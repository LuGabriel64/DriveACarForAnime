---
title: Estilo visual (UIKit)
date: 2026-11-14
tags: [ui, estilo]
aliases: [UIKit, Design system]
---

# Estilo visual (UIKit)

`StarterPlayerScripts.Client.UIKit` é o "design system" do jogo. **Toda tela usa ele.** Estilo das
referências (Steal an Egg / Throw a Food for Animals).

## Tokens
- **Fonte:** `Enum.Font.FredokaOne` (grossa, arredondada).
- **Texto:** branco com **contorno preto forte** (legível sobre qualquer fundo).
- **Cantos arredondados**; painéis escuros com cabeçalho colorido; botão **X vermelho** para fechar.
- **Cores (`UIKit.C`):**

| Token | RGB | Uso |
|-------|-----|-----|
| PanelBg | 14, 14, 22 | fundo dos painéis |
| CardBg | 30, 30, 44 | cartões |
| Red | 228, 48, 48 | fechar, perigo |
| Green | 78, 214, 52 | confirmar |
| Blue | 38, 128, 255 | ação neutra |
| Orange | 255, 166, 20 | destaque |
| Magenta | 206, 44, 206 | especial |
| Cyan | 40, 200, 230 | lobby / neon |
| Cash | 88, 255, 70 | dinheiro |
| Gold | 255, 200, 40 | prêmio |
| Grey | 110, 110, 124 | desativado |

- Cores de raridade em `Config.Rarities` (Secret = preto "Void" com texto claro).

## Funções
`New`, `Text`, `Button` (pop + squash no clique), `MenuButton`, `Panel` (cabeçalho, fechar, abre deslizando
com fundo escurecido, registra em `UIKit.Panels`), `Viewport` (enquadra pela maior medida do modelo),
`Pop`, `Shake`, `Confetti`, `Tween`, `PlaySound`, `Rainbow`, `SpinGradient`, `Shine`, `FloatText`, `Sunburst`,
`Wobble`, `Percent`, `RarityLabel`, `Void*`. 1.9: `T`, `SetText`, `Locale.Bind`, `Platform.Scale("Panel")`.

## Regras
- StarterGui fica **vazio de propósito**: a UI é criada por código.
- Textos do jogador em inglês (traduzidos pelo Locale); comentários do código em português.
- Não aplicar `Platform.Apply` em botões do UIKit (já têm `UIScale`): só em Frames.
- `UIKit.Pop` respeita o atributo `Rest` e reseta no `Completed` (bug da 1.9 corrigido).

Relacionado: [Hierarquia de telas](Hierarquia_de_Telas.md) · [Requisitos de UI](Requisitos_de_UI.md) · [Interface multiplataforma](Interface_Multiplataforma.md) · [Idiomas](../02_Sistemas/Idiomas_Locale.md)
