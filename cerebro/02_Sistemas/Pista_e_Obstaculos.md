---
title: Pista e obstáculos
date: 2026-11-14
tags: [sistema, mapa, obstaculos]
aliases: [HazardController, Hazards]
---

# Pista e obstáculos

## A pista
- 7 biomas encadeados no eixo **-Z**, 32.500 studs de pista; mundo de 704 studs de largura; estrada de 60 studs.
- Obstáculos de terreno e peça, **determinísticos** por bioma (`Config.Biomes[i].Obstacles` = pesos): ramp, bumps,
  slalom, whoops, crest, gap (abismo + ponte estreita), pinch (desfiladeiro), logs, ice, gate.
  Peso ≥ 3 = "assinatura" do bioma (sempre aparece). Regenerar dá o mesmo mapa.
- 1.6: sem rampas amarelas e sem blocos de slalom (pedido do dono); **passarelas elevadas** (Skyway), **pads de
  lentidão** (SlowPad) e ponte temática de torneio no bioma 1.

## Boost pads
- 1.8: de 143 para **46** (`Track.BoostEvery = 700`, `BoostMinGap = 650`). Tag `BoostPad`.

## Obstáculos animados (Beta 1.8)
- Pêndulo, hélice, pistões, portal de laser, gêiseres. Tag `Hazard`, Models com `ModelStreamingMode Atomic`.
- **Só existem no cliente como movimento**, sem colisão física (`CanCollide false`), então o carro não fica preso.
- `Client.HazardController`: pose pelo **relógio do servidor**, só anima até 520 studs da câmera; batida por
  segmento × caixa (não atravessa em alta velocidade) → `Drive.Hit` + tela vermelha + "OUCH!" + tremor.
- Números em `Config.Track.Hazards` (Every, SpeedMult 0,4, Duration 1,3, Knock 42, Periods, Kinds por bioma).
- 51 obstáculos no total; bioma 1 começa vazio (pedido do dono): pêndulo -190, hélice -510, pistão -1010,
  laser -1645, hélice -2775.

## Decoração japonesa high-tech (bioma 1, 1.4d/1.4e)
Torii neon, lanternas de pedra, painéis com kanji, cerejeiras low-poly, pagodes, shimenawa, taikobashi,
nobori, kanji holográficos girando (`HoloSpin`), varais de lanternas.

Relacionado: [Mapa (WorldBuilder)](../05_Modelagem/Mapa_WorldBuilder.md) · [Carros e direção](Carros_e_Direcao.md) · [Biomas](../03_Conteudo/Biomas.md) · [Beta 1.8](../07_Versoes/Beta_1.8.md)
