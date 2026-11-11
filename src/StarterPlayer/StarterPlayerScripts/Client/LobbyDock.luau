--[[
	LobbyDock (Beta 1.4): MENU FLUTUANTE do lobby + TRANSIÇÃO para a corrida.

	  Dock inferior (dentro do HUD => some junto com ele no menu inicial):
	     🚘 GARAGE     -> My Garage, aba CARS (carro equipado / trocar)        [Client.InventoryPanel]
	     🎒 INVENTORY  -> My Garage, aba CHARACTERS (+ selo com ovos na incubadora)
	     ▶  PLAY       -> transição animada + "StartRace" no servidor (leva o carro ao grid da pista isolada)
	     🛒 SHOP       -> Car Shop                                            [Client.GaragePanel]
	     🎁 GIFT       -> presente (selo "!" até resgatar)                   [Client.GiftPanel]
	  Visual: botões com gradiente vibrante, cantos arredondados, contorno grosso, fonte LuckiestGuy, flutuando
	  (bob), brilho passando, hover = cresce/inclina, clique = "squash". O dock desliza para baixo quando você
	  sai do lobby (corrida) e volta deslizando ao retornar. Tudo com TweenService.

	  ESTADO: depende só do atributo RaceState ("Lobby" | "Countdown" | "Racing") replicado pelo RaceService.
	  TRANSIÇÃO (PLAY ou portal): cortina diagonal rosa/roxa cobre a tela -> servidor teleporta -> cortina sai
	  pela direita e a contagem 3-2-1 do RaceUI aparece. Se o servidor recusar, a cortina sai e um aviso explica.
	  Também desliga o prompt "Drive" do seu carro no lobby (lobby só a pé — Config.Lobby.WalkOnly).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Notify = require(script.Parent.Notify)
local InventoryPanel = require(script.Parent.InventoryPanel)
local WheelPanel = require(script.Parent.WheelPanel) -- Beta 1.5: botão WHEEL (roleta a cada 8 h)
local new, C = UIKit.New, UIKit.C
local lp = Players.LocalPlayer

local LobbyDock = {}
local DISPLAY = Enum.Font.LuckiestGuy
local dock, dockScale, incBadge, giftBadge, wheelBadge
local tGui, wipeA, wipeB, tTitle, tSub, lines
local shown, busy, covered = nil, false, false

local ERR = {
	NoGarage = "🏁 Choose a garage first!", Full = "⏳ All race slots are busy, try again in a moment!",
	AlreadyRacing = "You're already racing!", Dead = "Wait to respawn!",
}
local function inLobby() return (lp:GetAttribute("RaceState") or "Lobby") == "Lobby" end

-- ---------------------------------------------------------------- botão flutuante do dock
local function dockButton(parent, p)
	local holder = new("Frame", { Name = p.Name, Size = p.Size, BackgroundTransparency = 1, LayoutOrder = p.Order }, parent)
	local scale = new("UIScale", { Scale = 1 }, holder)
	local b = new("TextButton", { Name = "Button", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, holder)
	new("UICorner", { CornerRadius = UDim.new(0, p.Radius or 22) }, b)
	UIKit.Stroke(b, 4)
	new("UIGradient", { Color = ColorSequence.new(p.C1, p.C2), Rotation = 90 }, b)
	local inner = new("Frame", { Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), BackgroundTransparency = 1 }, b)
	new("UICorner", { CornerRadius = UDim.new(0, (p.Radius or 22) - 4) }, inner)
	new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Transparency = 0.45 }, inner)
	local icon = UIKit.Text(b, { Name = "Icon", Text = p.Icon, TextSize = p.IconSize or 36, Size = UDim2.new(1, 0, 0.58, 0), Position = UDim2.fromScale(0, 0.05), Stroke = 0, ZIndex = 2 })
	UIKit.Text(b, { Name = "Caption", Text = p.Label, Font = DISPLAY, TextSize = p.LabelSize or 17, Scaled = true, Size = UDim2.new(1, -8, 0.3, 0),
		Position = UDim2.new(0, 4, 0.63, 0), Stroke = 3, ZIndex = 2 })
	UIKit.Shine(b, 3 + p.Order * 0.5)
	-- flutuando (bob) defasado por botão
	task.spawn(function()
		task.wait(p.Order * 0.22)
		while b.Parent do
			UIKit.Tween(b, 1.3, { Position = UDim2.fromOffset(0, -5) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut); task.wait(1.3)
			UIKit.Tween(b, 1.3, { Position = UDim2.fromOffset(0, 1) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut); task.wait(1.3)
		end
	end)
	b.MouseEnter:Connect(function() UIKit.Tween(scale, 0.18, { Scale = 1.1 }, Enum.EasingStyle.Back); UIKit.Tween(icon, 0.18, { Rotation = -10 }) end)
	b.MouseLeave:Connect(function() UIKit.Tween(scale, 0.18, { Scale = 1 }); UIKit.Tween(icon, 0.18, { Rotation = 0 }) end)
	b.MouseButton1Down:Connect(function() UIKit.Tween(scale, 0.07, { Scale = 0.88 }) end)
	b.MouseButton1Up:Connect(function() UIKit.Tween(scale, 0.3, { Scale = 1.06 }, Enum.EasingStyle.Back) end)
	b.Activated:Connect(function()
		UIKit.PlaySound("Click")
		if p.OnClick then task.spawn(p.OnClick) end
	end)
	return holder, b
end

local function badge(parent, text, color)
	local f = new("Frame", { Name = "Badge", Size = UDim2.fromOffset(34, 26), Position = UDim2.new(1, -8, 0, -6), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color, Visible = false, ZIndex = 5 }, parent)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	UIKit.Stroke(f, 2.5)
	UIKit.Text(f, { Name = "Text", Text = text, TextSize = 16, Scaled = true, Size = UDim2.fromScale(0.86, 0.8), Position = UDim2.fromScale(0.07, 0.1), Stroke = 2, ZIndex = 6 })
	return f
end

-- ---------------------------------------------------------------- transição (cortina anime)
local function buildTransition()
	tGui = new("ScreenGui", { Name = "PlayTransition", IgnoreGuiInset = true, DisplayOrder = 30, ResetOnSpawn = false, Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, lp:WaitForChild("PlayerGui"))
	wipeB = new("Frame", { Size = UDim2.fromScale(2.4, 2.4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-1.4, 0.5), Rotation = 14,
		BackgroundColor3 = Color3.fromRGB(255, 205, 80), BorderSizePixel = 0, ZIndex = 1 }, tGui)
	wipeA = new("Frame", { Size = UDim2.fromScale(2.4, 2.4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-1.4, 0.5), Rotation = 14,
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, tGui)
	UIKit.Gradient(wipeA, Color3.fromRGB(255, 110, 200), Color3.fromRGB(110, 60, 230), 0)
	lines = {}
	for i = 1, 16 do -- linhas de velocidade
		lines[i] = new("Frame", { Size = UDim2.new(0, math.random(140, 420), 0, math.random(2, 5)), Position = UDim2.fromScale(1.2, math.random()),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 3 }, tGui)
	end
	tTitle = UIKit.Text(tGui, { Text = "TO THE TRACK!", Font = DISPLAY, TextSize = 84, Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromScale(0, 0.4),
		Stroke = 7, ZIndex = 4 })
	UIKit.Gradient(tTitle, Color3.fromRGB(255, 245, 140), Color3.fromRGB(255, 150, 60), 90)
	tSub = UIKit.Text(tGui, { Text = "🥚 Grab the Giant Egg at the end of a biome & escape!", TextSize = 26, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0.4, 104),
		Stroke = 3, ZIndex = 4 })
	local sc = new("UIScale", { Scale = 1 }, tTitle)
	local vs = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	sc.Scale = math.clamp(vs.X / 900, 0.5, 1)
end

local function speedLines()
	task.spawn(function()
		while covered do
			for _, l in ipairs(lines) do
				if l.Position.X.Scale < -0.4 then l.Position = UDim2.fromScale(1.1 + math.random() * 0.4, math.random()) end
				l.Position -= UDim2.fromScale(0.06 + (l.Size.Y.Offset * 0.01), 0)
			end
			task.wait(1 / 60)
		end
	end)
end

function LobbyDock.CoverIn(fast)
	if covered then return end
	covered = true
	tGui.Enabled = true
	local t = fast and 0.25 or 0.42
	wipeB.Position = UDim2.fromScale(-1.4, 0.5); wipeA.Position = UDim2.fromScale(-1.4, 0.5)
	tTitle.TextTransparency, tSub.TextTransparency = 1, 1
	for _, s in ipairs({ tTitle:FindFirstChildOfClass("UIStroke"), tSub:FindFirstChildOfClass("UIStroke") }) do s.Transparency = 1 end
	UIKit.Tween(wipeB, t, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	task.delay(0.06, function() UIKit.Tween(wipeA, t, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out) end)
	speedLines()
	task.delay(t * 0.7, function()
		UIKit.Tween(tTitle, 0.25, { TextTransparency = 0 }); UIKit.Tween(tSub, 0.25, { TextTransparency = 0 })
		for _, s in ipairs({ tTitle:FindFirstChildOfClass("UIStroke"), tSub:FindFirstChildOfClass("UIStroke") }) do UIKit.Tween(s, 0.25, { Transparency = 0 }) end
		UIKit.Pop(tTitle, 1.4)
	end)
	task.wait(t + 0.08)
end

function LobbyDock.CoverOut()
	if not covered then return end
	UIKit.Tween(tTitle, 0.2, { TextTransparency = 1 }); UIKit.Tween(tSub, 0.2, { TextTransparency = 1 })
	for _, s in ipairs({ tTitle:FindFirstChildOfClass("UIStroke"), tSub:FindFirstChildOfClass("UIStroke") }) do UIKit.Tween(s, 0.2, { Transparency = 1 }) end
	UIKit.Tween(wipeA, 0.45, { Position = UDim2.fromScale(2.4, 0.5) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	task.delay(0.07, function() UIKit.Tween(wipeB, 0.45, { Position = UDim2.fromScale(2.4, 0.5) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In) end)
	task.wait(0.55)
	covered = false
	tGui.Enabled = false
end

-- ---------------------------------------------------------------- PLAY: lobby -> corrida
function LobbyDock.Play()
	if busy or not inLobby() then return end
	busy = true
	for _, pnl in pairs(UIKit.Panels) do if pnl.IsOpen then pnl.Close() end end
	LobbyDock.CoverIn(false)
	local r = Net.Call("StartRace")
	if not (r and r.ok) then
		LobbyDock.CoverOut()
		Notify.Toast(ERR[r and r.err] or "Couldn't start the race.", "error")
		busy = false
		return
	end
	-- espera o servidor levar o carro ao grid (RaceState sai de "Lobby") + um instante para o streaming da pista
	local t0 = os.clock()
	while inLobby() and os.clock() - t0 < 5 do task.wait(0.05) end
	task.wait(0.45)
	LobbyDock.CoverOut()
	busy = false
end

-- ---------------------------------------------------------------- mostrar / esconder o dock
local function setShown(v)
	if shown == v then return end
	shown = v
	if v then
		dock.Visible = true
		dock.Position = UDim2.new(0.5, 0, 1, 170)
		UIKit.Tween(dock, 0.5, { Position = UDim2.new(0.5, 0, 1, -12) }, Enum.EasingStyle.Back)
	else
		local tw = UIKit.Tween(dock, 0.3, { Position = UDim2.new(0.5, 0, 1, 170) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Connect(function() if not shown then dock.Visible = false end end)
	end
end

function LobbyDock.Init()
	if not Config.Features.LobbyDock then return end
	local gui = UIKit.GetGui()
	local hud = gui:WaitForChild("HUD", 10) or gui
	dock = new("Frame", { Name = "LobbyDock", Size = UDim2.fromOffset(720, 132), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1, ZIndex = 5 }, hud)
	dockScale = new("UIScale", { Scale = 1 }, dock)
	local function fit()
		local vs = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		dockScale.Scale = math.clamp(math.min((vs.X - 24) / 720, (vs.Y * 0.24) / 132), 0.45, 1)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	-- base de vidro com borda em gradiente girando (rosa -> ciano)
	local glass = new("Frame", { Name = "Glass", Size = UDim2.new(1, 0, 0, 96), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(24, 12, 46), BackgroundTransparency = 0.22 }, dock)
	new("UICorner", { CornerRadius = UDim.new(0, 48) }, glass)
	local gst = new("UIStroke", { Thickness = 3.5, Color = Color3.new(1, 1, 1) }, glass)
	UIKit.SpinGradient(gst, ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 210)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 220, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 110, 210)) }), 60)

	local row = new("Frame", { Name = "Row", Size = UDim2.new(1, -24, 1, -8), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1 }, dock)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local small = UDim2.fromOffset(88, 84)

	dockButton(row, { Name = "Garage", Icon = "🚘", Label = "GARAGE", Order = 1, Size = small,
		C1 = Color3.fromRGB(110, 230, 255), C2 = Color3.fromRGB(40, 110, 255), OnClick = function() InventoryPanel.OpenTab("Cars") end })
	local inv = dockButton(row, { Name = "Inventory", Icon = "🎒", Label = "INVENTORY", Order = 2, Size = small, LabelSize = 15,
		C1 = Color3.fromRGB(255, 150, 225), C2 = Color3.fromRGB(205, 50, 200), OnClick = function() InventoryPanel.OpenTab("Characters") end })
	local play = dockButton(row, { Name = "Play", Icon = "▶", Label = "PLAY", Order = 3, Size = UDim2.fromOffset(160, 118), Radius = 28,
		IconSize = 50, LabelSize = 34, C1 = Color3.fromRGB(255, 236, 100), C2 = Color3.fromRGB(255, 104, 40), OnClick = LobbyDock.Play })
	dockButton(row, { Name = "Shop", Icon = "🛒", Label = "SHOP", Order = 4, Size = small,
		C1 = Color3.fromRGB(150, 255, 130), C2 = Color3.fromRGB(30, 170, 70), OnClick = function() UIKit.OpenPanel("Garage") end })
	local wheel = dockButton(row, { Name = "Wheel", Icon = "🎡", Label = "WHEEL", Order = 5, Size = small,
		C1 = Color3.fromRGB(255, 225, 110), C2 = Color3.fromRGB(240, 120, 40), OnClick = function() UIKit.TogglePanel("Wheel") end })
	local gift = dockButton(row, { Name = "Gift", Icon = "🎁", Label = "GIFT", Order = 6, Size = small,
		C1 = Color3.fromRGB(200, 160, 255), C2 = Color3.fromRGB(110, 60, 235), OnClick = function() UIKit.TogglePanel("Gift") end })

	-- PLAY: anel pulsando atrás (chama o olho para o botão principal)
	local pulse = new("Frame", { Name = "Pulse", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 }, play)
	new("UICorner", { CornerRadius = UDim.new(0, 28) }, pulse)
	local pst = new("UIStroke", { Thickness = 6, Color = Color3.fromRGB(255, 220, 90) }, pulse)
	local ps = new("UIScale", { Scale = 1 }, pulse)
	task.spawn(function()
		while pulse.Parent do
			ps.Scale, pst.Transparency = 1, 0.1
			UIKit.Tween(ps, 1.1, { Scale = 1.28 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			UIKit.Tween(pst, 1.1, { Transparency = 1 })
			task.wait(1.3)
		end
	end)

	-- selos: ovos na incubadora (INVENTORY) e presente não resgatado (GIFT)
	incBadge = badge(inv, "🥚0", Color3.fromRGB(255, 160, 40))
	giftBadge = badge(gift, "!", C.Red)
	wheelBadge = badge(wheel, "!", C.Green)
	task.spawn(function() -- selo "!" na roleta quando o giro grátis está liberado (relógio do servidor)
		while wheel.Parent do
			local ready = WheelPanel.IsReady()
			if ready and not wheelBadge.Visible then UIKit.Pop(wheelBadge, 1.5) end
			wheelBadge.Visible = ready
			task.wait(1)
		end
	end)
	local function refreshBadges()
		local n = lp:GetAttribute("IncubatorUsed") or 0
		incBadge.Visible = n > 0
		incBadge.Text.Text = "🥚" .. n
		giftBadge.Visible = not lp:GetAttribute("GiftClaimed")
	end
	lp:GetAttributeChangedSignal("IncubatorUsed"):Connect(function() refreshBadges(); UIKit.Pop(incBadge, 1.4) end)
	lp:GetAttributeChangedSignal("GiftClaimed"):Connect(refreshBadges)
	refreshBadges()

	buildTransition()

	-- estado: dock só no lobby | cortina rápida quando a corrida começa pelo PORTAL (sem clicar em PLAY)
	local function onState() setShown(inLobby()) end
	lp:GetAttributeChangedSignal("RaceState"):Connect(onState)
	onState()
	Net.On("RaceCountdown", function()
		if busy or covered then return end
		task.spawn(function()
			LobbyDock.CoverIn(true)
			task.wait(0.5)
			LobbyDock.CoverOut()
		end)
	end)

	-- lobby só a pé: esconde o prompt "Drive" do seu carro estacionado enquanto estiver no lobby
	-- Beta 1.6b: e também enquanto alguém estiver SENTADO no banco (sem "Drive" flutuando com você dentro do carro)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local cars = workspace:FindFirstChild("Cars")
			if cars then
				for _, m in ipairs(cars:GetChildren()) do
					if m:GetAttribute("OwnerUserId") == lp.UserId then
						local pp = m:FindFirstChild("DrivePrompt", true)
						local seat = pp and pp.Parent
						local occupied = seat and seat:IsA("VehicleSeat") and seat.Occupant ~= nil
						if pp then pp.Enabled = not occupied and not (Config.Lobby.WalkOnly and inLobby()) end
					end
				end
			end
		end
	end)
end

return LobbyDock
