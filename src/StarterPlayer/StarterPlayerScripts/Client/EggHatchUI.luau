--[[
	EggHatchUI: animação de CHOCAR (o momento de dopamina do jogo).
	  Play(biomeId, results): escurece a tela, raios girando, 1 ou 3 ovos caem quicando, tremem cada vez mais,
	  rachaduras, CLARÃO e revelação de cada personagem (cartão com raridade, "1 in N", renda, mutação/BIG).
	  Lendário+ treme a tela; SECRET ganha arco-íris e um letreiro gigante.
	  FromRoad(nodeName): pede ao servidor o ovo grátis da estrada e toca a animação.
	Enquanto toca, State.Encounter = true (o carro freia sozinho).
]]
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local AnimeFactory = require(Shared.AnimeModelFactory)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Notify = require(script.Parent.Notify)
local EggVisuals = require(script.Parent.EggVisuals)
local new, C = UIKit.New, UIKit.C

local EggHatchUI = {}
local gui
local busy = false
function EggHatchUI.IsBusy() return busy end

local function revealCard(parent, r, w, h, xoff)
	local cfg = Config.AnimeById[r.Id]
	local rar = Config.Rarities[cfg.Rarity]
	local card = new("Frame", { Size = UDim2.fromOffset(w, h), Position = UDim2.new(0.5, xoff, 0.5, 10), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.PanelBg, ZIndex = 61 }, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 20) }, card)
	local stroke = UIKit.Stroke(card, 6, rar.Color)
	UIKit.RarityFx(stroke, rar, 160)
	local sc = new("UIScale", { Scale = 0.15 }, card)
	UIKit.Tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	local ribbon = new("Frame", { Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = rar.Color, ZIndex = 62 }, card)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, ribbon); UIKit.Stroke(ribbon, 3)
	if not UIKit.RarityFx(ribbon, rar, 120) then UIKit.Gradient(ribbon, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)) end
	UIKit.Text(ribbon, { Text = (rar.Label or cfg.Rarity) .. "!", TextSize = 28, Scaled = true, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), Stroke = 3.5, ZIndex = 63 })
	UIKit.Shine(ribbon, 1.6)

	local oddsL = UIKit.Text(card, { Text = "1 in " .. Util.FormatNumber(r.Odds), TextSize = 30, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 58), Stroke = 4, ZIndex = 62 })
	UIKit.RarityLabel(oddsL, rar)

	local vh = math.floor(h * 0.42)
	local holder = new("Frame", { Size = UDim2.new(1, -40, 0, vh), Position = UDim2.fromOffset(20, 96), BackgroundColor3 = rar.Color, ZIndex = 62 }, card)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, holder); UIKit.Stroke(holder, 4)
	if not UIKit.RarityFx(holder, rar, 60) then UIKit.Gradient(holder, Color3.new(1, 1, 1), Color3.fromRGB(100, 100, 100)) end
	local model = AnimeFactory.Build(cfg, r.Mut, r.Size)
	UIKit.Viewport(holder, model, { Dir = Vector3.new(0.3, 0.15, -1), Zoom = 0.95, ZIndex = 63 })
	local spin = RunService.RenderStepped:Connect(function(dt) if model.Parent then model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 1.8, 0)) end end)

	local y = 104 + vh
	UIKit.Text(card, { Text = cfg.Name, TextSize = 26, Scaled = true, Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, y), Stroke = 3.5, ZIndex = 62 })
	local tags = {}
	if r.Mut then tags[#tags + 1] = ('<font color="#%s">%s</font>'):format(Config.Mutations[r.Mut].Color:ToHex(), r.Mut:upper()) end
	if r.Size then tags[#tags + 1] = '<font color="#ffb400">' .. r.Size .. '</font>' end
	if #tags > 0 then
		UIKit.Text(card, { Text = table.concat(tags, "  "), RichText = true, TextSize = 22, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, y + 30), Stroke = 3, ZIndex = 62 })
	end
	UIKit.Text(card, { Text = "+$" .. Util.FormatNumber(r.Income) .. "/s", TextSize = 30, Color = C.Cash, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, y + 56), Stroke = 4, ZIndex = 62 })
	UIKit.Text(card, { Text = r.Placed and "✅ Added to your garage!" or "🎒 Sent to your backpack", TextSize = 16, Color = Color3.fromRGB(205, 205, 225),
		Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, h - 32), Scaled = true, Stroke = 2, ZIndex = 62 })
	if rar.Order >= 5 then UIKit.Shake(card, 9, 0.5) end
	return card, sc, spin, rar.Order
end

function EggHatchUI.Play(biomeId, results)
	busy = true
	State.Encounter = true
	local egg = Config.Eggs[biomeId] or Config.Eggs[Config.Biomes[1].Id]
	local n = #results
	UIKit.PlaySound("Hatch")

	local overlay = new("TextButton", { Name = "Hatch", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 6, 14), BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false, ZIndex = 50 }, gui)
	UIKit.Tween(overlay, 0.3, { BackgroundTransparency = 0.3 })
	local burst = UIKit.Sunburst(overlay, egg.Color, 14, 51)
	local title = UIKit.Text(overlay, { Text = "🥚 " .. egg.Name:upper() .. " 🥚", TextSize = 44, Size = UDim2.fromOffset(800, 56), Position = UDim2.new(0.5, 0, 0.12, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 5, ZIndex = 60 })
	UIKit.Gradient(title, egg.Color:Lerp(Color3.new(1, 1, 1), 0.4), egg.Color, 90)
	UIKit.Pop(title, 1.3)

	-- 1) ovos caem quicando
	local spacing = n > 1 and 260 or 0
	local eggs = {}
	for i = 1, n do
		local xoff = (i - (n + 1) / 2) * spacing
		local holder = new("Frame", { Size = UDim2.fromOffset(230, 270), Position = UDim2.new(0.5, xoff, -0.4, 0), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1, ZIndex = 52 }, overlay)
		local vp = UIKit.Viewport(holder, EggVisuals.Build(biomeId, 1), { Dir = Vector3.new(0, 0.12, -1), Zoom = 1.05, ZIndex = 53 })
		UIKit.Tween(holder, 0.7 + i * 0.08, { Position = UDim2.new(0.5, xoff, 0.52, 0) }, Enum.EasingStyle.Bounce)
		eggs[i] = { Holder = holder, Vp = vp }
	end
	task.wait(1.0)

	-- 2) tremem cada vez mais + rachaduras
	for k = 1, 3 do
		UIKit.PlaySound("Crack")
		local amp = 7 * k
		for _, e in ipairs(eggs) do
			UIKit.Tween(e.Vp, 0.07, { Rotation = amp }); task.delay(0.07, function() UIKit.Tween(e.Vp, 0.14, { Rotation = -amp }) end)
			task.delay(0.21, function() UIKit.Tween(e.Vp, 0.08, { Rotation = 0 }) end)
			if k >= 2 then
				for _ = 1, 2 do
					new("Frame", { Size = UDim2.fromOffset(math.random(26, 46), 4), Position = UDim2.new(0.5, math.random(-40, 40), 0.5, math.random(-60, 30)),
						AnchorPoint = Vector2.new(0.5, 0.5), Rotation = math.random(-60, 60), BackgroundColor3 = Color3.fromRGB(20, 20, 26), BorderSizePixel = 0, ZIndex = 55 }, e.Holder)
				end
			end
		end
		task.wait(0.42 + (3 - k) * 0.08)
	end

	-- 3) clarão
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 80 }, overlay)
	UIKit.Tween(flash, 0.6, { BackgroundTransparency = 1 })
	for _, e in ipairs(eggs) do e.Holder:Destroy() end
	title.Visible = false

	-- 4) revelação
	local w, h = (n > 1) and 240 or 330, (n > 1) and 380 or 470
	local cards, best = {}, 0
	for i, r in ipairs(results) do
		local card, sc, spin, order = revealCard(overlay, r, w, h, (i - (n + 1) / 2) * spacing)
		cards[#cards + 1] = { Card = card, Scale = sc, Spin = spin }
		best = math.max(best, order)
	end
	local topRar = Config.Rarities[Config.RarityOrder[best]]
	UIKit.PlaySound(best >= 4 and "Rare" or "Reveal")
	UIKit.Confetti(overlay, Config.RarityFx(topRar), 20 + best * 10)
	burst:Destroy()
	burst = UIKit.Sunburst(overlay, Config.RarityFx(topRar), 16, 51)
	if best >= 7 then
		local secret = UIKit.Text(overlay, { Text = "✨ SECRET HATCHED! ✨", TextSize = 64, Size = UDim2.fromOffset(900, 80), Position = UDim2.new(0.5, 0, 0.08, 0),
			AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 6, ZIndex = 70 })
		UIKit.RarityLabel(secret, topRar); UIKit.Pop(secret, 1.6); UIKit.Shake(overlay, 6, 0.8)
		UIKit.Confetti(overlay, Color3.new(1, 1, 1), 60)
	end

	-- 5) fechar (toque ou tempo)
	local closed = false
	local done = Instance.new("BindableEvent")
	local function close()
		if closed then return end
		closed = true
		for _, c in ipairs(cards) do
			c.Spin:Disconnect()
			UIKit.Tween(c.Scale, 0.2, { Scale = 0.05 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		UIKit.Tween(overlay, 0.25, { BackgroundTransparency = 1 })
		task.delay(0.27, function() overlay:Destroy(); done:Fire() end)
	end
	task.delay(0.8, function() overlay.Activated:Connect(close) end) -- evita fechar por toque acidental
	task.delay(4.5 + (n > 1 and 1.5 or 0) + (best >= 6 and 1.5 or 0), close)
	done.Event:Wait()
	State.Encounter = false
	busy = false
end

local ERR = { Locked = "🔒 Your car's tier is too low for this biome!", NoGarage = "🏁 Choose a garage first!", Cooldown = "⏳ This egg is recharging!" }
function EggHatchUI.FromRoad(nodeName)
	if busy then return false, "Busy" end
	busy = true
	local r = Net.Call("CollectRoadEgg", nodeName)
	if not r or not r.ok then
		busy = false
		if r and ERR[r.err] then Notify.Toast(ERR[r.err], "error") end
		return false, r and r.err
	end
	EggHatchUI.Play(r.Biome, r.Results)
	return true
end

function EggHatchUI.Init()
	gui = UIKit.GetGui()
end

return EggHatchUI
