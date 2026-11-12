--[=[
================================================================================
 DRIVE A CAR FOR ANIME — ESTADO ATUAL (Beta 1.8d, 12/11/2026)
 PORTA DE ENTRADA para QUALQUER assistente (Claude, Claude Code do amigo, Roblox Assistant, Rebirth).
 Leia ESTE arquivo primeiro; depois 02_AI_Protocol (regras), 01_ChangeLog (histórico, mais novo no topo)
 e 00_ProjectBible (visão + seções 10b..10f). Onde houver conflito, vale o texto MAIS NOVO.
================================================================================

1. O JOGO EM 1 PARÁGRAFO
   Lobby noturno "Sakura Night" (a pé) -> PLAY -> corrida solo numa pista compartilhada ("pista fantasma",
   cada jogador no seu SLOT 1..8) que atravessa 7 biomas no eixo -Z -> no FIM de cada bioma há um OVO GIGANTE
   -> segurar F (GrabPromptUI) -> ROLETA de raridade -> a pista DESMORONA atrás do carro (velocidade cresce com
   o carro do jogador) -> cruzar a largada = ovo vai para a INCUBADORA -> choca (30 s .. 12 h) -> personagem vai
   para a GARAGEM (8 pedestais) e rende $/s -> dinheiro compra carros (Tier N abre o bioma N) e motor.
   Extra: Roleta da Sorte na UI (1 giro grátis/8 h + giros extras + pacotes por Robux).

2. ONDE CADA COISA FICA (o que cada script faz)
   ReplicatedStorage.Shared
     Config ............ TODO número/conteúdo: Biomes, Animes (71 entradas, bioma 1 com nomes alterados), Cars,
                         Rarities (Secret = PRETO/Void), Escape, Incubator, Wheel (Prizes/Packs), Track (Hazards,
                         Boost, SlowPad, Skyway), Lobby, Race, Features (liga/desliga sistemas), Updates, Version.
     Net ............... ÚNICO caminho de rede (Remotes.Action RemoteFunction + Remotes.Event RemoteEvent).
     AnimeModelFactory . personagens procedurais estilo "BLOCOS ANIME" (Beta 1.8b). Antigos em ServerStorage.LegacyCode.
     CarFactory / Util . modelo do carro / utilidades.
   ServerScriptService
     Main .............. inicia serviços na ORDER (cada um em pcall) + Net "GetState".
     Services.DataService ....... DataStore "P_<UserId>" com trava de sessão, defaults/reconcile/migrate (Version 2),
                                  SaveNow/SaveSync, leaderstats.Cash.
     Services.FarmService ....... garagens (Plot_N), personagens colocados, renda/s, EquipBest, venda.
     Services.CarService ........ carro estacionado, DriveCar/ExitCar, compra/upgrade; lobby só a pé.
     Services.ZoneService ....... bioma atual por Z (atributo Biome), zonas lobby/start.
     Services.RaceService ....... StartRace/EndRace/GoHome, slots, contagem, distância/recorde (anti-trapaça 1.8d).
     Services.EscapeService ..... ovos gigantes (Map.BiomeEggs em runtime), GrabPrompt F, sorteio, frente do colapso.
                                  Anti-trapaça de velocidade dos dois: Config.AntiCheat (orçamento = TopSpeed x 1,6).
     Services.EggRoll ........... sorteio ponderado (biblioteca, sem Init).
     Services.IncubatorService .. choco por os.time (conta offline) -> FarmService.AddAnime.
     Services.WheelService ...... roleta: GetWheel/SpinWheel/WheelPack, Tokens, ProcessReceipt idempotente.
     Services.EggService / AnimeService / GiftService ... sistemas GUARDADOS ou pequenos (ver Features).
   StarterPlayer.StarterPlayerScripts
     ClientMain ........ carrega os módulos de Client na ORDER (depende de Config.Features).
     Client.UIKit ...... TODA UI passa por aqui (painéis, botões, Viewport, RarityLabel/Void...).
     Client.StartMenu .. tela inicial + escolha de garagem (controla a câmera até escolher).
     Client.LobbyDock .. dock GARAGE/INVENTORY/PLAY/SHOP/GIFT/WHEEL + cortina "TO THE TRACK!".
     Client.LobbyShowcase  giratórios do showroom, Hall of Heroes, lanternas (atributo Home), koi.
     Client.DriveController física do carro por raycast, boost/slow/hit (Drive.Hit, IsSlowed).
     Client.HazardController obstáculos animados pelo relógio do servidor + batida segmento x caixa.
     Client.BiomeEggs / GrabPromptUI / EggRouletteUI / EscapeFX ... ovo gigante, prompt F, roleta, colapso visual.
     Client.InventoryPanel ("My Garage"), WheelPanel, HUD, RaceUI, GhostController, AtmosphereController, Notify, State.
   ServerStorage
     ProjectDocs ....... 00 Bíblia | 01 ChangeLog | 02 Protocolo IA | 03 Guia Bioma 1 | 04 ESTE arquivo.
     Tools.WorldBuilder  gera terreno/mapa/lobby/obstáculos (ferramenta de EDIÇÃO, determinística).
     Tools.LobbyBuilder  lobby alternativo antigo, NÃO aplicado.
     Backups ........... "Beta 1.1" (único com TERRENO), "Beta 1.6", "Beta 1.7", "Beta 1.8b" (scripts + o Map que
                         estava duplicado + sobras da limpeza da 1.8d).
     LegacyCode ........ AnimeModelFactory Voxel (1.6) e Chibi (1.7).
   Workspace.Map
     Drivable (rampas/pontes/passarelas por bioma) | Props.<bioma> (decoração, JapanTech, Hazards) | Plots (Plot_1..8)
     | Structures (Lobby, StartLine, portões) | BoostPads | EggNodes/EggShrines (guardados; vão p/ DisabledAtRuntime).
   StarterGui fica VAZIO de propósito: a UI é criada por código.
   Workspace (1.8d): Cars, Map, Terrain, SpawnLocation, Camera — UM de cada. Lighting: só o "Simple Sunset Sky".
   Ao contar tags no servidor, filtre IsDescendantOf(workspace): os Backups também têm peças com tag.

3. REDE (Net)
   Ações (cliente -> servidor): GetState, GetGarages, ClaimGarage, PlaceAnime, PickUpAnime, SellAnime, EquipBest,
     DriveCar, ExitCar, BuyCar, EquipCar, UpgradeEngine, ResetCar, StartRace, EndRace, GoHome, GetIncubator,
     GetWheel, SpinWheel, WheelPack, SaveSettings, ClaimGift (+ guardadas: BuyEgg, CollectRoadEgg, StartEncounter,
     ResolveEncounter).
   Eventos (servidor -> cliente): Inventory, CarState, BiomeChanged, GaragesChanged, RaceCountdown, RaceGo,
     RaceEnded, EggRoulette, EscapeResult, Incubator, Hatched, Toast.
   O ovo gigante NÃO usa Net: é um ProximityPrompt (GrabPrompt) tratado no EscapeService.

4. FEATURES (Config.Features) — sistemas guardados, NÃO apagar
   Eggs=true, BiomeEggs=true, StartMenu=true, LobbyDock=true | CaptureNodes=false, RoadEggs=false, Shrines=false.

5. PEGADINHAS TÉCNICAS (já custaram horas)
   - NUNCA require() de Services pelo Command Bar/MCP durante o Play (recria o Net => "UnknownAction"). Reinicie o Play.
   - Cache de require no EDITOR: clone o Config antes de rodar o WorldBuilder (ver 02_AI_Protocol regra 15).
   - StreamingEnabled = true: Model pode chegar ANTES das peças. Guarde posição em atributo (ex.: Home) e use
     ModelStreamingMode Atomic em modelos animados.
   - screen_capture não mostra BillboardGui em Play; CanvasGroup dentro de BillboardGui não renderiza.
   - Robux: ProcessReceipt tem que ser idempotente e salvar ANTES de PurchaseGranted.
   - Obstáculos (tag Hazard) não têm colisão: o castigo é Drive.Hit no cliente.

6. PENDENTE (dono)
   - Criar 2 Developer Products (x3 Spins R$29, x10 Spins R$79) e pôr os IDs em Config.Wheel.Packs[i].ProductId.
   - Sons (Config.Sounds vazio), nomes em Config.Credits, botão Index.
   - Testar DataStore no servidor publicado (Studio sem API).
   - PUBLICAR a Beta 1.8d (o Studio só salvou; jogadores ainda veem a 1.8b).

7. COMO TRABALHAR (resumo do 02_AI_Protocol)
   Ler antes de escrever -> mudanças grandes = BACKUP em ServerStorage.Backups["Beta X.Y"] + Version/Updates no
   Config -> nova entrada NO TOPO do 01_ChangeLog (Date, Author = qual assistente/pessoa, Version, Summary, Files,
   Notes com o que foi TESTADO e o que NÃO foi) -> atualizar este arquivo se a estrutura mudar.
   Comentários em português; textos da UI do jogador em inglês. Personagens/nomes sem marcas registradas.
]=]
return true
