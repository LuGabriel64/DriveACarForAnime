---
title: Corrida 1v1 de F1
date: 2026-11-14
tags: [sistema, pvp, corrida, beta-1-9]
aliases: [DuelRaceService, DuelRaceUI, Modo Duel]
desde: Beta 1.9
---

# Corrida 1v1 de F1

## O mapa: a mesma pista, em outro modo
O dono pediu "o mapa sem ovos, sem o sistema de ovos e sem o bloqueio de biomas". Em vez de copiar o mapa
(43 mil peças), a corrida usa a pista do jogo com `RaceMode = "Duel"`:

| Pedido | Como ficou |
|--------|-----------|
| Sem ovos | `Client.BiomeEggs` esconde o ovo, a placa e o prompt em Duel |
| Sem o sistema de ovos | `EscapeService.tryGrab` recusa em Duel |
| Sem bloqueio de biomas | `ZoneService` não aplica o tier nem grava `BestBiome` em Duel |
| Estruturas novas entram | entram sozinhas, porque é a mesma pista |

## Fluxo
1. Preparação (30 s): escolhe o F1 (pode comprar na hora).
2. Grid lado a lado (`GridColsX = {-10, 10}`), 3-2-1-GO com o carro ancorado.
3. Corrida até o fim do mapa (~32.400 studs; 2 a 3 min com o Rookie).
4. Os dois **se veem** (mesmo `MatchId`) mas **não colidem**.

## Colapso desde a largada
- Nasce 120 studs atrás do grid, começa 4 s depois do GO, anda na direção da corrida (−Z).
- Velocidade = MaxSpeed do carro **mais lento** × 0,55 (mínimo 60). Na fuga do ovo o fator é 0,82.
- Frente: `Z0 − Speed × (t − Start)` com `workspace:GetServerTimeNow()`; atributos `CollapseDir/Z0/Start/Speed`.
- Servidor a cada 0,1 s: carro com `Z ≥ frente` foi **pego**.

## Quem vence
Chegou primeiro → vence · um pego → o outro vence · os dois pegos ou passou de 420 s → o mais longe vence ·
saiu/LEAVE → o outro vence · empate exato → sem vencedor.

## Placar ao vivo (`Client.DuelRaceUI`)
Topo da tela: 🥇/🥈, metros de cada um, "+310 m à frente", distância do colapso (vermelho piscando abaixo de 200 m).
No celular vira uma linha: `🥇 12.480 m · +310 m`. Lê `RaceDistance` dos dois a 4 Hz (sem rede extra).
O colapso local tem visual próprio (parede, pedaços, tremor, tela vermelha) — o `EscapeFX` **não** foi generalizado.

## Anti-trapaça
`Config.AntiCheat` com `TopSpeed` = velocidade do F1 durante o duelo; avanço impossível = desclassificado.

## Diferença do projeto
A animação de vitória na corrida aparece só na tela (confete e ícone), não em 3D sobre o carro.

Relacionado: [Desafio 1v1](Desafio_1v1.md) · [Corrida solo](Corrida_Solo_Pista_Fantasma.md) · [Carros e direção](Carros_e_Direcao.md) · [Anti-trapaça](Anti_Trapaca.md) · [Carros (CarFactory)](../05_Modelagem/Carros_CarFactory.md)
