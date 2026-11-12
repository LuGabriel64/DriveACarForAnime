# 05 — Idiomas (English / Português)

Módulo `Shared.Locale` + tabela `Shared.Locale.pt` (rascunhos prontos; a parte pura está testada).

## O que o jogador vê

- Na tela de início (a do START / CONFIGS), no **canto superior direito**, um botão **🌐 Languages**.
- Ao tocar, abrem duas opções: **🇺🇸 English** e **🇧🇷 Português**. A escolhida fica marcada.
- A troca vale na hora, para o jogo inteiro, e fica salva para as próximas vezes.
- Na primeira entrada, o idioma vem da conta Roblox do jogador: conta em português já abre em português.
- O mesmo seletor aparece dentro do painel Configs, para trocar no meio do jogo.

> **Bandeiras:** uso os emojis 🇺🇸 e 🇧🇷. Preciso conferir no Studio se o Roblox desenha bandeiras em todas
> as plataformas. Se não desenhar, troco por bandeiras feitas com Frames (listras e círculo), que funcionam
> em qualquer aparelho.

## Como funciona

O texto em **inglês é a chave**, exatamente como o código já está escrito:

```lua
Locale.T("Free spin ready!")                      --> "Giro grátis pronto!"
Locale.T("🔒 This egg needs a Tier %d car!", 3)   --> "🔒 Este ovo precisa de um carro Tier 3!"
Locale.T("Texto ainda sem tradução")              --> devolve o próprio texto (nunca quebra a tela)
```

- O idioma do jogador é o atributo `Lang` do Player (`"en"` ou `"pt"`), definido pelo servidor e salvo em `data.Lang`.
- A troca é a ação de rede `SetLanguage(code)`, que só aceita códigos de `Config.Languages`.
- **Por que não o sistema automático do Roblox:** ele segue o idioma da conta e não deixa o jogador escolher
  dentro do jogo. Com tabela própria, o botão funciona, a tradução fica no Git (fácil de revisar) e um
  idioma novo é só mais um arquivo.

### Textos fixos: tradução automática pelo UIKit

Quase toda a UI passa por `UIKit.Text`, `UIKit.Button`, `UIKit.Panel` e `UIKit.SetButton`. Esses quatro
passam a chamar `Locale.Bind(objeto, texto)` **quando o texto tem tradução**:

- `Bind` escreve o texto traduzido e guarda a chave. Quando o idioma muda, todos os textos ligados são
  reescritos sozinhos, sem recriar a interface.
- Textos que mudam o tempo todo (`"0"`, `"GARAGE 3"`, valores de dinheiro) não têm tradução na tabela,
  então o UIKit não toca neles.
- Se outro script escrever por cima de um texto ligado, o `Bind` percebe (o texto na tela não é mais o
  que ele pôs) e solta aquele objeto, em vez de sobrescrever um valor novo com uma frase velha.

### Textos montados com valores

Frases que hoje o código monta juntando pedaços passam a usar formato, para a ordem das palavras poder
mudar em cada idioma:

```lua
-- antes
timerL.Text = "Spin in: " .. clock(nextAt() - serverNow())
-- depois
timerL.Text = Locale.T("Spin in: %s", clock(nextAt() - serverNow()))
```

São 18 frases, marcadas com `(FORMATO)` em `Locale/pt.luau`.

### Avisos que vêm do servidor

O servidor conhece o idioma do jogador (atributo `Lang`), então traduz antes de enviar:

```lua
-- antes
Net.Fire(player, "Toast", ("🔒 This egg needs a Tier %d car!"):format(biome.Tier), "error")
-- depois
Net.Fire(player, "Toast", Locale.For(player, "🔒 This egg needs a Tier %d car!", biome.Tier), "error")
```

São 11 pontos no código atual (CarService, EscapeService, ZoneService e WheelService), mais os dos serviços novos.
Placas do mapa vistas por todos (como "Free Garage") ficam em inglês nesta versão.

## O que já está traduzido

`Locale/pt.luau` tem **303 frases**: tela de início, Configs, dock, HUD, ovo gigante e fuga, corrida solo,
My Garage, loja de carros, vitrines do lobby, presente, roleta, raridades e mutações, e todos os textos
novos da Beta 1.9 (desafio, corrida 1v1, batalha, recompensas, estrelas e nível).

Os testes conferem que cada tradução tem os mesmos `%d` / `%s` da frase original, na mesma ordem, e que
nenhuma está vazia. Uma tradução com formato errado cairia para o inglês em vez de dar erro.

## O que fica em inglês nesta versão

| Texto | Motivo |
|-------|--------|
| Nomes de personagens, carros, biomas, ovos e ULTs | são nomes próprios; dá para traduzir depois, por tabela |
| Notas de atualização (botão UPDATES) | textos longos, um bloco por versão; proponho traduzir a partir da 1.9 |
| Créditos | nomes |
| Placas no mapa (garagens, pontes, largada) | o mesmo objeto é visto por todos os jogadores; traduzir por jogador exige trocar o texto no cliente |
| Sistemas guardados (captura, ovos de estrada, santuários) | estão desligados |

## Para adicionar um idioma depois

1. Uma linha em `Config.Languages` (código, nome, bandeira, prefixos de idioma do Roblox).
2. Um ModuleScript `Shared.Locale.<código>` copiando `pt` e traduzindo os valores.
3. Nada mais: o botão e a detecção passam a oferecer o idioma.
