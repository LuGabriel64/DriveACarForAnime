# Auditoria — Beta 1.8b (place de 11/11/2026)

Feita por Claude Code (sessão na nuvem, sem acesso ao Studio) lendo o `.rbxl` completo:
207.026 instâncias, 55 scripts ativos (+ 144 em `ServerStorage.Backups`), o mapa inteiro e a
documentação interna (`ServerStorage.ProjectDocs`). **Nenhuma correção foi aplicada no jogo**: o
Studio é a fonte da verdade e esta sessão não alcança o Studio. Cada item diz como corrigir.

Severidade: 🔴 corrigir já · 🟠 corrigir antes de publicar · 🟡 melhoria

> **Status em 12/11/2026 (Beta 1.8d):** os itens 1, 2, 3, 4 e 5 e a limpeza do item 7 (Sky, ScreenGui e
> Workspace.Script) foram **corrigidos** no Studio. Ver `CHANGELOG.md`. Nos itens 3 e 4, a correção foi um
> orçamento de velocidade (`Config.AntiCheat`) em vez da troca de 1 linha sugerida abaixo, porque a folga de
> +60 studs por tick ainda permitia ~600 studs/s. Ainda abertos: item 6 (pendências do dono), `LobbyBuilder` e o
> tamanho de `ServerStorage.Backups`.

---

## 🔴 1. `Workspace.Map` está DUPLICADO (43.298 objetos a mais)

- O Workspace tem **duas** pastas `Map`, idênticas peça por peça (mesma classe, nome e posição
  em todos os 43.298 descendentes). A ordem das garagens na 2ª cópia é embaralhada
  (`Plot_5, Plot_4, Plot_8…`), típico de copiar/colar ou Ctrl+D.
- **Não existia na Beta 1.7** (o backup `Beta 1.7` tem só um Map). Entrou depois da 1.8b.
- **Efeitos no jogo:**
  - 86 mil peças no Workspace em vez de 43 mil: o dobro de memória e de streaming, e lag no celular.
  - Superfícies sobrepostas tremem (z-fighting): letreiros, SurfaceGuis e neon das garagens.
  - Toda tag do CollectionService conta em dobro: `Hazard` 102 (o ChangeLog diz 51), `BoostPad` 92 (eram 46),
    `LobbyLantern` 120 (eram 60), `RacePortal` 2.
    - O `HazardController` anima 102 obstáculos e o `LobbyShowcase` 120 lanternas.
    - Os dois portais de corrida disparam juntos.
  - 29 lugares do código usam `workspace.Map` / `FindFirstChild("Map")`. Cada um pega uma das duas cópias,
    sem ordem garantida. O `EscapeService` cria `BiomeEggs` numa cópia e o `FarmService` pode ler as
    garagens da outra.
- **Como corrigir (1 minuto no Studio):** no Explorer, clique na **segunda** `Map` e aperte Delete.
  Faça o mesmo com a **segunda** `SpawnLocation` (item 2). Depois salve/publique.
  - Pode apagar qualquer uma das duas: o conteúdo é igual.
  - Confirme pelo Command Bar: `print(#workspace:GetChildren())` deve cair de 8 para 6.

## 🔴 2. Duas `SpawnLocation` iguais em (0, 3, 3230)

Mesmo caso do item 1: as duas estão ativas e neutras, na mesma posição. Apague uma.

## 🟠 3. Anti-trapaça da fuga é frouxo demais (`EscapeService.step`)

O limite de avanço por tick é `Config.SpeedCap (700) × Escape.MaxForwardSpeed (1.6) × dt + 60`.
Isso dá ~1.700 studs/s, enquanto o carro inicial anda 70 studs/s. Como o **cliente é dono da física do
carro** (`SetNetworkOwner(player)`), um exploiter pode "dirigir" a 1.000+ studs/s de volta à base, e o
servidor aceita: a fuga é o loop principal e vira ovo garantido.

**Correção sugerida** (troca 1 linha em `ServerScriptService.Services.EscapeService`, função `step`):

```lua
-- limite pela velocidade REAL do carro do jogador (+ folga de boost/rampa), não pelo teto global
local top = (player:GetAttribute("TopSpeed") or 70) * E.MaxForwardSpeed
if advance > top * dt + 60 then
```

O boost pad multiplica a velocidade máxima por exatamente 1,6 (`DriveController`, linha 132), o mesmo valor
de `MaxForwardSpeed`. A folga de +60 studs por tick cobre o empurrão inicial do boost.

## 🟠 4. Recorde de distância também confia no cliente (`RaceService`)

`r.MinZ` vem da posição do carro, que é do cliente. Teleportar o carro até o fim dá recorde máximo.
Hoje isso não dá dinheiro (`Race.CashPer100Studs = 0`), mas o roadmap prevê **ranking diário de distância**.
Antes de criar o ranking, aplique ao `MinZ` o mesmo limite de velocidade do item 3.

## 🟠 5. Compra com Robux: o save "ok" não garante que gravou (`DataService.save`)

Se outro servidor tiver a trava da sessão, o `UpdateAsync` devolve `nil` (cancela a gravação). Mesmo
assim o `pcall` retorna `ok = true`, e o `WheelService.processReceipt` confirma `PurchaseGranted` sem o
DataStore ter gravado nada. É raro (troca rápida de servidor), mas envolve Robux.

**Correção:** dentro do `save`, marcar `wrote = true` só quando o transform retornar `old`, e
retornar `ok and wrote`.

## 🟡 6. Pendências do dono (já registradas no ChangeLog, continuam abertas)

- `Config.Wheel.Packs[i].ProductId = 0`: falta criar os 2 Developer Products (x3 / x10 giros) no Creator Hub.
- `Config.Sounds` vazio: o jogo não tem nenhum som.
- `Config.Credits`: conferir os nomes.
- `Config.Gift.GroupId = 0`: o presente grátis não exige grupo.
- A migração de save v1 → v2 (Beta 1.6) nunca foi testada com save real.
  Teste num servidor publicado ou com "Enable Studio Access to API Services".

## 🟡 7. Limpeza

- `Lighting` tem dois `Sky` ("Sky" e "Simple Sunset Sky"). O Roblox usa só um, sem ordem garantida.
  Apague o que não é usado.
- `StarterGui.ScreenGui` está vazio (sobra). A UI é toda criada por código (Bíblia, 10f).
- `Workspace.Script` (+ filho) são "Hello world" desativados desde a Beta 1.2. Podem ser apagados.
- `ServerStorage.Tools.LobbyBuilder` (sessão de 04/11) nunca foi aplicado. Decidam se fica.
- `ServerStorage.Backups` guarda 120 mil instâncias (1.1, 1.6, 1.7) e quase dobra o tamanho do place.
  Agora que existe backup em Git (`places/`), dá para manter só o último backup interno.

## ✅ O que está bom (manter)

- Sorteio só no servidor (`EggRoll`, `Random` próprio). O cliente não envia nenhum número que entre no sorteio.
- `Net` centralizado: rate limit por ação, `pcall` em todo handler e validação de tipo em todas as ações.
- `DataService` com trava de sessão, `reconcile` + `migrate` versionado e kick só quando o load falha de verdade.
- `ProcessReceipt` idempotente (lista de `PurchaseId`).
- Tempos de incubadora e roleta em `os.time()` do servidor, sem confiar no relógio do cliente.
- `Config.Features` liga e desliga os sistemas antigos sem apagar código, e cada script começa com um cabeçalho explicativo.
