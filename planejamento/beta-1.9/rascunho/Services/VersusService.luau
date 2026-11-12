--[[
	VersusService  (destino: ServerScriptService.Services.VersusService)              RASCUNHO — Beta 1.9
	=====================================================================================================
	DESAFIOS 1v1 entre dois jogadores do mesmo servidor: CORRIDA e BATALHA DE ANIME.
	Este serviço cuida do que é IGUAL nos dois modos; cada modo se registra com RegisterMode:
	    Services.DuelRaceService  -> modo "Race"   (pista do jogo, carros de F1, colapso desde a largada)
	    Services.BattleService    -> modo "Battle" (arena, simulação BattleSim, roteiro para os clientes)

	FLUXO DE UMA PARTIDA
	    convite (InviteSeconds)  -> o convidado vê um cartão ACCEPT / DECLINE
	    "Lobby"  (LobbySeconds)  -> os dois vão para o Versus Hall; acaba antes se os dois apertarem READY
	    "Vote"   (VoteSeconds)   -> votação do mapa/arena (empate = sorteio do servidor entre os votados)
	    "Prep"   (PrepSeconds)   -> 30 s para comprar/escolher carro, lutador e animação de vitória
	    "Playing"                -> o modo assume (handler.Start) e avisa o fim com VersusService.Finish
	    "Result" (ResultSeconds) -> recompensas na tela; depois cada um volta para a própria garagem

	SEGURANÇA (servidor decide tudo)
	  * Só convida/aceita quem está LIVRE: perfil carregado, garagem escolhida, no lobby, vivo, sem fuga
	    com ovo, sem convite pendente e sem partida.
	  * Todo dado do cliente é validado (tipo, lista branca de modos e mapas, dono do convite).
	  * Recompensas são calculadas aqui. Contra o MESMO adversário, depois de FullRewardsPerOpponent partidas
	    na sessão, só o XP é dado (evita dois jogadores trocando vitórias para farmar dinheiro e spins).

	REDE
	    cliente -> servidor : VersusPlayers | VersusInvite(userId, mode) | VersusRespond(inviteId, accept)
	                          VersusCancel | VersusReady | VersusVote(mapId) | VersusLeave
	    servidor -> cliente : VersusInvited(info) | VersusInviteClosed(info) | VersusState(snapshot)
	                          VersusResult(info)
	ATRIBUTOS do Player : MatchId (0 = nenhuma), VersusMode ("" | "Race" | "Battle"),
	                      VersusStage ("" | "Lobby" | "Vote" | "Prep" | "Playing" | "Result")

	API para os modos
	    VersusService.RegisterMode(name, handler)
	        handler.Maps()                 -> { { Id, Name, Icon, Desc }, ... }
	        handler.CanJoin(player)        -> true | false, "mensagem em inglês (chave do Locale)"
	        handler.Start(match)           -> começa o jogo (match.Players, match.Map)
	        handler.Abort(match, leaver)   -> limpa tudo se alguém sair no meio (opcional)
	        handler.XpTarget(match, player)-> Uid do personagem que ganha o XP (opcional; padrão = parceiro)
	    VersusService.Finish(match, winnerPlayer, info)   -- info.Reason é mostrado na tela de resultado
	    VersusService.GetMatch(player) / VersusService.Opponent(match, player)

	DEPENDÊNCIAS: DataService, FarmService, ZoneService, WheelService (AddPoints), ProgressService (AddXP),
	              Shared.Locale, Config.Versus.
]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Locale = require(Shared.Locale)
local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local ZoneService = require(script.Parent.ZoneService)
local WheelService = require(script.Parent.WheelService)
local ProgressService = require(script.Parent.ProgressService)

local VersusService = {}
local V = Config.Versus
local rng = Random.new()

local modes = {}       -- [nome] = handler
local invites = {}     -- [inviteId] = { Id, From, To, Mode, Token }
local inviteOf = {}    -- [player] = convite em que ele está (quem convidou OU quem foi convidado)
local matches = {}     -- [matchId] = match
local matchOf = {}     -- [player] = match
local lastInvite = {}  -- [player] = os.clock() do último convite enviado
local pairCount = {}   -- ["idMenor:idMaior"] = partidas com recompensa completa nesta sessão
local nextId = 0

local STAGE_SECONDS = { Lobby = V.LobbySeconds, Vote = V.VoteSeconds, Prep = V.PrepSeconds, Result = V.ResultSeconds }

-- ---------------------------------------------------------------- utilidades
local function toast(player, key, kind, ...)
	Net.Fire(player, "Toast", Locale.For(player, key, ...), kind or "info")
end

local function newId()
	nextId = nextId + 1
	return nextId
end

local function pairKey(a, b)
	local x, y = a.UserId, b.UserId
	if x > y then x, y = y, x end
	return x .. ":" .. y
end

-- O jogador pode entrar num desafio agora?
local function isFree(player)
	if not player or not player.Parent then return false end
	if not DataService.Get(player) or not FarmService.GetPlot(player) then return false end
	if (player:GetAttribute("RaceState") or "Lobby") ~= "Lobby" then return false end
	if player:GetAttribute("EscapeState") == "Escaping" then return false end
	if matchOf[player] or inviteOf[player] then return false end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

function VersusService.GetMatch(player) return matchOf[player] end
function VersusService.Opponent(match, player)
	return (match.Players[1] == player) and match.Players[2] or match.Players[1]
end
function VersusService.RegisterMode(name, handler) modes[name] = handler end

local function setAttrs(player, match)
	if not player.Parent then return end
	player:SetAttribute("MatchId", match and match.Id or 0)
	player:SetAttribute("VersusMode", match and match.Mode or "")
	player:SetAttribute("VersusStage", match and match.Stage or "")
end

-- O que cada cliente precisa para desenhar a tela da etapa atual.
local function snapshot(match)
	local list = {}
	for i, p in ipairs(match.Players) do
		list[i] = { UserId = p.UserId, Name = p.DisplayName, Ready = match.Ready[p] == true, Vote = match.Votes[p] }
	end
	return {
		MatchId = match.Id, Mode = match.Mode, Stage = match.Stage,
		EndsAt = match.EndsAt, Now = workspace:GetServerTimeNow(),
		Players = list, Maps = match.Maps, Map = match.Map,
	}
end

local function broadcast(match)
	local snap = snapshot(match)
	for _, p in ipairs(match.Players) do
		if p.Parent then
			setAttrs(p, match)
			Net.Fire(p, "VersusState", snap)
		end
	end
end

local function teleport(player, cf)
	local char = player.Character
	if not (char and cf) then return end
	pcall(function() player:RequestStreamAroundAsync(cf.Position, 5) end)
	if not char.Parent then return end
	char:PivotTo(cf)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
	ZoneService.ResetSafe(player, cf)
end

local function toHall(player, index)
	local offset = V.HallSpawns[index] or V.HallSpawns[1]
	teleport(player, CFrame.new(V.HallOrigin + offset))
end

-- ---------------------------------------------------------------- etapas
local setStage -- declarado antes porque as etapas se chamam em sequência

-- Troca de etapa e agenda o fim dela. O Token garante que um timer antigo não dispare depois de a etapa
-- já ter mudado (ex.: os dois apertaram READY antes do tempo).
local function runStage(match, stage, onEnd)
	match.Stage = stage
	match.Token = {}
	local seconds = STAGE_SECONDS[stage]
	match.EndsAt = seconds and (workspace:GetServerTimeNow() + seconds) or nil
	broadcast(match)
	if seconds and onEnd then
		local token = match.Token
		task.delay(seconds, function()
			if matches[match.Id] == match and match.Token == token then onEnd() end
		end)
	end
end

local function closeMatch(match)
	if matches[match.Id] ~= match then return end
	matches[match.Id] = nil
	match.Token = {}
	for _, p in ipairs(match.Players) do
		if matchOf[p] == match then matchOf[p] = nil end
		if p.Parent then
			setAttrs(p, nil)
			Net.Fire(p, "VersusState", nil)
			task.spawn(teleport, p, FarmService.GetPlayerSpawn(p))
		end
	end
end

local function pickMap(match)
	-- conta os votos; sem voto nenhum = qualquer mapa; empate = sorteio entre os mais votados
	local count, best, top = {}, {}, 0
	for _, p in ipairs(match.Players) do
		local v = match.Votes[p]
		if v then count[v] = (count[v] or 0) + 1 end
	end
	for _, map in ipairs(match.Maps) do
		local c = count[map.Id] or 0
		if c > top then
			best, top = { map }, c
		elseif c == top then
			best[#best + 1] = map
		end
	end
	return best[rng:NextInteger(1, #best)]
end

setStage = function(match, stage)
	if stage == "Lobby" then
		for i, p in ipairs(match.Players) do task.spawn(toHall, p, i) end
		runStage(match, "Lobby", function() setStage(match, "Vote") end)
	elseif stage == "Vote" then
		runStage(match, "Vote", function() setStage(match, "Prep") end)
	elseif stage == "Prep" then
		match.Map = pickMap(match)
		runStage(match, "Prep", function() setStage(match, "Playing") end)
	elseif stage == "Playing" then
		runStage(match, "Playing")
		local handler = modes[match.Mode]
		local ok, err = pcall(handler.Start, match)
		if not ok then
			warn("[VersusService] falha ao iniciar " .. match.Mode .. ": " .. tostring(err))
			for _, p in ipairs(match.Players) do toast(p, "The match was cancelled.", "error") end
			closeMatch(match)
		end
	end
end

-- ---------------------------------------------------------------- recompensas
local function reward(match, winner, loser)
	local R = V.Rewards
	local handler = modes[match.Mode]
	local key = pairKey(match.Players[1], match.Players[2])
	pairCount[key] = (pairCount[key] or 0) + 1
	local full = pairCount[key] <= R.FullRewardsPerOpponent

	local function xpFor(player, amount)
		local uid = handler.XpTarget and handler.XpTarget(match, player) or ProgressService.PartnerUid(player)
		local res = uid and ProgressService.AddXP(player, uid, amount)
		return { Amount = amount, Uid = uid, Name = res and res.Name, Level = res and res.Level, LevelsGained = res and res.LevelsGained or 0 }
	end

	local out = {}
	if winner and winner.Parent then
		local cash, points = 0, 0
		if full then
			cash = math.floor(math.max(R.WinCashMin, (winner:GetAttribute("CashPerSec") or 0) * R.WinCashSeconds))
			points = R.WinSpinPoints
			DataService.AddCash(winner, cash)
			WheelService.AddPoints(winner, points)
		end
		out[winner] = { Win = true, XP = xpFor(winner, R.WinXP), Cash = cash, SpinPoints = points, Full = full }
		local data = DataService.Get(winner)
		if data and data.Versus then
			local s = data.Versus.Stats
			local field = match.Mode .. "Wins"
			s[field] = (s[field] or 0) + 1
			s.Streak = (s.Streak or 0) + 1
			s.BestStreak = math.max(s.BestStreak or 0, s.Streak)
		end
	end
	-- quem SAIU do jogo no meio (matchOf já limpo) não recebe nem o XP de consolação
	if loser and loser.Parent and matchOf[loser] == match then
		out[loser] = { Win = false, XP = xpFor(loser, R.LoseXP), Cash = 0, SpinPoints = 0, Full = full }
		local data = DataService.Get(loser)
		if data and data.Versus then
			local s = data.Versus.Stats
			local field = match.Mode .. "Losses"
			s[field] = (s[field] or 0) + 1
			s.Streak = 0
		end
	end
	return out
end

-- Chamado pelo modo quando o jogo acaba. winner = Player (ou nil se ninguém venceu: sem recompensa).
function VersusService.Finish(match, winner, info)
	if matches[match.Id] ~= match or match.Stage ~= "Playing" then return end
	local loser = winner and VersusService.Opponent(match, winner) or nil
	local rewards = winner and reward(match, winner, loser) or {}
	runStage(match, "Result", function() closeMatch(match) end)
	for _, p in ipairs(match.Players) do
		if p.Parent then
			Net.Fire(p, "VersusResult", {
				Mode = match.Mode, WinnerUserId = winner and winner.UserId or 0,
				WinnerName = winner and winner.DisplayName or "", Reason = info and info.Reason or "",
				Rewards = rewards[p], Details = info and info.Details,
			})
			DataService.SaveNow(p)
		end
	end
end

-- ---------------------------------------------------------------- convites
local function closeInvite(invite, reasonKey, toSender, toTarget)
	if invites[invite.Id] ~= invite then return end
	invites[invite.Id] = nil
	invite.Token = nil
	for _, p in ipairs({ invite.From, invite.To }) do
		if inviteOf[p] == invite then inviteOf[p] = nil end
		if p.Parent then Net.Fire(p, "VersusInviteClosed", { Id = invite.Id }) end
	end
	if toSender and invite.From.Parent then toast(invite.From, toSender, "info", invite.To.DisplayName) end
	if toTarget and invite.To.Parent then toast(invite.To, toTarget, "info", invite.From.DisplayName) end
	return reasonKey
end

local function startMatch(invite)
	local handler = modes[invite.Mode]
	local match = {
		Id = newId(), Mode = invite.Mode, Players = { invite.From, invite.To },
		Ready = {}, Votes = {}, Maps = handler.Maps(), Map = nil, Stage = "", Token = {},
	}
	matches[match.Id] = match
	matchOf[invite.From], matchOf[invite.To] = match, match
	setStage(match, "Lobby")
end

-- Alguém saiu (do jogo ou pelo botão LEAVE).
local function leave(player, quit)
	local invite = inviteOf[player]
	if invite then
		closeInvite(invite, "left", player ~= invite.From and "%s declined your challenge." or nil, nil)
	end
	local match = matchOf[player]
	if not match then return end
	local other = VersusService.Opponent(match, player)
	if match.Stage == "Playing" then
		-- no meio do jogo: quem ficou vence (o modo limpa carros/arena antes)
		local handler = modes[match.Mode]
		if handler.Abort then pcall(handler.Abort, match, player) end
		if other.Parent then toast(other, "Your opponent left. You win!", "good") end
		if quit then matchOf[player] = nil end
		VersusService.Finish(match, other, { Reason = "Forfeit" })
	elseif match.Stage == "Result" then
		if quit then matchOf[player] = nil end
	else
		if other.Parent then toast(other, "The match was cancelled.", "info") end
		closeMatch(match)
	end
end

-- ---------------------------------------------------------------- init
function VersusService.Init()
	DataService.OnLoaded(function(player) setAttrs(player, nil) end)
	Players.PlayerRemoving:Connect(function(player)
		leave(player, true)
		lastInvite[player] = nil
	end)

	-- Lista de jogadores do servidor para o painel "Challenge a Player".
	Net.Handle("VersusPlayers", function(player)
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				list[#list + 1] = { UserId = p.UserId, Name = p.DisplayName, Free = isFree(p) }
			end
		end
		return { ok = true, List = list, Free = isFree(player) }
	end, 1)

	Net.Handle("VersusInvite", function(player, userId, mode)
		if type(userId) ~= "number" or type(mode) ~= "string" then return { ok = false, err = "Invalid" } end
		local handler = modes[mode]
		if not handler then return { ok = false, err = "Invalid" } end
		if not isFree(player) then
			return { ok = false, err = "NotFree", msg = Locale.For(player, "You can only challenge from the lobby.") }
		end
		if lastInvite[player] and os.clock() - lastInvite[player] < V.InviteCooldown then
			return { ok = false, err = "Cooldown", msg = Locale.For(player, "Wait a few seconds before inviting again.") }
		end
		local target = Players:GetPlayerByUserId(userId)
		if not target or target == player then return { ok = false, err = "Invalid" } end
		if not isFree(target) then
			return { ok = false, err = "Busy", msg = Locale.For(player, "%s is busy right now.", target.DisplayName) }
		end
		if handler.CanJoin then
			local ok, msg = handler.CanJoin(player)
			if not ok then return { ok = false, err = "CantJoin", msg = Locale.For(player, msg) } end
		end

		lastInvite[player] = os.clock()
		local invite = { Id = newId(), From = player, To = target, Mode = mode, Token = {} }
		invites[invite.Id] = invite
		inviteOf[player], inviteOf[target] = invite, invite
		local endsAt = workspace:GetServerTimeNow() + V.InviteSeconds
		Net.Fire(target, "VersusInvited", { Id = invite.Id, Mode = mode, FromUserId = player.UserId, FromName = player.DisplayName, EndsAt = endsAt })
		local token = invite.Token
		task.delay(V.InviteSeconds, function()
			if invites[invite.Id] == invite and invite.Token == token then
				closeInvite(invite, "timeout", "%s didn't answer in time.", nil)
			end
		end)
		return { ok = true, Id = invite.Id, EndsAt = endsAt, Name = target.DisplayName }
	end, 1)

	Net.Handle("VersusRespond", function(player, inviteId, accept)
		if type(inviteId) ~= "number" or type(accept) ~= "boolean" then return { ok = false, err = "Invalid" } end
		local invite = invites[inviteId]
		if not invite or invite.To ~= player then return { ok = false, err = "Expired" } end
		if not accept then
			closeInvite(invite, "declined", "%s declined your challenge.", nil)
			return { ok = true }
		end
		-- confere de novo: 20 segundos se passaram e qualquer um dos dois pode ter ficado ocupado
		local handler = modes[invite.Mode]
		local from = invite.From
		closeInvite(invite, "accepted", nil, nil) -- libera inviteOf antes do isFree
		if not (isFree(player) and isFree(from)) then
			if from.Parent then toast(from, "The match was cancelled.", "info") end
			return { ok = false, err = "Busy" }
		end
		if handler.CanJoin then
			local ok, msg = handler.CanJoin(player)
			if not ok then
				if from.Parent then toast(from, "The match was cancelled.", "info") end
				return { ok = false, err = "CantJoin", msg = Locale.For(player, msg) }
			end
		end
		startMatch(invite)
		return { ok = true }
	end, 0.5)

	Net.Handle("VersusCancel", function(player)
		local invite = inviteOf[player]
		if invite and invite.From == player then closeInvite(invite, "cancelled", nil, nil) end
		return { ok = true }
	end, 0.5)

	Net.Handle("VersusReady", function(player)
		local match = matchOf[player]
		if not match or match.Stage ~= "Lobby" then return { ok = false } end
		match.Ready[player] = true
		if match.Ready[match.Players[1]] and match.Ready[match.Players[2]] then
			setStage(match, "Vote")
		else
			broadcast(match)
		end
		return { ok = true }
	end, 0.5)

	Net.Handle("VersusVote", function(player, mapId)
		local match = matchOf[player]
		if not match or match.Stage ~= "Vote" or type(mapId) ~= "string" then return { ok = false } end
		local valid = false
		for _, map in ipairs(match.Maps) do
			if map.Id == mapId then valid = true end
		end
		if not valid then return { ok = false, err = "Invalid" } end
		match.Votes[player] = mapId
		if match.Votes[match.Players[1]] and match.Votes[match.Players[2]] then
			setStage(match, "Prep")
		else
			broadcast(match)
		end
		return { ok = true }
	end, 0.3)

	Net.Handle("VersusLeave", function(player)
		leave(player, false)
		return { ok = true }
	end, 1)
end

return VersusService
