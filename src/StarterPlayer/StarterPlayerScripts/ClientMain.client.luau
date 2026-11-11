--[[
	ClientMain: inicializa os módulos do cliente NA ORDEM correta (cada um isolado em pcall).
	Para adicionar uma tela/sistema: crie o ModuleScript em Client (com Init) e inclua o nome em ORDER.
	Beta 1.1: StartMenu por último (esconde o HUD e controla a câmera até a garagem ser escolhida).
	O sistema ANTIGO de captura (EncounterUI + AnimeNodes) só carrega com Config.Features.CaptureNodes = true.
]]
local StarterGui = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local Client = script.Parent:WaitForChild("Client")
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

local ORDER = { "State", "Notify", "DriveController", "CarVisuals", "HUD", "AtmosphereController", "AnimesPanel", "GaragePanel", "GiftPanel" }
if Config.Features.Eggs then
	table.insert(ORDER, "EggHatchUI")
	-- Beta 1.3: ovos de estrada e santuários ficam GUARDADOS (Config.Features.RoadEggs / .Shrines)
	if Config.Features.RoadEggs then table.insert(ORDER, "EggNodes") end
	if Config.Features.Shrines then table.insert(ORDER, "EggShop") end
end
-- Beta 1.3: ovo do fim do bioma (roleta + fuga com a pista desmoronando) e painel "My Garage"
if Config.Features.BiomeEggs then
	-- Beta 1.7: + GrabPromptUI (visual do prompt "segurar F" do ovo gigante)
	for _, n in ipairs({ "EggRouletteUI", "BiomeEggs", "EscapeFX", "GrabPromptUI" }) do table.insert(ORDER, n) end
end
table.insert(ORDER, "InventoryPanel")
-- Beta 1.4: vitrines do lobby (showroom / Hall of Heroes / lanternas / koi) e o dock flutuante com PLAY
-- Beta 1.5: WheelPanel (roleta) antes do dock, que tem o botão WHEEL
for _, n in ipairs({ "WheelPanel", "LobbyShowcase", "LobbyDock" }) do table.insert(ORDER, n) end
if Config.Features.CaptureNodes then
	for _, n in ipairs({ "EncounterUI", "AnimeNodes" }) do table.insert(ORDER, n) end
end
for _, n in ipairs({ "GhostController", "RaceUI" }) do table.insert(ORDER, n) end -- Beta 1.2: corrida solo
table.insert(ORDER, "HazardController") -- Beta 1.8: obstáculos animados (pêndulo, hélice, pistão, laser, gêiser)
table.insert(ORDER, "StartMenu")

for _, name in ipairs(ORDER) do
	local ok, mod = pcall(require, Client:WaitForChild(name))
	if not ok then
		warn("[Client] falha ao carregar " .. name .. ": " .. tostring(mod))
	elseif type(mod) == "table" and mod.Init then
		local ok2, err = pcall(mod.Init)
		if not ok2 then warn("[Client] falha ao iniciar " .. name .. ": " .. tostring(err)) end
	end
end
print("[Client] Drive A Car For Anime " .. Config.Version .. ": interface iniciada.")
