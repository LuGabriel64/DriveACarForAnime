--[[
	EggShop: loja dos SANTUÁRIOS DE OVOS (parts com tag "EggShrine").
	Coloca um ProximityPrompt "Open Egg Shop" em cada santuário (no cliente). O painel mostra o ovo girando,
	o preço e a TABELA DE CHANCES exata (Config.EggOdds, a mesma que o servidor usa). Secretos aparecem como
	"???" até você ter um. Botões OPEN x1 / OPEN x3 => servidor confere dinheiro/proximidade => EggHatchUI.
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Notify = require(script.Parent.Notify)
local EggVisuals = require(script.Parent.EggVisuals)
local EggHatchUI = require(script.Parent.EggHatchUI)
local new, C = UIKit.New, UIKit.C
local lp = Players.LocalPlayer

local EggShop = {}
local panel, eggBox, nameL, priceL, oddsScroll, btn1, btn3
local current, spinConn

local ERR = { NoCash = "💸 Not enough cash!", TooFar = "🥚 Get closer to the Egg Shrine!", Locked = "🔒 Your car's tier is too low for this biome!", NoGarage = "🏁 Choose a garage first!" }

local function refreshButtons()
	if not current then return end
	local price = Config.Eggs[current].Price
	local cash = lp:GetAttribute("Cash") or 0
	UIKit.SetButton(btn1, "OPEN x1   $" .. Util.FormatNumber(price), cash >= price and C.Green or C.Grey, cash < price)
	UIKit.SetButton(btn3, "OPEN x3   $" .. Util.FormatNumber(price * 3), cash >= price * 3 and C.Orange or C.Grey, cash < price * 3)
end

local function buy(n)
	if not current or EggHatchUI.IsBusy() then return end
	local r = Net.Call("BuyEgg", current, n)
	if not r then return end
	if not r.ok then Notify.Toast(ERR[r.err] or "Couldn't open the egg.", "error"); return end
	panel.Close()
	task.spawn(EggHatchUI.Play, r.Biome, r.Results)
end

function EggShop.Open(biomeId)
	local egg, biome = Config.Eggs[biomeId], Config.BiomeById[biomeId]
	if not egg then return end
	if biome.Tier > (lp:GetAttribute("CarTier") or 1) then
		Notify.Toast(("🔒 %s eggs need a Tier %d car!"):format(biome.Name, biome.Tier), "error"); return
	end
	current = biomeId
	panel.Header.BackgroundColor3 = egg.Color
	for _, f in ipairs(panel.Header:GetChildren()) do if f:IsA("Frame") and f.Name ~= "Shine" then f.BackgroundColor3 = egg.Color end end

	-- ovo girando
	if spinConn then spinConn:Disconnect() end
	for _, c in ipairs(eggBox:GetChildren()) do if c:IsA("ViewportFrame") then c:Destroy() end end
	eggBox.BackgroundColor3 = egg.Color
	local _, model = UIKit.Viewport(eggBox, EggVisuals.Build(biomeId, 1), { Dir = Vector3.new(0, 0.15, -1), Zoom = 1.1, ZIndex = 24 })
	spinConn = RunService.RenderStepped:Connect(function(dt) if model.Parent then model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 1.5, 0)) end end)
	nameL.Text = biome.Emoji .. " " .. egg.Name
	priceL.Text = "$" .. Util.FormatNumber(egg.Price) .. " each  •  +" .. math.floor((Config.EggRules.ShrineLuck - 1) * 100 + 0.5) .. "% luck"

	-- tabela de chances
	for _, c in ipairs(oddsScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	local owned = {}
	for _, e in ipairs(State.Inventory) do owned[e.Id] = true end
	for i, row in ipairs(Config.EggOdds(biomeId, Config.EggRules.ShrineLuck)) do
		local a = row.Anime
		local rar = Config.Rarities[a.Rarity]
		local f = new("Frame", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = C.CardBg, LayoutOrder = i, ZIndex = 23 }, oddsScroll)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, f)
		local st = UIKit.Stroke(f, 2.5, rar.Color)
		local dot = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = rar.Color, ZIndex = 24 }, f)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		local hidden = (rar.Rainbow or rar.Void) and not owned[a.Id]
		UIKit.Text(f, { Text = hidden and "???" or a.Name, TextSize = 18, AlignX = Enum.TextXAlignment.Left, Size = UDim2.new(0.62, -36, 1, 0), Position = UDim2.fromOffset(34, 0), Scaled = true, Stroke = 2.5, ZIndex = 24 })
		local rl = UIKit.Text(f, { Text = rar.Label, TextSize = 14, Color = Config.RarityText(rar), Size = UDim2.new(0.2, 0, 1, 0), Position = UDim2.fromScale(0.6, 0), Scaled = true, Stroke = 2, ZIndex = 24 })
		UIKit.Text(f, { Text = UIKit.Percent(row.Chance), TextSize = 18, Color = Color3.fromRGB(255, 240, 160), AlignX = Enum.TextXAlignment.Right, Size = UDim2.new(0.2, -10, 1, 0), Position = UDim2.fromScale(0.8, 0), Stroke = 2.5, ZIndex = 24 })
		if rar.Void then st.Color = Color3.fromRGB(200, 200, 215); UIKit.VoidText(rl); UIKit.VoidFill(dot) elseif rar.Rainbow then UIKit.Rainbow(st); UIKit.Rainbow(rl); UIKit.Rainbow(dot) end
	end
	refreshButtons()
	panel.Open()
end

local function addPrompt(part)
	if part:FindFirstChild("EggShopPrompt") then return end
	local egg = Config.Eggs[part:GetAttribute("BiomeId") or ""]
	if not egg then return end
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "EggShopPrompt"; pp.ActionText = "Open Egg Shop"; pp.ObjectText = egg.Name
	pp.MaxActivationDistance = 26; pp.RequiresLineOfSight = false; pp.HoldDuration = 0
	pp.KeyboardKeyCode = Enum.KeyCode.F
	pp.Triggered:Connect(function() EggShop.Open(part:GetAttribute("BiomeId")) end)
	pp.Parent = part
end

function EggShop.Init()
	panel = UIKit.Panel({ Name = "EggShop", Title = "Egg Shrine", HeaderColor = C.Orange, Size = UDim2.fromScale(0.62, 0.74), MaxSize = Vector2.new(760, 520) })
	local body = panel.Body
	local left = new("Frame", { Size = UDim2.new(0.4, -8, 1, 0), BackgroundTransparency = 1, ZIndex = 22 }, body)
	eggBox = new("Frame", { Size = UDim2.new(1, 0, 0.62, 0), BackgroundColor3 = C.Orange, ZIndex = 23 }, left)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, eggBox); UIKit.Stroke(eggBox, 4)
	UIKit.Gradient(eggBox, Color3.new(1, 1, 1), Color3.fromRGB(90, 90, 90))
	nameL = UIKit.Text(left, { Text = "", TextSize = 26, Scaled = true, Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.fromScale(0, 0.64), Stroke = 3.5, ZIndex = 23 })
	priceL = UIKit.Text(left, { Text = "", TextSize = 18, Scaled = true, Color = C.Cash, Size = UDim2.new(1, 0, 0.09, 0), Position = UDim2.fromScale(0, 0.77), Stroke = 2.5, ZIndex = 23 })
	UIKit.Text(left, { Text = "Characters hatch straight into your garage!", TextSize = 14, Scaled = true, Wrapped = true, Color = Color3.fromRGB(190, 190, 215),
		Size = UDim2.new(1, 0, 0.1, 0), Position = UDim2.fromScale(0, 0.88), Stroke = 2, ZIndex = 23 })

	local right = new("Frame", { Size = UDim2.new(0.6, -8, 1, 0), Position = UDim2.new(0.4, 8, 0, 0), BackgroundTransparency = 1, ZIndex = 22 }, body)
	UIKit.Text(right, { Text = "CHANCES", TextSize = 22, AlignX = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 26), Stroke = 3, ZIndex = 23 })
	oddsScroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -126), Position = UDim2.fromOffset(0, 30), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 23 }, right)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, oddsScroll)
	btn1 = UIKit.Button(right, { Text = "OPEN x1", Size = UDim2.new(0.5, -5, 0, 50), Position = UDim2.new(0, 0, 1, -88), Color = C.Green, TextSize = 24, ZIndex = 24, OnClick = function() buy(1) end })
	btn3 = UIKit.Button(right, { Text = "OPEN x3", Size = UDim2.new(0.5, -5, 0, 50), Position = UDim2.new(0.5, 5, 1, -88), Color = C.Orange, TextSize = 24, ZIndex = 24, OnClick = function() buy(3) end })
	UIKit.Shine(btn1, 2.2); UIKit.Shine(btn3, 2.6)
	UIKit.Text(right, { Text = "🍀 Rare and above get the shrine luck bonus", TextSize = 14, Scaled = true, Color = Color3.fromRGB(170, 255, 170),
		Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -30), Stroke = 2, ZIndex = 23 })
	lp:GetAttributeChangedSignal("Cash"):Connect(function() if panel.IsOpen then refreshButtons() end end)

	CollectionService:GetInstanceAddedSignal("EggShrine"):Connect(addPrompt)
	for _, p in ipairs(CollectionService:GetTagged("EggShrine")) do addPrompt(p) end
end

return EggShop
