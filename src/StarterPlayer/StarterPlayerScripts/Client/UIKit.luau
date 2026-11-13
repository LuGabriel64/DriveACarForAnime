--[[
	UIKit: biblioteca de UI no estilo das referências (Steal an Egg / Throw a Food for Animals):
	fonte grossa (FredokaOne), contorno preto forte, cantos arredondados, painéis escuros com
	cabeçalho colorido, botão X vermelho e botões com animação de clique (pop + squash).
	Todas as telas do jogo usam estas funções => visual consistente e fácil de ajustar.

	  UIKit.New(class, props, parent)      cria instância (Parent por último = mais rápido)
	  UIKit.Text(parent, p)                TextLabel com contorno
	  UIKit.Button(parent, p)              botão animado  (p.OnClick)
	  UIKit.MenuButton(parent, p)          botão quadrado de menu (ícone + legenda)
	  UIKit.Panel(p)                       painel com cabeçalho/fechar/abrir animado (registra em UIKit.Panels)
	  UIKit.Viewport(parent, model, p)     ViewportFrame enquadrando o modelo
	  UIKit.Pop / Shake / Confetti / Tween / PlaySound

	Beta 1.9
	  * IDIOMAS: Text / Button / MenuButton / Panel / SetButton chamam Locale.Bind quando o texto tem tradução
	    (Shared.Locale). O texto é retraduzido sozinho quando o jogador troca o idioma. Texto dinâmico (sem
	    tradução na tabela) não é tocado. UIKit.T(key, ...) = atalho de Locale.T para textos montados.
	  * PLATAFORMA: os painéis abrem no tamanho de Platform.Scale("Panel") (menor no celular, maior na TV).
]]
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Locale = require(RS.Shared.Locale)       -- Beta 1.9: tradução
local Platform = require(script.Parent.Platform) -- Beta 1.9: tamanho por aparelho

local UIKit = {}
UIKit.Locale, UIKit.Platform = Locale, Platform
-- Atalho: UIKit.T("Spin in: %s", tempo) -> texto no idioma do jogador.
function UIKit.T(key, ...) return Locale.T(key, ...) end
-- Põe um texto num objeto: traduzido e ligado (retraduz na troca de idioma) se a chave existir; senão, texto puro.
function UIKit.SetText(obj, text, ...)
	if type(text) == "string" and Locale.Has(text) then Locale.Bind(obj, text, ...)
	else Locale.Unbind(obj); obj.Text = (select("#", ...) > 0) and string.format(text, ...) or (text or "") end
end
UIKit.Font = Enum.Font.FredokaOne
UIKit.C = {
	PanelBg = Color3.fromRGB(14, 14, 22), CardBg = Color3.fromRGB(30, 30, 44),
	Red = Color3.fromRGB(228, 48, 48), Green = Color3.fromRGB(78, 214, 52),
	Blue = Color3.fromRGB(38, 128, 255), Orange = Color3.fromRGB(255, 166, 20),
	Magenta = Color3.fromRGB(206, 44, 206), Cyan = Color3.fromRGB(40, 200, 230),
	White = Color3.new(1, 1, 1), Cash = Color3.fromRGB(88, 255, 70),
	Gold = Color3.fromRGB(255, 200, 40), Grey = Color3.fromRGB(110, 110, 124),
}
local C = UIKit.C

local function new(class, props, parent)
	local o = Instance.new(class)
	if props then for k, v in pairs(props) do o[k] = v end end
	if parent then o.Parent = parent end
	return o
end
UIKit.New = new

function UIKit.Tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local tween = UIKit.Tween

function UIKit.GetGui()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = pg:FindFirstChild("GameUI")
	if not gui then
		gui = new("ScreenGui", { Name = "GameUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 }, pg)
	end
	return gui
end

function UIKit.PlaySound(name)
	if Players.LocalPlayer:GetAttribute("Set_SFX") == false then return end -- menu CONFIGS
	local id = Config.Sounds[name]
	if not id or id == "" then return end
	local s = new("Sound", { SoundId = id, Volume = 0.6 }, SoundService)
	s:Play(); Debris:AddItem(s, 6)
end

function UIKit.Stroke(parent, thickness, color)
	return new("UIStroke", { Thickness = thickness or 3, Color = color or Color3.new(0, 0, 0), LineJoinMode = Enum.LineJoinMode.Round }, parent)
end

function UIKit.Text(parent, p)
	local t = new("TextLabel", {
		Name = p.Name or "Text", BackgroundTransparency = 1,
		Size = p.Size or UDim2.fromScale(1, 1), Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero, Font = p.Font or UIKit.Font,
		Text = p.Text or "", TextColor3 = p.Color or C.White, TextSize = p.TextSize or 24,
		TextScaled = p.Scaled or false, RichText = p.RichText or false,
		TextXAlignment = p.AlignX or Enum.TextXAlignment.Center, TextYAlignment = p.AlignY or Enum.TextYAlignment.Center,
		ZIndex = p.ZIndex or 1, LayoutOrder = p.LayoutOrder or 0, TextWrapped = p.Wrapped or false,
	}, parent)
	if p.Scaled then new("UITextSizeConstraint", { MaxTextSize = p.TextSize or 24 }, t) end
	if p.Stroke ~= 0 then UIKit.Stroke(t, p.Stroke or 2.5) end
	if p.Text and p.Text ~= "" and Locale.Has(p.Text) then Locale.Bind(t, p.Text) end -- Beta 1.9
	return t
end

function UIKit.Button(parent, p)
	local z = p.ZIndex or 1
	local b = new("TextButton", {
		Name = p.Name or "Button", Text = "", AutoButtonColor = false,
		Size = p.Size or UDim2.fromOffset(120, 44), Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero, BackgroundColor3 = p.Color or C.Green,
		LayoutOrder = p.LayoutOrder or 0, ZIndex = z,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, p.Radius or 10) }, b)
	UIKit.Stroke(b, p.StrokeThickness or 3.5, p.StrokeColor)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)), Rotation = 90 }, b)
	local scale = new("UIScale", { Scale = 1 }, b)
	UIKit.Text(b, { Name = "Label", Text = p.Text or "", TextSize = p.TextSize or 22, Scaled = true,
		Size = UDim2.fromScale(0.9, 0.72), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z + 1, Stroke = p.TextStroke or 2.5 })

	b.MouseEnter:Connect(function() tween(scale, 0.12, { Scale = 1.07 }) end)
	b.MouseLeave:Connect(function() tween(scale, 0.12, { Scale = 1 }) end)
	b.MouseButton1Down:Connect(function() tween(scale, 0.06, { Scale = 0.9 }) end)
	b.MouseButton1Up:Connect(function() tween(scale, 0.25, { Scale = 1.07 }, Enum.EasingStyle.Back) end)
	b.Activated:Connect(function()
		UIKit.PlaySound("Click")
		if b:GetAttribute("Disabled") then
			tween(scale, 0.05, { Scale = 0.95 }); return
		end
		if p.OnClick then task.spawn(p.OnClick, b) end
	end)
	return b
end

-- Atualiza texto/cor de um botão; disabled=true deixa cinza e sem ação.
function UIKit.SetButton(b, text, color, disabled)
	local l = b:FindFirstChild("Label")
	if l and text then UIKit.SetText(l, text) end -- Beta 1.9: traduz se houver tradução
	if color then b.BackgroundColor3 = color end
	b:SetAttribute("Disabled", disabled or false)
end

function UIKit.MenuButton(parent, p)
	local b = UIKit.Button(parent, { Name = p.Name or p.Label, Size = p.Size or UDim2.fromOffset(78, 78),
		Color = p.Color or Color3.fromRGB(26, 26, 38), Radius = 14, StrokeThickness = 3.5, StrokeColor = p.StrokeColor or Color3.fromRGB(95, 95, 118),
		OnClick = p.OnClick, LayoutOrder = p.LayoutOrder, ZIndex = 2 })
	b.Label.Visible = false
	UIKit.Text(b, { Name = "Icon", Text = p.Icon, TextSize = 38, Size = UDim2.fromScale(1, 0.62), Position = UDim2.fromScale(0, 0.04), Stroke = 0, ZIndex = 3 })
	UIKit.Text(b, { Name = "Caption", Text = p.Label, TextSize = 17, Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.66), Stroke = 2.5, ZIndex = 3, Color = p.LabelColor })
	return b
end

-- ------------------------------------------------------------ painéis
UIKit.Panels = {}
function UIKit.Panel(p)
	local gui = p.Parent or UIKit.GetGui()
	-- Beta 1.4: fundo escurecido atrás do painel (tocar fora fecha) + entrada deslizando de baixo
	local dim = new("TextButton", { Name = p.Name .. "_Backdrop", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 4, 24), BackgroundTransparency = 1, Visible = false, ZIndex = 19 }, gui)
	local holder = new("Frame", { Name = p.Name, Size = p.Size, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.PanelBg, Visible = false, ZIndex = 20 }, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 18) }, holder)
	UIKit.Stroke(holder, 4.5)
	new("UISizeConstraint", { MaxSize = p.MaxSize or Vector2.new(700, 600), MinSize = p.MinSize or Vector2.new(300, 280) }, holder)
	local scale = new("UIScale", { Scale = 0.6 }, holder)

	local hc = p.HeaderColor or C.Magenta
	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = hc, ZIndex = 21 }, holder)
	new("UICorner", { CornerRadius = UDim.new(0, 18) }, header)
	new("Frame", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -30), BackgroundColor3 = hc, BorderSizePixel = 0, ZIndex = 21 }, header)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)), Rotation = 90 }, header)
	new("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 22 }, header)
	UIKit.Text(header, { Name = "Title", Text = p.Title, TextSize = 34, AlignX = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -150, 1, 0), ZIndex = 23, Stroke = 4 })

	UIKit.Shine(header, 3.5)
	local body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 72), Size = UDim2.new(1, -24, 1, -84), ZIndex = 21 }, holder)

	local obj = { Name = p.Name, Frame = holder, Body = body, Header = header, IsOpen = false }
	function obj.Open()
		if obj.IsOpen then return end
		for _, other in pairs(UIKit.Panels) do if other ~= obj and other.IsOpen then other.Close() end end
		obj.IsOpen = true
		holder.Visible = true
		local full = Platform.Scale("Panel") -- Beta 1.9: tamanho final por aparelho (antes: sempre 1)
		scale.Scale = 0.6 * full
		tween(scale, 0.3, { Scale = full }, Enum.EasingStyle.Back)
		holder.Position = UDim2.fromScale(0.5, 0.58)
		tween(holder, 0.35, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
		dim.Visible = true
		tween(dim, 0.25, { BackgroundTransparency = 0.45 })
		if obj.OnOpen then task.spawn(obj.OnOpen) end
	end
	function obj.Close()
		if not obj.IsOpen then return end
		obj.IsOpen = false
		local tw = tween(scale, 0.16, { Scale = 0.6 * Platform.Scale("Panel") }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(holder, 0.16, { Position = UDim2.fromScale(0.5, 0.56) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(dim, 0.18, { BackgroundTransparency = 1 })
		tw.Completed:Connect(function() if not obj.IsOpen then holder.Visible = false; dim.Visible = false end end)
	end
	function obj.Toggle() if obj.IsOpen then obj.Close() else obj.Open() end end

	dim.Activated:Connect(function() obj.Close() end)
	UIKit.Button(header, { Name = "Close", Text = "X", Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), Color = C.Red, ZIndex = 24, OnClick = obj.Close })
	UIKit.Panels[p.Name] = obj
	return obj
end
function UIKit.TogglePanel(name) local p = UIKit.Panels[name]; if p then p.Toggle() end end
function UIKit.OpenPanel(name) local p = UIKit.Panels[name]; if p then p.Open() end end

-- ------------------------------------------------------------ efeitos
function UIKit.Pop(obj, amount)
	local s = obj:FindFirstChildOfClass("UIScale") or new("UIScale", { Scale = 1 }, obj)
	-- Beta 1.9: se o objeto usa Platform.Apply, o tamanho de repouso é o do aparelho (atributo "Rest"), não 1
	local rest = s:GetAttribute("Rest") or 1
	s.Scale = rest * (amount or 1.15)
	local tw = tween(s, 0.4, { Scale = rest }, Enum.EasingStyle.Elastic)
	-- o tamanho de repouso pode mudar DURANTE o pop (janela redimensionada / câmera ficando pronta): confere no fim
	tw.Completed:Connect(function() if s.Parent then s.Scale = s:GetAttribute("Rest") or 1 end end)
end

function UIKit.Shake(obj, strength, duration)
	local origin = obj.Position
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < (duration or 0.4) do
			local k = strength or 8
			obj.Position = origin + UDim2.fromOffset(math.random(-k, k), math.random(-k, k))
			task.wait(0.02)
		end
		obj.Position = origin
	end)
end

function UIKit.Confetti(parent, color, count)
	for i = 1, count or 30 do
		local f = new("Frame", { Size = UDim2.fromOffset(math.random(8, 14), math.random(8, 14)), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = (i % 3 == 0) and Color3.new(1, 1, 1) or color,
			BorderSizePixel = 0, Rotation = math.random(0, 360), ZIndex = 60 }, parent)
		new("UICorner", { CornerRadius = UDim.new(0, 3) }, f)
		local ang, dist = math.random() * math.pi * 2, math.random(160, 440)
		local target = UDim2.new(0.5, math.cos(ang) * dist, 0.5, math.sin(ang) * dist * 0.8 + 140)
		local tw = tween(f, 0.9 + math.random() * 0.6, { Position = target, Rotation = math.random(-540, 540), BackgroundTransparency = 1 })
		tw.Completed:Connect(function() f:Destroy() end)
	end
end

-- Coloca um modelo (já construído) num ViewportFrame com câmera enquadrada.
function UIKit.Viewport(parent, model, p)
	p = p or {}
	local vp = new("ViewportFrame", { Name = "Viewport", Size = p.Size or UDim2.fromScale(1, 1), Position = p.Position or UDim2.new(),
		BackgroundTransparency = 1, Ambient = Color3.fromRGB(205, 205, 205), LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.4, -1, -0.6), ZIndex = p.ZIndex or 3 }, parent)
	local cam = new("Camera", { FieldOfView = 35 }, vp)
	vp.CurrentCamera = cam
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	-- Beta 1.8b: enquadra pela MAIOR medida (antes: diagonal 3D) => personagens de cabelo espetado não ficam minúsculos
	local dist = (math.max(size.X, size.Y, size.Z) * 0.6) / math.tan(math.rad(cam.FieldOfView / 2))
	local dir = (p.Dir or Vector3.new(0.55, 0.3, -1)).Unit
	cam.CFrame = CFrame.lookAt(cf.Position + dir * dist * (p.Zoom or 1.0), cf.Position)
	return vp, model
end

-- ============================================================ EFEITOS "VIVOS" (Beta 1.1)
local RunService = game:GetService("RunService")
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 180, 60)),
	ColorSequenceKeypoint.new(0.34, Color3.fromRGB(255, 255, 90)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 120)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(80, 200, 255)), ColorSequenceKeypoint.new(0.84, Color3.fromRGB(170, 100, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 80)) })
UIKit.RainbowSequence = RAINBOW
local rainbowProps, spinGradients, loopOn = {}, {}, false
local function startLoop()
	if loopOn then return end
	loopOn = true
	RunService.RenderStepped:Connect(function(dt)
		local h = (os.clock() * 0.22) % 1
		for obj, prop in pairs(rainbowProps) do
			if obj.Parent then obj[prop] = Color3.fromHSV(h, 0.7, 1) else rainbowProps[obj] = nil end
		end
		for g, speed in pairs(spinGradients) do
			if g.Parent then g.Rotation = (g.Rotation + dt * speed) % 360 else spinGradients[g] = nil end
		end
	end)
end
-- Arco-íris animado (raridade SECRET). Funciona em TextLabel, UIStroke e Frames.
function UIKit.Rainbow(obj, prop)
	rainbowProps[obj] = prop or ((obj:IsA("TextLabel") or obj:IsA("TextButton")) and "TextColor3" or (obj:IsA("UIStroke") and "Color") or "BackgroundColor3")
	startLoop()
end
-- Gradiente girando (padrão: arco-íris). Em UIStroke vira uma borda animada.
function UIKit.SpinGradient(obj, seq, speed)
	local g = new("UIGradient", { Color = seq or RAINBOW }, obj)
	spinGradients[g] = speed or 90
	startLoop()
	return g
end
-- Beta 1.7: estilo VOID (raridade SECRET = PRETO). Preto com um brilho prateado girando devagar.
-- VoidFill: fundo/borda (o UIGradient multiplica a cor => a base vira branca e o gradiente dá o preto).
-- VoidText: texto PRETO com contorno branco pulsando (legível em qualquer fundo).
local VOID = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 8, 10)), ColorSequenceKeypoint.new(0.42, Color3.fromRGB(14, 14, 18)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(92, 92, 108)), ColorSequenceKeypoint.new(0.58, Color3.fromRGB(14, 14, 18)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 10)) })
UIKit.VoidSequence = VOID
function UIKit.VoidFill(obj, speed)
	if obj:IsA("UIStroke") then obj.Color = Color3.new(1, 1, 1) elseif obj:IsA("GuiObject") then obj.BackgroundColor3 = Color3.new(1, 1, 1) end
	return UIKit.SpinGradient(obj, VOID, speed or 60)
end
local voidTexts = {}
function UIKit.VoidText(obj)
	obj.TextColor3 = Color3.fromRGB(10, 10, 14)
	local st = obj:FindFirstChildOfClass("UIStroke") or UIKit.Stroke(obj, 2.5)
	st.Color = Color3.new(1, 1, 1)
	voidTexts[st] = true
	if not voidTexts._loop then
		voidTexts._loop = true
		RunService.RenderStepped:Connect(function()
			local k = 0.5 + math.sin(os.clock() * 3) * 0.5
			local c = Color3.fromRGB(150, 150, 165):Lerp(Color3.new(1, 1, 1), k)
			for s in pairs(voidTexts) do
				if s ~= "_loop" then if s.Parent then s.Color = c else voidTexts[s] = nil end end
			end
		end)
	end
end
-- Fundo/borda de raridade: Void (preto), Rainbow (arco-íris) ou nada (false => quem chamou aplica o normal)
function UIKit.RarityFx(obj, rar, speed)
	if rar.Void then UIKit.VoidFill(obj, speed); return true end
	if rar.Rainbow then UIKit.SpinGradient(obj, nil, speed); return true end
	return false
end
function UIKit.RarityLabel(obj, rar)
	if rar.Void then UIKit.VoidText(obj) elseif rar.Rainbow then UIKit.Rainbow(obj) end
end
function UIKit.Gradient(obj, c1, c2, rot)
	return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 90 }, obj)
end
-- Faixa de brilho que atravessa o objeto de tempos em tempos (botões/cabeçalhos "vivos")
function UIKit.Shine(obj, every)
	local corner = obj:FindFirstChildOfClass("UICorner")
	local shine = new("Frame", { Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = obj.ZIndex }, obj)
	new("UICorner", { CornerRadius = corner and corner.CornerRadius or UDim.new(0, 10) }, shine)
	local g = new("UIGradient", { Rotation = 20, Offset = Vector2.new(-1, 0), Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) }) }, shine)
	task.spawn(function()
		task.wait(math.random() * 1.5)
		while shine.Parent do
			g.Offset = Vector2.new(-1, 0)
			tween(g, 0.8, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
			task.wait((every or 2.5) + 0.8)
		end
	end)
	return shine
end
-- Texto que sobe e some ("+$120")
function UIKit.FloatText(parent, text, color, pos, size)
	local l = UIKit.Text(parent, { Text = text, TextSize = size or 26, Color = color, Size = UDim2.fromOffset(260, 34), Position = pos,
		AnchorPoint = Vector2.new(0, 0.5), AlignX = Enum.TextXAlignment.Left, Stroke = 3, ZIndex = 70 })
	local stroke = l:FindFirstChildOfClass("UIStroke")
	tween(l, 1.1, { Position = pos - UDim2.fromOffset(0, 46), TextTransparency = 1 })
	if stroke then tween(stroke, 1.1, { Transparency = 1 }) end
	Debris:AddItem(l, 1.2)
	return l
end
-- Raios de sol girando atrás de recompensas
function UIKit.Sunburst(parent, color, rays, z)
	rays = rays or 12
	local holder = new("Frame", { Name = "Sunburst", Size = UDim2.fromOffset(1000, 1000), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = z or 50 }, parent)
	for i = 1, rays do
		local r = new("Frame", { Size = UDim2.new(0, 80, 1, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color, BackgroundTransparency = 0.7, BorderSizePixel = 0, Rotation = i * (180 / rays), ZIndex = z or 50 }, holder)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1) }) }, r)
	end
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not holder.Parent then conn:Disconnect(); return end
		holder.Rotation = (holder.Rotation + dt * 18) % 360
	end)
	return holder
end
-- Balanço contínuo (logo, ícones)
function UIKit.Wobble(obj, degrees, period)
	task.spawn(function()
		while obj.Parent do
			tween(obj, period or 1.2, { Rotation = degrees or 4 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut); task.wait(period or 1.2)
			tween(obj, period or 1.2, { Rotation = -(degrees or 4) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut); task.wait(period or 1.2)
		end
	end)
end
-- Formata chance (0..1) como porcentagem legível
function UIKit.Percent(p)
	local v = p * 100
	if v >= 1 then return string.format("%.1f%%", v) elseif v >= 0.01 then return string.format("%.2f%%", v) end
	return string.format("%.3f%%", v)
end

return UIKit
