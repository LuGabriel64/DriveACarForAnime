---
title: Lobby Sakura Night
date: 2026-11-14
tags: [conteudo, mapa, lobby]
desde: Beta 1.4
---

# Lobby Sakura Night

Ilha flutuante em `Config.Lobby.Origin` (0, 0, 3200), **sem estrada até a pista**, **só a pé**
(`Config.Lobby.WalkOnly`). Noite só no lobby (`Config.Lobby.Sky`, meia-noite com lua + Exposure).
Gerado por `WorldBuilder.BuildLobby` (zonas em `Config.Lobby.Zones`, relativas à origem; -Z = lado da pista).

## Zonas
| Zona | O que tem |
|------|-----------|
| Praça Sakura (centro) | spawn, cerejeira gigante, bancos, 18 lanternas flutuantes |
| Race Gate (norte) | palco com escadas, torii "PLAY", portal (`RacePortal`) |
| Garagens 1–4 (oeste) e 5–8 (leste) | faixas ciano em x = ±80; interior japonês noturno |
| Car Showroom (sudeste) | 3 giratórios: carro equipado / próximo / sonho |
| Hall of Heroes (sudoeste) | pódio: cópia do avatar + 4 melhores personagens |
| Sul | arco do jogo |
| Borda | lagos koi, pagodes, cerejeiras, lua, paredes invisíveis (ninguém cai) |

Pastas: `Map.Structures.Lobby/{Plaza, RaceGate, GarageRow, Showroom, HallOfHeroes, Paths, Decor, Barrier}`.
Tags: ShowroomPad, ShowcasePad, CarShopKiosk, InventoryKiosk, LobbyLantern, KoiFish.

> [!WARNING]
> O terreno do lobby é desenhado em **y ≈ 2** (meio voxel). `BuildLobby` mede o chão e apoia tudo nele.

## Histórico
- 1.2: lobby flutuante separado (antes era um hub ligado à pista).
- 1.4: Sakura Night + dock + lobby a pé. 1.4b: cerejeiras novas e garagens japonesas.
- 1.5: máquinas de venda removidas; quiosques da roleta (removidos na 1.7).
- 1.8: lanternas empilhavam em (0,0,0) por causa do StreamingEnabled → atributo `Home` + Atomic.

Relacionado: [Versus Hall e arenas](Versus_Hall_e_Arenas.md) · [Mapa (WorldBuilder)](../05_Modelagem/Mapa_WorldBuilder.md) · [Incubadora e garagem](../02_Sistemas/Incubadora_e_Garagem.md) · [Beta 1.4](../07_Versoes/Beta_1.4.md)
