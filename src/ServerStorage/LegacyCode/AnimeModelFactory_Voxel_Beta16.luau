--[[
	AnimeModelFactory: gera personagens anime "chibi voxel" por código a partir de
	Config.Animes[i].Look. Usado pelo servidor (fazenda) e pelo cliente (ViewportFrames).
	  Build(cfg, mut, size) -> Model (PrimaryPart "Root" nos PÉS; frente = -Z)
	  Silhouette(model)     -> recolore tudo de preto (pontos "misteriosos" no mapa)

	PIPELINE BLENDER: se existir ServerStorage/ReplicatedStorage "Models/Animes/<Id>",
	troque a geração procedural por esse modelo (mantenha Root nos pés e frente -Z).
	Os modelos de Blender devem ser importados via Asset Manager > Bulk Import (FBX/GLB).
	IMPORTANTE: use personagens ORIGINAIS (nada de IP de anime existente) para evitar
	remoções por direitos autorais no Roblox.
]]
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)

local F = {}
local V3 = Vector3.new

function F.Build(cfg, mut, size)
	local L = cfg.Look
	local m = Instance.new("Model")
	m.Name = cfg.Id

	local function P(name, sz, pos, color, o)
		o = o or {}
		local p = Instance.new("Part")
		p.Name = name; p.Size = sz
		local cf = CFrame.new(pos)
		if o.Rot then cf = cf * CFrame.Angles(math.rad(o.Rot.X), math.rad(o.Rot.Y), math.rad(o.Rot.Z)) end
		p.CFrame = cf; p.Color = color
		p.Material = o.Mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		if o.Shape then p.Shape = o.Shape end
		if o.NoTint then p:SetAttribute("NoTint", true) end
		p.Parent = m
		return p
	end

	local root = P("Root", V3(0.2, 0.1, 0.2), V3(0, 0.05, 0), Color3.new(), { NoTint = true })
	root.Transparency = 1
	m.PrimaryPart = root

	local skin, hair, eyes = L.Skin, L.Hair, L.Eyes
	local o1, o2 = L.Outfit, L.Outfit2
	local acc = L.AccColor or Color3.new(1, 1, 1)

	-- Corpo
	P("LegL", V3(0.95, 1.2, 0.95), V3(-0.6, 0.65, 0), o2)
	P("LegR", V3(0.95, 1.2, 0.95), V3(0.6, 0.65, 0), o2)
	P("Torso", V3(2.2, 1.8, 1.3), V3(0, 2.15, 0), o1)
	P("ArmL", V3(0.75, 1.2, 0.75), V3(-1.5, 2.45, 0), o1)
	P("ArmR", V3(0.75, 1.2, 0.75), V3(1.5, 2.45, 0), o1)
	P("HandL", V3(0.75, 0.5, 0.75), V3(-1.5, 1.6, 0), skin)
	P("HandR", V3(0.75, 0.5, 0.75), V3(1.5, 1.6, 0), skin)
	-- Cabeça (grande = chibi)
	P("Head", V3(2.9, 2.6, 2.7), V3(0, 4.35, 0), skin)
	-- Rosto
	P("EyeL", V3(0.6, 0.95, 0.12), V3(-0.8, 4.2, -1.4), eyes, { NoTint = true })
	P("EyeR", V3(0.6, 0.95, 0.12), V3(0.8, 4.2, -1.4), eyes, { NoTint = true })
	P("PupilL", V3(0.3, 0.55, 0.13), V3(-0.8, 4.1, -1.42), Color3.fromRGB(25, 25, 40), { NoTint = true })
	P("PupilR", V3(0.3, 0.55, 0.13), V3(0.8, 4.1, -1.42), Color3.fromRGB(25, 25, 40), { NoTint = true })
	P("ShineL", V3(0.22, 0.26, 0.14), V3(-0.68, 4.45, -1.44), Color3.new(1, 1, 1), { NoTint = true, Mat = Enum.Material.Neon })
	P("ShineR", V3(0.22, 0.26, 0.14), V3(0.92, 4.45, -1.44), Color3.new(1, 1, 1), { NoTint = true, Mat = Enum.Material.Neon })
	P("Mouth", V3(0.55, 0.12, 0.12), V3(0, 3.55, -1.4), Color3.fromRGB(170, 70, 80), { NoTint = true })
	P("BlushL", V3(0.55, 0.22, 0.12), V3(-1.05, 3.75, -1.4), Color3.fromRGB(255, 150, 150), { NoTint = true })
	P("BlushR", V3(0.55, 0.22, 0.12), V3(1.05, 3.75, -1.4), Color3.fromRGB(255, 150, 150), { NoTint = true })

	-- Cabelo (Beta 1.6: Look.Bald = true pula o cabelo — Kuririn, Master Kame)
	if not L.Bald then
	local style = L.Style or "short"
	P("HairTop", V3(3.1, 0.8, 2.9), V3(0, 5.7, 0), hair)
	P("Bangs", V3(3.1, 0.7, 0.6), V3(0, 5.2, -1.5), hair)
	P("LockL", V3(0.7, 1.3, 0.5), V3(-1.2, 4.75, -1.5), hair)
	P("LockR", V3(0.7, 1.3, 0.5), V3(1.2, 4.75, -1.5), hair)
	P("SideL", V3(0.45, 2.0, 2.5), V3(-1.65, 4.75, 0.1), hair)
	P("SideR", V3(0.45, 2.0, 2.5), V3(1.65, 4.75, 0.1), hair)
	local backH, backY = 2.2, 4.8
	if style == "long" then backH, backY = 4.4, 3.5 end
	P("HairBack", V3(3.1, backH, 0.7), V3(0, backY, 1.45), hair)
	if style == "twin" then
		P("TailL", V3(0.9, 3.0, 0.9), V3(-2.1, 3.6, 0.8), hair)
		P("TailR", V3(0.9, 3.0, 0.9), V3(2.1, 3.6, 0.8), hair)
	elseif style == "spiky" then
		P("SpikeA", V3(0.8, 1.9, 0.8), V3(0, 6.7, 0), hair, { Rot = V3(0, 0, 0) })
		P("SpikeB", V3(0.8, 1.7, 0.8), V3(-1.1, 6.5, 0), hair, { Rot = V3(0, 0, 25) })
		P("SpikeC", V3(0.8, 1.7, 0.8), V3(1.1, 6.5, 0), hair, { Rot = V3(0, 0, -25) })
		P("SpikeD", V3(0.8, 1.5, 0.8), V3(0, 6.4, 0.9), hair, { Rot = V3(-25, 0, 0) })
	elseif style == "bun" then
		P("Bun", V3(1.5, 1.5, 1.5), V3(0, 6.8, 0.2), hair)
	end

	end

	-- Acessórios
	for _, a in ipairs(L.Acc or {}) do
		if a == "headband" then P("Headband", V3(3.2, 0.45, 3.0), V3(0, 5.15, 0), acc)
		elseif a == "scarf" then
			P("Scarf", V3(2.5, 0.6, 1.6), V3(0, 3.15, 0), acc)
			P("ScarfTail", V3(0.7, 1.6, 0.3), V3(0.9, 2.4, 0.85), acc)
		elseif a == "hat" then
			P("HatBrim", V3(0.3, 4.8, 4.8), V3(0, 6.15, 0), acc, { Shape = Enum.PartType.Cylinder, Rot = V3(0, 0, 90) })
			P("HatTop", V3(2.6, 1.0, 2.6), V3(0, 6.6, 0), acc)
		elseif a == "chefhat" then
			P("ChefBand", V3(3.0, 0.6, 2.8), V3(0, 6.2, 0), acc)
			P("ChefTop", V3(3.4, 1.7, 3.2), V3(0, 7.3, 0), acc)
		elseif a == "foxears" then
			P("EarL", V3(0.9, 1.4, 0.5), V3(-0.95, 6.7, 0), hair, { Rot = V3(0, 0, 14) })
			P("EarR", V3(0.9, 1.4, 0.5), V3(0.95, 6.7, 0), hair, { Rot = V3(0, 0, -14) })
		elseif a == "tail" then
			P("Tail1", V3(0.9, 0.9, 1.2), V3(0, 1.5, 1.3), hair)
			P("Tail2", V3(1.2, 1.2, 1.4), V3(0, 1.9, 2.2), hair)
			P("Tail3", V3(1.0, 1.0, 1.0), V3(0, 2.5, 3.0), Color3.new(1, 1, 1))
		elseif a == "horns" then
			P("HornL", V3(0.6, 1.3, 0.6), V3(-0.9, 6.5, -0.4), acc, { Rot = V3(0, 0, 14), Mat = Enum.Material.Neon })
			P("HornR", V3(0.6, 1.3, 0.6), V3(0.9, 6.5, -0.4), acc, { Rot = V3(0, 0, -14), Mat = Enum.Material.Neon })
		elseif a == "halo" then
			P("Halo", V3(0.25, 3.8, 3.8), V3(0, 7.7, 0), acc, { Shape = Enum.PartType.Cylinder, Rot = V3(0, 0, 90), Mat = Enum.Material.Neon, NoTint = true })
		elseif a == "crown" then
			P("CrownBase", V3(2.6, 0.5, 2.4), V3(0, 6.35, 0), acc, { Mat = Enum.Material.Metal })
			P("CrownA", V3(0.5, 0.8, 0.5), V3(-0.9, 6.9, 0), acc, { Mat = Enum.Material.Metal })
			P("CrownB", V3(0.5, 1.0, 0.5), V3(0, 6.95, 0), acc, { Mat = Enum.Material.Metal })
			P("CrownC", V3(0.5, 0.8, 0.5), V3(0.9, 6.9, 0), acc, { Mat = Enum.Material.Metal })
		elseif a == "cape" then P("Cape", V3(2.8, 3.0, 0.3), V3(0, 2.2, 0.95), acc)
		elseif a == "sword" then
			P("SwordHandle", V3(0.35, 1.0, 0.45), V3(1.3, 1.9, 0.9), Color3.fromRGB(70, 50, 40), { Rot = V3(0, 0, -35) })
			P("SwordBlade", V3(0.3, 3.4, 0.5), V3(2.4, 3.2, 0.9), Color3.fromRGB(235, 245, 255), { Rot = V3(0, 0, -35), Mat = Enum.Material.Neon, NoTint = true })
		elseif a == "wings" then
			P("WingL", V3(0.3, 2.6, 1.9), V3(-1.5, 3.4, 1.2), acc, { Rot = V3(0, 20, 18), Mat = Enum.Material.Neon })
			P("WingR", V3(0.3, 2.6, 1.9), V3(1.5, 3.4, 1.2), acc, { Rot = V3(0, -20, -18), Mat = Enum.Material.Neon })
		elseif a == "beanie" then
			P("Beanie", V3(3.3, 1.4, 3.1), V3(0, 6.3, 0), acc)
			P("BeanieBand", V3(3.4, 0.5, 3.2), V3(0, 5.7, 0), acc:Lerp(Color3.new(1, 1, 1), 0.5))
			P("Pom", V3(1.0, 1.0, 1.0), V3(0, 7.3, 0), Color3.new(1, 1, 1))
		elseif a == "visor" then
			P("Visor", V3(2.9, 0.75, 0.3), V3(0, 4.6, -1.55), acc, { Mat = Enum.Material.Neon, NoTint = true })
		elseif a == "staff" then
			P("Staff", V3(0.4, 6.6, 0.4), V3(2.1, 3.4, -0.6), Color3.fromRGB(110, 78, 50))
			P("StaffOrb", V3(1.3, 1.3, 1.3), V3(2.1, 7.0, -0.6), acc, { Mat = Enum.Material.Neon, NoTint = true })
		-- Beta 1.6: acessórios para o elenco do bioma 1 (barba, turbante, antenas, crista, "rabinho" na cabeça, cinto)
		elseif a == "beard" then
			P("Beard", V3(2.3, 1.7, 0.6), V3(0, 3.25, -1.5), Color3.fromRGB(250, 250, 250), { NoTint = true })
			P("Mustache", V3(1.8, 0.45, 0.4), V3(0, 3.85, -1.55), Color3.fromRGB(250, 250, 250), { NoTint = true })
		elseif a == "turban" then
			P("Turban", V3(3.3, 1.7, 3.1), V3(0, 6.0, 0), Color3.fromRGB(245, 245, 245))
			P("TurbanTop", V3(2.4, 0.8, 2.3), V3(0, 7.1, 0), Color3.fromRGB(235, 235, 235))
		elseif a == "antenna" then
			P("AntennaL", V3(0.3, 1.6, 0.3), V3(-0.5, 6.4, -1.1), skin, { Rot = V3(-25, 0, 12) })
			P("AntennaR", V3(0.3, 1.6, 0.3), V3(0.5, 6.4, -1.1), skin, { Rot = V3(-25, 0, -12) })
		elseif a == "crest" then
			P("CrestL", V3(0.7, 3.4, 1.4), V3(-1.1, 6.9, 0.2), acc, { Rot = V3(0, 0, 18) })
			P("CrestR", V3(0.7, 3.4, 1.4), V3(1.1, 6.9, 0.2), acc, { Rot = V3(0, 0, -18) })
			P("CrestBack", V3(2.6, 1.2, 1.6), V3(0, 6.0, 0.9), acc)
		elseif a == "headtail" then
			P("HeadTail", V3(0.9, 2.4, 0.9), V3(0, 6.6, 0.6), skin, { Rot = V3(-35, 0, 0) })
		elseif a == "belt" then
			P("Belt", V3(2.35, 0.45, 1.4), V3(0, 1.4, 0), L.BeltColor or acc)
			P("BeltKnot", V3(0.6, 0.9, 0.3), V3(0.5, 1.1, -0.72), L.BeltColor or acc)
		elseif a == "mecha" then
			P("PadL", V3(1.5, 0.9, 1.6), V3(-1.7, 3.2, 0), acc)
			P("PadR", V3(1.5, 0.9, 1.6), V3(1.7, 3.2, 0), acc)
			P("Chest", V3(1.2, 1.0, 0.2), V3(0, 2.4, -0.7), acc, { Mat = Enum.Material.Neon })
		end
	end

	-- Mutação (Gold/Diamond)
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

	-- SECRET: aura neon translúcida + estrela flutuante (fica de fora do tingimento das mutações)
	if cfg.Rarity == "Secret" then
		P("SecretAura", V3(4.6, 7.6, 4.0), V3(0, 3.6, 0), Color3.fromRGB(255, 255, 255), { Mat = Enum.Material.ForceField, NoTint = true })
		P("SecretRing", V3(0.3, 6.2, 6.2), V3(0, 0.25, 0), Color3.fromRGB(255, 120, 255), { Shape = Enum.PartType.Cylinder, Rot = V3(0, 0, 90), Mat = Enum.Material.Neon, NoTint = true })
		P("SecretStar", V3(1.1, 1.1, 1.1), V3(0, 8.9, 0), Color3.fromRGB(255, 240, 120), { Rot = V3(45, 45, 0), Mat = Enum.Material.Neon, NoTint = true })
	end

	-- Tamanho (BIG)
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
