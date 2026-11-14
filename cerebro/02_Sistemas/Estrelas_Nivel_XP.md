---
title: Estrelas, nível e XP
date: 2026-11-14
tags: [sistema, progressao, beta-1-9]
aliases: [AnimeStats, ProgressService, Poder]
desde: Beta 1.9
---

# Estrelas, nível e XP

Contas em `Shared.AnimeStats` (o mesmo módulo no servidor e no cliente). XP e parceiro em `Services.ProgressService`.

## Estrelas (0 a 5)
Sorteadas no servidor junto com o personagem (`EggRoll.Roll`). Cada estrela = **+7,5% fixo** sobre o base.

| ★ | Mult. | Exemplo do dono ($400/s) | Chance |
|---|-------|--------------------------|--------|
| 0 | ×1,000 | $400 | 40% |
| 1 | ×1,075 | $430 | 28% |
| 2 | ×1,150 | $460 | 17% |
| 3 | ×1,225 | $490 | 9% |
| 4 | ×1,300 | $520 | 4,5% |
| 5 | ×1,375 | $550 | 1,5% |

Personagens antigos ficam com 0★ (renda igual). O "1 in N" da roleta não inclui as estrelas (aparecem ao lado).

## Nível (1 a 50)
- XP para subir de L para L+1 = `30 + 12 × L`; total até 50 = **16.170 XP**.
- Cada nível: **+2% nos status de batalha** (50 = ×1,98) e **+1% de renda** (50 = ×1,49; `Config.Levels.IncomePerLevel = 0` desliga).
- Aviso "⬆️ Gokun reached level 7!" (evento `LevelUp`) e placa do pedestal atualizada.
- Batalha: XP vai para o lutador. Corrida 1v1: para o **parceiro** (`SET PARTNER`; padrão = maior Poder).

## Poder e status
`Poder = raridade × bioma × estrelas × nível × mutação × tamanho`
- Raridade: Common 100 · Uncommon 135 · Rare 180 · Epic 245 · Legendary 330 · Mythic 450 · Secret 620.
- Bioma +25% por bioma após o 1º · Gold ×1,15 · Diamond ×1,35 · BIG ×1,10.
- A **classe** distribui o Poder entre HP, ATK, DEF, SPD, ASPD e POW.
- Exemplos: Gokun 0★ Lv1 = Poder 100 · Majin Bubu 5★ Lv50 = Poder 1.688, Vida 31.598.

## Save
`data.Animes[i].Stars/Level/XP`, `data.Partner`. Save Version 3 (migração 2→3 só acrescenta campos).

Relacionado: [Batalha de anime](Batalha_de_Anime.md) · [Recompensas e pontos de spin](Recompensas_e_Pontos_de_Spin.md) · [Incubadora e garagem](Incubadora_e_Garagem.md) · [Save](Save_DataService.md) · [Raridades](../03_Conteudo/Raridades_e_Mutacoes.md)
