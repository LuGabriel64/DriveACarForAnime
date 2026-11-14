---
title: Sessão 2026-11-14 — criação do Mapa Cerebral
date: 2026-11-14
tags: [sessao, obsidian]
modelo: Claude Opus 5.5 (Claude Code local, app desktop)
---

# Sessão 14/11/2026 — criação do Mapa Cerebral

**Pedido:** criar no vault do Obsidian um Mapa Cerebral do jogo com tudo do projeto (GitHub, ideias, versões,
pedidos, UI, modelagem, código, sistemas, erros, estratégias); atualizar a cada prompt e versão; guardar as
imagens enviadas (sem apagar as antigas); usar o mapa em todo prompt; avisar sobre plugins.

**Lido:** CLAUDE.md, README, CHANGELOG, `estado-atual/` (todos), `docs/` (estrutura, auditoria, histórico do
chat, conexão), `planejamento/beta-1.9/` (todos), ProjectDocs 00–04 do place (espelho), cabeçalhos do UIKit,
AnimeModelFactory, CarFactory, WorldBuilder, e o Config (biomas, carros, raridades, 71 personagens).

**Feito:**
- Vault com 16 ramos, índice em cada pasta, 94 notas, mapa mental em Canvas, modelos de nota.
- Configuração do Obsidian: links em markdown relativos, anexos em `11_Referencias_Visuais/entrada`, pasta de modelos, cores no grafo.
- Notas vazias de boas-vindas ("Bem-vindo", "crie um link") removidas.
- Cópia do vault em `cerebro/` no repositório + `tools/vault/vault_tools.js` + checagem de links.
- CLAUDE.md, CHANGELOG.md e memória do Claude atualizados para ler e manter o vault em todo prompt.

**Não feito / limites:** a skill `obsidian-notes` não rodou o linter oficial (o PC não tem Python); foi usado um
verificador em Node no lugar. Nenhuma imagem de referência existe em arquivo ainda.
Nenhuma mudança no jogo (Studio não foi tocado).

Relacionado: [Pedidos do dono](../08_Pedidos_e_Decisoes/Pedidos_do_Dono.md) · [Manter o vault](../10_Estrategias/Manter_o_Vault.md) · [Plugins recomendados](../14_Equipe_e_Ferramentas/Plugins_Recomendados.md)
