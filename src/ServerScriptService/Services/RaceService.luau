--[[
	RaceService (Beta 1.2): LOBBY ⇄ PISTA. Cada corrida é única por jogador.

	MODELO "PISTA FANTASMA" (decisão de arquitetura — ver Bíblia 10d)
	  Existe UMA pista física. Cada jogador que inicia uma corrida recebe um SLOT (1..Config.Race.MaxSlots):
	    * o slot define a vaga no grid de largada (ninguém nasce em cima de ninguém);
	    * carros e personagens ficam em grupos de colisão que NÃO colidem entre si;
	    * no cliente, o GhostController esconde os outros jogadores enquanto alguém está correndo.
	  Resultado: cada um corre sozinho, sem tráfego, sem custo de memória extra (copiar o mundo 8x
	  criaria ~200 mil peças e passaria do limite saudável de um place do Roblox).

	ESTADOS DO JOGADOR (atributo "RaceState"):  "Lobby" -> "Countdown" -> "Racing" -> "Lobby"
	  RaceSlot (número), RaceDistance (studs percorridos), RaceBest (recorde).

	FLUXO
	  StartRace : valida (garagem escolhida, vivo, no lobby) -> reserva slot -> carrega a área (streaming)
	              -> leva o carro ao grid -> senta o jogador -> carro ANCORADO durante a contagem -> GO.
	  EndRace   : tira do carro -> estaciona o carro na garagem -> leva o jogador ao lobby -> libera o slot
	              -> envia o resumo (distância, tempo, ovos chocados, recorde).
	  Termina sozinho ao: chegar ao fim do mundo, morrer/renascer, sair do jogo.

	REDE: StartRace, EndRace, GoHome (cliente->servidor) | RaceCountdown, RaceGo, RaceEnded (servidor->cliente)

	Beta 1.8d (auditoria 11/11, item 4): o recorde (MinZ) vem da posição do carro, que é do CLIENTE. Agora o avanço
	  passa pelo mesmo orçamento de velocidade da fuga (Config.AntiCheat). Velocidade impossível => corrida encerrada
	  com Reason "invalid", sem contar a distância do salto (MinZ fica onde estava). Necessário antes de um ranking.
]]
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local CarService = require(script.Parent.CarService)
local ZoneService = require(script.Parent.ZoneService)

local RaceService = {}
local RC, W = Config.Race, Config.World
local slots = {}  -- [slot] = player
local races = {}  -- [player] = { Slot, Token, StartedAt, MinZ, StartHatches }

-- ---------------------------------------------------------------- utilidades
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function groundY(x, z)
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map and map:FindFirstChild("Drivable") then table.insert(list, map.Drivable) end
	groundParams.FilterDescendantsInstances = list
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), groundParams)
	return hit and hit.Position.Y or 0
end

-- Vaga do grid de largada para um slot (fileiras atrás do pórtico, olhando para -Z)
function RaceService.GridCFrame(slot)
	local cols = RC.GridColsX
	local row = math.floor((slot - 1) / #cols) + 1
	local col = (slot - 1) % #cols + 1
	local z = RC.GridRowsZ[math.min(row, #RC.GridRowsZ)] + math.max(0, row - #RC.GridRowsZ) * 26
	local x = W.RoadX(z) + cols[col]
	local p = Vector3.new(x, groundY(x, z) + 4.5, z)
	return CFrame.lookAt(p, p + Vector3.new(0, 0, -1))
end

local function freeSlot()
	for i = 1, RC.MaxSlots do if not slots[i] then return i end end
end
local function finishZ() return RC.FinishZ or (-W.TotalLength + 120) end

-- Beta 1.8d: orçamento de avanço (igual ao EscapeService). false = andou mais rápido do que o carro consegue.
local AC = Config.AntiCheat
local function forwardOk(player, r, advance, dt)
	local rate = (player:GetAttribute("TopSpeed") or AC.FallbackTopSpeed) * AC.ForwardSpeedMult
	local cap = rate * AC.BurstSeconds + AC.Slack
	r.Budget = math.min(cap, (r.Budget or cap) + rate * dt)
	if advance > 0 then r.Budget -= advance end
	return r.Budget >= 0
end

local function stream(player, pos)
	pcall(function() player:RequestStreamAroundAsync(pos, 6) end)
end

local function setState(player, state, slot)
	player:SetAttribute("RaceState", state)
	player:SetAttribute("RaceSlot", slot or 0)
end

-- ---------------------------------------------------------------- iniciar
function RaceService.Start(player)
	if races[player] then return { ok = false, err = "AlreadyRacing" } end
	if not FarmService.GetPlot(player) then return { ok = false, err = "NoGarage" } end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return { ok = false, err = "Dead" } end
	local slot = freeSlot()
	if not slot then return { ok = false, err = "Full" } end

	local token = {}
	slots[slot] = player
	local data = DataService.Get(player)
	races[player] = { Slot = slot, Token = token, StartedAt = 0, MinZ = RC.StartLineZ,
		StartHatches = data and data.Stats.Hatches or 0 }
	setState(player, "Countdown", slot)

	local cf = RaceService.GridCFrame(slot)
	stream(player, cf.Position)
	-- carro no grid (cria se ainda não existir) e jogador sentado
	if CarService.GetCar(player) then CarService.Teleport(player, cf) else CarService.Spawn(player, cf, false) end
	local car = CarService.GetCar(player)
	if car and car.PrimaryPart then car.PrimaryPart.Anchored = true end
	CarService.SeatPlayer(player, car)
	ZoneService.ResetSafe(player, cf)

	local goAt = workspace:GetServerTimeNow() + RC.Countdown
	Net.Fire(player, "RaceCountdown", { Slot = slot, GoAt = goAt, Seconds = RC.Countdown })
	task.delay(RC.Countdown, function()
		local r = races[player]
		if not r or r.Token ~= token then return end -- corrida cancelada no meio da contagem
		local c = CarService.GetCar(player)
		if c and c.PrimaryPart then
			c.PrimaryPart.Anchored = false
			pcall(function() c.PrimaryPart:SetNetworkOwner(player) end)
		end
		r.StartedAt = os.clock()
		setState(player, "Racing", r.Slot)
		Net.Fire(player, "RaceGo")
	end)
	return { ok = true, Slot = slot }
end

-- ---------------------------------------------------------------- terminar
function RaceService.End(player, reason)
	local r = races[player]
	if not r then return nil end
	races[player] = nil
	if slots[r.Slot] == player then slots[r.Slot] = nil end

	local data = DataService.Get(player)
	local distance = math.max(0, math.floor(RC.StartLineZ - r.MinZ))
	local time = r.StartedAt > 0 and (os.clock() - r.StartedAt) or 0
	local hatched = data and math.max(0, (data.Stats.Hatches or 0) - r.StartHatches) or 0
	local best = data and (data.Stats.BestDistance or 0) or 0
	local newRecord = distance > best
	if data and newRecord then data.Stats.BestDistance = distance end
	local reward = math.floor(distance / 100) * (RC.CashPer100Studs or 0)
	if reward > 0 then DataService.AddCash(player, reward) end
	player:SetAttribute("RaceBest", math.max(best, distance))

	if player.Parent then
		-- desce do carro, estaciona na garagem e leva o jogador ao lobby
		local car = CarService.GetCar(player)
		if car and car.PrimaryPart then car.PrimaryPart.Anchored = false end
		if CarService.IsDriving(player) then CarService.ExitPlayer(player) end
		local garageCF = FarmService.GetCarSpawn(player)
		if garageCF then stream(player, garageCF.Position) end
		if car and garageCF then task.spawn(CarService.Teleport, player, garageCF) end
		local spawnCF = FarmService.GetPlayerSpawn(player)
		local char = player.Character
		if char and spawnCF then
			char:PivotTo(spawnCF)
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then root.AssemblyLinearVelocity = Vector3.zero end
		end
		ZoneService.ResetSafe(player, spawnCF)
		setState(player, "Lobby", 0)
		player:SetAttribute("RaceDistance", 0)
		Net.Fire(player, "RaceEnded", { Reason = reason or "home", Distance = distance, Time = time, Hatched = hatched,
			Best = math.max(best, distance), NewRecord = newRecord, Reward = reward })
	end
	return distance
end

function RaceService.IsRacing(player) return races[player] ~= nil end

-- ---------------------------------------------------------------- colisões (ninguém colide com ninguém)
local function setupCollisions()
	pcall(function() PhysicsService:RegisterCollisionGroup("Characters") end)
	pcall(function() PhysicsService:RegisterCollisionGroup("Cars") end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable("Characters", "Characters", false) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable("Characters", "Cars", false) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable("Cars", "Cars", false) end)
end
local function tagCharacter(char)
	local function set(p) if p:IsA("BasePart") then p.CollisionGroup = "Characters" end end
	for _, p in ipairs(char:GetDescendants()) do set(p) end
	char.DescendantAdded:Connect(set)
end

-- ---------------------------------------------------------------- init
function RaceService.Init()
	setupCollisions()

	DataService.OnLoaded(function(player, data)
		data.Stats.BestDistance = data.Stats.BestDistance or 0
		player:SetAttribute("RaceBest", data.Stats.BestDistance)
		setState(player, "Lobby", 0)
		if player.Character then tagCharacter(player.Character) end
		player.CharacterAdded:Connect(function(char)
			tagCharacter(char)
			-- morreu/renasceu durante a corrida: a corrida acaba (o FarmService já põe o corpo na garagem)
			if races[player] then task.defer(RaceService.End, player, "respawn") end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local r = races[player]
		if r then races[player] = nil; if slots[r.Slot] == player then slots[r.Slot] = nil end end
	end)

	Net.Handle("StartRace", function(player) return RaceService.Start(player) end, 2)
	Net.Handle("EndRace", function(player)
		local d = RaceService.End(player, "home")
		return { ok = d ~= nil }
	end, 2)
	-- Botão Home: correndo => volta ao lobby. No lobby => vai até a própria garagem.
	Net.Handle("GoHome", function(player)
		if races[player] then RaceService.End(player, "home"); return { ok = true } end
		if not FarmService.GetPlot(player) then return { ok = false, err = "NoGarage" } end
		if CarService.IsDriving(player) then
			task.spawn(CarService.Teleport, player, FarmService.GetCarSpawn(player))
		else
			local char, cf = player.Character, FarmService.GetPlayerSpawn(player)
			if char and cf then char:PivotTo(cf) end
		end
		return { ok = true }
	end, 2)

	-- progresso (distância) e chegada
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, r in pairs(races) do
				if r.StartedAt > 0 then
					local pos = CarService.GetPosition(player)
					local now = os.clock()
					local legit = true
					if pos and r.LastZ then
						-- corrida vai para -Z: avanço = quanto o carro andou para frente desde o último tick
						legit = forwardOk(player, r, r.LastZ - pos.Z, math.max(now - r.LastT, 1 / 60))
					end
					if pos and not legit then
						warn(("[RaceService] %s: avanço impossível (%.0f studs, TopSpeed %s) => corrida encerrada sem o salto"):format(
							player.Name, r.LastZ - pos.Z, tostring(player:GetAttribute("TopSpeed"))))
						task.spawn(RaceService.End, player, "invalid")
					elseif pos then
						r.LastZ, r.LastT = pos.Z, now
						if pos.Z < r.MinZ then r.MinZ = pos.Z end
						player:SetAttribute("RaceDistance", math.max(0, math.floor(RC.StartLineZ - r.MinZ)))
						if pos.Z <= finishZ() then task.spawn(RaceService.End, player, "finish") end
					end
				end
			end
		end
	end)
end

return RaceService
