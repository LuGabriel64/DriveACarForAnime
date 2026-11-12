# 06 — Interface em qualquer plataforma

Módulo `Client.Platform` (rascunho pronto, só compilado: precisa de teste em aparelho real ou no emulador
de dispositivos do Studio).

## O problema hoje

A UI do jogo usa tamanhos em pixels fixos (`UDim2.fromOffset`). Só o dock do lobby se ajusta à tela.
Num celular, o bloco de moedas (260 × 160), o velocímetro (280 × 100) e o painel de corrida ocupam uma
parte grande de uma tela de ~850 × 390 pontos, e o jogador vê menos pista e menos obstáculos.

## A regra

Um módulo só decide a classe do aparelho e o tamanho de cada tipo de interface.

| Classe | Como é detectada | Overlay em jogo | Painéis | HUD | Altura máxima de um overlay em jogo |
|--------|------------------|-----------------|---------|-----|--------------------------------------|
| **Phone** | toque, sem mouse, lado menor da tela < 500 | ×0,70 | ×0,82 | ×0,74 | 12% da tela |
| **Tablet** | toque, sem mouse, tela maior | ×0,85 | ×0,92 | ×0,88 | 14% |
| **Desktop** | teclado e mouse | ×1,00 | ×1,00 | ×1,00 | 18% |
| **Console** | interface de TV (`IsTenFootInterface`) | ×1,25 | ×1,15 | ×1,20 | 18%, com margem de 5% nas bordas |

- No PC, uma janela pequena também reduz a UI (de 0,6× a 1,3× conforme o tamanho da janela).
- A classe é reavaliada quando a janela muda de tamanho ou o jogador troca de entrada (ex.: liga um controle).

### Regras para todo overlay que fica na tela durante a corrida ou a batalha

1. **No celular o layout muda, não só encolhe.** `Platform.IsCompact()` troca para a versão de uma linha.
   Exemplo: o placar da corrida 1v1 vira `🥇 12.480 m · +310 m`.
2. **O centro fica livre.** Os 60% centrais da tela são da pista e dos obstáculos. Overlays ficam no topo
   ou nos cantos.
3. **Zonas dos polegares livres no toque:** embaixo à esquerda (joystick) e embaixo à direita (botões).
4. **Área segura:** todo `ScreenGui` novo usa `Platform.SafeArea` (entalhe da câmera, barra de gestos).
5. **Alvo de toque mínimo de 44 × 44 pontos** depois da escala. Botão menor que isso ganha área invisível.
6. **Texto nunca menor que 11 pontos** depois da escala. Se não couber, o texto é encurtado, não encolhido.
7. **TV:** textos maiores e nada encostado na borda (TVs cortam a imagem).

## Controles por plataforma

| Ação | Teclado e mouse | Toque | Controle |
|------|-----------------|-------|----------|
| Abrir desafio | clique no dock | toque no dock | navegar no dock com o direcional, A confirma |
| Aceitar / recusar convite | clique, ou Y / N | toque nos botões grandes | A aceita, B recusa |
| Votar no mapa | clique no cartão | toque no cartão | direcional + A |
| Fechar painel | X, ou clicar fora | X, ou tocar fora | B |
| Pegar o ovo gigante | segurar F | tocar e segurar | segurar X |

- As dicas de tecla na tela seguem a **última entrada usada** (`Platform.KeyHint`): quem está no controle
  vê "Ⓐ Accept"; quem está no celular não vê tecla nenhuma.
- Todo botão novo é selecionável pelo controle, e cada painel define qual botão começa selecionado
  (`GuiService.SelectedObject`).
- Nada depende só de passar o mouse por cima: tudo o que aparece no hover também aparece ao selecionar.

## Acessibilidade

- **Cor nunca é o único sinal.** Raridade tem nome além da cor; vitória e derrota têm texto e ícone;
  o aviso do colapso pisca e mostra a distância em número.
- **Contraste:** o padrão do UIKit (texto branco com contorno preto grosso) já é legível sobre qualquer fundo.
- **Movimento:** o tremor de câmera da batalha e do colapso respeita o interruptor "Speed Camera Effect".
  Proponho renomeá-lo para "Camera Effects" na próxima versão, sem mudar a chave salva.
- **Som:** nenhuma informação existe só no som. A música tem interruptor próprio ("Music").

## Onde aplicar

| Interface | Tipo | Mudança |
|-----------|------|---------|
| `UIKit.GetGui` (GameUI) | — | `Platform.SafeArea(gui)` |
| `UIKit.Panel` | Panel | a animação de abrir vai de 0,6 até `Platform.Scale("Panel")` (hoje vai até 1) |
| HUD: moedas, velocímetro, botões Home / Reset / Drive | Hud | `Platform.Apply(frame, "Hud")` |
| HUD: título do bioma, aviso BOOST / SLOWED | Overlay | `Platform.Apply(frame, "Overlay")` |
| `RaceUI`: painel ao vivo e contagem | Overlay | idem |
| `EscapeFX` / `CollapseFX`: faixa de aviso | Overlay | idem; no celular, uma linha só |
| `Notify`: avisos | Overlay | idem; no celular, largura máxima de 80% da tela |
| `LobbyDock` | — | já se ajusta; a largura passa de 720 para 912 com os 2 botões novos |
| `WheelPanel`, `EggRouletteUI`, `GrabPromptUI` | — | já têm ajuste próprio; passam a usar `Platform.Scale` para ficar consistente |
| UI nova (`VersusUI`, `DuelRaceUI`, `BattleUI`, lojas) | Overlay / Panel | nasce usando `Platform` |

## Como testar

No Studio: **Test → Device** (emulador). Conferir cada tela em pelo menos:

| Aparelho | Por quê |
|----------|---------|
| iPhone SE (667 × 375) | menor tela comum |
| iPhone 14 Pro Max, deitado | entalhe e barra de gestos |
| iPad | classe Tablet |
| 1920 × 1080 | PC |
| 1366 × 768, janela reduzida | PC fraco |
| Xbox / TV 1080p com controle | classe Console e navegação |

Para cada um: a pista aparece no centro? Algum botão ficou embaixo do polegar? Dá para fazer o fluxo
inteiro (convite → votação → corrida → resultado) só com aquela entrada?
