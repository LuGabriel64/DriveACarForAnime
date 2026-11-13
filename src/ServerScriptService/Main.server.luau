--[[
	Main: inicializa os serviços do servidor NA ORDEM correta.
	Para adicionar um serviço: crie o ModuleScript em Services (com função Init) e inclua o nome em ORDER.
	Cada serviço isolado em pcall: se um falhar, os demais continuam e o erro aparece no Output.
]]
local RS = game:GetService("ReplicatedStorage")
local Services = script.Parent:WaitForChild("Services")
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))

-- AnimeService = sistema de CAPTURA (guardado; só registra ações, sem pontos no mapa ele fica inerte).
-- Beta 1.3: IncubatorService (choco na base) e EscapeService (ovo do bioma + fuga). EggRoll é biblioteca (sem Init).
local ORDER = { "DataService", "FarmService", "CarService", "ZoneService", "RaceService", "EggService", "IncubatorService", "EscapeService", "WheelService",
	"ProgressService", -- Beta 1.9: XP / nível / parceiro dos personagens
	"VersusService", "DuelRaceService", "BattleService", -- Beta 1.9: desafio 1v1 (convite/etapas), corrida 1v1 e batalha de anime
	"AnimeService", "GiftService" } -- Beta 1.5: + WheelService (roleta)
local loaded = {}
for _, name in ipairs(ORDER) do
	local ok, mod = pcall(require, Services[name])
	if ok then loaded[name] = mod else warn("[Main] falha ao carregar " .. name .. ": " .. tostring(mod)) end
end
for _, name in ipairs(ORDER) do
	local m = loaded[name]
	if m and m.Init then
		local ok, err = pcall(m.Init)
		if not ok then warn("[Main] falha ao iniciar " .. name .. ": " .. tostring(err)) end
	end
end

-- O cliente chama isso ao abrir o jogo para receber o estado atual (eventos anteriores se perdem).
Net.Handle("GetState", function(player)
	if loaded.DataService then loaded.DataService.WaitFor(player) end
	if loaded.FarmService then loaded.FarmService.Sync(player) end
	if loaded.CarService then loaded.CarService.SendState(player) end
	return { ok = true }
end, 0.5)

print("[Main] Drive A Car For Anime: serviços iniciados.")
