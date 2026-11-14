---
title: Sistemas guardados (Features)
date: 2026-11-14
tags: [sistema, legado]
aliases: [Config.Features, Legado]
---

# Sistemas guardados (Features)

**Regra do projeto:** sistemas antigos **não são apagados**; ficam desligados atrás de `Config.Features`,
porque o dono pode querer de volta.

| Feature | Valor | O que é |
|---------|-------|---------|
| Eggs | true | sistema de personagens por ovos |
| BiomeEggs | true | ovo gigante no fim do bioma (loop atual) |
| StartMenu | true | tela de início |
| LobbyDock | true | dock do lobby (false traz de volta o menu lateral do HUD e o botão RACE) |
| CaptureNodes | false | mini-jogo de captura da 0.1.0 (`AnimeService`, `EncounterUI`, `AnimeNodes`) |
| RoadEggs | false | ovos de estrada grátis (`EggService`, `EggNodes`) |
| Shrines | false | santuários pagos e `EggShop` |

- Em jogo, `Map.EggNodes` e `Map.EggShrines` vão para `ServerStorage.DisabledAtRuntime` (o mapa do editor não muda).
- Código antigo de modelos: `ServerStorage.LegacyCode` (AnimeModelFactory voxel 1.6 e chibi 1.7).
- Lobby antigo: `WorldBuilder.BuildLobbyBeta12`. Lobby alternativo nunca aplicado: `Tools.LobbyBuilder`.
- Personagens antigos: `Legacy = true` no Config (não saem em ovos; existem para saves antigos).

Relacionado: [Convenções](../06_Codigo/Convencoes.md) · [Personagens](../03_Conteudo/Personagens.md) · [Decisões](../08_Pedidos_e_Decisoes/Decisoes.md)
