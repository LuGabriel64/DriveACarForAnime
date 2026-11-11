--[[
	AnimeModelFactory (Beta 1.7): personagens anime no estilo CHIBI ARREDONDADO, gerados por código a partir de
	Config.Animes[i].Look. Usado pelo servidor (garagem/vitrine) e pelo cliente (ViewportFrames das UIs).
	  Build(cfg, mut, size) -> Model (PrimaryPart "Root" nos PÉS; frente = -Z; ~7 studs de altura)
	  Silhouette(model)     -> recolore tudo de preto (pontos "misteriosos")

	ESTILO: tudo é ELIPSOIDE (Part + SpecialMesh Sphere) ou cilindro => formas macias, sem quinas.
	  * Cabeça grande e oval; o rosto é colado na SUPERFÍCIE da cabeça (onHead) seguindo a normal => olhos de anime
	    grandes (borda clara, íris na cor Look.Eyes, pupila, 2 brilhos), cílio, sobrancelha, boca e bochecha.
	  * Cabelo = touca + nuca + franja em "pétalas" + estilos (spiky / long / twin / bun / short). Look.Bald pula.
	  * Corpo: tronco e quadril ovais, braços em gota, mãos e tênis redondos.
	Look: Skin Hair Eyes Outfit Outfit2 Style Bald Acc AccColor BeltColor Shoe(opcional)
	Acessórios: headband scarf hat chefhat foxears tail horns halo crown cape sword wings beanie visor staff
	            beard turban antenna crest headtail belt mecha
	A versão VOXEL (Beta 1.0–1.6) está guardada em ServerStorage.LegacyCode.AnimeModelFactory_Voxel_Beta16.
]]
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)

local F = {}
local V3 = Vector3.new
local rad = math.rad

-- cabeça (centro e raios do elipsoide) — o rosto e o cabelo são posicionados a partir daqui
local HY, HA, HB, HC = 4.5, 1.65, 1.55, 1.55

function F.Build(cfg, mut, size)
	local L = cfg.Look
	local m = Instance.new("Model")
	m.Name = cfg.Id

	local function base(name, sz, cf, color, o)
		o = o or {}
		local p = Instance.new("Part")
		p.Name = name; p.Size = sz; p.CFrame = cf; p.Color = color
		p.Material = o.Mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = o.Shadow ~= false
		if o.Transparency then p.Transparency = o.Transparency end
		if o.Shape then p.Shape = o.Shape end
		if o.NoTint then p:SetAttribute("NoTint", true) end
		p.Parent = m
		return p
	end
	local function cfAt(pos, rot)
		local cf = CFrame.new(pos)
		if rot then cf = cf * CFrame.Angles(rad(rot.X), rad(rot.Y), rad(rot.Z)) end
		return cf
	end
	-- elipsoide (bloco + malha esfera que preenche o bloco)
	local function E(name, sz, pos, color, o)
		local p = base(name, sz, typeof(pos) == "CFrame" and pos or cfAt(pos, o and o.Rot), color, o)
		local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = p
		return p
	end
	-- bloco/cilindro comuns
	local function B(name, sz, pos, color, o) return base(name, sz, typeof(pos) == "CFrame" and pos or cfAt(pos, o and o.Rot), color, o) end
	local function Cyl(name, len, d, pos, color, o) -- eixo do cilindro = X local
		o = o or {}; o.Shape = Enum.PartType.Cylinder
		return base(name, V3(len, d, d), typeof(pos) == "CFrame" and pos or cfAt(pos, o.Rot), color, o)
	end
	-- ponto na superfície frontal da cabeça (x, y relativos ao centro) virado para fora pela normal
	local function onHead(x, y, push)
		local k = 1 - (x / HA) ^ 2 - (y / HB) ^ 2
		local z = -HC * math.sqrt(math.max(0.02, k))
		local p = V3(x, HY + y, z)
		local n = V3(x / HA ^ 2, y / HB ^ 2, z / HC ^ 2).Unit
		return CFrame.lookAt(p + n * (push or 0), p + n * ((push or 0) + 1))
	end

	local root = B("Root", V3(0.2, 0.1, 0.2), V3(0, 0.05, 0), Color3.new(), { NoTint = true })
	root.Transparency = 1
	m.PrimaryPart = root

	local skin, hair, eyes = L.Skin, L.Hair, L.Eyes
	local o1, o2 = L.Outfit, L.Outfit2
	local acc = L.AccColor or Color3.new(1, 1, 1)
	local shoe = L.Shoe or o2:Lerp(Color3.new(0, 0, 0), 0.45)
	local dark = Color3.fromRGB(28, 22, 34)

	-- ---------------------------------------------------------------- corpo
	Cyl("LegL", 1.0, 0.74, cfAt(V3(-0.48, 0.95, 0), V3(0, 0, 90)), o2)
	Cyl("LegR", 1.0, 0.74, cfAt(V3(0.48, 0.95, 0), V3(0, 0, 90)), o2)
	E("ShoeL", V3(0.86, 0.62, 1.25), V3(-0.48, 0.32, -0.12), shoe)
	E("ShoeR", V3(0.86, 0.62, 1.25), V3(0.48, 0.32, -0.12), shoe)
	E("ShoeTipL", V3(0.7, 0.3, 0.5), V3(-0.48, 0.2, -0.62), Color3.fromRGB(245, 245, 245), { NoTint = true })
	E("ShoeTipR", V3(0.7, 0.3, 0.5), V3(0.48, 0.2, -0.62), Color3.fromRGB(245, 245, 245), { NoTint = true })
	E("Hips", V3(1.85, 0.95, 1.35), V3(0, 1.55, 0), o2)
	E("Torso", V3(1.95, 1.8, 1.42), V3(0, 2.3, 0), o1)
	E("Collar", V3(1.1, 0.35, 0.9), V3(0, 3.05, -0.05), o1:Lerp(Color3.new(1, 1, 1), 0.25))
	E("ArmL", V3(0.62, 1.38, 0.62), V3(-1.12, 2.25, 0), o1, { Rot = V3(0, 0, -14) })
	E("ArmR", V3(0.62, 1.38, 0.62), V3(1.12, 2.25, 0), o1, { Rot = V3(0, 0, 14) })
	E("HandL", V3(0.64, 0.64, 0.64), V3(-1.3, 1.55, 0), skin)
	E("HandR", V3(0.64, 0.64, 0.64), V3(1.3, 1.55, 0), skin)
	E("Neck", V3(0.7, 0.4, 0.7), V3(0, 3.1, 0), skin)

	-- ---------------------------------------------------------------- cabeça + rosto
	E("Head", V3(HA * 2, HB * 2, HC * 2), V3(0, HY, 0), skin)
	E("EarL", V3(0.34, 0.62, 0.48), V3(-1.62, HY - 0.05, 0.1), skin)
	E("EarR", V3(0.34, 0.62, 0.48), V3(1.62, HY - 0.05, 0.1), skin)
	local nt = { NoTint = true, Shadow = false }
	for _, sx in ipairs({ -1, 1 }) do
		local s = sx < 0 and "L" or "R"
		local ex, ey = 0.6 * sx, -0.14
		E("EyeRim" .. s, V3(0.74, 0.98, 0.16), onHead(ex, ey, 0.01), Color3.fromRGB(250, 250, 252), nt)
		E("Eye" .. s, V3(0.62, 0.86, 0.16), onHead(ex, ey - 0.02, 0.05), eyes, nt)
		E("EyeDeep" .. s, V3(0.62, 0.42, 0.16), onHead(ex, ey + 0.2, 0.07), eyes:Lerp(Color3.new(0, 0, 0), 0.45), nt)
		E("Pupil" .. s, V3(0.3, 0.44, 0.16), onHead(ex, ey - 0.06, 0.09), Color3.fromRGB(14, 12, 22), nt)
		E("Shine" .. s, V3(0.24, 0.26, 0.16), onHead(ex - 0.13, ey + 0.17, 0.12), Color3.new(1, 1, 1), { NoTint = true, Shadow = false, Mat = Enum.Material.Neon })
		E("Shine2" .. s, V3(0.12, 0.12, 0.16), onHead(ex + 0.14, ey - 0.24, 0.12), Color3.new(1, 1, 1), { NoTint = true, Shadow = false, Mat = Enum.Material.Neon })
		B("Lash" .. s, V3(0.8, 0.13, 0.12), onHead(ex, ey + 0.47, 0.05) * CFrame.Angles(0, 0, rad(-8 * sx)), dark, nt)
		B("Brow" .. s, V3(0.55, 0.12, 0.12), onHead(ex + 0.02 * sx, ey + 0.82, 0.05) * CFrame.Angles(0, 0, rad(10 * sx)), L.Bald and dark or hair, nt)
		E("Blush" .. s, V3(0.5, 0.24, 0.12), onHead(1.0 * sx, -0.58, 0.02), Color3.fromRGB(255, 140, 150), { NoTint = true, Shadow = false, Transparency = 0.25 })
	end
	E("Mouth", V3(0.34, 0.16, 0.12), onHead(0, -0.8, 0.03), Color3.fromRGB(150, 55, 70), nt)
	E("Nose", V3(0.12, 0.1, 0.1), onHead(0, -0.42, 0.04), skin:Lerp(Color3.fromRGB(200, 120, 110), 0.35), nt)

	-- ---------------------------------------------------------------- cabelo
	if not L.Bald then
		local style = L.Style or "short"
		E("HairCap", V3(3.55, 2.35, 3.35), V3(0, HY + 0.78, 0.14), hair)
		E("HairBack", V3(3.35, 2.7, 1.7), V3(0, HY - 0.15, 0.82), hair)
		for i = -2, 2 do -- franja em pétalas
			local cf = onHead(i * 0.62, 0.98 - math.abs(i) * 0.1, 0.02) * CFrame.Angles(0, 0, rad(-i * 14))
			E("Bang" .. (i + 3), V3(0.78, 1.15, 0.42), cf * CFrame.new(0, -0.15, 0), hair)
		end
		E("SideL", V3(0.48, 1.15, 0.85), V3(-1.58, HY - 0.12, -0.3), hair, { Rot = V3(0, 0, -6) })
		E("SideR", V3(0.48, 1.15, 0.85), V3(1.58, HY - 0.12, -0.3), hair, { Rot = V3(0, 0, 6) })
		local function spike(name, dir, len, w)
			dir = dir.Unit
			local p = V3(0, HY + 0.3, 0.15) + dir * (1.05 + len * 0.36)
			E(name, V3(w or 0.85, len, w or 0.85), CFrame.lookAt(p, p + dir) * CFrame.Angles(-math.pi / 2, 0, 0), hair)
		end
		if style == "spiky" then
			spike("SpikeTop", V3(0, 1, 0.12), 2.5)
			spike("SpikeL1", V3(-0.6, 0.85, 0.1), 2.3); spike("SpikeR1", V3(0.6, 0.85, 0.1), 2.3)
			spike("SpikeL2", V3(-0.95, 0.4, 0.25), 2.1); spike("SpikeR2", V3(0.95, 0.4, 0.25), 2.1)
			spike("SpikeB1", V3(0, 0.65, 0.8), 2.3)
			spike("SpikeBL", V3(-0.55, 0.45, 0.75), 2.0); spike("SpikeBR", V3(0.55, 0.45, 0.75), 2.0)
			spike("SpikeF", V3(0.25, 0.7, -0.55), 1.7, 0.75)
		elseif style == "long" then
			E("HairLong", V3(3.2, 4.6, 1.3), V3(0, HY - 1.35, 1.05), hair)
			E("LongL", V3(0.75, 2.6, 0.9), V3(-1.55, HY - 1.4, -0.1), hair)
			E("LongR", V3(0.75, 2.6, 0.9), V3(1.55, HY - 1.4, -0.1), hair)
		elseif style == "twin" then
			E("TailL", V3(1.05, 3.1, 1.05), V3(-2.05, HY - 0.75, 0.55), hair, { Rot = V3(0, 0, -16) })
			E("TailR", V3(1.05, 3.1, 1.05), V3(2.05, HY - 0.75, 0.55), hair, { Rot = V3(0, 0, 16) })
			E("TieL", V3(0.45, 0.45, 0.45), V3(-1.75, HY + 0.55, 0.5), acc)
			E("TieR", V3(0.45, 0.45, 0.45), V3(1.75, HY + 0.55, 0.5), acc)
		elseif style == "bun" then
			E("Bun", V3(1.6, 1.6, 1.6), V3(0, HY + 1.85, 0.55), hair)
		end
	end

	-- ---------------------------------------------------------------- acessórios
	for _, a in ipairs(L.Acc or {}) do
		if a == "headband" then
			Cyl("Headband", 0.42, 3.5, cfAt(V3(0, HY + 0.62, 0.05), V3(0, 0, 90)), acc)
			E("HeadbandKnot", V3(0.6, 0.5, 0.4), V3(0, HY + 0.6, 1.62), acc)
		elseif a == "scarf" then
			Cyl("Scarf", 0.55, 1.75, cfAt(V3(0, 3.1, 0), V3(0, 0, 90)), acc)
			E("ScarfTail", V3(0.55, 1.6, 0.3), V3(0.6, 2.45, 0.75), acc, { Rot = V3(10, 0, -10) })
		elseif a == "hat" then
			Cyl("HatBrim", 0.25, 4.9, cfAt(V3(0, HY + 1.45, 0), V3(0, 0, 90)), acc)
			E("HatTop", V3(2.9, 1.5, 2.9), V3(0, HY + 1.9, 0), acc)
		elseif a == "chefhat" then
			Cyl("ChefBand", 0.6, 3.1, cfAt(V3(0, HY + 1.55, 0), V3(0, 0, 90)), acc)
			E("ChefTop", V3(3.5, 2.0, 3.3), V3(0, HY + 2.5, 0), acc)
		elseif a == "foxears" then
			E("EarFoxL", V3(0.85, 1.6, 0.5), V3(-1.0, HY + 2.0, 0.1), hair, { Rot = V3(0, 0, 16) })
			E("EarFoxR", V3(0.85, 1.6, 0.5), V3(1.0, HY + 2.0, 0.1), hair, { Rot = V3(0, 0, -16) })
			E("EarInL", V3(0.45, 0.9, 0.2), V3(-1.0, HY + 1.95, -0.08), Color3.fromRGB(255, 190, 200), { Rot = V3(0, 0, 16), NoTint = true })
			E("EarInR", V3(0.45, 0.9, 0.2), V3(1.0, HY + 1.95, -0.08), Color3.fromRGB(255, 190, 200), { Rot = V3(0, 0, -16), NoTint = true })
		elseif a == "tail" then
			E("Tail1", V3(0.9, 0.9, 1.4), V3(0, 1.5, 1.2), hair, { Rot = V3(-20, 0, 0) })
			E("Tail2", V3(1.25, 1.25, 1.6), V3(0, 2.0, 2.1), hair, { Rot = V3(-35, 0, 0) })
			E("Tail3", V3(0.95, 0.95, 0.95), V3(0, 2.6, 2.75), Color3.new(1, 1, 1))
		elseif a == "horns" then
			E("HornL", V3(0.5, 1.4, 0.5), V3(-0.85, HY + 1.85, -0.3), acc, { Rot = V3(0, 0, 18), Mat = Enum.Material.Neon })
			E("HornR", V3(0.5, 1.4, 0.5), V3(0.85, HY + 1.85, -0.3), acc, { Rot = V3(0, 0, -18), Mat = Enum.Material.Neon })
		elseif a == "halo" then
			Cyl("Halo", 0.22, 3.6, cfAt(V3(0, HY + 2.9, 0), V3(0, 0, 90)), acc, { Mat = Enum.Material.Neon, NoTint = true })
		elseif a == "crown" then
			Cyl("CrownBase", 0.55, 2.5, cfAt(V3(0, HY + 1.75, 0), V3(0, 0, 90)), acc, { Mat = Enum.Material.Metal })
			for k = 0, 4 do
				local ang = rad(k * 72)
				E("CrownTip" .. k, V3(0.42, 0.75, 0.42), V3(math.sin(ang) * 1.05, HY + 2.2, -math.cos(ang) * 1.05), acc, { Mat = Enum.Material.Metal })
			end
		elseif a == "cape" then
			E("Cape", V3(2.6, 3.2, 0.32), V3(0, 1.95, 0.85), acc, { Rot = V3(-8, 0, 0) })
			E("CapeTop", V3(2.2, 0.5, 1.2), V3(0, 3.05, 0.35), acc)
		elseif a == "sword" then
			B("SwordHandle", V3(0.32, 1.0, 0.4), V3(1.25, 1.95, 0.85), Color3.fromRGB(70, 50, 40), { Rot = V3(0, 0, -35) })
			B("SwordBlade", V3(0.28, 3.4, 0.45), V3(2.35, 3.25, 0.85), Color3.fromRGB(235, 245, 255), { Rot = V3(0, 0, -35), Mat = Enum.Material.Neon, NoTint = true })
		elseif a == "wings" then
			E("WingL", V3(0.3, 2.8, 2.0), V3(-1.4, 3.1, 1.15), acc, { Rot = V3(0, 22, 20), Mat = Enum.Material.Neon })
			E("WingR", V3(0.3, 2.8, 2.0), V3(1.4, 3.1, 1.15), acc, { Rot = V3(0, -22, -20), Mat = Enum.Material.Neon })
		elseif a == "beanie" then
			E("Beanie", V3(3.5, 2.0, 3.3), V3(0, HY + 1.2, 0.05), acc)
			Cyl("BeanieBand", 0.5, 3.45, cfAt(V3(0, HY + 0.55, 0.05), V3(0, 0, 90)), acc:Lerp(Color3.new(1, 1, 1), 0.5))
			E("Pom", V3(0.95, 0.95, 0.95), V3(0, HY + 2.25, 0.05), Color3.new(1, 1, 1))
		elseif a == "visor" then
			-- óculos escuros (2 lentes + ponte) na cor AccColor escurecida
			local lens = acc:Lerp(Color3.new(0, 0, 0), 0.55)
			E("LensL", V3(0.92, 0.72, 0.2), onHead(-0.6, -0.1, 0.16), lens, { Mat = Enum.Material.Glass, NoTint = true, Transparency = 0.05 })
			E("LensR", V3(0.92, 0.72, 0.2), onHead(0.6, -0.1, 0.16), lens, { Mat = Enum.Material.Glass, NoTint = true, Transparency = 0.05 })
			B("Bridge", V3(0.45, 0.1, 0.1), onHead(0, 0.05, 0.12), Color3.fromRGB(40, 40, 46), { NoTint = true })
			E("LensShineL", V3(0.22, 0.14, 0.1), onHead(-0.78, 0.08, 0.26), Color3.new(1, 1, 1), { Mat = Enum.Material.Neon, NoTint = true, Transparency = 0.3 })
			E("LensShineR", V3(0.22, 0.14, 0.1), onHead(0.42, 0.08, 0.26), Color3.new(1, 1, 1), { Mat = Enum.Material.Neon, NoTint = true, Transparency = 0.3 })
		elseif a == "staff" then
			Cyl("Staff", 6.6, 0.38, cfAt(V3(1.9, 3.3, -0.6), V3(0, 0, 90)), Color3.fromRGB(110, 78, 50))
			E("StaffOrb", V3(1.25, 1.25, 1.25), V3(1.9, 6.85, -0.6), acc, { Mat = Enum.Material.Neon, NoTint = true })
		elseif a == "beard" then
			E("Beard", V3(1.7, 1.5, 0.6), onHead(0, -1.05, -0.12) * CFrame.new(0, -0.45, 0), Color3.fromRGB(250, 250, 250), { NoTint = true })
			E("Mustache", V3(1.25, 0.34, 0.3), onHead(0, -0.6, 0.04), Color3.fromRGB(250, 250, 250), { NoTint = true })
		elseif a == "turban" then
			E("Turban", V3(3.6, 2.1, 3.4), V3(0, HY + 1.05, 0.05), Color3.fromRGB(245, 245, 245))
			E("TurbanTop", V3(2.5, 1.0, 2.4), V3(0, HY + 1.95, 0.05), Color3.fromRGB(232, 232, 232))
			E("TurbanGem", V3(0.42, 0.42, 0.2), onHead(0, 1.18, 0.12), Color3.fromRGB(150, 60, 220), { Mat = Enum.Material.Neon, NoTint = true })
		elseif a == "antenna" then
			E("AntennaL", V3(0.28, 1.6, 0.28), V3(-0.5, HY + 2.15, -0.9), skin, { Rot = V3(-25, 0, 12) })
			E("AntennaR", V3(0.28, 1.6, 0.28), V3(0.5, HY + 2.15, -0.9), skin, { Rot = V3(-25, 0, -12) })
		elseif a == "crest" then
			E("CrestL", V3(0.7, 3.2, 1.3), V3(-1.05, HY + 2.15, 0.25), acc, { Rot = V3(0, 0, 18) })
			E("CrestR", V3(0.7, 3.2, 1.3), V3(1.05, HY + 2.15, 0.25), acc, { Rot = V3(0, 0, -18) })
			E("CrestBack", V3(2.7, 1.4, 1.8), V3(0, HY + 1.25, 0.9), acc)
		elseif a == "headtail" then
			E("HeadTail", V3(0.95, 2.6, 0.95), V3(0, HY + 2.05, 0.65), skin, { Rot = V3(-35, 0, 0) })
		elseif a == "belt" then
			Cyl("Belt", 0.42, 1.95, cfAt(V3(0, 1.62, 0), V3(0, 0, 90)), L.BeltColor or acc)
			E("BeltKnot", V3(0.5, 0.8, 0.3), V3(0.45, 1.35, -0.8), L.BeltColor or acc)
		elseif a == "mecha" then
			E("PadL", V3(1.3, 0.85, 1.45), V3(-1.2, 3.0, 0), acc)
			E("PadR", V3(1.3, 0.85, 1.45), V3(1.2, 3.0, 0), acc)
			E("Chest", V3(1.5, 1.15, 0.32), V3(0, 2.4, -0.66), acc:Lerp(Color3.new(1, 1, 1), 0.35))
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
		E("SecretAura", V3(4.8, 8.2, 4.4), V3(0, 3.9, 0), Color3.fromRGB(40, 40, 50), { Mat = Enum.Material.ForceField, NoTint = true, Shadow = false })
		Cyl("SecretRing", 0.3, 6.2, cfAt(V3(0, 0.2, 0), V3(0, 0, 90)), Color3.fromRGB(20, 20, 26), { Mat = Enum.Material.Neon, NoTint = true, Shadow = false })
		Cyl("SecretRingGlow", 0.32, 5.2, cfAt(V3(0, 0.22, 0), V3(0, 0, 90)), Color3.fromRGB(210, 210, 225), { Mat = Enum.Material.Neon, NoTint = true, Shadow = false })
		E("SecretStar", V3(1.0, 1.0, 1.0), V3(0, HY + 3.4, 0), Color3.fromRGB(235, 235, 245), { Mat = Enum.Material.Neon, NoTint = true, Shadow = false })
	end

	-- tamanho (BIG)
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
