# CHANGELOG — Drive A Car For Anime

Entrada mais nova no topo. O ChangeLog **detalhado** de cada versão do jogo fica dentro do place, em
`ServerStorage.ProjectDocs.01_ChangeLog` (cópia em `src/ServerStorage/ProjectDocs/01_ChangeLog.luau`).
Aqui registramos também o que acontece **no repositório**.

Formato de cada entrada: data · versão · autor/assistente · o que mudou (caminho no Explorer) · testado / não testado.

---

## 2026-11-11 · Beta 1.8b (sem mudança no jogo) · Claude Code (sessão do dono, nuvem)

**Integração do projeto ao GitHub.** Nenhum script ou parte do mapa foi alterado no place.

- `places/DriveACarForAnime_Beta1.8b_2026-11-11.rbxl`: backup do place enviado pelo dono
  (sha256 `f8c2e664…5c58`, 207.026 instâncias).
- `src/`: os 55 scripts do place, extraídos no formato Rojo (mesmos caminhos do Explorer). Ficaram de fora
  os backups internos e o `Workspace.Script` "Hello world".
- `tools/place/`: leitor de `.rbxl` em Python (`rbxl.py`) e `place_tool.py`, com os comandos
  `extract` e `summary`.
- `docs/ESTRUTURA.md` (mapa do jogo), `docs/AUDITORIA_2026-11-11.md` (problemas encontrados) e
  `docs/HISTORICO_CHAT.md` (resumo da conversa do chat até a Beta 1.2).
- `CLAUDE.md`: instruções para os assistentes, com as regras do projeto e o fluxo de sincronização.
- `default.project.json`: mapeamento Rojo seguro (`$ignoreUnknownInstances`, que não apaga mapa nem
  backups). **Ainda não usar `rojo serve`**: o Studio continua sendo a fonte da verdade.

**Achados (ver auditoria):**
- 🔴 `Workspace.Map` e `Workspace.SpawnLocation` estão **duplicados** no place: +43 mil peças e todas as tags
  em dobro. Isso não existia na Beta 1.7. Correção manual no Studio: apagar uma cópia de cada.
- 🟠 O anti-trapaça da fuga aceita ~1.700 studs/s.
- 🟠 Recorde de distância baseado no cliente.
- 🟠 O save das compras com Robux pode ser cancelado pela trava da sessão sem avisar.

Testado: a extração foi feita duas vezes (script avulso e `place_tool.py`) e saiu idêntica byte a byte.
Não testado: nada roda em jogo; esta sessão não tem acesso ao Studio.

---

## Histórico do jogo (resumo do `01_ChangeLog` do place)

| Data | Versão | Autor | Resumo |
|------|--------|-------|--------|
| 10/11 | Beta 1.8b | Claude | Personagens estilo "blocos anime" R6 (rosto anime, cabelo em espetos); chibi 1.7 vai para LegacyCode |
| 10/11 | Beta 1.8 | Claude | Obstáculos animados nos 7 biomas (51 no total); boosts de 143 para 46; lanternas do lobby corrigidas (StreamingEnabled) |
| 10/11 | Beta 1.7 | Claude | Roleta só na UI + pacotes x3/x10 por Robux (ProductId pendente); Secret preta; "segurar F" volta com UI própria; personagens chibi; colapso na velocidade do SEU carro |
| 09/11 | Beta 1.6b | Claude | Ovo pego passando com o carro; prompt Drive some com o banco ocupado |
| 09/11 | Beta 1.6 | Claude | Elenco DBZ no bioma 1 (exceção do dono); migração de save v1→v2; passarelas, pads de lentidão e ponte de torneio; backups antigos apagados |
| 09/11 | Beta 1.5 | Claude | Roleta da sorte (8 h, servidor); leaderstats.Cash |
| 07/11 | Beta 1.4–1.4e | Claude | Lobby Sakura Night, dock, lobby só a pé, garagem japonesa, decoração JapanTech no bioma 1 |
| 07/11 | Beta 1.3 | Claude | Ovo gigante + roleta + fuga + incubadora + My Garage |
| 07/11 | Beta 1.2 | Claude | Lobby separado, corrida solo (pista fantasma), Azure Planet |
| 07/11 | Beta 1.1 | Claude | Tela de início, garagem, a pé + DRIVE/EXIT, ovos, Secret, Warrior Canyon |
| 06/11 | 0.2.0 (= Beta 1.0) | Claude | Garagens, 7 biomas, pista maior, 83 obstáculos |
| 03/11 | 0.1.0 | Claude | Fundação: arquitetura, dados, rede, 3 biomas, UI |
