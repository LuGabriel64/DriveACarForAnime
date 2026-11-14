---
title: Pegadinhas técnicas
date: 2026-11-14
updated: 2026-11-14
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
- `user_mouse_input` com `instance_path` funciona no dock, falhou no START do menu (use coordenadas: JOGAR ~765,197; ESCOLHER ~765,433).

## Git e Windows
- Sem `user.name`/`user.email` neste PC: `git -c user.name="Claude Code" -c user.email="noreply@anthropic.com"`.
- `git fetch` antes do push; rebase mantendo os dois lados.
- PowerShell 5.1 não tem `&&`. O Git Bash tem `sed`/`grep`.
- **Sem Python** no PC do dono; há Node (`D:\node`). Heredoc longo no Bash falhou ao escrever as notas do vault → use a ferramenta de escrita.
- Git converte LF em CRLF: ignore `\r` ao comparar checksums.

Relacionado: [Erros corrigidos](Erros_Corrigidos.md) · [Checklist antes de mexer](Checklist_Antes_de_Mexer.md) · [Testar](../10_Estrategias/Testar.md) · [Ferramentas](../14_Equipe_e_Ferramentas/Ferramentas_MCP_GitHub.md)
