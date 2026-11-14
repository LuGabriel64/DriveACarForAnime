---
title: Biomas
date: 2026-11-14
tags: [conteudo, mapa, biomas]
---

# Biomas

Encadeados no eixo **-Z** a partir da largada (z = 40). `Config.Biomes[i].Length`; `ZStart`/`ZEnd` são
calculados no fim do Config. Carro Tier N abre o bioma N (portão "Requires Tier N car").

| # | Id | Nome | Comprimento | Carro do tier | Preço | Vel. máx | Ovo |
|---|----|------|-------------|---------------|-------|----------|-----|
| 1 | warrior | 🪐 Azure Planet | 3.200 | Starter Hatch | 0 | 70 | Azure Egg |
| 2 | sakura | 🌸 Sakura Valley | 3.700 | Sakura GT | $25K | 105 | Blossom Egg |
| 3 | dunes | 🏜️ Sunset Dunes | 4.200 | Dune Racer | $400K | 150 | Desert Egg |
| 4 | tundra | ❄️ Frozen Tundra | 4.600 | Frost Runner | $5M | 210 | Frost Egg |
| 5 | volcano | 🌋 Volcano Rift | 5.100 | Magma Reaper | $70M | 290 | Magma Egg |
| 6 | city | 🌃 Neon City | 5.600 | Neon Phantom | $1B | 390 | Neon Egg |
| 7 | celestial | ☁️ Celestial Peaks | 6.100 | Celestial Comet | $15B | 520 | Celestial Egg |

Total: **32.500 studs**. Cada bioma tem `Sky` (névoa/tom/luz) aplicado pelo `Client.AtmosphereController`,
`Terrain` (amplitude, terraços), `Props`, `Obstacles` (pesos) e cor.

## História do bioma 1
| Versão | Bioma 1 |
|--------|---------|
| 0.1.0 | Verdant Plains (hoje Legacy) |
| 1.1 | **Warrior Canyon** (original de artes marciais; o pedido era DBZ, recusado por IP) |
| 1.2 | **Azure Planet** (Id continua "warrior"): planeta alienígena original — grama azul, estrada de terra, penhascos lilás, casas-domo, cogumelos laranja, ilhas flutuantes, arenas, pilares de cristal com aura |
| 1.4d/e | decoração **japonesa high-tech** (torii neon, lanternas, kanji, cerejeiras, pagodes) |
| 1.6 | elenco estilo DBZ **pedido pelo dono** (exceção de IP) |

Guia de design do bioma 1: inspiração permitida = clima geral (planeta alienígena de guerreiros, vilas de domos,
torneio, auras). **Proibido**: nomes, logos, esferas laranja com estrelas, empresas, roupas ou golpes reconhecíveis.

Relacionado: [Personagens](Personagens.md) · [Pista e obstáculos](../02_Sistemas/Pista_e_Obstaculos.md) · [Mapa (WorldBuilder)](../05_Modelagem/Mapa_WorldBuilder.md) · [Carros e direção](../02_Sistemas/Carros_e_Direcao.md)
