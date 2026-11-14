---
title: Beta 1.3 — ovo gigante, roleta, fuga, incubadora
date: 2026-11-07
tags: [versao, marco]
autor: Claude
---

# Beta 1.3 (07/11/2026) — o loop atual nasce

**Feito:** um ovo gigante no fim de cada bioma; roleta (gacha) com `EggRouletteUI`; fuga com a pista
desmoronando até a base (`EscapeService` + `EscapeFX`); incubadora por raridade (`IncubatorService`, conta
offline); painel My Garage; tabela de raridades do dono (normalizada); 8 lutadores originais no Azure Planet;
`EggRoll` (sorteio só no servidor). Ovos de estrada, santuários e EggShop **guardados**.

**Testado:** fluxo completo (ovo → roleta EPIC 1 in 22 → colapso → entregue → incubadora → chocou → pedestal);
carro parado = pego; teleporte = `invalid`.

**Decisões:** colapso visual por jogador e regra no servidor; DataService próprio em vez de ProfileService.

Relacionado: [Beta 1.2](Beta_1.2.md) · [Beta 1.4](Beta_1.4.md) · [Ovo, roleta e fuga](../02_Sistemas/Ovo_Gigante_Roleta_Fuga.md) · [Incubadora e garagem](../02_Sistemas/Incubadora_e_Garagem.md)
