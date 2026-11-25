---
title: Mapa de scripts
date: 2026-11-14
tags: [codigo, referencia]
---

# Mapa de scripts (Beta 1.9)

Caminho no repositório: `src/` espelha o Explorer.

## ReplicatedStorage.Shared
| Script | Papel |
|--------|-------|
| Config | **fonte única** de números e conteúdo; no fim aplica `ConfigBeta19` |
| ConfigBeta19 | números da 1.9 (Stars, Levels, Wheel.Points, Languages, Music, Versus, F1Cars, Battle) |
| Net | única camada de rede |
| Util | utilidades |
| CarFactory | modelo do carro (+ corpo f1) |
| AnimeModelFactory | personagens blocos anime |
| AnimeStats | estrelas, nível, XP, renda, Poder, status de batalha |
| CharacterRig (Beta 2.0) | anima personagens de malha por peças rígidas: `Rig.Play(model, id)`; ainda sem uso no jogo → [nota](../05_Modelagem/Animacao_Idle_CharacterRig.md) |
| CharacterAnims (Beta 2.0) | dados das animações de parado (gerado por `tools/art/anims_to_luau.js`) |
| Locale (+ pt) | tradução |

## ServerScriptService.Services
DataService (save) · FarmService (garagens, renda) · CarService (carro, compra, F1) · ZoneService (zona/bioma,
tier, resgate de queda) · RaceService (corrida solo e Duel) · EscapeService (ovo gigante e fuga) · EggRoll
(sorteio, lib) · IncubatorService · WheelService (roleta, Robux, pontos) · EggService (guardado) · AnimeService
(guardado) · GiftService (presente $10K) · DevService (painel DEV, 2.0b) · ProgressService (XP, parceiro) · VersusService (desafio) ·
DuelRaceService (corrida 1v1) · BattleSim (lib) · BattleService (batalha).

## StarterPlayerScripts.Client
UIKit · State · Notify · HUD · StartMenu · LobbyDock · LobbyShowcase · InventoryPanel · GaragePanel ·
GiftPanel · WheelPanel · DriveController · CarVisuals · AtmosphereController · RaceUI · GhostController ·
EggRouletteUI · BiomeEggs · EscapeFX · GrabPromptUI · HazardController · EggHatchUI · AnimesPanel ·
1.9: Platform · VersusUI · DuelRaceUI · BattleUI · MusicController · guardados: EggNodes, EggShop,
EggVisuals, EncounterUI, AnimeNodes.

## ServerStorage
ProjectDocs (00–04) · Tools (WorldBuilder, LobbyBuilder, VersusBuilder, MirrorDump) · LegacyCode ·
Backups ("Beta 1.1" único com terreno, "1.6", "1.7", "1.8b", "1.8d").

## Repositório
`tools/place/place_tool.py` + `rbxl.py` (extrai `.rbxl`, precisa de Python) · `tools/place/mirror_from_dump.js`
(espelho sem Python, Node) · `planejamento/beta-1.9/testes/` (80 verificações de lógica em Lua 5.4).

Relacionado: [Arquitetura](Arquitetura.md) · [Hierarquia de telas](../04_UI_UX/Hierarquia_de_Telas.md) · [Rede (Net)](../02_Sistemas/Rede_Net.md)
