--[[
	IncubatorService (Beta 1.3): os ovos salvos na FUGA chocam NA BASE.
	  * Cada ovo entregue entra em data.Incubator com ReadyAt = os.time() + Config.Rarities[raridade].HatchSeconds
	    (Common 30s | Uncommon 1min | Rare 3min | Epic 5min | Legendary 20min | Mythic 1h | Secret 12h).
	  * os.time() é hora UNIX do servidor: o tempo conta OFFLINE e o cliente não consegue acelerar nada.
	  * Pronto => FarmService.AddAnime (vai para a garagem/mochila, conforme AutoPlace) + evento "Hatched".
	  * Salvo pelo DataService junto com o resto do perfil (autosave + saída + BindToClose, com trava de sessão).
	API (servidor): Add(player, biomeId, roll) -> entry | nil, err   |   IsFull(player)   |   Push(player)
	Rede: ação "GetIncubator" -> { ok, Slots, List, Now }   |   eventos "Incubator"(state) e "Hatched"(info)
	Atributos do Player: IncubatorUsed, IncubatorSlots
	Dependências: DataService, FarmService, Config.Incubator / Config.Rarities
	Beta 1.9: cada ovo guarda Stars (0..5, sorteadas no EggRoll) e repassa ao FarmService.AddAnime ao chocar.
	  Ovos antigos (sem o campo) chocam com 0 estrelas.
]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)

local IncubatorService = {}

local function slots() return Config.Incubator.Slots end

local function stateOf(data)
	local list = {}
	for _, e in ipairs(data.Incubator) do
		list[#list + 1] = { IncId = e.IncId, Biome = e.Biome, Id = e.Id, Mut = e.Mut, Size = e.Size, Odds = e.Odds,
			Stars = e.Stars or 0, Start = e.Start, ReadyAt = e.ReadyAt }
	end
	return { Slots = slots(), List = list, Now = os.time() }
end

function IncubatorService.Push(player)
	local data = DataService.Get(player); if not data then return end
	player:SetAttribute("IncubatorUsed", #data.Incubator)
	player:SetAttribute("IncubatorSlots", slots())
	Net.Fire(player, "Incubator", stateOf(data))
end

function IncubatorService.IsFull(player)
	local data = DataService.Get(player)
	return (not data) or #data.Incubator >= slots()
end

-- roll = { Id, Mut, Size, Odds } vindo do EggRoll (servidor). Nunca aceita dados do cliente.
function IncubatorService.Add(player, biomeId, roll)
	local data = DataService.Get(player)
	if not data then return nil, "NoData" end
	local cfg = roll and Config.AnimeById[roll.Id]
	if not cfg then return nil, "Invalid" end
	if #data.Incubator >= slots() then return nil, "Full" end
	local now = os.time()
	local entry = { IncId = data.NextIncId, Biome = biomeId, Id = roll.Id, Mut = roll.Mut, Size = roll.Size, Odds = roll.Odds,
		Stars = math.clamp(math.floor(tonumber(roll.Stars) or 0), 0, Config.Stars.Max), Start = now, ReadyAt = now + (Config.Rarities[cfg.Rarity].HatchSeconds or 30) }
	data.NextIncId += 1
	table.insert(data.Incubator, entry)
	IncubatorService.Push(player)
	return entry
end

local function hatch(player, data, index)
	local e = table.remove(data.Incubator, index)
	if not e or not Config.AnimeById[e.Id] then return end -- personagem removido do Config: descarta
	local entry, placed = FarmService.AddAnime(player, e.Id, e.Mut, e.Size, e.Stars)
	if not entry then table.insert(data.Incubator, index, e); return end -- tenta de novo no próximo ciclo
	data.Stats.Hatches = (data.Stats.Hatches or 0) + 1
	Net.Fire(player, "Hatched", { Id = e.Id, Mut = e.Mut, Size = e.Size, Odds = e.Odds, Placed = placed, Stars = entry.Stars or 0,
		Income = FarmService.IncomeOf(entry), Biome = e.Biome })
end

function IncubatorService.Init()
	DataService.OnLoaded(function(player) IncubatorService.Push(player) end)

	Net.Handle("GetIncubator", function(player)
		local data = DataService.Get(player)
		if not data then return { ok = false } end
		local s = stateOf(data)
		s.ok = true
		return s
	end, 0.5)

	-- relógio da incubadora (1x por segundo). Ovos que ficaram prontos OFFLINE chocam assim que o perfil carrega.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.Get(player)
				if data and #data.Incubator > 0 then
					local changed = false
					for i = #data.Incubator, 1, -1 do
						if (data.Incubator[i].ReadyAt or 0) <= now then
							local ok, err = pcall(hatch, player, data, i)
							if not ok then warn("[IncubatorService] " .. tostring(err)) end
							changed = true
						end
					end
					if changed then IncubatorService.Push(player) end
				end
			end
		end
	end)
end

return IncubatorService
