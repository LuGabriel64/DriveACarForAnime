--[[
	EggService (Beta 1.1): personagens agora vêm de OVOS.
	  * OVO DE ESTRADA (grátis): peças com tag "RoadEgg" em workspace.Map.EggNodes. O cliente desenha o ovo e,
	    quando o jogador passa por cima (de carro ou a pé), chama "CollectRoadEgg". O servidor confere distância,
	    tier do bioma e cooldown POR JOGADOR (cada um vê os seus ovos).
	  * SANTUÁRIO (pago): peças com tag "EggShrine". O cliente abre a loja; "BuyEgg"(biomeId, quantidade) confere
	    proximidade, tier e dinheiro.
	  * O SORTEIO usa Config.EggOdds (a mesma tabela que a UI mostra) + mutação (Gold/Diamond) + tamanho (BIG).
	  * O cliente NUNCA decide o resultado. A resposta traz tudo para a animação de chocar.
	Beta 1.3: o sorteio mudou para Services.EggRoll (compartilhado com o ovo do bioma). Ovos de estrada e santuários
	ficam GUARDADOS atrás de Config.Features.RoadEggs / .Shrines: desligados, as ações respondem "Disabled" e as
	pastas Map.EggNodes / Map.EggShrines saem do workspace SÓ durante o jogo (o mapa no editor não muda).
]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local CarService = require(script.Parent.CarService)
local EggRoll = require(script.Parent.EggRoll)

local EggService = {}
local roadCooldowns = {} -- [player][nodeName] = os.clock() em que libera

-- "1 in N" mostrado na revelação = raridade BASE (sem sorte) do personagem x mutação x tamanho (ver EggRoll)
local function hatchOne(player, biomeId, luck)
	local roll = EggRoll.Roll(biomeId, luck)
	if not roll then return nil end
	local entry, placed = FarmService.AddAnime(player, roll.Id, roll.Mut, roll.Size)
	if not entry then return nil end
	local data = DataService.Get(player)
	if data then data.Stats.Hatches = (data.Stats.Hatches or 0) + 1 end
	return { Id = roll.Id, Mut = roll.Mut, Size = roll.Size, Odds = roll.Odds, Placed = placed, Income = FarmService.IncomeOf(entry), Uid = entry.Uid }
end

-- Sistemas guardados: tira a pasta do workspace só em jogo (as tags somem para o cliente). O editor não muda.
local function stash(folderName)
	local map = workspace:FindFirstChild("Map")
	local f = map and map:FindFirstChild(folderName)
	if not f then return end
	local holder = game:GetService("ServerStorage"):FindFirstChild("DisabledAtRuntime")
	if not holder then
		holder = Instance.new("Folder"); holder.Name = "DisabledAtRuntime"; holder.Parent = game:GetService("ServerStorage")
	end
	f.Parent = holder
end

local function nearTagged(folderName, biomeId, pos, radius)
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild(folderName)
	if not folder then return false end
	for _, p in ipairs(folder:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("BiomeId") == biomeId and (p.Position - pos).Magnitude <= radius then return true end
	end
	return false
end

function EggService.Init()
	if not Config.Features.RoadEggs then stash("EggNodes") end
	if not Config.Features.Shrines then stash("EggShrines") end

	-- Ovo da estrada (grátis)
	Net.Handle("CollectRoadEgg", function(player, nodeName)
		if not Config.Features.RoadEggs then return { ok = false, err = "Disabled" } end
		if type(nodeName) ~= "string" then return { ok = false } end
		if not FarmService.GetPlot(player) then return { ok = false, err = "NoGarage" } end
		local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("EggNodes")
		local node = folder and folder:FindFirstChild(nodeName, true)
		if not node or not node:IsA("BasePart") then return { ok = false, err = "NoNode" } end
		local biome = Config.BiomeById[node:GetAttribute("BiomeId") or ""]
		if not biome then return { ok = false, err = "NoBiome" } end
		if biome.Tier > CarService.GetTier(player) then return { ok = false, err = "Locked" } end
		local pos = CarService.GetPosition(player)
		if not pos or (pos - node.Position).Magnitude > Config.EggRules.RoadRadius + 35 then return { ok = false, err = "TooFar" } end
		roadCooldowns[player] = roadCooldowns[player] or {}
		if (roadCooldowns[player][nodeName] or 0) > os.clock() then return { ok = false, err = "Cooldown" } end
		roadCooldowns[player][nodeName] = os.clock() + Config.EggRules.RoadCooldown
		local r = hatchOne(player, biome.Id, Config.EggRules.RoadLuck)
		if not r then return { ok = false } end
		return { ok = true, Biome = biome.Id, Source = "Road", Results = { r } }
	end, 0.4)

	-- Santuário (pago, x1 ou x3)
	Net.Handle("BuyEgg", function(player, biomeId, count)
		if not Config.Features.Shrines then return { ok = false, err = "Disabled" } end
		local biome = type(biomeId) == "string" and Config.BiomeById[biomeId]
		local egg = biome and Config.Eggs[biomeId]
		if not egg then return { ok = false, err = "Invalid" } end
		local allowed = false
		for _, n in ipairs(Config.EggRules.MultiBuy) do if n == count then allowed = true end end
		if not allowed then return { ok = false, err = "Invalid" } end
		if not FarmService.GetPlot(player) then return { ok = false, err = "NoGarage" } end
		if biome.Tier > CarService.GetTier(player) then return { ok = false, err = "Locked" } end
		local pos = CarService.GetPosition(player)
		if not pos or not nearTagged("EggShrines", biomeId, pos, Config.EggRules.ShrineRadius + 20) then return { ok = false, err = "TooFar" } end
		if not DataService.TrySpend(player, egg.Price * count) then return { ok = false, err = "NoCash" } end
		local results = {}
		for _ = 1, count do
			local r = hatchOne(player, biomeId, Config.EggRules.ShrineLuck)
			if r then results[#results + 1] = r end
		end
		return { ok = true, Biome = biomeId, Source = "Shrine", Results = results }
	end, 0.6)

	Players.PlayerRemoving:Connect(function(p) roadCooldowns[p] = nil end)
end

return EggService
