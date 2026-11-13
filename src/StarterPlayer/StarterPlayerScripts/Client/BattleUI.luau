--[[
	BattleUI  (StarterPlayerScripts.Client.BattleUI)                                             Beta 1.9
	=====================================================================================================
	ENCENA a batalha de anime. O servidor (Services.BattleService + BattleSim) já decidiu a luta inteira e manda o
	ROTEIRO no evento "BattleScript"; aqui só tocamos o roteiro, sem decidir nada. Os dois jogadores veem a mesma luta.

	O QUE ACONTECE NA TELA
	    Entrada (Intro)  câmera girando pela arena, os dois lutadores caem do céu, cartões com nome/raridade/★/nível/
	                     Poder e "FIGHT!"
	    Golpe            o atacante avança, acerta e volta; número de dano sobe; a barra de vida desce com atraso
	    Crítico          "CRITICAL!", tremor curto e clarão
	    Esquiva          "DODGE!", o alvo desliza para o lado
	    ULT              a tela escurece, faixa com o NOME DA ULT na cor da raridade, câmera fecha no lutador, efeito
	                     grande do tipo dele (Config.Battle.Fighters[id].Fx: beam slash punch storm flame ice sand light
	                     shadow tech blossom meteor); Bulwark ganha a bolha de escudo; Flurry dá vários golpes
	    Nocaute          "K.O.!", o perdedor voa para fora do ringue | tempo esgotado: "TIME'S UP!"
	    Vitória          a animação de vitória do vencedor (loja do Versus Hall) toca em cima dele
	Depois o Client.VersusUI mostra a tela de resultado com as recompensas (evento VersusResult do servidor).

	DETALHES
	  * Tudo é LOCAL (pasta dentro da Camera): várias batalhas podem usar a mesma arena ao mesmo tempo.
	  * Relógio = workspace:GetServerTimeNow(): a cena começa em StartAt nos dois aparelhos.
	  * O tremor de câmera respeita o interruptor "Speed Camera Effect" (Set_FOV).
	  * Celular (Platform.IsCompact): painéis menores, sem a linha de raridade, textos grandes mais acima.
	  * BattleUI.PlayVictory(id, posição) toca uma animação de vitória em qualquer lugar (reaproveitável).
	  * Evento "BattleAbort" (alguém saiu): limpa tudo na hora.

	Dependências: UIKit (Platform, T), Shared.Config / AnimeModelFactory / Util. NÃO TESTADO com 2 jogadores reais.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local AnimeFactory = require(Shared.AnimeModelFactory)
local UIKit = require(script.Parent.UIKit)
local new, C, T = UIKit.New, UIKit.C, UIKit.T
local Platform = UIKit.Platform
local lp = Players.LocalPlayer

local BattleUI = {}
local VB = Config.Versus.Battle
local sgui, topBar, big, ultBanner, dim
local panels = {}      -- [1|2] = { Hp, HpTrail, Shield, Energy, Root }
local token = 0        -- muda a cada cena: corta a cena antiga se outra começar ou se abortar
local scene            -- { Folder, Models = {m1, m2}, Pos = {p1, p2}, Center, Floor, Script }
local FIGHTER_SCALE = 1.7

local function now() return workspace:GetServerTimeNow() end
local function waitUntil(t, tk)
	while now() < t do
		if token ~= tk then return false end
		RunService.RenderStepped:Wait()
	end
	return token == tk
end
local function tw(obj, t, props, style, dir)
	local x = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end
local function shakeOn() return lp:GetAttribute("Set_FOV") ~= false end

-- ============================================================ efeitos 3D (peças locais que somem sozinhas)
local function fxPart(props, life)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	p.Parent = (scene and scene.Folder) or workspace.CurrentCamera
	Debris:AddItem(p, life or 1.5)
	return p
end

-- esfera que cresce e some
local function blast(pos, color, size, t)
	local p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = CFrame.new(pos), Color = color, Transparency = 0.1 }, (t or 0.6) + 0.2)
	tw(p, t or 0.6, { Size = Vector3.one * (size or 10), Transparency = 1 })
	return p
end
-- anel no chão (onda de choque)
local function ring(pos, color, size)
	local p = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1, 1), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Transparency = 0.15 }, 0.8)
	tw(p, 0.6, { Size = Vector3.new(0.3, size or 18, size or 18), Transparency = 1 })
end
-- estilhaços voando para todos os lados
local function burst(pos, color, count, size, speed, shape)
	for _ = 1, count or 10 do
		local s = (size or 1) * (0.6 + math.random() * 0.8)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
		local p = fxPart({ Shape = shape or Enum.PartType.Block, Size = Vector3.one * s, CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Color = color }, 1)
		tw(p, 0.7 + math.random() * 0.3, { CFrame = CFrame.new(pos + dir * (speed or 10)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Transparency = 1, Size = Vector3.one * s * 0.3 })
	end
end
-- raio de energia entre dois pontos
local function beam(from, to, color, width)
	local d = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
	local p = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(d, 0.3, 0.3), CFrame = cf, Color = color, Transparency = 0.05 }, 0.9)
	tw(p, 0.15, { Size = Vector3.new(d, width or 3, width or 3) })
	task.delay(0.35, function() if p.Parent then tw(p, 0.35, { Size = Vector3.new(d, 0.2, 0.2), Transparency = 1 }) end end)
	local core = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(d, (width or 3) * 0.4, (width or 3) * 0.4), CFrame = cf, Color = Color3.new(1, 1, 1) }, 0.5)
	tw(core, 0.45, { Transparency = 1 })
end
-- raio caindo do céu
local function bolt(pos, color)
	local top = pos + Vector3.new(math.random(-3, 3), 40, math.random(-3, 3))
	local mid = (top + pos) / 2 + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
	for _, seg in ipairs({ { top, mid }, { mid, pos } }) do
		local a, b = seg[1], seg[2]
		local p = fxPart({ Size = Vector3.new(0.6, 0.6, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color }, 0.4)
		tw(p, 0.35, { Transparency = 1 })
	end
	blast(pos, color, 6, 0.35)
end
-- corte (três lâminas finas em X)
local function slash(pos, color)
	for i = 1, 3 do
		local p = fxPart({ Size = Vector3.new(0.3, 0.6, 14), CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(-30 + i * 20), math.rad(45 * i), math.rad(60 * i)), Color = color }, 0.6)
		tw(p, 0.45, { Size = Vector3.new(0.1, 0.2, 20), Transparency = 1 })
	end
end
-- pétalas / partículas caindo
local function rain(pos, color, count, height)
	for _ = 1, count or 20 do
		local start = pos + Vector3.new(math.random(-12, 12), (height or 18) + math.random() * 8, math.random(-12, 12))
		local p = fxPart({ Size = Vector3.new(0.7, 0.15, 0.7), CFrame = CFrame.new(start) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Color = color, Material = Enum.Material.SmoothPlastic }, 2.2)
		tw(p, 1.6 + math.random() * 0.5, { CFrame = CFrame.new(start - Vector3.new(math.random(-4, 4), height or 18, math.random(-4, 4))) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Transparency = 1 }, Enum.EasingStyle.Sine)
	end
end
-- meteoro caindo do céu no alvo
local function meteor(pos, color)
	local start = pos + Vector3.new(-30, 60, -10)
	local p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 6, CFrame = CFrame.new(start), Color = color }, 1.2)
	local trail = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 9, CFrame = CFrame.new(start), Color = Color3.fromRGB(255, 160, 60), Transparency = 0.6 }, 1.2)
	tw(p, 0.45, { CFrame = CFrame.new(pos) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tw(trail, 0.45, { CFrame = CFrame.new(pos), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.45, function()
		blast(pos, color, 20, 0.7); ring(pos - Vector3.new(0, 3, 0), color, 30); burst(pos, Color3.fromRGB(80, 60, 50), 14, 1.6, 16)
	end)
end

-- Efeito de ULT por tipo (Config.Battle.Fighters[id].Fx). from = atacante, to = alvo, color = cor da raridade.
local ULT_FX = {
	beam = function(from, to, c) beam(from, to, c, 4); blast(to, c, 14) end,
	slash = function(_, to, c) slash(to, c); task.delay(0.15, function() slash(to, Color3.new(1, 1, 1)) end); burst(to, c, 8, 0.8, 9) end,
	punch = function(_, to, c) blast(to, c, 10, 0.4); ring(to - Vector3.new(0, 3, 0), c, 26); burst(to, c, 10, 1, 12) end,
	storm = function(_, to, c) for i = 1, 5 do task.delay(i * 0.08, function() bolt(to + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)), c) end) end end,
	flame = function(from, to, c) beam(from, to, Color3.fromRGB(255, 120, 30), 3); burst(to, Color3.fromRGB(255, 90, 20), 16, 1.6, 12, Enum.PartType.Ball); blast(to, c, 12) end,
	ice = function(_, to, c)
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local p = fxPart({ Size = Vector3.new(1.4, 0.2, 1.4), CFrame = CFrame.new(to + Vector3.new(math.cos(a) * 4, -3, math.sin(a) * 4)) * CFrame.Angles(math.cos(a) * 0.4, 0, math.sin(a) * 0.4),
				Color = Color3.fromRGB(170, 230, 255), Material = Enum.Material.Glass, Transparency = 0.2 }, 1.4)
			tw(p, 0.25, { Size = Vector3.new(1.4, 7, 1.4) }, Enum.EasingStyle.Back)
			task.delay(0.9, function() if p.Parent then tw(p, 0.4, { Transparency = 1 }) end end)
		end
		blast(to, c, 9)
	end,
	sand = function(_, to, c) burst(to, Color3.fromRGB(230, 190, 120), 22, 1, 14, Enum.PartType.Ball); ring(to - Vector3.new(0, 3, 0), c, 22) end,
	light = function(_, to, c) blast(to, Color3.new(1, 1, 0.85), 22, 0.7); blast(to, c, 12, 0.5); ring(to, c, 30) end,
	shadow = function(_, to, c) blast(to, Color3.fromRGB(40, 0, 60), 18, 0.8); burst(to, c, 12, 1, 10, Enum.PartType.Ball) end,
	tech = function(from, to, c) beam(from, to, Color3.fromRGB(70, 240, 255), 2); for i = 1, 3 do task.delay(i * 0.1, function() burst(to, Color3.fromRGB(70, 240, 255), 6, 0.9, 8) end) end; blast(to, c, 8) end,
	blossom = function(_, to, c) rain(to, Color3.fromRGB(255, 160, 210), 26, 14); blast(to, c, 10) end,
	meteor = function(_, to, c) meteor(to, c) end,
}

-- Animações de vitória (ids de Config.Battle.VictoryFx). Pública: também serve para outros modos.
local VICTORY_FX = {
	confetti = function(p) for _, col in ipairs({ C.Gold, C.Cyan, C.Magenta, C.Green }) do burst(p + Vector3.new(0, 4, 0), col, 10, 0.6, 14) end end,
	fireworks = function(p)
		for i = 1, 4 do
			task.delay(i * 0.35, function()
				local at = p + Vector3.new(math.random(-14, 14), 18 + math.random(0, 8), math.random(-10, 10))
				local col = Color3.fromHSV(math.random(), 0.8, 1)
				blast(at, col, 8, 0.4); burst(at, col, 14, 0.6, 10, Enum.PartType.Ball)
			end)
		end
	end,
	explosion = function(p) blast(p, Color3.fromRGB(255, 160, 40), 30, 0.9); blast(p, Color3.new(1, 1, 0.8), 14, 0.5); ring(p - Vector3.new(0, 3, 0), Color3.fromRGB(255, 120, 30), 44) end,
	lightning = function(p) for i = 1, 6 do task.delay(i * 0.12, function() bolt(p + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)), Color3.fromRGB(150, 210, 255)) end) end end,
	sakura = function(p) rain(p, Color3.fromRGB(255, 160, 210), 45, 22) end,
	meteor = function(p) meteor(p + Vector3.new(6, 0, 0), Color3.fromRGB(255, 110, 40)); task.delay(0.3, function() meteor(p - Vector3.new(6, 0, 0), Color3.fromRGB(255, 200, 80)) end) end,
	blackhole = function(p)
		local hole = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = CFrame.new(p + Vector3.new(0, 10, 0)), Color = Color3.fromRGB(10, 0, 20), Material = Enum.Material.SmoothPlastic }, 3)
		tw(hole, 0.8, { Size = Vector3.one * 14 }, Enum.EasingStyle.Back)
		for i = 1, 24 do
			local a = i / 24 * math.pi * 2
			local start = p + Vector3.new(math.cos(a) * 22, 10 + math.sin(a * 3) * 4, math.sin(a) * 22)
			local s = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = CFrame.new(start), Color = Color3.fromRGB(190, 90, 255) }, 2)
			tw(s, 1.4, { CFrame = CFrame.new(p + Vector3.new(0, 10, 0)), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.delay(2, function() if hole.Parent then tw(hole, 0.4, { Size = Vector3.one * 0.1, Transparency = 1 }) end end)
	end,
}
function BattleUI.PlayVictory(id, position)
	local fn = VICTORY_FX[id] or VICTORY_FX.confetti
	task.spawn(fn, position)
end

-- ============================================================ interface (barras no topo, textos grandes)
local function bigText(text, color, size, hold)
	big.Text = text
	big.TextColor3 = color or C.White
	big.Size = UDim2.new(0.9, 0, 0, size or 90)
	big.TextTransparency = 0
	local st = big:FindFirstChildOfClass("UIStroke"); if st then st.Transparency = 0 end
	big.Visible = true
	UIKit.Pop(big, 1.35)
	local mine = big:GetAttribute("N") or 0
	mine += 1
	big:SetAttribute("N", mine)
	task.delay(hold or 0.7, function()
		if big:GetAttribute("N") ~= mine then return end
		tw(big, 0.3, { TextTransparency = 1 })
		if st then tw(st, 0.3, { Transparency = 1 }) end
	end)
end

local function buildPanel(i, f)
	local right = i == 2
	local cfg = Config.AnimeById[f.Id]
	local rar = Config.Rarities[f.Rarity] or Config.Rarities.Common
	local compact = Platform.IsCompact()
	local root = new("Frame", { Name = "Fighter" .. i, Size = UDim2.new(0.5, -40, 1, 0), Position = right and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0),
		AnchorPoint = right and Vector2.new(1, 0) or Vector2.zero, BackgroundTransparency = 1 }, topBar)
	local align = right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	UIKit.Text(root, { Text = (cfg and cfg.Name or f.Id) .. "  •  " .. T("Lv %d", f.Level or 1), TextSize = 24, Scaled = true, AlignX = align,
		Size = UDim2.new(1, 0, 0, 28), Stroke = 3.5, Color = Config.RarityText(rar) })
	local sub = string.rep("★", f.Stars or 0) .. string.rep("☆", Config.Stars.Max - (f.Stars or 0)) .. "   ⚔️ " .. Util.FormatNumber(f.Stats and f.Stats.Power or 0)
	if not compact then sub = rar.Label .. "   " .. sub .. "   👤 " .. tostring(f.Player) end
	UIKit.Text(root, { Text = sub, TextSize = 15, Scaled = true, AlignX = align, Color = C.Gold, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 28), Stroke = 2.5 })
	local function bar(y, h, color, name)
		local track = new("Frame", { Name = name .. "Track", Size = UDim2.new(1, 0, 0, h), Position = UDim2.fromOffset(0, y), BackgroundColor3 = Color3.fromRGB(26, 22, 38) }, root)
		new("UICorner", { CornerRadius = UDim.new(0, h / 2) }, track); UIKit.Stroke(track, 2.5)
		local fill = new("Frame", { Name = name, Size = UDim2.fromScale(1, 1), AnchorPoint = right and Vector2.new(1, 0) or Vector2.zero,
			Position = right and UDim2.fromScale(1, 0) or UDim2.new(), BackgroundColor3 = color, BorderSizePixel = 0 }, track)
		new("UICorner", { CornerRadius = UDim.new(0, h / 2) }, fill)
		return fill, track
	end
	local trail, hpTrack = bar(50, 22, Color3.fromRGB(255, 240, 240), "HpTrail")
	local hp = new("Frame", { Name = "Hp", Size = UDim2.fromScale(1, 1), AnchorPoint = right and Vector2.new(1, 0) or Vector2.zero,
		Position = right and UDim2.fromScale(1, 0) or UDim2.new(), BackgroundColor3 = Color3.fromRGB(80, 230, 90), BorderSizePixel = 0, ZIndex = 2 }, hpTrack)
	new("UICorner", { CornerRadius = UDim.new(0, 11) }, hp)
	local shield = new("Frame", { Name = "Shield", Size = UDim2.fromScale(0, 0.4), AnchorPoint = right and Vector2.new(1, 0) or Vector2.zero,
		Position = right and UDim2.fromScale(1, 0) or UDim2.new(), BackgroundColor3 = Color3.fromRGB(120, 220, 255), BorderSizePixel = 0, ZIndex = 3 }, hpTrack)
	local hpText = UIKit.Text(hpTrack, { Text = "", TextSize = 14, Stroke = 2, ZIndex = 4 })
	local energy = bar(76, 10, Color3.fromRGB(255, 210, 50), "Energy")
	energy.Size = UDim2.fromScale(0, 1)
	panels[i] = { Root = root, Hp = hp, HpTrail = trail, Shield = shield, Energy = energy, HpText = hpText, Max = f.Stats and f.Stats.HP or 1 }
end

-- Atualiza as barras com o estado de um evento do roteiro.
local function setBars(e)
	for i = 1, 2 do
		local p = panels[i]
		if p then
			local frac = math.clamp((e.Hp[i] or 0) / p.Max, 0, 1)
			local color = frac > 0.5 and Color3.fromRGB(80, 230, 90) or (frac > 0.25 and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(255, 70, 60))
			tw(p.Hp, 0.15, { Size = UDim2.fromScale(frac, 1), BackgroundColor3 = color })
			task.delay(0.35, function() if p.HpTrail.Parent then tw(p.HpTrail, 0.5, { Size = UDim2.fromScale(frac, 1) }) end end) -- barra branca "atrasada"
			tw(p.Shield, 0.2, { Size = UDim2.fromScale(math.clamp((e.Shield and e.Shield[i] or 0) / p.Max, 0, 1), 0.4) })
			local en = math.clamp((e.Energy and e.Energy[i] or 0) / Config.Battle.Sim.EnergyMax, 0, 1)
			tw(p.Energy, 0.2, { Size = UDim2.fromScale(en, 1) })
			p.Energy.BackgroundColor3 = en >= 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 210, 50)
			p.HpText.Text = Util.FormatNumber(e.Hp[i] or 0) .. " / " .. Util.FormatNumber(p.Max)
		end
	end
end

-- Número de dano subindo em cima do alvo.
local function damageNumber(i, dmg, crit, color)
	local m = scene and scene.Models[i]
	if not (m and m.PrimaryPart) then return end
	local g = new("BillboardGui", { Size = UDim2.fromOffset(200, 60), StudsOffsetWorldSpace = Vector3.new(math.random(-2, 2), 10, 0), AlwaysOnTop = true, Adornee = m.PrimaryPart }, lp.PlayerGui)
	local l = UIKit.Text(g, { Text = (crit and "💥 " or "") .. Util.FormatNumber(dmg), TextSize = crit and 44 or 32, Color = color or (crit and C.Gold or C.White), Stroke = 4 })
	tw(g, 0.9, { StudsOffsetWorldSpace = g.StudsOffsetWorldSpace + Vector3.new(0, 5, 0) })
	task.delay(0.5, function() if l.Parent then tw(l, 0.4, { TextTransparency = 1 }) end end)
	Debris:AddItem(g, 1)
end

-- ============================================================ câmera e lutadores
local function shake(power, time)
	if not shakeOn() then return end
	local cam = workspace.CurrentCamera
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < (time or 0.25) do
			cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * power, (math.random() - 0.5) * power, 0)
			RunService.RenderStepped:Wait()
		end
	end)
end

local function camTo(cf, t)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	if t and t > 0 then return tw(cam, t, { CFrame = cf }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) end
	cam.CFrame = cf
end

local function sideView()
	-- alta e afastada o bastante para os pilares dos cantos ficarem fora do quadro (testado no Studio)
	return CFrame.lookAt(scene.Center + Vector3.new(0, 17, 52), scene.Center + Vector3.new(0, 4, 0))
end

local function facing(i)
	local me, other = scene.Pos[i], scene.Pos[3 - i]
	return CFrame.lookAt(me, Vector3.new(other.X, me.Y, other.Z))
end

-- Atacante avança até perto do alvo e volta.
local function lunge(i, distance)
	local m = scene.Models[i]
	if not m then return end
	local home = facing(i)
	local dir = (scene.Pos[3 - i] - scene.Pos[i]).Unit
	local v = Instance.new("CFrameValue"); v.Value = home
	local conn = v.Changed:Connect(function(cf) if m.Parent then m:PivotTo(cf) end end)
	tw(v, 0.12, { Value = home + dir * (distance or 18) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.2, function()
		local back = tw(v, 0.22, { Value = home }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		back.Completed:Connect(function() conn:Disconnect(); v:Destroy() end)
	end)
end

-- Alvo recua e pisca de branco.
local function flinch(i, sideStep)
	local m = scene.Models[i]
	if not m then return end
	local home = facing(i)
	local dir = (scene.Pos[i] - scene.Pos[3 - i]).Unit
	local offset = sideStep and (home.RightVector * (math.random() < 0.5 and -6 or 6)) or (dir * 2.5)
	local v = Instance.new("CFrameValue"); v.Value = home
	local conn = v.Changed:Connect(function(cf) if m.Parent then m:PivotTo(cf) end end)
	tw(v, 0.08, { Value = home + offset })
	task.delay(sideStep and 0.35 or 0.12, function()
		local back = tw(v, 0.2, { Value = home })
		back.Completed:Connect(function() conn:Disconnect(); v:Destroy() end)
	end)
	if not sideStep then
		local hl = Instance.new("Highlight"); hl.FillColor = Color3.new(1, 1, 1); hl.FillTransparency = 0.2; hl.OutlineTransparency = 1; hl.Parent = m
		Debris:AddItem(hl, 0.12)
	end
end

local function fighterColor(i)
	local f = scene.Script.Fighters[i]
	return Config.RarityFx(Config.Rarities[f.Rarity] or Config.Rarities.Common)
end
local function chest(i) return scene.Pos[i] + Vector3.new(0, 5, 0) end

-- ============================================================ um evento do roteiro
local function playEvent(e, tk)
	local i, foe = e.Actor, 3 - e.Actor
	if e.Kind == "hit" then
		lunge(i)
		task.delay(0.12, function()
			if token ~= tk then return end
			flinch(foe)
			blast(chest(foe), fighterColor(i), e.Crit and 9 or 5, 0.3)
			damageNumber(foe, e.Dmg or 0, e.Crit)
			setBars(e)
			if e.Crit then bigText(T("CRITICAL!"), C.Gold, 70, 0.5); shake(0.8, 0.2) end
		end)
	elseif e.Kind == "dodge" then
		lunge(i, 14)
		task.delay(0.08, function()
			if token ~= tk then return end
			flinch(foe, true)
			bigText(T("DODGE!"), Color3.fromRGB(120, 220, 255), 60, 0.45)
			setBars(e)
		end)
	elseif e.Kind == "ult" then
		local f = scene.Script.Fighters[i]
		local color = fighterColor(i)
		-- faixa com o nome da ULT + tela escura + câmera no lutador
		dim.Visible = true; dim.BackgroundTransparency = 1; tw(dim, 0.15, { BackgroundTransparency = 0.45 })
		ultBanner.BackgroundColor3 = color
		ultBanner.Name1.Text = T("ULTIMATE!")
		ultBanner.Name2.Text = (f.Stats and f.Stats.Ult or "Power Strike")
		ultBanner.Visible = true
		ultBanner.Position = UDim2.new(-0.6, 0, 0.3, 0)
		tw(ultBanner, 0.25, { Position = UDim2.new(0.5, 0, 0.3, 0) }, Enum.EasingStyle.Back)
		local close = CFrame.lookAt(scene.Pos[i] + (scene.Pos[foe] - scene.Pos[i]).Unit * -10 + Vector3.new(0, 7, 6), chest(i))
		camTo(close, 0.25)
		blast(chest(i), color, 8, 0.5)
		task.delay(0.55, function()
			if token ~= tk then return end
			camTo(sideView(), 0.2)
			tw(ultBanner, 0.2, { Position = UDim2.new(1.6, 0, 0.3, 0) })
			tw(dim, 0.25, { BackgroundTransparency = 1 })
			local fxName = (f.Stats and f.Stats.Fx) or "punch"
			lunge(i, 10)
			local ultFx = ULT_FX[fxName] or ULT_FX.punch
			ultFx(chest(i), chest(foe), color)
			shake(1.4, 0.35)
			flinch(foe)
			local hits = e.Hits or { e.Dmg or 0 }
			for h, dmg in ipairs(hits) do
				task.delay((h - 1) * 0.12, function() if token == tk then damageNumber(foe, dmg, #hits == 1, color) end end)
			end
			if e.UltKind == "Bulwark" and scene.Models[i] then -- bolha de escudo no Guardian
				local bubble = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(chest(i)), Color = Color3.fromRGB(120, 220, 255), Transparency = 0.6, Material = Enum.Material.ForceField }, 2.5)
				tw(bubble, 0.3, { Size = Vector3.one * 16 }, Enum.EasingStyle.Back)
			end
			setBars(e)
		end)
	elseif e.Kind == "ko" or e.Kind == "timeout" then
		local loser = scene.Models[3 - e.Actor]
		bigText(e.Kind == "ko" and T("K.O.!") or T("TIME'S UP!"), C.Red, 120, 1.6)
		shake(1.6, 0.4)
		setBars(e)
		if e.Kind == "ko" and loser then -- o perdedor voa para fora do ringue
			local dir = (scene.Pos[3 - e.Actor] - scene.Pos[e.Actor]).Unit
			local v = Instance.new("CFrameValue"); v.Value = loser:GetPivot()
			local conn = v.Changed:Connect(function(cf) if loser.Parent then loser:PivotTo(cf) end end)
			tw(v, 1.1, { Value = CFrame.new(loser:GetPivot().Position + dir * 60 + Vector3.new(0, 26, 0)) * CFrame.Angles(math.rad(540), 0, math.rad(200)) }, Enum.EasingStyle.Quad)
			task.delay(1.2, function() conn:Disconnect(); v:Destroy() end)
			blast(chest(3 - e.Actor), fighterColor(e.Actor), 16, 0.6)
		end
	end
end

-- ============================================================ limpeza
local function cleanup()
	token += 1
	if scene and scene.Folder then scene.Folder:Destroy() end
	scene = nil
	if sgui then sgui.Enabled = false end
	for _, p in pairs(panels) do if p.Root then p.Root:Destroy() end end
	panels = {}
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	local hud = UIKit.GetGui():FindFirstChild("HUD")
	if hud then hud.Visible = true end
end
BattleUI.Stop = cleanup

-- ============================================================ a cena inteira
local function play(s)
	cleanup()
	token += 1
	local tk = token
	local arena = s.Arena
	local origin = arena.Origin
	local floorY = origin.Y + VB.RingTop
	local folder = Instance.new("Folder"); folder.Name = "BattleScene"; folder.Parent = workspace.CurrentCamera
	scene = { Folder = folder, Models = {}, Pos = {}, Center = Vector3.new(origin.X, floorY, origin.Z), Script = s }
	for i = 1, 2 do
		local off = VB.FighterOffsets[i]
		scene.Pos[i] = Vector3.new(origin.X + off.X, floorY, origin.Z + off.Z)
	end
	-- interface
	local hud = UIKit.GetGui():FindFirstChild("HUD")
	if hud then hud.Visible = false end -- o topo da tela é das barras da luta
	sgui.Enabled = true
	big.Visible = false; ultBanner.Visible = false; dim.Visible = false
	for i, f in ipairs(s.Fighters) do buildPanel(i, f) end
	setBars({ Hp = { panels[1].Max, panels[2].Max }, Shield = { 0, 0 }, Energy = { 0, 0 } })

	-- espera o começo combinado (hora do servidor) com a câmera girando pela arena
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local orbitStart = os.clock()
	local orbit = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - orbitStart) * 0.6
		cam.CFrame = CFrame.lookAt(scene.Center + Vector3.new(math.sin(a) * 52, 20, math.cos(a) * 52), scene.Center + Vector3.new(0, 4, 0))
	end)
	if not waitUntil(s.StartAt, tk) then orbit:Disconnect(); return end

	-- entrada: os dois lutadores caem do céu
	for i, f in ipairs(s.Fighters) do
		local cfg = Config.AnimeById[f.Id]
		if cfg then
			local ok, m = pcall(AnimeFactory.Build, cfg, f.Mut, f.Size)
			if ok and m then
				pcall(function() m:ScaleTo(m:GetScale() * FIGHTER_SCALE) end)
				m.Name = "Fighter" .. i
				m:PivotTo(facing(i) + Vector3.new(0, 60, 0))
				m.Parent = folder
				scene.Models[i] = m
				local v = Instance.new("CFrameValue"); v.Value = m:GetPivot()
				local conn = v.Changed:Connect(function(cf) if m.Parent then m:PivotTo(cf) end end)
				local fall = tw(v, 0.7, { Value = facing(i) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				fall.Completed:Connect(function()
					conn:Disconnect(); v:Destroy()
					if token == tk then ring(scene.Pos[i] + Vector3.new(0, 0.3, 0), fighterColor(i), 20); burst(scene.Pos[i], Color3.fromRGB(200, 200, 210), 8, 0.8, 8); shake(0.6, 0.15) end
				end)
			end
		end
		task.wait(0.45)
		if token ~= tk then orbit:Disconnect(); return end
	end
	local fightAt = s.StartAt + (s.Intro or VB.IntroSeconds)
	if not waitUntil(fightAt - 0.6, tk) then orbit:Disconnect(); return end
	orbit:Disconnect()
	camTo(sideView(), 0.5)
	bigText(T("FIGHT!"), C.Gold, 130, 0.8)
	shake(1, 0.25)

	-- a luta: cada evento no seu tempo
	for _, e in ipairs(s.Events or {}) do
		if not waitUntil(fightAt + (e.T or 0), tk) then return end
		local ok, err = pcall(playEvent, e, tk)
		if not ok then warn("[BattleUI] " .. tostring(err)) end
	end

	-- final: vitória do vencedor
	if not waitUntil(fightAt + (s.Duration or 0) + 1.2, tk) then return end
	local w = s.Winner
	local wf = s.Fighters[w]
	local wcfg = wf and Config.AnimeById[wf.Id]
	bigText(T("%s wins the battle!", tostring(wf and wf.Player or "?")), C.Gold, 64, 2.2)
	camTo(CFrame.lookAt(scene.Pos[w] + (scene.Center - scene.Pos[w]).Unit * 16 + Vector3.new(0, 8, 14), chest(w)), 0.6)
	BattleUI.PlayVictory(s.WinnerFx, scene.Pos[w])
	if wcfg and scene.Models[w] then -- pulinho de comemoração
		local m = scene.Models[w]
		for _ = 1, 3 do
			if token ~= tk or not m.Parent then break end
			local home = facing(w)
			m:PivotTo(home + Vector3.new(0, 3, 0)); task.wait(0.18)
			if token ~= tk or not m.Parent then break end
			m:PivotTo(home); task.wait(0.28)
		end
	end
	if not waitUntil(fightAt + (s.Duration or 0) + (s.Outro or VB.OutroSeconds) + 0.5, tk) then return end
	cleanup()
end

function BattleUI.Init()
	sgui = new("ScreenGui", { Name = "BattleUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 6, Enabled = false }, lp:WaitForChild("PlayerGui"))
	Platform.SafeArea(sgui)
	dim = new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, sgui)
	topBar = new("Frame", { Name = "TopBar", Size = UDim2.fromOffset(900, 90), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 5 }, sgui)
	Platform.Apply(topBar, "Overlay")
	UIKit.Text(topBar, { Name = "VS", Text = "VS", TextSize = 44, Color = C.Gold, Size = UDim2.fromOffset(80, 50), Position = UDim2.new(0.5, 0, 0, 22), AnchorPoint = Vector2.new(0.5, 0), Stroke = 5, ZIndex = 6 })
	big = UIKit.Text(sgui, { Name = "Big", Text = "", TextSize = 100, Scaled = true, Size = UDim2.new(0.9, 0, 0, 100), Position = UDim2.fromScale(0.5, 0.24), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 7, ZIndex = 20 })
	big.Visible = false
	ultBanner = new("Frame", { Name = "UltBanner", Size = UDim2.new(1.2, 0, 0, 96), Position = UDim2.new(0.5, 0, 0.3, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Magenta, Rotation = -4, Visible = false, ZIndex = 15 }, sgui)
	UIKit.Stroke(ultBanner, 5)
	UIKit.Gradient(ultBanner, Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 120))
	UIKit.Text(ultBanner, { Name = "Name1", Text = "", TextSize = 24, Color = C.White, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 6), Stroke = 3, ZIndex = 16 })
	UIKit.Text(ultBanner, { Name = "Name2", Text = "", TextSize = 54, Scaled = true, Color = C.White, Size = UDim2.new(0.8, 0, 0, 56), Position = UDim2.new(0.1, 0, 0, 34), Stroke = 6, ZIndex = 16 })
	-- no celular os textos grandes ficam menores e mais acima (não cobrem os lutadores)
	local function layout()
		local compact = Platform.IsCompact()
		big.Position = UDim2.fromScale(0.5, compact and 0.2 or 0.24)
		ultBanner.Size = UDim2.new(1.2, 0, 0, compact and 70 or 96)
	end
	layout()
	Platform.OnChanged(layout)

	Net.On("BattleScript", function(s)
		if type(s) ~= "table" or type(s.Fighters) ~= "table" or #s.Fighters < 2 then return end
		task.spawn(function()
			local ok, err = pcall(play, s)
			if not ok then warn("[BattleUI] " .. tostring(err)); cleanup() end
		end)
	end)
	Net.On("BattleAbort", cleanup)
	-- saída de segurança: o desafio acabou (MatchId 0) e a cena ficou presa
	lp:GetAttributeChangedSignal("MatchId"):Connect(function()
		if (lp:GetAttribute("MatchId") or 0) == 0 and scene then cleanup() end
	end)
end

return BattleUI
