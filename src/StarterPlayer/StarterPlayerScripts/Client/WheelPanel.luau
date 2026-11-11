--[[
	WheelPanel (Beta 1.5 -> 1.7): janela da ROLETA DA SORTE — agora SÓ NA INTERFACE (sem quiosques no mapa).
	Visual (referência do dono): roda grande com contorno preto grosso, 6 fatias coloridas com ÍCONE + nome + chance,
	divisórias escuras, miolo branco, ponteiro branco no topo, botão X vermelho; embaixo 3 botões:
	  [ R$29  x3 Spins ] (amarelo)   [ Spin (N) ] (verde) + "Spin in: 07:59:12"   [ R$79  x10 Spins ] (roxo)
	  * Spin (N): N = giro grátis pronto (0/1) + giros extras (atributo WheelTokens). Pede "SpinWheel" ao servidor.
	  * A resposta diz QUAL fatia ganhou; a roda gira (TweenService, Quint/Out, 5 s) até parar nela.
	  * x3 / x10: "WheelPack" => o servidor abre a compra com Robux (Developer Product). Sem ProductId = "Soon".
	  * Contador do grátis com o relógio do SERVIDOR (WheelNextAt + workspace:GetServerTimeNow()).
	  * Registrado em UIKit.Panels["Wheel"] (Open/Close/Toggle) => o botão WHEEL do dock (Client.LobbyDock) abre.
	Fatia = interseção de dois semiplanos (CanvasGroup + UIGradient de transparência) dentro de um CanvasGroup redondo.
	O cliente não decide nada: só mostra o que Services.WheelService mandou.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Notify = require(script.Parent.Notify)
local new, C = UIKit.New, UIKit.C
local lp = Players.LocalPlayer

local WheelPanel = {}
local WC = Config.Wheel
local N = #WC.Prizes
local STEP = 360 / N
local SIZE = 380              -- diâmetro do disco (px, antes do UIScale)
local W, H = 470, 650         -- tamanho de desenho da janela
local Z = 30
local dim, frame, scaleObj, disc, pointer, spinBtn, timerL, resultL, packBtns
local spinning, obj = false, nil
local offset = 0 -- os.time do servidor - GetServerTimeNow

local HALF = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.499, 1),
	NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0) })

local function serverNow() return workspace:GetServerTimeNow() + offset end
local function nextAt() return lp:GetAttribute("WheelNextAt") or 0 end
local function tokens() return lp:GetAttribute("WheelTokens") or 0 end
local function freeReady() return nextAt() > 0 and serverNow() >= nextAt() end
local function available() return (freeReady() and 1 or 0) + tokens() end
function WheelPanel.IsReady() return available() > 0 end

local function clock(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%02d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
end

-- ---------------------------------------------------------------- roda
local function wedge(parent, k, color)
	local a = (k - 1) * STEP
	local outer = new("CanvasGroup", { Name = "Slice" .. k, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = Z + 3 }, parent)
	new("UIGradient", { Rotation = a + 90, Transparency = HALF }, outer)
	local inner = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = Z + 3 }, outer)
	new("UIGradient", { Rotation = a + STEP - 90, Transparency = HALF }, inner)
	return outer
end

local function polar(r, deg) local t = math.rad(deg); return UDim2.new(0.5, math.cos(t) * r, 0.5, math.sin(t) * r) end

local function buildWheel(holder)
	-- contorno preto grosso + aro escuro
	local ring = new("Frame", { Name = "Ring", Size = UDim2.fromOffset(SIZE + 22, SIZE + 22), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(34, 28, 48), ZIndex = Z + 1 }, holder)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	UIKit.Stroke(ring, 6)
	disc = new("CanvasGroup", { Name = "Disc", Size = UDim2.fromOffset(SIZE, SIZE), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(20, 18, 28), ZIndex = Z + 2 }, holder)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
	for k, p in ipairs(WC.Prizes) do wedge(disc, k, p.Color) end
	-- brilho suave no topo do disco (volume)
	local gloss = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = Z + 4 }, disc)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.75) }),
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)) }, gloss)
	for k = 0, N - 1 do -- divisórias escuras (raio do centro até a borda)
		local ang = k * STEP
		new("Frame", { Size = UDim2.fromOffset(SIZE / 2, 4), Position = polar(SIZE / 4, ang), AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = ang, BackgroundColor3 = Color3.fromRGB(24, 20, 34), BorderSizePixel = 0, ZIndex = Z + 5 }, disc)
	end
	local total = 0
	for _, p in ipairs(WC.Prizes) do total += p.Weight end
	for k, p in ipairs(WC.Prizes) do
		local m = (k - 1) * STEP + STEP / 2
		local rot = m + 90 -- tangente: a fatia do topo fica com o texto em pé
		local lbl = UIKit.Text(disc, { Text = p.Label, TextSize = p.Jackpot and 24 or 21, Size = UDim2.fromOffset(150, 28), Position = polar(SIZE * 0.405, m),
			AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 3, ZIndex = Z + 6 })
		lbl.Rotation = rot
		local icon = UIKit.Text(disc, { Text = p.Icon or "🎁", TextSize = 46, Size = UDim2.fromOffset(64, 56), Position = polar(SIZE * 0.27, m),
			AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 0, ZIndex = Z + 6 })
		icon.Rotation = rot
		local pct = p.Weight / total * 100
		local ch = UIKit.Text(disc, { Text = (pct >= 10 and "%d%%" or "%g%%"):format(pct >= 10 and math.floor(pct + 0.5) or math.floor(pct * 10 + 0.5) / 10),
			TextSize = 15, Color = Color3.fromRGB(255, 255, 255), Size = UDim2.fromOffset(60, 20), Position = polar(SIZE * 0.155, m),
			AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 2.5, ZIndex = Z + 6 })
		ch.Rotation = rot
		if p.Jackpot then UIKit.Rainbow(lbl:FindFirstChildOfClass("UIStroke")) end
	end
	-- miolo
	local hub = new("Frame", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(245, 245, 250), ZIndex = Z + 8 }, holder)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, hub); UIKit.Stroke(hub, 4)
	local dot = new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 200, 60), ZIndex = Z + 9 }, hub)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot); UIKit.Stroke(dot, 2)
	-- ponteiro (triângulo branco no topo)
	pointer = UIKit.Text(holder, { Name = "Pointer", Text = "▼", TextSize = 72, Color = Color3.fromRGB(240, 240, 248), Size = UDim2.fromOffset(80, 70),
		Position = UDim2.new(0.5, 0, 0.5, -SIZE / 2 - 14), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 5, ZIndex = Z + 10 })
end

-- ---------------------------------------------------------------- estado dos botões
local function refresh()
	if not frame then return end
	local n = available()
	if not spinning then UIKit.SetButton(spinBtn, ("Spin (%d)"):format(n), n > 0 and C.Green or C.Grey, false) end
	if nextAt() <= 0 then
		timerL.Text = "..."
	elseif freeReady() then
		timerL.Text = "Free spin ready!"; timerL.TextColor3 = C.Cash
	else
		timerL.Text = "Spin in: " .. clock(nextAt() - serverNow()); timerL.TextColor3 = Color3.fromRGB(235, 235, 245)
	end
end

local ERR = { Cooldown = "⏳ No spins left! Wait for the free spin or grab a spin pack.", NoData = "Still loading, try again!",
	Spinning = "The wheel is still spinning!", TooFast = "Easy there!" }

function WheelPanel.Spin()
	if spinning then return end
	if available() <= 0 then
		Notify.Toast(("⏳ Free spin in %s — or grab a x3 / x10 spin pack!"):format(clock(nextAt() - serverNow())), "info")
		UIKit.Shake(spinBtn, 6, 0.3)
		return
	end
	spinning = true
	UIKit.SetButton(spinBtn, "Spinning...", C.Orange, true)
	for _, b in ipairs(packBtns) do b:SetAttribute("Disabled", true) end
	resultL.Text = ""
	local r = Net.Call("SpinWheel")
	if not (r and r.ok) then
		spinning = false
		for _, b in ipairs(packBtns) do b:SetAttribute("Disabled", false) end
		if r and r.Now then offset = r.Now - workspace:GetServerTimeNow() end
		Notify.Toast(ERR[r and r.err] or "Couldn't spin, try again.", "error")
		refresh()
		return
	end
	if r.Now then offset = r.Now - workspace:GetServerTimeNow() end
	local prize = WC.Prizes[r.Index]
	-- ângulo final: o meio da fatia vencedora para no topo (270°), com várias voltas e um desvio aleatório
	local mid = (r.Index - 1) * STEP + STEP / 2
	local cur = disc.Rotation % 360
	disc.Rotation = cur
	local jitter = (math.random() - 0.5) * STEP * 0.6
	local target = cur + 360 * 6 + ((270 - mid - cur) % 360) + jitter
	local tw = TweenService:Create(disc, TweenInfo.new(WC.SpinSeconds or 5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = target })
	local last = math.floor(cur / STEP)
	local tick = RunService.RenderStepped:Connect(function()
		local idx = math.floor(disc.Rotation / STEP)
		if idx ~= last then
			last = idx
			UIKit.PlaySound("Click")
			pointer.Rotation = -16
			UIKit.Tween(pointer, 0.12, { Rotation = 0 })
		end
	end)
	tw:Play()
	tw.Completed:Wait()
	tick:Disconnect()
	-- resultado
	local text = prize.Spins and ("🎟️ +%d SPINS!"):format(prize.Spins) or ("+$" .. Util.FormatNumber(prize.Cash))
	resultL.Text = (prize.Jackpot and "👑 JACKPOT! " or "🎉 ") .. text
	resultL.TextColor3 = prize.Color
	UIKit.Pop(resultL, 1.6)
	UIKit.Confetti(frame, prize.Color, prize.Jackpot and 90 or 35)
	UIKit.PlaySound(prize.Jackpot and "Rare" or "Reveal")
	if prize.Jackpot then UIKit.Rainbow(resultL); UIKit.Shake(frame, 10, 0.6) end
	Notify.Toast(prize.Spins and ("🎟️ You won %d extra spins!"):format(prize.Spins)
		or ("🎡 You won $%s on the Lucky Wheel!"):format(Util.FormatNumber(prize.Cash)), "good")
	task.wait(0.4) -- o servidor entrega o prêmio quando a roda para
	spinning = false
	for _, b in ipairs(packBtns) do b:SetAttribute("Disabled", false) end
	refresh()
end

local function buyPack(pk)
	if spinning then return end
	local r = Net.Call("WheelPack", pk.Key)
	if r and r.err == "Soon" then Notify.Toast("🎟️ Spin packs are coming soon!", "info")
	elseif not (r and r.ok) then Notify.Toast("Couldn't open the purchase, try again.", "error") end
end

-- ---------------------------------------------------------------- abrir / fechar
local function fit()
	local vs = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	-- deixa ~130 px livres embaixo para o dock do lobby não ficar atrás dos botões
	return math.clamp(math.min((vs.Y - 150) / H, (vs.X - 16) / W), 0.45, 0.95)
end

function WheelPanel.Open() if obj then obj.Open() end end

function WheelPanel.Init()
	local gui = UIKit.GetGui()
	dim = new("TextButton", { Name = "Wheel_Backdrop", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 4, 20), BackgroundTransparency = 1, Visible = false, ZIndex = Z }, gui)
	frame = new("Frame", { Name = "Wheel", Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, 0, 0.5, -55), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, Visible = false, ZIndex = Z + 1 }, gui)
	scaleObj = new("UIScale", { Scale = 1 }, frame)

	local holder = new("Frame", { Name = "WheelHolder", Size = UDim2.fromOffset(SIZE + 40, SIZE + 40), Position = UDim2.new(0.5, 0, 0, 22), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1, ZIndex = Z + 1 }, frame)
	buildWheel(holder)

	UIKit.Button(frame, { Name = "Close", Text = "X", Size = UDim2.fromOffset(58, 58), Position = UDim2.new(1, -6, 0, 18), AnchorPoint = Vector2.new(1, 0),
		Color = C.Red, TextSize = 34, Radius = 12, StrokeThickness = 4, ZIndex = Z + 12, OnClick = function() obj.Close() end })

	resultL = UIKit.Text(frame, { Name = "Result", Text = "", TextSize = 34, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, SIZE + 66), Stroke = 4, ZIndex = Z + 12 })

	-- linha de botões
	local rowY = SIZE + 112
	packBtns = {}
	local function pack(pk, x)
		local b = UIKit.Button(frame, { Name = "Pack_" .. pk.Key, Text = "R$ " .. pk.Robux, Size = UDim2.fromOffset(118, 74), Position = UDim2.new(0.5, x, 0, rowY),
			AnchorPoint = Vector2.new(0.5, 0), Color = pk.Color, TextSize = 28, Radius = 14, StrokeThickness = 4, ZIndex = Z + 12, OnClick = function() buyPack(pk) end })
		UIKit.Text(frame, { Text = pk.Key .. " Spins", TextSize = 20, Size = UDim2.fromOffset(130, 24), Position = UDim2.new(0.5, x, 0, rowY + 80), AnchorPoint = Vector2.new(0.5, 0),
			Stroke = 3, ZIndex = Z + 12 })
		table.insert(packBtns, b)
		return b
	end
	local packs = WC.Packs or {}
	if packs[1] then pack(packs[1], -158) end
	if packs[2] then pack(packs[2], 158) end
	spinBtn = UIKit.Button(frame, { Name = "Spin", Text = "Spin (0)", Size = UDim2.fromOffset(180, 80), Position = UDim2.new(0.5, 0, 0, rowY - 3), AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Green, TextSize = 36, Radius = 16, StrokeThickness = 4, ZIndex = Z + 12, OnClick = function() WheelPanel.Spin() end })
	UIKit.Shine(spinBtn, 2)
	timerL = UIKit.Text(frame, { Name = "Timer", Text = "", TextSize = 21, Size = UDim2.fromOffset(220, 26), Position = UDim2.new(0.5, 0, 0, rowY + 81), AnchorPoint = Vector2.new(0.5, 0),
		Stroke = 3, ZIndex = Z + 12 })

	obj = { Name = "Wheel", Frame = frame, IsOpen = false }
	function obj.Open()
		if obj.IsOpen then return end
		for _, other in pairs(UIKit.Panels) do if other ~= obj and other.IsOpen then other.Close() end end
		obj.IsOpen = true
		resultL.Text = ""
		frame.Visible, dim.Visible = true, true
		local s = fit()
		scaleObj.Scale = s * 0.6
		UIKit.Tween(scaleObj, 0.32, { Scale = s }, Enum.EasingStyle.Back)
		UIKit.Tween(dim, 0.25, { BackgroundTransparency = 0.4 })
		task.spawn(function()
			local r = Net.Call("GetWheel")
			if r and r.ok and r.Now then offset = r.Now - workspace:GetServerTimeNow() end
			refresh()
		end)
		refresh()
	end
	function obj.Close()
		if not obj.IsOpen then return end
		obj.IsOpen = false
		local tw = UIKit.Tween(scaleObj, 0.16, { Scale = fit() * 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UIKit.Tween(dim, 0.18, { BackgroundTransparency = 1 })
		tw.Completed:Connect(function() if not obj.IsOpen then frame.Visible = false; dim.Visible = false end end)
	end
	function obj.Toggle() if obj.IsOpen then obj.Close() else obj.Open() end end
	dim.Activated:Connect(function() if not spinning then obj.Close() end end)
	UIKit.Panels.Wheel = obj

	-- contador (só com a janela aberta) + roda girando devagar parada
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		if not obj.IsOpen then return end
		acc += dt
		if acc >= 0.25 then acc = 0; refresh() end
	end)
	lp:GetAttributeChangedSignal("WheelNextAt"):Connect(refresh)
	lp:GetAttributeChangedSignal("WheelTokens"):Connect(refresh)
end

return WheelPanel
