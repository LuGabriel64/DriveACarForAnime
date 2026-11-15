---
title: Carros de F1 no Blender
date: 2026-11-15
tags: [modelagem, carro, blender, beta-2-0]
aliases: [f1lib, Pipeline Blender]
---

# Carros de F1 no Blender (Beta 2.0)

Os carros deixam de ser montados com peças do Roblox e passam a ser **malhas geradas por script no Blender**.
O script fica no repositório (`arte/blender/`), então qualquer um regera os 21 carros com um comando.

## Como é feito
- **Blender em segundo plano** (`blender --background --python ...`): não precisa de janela nem do MCP.
- **Peças paramétricas** (`f1lib.py`): `loft` (corpo por seções em superelipse), `wing` (asa por estações),
  `tube` (halo, neon), `lathe` (pneus, calotas, escapamento), `spike` (cabelo, cristais, chamas), `prism`, `strut`.
- **3 carrocerias** (`f1_build.py`): A Rookie (clássica, rodas com raios) · B Pro (efeito solo, barbatana,
  calotas, halo) · C Hyper (canopy fechado, para-lamas, 2 turbinas). 8 a 10 mil triângulos.
- **21 pinturas** (`f1_themes.py`): textura 1024×1024 pintada com numpy em coordenadas do carro (studs).
  Metade de cima = vista lateral; metade de baixo = vista de cima. Sem logotipos.
- **Acessórios por bioma**: cabelo espetado, cauda e aura (1), flores e torii (2), disco solar (3), cristais e
  aurora (4), chamas e chifres (5), neon (6), auréola e asas (7).

## Anatomia e proporção
1 unidade = 1 stud; frente = −Y no Blender (−Z no Roblox). Entre-eixos 11,6; bitola 7,8; comprimento ~19;
roda dianteira raio 1,5 e traseira 1,62. Mais "gordinho" que um F1 real, de propósito: lê melhor de longe e
combina com o resto do jogo.

## Papéis (um objeto por papel → MeshParts)
`Body` (textura) · `Trim` (cor por vértice) · `Glow` (Neon) · `Glass` · `Acc` · `Wheel_FL/FR/RL/RR`.
O contrato do [CarFactory](Carros_CarFactory.md) continua: `Chassis`, `Seat`, soldas `Wheel_*`.

## Estado
✅ gerados, renderizados e exportados (`arte/export/*.fbx`). ❌ ainda não importados no Roblox, nunca dirigidos.

## Para melhorar (v2)
Ombro dos pneus mais definido; costura lado/topo da pintura no bico; acessórios mais ricos; LOD; aerofólios
com perfil mais fino.

Relacionado: [Carros (CarFactory)](Carros_CarFactory.md) · [Referência dos carros](../11_Referencias_Visuais/2026-11-15_Beta2_Carros_F1.md) · [Modelar](../10_Estrategias/Modelar.md) · [Beta 2.0](../07_Versoes/Beta_2.0.md) · [Carros e direção](../02_Sistemas/Carros_e_Direcao.md)
