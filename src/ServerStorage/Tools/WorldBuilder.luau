--[[
	WorldBuilder v2  (FERRAMENTA DE EDIÇÃO — roda no Studio, NÃO durante o jogo)
	===========================================================================
	Gera o mundo a partir de Config.World / Config.Garage / Config.Biomes. Idempotente (pode rodar de novo).

	  local WB = require(game.ServerStorage.Tools.WorldBuilder)
	  WB.StyleTerrain(); WB.ClearTerrain()
	  WB.BuildTerrain(380, 0)                    -- hub (z de 380 até 0)
	  WB.BuildTerrain(b.ZStart, b.ZEnd - 40)     -- um bioma por vez (veja Config.Biomes)
	  WB.BuildLobbyTerrain()                     -- Beta 1.2: ilha flutuante do lobby (Config.Lobby)
	  WB.BuildLobby()                            -- Beta 1.4: lobby "Sakura Night" (zonas em Config.Lobby.Zones)
	  WB.BuildMap()                              -- lobby (garagens/portal/santuário) + largada + portões (não apaga biomas)
	  WB.BuildBiome(i)                           -- props, obstáculos, boost pads e pontos de captura do bioma i

	TERRENO: heightmap por Perlin noise escrito com Terrain:WriteVoxels (superfície suave). A estrada
	(Config.World.RoadX) é plana e cercada por colinas e paredões laterais (corredor).
	OBSTÁCULOS: sorteados de forma DETERMINÍSTICA por bioma (Config.Biomes[i].Obstacles = pesos), espaçados
	260-420 studs. Tipos de terreno (crest, whoops, gap) alteram o heightmap; os demais são peças.
	  gap  = abismo atravessando TODO o mundo + ponte estreita (carro que cai é resgatado pelo ZoneService)
	  ice  = zona com tag "IceZone" (o DriveController reduz aderência)
]]
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(RS.Shared.Config)
local W, G = Config.World, Config.Garage
local biomes = Config.Biomes
local V3 = Vector3.new
local Terrain = workspace.Terrain
local lastEnd = biomes[#biomes].ZEnd

local WorldBuilder = {}

local function smooth(t) t = math.clamp(t, 0, 1); return t * t * (3 - 2 * t) end

-- ===================================================================== TERRENO
local function biomeIndexAt(z)
	for i, b in ipairs(biomes) do if z <= b.ZStart and z > b.ZEnd then return i end end
	if z <= lastEnd then return #biomes end
	return 0
end
local function terrainParam(idx, key)
	local t = (idx < 1) and W.HubTerrain or biomes[idx].Terrain
	return t[key] or 0  -- parâmetro ausente (ex.: Terrace fora do bioma 1) conta como 0
end
-- Parâmetro interpolado entre biomas vizinhos (sem "degrau" na fronteira)
local function param(z, key)
	local idx = biomeIndexAt(z)
	local v = terrainParam(idx, key)
	local B = W.BlendZone
	if idx >= 1 then
		local b = biomes[idx]
		local dStart = b.ZStart - z
		if idx > 1 and dStart < B then
			local pv = terrainParam(idx - 1, key)
			v = pv + (v - pv) * smooth(0.5 + 0.5 * dStart / B)
		end
		local dEnd = z - b.ZEnd
		local nb = biomes[idx + 1]
		if nb and dEnd < B then
			local nv = terrainParam(idx + 1, key)
			v = nv + (v - nv) * smooth(0.5 + 0.5 * dEnd / B)
		end
	end
	return v
end

-- ---- Obstáculos (determinístico): lista de features por bioma
local features
local function buildFeatures()
	features = { Crests = {}, Whoops = {}, Gaps = {}, List = {} }
	for _, b in ipairs(biomes) do
		local rng = Random.new(b.Order * 104729)
		local kinds = {}
		for k in pairs(b.Obstacles) do kinds[#kinds + 1] = k end
		table.sort(kinds)
		local menu = {}
		for _, k in ipairs(kinds) do for _ = 1, b.Obstacles[k] do menu[#menu + 1] = k end end
		local forced = {}                       -- obstáculos de assinatura do bioma (peso >= 3)
		for _, k in ipairs(kinds) do
			if b.Obstacles[k] >= 3 and k ~= "ramp" and k ~= "gap" then forced[#forced + 1] = k end
		end
		local fIdx = 0
		local z, lastGap = b.ZStart - 260, nil
		while z > b.ZEnd + 300 do
			fIdx += 1
			local kind = forced[fIdx] or menu[rng:NextInteger(1, #menu)]
			if kind == "gap" and lastGap and (lastGap - z) < 1000 then kind = "crest" end -- abismos bem espaçados
			local f = { Kind = kind, Z = z, Biome = b }
			if kind == "crest" then
				f.H = rng:NextNumber(5, 9) + b.Order * 0.6; f.Wd = rng:NextNumber(34, 52)
				table.insert(features.Crests, f)
			elseif kind == "whoops" then
				f.Len = rng:NextNumber(180, 280); f.Amp = rng:NextNumber(1.6, 2.4)
				table.insert(features.Whoops, f)
			elseif kind == "gap" then
				f.Len = rng:NextNumber(60, 80) + b.Order * 4
				table.insert(features.Gaps, f); lastGap = z
			end
			table.insert(features.List, f)
			-- espaçamento = folga aleatória + comprimento do próprio obstáculo (evita sobreposição)
			local LEN = { ramp = 60, bumps = 60, slalom = 220, pinch = 140, logs = 90, ice = 130, gate = 20, crest = 70 }
			local adv = rng:NextNumber(50, 100) + (LEN[kind] or 60)
			if kind == "gap" then adv += f.Len + 40 elseif kind == "whoops" then adv += f.Len end
			z -= adv
		end
	end
end
local function F() if not features then buildFeatures() end return features end
local function isVoid(z)
	for _, f in ipairs(F().Gaps) do if z <= f.Z and z >= f.Z - f.Len then return true end end
	return false
end

-- Perfil de altura da estrada (ondulação base + lombos + ondulações)
local function roadProfile(z)
	local ramp = smooth(-z / 200)
	local y = math.noise(z / 170, 0.5, 11.7) * 2 * W.RoadRoll * ramp
	local fs = F()
	for _, f in ipairs(fs.Crests) do
		local dz = (z - f.Z) / f.Wd
		if math.abs(dz) < 3 then y += f.H * math.exp(-dz * dz) end
	end
	for _, f in ipairs(fs.Whoops) do
		if z <= f.Z and z >= f.Z - f.Len then
			local t = (f.Z - z) / f.Len
			y += f.Amp * math.sin((f.Z - z) / 9.5) * math.min(1, math.sin(math.pi * t) * 4)
		end
	end
	return y
end
local function wallEnd(z)
	local eEnd = math.clamp((lastEnd + 90 - z) / 90, 0, 1)
	local eHub = math.clamp((z - (W.HubDepth - 60)) / 60, 0, 1)
	return (eEnd * eEnd + eHub * eHub) * W.WallHeight
end

-- Tudo que depende só de Z fica em cache (quantizado a 1 stud): acelera MUITO a geração.
local zcache = {}
local function zinfo(z)
	local key = math.floor(-z + 0.5)
	local c = zcache[key]
	if c then return c end
	local zz = -key
	c = { Amp = param(zz, "Amp"), Scale = param(zz, "Scale"), RoadX = W.RoadX(zz), Road = roadProfile(zz),
		Ramp = smooth(-zz / 200), Wall = wallEnd(zz), Void = isVoid(zz),
		Terrace = param(zz, "Terrace"), TerraceMix = param(zz, "TerraceMix") }
	zcache[key] = c
	return c
end

local function surfaceHeight(x, z)
	local c = zinfo(z)
	local scale = c.Scale
	local n = math.noise(x / scale, z / scale, 7.3) * 2 + math.noise(x / (scale * 0.45), z / (scale * 0.45), 3.1)
	local hills = (n * 0.5 + 0.35) * c.Amp * c.Ramp
	if c.TerraceMix > 0.001 and hills > 0 then
		local s = math.max(c.Terrace, 6)
		local q = hills / s
		local f = q - math.floor(q)
		local stepped = (math.floor(q) + smooth((f - 0.72) / 0.28)) * s  -- 72% do degrau plano, 28% subida
		hills += (stepped - hills) * c.TerraceMix
	end
	local d = math.abs(x - c.RoadX)
	local k = smooth((d - W.RoadFlat) / W.RoadBlend)               -- 0 na estrada, 1 longe dela
	local h = c.Road * (1 - k) + hills * k
	local edge = math.clamp((math.abs(x) - W.WallStart) / W.WallRamp, 0, 1)
	h += edge * edge * W.WallHeight + c.Wall                       -- paredões laterais e fim do mundo
	return math.max(h, -16)
end
WorldBuilder.SurfaceHeight = surfaceHeight
function WorldBuilder.Features() return F() end
function WorldBuilder.IsVoid(z) return isVoid(z) end

function WorldBuilder.StyleTerrain()
	for mat, color in pairs(Config.TerrainColors) do Terrain:SetMaterialColor(mat, color) end
	pcall(function() Terrain.Decoration = false end)
	return "terreno estilizado"
end
function WorldBuilder.ClearTerrain() Terrain:Clear() end

function WorldBuilder.BuildTerrain(zFrom, zTo)
	local cell, chunk = 4, 32
	local xMin0 = -W.HalfWidth
	local nxTotal = (2 * W.HalfWidth) / cell
	local yMin, yMax = W.YMin, W.YMax
	local ny = (yMax - yMin) / cell
	local zLo = math.floor(math.min(zFrom, zTo) / cell) * cell
	local zHi = math.ceil(math.max(zFrom, zTo) / cell) * cell
	local count = 0
	for zMin = zLo, zHi - 1, chunk * cell do
		local nz = math.min(chunk, (zHi - zMin) / cell)
		for xi = 0, nxTotal - 1, chunk do
			local nx = math.min(chunk, nxTotal - xi)
			local xMin = xMin0 + xi * cell
			local mats, occ = table.create(nx), table.create(nx)
			for i = 1, nx do
				mats[i], occ[i] = table.create(ny), table.create(ny)
				for j = 1, ny do
					mats[i][j] = table.create(nz, Enum.Material.Air)
					occ[i][j] = table.create(nz, 0)
				end
			end
			for k = 1, nz do
				local z = zMin + (k - 0.5) * cell
				if not zinfo(z).Void then            -- abismos: coluna vazia
					for i = 1, nx do
						local x = xMin + (i - 0.5) * cell
						-- o Roblox desenha a superfície meio voxel ACIMA do preenchimento: compensa (cell/2)
						local surf = surfaceHeight(x, z) - cell / 2
						local sx = surfaceHeight(x + cell, z) - surfaceHeight(x - cell, z)
						local sz = surfaceHeight(x, z + cell) - surfaceHeight(x, z - cell)
						local slope = math.sqrt(sx * sx + sz * sz) / (2 * cell)
						local bi = biomeIndexAt(z + 40 * math.noise(x / 60, 5.5, 3.3)) -- fronteira "orgânica"
						local T = (bi == 0) and W.HubTerrain or biomes[bi].Terrain
						local d = math.abs(x - zinfo(z).RoadX)
						local top = (slope > 0.9) and T.Cliff or T.Top
						local isRoad = d < W.RoadFlat - 2
						local isEdge = (not isRoad) and d < W.RoadFlat + 2
						for j = 1, ny do
							local yb = yMin + (j - 1) * cell
							local o = math.clamp((surf - yb) / cell, 0, 1)
							if o > 0.01 then
								local depth = surf - (yb + cell * 0.5)
								local mat
								if isRoad and depth < 8 then mat = T.Road
								elseif isEdge and depth < 8 then mat = T.RoadEdge
								elseif depth < 5 then mat = top
								else mat = T.Sub end
								mats[i][j][k], occ[i][j][k] = mat, o
							end
						end
					end
				end
			end
			Terrain:WriteVoxels(Region3.new(V3(xMin, yMin, zMin), V3(xMin + nx * cell, yMax, zMin + nz * cell)), cell, mats, occ)
			count += 1
			task.wait()
		end
	end
	return ("terreno z[%d..%d]: %d blocos"):format(zFrom, zTo, count)
end

-- ===================================================================== AUXILIARES DE MAPA
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Terrain }
local function ground(x, z)
	local hit = workspace:Raycast(V3(x, 400, z), V3(0, -800, 0), groundParams)
	if hit then return hit.Position.Y, hit.Normal end
	return 0, V3(0, 1, 0)
end
local function roadForward(z) return V3(W.RoadX(z - 10) - W.RoadX(z), 0, -10).Unit end
-- CFrame no chão da estrada, olhando ao longo dela (X = direita). lateral = deslocamento lateral.
local function frameAt(z, lateral)
	local fwd = roadForward(z)
	local right = fwd:Cross(V3(0, 1, 0))
	local p = V3(W.RoadX(z), 0, z) + right * (lateral or 0)
	local pos = V3(p.X, (ground(p.X, p.Z)), p.Z)
	return CFrame.lookAt(pos, pos + fwd), pos, fwd
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

local function signGui(p, face, title, sub, color)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 24; sg.Parent = p
	local function lbl(y, h, text, col)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, h); l.Position = UDim2.fromScale(0, y)
		l.Font = Enum.Font.FredokaOne; l.TextScaled = true; l.Text = text; l.TextColor3 = col
		local s = Instance.new("UIStroke"); s.Thickness = 4; s.Parent = l
		l.Parent = sg
	end
	if sub and sub ~= "" then lbl(0.04, 0.58, title, color); lbl(0.62, 0.34, sub, Color3.new(1, 1, 1))
	else lbl(0.1, 0.8, title, color) end
end

local function arch(parent, center, forward, halfSpan, title, sub, color)
	local cy = ground(center.X, center.Z)
	local base = V3(center.X, cy, center.Z)
	local cf = CFrame.lookAt(base, base + forward)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.45)
	for _, s in ipairs({ -1, 1 }) do
		part(parent, { Name = "Pillar", Size = V3(6, 60, 6), CFrame = cf * CFrame.new(s * halfSpan, 22, 0), Color = dark })
	end
	local beam = part(parent, { Name = "Beam", Size = V3(halfSpan * 2 + 10, 12, 8), CFrame = cf * CFrame.new(0, 42, 0), Color = dark })
	signGui(beam, Enum.NormalId.Back, title, sub, color)
	return cf
end

-- ===================================================================== GARAGEM (referência: imagem do usuário)
local COL = {
	green = Color3.fromRGB(58, 112, 74), greenDark = Color3.fromRGB(38, 78, 52), metal = Color3.fromRGB(46, 52, 60),
	concrete = Color3.fromRGB(62, 66, 78), concreteLight = Color3.fromRGB(104, 108, 120),
	cyan = Color3.fromRGB(0, 205, 255), magenta = Color3.fromRGB(255, 70, 255), blueLight = Color3.fromRGB(110, 180, 255),
	warm = Color3.fromRGB(255, 214, 150), yellow = Color3.fromRGB(255, 200, 20), white = Color3.new(1, 1, 1),
	tire = Color3.fromRGB(26, 26, 30), orange = Color3.fromRGB(255, 120, 20), box = Color3.fromRGB(176, 138, 88),
	wood = Color3.fromRGB(140, 100, 60), red = Color3.fromRGB(200, 50, 50), blue = Color3.fromRGB(40, 90, 200),
	grey = Color3.fromRGB(120, 124, 136),
}
local function pointLight(p, color, range, brightness)
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = brightness; l.Parent = p
end

local function buildGarage(i, folder)
	local left = i <= 4
	local row = (i - 1) % 4
	-- Beta 1.2: garagens no LOBBY (Config.Lobby.Origin), 4 de cada lado da avenida central
	local LO = Config.Lobby.Origin
	local cx = LO.X + (left and -G.CenterX or G.CenterX)
	local cz = LO.Z + (row - 1.5) * G.Spacing
	local center = V3(cx, (ground(cx, cz)), cz) -- Beta 1.4b: chão real do terreno (desenhado em y≈2)
	-- origem local: -Z = FRENTE (portão voltado para a pista). Garagens 1-4 à esquerda, 5-8 à direita.
	local origin = CFrame.lookAt(center, center + V3(left and 1 or -1, 0, 0))
	local model = Instance.new("Model"); model.Name = "Plot_" .. i  -- "Plot_N": nome usado pelo FarmService
	model:SetAttribute("PlotIndex", i); model:SetAttribute("OwnerUserId", 0)
	local Wd, D, H, DW, DH = G.Width, G.Depth, G.Height, G.DoorWidth, G.DoorHeight

	local function P(name, size, lcf, color, o)
		local props = { Name = name, Size = size, CFrame = origin * lcf, Color = color }
		if o then for k, v in pairs(o) do props[k] = v end end
		return part(model, props)
	end
	local metalMat = Enum.Material.Metal

	-- Beta 1.4b: GARAGEM JAPONESA NOTURNA (combina com o lobby Sakura Night). Contrato do FarmService mantido:
	-- Base (+Title/Label), Slots/Slot_N, Placed, CarPad, CarSpawn, PlayerSpawn.
	local wood, woodDark, paper = Color3.fromRGB(78, 44, 50), Color3.fromRGB(42, 24, 32), Color3.fromRGB(246, 230, 214)
	local stone, sakura, lanternC = Color3.fromRGB(70, 64, 88), Color3.fromRGB(255, 125, 196), Color3.fromRGB(255, 150, 70)
	local WoodM, Slate = Enum.Material.Wood, Enum.Material.Slate

	-- Piso de pedra escura + passarela de madeira até o carro + soleira
	local base = P("Base", V3(Wd, 0.5, D), CFrame.new(0, 0.25, 0), stone, { Material = Slate })
	P("Walkway", V3(14, 0.1, D - 4), CFrame.new(0, 0.55, -2), Color3.fromRGB(150, 98, 70), { Material = Enum.Material.WoodPlanks, CanCollide = false })
	P("Apron", V3(Wd - 4, 0.5, 44), CFrame.new(0, 0.25, -D / 2 - 22), Color3.fromRGB(64, 56, 96), { Material = Slate })
	P("Threshold", V3(DW, 0.3, 2.6), CFrame.new(0, 0.6, -D / 2 + 1), woodDark, { Material = WoodM })

	-- Paredes de madeira escura com painéis SHOJI (papel iluminado) e pilares
	P("WallL", V3(1.2, H, D), CFrame.new(-Wd / 2 + 0.6, H / 2, 0), wood, { Material = WoodM })
	P("WallR", V3(1.2, H, D), CFrame.new(Wd / 2 - 0.6, H / 2, 0), wood, { Material = WoodM })
	P("WallBack", V3(Wd, H, 1.2), CFrame.new(0, H / 2, D / 2 - 0.6), wood, { Material = WoodM })
	local segW = (Wd - DW) / 2
	P("WallFrontL", V3(segW, H, 1.2), CFrame.new(-(DW / 2 + segW / 2), H / 2, -D / 2 + 0.6), wood, { Material = WoodM })
	P("WallFrontR", V3(segW, H, 1.2), CFrame.new(DW / 2 + segW / 2, H / 2, -D / 2 + 0.6), wood, { Material = WoodM })
	P("Lintel", V3(DW, H - DH, 1.2), CFrame.new(0, DH + (H - DH) / 2, -D / 2 + 0.6), woodDark, { Material = WoodM })
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (Wd / 2 - 1.3)
		for k = 0, 4 do -- painéis shoji entre os pilares
			local z = -D / 2 + 7 + k * 11
			P("Shoji", V3(0.2, 8, 9), CFrame.new(x, 9, z), paper, { Material = Enum.Material.SmoothPlastic, CanCollide = false })
			P("ShojiBarH", V3(0.3, 0.3, 9), CFrame.new(x - side * 0.1, 9, z), woodDark, { CanCollide = false })
			P("ShojiBarV", V3(0.3, 8, 0.3), CFrame.new(x - side * 0.1, 9, z), woodDark, { CanCollide = false })
		end
		for k = 0, 5 do
			P("Pillar", V3(1.6, H, 1.6), CFrame.new(side * (Wd / 2 - 1.5), H / 2, -D / 2 + 1.5 + k * 11), woodDark, { Material = WoodM })
		end
		P("BaseBoard", V3(0.6, 2, D - 2), CFrame.new(side * (Wd / 2 - 1.4), 1.5, 0), woodDark, { Material = WoodM })
	end

	-- Telhado de telhas escuras com beiral, borda vermelha e friso neon rosa + vigas de madeira
	P("Roof", V3(Wd + 6, 1.2, D + 6), CFrame.new(0, H + 0.6, 0), Color3.fromRGB(36, 32, 56), { Material = Slate })
	P("RoofRidge", V3(Wd - 10, 2, 4), CFrame.new(0, H + 2.2, 0), Color3.fromRGB(28, 24, 44), { Material = Slate })
	P("RoofTrim", V3(Wd + 6.4, 0.6, D + 6.4), CFrame.new(0, H - 0.1, 0), Color3.fromRGB(200, 44, 58))
	P("RoofNeon", V3(Wd + 6.6, 0.3, 0.4), CFrame.new(0, H + 1.3, -D / 2 - 3.1), sakura, { Material = Enum.Material.Neon, CanCollide = false })
	for _, zt in ipairs({ -20, -7, 6, 19 }) do
		P("Beam", V3(Wd - 2, 1.2, 1.4), CFrame.new(0, H - 1, zt), woodDark, { Material = WoodM })
	end

	-- Lanternas de papel penduradas (as únicas luzes internas: leve para celular)
	for _, z in ipairs({ -12, 12 }) do
		P("LanternCord", V3(0.15, 3, 0.15), CFrame.new(0, H - 3, z), woodDark, { CanCollide = false })
		local lan = P("Lantern", V3(3.4, 3, 3.4), CFrame.new(0, H - 6, z) * CFrame.Angles(0, 0, math.rad(90)), lanternC,
			{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, CanCollide = false })
		lan.Size = V3(3.4, 3.4, 3.4); lan.Shape = Enum.PartType.Ball
		pointLight(lan, Color3.fromRGB(255, 180, 120), 34, 1.6)
	end

	-- Entrada: cortina NOREN sobre a porta e duas lanternas vermelhas do lado de fora
	for k = 0, 3 do
		local x = -DW / 2 + 2 + k * ((DW - 4) / 3)
		P("Noren", V3((DW - 6) / 4, 2.2, 0.15), CFrame.new(x, DH - 1.1, -D / 2 - 0.3), Color3.fromRGB(46, 40, 110), { Material = Enum.Material.Fabric, CanCollide = false })
	end
	P("NorenMark", V3(0.1, 1.8, 1.8), CFrame.new(0, DH - 1.8, -D / 2 - 0.4), sakura, { Shape = Enum.PartType.Cylinder, CanCollide = false }).CFrame =
		origin * CFrame.new(0, DH - 1.1, -D / 2 - 0.42) * CFrame.Angles(0, math.rad(90), 0)
	for _, sx in ipairs({ -1, 1 }) do
		P("DoorLantern", V3(2.4, 3.2, 2.4), CFrame.new(sx * (DW / 2 + 3), DH - 2, -D / 2 - 1.6), Color3.fromRGB(230, 50, 60), { Material = Enum.Material.Neon, CanCollide = false })
		P("DoorLanternCap", V3(2.8, 0.4, 2.8), CFrame.new(sx * (DW / 2 + 3), DH - 0.2, -D / 2 - 1.6), woodDark, { CanCollide = false })
	end
	local doorSign = P("DoorSign", V3(20, 3.4, 0.5), CFrame.new(0, DH + 3.4, -D / 2 - 0.3), woodDark, { CanCollide = false })
	signGui(doorSign, Enum.NormalId.Front, "🌸 GARAGE " .. i, nil, sakura)

	-- Fundo: pergaminho pendurado com o nome + moldura de madeira
	P("ScrollFrame", V3(26, 8.2, 0.5), CFrame.new(0, 13, D / 2 - 1.4), woodDark, { Material = WoodM })
	local sign = P("SignBack", V3(24, 6.6, 0.6), CFrame.new(0, 13, D / 2 - 1.75), paper)
	signGui(sign, Enum.NormalId.Front, "GARAGE", "ガレージ", Color3.fromRGB(200, 44, 58))

	-- Pedestais dos personagens: ALTARES de pedra (8 vagas, 4 de cada lado, viradas para o corredor)
	local slots = Instance.new("Folder"); slots.Name = "Slots"; slots.Parent = model
	local n = 0
	for _, side in ipairs({ -1, 1 }) do
		for _, zl in ipairs(G.PodiumZ) do
			n += 1
			local lp = V3(side * G.PodiumX, 0.9, zl)
			P("AltarStep", V3(9.4, 0.5, 9.4), CFrame.new(lp.X, 0.55, lp.Z), Color3.fromRGB(96, 90, 116), { Material = Slate })
			local s = P("Slot_" .. n, V3(8, 0.8, 8), CFrame.lookAt(lp, lp + V3(-side, 0, 0)), Color3.fromRGB(120, 112, 140), { Material = Enum.Material.Marble })
			s.Parent = slots
			P("SlotTrim", V3(8.6, 0.25, 8.6), CFrame.new(lp.X, 1.05, lp.Z), sakura, { Material = Enum.Material.Neon, CanCollide = false })
			P("Incense", V3(0.6, 1.4, 0.6), CFrame.new(lp.X + side * 4.6, 1.5, lp.Z + 3.4), woodDark, { CanCollide = false })
			P("IncenseGlow", V3(0.5, 0.5, 0.5), CFrame.new(lp.X + side * 4.6, 2.35, lp.Z + 3.4), lanternC, { Material = Enum.Material.Neon, CanCollide = false })
		end
	end
	Instance.new("Folder", model).Name = "Placed"

	-- Plataforma do carro (tatame circular) — o carro nasce aqui, virado para a porta
	P("CarPad", V3(0.2, 18, 18), CFrame.new(0, 0.6, 6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(196, 170, 112), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Fabric })
	P("PadRing", V3(0.14, 19.4, 19.4), CFrame.new(0, 0.56, 6) * CFrame.Angles(0, 0, math.rad(90)), sakura, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, CanCollide = false })
	P("PlayerSpawn", V3(2, 1, 2), CFrame.lookAt(V3(0, 0.5, -18), V3(0, 0.5, 6)), COL.white, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	P("CarSpawn", V3(2, 2, 2), CFrame.new(0, 0.5, 6), COL.white, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })

	-- Decoração: bonsais de cerejeira no fundo, bambu na entrada, vasos de pedra
	local function bonsai(x, z)
		P("BonsaiPot", V3(3.2, 1.6, 3.2), CFrame.new(x, 1.3, z), Color3.fromRGB(40, 36, 52), { Material = Slate })
		P("BonsaiTrunk", V3(0.7, 3.4, 0.7), CFrame.new(x, 3.6, z) * CFrame.Angles(0, 0, math.rad(12)), woodDark, { Material = WoodM })
		for k, o in ipairs({ { 0, 5.6, 0, 3.2 }, { 1.4, 5.1, 0.6, 2.4 }, { -1.2, 5.0, -0.5, 2.2 } }) do
			P("BonsaiBloom", V3(o[4], o[4], o[4]), CFrame.new(x + o[1], o[2], z + o[3]), (k == 1) and Color3.fromRGB(255, 182, 226) or sakura,
				{ Shape = Enum.PartType.Ball, CanCollide = false, CastShadow = false })
		end
	end
	bonsai(-19, 25); bonsai(19, 25)
	local function bamboo(x, z)
		for k = 0, 2 do
			local h = 10 + k * 2
			P("Bamboo", V3(h, 0.7, 0.7), CFrame.new(x + (k - 1) * 0.9, 0.5 + h / 2, z + (k % 2) * 0.8) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(90, 160, 90), { Shape = Enum.PartType.Cylinder, CanCollide = false })
		end
	end
	bamboo(-20.5, -25); bamboo(20.5, -25)
	P("Bench", V3(8, 1, 2.6), CFrame.new(-17, 2.2, -12), Color3.fromRGB(150, 98, 70), { Material = Enum.Material.WoodPlanks })
	P("BenchLegs", V3(7, 1.5, 2), CFrame.new(-17, 1.1, -12), woodDark)

	-- Título (nome do dono + renda/s) visível de longe; o FarmService atualiza o "Label"
	local bb = Instance.new("BillboardGui")
	bb.Name = "Title"; bb.Size = UDim2.fromOffset(320, 90); bb.StudsOffsetWorldSpace = V3(0, H + 12, 0); bb.MaxDistance = 260
	bb.Adornee = base; bb.Parent = base
	local l = Instance.new("TextLabel")
	l.Name = "Label"; l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 1); l.Font = Enum.Font.FredokaOne; l.TextSize = 28
	l.TextColor3 = COL.white; l.Text = "Free Garage"
	local s = Instance.new("UIStroke"); s.Thickness = 3; s.Parent = l
	l.Parent = bb

	model.Parent = folder
end

-- ===================================================================== LOBBY (Beta 1.2)
-- Ilha flutuante separada da pista. Terreno: blocos (FillBlock) — rápido e com visual "ilha no céu".
function WorldBuilder.BuildLobbyTerrain()
	local L = Config.Lobby
	local O = L.Origin
	local px, pz = L.HalfX * 2, L.HalfZ * 2
	local rim = L.RimWidth * 2
	Terrain:FillBlock(CFrame.new(O.X, O.Y - 6, O.Z), V3(px + rim, 12, pz + rim), Enum.Material.Grass)
	Terrain:FillBlock(CFrame.new(O.X, O.Y - 6, O.Z), V3(px, 12, pz), Enum.Material.Concrete)
	Terrain:FillBlock(CFrame.new(O.X, O.Y - 30, O.Z), V3(px + rim - 24, 36, pz + rim - 24), Enum.Material.Rock)
	Terrain:FillBlock(CFrame.new(O.X, O.Y - 70, O.Z), V3((px + rim) * 0.7, 44, (pz + rim) * 0.7), Enum.Material.Rock)
	Terrain:FillBlock(CFrame.new(O.X, O.Y - 110, O.Z), V3((px + rim) * 0.38, 40, (pz + rim) * 0.38), Enum.Material.Rock)
	return "terreno do lobby (ilha flutuante) ok"
end

local function clearChildren(folder, keepFolders)
	for _, c in ipairs(folder:GetChildren()) do
		if not (keepFolders and c:IsA("Folder")) then c:Destroy() end
	end
end
local function ensureMap()
	local map = workspace:FindFirstChild("Map")
	if not map then map = Instance.new("Folder"); map.Name = "Map"; map.Parent = workspace end
	for _, n in ipairs({ "Drivable", "Props", "Plots", "Structures", "AnimeSpawns", "BoostPads", "EggNodes", "EggShrines" }) do
		if not map:FindFirstChild(n) then local f = Instance.new("Folder"); f.Name = n; f.Parent = map end
	end
	return map
end

-- [Beta 1.2 — GUARDADO] Lobby antigo: 8 garagens, avenida, portal (tag "RacePortal"), santuário, arco e spawn.
-- Substituído pelo lobby "Sakura Night" (WorldBuilder.BuildLobby, Beta 1.4). Mantido para quem quiser voltar.
function WorldBuilder.BuildLobbyBeta12()
	local map = ensureMap()
	local L = Config.Lobby
	local O = L.Origin
	clearChildren(map.Plots)
	for _, n in ipairs({ "Lobby" }) do local f = map.Structures:FindFirstChild(n); if f then f:Destroy() end end
	local hub = map.EggShrines:FindFirstChild("hub"); if hub then hub:Destroy() end
	local lob = Instance.new("Folder"); lob.Name = "Lobby"; lob.Parent = map.Structures

	for i = 1, 8 do buildGarage(i, map.Plots) end

	-- avenida central com faixas neon apontando para o portal
	part(lob, { Name = "Avenue", Size = V3(40, 0.2, L.HalfZ * 2 - 20), CFrame = CFrame.new(O + V3(0, 0.1, 0)), Color = Color3.fromRGB(52, 56, 76), Material = Enum.Material.Asphalt })
	for _, sx in ipairs({ -1, 1 }) do
		part(lob, { Name = "AvenueNeon", Size = V3(0.8, 0.25, L.HalfZ * 2 - 20), CFrame = CFrame.new(O + V3(sx * 19.6, 0.15, 0)), Color = COL.cyan, Material = Enum.Material.Neon, CanCollide = false })
	end
	for k = 0, 7 do
		local z = O.Z + L.HalfZ - 40 - k * 40
		part(lob, { Name = "Chevron", Size = V3(10, 0.25, 3), CFrame = CFrame.new(O.X, O.Y + 0.2, z) * CFrame.Angles(0, math.rad(45), 0) * CFrame.new(-3, 0, 0), Color = COL.yellow, Material = Enum.Material.Neon, CanCollide = false })
		part(lob, { Name = "Chevron", Size = V3(10, 0.25, 3), CFrame = CFrame.new(O.X, O.Y + 0.2, z) * CFrame.Angles(0, math.rad(-45), 0) * CFrame.new(3, 0, 0), Color = COL.yellow, Material = Enum.Material.Neon, CanCollide = false })
	end

	-- PORTAL DE CORRIDA: anel neon + plataforma (a plataforma é a peça oficial com tag "RacePortal")
	local pz = O.Z + L.PortalOffsetZ
	local pc = CFrame.lookAt(V3(O.X, O.Y, pz), V3(O.X, O.Y, pz - 1))
	local pad = part(lob, { Name = "RacePortalPad", Size = V3(36, 0.6, 36), CFrame = pc * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(30, 34, 52), Material = Enum.Material.DiamondPlate })
	CollectionService:AddTag(pad, "RacePortal")
	part(lob, { Name = "PadRing", Size = V3(0.3, 38, 38), CFrame = pc * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = COL.yellow, Material = Enum.Material.Neon, CanCollide = false })
	local segs = 20
	for k = 0, segs - 1 do -- arco circular feito de blocos
		local a = k / segs * math.pi * 2
		local r = 17
		local seg = part(lob, { Name = "PortalRing", Size = V3(3.2, 5.6, 3.2), CFrame = pc * CFrame.new(math.cos(a) * r, 19 + math.sin(a) * r, 0) * CFrame.Angles(0, 0, a),
			Color = (k % 2 == 0) and COL.cyan or COL.magenta, Material = Enum.Material.Neon, CanCollide = false })
	end
	local veil = part(lob, { Name = "PortalVeil", Size = V3(0.4, 31, 31), CFrame = pc * CFrame.new(0, 19, 0) * CFrame.Angles(0, math.rad(90), 0), Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.ForceField, Transparency = 0.1, CanCollide = false, CanQuery = false })
	WorldBuilder.EnergyAura(pad, COL.cyan, 20, 12, 1.8)
	local l = Instance.new("PointLight"); l.Color = COL.cyan; l.Range = 50; l.Brightness = 2.5; l.Parent = veil
	local sign = part(lob, { Name = "PortalSign", Size = V3(30, 7, 0.6), CFrame = pc * CFrame.new(0, 41, 0) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(16, 18, 30), CanCollide = false })
	signGui(sign, Enum.NormalId.Front, "🏁 START RACE", "drive or walk in!", COL.yellow)

	-- arco com o nome do jogo (no fundo do lobby)
	arch(lob, V3(O.X, O.Y, O.Z + L.ArchOffsetZ), V3(0, 0, -1), 30, "DRIVE A CAR FOR ANIME", "Lobby • Garages • Eggs", COL.cyan)
	-- santuário inicial (ovo do bioma 1)
	local hubShrines = Instance.new("Folder"); hubShrines.Name = "hub"; hubShrines.Parent = map.EggShrines
	local so = L.ShrineOffset
	WorldBuilder.BuildShrine(hubShrines, O + so, V3(-math.sign(so.X ~= 0 and so.X or 1), 0, 0), biomes[1])
	-- árvores azuis e postes de luz na borda do pátio
	local rng = Random.new(4242)
	for k = 1, 28 do
		local side = (k % 2 == 0) and 1 or -1
		local alongZ = (k % 4 < 2)
		local p
		if alongZ then p = V3(O.X + side * (L.HalfX + L.RimWidth * 0.5), O.Y, O.Z + rng:NextNumber(-L.HalfZ, L.HalfZ))
		else p = V3(O.X + rng:NextNumber(-L.HalfX, L.HalfX), O.Y, O.Z + side * (L.HalfZ + L.RimWidth * 0.5)) end
		WorldBuilder.PROP.bluetree(lob, p, biomes[1], rng)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 5 do
			local p = V3(O.X + sx * 32, O.Y, O.Z + L.HalfZ - 40 - k * 80)
			part(lob, { Name = "LampPole", Size = V3(0.8, 14, 0.8), CFrame = CFrame.new(p + V3(0, 7, 0)), Color = Color3.fromRGB(50, 52, 70) })
			local head = part(lob, { Name = "LampHead", Size = V3(3, 1, 3), CFrame = CFrame.new(p + V3(0, 14.3, 0)), Color = COL.warm, Material = Enum.Material.Neon, CanCollide = false })
			local pl = Instance.new("PointLight"); pl.Color = COL.warm; pl.Range = 28; pl.Brightness = 1.4; pl.Parent = head
		end
	end

	-- spawn no centro do lobby
	local bp = workspace:FindFirstChild("Baseplate"); if bp then bp:Destroy() end
	local sp = workspace:FindFirstChildOfClass("SpawnLocation")
	if sp then
		for _, c in ipairs(sp:GetChildren()) do if c:IsA("Decal") then c:Destroy() end end
		sp.Anchored = true; sp.Neutral = true; sp.Transparency = 1; sp.CanCollide = false; sp.CanQuery = false
		sp.Size = V3(12, 1, 12); sp.Position = O + V3(0, 1, 0)
	end
	return ("lobby ok em %s (%d instâncias)"):format(tostring(O), #lob:GetDescendants() + #map.Plots:GetDescendants())
end

-- ===================================================================== LOBBY "SAKURA NIGHT" (Beta 1.4)
--[[
	LAYOUT (relativo a Config.Lobby.Origin; -Z = norte = lado da pista)

	        [Pagode]        +---- RACE GATE (palco +3, torii, portal "RacePortal") ----+        [Pagode]
	                        +---------------------- escadas ----------------------------+
	   GARAGENS 1-4   | lago koi |   caminho norte (lanternas)   | lago koi |   GARAGENS 5-8
	   (x = -135)     | faixa    |   (*) PRAÇA SAKURA (spawn)     | faixa    |   (x = +135)
	                  | x=-80    |   caminho sul (lanternas)     | x=+80    |
	   HALL OF HEROES (avatar + top 4)      ARCO DO JOGO      CAR SHOWROOM (3 giratórios)
	                       [paredes invisíveis na borda da ilha — Config.Lobby.Zones.Barrier]

	HIERARQUIA: Map.Structures.Lobby/{Plaza, RaceGate, GarageRow, Showroom, HallOfHeroes, Paths, Decor, Barrier}
	TAGS (o cliente usa): RacePortal (palco), ShowroomPad (Slot 1-3), ShowcasePad (Slot 0 = avatar, 1-4),
	  CarShopKiosk, InventoryKiosk, LobbyLantern (balança), KoiFish (nada em círculo; atributos Center/Radius/Speed).
	Tudo é ancorado; decoração alta sem colisão onde não precisa. Poucas PointLights (celular).
]]
local LT = Config.Lobby.Theme
local function disc(parent, name, radius, height, center, color, mat, o)
	local props = { Name = name, Shape = Enum.PartType.Cylinder, Size = V3(height, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = mat or Enum.Material.SmoothPlastic }
	if o then for k, v in pairs(o) do props[k] = v end end
	return part(parent, props)
end
local function folderIn(parent, name) local f = Instance.new("Folder"); f.Name = name; f.Parent = parent; return f end

-- Beta 1.4b: CEREJEIRA EM CAMADAS (pedido do dono): tronco curvo em 3 segmentos, galhos tortos e copa em 2-3 andares
-- de "nuvens" achatadas (disco + bolas na borda), cachos pendurados e pétalas caindo.
local function segment(m, p0, p1, w, color)
	return part(m, { Name = "Wood", Size = V3(w, w, (p1 - p0).Magnitude + w * 0.6), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Color = color, Material = Enum.Material.Wood })
end
-- Beta 1.4c (referência do dono): TUFO low-poly = blocos achatados e inclinados com textura salpicada (Grass)
-- + franja serrilhada de cunhas apontando para baixo nas bordas.
local function clump(m, center, w, rng, cols)
	local cf = CFrame.new(center) * CFrame.Angles(math.rad(rng:NextNumber(-9, 9)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-9, 9)))
	local main = part(m, { Name = "Canopy", Size = V3(w, w * 0.3, w * 0.78), CFrame = cf, Color = cols[1], Material = Enum.Material.Fabric, CanCollide = false, CastShadow = false })
	part(m, { Name = "CanopyTop", Size = V3(w * 0.72, w * 0.26, w * 0.56), CFrame = cf * CFrame.new(rng:NextNumber(-0.08, 0.08) * w, w * 0.2, rng:NextNumber(-0.08, 0.08) * w) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
		Color = cols[2], Material = Enum.Material.Fabric, CanCollide = false, CastShadow = false })
	local hx, hz = w * 0.5, w * 0.39
	local n = 10
	for k = 0, n - 1 do -- franja: cunhas penduradas no contorno do bloco principal
		local t = k / n
		local lx, lz, yaw
		if t < 0.25 then lx, lz, yaw = -hx + t * 4 * w, -hz, 0
		elseif t < 0.5 then lx, lz, yaw = hx, -hz + (t - 0.25) * 4 * hz * 2, math.pi / 2
		elseif t < 0.75 then lx, lz, yaw = hx - (t - 0.5) * 4 * w, hz, math.pi
		else lx, lz, yaw = -hx, hz - (t - 0.75) * 4 * hz * 2, -math.pi / 2 end
		local wd = Instance.new("WedgePart")
		wd.Name = "Fringe"; wd.Anchored = true; wd.CanCollide = false; wd.CanQuery = false; wd.CastShadow = false
		wd.Material = Enum.Material.Fabric; wd.Color = cols[rng:NextInteger(1, #cols)]
		local h = w * rng:NextNumber(0.12, 0.22)
		wd.Size = V3(w * rng:NextNumber(0.1, 0.16), h, w * 0.07)
		-- cunha com a ponta para baixo e a face reta para fora
		wd.CFrame = main.CFrame * CFrame.new(lx, -w * 0.15 - h / 2 + 0.05, lz) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(180), 0, 0)
		wd.Parent = m
	end
	return main
end
local function sakuraTree(parent, base, s, rng, petals)
	local m = Instance.new("Model"); m.Name = "SakuraTree"
	local bark = Color3.fromRGB(64, 38, 70)
	local cols = { Color3.fromRGB(236, 160, 240), Color3.fromRGB(250, 190, 246), Color3.fromRGB(222, 140, 232), Color3.fromRGB(255, 206, 250) }
	-- tronco reto com "anel" na base (como na referência) e forquilha
	part(m, { Name = "TrunkBase", Size = V3(2.1 * s, 3.2 * s, 2.1 * s), CFrame = CFrame.new(base + V3(0, 1.6 * s, 0)), Color = Color3.fromRGB(54, 32, 60), Material = Enum.Material.Wood })
	local fork = base + V3(rng:NextNumber(-0.3, 0.3) * s, 9 * s, rng:NextNumber(-0.3, 0.3) * s)
	segment(m, base + V3(0, 3 * s, 0), fork, 1.5 * s, bark)
	local first
	local nb = 3
	local a0 = rng:NextNumber(0, math.pi * 2)
	for k = 1, nb do
		local a = a0 + k / nb * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
		local dir = V3(math.cos(a), 0, math.sin(a))
		local tip = fork + dir * rng:NextNumber(5, 7.5) * s + V3(0, rng:NextNumber(3, 6) * s, 0)
		segment(m, fork, tip, 0.85 * s, bark)
		local c = clump(m, tip + V3(0, 1.2 * s, 0), rng:NextNumber(7, 9.5) * s, rng, cols)
		first = first or c
	end
	-- tufos de cima e do meio, desencontrados (copa assimétrica)
	for k = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = fork + V3(math.cos(a) * rng:NextNumber(1, 4) * s, rng:NextNumber(6.5, 9.5) * s, math.sin(a) * rng:NextNumber(1, 4) * s)
		clump(m, p, rng:NextNumber(7.5, 10) * s, rng, cols)
	end
	if petals and first then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Petals"; pe.Color = ColorSequence.new(cols[4], cols[1]); pe.LightEmission = 0.3
		pe.Size = NumberSequence.new(0.5 * s, 0.25 * s); pe.Rate = 4 * s; pe.Lifetime = NumberRange.new(6, 9)
		pe.Speed = NumberRange.new(1, 3); pe.SpreadAngle = Vector2.new(180, 180); pe.Acceleration = V3(0.8, -1.4, 0.4)
		pe.Drag = 0.6; pe.RotSpeed = NumberRange.new(-60, 60); pe.Rotation = NumberRange.new(0, 360)
		pe.Parent = first
	end
	m.Parent = parent
	return m
end

-- cerejeira GIGANTE da praça: a mesma árvore em camadas em escala 2.4 + brilhos e luz rosa
local function giantSakura(parent, base, rng)
	local m = sakuraTree(parent, base, 2.4, rng, true)
	m.Name = "GiantSakura"
	local cf, size = m:GetBoundingBox()
	for _ = 1, 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(4, size.X * 0.4)
		part(m, { Name = "Glow", Shape = Enum.PartType.Ball, Size = V3(1.4, 1.4, 1.4), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 220, 245),
			CanCollide = false, CanQuery = false, CastShadow = false, CFrame = CFrame.new(cf.Position + V3(math.cos(a) * r, rng:NextNumber(-2, size.Y * 0.3), math.sin(a) * r)) })
	end
	local canopy = m:FindFirstChild("Canopy")
	if canopy then
		local pe = canopy:FindFirstChild("Petals"); if pe then pe.Rate = 14 end
		local l = Instance.new("PointLight"); l.Color = LT.Sakura; l.Range = 45; l.Brightness = 1.2; l.Parent = canopy
	end
	return m
end

local function stoneLantern(parent, pos, light)
	local m = Instance.new("Model"); m.Name = "StoneLantern"
	local st = LT.Stone
	part(m, { Name = "Base", Size = V3(3, 1, 3), CFrame = CFrame.new(pos + V3(0, 0.5, 0)), Color = st, Material = Enum.Material.Slate })
	part(m, { Name = "Post", Size = V3(1.2, 4, 1.2), CFrame = CFrame.new(pos + V3(0, 3, 0)), Color = st, Material = Enum.Material.Slate })
	part(m, { Name = "Shelf", Size = V3(2.8, 0.6, 2.8), CFrame = CFrame.new(pos + V3(0, 5.3, 0)), Color = st, Material = Enum.Material.Slate })
	local fire = part(m, { Name = "Firebox", Size = V3(2, 2, 2), CFrame = CFrame.new(pos + V3(0, 6.6, 0)), Color = Color3.fromRGB(255, 160, 80), Material = Enum.Material.Neon, CanCollide = false })
	part(m, { Name = "Roof", Size = V3(3.8, 0.8, 3.8), CFrame = CFrame.new(pos + V3(0, 8, 0)), Color = st, Material = Enum.Material.Slate })
	part(m, { Name = "Cap", Size = V3(1, 0.9, 1), CFrame = CFrame.new(pos + V3(0, 8.8, 0)), Color = st, Material = Enum.Material.Slate })
	if light then pointLight(fire, LT.Lantern, 20, 1.2) end
	m.Parent = parent
	return m
end

local function paperLantern(parent, pos, light)
	local m = Instance.new("Model"); m.Name = "PaperLantern"
	local body = disc(m, "Body", 1.4, 2.8, pos, Color3.fromRGB(255, 150, 70), Enum.Material.Neon, { CanCollide = false, CanQuery = false, CastShadow = false })
	disc(m, "CapTop", 1.05, 0.4, pos + V3(0, 1.55, 0), Color3.fromRGB(150, 40, 52), nil, { CanCollide = false, CanQuery = false })
	disc(m, "CapBottom", 1.05, 0.4, pos - V3(0, 1.55, 0), Color3.fromRGB(150, 40, 52), nil, { CanCollide = false, CanQuery = false })
	m.PrimaryPart = body
	if light then pointLight(body, LT.Lantern, 18, 1) end
	-- Beta 1.8: posição "de casa" gravada + streaming atômico. Sem isso, com StreamingEnabled o cliente lia o pivô
	-- antes das peças chegarem (0,0,0) e a animação juntava TODAS as lanternas na largada ("bola vermelha" na pista).
	m:SetAttribute("Home", m:GetPivot())
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	CollectionService:AddTag(m, "LobbyLantern")
	return m
end

local function torii(parent, cf, span, height)
	local red, black = LT.Torii, Color3.fromRGB(28, 22, 34)
	for _, s in ipairs({ -1, 1 }) do
		part(parent, { Name = "ToriiPillar", Shape = Enum.PartType.Cylinder, Size = V3(height, 2.8, 2.8), CFrame = cf * CFrame.new(s * span, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = red, Material = Enum.Material.Wood })
		part(parent, { Name = "ToriiFoot", Size = V3(3.8, 1.6, 3.8), CFrame = cf * CFrame.new(s * span, 0.8, 0), Color = black })
		part(parent, { Name = "KasagiTip", Size = V3(5, 1.8, 3.4), CFrame = cf * CFrame.new(s * (span + 8), height + 1.4, 0) * CFrame.Angles(0, 0, math.rad(s * 12)), Color = black, CanCollide = false })
	end
	part(parent, { Name = "Nuki", Size = V3(span * 2 + 7, 1.6, 1.6), CFrame = cf * CFrame.new(0, height - 7, 0), Color = red, Material = Enum.Material.Wood, CanCollide = false })
	part(parent, { Name = "KasagiRed", Size = V3(span * 2 + 12, 1.6, 3), CFrame = cf * CFrame.new(0, height - 0.8, 0), Color = red, Material = Enum.Material.Wood, CanCollide = false })
	part(parent, { Name = "Kasagi", Size = V3(span * 2 + 13, 2.2, 3.4), CFrame = cf * CFrame.new(0, height + 1, 0), Color = black, CanCollide = false })
	local plaque = part(parent, { Name = "Plaque", Size = V3(12, 5, 0.6), CFrame = cf * CFrame.new(0, height - 3.9, -1.1), Color = black, CanCollide = false })
	return plaque
end

local function pagoda(parent, base, tiers)
	local m = Instance.new("Model"); m.Name = "Pagoda"
	local wood, roof = Color3.fromRGB(122, 36, 50), Color3.fromRGB(34, 30, 54)
	part(m, { Name = "Plinth", Size = V3(32, 3, 32), CFrame = CFrame.new(base + V3(0, 1.5, 0)), Color = LT.Stone, Material = Enum.Material.Slate })
	local y, w = 3, 20
	for t = 1, tiers do
		local h = 9 - t
		part(m, { Name = "Tier", Size = V3(w, h, w), CFrame = CFrame.new(base + V3(0, y + h / 2, 0)), Color = wood, Material = Enum.Material.Wood })
		local win = part(m, { Name = "Windows", Size = V3(w + 0.2, 1.4, w + 0.2), CFrame = CFrame.new(base + V3(0, y + h * 0.5, 0)), Color = LT.Lantern, Material = Enum.Material.Neon, CanCollide = false })
		if t == 1 then pointLight(win, LT.Lantern, 30, 1.2) end
		y += h
		part(m, { Name = "RoofTrim", Size = V3(w + 10.4, 0.5, w + 10.4), CFrame = CFrame.new(base + V3(0, y + 0.1, 0)), Color = LT.Torii })
		part(m, { Name = "Roof", Size = V3(w + 10, 1.6, w + 10), CFrame = CFrame.new(base + V3(0, y + 1.1, 0)), Color = roof, Material = Enum.Material.Slate })
		for _, cx in ipairs({ -1, 1 }) do
			for _, cz in ipairs({ -1, 1 }) do
				part(m, { Name = "CornerLantern", Size = V3(1.3, 2, 1.3), CFrame = CFrame.new(base + V3(cx * (w / 2 + 4.4), y - 1.2, cz * (w / 2 + 4.4))), Color = LT.Lantern, Material = Enum.Material.Neon, CanCollide = false })
			end
		end
		y += 1.9
		w -= 4
	end
	part(m, { Name = "Spire", Size = V3(1, 12, 1), CFrame = CFrame.new(base + V3(0, y + 6, 0)), Color = LT.Gold, Material = Enum.Material.Metal })
	part(m, { Name = "SpireOrb", Shape = Enum.PartType.Ball, Size = V3(2.4, 2.4, 2.4), CFrame = CFrame.new(base + V3(0, y + 12.5, 0)), Color = LT.Gold, Material = Enum.Material.Neon, CanCollide = false })
	m.Parent = parent
	return m
end

-- placa de zona em dois postes; facing = para onde a frente (o texto) aponta
local function zoneSign(parent, pos, facing, title, sub, color, width, height)
	local cf = CFrame.lookAt(pos, pos + facing)
	width, height = width or 24, height or 12
	for _, s in ipairs({ -1, 1 }) do
		part(parent, { Name = "SignPost", Size = V3(1, height, 1), CFrame = cf * CFrame.new(s * (width / 2 - 1), height / 2, 0), Color = Color3.fromRGB(40, 32, 60) })
	end
	local board = part(parent, { Name = "ZoneSign", Size = V3(width, 6, 0.6), CFrame = cf * CFrame.new(0, height, 0), Color = Color3.fromRGB(22, 16, 38), CanCollide = false })
	part(parent, { Name = "ZoneSignGlow", Size = V3(width + 0.8, 6.8, 0.4), CFrame = cf * CFrame.new(0, height, 0.25), Color = color, Material = Enum.Material.Neon, CanCollide = false })
	signGui(board, Enum.NormalId.Front, title, sub, color)
	return board
end

-- piso de zona com borda neon (center = no chão)
local function zoneFloor(parent, name, center, size, color, edge, mat)
	local top = part(parent, { Name = name, Size = size, CFrame = CFrame.new(center + V3(0, size.Y / 2, 0)), Color = color, Material = mat or Enum.Material.Slate })
	local y = size.Y + 0.1
	for _, s in ipairs({ -1, 1 }) do
		part(parent, { Name = name .. "Edge", Size = V3(size.X + 0.8, 0.3, 0.8), CFrame = CFrame.new(center + V3(0, y, s * size.Z / 2)), Color = edge, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		part(parent, { Name = name .. "Edge", Size = V3(0.8, 0.3, size.Z + 0.8), CFrame = CFrame.new(center + V3(s * size.X / 2, y, 0)), Color = edge, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
	end
	return top
end

-- degraus para subir em plataformas altas (zEdge = borda da plataforma; dir = lado para onde os degraus descem)
local function steps(parent, center, width, topY, zEdge, dir)
	local n = math.max(1, math.ceil(topY / 0.9))
	for k = 1, n do
		local h = topY * (n - k + 1) / (n + 1)
		part(parent, { Name = "Step", Size = V3(width, h, 2.6), CFrame = CFrame.new(center.X, center.Y + h / 2, zEdge + dir * (k - 0.5) * 2.6), Color = LT.Stone, Material = Enum.Material.Slate })
	end
end

-- Lobby "Sakura Night". Idempotente: refaz Map.Structures.Lobby e as 8 garagens (Map.Plots). Não mexe no terreno.
function WorldBuilder.BuildLobby()
	local map = ensureMap()
	local L, Z = Config.Lobby, Config.Lobby.Zones
	local O = L.Origin
	-- o terreno do lobby é DESENHADO ~2 studs acima do valor escrito (meio voxel): mede o chão real e apoia tudo nele
	local gy = (ground(O.X, O.Z))
	if gy < O.Y - 10 or gy > O.Y + 10 then gy = O.Y end
	local function at(x, y, z) return V3(O.X + x, gy + y, O.Z + z) end
	clearChildren(map.Plots)
	local oldLobby = map.Structures:FindFirstChild("Lobby"); if oldLobby then oldLobby:Destroy() end
	local hub = map.EggShrines:FindFirstChild("hub"); if hub then hub:Destroy() end
	local lob = folderIn(map.Structures, "Lobby")
	local fPlaza, fRace, fGar = folderIn(lob, "Plaza"), folderIn(lob, "RaceGate"), folderIn(lob, "GarageRow")
	local fShow, fHero, fPath = folderIn(lob, "Showroom"), folderIn(lob, "HallOfHeroes"), folderIn(lob, "Paths")
	local fDecor, fBar = folderIn(lob, "Decor"), folderIn(lob, "Barrier")
	local rng = Random.new(1404)

	-- ---------------- garagens (mesmo contrato Plot_N do FarmService)
	for i = 1, 8 do buildGarage(i, map.Plots) end

	-- ---------------- PRAÇA SAKURA (spawn) — anéis concêntricos + cerejeira gigante
	local R = Z.PlazaRadius
	disc(fPlaza, "PlazaBase", R, 0.5, at(0, 0.25, 0), LT.Plaza, Enum.Material.Slate)
	disc(fPlaza, "PlazaRingNeon", R - 2.5, 0.56, at(0, 0.25, 0), LT.Sakura, Enum.Material.Neon)
	disc(fPlaza, "PlazaStone", R - 3.5, 0.6, at(0, 0.25, 0), Color3.fromRGB(72, 62, 108), Enum.Material.Slate)
	disc(fPlaza, "PlazaInnerNeon", 31, 0.62, at(0, 0.25, 0), LT.Lantern, Enum.Material.Neon)
	disc(fPlaza, "PlazaInner", 30, 0.64, at(0, 0.25, 0), Color3.fromRGB(92, 78, 132), Enum.Material.Slate)
	disc(fPlaza, "PlazaCenter", 14, 0.68, at(0, 0.25, 0), Color3.fromRGB(58, 46, 88), Enum.Material.Slate)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		part(fPlaza, { Name = "Spoke", Size = V3(0.6, 0.2, 16), CFrame = CFrame.new(at(math.cos(a) * 22, 0.62, math.sin(a) * 22)) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = LT.Sakura, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
	end
	for k = 0, 7 do -- bancos em octógono em volta da árvore
		local a = (k + 0.5) / 8 * math.pi * 2
		local p = at(math.cos(a) * 12, 0, math.sin(a) * 12)
		local cf = CFrame.lookAt(p, p + V3(math.cos(a), 0, math.sin(a)))
		part(fPlaza, { Name = "Bench", Size = V3(7, 0.8, 2.2), CFrame = cf * CFrame.new(0, 1.6, 0), Color = Color3.fromRGB(120, 76, 60), Material = Enum.Material.WoodPlanks })
		for _, s in ipairs({ -1, 1 }) do
			part(fPlaza, { Name = "BenchLeg", Size = V3(0.8, 1.2, 1.8), CFrame = cf * CFrame.new(s * 2.8, 0.6, 0), Color = LT.Stone, Material = Enum.Material.Slate })
		end
	end
	giantSakura(fPlaza, at(0, 0.6, 0), rng)
	for k = 0, 17 do -- lanternas flutuantes (6 com luz)
		local a = k / 18 * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local r = rng:NextNumber(30, 46)
		paperLantern(fPlaza, at(math.cos(a) * r, rng:NextNumber(13, 24), math.sin(a) * r), k % 3 == 0)
	end

	-- ---------------- CAMINHOS (pedra) + lanternas de pedra
	local stage = Z.RaceStage
	local stageFront = stage.Z + Z.RaceStageSize.Z / 2         -- borda sul do palco (relativa)
	local northLen = (-R) - (stageFront + 8)
	part(fPath, { Name = "PathNorth", Size = V3(20, 0.4, northLen), CFrame = CFrame.new(at(0, 0.2, -R - northLen / 2 + 0.5)), Color = LT.Path, Material = Enum.Material.Slate })
	part(fPath, { Name = "PathSouth", Size = V3(20, 0.4, 150), CFrame = CFrame.new(at(0, 0.2, R + 74)), Color = LT.Path, Material = Enum.Material.Slate })
	local ewLen = Z.GarageLaneX - 7 - R + 4
	for _, s in ipairs({ -1, 1 }) do
		part(fPath, { Name = "PathEastWest", Size = V3(ewLen, 0.4, 16), CFrame = CFrame.new(at(s * (R - 2 + ewLen / 2), 0.2, 0)), Color = LT.Path, Material = Enum.Material.Slate })
		part(fPath, { Name = "PathToHall", Size = V3(80, 0.4, 16), CFrame = CFrame.new(at(s * 50, 0.2, 180)), Color = LT.Path, Material = Enum.Material.Slate })
		for _, z in ipairs({ -66, -96, -126 }) do stoneLantern(fPath, at(s * 14, 0.4, z), z == -96) end
		for _, z in ipairs({ 72, 112, 152 }) do stoneLantern(fPath, at(s * 14, 0.4, z), z == 112) end
	end

	-- ---------------- FAIXAS DAS GARAGENS (ciano) + placas
	for _, s in ipairs({ -1, 1 }) do
		local x = s * Z.GarageLaneX
		part(fGar, { Name = "GarageLane", Size = V3(14, 0.35, 290), CFrame = CFrame.new(at(x, 0.18, 0)), Color = Color3.fromRGB(46, 40, 76), Material = Enum.Material.Slate })
		part(fGar, { Name = "GarageLaneNeon", Size = V3(0.7, 0.4, 290), CFrame = CFrame.new(at(x - s * 7, 0.22, 0)), Color = LT.Garage, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		zoneSign(fGar, at(s * 62, 0, -14), V3(-s, 0, 0), s < 0 and "🔧 GARAGES 1-4" or "🔧 GARAGES 5-8", "your characters earn $ here", LT.Garage, 22, 11)
	end

	-- ---------------- RACE GATE (palco elevado, torii, portal) — a peça com tag "RacePortal" inicia a corrida
	local sY = Z.RaceStageSize.Y
	zoneFloor(fRace, "RaceStage", at(stage.X, 0, stage.Z), Z.RaceStageSize, Color3.fromRGB(46, 34, 66), LT.Race, Enum.Material.Marble)
	steps(fRace, at(0, 0, 0), 34, sY, O.Z + stageFront, 1)
	local pz = L.PortalOffsetZ
	local pc = CFrame.lookAt(at(0, sY, pz), at(0, sY, pz - 1))
	local pad = part(fRace, { Name = "RacePortalPad", Size = V3(36, 0.6, 36), CFrame = pc * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(30, 24, 48), Material = Enum.Material.DiamondPlate })
	CollectionService:AddTag(pad, "RacePortal")
	disc(fRace, "PadRing", 19, 0.3, (pc * CFrame.new(0, 0.55, 0)).Position, LT.Race, Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		part(fRace, { Name = "PortalRing", Size = V3(3, 5, 3), CFrame = pc * CFrame.new(math.cos(a) * 17, 19 + math.sin(a) * 17, 0) * CFrame.Angles(0, 0, a),
			Color = (k % 2 == 0) and LT.Gold or LT.Sakura, Material = Enum.Material.Neon, CanCollide = false })
	end
	local veil = part(fRace, { Name = "PortalVeil", Size = V3(0.4, 31, 31), CFrame = pc * CFrame.new(0, 19, 0) * CFrame.Angles(0, math.rad(90), 0), Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(255, 150, 220), Material = Enum.Material.ForceField, Transparency = 0.1, CanCollide = false, CanQuery = false })
	if WorldBuilder.EnergyAura then WorldBuilder.EnergyAura(pad, LT.Sakura, 20, 12, 1.8) end
	pointLight(veil, LT.Sakura, 50, 2.5)
	local toriiCF = CFrame.lookAt(at(0, sY, stageFront - 9), at(0, sY, stageFront + 1))
	local plaque = torii(fRace, toriiCF, 23, 32)
	signGui(plaque, Enum.NormalId.Front, "▶ PLAY", nil, LT.Gold)
	local portalSign = part(fRace, { Name = "PortalSign", Size = V3(30, 7, 0.6), CFrame = pc * CFrame.new(0, 41, 0) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(22, 16, 38), CanCollide = false })
	signGui(portalSign, Enum.NormalId.Front, "🏁 START RACE", "walk in or press PLAY", LT.Race)
	for _, s in ipairs({ -1, 1 }) do
		local bx = s * (Z.RaceStageSize.X / 2 - 5)
		part(fRace, { Name = "BannerPole", Size = V3(1, 30, 1), CFrame = CFrame.new(at(bx, sY + 15, stage.Z)), Color = Color3.fromRGB(40, 32, 60), Material = Enum.Material.Metal })
		part(fRace, { Name = "Banner", Size = V3(0.4, 20, 7), CFrame = CFrame.new(at(bx, sY + 18, stage.Z + 4)), Color = (s < 0) and LT.Sakura or LT.Gold, Material = Enum.Material.Fabric, CanCollide = false })
		stoneLantern(fRace, at(s * 40, sY, stage.Z - 26), false)
		stoneLantern(fRace, at(s * 40, sY, stageFront - 4), false)
	end
	zoneSign(fRace, at(0, 0, stageFront + 16), V3(0, 0, 1), "🏁 RACE GATE", "grab Giant Eggs at the end of each biome!", LT.Race, 30, 10)

	-- ---------------- SALÕES (piso + parede de fundo + letreiro + balcão com prompt no cliente)
	local hall = Z.HallSize
	local function hallZone(folder, center, title, sub, color, floorColor, kioskTag, kioskTitle, kioskSub)
		zoneFloor(folder, "Floor", at(center.X, 0, center.Z), hall, floorColor, color, Enum.Material.Marble)
		local wallCF = CFrame.lookAt(at(center.X, hall.Y, center.Z + hall.Z / 2 - 3), at(center.X, hall.Y, center.Z - 10))
		part(folder, { Name = "BackWall", Size = V3(hall.X, 26, 2), CFrame = wallCF * CFrame.new(0, 13, 0), Color = Color3.fromRGB(26, 20, 44), Material = Enum.Material.Slate })
		part(folder, { Name = "BackWallNeon", Size = V3(hall.X, 0.8, 0.6), CFrame = wallCF * CFrame.new(0, 26, -1.2), Color = color, Material = Enum.Material.Neon, CanCollide = false })
		local sign = part(folder, { Name = "HallSign", Size = V3(54, 8, 0.6), CFrame = wallCF * CFrame.new(0, 22, -1.3), Color = Color3.fromRGB(22, 16, 38), CanCollide = false })
		signGui(sign, Enum.NormalId.Front, title, sub, color)
		for _, s in ipairs({ -1, 1 }) do
			part(folder, { Name = "Pillar", Size = V3(3, 26, 3), CFrame = wallCF * CFrame.new(s * (hall.X / 2 - 1.5), 13, -2.5), Color = Color3.fromRGB(40, 32, 62) })
			part(folder, { Name = "PillarNeon", Size = V3(3.2, 26, 0.4), CFrame = wallCF * CFrame.new(s * (hall.X / 2 - 1.5), 13, -4.1), Color = color, Material = Enum.Material.Neon, CanCollide = false })
		end
		-- balcão na LATERAL da frente (não tapa os pódios/giratórios), voltado para quem chega pelo caminho do sul
		local kx = center.X + ((center.X > 0) and -1 or 1) * (hall.X / 2 - 9)
		local kcf = CFrame.lookAt(at(kx, hall.Y, center.Z - hall.Z / 2 + 8), at(kx, hall.Y, center.Z - hall.Z / 2 - 10))
		local counter = part(folder, { Name = "Kiosk", Size = V3(12, 4, 3), CFrame = kcf * CFrame.new(0, 2, 0), Color = Color3.fromRGB(30, 24, 50) })
		part(folder, { Name = "KioskTop", Size = V3(12.4, 0.4, 3.4), CFrame = kcf * CFrame.new(0, 4.2, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false })
		local screen = part(folder, { Name = "KioskScreen", Size = V3(10, 5, 0.5), CFrame = kcf * CFrame.new(0, 7.5, 0.6), Color = Color3.fromRGB(14, 10, 26), CanCollide = false })
		signGui(screen, Enum.NormalId.Front, kioskTitle, kioskSub, color)
		CollectionService:AddTag(counter, kioskTag)
		return wallCF
	end

	-- ---------------- CAR SHOWROOM (3 giratórios: 1 = equipado no centro, 2 = próximo, 3 = carro dos sonhos)
	local sc = Z.Showroom
	hallZone(fShow, sc, "🚗 CAR SHOWROOM", "your car • next upgrade • dream car", LT.Showroom, Color3.fromRGB(30, 30, 58), "CarShopKiosk", "🛒 CAR SHOP", "buy & upgrade")
	for slot, dx in ipairs({ 0, -30, 30 }) do
		local c = at(sc.X + dx, hall.Y, sc.Z + 4)
		disc(fShow, "TurntableRing", 12, 0.5, c + V3(0, 0.25, 0), LT.Showroom, Enum.Material.Neon, { CanCollide = false })
		local tt = disc(fShow, "Turntable", 11, 0.8, c + V3(0, 0.4, 0), Color3.fromRGB(42, 42, 70), Enum.Material.DiamondPlate)
		tt:SetAttribute("Slot", slot)
		CollectionService:AddTag(tt, "ShowroomPad")
		local lamp = part(fShow, { Name = "Spot", Size = V3(3, 1, 3), CFrame = CFrame.new(c + V3(0, 22, 0)), Color = Color3.fromRGB(60, 60, 80), CanCollide = false })
		local sl = Instance.new("SpotLight"); sl.Face = Enum.NormalId.Bottom; sl.Range = 30; sl.Angle = 70; sl.Brightness = 3; sl.Color = Color3.fromRGB(220, 225, 255); sl.Parent = lamp
	end

	-- ---------------- HALL OF HEROES (pódio: avatar no centro = Slot 0 + 4 melhores personagens)
	local hc = Z.Heroes
	hallZone(fHero, hc, "⭐ HALL OF HEROES", "you & your best hatched characters", LT.Heroes, Color3.fromRGB(46, 26, 58), "InventoryKiosk", "🎒 INVENTORY", "equip your heroes")
	for _, d in ipairs({ { 0, 0, 5 }, { 1, -15, 3.5 }, { 2, 15, 3.5 }, { 3, -30, 2 }, { 4, 30, 2 } }) do -- { Slot, dx, altura }
		local slot, dx, h = d[1], d[2], d[3]
		local c = at(hc.X + dx, hall.Y, hc.Z + 8 - math.abs(dx) * 0.12)
		local p = part(fHero, { Name = "Podium", Size = V3(10, h, 10), CFrame = CFrame.new(c + V3(0, h / 2, 0)), Color = (slot == 0) and Color3.fromRGB(70, 50, 100) or Color3.fromRGB(56, 40, 82), Material = Enum.Material.Marble })
		p:SetAttribute("Slot", slot)
		CollectionService:AddTag(p, "ShowcasePad")
		part(fHero, { Name = "PodiumTrim", Size = V3(10.4, 0.3, 10.4), CFrame = CFrame.new(c + V3(0, h + 0.1, 0)), Color = (slot == 0) and LT.Gold or LT.Heroes, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		if slot <= 2 then
			local lamp = part(fHero, { Name = "Spot", Size = V3(3, 1, 3), CFrame = CFrame.new(c + V3(0, 24, 0)), Color = Color3.fromRGB(60, 50, 80), CanCollide = false })
			local sl = Instance.new("SpotLight"); sl.Face = Enum.NormalId.Bottom; sl.Range = 30; sl.Angle = 60; sl.Brightness = 3; sl.Color = Color3.fromRGB(255, 225, 245); sl.Parent = lamp
		end
	end

	-- ---------------- DECORAÇÃO: lagos koi, pagodes, cerejeiras, lua, arco do jogo
	for _, pp in ipairs(Z.Ponds) do
		local c = at(pp.X, 0, pp.Z)
		disc(fDecor, "PondRim", 17, 1, c + V3(0, 0.5, 0), LT.Stone, Enum.Material.Slate)
		disc(fDecor, "PondWater", 15, 1.1, c + V3(0, 0.5, 0), Color3.fromRGB(40, 80, 170), Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
		for k = 1, 3 do
			local fish = part(fDecor, { Name = "KoiFish", Size = V3(0.8, 0.3, 2.2), CFrame = CFrame.new(c + V3(k * 3, 1.15, 0)),
				Color = (k == 2) and Color3.new(1, 1, 1) or Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			fish:SetAttribute("Center", c + V3(0, 1.15, 0)); fish:SetAttribute("Radius", 3 + k * 3); fish:SetAttribute("Speed", 0.25 + k * 0.1)
			CollectionService:AddTag(fish, "KoiFish")
		end
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2 + 0.4
			local sz = rng:NextNumber(2.5, 4.5)
			part(fDecor, { Name = "PondRock", Shape = Enum.PartType.Ball, Size = V3(sz, sz, sz), CFrame = CFrame.new(c + V3(math.cos(a) * 17.5, 0.6, math.sin(a) * 17.5)), Color = Color3.fromRGB(88, 82, 110), Material = Enum.Material.Slate })
		end
	end
	for _, pg in ipairs(Z.Pagodas) do pagoda(fDecor, at(pg.X, 0, pg.Z), 4) end
	local treeSpots = { { -110, -205 }, { 110, -205 }, { -215, 70 }, { 215, 70 }, { -215, 135 }, { 215, 135 }, { -60, 150 }, { 60, 150 },
		{ -40, -150 }, { 40, -150 }, { -210, -95 }, { 210, -95 } }
	for k = 0, 5 do -- borda da ilha (anel de grama)
		local t = -230 + k * 92
		for _, p in ipairs({ { t, -268 }, { t, 268 }, { -268, t }, { 268, t } }) do table.insert(treeSpots, p) end
	end
	for i, p in ipairs(treeSpots) do
		sakuraTree(fDecor, at(p[1] + rng:NextNumber(-6, 6), 0, p[2] + rng:NextNumber(-6, 6)), rng:NextNumber(0.85, 1.25), rng, i % 4 == 0)
	end
	local moonPos = at(-320, 260, -430)
	part(fDecor, { Name = "Moon", Shape = Enum.PartType.Ball, Size = V3(90, 90, 90), CFrame = CFrame.new(moonPos), Color = Color3.fromRGB(236, 236, 255), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false })
	part(fDecor, { Name = "MoonHalo", Shape = Enum.PartType.Ball, Size = V3(150, 150, 150), CFrame = CFrame.new(moonPos), Color = Color3.fromRGB(180, 160, 255), Material = Enum.Material.Neon, Transparency = 0.9, CanCollide = false, CanQuery = false, CastShadow = false })
	arch(fDecor, V3(O.X, O.Y, O.Z + L.ArchOffsetZ), V3(0, 0, 1), 30, "DRIVE A CAR FOR ANIME", "🌸 Sakura Lobby", LT.Sakura)
	if Config.Features.Shrines then -- santuário inicial só se o sistema antigo estiver ligado
		local hubShrines = Instance.new("Folder"); hubShrines.Name = "hub"; hubShrines.Parent = map.EggShrines
		WorldBuilder.BuildShrine(hubShrines, O + L.ShrineOffset, V3(-1, 0, 0), biomes[1])
	end

	-- Beta 1.7: roleta SAIU do mapa (agora só na interface: Client.WheelPanel). BuildLobbyWheels fica guardada, sem chamada.

	-- ---------------- BARREIRA invisível na borda da ilha (ninguém cai do lobby)
	local B = Z.Barrier
	for _, d in ipairs({ { 0, -B, B * 2 + 8, 4 }, { 0, B, B * 2 + 8, 4 }, { -B, 0, 4, B * 2 + 8 }, { B, 0, 4, B * 2 + 8 } }) do
		part(fBar, { Name = "LobbyBarrier", Size = V3(d[3], 90, d[4]), CFrame = CFrame.new(at(d[1], 40, d[2])), Transparency = 1, CanQuery = false, CastShadow = false })
	end

	-- ---------------- spawn na praça (só antes de escolher a garagem; depois o FarmService usa o PlayerSpawn da garagem)
	local bp = workspace:FindFirstChild("Baseplate"); if bp then bp:Destroy() end
	local sp = workspace:FindFirstChildOfClass("SpawnLocation")
	if sp then
		for _, c in ipairs(sp:GetChildren()) do if c:IsA("Decal") then c:Destroy() end end
		sp.Anchored = true; sp.Neutral = true; sp.Transparency = 1; sp.CanCollide = false; sp.CanQuery = false
		sp.Size = V3(12, 1, 12); sp.Position = at(Z.SpawnOffset.X, Z.SpawnOffset.Y, Z.SpawnOffset.Z)
	end
	return ("lobby Sakura Night ok em %s (%d instâncias no lobby, %d nas garagens)"):format(tostring(O), #lob:GetDescendants(), #map.Plots:GetDescendants())
end

-- Linha de largada na pista: pórtico quadriculado + vagas do grid (uma por slot)
function WorldBuilder.BuildStartLine()
	local map = ensureMap()
	local old = map.Structures:FindFirstChild("StartLine"); if old then old:Destroy() end
	local f = Instance.new("Folder"); f.Name = "StartLine"; f.Parent = map.Structures
	local RC = Config.Race
	local z = RC.StartLineZ
	local x = W.RoadX(z)
	local gy = ground(x, z)
	local cf = CFrame.lookAt(V3(x, gy, z), V3(x, gy, z - 1))
	local span = W.RoadFlat + 8
	for _, s in ipairs({ -1, 1 }) do
		part(f, { Name = "GantryPost", Size = V3(4, 30, 4), CFrame = cf * CFrame.new(s * span, 15, 0), Color = Color3.fromRGB(40, 42, 56) })
	end
	local beam = part(f, { Name = "GantryBeam", Size = V3(span * 2 + 8, 7, 3), CFrame = cf * CFrame.new(0, 28, 0), Color = Color3.fromRGB(20, 20, 26), CanCollide = false })
	signGui(beam, Enum.NormalId.Back, "🏁 START", nil, COL.yellow)
	signGui(beam, Enum.NormalId.Front, "GOOD LUCK!", nil, COL.cyan)
	for k = 0, 11 do -- linha quadriculada no chão
		for r = 0, 1 do
			part(f, { Name = "Checker", Size = V3((W.RoadFlat * 2) / 12, 0.12, 2), CFrame = cf * CFrame.new(-W.RoadFlat + (k + 0.5) * (W.RoadFlat * 2) / 12, 0.08, (r - 0.5) * 2),
				Color = ((k + r) % 2 == 0) and Color3.new(1, 1, 1) or Color3.new(0.05, 0.05, 0.05), CanCollide = false, CanQuery = false })
		end
	end
	for k = 0, 3 do
		local light = part(f, { Name = "StartLight", Size = V3(2.6, 2.6, 1), CFrame = cf * CFrame.new(-9 + k * 6, 23, -1.4), Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon, CanCollide = false })
		light:SetAttribute("Index", k + 1)
	end
	-- vagas do grid
	for slot = 1, RC.MaxSlots do
		local cols = RC.GridColsX
		local row = math.floor((slot - 1) / #cols) + 1
		local col = (slot - 1) % #cols + 1
		local gz = RC.GridRowsZ[math.min(row, #RC.GridRowsZ)]
		local gx = W.RoadX(gz) + cols[col]
		local g = ground(gx, gz)
		-- girada 90° para o número na face Top ficar de pé para quem olha a pista (-Z)
		local box = part(f, { Name = "GridBox_" .. slot, Size = V3(15, 0.12, 11), CFrame = CFrame.new(gx, g + 0.08, gz) * CFrame.Angles(0, math.rad(-90), 0), Color = Color3.fromRGB(255, 255, 255), Transparency = 0.55, CanCollide = false, CanQuery = false })
		signGui(box, Enum.NormalId.Top, tostring(slot), nil, COL.yellow)
	end
	return "linha de largada ok"
end

-- Portões entre biomas (arco + véu neon com o tier necessário)
function WorldBuilder.BuildGates()
	local map = ensureMap()
	local old = map.Structures:FindFirstChild("Gates"); if old then old:Destroy() end
	local f = Instance.new("Folder"); f.Name = "Gates"; f.Parent = map.Structures
	for i, b in ipairs(biomes) do
		if i >= 2 then
			local z, x = b.ZStart, W.RoadX(b.ZStart)
			local fwd = roadForward(z)
			arch(f, V3(x, 0, z), fwd, W.RoadFlat + 8, b.Emoji .. " " .. b.Name:upper(), "Requires a Tier " .. b.Tier .. " car", b.Color)
			local gy = ground(x, z)
			part(f, { Name = "Portal", Size = V3((W.RoadFlat + 8) * 2 - 3, 36, 0.6), CFrame = CFrame.lookAt(V3(x, gy + 17, z), V3(x, gy + 17, z) + fwd),
				Color = b.Color, Material = Enum.Material.Neon, Transparency = 0.72, CanCollide = false, CanQuery = false, CanTouch = false })
		end
	end
	return "portões ok"
end

-- BuildMap (Beta 1.2): NÃO apaga mais o mapa inteiro. Remove peças soltas antigas do hub e reconstrói
-- lobby, linha de largada e portões. Props/obstáculos de cada bioma continuam em WorldBuilder.BuildBiome(i).
function WorldBuilder.BuildMap()
	local map = ensureMap()
	clearChildren(map.Structures, true) -- peças soltas da versão antiga (arco/portões do hub)
	local r = { WorldBuilder.BuildLobby(), WorldBuilder.BuildStartLine(), WorldBuilder.BuildGates() }
	return table.concat(r, " | ")
end

-- ===================================================================== PROPS (decoração)
local PROP = {}
WorldBuilder.PROP = PROP -- exportado: o lobby (definido acima) usa as decorações
local function newModel(name) local m = Instance.new("Model"); m.Name = name; return m end

function PROP.tree(parent, pos, b, rng)
	local P, m = b.Props, newModel("Tree")
	local h = rng:NextNumber(8, 13)
	part(m, { Name = "Trunk", Size = V3(2.2, h, 2.2), CFrame = CFrame.new(pos + V3(0, h / 2, 0)), Color = P.Trunk })
	local leaf = P.Leaf:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.18))
	local y = h + 2
	for idx, s in ipairs({ 10 + rng:NextNumber(-1, 1), 7.5, 5 }) do
		part(m, { Name = "Leaves" .. idx, Size = V3(s, s * 0.7, s), CFrame = CFrame.new(pos + V3(rng:NextNumber(-0.6, 0.6), y, rng:NextNumber(-0.6, 0.6))) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = leaf, CanCollide = false })
		y += s * 0.55
	end
	m.Parent = parent
end
function PROP.cactus(parent, pos, b, rng)
	local P, m = b.Props, newModel("Cactus")
	local h = rng:NextNumber(9, 16)
	part(m, { Name = "Trunk", Size = V3(2.6, h, 2.6), CFrame = CFrame.new(pos + V3(0, h / 2, 0)), Color = P.Leaf })
	for _, s in ipairs({ -1, 1 }) do
		local ah = rng:NextNumber(2, h * 0.5)
		part(m, { Name = "ArmH", Size = V3(3.6, 1.8, 1.8), CFrame = CFrame.new(pos + V3(s * 2.6, ah, 0)), Color = P.Leaf, CanCollide = false })
		part(m, { Name = "ArmV", Size = V3(1.8, rng:NextNumber(3, 6), 1.8), CFrame = CFrame.new(pos + V3(s * 4.0, ah + 2.2, 0)), Color = P.Leaf, CanCollide = false })
	end
	m.Parent = parent
end
function PROP.pine(parent, pos, b, rng)
	local P, m = b.Props, newModel("Pine")
	local h = rng:NextNumber(5, 8)
	part(m, { Name = "Trunk", Size = V3(2, h, 2), CFrame = CFrame.new(pos + V3(0, h / 2, 0)), Color = P.Trunk })
	local y, s = h, rng:NextNumber(11, 14)
	for _ = 1, 4 do
		part(m, { Name = "Tier", Size = V3(s, 3.2, s), CFrame = CFrame.new(pos + V3(0, y + 1.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Color = P.Leaf, CanCollide = false })
		part(m, { Name = "Snow", Size = V3(s * 0.7, 0.8, s * 0.7), CFrame = CFrame.new(pos + V3(0, y + 3.4, 0)), Color = Color3.fromRGB(245, 250, 255), CanCollide = false })
		y += 2.6; s *= 0.72
	end
	m.Parent = parent
end
function PROP.crystal(parent, pos, b, rng)
	local m = newModel("Crystal")
	for k = 1, 3 do
		local h = rng:NextNumber(7, 16) * (k == 1 and 1.3 or 0.8)
		part(m, { Name = "Crystal", Size = V3(3, h, 3), CFrame = CFrame.new(pos + V3((k - 2) * 2.6, h / 2, rng:NextNumber(-1, 1))) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)),
			Color = b.Props.Accent, Material = Enum.Material.Glass, Transparency = 0.15 })
	end
	m.Parent = parent
end
function PROP.deadtree(parent, pos, b, rng)
	local P, m = b.Props, newModel("DeadTree")
	local h = rng:NextNumber(10, 16)
	part(m, { Name = "Trunk", Size = V3(2.4, h, 2.4), CFrame = CFrame.new(pos + V3(0, h / 2, 0)), Color = P.Trunk })
	for _, s in ipairs({ -1, 1 }) do
		part(m, { Name = "Branch", Size = V3(1.4, rng:NextNumber(5, 8), 1.4), CFrame = CFrame.new(pos + V3(s * 2, h * 0.7, 0)) * CFrame.Angles(0, 0, s * -0.7), Color = P.Trunk, CanCollide = false })
	end
	m.Parent = parent
end
function PROP.lavarock(parent, pos, b, rng)
	local m = newModel("LavaRock")
	local s = rng:NextNumber(6, 12)
	part(m, { Name = "Rock", Size = V3(s, s * 1.1, s), CFrame = CFrame.new(pos + V3(0, s * 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = b.Style.Color, Material = Enum.Material.Basalt })
	for _ = 1, 2 do
		part(m, { Name = "Vein", Size = V3(0.5, s * 0.8, 0.5), CFrame = CFrame.new(pos + V3(rng:NextNumber(-s / 2, s / 2), s * 0.55, s / 2 + 0.1)), Color = b.Props.Accent, Material = Enum.Material.Neon, CanCollide = false })
	end
	m.Parent = parent
end
function PROP.building(parent, pos, b, rng)
	local P, m = b.Props, newModel("Building")
	local w, d, h = rng:NextNumber(20, 34), rng:NextNumber(20, 34), rng:NextNumber(40, 150)
	part(m, { Name = "Tower", Size = V3(w, h, d), CFrame = CFrame.new(pos + V3(0, h / 2, 0)), Color = P.Leaf:Lerp(P.Trunk, rng:NextNumber(0, 1)) })
	local neon = rng:NextNumber() < 0.5 and P.Accent or Color3.fromRGB(70, 240, 255)
	for _, s in ipairs({ -1, 1 }) do
		part(m, { Name = "Neon", Size = V3(0.8, h * 0.9, d * 0.5), CFrame = CFrame.new(pos + V3(s * (w / 2 + 0.2), h / 2, 0)), Color = neon, Material = Enum.Material.Neon, CanCollide = false })
	end
	part(m, { Name = "Roof", Size = V3(w * 0.6, 3, d * 0.6), CFrame = CFrame.new(pos + V3(0, h + 1.5, 0)), Color = neon, Material = Enum.Material.Neon, CanCollide = false })
	m.Parent = parent
end
function PROP.lamp(parent, pos, b)
	local m = newModel("Lamp")
	part(m, { Name = "Pole", Size = V3(0.8, 14, 0.8), CFrame = CFrame.new(pos + V3(0, 7, 0)), Color = Color3.fromRGB(50, 52, 70) })
	part(m, { Name = "Head", Size = V3(3.4, 1, 3.4), CFrame = CFrame.new(pos + V3(0, 14.2, 0)), Color = b.Props.Accent, Material = Enum.Material.Neon, CanCollide = false })
	m.Parent = parent
end
function PROP.spire(parent, pos, b, rng)
	local P, m = b.Props, newModel("Spire")
	local h = rng:NextNumber(40, 100)
	part(m, { Name = "Pillar", Size = V3(6, h, 6), CFrame = CFrame.new(pos + V3(0, h / 2, 0)), Color = P.Leaf, Material = Enum.Material.Marble })
	part(m, { Name = "Ring", Size = V3(8.6, 1.4, 8.6), CFrame = CFrame.new(pos + V3(0, h * 0.7, 0)), Color = P.Accent, Material = Enum.Material.Metal, CanCollide = false })
	part(m, { Name = "Cap", Size = V3(5, 3, 5), CFrame = CFrame.new(pos + V3(0, h + 1.5, 0)), Color = P.Accent, Material = Enum.Material.Neon, CanCollide = false })
	m.Parent = parent
end
function PROP.cloudtree(parent, pos, b, rng)
	local P, m = b.Props, newModel("CloudTree")
	local h = rng:NextNumber(8, 12)
	part(m, { Name = "Trunk", Size = V3(2.4, h, 2.4), CFrame = CFrame.new(pos + V3(0, h / 2, 0)), Color = P.Trunk })
	for k = 1, 3 do
		local s = rng:NextNumber(6, 9)
		part(m, { Name = "Cloud", Size = V3(s, s * 0.8, s), CFrame = CFrame.new(pos + V3((k - 2) * 4, h + 2 + (k == 2 and 2.5 or 0), rng:NextNumber(-1.5, 1.5))), Color = P.Leaf, CanCollide = false })
	end
	m.Parent = parent
end
function PROP.rock(parent, pos, b, rng)
	local m = newModel("Rock")
	local c = b.Style.Color:Lerp(Color3.fromRGB(140, 134, 150), 0.4)
	for _ = 1, 2 do
		local s = rng:NextNumber(3, 8)
		part(m, { Name = "Stone", Size = V3(s, s * 0.8, s * 1.1), Color = c:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.15)),
			CFrame = CFrame.new(pos + V3(rng:NextNumber(-2, 2), s * 0.3, rng:NextNumber(-2, 2))) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)) })
	end
	m.Parent = parent
end

-- ---- decorações do Warrior Canyon (bioma original de artes marciais)
function PROP.dummy(parent, pos, b, rng)
	local m = newModel("TrainingDummy")
	local wood, light = b.Props.Trunk, b.Props.Trunk:Lerp(Color3.new(1, 1, 1), 0.35)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	part(m, { Name = "Base", Size = V3(3.4, 0.8, 3.4), CFrame = CFrame.new(pos + V3(0, 0.4, 0)) * yaw, Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Slate })
	part(m, { Name = "Post", Size = V3(1.3, 8, 1.3), CFrame = CFrame.new(pos + V3(0, 4.4, 0)) * yaw, Color = wood, Material = Enum.Material.Wood })
	part(m, { Name = "Body", Size = V3(2.8, 3.6, 2.8), CFrame = CFrame.new(pos + V3(0, 6.2, 0)) * yaw, Shape = Enum.PartType.Cylinder, Color = light, Material = Enum.Material.Wood })
	for _, h in ipairs({ 5.4, 7.0 }) do
		part(m, { Name = "Arm", Size = V3(6.4, 0.7, 0.7), CFrame = CFrame.new(pos + V3(0, h, 0)) * yaw * CFrame.Angles(0, (h > 6) and 0.6 or -0.6, 0), Color = wood, Material = Enum.Material.Wood, CanCollide = false })
	end
	part(m, { Name = "Band", Size = V3(3.0, 0.5, 3.0), CFrame = CFrame.new(pos + V3(0, 8.2, 0)) * yaw, Color = b.Props.Accent, CanCollide = false })
	m.Parent = parent
end
function PROP.boulder(parent, pos, b, rng)
	local m = newModel("Boulder")
	local s = rng:NextNumber(8, 16)
	local c = b.Style.Color
	part(m, { Name = "Rock", Size = V3(s, s * 0.85, s * 1.1), Color = c, Material = Enum.Material.Rock,
		CFrame = CFrame.new(pos + V3(0, s * 0.35, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)) })
	part(m, { Name = "Crack", Size = V3(0.4, s * 0.7, s * 0.9), Color = Color3.fromRGB(40, 30, 30), CanCollide = false,
		CFrame = CFrame.new(pos + V3(0, s * 0.4, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0.15) })
	for _ = 1, 3 do
		local q = rng:NextNumber(1.5, 3.5)
		part(m, { Name = "Pebble", Size = V3(q, q * 0.8, q), Color = c:Lerp(Color3.new(1, 1, 1), 0.15), Material = Enum.Material.Rock, CanCollide = false,
			CFrame = CFrame.new(pos + V3(rng:NextNumber(-s, s) * 0.7, q * 0.3, rng:NextNumber(-s, s) * 0.7)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0) })
	end
	m.Parent = parent
end
function PROP.banner(parent, pos, b, rng)
	local m = newModel("Banner")
	local yaw = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	part(m, { Name = "Pole", Size = V3(0.7, 16, 0.7), CFrame = CFrame.new(pos + V3(0, 8, 0)) * yaw, Color = Color3.fromRGB(50, 40, 40), Material = Enum.Material.Wood })
	part(m, { Name = "Bar", Size = V3(5.6, 0.5, 0.5), CFrame = CFrame.new(pos + V3(0, 15.6, 0)) * yaw, Color = Color3.fromRGB(50, 40, 40), Material = Enum.Material.Wood, CanCollide = false })
	local flag = part(m, { Name = "Flag", Size = V3(5, 7.5, 0.2), CFrame = CFrame.new(pos + V3(0, 11.6, 0)) * yaw * CFrame.new(0, 0, 0.5), Color = b.Props.Accent, Material = Enum.Material.Fabric, CanCollide = false })
	signGui(flag, Enum.NormalId.Front, "武", nil, Color3.new(1, 1, 1))
	signGui(flag, Enum.NormalId.Back, "武", nil, Color3.new(1, 1, 1))
	m.Parent = parent
end

-- Partículas de "aura de energia" (genéricas: faíscas subindo). Usadas em marcos e no portal do lobby.
local function energyAura(p, color, rate, speed, size)
	local e = Instance.new("ParticleEmitter")
	e.Name = "EnergyAura"
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1; e.LightInfluence = 0
	e.Rate = rate or 12
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new((speed or 8) * 0.6, speed or 8)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = V3(0, 4, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 1.4), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = p
	return e
end
WorldBuilder.EnergyAura = energyAura

-- ---- Azure Planet (bioma 1, original): árvore de copa redonda azul (tronco fino e alto, como na referência)
function PROP.bluetree(parent, pos, b, rng)
	local P, m = b.Props, newModel("BlueTree")
	local h = rng:NextNumber(12, 22)
	local lean = CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, 6.28), rng:NextNumber(-0.08, 0.08))
	part(m, { Name = "Trunk", Size = V3(1.6, h, 1.6), CFrame = CFrame.new(pos + V3(0, h / 2, 0)) * lean, Color = P.Trunk, Material = Enum.Material.Wood })
	part(m, { Name = "Branch", Size = V3(0.9, h * 0.3, 0.9), CFrame = CFrame.new(pos + V3(1.3, h * 0.72, 0)) * CFrame.Angles(0, 0, -0.7), Color = P.Trunk, Material = Enum.Material.Wood, CanCollide = false })
	local leaf = P.Leaf:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.15))
	local s = rng:NextNumber(10, 15)
	part(m, { Name = "Crown", Size = V3(s, s * 0.8, s), CFrame = CFrame.new(pos + V3(0, h + s * 0.25, 0)), Shape = Enum.PartType.Ball, Color = leaf, CanCollide = false })
	part(m, { Name = "CrownTop", Size = V3(s * 0.65, s * 0.55, s * 0.65), CFrame = CFrame.new(pos + V3(s * 0.15, h + s * 0.65, -s * 0.1)), Shape = Enum.PartType.Ball, Color = leaf:Lerp(Color3.new(1, 1, 1), 0.12), CanCollide = false })
	m.Parent = parent
end
-- casa-domo branca com janelas redondas, faixa colorida, porta e antena com luz
function PROP.domehouse(parent, pos, b, rng)
	local m = newModel("DomeHouse")
	local s = rng:NextNumber(14, 20)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local base = CFrame.new(pos) * yaw
	local white, band = Color3.fromRGB(240, 244, 250), b.Props.Accent
	part(m, { Name = "Base", Size = V3(s * 1.05, 1.2, s * 1.05), CFrame = base * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(150, 150, 170) })
	part(m, { Name = "Dome", Size = V3(s, s * 0.85, s), CFrame = base * CFrame.new(0, 1.2, 0), Shape = Enum.PartType.Ball, Color = white })
	part(m, { Name = "Band", Size = V3(0.8, s * 0.98, s * 0.98), CFrame = base * CFrame.new(0, s * 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = band, Material = Enum.Material.Neon, CanCollide = false })
	for k = 0, 2 do
		local a = math.rad(-50 + k * 50)
		local r = s * 0.47
		part(m, { Name = "Window", Size = V3(0.4, s * 0.16, s * 0.16), CFrame = base * CFrame.new(math.sin(a) * r, s * 0.32, -math.cos(a) * r) * CFrame.Angles(0, -a + math.rad(90), 0),
			Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(90, 220, 255), Material = Enum.Material.Neon, CanCollide = false })
	end
	part(m, { Name = "Door", Size = V3(s * 0.22, s * 0.3, 1), CFrame = base * CFrame.new(0, s * 0.15 + 1.2, -s * 0.48), Color = Color3.fromRGB(70, 80, 110), CanCollide = false })
	part(m, { Name = "Antenna", Size = V3(0.4, s * 0.45, 0.4), CFrame = base * CFrame.new(0, s * 0.6 + s * 0.22, 0), Color = Color3.fromRGB(200, 200, 215), CanCollide = false })
	part(m, { Name = "AntennaLight", Size = V3(1.2, 1.2, 1.2), CFrame = base * CFrame.new(0, s * 0.6 + s * 0.46, 0), Shape = Enum.PartType.Ball, Color = band, Material = Enum.Material.Neon, CanCollide = false })
	m.Parent = parent
end
-- cogumelos laranja pequenos (como na referência)
function PROP.mushroom(parent, pos, b, rng)
	local m = newModel("Mushrooms")
	for k = 1, rng:NextInteger(2, 4) do
		local p = pos + V3(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local h, r = rng:NextNumber(1.2, 2.6), rng:NextNumber(1.4, 2.6)
		part(m, { Name = "Stem", Size = V3(0.6, h, 0.6), CFrame = CFrame.new(p + V3(0, h / 2, 0)), Color = Color3.fromRGB(250, 240, 220), CanCollide = false })
		part(m, { Name = "Cap", Size = V3(r, r * 0.5, r), CFrame = CFrame.new(p + V3(0, h + 0.1, 0)), Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 110, 50), CanCollide = false })
	end
	m.Parent = parent
end
-- ilha de pedra flutuando no céu (decoração de fundo)
function PROP.floatisland(parent, pos, b, rng)
	local m = newModel("FloatIsland")
	local y = rng:NextNumber(45, 85)
	local s = rng:NextNumber(14, 26)
	local c = pos + V3(0, y, 0)
	part(m, { Name = "Top", Size = V3(s, 2.5, s * 0.85), CFrame = CFrame.new(c) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = b.Props.Leaf, Material = Enum.Material.Grass, CanCollide = false })
	part(m, { Name = "Rock", Size = V3(s * 0.85, s * 0.55, s * 0.7), CFrame = CFrame.new(c - V3(0, s * 0.3, 0)) * CFrame.Angles(0.2, rng:NextNumber(0, 6), 0.15), Color = b.Style.Color, Material = Enum.Material.Rock, CanCollide = false })
	part(m, { Name = "Tip", Size = V3(s * 0.4, s * 0.45, s * 0.4), CFrame = CFrame.new(c - V3(0, s * 0.68, 0)) * CFrame.Angles(0.3, 0.5, 0.2), Color = b.Style.Color:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Rock, CanCollide = false })
	if rng:NextNumber() < 0.6 then PROP.bluetree(m, c + V3(rng:NextNumber(-s / 4, s / 4), 1.2, 0), b, rng) end
	m.Parent = parent
end

-- Marcos: cf = no chão, olhando para a pista
local LANDMARK = {}
function LANDMARK.dojo(parent, cf, b)
	local m = newModel("Dojo")
	local red, wood, roof, stone = Color3.fromRGB(190, 50, 45), Color3.fromRGB(150, 100, 60), Color3.fromRGB(60, 44, 50), Color3.fromRGB(150, 145, 140)
	local function Q(name, size, lcf, color, o)
		local props = { Name = name, Size = size, CFrame = cf * lcf, Color = color }
		if o then for k, v in pairs(o) do props[k] = v end end
		return part(m, props)
	end
	Q("Platform", V3(46, 8, 36), CFrame.new(0, -2.5, 0), stone, { Material = Enum.Material.Cobblestone })
	Q("Steps", V3(16, 1.5, 6), CFrame.new(0, 1.2, -20), stone, { Material = Enum.Material.Cobblestone })
	Q("Hall", V3(34, 12, 24), CFrame.new(0, 7.5, 2), wood, { Material = Enum.Material.WoodPlanks })
	Q("Door", V3(9, 8, 0.4), CFrame.new(0, 5.5, -10.2), Color3.fromRGB(40, 30, 30))
	for _, x in ipairs({ -15, -5, 5, 15 }) do Q("Pillar", V3(1.6, 12, 1.6), CFrame.new(x, 7.5, -10.4), red, { Material = Enum.Material.Wood }) end
	Q("Roof1", V3(44, 1.6, 34), CFrame.new(0, 14.2, 2), roof, { Material = Enum.Material.Slate })
	Q("Roof1Trim", V3(45, 0.8, 35), CFrame.new(0, 13.2, 2), red)
	Q("Upper", V3(22, 6, 14), CFrame.new(0, 18, 2), wood, { Material = Enum.Material.WoodPlanks })
	Q("Roof2", V3(30, 1.6, 22), CFrame.new(0, 21.8, 2), roof, { Material = Enum.Material.Slate })
	Q("Ridge", V3(16, 3, 4), CFrame.new(0, 24, 2), roof, { Material = Enum.Material.Slate })
	local sign = Q("Sign", V3(14, 4, 0.5), CFrame.new(0, 16.5, -5.3), Color3.fromRGB(30, 22, 22), { CanCollide = false })
	signGui(sign, Enum.NormalId.Front, "DOJO", nil, b.Props.Accent)
	for _, x in ipairs({ -20, 20 }) do
		Q("Lantern", V3(2.4, 3, 2.4), CFrame.new(x, 3.2, -16), Color3.fromRGB(255, 190, 90), { Material = Enum.Material.Neon, CanCollide = false })
		Q("LanternPost", V3(0.8, 2, 0.8), CFrame.new(x, 1, -16), stone)
	end
	m.Parent = parent
end
function LANDMARK.arena(parent, cf, b)
	local m = newModel("Arena")
	local stone, dark = Color3.fromRGB(205, 200, 190), Color3.fromRGB(110, 105, 100)
	local function Q(name, size, lcf, color, o)
		local props = { Name = name, Size = size, CFrame = cf * lcf, Color = color }
		if o then for k, v in pairs(o) do props[k] = v end end
		return part(m, props)
	end
	Q("Ring", V3(9, 56, 56), CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90)), stone, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Marble })
	Q("RingEdge", V3(8.6, 58, 58), CFrame.new(0, -1.3, 0) * CFrame.Angles(0, 0, math.rad(90)), dark, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate })
	local center = Q("Center", V3(0.2, 14, 14), CFrame.new(0, 3.55, 0) * CFrame.Angles(0, 0, math.rad(90)), b.Props.Accent, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, CanCollide = false })
	energyAura(center, b.Props.Accent, 8, 6, 1.2)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local x, z = math.cos(a) * 31, math.sin(a) * 31
		Q("Torch", V3(1.4, 10, 1.4), CFrame.new(x, 5, z), Color3.fromRGB(70, 50, 40), { Material = Enum.Material.Wood })
		local fire = Q("Flame", V3(1.8, 1.8, 1.8), CFrame.new(x, 10.6, z), Color3.fromRGB(255, 140, 40), { Material = Enum.Material.Neon, CanCollide = false })
		local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(255, 160, 80); l.Range = 18; l.Brightness = 1.5; l.Parent = fire
	end
	local gate = Q("GateBeam", V3(18, 2, 2), CFrame.new(0, 12, -31), dark, { Material = Enum.Material.Slate, CanCollide = false })
	signGui(gate, Enum.NormalId.Front, "ARENA", nil, b.Props.Accent)
	for _, x in ipairs({ -8, 8 }) do Q("GatePost", V3(2, 12, 2), CFrame.new(x, 6, -31), dark, { Material = Enum.Material.Slate }) end
	m.Parent = parent
end

-- vila de casas-domo em volta de uma praça redonda
function LANDMARK.pods(parent, cf, b)
	local m = newModel("DomeVillage")
	local rng = Random.new(math.floor(cf.Position.Z))
	part(m, { Name = "Plaza", Size = V3(0.6, 34, 34), CFrame = cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(214, 160, 104), Material = Enum.Material.Sand })
	part(m, { Name = "Pond", Size = V3(0.7, 12, 12), CFrame = cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(70, 170, 255), Material = Enum.Material.Glass, Transparency = 0.2 })
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2 + 0.3
		local p = (cf * CFrame.new(math.cos(a) * 30, 0, math.sin(a) * 30)).Position
		PROP.domehouse(m, p, b, rng)
	end
	m.Parent = parent
end
-- pilar de cristal com aura de energia subindo (ponto de referência visível de longe)
function LANDMARK.energyspire(parent, cf, b)
	local m = newModel("EnergySpire")
	local acc = b.Props.Accent
	part(m, { Name = "Base", Size = V3(16, 3, 16), CFrame = cf * CFrame.new(0, 1.2, 0), Color = b.Style.Color, Material = Enum.Material.Rock })
	part(m, { Name = "Ring", Size = V3(0.4, 15, 15), CFrame = cf * CFrame.new(0, 2.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = acc, Material = Enum.Material.Neon, CanCollide = false })
	local crystal = part(m, { Name = "Crystal", Size = V3(5, 26, 5), CFrame = cf * CFrame.new(0, 16, 0) * CFrame.Angles(0, math.rad(45), 0), Color = acc, Material = Enum.Material.Glass, Transparency = 0.15 })
	part(m, { Name = "Core", Size = V3(2.4, 22, 2.4), CFrame = cf * CFrame.new(0, 16, 0), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, CanCollide = false })
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		part(m, { Name = "Shard", Size = V3(2.4, 10, 2.4), CFrame = cf * CFrame.new(math.cos(a) * 5.5, 7, math.sin(a) * 5.5) * CFrame.Angles(math.cos(a) * 0.35, 0, math.sin(a) * 0.35), Color = acc, Material = Enum.Material.Glass, Transparency = 0.2 })
	end
	energyAura(crystal, acc, 14, 10, 1.6)
	local l = Instance.new("PointLight"); l.Color = acc; l.Range = 40; l.Brightness = 2; l.Parent = crystal
	m.Parent = parent
end

-- ===================================================================== SANTUÁRIO DE OVOS
-- pos = no chão; facing = direção para onde a frente aponta (normalmente: para a pista)
function WorldBuilder.BuildShrine(parent, pos, facing, b)
	local egg = Config.Eggs[b.Id]
	local m = Instance.new("Model"); m.Name = "EggShrine_" .. b.Id
	local cf = CFrame.lookAt(pos, pos + V3(facing.X, 0, facing.Z))
	local col, acc = b.Style.Color, b.Color
	local function Q(name, size, lcf, color, o)
		local props = { Name = name, Size = size, CFrame = cf * lcf, Color = color }
		if o then for k, v in pairs(o) do props[k] = v end end
		return part(m, props)
	end
	Q("Base", V3(22, 6, 22), CFrame.new(0, -2.2, 0), col, { Material = Enum.Material.Marble })
	Q("BaseTrim", V3(22.6, 0.5, 22.6), CFrame.new(0, 0.6, 0), acc, { Material = Enum.Material.Neon, CanCollide = false })
	for _, x in ipairs({ -9, 9 }) do
		for _, z in ipairs({ -9, 9 }) do
			Q("Pillar", V3(1.8, 16, 1.8), CFrame.new(x, 8.6, z), col, { Material = Enum.Material.Marble })
			Q("PillarCap", V3(2.4, 1, 2.4), CFrame.new(x, 16.6, z), acc, { Material = Enum.Material.Neon, CanCollide = false })
		end
	end
	Q("Roof", V3(24, 1.6, 24), CFrame.new(0, 17.6, 0), col, { Material = Enum.Material.Marble })
	Q("RoofTop", V3(14, 2.4, 14), CFrame.new(0, 19.6, 0), acc, { Material = Enum.Material.SmoothPlastic })
	-- Pedestal = a peça "oficial" (tag EggShrine, atributo BiomeId): o cliente coloca o prompt nela
	local pedestal = Q("Pedestal", V3(7, 3.4, 7), CFrame.new(0, 2.3, 0), Color3.fromRGB(40, 40, 52), { Material = Enum.Material.DiamondPlate })
	pedestal:SetAttribute("BiomeId", b.Id)
	CollectionService:AddTag(pedestal, "EggShrine")
	Q("PedestalGlow", V3(7.6, 0.4, 7.6), CFrame.new(0, 4.1, 0), acc, { Material = Enum.Material.Neon, CanCollide = false })
	-- ovo de vitrine (gira no cliente: nome "DisplayEgg")
	local e = Q("DisplayEgg", V3(5, 6.4, 5), CFrame.new(0, 7.6, 0), egg.Color, { Material = Enum.Material.SmoothPlastic, CanCollide = false })
	local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = e
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		Q("EggSpot", V3(1.1, 1.1, 1.1), CFrame.new(math.cos(a) * 2.3, 7.6 + ((k % 2 == 0) and 1.2 or -0.9), math.sin(a) * 2.3), egg.Spot,
			{ Shape = Enum.PartType.Ball, CanCollide = false })
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "ShrineTag"; bb.Size = UDim2.fromOffset(240, 80); bb.StudsOffsetWorldSpace = V3(0, 9, 0); bb.MaxDistance = 220; bb.Adornee = e; bb.Parent = e
	local function lbl(y, h, text, color, size)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1; l.Size = UDim2.new(1, 0, 0, h); l.Position = UDim2.fromOffset(0, y)
		l.Font = Enum.Font.FredokaOne; l.TextSize = size; l.TextColor3 = color; l.Text = text
		local s = Instance.new("UIStroke"); s.Thickness = 3; s.Parent = l
		l.Parent = bb
	end
	lbl(0, 36, egg.Name:upper(), acc, 30)
	lbl(38, 30, "🥚 Egg Shrine", Color3.new(1, 1, 1), 20)
	m.Parent = parent
	return m
end

-- ===================================================================== BIOMA (props + obstáculos + objetos)
function WorldBuilder.BuildBiome(index)
	local b = biomes[index]
	local map = workspace.Map
	local feats = F()
	for _, name in ipairs({ "Drivable", "Props", "Structures", "BoostPads", "EggNodes", "EggShrines" }) do
		if not map:FindFirstChild(name) then local f = Instance.new("Folder"); f.Name = name; f.Parent = map end
		local s = map[name]:FindFirstChild(b.Id); if s then s:Destroy() end
	end
	for _, n in ipairs(map.AnimeSpawns:GetChildren()) do if n:GetAttribute("BiomeId") == b.Id then n:Destroy() end end
	local function sub(name) local f = Instance.new("Folder"); f.Name = b.Id; f.Parent = map[name]; return f end
	local dr, pr, st, bp = sub("Drivable"), sub("Props"), sub("Structures"), sub("BoostPads")
	local rng = Random.new(b.Order * 7919)
	local S, P = b.Style, b.Props
	local roadW = W.RoadFlat * 2
	local stats = { props = 0, nodes = 0, pads = 0 }
	local kinds = {}

	local function clear(z, margin) return not (isVoid(z) or isVoid(z - margin) or isVoid(z + margin)) end

	-- ---- decoração
	local count = math.floor(b.Length / 1000 * P.PerK)
	local total = count + math.floor(b.Length / 1000 * 26)
	local tries = 0
	while stats.props < total and tries < total * 6 do
		tries += 1
		local z = rng:NextNumber(b.ZStart - 20, b.ZEnd + 20)
		local x = rng:NextNumber(-W.HalfWidth + 30, W.HalfWidth - 30)
		local kind = (stats.props < count) and P.Kinds[rng:NextInteger(1, #P.Kinds)] or "rock"
		local minOff = (kind == "building" or kind == "spire") and (W.RoadFlat + 45) or (W.RoadFlat + 12)
		if math.abs(x - W.RoadX(z)) > minOff and clear(z, 14) then
			local y, n = ground(x, z)
			if n.Y > 0.82 and y < 55 then
				PROP[kind](pr, V3(x, y - 0.3, z), b, rng)
				stats.props += 1
			end
		end
		if tries % 80 == 0 then task.wait() end
	end
	if P.RoadSide == "fence" then -- cercas de madeira ao longo da pista (Azure Planet)
		local z = b.ZStart - 50
		while z > b.ZEnd + 50 do
			if clear(z, 24) then
				for _, side in ipairs({ -1, 1 }) do
					local a = V3(W.RoadX(z) + side * (W.RoadFlat + 7), 0, z)
					local bz = z - 26
					local bb = V3(W.RoadX(bz) + side * (W.RoadFlat + 7), 0, bz)
					a = V3(a.X, (ground(a.X, a.Z)), a.Z); bb = V3(bb.X, (ground(bb.X, bb.Z)), bb.Z)
					local f = newModel("Fence")
					for _, p in ipairs({ a, bb }) do
						part(f, { Name = "Post", Size = V3(1.2, 4.6, 1.2), CFrame = CFrame.new(p + V3(0, 2.1, 0)), Color = Color3.fromRGB(150, 88, 50), Material = Enum.Material.Wood })
					end
					local mid, len = (a + bb) / 2, (bb - a).Magnitude
					part(f, { Name = "Rail", Size = V3(0.5, 0.7, len), CFrame = CFrame.lookAt(mid + V3(0, 3, 0), bb + V3(0, 3, 0)), Color = Color3.fromRGB(190, 116, 64), Material = Enum.Material.Wood, CanCollide = false })
					part(f, { Name = "Rail2", Size = V3(0.5, 0.7, len), CFrame = CFrame.lookAt(mid + V3(0, 1.6, 0), bb + V3(0, 1.6, 0)), Color = Color3.fromRGB(190, 116, 64), Material = Enum.Material.Wood, CanCollide = false })
					f.Parent = pr
				end
			end
			z -= 70
		end
	end
	if P.RoadSide == "lamp" then -- postes de luz ao longo da pista (cidade)
		local z = b.ZStart - 60
		while z > b.ZEnd + 60 do
			if clear(z, 10) then
				for _, side in ipairs({ -1, 1 }) do
					local x = W.RoadX(z) + side * (W.RoadFlat + 4)
					PROP.lamp(pr, V3(x, (ground(x, z)), z), b)
				end
			end
			z -= 90
		end
	end

	-- ---- auxiliares de obstáculo
	local function padAt(zp, lateral)
		if not clear(zp, 30) then return end
		local cf = frameAt(zp, lateral or rng:NextNumber(-8, 8))
		local p = part(bp, { Name = "BoostPad", Size = V3(16, 0.5, 26), CFrame = cf * CFrame.new(0, 0.45, 0), Color = Color3.fromRGB(70, 240, 255),
			Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		signGui(p, Enum.NormalId.Top, "▲▲▲", "BOOST", COL.white)
		for _, g in ipairs(p:GetDescendants()) do -- na face Top o "topo" do texto aponta para trás: gira 180° para ler de quem chega
			if g:IsA("TextLabel") then g.Rotation = 180 end
		end
		CollectionService:AddTag(p, "BoostPad")
		stats.pads += 1
	end
	local function signPost(zp, title, subtitle, color)
		local cf = frameAt(zp, W.RoadFlat + 6)
		part(st, { Name = "SignPole", Size = V3(1, 12, 1), CFrame = cf * CFrame.new(0, 6, 0), Color = Color3.fromRGB(60, 60, 70) })
		local panel = part(st, { Name = "SignPanel", Size = V3(16, 7, 0.6), CFrame = cf * CFrame.new(0, 12.5, 0), Color = Color3.fromRGB(20, 20, 28) })
		signGui(panel, Enum.NormalId.Back, title, subtitle, color)
	end

	-- ---- obstáculos
	for _, f in ipairs(feats.List) do
		if f.Biome == b then
			local z, k = f.Z, f.Kind
			kinds[k] = (kinds[k] or 0) + 1
			if k == "ramp" then
				local cf = frameAt(z, rng:NextNumber(-6, 6))
				local c = cf * CFrame.new(0, 5.4, 0) * CFrame.Angles(math.rad(15), 0, 0)
				if Config.Track and Config.Track.Ramps then -- Beta 1.6: rampas amarelas DESLIGADAS a pedido do dono
					part(dr, { Name = "Ramp", Size = V3(28, 1.6, 36), CFrame = c, Color = Color3.fromRGB(255, 170, 30), Material = Enum.Material.DiamondPlate })
					for _, s in ipairs({ -1, 1 }) do
						part(dr, { Name = "RampRail", Size = V3(0.8, 0.8, 36), CFrame = c * CFrame.new(s * 14, 1.1, 0), Color = Color3.fromRGB(255, 255, 120), Material = Enum.Material.Neon, CanCollide = false })
					end
				end
				padAt(z + 55)
			elseif k == "bumps" then
				for r = 0, 4 do
					local cf = frameAt(z - r * 13, 0)
					part(dr, { Name = "Bump", Size = V3(roadW - 2, 3.2, 3.2), CFrame = cf * CFrame.new(0, -0.5, 0), Shape = Enum.PartType.Cylinder,
						Color = (r % 2 == 0) and S.Color or S.Accent, Material = S.Material })
				end
			elseif k == "slalom" then
				if Config.Track and Config.Track.Slalom then -- Beta 1.6: blocos laterais DESLIGADOS a pedido do dono
					for r = 0, 5 do
						local cf = frameAt(z - r * 36, ((r % 2 == 0) and -1 or 1) * 14)
						part(pr, { Name = "SlalomBlock", Size = V3(9, 8, 9), CFrame = cf * CFrame.new(0, 4, 0), Color = S.Color, Material = S.Material })
						part(pr, { Name = "SlalomStripe", Size = V3(9.2, 1.4, 9.2), CFrame = cf * CFrame.new(0, 6.8, 0), Color = S.Accent, Material = Enum.Material.Neon, CanCollide = false })
					end
				end
			elseif k == "pinch" then
				signPost(z + 70, "⚠ NARROW", "slow down!", Color3.fromRGB(255, 200, 20))
				local cf = frameAt(z, 0)
				for _, s in ipairs({ -1, 1 }) do
					part(pr, { Name = "PinchWall", Size = V3(16, 28, 130), CFrame = cf * CFrame.new(s * 25, 14, -65), Color = S.Color, Material = S.Material })
					part(pr, { Name = "PinchNeon", Size = V3(0.5, 0.7, 130), CFrame = cf * CFrame.new(s * 16.6, 2.2, -65), Color = S.Accent, Material = Enum.Material.Neon, CanCollide = false })
				end
			elseif k == "logs" then
				for r = 0, 2 do
					local cf = frameAt(z - r * 28, ((r % 2 == 0) and -1 or 1) * 9)
					part(pr, { Name = "Log", Size = V3(24, 4.8, 4.8), CFrame = cf * CFrame.new(0, 2.2, 0), Shape = Enum.PartType.Cylinder, Color = P.Trunk, Material = Enum.Material.Wood })
				end
			elseif k == "ice" then
				local cf = frameAt(z, 0)
				local zone = part(pr, { Name = "IceZone", Size = V3(roadW - 2, 0.3, 120), CFrame = cf * CFrame.new(0, 0.2, -60), Color = Color3.fromRGB(170, 230, 255),
					Material = Enum.Material.Ice, Transparency = 0.15, CanCollide = false, CanQuery = false })
				CollectionService:AddTag(zone, "IceZone")
				signPost(z + 70, "❄ SLIPPERY", "ice ahead!", Color3.fromRGB(130, 215, 255))
			elseif k == "gate" then
				local cf = frameAt(z, 0)
				local span = W.RoadFlat + 8
				for _, s in ipairs({ -1, 1 }) do
					part(st, { Name = "GatePillar", Size = V3(4, 26, 4), CFrame = cf * CFrame.new(s * span, 13, 0), Color = S.Color, Material = S.Material })
				end
				part(st, { Name = "GateBeam", Size = V3(span * 2 + 8, 3.2, 5), CFrame = cf * CFrame.new(0, 27, 0), Color = S.Color, Material = S.Material, CanCollide = false })
				part(st, { Name = "GateNeon", Size = V3(span * 2 + 6, 0.8, 0.8), CFrame = cf * CFrame.new(0, 25.2, 0), Color = S.Accent, Material = Enum.Material.Neon, CanCollide = false })
			elseif k == "gap" then
				local z0, z1 = f.Z, f.Z - f.Len
				local zA, zB = z0 + 14, z1 - 14
				local A = V3(W.RoadX(zA), (ground(W.RoadX(zA), zA)), zA)
				local B = V3(W.RoadX(zB), (ground(W.RoadX(zB), zB)), zB)
				local mid, len = (A + B) / 2, (B - A).Magnitude
				local cf = CFrame.lookAt(mid, B)
				local bw = W.BridgeWidth
				part(dr, { Name = "BridgeDeck", Size = V3(bw, 2, len), CFrame = cf * CFrame.new(0, -1, 0), Color = S.Color, Material = (b.Id == "celestial") and Enum.Material.Marble or Enum.Material.Metal })
				part(dr, { Name = "BridgeStripe", Size = V3(1, 0.1, len), CFrame = cf * CFrame.new(0, 0.05, 0), Color = S.Accent, Material = Enum.Material.Neon, CanCollide = false })
				for _, s in ipairs({ -1, 1 }) do
					part(pr, { Name = "BridgeRail", Size = V3(0.8, 3, len), CFrame = cf * CFrame.new(s * (bw / 2 - 0.4), 1.5, 0), Color = S.Color, Material = S.Material })
					part(pr, { Name = "BridgeRailNeon", Size = V3(0.9, 0.6, len), CFrame = cf * CFrame.new(s * (bw / 2 - 0.4), 3.2, 0), Color = S.Accent, Material = Enum.Material.Neon, CanCollide = false })
				end
				if S.GapFloor == "lava" then
					part(st, { Name = "Lava", Size = V3(W.HalfWidth * 2, 2, f.Len + 30), CFrame = CFrame.new(0, -26, (z0 + z1) / 2), Color = Color3.fromRGB(255, 90, 20),
						Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
				end
				signPost(z0 + 110, "⚠ BRIDGE", "narrow road!", Color3.fromRGB(255, 200, 20))
				padAt(z0 + 70, 0)
			end
		end
		task.wait()
	end

	-- ---- boost pads extras
	local zp = b.ZStart - 140
	-- Beta 1.8: menos boosts (Config.Track.BoostEvery; era 230). O rng é consumido igual => resto do bioma não muda.
	while zp > b.ZEnd + 140 do
		local jitter = rng:NextNumber(-30, 30)
		if ((b.ZStart - 140 - zp) % ((Config.Track and Config.Track.BoostEvery) or 230)) < 230 then padAt(zp + jitter) end
		zp -= 230
	end

	-- ---- OVOS DE ESTRADA (grátis) — sistema atual
	local eggF = Instance.new("Folder"); eggF.Name = b.Id; eggF.Parent = map.EggNodes
	stats.eggs = 0
	local ez = b.ZStart - 160
	while ez > b.ZEnd + 160 do
		local zz = ez + rng:NextNumber(-30, 30)
		if clear(zz, 40) then
			stats.eggs += 1
			local x = W.RoadX(zz) + rng:NextNumber(-(W.RoadFlat - 10), W.RoadFlat - 10)
			local node = part(eggF, { Name = ("Egg_%s_%d"):format(b.Id, stats.eggs), Size = V3(4, 1, 4), CFrame = CFrame.new(x, (ground(x, zz)) + 0.5, zz),
				Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
			node:SetAttribute("BiomeId", b.Id)
			CollectionService:AddTag(node, "RoadEgg")
		end
		ez -= (b.EggSpacing or 230)
	end

	-- ---- SANTUÁRIOS DE OVOS (pagos): início e meio do bioma, ao lado da pista
	local shrF = Instance.new("Folder"); shrF.Name = b.Id; shrF.Parent = map.EggShrines
	stats.shrines = 0
	for k, zs in ipairs({ b.ZStart - 130, b.ZStart - math.floor(b.Length / 2) }) do
		for _ = 1, 6 do
			if clear(zs, 60) then break end
			zs -= 90
		end
		local side = (k % 2 == 1) and 1 or -1
		local fwd = roadForward(zs)
		local right = fwd:Cross(V3(0, 1, 0))
		local p = V3(W.RoadX(zs), 0, zs) + right * side * (W.RoadFlat + 22)
		WorldBuilder.BuildShrine(shrF, V3(p.X, (ground(p.X, p.Z)), p.Z), -right * side, b)
		stats.shrines += 1
	end

	-- ---- MARCOS (construções grandes de bioma, ex.: dojôs e arenas do Warrior Canyon)
	stats.landmarks = 0
	if b.Props.Landmarks then
		local li, side = 0, 1
		local lz = b.ZStart - 320
		while lz > b.ZEnd + 220 do
			if clear(lz, 80) then
				li += 1
				local kind = b.Props.Landmarks[(li - 1) % #b.Props.Landmarks + 1]
				local fwd = roadForward(lz)
				local right = fwd:Cross(V3(0, 1, 0))
				local road = V3(W.RoadX(lz), 0, lz)
				local p = road + right * side * (W.RoadFlat + 88)
				local gy = ground(p.X, p.Z)
				local cf = CFrame.lookAt(V3(p.X, gy, p.Z), V3(road.X, gy, road.Z))
				LANDMARK[kind](pr, cf, b)
				stats.landmarks += 1
				side = -side
			end
			lz -= (b.Props.LandmarkEvery or 700)
		end
	end

	-- ---- pontos de captura de anime (sistema ANTIGO, guardado: só com Config.Features.CaptureNodes)
	local nz = Config.Features.CaptureNodes and (b.ZStart - 150) or -math.huge
	while nz > b.ZEnd + 150 do
		local zz = nz + rng:NextNumber(-25, 25)
		if clear(zz, 40) then
			stats.nodes += 1
			local x = W.RoadX(zz) + rng:NextNumber(-(W.RoadFlat - 8), W.RoadFlat - 8)
			local node = part(map.AnimeSpawns, { Name = ("Node_%s_%d"):format(b.Id, stats.nodes), Size = V3(4, 1, 4), CFrame = CFrame.new(x, (ground(x, zz)) + 0.5, zz),
				Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
			node:SetAttribute("BiomeId", b.Id)
			CollectionService:AddTag(node, "AnimeSpawn")
		end
		nz -= (b.NodeSpacing or 120)
	end

	local ks = {}
	for k, v in pairs(kinds) do ks[#ks + 1] = k .. "=" .. v end
	table.sort(ks)
	return ("%s: %d props | %d marcos | %d ovos de estrada | %d santuários | %d pads | obstáculos: %s"):format(b.Name, stats.props, stats.landmarks, stats.eggs, stats.shrines, stats.pads, table.concat(ks, " "))
end

-- ===================================================================== DECORAÇÃO JAPONESA HIGH-TECH (Beta 1.4d)
--[[
	WorldBuilder.BuildJapanTechDecor(index) — enfeita um bioma SEM regenerar terreno/obstáculos (pasta própria:
	Map.Props.<bioma>.JapanTech; rodar de novo substitui). Estética: Japão tradicional + alta tecnologia de anime.
	  * Torii NEON sobre a pista (portal de entrada + a cada ~520 studs), com faixa de luz no topo
	  * Pares de lanternas de pedra nas bordas da pista (~150 studs) — só 1 em 4 com PointLight (celular)
	  * Painéis HOLOGRÁFICOS com kanji (速 velocidade, 龍 dragão, 夢 sonho, 風 vento, 力 força, 光 luz, 星 estrela)
	  * Cerejeiras low-poly (mesmo estilo do lobby) em grupos, 1 em 3 com pétalas
	  * Pagodes com lanterna nos cantos como marcos distantes (fora da pista)
	  * Lanternas de papel flutuando em fileira sobre a pista perto dos torii
	Nunca coloca nada dentro de abismos (isVoid) nem na faixa da estrada (só torii/lanternas aéreas cruzam por cima).
]]
function WorldBuilder.BuildJapanTechDecor(index)
	local b = biomes[index or 1]
	local map = workspace.Map
	local root = map.Props:FindFirstChild(b.Id) or Instance.new("Folder", map.Props)
	root.Name = b.Id
	local old = root:FindFirstChild("JapanTech"); if old then old:Destroy() end
	local f = Instance.new("Folder"); f.Name = "JapanTech"
	local rng = Random.new(b.Order * 4243)
	local cyan, pink = Color3.fromRGB(80, 230, 255), LT.Sakura
	local stats = { torii = 0, lanterns = 0, panels = 0, trees = 0, pagodas = 0 }
	-- longe de abismos E de obstáculos (desfiladeiros, slalom, rampas...): decoração nunca briga com o gameplay
	local function inFeature(z, m)
		for _, ft in ipairs(F().List) do
			-- só desfiladeiro (paredes) e abismo (ponte) colidem com os pilares do torii
			if ft.Kind ~= "pinch" and ft.Kind ~= "gap" then continue end
			local top, bottom = ft.Z + 45 + m, ft.Z - (ft.Len or 150) - 25 - m
			if z <= top and z >= bottom then return true end
		end
		return false
	end
	local function ok(z, m, strict) m = m or 20; return not (isVoid(z) or isVoid(z - m) or isVoid(z + m) or (strict and inFeature(z, m))) end
	local kanji = { "速", "龍", "夢", "風", "力", "光", "星" }
	local sub = { "SPEED", "DRAGON", "DREAM", "WIND", "POWER", "LIGHT", "STAR" }

	-- torii neon sobre a pista
	local z = b.ZStart - 40
	while z > b.ZEnd + 60 do
		if ok(z, 8, true) then -- torii cruzam a pista: evitam obstáculos
			local cf, pos, fwd = frameAt(z, 0)
			local tcf = CFrame.lookAt(pos, pos - fwd) -- frente do torii voltada para quem vem da largada
			local span = W.RoadFlat + 6
			local plaque = torii(f, tcf, span, 34)
			signGui(plaque, Enum.NormalId.Front, kanji[(stats.torii % #kanji) + 1], nil, cyan)
			part(f, { Name = "ToriiNeon", Size = V3(span * 2 + 12, 0.5, 0.5), CFrame = tcf * CFrame.new(0, 35.4, -1.8), Color = cyan, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			part(f, { Name = "ToriiNeon", Size = V3(span * 2 + 6, 0.4, 0.4), CFrame = tcf * CFrame.new(0, 27, -0.9), Color = pink, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			for k = -3, 3 do -- fileira de lanternas de papel logo depois do portal
				local lz = z - 22
				local lcf = frameAt(lz, k * 7)
				paperLantern(f, lcf.Position + V3(0, 20 + math.abs(k) * 0.6, 0), false)
			end
			stats.torii += 1
			z -= 520
		else
			z -= 50 -- trecho com obstáculo: procura o próximo espaço livre logo adiante
		end
	end

	-- lanternas de pedra nas bordas
	local lz = b.ZStart - 80
	local n = 0
	while lz > b.ZEnd + 40 do
		if ok(lz, 12) then
			for _, side in ipairs({ -1, 1 }) do
				local _, p = frameAt(lz, side * (W.RoadFlat + 6))
				n += 1
				stoneLantern(f, p, n % 4 == 0)
				stats.lanterns += 1
			end
		end
		lz -= 150
	end

	-- painéis holográficos com kanji (alternando os lados)
	local pz, side = b.ZStart - 260, 1
	while pz > b.ZEnd + 120 do
		if ok(pz, 20) then
			local _, p, fwd = frameAt(pz, side * (W.RoadFlat + 16))
			local pcf = CFrame.lookAt(p, p - fwd + (-fwd:Cross(V3(0, 1, 0)) * side) * 0.6)
			part(f, { Name = "HoloPost", Size = V3(1.2, 16, 1.2), CFrame = pcf * CFrame.new(0, 8, 0), Color = Color3.fromRGB(40, 36, 60), Material = Enum.Material.Metal })
			part(f, { Name = "HoloFrame", Size = V3(12.6, 10.6, 0.4), CFrame = pcf * CFrame.new(0, 19, 0.15), Color = (stats.panels % 2 == 0) and cyan or pink, Material = Enum.Material.Neon, CanCollide = false })
			local panel = part(f, { Name = "HoloPanel", Size = V3(12, 10, 0.3), CFrame = pcf * CFrame.new(0, 19, -0.1), Color = Color3.fromRGB(16, 20, 40), Transparency = 0.25, CanCollide = false })
			local k = rng:NextInteger(1, #kanji)
			signGui(panel, Enum.NormalId.Front, kanji[k], sub[k], (stats.panels % 2 == 0) and cyan or pink)
			stats.panels += 1
			side = -side
		end
		pz -= 400
	end

	-- cerejeiras em grupos + pagodes distantes
	local tz = b.ZStart - 120
	while tz > b.ZEnd + 80 do
		local s = (rng:NextNumber() < 0.5) and -1 or 1
		local zz = tz + rng:NextNumber(-30, 30)
		if ok(zz, 25) then
			for _ = 1, rng:NextInteger(1, 3) do
				local x = W.RoadX(zz) + s * rng:NextNumber(W.RoadFlat + 20, W.RoadFlat + 70)
				local y, nrm = ground(x, zz)
				if nrm.Y > 0.8 and y < 60 then
					stats.trees += 1
					sakuraTree(f, V3(x, y - 0.3, zz + rng:NextNumber(-12, 12)), rng:NextNumber(0.9, 1.3), rng, stats.trees % 3 == 0)
				end
			end
		end
		tz -= 190
		task.wait()
	end
	for _, frac in ipairs({ 0.3, 0.75 }) do
		local zz = b.ZStart - b.Length * frac
		for _ = 1, 6 do if ok(zz, 40) then break end zz -= 60 end
		local s = (frac < 0.5) and 1 or -1
		local x = W.RoadX(zz) + s * (W.RoadFlat + 110)
		local y = ground(x, zz)
		pagoda(f, V3(x, y - 0.5, zz), 4)
		stats.pagodas += 1
	end

	-- ---------- (Beta 1.4e) SHIMENAWA: portal de corda sagrada com papéis shide, sinos e neon na entrada do bioma
	do
		local zz = b.ZStart - 14
		local _, pos, fwd = frameAt(zz, 0)
		local cf = CFrame.lookAt(pos, pos - fwd)
		local span = W.RoadFlat + 8
		local straw = Color3.fromRGB(214, 186, 120)
		for _, sd in ipairs({ -1, 1 }) do
			part(f, { Name = "ShimenawaPost", Size = V3(3, 30, 3), CFrame = cf * CFrame.new(sd * span, 15, 0), Color = Color3.fromRGB(46, 34, 44), Material = Enum.Material.Wood })
			part(f, { Name = "ShimenawaPostNeon", Size = V3(3.2, 1, 3.2), CFrame = cf * CFrame.new(sd * span, 26, 0), Color = cyan, Material = Enum.Material.Neon, CanCollide = false })
		end
		-- corda com barriga: 6 segmentos seguindo uma parábola
		local pts = {}
		for k = 0, 6 do
			local t = k / 6
			local x = -span + t * span * 2
			pts[k] = (cf * CFrame.new(x, 27 - 6 * (1 - (2 * t - 1) ^ 2), 0)).Position
		end
		for k = 1, 6 do
			local a, c = pts[k - 1], pts[k]
			part(f, { Name = "Rope", Shape = Enum.PartType.Block, Size = V3(2.6, 2.6, (c - a).Magnitude + 1.2), CFrame = CFrame.lookAt((a + c) / 2, c), Color = straw, Material = Enum.Material.Fabric, CanCollide = false })
			part(f, { Name = "RopeNeon", Size = V3(0.4, 0.4, (c - a).Magnitude), CFrame = CFrame.lookAt((a + c) / 2, c) * CFrame.new(0, 1.4, 0), Color = pink, Material = Enum.Material.Neon, CanCollide = false })
			-- shide: papel em zigue-zague pendurado (3 cunhas brancas alternadas)
			local mid = (a + c) / 2
			for z = 0, 2 do
				part(f, { Name = "Shide", Size = V3(0.15, 1.6, 1.2), CFrame = CFrame.new(mid + V3(0, -2.2 - z * 1.5, 0)) * CFrame.Angles(0, 0, math.rad((z % 2 == 0) and 12 or -12)),
					Color = Color3.new(1, 1, 1), CanCollide = false, CastShadow = false })
			end
			if k % 2 == 0 then -- sino dourado
				part(f, { Name = "Bell", Shape = Enum.PartType.Ball, Size = V3(2.2, 2.2, 2.2), CFrame = CFrame.new(c + V3(0, -3, 0)), Color = LT.Gold, Material = Enum.Material.Metal, CanCollide = false })
			end
		end
		local plaque = part(f, { Name = "ShimenawaSign", Size = V3(16, 5, 0.5), CFrame = cf * CFrame.new(0, 33, 0), Color = Color3.fromRGB(22, 16, 38), CanCollide = false })
		signGui(plaque, Enum.NormalId.Front, "神域", "SACRED ROAD", LT.Gold)
	end

	-- ---------- (Beta 1.4e) TAIKOBASHI: arcos vermelhos sobre as pontes dos abismos (sem colisão; o carro passa por baixo)
	stats.bridges = 0
	for _, ft in ipairs(F().List) do
		if ft.Biome == b and ft.Kind == "gap" and not (Config.Track and Config.Track.BridgeThemes and Config.Track.BridgeThemes[b.Id]) then -- Beta 1.6: ponte temática tem prioridade
			local zA, zB = ft.Z + 14, ft.Z - ft.Len - 14
			local A = V3(W.RoadX(zA), (ground(W.RoadX(zA), zA)), zA)
			local B = V3(W.RoadX(zB), (ground(W.RoadX(zB), zB)), zB)
			local len = (B - A).Magnitude
			local bw = W.BridgeWidth / 2 + 1.5
			local count = math.max(2, math.floor(len / 22))
			for k = 0, count do
				local p = A:Lerp(B, k / count)
				local cf = CFrame.lookAt(p, p + (B - A).Unit)
				local h = 14 + 6 * math.sin(math.pi * k / count) -- o arco sobe no meio da ponte (formato taikobashi)
				for _, sd in ipairs({ -1, 1 }) do
					part(f, { Name = "BridgePost", Size = V3(1.6, h, 1.6), CFrame = cf * CFrame.new(sd * bw, h / 2, 0), Color = LT.Torii, Material = Enum.Material.Wood, CanCollide = false })
					if k % 2 == 0 then
						part(f, { Name = "BridgeLantern", Size = V3(1.6, 2.2, 1.6), CFrame = cf * CFrame.new(sd * bw, h - 3, -1.4), Color = Color3.fromRGB(255, 150, 70), Material = Enum.Material.Neon, CanCollide = false })
					end
				end
				part(f, { Name = "BridgeArch", Size = V3(bw * 2 + 4, 1.4, 2), CFrame = cf * CFrame.new(0, h + 0.4, 0), Color = Color3.fromRGB(30, 22, 34), CanCollide = false })
				part(f, { Name = "BridgeArchNeon", Size = V3(bw * 2 + 3, 0.3, 0.3), CFrame = cf * CFrame.new(0, h - 0.5, -1), Color = cyan, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			end
			stats.bridges += 1
		end
	end

	-- ---------- (Beta 1.4e) NOBORI: bandeirolas verticais com kanji e borda neon ao longo da pista
	stats.banners = 0
	local nobKanji = { "勝", "疾", "炎", "雷", "侍", "桜" }
	local nz, nside = b.ZStart - 110, 1
	while nz > b.ZEnd + 60 do
		if ok(nz, 8) then
			local _, p, fwd = frameAt(nz, nside * (W.RoadFlat + 11))
			local cf = CFrame.lookAt(p, p - fwd)
			local col = ({ pink, cyan, Color3.fromRGB(245, 240, 250) })[stats.banners % 3 + 1]
			part(f, { Name = "NoboriPole", Size = V3(0.6, 15, 0.6), CFrame = cf * CFrame.new(0, 7.5, 0), Color = Color3.fromRGB(40, 32, 50), Material = Enum.Material.Metal })
			part(f, { Name = "NoboriBar", Size = V3(3.2, 0.4, 0.4), CFrame = cf * CFrame.new(1.4, 14.6, 0), Color = Color3.fromRGB(40, 32, 50), CanCollide = false })
			local cloth = part(f, { Name = "Nobori", Size = V3(2.8, 10, 0.15), CFrame = cf * CFrame.new(1.6, 9.2, 0), Color = col, Material = Enum.Material.Fabric, CanCollide = false })
			part(f, { Name = "NoboriNeon", Size = V3(0.25, 10, 0.2), CFrame = cf * CFrame.new(3.05, 9.2, 0), Color = (col == cyan) and pink or cyan, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 20; sg.Parent = cloth
			local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Font = Enum.Font.FredokaOne; t.TextScaled = true
			t.Text = nobKanji[stats.banners % #nobKanji + 1]; t.TextColor3 = Color3.fromRGB(30, 20, 40); t.Parent = sg
			stats.banners += 1
			nside = -nside
		end
		nz -= 95
	end

	-- ---------- (Beta 1.4e) HOLOGRAMAS: kanji gigantes girando no céu (o cliente gira: tag "HoloSpin")
	stats.holos = 0
	local holoKanji = { "龍", "夢", "光" }
	for k, frac in ipairs({ 0.18, 0.5, 0.82 }) do
		local zz = b.ZStart - b.Length * frac
		local sd = (k % 2 == 0) and -1 or 1
		local x = W.RoadX(zz) + sd * (W.RoadFlat + 90)
		local y = ground(x, zz) + 70
		local col = (k % 2 == 0) and pink or cyan
		local holo = part(f, { Name = "HoloKanji", Size = V3(36, 36, 0.4), CFrame = CFrame.new(x, y, zz), Color = col, Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local sg = Instance.new("SurfaceGui"); sg.Face = face; sg.LightInfluence = 0; sg.Brightness = 2
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 12; sg.Parent = holo
			local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Font = Enum.Font.FredokaOne; t.TextScaled = true
			t.Text = holoKanji[k]; t.TextColor3 = col; t.TextTransparency = 0.1; t.Parent = sg
			local st = Instance.new("UIStroke"); st.Color = Color3.new(1, 1, 1); st.Thickness = 3; st.Transparency = 0.3; st.Parent = t
		end
		disc(f, "HoloRing", 22, 0.6, V3(x, y - 24, zz), col, Enum.Material.Neon, { CanCollide = false, CanQuery = false, Transparency = 0.2 })
		part(f, { Name = "HoloBeam", Size = V3(2, 46, 2), CFrame = CFrame.new(x, y - 47, zz), Color = col, Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, CanQuery = false })
		CollectionService:AddTag(holo, "HoloSpin")
		stats.holos += 1
	end

	f.Parent = root
	return ("%s: %d torii, %d lanternas, %d painéis, %d cerejeiras, %d pagodes, %d pontes taikobashi, %d nobori, %d hologramas + shimenawa (%d instâncias)"):format(b.Name, stats.torii, stats.lanterns, stats.panels, stats.trees, stats.pagodas, stats.bridges, stats.banners, stats.holos, #f:GetDescendants())
end

-- (Beta 1.5) QUIOSQUES "LUCKY WHEEL" no lobby (substituem as máquinas de venda da 1.4e, removidas a pedido do dono).
-- Dois quiosques simétricos ao lado da praça, virados para o centro. Base com tag "WheelKiosk" (o cliente põe o
-- prompt "Spin the Wheel" e abre o painel da roleta). O disco tem tag "LobbyWheelDisc" (o cliente gira devagar).
function WorldBuilder.BuildLobbyWheels(parent, at)
	local f = Instance.new("Folder"); f.Name = "LuckyWheels"; f.Parent = parent
	local prizes = Config.Wheel and Config.Wheel.Prizes or {}
	for _, sd in ipairs({ -1, 1 }) do
		local p = at(sd * 60, 0, 40)
		local cf = CFrame.lookAt(p, p + V3(-sd, 0, 0)) -- frente para o centro do lobby
		local dark = Color3.fromRGB(30, 22, 46)
		local basePart = part(f, { Name = "WheelStage", Size = V3(12, 1.2, 12), CFrame = cf * CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(70, 52, 100), Material = Enum.Material.Marble })
		CollectionService:AddTag(basePart, "WheelKiosk")
		part(f, { Name = "WheelStageTrim", Size = V3(12.5, 0.3, 12.5), CFrame = cf * CFrame.new(0, 1.0, 0), Color = LT.Gold, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		for _, sx in ipairs({ -1, 1 }) do
			part(f, { Name = "WheelPost", Size = V3(1.2, 14, 1.2), CFrame = cf * CFrame.new(sx * 5.4, 8, 1.5), Color = dark, Material = Enum.Material.Metal })
		end
		-- disco: cilindro com o eixo apontando para quem olha (frente = -Z local)
		local center = cf * CFrame.new(0, 10.5, 0.6)
		local disc = part(f, { Name = "WheelDisc", Shape = Enum.PartType.Cylinder, Size = V3(0.8, 11, 11), CFrame = center * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(245, 240, 250), Material = Enum.Material.SmoothPlastic, CanCollide = false })
		CollectionService:AddTag(disc, "LobbyWheelDisc")
		local n = math.max(#prizes, 8)
		for k = 0, n - 1 do -- fatias coloridas: raios grossos com a cor de cada prêmio
			local ang = k / n * math.pi * 2
			local col = prizes[k + 1] and prizes[k + 1].Color or LT.Sakura
			local spoke = part(f, { Name = "WheelSlice", Size = V3(2.6, 4.8, 0.2), CFrame = center * CFrame.Angles(0, 0, ang) * CFrame.new(0, 2.9, -0.5),
				Color = col, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			spoke:SetAttribute("Angle", ang)
		end
		part(f, { Name = "WheelRim", Shape = Enum.PartType.Cylinder, Size = V3(0.6, 11.8, 11.8), CFrame = center * CFrame.new(0, 0, 0.25) * CFrame.Angles(0, math.rad(90), 0),
			Color = LT.Gold, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		part(f, { Name = "WheelHub", Shape = Enum.PartType.Ball, Size = V3(1.8, 1.8, 1.8), CFrame = center * CFrame.new(0, 0, -0.8), Color = LT.Gold, Material = Enum.Material.Metal, CanCollide = false })
		local pointer = Instance.new("WedgePart")
		pointer.Name = "WheelPointer"; pointer.Anchored = true; pointer.CanCollide = false; pointer.Color = Color3.fromRGB(230, 50, 60); pointer.Material = Enum.Material.Neon
		pointer.Size = V3(0.6, 1.6, 1.4); pointer.CFrame = center * CFrame.new(0, 6.4, -0.6) * CFrame.Angles(math.rad(180), 0, 0); pointer.Parent = f
		local sign = part(f, { Name = "WheelSign", Size = V3(12, 3, 0.4), CFrame = cf * CFrame.new(0, 19, 0.4), Color = Color3.fromRGB(22, 16, 38), CanCollide = false })
		signGui(sign, Enum.NormalId.Front, "🎡 LUCKY WHEEL", "free spin every 8 hours!", LT.Gold)
		local glow = part(f, { Name = "WheelGlow", Size = V3(1, 1, 1), CFrame = center * CFrame.new(0, 0, -4), Transparency = 1, CanCollide = false, CanQuery = false })
		pointLight(glow, Color3.fromRGB(255, 220, 160), 18, 1.2)
	end
	return f
end

-- ===================================================================== DESAFIOS DA PISTA (Beta 1.6)
--[[
	WorldBuilder.BuildChallenges(index) — idempotente; não mexe no terreno nem nos obstáculos sorteados.
	  * PASSARELA ELEVADA (Map.Drivable.<bioma>.Skyways): sobe em rampa suave (Config.Track.Skyway.Incline studs),
	    segue reta (Length) a Height studs de altura e desce. Ocupa MEIA pista (lado alternado): quem fica embaixo
	    passa por um PAD DE LENTIDÃO => escolha de rota. Peças na pasta Drivable => a suspensão do carro (raycast) as enxerga.
	  * PADS DE LENTIDÃO (Map.Props.<bioma>.Challenges, tag "SlowPad"): meia pista, alternando lados, a cada ~Every studs,
	    + um antes de cada ponte de abismo. O DriveController reduz a velocidade máxima (SpeedMult) por Duration s.
	  * PONTE TEMÁTICA (Config.Track.BridgeThemes[bioma]): reveste as pontes dos abismos (piso, grades, pilares com
	    esferas iluminadas, portais nas pontas). Bioma 1 = ponte de TORNEIO de artes marciais (tema Dragon Ball Z).
	Nunca coloca nada sobre obstáculos/abismos (usa a lista de obstáculos determinística F().List).
]]
local function frameAtLateral(z, lateral)
	local cf, pos, fwd = frameAt(z, lateral)
	return cf, pos, fwd
end

function WorldBuilder.BuildChallenges(index)
	local b = biomes[index or 1]
	local T = Config.Track
	local map = workspace.Map
	local drv = map.Drivable:FindFirstChild(b.Id) or Instance.new("Folder", map.Drivable); drv.Name = b.Id
	local prp = map.Props:FindFirstChild(b.Id) or Instance.new("Folder", map.Props); prp.Name = b.Id
	for _, f in ipairs({ drv:FindFirstChild("Skyways"), prp:FindFirstChild("Challenges") }) do if f then f:Destroy() end end
	local sky = Instance.new("Folder"); sky.Name = "Skyways"
	local ch = Instance.new("Folder"); ch.Name = "Challenges"
	local stats = { skyways = 0, slow = 0, bridges = 0 }
	local accent = b.Style and b.Style.Accent or Color3.fromRGB(90, 230, 255)

	local function busy(z0, z1) -- algum obstáculo/abismo entre z0 (mais perto da largada) e z1?
		-- só o que colide de verdade: abismo/ponte, paredes do desfiladeiro, troncos e lombadas.
		-- (rampas e slalom estão desligados em Config.Track; morros/ondulações do terreno a passarela acompanha)
		local blocking = { gap = true, pinch = true, logs = true, bumps = true,
			ramp = T.Ramps == true, slalom = T.Slalom == true }
		for _, ft in ipairs(F().List) do
			if blocking[ft.Kind] then
				local len = (ft.Kind == "gap" and ft.Len) or (ft.Kind == "pinch" and 130) or 70
				local top, bottom = ft.Z + 40, ft.Z - len - 25
				if not (bottom > z0 or top < z1) then return true end
			end
		end
		for z = z1, z0, 20 do if isVoid(z) then return true end end
		return false
	end

	local function slowPad(z, lateral)
		local cf = frameAtLateral(z, lateral)
		local S = T.SlowPad
		local p = part(ch, { Name = "SlowPad", Size = V3(S.Width, 0.5, S.Length), CFrame = cf * CFrame.new(0, 0.45, 0), Color = Color3.fromRGB(200, 40, 70),
			Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Transparency = 0.15 })
		signGui(p, Enum.NormalId.Top, "▼▼▼", "SLOW", Color3.fromRGB(255, 230, 230))
		for _, g in ipairs(p:GetDescendants()) do if g:IsA("TextLabel") then g.Rotation = 180 end end
		CollectionService:AddTag(p, "SlowPad")
		stats.slow += 1
	end

	-- ---------- passarelas elevadas
	local K = T.Skyway
	local total = K.Incline * 2 + K.Length
	local z = b.ZStart - 220
	local side = 1
	while z - total > b.ZEnd + 260 do
		if busy(z + 30, z - total - 30) then
			z -= 60
		else
			local lat = side * (W.RoadFlat - K.Width / 2 - 2)
			local seg = 10
			local prev
			for s = 0, total, seg do
				local h
				if s < K.Incline then h = K.Height * (s / K.Incline)
				elseif s <= K.Incline + K.Length then h = K.Height
				else h = K.Height * math.max(0, (total - s) / K.Incline) end
				local _, pos = frameAtLateral(z - s, lat)
				local p = pos + V3(0, h, 0)
				if prev then
					local mid, len = (prev + p) / 2, (p - prev).Magnitude
					local cf = CFrame.lookAt(mid, p)
					part(sky, { Name = "SkywayDeck", Size = V3(K.Width, 1.6, len + 0.8), CFrame = cf * CFrame.new(0, -0.8, 0), Color = Color3.fromRGB(58, 60, 80), Material = Enum.Material.Concrete })
					part(sky, { Name = "SkywayStripe", Size = V3(0.6, 0.1, len + 0.8), CFrame = cf * CFrame.new(0, 0.05, 0), Color = accent, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
					for _, e in ipairs({ -1, 1 }) do
						part(ch, { Name = "SkywayRail", Size = V3(0.6, 0.6, len + 0.8), CFrame = cf * CFrame.new(e * (K.Width / 2 - 0.3), 0.8, 0), Color = accent, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
					end
					if h >= K.Height - 0.01 and (s % 30 == 0) then -- pilares sob o trecho alto
						for _, e in ipairs({ -1, 1 }) do
							local base = (cf * CFrame.new(e * (K.Width / 2 - 2), 0, 0)).Position
							part(ch, { Name = "SkywayPillar", Size = V3(2, h + 2, 2), CFrame = CFrame.new(base - V3(0, (h + 2) / 2, 0)), Color = Color3.fromRGB(44, 44, 60), Material = Enum.Material.Metal })
						end
					end
				end
				prev = p
			end
			local signCF = frameAtLateral(z + 30, lat)
			local post = part(ch, { Name = "SkywaySign", Size = V3(14, 4, 0.5), CFrame = signCF * CFrame.new(0, 16, 0) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(20, 20, 30), CanCollide = false })
			signGui(post, Enum.NormalId.Front, "⬆ SKYWAY", "go up or take the slow lane!", accent)
			slowPad(z - K.Incline - K.Length / 2, -side * (W.RoadFlat / 2)) -- faixa de baixo tem lentidão
			stats.skyways += 1
			side = -side
			z -= total + K.Every
		end
	end

	-- ---------- pads de lentidão espalhados (meia pista, lados alternados) + antes de cada abismo
	local S = T.SlowPad
	local sz, sl = b.ZStart - 380, -1
	while sz > b.ZEnd + 200 do
		if not busy(sz + 20, sz - 20) then
			local nearSky = false
			for _, d in ipairs(sky:GetChildren()) do if math.abs(d.Position.Z - sz) < 60 then nearSky = true; break end end
			if not nearSky then slowPad(sz, sl * (W.RoadFlat / 2)); sl = -sl end
		end
		sz -= S.Every
	end
	for _, ft in ipairs(F().List) do
		if ft.Biome == b and ft.Kind == "gap" and not isVoid(ft.Z + 120) then slowPad(ft.Z + 120, 0) end
	end

	-- ---------- pontes temáticas
	local theme = T.BridgeThemes and T.BridgeThemes[b.Id]
	if theme then
		local deco = Instance.new("Folder"); deco.Name = "ThemedBridges"; deco.Parent = ch
		for _, ft in ipairs(F().List) do
			if ft.Biome == b and ft.Kind == "gap" then
				local zA, zB = ft.Z + 14, ft.Z - ft.Len - 14
				-- reveste as peças existentes da ponte (piso, faixa, grades)
				for _, root in ipairs({ drv, prp }) do
					for _, p in ipairs(root:GetChildren()) do
						if p:IsA("BasePart") and p.Position.Z <= zA + 5 and p.Position.Z >= zB - 5 then
							if p.Name == "BridgeDeck" then p.Color = theme.Deck; p.Material = theme.DeckMaterial
							elseif p.Name == "BridgeStripe" then p.Color = theme.Stripe
							elseif p.Name == "BridgeRail" then p.Color = theme.Rail; p.Material = Enum.Material.SmoothPlastic
							elseif p.Name == "BridgeRailNeon" then p.Color = theme.Stripe end
						end
					end
				end
				local A = V3(W.RoadX(zA), (ground(W.RoadX(zA), zA)), zA)
				local B = V3(W.RoadX(zB), (ground(W.RoadX(zB), zB)), zB)
				local dir = (B - A).Unit
				local bw = W.BridgeWidth / 2 + 1.6
				local len = (B - A).Magnitude
				local n = math.max(2, math.floor(len / 16))
				for k = 0, n do -- pilares com esferas iluminadas nas duas bordas
					local p = A:Lerp(B, k / n)
					local cf = CFrame.lookAt(p, p + dir)
					for _, e in ipairs({ -1, 1 }) do
						part(deco, { Name = "BridgePillar", Size = V3(1.8, 5, 1.8), CFrame = cf * CFrame.new(e * bw, 2.5, 0), Color = theme.Pillar, CanCollide = false })
						local orb = part(deco, { Name = "BridgeOrb", Shape = Enum.PartType.Ball, Size = V3(2, 2, 2), CFrame = cf * CFrame.new(e * bw, 6, 0), Color = theme.Orb,
							Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
						if theme.OrbText then
							local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 40; sg.Parent = orb
							local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.TextScaled = true; t.Font = Enum.Font.FredokaOne
							t.Text = theme.OrbText; t.TextColor3 = Color3.fromRGB(220, 40, 30); t.Parent = sg
						end
					end
				end
				for _, endP in ipairs({ { A, dir }, { B, -dir } }) do -- portais nas duas pontas
					local cf = CFrame.lookAt(endP[1], endP[1] - endP[2])
					for _, e in ipairs({ -1, 1 }) do
						part(deco, { Name = "BridgeGatePost", Size = V3(3, 22, 3), CFrame = cf * CFrame.new(e * (bw + 1.5), 11, 0), Color = theme.Pillar, Material = Enum.Material.SmoothPlastic })
					end
					local beam = part(deco, { Name = "BridgeGateBeam", Size = V3(bw * 2 + 8, 4, 2.4), CFrame = cf * CFrame.new(0, 22, 0), Color = theme.Beam, CanCollide = false })
					signGui(beam, Enum.NormalId.Front, theme.Title, theme.Sub, theme.Orb)
				end
				stats.bridges += 1
			end
		end
	end

	sky.Parent = drv
	ch.Parent = prp
	return ("%s: %d passarelas, %d pads de lentidão, %d pontes temáticas (%d instâncias)"):format(b.Name, stats.skyways, stats.slow, stats.bridges, #sky:GetDescendants() + #ch:GetDescendants())
end

-- ===================================================================== OBSTÁCULOS ANIMADOS (Beta 1.8)
--[[
	WorldBuilder.BuildHazards(index) — idempotente (pasta Map.Props.<bioma>.Hazards; rodar de novo substitui).
	Cada obstáculo = Model com tag "Hazard" (ModelStreamingMode Atomic) e atributos:
	  Kind (pendulum/sweeper/piston/laser/geyser), Period, Phase, Origin (CFrame no centro da pista, olhando para a frente)
	  + parâmetros do tipo (PivotH, Amp, Reach, Duty, JetH).
	Peças que MEXEM: atributo Move (papel) + Rel (CFrame relativo ao pivô/Origin na pose zero) [+ Delay].
	Peças que MACHUCAM: atributo Hit = true (CanCollide false: a batida é detectada pelo Client.HazardController).
	O servidor NÃO anima nada: o cliente calcula a pose com workspace:GetServerTimeNow() (todos veem igual).
	Posições: a cada Config.Track.Hazards.Every studs, longe de abismos/paredões/troncos/lombadas, passarelas,
	pads, do começo do bioma e do ovo gigante. Tipos por bioma: Config.Track.Hazards.Kinds[bioma] (em rodízio).
]]
function WorldBuilder.BuildHazards(index)
	local b = biomes[index or 1]
	local HZ = Config.Track.Hazards
	local map = workspace.Map
	local prp = map.Props:FindFirstChild(b.Id)
	if not prp then prp = Instance.new("Folder"); prp.Name = b.Id; prp.Parent = map.Props end
	local old = prp:FindFirstChild("Hazards"); if old then old:Destroy() end
	local folder = Instance.new("Folder"); folder.Name = "Hazards"
	local S = b.Style
	local col, acc, mat = S.Color, S.Accent, S.Material
	local dark = Color3.fromRGB(36, 34, 46)
	local RF = W.RoadFlat
	local rng = Random.new(b.Order * 4243)
	local kinds = HZ.Kinds[b.Id] or { "pendulum", "sweeper", "piston", "laser", "geyser" }
	local stats = {}

	-- pontos ocupados (passarelas, pads, ponte temática) para não empilhar desafios
	local taken = {}
	for _, root in ipairs({ map.Drivable:FindFirstChild(b.Id), prp, map.BoostPads:FindFirstChild(b.Id) }) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("BasePart") and (d.Name == "SkywayDeck" or d.Name == "SlowPad" or d.Name == "BoostPad" or d.Name == "BridgeGatePost") then
					table.insert(taken, d.Position.Z)
				end
			end
		end
	end
	-- torii/shimenawa/hologramas: só os obstáculos ALTOS (pêndulo, pistões) precisam desviar deles
	local tall = {}
	local jt = prp:FindFirstChild("JapanTech")
	if jt then
		for _, d in ipairs(jt:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name == "ToriiPillar" or d.Name == "ShimenawaPost" or d.Name == "HoloPost") then table.insert(tall, d.Position.Z) end
		end
	end
	local function nearTall(z) for _, tz in ipairs(tall) do if math.abs(tz - z) < 34 then return true end end return false end
	-- desfiladeiros (pinch) cujas paredes NÃO existem mais no mapa não bloqueiam (eram "fantasmas" no começo do bioma 1)
	local pinchWalls = {}
	for _, d in ipairs(prp:GetChildren()) do if d:IsA("BasePart") and d.Name == "PinchWall" then table.insert(pinchWalls, d.Position.Z) end end
	local function pinchExists(fz)
		for _, pz in ipairs(pinchWalls) do if pz <= fz + 10 and pz >= fz - 140 then return true end end
		return false
	end
	local function busy(z0, z1)
		local blocking = { gap = true, pinch = true, logs = true, bumps = true } -- gelo NÃO bloqueia (laser no gelo = desafio extra)
		for _, ft in ipairs(F().List) do
			if blocking[ft.Kind] and ft.Biome == b and (ft.Kind ~= "pinch" or pinchExists(ft.Z)) then
				local len = (ft.Kind == "gap" and ft.Len) or ((ft.Kind == "pinch" or ft.Kind == "ice") and 130) or 70
				if not (ft.Z - len - 25 > z0 or ft.Z + 40 < z1) then return true end
			end
		end
		for z = z1, z0, 15 do if isVoid(z) then return true end end
		for _, tz in ipairs(taken) do if tz <= z0 + 25 and tz >= z1 - 25 then return true end end
		return false
	end

	local function newHazard(kind, origin, extra)
		local m = Instance.new("Model"); m.Name = "Hazard_" .. kind
		m:SetAttribute("Kind", kind)
		m:SetAttribute("Period", HZ.Periods[kind] or 3)
		m:SetAttribute("Phase", rng:NextNumber())
		m:SetAttribute("Origin", origin)
		for k, v in pairs(extra or {}) do m:SetAttribute(k, v) end
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		return m
	end
	local function mover(m, role, pivot, props, hit)
		local p = part(m, props)
		p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p:SetAttribute("Move", role)
		p:SetAttribute("Rel", pivot:ToObjectSpace(p.CFrame))
		if hit then p:SetAttribute("Hit", true) end
		return p
	end
	local function static(m, props) local p = part(m, props); return p end
	local function warnStripes(m, origin) -- faixas de aviso no chão antes do obstáculo
		for _, dz in ipairs({ 26, 32 }) do
			static(m, { Name = "WarnStripe", Size = V3(RF * 2 - 4, 0.12, 2), CFrame = origin * CFrame.new(0, 0.08, dz), Color = acc, Material = Enum.Material.Neon,
				CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 0.25 })
		end
	end

	local BUILD = {}
	function BUILD.pendulum(origin)
		local H = 29
		local m = newHazard("pendulum", origin, { PivotH = H, Amp = 62 })
		for _, s in ipairs({ -1, 1 }) do
			static(m, { Name = "Post", Size = V3(3.2, H + 2, 3.2), CFrame = origin * CFrame.new(s * (RF + 5), (H + 2) / 2, 0), Color = col, Material = mat })
			static(m, { Name = "PostCap", Size = V3(4.4, 1.2, 4.4), CFrame = origin * CFrame.new(s * (RF + 5), H + 2.4, 0), Color = acc, Material = Enum.Material.Neon, CanCollide = false })
		end
		static(m, { Name = "Beam", Size = V3(RF * 2 + 14, 3, 3.4), CFrame = origin * CFrame.new(0, H + 1, 0), Color = col, Material = mat, CanCollide = false })
		local pivot = origin * CFrame.new(0, H, 0)
		mover(m, "swing", pivot, { Name = "Arm", Size = V3(1.1, 21, 1.1), CFrame = pivot * CFrame.new(0, -10.5, 0), Color = dark, Material = Enum.Material.Metal })
		mover(m, "swing", pivot, { Name = "Hammer", Shape = Enum.PartType.Ball, Size = V3(8.5, 8.5, 8.5), CFrame = pivot * CFrame.new(0, -24.5, 0), Color = col, Material = mat }, true)
		mover(m, "swing", pivot, { Name = "HammerRing", Shape = Enum.PartType.Cylinder, Size = V3(1.2, 9.2, 9.2), CFrame = pivot * CFrame.new(0, -24.5, 0),
			Color = acc, Material = Enum.Material.Neon })
		warnStripes(m, origin)
		return m
	end
	function BUILD.sweeper(origin)
		local m = newHazard("sweeper", origin, {})
		static(m, { Name = "Base", Shape = Enum.PartType.Cylinder, Size = V3(0.4, 12, 12), CFrame = origin * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = dark, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
		local hub = static(m, { Name = "Hub", Shape = Enum.PartType.Cylinder, Size = V3(4.4, 3.4, 3.4), CFrame = origin * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = acc, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		hub:SetAttribute("Hit", true)
		local len = RF * 2 - 22 -- as duas bordas da pista ficam LIVRES (~11 studs de cada lado)
		mover(m, "spin", origin, { Name = "Blade", Size = V3(len, 1.8, 2.2), CFrame = origin * CFrame.new(0, 2, 0), Color = col, Material = mat }, true)
		for _, s in ipairs({ -1, 1 }) do
			mover(m, "spin", origin, { Name = "BladeTip", Size = V3(2.4, 2.2, 2.6), CFrame = origin * CFrame.new(s * (len / 2 - 1), 2, 0), Color = acc, Material = Enum.Material.Neon })
		end
		warnStripes(m, origin)
		return m
	end
	function BUILD.piston(origin)
		local reach = RF - 2
		local m = newHazard("piston", origin, { Reach = reach })
		local bw = RF + 2
		for _, s in ipairs({ -1, 1 }) do
			local cx = s * (RF + bw / 2 + 1)
			static(m, { Name = "Housing", Size = V3(bw + 2, 9, 11), CFrame = origin * CFrame.new(s * (RF + bw / 2 + 2), 4.5, 0), Color = dark, Material = Enum.Material.Metal })
			static(m, { Name = "HousingTrim", Size = V3(0.6, 9.2, 11.2), CFrame = origin * CFrame.new(s * (RF + 1.2), 4.5, 0), Color = acc, Material = Enum.Material.Neon, CanCollide = false })
			mover(m, s < 0 and "pistonL" or "pistonR", origin, { Name = "Ram", Size = V3(bw, 6, 8.6), CFrame = origin * CFrame.new(cx, 3.2, 0), Color = col, Material = mat }, true)
			mover(m, s < 0 and "pistonL" or "pistonR", origin, { Name = "RamFace", Size = V3(0.5, 6.2, 8.8), CFrame = origin * CFrame.new(cx - s * (bw / 2), 3.2, 0),
				Color = acc, Material = Enum.Material.Neon })
		end
		warnStripes(m, origin)
		return m
	end
	function BUILD.laser(origin)
		local m = newHazard("laser", origin, { Duty = 0.5 })
		for _, s in ipairs({ -1, 1 }) do
			static(m, { Name = "Emitter", Size = V3(2.6, 8, 2.6), CFrame = origin * CFrame.new(s * (RF + 3), 4, 0), Color = dark, Material = Enum.Material.Metal })
			static(m, { Name = "EmitterCap", Size = V3(3, 0.8, 3), CFrame = origin * CFrame.new(s * (RF + 3), 8.4, 0), Color = acc, Material = Enum.Material.Neon, CanCollide = false })
		end
		for k, y in ipairs({ 1.3, 3.1, 4.9 }) do
			mover(m, "beam", origin, { Name = "Beam" .. k, Size = V3(RF * 2 + 4, 0.45, 0.45), CFrame = origin * CFrame.new(0, y, 0), Color = Color3.fromRGB(255, 50, 70),
				Material = Enum.Material.Neon }, true)
		end
		warnStripes(m, origin)
		return m
	end
	function BUILD.geyser(origin)
		local jetCol = (b.Id == "volcano") and Color3.fromRGB(255, 110, 20) or (b.Id == "tundra") and Color3.fromRGB(200, 240, 255)
			or (b.Id == "dunes") and Color3.fromRGB(240, 200, 120) or acc
		local m = newHazard("geyser", origin, { JetH = 16 })
		for k, x in ipairs({ -19, 0, 19 }) do
			local base = origin * CFrame.new(x, 0, 0)
			static(m, { Name = "Vent", Shape = Enum.PartType.Cylinder, Size = V3(0.5, 9, 9), CFrame = base * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color = dark, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
			static(m, { Name = "VentRing", Shape = Enum.PartType.Cylinder, Size = V3(0.55, 7, 7), CFrame = base * CFrame.new(0, 0.22, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color = jetCol, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
			local jet = mover(m, "jet", origin, { Name = "Jet" .. k, Shape = Enum.PartType.Cylinder, Size = V3(0.2, 6.4, 6.4),
				CFrame = base * CFrame.Angles(0, 0, math.rad(90)), Color = jetCol, Material = Enum.Material.Neon, Transparency = 0.2 }, true)
			jet:SetAttribute("Delay", (k - 1) / 3)
		end
		warnStripes(m, origin)
		return m
	end

	local Hz = HZ
	local eggZ = Config.BiomeEggZ(b)
	local z = b.ZStart - Hz.Start
	local n = 0
	while z > eggZ + Hz.EggClear do
		if busy(z + 30, z - 30) then
			z -= 15
		else
			n += 1
			local kind = kinds[(n - 1) % #kinds + 1]
			if nearTall(z) and (kind == "pendulum" or kind == "piston") then -- perto de torii: troca por um obstáculo baixo
				for k = 1, #kinds do
					local alt = kinds[(n - 1 + k) % #kinds + 1]
					if alt ~= "pendulum" and alt ~= "piston" then kind = alt; break end
				end
				if kind == "pendulum" or kind == "piston" then kind = "laser" end
			end
			local origin = frameAt(z, 0)
			local m = BUILD[kind](origin)
			CollectionService:AddTag(m, "Hazard")
			m.Parent = folder
			stats[kind] = (stats[kind] or 0) + 1
			z -= Hz.Every
		end
	end
	folder.Parent = prp
	local parts = {}
	for k, v in pairs(stats) do table.insert(parts, k .. "=" .. v) end
	table.sort(parts)
	return ("%s: %d obstáculos (%s)"):format(b.Name, n, table.concat(parts, " "))
end

-- Beta 1.8: afina os boost pads JÁ EXISTENTES (sem regenerar o bioma): mantém um a cada Config.Track.BoostMinGap studs.
function WorldBuilder.ThinBoostPads(index)
	local b = biomes[index or 1]
	local f = workspace.Map.BoostPads:FindFirstChild(b.Id)
	if not f then return b.Name .. ": sem pasta" end
	local pads = {}
	for _, p in ipairs(f:GetChildren()) do if p:IsA("BasePart") then table.insert(pads, p) end end
	table.sort(pads, function(x, y) return x.Position.Z > y.Position.Z end) -- da largada para o fim
	local gap = Config.Track.BoostMinGap or 650
	local lastZ, kept, removed = math.huge, 0, 0
	for _, p in ipairs(pads) do
		if lastZ - p.Position.Z >= gap then lastZ = p.Position.Z; kept += 1 else p:Destroy(); removed += 1 end
	end
	return ("%s: boosts %d -> %d"):format(b.Name, kept + removed, kept)
end
-- Beta 1.8: VARAL das lanternas de papel (Map.Props.<bioma>.JapanTech.LanternGarlands). As lanternas flutuavam
-- sobre a pista sem nada segurando; vistas de cima (câmera alta) pareciam uma "bola" no chão. Agora cada fileira
-- tem 2 postes de madeira fora da pista e um fio passando pelo topo de cada lanterna. Rodar de novo substitui.
-- (Chamar depois de BuildJapanTechDecor(i), que é quem cria as lanternas.)
function WorldBuilder.BuildLanternGarlands(index)
	local b = biomes[index or 1]
	local jt = workspace.Map.Props:FindFirstChild(b.Id) and workspace.Map.Props[b.Id]:FindFirstChild("JapanTech")
	if not jt then return b.Name .. ": sem JapanTech" end
	local old = jt:FindFirstChild("LanternGarlands"); if old then old:Destroy() end
	local g = Instance.new("Folder"); g.Name = "LanternGarlands"
	local function seg(a, c, thick, color, name)
		local mid, len = (a + c) / 2, (c - a).Magnitude
		part(g, { Name = name or "Wire", Size = V3(thick, thick, len), CFrame = CFrame.lookAt(mid, c), Color = color, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	end
	local rows = {}
	for _, m in ipairs(jt:GetChildren()) do
		if m.Name == "PaperLantern" and m:FindFirstChild("CapTop") then
			local cf = m:GetBoundingBox()
			local entry = { Top = m.CapTop.Position + V3(0, 0.2, 0), Off = cf.X - W.RoadX(cf.Z) }
			local row
			for _, r in ipairs(rows) do if math.abs(r.Z - cf.Z) < 12 then row = r; break end end
			if not row then row = { Z = cf.Z, L = {} }; table.insert(rows, row) end
			table.insert(row.L, entry)
		end
	end
	local wireCol, wood = Color3.fromRGB(45, 30, 28), Color3.fromRGB(120, 72, 44)
	for _, r in ipairs(rows) do
		table.sort(r.L, function(a, c) return a.Off < c.Off end)
		local fwd = roadForward(r.Z)
		local right = fwd:Cross(V3(0, 1, 0))
		local hTop = 0
		for _, l in ipairs(r.L) do hTop = math.max(hTop, l.Top.Y) end
		local poles = {}
		for _, side in ipairs({ -1, 1 }) do
			local base = V3(W.RoadX(r.Z), 0, r.Z) + right * side * (W.RoadFlat + 7)
			local gy = ground(base.X, base.Z)
			local topY = hTop + 3
			part(g, { Name = "LanternPole", Size = V3(1.2, topY - gy, 1.2), CFrame = CFrame.new(base.X, (gy + topY) / 2, base.Z), Color = wood, Material = Enum.Material.Wood })
			part(g, { Name = "LanternPoleCap", Size = V3(2, 0.6, 2), CFrame = CFrame.new(base.X, topY + 0.3, base.Z), Color = Color3.fromRGB(200, 40, 40), CanCollide = false })
			poles[side] = V3(base.X, topY, base.Z)
		end
		local pts = { poles[-1] }
		for _, l in ipairs(r.L) do table.insert(pts, l.Top) end
		table.insert(pts, poles[1])
		if (poles[-1] - r.L[1].Top).Magnitude > (poles[1] - r.L[1].Top).Magnitude then pts[1], pts[#pts] = pts[#pts], pts[1] end
		for i = 1, #pts - 1 do seg(pts[i], pts[i + 1], 0.22, wireCol) end
		for _, l in ipairs(r.L) do seg(l.Top, l.Top + V3(0, 0.6, 0), 0.18, wireCol, "Hook") end
	end
	g.Parent = jt
	return ("%s: %d fileiras de lanternas com varal"):format(b.Name, #rows)
end
return WorldBuilder
