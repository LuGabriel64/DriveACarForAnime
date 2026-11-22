---
title: Decisões
date: 2026-11-14
tags: [decisoes, adr]
---

# Decisões (registro)

Cada linha: o que foi decidido, por quê e onde mudar. Decisões do **dono** são marcadas com 👑.

| # | Decisão | Por quê | Onde mudar |
|---|---------|---------|------------|
| 1 | **Pista fantasma**: uma pista para todos, cada um no seu slot, sem se ver | 8 cópias = ~200 mil peças | RaceService, GhostController |
| 2 | Colapso **visual por jogador**, regra no servidor | pista compartilhada | EscapeService / EscapeFX |
| 3 | **DataService próprio** em vez de ProfileService | evitar código de terceiros do Toolbox | DataService |
| 4 | Sistemas antigos **guardados** atrás de `Config.Features` | o dono pode querer de volta | Config.Features |
| 5 | 👑 Tabela de raridades **normalizada** (soma 99,86) | escolha do dono | Config.Rarities |
| 6 | 👑 **Elenco estilo DBZ no bioma 1** (1.6), nomes alterados (1.7); não ampliar | o dono assume o risco | Config.Animes, regra 13 |
| 7 | Obstáculos animados **sem colisão**; punição `Drive.Hit` | carro não fica preso | HazardController |
| 8 | Corrida 1v1 na **mesma pista** (modo Duel) | cópia = 43 mil peças e manutenção | RaceService, ZoneService |
| 9 | Carros 1v1 **se veem mas não colidem** | evita empurrão e física entre clientes | grupos de colisão |
| 10 | Batalha **automática** simulada no servidor | o mais forte vence; sem trapaça; roda no celular | BattleSim |
| 11 | Nível também aumenta a renda (+1%/nível) | status sobem com o nível | `Config.Levels.IncomePerLevel` |
| 12 | XP da corrida vai para o **parceiro** | não há personagem em jogo | ProgressService |
| 13 | Personagens antigos ficam com **0★** | justiça com quem já joga | DataService.migrate |
| 14 | Prêmio do vencedor = **2 min da renda** (mín. $500) | valor fixo seria enorme ou irrelevante | Config.Versus.Rewards |
| 15 | Depois de **10 partidas** contra o mesmo adversário, só XP | anti-farm | Rewards.FullRewardsPerOpponent |
| 16 | Nomes de ULT **originais** | regra 13 (exceção cobre elenco, não golpes) | Config.Battle.Fighters |
| 17 | Variação de dano ±8% | imprevisível entre iguais | Config.Battle.Sim.Variance |
| 18 | Bandeiras desenhadas **com Frames** | emoji não é garantido | StartMenu |
| 19 | Locale próprio (texto em inglês = chave) em vez da tradução automática do Roblox | permite escolher no jogo e versionar | Shared.Locale |
| 20 | EscapeFX **não** generalizado na 1.9 | risco de quebrar a fuga | DuelRaceUI |
| 21 | Espelho sem Python (MirrorDump + Node) | PC do dono não tem Python | tools/place |
| 22 | Mapa duplicado **movido** para backup, não apagado | segurança | Backups["Beta 1.8b"] |
| 23 | Carros gerados por **script do Blender** (paramétrico), não esculpidos à mão | reproduzível, versionado, 21 carros de 3 carrocerias | `arte/blender/` |
| 24 | Pintura dos carros por textura + cor por vértice, **sem logotipos** de marcas | assets autocontidos e sem marca de terceiros | `f1_themes.py` |
| 25 | Os 7 ids de carro atuais viram a classe A do bioma; B e C são ids novos | nenhum save quebra | Config.Cars |
| 26 | Combustível medido no **servidor**; piloto automático no **cliente**, validado pelo servidor | o cliente é dono da física | RaceService, Client.Autopilot |
| 27 | Personagens em **low-poly próprio**, inspirado nas referências; sem cópia fiel, sem emblemas, sem modelos baixados da web | obra e marca de terceiros; risco de remoção e de punição da conta | `planejamento/beta-2.0/README.md` |
| 28 | Tanque cheio a cada largada; combustível desligado na corrida 1v1 | simplicidade; equilibrar depois | Config (Beta 2.0) |
| 29 | Personagens deixam de ser blocos: escultura por SDF com cel-shading pintado nos vértices (dono pediu estilo anime 2.5D, 16/11) | o estudo v1 ficou "boneco de blocos"; o dono quer músculo, sombra e rosto másculo | `arte/blender/sdflib.py`, `char_hero.py` |
| 30 | Um corpo só, reaproveitado: adulto, Super (cabelo + aura) e Mini (mesmas peças achatadas) | consistência entre personagem e companheiro; menos trabalho por variante | `char_hero.py` (`chibi`) |
| 31 | Versões antigas da arte ficam guardadas no repositório (pedido do dono) | comparar o antes e o depois | `arte/blender/char_mini.py`, `arte/export/mini_gokun_*.fbx` |
| 32 | Carros de Fórmula v1 **aprovados** pelo dono em 16/11 | "O dos carros está perfeito" | `arte/export/` |
| 33 | Estilo de personagem v2/v3 (escultura SDF, cel-shading) **aprovado** pelo dono em 16/11, com ajustes de rosto e mãos | "Ficou muito maneiro! Adorei!" | `arte/blender/char_hero.py` |
| 34 | Animação por **peças rígidas** calculada em código (pose + ondas), sem Humanoid nem AnimationTrack | funciona com MeshParts soltos, é barata, roda igual no ViewportFrame e a mesma tabela serve ao Blender e ao Roblox | `Shared.CharacterRig`, `Shared.CharacterAnims` |
| 35 | A pose mora num lugar só (`IDLE` em `char_hero.py`); `CharacterAnims` é arquivo **gerado** | evitar duas versões da mesma animação | `tools/art/anims_to_luau.js` |
| 36 | Duas densidades por personagem: vitrine (66 a 73 mil triângulos) e jogo (24 a 27 mil) | o jogo roda em celular; a vitrine serve para render e loja | `lod=0.35` |
| 37 | Versões antigas de arte vão para `arte/arquivo/<nome>_vN/`; `arte/export/` só tem o que é atual | o dono pediu para guardar; a pasta de upload fica limpa | `arte/arquivo/` |
| 38 | Malhas importadas ficam em `ReplicatedStorage.Assets` (não no Workspace), **sem PackageLink**, com `Root` no chão e frente em -Z | o importador gira o modelo; a correção só vale na cópia local; os sistemas clonam de um lugar só | `ReplicatedStorage.Assets.LEIA-ME` |
| 39 | Personagens no jogo usam a **versão de jogo** (`*_v3_game.fbx`) | 24 a 27 mil triângulos cabem no celular; a vitrine (66 a 73 mil) fica só para render | `arte/export/assets_roblox.json` |
| 40 | A Beta 2.0 sai em partes: **2.0** = malhas + animação; 2.0b combustível; 2.0c piloto automático; 2.0d primeira pessoa + 21 carros | entregar o que já está testado sem esperar o resto; cada parte com backup e tag | `CHANGELOG.md` |
| 41 | Os 7 carros atuais usam a malha da **classe A** do bioma; os 5 F1 do 1v1 usam B/C; Ids e números iguais | save e economia não mudam; as outras malhas ficam para a loja de 21 carros | `Config.CarMeshes`, `Config.F1Meshes` |
| 42 | Super Gokun = **Secret** ($12.000/s) e Mini Gokun = **Epic** ($100/s) no bioma 1, dividindo o sorteio com Majin Bubu e Gohen | pedido de 15/11; renda igual à da raridade | `Config.Animes` |
| 43 | Tudo da malha atrás de `Config.Features.MeshArt` | regra do projeto: sistema antigo guardado, volta com uma chave | `Shared.Config` |
| 44 | Peças de malha com `Color` **branco** | a cor da peça multiplica a cor por vértice; branco = cor do Blender; preto = silhueta; mutação = tinta | `ReplicatedStorage.Assets` |

Relacionado: [Pedidos do dono](Pedidos_do_Dono.md) · [Requisitos permanentes](Requisitos_Permanentes.md) · [Arquitetura](../06_Codigo/Arquitetura.md)
