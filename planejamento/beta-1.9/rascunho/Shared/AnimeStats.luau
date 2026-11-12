--[[
	AnimeStats  (destino: ReplicatedStorage.Shared.AnimeStats)                        RASCUNHO — Beta 1.9
	=====================================================================================================
	Funções PURAS (sem estado, sem serviços do Roblox) que respondem: "quanto vale ESTE personagem?"
	Servidor e cliente usam o MESMO módulo => o que a UI mostra é exatamente o que o servidor calcula.

	Um personagem salvo (entry em data.Animes) tem:
	    Id, Mut, Size            (já existiam)
	    Stars  0..5              NOVO — sorteado no ovo; cada estrela vale um valor fixo (Config.Stars)
	    Level  1..50, XP         NOVO — sobe com corridas 1v1 e batalhas (Config.Levels)
	Campos ausentes (saves antigos) contam como Stars = 0, Level = 1, XP = 0.

	API
	    AnimeStats.StarMult(stars)            -> multiplicador das estrelas
	    AnimeStats.LevelMult(level, perLevel) -> multiplicador do nível
	    AnimeStats.Income(cfg, entry)         -> renda em $/s (substitui a conta do FarmService.incomeOf)
	    AnimeStats.Power(cfg, entry)          -> "poder de batalha" (um número só, para comparar e mostrar)
	    AnimeStats.BattleStats(cfg, entry)    -> { HP, ATK, DEF, SPD, ASPD, POW, Power, Class, UltKind }
	    AnimeStats.XpToNext(level)            -> XP para subir do nível atual para o próximo (nil no máximo)
	    AnimeStats.AddXP(entry, amount)       -> níveis ganhos (altera entry.Level / entry.XP)
	    AnimeStats.RollStars(randomNumber)    -> estrelas para um número aleatório em [0,1) vindo do SERVIDOR

	Dependências: Shared.Config (com ConfigBeta19 aplicado).
]]
local AnimeStats = {}

local Config -- preenchido por AnimeStats.Use(Config) nos testes, ou pelo require abaixo dentro do Roblox
local function cfgRoot()
	if not Config then
		Config = require(script.Parent.Config)
	end
	return Config
end
-- Só para testes fora do Roblox (onde não existe script.Parent).
function AnimeStats.Use(config)
	Config = config
	return AnimeStats
end

local function clamp(x, lo, hi)
	if x < lo then return lo end
	if x > hi then return hi end
	return x
end

-- ---------------------------------------------------------------- estrelas e nível
function AnimeStats.Stars(entry)
	local s = tonumber(entry and entry.Stars) or 0
	return clamp(math.floor(s), 0, cfgRoot().Stars.Max)
end

function AnimeStats.Level(entry)
	local l = tonumber(entry and entry.Level) or 1
	return clamp(math.floor(l), 1, cfgRoot().Levels.Max)
end

function AnimeStats.StarMult(stars)
	return 1 + cfgRoot().Stars.StepMult * clamp(stars or 0, 0, cfgRoot().Stars.Max)
end

-- perLevel = quanto cada nível acima do 1 soma (Config.Levels.StatPerLevel ou .IncomePerLevel)
function AnimeStats.LevelMult(level, perLevel)
	return 1 + (perLevel or 0) * (clamp(level or 1, 1, cfgRoot().Levels.Max) - 1)
end

-- Sorteio das estrelas. r = número em [0,1) gerado pelo Random do SERVIDOR (EggRoll). O cliente nunca sorteia.
function AnimeStats.RollStars(r)
	local S = cfgRoot().Stars
	local total = 0
	for s = 0, S.Max do
		total = total + (S.Weights[s] or 0)
	end
	local pick, acc = r * total, 0
	for s = 0, S.Max do
		acc = acc + (S.Weights[s] or 0)
		if pick < acc then return s end
	end
	return 0
end

-- Chance (0..1) de sair exatamente N estrelas (a UI mostra a mesma tabela que o servidor usa).
function AnimeStats.StarChance(stars)
	local S = cfgRoot().Stars
	local total = 0
	for s = 0, S.Max do
		total = total + (S.Weights[s] or 0)
	end
	return (S.Weights[stars] or 0) / total
end

-- ---------------------------------------------------------------- XP
function AnimeStats.XpToNext(level)
	local L = cfgRoot().Levels
	if level >= L.Max then return nil end
	return L.XpBase + L.XpPerLevel * level
end

-- Soma XP e sobe de nível quantas vezes der. Devolve quantos níveis subiu.
-- No nível máximo o XP fica em 0 (nada a acumular).
function AnimeStats.AddXP(entry, amount)
	local L = cfgRoot().Levels
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then return 0 end
	entry.Level = AnimeStats.Level(entry)
	entry.XP = math.max(0, tonumber(entry.XP) or 0) + math.floor(amount)
	local gained = 0
	while entry.Level < L.Max do
		local need = AnimeStats.XpToNext(entry.Level)
		if entry.XP < need then break end
		entry.XP = entry.XP - need
		entry.Level = entry.Level + 1
		gained = gained + 1
	end
	if entry.Level >= L.Max then entry.XP = 0 end
	return gained
end

-- ---------------------------------------------------------------- renda ($/s)
-- renda = base x mutação x tamanho (como já era) x estrelas x nível
function AnimeStats.Income(cfg, entry)
	if not cfg then return 0 end
	local root = cfgRoot()
	local mult = 1
	if entry.Mut and root.Mutations[entry.Mut] then
		mult = mult * root.Mutations[entry.Mut].Mult
	end
	if entry.Size and root.Sizes[entry.Size] then
		mult = mult * root.Sizes[entry.Size].Mult
	end
	mult = mult * AnimeStats.StarMult(AnimeStats.Stars(entry))
	mult = mult * AnimeStats.LevelMult(AnimeStats.Level(entry), root.Levels.IncomePerLevel)
	return cfg.Income * mult
end

-- ---------------------------------------------------------------- batalha
-- Poder = raridade x bioma x estrelas x nível x mutação x tamanho.
function AnimeStats.Power(cfg, entry)
	if not cfg then return 0 end
	local root = cfgRoot()
	local B = root.Battle
	local biome = root.BiomeById[cfg.Biome]
	local order = biome and biome.Order or 1 -- personagens Legacy de biomas que não existem mais contam como bioma 1
	local p = (B.RarityPower[cfg.Rarity] or B.RarityPower.Common) * (1 + B.BiomeStep * (order - 1))
	p = p * AnimeStats.StarMult(AnimeStats.Stars(entry))
	p = p * AnimeStats.LevelMult(AnimeStats.Level(entry), root.Levels.StatPerLevel)
	if entry.Mut and B.MutationPower[entry.Mut] then
		p = p * B.MutationPower[entry.Mut]
	end
	if entry.Size and B.SizePower[entry.Size] then
		p = p * B.SizePower[entry.Size]
	end
	return p
end

local STAT_KEYS = { "HP", "ATK", "DEF", "SPD", "ASPD", "POW" }
AnimeStats.StatKeys = STAT_KEYS

function AnimeStats.BattleStats(cfg, entry)
	local root = cfgRoot()
	local B = root.Battle
	local fighter = root.FighterOf(cfg.Id)
	local class = B.Classes[fighter.Class] or B.Classes[B.DefaultClass]
	local power = AnimeStats.Power(cfg, entry)
	local out = { Power = math.floor(power + 0.5), Class = fighter.Class, UltKind = class.UltKind, Ult = fighter.Ult, Fx = fighter.Fx }
	for _, key in ipairs(STAT_KEYS) do
		out[key] = math.floor(power * B.Base[key] * class[key] + 0.5)
	end
	return out
end

return AnimeStats
