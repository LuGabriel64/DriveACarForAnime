# Beta 1.9 — aplicação em andamento (12/11/2026)

> Escrito pelo Claude Code local do dono (app desktop, MCP `Roblox_Studio`). **Leia antes de continuar a 1.9.**
> A sessão parou porque o Studio deixou de responder ao MCP logo depois de um Play de teste.

## ATUALIZAÇÃO 13/11/2026 — Etapa A testada, salva e espelhada

- O Studio voltou e a Etapa A estava inteira no place (o Team Create guardou as edições).
- Corrigido: um comentário no meio de uma linha do `InventoryPanel` (erro de sintaxe que derrubava a mochila e o
  dock); `UIKit.Pop` voltava a escala para 1 quando a tela mudava durante a animação; o menu lateral antigo do HUD
  ficou fora do `Platform.Apply` (já tinha `UIScale` próprio).
- **Testado em Play (1 jogador, janela de 1530 x 572):** tela de início em PT/EN trocando ao vivo; botão Idiomas;
  mochila com ★, nível, XP, Poder e VIRAR PARCEIRO; roleta com "Pontos de giro: 84/100"; fuga do ovo completa
  (ovo sorteado com estrelas, entregue, chocado, placa do pedestal "☆☆☆☆☆ Lv 1 | $3/s", renda $3/s).
- **Continua sem teste:** save real na migração 2→3; ovo com 1+ estrelas (o sorteio deu 0★ nas duas vezes);
  100 pontos virando giro; celular, tablet e TV.
- Place salvo (**versão 105**, não publicado). `src/` espelhado com `ServerStorage.Tools.MirrorDump` +
  `tools/place/mirror_from_dump.js` (26 arquivos mudaram; os outros 33 saíram idênticos ao Git).
- Verificador de sintaxe: em modo Edit, `loadstring(script.Source)` funciona no `execute_luau`. Rode em todos os
  scripts antes de cada Play (o erro acima teria aparecido na hora).
- Para ver as telas pelo MCP: `user_mouse_input` com `instance_path` funciona nos botões do dock; `screen_capture`
  funciona em Play. Se a garagem foi escolhida pelo remote, apague o `PlayerGui.StartMenu` antes (ele não sai sozinho).

O texto abaixo é o registro de 12/11 (antes do teste).

## Resumo (12/11)

- **Etapa A (fundação) foi APLICADA no place**, script por script, pelo MCP.
- **Não chamei `save_place`.** O place é Team Create, então as edições costumam ficar na sessão da nuvem, mas
  isso **não foi confirmado**. Primeira coisa a fazer ao reabrir o Studio: conferir se
  `ReplicatedStorage.Shared.ConfigBeta19` existe. Se não existir, a Etapa A se perdeu e tem de ser refeita.
- **`src/` ainda é o espelho da 1.8d.** O despejo do place para `src/` não foi feito (o Studio caiu antes).
- `Config.Version` continua `"Beta 1.8d"` de propósito: só muda na Etapa D.
- Etapas B (desafio + corrida 1v1), C (batalha) e D (fechamento) **não começaram**.

## O que foi feito no place

| Onde (Explorer) | Mudança |
|-----------------|---------|
| `ServerStorage.Backups["Beta 1.8d"]` | NOVO: backup de scripts, docs e ferramentas + LEIA-ME de restauração |
| `ServerStorage.Backups["Beta 1.8d"].StrayFromWorkspace` | 2 `Hazard_pendulum` que estavam soltos no Workspace (x=-793 e x=-1327, fora da pista) foram **movidos** para cá, não apagados |
| `ReplicatedStorage.Shared.ConfigBeta19` | NOVO (igual ao rascunho; `Config.Languages` ganhou `FlagKind`) |
| `ReplicatedStorage.Shared.AnimeStats` | NOVO (rascunho + `StarText`) |
| `ReplicatedStorage.Shared.Locale` e `Locale.pt` | NOVOS (303 frases + seção EXTRAS) |
| `Shared.Config` | 1 linha antes do `return`: `require(script.Parent.ConfigBeta19)(Config)` |
| `Services.DataService` | save **Version 3** (`defaults`, `migrate` 2→3), idioma detectado na 1ª entrada, atributo `Lang`, ação `SetLanguage` |
| `Services.EggRoll` | `Roll` devolve `Stars` |
| `Services.IncubatorService` | guarda e repassa `Stars` |
| `Services.FarmService` | `incomeOf` = `AnimeStats.Income`; `AddAnime(..., stars)`; `Inventory` leva `Stars/Level/XP/XpNext/Power`; placa com ★ e nível; `Refresh(player)`; `CashPerSec(player)` |
| `Services.WheelService` | `AddPoints`, +2 pontos por minuto, atributo `WheelPoints` |
| `Services.ProgressService` | NOVO (XP, parceiro, `FindEntry`, `StrongestUid`); entrou no `Main.ORDER` |
| `Services.CarService`, `ZoneService`, `EscapeService` | avisos via `Locale.For`; `EscapeService.tryGrab` recusa em `RaceMode == "Duel"`; `EggRoulette` leva `Stars` |
| `Client.Platform` | NOVO; primeiro do `ClientMain.ORDER` |
| `Client.UIKit` | `Locale.Bind` em `Text`/`SetButton`; `UIKit.T`; `UIKit.SetText`; painéis abrem em `Platform.Scale("Panel")`; `Pop` respeita o atributo `Rest` |
| `Client.Notify` | traduz texto fixo; `Platform.Apply`; evento `LevelUp` |
| `Client.WheelPanel` | barra "Spin points: N/100"; textos por `UIKit.T` |
| `Client.StartMenu` | botão `🌐 Languages` no canto superior direito; linha de idioma no Configs (lista agora rola); bandeiras **desenhadas com Frames** |
| `Client.InventoryPanel` | cartão com ★, selo de nível, barra de XP, Poder e `SET PARTNER` (célula 148×284) |
| `Client.HUD`, `RaceUI`, `EggRouletteUI` | `Platform.Apply` nos blocos fixos; zonas traduzidas; estrelas ao lado do "1 in N" |

Diferenças em relação ao projeto: `GameUI` **não** recebeu `Platform.SafeArea` (mudaria o layout atual sem
teste em aparelho); `EggHatchUI` não foi tocado (é do sistema antigo, desligado); o teto de escala no PC é 1,2
(o documento 06 dizia 1,3).

## Testado

Play no Studio, 1 jogador, **antes** das mudanças de tela (só servidor + `Platform` + `UIKit`):

- Output sem erros dos nossos scripts; cliente e servidor iniciam.
- Renda de personagem 0★ nível 1 = renda base (Gokun: 3). Exemplo do dono: 400 / 430 / 460 / 490 / 520 / 550.
- 16.170 XP levam do nível 1 ao 50. Majin Bubu 5★ nível 50: Poder 1.688, Vida 31.598 (igual ao documento 03).
- Idioma detectado pela conta (`pt-br` → `pt`); `SetLanguage("pt")` aceito; `SetPartner` com Uid falso recusado.
- `WheelPoints` subiu para 2 depois de 1 minuto.

## NÃO testado

- **Nenhuma das telas alteradas depois** (WheelPanel, StartMenu/idiomas, InventoryPanel, HUD, RaceUI,
  EggRouletteUI, Notify): o Studio caiu ao iniciar o segundo Play. Podem ter erro de sintaxe ou de layout.
- Save antigo de verdade passando pela migração 2→3 (o Studio usa dados temporários, sem API de DataStore).
- Ovo com estrelas até o pedestal; 100 pontos virando giro; troca de idioma com painéis abertos.
- Qualquer aparelho que não seja a janela do Studio no PC.

## Como continuar

1. Abrir o Studio, `list_roblox_studios`, conferir que `Shared.ConfigBeta19` existe.
2. Play: olhar o Output, abrir roleta, mochila, Configs e o botão Languages. Corrigir o que aparecer.
3. Fuga do ovo completa (ver `06_licoes_tecnicas.md`) para ver as estrelas na roleta e no pedestal.
4. `save_place`, depois espelhar: rodar o trecho DUMP de `tools/place/mirror_from_dump.js` e o script.
   **O script ainda não foi usado de verdade**: confira o `git diff` com cuidado na primeira vez.
5. Seguir para a Etapa B em `planejamento/beta-1.9/07_plano_de_implementacao.md`.

## Lições desta sessão

- `start_stop_play(true)` sempre devolve "Request timed out" e o Studio some da lista por alguns segundos;
  o Play começa mesmo assim. Chame `list_roblox_studios` de novo.
- O `execute_luau` não alcança `127.0.0.1` (lista de permissões de HTTP do assistente). Não há como mandar
  arquivos do disco para o Studio sem passar pelo `multi_edit`.
- Resposta grande do `execute_luau` é gravada em arquivo pelo Claude Code: é o caminho Studio → disco usado
  pelo `mirror_from_dump.js` (substitui o `place_tool.py` neste PC, que não tem Python; há Node em `D:\node`).
- Um `Platform.Apply` em botão do UIKit criaria dois `UIScale` no mesmo objeto. Aplique só em Frames.
