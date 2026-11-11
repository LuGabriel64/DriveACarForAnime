--[[ EggVisuals: monta o modelo 3D de um ovo (casca elipsoide + pintas) a partir de Config.Eggs[biomeId].
     Usado pelos ovos de estrada (mundo), pela loja (ViewportFrame) e pela animação de chocar. ]]
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)

local EggVisuals = {}

function EggVisuals.Build(biomeId, scale)
	local egg = Config.Eggs[biomeId] or Config.Eggs[Config.Biomes[1].Id]
	scale = scale or 1
	local m = Instance.new("Model"); m.Name = "Egg"
	local function P(name, size, cf, color, mat, shape)
		local p = Instance.new("Part")
		p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Parent = m
		return p
	end
	local shell = P("Shell", Vector3.new(5, 6.6, 5) * scale, CFrame.new(0, 3.3 * scale, 0), egg.Color)
	local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = shell
	m.PrimaryPart = shell
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local y = (k % 2 == 0) and 1.1 or -0.6
		local r = 2.5 * math.sqrt(1 - (y / 3.3) ^ 2) - 0.25
		P("Spot", Vector3.new(1.2, 1.2, 1.2) * scale, CFrame.new(math.cos(a) * r * scale, (3.3 + y) * scale, math.sin(a) * r * scale), egg.Spot, nil, Enum.PartType.Ball)
	end
	P("Shine", Vector3.new(0.9, 1.6, 0.9) * scale, CFrame.new(-1.2 * scale, 4.9 * scale, -1.6 * scale) * CFrame.Angles(0.3, 0, 0.4), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
	return m
end

return EggVisuals
