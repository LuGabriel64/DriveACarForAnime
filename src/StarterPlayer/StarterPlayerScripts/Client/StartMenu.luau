--[[
	StartMenu (Beta 1.1): TELA DE INÍCIO + ESCOLHA DE GARAGEM + painéis CONFIGS / CREDITS / UPDATES.
	FLUXO: entrar no jogo => câmera girando sobre as garagens, logo animada, botões
	       START   => escolher garagem (◀ ▶, câmera voa até cada uma; ocupadas ficam bloqueadas) => CHOOSE
	                  => servidor "ClaimGarage" => o jogador nasce A PÉ na garagem e o HUD aparece
	       CONFIGS => painel "Settings" (o mesmo do botão ⚙ no jogo) | CREDITS / UPDATES => textos do Config
	Textos de créditos/atualizações: Config.Credits / Config.Updates. Liga/desliga: Config.Features.StartMenu.
	O menu fica numa ScreenGui com DisplayOrder 4 (abaixo da GameUI = 5), então os painéis abrem POR CIMA dele.
]]
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Notify = require(script.Parent.Notify)
local HUD = require(script.Parent.HUD)
local new, C = UIKit.New, UIKit.C
local lp = Players.LocalPlayer

local StartMenu = {}
local menuGui, orbitConn, blur
local inMenu = false

-- ============================================================ painéis (também usados no jogo)
local function buildSettings()
	local p = UIKit.Panel({ Name = "Settings", Title = "⚙️ Configs", HeaderColor = Color3.fromRGB(60, 120, 255), Size = UDim2.fromScale(0.5, 0.66), MaxSize = Vector2.new(560, 470) })
	local list = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 22 }, p.Body)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	for i, s in ipairs(Config.Settings) do
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = C.CardBg, LayoutOrder = i, ZIndex = 22 }, list)
		new("UICorner", { CornerRadius = UDim.new(0, 14) }, row); UIKit.Stroke(row, 3)
		UIKit.Text(row, { Text = s.Label, TextSize = 24, AlignX = Enum.TextXAlignment.Left, Size = UDim2.new(1, -130, 0, 32), Position = UDim2.fromOffset(16, 8), Stroke = 3, ZIndex = 23 })
		UIKit.Text(row, { Text = s.Desc, TextSize = 15, AlignX = Enum.TextXAlignment.Left, Color = Color3.fromRGB(180, 180, 205), Size = UDim2.new(1, -130, 0, 24),
			Position = UDim2.fromOffset(16, 40), Scaled = true, Stroke = 2, ZIndex = 23 })
		-- interruptor (pílula com bolinha)
		local sw = new("TextButton", { Size = UDim2.fromOffset(84, 40), Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Text = "",
			AutoButtonColor = false, BackgroundColor3 = C.Grey, ZIndex = 23 }, row)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, sw); UIKit.Stroke(sw, 3)
		local knob = new("Frame", { Size = UDim2.fromOffset(32, 32), Position = UDim2.new(0, 4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = C.White, ZIndex = 24 }, sw)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob); UIKit.Stroke(knob, 2)
		local function paint()
			local on = lp:GetAttribute("Set_" .. s.Key)
			if on == nil then on = s.Default end
			UIKit.Tween(sw, 0.18, { BackgroundColor3 = on and C.Green or C.Grey })
			UIKit.Tween(knob, 0.18, { Position = on and UDim2.new(1, -36, 0.5, 0) or UDim2.new(0, 4, 0.5, 0) }, Enum.EasingStyle.Back)
		end
		sw.Activated:Connect(function()
			UIKit.PlaySound("Click")
			local on = lp:GetAttribute("Set_" .. s.Key)
			if on == nil then on = s.Default end
			Net.Call("SaveSettings", s.Key, not on)
			paint()
		end)
		lp:GetAttributeChangedSignal("Set_" .. s.Key):Connect(paint)
		paint()
	end
	-- Beta 1.5: versão visível também no painel de configurações (vem de Config.Version)
	UIKit.Text(list, { Name = "VersionFooter", Text = Config.GameName .. "  •  " .. Config.Version, TextSize = 16, Color = Color3.fromRGB(170, 170, 200),
		Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 999, Stroke = 2, ZIndex = 23 })
end

local function textPanel(name, title, color, fill)
	local p = UIKit.Panel({ Name = name, Title = title, HeaderColor = color, Size = UDim2.fromScale(0.5, 0.7), MaxSize = Vector2.new(560, 500) })
	local scroll = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22 }, p.Body)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	local order = 0
	local function line(text, size, col, h)
		order += 1
		return UIKit.Text(scroll, { Text = text, TextSize = size, Color = col or C.White, Size = UDim2.new(1, -10, 0, h or (size + 10)), AlignX = Enum.TextXAlignment.Left,
			Wrapped = true, Stroke = 2.5, ZIndex = 23, LayoutOrder = order })
	end
	fill(line)
end

-- ============================================================ câmera e efeitos de fundo
local function startOrbit()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	orbitConn = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - t0) * 0.06
		local center = Config.Lobby.Origin + Vector3.new(0, 10, 0) -- gira sobre o lobby flutuante
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(a) * 240, 95, math.cos(a) * 240), center)
	end)
end
local function stopOrbit() if orbitConn then orbitConn:Disconnect(); orbitConn = nil end end

local function freeze(on)
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.WalkSpeed = on and 0 or 16
	hum.JumpPower = on and 0 or 50
	hum.JumpHeight = on and 0 or 7.2
end

local function sparkles(parent)
	for _ = 1, 22 do
		local s = new("Frame", { Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromHSV(math.random(), 0.5, 1), BorderSizePixel = 0,
			Position = UDim2.fromScale(math.random(), 1.1), Rotation = 45, ZIndex = 2 }, parent)
		new("UICorner", { CornerRadius = UDim.new(0, 2) }, s)
		task.spawn(function()
			task.wait(math.random() * 6)
			while s.Parent do
				local x = math.random()
				local dur = 5 + math.random() * 5
				s.Position = UDim2.fromScale(x, 1.05); s.BackgroundTransparency = 0.2
				UIKit.Tween(s, dur, { Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.1, -0.05), BackgroundTransparency = 0.8, Rotation = 45 + 360 }, Enum.EasingStyle.Linear)
				task.wait(dur)
			end
		end)
	end
end

-- ============================================================ entrar no jogo
local function enterGame(index)
	inMenu = false
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 100 }, menuGui)
	flash.BackgroundTransparency = 1
	UIKit.Tween(flash, 0.25, { BackgroundTransparency = 0 })
	task.wait(0.28)
	stopOrbit()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	-- câmera logo atrás do personagem (senão ela herdaria a distância da vista do seletor de garagem)
	local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if root then cam.CFrame = CFrame.lookAt((root.CFrame * CFrame.new(0, 7, 16)).Position, root.Position + Vector3.new(0, 2, 0)) end
	freeze(false)
	if blur then TweenService:Create(blur, TweenInfo.new(0.5), { Size = 0 }):Play() end
	HUD.SetVisible(true)
	for _, c in ipairs(menuGui:GetChildren()) do if c ~= flash then c:Destroy() end end
	UIKit.Tween(flash, 0.6, { BackgroundTransparency = 1 })
	task.delay(0.7, function() menuGui:Destroy(); if blur then blur:Destroy() end end)
	-- Beta 1.4: dicas do lobby novo (só a pé, PLAY no dock, ovo gigante no fim de cada bioma)
	Notify.Toast(("🌸 Welcome to the Sakura Lobby! Garage %d is yours."):format(index), "good")
	task.delay(3.5, function() Notify.Toast("▶ Press PLAY (or walk into the Race Gate) to start your solo race!", "info") end)
	task.delay(7, function() Notify.Toast("🥚 Grab the Giant Egg at the end of a biome and escape back to base!", "info") end)
end

-- ============================================================ escolha de garagem
local function buildPicker(onBack)
	local root = new("Frame", { Name = "Picker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10 }, menuGui)
	local title = UIKit.Text(root, { Text = "CHOOSE YOUR GARAGE", TextSize = 56, Size = UDim2.fromOffset(900, 66), Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 6, ZIndex = 11 })
	UIKit.Gradient(title, Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 140, 40))
	UIKit.Text(root, { Text = "Your characters live here and earn money for you!", TextSize = 22, Size = UDim2.fromOffset(800, 30), Position = UDim2.new(0.5, 0, 0, 116),
		AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 3, ZIndex = 11 })

	local card = new("Frame", { Size = UDim2.fromOffset(440, 190), Position = UDim2.new(0.5, 0, 1, -40), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = C.PanelBg, ZIndex = 11 }, root)
	new("UICorner", { CornerRadius = UDim.new(0, 22) }, card)
	local cst = UIKit.Stroke(card, 5)
	UIKit.SpinGradient(cst, ColorSequence.new(Color3.fromRGB(0, 205, 255), Color3.fromRGB(255, 70, 255)), 70)
	local nameL = UIKit.Text(card, { Text = "GARAGE 1", TextSize = 44, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 10), Stroke = 5, ZIndex = 12 })
	local status = new("Frame", { Size = UDim2.fromOffset(220, 32), Position = UDim2.new(0.5, 0, 0, 66), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.Green, ZIndex = 12 }, card)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, status); UIKit.Stroke(status, 2.5)
	local statusL = UIKit.Text(status, { Text = "FREE", TextSize = 20, Scaled = true, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), Stroke = 2.5, ZIndex = 13 })
	local dots = new("Frame", { Size = UDim2.fromOffset(8 * 22, 14), Position = UDim2.new(0.5, 0, 0, 106), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 12 }, card)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }, dots)
	local choose
	local garages, index = {}, 1

	local function dotPaint()
		for _, d in ipairs(dots:GetChildren()) do if d:IsA("Frame") then d:Destroy() end end
		for i, g in ipairs(garages) do
			local d = new("Frame", { Size = UDim2.fromOffset(i == index and 18 or 12, i == index and 18 or 12), BackgroundColor3 = g.Taken and C.Red or C.Green, LayoutOrder = i, ZIndex = 13 }, dots)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, d); UIKit.Stroke(d, 2)
		end
	end
	local function show(i, instant)
		if #garages == 0 then return end
		index = (i - 1) % #garages + 1
		local g = garages[index]
		nameL.Text = "GARAGE " .. g.Index
		UIKit.Pop(nameL, 1.1)
		status.BackgroundColor3 = g.Taken and C.Red or C.Green
		statusL.Text = g.Taken and ("TAKEN" .. (g.Owner and (" by " .. g.Owner) or "")) or "✅ FREE"
		UIKit.SetButton(choose, g.Taken and "TAKEN" or "CHOOSE!", g.Taken and C.Grey or C.Green, g.Taken)
		dotPaint()
		if g.Spawn then
			local look = g.Spawn.LookVector
			local camPos = g.Spawn.Position + look * 58 + Vector3.new(0, 12, 0) + g.Spawn.RightVector * 6
			local target = CFrame.lookAt(camPos, g.Spawn.Position + Vector3.new(0, 5, 0))
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Scriptable
			if instant then cam.CFrame = target else TweenService:Create(cam, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = target }):Play() end
		end
	end
	local function refresh(keepIndex)
		local r = Net.Call("GetGarages")
		if not (r and r.ok) then return end
		garages = r.Garages
		if not keepIndex then -- começa na primeira livre
			for i, g in ipairs(garages) do if not g.Taken then index = i; break end end
		end
		show(index, not keepIndex)
	end

	UIKit.Button(card, { Text = "◀", Size = UDim2.fromOffset(62, 62), Position = UDim2.new(0, -78, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = C.Blue, TextSize = 34, ZIndex = 12,
		OnClick = function() show(index - 1) end })
	UIKit.Button(card, { Text = "▶", Size = UDim2.fromOffset(62, 62), Position = UDim2.new(1, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = C.Blue, TextSize = 34, ZIndex = 12,
		OnClick = function() show(index + 1) end })
	local claiming = false
	choose = UIKit.Button(card, { Text = "CHOOSE!", Size = UDim2.new(1, -40, 0, 54), Position = UDim2.new(0.5, 0, 1, -14), AnchorPoint = Vector2.new(0.5, 1), Color = C.Green, TextSize = 32,
		Radius = 14, ZIndex = 12, OnClick = function()
			if claiming or #garages == 0 then return end
			claiming = true
			local g = garages[index]
			local r = Net.Call("ClaimGarage", g.Index)
			if r and r.ok then
				orbitConn = nil
				enterGame(g.Index)
			else
				Notify.Toast("😬 Someone just took that garage! Pick another one.", "error")
				refresh(true)
				claiming = false
			end
		end })
	UIKit.Shine(choose, 2)
	UIKit.Button(root, { Text = "◀ BACK", Size = UDim2.fromOffset(130, 46), Position = UDim2.fromOffset(24, 24), Color = C.Grey, TextSize = 22, ZIndex = 12,
		OnClick = function() root.Visible = false; onBack() end })
	Net.On("GaragesChanged", function() if root.Parent and root.Visible then refresh(true) end end)
	return root, refresh
end

-- ============================================================ tela de título
function StartMenu.Init()
	buildSettings()
	textPanel("Credits", "⭐ Credits", Color3.fromRGB(170, 70, 255), function(line)
		line("DRIVE A CAR FOR ANIME", 30, Color3.fromRGB(255, 200, 60))
		for _, c in ipairs(Config.Credits) do
			line(c.Role, 22, Color3.fromRGB(120, 220, 255))
			line(table.concat(c.Names, "\n"), 20, C.White, 26 * #c.Names)
		end
	end)
	textPanel("Updates", "📜 Updates", Color3.fromRGB(255, 140, 30), function(line)
		for _, u in ipairs(Config.Updates) do
			line(u.Version .. "  •  " .. u.Date, 26, Color3.fromRGB(255, 210, 70))
			for _, n in ipairs(u.Notes) do line(n, 18, C.White, 44) end
		end
	end)

	if not Config.Features.StartMenu then -- sem menu: pega a primeira garagem livre
		task.spawn(function()
			local r = Net.Call("GetGarages")
			for _, g in ipairs(r and r.Garages or {}) do
				if not g.Taken and (Net.Call("ClaimGarage", g.Index) or {}).ok then break end
			end
			HUD.SetVisible(true)
		end)
		return
	end

	inMenu = true
	menuGui = new("ScreenGui", { Name = "StartMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, lp:WaitForChild("PlayerGui"))
	blur = new("BlurEffect", { Name = "MenuBlur", Size = 0 }, Lighting)
	TweenService:Create(blur, TweenInfo.new(1), { Size = 8 }):Play()
	startOrbit()
	freeze(true)
	lp.CharacterAdded:Connect(function() if inMenu then task.wait(0.5); freeze(true) end end)

	local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 6, 30), BackgroundTransparency = 0.35, ZIndex = 1 }, menuGui)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.45, 0.7), NumberSequenceKeypoint.new(1, 0.05) }) }, shade)
	sparkles(menuGui)

	local title = new("Frame", { Name = "Title", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, menuGui)
	-- logo
	local logo = new("Frame", { Size = UDim2.fromOffset(900, 200), Position = UDim2.new(0.5, 0, 0.24, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 4 }, title)
	local l1 = UIKit.Text(logo, { Text = "DRIVE A CAR", TextSize = 92, Size = UDim2.new(1, 0, 0, 100), Stroke = 8, ZIndex = 5 })
	UIKit.Gradient(l1, Color3.fromRGB(255, 240, 90), Color3.fromRGB(255, 120, 30))
	local l2 = UIKit.Text(logo, { Text = "FOR ANIME", TextSize = 80, Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromOffset(0, 96), Stroke = 8, ZIndex = 5 })
	l2.Rotation = -3
	UIKit.Gradient(l2, Color3.fromRGB(255, 120, 220), Color3.fromRGB(150, 70, 255))
	local badge = new("Frame", { Size = UDim2.fromOffset(130, 44), Position = UDim2.new(0.86, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Red, Rotation = 10, ZIndex = 6 }, logo)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, badge); UIKit.Stroke(badge, 3.5)
	UIKit.Text(badge, { Text = Config.Version:upper(), TextSize = 26, Scaled = true, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), Stroke = 3, ZIndex = 7 })
	UIKit.Wobble(badge, 14, 0.7)
	UIKit.Wobble(logo, 1.6, 2.2)
	logo.Position = UDim2.new(0.5, 0, -0.3, 0)
	UIKit.Tween(logo, 0.9, { Position = UDim2.new(0.5, 0, 0.24, 0) }, Enum.EasingStyle.Bounce)

	-- botões
	local col = new("Frame", { Size = UDim2.fromOffset(320, 330), Position = UDim2.new(0.5, 0, 0.66, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 4 }, title)
	new("UIListLayout", { Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, col)
	local picker, refreshPicker
	local function showTitle() title.Visible = true; startOrbit() end
	local startBtn = UIKit.Button(col, { Text = "▶  START", Size = UDim2.fromOffset(320, 84), Color = C.Green, TextSize = 44, Radius = 20, StrokeThickness = 4.5, LayoutOrder = 1, ZIndex = 5,
		OnClick = function()
			title.Visible = false
			stopOrbit()
			if not picker then picker, refreshPicker = buildPicker(showTitle) end
			picker.Visible = true
			refreshPicker(false)
		end })
	UIKit.Shine(startBtn, 1.8)
	local function small(text, color, order, panelName)
		local b = UIKit.Button(col, { Text = text, Size = UDim2.fromOffset(270, 60), Color = color, TextSize = 28, Radius = 16, LayoutOrder = order, ZIndex = 5,
			OnClick = function() UIKit.OpenPanel(panelName) end })
		return b
	end
	small("⚙️  CONFIGS", Color3.fromRGB(60, 120, 255), 2, "Settings")
	small("⭐  CREDITS", Color3.fromRGB(170, 70, 255), 3, "Credits")
	local upd = small("📜  UPDATES", Color3.fromRGB(255, 140, 30), 4, "Updates")
	local newB = new("Frame", { Size = UDim2.fromOffset(64, 28), Position = UDim2.new(1, -6, 0, -8), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Red, Rotation = 12, ZIndex = 8 }, upd)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, newB); UIKit.Stroke(newB, 2.5)
	UIKit.Text(newB, { Text = "NEW!", TextSize = 18, Scaled = true, Size = UDim2.fromScale(0.86, 0.8), Position = UDim2.fromScale(0.07, 0.1), Stroke = 2.5, ZIndex = 9 })
	UIKit.Wobble(newB, 10, 0.5)
	-- entrada dos botões
	for i, b in ipairs(col:GetChildren()) do
		if b:IsA("GuiButton") then
			local s = b:FindFirstChildOfClass("UIScale")
			if s then s.Scale = 0; task.delay(0.5 + b.LayoutOrder * 0.12, function() UIKit.Tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back) end) end
		end
	end

	local names = Config.Credits[1] and table.concat(Config.Credits[1].Names, " & ") or ""
	UIKit.Text(title, { Text = "Made with ❤ by " .. names, TextSize = 18, Color = Color3.fromRGB(220, 220, 240), AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(600, 24), Position = UDim2.new(1, -20, 1, -16), AnchorPoint = Vector2.new(1, 1), Stroke = 2.5, ZIndex = 5 })
	UIKit.Text(title, { Text = Config.GameName .. "  •  " .. Config.Version, TextSize = 18, Color = Color3.fromRGB(220, 220, 240), AlignX = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(500, 24), Position = UDim2.new(0, 20, 1, -16), AnchorPoint = Vector2.new(0, 1), Stroke = 2.5, ZIndex = 5 })
end

return StartMenu
