--[[
	CarService (Beta 1.1): o carro de cada jogador.
	FLUXO NOVO
	  * O carro NÃO nasce com o personagem. Quando o jogador escolhe a garagem (FarmService.ClaimGarage),
	    o carro aparece ESTACIONADO dentro dela (sem motorista). Ele entra pelo prompt "Drive" do banco.
	  * Botão DRIVE (ação "DriveCar"): traz o carro para o lado do jogador e o senta. Na garagem, usa a vaga.
	  * Botão EXIT  (ação "ExitCar"): o jogador desce; o carro fica parado onde está.
	  * "GoHome": dirigindo => leva o carro à garagem; a pé => leva o jogador à garagem.
	A FÍSICA roda no cliente dono do carro (DriveController); aqui só ficam dono de rede e atributos.

	Beta 1.9 (corrida 1v1):
	  * Spawn(player, cf, seat, cfgOverride): cfgOverride = um carro de Config.F1Cars. O modelo nasce com o atributo
	    F1 = true e com os status do F1 (sem motor/upgrade). Sem override, tudo como antes.
	  * Durante um desafio (atributo MatchId ~= 0) não dá para comprar, trocar ou melhorar carro: isso recriaria o
	    modelo no meio da partida.
]]
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Locale = require(Shared.Locale) -- Beta 1.9: avisos no idioma do jogador
local CarFactory = require(Shared.CarFactory)
local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)

local CarService = {}
local cars = {}

-- Beta 1.4: lobby SÓ A PÉ (Config.Lobby.WalkOnly). Carros no lobby ficam estacionados/expostos: nada de
-- carro atropelando a praça, entalando em decoração ou empurrando gente. PLAY leva direto ao grid.
local function lobbyWalkOnly(player)
	return Config.Lobby.WalkOnly and (player:GetAttribute("RaceState") or "Lobby") == "Lobby"
end
CarService.LobbyWalkOnly = lobbyWalkOnly
local carsFolder = workspace:WaitForChild("Cars")

-- ---------------------------------------------------------------- stats
local function statsFor(data)
	local cfg = Config.CarById[data.CarId] or Config.Cars[1]
	local entry = data.Cars[cfg.Id]
	local lvl = entry and entry.Engine or 0
	local m = Config.SpeedMult(lvl)
	return cfg, { MaxSpeed = math.min(cfg.MaxSpeed * m, Config.SpeedCap), Accel = cfg.Accel * (1 + (m - 1) * 0.6), Turn = cfg.Turn, Grip = cfg.Grip }, lvl
end
local function bestTier(data)
	local t = 1
	for id in pairs(data.Cars) do
		local c = Config.CarById[id]
		if c and c.Tier > t then t = c.Tier end
	end
	return t
end
local function applyStats(model, stats) for k, v in pairs(stats) do model:SetAttribute(k, v) end end

-- ---------------------------------------------------------------- consultas (usadas por Zone/Egg)
function CarService.GetCar(player) return cars[player] end
function CarService.IsDriving(player)
	local m = cars[player]
	local seat = m and m:FindFirstChild("Seat")
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return seat ~= nil and hum ~= nil and hum.SeatPart == seat
end
-- Posição "do jogador" no mundo: o carro se estiver dirigindo, senão o corpo.
function CarService.GetPosition(player)
	if CarService.IsDriving(player) then return cars[player].PrimaryPart.Position end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end
function CarService.GetTier(player)
	local data = DataService.Get(player)
	if not data then return 1 end
	return (statsFor(data)).Tier
end

function CarService.RefreshAttributes(player)
	local data = DataService.Get(player); if not data then return end
	local cfg, stats, lvl = statsFor(data)
	player:SetAttribute("CarId", cfg.Id)
	player:SetAttribute("CarTier", cfg.Tier)
	player:SetAttribute("TopSpeed", math.floor(stats.MaxSpeed))
	player:SetAttribute("EngineLevel", lvl)
	local m = cars[player]
	if m and not m:GetAttribute("F1") then applyStats(m, stats) end -- Beta 1.9: o F1 guarda os próprios status
end

function CarService.SendState(player)
	local data = DataService.Get(player); if not data then return end
	local owned = {}
	for id, c in pairs(data.Cars) do owned[id] = c.Engine end
	local carCfg, _, lvl = statsFor(data)
	local maxed = lvl >= Config.Engine.MaxLevel
	Net.Fire(player, "CarState", {
		Equipped = data.CarId, Owned = owned, EngineLevel = lvl,
		EngineCost = (not maxed) and Config.EngineCost(lvl, carCfg.Tier) or nil, EngineMax = maxed,
	})
end

-- ---------------------------------------------------------------- sentar / descer
local function seatPlayer(player, model)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = model and model:FindFirstChild("Seat")
	if not (hum and seat) or hum.Health <= 0 then return false end
	if seat:IsA("VehicleSeat") then seat.Disabled = false end -- corrida começando: libera o banco
	if hum.SeatPart == seat then return true end
	if char.PrimaryPart then char:PivotTo(seat.CFrame * CFrame.new(0, 2.5, 0)) end
	pcall(function() seat:Sit(hum) end)
	task.wait(0.25)
	return hum.SeatPart == seat
end

local function exitPlayer(player)
	local m = cars[player]
	local seat = m and m:FindFirstChild("Seat")
	local char = player.Character
	if not (seat and char) then return false end
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then weld:Destroy() end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Sit = false end
	-- desce pelo lado esquerdo do carro, em pé
	local side = seat.CFrame * CFrame.new(-7.5, 2, 0)
	local _, yaw = seat.CFrame:ToEulerAnglesYXZ()
	local cf = CFrame.new(side.Position) * CFrame.Angles(0, yaw, 0)
	char:PivotTo(cf)
	-- O corpo é simulado pelo CLIENTE: o PivotTo do servidor pode ser sobrescrito. Por isso o ponto de descida
	-- também volta na resposta e o cliente aplica (HUD -> botão EXIT).
	return true, cf
end

CarService.SeatPlayer = seatPlayer -- usados pelo RaceService
CarService.ExitPlayer = exitPlayer

-- ---------------------------------------------------------------- criar / remover
function CarService.Despawn(player)
	local m = cars[player]
	if m then m:Destroy() end
	cars[player] = nil
end

-- seat = true senta o jogador; false deixa o carro estacionado.
function CarService.Spawn(player, atCF, seat, cfgOverride)
	local data = DataService.Get(player); if not data then return end
	CarService.Despawn(player)
	local cfg, stats = statsFor(data)
	if cfgOverride then -- Beta 1.9: carro de Fórmula 1 da corrida 1v1 (status direto do Config.F1Cars)
		cfg = cfgOverride
		stats = { MaxSpeed = math.min(cfg.MaxSpeed, Config.SpeedCap), Accel = cfg.Accel, Turn = cfg.Turn, Grip = cfg.Grip }
	end
	local model = CarFactory.Build(cfg, false)
	if cfgOverride then model:SetAttribute("F1", true) end
	model.Name = "Car_" .. player.Name
	model:SetAttribute("OwnerUserId", player.UserId)
	applyStats(model, stats)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then pcall(function() p.CollisionGroup = "Cars" end) end
	end
	model:PivotTo(atCF or FarmService.GetCarSpawn(player) or CFrame.new(0, 6, 150))
	model.Parent = carsFolder
	pcall(function() model.PrimaryPart:SetNetworkOwner(player) end)
	cars[player] = model

	-- Prompt no banco: entrar no próprio carro (na garagem ou onde ele ficou estacionado)
	local seatPart = model:FindFirstChild("Seat")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"; prompt.ActionText = "Drive"; prompt.ObjectText = cfg.Name
	prompt.MaxActivationDistance = 16; prompt.RequiresLineOfSight = false; prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = seatPart
	-- Beta 1.6b: com alguém no banco o prompt some (não fica "Drive" flutuando em cima do carro)
	if seatPart and seatPart:IsA("VehicleSeat") then
		local function syncPrompt() prompt.Enabled = seatPart.Occupant == nil end
		seatPart:GetPropertyChangedSignal("Occupant"):Connect(syncPrompt)
		syncPrompt()
	end
	prompt.Triggered:Connect(function(plr)
		if plr ~= player then return end
		if lobbyWalkOnly(player) then
			Net.Fire(player, "Toast", "🚶 The lobby is walk-only — press ▶ PLAY to race!", "info")
			return
		end
		task.spawn(seatPlayer, player, model)
	end)

	if seat then task.spawn(seatPlayer, player, model) end
	return model
end

-- Teleporte seguro de um carro cujo dono de rede é o cliente
function CarService.Teleport(player, cf)
	local m = cars[player]; if not m or not m.PrimaryPart then return end
	local ch = m.PrimaryPart
	pcall(function() ch:SetNetworkOwner(nil) end)
	m:PivotTo(cf)
	ch.AssemblyLinearVelocity = Vector3.zero
	ch.AssemblyAngularVelocity = Vector3.zero
	task.wait(0.15)
	if m.Parent then pcall(function() ch:SetNetworkOwner(player) end) end
end

local function uprightHere(player)
	local m = cars[player]; if not m or not m.PrimaryPart then return nil end
	local cf = m.PrimaryPart.CFrame
	local _, yaw = cf:ToEulerAnglesYXZ()
	return CFrame.new(cf.Position + Vector3.new(0, 5, 0)) * CFrame.Angles(0, yaw, 0)
end

-- Troca de carro/upgrade: recria o carro no mesmo lugar, mantendo o jogador dentro se estava dirigindo.
local function refresh(player, respawn)
	CarService.RefreshAttributes(player)
	CarService.SendState(player)
	if respawn and FarmService.GetPlot(player) then
		local driving = CarService.IsDriving(player)
		CarService.Spawn(player, uprightHere(player), driving)
	end
end

-- Lugar seguro para trazer o carro até o jogador (DRIVE fora da garagem)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function spotBeside(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map and map:FindFirstChild("Drivable") then table.insert(list, map.Drivable) end
	groundParams.FilterDescendantsInstances = list
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local right = look:Cross(Vector3.yAxis)
	local p = root.Position + right * 9
	local hit = workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), groundParams)
	local y = hit and hit.Position.Y or root.Position.Y
	return CFrame.lookAt(Vector3.new(p.X, y + 5, p.Z), Vector3.new(p.X, y + 5, p.Z) + look)
end

-- ---------------------------------------------------------------- init
function CarService.Init()
	pcall(function() PhysicsService:RegisterCollisionGroup("Cars") end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable("Cars", "Cars", false) end)

	DataService.OnLoaded(function(player)
		CarService.RefreshAttributes(player)
		CarService.SendState(player)
	end)
	DataService.OnLeaving(function(player) CarService.Despawn(player) end)

	-- Beta 1.4d: GUARDA do lobby. Fora da corrida o VehicleSeat fica DESATIVADO (ninguém senta/dirige) e, se alguém
	-- estiver sentado no lobby (bug ou exploit), o servidor tira do banco. RaceService senta o jogador no grid.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, m in pairs(cars) do
				local seat = m.Parent and m:FindFirstChild("Seat")
				if seat and seat:IsA("VehicleSeat") then
					local lobby = lobbyWalkOnly(player)
					if seat.Disabled ~= lobby then seat.Disabled = lobby end
					if lobby and CarService.IsDriving(player) then
						exitPlayer(player)
						Net.Fire(player, "Toast", "🚶 The lobby is walk-only — press ▶ PLAY to race!", "info")
					end
				end
			end
		end
	end)
	-- garagem escolhida => carro estacionado dentro dela
	FarmService.OnGarageClaimed(function(player)
		CarService.Spawn(player, FarmService.GetCarSpawn(player), false)
	end)

	Net.Handle("DriveCar", function(player)
		if not FarmService.GetPlot(player) then return { ok = false, err = "NoGarage" } end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return { ok = false, err = "Dead" } end
		if CarService.IsDriving(player) then return { ok = true } end
		if lobbyWalkOnly(player) then return { ok = false, err = "LobbyWalk" } end
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		local garageCF = FarmService.GetCarSpawn(player)
		local cf
		if garageCF and root and (root.Position - garageCF.Position).Magnitude < 45 then
			cf = garageCF                     -- dentro/perto da garagem: usa a vaga do carro
		else
			cf = spotBeside(player) or garageCF
		end
		if cars[player] then
			CarService.Teleport(player, cf)
		else
			CarService.Spawn(player, cf, false)
		end
		local ok = seatPlayer(player, cars[player])
		return { ok = ok }
	end, 1)
	Net.Handle("ExitCar", function(player)
		if not CarService.IsDriving(player) then return { ok = true } end
		local ok, cf = exitPlayer(player)
		return { ok = ok, ExitCF = cf }
	end, 0.5)

	Net.Handle("BuyCar", function(player, carId)
		local data, cfg = DataService.Get(player), type(carId) == "string" and Config.CarById[carId]
		if not data or not cfg then return { ok = false, err = "Invalid" } end
		if player:GetAttribute("EscapeState") == "Escaping" then return { ok = false, err = "Escaping" } end -- Beta 1.3
		if (player:GetAttribute("MatchId") or 0) ~= 0 then return { ok = false, err = "InMatch" } end -- Beta 1.9
		if data.Cars[carId] then return { ok = false, err = "Owned" } end
		if cfg.Tier > bestTier(data) + 1 then return { ok = false, err = "Locked" } end
		if not DataService.TrySpend(player, cfg.Price) then return { ok = false, err = "NoCash" } end
		data.Cars[carId] = { Engine = 0 }
		data.CarId = carId
		refresh(player, true)
		return { ok = true }
	end, 0.4)
	Net.Handle("EquipCar", function(player, carId)
		local data = DataService.Get(player)
		if not data or type(carId) ~= "string" or not data.Cars[carId] then return { ok = false, err = "Invalid" } end
		-- Beta 1.3: trocar de carro recria o modelo => proibido no meio de uma fuga com o ovo
		if player:GetAttribute("EscapeState") == "Escaping" then return { ok = false, err = "Escaping" } end
		if (player:GetAttribute("MatchId") or 0) ~= 0 then return { ok = false, err = "InMatch" } end -- Beta 1.9
		if data.CarId == carId then return { ok = true } end
		data.CarId = carId
		refresh(player, true)
		return { ok = true }
	end, 0.4)
	Net.Handle("UpgradeEngine", function(player)
		local data = DataService.Get(player); if not data then return { ok = false } end
		local entry = data.Cars[data.CarId]
		if not entry then return { ok = false } end
		if (player:GetAttribute("MatchId") or 0) ~= 0 then return { ok = false, err = "InMatch" } end -- Beta 1.9
		if entry.Engine >= Config.Engine.MaxLevel then return { ok = false, err = "Max" } end
		if not DataService.TrySpend(player, Config.EngineCost(entry.Engine, (Config.CarById[data.CarId] or Config.Cars[1]).Tier)) then return { ok = false, err = "NoCash" } end
		entry.Engine += 1
		refresh(player, false)
		return { ok = true }
	end, 0.2)
	-- "GoHome" saiu daqui na Beta 1.2: agora é tratado pelo RaceService (termina a corrida e volta ao lobby).
	Net.Handle("ResetCar", function(player)
		local cf = uprightHere(player)
		if not cf then return { ok = false } end
		task.spawn(CarService.Teleport, player, cf)
		return { ok = true }
	end, 2)
end

return CarService
