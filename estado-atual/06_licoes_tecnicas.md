# Lições técnicas (aprendidas em 12/11/2026)

Coisas que custaram tempo nesta sessão e vão se repetir. Complementam a seção "Pegadinhas" do
`ProjectDocs.04_EstadoAtual` e as regras do `02_AI_Protocol`.

## Versões

- **Confira o número da versão dentro do place**, no topo do `01_ChangeLog`, antes de usar o número que está
  no GitHub. A "1.8c" planejada já tinha sido usada no place por uma entrada só de docs.
- `Config.Version` não é atualizado em toda versão: ficou em "Beta 1.8" durante a 1.8b e a 1.8c. Confie no
  ChangeLog.

## Comparar o place com `src/` sem Python

O PC do dono não tem Python, então o `place_tool.py` não roda. Alternativa usada: checksum do `Source`.

- No Studio (`execute_luau`, modo Edit):
  ```lua
  local function sum(s) s = s:gsub("\r","") local h=0 for i=1,#s do h=(h*31+string.byte(s,i))%2147483647 end return h,#s end
  ```
  Percorra os `LuaSourceContainer` de `ServerScriptService`, `ReplicatedStorage`, `ServerStorage` (sem
  `Backups`) e `StarterPlayer`.
- No PowerShell: o mesmo cálculo sobre `[IO.File]::ReadAllBytes`, ignorando o byte 13 (`\r`).
- Se o tamanho e o hash baterem, o arquivo é idêntico. O Git converte LF em CRLF no Windows; por isso o `\r`
  é ignorado dos dois lados.

## MCP do Roblox Studio

- O `studio_id` pode mudar: chame `list_roblox_studios` antes.
- `execute_luau` com uma string `[[ ... ]]` que contém `--[[ ... ]]` dá "Failed to parse". Use `[==[ ... ]==]`.
- Mover a `Map` inteira (43 mil objetos) com `.Parent =` funcionou numa chamada só, sem derrubar a conexão.
- `save_place` salva no Team Create e cria uma versão no histórico. **Não publica.**
- **Tags no servidor:** `CollectionService:GetTagged` também devolve peças dentro de
  `ServerStorage.Backups`. Para contar o que está no jogo, filtre `IsDescendantOf(workspace)`. No cliente, o
  StreamingEnabled faz a contagem dar só o que está perto.

## Testar no Play pelo MCP

- **Nunca** dê `require` em `ServerScriptService.Services.*` durante o Play (regra 11). No **cliente** é seguro
  chamar o remote direto: `game.ReplicatedStorage.Remotes.Action:InvokeServer("StartRace")`.
- Para correr é preciso ter garagem: `InvokeServer("ClaimGarage", 1)` antes do `StartRace`; senão o erro é
  `NoGarage`.
- **Mover o carro:** o cliente é dono da física, então `car:PivotTo(...)` no contexto Client, a cada
  `Heartbeat`, simula direção. O carro é `workspace.Cars["Car_<Nome>"]`.
- **Pegar o ovo:** o `user_keyboard_input` com F não é confiável. `pp:InputHoldBegin()` só dispara o `Triggered`
  se o prompt já estiver "mostrado". O que funcionou: parar a cerca de 20 studs do ovo, esperar 1,5 s, chamar
  `InputHoldBegin()`, esperar `HoldDuration + 0.8` e chamar `InputHoldEnd()`. Repita até 4 vezes, conferindo o
  atributo `EscapeState == "Escaping"`.
- **A roleta dura 6 s e o colapso começa 3 s depois.** Entre chamadas do MCP passam vários segundos: faça
  "pegar o ovo e dirigir de volta" numa **única** chamada, senão o colapso pega o carro parado.
- Os ovos ficam em `Map.BiomeEggs` (criados em Play). O do bioma 1 (`warrior`) fica em z = -3090.
- O `user_mouse_input` com `instance_path` falhou no botão START do menu inicial. Use os remotes.

## Git neste PC

- Não há `user.name` nem `user.email` configurados. Os commits usam
  `git -c user.name="Claude Code" -c user.email="noreply@anthropic.com"`, igual aos anteriores.
- Antes do push, rode `git fetch`: sessões da nuvem também fazem commit no `main`. Faça rebase e resolva os
  conflitos mantendo os dois lados.
- O Git Bash tem `sed`/`grep`; o PowerShell 5.1 não tem `&&`.
