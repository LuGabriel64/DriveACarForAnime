---
title: Erros corrigidos
date: 2026-11-14
updated: 2026-11-14
tags: [erros, bugs]
---

# Erros corrigidos

| Versão | Sintoma | Causa | Correção | Lição |
|--------|---------|-------|----------|-------|
| 0.1.0 | estrada flutuando/enterrada | o Roblox desenha o terreno 2 studs acima (meio voxel) | `cell/2` no WorldBuilder | medir o chão real |
| 0.2.0 | jogador expulso no Studio | erro de API sem acesso vinha em minúsculas | detectar "studio"/"API access"/"403" | testar sem API |
| 1.2 | EXIT deixava o corpo no carro | o cliente é dono da física do corpo | cliente aplica `ExitCF` | quem é dono da física move |
| 1.2 | vagas giradas, "NEW RECORD" sobreposto, santuário na avenida | layout | ajustes | conferir em captura |
| 1.4 | pisos enterrados no lobby | terreno do lobby em y = 2 | `BuildLobby` mede o chão | idem |
| 1.4 | placas do showroom tortas | giratório é cilindro girado | placa num Attachment | cuidado com rotação de cilindro |
| 1.8 | "bola vermelha" na largada | 18 lanternas do lobby em (0,0,0): com StreamingEnabled o Model chega antes das peças e `GetPivot()` = origem | atributo `Home` + `ModelStreamingMode Atomic` | guardar posição em atributo |
| 1.8 | 1º diagnóstico errado da bola (lanterna do bioma 1) | olhar de cima | varais (ficaram) | confirmar a causa antes |
| 1.8b/c | dois `Map` e dois `SpawnLocation` | copiar/colar (Ctrl+D) | movidos para backup (1.8d) | checar duplicatas sempre |
| 1.8c | anti-trapaça aceitava ~1.700 studs/s | limite pelo SpeedCap global | orçamento pela TopSpeed real (1.8d) | limite pelo jogador, não global |
| 1.8c | recorde confiava no cliente | `MinZ` = posição do cliente | mesmo orçamento | idem |
| 1.8c | Robux confirmado sem gravar | `pcall` ok com `UpdateAsync` cancelado | `ok and wrote` | conferir que gravou |
| 1.9 | mochila e dock sumiram | comentário inserido no meio de uma linha (UIGridLayout) | corrigido + checagem de sintaxe | `loadstring` em tudo antes do Play |
| 1.9 | BiomePill ficava na escala 1 | resize durante o tween do `UIKit.Pop` | reset no `Completed` + atributo `Rest` | tween + resize brigam |
| 1.9 | HUD "Menu" com UIScale duplo | `Platform.Apply` em quem já tinha UIScale | excluído | Apply só em Frames |
| 1.9 | câmera da batalha presa no lobby | órbita do StartMenu continuava (menu destruído à mão no teste) | entrar pelo menu de verdade | artefato de teste |
| 1.9 | estandartes tapavam a câmera da arena | posição | atrás do ringue; câmera mais afastada | conferir em captura |
| 1.9 | "Victory Effects" duplicado no `pt` | chave repetida | removida | tabela de tradução sem duplicatas |
| 1.9 | `;(` no início de linha no BattleUI | ambiguidade de sintaxe | variável local | evitar linha começando com `(` |
| 1.9 | MirrorDump truncado em 100 KB | limite de saída do MCP | formato em partes `@@@PARTS k/n` | dividir saídas grandes |

Relacionado: [Pegadinhas técnicas](Pegadinhas_Tecnicas.md) · [Checklist antes de mexer](Checklist_Antes_de_Mexer.md) · [Linha do tempo](../07_Versoes/INDEX.md)
