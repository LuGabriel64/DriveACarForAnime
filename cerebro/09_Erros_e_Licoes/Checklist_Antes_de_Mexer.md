---
title: Checklist antes de mexer
date: 2026-11-14
tags: [erros, checklist, processo]
---

# Checklist antes de mexer

## Início da sessão
- [ ] Ler o [Mapa Cerebral](../00_Mapa_Cerebral.md) e as [Tarefas do dono](../13_Pendencias/Tarefas_do_Dono.md).
- [ ] `git pull` (sessões da nuvem e o amigo também fazem commit).
- [ ] `list_roblox_studios` (o `studio_id` muda) e conferir `Config.Version` + **topo do `01_ChangeLog` no place**.
- [ ] Conferir se não há **duplicatas na raiz do Workspace** (dois `Map`, dois `SpawnLocation`).
- [ ] Escolher o número da versão pelo ChangeLog do **place**, não pelo GitHub.

## Antes de editar
- [ ] Ler o cabeçalho do módulo e quem mudou por último.
- [ ] Backup em `ServerStorage.Backups["<versão anterior>"]` com LEIA-ME (mudança grande).
- [ ] Números novos só no Config / ConfigBeta19. Nenhuma chave pública renomeada.
- [ ] Texto novo de jogador: inglês + `Locale.pt`; formato `%s/%d`, nunca `..`.
- [ ] UI nova: UIKit + `Platform`; `Platform.Apply` só em Frames.
- [ ] Mudou o save? `defaults/reconcile/migrate` + `Version`.
- [ ] Antes de gerar mapa: clonar o Config (cache).

## Antes do Play
- [ ] **Checar a sintaxe de todos os scripts** (`loadstring(script.Source)` em modo Edit).
- [ ] Nunca `require` de `Services.*` durante o Play.
- [ ] Escolher a garagem clicando no menu (não destruir o StartMenu à mão).

## Ao terminar
- [ ] Output sem erros; anotar o que foi testado e o que **não** foi.
- [ ] `save_place` (não publica). Espelhar `src/` (MirrorDump + `mirror_from_dump.js`).
- [ ] ChangeLog no place + `CHANGELOG.md` + `estado-atual/` + este vault (+ cópia em `cerebro/`).
- [ ] Commit com `git -c user.name="Claude Code" -c user.email="noreply@anthropic.com"`; branch → main; tag se versão.

Relacionado: [Erros corrigidos](Erros_Corrigidos.md) · [Pegadinhas técnicas](Pegadinhas_Tecnicas.md) · [Convenções](../06_Codigo/Convencoes.md) · [Fluxo de versão](../10_Estrategias/Fluxo_de_Versao.md)
