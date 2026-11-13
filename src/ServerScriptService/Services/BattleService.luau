--[[
	BattleService  (ServerScriptService.Services.BattleService)                                  Beta 1.9
	=====================================================================================================
	BATALHA DE ANIME — o modo "Battle" do VersusService.

	COMO FUNCIONA
	  1. Na preparação (30 s) cada jogador escolhe UM lutador entre os seus personagens: ação "PickFighter"(uid).
	     Sem escolha, vale o de maior Poder.
	  2. No começo do jogo o servidor monta os status dos dois lutadores A PARTIR DO SAVE de cada jogador
	     (Shared.AnimeStats.BattleStats: raridade, bioma, estrelas, nível, mutação, tamanho, classe) e SIMULA a luta
	     inteira com Services.BattleSim. O vencedor está decidido antes de a cena começar.
	  3. Os dois recebem o ROTEIRO (evento "BattleScript") e assistem à mesma encenação (Client.BattleUI).
	     Os avatares vão para a plateia da arena votada.
	  4. Passado o tempo da cena, VersusService.Finish paga as recompensas. O XP vai para o lutador usado.

	SEGURANÇA: o cliente só manda QUAL personagem quer usar; o servidor confere que o uid é dele e lê os status
	do save. A semente do sorteio é do servidor (impressa no Output: a mesma semente reproduz a mesma luta).
	Sair durante a cena dá a vitória ao outro (VersusService), mesmo que a simulação apontasse o contrário.

	REDE : "PickFighter"(uid) -> { ok } | eventos "BattleScript"(roteiro) e "BattleAbort"()
	ATRIBUTO do Player: FighterUid (0 = automático: o mais forte)
	ROTEIRO = { MatchId, Arena = { Id, Name, Origin }, StartAt (hora do servidor), Intro, Outro, Duration,
	            Winner (1|2), Reason ("ko"|"timeout"), WinnerFx, Events (do BattleSim),
	            Fighters = { { UserId, Player, Id, Name, Mut, Size, Stars, Level, Rarity, Stats = BattleStats }, x2 } }

	DEPENDÊNCIAS: VersusService, ProgressService (FindEntry / StrongestUid), BattleSim, Shared.AnimeStats, Config.Versus.Battle.
	NÃO TESTADO com 2 jogadores reais (o MCP só abre Play de 1 jogador).
]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local AnimeStats = require(Shared.AnimeStats)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local VersusService = require(script.Parent.VersusService)
local BattleSim = require(script.Parent.BattleSim)

local BattleService = {}
local VB = Config.Versus.Battle
local rng = Random.new()
local picked = {}   -- [player] = uid escolhido na preparação
local battles = {}  -- [match] = { Token, Uids = {[player]=uid} }

local function hasCharacter(player)
	local data = DataService.Get(player)
	if not data then return false end
	for _, e in ipairs(data.Animes) do
		if Config.AnimeById[e.Id] then return true end
	end
	return false
end

-- Lutador de um jogador: o escolhido (se ainda for dele) ou o mais forte. Devolve uid, entry, cfg.
local function fighterOf(player)
	local uid = picked[player]
	local entry, cfg = ProgressService.FindEntry(player, uid)
	if not (entry and cfg) then
		uid = ProgressService.StrongestUid(player)
		entry, cfg = ProgressService.FindEntry(player, uid)
	end
	if entry and cfg then return uid, entry, cfg end
	return nil
end

local function start(match)
	local arena = match.Map or VB.Arenas[1]
	local st = { Token = {}, Uids = {} }
	battles[match] = st
	local fighters, stats = {}, {}
	for i, p in ipairs(match.Players) do
		local uid, entry, cfg = fighterOf(p)
		if not uid then
			-- ficou sem personagem entre o convite e o jogo (vendeu todos): o outro vence
			battles[match] = nil
			VersusService.Finish(match, VersusService.Opponent(match, p), { Reason = "Forfeit" })
			return
		end
		st.Uids[p] = uid
		stats[i] = AnimeStats.BattleStats(cfg, entry)
		fighters[i] = { UserId = p.UserId, Player = p.DisplayName, Id = cfg.Id, Name = cfg.Name, Rarity = cfg.Rarity,
			Mut = entry.Mut, Size = entry.Size, Stars = AnimeStats.Stars(entry), Level = AnimeStats.Level(entry), Stats = stats[i] }
	end

	local seed = rng:NextInteger(1, 2147483646)
	local result = BattleSim.Run(stats[1], stats[2], seed)
	local winner = match.Players[result.Winner]
	print(("[BattleService] partida %d (semente %d): %s [%s, Poder %d] x %s [%s, Poder %d] => vence %s (%s, %.1fs, %d eventos)"):format(
		match.Id, seed, match.Players[1].Name, fighters[1].Name, stats[1].Power, match.Players[2].Name, fighters[2].Name, stats[2].Power,
		winner.Name, result.Reason, result.Duration, #result.Events))

	local startAt = workspace:GetServerTimeNow() + VB.StartDelay
	local script = {
		MatchId = match.Id, Arena = { Id = arena.Id, Name = arena.Name, Origin = arena.Origin },
		StartAt = startAt, Intro = VB.IntroSeconds, Outro = VB.OutroSeconds, Duration = result.Duration,
		Winner = result.Winner, Reason = result.Reason, WinnerFx = VersusService.EquippedFx(winner),
		Events = result.Events, Fighters = fighters,
	}
	for i, p in ipairs(match.Players) do
		if p.Parent then
			local spot = arena.Origin + (VB.SpectatorOffsets[i] or VB.SpectatorOffsets[1])
			task.spawn(VersusService.Teleport, p, CFrame.lookAt(spot, Vector3.new(arena.Origin.X, spot.Y, arena.Origin.Z)))
			Net.Fire(p, "BattleScript", script)
		end
	end

	local token = st.Token
	task.delay(VB.StartDelay + VB.IntroSeconds + result.Duration + VB.OutroSeconds, function()
		if battles[match] ~= st or st.Token ~= token then return end -- partida abortada
		battles[match] = nil
		VersusService.Finish(match, winner, {
			Reason = result.Reason == "ko" and "K.O.!" or "TIME'S UP!",
			Details = { Fighters = { fighters[1].Name, fighters[2].Name }, WinnerFighter = fighters[result.Winner].Name },
		})
		for _, p in ipairs(match.Players) do picked[p] = nil; if p.Parent then p:SetAttribute("FighterUid", 0) end end
	end)
end

-- Alguém saiu no meio da cena: cancela o fim agendado e manda o outro parar a encenação.
local function abort(match)
	local st = battles[match]
	battles[match] = nil
	if st then st.Token = nil end
	for _, p in ipairs(match.Players) do
		picked[p] = nil
		if p.Parent then p:SetAttribute("FighterUid", 0); Net.Fire(p, "BattleAbort") end
	end
end

function BattleService.Init()
	VersusService.RegisterMode("Battle", {
		Maps = function() return VB.Arenas end,
		CanJoin = function(player)
			if hasCharacter(player) then return true end
			return false, "You need at least one character to battle!"
		end,
		Start = start,
		Abort = abort,
		XpTarget = function(match, player)
			local st = battles[match]
			return (st and st.Uids[player]) or select(1, fighterOf(player))
		end,
	})

	Net.Handle("PickFighter", function(player, uid)
		if type(uid) ~= "number" then return { ok = false, err = "Invalid" } end
		local match = VersusService.GetMatch(player)
		if not match or match.Mode ~= "Battle" or match.Stage == "Playing" or match.Stage == "Result" then return { ok = false, err = "Stage" } end
		local entry, cfg = ProgressService.FindEntry(player, uid)
		if not (entry and cfg) then return { ok = false, err = "Invalid" } end
		picked[player] = uid
		player:SetAttribute("FighterUid", uid)
		return { ok = true }
	end, 0.2)

	DataService.OnLoaded(function(player) player:SetAttribute("FighterUid", 0) end)
	Players.PlayerRemoving:Connect(function(player) picked[player] = nil end)
end

return BattleService
