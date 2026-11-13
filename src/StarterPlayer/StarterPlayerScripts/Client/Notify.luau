--[[
	Notify: avisos rápidos (toasts) no topo da tela. Servidor: Net.Fire(player, "Toast", texto, "info"|"good"|"error")
	Beta 1.9: * texto fixo com tradução (Shared.Locale) sai no idioma do jogador; texto já montado passa direto.
	          * tamanho por aparelho (Client.Platform, tipo "Overlay"); no celular a largura máxima é 80% da tela.
	          * evento "LevelUp" do servidor vira um aviso ("⬆️ Gokun reached level 7!").
]]
local RS = game:GetService("ReplicatedStorage")
local Net = require(RS.Shared.Net)
local UIKit = require(script.Parent.UIKit)
local new, C = UIKit.New, UIKit.C

local Notify = {}
local holder

function Notify.Toast(text, kind)
	if not holder then return end
	if type(text) == "string" and UIKit.Locale.Has(text) then text = UIKit.T(text) end
	local bg = kind == "error" and Color3.fromRGB(150, 30, 40) or kind == "good" and Color3.fromRGB(30, 130, 40) or Color3.fromRGB(28, 28, 46)
	local label = new("TextLabel", { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = bg,
		BackgroundTransparency = 1, Font = UIKit.Font, TextSize = 20, TextColor3 = C.White, Text = text, TextTransparency = 1, ZIndex = 81 }, holder)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, label)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, label)
	local stroke = UIKit.Stroke(label, 3); stroke.Transparency = 1
	UIKit.Tween(label, 0.18, { BackgroundTransparency = 0.1, TextTransparency = 0 })
	UIKit.Tween(stroke, 0.18, { Transparency = 0 })
	UIKit.Pop(label, 1.12)
	task.delay(2.6, function()
		if not label.Parent then return end
		UIKit.Tween(label, 0.4, { BackgroundTransparency = 1, TextTransparency = 1 })
		local tw = UIKit.Tween(stroke, 0.4, { Transparency = 1 })
		tw.Completed:Connect(function() label:Destroy() end)
	end)
end

function Notify.Init()
	holder = new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(460, 220), Position = UDim2.new(0.5, 0, 0, 74),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 80 }, UIKit.GetGui())
	new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, holder)
	UIKit.Platform.Apply(holder, "Overlay")
	Net.On("Toast", Notify.Toast)
	Net.On("LevelUp", function(info)
		if type(info) ~= "table" then return end
		Notify.Toast(UIKit.T("⬆️ %s reached level %d!", tostring(info.Name), tonumber(info.Level) or 1), "good")
	end)
end

return Notify
