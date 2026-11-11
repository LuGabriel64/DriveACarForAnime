--[[
	EncounterUI: mini-jogo de captura (referência: imagem 6 "TAP TO THROW!") + revelação (imagem 7 "1 in 211").
	Fluxo: Begin(nodeId) -> servidor valida -> barra vertical com marcador oscilando -> toque/Espaço ->
	servidor decide o resultado -> Reveal(): card com modelo 3D girando, "1 in N", confete e flash por raridade.
]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local AnimeFactory = require(Shared.AnimeModelFactory)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local new, C = UIKit.New, UIKit.C

local EncounterUI = {}
local gui, meter, marker, luckLabel
local busy, currentResolve = false, nil
local FULL = UDim2.fromScale(1, 1)

function EncounterUI.IsBusy() return busy end

local function build()
	meter = new("Frame", { Name = "CaptureMeter", Size = FULL, BackgroundTransparency = 1, Visible = false, ZIndex = 40 }, gui)
	local catcher = new("TextButton", { Name = "Catcher", Size = FULL, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.7,
		Text = "", AutoButtonColor = false, ZIndex = 40 }, meter)
	local bar = new("Frame", { Name = "Bar", Size = UDim2.fromOffset(74, 360), Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 41 }, meter)
	new("UICorner", { CornerRadius = UDim.new(0, 37) }, bar); UIKit.Stroke(bar, 5)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 255, 90)), ColorSequenceKeypoint.new(0.3, Color3.fromRGB(190, 255, 70)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 235, 60)), ColorSequenceKeypoint.new(0.85, Color3.fromRGB(255, 140, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 50)) }) }, bar)
	for _, y in ipairs({ 0.15, 0.4, 0.7 }) do -- linhas dos limites das notas (PERFECT/GREAT/GOOD)
		new("Frame", { Size = UDim2.new(1, 0, 0, 4), Position = UDim2.fromScale(0, y), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 42 }, bar)
	end
	marker = new("Frame", { Name = "Marker", Size = UDim2.fromOffset(106, 24), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 44 }, bar)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, marker); UIKit.Stroke(marker, 4)
	luckLabel = UIKit.Text(marker, { Text = "+0%", TextSize = 36, Size = UDim2.fromOffset(130, 40), Position = UDim2.new(1, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), AlignX = Enum.TextXAlignment.Left, Stroke = 4, ZIndex = 45 })
	local tap = UIKit.Text(meter, { Text = "TAP TO CAPTURE!", TextSize = 46, Size = UDim2.fromOffset(560, 56),
		Position = UDim2.new(0.5, 0, 0.46, 212), AnchorPoint = Vector2.new(0.5, 0), Stroke = 5, ZIndex = 45 })
	local s = new("UIScale", { Scale = 1 }, tap)
	TweenService:Create(s, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 }):Play()
	return catcher
end

function EncounterUI.Reveal(r)
	local cfg = Config.AnimeById[r.Id]
	if not cfg then return end
	local rar = Config.Rarities[cfg.Rarity]
	local gcol = Color3.new(1, 1, 1)
	for _, g in ipairs(Config.Capture.Grades) do if g.Name == r.Grade then gcol = g.Color end end
	UIKit.PlaySound(rar.Order >= 4 and "Rare" or "Reveal")

	local overlay = new("TextButton", { Size = FULL, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 50 }, gui)
	local flash = new("Frame", { Size = FULL, BackgroundColor3 = rar.Color, BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 50 }, overlay)
	UIKit.Tween(flash, 0.7, { BackgroundTransparency = 1 })

	local card = new("Frame", { Size = UDim2.fromOffset(360, 490), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.PanelBg, ZIndex = 51 }, overlay)
	new("UICorner", { CornerRadius = UDim.new(0, 22) }, card); UIKit.Stroke(card, 6, rar.Color)
	local sc = new("UIScale", { Scale = 0.2 }, card)
	UIKit.Tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	UIKit.Text(card, { Text = "1 in " .. Util.FormatNumber(r.Odds), TextSize = 60, Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 8), Stroke = 6, ZIndex = 52 })
	UIKit.Text(card, { Text = r.Grade .. "!", TextSize = 30, Color = gcol, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 78), Stroke = 4, ZIndex = 52 })

	local holder = new("Frame", { Size = UDim2.fromOffset(220, 200), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = rar.Color, ZIndex = 52 }, card)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, holder); UIKit.Stroke(holder, 4)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 110)), Rotation = 90 }, holder)
	local model = AnimeFactory.Build(cfg, r.Mut, r.Size)
	UIKit.Viewport(holder, model, { Dir = Vector3.new(0.3, 0.15, -1), Zoom = 0.95, ZIndex = 53 })
	local spin = RunService.RenderStepped:Connect(function(dt) model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 1.8, 0)) end)

	UIKit.Text(card, { Text = cfg.Name, TextSize = 28, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 330), Stroke = 4, Scaled = true, ZIndex = 52 })
	local rich = ('<font color="#%s">%s</font>'):format(rar.Color:ToHex(), cfg.Rarity:upper())
	if r.Mut then rich ..= ('  <font color="#%s">%s</font>'):format(Config.Mutations[r.Mut].Color:ToHex(), r.Mut:upper()) end
	if r.Size then rich ..= '  <font color="#ffb400">' .. r.Size .. '</font>' end
	UIKit.Text(card, { Text = rich, RichText = true, TextSize = 22, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 366), Stroke = 3, ZIndex = 52 })
	UIKit.Text(card, { Text = "+$" .. Util.FormatNumber(r.Income) .. "/s", TextSize = 32, Color = C.Cash, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 396), Stroke = 4, ZIndex = 52 })
	UIKit.Text(card, { Text = r.Placed and "✅ Added to your garage!" or "🎒 Sent to your backpack", TextSize = 18, Color = Color3.fromRGB(200, 200, 220),
		Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 440), Stroke = 2, ZIndex = 52 })

	UIKit.Confetti(overlay, rar.Color, 18 + rar.Order * 9)
	if rar.Order >= 5 then UIKit.Shake(card, 10, 0.5) end

	local closed = false
	local function close()
		if closed then return end
		closed = true
		spin:Disconnect()
		UIKit.Tween(sc, 0.2, { Scale = 0.05 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.22, function() overlay:Destroy() end)
	end
	overlay.Activated:Connect(close)
	task.delay(3.8, close)
end

-- Retorna true se a captura rodou; false + motivo se o servidor recusou.
function EncounterUI.Begin(nodeId)
	if busy then return false, "Busy" end
	busy = true
	local res = Net.Call("StartEncounter", nodeId)
	if not res or not res.ok then busy = false; return false, res and res.err end

	State.Encounter = true
	meter.Visible = true
	UIKit.PlaySound("Capture")
	local resolved, conn = false, nil

	local function resolve(tapTime)
		if resolved then return end
		resolved = true
		if conn then conn:Disconnect() end
		ContextActionService:UnbindAction("CaptureTap")
		currentResolve = nil
		meter.Visible = false
		local r = Net.Call("ResolveEncounter", tapTime)
		State.Encounter = false
		if r and r.ok then EncounterUI.Reveal(r) end
		busy = false
	end
	currentResolve = resolve

	ContextActionService:BindActionAtPriority("CaptureTap", function(_, state)
		if state == Enum.UserInputState.Begin then resolve(workspace:GetServerTimeNow()) end
		return Enum.ContextActionResult.Sink -- impede o Espaço de pular/sair do carro
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	conn = RunService.RenderStepped:Connect(function()
		local t = workspace:GetServerTimeNow() - res.Start
		local pos = Util.Triangle(math.max(t, 0), res.Period)
		marker.Position = UDim2.fromScale(0.5, 1 - pos)
		local g = Config.GradeFor(pos)
		luckLabel.Text = "+" .. math.floor((g.Luck - 1) * 100) .. "%"
		luckLabel.TextColor3 = g.Color
		if t >= res.Duration then resolve(nil) end -- tempo esgotado = nota mínima
	end)
	return true
end

function EncounterUI.Init()
	gui = UIKit.GetGui()
	local catcher = build()
	catcher.Activated:Connect(function()
		if currentResolve then currentResolve(workspace:GetServerTimeNow()) end
	end)
end

return EncounterUI
