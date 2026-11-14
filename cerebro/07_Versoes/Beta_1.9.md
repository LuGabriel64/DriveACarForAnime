---
title: Beta 1.9 — desafio 1v1, F1, batalha
date: 2026-11-13
tags: [versao, marco, beta-1-9]
autor: Claude Code (Lu, via MCP; Fable 5.2 e Opus 5.5)
status: salva (versão 113), não publicada
---

# Beta 1.9 (12 e 13/11/2026)

**Pedido do dono:** desafio 1v1 (botão no dock, convite, sala de espera, votação, 30 s de preparação); corrida de
F1 com loja própria e colapso desde a largada, mais lento; placar ao vivo; batalha de anime em arenas temáticas
com ULT por personagem e loja de animações de vitória; estrelas 0–5 com aumento fixo; nível até 50;
recompensas (perdedor só XP; vencedor XP + dinheiro + 10 pontos); 100 pontos = 1 giro; +2 por minuto; barra
"x/100"; overlays por plataforma; botão Languages com bandeiras EUA/Brasil; músicas épicas.

**Etapas:** A (fundação: ConfigBeta19, AnimeStats, Locale, Platform, save v3, telas) → B (desafio + corrida 1v1)
→ C (batalha) → D (fechamento, docs, espelho, tag).

**Testado (1 jogador):** sobe sem erros; idioma ao vivo; mochila com ★/XP/Poder; barra de pontos; fuga do ovo
com estrelas; dock com 2 botões; validações do servidor; cena da batalha com roteiro real; placar e colapso da
corrida (modo Duel só no cliente).

**Não testado:** tudo com 2 jogadores; dirigir o F1; celular/tablet/TV; música (IDs vazios).

**Diferenças do projeto:** EscapeFX não generalizado; vitória na corrida só na tela; SafeArea não aplicado.

**Erros no caminho:** comentário no meio de uma linha do InventoryPanel derrubou o dock (→ checagem de sintaxe);
`UIKit.Pop` com escala errada; câmera da batalha presa na órbita do menu (artefato de teste).

Salva como versão 113, commit `49ce202`, tag `beta-1.9`. Backup `Backups["Beta 1.8d"]`.

Relacionado: [Beta 1.8d](Beta_1.8d.md) · [Desafio 1v1](../02_Sistemas/Desafio_1v1.md) · [Corrida 1v1 de F1](../02_Sistemas/Corrida_1v1_F1.md) · [Batalha de anime](../02_Sistemas/Batalha_de_Anime.md) · [Estrelas, nível e XP](../02_Sistemas/Estrelas_Nivel_XP.md) · [Idiomas](../02_Sistemas/Idiomas_Locale.md) · [Não testado](../13_Pendencias/Nao_Testado.md)
