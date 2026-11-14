---
title: Ovo gigante, roleta e fuga
date: 2026-11-14
tags: [sistema, ovo, loop]
aliases: [EscapeService, Fuga, Colapso]
desde: Beta 1.3
---

# Ovo gigante, roleta e fuga

## Fluxo
1. No fim de cada bioma há **um** ovo gigante (`Map.BiomeEggs`, criado pelo servidor ao iniciar; posição em
   `Config.BiomeEggZ`; o do bioma 1 fica em z = -3090).
2. **Segurar F** (`GrabPrompt`, `HoldDuration` 1,1 s; UI própria em `Client.GrabPromptUI`, anel de 24 segmentos).
3. O servidor sorteia (`Services.EggRoll`: personagem, mutação, tamanho e, desde a 1.9, **estrelas**).
4. `Client.EggRouletteUI` gira a roleta até o resultado (6 s) e mostra "1 in N" e as estrelas ao lado.
5. A pista **desmorona** atrás do carro, rumo à base (o colapso começa ~3 s depois da roleta).
6. Cruzar a linha de largada (`Config.Escape.BaseZ`) = ovo vai para a [incubadora](Incubadora_e_Garagem.md).
7. Colapso alcançou o carro, Home ou morreu = **ovo perdido** (`caught`). Teleporte = `invalid`.

## Quem decide
- **Servidor** (`Services.EscapeService`): frente do colapso `FrontZ0 + Speed × (t − FrontStart)`, pego/entregue,
  anti-teleporte e orçamento de velocidade ([anti-trapaça](Anti_Trapaca.md)).
- **Cliente** (`Client.EscapeFX`): fendas, destroços, rampas e pontes caindo **só na tela do jogador**, parede de
  colapso, aviso, tremor e tela avermelhada.
- **Por que o colapso é só visual:** a pista é compartilhada (pista fantasma). Destruir de verdade afetaria os outros.

## Velocidade do colapso
Desde a 1.7 cresce com o carro do jogador: `Config.EscapeSpeed(biome, carMax, carTier)` com `CarFactor`,
`CarFactorMaxTier`, `CarFactorCap`. Ajustes fáceis em `Config.Escape` (SpeedFactor, HeadStart, RouletteSeconds,
EggBeforeEnd, PromptDistance, HoldDuration).

## Atributos
`EscapeState`, `EscapeBiome`, `EscapeEggZ`, `EscapeFrontZ0`, `EscapeFrontStart`, `EscapeSpeed`.

## Histórico de decisões
- 1.3: prompt "Grab Egg" (F).
- 1.6b: pego **passando com o carro** (raio 18, distância ao segmento percorrido).
- 1.7: volta o **segurar F** com UI própria (pedido do dono); colapso na velocidade do carro do jogador.
- 1.8: textos do ovo menores (placa 190×72; cartão 20% menor).
- 1.9: recusado em modo Duel; o ovo some para quem está na corrida 1v1 (`Client.BiomeEggs`).

Relacionado: [Incubadora e garagem](Incubadora_e_Garagem.md) · [Raridades e mutações](../03_Conteudo/Raridades_e_Mutacoes.md) · [Estrelas, nível e XP](Estrelas_Nivel_XP.md) · [Beta 1.3](../07_Versoes/Beta_1.3.md) · [Pegadinhas técnicas](../09_Erros_e_Licoes/Pegadinhas_Tecnicas.md)
