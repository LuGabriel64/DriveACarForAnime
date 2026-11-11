# Drive A Car For Anime — instruções para assistentes de IA

Leia este arquivo inteiro antes de mexer no jogo. Vale para o Claude Code do dono, o Claude Code do
amigo, o Claude (chat), o Roblox Assistant e o Rebirth IA.

## O que é

Jogo de Roblox no estilo "Steal an Egg" / "Throw a Food For Animals" / "Kick a Lucky Block":
- o jogador dirige por 7 biomas longos;
- pega o ovo gigante no fim de cada bioma e foge com a pista desmoronando;
- choca personagens de anime, que rendem $/s na garagem;
- compra carros melhores, que abrem os próximos biomas.

Versão atual: **Beta 1.8b**. Dois desenvolvedores: o dono do repositório e um amigo.

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

Ver `docs/ESTRUTURA.md`: Explorer, serviços, biomas, loop e ações de rede.
Problemas conhecidos: `docs/AUDITORIA_2026-11-11.md`. Histórico do chat até a Beta 1.2: `docs/HISTORICO_CHAT.md`.

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

## Sincronizar o repositório com o Studio (a cada versão)

```bash
# 1. no Studio: Arquivo > "Baixar uma cópia" (.rbxl) e copie para places/
python tools/place/place_tool.py summary places/<arquivo>.rbxl   # árvore + alertas (ex.: Map duplicado)
python tools/place/place_tool.py extract places/<arquivo>.rbxl   # reescreve src/
git diff --stat                                                  # o que mudou desde o último commit
```

No Windows/macOS: `pip install zstandard lz4` antes, porque o leitor usa esses pacotes.

## Estado em 11/11/2026

- O place de 11/11 tem **`Workspace.Map` e `SpawnLocation` duplicados**: 43 mil peças a mais e tags em dobro.
  Corrigir no Studio é a prioridade nº 1 (ver auditoria, itens 1 e 2).
- Abertos: o anti-trapaça da fuga é frouxo (auditoria 3) e o save das compras com Robux pode ser cancelado
  pela trava da sessão (auditoria 5).
- Pendências do dono: ProductIds dos pacotes da roleta, sons (`Config.Sounds`), créditos e `Gift.GroupId`.
- Próximos passos de produto, já sugeridos antes: anéis de energia com combo, página Index (coleção),
  compra de vagas na garagem, rebirth, ranking de distância (só depois da auditoria 4) e sons.
