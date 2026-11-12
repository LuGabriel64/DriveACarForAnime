# Estado atual do jogo — leia isto primeiro

> **Última atualização:** 12/11/2026, pelo Claude Code local do dono (PC com Windows, ligado ao Roblox Studio
> pelo MCP). Se você é um Claude Code (app, nuvem, PC do amigo) chegando agora, esta pasta resume **tudo** o
> que foi feito, testado, deixado de lado e o que falta. Nada aqui depende da memória de alguma conversa.

## Em uma frase

O jogo está na **Beta 1.8d**: as correções da auditoria foram aplicadas e testadas no Studio. A versão está
**salva** no place, mas **ainda não publicada**. A **Beta 1.9** está só projetada: nada dela entrou no jogo.

## Situação de cada coisa

| O quê | Estado |
|-------|--------|
| Jogo publicado (o que os jogadores veem) | Beta 1.8b |
| Place salvo no Studio (Team Create, versão 95) | **Beta 1.8d** |
| Espelho `src/` no GitHub | igual ao place 1.8d, byte a byte (conferido por checksum) |
| Tag git | `beta-1.8d` (commit `17e3993`) |
| `.rbxl` da 1.8d em `places/` | **falta** (só o dono consegue baixar) |
| Beta 1.9 | projetada em `planejamento/beta-1.9/`, **nenhuma etapa aplicada** |
| Próximo passo | publicar a 1.8d, depois o **Pedido 2 (Etapa A)** da Beta 1.9 |

## Arquivos desta pasta

| Arquivo | Conteúdo |
|---------|----------|
| [`01_beta-1.8d_o_que_foi_feito.md`](01_beta-1.8d_o_que_foi_feito.md) | Cada mudança no jogo, com o caminho no Explorer e o motivo |
| [`02_testado_e_nao_testado.md`](02_testado_e_nao_testado.md) | Cada teste feito e o resultado; o que ficou sem testar e como testar |
| [`03_tarefas_do_dono.md`](03_tarefas_do_dono.md) | Checklist do que só o dono (LuGabriel64) pode fazer |
| [`04_beta-1.9_situacao.md`](04_beta-1.9_situacao.md) | O que existe da 1.9, o que falta, a ordem das etapas e como pedir |
| [`05_historico_da_sessao_2026-11-12.md`](05_historico_da_sessao_2026-11-12.md) | Cada pedido do dono nesta sessão e o que o Claude Code respondeu ou fez |
| [`06_licoes_tecnicas.md`](06_licoes_tecnicas.md) | Pegadinhas descobertas (MCP, testes em Play, Git, Windows) |

## Como usar esta pasta (para o Claude Code)

1. Leia o [`CLAUDE.md`](../CLAUDE.md) da raiz: são as regras do projeto.
2. Leia este README e o `03_tarefas_do_dono.md`, para saber o que está esperando o dono.
3. Se tiver o Studio ligado, **confira o place antes de agir**: `Config.Version` e o topo de
   `ServerStorage.ProjectDocs.01_ChangeLog`. Com Team Create, o amigo (Gabxx10) pode ter mudado algo depois
   desta data.
4. Ao terminar qualquer trabalho, **atualize esta pasta**: o README, a tabela acima e, se for o caso, um
   `05_historico_da_sessao_<data>.md` novo. Depois atualize o `CHANGELOG.md`.

## Onde mais olhar

- `CHANGELOG.md`: catálogo de todas as versões.
- `docs/AUDITORIA_2026-11-11.md`: os problemas encontrados no place de 11/11 (quase todos corrigidos na 1.8d).
- `planejamento/beta-1.9/PROMPTS_PARA_O_STUDIO.md`: os pedidos prontos, um por etapa.
- Dentro do place: `ServerStorage.ProjectDocs.04_EstadoAtual` (o equivalente desta pasta dentro do Studio).
