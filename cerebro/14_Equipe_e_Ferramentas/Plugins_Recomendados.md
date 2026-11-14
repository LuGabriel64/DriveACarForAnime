---
title: Plugins recomendados
date: 2026-11-14
updated: 2026-11-14
tags: [ferramentas, obsidian, plugins]
---

# Plugins recomendados

## Não é preciso nenhum plugin para o vault funcionar
O Claude Code já lê e escreve esta pasta direto no disco. O vault usa só recursos nativos do Obsidian:
links, Graph View, **Canvas** ([Mapa_Cerebral.canvas](../Mapa_Cerebral.canvas)), Properties, Templates, Mermaid.

## Plugins da comunidade do Obsidian (opcionais, instalar em Configurações → Plugins da comunidade)
| Plugin | Para quê | Prioridade |
|--------|----------|------------|
| **Dataview** | listas automáticas a partir do frontmatter (ex.: todas as notas com `status: pendente`, versões por data) | alta |
| **Obsidian Git** | versiona o vault sozinho e mostra o histórico de cada nota | média (já há a cópia em `cerebro/`) |
| **Excalidraw** | desenhar esboços de telas e mapas à mão, para o Claude usar como referência | média |
| **Image Toolkit** ou **Image Converter** | ver e comparar imagens de referência lado a lado | baixa |
| **Advanced Canvas** | mais recursos no mapa mental em Canvas | baixa |

## Conectores e skills (Claude)
- **Skill `obsidian-notes`** (já instalada): checa links quebrados, órfãos e índices. Precisa de **Python** no PC.
- **GitHub (plugin engineering)**: precisa ser autorizado com `/mcp` para o Claude abrir PRs e issues pelo conector
  (hoje o Claude usa o `git` direto, o que já basta).
- **Figma / Canva** (conectores de design): úteis se você quiser mandar referências de UI por lá.
- Não é preciso um MCP do Obsidian: o acesso direto à pasta é mais simples e confiável.

## Dica de ambiente
Para o Claude Code sempre enxergar o vault, a pasta do D: foi adicionada às pastas de trabalho da sessão. Em
sessões novas, se o Claude disser que não acessa o vault, adicione a pasta (no app: botão de adicionar pasta;
no terminal: `claude --add-dir "D:\Arquivos Sistema\Obsidian\DriveACarForAnime"`).

Relacionado: [Ferramentas](Ferramentas_MCP_GitHub.md) · [Manter o vault](../10_Estrategias/Manter_o_Vault.md) · [Tarefas do dono](../13_Pendencias/Tarefas_do_Dono.md)
