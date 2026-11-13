--[[
	ProgressService  (ServerScriptService.Services.ProgressService)                              Beta 1.9
	=====================================================================================================
	XP, NÍVEL e PARCEIRO dos personagens. As contas ficam em Shared.AnimeStats (puras); aqui só mexemos
	no save do jogador e avisamos o cliente.

	  * AddXP(player, uid, amount) : soma XP num personagem do jogador (nível máximo 50). Se subir de nível,
	    a renda e os status mudam => FarmService.Refresh recalcula a renda, a placa do pedestal e a mochila.
	  * PARCEIRO (data.Partner = Uid): o personagem que ganha o XP das CORRIDAS 1v1 (na batalha, quem ganha
	    XP é o lutador usado). Sem parceiro escolhido (ou vendido), vale o personagem de maior Poder.

	REDE : "SetPartner"(uid) -> { ok } | evento "LevelUp"({ Uid, Name, Level, LevelsGained })
	ATRIBUTO do Player: Partner (Uid; 0 = automático)
	API  : AddXP(player, uid, amount) -> { Name, Level, LevelsGained } | nil
	       PartnerUid(player) -> Uid | nil        FindEntry(player, uid) -> entry, cfg
	DEPENDÊNCIAS: DataService, FarmService (Refresh / Sync), Shared.AnimeStats.
]]
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local AnimeStats = require(Shared.AnimeStats)
local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)

local ProgressService = {}

local function findEntry(data, uid)
	for _, e in ipairs(data.Animes) do
		if e.Uid == uid then return e end
	end
	return nil
end

-- Personagem do jogador pelo Uid (e a ficha dele no Config). nil se não for dele.
function ProgressService.FindEntry(player, uid)
	local data = DataService.Get(player)
	local entry = data and type(uid) == "number" and findEntry(data, uid)
	if not entry then return nil end
	return entry, Config.AnimeById[entry.Id]
end

-- Uid do personagem de maior Poder (nil se o jogador não tem nenhum).
function ProgressService.StrongestUid(player)
	local data = DataService.Get(player)
	if not data then return nil end
	local best, bestPower = nil, -1
	for _, e in ipairs(data.Animes) do
		local cfg = Config.AnimeById[e.Id]
		local power = cfg and AnimeStats.Power(cfg, e) or -1
		if power > bestPower then best, bestPower = e.Uid, power end
	end
	return best
end

function ProgressService.PartnerUid(player)
	local data = DataService.Get(player)
	if not data then return nil end
	if data.Partner and findEntry(data, data.Partner) then return data.Partner end
	return ProgressService.StrongestUid(player) -- sem parceiro escolhido (ou ele foi vendido)
end

function ProgressService.AddXP(player, uid, amount)
	local data = DataService.Get(player)
	local entry = data and findEntry(data, uid)
	local cfg = entry and Config.AnimeById[entry.Id]
	if not cfg then return nil end
	local gained = AnimeStats.AddXP(entry, amount)
	if gained > 0 then
		FarmService.Refresh(player) -- renda + placas dos pedestais + mochila
		Net.Fire(player, "LevelUp", { Uid = uid, Name = cfg.Name, Level = entry.Level, LevelsGained = gained })
	else
		FarmService.Sync(player) -- só a barra de XP na mochila
	end
	return { Name = cfg.Name, Level = entry.Level, LevelsGained = gained }
end

function ProgressService.Init()
	Net.Handle("SetPartner", function(player, uid)
		local data = DataService.Get(player)
		if not data or type(uid) ~= "number" then return { ok = false } end
		if not findEntry(data, uid) then return { ok = false, err = "Invalid" } end
		data.Partner = uid
		player:SetAttribute("Partner", uid)
		return { ok = true }
	end, 0.3)
	DataService.OnLoaded(function(player, data)
		player:SetAttribute("Partner", data.Partner or 0)
	end)
end

return ProgressService
