--[[
	CarFactory: constrói o modelo do carro por código (estilo voxel/chunky).
	  CarFactory.Build(cfg, preview)  -> Model (PrimaryPart = "Chassis"; frente = -Z)
	  preview=true  -> versão estática (Anchored, sem assento) para ViewportFrame/UI.
	A física NÃO é feita por rodas reais: o carro é um corpo único com SUSPENSÃO POR RAYCAST
	(ver StarterPlayerScripts.Client.DriveController). Isso o torna estável em terreno
	irregular, impossível de "agarrar" em degraus e barato em rede.
	Para trocar pelo modelo do Blender: mantenha Chassis/Seat e as Welds "Wheel_XX".

	Beta 1.9: cfg.Body == "f1" (Config.F1Cars) => carroceria de FÓRMULA 1 (corrida 1v1): baixa, bico, asa dianteira
	  e traseira, entradas laterais, halo e rodas expostas. O Chassis, o Seat e as rodas (mesmos WheelPoints) são
	  IGUAIS aos do carro normal, então a física do DriveController não muda em nada.
]]
local CarFactory = {}

CarFactory.WheelRadius = 1.8
CarFactory.WheelPoints = {
	FL = Vector3.new(-4.3, -0.2, -4.7), FR = Vector3.new(4.3, -0.2, -4.7),
	RL = Vector3.new(-4.3, -0.2, 4.7),  RR = Vector3.new(4.3, -0.2, 4.7),
}
CarFactory.WheelList = { "FL", "FR", "RL", "RR" }
CarFactory.Rest = CarFactory.WheelRadius + 1.0     -- distância (centro da roda->chão) com mola relaxada
CarFactory.RayLength = CarFactory.Rest + 0.8

function CarFactory.Build(cfg, preview)
	local model = Instance.new("Model")
	model.Name = "Car"
	model:SetAttribute("CarId", cfg.Id)

	local function part(name, size, pos, color, props)
		local p = Instance.new("Part")
		p.Name = name; p.Size = size; p.CFrame = CFrame.new(pos); p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true
		p.Anchored = preview and true or false
		if props then for k, v in pairs(props) do p[k] = v end end
		p.Parent = model
		return p
	end

	local body = cfg.Color
	local accent = cfg.Accent or Color3.new(1, 1, 1)
	local dark = Color3.fromRGB(30, 30, 38)

	-- Chassi (único corpo físico)
	local chassis = part("Chassis", Vector3.new(8, 2, 13.4), Vector3.zero, body, {
		Transparency = 1, CanCollide = true, CanQuery = true, CanTouch = true, Massless = false,
		CustomPhysicalProperties = PhysicalProperties.new(2, 0.05, 0.05, 100, 100),
	})
	model.PrimaryPart = chassis

	local seatPos = Vector3.new(0, 1.7, 1.6)
	if cfg.Body == "f1" then
		-- Beta 1.9: carroceria de Fórmula 1 (peças só visuais; frente = -Z)
		seatPos = Vector3.new(0, 0.2, 0.9)
		local red = Color3.fromRGB(255, 50, 60)
		part("Floor",      Vector3.new(6.6, 0.4, 12.4),  Vector3.new(0, -0.75, 0.2),   dark)
		part("Monocoque",  Vector3.new(2.8, 1.5, 9.4),   Vector3.new(0, 0.1, 0.8),     body)
		part("Nose",       Vector3.new(1.7, 0.9, 4.6),   Vector3.new(0, -0.15, -5.6),  body)
		part("NoseTip",    Vector3.new(1.2, 0.6, 1.4),   Vector3.new(0, -0.35, -8.4),  accent)
		part("Stripe",     Vector3.new(0.7, 0.12, 9.2),  Vector3.new(0, 0.88, 0.8),    accent)
		part("FrontWing",  Vector3.new(9.6, 0.3, 1.9),   Vector3.new(0, -0.95, -8.6),  accent)
		part("FWingEndL",  Vector3.new(0.3, 1.2, 2.1),   Vector3.new(-4.8, -0.5, -8.6), dark)
		part("FWingEndR",  Vector3.new(0.3, 1.2, 2.1),   Vector3.new(4.8, -0.5, -8.6),  dark)
		part("SidePodL",   Vector3.new(1.9, 1.3, 5.2),   Vector3.new(-2.3, -0.05, 1.6), body)
		part("SidePodR",   Vector3.new(1.9, 1.3, 5.2),   Vector3.new(2.3, -0.05, 1.6),  body)
		part("IntakeL",    Vector3.new(1.5, 0.9, 0.3),   Vector3.new(-2.3, 0, -1.05),   dark)
		part("IntakeR",    Vector3.new(1.5, 0.9, 0.3),   Vector3.new(2.3, 0, -1.05),    dark)
		part("EngineCover",Vector3.new(1.7, 1.7, 4.8),   Vector3.new(0, 1.0, 3.8),     body)
		part("Airbox",     Vector3.new(1.1, 0.9, 1.1),   Vector3.new(0, 2.1, 2.0),     dark)
		part("HaloL",      Vector3.new(0.28, 0.28, 3.0), Vector3.new(-1.15, 1.75, 0.1), dark)
		part("HaloR",      Vector3.new(0.28, 0.28, 3.0), Vector3.new(1.15, 1.75, 0.1),  dark)
		part("HaloFront",  Vector3.new(2.58, 0.28, 0.28), Vector3.new(0, 1.75, -1.4),   dark)
		part("HaloPost",   Vector3.new(0.28, 1.0, 0.28), Vector3.new(0, 1.3, -1.4),    dark)
		part("RearWing",   Vector3.new(8.2, 0.35, 1.7),  Vector3.new(0, 2.8, 6.7),     accent)
		part("RearWing2",  Vector3.new(8.2, 0.3, 1.1),   Vector3.new(0, 2.0, 7.0),     body)
		part("RWingEndL",  Vector3.new(0.3, 2.3, 2.3),   Vector3.new(-4.1, 2.0, 6.7),  dark)
		part("RWingEndR",  Vector3.new(0.3, 2.3, 2.3),   Vector3.new(4.1, 2.0, 6.7),   dark)
		part("RWingPost",  Vector3.new(0.5, 1.6, 0.8),   Vector3.new(0, 1.0, 6.6),     dark)
		part("TailL",      Vector3.new(0.9, 0.5, 0.3),   Vector3.new(0, 0.1, 6.95),    red, { Material = Enum.Material.Neon })
	else
	-- Carroceria (peças só visuais)
	part("Body",      Vector3.new(8.4, 2.4, 14),   Vector3.new(0, 0.2, 0),      body)
	part("Hood",      Vector3.new(7.6, 0.8, 5),    Vector3.new(0, 1.6, -4.2),   body)
	part("Stripe",    Vector3.new(1.8, 0.2, 13.6), Vector3.new(0, 1.5, 0),      accent)
	part("Windshield",Vector3.new(6.6, 2.4, 0.4),  Vector3.new(0, 2.7, -1.4),   Color3.fromRGB(150, 225, 255), { Transparency = 0.35, Material = Enum.Material.Glass, CFrame = CFrame.new(0, 2.7, -1.4) * CFrame.Angles(math.rad(-22), 0, 0) })
	part("RollBar",   Vector3.new(7.4, 0.6, 0.8),  Vector3.new(0, 4.0, 3.6),    dark)
	part("RollPostL", Vector3.new(0.6, 3, 0.8),    Vector3.new(-3.4, 2.6, 3.6), dark)
	part("RollPostR", Vector3.new(0.6, 3, 0.8),    Vector3.new(3.4, 2.6, 3.6),  dark)
	part("Spoiler",   Vector3.new(8.6, 0.5, 1.8),  Vector3.new(0, 3.1, 7.2),    accent)
	part("SpoilL",    Vector3.new(0.6, 1.6, 0.8),  Vector3.new(-3, 2.2, 7.0),   dark)
	part("SpoilR",    Vector3.new(0.6, 1.6, 0.8),  Vector3.new(3, 2.2, 7.0),    dark)
	part("BumperF",   Vector3.new(8.8, 0.9, 0.9),  Vector3.new(0, -0.5, -7.2),  dark)
	part("BumperR",   Vector3.new(8.8, 0.9, 0.9),  Vector3.new(0, -0.5, 7.2),   dark)
	part("HeadL",     Vector3.new(1.8, 1, 0.4),    Vector3.new(-2.8, 0.5, -7.1),Color3.fromRGB(255, 244, 160), { Material = Enum.Material.Neon })
	part("HeadR",     Vector3.new(1.8, 1, 0.4),    Vector3.new(2.8, 0.5, -7.1), Color3.fromRGB(255, 244, 160), { Material = Enum.Material.Neon })
	part("TailL",     Vector3.new(1.8, 0.8, 0.4),  Vector3.new(-2.8, 0.7, 7.1), Color3.fromRGB(255, 50, 60),   { Material = Enum.Material.Neon })
	part("TailR",     Vector3.new(1.8, 0.8, 0.4),  Vector3.new(2.8, 0.7, 7.1),  Color3.fromRGB(255, 50, 60),   { Material = Enum.Material.Neon })
	end -- fim da carroceria (f1 / normal)

	if not preview then
		for _, n in ipairs({ "HeadL", "HeadR" }) do
			local hp = model:FindFirstChild(n)
			local sl = Instance.new("SpotLight")
			sl.Face = Enum.NormalId.Front; sl.Range = 70; sl.Angle = 55; sl.Brightness = 2.5
			sl.Color = Color3.fromRGB(255, 244, 200); sl.Parent = hp
		end
	end

	-- Assento (VehicleSeat lê as teclas/analógico/toque automaticamente)
	local seat
	if preview then
		seat = part("Seat", Vector3.new(2.8, 0.6, 2.8), seatPos, dark)
	else
		seat = Instance.new("VehicleSeat")
		seat.Name = "Seat"; seat.Size = Vector3.new(2.8, 0.6, 2.8)
		seat.CFrame = CFrame.new(seatPos); seat.Color = dark; seat.Material = Enum.Material.SmoothPlastic
		seat.MaxSpeed = 0; seat.Torque = 0; seat.TurnSpeed = 0   -- desliga a física legada; usamos o DriveController
		seat.CanCollide = false; seat.Massless = true
		seat.Parent = model
	end

	-- Rodas (somente visuais; a Weld permite girar/esterçar no cliente)
	local wheels = {}
	for _, key in ipairs(CarFactory.WheelList) do
		local pos = CarFactory.WheelPoints[key]
		local w = part("Wheel_" .. key, Vector3.new(1.7, CarFactory.WheelRadius * 2, CarFactory.WheelRadius * 2), pos, dark, {
			Shape = Enum.PartType.Cylinder,
		})
		part("Hub_" .. key, Vector3.new(1.8, 1.6, 1.6), pos, accent, { Shape = Enum.PartType.Cylinder, Name = "Hub_" .. key })
		wheels[key] = w
	end

	if not preview then
		-- Solda tudo ao chassi. Rodas usam Weld (com offset editável); o resto WeldConstraint.
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p ~= chassis then
				local isWheel = p.Name:sub(1, 6) == "Wheel_"
				local isHub = p.Name:sub(1, 4) == "Hub_"
				if isWheel then
					local weld = Instance.new("Weld")
					weld.Name = p.Name; weld.Part0 = chassis; weld.Part1 = p
					weld.C0 = chassis.CFrame:Inverse() * p.CFrame
					weld.Parent = p
				elseif isHub then
					local key = p.Name:sub(5)
					local wp = wheels[key]
					local weld = Instance.new("Weld")
					weld.Part0 = wp; weld.Part1 = p
					weld.C0 = wp.CFrame:Inverse() * p.CFrame
					weld.Parent = p
				else
					local wc = Instance.new("WeldConstraint")
					wc.Part0 = chassis; wc.Part1 = p; wc.Parent = p
				end
			end
		end
	end
	return model
end

return CarFactory
