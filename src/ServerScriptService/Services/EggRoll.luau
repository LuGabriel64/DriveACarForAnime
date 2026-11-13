--[[
	EggRoll (Beta 1.3): SORTEIO PONDERADO dos ovos — roda SÓ no servidor.
	  Roll(biomeId, luck) -> { Id, Mut, Size, Odds }   (Odds = "1 in N" mostrado na revelação)
	  Odds(biomeId)       -> mesma tabela que a UI mostra (Config.EggOdds, sem sorte)

	POR QUE É IMUNE A EXPLOIT
	  * Fica em ServerScriptService: o cliente não enxerga nem consegue dar require neste módulo.
	  * Usa um objeto Random próprio (semente da entropia do motor), nunca exposto ao cliente.
	  * O cliente não manda NENHUM número que entre no sorteio: o bioma vem do ovo físico validado pelo
	    servidor (EscapeService) e a sorte é sempre definida no servidor.
	  * Os pesos vêm de Config.Rarities (fonte única). Config.EggOdds normaliza pelo total (99,86).
	Usado por: EscapeService (ovo do bioma) e EggService (sistema antigo, guardado).
	Não tem Init: não precisa entrar no ORDER do Main.
	Beta 1.9: Roll devolve também Stars (0..5), sorteadas AQUI com o mesmo Random do servidor (pesos em
	  Config.Stars.Weights; conta em Shared.AnimeStats.RollStars). As estrelas NÃO entram no "1 in N" (Odds).
]]
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local AnimeStats = require(RS.Shared:WaitForChild("AnimeStats"))

local EggRoll = {}
local rng = Random.new()

function EggRoll.Odds(biomeId) return Config.EggOdds(biomeId, 1) end

-- Sorteio acumulado: r em [0,1) cai na faixa de um personagem (faixas proporcionais às chances)
function EggRoll.Anime(biomeId, luck)
	local odds = Config.EggOdds(biomeId, luck or 1)
	if #odds == 0 then return nil end
	local r, acc = rng:NextNumber(), 0
	for _, row in ipairs(odds) do
		acc += row.Chance
		if r < acc then return row.Anime end
	end
	return odds[#odds].Anime -- arredondamento de ponto flutuante
end

function EggRoll.Mutation()
	local r, acc = rng:NextNumber(), 0
	for _, name in ipairs(Config.MutationOrder) do
		local c = Config.Mutations[name].Chance
		acc += c
		if r < acc then return name, c end
	end
	return nil, 1 - acc
end

function EggRoll.Size()
	for name, def in pairs(Config.Sizes) do
		if rng:NextNumber() < def.Chance then return name, def.Chance end
	end
	local none = 1
	for _, def in pairs(Config.Sizes) do none -= def.Chance end
	return nil, none
end

-- chance BASE (sem sorte) de um personagem no ovo do bioma (cache)
local base = {}
function EggRoll.Chance(biomeId, animeId)
	base[biomeId] = base[biomeId] or {}
	local t = base[biomeId]
	if t[animeId] == nil then
		for _, row in ipairs(Config.EggOdds(biomeId, 1)) do t[row.Anime.Id] = row.Chance end
	end
	return t[animeId] or 1
end

function EggRoll.Roll(biomeId, luck)
	local cfg = EggRoll.Anime(biomeId, luck)
	if not cfg then return nil end
	local mut, pMut = EggRoll.Mutation()
	local size, pSize = EggRoll.Size()
	local odds = math.max(1, math.floor(1 / (EggRoll.Chance(biomeId, cfg.Id) * pMut * pSize) + 0.5))
	return { Id = cfg.Id, Mut = mut, Size = size, Odds = odds, Stars = AnimeStats.RollStars(rng:NextNumber()) }
end

return EggRoll
