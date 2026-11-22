---
title: Tarefas do dono
date: 2026-11-14
updated: 2026-11-16
tags: [pendencias, dono]
---

# Tarefas do dono (LuGabriel64)

Espelho do `estado-atual/03_tarefas_do_dono.md` do repositório. Marque `[x]` quando fizer.

## Agora (Beta 2.0)
- [ ] **Jogar a Beta 2.0 no Studio** e dizer o que achou: carro novo na corrida, garagem com os personagens animados, Super e Mini Gokun (chocar no ovo do bioma 1).
- [ ] **Publicar** quando aprovar (os jogadores ainda veem a 1.8b) e **baixar o `.rbxl`** como `places/DriveACarForAnime_Beta2.0_2026-11-22.rbxl`.
- [ ] Testar o 1v1 com 2 jogadores (agora com os F1 em malha).
- [ ] Apagar a pasta vazia `C:\LUCASG~1` (criada por engano pelo Claude em 22/11; o Claude não tem permissão para apagar pastas na raiz do C:).
- [x] Abrir o Roblox Studio e religar o MCP (feito em 16/11).
- [x] Olhar os carros (aprovados em 16/11).
- [x] **Aprovar a pasta de upload** (feito; importação concluída em 22/11): Studio → Assistant Settings → MCP Permissions →
      lista de pastas aprovadas para upload → adicionar `C:\Users\Lucas Gabriel\Documents\DriveACarForAnime\arte\export`.
      Liberar os escopos não basta: a pasta é uma lista à parte. Sem isso o Claude não consegue subir FBX nem PNG.
      Caminho no Studio: aba **Assistant** (ou View → Assistant) → engrenagem **Settings** → **MCP Permissions** → seção de
      pastas de upload ("approved upload directories") → **Add** → escolher a pasta acima. Pedido de novo em 16/11 (2).
- [x] Dizer se o estilo v2 dos personagens serve (aprovado em 16/11, com ajustes de rosto e mãos).
- [ ] **Dizer se a v3 serve** ([resultado](../11_Referencias_Visuais/2026-11-16_Gokun_Cabeca_v3.md)): rosto, mãos e as três animações de parado
      (vídeo `arte/renders/idle_personagens.mp4`). Com o sim, o Claude faz o resto do elenco do bioma 1 no mesmo corpo.
- [ ] (Opcional) Ligar o servidor MCP dentro do Blender.

## Antes (Beta 1.9)
- [ ] **Testar com 2 jogadores**: Studio → Test → Clients and Servers → 2 Players → Start. Garagem nas duas
      janelas; RACE 1v1 → INVITE → ACCEPT → READY → votar → 30 s. Depois BATTLE (os dois com 1+ personagem).
- [ ] **Dirigir o F1** e dizer se está bom (velocidade, curva).
- [ ] **Escolher as músicas** e pôr os IDs em `Config.Music` (`Shared.ConfigBeta19`): Race, Battle, VersusLobby, Victory.
- [ ] **Celular / emulador** (Test → Device): tamanho do placar, barras e botões.
- [ ] **Preços** dos F1 ($150K a $5B) e das animações de vitória ($25K a $20B).
- [ ] **Publicar** (jogadores ainda veem a 1.8b).
- [ ] **Baixar o `.rbxl`** como `places/DriveACarForAnime_Beta1.9_2026-11-13.rbxl`.

## Antes de vender por Robux
- [ ] Criar os Developer Products "x3 Spins" (R$29) e "x10 Spins" (R$79) e pôr os IDs em `Config.Wheel.Packs[i].ProductId`.
- [ ] Testar uma compra no jogo publicado.

## Conteúdo a escolher
- [ ] Sons (`Config.Sounds`). · [ ] Créditos (`Config.Credits`: trocar `[Your Name]`). · [ ] `Config.Gift.GroupId`.

## Com o amigo (Gabxx10)
- [ ] Confirmar que ele abre o mesmo place no Team Create.
- [ ] Adicioná-lo como colaborador do repositório no GitHub.
- [ ] Combinar `git pull` + leitura do topo do ChangeLog antes de cada sessão.

## Decisões abertas
- [ ] `Tools.LobbyBuilder` (nunca aplicado): fica ou sai?
- [ ] `ServerStorage.Backups` está pesado (1.1, 1.6, 1.7, 1.8b, 1.8d): manter só o 1.1 e o mais novo? (só apago se você pedir)

## Opcional (facilita o trabalho do Claude)
- [ ] Instalar **Python 3** (python.org, "Add to PATH") + `pip install zstandard lz4`: libera o extrator do place,
      os testes da 1.9 e o verificador de links do vault.
- [ ] Identidade do Git com o seu nome.
- [ ] Plugins do Obsidian → [Plugins recomendados](../14_Equipe_e_Ferramentas/Plugins_Recomendados.md).

Relacionado: [Não testado](Nao_Testado.md) · [Roadmap](../12_Ideias_e_Roadmap/Roadmap.md) · [Equipe e colaboração](../14_Equipe_e_Ferramentas/Equipe_e_Colaboracao.md)
