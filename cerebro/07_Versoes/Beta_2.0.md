---
title: Beta 2.0 — carros de F1 em malha, piloto automático, combustível (em andamento)
date: 2026-11-15
updated: 2026-11-15
tags: [versao, beta-2-0, em-andamento]
autor: Claude Code (Lu; Fable 5.2)
status: Etapa A feita (arte); nada aplicado no jogo
---

# Beta 2.0 (em andamento desde 15/11/2026)

**Pedido do dono:** carros de Fórmula 1 modelados no Blender, 3 por bioma, com pintura do bioma e acessórios
(bioma 1 com tema e um Mini Goku voando junto); personagem Mini Goku Épico com 2 skins; elenco do bioma 1
remodelado pelas imagens + novo Secret e novo Mítico; primeira pessoa na corrida; modo Manual/Automático com
piloto automático, skill-checks e falhas; combustível; teto no engine upgrade e novo Fuel Engine.

Projeto completo: `planejamento/beta-2.0/README.md` no repositório.

| Etapa | Conteúdo | Estado |
|-------|----------|--------|
| A | arte dos 21 carros no Blender (FBX + pinturas) | ✅ versão 1, **aprovada pelo dono em 16/11** |
| B | importar no Roblox, `CarFactory` com malhas, companheiro voador | ⏳ Studio ligado; falta o dono aprovar a pasta `arte\export` para upload |
| C | 21 carros no Config, combustível, upgrades, primeira pessoa, Manual/Auto, piloto automático, skill-checks | ⏳ projetado |
| D | personagens do bioma 1 em malha + 3 novos | ⏳ arte v2 de Gokun, Super Gokun e Mini Gokun (2 skins) feita; faltam os outros e a importação |
| E | fechamento, testes, tag | ⏳ |

**Feito em 15/11:** gerador paramétrico (`arte/blender/`), 21 carros exportados, folha de renders, estudo do
Mini Gokun em 2 skins, 20 imagens de referência guardadas com nota.

**Feito em 16/11:** personagens v2 por [escultura SDF](../05_Modelagem/Personagens_SDF_Blender.md) (o dono pediu estilo anime 2.5D com cel-shading): Gokun, Super Gokun com aura, Mini Gokun nas 2 skins sobre a nuvem com fumaça. Resultado e as 9 referências em [Referências 16/11](../11_Referencias_Visuais/2026-11-16_Gokun_Referencias_v2.md). A v1 ficou guardada. O upload para o Roblox foi recusado (pasta não aprovada).

**Testado:** geração e render (conferidos na imagem). **Não testado:** tudo no Roblox.

**Por que parou aqui:** o Roblox Studio estava fechado e o MCP do Blender desligado. A arte foi feita com o
Blender em segundo plano; o código do jogo espera o Studio.

Relacionado: [Beta 1.9](Beta_1.9.md) · [Carros de F1 no Blender](../05_Modelagem/Carros_F1_Blender.md) · [Referência dos carros](../11_Referencias_Visuais/2026-11-15_Beta2_Carros_F1.md) · [Referência dos personagens](../11_Referencias_Visuais/2026-11-15_Beta2_Personagens_Bioma1.md) · [Tarefas do dono](../13_Pendencias/Tarefas_do_Dono.md)
