---
title: Corrida solo (pista fantasma)
date: 2026-11-14
tags: [sistema, corrida]
aliases: [Pista fantasma, RaceService]
desde: Beta 1.2
---

# Corrida solo (pista fantasma)

**Ideia:** uma única pista física para todos. Cada corredor recebe um **slot** (1 a 8) e corre "sozinho":
os outros ficam invisíveis na tela dele e ninguém colide com ninguém.

**Por que não 8 cópias do mundo:** seriam ~200 mil peças, geração lenta, risco de passar do limite do place e lag
no celular. A mesma decisão foi reaproveitada na corrida 1v1 (modo Duel).

## Como funciona
- `Services.RaceService`: `StartRace` / `EndRace` / `GoHome`, grid (`Config.Race`), contagem 3-2-1 com o carro
  ancorado, distância e recorde (`data.Stats.BestDistance`). Termina ao chegar no fim do mundo, morrer ou sair.
- Grupos de colisão: "Characters" e "Cars" não colidem entre si.
- `Client.GhostController`: esconde os outros jogadores enquanto alguém corre. Na 1.9: quem tem o mesmo `MatchId ≠ 0` se vê.
- `Client.RaceUI`: botão RACE (guardado), portal, 3-2-1-GO, painel ao vivo, tela de resultados.
- Linha de largada: `Map.Structures.StartLine` (pórtico, luzes que ficam verdes no GO, vagas 1 a 8), z = 40.
- Entrada: PLAY no dock ou entrar no portal (`tag RacePortal`) a pé. A cortina "TO THE TRACK!" cobre a transição.

## Atributos
`RaceState` ("Lobby" | "Countdown" | "Racing"), `RaceSlot`, `RaceDistance`, `RaceBest`, `RaceMode` ("Solo" | "Duel", 1.9).

## Regras importantes
- Controle do carro só com `RaceState = "Racing"` (cliente e servidor, Beta 1.4d).
- Distância limitada pelo [anti-trapaça](Anti_Trapaca.md) (1.8d): velocidade impossível encerra com `invalid`.
- 1.9: `RaceService.Start(player, opts)` aceita `Mode = "Duel"`, `GridCFrame`, `Car`, `FinishZ`; `OnEnded(fn)`.

Relacionado: [Corrida 1v1 de F1](Corrida_1v1_F1.md) · [Ovo, roleta e fuga](Ovo_Gigante_Roleta_Fuga.md) · [Carros e direção](Carros_e_Direcao.md) · [Beta 1.2](../07_Versoes/Beta_1.2.md)
