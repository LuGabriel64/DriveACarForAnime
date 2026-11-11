--[[
	AnimesPanel: "My Animes" (referência: imagem 5). Seções IN YOUR GARAGE / BACKPACK, botões
	PICK UP / EQUIP / SELL e EQUIP BEST. Atualiza sozinho quando o servidor envia "Inventory".
]]
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local AnimeFactory = require(Shared.AnimeModelFactory)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Notify = require(script.Parent.Notify)
local new, C = UIKit.New, UIKit.C

local AnimesPanel = {}
local panel, scroll, capLabel
local dirty = true

local ERR = {
	PlotFull = "🐾 Your garage is full! Pick up or sell an anime.",
	Invalid = "Something changed, try again.",
}

local function act(name, uid)
	local r = Net.Call(name, uid)
	if not r then return end
	if not r.ok then Notify.Toast(ERR[r.err] or "Couldn't do that.", "error")
	elseif r.value then Notify.Toast("💰 Sold for $" .. Util.FormatNumber(r.value), "good") end
end

local function section(text, order)
	return UIKit.Text(scroll, { Name = "Section", Text = text, RichText = true, TextSize = 22, Size = UDim2.new(1, 0, 0, 30),
		AlignX = Enum.TextXAlignment.Left, LayoutOrder = order, Stroke = 3 })
end

local function card(e, order)
	local cfg = Config.AnimeById[e.Id]
	if not cfg then return end
	local rar = Config.Rarities[cfg.Rarity]
	local f = new("Frame", { Name = "Card_" .. e.Uid, Size = UDim2.new(1, -6, 0, 104), BackgroundColor3 = C.CardBg, LayoutOrder = order }, scroll)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, f); UIKit.Stroke(f, 3.5)

	local icon = new("Frame", { Size = UDim2.fromOffset(86, 86), Position = UDim2.fromOffset(9, 9), BackgroundColor3 = rar.Color }, f)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, icon); UIKit.Stroke(icon, 3)
	if UIKit.RarityFx(icon, rar, 70) then -- SECRET: fundo preto (Void) com brilho girando
	else new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 120)), Rotation = 90 }, icon) end
	local m = AnimeFactory.Build(cfg, e.Mut, e.Size)
	UIKit.Viewport(icon, m, { Dir = Vector3.new(0.35, 0.2, -1), Zoom = 0.95 })

	local txt = new("Frame", { Size = UDim2.new(1, -212, 1, -14), Position = UDim2.fromOffset(104, 7), BackgroundTransparency = 1 }, f)
	local tag = string.upper(cfg.Rarity)
	local rich = ('<font color="#%s">%s</font>'):format(Config.RarityText(rar):ToHex(), tag)
	if e.Mut then rich ..= ('  <font color="#%s">%s</font>'):format(Config.Mutations[e.Mut].Color:ToHex(), e.Mut:upper()) end
	if e.Size then rich ..= ('  <font color="#ffb400">%s</font>'):format(e.Size) end
	UIKit.Text(txt, { Text = rich, RichText = true, TextSize = 14, Size = UDim2.new(1, 0, 0, 20), AlignX = Enum.TextXAlignment.Left, Stroke = 2 })
	UIKit.Text(txt, { Text = cfg.Name, TextSize = 21, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 30),
		AlignX = Enum.TextXAlignment.Left, Stroke = 3, Scaled = true })
	UIKit.Text(txt, { Text = "$" .. Util.FormatNumber(e.Income) .. "/s", TextSize = 24, Color = C.Cash, Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 30), AlignX = Enum.TextXAlignment.Left, Stroke = 3 })

	local top = UIKit.Button(f, { Text = e.Placed and "PICK UP" or "EQUIP", Size = UDim2.fromOffset(98, 40), Position = UDim2.new(1, -108, 0, 9),
		Color = e.Placed and C.Blue or C.Green, OnClick = function() act(e.Placed and "PickUpAnime" or "PlaceAnime", e.Uid) end })
	local armed = false
	UIKit.Button(f, { Text = "SELL", Size = UDim2.fromOffset(98, 40), Position = UDim2.new(1, -108, 0, 55), Color = C.Red,
		OnClick = function(b)
			if rar.Order >= 4 and not armed then -- raros pedem confirmação
				armed = true; UIKit.SetButton(b, "SURE?", C.Orange)
				task.delay(2.5, function() armed = false; if b.Parent then UIKit.SetButton(b, "SELL", C.Red) end end)
				return
			end
			act("SellAnime", e.Uid)
		end })
end

local function refresh()
	if not panel.IsOpen then dirty = true; return end
	dirty = false
	for _, ch in ipairs(scroll:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
	local placed, pack = {}, {}
	for _, e in ipairs(State.Inventory) do table.insert(e.Placed and placed or pack, e) end
	local function byIncome(a, b) if a.Income ~= b.Income then return a.Income > b.Income end return a.Uid < b.Uid end
	table.sort(placed, byIncome); table.sort(pack, byIncome)
	capLabel.Text = ("🐾 %d/%d"):format(#placed, State.PlotSlots)

	section(('ON YOUR FARM  <font color="#57e63c">%d/%d</font>'):format(#placed, State.PlotSlots), 0)
	for i, e in ipairs(placed) do card(e, i) end
	section(('BACKPACK  <font color="#ffc828">%d</font>'):format(#pack), 1000)
	for i, e in ipairs(pack) do card(e, 1000 + i) end
	if #placed == 0 and #pack == 0 then
		UIKit.Text(scroll, { Text = "Race to the end of a biome, grab the Giant Egg and escape back to base before the track collapses!", TextSize = 20, Color = Color3.fromRGB(190, 190, 210),
			Size = UDim2.new(1, 0, 0, 70), LayoutOrder = 500, Wrapped = true, Stroke = 2 })
	end
end

function AnimesPanel.Init()
	panel = UIKit.Panel({ Name = "Animes", Title = "My Animes", HeaderColor = C.Magenta, Size = UDim2.fromScale(0.36, 0.82), MaxSize = Vector2.new(470, 680) })
	local pillF = new("Frame", { Size = UDim2.fromOffset(112, 38), Position = UDim2.new(1, -68, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(20, 56, 18), ZIndex = 23 }, panel.Header)
	new("UICorner", { CornerRadius = UDim.new(0, 19) }, pillF); UIKit.Stroke(pillF, 3)
	capLabel = UIKit.Text(pillF, { Text = "🐾 0/10", TextSize = 22, Color = C.Cash, ZIndex = 24 })

	scroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -64), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22 }, panel.Body)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	new("UIPadding", { PaddingRight = UDim.new(0, 4) }, scroll)

	UIKit.Button(panel.Body, { Name = "EquipBest", Text = "EQUIP BEST", Size = UDim2.new(1, 0, 0, 54), Position = UDim2.new(0, 0, 1, -54),
		Color = C.Orange, ZIndex = 23, TextSize = 30, Radius = 12, OnClick = function()
			local r = Net.Call("EquipBest")
			if r and r.ok then Notify.Toast("⭐ Best animes equipped!", "good") end
		end })

	panel.OnOpen = function() if dirty then refresh() else refresh() end end
	State.Changed.Event:Connect(function(what) if what == "Inventory" then refresh() end end)
end

return AnimesPanel
