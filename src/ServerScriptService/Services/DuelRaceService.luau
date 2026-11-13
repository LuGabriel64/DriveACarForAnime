--[[
	DuelRaceService  (ServerScriptService.Services.DuelRaceService)                              Beta 1.9
	=====================================================================================================
	CORRIDA 1v1 — o modo "Race" do VersusService.

	Usa a MESMA pista do jogo (nada de copiar o mapa) com o atributo RaceMode = "Duel", que desliga o que não
	deve existir: ovo gigante (Client.BiomeEggs esconde, EscapeService recusa) e bloqueio de tier (ZoneService).
	Cada jogador corre no carro de F1 que escolheu (Config.F1Cars; loja no VersusService).

	O COLAPSO DESDE A LARGADA (igual ao da fuga do ovo, ao contrário e mais lento)
	    nasce CollapseStartGap studs ATRÁS do grid e anda na direção da corrida (-Z);
	    começa CollapseDelay segundos depois do GO;
	    velocidade = MaxSpeed do carro MAIS LENTO da partida x CollapseFactor (mínimo CollapseMin).
	    frenteZ(t) = CollapseZ0 - CollapseSpeed x max(0, t - CollapseStart)      (t = workspace:GetServerTimeNow())
	O servidor publica CollapseDir (-1), CollapseZ0, CollapseStart e CollapseSpeed nos dois jogadores; o cliente
	(Client.DuelRaceUI) desenha a destruição. A pista NÃO é destruída de verdade: quem decide é a regra abaixo.

	QUEM VENCE (tudo decidido aqui)
	    cruzou a chegada primeiro ............ "Finished first"
	    o outro foi pego pelo colapso ........ "Caught by the collapse"
	    os dois pegos no mesmo instante ...... quem foi mais longe ("Went the farthest"); empate = sem vencedor
	    passou de MaxSeconds ................. quem foi mais longe
	    o outro saiu / apertou Home / morreu . "Forfeit"   | velocidade impossível (anti-trapaça) = "Disqualified"

	ANTI-TRAPAÇA: o do RaceService (Config.AntiCheat), com TopSpeed = velocidade do F1. A distância usada é a do
	servidor (atributo RaceDistance).

	DEPENDÊNCIAS: VersusService (RegisterMode / Finish / EquippedF1), RaceService (Start com opts / End / OnEnded),
	              CarService, Config.Versus.Race.
	NÃO TESTADO com 2 jogadores reais (o MCP só abre Play de 1 jogador).
]]
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local VersusService = require(script.Parent.VersusService)
local RaceService = require(script.Parent.RaceService)
local CarService = require(script.Parent.CarService)

local DuelRaceService = {}
local RC = Config.Versus.Race
local duels = {}   -- [match] = { Match, Dist = {[player]=studs}, Done, GoAt, Z0, Start, Speed }
local duelOf = {}  -- [player] = o mesmo estado

local ATTRS = { "CollapseDir", "CollapseZ0", "CollapseStart", "CollapseSpeed" }
local function setCollapse(player, st)
	if not player.Parent then return end
	if st then
		player:SetAttribute("CollapseZ0", st.Z0)
		player:SetAttribute("CollapseStart", st.Start)
		player:SetAttribute("CollapseSpeed", st.Speed)
		player:SetAttribute("CollapseDir", -1) -- por último: o cliente lê os outros quando este muda
	else
		for _, a in ipairs(ATTRS) do player:SetAttribute(a, nil) end
	end
end

-- Vaga no grid: primeira fileira, deslocada colX studs do centro da pista.
local function gridCF(colX)
	local base = RaceService.GridCFrame(1) -- fileira 1, coluna 1 (x = centro + GridColsX[1])
	return base + Vector3.new(colX - Config.Race.GridColsX[1], 0, 0)
end

local function cleanup(st)
	duels[st.Match] = nil
	for _, p in ipairs(st.Match.Players) do
		if duelOf[p] == st then duelOf[p] = nil end
		setCollapse(p, nil)
	end
end

-- Encerra as corridas que ainda estão rodando e guarda a distância de cada um.
local function endRaces(st)
	for _, p in ipairs(st.Match.Players) do
		if p.Parent and RaceService.IsRacing(p) then
			local d = RaceService.End(p, "duel")
			st.Dist[p] = st.Dist[p] or d or 0
		end
	end
end

local function decide(st, winner, reason)
	if st.Done then return end
	st.Done = true
	endRaces(st)
	local details = { Distances = {} }
	for _, p in ipairs(st.Match.Players) do details.Distances[tostring(p.UserId)] = math.floor(st.Dist[p] or 0) end
	cleanup(st)
	VersusService.Finish(st.Match, winner, { Reason = reason, Details = details })
end

-- Quem está mais longe agora (nil = empate exato).
local function farthest(st)
	local a, b = st.Match.Players[1], st.Match.Players[2]
	local da = st.Dist[a] or a:GetAttribute("RaceDistance") or 0
	local db = st.Dist[b] or b:GetAttribute("RaceDistance") or 0
	if da == db then return nil end
	return da > db and a or b
end

local function start(match)
	local st = { Match = match, Dist = {}, Done = false }
	local slowest = math.huge
	local cars = {}
	for _, p in ipairs(match.Players) do
		cars[p] = VersusService.EquippedF1(p)
		slowest = math.min(slowest, cars[p].MaxSpeed)
	end
	local now = workspace:GetServerTimeNow()
	-- +1 s: o RaceService leva um instante para carregar a pista, criar o F1 e sentar o jogador antes da contagem
	st.GoAt = now + Config.Race.Countdown + 1
	st.Z0 = Config.Race.GridRowsZ[1] + RC.CollapseStartGap
	st.Start = st.GoAt + RC.CollapseDelay
	st.Speed = math.max(RC.CollapseMin, slowest * RC.CollapseFactor)
	duels[match] = st
	for i, p in ipairs(match.Players) do
		duelOf[p] = st
		setCollapse(p, st)
		task.spawn(function()
			local r = RaceService.Start(p, { Mode = "Duel", GridCFrame = gridCF(RC.GridColsX[i] or 0), Car = cars[p],
				FinishZ = match.Map and match.Map.FinishZ or nil })
			if not (r and r.ok) then
				warn(("[DuelRaceService] %s não conseguiu largar (%s)"):format(p.Name, tostring(r and r.err)))
				decide(st, VersusService.Opponent(match, p), "Forfeit")
			end
		end)
	end
	print(("[DuelRaceService] partida %d: %s x %s | colapso a %.0f studs/s"):format(match.Id, match.Players[1].Name, match.Players[2].Name, st.Speed))
end

-- Alguém saiu no meio: só limpa (o VersusService chama o Finish dando a vitória a quem ficou).
local function abort(match)
	local st = duels[match]
	if not st or st.Done then return end
	st.Done = true
	cleanup(st)
	task.spawn(endRaces, st)
end

local function step()
	local t = workspace:GetServerTimeNow()
	for _, st in pairs(duels) do
		if not st.Done and t >= st.GoAt then
			local front = st.Z0 - st.Speed * math.max(0, t - st.Start)
			local caught = {}
			if t > st.Start then
				for _, p in ipairs(st.Match.Players) do
					if p.Parent and RaceService.IsRacing(p) then
						local pos = CarService.GetPosition(p)
						if pos and pos.Z >= front then caught[#caught + 1] = p end
					end
				end
			end
			if #caught >= 2 then
				task.spawn(decide, st, farthest(st), "Went the farthest")
			elseif #caught == 1 then
				task.spawn(RaceService.End, caught[1], "caught") -- o OnEnded abaixo dá a vitória ao outro
			elseif t - st.GoAt > RC.MaxSeconds then
				task.spawn(decide, st, farthest(st), "Went the farthest")
			end
		end
	end
end

function DuelRaceService.Init()
	VersusService.RegisterMode("Race", {
		Maps = function() return RC.Maps end,
		CanJoin = function() return true end,
		Start = start,
		Abort = abort,
		-- XpTarget ausente: o XP vai para o PARCEIRO (ProgressService.PartnerUid)
	})

	-- Fim da corrida de um dos dois (chegou, foi pego, anti-trapaça, Home, morreu...)
	RaceService.OnEnded(function(player, reason, distance, mode)
		local st = duelOf[player]
		if mode ~= "Duel" or not st then return end
		st.Dist[player] = distance
		if st.Done then return end
		local other = VersusService.Opponent(st.Match, player)
		if reason == "finish" then
			decide(st, player, "Finished first")
		elseif reason == "caught" then
			decide(st, other, "Caught by the collapse")
		elseif reason == "invalid" then
			decide(st, other, "Disqualified")
		else
			decide(st, other, "Forfeit")
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(step)
			if not ok then warn("[DuelRaceService] " .. tostring(err)) end
		end
	end)
end

return DuelRaceService
