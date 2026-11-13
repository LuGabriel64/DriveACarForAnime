--[[
	Config  (ReplicatedStorage.Shared.Config)                              Beta 1.1
	=====================================================================
	FONTE ÚNICA DE VERDADE do jogo "Drive A Car For Anime".
	Todo número de balanceamento, biomas, carros, personagens, ovos, raridades, textos de menu
	(créditos/atualizações) e configurações padrão moram AQUI.

	REGRAS PARA TODOS (pessoas e assistentes):
	  * Não renomeie chaves existentes (quebra outros scripts). Só adicione.
	  * Registre qualquer mudança em ServerStorage.ProjectDocs.01_ChangeLog.
	  * Personagens precisam ser ORIGINAIS (nada de personagens/marcas de animes existentes:
	    o Roblox remove jogos por violação de direitos autorais).
]]
local Config = {}
local C = Color3.fromRGB

Config.GameName = "Drive A Car For Anime"
Config.Version  = "Beta 1.9"

-- ---------------------------------------------------------------- RECURSOS (liga/desliga sistemas)
Config.Features = {
	Eggs = true,          -- sistema ATUAL de personagens: ovos (estrada + santuários)
	CaptureNodes = false, -- sistema ANTIGO (mini-jogo de captura) — GUARDADO. true = volta a funcionar
	                      -- (também é preciso regenerar o mapa: WorldBuilder.BuildBiome cria os pontos)
	StartMenu = true,     -- tela de início (START / CONFIGS / CREDITS / UPDATES)
	-- Beta 1.3: UM ovo por bioma (no FIM do bioma) + roleta + fuga com a pista desmoronando + incubadora.
	BiomeEggs = true,     -- sistema ATUAL (Services.EscapeService / IncubatorService)
	RoadEggs = false,     -- ovos grátis da estrada (Beta 1.1) — GUARDADO. true = volta a funcionar
	Shrines = false,      -- santuários pagos / Egg Shop (Beta 1.1) — GUARDADO. true = volta a funcionar
	-- Beta 1.4: dock flutuante (GARAGE / INVENTORY / PLAY / SHOP / GIFT) no lugar do menu lateral e do botão RACE.
	LobbyDock = true,     -- false = volta o menu lateral antigo do HUD + botão RACE (RaceUI)
}

-- ---------------------------------------------------------------- DADOS
Config.Data = {
	StoreName       = "DACFA_Player_v1", -- mudar o sufixo = resetar todos os saves
	AutosaveSeconds = 60,
	LoadRetries     = 5,
	LockTimeout     = 120,
}
Config.Start = { Cash = 0 }

-- Configurações do jogador (menu CONFIGS). Salvas em data.Settings e replicadas como atributos "Set_<nome>".
Config.Settings = {
	{ Key = "SFX",       Default = true,  Label = "Sound Effects",       Desc = "Clicks, hatching and reward sounds" },
	{ Key = "FOV",       Default = true,  Label = "Speed Camera Effect", Desc = "Camera zooms out when you drive fast" },
	{ Key = "LowGfx",    Default = false, Label = "Low Graphics",        Desc = "Turns off bloom, sun rays and fog for weaker devices" },
	{ Key = "AutoPlace", Default = true,  Label = "Auto-Place Hatches",  Desc = "New characters go straight to your garage pedestals" },
}

-- ---------------------------------------------------------------- MENU: créditos e atualizações
-- EDITE os nomes abaixo (aparecem no botão CREDITS da tela de início).
Config.Credits = {
	{ Role = "Created by",          Names = { "[Your Name]", "[Your Friend's Name]" } },
	{ Role = "Game Design & Build", Names = { "[Your Name]", "[Your Friend's Name]" } },
	{ Role = "Built with",          Names = { "Roblox Studio" } },
	{ Role = "AI Assistance",       Names = { "Claude (Anthropic)" } },
	{ Role = "Special Thanks",      Names = { "Every beta tester!" } },
}
Config.Updates = {
	{ Version = "Beta 1.9", Date = "Nov 13, 2026", Notes = {
		"🏁 NEW: 1v1 RACES! Challenge a player, vote the map and race in Formula cars — the track collapses from the start!",
		"⚔️ NEW: ANIME BATTLES! Pick your strongest fighter, watch the ULTs fly and win rewards",
		"🏎️ F1 Shop and Victory Effects shop in the new Versus Hall",
		"⭐ Characters now have 0-5 STARS and LEVELS up to 50: stronger stats and more income",
		"🎟️ Spin points: play and win to earn free Lucky Wheel spins (100 points = 1 spin)",
		"🌐 Languages: English and Português",
		"📱 The interface now fits phones, tablets, PC and consoles",
	} },
	{ Version = "Beta 1.8d", Date = "Nov 12, 2026", Notes = {
		"🧹 Removed a duplicated copy of the whole map: less lag, especially on phones",
		"✨ No more flickering signs and lights in the garages",
		"🛡️ Fairer escapes and records: impossible speeds no longer count",
	} },
	{ Version = "Beta 1.8", Date = "Nov 10, 2026", Notes = {
		"🚧 NEW OBSTACLES in every world: giant pendulums, spinning blades, crushing pistons, laser gates and geysers!",
		"💥 Hitting an obstacle knocks you back and slows you down — watch the timing!",
		"⚡ Fewer speed boosts on the track: driving skill matters more now",
	} },
	{ Version = "Beta 1.7", Date = "Nov 10, 2026", Notes = {
		"🎡 Lucky Wheel moved to the menu with a brand-new look — bigger prizes are rarer!",
		"🎟️ Win extra spins on the wheel, or grab x3 / x10 spin packs",
		"🧸 First-biome fighters got a cuter, rounder look (and new names)",
		"🖤 SECRET rarity is now pitch black",
		"🥚 Hold F to grab the Giant Egg — with a sleek new prompt",
		"💨 The collapse now chases you as fast as YOUR car — better cars, tougher escapes!",
	} },
	{ Version = "Beta 1.6", Date = "Nov 9, 2026", Notes = {
		"🐉 NEW CAST in the first biome: Gokun, Kurilin, Vegita, Master Kamo, Gohen, Cello, Pikollo and Majin Bubu",
		"🔄 Characters you already had were converted to the new cast automatically",
		"🛣️ Cleaner track: yellow ramps and side blocks removed",
		"⬆️ NEW Skyways: elevated lanes — go up, or take the slow lane below!",
		"🐢 NEW Slow pads: avoid the red pads to keep your speed",
		"🥋 NEW Tournament Bridge in the first biome",
	} },
	{ Version = "Beta 1.5", Date = "Nov 9, 2026", Notes = {
		"🎡 NEW: Lucky Wheel! Spin for FREE every 8 hours and win up to $100,000",
		"⏳ The wheel timer keeps counting even while you're offline",
		"💵 Wheel prizes go straight to your Cash (shown on the leaderboard)",
		"🏮 Two Lucky Wheel kiosks in the lobby (or tap WHEEL on the menu dock)",
		"🧹 Vending machines removed from the lobby for a cleaner, roomier plaza",
	} },
	{ Version = "Beta 1.4", Date = "Nov 7, 2026", Notes = {
		"🌸 NEW LOBBY: Sakura Night plaza with a giant cherry tree, lanterns, koi ponds and pagodas",
		"▶ NEW menu dock: PLAY, GARAGE, INVENTORY, SHOP and GIFT always one tap away",
		"🚗 Car Showroom: see your car, your next upgrade and the dream car",
		"⭐ Hall of Heroes: you and your 4 best characters on the podium",
		"🚶 The lobby is walk-only now — PLAY takes you straight to the starting grid",
	} },
	{ Version = "Beta 1.3", Date = "Nov 7, 2026", Notes = {
		"🥚 NEW: one Giant Egg at the END of every biome — spin the roulette to see what's inside!",
		"💥 NEW: grab the egg and ESCAPE — the track collapses behind you all the way back to base!",
		"⏳ NEW: Incubator — eggs hatch at your base (30s up to 12h, depending on rarity)",
		"🏠 NEW: Garage menu — equip characters, watch your incubator and switch cars",
		"🥋 8 brand-new fighters on Azure Planet",
	} },
	{ Version = "Beta 1.2", Date = "Nov 7, 2026", Notes = {
		"🏝️ NEW: Floating Lobby with all garages, separated from the race track",
		"🏁 NEW: Solo races! Start at the Race Portal — you race alone, no traffic",
		"⏱️ Countdown, live timer, distance and a results screen with your record",
		"🪐 First biome is now AZURE PLANET: blue forests, dome villages and energy spires",
		"✨ Energy aura on your car while boosting",
	} },
	{ Version = "Beta 1.1", Date = "Nov 7, 2026", Notes = {
		"🥚 NEW: Eggs! Find FREE eggs on the road or buy them at Egg Shrines",
		"⭐ NEW rarity: SECRET — one ultra-rare character in every biome",
		"🥋 NEW first biome: Warrior Canyon with 7 brand-new fighters",
		"🌍 All biomes are now much wider and longer",
		"🏁 Pick your garage, walk around and hit DRIVE whenever you want",
		"🎨 Brand-new menus, colors and effects",
	} },
	{ Version = "Beta 1.0", Date = "Nov 6, 2026", Notes = {
		"🏠 Garages with 8 character pedestals",
		"🗺️ 7 biomes and 7 cars",
		"🚧 Ramps, bridges, ice, narrow canyons and more obstacles",
	} },
}

-- ---------------------------------------------------------------- MUNDO
-- Rodovia no eixo -Z:  HUB/garagens (z>0)  ->  Bioma 1  ->  ...  ->  Bioma 7.
Config.World = {
	HalfWidth = 352, HubDepth = 380,
	YMin = -24, YMax = 180,
	RoadFlat = 30, RoadBlend = 70, RoadRoll = 6,      -- pista com 60 studs de largura
	WallStart = 250, WallRamp = 80, WallHeight = 90,  -- paredões laterais
	BlendZone = 160,
	BridgeWidth = 38,
	-- Hub (garagens): pátio de CONCRETO. Não pode ser Grass: o capim 3D atravessaria o piso das garagens.
	HubTerrain = { Amp = 0, Scale = 120, Top = Enum.Material.Concrete, Sub = Enum.Material.Pavement, Cliff = Enum.Material.Rock,
		Road = Enum.Material.Asphalt, RoadEdge = Enum.Material.Cobblestone },
}
-- Linha central da estrada. Curvas largas (raio >= ~850 studs) para carros de até 700 studs/s.
function Config.World.RoadX(z)
	if z >= 0 then return 0 end
	local t = -z
	local ramp = math.clamp(t / 260, 0, 1)
	return ramp * (120 * math.sin(t / 560) + 46 * math.sin(t / 250 + 1.3))
end

-- ---------------------------------------------------------------- LOBBY (Beta 1.2)
-- Ilha flutuante TOTALMENTE separada da pista (não há estrada entre os dois).
-- Lá ficam: as 8 garagens, o santuário inicial, o portal de corrida e o ponto de spawn.
-- Origin = centro do pátio (topo do piso em Y = Origin.Y). HalfX/HalfZ = meia-medida do pátio de concreto.
Config.Lobby = {
	Origin = Vector3.new(0, 0, 3200),
	HalfX = 250, HalfZ = 250,
	RimWidth = 44,               -- borda de grama em volta do pátio
	PortalOffsetZ = -205,        -- portal de corrida (lado "da frente" = -Z, mesma direção da pista)
	ShrineOffset = Vector3.new(78, 0, -150), -- ao lado da avenida (não bloqueia o caminho até o portal)
	ArchOffsetZ = 205,           -- arco com o nome do jogo
	PortalRadius = 18,           -- passar com o carro/a pé por aqui inicia a corrida
}

-- Beta 1.4: lobby "SAKURA NIGHT" (referência do dono: praça noturna com cerejeira gigante, lanternas e pagodes).
-- Construído por WorldBuilder.BuildLobby; vitrines por Client.LobbyShowcase; menu por Client.LobbyDock.
-- Coordenadas das zonas são RELATIVAS a Config.Lobby.Origin (-Z = lado da pista / "norte").
Config.Lobby.WalkOnly = true  -- no lobby ninguém dirige (fim dos bugs de colisão de carro); PLAY leva direto ao grid
Config.Lobby.Theme = {
	Sakura = C(255, 125, 196), SakuraLight = C(255, 182, 226), SakuraDeep = C(222, 84, 168),
	Lantern = C(255, 196, 118), Gold = C(255, 204, 72), Torii = C(214, 42, 56),
	Stone = C(150, 144, 178), Path = C(64, 56, 96), Night = C(30, 22, 54), Plaza = C(52, 44, 82),
	Race = C(255, 190, 60), Garage = C(0, 205, 255), Showroom = C(120, 140, 255), Heroes = C(255, 110, 220),
}
Config.Lobby.Zones = {
	PlazaRadius = 50,                                  -- praça central (spawn) com a cerejeira gigante
	SpawnOffset = Vector3.new(0, 1, 30),               -- SpawnLocation (só antes de escolher a garagem)
	RaceStage = Vector3.new(0, 0, -195), RaceStageSize = Vector3.new(90, 3, 64), -- palco do Race Gate (portal em PortalOffsetZ)
	GarageLaneX = 80,                                  -- faixas na frente das garagens (x = ±80)
	Showroom = Vector3.new(140, 0, 198),               -- vitrine de carros (3 giratórios)
	Heroes = Vector3.new(-140, 0, 198),                -- Hall of Heroes (seu avatar + 4 melhores personagens)
	HallSize = Vector3.new(100, 1.2, 76),
	Ponds = { Vector3.new(52, 0, -105), Vector3.new(-52, 0, -105) },
	Pagodas = { Vector3.new(195, 0, -195), Vector3.new(-195, 0, -195) },
	Barrier = 292,                                     -- paredes invisíveis na borda da ilha (ninguém cai)
}
-- Céu noturno SÓ no lobby (Client.AtmosphereController). Na pista volta ao visual-base do Lighting.
-- (meia-noite com lua alta = luz azulada; Exposure clareia sem estourar o neon. Ajustado em playtest.)
Config.Lobby.Sky = { ClockTime = 0.3, LightBrightness = 2.4, Exposure = 0.35, Tint = C(232, 218, 255), Saturation = 0.3, Brightness = 0.02,
	Contrast = 0.12, FogColor = C(140, 100, 210), FogDensity = 0.28, Ambient = C(128, 108, 190) }

-- ---------------------------------------------------------------- CORRIDA (Beta 1.2)
-- Modelo "PISTA FANTASMA": existe UMA pista, mas cada corredor recebe um SLOT e corre sozinho:
-- ninguém vê nem colide com outro jogador (ver Services.RaceService e Client.GhostController).
-- O slot define a posição no grid de largada e identifica a corrida ativa do jogador.
Config.Race = {
	MaxSlots = 8,
	Countdown = 3,                       -- segundos de 3-2-1-GO (carro ancorado)
	StartLineZ = 40,                     -- pórtico de largada (a pista corre para -Z a partir daqui)
	GridRowsZ = { 78, 104 },             -- fileiras do grid (atrás do pórtico)
	GridColsX = { -21, -7, 7, 21 },      -- 4 carros por fileira (pista tem 60 studs)
	FinishZ = nil,                       -- nil = fim do mundo (Config.World.TotalLength)
	CashPer100Studs = 0,                 -- recompensa por distância (0 = desligado; ligue para testar balanceamento)
}

-- ---------------------------------------------------------------- GARAGENS
Config.Garage = {
	Width = 48, Depth = 58, Height = 20, DoorWidth = 26, DoorHeight = 13,
	CenterX = 135, FirstZ = 54, Spacing = 64,
	PodiumX = 15.5, PodiumZ = { -18, -6, 6, 18 },
}

-- Cores do terreno (cor é POR MATERIAL e vale para o mundo inteiro: cada bioma usa materiais próprios).
Config.TerrainColors = {
	[Enum.Material.Grass]       = C(66, 118, 235),   -- grama AZUL do Azure Planet (só o bioma 1 e o lobby usam Grass)
	[Enum.Material.Ground]      = C(214, 160, 104),  -- estrada de terra do Azure Planet (só o bioma 1 usa Ground)
	[Enum.Material.LeafyGrass]  = C(255, 150, 196),
	[Enum.Material.Mud]         = C(132, 84, 98),
	[Enum.Material.Rock]        = C(178, 170, 198),   -- penhascos lilás-claros (Azure Planet e Sakura)
	[Enum.Material.Sand]        = C(255, 222, 122),
	[Enum.Material.Sandstone]   = C(232, 150, 76),
	[Enum.Material.Snow]        = C(244, 250, 255),
	[Enum.Material.Glacier]     = C(150, 212, 245),
	[Enum.Material.Ice]         = C(176, 230, 255),
	[Enum.Material.Basalt]      = C(52, 40, 50),
	[Enum.Material.Slate]       = C(84, 62, 74),
	[Enum.Material.CrackedLava] = C(255, 112, 30),
	[Enum.Material.Concrete]    = C(92, 96, 120),
	[Enum.Material.Pavement]    = C(66, 70, 98),
	[Enum.Material.Brick]       = C(128, 74, 92),
	[Enum.Material.Salt]        = C(248, 238, 255),
	[Enum.Material.Limestone]   = C(236, 224, 200),
	[Enum.Material.WoodPlanks]  = C(255, 214, 120),
	[Enum.Material.Asphalt]     = C(52, 52, 68),
	[Enum.Material.Cobblestone] = C(178, 178, 196),
}

-- ---------------------------------------------------------------- BIOMAS (7 = lançamento)
-- Length   : comprimento em studs (ZStart/ZEnd calculados no fim deste arquivo)
-- Tier     : nível mínimo do CARRO para entrar
-- Terrain  : Amp/Scale = colinas | Terrace/TerraceMix = platôs em degraus (mesas de cânion) | materiais
-- Props    : Kinds = decoração sorteada | PerK = quantidade por 1000 studs | Landmarks = construções grandes
-- Obstacles: pesos dos obstáculos (ver WorldBuilder). Peso >= 3 = "assinatura" (sempre aparece)
-- Style    : cor/material dos obstáculos | Sky: atmosfera local
local biomes = {
	-- Bioma 1 (Beta 1.2): "Azure Planet" — planeta alienígena ORIGINAL de guerreiros: grama azul, árvores azuis,
	-- casas-domo, platôs em degraus, estrada de terra, arenas de torneio e pilares de energia.
	-- O Id continua "warrior" (saves, ovos e personagens dependem dele).
	{ Id = "warrior", Name = "Azure Planet", Emoji = "🪐", Tier = 1, Length = 3200, Color = C(80, 160, 255),
	  Terrain = { Amp = 40, Scale = 150, Terrace = 10, TerraceMix = 1, Top = Enum.Material.Grass, Sub = Enum.Material.Rock,
	              Cliff = Enum.Material.Rock, Road = Enum.Material.Ground, RoadEdge = Enum.Material.Cobblestone },
	  Props = { Kinds = { "bluetree", "bluetree", "bluetree", "domehouse", "mushroom", "boulder", "dummy", "floatisland" }, PerK = 170,
	            Leaf = C(62, 120, 240), Trunk = C(150, 96, 60), Accent = C(90, 230, 255), RoadSide = "fence",
	            Landmarks = { "arena", "pods", "energyspire", "dojo", "pods", "energyspire" }, LandmarkEvery = 480 },
	  Obstacles = { pinch = 3, ramp = 3, crest = 2, slalom = 2, gap = 2, logs = 2, bumps = 1, whoops = 1 },
	  Style = { Color = C(196, 188, 214), Accent = C(90, 230, 255), Material = Enum.Material.Rock },
	  Sky = { Tint = C(235, 245, 255), Saturation = 0.28, Brightness = 0.03, Contrast = 0.04, FogColor = C(185, 225, 255), FogDensity = 0.26 } },
	{ Id = "sakura", Name = "Sakura Valley", Emoji = "🌸", Tier = 2, Length = 3700, Color = C(255, 130, 190),
	  Terrain = { Amp = 24, Scale = 115, Top = Enum.Material.LeafyGrass, Sub = Enum.Material.Mud, Cliff = Enum.Material.Rock, Road = Enum.Material.Asphalt, RoadEdge = Enum.Material.Cobblestone },
	  Props = { Kinds = { "tree" }, PerK = 190, Leaf = C(255, 140, 190), Trunk = C(96, 56, 52), Accent = C(255, 200, 225) },
	  Obstacles = { ramp = 2, bumps = 2, slalom = 2, whoops = 2, gate = 3, crest = 2, gap = 2, pinch = 2 },
	  Style = { Color = C(214, 204, 214), Accent = C(255, 110, 170), Material = Enum.Material.Concrete },
	  Sky = { Tint = C(255, 230, 242), Saturation = 0.2, Brightness = 0, Contrast = 0, FogColor = C(255, 198, 224), FogDensity = 0.34 } },
	{ Id = "dunes", Name = "Sunset Dunes", Emoji = "🏜️", Tier = 3, Length = 4200, Color = C(255, 190, 70),
	  Terrain = { Amp = 32, Scale = 150, Top = Enum.Material.Sand, Sub = Enum.Material.Sandstone, Cliff = Enum.Material.Sandstone, Road = Enum.Material.Asphalt, RoadEdge = Enum.Material.Cobblestone },
	  Props = { Kinds = { "cactus", "cactus", "rock" }, PerK = 150, Leaf = C(70, 160, 70), Trunk = C(70, 160, 70), Accent = C(255, 230, 140) },
	  Obstacles = { ramp = 2, crest = 4, whoops = 3, slalom = 1, gap = 2, pinch = 2, bumps = 1 },
	  Style = { Color = C(224, 162, 94), Accent = C(255, 232, 140), Material = Enum.Material.Sandstone },
	  Sky = { Tint = C(255, 226, 192), Saturation = 0.15, Brightness = 0, Contrast = 0.03, FogColor = C(255, 202, 142), FogDensity = 0.36 } },
	{ Id = "tundra", Name = "Frozen Tundra", Emoji = "❄️", Tier = 4, Length = 4600, Color = C(130, 215, 255),
	  Terrain = { Amp = 36, Scale = 150, Top = Enum.Material.Snow, Sub = Enum.Material.Glacier, Cliff = Enum.Material.Glacier, Road = Enum.Material.Asphalt, RoadEdge = Enum.Material.Ice },
	  Props = { Kinds = { "pine", "pine", "crystal" }, PerK = 170, Leaf = C(34, 112, 84), Trunk = C(90, 62, 44), Accent = C(130, 220, 255) },
	  Obstacles = { ramp = 2, ice = 4, slalom = 3, crest = 2, gap = 2, pinch = 3, bumps = 1 },
	  Style = { Color = C(176, 228, 255), Accent = C(255, 255, 255), Material = Enum.Material.Ice },
	  Sky = { Tint = C(222, 238, 255), Saturation = -0.05, Brightness = 0.03, Contrast = 0.02, FogColor = C(204, 228, 252), FogDensity = 0.42 } },
	{ Id = "volcano", Name = "Volcano Rift", Emoji = "🌋", Tier = 5, Length = 5100, Color = C(255, 110, 40),
	  Terrain = { Amp = 44, Scale = 120, Top = Enum.Material.Basalt, Sub = Enum.Material.Slate, Cliff = Enum.Material.Basalt, Road = Enum.Material.Asphalt, RoadEdge = Enum.Material.CrackedLava },
	  Props = { Kinds = { "deadtree", "lavarock", "lavarock" }, PerK = 150, Leaf = C(40, 32, 38), Trunk = C(38, 30, 34), Accent = C(255, 110, 30) },
	  Obstacles = { ramp = 2, slalom = 3, whoops = 2, pinch = 3, crest = 2, gap = 3, bumps = 1 },
	  Style = { Color = C(46, 38, 46), Accent = C(255, 100, 20), Material = Enum.Material.Basalt, GapFloor = "lava" },
	  Sky = { Tint = C(255, 190, 160), Saturation = 0.1, Brightness = -0.12, Contrast = 0.12, FogColor = C(255, 100, 50), FogDensity = 0.5, Ambient = C(120, 60, 50) } },
	{ Id = "city", Name = "Neon City", Emoji = "🌃", Tier = 6, Length = 5600, Color = C(190, 90, 255),
	  Terrain = { Amp = 12, Scale = 220, Top = Enum.Material.Concrete, Sub = Enum.Material.Pavement, Cliff = Enum.Material.Brick, Road = Enum.Material.Asphalt, RoadEdge = Enum.Material.Pavement },
	  Props = { Kinds = { "building" }, PerK = 120, Leaf = C(44, 48, 78), Trunk = C(30, 32, 52), Accent = C(255, 70, 220), RoadSide = "lamp" },
	  Obstacles = { ramp = 2, slalom = 4, bumps = 3, gap = 2, pinch = 2, whoops = 1, crest = 1, gate = 3 },
	  Style = { Color = C(240, 240, 248), Accent = C(255, 60, 90), Material = Enum.Material.SmoothPlastic },
	  Sky = { Tint = C(226, 204, 255), Saturation = 0.2, Brightness = -0.18, Contrast = 0.15, FogColor = C(150, 80, 230), FogDensity = 0.4, Ambient = C(80, 70, 130) } },
	{ Id = "celestial", Name = "Celestial Peaks", Emoji = "☁️", Tier = 7, Length = 6100, Color = C(255, 220, 120),
	  Terrain = { Amp = 44, Scale = 170, Top = Enum.Material.Salt, Sub = Enum.Material.Limestone, Cliff = Enum.Material.Limestone, Road = Enum.Material.WoodPlanks, RoadEdge = Enum.Material.Salt },
	  Props = { Kinds = { "spire", "cloudtree", "cloudtree" }, PerK = 140, Leaf = C(255, 255, 255), Trunk = C(255, 214, 110), Accent = C(255, 215, 90) },
	  Obstacles = { ramp = 3, gap = 4, crest = 3, slalom = 2, pinch = 2, whoops = 2, gate = 3 },
	  Style = { Color = C(250, 246, 255), Accent = C(255, 210, 90), Material = Enum.Material.Marble },
	  Sky = { Tint = C(255, 244, 216), Saturation = 0.25, Brightness = 0.02, Contrast = 0.03, FogColor = C(255, 226, 172), FogDensity = 0.3 } },
}
Config.Biomes = biomes

-- ---------------------------------------------------------------- CARROS (Tier N abre o bioma N)
Config.Cars = {
	{ Id = "starter",         Name = "Starter Hatch",    Tier = 1, Price = 0,           MaxSpeed = 70,  Accel = 60,  Turn = 1.90, Grip = 7.0,  Color = C(255, 106, 48),  Accent = C(255, 255, 255) },
	{ Id = "sakura_gt",       Name = "Sakura GT",        Tier = 2, Price = 25000,       MaxSpeed = 105, Accel = 80,  Turn = 2.00, Grip = 7.5,  Color = C(255, 120, 190), Accent = C(255, 255, 255) },
	{ Id = "dune_racer",      Name = "Dune Racer",       Tier = 3, Price = 400000,      MaxSpeed = 150, Accel = 105, Turn = 2.10, Grip = 8.0,  Color = C(255, 206, 60),  Accent = C(40, 40, 50) },
	{ Id = "frost_runner",    Name = "Frost Runner",     Tier = 4, Price = 5000000,     MaxSpeed = 210, Accel = 140, Turn = 2.15, Grip = 8.5,  Color = C(120, 210, 255), Accent = C(255, 255, 255) },
	{ Id = "magma_reaper",    Name = "Magma Reaper",     Tier = 5, Price = 70000000,    MaxSpeed = 290, Accel = 185, Turn = 2.20, Grip = 9.0,  Color = C(230, 60, 30),   Accent = C(30, 26, 30) },
	{ Id = "neon_phantom",    Name = "Neon Phantom",     Tier = 6, Price = 1000000000,  MaxSpeed = 390, Accel = 240, Turn = 2.25, Grip = 9.5,  Color = C(170, 70, 255),  Accent = C(70, 240, 255) },
	{ Id = "celestial_comet", Name = "Celestial Comet",  Tier = 7, Price = 15000000000, MaxSpeed = 520, Accel = 300, Turn = 2.30, Grip = 10.0, Color = C(255, 236, 150), Accent = C(255, 255, 255) },
}
-- ---------------------------------------------------------------- PISTA (Beta 1.6)
-- Liga/desliga peças de obstáculo no WorldBuilder.BuildBiome (o sorteio dos obstáculos não muda).
-- Desafios novos: WorldBuilder.BuildChallenges(i) — passarelas elevadas, pads de lentidão e pontes temáticas.
Config.Track = {
	Ramps = false,          -- rampas amarelas (removidas a pedido do dono)
	Slalom = false,         -- blocos de concreto nas laterais da pista (removidos a pedido do dono)
	Skyway = { Every = 900, Length = 90, Height = 9, Incline = 70, Width = 30 }, -- passarela elevada (sobe, reta, desce)
	SlowPad = { Every = 650, Width = 26, Length = 24, SpeedMult = 0.45, Duration = 1.4 }, -- pad de lentidão (meia pista)
	-- Beta 1.8: MENOS boosts. BoostEvery = distância entre boost pads extras (era 230). BoostMinGap = distância mínima
	-- entre QUAISQUER dois boosts (usada para afinar os pads já existentes no mapa).
	BoostEvery = 700, BoostMinGap = 650,
	-- Beta 1.8: OBSTÁCULOS ANIMADOS (WorldBuilder.BuildHazards + Client.HazardController). Movimento calculado no CLIENTE
	-- a partir do relógio do SERVIDOR (workspace:GetServerTimeNow) => todos veem igual, sem custo de rede.
	-- Bater: velocidade máx x SpeedMult por Duration s + empurrão (Knock studs/s) para longe do obstáculo.
	--   pendulum = martelo gigante balançando de um lado ao outro sob um pórtico
	--   sweeper  = hélice girando no meio da pista (as bordas ficam livres)
	--   piston   = blocos que saem das laterais e fecham meia pista, alternando os lados
	--   laser    = 3 feixes atravessando a pista que ligam/desligam (pisca antes de ligar)
	--   geyser   = 3 jatos que sobem do chão em sequência (fogo, areia, gelo, energia...)
	Hazards = {
		Every = 320, Start = 190, EggClear = 280, -- espaçamento | distância do início do bioma | distância livre antes do ovo
		SpeedMult = 0.4, Duration = 1.3, Knock = 42, Cooldown = 1.2,
		Periods = { pendulum = 3.2, sweeper = 3.4, piston = 2.8, laser = 3.0, geyser = 2.6 },
		Kinds = {
			warrior   = { "pendulum", "sweeper", "piston", "laser" },
			sakura    = { "pendulum", "laser", "sweeper", "geyser" },
			dunes     = { "geyser", "piston", "pendulum", "sweeper" },
			tundra    = { "piston", "geyser", "sweeper", "pendulum" },
			volcano   = { "geyser", "pendulum", "piston", "laser" },
			city      = { "laser", "piston", "sweeper", "geyser" },
			celestial = { "laser", "sweeper", "pendulum", "piston" },
		},
	},
	-- Pontes temáticas por bioma (WorldBuilder.BuildChallenges). Bioma 1: ponte de TORNEIO de artes marciais (tema DBZ).
	BridgeThemes = {
		warrior = { Deck = Color3.fromRGB(236, 230, 214), DeckMaterial = Enum.Material.Slate, Stripe = Color3.fromRGB(255, 140, 30),
			Rail = Color3.fromRGB(255, 140, 30), Pillar = Color3.fromRGB(255, 132, 28), Beam = Color3.fromRGB(40, 70, 170), Orb = Color3.fromRGB(255, 176, 40),
			OrbText = "★", Title = "🥋 TOURNAMENT BRIDGE", Sub = "don't fall off the ring!" },
	},
}

Config.Engine = { MaxLevel = 25, BaseCost = 150, Growth = 1.32, TierMult = 12, SpeedPerLevel = 0.05 }
-- Teto de velocidade (studs/s) já contando o motor. Acima disso a física por raycast perde o chão.
Config.SpeedCap = 700

-- ---------------------------------------------------------------- GARAGEM (renda dos personagens)
Config.Farm = { StartSlots = 8, SellMult = 25, AutoPlace = true }

-- ---------------------------------------------------------------- RARIDADES (7 níveis em TODOS os biomas)
-- Weight = peso base do sorteio (Beta 1.3: tabela do dono, em %). Os pesos somam 99,86 e Config.EggOdds
--          NORMALIZA (divide pelo total) => chance real = Weight / 99,86. Ex.: Common 58,18% | Secret 0,030%.
--          Se a raridade tiver 2+ personagens no bioma, o peso é dividido igualmente entre eles.
-- HatchSeconds = tempo na INCUBADORA da base até o ovo chocar (Beta 1.3).
-- Rainbow = texto/borda com arco-íris animado na UI.
-- Void (Beta 1.7) = estilo PRETO do Secret: cartas/fitas pretas com brilho prateado correndo (UIKit.VoidFill/VoidText).
--        TextColor = cor usada quando o nome da raridade aparece DENTRO de um texto (preto sumiria no contorno preto).
Config.Rarities = {
	Common    = { Order = 1, Weight = 58.1, HatchSeconds = 30,    Color = C(110, 255, 90),  Label = "COMMON" },
	Uncommon  = { Order = 2, Weight = 23.2, HatchSeconds = 60,    Color = C(90, 205, 255),  Label = "UNCOMMON" },
	Rare      = { Order = 3, Weight = 11.6, HatchSeconds = 180,   Color = C(90, 130, 255),  Label = "RARE" },
	Epic      = { Order = 4, Weight = 5.2,  HatchSeconds = 300,   Color = C(195, 95, 255),  Label = "EPIC" },
	Legendary = { Order = 5, Weight = 1.5,  HatchSeconds = 1200,  Color = C(255, 195, 45),  Label = "LEGENDARY" },
	Mythic    = { Order = 6, Weight = 0.23, HatchSeconds = 3600,  Color = C(255, 75, 115),  Label = "MYTHIC" },
	Secret    = { Order = 7, Weight = 0.03, HatchSeconds = 43200, Color = C(14, 14, 18), Label = "SECRET", Void = true,
	              TextColor = C(215, 215, 228), FxColor = C(235, 235, 245) },
}
Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Config.Mutations = {
	Gold    = { Chance = 0.06,  Mult = 2, Hue = 0.125, Sat = 0.85, Material = Enum.Material.Metal, Color = C(255, 200, 40) },
	Diamond = { Chance = 0.015, Mult = 5, Hue = 0.53,  Sat = 0.45, Material = Enum.Material.Glass, Color = C(120, 230, 255) },
}
Config.MutationOrder = { "Diamond", "Gold" }
Config.Sizes = { BIG = { Chance = 0.05, Mult = 1.5, Scale = 1.4 } }

-- ---------------------------------------------------------------- OVOS (sistema atual)
-- Um ovo por bioma. Price = preço no SANTUÁRIO (Egg Shrine). Luck multiplica raridades Rare+.
-- Ovos de ESTRADA (brilhando na pista) são GRÁTIS: basta passar por cima (de carro ou a pé).
Config.Eggs = {
	warrior   = { Name = "Azure Egg",     Price = 750,        Color = C(80, 150, 255),  Spot = C(255, 255, 255) },
	sakura    = { Name = "Blossom Egg",   Price = 6250,       Color = C(255, 150, 200), Spot = C(255, 255, 255) },
	dunes     = { Name = "Desert Egg",    Price = 75000,      Color = C(255, 205, 90),  Spot = C(200, 120, 50) },
	tundra    = { Name = "Frost Egg",     Price = 1000000,    Color = C(150, 220, 255), Spot = C(255, 255, 255) },
	volcano   = { Name = "Magma Egg",     Price = 13750000,   Color = C(70, 40, 44),    Spot = C(255, 110, 30) },
	city      = { Name = "Neon Egg",      Price = 200000000,  Color = C(160, 70, 255),  Spot = C(70, 240, 255) },
	celestial = { Name = "Celestial Egg", Price = 3000000000, Color = C(255, 240, 200), Spot = C(255, 210, 90) },
}
Config.EggRules = {
	ShrineLuck = 1.2,       -- sorte extra ao comprar no santuário
	RoadLuck = 1.0,         -- ovos grátis da estrada
	RoadCooldown = 30,      -- seg até o mesmo ovo de estrada reaparecer PARA O JOGADOR
	RoadRadius = 26,        -- distância (studs) para pegar um ovo de estrada
	ShrineRadius = 45,      -- distância máxima de um santuário para comprar
	MultiBuy = { 1, 3 },    -- quantidades permitidas por compra
	LuckFromOrder = 3,      -- sorte afeta Rare (3) para cima
}

-- ---------------------------------------------------------------- OVO DO BIOMA + FUGA (Beta 1.3)
-- Cada bioma tem UM ovo gigante perto do FIM. Durante a corrida: parar perto do ovo e SEGURAR F -> ROLETA (servidor sorteia)
-- -> a pista começa a DESMORONAR atrás do carro em direção à base -> chegar à linha de largada = ovo salvo (vai para
-- a incubadora) | o colapso alcançar o carro = ovo perdido. Tudo validado no servidor (Services.EscapeService).
Config.Escape = {
	EggBeforeEnd = 110,     -- studs antes do fim do bioma onde fica o ovo
	PromptDistance = 32,    -- Beta 1.7: volta o prompt SEGURAR F (UI própria: Client.GrabPromptUI)
	HoldDuration = 1.1,     -- segundos segurando F (ou o botão na tela) para pegar o ovo
	RouletteSeconds = 6,    -- duração da roleta (o carro fica freado)
	HeadStart = 3,          -- segundos de vantagem depois da roleta antes do colapso andar
	StartGap = 40,          -- o colapso nasce X studs além do ovo (lado do fim do bioma)
	SpeedFactor = 0.72,     -- piso: MaxSpeed BASE do carro do tier do bioma x fator
	CarFactor = 0.82,       -- Beta 1.7: colapso = MaxSpeed REAL do SEU carro (com motor) x fator => carro melhor, barreira mais rápida
	CarFactorMaxTier = 0.04,-- +4% por tier do seu carro acima do tier do bioma (carro forte em bioma fraco = ainda difícil)
	CarFactorCap = 0.92,    -- nunca passa de 92% da sua velocidade máxima (sempre dá para fugir dirigindo bem)
	MinSpeed = 45,          -- studs/s mínimos do colapso
	BaseZ = 40,             -- linha de chegada da fuga (pórtico de largada = Config.Race.StartLineZ)
	MaxForwardSpeed = 1.6,  -- (até a Beta 1.8b: limite por tick SpeedCap x isto + 60). Beta 1.8d: SEM USO — ver Config.AntiCheat
	CaughtEndDelay = 1.6,   -- segundos mostrando a queda antes de voltar ao lobby
	ChunkLength = 36,       -- (visual) tamanho de cada pedaço de pista que desaba
	ShakeDistance = 160,    -- (visual) tremor de câmera quando o colapso está a menos de X studs
}
-- Beta 1.8d: ANTI-TRAPAÇA de velocidade (fuga do ovo e recorde de distância). O cliente é dono da física do carro,
-- então o servidor confere o avanço com um "orçamento" (token bucket): enche a TopSpeed x ForwardSpeedMult por
-- segundo, até TopSpeed x ForwardSpeedMult x BurstSeconds + Slack; cada tick gasta o avanço medido. Orçamento
-- negativo = velocidade impossível (teleporte / speed hack) => fuga anulada ("invalid") ou corrida encerrada sem recorde.
-- Velocidade sustentada máxima aceita = TopSpeed x 1,6 (o mesmo que o boost pad dá no Client.DriveController).
Config.AntiCheat = {
	ForwardSpeedMult = 1.6, -- = boost pad (DriveController: cap x1.6)
	BurstSeconds = 2.5,     -- tolera posições chegando em rajada depois de lag de rede
	Slack = 120,            -- studs extras: empurrão do boost (35) + batida de obstáculo (42) + margem
	FallbackTopSpeed = 70,  -- se o atributo TopSpeed ainda não existir (carro inicial)
}
-- ---------------------------------------------------------------- ROLETA DA SORTE (Beta 1.5)
-- Um giro GRÁTIS a cada Cooldown segundos (8 h). O servidor (Services.WheelService) decide tudo: confere o tempo com
-- os.time() (relógio do servidor, salvo em data.Wheel.LastSpin => conta offline), sorteia pelo Weight e paga em Cash
-- (aparece no leaderstats). Prizes em ordem = fatias da roda no sentido horário. Chance = Weight / soma dos pesos.
-- Beta 1.7: roleta SÓ NA INTERFACE (sem quiosques no mapa), 6 fatias iguais no visual MAS pesos bem diferentes:
-- quanto maior o prêmio, menor o peso (os pesos somam 100 => Weight = chance em %). Spins = giros extras ganhos.
-- Giros: 1 grátis a cada Cooldown + giros EXTRAS (data.Wheel.Tokens) comprados com Robux (Packs) ou ganhos na roda.
-- Packs.ProductId = Developer Product criado no Creator Hub (Monetization > Developer Products). 0 = botão "Soon".
Config.Wheel = {
	Cooldown = 8 * 60 * 60,  -- 8 horas
	SpinSeconds = 5,         -- duração da animação; o prêmio entra no Cash quando a roda para
	Prizes = {
		{ Label = "$500",    Icon = "💵", Cash = 500,    Weight = 38, Color = C(110, 220, 80) },
		{ Label = "$2.5K",   Icon = "💰", Cash = 2500,   Weight = 27, Color = C(70, 170, 255) },
		{ Label = "+2 Spins",Icon = "🎟️", Spins = 2,     Weight = 15, Color = C(170, 90, 240) },
		{ Label = "$10K",    Icon = "💎", Cash = 10000,  Weight = 12, Color = C(255, 150, 40) },
		{ Label = "$50K",    Icon = "🏆", Cash = 50000,  Weight = 6,  Color = C(240, 70, 90) },
		{ Label = "$250K",   Icon = "👑", Cash = 250000, Weight = 2,  Color = C(255, 205, 50), Jackpot = true },
	},
	Packs = {
		{ Key = "x3",  Spins = 3,  Robux = 29, ProductId = 0, Color = C(255, 196, 40) },
		{ Key = "x10", Spins = 10, Robux = 79, ProductId = 0, Color = C(190, 80, 255) },
	},
}

Config.Incubator = {
	Slots = 6,              -- ovos chocando ao mesmo tempo (cheia = não dá para pegar outro ovo)
}

-- ---------------------------------------------------------------- CAPTURA (sistema ANTIGO, guardado — ver Features)
Config.Capture = {
	Period = 1.1, Duration = 3.0, NodeCooldown = 25, TriggerRadius = 34, LuckFromOrder = 3,
	Grades = {
		{ Name = "PERFECT", Min = 0.85, Luck = 2.0, Color = C(255, 215, 60) },
		{ Name = "GREAT",   Min = 0.60, Luck = 1.5, Color = C(100, 255, 90) },
		{ Name = "GOOD",    Min = 0.30, Luck = 1.2, Color = C(90, 200, 255) },
		{ Name = "OK",      Min = 0.00, Luck = 1.0, Color = C(230, 230, 230) },
	},
}

Config.Gift = { Cash = 10000, GroupId = 0 }
Config.Sounds = { Click = "", Capture = "", Reveal = "", Cash = "", Boost = "", Rare = "", Hatch = "", Crack = "" }

-- ---------------------------------------------------------------- PERSONAGENS (ORIGINAIS)
-- Look: parâmetros do AnimeModelFactory. Acessórios: headband scarf hat chefhat foxears tail horns halo
-- crown cape sword wings mecha beanie visor staff.  Legacy = true: não aparece em ovos (só p/ saves antigos).
local S1, S2 = C(255, 224, 196), C(240, 196, 160)
local function A(id, name, biome, rarity, income, look, legacy)
	return { Id = id, Name = name, Biome = biome, Rarity = rarity, Income = income, Look = look, Legacy = legacy }
end
Config.Animes = {
	-- ===== 1. Bioma 1 (Id "warrior") — Beta 1.6: elenco de DRAGON BALL Z escolhido pelo DONO (09/11/2026).
	-- ATENÇÃO (regra 13 do 02_AI_Protocol): é IP de terceiros; o dono autorizou e assume o risco de moderação.
	-- Para voltar aos originais: marque estes como Legacy e tire o Legacy do bloco "Beta 1.3" abaixo.
	-- Beta 1.7: NOMES levemente alterados a pedido do dono (Gokun, Kurilin, Vegita, Master Kamo, Gohen, Cello, Pikollo,
	-- Majin Bubu). Os Ids (goku, kuririn...) NÃO mudaram => saves continuam válidos, sem migração.
	A("goku",    "Gokun",         "warrior", "Common",    3,     { Skin = S1, Hair = C(20,20,26), Style = "spiky", Eyes = C(25,25,35), Outfit = C(255,128,30), Outfit2 = C(255,128,30), Acc = {"belt"}, AccColor = C(40,80,200), BeltColor = C(40,80,200), Under = C(40,80,200), Sleeve = C(40,80,200), Wrist = C(40,80,200), Shoe = C(40,70,170), BootTrim = C(210,40,40), Gi = true, Expression = "confident" }),
	A("kuririn", "Kurilin",       "warrior", "Common",    4,     { Bald = true, Skin = S1, Hair = S1, Style = "short", Eyes = C(25,25,35), Outfit = C(255,128,30), Outfit2 = C(255,128,30), Acc = {"belt"}, AccColor = C(40,80,200), BeltColor = C(40,80,200), Under = C(40,80,200), Sleeve = C(255,128,30), Wrist = C(40,80,200), Shoe = C(40,70,170), Gi = true, Expression = "happy" }),
	A("vegeta",  "Vegita",        "warrior", "Uncommon",  9,     { Skin = S1, Hair = C(20,20,26), Style = "flame", Eyes = C(25,25,35), Outfit = C(245,245,245), Outfit2 = C(30,40,140), Acc = {"mecha"}, AccColor = C(230,190,70), Under = C(30,40,140), Sleeve = C(30,40,140), LongSleeve = true, Gloves = C(250,250,250), Shoe = C(250,250,250), BootTrim = C(230,190,70), Expression = "angry" }),
	A("kame",    "Master Kamo",   "warrior", "Rare",      28,    { Bald = true, Skin = S2, Hair = S2, Style = "short", Eyes = C(25,25,35), Outfit = C(235,90,40), Outfit2 = C(40,90,200), Acc = {"visor","beard"}, AccColor = C(230,40,50), Under = C(255,230,170), Sleeve = C(235,90,40), Shoe = C(140,90,50), Expression = "happy", Brow = C(250,250,250) }),
	A("gohan",   "Gohen",         "warrior", "Epic",      100,   { Skin = S1, Hair = C(20,20,26), Style = "spiky", Eyes = C(25,25,35), Outfit = C(80,40,140), Outfit2 = C(80,40,140), Acc = {"belt"}, AccColor = C(210,40,50), BeltColor = C(210,40,50), Under = C(60,30,110), Sleeve = C(80,40,140), Wrist = C(210,40,50), Shoe = C(150,90,50), Gi = true, Expression = "confident" }),
	A("cell",    "Cello",         "warrior", "Legendary", 380,   { Bald = true, Skin = C(235,230,240), Hair = C(25,25,32), Style = "short", Eyes = C(170,60,200), Outfit = C(150,220,60), Outfit2 = C(150,220,60), Acc = {"crest","wings"}, AccColor = C(25,25,32), Under = C(25,25,32), Sleeve = C(150,220,60), LongSleeve = true, Gloves = C(235,230,240), Shoe = C(25,25,32), Expression = "angry", Brow = C(25,25,32) }),
	A("piccolo", "Pikollo",       "warrior", "Mythic",    2200,  { Bald = true, Skin = C(110,200,90), Hair = C(110,200,90), Style = "short", Eyes = C(25,25,35), Outfit = C(60,40,140), Outfit2 = C(60,40,140), Acc = {"turban","antenna","cape","belt"}, AccColor = C(245,245,245), BeltColor = C(70,110,220), Under = C(40,30,90), Sleeve = C(60,40,140), Wrist = C(200,60,60), Shoe = C(120,80,50), Gi = true, Expression = "angry", Brow = C(60,120,50) }),
	A("buu",     "Majin Bubu",    "warrior", "Secret",    12000, { Bald = true, Skin = C(255,165,190), Hair = C(255,165,190), Style = "short", Eyes = C(25,25,35), Outfit = C(255,165,190), Outfit2 = C(245,240,225), Acc = {"headtail","belt","cape"}, AccColor = C(120,40,150), BeltColor = C(25,25,32), Under = C(120,40,150), Sleeve = C(255,165,190), Gloves = C(250,250,250), Shoe = C(240,200,60), Expression = "happy", Brow = C(30,30,40) }),
	-- ===== 1. Azure Planet (Id "warrior") — Beta 1.3: 8 lutadores ORIGINAIS (2 comuns, como pediu o dono).
	-- Papéis por raridade: lutador novato e monge (Common) | príncipe guerreiro (Uncommon) | velho mestre (Rare) |
	-- aprendiz da tempestade (Epic) | bio-titã (Legendary) | sábio alienígena (Mythic) | criatura de goma do caos (Secret).
	A("ryo",    "Rookie Fighter Ryo",     "warrior", "Common",    3,     { Skin = S1, Hair = C(70,45,30),    Style = "spiky", Eyes = C(70,50,40),    Outfit = C(225,60,50),   Outfit2 = C(245,245,245), Acc = {"headband"}, AccColor = C(40,40,50) }, true),
	A("toru",   "Pebble Monk Toru",       "warrior", "Common",    4,     { Skin = S2, Hair = C(40,35,35),    Style = "bun",   Eyes = C(60,50,45),    Outfit = C(60,170,160),  Outfit2 = C(240,220,170), Acc = {"scarf"}, AccColor = C(255,190,60) }, true),
	A("varek",  "Sky Prince Varek",       "warrior", "Uncommon",  9,     { Skin = S1, Hair = C(60,30,80),    Style = "spiky", Eyes = C(170,90,255),  Outfit = C(190,40,50),   Outfit2 = C(40,40,60),    Acc = {"mecha","cape"}, AccColor = C(220,225,235) }, true),
	A("hoji",   "Old Master Hoji",        "warrior", "Rare",      28,    { Skin = S2, Hair = C(245,245,245), Style = "long",  Eyes = C(60,60,60),    Outfit = C(120,190,90),  Outfit2 = C(230,200,140), Acc = {"visor","staff"}, AccColor = C(255,170,40) }, true),
	A("ren",    "Storm Pupil Ren",        "warrior", "Epic",      100,   { Skin = S1, Hair = C(30,30,40),    Style = "spiky", Eyes = C(80,200,255),  Outfit = C(40,120,200),  Outfit2 = C(25,50,100),   Acc = {"scarf","headband"}, AccColor = C(255,150,40) }, true),
	A("zerak",  "Bio-Titan Zerak",        "warrior", "Legendary", 380,   { Skin = C(120,200,190), Hair = C(40,90,90), Style = "spiky", Eyes = C(255,60,120), Outfit = C(50,140,130), Outfit2 = C(40,30,60), Acc = {"horns","wings","mecha"}, AccColor = C(255,90,200) }, true),
	A("oru",    "Star Sage Oru",          "warrior", "Mythic",    2200,  { Skin = C(110,150,255), Hair = C(240,240,250), Style = "short", Eyes = C(255,240,120), Outfit = C(70,40,120), Outfit2 = C(30,20,60), Acc = {"horns","cape","staff"}, AccColor = C(255,255,255) }, true),
	A("moko",   "Chaos Gummy Moko",       "warrior", "Secret",    12000, { Skin = C(205,150,255), Hair = C(170,110,240), Style = "bun", Eyes = C(255,80,120), Outfit = C(255,240,250), Outfit2 = C(120,60,170), Acc = {"tail","crown","cape"}, AccColor = C(255,215,90) }, true),
	-- Antigos do Warrior Canyon (Beta 1.1/1.2): LEGADO (não saem mais em ovos; mantidos para saves antigos).
	A("kenta",  "Rookie Brawler Kenta",   "warrior", "Common",    3,     { Skin = S1, Hair = C(90,55,35),    Style = "short", Eyes = C(90,60,40),    Outfit = C(120,140,170), Outfit2 = C(60,70,95),   Acc = {"headband"}, AccColor = C(255,210,60) }, true),
	A("rio",    "Kick Master Rio",        "warrior", "Uncommon",  9,     { Skin = S1, Hair = C(40,160,120),  Style = "long",  Eyes = C(60,200,140),  Outfit = C(60,200,140),  Outfit2 = C(30,90,70),    Acc = {"scarf"}, AccColor = C(255,255,255) }, true),
	A("bao",    "Stone Monk Bao",         "warrior", "Rare",      28,    { Skin = S2, Hair = C(60,50,45),    Style = "bun",   Eyes = C(70,60,50),    Outfit = C(150,150,160), Outfit2 = C(100,100,110), Acc = {"staff"}, AccColor = C(120,200,255) }, true),
	A("raika",  "Thunder Fist Raika",     "warrior", "Epic",      100,   { Skin = S1, Hair = C(200,200,215), Style = "spiky", Eyes = C(255,230,60),  Outfit = C(110,60,180),  Outfit2 = C(50,30,90),    Acc = {"mecha","headband"}, AccColor = C(255,230,60) }, true),
	A("ryuen",  "Dragon Sage Ryuen",      "warrior", "Legendary", 380,   { Skin = S1, Hair = C(245,245,245), Style = "long",  Eyes = C(255,90,90),   Outfit = C(190,40,50),   Outfit2 = C(120,25,35),   Acc = {"horns","staff","cape"}, AccColor = C(255,200,60) }, true),
	A("garon",  "Storm Emperor Garon",    "warrior", "Mythic",    2200,  { Skin = S2, Hair = C(30,30,40),    Style = "spiky", Eyes = C(90,220,255),  Outfit = C(40,50,90),    Outfit2 = C(20,25,50),    Acc = {"crown","cape","sword","wings"}, AccColor = C(90,220,255) }, true),
	A("nameless","The Nameless Champion", "warrior", "Secret",    12000, { Skin = S1, Hair = C(15,15,20),    Style = "long",  Eyes = C(255,255,255), Outfit = C(15,15,20),    Outfit2 = C(255,255,255), Acc = {"halo","visor","cape","wings"}, AccColor = C(255,255,255) }, true),
	-- ===== 2. Sakura Valley
	A("hanami", "Hanami Student",         "sakura",  "Common",    25,    { Skin = S1, Hair = C(30,30,40),    Style = "twin",  Eyes = C(160,100,80),  Outfit = C(255,255,255), Outfit2 = C(60,70,140),  Acc = {"scarf"}, AccColor = C(255,120,170) }),
	A("kiri",   "Kitsune Kiri",           "sakura",  "Uncommon",  80,    { Skin = S1, Hair = C(255,160,60),  Style = "long",  Eyes = C(255,210,60),  Outfit = C(255,120,60),  Outfit2 = C(255,255,255),Acc = {"foxears","tail"}, AccColor = C(255,160,60) }),
	A("rei",    "Shrine Maiden Rei",      "sakura",  "Rare",      250,   { Skin = S1, Hair = C(25,25,35),    Style = "long",  Eyes = C(200,60,60),   Outfit = C(255,255,255), Outfit2 = C(220,40,50),  Acc = {"headband"}, AccColor = C(220,40,50) }),
	A("gen",    "Oni Warrior Gen",        "sakura",  "Epic",      900,   { Skin = C(224,110,100), Hair = C(240,240,240), Style = "spiky", Eyes = C(255,230,60), Outfit = C(60,40,60), Outfit2 = C(90,50,90), Acc = {"horns","sword"}, AccColor = C(255,80,60) }),
	A("kenji",  "Samurai Kenji",          "sakura",  "Legendary", 3500,  { Skin = S2, Hair = C(25,25,30),    Style = "bun",   Eyes = C(90,60,50),    Outfit = C(50,60,90),    Outfit2 = C(200,40,40),  Acc = {"mecha","sword","headband"}, AccColor = C(220,220,230) }),
	A("tsuki",  "Moon Princess Tsuki",    "sakura",  "Mythic",    20000, { Skin = S1, Hair = C(200,180,255), Style = "long",  Eyes = C(255,200,255), Outfit = C(255,240,255), Outfit2 = C(160,110,255),Acc = {"halo","wings","crown"}, AccColor = C(255,240,160) }),
	A("sakuya", "Blossom Spirit Sakuya",  "sakura",  "Secret",    120000,{ Skin = S1, Hair = C(255,190,220), Style = "long",  Eyes = C(255,120,180), Outfit = C(255,235,245), Outfit2 = C(255,150,200),Acc = {"halo","wings","crown","staff"}, AccColor = C(255,150,200) }),
	-- ===== 3. Sunset Dunes
	A("wanderer","Desert Wanderer",       "dunes",   "Common",    300,    { Skin = S2, Hair = C(110,70,40),   Style = "short", Eyes = C(90,60,40),    Outfit = C(210,170,110), Outfit2 = C(150,110,70), Acc = {"scarf","hat"}, AccColor = C(235,205,145) }),
	A("zahra",  "Sand Dancer Zahra",      "dunes",   "Uncommon",  1000,   { Skin = S2, Hair = C(80,30,110),   Style = "twin",  Eyes = C(255,120,200), Outfit = C(240,90,160),  Outfit2 = C(255,200,90), Acc = {"scarf"}, AccColor = C(255,200,90) }),
	A("amun",   "Pharaoh Prince Amun",    "dunes",   "Rare",      3000,   { Skin = S2, Hair = C(25,25,30),    Style = "short", Eyes = C(60,140,255),  Outfit = C(255,255,255), Outfit2 = C(255,200,60), Acc = {"crown","cape"}, AccColor = C(60,110,255) }),
	A("zero",   "Mecha Pilot Zero",       "dunes",   "Epic",      11000,  { Skin = S1, Hair = C(40,220,200),  Style = "spiky", Eyes = C(255,255,255), Outfit = C(240,240,250), Outfit2 = C(60,70,90),   Acc = {"mecha","headband"}, AccColor = C(255,120,30) }),
	A("kaito",  "Dragon Slayer Kaito",    "dunes",   "Legendary", 45000,  { Skin = S2, Hair = C(230,50,40),   Style = "spiky", Eyes = C(255,170,40),  Outfit = C(60,60,70),    Outfit2 = C(170,40,30),  Acc = {"sword","cape","wings"}, AccColor = C(150,30,30) }),
	A("amara",  "Sun Goddess Amara",      "dunes",   "Mythic",    250000, { Skin = S2, Hair = C(255,160,40),  Style = "long",  Eyes = C(255,240,120), Outfit = C(255,225,120), Outfit2 = C(255,120,40), Acc = {"halo","crown","wings","cape"}, AccColor = C(255,200,60) }),
	A("sefet",  "Eternal Sphinx Sefet",   "dunes",   "Secret",    1500000,{ Skin = S2, Hair = C(25,25,30),    Style = "long",  Eyes = C(80,230,255),  Outfit = C(255,215,90),  Outfit2 = C(30,60,140),  Acc = {"crown","cape","wings","tail"}, AccColor = C(255,215,90) }),
	-- ===== 4. Frozen Tundra
	A("scout",  "Snowy Scout",            "tundra",  "Common",    4000,     { Skin = S1, Hair = C(225,240,255), Style = "short", Eyes = C(90,170,255),  Outfit = C(80,130,210),  Outfit2 = C(50,70,120),  Acc = {"beanie","scarf"}, AccColor = C(255,255,255) }),
	A("yukiko", "Yukiko the Skater",      "tundra",  "Uncommon",  13000,    { Skin = S1, Hair = C(150,220,255), Style = "twin",  Eyes = C(60,140,255),  Outfit = C(235,250,255), Outfit2 = C(90,160,230),  Acc = {"scarf"}, AccColor = C(255,120,180) }),
	A("frey",   "Frost Mage Frey",        "tundra",  "Rare",      40000,    { Skin = S1, Hair = C(170,150,255), Style = "long",  Eyes = C(255,255,255), Outfit = C(70,80,170),   Outfit2 = C(40,50,110),   Acc = {"staff","crown"}, AccColor = C(150,230,255) }),
	A("borea",  "Blizzard Knight Borea",  "tundra",  "Epic",      150000,   { Skin = S1, Hair = C(210,220,235), Style = "spiky", Eyes = C(120,220,255), Outfit = C(150,170,200), Outfit2 = C(70,90,130),   Acc = {"mecha","sword","headband"}, AccColor = C(190,240,255) }),
	A("kori",   "Ice Empress Kori",       "tundra",  "Legendary", 600000,   { Skin = S1, Hair = C(240,250,255), Style = "long",  Eyes = C(120,200,255), Outfit = C(200,235,255), Outfit2 = C(120,180,240), Acc = {"crown","cape","wings"}, AccColor = C(160,230,255) }),
	A("fenri",  "Polar Spirit Fenri",     "tundra",  "Mythic",    3500000,  { Skin = S1, Hair = C(255,255,255), Style = "long",  Eyes = C(90,220,255),  Outfit = C(235,245,255), Outfit2 = C(170,200,230), Acc = {"foxears","tail","halo"}, AccColor = C(150,235,255) }),
	A("kaida",  "Frost Wyrm Kaida",       "tundra",  "Secret",    21000000, { Skin = S1, Hair = C(200,240,255), Style = "spiky", Eyes = C(80,200,255),  Outfit = C(120,190,255), Outfit2 = C(60,100,180),  Acc = {"horns","wings","tail","crown"}, AccColor = C(180,240,255) }),
	-- ===== 5. Volcano Rift
	A("ember",  "Ember the Blacksmith",   "volcano", "Common",    55000,     { Skin = S2, Hair = C(200,60,40),   Style = "short", Eyes = C(255,150,40),  Outfit = C(70,60,60),    Outfit2 = C(120,50,40),   Acc = {"headband","scarf"}, AccColor = C(255,120,30) }),
	A("piko",   "Cinder Imp Piko",        "volcano", "Uncommon",  180000,    { Skin = C(240,130,90), Hair = C(60,30,40), Style = "twin", Eyes = C(255,230,60), Outfit = C(150,40,40), Outfit2 = C(60,30,30), Acc = {"horns","tail"}, AccColor = C(255,90,40) }),
	A("gor",    "Magma Brawler Gor",      "volcano", "Rare",      550000,    { Skin = S2, Hair = C(255,110,30),  Style = "spiky", Eyes = C(255,255,255), Outfit = C(60,56,64),    Outfit2 = C(190,70,30),   Acc = {"mecha","headband"}, AccColor = C(255,140,30) }),
	A("ignia",  "Fire Dancer Ignia",      "volcano", "Epic",      2000000,   { Skin = S1, Hair = C(255,130,60),  Style = "long",  Eyes = C(255,230,90),  Outfit = C(230,60,50),   Outfit2 = C(255,170,50),  Acc = {"wings","scarf","cape"}, AccColor = C(255,120,30) }),
	A("zagan",  "Demon General Zagan",    "volcano", "Legendary", 8000000,   { Skin = C(200,70,70), Hair = C(25,20,28), Style = "spiky", Eyes = C(255,230,60), Outfit = C(40,30,44), Outfit2 = C(130,30,40), Acc = {"horns","sword","cape"}, AccColor = C(255,70,40) }),
	A("hinoko", "Phoenix Empress Hinoko", "volcano", "Mythic",    50000000,  { Skin = S1, Hair = C(255,170,50),  Style = "long",  Eyes = C(255,240,140), Outfit = C(255,120,40),  Outfit2 = C(255,210,80),  Acc = {"halo","wings","crown","tail"}, AccColor = C(255,150,40) }),
	A("volka",  "Inferno Titan Volka",    "volcano", "Secret",    300000000, { Skin = C(90,50,50), Hair = C(255,120,30), Style = "spiky", Eyes = C(255,240,90), Outfit = C(50,30,30), Outfit2 = C(255,90,30), Acc = {"horns","mecha","cape","sword"}, AccColor = C(255,110,30) }),
	-- ===== 6. Neon City
	A("rin",    "Street Racer Rin",       "city",    "Common",    800000,     { Skin = S1, Hair = C(255,90,170),  Style = "twin",  Eyes = C(90,240,255),  Outfit = C(40,40,60),    Outfit2 = C(255,60,150),  Acc = {"visor","scarf"}, AccColor = C(80,240,255) }),
	A("kuro",   "Hacker Kuro",            "city",    "Uncommon",  2600000,    { Skin = S1, Hair = C(70,255,160),  Style = "short", Eyes = C(70,255,160),  Outfit = C(30,30,40),    Outfit2 = C(60,60,80),    Acc = {"beanie","visor"}, AccColor = C(70,255,160) }),
	A("mimi",   "Idol Star Mimi",         "city",    "Rare",      8000000,    { Skin = S1, Hair = C(255,130,230), Style = "twin",  Eyes = C(255,255,255), Outfit = C(255,240,255), Outfit2 = C(255,90,200),  Acc = {"crown","scarf"}, AccColor = C(255,230,90) }),
	A("hayate", "Cyber Samurai Hayate",   "city",    "Epic",      30000000,   { Skin = S1, Hair = C(60,230,255),  Style = "spiky", Eyes = C(255,70,100),  Outfit = C(30,34,50),    Outfit2 = C(70,200,255),  Acc = {"mecha","sword","visor"}, AccColor = C(70,230,255) }),
	A("nova",   "Mecha Queen Nova",       "city",    "Legendary", 120000000,  { Skin = S1, Hair = C(180,110,255), Style = "long",  Eyes = C(255,255,255), Outfit = C(235,235,250), Outfit2 = C(120,70,210),  Acc = {"mecha","halo","wings"}, AccColor = C(200,140,255) }),
	A("kaizen", "Neon God Kaizen",        "city",    "Mythic",    800000000,  { Skin = S1, Hair = C(255,255,255), Style = "spiky", Eyes = C(255,70,255),  Outfit = C(25,25,40),    Outfit2 = C(255,70,255),  Acc = {"crown","halo","cape","wings","visor"}, AccColor = C(255,90,255) }),
	A("null",   "Glitch Phantom Null",    "city",    "Secret",    4800000000, { Skin = S1, Hair = C(0,255,200),   Style = "spiky", Eyes = C(255,0,200),   Outfit = C(10,10,20),    Outfit2 = C(0,255,200),   Acc = {"visor","halo","cape"}, AccColor = C(0,255,200) }),
	-- ===== 7. Celestial Peaks
	A("wisp",   "Cloud Apprentice Wisp",  "celestial","Common",   12000000,    { Skin = S1, Hair = C(245,248,255), Style = "short", Eyes = C(150,200,255), Outfit = C(250,250,255), Outfit2 = C(190,215,255), Acc = {"halo"}, AccColor = C(255,235,150) }),
	A("selene", "Star Archer Selene",     "celestial","Uncommon", 40000000,    { Skin = S1, Hair = C(255,225,120), Style = "twin",  Eyes = C(255,200,60),  Outfit = C(70,80,170),   Outfit2 = C(255,240,190), Acc = {"staff","scarf"}, AccColor = C(255,225,100) }),
	A("tenzo",  "Sky Monk Tenzo",         "celestial","Rare",     120000000,   { Skin = S2, Hair = C(30,30,40),    Style = "bun",   Eyes = C(255,210,90),  Outfit = C(255,170,50),  Outfit2 = C(255,240,200), Acc = {"headband","staff"}, AccColor = C(255,255,255) }),
	A("brynn",  "Celestial Valkyrie Brynn","celestial","Epic",    450000000,   { Skin = S1, Hair = C(255,230,150), Style = "long",  Eyes = C(100,220,255), Outfit = C(235,240,255), Outfit2 = C(255,200,70),  Acc = {"wings","sword","crown"}, AccColor = C(255,225,110) }),
	A("ryujin", "Dragon Emperor Ryujin",  "celestial","Legendary",1800000000,  { Skin = S1, Hair = C(60,230,200),  Style = "long",  Eyes = C(255,230,70),  Outfit = C(30,100,120),  Outfit2 = C(255,200,60),  Acc = {"horns","cape","crown","wings"}, AccColor = C(255,210,70) }),
	A("aeon",   "Creator Goddess Aeon",   "celestial","Mythic",   12000000000, { Skin = S1, Hair = C(255,250,235), Style = "long",  Eyes = C(255,230,150), Outfit = C(255,255,255), Outfit2 = C(255,215,100), Acc = {"halo","wings","crown","cape","staff"}, AccColor = C(255,225,110) }),
	A("lumina", "Origin Star Lumina",     "celestial","Secret",   72000000000, { Skin = S1, Hair = C(255,255,200), Style = "long",  Eyes = C(255,220,120), Outfit = C(255,255,255), Outfit2 = C(255,230,150), Acc = {"halo","wings","crown","cape","staff"}, AccColor = C(255,240,170) }),
	-- ===== LEGADO (antigo bioma Verdant Plains; Beta 1.0). Não aparecem em ovos; mantidos para saves antigos.
	A("nini",   "Nini the Villager",      "verdant", "Common",    2,    { Skin = S1, Hair = C(120,70,40),   Style = "short", Eyes = C(60,170,90),   Outfit = C(240,240,230), Outfit2 = C(190,110,70), Acc = {"scarf"}, AccColor = C(220,70,70) }, true),
	A("haru",   "Haru the Apprentice",    "verdant", "Uncommon",  7,    { Skin = S1, Hair = C(40,50,110),   Style = "spiky", Eyes = C(80,170,255),  Outfit = C(80,120,220),  Outfit2 = C(50,60,100),  Acc = {"headband","sword"}, AccColor = C(255,255,255) }, true),
	A("mika",   "Mika the Ramen Chef",    "verdant", "Rare",      22,   { Skin = S1, Hair = C(255,140,180), Style = "bun",   Eyes = C(255,110,150), Outfit = C(250,250,250), Outfit2 = C(230,70,70),  Acc = {"chefhat"}, AccColor = C(255,255,255) }, true),
	A("taro",   "Taro the Shadow Ninja",  "verdant", "Epic",      80,   { Skin = S2, Hair = C(30,30,40),    Style = "spiky", Eyes = C(255,60,60),   Outfit = C(45,45,62),    Outfit2 = C(30,30,42),   Acc = {"headband","scarf"}, AccColor = C(180,40,200) }, true),
	A("yuna",   "Yuna the Sun Priestess", "verdant", "Legendary", 300,  { Skin = S1, Hair = C(255,210,80),  Style = "long",  Eyes = C(255,170,40),  Outfit = C(255,245,215), Outfit2 = C(255,190,60), Acc = {"halo","wings"}, AccColor = C(255,215,80) }, true),
	A("raiden", "Raiden the Storm Lord",  "verdant", "Mythic",    1800, { Skin = S2, Hair = C(190,230,255), Style = "spiky", Eyes = C(80,220,255),  Outfit = C(60,70,200),   Outfit2 = C(30,35,110),  Acc = {"cape","crown","sword"}, AccColor = C(255,230,90) }, true),
}

-- Beta 1.6: MIGRAÇÃO de saves (DataService, data.Version 1 -> 2): personagens do elenco anterior do bioma 1 viram o
-- equivalente do elenco novo (mesma raridade e renda). Inventário, incubadora e Index são convertidos ao carregar.
Config.AnimeMigrations = { ryo = "goku", toru = "kuririn", varek = "vegeta", hoji = "kame", ren = "gohan", zerak = "cell", oru = "piccolo", moko = "buu" }

-- ---------------------------------------------------------------- ÍNDICES AUXILIARES (gerados — não editar)
Config.CarById, Config.AnimeById, Config.BiomeById, Config.AnimesByBiome = {}, {}, {}, {}
for _, c in ipairs(Config.Cars) do Config.CarById[c.Id] = c end
do
	local z = 0 -- encadeia os biomas: cada um começa onde o anterior termina
	for i, b in ipairs(biomes) do
		b.Order = i
		b.ZStart, b.ZEnd = z, z - b.Length
		z = b.ZEnd
		Config.BiomeById[b.Id] = b
		Config.AnimesByBiome[b.Id] = {}
	end
	Config.World.TotalLength = -z
end
for _, a in ipairs(Config.Animes) do
	Config.AnimeById[a.Id] = a
	local pool = Config.AnimesByBiome[a.Biome]
	if pool and not a.Legacy then -- legado não entra no sorteio
		pool[a.Rarity] = pool[a.Rarity] or {}
		table.insert(pool[a.Rarity], a)
	end
end

function Config.EngineCost(level, tier)
	tier = tier or 1
	return math.floor(Config.Engine.BaseCost * Config.Engine.Growth ^ level * Config.Engine.TierMult ^ (tier - 1))
end
function Config.SpeedMult(level) return 1 + level * Config.Engine.SpeedPerLevel end
function Config.BiomeAtZ(z)
	for _, b in ipairs(Config.Biomes) do
		if z <= b.ZStart and z > b.ZEnd then return b end
	end
	return nil
end
function Config.GradeFor(pos)
	for _, g in ipairs(Config.Capture.Grades) do if pos >= g.Min then return g end end
	return Config.Capture.Grades[#Config.Capture.Grades]
end

-- Beta 1.3: posição do ovo do bioma (Z no eixo da pista) e velocidade do colapso da fuga (studs/s).
function Config.BiomeEggZ(biome) return biome.ZEnd + Config.Escape.EggBeforeEnd end
-- Beta 1.7: carMaxSpeed/carTier = carro REAL do jogador (opcionais). Colapso = o MAIOR entre o piso do bioma e
-- MaxSpeed do carro x (CarFactor + CarFactorMaxTier por tier acima do bioma), limitado a CarFactorCap x MaxSpeed.
function Config.EscapeSpeed(biome, carMaxSpeed, carTier)
	local E = Config.Escape
	local base = Config.Cars[1].MaxSpeed
	for _, c in ipairs(Config.Cars) do if c.Tier == biome.Tier then base = c.MaxSpeed end end
	local speed = math.max(E.MinSpeed, base * E.SpeedFactor)
	if carMaxSpeed and carMaxSpeed > 0 then
		local f = E.CarFactor + math.max(0, (carTier or biome.Tier) - biome.Tier) * E.CarFactorMaxTier
		speed = math.max(speed, carMaxSpeed * math.min(f, E.CarFactorCap))
		speed = math.min(speed, carMaxSpeed * E.CarFactorCap)
	end
	return speed
end
-- Beta 1.7: cor de TEXTO / efeitos de uma raridade (o Secret é preto: texto prateado, efeitos brancos)
function Config.RarityText(rar) return rar.TextColor or rar.Color end
function Config.RarityFx(rar) return rar.FxColor or rar.Color end
-- "3m 05s" / "12h 00m" / "45s"
function Config.FormatDuration(sec)
	sec = math.max(0, math.floor(sec + 0.5))
	if sec >= 3600 then return string.format("%dh %02dm", sec // 3600, (sec % 3600) // 60) end
	if sec >= 60 then return string.format("%dm %02ds", sec // 60, sec % 60) end
	return sec .. "s"
end

-- Probabilidades de um ovo: lista { Anime, Chance (0..1) } em ordem de raridade. Usado pelo servidor
-- (sorteio) e pela UI (tabela de chances) => o que o jogador vê é EXATAMENTE o que o servidor usa.
function Config.EggOdds(biomeId, luck)
	luck = luck or 1
	local pool = Config.AnimesByBiome[biomeId]
	if not pool then return {} end
	local total, rows = 0, {}
	for _, rname in ipairs(Config.RarityOrder) do
		local list = pool[rname]
		local r = Config.Rarities[rname]
		if list and #list > 0 then
			local w = r.Weight * ((r.Order >= Config.EggRules.LuckFromOrder) and luck or 1)
			total += w
			for _, a in ipairs(list) do rows[#rows + 1] = { Anime = a, W = w / #list } end
		end
	end
	for _, row in ipairs(rows) do row.Chance = row.W / total; row.W = nil end
	return rows
end

-- Beta 1.9: estrelas, nível, pontos de spin, idiomas, música, Versus (corrida 1v1 e batalha). Os números moram em
-- Shared.ConfigBeta19 (módulo separado para este arquivo não crescer mais) e aparecem aqui como Config.*.
require(script.Parent.ConfigBeta19)(Config)

return Config