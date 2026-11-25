--[[
	DevService  (ServerScriptService.Services.DevService)                                     Beta 2.0b
	=====================================================================================================
	Ferramentas da EQUIPE DEV (painel 🛠️ DEV no cliente: Client.DevPanel). Pedido do dono em 25/11/2026:
	"uma aba só nossa (cargo DEV) para pegar personagens sem correr, com quantas estrelas quiser, dinheiro e spins".

	QUEM É DEV: Config.Dev (UserId; o nome pode mudar, o UserId não). Opcional: rank mínimo no grupo dono do jogo
	(Config.Dev.GroupMinRank) e, só no Studio, os bonecos de teste (Player1/Player2, UserId <= 0).
	O servidor confere em TODA ação; o atributo "IsDev" do Player serve só para o cliente desenhar o botão e a
	etiqueta [DEV] do chat. Um cliente que não é DEV e chama estas ações recebe { ok = false, err = "NotDev" }
	e a tentativa fica no Output.

	ALVO: toda ação recebe targetUserId (nil = o próprio DEV). Dá para dar coisas a qualquer jogador do servidor
	(útil para testar o 1v1 com outra conta). O alvo recebe um aviso.

	REDE (todas só para DEV; retornam { ok, err?, Msg? }):
	  DevInfo()                                   -> { ok, Players = {{UserId, Name, Dev}}, Log = {...}, Studio = bool }
	  DevGiveAnime(target, animeId, opts)         opts = { Stars 0..5, Mut nil|"Gold"|"Diamond", Size nil|"BIG",
	                                                       Level 1..50, Count 1..MaxGive, Hatch = bool }
	                                              Hatch = vai para a incubadora e choca em 2 s (testa a revelação)
	  DevGiveAll(target, biomeId|"all", opts)     um de cada personagem (sem os Legacy) do bioma, com Stars/Mut/Level
	  DevCash(target, "add"|"set", amount)        0..Config.Dev.MaxCash
	  DevSpins(target, "tokens"|"points"|"free", amount)   giros extras | pontos de spin | zera a espera do giro grátis
	  DevCars(target, "all"|"engine")             todos os carros | motor no máximo em todos os carros que tem
	  DevVersusShop(target)                       todos os F1 e todas as animações de vitória
	  DevMaxAnimes(target)                        todos os personagens com 5★ e nível 50
	  DevHatchNow(target)                         todos os ovos da incubadora chocam agora
	  DevSaveNow(target)                          salva o perfil agora
	REGISTRO: cada ação vai para o Output ("[DEV] ...") e para a lista do painel (últimas Config.Dev.LogSize).
	DEPENDÊNCIAS: DataService, FarmService, IncubatorService, CarService, WheelService (Push), Config.Dev.
	NÃO MUDA o formato do save (só usa campos que já existem).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local IncubatorService = require(script.Parent.IncubatorService)
local CarService = require(script.Parent.CarService)
local WheelService = require(script.Parent.WheelService)

local DevService = {}
local D = Config.Dev or { Enabled = false, Members = {} }
local log = {}
local devCache = {} -- [player] = true/false (conferido ao entrar)

local function inList(userId)
	for _, m in ipairs(D.Members or {}) do
		if m.UserId == userId then return true end
	end
	return false
end

local function computeIsDev(player)
	if not D.Enabled then return false end
	if inList(player.UserId) then return true end
	if D.StudioTestPlayers and RunService:IsStudio() and player.UserId <= 0 then return true end
	if (D.GroupMinRank or 0) > 0 and game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if ok and rank >= D.GroupMinRank then return true end
	end
	return false
end

function DevService.IsDev(player)
	if devCache[player] == nil then devCache[player] = computeIsDev(player) end
	return devCache[player]
end

local function addLog(dev, target, text)
	local line = { Time = os.time(), By = dev.Name, Target = target and target.Name or dev.Name, Text = text }
	table.insert(log, 1, line)
	while #log > (D.LogSize or 60) do table.remove(log) end
	print(("[DEV] %s -> %s: %s"):format(line.By, line.Target, text))
end

local function targetOf(dev, userId)
	if userId == nil then return dev end
	if type(userId) ~= "number" or userId ~= userId then return nil end
	return Players:GetPlayerByUserId(userId)
end

local function int(v, lo, hi, default)
	v = tonumber(v)
	if not v or v ~= v then return default end
	return math.clamp(math.floor(v), lo, hi)
end

-- Avisa o alvo quando o DEV deu algo para OUTRA pessoa.
local function notify(dev, target, text)
	if target ~= dev then Net.Fire(target, "Toast", "🛠️ " .. text, "good") end
end

-- Registra uma ação só para DEV. fn(dev, target, ...) -> resposta. O alvo é o 1º argumento do cliente.
local function devHandle(name, fn, cooldown)
	Net.Handle(name, function(player, targetUserId, ...)
		if not DevService.IsDev(player) then
			warn(("[DEV] %s (%d) tentou '%s' sem ser DEV"):format(player.Name, player.UserId, name))
			return { ok = false, err = "NotDev" }
		end
		local target = targetOf(player, targetUserId)
		if not target then return { ok = false, err = "NoTarget" } end
		if not DataService.Get(target) then return { ok = false, err = "NoData" } end
		return fn(player, target, ...)
	end, cooldown or 0.2)
end

local function cleanOpts(opts)
	opts = type(opts) == "table" and opts or {}
	local o = {
		Stars = int(opts.Stars, 0, Config.Stars.Max, 0),
		Level = int(opts.Level, 1, Config.Levels.Max, 1),
		Count = int(opts.Count, 1, D.MaxGive or 50, 1),
		Hatch = opts.Hatch == true,
	}
	if type(opts.Mut) == "string" and Config.Mutations[opts.Mut] then o.Mut = opts.Mut end
	if type(opts.Size) == "string" and Config.Sizes[opts.Size] then o.Size = opts.Size end
	return o
end

local function describe(cfg, o)
	local s = cfg.Name .. " " .. string.rep("★", o.Stars)
	if o.Mut then s = o.Mut .. " " .. s end
	if o.Size then s = o.Size .. " " .. s end
	if o.Level > 1 then s ..= " Lv" .. o.Level end
	return s
end

-- Dá um personagem já pronto (mochila/pedestal). Devolve a entrada.
local function give(target, cfg, o)
	local entry = FarmService.AddAnime(target, cfg.Id, o.Mut, o.Size, o.Stars)
	if entry and o.Level > 1 then entry.Level, entry.XP = o.Level, 0 end
	return entry
end

function DevService.Init()
	if not D.Enabled then return end

	local function mark(player)
		devCache[player] = computeIsDev(player)
		player:SetAttribute("IsDev", devCache[player] or nil)
		if devCache[player] then print("[DEV] " .. player.Name .. " entrou (DEV)") end
	end
	Players.PlayerAdded:Connect(mark)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(mark, p) end
	Players.PlayerRemoving:Connect(function(p) devCache[p] = nil end)

	devHandle("DevInfo", function(dev)
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			list[#list + 1] = { UserId = p.UserId, Name = p.Name, Dev = DevService.IsDev(p) }
		end
		return { ok = true, Players = list, Log = log, Studio = RunService:IsStudio() }
	end, 0.3)

	devHandle("DevGiveAnime", function(dev, target, animeId, opts)
		local cfg = type(animeId) == "string" and Config.AnimeById[animeId]
		if not cfg then return { ok = false, err = "Invalid" } end
		local o = cleanOpts(opts)
		if o.Hatch then
			local entry, err = IncubatorService.Add(target, cfg.Biome, { Id = cfg.Id, Mut = o.Mut, Size = o.Size, Odds = 1, Stars = o.Stars })
			if not entry then return { ok = false, err = err == "Full" and "IncubatorFull" or "Invalid" } end
			entry.ReadyAt = os.time() + 2
			IncubatorService.Push(target)
			addLog(dev, target, "hatch " .. describe(cfg, o))
			notify(dev, target, "A dev sent you an egg: " .. cfg.Name .. "!")
			return { ok = true, Msg = "🥚 " .. cfg.Name .. " hatching in 2s" }
		end
		local n = 0
		for _ = 1, o.Count do
			if give(target, cfg, o) then n += 1 end
		end
		if o.Level > 1 then FarmService.Refresh(target) end
		addLog(dev, target, ("give %dx %s"):format(n, describe(cfg, o)))
		notify(dev, target, ("A dev gave you %dx %s!"):format(n, cfg.Name))
		return { ok = n > 0, Msg = ("✅ %dx %s"):format(n, describe(cfg, o)) }
	end, 0.25)

	devHandle("DevGiveAll", function(dev, target, biomeId, opts)
		if biomeId ~= "all" and not (type(biomeId) == "string" and Config.BiomeById[biomeId]) then return { ok = false, err = "Invalid" } end
		local o = cleanOpts(opts)
		local n = 0
		for _, cfg in ipairs(Config.Animes) do
			if not cfg.Legacy and (biomeId == "all" or cfg.Biome == biomeId) then
				if give(target, cfg, o) then n += 1 end
			end
		end
		FarmService.Refresh(target)
		addLog(dev, target, ("give ALL (%s): %d characters %s"):format(biomeId, n, string.rep("★", o.Stars)))
		notify(dev, target, ("A dev gave you %d characters!"):format(n))
		return { ok = true, Msg = ("✅ %d characters"):format(n) }
	end, 1)

	devHandle("DevCash", function(dev, target, mode, amount)
		amount = tonumber(amount)
		if (mode ~= "add" and mode ~= "set") or not amount or amount ~= amount then return { ok = false, err = "Invalid" } end
		amount = math.floor(math.clamp(amount, 0, D.MaxCash or 1e15))
		local data = DataService.Get(target)
		if mode == "set" then DataService.AddCash(target, amount - data.Cash) else DataService.AddCash(target, amount) end
		addLog(dev, target, ("cash %s $%s (now $%s)"):format(mode, Util.FormatNumber(amount), Util.FormatNumber(data.Cash)))
		notify(dev, target, "A dev gave you $" .. Util.FormatNumber(amount) .. "!")
		return { ok = true, Msg = "💵 $" .. Util.FormatNumber(data.Cash) }
	end)

	devHandle("DevSpins", function(dev, target, kind, amount)
		local data = DataService.Get(target)
		data.Wheel = data.Wheel or {}
		local w = data.Wheel
		if kind == "tokens" then
			local n = int(amount, -(w.Tokens or 0), D.MaxSpins or 1000, 0)
			w.Tokens = math.max(0, (w.Tokens or 0) + n)
			addLog(dev, target, ("spins %+d (now %d)"):format(n, w.Tokens))
			notify(dev, target, ("A dev gave you %d spins!"):format(n))
		elseif kind == "points" then
			local n = int(amount, 1, 10000, 0)
			WheelService.AddPoints(target, n) -- 100 pontos viram 1 giro (regra normal)
			addLog(dev, target, ("spin points +%d"):format(n))
		elseif kind == "free" then
			w.LastSpin = 0
			addLog(dev, target, "free spin ready")
		else
			return { ok = false, err = "Invalid" }
		end
		WheelService.Push(target)
		return { ok = true, Msg = ("🎟️ %d spins | %d pts"):format(w.Tokens or 0, w.Points or 0) }
	end)

	devHandle("DevCars", function(dev, target, kind)
		local data = DataService.Get(target)
		if kind == "all" then
			for _, c in ipairs(Config.Cars) do data.Cars[c.Id] = data.Cars[c.Id] or { Engine = 0 } end
		elseif kind == "engine" then
			for _, entry in pairs(data.Cars) do entry.Engine = Config.Engine.MaxLevel end
		else
			return { ok = false, err = "Invalid" }
		end
		CarService.RefreshAttributes(target)
		CarService.SendState(target)
		addLog(dev, target, kind == "all" and "all cars unlocked" or "engine maxed on every car")
		notify(dev, target, kind == "all" and "A dev unlocked every car!" or "A dev maxed your engines!")
		return { ok = true, Msg = kind == "all" and "🏎️ all cars unlocked" or "🔧 engines maxed" }
	end, 0.5)

	devHandle("DevVersusShop", function(dev, target)
		local data = DataService.Get(target)
		data.Versus = data.Versus or {}
		data.Versus.F1 = data.Versus.F1 or { Owned = {}, Equipped = Config.F1Cars[1].Id }
		data.Versus.Fx = data.Versus.Fx or { Owned = {}, Equipped = Config.Battle.VictoryFx[1].Id }
		data.Versus.F1.Owned = data.Versus.F1.Owned or {}
		data.Versus.Fx.Owned = data.Versus.Fx.Owned or {}
		for _, c in ipairs(Config.F1Cars) do data.Versus.F1.Owned[c.Id] = true end
		for _, f in ipairs(Config.Battle.VictoryFx) do data.Versus.Fx.Owned[f.Id] = true end
		addLog(dev, target, "all F1 cars + victory effects")
		notify(dev, target, "A dev unlocked every F1 car and victory effect!")
		return { ok = true, Msg = "🏁 F1 + effects unlocked (reopen the shop)" }
	end, 0.5)

	devHandle("DevMaxAnimes", function(dev, target)
		local data = DataService.Get(target)
		for _, e in ipairs(data.Animes) do e.Stars, e.Level, e.XP = Config.Stars.Max, Config.Levels.Max, 0 end
		FarmService.Refresh(target)
		addLog(dev, target, ("max %d characters (5★ Lv%d)"):format(#data.Animes, Config.Levels.Max))
		notify(dev, target, "A dev maxed all your characters!")
		return { ok = true, Msg = ("⭐ %d characters maxed"):format(#data.Animes) }
	end, 0.5)

	devHandle("DevHatchNow", function(dev, target)
		local data = DataService.Get(target)
		local now = os.time()
		for _, e in ipairs(data.Incubator) do e.ReadyAt = now end
		IncubatorService.Push(target)
		addLog(dev, target, ("hatch now (%d eggs)"):format(#data.Incubator))
		return { ok = true, Msg = ("🥚 %d eggs hatching"):format(#data.Incubator) }
	end, 0.5)

	devHandle("DevSaveNow", function(dev, target)
		local ok = DataService.SaveSync(target)
		addLog(dev, target, "save now: " .. tostring(ok))
		-- No Studio sem "Enable Studio Access to API Services" o DataService usa dados temporários: nada é gravado.
		local msg = RunService:IsStudio() and "💾 done (in Studio it only writes with API access on)" or "💾 saved"
		return { ok = ok, Msg = ok and msg or "💾 not saved (profile locked by another server?)" }
	end, 2)
end

return DevService
