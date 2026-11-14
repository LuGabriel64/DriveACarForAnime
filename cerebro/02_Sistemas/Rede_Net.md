---
title: Rede (Net)
date: 2026-11-14
tags: [sistema, rede, codigo]
aliases: [Net, Shared.Net, Remotes]
---

# Rede (Net)

`Shared.Net` é o **único** caminho de rede: `Remotes.Action` (RemoteFunction) e `Remotes.Event` (RemoteEvent).
Servidor: `Net.Handle(nome, fn)` e `Net.Fire(player, evento, ...)`. Cliente: `Net.Call(nome, ...)` e `Net.On(evento, fn)`.
Tem rate limit por ação, `pcall` em todo handler e validação de tipo em cada ação.

## Ações (cliente → servidor)
- **Base:** GetState, GetGarages, ClaimGarage, PlaceAnime, PickUpAnime, SellAnime, EquipBest, DriveCar, ExitCar,
  BuyCar, EquipCar, UpgradeEngine, ResetCar, StartRace, EndRace, GoHome, GetIncubator, GetWheel, SpinWheel,
  WheelPack, SaveSettings, ClaimGift.
- **Beta 1.9:** SetLanguage, SetPartner, VersusPlayers, VersusInvite, VersusRespond, VersusCancel, VersusReady,
  VersusVote, VersusLeave, GetVersusShop, BuyF1, EquipF1, BuyVictoryFx, EquipVictoryFx, PickFighter.
- **Guardadas:** CollectRoadEgg, BuyEgg, StartEncounter, ResolveEncounter.

## Eventos (servidor → cliente)
Inventory, CarState, BiomeChanged, GaragesChanged, RaceCountdown, RaceGo, RaceEnded, EggRoulette, EscapeResult,
Incubator, Hatched, Toast · 1.9: VersusInvited, VersusInviteClosed, VersusState, VersusResult, DuelStart, DuelEnd,
BattleScript, BattleAbort, LevelUp.

O ovo gigante **não** usa Net: é um ProximityPrompt (`GrabPrompt`) tratado no EscapeService.

## Atributos do Player (replicados)
Cash, CashPerSec, CarId, CarTier, TopSpeed, EngineLevel, PlotSlots, PlotUsed, GiftClaimed, Biome, Garage,
Set_SFX/FOV/LowGfx/AutoPlace/Music, RaceState, RaceSlot, RaceDistance, RaceBest, EscapeState/Biome/EggZ/FrontZ0/
FrontStart/Speed, IncubatorUsed/Slots, WheelNextAt, WheelTokens · 1.9: MatchId, VersusMode, VersusStage, RaceMode,
CollapseDir/Z0/Start/Speed, WheelPoints, Lang, Partner, F1Equipped, FxEquipped, FighterUid, F1.

> [!WARNING]
> **Nunca** dê `require` em `ServerScriptService.Services.*` pelo Command Bar ou MCP durante o Play: cria um
> segundo Net que sobrescreve `Action.OnServerInvoke` e tudo vira "UnknownAction". No cliente é seguro chamar
> `Remotes.Action:InvokeServer(...)`.

Relacionado: [Arquitetura](../06_Codigo/Arquitetura.md) · [Anti-trapaça](Anti_Trapaca.md) · [Pegadinhas técnicas](../09_Erros_e_Licoes/Pegadinhas_Tecnicas.md) · [Mapa de scripts](../06_Codigo/Mapa_de_Scripts.md)
