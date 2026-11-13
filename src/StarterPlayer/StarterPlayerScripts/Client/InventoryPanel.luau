--[[
	InventoryPanel (Beta 1.3): "MY GARAGE" — inventário + garagem num painel só, com 3 abas.
	  🐾 CHARACTERS : todos os personagens chocados. EQUIP = coloca num pedestal da garagem (rende $/s),
	                  UNEQUIP = volta para a mochila. EQUIP BEST de 1 toque. (Ações PlaceAnime/PickUpAnime/EquipBest.)
	  🥚 INCUBATOR  : ovos salvos na fuga chocando na base, com barra de progresso e tempo restante ao vivo.
	  🚗 CARS       : carros desbloqueados — SELECT troca o carro que você usa na corrida (ação EquipCar).
	                  Carros ainda não comprados levam ao Car Shop (Client.GaragePanel).
	  Abre SÓ NA BASE (lobby): botão "Garage" do HUD ou prompt "Open Garage" (tecla G) na sua garagem.
	  Tudo o que muda dados passa pelo servidor (que valida); aqui só se desenha o estado recebido:
	    State.Inventory (evento "Inventory"), State.Cars ("CarState"), incubadora ("Incubator" / GetIncubator).
	  Também mostra o aviso quando um ovo choca (evento "Hatched").
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local AnimeFactory = require(Shared.AnimeModelFactory)
local CarFactory = require(Shared.CarFactory)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Notify = require(script.Parent.Notify)
local EggVisuals = require(script.Parent.EggVisuals)
local new, C = UIKit.New, UIKit.C
local lp = Players.LocalPlayer

local T = UIKit.T -- Beta 1.9: textos montados no idioma do jogador
-- Beta 1.9: cada cartão de personagem mostra também ESTRELAS (sobre o retrato), NÍVEL (selo), barra de XP, PODER de
-- batalha e o botão SET PARTNER (o parceiro ganha o XP das corridas 1v1; atributo "Partner", 0 = o mais forte).
-- Os números vêm prontos do servidor no evento "Inventory" (Stars, Level, XP, XpNext, Power).

local InventoryPanel = {}
local panel
local tabs, pages = {}, {}
local current = "Characters"
local incubator = { Slots = Config.Incubator.Slots, List = {} }
local clockOffset = 0          -- os.time do servidor - GetServerTimeNow (normalmente ~0)
local incRows = {}
local charScroll, charInfo, incScroll, incInfo, carScroll, carInfo

local ERR = {
	PlotFull = "🐾 All pedestals are full! Unequip one first.", Invalid = "Something changed, try again.",
	Escaping = "🥚 Not while you're carrying an egg!", NoCash = "💸 Not enough cash!",
}
local function call(name, arg)
	local r = Net.Call(name, arg)
	if r and not r.ok then Notify.Toast(ERR[r.err] or "Couldn't do that.", "error") end
	return r and r.ok
end
local function atBase() return (lp:GetAttribute("RaceState") or "Lobby") == "Lobby" end
local function clear(container)
	for _, ch in ipairs(container:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
end
local function serverNow() return workspace:GetServerTimeNow() + clockOffset end

-- ---------------------------------------------------------------- aba CHARACTERS
local function charCard(e, order)
	local cfg = Config.AnimeById[e.Id]
	if not cfg then return end
	local rar = Config.Rarities[cfg.Rarity]
	local f = new("Frame", { Name = "Char_" .. e.Uid, BackgroundColor3 = C.CardBg, LayoutOrder = order, ZIndex = 22 }, charScroll)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, f)
	UIKit.Stroke(f, 3.5, e.Placed and C.Gold or nil)
	local icon = new("Frame", { Size = UDim2.new(1, -12, 0, 100), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = rar.Color, ZIndex = 23 }, f)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, icon); UIKit.Stroke(icon, 2.5)
	if not UIKit.RarityFx(icon, rar, 70) then UIKit.Gradient(icon, Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 110)) end
	UIKit.Viewport(icon, AnimeFactory.Build(cfg, e.Mut, e.Size), { Dir = Vector3.new(0.35, 0.2, -1), Zoom = 0.95, ZIndex = 24 })
	if e.Placed then
		UIKit.Text(icon, { Text = "✅", TextSize = 22, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(2, 2), Stroke = 0, ZIndex = 25 })
	end
	local rich = ('<font color="#%s">%s</font>'):format(Config.RarityText(rar):ToHex(), rar.Label)
	if e.Mut then rich ..= (' <font color="#%s">%s</font>'):format(Config.Mutations[e.Mut].Color:ToHex(), e.Mut:upper()) end
	if e.Size then rich ..= ' <font color="#ffb400">' .. e.Size .. "</font>" end
	local rl = UIKit.Text(f, { Text = rich, RichText = true, TextSize = 13, Scaled = true, Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(5, 110), Stroke = 2, ZIndex = 23 })
	if rar.Rainbow then UIKit.Rainbow(rl) end
	UIKit.Text(f, { Text = cfg.Name, TextSize = 16, Scaled = true, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 127), Stroke = 2.5, ZIndex = 23 })
	UIKit.Text(f, { Text = "$" .. Util.FormatNumber(e.Income) .. "/s", TextSize = 18, Color = C.Cash, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 148), Stroke = 2.5, ZIndex = 23 })
	-- Beta 1.9: estrelas (faixa sobre o retrato) e nível (selo no canto)
	local stars = e.Stars or 0
	UIKit.Text(icon, { Name = "Stars", Text = string.rep("★", stars) .. string.rep("☆", Config.Stars.Max - stars), TextSize = 17,
		Color = stars > 0 and C.Gold or Color3.fromRGB(200, 200, 215), Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -21), Stroke = 2.5, ZIndex = 26 })
	local lvl = new("Frame", { Name = "Level", Size = UDim2.fromOffset(48, 22), Position = UDim2.new(1, -3, 0, 3), AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(24, 22, 38), ZIndex = 26 }, icon)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, lvl); UIKit.Stroke(lvl, 2)
	UIKit.Text(lvl, { Text = T("Lv %d", e.Level or 1), TextSize = 14, Scaled = true, Size = UDim2.fromScale(0.88, 0.8), Position = UDim2.fromScale(0.06, 0.1), Stroke = 2, ZIndex = 27 })
	-- barra de XP (cheia e dourada no nível máximo)
	local xpBar = new("Frame", { Name = "XP", Size = UDim2.new(1, -16, 0, 15), Position = UDim2.fromOffset(8, 171), BackgroundColor3 = Color3.fromRGB(18, 16, 28), ZIndex = 23 }, f)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, xpBar); UIKit.Stroke(xpBar, 2)
	local frac = e.XpNext and math.clamp((e.XP or 0) / e.XpNext, 0, 1) or 1
	local xpFill = new("Frame", { Size = UDim2.fromScale(math.max(frac, 0.02), 1), BackgroundColor3 = e.XpNext and Color3.fromRGB(70, 170, 255) or C.Gold, BorderSizePixel = 0, ZIndex = 23 }, xpBar)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, xpFill)
	UIKit.Text(xpBar, { Text = e.XpNext and T("XP %d/%d", e.XP or 0, e.XpNext) or T("MAX LEVEL"), TextSize = 11, Stroke = 2, ZIndex = 24 })
	UIKit.Text(f, { Text = "⚔️ " .. T("Power") .. " " .. Util.FormatNumber(e.Power or 0), TextSize = 14, Color = Color3.fromRGB(255, 150, 120),
		Size = UDim2.new(1, -10, 0, 17), Position = UDim2.fromOffset(5, 189), Stroke = 2.5, ZIndex = 23 })
	local partner = (lp:GetAttribute("Partner") or 0) == e.Uid
	UIKit.Button(f, { Name = "Partner", Text = partner and "⭐ PARTNER" or "SET PARTNER", Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 1, -72),
		Color = partner and C.Gold or Color3.fromRGB(120, 80, 220), TextSize = 15, ZIndex = 24,
		OnClick = function()
			if partner then Notify.Toast("Your partner earns XP when you race!", "info"); return end
			call("SetPartner", e.Uid)
		end })
	UIKit.Button(f, { Text = e.Placed and "UNEQUIP" or "EQUIP", Size = UDim2.new(1, -16, 0, 32), Position = UDim2.new(0, 8, 1, -38),
		Color = e.Placed and C.Blue or C.Green, TextSize = 18, ZIndex = 24,
		OnClick = function() call(e.Placed and "PickUpAnime" or "PlaceAnime", e.Uid) end })
end

local function refreshCharacters()
	clear(charScroll)
	local list = table.clone(State.Inventory or {})
	table.sort(list, function(a, b)
		if a.Placed ~= b.Placed then return a.Placed end
		if a.Income ~= b.Income then return a.Income > b.Income end
		return a.Uid < b.Uid
	end)
	local placed, cps = 0, 0
	for i, e in ipairs(list) do
		if e.Placed then placed += 1; cps += e.Income end
		charCard(e, i)
	end
	charInfo.Text = T('🐾 Equipped <font color="#57e63c">%d/%d</font>   ⚡ <font color="#57e63c">$%s/s</font>', placed, State.PlotSlots or 8, Util.FormatNumber(cps))
	if #list == 0 then
		UIKit.Text(charScroll, { Text = "No characters yet! Race to the end of a biome, grab the Giant Egg and escape back to base.",
			TextSize = 20, Wrapped = true, Color = Color3.fromRGB(190, 190, 210), Size = UDim2.fromOffset(440, 90), LayoutOrder = 1, Stroke = 2, ZIndex = 23 })
	end
end

-- ---------------------------------------------------------------- aba INCUBATOR
local function incRow(e, order)
	local cfg = Config.AnimeById[e.Id]
	local rar = cfg and Config.Rarities[cfg.Rarity] or Config.Rarities.Common
	local f = new("Frame", { Size = UDim2.new(1, -6, 0, 96), BackgroundColor3 = C.CardBg, LayoutOrder = order, ZIndex = 22 }, incScroll)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, f)
	local st = UIKit.Stroke(f, 3.5, rar.Color)
	UIKit.RarityFx(st, rar, 120)
	local eggBox = new("Frame", { Size = UDim2.fromOffset(80, 84), Position = UDim2.fromOffset(8, 6), BackgroundTransparency = 1, ZIndex = 23 }, f)
	local vp = UIKit.Viewport(eggBox, EggVisuals.Build(e.Biome, 1), { Dir = Vector3.new(0, 0.12, -1), Zoom = 1.05, ZIndex = 23 })
	local txt = new("Frame", { Size = UDim2.new(1, -110, 1, -12), Position = UDim2.fromOffset(98, 6), BackgroundTransparency = 1, ZIndex = 23 }, f)
	local rich = ('<font color="#%s">%s</font>'):format(Config.RarityText(rar):ToHex(), rar.Label)
	if e.Mut then rich ..= (' <font color="#%s">%s</font>'):format(Config.Mutations[e.Mut].Color:ToHex(), e.Mut:upper()) end
	if e.Size then rich ..= ' <font color="#ffb400">' .. e.Size .. "</font>" end
	UIKit.Text(txt, { Text = rich, RichText = true, TextSize = 15, Size = UDim2.new(1, 0, 0, 18), AlignX = Enum.TextXAlignment.Left, Stroke = 2, ZIndex = 24 })
	UIKit.Text(txt, { Text = cfg and cfg.Name or e.Id, TextSize = 21, Scaled = true, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 18),
		AlignX = Enum.TextXAlignment.Left, Stroke = 2.5, ZIndex = 24 })
	local barBg = new("Frame", { Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(0, 56), BackgroundColor3 = Color3.fromRGB(16, 16, 26), ZIndex = 24 }, txt)
	new("UICorner", { CornerRadius = UDim.new(0, 9) }, barBg); UIKit.Stroke(barBg, 2.5)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = rar.Color, ZIndex = 25 }, barBg)
	new("UICorner", { CornerRadius = UDim.new(0, 9) }, fill)
	UIKit.Gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(160, 160, 160))
	local time = UIKit.Text(txt, { Text = "", TextSize = 20, Color = Color3.fromRGB(150, 230, 255), Size = UDim2.new(0, 104, 0, 24), Position = UDim2.new(1, -104, 0, 53),
		AlignX = Enum.TextXAlignment.Right, Stroke = 2.5, ZIndex = 24 })
	table.insert(incRows, { Fill = fill, Time = time, Vp = vp, Start = e.Start or 0, ReadyAt = e.ReadyAt or 0 })
end

local function refreshIncubator()
	clear(incScroll)
	incRows = {}
	local list = table.clone(incubator.List or {})
	table.sort(list, function(a, b) return (a.ReadyAt or 0) < (b.ReadyAt or 0) end)
	for i, e in ipairs(list) do incRow(e, i) end
	for i = #list + 1, incubator.Slots or Config.Incubator.Slots do
		local f = new("Frame", { Size = UDim2.new(1, -6, 0, 60), BackgroundColor3 = Color3.fromRGB(22, 22, 32), LayoutOrder = 100 + i, ZIndex = 22 }, incScroll)
		new("UICorner", { CornerRadius = UDim.new(0, 14) }, f); UIKit.Stroke(f, 2.5, Color3.fromRGB(70, 70, 90))
		UIKit.Text(f, { Text = "➕ Empty slot — grab a Giant Egg at the end of a biome!", TextSize = 17, Scaled = true, Color = Color3.fromRGB(160, 160, 185),
			Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 17), Stroke = 2, ZIndex = 23 })
	end
	incInfo.Text = ('🥚 Incubator <font color="#ffc828">%d/%d</font>   Eggs hatch here, even while you\'re offline!'):format(#list, incubator.Slots or 6)
end

local function tickIncubator()
	local now = serverNow()
	for _, r in ipairs(incRows) do
		local total = math.max(1, r.ReadyAt - r.Start)
		local left = r.ReadyAt - now
		r.Fill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
		if left <= 0 then
			r.Time.Text = "🐣 Hatching!"
			r.Vp.Rotation = math.sin(os.clock() * 30) * 8
		else
			r.Time.Text = "⏳ " .. Config.FormatDuration(left)
			r.Vp.Rotation = (left < 10) and math.sin(os.clock() * 25) * 6 or 0
		end
	end
end

-- ---------------------------------------------------------------- aba CARS
local function refreshCars()
	clear(carScroll)
	local cs = State.Cars
	if not cs then return end
	local eq = Config.CarById[cs.Equipped] or Config.Cars[1]
	carInfo.Text = ('🚗 <font color="#ffa614">%s</font>   🚀 %s km/h   🔧 Engine Lv %d'):format(eq.Name,
		Util.FormatNumber(lp:GetAttribute("TopSpeed") or eq.MaxSpeed), cs.EngineLevel or 0)
	for i, car in ipairs(Config.Cars) do
		local owned, equipped = cs.Owned[car.Id] ~= nil, cs.Equipped == car.Id
		local f = new("Frame", { Name = car.Id, Size = UDim2.new(0, 184, 1, -8), BackgroundColor3 = owned and Color3.new(1, 1, 1) or Color3.fromRGB(120, 120, 130),
			LayoutOrder = i, ZIndex = 22 }, carScroll)
		new("UICorner", { CornerRadius = UDim.new(0, 14) }, f)
		UIKit.Stroke(f, equipped and 5 or 3.5, equipped and C.Gold or nil)
		if owned then UIKit.Gradient(f, Color3.fromRGB(150, 220, 255), Color3.fromRGB(40, 110, 230)) end
		UIKit.Text(f, { Text = car.Name, TextSize = 22, Scaled = true, Size = UDim2.fromScale(0.92, 0.11), Position = UDim2.fromScale(0.04, 0.03), Stroke = 3, ZIndex = 23 })
		local holder = new("Frame", { Size = UDim2.fromScale(1, 0.42), Position = UDim2.fromScale(0, 0.15), BackgroundTransparency = 1, ZIndex = 23 }, f)
		UIKit.Viewport(holder, CarFactory.Build(car, true), { Dir = Vector3.new(0.7, 0.45, -1), Zoom = 1.0, ZIndex = 23 })
		UIKit.Text(f, { Text = T("Tier %d  •  🚀 %d km/h", car.Tier, car.MaxSpeed), TextSize = 17, Scaled = true, Size = UDim2.fromScale(0.92, 0.09),
			Position = UDim2.fromScale(0.04, 0.6), Stroke = 2.5, ZIndex = 23 })
		if owned then
			UIKit.Text(f, { Text = T("🔧 Engine Lv %d", cs.Owned[car.Id]), TextSize = 15, Scaled = true, Size = UDim2.fromScale(0.92, 0.07),
				Position = UDim2.fromScale(0.04, 0.7), Color = Color3.fromRGB(230, 240, 255), Stroke = 2, ZIndex = 23 })
		end
		local b = UIKit.Button(f, { Text = "", Size = UDim2.fromScale(0.88, 0.14), Position = UDim2.fromScale(0.06, 0.82), ZIndex = 24, TextSize = 20 })
		if equipped then
			UIKit.SetButton(b, "SELECTED", C.Grey, true)
		elseif owned then
			UIKit.SetButton(b, "SELECT", C.Green, false)
			b.Activated:Connect(function()
				if not atBase() then Notify.Toast("🏠 Switch cars at your base!", "error"); return end
				if call("EquipCar", car.Id) then Notify.Toast("🚗 " .. T("%s selected!", car.Name), "good") end
			end)
		else
			UIKit.SetButton(b, "🔒 CAR SHOP", C.Orange, false)
			b.Activated:Connect(function() panel.Close(); task.delay(0.2, function() UIKit.OpenPanel("Garage") end) end)
		end
	end
end

-- ---------------------------------------------------------------- abas / painel
local function refresh()
	if not panel or not panel.IsOpen then return end
	if current == "Characters" then refreshCharacters()
	elseif current == "Incubator" then refreshIncubator()
	else refreshCars() end
end

local TAB_DEF = {
	{ Key = "Characters", Text = "🐾 CHARACTERS", Color = C.Magenta },
	{ Key = "Incubator",  Text = "🥚 INCUBATOR",  Color = C.Orange },
	{ Key = "Cars",       Text = "🚗 CARS",       Color = C.Blue },
}
local function selectTab(key)
	current = key
	for _, d in ipairs(TAB_DEF) do
		local on = d.Key == key
		UIKit.SetButton(tabs[d.Key], nil, on and d.Color or Color3.fromRGB(44, 44, 62), false)
		pages[d.Key].Visible = on
	end
	refresh()
end

local function page(name)
	local p = new("Frame", { Name = name, Size = UDim2.new(1, 0, 1, -58), Position = UDim2.fromOffset(0, 58), BackgroundTransparency = 1, Visible = false, ZIndex = 21 }, panel.Body)
	pages[name] = p
	return p
end
local function infoBar(parent, withButton)
	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.CardBg, ZIndex = 22 }, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, bar); UIKit.Stroke(bar, 3)
	local l = UIKit.Text(bar, { Text = "", RichText = true, TextSize = 19, Scaled = true, AlignX = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, withButton and -190 or -24, 0, 28), Position = UDim2.fromOffset(12, 9), Stroke = 2.5, ZIndex = 23 })
	return bar, l
end

function InventoryPanel.Open() if panel then panel.Open() end end
-- Beta 1.4 (dock): abre direto numa aba ("Characters" | "Incubator" | "Cars"); se já estiver aberto, só troca a aba
function InventoryPanel.OpenTab(key)
	if not panel or not pages[key] then return end
	current = key
	if panel.IsOpen then selectTab(key) else panel.Open() end
end

local function setupGaragePrompt()
	-- prompt "Open Garage" (tecla G) no PlayerSpawn da SUA garagem; recriado se a peça sair/voltar do streaming
	task.spawn(function()
		while true do
			local idx = lp:GetAttribute("Garage")
			local plots = idx and workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
			if plots then
				for _, plot in ipairs(plots:GetChildren()) do
					local sp = plot:FindFirstChild("PlayerSpawn")
					local mine = plot:GetAttribute("PlotIndex") == idx
					local pp = sp and sp:FindFirstChild("OpenGaragePrompt")
					if sp and mine and not pp then
						pp = Instance.new("ProximityPrompt")
						pp.Name = "OpenGaragePrompt"; pp.ActionText = "Open Garage"; pp.ObjectText = "My Garage"
						pp.KeyboardKeyCode = Enum.KeyCode.G; pp.HoldDuration = 0; pp.MaxActivationDistance = 14; pp.RequiresLineOfSight = false
						pp.Triggered:Connect(InventoryPanel.Open)
						pp.Parent = sp
					elseif pp and not mine then
						pp:Destroy()
					end
				end
			end
			task.wait(2)
		end
	end)
end

function InventoryPanel.Init()
	panel = UIKit.Panel({ Name = "Inventory", Title = "🏠 My Garage", HeaderColor = C.Blue, Size = UDim2.fromScale(0.9, 0.86),
		MaxSize = Vector2.new(840, 620), MinSize = Vector2.new(330, 430) })
	-- só abre na base
	local rawOpen = panel.Open
	panel.Open = function()
		if not atBase() then Notify.Toast("🏠 Your Garage opens at the base (lobby)!", "error"); return end
		rawOpen()
	end

	-- abas
	local tabRow = new("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, ZIndex = 21 }, panel.Body)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, tabRow)
	for i, d in ipairs(TAB_DEF) do
		tabs[d.Key] = UIKit.Button(tabRow, { Text = d.Text, Size = UDim2.new(1 / 3, -6, 1, 0), Color = Color3.fromRGB(44, 44, 62), LayoutOrder = i,
			TextSize = 20, ZIndex = 22, OnClick = function() selectTab(d.Key) end })
	end

	-- CHARACTERS
	local pc = page("Characters")
	local bar
	bar, charInfo = infoBar(pc, true)
	UIKit.Button(bar, { Text = "⭐ EQUIP BEST", Size = UDim2.fromOffset(170, 36), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Orange, TextSize = 18, ZIndex = 24, OnClick = function() if call("EquipBest") then Notify.Toast("⭐ Best characters equipped!", "good") end end })
	charScroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -54), Position = UDim2.fromOffset(0, 54), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22 }, pc)
	-- Beta 1.9: célula mais alta (era 148 x 214): + barra de XP, Poder e botão de parceiro
	new("UIGridLayout", { CellSize = UDim2.fromOffset(148, 284), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, charScroll)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) }, charScroll)

	-- INCUBATOR
	local pi = page("Incubator")
	local _incBar
	_incBar, incInfo = infoBar(pi, false)
	incScroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -54), Position = UDim2.fromOffset(0, 54), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22 }, pi)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, incScroll)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) }, incScroll)

	-- CARS
	local pcar = page("Cars")
	local cbar
	cbar, carInfo = infoBar(pcar, true)
	UIKit.Button(cbar, { Text = "🛒 CAR SHOP", Size = UDim2.fromOffset(170, 36), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Orange, TextSize = 18, ZIndex = 24, OnClick = function() panel.Close(); task.delay(0.2, function() UIKit.OpenPanel("Garage") end) end })
	carScroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -54), Position = UDim2.fromOffset(0, 54), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ZIndex = 22 }, pcar)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, carScroll)

	panel.OnOpen = function() selectTab(current) end

	-- estado vindo do servidor
	State.Changed.Event:Connect(function(what)
		if (what == "Inventory" and current == "Characters") or (what == "Cars" and current == "Cars") then refresh() end
	end)
	local function setIncubator(s)
		if type(s) ~= "table" then return end
		incubator = s
		if s.Now then clockOffset = s.Now - workspace:GetServerTimeNow() end
		if current == "Incubator" then refresh() end
	end
	Net.On("Incubator", setIncubator)
	task.spawn(function() setIncubator(Net.Call("GetIncubator")) end)
	Net.On("Hatched", function(info)
		local cfg = info and Config.AnimeById[info.Id]
		if not cfg then return end
		local rar = Config.Rarities[cfg.Rarity]
		Notify.Toast(T("🐣 %s hatched! +$%s/s %s", cfg.Name, Util.FormatNumber(info.Income or 0), T(info.Placed and "(in your garage)" or "(in your backpack)")), "good")
		UIKit.Confetti(UIKit.GetGui(), rar.Color, 16 + rar.Order * 6)
		UIKit.PlaySound(rar.Order >= 4 and "Rare" or "Reveal")
	end)
	-- sai da base (corrida) => fecha
	lp:GetAttributeChangedSignal("RaceState"):Connect(function() if not atBase() and panel.IsOpen then panel.Close() end end)
	RunService.RenderStepped:Connect(function()
		if panel.IsOpen and current == "Incubator" then tickIncubator() end
	end)
	setupGaragePrompt()
	-- Beta 1.9: trocou o parceiro ou o idioma => redesenha os cartões
	lp:GetAttributeChangedSignal("Partner"):Connect(refresh)
	UIKit.Locale.OnChanged(refresh)
end

return InventoryPanel
