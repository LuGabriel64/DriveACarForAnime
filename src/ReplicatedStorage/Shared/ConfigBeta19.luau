--[[
	ConfigBeta19  (ReplicatedStorage.Shared.ConfigBeta19)                                        Beta 1.9
	=====================================================================================================
	TODOS os números e conteúdos novos da Beta 1.9, num módulo SEPARADO do Config principal (que já tem
	650 linhas). O Config continua sendo a fonte única: ele chama este módulo e tudo aparece como Config.*.

	COMO ESTÁ LIGADO: última linha de Shared.Config, antes do "return Config":
	    require(script.Parent.ConfigBeta19)(Config)

	O QUE ADICIONA
	    Config.Stars, Config.Levels          estrelas (0..5) e nível (1..50) de cada personagem
	    Config.Wheel.Points                  pontos de SPIN (100 = 1 giro)
	    Config.Languages                     idiomas do botão "Languages"
	    Config.Music                         músicas de fundo (IDs pendentes: o dono escolhe)
	    Config.Versus                        convite, lobby, votação, preparação, recompensas
	    Config.Versus.Race + Config.F1Cars   corrida 1v1 (carros de Fórmula 1, colapso desde a largada)
	    Config.Versus.Battle + Config.Battle batalha de anime (arenas, classes, ULTs, animações de vitória)
	    Config.Settings                      + interruptor "Music"

	REGRAS: não renomeie chaves; só adicione. Registre mudanças no 01_ChangeLog.
	TESTES: a lógica que usa estes números (AnimeStats, BattleSim) tem 80 verificações fora do Roblox
	        (repositório: planejamento/beta-1.9/testes). Mexeu em Battle.Classes ou Battle.Sim? Rode de novo.
]]
return function(Config)
	local C = Color3.fromRGB

	-- ------------------------------------------------------------ ESTRELAS (0..5)
	-- Sorteadas quando o ovo é sorteado (Services.EggRoll). Cada estrela vale um valor FIXO:
	--   multiplicador = 1 + StepMult x estrelas   =>  0★ x1,00 | 1★ x1,075 | 2★ x1,15 | 3★ x1,225 | 4★ x1,30 | 5★ x1,375
	-- Exemplo do dono: um Secret de $400/s => 400 | 430 | 460 | 490 | 520 | 550.
	-- Vale para a RENDA e para TODOS os status de batalha. Personagens antigos (sem o campo) contam como 0★.
	Config.Stars = {
		Max = 5,
		StepMult = 0.075,
		-- pesos do sorteio (somam 100 => peso = chance em %)
		Weights = { [0] = 40, [1] = 28, [2] = 17, [3] = 9, [4] = 4.5, [5] = 1.5 },
	}

	-- ------------------------------------------------------------ NÍVEL (1..50)
	-- XP para subir do nível L para L+1 = XpBase + XpPerLevel x L   (total até o 50 = 16.170 XP)
	-- Cada nível acima do 1 soma StatPerLevel nos status de batalha e IncomePerLevel na renda.
	Config.Levels = {
		Max = 50,
		XpBase = 30,
		XpPerLevel = 12,
		StatPerLevel = 0.02,    -- nível 50 = x1,98 nos status de batalha
		IncomePerLevel = 0.01,  -- nível 50 = x1,49 na renda (0 = nível não mexe na renda)
	}

	-- ------------------------------------------------------------ PONTOS DE SPIN
	-- 100 pontos viram 1 giro extra da roleta (data.Wheel.Tokens). O resto fica guardado (ex.: 37/100).
	Config.Wheel.Points = {
		PerSpin = 100,
		PerMinute = 2,   -- a cada minuto jogado (relógio do SERVIDOR)
		PerWin = 10,     -- vitória em corrida 1v1 ou batalha
	}

	-- ------------------------------------------------------------ IDIOMAS
	-- Code = chave das tabelas de Shared.Locale. O 1º da lista é o padrão quando o idioma do Roblox não bate.
	-- Flag = emoji (nem todo aparelho desenha bandeiras) | FlagKind = bandeira desenhada com Frames (Client.StartMenu).
	Config.Languages = {
		{ Code = "en", Name = "English",   Flag = "🇺🇸", FlagKind = "us", RobloxLocales = { "en" } },
		{ Code = "pt", Name = "Português", Flag = "🇧🇷", FlagKind = "br", RobloxLocales = { "pt" } },
	}

	-- ------------------------------------------------------------ MÚSICA
	-- IDs "rbxassetid://..." (PENDENTE: o dono escolhe no Creator Store > Audio). "" = sem música (sem erro).
	Config.Music = {
		Race = "",          -- corrida 1v1 (épica, rápida)
		Battle = "",        -- batalha de anime (épica, orquestral)
		VersusLobby = "",   -- sala de espera / votação
		Victory = "",       -- vinheta curta de vitória
		Volume = 0.45,
		FadeSeconds = 1.2,
	}
	table.insert(Config.Settings, { Key = "Music", Default = true, Label = "Music", Desc = "Background music in races and battles" })

	-- ------------------------------------------------------------ VERSUS (convite -> lobby -> votação -> preparação -> jogo)
	Config.Versus = {
		InviteSeconds = 20,     -- tempo para o convidado responder
		InviteCooldown = 8,     -- espera entre dois convites do mesmo jogador
		LobbySeconds = 20,      -- sala de espera (termina antes se os dois apertarem READY)
		VoteSeconds = 15,       -- votação do mapa / arena
		PrepSeconds = 30,       -- preparação (comprar e escolher carro, personagem, animação)
		ResultSeconds = 8,      -- tela de resultado antes de voltar ao lobby principal
		-- Versus Hall: ilha separada, só a pé, com a loja de F1 e a loja de animações de vitória.
		-- (construída por ServerStorage.Tools.VersusBuilder em Workspace.Map.Versus)
		HallOrigin = Vector3.new(1400, 0, 3200),
		HallSpawns = { Vector3.new(-12, 4, 20), Vector3.new(12, 4, 20) },
		Rewards = {
			WinXP = 100,
			LoseXP = 40,
			WinSpinPoints = 10,
			WinCashSeconds = 120,        -- dinheiro do vencedor = renda dele ($/s) x estes segundos...
			WinCashMin = 500,            -- ...com este mínimo (jogador novo, sem renda)
			FullRewardsPerOpponent = 10, -- depois de N partidas contra o MESMO adversário na sessão: só XP
		},
	}

	-- ------------------------------------------------------------ CORRIDA 1v1
	-- Usa a MESMA pista do jogo (nada de copiar o mapa): assim toda estrutura nova da pista entra sozinha.
	-- O que muda é o MODO (atributo RaceMode = "Duel"): sem ovo gigante, sem bloqueio de tier, com carros
	-- de F1 e com o colapso começando na largada.
	Config.Versus.Race = {
		Maps = {
			{ Id = "grand_tour", Name = "Grand Tour", Icon = "🏁", Desc = "All 7 biomes, start to finish", FinishZ = nil },
			-- FinishZ = nil => fim do mundo (Config.World.TotalLength). Mapas futuros: trechos ou pistas novas.
		},
		Countdown = 3,
		GridColsX = { -10, 10 },   -- os dois lado a lado na primeira fileira
		CollapseDelay = 4,         -- segundos depois do GO até o colapso começar a andar
		CollapseStartGap = 120,    -- o colapso nasce X studs ATRÁS do grid
		CollapseFactor = 0.55,     -- velocidade = MaxSpeed do carro MAIS LENTO da partida x fator (fuga do ovo usa 0,82)
		CollapseMin = 60,          -- studs/s mínimos
		MaxSeconds = 420,          -- limite da corrida: quem estiver mais longe vence
		MaxForwardFactor = 1.6,    -- (documentação) o anti-trapaça real usa Config.AntiCheat, igual à corrida solo
	}

	-- Carros de F1: SÓ para a corrida 1v1 (não abrem biomas, não têm tier, motor não se aplica).
	-- Body = "f1" => CarFactory constrói o modelo de fórmula (baixo, largo, rodas expostas, asas, halo).
	-- Todo jogador começa com o primeiro. Comprados com Cash na loja do Versus Hall.
	Config.F1Cars = {
		{ Id = "f1_rookie",  Name = "Rookie F-01",  Body = "f1", Price = 0,          MaxSpeed = 230, Accel = 170, Turn = 2.40, Grip = 10.5, Color = C(235, 235, 245), Accent = C(230, 40, 50) },
		{ Id = "f1_viper",   Name = "Viper F-02",   Body = "f1", Price = 150000,     MaxSpeed = 270, Accel = 200, Turn = 2.45, Grip = 11.0, Color = C(40, 200, 90),   Accent = C(20, 20, 26) },
		{ Id = "f1_storm",   Name = "Storm F-03",   Body = "f1", Price = 5000000,    MaxSpeed = 310, Accel = 230, Turn = 2.50, Grip = 11.5, Color = C(40, 120, 255),  Accent = C(255, 220, 60) },
		{ Id = "f1_phantom", Name = "Phantom F-04", Body = "f1", Price = 150000000,  MaxSpeed = 350, Accel = 260, Turn = 2.55, Grip = 12.0, Color = C(28, 26, 36),    Accent = C(190, 80, 255) },
		{ Id = "f1_apex",    Name = "Apex F-05",    Body = "f1", Price = 5000000000, MaxSpeed = 400, Accel = 300, Turn = 2.60, Grip = 12.5, Color = C(255, 196, 40),  Accent = C(255, 255, 255) },
	}
	Config.F1ById = {}
	for _, c in ipairs(Config.F1Cars) do Config.F1ById[c.Id] = c end

	-- ------------------------------------------------------------ BATALHA DE ANIME
	Config.Versus.Battle = {
		-- Arenas ORIGINAIS com tema de anime (construídas por ServerStorage.Tools.VersusBuilder).
		Arenas = {
			{ Id = "sky_ring",   Name = "Sky Tournament Ring", Icon = "🥋", Desc = "A floating martial-arts ring above the clouds", Origin = Vector3.new(-1400, 0, 3200) },
			{ Id = "moon_dojo",  Name = "Sakura Moon Dojo",    Icon = "🌸", Desc = "Petals, lanterns and a giant full moon",        Origin = Vector3.new(-1400, 0, 3900) },
			{ Id = "lava_arena", Name = "Volcano Coliseum",    Icon = "🌋", Desc = "A stone arena surrounded by lava falls",        Origin = Vector3.new(-1400, 0, 4600) },
		},
		-- Posições RELATIVAS ao Origin da arena (iguais nas 3). O piso do ringue fica em Origin.Y + RingTop.
		RingTop = 4,
		FighterOffsets = { Vector3.new(-13, 4, 0), Vector3.new(13, 4, 0) },       -- lutador 1 (esquerda) e 2 (direita)
		SpectatorOffsets = { Vector3.new(-8, 11, 44), Vector3.new(8, 11, 44) },   -- plateia: onde ficam os avatares dos jogadores
		StartDelay = 1.5,     -- segundos entre o servidor mandar o roteiro e a cena começar (tempo de carregar a arena)
		IntroSeconds = 3.5,   -- (replay) apresentação dos dois lutadores
		OutroSeconds = 4,     -- (replay) nocaute + animação de vitória
	}

	Config.Battle = {
		-- Poder base por raridade (o bioma multiplica: 1 + BiomeStep x (ordem do bioma - 1)).
		RarityPower = { Common = 100, Uncommon = 135, Rare = 180, Epic = 245, Legendary = 330, Mythic = 450, Secret = 620 },
		BiomeStep = 0.25,
		MutationPower = { Gold = 1.15, Diamond = 1.35 },
		SizePower = { BIG = 1.10 },
		-- Status base a partir do Poder (P), antes da classe: HP = P x HP, ATK = P x ATK, ...
		Base = { HP = 16, ATK = 1, DEF = 0.5, SPD = 1, ASPD = 1, POW = 1 },
		-- Classes: como o Poder é distribuído. Cada uma tem um tipo de ULT.
		-- NÚMEROS CALIBRADOS por simulação: com o MESMO Poder, nenhuma classe precisa de mais de ~3,5% de Poder
		-- extra para empatar com outra — menos que meia estrela. Quem decide a luta é raridade, estrelas e nível;
		-- a classe só dá o "jeito" da luta. Mexeu aqui? Rode os testes de novo.
		Classes = {
			Brawler   = { HP = 1.02, ATK = 1.18, DEF = 0.92, SPD = 1.00, ASPD = 1.00, POW = 0.90, UltKind = "Burst" },
			Guardian  = { HP = 1.17, ATK = 0.90, DEF = 1.18, SPD = 0.85, ASPD = 0.92, POW = 0.95, UltKind = "Bulwark" },
			Speedster = { HP = 0.94, ATK = 1.00, DEF = 0.90, SPD = 1.30, ASPD = 1.22, POW = 0.90, UltKind = "Flurry" },
			Mystic    = { HP = 0.93, ATK = 1.00, DEF = 0.95, SPD = 1.00, ASPD = 1.00, POW = 1.40, UltKind = "Nova" },
			Champion  = { HP = 1.04, ATK = 1.03, DEF = 1.03, SPD = 1.03, ASPD = 1.03, POW = 1.03, UltKind = "Finisher" },
		},
		DefaultClass = "Champion",
		-- ULTs por tipo. O NOME e o efeito visual (Fx) são por personagem, em Config.Battle.Fighters.
		--   Burst    = um golpe enorme                      | Bulwark  = golpe + escudo (% do HP máximo)
		--   Flurry   = vários golpes rápidos                | Nova     = golpe mágico (cresce com POW, fura DEF)
		--   Finisher = golpe forte; muito mais forte se o alvo estiver com pouco HP
		UltKinds = {
			Burst    = { Mult = 3.0 },
			Bulwark  = { Mult = 2.0, Shield = 0.12 },
			Flurry   = { Mult = 0.62, Hits = 5 },
			Nova     = { Mult = 2.4, IgnoreDef = 0.5 },
			Finisher = { Mult = 2.8, ExecuteBelow = 0.35, ExecuteBonus = 0.5 },
		},
		-- Simulação (Services.BattleSim). O servidor simula a luta INTEIRA e manda o roteiro aos dois clientes.
		Sim = {
			MaxSeconds = 60,       -- passou disso: vence quem tiver mais % de HP
			BaseInterval = 1.15,   -- segundos entre ataques (ASPD encurta ou alonga)
			IntervalClamp = { 0.65, 1.5 },
			FirstStrike = 0.6,     -- o mais rápido (SPD) ataca primeiro; o outro, FirstStrikeGap depois
			FirstStrikeGap = 0.35,
			Variance = 0.08,       -- dano x (1 ± 8%). 0 = luta 100% determinística
			CritBase = 0.05, CritScale = 0.25, CritMin = 0.03, CritMax = 0.35, CritMult = 1.6,
			DodgeBase = 0.04, DodgeScale = 0.25, DodgeMax = 0.25,
			-- EnergyHit 25 + EnergyHurt 10: os dois chegam à ULT na MESMA rodada e quem é mais rápido usa primeiro.
			-- (Com 22, quem atacava em segundo carregava a ULT uma rodada antes: ser rápido virava desvantagem.)
			EnergyHit = 25, EnergyHurt = 10, EnergyDodge = 6, EnergyMax = 100,
			PowClamp = { 0.7, 1.5 }, -- POW (comparado ao do adversário) acelera a carga da ULT e o dano da Nova
			UltPause = 0.4,        -- tempo extra que a ULT ocupa no relógio da luta
		},
		-- Animações de vitória (loja do Versus Hall). Tocam no lutador vencedor (e no carro vencedor da corrida).
		VictoryFx = {
			{ Id = "confetti",  Name = "Confetti Pop",    Icon = "🎉", Price = 0 },
			{ Id = "fireworks", Name = "Fireworks",       Icon = "🎆", Price = 25000 },
			{ Id = "explosion", Name = "Mega Explosion",  Icon = "💥", Price = 400000 },
			{ Id = "lightning", Name = "Thunder Strike",  Icon = "⚡", Price = 6000000 },
			{ Id = "sakura",    Name = "Sakura Storm",    Icon = "🌸", Price = 80000000 },
			{ Id = "meteor",    Name = "Meteor Crash",    Icon = "☄️", Price = 1200000000 },
			{ Id = "blackhole", Name = "Black Hole",      Icon = "🌌", Price = 20000000000 },
		},
		-- Classe + ULT de CADA personagem. Nomes de golpes ORIGINAIS (regra 13 do Protocolo: nada de golpes
		-- com nome de anime existente). Fx = efeito visual do cliente (Client.BattleFX):
		--   beam slash punch storm flame ice sand light shadow tech blossom meteor
		Fighters = {
			-- 1. Azure Planet
			goku    = { Class = "Brawler",   Ult = "Azure Wave",        Fx = "beam" },
			kuririn = { Class = "Speedster", Ult = "Twin Disc",         Fx = "slash" },
			vegeta  = { Class = "Champion",  Ult = "Royal Flash",       Fx = "beam" },
			kame    = { Class = "Mystic",    Ult = "Turtle Tide",       Fx = "beam" },
			gohan   = { Class = "Mystic",    Ult = "Storm Burst",       Fx = "storm" },
			cell    = { Class = "Champion",  Ult = "Perfect Nova",      Fx = "light" },
			piccolo = { Class = "Guardian",  Ult = "Spiral Piercer",    Fx = "beam" },
			buu     = { Class = "Guardian",  Ult = "Candy Chaos",       Fx = "meteor" },
			-- 2. Sakura Valley
			hanami  = { Class = "Speedster", Ult = "Petal Dash",        Fx = "blossom" },
			kiri    = { Class = "Speedster", Ult = "Fox Fire",          Fx = "flame" },
			rei     = { Class = "Mystic",    Ult = "Shrine Seal",       Fx = "light" },
			gen     = { Class = "Brawler",   Ult = "Oni Crusher",       Fx = "punch" },
			kenji   = { Class = "Champion",  Ult = "Moonlit Slash",     Fx = "slash" },
			tsuki   = { Class = "Mystic",    Ult = "Lunar Veil",        Fx = "light" },
			sakuya  = { Class = "Mystic",    Ult = "Thousand Blossoms", Fx = "blossom" },
			-- 3. Sunset Dunes
			wanderer = { Class = "Guardian",  Ult = "Dust Guard",        Fx = "sand" },
			zahra    = { Class = "Speedster", Ult = "Sand Waltz",        Fx = "sand" },
			amun     = { Class = "Champion",  Ult = "Pharaoh's Decree",  Fx = "light" },
			zero     = { Class = "Brawler",   Ult = "Mecha Barrage",     Fx = "tech" },
			kaito    = { Class = "Brawler",   Ult = "Dragon Cleaver",    Fx = "slash" },
			amara    = { Class = "Mystic",    Ult = "Solar Flare",       Fx = "flame" },
			sefet    = { Class = "Guardian",  Ult = "Riddle of Eternity", Fx = "sand" },
			-- 4. Frozen Tundra
			scout   = { Class = "Speedster", Ult = "Snow Rush",         Fx = "ice" },
			yukiko  = { Class = "Speedster", Ult = "Triple Axel",       Fx = "ice" },
			frey    = { Class = "Mystic",    Ult = "Frost Sigil",       Fx = "ice" },
			borea   = { Class = "Guardian",  Ult = "Blizzard Wall",     Fx = "ice" },
			kori    = { Class = "Mystic",    Ult = "Absolute Zero",     Fx = "ice" },
			fenri   = { Class = "Speedster", Ult = "Polar Howl",        Fx = "storm" },
			kaida   = { Class = "Brawler",   Ult = "Wyrm Breath",       Fx = "ice" },
			-- 5. Volcano Rift
			ember   = { Class = "Guardian",  Ult = "Anvil Slam",        Fx = "punch" },
			piko    = { Class = "Speedster", Ult = "Cinder Pop",        Fx = "flame" },
			gor     = { Class = "Brawler",   Ult = "Magma Knuckle",     Fx = "punch" },
			ignia   = { Class = "Speedster", Ult = "Blazing Waltz",     Fx = "flame" },
			zagan   = { Class = "Champion",  Ult = "Demon March",       Fx = "shadow" },
			hinoko  = { Class = "Mystic",    Ult = "Phoenix Rebirth",   Fx = "flame" },
			volka   = { Class = "Guardian",  Ult = "Inferno Quake",     Fx = "meteor" },
			-- 6. Neon City
			rin     = { Class = "Speedster", Ult = "Nitro Drift",       Fx = "tech" },
			kuro    = { Class = "Mystic",    Ult = "System Crash",      Fx = "tech" },
			mimi    = { Class = "Mystic",    Ult = "Encore Beam",       Fx = "light" },
			hayate  = { Class = "Champion",  Ult = "Neon Iai",          Fx = "slash" },
			nova    = { Class = "Guardian",  Ult = "Queen Protocol",    Fx = "tech" },
			kaizen  = { Class = "Mystic",    Ult = "Neon Judgment",     Fx = "storm" },
			null    = { Class = "Speedster", Ult = "Glitch Storm",      Fx = "shadow" },
			-- 7. Celestial Peaks
			wisp    = { Class = "Mystic",    Ult = "Cloud Pop",         Fx = "light" },
			selene  = { Class = "Speedster", Ult = "Star Volley",       Fx = "light" },
			tenzo   = { Class = "Guardian",  Ult = "Sky Palm",          Fx = "punch" },
			brynn   = { Class = "Champion",  Ult = "Valkyrie Dive",     Fx = "slash" },
			ryujin  = { Class = "Brawler",   Ult = "Emperor's Roar",    Fx = "storm" },
			aeon    = { Class = "Mystic",    Ult = "Genesis Light",     Fx = "light" },
			lumina  = { Class = "Mystic",    Ult = "Origin Supernova",  Fx = "meteor" },
		},
		-- Personagens sem entrada acima (os Legacy de saves antigos) usam isto:
		DefaultFighter = { Class = "Champion", Ult = "Power Strike", Fx = "punch" },
	}

	-- Classe, ULT e efeito de um personagem (sempre devolve algo válido).
	function Config.FighterOf(animeId)
		return Config.Battle.Fighters[animeId] or Config.Battle.DefaultFighter
	end
end
