# Drive A Car For Anime — instruções para assistentes de IA

Leia este arquivo inteiro antes de mexer no jogo. Vale para o Claude Code do dono, o Claude Code do
amigo, o Claude (chat), o Roblox Assistant e o Rebirth IA.

## O que é

Jogo de Roblox no estilo "Steal an Egg" / "Throw a Food For Animals" / "Kick a Lucky Block":
- o jogador dirige por 7 biomas longos;
- pega o ovo gigante no fim de cada bioma e foge com a pista desmoronando;
- choca personagens de anime, que rendem $/s na garagem;
- compra carros melhores, que abrem os próximos biomas.

Versão atual do jogo: **Beta 1.9** (salva no Studio em 13/11; a publicada ainda é a 1.8b). Projeto e plano em
`planejamento/beta-1.9/`; o que foi aplicado, testado e não testado em `estado-atual/07_beta-1.9_aplicacao_em_andamento.md`. Dois desenvolvedores: o dono do repositório (LuGabriel64) e um amigo (Gabxx10),
cada um com o seu Claude Code.

## Fonte da verdade

1. **O place no Roblox Studio é a fonte da verdade do JOGO.** O código foi escrito por assistentes que
   editam o Studio direto, via MCP. Este repositório é um **espelho**: `src/` é extraído do place com
   `tools/place/place_tool.py`.
2. **Não edite `src/` esperando que o jogo mude.** Ainda não há Rojo sincronizando. Mudança de jogo:
   - pelo MCP do Roblox Studio (Claude Code rodando no PC com o Studio aberto), ou
   - colando o código no Studio.

   Depois, re-extraia o place e faça commit.
3. A documentação oficial vive **dentro do place**, em `ServerStorage.ProjectDocs`, com cópia em
   `src/ServerStorage/ProjectDocs/`:
   - `00_ProjectBible`: as seções 10c a 10f valem por cima das anteriores;
   - `01_ChangeLog`: o histórico completo, com a entrada mais nova no topo;
   - `02_AI_Protocol`: as regras de colaboração;
   - `03_Guia_Bioma1`.

   Leia o ChangeLog **e** o cabeçalho do módulo antes de editar.

## Mapa rápido

| Preciso de… | Onde está |
|-------------|-----------|
| **Estado atual do jogo, o que foi testado e o que falta (comece aqui)** | `estado-atual/README.md` |
| Onde fica cada script, biomas, loop, ações de rede | `docs/ESTRUTURA.md` |
| Problemas conhecidos e como corrigir | `docs/AUDITORIA_2026-11-11.md` |
| Todas as versões, da 0.1.0 à planejada 1.9 | `CHANGELOG.md` |
| Projeto da próxima versão + passo a passo para aplicar | `planejamento/beta-1.9/README.md` e `07_plano_de_implementacao.md` |
| Como ligar o Claude Code ao Roblox Studio | `docs/CONECTAR_STUDIO.md` |
| O que foi decidido no chat até a Beta 1.2 | `docs/HISTORICO_CHAT.md` |

## Regras do projeto (do dono + `02_AI_Protocol`)

- **Versão e backup:** toda mudança relevante gera uma nova versão Beta (1.8 → 1.8b → 1.9…).
  - Antes de mudar, faça backup em `ServerStorage.Backups["<versão anterior>"]` (com LEIA-ME de restauração).
  - Salve também o `.rbxl` em `places/` e crie a git tag `beta-X.Y`.
- **Catalogar sempre**, em dois lugares: uma entrada no topo de `ServerStorage.ProjectDocs.01_ChangeLog` (no Studio)
  e no `CHANGELOG.md` deste repo. A entrada traz data, autor/assistente, versão, scripts alterados com o caminho
  completo no Explorer, motivo, o que foi testado e o que NÃO foi.
- **Ler antes de escrever:** qualquer assistente ou pessoa pode ter mudado qualquer coisa. Antes de começar,
  extraia o place atual e rode `git diff`.
- `Shared.Config` é a fonte única de números e conteúdo. Não renomeie chaves públicas: Config, ações do Net,
  atributos do Player e campos salvos.
- Servidor decide tudo: moedas, sorteio, DataStore, Robux. O cliente só pede via `Shared.Net`, e todo
  `Net.Handle` valida tipo e limites.
- Todo script começa com um cabeçalho `--[[ ]]`: o que faz, entradas/saídas, dependências e a versão que mudou.
  Comentários em português; textos da UI do jogador em inglês. A UI usa sempre o `UIKit`.
- Mudou o formato do save? Atualize `defaults()`, `reconcile()` e `migrate()` no DataService e suba `Version`.
- Sistemas antigos ficam **guardados** atrás de `Config.Features`, sem apagar código.
- **Nunca** dê `require` em `ServerScriptService.Services.*` pelo Command Bar durante o Play: isso cria um
  segundo Net e tudo vira "UnknownAction".
- O mapa e o terreno saem sempre do `ServerStorage.Tools.WorldBuilder`; não edite à mão.
- **Propriedade intelectual:** só personagens originais. Exceção registrada: o dono escolheu o elenco
  estilo Dragon Ball no bioma 1 (Beta 1.6; nomes alterados na 1.7) e assume o risco. Não amplie para
  outros biomas sem pedido expresso.
- MCP do Studio: o `studio_id` muda entre chamadas, então chame `list_roblox_studios` antes. Scripts
  `execute_luau` devem ser idempotentes (a conexão cai no meio).

## A cada pedido do dono (mesmo sem mudar o jogo)

- Atualize o GitHub no mesmo turno: `CHANGELOG.md` (seção "Repositório" ou a versão do jogo), os documentos
  afetados e este arquivo, se o estado mudou. Commit num branch, depois junte ao `main` (o dono autorizou).
- Escreva para quem chega sem contexto: o Claude Code do outro desenvolvedor lê só o repositório.
- Diga sempre o que foi testado e o que não foi. Código escrito sem o Studio é **rascunho** e fica em
  `planejamento/`, nunca em `src/`.
- O dono pode trocar de modelo ou ficar sem tokens no meio: nada pode depender da memória da conversa.
  O que importa tem de estar num arquivo deste repositório.

## Projeto de uma versão antes de ter o Studio

Padrão usado na Beta 1.9 (`planejamento/beta-1.9/`):
- documentos numerados com o desenho, um `README.md` com status e decisões em aberto, e um plano de
  implementação em etapas com os testes de cada uma;
- `rascunho/` com o Luau já escrito, nos caminhos de destino do Explorer;
- `testes/` com testes da lógica pura, rodando fora do Roblox contra o `Config` real de `src/`:

```bash
python planejamento/beta-1.9/testes/run_tests.py
```

Os rascunhos evitam sintaxe exclusiva do Luau (anotações de tipo, `continue`, expressão `if`) para que os
mesmos arquivos rodem nos testes.

## Sincronizar o repositório com o Studio (a cada versão)

```bash
# 1. no Studio: Arquivo > "Baixar uma cópia" (.rbxl) e copie para places/
python tools/place/place_tool.py summary places/<arquivo>.rbxl   # árvore + alertas (ex.: Map duplicado)
python tools/place/place_tool.py extract places/<arquivo>.rbxl   # reescreve src/
git diff --stat                                                  # o que mudou desde o último commit
```

No Windows/macOS: `pip install zstandard lz4` antes, porque o leitor usa esses pacotes.

## Estado em 13/11/2026

- **Jogo:** Beta 1.9 aplicada e salva (versão 113 do place, Team Create), **não publicada**. Desafio 1v1 (corrida de
  F1 e batalha de anime), estrelas, nível, pontos de spin, idiomas EN/PT e UI por aparelho. Testado com 1 jogador;
  **falta o teste com 2 jogadores** (o MCP só abre Play de 1). Próximo número de versão: **Beta 1.9b** (ajustes) ou 2.0.
- O histórico abaixo (12/11) continua valendo para o resto.

## Estado em 12/11/2026

- **Jogo:** Beta 1.8d, aplicada em 12/11 pelo Claude Code do dono, no PC dele, via MCP. É a Etapa 0 do
  plano: mapa duplicado fora do Workspace, anti-trapaça (`Config.AntiCheat`), save com Robux e limpeza.
  - Está **salva** no place (versão 95, Team Create), mas **não publicada**: os jogadores ainda veem a 1.8b.
  - `src/` confere byte a byte com o place (checksum). Ver `CHANGELOG.md`.
- **Numeração:** "Beta 1.8c" foi usada no place por uma entrada só de documentação (11/11). Por isso a Etapa 0
  virou 1.8d. Antes de escolher o número de uma versão, confira o topo do `01_ChangeLog` **dentro do place**.
- **Falta da 1.8d:** o `.rbxl` em `places/` (Studio > "Baixar uma cópia") e publicar o jogo.
- **PC do dono:** não tem Python instalado, então `place_tool.py` e os testes da 1.9 não rodam lá ainda.
  Para conferir o espelho sem Python, compare checksums dos `Source` pelo MCP (como no commit da 1.8d).
- **Beta 1.9 em aplicação (12/11):** a Etapa A está no place, sem `save_place`, sem espelho em `src/` e com as
  telas sem teste. Leia `estado-atual/07_beta-1.9_aplicacao_em_andamento.md` antes de mexer.
- **Beta 1.9, projeto original:** desafio 1v1 (corrida de F1 e batalha de anime), estrelas, nível,
  pontos de spin, idiomas EN/PT e UI por plataforma. Lógica pura testada (80 verificações); módulos que
  dependem do Roblox só compilados; UI, mapa e dois serviços ainda por escrever. Se o place já estiver na
  1.9 quando for aplicar, vira 2.0.
- **A sessão da nuvem (claude.ai/code) não alcança o Studio.** Quem aplica é um Claude Code local.
  Em 12/11 o dono ligou o Claude Code do PowerShell ao Studio (MCP `Roblox_Studio`), e esse Claude Code aplicou a
  Etapa 0 (Beta 1.8d). Os pedidos prontos para colar lá, um por etapa, estão em
  `planejamento/beta-1.9/PROMPTS_PARA_O_STUDIO.md`. Se você é esse Claude Code local: rode `git pull`, siga o
  plano a partir da **Etapa A** e pare ao fim de cada etapa.
- **Pendências do dono:** IDs de música (`Config.Music`) e de sons (`Config.Sounds`), ProductIds dos
  pacotes da roleta, créditos, `Gift.GroupId`, conferir as bandeiras do botão de idiomas.
- **Colaboração:** o amigo ainda não usa o GitHub. Recomendado: Team Create para o jogo (mesmo place) e o
  amigo como colaborador do repositório com a conta dele. GitHub sozinho não junta dois places.
  Ver `docs/CONECTAR_STUDIO.md`.
- **Ainda sem conexão:** Obsidian e os demais conectores (referências de UI). O dono vai ligar depois.
- Ideias de produto ainda na fila: anéis de energia com combo, página Index (coleção), compra de vagas na
  garagem, rebirth, ranking de distância (a auditoria 4, que bloqueava o ranking, foi corrigida na 1.8d).
