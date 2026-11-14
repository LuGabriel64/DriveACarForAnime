---
title: Incubadora e garagem
date: 2026-11-14
tags: [sistema, economia]
aliases: [FarmService, IncubatorService, My Garage]
---

# Incubadora e garagem

## Incubadora (Beta 1.3)
- `Services.IncubatorService`: `data.Incubator` = {IncId, Biome, Id, Mut, Size, Odds, Start, ReadyAt, Stars}.
- Tempo em `os.time()` do **servidor** (conta offline). 6 vagas (`Config.Incubator.Slots`).
- Tempo de choco por raridade: 30 s, 1 min, 3 min, 5 min, 20 min, 1 h, 12 h.
- Ao chocar → `FarmService.AddAnime(player, id, mut, size, stars)`; eventos `Incubator` e `Hatched`.

## Garagem (desde a 0.2.0)
- 8 garagens no lobby (`Map.Plots.Plot_1..8`, nome interno antigo; na UI tudo é "Garage").
- Cada garagem: 8 pedestais (`Slots/Slot_N`), `CarPad`, `CarSpawn`, `PlayerSpawn`, placa (Base/Title/Label).
- `Services.FarmService`: escolher garagem (`GetGarages`/`ClaimGarage`), colocar, tirar, vender, EQUIP BEST,
  renda por segundo (atributo `CashPerSec`), AutoPlace por jogador.
- 1.9: a renda usa `AnimeStats.Income` (estrelas e nível); a placa mostra `☆☆☆☆☆ Lv 1 | $3/s`;
  `FarmService.Refresh(player)` e `FarmService.CashPerSec(player)`.

## Painel "My Garage" (`Client.InventoryPanel`)
Abas CHARACTERS / INCUBATOR / CARS. Abre só no lobby (botão Garage do HUD ou tecla G na garagem).
1.9: cartão 148×284 com ★, selo de nível, barra de XP, Poder e o botão SET PARTNER.

## Visual das garagens
- 0.2.0: oficina (metal verde, neon magenta "GARAGE", pneus, cones).
- 1.4b: **interior japonês noturno** (madeira escura, shoji, telhado com beiral, lanternas, noren, altares de
  pedra nos slots, tatame no CarPad, bonsais, bambu). Contrato do FarmService mantido.

Relacionado: [Ovo, roleta e fuga](Ovo_Gigante_Roleta_Fuga.md) · [Estrelas, nível e XP](Estrelas_Nivel_XP.md) · [Lobby Sakura Night](../03_Conteudo/Lobby_Sakura_Night.md) · [Hierarquia de telas](../04_UI_UX/Hierarquia_de_Telas.md)
