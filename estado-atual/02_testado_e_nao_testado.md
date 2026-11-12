# Beta 1.8d — o que foi testado e o que não foi

Todos os testes foram feitos no **Play do Roblox Studio**, com **1 jogador** (LuGabriel64), o carro
inicial (`TopSpeed` 70, portanto limite de 70 × 1,6 = 112 studs/s) e **sem acesso à API de DataStore**: o
Studio usou dados temporários, que não salvam.

## ✅ Testado

| # | Teste | Como | Resultado |
|---|-------|------|-----------|
| 1 | Os 5 scripts alterados compilam | `loadstring` do `Source` no Edit | OK |
| 2 | O jogo inicia sem erro | Play + Output | Só as mensagens normais, inclusive "[Client] … Beta 1.8d: interface iniciada." |
| 3 | Mapa sem duplicata | contagem de tags filtrando `IsDescendantOf(workspace)` no servidor | Hazard 51, BoostPad 46, LobbyLantern 60, RacePortal 1, BiomeEgg 7 |
| 4 | Corrida em velocidade permitida | carro movido a 100 studs/s por ~3.100 studs | Corrida continuou; distância 3.089 |
| 5 | Corrida com teleporte | carro saltou 2.000 studs para frente | `RaceEnded` com `Reason = "invalid"`; distância parada em 413 (o salto não contou); `warn` no Output |
| 6 | Fuga com teleporte | pegou o ovo do bioma 1 e teleportou o carro até a base durante a roleta | `EscapeResult` com `Reason = "invalid"` (3.158 studs em 0,11 s); ovo perdido |
| 7 | Fuga legítima | pegou o ovo e voltou a 100 studs/s | `EscapeResult` com `Success = true` e `Reason = "delivered"`, 29,7 s depois do colapso começar |
| 8 | Ser pego pelo colapso | ficou parado depois da roleta (sem querer, nos testes 6 e 7) | `caught` 1,0 s depois do colapso começar: a regra antiga continua funcionando |
| 9 | Docs internos | `require` do `01_ChangeLog` e `loadstring` do `04_EstadoAtual` | Compilam; o topo é a 1.8d |
| 10 | Espelho do GitHub | checksum dos `Source` no place × arquivos em `src/` | Idênticos (5 scripts + 5 docs) |

**Atenção:** nos testes 4 a 7 o carro foi movido por **script** (`PivotTo` no cliente, que é dono da física do
carro), e não dirigindo com o teclado. Isso simula bem o que o servidor vê, mas **não** é uma partida real.

## ❌ Não testado

| # | O quê | Por quê | Como testar |
|---|-------|---------|-------------|
| 1 | Save cancelado pela trava de outro servidor (correção 5) | Precisa de dois servidores publicados e da API de DataStore | Num servidor publicado, entrar, sair e entrar logo em outro servidor; ver no Output (F9 > Server) se aparece "save … cancelado". Na prática é raro |
| 2 | Compra real com Robux (pacotes x3 / x10 da roleta) | Os ProductIds ainda são 0 (pendência do dono) | Depois de criar os Developer Products, comprar no jogo publicado |
| 3 | Carro de tier alto pegando vários boosts seguidos, dirigindo de verdade | Só havia o carro inicial | Comprar um carro melhor, dirigir com boosts em sequência e fazer uma fuga. Se aparecer "avanço impossível" no Output sem trapaça, aumentar `Config.AntiCheat.Slack` ou `BurstSeconds` |
| 4 | Lag real de rede (celular, Wi-Fi ruim) | O Studio roda tudo na mesma máquina | Jogar no celular e fazer fugas; a folga de 2,5 s deve cobrir |
| 5 | Roleta da sorte, menu, lojas e garagem | Não foram mexidos; só a roleta do ovo rodou | Jogar normalmente depois de publicar |
| 6 | Mais de um jogador | Teste com 1 só | Test > Start com 2 Players, ou servidor publicado |
| 7 | Testes automáticos da Beta 1.9 (`run_tests.py`) | O PC do dono não tem Python | Instalar o Python 3, ou rodar numa sessão da nuvem |
| 8 | Visual sem z-fighting (placas e neon das garagens que piscavam) | Não foi tirado print | Olhar as garagens no jogo |

## Problemas que apareceram nos testes (e não são bugs do jogo)

- **Pegar o ovo por script falhou várias vezes.** `ProximityPrompt:InputHoldBegin()` só dispara o `Triggered`
  quando o prompt já está "mostrado" (evento `PromptShown`). Funcionou de forma estável esperando ~1,5 s perto
  do ovo antes de segurar. Ver `06_licoes_tecnicas.md`.
- **O botão PLAY não respondeu ao clique simulado** com o menu de início aberto. Os testes iniciaram a corrida
  chamando `Remotes.Action:InvokeServer("StartRace")` pelo cliente, depois de `ClaimGarage(1)`.
