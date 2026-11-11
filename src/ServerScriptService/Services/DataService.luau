--[[
	DataService: carrega/salva o perfil do jogador (DataStore) com TRAVA DE SESSÃO.
	  - Trava por JobId evita duplicação de itens ao trocar de servidor rápido.
	  - Em Studio sem "Enable Studio Access to API Services" usa dados temporários (não salva).
	  - Nunca salva se o carregamento falhou (protege contra apagar o progresso).
	API: Get(player) | WaitFor(player) | AddCash | TrySpend | PushAttributes | OnLoaded(fn) | OnLeaving(fn)
	Valores escalares (Cash, CarId...) são replicados ao cliente via ATRIBUTOS do Player.
	PRÓXIMO PASSO RECOMENDADO: migrar para ProfileStore (loleris) quando o projeto crescer.
	Beta 1.3: + data.Incubator / data.NextIncId / Stats.Escapes / Stats.EscapesLost (reconcile() preenche saves antigos).
	Beta 1.5: + data.Wheel {LastSpin, Spins, Pending}; leaderstats.Cash (placar do Roblox) espelha o Cash; SaveNow(player).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Util = require(RS.Shared.Util)
local Net = require(RS.Shared.Net)

local DataService = {}
local profiles, onLoaded, onLeaving = {}, {}, {}
local store

local function getStore()
	if store == nil then
		local ok, res = pcall(function() return DataStoreService:GetDataStore(Config.Data.StoreName) end)
		store = ok and res or false
	end
	return store
end
local function keyOf(player) return "P_" .. player.UserId end

local function settingsDefaults()
	local t = {}
	for _, s in ipairs(Config.Settings) do t[s.Key] = s.Default end
	return t
end

local function defaults()
	return {
		Version = 2, -- Beta 1.6: 2 = elenco novo do bioma 1 (ver migrate())
		Cash = Config.Start.Cash,
		CarId = "starter",
		Cars = { starter = { Engine = 0 } },
		Animes = {},          -- { Uid, Id, Mut, Size, Placed, Slot }
		NextUid = 1,
		PlotSlots = Config.Farm.StartSlots,
		GiftClaimed = false,
		Index = {},           -- [animeId] = true (coleção descoberta)
		Stats = { Captures = 0, Hatches = 0, BestBiome = 0, PlayTime = 0, Escapes = 0, EscapesLost = 0 },
		Settings = settingsDefaults(),  -- menu CONFIGS (replicado como atributos "Set_<Key>")
		-- Beta 1.3: incubadora (ovos salvos na fuga chocando na base). Ver Services.IncubatorService.
		-- { IncId, Biome, Id, Mut, Size, Odds, Start, ReadyAt }  (Start/ReadyAt = os.time(): o tempo conta offline)
		Incubator = {},
		NextIncId = 1,
		-- Beta 1.5: roleta da sorte (Services.WheelService). LastSpin = os.time() do último giro (conta offline);
		-- Pending = Cash sorteado que ainda não foi pago (pago quando a roda para ou no próximo login).
		-- Beta 1.7: Tokens = giros EXTRAS (pacotes Robux / prêmio "+2 Spins"), PendingSpins = giros ganhos ainda não
		-- entregues (entram quando a roda para), Receipts = PurchaseIds já entregues (anti-duplicação, guarda os 50 últimos).
		Wheel = { LastSpin = 0, Spins = 0, Pending = 0, Tokens = 0, PendingSpins = 0, Receipts = {} },
	}
end

local function reconcile(data, def)
	for k, v in pairs(def) do
		if data[k] == nil then data[k] = Util.DeepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" then reconcile(data[k], v) end
	end
end

-- Beta 1.6: MIGRAÇÃO de saves. Version 1 -> 2: troca os Ids do elenco anterior do bioma 1 pelo elenco novo
-- (Config.AnimeMigrations) no inventário, na incubadora e no Index. Roda uma vez por save (depois Version = 2).
local function migrate(data)
	if (data.Version or 1) >= 2 then return end
	local map = Config.AnimeMigrations or {}
	for _, e in ipairs(data.Animes or {}) do if map[e.Id] then e.Id = map[e.Id] end end
	for _, e in ipairs(data.Incubator or {}) do if map[e.Id] then e.Id = map[e.Id] end end
	local idx = {}
	for id, v in pairs(data.Index or {}) do idx[map[id] or id] = v end
	data.Index = idx
	data.Version = 2
end

local function acquire(player)
	local s = getStore()
	if not s then return false, nil, "NoStore" end
	local acquired, loaded = false, nil
	local ok, err = pcall(function()
		s:UpdateAsync(keyOf(player), function(old)
			acquired = false
			if old and old.Lock and old.Lock.JobId ~= game.JobId and (os.time() - old.Lock.Time) < Config.Data.LockTimeout then
				return nil -- travado por outro servidor
			end
			old = old or {}
			old.Lock = { JobId = game.JobId, Time = os.time() }
			acquired, loaded = true, old.Data
			return old
		end)
	end)
	if not ok then return false, nil, tostring(err) end
	if not acquired then return false, nil, "Locked" end
	return true, loaded, nil
end

local function save(player, release)
	local p = profiles[player]
	if not p or not p.Persistent then return true end
	p.Data.Stats.PlayTime = (p.Data.Stats.PlayTime or 0) + (os.clock() - p.LastSave)
	p.LastSave = os.clock()
	local ok, err = pcall(function()
		getStore():UpdateAsync(keyOf(player), function(old)
			old = old or {}
			if old.Lock and old.Lock.JobId ~= game.JobId and (os.time() - old.Lock.Time) < Config.Data.LockTimeout then
				return nil
			end
			old.Data = p.Data
			old.Lock = (not release) and { JobId = game.JobId, Time = os.time() } or nil
			return old
		end)
	end)
	if not ok then warn("[DataService] erro ao salvar " .. player.Name .. ": " .. tostring(err)) end
	return ok
end

local function loadPlayer(player)
	local data, persistent, noApi = nil, false, false
	for attempt = 1, Config.Data.LoadRetries do
		if not player.Parent then return end
		local ok, loaded, err = acquire(player)
		if ok then data, persistent = loaded, true; break end
		-- Studio sem "Enable Studio Access to API Services": a mensagem real é
		-- "403: Cannot write to DataStore from studio if API access is not enabled." (minúsculas!)
		local low = err and tostring(err):lower() or ""
		if RunService:IsStudio() and (err == "NoStore" or low:find("studio") or low:find("api access") or low:find("api services") or low:find("403")) then
			noApi = true; break
		end
		warn(("[DataService] tentativa %d falhou para %s: %s"):format(attempt, player.Name, tostring(err)))
		task.wait(2 + attempt)
	end
	if not persistent and not noApi then
		player:Kick("Não foi possível carregar seus dados. Entre novamente em instantes.")
		return
	end
	if noApi then warn("[DataService] Studio sem acesso à API de DataStore: usando dados TEMPORÁRIOS (não salvam).") end
	data = data or defaults()
	local oldVersion = data.Version or 1
	reconcile(data, defaults())
	data.Version = oldVersion -- reconcile não sobrescreve, mas garante que saves sem Version contem como 1
	migrate(data)
	profiles[player] = { Data = data, Persistent = persistent, LastSave = os.clock() }
	DataService.PushAttributes(player)
	for _, fn in ipairs(onLoaded) do task.spawn(fn, player, data) end
end

local function onRemoving(player)
	for _, fn in ipairs(onLeaving) do pcall(fn, player) end
	if profiles[player] then save(player, true); profiles[player] = nil end
end

-- Beta 1.5: placar do Roblox (leaderstats). Espelha o Cash — a fonte da verdade continua sendo data.Cash.
local function syncLeaderstats(player, cash)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player end
	local v = ls:FindFirstChild("Cash")
	if not v then v = Instance.new("NumberValue"); v.Name = "Cash"; v.Parent = ls end
	v.Value = math.floor(cash)
end

function DataService.Get(player) local p = profiles[player]; return p and p.Data end
-- Salva já (sem esperar o autosave). Usado depois de ações importantes como o giro da roleta.
function DataService.SaveNow(player) if profiles[player] then task.spawn(save, player, false) end end
-- Beta 1.7: salva ESPERANDO o resultado (compras com Robux: só confirma o recibo depois de salvo). true = ok.
function DataService.SaveSync(player) if not profiles[player] then return false end return save(player, false) end
function DataService.WaitFor(player)
	local t = 0
	while not profiles[player] and player.Parent and t < 30 do task.wait(0.1); t += 0.1 end
	return DataService.Get(player)
end
function DataService.PushAttributes(player)
	local d = DataService.Get(player); if not d then return end
	player:SetAttribute("Cash", d.Cash)
	syncLeaderstats(player, d.Cash)
	player:SetAttribute("CarId", d.CarId)
	player:SetAttribute("GiftClaimed", d.GiftClaimed)
	player:SetAttribute("PlotSlots", d.PlotSlots)
	for _, s in ipairs(Config.Settings) do player:SetAttribute("Set_" .. s.Key, d.Settings[s.Key]) end
end
function DataService.AddCash(player, amount)
	local d = DataService.Get(player); if not d or amount ~= amount then return 0 end
	d.Cash += amount
	player:SetAttribute("Cash", d.Cash)
	syncLeaderstats(player, d.Cash)
	return d.Cash
end
function DataService.TrySpend(player, cost)
	local d = DataService.Get(player)
	if not d or cost ~= cost or d.Cash < cost then return false end
	d.Cash -= cost
	player:SetAttribute("Cash", d.Cash)
	syncLeaderstats(player, d.Cash)
	return true
end
function DataService.OnLoaded(fn)
	table.insert(onLoaded, fn)
	for pl, p in pairs(profiles) do task.spawn(fn, pl, p.Data) end
end
function DataService.OnLeaving(fn) table.insert(onLeaving, fn) end

function DataService.Init()
	-- Menu CONFIGS: o cliente pede para mudar UMA configuração (só chaves conhecidas, só booleanos).
	Net.Handle("SaveSettings", function(player, key, value)
		local d = DataService.Get(player)
		if not d or type(key) ~= "string" or type(value) ~= "boolean" then return { ok = false } end
		local known = false
		for _, s in ipairs(Config.Settings) do if s.Key == key then known = true end end
		if not known then return { ok = false, err = "Invalid" } end
		d.Settings[key] = value
		player:SetAttribute("Set_" .. key, value)
		return { ok = true }
	end, 0.15)
	Players.PlayerAdded:Connect(function(pl) task.spawn(loadPlayer, pl) end)
	for _, pl in ipairs(Players:GetPlayers()) do task.spawn(loadPlayer, pl) end
	Players.PlayerRemoving:Connect(onRemoving)
	game:BindToClose(function()
		local pending = 0
		for pl in pairs(profiles) do
			pending += 1
			task.spawn(function() pcall(onRemoving, pl); pending -= 1 end)
		end
		local t = 0
		while pending > 0 and t < 25 do task.wait(0.1); t += 0.1 end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for pl in pairs(profiles) do task.spawn(save, pl, false); task.wait(0.5) end
		end
	end)
end

return DataService
