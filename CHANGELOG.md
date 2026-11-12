# CHANGELOG — Drive A Car For Anime

Catálogo de **todas as versões** do jogo e do repositório. A mais nova fica no topo.

- O registro técnico original de cada versão do jogo fica dentro do place, em
  `ServerStorage.ProjectDocs.01_ChangeLog` (cópia em `src/ServerStorage/ProjectDocs/01_ChangeLog.luau`).
  Este arquivo é a versão legível, e também registra o que acontece no GitHub.
- Caminhos de scripts usam o Explorer do Studio. `Services.X` = `ServerScriptService.Services.X`;
  `Client.X` = `StarterPlayer.StarterPlayerScripts.Client.X`; `Shared.X` = `ReplicatedStorage.Shared.X`;
  `Tools.X` = `ServerStorage.Tools.X`.
- Cada entrada diz o que foi **testado** e o que **não** foi.

| Versão | Data | Estado | Em uma linha |
|--------|------|--------|--------------|
| [Beta 1.9](#beta-19--planejada) | — | 📐 planejada | Desafio 1v1 (corrida de F1 e batalha de anime), estrelas, nível, pontos de spin, idiomas, UI por plataforma |
| [Beta 1.8d](#beta-18d--12112026) | 12/11/2026 | 💾 salva no Studio, falta publicar | Correções da auditoria (mapa duplicado, anti-trapaça, save) |
| [Beta 1.8c](#beta-18c--11112026) | 11/11/2026 | ✅ | Só documentação dentro do place (`04_EstadoAtual`) |
| [Beta 1.8b](#beta-18b--10112026) | 10/11/2026 | ✅ publicada | Personagens em "blocos anime" |
| [Beta 1.8](#beta-18--10112026) | 10/11/2026 | ✅ | Obstáculos animados, menos boosts |
| [Beta 1.7](#beta-17--10112026) | 10/11/2026 | ✅ | Roleta nova com pacotes de Robux, Secret preta, segurar F |
| [Beta 1.6b](#beta-16b--09112026) | 09/11/2026 | ✅ | Ovo pego passando com o carro |
| [Beta 1.6](#beta-16--09112026) | 09/11/2026 | ✅ | Elenco estilo Dragon Ball no bioma 1, pista limpa, desafios novos |
| [Beta 1.5](#beta-15--09112026) | 09/11/2026 | ✅ | Roleta da sorte |
| [Beta 1.4e](#beta-14e--07112026) | 07/11/2026 | ✅ | Mais decoração japonesa high-tech |
| [Beta 1.4d](#beta-14d--07112026) | 07/11/2026 | ✅ | Carro só na corrida, decoração do bioma 1 |
| [Beta 1.4b](#beta-14b--07112026) | 07/11/2026 | ✅ | Cerejeiras novas, garagem japonesa |
| [Beta 1.4](#beta-14--07112026) | 07/11/2026 | ✅ | Lobby "Sakura Night" e dock |
| [Beta 1.3](#beta-13--07112026) | 07/11/2026 | ✅ | Ovo gigante, roleta, fuga, incubadora |
| [Beta 1.2](#beta-12--07112026) | 07/11/2026 | ✅ | Lobby separado, corrida solo, Azure Planet |
| [Beta 1.1](#beta-11--07112026) | 07/11/2026 | ✅ | Tela de início, garagem, ovos, raridade Secret |
| [Beta 1.0](#beta-10-020--06112026) | 06/11/2026 | ✅ | Garagens e 7 biomas |
| [0.1.0](#010--03112026) | 03/11/2026 | ✅ | Fundação do projeto |

Backups: dentro do place existem `ServerStorage.Backups["Beta 1.1"]` (o único com o terreno), `["Beta 1.6"]`,
`["Beta 1.7"]` e `["Beta 1.8b"]`. No GitHub, `places/` guarda o `.rbxl` completo de cada versão a partir da 1.8b.

---

## Repositório

### 12/11/2026 — Beta 1.8d aplicada pelo Studio · Claude Code (PC do dono, com MCP)

- Primeira sessão ligada ao Studio de verdade. Antes de mudar, o código do place foi comparado com `src/` por
  checksum: os 51 scripts do jogo eram idênticos. Só os docs internos tinham mudado (entrada "1.8c").
- `src/` atualizado à mão com as mesmas edições feitas no Studio. Os 5 scripts e os 5 docs alterados conferem
  byte a byte com o place (checksum). Sem Python neste PC, então o `place_tool.py` não rodou.
- `src/ServerStorage/ProjectDocs/04_EstadoAtual.luau` (novo no espelho). Tag `beta-1.8d`.
- `PROMPTS_PARA_O_STUDIO.md`: Etapa 0 marcada como feita (virou 1.8d).
- **Falta:** o `.rbxl` da 1.8d em `places/` (o dono baixa pelo Studio).

### 12/11/2026 — Preparação para aplicar no Studio · Claude Code (sessão do dono, nuvem)

Nenhuma mudança no jogo. O dono ligou um Claude Code local (PowerShell) ao Roblox Studio.

- `planejamento/beta-1.9/PROMPTS_PARA_O_STUDIO.md`: um pedido pronto por etapa (0, A, B, C, D) para colar
  no Claude Code local.
- `docs/CONECTAR_STUDIO.md`: comando manual do MCP, pré-requisitos no Windows (Git), e como os dois
  desenvolvedores compartilham o jogo (Team Create) e o repositório (colaborador no GitHub).

### 12/11/2026 — Projeto da Beta 1.9 · Claude Code (sessão do dono, nuvem)

Nenhuma mudança no jogo.

- `planejamento/beta-1.9/`: projeto completo da Beta 1.9 (7 documentos), rascunhos de 8 módulos Luau e
  80 testes automáticos da lógica pura, rodados contra o `Config` real.
- Os testes acharam e corrigiram dois problemas de equilíbrio da batalha antes de qualquer código ir para
  o jogo: vantagem de quem atacava em segundo, e uma classe que vencia todas as lutas.
- `docs/CONECTAR_STUDIO.md`: como ligar o Claude Code ao Roblox Studio.
- `CHANGELOG.md` reescrito como catálogo completo de versões. `CLAUDE.md` e `README.md` atualizados.
- Branch `claude/integracao-beta-1.8b` juntado ao `main`.

Não testado: nada do projeto rodou dentro do Roblox. Os módulos que dependem do Studio só tiveram a
sintaxe conferida.

### 11/11/2026 — Integração ao GitHub · Claude Code (sessão do dono, nuvem)

Nenhuma mudança no jogo.

- `places/DriveACarForAnime_Beta1.8b_2026-11-11.rbxl`: backup do place (207.026 instâncias).
- `src/`: os 55 scripts do place, nos mesmos caminhos do Explorer (formato Rojo).
- `tools/place/`: leitor de `.rbxl` em Python e `place_tool.py` (`extract`, `summary`).
- `docs/ESTRUTURA.md`, `docs/AUDITORIA_2026-11-11.md`, `docs/HISTORICO_CHAT.md`, `CLAUDE.md`,
  `default.project.json`.
- **Achados:** `Workspace.Map` e `SpawnLocation` duplicados no place; anti-trapaça da fuga frouxo; recorde
  de distância confiando no cliente; save de compra com Robux que pode ser cancelado sem aviso.

Testado: extração feita duas vezes, por caminhos diferentes, com resultado idêntico.

---

## Jogo

### Beta 1.9 — planejada

Projeto em [`planejamento/beta-1.9/`](planejamento/beta-1.9/README.md). Se outra Beta 1.9 for feita antes,
este pacote vira a Beta 2.0.

- **Desafio 1v1:** dois botões novos no dock convidam um jogador do servidor para uma corrida ou uma batalha.
  O convidado aceita ou recusa; depois vêm a sala de espera (Versus Hall), a votação do mapa e 30 s de preparação.
- **Corrida 1v1:** até o fim do mapa, na mesma pista do jogo em modo sem ovos e sem bloqueio de biomas.
  Cinco carros de Fórmula 1 com loja própria. A pista desmorona desde a largada, mais devagar que na fuga
  do ovo. Placar ao vivo com posição e metros. Música.
- **Batalha de anime:** o servidor simula a luta e os dois assistem à mesma cena. Seis status, cinco
  classes, ULT com nome e efeito próprios para os 50 personagens, três arenas, loja de animações de vitória.
- **Estrelas (0 a 5) e nível (1 a 50)** em todo personagem. Cada estrela vale +7,5%.
- **Recompensas:** vencedor ganha XP, dinheiro e 10 pontos de spin; perdedor ganha só XP.
- **Pontos de spin:** 100 pontos = 1 giro; +2 por minuto jogado.
- **Idiomas:** botão "Languages" com inglês e português (303 frases traduzidas).
- **Interface por plataforma:** tamanhos e layouts próprios para celular, tablet, PC e TV.
- Save passa para a versão 3 (campos novos; nada é apagado).

### Beta 1.8d — 12/11/2026

**Correções da auditoria de 11/11 (Etapa 0 do plano da 1.9).** Autor: Claude Code do dono, local, ligado ao
Studio pelo MCP. No plano ela se chamava "Beta 1.8c", mas esse número já tinha sido usado no place por uma
entrada só de documentação, então virou 1.8d.

- **Mapa duplicado:** a segunda `Workspace.Map` (43.298 objetos) e a segunda `SpawnLocation` saíram do Workspace.
  Não foram apagadas: foram movidas para `ServerStorage.Backups["Beta 1.8b"]`, porque eram idênticas às que
  ficaram e servem de backup do mapa. As tags no Workspace voltaram ao normal: `Hazard` 51, `BoostPad` 46,
  `LobbyLantern` 60, `RacePortal` 1.
- **Anti-trapaça da fuga** (`Services.EscapeService`, auditoria 3): o limite agora segue a velocidade real
  do carro (atributo `TopSpeed`) × 1,6, e não mais o teto global de 700 × 1,6 + 60 studs por tick, que
  aceitava cerca de 1.700 studs/s. O limite funciona como um "orçamento" (token bucket) em `Config.AntiCheat`:
  - aguenta posições chegando em rajada depois de lag (2,5 s) e o empurrão de boost ou de batida (120 studs);
  - não deixa passar teleporte nem velocidade sustentada acima de `TopSpeed` × 1,6.
- **Recorde de distância** (`Services.RaceService`, auditoria 4): usa o mesmo orçamento. Com velocidade
  impossível, a corrida termina com o motivo `invalid` e a distância do salto não conta.
  `Client.RaceUI` ganhou o texto "Impossible speed — race cancelled".
- **Save com Robux** (`Services.DataService`, auditoria 5): `save()` só devolve `true` quando o `UpdateAsync`
  gravou de verdade. Se a trava de outro servidor cancelar a gravação, `SaveSync` devolve `false` e o
  `ProcessReceipt` responde `NotProcessedYet`, em vez de confirmar a compra sem salvar. O formato do save não mudou.
- **Limpeza:** o `Sky` genérico (fica o "Simple Sunset Sky", que é o que o `AtmosphereController` cita),
  `StarterGui.ScreenGui` vazio e `Workspace.Script` ("Hello world") foram movidos para o backup 1.8b.
- `Shared.Config`: `Version = "Beta 1.8d"`, notas em `Updates`, tabela nova `Config.AntiCheat`.
  `Escape.MaxForwardSpeed` ficou sem uso, mas não foi apagado.
- Backup `ServerStorage.Backups["Beta 1.8b"]` com todos os scripts, docs, Tools e LegacyCode, mais o LEIA-ME.
- `ProjectDocs`: entrada no `01_ChangeLog` e `04_EstadoAtual` atualizado.

Testado no Play do Studio (1 jogador, carro inicial com `TopSpeed` 70):

| Teste | Resultado |
|-------|-----------|
| Output | sem erros |
| Corrida a 100 studs/s (abaixo do limite de 112) | aceita, 3.089 studs |
| Teleporte de 2.000 studs na corrida | encerrada como `invalid`, distância parada em 413 |
| Fuga com teleporte do ovo até a base | `invalid` |
| Fuga legítima a 100 studs/s | `delivered` |

Os movimentos foram feitos com `PivotTo` no cliente, não dirigindo com o teclado.

Não testado:
- save bloqueado pela trava de outro servidor (precisa de dois servidores publicados);
- compra real com Robux;
- carro de tier alto pegando vários boosts seguidos, dirigindo de verdade.

**Salva no Studio (versão 95 do place), ainda não publicada.**

### Beta 1.8c — 11/11/2026

**Só documentação dentro do place.** Autor: Claude Code do dono. Criou `ProjectDocs.04_EstadoAtual` (porta de
entrada para qualquer assistente), as regras 17 e 18 no `02_AI_Protocol` e um aviso no topo do `00_ProjectBible`.
Nenhum script do jogo mudou. (Estava no place mas não no espelho do GitHub até a 1.8d.)

### Beta 1.8b — 10/11/2026

**Personagens no estilo "blocos anime".** Autor: Claude.

- Todos os personagens foram redesenhados a partir de uma referência do dono: corpo de avatar R6 em blocos,
  rosto de anime em peças finas (olhos com íris, pupila e brilho; sobrancelhas que mudam com a expressão)
  e cabelo esculpido em espetos.
- `Shared.AnimeModelFactory` reescrito: seis estilos de cabelo, 21 acessórios, mangas, luvas, botas, quimono.
  O modelo chibi da 1.7 foi guardado em `ServerStorage.LegacyCode.AnimeModelFactory_Chibi_Beta17`.
- `Shared.Config`: o elenco do bioma 1 ganhou os campos de roupa e expressão.
- `Client.UIKit.Viewport` enquadra pela maior medida do modelo: os personagens ficam maiores nas cartas.
- O símbolo do peito da referência **não** foi copiado (é marca do personagem original).

Testado em Play: 16 personagens renderizados, roleta do ovo com cartas de quatro raridades, Output sem erros.

### Beta 1.8 — 10/11/2026

**Obstáculos animados e menos boosts.** Autor: Claude.

- Cinco tipos de obstáculo animado nos 7 biomas, 51 no total: **pêndulo** (martelo gigante), **hélice**,
  **pistões** que fecham meia pista, **portal de laser** e **gêiseres**.
- Bater freia o carro (velocidade ×0,4 por 1,3 s), empurra para trás e mostra "OUCH!".
- O movimento é calculado em cada cliente a partir do relógio do servidor: todos veem igual, sem custo de
  rede. Os obstáculos não têm colisão física; a punição é o `Drive.Hit`.
- Boost pads reduzidos de 143 para 46: dirigir bem passa a importar mais.
- `Tools.WorldBuilder`: `BuildHazards(i)` e `ThinBoostPads(i)`. `Client.HazardController` novo.
  `Client.DriveController`: `Drive.Hit`, `Drive.IsHit`.
- Ajustes no mesmo dia:
  - começo do bioma 1 ganhou obstáculos;
  - lanternas do bioma 1 ganharam postes e varal;
  - **correção:** as 18 lanternas do lobby se empilhavam logo depois da largada, por causa do carregamento
    por streaming. Agora cada lanterna guarda sua posição de origem;
  - textos do ovo gigante ficaram menores.

Testado em Play: hélice derrubando o carro, pistão, laser, gêiser e pêndulo conferidos; Output sem erros.
Backup anterior: `Backups["Beta 1.7"]`.

### Beta 1.7 — 10/11/2026

**Roleta nova, Secret preta, "segurar F" de volta, personagens chibi.** Autor: Claude.

- **Roleta só na interface**, com novo visual: 6 fatias com chances bem diferentes ($500 38%, $2,5K 27%,
  +2 Spins 15%, $10K 12%, $50K 6%, $250K 2%). Os quiosques do mapa foram removidos.
- **Giros extras** e pacotes x3 (R$29) e x10 (R$79) por Robux. O `ProcessReceipt` não entrega duas vezes
  a mesma compra e só confirma depois de salvar.
- Nomes do elenco do bioma 1 levemente alterados (Gokun, Kurilin, Vegita, Master Kamo, Gohen, Cello,
  Pikollo, Majin Bubu). Os identificadores internos não mudaram, então os saves continuam válidos.
- Raridade **Secret** passa a ser preta com brilho prateado.
- O ovo gigante volta a ser pego **segurando F**, com interface própria (`Client.GrabPromptUI`): anel de
  24 segmentos que enche; no celular, tocar e segurar.
- A velocidade do colapso passa a acompanhar a velocidade máxima **do carro do jogador**.
- Personagens no estilo chibi arredondado (substituído na 1.8b).

Testado em Play: roleta pagou e travou o segundo giro; fuga iniciou segurando F; Output sem erros.
**Não testado:** compra real com Robux e o prêmio "+2 Spins".
**Pendente do dono:** criar os dois Developer Products e pôr os IDs em `Config.Wheel.Packs`.
Backup: `Backups["Beta 1.7"]`.

### Beta 1.6b — 09/11/2026

**Ovo gigante pego passando com o carro.** Autor: Claude. (Revertido na 1.7, que trouxe de volta o "segurar F".)

- `Services.EscapeService`: sem prompt; o servidor mede a distância do ovo ao trecho percorrido pelo carro.
- O prompt "Drive" some enquanto o jogador está sentado no carro.

Testado em Play: carro a 50 studs/s pegou o ovo e a roleta abriu.

### Beta 1.6 — 09/11/2026

**Elenco estilo Dragon Ball no bioma 1, pista limpa, desafios novos.** Autor: Claude.

- **Elenco do bioma 1** trocado, a pedido expresso do dono, por oito personagens de Dragon Ball Z, com as
  mesmas raridades e rendas. É a única exceção à regra de personagens originais; está registrada no
  `02_AI_Protocol` (regra 13) e o dono assume o risco. O elenco original anterior ficou como Legacy.
- **Migração de save** versão 1 → 2: personagens do elenco antigo viram os equivalentes do novo, no
  inventário, na incubadora e no índice.
- **Pista limpa:** removidas as rampas amarelas e os blocos laterais de slalom.
- **Desafios novos** (`WorldBuilder.BuildChallenges`): 24 passarelas elevadas, 57 pads de lentidão e uma
  ponte temática de torneio no bioma 1.
- Limpeza: backups 1.0, 1.2, 1.3, 1.4c e 1.5 apagados do place (~80 mil instâncias).

Testado em Play: pad de lentidão, passarela, ponte e os oito modelos.
**Não testado:** a migração com um save real. Backup: `Backups["Beta 1.6"]`.

### Beta 1.5 — 09/11/2026

**Roleta da sorte.** Autor: Claude.

- Um giro grátis a cada 8 horas. O tempo usa o relógio do servidor e é salvo, então conta com o jogador offline.
- O servidor sorteia e paga; o cliente só anima. O prêmio fica pendente até a roda parar e é pago no
  próximo login se o jogador sair antes.
- `Services.WheelService` e `Client.WheelPanel` novos. Botão WHEEL no dock, com selo quando há giro.
- Placar do Roblox (`leaderstats.Cash`) passa a espelhar o dinheiro.
- Máquinas de venda do lobby removidas; dois quiosques da roleta no lugar (removidos na 1.7).

Testado em Play: giro, pagamento e seis tentativas extras recusadas.
**Não testado:** persistência entre sessões (o Studio estava sem acesso à API de DataStore).

### Beta 1.4e — 07/11/2026

**Mais decoração japonesa high-tech.** Autor: Claude.

- Bioma 1: corda shimenawa na entrada, arcos taikobashi nas pontes, bandeirolas nobori com kanji em neon,
  kanji holográficos gigantes girando no céu.
- Lobby: seis máquinas de venda em neon (removidas na 1.5).

### Beta 1.4d — 07/11/2026

**Carro só na corrida; decoração do bioma 1.** Autor: Claude.

- O carro só responde aos controles durante a corrida. No lobby o banco fica desativado, e o servidor tira
  do banco quem estiver sentado ali.
- `WorldBuilder.BuildJapanTechDecor`: 6 torii em neon, 42 lanternas de pedra, 8 painéis holográficos,
  27 cerejeiras e 2 pagodes no bioma 1.

Testado em Play: lobby a pé, contagem e corrida.

### Beta 1.4b — 07/11/2026

**Cerejeiras novas e garagem japonesa.** Autor: Claude.

- Cerejeiras com tronco curvo e copa em camadas.
- Interior das garagens refeito: madeira escura, painéis shoji, telhado com beiral, lanternas de papel,
  altares de pedra no lugar dos pedestais, tatame na vaga do carro, bonsais e bambu.
- A porta de enrolar foi removida (tapava a câmera ao nascer).

### Beta 1.4 — 07/11/2026

**Lobby "Sakura Night" e dock.** Autor: Claude.

- **Lobby novo:** praça noturna com cerejeira gigante, Race Gate com torii, vitrine de carros (Car Showroom),
  Hall of Heroes com o avatar e os quatro melhores personagens, lagos com carpas, pagodes e lua.
- **Lobby só a pé.** O carro fica estacionado na garagem; PLAY leva direto ao grid.
- **Dock flutuante** na base da tela: GARAGE, INVENTORY, PLAY, SHOP, GIFT (`Client.LobbyDock`).
- Transição animada "TO THE TRACK!" entre o lobby e a pista.
- Céu noturno apenas no lobby; na pista volta o dia.
- Painéis com fundo escurecido e entrada deslizando.

Testado em Play: fluxo completo do menu até um personagem chocar e aparecer no Hall of Heroes.
Backup: `Backups["Beta 1.3"]` (apagado depois, na 1.6).

### Beta 1.3 — 07/11/2026

**O loop atual do jogo: ovo gigante, roleta, fuga, incubadora.** Autor: Claude.

- **Um ovo gigante no fim de cada bioma.** Pegar o ovo abre uma **roleta** que revela o personagem.
- **Fuga:** a pista desmorona atrás do carro em direção à base. Cruzar a largada salva o ovo; ser alcançado
  perde o ovo. A pista não é destruída de verdade: o efeito é visual por jogador e o servidor decide.
- **Incubadora:** o ovo salvo choca na base em um tempo que depende da raridade (de 30 s a 12 h) e conta
  com o jogador offline.
- **My Garage:** painel com personagens, incubadora e carros (`Client.InventoryPanel`).
- **Tabela de raridades do dono** (58,1 / 23,2 / 11,6 / 5,2 / 1,5 / 0,23 / 0,03), normalizada para 100%.
- Oito personagens originais no bioma 1 (trocados na 1.6).
- Serviços novos: `EggRoll`, `EscapeService`, `IncubatorService`. Ovos de estrada e santuários foram
  guardados atrás de `Config.Features`.

Testado em Play: fluxo completo; carro parado é pego; teleporte para a base anula a fuga.

### Beta 1.2 — 07/11/2026

**Lobby separado, corrida solo, Azure Planet.** Autor: Claude.

- **Lobby** em uma ilha flutuante, sem estrada até a pista.
- **"Pista fantasma":** existe uma pista só, e cada jogador corre sozinho nela. Ninguém se vê nem colide
  durante a corrida. Copiar o mundo para cada jogador somaria ~200 mil peças.
- `Services.RaceService`: vagas no grid, contagem 3-2-1-GO, distância, recorde, fim por chegada ou morte.
- `Client.GhostController` e `Client.RaceUI` novos; portal de corrida.
- **Bioma 1 = Azure Planet:** planeta alienígena original (grama e árvores azuis, casas-domo, ilhas flutuantes).
- Correções: o EXIT deixava o corpo dentro do carro; números do grid invertidos; "NEW RECORD" sobreposto.

Testado em Play: menu, garagem, corrida pelo botão e pelo portal, resultados.

### Beta 1.1 — 07/11/2026

**Tela de início, garagem, ovos, raridade Secret.** Autor: Claude.

- **Tela de início** com START, CONFIGS, CREDITS e UPDATES.
- **Escolha de garagem** com a câmera voando até cada uma.
- O jogador **nasce a pé**; o carro fica estacionado. Botões DRIVE e EXIT.
- **Ovos** no lugar do mini-jogo de captura (que ficou guardado): ovos grátis na estrada e santuários pagos.
- **Sétima raridade: Secret.**
- Bioma 1 vira o Warrior Canyon (original). O pedido era Dragon Ball Z; o assistente não usou a marca.
- Mundo ampliado para 32.500 studs de pista e 141 obstáculos.
- UI com mais cor e efeitos.

Testado em Play: do menu até os ovos chocando. Backup: `Backups["Beta 1.1"]` (o único com o terreno).

### Beta 1.0 (0.2.0) — 06/11/2026

**Garagens e 7 biomas.** Autor: Claude.

- As fazendas viram **garagens** com 8 pedestais (4 de cada lado).
- Quatro biomas novos: Frozen Tundra, Volcano Rift, Neon City e Celestial Peaks. Total: 7 biomas e 7 carros.
- Pista de 20.300 studs (eram 2.400), mais larga, com 83 obstáculos.
- Atmosfera própria por bioma (`Client.AtmosphereController`). Botão Home.
- Correção: o jogo expulsava o jogador no Studio sem acesso à API de dados.

Testado em Play: captura, renda, bloqueio por tier, Home, loja com os 7 carros.

### 0.1.0 — 03/11/2026

**Fundação.** Autor: Claude.

- O projeto estava vazio. Foram criados a arquitetura (`Shared`, `Services`, `Client`), o salvamento com
  trava de sessão, a camada de rede única (`Shared.Net`), 3 biomas, fazenda, 3 carros, captura por
  mini-jogo, 18 personagens originais e a UI (My Animes, Garage, Free Gift).
- A documentação interna (`ServerStorage.ProjectDocs`) nasceu aqui.

**Não testado em Play** nesta versão (as ferramentas de teste não responderam).
