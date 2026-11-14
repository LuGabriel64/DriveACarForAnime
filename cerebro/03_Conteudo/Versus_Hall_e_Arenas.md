---
title: Versus Hall e arenas
date: 2026-11-14
tags: [conteudo, mapa, beta-1-9]
desde: Beta 1.9
---

# Versus Hall e arenas

Gerados por `ServerStorage.Tools.VersusBuilder` (`BuildHall`, `BuildArena(i)`, `BuildAll`; atalhos
`WorldBuilder.BuildVersusHall/BuildArena/BuildVersus`) em `Workspace.Map.Versus` (~250 peças).

- **Versus Hall** em `Config.Versus.HallOrigin` (1400, 0, 3200): sala de espera com os balcões da loja de F1 e
  da loja de animações de vitória (ProximityPrompt "VersusShop").
- **Arenas** em x = -1400 (`Config.Versus.Battle.Arenas`, `RingTop = 4`, lutadores a ±13, plateia em (±8, 11, 44)):

| Arena | Tema |
|-------|------|
| 🥋 Sky Tournament Ring (`Arena_sky_ring`) | ringue de torneio flutuando acima das nuvens |
| 🌸 Sakura Moon Dojo (`Arena_moon_dojo`) | pétalas, lanternas, lua cheia gigante |
| 🌋 Volcano Coliseum (`Arena_lava_arena`) | arena de pedra com cascatas de lava |

A arena não muda o resultado; é cenário. Ajuste feito no teste: os estandartes foram para trás do ringue
(tapavam a câmera).

Relacionado: [Desafio 1v1](../02_Sistemas/Desafio_1v1.md) · [Batalha de anime](../02_Sistemas/Batalha_de_Anime.md) · [Lobby Sakura Night](Lobby_Sakura_Night.md) · [Mapa (WorldBuilder)](../05_Modelagem/Mapa_WorldBuilder.md)
