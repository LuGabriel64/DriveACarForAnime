--[[
	GrabPromptUI (Beta 1.7): visual ELEGANTE do prompt "segurar F" do ovo gigante (ProximityPrompt "GrabPrompt",
	Style = Custom, criado pelo Services.EscapeService). O Roblox só cuida da tecla/distância; o desenho é nosso:
	  * Cartão "vidro escuro" em pílula flutuando sobre o ovo (BillboardGui em PlayerGui, tamanho fixo em pixels).
	  * À esquerda, a TECLA (F / botão do controle / ☝ no celular) dentro de um ANEL de 24 segmentos que acendem
	    na cor do ovo enquanto você segura (duração = prompt.HoldDuration). Soltou antes => o anel esvazia.
	  * À direita: "HOLD TO GRAB" + nome do ovo na cor dele.
	  * Celular/mouse: o cartão inteiro é um botão (InputHoldBegin/End do próprio prompt).
	  * Completou => clarão + pop e some (a roleta abre pelo servidor).
	Só desenha prompts com Style = Custom cujo nome é "GrabPrompt" (os outros prompts do jogo seguem o padrão).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent.UIKit)
local new = UIKit.New
local lp = Players.LocalPlayer

local GrabPromptUI = {}
local SEGS = 24
local active = {} -- [prompt] = ui

local GLASS = Color3.fromRGB(12, 12, 22)
local SIZE = 0.8 -- Beta 1.8: cartão 20% menor (pedido do dono)
local DIM_SEG = Color3.fromRGB(70, 70, 92)

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then return "☝" end
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local k = prompt.GamepadKeyCode.Name
		return (k:gsub("^Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

local function build(prompt, inputType)
	local biomeId = prompt:GetAttribute("BiomeId")
	local egg = biomeId and Config.Eggs[biomeId]
	local color = egg and egg.Color or Color3.fromRGB(120, 200, 255)
	local bright = color:Lerp(Color3.new(1, 1, 1), 0.35)

	local bb = new("BillboardGui", { Name = "GrabPromptUI", Adornee = prompt.Parent, Size = UDim2.fromOffset(math.ceil(310 * SIZE), math.ceil(96 * SIZE)), StudsOffset = Vector3.new(0, 1.5, 0),
		AlwaysOnTop = true, Active = true, LightInfluence = 0, ResetOnSpawn = false, ClipsDescendants = false })
	-- (Frame e não CanvasGroup: CanvasGroup dentro de BillboardGui não desenhou no teste)
	local root = new("Frame", { Size = UDim2.fromOffset(310, 96), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, bb)
	local scale = new("UIScale", { Scale = 0.7 }, root)

	-- cartão (pílula de vidro escuro) — é um botão p/ toque/mouse
	local card = new("TextButton", { Name = "Card", Text = "", AutoButtonColor = false, Size = UDim2.new(1, -8, 0, 76), Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = GLASS, BackgroundTransparency = 0.12 }, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, card)
	local cardStroke = new("UIStroke", { Thickness = 2, Color = bright, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 170)) }, card)
	-- brilho de vidro (faixa clara no topo)
	local gloss = new("Frame", { Size = UDim2.new(1, -24, 0.42, 0), Position = UDim2.fromOffset(12, 4), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.9, BorderSizePixel = 0 }, card)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, gloss)

	-- anel de progresso + tecla
	local ringHolder = new("Frame", { Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1 }, card)
	local segs = {}
	for i = 1, SEGS do
		local ang = (i - 1) / SEGS * math.pi * 2 - math.pi / 2
		local s = new("Frame", { Size = UDim2.fromOffset(4, 9), Position = UDim2.new(0.5, math.cos(ang) * 28, 0.5, math.sin(ang) * 28),
			AnchorPoint = Vector2.new(0.5, 0.5), Rotation = math.deg(ang) + 90, BackgroundColor3 = DIM_SEG, BorderSizePixel = 0 }, ringHolder)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, s)
		segs[i] = s
	end
	local key = new("Frame", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(245, 245, 252) }, ringHolder)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, key)
	new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(30, 30, 44) }, key)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205)) }, key)
	local keyScale = new("UIScale", { Scale = 1 }, key)
	local keyL = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 22,
		TextColor3 = Color3.fromRGB(22, 22, 34), Text = keyText(prompt, inputType) }, key)

	-- textos
	new("TextLabel", { Size = UDim2.new(1, -96, 0, 22), Position = UDim2.fromOffset(84, 12), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
		TextSize = 13, TextColor3 = Color3.fromRGB(200, 200, 220), TextXAlignment = Enum.TextXAlignment.Left,
		Text = inputType == Enum.ProximityPromptInputType.Touch and "TAP & HOLD TO GRAB" or "HOLD TO GRAB" }, card)
	local title = new("TextLabel", { Size = UDim2.new(1, -96, 0, 32), Position = UDim2.fromOffset(84, 32), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
		TextSize = 27, TextColor3 = bright, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true, Text = (prompt.ObjectText ~= "" and prompt.ObjectText or "Giant Egg") .. " 🥚" }, card)
	new("UITextSizeConstraint", { MaxTextSize = 27 }, title)
	new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(10, 10, 16) }, title)

	local ui = { Gui = bb, Root = root, Scale = scale, Segs = segs, Key = key, KeyScale = keyScale, Card = card, Stroke = cardStroke,
		Color = color, Bright = bright, Holding = false, HoldStart = 0, Progress = 0 }

	-- toque / clique: segura o próprio prompt
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then prompt:InputHoldBegin() end
	end)
	card.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then prompt:InputHoldEnd() end
	end)

	bb.Parent = lp:WaitForChild("PlayerGui")
	UIKit.Tween(scale, 0.3, { Scale = SIZE }, Enum.EasingStyle.Back)
	return ui
end

local function setProgress(ui, p)
	ui.Progress = p
	local lit = math.floor(p * SEGS + 0.0001)
	for i, s in ipairs(ui.Segs) do
		local on = i <= lit
		s.BackgroundColor3 = on and ui.Bright or DIM_SEG
		s.Size = on and UDim2.fromOffset(5, 11) or UDim2.fromOffset(4, 9)
	end
end

local function destroy(prompt, fancy)
	local ui = active[prompt]
	if not ui then return end
	active[prompt] = nil
	UIKit.Tween(ui.Scale, 0.15, { Scale = fancy and SIZE * 1.25 or 0.01 })
	task.delay(0.17, function() ui.Gui:Destroy() end)
end

function GrabPromptUI.Init()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom or prompt.Name ~= "GrabPrompt" then return end
		if active[prompt] then destroy(prompt) end
		local ui = build(prompt, inputType)
		active[prompt] = ui
		local conns = {}
		table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
			ui.Holding, ui.HoldStart = true, os.clock()
			UIKit.Tween(ui.KeyScale, 0.08, { Scale = 0.88 })
			UIKit.Tween(ui.Stroke, 0.15, { Transparency = 0, Thickness = 3 })
		end))
		table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
			ui.Holding = false
			UIKit.Tween(ui.KeyScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
			UIKit.Tween(ui.Stroke, 0.2, { Transparency = 0.35, Thickness = 2 })
		end))
		table.insert(conns, prompt.Triggered:Connect(function()
			setProgress(ui, 1)
			ui.Card.BackgroundColor3 = ui.Bright
			UIKit.Tween(ui.Card, 0.25, { BackgroundColor3 = GLASS })
			UIKit.PlaySound("Reveal")
			destroy(prompt, true)
		end))
		local hidden
		hidden = prompt.PromptHidden:Connect(function()
			for _, c in ipairs(conns) do c:Disconnect() end
			hidden:Disconnect()
			destroy(prompt)
		end)
	end)

	-- anel: enche durante o hold, esvazia rápido ao soltar; tecla pulsa de leve parada
	RunService.RenderStepped:Connect(function(dt)
		for prompt, ui in pairs(active) do
			if ui.Holding then
				setProgress(ui, math.clamp((os.clock() - ui.HoldStart) / math.max(prompt.HoldDuration, 0.05), 0, 1))
			elseif ui.Progress > 0 then
				setProgress(ui, math.max(0, ui.Progress - dt * 3))
			else
				ui.KeyScale.Scale = 1 + math.sin(os.clock() * 4) * 0.04
			end
		end
	end)
end

return GrabPromptUI
