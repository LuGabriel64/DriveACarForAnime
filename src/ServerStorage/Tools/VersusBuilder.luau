--[[
	VersusBuilder  (ServerStorage.Tools.VersusBuilder)                                           Beta 1.9
	=====================================================================================================
	Constrói as ilhas do DESAFIO 1v1 em Workspace.Map.Versus. FERRAMENTA de edição (roda no Command Bar / MCP em
	modo Edit, não durante o jogo). É um complemento do WorldBuilder, separado para não aumentar aquele arquivo;
	o WorldBuilder expõe os atalhos WorldBuilder.BuildVersusHall() e WorldBuilder.BuildArena(i).

	    VersusBuilder.BuildHall()     -> Workspace.Map.Versus.Hall        (Config.Versus.HallOrigin)
	    VersusBuilder.BuildArena(i)   -> Workspace.Map.Versus.Arena_<Id>  (Config.Versus.Battle.Arenas[i].Origin)
	    VersusBuilder.BuildAll()      -> tudo (hall + as 3 arenas)
	Cada função APAGA a sua pasta e refaz (idempotente). Nada fora de Map.Versus é tocado.

	VERSUS HALL: sala de espera a pé (piso, mureta de neon, paredes invisíveis, letreiro) com dois balcões:
	    F1 SHOP e VICTORY SHOP. Cada balcão tem um ProximityPrompt com a tag "VersusShop" e o atributo
	    ShopKind ("F1" | "Fx"); quem abre a loja é o cliente (Client.VersusUI).
	ARENAS: ringue de 44 x 44 com o piso em Origin.Y + Config.Versus.Battle.RingTop e uma plateia atrás (+Z), onde
	    ficam os avatares dos jogadores (SpectatorOffsets). Os lutadores são modelos LOCAIS do cliente (BattleUI).
	    Temas ORIGINAIS: sky_ring (torneio nas nuvens), moon_dojo (dojo com lua cheia), lava_arena (coliseu de lava).

	Depois de mudar algo aqui: rode BuildAll() e registre no 01_ChangeLog.
]]
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(RS.Shared.Config)
local CarFactory = require(RS.Shared.CarFactory)

local VersusBuilder = {}
local C = Color3.fromRGB
local T = Config.Lobby.Theme

local function root()
	local map = workspace:FindFirstChild("Map") or workspace
	local f = map:FindFirstChild("Versus")
	if not f then f = Instance.new("Folder"); f.Name = "Versus"; f.Parent = map end
	return f
end
local function fresh(name)
	local r = root()
	local old = r:FindFirstChild(name)
	if old then old:Destroy() end
	local f = Instance.new("Folder"); f.Name = name
	return f, r
end

-- Peça ancorada. props extras sobrescrevem (Material, Transparency, Shape, CanCollide...).
local function P(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf; p.Color = color
	p.Anchored = true; p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if props then for k, v in pairs(props) do p[k] = v end end
	p.Parent = parent
	return p
end
local NEON = { Material = Enum.Material.Neon, CanCollide = false }

local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color; l.Range = range or 28; l.Brightness = brightness or 1.6; l.Parent = part
end

-- Letreiro (texto em inglês: é visto por todos os jogadores).
local function sign(part, text, color, face, textSize)
	local g = Instance.new("SurfaceGui")
	g.Face = face or Enum.NormalId.Front; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 20
	g.LightInfluence = 0; g.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Font = Enum.Font.FredokaOne
	l.Text = text; l.TextColor3 = color; l.TextScaled = true
	local st = Instance.new("UIStroke"); st.Thickness = textSize or 4; st.Parent = l
	l.Parent = g
	return g
end

-- Paredes invisíveis em volta de um retângulo (ninguém cai). y0 = base das paredes.
local function fence(parent, center, halfX, halfZ, y0, height)
	local h = height or 26
	local inv = { Transparency = 1, CanQuery = false }
	P(parent, "WallN", Vector3.new(halfX * 2 + 4, h, 2), center + Vector3.new(0, y0 + h / 2, -halfZ - 1), C(255, 255, 255), inv)
	P(parent, "WallS", Vector3.new(halfX * 2 + 4, h, 2), center + Vector3.new(0, y0 + h / 2, halfZ + 1), C(255, 255, 255), inv)
	P(parent, "WallW", Vector3.new(2, h, halfZ * 2 + 4), center + Vector3.new(-halfX - 1, y0 + h / 2, 0), C(255, 255, 255), inv)
	P(parent, "WallE", Vector3.new(2, h, halfZ * 2 + 4), center + Vector3.new(halfX + 1, y0 + h / 2, 0), C(255, 255, 255), inv)
end

local function lantern(parent, pos, color)
	P(parent, "LanternPost", Vector3.new(0.8, 9, 0.8), pos + Vector3.new(0, 4.5, 0), C(40, 34, 60))
	local b = P(parent, "Lantern", Vector3.new(2.6, 2.6, 2.6), pos + Vector3.new(0, 10, 0), color, { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, CanCollide = false })
	light(b, color, 30, 1.8)
end

-- ============================================================ VERSUS HALL
function VersusBuilder.BuildHall()
	local f, r = fresh("Hall")
	local o = Config.Versus.HallOrigin
	local HX, HZ, TOP = 60, 44, 1 -- meia-largura, meia-profundidade, altura do piso
	P(f, "Floor", Vector3.new(HX * 2, 4, HZ * 2), o + Vector3.new(0, TOP - 2, 0), T.Plaza, { Material = Enum.Material.Slate })
	P(f, "Carpet", Vector3.new(34, 0.2, HZ * 2 - 8), o + Vector3.new(0, TOP + 0.1, 0), T.Night, { CanCollide = false })
	-- mureta de neon nas bordas
	for _, e in ipairs({ { Vector3.new(HX * 2, 0.6, 0.8), Vector3.new(0, 0, -HZ) }, { Vector3.new(HX * 2, 0.6, 0.8), Vector3.new(0, 0, HZ) },
		{ Vector3.new(0.8, 0.6, HZ * 2), Vector3.new(-HX, 0, 0) }, { Vector3.new(0.8, 0.6, HZ * 2), Vector3.new(HX, 0, 0) } }) do
		P(f, "NeonEdge", e[1], o + e[2] + Vector3.new(0, TOP + 0.3, 0), T.Sakura, NEON)
	end
	fence(f, o, HX, HZ, TOP)
	-- letreiro no fundo (-Z)
	local board = P(f, "TitleBoard", Vector3.new(54, 13, 1.2), o + Vector3.new(0, TOP + 15, -HZ + 2), T.Night)
	sign(board, "⚔️ VERSUS HALL 🏁", T.Gold, Enum.NormalId.Back, 5)
	P(f, "BoardGlow", Vector3.new(56, 0.6, 0.6), o + Vector3.new(0, TOP + 8.2, -HZ + 2.4), T.Garage, NEON)
	P(f, "BoardPostL", Vector3.new(2, 22, 2), o + Vector3.new(-26, TOP + 11, -HZ + 2), T.Stone)
	P(f, "BoardPostR", Vector3.new(2, 22, 2), o + Vector3.new(26, TOP + 11, -HZ + 2), T.Stone)

	-- balcões das duas lojas
	local function shop(kind, x, title, color, prompt)
		local base = o + Vector3.new(x, TOP, -16)
		P(f, kind .. "_Counter", Vector3.new(18, 4, 5), base + Vector3.new(0, 2, 0), T.Night, { Material = Enum.Material.Slate })
		P(f, kind .. "_CounterTop", Vector3.new(19, 0.5, 6), base + Vector3.new(0, 4.25, 0), color, NEON)
		local sb = P(f, kind .. "_Sign", Vector3.new(20, 5, 0.8), base + Vector3.new(0, 13, -3), T.Night)
		sign(sb, title, color, Enum.NormalId.Back, 4)
		P(f, kind .. "_PostL", Vector3.new(1, 15, 1), base + Vector3.new(-9.5, 7.5, -3), T.Stone)
		P(f, kind .. "_PostR", Vector3.new(1, 15, 1), base + Vector3.new(9.5, 7.5, -3), T.Stone)
		local spot = P(f, kind .. "_Prompt", Vector3.new(2, 2, 2), base + Vector3.new(0, 5, 3), color, { Transparency = 1, CanCollide = false, CanQuery = false })
		local pp = Instance.new("ProximityPrompt")
		pp.Name = "ShopPrompt"; pp.ActionText = prompt; pp.ObjectText = "Versus Hall"; pp.HoldDuration = 0
		pp.MaxActivationDistance = 16; pp.RequiresLineOfSight = false; pp.KeyboardKeyCode = Enum.KeyCode.E
		pp:SetAttribute("ShopKind", kind)
		pp.Parent = spot
		CollectionService:AddTag(pp, "VersusShop")
		light(spot, color, 26, 1.4)
		return base
	end
	local f1Base = shop("F1", -34, "🏎️ F1 SHOP", T.Race, "F1 Shop")
	shop("Fx", 34, "✨ VICTORY SHOP", T.Heroes, "Victory Effects")

	-- vitrine: um F1 parado num pedestal ao lado da loja de F1 (modelo estático do CarFactory)
	local ped = P(f, "F1_Pedestal", Vector3.new(14, 1.2, 22), f1Base + Vector3.new(-16, 0.6, 14), T.Night, { Material = Enum.Material.Slate })
	P(f, "F1_PedestalGlow", Vector3.new(14.6, 0.3, 22.6), ped.Position + Vector3.new(0, 0.5, 0), T.Race, NEON)
	local okCar, car = pcall(CarFactory.Build, Config.F1Cars[#Config.F1Cars], true)
	if okCar and car then
		car.Name = "F1_Display"
		for _, p in ipairs(car:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
		car:PivotTo(CFrame.new(ped.Position + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, math.rad(-35), 0))
		car.Parent = f
	end
	-- vitrine da loja de vitória: troféu de neon
	local tp = o + Vector3.new(50, TOP, -2)
	P(f, "Trophy_Base", Vector3.new(6, 2, 6), tp + Vector3.new(0, 1, 0), T.Night, { Material = Enum.Material.Slate })
	P(f, "Trophy_Stem", Vector3.new(1.2, 4, 1.2), tp + Vector3.new(0, 4, 0), T.Gold, { Material = Enum.Material.Metal })
	local cup = P(f, "Trophy_Cup", Vector3.new(5, 5, 5), tp + Vector3.new(0, 8, 0), T.Gold, { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, CanCollide = false })
	light(cup, T.Gold, 34, 2)

	for _, x in ipairs({ -52, 52 }) do
		for _, z in ipairs({ -34, 0, 34 }) do lantern(f, o + Vector3.new(x, TOP, z), T.Lantern) end
	end
	-- marcas onde os dois jogadores chegam
	for i, off in ipairs(Config.Versus.HallSpawns) do
		P(f, "SpawnMark" .. i, Vector3.new(0.2, 7, 7), -- cilindro: o eixo é o X (deitado com a rotação de 90°)
			 o + Vector3.new(off.X, TOP + 0.12, off.Z), i == 1 and T.Garage or T.Heroes, { Material = Enum.Material.Neon, CanCollide = false, Shape = Enum.PartType.Cylinder,
			CFrame = CFrame.new(o + Vector3.new(off.X, TOP + 0.12, off.Z)) * CFrame.Angles(0, 0, math.rad(90)) })
	end
	f.Parent = r
	return ("Versus Hall: %d peças em %s"):format(#f:GetDescendants(), tostring(o))
end

-- ============================================================ ARENAS
local THEMES = {
	sky_ring = { Floor = C(240, 236, 226), FloorMat = Enum.Material.Marble, Trim = C(255, 140, 30), Post = C(40, 70, 170), Glow = C(255, 196, 60), Stand = C(214, 208, 226) },
	moon_dojo = { Floor = C(150, 96, 60), FloorMat = Enum.Material.WoodPlanks, Trim = C(255, 125, 196), Post = C(214, 42, 56), Glow = C(255, 196, 118), Stand = C(64, 56, 96) },
	lava_arena = { Floor = C(52, 40, 50), FloorMat = Enum.Material.Basalt, Trim = C(255, 110, 30), Post = C(84, 62, 74), Glow = C(255, 90, 20), Stand = C(60, 48, 56) },
}

function VersusBuilder.BuildArena(i)
	local arena = Config.Versus.Battle.Arenas[i]
	if not arena then return "arena " .. tostring(i) .. " não existe no Config" end
	local th = THEMES[arena.Id] or THEMES.sky_ring
	local f, r = fresh("Arena_" .. arena.Id)
	local o = arena.Origin
	local VB = Config.Versus.Battle
	local TOP, R = VB.RingTop, 22 -- piso do ringue em o.Y + TOP; meia-medida do ringue

	-- ringue
	P(f, "RingBase", Vector3.new(R * 2 + 8, TOP - 0.6, R * 2 + 8), o + Vector3.new(0, (TOP - 0.6) / 2, 0), th.Stand, { Material = Enum.Material.Slate })
	P(f, "Ring", Vector3.new(R * 2, 0.6, R * 2), o + Vector3.new(0, TOP - 0.3, 0), th.Floor, { Material = th.FloorMat })
	P(f, "RingCircle", Vector3.new(0.2, 20, 20), CFrame.new(o + Vector3.new(0, TOP + 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)), th.Trim, { Material = Enum.Material.Neon, Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.35 })
	for _, e in ipairs({ { Vector3.new(R * 2, 0.5, 0.8), Vector3.new(0, 0, -R) }, { Vector3.new(R * 2, 0.5, 0.8), Vector3.new(0, 0, R) },
		{ Vector3.new(0.8, 0.5, R * 2), Vector3.new(-R, 0, 0) }, { Vector3.new(0.8, 0.5, R * 2), Vector3.new(R, 0, 0) } }) do
		P(f, "RingTrim", e[1], o + e[2] + Vector3.new(0, TOP + 0.2, 0), th.Trim, NEON)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local base = o + Vector3.new(sx * (R + 2), 0, sz * (R + 2))
			P(f, "Pillar", Vector3.new(3, TOP + 14, 3), base + Vector3.new(0, (TOP + 14) / 2, 0), th.Post, { Material = Enum.Material.Slate })
			local orb = P(f, "PillarOrb", Vector3.new(4, 4, 4), base + Vector3.new(0, TOP + 16.5, 0), th.Glow, { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, CanCollide = false })
			light(orb, th.Glow, 44, 2.2)
		end
	end
	local title = P(f, "ArenaSign", Vector3.new(40, 7, 1), o + Vector3.new(0, TOP + 24, -R - 10), C(20, 16, 34))
	sign(title, arena.Icon .. " " .. string.upper(arena.Name), th.Glow, Enum.NormalId.Back, 5)

	-- plateia (onde ficam os avatares dos jogadores), com paredes invisíveis
	local s1 = VB.SpectatorOffsets[1]
	local standTop = s1.Y - 3
	local sc = Vector3.new(o.X, o.Y, o.Z + s1.Z)
	P(f, "Stand", Vector3.new(40, 2, 14), sc + Vector3.new(0, standTop - 1, 0), th.Stand, { Material = Enum.Material.Slate })
	P(f, "StandFront", Vector3.new(40, standTop - 1, 2), sc + Vector3.new(0, (standTop - 1) / 2, -6), th.Post, { Material = Enum.Material.Slate })
	P(f, "StandRail", Vector3.new(40, 0.5, 0.6), sc + Vector3.new(0, standTop + 3, -6.6), th.Trim, NEON)
	fence(f, sc, 20, 7, standTop, 20)

	-- cenário de cada tema
	if arena.Id == "sky_ring" then
		for k = 1, 14 do -- nuvens em volta, abaixo do ringue
			local a = k / 14 * math.pi * 2
			local d = 70 + (k % 3) * 22
			P(f, "Cloud", Vector3.new(34 + (k % 4) * 8, 12, 26), o + Vector3.new(math.cos(a) * d, -10 - (k % 2) * 6, math.sin(a) * d), C(250, 250, 255),
				{ Shape = Enum.PartType.Ball, CanCollide = false, Transparency = 0.15, Material = Enum.Material.SmoothPlastic })
		end
		-- estandartes ATRÁS do ringue (-Z): nas laterais eles tapavam a câmera que gira na entrada da luta
		P(f, "Banner", Vector3.new(8, 16, 0.6), o + Vector3.new(-16, TOP + 10, -R - 7), th.Trim, { CanCollide = false })
		P(f, "Banner", Vector3.new(8, 16, 0.6), o + Vector3.new(16, TOP + 10, -R - 7), th.Trim, { CanCollide = false })
	elseif arena.Id == "moon_dojo" then
		local moon = P(f, "Moon", Vector3.new(70, 70, 70), o + Vector3.new(0, 70, -150), C(255, 246, 214), { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, CanCollide = false })
		light(moon, C(255, 240, 210), 60, 1)
		for _, sx in ipairs({ -1, 1 }) do -- cerejeiras simples
			local base = o + Vector3.new(sx * (R + 16), 0, -8)
			P(f, "Trunk", Vector3.new(3, 16, 3), base + Vector3.new(0, 8, 0), C(96, 56, 52))
			for k = 1, 5 do
				P(f, "Blossom", Vector3.new(12, 10, 12), base + Vector3.new(math.cos(k * 1.3) * 5, 17 + (k % 2) * 3, math.sin(k * 1.3) * 5), T.Sakura,
					{ Shape = Enum.PartType.Ball, CanCollide = false })
			end
			lantern(f, o + Vector3.new(sx * (R + 6), 0, R + 6), T.Lantern)
		end
		P(f, "Ground", Vector3.new(150, 1, 150), o + Vector3.new(0, -0.5, 10), C(60, 52, 90), { Material = Enum.Material.Slate })
	elseif arena.Id == "lava_arena" then
		P(f, "Lava", Vector3.new(220, 1, 220), o + Vector3.new(0, -4, 10), C(255, 112, 30), { Material = Enum.Material.Neon, CanCollide = false })
		P(f, "LavaCrust", Vector3.new(150, 1, 150), o + Vector3.new(0, -0.5, 10), C(52, 40, 50), { Material = Enum.Material.CrackedLava })
		for k = 1, 6 do -- cascatas de lava ao fundo e dos lados
			local a = math.rad(200 + k * 20)
			local pos = o + Vector3.new(math.cos(a) * 78, 26, math.sin(a) * 78)
			P(f, "Cliff", Vector3.new(22, 60, 14), CFrame.lookAt(pos, Vector3.new(o.X, pos.Y, o.Z)), C(46, 38, 46), { Material = Enum.Material.Basalt })
			local fall = P(f, "LavaFall", Vector3.new(8, 56, 1.5), CFrame.lookAt(pos, Vector3.new(o.X, pos.Y, o.Z)) * CFrame.new(0, -2, -7.4), C(255, 120, 30), NEON)
			light(fall, C(255, 110, 30), 50, 1.6)
		end
	end
	f.Parent = r
	return ("%s: %d peças em %s"):format(arena.Name, #f:GetDescendants(), tostring(o))
end

function VersusBuilder.BuildAll()
	local out = { VersusBuilder.BuildHall() }
	for i = 1, #Config.Versus.Battle.Arenas do
		out[#out + 1] = VersusBuilder.BuildArena(i)
		task.wait()
	end
	return table.concat(out, "\n")
end

return VersusBuilder
