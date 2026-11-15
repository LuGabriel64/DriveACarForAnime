---
title: Referência — personagens do bioma 1 (2026-11-15)
date: 2026-11-15
tags: [referencias, imagens, personagens, beta-2-0, ip]
substitui: Referencias_Antigas.md (avatar R6 com rosto de anime, 10/11)
---

# Referência — personagens do bioma 1 (15/11/2026)

**Pedido junto com as imagens:** remodelar o elenco do bioma 1 com base nestas imagens; criar o Mini Goku
(Épico, 2 skins, também voando ao lado do carro), um Secret (Goku Super Saiyajin, com aura) e um Mítico
(Majin Vegeta).

> [!NOTE]
> O dono numerou as imagens contando 21; chegaram 20 arquivos (limite de anexos). A partir da 12ª, o número
> do dono é o número do arquivo **mais um**. A tabela usa as duas numerações.

| Arquivo | Nº do dono | Imagem | Destino no jogo |
|---------|-----------|--------|-----------------|
| 05 | 5 | ![mirim com bastão](imagens/2026-11-15_beta2_05.png) | Mini Gokun, skin clássica (laranja/azul) |
| 06 | 6 | ![mirim low-poly roxo](imagens/2026-11-15_beta2_06.webp) | Mini Gokun, skin roxa; **nível de detalhe alvo (low-poly)** |
| 11 | 12 | ![adulto em clay](imagens/2026-11-15_beta2_11.png) | Gokun (Common) |
| 12 | 13 | ![transformado em T](imagens/2026-11-15_beta2_12.webp) | Super Gokun (Secret, com aura) |
| 13 | 14 | ![careca de quimono](imagens/2026-11-15_beta2_13.png) | Kurilin (Common) |
| 14 | 15 | ![armadura rasgada](imagens/2026-11-15_beta2_14.png) | Majin Vegita (Mythic) |
| 15 | 16 | ![armadura azul e branca](imagens/2026-11-15_beta2_15.png) | Vegita (Uncommon) |
| 16 | 17 | ![cabelo azul em T](imagens/2026-11-15_beta2_16.png) | Majin Vegita (pose e proporção) |
| 17 | 18 | ![armadura com ombreiras](imagens/2026-11-15_beta2_17.png) | Vegita (Uncommon), armadura completa |
| 18 | 19 | ![mestre musculoso](imagens/2026-11-15_beta2_18.webp) | Master Kamo (Rare) |
| 19 | 20 | ![jovem em clay](imagens/2026-11-15_beta2_19.png) | Gohen (Epic) |
| 20 | 21 | ![jovem de capa](imagens/2026-11-15_beta2_20.png) | Gohen (Epic), capa e cores |

**Copiar (estilo):** proporções (chibi no mirim; heroica nos adultos), silhueta do cabelo, paleta das roupas,
pose, a aura no Secret.

**Não copiar:** os emblemas do peito (kanji), o "M" da testa e qualquer marca; não baixar nem importar
modelos 3D de terceiros. Os modelos do jogo são feitos do zero, em low-poly, com os **nomes alterados** que o
jogo já usa (Gokun, Kurilin, Vegita, Master Kamo, Gohen). Ver [Decisões](../08_Pedidos_e_Decisoes/Decisoes.md), linha 6 e linha 27.

## Resultado (estudo, versão 1): Mini Gokun

![Mini Gokun, duas skins](imagens/2026-11-15_resultado_mini_gokun_v1.png)

Low-poly próprio (4.168 triângulos), peças separadas para animar por código (cabeça, tronco, braços, pernas,
cauda, bastão, nuvem). Falta: o resto do elenco, a aura, e importar no jogo.

**Antes × agora:** em 10/11 a referência era um avatar R6 em blocos com rosto de anime, e o elenco inteiro
virou "blocos anime" (Beta 1.8b). Agora o pedido é por **malhas modeladas**, mais próximas de figuras 3D.
Os blocos continuam como reserva (o `AnimeModelFactory` cai neles quando não há malha).

Relacionado: [Referências visuais](INDEX.md) · [Personagens](../03_Conteudo/Personagens.md) · [Personagens blocos anime](../05_Modelagem/Personagens_Blocos_Anime.md) · [Beta 2.0](../07_Versoes/Beta_2.0.md)
