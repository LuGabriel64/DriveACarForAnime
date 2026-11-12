-- test_beta19.lua — testes da lógica pura da Beta 1.9 (rodado por run_tests.py em Lua 5.4).
-- MODULE_DIR (global) = pasta com os módulos já convertidos para Lua 5.4.

-- ---------------------------------------------------------------- imitações mínimas do Roblox
Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end, new = function(r, g, b) return { R = r, G = g, B = b } end }
Vector3 = { new = function(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end }
Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }
Enum = setmetatable({}, { __index = function(t, k)
	local sub = setmetatable({}, { __index = function(_, k2) return k .. "." .. k2 end })
	rawset(t, k, sub)
	return sub
end })
function math.clamp(x, lo, hi) if x < lo then return lo elseif x > hi then return hi end return x end
Random = { new = function(seed)
	local state = (math.floor(seed or 1) * 2654435761 + 88172645463325252) & 0x7FFFFFFFFFFFFFFF
	if state == 0 then state = 88172645463325252 end
	local self = {}
	function self:NextNumber()
		state = state ~ ((state << 13) & 0x7FFFFFFFFFFFFFFF)
		state = state ~ (state >> 7)
		state = state ~ ((state << 17) & 0x7FFFFFFFFFFFFFFF)
		return (state % 1000000007) / 1000000007
	end
	function self:NextInteger(a, b) return a + math.floor(self:NextNumber() * (b - a + 1)) end
	return self
end }

-- ---------------------------------------------------------------- mini framework
local passed, failed = 0, 0
local function check(cond, name, detail)
	if cond then
		passed = passed + 1
	else
		failed = failed + 1
		print("  FALHOU: " .. name .. (detail and (" -> " .. tostring(detail)) or ""))
	end
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
local function section(name) print("== " .. name) end
local function module(name) return dofile(MODULE_DIR .. "/" .. name .. ".lua") end

-- ---------------------------------------------------------------- Config real + bloco da Beta 1.9
section("Config + ConfigBeta19")
local Config = module("Config")
local settingsBefore = #Config.Settings
module("ConfigBeta19")(Config)
check(Config.Version ~= nil and #Config.Biomes == 7, "Config real carregou (7 biomas)")
check(#Config.Settings == settingsBefore + 1 and Config.Settings[#Config.Settings].Key == "Music", "interruptor Music adicionado")
check(Config.Wheel.Points.PerSpin == 100 and Config.Wheel.Prizes ~= nil, "Config.Wheel.Points sem apagar o resto da roleta")
do
	local okOrder = true
	for i = 2, #Config.F1Cars do
		local a, b = Config.F1Cars[i - 1], Config.F1Cars[i]
		if not (b.Price > a.Price and b.MaxSpeed > a.MaxSpeed) then okOrder = false end
	end
	check(okOrder, "F1: preço e velocidade sobem a cada carro")
	check(Config.F1Cars[1].Price == 0, "F1: o primeiro é grátis")
	check(Config.F1Cars[#Config.F1Cars].MaxSpeed * 1.6 <= Config.SpeedCap, "F1: mesmo com boost (x1,6) fica abaixo do teto de velocidade",
		Config.F1Cars[#Config.F1Cars].MaxSpeed * 1.6 .. " > " .. Config.SpeedCap)
	check(Config.Versus.Race.CollapseFactor < Config.Escape.CarFactor, "colapso da corrida 1v1 é mais lento que o da fuga do ovo")
	for _, c in ipairs(Config.F1Cars) do
		check(Config.CarById[c.Id] == nil, "F1 " .. c.Id .. " não colide com Id de carro normal")
	end
end

-- ---------------------------------------------------------------- AnimeStats
section("AnimeStats: estrelas, nível, renda")
local AnimeStats = module("AnimeStats").Use(Config)
do
	-- exemplo do dono: Secret de $400/s => 400, 430, 460, 490, 520, 550
	local fake = { Id = "x", Income = 400, Rarity = "Secret", Biome = "warrior" }
	local expect = { [0] = 400, 430, 460, 490, 520, 550 }
	for s = 0, 5 do
		check(near(AnimeStats.Income(fake, { Stars = s }), expect[s], 1e-6), "renda com " .. s .. " estrelas = " .. expect[s], AnimeStats.Income(fake, { Stars = s }))
	end
	check(near(AnimeStats.Income(fake, {}), 400), "personagem antigo (sem Stars/Level) rende igual a antes")
	check(near(AnimeStats.Income(fake, { Stars = 9, Level = 999 }), 550 * 1.49), "estrelas e nível fora do limite são cortados (5★, nv 50)")
	check(near(AnimeStats.Income(fake, { Mut = "Gold", Size = "BIG" }), 400 * 2 * 1.5), "mutação e tamanho continuam valendo")

	local sum = 0
	for s = 0, 5 do sum = sum + AnimeStats.StarChance(s) end
	check(near(sum, 1), "chances das estrelas somam 100%")
	check(AnimeStats.RollStars(0) == 0 and AnimeStats.RollStars(0.999999) == 5, "RollStars: extremos 0 e 5")
	local rng, count, N = Random.new(7), {}, 200000
	for _ = 1, N do
		local s = AnimeStats.RollStars(rng:NextNumber())
		count[s] = (count[s] or 0) + 1
	end
	local okDist = true
	for s = 0, 5 do
		if math.abs((count[s] or 0) / N - AnimeStats.StarChance(s)) > 0.01 then okDist = false end
	end
	check(okDist, "RollStars: distribuição bate com os pesos (200 mil sorteios)")
end

section("AnimeStats: XP e nível")
do
	local total = 0
	for l = 1, Config.Levels.Max - 1 do total = total + AnimeStats.XpToNext(l) end
	print(("  XP total do nível 1 ao %d: %d"):format(Config.Levels.Max, total))
	check(total == 16170, "XP total até o nível 50 = 16.170", total)
	check(AnimeStats.XpToNext(Config.Levels.Max) == nil, "nível máximo não pede mais XP")
	local e = {}
	check(AnimeStats.AddXP(e, 41) == 0 and e.Level == 1 and e.XP == 41, "41 XP: ainda nível 1")
	check(AnimeStats.AddXP(e, 1) == 1 and e.Level == 2 and e.XP == 0, "42 XP: sobe para o nível 2")
	local e2 = {}
	check(AnimeStats.AddXP(e2, total) == 49 and e2.Level == 50 and e2.XP == 0, "XP total exato leva ao nível 50")
	check(AnimeStats.AddXP(e2, 99999) == 0 and e2.Level == 50 and e2.XP == 0, "nível 50 não passa disso")
	local e3 = { Level = 3, XP = 5 }
	check(AnimeStats.AddXP(e3, -50) == 0 and AnimeStats.AddXP(e3, 0 / 0) == 0 and AnimeStats.AddXP(e3, "x") == 0 and e3.XP == 5, "XP negativo / NaN / texto é ignorado")
	local wins = math.ceil(total / Config.Versus.Rewards.WinXP)
	local losses = math.ceil(total / Config.Versus.Rewards.LoseXP)
	print(("  partidas até o nível 50: %d só vencendo | %d só perdendo"):format(wins, losses))
end

-- ---------------------------------------------------------------- lutadores
section("Batalha: classes, ULTs e poder")
do
	local missing, bad, orphan = {}, {}, {}
	local FX = { beam = 1, slash = 1, punch = 1, storm = 1, flame = 1, ice = 1, sand = 1, light = 1, shadow = 1, tech = 1, blossom = 1, meteor = 1 }
	for _, a in ipairs(Config.Animes) do
		if not a.Legacy then
			local f = Config.Battle.Fighters[a.Id]
			if not f then
				missing[#missing + 1] = a.Id
			elseif not (Config.Battle.Classes[f.Class] and FX[f.Fx] and type(f.Ult) == "string" and #f.Ult > 0) then
				bad[#bad + 1] = a.Id
			end
		end
	end
	for id in pairs(Config.Battle.Fighters) do
		if not Config.AnimeById[id] then orphan[#orphan + 1] = id end
	end
	check(#missing == 0, "todo personagem ativo tem classe e ULT", table.concat(missing, ","))
	check(#bad == 0, "classes e efeitos das ULTs são válidos", table.concat(bad, ","))
	check(#orphan == 0, "nenhuma ULT para personagem que não existe", table.concat(orphan, ","))
	for _, cls in pairs(Config.Battle.Classes) do
		check(Config.Battle.UltKinds[cls.UltKind] ~= nil, "tipo de ULT " .. tostring(cls.UltKind) .. " existe")
	end
	local legacy = AnimeStats.BattleStats(Config.AnimeById.nini, {})
	check(legacy.Class == "Champion" and legacy.HP > 0, "personagem Legacy luta com a classe padrão")

	-- dentro de um bioma, raridade maior = mais poder
	local okMono = true
	for _, b in ipairs(Config.Biomes) do
		local last = 0
		for _, rname in ipairs(Config.RarityOrder) do
			for _, a in ipairs(Config.AnimesByBiome[b.Id][rname] or {}) do
				local p = AnimeStats.Power(a, {})
				if p < last then okMono = false end
			end
			local list = Config.AnimesByBiome[b.Id][rname]
			if list and list[1] then last = AnimeStats.Power(list[1], {}) end
		end
	end
	check(okMono, "poder cresce com a raridade em todos os biomas")
end

-- ---------------------------------------------------------------- BattleSim
section("BattleSim")
local BattleSim = module("BattleSim").Use(Config)
local function stats(id, entry) return AnimeStats.BattleStats(Config.AnimeById[id], entry or {}) end
local function winRate(a, b, n)
	local w, dur, minD, maxD = 0, 0, math.huge, 0
	for seed = 1, n do
		local r = BattleSim.Run(a, b, seed)
		if r.Winner == 1 then w = w + 1 end
		dur = dur + r.Duration
		if r.Duration < minD then minD = r.Duration end
		if r.Duration > maxD then maxD = r.Duration end
	end
	return w / n, dur / n, minD, maxD
end
do
	local a, b = stats("gohan"), stats("gohan")
	local r1, r2 = BattleSim.Run(a, b, 1234), BattleSim.Run(a, b, 1234)
	local same = r1.Winner == r2.Winner and #r1.Events == #r2.Events and r1.Duration == r2.Duration
	for i = 1, #r1.Events do
		if r1.Events[i].Kind ~= r2.Events[i].Kind or r1.Events[i].Dmg ~= r2.Events[i].Dmg then same = false end
	end
	check(same, "mesma semente = mesma luta (determinístico)")

	local okEvents, sawUlt, lastT = true, false, 0
	for _, e in ipairs(r1.Events) do
		if e.Hp[1] < 0 or e.Hp[2] < 0 or e.T < lastT or e.Energy[1] > 100 or e.Energy[2] > 100 then okEvents = false end
		if e.Kind == "ult" then sawUlt = true end
		lastT = e.T
	end
	local last = r1.Events[#r1.Events]
	check(okEvents, "roteiro: HP nunca negativo, tempo crescente, energia até 100")
	check(sawUlt, "roteiro: a ULT acontece numa luta normal")
	check(last.Kind == "ko" and last.Hp[3 - r1.Winner] == 0 and last.Hp[r1.Winner] > 0, "roteiro: termina em nocaute com o vencedor de pé")

	local rate, avg, minD, maxD = winRate(a, b, 2000)
	print(("  espelho (mesmo personagem): jogador 1 vence %.1f%% | luta dura %.1fs em média (%.1f a %.1f)"):format(rate * 100, avg, minD, maxD))
	check(rate > 0.44 and rate < 0.56, "luta espelhada é equilibrada (44-56%)", rate)
	check(avg >= 10 and avg <= 35, "duração média de luta equilibrada entre 10 e 35 s", avg)
	check(maxD <= Config.Battle.Sim.MaxSeconds, "nenhuma luta passa do tempo máximo")

	-- "o boneco mais raro com os melhores status ganha"
	local order = { "goku", "vegeta", "kame", "gohan", "cell", "piccolo", "buu" }
	local okRarity = true
	for i = 2, #order do
		local r = winRate(stats(order[i]), stats(order[i - 1]), 300)
		if r < 0.97 then okRarity = false; print("  " .. order[i] .. " x " .. order[i - 1] .. ": " .. r) end
	end
	check(okRarity, "raridade maior (mesmo bioma) vence a raridade logo abaixo em 97%+ das lutas")
	local r5 = winRate(stats("gohan", { Stars = 5 }), stats("gohan", { Stars = 0 }), 1000)
	local r1s = winRate(stats("gohan", { Stars = 1 }), stats("gohan", { Stars = 0 }), 1000)
	print(("  mesma personagem: 5★ x 0★ vence %.1f%% | 1★ x 0★ vence %.1f%%"):format(r5 * 100, r1s * 100))
	check(r5 > 0.95, "5 estrelas vence 0 estrelas quase sempre", r5)
	check(r1s > 0.55, "1 estrela já dá vantagem", r1s)
	local rl = winRate(stats("piccolo", { Level = 50 }), stats("buu", { Level = 1 }), 300)
	check(rl > 0.9, "Mythic nível 50 vence Secret nível 1 (treinar compensa)", rl)

	-- equilíbrio entre classes: quanto Poder a mais a LINHA precisa para empatar com a COLUNA.
	-- Critério: nunca mais que 1 estrela (7,5%) => a classe não decide a luta sozinha.
	local names = { "Brawler", "Guardian", "Speedster", "Mystic", "Champion" }
	local function classStats(class, mult)
		local B, cls, out = Config.Battle, Config.Battle.Classes[class], { Power = 300 * mult, Class = class }
		out.UltKind = cls.UltKind
		for _, k in ipairs(AnimeStats.StatKeys) do out[k] = math.floor(300 * mult * B.Base[k] * cls[k] + 0.5) end
		return out
	end
	local N = 120
	local function rate(x, mx, y)
		local w = 0
		for seed = 1, N do
			if BattleSim.Run(classStats(x, mx), classStats(y, 1), seed).Winner == 1 then w = w + 1 end
			if BattleSim.Run(classStats(y, 1), classStats(x, mx), seed + 5000).Winner == 2 then w = w + 1 end
		end
		return w / (2 * N)
	end
	local function handicap(x, y)
		local lo, hi = 0.6, 1.6
		for _ = 1, 8 do
			local mid = (lo + hi) / 2
			if rate(x, mid, y) < 0.5 then lo = mid else hi = mid end
		end
		return (lo + hi) / 2
	end
	print("  classe x classe — Poder que a linha precisa para empatar com a coluna (1,000 = igual):")
	local worst, worstAvg = 1, 1
	for _, x in ipairs(names) do
		local row, logsum = {}, 0
		for _, y in ipairs(names) do
			if x == y then
				row[#row + 1] = "  -  "
			else
				local h = handicap(x, y)
				row[#row + 1] = ("%5.3f"):format(h)
				logsum = logsum + math.log(h)
				if math.abs(h - 1) > math.abs(worst - 1) then worst = h end
			end
		end
		local avg = math.exp(logsum / 4)
		if math.abs(avg - 1) > math.abs(worstAvg - 1) then worstAvg = avg end
		print(("    %-10s %s   média %.3f"):format(x, table.concat(row, " "), avg))
	end
	check(math.abs(worst - 1) <= Config.Stars.StepMult, "vantagem de classe nunca passa de 1 estrela (7,5%)", worst)
	check(math.abs(worstAvg - 1) <= 0.02, "nenhuma classe é melhor ou pior que a média por mais de 2%", worstAvg)
end

-- ---------------------------------------------------------------- Locale
section("Locale")
do
	local pt = module("Locale_pt")
	local Locale = module("Locale").Use(Config.Languages, { pt = pt })
	check(Locale.Translate("pt", "Free spin ready!") == "Giro grátis pronto!", "traduz frase simples")
	check(Locale.Translate("en", "Free spin ready!") == "Free spin ready!", "inglês devolve a própria chave")
	check(Locale.Translate("pt", "Texto que não existe") == "Texto que não existe", "sem tradução: devolve o original")
	check(Locale.Translate("pt", "🔒 This egg needs a Tier %d car!", 3) == "🔒 Este ovo precisa de um carro Tier 3!", "traduz e formata")
	check(Locale.Translate("pt", "Spin (%d)", "abc") == "Spin (%d)", "argumento errado não derruba a tela")
	check(Locale.Detect("pt-br") == "pt" and Locale.Detect("PT_PT") == "pt" and Locale.Detect("fr-fr") == "en" and Locale.Detect(nil) == "en", "detecta o idioma da conta")
	check(Locale.IsValid("pt") and not Locale.IsValid("xx") and not Locale.IsValid(nil), "lista branca de idiomas")
	check(Locale.Has("PLAY") and not Locale.Has("GARAGE 3"), "Has: só textos com tradução")

	-- toda tradução precisa ter os MESMOS %d / %s, na mesma ordem
	local function specs(s)
		local out = {}
		for sp in s:gsub("%%%%", ""):gmatch("%%[%-%d%.]*([a-zA-Z])") do out[#out + 1] = sp end
		return table.concat(out, ",")
	end
	local n, badSpecs, empty = 0, {}, {}
	for key, value in pairs(pt) do
		n = n + 1
		if specs(key) ~= specs(value) then badSpecs[#badSpecs + 1] = key end
		if type(value) ~= "string" or value == "" then empty[#empty + 1] = key end
	end
	print("  frases em português: " .. n)
	check(#badSpecs == 0, "traduções têm os mesmos %d/%s das chaves", table.concat(badSpecs, " | "))
	check(#empty == 0, "nenhuma tradução vazia")
	for _, s in ipairs(Config.Settings) do
		check(pt[s.Label] ~= nil and pt[s.Desc] ~= nil, "Configs traduzido: " .. s.Label)
	end
	for _, rname in ipairs(Config.RarityOrder) do
		check(pt[Config.Rarities[rname].Label] ~= nil, "raridade traduzida: " .. rname)
	end
end

-- ---------------------------------------------------------------- só compilar (dependem do Roblox)
section("Sintaxe dos módulos que dependem do Roblox")
for _, name in ipairs({ "VersusService", "ProgressService", "Platform", "Locale" }) do
	local fn, err = loadfile(MODULE_DIR .. "/" .. name .. ".lua")
	check(fn ~= nil, name .. " compila", err)
end

print(("\n%d verificações passaram, %d falharam"):format(passed, failed))
if failed > 0 then error("testes falharam", 0) end
