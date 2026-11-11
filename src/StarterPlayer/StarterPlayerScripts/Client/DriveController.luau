--[[
	DriveController: FÍSICA ARCADE do carro (roda no cliente dono do carro).
	O carro é UM corpo rígido (Chassis) com 4 "molas" por RAYCAST (uma por roda):
	  1. Suspensão: mola+amortecedor empurram o chassi para cima a partir do chão (impulso por roda =>
	     inclinação natural em curvas/ladeiras, passa por degraus sem agarrar).
	  2. Tração: acelera até MaxSpeed ao longo do plano do chão; freia sozinho se solto.
	  3. Aderência lateral: cancela deslize lateral (menos aderência ao esterçar forte = "drift" leve).
	  4. Direção: velocidade angular em torno da normal do chão, proporcional à velocidade.
	  5. Ar: auto-nivelamento suave. Capotou por 2s => desvira sozinho.
	  6. Boost pads (tag "BoostPad"): x1.6 velocidade máx. por 1.6s + empurrão.
	Stats vêm de ATRIBUTOS do modelo do carro (MaxSpeed, Accel, Turn, Grip), definidos pelo CarService.
	Entrada: VehicleSeat.ThrottleFloat/SteerFloat (teclado, analógico e toque já suportados pelo Roblox).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local CarFactory = require(Shared.CarFactory)
local State = require(script.Parent.State)

local lp = Players.LocalPlayer
local Drive = {}

-- Beta 1.4d: o carro SÓ aceita comandos durante a corrida (RaceState = "Racing", depois do GO).
-- No lobby e na contagem 3-2-1 o acelerador/volante do VehicleSeat são ignorados e o carro freia sozinho.
-- (Defesa em camadas: o servidor também recusa DriveCar no lobby e tira do banco quem sentar fora da corrida.)
local function raceAllowsInput()
	return (lp:GetAttribute("RaceState") or "Lobby") == "Racing"
end
Drive.CanControl = raceAllowsInput

local car, chassis, seat
local yawCur, flipTimer, boostTime, lastFind = 0, 0, 0, 0
local speed, maxSpeedNow, driving, wasBoost, warned = 0, 70, false, false, false
local pads, ices = {}, {}
-- Beta 1.6: pads de LENTIDÃO (tag "SlowPad"): velocidade máxima x SpeedMult por Duration s (Config.Track.SlowPad)
local slows, slowTime = {}, 0
local TrackCfg = require(Shared:WaitForChild("Config")).Track or {}
local SLOW = TrackCfg.SlowPad or { SpeedMult = 0.45, Duration = 1.4 }
-- Beta 1.8: batida em OBSTÁCULO (Client.HazardController chama Drive.Hit): freia + empurrão
local HZ = TrackCfg.Hazards or { SpeedMult = 0.4, Duration = 1.3, Knock = 42 }
local hitTime, pendingKnock = 0, nil
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function refreshFilter()
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	local dr = map and map:FindFirstChild("Drivable")
	if dr then table.insert(list, dr) end
	rayParams.FilterDescendantsInstances = list
end

local function findCar()
	local folder = workspace:FindFirstChild("Cars")
	if not folder then return end
	for _, m in ipairs(folder:GetChildren()) do
		if m:GetAttribute("OwnerUserId") == lp.UserId then
			local ch, st = m:FindFirstChild("Chassis"), m:FindFirstChild("Seat")
			if ch and st then
				car, chassis, seat = m, ch, st
				yawCur, flipTimer = 0, 0
				refreshFilter()
				return
			end
		end
	end
end

local function step(dt)
	dt = math.min(dt, 1 / 30)
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	driving = hum ~= nil and hum.SeatPart == seat

	local cf = chassis.CFrame
	local mass = chassis.AssemblyMass
	local vel = chassis.AssemblyLinearVelocity
	local g = workspace.Gravity
	local up = cf.UpVector
	local pos = cf.Position

	-- Beta 1.8: empurrão da batida (corta a velocidade e joga para o lado/trás, com um pulinho)
	if pendingKnock then
		chassis.AssemblyLinearVelocity = vel * 0.3 + pendingKnock * HZ.Knock + Vector3.new(0, 16, 0)
		chassis.AssemblyAngularVelocity = Vector3.new(0, (math.random() - 0.5) * 6, 0)
		pendingKnock = nil
		vel = chassis.AssemblyLinearVelocity
	end
	if hitTime > 0 then hitTime -= dt end

	local maxSpeed = car:GetAttribute("MaxSpeed") or 60
	local accel = car:GetAttribute("Accel") or 50
	local turn = car:GetAttribute("Turn") or 2
	local gripBase = car:GetAttribute("Grip") or 7

	local throttle, steer = 0, 0
	local locked = not raceAllowsInput()
	if driving and not State.Encounter and not locked then throttle, steer = seat.ThrottleFloat, seat.SteerFloat end

	-- Boost pads
	for pad in pairs(pads) do
		if pad.Parent then
			local rel = pad.CFrame:PointToObjectSpace(pos)
			local hs = pad.Size * 0.5
			if math.abs(rel.X) < hs.X and math.abs(rel.Z) < hs.Z and math.abs(rel.Y) < 10 then boostTime = 1.6 end
		end
	end
	if boostTime > 0 then boostTime -= dt end
	local boosting = boostTime > 0
	for pad in pairs(slows) do
		if pad.Parent then
			local rel = pad.CFrame:PointToObjectSpace(pos)
			local hs = pad.Size * 0.5
			if math.abs(rel.X) < hs.X and math.abs(rel.Z) < hs.Z and math.abs(rel.Y) < 10 then slowTime = SLOW.Duration; boostTime = 0; boosting = false end
		end
	end
	if slowTime > 0 then slowTime -= dt end
	local slowed = slowTime > 0
	if boosting and not wasBoost then chassis:ApplyImpulse(cf.LookVector * mass * 35) end
	wasBoost = boosting
	-- Zonas de gelo (tag "IceZone"): pouca aderência e pouca tração
	local onIce = false
	for zone in pairs(ices) do
		if zone.Parent then
			local rel = zone.CFrame:PointToObjectSpace(pos)
			local hs = zone.Size * 0.5
			if math.abs(rel.X) < hs.X and math.abs(rel.Z) < hs.Z and math.abs(rel.Y) < 10 then onIce = true; break end
		end
	end
	if hitTime > 0 then boostTime = 0; boosting = false end
	local cap = maxSpeed * (boosting and 1.6 or 1) * (slowed and SLOW.SpeedMult or 1) * (hitTime > 0 and HZ.SpeedMult or 1)
	local acc = accel * (boosting and 2.2 or 1)
	if onIce then gripBase *= 0.18; acc *= 0.6 end
	maxSpeedNow = cap

	-- Suspensão por raycast (4 rodas)
	local kPer = mass * g / 4                      -- mola: carga estática por roda / 1 stud de compressão
	local cPer = 0.8 * math.sqrt(kPer * mass / 4)  -- amortecimento (zeta ~0.4)
	local rayLen = CarFactory.RayLength + math.clamp(vel.Magnitude / 250, 0, 4) -- alcance maior em alta velocidade
	local grounded, nSum = 0, Vector3.zero
	for _, key in ipairs(CarFactory.WheelList) do
		local origin = cf:PointToWorldSpace(CarFactory.WheelPoints[key])
		local hit = workspace:Raycast(origin, -up * rayLen, rayParams)
		if hit then
			grounded += 1
			nSum += hit.Normal
			local compress = CarFactory.Rest - hit.Distance
			if compress > 0 then
				local vn = chassis:GetVelocityAtPosition(origin):Dot(hit.Normal)
				local force = math.clamp(kPer * compress - cPer * vn, 0, kPer * 3)
				chassis:ApplyImpulseAtPosition(hit.Normal * force * dt, origin)
			end
		end
	end

	if grounded > 0 then
		local n = nSum.Unit
		local traction = grounded / 4
		local look = cf.LookVector
		local fwd = look - n * look:Dot(n)
		fwd = fwd.Magnitude > 1e-3 and fwd.Unit or look
		local right = fwd:Cross(n)
		local vF, vR = vel:Dot(fwd), vel:Dot(right)

		-- Tração / freio
		local target = throttle * cap * (throttle < 0 and 0.45 or 1)
		local a
		if State.Encounter or locked then
			a = math.clamp(-vF * 5, -acc * 2.5, acc * 2.5)
		elseif throttle == 0 then
			local decel = ((not driving) or math.abs(vF) < 5) and 160 or 28
			a = -math.sign(vF) * math.min(math.abs(vF) / dt, decel)
		else
			a = math.clamp((target - vF) * 4, -acc * 1.6, acc)
		end
		chassis:ApplyImpulse(fwd * a * mass * dt * traction)

		-- Aderência lateral (menos ao esterçar forte em alta velocidade)
		local steerLoad = math.clamp(math.abs(steer) * math.abs(vF) / math.max(cap, 1), 0, 1)
		local grip = driving and gripBase * (1 - 0.45 * steerLoad) or 20
		chassis:ApplyImpulse(-right * vR * mass * math.min(1, grip * dt) * traction)

		-- Downforce (cola no chão em lombadas)
		chassis:ApplyImpulse(-n * mass * 40 * dt * math.clamp(vel.Magnitude / math.max(cap, 1), 0, 1.5))

		-- Direção
		local sf = math.clamp(math.abs(vF) / 20, 0, 1) * (1 - 0.4 * math.clamp(math.abs(vF) / math.max(cap, 1), 0, 1))
		local dir = vF >= 0 and 1 or -1
		local yawTarget = -steer * turn * sf * dir
		yawCur += (yawTarget - yawCur) * (1 - math.exp(-10 * dt))
		local av = chassis.AssemblyAngularVelocity
		local rest = (av - n * av:Dot(n)) * math.max(0, 1 - 5 * dt)
		chassis.AssemblyAngularVelocity = rest + n * yawCur
	else
		-- No ar: nivelamento suave
		local axis = up:Cross(Vector3.yAxis)
		local av = chassis.AssemblyAngularVelocity
		chassis.AssemblyAngularVelocity = av * math.max(0, 1 - 1.2 * dt) + axis * 4 * dt
		yawCur *= (1 - math.min(1, 4 * dt))
	end

	-- Limite de velocidade
	local vmag = vel.Magnitude
	if vmag > cap * 1.35 then
		chassis:ApplyImpulse(-vel.Unit * mass * (vmag - cap * 1.35) * math.min(1, 3 * dt))
	end
	speed = vmag

	-- Desvirar sozinho
	if up.Y < 0.25 and vmag < 25 then flipTimer += dt else flipTimer = 0 end
	if flipTimer > 2 then
		flipTimer = 0
		local _, yaw = cf:ToEulerAnglesYXZ()
		car:PivotTo(CFrame.new(pos + Vector3.new(0, 6, 0)) * CFrame.Angles(0, yaw, 0))
		chassis.AssemblyLinearVelocity = Vector3.zero
		chassis.AssemblyAngularVelocity = Vector3.zero
	end
end

function Drive.GetSpeed() return speed end
function Drive.GetMaxSpeed() return maxSpeedNow end
function Drive.IsDriving() return driving end
function Drive.IsBoosting() return boostTime > 0 end
function Drive.IsSlowed() return slowTime > 0 or hitTime > 0 end
function Drive.IsHit() return hitTime > 0 end
-- Beta 1.8: chamado pelo Client.HazardController. dir = direção (horizontal) do empurrão. true = aplicou.
function Drive.Hit(dir)
	if hitTime > HZ.Duration - 0.35 or not (chassis and chassis.Parent) or not driving then return false end
	hitTime = HZ.Duration
	boostTime = 0
	pendingKnock = (dir and dir.Magnitude > 0.01) and dir.Unit or Vector3.zero
	return true
end
function Drive.GetChassis() return chassis end
function Drive.GetPosition()
	if chassis and chassis.Parent then return chassis.Position end
	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function noJump(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	-- Beta 1.1: o jogador anda a pé, então pular é liberado FORA do carro. Dentro dele continua desligado
	-- (o botão de pulo do mobile / Espaço faria o jogador sair do carro sem querer — para sair use EXIT).
	local function apply() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, hum.SeatPart == nil) end
	hum:GetPropertyChangedSignal("SeatPart"):Connect(apply)
	apply()
end

function Drive.Init()
	lp.CharacterAdded:Connect(noJump)
	if lp.Character then task.spawn(noJump, lp.Character) end
	CollectionService:GetInstanceAddedSignal("BoostPad"):Connect(function(p) pads[p] = true end)
	CollectionService:GetInstanceRemovedSignal("BoostPad"):Connect(function(p) pads[p] = nil end)
	for _, p in ipairs(CollectionService:GetTagged("BoostPad")) do pads[p] = true end
	CollectionService:GetInstanceAddedSignal("IceZone"):Connect(function(p) ices[p] = true end)
	CollectionService:GetInstanceRemovedSignal("IceZone"):Connect(function(p) ices[p] = nil end)
	for _, p in ipairs(CollectionService:GetTagged("IceZone")) do ices[p] = true end
	CollectionService:GetInstanceAddedSignal("SlowPad"):Connect(function(p) slows[p] = true end)
	CollectionService:GetInstanceRemovedSignal("SlowPad"):Connect(function(p) slows[p] = nil end)
	for _, p in ipairs(CollectionService:GetTagged("SlowPad")) do slows[p] = true end

	RunService.PreSimulation:Connect(function(dt)
		if not (car and car.Parent and chassis and chassis.Parent and seat and seat.Parent) then
			car, chassis, seat = nil, nil, nil
			driving, speed = false, 0
			if os.clock() - lastFind > 0.5 then lastFind = os.clock(); findCar() end
			return
		end
		local ok, err = pcall(step, dt)
		if not ok and not warned then warned = true; warn("[DriveController] " .. tostring(err)) end
	end)

	-- FOV dinâmico: sensação de velocidade
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam then return end
		local target = 70
		if driving and lp:GetAttribute("Set_FOV") ~= false then -- menu CONFIGS: "Speed Camera Effect"
			local r = math.clamp(speed / math.max(maxSpeedNow, 1), 0, 1.4)
			target = 70 + 22 * r ^ 1.5 + (boostTime > 0 and 10 or 0)
		end
		cam.FieldOfView += (target - cam.FieldOfView) * math.min(1, dt * 5)
	end)
end

return Drive
