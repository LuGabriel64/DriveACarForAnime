---
title: Save (DataService)
date: 2026-11-14
tags: [sistema, dados, save]
aliases: [DataService, DataStore]
---

# Save (DataService)

- DataStore `DACFA_Player_v1`, chave `P_<UserId>`, **trava de sessão** própria (sem ProfileService, para
  não usar código de terceiros do Toolbox). **Nunca trocar o StoreName** (apagaria os saves).
- `defaults()` / `reconcile()` / `migrate()` versionado. Autosave a cada 60 s e ao sair; `SaveNow` / `SaveSync`.
- `leaderstats.Cash` espelha o Cash.
- 1.8d (auditoria 5): `save()` devolve `ok and wrote` — se outro servidor tiver a trava, não confirma Robux sem gravar.
- 0.2.0: corrigido kick no Studio sem API (a mensagem real vem em minúsculas: "studio"/"API access"/"403").

## Versões do formato
| Version | Quando | O que entrou |
|---------|--------|--------------|
| 1 | 0.1.0 | Cash, CarId, Cars{Engine}, Animes, NextUid, PlotSlots, GiftClaimed, Index, Stats |
| 1 (+campos) | 1.1–1.7 | Settings, Stats.Hatches, Incubator, NextIncId, Stats.Escapes/EscapesLost, Wheel{LastSpin,Spins,Pending,Tokens,PendingSpins,Receipts} |
| 2 | 1.6 | migração dos Ids do bioma 1 (`Config.AnimeMigrations`) |
| 3 | 1.9 | Animes[i].Stars/Level/XP, Incubator[i].Stars, Partner, Lang, Wheel.Points, Versus{F1, Fx, Stats} |

**Regra:** mudou o formato? Atualize `defaults()`, `reconcile()` e `migrate()` e suba `Version`.
Listas não são preenchidas pelo `reconcile`: a migração percorre `Animes` e `Incubator`.

## Não testado
Migração com save real (o Studio usa dados temporários sem "Enable Studio Access to API Services").

Relacionado: [Anti-trapaça](Anti_Trapaca.md) · [Rede (Net)](Rede_Net.md) · [Convenções](../06_Codigo/Convencoes.md) · [Não testado](../13_Pendencias/Nao_Testado.md)
