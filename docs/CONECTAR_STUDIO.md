# Como ligar o Claude Code ao Roblox Studio

## Por que a sessão na nuvem não alcança o Studio

O Claude Code roda em dois lugares diferentes:

| Onde roda | O que alcança |
|-----------|---------------|
| **Na nuvem** (claude.ai/code no navegador ou no celular) | o repositório do GitHub. Lê e escreve código, documentos e testes. **Não enxerga o seu computador nem o Studio** |
| **No seu computador** (app Claude Desktop, aba Code, ou `claude` no terminal) | os arquivos do PC **e** os programas abertos nele, como o Roblox Studio |

O Roblox Studio oferece um servidor **MCP** — uma porta pela qual um assistente lê e altera o jogo aberto.
Essa porta só existe dentro do seu computador. Por isso, quem mexe no jogo é sempre um Claude Code
**local**, com o Studio aberto. Foi assim que as versões Beta 1.0 a 1.8b foram construídas.

A sessão na nuvem continua útil para tudo o que não precisa do Studio: projetar, revisar código, testar
lógica pura, documentar e manter o GitHub.

## Passo a passo (Windows)

> Estes passos vêm da conversa anterior do projeto, que consultou a documentação da Roblox. Os menus do
> Studio mudam com frequência: se um nome não bater, procure "MCP" nas configurações do Assistant e confira
> a página oficial **Roblox Creator Docs → Studio → MCP**. Não consegui abrir essa página desta sessão
> (o site `create.roblox.com` está fora da rede liberada aqui), então não a reconfirmei hoje.

1. **No Roblox Studio**, com o place aberto: painel **Assistant** → menu **…** → **Manage MCP Servers** →
   ative **Enable Studio as MCP server**.
2. Ainda no Studio: **Assistant Settings → MCP Servers → Quick connect** → ative **Claude Code**.
3. **Reinicie** o Studio e o Claude Code.
4. **Abra o Claude Code na pasta do repositório**:
   - app Claude Desktop → aba **Code** → sessão **local** → escolha a pasta `DriveACarForAnime`; ou
   - no terminal, dentro da pasta, rode `claude`.
5. Se a pasta ainda não existe no PC, baixe o repositório antes:

```bash
git clone https://github.com/LuGabriel64/DriveACarForAnime.git
```

6. Com o place aberto no Studio, mande ao Claude Code:

> Leia o CLAUDE.md. Conecte ao Roblox Studio, confira Config.Version e o topo do 01_ChangeLog, e siga
> planejamento/beta-1.9/07_plano_de_implementacao.md a partir da Etapa 0.

O Claude Code lê o `CLAUDE.md` sozinho ao abrir a pasta, então ele já sabe as regras do projeto e onde
está o plano.

## Como saber que conectou

Peça: "liste os Roblox Studios conectados". A resposta deve trazer **Drive A Car For Anime**
(place 83805628245898), em modo Edit. Se vier vazio: o Studio está aberto? O passo 1 ficou ligado depois
de reiniciar?

## O que o assistente consegue fazer pelo Studio

Pelo histórico do projeto (Beta 1.0 a 1.8b): ler e editar scripts, criar e mover objetos, rodar Luau,
iniciar e parar o Play, ler o Output e tirar capturas de tela.

Cuidados já aprendidos, que estão no `CLAUDE.md`:
- o identificador da conexão muda entre chamadas — listar os Studios antes de cada bloco de trabalho;
- a conexão pode cair no meio — todo script enviado precisa poder rodar duas vezes sem estragar nada;
- capturas de tela não mostram `BillboardGui` durante o Play;
- **salve o place** (Ctrl+S ou Publicar) depois de cada etapa: as mudanças só existem no Studio aberto.

## Dois desenvolvedores, um jogo

O Studio do dono e o do amigo abrem o **mesmo place** (Team Create) ou cópias diferentes? Isso muda tudo:

- **Mesmo place (Team Create):** os dois Claude Code alteram o mesmo jogo. Combinem quem mexe em quê e
  registrem no `01_ChangeLog` antes de começar, para um não sobrescrever o outro.
- **Cópias separadas:** cada um tem um jogo diferente e as versões divergem. Nesse caso o GitHub vira o
  ponto de encontro: quem terminar uma versão exporta o `.rbxl`, extrai para `src/` e faz commit; o outro
  parte dali.

Em qualquer caso, o ritual de cada versão é o mesmo (ver `CLAUDE.md`): backup, mudança, teste em Play,
ChangeLog, `.rbxl` em `places/`, extração para `src/`, commit e tag.

## Depois: Rojo (opcional)

O `default.project.json` deste repositório já descreve onde cada pasta de `src/` fica no Studio. Com o
**Rojo** instalado, editar um arquivo em `src/` mudaria o script no Studio na hora, e o GitHub passaria a
ser a fonte da verdade. **Ainda não usamos isso**: hoje o Studio é a fonte, e ligar o Rojo sem combinar
sobrescreveria scripts mais novos do Studio com os do repositório. Vale a pena quando os dois
desenvolvedores concordarem em trabalhar assim.
