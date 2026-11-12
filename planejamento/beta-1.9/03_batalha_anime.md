# 03 — Batalha de anime

Números em `Config.Battle` e `Config.Versus.Battle`. Contas em `Shared.AnimeStats`. Simulação em
`Services.BattleSim` (escrita, testada e calibrada — ver `testes/`).

## Como funciona

1. Mesmo convite, sala de espera, votação e preparação da corrida ([01](01_arquitetura.md)). A votação é da **arena**.
2. Na preparação (30 s) cada jogador escolhe **um lutador** entre os seus personagens (padrão: o de maior
   Poder) e a **animação de vitória** (pode comprar na loja do Versus Hall).
3. O servidor monta os status dos dois lutadores a partir do save de cada jogador, **simula a luta inteira**
   e define o vencedor. O cliente não manda nenhum número.
4. Os dois recebem o **roteiro** da luta e assistem à mesma encenação: entrada, golpes, críticos,
   esquivas, ULTs com corte de câmera, nocaute e a animação de vitória.
5. Tela de resultado com as recompensas ([04](04_progressao_e_recompensas.md)).

Quem tem o personagem mais forte vence. Dois personagens iguais, com as mesmas estrelas e o mesmo nível,
dão uma luta de 50/50 (testado: 50,6% em 2.000 lutas).

**Por que simular no servidor e só encenar no cliente**
- Não dá para trapacear: o resultado e as recompensas já estão decididos quando a luta começa a passar.
- Não há lutador físico no servidor, então não há atraso nem peças disputadas entre clientes.
- Várias batalhas cabem na mesma arena ao mesmo tempo: cada tela desenha só a sua.
- Funciona igual no celular, que só precisa tocar a animação.

## Status de cada personagem

Todo personagem passa a ter seis status de batalha, além da renda:

| Status | Na tela (EN / PT) | Efeito na luta |
|--------|-------------------|----------------|
| HP | Health / Vida | quanto dano aguenta |
| ATK | Strength / Força | dano de cada golpe |
| DEF | Defense / Defesa | reduz o dano recebido |
| SPD | Speed / Velocidade | quem ataca primeiro, chance de crítico e de esquiva |
| ASPD | Attack Speed / Vel. de Ataque | intervalo entre os golpes |
| POW | Powers / Poderes | carrega a ULT mais rápido e fortalece a ULT mágica |

Tudo sai de um número só, o **Poder**:

```
Poder = raridade × bioma × estrelas × nível × mutação × tamanho
```

| Fator | Valores |
|-------|---------|
| Raridade | Common 100 · Uncommon 135 · Rare 180 · Epic 245 · Legendary 330 · Mythic 450 · Secret 620 |
| Bioma | +25% por bioma depois do primeiro (bioma 7 = ×2,5) |
| Estrelas | +7,5% por estrela (5★ = ×1,375) |
| Nível | +2% por nível acima do 1 (nível 50 = ×1,98) |
| Mutação | Gold ×1,15 · Diamond ×1,35 |
| Tamanho | BIG ×1,10 |

Depois a **classe** distribui o Poder entre os status.

### Classes

| Classe | Estilo | ULT | Efeito da ULT |
|--------|--------|-----|---------------|
| Brawler | bate forte | Burst | um golpe enorme (×3,0) |
| Guardian | aguenta muito, bate menos | Bulwark | golpe (×2,0) + escudo de 12% da vida máxima |
| Speedster | rápido, ataca mais vezes | Flurry | cinco golpes seguidos (5 × 0,62) |
| Mystic | carrega a ULT mais rápido | Nova | golpe mágico (×2,4) que ignora metade da defesa e cresce com POW |
| Champion | equilibrado | Finisher | golpe forte (×2,8), 50% maior se o alvo estiver abaixo de 35% de vida |

**Calibragem:** os multiplicadores de cada classe foram ajustados por simulação até que, com o mesmo Poder,
nenhuma classe precise de mais de 3,3% de Poder extra para empatar com outra. Isso é menos que meia
estrela. A classe muda o jeito da luta, não quem vence. O teste falha se alguém mexer nos números e
quebrar esse equilíbrio.

### Exemplos (calculados pelo módulo real)

| Personagem | Poder | Vida | Força | Defesa | Renda |
|------------|-------|------|-------|--------|-------|
| Gokun (Common, bioma 1), 0★ nível 1 | 100 | 1.632 | 118 | 46 | $3/s |
| Gokun 5★ nível 1 | 138 | 2.244 | 162 | 63 | $4,13/s |
| Gokun 5★ nível 50 | 272 | 4.443 | 321 | 125 | $6,15/s |
| Majin Bubu (Secret, bioma 1), 0★ nível 1 | 620 | 11.606 | 558 | 366 | $12K/s |
| Majin Bubu 5★ nível 50 | 1.688 | 31.598 | 1.519 | 996 | $24,6K/s |
| Origin Star Lumina (Secret, bioma 7), 0★ nível 1 | 1.550 | 23.064 | 1.550 | 736 | $72B/s |

Resultados dos testes:
- Raridade maior vence a raridade logo abaixo (mesmo bioma) em 97% ou mais das lutas.
- A mesma personagem com 1 estrela a mais venceu todas as 1.000 lutas do teste.
- Um Mythic nível 50 vence um Secret nível 1: treinar compensa.

## Regras da luta (simulação)

- Cada lutador ataca no seu ritmo: 1,15 s entre golpes, ajustado pela Vel. de Ataque (de 0,65× a 1,5×).
- O mais rápido ataca primeiro. Com Velocidade igual, o servidor sorteia.
- Dano de um golpe = `ATK × ATK / (ATK + DEF do alvo)`, com variação de ±8%.
- Crítico (×1,6): 5% de base, sobe com a vantagem de Velocidade (de 3% a 35%).
- Esquiva: 4% de base, sobe com a vantagem de Velocidade (até 25%).
- **Energia:** +25 ao acertar, +10 ao apanhar, +6 ao esquivar. Com 100, o próximo ataque é a **ULT**, que
  nunca erra.
- Vida do alvo em 0 = nocaute. Depois de 60 s, vence quem tiver maior porcentagem de vida.

Uma luta entre personagens iguais dura cerca de 19 s de combate (de 17 a 23 s nos testes), com várias ULTs
de cada lado. Somando a entrada (3,5 s) e o final (4 s), a cena tem perto de 30 s. Quando um lutador é
bem mais forte, a luta acaba mais rápido.

## ULT de cada personagem

Cada um dos 50 personagens ativos tem **nome de ULT e efeito visual próprios** em `Config.Battle.Fighters`
(ex.: Gokun "Azure Wave", Samurai Kenji "Moonlit Slash", Origin Star Lumina "Origin Supernova").
Os personagens antigos (Legacy) usam "Power Strike". O teste confere que nenhum personagem ativo ficou sem ULT.

Os nomes são **originais**. A exceção de propriedade intelectual aprovada pelo dono vale para o elenco do
bioma 1, não para golpes; por isso não usei nomes de golpes de animes existentes.

Efeitos visuais (`Client.BattleFX`, 12 tipos): `beam` (raio), `slash` (corte), `punch` (soco com onda de
choque), `storm` (raios), `flame`, `ice`, `sand`, `light`, `shadow`, `tech` (hologramas), `blossom`
(pétalas) e `meteor`. Cada tipo usa a cor do personagem.

## A encenação (o que deixa a luta emocionante)

| Momento | O que acontece |
|---------|----------------|
| Entrada (3,5 s) | câmera gira pela arena; cada lutador cai do céu no seu lado; cartão com nome, raridade, ★, nível e Poder; "FIGHT!" |
| Golpe | o atacante avança, acerta e volta; número de dano sobe; a barra de vida desce com atraso (efeito de luta) |
| Crítico | "CRITICAL!", tremor curto de câmera, flash |
| Esquiva | "DODGE!", o alvo desliza para o lado com rastro |
| ULT | o tempo desacelera, a tela escurece, entra uma faixa com o nome da ULT e a cor da raridade, câmera fecha no lutador, depois o efeito grande |
| Escudo | bolha em volta do Guardian, com barra própria sobre a vida |
| Nocaute | câmera lenta no último golpe, "K.O.!", o perdedor voa para fora da arena |
| Vitória | a animação de vitória comprada toca no vencedor; confete para quem venceu |

- Barras no topo: vida, escudo e energia da ULT de cada lado. A barra de energia pulsa quando a ULT está pronta.
- **Música:** `Config.Music.Battle` em loop durante a luta e `Config.Music.Victory` no final.
- No celular as barras ficam compactas e os textos grandes ("CRITICAL!") aparecem menores e mais acima
  ([06](06_interface_multiplataforma.md)).

## Arenas (votação)

Três arenas originais no lançamento, construídas por `WorldBuilder.BuildArena(i)` longe da pista:

| Arena | Tema |
|-------|------|
| 🥋 Sky Tournament Ring | ringue de torneio de artes marciais flutuando acima das nuvens |
| 🌸 Sakura Moon Dojo | pétalas, lanternas e lua cheia gigante (combina com o lobby) |
| 🌋 Volcano Coliseum | arena de pedra cercada por cascatas de lava |

Os avatares dos dois jogadores ficam numa plataforma de plateia enquanto a câmera mostra a luta.
A arena não muda o resultado; é cenário.

## Loja de animações de vitória

Balcão no Versus Hall + botão na tela de preparação. Tocam no lutador vencedor (e no carro vencedor da
corrida 1v1).

| Animação | Preço |
|----------|-------|
| 🎉 Confetti Pop | grátis |
| 🎆 Fireworks | $25K |
| 💥 Mega Explosion | $400K |
| ⚡ Thunder Strike | $6M |
| 🌸 Sakura Storm | $80M |
| ☄️ Meteor Crash | $1,2B |
| 🌌 Black Hole | $20B |

## Segurança

- O jogador só manda **qual personagem** quer usar (`PickFighter(uid)`). O servidor confere que o `uid` é
  dele e lê os status do save.
- A semente do sorteio é do servidor. A mesma semente reproduz a mesma luta, o que ajuda a investigar
  reclamações.
- Sair durante a cena dá a vitória ao outro, mesmo que a simulação apontasse o contrário.
- Para batalhar é preciso ter ao menos um personagem (`CanJoin`).
