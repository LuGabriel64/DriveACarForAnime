# 01 — Arquitetura da Beta 1.9

Tudo segue as regras do `02_AI_Protocol`: números só no Config, servidor decide, rede só pelo `Shared.Net`,
UI pelo `UIKit`, nenhuma chave pública renomeada, sistemas antigos preservados.

## Fluxo do desafio 1v1 (igual para corrida e batalha)

```
LOBBY PRINCIPAL
  jogador A toca em [RACE 1v1] ou [BATTLE] no dock
        │  painel "Challenge a Player": lista de quem está no servidor (livre / ocupado)
        ▼
  CONVITE (20 s) ──recusou / não respondeu──► aviso para A, fim
        │ aceitou
        ▼
  "Lobby"  (20 s, ou os dois apertam READY)   os dois vão para o VERSUS HALL (loja de F1 e loja de vitória)
        ▼
  "Vote"   (15 s, ou os dois votaram)         cartões de mapa/arena; empate = sorteio do servidor
        ▼
  "Prep"   (30 s)                             comprar e escolher carro / lutador / animação de vitória
        ▼
  "Playing"                                   corrida 1v1  ou  batalha
        ▼
  "Result" (8 s)                              recompensas na tela, depois cada um volta para a própria garagem
```

Sair no meio (`VersusLeave` ou desconectar): antes do jogo a partida é cancelada sem recompensa; durante o
jogo o outro vence e quem saiu não recebe nada.

## Módulos novos

| Onde (Explorer) | Módulo | Papel | Rascunho |
|-----------------|--------|-------|----------|
| `ReplicatedStorage.Shared` | `ConfigBeta19` | todos os números novos; aplicado pelo `Config` | ✅ pronto |
| | `AnimeStats` | contas de estrelas, nível, XP, renda e status de batalha | ✅ pronto |
| | `Locale` (+ filho `pt`) | tradução | ✅ pronto |
| `ServerScriptService.Services` | `ProgressService` | XP, nível e parceiro no save | ⚠ compilado |
| | `VersusService` | convite, etapas, votação, recompensas | ⚠ compilado |
| | `BattleSim` | simulação da luta (biblioteca, sem Init) | ✅ pronto |
| | `DuelRaceService` | modo "Race": grid, colapso, chegada, anti-trapaça | a escrever |
| | `BattleService` | modo "Battle": lutadores, `BattleSim`, roteiro para os clientes | a escrever |
| `StarterPlayerScripts.Client` | `Platform` | tamanho da UI por aparelho | ⚠ compilado |
| | `VersusUI` | painel de desafio, cartão de convite, telas Lobby/Vote/Prep/Result | a escrever |
| | `DuelRaceUI` | placar ao vivo, aviso do colapso | a escrever |
| | `BattleUI` + `BattleFX` | encenação da luta, barras de HP, ULT, efeitos | a escrever |
| | `F1Shop`, `VictoryShop` | lojas do Versus Hall (painéis do `UIKit`) | a escrever |
| | `MusicController` | música de fundo com fade, respeita o interruptor Music | a escrever |
| | `CollapseFX` | o `EscapeFX` atual generalizado (ver abaixo) | a adaptar |

Ordem de inicialização:

- `Main.ORDER`: … `WheelService`, **`ProgressService`, `VersusService`, `DuelRaceService`, `BattleService`**, `AnimeService`, `GiftService`.
- `ClientMain.ORDER`: **`Platform`** primeiro (o `UIKit` usa); **`MusicController`, `VersusUI`, `DuelRaceUI`, `BattleUI`, `F1Shop`, `VictoryShop`** antes do `StartMenu`.

## Save (DataService) — Version 2 → 3

```lua
data.Version = 3
data.Animes[i].Stars  = 0..5      -- novo; ausente = 0
data.Animes[i].Level  = 1..50     -- novo; ausente = 1
data.Animes[i].XP     = 0..       -- novo; ausente = 0
data.Incubator[i].Stars = 0..5    -- sorteado junto com o personagem
data.Partner = Uid | nil          -- quem ganha XP na corrida 1v1
data.Lang    = "en" | "pt" | nil  -- nil = detectar pelo idioma da conta na primeira entrada
data.Wheel.Points = 0..99         -- pontos de spin guardados
data.Versus = {
    F1 = { Owned = { f1_rookie = true }, Equipped = "f1_rookie" },
    Fx = { Owned = { confetti = true },  Equipped = "confetti" },
    Stats = { RaceWins = 0, RaceLosses = 0, BattleWins = 0, BattleLosses = 0, Streak = 0, BestStreak = 0 },
}
```

- `defaults()` ganha os campos acima; `reconcile()` já preenche os que são tabelas de primeiro nível.
- `migrate()` ganha o passo 2 → 3: percorre `data.Animes` e `data.Incubator` pondo `Stars = 0`, `Level = 1`,
  `XP = 0` onde faltar. Listas não são preenchidas pelo `reconcile`, por isso o laço é necessário.
- O código nunca assume que o campo existe: `AnimeStats.Stars(entry)` e `AnimeStats.Level(entry)` tratam `nil`.
- `StoreName` **não muda** (mudar apagaria os saves).

## Rede

| Direção | Nome | Quem trata | Validação |
|---------|------|-----------|-----------|
| C → S | `VersusPlayers` | VersusService | — |
| C → S | `VersusInvite(userId, mode)` | VersusService | tipos, modo registrado, os dois livres, cooldown |
| C → S | `VersusRespond(inviteId, accept)` | VersusService | o convite existe e é para este jogador; reconfere os dois |
| C → S | `VersusCancel`, `VersusReady`, `VersusLeave` | VersusService | etapa certa |
| C → S | `VersusVote(mapId)` | VersusService | etapa "Vote", `mapId` na lista da partida |
| C → S | `BuyF1(id)`, `EquipF1(id)` | DuelRaceService | id em `Config.F1ById`, dinheiro, já tem |
| C → S | `BuyVictoryFx(id)`, `EquipVictoryFx(id)` | BattleService | idem com `Config.Battle.VictoryFx` |
| C → S | `PickFighter(uid)` | BattleService | etapa "Prep", `uid` é do jogador |
| C → S | `SetPartner(uid)` | ProgressService | `uid` é do jogador |
| C → S | `SetLanguage(code)` | DataService | `Locale.IsValid(code)` |
| S → C | `VersusInvited`, `VersusInviteClosed`, `VersusState`, `VersusResult` | VersusUI | |
| S → C | `DuelStart`, `DuelEnd` | DuelRaceUI | |
| S → C | `BattleScript` (roteiro da luta) | BattleUI | |
| S → C | `LevelUp` | HUD / Notify | |

Atributos novos do Player (replicados): `MatchId`, `VersusMode`, `VersusStage`, `RaceMode` (`"Solo"` | `"Duel"`),
`CollapseDir`, `CollapseZ0`, `CollapseStart`, `CollapseSpeed`, `WheelPoints`, `Lang`, `Partner`.
O placar da corrida lê `RaceDistance`, que já existe e já é replicado para todos.

## O que muda em cada script que já existe

Mudanças pequenas e localizadas. Nenhuma remove comportamento atual.

| Script | Mudança |
|--------|---------|
| `Shared.Config` | 1 linha no fim: `require(script.Parent.ConfigBeta19)(Config)`; `Version = "Beta 1.9"` + entrada em `Updates` |
| `Shared.CarFactory` | `Build(cfg)` com `cfg.Body == "f1"` constrói o carro de fórmula. Mantém o contrato `Chassis` / `Seat` / `Wheel_FL..RR`, então o `DriveController` não muda |
| `Services.DataService` | `defaults()` + `migrate()` 2 → 3; ação `SetLanguage`; atributo `Lang`; **correção da auditoria 5** (`save` devolve `false` quando a gravação foi cancelada) |
| `Services.EggRoll` | `Roll` devolve também `Stars = AnimeStats.RollStars(rng:NextNumber())` |
| `Services.IncubatorService` | guarda e repassa `Stars` (`Add`, `stateOf`, `hatch`) |
| `Services.FarmService` | `incomeOf` passa a chamar `AnimeStats.Income`; `AddAnime(player, id, mut, size, stars)`; `sync` envia `Stars`, `Level`, `XP`, `Power`; placa do pedestal mostra ★ e nível; **nova** `FarmService.Refresh(player)` = `recompute` + `sync` + redesenhar placas |
| `Services.WheelService` | `AddPoints(player, n)`, laço de +2 por minuto, atributo `WheelPoints` (ver [04](04_progressao_e_recompensas.md)) |
| `Services.RaceService` | `Start(player, opts)` aceita `opts.Mode = "Duel"`, `opts.GridCFrame`, `opts.Car`; recusa corrida solo com `MatchId ~= 0`; `OnEnded(fn)` para o `DuelRaceService` saber do fim; **correção da auditoria 4** (limite de avanço por tick) |
| `Services.CarService` | `Spawn(player, cf, seat, cfgOverride)` para o F1; `BuyCar` / `EquipCar` recusados com `MatchId ~= 0` |
| `Services.ZoneService` | com `RaceMode == "Duel"`: sem bloqueio de tier e sem gravar `Stats.BestBiome` |
| `Services.EscapeService` | `tryGrab` recusa com `RaceMode == "Duel"`; **correção da auditoria 3** (limite pela velocidade real do carro) |
| `Client.EscapeFX` → `CollapseFX` | passa a aceitar a direção do colapso (`+1` fuga do ovo, `−1` corrida 1v1) e lê `Collapse*` além de `Escape*`. O comportamento da fuga do ovo fica idêntico |
| `Client.BiomeEggs` | com `RaceMode == "Duel"` esconde o ovo gigante, a placa e o prompt |
| `Client.GhostController` | regra nova: vejo o outro se **nós dois** temos o mesmo `MatchId ~= 0` |
| `Client.UIKit` | `Text` / `Button` / `Panel` / `SetButton` chamam `Locale.Bind` quando há tradução; painéis usam `Platform.Scale("Panel")` |
| `Client.HUD`, `RaceUI`, `Notify` | `Platform.Apply` nos blocos fixos (moedas, velocímetro, painel de corrida, avisos) |
| `Client.LobbyDock` | 2 botões novos à esquerda do dock (`RACE 1v1`, `BATTLE`); largura 720 → 912 (o `fit()` atual já reduz) |
| `Client.StartMenu` | botão `🌐 Languages` no canto superior direito |
| `Client.WheelPanel` | barra "Spin points: 37/100" |
| `Client.InventoryPanel` | cartão do personagem mostra ★, nível, barra de XP, Poder e o botão `SET PARTNER` |
| `Client.EggRouletteUI`, `EggHatchUI` | mostram as estrelas do personagem sorteado |
| `Tools.WorldBuilder` | `BuildVersusHall()` e `BuildArena(i)` — só acrescentam peças, não regeneram nada |
| toasts do servidor | `Net.Fire(p, "Toast", Locale.For(p, "texto", args...))` no lugar do texto fixo (11 pontos hoje) |

## Como os modos se ligam ao VersusService

```lua
VersusService.RegisterMode("Race", {
    Maps     = function() return Config.Versus.Race.Maps end,
    CanJoin  = function(player) return true end,
    Start    = function(match) ... end,          -- põe os dois no grid, liga o colapso
    Abort    = function(match, leaver) ... end,  -- devolve os carros
    XpTarget = nil,                              -- padrão: parceiro
})
-- quando a corrida acaba:
VersusService.Finish(match, winnerPlayer, { Reason = "Finished first", Details = { ... } })
```

O `VersusService` não conhece corrida nem batalha. Um terceiro modo no futuro (ex.: 2v2, drift) é só outro
`RegisterMode`.
