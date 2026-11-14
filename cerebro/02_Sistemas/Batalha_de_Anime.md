---
title: Batalha de anime
date: 2026-11-14
tags: [sistema, pvp, batalha, beta-1-9]
aliases: [BattleSim, BattleService, BattleUI]
desde: Beta 1.9
---

# Batalha de anime

## Princípio: o servidor simula, o cliente encena
1. Na preparação cada jogador escolhe **um lutador** (padrão: o de maior Poder) e a animação de vitória.
2. `Services.BattleService` monta os status a partir do save (`AnimeStats.BattleStats`), roda
   `Services.BattleSim.Run(a, b, seed)` e decide o vencedor **antes** da cena.
3. Os dois recebem o **roteiro** (evento `BattleScript`) e `Client.BattleUI` encena a mesma luta.

**Por quê:** ninguém trapaceia, não há lutador físico no servidor, várias lutas cabem na mesma arena,
roda igual no celular. Mesma semente + mesmos status = mesma luta (o servidor imprime a semente).

## Regras da simulação (`Config.Battle.Sim`)
- Intervalo 1,15 s ajustado pela Vel. de Ataque (0,65× a 1,5×). O mais rápido (SPD) começa; empate = sorteio.
- Dano = `ATK × ATK / (ATK + DEF)`, variação ±8%. Crítico ×1,6 (3% a 35%). Esquiva até 25%.
- Energia: +25 ao acertar, +10 ao apanhar, +6 ao esquivar. Com 100, o próximo ataque é a **ULT** (nunca erra).
- HP 0 = K.O. Depois de 60 s vence a maior % de vida (empate → Poder → sorteio).
- Luta entre iguais: ~19 s de combate; cena total ~30 s.

## Classes e ULT
| Classe | ULT | Efeito |
|--------|-----|--------|
| Brawler | Burst | golpe ×3,0 |
| Guardian | Bulwark | golpe ×2,0 + escudo de 12% da vida |
| Speedster | Flurry | 5 golpes × 0,62 |
| Mystic | Nova | ×2,4, ignora metade da DEF, cresce com POW |
| Champion | Finisher | ×2,8, +50% com o alvo abaixo de 35% |

Calibragem: com o mesmo Poder, nenhuma classe precisa de mais de 3,3% de Poder extra para empatar (menos que meia estrela).
Cada personagem ativo tem **nome de ULT original** e efeito visual em `Config.Battle.Fighters` (ex.: Gokun "Azure Wave").

## Encenação (`Client.BattleUI`)
Entrada com câmera girando e lutadores caindo do céu; cartão com nome, raridade, ★, nível, Poder; "FIGHT!";
golpes com número de dano; CRITICAL com tremor; DODGE com rastro; ULT com escurecimento, faixa com o nome e
câmera fechada; escudo em bolha; K.O. em câmera lenta; animação de vitória (`BattleUI.PlayVictory`).
Barras no topo: vida, escudo, energia (pulsa quando a ULT está pronta). O HUD some durante a cena.
Câmera lateral: `CFrame.lookAt(Center + (0,17,52), Center + (0,4,0))`.

## Loja de animações de vitória
Confetti Pop (grátis) · Fireworks $25K · Mega Explosion $400K · Thunder Strike $6M · Sakura Storm $80M ·
Meteor Crash $1,2B · Black Hole $20B.

## Testado
✅ cena com roteiro real do BattleSim (Master Kamo × Cello) enviado pelo servidor · ✅ testes de lógica (80 verificações).
❌ batalha disparada pelo BattleService com 2 jogadores, plateia, recompensas.

Relacionado: [Estrelas, nível e XP](Estrelas_Nivel_XP.md) · [Desafio 1v1](Desafio_1v1.md) · [Versus Hall e arenas](../03_Conteudo/Versus_Hall_e_Arenas.md) · [Testar](../10_Estrategias/Testar.md)
