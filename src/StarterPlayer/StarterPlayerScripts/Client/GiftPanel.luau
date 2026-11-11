--[[ GiftPanel: "Free Gift!" (referência: imagem 1). Recompensa única; botão vira CLAIMED! ao resgatar. ]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Notify = require(script.Parent.Notify)
local new, C = UIKit.New, UIKit.C
local lp = Players.LocalPlayer

local GiftPanel = {}

function GiftPanel.Init()
	local panel = UIKit.Panel({ Name = "Gift", Title = "Free Gift!", HeaderColor = C.Cyan, Size = UDim2.fromScale(0.56, 0.72), MaxSize = Vector2.new(660, 480) })
	local body = panel.Body

	local present = UIKit.Text(body, { Text = "🎁", TextSize = 120, Size = UDim2.fromScale(0.4, 0.42), Position = UDim2.fromScale(0.02, 0.0), Stroke = 0, ZIndex = 22 })
	UIKit.Text(body, { Text = "~ LIMITED TIME! ~", TextSize = 28, Color = Color3.fromRGB(255, 120, 130), Size = UDim2.fromScale(0.56, 0.12), Position = UDim2.fromScale(0.42, 0.06), Scaled = true, Stroke = 4, ZIndex = 22 })
	local reward = UIKit.Text(body, { Text = Util.FormatNumber(Config.Gift.Cash) .. " CASH!", TextSize = 56, Size = UDim2.fromScale(0.56, 0.2), Position = UDim2.fromScale(0.42, 0.2), Scaled = true, Stroke = 5, ZIndex = 22 })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(40, 210, 255), Color3.fromRGB(80, 255, 120)), Rotation = 0 }, reward)

	local steps = { { "👍", "1. Like the game!" }, { "⭐", "2. Favorite the game!" }, { "👥", "3. Join the community!" } }
	for i, s in ipairs(steps) do
		local f = new("Frame", { Size = UDim2.fromScale(0.31, 0.27), Position = UDim2.fromScale(0.0 + (i - 1) * 0.345, 0.5), BackgroundColor3 = C.CardBg, ZIndex = 22 }, body)
		new("UICorner", { CornerRadius = UDim.new(0, 12) }, f); UIKit.Stroke(f, 3.5, Color3.fromRGB(90, 90, 112))
		UIKit.Text(f, { Text = s[1], TextSize = 44, Size = UDim2.fromScale(1, 0.55), Position = UDim2.fromScale(0, 0.04), Stroke = 0, ZIndex = 23 })
		UIKit.Text(f, { Text = s[2], TextSize = 17, Size = UDim2.fromScale(0.94, 0.3), Position = UDim2.fromScale(0.03, 0.62), Scaled = true, Stroke = 2.5, ZIndex = 23 })
	end

	local claim
	local function paint()
		if lp:GetAttribute("GiftClaimed") then UIKit.SetButton(claim, "CLAIMED!", C.Grey, true)
		else UIKit.SetButton(claim, "CLAIM!", C.Green, false) end
	end
	claim = UIKit.Button(body, { Text = "CLAIM!", Size = UDim2.fromScale(0.62, 0.17), Position = UDim2.fromScale(0.5, 0.97), AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 23, TextSize = 36, Radius = 12, OnClick = function()
			local r = Net.Call("ClaimGift")
			if r and r.ok then
				Notify.Toast("🎁 +$" .. Util.FormatNumber(r.Cash) .. " claimed!", "good")
				UIKit.Confetti(UIKit.GetGui(), C.Gold, 40)
			elseif r and r.err == "Group" then Notify.Toast("👥 Join the community first!", "error")
			elseif r and r.err == "Claimed" then Notify.Toast("You already claimed this gift.", "info") end
			paint()
		end })
	lp:GetAttributeChangedSignal("GiftClaimed"):Connect(paint)
	panel.OnOpen = function()
		paint()
		task.spawn(function() -- balança o presente
			for _ = 1, 3 do
				UIKit.Tween(present, 0.12, { Rotation = 10 }); task.wait(0.12)
				UIKit.Tween(present, 0.12, { Rotation = -10 }); task.wait(0.12)
			end
			UIKit.Tween(present, 0.1, { Rotation = 0 })
		end)
	end
	paint()
end

return GiftPanel
