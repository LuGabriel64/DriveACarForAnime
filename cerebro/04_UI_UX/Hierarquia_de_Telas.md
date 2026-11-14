---
title: Hierarquia de telas
date: 2026-11-14
tags: [ui, telas]
---

# Hierarquia de telas

```
PlayerGui
├─ StartMenu            Client.StartMenu: START/JOGAR, CONFIGS, CREDITS, UPDATES, 🌐 Languages; escolha de garagem
├─ PlayTransition       cortina "TO THE TRACK!" (LobbyDock)
└─ GameUI               UIKit.GetGui()
   ├─ HUD               Client.HUD
   │  ├─ Currency, Speedo, BiomePill, Drive/Exit, Home, Reset
   │  ├─ RacePanel      Client.RaceUI (painel ao vivo da corrida solo)
   │  └─ LobbyDock      Glass + Row/{Race1v1, Battle, Garage, Inventory, Play, Shop, Gift, Wheel}
   ├─ Painéis (+ "_Backdrop"): Inventory ("My Garage"), Garage (Car Shop), Gift, Settings, RaceResults, Wheel,
   │  painéis do Versus (desafio, lojas, escolha do lutador)
   ├─ Toasts (Notify), EscapeBanner, DangerTint
   └─ Overlays 1.9: placar do DuelRaceUI, faixa de etapas e cartão de convite do VersusUI, cena do BattleUI
```

## Telas e donos
| Tela | Módulo | Notas |
|------|--------|-------|
| Tela de início | StartMenu | câmera orbitando o lobby, blur; versão no selo e no Configs |
| Dock do lobby | LobbyDock | some com `MatchId ≠ 0`; esconde o prompt Drive no lobby |
| My Garage | InventoryPanel | CHARACTERS / INCUBATOR / CARS; cartão 148×284 (1.9) |
| Car Shop | GaragePanel | lista os 7 carros |
| Roleta da sorte | WheelPanel | 6 fatias, pacotes, barra de pontos |
| Roleta do ovo | EggRouletteUI | cartas por raridade, "1 in N" + estrelas |
| Prompt do ovo | GrabPromptUI | cartão de vidro + anel que enche |
| Colapso | EscapeFX / DuelRaceUI | aviso, tela vermelha, tremor |
| Corrida | RaceUI | 3-2-1-GO, painel ao vivo, resultados |
| Desafio | VersusUI | painel, convite (Y/N), etapas, resultado, lojas |
| Batalha | BattleUI | barras de vida/escudo/energia, cena inteira |
| Avisos | Notify | toasts traduzidos, LevelUp |
| Lobby 3D | LobbyShowcase | giratórios, pódio, balcões com prompt E |

Ordem de carga (`ClientMain.ORDER`): Platform primeiro; MusicController, VersusUI, DuelRaceUI, BattleUI antes do StartMenu; StartMenu por último.

Relacionado: [Estilo visual UIKit](Estilo_Visual_UIKit.md) · [Mapa de scripts](../06_Codigo/Mapa_de_Scripts.md) · [Requisitos de UI](Requisitos_de_UI.md)
