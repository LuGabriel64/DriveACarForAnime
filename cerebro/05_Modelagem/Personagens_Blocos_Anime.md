---
title: Personagens (blocos anime)
date: 2026-11-14
tags: [modelagem, personagens]
aliases: [AnimeModelFactory]
---

# Personagens — estilo "blocos anime"

`ReplicatedStorage.Shared.AnimeModelFactory` (Beta 1.8b). Usado pelo servidor (garagem, vitrine) e pelo
cliente (ViewportFrames). `Build(cfg, mut, size)` → Model (PrimaryPart "Root" nos **pés**; frente = **-Z**;
~7 studs + cabelo). `Silhouette(model)` recolore tudo de preto.

## Anatomia (referência do dono: avatar R6 com rosto de anime e cabelo esculpido)
- Alturas: botas 0–1 · calça 1–2,9 · tronco 2,9–4,9 · cabeça 4,9–6,9 (bloco 2,1 × 2,0 × 1,95) · cabelo por cima.
- Rosto em peças finas: esclera, íris, pupila, brilho, cílio e sobrancelha inclinados pela `Expression`
  (confident / angry / happy / calm), boca (smirk / flat / smile).
- Cabelo com prismas pontudos: spiky, flame, short, long, twin, bun. `Bald` para careca.
- Acessórios: headband scarf hat chefhat foxears tail horns halo crown cape sword wings beanie visor staff
  beard turban antenna crest headtail belt mecha.
- Roupa: Skin Hair Eyes Outfit (tronco) Outfit2 (calça) AccColor BeltColor + Under, Sleeve, LongSleeve, Gloves,
  Wrist, Shoe, BootTrim, Gi, Expression, Brow.
- Peças `Anchored`, sem colisão, SmoothPlastic; atributo `NoTint` para peças que não recebem a cor da mutação.

## Evolução
| Versão | Estilo | Onde está hoje |
|--------|--------|----------------|
| 0.1–1.6 | voxel / low-poly chunky, cabeça grande | `ServerStorage.LegacyCode.AnimeModelFactory_Voxel_Beta16` |
| 1.7 | chibi arredondado (elipsoides por SpecialMesh Sphere) | `LegacyCode.AnimeModelFactory_Chibi_Beta17` |
| **1.8b** | **blocos anime R6** (vale para todos) | ativo |

Opções descartadas na 1.8b: A chibi, B herói anime, D colecionável, E modelo IA.
Secret tem aura/anel/estrela (1.1). O símbolo do peito da referência **não** foi copiado.

## Pipeline para modelos de fora (Blender, ainda não usado)
Root nos pés, frente -Z, ~6 studs; exportar FBX; Asset Manager → Bulk Import; Model chamada `<Id>`; a factory
passaria a preferir `ServerStorage/Models/Animes/<Id>` quando existir.

Relacionado: [Personagens](../03_Conteudo/Personagens.md) · [Estratégia de modelagem](../10_Estrategias/Modelar.md) · [Referências visuais](../11_Referencias_Visuais/INDEX.md) · [Beta 1.8b](../07_Versoes/Beta_1.8b.md)
