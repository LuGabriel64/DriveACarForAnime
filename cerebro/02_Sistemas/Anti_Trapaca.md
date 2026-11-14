---
title: Anti-trapaça
date: 2026-11-14
tags: [sistema, seguranca]
aliases: [AntiCheat, Config.AntiCheat]
---

# Anti-trapaça

## O problema
O cliente é dono da física do carro. Um exploiter pode "dirigir" a 1.000+ studs/s. Antes da 1.8d o limite da
fuga era `SpeedCap 700 × 1,6 + 60/tick` ≈ 1.700 studs/s: ovo garantido.

## A solução (Beta 1.8d): orçamento de velocidade
`Config.AntiCheat` = { ForwardSpeedMult 1,6 · BurstSeconds 2,5 · Slack 120 · FallbackTopSpeed 70 }.
O avanço permitido usa a **TopSpeed real do carro** × 1,6 (o 1,6 é exatamente o multiplicador do boost).
- **Fuga** (`EscapeService.step` → `forwardOk()`): avanço impossível anula a fuga (`invalid`) e avisa no Output.
- **Recorde** (`RaceService`): velocidade impossível → `End(player, "invalid")` sem contar o salto.
- **Corrida 1v1**: `TopSpeed` = velocidade do F1; avanço impossível = desclassificado.

Testado: corrida a 100 studs/s com carro de 70 (abaixo de 112) aceita; teleporte de 2.000 studs = `invalid`;
fuga legítima entregue; fuga com teleporte anulada.

## Outras garantias (desde o início)
- Sorteio só no servidor (`EggRoll`, `Random` próprio); o cliente não envia nenhum número que entre no sorteio.
- Tempos de incubadora e roleta em `os.time()` do servidor.
- Batalha simulada no servidor; o cliente só manda o `uid` do lutador.
- `ProcessReceipt` idempotente (lista de `PurchaseId`), salva antes de `PurchaseGranted`.
- Todo `Net.Handle` valida tipo e limites.

## Não testado
Carros de tier alto com boosts em sequência dirigindo de verdade (o Slack de 120 deve cobrir).

Relacionado: [Rede (Net)](Rede_Net.md) · [Save](Save_DataService.md) · [Ovo, roleta e fuga](Ovo_Gigante_Roleta_Fuga.md) · [Beta 1.8d](../07_Versoes/Beta_1.8d.md) · [Erros corrigidos](../09_Erros_e_Licoes/Erros_Corrigidos.md)
