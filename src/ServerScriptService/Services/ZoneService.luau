--[[
	ZoneService (Beta 1.1): em qual bioma o jogador está (de carro OU a pé).
	  * Atualiza o atributo "Biome" do Player e avisa o cliente (título + atmosfera).
	  * BLOQUEIA biomas acima do tier do carro equipado: devolve o carro (ou o jogador a pé) ao portão.
	  * Resgata quem cai no abismo/fora do mapa (volta ao último ponto seguro).
]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Locale = require(Shared.Locale) -- Beta 1.9: avisos no idioma do jogador
local CarService = require(script.Parent.CarService)
local DataService = require(script.Parent.DataService)

local ZoneService = {}
local lastBiome, lastSafe = {}, {}

-- Chamado pelo RaceService ao teleportar (lobby <-> pista): evita "resgatar" o jogador para o lugar errado.
function ZoneService.ResetSafe(player, cf)
	lastSafe[player] = cf
	lastBiome[player] = nil -- força reenviar o bioma/zona atual
end

local function groundY(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map and map:FindFirstChild("Drivable") then table.insert(list, map.Drivable) end
	params.FilterDescendantsInstances = list
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
	return hit and hit.Position.Y or 5
end

-- Move o "sujeito" (carro se dirigindo, senão o corpo) para um CFrame seguro
local function moveSubject(player, cf, driving)
	if driving then
		task.spawn(CarService.Teleport, player, cf)
	elseif player.Character then
		player.Character:PivotTo(cf)
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if root then root.AssemblyLinearVelocity = Vector3.zero end
	end
end

local function step(player)
	local driving = CarService.IsDriving(player)
	local pos = CarService.GetPosition(player)
	if not pos then return end

	-- Resgate de queda (abismos / fora do mapa)
	if pos.Y < -30 then
		local cf = lastSafe[player] or CFrame.new(Config.Lobby.Origin + Vector3.new(0, 10, 0))
		moveSubject(player, cf + Vector3.new(0, 8, 0), driving)
		Net.Fire(player, "Toast", Locale.For(player, "🛟 Back on the road!"), "info")
		return
	end

	-- No lobby não existe bioma (nem bloqueio de tier). Na pista, antes do bioma 1 = zona de largada.
	local inLobby = (player:GetAttribute("RaceState") or "Lobby") == "Lobby"
	local biome = (not inLobby) and Config.BiomeAtZ(pos.Z) or nil
	local id = inLobby and "lobby" or (biome and biome.Id or "start")
	if lastBiome[player] ~= id then
		lastBiome[player] = id
		player:SetAttribute("Biome", id)
		Net.Fire(player, "BiomeChanged", id)
		local data = DataService.Get(player)
		-- Beta 1.9: na corrida 1v1 (RaceMode "Duel") o progresso normal não é pulado: não grava "melhor bioma"
		if biome and data and player:GetAttribute("RaceMode") ~= "Duel" and biome.Order > (data.Stats.BestBiome or 0) then data.Stats.BestBiome = biome.Order end
	end

	-- Bloqueio por tier (vale a pé também)
	-- Beta 1.9: sem bloqueio na corrida 1v1 (os carros de F1 não têm tier; a corrida vai até o fim do mapa)
	if biome and player:GetAttribute("RaceMode") ~= "Duel" and biome.Tier > CarService.GetTier(player) then
		local zs = biome.ZStart + 60
		local x = Config.World.RoadX(zs)
		moveSubject(player, CFrame.new(x, groundY(x, zs) + 5, zs), driving)
		local need
		for _, c in ipairs(Config.Cars) do if c.Tier == biome.Tier then need = c.Name end end
		Net.Fire(player, "Toast", Locale.For(player, "🔒 %s needs a Tier %d car (%s)!", biome.Name, biome.Tier, need or "?"), "error")
		return
	end

	if pos.Y > -10 then lastSafe[player] = CFrame.new(pos) end
end

function ZoneService.Init()
	Players.PlayerRemoving:Connect(function(p) lastBiome[p], lastSafe[p] = nil, nil end)
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(step, player)
				if not ok then warn("[ZoneService] " .. tostring(err)) end
			end
		end
	end)
end

return ZoneService
