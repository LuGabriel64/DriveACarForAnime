--[[
	Platform  (StarterPlayerScripts.Client.Platform)                                             Beta 1.9
	=====================================================================================================
	UM lugar que responde: "em que aparelho este jogador está e de que tamanho a interface deve ser?"
	Todo overlay novo (corrida 1v1, batalha, convite) e os antigos (HUD, painéis) perguntam aqui.

	CLASSES DE APARELHO (Platform.Class)
	    "Phone"    toque + tela baixa (lado menor < 500)   => overlays COMPACTOS: a pista precisa aparecer
	    "Tablet"   toque + tela maior
	    "Desktop"  teclado e mouse
	    "Console"  interface de TV (10 pés): textos maiores, margem de segurança, tudo navegável no controle

	REGRAS DE TAMANHO (Platform.Rules) — valem para TODO overlay que fica na tela DURANTE a corrida/batalha
	    Phone   : escala 0,70 | no máximo 12% da altura da tela | fora do centro (60% do meio fica livre)
	              e fora das zonas dos polegares (joystick embaixo à esquerda, botões embaixo à direita)
	    Tablet  : escala 0,85 | no máximo 14% da altura
	    Desktop : escala 1,00 | no máximo 18% da altura (janela pequena encolhe; tela grande cresce até 1,2)
	    Console : escala 1,25 | margem de 5% nas bordas (TVs cortam a imagem)
	    Botões de toque nunca menores que 44 x 44 pontos DEPOIS da escala.

	API
	    Platform.Class                      classe atual (muda se o jogador trocar de entrada/tamanho de janela)
	    Platform.Input                      "Touch" | "Gamepad" | "Keyboard" (última entrada usada: para dicas de tecla)
	    Platform.Scale(kind)                fator para um tipo de UI: "Overlay" | "Panel" | "Hud"
	    Platform.Apply(guiObject, kind)     cria/atualiza um UIScale ("PlatformScale") no objeto e mantém atualizado
	    Platform.SafeArea(screenGui)        liga os recuos seguros do aparelho (entalhe, barra de gestos)
	    Platform.IsCompact()                true no Phone (use para trocar o layout, não só encolher)
	    Platform.KeyHint(keyboard, gamepad, touch)  devolve o texto certo para a entrada atual
	    Platform.OnChanged(fn)              avisa quando Class, Input ou o tamanho da tela mudam

	Dependências: nenhuma (só serviços do Roblox). Não depende do UIKit: o UIKit é que usa este módulo.
	É o PRIMEIRO do ClientMain.ORDER, mas funciona mesmo antes do Init (usa a classe detectada na hora).
	NÃO TESTADO em aparelho real: só no Studio (janela de PC). Conferir no emulador de dispositivos (Test > Device).
]]
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Platform = {}

Platform.Rules = {
	Phone   = { Overlay = 0.70, Panel = 0.82, Hud = 0.74, MaxOverlayHeight = 0.12, EdgeMargin = 0.00 },
	Tablet  = { Overlay = 0.85, Panel = 0.92, Hud = 0.88, MaxOverlayHeight = 0.14, EdgeMargin = 0.00 },
	Desktop = { Overlay = 1.00, Panel = 1.00, Hud = 1.00, MaxOverlayHeight = 0.18, EdgeMargin = 0.00 },
	Console = { Overlay = 1.25, Panel = 1.15, Hud = 1.20, MaxOverlayHeight = 0.18, EdgeMargin = 0.05 },
}
Platform.MinTouchTarget = 44
-- Tela de referência dos tamanhos em pixels já usados no jogo (UIKit usa UDim2.fromOffset).
Platform.Reference = Vector2.new(1280, 720)
-- No PC: a janela pequena encolhe até DesktopMin e a tela grande cresce até DesktopMax.
Platform.DesktopMin, Platform.DesktopMax = 0.6, 1.2

Platform.Class = "Desktop"
Platform.Input = "Keyboard"

local listeners = {}
local applied = {} -- [UIScale] = kind

local function viewport()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize
	if not v or v.X < 10 or v.Y < 10 then return Platform.Reference end -- câmera ainda não pronta
	return v
end

local function detectClass()
	local ok, tenFoot = pcall(function() return GuiService:IsTenFootInterface() end)
	if ok and tenFoot then return "Console" end
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local v = viewport()
		return (math.min(v.X, v.Y) < 500) and "Phone" or "Tablet"
	end
	return "Desktop"
end

local function detectInput(lastType)
	local name = lastType and lastType.Name or ""
	if name == "Touch" then return "Touch" end
	if string.sub(name, 1, 7) == "Gamepad" then return "Gamepad" end
	if name == "Keyboard" or string.sub(name, 1, 5) == "Mouse" then return "Keyboard" end
	return Platform.Input
end

-- Fator final = regra da classe x ajuste pelo tamanho da tela.
function Platform.Scale(kind)
	local rule = Platform.Rules[Platform.Class] or Platform.Rules.Desktop
	local base = rule[kind or "Overlay"] or 1
	local v = viewport()
	local fit = math.min(v.X / Platform.Reference.X, v.Y / Platform.Reference.Y)
	if Platform.Class == "Phone" or Platform.Class == "Tablet" then
		-- no toque a regra da classe já é o tamanho pensado; só encolhe mais se a tela for MUITO pequena
		fit = math.clamp(fit / 0.6, 0.75, 1)
	else
		fit = math.clamp(fit, Platform.DesktopMin, Platform.DesktopMax)
	end
	return base * fit
end

function Platform.IsCompact()
	return Platform.Class == "Phone"
end

-- Tamanho útil da tela (em pontos). Para layouts que mudam com a largura.
function Platform.Viewport()
	return viewport()
end

function Platform.Apply(guiObject, kind)
	local scale = guiObject:FindFirstChild("PlatformScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "PlatformScale"
		scale.Parent = guiObject
		scale.Destroying:Connect(function() applied[scale] = nil end)
	end
	scale.Scale = Platform.Scale(kind)
	scale:SetAttribute("Rest", scale.Scale) -- UIKit.Pop volta para este valor (não para 1)
	applied[scale] = kind or "Overlay"
	return scale
end

function Platform.SafeArea(screenGui)
	pcall(function() screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)
	pcall(function() screenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension end)
end

function Platform.KeyHint(keyboard, gamepad, touch)
	if Platform.Input == "Touch" then return touch end
	if Platform.Input == "Gamepad" then return gamepad end
	return keyboard
end

function Platform.OnChanged(fn)
	listeners[#listeners + 1] = fn
end

local function refresh()
	Platform.Class = detectClass()
	for scale, kind in pairs(applied) do
		scale.Scale = Platform.Scale(kind)
		scale:SetAttribute("Rest", scale.Scale)
	end
end

local function notify()
	for _, fn in ipairs(listeners) do
		task.spawn(fn, Platform.Class, Platform.Input)
	end
end

local started = false
function Platform.Init()
	if started then return end
	started = true
	Platform.Input = detectInput(UserInputService:GetLastInputType())
	refresh()
	UserInputService.LastInputTypeChanged:Connect(function(lastType)
		local input = detectInput(lastType)
		if input ~= Platform.Input then
			Platform.Input = input
			notify()
		end
	end)
	local camConn
	local function watchCamera()
		if camConn then camConn:Disconnect() end
		local cam = workspace.CurrentCamera
		if cam then
			camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				refresh(); notify()
			end)
		end
	end
	watchCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera(); refresh(); notify()
	end)
end

-- A classe já vale mesmo se alguém usar o módulo antes do ClientMain chamar o Init.
Platform.Class = detectClass()

return Platform
