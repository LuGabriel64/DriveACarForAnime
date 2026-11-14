---
title: Carros (CarFactory)
date: 2026-11-14
tags: [modelagem, carro]
aliases: [CarFactory]
---

# Carros (CarFactory)

`ReplicatedStorage.Shared.CarFactory.Build(cfg, preview)` → Model (PrimaryPart = **Chassis**; frente = -Z).
`preview = true` → versão ancorada sem assento, para ViewportFrame.

## O contrato (não quebrar)
- Peças **`Chassis`**, **`Seat`** (VehicleSeat) e Welds **`Wheel_FL/FR/RL/RR`**.
- `WheelRadius 1,8`; `WheelPoints` FL (-4,3, -0,2, -4,7) … RR (4,3, -0,2, 4,7); `Rest` = raio + 1,0; `RayLength` = Rest + 0,8.
- A física é do `DriveController` (raycast), não das rodas. Trocar o visual por um modelo do Blender é só
  manter esse contrato.
- Peças sem colisão, `Massless`, SmoothPlastic, estilo voxel/chunky; faróis com SpotLight; cores `Color`/`Accent` do Config.

## Corpo F1 (1.9)
`cfg.Body == "f1"`: baixo e largo, bico, asa dianteira e traseira, entradas laterais, halo, rodas expostas.
Banco em (0, 0,2, 0,9). Chassis, Seat e rodas iguais aos do carro normal → a física não muda. 34 peças.
**Ainda não foi dirigido** (só o modelo foi montado).

## Ideias de skins originais (Guia do bioma 1)
Hover Pod (disco sem rodas visíveis) · Dome Runner (buggy com cúpula) · Aura Striker (esportivo branco com listras
de energia) · Arena Cruiser (jipe de torneio).

Relacionado: [Carros e direção](../02_Sistemas/Carros_e_Direcao.md) · [Corrida 1v1 de F1](../02_Sistemas/Corrida_1v1_F1.md) · [Backlog de ideias](../12_Ideias_e_Roadmap/Backlog_de_Ideias.md)
