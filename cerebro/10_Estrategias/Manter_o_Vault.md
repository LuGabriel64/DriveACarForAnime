---
title: Manter o vault
date: 2026-11-14
tags: [estrategia, obsidian, processo]
---

# Manter o vault (rotina do Claude a cada prompt)

**Onde está:** `D:\Arquivos Sistema\Obsidian\DriveACarForAnime\Drive A Car For Anime` (vault mestre) e cópia
em `cerebro/` no repositório (para o Claude Code do amigo e as sessões da nuvem).

## No começo do prompt
1. Ler [Mapa Cerebral](../00_Mapa_Cerebral.md) → nota do assunto → [Checklist](../09_Erros_e_Licoes/Checklist_Antes_de_Mexer.md).
2. Ver se há imagens novas em `11_Referencias_Visuais/entrada/`.

## No fim do prompt (mesmo sem mudar o jogo)
1. Linha nova em [Pedidos do dono](../08_Pedidos_e_Decisoes/Pedidos_do_Dono.md).
2. Atualizar as notas dos sistemas, UI, conteúdo ou código que mudaram (e o `updated:` do frontmatter).
3. Decisão nova → [Decisões](../08_Pedidos_e_Decisoes/Decisoes.md). Erro novo → [Erros corrigidos](../09_Erros_e_Licoes/Erros_Corrigidos.md) / [Pegadinhas](../09_Erros_e_Licoes/Pegadinhas_Tecnicas.md).
4. Ideia nova → [Backlog](../12_Ideias_e_Roadmap/Backlog_de_Ideias.md). Pendência → [13](../13_Pendencias/INDEX.md).
5. Versão nova → nota em [07 Versões](../07_Versoes/INDEX.md) (a partir do [modelo](../_Modelos/Modelo_Versao.md)) e tabela "Estado agora".
6. Nota da sessão em [15](../15_Registro_de_Sessoes/INDEX.md).
7. Conferir links (script de checagem) e copiar para `cerebro/` (`node tools/vault/vault_tools.js sync`).

## Imagens
Ver [Referências visuais](../11_Referencias_Visuais/INDEX.md): nunca apagar as antigas; cada imagem tem uma nota
com data, pedido, o que mudou e a comparação com a anterior.

## Formato
Links relativos em markdown, nomes de arquivo sem espaço, frontmatter (`title`, `date`, `updated`, `tags`),
linha "Relacionado:" no fim, um índice por pasta.

Relacionado: [Escrever documentação](Escrever_Docs.md) · [Fluxo de versão](Fluxo_de_Versao.md) · [Plugins recomendados](../14_Equipe_e_Ferramentas/Plugins_Recomendados.md)
