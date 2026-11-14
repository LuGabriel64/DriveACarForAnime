---
title: Mapa Cerebral — Drive A Car For Anime
date: 2026-11-14
updated: 2026-11-14
versao_do_jogo: Beta 1.9
tags: [moc, inicio]
aliases: [Início, Home, Mapa Mental]
---

# 🧠 Mapa Cerebral — Drive A Car For Anime

> [!NOTE]
> **Comece aqui.** Este vault é a memória viva do jogo: ideias, requisitos, sistemas, UI, modelagem, código,
> versões, erros e estratégias. O Claude Code lê e atualiza este vault **a cada pedido e a cada versão**.
> Para ver como mapa mental, abra [Mapa_Cerebral.canvas](Mapa_Cerebral.canvas) ou o Graph View (Ctrl+G).

## Estado agora (14/11/2026)

| | |
|---|---|
| Versão no Studio | **Beta 1.9** (salva, versão 113 do place, Team Create) |
| Versão publicada | Beta 1.8b |
| Próximo número | Beta 1.9b (ajustes) ou 2.0 |
| Bloqueio principal | teste com 2 jogadores, músicas, publicar → [Tarefas do dono](13_Pendencias/Tarefas_do_Dono.md) |
| GitHub | `LuGabriel64/DriveACarForAnime`, `main`, tag `beta-1.9` |

## O jogo em uma frase

Dirija por 7 biomas, pegue o **ovo gigante** no fim de cada um, **fuja** da pista que desmorona, choque
**personagens de anime** que rendem $/s na garagem, compre carros mais rápidos e, desde a 1.9, desafie
outro jogador em **corrida de F1** ou **batalha de anime**. → [Visão e pilares](01_Visao/Visao_e_Pilares.md)

## Ramos do mapa

| Ramo | Para que serve |
|------|----------------|
| [01 Visão](01_Visao/INDEX.md) | o que o jogo é, pilares, loop, gênero |
| [02 Sistemas](02_Sistemas/INDEX.md) | como cada sistema funciona (servidor e cliente) |
| [03 Conteúdo](03_Conteudo/INDEX.md) | biomas, personagens, raridades, carros, mapas |
| [04 UI e UX](04_UI_UX/INDEX.md) | como a interface é **e como deve ser** |
| [05 Modelagem](05_Modelagem/INDEX.md) | como personagens, carros e mapa são construídos |
| [06 Código](06_Codigo/INDEX.md) | arquitetura, onde fica cada script, convenções |
| [07 Versões](07_Versoes/INDEX.md) | linha do tempo de 0.1.0 até hoje, uma nota por versão |
| [08 Pedidos e decisões](08_Pedidos_e_Decisoes/INDEX.md) | tudo o que o dono pediu e cada decisão tomada |
| [09 Erros e lições](09_Erros_e_Licoes/INDEX.md) | bugs corrigidos, pegadinhas, checklist para não repetir |
| [10 Estratégias](10_Estrategias/INDEX.md) | como o Claude programa, modela, escreve, testa e faz brainstorm |
| [11 Referências visuais](11_Referencias_Visuais/INDEX.md) | imagens de exemplo do dono (antigas e novas, para comparar) |
| [12 Ideias e roadmap](12_Ideias_e_Roadmap/INDEX.md) | backlog de ideias e fases |
| [13 Pendências](13_Pendencias/INDEX.md) | tarefas do dono e o que não foi testado |
| [14 Equipe e ferramentas](14_Equipe_e_Ferramentas/INDEX.md) | quem faz o quê, MCP, GitHub, plugins |
| [15 Registro de sessões](15_Registro_de_Sessoes/INDEX.md) | o que foi feito em cada conversa |
| [Modelos](_Modelos/INDEX.md) | modelos de nota (versão, referência visual, ideia, sessão) |

## Regras que nunca mudam

1. O **place no Studio é a fonte da verdade** do jogo; o GitHub é o espelho; este vault é o cérebro. → [Arquitetura](06_Codigo/Arquitetura.md)
2. **O servidor decide tudo**; o cliente só pede via `Shared.Net`. → [Rede](02_Sistemas/Rede_Net.md)
3. **Números só no `Shared.Config`** (e no `ConfigBeta19`). → [Convenções](06_Codigo/Convencoes.md)
4. **Backup, versão e catálogo** a cada mudança relevante. → [Fluxo de versão](10_Estrategias/Fluxo_de_Versao.md)
5. **Dizer sempre o que foi testado e o que não foi.** → [Testar](10_Estrategias/Testar.md)
6. **Personagens originais** (exceção: elenco do bioma 1, decisão do dono). → [Decisões](08_Pedidos_e_Decisoes/Decisoes.md)

## Como o Claude usa este vault (todo pedido)

1. Ler esta nota, as [Tarefas do dono](13_Pendencias/Tarefas_do_Dono.md) e a nota do sistema que vai mexer.
2. Trabalhar no Studio e no GitHub seguindo o [Checklist antes de mexer](09_Erros_e_Licoes/Checklist_Antes_de_Mexer.md).
3. Ao terminar: atualizar as notas afetadas e a tabela "Estado agora"; criar a nota da versão em
   [07 Versões](07_Versoes/INDEX.md) se houver versão nova; registrar o pedido em
   [Pedidos do dono](08_Pedidos_e_Decisoes/Pedidos_do_Dono.md) e a sessão em [15](15_Registro_de_Sessoes/INDEX.md).
4. Imagens enviadas pelo dono vão para [Referências visuais](11_Referencias_Visuais/INDEX.md), **sem apagar as antigas**.
5. Copiar o vault para `cerebro/` no repositório (o Claude Code do amigo lê por lá). → [Ferramentas](14_Equipe_e_Ferramentas/Ferramentas_MCP_GitHub.md)
