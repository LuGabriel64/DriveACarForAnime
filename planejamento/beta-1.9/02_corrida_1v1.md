# 02 — Corrida 1v1

Números em `Config.Versus.Race` e `Config.F1Cars` (rascunho `Shared/ConfigBeta19.luau`).

## O mapa: mesma pista, outro modo

O pedido foi "recriar o mapa sem ovos, sem o sistema de ovos e sem o bloqueio de biomas". Proponho chegar a
esse resultado **sem copiar o mapa**: a corrida 1v1 usa a pista do jogo com o atributo `RaceMode = "Duel"`,
e é o modo que desliga o que não deve existir.

| O que o dono pediu | Como fica no modo Duel |
|--------------------|------------------------|
| Sem ovos | `Client.BiomeEggs` esconde o ovo gigante, a placa e o prompt para quem está em Duel. Ovos de estrada e santuários já estão desligados desde a Beta 1.3 |
| Sem o sistema de ovos | `EscapeService.tryGrab` recusa em Duel. Não há roleta, incubadora nem fuga |
| Sem bloqueio de biomas | `ZoneService` não aplica o bloqueio de tier em Duel, e não grava "melhor bioma" (a progressão normal não é pulada) |
| Estruturas novas do mapa real entram na corrida | Entram sozinhas, porque é a mesma pista: obstáculos animados, pads, passarelas e pontes |

**Por que não copiar:** o mapa tem 43 mil peças. Uma segunda cópia dobraria o peso do jogo (o problema do
item 1 da auditoria, só que de propósito) e teria de ser regenerada a cada mudança da pista. É a mesma
decisão da "pista fantasma" da Beta 1.2, pelos mesmos motivos.

Quem está em corrida solo e quem está em 1v1 usam a pista ao mesmo tempo sem se ver nem colidir.

## Carros de Fórmula 1

- Só existem na corrida 1v1. Não abrem biomas, não têm tier e não usam o upgrade de motor.
- O primeiro é grátis para todos. Os outros são comprados com Cash na **loja de F1** do Versus Hall
  (balcão no mapa + botão na tela de preparação).

| Carro | Preço | Vel. máx (studs/s) |
|-------|-------|--------------------|
| Rookie F-01 | grátis | 230 |
| Viper F-02 | $150K | 270 |
| Storm F-03 | $5M | 310 |
| Phantom F-04 | $150M | 350 |
| Apex F-05 | $5B | 400 |

- Com boost (×1,6) o mais rápido chega a 640, abaixo do teto de 700 do jogo (verificado nos testes).
- **Modelo:** `CarFactory.Build` ganha o corpo `"f1"`: baixo e largo, rodas expostas, bico, asa dianteira e
  traseira, halo e entradas laterais. Mantém `Chassis`, `Seat` e as soldas `Wheel_FL/FR/RL/RR`, então a
  física (`DriveController`) funciona sem alteração. As rodas ficam mais abertas, o que pede conferir
  `CarFactory.WheelPoints` em Play.
- Depois da partida, o `CarService` recria o carro normal do jogador na garagem.

## Fluxo da corrida

1. **Preparação (30 s):** cada um escolhe o F1 entre os que tem. Pode comprar na hora.
2. **Grid:** `RaceService.Start(player, { Mode = "Duel", ... })` leva os dois à primeira fileira, lado a lado
   (`GridColsX = { -10, 10 }`), cada um no seu F1. Contagem 3-2-1-GO com os carros ancorados (já existe).
3. **Corrida:** até o fim do mapa (`FinishZ = nil` = fim do mundo, ~32.400 studs).
   Com o Rookie leva cerca de 2 a 3 minutos; com o Apex, pouco mais de 1 minuto e meio.
4. **Fim:** ver "Quem vence".

Os dois se **veem** (regra nova do `GhostController`: mesmo `MatchId`) mas **não colidem**.

## O colapso desde a largada

É o mesmo efeito da fuga do ovo, virado ao contrário e mais lento.

- Nasce `CollapseStartGap` (120) studs **atrás** do grid e anda na direção da corrida (−Z).
- Começa `CollapseDelay` (4 s) depois do GO.
- Velocidade = `MaxSpeed` do carro **mais lento** da partida × `CollapseFactor` (0,55), com mínimo de 60.
  Na fuga do ovo o fator é 0,82, então aqui a pressão é bem menor: só alcança quem bate muito ou para.
  Exemplo: Rookie contra Rookie = 126 studs/s atrás de carros que andam a 230.
- Posição da frente, igual no servidor e no cliente:
  `frenteZ(t) = CollapseZ0 − CollapseSpeed × (t − CollapseStart)`, com `t = workspace:GetServerTimeNow()`.
- O servidor publica `CollapseDir = -1`, `CollapseZ0`, `CollapseStart` e `CollapseSpeed` nos dois jogadores.
  O `CollapseFX` (o `EscapeFX` generalizado) desenha fendas, destroços e a parede de destruição.
- **Regra no servidor** (a cada 0,1 s): carro com `Z >= frenteZ` foi **pego** e está eliminado.

Como na fuga do ovo, a pista não é destruída de verdade: o efeito é visual por jogador, e quem decide é o
servidor. Assim a corrida 1v1 não atrapalha quem está na corrida solo.

## Quem vence

| Situação | Resultado |
|----------|-----------|
| Um cruza a chegada primeiro | vence ("Finished first") |
| Um é pego pelo colapso | o outro vence na hora ("Caught by the collapse") |
| Os dois são pegos | vence quem foi mais longe |
| Passou de `MaxSeconds` (420 s) | vence quem foi mais longe ("Went the farthest") |
| Um sai do jogo ou aperta LEAVE | o outro vence; quem saiu não recebe nada |
| Empate exato de distância | sem vencedor, sem recompensa |

## Anti-trapaça

O carro é simulado pelo cliente (dono de rede), então o servidor não confia na posição sem conferir:

- Avanço por verificação acima de `TopSpeed × MaxForwardFactor (1,6) × dt + 60` studs = **desclassificado**.
  O 1,6 é exatamente o multiplicador do boost; o +60 cobre o empurrão inicial.
- É a mesma correção dos itens 3 e 4 da auditoria, aplicada também à fuga do ovo e ao recorde de distância.
- A distância mostrada e usada no resultado é a do servidor (`RaceDistance`).

## Placar ao vivo (overlay no topo)

Mostra quem está em primeiro e quantos metros cada um andou desde a largada. O número **só aumenta**
(usa a maior distância já alcançada, como o `RaceDistance` atual). 1 stud = 1 m na tela, como o velocímetro.

```
Computador / tablet / TV                       Celular (uma linha, no topo, fora do centro)
┌───────────────────────────────────┐          ┌──────────────────────────┐
│ 🥇 1st  Você        12.480 m      │          │ 🥇 12.480 m  ·  +310 m   │
│ 🥈 2nd  Gabxx10     12.170 m      │          └──────────────────────────┘
│ +310 m à frente   🔥 Colapso 840 m│
└───────────────────────────────────┘
```

- Atualiza a 4 Hz lendo os atributos `RaceDistance` dos dois jogadores (sem tráfego de rede extra).
- A troca de posição dá um "pop" e inverte as linhas com animação.
- O aviso do colapso fica vermelho e pisca abaixo de 200 m.
- No celular ocupa no máximo 12% da altura e nunca cobre o centro nem os controles de toque
  (regras em [06](06_interface_multiplataforma.md)).

## Música e fim

- `MusicController` toca `Config.Music.Race` em loop com fade de entrada e saída. Respeita o interruptor
  **Music** do menu Configs. Sem ID configurado, fica em silêncio.
- No fim, o vencedor ganha a animação de vitória equipada no carro, e os dois veem a tela de resultado
  com as recompensas ([04](04_progressao_e_recompensas.md)).

## Mapas futuros

A votação já nasce pronta para mais de um mapa: cada entrada de `Config.Versus.Race.Maps` tem `Id`, `Name`,
`Icon`, `Desc` e `FinishZ`. Um "Sprint" só do bioma 1, por exemplo, é uma linha nova com
`FinishZ = Config.Biomes[1].ZEnd`. Com um mapa só, a tela de votação aparece e confirma sozinha.
