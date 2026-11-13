--[[
	BattleSim  (ServerScriptService.Services.BattleSim)                                          Beta 1.9
	=====================================================================================================
	SIMULA uma batalha de anime inteira, de uma vez, no SERVIDOR. Biblioteca sem Init (como o EggRoll).

	POR QUE ASSIM
	  * O cliente não decide nada: o servidor calcula a luta, paga as recompensas e só então manda o
	    ROTEIRO (lista de eventos) para os dois jogadores. O cliente apenas encena o roteiro (Client.BattleUI).
	  * Nada de lutador físico no servidor: sem custo de física, sem problema de "quem é dono da peça",
	    e várias batalhas podem acontecer ao mesmo tempo na mesma arena (cada tela desenha só a sua).
	  * Mesma semente + mesmos status = mesma luta (dá para reproduzir um bug ou conferir um resultado).

	REGRAS DA LUTA (números em Config.Battle.Sim)
	  * Cada lutador ataca num intervalo próprio (ASPD maior = ataca mais vezes). O mais rápido (SPD) começa;
	    com SPD igual, o servidor sorteia quem começa.
	  * Dano básico = ATK x ATK / (ATK + DEF do alvo), com variação pequena, chance de crítico e de esquiva
	    (as duas dependem da diferença de SPD).
	  * Bater e apanhar enchem a ENERGIA. Com 100, o próximo ataque é a ULT da classe:
	        Burst (golpe enorme) | Bulwark (golpe + escudo) | Flurry (vários golpes) |
	        Nova (golpe mágico que fura defesa) | Finisher (mais forte com o alvo quase caído)
	  * HP do alvo chegou a 0 => nocaute. Passou de MaxSeconds => vence quem tiver mais % de HP.

	API
	    BattleSim.Run(a, b, seed) -> { Winner = 1 | 2, Reason = "ko" | "timeout", Duration, Events, Fighters }
	        a, b = tabelas de AnimeStats.BattleStats (HP, ATK, DEF, SPD, ASPD, POW, UltKind...)
	    Evento  = { T, Actor (1|2), Kind, Dmg, Crit, Hp = {hp1, hp2}, Shield = {s1, s2}, Energy = {e1, e2}, Hits }
	        Kind: "hit" | "dodge" | "ult" | "ko" | "timeout"

	Dependências: Shared.Config (Config.Battle). Random.new(seed) do Roblox.
	TESTADO e calibrado fora do Roblox (repositório: planejamento/beta-1.9/testes). Sem sintaxe exclusiva do Luau.
]]
local BattleSim = {}

local Config
local function root()
	if not Config then
		Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
	end
	return Config
end
-- Só para testes fora do Roblox.
function BattleSim.Use(config)
	Config = config
	return BattleSim
end

local function clamp(x, lo, hi)
	if x < lo then return lo end
	if x > hi then return hi end
	return x
end

-- Dano de um golpe: quanto maior a DEF do alvo em relação ao ATK, menor a fatia que passa.
local function rawDamage(atk, def)
	if atk <= 0 then return 0 end
	return atk * atk / (atk + math.max(0, def))
end

-- Tira dano do escudo primeiro, depois do HP. Devolve o dano que chegou no HP.
local function applyDamage(target, dmg)
	if target.Shield > 0 then
		local absorbed = math.min(target.Shield, dmg)
		target.Shield = target.Shield - absorbed
		dmg = dmg - absorbed
	end
	target.Hp = math.max(0, target.Hp - dmg)
	return dmg
end

local function addEnergy(f, amount, max)
	f.Energy = math.min(max, f.Energy + amount)
end

function BattleSim.Run(a, b, seed)
	local B = root().Battle
	local S = B.Sim
	local rng = Random.new(seed or 0)

	local avgAspd = math.max(1, (a.ASPD + b.ASPD) / 2)
	local function newFighter(stats, other)
		local ratio = clamp(stats.ASPD / avgAspd, S.IntervalClamp[1], S.IntervalClamp[2])
		return {
			Stats = stats,
			Hp = stats.HP, MaxHp = stats.HP, Shield = 0, Energy = 0,
			Interval = S.BaseInterval / ratio,
			-- POW comparado ao do adversário: acelera a carga da ULT (e o dano da Nova)
			PowFactor = clamp(stats.POW / math.max(1, other.POW), S.PowClamp[1], S.PowClamp[2]),
			NextAt = 0,
		}
	end
	local f = { newFighter(a, b), newFighter(b, a) }
	-- o mais rápido ataca primeiro; empate de SPD = sorteio do servidor (senão o jogador 1 levaria vantagem fixa)
	local first = 1
	if b.SPD > a.SPD or (b.SPD == a.SPD and rng:NextNumber() < 0.5) then
		first = 2
	end
	f[first].NextAt = S.FirstStrike
	f[3 - first].NextAt = S.FirstStrike + S.FirstStrikeGap

	local events = {}
	local function push(t, actor, kind, extra)
		local e = {
			T = math.floor(t * 100 + 0.5) / 100, Actor = actor, Kind = kind,
			Hp = { math.floor(f[1].Hp + 0.5), math.floor(f[2].Hp + 0.5) },
			Shield = { math.floor(f[1].Shield + 0.5), math.floor(f[2].Shield + 0.5) },
			Energy = { math.floor(f[1].Energy), math.floor(f[2].Energy) },
		}
		if extra then
			for k, v in pairs(extra) do e[k] = v end
		end
		events[#events + 1] = e
		return e
	end

	local winner, reason, now = nil, nil, 0
	while not winner do
		-- quem age agora = quem tem o menor NextAt (empate: o mais rápido)
		local i = (f[2].NextAt < f[1].NextAt or (f[2].NextAt == f[1].NextAt and first == 2)) and 2 or 1
		local me, foe = f[i], f[3 - i]
		now = me.NextAt
		if now > S.MaxSeconds then
			reason = "timeout"
			break
		end

		if me.Energy >= S.EnergyMax then
			-- ---------------------------------------------------- ULT (nunca erra)
			me.Energy = 0
			local kind = B.UltKinds[me.Stats.UltKind] or B.UltKinds.Burst
			local def = foe.Stats.DEF * (1 - (kind.IgnoreDef or 0))
			local base = rawDamage(me.Stats.ATK, def) * kind.Mult
			if me.Stats.UltKind == "Nova" then
				base = base * me.PowFactor
			end
			if kind.ExecuteBelow and foe.Hp / foe.MaxHp <= kind.ExecuteBelow then
				base = base * (1 + kind.ExecuteBonus)
			end
			local hits, total = {}, 0
			for _ = 1, (kind.Hits or 1) do
				local dmg = base * (1 + (rng:NextNumber() * 2 - 1) * S.Variance)
				applyDamage(foe, dmg)
				total = total + dmg
				hits[#hits + 1] = math.floor(dmg + 0.5)
			end
			if kind.Shield then
				me.Shield = me.Shield + me.MaxHp * kind.Shield
			end
			addEnergy(foe, S.EnergyHurt, S.EnergyMax)
			push(now, i, "ult", { Dmg = math.floor(total + 0.5), Hits = hits, UltKind = me.Stats.UltKind })
			me.NextAt = now + me.Interval + S.UltPause
		else
			-- ---------------------------------------------------- ataque básico
			local spdRatio = me.Stats.SPD / math.max(1, foe.Stats.SPD)
			local dodge = clamp(S.DodgeBase + S.DodgeScale * (1 / spdRatio - 1), 0, S.DodgeMax)
			if rng:NextNumber() < dodge then
				addEnergy(foe, S.EnergyDodge, S.EnergyMax)
				push(now, i, "dodge")
			else
				local crit = rng:NextNumber() < clamp(S.CritBase + S.CritScale * (spdRatio - 1), S.CritMin, S.CritMax)
				local dmg = rawDamage(me.Stats.ATK, foe.Stats.DEF) * (1 + (rng:NextNumber() * 2 - 1) * S.Variance)
				if crit then
					dmg = dmg * S.CritMult
				end
				applyDamage(foe, dmg)
				addEnergy(me, S.EnergyHit * me.PowFactor, S.EnergyMax)
				addEnergy(foe, S.EnergyHurt, S.EnergyMax)
				push(now, i, "hit", { Dmg = math.floor(dmg + 0.5), Crit = crit })
			end
			me.NextAt = now + me.Interval
		end

		if foe.Hp <= 0 then
			winner, reason = i, "ko"
			push(now, i, "ko")
		end
	end

	if not winner then
		-- tempo esgotado: mais % de HP vence; empate => mais Poder; empate de novo => sorteio do servidor
		local p1, p2 = f[1].Hp / f[1].MaxHp, f[2].Hp / f[2].MaxHp
		if p1 ~= p2 then
			winner = (p1 > p2) and 1 or 2
		elseif (a.Power or 0) ~= (b.Power or 0) then
			winner = ((a.Power or 0) > (b.Power or 0)) and 1 or 2
		else
			winner = (rng:NextNumber() < 0.5) and 1 or 2
		end
		now = S.MaxSeconds
		push(now, winner, "timeout")
	end

	return {
		Winner = winner, Reason = reason or "timeout", Duration = math.floor(now * 100 + 0.5) / 100, Events = events,
		Fighters = {
			{ MaxHp = f[1].MaxHp, Interval = f[1].Interval },
			{ MaxHp = f[2].MaxHp, Interval = f[2].Interval },
		},
	}
end

return BattleSim
