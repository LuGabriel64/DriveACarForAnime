# Histórico da conversa no Claude (chat), 02/11 a 08/11/2026

Resumo da exportação da conversa "Drive A Car For Anime" (57 mensagens). As chamadas de ferramenta
(o código enviado ao Studio pelo MCP) não vêm na exportação. O código real está em `src/` e no place.
A partir da Beta 1.3, o histórico está só no `01_ChangeLog` do place, feito pelo Claude Code do amigo
e pelo chat.

| Data | Versão | Pedido do dono | O que foi feito |
|------|--------|----------------|-----------------|
| 02–03/11 | 0.1.0 | Criar o jogo do zero, com UI inspirada em imagens de referência (Steal an Egg etc.) | Projeto estava vazio (só Baseplate). Arquitetura Shared/Services/Client, DataService com trava, 3 biomas, fazenda, 3 carros, captura por mini-jogo, 18 personagens originais, UI (My Animes, Garage, Free Gift), `ProjectDocs` |
| 03–06/11 | 0.2.0 ("Beta 1.0") | Fazendas → garagens (8 pedestais, 4 de cada lado, referência por imagem); +4 biomas; biomas maiores e com mais obstáculos | 7 biomas, 7 carros, pista de 20.300 studs, 83 obstáculos, botão Home; corrigido kick no Studio sem API |
| 07/11 | Beta 1.1 | Bioma 1 de Dragon Ball Z; ovos no lugar da captura; tela de início START/CONFIGS/CREDITS/UPDATES; escolher garagem; nascer a pé + DRIVE; 7 raridades até SECRET; UI mais viva; backup | Feito, mas o bioma 1 virou **Warrior Canyon (original)**: o assistente recusou a marca DBZ por risco de remoção |
| 07/11 | — | Instalar skills/plugins (Design Taste, Grilling, Agent Browser, Find Skills, HyperFrames, OmniRoute, Graphify) e Obsidian | Grilling (Skills For Real Engineers), Find Skills (AI Skills) e Obsidian Notes vieram do catálogo; os outros são externos |
| 07/11 | Beta 1.2 | Lobby separado; pista exclusiva por jogador; bioma 1 de Dragon Ball (Namekusei, Corporação Cápsula, Torneio); guia de design; backup; corrigir bugs | Lobby flutuante, "pista fantasma" (slots 1..8, sem colisão e sem ver os outros), RaceService, bioma 1 = **Azure Planet** (original, inspirado nas referências) |
| 07–08/11 | — | Passar a conversa para o Claude Code | Teleport não funciona no Windows; foi criado `Documents\DriveACarForAnime\CLAUDE.md` no PC do dono |

## Decisões que continuam valendo

- **IP:** até a Beta 1.5 só personagens originais. Na **Beta 1.6** o dono pediu expressamente o elenco
  de DBZ no bioma 1 e assumiu o risco (exceção registrada no `02_AI_Protocol`, regra 13). Na Beta 1.7
  os nomes foram levemente alterados (Gokun, Kurilin, Vegita…).
- **Pista fantasma** em vez de 8 cópias do mundo: copiar daria ~200 mil peças.
- **DataService próprio** em vez de ProfileService: evita código de terceiros do Toolbox.
- Sistemas antigos ficam guardados atrás de `Config.Features`.
- O dono pediu: atuar como dev sênior e parceiro criativo, sempre ler o estado atual, comentar bem e
  catalogar tudo.

## O que aconteceu entre a 1.3 e a 1.8b (pelo ChangeLog do place)

| Versão | Mudança |
|--------|---------|
| 1.3 | Ovo gigante no fim do bioma, roleta, fuga com colapso, incubadora e My Garage |
| 1.4 | Lobby Sakura Night, dock (GARAGE/INVENTORY/PLAY/SHOP/GIFT), lobby só a pé e decoração japonesa high-tech |
| 1.5 | Roleta da sorte (8 h) |
| 1.6 | Elenco DBZ no bioma 1, migração de save v2, passarelas e pads de lentidão |
| 1.6b | Ovo pego passando com o carro |
| 1.7 | Roleta só na UI com pacotes de Robux, Secret preta, segurar F de volta e personagens chibi |
| 1.8 | Obstáculos animados (pêndulo, hélice, pistão, laser, gêiser) e menos boosts |
| 1.8b | Personagens no estilo "blocos anime" R6 |
