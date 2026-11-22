"""
char_mini.py — ESTUDO do "Mini Gokun": lutador mirim low-poly (companheiro voador dos carros do bioma 1 e
personagem Épico com 2 skins). Modelo próprio, inspirado nas referências do dono (proporção chibi, cabelo
espetado, quimono, bastão, cauda, nuvem). Sem emblemas.

  blender --background --python arte/blender/char_mini.py -- <pasta arte/>

Peças rígidas (viram MeshParts e são animadas por código no Roblox):
  Head, Torso, ArmL, ArmR, LegL, LegR, Tail, Staff, Cloud      (frente = -Y, pés em z = 0, altura ~6 studs + cabelo)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy
from mathutils import Vector

import f1lib as L


def rgb(r, g, b):
    return (r / 255.0, g / 255.0, b / 255.0)


SKIN, HAIR, WHITE, DARK = rgb(255, 205, 160), rgb(22, 22, 28), (1, 1, 1), rgb(30, 22, 22)
SKINS = {
    "classic": dict(gi=rgb(255, 150, 30), under=rgb(40, 100, 210), sash=rgb(60, 110, 215), shoe=rgb(50, 90, 190)),
    "violet": dict(gi=rgb(124, 104, 205), under=rgb(205, 45, 45), sash=rgb(196, 226, 206), shoe=rgb(40, 44, 110)),
}


def vloft(stations, K=14, sub=3):
    """Loft na VERTICAL. Estação: (z, cx, cy, meia_largura_x, meia_profundidade_y, n)."""
    v, f = L.loft([(z, cx, cy, hw, hd, n) for z, cx, cy, hw, hd, n in stations], K=K, sub=sub)
    return L.oriented([(x, zz, y) for x, y, zz in v], f)


def build(skin, cloud=True):
    c = SKINS[skin]
    b = L.Builder()
    H = Vector((0, 0, 4.55))

    # ---- cabeça, orelhas, rosto
    b.add("Head", L.sphere(H, 1.2, 16, 10, (1.05, 1.0, 0.95)), SKIN)
    b.add("Head", L.sphere((1.22, 0.05, 4.45), 0.3, 8, 6, (0.5, 0.8, 1.0)), SKIN, mirror=True)
    b.add("Head", L.sphere((0.46, -1.07, 4.5), 0.37, 10, 6, (0.8, 0.3, 1.15)), WHITE, mirror=True)
    b.add("Head", L.sphere((0.42, -1.17, 4.47), 0.2, 8, 6, (0.75, 0.3, 1.25)), DARK, mirror=True)
    b.add("Head", L.sphere((0.37, -1.23, 4.56), 0.06, 6, 4), WHITE, mirror=True)
    b.add("Head", L.strut((0.82, -1.08, 5.02), (0.2, -1.2, 4.84), 0.1, 0.1), HAIR, smooth=False, mirror=True)
    b.add("Head", L.strut((0.0, -1.2, 3.92), (0.24, -1.17, 3.98), 0.05, 0.05), DARK, smooth=False, mirror=True)

    # ---- cabelo: calota + espinhos
    hc = Vector((0, 0.14, 4.74))
    b.add("Head", L.sphere(hc, 1.27, 16, 10, (1.06, 1.02, 0.95)), HAIR)
    tips = [(-2.5, 0.2, 5.5), (-2.1, 0.3, 6.7), (-0.9, 0.0, 7.4), (0.5, 0.0, 7.5), (1.7, 0.2, 6.9), (2.6, 0.3, 5.8),
            (2.3, 0.5, 4.8), (-2.2, 0.6, 4.7), (0.0, 1.9, 6.2), (-1.3, 1.7, 5.4), (1.3, 1.7, 5.4)]
    for t in tips:
        d = (Vector(t) - hc).normalized()
        b.add("Head", L.spike(hc + d * 0.7, t, 0.66, 5, bend=(0, 0.1, 0.12)), HAIR, smooth=False)
    for x in (-0.55, 0.05, 0.6):
        b.add("Head", L.spike((x, -0.98, 5.35), (x * 1.25, -1.34, 4.72), 0.3, 4), HAIR, smooth=False)

    # ---- tronco: quimono, camiseta, faixa
    b.add("Torso", vloft([(2.1, 0, 0, 0.78, 0.55, 2.6), (2.6, 0, 0, 0.9, 0.62, 2.6), (3.2, 0, 0, 0.95, 0.62, 2.6), (3.6, 0, 0, 0.62, 0.48, 2.4)]), c["gi"])
    b.add("Torso", L.prism([(-0.42, 3.62), (0.42, 3.62), (0, 2.95)], "Y", -0.66, -0.56), c["under"], smooth=False)
    b.add("Torso", vloft([(2.05, 0, 0, 0.94, 0.68, 2.6), (2.38, 0, 0, 0.97, 0.7, 2.6)], sub=1), c["sash"])
    b.add("Torso", L.sphere((0.3, -0.72, 2.22), 0.2, 8, 5), c["sash"])
    b.add("Torso", L.strut((0.3, -0.74, 2.2), (0.5, -0.76, 1.7), 0.16, 0.06), c["sash"], smooth=False)
    b.add("Torso", L.strut((0.3, -0.74, 2.2), (0.12, -0.76, 1.75), 0.16, 0.06), c["sash"], smooth=False)

    # ---- braços (um de cada lado: peças separadas para animar)
    for role, s in (("ArmR", 1), ("ArmL", -1)):
        b.add(role, L.sphere((s * 1.02, 0, 3.3), 0.44, 10, 6), c["under"])
        b.add(role, L.tube([(s * 1.05, 0, 3.25), (s * 1.42, -0.08, 2.75), (s * 1.55, -0.32, 2.25)], 0.29, 8), SKIN)
        b.add(role, L.tube([(s * 1.5, -0.24, 2.42), (s * 1.56, -0.34, 2.18)], 0.35, 8), c["under"])
        b.add(role, L.sphere((s * 1.59, -0.42, 1.98), 0.36, 10, 6), SKIN)

    # ---- pernas (calça larga) e sapatos
    for role, s in (("LegR", 1), ("LegL", -1)):
        b.add(role, vloft([(2.2, s * 0.45, 0, 0.5, 0.5, 2.2), (1.5, s * 0.5, 0, 0.62, 0.6, 2.2), (0.8, s * 0.52, 0, 0.52, 0.52, 2.2), (0.55, s * 0.52, 0, 0.33, 0.36, 2.2)]), c["gi"])
        b.add(role, vloft([(0.42, s * 0.52, 0, 0.36, 0.38, 2.2), (0.62, s * 0.52, 0, 0.36, 0.38, 2.2)], sub=1), WHITE)
        b.add(role, L.sphere((s * 0.52, -0.2, 0.3), 0.42, 10, 6, (0.9, 1.45, 0.7)), c["shoe"])

    # ---- cauda, bastão, nuvem
    b.add("Tail", L.tube([(0, 0.5, 2.2), (0.3, 1.3, 1.9), (0.9, 1.75, 2.5), (1.05, 1.65, 3.3)], 0.14, 8, radii=[0.15, 0.15, 0.14, 0.1]), rgb(110, 62, 30))
    b.add("Staff", L.tube([(-1.5, 0.78, 1.4), (1.35, 0.78, 5.9)], 0.12, 8), rgb(222, 40, 40))
    if cloud:
        for dx, dy, s in ((0, 0, 1.3), (1.3, 0.2, 1.0), (-1.3, 0.1, 1.05), (0.5, 1.2, 0.95), (-0.6, 1.1, 0.9), (0.2, -1.1, 0.85), (2.2, 0.9, 0.6), (-2.1, 1.0, 0.55)):
            b.add("Cloud", L.sphere((dx, dy, -0.55), s, 10, 6, (1, 1, 0.55)), rgb(255, 214, 90))
    return b


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    root = argv[0]
    exp, ren = os.path.join(root, "export"), os.path.join(root, "renders")
    scene = L.reset_scene()
    L.add_lights(scene)
    L.add_ground(scene, 200)
    vc = L.mat_vertex("CharVC", 0.6)
    for i, skin in enumerate(SKINS):
        b = build(skin)
        coll = bpy.data.collections.new(f"mini_{skin}")
        scene.collection.children.link(coll)
        objs = L.to_objects(b, f"mini_{skin}", coll)
        for ob in objs.values():
            ob.data.materials.append(vc)
        # exporta (na origem) e depois afasta para o render
        bpy.ops.object.select_all(action="DESELECT")
        old = {}
        for role, ob in objs.items():
            old[ob] = ob.name
            ob.name = role
            ob.select_set(True)
        bpy.context.view_layer.objects.active = objs["Torso"]
        bpy.ops.export_scene.fbx(filepath=os.path.join(exp, f"mini_gokun_{skin}.fbx"), use_selection=True, object_types={"MESH"},
                                 axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True,
                                 mesh_smooth_type="FACE", use_triangles=True, colors_type="SRGB", add_leaf_bones=False, bake_anim=False)
        for ob, name in old.items():
            ob.name = name
        for ob in objs.values():
            ob.location = ((i - 0.5) * 7.5, 0, 1.2)
        print("MINI", skin, sum(b.tris().values()), b.tris())
    L.camera(scene, (-6.5, -19, 6.5), (0, 0, 4.2), lens=50)
    L.render(scene, os.path.join(ren, "mini_gokun_frente.png"), (1280, 800))
    L.camera(scene, (9, 17, 7.5), (0, 0, 4.2), lens=50)
    L.render(scene, os.path.join(ren, "mini_gokun_costas.png"), (1280, 800))


if __name__ == "__main__":
    main()
