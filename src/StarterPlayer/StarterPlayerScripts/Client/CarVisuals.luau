--[[ CarVisuals: gira e esterça as rodas de TODOS os carros (localmente, a partir da velocidade). ]]
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local CarFactory = require(RS.Shared.CarFactory)
local Players = game:GetService("Players")
local Drive = require(script.Parent.DriveController)
local lp = Players.LocalPlayer

-- Beta 1.2: aura de energia (partículas subindo + brilho) no próprio carro enquanto o BOOST está ativo
local function makeAura(chassis)
	local e = Instance.new("ParticleEmitter")
	e.Name = "BoostAura"
	e.Color = ColorSequence.new(Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 255, 255))
	e.LightEmission = 1; e.LightInfluence = 0; e.Rate = 70
	e.Lifetime = NumberRange.new(0.35, 0.6); e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(40, 40); e.Acceleration = Vector3.new(0, 18, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.EmissionDirection = Enum.NormalId.Top; e.Enabled = false
	e.Parent = chassis
	local l = Instance.new("PointLight"); l.Name = "BoostGlow"; l.Color = Color3.fromRGB(120, 230, 255); l.Range = 22; l.Brightness = 3; l.Enabled = false; l.Parent = chassis
	return e, l
end

local CarVisuals = {}
local tracked = {}

local function collect(d)
	d.Wheels = {}
	for _, w in ipairs(d.Car:GetDescendants()) do
		if w:IsA("Weld") and w.Name:sub(1, 6) == "Wheel_" then
			table.insert(d.Wheels, { Weld = w, C0 = w.C0, Front = (w.Name == "Wheel_FL" or w.Name == "Wheel_FR") })
		end
	end
end

function CarVisuals.Init()
	local folder = workspace:WaitForChild("Cars")
	local function add(car) tracked[car] = { Car = car, Spin = 0, Steer = 0, Wheels = {}, Scan = 0 } end
	folder.ChildAdded:Connect(add)
	folder.ChildRemoved:Connect(function(c) tracked[c] = nil end)
	for _, c in ipairs(folder:GetChildren()) do add(c) end

	RunService.RenderStepped:Connect(function(dt)
		for car, d in pairs(tracked) do
			local chassis = car:FindFirstChild("Chassis")
			if chassis and car:GetAttribute("OwnerUserId") == lp.UserId then
				local aura, glow = chassis:FindFirstChild("BoostAura"), chassis:FindFirstChild("BoostGlow")
				if not aura then aura, glow = makeAura(chassis) end
				local on = Drive.IsBoosting()
				aura.Enabled = on; if glow then glow.Enabled = on end
			end
			if chassis then
				if #d.Wheels < 4 then
					d.Scan += dt
					if d.Scan > 0.5 then d.Scan = 0; collect(d) end
				end
				local vF = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
				d.Spin -= vF / CarFactory.WheelRadius * dt
				local seat = car:FindFirstChild("Seat")
				local target = (seat and seat:IsA("VehicleSeat")) and seat.SteerFloat or 0
				d.Steer += (-target * 0.45 - d.Steer) * math.min(1, dt * 10)
				for _, w in ipairs(d.Wheels) do
					if w.Weld.Parent then
						local c0 = w.C0
						if w.Front then c0 = c0 * CFrame.Angles(0, d.Steer, 0) end
						w.Weld.C0 = c0 * CFrame.Angles(d.Spin, 0, 0)
					end
				end
			end
		end
	end)
end

return CarVisuals
