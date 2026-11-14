---
title: Convenções de código
date: 2026-11-14
tags: [codigo, regras]
aliases: [AI Protocol, Regras do projeto]
---

# Convenções de código

Resumo do `ServerStorage.ProjectDocs.02_AI_Protocol` (regras 1 a 23) e do `CLAUDE.md`.

1. **Ler antes de escrever**: topo do `01_ChangeLog` e o cabeçalho do módulo. Outro assistente pode ter mudado algo.
2. **Uma fonte de verdade**: números e conteúdo só em `Shared.Config` / `ConfigBeta19`. Sem números mágicos.
3. **Não renomear chaves públicas**: Config, ações do Net, atributos do Player, campos salvos. Só acrescentar.
4. **Rede**: cliente pede, servidor valida e decide. Toda ação nova = `Net.Handle` com validação de tipo e limite.
5. **UI** pelo UIKit. Textos do jogador em inglês (+ tradução no `Locale.pt`); **comentários em português**.
6. **Save**: mudou o formato? `defaults()`, `reconcile()`, `migrate()` e `Version`.
7. **Cabeçalho `--[[ ]]`** em todo script: o que faz, entradas/saídas, dependências, versão que mudou.
8. Revisar código de servidor (exploits, loops infinitos, yields sem timeout).
9. Não apagar trabalho de outro assistente sem registrar o motivo.
10. Mapa só pelo WorldBuilder.
11. **Nunca** `require` de `Services.*` pelo Command Bar/MCP durante o Play.
12. Conferir se o `Enum.Material` existe.
13. **Propriedade intelectual**: só originais (exceção: bioma 1).
14. Backup antes de versão grande; sistemas antigos atrás de `Config.Features`.
15. Clonar o Config antes de gerar mapa (cache de require).
16. Funções locais mais abaixo não existem para as de cima.
17. Conferir duplicatas na raiz do Workspace.
18. Dois Claude Code no mesmo place: ler o topo do ChangeLog.
19. Texto de jogador: inglês + `Locale.pt`; nunca montar frase com `..`.
20. UI nova usa `Client.Platform`; no celular troca o layout.
21. Números da 1.9 em `ConfigBeta19`; mexeu na batalha → rodar os testes.
22. **Conferir a sintaxe de todos os scripts antes de cada Play** (`loadstring(script.Source)` em modo Edit).
23. Espelho sem Python: `Tools.MirrorDump` + `mirror_from_dump.js`.

## Estilo
- Serviços: `Init()` registra `Net.Handle` e eventos. Cliente: `Init()` constrói UI e conexões.
- Rascunhos fora do Studio evitam sintaxe exclusiva do Luau (tipos, `continue`, `if` expressão) para rodar nos testes Lua 5.4.
- `execute_luau` idempotente (a conexão cai no meio).

Relacionado: [Arquitetura](Arquitetura.md) · [Checklist antes de mexer](../09_Erros_e_Licoes/Checklist_Antes_de_Mexer.md) · [Programar](../10_Estrategias/Programar.md)
