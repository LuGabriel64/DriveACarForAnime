---
title: Idiomas (Locale)
date: 2026-11-14
tags: [sistema, i18n, beta-1-9]
aliases: [Locale, Tradução, Languages]
desde: Beta 1.9
---

# Idiomas (Locale)

## O que o jogador vê
- Botão **🌐 Languages** no canto superior direito da tela de início → 🇺🇸 English / 🇧🇷 Português.
- As bandeiras são **desenhadas com Frames** (`FlagKind` us/br), porque emoji de bandeira não é garantido no Roblox.
- A troca vale na hora, para o jogo todo, e fica salva (`data.Lang`). Também há o seletor no painel Configs.
- Na primeira entrada, o idioma vem da conta Roblox (`pt-br` → `pt`).

## Como funciona
- **O texto em inglês é a chave**: `Locale.T("Free spin ready!")` → "Giro grátis pronto!". Sem tradução, volta o inglês.
- Cliente: `UIKit.T(...)` e `Locale.Bind(obj, texto)` (UIKit.Text/Button/Panel/SetButton ligam sozinhos;
  ao trocar o idioma, retraduzem sem recriar a UI). Se outro script sobrescrever, o Bind solta o objeto.
- Servidor: `Net.Fire(p, "Toast", Locale.For(p, "texto %d", x))`.
- Frases com valores usam formato (`%s`, `%d`), **nunca** concatenação com `..`.
- `Shared.Locale.pt`: 303+ frases (com extras como "⬆️ LEVEL UP!", "Forfeit" → "Desistência").
- Ação `SetLanguage(code)`; atributo `Lang`.

## O que fica em inglês
Nomes próprios (personagens, carros, biomas, ULTs), notas de atualização, créditos e placas no mapa vistas por todos.

## Adicionar um idioma
1 linha em `Config.Languages` + um ModuleScript `Shared.Locale.<código>`.

Relacionado: [Estilo visual UIKit](../04_UI_UX/Estilo_Visual_UIKit.md) · [Requisitos de UI](../04_UI_UX/Requisitos_de_UI.md) · [Convenções](../06_Codigo/Convencoes.md)
