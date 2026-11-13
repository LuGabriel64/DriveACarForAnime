# Tarefas do dono (LuGabriel64)

Coisas que **só você** pode fazer. Os assistentes não alcançam o Creator Hub, não publicam sem você pedir e
não baixam o place. Marque com `[x]` quando fizer (ou peça ao Claude Code para marcar).

## Agora (Beta 1.9)

- [ ] **Testar com 2 jogadores** no Studio: aba Test > Clients and Servers > 2 Players > Start. Em cada janela,
      escolher garagem; numa delas, CORRIDA 1v1 > INVITE > na outra, ACEITAR; READY nos dois; votar; esperar a
      corrida. Depois repetir com BATALHA (os dois precisam de pelo menos 1 personagem). Anote o que estranhar
      e cole para o Claude Code. Passo a passo em `estado-atual/07_beta-1.9_aplicacao_em_andamento.md`.
- [ ] **Dirigir o carro de F1** numa corrida 1v1 e dizer se está gostoso de pilotar (velocidade, curva).
- [ ] **Escolher as músicas** (Creator Store > Audio) e colar os IDs em `Config.Music` (dentro do
      `ReplicatedStorage.Shared.ConfigBeta19`): Race, Battle, VersusLobby e Victory. Sem ID, fica em silêncio.
- [ ] **Abrir o jogo no celular** (ou no emulador do Studio: Test > Device) e ver se placar, barras e botões
      estão bons de tamanho.
- [ ] **Preços** dos F1 ($150K a $5B) e das animações de vitória ($25K a $20B): ajuste jogando.
- [ ] **Publicar** quando os testes acima estiverem bons. Até lá, os jogadores veem a Beta 1.8b.
- [ ] **Baixar o `.rbxl`** (Arquivo > "Baixar uma cópia") como `places/DriveACarForAnime_Beta1.9_2026-11-13.rbxl`.

## Da Beta 1.8d (ainda valem)

- [ ] **Jogar um pouco no Studio** (Play) e ver se nada quebrou: menu, garagem, corrida, pegar o ovo, fuga,
      roleta da sorte.
- [ ] **Publicar** o jogo: no Studio, Arquivo > Publicar no Roblox. Até lá, os jogadores veem a Beta 1.8b.
- [ ] **Baixar o `.rbxl`**: Arquivo > "Baixar uma cópia". Salve como
      `places/DriveACarForAnime_Beta1.8d_2026-11-12.rbxl` (na pasta do repositório) e peça ao Claude Code para
      fazer o commit.
- [ ] (Opcional) **Instalar o Python 3** no PC, de python.org; na instalação, marque "Add to PATH". Depois rode
      `pip install zstandard lz4`. Isso permite ao Claude Code local extrair o place para `src/` e rodar os
      testes da Beta 1.9.
- [ ] (Opcional) **Identidade do Git** neste PC. Hoje os commits saem como "Claude Code". Se quiser seu nome:
      `git config --global user.name "LuGabriel64"` e `git config --global user.email "<seu e-mail>"`.

## Antes de vender coisas por Robux

- [ ] Criar 2 **Developer Products** no Creator Hub: "x3 Spins" (R$29) e "x10 Spins" (R$79). Ponha os IDs em
      `Config.Wheel.Packs[i].ProductId`; hoje estão em 0.
- [ ] Testar uma compra no jogo publicado.

## Conteúdo que falta escolher

- [ ] **Sons**: `Config.Sounds` está vazio desde a Beta 1.1, e o jogo não tem nenhum som.
- [ ] **Músicas** da Beta 1.9 (`Config.Music`: corrida, batalha, sala de espera, vitória). Sem ID o jogo roda
      mudo, sem erro.
- [ ] **Créditos**: trocar `[Your Name]` e `[Your Friend's Name]` em `Config.Credits`.
- [ ] **Presente grátis**: `Config.Gift.GroupId = 0`, ou seja, o presente não exige entrar num grupo. Se
      quiser exigir, ponha o ID do grupo.
- [ ] **Bandeiras do botão de idiomas** (Beta 1.9): conferir se 🇺🇸 e 🇧🇷 aparecem no Studio.
- [ ] **Preços** dos carros de F1 e das animações de vitória (Beta 1.9): são um chute; ajuste jogando.

## Decisões com o amigo (Gabxx10)

- [ ] O place já está em **Team Create** (o save foi para a nuvem como TeamCreate). Confirmar se o amigo abre
      o mesmo place. Se abrir, os dois veem as mudanças um do outro.
- [ ] Adicionar o amigo como **colaborador** do repositório no GitHub (Settings > Collaborators), para o Claude
      Code dele ler e escrever aqui.
- [ ] Combinar: antes de cada sessão, `git pull` e ler o topo do `01_ChangeLog` no place.

## Decisões abertas da auditoria

- [ ] `ServerStorage.Tools.LobbyBuilder` (lobby alternativo de 04/11, nunca aplicado): fica ou sai?
- [ ] `ServerStorage.Backups` pesa muito: agora são 1.1, 1.6, 1.7 e 1.8b, e o 1.8b inclui um `Map` completo.
      Com os `.rbxl` no GitHub, dá para manter só o mais novo e o 1.1, que é o único com terreno. Só apague se
      você pedir.

## Próximo passo de desenvolvimento

- [ ] Quando a 1.8d estiver publicada e jogada, cole no Claude Code local o **Pedido 2 — Etapa A** de
      `planejamento/beta-1.9/PROMPTS_PARA_O_STUDIO.md`. **Não** cole o Pedido 1: ele já foi feito.
