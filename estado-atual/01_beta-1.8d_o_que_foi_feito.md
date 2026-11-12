# Beta 1.8d — o que foi feito (12/11/2026)

**Autor:** Claude Code do dono, rodando no PowerShell do PC dele, ligado ao Roblox Studio pelo MCP
`Roblox_Studio`. **Pedido do dono:** "Pode começar" a Etapa 0 do plano da Beta 1.9 (correções da auditoria).

## Por que "1.8d" e não "1.8c"

O plano no GitHub chamava esta etapa de "Beta 1.8c". Ao ler o place, o topo do `01_ChangeLog` já tinha uma
entrada **"Beta 1.8c"**, de 11/11, com Author "Claude Code (Lu)". Essa entrada era **só documentação**: criou o
`ProjectDocs.04_EstadoAtual`, as regras 17 e 18 do `02_AI_Protocol` e um aviso no `00_ProjectBible`. Para não
haver duas versões com o mesmo número, a Etapa 0 virou **Beta 1.8d**.

## Leitura antes de mudar

- Comparei o `Source` de todos os scripts do place com `src/` por checksum. Os **51 scripts do jogo eram
  idênticos** ao espelho de 11/11. Só os docs internos (`00`, `01`, `02` e o novo `04`) tinham mudado.
- `Config.Version` ainda dizia "Beta 1.8": ninguém tinha subido a versão na 1.8b nem na 1.8c.
- O Workspace tinha 8 filhos: `Script`, `Cars`, `Map`, `Map`, `Terrain`, `SpawnLocation`, `SpawnLocation` e
  `Camera`.
- As duas `Map` tinham os mesmos filhos e 43.298 descendentes cada.

## Mudanças no place

### 1. Backup — `ServerStorage.Backups["Beta 1.8b"]` (novo)
- Cópia de `ReplicatedStorage.Shared`, de tudo em `ServerScriptService` e `StarterPlayerScripts`, e de
  `ServerStorage.ProjectDocs`, `Tools` e `LegacyCode`. Os scripts `Main` e `ClientMain` estão desativados na
  cópia.
- Tem um `LEIA-ME (como restaurar)` explicando como voltar cada coisa.
- Também guarda os itens tirados na limpeza (abaixo).

### 2. Mapa duplicado (auditoria itens 1 e 2)
- A **segunda** `Workspace.Map` foi **movida**, não apagada, para `Backups["Beta 1.8b"].Map`. Era idêntica à
  que ficou, então serve de backup do mapa.
- A segunda `SpawnLocation` foi para `Backups["Beta 1.8b"].Workspace`.
- Antes, `workspace.Map` pegava uma das duas cópias sem ordem garantida. As tags contavam em dobro, e as
  superfícies sobrepostas piscavam (z-fighting).
- Depois: o Workspace tem 5 filhos (`Cars`, `Map`, `Terrain`, `SpawnLocation`, `Camera`). As tags no Workspace
  ficaram em Hazard 51, BoostPad 46, LobbyLantern 60, RacePortal 1 e BiomeEgg 7 (em jogo).

### 3. Anti-trapaça da fuga — `ServerScriptService.Services.EscapeService` (auditoria item 3)
- **Antes:** a fuga era anulada só se o carro avançasse mais de `SpeedCap (700) × 1,6 × dt + 60` studs por
  tick. Isso dava cerca de 1.700 studs/s, enquanto o carro inicial anda 70.
- A correção sugerida na auditoria (TopSpeed × 1,6 × dt + 60) **ainda deixaria passar ~600 studs/s**, porque
  os +60 studs se repetem a cada tick de 0,1 s.
- **Agora:** uma função `forwardOk()` usa um **orçamento** de avanço (token bucket):
  - o orçamento enche `TopSpeed × 1,6` studs por segundo, até um teto de `TopSpeed × 1,6 × 2,5 + 120`;
  - cada tick gasta o avanço medido; se o orçamento ficar negativo, a fuga é anulada (`"invalid"`) e sai um
    `warn` no Output;
  - os 2,5 s de folga cobrem posições que chegam em rajada depois de lag;
  - os 120 studs cobrem o empurrão do boost (35) e o da batida em obstáculo (42);
  - a velocidade sustentada máxima aceita é `TopSpeed × 1,6`, a mesma que o boost pad dá no
    `Client.DriveController`.

### 4. Recorde de distância — `ServerScriptService.Services.RaceService` (auditoria item 4)
- Mesmo orçamento no laço de distância (a cada 0,25 s).
- Com velocidade impossível, a corrida termina com `Reason = "invalid"`. O `MinZ` não anda, então o salto não
  conta para a distância nem para o recorde.
- Isso era pré-requisito para um ranking de distância.

### 5. Save de compra com Robux — `ServerScriptService.Services.DataService` (auditoria item 5)
- **Antes:** se outro servidor tivesse a trava da sessão, o `UpdateAsync` cancelava a gravação, mas `save()`
  devolvia `true`. Então o `WheelService.processReceipt` confirmava `PurchaseGranted` sem ter salvo.
- **Agora:** existe uma variável `wrote`, que só vira `true` quando o transform devolve os dados. `save()`
  devolve `ok and wrote` e avisa no Output quando a gravação é cancelada.
- O **formato do save não mudou** (`Version` continua 2).

### 6. Texto no cliente — `StarterPlayer.StarterPlayerScripts.Client.RaceUI`
- Novo texto para o motivo `invalid`: "⚠️ Impossible speed — race cancelled".

### 7. `ReplicatedStorage.Shared.Config`
- `Config.Version = "Beta 1.8d"`.
- `Config.Updates`: entrada nova, em inglês, que o jogador lê no menu UPDATES.
- `Config.AntiCheat`, tabela nova: `ForwardSpeedMult = 1.6`, `BurstSeconds = 2.5`, `Slack = 120`,
  `FallbackTopSpeed = 70`.
- `Config.Escape.MaxForwardSpeed` ficou **sem uso**, mas **não foi apagado** (regra: não remover chaves públicas).

### 8. Limpeza (auditoria item 7)
Todos os itens foram movidos para o backup 1.8b; nada foi apagado.
- `Lighting.Sky`: era o céu genérico. Fica o "Simple Sunset Sky", que é o que o `AtmosphereController` cita.
- `StarterGui.ScreenGui`: estava vazio, porque a UI é toda criada por código.
- `Workspace.Script` e o filho dele: um "Hello world" desativado desde a Beta 1.2.
- **Não** foram mexidos: o `ServerStorage.Tools.LobbyBuilder` e os backups antigos (1.1, 1.6 e 1.7).

### 9. Documentação dentro do place
- `ServerStorage.ProjectDocs.01_ChangeLog`: entrada "Beta 1.8d" no topo, com o que foi testado e o que não foi.
- `ServerStorage.ProjectDocs.04_EstadoAtual`: versão, backups, Workspace limpo, anti-trapaça e a pendência de
  publicar.

### 10. Salvamento
- O place foi salvo com `save_place`: status "Saved", versão **95**, local TeamCreate.
- **Não foi publicado.** Publicar é decisão do dono.

## Mudanças no GitHub (mesmo dia)

- `src/`: as mesmas edições, aplicadas à mão (sem Python não dá para rodar o `place_tool.py`). Os 5 scripts e
  os 5 docs alterados conferem byte a byte com o place.
- `src/ServerStorage/ProjectDocs/04_EstadoAtual.luau`: novo no espelho.
- Documentos atualizados: `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `docs/ESTRUTURA.md`,
  `docs/AUDITORIA_2026-11-11.md` (status no topo), `planejamento/beta-1.9/07_plano_de_implementacao.md`,
  `PROMPTS_PARA_O_STUDIO.md` (Pedido 1 marcado como feito) e `docs/CONECTAR_STUDIO.md`.
- Commit `17e3993`, branch `claude/beta-1.8d`, juntado ao `main`, tag `beta-1.8d`.
- Durante o push, o `main` remoto tinha um commit novo, de uma sessão na nuvem (`8adcbaf`, com os pedidos
  prontos e o guia de colaboração). Fiz rebase por cima dele e resolvi os conflitos no `CHANGELOG.md` e no
  `CLAUDE.md`, mantendo os dois lados.
- A tag `beta-1.8d` foi movida (push forçado) do commit pré-rebase para o final. Ninguém dependia dela.
