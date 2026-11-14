---
title: Fluxo de versão
date: 2026-11-14
tags: [estrategia, processo, versao]
---

# Fluxo de versão

```mermaid
flowchart TD
  A[Pedido do dono] --> B[Conferir versão no topo do 01_ChangeLog do place]
  B --> C[Backup em ServerStorage.Backups versão anterior + LEIA-ME]
  C --> D[Editar no Studio via MCP, etapa por etapa]
  D --> E[Checar sintaxe + Play + Output]
  E --> F[Config.Version + Config.Updates]
  F --> G[01_ChangeLog no topo + 04_EstadoAtual + Bíblia se mudou estrutura]
  G --> H[save_place - não publica]
  H --> I[Espelho src/ via MirrorDump + mirror_from_dump.js]
  I --> J[CHANGELOG.md + estado-atual/ + CLAUDE.md]
  J --> K[Vault: nota da versão, sistemas, pedidos, erros, sessão + cópia em cerebro/]
  K --> L[Commit no branch → merge main → push → tag beta-X.Y]
  L --> M[Relatório ao dono: testado / não testado / tarefas dele]
```

- Numeração: 1.8 → 1.8b → 1.8c… ; mudança grande sobe o número (1.9, 2.0). Se a versão planejada já existir no place, use a seguinte.
- O `.rbxl` em `places/` e a publicação são do dono.

Relacionado: [Checklist antes de mexer](../09_Erros_e_Licoes/Checklist_Antes_de_Mexer.md) · [Linha do tempo](../07_Versoes/INDEX.md) · [Manter o vault](Manter_o_Vault.md)
