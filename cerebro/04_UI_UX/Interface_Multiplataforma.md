---
title: Interface multiplataforma
date: 2026-11-14
tags: [ui, mobile, plataforma, beta-1-9]
aliases: [Platform, Client.Platform]
---

# Interface multiplataforma

`Client.Platform` decide a classe do aparelho e o tamanho de cada tipo de UI. Uso:
`Platform.Apply(frame, "Overlay" | "Hud" | "Panel")` (grava o atributo `Rest`), `Platform.Scale(tipo)`,
`Platform.IsCompact()`, `Platform.KeyHint`.

| Classe | Detecção | Overlay | Painel | HUD | Altura máx. de overlay |
|--------|----------|---------|--------|-----|------------------------|
| Phone | toque, sem mouse, lado menor < 500 | ×0,70 | ×0,82 | ×0,74 | 12% |
| Tablet | toque, tela maior | ×0,85 | ×0,92 | ×0,88 | 14% |
| Desktop | teclado e mouse | ×1,00 | ×1,00 | ×1,00 | 18% |
| Console | `IsTenFootInterface` | ×1,25 | ×1,15 | ×1,20 | 18% + margem de 5% |

No PC, janela pequena também reduz (0,6× a 1,2×; o projeto dizia 1,3).

## Regras para overlays em jogo
1. **No celular o layout muda, não só encolhe** (ex.: placar em uma linha).
2. **O centro (60%) fica livre** para a pista e os obstáculos.
3. Zonas dos polegares livres (embaixo à esquerda e à direita).
4. Área segura (entalhe, barra de gestos) — `SafeArea` ainda **não** aplicado no GameUI (mudaria o layout sem teste).
5. Alvo de toque ≥ 44×44 pontos; texto ≥ 11 pontos.
6. TV: textos maiores e nada encostado na borda.
7. Dicas de tecla seguem a última entrada usada; tudo navegável por controle.

## Acessibilidade
Cor nunca é o único sinal; contraste do UIKit; tremor respeita "Speed Camera Effect"; nada só no som.

## Não testado
Celular, tablet e TV de verdade. Testar no Studio: **Test → Device** (iPhone SE, iPhone 14 Pro Max deitado,
iPad, 1920×1080, 1366×768, Xbox/TV).

Relacionado: [Requisitos de UI](Requisitos_de_UI.md) · [Estilo visual UIKit](Estilo_Visual_UIKit.md) · [Não testado](../13_Pendencias/Nao_Testado.md)
