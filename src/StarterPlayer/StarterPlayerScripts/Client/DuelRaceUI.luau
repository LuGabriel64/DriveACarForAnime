--[[
	DuelRaceUI  (StarterPlayerScripts.Client.DuelRaceUI)                                         Beta 1.9
	=====================================================================================================
	CORRIDA 1v1: o PLACAR ao vivo e o visual do COLAPSO que persegue os dois desde a largada.
	Só aparece com RaceMode == "Duel" (atributo do Player definido pelo RaceService).

	PLACAR (topo da tela)
	  * Quem está em 1º e quantos metros cada um andou desde a largada. O número só aumenta: é o atributo
	    RaceDistance de cada jogador (calculado no SERVIDOR e replicado; nenhum tráfego de rede extra).
	  * Diferença para o adversário ("+310 m ahead" / "-120 m behind") e distância do colapso ("🔥 Collapse: 840 m"),
	    que fica vermelha e pisca abaixo de 200 m. Atualiza 4x por segundo.
	  * CELULAR (Platform.IsCompact): uma linha só, "🥇 12.480 m · +310 m · 🔥 840 m", para a pista aparecer.

	COLAPSO (visual, só para este jogador — quem decide é o servidor: Services.DuelRaceService)
	  frenteZ(t) = CollapseZ0 - CollapseSpeed x max(0, t - CollapseStart), t = workspace:GetServerTimeNow()
	  (mesma conta do servidor, com os atributos CollapseZ0 / CollapseStart / CollapseSpeed).
	  Desenha: uma PAREDE de destruição atravessando a pista + pedaços da pista caindo conforme a frente avança +
	  tremor de câmera e tela avermelhada quando está perto (o tremor respeita o interruptor "Speed Camera Effect").
	  É uma versão SIMPLES do efeito da fuga do ovo: o Client.EscapeFX NÃO foi alterado (ele é delicado e preso à
	  direção "de volta para a base"). Unificar os dois num CollapseFX fica como melhoria futura.

	Dependências: UIKit (Platform, T), Shared.Config. NÃO TESTADO com 2 jogadores reais.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(RS.Shared.Util)
local UIKit = require(script.Parent.UIKit)
local new, C, T = UIKit.New, UIKit.C, UIKit.T
local Platform = UIKit.Platform
local lp = Players.LocalPlayer

local DuelRaceUI = {}
local W, E = Config.World, Config.Escape
local board, line1, line2, line3, tint, banner
local fxFolder, wall, lastChunk
local bannerShown = false

local function active()
	return lp:GetAttribute("RaceMode") == "Duel" and (lp:GetAttribute("RaceState") or "Lobby") ~= "Lobby"
end
local function opponent()
	local my = lp:GetAttribute("MatchId") or 0
	if my == 0 then return nil end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= lp and (p:GetAttribute("MatchId") or 0) == my then return p end
	end
	return nil
end
local function myCarZ()
	local cars = workspace:FindFirstChild("Cars")
	local car = cars and cars:FindFirstChild("Car_" .. lp.Name)
	return car and car.PrimaryPart and car.PrimaryPart.Position.Z
end
-- Onde está a frente do colapso agora (nil = ainda não há colapso).
local function frontZ()
	local z0, start, speed = lp:GetAttribute("CollapseZ0"), lp:GetAttribute("CollapseStart"), lp:GetAttribute("CollapseSpeed")
	if not (z0 and start and speed) then return nil end
	local t = workspace:GetServerTimeNow()
	return z0 - speed * math.max(0, t - start), t >= start
end

-- ---------------------------------------------------------------- placar
local function m(n) return T("%s m", Util.FormatNumber(math.floor(n))) end

local function updateBoard()
	local foe = opponent()
	local mine = lp:GetAttribute("RaceDistance") or 0
	local theirs = foe and (foe:GetAttribute("RaceDistance") or 0) or 0
	local leading = mine >= theirs
	local diff = math.abs(mine - theirs)
	local gapText = leading and T("+%s m ahead", Util.FormatNumber(diff)) or T("-%s m behind", Util.FormatNumber(diff))
	local fz, moving = frontZ()
	local carZ = myCarZ()
	local gap = (fz and carZ) and math.max(0, fz - carZ) or nil
	local danger = gap ~= nil and moving and gap < 200
	local collapseText = gap and T("🔥 Collapse: %s m", Util.FormatNumber(math.floor(gap))) or ""
	local blink = danger and (os.clock() % 0.5 < 0.25)
	local dangerColor = danger and (blink and Color3.fromRGB(255, 70, 60) or Color3.fromRGB(255, 200, 190)) or Color3.fromRGB(255, 180, 90)

	if Platform.IsCompact() then
		-- uma linha só: posição, minha distância, diferença e colapso
		line1.Text = (leading and "🥇 " or "🥈 ") .. m(mine) .. "  ·  " .. (leading and "+" or "-") .. m(diff) .. (gap and ("  ·  🔥 " .. m(gap)) or "")
		line1.TextColor3 = danger and dangerColor or C.White
		line2.Visible, line3.Visible = false, false
		board.Size = UDim2.fromOffset(430, 40)
	else
		local meRow = lp.DisplayName .. "   " .. m(mine)
		local foeRow = (foe and foe.DisplayName or "...") .. "   " .. m(theirs)
		line1.Text = "🥇 " .. T("1st") .. "  " .. (leading and meRow or foeRow)
		line2.Text = "🥈 " .. T("2nd") .. "  " .. (leading and foeRow or meRow)
		line1.TextColor3 = leading and C.Gold or C.White
		line2.TextColor3 = leading and C.White or C.Gold -- a MINHA linha fica dourada
		line3.Text = gapText .. (gap and ("     " .. collapseText) or "")
		line3.TextColor3 = dangerColor
		line2.Visible, line3.Visible = true, true
		board.Size = UDim2.fromOffset(430, 104)
	end
	-- troca de posição: um "pop" no placar
	if board:GetAttribute("Leading") ~= leading then
		board:SetAttribute("Leading", leading)
		UIKit.Pop(board, 1.1)
	end
	tint.BackgroundTransparency = danger and (0.86 - (1 - gap / 200) * 0.2) or 1
end

-- ---------------------------------------------------------------- visual do colapso
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local function groundY(x, z)
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map and map:FindFirstChild("Drivable") then table.insert(list, map.Drivable) end
	rayParams.FilterDescendantsInstances = list
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), rayParams)
	return hit and hit.Position.Y or 0
end

local function clearFx()
	if fxFolder then fxFolder:Destroy() end
	fxFolder, wall, lastChunk = nil, nil, nil
	bannerShown = false
	if tint then tint.BackgroundTransparency = 1 end
	if banner then banner.Visible = false end
end

local function ensureFx()
	if fxFolder then return end
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "DuelCollapseFX"
	fxFolder.Parent = workspace.CurrentCamera -- local: só este jogador vê
	wall = Instance.new("Part")
	wall.Name = "CollapseWall"; wall.Anchored = true; wall.CanCollide = false; wall.CanQuery = false; wall.CanTouch = false
	wall.Size = Vector3.new(420, 260, 26); wall.Material = Enum.Material.Neon; wall.Color = Color3.fromRGB(255, 70, 30); wall.Transparency = 0.35
	wall.Parent = fxFolder
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 60; smoke.Lifetime = NumberRange.new(1.2, 2.2); smoke.Speed = NumberRange.new(30, 70)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 18), NumberSequenceKeypoint.new(1, 46) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(40, 20, 20), Color3.fromRGB(255, 110, 40))
	smoke.EmissionDirection = Enum.NormalId.Front -- frente da parede = -Z = direção da corrida
	smoke.SpreadAngle = Vector2.new(35, 35)
	smoke.Parent = wall
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 90, 40); light.Range = 60; light.Brightness = 3; light.Parent = wall
end

-- Pedaços da pista caindo no ponto por onde a frente acabou de passar.
local function dropChunk(z)
	local cx = W.RoadX(z)
	local y = groundY(cx, z)
	for i = 1, 6 do
		local p = Instance.new("Part")
		p.Size = Vector3.new(math.random(8, 16), math.random(2, 4), math.random(8, 16))
		p.CFrame = CFrame.new(cx + (i - 3.5) * 10 + math.random(-3, 3), y + 1, z + math.random(-10, 10)) * CFrame.Angles(0, math.random() * 6, 0)
		p.Color = Color3.fromRGB(58, 54, 70); p.Material = Enum.Material.Slate
		p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(14, 30), math.random(4, 20))
		p.AssemblyAngularVelocity = Vector3.new(math.random(-4, 4), math.random(-4, 4), math.random(-4, 4))
		p.Parent = fxFolder
		Debris:AddItem(p, 2.6)
	end
end

local function stepFx()
	local fz, moving = frontZ()
	if not fz then clearFx(); return end
	ensureFx()
	local cx = W.RoadX(fz)
	local carZ = myCarZ()
	-- a parede fica um pouco ATRÁS da frente (a regra do servidor é a frente; o visual não pode enganar para menos)
	wall.CFrame = CFrame.new(cx, groundY(cx, fz) + 110, fz + 16)
	if moving then
		if not bannerShown then
			bannerShown = true
			banner.Visible = true
			UIKit.Pop(banner, 1.25)
			task.delay(2.4, function() if banner then banner.Visible = false end end)
		end
		local step = E.ChunkLength or 36
		local idx = math.floor(fz / step)
		-- só gasta peças se a frente estiver razoavelmente perto do jogador
		if idx ~= lastChunk then
			lastChunk = idx
			if carZ and math.abs(fz - carZ) < 900 then dropChunk(fz) end
		end
		-- tremor de câmera perto do colapso (respeita o interruptor do menu Configs)
		local gap = carZ and (fz - carZ) or math.huge
		if gap < (E.ShakeDistance or 160) and lp:GetAttribute("Set_FOV") ~= false then
			local k = (1 - math.clamp(gap / (E.ShakeDistance or 160), 0, 1)) * 0.5
			local cam = workspace.CurrentCamera
			cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
		end
	end
end

function DuelRaceUI.Init()
	local gui = UIKit.GetGui()
	tint = new("Frame", { Name = "DuelDangerTint", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 40, 20), BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 2, Active = false }, gui)
	board = new("Frame", { Name = "DuelBoard", Size = UDim2.fromOffset(430, 104), Position = UDim2.new(0.5, 0, 0, 48), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(14, 14, 22), BackgroundTransparency = 0.15, Visible = false, ZIndex = 10 }, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, board); UIKit.Stroke(board, 3.5, C.Gold)
	Platform.Apply(board, "Overlay")
	new("UIListLayout", { Padding = UDim.new(0, 0), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, board)
	local function row(order, size, h)
		return UIKit.Text(board, { Name = "Line" .. order, Text = "", TextSize = size, Scaled = true, Size = UDim2.new(1, -20, 0, h), LayoutOrder = order, Stroke = 3, ZIndex = 11 })
	end
	line1, line2, line3 = row(1, 22, 34), row(2, 20, 30), row(3, 17, 28)
	banner = UIKit.Text(gui, { Name = "DuelCollapseBanner", Text = "🚨 THE TRACK IS COLLAPSING! 🚨", TextSize = 40, Color = Color3.fromRGB(255, 90, 60), Scaled = true,
		Size = UDim2.new(0.8, 0, 0, 54), Position = UDim2.fromScale(0.5, 0.26), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 5, ZIndex = 44 })
	banner.Visible = false

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local on = active()
		if board.Visible ~= on then
			board.Visible = on
			if on then UIKit.Pop(board, 1.1) else clearFx() end
		end
		if not on then return end
		stepFx()
		acc += dt
		if acc >= 0.25 then acc = 0; updateBoard() end
	end)
end

return DuelRaceUI
