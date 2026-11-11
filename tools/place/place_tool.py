"""place_tool.py — sincroniza o place do Roblox Studio com o repositório (Drive A Car For Anime).

USO (na raiz do repositório):
    python tools/place/place_tool.py extract  <arquivo.rbxl>   # reescreve src/ com os scripts do place
    python tools/place/place_tool.py summary  <arquivo.rbxl>   # árvore do Explorer + alertas (Map duplicado etc.)

FLUXO RECOMENDADO a cada versão Beta:
    1. Studio: Arquivo > "Baixar uma cópia" (.rbxl)  -> copie para places/DriveACarForAnime_<versão>_<data>.rbxl
    2. python tools/place/place_tool.py extract places/<arquivo>.rbxl
    3. git diff  (mostra exatamente o que mudou nos scripts, seja quem for que mudou: Claude, amigo, outro assistente)
    4. Atualize CHANGELOG.md e faça commit + tag (ex.: git tag beta-1.9)

O que é extraído (mesmas pastas do Explorer, formato compatível com Rojo):
    ServerScriptService, ReplicatedStorage, StarterPlayer, ServerStorage.ProjectDocs / Tools / LegacyCode
    Script -> .server.luau | LocalScript -> .client.luau | ModuleScript -> .luau
NÃO extrai: mapa, terreno, ServerStorage.Backups (ficam só no .rbxl — grandes demais e não são código).
"""
import collections
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rbxl  # noqa: E402

ROOTS = ["ServerScriptService", "ReplicatedStorage", "StarterPlayer",
         "ServerStorage.ProjectDocs", "ServerStorage.Tools", "ServerStorage.LegacyCode"]
SUFFIX = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}


def _in_roots(path):
    return any(path == r or path.startswith(r + ".") for r in ROOTS)


def extract(place, out="src"):
    root, _, problems, _ = rbxl.load(place)
    # recria só as pastas gerenciadas (não apaga nada fora delas)
    for r in ROOTS:
        d = os.path.join(out, *r.split("."))
        if os.path.isdir(d):
            shutil.rmtree(d)
    count = 0
    for n in root.descendants():
        if n.cls not in SUFFIX:
            continue
        path = n.path()
        if not _in_roots(path):
            continue
        parts = path.split(".")
        src = n.props.get("Source", "")
        if isinstance(src, bytes):
            src = src.decode("utf-8", "replace")
        if any(c.cls in SUFFIX for c in n.children):  # script com scripts dentro -> pasta + init
            rel = os.path.join(*parts, "init" + SUFFIX[n.cls])
        else:
            rel = os.path.join(*parts[:-1], parts[-1] + SUFFIX[n.cls])
        dst = os.path.join(out, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "w", encoding="utf-8", newline="\n") as f:
            f.write(src.replace("\r\n", "\n"))
        count += 1
    print(f"{count} scripts extraídos para {out}/")
    if problems:
        print("propriedades ignoradas:", sorted({(p[0], p[1]) for p in problems}))


def summary(place):
    root, _, problems, insts = rbxl.load(place)

    def size(n):
        return sum(1 for _ in n.descendants())

    print(f"{len(insts)} instâncias")
    for svc in root.children:
        total = size(svc)
        if total == 0:
            continue
        print(f"{svc.name} ({total})")
        for c in svc.children:
            print(f"   {c.name} [{c.cls}] {size(c)}")
    # alertas
    ws = root.find("Workspace")
    names = collections.Counter(c.name for c in ws.children)
    for name, k in names.items():
        if k > 1:
            print(f"ALERTA: Workspace tem {k} filhos chamados '{name}' (scripts usam workspace.{name} => pegam um ao acaso)")
    n_scripts = sum(1 for n in insts.values() if n.cls in SUFFIX)
    print(f"scripts no place (inclui backups): {n_scripts}")


if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] not in ("extract", "summary"):
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == "extract":
        extract(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "src")
    else:
        summary(sys.argv[2])
