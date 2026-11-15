"""
f1lib.py — biblioteca de modelagem procedural (Blender 5.x, roda em segundo plano) dos carros de Fórmula do jogo.

CONVENÇÕES (iguais às do Roblox, para a importação sair direta)
  * 1 unidade do Blender = 1 stud. Frente do carro = -Y do Blender (vira -Z no Roblox na exportação FBX).
  * Chão em z = 0. Centro do carro em x = 0.
  * Cada carro vira poucos objetos, um por PAPEL (role), que no Roblox são MeshParts:
        Body      superfícies pintadas (usa a textura de pintura, "livery")
        Trim      carbono, suspensão, assoalho, capacete (cor por vértice)
        Glow      peças que brilham (Neon no Roblox)
        Glass     canopy / vidros
        Acc       acessórios do bioma (cor por vértice)
        Wheel_FL / Wheel_FR / Wheel_RL / Wheel_RR   rodas (giram)
  * Toda peça é uma casca FECHADA; as normais são recalculadas por peça (bmesh).

Nada aqui depende de arquivo externo. Quem monta o carro é f1_build.py.
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

# ----------------------------------------------------------------------------- utilidades de malha


def oriented(verts, faces):
    """Limpa a peça (solda vértices repetidos, tira faces degeneradas) e deixa as normais para fora."""
    bm = bmesh.new()
    bv = [bm.verts.new(v) for v in verts]
    for f in faces:
        ids = []
        for i in f:
            if i not in ids:
                ids.append(i)
        if len(ids) < 3:
            continue
        try:
            bm.faces.new([bv[i] for i in ids])
        except ValueError:
            pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.verts.index_update()
    out_v = [tuple(v.co) for v in bm.verts]
    out_f = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    return out_v, out_f


class Builder:
    """Junta peças por papel. Cada face guarda cor (sRGB 0..1) e se é lisa (smooth)."""

    def __init__(self):
        self.roles = {}

    def add(self, role, piece, color, smooth=True, mirror=False):
        verts, faces = piece
        r = self.roles.setdefault(role, dict(v=[], f=[], c=[], s=[]))

        def push(vs, fs):
            base = len(r["v"])
            r["v"].extend(vs)
            for f in fs:
                r["f"].append(tuple(base + i for i in f))
                r["c"].append(color)
                r["s"].append(smooth)

        push(verts, faces)
        if mirror:
            push([(-x, y, z) for x, y, z in verts], [tuple(reversed(f)) for f in faces])

    def tris(self):
        return {k: sum(len(f) - 2 for f in r["f"]) for k, r in self.roles.items()}


# ----------------------------------------------------------------------------- primitivas


def box(c, s, rot=None):
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    vs = [Vector((sx * hx, sy * hy, sz * hz)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    if rot is not None:
        vs = [rot @ v for v in vs]
    vs = [tuple(v + Vector(c)) for v in vs]
    fs = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return oriented(vs, fs)


def strut(p1, p2, w, t):
    """Barra de seção w x t entre dois pontos (braços de suspensão, hastes)."""
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    rot = d.normalized().to_track_quat("Y", "Z").to_matrix()
    return box((p1 + p2) / 2, (w, d.length, t), rot)


def prism(poly, axis, a0, a1):
    """Extrusão de um polígono 2D. axis 'X': pontos (y,z) | 'Y': (x,z) | 'Z': (x,y)."""

    def p3(p, a):
        if axis == "X":
            return (a, p[0], p[1])
        if axis == "Y":
            return (p[0], a, p[1])
        return (p[0], p[1], a)

    n = len(poly)
    vs = [p3(p, a0) for p in poly] + [p3(p, a1) for p in poly]
    fs = [tuple(range(n)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    return oriented(vs, fs)


def _catmull(vals, sub):
    """Interpola uma lista de vetores numpy (estações) com Catmull-Rom; devolve a lista densa."""
    P = [np.array(v, dtype=float) for v in vals]
    out = []
    n = len(P)
    for i in range(n - 1):
        p0, p1, p2, p3 = P[max(i - 1, 0)], P[i], P[i + 1], P[min(i + 2, n - 1)]
        for k in range(sub):
            t = k / sub
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-1])
    return out


def loft(stations, K=20, sub=4):
    """
    Corpo por seções. Cada estação: (y, cx, cz, hw, hh, n)  n = expoente da superelipse (2 = elipse, 4+ = caixa).
    """
    dense = _catmull(stations, sub)
    vs, fs = [], []
    for st in dense:
        y, cx, cz, hw, hh, n = st
        hw, hh, n = max(hw, 0.01), max(hh, 0.01), max(n, 1.2)
        for k in range(K):
            th = 2 * math.pi * k / K
            c, s = math.cos(th), math.sin(th)
            x = cx + hw * math.copysign(abs(c) ** (2 / n), c)
            z = cz + hh * math.copysign(abs(s) ** (2 / n), s)
            vs.append((x, y, z))
    R = len(dense)
    for r in range(R - 1):
        for k in range(K):
            a, b = r * K + k, r * K + (k + 1) % K
            fs.append((a, b, b + K, a + K))
    fs.append(tuple(range(K)))
    fs.append(tuple(range((R - 1) * K, R * K)))
    return oriented(vs, fs)


def wing(stations):
    """
    Asa por estações ao longo da envergadura. Estação: (x, y_bordo_de_ataque, z, corda, angulo_graus, espessura).
    A corda aponta para +Y (trás); ângulo positivo levanta o bordo de fuga.
    """
    prof = [(0.0, 0.0), (0.25, 0.5), (0.7, 0.3), (1.0, 0.0), (0.7, -0.2), (0.25, -0.5)]
    vs, fs = [], []
    for x, yl, z, ch, ang, th in stations:
        a = math.radians(ang)
        ca, sa = math.cos(a), math.sin(a)
        for c, t in prof:
            cc, tt = c * ch, t * th
            vs.append((x, yl + cc * ca - tt * sa, z + cc * sa + tt * ca))
    n, R = len(prof), len(stations)
    for r in range(R - 1):
        for k in range(n):
            a, b = r * n + k, r * n + (k + 1) % n
            fs.append((a, b, b + n, a + n))
    fs.append(tuple(range(n)))
    fs.append(tuple(range((R - 1) * n, R * n)))
    return oriented(vs, fs)


def tube(points, radius, segs=8, radii=None):
    """Tubo ao longo de uma linha (halo, tubos de neon, caudas). radii = raio por ponto (opcional)."""
    pts = [Vector(p) for p in points]
    vs, fs = [], []
    up = Vector((0, 0, 1))
    prev_n = None
    for i, p in enumerate(pts):
        if i == 0:
            d = pts[1] - pts[0]
        elif i == len(pts) - 1:
            d = pts[-1] - pts[-2]
        else:
            d = pts[i + 1] - pts[i - 1]
        d.normalize()
        if prev_n is None:
            ref = up if abs(d.dot(up)) < 0.95 else Vector((1, 0, 0))
            nrm = d.cross(ref).normalized()
        else:
            nrm = (prev_n - d * prev_n.dot(d)).normalized()
        prev_n = nrm
        bn = d.cross(nrm)
        r = radii[i] if radii else radius
        for k in range(segs):
            th = 2 * math.pi * k / segs
            vs.append(tuple(p + (nrm * math.cos(th) + bn * math.sin(th)) * r))
    R = len(pts)
    for r in range(R - 1):
        for k in range(segs):
            a, b = r * segs + k, r * segs + (k + 1) % segs
            fs.append((a, b, b + segs, a + segs))
    fs.append(tuple(range(segs)))
    fs.append(tuple(range((R - 1) * segs, R * segs)))
    return oriented(vs, fs)


def lathe(profile, center, segs=24, axis="X", arc=(0.0, 360.0)):
    """
    Revolução de um perfil FECHADO em torno de um eixo. profile = [(raio, deslocamento_no_eixo), ...].
    arc em graus (360 = volta inteira; menos que isso fecha as pontas: para-lamas).
    """
    full = abs(arc[1] - arc[0]) >= 359.9
    steps = segs if full else segs + 1
    n = len(profile)
    vs, fs = [], []
    for s in range(steps):
        th = math.radians(arc[0] + (arc[1] - arc[0]) * s / segs)
        c, sn = math.cos(th), math.sin(th)
        for r, a in profile:
            if axis == "X":
                vs.append((center[0] + a, center[1] + r * c, center[2] + r * sn))
            elif axis == "Z":
                vs.append((center[0] + r * c, center[1] + r * sn, center[2] + a))
            else:
                vs.append((center[0] + r * c, center[1] + a, center[2] + r * sn))
    rings = steps if full else steps - 1
    for s in range(rings):
        s2 = (s + 1) % steps
        for k in range(n):
            k2 = (k + 1) % n
            fs.append((s * n + k, s * n + k2, s2 * n + k2, s2 * n + k))
    if not full:
        fs.append(tuple(range(n)))
        fs.append(tuple(range((steps - 1) * n, steps * n)))
    return oriented(vs, fs)


def sphere(c, r, segs=14, rings=8, scale=(1, 1, 1)):
    vs, fs = [], []
    for i in range(rings + 1):
        ph = math.pi * i / rings
        for k in range(segs):
            th = 2 * math.pi * k / segs
            vs.append((
                c[0] + r * scale[0] * math.sin(ph) * math.cos(th),
                c[1] + r * scale[1] * math.sin(ph) * math.sin(th),
                c[2] + r * scale[2] * math.cos(ph),
            ))
    for i in range(rings):
        for k in range(segs):
            a, b = i * segs + k, i * segs + (k + 1) % segs
            fs.append((a, b, b + segs, a + segs))
    return oriented(vs, fs)


def spike(base, tip, r, sides=5, bend=(0, 0, 0), mid=0.55):
    """Espinho (cabelo, cristal, chama): base -> anel do meio (com desvio) -> ponta."""
    base, tip = Vector(base), Vector(tip)
    d = (tip - base)
    L = d.length
    d.normalize()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    n1 = d.cross(ref).normalized()
    n2 = d.cross(n1)
    vs = []
    for cpos, rad in ((base, r), (base + d * L * mid + Vector(bend), r * 0.62)):
        for k in range(sides):
            th = 2 * math.pi * k / sides
            vs.append(tuple(cpos + (n1 * math.cos(th) + n2 * math.sin(th)) * rad))
    vs.append(tuple(tip))
    fs = [tuple(range(sides))]
    for k in range(sides):
        k2 = (k + 1) % sides
        fs.append((k, k2, sides + k2, sides + k))
        fs.append((sides + k, sides + k2, 2 * sides))
    return oriented(vs, fs)


# ----------------------------------------------------------------------------- do Builder para objetos do Blender

# Caixa usada para projetar a pintura (UV) na carroceria: lado em cima da textura, vista de cima embaixo.
UV_YMIN, UV_YMAX, UV_ZMAX, UV_XMAX = -10.4, 9.0, 4.4, 5.2


def body_uv(co, nz):
    u = (co[1] - UV_YMIN) / (UV_YMAX - UV_YMIN)
    u = min(max(u, 0.001), 0.999)
    if abs(nz) > 0.55:
        v = 0.25 + 0.25 * min(max(co[0] / UV_XMAX, -0.995), 0.995)
    else:
        v = 0.5 + 0.5 * min(max(co[2] / UV_ZMAX, 0.005), 0.995)
    return u, v


def to_objects(builder, prefix, collection):
    """Cria um objeto de malha por papel: cor por vértice 'Col', UV 'UV' (útil só no Body)."""
    objs = {}
    for role, r in builder.roles.items():
        me = bpy.data.meshes.new(f"{prefix}_{role}")
        me.from_pydata(r["v"], [], r["f"])
        me.update()
        me.polygons.foreach_set("use_smooth", r["s"])
        col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        uv = me.uv_layers.new(name="UV")
        for p in me.polygons:
            c = r["c"][p.index]
            for li in p.loop_indices:
                col.data[li].color_srgb = (c[0], c[1], c[2], 1.0)
                if role == "Body":
                    uv.data[li].uv = body_uv(me.vertices[me.loops[li].vertex_index].co, p.normal.z)
        ob = bpy.data.objects.new(f"{prefix}_{role}", me)
        collection.objects.link(ob)
        ob["role"] = role
        objs[role] = ob
    return objs


# ----------------------------------------------------------------------------- materiais de pré-visualização


def _mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m, False
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    return m, True


def mat_vertex(name="VC", rough=0.5, metallic=0.0):
    m, new = _mat(name)
    if new:
        nt = m.node_tree
        b = nt.nodes["Principled BSDF"]
        a = nt.nodes.new("ShaderNodeVertexColor")
        a.layer_name = "Col"
        nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = rough
        b.inputs["Metallic"].default_value = metallic
    return m


def mat_vertex_emit(name="GlowVC", strength=4.0):
    m, new = _mat(name)
    if new:
        nt = m.node_tree
        b = nt.nodes["Principled BSDF"]
        a = nt.nodes.new("ShaderNodeVertexColor")
        a.layer_name = "Col"
        nt.links.new(a.outputs["Color"], b.inputs["Base Color"])
        nt.links.new(a.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = strength
    return m


def mat_clay():
    m, new = _mat("Clay")
    if new:
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (0.42, 0.42, 0.42, 1)
        b.inputs["Roughness"].default_value = 0.6
    return m


def mat_livery(name, image):
    m, new = _mat(name)
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    if new:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.name = "Livery"
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.28
        try:
            b.inputs["Coat Weight"].default_value = 0.6
        except KeyError:
            pass
    nt.nodes["Livery"].image = image
    return m


def mat_glow(name, color, strength=5.0):
    m, new = _mat(name)
    if new:
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*color, 1)
        b.inputs["Emission Color"].default_value = (*color, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


def mat_glass(name="Glass", color=(0.05, 0.08, 0.12)):
    m, new = _mat(name)
    if new:
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*color, 1)
        b.inputs["Roughness"].default_value = 0.05
        b.inputs["Metallic"].default_value = 0.6
    return m


# ----------------------------------------------------------------------------- cena, câmera e render


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE"
    s.unit_settings.system = "NONE"
    s.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("World")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.045, 0.045, 0.05, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    s.world = w
    return s


def add_lights(scene):
    def light(name, kind, loc, rot, energy, size=None):
        d = bpy.data.lights.new(name, kind)
        d.energy = energy
        if size and kind == "AREA":
            d.size = size
        o = bpy.data.objects.new(name, d)
        o.location, o.rotation_euler = loc, rot
        scene.collection.objects.link(o)
        return o

    light("Key", "SUN", (0, 0, 20), (math.radians(50), math.radians(-18), math.radians(-35)), 2.6)
    light("Fill", "SUN", (0, 0, 20), (math.radians(62), 0, math.radians(125)), 1.1)
    light("Rim", "SUN", (0, 0, 20), (math.radians(70), 0, math.radians(20)), 0.7)


def add_ground(scene, size=400, color=(0.11, 0.11, 0.12)):
    me = bpy.data.meshes.new("Ground")
    h = size / 2
    me.from_pydata([(-h, -h, 0), (h, -h, 0), (h, h, 0), (-h, h, 0)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("Ground", me)
    m, new = _mat("GroundMat")
    if new:
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*color, 1)
        b.inputs["Roughness"].default_value = 0.95
    me.materials.append(m)
    scene.collection.objects.link(ob)
    return ob


def camera(scene, loc, target, lens=55):
    cam = scene.camera
    if cam is None:
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
    cam.data.lens = lens
    cam.data.clip_end = 2000
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return cam


def render(scene, path, res=(1280, 720)):
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


def contact_sheet(paths, out, cols):
    """Monta várias imagens PNG (mesmo tamanho) numa grade."""
    imgs = [bpy.data.images.load(p) for p in paths]
    w, h = imgs[0].size
    rows = math.ceil(len(imgs) / cols)
    sheet = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    sheet[..., 3] = 1
    for i, im in enumerate(imgs):
        px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        r, c = divmod(i, cols)
        y0 = (rows - 1 - r) * h
        sheet[y0:y0 + h, c * w:(c + 1) * w] = px
    o = bpy.data.images.new("sheet", cols * w, rows * h, alpha=True)
    o.pixels.foreach_set(sheet.ravel())
    o.filepath_raw = out
    o.file_format = "PNG"
    o.save()
