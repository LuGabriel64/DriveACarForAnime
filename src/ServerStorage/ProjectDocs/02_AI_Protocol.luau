--[=[
  PROTOCOLO DE COLABORAÇÃO ENTRE ASSISTENTES (Roblox Assistant, Claude, Rebirth IA)
  =================================================================================
  Cole isto no início do prompt de qualquer assistente:
     "Antes de qualquer coisa, leia ServerStorage.ProjectDocs (04_EstadoAtual PRIMEIRO, depois 02_AI_Protocol,
      01_ChangeLog e 00_ProjectBible) e Shared.Config. Siga as convenções. Ao terminar, registre a mudança no
      01_ChangeLog (Author = quem fez: 'Claude Code (Lu)', 'Claude Code (amigo)', 'Roblox Assistant', 'Rebirth'...)."

  REGRAS
  1. LER antes de escrever: veja o ChangeLog e o módulo que vai tocar (cabeçalho explica o papel dele).
  2. UMA fonte de verdade: balanceamento e conteúdo só em Shared.Config. Não duplique números.
  3. Não renomeie/remova chaves públicas (Config.*, nomes de Net.Handle/Net.Fire, atributos do Player,
     campos salvos em data). Só adicione. Se precisar mudar, migre TODOS os usos e registre no ChangeLog.
  4. Rede: cliente pede, servidor valida e decide. Toda ação nova = Net.Handle com validação de tipo/limite.
  5. UI: use UIKit (consistência visual e animações). Textos em inglês na UI do jogador; comentários em português.
  6. Dados: mudou o schema? Atualize defaults() + reconcile() no DataService e registre.
  7. Cada script novo: cabeçalho --[[ ]] explicando função, entradas/saídas e dependências.
  8. Código gerado por IA: revise o que roda no servidor (exploits, loops infinitos, yields sem timeout).
  9. Não apague o trabalho de outro assistente sem registrar o motivo. Prefira corrigir e catalogar.
 10. Terreno/mapa: nunca edite Terrain à mão se puder alterar WorldBuilder e regenerar (é reproduzível).
 11. Testes durante o Play: NUNCA faça require() de ServerScriptService.Services.* pelo Command Bar/plugin.
     Isso cria outra cópia do Net, que sobrescreve Action.OnServerInvoke ("UnknownAction" em tudo). Teste pelo
     cliente (Net.Call) ou inspecionando atributos/instâncias.
 13. Propriedade intelectual: NADA de personagens, nomes ou marcas de animes existentes (ex.: Dragon Ball Z).
     Personagens precisam ser originais; o Roblox remove jogos por violação de direitos autorais.
     EXCEÇÃO (09/11/2026, Beta 1.6): o DONO decidiu usar o elenco de Dragon Ball Z no bioma 1 (Goku, Kuririn, Vegeta,
     Master Kame, Gohan, Cell, Piccolo, Majin Boo) e assume o risco. Não reverta sem o dono pedir; não amplie para
     outros biomas/IPs sem pedido expresso. O elenco original antigo continua no Config como Legacy.
     ATUALIZAÇÃO Beta 1.7: o dono pediu nomes LEVEMENTE alterados (Gokun, Kurilin, Vegita, Master Kamo, Gohen, Cello,
     Pikollo, Majin Bubu; Ids iguais). Não volte aos nomes originais e não copie emblemas/símbolos (ex.: kanji do peito).
 14. Antes de uma versão grande, faça BACKUP em ServerStorage.Backups["<versão>"] (veja "Beta 1.0").
     Sistemas antigos ficam GUARDADOS atrás de Config.Features (não apague código que o dono pode querer de volta).
 15. Cache de módulos no EDITOR: depois de editar o Config, um require() pelo Command Bar pode devolver a versão
     ANTIGA (o resultado fica em cache). Antes de gerar mapa, troque a instância por um clone:
       local c = game.ReplicatedStorage.Shared.Config; local n = c:Clone(); n.Parent = c.Parent; c:Destroy()
 16. Funções locais definidas MAIS ABAIXO no arquivo não existem para funções definidas acima (ex.: WorldBuilder
     usa WorldBuilder.PROP / WorldBuilder.EnergyAura no lobby por isso).
 17. Antes de mexer no mapa, confira se não há instâncias DUPLICADAS na raiz do Workspace (ex.: dois 'Map' ou dois
     'SpawnLocation' — aconteceu em 11/11/2026). FindFirstChild pega só o primeiro; o segundo dobra peças e tags.
 18. Dois Claude Code trabalham no mesmo place (o dono e o amigo). Antes de começar, leia o TOPO do ChangeLog para ver
     o que o outro fez; não desfaça mudanças recentes do outro sem registrar o motivo.
 12. Material de terreno: confira se o Enum.Material existe antes de usar (ex.: "CorrugatedMetal" NÃO existe
     como Material; use Enum.Material.Metal ou um MaterialVariant).
 19. (Beta 1.9) TEXTO DE JOGADOR: escreva em inglês e acrescente a tradução em Shared.Locale.pt. Cliente: UIKit.T("...%s", x)
     ou UIKit.Text (traduz sozinho). Servidor: Net.Fire(p, "Toast", Locale.For(p, "..."), ...). Nunca monte frase com "..".
 20. (Beta 1.9) UI NOVA usa Client.Platform: Platform.Apply(frame, "Overlay"|"Hud"|"Panel") em Frames (não em botões do UIKit,
     que já têm UIScale). No celular (Platform.IsCompact) troque o LAYOUT, não só o tamanho; deixe o centro da tela livre.
 21. (Beta 1.9) Números da 1.9 ficam em Shared.ConfigBeta19 (o Config o aplica no fim). Batalha: mexeu em Config.Battle.Classes
     ou .Sim? Rode os testes do GitHub (planejamento/beta-1.9/testes) para não quebrar o equilíbrio.
 22. (Beta 1.9) Antes de cada Play, confira a SINTAXE de todos os scripts (loadstring(script.Source) no execute_luau, modo
     Edit): um erro num módulo do cliente derruba os que dependem dele sem aviso claro.
 23. (Beta 1.9) Espelho para o GitHub sem Python: ServerStorage.Tools.MirrorDump + tools/place/mirror_from_dump.js.

  ESPECIALIDADES SUGERIDAS
   - Claude: arquitetura, sistemas, economia/balanceamento, UI, revisão e documentação.
   - Roblox Assistant: ajustes rápidos dentro do Studio, propriedades, pequenos scripts, materiais/iluminação.
   - Rebirth IA: conforme sua especialidade (combine com o time); sempre via ChangeLog.
]=]
return true
