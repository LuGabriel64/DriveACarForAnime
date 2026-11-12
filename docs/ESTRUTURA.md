# Estrutura do jogo — Beta 1.8d

Mapa rápido de **onde está cada coisa** no Roblox Studio e do que cada script faz.
A documentação longa e oficial continua **dentro do place**, em `ServerStorage.ProjectDocs`.
Uma cópia está em `src/ServerStorage/ProjectDocs/`: `00_ProjectBible` (seções 10c a 10f valem por cima
das anteriores), `01_ChangeLog` e `02_AI_Protocol`.

## Explorer

```
ReplicatedStorage
├─ Shared/                  (src/ReplicatedStorage/Shared)
│  ├─ Config                ← FONTE ÚNICA de números e conteúdo (biomas, carros, raridades, ovos, roleta, fuga…)
│  ├─ Net                   ← única camada de rede (Net.Handle / Net.Call / Net.Fire)
│  ├─ Util, CarFactory, AnimeModelFactory (personagens "blocos anime" R6, Beta 1.8b)
└─ Remotes/ Action (RemoteFunction) + Event (RemoteEvent) — use SÓ via Shared.Net

ServerScriptService
├─ Main (Script)            ← inicia os serviços na ORDEM: Data, Farm, Car, Zone, Race, Egg, Incubator,
│                             Escape, Wheel, Anime, Gift (cada um em pcall)
└─ Services/
   ├─ DataService           perfil "P_<UserId>" no DataStore "DACFA_Player_v1", trava de sessão, migração v1→v2
   ├─ FarmService           garagens (Plot_1..8, nome interno antigo), 8 pedestais, renda $/s, vender/equipar
   ├─ CarService            spawn/sentar/descer, comprar carro, motor, lobby só a pé
   ├─ ZoneService           zona atual (lobby/start/bioma), bloqueio por tier, resgate de queda
   ├─ RaceService           corrida solo: slots 1..8 ("pista fantasma"), contagem, distância, recorde
   ├─ EscapeService         OVO GIGANTE no fim do bioma → roleta → FUGA (pista desmorona) → incubadora
   ├─ EggRoll               sorteio ponderado (biblioteca, sem Init)
   ├─ IncubatorService      choco por raridade em os.time() (conta offline)
   ├─ WheelService          roleta da sorte (8 h grátis + giros por Robux), ÚNICO ProcessReceipt do jogo
   ├─ EggService            ovos de estrada / santuários (GUARDADO: Features.RoadEggs/Shrines = false)
   ├─ AnimeService          captura por mini-jogo (GUARDADO: Features.CaptureNodes = false)
   └─ GiftService           presente grátis ($10K)

StarterPlayer.StarterPlayerScripts
├─ ClientMain (LocalScript) ← inicia os módulos do cliente na ordem (StartMenu por último)
└─ Client/                  UIKit (TODA a UI usa ele), State, Notify, HUD, StartMenu, LobbyDock, LobbyShowcase,
                            InventoryPanel ("My Garage"), GaragePanel (Car Shop), GiftPanel, WheelPanel,
                            DriveController (física do carro NO CLIENTE), CarVisuals, AtmosphereController,
                            RaceUI, GhostController, EggRouletteUI, BiomeEggs, EscapeFX, GrabPromptUI,
                            HazardController (obstáculos animados, Beta 1.8), EggHatchUI, AnimesPanel
                            (+ guardados: EggNodes, EggShop, EggVisuals, EncounterUI, AnimeNodes)

ServerStorage
├─ ProjectDocs/             Bíblia, ChangeLog, Protocolo de IA, Guia do Bioma 1
├─ Tools/WorldBuilder       gera terreno, lobby, biomas, obstáculos, hazards (2.411 linhas, ferramenta de EDIÇÃO)
├─ Tools/LobbyBuilder       design alternativo de outra sessão, NUNCA aplicado
├─ LegacyCode/              AnimeModelFactory voxel (1.6) e chibi (1.7)
└─ Backups/                 "Beta 1.1" (único com TERRENO), "Beta 1.6", "Beta 1.7", "Beta 1.8b" + LEIA-ME de restauração

Workspace
├─ Map/                     um só desde a Beta 1.8d (a cópia duplicada foi para Backups["Beta 1.8b"])
│  ├─ Drivable/<bioma>      pontes, passarelas, lombadas (o raycast do carro usa isto + Terrain)
│  ├─ Props/<bioma>         decoração, obstáculos, JapanTech (bioma 1), Hazards (Beta 1.8)
│  ├─ Plots/Plot_1..8       garagens (Base/Title/Label, Slots/Slot_N, Placed, CarPad, CarSpawn, PlayerSpawn)
│  ├─ Structures/           Lobby (Plaza, RaceGate, GarageRow, Showroom, HallOfHeroes…), StartLine, Gates, <bioma>
│  ├─ BoostPads/<bioma>, EggNodes/<bioma>, EggShrines/<bioma> (os 2 últimos vão para ServerStorage em jogo)
│  └─ BiomeEggs             criado pelo EscapeService ao iniciar o servidor
├─ Cars/                    um carro por jogador (CarService)
└─ Terrain                  pista + biomas (regerado pelo WorldBuilder; nunca editar à mão)
```

## Mundo (eixo -Z)

| # | Id | Nome | Tier | Comprimento | Carro do tier | Preço | Vel. máx |
|---|----|------|------|-------------|---------------|-------|----------|
| 1 | warrior | Azure Planet (elenco "DBZ-like", exceção do dono) | 1 | 3.200 | Starter Hatch | 0 | 70 |
| 2 | sakura | Sakura Valley | 2 | 3.700 | Sakura GT | 25K | 105 |
| 3 | dunes | Sunset Dunes | 3 | 4.200 | Dune Racer | 400K | 150 |
| 4 | tundra | Frozen Tundra | 4 | 4.600 | Frost Runner | 5M | 210 |
| 5 | volcano | Volcano Rift | 5 | 5.100 | Magma Reaper | 70M | 290 |
| 6 | city | Neon City | 6 | 5.600 | Neon Phantom | 1B | 390 |
| 7 | celestial | Celestial Peaks | 7 | 6.100 | Celestial Comet | 15B | 520 |

- **Lobby "Sakura Night":** ilha flutuante em (0, 0, 3200), só a pé, sem estrada até a pista.
- **Largada:** z = 40. A pista vai até z ≈ −32.500, com 704 studs de largura e estrada de 60 studs.
- **Raridades:** pesos 58.1, 23.2, 11.6, 5.2, 1.5, 0.23 e 0.03, normalizados para somar 100%.
  - Tempo de choco: 30 s, 1 min, 3 min, 5 min, 20 min, 1 h e 12 h.
  - A raridade Secret tem visual preto ("Void").
  - Mutações: Gold ×2 (6%) e Diamond ×5 (1,5%). Tamanho BIG ×1,5 (5%).

## Loop atual (desde a Beta 1.3)

1. O jogador escolhe a garagem no lobby.
2. Aperta PLAY (dock) e vai ao grid, com contagem de 3 s.
3. Dirige até o ovo gigante no fim do bioma e **segura F**.
4. O servidor sorteia o personagem e a roleta mostra o resultado.
5. A pista **desmorona** atrás do carro. Se o jogador cruzar a largada, o ovo vai para a **incubadora** (6 vagas).
6. O ovo choca e o personagem vai para um pedestal da garagem, onde gera $/s.
7. Com o dinheiro, o jogador compra um carro de tier maior, que abre o próximo bioma.

Extras: roleta da sorte (8 h), obstáculos animados (Beta 1.8, só visuais, a punição é o `Drive.Hit`),
pads de lentidão e passarelas.

## Rede (ações `Net.Call` → servidor)

GetState, GetGarages, ClaimGarage, DriveCar, ExitCar, BuyCar, EquipCar, UpgradeEngine, ResetCar, StartRace,
EndRace, GoHome, PlaceAnime, PickUpAnime, SellAnime, EquipBest, GetIncubator, GetWheel, SpinWheel, WheelPack,
ClaimGift, SaveSettings. As ações guardadas são CollectRoadEgg, BuyEgg, StartEncounter e ResolveEncounter.

## Regras de ouro (resumo do `02_AI_Protocol`)

1. Ler o ChangeLog e o cabeçalho do módulo antes de editar.
2. Balanceamento só no `Config`.
3. Não renomear chaves públicas: Config, ações do Net, atributos e campos salvos.
4. O cliente pede e o servidor valida.
5. A UI usa o UIKit, com textos em inglês e comentários em português.
6. Mudou o schema? Atualize `defaults()`, `reconcile()` e `migrate()`.
7. **Nunca** dar `require` em `Services.*` pelo Command Bar durante o Play: isso derruba o Net com "UnknownAction".
8. O mapa sai sempre do WorldBuilder, nunca de edição à mão.
9. Fazer backup antes de cada versão grande.
10. Propriedade intelectual: só personagens originais. A única exceção é o elenco do bioma 1, decidido pelo dono.
