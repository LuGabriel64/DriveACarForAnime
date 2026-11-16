"""
sdflib.py — "escultura" procedural por campos de distância (SDF) para os personagens (Beta 2.0).

Por que existe: a primeira versão dos personagens (char_mini.py) era feita de esferas e tubos e ficou com cara
de boneco de blocos. Aqui o corpo é esculpido como numa escultura digital: volumes (músculos, tecido) são
fundidos com união suave, as dobras de roupa são vincos de verdade na superfície, e a malha sai por
"surface nets" (um parente do marching cubes) e depois é reduzida para o orçamento do Roblox.

Fluxo de uma casca (shell):
    G = Grid(lo, hi, h)                      grade de amostragem (metros)
    F = ...primitivas e uniões em G.P / G.M  campo de distância (negativo = dentro)
    V, T = mesh(F, G, alvo_de_triangulos)    malha fechada, já reduzida
    linha = cavity(F, G, V)                  onde há vinco (vira a "linha de tinta" do cel-shading)

O cel-shading é PINTADO nos vértices (shade): luz fixa, dois tons, sombra projetada por raio e linhas nos vincos.
No Roblox isso entra como cor por vértice do MeshPart (sem shader).

Só depende de numpy e do Blender (bpy/mathutils). Usado por char_hero.py.
"""
import math

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

F32 = np.float32


def v3(a):
    return np.asarray(a, dtype=F32)


# ----------------------------------------------------------------------------- grade


class Grid:
    def __init__(self, lo, hi, h):
        self.lo = v3(lo)
        self.h = float(h)
        n = np.ceil((v3(hi) - self.lo) / h).astype(int) + 1
        ax = [self.lo[i] + h * np.arange(n[i], dtype=F32) for i in range(3)]
        self.X, self.Y, self.Z = np.meshgrid(*ax, indexing="ij")
        self.shape = self.X.shape

    @property
    def P(self):
        return (self.X, self.Y, self.Z)

    @property
    def M(self):
        """Espaço espelhado (|x|): o que for modelado em x > 0 aparece dos dois lados."""
        return (np.abs(self.X), self.Y, self.Z)


# ----------------------------------------------------------------------------- rotações


def frame_z(direction, hint=(0, -1, 0)):
    """Matriz 3x3 (colunas = eixos locais) com o eixo Z local apontando para `direction`."""
    z = v3(direction)
    z = z / np.linalg.norm(z)
    y = v3(hint) - z * float(v3(hint) @ z)
    if np.linalg.norm(y) < 1e-5:
        y = v3((1, 0, 0)) - z * z[0]
    y = y / np.linalg.norm(y)
    x = np.cross(y, z)
    return np.stack([x, y, z], axis=1)


def euler(rx=0.0, ry=0.0, rz=0.0):
    """Rotação em graus (X, depois Y, depois Z). Colunas = eixos locais."""
    a, b, c = (math.radians(t) for t in (rx, ry, rz))
    Rx = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]], dtype=F32)
    Ry = np.array([[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]], dtype=F32)
    Rz = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]], dtype=F32)
    return Rz @ Ry @ Rx


def _local(P, c, R):
    x, y, z = P[0] - c[0], P[1] - c[1], P[2] - c[2]
    if R is None:
        return x, y, z
    return (R[0, 0] * x + R[1, 0] * y + R[2, 0] * z,
            R[0, 1] * x + R[1, 1] * y + R[2, 1] * z,
            R[0, 2] * x + R[1, 2] * y + R[2, 2] * z)


# ----------------------------------------------------------------------------- primitivas (devolvem o campo)


def ell(P, c, r, R=None):
    """Elipsoide (distância aproximada, boa perto da superfície)."""
    x, y, z = _local(P, c, R)
    k0 = np.sqrt((x / r[0]) ** 2 + (y / r[1]) ** 2 + (z / r[2]) ** 2)
    k1 = np.sqrt((x / r[0] ** 2) ** 2 + (y / r[1] ** 2) ** 2 + (z / r[2] ** 2) ** 2)
    return np.where(k1 > 1e-6, k0 * (k0 - 1.0) / np.maximum(k1, 1e-6), -min(r)).astype(F32)


def cone(P, a, b, r1, r2):
    """Cápsula afunilada de a (raio r1) até b (raio r2)."""
    a, b = v3(a), v3(b)
    d = b - a
    L2 = float(d @ d)
    px, py, pz = P[0] - a[0], P[1] - a[1], P[2] - a[2]
    t = np.clip((px * d[0] + py * d[1] + pz * d[2]) / L2, 0.0, 1.0)
    dx, dy, dz = px - t * d[0], py - t * d[1], pz - t * d[2]
    return (np.sqrt(dx * dx + dy * dy + dz * dz) - (r1 + (r2 - r1) * t)).astype(F32)


def rbox(P, c, half, rad, R=None):
    """Caixa de cantos arredondados."""
    x, y, z = _local(P, c, R)
    qx, qy, qz = np.abs(x) - (half[0] - rad), np.abs(y) - (half[1] - rad), np.abs(z) - (half[2] - rad)
    out = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2 + np.maximum(qz, 0) ** 2)
    return (out + np.minimum(np.maximum(qx, np.maximum(qy, qz)), 0) - rad).astype(F32)


def smin(a, b, k):
    """União suave. k pequeno = vinco marcado (músculo definido); k grande = fusão macia."""
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return (b + (a - b) * h - k * h * (1.0 - h)).astype(F32)


def smax(a, b, k):
    """Interseção suave (corte)."""
    return -smin(-a, -b, k)


def cut(a, b, k=0.004):
    """a menos b."""
    return smax(a, -b, k)


def saw(s):
    """Perfil de dobra de tecido: sobe macio e cai de uma vez (a queda vira a linha do vinco)."""
    a = np.clip((s + 1.0) / 1.7, 0.0, 1.0)
    rise = a * a * (3.0 - 2.0 * a)
    drop = np.clip((1.0 - s) / 0.3, 0.0, 1.0)
    return np.where(s < 0.7, rise, drop) * (np.abs(s) < 1.0)


def strokes(P, items, front=True, ymid=0.0):
    """
    Dobras desenhadas em vista frontal (ou de costas). Cada item: (x1, z1, x2, z2, largura, altura).
    Devolve o quanto empurrar a superfície para fora; subtraia do campo.
    """
    X, Y, Z = P
    out = np.zeros_like(X)
    for x1, z1, x2, z2, w, amp in items:
        dx, dz = x2 - x1, z2 - z1
        L = math.hypot(dx, dz)
        ux, uz = dx / L, dz / L
        u = ((X - x1) * ux + (Z - z1) * uz) / L
        s = (-(X - x1) * uz + (Z - z1) * ux) / w
        taper = np.maximum(np.sin(np.pi * np.clip(u, 0.0, 1.0)), 0.0) ** 0.7
        out += amp * taper * saw(s)
    side = np.clip((ymid - Y) / 0.02, 0.0, 1.0) if front else np.clip((Y - ymid) / 0.02, 0.0, 1.0)
    return (out * side).astype(F32)


# ----------------------------------------------------------------------------- campo -> malha (surface nets)

_CORNERS = [(0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1, 0), (0, 0, 1), (1, 0, 1), (0, 1, 1), (1, 1, 1)]
_EDGES = [(a, b) for a in range(8) for b in range(a + 1, 8)
          if sum(abs(_CORNERS[a][i] - _CORNERS[b][i]) for i in range(3)) == 1]


def surface_nets(F, lo, h):
    nx, ny, nz = F.shape
    cx, cy, cz = nx - 1, ny - 1, nz - 1
    neg = np.zeros((cx, cy, cz), dtype=np.int8)
    for dx, dy, dz in _CORNERS:
        neg += (F[dx:dx + cx, dy:dy + cy, dz:dz + cz] < 0)
    active = (neg > 0) & (neg < 8)
    ai = np.argwhere(active)
    m = len(ai)
    vid = -np.ones((cx, cy, cz), dtype=np.int32)
    vid[active] = np.arange(m, dtype=np.int32)
    acc = np.zeros((m, 3), dtype=F32)
    cnt = np.zeros(m, dtype=F32)
    for a, b in _EDGES:
        ca, cb = _CORNERS[a], _CORNERS[b]
        fa = F[ai[:, 0] + ca[0], ai[:, 1] + ca[1], ai[:, 2] + ca[2]]
        fb = F[ai[:, 0] + cb[0], ai[:, 1] + cb[1], ai[:, 2] + cb[2]]
        cross = (fa < 0) != (fb < 0)
        t = np.where(cross, fa / np.where(cross, fa - fb, 1.0), 0.0)
        p = v3(ca)[None, :] + t[:, None] * (v3(cb) - v3(ca))[None, :]
        acc += np.where(cross[:, None], p, 0.0)
        cnt += cross
    pos = (ai.astype(F32) + acc / np.maximum(cnt, 1.0)[:, None]) * h + lo[None, :]

    quads = []
    # arestas em X: células (i, j-1..j, k-1..k)
    s0, s1 = F[0:nx - 1, 1:ny - 1, 1:nz - 1] < 0, F[1:nx, 1:ny - 1, 1:nz - 1] < 0
    e = np.argwhere(s0 != s1)
    i, j, k = e[:, 0], e[:, 1] + 1, e[:, 2] + 1
    q = np.stack([vid[i, j - 1, k - 1], vid[i, j, k - 1], vid[i, j, k], vid[i, j - 1, k]], axis=1)
    flip = ~s0[e[:, 0], e[:, 1], e[:, 2]]
    q[flip] = q[flip][:, ::-1]
    quads.append(q)
    # arestas em Y: células (i-1..i, j, k-1..k)
    s0, s1 = F[1:nx - 1, 0:ny - 1, 1:nz - 1] < 0, F[1:nx - 1, 1:ny, 1:nz - 1] < 0
    e = np.argwhere(s0 != s1)
    i, j, k = e[:, 0] + 1, e[:, 1], e[:, 2] + 1
    q = np.stack([vid[i - 1, j, k - 1], vid[i - 1, j, k], vid[i, j, k], vid[i, j, k - 1]], axis=1)
    flip = ~s0[e[:, 0], e[:, 1], e[:, 2]]
    q[flip] = q[flip][:, ::-1]
    quads.append(q)
    # arestas em Z: células (i-1..i, j-1..j, k)
    s0, s1 = F[1:nx - 1, 1:ny - 1, 0:nz - 1] < 0, F[1:nx - 1, 1:ny - 1, 1:nz] < 0
    e = np.argwhere(s0 != s1)
    i, j, k = e[:, 0] + 1, e[:, 1] + 1, e[:, 2]
    q = np.stack([vid[i - 1, j - 1, k], vid[i, j - 1, k], vid[i, j, k], vid[i - 1, j, k]], axis=1)
    flip = ~s0[e[:, 0], e[:, 1], e[:, 2]]
    q[flip] = q[flip][:, ::-1]
    quads.append(q)
    return pos, np.concatenate(quads, axis=0)


def decimate(V, Q, target_tris):
    """Reduz a malha (modificador Decimate do Blender) e devolve triângulos."""
    me = bpy.data.meshes.new("tmp_sdf")
    me.vertices.add(len(V))
    me.vertices.foreach_set("co", V.astype(F32).ravel())
    n = Q.shape[1]
    me.loops.add(Q.size)
    me.loops.foreach_set("vertex_index", Q.astype(np.int32).ravel())
    me.polygons.add(len(Q))
    me.polygons.foreach_set("loop_start", np.arange(0, Q.size, n, dtype=np.int32))
    me.update(calc_edges=True)
    me.validate()
    ob = bpy.data.objects.new("tmp_sdf", me)
    bpy.context.scene.collection.objects.link(ob)
    cur = len(Q) * (n - 2)
    if target_tris and cur > target_tris:
        mod = ob.modifiers.new("dec", "DECIMATE")
        mod.ratio = target_tris / cur
    tri = ob.modifiers.new("tri", "TRIANGULATE")
    dg = bpy.context.evaluated_depsgraph_get()
    me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    Vo = np.zeros(len(me2.vertices) * 3, dtype=F32)
    me2.vertices.foreach_get("co", Vo)
    To = np.zeros(len(me2.polygons) * 3, dtype=np.int32)
    me2.polygons.foreach_get("vertices", To)
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    bpy.data.meshes.remove(me2)
    return Vo.reshape(-1, 3), To.reshape(-1, 3)


def mesh(F, G, target_tris):
    V, Q = surface_nets(F, G.lo, G.h)
    return decimate(V, Q, target_tris)


def sample(A, G, V):
    """Lê o volume A (na grade G) nos pontos V, com interpolação trilinear."""
    g = (V - G.lo[None, :]) / G.h
    n = np.array(A.shape) - 2
    i = np.clip(np.floor(g).astype(int), 0, n[None, :])
    f = np.clip(g - i, 0.0, 1.0)
    out = np.zeros(len(V), dtype=F32)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out += w * A[i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz]
    return out


def cavity(F, G, V, lo=70.0, hi=200.0, step=1):
    """0..1: quanto o ponto está num vinco (curvatura côncava forte). É a máscara da linha de tinta."""
    s = step
    lap = (np.roll(F, s, 0) + np.roll(F, -s, 0) + np.roll(F, s, 1) + np.roll(F, -s, 1) + np.roll(F, s, 2) + np.roll(F, -s, 2) - 6.0 * F) / ((G.h * s) ** 2)
    val = -sample(lap.astype(F32), G, V)
    return np.clip((val - lo) / (hi - lo), 0.0, 1.0)


# ----------------------------------------------------------------------------- cascas e pintura


class Shell:
    """Um pedaço de malha de uma só cor-base (material `mat`), que pertence a uma peça rígida (`role`)."""

    def __init__(self, role, mat, V, T, line=None, flat=False, unlit=False, cast=True):
        self.role, self.mat = role, mat
        self.V = np.asarray(V, dtype=F32).reshape(-1, 3)
        self.T = np.asarray(T, dtype=np.int32).reshape(-1, 3)
        self.line = np.zeros(len(self.V), dtype=F32) if line is None else np.asarray(line, dtype=F32)
        self.flat, self.unlit, self.cast = flat, unlit, cast

    def copy(self, role=None, mat=None):
        s = Shell(role or self.role, mat or self.mat, self.V.copy(), self.T.copy(), self.line.copy(), self.flat, self.unlit, self.cast)
        return s

    def mirrored(self, role):
        s = self.copy(role)
        s.V[:, 0] *= -1.0
        s.T = s.T[:, ::-1].copy()
        return s

    def affine(self, scale, pivot, new_pivot):
        self.V = (self.V - v3(pivot)[None, :]) * v3(scale)[None, :] + v3(new_pivot)[None, :]
        return self


def vnormals(V, T):
    fn = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
    vn = np.zeros_like(V)
    for k in range(3):
        np.add.at(vn, T[:, k], fn)
    ln = np.linalg.norm(vn, axis=1, keepdims=True)
    fl = np.linalg.norm(fn, axis=1, keepdims=True)
    return vn / np.maximum(ln, 1e-12), fn / np.maximum(fl, 1e-12)


def _bvh(shells):
    vs, ts, base = [], [], 0
    for s in shells:
        if not s.cast:
            continue
        vs.append(s.V)
        ts.append(s.T + base)
        base += len(s.V)
    if not vs:
        return None
    return BVHTree.FromPolygons(np.concatenate(vs).tolist(), np.concatenate(ts).tolist())


def shade(shell, occluders, palette, light, reach=0.35, line_strength=0.92, back=None):
    """
    Devolve as cores por canto (m, 3, 3) da casca: dois tons + sombra projetada + linhas nos vincos.
    palette[mat] = dict(base=, shadow=, line=) em sRGB 0..1.
    """
    pal = palette[shell.mat]
    base, shadow = v3(pal["base"]), v3(pal.get("shadow", pal["base"]))
    line = v3(pal.get("line", pal.get("shadow", pal["base"])))
    V, T = shell.V, shell.T
    if shell.unlit:
        return np.broadcast_to(base[None, None, :], (len(T), 3, 3)).copy()
    vn, fn = vnormals(V, T)
    Lv = v3(light)
    Lv = Lv / np.linalg.norm(Lv)
    bvh = _bvh(occluders)
    if shell.flat:
        pts, nrm = V[T].mean(axis=1), fn
    else:
        pts, nrm = V, vn
    ndl = nrm @ Lv
    lit = np.clip((ndl - pal.get("thresh", 0.08) + 0.05) / 0.10, 0.0, 1.0)
    lit = lit * lit * (3 - 2 * lit)
    if back is not None:      # contraluz: clareia os planos que encaram a luz de trás (para as costas não ficarem chapadas)
        Bv = v3(back)
        Bv = Bv / np.linalg.norm(Bv)
        l2 = np.clip((nrm @ Bv - 0.42) / 0.10, 0.0, 1.0)
        back_lit = l2 * l2 * (3 - 2 * l2)
    else:
        back_lit = np.zeros_like(lit)
    if bvh is not None:
        idx = np.nonzero(ndl > 0.0)[0]
        Lt = tuple(float(x) for x in Lv)
        for i in idx:
            o = pts[i] + nrm[i] * 0.006 + Lv * 0.004
            hit = bvh.ray_cast((float(o[0]), float(o[1]), float(o[2])), Lt, reach)
            if hit[0] is not None:
                lit[i] = 0.0
    lit = np.maximum(lit, back_lit)
    col = shadow[None, :] + (base - shadow)[None, :] * lit[:, None]
    if "high" in pal:  # brilho (cabelo, metal): faixa clara onde a superfície encara a luz
        hi = np.clip((ndl - pal.get("high_at", 0.82)) / 0.06, 0.0, 1.0) * lit
        col = col + (v3(pal["high"])[None, :] - col) * hi[:, None]
    if shell.flat:
        return np.repeat(col[:, None, :], 3, axis=1)
    lm = (shell.line * line_strength)[:, None]
    col = col + (line[None, :] - col) * lm
    return col[T]


def to_object(name, shells, colors, scale=1.0, collection=None):
    """Junta as cascas de uma peça num objeto de malha, com a cor por vértice 'Col'."""
    vs, ts, cs, sm, base = [], [], [], [], 0
    for s, c in zip(shells, colors):
        vs.append(s.V * scale)
        ts.append(s.T + base)
        cs.append(c)
        sm.append(np.full(len(s.T), not s.flat))
        base += len(s.V)
    V, T, C, S = np.concatenate(vs), np.concatenate(ts), np.concatenate(cs), np.concatenate(sm)
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(V))
    me.vertices.foreach_set("co", V.astype(F32).ravel())
    me.loops.add(T.size)
    me.loops.foreach_set("vertex_index", T.ravel())
    me.polygons.add(len(T))
    me.polygons.foreach_set("loop_start", np.arange(0, T.size, 3, dtype=np.int32))
    me.update(calc_edges=True)
    me.polygons.foreach_set("use_smooth", S)
    col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    rgba = np.ones((T.size, 4), dtype=F32)
    rgba[:, :3] = np.clip(C.reshape(-1, 3), 0.0, 1.0)
    try:
        col.data.foreach_set("color_srgb", rgba.ravel())
    except Exception:
        for i in range(T.size):
            col.data[i].color_srgb = rgba[i]
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    return ob


def tri_count(shells):
    return int(sum(len(s.T) for s in shells))
