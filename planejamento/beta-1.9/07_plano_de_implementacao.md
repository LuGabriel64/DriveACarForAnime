# 07 — Plano de implementação (para quem estiver ligado ao Studio)

Para o Claude Code que tiver o MCP do Roblox Studio (do dono ou do amigo). Leia antes o
[`CLAUDE.md`](../../CLAUDE.md), o `02_AI_Protocol` e os documentos 01 a 06 desta pasta.

## Antes de tocar em qualquer coisa

1. **Ler o estado atual.** `Config.Version` ainda é "Beta 1.8"? Leia a entrada do topo do `01_ChangeLog`.
   Se já existir uma Beta 1.9 de outra pessoa, este pacote vira **Beta 2.0**: troque o número aqui, no
   `ConfigBeta19` (o nome do módulo pode ficar) e no CHANGELOG.
2. **Comparar com o Git.** Peça ao dono um `.rbxl` novo ("Baixar uma cópia"), rode
   `python tools/place/place_tool.py extract places/<arquivo>.rbxl` e veja o `git diff`. Se alguém mexeu
   em scripts que este plano altera, releia o [01](01_arquitetura.md) com o código novo em mãos.
3. **Rodar os testes** (`python planejamento/beta-1.9/testes/run_tests.py`). Devem passar 80 de 80.
4. **Backup.** `ServerStorage.Backups["Beta 1.8b"]` com scripts, docs, ferramentas e `Map`, mais o LEIA-ME
   de restauração (o place hoje **não tem** backup interno da 1.8). O `.rbxl` em `places/` é o segundo backup.

## Etapa 0 — Beta 1.8d: limpar o que a auditoria achou ✅ feita em 12/11/2026

> **Feita** como **Beta 1.8d** (o número 1.8c já tinha sido usado no place). Ver `CHANGELOG.md`. O backup
> `ServerStorage.Backups["Beta 1.8b"]` já existe, então o passo 4 acima está cumprido. Ao começar a Etapa A,
> `Config.Version` vai estar em "Beta 1.8d". Falta só **publicar** e salvar o `.rbxl` em `places/`.
> O anti-trapaça usou um orçamento (`Config.AntiCheat`) em vez da troca de uma linha sugerida na auditoria:
> com +60 studs por tick (10 por segundo), a sugestão ainda aceitaria cerca de 600 studs/s.

Pequena, separada e publicada antes do resto, para o jogo ficar saudável.

| # | O quê | Como conferir |
|---|-------|---------------|
| 0.1 | Apagar a segunda `Workspace.Map` e a segunda `SpawnLocation` | `#workspace:GetChildren()` cai de 8 para 6; tag `Hazard` com 51 objetos, `BoostPad` com 46 |
| 0.2 | Auditoria 3: limite de avanço da fuga pela velocidade real do carro | fuga normal continua valendo; teleporte do carro anula a fuga |
| 0.3 | Auditoria 4: mesmo limite no recorde de distância | recorde não sobe com teleporte |
| 0.4 | Auditoria 5: `DataService.save` devolve `false` quando a gravação é cancelada pela trava | leitura do código + teste com dois servidores, se possível |
| 0.5 | Limpeza: segundo `Sky`, `StarterGui.ScreenGui` vazio, `Workspace.Script` | Output sem avisos |

Registrado como **Beta 1.8d** no `01_ChangeLog`, no `Config.Updates` e no `CHANGELOG.md`. Playtest feito.

## Etapa A — Fundação (sem nada visível de 1v1 ainda)

| # | O quê | Arquivos |
|---|-------|----------|
| A1 | Criar `Shared.ConfigBeta19`, ligar no `Config` | rascunho pronto |
| A2 | Criar `Shared.AnimeStats` | rascunho pronto |
| A3 | `DataService`: `defaults()` + `migrate()` 2 → 3, `SetLanguage`, atributo `Lang` | [01](01_arquitetura.md) |
| A4 | Estrelas: `EggRoll`, `IncubatorService`, `FarmService` (`incomeOf`, `AddAnime`, `sync`, placa, `Refresh`) | [04](04_progressao_e_recompensas.md) |
| A5 | `ProgressService` (XP, parceiro) + `Main.ORDER` | rascunho compilado |
| A6 | Pontos de spin: `WheelService.AddPoints`, laço por minuto, barra no `WheelPanel` | [04](04_progressao_e_recompensas.md) |
| A7 | `Client.Platform` + `ClientMain.ORDER`; aplicar em `UIKit.Panel`, HUD, `RaceUI`, `Notify` | [06](06_interface_multiplataforma.md) |
| A8 | `Shared.Locale` + `pt`; ligar no `UIKit`; trocar as 18 frases montadas e os 11 toasts do servidor; botão Languages no `StartMenu` e no Configs | [05](05_idiomas.md) |
| A9 | Mochila: ★, nível, barra de XP, Poder, `SET PARTNER`; estrelas na roleta do ovo | [04](04_progressao_e_recompensas.md) |

**Teste em Play (A):**
- Save antigo carrega sem erro; os personagens aparecem com 0★ nível 1 e a **renda é idêntica à de antes**.
- Pegar um ovo: a roleta mostra as estrelas; depois de chocar, a renda do pedestal bate com a tabela do [04](04_progressao_e_recompensas.md).
- Ficar 1 minuto: `WheelPoints` sobe 2. Forçar 100 pelo servidor: vira 1 giro e sobra o resto.
- Trocar o idioma na tela de início e no Configs: tudo muda na hora, inclusive painéis já abertos. Sair e voltar: o idioma ficou.
- Emulador de dispositivo: iPhone SE, iPad, 1080p e Xbox ([06](06_interface_multiplataforma.md)).

## Etapa B — Desafio + corrida 1v1

| # | O quê |
|---|-------|
| B1 | `VersusService` (rascunho) + `Main.ORDER`. Conferir cada chamada contra os serviços reais |
| B2 | `WorldBuilder.BuildVersusHall()`: ilha em `Config.Versus.HallOrigin` (só acrescenta peças, não regenera nada); balcões das duas lojas |
| B3 | `VersusUI`: 2 botões no dock, painel "Challenge a Player", cartão de convite, telas Lobby / Vote / Prep / Result |
| B4 | `CarFactory` corpo `"f1"`; `CarService.Spawn` com carro alternativo; `F1Shop` + `BuyF1` / `EquipF1` |
| B5 | `RaceService.Start(player, opts)` + `OnEnded`; `ZoneService` e `EscapeService` respeitando `RaceMode` |
| B6 | `DuelRaceService`: grid, colapso (`Collapse*`), chegada, eliminação, tempo máximo, anti-trapaça, `Finish` |
| B7 | `EscapeFX` → `CollapseFX` com direção. **Reteste a fuga do ovo inteira depois** |
| B8 | `GhostController` (mesmo `MatchId` se vê), `BiomeEggs` (some em Duel), `DuelRaceUI` (placar), `MusicController` |

**Teste em Play (B)** — precisa de 2 jogadores: **Test → Start (2 Players)** no Studio.
- Convite: aceitar, recusar, deixar expirar, cancelar, convidar quem está ocupado, convidar durante o cooldown.
- Um dos dois sai em cada etapa (Lobby, Vote, Prep, corrida, resultado).
- Corrida completa até o fim; um pego pelo colapso; os dois pegos; tempo esgotado.
- Durante o 1v1: o ovo gigante não aparece nem pode ser pego; nenhum bioma bloqueia; `Stats.BestBiome` não muda.
- Um terceiro jogador em corrida solo ao mesmo tempo: não vê nem é visto.
- Recompensas: vencedor (XP, dinheiro, +10 pontos), perdedor (só XP), 11ª partida contra o mesmo (só XP).
- Depois da partida, o carro normal volta para a garagem e a corrida solo funciona como antes.
- **A fuga do ovo continua igual** (o `CollapseFX` é o mesmo código).

## Etapa C — Batalha

| # | O quê |
|---|-------|
| C1 | `BattleSim` (rascunho testado) e `BattleService`: `PickFighter`, montar status do save, simular, esperar a duração da cena, `Finish` |
| C2 | `WorldBuilder.BuildArena(1..3)` em `Config.Versus.Battle.Arenas[i].Origin` |
| C3 | `BattleUI` + `BattleFX`: entrada, golpes, crítico, esquiva, ULT com corte, escudo, nocaute, vitória; os 12 efeitos |
| C4 | `VictoryShop` + `BuyVictoryFx` / `EquipVictoryFx`; animação de vitória também no fim da corrida 1v1 |
| C5 | Música de batalha e de vitória |

**Teste em Play (C):**
- O vencedor na tela é sempre o que o servidor decidiu (comparar com o `print` do servidor).
- As duas telas mostram a mesma luta (mesmos golpes, mesma ordem).
- Jogador sem personagem não consegue convidar para batalha.
- Sair no meio da cena: o outro vence.
- Duas batalhas ao mesmo tempo na mesma arena (4 jogadores) não se misturam.
- No celular: barras legíveis, textos sem cobrir os lutadores.

## Etapa D — Fechamento

1. `Config.Version = "Beta 1.9"` e a entrada em `Config.Updates` (em inglês; é o que o jogador lê).
2. Atualizar `00_ProjectBible` (seção nova "10g. BETA 1.9"), `01_ChangeLog` e `02_AI_Protocol`
   (regras novas: usar `Locale` para todo texto de jogador; usar `Platform` para toda UI nova; `ConfigBeta19`).
3. Pedir ao dono um `.rbxl`, salvar em `places/`, extrair para `src/`, conferir o `git diff`, atualizar
   `CHANGELOG.md`, `CLAUDE.md` e `docs/ESTRUTURA.md`, commit e tag `beta-1.9`.
4. Mover esta pasta para `planejamento/arquivo/beta-1.9/`, com uma nota do que mudou em relação ao projeto.

## Riscos conhecidos

| Risco | Como reduzir |
|-------|--------------|
| Os rascunhos foram escritos sem o Studio | cada módulo "⚠ só compilado" é revisado contra o código real antes de entrar; nada é colado às cegas |
| `EscapeFX` é delicado (colapso, fendas, peças que caem) | generalizar com o mínimo de mudança e retestar a fuga do ovo |
| F1 muito rápido atravessar pontes ou passarelas | o teto já é 700 studs/s; testar o Apex com boost nas passarelas e nos abismos |
| Carro de F1 com rodas mais abertas na suspensão por raycast | ajustar `WheelPoints` só para o corpo `"f1"` |
| Tradução maior que o botão | os textos usam `TextScaled` com teto; conferir os botões pequenos do dock em português |
| Mapa: Versus Hall e arenas somam peças | orçamento de ~1.500 peças por ilha; com a Etapa 0 o Workspace já perde 43 mil |
| Dois jogadores combinando partidas | limite por adversário (já no rascunho); observar as estatísticas depois do lançamento |
| Economia: renda maior com estrelas e nível | no máximo ×1,375 × ×1,49 ≈ ×2,05 num personagem 5★ nível 50; pequeno perto do salto de ~×8 entre biomas |

## O que NÃO fazer

- Não editar `src/` esperando que o jogo mude: `src/` é o espelho. A mudança é feita no Studio e depois extraída.
- Não dar `require` em `Services.*` pelo Command Bar durante o Play (regra 11 do Protocolo).
- Não renomear chaves do Config, ações do Net, atributos ou campos do save.
- Não mudar `Config.Data.StoreName`.
- Não copiar o mapa para a corrida 1v1.
