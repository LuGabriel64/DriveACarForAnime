---
title: Personagens por escultura SDF no Blender (Beta 2.0)
date: 2026-11-16
tags: [modelagem, blender, personagens, cel-shading, beta-2-0]
---

# Personagens por escultura SDF (Beta 2.0, v2 da arte)

Como os personagens novos são feitos. Substitui o estudo de blocos (`arte/blender/char_mini.py`, guardado).

## Arquivos

| Arquivo | Papel |
|---------|-------|
| `arte/blender/sdflib.py` | a "escultura": grade, primitivas (elipsoide, cápsula, caixa), união suave, dobras, surface nets, redução, pintura cel |
| `arte/blender/char_hero.py` | o personagem: cabeça, tronco, braço, perna, cabelo, nuvem, aura; variantes; render e FBX |
| `arte/export/gokun.fbx`, `super_gokun.fbx`, `mini_gokun_v2_classic.fbx`, `mini_gokun_v2_violet.fbx` | saídas |
| `arte/export/personagens.json` | peças, triângulos, juntas (pivôs) e escala de cada personagem |
| `arte/renders/<id>.png` | folha de cada um (frente, 3/4, costas, rosto) |

```bash
"D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --python arte/blender/char_hero.py -- "<pasta arte>" [gokun super mini_classic mini_violet]
```

Roda sem o MCP do Blender. Os 4 personagens levam cerca de 2 minutos (a escultura fica em cache em `%TEMP%/dacfa_sdf_cache`).

## A ideia

1. **Um corpo só**, esculpido em metros (pés em z = 0, frente = -Y). Cada volume é um campo de distância; a
   **união suave** (`smin`) funde os volumes. `k` pequeno deixa um vinco (músculo definido), `k` grande funde macio (tecido).
2. **Dobras de roupa** são traços desenhados em vista frontal (`strokes`): sobem macio e caem de uma vez; a queda vira linha.
3. **Malha:** surface nets (numpy) → Decimate do Blender até o orçamento de triângulos.
4. **Cascas separadas por cor** (pele, quimono, camiseta, faixa, bota...), fechadas e sobrepostas, como roupa de verdade.
   Assim a divisa entre as cores fica nítida sem textura.
5. **Rosto:** polígonos em vista frontal (sobrancelha, olho, íris, boca) projetados na pele por raio.
6. **Cabelo:** mechas facetadas (seção em losango ao longo de uma curva), sem suavização: planos chapados como no 2D.
7. **Cel-shading pintado nos vértices** (`shade`): luz fixa, dois tons, contraluz, sombra projetada por raio (cabelo na
   testa, queixo no pescoço) e linha de tinta onde a curvatura é côncava (`cavity`). No Roblox vira cor por vértice.
8. **Contorno:** no render é casca invertida (Solidify). No Roblox usar `Highlight` (limite de ~31 visíveis) ou casca invertida.

## Variantes a partir do mesmo corpo

| Variante | O que muda |
|----------|------------|
| Gokun | cabelo preto espetado |
| Super Gokun | cabelo dourado para cima, olho verde-água, peça `Aura` (translúcida; no Roblox, partículas) |
| Mini Gokun | as MESMAS peças achatadas por peça (`chibi`): cabeça 1,85x, tronco 44% da altura, perna 30%; + `Tail`, `Staff`, `Cloud` |
| Skin violeta | troca só a paleta |

Peças rígidas (um MeshPart cada, animadas por código): `Head`, `Hair`, `Torso`, `ArmL`, `ArmR`, `LegL`, `LegR`.

## Números (16/11)

| Personagem | Triângulos | Maior peça |
|------------|-----------|------------|
| Gokun | 56 299 | Torso 14 500 |
| Super Gokun | 57 395 | Torso 14 500 |
| Mini Gokun | 63 431 | Torso 14 500 |

**Pesado para o jogo.** Antes de importar, gerar uma versão de jogo (meta: 15 a 20 mil por personagem, nenhuma peça
acima de 10 mil) baixando os alvos de `shell_from(...)`. A versão atual é a de vitrine.

## Limites honestos

- Não é escultura à mão no ZBrush: é procedural. Mãos, orelhas e boca são simples.
- A sombra é pintada com luz fixa; no Roblox a iluminação do jogo soma por cima.
- Só o corpo do Gokun existe. Kurilin, Vegita, Master Kamo, Gohen e Majin Vegita precisam de cabeça, cabelo e roupa próprios
  (o corpo e a biblioteca se reaproveitam).
- Nada disso foi importado no Roblox ainda.

Relacionado: [Carros de F1 no Blender](Carros_F1_Blender.md) · [Personagens (blocos anime)](Personagens_Blocos_Anime.md) · [Referências 16/11](../11_Referencias_Visuais/2026-11-16_Gokun_Referencias_v2.md) · [Beta 2.0](../07_Versoes/Beta_2.0.md) · [Pegadinhas técnicas](../09_Erros_e_Licoes/Pegadinhas_Tecnicas.md)

Up: [Modelagem](INDEX.md)
