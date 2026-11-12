# 04 — Estrelas, nível, recompensas e pontos de spin

Números em `Config.Stars`, `Config.Levels`, `Config.Versus.Rewards` e `Config.Wheel.Points`.
Contas em `Shared.AnimeStats` (testadas).

## Estrelas (0 a 5)

- Um mesmo personagem pode vir com 0, 1, 2, 3, 4 ou 5 estrelas. As estrelas são sorteadas **no servidor**,
  junto com o personagem (`EggRoll.Roll`), e aparecem na roleta do ovo, no cartão da mochila e na placa do pedestal.
- Cada estrela vale um valor **fixo**: +7,5% sobre o valor base. Vale para a renda e para todos os status de batalha.

| Estrelas | Multiplicador | Exemplo do dono (Secret de $400/s) | Chance |
|----------|---------------|------------------------------------|--------|
| 0★ | ×1,000 | $400/s | 40% |
| 1★ | ×1,075 | $430/s | 28% |
| 2★ | ×1,150 | $460/s | 17% |
| 3★ | ×1,225 | $490/s | 9% |
| 4★ | ×1,300 | $520/s | 4,5% |
| 5★ | ×1,375 | $550/s | 1,5% |

A tabela bate com o exemplo que você deu (400 → 430 → … → 550) e é verificada nos testes.

- Personagens que já existem ficam com **0★**, e a renda deles não muda.
- O "1 in N" mostrado na roleta do ovo continua sendo a chance do personagem, da mutação e do tamanho.
  As estrelas aparecem ao lado, sem inflar esse número.

## Nível (1 a 50) e XP

- Todo personagem começa no nível 1 e sobe até o 50.
- XP para subir do nível L para L+1: `30 + 12 × L`. Total até o 50: **16.170 XP**.
  Os primeiros níveis saem em uma ou duas partidas; os últimos pedem cerca de 6 vitórias cada.
- Cada nível acima do 1 dá **+2% em todos os status de batalha** (nível 50 = ×1,98) e **+1% de renda**
  (nível 50 = ×1,49). O bônus de renda pode ser desligado com `Config.Levels.IncomePerLevel = 0`.
- Subir de nível mostra um aviso ("⬆️ Gokun reached level 7!") e atualiza a placa do pedestal.

Quem ganha o XP:

| Modo | Personagem que recebe |
|------|-----------------------|
| Batalha | o lutador usado |
| Corrida 1v1 | o **parceiro**: personagem marcado com `SET PARTNER` na mochila. Sem escolha, é o de maior Poder |

Com as recompensas abaixo, levar um personagem ao nível 50 pede 162 partidas só vencendo, ou 405 só perdendo.

## Recompensas da partida (corrida e batalha)

| | Vencedor | Perdedor |
|---|----------|----------|
| XP no personagem | **+100** | **+40** |
| Dinheiro | **2 minutos da renda dele**, mínimo $500 | — |
| Pontos de spin | **+10** | — |

- O perdedor ganha apenas XP, como você pediu.
- O dinheiro acompanha o progresso do jogador: quem rende $100/s ganha $12K; quem rende $1M/s ganha $120M.
- **Proteção contra farm:** contra o mesmo adversário, as 10 primeiras partidas da sessão pagam tudo.
  Depois disso só o XP é dado, e a tela de resultado avisa. Sem isso, dois jogadores combinados (ou uma
  conta secundária) trocariam vitórias sem parar para gerar dinheiro e giros.
- Quem sai da partida no meio não recebe nada; o outro recebe como vencedor.
- Tudo é calculado no servidor (`VersusService.reward`) e o perfil é salvo logo depois.

## Pontos de spin

Hoje a roleta dá 1 giro grátis a cada 8 horas, giros extras pela própria roleta ("+2 Spins") e, no futuro,
por pacotes de Robux. A Beta 1.9 acrescenta os **pontos de spin**:

| Fonte | Pontos |
|-------|--------|
| Cada minuto jogado | +2 |
| Vitória em corrida 1v1 ou batalha | +10 |

- **100 pontos = 1 giro extra**, somado em `data.Wheel.Tokens` (o mesmo contador dos outros giros extras).
  O que sobra fica guardado: com 97 pontos, ganhar 10 dá 1 giro e deixa 7.
- Só jogando, isso dá um giro a cada 50 minutos.
- Na janela da roleta aparece a barra **"🎟️ Spin points: 37/100"** logo abaixo do contador do giro grátis.
  Ao completar 100, a barra enche, pisca e avisa "You earned a free spin!".
- Fora da roleta, um aviso pequeno "+10 spin points" aparece na tela de resultado da partida.

### Onde entra no código (`Services.WheelService`)

```lua
-- data.Wheel.Points (0..PerSpin-1) + atributo "WheelPoints"
function WheelService.AddPoints(player, amount)
	local data = DataService.Get(player)
	if not data or type(amount) ~= "number" or amount <= 0 then return end
	local w = wheelData(data)                    -- wheelData passa a garantir w.Points = w.Points or 0
	local P = WC.Points
	w.Points += math.floor(amount)
	local spins = w.Points // P.PerSpin
	if spins > 0 then
		w.Points -= spins * P.PerSpin
		w.Tokens += spins
		Net.Fire(player, "Toast", Locale.For(player, "🎟️ You earned a free spin!"), "good")
	end
	push(player, data)                           -- push também publica o atributo WheelPoints
end

-- no Init: +PerMinute a cada minuto, pelo relógio do SERVIDOR
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			WheelService.AddPoints(player, WC.Points.PerMinute)
		end
	end
end)
```

- O cliente não manda nada: o tempo é contado no servidor e os pontos de vitória vêm do `VersusService`.
- O Roblox desconecta quem fica parado por 20 minutos, o que limita o ganho de quem deixa o jogo aberto.
- Os pontos são salvos com o resto do perfil (autosave a cada 60 s e ao sair).
