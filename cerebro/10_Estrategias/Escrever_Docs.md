---
title: Estratégia — escrever documentação
date: 2026-11-14
tags: [estrategia, docs]
---

# Escrever documentação

- **Escrever para quem chega sem contexto**: o Claude Code do amigo lê só o repositório; outro modelo pode
  assumir no meio. Nada pode depender da conversa.
- **Português** para docs e comentários; **inglês** para textos do jogador.
- **Frases curtas, tabelas para comparar, listas para passos.** Caminho completo no Explorer (`ServerScriptService.Services.X`).
- Toda entrada de versão tem: data, autor/assistente, versão, scripts com caminho, motivo, **testado** e **não testado**.
- **Um lugar por assunto** e links entre eles: ChangeLog (histórico), estado-atual (agora), planejamento
  (futuro), este vault (mapa de ideias e decisões).
- Decisões com "por quê" e "onde mudar" (o dono pode discordar e mudar sozinho).
- Para o dono: dizer primeiro o resultado (o que funciona, o que falta, o que só ele pode fazer).
- No vault: links relativos em markdown (funcionam no Obsidian, no GitHub e no VS Code), frontmatter com
  `title`, `date`, `tags`, e uma linha "Relacionado:" no fim de cada nota.

Relacionado: [Manter o vault](Manter_o_Vault.md) · [Fluxo de versão](Fluxo_de_Versao.md) · [Requisitos permanentes](../08_Pedidos_e_Decisoes/Requisitos_Permanentes.md)
