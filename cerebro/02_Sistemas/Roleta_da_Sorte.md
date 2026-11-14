---
title: Roleta da sorte
date: 2026-11-14
tags: [sistema, monetizacao, roleta]
aliases: [WheelService, WheelPanel, Lucky Wheel]
desde: Beta 1.5
---

# Roleta da sorte

- **1 giro grátis a cada 8 h** (`Config.Wheel.Cooldown`), `LastSpin` em `os.time()` do servidor.
- **Giros extras** (`data.Wheel.Tokens`): prêmio "+2 Spins", pacotes por Robux e, desde a 1.9, **pontos de spin**
  (100 pontos = 1 giro). → [Recompensas e pontos de spin](Recompensas_e_Pontos_de_Spin.md)
- Prêmios (1.7): $500 38% · $2.5K 27% · +2 Spins 15% · $10K 12% · $50K 6% · $250K 2%.
- Pacotes: x3 por R$29 e x10 por R$79 (`Config.Wheel.Packs`, `ProductId = 0` até o dono criar os Developer Products).
- `Services.WheelService`: `GetWheel` / `SpinWheel` / `WheelPack`, `Pending` pago quando a roda para (ou no
  próximo login), anti giro duplo, **único `ProcessReceipt` do jogo** (idempotente, salva antes de `PurchaseGranted`).
- `Client.WheelPanel`: janela própria (6 fatias com ícone/nome/chance, ponteiro, X, botões R$29 x3 | Spin (N) |
  R$79 x10, contador "Spin in: hh:mm:ss"); na 1.9, barra "🎟️ Spin points: N/100".
- Histórico: 1.5 tinha 2 quiosques Lucky Wheel no lobby → 1.7 roleta **só na UI** (quiosques removidos).

Relacionado: [Recompensas e pontos de spin](Recompensas_e_Pontos_de_Spin.md) · [Anti-trapaça](Anti_Trapaca.md) · [Tarefas do dono](../13_Pendencias/Tarefas_do_Dono.md) · [Beta 1.7](../07_Versoes/Beta_1.7.md)
