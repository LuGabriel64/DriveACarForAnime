--[[
	AnimeModelFactory (Beta 1.8b): personagens no estilo "BLOCOS ANIME" — corpo de avatar clássico do Roblox (R6:
	pernas, tronco, braços e cabeça em blocos) com ROSTO de anime e CABELO esculpido em espetos (referência do dono).
	Usado pelo servidor (garagem/vitrine) e pelo cliente (ViewportFrames).
	  Build(cfg, mut, size) -> Model (PrimaryPart "Root" nos PÉS; frente = -Z; ~7 studs + cabelo)
	  Silhouette(model)     -> recolore tudo de preto

	ALTURAS: botas 0-1 | calça 1-2.9 | tronco 2.9-4.9 | cabeça 4.9-6.9 (bloco 2.1 x 2.0 x 1.95) | cabelo por cima.
	Look (Config.Animes[i].Look):
	  Skin Hair Eyes Outfit (tronco) Outfit2 (calça) AccColor BeltColor Style Bald Acc
	  + opcionais (Beta 1.8b): Under (camiseta do decote em V), Sleeve (manga curta), LongSleeve (true = braço todo
	    na cor da manga), Gloves (mãos), Wrist (munhequeiras), Shoe (botas), BootTrim (faixa da bota), Gi (aba do
	    quimono abaixo da faixa), Expression ("confident" | "angry" | "happy" | "calm"), Brow (cor da sobrancelha)
	Estilos de cabelo: spiky (espetos para todo lado) | flame (labareda para cima) | short | long | twin | bun
	Acessórios: headband scarf hat chefhat foxears tail horns halo crown cape sword wings beanie visor staff
	            beard turban antenna crest headtail belt mecha
	Versões antigas: ServerStorage.LegacyCode (voxel Beta 1.0-1.6, chibi Beta 1.7).
]]
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)

local F = {}
local V3, rad = Vector3.new, math.rad
local HY, FZ = 5.9, -0.975 -- centro da cabeça | face da frente da cabeça

local EXPR = { -- inclinação (graus) do cílio e da sobrancelha + altura do olho
	confident = { Lash = 12, Brow = 22, EyeH = 0.38, Mouth = "smirk" },
	angry     = { Lash = 18, Brow = 30, EyeH = 0.32, Mouth = "flat" },
	happy     = { Lash = -6, Brow = -10, EyeH = 0.44, Mouth = "smile" },
	calm      = { Lash = 4,  Brow = 6,  EyeH = 0.4,  Mouth = "smile" },
}

function F.Build(cfg, mut, size)
	local L = cfg.Look
	local m = Instance.new("Model")
	m.Name = cfg.Id

	local function base(cls, name, sz, cf, color, o)
		o = o or {}
		local p = Instance.new(cls)
		p.Name = name; p.Size = sz; p.CFrame = cf; p.Color = color
		p.Material = o.Mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		if o.Shape then p.Shape = o.Shape end
		if o.T then p.Transparency = o.T end
		if o.NoTint then p:SetAttribute("NoTint", true) end
		if o.NoShadow then p.CastShadow = false end
		p.Parent = m
		return p
	end
	local function cfOf(pos, rot)
		if typeof(pos) == "CFrame" then return pos end
		local c = CFrame.new(pos)
		if rot then c = c * CFrame.Angles(rad(rot.X), rad(rot.Y), rad(rot.Z)) end
		return c
	end
	local function B(n, sz, pos, col, o) return base("Part", n, sz, cfOf(pos, o and o.Rot), col, o) end
	local function E(n, sz, pos, col, o) local p = B(n, sz, pos, col, o); local s = Instance.new("SpecialMesh"); s.MeshType = Enum.MeshType.Sphere; s.Parent = p; return p end
	local function Cyl(n, len, d, pos, col, o) o = o or {}; o.Shape = Enum.PartType.Cylinder; return B(n, V3(len, d, d), pos, col, o) end
	-- espeto/prisma pontudo: 2 cunhas formam um triângulo voltado para a frente; dir = direção da ponta
	local function Spike(n, basePos, dir, len, w, t, col, o)
		dir = dir.Unit
		local mid = basePos + dir * (len / 2)
		local ref = math.abs(dir.Z) < 0.85 and V3(0, 0, -1) or V3(1, 0, 0)
		local right = ref:Cross(dir).Unit
		local back = right:Cross(dir).Unit
		local cf = CFrame.fromMatrix(mid, right, dir, back) * CFrame.Angles(0, math.pi / 2, 0)
		base("WedgePart", n .. "A", V3(t, len, w / 2), cf * CFrame.new(0, 0, -w / 4), col, o)
		base("WedgePart", n .. "B", V3(t, len, w / 2), cf * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, -w / 4), col, o)
	end
	-- peça fina colada na frente da cabeça (camada = quanto à frente)
	local function face(n, w, h, x, y, col, layer, rotZ, o)
		o = o or {}; o.NoTint = true; o.NoShadow = true
		return B(n, V3(w, h, 0.05), CFrame.new(x, y, FZ - 0.03 - (layer or 0) * 0.012) * CFrame.Angles(0, 0, rad(rotZ or 0)), col, o)
	end

	local root = B("Root", V3(0.2, 0.1, 0.2), V3(0, 0.05, 0), Color3.new(), { NoTint = true })
	root.Transparency = 1
	m.PrimaryPart = root

	local skin, hair, eyes = L.Skin, L.Hair, L.Eyes
	local o1, o2 = L.Outfit, L.Outfit2
	local acc = L.AccColor or Color3.new(1, 1, 1)
	local dark = Color3.fromRGB(22, 18, 28)
	local under = L.Under or o1:Lerp(Color3.new(0, 0, 0), 0.35)
	local sleeve = L.Sleeve or o1
	local shoe = L.Shoe or o2:Lerp(Color3.new(0, 0, 0), 0.45)
	local hasAcc = {}
	for _, a in ipairs(L.Acc or {}) do hasAcc[a] = true end

	-- ---------------------------------------------------------------- corpo (R6)
	for _, s in ipairs({ -1, 1 }) do
		local side = s < 0 and "L" or "R"
		B("Boot" .. side, V3(1.0, 1.0, 1.12), V3(s * 0.52, 0.5, -0.05), shoe)
		if L.BootTrim then
			B("BootTrim" .. side, V3(1.04, 0.14, 1.16), V3(s * 0.52, 0.97, -0.05), L.BootTrim)
			B("BootStripe" .. side, V3(0.12, 0.85, 0.04), V3(s * 0.52, 0.5, -0.63), L.BootTrim, { NoShadow = true })
			B("BootTie" .. side, V3(0.5, 0.1, 0.06), V3(s * 0.52, 0.82, -0.64), Color3.fromRGB(240, 190, 60), { NoShadow = true })
		end
		B("Leg" .. side, V3(1.0, 1.92, 1.0), V3(s * 0.52, 1.96, 0), o2)
		-- braço: pele (manga curta) ou todo na cor da manga (manga longa)
		local armCol = L.LongSleeve and sleeve or skin
		B("Arm" .. side, V3(1.0, 2.0, 1.0), V3(s * 1.55, 3.9, 0), armCol)
		if not L.LongSleeve then B("Sleeve" .. side, V3(1.04, 0.72, 1.04), V3(s * 1.55, 4.55, 0), sleeve) end
		if L.Gloves then B("Glove" .. side, V3(1.03, 0.55, 1.03), V3(s * 1.55, 3.18, 0), L.Gloves)
		elseif L.LongSleeve then B("Hand" .. side, V3(1.02, 0.5, 1.02), V3(s * 1.55, 3.15, 0), skin) end
		if L.Wrist then B("Wrist" .. side, V3(1.06, 0.34, 1.06), V3(s * 1.55, 3.42, 0), L.Wrist) end
	end
	B("Torso", V3(2.08, 2.0, 1.04), V3(0, 3.9, 0), o1)
	Spike("Undershirt", V3(0, 4.89, -0.54), V3(0, -1, 0), 1.05, 1.2, 0.05, under, { NoShadow = true }) -- decote em V
	if L.Gi then B("GiFlap", V3(2.1, 0.42, 1.07), V3(0, 2.75, 0), o1) end
	if hasAcc.belt then
		local bc = L.BeltColor or acc
		B("Belt", V3(2.14, 0.38, 1.09), V3(0, 3.12, 0), bc)
		B("BeltKnot", V3(0.44, 0.44, 0.14), V3(0, 3.12, -0.6), bc)
		B("BeltTailL", V3(0.26, 1.05, 0.08), V3(-0.14, 2.5, -0.62), bc, { Rot = V3(0, 0, -8) })
		B("BeltTailR", V3(0.26, 0.95, 0.08), V3(0.16, 2.55, -0.62), bc, { Rot = V3(0, 0, 10) })
	end

	-- ---------------------------------------------------------------- cabeça + rosto de anime
	B("Head", V3(2.1, 2.0, 1.95), V3(0, HY, 0), skin)
	local ex = EXPR[L.Expression or "calm"] or EXPR.calm
	local browCol = L.Brow or (L.Bald and dark or hair)
	for _, s in ipairs({ -1, 1 }) do
		local side = s < 0 and "L" or "R"
		local x = 0.43 * s
		local tilt = s * ex.Lash  -- olho esquerdo: ponta de dentro (direita) mais baixa => olhar decidido
		face("Sclera" .. side, 0.62, ex.EyeH, x, HY - 0.05, Color3.new(1, 1, 1), 0, tilt * 0.5)
		face("Iris" .. side, 0.28, ex.EyeH - 0.04, x - s * 0.08, HY - 0.07, eyes, 1)
		face("Pupil" .. side, 0.14, (ex.EyeH - 0.04) * 0.6, x - s * 0.08, HY - 0.09, Color3.fromRGB(8, 8, 12), 2)
		face("Glint" .. side, 0.08, 0.09, x - s * 0.12, HY + 0.02, Color3.new(1, 1, 1), 3, 0, { Mat = Enum.Material.Neon })
		face("Lash" .. side, 0.74, 0.12, x, HY - 0.05 + ex.EyeH / 2 + 0.03, dark, 3, tilt)
		face("Brow" .. side, 0.62, 0.15, x - s * 0.02, HY + 0.36, browCol, 3, s * ex.Brow)
	end
	face("Nose", 0.07, 0.1, 0.03, HY - 0.32, skin:Lerp(Color3.fromRGB(120, 70, 60), 0.5), 0)
	if ex.Mouth == "smile" then
		face("MouthL", 0.2, 0.05, -0.09, HY - 0.6, Color3.fromRGB(90, 40, 45), 0, -14)
		face("MouthR", 0.2, 0.05, 0.09, HY - 0.6, Color3.fromRGB(90, 40, 45), 0, 14)
	elseif ex.Mouth == "smirk" then
		face("Mouth", 0.3, 0.05, -0.02, HY - 0.6, Color3.fromRGB(90, 40, 45), 0, 0)
		face("MouthUp", 0.12, 0.05, 0.17, HY - 0.57, Color3.fromRGB(90, 40, 45), 0, 25)
	else
		face("Mouth", 0.32, 0.05, 0, HY - 0.6, Color3.fromRGB(90, 40, 45), 0, 0)
	end

	-- ---------------------------------------------------------------- cabelo esculpido
	if not L.Bald then
		local style = L.Style or "short"
		B("HairCap", V3(2.24, 0.55, 2.1), V3(0, 7.05, 0.02), hair)
		B("HairBack", V3(2.24, 1.75, 0.42), V3(0, 6.25, 0.97), hair)
		B("HairSideL", V3(0.2, 1.15, 1.75), V3(-1.1, 6.42, 0.12), hair)
		B("HairSideR", V3(0.2, 1.15, 1.75), V3(1.1, 6.42, 0.12), hair)
		local bangs = (style == "flame") and { { -0.55, 0.7 }, { 0.55, 0.7 } } or { { -0.75, 1.3 }, { -0.28, 1.05 }, { 0.22, 1.2 }, { 0.72, 1.0 } }
		for i, b in ipairs(bangs) do Spike("Bang" .. i, V3(b[1], 7.0, -1.0), V3(b[1] * 0.18, -1, -0.12), b[2], 0.78, 0.3, hair) end
		local C = V3(0, 6.8, 0.15)
		local list
		if style == "spiky" then
			list = { { V3(0, 1, 0.1), 2.3, 1.5 }, { V3(-0.5, 1, 0.05), 2.1, 1.4 }, { V3(0.5, 1, 0.05), 2.1, 1.4 },
				{ V3(-1, 0.6, 0.1), 2.5, 1.5 }, { V3(1, 0.6, 0.1), 2.5, 1.5 }, { V3(-1, 0.08, 0.2), 2.6, 1.4 }, { V3(1, 0.08, 0.2), 2.6, 1.4 },
				{ V3(-1, -0.35, 0.25), 1.9, 1.2 }, { V3(1, -0.35, 0.25), 1.9, 1.2 },
				{ V3(-0.45, 0.5, 1), 2.0, 1.3 }, { V3(0.45, 0.5, 1), 2.0, 1.3 }, { V3(0, 0.15, 1), 2.0, 1.3 } }
		elseif style == "flame" then
			list = { { V3(0, 1, 0.15), 3.0, 1.6 }, { V3(-0.35, 1, 0.1), 2.7, 1.4 }, { V3(0.35, 1, 0.1), 2.7, 1.4 },
				{ V3(-0.7, 1, 0.2), 2.2, 1.3 }, { V3(0.7, 1, 0.2), 2.2, 1.3 }, { V3(0, 1, 0.7), 2.5, 1.4 }, { V3(-0.4, 0.8, 0.7), 2.0, 1.2 }, { V3(0.4, 0.8, 0.7), 2.0, 1.2 } }
		elseif style == "short" then
			list = { { V3(-0.4, 1, 0.3), 0.9, 1.0 }, { V3(0.4, 1, 0.3), 0.9, 1.0 }, { V3(0, 1, 0.6), 0.8, 1.0 } }
		end
		for i, sp in ipairs(list or {}) do Spike("Spike" .. i, C + sp[1].Unit * 0.85, sp[1], sp[2], sp[3], 1.0, hair) end
		if style == "long" then
			B("HairLong", V3(2.24, 3.4, 0.45), V3(0, 5.25, 0.98), hair)
			B("LockL", V3(0.36, 2.3, 0.7), V3(-1.12, 5.55, -0.55), hair)
			B("LockR", V3(0.36, 2.3, 0.7), V3(1.12, 5.55, -0.55), hair)
		elseif style == "twin" then
			B("TailL", V3(0.8, 2.7, 0.8), V3(-1.5, 5.85, 0.4), hair, { Rot = V3(0, 0, -12) })
			B("TailR", V3(0.8, 2.7, 0.8), V3(1.5, 5.85, 0.4), hair, { Rot = V3(0, 0, 12) })
			B("TieL", V3(0.5, 0.35, 0.5), V3(-1.3, 7.0, 0.4), acc)
			B("TieR", V3(0.5, 0.35, 0.5), V3(1.3, 7.0, 0.4), acc)
		elseif style == "bun" then
			B("Bun", V3(1.1, 0.95, 1.1), V3(0, 7.6, 0.45), hair)
		end
	end

	-- ---------------------------------------------------------------- acessórios
	for _, a in ipairs(L.Acc or {}) do
		if a == "headband" then
			B("Headband", V3(2.2, 0.32, 2.05), V3(0, 6.5, 0), acc)
			B("HeadbandTail", V3(0.3, 1.1, 0.08), V3(0.35, 6.0, 1.05), acc, { Rot = V3(10, 0, -15) })
		elseif a == "scarf" then
			B("Scarf", V3(2.2, 0.48, 1.18), V3(0, 4.82, 0), acc)
			B("ScarfTail", V3(0.45, 1.3, 0.14), V3(0.6, 4.1, 0.62), acc, { Rot = V3(8, 0, -8) })
		elseif a == "hat" then
			B("HatBrim", V3(3.2, 0.22, 3.0), V3(0, 7.2, 0), acc)
			B("HatTop", V3(2.2, 1.0, 2.1), V3(0, 7.8, 0), acc)
		elseif a == "chefhat" then
			B("ChefBand", V3(2.2, 0.5, 2.05), V3(0, 7.15, 0), acc)
			E("ChefTop", V3(2.6, 1.6, 2.4), V3(0, 8.05, 0), acc)
		elseif a == "foxears" then
			for _, s in ipairs({ -1, 1 }) do
				Spike("FoxEar" .. (s < 0 and "L" or "R"), V3(s * 0.68, 7.2, 0), V3(s * 0.25, 1, 0), 1.3, 0.95, 0.4, hair)
				Spike("FoxEarIn" .. (s < 0 and "L" or "R"), V3(s * 0.68, 7.25, -0.22), V3(s * 0.25, 1, 0), 0.85, 0.5, 0.05, Color3.fromRGB(255, 190, 200), { NoTint = true })
			end
		elseif a == "tail" then
			B("Tail1", V3(0.75, 0.75, 1.1), V3(0, 2.7, 0.95), hair, { Rot = V3(-20, 0, 0) })
			B("Tail2", V3(0.95, 0.95, 1.2), V3(0, 3.2, 1.85), hair, { Rot = V3(-40, 0, 0) })
			B("Tail3", V3(0.8, 0.8, 0.8), V3(0, 3.85, 2.4), Color3.new(1, 1, 1))
		elseif a == "horns" then
			for _, s in ipairs({ -1, 1 }) do Spike("Horn" .. (s < 0 and "L" or "R"), V3(s * 0.62, 7.15, -0.2), V3(s * 0.35, 1, 0), 1.3, 0.55, 0.55, acc, { Mat = Enum.Material.Neon }) end
		elseif a == "halo" then
			Cyl("Halo", 0.2, 2.6, CFrame.new(0, 8.6, 0) * CFrame.Angles(0, 0, rad(90)), acc, { Mat = Enum.Material.Neon, NoTint = true })
		elseif a == "crown" then
			B("CrownBase", V3(1.9, 0.45, 1.8), V3(0, 7.35, 0), acc, { Mat = Enum.Material.Metal })
			for k, x in ipairs({ -0.65, 0, 0.65 }) do Spike("CrownTip" .. k, V3(x, 7.55, -0.85), V3(0, 1, 0), k == 2 and 0.9 or 0.65, 0.55, 0.2, acc, { Mat = Enum.Material.Metal }) end
		elseif a == "cape" then
			B("Cape", V3(2.0, 3.4, 0.18), V3(0, 3.35, 0.62), acc, { Rot = V3(-5, 0, 0) })
			B("CapeCollar", V3(2.3, 0.4, 1.3), V3(0, 4.85, 0.1), acc)
		elseif a == "sword" then
			B("SwordHandle", V3(0.3, 1.0, 0.3), V3(0.9, 5.3, 0.75), Color3.fromRGB(70, 50, 40), { Rot = V3(0, 0, -35) })
			B("SwordBlade", V3(0.22, 3.4, 0.5), V3(-0.25, 3.7, 0.75), Color3.fromRGB(235, 245, 255), { Rot = V3(0, 0, -35), Mat = Enum.Material.Neon, NoTint = true })
		elseif a == "wings" then
			for _, s in ipairs({ -1, 1 }) do
				B("Wing" .. (s < 0 and "L" or "R"), V3(0.2, 2.6, 1.8), V3(s * 1.2, 4.4, 1.05), acc, { Rot = V3(0, -s * 25, s * 25), Mat = Enum.Material.Neon })
			end
		elseif a == "beanie" then
			B("Beanie", V3(2.26, 1.1, 2.12), V3(0, 7.25, 0), acc)
			B("BeanieBand", V3(2.3, 0.4, 2.16), V3(0, 6.75, 0), acc:Lerp(Color3.new(1, 1, 1), 0.5))
			E("Pom", V3(0.7, 0.7, 0.7), V3(0, 7.95, 0), Color3.new(1, 1, 1))
		elseif a == "visor" then -- óculos escuros
			local lens = acc:Lerp(Color3.new(0, 0, 0), 0.55)
			face("LensL", 0.74, 0.42, -0.43, HY - 0.03, lens, 5, 0, { Mat = Enum.Material.Glass })
			face("LensR", 0.74, 0.42, 0.43, HY - 0.03, lens, 5, 0, { Mat = Enum.Material.Glass })
			face("Bridge", 0.2, 0.07, 0, HY + 0.08, Color3.fromRGB(40, 40, 46), 5)
			face("LensShine", 0.18, 0.07, -0.55, HY + 0.08, Color3.new(1, 1, 1), 6, 20, { Mat = Enum.Material.Neon, T = 0.3 })
		elseif a == "staff" then
			Cyl("Staff", 6.4, 0.32, CFrame.new(2.3, 3.4, -0.3) * CFrame.Angles(0, 0, rad(90)), Color3.fromRGB(110, 78, 50))
			B("StaffOrb", V3(1.0, 1.0, 1.0), V3(2.3, 6.8, -0.3), acc, { Mat = Enum.Material.Neon, NoTint = true, Rot = V3(45, 45, 0) })
		elseif a == "beard" then
			local white = Color3.fromRGB(250, 250, 250)
			B("Beard", V3(1.7, 1.0, 0.35), V3(0, HY - 0.75, FZ - 0.12), white, { NoTint = true })
			B("BeardChin", V3(1.4, 0.8, 0.9), V3(0, 4.75, -0.6), white, { NoTint = true })
			Spike("BeardTip", V3(0, 4.4, -0.75), V3(0, -1, -0.1), 0.8, 1.0, 0.6, white, { NoTint = true })
			face("Mustache", 1.1, 0.2, 0, HY - 0.42, white, 4)
		elseif a == "turban" then
			B("Turban", V3(2.36, 1.15, 2.2), V3(0, 7.25, 0), Color3.fromRGB(245, 245, 245))
			B("TurbanTop", V3(1.8, 0.55, 1.7), V3(0, 8.05, 0), Color3.fromRGB(232, 232, 232))
			B("TurbanGem", V3(0.4, 0.4, 0.12), V3(0, 7.3, -1.15), Color3.fromRGB(150, 60, 220), { Mat = Enum.Material.Neon, NoTint = true, Rot = V3(0, 0, 45) })
		elseif a == "antenna" then
			B("AntennaL", V3(0.16, 1.4, 0.16), V3(-0.35, 7.4, -0.75), skin, { Rot = V3(-25, 0, 12) })
			B("AntennaR", V3(0.16, 1.4, 0.16), V3(0.35, 7.4, -0.75), skin, { Rot = V3(-25, 0, -12) })
		elseif a == "crest" then
			for _, s in ipairs({ -1, 1 }) do Spike("Crest" .. (s < 0 and "L" or "R"), V3(s * 0.75, 6.9, 0.1), V3(s * 0.35, 1, 0.25), 2.3, 1.0, 0.6, acc) end
			B("CrestBack", V3(2.2, 1.5, 0.6), V3(0, 6.6, 0.9), acc)
		elseif a == "headtail" then
			Spike("HeadTail", V3(0, 6.9, 0.3), V3(0, 1, 0.65), 2.4, 1.1, 1.0, skin)
		elseif a == "mecha" then
			B("PadL", V3(1.3, 0.6, 1.3), V3(-1.6, 5.0, 0), acc)
			B("PadR", V3(1.3, 0.6, 1.3), V3(1.6, 5.0, 0), acc)
			B("ChestPlate", V3(1.9, 1.3, 0.14), V3(0, 4.15, -0.58), acc:Lerp(Color3.new(1, 1, 1), 0.3))
		end
	end

	-- ---------------------------------------------------------------- mutação (Gold/Diamond)
	local def = mut and Config.Mutations[mut]
	if def then
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and not p:GetAttribute("NoTint") then
				local _, _, v = p.Color:ToHSV()
				p.Color = Color3.fromHSV(def.Hue, def.Sat, math.clamp(0.45 + v * 0.55, 0, 1))
				p.Material = def.Material
			end
		end
	end

	-- ---------------------------------------------------------------- SECRET: aura escura + anel preto/prata
	if cfg.Rarity == "Secret" then
		E("SecretAura", V3(5.2, 9.4, 4.2), V3(0, 4.3, 0), Color3.fromRGB(40, 40, 50), { Mat = Enum.Material.ForceField, NoTint = true, NoShadow = true })
		Cyl("SecretRing", 0.3, 5.6, CFrame.new(0, 0.18, 0) * CFrame.Angles(0, 0, rad(90)), Color3.fromRGB(20, 20, 26), { Mat = Enum.Material.Neon, NoTint = true, NoShadow = true })
		Cyl("SecretRingGlow", 0.32, 4.6, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, rad(90)), Color3.fromRGB(210, 210, 225), { Mat = Enum.Material.Neon, NoTint = true, NoShadow = true })
		B("SecretStar", V3(0.9, 0.9, 0.9), V3(0, 10.2, 0), Color3.fromRGB(235, 235, 245), { Mat = Enum.Material.Neon, NoTint = true, NoShadow = true, Rot = V3(45, 45, 0) })
	end

	local sz = size and Config.Sizes[size]
	if sz then m:ScaleTo(sz.Scale) end
	return m
end

function F.Silhouette(model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			p.Color = Color3.fromRGB(8, 8, 14); p.Material = Enum.Material.SmoothPlastic
		end
	end
end

return F
