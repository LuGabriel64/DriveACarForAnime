# Beta 1.9 — Projeto (ainda NÃO aplicado no jogo)

> **Status em 12/11/2026:** projeto escrito e lógica pura testada fora do Roblox. **Nada disto está no
> place.** Será aplicado quando um Claude Code estiver ligado ao Roblox Studio (ver
> [`docs/CONECTAR_STUDIO.md`](../../docs/CONECTAR_STUDIO.md)). Quem aplicar segue o
> [`07_plano_de_implementacao.md`](07_plano_de_implementacao.md).
>
> **Regra de versão:** se, na hora de aplicar, o place já estiver na Beta 1.9 (feita por outra pessoa ou
> assistente), este pacote vira a **Beta 2.0**. Confira `Config.Version` antes de começar.

## O que a Beta 1.9 traz

| # | Novidade | Documento |
|---|----------|-----------|
| 1 | **Desafio 1v1**: botão no dock convida um jogador do servidor; ele aceita ou recusa; sala de espera, votação do mapa e 30 s de preparação | [01](01_arquitetura.md), [02](02_corrida_1v1.md) |
| 2 | **Corrida 1v1** até o fim do mapa, com carros de Fórmula 1, loja própria, pista desmoronando desde a largada, placar ao vivo e música | [02](02_corrida_1v1.md) |
| 3 | **Batalha de anime** em arenas temáticas, com ULT por personagem, efeitos e loja de animações de vitória | [03](03_batalha_anime.md) |
| 4 | **Estrelas (0 a 5) e nível (1 a 50)** em todo personagem; XP e recompensas das partidas | [04](04_progressao_e_recompensas.md) |
| 5 | **Pontos de spin**: 100 pontos = 1 giro; +2 por minuto jogado, +10 por vitória | [04](04_progressao_e_recompensas.md) |
| 6 | **Idiomas**: botão "Languages" na tela de início, inglês e português | [05](05_idiomas.md) |
| 7 | **Interface por plataforma**: overlays menores no celular, maiores na TV, tudo navegável por toque, teclado e controle | [06](06_interface_multiplataforma.md) |

## O que há nesta pasta

```
planejamento/beta-1.9/
├─ README.md                        este arquivo
├─ 01_arquitetura.md                módulos novos, save, rede, e o que muda em cada script existente
├─ 02_corrida_1v1.md
├─ 03_batalha_anime.md
├─ 04_progressao_e_recompensas.md
├─ 05_idiomas.md
├─ 06_interface_multiplataforma.md
├─ 07_plano_de_implementacao.md     passo a passo para aplicar no Studio, com backup e testes
├─ rascunho/                        código Luau já escrito (NÃO está em src/ nem no place)
│  ├─ Shared/ConfigBeta19.luau      todos os números novos                    ✅ testado
│  ├─ Shared/AnimeStats.luau        estrelas, nível, XP, renda, status        ✅ testado
│  ├─ Shared/Locale/init.luau       tradução (parte pura testada)             ✅ / ⚠ parte do Roblox só compilada
│  ├─ Shared/Locale/pt.luau         303 frases em português                   ✅ testado
│  ├─ Services/BattleSim.luau       simulação da batalha                      ✅ testado e calibrado
│  ├─ Services/VersusService.luau   convite, etapas, recompensas              ⚠ só compilado
│  ├─ Services/ProgressService.luau XP e parceiro                             ⚠ só compilado
│  └─ Client/Platform.luau          tamanho da UI por aparelho                ⚠ só compilado
└─ testes/
   ├─ run_tests.py                  roda os testes em Lua 5.4 (fora do Roblox)
   └─ test_beta19.lua               80 verificações
```

- ✅ **testado**: executado de verdade contra o `Config` real do jogo (`src/…/Config.luau`).
- ⚠ **só compilado**: a sintaxe foi conferida, mas o módulo depende de serviços do Roblox e **nunca rodou**.
  Trate como rascunho: leia, ajuste ao estado do place e teste em Play.
- **Ainda não escritos** (dependem de ver o jogo rodando): `DuelRaceService`, `BattleService`, toda a UI nova
  (`VersusUI`, `DuelRaceUI`, `BattleUI`, lojas, `MusicController`), o carro de F1 no `CarFactory`, o Versus Hall
  e as arenas no `WorldBuilder`. Estão especificados nos documentos 01 a 06.

Para rodar os testes (Linux com `liblua5.4`):

```bash
python planejamento/beta-1.9/testes/run_tests.py
```

## Decisões que tomei e que o dono pode mudar

Escolhi um padrão para não travar o projeto. Cada item diz onde mudar.

| # | Decisão | Por quê | Onde mudar |
|---|---------|---------|------------|
| 1 | A corrida 1v1 usa a **mesma pista do jogo**, em outro modo, em vez de uma cópia do mapa | Uma cópia somaria ~43 mil peças e teria de ser refeita a cada mudança do mapa. Com a mesma pista, toda estrutura nova entra sozinha, e os ovos somem só para quem está no 1v1 | [02](02_corrida_1v1.md) |
| 2 | Os dois carros **se veem mas não colidem** | Evita empurrão proposital e os defeitos de física entre carros controlados por clientes diferentes | `RaceService` (grupos de colisão) |
| 3 | A batalha é **automática**: o servidor simula e os dois assistem | Você pediu que o mais raro com os melhores status vença. Assim ninguém trapaceia e roda igual no celular | [03](03_batalha_anime.md) |
| 4 | **Nível também aumenta a renda** (+1% por nível, +49% no 50) | Você pediu que os status subam com o nível, e a renda é um deles | `Config.Levels.IncomePerLevel` (0 desliga) |
| 5 | Na corrida, o XP vai para o **parceiro** (personagem escolhido; padrão = o de maior Poder) | Na corrida não há um personagem em jogo | [04](04_progressao_e_recompensas.md) |
| 6 | Personagens que já existem ficam com **0 estrelas** | Mudar a renda de quem já joga sem ele fazer nada seria injusto para um lado ou para o outro | `DataService.migrate` |
| 7 | Dinheiro do vencedor = **2 minutos da renda dele** (mínimo $500) | Um valor fixo seria enorme no começo e irrelevante no fim | `Config.Versus.Rewards` |
| 8 | Contra o **mesmo adversário**, depois de 10 partidas na sessão só o XP é dado | Dois amigos (ou uma conta secundária) poderiam trocar vitórias para farmar dinheiro e giros | `Rewards.FullRewardsPerOpponent` |
| 9 | Nomes de ULT **originais** ("Azure Wave", "Royal Flash"…), sem nomes de golpes de animes existentes | Regra 13 do Protocolo. A exceção do bioma 1 cobre o elenco, não os golpes | `Config.Battle.Fighters` |
| 10 | Variação de dano de ±8% | Luta com a mesma força fica imprevisível; com 1 estrela de diferença o mais forte já vence quase sempre | `Config.Battle.Sim.Variance` |

## Pendências que só o dono resolve

- **Músicas**: escolher os áudios (Creator Store → Audio) e pôr os IDs em `Config.Music` (corrida, batalha,
  sala de espera, vitória). Sem ID o jogo roda mudo, sem erro.
- **Sons** (`Config.Sounds`) continuam vazios desde a Beta 1.1.
- **Bandeiras do botão de idiomas**: os emojis 🇺🇸 e 🇧🇷 precisam ser conferidos no Studio. Se o Roblox não
  desenhar, troco por bandeiras feitas com Frames (ver [05](05_idiomas.md)).
- **Preços** dos F1 e das animações de vitória: são um chute coerente com a economia atual; ajuste jogando.
