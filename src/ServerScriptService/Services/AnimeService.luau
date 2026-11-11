--[[
	AnimeService: captura de animes (o coração do loop de dopamina).
	  1. O CLIENTE detecta que chegou perto de um ponto (workspace.Map.AnimeSpawns.*) e chama "StartEncounter".
	  2. O SERVIDOR valida (distância, tier, cooldown) e devolve o instante de início do mini-jogo.
	  3. O jogador toca no momento certo; o cliente chama "ResolveEncounter" com o instante do toque.
	  4. O SERVIDOR calcula a nota (mesma onda triangular do cliente), sorteia anime/mutação/tamanho,
	     entrega via FarmService.AddAnime e responde com o resultado para a tela de revelação.
	O cliente NUNCA decide o resultado nem a raridade.
]]
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local CarService = require(script.Parent.CarService)

local AnimeService = {}
local rng = Random.new()
local sessions, cooldowns = {}, {}

local function weightedPick(weights, total)
	local r = rng:NextNumber() * total
	for k, w in pairs(weights) do
		r -= w
		if r <= 0 then return k end
	end
	return next(weights)
end

-- Retorna cfg do anime sorteado e a probabilidade BASE (sem sorte) dele, para exibir "1 in N".
local function rollAnime(biomeId, luck)
	local pool = Config.AnimesByBiome[biomeId]
	local base, boosted, tb, tl = {}, {}, 0, 0
	for rname in pairs(pool) do
		local r = Config.Rarities[rname]
		base[rname] = r.Weight; tb += r.Weight
		local w = r.Weight * ((r.Order >= Config.Capture.LuckFromOrder) and luck or 1)
		boosted[rname] = w; tl += w
	end
	local rname = weightedPick(boosted, tl)
	local list = pool[rname]
	return list[rng:NextInteger(1, #list)], (base[rname] / tb) / #list
end

local function rollMutation()
	local r, acc = rng:NextNumber(), 0
	for _, name in ipairs(Config.MutationOrder) do
		local c = Config.Mutations[name].Chance
		acc += c
		if r < acc then return name, c end
	end
	return nil, 1 - acc
end

local function rollSize()
	for name, def in pairs(Config.Sizes) do
		if rng:NextNumber() < def.Chance then return name, def.Chance end
	end
	local none = 1
	for _, def in pairs(Config.Sizes) do none -= def.Chance end
	return nil, none
end

function AnimeService.Init()
	Net.Handle("StartEncounter", function(player, nodeId)
		if type(nodeId) ~= "string" then return { ok = false } end
		if sessions[player] and os.clock() - sessions[player].Created < Config.Capture.Duration + 3 then
			return { ok = false, err = "Busy" }
		end
		local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("AnimeSpawns")
		local node = folder and folder:FindFirstChild(nodeId)
		if not node then return { ok = false, err = "NoNode" } end
		local biomeId = node:GetAttribute("BiomeId")
		local biome = biomeId and Config.BiomeById[biomeId]
		if not biome then return { ok = false, err = "NoBiome" } end
		if biome.Tier > CarService.GetTier(player) then return { ok = false, err = "Locked" } end
		local pos = CarService.GetPosition(player)
		if not pos or (pos - node.Position).Magnitude > Config.Capture.TriggerRadius + 30 then
			return { ok = false, err = "TooFar" }
		end
		cooldowns[player] = cooldowns[player] or {}
		if (cooldowns[player][nodeId] or 0) > os.clock() then return { ok = false, err = "Cooldown" } end
		cooldowns[player][nodeId] = os.clock() + Config.Capture.NodeCooldown

		local start = workspace:GetServerTimeNow()
		sessions[player] = { NodeId = nodeId, Biome = biomeId, Start = start, Created = os.clock() }
		return { ok = true, Start = start, Period = Config.Capture.Period, Duration = Config.Capture.Duration, Biome = biomeId }
	end)

	Net.Handle("ResolveEncounter", function(player, tapTime)
		local s = sessions[player]
		if not s then return { ok = false, err = "NoSession" } end
		sessions[player] = nil
		local data = DataService.Get(player)
		if not data then return { ok = false } end

		-- Nota: usa o instante do toque (limitado à janela válida); sem toque = nota mínima.
		local grade = Config.Capture.Grades[#Config.Capture.Grades]
		local now = workspace:GetServerTimeNow()
		if type(tapTime) == "number" and tapTime == tapTime then
			local t = math.clamp(tapTime, now - 1.5, now) - s.Start
			t = math.clamp(t, 0, Config.Capture.Duration)
			grade = Config.GradeFor(Util.Triangle(t, Config.Capture.Period))
		end

		local cfg, pAnime = rollAnime(s.Biome, grade.Luck)
		local mut, pMut = rollMutation()
		local size, pSize = rollSize()
		local odds = math.max(1, math.floor(1 / (pAnime * pMut * pSize) + 0.5))

		local entry, placed = FarmService.AddAnime(player, cfg.Id, mut, size)
		if not entry then return { ok = false } end
		data.Stats.Captures += 1
		return {
			ok = true, Grade = grade.Name, Luck = grade.Luck, Id = cfg.Id, Mut = mut, Size = size,
			Odds = odds, Placed = placed, Income = FarmService.IncomeOf(entry), Uid = entry.Uid,
		}
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(p) sessions[p], cooldowns[p] = nil, nil end)
end

return AnimeService
