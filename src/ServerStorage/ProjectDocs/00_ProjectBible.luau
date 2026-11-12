--[=[
================================================================================
 DRIVE A CAR FOR ANIME — BÍBLIA DO PROJETO  Beta 1.4  (leia ANTES de editar qualquer coisa)
================================================================================
 >>> RESUMO ATUALIZADO (Beta 1.8b+): ServerStorage.ProjectDocs.04_EstadoAtual. As seções abaixo são a história
     até a Beta 1.4; o que mudou depois (roleta, obstáculos, estilo dos personagens...) está no 04 e no 01_ChangeLog.

1. VISÃO
   O jogador começa com um carro e dirige por BIOMAS grandes e cheios de obstáculos
   (curvas, rampas, boost pads, colinas). Ao longo do caminho encontra pontos brilhantes
   com ANIMES (personagens originais). Captura-os num mini-jogo de timing; os animes vão
   para a GARAGEM do jogador (8 pedestais, 4 de cada lado) e pagam $/s. O dinheiro compra carros melhores (que liberam novos
   biomas) e upgrades de motor. Referências de gênero: Steal an Egg, Throw a Food for
   Animals, Kick a Lucky Block.

2. PILARES DE DESIGN (dopamina rápida, mas com profundidade)
   - Recompensa a cada ~10s: ponto de captura -> mini-jogo -> revelação "1 in N".
   - Raridade + mutações (Gold x2, Diamond x5) + tamanho BIG (x1.5) = "caça ao lendário".
   - Renda passiva visível (números subindo) + "EQUIP BEST" de 1 toque.
   - Progressão clara: carro Tier N destrava bioma N (portão com "Requires Tier N car").
   - Velocidade tem que SER SENTIDA: FOV dinâmico, boost pads, rampas, velocímetro.
   - Mobile-first: UI grande, toque único, sem teclado obrigatório.

3. LOOP
   Dirigir -> capturar -> (auto) colocar na garagem -> renda -> comprar carro/motor ->
   novo bioma (animes melhores) -> repetir. (Futuro: rebirth, eventos, trade, pets de carro.)

4. ARQUITETURA (pastas)
   ReplicatedStorage.Shared      Config (TUDO de balanceamento), Util, Net, CarFactory, AnimeModelFactory
   ReplicatedStorage.Remotes     Action (RemoteFunction) + Event (RemoteEvent) — usados SÓ via Shared.Net
   ServerScriptService.Main      inicia os serviços em ordem
   ServerScriptService.Services  DataService, FarmService, CarService, ZoneService, AnimeService, GiftService
   StarterPlayerScripts.ClientMain + .Client (UIKit, State, Notify, HUD, AnimesPanel, GaragePanel, GiftPanel,
                                   EncounterUI, DriveController, CarVisuals, AnimeNodes)
   ServerStorage.Tools.WorldBuilder   gera terreno/mapa (ferramenta de EDIÇÃO)
   ServerStorage.ProjectDocs     esta documentação
   Workspace.Map                 Drivable (rampas/pontes/lombadas, por bioma), Props (decoração + obstáculos sólidos,
                                 por bioma), Plots (8 GARAGENS "Plot_1..8"), Structures (arcos/portões/placas),
                                 AnimeSpawns (tag "AnimeSpawn"), BoostPads (tag "BoostPad"). Zonas de gelo: tag "IceZone".
                                 (As garagens mantêm o nome interno "Plot_N" e o FarmService mantém o nome por
                                 compatibilidade; na UI tudo se chama "Garage".)
   Workspace.Cars                um carro por jogador (criado pelo CarService)

5. REDE (Shared.Net)  — cliente nunca decide resultado; servidor valida tudo
   (Beta 1.2 adicionou: StartRace, EndRace | eventos RaceCountdown, RaceGo, RaceEnded; GoHome agora é do RaceService)
   Cliente -> Servidor (Net.Call):  GetState, PlaceAnime, PickUpAnime, SellAnime, EquipBest, BuyCar, EquipCar,
                                    UpgradeEngine, ResetCar, GoHome, StartEncounter, ResolveEncounter, ClaimGift
   Servidor -> Cliente (Net.Fire):  Inventory, CarState, BiomeChanged, Toast
   Atributos do Player (replicados): Cash, CashPerSec, CarId, CarTier, TopSpeed, EngineLevel, PlotSlots,
                                     PlotUsed, GiftClaimed, Biome

6. DADOS SALVOS (DataService, chave "P_<UserId>", com trava de sessão)
   Cash, CarId, Cars{[id]={Engine}}, Animes[{Uid,Id,Mut,Size,Placed,Slot}], NextUid, PlotSlots,
   GiftClaimed, Index{[animeId]=true}, Stats{Captures,BestBiome,PlayTime}
   Mudou o formato? Aumente Version e faça migração em reconcile(); NUNCA troque StoreName sem querer.

7. CONVENÇÕES
   - Números/lista de conteúdo SÓ em Shared.Config. Sem "números mágicos" em outros scripts.
   - Todo módulo começa com um comentário --[[ ]] explicando o que faz (em português).
   - Serviços: Init() registra Net.Handle e eventos. Cliente: Init() constrói UI/conexões.
   - UI sempre pelos helpers do UIKit (fonte FredokaOne, contorno preto, cantos redondos, animação de clique).
   - Nunca confie em dados do cliente: valide tipo/limites em Net.Handle.
   - Não use localStorage etc.; persistência só no DataService.

8. COMO ADICIONAR CONTEÚDO
   Anime : nova entrada em Config.Animes (Id único, Biome, Rarity, Income, Look). Modelo procedural automático.
   Carro : nova entrada em Config.Cars (Tier sobe 1 por vez). Aparece sozinho na Garagem.
   Bioma : nova entrada em Config.Biomes (ZStart/ZEnd contínuos, Tier, Terrain, Props) + animes dele +
           carro do Tier. Depois rode WorldBuilder (ver cabeçalho do módulo). Não esqueça de checar que
           todas as 6 raridades existem para o bioma (o sorteio depende disso).
   Tela  : novo ModuleScript em Client usando UIKit.Panel; registrar o nome em ClientMain.ORDER e criar botão no HUD.

9. PIPELINE DE MODELAGEM (Blender -> Roblox)
   - Estilo: voxel/low-poly chunky, cabeça grande (chibi), contorno suave, cores saturadas.
   - Anime: Root nos PÉS, frente = -Z, ~6 studs de altura (escala 1). Exportar FBX, importar via
     Asset Manager > Bulk Import, agrupar em Model chamada <Id> e (próximo passo) fazer a factory
     preferir esse modelo quando existir em ServerStorage/Models/Animes.
   - Carro: manter peças "Chassis", "Seat" (VehicleSeat) e Welds "Wheel_FL/FR/RL/RR".
   - USE PERSONAGENS ORIGINAIS. Nada de personagens/marcas de animes existentes (risco de remoção).

10. PENDÊNCIAS / LIMITAÇÕES CONHECIDAS (v0.1)
   - Config.Sounds está vazio: preencher com rbxassetid:// (cliques, captura, revelação, cash, boost).
   - Like/Favorite do "Free Gift" NÃO são verificáveis pelo Roblox (só grupo, via Config.Gift.GroupId).
   - Botão "Index" ainda é placeholder (dados já são guardados em data.Index).
   - Garagem com 8 vagas físicas (compra de vagas/garagem maior = fase 2). Sem ganho offline ainda.
   - Física do carro e balanceamento AINDA NÃO foram testados em jogo: afinar Config.Cars (Accel/Turn/Grip)
     e o DriveController conforme o "feeling".
   - Orientação das setas dos boost pads (SurfaceGui Top) precisa conferir visualmente.
   - Terreno: colinas ainda suaves (Amp 14/22/30). Para biomas mais "complexos", aumente Terrain.Amp,
     adicione pontes, saltos maiores e desvios (fase 2).

10b. MUNDO v0.2 (lançamento)
   7 biomas encadeados no eixo -Z (Config.Biomes[i].Length; ZStart/ZEnd são CALCULADOS no fim do Config):
     1 Warrior Canyon 3200 | 2 Sakura Valley 3700 | 3 Sunset Dunes 4200 | 4 Frozen Tundra 4600 |
     5 Volcano Rift 5100 | 6 Neon City 5600 | 7 Celestial Peaks 6100   => 32.500 studs de pista (Beta 1.1).
   Mundo com 704 studs de largura (HalfWidth 352); pista com 60 studs (RoadFlat 30). Carro Tier N abre o bioma N (7 carros).
   Obstáculos por bioma (Config.Biomes[i].Obstacles = pesos): ramp, bumps, slalom, whoops, crest,
   gap (abismo + ponte estreita de 34 studs), pinch (desfiladeiro), logs, ice, gate. Pesos >= 3 são a
   "assinatura" do bioma e sempre aparecem. Tudo é determinístico: regenerar dá o mesmo mapa.
   Atmosfera por bioma: Config.Biomes[i].Sky (névoa/tom/luz), aplicada pelo Client.AtmosphereController.
   Teto de velocidade: Config.SpeedCap = 700 studs/s (física por raycast; acima disso atravessa pontes).
   REGENERAR O MUNDO (Studio, modo Edit; um passo por vez para não travar):
     local WB = require(game.ServerStorage.Tools.WorldBuilder)
     WB.StyleTerrain(); workspace.Terrain:Clear(); WB.BuildTerrain(420, 0)
     for i, b in ipairs(Config.Biomes) do WB.BuildTerrain(b.ZStart, (i == #Config.Biomes) and b.ZEnd - 60 or b.ZEnd) end
     WB.BuildMap()                      -- hub: 8 garagens, arco, portões
     for i = 1, #Config.Biomes do WB.BuildBiome(i) end
   DICA: capturas/visões de longe no Studio mostram o terreno em baixa resolução (LOD) e a pista pode
   "sumir". Não é bug: aproxime a câmera real do Studio e espere alguns segundos.

10c. BETA 1.1 (vale por cima de qualquer texto anterior que diga o contrário)
   FLUXO DO JOGADOR
     Entra => TELA DE INÍCIO (Client.StartMenu: START / CONFIGS / CREDITS / UPDATES; câmera girando, blur)
     START => escolhe a GARAGEM (◀ ▶, câmera voa até cada uma) => servidor "ClaimGarage"
     => nasce A PÉ no PlayerSpawn da garagem (também ao renascer); o carro fica ESTACIONADO na vaga.
     Entrar no carro: botão DRIVE (traz o carro para o lado) ou prompt "Drive" (tecla E) no banco.
     Sair: botão EXIT. A pé pode pular; dentro do carro o pulo fica desligado.
   PERSONAGENS = OVOS (o mini-jogo de captura está GUARDADO: Config.Features.CaptureNodes = false)
     Ovo de ESTRADA: grátis, tag "RoadEgg" (Map.EggNodes.<bioma>), passar por cima de carro ou a pé.
       Recarrega por jogador (Config.EggRules.RoadCooldown).
     SANTUÁRIO: pago (x1 / x3, +20% de sorte), tag "EggShrine" no Pedestal (Map.EggShrines.<bioma>;
       há 1 no hub). Prompt "Open Egg Shop" (tecla F) abre Client.EggShop.
     Sorteio no servidor (Services.EggService) com Config.EggOdds = a MESMA tabela que a loja mostra.
     7 raridades em TODOS os biomas: Common, Uncommon, Rare, Epic, Legendary, Mythic, SECRET (arco-íris).
   BIOMA 1 = "Warrior Canyon" (ORIGINAL de artes marciais). O pedido era Dragon Ball Z, mas IP de anime
     existente não pode ser usado (risco de remoção do jogo). Platôs em degraus (Terrain.Terrace),
     bonecos de treino, pedregulhos, estandartes, dojôs e arenas (Props.Landmarks). Personagens antigos do
     Verdant Plains ficaram como Legacy = true (não saem em ovos; existem só para saves antigos).
   REDE NOVA: GetGarages, ClaimGarage, DriveCar, ExitCar, CollectRoadEgg, BuyEgg, SaveSettings
     | evento GaragesChanged.
   ATRIBUTOS NOVOS do Player: Garage (índice), Set_SFX, Set_FOV, Set_LowGfx, Set_AutoPlace.
   DADOS NOVOS: data.Settings (menu CONFIGS) e data.Stats.Hatches.
   CLIENTE NOVO: StartMenu, EggVisuals, EggNodes, EggShop, EggHatchUI. UIKit ganhou Rainbow, SpinGradient,
     Shine, FloatText, Sunburst, Wobble e Percent.
   CRÉDITOS / ATUALIZAÇÕES do menu: Config.Credits (TROCAR os nomes "[Your Name]") e Config.Updates.
   OUTRAS FERRAMENTAS: ServerStorage.Tools.LobbyBuilder (outra sessão, 04/11) gera um lobby/garagens ALTERNATIVO.
     NÃO está aplicado. Se rodar, ele substitui as garagens atuais (mesmo contrato Plot_N).
   BACKUPS: ServerStorage.Backups["Beta 1.0"] (scripts, docs, ferramentas, iluminação + LEIA-ME de restauração).

10d. BETA 1.2 — LOBBY + CORRIDA SOLO + AZURE PLANET (vale por cima do que vier antes)
   LOBBY: ilha flutuante em Config.Lobby.Origin (0, 0, 3200), SEM estrada até a pista. Tem as 8 garagens,
     o santuário inicial (Azure Egg), o arco do jogo, a avenida e o PORTAL DE CORRIDA (peça com tag "RacePortal").
     O ponto de spawn e a câmera do menu ficam no lobby. Terreno: WorldBuilder.BuildLobbyTerrain (blocos).
   CORRIDA ("pista fantasma"): uma pista física; cada corredor recebe um SLOT (1..8) e corre sozinho.
     Services.RaceService: StartRace/EndRace/GoHome, grid (Config.Race), contagem com carro ancorado,
       distância e recorde (data.Stats.BestDistance), fim ao chegar no fim do mundo / morrer / sair.
     Grupos de colisão: "Characters" e "Cars" não colidem entre si nem uns com os outros.
     Client.GhostController: esconde os outros jogadores na tela enquanto alguém está correndo.
     Client.RaceUI: botão RACE, portal, 3-2-1-GO, painel ao vivo, tela de resultados.
     Por que não 8 cópias do mundo: ~200 mil peças, geração lenta, risco de passar do limite de place/lag.
   ATRIBUTOS: RaceState ("Lobby" | "Countdown" | "Racing"), RaceSlot, RaceDistance, RaceBest. Zona: "lobby" / "start".
   BIOMA 1 = "Azure Planet" (Id continua "warrior"): planeta alienígena ORIGINAL — grama azul (Grass), estrada de
     terra (Ground), penhascos lilás (Rock), árvores azuis, casas-domo, cogumelos, ilhas flutuantes, cercas,
     marcos arena/pods/energyspire/dojo com partículas de aura. Ovo = "Azure Egg".
     NÃO usar Dragon Ball (nomes, esferas, empresas, personagens): IP protegida. Ver 03_Guia_Bioma1.
   LINHA DE LARGADA: Map.Structures.StartLine (pórtico, luzes que ficam verdes no GO, vagas 1..8).
   WorldBuilder.BuildMap NÃO apaga mais o mundo: refaz lobby + largada + portões. Biomas: BuildBiome(i).
   BACKUP: ServerStorage.Backups["Beta 1.1"] (scripts + Map completo + terreno em TerrainRegion).

10e. BETA 1.3 — OVO DO BIOMA + ROLETA + FUGA + INCUBADORA + MY GARAGE (vale por cima do que vier antes)
   LOOP NOVO: corrida -> no FIM de cada bioma há UM ovo gigante (Map.BiomeEggs, criado pelo servidor ao iniciar;
     posição = Config.BiomeEggZ) -> prompt "Grab Egg" (F) -> ROLETA (Client.EggRouletteUI) -> a pista DESMORONA atrás
     do carro rumo à base -> cruzar a linha de largada (Config.Escape.BaseZ) = ovo vai para a INCUBADORA
     -> choca depois de Config.Rarities[r].HatchSeconds (30s/1min/3min/5min/20min/1h/12h) e vai para a garagem.
     Colapso alcançou o carro / Home / morreu = ovo perdido.
   SERVIDOR: Services.EggRoll (sorteio, só servidor), Services.EscapeService (validação + frente do colapso + anti-
     teleporte), Services.IncubatorService (tempo em os.time, conta offline). Frente: FrontZ0 + Speed*(t - FrontStart).
   CLIENTE: BiomeEggs (visual do ovo + liga/desliga o prompt), EggRouletteUI (TweenService), EscapeFX (fendas, destroços,
     rampas/pontes caindo SÓ na tela do jogador, parede de colapso, aviso, tremor), InventoryPanel ("My Garage":
     CHARACTERS / INCUBATOR / CARS; abre só no lobby pelo botão Garage do HUD ou tecla G na garagem).
   POR QUE O COLAPSO É SÓ VISUAL: a pista é compartilhada (pista fantasma, 10d). Quem decide "pego" é o servidor.
   CHANCES: Config.Rarities.Weight = tabela do dono (soma 99,86) e Config.EggOdds normaliza. Bioma 1 tem 8 personagens
     (2 Common). Os do Warrior Canyon antigo são Legacy.
   ATRIBUTOS NOVOS: EscapeState, EscapeBiome, EscapeEggZ, EscapeFrontZ0, EscapeFrontStart, EscapeSpeed, IncubatorUsed, IncubatorSlots.
   REDE NOVA: GetIncubator | eventos EggRoulette, EscapeResult, Incubator, Hatched.
   DADOS NOVOS: data.Incubator {IncId,Biome,Id,Mut,Size,Odds,Start,ReadyAt}, data.NextIncId, Stats.Escapes, Stats.EscapesLost.
   GUARDADOS: ovos de estrada (Features.RoadEggs) e santuários/EggShop (Features.Shrines) — em jogo as pastas
     Map.EggNodes/Map.EggShrines vão para ServerStorage.DisabledAtRuntime (o mapa do editor não muda).
   AJUSTE FÁCIL: Config.Escape (SpeedFactor, HeadStart, RouletteSeconds, EggBeforeEnd) e Config.Incubator.Slots.
   BACKUP: ServerStorage.Backups["Beta 1.2"].

10f. BETA 1.4 — LOBBY "SAKURA NIGHT" + DOCK + TRANSIÇÃO (vale por cima do que vier antes)
   MAPA (WorldBuilder.BuildLobby; zonas em Config.Lobby.Zones, relativas a Config.Lobby.Origin, -Z = lado da pista):
     Praça Sakura (spawn, r=50, cerejeira gigante, bancos, 18 lanternas flutuantes) no centro | Race Gate ao norte
     (palco +3 com escadas, torii "PLAY", portal com tag RacePortal) | garagens 1-4 (oeste) e 5-8 (leste) com faixas
     ciano em x=±80 | Car Showroom (sudeste, 3 giratórios) | Hall of Heroes (sudoeste, pódio Slot 0..4) | arco do jogo
     ao sul | lagos koi, pagodes, cerejeiras na borda, lua | paredes invisíveis na borda (ninguém cai).
     Pastas: Map.Structures.Lobby/{Plaza, RaceGate, GarageRow, Showroom, HallOfHeroes, Paths, Decor, Barrier}.
     ATENÇÃO: o terreno do lobby é DESENHADO em y≈2 (meio voxel). BuildLobby mede o chão e apoia tudo nele.
   LOBBY SÓ A PÉ (Config.Lobby.WalkOnly): ninguém dirige no lobby (CarService recusa "LobbyWalk"); o carro fica
     estacionado na garagem. PLAY (dock) ou entrar no portal => RaceService leva o carro direto ao grid.
   CLIENTE: LobbyDock (dock inferior GARAGE/INVENTORY/PLAY/SHOP/GIFT dentro do HUD, cortina "TO THE TRACK!" em
     PlayerGui.PlayTransition, esconde o prompt Drive no lobby) | LobbyShowcase (giratórios: equipado/próximo/sonho;
     pódio: cópia do avatar + 4 melhores personagens; balcões com prompt E; lanternas e koi animados) |
     AtmosphereController aplica Config.Lobby.Sky SÓ na zona "lobby" | UIKit.Panel com fundo escurecido.
   HIERARQUIA DE UI (criada por código via UIKit; StarterGui fica vazio de propósito):
     PlayerGui.GameUI/HUD/{Currency, BiomePill, Drive, Home, Reset, RacePanel, LobbyDock/{Glass, Row/{Garage, Inventory,
     Play, Shop, Gift}}} + painéis {Inventory, Garage(Car Shop), Gift, Settings, RaceResults} e seus "_Backdrop" +
     Toasts, EscapeBanner, DangerTint | PlayerGui.PlayTransition | PlayerGui.StartMenu.
   TAGS NOVAS: ShowroomPad, ShowcasePad, CarShopKiosk, InventoryKiosk, LobbyLantern, KoiFish.
   GUARDADOS: menu lateral do HUD e botão RACE (Config.Features.LobbyDock = false traz de volta);
     WorldBuilder.BuildLobbyBeta12 (lobby antigo). BACKUP: ServerStorage.Backups["Beta 1.3"] (inclui LobbyMap).

11. ROADMAP
   Fase 1 (atual): base jogável (dirigir, capturar, fazenda, garagem, 3 biomas, HUD, gift).
   Fase 2: playtest + balanceamento, sons, Index, compra de slots, rebirth, ganho offline, mais animes.
   Fase 3: eventos/limited time, trade plaza, pets de carro, mais biomas pós-lançamento. (Biomas 4-7 já feitos na v0.2.)
   Fase 4: monetização (gamepasses: 2x cash, VIP carro, auto-capture), analytics, otimização mobile.
]=]
return true
