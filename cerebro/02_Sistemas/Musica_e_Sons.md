---
title: Música e sons
date: 2026-11-14
tags: [sistema, audio, pendente]
aliases: [MusicController]
---

# Música e sons

- `Client.MusicController` (1.9): toca a música conforme o atributo `VersusStage` e o evento `VersusResult`,
  com fade; respeita o interruptor **Music** (`Set_Music`) do Configs.
- IDs em `Config.Music` (dentro de `Shared.ConfigBeta19`): `Race`, `Battle`, `VersusLobby`, `Victory`.
  **Estão vazios**: o jogo roda mudo, sem erro, até o dono escolher (Creator Store → Audio).
- `Config.Sounds` (cliques, captura, revelação, cash, boost) **está vazio desde a Beta 1.1**.
  `UIKit.PlaySound(name)` só toca se houver ID e se `Set_SFX` não for false.
- Pedido do dono (1.9): "músicas épicas" na corrida e na batalha.

Relacionado: [Tarefas do dono](../13_Pendencias/Tarefas_do_Dono.md) · [Desafio 1v1](Desafio_1v1.md) · [Backlog de ideias](../12_Ideias_e_Roadmap/Backlog_de_Ideias.md)
