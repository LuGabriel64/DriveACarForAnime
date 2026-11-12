# Pedidos prontos para o Claude Code ligado ao Studio

Para o dono colar no Claude Code do **PowerShell** (o que está conectado ao Roblox Studio).
A sessão da nuvem (claude.ai/code) não alcança o Studio; ela projeta, revisa e mantém o GitHub.

**Um pedido por vez.** Cada etapa termina com teste em Play e com o place salvo. Só passe para a próxima
depois de jogar um pouco e ver que nada quebrou. A Beta 1.9 inteira é grande: espere várias sessões.

Antes de cada sessão, na pasta do repositório:

```bash
git pull
```

---

## Pedido 1 — Etapa 0: correções (vira a Beta 1.8c)

```text
Leia o CLAUDE.md, docs/AUDITORIA_2026-11-11.md e planejamento/beta-1.9/07_plano_de_implementacao.md.
Conecte ao Roblox Studio (liste os Studios antes) e confira Config.Version e a entrada do topo do
ServerStorage.ProjectDocs.01_ChangeLog. Se o jogo não estiver na Beta 1.8 / 1.8b, pare e me avise.

Faça SOMENTE a Etapa 0 do plano:
1. Backup em ServerStorage.Backups["Beta 1.8b"] (scripts, docs, ferramentas e Map) com LEIA-ME de restauração.
2. Workspace tem duas pastas "Map" e duas "SpawnLocation". Antes de apagar, confirme que as duas Map
   têm o mesmo número de descendentes e as mesmas posições; se forem diferentes, pare e me mostre a diferença.
   Se forem iguais, apague uma Map e uma SpawnLocation.
3. Aplique as correções 3, 4 e 5 da auditoria (limite de avanço na fuga e no recorde pela velocidade real
   do carro; DataService.save devolvendo false quando a gravação é cancelada pela trava).
4. Limpeza do item 7 da auditoria: segundo Sky do Lighting, StarterGui.ScreenGui vazio, Workspace.Script.
   NÃO apague o LobbyBuilder nem os Backups antigos.
5. Teste em Play: menu, garagem, corrida, pegar o ovo gigante, fuga até a base, roleta. Output sem erros.
6. Registre como Beta 1.8c no 01_ChangeLog, em Config.Version, em Config.Updates e no CHANGELOG.md do repo.
7. Me peça para salvar o place (Ctrl+S / Publicar). Depois faça commit e push no GitHub.

Diga no final o que foi testado e o que não foi. Não comece a Etapa A.
```

## Pedido 2 — Etapa A: fundação da Beta 1.9

```text
Leia planejamento/beta-1.9/ (README, 01, 04, 05, 06 e 07) e rode os testes
(python planejamento/beta-1.9/testes/run_tests.py, se houver Python; senão, siga sem eles e me avise).
Aplique a Etapa A do plano no Studio, usando os rascunhos de planejamento/beta-1.9/rascunho/ como base.
Os rascunhos marcados "só compilado" nunca rodaram: revise cada um contra o código real antes de usar.
Faça os testes em Play da Etapa A descritos no plano. O mais importante: um save antigo carrega e a
RENDA de cada personagem fica idêntica à de antes.
Registre no 01_ChangeLog, me peça para salvar o place, faça commit e push. Não comece a Etapa B.
```

## Pedido 3 — Etapa B: desafio e corrida 1v1

```text
Leia planejamento/beta-1.9/01, 02, 06 e 07. Aplique a Etapa B do plano.
Teste com 2 jogadores (Test > Start, 2 Players) seguindo a lista da Etapa B.
Reteste a fuga do ovo inteira, porque o EscapeFX foi generalizado.
Registre, me peça para salvar, commit e push. Não comece a Etapa C.
```

## Pedido 4 — Etapa C: batalha de anime

```text
Leia planejamento/beta-1.9/03, 06 e 07. Aplique a Etapa C do plano.
O BattleSim do rascunho já foi testado e calibrado: não mude os números de Config.Battle sem rodar os testes.
Teste com 2 jogadores seguindo a lista da Etapa C. Registre, me peça para salvar, commit e push.
```

## Pedido 5 — Etapa D: fechamento da Beta 1.9

```text
Aplique a Etapa D do plano: Config.Version = "Beta 1.9", Config.Updates, Bíblia (seção 10g), ChangeLog,
Protocolo. Atualize CHANGELOG.md, CLAUDE.md e docs/ESTRUTURA.md no repositório, faça commit e push,
e mova planejamento/beta-1.9 para planejamento/arquivo/beta-1.9 com uma nota do que mudou em relação ao projeto.
```

---

## Depois de cada etapa: conferência pela sessão da nuvem (opcional)

No Studio: Arquivo → "Baixar uma cópia" (`.rbxl`) e envie o arquivo na conversa do claude.ai/code.
A sessão da nuvem extrai os scripts, compara com a versão anterior e audita o que mudou.
