# Beta 1.9 — situação em 12/11/2026

## Resumo

**Nada da Beta 1.9 está no jogo.** Ela foi projetada em sessões na nuvem (11 e 12/11), sem acesso ao Studio.
O que aconteceu "durante a 1.9" até agora:

1. **Projeto escrito** em `planejamento/beta-1.9/`: 7 documentos, um plano de implementação em etapas e os
   pedidos prontos.
2. **Código-rascunho** de 8 módulos Luau em `planejamento/beta-1.9/rascunho/`. Eles **não** estão em `src/`
   nem no place.
3. **80 testes automáticos** da lógica pura, rodados fora do Roblox contra o `Config` real. Os testes acharam
   e corrigiram dois problemas de equilíbrio da batalha: vantagem para quem atacava em segundo, e uma classe
   que vencia todas as lutas.
4. **Etapa 0 do plano aplicada** (a única etapa feita), como **Beta 1.8d**: as correções da auditoria. Ela é
   pré-requisito da 1.9, mas não traz nada da 1.9. Ver `01_beta-1.8d_o_que_foi_feito.md`.

## O que a Beta 1.9 vai trazer

| # | Novidade |
|---|----------|
| 1 | **Desafio 1v1**: botão no dock convida um jogador; ele aceita ou recusa; sala de espera (Versus Hall), votação do mapa e 30 s de preparação |
| 2 | **Corrida 1v1** com carros de Fórmula 1, loja própria, pista desmoronando desde a largada, placar ao vivo e música |
| 3 | **Batalha de anime**: o servidor simula e os dois assistem; ULT por personagem, 3 arenas, loja de animações de vitória |
| 4 | **Estrelas (0 a 5) e nível (1 a 50)** em todo personagem; XP; cada estrela vale +7,5% |
| 5 | **Pontos de spin**: 100 = 1 giro; +2 por minuto jogado, +10 por vitória |
| 6 | **Idiomas** EN/PT (303 frases traduzidas) |
| 7 | **Interface por plataforma**: celular, tablet, PC e TV |

O save passa para a versão 3, só com campos novos; nada é apagado.

## Estado de cada peça de código

| Módulo (rascunho) | Estado |
|-------------------|--------|
| `Shared/ConfigBeta19` | ✅ testado |
| `Shared/AnimeStats` | ✅ testado |
| `Shared/Locale` + `pt` | ✅ parte pura testada / ⚠ parte do Roblox só compilada |
| `Services/BattleSim` | ✅ testado e calibrado |
| `Services/VersusService` | ⚠ só compilado (nunca rodou) |
| `Services/ProgressService` | ⚠ só compilado |
| `Client/Platform` | ⚠ só compilado |
| `DuelRaceService`, `BattleService`, toda a UI nova, o carro de F1, o Versus Hall e as arenas | ❌ ainda não escritos (estão especificados nos documentos 01 a 06) |

## Etapas que faltam (na ordem)

Cada etapa termina com teste em Play e com o place salvo. **Um pedido por vez.** Os textos prontos para colar
estão em `planejamento/beta-1.9/PROMPTS_PARA_O_STUDIO.md`.

| Etapa | Pedido | Conteúdo | Estado |
|-------|--------|----------|--------|
| 0 | Pedido 1 | Correções da auditoria | ✅ **feita** (Beta 1.8d) |
| A | Pedido 2 | Fundação: `ConfigBeta19`, `AnimeStats`, save v3, estrelas, XP, pontos de spin, `Platform`, idiomas, mochila | ⏳ próxima |
| B | Pedido 3 | Desafio + corrida 1v1 (`VersusService`, Versus Hall, F1, `DuelRaceService`, `CollapseFX`) | ⏳ |
| C | Pedido 4 | Batalha (`BattleService`, arenas, `BattleUI`, loja de vitória, música) | ⏳ |
| D | Pedido 5 | Fechamento: `Config.Version = "Beta 1.9"`, docs, `.rbxl`, tag `beta-1.9` | ⏳ |

O teste mais importante da **Etapa A**: um save antigo carrega e a **renda de cada personagem fica idêntica**
à de antes.

## Avisos para quem for aplicar

- Ao começar a Etapa A, `Config.Version` estará em **"Beta 1.8d"**. O plano foi escrito quando ainda era 1.8;
  isso está correto, não é sinal de problema.
- Se outra pessoa já tiver feito uma "Beta 1.9" no place, este pacote vira a **Beta 2.0**.
- O anti-trapaça novo (`Config.AntiCheat`) tem de valer também na **corrida 1v1** (Etapa B, `DuelRaceService`):
  use o mesmo orçamento do `RaceService`.
- A Etapa B generaliza o `EscapeFX`. **Reteste a fuga do ovo inteira** depois, inclusive o anti-trapaça.
- Os rascunhos evitam sintaxe exclusiva do Luau para rodar nos testes. No Studio pode usar Luau normal.
- Decisões que o dono pode mudar (corrida na mesma pista, batalha automática, nível aumentando a renda etc.)
  estão listadas em `planejamento/beta-1.9/README.md`.
