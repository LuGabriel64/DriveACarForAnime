---
title: Recompensas e pontos de spin
date: 2026-11-14
tags: [sistema, economia, beta-1-9]
desde: Beta 1.9
---

# Recompensas e pontos de spin

## Recompensa de partida 1v1 (`Config.Versus.Rewards`)

| | Vencedor | Perdedor |
|---|---|---|
| XP no personagem | +100 | +40 |
| Dinheiro | 2 minutos da renda dele (mínimo $500) | — |
| Pontos de spin | +10 | — |

- Pedido do dono: **o perdedor ganha só XP**.
- **Proteção contra farm:** contra o mesmo adversário, depois de 10 partidas na sessão só o XP é dado
  (`FullRewardsPerOpponent`). A tela de resultado avisa.
- Quem sai no meio não ganha nada. Tudo calculado no servidor; o perfil é salvo logo depois.

## Pontos de spin (`Config.Wheel.Points`)
- +2 por minuto jogado (relógio do servidor) e +10 por vitória 1v1.
- **100 pontos = 1 giro extra** (`data.Wheel.Tokens`); a sobra fica guardada (`data.Wheel.Points`).
- `WheelService.AddPoints(player, n)`; atributo `WheelPoints`; barra "🎟️ Spin points: x/100" na roleta.
- Só jogando: 1 giro a cada 50 min.

## Testado
✅ `WheelPoints` subiu 2 após 1 minuto; barra "Pontos de giro: 84/100".
❌ 100 pontos virando giro; recompensas reais de partida.

Relacionado: [Roleta da sorte](Roleta_da_Sorte.md) · [Desafio 1v1](Desafio_1v1.md) · [Estrelas, nível e XP](Estrelas_Nivel_XP.md) · [Decisões](../08_Pedidos_e_Decisoes/Decisoes.md)
