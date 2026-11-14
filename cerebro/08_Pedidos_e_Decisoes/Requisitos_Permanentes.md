---
title: Requisitos permanentes
date: 2026-11-14
updated: 2026-11-14
tags: [requisitos, processo]
---

# Requisitos permanentes (valem em todo pedido)

## Como o dono quer que o trabalho seja feito
- Atuar como **desenvolvedor sênior e parceiro criativo**; ler o estado atual antes de agir; comentar bem e catalogar tudo.
- **Editar o Studio de verdade** (MCP), não só planejar.
- **Toda mudança relevante = nova versão Beta**, com backup em `ServerStorage.Backups`, `.rbxl` em `places/` e tag git.
- Catalogar em dois lugares: topo do `01_ChangeLog` no place e `CHANGELOG.md` no repositório.
- **Manter o GitHub sempre atualizado**: CHANGELOG, `estado-atual/` (estado atual e antigo), docs legíveis pelo
  Claude Code do amigo. Commit num branch e merge no `main` (autorizado).
- **Manter este vault atualizado a cada prompt e a cada versão** (ideias, requisitos, decisões, erros, estratégias).
- **Imagens de exemplo** sempre salvas em [Referências visuais](../11_Referencias_Visuais/INDEX.md); manter as antigas para comparar.
- Dizer **sempre** o que foi testado e o que não foi.
- O dono pode trocar de modelo ou ficar sem tokens: **nada pode depender da memória da conversa**.
- Avisar sobre plugins, conectores ou skills que ajudariam.

## Produto
- Personagens originais (exceção: bioma 1). Recompensa rápida. Mobile-first. UI no estilo das referências.
- O jogo deve rodar bem em celular, tablet, PC e console.
- Textos do jogador em inglês e português.

## Privacidade
- O e-mail do dono é privado: nunca em commits, URLs ou serviços externos.

Relacionado: [Pedidos do dono](Pedidos_do_Dono.md) · [Fluxo de versão](../10_Estrategias/Fluxo_de_Versao.md) · [Equipe e colaboração](../14_Equipe_e_Ferramentas/Equipe_e_Colaboracao.md)
