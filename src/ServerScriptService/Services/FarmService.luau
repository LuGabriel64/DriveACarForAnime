--[[
	FarmService (Beta 1.1): a GARAGEM do jogador (onde os personagens rendem $/s).
	(O nome "Farm" ficou por compatibilidade: na UI e no mapa tudo se chama Garage.)

	FLUXO NOVO
	  * Ao entrar, o jogador NÃO recebe garagem automaticamente: ele escolhe na tela de início
	    (ação "ClaimGarage"). A lista de garagens livres vem da ação "GetGarages".
	  * Com a garagem escolhida: os personagens aparecem nos pedestais, a renda começa,
	    o personagem do jogador nasce A PÉ no "PlayerSpawn" da garagem (também ao renascer),
	    e quem se inscreveu em OnGarageClaimed é avisado (CarService estaciona o carro).
	Dados: data.Animes = { {Uid, Id, Mut, Size, Placed, Slot, Stars, Level, XP}, ... }

	Beta 1.9: ESTRELAS e NÍVEL.
	  * incomeOf usa Shared.AnimeStats.Income (base x mutação x tamanho x estrelas x nível). Personagem antigo
	    (0 estrelas, nível 1) rende EXATAMENTE o mesmo que antes.
	  * AddAnime(player, id, mut, size, stars): stars vem do EggRoll (servidor), nunca do cliente.
	  * O evento "Inventory" leva também Stars, Level, XP, XpNext e Power (para a mochila e a batalha).
	  * A placa do pedestal mostra as estrelas e o nível.
	  * FarmService.Refresh(player): recalcula a renda, reenvia a mochila e redesenha as placas (usado pelo
	    ProgressService quando um personagem sobe de nível).
]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local AnimeFactory = require(Shared.AnimeModelFactory)
local AnimeStats = require(Shared.AnimeStats)
local DataService = require(script.Parent.DataService)

local FarmService = {}
local plotOf, placedModels, cashPerSec = {}, {}, {}
local claimedCallbacks = {}

local function incomeOf(entry)
	-- Beta 1.9: a conta mora em Shared.AnimeStats (o cliente usa a MESMA função para mostrar os números).
	return AnimeStats.Income(Config.AnimeById[entry.Id], entry)
end
FarmService.IncomeOf = incomeOf
local function sellValue(entry) return math.floor(incomeOf(entry) * Config.Farm.SellMult) end

local function findEntry(data, uid)
	for i, e in ipairs(data.Animes) do if e.Uid == uid then return e, i end end
end

local function updatePlotTitle(player)
	local plot = plotOf[player]
	local label = plot and plot:FindFirstChild("Label", true)
	if label then
		label.Text = player.DisplayName .. "'s Garage\n$" .. Util.FormatNumber(cashPerSec[player] or 0) .. "/s"
	end
end

-- Renda só existe com garagem escolhida (personagens precisam estar nos pedestais).
local function recompute(player, data)
	local sum, placed = 0, 0
	for _, e in ipairs(data.Animes) do
		if e.Placed then sum += incomeOf(e); placed += 1 end
	end
	if not plotOf[player] then sum = 0 end
	cashPerSec[player] = sum
	player:SetAttribute("CashPerSec", sum)
	player:SetAttribute("PlotUsed", placed)
	player:SetAttribute("PlotSlots", data.PlotSlots)
	updatePlotTitle(player)
end

local function sync(player)
	local data = DataService.Get(player); if not data then return end
	local list = {}
	for _, e in ipairs(data.Animes) do
		local cfg = Config.AnimeById[e.Id]
		local level = AnimeStats.Level(e)
		list[#list + 1] = { Uid = e.Uid, Id = e.Id, Mut = e.Mut, Size = e.Size, Placed = e.Placed or false,
			Income = incomeOf(e), Sell = sellValue(e),
			-- Beta 1.9
			Stars = AnimeStats.Stars(e), Level = level, XP = e.XP or 0, XpNext = AnimeStats.XpToNext(level),
			Power = cfg and math.floor(AnimeStats.Power(cfg, e) + 0.5) or 0 }
	end
	Net.Fire(player, "Inventory", list, data.PlotSlots)
end
FarmService.Sync = sync

-- ---------------------------------------------------------------- modelos nos pedestais
local function removeModel(player, uid)
	local t = placedModels[player]
	if t and t[uid] then t[uid]:Destroy(); t[uid] = nil end
end

local function spawnModel(player, entry)
	local plot = plotOf[player]; if not plot then return end
	local slot = plot.Slots:FindFirstChild("Slot_" .. tostring(entry.Slot)); if not slot then return end
	local cfg = Config.AnimeById[entry.Id]; if not cfg then return end
	removeModel(player, entry.Uid)
	local model = AnimeFactory.Build(cfg, entry.Mut, entry.Size)
	model:PivotTo(slot.CFrame * CFrame.new(0, slot.Size.Y / 2, 0))
	model.Name = "Anime_" .. entry.Uid

	local rar = Config.Rarities[cfg.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"; gui.Adornee = model.PrimaryPart; gui.Size = UDim2.fromOffset(200, 96)
	gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y + 2.5, 0)
	gui.MaxDistance = 130; gui.AlwaysOnTop = false
	local function label(y, h, text, color, size)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1; l.Size = UDim2.new(1, 0, 0, h); l.Position = UDim2.fromOffset(0, y)
		l.Font = Enum.Font.FredokaOne; l.TextSize = size; l.TextColor3 = color; l.Text = text
		local s = Instance.new("UIStroke"); s.Thickness = 2; s.Parent = l
		l.Parent = gui
		return l
	end
	label(0, 22, cfg.Name, Config.RarityText(rar), 17)
	local sub = rar.Label or cfg.Rarity
	if entry.Mut then sub = entry.Mut:upper() .. " " .. sub end
	if entry.Size then sub = entry.Size .. " " .. sub end
	local subL = label(22, 18, sub, entry.Mut and Config.Mutations[entry.Mut].Color or Config.RarityText(rar), 13)
	if rar.Rainbow then subL:SetAttribute("Rainbow", true) end
	if rar.Void and not entry.Mut then subL:SetAttribute("Void", true) end -- Beta 1.7: SECRET preto -- o cliente anima o arco-íris
	-- Beta 1.9: linha de estrelas + nível ("★★★☆☆  Lv 7")
	label(40, 16, AnimeStats.StarText(AnimeStats.Stars(entry)) .. "  Lv " .. AnimeStats.Level(entry), Color3.fromRGB(255, 214, 70), 14)
	label(58, 30, "$" .. Util.FormatNumber(incomeOf(entry)) .. "/s", Color3.fromRGB(90, 255, 80), 24)
	gui.Parent = model.PrimaryPart

	model.Parent = plot.Placed
	placedModels[player] = placedModels[player] or {}
	placedModels[player][entry.Uid] = model
end

local function freeSlot(data)
	local used = {}
	for _, e in ipairs(data.Animes) do if e.Placed and e.Slot then used[e.Slot] = true end end
	for i = 1, data.PlotSlots do if not used[i] then return i end end
end
local function placeEntry(player, data, entry)
	local slot = freeSlot(data)
	if not slot then return false end
	entry.Placed, entry.Slot = true, slot
	spawnModel(player, entry)
	return true
end
local function unplaceEntry(player, entry)
	entry.Placed, entry.Slot = false, nil
	removeModel(player, entry.Uid)
end

-- Concede um personagem novo (usado pelo EggService). Retorna entry, colocadoNaGaragem
-- Beta 1.9: stars (0..5) vem do sorteio do servidor (EggRoll -> IncubatorService). Ausente = 0.
function FarmService.AddAnime(player, animeId, mut, size, stars)
	local data = DataService.Get(player); if not data then return nil end
	local entry = { Uid = data.NextUid, Id = animeId, Mut = mut, Size = size, Placed = false,
		Stars = math.clamp(math.floor(tonumber(stars) or 0), 0, Config.Stars.Max), Level = 1, XP = 0 }
	data.NextUid += 1
	table.insert(data.Animes, entry)
	data.Index[animeId] = true
	local autoPlace = Config.Farm.AutoPlace
	if data.Settings and data.Settings.AutoPlace ~= nil then autoPlace = data.Settings.AutoPlace end
	local placed = false
	if autoPlace then placed = placeEntry(player, data, entry) end
	recompute(player, data); sync(player)
	return entry, placed
end

-- Beta 1.9: algo mudou o valor de um personagem (subiu de nível): renda + mochila + placas dos pedestais.
function FarmService.Refresh(player)
	local data = DataService.Get(player); if not data then return end
	if plotOf[player] then
		for _, e in ipairs(data.Animes) do
			if e.Placed and e.Slot then spawnModel(player, e) end
		end
	end
	recompute(player, data); sync(player)
end
-- Renda atual ($/s) de um jogador (0 sem garagem). Usado pelo VersusService para o prêmio do vencedor.
function FarmService.CashPerSec(player) return cashPerSec[player] or 0 end

-- ---------------------------------------------------------------- garagens (escolha)
local function plotsSorted()
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	if not folder then return {} end
	local plots = folder:GetChildren()
	table.sort(plots, function(a, b) return (a:GetAttribute("PlotIndex") or 0) < (b:GetAttribute("PlotIndex") or 0) end)
	return plots
end
local function plotByIndex(i)
	for _, p in ipairs(plotsSorted()) do if p:GetAttribute("PlotIndex") == i then return p end end
end

function FarmService.GetPlot(player) return plotOf[player] end
function FarmService.GetCarSpawn(player)
	local plot = plotOf[player]
	local spawn = plot and (plot:FindFirstChild("CarSpawn") or plot:FindFirstChild("CarPad"))
	if spawn then return spawn.CFrame * CFrame.new(0, 4.5, 0) end
end
function FarmService.GetPlayerSpawn(player)
	local plot = plotOf[player]
	local sp = plot and plot:FindFirstChild("PlayerSpawn")
	if sp then return sp.CFrame * CFrame.new(0, 3.5, 0) end
	local car = FarmService.GetCarSpawn(player)
	return car and car * CFrame.new(-8, 0, 0)
end
function FarmService.OnGarageClaimed(fn) table.insert(claimedCallbacks, fn) end

local function placeCharacter(player)
	local char = player.Character
	local cf = FarmService.GetPlayerSpawn(player)
	if char and cf then char:PivotTo(cf) end
end

local function claim(player, index)
	local data = DataService.Get(player)
	if not data then return { ok = false, err = "NoData" } end
	if plotOf[player] then return { ok = false, err = "AlreadyHas" } end
	if type(index) ~= "number" or index ~= math.floor(index) then return { ok = false, err = "Invalid" } end
	local plot = plotByIndex(index)
	if not plot then return { ok = false, err = "Invalid" } end
	if plot:GetAttribute("OwnerUserId") ~= 0 then return { ok = false, err = "Taken" } end
	plot:SetAttribute("OwnerUserId", player.UserId)
	plotOf[player] = plot
	player:SetAttribute("Garage", index)

	local physical = #plot.Slots:GetChildren()        -- saves antigos (10 vagas) => vagas físicas (8)
	if data.PlotSlots > physical then data.PlotSlots = physical end
	local used = {}
	for _, e in ipairs(data.Animes) do
		if e.Placed then
			if not e.Slot or e.Slot > data.PlotSlots or used[e.Slot] then e.Slot = freeSlot(data) end
			if e.Slot and not used[e.Slot] then used[e.Slot] = true; spawnModel(player, e)
			else e.Placed, e.Slot = false, nil end
		end
	end
	recompute(player, data); sync(player)
	placeCharacter(player)
	for _, fn in ipairs(claimedCallbacks) do task.spawn(fn, player, plot) end
	Net.FireAll("GaragesChanged")
	return { ok = true, Index = index }
end

local function releasePlot(player)
	local plot = plotOf[player]
	if plot then
		plot.Placed:ClearAllChildren()
		plot:SetAttribute("OwnerUserId", 0)
		local label = plot:FindFirstChild("Label", true)
		if label then label.Text = "Free Garage" end
	end
	plotOf[player], placedModels[player], cashPerSec[player] = nil, nil, nil
	task.defer(function() Net.FireAll("GaragesChanged") end)
end

-- ---------------------------------------------------------------- ações do cliente
local function okSync(player) sync(player); return { ok = true } end

function FarmService.Init()
	DataService.OnLoaded(function(player, data)
		recompute(player, data); sync(player)
		-- ao renascer, volta para a própria garagem
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.2)
			if plotOf[player] then placeCharacter(player) end
		end)
	end)
	DataService.OnLeaving(releasePlot)

	Net.Handle("GetGarages", function()
		local list = {}
		for _, p in ipairs(plotsSorted()) do
			local owner = p:GetAttribute("OwnerUserId") or 0
			local who = owner ~= 0 and Players:GetPlayerByUserId(owner)
			list[#list + 1] = { Index = p:GetAttribute("PlotIndex"), Taken = owner ~= 0, Owner = who and who.DisplayName or nil,
				Spawn = p:FindFirstChild("CarSpawn") and p.CarSpawn.CFrame or nil }
		end
		return { ok = true, Garages = list }
	end, 0.3)
	Net.Handle("ClaimGarage", claim, 0.5)

	Net.Handle("PlaceAnime", function(player, uid)
		local data = DataService.Get(player)
		if not data or type(uid) ~= "number" then return { ok = false } end
		local e = findEntry(data, uid)
		if not e or e.Placed then return { ok = false, err = "Invalid" } end
		if not placeEntry(player, data, e) then return { ok = false, err = "PlotFull" } end
		recompute(player, data); return okSync(player)
	end)
	Net.Handle("PickUpAnime", function(player, uid)
		local data = DataService.Get(player)
		if not data or type(uid) ~= "number" then return { ok = false } end
		local e = findEntry(data, uid)
		if not e or not e.Placed then return { ok = false, err = "Invalid" } end
		unplaceEntry(player, e)
		recompute(player, data); return okSync(player)
	end)
	Net.Handle("SellAnime", function(player, uid)
		local data = DataService.Get(player)
		if not data or type(uid) ~= "number" then return { ok = false } end
		local e, idx = findEntry(data, uid)
		if not e then return { ok = false, err = "Invalid" } end
		local value = sellValue(e)
		removeModel(player, uid)
		table.remove(data.Animes, idx)
		DataService.AddCash(player, value)
		recompute(player, data); sync(player)
		return { ok = true, value = value }
	end)
	Net.Handle("EquipBest", function(player)
		local data = DataService.Get(player); if not data then return { ok = false } end
		local sorted = table.clone(data.Animes)
		table.sort(sorted, function(a, b)
			local ia, ib = incomeOf(a), incomeOf(b)
			if ia ~= ib then return ia > ib end
			return a.Uid < b.Uid
		end)
		local best = {}
		for i = 1, math.min(data.PlotSlots, #sorted) do best[sorted[i].Uid] = true end
		for _, e in ipairs(data.Animes) do if e.Placed and not best[e.Uid] then unplaceEntry(player, e) end end
		for _, e in ipairs(sorted) do if best[e.Uid] and not e.Placed then placeEntry(player, data, e) end end
		recompute(player, data); return okSync(player)
	end, 0.5)

	-- Renda: a cada ~1s paga CashPerSec * tempo decorrido
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock(); local dt = now - last; last = now
			for player, cps in pairs(cashPerSec) do
				if cps > 0 and player.Parent then DataService.AddCash(player, cps * dt) end
			end
		end
	end)
end

return FarmService
