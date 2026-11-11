--[[
	EscapeService (Beta 1.3): OVO DO FIM DO BIOMA + FUGA com a pista desmoronando.

	FLUXO (durante uma corrida — RaceState = "Racing")
	  1. Um ovo gigante por bioma, a Config.Escape.EggBeforeEnd studs do fim (Map.BiomeEggs, criado ao iniciar o
	     servidor, tag "BiomeEgg", atributo BiomeId). Beta 1.7: volta o prompt SEGURAR F ("GrabPrompt",
	     Style = Custom: o visual é desenhado pelo Client.GrabPromptUI; Config.Escape.HoldDuration / PromptDistance).
	  2. Prompt completado => o SERVIDOR valida (correndo, dentro do carro, tier do carro, distância real do carro,
	     incubadora com vaga, não está carregando outro ovo, anti-spam) e SORTEIA com EggRoll.
	     O resultado vai ao cliente só para a ROLETA (evento "EggRoulette"). O cliente não escolhe nada.
	  3. Depois da roleta + HeadStart, a FRENTE DE COLAPSO anda em direção à base (+Z):
	        frenteZ(t) = FrontZ0 + Speed * (t - FrontStart)        (t = workspace:GetServerTimeNow())
	     Speed = Config.EscapeSpeed(bioma, TopSpeed, CarTier) — Beta 1.7: acompanha a velocidade máxima REAL do SEU carro
     (com motor) => carro melhor = barreira mais rápida (nunca acima de CarFactorCap x sua velocidade).
	     Os mesmos números vão para o cliente em ATRIBUTOS => o visual (Client.EscapeFX) desenha a pista
	     caindo exatamente onde o servidor acha que ela está.
	  4. A cada 0,1 s o servidor confere a posição REAL do carro:
	        z <= frenteZ   => PEGO pelo colapso: ovo perdido, volta ao lobby (RaceService.End "caught")
	        z >= BaseZ     => ENTREGUE na base: ovo vai para a INCUBADORA (IncubatorService), volta ao lobby
	        corrida acabou (Home / morreu / saiu) => ovo perdido ("abandoned")
	        avanço impossível em direção à base (teleporte/speed hack) => fuga anulada ("invalid")

	POR QUE A PISTA NÃO É DESTRUÍDA NO SERVIDOR: a pista é UMA só para todos (modelo "pista fantasma" da Beta 1.2).
	Destruir de verdade derrubaria os outros corredores. Então o colapso é desenhado POR JOGADOR no cliente e a
	regra (quem foi pego) é decidida aqui no servidor.

	ATRIBUTOS do Player: EscapeState ("" | "Escaping"), EscapeBiome, EscapeEggZ, EscapeFrontZ0, EscapeFrontStart, EscapeSpeed
	EVENTOS: EggRoulette(info), EscapeResult(info)
	DEPENDÊNCIAS: DataService, CarService, RaceService, IncubatorService, EggRoll, Config.Escape
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)
local CarService = require(script.Parent.CarService)
local RaceService = require(script.Parent.RaceService)
local IncubatorService = require(script.Parent.IncubatorService)
local EggRoll = require(script.Parent.EggRoll)

local EscapeService = {}
local E, W = Config.Escape, Config.World
local escapes = {}  -- [player] = { Biome, Roll, EggZ, FrontZ0, FrontStart, Speed, Armed, LastPos, LastT }
local lastTry = {}  -- anti-spam do prompt

-- ---------------------------------------------------------------- utilidades
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function groundY(x, z)
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map and map:FindFirstChild("Drivable") then table.insert(list, map.Drivable) end
	groundParams.FilterDescendantsInstances = list
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), groundParams)
	return hit and hit.Position.Y or 0
end

local function toast(player, text, kind) Net.Fire(player, "Toast", text, kind or "error") end

local ATTRS = { "EscapeBiome", "EscapeEggZ", "EscapeFrontZ0", "EscapeFrontStart", "EscapeSpeed" }
local function setAttrs(player, e)
	if e then
		player:SetAttribute("EscapeBiome", e.Biome)
		player:SetAttribute("EscapeEggZ", e.EggZ)
		player:SetAttribute("EscapeFrontZ0", e.FrontZ0)
		player:SetAttribute("EscapeFrontStart", e.FrontStart)
		player:SetAttribute("EscapeSpeed", e.Speed)
		player:SetAttribute("EscapeState", "Escaping") -- por último: o cliente lê os outros quando este muda
	else
		player:SetAttribute("EscapeState", "")
		for _, a in ipairs(ATTRS) do player:SetAttribute(a, nil) end
	end
end

function EscapeService.FrontZ(e, t) return e.FrontZ0 + e.Speed * math.max(0, t - e.FrontStart) end
function EscapeService.IsEscaping(player) return escapes[player] ~= nil end

-- ---------------------------------------------------------------- fim da fuga
local function endRaceLater(player, delay, reason)
	task.delay(delay, function()
		if player.Parent and RaceService.IsRacing(player) then RaceService.End(player, reason) end
	end)
end

local function finish(player, success, reason)
	local e = escapes[player]
	if not e then return end
	escapes[player] = nil
	setAttrs(player, nil)
	print(("[EscapeService] %s: fuga terminou (%s) | ovo %s | %.1fs após o colapso começar"):format(player.Name,
		success and "delivered" or tostring(reason), e.Roll.Id, workspace:GetServerTimeNow() - e.FrontStart))
	local data = DataService.Get(player)
	local info = { Success = false, Reason = reason, Id = e.Roll.Id, Mut = e.Roll.Mut, Size = e.Roll.Size, Biome = e.Biome }
	if success then
		local entry, err = IncubatorService.Add(player, e.Biome, e.Roll)
		if entry then
			info.Success, info.Reason, info.ReadyAt, info.Now = true, "delivered", entry.ReadyAt, os.time()
			if data then data.Stats.Escapes = (data.Stats.Escapes or 0) + 1 end
		else
			info.Reason = err -- (não deveria acontecer: a vaga é conferida ao pegar o ovo)
		end
		Net.Fire(player, "EscapeResult", info)
		endRaceLater(player, 1.4, "delivered")
	else
		if data then data.Stats.EscapesLost = (data.Stats.EscapesLost or 0) + 1 end
		Net.Fire(player, "EscapeResult", info)
		if reason ~= "abandoned" then endRaceLater(player, E.CaughtEndDelay, "caught") end
	end
end

-- ---------------------------------------------------------------- pegar o ovo
local function tryGrab(player, biome, part)
	local clock = os.clock()
	if lastTry[player] and clock - lastTry[player] < 1 then return end
	lastTry[player] = clock

	if escapes[player] then return toast(player, "🥚 You're already carrying an egg — get it home!") end
	if (player:GetAttribute("RaceState") or "Lobby") ~= "Racing" then return toast(player, "🏁 Start a race to grab this egg!") end
	if not CarService.IsDriving(player) then return toast(player, "🚗 Get in your car to carry the egg!") end
	if biome.Tier > CarService.GetTier(player) then
		return toast(player, ("🔒 This egg needs a Tier %d car!"):format(biome.Tier))
	end
	local pos = CarService.GetPosition(player)
	if not pos or (pos - part.Position).Magnitude > E.PromptDistance + 20 then return toast(player, "Get closer to the egg!") end
	if IncubatorService.IsFull(player) then
		return toast(player, ("🥚 Your incubator is full (%d/%d)! Wait for an egg to hatch."):format(Config.Incubator.Slots, Config.Incubator.Slots))
	end

	local roll = EggRoll.Roll(biome.Id, 1) -- SORTEIO NO SERVIDOR
	if not roll then return end
	local t = workspace:GetServerTimeNow()
	local eggZ = Config.BiomeEggZ(biome)
	local e = {
		Biome = biome.Id, Roll = roll, EggZ = eggZ,
		FrontZ0 = math.min(eggZ, pos.Z) - E.StartGap,
		FrontStart = t + E.RouletteSeconds + E.HeadStart,
		Speed = Config.EscapeSpeed(biome, player:GetAttribute("TopSpeed"), player:GetAttribute("CarTier")),
		Armed = false, LastPos = pos, LastT = t,
	}
	escapes[player] = e
	setAttrs(player, e)
	local cfg = Config.AnimeById[roll.Id]
	print(("[EscapeService] %s pegou o ovo %s => %s (%s) | colapso a %.0f studs/s"):format(player.Name, biome.Id, roll.Id, cfg.Rarity, e.Speed))
	Net.Fire(player, "EggRoulette", {
		Biome = biome.Id,
		Result = { Id = roll.Id, Mut = roll.Mut, Size = roll.Size, Odds = roll.Odds },
		HatchSeconds = Config.Rarities[cfg.Rarity].HatchSeconds,
		RouletteEnds = t + E.RouletteSeconds,
		FrontStart = e.FrontStart,
	})
end

-- ---------------------------------------------------------------- ovos físicos (1 por bioma)
local function buildEggs()
	local map = workspace:FindFirstChild("Map") or workspace
	local old = map:FindFirstChild("BiomeEggs")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "BiomeEggs"
	for _, b in ipairs(Config.Biomes) do
		local egg = Config.Eggs[b.Id]
		local z = Config.BiomeEggZ(b)
		local x = W.RoadX(z)
		local p = Instance.new("Part")
		p.Name = "BiomeEgg_" .. b.Id
		p.Size = Vector3.new(10, 1, 10)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Transparency = 1
		p.CFrame = CFrame.new(x, groundY(x, z) + 0.5, z)
		p:SetAttribute("BiomeId", b.Id)
		p:SetAttribute("EggName", egg and egg.Name or "Egg")
		local att = Instance.new("Attachment")
		att.Name = "PromptPoint"; att.Position = Vector3.new(0, 6, 0); att.Parent = p
		local pp = Instance.new("ProximityPrompt")
		pp.Name = "GrabPrompt"
		pp.ActionText = "Grab Egg"
		pp.ObjectText = egg and egg.Name or "Egg"
		pp.HoldDuration = E.HoldDuration
		pp.MaxActivationDistance = E.PromptDistance
		pp.RequiresLineOfSight = false
		pp.KeyboardKeyCode = Enum.KeyCode.F
		pp.GamepadKeyCode = Enum.KeyCode.ButtonX
		pp.Style = Enum.ProximityPromptStyle.Custom -- Beta 1.7: UI própria (Client.GrabPromptUI)
		pp:SetAttribute("BiomeId", b.Id)
		pp.Parent = att
		pp.Triggered:Connect(function(plr) tryGrab(plr, b, p) end)
		p.Parent = folder
		CollectionService:AddTag(p, "BiomeEgg")
	end
	folder.Parent = map
end

-- ---------------------------------------------------------------- regra da fuga (autoridade do servidor)
local function step()
	local t = workspace:GetServerTimeNow()
	for player, e in pairs(escapes) do
		if not player.Parent then
			escapes[player] = nil
		elseif (player:GetAttribute("RaceState") or "Lobby") ~= "Racing" then
			finish(player, false, "abandoned") -- Home, morreu/renasceu, corrida acabou
		else
			local pos = CarService.GetPosition(player)
			if pos then
				local dt = math.max(t - e.LastT, 1 / 60)
				local advance = pos.Z - e.LastPos.Z -- quanto chegou mais perto da base desde o último tick
				e.LastPos, e.LastT = pos, t
				if advance > Config.SpeedCap * E.MaxForwardSpeed * dt + 60 then
					finish(player, false, "invalid")
				elseif t >= e.FrontStart then
					if not e.Armed then
						-- carro rápido que passou do ovo ao frear: o colapso nasce atrás dele (nunca "pego" de graça)
						e.Armed = true
						local z0 = math.min(e.FrontZ0, pos.Z - E.StartGap)
						if z0 ~= e.FrontZ0 then e.FrontZ0 = z0; player:SetAttribute("EscapeFrontZ0", z0) end
					end
					if pos.Z >= E.BaseZ then
						finish(player, true)
					elseif pos.Z <= EscapeService.FrontZ(e, t) then
						finish(player, false, "caught")
					end
				end
			end
		end
	end
end

function EscapeService.Init()
	if not Config.Features.BiomeEggs then return end
	buildEggs()
	DataService.OnLoaded(function(player) player:SetAttribute("EscapeState", "") end)
	Players.PlayerRemoving:Connect(function(p) escapes[p], lastTry[p] = nil, nil end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(step)
			if not ok then warn("[EscapeService] " .. tostring(err)) end
		end
	end)
end

return EscapeService
