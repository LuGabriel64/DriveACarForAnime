---
title: Mapa (WorldBuilder)
date: 2026-11-14
tags: [modelagem, mapa, ferramenta]
aliases: [WorldBuilder, VersusBuilder]
---

# Mapa (WorldBuilder)

`ServerStorage.Tools.WorldBuilder` (~2.400 linhas) é uma **ferramenta de edição**: roda no Studio em modo
Edit, nunca durante o jogo. **O mapa sai sempre dele; não editar à mão** (é reproduzível e determinístico).

## Terreno
Heightmap por Perlin noise com `Terrain:WriteVoxels`; parâmetros interpolados entre biomas (`BlendZone`, sem
degrau na fronteira); estrada plana (`Config.World.RoadX`) num corredor de colinas e paredões; terraços no bioma 1.
O Roblox desenha o terreno **2 studs acima** do valor escrito (meio voxel) — compensado com `cell/2`.

## Funções principais
```lua
local WB = require(game.ServerStorage.Tools.WorldBuilder)
WB.StyleTerrain(); workspace.Terrain:Clear(); WB.BuildTerrain(420, 0)
for i, b in ipairs(Config.Biomes) do WB.BuildTerrain(b.ZStart, (i == #Config.Biomes) and b.ZEnd - 60 or b.ZEnd) end
WB.BuildLobbyTerrain(); WB.BuildLobby()   -- lobby Sakura Night
WB.BuildMap()                              -- lobby + largada + portões (não apaga biomas)
for i = 1, #Config.Biomes do WB.BuildBiome(i) end
-- extras: BuildChallenges(i), BuildHazards(i), ThinBoostPads(i), BuildJapanTechDecor(i), BuildLanternGarlands(i)
-- 1.9: BuildVersusHall(), BuildArena(i), BuildVersus()  (atalhos do Tools.VersusBuilder)
```
Um passo por vez para não travar o Studio.

## Estrutura do Workspace.Map
Drivable/<bioma> (pontes, passarelas, lombadas — o raycast usa isto + Terrain) · Props/<bioma> (decoração,
JapanTech, Hazards) · Plots/Plot_1..8 · Structures (Lobby, StartLine, Gates) · BoostPads · EggNodes/EggShrines
(guardados) · BiomeEggs (runtime) · Versus (1.9).

## Cuidados
- Antes de gerar: **clonar o Config** (cache de `require` no editor devolve a versão antiga).
- Funções locais definidas mais abaixo no arquivo não existem para as de cima (por isso `WorldBuilder.PROP`).
- Conferir se o `Enum.Material` existe ("CorrugatedMetal" não existe).
- Conferir **duplicatas na raiz do Workspace** (dois `Map` em 11/11/2026).
- Vista de longe no Studio mostra o terreno em LOD baixo: a pista "some". Não é bug.
- `Tools.LobbyBuilder`: lobby alternativo de 04/11, **nunca aplicado** (decisão aberta do dono).

Relacionado: [Pista e obstáculos](../02_Sistemas/Pista_e_Obstaculos.md) · [Biomas](../03_Conteudo/Biomas.md) · [Lobby Sakura Night](../03_Conteudo/Lobby_Sakura_Night.md) · [Pegadinhas técnicas](../09_Erros_e_Licoes/Pegadinhas_Tecnicas.md)
