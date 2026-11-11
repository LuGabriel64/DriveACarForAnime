--[[
	LobbyBuilder v1  (FERRAMENTA DE EDIÇÃO — roda no Studio, NÃO durante o jogo)
	=========================================================================
	Autor: Claude | Criado: 2026-11-04 | Não altera o WorldBuilder (outro assistente pode estar editando-o).

	USO (na Command Bar do Studio):
	  local LB = require(game.ServerStorage.Tools.LobbyBuilder)
	  LB.Build()          -- tudo: lobby + garagens + portais de bioma
	  LB.BuildLobby()     -- só o lobby (8 garagens estilo showroom + praça de madeira)
	  LB.BuildGates()     -- só os 7 portais (um por bioma, cada um com tema próprio)
	É IDEMPOTENTE: pode rodar de novo, ele limpa o que ele mesmo criou.

	ATENÇÃO: WorldBuilder.BuildMap() destrói workspace.Map inteiro (inclusive isto).
	         Se rodar BuildMap, rode LB.Build() depois.

	ONDE FICA O QUÊ
	  Map.Plots.Plot_1..8        garagens (contrato do FarmService, ver abaixo)
	  Map.Drivable.Lobby         pisos dirigíveis: azulejo das garagens + decks de madeira
	                             (DriveController só enxerga Terrain + Map.Drivable como chão!)
	  Map.Structures.Lobby       decoração: pavilhões, bancos, cercas-vivas, postes, pinheiros, placas
	  Map.Structures.Gates       Gate_<n>_<biomaId>: portal/barreira de cada bioma

	CONTRATO DA GARAGEM (FarmService/CarService dependem disto — NÃO renomear):
	  Plot_N com atributos PlotIndex (1..8) e OwnerUserId (0 = livre)
	    .Slots   Folder com SOMENTE as Parts Slot_1..Slot_8 (FarmService conta #Slots:GetChildren())
	    .Placed  Folder (modelos dos animes)
	    .CarSpawn (invisível; orientação = direção em que o carro nasce) e .CarPad (plataforma visual)
	    TextLabel chamado "Label" (título do dono + renda/s)

	Medidas vêm de Config.Garage / Config.World / Config.Biomes — mude lá, não aqui.
]]
local Config = require(game.ReplicatedStorage.Shared.Config)
local W, G, Biomes, Cars = Config.World, Config.Garage, Config.Biomes, Config.Cars
local V3, ANG = Vector3.new, CFrame.Angles
local rad = math.rad
local LobbyBuilder = {}

local C = {
	deck = Color3.fromRGB(120, 84, 56), deckDark = Color3.fromRGB(78, 54, 40), wallWood = Color3.fromRGB(70, 46, 34),
	woodLight = Color3.fromRGB(150, 108, 70), concrete = Color3.fromRGB(150, 152, 160), dark = Color3.fromRGB(26, 26, 30),
	tileDark = Color3.fromRGB(34, 34, 40), tileLight = Color3.fromRGB(176, 178, 186), gold = Color3.fromRGB(214, 176, 98),
	warm = Color3.fromRGB(255, 200, 130), white = Color3.fromRGB(255, 246, 228), roof = Color3.fromRGB(168, 44, 44),
	hedge = Color3.fromRGB(58, 120, 62), pineA = Color3.fromRGB(44, 104, 58), pineB = Color3.fromRGB(58, 128, 70),
	trunk = Color3.fromRGB(96, 66, 42), stone = Color3.fromRGB(96, 98, 108), tire = Color3.fromRGB(24, 24, 28),
	toolRed = Color3.fromRGB(190, 40, 40),
}

-- ===================================================================== AUXILIARES
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }
local function groundY(x, z)
	local hit = workspace:Raycast(V3(x, 400, z), V3(0, -800, 0), groundParams)
	return hit and hit.Position.Y or 0
end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end

local function light(p, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range, brightness
	l.Parent = p
	return l
end

local function emitter(p, color, rate, speed, size, life, accel)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color); e.Rate = rate
	e.Speed = NumberRange.new(speed * 0.6, speed); e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Size = NumberSequence.new(size)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = 0.5; e.SpreadAngle = Vector2.new(180, 180); e.Acceleration = accel or V3(0, 0, 0)
	e.Parent = p
	return e
end

-- Placa com texto empilhado. lines = { {text=, h=(fração da altura), color=, stroke=} ... }
local function sign(p, face, lines)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 30
	sg.LightInfluence = 0; sg.Parent = p
	local y = 0
	for _, ln in ipairs(lines) do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, ln.h); l.Position = UDim2.fromScale(0, y)
		l.Font = Enum.Font.FredokaOne; l.TextScaled = true; l.Text = ln.text; l.TextColor3 = ln.color
		local s = Instance.new("UIStroke"); s.Thickness = ln.stroke or 3; s.Color = Color3.new(0, 0, 0); s.Parent = l
		l.Parent = sg
		y += ln.h
	end
end

local function folderIn(parent, name, clear)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end
	if clear then f:ClearAllChildren() end
	return f
end

local function mapRoot()
	local map = workspace:FindFirstChild("Map")
	if not map then map = Instance.new("Folder"); map.Name = "Map"; map.Parent = workspace end
	for _, n in ipairs({ "Drivable", "Props", "Plots", "Structures", "AnimeSpawns", "BoostPads" }) do folderIn(map, n, false) end
	return map
end

local function carForTier(t)
	for _, c in ipairs(Cars) do if c.Tier == t then return c end end
end

-- ===================================================================== GARAGEM (showroom — referência: imagem do usuário)
-- Espaço local: -Z = FRENTE (portão voltado para a pista). Garagens 1-4 à esquerda da pista, 5-8 à direita.
local function buildGarage(i, plots, drivable)
	local left = i <= 4
	local row = (i - 1) % 4
	local cx = left and -G.CenterX or G.CenterX
	local cz = G.FirstZ + row * G.Spacing
	local center = V3(cx, groundY(cx, cz), cz)
	local origin = CFrame.lookAt(center, center + V3(left and 1 or -1, 0, 0))
	local Wd, D, H, DW, DH = G.Width, G.Depth, G.Height, G.DoorWidth, G.DoorHeight
	local model = Instance.new("Model"); model.Name = "Plot_" .. i
	model:SetAttribute("PlotIndex", i); model:SetAttribute("OwnerUserId", 0)
	local function P(name, size, lcf, color, o, parent)
		local props = { Name = name, Size = size, CFrame = origin * lcf, Color = color }
		if o then for k, v in pairs(o) do props[k] = v end end
		return part(parent or model, props)
	end
	local WOOD, NEON, METAL = Enum.Material.WoodPlanks, Enum.Material.Neon, Enum.Material.Metal

	-- Piso xadrez (dirigível: fica em Map.Drivable). Topo do piso = +0.2 acima do terreno.
	local floorFolder = Instance.new("Folder"); floorFolder.Name = "Garage_" .. i; floorFolder.Parent = drivable
	local cols, rows = 6, 7
	local tw, td = Wd / cols, D / rows
	for ci = 1, cols do
		for ri = 1, rows do
			local dark = (ci + ri) % 2 == 0
			P("Tile", V3(tw, 1, td), CFrame.new(-Wd / 2 + (ci - 0.5) * tw, -0.3, -D / 2 + (ri - 0.5) * td),
				dark and C.tileDark or C.tileLight, { Material = Enum.Material.Marble, Reflectance = 0.08 }, floorFolder)
		end
	end

	-- Paredes de ripado de madeira escura + pilares de concreto + frisos de luz quente
	P("WallL", V3(1.2, H, D), CFrame.new(-Wd / 2 + 0.6, H / 2, 0), C.wallWood, { Material = WOOD })
	P("WallR", V3(1.2, H, D), CFrame.new(Wd / 2 - 0.6, H / 2, 0), C.wallWood, { Material = WOOD })
	P("WallBack", V3(Wd, H, 1.2), CFrame.new(0, H / 2, D / 2 - 0.6), C.wallWood, { Material = WOOD })
	local segW = (Wd - DW) / 2
	P("WallFrontL", V3(segW, H, 1.2), CFrame.new(-(DW / 2 + segW / 2), H / 2, -D / 2 + 0.6), C.wallWood, { Material = WOOD })
	P("WallFrontR", V3(segW, H, 1.2), CFrame.new(DW / 2 + segW / 2, H / 2, -D / 2 + 0.6), C.wallWood, { Material = WOOD })
	P("Lintel", V3(DW, H - DH, 1.2), CFrame.new(0, DH + (H - DH) / 2, -D / 2 + 0.6), C.wallWood, { Material = WOOD })
	local sideZ = { -26, -13, 0, 13, 26 }
	for _, sx in ipairs({ -1, 1 }) do
		for k, zp in ipairs(sideZ) do
			P("Pillar", V3(2.6, H, 2.6), CFrame.new(sx * (Wd / 2 - 2.1), H / 2, zp), C.concrete, { Material = Enum.Material.Concrete })
			if k < #sideZ then
				local zm = (zp + sideZ[k + 1]) / 2
				P("WoodGlow", V3(0.15, 11, 0.5), CFrame.new(sx * (Wd / 2 - 1.3), 7.5, zm), C.warm, { Material = NEON, CanCollide = false })
			end
		end
	end
	for _, xp in ipairs({ -22, -12, 12, 22 }) do
		P("PillarBack", V3(2.6, H, 2.6), CFrame.new(xp, H / 2, D / 2 - 1.9), C.concrete, { Material = Enum.Material.Concrete })
	end
	for _, sx in ipairs({ -1, 1 }) do
		P("PillarDoor", V3(2.6, H, 2.6), CFrame.new(sx * (DW / 2 + 1.3), H / 2, -D / 2 + 1.9), C.concrete, { Material = Enum.Material.Concrete })
	end
	-- Portão seccional decorativo (parede do fundo, como na referência)
	P("BackDoor", V3(20, 12, 0.5), CFrame.new(0, 6.2, D / 2 - 1.0), Color3.fromRGB(214, 196, 160))
	for _, y in ipairs({ 3.2, 6.2, 9.2 }) do P("BackDoorLine", V3(20, 0.25, 0.2), CFrame.new(0, y, D / 2 - 1.3), Color3.fromRGB(160, 140, 110), { CanCollide = false }) end
	P("BackDoorTop", V3(22, 0.8, 0.7), CFrame.new(0, 12.6, D / 2 - 1.0), C.wallWood, { Material = WOOD })
	for _, sx in ipairs({ -1, 1 }) do P("BackDoorSide", V3(0.8, 12.6, 0.7), CFrame.new(sx * 10.8, 6.3, D / 2 - 1.0), C.wallWood, { Material = WOOD }) end

	-- Teto escuro, vigas de madeira com LED, anel octogonal com painel luminoso (assinatura da referência)
	P("Roof", V3(Wd + 2, 1, D + 2), CFrame.new(0, H + 0.5, 0), Color3.fromRGB(24, 24, 28), { Material = Enum.Material.Metal })
	P("RoofTrim", V3(Wd + 2, 0.5, 0.5), CFrame.new(0, H + 1.2, -D / 2 - 1), C.warm, { Material = NEON, CanCollide = false })
	local function beam(zp, xc, len)
		P("Beam", V3(len, 1.6, 2.2), CFrame.new(xc, H - 1.2, zp), C.woodLight, { Material = WOOD })
		P("LedStrip", V3(len - 1, 0.25, 0.6), CFrame.new(xc, H - 2.1, zp), C.white, { Material = NEON, CanCollide = false })
	end
	for _, zp in ipairs({ -26, -17, 26 }) do beam(zp, 0, Wd - 1.2) end           -- vigas inteiras (fora do anel)
	for _, zp in ipairs({ -4, 6, 16 }) do                                           -- vigas curtas (param no anel)
		beam(zp, -19.3, 9.6); beam(zp, 19.3, 9.6)
	end
	local ringC = V3(0, H - 2, 6)
	for k = 0, 7 do
		local a = rad(k * 45)
		local pos = V3(math.cos(a) * 13, H - 2, 6 + math.sin(a) * 13)
		P("RingSeg", V3(10.6, 4, 2.2), CFrame.lookAt(pos, ringC), Color3.fromRGB(140, 146, 152), { Material = METAL })
	end
	local disc = P("RingLight", V3(0.4, 23.4, 23.4), CFrame.new(0, H - 0.1, 6) * ANG(0, 0, rad(90)), C.white,
		{ Shape = Enum.PartType.Cylinder, Material = NEON, CanCollide = false })
	light(disc, C.white, 46, 2.6)
	for _, a in ipairs({ 0, 45, 90, 135 }) do
		P("RingLine", V3(23.4, 0.08, 0.3), CFrame.new(0, H - 0.35, 6) * ANG(0, rad(a), 0), Color3.fromRGB(120, 84, 60), { CanCollide = false })
	end

	-- Plataforma giratória dourada/branca (o carro nasce aqui, virado para o portão)
	P("PadRing", V3(0.1, 19.6, 19.6), CFrame.new(0, 0.25, 6) * ANG(0, 0, rad(90)), C.gold,
		{ Shape = Enum.PartType.Cylinder, Material = METAL, CanCollide = false, CanQuery = false })
	P("CarPad", V3(0.1, 18, 18), CFrame.new(0, 0.3, 6) * ANG(0, 0, rad(90)), Color3.fromRGB(225, 226, 230),
		{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Marble, Reflectance = 0.2, CanCollide = false, CanQuery = false })
	P("CarSpawn", V3(2, 2, 2), CFrame.new(0, 0.5, 6), C.white, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })

	-- 8 pedestais dos personagens (4 de cada lado), virados para o corredor central
	local slots = Instance.new("Folder"); slots.Name = "Slots"; slots.Parent = model
	local n = 0
	for _, side in ipairs({ -1, 1 }) do
		for _, zl in ipairs(G.PodiumZ) do
			n += 1
			local lp = V3(side * G.PodiumX, 0.6, zl)
			P("Slot_" .. n, V3(8, 0.8, 8), CFrame.lookAt(lp, lp + V3(-side, 0, 0)), Color3.fromRGB(40, 30, 26), { Material = Enum.Material.Wood }, slots)
			P("SlotTrim", V3(8.8, 0.2, 8.8), CFrame.new(lp.X, 0.35, lp.Z), C.gold, { Material = NEON, CanCollide = false })
		end
	end
	Instance.new("Folder", model).Name = "Placed"

	-- Oficina: estante de pneus (esq.), caixa de ferramentas vermelha, balcão com banquetas (dir.), cones
	P("RackBack", V3(8, 7, 0.4), CFrame.new(-19.5, 3.7, D / 2 - 1.5), C.woodLight, { Material = WOOD })
	for _, y in ipairs({ 0.9, 3.0, 5.1 }) do
		P("Shelf", V3(8, 0.4, 3), CFrame.new(-19.5, y + 0.4, D / 2 - 3), C.woodLight, { Material = WOOD })
		for _, xo in ipairs({ -2.6, 0, 2.6 }) do
			P("Tire", V3(1.4, 2.6, 2.6), CFrame.new(-19.5 + xo, y + 0.6 + 1.3, D / 2 - 3) * ANG(0, rad(90), 0), C.tire, { Shape = Enum.PartType.Cylinder })
		end
	end
	P("Toolbox", V3(2.2, 3.4, 3.2), CFrame.new(-21.4, 2.1, -21), C.toolRed)
	P("ToolboxLid", V3(2.4, 0.3, 3.4), CFrame.new(-21.4, 3.95, -21), Color3.fromRGB(120, 24, 24))
	P("Counter", V3(9, 3.6, 3), CFrame.new(17, 2.0, D / 2 - 2.8), Color3.fromRGB(60, 44, 36), { Material = WOOD })
	P("CounterTop", V3(9.6, 0.4, 3.6), CFrame.new(17, 3.95, D / 2 - 2.8), Color3.fromRGB(235, 232, 226), { Material = Enum.Material.Marble })
	local glow = P("CounterGlow", V3(9, 0.25, 0.3), CFrame.new(17, 0.9, D / 2 - 4.4), C.warm, { Material = NEON, CanCollide = false })
	light(glow, C.warm, 16, 1.2)
	for _, xo in ipairs({ 14.5, 17, 19.5 }) do
		P("Stool", V3(2.6, 1.8, 1.8), CFrame.new(xo, 1.6, D / 2 - 6.0) * ANG(0, 0, rad(90)), Color3.fromRGB(40, 40, 46), { Shape = Enum.PartType.Cylinder })
	end
	for _, o in ipairs({ { 10, -D / 2 + 3 }, { -10, -D / 2 + 3 } }) do
		P("ConeBase", V3(2.6, 0.4, 2.6), CFrame.new(o[1], 0.4, o[2]), Color3.fromRGB(40, 40, 44))
		P("Cone", V3(1.8, 2.6, 1.8), CFrame.new(o[1], 1.9, o[2]), Color3.fromRGB(255, 120, 20))
	end

	-- Fachada: letreiro "GARAGE n", lanternas e título do dono (Label)
	local doorSign = P("DoorSign", V3(22, 4, 0.6), CFrame.new(0, DH + 3.6, -D / 2 - 0.35), Color3.fromRGB(34, 24, 20), { Material = WOOD, CanCollide = false })
	sign(doorSign, Enum.NormalId.Front, { { text = "GARAGE " .. i, h = 1, color = C.gold } })
	for _, sx in ipairs({ -1, 1 }) do
		local lamp = P("DoorLamp", V3(1.4, 1.8, 1.4), CFrame.new(sx * (DW / 2 + 3.6), 9, -D / 2 - 0.9), C.warm, { Material = NEON, CanCollide = false })
		light(lamp, C.warm, 24, 1.4)
	end
	local anchor = P("TitleAnchor", V3(1, 1, 1), CFrame.new(0, H + 14, 0), C.white, { Transparency = 1, CanCollide = false, CanQuery = false })
	local bb = Instance.new("BillboardGui")
	bb.Name = "Title"; bb.Size = UDim2.fromOffset(320, 90); bb.MaxDistance = 260; bb.Adornee = anchor; bb.Parent = anchor
	local l = Instance.new("TextLabel")
	l.Name = "Label"; l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 1); l.Font = Enum.Font.FredokaOne; l.TextSize = 28
	l.TextColor3 = C.white; l.Text = "Free Garage"
	local s = Instance.new("UIStroke"); s.Thickness = 3; s.Parent = l
	l.Parent = bb

	model.Parent = plots
end

-- ===================================================================== PRAÇA DO LOBBY (referência: deck de madeira, pavilhões vermelhos, pinheiros)
local function pavilion(parent, pos)
	local cf0 = CFrame.new(pos)
	local function P(name, size, lcf, color, o)
		local props = { Name = name, Size = size, CFrame = cf0 * lcf, Color = color }
		if o then for k, v in pairs(o) do props[k] = v end end
		return part(parent, props)
	end
	local WOOD = Enum.Material.WoodPlanks
	P("Floor", V3(15, 0.3, 15), CFrame.new(0, 0.35, 0), C.deckDark, { Material = WOOD })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			P("Post", V3(1.4, 10.4, 1.4), CFrame.new(sx * 6.4, 5.4, sz * 6.4), C.wallWood, { Material = WOOD })
			local lamp = P("Lantern", V3(1.6, 2, 1.6), CFrame.new(sx * 5.2, 7.4, sz * 5.2), C.warm, { Material = Enum.Material.Neon, CanCollide = false })
			light(lamp, C.warm, 22, 1.1)
		end
		P("BeamZ", V3(1, 0.9, 14.4), CFrame.new(sx * 6.4, 10.2, 0), C.wallWood, { Material = WOOD })
		P("Roof", V3(8.8, 0.7, 16.4), CFrame.new(sx * 3.9, 11.7, 0) * ANG(0, 0, -sx * rad(22)), C.roof)
		P("Seat", V3(2.2, 0.6, 9), CFrame.new(sx * 5, 1.9, 0), C.woodLight, { Material = WOOD })
	end
	P("Ridge", V3(1.4, 1, 16.6), CFrame.new(0, 13.3, 0), Color3.fromRGB(120, 28, 28))
end

local function pine(parent, x, z, scale, rng)
	local y = groundY(x, z)
	local tint = rng:NextNumber() < 0.5 and C.pineA or C.pineB
	part(parent, { Name = "Trunk", Size = V3(6 * scale, 1.6 * scale, 1.6 * scale), CFrame = CFrame.new(x, y + 3 * scale, z) * ANG(0, 0, rad(90)),
		Color = C.trunk, Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood })
	for k, d in ipairs({ 12, 9.6, 7.2, 4.8 }) do
		part(parent, { Name = "Tier", Size = V3(3.4 * scale, d * scale, d * scale), CFrame = CFrame.new(x, y + (4.5 + (k - 1) * 3.2) * scale, z) * ANG(0, 0, rad(90)),
			Color = (k % 2 == 0) and tint:Lerp(Color3.new(1, 1, 1), 0.08) or tint, Shape = Enum.PartType.Cylinder, Material = Enum.Material.Grass })
	end
end

local function buildPlaza(deco, drivable)
	local rng = Random.new(2026)
	local WOOD = Enum.Material.WoodPlanks
	for _, s in ipairs({ -1, 1 }) do
		-- deck dirigível (x de 28 a 108, z de 18 a 268): liga a porta das garagens à pista
		part(drivable, { Name = "Deck", Size = V3(80, 1, 250), Position = V3(s * 68, -0.3, 143), Color = C.deck, Material = WOOD })
		for _, z in ipairs({ 86, 150, 214 }) do -- vãos entre as saídas das garagens (os carros passam em z = 54, 118, 182, 246)
			pavilion(deco, V3(s * 68, 0, z))
			part(deco, { Name = "Bench", Size = V3(3, 0.6, 14), Position = V3(s * 36, 1.9, z), Color = C.deckDark, Material = WOOD })
			part(deco, { Name = "BenchBack", Size = V3(0.6, 2.2, 14), Position = V3(s * 37.6, 3.1, z), Color = C.deckDark, Material = WOOD })
			for _, dz in ipairs({ -6.5, 6.5 }) do part(deco, { Name = "BenchLeg", Size = V3(2.4, 1.6, 1), Position = V3(s * 36, 1.0, z + dz), Color = C.stone, Material = Enum.Material.Cobblestone }) end
			for _, dz in ipairs({ -11, 11 }) do part(deco, { Name = "Hedge", Size = V3(4, 2.6, 8), Position = V3(s * 36, 1.5, z + dz), Color = C.hedge, Material = Enum.Material.Grass }) end
		end
		for _, z in ipairs({ 73, 99, 137, 163, 201, 227 }) do -- postes com lanterna na beira da pista
			part(deco, { Name = "LampPost", Size = V3(0.9, 9, 0.9), Position = V3(s * 30, 4.7, z), Color = C.wallWood, Material = WOOD })
			local lamp = part(deco, { Name = "Lamp", Size = V3(2.2, 2.6, 2.2), Position = V3(s * 30, 10.3, z), Color = C.warm, Material = Enum.Material.Neon, CanCollide = false })
			light(lamp, C.warm, 30, 1.2)
		end
		-- placa "HOW TO PLAY" (z = 272, fora do caminho das saídas), de frente para a praça
		local bx = s * 60
		for _, dx in ipairs({ -8, 8 }) do part(deco, { Name = "BoardPost", Size = V3(1.2, 10, 1.2), Position = V3(bx + dx, 5.2, 272), Color = C.wallWood, Material = WOOD }) end
		local board = part(deco, { Name = "HowToPlay", Size = V3(18, 10, 0.8), Position = V3(bx, 11, 272), Color = Color3.fromRGB(34, 24, 20), Material = WOOD })
		part(deco, { Name = "BoardRoof", Size = V3(19.4, 1, 2.6), Position = V3(bx, 16.6, 271.4), Color = C.roof })
		sign(board, Enum.NormalId.Front, {
			{ text = "HOW TO PLAY", h = 0.3, color = C.gold }, { text = "1  Drive & find anime", h = 0.22, color = C.white, stroke = 2 },
			{ text = "2  Capture them", h = 0.22, color = C.white, stroke = 2 }, { text = "3  Earn $ in your garage", h = 0.22, color = C.white, stroke = 2 } })
		-- pinheiros atrás das garagens
		for z = 30, 270, 20 do
			pine(deco, s * (176 + rng:NextNumber(0, 16)), z + rng:NextNumber(-6, 6), rng:NextNumber(0.9, 1.5), rng)
		end
	end
end

-- ===================================================================== PORTAIS DE BIOMA (barreira + nome + requisito)
-- Cada THEMES[id] desenha pilares/viga do tema e devolve a meia-profundidade do pilar (p/ colar as placas de TIER).
local THEMES = {}

THEMES.verdant = function(P, b, hs, TOP)
	local log, leaf = Color3.fromRGB(112, 78, 48), Color3.fromRGB(72, 150, 70)
	for _, s in ipairs({ -1, 1 }) do
		P("Pillar", V3(56, 6.5, 6.5), CFrame.new(s * hs, 28, 0) * ANG(0, 0, rad(90)), log, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood })
		P("Canopy", V3(13, 13, 13), CFrame.new(s * hs, 57, 0), leaf, { Shape = Enum.PartType.Ball, Material = Enum.Material.Grass })
		P("Canopy2", V3(9, 9, 9), CFrame.new(s * (hs + 6), 52, 2), leaf:Lerp(Color3.new(1, 1, 1), 0.1), { Shape = Enum.PartType.Ball, Material = Enum.Material.Grass })
		local lamp = P("Lantern", V3(2.4, 3, 2.4), CFrame.new(s * (hs - 8), TOP - 7, 0), Color3.fromRGB(255, 214, 140), { Material = Enum.Material.Neon, CanCollide = false })
		light(lamp, Color3.fromRGB(255, 214, 140), 30, 1.4)
	end
	P("Beam", V3(hs * 2 + 14, 5, 5), CFrame.new(0, TOP, 0), log, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood })
	return 3.25
end

THEMES.sakura = function(P, b, hs, TOP)
	local red, black, pink = Color3.fromRGB(196, 40, 52), Color3.fromRGB(26, 20, 24), Color3.fromRGB(255, 160, 200)
	for _, s in ipairs({ -1, 1 }) do
		P("Pillar", V3(56, 5.6, 5.6), CFrame.new(s * hs, 28, 0) * ANG(0, 0, rad(90)), red, { Shape = Enum.PartType.Cylinder })
		P("PillarBase", V3(5, 6.8, 6.8), CFrame.new(s * hs, 2.5, 0) * ANG(0, 0, rad(90)), black, { Shape = Enum.PartType.Cylinder })
		local tx = s * (hs + 17)
		P("TreeTrunk", V3(16, 2.6, 2.6), CFrame.new(tx, 8, 0) * ANG(0, 0, rad(90)), Color3.fromRGB(88, 60, 46), { Shape = Enum.PartType.Cylinder })
		for _, o in ipairs({ { 0, 19, 0, 20 }, { 7, 16, 3, 13 }, { -7, 17, -2, 14 }, { 2, 24, 4, 12 } }) do
			P("Blossom", V3(o[4], o[4], o[4]), CFrame.new(tx + o[1], o[2], o[3]), pink, { Shape = Enum.PartType.Ball, Transparency = 0.05 })
		end
		P("Tip", V3(14, 4, 6.6), CFrame.new(s * (hs + 13.5), TOP + 3.2, 0) * ANG(0, 0, s * rad(11)), black)
	end
	local kasagi = P("Kasagi", V3(hs * 2 + 22, 4, 6.6), CFrame.new(0, TOP + 2, 0), black)
	P("Shimaki", V3(hs * 2 + 16, 3, 5.4), CFrame.new(0, TOP - 1, 0), red)
	P("Nuki", V3(hs * 2 + 2, 2.6, 3.2), CFrame.new(0, 31, 0), red)
	emitter(kasagi, pink, 6, 4, 0.5, 5, V3(0, -3, 0))
	return 2.8
end

THEMES.dunes = function(P, b, hs, TOP)
	local sand, gold, cloth = Color3.fromRGB(224, 186, 124), Color3.fromRGB(240, 192, 72), Color3.fromRGB(214, 92, 40)
	local mat = Enum.Material.Sandstone
	for _, s in ipairs({ -1, 1 }) do
		P("Pillar", V3(8, 56, 8), CFrame.new(s * hs, 28, 0), sand, { Material = mat })
		P("Base", V3(11, 6, 11), CFrame.new(s * hs, 3, 0), sand:Lerp(Color3.new(0, 0, 0), 0.12), { Material = mat })
		for k, w in ipairs({ 10, 8, 6, 4 }) do P("Cap", V3(w, 2.2, w), CFrame.new(s * hs, 57 + (k - 1) * 2.2, 0), sand, { Material = mat }) end
		for _, y in ipairs({ 18, 34 }) do P("GoldBand", V3(8.6, 1.6, 8.6), CFrame.new(s * hs, y, 0), gold, { Material = Enum.Material.Metal }) end
		local bra = P("Brazier", V3(3, 2, 3), CFrame.new(s * (hs - 8), 2, 6), Color3.fromRGB(60, 48, 40), { Material = Enum.Material.Slate })
		local fire = Instance.new("Fire"); fire.Size = 6; fire.Heat = 6; fire.Parent = bra
		P("Banner", V3(5.2, 16, 0.3), CFrame.new(s * (hs + 9), 40, 1), cloth, { Material = Enum.Material.Fabric })
		P("BannerStripe", V3(5.2, 1.4, 0.35), CFrame.new(s * (hs + 9), 46, 1), gold, { Material = Enum.Material.Metal })
	end
	P("Beam", V3(hs * 2 + 16, 6, 8), CFrame.new(0, TOP, 0), sand, { Material = mat })
	P("BeamGold", V3(hs * 2 + 16.6, 1.2, 8.6), CFrame.new(0, TOP - 3.6, 0), gold, { Material = Enum.Material.Metal })
	return 4.25
end

THEMES.tundra = function(P, b, hs, TOP)
	local ice, snow = Color3.fromRGB(150, 214, 255), Color3.fromRGB(246, 250, 255)
	local rng = Random.new(41)
	for _, s in ipairs({ -1, 1 }) do
		P("Pillar", V3(7, 56, 7), CFrame.new(s * hs, 28, 0), ice, { Material = Enum.Material.Ice, Transparency = 0.12, Reflectance = 0.25 })
		P("SnowCap", V3(10, 4, 10), CFrame.new(s * hs, 58, 0), snow, { Material = Enum.Material.Snow })
		for k = 1, 6 do
			local a = rad(k * 60)
			P("Crystal", V3(2.2, 12 + rng:NextInteger(0, 8), 2.2), CFrame.new(s * hs + math.cos(a) * 6, 5, math.sin(a) * 6) * ANG(math.sin(a) * 0.35, 0, -math.cos(a) * 0.35),
				ice:Lerp(snow, 0.3), { Material = Enum.Material.Ice, Transparency = 0.15 })
		end
	end
	P("Beam", V3(hs * 2 + 14, 5, 7), CFrame.new(0, TOP, 0), ice, { Material = Enum.Material.Ice, Transparency = 0.1, Reflectance = 0.2 })
	local top = P("SnowTop", V3(hs * 2 + 16, 2.4, 8.4), CFrame.new(0, TOP + 3.6, 0), snow, { Material = Enum.Material.Snow })
	for k = 1, 12 do
		local len = 1.6 + rng:NextNumber(0, 1.4)
		P("Icicle", V3(1, len, 1), CFrame.new(-hs + 3 + (k - 1) * ((hs * 2 - 6) / 11), TOP - 2.5 - len / 2, 2), Color3.fromRGB(205, 238, 255), { Material = Enum.Material.Ice, Transparency = 0.2 })
	end
	emitter(top, Color3.new(1, 1, 1), 10, 3, 0.6, 5, V3(0, -4, 0))
	return 3.5
end

THEMES.volcano = function(P, b, hs, TOP)
	local rock, lava = Color3.fromRGB(34, 26, 28), Color3.fromRGB(255, 96, 24)
	local rng = Random.new(77)
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, 6 do
			local w = 9 - k * 0.3
			P("Rock", V3(w, 8.4, w), CFrame.new(s * hs + rng:NextNumber(-0.8, 0.8), 4.2 + k * 8, rng:NextNumber(-0.6, 0.6)) * ANG(0, rng:NextNumber(0, 1.5), 0), rock, { Material = Enum.Material.Basalt })
		end
		for k = 1, 4 do
			P("LavaCrack", V3(0.6, 9, 0.35), CFrame.new(s * hs + (k - 2.5) * 1.8, 8 + k * 11, 5.3), lava, { Material = Enum.Material.Neon, CanCollide = false })
		end
		for _, a in ipairs({ -1, 1 }) do
			P("Spike", V3(2.4, 16, 2.4), CFrame.new(s * hs + a * 4.2, 64, 0) * ANG(0, 0, -a * 0.3), rock, { Material = Enum.Material.Basalt })
		end
		local f = P("FireAnchor", V3(2, 2, 2), CFrame.new(s * hs, 62, 0), lava, { Transparency = 1, CanCollide = false, CanQuery = false })
		local fire = Instance.new("Fire"); fire.Size = 16; fire.Heat = 14; fire.Parent = f
		light(f, lava, 60, 3)
	end
	P("Beam", V3(hs * 2 + 14, 6, 8.4), CFrame.new(0, TOP, 0), rock, { Material = Enum.Material.Basalt })
	P("BeamLava", V3(hs * 2 + 14.2, 0.9, 8.6), CFrame.new(0, TOP - 3.4, 0), lava, { Material = Enum.Material.Neon, CanCollide = false })
	for k = 1, 5 do
		P("BeamSpike", V3(2.4, 8 + (k % 3) * 3, 2.4), CFrame.new(-hs + 8 + (k - 1) * ((2 * hs - 16) / 4), TOP + 7, 0), rock, { Material = Enum.Material.Basalt })
	end
	return 4.5
end

THEMES.city = function(P, b, hs, TOP)
	local metal, cyan, mag = Color3.fromRGB(26, 28, 42), Color3.fromRGB(0, 230, 255), Color3.fromRGB(255, 60, 220)
	local NEON = Enum.Material.Neon
	for _, s in ipairs({ -1, 1 }) do
		P("Pillar", V3(6.4, 56, 6.4), CFrame.new(s * hs, 28, 0), metal, { Material = Enum.Material.Metal })
		P("TubeA", V3(0.7, 56, 0.7), CFrame.new(s * hs - 3.4, 28, 3.4), cyan, { Material = NEON, CanCollide = false })
		P("TubeB", V3(0.7, 56, 0.7), CFrame.new(s * hs + 3.4, 28, 3.4), mag, { Material = NEON, CanCollide = false })
		for _, y in ipairs({ 12, 26, 40 }) do P("Brace", V3(7.4, 0.8, 7.4), CFrame.new(s * hs, y, 0), cyan:Lerp(mag, (y - 12) / 56), { Material = NEON, CanCollide = false }) end
		P("Antenna", V3(0.8, 22, 0.8), CFrame.new(s * hs, 67, 0), metal, { Material = Enum.Material.Metal })
		local tip = P("AntennaTip", V3(1.6, 1.6, 1.6), CFrame.new(s * hs, 78.5, 0), Color3.fromRGB(255, 40, 60), { Shape = Enum.PartType.Ball, Material = NEON, CanCollide = false })
		light(tip, Color3.fromRGB(255, 40, 60), 24, 2)
	end
	P("Beam", V3(hs * 2 + 14, 5, 7), CFrame.new(0, TOP, 0), metal, { Material = Enum.Material.Metal })
	P("TubeTop", V3(hs * 2 + 14, 0.8, 0.8), CFrame.new(0, TOP + 2.9, 3.6), cyan, { Material = NEON, CanCollide = false })
	P("TubeBottom", V3(hs * 2 + 14, 0.8, 0.8), CFrame.new(0, TOP - 2.9, 3.6), mag, { Material = NEON, CanCollide = false })
	return 3.2
end

THEMES.celestial = function(P, b, hs, TOP)
	local marble, gold = Color3.fromRGB(246, 244, 252), Color3.fromRGB(255, 214, 110)
	for _, s in ipairs({ -1, 1 }) do
		P("Pillar", V3(7, 56, 7), CFrame.new(s * hs, 28, 0), marble, { Material = Enum.Material.Marble })
		for _, y in ipairs({ 6, 20, 34, 48 }) do
			P("GoldRing", V3(1.4, 9.4, 9.4), CFrame.new(s * hs, y, 0) * ANG(0, 0, rad(90)), gold, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
		end
		for _, o in ipairs({ { -5, 3, 6, 10 }, { 4, 2, 7, 13 }, { 9, 4, -3, 9 }, { -9, 2, -4, 11 }, { 0, 1, -8, 12 } }) do
			P("Cloud", V3(o[4], o[4], o[4]), CFrame.new(s * hs + o[1], o[2], o[3]), Color3.new(1, 1, 1), { Shape = Enum.PartType.Ball, Transparency = 0.12, CanCollide = false })
		end
	end
	local beam = P("Beam", V3(hs * 2 + 14, 5, 7), CFrame.new(0, TOP, 0), marble, { Material = Enum.Material.Marble })
	P("BeamGold", V3(hs * 2 + 14.4, 0.9, 7.4), CFrame.new(0, TOP - 2.7, 0), gold, { Material = Enum.Material.Metal })
	local R, N = 20, 16 -- auréola dourada vertical (16 segmentos) acima do portal
	for k = 0, N - 1 do
		local a = rad(k * 360 / N)
		P("Halo", V3(8.4, 1.8, 1.8), CFrame.new(math.cos(a) * R, TOP + 16 + math.sin(a) * R, 0) * ANG(0, 0, a + math.pi / 2), gold, { Material = Enum.Material.Neon, CanCollide = false })
	end
	emitter(beam, gold, 8, 3, 0.8, 4, V3(0, 2, 0))
	return 3.5
end

local function buildGate(i, b, folder)
	local z = (i == 1) and 24 or b.ZStart -- bioma 1: arco de largada logo após o lobby
	local x = W.RoadX(z)
	local fwd = V3(W.RoadX(z - 10) - W.RoadX(z), 0, -10).Unit
	local base = V3(x, groundY(x, z), z)
	local cf = CFrame.lookAt(base, base + fwd) -- -Z local = sentido da corrida; a face "Back" (+Z) olha para quem chega
	local hs, TOP = W.RoadFlat + 8, 52
	local model = Instance.new("Model"); model.Name = "Gate_" .. i .. "_" .. b.Id
	model:SetAttribute("BiomeId", b.Id); model:SetAttribute("Tier", b.Tier)
	local col = b.Color
	local dark = col:Lerp(Color3.new(0, 0, 0), 0.65)
	local function P(name, size, lcf, color, o)
		local props = { Name = name, Size = size, CFrame = cf * lcf, Color = color }
		if o then for k, v in pairs(o) do props[k] = v end end
		return part(model, props)
	end
	local pd = (THEMES[b.Id] or THEMES.verdant)(P, b, hs, TOP)

	-- Painel de informações (nome + requisito) pendurado entre os pilares
	local car = carForTier(b.Tier)
	local panel = P("InfoPanel", V3(hs * 2 - 8, 13, 1.2), CFrame.new(0, 40, 0), dark, { Material = Enum.Material.Metal })
	local reqLine = (i == 1) and "START HERE • ANY CAR" or ("🔒 REQUIRES CAR TIER " .. b.Tier)
	local carLine = (i == 1) and ((car and car.Name or "Starter") .. " is enough") or ((car and car.Name or ("Tier " .. b.Tier)) .. " or better")
	sign(panel, Enum.NormalId.Back, {
		{ text = b.Emoji .. " " .. b.Name:upper(), h = 0.48, color = col:Lerp(Color3.new(1, 1, 1), 0.25), stroke = 4 },
		{ text = reqLine, h = 0.27, color = Color3.new(1, 1, 1), stroke = 3 },
		{ text = carLine, h = 0.25, color = Color3.fromRGB(255, 222, 120), stroke = 2 } })
	sign(panel, Enum.NormalId.Front, {
		{ text = (i == 1) and "DRIVE SAFE!" or "WELCOME TO", h = 0.3, color = Color3.new(1, 1, 1), stroke = 3 },
		{ text = b.Emoji .. " " .. b.Name:upper(), h = 0.7, color = col:Lerp(Color3.new(1, 1, 1), 0.25), stroke = 4 } })
	for _, y in ipairs({ 33.1, 46.9 }) do P("FrameH", V3(hs * 2 - 7, 0.6, 1.5), CFrame.new(0, y, 0), col, { Material = Enum.Material.Neon, CanCollide = false }) end
	for _, s in ipairs({ -1, 1 }) do
		P("FrameV", V3(0.6, 14.4, 1.5), CFrame.new(s * (hs - 3.7), 40, 0), col, { Material = Enum.Material.Neon, CanCollide = false })
		P("Rod", V3(0.6, 3, 0.6), CFrame.new(s * (hs - 8), 48.4, 0), dark, { Material = Enum.Material.Metal })
		-- plaquetas "TIER n" coladas na face voltada para o jogador
		local pl = P("TierPlaque", V3(5.2, 6.4, 0.4), CFrame.new(s * hs, 13, pd + 0.25), dark, { Material = Enum.Material.Metal })
		sign(pl, Enum.NormalId.Back, { { text = "TIER", h = 0.3, color = col, stroke = 2 }, { text = tostring(b.Tier), h = 0.7, color = Color3.new(1, 1, 1), stroke = 3 } })
	end
	-- Campo de energia (a "barreira") + linha neon no asfalto. Sem colisão: quem barra é o ZoneService.
	if i >= 2 then
		P("Portal", V3(hs * 2 - 10, 40, 0.5), CFrame.new(0, 20, 0), col, { Material = Enum.Material.Neon, Transparency = 0.82, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	P("RoadLine", V3(W.RoadFlat * 2 - 2, 0.12, 1.6), CFrame.new(0, 0.25, 0), (i == 1) and Color3.new(1, 1, 1) or col, { Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
	model.Parent = folder
end

-- ===================================================================== API
function LobbyBuilder.BuildLobby()
	local map = mapRoot()
	folderIn(map, "Plots", true)
	local drivable = folderIn(map.Drivable, "Lobby", true)
	local deco = folderIn(map.Structures, "Lobby", true)
	for i = 1, 8 do buildGarage(i, map.Plots, drivable) end
	buildPlaza(deco, drivable)
	local n = #map.Plots:GetDescendants() + #drivable:GetDescendants() + #deco:GetDescendants()
	return ("lobby ok: 8 garagens + praça (%d instâncias)"):format(n)
end

function LobbyBuilder.BuildGates()
	local map = mapRoot()
	local folder = folderIn(map.Structures, "Gates", true)
	for i, b in ipairs(Biomes) do buildGate(i, b, folder) end
	return ("%d portais ok (%d instâncias)"):format(#Biomes, #folder:GetDescendants())
end

function LobbyBuilder.Build()
	return LobbyBuilder.BuildLobby() .. " | " .. LobbyBuilder.BuildGates()
end

return LobbyBuilder
