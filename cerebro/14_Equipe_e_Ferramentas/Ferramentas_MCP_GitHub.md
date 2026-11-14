---
title: Ferramentas (MCP, GitHub, espelho)
date: 2026-11-14
tags: [ferramentas, mcp, github]
---

# Ferramentas (MCP, GitHub, espelho)

## Roblox Studio via MCP
- Servidor MCP `Roblox_Studio` (configurado com `cmd.exe /c cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat`).
- Place "Drive A Car For Anime", placeId 83805628245898, Team Create.
- Ferramentas usadas: `list_roblox_studios`, `execute_luau` (Edit/Client/Server), `multi_edit`, `script_read`,
  `script_grep`, `save_place`, `start_stop_play`, `screen_capture`, `user_mouse_input`, `get_console_output`.
- Guia de conexão: `docs/CONECTAR_STUDIO.md` no repositório.

## GitHub
- Repositório `LuGabriel64/DriveACarForAnime`, branch `main`, tags `beta-1.8d`, `beta-1.9`.
- Pastas: `src/` (espelho), `estado-atual/`, `planejamento/`, `docs/`, `places/`, `tools/`, `cerebro/` (cópia deste vault).

## Espelho Studio → GitHub (sem Python)
1. No Studio: `require(game.ServerStorage.Tools.MirrorDump)` gera partes de até 90.000 bytes
   (`@@@PARTS k/n`, registros `@@@FILE <caminho> <Classe> <bytes>`).
2. O Claude Code grava as saídas em arquivo e roda `node tools/place/mirror_from_dump.js <partes...>`.
3. Com Python: `python tools/place/place_tool.py extract places/<arquivo>.rbxl`.

## Vault → GitHub
`node tools/vault/vault_tools.js sync` copia este vault para `cerebro/` no repositório (sem `.obsidian/workspace*.json`).
O vault mestre é o do D:; não edite `cerebro/` à mão.

## Ambiente do PC do dono
Windows 11, PowerShell 5.1 e Git Bash, Node em `D:\node`, **sem Python**, Git sem identidade configurada.

Relacionado: [Arquitetura](../06_Codigo/Arquitetura.md) · [Pegadinhas técnicas](../09_Erros_e_Licoes/Pegadinhas_Tecnicas.md) · [Plugins recomendados](Plugins_Recomendados.md) · [Manter o vault](../10_Estrategias/Manter_o_Vault.md)
