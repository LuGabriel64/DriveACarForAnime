"""
char_hero.py — personagens do bioma 1 esculpidos por SDF (Beta 2.0, segunda versão da arte de personagens).

  blender --background --python arte/blender/char_hero.py -- <pasta arte/> [gokun super mini_classic mini_violet]

O que sai (em arte/export/ e arte/renders/):
  gokun.fbx          lutador adulto, cabelo preto espetado           (Common)
  super_gokun.fbx    mesmo corpo, cabelo dourado para cima + aura     (Secret)
  mini_gokun_v2_classic.fbx / mini_gokun_v2_violet.fbx   versão mirim na nuvem (Épico, 2 skins; companheiro dos carros)
  personagens.json   peças, triângulos, juntas (pivôs) e escala de cada um

Um corpo só é esculpido (em metros, pés em z = 0, frente = -Y) e reaproveitado:
  * adulto: cabeça 10% maior (proporção de anime);
  * mirim: as MESMAS peças, achatadas por peça (cabeça grande, tronco e membros curtos).
Peças rígidas (MeshParts animados por código no Roblox): Head, Hair, Torso, ArmL, ArmR, LegL, LegR
(+ Tail, Staff, Cloud no mirim; + Aura no Super).

Estilo: anime 2.5D com cel-shading PINTADO nos vértices (dois tons, sombra projetada, linhas nos vincos).
Modelos próprios: sem emblemas, sem kanji, nada baixado da web.
A versão antiga (blocos) continua em char_mini.py e arte/export/mini_gokun_classic.fbx, para comparar.
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

# ----------------------------------------------------------------------------- cache das esculturas

CACHE = os.path.join(tempfile.gettempdir(), "dacfa_sdf_cache")


def cached(fn):
    """A escultura demora; guarda o resultado num .npz que se invalida quando o código da função muda."""
    def run():
        src = inspect.getsource(fn) + inspect.getsource(S)
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


def shell_from(F, G, role, mat, tris, lo=50.0, hi=150.0):
    V, T = S.mesh(F, G, tris)
    return S.Shell(role, mat, V, T, S.cavity(F, G, V, lo, hi, step=2))


# ----------------------------------------------------------------------------- CABEÇA


def head_field(G):
    P, M = G.P, G.M
    cran = ell(P, (0, 0.012, 1.71), (0.083, 0.1, 0.093))
    face = cone(P, (0, -0.022, 1.685), (0, -0.05, 1.601), 0.069, 0.037)
    h = smin(cran, face, 0.03)
    h = smin(h, ell(M, (0.041, -0.014, 1.615), (0.026, 0.046, 0.026)), 0.016)          # ângulo da mandíbula
    h = smin(h, ell(P, (0, -0.066, 1.582), (0.029, 0.022, 0.019)), 0.012)                # queixo quadrado
    h = smin(h, ell(P, (0, -0.079, 1.63), (0.028, 0.013, 0.017)), 0.016)                # boca / focinho
    h = smin(h, ell(M, (0.034, -0.087, 1.714), (0.034, 0.012, 0.009), S.euler(ry=-10)), 0.008)   # arco da sobrancelha
    h = cut(h, ell(M, (0.038, -0.101, 1.69), (0.024, 0.012, 0.011)), 0.008)           # órbita
    nose = cone(P, (0, -0.089, 1.7), (0, -0.101, 1.668), 0.004, 0.006)
    h = smin(h, nose, 0.007)
    ear = ell(M, (0.085, 0.016, 1.672), (0.011, 0.021, 0.031), S.euler(rz=-18))
    ear = cut(ear, ell(M, (0.096, 0.006, 1.672), (0.007, 0.012, 0.019)), 0.003)
    h = smin(h, ear, 0.005)
    h = smin(h, cone(P, (0, 0.012, 1.545), (0, 0.008, 1.64), 0.052, 0.052), 0.02)     # toco do pescoço
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


@cached
def sculpt_head():
    G = S.Grid((-0.125, -0.14, 1.53), (0.125, 0.13, 1.82), 0.0032)
    skin = shell_from(head_field(G), G, "Head", "skin", 9000, lo=150.0, hi=340.0)
    bvh = BVHTree.FromPolygons(skin.V.tolist(), skin.T.tolist())
    sh = [skin]
    # sobrancelha grossa, descendo para o nariz (expressão decidida)
    sh += decal([(0.007, 1.7075), (0.030, 1.7225), (0.060, 1.7315), (0.072, 1.7265), (0.060, 1.7215), (0.034, 1.7125), (0.011, 1.6995)], bvh, 6, "ink", mirror=True)
    # olho anguloso: branco, cílio de cima grosso, íris grande, brilho, linha de baixo
    sh += decal([(0.014, 1.690), (0.030, 1.7025), (0.060, 1.7015), (0.066, 1.6925), (0.058, 1.681), (0.022, 1.6795)], bvh, 1, "white", mirror=True)
    sh += decal([(0.009, 1.6925), (0.030, 1.7075), (0.061, 1.7065), (0.072, 1.6935), (0.061, 1.699), (0.030, 1.7), (0.013, 1.6885)], bvh, 4, "ink", mirror=True)
    sh += decal(circle((0.038, 1.6925), 0.011, 16), bvh, 2, "eye", cuts=1, mirror=True)
    sh += decal(circle((0.038, 1.6925), 0.0055, 10), bvh, 3, "ink", cuts=0, mirror=True)
    sh += decal(circle((0.0338, 1.6955), 0.003, 8), bvh, 5, "white", cuts=0, mirror=True)
    sh += decal([(0.022, 1.6792), (0.042, 1.6772), (0.062, 1.684), (0.062, 1.682), (0.042, 1.675), (0.022, 1.677)], bvh, 4, "ink", mirror=True)
    # risco da maçã do rosto, boca firme, sombra sob o lábio
    sh += decal([(-0.003, 1.6632), (0.007, 1.6645), (0.006, 1.6622), (-0.002, 1.6615)], bvh, 2, "ink", cuts=1)
    sh += decal([(-0.015, 1.6222), (-0.006, 1.6232), (0.006, 1.6232), (0.015, 1.6222), (0.015, 1.6206), (0.006, 1.6212), (-0.006, 1.6212), (-0.015, 1.6206)], bvh, 2, "ink")
    sh += decal([(-0.009, 1.6125), (0.009, 1.6125), (0.006, 1.6105), (-0.006, 1.6105)], bvh, 2, "lip", cuts=1)
    return sh


# ----------------------------------------------------------------------------- CABELO (mechas facetadas)

HC = np.array((0.0, 0.018, 1.712), dtype=F32)
HR = 0.097
HC1 = np.array((0.0, 0.005, 1.555), dtype=F32) + (HC - np.array((0.0, 0.005, 1.555), dtype=F32)) * 1.1   # depois do aumento de 10% da cabeça


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
    return prim_shell(L.sphere((0, 0.022, 1.716), 0.099, 20, 12, (1.0, 1.03, 0.97)), "Hair", "hair")


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
    for tip, root, w in (((-0.066, -0.114, 0.022), (-0.4, -0.72, 0.58), 0.03), ((0.012, -0.124, 0.0), (0.05, -0.82, 0.58), 0.028),
                         ((0.072, -0.11, 0.03), (0.45, -0.7, 0.55), 0.028), ((-0.104, -0.085, 0.0), (-0.72, -0.5, 0.48), 0.026)):
        sh.append(lock(tip, w, root=root, n=6, sag=-0.02))
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
    sh.append(lock((0.022, -0.118, -0.002), 0.022, root=(0.12, -0.8, 0.6), n=6, sag=-0.02))
    sh.append(lock((-0.05, -0.1, 0.06), 0.022, root=(-0.3, -0.75, 0.62), n=6, sag=-0.03))
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


@cached
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
    trap = cone(M, (0.03, 0.02, 1.575), (0.165, 0.012, 1.497), 0.046, 0.038)
    neck = cone(P, (0, 0.012, 1.47), (0, 0.0, 1.63), 0.063, 0.056)

    soft = smin(smin(smin(core, pec, 0.04), lat, 0.04), trap, 0.03)           # volume para a roupa

    skin = smin(smin(core, lat, 0.03), trap, 0.02)
    skin = smin(skin, neck, 0.02)
    skin = smin(skin, pec, 0.011)
    skin = smin(skin, cone(M, (0.014, -0.083, 1.49), (0.176, -0.034, 1.506), 0.011, 0.012), 0.006)   # clavícula
    skin = smin(skin, cone(M, (0.012, -0.062, 1.488), (0.05, 0.012, 1.605), 0.011, 0.014), 0.006)    # esternocleidomastoideo
    skin = smin(skin, ell(P, (0, -0.058, 1.555), (0.012, 0.01, 0.014)), 0.006)                        # pomo de adão
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


@cached
def sculpt_arm():
    G = S.Grid((0.11, -0.15, 0.82), (0.43, 0.12, 1.6), 0.0042)
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
    # punho fechado
    Fc = W + u2 * 0.05
    fist = rbox(P, Fc, (0.031, 0.041, 0.046), 0.016, R2)
    xl, yl = R2[:, 0], R2[:, 1]
    for off in (-0.021, 0.0, 0.021):                                                   # sulcos entre os dedos
        g = rbox(P, Fc + xl * 0.022 + yl * off + u2 * 0.012, (0.02, 0.0022, 0.04), 0.001, R2)
        fist = cut(fist, g, 0.003)
    thumb = cone(P, Fc + yl * 0.04 - u2 * 0.02 - xl * 0.006, Fc + yl * 0.037 + u2 * 0.024 + xl * 0.012, 0.014, 0.012)
    fist = smin(fist, thumb, 0.005)
    arm = smin(arm, fist, 0.012)
    sh = [shell_from(arm, G, "ArmL", "skin", 5200, lo=55.0, hi=170.0)]

    # manga curta da camiseta
    along1 = (P[0] - Sv[0]) * u1[0] + (P[1] - Sv[1]) * u1[1] + (P[2] - Sv[2]) * u1[2]
    full = smin(upper, delt, 0.03) - 0.008
    hem = np.maximum(np.abs(along1 - 0.062) - 0.011, full - 0.004)
    sl = smax(smin(full, hem, 0.003), along1 - 0.073, 0.004)
    sh.append(shell_from(sl, G, "ArmL", "under", 1000))

    # munhequeira
    along2 = (P[0] - E[0]) * u2[0] + (P[1] - E[1]) * u2[1] + (P[2] - E[2]) * u2[2]
    wb = smax(cone(P, E, W, 0.049, 0.033) - 0.012, np.abs(along2 - 0.212) - 0.036, 0.007)
    wb = wb - 0.0028 * np.abs(np.sin(along2 * 130.0))
    sh.append(shell_from(wb, G, "ArmL", "under", 700))
    return sh


# ----------------------------------------------------------------------------- PERNA (esquerda do modelo, x > 0)


@cached
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
    sh = [shell_from(pants, G, "LegL", "gi", 5200)]

    shaft = cone(P, (0.112, 0.008, 0.275), (0.113, 0.012, 0.08), 0.068, 0.051)
    foot = ell(P, (0.118, -0.058, 0.047), (0.053, 0.118, 0.047))
    boot = smax(smin(shaft, foot, 0.025), 0.004 - Z, 0.003)
    sh.append(shell_from(boot, G, "LegL", "boot", 1700))
    sole = smax(smax(smin(shaft, foot, 0.025) - 0.005, Z - 0.022, 0.002), 0.0 - Z, 0.002)
    sh.append(shell_from(sole, G, "LegL", "sole", 500))
    cuff = smax(shaft - 0.007, np.abs(Z - 0.222) - 0.02, 0.004)
    stripe = np.maximum(np.maximum(smin(shaft, foot, 0.025) - 0.0045, np.abs(X - 0.116) - 0.009), np.maximum(Y + 0.025, Z - 0.21))
    sh.append(shell_from(np.minimum(cuff, stripe), G, "LegL", "trim", 700))
    cord = np.sqrt((shaft - 0.003) ** 2 + (Z - 0.165) ** 2) - 0.0062
    cord = np.minimum(cord, ell(P, (0.113, -0.052, 0.165), (0.013, 0.009, 0.011)))
    cord = np.minimum(cord, cone(P, (0.113, -0.055, 0.165), (0.135, -0.062, 0.128), 0.005, 0.004))
    cord = np.minimum(cord, cone(P, (0.113, -0.055, 0.165), (0.094, -0.064, 0.132), 0.005, 0.004))
    sh.append(shell_from(cord, G, "LegL", "cord", 500))
    return sh


# ----------------------------------------------------------------------------- extras do mirim


@cached
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
    return [shell_from(f, G, "Cloud", "cloud", 5200, lo=35.0, hi=110.0), shell_from(puffs, G, "Cloud", "cloud", 1800, lo=35.0, hi=110.0)]


# ----------------------------------------------------------------------------- montagem


def body(hair):
    sh = [s.copy() for s in sculpt_head()] + hair
    for s in sh:
        s.affine((1.1, 1.1, 1.1), NECK, NECK)
    sh += [s.copy() for s in sculpt_torso()]
    arm, leg = sculpt_arm(), sculpt_leg()
    sh += [s.copy() for s in arm] + [s.mirrored("ArmR") for s in arm]
    sh += [s.copy() for s in leg] + [s.mirrored("LegR") for s in leg]
    return sh


def joints_adult():
    return dict(Head=NECK, Hair=NECK, Torso=(0, 0, 1.0), ArmL=SHO, ArmR=(-SHO[0], SHO[1], SHO[2]), LegL=HIP, LegR=(-HIP[0], HIP[1], HIP[2]))


def chibi(shells):
    """Transforma o corpo adulto no mirim: mesmas peças, proporção de 2,5 cabeças."""
    lz, tz = 0.3, 0.44
    hip_z = HIP[2] * lz
    neck_z = hip_z + (NECK[2] - HIP[2]) * tz
    sho_z = hip_z + (SHO[2] - HIP[2]) * tz
    J = {}
    for s in shells:
        sx = 1.0 if s.role.endswith("L") or s.role in ("Head", "Hair", "Torso") else -1.0
        if s.role in ("Head", "Hair"):
            sc = (1.85, 1.85, 1.52)
            new = (0, 0.0, neck_z - 0.062)
            s.affine(sc, NECK, new)
            if s.role == "Hair":                                  # encurta as mechas (o couro cabeludo fica onde está)
                hc = np.array(new, dtype=F32) + (HC1 - np.array(NECK, dtype=F32)) * np.array(sc, dtype=F32)
                dv = s.V - hc[None, :]
                r = np.linalg.norm(dv, axis=1, keepdims=True)
                r0 = 0.2
                s.V = hc[None, :] + dv * np.where(r > r0, (r0 + (r - r0) * 0.66) / np.maximum(r, 1e-6), 1.0)
            J[s.role] = (0, 0, neck_z)
        elif s.role == "Torso":
            s.affine((0.76, 0.9, tz), (0, 0, HIP[2]), (0, 0, hip_z))
            J[s.role] = (0, 0, hip_z + 0.03)
        elif s.role.startswith("Arm"):
            new = (sx * SHO[0] * 0.76, 0, sho_z)
            s.affine((0.9, 0.9, 0.5), (sx * SHO[0], SHO[1], SHO[2]), new)
            J[s.role] = new
        elif s.role.startswith("Leg"):
            new = (sx * HIP[0] * 0.8, 0, hip_z)
            s.affine((0.86, 0.9, lz), (sx * HIP[0], HIP[1], HIP[2]), new)
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
    return sh


SPECS = {
    "gokun": dict(file="gokun", name="Gokun", pal=PAL_CLASSIC, hair="base", scale=4.3),
    "super": dict(file="super_gokun", name="Super Gokun", pal=PAL_SUPER, hair="super", scale=4.3, aura=True),
    "mini_classic": dict(file="mini_gokun_v2_classic", name="Mini Gokun", pal=PAL_CLASSIC, hair="base", scale=6.2, mini=True),
    "mini_violet": dict(file="mini_gokun_v2_violet", name="Mini Gokun (violet)", pal=PAL_VIOLET, hair="base", scale=6.2, mini=True),
}

OCCL = {"Torso": ("Torso", "Head", "Hair"), "Head": ("Head", "Hair"), "Cloud": ("Cloud",)}


def build(key, scene):
    sp = SPECS[key]
    shells = body(hair_base() if sp["hair"] == "base" else hair_super())
    J = joints_adult()
    lift = 0.0
    if sp.get("mini"):
        J = chibi(shells)
        lift = 0.14                                              # o mirim fica de pé em cima da nuvem
        for s in shells:
            s.V[:, 2] += lift
        J = {k: (v[0], v[1], v[2] + lift) for k, v in J.items()}
        shells += mini_extras(lift)
    if sp.get("aura"):
        shells += aura()
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
    info = dict(id=sp["file"], name=sp["name"], scale=sp["scale"], tris=sum(tris.values()), parts=tris,
                joints={k: [round(c * sp["scale"], 3) for c in v] for k, v in J.items()})
    return objs, info


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
    top = (1.25 if mini else 2.15) * sc
    mid = (0.5 if mini else 1.02) * sc
    d = (3.3 if mini else 3.55) * sc
    face_z = (0.83 if mini else 1.72) * sc
    views = [("frente", (0, -d, mid * 1.05), (0, 0, mid), 60), ("tres_quartos", (-d * 0.62, -d * 0.78, mid * 1.15), (0, 0, mid), 60),
             ("costas", (d * 0.55, d * 0.83, mid * 1.15), (0, 0, mid), 60),
             ("rosto", (-0.5 * sc * (1.6 if mini else 1.0), -1.9 * sc * (1.6 if mini else 1.0), face_z), (0, 0, face_z), 85)]
    for o in scene.collection.children:
        o.hide_render = o.name != key
    paths = []
    for name, loc, tgt, lens in views:
        L.camera(scene, loc, tgt, lens=lens)
        p = os.path.join(ren, "personagens", f"{sp['file']}_{name}.png")
        L.render(scene, p, (760, 1000))
        paths.append(p)
    return paths


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    root = argv[0]
    keys = argv[1:] or list(SPECS)
    exp, ren = os.path.join(root, "export"), os.path.join(root, "renders")
    os.makedirs(os.path.join(ren, "personagens"), exist_ok=True)
    scene = L.reset_scene()
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.53, 0.58, 1)
    infos, sheets = [], []
    for key in keys:
        sp = SPECS[key]
        objs, info = build(key, scene)
        export(objs, os.path.join(exp, sp["file"] + ".fbx"))
        dress(objs, sp["scale"])
        infos.append(info)
        print("CHAR", key, info["tris"], info["parts"])
        sheets.append((sp, shots(scene, key, objs, sp, ren)))
    for sp, paths in sheets:
        L.contact_sheet(paths, os.path.join(ren, f"{sp['file']}.png"), 4)
    jp = os.path.join(exp, "personagens.json")
    prev = []
    if os.path.exists(jp):
        with open(jp, "r", encoding="utf-8") as f:
            prev = [p for p in json.load(f) if p["id"] not in {i["id"] for i in infos}]
    with open(jp, "w", encoding="utf-8") as f:
        json.dump(prev + infos, f, indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "blend", "personagens.blend"))


if __name__ == "__main__":
    main()
