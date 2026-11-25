# Beta 2.0 — Projeto (em andamento desde 15/11/2026)

> **Status em 15/11/2026:** Etapa A (arte dos carros no Blender) **feita em primeira versão**: 21 carros de
> Fórmula modelados, pintados e exportados em `arte/export/`. **Nada foi aplicado no jogo ainda**: o Roblox
> Studio estava fechado nesta sessão. As Etapas B a E abaixo estão projetadas, não escritas.
> Escrito pelo Claude Code local do dono (Fable 5.2). Leia junto com `cerebro/07_Versoes/Beta_2.0.md`.

## O que o dono pediu (15/11/2026)

| # | Pedido | Etapa | Estado |
|---|--------|-------|--------|
| 1 | Carros de **Fórmula 1 modelados no Blender** para os carros do jogo, com pintura ligada ao bioma | A | ✅ 1ª versão (21 FBX + pinturas), **aprovada pelo dono em 16/11** |
| 2 | **3 carros por bioma** (21 no total) | A / C | ✅ arte · ⏳ Config e loja |
| 3 | Carros do bioma 1 com as cores do tema e **acessórios** | A | ✅ 1ª versão |
| 4 | **Mini Goku voando junto** do carro, com animação | B | ⏳ modelo v2 pronto (`mini_gokun_v2_*.fbx`); falta importar e animar |
| 5 | Personagem **Mini Goku**, Épico, com **2 skins** (cor da roupa) | B / D | ⏳ arte v2 nas 2 skins; falta o jogo |
| 6 | Elenco do bioma 1 **remodelado** pelas imagens de referência; novo **Secret** (Goku Super Saiyajin, com aura) e novo **Mítico** (Majin Vegeta) | D | ⏳ ver "Fidelidade e propriedade intelectual" |
| 7 | Corrida em **primeira pessoa** (podendo voltar para a terceira) | C | ⏳ projetado |
| 8 | Escolha **Manual / Automático** antes da contagem | C | ⏳ projetado |
| 9 | **Piloto automático** que traça a rota mais segura, desvia dos obstáculos, pega o ovo e foge do colapso; carro melhor = bot melhor | C | ⏳ projetado |
| 10 | **Skill-checks** no modo automático; falha = fumaça, apito, luzes e alerta | C | ⏳ projetado |
| 11 | **Combustível** limitado | C | ⏳ projetado |
| 12 | **Engine upgrade** com teto na velocidade base do carro seguinte; novo upgrade de **motor de combustível** | C | ⏳ projetado |
| 13 | Integrar ao GitHub e ao Obsidian | todas | ✅ nesta sessão |

## Atualização de 16/11/2026 — personagens v2

O dono aprovou os carros e pediu outro estilo para os personagens: anime 2.5D com cel-shading, músculos, rosto másculo e
nuvem com fumaça (9 imagens novas, guardadas em `cerebro/11_Referencias_Visuais/`). A arte de personagem foi refeita:

| Arquivo | O que é |
|---------|---------|
| `arte/blender/sdflib.py` | escultura por campos de distância + cel-shading pintado nos vértices |
| `arte/blender/char_hero.py` | Gokun, Super Gokun (aura), Mini Gokun clássico e violeta, a partir de um corpo só |
| `arte/export/gokun.fbx`, `super_gokun.fbx`, `mini_gokun_v2_classic.fbx`, `mini_gokun_v2_violet.fbx` | saídas (56 a 63 mil triângulos: versão de vitrine) |
| `arte/export/personagens.json` | peças, triângulos, juntas (pivôs) e escala |
| `arte/renders/gokun.png`, `super_gokun.png`, `mini_gokun_v2_classic.png`, `mini_gokun_v2_violet.png` | folhas (frente, 3/4, costas, rosto) |

Como funciona, números e limites: `cerebro/05_Modelagem/Personagens_SDF_Blender.md`. A v1 (`char_mini.py`) fica guardada.

**Versão de jogo:** feita na atualização seguinte (`lod=0.35`, 24 a 27 mil triângulos, nenhuma peça acima de 5,1 mil).
Os arquivos da v2 citados acima foram para `arte/arquivo/personagens_v2/`.

**Bloqueio da Etapa B (16/11):** o Studio está ligado, mas o upload foi recusado porque a pasta `arte\export` não está
na lista de pastas aprovadas (Assistant Settings → MCP Permissions → pastas de upload). O jogo é de um grupo
(id 879120012), então o `creationContext.creator` do upload é `{"groupId":"879120012"}`.

## Atualização de 25/11/2026 — Beta 2.0b (painel DEV) e nova numeração

O dono pediu um painel só dos DEVs e os créditos; isso virou a **Beta 2.0b** (place versão 135). Por isso as próximas
etapas mudaram de letra: **2.0c** = combustível + teto do motor + Fuel Engine; **2.0d** = Manual/Auto + piloto
automático + skill-checks; **2.0e** = primeira pessoa + 21 carros na loja. Para testar essas etapas, use o painel DEV
(dinheiro, carros, personagens) em vez de correr.

## Atualização de 22/11/2026 (2) — APLICADA AO JOGO (Beta 2.0, place versão 132)

Feito: `CarFactory` com malha (todos os 12 carros da Config), `AnimeModelFactory` com malha (Gokun + novos Super Gokun
Secret e Mini Gokun Epic), `Client.CharacterAnimator`. Atrás de `Config.Features.MeshArt`. Diferenças do projeto:
- as malhas ficaram em `Assets.Characters` (não `Assets.Animes`) e o personagem aponta com `Look.Mesh`;
- os 7 carros atuais usam a classe A do bioma e os F1 do 1v1 usam B/C; as outras 9 malhas esperam a loja de 21 carros;
- skin violeta do Mini e Majin Vegita ainda não (precisam de save V4 e de malha).

Próximas versões: **2.0b** = combustível + teto do motor + Fuel Engine; **2.0c** = Manual/Auto + piloto automático +
skill-checks; **2.0d** = primeira pessoa + 21 carros na loja; elenco em malha quando o dono aprovar cada personagem.

## Atualização de 22/11/2026 — importação feita

A pasta foi aprovada e as malhas estão no place, em `ReplicatedStorage.Assets` (`Cars/<21 ids>`, `Characters/<4 ids>`),
prontas para clonar. IDs em `arte/export/assets_roblox.json`; formato de cada modelo no `LEIA-ME` da pasta
(`src/ReplicatedStorage/Assets/LEIA-ME.luau`). **O jogo ainda não usa os modelos.** Próximo: `CarFactory` montando o
carro com `Assets.Cars[id]` (rodas `Wheel_FL/FR/RL/RR`, `Root` no chão, frente em -Z), garagem e vitrine com
`Assets.Characters` + `CharacterRig.Play`, depois a Etapa C.

## Atualização de 16/11/2026 (2) — personagens v3, animação de parado, primeira peça no place

O dono aprovou o estilo e pediu rosto mais fino de anime, mãos com mais detalhe e animações de parado.

| Arquivo | O que é |
|---------|---------|
| `arte/export/gokun_v3.fbx`, `super_gokun_v3.fbx`, `mini_gokun_v3_classic.fbx`, `mini_gokun_v3_violet.fbx` | v3 de vitrine (66 a 73 mil triângulos) |
| `arte/export/<id>_game.fbx` | **versão de jogo** (24 a 27 mil): é esta que se importa no Roblox |
| `arte/export/personagens_anim.json` | animações de parado (pose + ondas), em studs |
| `arte/renders/idle_personagens.mp4`, `<id>_idle.png`, `gokun_v3_detalhes.png` | vídeo e folhas |
| `arte/arquivo/personagens_v1/`, `personagens_v2/` | versões antigas guardadas |
| `src/ReplicatedStorage/Shared/CharacterRig.luau`, `CharacterAnims.luau` | **já no place**: motor de animação por peças rígidas e os dados |
| `tools/art/anims_to_luau.js`, `tools/art/rig_reference.py` | gerar `CharacterAnims`; conferir o rig contra o Blender |

Peças de cada personagem: `Head`, `Hair`, `Torso`, `ArmL`, `ForeL`, `ArmR`, `ForeR`, `LegL`, `ShinL`, `LegR`, `ShinR`
(+ `Tail`, `Staff`, `Cloud`, `Smoke` no mirim; + `Aura` no Super).

**Para ligar no jogo (depois do upload):** importar o `_game.fbx`; montar um `Model` com um `Root` invisível nos pés
(frente em -Z) como `PrimaryPart` e as peças ancoradas com esses nomes, em repouso; no cliente,
`require(ReplicatedStorage.Shared.CharacterRig).Play(model, "gokun" | "super_gokun" | "mini_gokun")`. Conferir a
orientação: o FBX sai com a frente do personagem em +Z; o `Root` tem de ficar com a frente em -Z.

**Testado:** a conta do rig no Studio contra o Blender, com boneco de blocos (`Rig.DebugProxy`). **Não testado:** com as
malhas reais. Detalhes: `cerebro/05_Modelagem/Animacao_Idle_CharacterRig.md`.

## Etapas

| Etapa | Conteúdo | Precisa de |
|-------|----------|-----------|
| **A** | Arte dos carros: gerador paramétrico no Blender, 21 pinturas, acessórios, FBX | Blender (feito, em segundo plano) |
| **B** | Importar os carros no Roblox (Open Cloud) e trocar o `CarFactory` para usar as malhas; companheiro voador | Studio aberto + permissão de upload |
| **C** | Jogo: 21 carros no Config e na loja, combustível, upgrades, primeira pessoa, Manual/Automático, piloto automático, skill-checks, falhas | Studio aberto |
| **D** | Personagens do bioma 1 em malha + 3 personagens novos (Epic com 2 skins, Mythic, Secret com aura) | Studio + decisão do dono sobre fidelidade |
| **E** | Fechamento: testes, `Config.Version = "Beta 2.0"`, ChangeLog, espelho, tag `beta-2.0` | Studio |

Backup antes de tocar no place: `ServerStorage.Backups["Beta 1.9"]`.

## Etapa A — o que existe (arte dos carros)

Tudo é gerado por código, sem arquivo externo e **sem logotipos de marcas** (as referências tinham FIA, Pirelli
e outras: não foram copiadas).

| Arquivo | O que é |
|---------|---------|
| `arte/blender/f1lib.py` | biblioteca: peças (loft, asa, tubo, torno, espinho), cor por vértice, UV da pintura, cena e render |
| `arte/blender/f1_build.py` | o carro: 3 carrocerias (A Rookie, B Pro, C Hyper), cerca de 8 a 10 mil triângulos |
| `arte/blender/f1_themes.py` | as 21 pinturas (textura 1024×1024 pintada com numpy) e os acessórios por carro |
| `arte/blender/f1_all.py` | gera tudo: FBX, pinturas, renders, `.blend` |
| `arte/export/<id>.fbx` + `<id>_livery.png` | um carro por arquivo, pronto para o Roblox (frente = −Z, 1 unidade = 1 stud) |
| `arte/export/carros.json` | nome, bioma, carroceria, triângulos e medidas das rodas de cada carro |
| `arte/renders/carros_f1.png` | folha com os 21 carros (linhas = biomas 1 a 7; colunas = A, B, C) |
| `arte/blend/f1_carros.blend` | todos os carros numa grade, para abrir e editar no Blender |

Para gerar de novo:

```bash
"D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --python arte/blender/f1_all.py -- "C:/Users/Lucas Gabriel/Documents/DriveACarForAnime/arte"
```

**Estrutura de cada FBX** (vira um Model com MeshParts no Roblox):
`Body` (pintura por textura) · `Trim` (carbono, suspensão, capacete; cor por vértice) · `Glow` (vira Neon) ·
`Glass` · `Acc` (acessórios do bioma) · `Wheel_FL/FR/RL/RR` (giram).

**Os 21 carros** (ids provisórios de arte; os ids do jogo estão em "Carros no Config"):

| Bioma | A (Rookie) | B (Pro) | C (Hyper) |
|-------|-----------|---------|-----------|
| 1 Azure Planet | Turtle Trainer (laranja/azul, cabelo espetado, cauda) | Prince Vanguard (branco/azul/dourado, ombreiras, visor verde) | Golden Aura (dourado, cabelo dourado, chamas de aura) |
| 2 Sakura Valley | Petal Runner | Shrine GT (torii na asa) | Moon Blossom (lanternas) |
| 3 Sunset Dunes | Sand Skipper | Pharaoh (disco solar) | Sunset Scarab |
| 4 Frozen Tundra | Snow Fox | Glacier (cristais) | Aurora |
| 5 Volcano Rift | Ember | Magma Vein | Inferno Titan |
| 6 Neon City | Street Volt | Cyber Circuit | Glitch Phantom |
| 7 Celestial Peaks | Cloud Hopper | Star Archer (auréola) | Origin Comet (asas) |

**Testado:** os 21 geram sem erro; renders conferidos na folha; FBX e PNG gravados.
**NÃO testado:** importar no Roblox (escala, cor por vértice, Neon, textura embutida); dirigir; primeira pessoa.
**Conhecido:** é uma primeira versão de forma e pintura. Detalhes a melhorar depois do retorno do dono:
ombros do pneu, costura lateral/superior da pintura no bico, acessórios mais ricos.

## Etapa B — levar para o Roblox

1. O dono abre o Studio e, em **Assistant Settings → MCP Permissions**, libera os escopos `asset:read` e
   `asset:write` e aprova a pasta `C:\Users\Lucas Gabriel\Documents\DriveACarForAnime\arte\export`.
2. O Claude envia cada FBX pelo `open_cloud_invoke` (`POST /assets/v1/assets`, tipo Model), espera a operação
   e insere com `insert_asset` em `ReplicatedStorage.Assets.Cars.<id>`.
3. Ajuste no Studio (script de edição, idempotente): escala pela bitola das rodas, `Glow` = Neon,
   `Glass` = Glass com transparência, colisão desligada, pivôs das rodas.
4. `Shared.CarFactory.Build(cfg)`: se `cfg.Mesh` existir em `Assets.Cars`, clona a malha e cria `Chassis`,
   `Seat` e as soldas `Wheel_*` (mesmo contrato de hoje); senão, cai no carro por peças (nada quebra).
   Os pontos das rodas passam a vir do carro (`carros.json`): frente z = −6,0, trás z = +5,6, x = ±3,9.

Se o upload por Open Cloud não for liberado: o dono importa os FBX à mão (Studio → Importar 3D) e o Claude
faz os passos 3 e 4.

## Etapa C — sistemas de jogo (especificação)

### Carros no Config (21)

- `Tier` continua sendo o bioma (1 a 7). Cada tier tem 3 carros: classe A, B e C.
- **Os 7 ids atuais não mudam** (saves continuam válidos): viram a classe A do seu bioma, com nome e malha
  novos. Ids novos: `<bioma>_b` e `<bioma>_c`.
- Velocidade: A = a do tier hoje; B e C sobem em direção ao A do tier seguinte.
- Preço: entre o preço do tier e o do seguinte, em progressão geométrica.

| Tier | A | B | C |
|------|---|---|---|
| 1 | 70 · grátis | 82 · $5K | 94 · $12K |
| 2 | 105 · $25K | 120 · $60K | 135 · $160K |
| 3 | 150 · $400K | 170 · $900K | 190 · $2,2M |
| 4 | 210 · $5M | 236 · $12M | 262 · $30M |
| 5 | 290 · $70M | 322 · $170M | 356 · $420M |
| 6 | 390 · $1B | 432 · $2,5B | 476 · $6B |
| 7 | 520 · $15B | 575 · $60B | 640 · $250B |

Os 5 carros de F1 da corrida 1v1 (Beta 1.9) continuam separados.

### Engine upgrade com teto (pedido 12)

- Hoje o upgrade de motor não tem limite ligado ao próximo carro. Passa a ter **5 níveis**: no nível 5 a
  velocidade chega exatamente à velocidade base do **carro seguinte** da lista.
  `velocidade = base + (base_do_seguinte − base) × nível / 5`. O último carro usa +10%.
- Saves com nível acima do teto novo: o nível é limitado ao teto e a diferença paga é devolvida em Cash.

### Combustível e Fuel Engine (pedidos 11 e 12)

- Cada carro tem `FuelCap` (tanque) e `FuelUse` (gasto por 100 studs). O tanque enche a cada largada.
- O **servidor** mede o caminho percorrido (já faz isso para a anti-trapaça) e publica o atributo `Fuel`.
  Boost gasta +60%. Sem combustível: velocidade cai para 30% ("OUT OF FUEL") e o orçamento da
  anti-trapaça cai junto, então não dá para burlar no cliente.
- Tanque base: classe A cobre 1,10× a ida e volta até o ovo do próprio bioma; B 1,25×; C 1,45×.
  Assim o primeiro carro funciona sem upgrade, mas desperdiçar caminho custa a fuga.
- **Fuel Engine** (novo upgrade, embaixo do Engine na loja): 5 níveis; cada nível aumenta o tanque e reduz
  o gasto até chegar nos valores do carro seguinte. Save: `data.Cars[id].Fuel` (nível).
- HUD: barra de combustível ao lado do velocímetro; pisca e apita abaixo de 20%.
- Corrida 1v1 (F1): combustível desligado nesta versão.

### Manual ou Automático (pedido 8)

Ao tocar em PLAY, antes da contagem, um painel pergunta **MANUAL** (você dirige) ou **AUTO** (o bot dirige e
você faz os skill-checks). Lembra a última escolha. `StartRace(mode)` → atributo `DriveMode`.
No modo AUTO há sempre o botão **TAKE CONTROL** para assumir a direção.

### Piloto automático (pedido 9)

Roda no cliente (o cliente é dono da física do carro), dentro de um módulo novo `Client.Autopilot`, que
entrega acelerador e volante ao `DriveController` no lugar do teclado. O servidor continua validando tudo
(distância, fuga, combustível) como no modo manual.

- **O que ele enxerga:** eixo da pista, pontes estreitas e desfiladeiros, obstáculos animados (tag `Hazard`,
  com a fase pelo relógio do servidor), pads de lentidão e de boost, o ovo do bioma (`Config.BiomeEggZ`) e a
  frente do colapso (atributos `Escape*`).
- **Rota mais segura:** a pista à frente é cortada em fatias e 7 faixas laterais. Cada casa recebe um custo
  (obstáculo no instante em que o carro chega lá, pad de lentidão, fora da ponte = proibido, troca de faixa)
  e um bônus (boost seguro). Programação dinâmica acha o caminho de menor custo; é refeito 5 vezes por segundo.
- **Habilidade do carro** (`AutoSkill`): chance de seguir a rota ótima a cada decisão. Carro A do bioma 1
  ≈ 62%; sobe por classe e por tier até ≈ 97%. Quando "erra", pega uma rota vizinha pior.
  Carros melhores também olham mais longe (180 → 320 studs) e fazem curvas mais suaves, o que gasta menos
  combustível.
- **Ovo e fuga:** para na distância do prompt, segura o `GrabPrompt`, espera a roleta, dá meia-volta e foge
  até a base com o mesmo planejador. Se o combustível projetado não fecha a conta, entra em modo econômico
  (não usa boost).

### Skill-checks e falhas (pedido 10)

- A cada 10 a 18 s (mais frequente em carro pior) aparece um skill-check no estilo da UI do jogo: um
  ponteiro corre num arco e o jogador aperta ESPAÇO / toca na faixa certa (PERFECT, GOOD, MISS).
- PERFECT: o bot segue a rota ótima a 100% até o próximo check e ganha um mini boost. GOOD: normal.
- MISS: **FALHA** por 4 s: fumaça no motor, apito, luzes piscando, alerta "ENGINE FAILURE!" na tela;
  o carro perde 35% de velocidade e o volante treme. Três falhas seguidas: o motor apaga por 3 s.
- Tudo com `UIKit` + `Platform` (no celular o arco fica embaixo, ao centro, com alvo de toque grande).

### Primeira pessoa (pedido 7)

No GO a câmera vai para o cockpit (o bico, o halo e as rodas dianteiras ficam visíveis; o avatar fica
invisível só para o próprio jogador). Tecla **V** ou botão de câmera alterna para a terceira pessoa.
A escolha fica salva em `Settings.FirstPerson`.

## Etapa D — personagens

- Malhas em `ReplicatedStorage.Assets.Animes.<id>`; o `AnimeModelFactory.Build` usa a malha quando existe e
  cai no modelo em blocos quando não existe.
- Novos no bioma 1: **Mini Gokun** (Epic, 2 skins: laranja/azul e roxa; campo salvo `Skin`), **Majin Vegita**
  (Mythic), **Super Gokun** (Secret, com aura). Cada um ganha classe e ULT de nome original na batalha.
- Companheiro voador: o Mini Gokun numa nuvem, ao lado do carro (só nos carros do bioma 1), animado por código
  (`Client.Companion`): sobe e desce, inclina nas curvas, comemora no boost.
- Save **Version 4** (só campos novos): `Cars[id].Fuel`, `Animes[i].Skin`, `Settings.FirstPerson`, `Settings.DriveMode`.

### Fidelidade e propriedade intelectual

O dono pediu os personagens "extremamente fiéis" às imagens e modelos 3D prontos da web. O que o Claude faz e
não faz:

- **Faz:** modelos low-poly próprios, no espírito das referências (proporção, silhueta do cabelo, paleta),
  mantendo a linha que o jogo já segue desde a Beta 1.6/1.7: nomes alterados, sem emblemas.
- **Não faz:** copiar um personagem um a um, usar kanji/emblemas/esferas com estrelas, nem baixar e importar
  modelos de terceiros (são obras de outras pessoas e de uma marca registrada; no Roblox isso derruba o asset
  e pode punir a conta do dono, que é quem faz o upload).
- A regra 13 do `02_AI_Protocol` continua valendo: a exceção cobre o elenco do bioma 1, e o risco é do dono.

## Decisões tomadas (o dono pode mudar)

| # | Decisão | Por quê |
|---|---------|---------|
| 1 | Carros gerados por **script do Blender**, não esculpidos à mão | reproduzível, versionado no Git, 21 carros saem de 3 carrocerias |
| 2 | Pintura por **textura + cor por vértice**, sem logotipos | cada carro é um FBX autocontido; nada de marca de terceiros |
| 3 | Os 7 ids de carro atuais viram a classe A | nenhum save quebra |
| 4 | Combustível medido no **servidor** | o cliente é dono da física; se o cliente medisse, daria para burlar |
| 5 | Piloto automático no **cliente**, validado pelo servidor | mesma arquitetura do modo manual |
| 6 | Tanque cheio a cada largada | simples; sem posto, sem preço de gasolina |
| 7 | Combustível desligado na corrida 1v1 | os F1 do 1v1 correm o mapa inteiro; equilibrar depois |
| 8 | Personagens em low-poly inspirado, sem cópia fiel | ver seção acima |

## O que só o dono pode fazer

1. Abrir o **Roblox Studio** no place (sem ele nada entra no jogo).
2. Liberar o upload de assets (Etapa B, passo 1).
3. Olhar `arte/renders/carros_f1.png` e dizer o que mudar nos carros (forma, cores, acessórios).
4. (Opcional) Ligar o servidor MCP dentro do Blender, para o Claude trabalhar na cena que você está vendo.
   Sem isso funciona igual: o Blender roda em segundo plano.
