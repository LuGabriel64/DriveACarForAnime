---
title: Pegadinhas técnicas
date: 2026-11-14
updated: 2026-11-15
tags: [erros, mcp, roblox, git]
---

# Pegadinhas técnicas

## Roblox
- **`require` de `Services.*` no Play** (Command Bar ou MCP) cria um 2º Net → "UnknownAction" em tudo. Reinicie o Play.
- **Cache de `require` no editor**: depois de editar o Config, clone a instância antes de rodar o WorldBuilder.
- **StreamingEnabled**: o Model pode chegar antes das peças; guarde posição em atributo e use `ModelStreamingMode Atomic`.
- `screen_capture` não mostra BillboardGui em Play; CanvasGroup dentro de BillboardGui não renderiza.
- `ProcessReceipt` tem de ser idempotente e salvar **antes** de `PurchaseGranted`.
- `CollectionService:GetTagged` no servidor também pega peças em `ServerStorage.Backups` → filtre `IsDescendantOf(workspace)`.
- Funções locais definidas mais abaixo não existem para as de cima.
- `Enum.Material.CorrugatedMetal` não existe.
- Terreno desenhado 2 studs acima do escrito.

## MCP do Roblox Studio
- O `studio_id` muda: `list_roblox_studios` antes de cada bloco.
- `start_stop_play(true)` responde "timed out" e o Studio some da lista por alguns segundos; o Play começa mesmo assim.
- String `[[ ... ]]` contendo `--[[ ]]` dá "Failed to parse": use `[==[ ... ]==]`.
- `execute_luau` não alcança `127.0.0.1` (lista de HTTP); arquivos do disco só entram via `multi_edit`.
- Saída grande do `execute_luau` vira arquivo no disco → é o caminho Studio → GitHub (MirrorDump).
- Mover 43 mil objetos com `.Parent =` funcionou numa chamada.
- `save_place` salva no Team Create e cria versão; **não publica**. Às vezes falha ("Target is not reachable"): tente de novo.
- **Testar no Play:** no cliente, `Remotes.Action:InvokeServer(...)` é seguro; `ClaimGarage` antes de `StartRace`;
  carro anda por `PivotTo` no cliente a cada Heartbeat; pegar o ovo com `InputHoldBegin/End` depois de o prompt
  aparecer; **pegar o ovo e voltar numa única chamada** (a roleta dura 6 s e o colapso começa 3 s depois).
- Batalha sem 2 jogadores: no contexto Server, `require` do **BattleSim** (biblioteca) e `Remotes.Event:FireClient(p, "BattleScript", roteiro)`.
- **Upload de assets** (`open_cloud_invoke` em `/assets/v1/assets`): liberar os escopos não basta; a **pasta** do arquivo tem de estar na lista de pastas aprovadas (Assistant Settings → MCP Permissions). Erro: "is not inside a directory approved for uploads". Não contornar copiando o arquivo.
- O jogo pertence a um **grupo** (`game.CreatorType = Group`, id 879120012): no upload, `creationContext.creator` é `{groupId}`, não `{userId}`.
- Erro "Server's protocol version is not supported" ao ligar o MCP: resolve reiniciando o app do Claude / recriando o conector; depois os `mcp__Roblox_Studio__*` voltam.
- `user_mouse_input` com `instance_path` funciona no dock, falhou no START do menu (use coordenadas: JOGAR ~765,197; ESCOLHER ~765,433).

## Git e Windows
- Sem `user.name`/`user.email` neste PC: `git -c user.name="Claude Code" -c user.email="noreply@anthropic.com"`.
- `git fetch` antes do push; rebase mantendo os dois lados.
- PowerShell 5.1 não tem `&&`. O Git Bash tem `sed`/`grep`.
- **Sem Python** no PC do dono; há Node (`D:\node`). Heredoc longo no Bash falhou ao escrever as notas do vault → use a ferramenta de escrita.
- Git converte LF em CRLF: ignore `\r` ao comparar checksums.

## Blender
- O Blender aberto **não basta**: o servidor MCP precisa ser iniciado dentro dele (porta 9876). Sem isso, use `blender --background --python script.py` (caminho: `D:\SteamLibrary\steamapps\common\Blender\blender.exe`).
- Blender 5.3: o motor de render chama `BLENDER_EEVEE` (não existe `BLENDER_EEVEE_NEXT`); renderiza sem janela.
- Luz de área muito forte estoura o clay; sol e preenchimento bastam. Chão brilhante cria um reflexo branco: use rugosidade alta.
- Para exportar com nomes limpos (`Body`, `Trim`...), renomeie os objetos só durante a exportação (o Blender não aceita dois objetos com o mesmo nome).
- Script com aspas simples dentro de heredoc do Bash falha neste PC: grave o script com a ferramenta de escrita e rode o arquivo.

Relacionado: [Erros corrigidos](Erros_Corrigidos.md) · [Checklist antes de mexer](Checklist_Antes_de_Mexer.md) · [Testar](../10_Estrategias/Testar.md) · [Ferramentas](../14_Equipe_e_Ferramentas/Ferramentas_MCP_GitHub.md)
- **SDF (personagens):** `np.sin(np.pi * 1.0)` em float32 dá um número negativo minúsculo; elevar a 0,7 vira NaN e a malha sai em espinhos. Sempre `np.maximum(..., 0)` antes da potência.
- **Mechas de cabelo:** se a mecha sai radial do centro da cabeça, "para fora" e "ao longo" são o mesmo vetor e a seção colapsa em agulha. Use um eixo de referência fixo (frente, ou Z para as mechas que apontam para a frente/trás).
- **Aura e efeitos translúcidos:** só atrás e dos lados; na frente tapam o personagem.
- **Sombra cel pintada:** com a luz de frente quase não há sombra; a luz tem de vir de lado e de cima (e uma contraluz para as costas).
- **Mirim a partir do adulto:** escalar a cabeça leva junto o toco do pescoço; abaixe a cabeça e achate um pouco no Z, senão o rosto fica comprido.
