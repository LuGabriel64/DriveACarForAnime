--[[
	HUD (Beta 1.1): interface fixa durante o jogo.
	  - Topo-esquerda: pílulas de VELOCIDADE (+ abre a loja de carros), DINHEIRO (rolagem animada + "+$" flutuando)
	    e renda/s
	  - Esquerda: menu colorido (Animes, Index, Shop, Gift)  |  Topo-direita: ⚙ configurações
	  - Direita: botão grande DRIVE (traz/entra no carro) ⇄ EXIT (sai do carro)
	  - Topo-centro: nome do bioma + título animado ao entrar em um bioma
	  - Base: velocímetro (só dirigindo) + aviso de BOOST; canto: Home e Reset
	  - Escondido até o jogador escolher a garagem (StartMenu chama HUD.SetVisible(true))
	  - Rótulos com atributo "Rainbow" no mundo (ex.: SECRET nas garagens) ganham arco-íris animado
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Notify = require(script.Parent.Notify)
local Drive = require(script.Parent.DriveController)

local new, C = UIKit.New, UIKit.C
local lp = Players.LocalPlayer
local HUD = {}
local root, zoneTitle, zoneSub, zoneStroke, zoneSubStroke, topBiome, topPill
local titleToken = 0

function HUD.SetVisible(v) if root then root.Visible = v end end

function HUD.OnBiome(id)
	local biome = Config.BiomeById[id]
	-- zonas especiais (Beta 1.2): "lobby" = ilha das garagens | "start" = linha de largada da pista
	local special = {
		lobby = { "🏝️ LOBBY", "Garages • Eggs • Race Portal", "🏝️ Lobby", Color3.fromRGB(90, 220, 255) },
		start = { "🏁 START LINE", "Drive forward — good luck!", "🏁 Start Line", Color3.fromRGB(255, 200, 60) },
	}
	local sp = special[id] or special.lobby
	local T = UIKit.T -- Beta 1.9: zonas especiais no idioma do jogador (nomes de bioma ficam em inglês)
	local name = biome and (biome.Emoji .. " " .. biome.Name:upper()) or T(sp[1])
	local color = biome and biome.Color or sp[4]
	local sub = biome and (T("Tier %d", biome.Tier) .. "  •  " .. Config.Eggs[biome.Id].Name) or T(sp[2])
	topBiome.Text = biome and (biome.Emoji .. " " .. biome.Name) or T(sp[3])
	topPill.BackgroundColor3 = color
	UIKit.Pop(topPill, 1.15)
	titleToken += 1
	local token = titleToken
	zoneTitle.Text, zoneTitle.TextColor3, zoneSub.Text = name, color, sub
	zoneTitle.Position = UDim2.new(0.5, 0, 0.17, -40)
	zoneTitle.TextTransparency, zoneStroke.Transparency, zoneSub.TextTransparency, zoneSubStroke.Transparency = 1, 1, 1, 1
	UIKit.Tween(zoneTitle, 0.45, { Position = UDim2.new(0.5, 0, 0.17, 0), TextTransparency = 0 }, Enum.EasingStyle.Back)
	UIKit.Tween(zoneStroke, 0.3, { Transparency = 0 })
	UIKit.Tween(zoneSub, 0.4, { TextTransparency = 0 }); UIKit.Tween(zoneSubStroke, 0.4, { Transparency = 0 })
	task.delay(2.8, function()
		if token ~= titleToken then return end
		UIKit.Tween(zoneTitle, 0.5, { TextTransparency = 1 }); UIKit.Tween(zoneStroke, 0.5, { Transparency = 1 })
		UIKit.Tween(zoneSub, 0.5, { TextTransparency = 1 }); UIKit.Tween(zoneSubStroke, 0.5, { Transparency = 1 })
	end)
end

local function scanRainbow(container)
	local function check(d)
		if d:IsA("TextLabel") and d:GetAttribute("Rainbow") then UIKit.Rainbow(d) end
		if d:IsA("TextLabel") and d:GetAttribute("Void") then UIKit.VoidText(d) end
	end
	for _, d in ipairs(container:GetDescendants()) do check(d) end
	container.DescendantAdded:Connect(check)
end

function HUD.Init()
	local gui = UIKit.GetGui()
	root = new("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = not Config.Features.StartMenu }, gui)

	-- ---------- moedas (topo-esquerda)
	local cur = new("Frame", { Name = "Currency", Size = UDim2.fromOffset(260, 160), Position = UDim2.fromOffset(14, 8), BackgroundTransparency = 1 }, root)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, cur)
	local function pill(order, icon, color, tint)
		local f = new("Frame", { Name = "Pill", Size = UDim2.fromOffset(250, 56), BackgroundColor3 = tint, LayoutOrder = order }, cur)
		new("UICorner", { CornerRadius = UDim.new(0, 16) }, f)
		local st = UIKit.Stroke(f, 3.5)
		UIKit.Gradient(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(60, 60, 60), 90)
		local ic = UIKit.Text(f, { Name = "Icon", Text = icon, TextSize = 34, Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(6, 4), Stroke = 0 })
		local v = UIKit.Text(f, { Name = "Value", Text = "0", TextSize = 34, Color = color, Size = UDim2.new(1, -64, 1, 0),
			Position = UDim2.fromOffset(58, 0), AlignX = Enum.TextXAlignment.Left, Stroke = 3.5 })
		return f, v, ic
	end
	local speedPill, speedVal = pill(1, "🏎️", C.Orange, Color3.fromRGB(70, 40, 16))
	UIKit.Button(speedPill, { Name = "Plus", Text = "+", Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(34, 2), Color = C.Gold,
		Radius = 8, StrokeThickness = 2.5, ZIndex = 5, OnClick = function() UIKit.OpenPanel("Garage") end })
	local cashPill, cashVal, cashIcon = pill(2, "💵", C.Cash, Color3.fromRGB(20, 64, 24))
	UIKit.Shine(cashPill, 3.5)
	UIKit.Wobble(cashIcon, 8, 0.9)
	local incomeLabel = UIKit.Text(cur, { Name = "Income", Text = "", TextSize = 20, Color = Color3.fromRGB(190, 255, 170),
		Size = UDim2.fromOffset(250, 24), AlignX = Enum.TextXAlignment.Left, LayoutOrder = 3, Stroke = 2.5 })

	local function updateSpeed() speedVal.Text = Util.FormatNumber(lp:GetAttribute("TopSpeed") or 0) .. " km/h" end
	lp:GetAttributeChangedSignal("TopSpeed"):Connect(function() updateSpeed(); UIKit.Pop(speedPill, 1.08) end)
	updateSpeed()

	-- dinheiro com rolagem animada + "+$" flutuante (agrupado a cada ~1s para não poluir a tela)
	local cashNV = Instance.new("NumberValue")
	cashNV.Value = lp:GetAttribute("Cash") or 0
	local function drawCash() cashVal.Text = "$" .. Util.FormatNumber(math.floor(cashNV.Value)) end
	cashNV.Changed:Connect(drawCash); drawCash()
	local lastCash, pending = cashNV.Value, 0
	lp:GetAttributeChangedSignal("Cash"):Connect(function()
		local target = lp:GetAttribute("Cash") or 0
		local delta = target - lastCash
		UIKit.Tween(cashNV, 0.4, { Value = target })
		if delta < -0.5 and root.Visible then
			UIKit.FloatText(root, "-$" .. Util.FormatNumber(math.floor(-delta)), Color3.fromRGB(255, 90, 90), UDim2.fromOffset(270, 98), 24)
		elseif delta > 0 then
			pending += delta
			if delta > math.max(50, lastCash * 0.12) then UIKit.Pop(cashPill, 1.1) end
		end
		lastCash = target
	end)
	task.spawn(function()
		while root.Parent do
			task.wait(1)
			if pending >= 1 and root.Visible then
				UIKit.FloatText(root, "+$" .. Util.FormatNumber(math.floor(pending)), C.Cash, UDim2.fromOffset(270, 98), 24)
			end
			pending = 0
		end
	end)
	local function updateIncome()
		local cps = lp:GetAttribute("CashPerSec") or 0
		incomeLabel.Text = cps > 0 and ("⚡ +$" .. Util.FormatNumber(cps) .. "/s") or "🥚 Hatch eggs to earn money!"
	end
	lp:GetAttributeChangedSignal("CashPerSec"):Connect(updateIncome); updateIncome()

	-- ---------- menu lateral (cada botão com sua cor)
	-- ancorado logo abaixo das moedas; encolhe em telas baixas (celular deitado) para não cobrir nada
	local menu = new("Frame", { Name = "Menu", Size = UDim2.fromOffset(84, 466), Position = UDim2.fromOffset(14, 182),
		BackgroundTransparency = 1 }, root)
	menu.Visible = not Config.Features.LobbyDock -- Beta 1.4: o Client.LobbyDock (dock inferior) substitui este menu
	local menuScale = new("UIScale", { Scale = 1 }, menu)
	local function fitMenu()
		local h = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 700
		menuScale.Scale = math.clamp((h - 200) / 466, 0.5, 1)
	end
	fitMenu()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitMenu)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, menu)
	-- Beta 1.3: "Garage" = painel My Garage (personagens + incubadora + carros). Só abre na base (Client.InventoryPanel).
	local garageBtn = UIKit.MenuButton(menu, { Icon = "🚘", Label = "Garage", LayoutOrder = 0, Color = Color3.fromRGB(40, 190, 90), StrokeColor = Color3.new(0, 0, 0), OnClick = function() UIKit.TogglePanel("Inventory") end })
	UIKit.Shine(garageBtn, 3)
	UIKit.MenuButton(menu, { Icon = "🐾", Label = "Animes", LayoutOrder = 1, Color = Color3.fromRGB(206, 44, 206), StrokeColor = Color3.new(0, 0, 0), OnClick = function() UIKit.TogglePanel("Animes") end })
	UIKit.MenuButton(menu, { Icon = "📖", Label = "Index", LayoutOrder = 2, Color = Color3.fromRGB(40, 120, 255), StrokeColor = Color3.new(0, 0, 0), OnClick = function() Notify.Toast("📖 The Index is coming soon!", "info") end })
	local shop = UIKit.MenuButton(menu, { Icon = "🛒", Label = "Cars", LayoutOrder = 3, Color = Color3.fromRGB(255, 150, 20), StrokeColor = Color3.new(0, 0, 0), OnClick = function() UIKit.TogglePanel("Garage") end })
	UIKit.Shine(shop, 4)
	local gift = UIKit.MenuButton(menu, { Icon = "🎁", Label = "Gift", LayoutOrder = 4, Color = Color3.fromRGB(30, 200, 230), StrokeColor = Color3.new(0, 0, 0), OnClick = function() UIKit.TogglePanel("Gift") end })
	task.spawn(function() -- o presente balança até ser resgatado
		while gift.Parent and not lp:GetAttribute("GiftClaimed") do
			UIKit.Tween(gift.Icon, 0.35, { Rotation = 14 }, Enum.EasingStyle.Sine); task.wait(0.35)
			UIKit.Tween(gift.Icon, 0.35, { Rotation = -14 }, Enum.EasingStyle.Sine); task.wait(0.35)
		end
		gift.Icon.Rotation = 0
	end)

	-- ---------- configurações (topo-direita)
	local gear = UIKit.MenuButton(root, { Name = "Settings", Icon = "⚙️", Label = "Configs", Size = UDim2.fromOffset(64, 64), Color = Color3.fromRGB(60, 64, 90),
		StrokeColor = Color3.new(0, 0, 0), OnClick = function() UIKit.TogglePanel("Settings") end })
	gear.AnchorPoint = Vector2.new(1, 0); gear.Position = UDim2.new(1, -14, 0, 8)

	-- ---------- bioma (topo-centro)
	topPill = new("Frame", { Name = "BiomePill", Size = UDim2.fromOffset(300, 36), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.White }, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, topPill); UIKit.Stroke(topPill, 3)
	UIKit.Gradient(topPill, Color3.fromRGB(110, 110, 110), Color3.fromRGB(40, 40, 40))
	topBiome = UIKit.Text(topPill, { Name = "BiomeLabel", Text = "🏝️ Lobby", TextSize = 22, Stroke = 3 })
	zoneTitle = UIKit.Text(root, { Name = "ZoneTitle", Text = "", TextSize = 58, Size = UDim2.fromOffset(900, 72),
		Position = UDim2.new(0.5, 0, 0.17, 0), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 6, ZIndex = 30 })
	zoneSub = UIKit.Text(root, { Name = "ZoneSub", Text = "", TextSize = 24, Size = UDim2.fromOffset(700, 30),
		Position = UDim2.new(0.5, 0, 0.17, 48), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 3, ZIndex = 30 })
	zoneStroke, zoneSubStroke = zoneTitle:FindFirstChildOfClass("UIStroke"), zoneSub:FindFirstChildOfClass("UIStroke")
	zoneTitle.TextTransparency, zoneStroke.Transparency, zoneSub.TextTransparency, zoneSubStroke.Transparency = 1, 1, 1, 1
	Net.On("BiomeChanged", HUD.OnBiome)

	-- ---------- botão DRIVE / EXIT (direita)
	local driveBtn
	local busyDrive = false
	driveBtn = UIKit.Button(root, { Name = "Drive", Text = "🚗 DRIVE", Size = UDim2.fromOffset(170, 74), Position = UDim2.new(1, -16, 0.5, 40),
		AnchorPoint = Vector2.new(1, 0.5), Color = C.Green, TextSize = 34, Radius = 18, StrokeThickness = 4, OnClick = function()
			if busyDrive then return end
			busyDrive = true
			local r = Net.Call(Drive.IsDriving() and "ExitCar" or "DriveCar")
			if r and r.ExitCF and lp.Character then -- desce ao lado do carro (o cliente é dono da física do corpo)
				task.wait(0.05)
				lp.Character:PivotTo(r.ExitCF)
			end
			if r and not r.ok and r.err == "NoGarage" then Notify.Toast("🏁 Choose a garage first!", "error") end
			task.delay(0.6, function() busyDrive = false end)
		end })
	UIKit.Shine(driveBtn, 2.2)
	local hint = UIKit.Text(root, { Text = "or press E near your car", TextSize = 15, Color = Color3.fromRGB(220, 220, 240), Size = UDim2.fromOffset(200, 20),
		Position = UDim2.new(1, -16, 0.5, 88), AnchorPoint = Vector2.new(1, 0), AlignX = Enum.TextXAlignment.Right, Stroke = 2 })

	-- ---------- velocímetro + boost
	local meter = new("Frame", { Name = "Speedo", Size = UDim2.fromOffset(280, 100), Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Visible = false }, root)
	local num = UIKit.Text(meter, { Text = "0", TextSize = 56, Size = UDim2.new(1, 0, 0, 56), Stroke = 4.5 })
	UIKit.Text(meter, { Text = "km/h", TextSize = 18, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 18), Color = Color3.fromRGB(205, 205, 225) })
	local barBg = new("Frame", { Size = UDim2.new(1, -24, 0, 14), Position = UDim2.fromOffset(12, 78), BackgroundColor3 = Color3.fromRGB(18, 18, 28) }, meter)
	new("UICorner", { CornerRadius = UDim.new(0, 7) }, barBg); UIKit.Stroke(barBg, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Green }, barBg)
	new("UICorner", { CornerRadius = UDim.new(0, 7) }, fill)
	UIKit.Gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	local boost = UIKit.Text(root, { Name = "Boost", Text = "🔥 BOOST!", TextSize = 42, Color = Color3.fromRGB(255, 190, 40), Size = UDim2.fromOffset(300, 52),
		Position = UDim2.new(0.5, 0, 1, -140), AnchorPoint = Vector2.new(0.5, 1), Stroke = 5, Visible = false })

	-- ---------- Home / Reset
	local reset = UIKit.MenuButton(root, { Name = "Reset", Icon = "🔄", Label = "Reset", Size = UDim2.fromOffset(72, 72), Color = Color3.fromRGB(70, 74, 100), StrokeColor = Color3.new(0, 0, 0) })
	reset.AnchorPoint = Vector2.new(1, 1); reset.Position = UDim2.new(1, -16, 1, -16)
	local cooling = false
	reset.Activated:Connect(function()
		if cooling or not Drive.IsDriving() then return end
		cooling = true
		Net.Call("ResetCar"); Notify.Toast("🔄 Car reset!", "info")
		task.delay(3, function() cooling = false end)
	end)
	local home = UIKit.MenuButton(root, { Name = "Home", Icon = "🏠", Label = "Home", Size = UDim2.fromOffset(72, 72), Color = Color3.fromRGB(70, 74, 100), StrokeColor = Color3.new(0, 0, 0) })
	home.AnchorPoint = Vector2.new(1, 1); home.Position = UDim2.new(1, -96, 1, -16)
	local homing = false
	home.Activated:Connect(function()
		if homing then return end
		homing = true
		local wasRacing = (lp:GetAttribute("RaceState") or "Lobby") ~= "Lobby"
		local r = Net.Call("GoHome")
		if r and r.ok and not wasRacing then Notify.Toast("🏠 Back to your garage!", "info") end -- correndo: a tela de resultados aparece
		task.delay(4, function() homing = false end)
	end)

	-- ---------- loop visual
	local boosting, wasDriving = false, nil
	RunService.RenderStepped:Connect(function()
		local driving = Drive.IsDriving()
		-- Beta 1.4: lobby só a pé => sem DRIVE no lobby (PLAY do dock leva ao grid)
		local walkOnly = Config.Lobby.WalkOnly and not driving and (lp:GetAttribute("RaceState") or "Lobby") == "Lobby"
		driveBtn.Visible = not walkOnly
		hint.Visible = not driving and not walkOnly
		if driving ~= wasDriving then
			wasDriving = driving
			UIKit.SetButton(driveBtn, driving and "🚪 EXIT" or "🚗 DRIVE", driving and C.Red or C.Green)
			hint.Visible = not driving
			reset.Visible = driving
			UIKit.Pop(driveBtn, 1.12)
		end
		meter.Visible = driving
		if driving then
			local s, m = Drive.GetSpeed(), math.max(Drive.GetMaxSpeed(), 1)
			num.Text = tostring(math.floor(s + 0.5))
			local r = math.clamp(s / m, 0, 1)
			fill.Size = UDim2.fromScale(r, 1)
			fill.BackgroundColor3 = C.Green:Lerp(Color3.fromRGB(255, 70, 50), math.clamp((r - 0.5) * 2, 0, 1))
		end
		local b = Drive.IsBoosting()
		-- Beta 1.6: o mesmo letreiro avisa quando o carro passou num pad de lentidão
		local sl = Drive.IsSlowed and Drive.IsSlowed()
		if sl then
			boost.Text, boost.TextColor3 = "🐢 SLOWED!", Color3.fromRGB(255, 80, 100)
		else
			boost.Text, boost.TextColor3 = "🔥 BOOST!", Color3.fromRGB(255, 190, 40)
		end
		if sl and not boost.Visible then UIKit.Pop(boost, 1.4) end
		b = b or sl
		boost.Visible = b
		if b and not boosting then UIKit.Pop(boost, 1.4) end
		boosting = b
	end)

	-- arco-íris nas placas SECRET das garagens
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 30)
		local plots = map and map:WaitForChild("Plots", 30)
		if plots then scanRainbow(plots) end
	end)

	-- Beta 1.9: tamanho por aparelho (Client.Platform). Blocos fixos do HUD ficam menores no celular (a pista
	-- precisa aparecer) e maiores na TV. Só Frames simples: botões do UIKit já têm um UIScale próprio (animação).
	-- (o menu lateral antigo "Menu" fica de fora: ele já tem um UIScale próprio e dois no mesmo objeto brigam)
	for name, kind in pairs({ Currency = "Hud", Speedo = "Hud", BiomePill = "Overlay" }) do
		local o = root:FindFirstChild(name)
		if o and o:IsA("Frame") then UIKit.Platform.Apply(o, kind) end
	end
end

return HUD
