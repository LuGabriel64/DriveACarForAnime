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

## Modelar no Blender (desde a Beta 2.0)
1. **Script, não clique**: gerador em Python (`arte/blender/`) rodando com `blender --background`; funciona sem janela e sem MCP.
2. **Primeiro a forma, depois a cor**: render em clay das carrocerias, olhar a imagem, corrigir a proporção; só então pintura e acessórios.
3. **Olhar o render toda vez** (o Claude lê o PNG): enquadramento, luz estourada e peça fora do lugar só aparecem na imagem.
4. **Papéis em vez de materiais**: um objeto por função (Body, Trim, Glow, Glass, Acc, rodas) vira um MeshPart; cor por vértice no que não é pintura.
5. **Pintura em coordenadas do objeto** (studs), não em pixels: o desenho cai no lugar certo em qualquer carroceria.
6. **Orçamento**: 8 a 10 mil triângulos por carro; cerca de 4 mil por personagem; peças rígidas separadas para animar por código.
7. **Referência do dono**: copiar proporção, silhueta e paleta; nunca logotipos, emblemas ou o modelo de outra pessoa. Ver [Carros de F1 no Blender](../05_Modelagem/Carros_F1_Blender.md).

Relacionado: [Personagens blocos anime](../05_Modelagem/Personagens_Blocos_Anime.md) · [Mapa (WorldBuilder)](../05_Modelagem/Mapa_WorldBuilder.md) · [Carros (CarFactory)](../05_Modelagem/Carros_CarFactory.md) · [Referências visuais](../11_Referencias_Visuais/INDEX.md)
