---
title: Personagens
date: 2026-11-14
tags: [conteudo, personagens]
aliases: [Elenco, Config.Animes]
---

# Personagens

`Config.Animes` tem 71 entradas: **50 ativas** (saem em ovos) e o resto `Legacy = true` (só para saves antigos).
Formato: `A(id, nome, bioma, raridade, renda, Look)`. Modelo procedural automático (`AnimeModelFactory`).
Cada bioma tem as 7 raridades (o sorteio depende disso); o bioma 1 tem 2 Common.

## Elenco ativo

| Raridade | 1 Azure Planet | 2 Sakura Valley | 3 Sunset Dunes | 4 Frozen Tundra |
|---|---|---|---|---|
| Common | Gokun ($3), Kurilin ($4) | Hanami Student | Desert Wanderer | Snowy Scout |
| Uncommon | Vegita | Kitsune Kiri | Sand Dancer Zahra | Yukiko the Skater |
| Rare | Master Kamo | Shrine Maiden Rei | Pharaoh Prince Amun | Frost Mage Frey |
| Epic | Gohen | Oni Warrior Gen | Mecha Pilot Zero | Blizzard Knight Borea |
| Legendary | Cello | Samurai Kenji | Dragon Slayer Kaito | Ice Empress Kori |
| Mythic | Pikollo | Moon Princess Tsuki | Sun Goddess Amara | Polar Spirit Fenri |
| Secret | Majin Bubu ($12K) | Blossom Spirit Sakuya | Eternal Sphinx Sefet | Frost Wyrm Kaida |

| Raridade | 5 Volcano Rift | 6 Neon City | 7 Celestial Peaks |
|---|---|---|---|
| Common | Ember the Blacksmith | Street Racer Rin | Cloud Apprentice Wisp |
| Uncommon | Cinder Imp Piko | Hacker Kuro | Star Archer Selene |
| Rare | Magma Brawler Gor | Idol Star Mimi | Sky Monk Tenzo |
| Epic | Fire Dancer Ignia | Cyber Samurai Hayate | Celestial Valkyrie Brynn |
| Legendary | Demon General Zagan | Mecha Queen Nova | Dragon Emperor Ryujin |
| Mythic | Phoenix Empress Hinoko | Neon God Kaizen | Creator Goddess Aeon |
| Secret | Inferno Titan Volka | Glitch Phantom Null | Origin Star Lumina ($72B/s) |

## O caso do bioma 1 (propriedade intelectual)
- 1.1–1.5: só originais (o assistente recusou DBZ por risco de remoção).
- 1.3: 8 lutadores originais (Ryo, Toru, Varek, Hoji, Ren, Zerak, Oru, Moko) — hoje Legacy.
- **1.6:** o dono pediu expressamente o elenco de DBZ e assumiu o risco (exceção na regra 13 do `02_AI_Protocol`).
- **1.7:** nomes **levemente alterados** a pedido do dono: Gokun, Kurilin, Vegita, Master Kamo, Gohen, Cello,
  Pikollo, Majin Bubu. Ids iguais (goku, kuririn…) → saves válidos. **Não** copiar emblemas (kanji do peito).
- **Não ampliar** a exceção para outros biomas sem pedido expresso. ULTs têm nomes originais.

Legacy também: Warrior Canyon 1.1 (Kenta, Rio, Bao, Raika, Ryuen, Garon, The Nameless Champion) e Verdant Plains 0.1.

Relacionado: [Raridades e mutações](Raridades_e_Mutacoes.md) · [Personagens blocos anime](../05_Modelagem/Personagens_Blocos_Anime.md) · [Batalha de anime](../02_Sistemas/Batalha_de_Anime.md) · [Decisões](../08_Pedidos_e_Decisoes/Decisoes.md)
