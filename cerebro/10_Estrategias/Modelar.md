---
title: Estratégia — modelar
date: 2026-11-14
tags: [estrategia, modelagem]
---

# Modelar

1. **Tudo procedural, tudo pelo Config**: personagem = `Look` no Config + `AnimeModelFactory`; carro = `CarFactory`;
   mapa = `WorldBuilder` / `VersusBuilder`. Reproduzível, versionado, fácil de ajustar.
2. **Partir da referência do dono**: identificar proporções (cabeça, corpo), traço característico (rosto de anime,
   cabelo em espetos) e paleta. Gerar 3–5 opções lado a lado no Workspace, capturar tela e deixar o dono escolher;
   apagar as descartadas e registrar quais eram (1.8b fez assim: A, B, C, D, E).
3. **Contratos fixos**: personagem com Root nos pés e frente -Z; carro com Chassis/Seat/Wheel_*; garagem com
   Base/Title/Label, Slots, CarPad, CarSpawn, PlayerSpawn. Trocar o visual sem quebrar o código.
4. **Performance**: peças ancoradas e sem colisão na decoração; `CanQuery/CanTouch` falsos; animar só perto da câmera
   (520 studs para obstáculos, 1.200 para hologramas); `ModelStreamingMode Atomic` em modelos animados.
5. **Determinismo**: `Random.new(semente)` por bioma; regenerar dá o mesmo mapa.
6. **Medir o chão real** antes de apoiar peças (terreno em meio voxel).
7. **Conferir em captura** (`screen_capture`) de perto; vista de longe tem LOD baixo.
8. **Originalidade**: inspiração de clima geral, nunca nomes, logos, emblemas ou golpes reconhecíveis.

Relacionado: [Personagens blocos anime](../05_Modelagem/Personagens_Blocos_Anime.md) · [Mapa (WorldBuilder)](../05_Modelagem/Mapa_WorldBuilder.md) · [Carros (CarFactory)](../05_Modelagem/Carros_CarFactory.md) · [Referências visuais](../11_Referencias_Visuais/INDEX.md)
