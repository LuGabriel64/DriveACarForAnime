---
title: Carros e direção
date: 2026-11-14
tags: [sistema, carro, fisica]
aliases: [DriveController, CarService]
---

# Carros e direção

## Física
- O carro é **um corpo único com suspensão por raycast** (`Client.DriveController`). Não usa rodas reais:
  estável em terreno irregular, não "agarra" em degraus e é barato em rede.
- O **cliente é dono da física** do carro (`SetNetworkOwner(player)`). Por isso o servidor confere a posição
  ([anti-trapaça](Anti_Trapaca.md)).
- Teto global `Config.SpeedCap = 700` studs/s (acima disso o raycast atravessa pontes).
- Boost pad: velocidade máxima × 1,6. Pad de lentidão: teto × 0,45 por 1,4 s. Gelo (`IceZone`): menos aderência.
- Batida em obstáculo (`Drive.Hit`, 1.8): freia × 0,4 por 1,3 s, corta 70% da velocidade e empurra.

## Carros normais (Config.Cars)
Starter Hatch (T1, 70) · Sakura GT (T2, $25K, 105) · Dune Racer (T3, $400K, 150) · Frost Runner (T4, $5M, 210) ·
Magma Reaper (T5, $70M, 290) · Neon Phantom (T6, $1B, 390) · Celestial Comet (T7, $15B, 520).
Tier N abre o bioma N. Upgrade de motor com custo por tier (`Engine.TierMult`).

## Carros de F1 (1.9, só na corrida 1v1)
Rookie F-01 (grátis, 230) · Viper F-02 ($150K, 270) · Storm F-03 ($5M, 310) · Phantom F-04 ($150M, 350) ·
Apex F-05 ($5B, 400). Sem tier e sem motor. Com boost o mais rápido chega a 640 (< 700).

## CarService
- Carro **estacionado** na garagem; `DriveCar` / `ExitCar` (o cliente aplica o ponto de descida, `ExitCF`).
- **Lobby só a pé** (1.4): `DriveCar` responde "LobbyWalk"; o RaceService senta o jogador no grid.
- `VehicleSeat.Disabled` no lobby (1.4d); prompt Drive some com o banco ocupado (1.6b).
- 1.9: `Spawn(player, cf, seat, cfgOverride)` cria o F1 (atributo `F1`); compra/equipar/upgrade recusados em partida.

## Visual
`Client.CarVisuals`: aura de energia no boost ("BoostAura", 1.2), faróis com SpotLight (0.2.0).

Relacionado: [Carros (CarFactory)](../05_Modelagem/Carros_CarFactory.md) · [Pista e obstáculos](Pista_e_Obstaculos.md) · [Corrida 1v1 de F1](Corrida_1v1_F1.md) · [Biomas](../03_Conteudo/Biomas.md)
