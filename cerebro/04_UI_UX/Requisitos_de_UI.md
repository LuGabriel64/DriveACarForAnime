---
title: Requisitos de UI (como deve ser)
date: 2026-11-14
tags: [ui, requisitos]
---

# Requisitos de UI — como a interface deve ser

Lista viva do que o dono pediu para a UI, com status. Atualizar a cada pedido.

| # | Requisito | Origem | Status |
|---|-----------|--------|--------|
| 1 | UI inspirada nas imagens de referência (Steal an Egg etc.): fonte grossa, contorno preto, cores vivas | 0.1.0 | ✅ UIKit |
| 2 | Tela de início com START / CONFIGS / CREDITS / UPDATES | 1.1 | ✅ |
| 3 | Escolher a garagem com ◀ ▶ e câmera voando até cada uma | 1.1 | ✅ |
| 4 | UI "mais viva" (arco-íris, brilhos, +$ flutuando) | 1.1 | ✅ |
| 5 | Dock inferior flutuante (GARAGE/INVENTORY/PLAY/SHOP/GIFT) e transição animada | 1.4 | ✅ |
| 6 | Painéis com fundo escurecido | 1.4 | ✅ |
| 7 | Roleta só na interface, com o visual da referência, pacotes x3/x10 | 1.7 | ✅ (IDs de Robux pendentes) |
| 8 | Raridade Secret **preta** | 1.7 | ✅ |
| 9 | "Segurar F" no ovo com UI própria | 1.7 | ✅ GrabPromptUI |
| 10 | Textos do ovo gigante menores | 1.8 | ✅ |
| 11 | Botão 1v1 no canto inferior esquerdo (dock) | 1.9 | ✅ RACE 1v1 e BATTLE |
| 12 | Cartão de convite (aceitar / recusar) | 1.9 | ✅ (sem teste com 2 jogadores) |
| 13 | Placar ao vivo da corrida 1v1: quem lidera e metros de cada um | 1.9 | ✅ DuelRaceUI |
| 14 | Overlays menores no celular, ajustados a console e PC | 1.9 | ✅ Platform (sem teste em aparelho) |
| 15 | Botão "Languages" no canto superior direito da tela de início, com bandeiras EUA e Brasil | 1.9 | ✅ bandeiras em Frames |
| 16 | Barra "x/100" de pontos de spin na roleta | 1.9 | ✅ |
| 17 | Estrelas, nível, XP e Poder no cartão do personagem | 1.9 | ✅ |
| 18 | Efeitos épicos na batalha (ULT, K.O., vitória) | 1.9 | ✅ BattleUI |

## Regras permanentes
- Toda UI pelo **UIKit**; textos do jogador em inglês + tradução no `Locale.pt`.
- UI nova usa `Client.Platform`; no celular, troca o layout.
- Nada de informação só por cor ou só por som.
- Imagens de referência novas → [Referências visuais](../11_Referencias_Visuais/INDEX.md), com a comparação antes/depois.

Relacionado: [Estilo visual UIKit](Estilo_Visual_UIKit.md) · [Interface multiplataforma](Interface_Multiplataforma.md) · [Pedidos do dono](../08_Pedidos_e_Decisoes/Pedidos_do_Dono.md)
