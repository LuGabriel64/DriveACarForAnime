--[[
	GaragePanel: loja de carros (referência: imagem 10 "Food Shop") + upgrade de motor.
	Cards verdes com nome, TIER, preview 3D do carro, velocidade e botão (preço vermelho / EQUIP verde).
]]
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local CarFactory = require(Shared.CarFactory)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Notify = require(script.Parent.Notify)
local new, C = UIKit.New, UIKit.C

local GaragePanel = {}
local panel, scroll, engineBtn, engineText, engineSub

local ERR = { NoCash = "💸 Not enough cash!", Locked = "🔒 Buy the previous tier first!", Owned = "You already own it.", Max = "Engine is maxed!" }
local function call(name, arg)
	local r = Net.Call(name, arg)
	if r and not r.ok then Notify.Toast(ERR[r.err] or "Couldn't do that.", "error") end
	return r and r.ok
end

local function bestTier(owned)
	local t = 1
	for id in pairs(owned) do local c = Config.CarById[id]; if c and c.Tier > t then t = c.Tier end end
	return t
end

local function refresh()
	if not panel.IsOpen then return end
	local cs = State.Cars
	if not cs then return end
	for _, ch in ipairs(scroll:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
	local best = bestTier(cs.Owned)

	for i, car in ipairs(Config.Cars) do
		local f = new("Frame", { Name = car.Id, Size = UDim2.new(0, 196, 1, -6), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i }, scroll)
		new("UICorner", { CornerRadius = UDim.new(0, 14) }, f); UIKit.Stroke(f, 3.5)
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(238, 255, 130), Color3.fromRGB(70, 226, 40)), Rotation = 90 }, f)
		UIKit.Text(f, { Text = car.Name, TextSize = 24, Size = UDim2.fromScale(0.94, 0.1), Position = UDim2.fromScale(0.03, 0.025), Scaled = true, Stroke = 3 })
		local mdl = CarFactory.Build(car, true)
		UIKit.Viewport(f, mdl, { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.13), Dir = Vector3.new(0.7, 0.45, -1), Zoom = 1.0 })
		local badge = new("Frame", { Size = UDim2.fromScale(0.8, 0.1), Position = UDim2.fromScale(0.1, 0.56), BackgroundColor3 = Color3.fromRGB(24, 78, 22) }, f)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, badge); UIKit.Stroke(badge, 2.5)
		UIKit.Text(badge, { Text = "Tier " .. car.Tier, TextSize = 22, Color = Color3.fromRGB(120, 255, 90), Scaled = true, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1) })
		UIKit.Text(f, { Text = "🚀 " .. car.MaxSpeed .. " km/h", TextSize = 20, Size = UDim2.fromScale(0.94, 0.09), Position = UDim2.fromScale(0.03, 0.67), Scaled = true, Stroke = 2.5 })

		local owned, equipped = cs.Owned[car.Id] ~= nil, cs.Equipped == car.Id
		local b = UIKit.Button(f, { Text = "", Size = UDim2.fromScale(0.9, 0.15), Position = UDim2.fromScale(0.05, 0.8) })
		if equipped then UIKit.SetButton(b, "EQUIPPED", C.Grey, true)
		elseif owned then UIKit.SetButton(b, "EQUIP", Color3.fromRGB(40, 170, 40), false); b.Activated:Connect(function() call("EquipCar", car.Id) end)
		elseif car.Tier <= best + 1 then UIKit.SetButton(b, "$" .. Util.FormatNumber(car.Price), Color3.fromRGB(235, 25, 25), false); b.Activated:Connect(function() call("BuyCar", car.Id) end)
		else UIKit.SetButton(b, "🔒 LOCKED", C.Grey, true) end
	end

	if cs.EngineMax then
		engineText.Text = "ENGINE  Lv " .. cs.EngineLevel .. "  (MAX)"; engineSub.Text = "Fully upgraded!"
		UIKit.SetButton(engineBtn, "MAX", C.Grey, true)
	else
		engineText.Text = ("ENGINE  Lv %d → %d"):format(cs.EngineLevel, cs.EngineLevel + 1)
		engineSub.Text = ("+%d%% top speed per level"):format(Config.Engine.SpeedPerLevel * 100)
		UIKit.SetButton(engineBtn, "$" .. Util.FormatNumber(cs.EngineCost), C.Orange, false)
	end
end

function GaragePanel.Init()
	panel = UIKit.Panel({ Name = "Garage", Title = "Car Shop", HeaderColor = C.Magenta, Size = UDim2.fromScale(0.62, 0.76), MaxSize = Vector2.new(740, 540) })
	scroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -76), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ZIndex = 22 }, panel.Body)
	new("UIListLayout", { Padding = UDim.new(0, 12), FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 64), Position = UDim2.new(0, 0, 1, -64), BackgroundColor3 = C.CardBg, ZIndex = 22 }, panel.Body)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, row); UIKit.Stroke(row, 3.5)
	engineText = UIKit.Text(row, { Text = "ENGINE", TextSize = 24, AlignX = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 6), Size = UDim2.new(0.6, 0, 0, 30), ZIndex = 23, Stroke = 3 })
	engineSub = UIKit.Text(row, { Text = "", TextSize = 17, Color = Color3.fromRGB(190, 255, 170), AlignX = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 36), Size = UDim2.new(0.6, 0, 0, 22), ZIndex = 23, Stroke = 2 })
	engineBtn = UIKit.Button(row, { Text = "UPGRADE", Size = UDim2.fromOffset(150, 46), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = C.Orange, ZIndex = 23,
		OnClick = function()
			if call("UpgradeEngine") then UIKit.Pop(engineText, 1.15) end
		end })

	panel.OnOpen = refresh
	State.Changed.Event:Connect(function(what) if what == "Cars" then refresh() end end)
end

return GaragePanel
