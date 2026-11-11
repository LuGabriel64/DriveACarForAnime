--[=[
  GUIA DE DESIGN — BIOMA 1 "AZURE PLANET" + CORRIDA SOLO                                   Beta 1.2
  ======================================================================================================
  REGRA DE OURO: tudo ORIGINAL. Inspiração permitida = clima geral (planeta alienígena de guerreiros, vilas de
  domos, torneio de artes marciais, auras de energia). PROIBIDO: nomes, logos, esferas laranja com estrelas,
  empresas, personagens, roupas ou golpes reconhecíveis de qualquer anime. Isso derruba o jogo no Roblox.

  1. ELEMENTOS VISUAIS (já no mapa / onde ficam)
     - Grama azul, árvores de copa redonda azul, penhascos lilás em platôs, estrada de terra com cercas
       (Config.Biomes[1] + WorldBuilder PROP.bluetree / RoadSide "fence").
     - Casas-domo brancas com faixa neon e antena (PROP.domehouse) e VILAS de domos com lago (LANDMARK.pods).
     - Ilhas de pedra flutuando no céu (PROP.floatisland) — dão profundidade e "cara de outro planeta".
     - Arenas de torneio com tochas (LANDMARK.arena) e dojôs (LANDMARK.dojo) — tema artes marciais, genérico.
     - Pilares de cristal com aura subindo (LANDMARK.energyspire) — pontos de referência visíveis de longe.
     - Cogumelos laranja (PROP.mushroom) = contraste de cor que guia o olhar.
     Próximos (sugestão): cachoeira azul num platô, nave pousada como marco, pedras com runas originais brilhando.

  2. VEÍCULOS TEMÁTICOS (ideias de skins/tiers ORIGINAIS — adicionar em Config.Cars + CarFactory)
     - "Hover Pod": carro-disco arredondado, faixa neon, sem rodas visíveis (rodas escondidas sob a saia).
     - "Dome Runner": buggy com cúpula de vidro e antena igual às casas-domo (combina com a vila).
     - "Aura Striker": esportivo branco com spoiler alto e listras de energia azul (skin do Starter Hatch).
     - "Arena Cruiser": jipe de torneio com bandeirolas e tochas no capô (evento especial).

  3. PARTÍCULAS DE ENERGIA (aura) — já implementadas e onde
     - Aura no PRÓPRIO carro durante o boost (Client.CarVisuals, "BoostAura" + brilho).
     - Portal do lobby, pilares de cristal e centro das arenas (WorldBuilder energyAura).
     Sugestões: rastro de luz atrás do carro acima de 80% da velocidade; explosão de faíscas da cor da
     raridade ao chocar ovo raro; coluna de luz colorida nos ovos de estrada Legendary+.

  4. MECÂNICAS RÁPIDAS (dopamina a cada 10-20 s) — ordem sugerida de implementação
     a) ANÉIS DE ENERGIA: aros neon na pista; passar por dentro dá +1 de combo e um mini boost.
     b) COMBO METER: boost pads + anéis seguidos multiplicam o $ ganho na corrida (zera se bater).
     c) SALTO DAS ILHAS: rampas levando a ilhas flutuantes com um ovo de estrada em cima (risco x recompensa).
     d) FANTASMA DO RECORDE: grava o seu melhor percurso e mostra um carro translúcido seu correndo junto
        (combina com o modelo "pista fantasma"; nunca colide).
     e) CHECKPOINTS DE TEMPO: placas a cada 500 m com cronômetro parcial e recompensa por bater o recorde.
     f) NÚCLEOS DE ENERGIA: 5 cristais escondidos por bioma; juntar todos libera uma skin de aura (coleção).
     g) RANKING DIÁRIO de distância (OrderedDataStore) no lobby, ao lado do portal.

  5. RETENÇÃO (o que medir depois)
     - % de jogadores que fazem a 1ª corrida em < 60 s (portal visível do spawn ajuda).
     - Corridas por sessão e "RACE AGAIN" clicado; ovos chocados por corrida; tempo até o 2º carro.
]=]
return true
