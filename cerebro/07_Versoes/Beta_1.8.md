---
title: Beta 1.8 — obstáculos animados
date: 2026-11-10
tags: [versao]
autor: Claude
---

# Beta 1.8 (10/11/2026)

- Obstáculos **animados** nos 7 biomas: pêndulo, hélice, pistões, portal de laser, gêiseres (`HazardController`,
  `WorldBuilder.BuildHazards`). Sem colisão física; punição = `Drive.Hit`.
- Boost pads de 143 para 46.
- Ajustes pedidos pelo dono: começo da pista vazio; "bola vermelha" investigada (era lanterna flutuando →
  varais; a de verdade eram as 18 lanternas do lobby empilhadas em (0,0,0) por causa do **StreamingEnabled** →
  atributo `Home` + `ModelStreamingMode Atomic`); textos do ovo menores.
- Testado: hélice derrubou o carro com "OUCH!"; pistão, laser, gêiser, pêndulo conferidos.

Relacionado: [Beta 1.7](Beta_1.7.md) · [Beta 1.8b](Beta_1.8b.md) · [Pista e obstáculos](../02_Sistemas/Pista_e_Obstaculos.md) · [Erros corrigidos](../09_Erros_e_Licoes/Erros_Corrigidos.md)
