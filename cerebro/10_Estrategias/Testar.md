---
title: Estratégia — testar
date: 2026-11-14
tags: [estrategia, testes]
---

# Testar

## Camadas
1. **Lógica pura** fora do Roblox: `planejamento/beta-1.9/testes/run_tests.py` (80 verificações; precisa de
   Python + Lua 5.4, não roda no PC do dono). Calibragem da batalha por milhares de lutas simuladas.
2. **Compilação**: `loadstring(script.Source)` de todos os scripts em modo Edit.
3. **Play pelo MCP (1 jogador)**: Output, atributos, remotes chamados do cliente, capturas de tela,
   cliques por coordenada.
4. **Play com 2 jogadores**: só o dono (Test → Clients and Servers → 2 Players).
5. **Aparelhos**: Test → Device (emulador) ou aparelho real.
6. **Servidor publicado**: DataStore real, Robux real, migração de save real.

## Truques
- Simular direção com `PivotTo` no cliente a cada Heartbeat.
- Testar um modo só no cliente marcando os atributos localmente (ex.: placar do Duel).
- Testar a cena da batalha enviando um roteiro real do BattleSim pelo `Remotes.Event`.
- Fazer ações encadeadas com tempo (ovo → fuga) **numa única chamada**.
- Testar casos ruins também: sem dinheiro, item inválido, teleporte, velocidade impossível.

## Regra de ouro
**Sempre dizer o que foi testado e o que não foi**, com o motivo e como testar. A lista viva está em
[Não testado](../13_Pendencias/Nao_Testado.md).

Relacionado: [Pegadinhas técnicas](../09_Erros_e_Licoes/Pegadinhas_Tecnicas.md) · [Programar](Programar.md) · [Checklist antes de mexer](../09_Erros_e_Licoes/Checklist_Antes_de_Mexer.md)
