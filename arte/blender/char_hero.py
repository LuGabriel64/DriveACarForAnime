"""
char_hero.py — personagens do bioma 1 esculpidos por SDF (Beta 2.0, TERCEIRA versão da arte de personagens, 16/11/2026).

  blender --background --python arte/blender/char_hero.py -- <pasta arte/> [gokun super mini_classic mini_violet] [opções]
  opções:  lod=0.35  versão de JOGO (35% dos triângulos; arquivos com sufixo _game, sem vídeo)
           novideo   não renderiza o vídeo das animações        nodetail  não renderiza os closes de rosto e mão

O que sai (em arte/export/ e arte/renders/):
  gokun_v3.fbx                lutador adulto, cabelo preto espetado            (Common)
  super_gokun_v3.fbx          mesmo corpo, cabelo dourado para cima + aura      (Secret)
  mini_gokun_v3_classic.fbx / mini_gokun_v3_violet.fbx   versão mirim na nuvem (Épico, 2 skins; companheiro dos carros)
  <id>_game.fbx               as mesmas quatro, leves (24 a 27 mil triângulos), para importar no Roblox
  personagens.json            peças, triângulos, juntas (pivôs) e escala de cada um
  personagens_anim.json       animações de parado (pose + ondas), em studs; vira Shared.CharacterAnims com tools/art/anims_to_luau.js
  renders/<id>.png, <id>_idle.png, gokun_v3_detalhes.png, idle_personagens.mp4

Um corpo só é esculpido (em metros, pés em z = 0, frente = -Y) e reaproveitado:
  * adulto: cabeça 10% maior (proporção de anime);
  * mirim: as MESMAS peças, achatadas por peça (cabeça grande, tronco e membros curtos; mãos sem achatar).
Peças rígidas (MeshParts animados por código no Roblox, Shared.CharacterRig):
  Head, Hair, Torso, ArmL, ForeL, ArmR, ForeR, LegL, ShinL, LegR, ShinR  (+ Tail, Staff, Cloud, Smoke no mirim; + Aura no Super).
  Cotovelo e joelho têm uma esfera por dentro, para a dobra não abrir buraco.

v3 (pedido do dono em 16/11): rosto mais fino de anime (olhos grandes, queixo pequeno, sorriso, franja, orelha grande,
pescoço à mostra), mãos com dedos, nós, polegar e tendões, e as animações de parado (tabela IDLE).

Estilo: anime 2.5D com cel-shading PINTADO nos vértices (dois tons, sombra projetada, linhas nos vincos).
Modelos próprios: sem emblemas, sem kanji, nada baixado da web.
Versões antigas GUARDADAS: arte/arquivo/personagens_v1/ (blocos) e arte/arquivo/personagens_v2/ (primeira escultura).
"""
import hashlib
import inspect
import json
import math
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh
import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

import f1lib as L
import sdflib as S
from sdflib import cone, cut, ell, rbox, smax, smin

F32 = np.float32


def rgb(r, g, b):
    return (r / 255.0, g / 255.0, b / 255.0)


# ----------------------------------------------------------------------------- paletas (base, sombra, linha)

INK = rgb(18, 14, 20)


def palette(gi, gi_sh, under, under_sh, hair="black", eye=rgb(20, 20, 26)):
    p = {
        "skin": dict(base=rgb(255, 208, 168), shadow=rgb(228, 150, 118), line=rgb(112, 54, 40)),
        "gi": dict(base=gi, shadow=gi_sh, line=tuple(c * 0.42 for c in gi_sh)),
        "under": dict(base=under, shadow=under_sh, line=tuple(c * 0.35 for c in under_sh)),
        "boot": dict(base=rgb(40, 50, 128), shadow=rgb(22, 26, 74), line=rgb(8, 10, 30)),
        "trim": dict(base=rgb(220, 58, 58), shadow=rgb(150, 28, 36), line=rgb(70, 10, 16)),
        "sole": dict(base=rgb(240, 228, 204), shadow=rgb(188, 168, 140), line=rgb(96, 80, 60)),
        "cord": dict(base=rgb(244, 204, 80), shadow=rgb(200, 140, 40), line=rgb(110, 70, 16)),
        "white": dict(base=rgb(250, 250, 250)),
        "ink": dict(base=INK),
        "eye": dict(base=eye),
        "lip": dict(base=rgb(214, 132, 104)),
        "tail": dict(base=rgb(128, 74, 38), shadow=rgb(84, 44, 22), line=rgb(40, 20, 10)),
        "staff": dict(base=rgb(226, 48, 44), shadow=rgb(150, 24, 30), line=rgb(70, 10, 14)),
        "cloud": dict(base=rgb(255, 224, 108), shadow=rgb(245, 158, 50), line=rgb(190, 96, 24), high=rgb(255, 251, 220), high_at=0.8, thresh=0.22),
        "aura": dict(base=rgb(255, 236, 130)),
    }
    if hair == "black":
        p["hair"] = dict(base=rgb(36, 36, 48), shadow=rgb(13, 13, 19), line=rgb(0, 0, 0), high=rgb(78, 82, 116), high_at=0.9, thresh=0.25)
    else:
        p["hair"] = dict(base=rgb(255, 228, 100), shadow=rgb(240, 164, 44), line=rgb(170, 96, 16), high=rgb(255, 244, 170), high_at=0.95, thresh=0.12)
    return p


PAL_CLASSIC = palette(rgb(248, 134, 28), rgb(204, 82, 18), rgb(46, 62, 152), rgb(26, 32, 92))
PAL_SUPER = palette(rgb(248, 134, 28), rgb(204, 82, 18), rgb(46, 62, 152), rgb(26, 32, 92), hair="gold", eye=rgb(36, 196, 176))
PAL_VIOLET = palette(rgb(134, 110, 214), rgb(84, 62, 160), rgb(206, 50, 50), rgb(134, 26, 34))
PAL_VIOLET["cloud"] = dict(base=rgb(196, 236, 214), shadow=rgb(112, 178, 170), line=rgb(60, 112, 116), high=rgb(250, 255, 250), high_at=0.9, thresh=0.3)

LIGHT = (-0.7, -0.45, 0.55)      # luz principal: de cima, pela esquerda de quem olha (sombra no lado direito das formas)
BACK = (0.6, 0.7, 0.4)          # contraluz

# juntas do corpo adulto (metros)
NECK = (0.0, 0.005, 1.555)
SHO = (0.205, 0.0, 1.475)
ELB = (0.283, 0.005, 1.185)
WRI = (0.327, -0.046, 0.939)
HIP = (0.095, 0.0, 0.95)
KNEE = (0.105, -0.012, 0.52)
HEAD_LIFT = 0.024                                 # v3: a cabeça sobe 3 cm (pescoço à mostra, queixo longe do peito)
NECKH = (NECK[0], NECK[1], NECK[2] + HEAD_LIFT)   # pivô da cabeça depois de subir

# ----------------------------------------------------------------------------- cache das esculturas

CACHE = os.path.join(tempfile.gettempdir(), "dacfa_sdf_cache")


LOD = 1.0        # fator dos orçamentos de triângulos: 1.0 = vitrine; "lod=0.35" na linha de comando = versão de jogo


def cached(*deps):
    """A escultura demora; guarda o resultado num .npz que se invalida quando o código da função (ou de deps) muda."""
    def deco(fn):
        return _cached(fn, deps)
    return deco


def _cached(fn, deps):
    def run():
        src = inspect.getsource(fn) + "".join(inspect.getsource(d) for d in deps) + inspect.getsource(S) + f"lod{LOD}"
        key = hashlib.md5(src.encode("utf-8")).hexdigest()[:12]
        path = os.path.join(CACHE, f"{fn.__name__}_{key}.npz")
        if os.path.exists(path):
            d = np.load(path, allow_pickle=True)
            meta = json.loads(str(d["meta"]))
            return [S.Shell(m["role"], m["mat"], d[f"V{i}"], d[f"T{i}"], d[f"L{i}"], m["flat"], m["unlit"], m["cast"]) for i, m in enumerate(meta)]
        shells = fn()
        os.makedirs(CACHE, exist_ok=True)
        arrs = {}
        for i, s in enumerate(shells):
            arrs[f"V{i}"], arrs[f"T{i}"], arrs[f"L{i}"] = s.V, s.T, s.line
        meta = [dict(role=s.role, mat=s.mat, flat=s.flat, unlit=s.unlit, cast=s.cast) for s in shells]
        np.savez_compressed(path, meta=json.dumps(meta), **arrs)
        return shells
    run.__name__ = fn.__name__
    return run


def shell_from(F, G, role, mat, tris, lo=50.0, hi=150.0, cav=None):
    """cav = campo usado para achar os vincos (linhas); por padrão o próprio F. Peças cortadas num plano passam o campo inteiro."""
    V, T = S.mesh(F, G, max(int(tris * LOD), 120))
    return S.Shell(role, mat, V, T, S.cavity(F if cav is None else cav, G, V, lo, hi, step=2))


# ----------------------------------------------------------------------------- CABEÇA


def head_field(G):
    """v3 (16/11): rosto de anime. Crânio grande e redondo, bochecha larga na altura do olho, queixo pequeno e fino,
    órbita rasa e grande, nariz mínimo, orelha grande e pescoço fino (a v2 tinha mandíbula quadrada e pescoço de touro)."""
    P, M = G.P, G.M
    cran = ell(P, (0, 0.014, 1.716), (0.087, 0.101, 0.094))
    face = cone(P, (0, -0.02, 1.683), (0, -0.052, 1.612), 0.071, 0.024)                 # rosto em V
    h = smin(cran, face, 0.035)
    h = smin(h, ell(M, (0.046, -0.03, 1.662), (0.028, 0.04, 0.028)), 0.03)              # bochecha
    h = smin(h, ell(P, (0, -0.063, 1.603), (0.017, 0.016, 0.013)), 0.024)               # queixo pequeno
    h = cut(h, ell(M, (0.04, -0.107, 1.69), (0.03, 0.014, 0.023)), 0.012)               # órbita rasa e grande
    h = smin(h, cone(P, (0, -0.088, 1.676), (0, -0.098, 1.664), 0.004, 0.0055), 0.006)  # nariz mínimo
    ear = ell(M, (0.092, 0.012, 1.668), (0.013, 0.022, 0.035), S.euler(rz=-24))
    ear = cut(ear, ell(M, (0.103, 0.0, 1.668), (0.008, 0.013, 0.023)), 0.003)
    h = smin(h, ear, 0.005)
    h = smin(h, cone(P, (0, 0.014, 1.535), (0, 0.01, 1.64), 0.038, 0.04), 0.014)        # toco do pescoço (fica dentro do pescoço do tronco)
    return h


def circle(c, r, n=12):
    return [(c[0] + r * math.cos(2 * math.pi * i / n), c[1] + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def decal(poly, bvh, layer, mat, cuts=2, mirror=False):
    """Desenho do rosto: polígono em vista frontal (x, z) projetado na pele, um pouco à frente dela."""
    out = []
    for sgn in ((1, -1) if mirror else (1,)):
        bm = bmesh.new()
        vs = [bm.verts.new((sgn * x, -0.5, z)) for x, z in poly]
        f = bm.faces.new(vs)
        res = bmesh.ops.triangulate(bm, faces=[f])
        if cuts:
            bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
            bmesh.ops.triangulate(bm, faces=bm.faces[:])
        for v in bm.verts:
            hit = bvh.ray_cast(v.co, (0, 1, 0))
            if hit[0] is not None:
                v.co = hit[0]
            else:
                v.co.y = -0.09
            v.co.y -= 0.0012 * layer
        bm.verts.index_update()
        V = np.array([v.co[:] for v in bm.verts], dtype=F32)
        T = np.array([[v.index for v in f.verts] for f in bm.faces], dtype=np.int32)
        bm.free()
        n = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
        flip = n[:, 1] > 0
        T[flip] = T[flip][:, ::-1]
        out.append(S.Shell("Head", mat, V, T, unlit=True, cast=False))
    return out


@cached(head_field)
def sculpt_head_skin():
    G = S.Grid((-0.125, -0.14, 1.53), (0.125, 0.13, 1.82), 0.0032)
    return [shell_from(head_field(G), G, "Head", "skin", 9000, lo=150.0, hi=340.0)]


def sculpt_head(mood="grin"):
    """Pele (em cache) + o desenho do rosto. mood: "grin" (sorriso com dentes, Gokun e Mini) ou "serious" (Super)."""
    skin = sculpt_head_skin()[0].copy()
    bvh = BVHTree.FromPolygons(skin.V.tolist(), skin.T.tolist())
    sh = [skin]
    # sobrancelha grossa em cunha, descendo para o nariz e quase encostando no olho
    sh += decal([(0.005, 1.7045), (0.011, 1.7195), (0.036, 1.7315), (0.064, 1.7365), (0.0755, 1.7305), (0.063, 1.7215), (0.036, 1.7135), (0.013, 1.7005)], bvh, 6, "ink", mirror=True)
    # olho grande e alto: branco, cílio de cima grosso, pupila, brilho, linha de baixo
    sh += decal([(0.012, 1.672), (0.012, 1.7), (0.024, 1.711), (0.058, 1.713), (0.068, 1.703), (0.069, 1.682), (0.06, 1.67), (0.026, 1.667)], bvh, 1, "white", mirror=True)
    sh += decal([(0.008, 1.696), (0.022, 1.7145), (0.058, 1.7175), (0.0735, 1.705), (0.074, 1.69), (0.0695, 1.701), (0.057, 1.7115), (0.025, 1.709), (0.013, 1.697)], bvh, 4, "ink", mirror=True)
    sh += decal(circle((0.0345, 1.6905), 0.0125, 16), bvh, 2, "eye", cuts=1, mirror=True)
    sh += decal(circle((0.0345, 1.6905), 0.0066, 10), bvh, 3, "ink", cuts=0, mirror=True)
    sh += decal(circle((0.0302, 1.6952), 0.0037, 8), bvh, 5, "white", cuts=0, mirror=True)
    sh += decal([(0.024, 1.6665), (0.06, 1.6695), (0.069, 1.68), (0.0705, 1.679), (0.061, 1.6675), (0.024, 1.6645)], bvh, 4, "ink", mirror=True)
    # nariz: um risco
    sh += decal([(-0.002, 1.6612), (0.006, 1.6627), (0.005, 1.6604), (-0.0015, 1.6594)], bvh, 2, "ink", cuts=1)
    if mood == "grin":
        sh += decal([(-0.027, 1.6425), (-0.011, 1.6442), (0.011, 1.6442), (0.027, 1.6425), (0.023, 1.6295), (0.012, 1.6232), (-0.012, 1.6232), (-0.023, 1.6295)], bvh, 2, "ink")
        sh += decal([(-0.0242, 1.6406), (-0.011, 1.642), (0.011, 1.642), (0.0242, 1.6406), (0.0206, 1.6305), (0.0112, 1.6254), (-0.0112, 1.6254), (-0.0206, 1.6305)], bvh, 3, "white")
        sh += decal([(-0.0232, 1.6345), (0.0232, 1.6345), (0.0232, 1.6333), (-0.0232, 1.6333)], bvh, 4, "ink", cuts=1)
    else:
        sh += decal([(-0.014, 1.631), (-0.005, 1.632), (0.005, 1.632), (0.014, 1.631), (0.014, 1.6294), (0.005, 1.6302), (-0.005, 1.6302), (-0.014, 1.6294)], bvh, 2, "ink")
        sh += decal([(-0.008, 1.6215), (0.008, 1.6215), (0.0055, 1.6197), (-0.0055, 1.6197)], bvh, 2, "lip", cuts=1)
    return sh


# ----------------------------------------------------------------------------- CABELO (mechas facetadas)

HC = np.array((0.0, 0.018, 1.712), dtype=F32)
HR = 0.097
HC1 = np.array(NECKH, dtype=F32) + (HC - np.array(NECK, dtype=F32)) * 1.1   # depois do aumento de 10% e da subida da cabeça


def lock(tip, w, root=None, t=None, n=7, sag=0.0, role="Hair", mat="hair", origin=None, base_r=None):
    """Mecha afiada: seção em losango ao longo de uma curva, do couro cabeludo até a ponta."""
    c0 = HC if origin is None else np.asarray(origin, dtype=F32)
    tip = np.asarray(tip, dtype=F32)
    rd = np.asarray(root if root is not None else tip, dtype=F32)
    rd = rd / np.linalg.norm(rd)
    p0 = c0 + rd * ((HR if base_r is None else base_r) * 0.72)
    p2 = c0 + tip
    Lg = float(np.linalg.norm(p2 - p0))
    p1 = p0 + rd * Lg * 0.45 + (p2 - p0) * 0.25 + np.array((0, 0, -sag), dtype=F32)
    t = w * 0.62 if t is None else t
    # a largura da mecha fica no plano de quem olha de frente (silhueta 2D); mechas que apontam para a frente/trás usam o eixo Z
    ref = np.array((0, 0, 1), dtype=F32) if abs(float(rd[1])) > 0.6 else np.array((0, -1, 0), dtype=F32)
    V = []
    for i in range(n):
        s = i / n
        c = (1 - s) ** 2 * p0 + 2 * s * (1 - s) * p1 + s * s * p2
        tan = 2 * (1 - s) * (p1 - p0) + 2 * s * (p2 - p1)
        tan = tan / np.linalg.norm(tan)
        side = np.cross(tan, ref)
        side = side / max(float(np.linalg.norm(side)), 1e-6)
        up = np.cross(side, tan)
        k = (1 - s) ** 0.8 * (1.0 + 0.22 * math.sin(math.pi * min(s * 3.0, 1.0)))
        V += [c + side * w * k, c + up * t * k, c - side * w * k, c - up * t * 0.8 * k]
    V.append(p2)
    T = [(0, 1, 2), (0, 2, 3)]
    for i in range(n - 1):
        for k in range(4):
            a, b = i * 4 + k, i * 4 + (k + 1) % 4
            T += [(a, b, b + 4), (a, b + 4, a + 4)]
    last = (n - 1) * 4
    for k in range(4):
        T.append((last + k, last + (k + 1) % 4, n * 4))
    V, T = np.array(V, dtype=F32), np.array(T, dtype=np.int32)
    cen = V.mean(axis=0)
    vol = np.einsum("ij,ij->i", V[T[:, 0]] - cen, np.cross(V[T[:, 1]] - cen, V[T[:, 2]] - cen)).sum()
    if vol < 0:
        T = T[:, ::-1].copy()
    return S.Shell(role, mat, V, T, flat=True)


def prim_shell(piece, role, mat, flat=False):
    verts, faces = piece
    T = []
    for f in faces:
        for i in range(1, len(f) - 1):
            T.append((f[0], f[i], f[i + 1]))
    return S.Shell(role, mat, np.array(verts, dtype=F32), np.array(T, dtype=np.int32), flat=flat)


def scalp():
    return prim_shell(L.sphere((0, 0.03, 1.73), 0.104, 20, 12, (1.0, 1.02, 0.97)), "Hair", "hair")


def hair_base():
    sh = [scalp()]
    big = [  # (ponta relativa ao centro da cabeça, largura)
        ((-0.105, -0.05, 0.265), 0.055), ((0.135, -0.005, 0.245), 0.052),      # topo
        ((0.275, 0.0, 0.135), 0.05), ((0.265, 0.045, -0.02), 0.044),           # lado direito da imagem
        ((-0.285, -0.015, 0.16), 0.056), ((-0.305, 0.025, 0.02), 0.05), ((-0.215, 0.07, -0.105), 0.04),
        ((0.02, 0.2, 0.245), 0.056), ((-0.185, 0.25, 0.085), 0.05), ((0.2, 0.245, 0.065), 0.05), ((0.0, 0.25, -0.075), 0.05),
        ((0.02, -0.02, 0.21), 0.05),
    ]
    for tip, w in big:
        sh.append(lock(tip, w))
    # franja (v3): mechas que nascem no alto da testa e caem por cima dela, a maior até entre as sobrancelhas
    for tip, root, w in (((-0.014, -0.116, 0.012), (0.1, -0.62, 0.78), 0.036), ((0.045, -0.112, 0.04), (0.34, -0.6, 0.72), 0.03),
                         ((-0.06, -0.11, 0.036), (-0.36, -0.6, 0.72), 0.032), ((0.088, -0.086, 0.012), (0.72, -0.46, 0.52), 0.028),
                         ((-0.096, -0.08, 0.006), (-0.74, -0.44, 0.5), 0.028)):
        sh.append(lock(tip, w, root=root, t=0.014, n=6, sag=-0.012, base_r=0.146))
    return sh


def hair_super():
    sh = [scalp()]
    ups = [((-0.03, -0.045, 0.31), 0.052), ((0.065, -0.01, 0.345), 0.055), ((-0.11, 0.01, 0.275), 0.05), ((0.14, 0.02, 0.26), 0.05),
           ((0.0, 0.075, 0.32), 0.056), ((-0.075, 0.115, 0.25), 0.05), ((0.09, 0.12, 0.24), 0.05), ((-0.165, 0.03, 0.18), 0.045),
           ((0.185, 0.04, 0.17), 0.045), ((0.0, 0.17, 0.17), 0.05), ((-0.19, 0.05, 0.07), 0.04), ((0.2, 0.055, 0.06), 0.04),
           ((-0.11, 0.2, 0.08), 0.045), ((0.12, 0.2, 0.07), 0.045)]
    for tip, w in ups:
        rd = (tip[0] * 1.6, tip[1] * 1.3 + 0.01, max(tip[2], 0.05) * 0.6)
        sh.append(lock(tip, w, root=rd, sag=0.03))
    sh.append(lock((0.022, -0.116, 0.01), 0.024, root=(0.14, -0.62, 0.78), t=0.012, n=6, sag=-0.012, base_r=0.146))
    sh.append(lock((-0.05, -0.108, 0.05), 0.024, root=(-0.3, -0.6, 0.74), t=0.012, n=6, sag=-0.012, base_r=0.146))
    return sh


def aura():
    """Chamas da aura do Super: mechas grandes subindo em volta do corpo (peça à parte, translúcida)."""
    rng = np.random.default_rng(7)
    sh = []
    for i in range(20):                                   # só atrás e dos lados: a aura não pode tapar o personagem
        a = math.radians(-12 + 204 * i / 19) + rng.uniform(-0.06, 0.06)
        r0 = 0.44 + rng.uniform(-0.04, 0.08)
        base = np.array((r0 * math.cos(a), 0.06 + r0 * math.sin(a) * 0.7, rng.uniform(0.0, 0.5)))
        h = rng.uniform(1.2, 2.1)
        tip = np.array((base[0] * rng.uniform(0.5, 0.9), base[1] * rng.uniform(0.6, 0.9), base[2] + h))
        s = lock(tip - base, rng.uniform(0.07, 0.12), root=(base[0], base[1], 0.9), t=0.03, n=7, sag=-0.1, role="Aura", mat="aura", origin=base, base_r=0.0)
        s.unlit, s.cast = True, False
        sh.append(s)
    return sh


# ----------------------------------------------------------------------------- TRONCO


@cached()
def sculpt_torso():
    G = S.Grid((-0.29, -0.19, 0.76), (0.29, 0.18, 1.67), 0.005)
    P, M = G.P, G.M
    X, Y, Z = P
    AX = M[0]
    rib = ell(P, (0, 0, 1.31), (0.168, 0.112, 0.19))
    waist = ell(P, (0, 0, 1.10), (0.128, 0.092, 0.13))
    pelvis = ell(P, (0, 0.005, 0.975), (0.16, 0.112, 0.10))
    core = smin(smin(rib, waist, 0.05), pelvis, 0.05)
    core = smin(core, cone(M, (0, 0, 1.465), (0.185, 0.0, 1.472), 0.075, 0.058), 0.04)
    pec = ell(M, (0.088, -0.072, 1.362), (0.098, 0.058, 0.075), S.euler(ry=8))
    lat = ell(M, (0.145, 0.03, 1.28), (0.055, 0.07, 0.15))
    trap = cone(M, (0.03, 0.02, 1.562), (0.165, 0.012, 1.497), 0.04, 0.038)
    neck = cone(P, (0, 0.012, 1.47), (0, 0.006, 1.615), 0.053, 0.046)             # v3: pescoço mais fino e mais comprido

    soft = smin(smin(smin(core, pec, 0.04), lat, 0.04), trap, 0.03)           # volume para a roupa

    skin = smin(smin(core, lat, 0.03), trap, 0.02)
    skin = smin(skin, neck, 0.02)
    skin = smin(skin, pec, 0.011)
    skin = smin(skin, cone(M, (0.014, -0.083, 1.49), (0.176, -0.034, 1.506), 0.011, 0.012), 0.006)   # clavícula
    skin = smin(skin, cone(M, (0.012, -0.056, 1.488), (0.04, 0.012, 1.62), 0.009, 0.011), 0.006)     # esternocleidomastoideo
    skin = smin(skin, ell(P, (0, -0.046, 1.563), (0.01, 0.009, 0.013)), 0.006)                         # pomo de adão
    skin = smax(skin, 1.2 - Z, 0.005)
    sh = [shell_from(skin, G, "Torso", "skin", 3200, lo=60.0, hi=180.0)]

    arm_cut = np.minimum(AX - (0.236 + 0.3 * (Z - 1.47)), Z - 1.385)
    # camiseta de baixo
    under = soft - 0.008
    under = smax(under, Z - (1.478 + 0.25 * Y), 0.004)
    under = cut(under, ell(P, (0, -0.012, 1.53), (0.074, 0.074, 0.06)))
    under = smax(under, arm_cut + 0.006, 0.005)
    under = smax(under, 1.17 - Z, 0.004)
    sh.append(shell_from(under, G, "Torso", "under", 1600))

    # quimono (parte de cima), com gola em V, ombreira e dobras
    gi = soft - 0.019
    gi = smin(gi, ell(M, (0.182, 0.0, 1.49), (0.072, 0.086, 0.046)), 0.02)
    fr = [(-0.15, 1.11, -0.03, 1.055, 0.039, 0.0133), (0.16, 1.13, 0.05, 1.065, 0.039, 0.0133), (-0.17, 1.26, -0.07, 1.14, 0.047, 0.0133),
          (0.18, 1.28, 0.09, 1.16, 0.047, 0.0133), (-0.2, 1.43, -0.125, 1.3, 0.039, 0.0114), (0.2, 1.44, 0.135, 1.31, 0.039, 0.0114),
          (-0.06, 1.18, -0.15, 1.2, 0.033, 0.0095)]
    bk = [(-0.13, 1.12, 0.0, 1.06, 0.039, 0.0133), (0.15, 1.15, 0.03, 1.075, 0.039, 0.0133), (-0.16, 1.4, -0.05, 1.25, 0.047, 0.0133),
          (0.16, 1.4, 0.05, 1.25, 0.047, 0.0133), (-0.02, 1.36, 0.03, 1.16, 0.039, 0.0095)]
    gi = gi - S.strokes(P, fr, front=True) - S.strokes(P, bk, front=False)
    gi = cut(gi, ell(P, (0, -0.012, 1.575), (0.082, 0.078, 0.07)))
    gi = smax(gi, arm_cut, 0.006)
    gi = smax(gi, 1.0 - Z, 0.004)
    full = gi
    a = math.atan(0.40)
    zv = 1.235
    w = AX * math.cos(a) - (Z - zv) * math.sin(a)
    wedge = np.maximum(w, Y - 0.02)
    gi = cut(gi, wedge, 0.004)
    band = np.maximum(np.maximum(np.abs(w - 0.018) - 0.018, full - 0.008), Y - 0.02)
    # a lapela esquerda (x > 0) cruza por cima e desce até a faixa
    wl = X * math.cos(a) - (Z - zv) * math.sin(a)
    cross = np.maximum(np.maximum(np.abs(wl - 0.018) - 0.018, full - 0.011), np.maximum(Y - 0.02, Z - (zv + 0.03)))
    gi = smin(smin(gi, band, 0.003), cross, 0.003)
    sh.append(shell_from(gi, G, "Torso", "gi", 6500))

    # faixa com nó e duas pontas
    belt = smax(soft - 0.027, np.abs(Z - 1.03) - 0.036, 0.008)
    belt = belt - 0.003 * np.abs(np.sin(Z * 95.0 + X * 9.0))
    knot = ell(P, (0.045, -0.128, 1.03), (0.03, 0.022, 0.028))
    belt = smin(belt, knot, 0.006)
    belt = smin(belt, ell(P, (0.07, -0.135, 0.925), (0.024, 0.009, 0.105), S.euler(ry=-10, rx=4)), 0.004)
    belt = smin(belt, ell(P, (0.022, -0.137, 0.935), (0.022, 0.009, 0.095), S.euler(ry=9, rx=3)), 0.004)
    sh.append(shell_from(belt, G, "Torso", "under", 1700))

    # quadril da calça (a perna encaixa por baixo)
    hip = smin(pelvis, cone(M, (0.095, 0, 0.955), (0.1, -0.004, 0.8), 0.09, 0.08), 0.04) - 0.008
    hip = hip - S.strokes(M, [(0.0, 0.905, 0.13, 0.965, 0.039, 0.0114), (0.02, 0.86, 0.17, 0.9, 0.039, 0.0114)], front=True)
    hip = smax(smax(hip, Z - 1.012, 0.004), 0.81 - Z, 0.004)
    sh.append(shell_from(hip, G, "Torso", "gi", 1500))
    return sh


# ----------------------------------------------------------------------------- BRAÇO (esquerdo do modelo, x > 0)


def hand_frame():
    """Eixos da mão esquerda em repouso: colunas = (b costas da mão, c lado do polegar, d ao longo do antebraço); origem no pulso."""
    E, W = S.v3(ELB), S.v3(WRI)
    d = (W - E) / np.linalg.norm(W - E)
    b = S.v3((1, 0, 0)) - d * d[0]
    b = b / np.linalg.norm(b)
    c = np.cross(d, b)
    return W, np.stack([b, c, d], axis=1)


def hand_field(PL):
    """Punho fechado (v3), no espaço local da mão. PL = (b, c, a): a = ao longo do antebraço (0 no pulso),
    b = costas da mão (+) / palma (-), c = polegar (+) / mindinho (-). Quatro dedos dobrados com nó, polegar por cima,
    tendões nas costas da mão e o osso do pulso; a união com k pequeno deixa o sulco entre os dedos (vira linha)."""
    def q(a, b, c):
        return (b, c, a)
    f = cone(PL, q(-0.06, 0.0, 0.0), q(0.004, 0.0, 0.0), 0.034, 0.031)                 # pulso
    f = smin(f, rbox(PL, q(0.047, 0.006, 0.0), (0.017, 0.04, 0.042), 0.013), 0.012)    # costas da mão
    f = smin(f, ell(PL, q(0.05, -0.014, 0.0), (0.02, 0.036, 0.04)), 0.01)              # palma
    fing = None
    for c, r, da in ((0.032, 0.0108, 0.002), (0.0105, 0.0112, 0.005), (-0.011, 0.0106, 0.002), (-0.031, 0.0094, -0.004)):
        kn, p1, p2 = q(0.088 + da, 0.013, c), q(0.094 + da, -0.027, c), q(0.055 + da, -0.036, c)
        g = np.minimum(cone(PL, kn, p1, r * 1.08, r), cone(PL, p1, p2, r, r * 0.92))
        g = smin(g, ell(PL, kn, (r * 1.12, r * 1.12, r * 1.12)), 0.003)                # nó do dedo
        fing = g if fing is None else smin(fing, g, 0.0022)                            # sulco entre os dedos
        f = smin(f, cone(PL, q(0.082 + da, 0.0225, c), q(0.012, 0.02, c * 0.45), 0.0036, 0.003), 0.004)   # tendão
    f = smin(f, fing, 0.006)
    th = smin(cone(PL, q(0.012, -0.008, 0.036), q(0.058, -0.03, 0.047), 0.016, 0.013),
              cone(PL, q(0.058, -0.03, 0.047), q(0.088, -0.043, 0.018), 0.0125, 0.0105), 0.004)   # polegar por cima dos dedos
    f = smin(f, th, 0.004)
    f = smin(f, ell(PL, q(-0.004, 0.021, -0.024), (0.009, 0.009, 0.01)), 0.006)       # osso do pulso
    return f


@cached(hand_field, hand_frame)
def sculpt_hand():
    W, H = hand_frame()
    ctr = W + H[:, 2] * 0.045
    G = S.Grid(tuple(float(v) for v in ctr - 0.09), tuple(float(v) for v in ctr + 0.09), 0.0024)
    PL = S._local(G.P, W, H)
    return [shell_from(hand_field(PL), G, "ForeL", "skin", 4200, lo=90.0, hi=260.0)]


@cached()
def sculpt_arm():
    """Braço em duas peças rígidas (v3): ArmL (ombro ao cotovelo) e ForeL (cotovelo ao pulso), com uma esfera no cotovelo
    para a dobra não abrir buraco. A mão é outra casca (sculpt_hand), que entra por dentro da munhequeira."""
    G = S.Grid((0.11, -0.15, 0.86), (0.43, 0.12, 1.6), 0.0042)
    P = G.P
    Sv, E, W = S.v3(SHO), S.v3(ELB), S.v3(WRI)
    u1 = (E - Sv) / np.linalg.norm(E - Sv)
    u2 = (W - E) / np.linalg.norm(W - E)
    R1, R2 = S.frame_z(u1), S.frame_z(u2)
    upper = cone(P, Sv, E, 0.052, 0.04)
    delt = ell(P, (0.24, 0.0, 1.452), (0.074, 0.08, 0.092), R1)
    arm = smin(upper, delt, 0.012)
    arm = smin(arm, ell(P, (0.243, -0.027, 1.33), (0.05, 0.054, 0.11), R1), 0.007)    # bíceps
    arm = smin(arm, ell(P, (0.254, 0.034, 1.322), (0.05, 0.05, 0.12), R1), 0.007)   # tríceps
    arm = smin(arm, ell(P, E, (0.04, 0.042, 0.04)), 0.015)
    arm = smin(arm, cone(P, E, W, 0.049, 0.033), 0.015)
    arm = smin(arm, ell(P, E + 0.28 * (W - E) + S.v3((0.01, -0.008, 0.0)), (0.046, 0.05, 0.086), R2), 0.007)   # antebraço (braquiorradial)
    arm = smin(arm, ell(P, E + 0.3 * (W - E) + S.v3((-0.012, 0.014, 0.0)), (0.034, 0.036, 0.075), R2), 0.007)    # flexores
    along2 = (P[0] - E[0]) * u2[0] + (P[1] - E[1]) * u2[1] + (P[2] - E[2]) * u2[2]
    arm = smax(arm, along2 - (float(np.linalg.norm(W - E)) - 0.012), 0.003)           # termina dentro da munhequeira
    n = (u1 + u2) / np.linalg.norm(u1 + u2)
    cutp = (P[0] - E[0]) * n[0] + (P[1] - E[1]) * n[1] + (P[2] - E[2]) * n[2]
    dE = np.sqrt((P[0] - E[0]) ** 2 + (P[1] - E[1]) ** 2 + (P[2] - E[2]) ** 2)
    up = np.minimum(np.maximum(arm, cutp), dE - 0.044)
    lo = np.minimum(np.maximum(arm, -cutp), dE - 0.0425)
    sh = [shell_from(up, G, "ArmL", "skin", 2900, lo=55.0, hi=170.0, cav=arm), shell_from(lo, G, "ForeL", "skin", 2500, lo=55.0, hi=170.0, cav=arm)]

    # manga curta da camiseta
    along1 = (P[0] - Sv[0]) * u1[0] + (P[1] - Sv[1]) * u1[1] + (P[2] - Sv[2]) * u1[2]
    full = smin(upper, delt, 0.03) - 0.008
    hem = np.maximum(np.abs(along1 - 0.062) - 0.011, full - 0.004)
    sl = smax(smin(full, hem, 0.003), along1 - 0.073, 0.004)
    sh.append(shell_from(sl, G, "ArmL", "under", 1000))

    # munhequeira
    wb = smax(cone(P, E, W, 0.049, 0.033) - 0.012, np.abs(along2 - 0.212) - 0.036, 0.007)
    wb = wb - 0.0028 * np.abs(np.sin(along2 * 130.0))
    sh.append(shell_from(wb, G, "ForeL", "under", 700))
    return sh


# ----------------------------------------------------------------------------- PERNA (esquerda do modelo, x > 0)


@cached()
def sculpt_leg():
    G = S.Grid((-0.03, -0.21, -0.012), (0.26, 0.15, 1.0), 0.005)
    P = G.P
    X, Y, Z = P
    thigh = cone(P, (0.095, 0, 0.96), (0.105, -0.012, 0.52), 0.098, 0.088)
    shin = cone(P, (0.105, -0.012, 0.52), (0.112, 0.006, 0.3), 0.088, 0.098)
    pants = smin(smin(thigh, shin, 0.03), ell(P, (0.112, 0.005, 0.292), (0.108, 0.112, 0.066)), 0.03)
    fr = [(0.03, 0.87, 0.17, 0.81, 0.039, 0.0133), (0.02, 0.75, 0.16, 0.705, 0.036, 0.0114), (0.19, 0.66, 0.05, 0.585, 0.039, 0.0152),
          (0.02, 0.565, 0.17, 0.505, 0.039, 0.0171), (0.2, 0.47, 0.05, 0.42, 0.036, 0.0152), (0.01, 0.405, 0.18, 0.35, 0.039, 0.0171),
          (0.21, 0.335, 0.03, 0.292, 0.034, 0.0171)]
    bk = [(0.18, 0.86, 0.03, 0.8, 0.039, 0.0133), (0.02, 0.69, 0.17, 0.62, 0.039, 0.0133), (0.19, 0.55, 0.04, 0.5, 0.039, 0.0171),
          (0.02, 0.44, 0.18, 0.39, 0.039, 0.0152), (0.2, 0.34, 0.03, 0.295, 0.034, 0.0171)]
    pants = pants - S.strokes(P, fr, front=True) - S.strokes(P, bk, front=False)
    pants = smax(pants, 0.246 - Z, 0.01)
    # v3: coxa (LegL) e canela (ShinL) separadas no joelho, com uma esfera por dentro para a dobra não abrir buraco
    dK = np.sqrt((X - KNEE[0]) ** 2 + (Y - KNEE[1]) ** 2 + (Z - KNEE[2]) ** 2)
    up = np.minimum(np.maximum(pants, KNEE[2] - Z), dK - 0.068)
    lo = np.minimum(np.maximum(pants, Z - KNEE[2]), dK - 0.066)
    sh = [shell_from(up, G, "LegL", "gi", 2900, cav=pants), shell_from(lo, G, "ShinL", "gi", 2700, cav=pants)]

    shaft = cone(P, (0.112, 0.008, 0.275), (0.113, 0.012, 0.08), 0.068, 0.051)
    foot = ell(P, (0.118, -0.058, 0.047), (0.053, 0.118, 0.047))
    boot = smax(smin(shaft, foot, 0.025), 0.004 - Z, 0.003)
    sh.append(shell_from(boot, G, "ShinL", "boot", 1700))
    sole = smax(smax(smin(shaft, foot, 0.025) - 0.005, Z - 0.022, 0.002), 0.0 - Z, 0.002)
    sh.append(shell_from(sole, G, "ShinL", "sole", 500))
    cuff = smax(shaft - 0.007, np.abs(Z - 0.222) - 0.02, 0.004)
    stripe = np.maximum(np.maximum(smin(shaft, foot, 0.025) - 0.0045, np.abs(X - 0.116) - 0.009), np.maximum(Y + 0.025, Z - 0.21))
    sh.append(shell_from(np.minimum(cuff, stripe), G, "ShinL", "trim", 700))
    cord = np.sqrt((shaft - 0.003) ** 2 + (Z - 0.165) ** 2) - 0.0062
    cord = np.minimum(cord, ell(P, (0.113, -0.052, 0.165), (0.013, 0.009, 0.011)))
    cord = np.minimum(cord, cone(P, (0.113, -0.055, 0.165), (0.135, -0.062, 0.128), 0.005, 0.004))
    cord = np.minimum(cord, cone(P, (0.113, -0.055, 0.165), (0.094, -0.064, 0.132), 0.005, 0.004))
    sh.append(shell_from(cord, G, "ShinL", "cord", 500))
    return sh


# ----------------------------------------------------------------------------- extras do mirim


@cached()
def sculpt_cloud():
    """Nuvem voadora: gomos bem marcados (o vinco entre eles vira linha), mais um rastro de bolhas de fumaça."""
    G = S.Grid((-0.66, -0.52, -0.26), (0.66, 1.12, 0.36), 0.008)
    P = G.P
    rng = np.random.default_rng(5)
    f = ell(P, (0, 0, -0.05), (0.36, 0.3, 0.1))
    for i in range(13):                                                # anel de gomos
        a = 2 * math.pi * i / 13 + rng.uniform(-0.12, 0.12)
        r = rng.uniform(0.3, 0.4)
        s = rng.uniform(0.12, 0.17)
        f = smin(f, ell(P, (r * math.cos(a) * 1.2, r * math.sin(a) * 0.95, rng.uniform(-0.07, 0.0)), (s * 1.1, s, s * 0.85)), 0.012)
    for c, s in (((0.12, 0.04, 0.0), 0.17), ((-0.17, 0.1, -0.005), 0.16), ((0.0, -0.15, -0.01), 0.15), ((0.26, 0.2, -0.02), 0.13),
                 ((-0.24, -0.1, -0.02), 0.13), ((0.0, 0.24, -0.01), 0.14)):   # gomos de cima
        f = smin(f, ell(P, c, (s * 1.15, s, s * 0.72)), 0.012)
    f = smax(f, P[2] - 0.098, 0.04)                                    # topo um pouco chato, para pisar
    puffs = None
    spots = [((0.14, 0.52, 0.0), 0.12), ((-0.12, 0.66, 0.03), 0.095), ((0.07, 0.8, 0.07), 0.072), ((-0.04, 0.92, 0.11), 0.05), ((0.03, 1.01, 0.15), 0.032),
             ((0.36, 0.44, -0.02), 0.08), ((-0.38, 0.47, 0.0), 0.07), ((0.5, 0.2, 0.1), 0.045), ((-0.52, 0.16, 0.12), 0.04), ((0.56, -0.08, 0.16), 0.03),
             ((-0.57, -0.12, 0.18), 0.028), ((0.3, 0.7, 0.14), 0.04), ((-0.3, 0.78, 0.17), 0.034), ((0.2, 0.93, 0.22), 0.026), ((-0.17, 1.0, 0.25), 0.022)]
    for c, s in spots:
        bl = ell(P, c, (s, s * 1.05, s * 0.9))
        if s > 0.06:
            bl = smin(bl, ell(P, (c[0] + s * 0.62, c[1] + s * 0.25, c[2] + s * 0.25), (s * 0.62, s * 0.62, s * 0.55)), 0.01)
            bl = smin(bl, ell(P, (c[0] - s * 0.55, c[1] - s * 0.2, c[2] + s * 0.3), (s * 0.5, s * 0.5, s * 0.45)), 0.01)
        puffs = bl if puffs is None else np.minimum(puffs, bl)
    return [shell_from(f, G, "Cloud", "cloud", 5200, lo=35.0, hi=110.0), shell_from(puffs, G, "Smoke", "cloud", 1800, lo=35.0, hi=110.0)]


# ----------------------------------------------------------------------------- montagem


MIRROR = {"ArmL": "ArmR", "ForeL": "ForeR", "LegL": "LegR", "ShinL": "ShinR"}

# quem gira com quem (animação por peças rígidas)
PARENTS = dict(Torso="Root", Head="Torso", Hair="Head", ArmL="Torso", ArmR="Torso", ForeL="ArmL", ForeR="ArmR",
               LegL="Root", LegR="Root", ShinL="LegL", ShinR="LegR", Tail="Torso", Staff="Torso", Cloud="Root", Smoke="Cloud", Aura="Root")


def body(hair, mood="grin"):
    sh = sculpt_head(mood) + hair
    for s in sh:
        s.affine((1.1, 1.1, 1.1), NECK, NECKH)
    sh += [s.copy() for s in sculpt_torso()]
    arm, leg = sculpt_arm() + sculpt_hand(), sculpt_leg()
    sh += [s.copy() for s in arm] + [s.mirrored(MIRROR[s.role]) for s in arm]
    sh += [s.copy() for s in leg] + [s.mirrored(MIRROR[s.role]) for s in leg]
    return sh


def _mx(p):
    return (-p[0], p[1], p[2])


def joints_adult():
    return dict(Root=(0, 0, 0), Head=NECKH, Hair=NECKH, Torso=(0, 0, 0.97), ArmL=SHO, ArmR=_mx(SHO), ForeL=ELB, ForeR=_mx(ELB),
                LegL=HIP, LegR=_mx(HIP), ShinL=KNEE, ShinR=_mx(KNEE))


def chibi(shells):
    """Transforma o corpo adulto no mirim: mesmas peças, proporção de 2,5 cabeças. As mãos NÃO são achatadas (mão grande de mirim)."""
    lz, tz = 0.3, 0.44
    hip_z = HIP[2] * lz
    neck_z = hip_z + (NECK[2] - HIP[2]) * tz
    sho_z = hip_z + (SHO[2] - HIP[2]) * tz
    zw = 0.952                                                # abaixo disto é a mão
    J = dict(Root=(0, 0, 0))
    for s in shells:
        sx = -1.0 if s.role.endswith("R") else 1.0
        if s.role in ("Head", "Hair"):
            sc = (1.85, 1.85, 1.52)
            new = (0, 0.0, neck_z - 0.062)
            s.affine(sc, NECKH, new)
            if s.role == "Hair":                                  # encurta as mechas (o couro cabeludo fica onde está)
                hc = np.array(new, dtype=F32) + (HC1 - np.array(NECKH, dtype=F32)) * np.array(sc, dtype=F32)
                dv = s.V - hc[None, :]
                r = np.linalg.norm(dv, axis=1, keepdims=True)
                r0 = 0.2
                s.V = hc[None, :] + dv * np.where(r > r0, (r0 + (r - r0) * 0.66) / np.maximum(r, 1e-6), 1.0)
            J[s.role] = (0, 0, neck_z)
        elif s.role == "Torso":
            s.affine((0.76, 0.9, tz), (0, 0, HIP[2]), (0, 0, hip_z))
            J[s.role] = (0, 0, hip_z + 0.03)
        elif s.role[:3] in ("Arm", "For"):
            sc = (0.9, 0.9, 0.5)
            piv = (sx * SHO[0], SHO[1], SHO[2])
            new = (sx * SHO[0] * 0.76, 0, sho_z)
            z0 = s.V[:, 2].copy()
            s.affine(sc, piv, new)
            if s.role.startswith("Fore"):
                low = z0 < zw
                s.V[low, 2] = new[2] + (zw - SHO[2]) * sc[2] + (z0[low] - zw) * 0.9
                J[s.role] = (new[0] + sx * (ELB[0] - SHO[0]) * sc[0], new[1] + (ELB[1] - SHO[1]) * sc[1], new[2] + (ELB[2] - SHO[2]) * sc[2])
            else:
                J[s.role] = new
        elif s.role[:3] in ("Leg", "Shi"):
            sc = (0.86, 0.9, lz)
            new = (sx * HIP[0] * 0.8, 0, hip_z)
            s.affine(sc, (sx * HIP[0], HIP[1], HIP[2]), new)
            if s.role.startswith("Shin"):
                J[s.role] = (new[0] + sx * (KNEE[0] - HIP[0]) * sc[0], new[1] + (KNEE[1] - HIP[1]) * sc[1], new[2] + (KNEE[2] - HIP[2]) * sc[2])
            else:
                J[s.role] = new
    return J


def mini_extras(lift):
    sh = []
    tail = prim_shell(L.tube([(0, 0.07, 0.3), (0.05, 0.2, 0.25), (0.15, 0.28, 0.34), (0.19, 0.27, 0.47), (0.15, 0.24, 0.55)], 0.02, 10, radii=[0.022, 0.022, 0.021, 0.018, 0.012]), "Tail", "tail")
    staff = prim_shell(L.tube([(-0.25, 0.115, 0.2), (0.24, 0.115, 0.98)], 0.018, 10), "Staff", "staff")
    for s in (tail, staff):
        s.V[:, 2] += lift
    sh += [tail, staff]
    sh += [s.copy() for s in sculpt_cloud()]
    return sh, dict(Tail=(0, 0.07, 0.3 + lift), Staff=(0, 0.115, 0.59 + lift), Cloud=(0, 0, 0), Smoke=(0, 0.5, 0))


SPECS = {
    "gokun": dict(file="gokun_v3", name="Gokun", pal=PAL_CLASSIC, hair="base", scale=4.3, anim="gokun"),
    "super": dict(file="super_gokun_v3", name="Super Gokun", pal=PAL_SUPER, hair="super", scale=4.3, aura=True, mood="serious", anim="super"),
    "mini_classic": dict(file="mini_gokun_v3_classic", name="Mini Gokun", pal=PAL_CLASSIC, hair="base", scale=6.2, mini=True, anim="mini"),
    "mini_violet": dict(file="mini_gokun_v3_violet", name="Mini Gokun (violet)", pal=PAL_VIOLET, hair="base", scale=6.2, mini=True, anim="mini"),
}

# ----------------------------------------------------------------------------- animações de "parado" (idle)
#
# Cada personagem fica numa POSE própria e se mexe nela. Tudo em eixos do modelo (X = esquerda do personagem, -Y = frente, Z = cima):
#   a = giro em X (graus): + inclina tronco/cabeça para a frente; num membro pendurado, + leva para TRÁS (o cotovelo dobra com a negativo)
#   b = giro em Y: num membro, - abre o braço/perna ESQUERDO para fora e + abre o DIREITO
#   c = giro em Z: + vira para a esquerda do personagem
#   x, y, z = deslocamento em metros do modelo
# A rotação de cada peça é Rz(c) * Rx(a) * Ry(b) em torno da junta, no espaço do pai (PARENTS).
# waves = (peça, canal, amplitude, período em s, fase 0..1). Os períodos dividem "loop", para a animação fechar.
# O MESMO dado vai para o Roblox (ReplicatedStorage.Shared.CharacterAnims), lido por Shared.CharacterRig.

IDLE = {
    "gokun": dict(name="Fighting stance", loop=4.0, ground=True, pose={
        "Root": dict(c=-24), "Torso": dict(a=5, c=-4), "Head": dict(c=26, a=1),
        "LegL": dict(a=-20, b=-7), "ShinL": dict(a=20, b=7), "LegR": dict(a=14, b=12), "ShinR": dict(a=6, b=-12),
        "ArmL": dict(a=-50, b=-14), "ForeL": dict(a=-88), "ArmR": dict(a=28, b=14), "ForeR": dict(a=-105)},
        waves=[("Root", "z", 0.006, 2, 0), ("Torso", "a", 1.6, 2, 0), ("Torso", "c", 2, 4, 0), ("Head", "a", -1.2, 2, 0.1), ("Hair", "a", 1.2, 2, 0.3),
               ("ArmL", "a", 3, 2, 0.1), ("ForeL", "a", 5, 2, 0.2), ("ArmR", "a", 2.5, 2, 0.6), ("ForeR", "a", 4, 2, 0.7)]),
    "super": dict(name="Power up", loop=4.0, ground=True, pose={
        "Torso": dict(a=7), "Head": dict(a=6),
        "LegL": dict(a=-12, b=-15), "ShinL": dict(a=12, b=15), "LegR": dict(a=-12, b=15), "ShinR": dict(a=12, b=-15),
        "ArmL": dict(a=6, b=-32), "ForeL": dict(a=-62, b=22), "ArmR": dict(a=6, b=32), "ForeR": dict(a=-62, b=-22)},
        waves=[("Root", "x", 0.0035, 0.2, 0), ("Root", "z", 0.003, 0.25, 0.3), ("Torso", "a", 1.2, 1, 0), ("Head", "a", 1, 1, 0.2),
               ("Hair", "a", 2.2, 0.5, 0), ("Hair", "c", 1.5, 0.25, 0), ("ArmL", "b", 2.5, 1, 0), ("ArmR", "b", -2.5, 1, 0),
               ("ForeL", "a", 4, 1, 0.1), ("ForeR", "a", 4, 1, 0.1), ("Aura", "z", 0.035, 0.5, 0), ("Aura", "c", 5, 4, 0)]),
    "mini": dict(name="Cloud rider", loop=4.0, ground=False, pose={
        "Head": dict(b=5), "LegL": dict(b=-12), "ShinL": dict(b=12), "LegR": dict(b=12), "ShinR": dict(b=-12),
        "ArmR": dict(a=-28, b=128), "ForeR": dict(b=-22), "ArmL": dict(a=12, b=-38), "ForeL": dict(a=-20, b=80)},
        waves=[("Root", "z", 0.03, 2, 0), ("Root", "b", 2.5, 4, 0), ("Cloud", "c", 3, 4, 0.25), ("Smoke", "z", 0.02, 1, 0.5), ("Smoke", "y", 0.015, 2, 0),
               ("ForeR", "b", 16, 1, 0), ("ArmR", "b", 4, 1, 0.1), ("Tail", "c", 22, 1, 0), ("Tail", "a", 8, 2, 0),
               ("Head", "c", 5, 4, 0), ("Head", "b", 2, 2, 0), ("Torso", "a", 2, 2, 0), ("Hair", "a", 1.5, 2, 0.3)]),
}


def anim_values(anim, t):
    vals = {p: dict(v) for p, v in anim["pose"].items()}
    for part, ch, amp, period, phase in anim["waves"]:
        d = vals.setdefault(part, {})
        d[ch] = d.get(ch, 0.0) + amp * math.sin(2 * math.pi * (t / period + phase))
    return vals


def pose_mats(anim, joints, scale, t, drop=0.0, offset=(0, 0, 0)):
    """Matriz (mundo do Blender, já na escala de exportação) de cada peça no instante t. joints em metros."""
    from mathutils import Matrix
    vals = anim_values(anim, t)
    out = {}

    def local(part):
        v = vals.get(part, {})
        j = joints.get(part, (0, 0, 0))
        Jm = Matrix.Translation([c * scale for c in j])
        R = (Matrix.Rotation(math.radians(v.get("c", 0.0)), 4, "Z") @ Matrix.Rotation(math.radians(v.get("a", 0.0)), 4, "X")
             @ Matrix.Rotation(math.radians(v.get("b", 0.0)), 4, "Y"))
        tr = [v.get("x", 0.0) * scale, v.get("y", 0.0) * scale, v.get("z", 0.0) * scale]
        if part == "Root":
            tr = [tr[0] + offset[0], tr[1] + offset[1], tr[2] + offset[2] - drop * scale]
        return Matrix.Translation(tr) @ Jm @ R @ Jm.inverted()

    def world(part):
        if part not in out:
            p = PARENTS.get(part)
            out[part] = (world(p) @ local(part)) if p else local(part)
        return out[part]

    for part in list(joints) + list(PARENTS):
        world(part)
    return out


def apply_pose(objs, mats):
    for role, ob in objs.items():
        ob.matrix_world = mats[role]


def rest_pose(objs):
    from mathutils import Matrix
    for ob in objs.values():
        ob.matrix_world = Matrix.Identity(4)


def ground_drop(objs, anim, joints, scale):
    """Quanto o corpo tem de descer para o pé mais baixo encostar no chão na pose (em metros do modelo)."""
    mats = pose_mats(anim, joints, scale, 0.0)
    lows = {}
    for role in ("ShinL", "ShinR"):
        me = objs[role].data
        co = np.empty(len(me.vertices) * 3, dtype=F32)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        m = np.array(mats[role])
        lows[role] = float((co @ m[:3, :3].T + m[:3, 3])[:, 2].min()) / scale
    print("GROUND", {k: round(v, 4) for k, v in lows.items()})
    return min(lows.values())


OCCL = {"Torso": ("Torso", "Head", "Hair"), "Head": ("Head", "Hair"), "Cloud": ("Cloud",)}


def build(key, scene):
    sp = SPECS[key]
    shells = body(hair_base() if sp["hair"] == "base" else hair_super(), sp.get("mood", "grin"))
    J = joints_adult()
    lift = 0.0
    if sp.get("mini"):
        J = chibi(shells)
        lift = 0.14                                              # o mirim fica de pé em cima da nuvem
        for s in shells:
            s.V[:, 2] += lift
        J = {k: (v[0], v[1], v[2] + lift) for k, v in J.items()}
        J["Root"] = (0, 0, 0)
        extra, je = mini_extras(lift)
        shells += extra
        J.update(je)
    if sp.get("aura"):
        shells += aura()
        J["Aura"] = (0, 0, 0)
    roles = []
    for s in shells:
        if s.role not in roles:
            roles.append(s.role)
    coll = bpy.data.collections.new(key)
    scene.collection.children.link(coll)
    objs, tris = {}, {}
    for role in roles:
        mine = [s for s in shells if s.role == role]
        occ = [s for s in shells if s.role in OCCL.get(role, (role,))]
        cols = [S.shade(s, occ, sp["pal"], LIGHT, back=BACK) for s in mine]
        objs[role] = S.to_object(f"{key}_{role}", mine, cols, sp["scale"], coll)
        tris[role] = S.tri_count(mine)
    info = dict(id=sp["file"] + ("_game" if LOD < 1.0 else ""), name=sp["name"], scale=sp["scale"], tris=sum(tris.values()), parts=tris,
                joints={k: [round(c * sp["scale"], 3) for c in v] for k, v in J.items()})
    return objs, info, J


# ----------------------------------------------------------------------------- materiais, render, exportação


def mat_cel():
    m = bpy.data.materials.get("Cel")
    if m:
        return m
    m = bpy.data.materials.new("Cel")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    a = nt.nodes.new("ShaderNodeVertexColor")
    a.layer_name = "Col"
    e = nt.nodes.new("ShaderNodeEmission")
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(a.outputs["Color"], e.inputs["Color"])
    nt.links.new(e.outputs["Emission"], o.inputs["Surface"])
    return m


def mat_outline():
    m = bpy.data.materials.get("Outline")
    if m:
        return m
    m = bpy.data.materials.new("Outline")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (0.012, 0.01, 0.014, 1)
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs["Emission"], o.inputs["Surface"])
    m.use_backface_culling = True
    return m


def mat_aura():
    m = bpy.data.materials.get("AuraMat")
    if m:
        return m
    m = bpy.data.materials.new("AuraMat")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (1.0, 0.82, 0.2, 1)
    e.inputs["Strength"].default_value = 1.6
    t = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = 0.3
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(t.outputs[0], mix.inputs[1])
    nt.links.new(e.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], o.inputs["Surface"])
    try:
        m.surface_render_method = "BLENDED"
    except Exception:
        m.blend_method = "BLEND"
    return m


def dress(objs, scale, outline=True):
    for role, ob in objs.items():
        if role == "Aura":
            ob.data.materials.append(mat_aura())
            continue
        ob.data.materials.append(mat_cel())
        if outline:
            ob.data.materials.append(mat_outline())
            md = ob.modifiers.new("Outline", "SOLIDIFY")
            md.thickness = 0.0045 * scale
            md.offset = 1.0
            md.use_flip_normals = True
            md.use_rim = False
            md.material_offset = 1


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    old, mods = {}, {}
    for role, ob in objs.items():
        old[ob] = ob.name
        ob.name = role
        mods[ob] = [(m, m.show_viewport) for m in ob.modifiers]
        for m in ob.modifiers:
            m.show_viewport = False
        ob.select_set(True)
    bpy.context.view_layer.objects.active = next(iter(objs.values()))
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, axis_forward="-Z", axis_up="Y",
                             apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True, use_mesh_modifiers=False,
                             mesh_smooth_type="FACE", use_triangles=True, colors_type="SRGB", add_leaf_bones=False, bake_anim=False)
    for ob, name in old.items():
        ob.name = name
    for ob, lst in mods.items():
        for m, v in lst:
            m.show_viewport = v


def shots(scene, key, objs, sp, ren):
    """Folha do personagem: frente, 3/4, costas e rosto."""
    sc = sp["scale"]
    mini = sp.get("mini")
    mid = (0.5 if mini else 1.04) * sc
    d = (3.3 if mini else 3.6) * sc
    face_z = (0.83 if mini else 1.75) * sc
    views = [("frente", (0, -d, mid * 1.05), (0, 0, mid), 60), ("tres_quartos", (-d * 0.62, -d * 0.78, mid * 1.15), (0, 0, mid), 60),
             ("costas", (d * 0.55, d * 0.83, mid * 1.15), (0, 0, mid), 60),
             ("rosto", (-0.5 * sc * (1.6 if mini else 1.0), -1.9 * sc * (1.6 if mini else 1.0), face_z), (0, 0, face_z), 85)]
    for o in scene.collection.children:
        o.hide_render = o.name != key
    paths = []
    for name, loc, tgt, lens in views:
        L.camera(scene, loc, tgt, lens=lens)
        p = os.path.join(ren, "personagens", sp["file"] + "_" + name + ".png")
        L.render(scene, p, (760, 1000))
        paths.append(p)
    return paths


def detail_shots(scene, key, objs, sp, ren):
    """Closes da v3: rosto de frente, rosto de perfil, mão (costas) e mão (dedos)."""
    sc = sp["scale"]
    for o in scene.collection.children:
        o.hide_render = o.name != key
    hz = 1.75 * sc
    hand = (0.335 * sc, -0.055 * sc, 0.9 * sc)
    views = [("rosto_frente", (0, -1.75 * sc, hz), (0, 0, hz), 85), ("rosto_perfil", (-1.75 * sc, -0.1 * sc, hz), (0, 0, hz), 85),
             ("mao_costas", (hand[0] + 0.62 * sc, hand[1] - 0.42 * sc, hand[2] + 0.1 * sc), hand, 85),
             ("mao_dedos", (hand[0] - 0.1 * sc, hand[1] - 0.6 * sc, hand[2] - 0.42 * sc), hand, 85)]
    paths = []
    for name, loc, tgt, lens in views:
        L.camera(scene, loc, tgt, lens=lens)
        p = os.path.join(ren, "personagens", sp["file"] + "_" + name + ".png")
        L.render(scene, p, (760, 760))
        paths.append(p)
    return paths


def idle_shots(scene, key, objs, sp, ren, anim, J, drop):
    """Quatro instantes da animação de parado, em 3/4 de frente."""
    sc = sp["scale"]
    mini = sp.get("mini")
    mid = (0.55 if mini else 1.0) * sc
    d = (3.6 if mini else 3.9) * sc
    for o in scene.collection.children:
        o.hide_render = o.name != key
    L.camera(scene, (-d * 0.5, -d * 0.86, mid * 1.2), (0, 0, mid), 60)
    paths = []
    for i, t in enumerate((0.0, 0.5, 1.0, 1.5)):
        apply_pose(objs, pose_mats(anim, J, sc, t, drop))
        p = os.path.join(ren, "personagens", sp["file"] + "_idle" + str(i) + ".png")
        L.render(scene, p, (760, 1000))
        paths.append(p)
    rest_pose(objs)
    return paths


def video(scene, cast, path, fps=15):
    """Um vídeo curto com os personagens lado a lado na animação de parado (loop)."""
    state = []
    for i, (key, objs, sp, anim, J, drop) in enumerate(cast):
        state.append((objs, sp, anim, J, drop, ((i - (len(cast) - 1) * 0.5) * 10.5, 0.0, 0.0)))
    names = {c[0] for c in cast}
    for o in scene.collection.children:
        o.hide_render = o.name not in names

    def step(sc, *_):
        t = (sc.frame_current - 1) / fps
        for objs, sp, anim, J, drop, off in state:
            apply_pose(objs, pose_mats(anim, J, sp["scale"], t, drop, off))

    L.camera(scene, (-5.0, -39.0, 6.2), (0, 0, 4.5), 50)
    r = scene.render
    r.resolution_x, r.resolution_y, r.fps = 1280, 720, fps
    scene.frame_start, scene.frame_end = 1, int(round(4.0 * fps))
    ok = True
    try:
        try:
            r.image_settings.media_type = "VIDEO"
        except Exception:
            pass
        r.image_settings.file_format = "FFMPEG"
        r.ffmpeg.format = "MPEG4"
        r.ffmpeg.codec = "H264"
        r.ffmpeg.constant_rate_factor = "MEDIUM"
        r.filepath = path
        bpy.app.handlers.frame_change_pre.append(step)
        bpy.ops.render.render(animation=True)
    except Exception as e:
        ok = False
        print("VIDEO_FAIL", repr(e))
    if step in bpy.app.handlers.frame_change_pre:
        bpy.app.handlers.frame_change_pre.remove(step)
    try:
        r.image_settings.media_type = "IMAGE"
    except Exception:
        pass
    r.image_settings.file_format = "PNG"
    # um quadro parado do conjunto, para o relatório
    scene.frame_set(1)
    step(scene)
    L.render(scene, os.path.splitext(path)[0] + ".png", (1280, 720))
    for objs, *_ in state:
        rest_pose(objs)
    return ok


def anim_export(sp, anim, J, drop):
    """Animação no formato que o Roblox lê: juntas e deslocamentos em studs (eixos do Blender; o módulo converte)."""
    sc = sp["scale"]
    tr = ("x", "y", "z")
    pose = {p: {k: round(v * (sc if k in tr else 1.0), 4) for k, v in d.items()} for p, d in anim["pose"].items()}
    waves = [[p, ch, round(amp * (sc if ch in tr else 1.0), 4), per, ph] for p, ch, amp, per, ph in anim["waves"]]
    return dict(name=anim["name"], loop=anim["loop"], drop=round(drop * sc, 4), pose=pose, waves=waves,
                parents=PARENTS, joints={k: [round(c * sc, 3) for c in v] for k, v in J.items()})


def main():
    global LOD
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    root = argv[0]
    opts = [a for a in argv[1:] if "=" in a or a.startswith("no")]
    keys = [a for a in argv[1:] if a not in opts] or list(SPECS)
    for o in opts:
        if o.startswith("lod="):
            LOD = float(o[4:])
    game = LOD < 1.0
    suffix = "_game" if game else ""
    exp, ren = os.path.join(root, "export"), os.path.join(root, "renders")
    os.makedirs(os.path.join(ren, "personagens"), exist_ok=True)
    scene = L.reset_scene()
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.53, 0.58, 1)
    infos, sheets, cast, anims = [], [], [], {}
    for key in keys:
        sp = dict(SPECS[key])
        sp["file"] = sp["file"] + suffix
        objs, info, J = build(key, scene)
        info["id"] = sp["file"]
        export(objs, os.path.join(exp, sp["file"] + ".fbx"))
        dress(objs, sp["scale"])
        infos.append(info)
        print("CHAR", key, info["tris"], info["parts"])
        sheets.append((sp["file"], shots(scene, key, objs, sp, ren), 4))
        anim = IDLE[sp["anim"]]
        drop = ground_drop(objs, anim, J, sp["scale"]) if anim.get("ground") else 0.0
        anims[sp["file"]] = anim_export(sp, anim, J, drop)
        if game:
            continue
        if key == "gokun" and "nodetail" not in opts:
            sheets.append((sp["file"] + "_detalhes", detail_shots(scene, key, objs, sp, ren), 4))
        sheets.append((sp["file"] + "_idle", idle_shots(scene, key, objs, sp, ren, anim, J, drop), 4))
        if key != "mini_violet":
            cast.append((key, objs, sp, anim, J, drop))
    for name, paths, cols in sheets:
        L.contact_sheet(paths, os.path.join(ren, name + ".png"), cols)
    if cast and not game and "novideo" not in opts:
        video(scene, cast, os.path.join(ren, "idle_personagens.mp4"))
    for fn, new in (("personagens.json", infos), ("personagens_anim.json", anims)):
        jp = os.path.join(exp, fn)
        if isinstance(new, list):
            prev = []
            if os.path.exists(jp):
                with open(jp, "r", encoding="utf-8") as f:
                    prev = [p for p in json.load(f) if p["id"] not in {i["id"] for i in new}]
            data = prev + new
        else:
            data = {}
            if os.path.exists(jp):
                with open(jp, "r", encoding="utf-8") as f:
                    data = json.load(f)
            data.update(new)
        with open(jp, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=1)
    if not game:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "blend", "personagens.blend"))


if __name__ == "__main__":
    main()
