"""run_tests.py — roda os testes da Beta 1.9 FORA do Roblox (lógica pura).

USO (na raiz do repositório):   python planejamento/beta-1.9/testes/run_tests.py

O QUE FAZ
  1. Converte os .luau (rascunhos + o Config real de src/) para Lua 5.4 puro: só troca "a += b" por
     "a = a + (b)". O resto da sintaxe dos rascunhos já é compatível de propósito.
  2. Carrega a biblioteca Lua 5.4 do sistema (liblua5.4) por ctypes e roda test_beta19.lua, que:
       - executa de verdade: Config + ConfigBeta19, AnimeStats, BattleSim, Locale (parte pura) e a tabela pt
       - só COMPILA (confere sintaxe): VersusService, ProgressService, Platform — dependem do Roblox
  3. Sai com código 1 se algum teste falhar.

LIMITES: isto não substitui o teste no Studio. Serviços do Roblox são imitados (Color3, Vector3, Enum,
Random) só o bastante para os módulos puros rodarem. Precisa de liblua5.4 (Linux: já vem na maioria das
distros; Windows/macOS: rode os mesmos testes dentro do Studio ou com `lune`).
"""
import ctypes, ctypes.util, os, re, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DRAFT = os.path.join(HERE, "..", "rascunho")
SOURCES = {
    "Config": os.path.join(REPO, "src", "ReplicatedStorage", "Shared", "Config.luau"),
    "ConfigBeta19": os.path.join(DRAFT, "Shared", "ConfigBeta19.luau"),
    "AnimeStats": os.path.join(DRAFT, "Shared", "AnimeStats.luau"),
    "Locale": os.path.join(DRAFT, "Shared", "Locale", "init.luau"),
    "Locale_pt": os.path.join(DRAFT, "Shared", "Locale", "pt.luau"),
    "BattleSim": os.path.join(DRAFT, "Services", "BattleSim.luau"),
    "VersusService": os.path.join(DRAFT, "Services", "VersusService.luau"),
    "ProgressService": os.path.join(DRAFT, "Services", "ProgressService.luau"),
    "Platform": os.path.join(DRAFT, "Client", "Platform.luau"),
}
# "x += y" (até o fim da instrução) -> "x = x + (y)"
COMPOUND = re.compile(r"([A-Za-z_][\w\.]*(?:\[[^\]\n]*\])?)\s*(\.\.|[-+*/])=\s*([^;\n]*?)(?=\s+end\b|\s*;|\s*$)", re.M)


def to_lua54(src):
    return COMPOUND.sub(lambda m: f"{m.group(1)} = {m.group(1)} {m.group(2)} ({m.group(3)})", src)


def main():
    out = tempfile.mkdtemp(prefix="dacfa_tests_")
    for name, path in SOURCES.items():
        with open(path, encoding="utf-8") as f:
            code = to_lua54(f.read())
        with open(os.path.join(out, name + ".lua"), "w", encoding="utf-8") as f:
            f.write(code)
    lib = ctypes.CDLL(ctypes.util.find_library("lua5.4") or "liblua5.4.so.0")
    lib.luaL_newstate.restype = ctypes.c_void_p
    lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lib.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lib.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_long, ctypes.c_void_p]
    lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lib.lua_tolstring.restype = ctypes.c_char_p
    L = lib.luaL_newstate()
    lib.luaL_openlibs(L)
    test = (sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "test_beta19.lua")).replace("\\", "/")
    boot = f'MODULE_DIR = "{out.replace(chr(92), "/")}"; dofile("{test}")'
    status = lib.luaL_loadstring(L, boot.encode()) or lib.lua_pcallk(L, 0, 0, 0, 0, None)
    if status != 0:
        print("ERRO:", (lib.lua_tolstring(L, -1, None) or b"?").decode("utf-8", "replace"))
        sys.exit(1)


if __name__ == "__main__":
    main()
