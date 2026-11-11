--[[
	EscapeFX (Beta 1.3): DESTRUIÇÃO SEQUENCIAL DA PISTA durante a fuga com o ovo (visual por jogador).
	  O servidor (Services.EscapeService) decide a regra e publica nos ATRIBUTOS do Player:
	     EscapeState="Escaping", EscapeFrontZ0, EscapeFrontStart (hora do servidor), EscapeSpeed, EscapeBiome
	  Aqui calculamos a MESMA frente:  frenteZ = FrontZ0 + Speed * (GetServerTimeNow() - FrontStart)
	  e, a cada Config.Escape.ChunkLength studs que ela avança em direção à base:
	     * a pista daquele trecho vira uma FENDA escura com rachaduras de lava (pedaço "Rift");
	     * blocos da pista (cor/material do bioma) explodem para cima e caem no vazio;
	     * rampas, pontes e lombadas (Map.Drivable) daquele trecho DESABAM (só na sua tela; voltam no fim).
	  + parede de destruição (campo de força vermelho com faíscas) na frente do colapso,
	  + aviso no topo ("COLLAPSE IN 3", distância até a base e até o colapso), tela avermelhada e tremor de câmera
	    quando ele chega perto, + o ovo flutuando em cima do seu carro.
	  Resultado (evento "EscapeResult"): EGG SECURED! (confete) | CAUGHT! (clarão vermelho) | aviso.
	POR QUE SÓ NO CLIENTE: a pista é compartilhada (pista fantasma). Destruir no servidor afetaria todos.
	Dependências: UIKit, Notify, DriveController, EggVisuals, Config.Escape / Config.World.RoadX.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Notify = require(script.Parent.Notify)
local Drive = require(script.Parent.DriveController)
local EggVisuals = require(script.Parent.EggVisuals)
local new, C = UIKit.New, UIKit.C

local lp = Players.LocalPlayer
local E, W = Config.Escape, Config.World
local EscapeFX = {}
local gui, banner, bannerTitle, bannerInfo, redTint
local session = nil
local MAX_RIFTS = 40       -- fendas visíveis ao mesmo tempo (as mais antigas somem)

-- ---------------------------------------------------------------- utilidades
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local function refreshFilter()
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map and map:FindFirstChild("Drivable") then table.insert(list, map.Drivable) end
	rayParams.FilterDescendantsInstances = list
end
local function groundY(x, z, fallback)
	local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -1000, 0), rayParams)
	return hit and hit.Position.Y or fallback or 0
end
-- rotação alinhada com a estrada (olhando para a base, +Z)
local function roadRot(z)
	local dir = Vector3.new(W.RoadX(z + 10) - W.RoadX(z), 0, 10)
	return CFrame.lookAt(Vector3.zero, dir)
end
local function frontZ(s, t) return s.Z0 + s.Speed * math.max(0, t - s.Start) end

local function mk(parent, name, size, cf, color, mat, transparency)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	pcall(function() p.Material = mat or Enum.Material.SmoothPlastic end)
	p.Transparency = transparency or 0
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function roadStyle(z)
	local b = Config.BiomeAtZ(z) or Config.Biomes[1]
	local mat = b.Terrain.Road or Enum.Material.Asphalt
	return mat, Config.TerrainColors[mat] or Color3.fromRGB(70, 70, 86), b.Style and b.Style.Accent or Color3.fromRGB(255, 90, 40)
end

-- ---------------------------------------------------------------- um pedaço da pista desaba
local function collapseChunk(s, z0, debrisCount)
	local zc = z0 + E.ChunkLength / 2
	local x = W.RoadX(zc)
	local y = groundY(x, zc, s.LastY)
	s.LastY = y
	local rot = roadRot(zc)
	local mat, col = roadStyle(zc)

	-- fenda escura no lugar da pista + rachaduras incandescentes
	local rift = mk(s.Folder, "Rift", Vector3.new(128, 1.4, E.ChunkLength + 2), CFrame.new(x, y + 0.5, zc) * rot, Color3.fromRGB(14, 6, 18), Enum.Material.Slate)
	for _ = 1, 2 do
		local crack = mk(rift, "Crack", Vector3.new(math.random(20, 60), 0.3, 1.2),
			CFrame.new(x + math.random(-26, 26), y + 1.25, zc + math.random(-10, 10)) * rot * CFrame.Angles(0, math.rad(math.random(-70, 70)), 0),
			Color3.fromRGB(255, 70, 30), Enum.Material.Neon)
		crack.Parent = rift
	end
	table.insert(s.Rifts, rift)
	if #s.Rifts > MAX_RIFTS then
		local old = table.remove(s.Rifts, 1)
		if old then old:Destroy() end
	end

	-- blocos da pista voando e caindo no vazio
	for _ = 1, debrisCount do
		local sz = Vector3.new(math.random(5, 12), math.random(3, 7), math.random(5, 12))
		local p = mk(s.Folder, "Debris", sz, CFrame.new(x + math.random(-28, 28), y + 1, zc + math.random(-14, 14))
			* CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3), col, mat)
		p.Anchored = false
		p.AssemblyLinearVelocity = Vector3.new(math.random(-25, 25), math.random(18, 48), math.random(-30, 6))
		p.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
		Debris:AddItem(p, 3.5)
	end
end

-- rampas/pontes/lombadas daquele trecho: somem (local) e uma cópia cai girando
local function dropDrivable(s, p)
	if not p.Parent then return end
	table.insert(s.Hidden, { Part = p, T = p.Transparency, C = p.CanCollide })
	local ok, clone = pcall(function() return p:Clone() end)
	p.Transparency = 1
	p.CanCollide = false
	if ok and clone then
		for _, d in ipairs(clone:GetDescendants()) do if not d:IsA("BasePart") then d:Destroy() end end
		clone.Anchored = false; clone.CanCollide = false; clone.CanQuery = false; clone.CanTouch = false
		clone.Parent = s.Folder
		clone.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
		clone.AssemblyAngularVelocity = Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
		Debris:AddItem(clone, 4)
	end
end

-- ---------------------------------------------------------------- sessão (início / fim)
local function buildWall(s)
	local wall = mk(s.Folder, "CollapseWall", Vector3.new(300, 170, 4), CFrame.new(0, -500, 0), Color3.fromRGB(255, 50, 30), Enum.Material.ForceField, 0)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 40, 20))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.8, 1.6)
	pe.Rate = 90
	pe.Speed = NumberRange.new(20, 45)
	pe.SpreadAngle = Vector2.new(35, 35)
	pe.EmissionDirection = Enum.NormalId.Front
	pe.Parent = wall
	local lip = mk(s.Folder, "CollapseLip", Vector3.new(300, 3, 6), CFrame.new(0, -500, 0), Color3.fromRGB(255, 110, 40), Enum.Material.Neon, 0)
	s.Wall, s.Lip = wall, lip
end

local function collectDrivable(s)
	local list = {}
	local map = workspace:FindFirstChild("Map")
	local dr = map and map:FindFirstChild("Drivable")
	if dr then
		for _, p in ipairs(dr:GetDescendants()) do
			if p:IsA("BasePart") and p.Position.Z >= s.Z0 and p.Position.Z <= E.BaseZ and math.abs(p.Position.X - W.RoadX(p.Position.Z)) < 160 then
				table.insert(list, p)
			end
		end
	end
	table.sort(list, function(a, b) return a.Position.Z < b.Position.Z end)
	s.Dr, s.DrIdx = list, 1
end

local function startSession()
	if session then return end
	refreshFilter()
	local biomeId = lp:GetAttribute("EscapeBiome")
	local s = {
		Biome = biomeId,
		Z0 = lp:GetAttribute("EscapeFrontZ0") or 0,
		Start = lp:GetAttribute("EscapeFrontStart") or workspace:GetServerTimeNow(),
		Speed = lp:GetAttribute("EscapeSpeed") or 50,
		Rifts = {}, Hidden = {}, LastY = 0,
	}
	s.NextZ = s.Z0
	s.Folder = Instance.new("Folder"); s.Folder.Name = "EscapeFX"; s.Folder.Parent = workspace
	buildWall(s)
	collectDrivable(s)
	local egg = EggVisuals.Build(biomeId, 0.75)
	egg.Parent = s.Folder
	s.Egg = egg
	session = s
	banner.Visible = true
	UIKit.Pop(banner, 1.2)
end

local function endSession()
	local s = session
	if not s then return end
	session = nil
	banner.Visible = false
	redTint.BackgroundTransparency = 1
	if s.Wall then s.Wall.Transparency = 1; local pe = s.Wall:FindFirstChildOfClass("ParticleEmitter"); if pe then pe.Enabled = false end end
	if s.Egg then s.Egg:Destroy() end
	-- deixa o resultado aparecer um pouco antes de limpar e devolver a pista ao normal
	task.delay(2.2, function()
		for _, h in ipairs(s.Hidden) do
			if h.Part.Parent then h.Part.Transparency = h.T; h.Part.CanCollide = h.C end
		end
		s.Folder:Destroy()
	end)
end

-- ---------------------------------------------------------------- resultado
local function bigMessage(title, sub, color)
	local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 75 }, gui)
	local t = UIKit.Text(holder, { Text = title, TextSize = 64, Color = color, Size = UDim2.new(1, 0, 0, 76), Position = UDim2.fromScale(0, 0.3), Stroke = 6, ZIndex = 76 })
	local s = UIKit.Text(holder, { Text = sub, TextSize = 28, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0.3, 82), Stroke = 3.5, ZIndex = 76 })
	UIKit.Pop(t, 1.6)
	task.delay(2.4, function()
		UIKit.Tween(t, 0.4, { TextTransparency = 1 }); UIKit.Tween(s, 0.4, { TextTransparency = 1 })
		local a, b = t:FindFirstChildOfClass("UIStroke"), s:FindFirstChildOfClass("UIStroke")
		if a then UIKit.Tween(a, 0.4, { Transparency = 1 }) end
		if b then UIKit.Tween(b, 0.4, { Transparency = 1 }) end
		Debris:AddItem(holder, 0.5)
	end)
	return holder
end

local function onResult(info)
	local cfg = info and Config.AnimeById[info.Id]
	local name = cfg and cfg.Name or "your character"
	if info.Success then
		local left = (info.ReadyAt or 0) - (info.Now or info.ReadyAt or 0)
		bigMessage("🥚 EGG SECURED! 🥚", ("%s hatches in %s at your base"):format(name, Config.FormatDuration(left)), C.Cash)
		UIKit.Confetti(gui, C.Gold, 60)
		UIKit.PlaySound("Reveal")
	elseif info.Reason == "caught" then
		local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 40, 30), BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 74 }, gui)
		UIKit.Tween(flash, 0.9, { BackgroundTransparency = 1 })
		Debris:AddItem(flash, 1)
		local holder = bigMessage("💥 CAUGHT BY THE COLLAPSE! 💥", name .. " fell into the void...", Color3.fromRGB(255, 80, 60))
		UIKit.Shake(holder, 12, 0.7)
	elseif info.Reason == "invalid" then
		Notify.Toast("⚠️ Escape cancelled.", "error")
	else
		Notify.Toast("🥚 You left the race — the egg was lost!", "error")
	end
end

-- ---------------------------------------------------------------- loop
local function step()
	local s = session
	if not s then return end
	local t = workspace:GetServerTimeNow()
	local fz = frontZ(s, t)
	local pos = Drive.GetPosition()
	local collapsing = t >= s.Start
	local rouletteOver = t >= s.Start - E.HeadStart

	-- trechos da pista desabando (no máximo 4 por quadro; se atrasar muito por lag, pula para perto da frente)
	if collapsing then
		if fz - s.NextZ > E.ChunkLength * 14 then s.NextZ = fz - E.ChunkLength * 3 end
		local budget = 4
		local debrisCount = s.Speed > 200 and 3 or 6
		while s.NextZ + E.ChunkLength <= fz and budget > 0 do
			collapseChunk(s, s.NextZ, debrisCount)
			s.NextZ += E.ChunkLength
			budget -= 1
		end
		while s.DrIdx <= #s.Dr and s.Dr[s.DrIdx].Position.Z <= fz do
			dropDrivable(s, s.Dr[s.DrIdx])
			s.DrIdx += 1
		end
	end

	-- parede de destruição
	if rouletteOver then
		local x = W.RoadX(fz)
		local y = groundY(x, fz, s.LastY)
		local rot = roadRot(fz)
		s.Wall.CFrame = CFrame.new(x, y + 80, fz) * rot
		s.Lip.CFrame = CFrame.new(x, y + 1, fz + 2) * rot
		s.Wall.Transparency = 0.15 + math.sin(os.clock() * 8) * 0.08
	end

	-- ovo em cima do carro
	if pos and s.Egg then
		local c = os.clock()
		s.Egg:PivotTo(CFrame.new(pos + Vector3.new(0, 7.5 + math.sin(c * 4) * 0.6, 0)) * CFrame.Angles(0, c * 2.5, 0))
	end

	-- aviso + perigo
	local danger = 0
	if pos then
		local gap = pos.Z - fz
		if collapsing then danger = math.clamp(1 - gap / E.ShakeDistance, 0, 1) end
		bannerInfo.Text = ("🏠 %s m to base     🔥 %s m behind you"):format(
			Util.FormatNumber(math.max(0, math.floor(E.BaseZ - pos.Z))), Util.FormatNumber(math.max(0, math.floor(gap))))
		bannerInfo.TextColor3 = (collapsing and gap < 80) and Color3.fromRGB(255, 90, 70) or C.White
	end
	if not collapsing then
		bannerTitle.Text = ("⚠️ COLLAPSE IN %d ⚠️"):format(math.max(1, math.ceil(s.Start - t)))
	else
		bannerTitle.Text = "🚨 THE TRACK IS COLLAPSING! 🚨"
	end
	bannerTitle.TextTransparency = collapsing and (0.12 + math.sin(os.clock() * 9) * 0.12) or 0
	redTint.BackgroundTransparency = 1 - 0.28 * danger
	s.Danger = danger
end

-- tremor de câmera (depois da câmera padrão atualizar)
local function shake()
	local s = session
	if not s or not s.Danger or s.Danger <= 0 then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local a = 0.014 * s.Danger
	cam.CFrame = cam.CFrame * CFrame.Angles((math.random() - 0.5) * a, (math.random() - 0.5) * a, (math.random() - 0.5) * a * 0.5)
end

function EscapeFX.Init()
	gui = UIKit.GetGui()
	redTint = new("Frame", { Name = "DangerTint", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 20, 10),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Active = false }, gui)
	banner = new("Frame", { Name = "EscapeBanner", Size = UDim2.fromOffset(560, 74), Position = UDim2.new(0.5, 0, 0, 96), AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(40, 6, 8), BackgroundTransparency = 0.1, Visible = false, ZIndex = 40 }, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 16) }, banner)
	UIKit.Stroke(banner, 3.5, Color3.fromRGB(255, 70, 40))
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 74) }, banner)
	banner.Size = UDim2.new(0.94, 0, 0, 74)
	bannerTitle = UIKit.Text(banner, { Text = "", TextSize = 30, Scaled = true, Color = Color3.fromRGB(255, 90, 60), Size = UDim2.new(1, -16, 0, 38), Position = UDim2.fromOffset(8, 4), Stroke = 3.5, ZIndex = 41 })
	bannerInfo = UIKit.Text(banner, { Text = "", TextSize = 22, Scaled = true, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 42), Stroke = 2.5, ZIndex = 41 })

	local function onState()
		if lp:GetAttribute("EscapeState") == "Escaping" then startSession() else endSession() end
	end
	lp:GetAttributeChangedSignal("EscapeState"):Connect(onState)
	lp:GetAttributeChangedSignal("EscapeFrontZ0"):Connect(function()
		local z0 = lp:GetAttribute("EscapeFrontZ0")
		if session and z0 then
			if session.NextZ == session.Z0 then session.NextZ = z0 end
			session.Z0 = z0
		end
	end)
	onState()
	Net.On("EscapeResult", onResult)

	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(step)
		if not ok then warn("[EscapeFX] " .. tostring(err)) end
	end)
	RunService:BindToRenderStep("EscapeShake", Enum.RenderPriority.Camera.Value + 1, shake)
end

return EscapeFX
