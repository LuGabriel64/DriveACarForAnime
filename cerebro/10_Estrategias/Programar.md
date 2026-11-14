---
title: Estratégia — programar
date: 2026-11-14
tags: [estrategia, codigo]
---

# Programar

1. **Ler o estado real**: topo do ChangeLog no place, cabeçalho do módulo, `git pull`. Nunca confiar só na memória.
2. **Projetar antes**: para versão grande, um documento por sistema e um plano em etapas com testes de cada
   etapa (padrão de `planejamento/beta-1.9/`). Rascunho fora do Studio vai para `planejamento/`, nunca para `src/`.
3. **Lógica pura separada do Roblox**: módulos como `AnimeStats` e `BattleSim` não dependem de serviços, então
   rodam em testes Lua 5.4 contra o Config real. Sem sintaxe exclusiva do Luau nos rascunhos.
4. **Servidor decide, cliente encena.** Para algo "ao vivo" entre jogadores, prefira roteiro/atributos replicados
   com relógio do servidor (`GetServerTimeNow`) a física compartilhada.
5. **Encaixar no que existe** em vez de reescrever: `RegisterMode`, `opts` em funções existentes
   (`RaceService.Start(player, opts)`), atributos novos, nenhum nome público trocado.
6. **Mudanças pequenas e localizadas**, uma etapa por vez, com teste ao fim de cada uma.
7. **Edição pelo MCP**: `multi_edit` para criar/editar scripts; `execute_luau` idempotente (a conexão cai).
8. **Checar a sintaxe de todos os scripts** antes de cada Play.
9. **Validar todo `Net.Handle`**: tipo, limites, etapa certa, posse do item.
10. **Números no Config**, textos traduzíveis, UI pelo UIKit + Platform, cabeçalho em todo script.

Relacionado: [Convenções](../06_Codigo/Convencoes.md) · [Testar](Testar.md) · [Brainstorm e design](Brainstorm.md) · [Arquitetura](../06_Codigo/Arquitetura.md)
