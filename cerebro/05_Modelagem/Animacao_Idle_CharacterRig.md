---
title: Animação de parado dos personagens (CharacterRig, Beta 2.0)
date: 2026-11-16
tags: [modelagem, animacao, codigo, personagens, beta-2-0]
---

# Animação de parado (idle) por peças rígidas

Pedido do dono (16/11): "eles parados ficam se movendo em uma pose específica".

## Como funciona

O personagem é feito de **peças rígidas** (um MeshPart cada). A animação é uma **pose** (ângulo de cada junta)
mais **ondas** (senos) somadas a ela. Não há Humanoid, Motor6D nem AnimationTrack.

| Onde | O quê |
|------|-------|
| `arte/blender/char_hero.py`, tabela `IDLE` | **fonte** da pose e das ondas (um lugar só) |
| `arte/export/personagens_anim.json` | o mesmo dado, em studs, escrito pelo Blender |
| `tools/art/anims_to_luau.js` | gera `Shared.CharacterAnims` a partir do JSON |
| `ReplicatedStorage.Shared.CharacterAnims` | dados no jogo (arquivo gerado, não editar à mão) |
| `ReplicatedStorage.Shared.CharacterRig` | motor: `Rig.Play(model, id)`, `Rig.Stop`, `Rig.new` + `rig:Update(t)`, `Rig.DebugProxy` |
| `tools/art/rig_reference.py` | pontos de referência do Blender para conferir o motor do Roblox |

Peças e pais: `Torso` ← Root; `Head`, `ArmL`, `ArmR`, `Tail`, `Staff` ← Torso; `Hair` ← Head; `ForeL` ← ArmL;
`ForeR` ← ArmR; `LegL`, `LegR`, `Cloud`, `Aura` ← Root; `ShinL` ← LegL; `ShinR` ← LegR; `Smoke` ← Cloud.

## As três animações

| Id | Nome | Pose | O que mexe |
|----|------|------|-----------|
| `gokun` | Fighting stance | corpo de lado, perna da frente dobrada, um punho na guarda e o outro na cintura | respiração, braços, cabeça e cabelo |
| `super_gokun` | Power up | pernas abertas, braços abertos com os punhos fechados, queixo baixo | tremor rápido, cabelo, aura subindo e girando |
| `mini_gokun` | Cloud rider | em pé na nuvem, uma mão na cintura e a outra acenando | nuvem sobe e desce, fumaça, aceno, cauda |

Os períodos das ondas dividem 4 s, então a animação fecha em laço.

## Convenção de ângulos (eixos do modelo no Blender)

- `a` gira em X: positivo inclina tronco e cabeça para a frente; num membro pendurado, positivo leva para **trás**
  (o cotovelo dobra com `a` negativo; o joelho dobra com `a` positivo).
- `b` gira em Y: negativo abre o membro **esquerdo** para fora; positivo abre o **direito**.
- `c` gira em Z: positivo vira para a esquerda do personagem.
- Composição: `Rz(c) * Rx(a) * Ry(b)` em torno da junta, no espaço do pai.
- No Roblox: X = X, Z do Blender = Y, Y do Blender = -Z; o Root fica com a frente em -Z (meia-volta em Y).

## Como mudar uma pose

1. Edite `IDLE` em `char_hero.py`.
2. Rode o Blender (`char_hero.py`): sai o vídeo `arte/renders/idle_personagens.mp4` e o JSON.
3. `node tools/art/anims_to_luau.js` e aplique `CharacterAnims` no Studio.
4. Pé no chão: a linha `GROUND` do Blender mostra a altura de cada pé na pose; os dois têm de ficar perto de zero.

## Testado / não testado (16/11)

- **Testado:** poses e vídeo no Blender. No Studio (modo Edit), com um boneco de blocos (`Rig.DebugProxy`), 117 pontos
  de referência batem com a conta do Blender (diferença máxima de 0,0008 stud).
- **Testado em 22/11 com as malhas reais** (`ReplicatedStorage.Assets.Characters`, modo Edit): poses e pés no chão iguais ao Blender.
- **Não testado:** no Play, no celular, no ViewportFrame, com muitos personagens na tela.

## Limites

- Sem tornozelo nem dedos articulados: o pé gira junto com a canela, então as poses mantêm a canela quase em pé.
- A sombra é pintada na malha com luz fixa; ao girar uma peça, a sombra gira junto (em movimentos pequenos não se nota).
- Só existe a animação de parado. Golpe, vitória e corrida ainda não.

Relacionado: [Personagens por SDF](Personagens_SDF_Blender.md) · [Mapa de scripts](../06_Codigo/Mapa_de_Scripts.md) · [Beta 2.0](../07_Versoes/Beta_2.0.md) · [Referência da cabeça](../11_Referencias_Visuais/2026-11-16_Gokun_Cabeca_v3.md)

Up: [Modelagem](INDEX.md)
