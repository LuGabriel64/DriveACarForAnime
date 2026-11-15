"""
f1_all.py — gera os 21 carros (3 por bioma): pintura, acessórios, FBX para o Roblox, renders e o .blend.

  blender --background --python arte/blender/f1_all.py -- <pasta arte/> [ids separados por vírgula]

Saídas (dentro de arte/):
  export/<id>.fbx            um carro por arquivo; objetos Body, Trim, Glow, Glass, Acc, Wheel_FL/FR/RL/RR
  export/<id>_livery.png     a pintura (também vai embutida no FBX, no material do Body)
  renders/carros/<id>.png    pré-visualização; renders/carros_f1.png = folha com todos
  blend/f1_carros.blend      todos os carros numa grade (linhas = biomas, colunas = A, B, C)
  export/carros.json         nomes, bioma, carroceria, triângulos e medidas das rodas (para o CarFactory)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy

import f1lib as L
from f1_build import build, place
from f1_themes import CARS, Canvas


def export_fbx(objs, path):
    """Exporta só os objetos do carro, com os nomes dos papéis (Body, Trim...). Frente = -Z, cima = Y."""
    bpy.ops.object.select_all(action="DESELECT")
    old = {}
    for role, ob in objs.items():
        old[ob] = ob.name
        ob.name = role
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs["Body"]
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"}, axis_forward="-Z", axis_up="Y",
        global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True,
        mesh_smooth_type="FACE", use_triangles=True, colors_type="SRGB", path_mode="COPY", embed_textures=True,
        add_leaf_bones=False, bake_anim=False,
    )
    for ob, name in old.items():
        ob.name = name
    bpy.ops.object.select_all(action="DESELECT")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    root = argv[0]
    only = set(argv[1].split(",")) if len(argv) > 1 and argv[1] else None
    exp, ren, bl = os.path.join(root, "export"), os.path.join(root, "renders", "carros"), os.path.join(root, "blend")
    for d in (exp, ren, bl):
        os.makedirs(d, exist_ok=True)

    scene = L.reset_scene()
    L.add_lights(scene)
    L.add_ground(scene, 900)
    biomes = []
    info, built = [], []
    for car in CARS:
        if only and car["id"] not in only:
            continue
        if car["biome"] not in biomes:
            biomes.append(car["biome"])
        P = car["P"]
        b = build(P)
        car["acc"](b, P)
        cv = Canvas(1024)
        car["paint"](cv)
        img = cv.image(f"{car['id']}_livery")
        img.filepath_raw = os.path.join(exp, f"{car['id']}_livery.png")
        img.file_format = "PNG"
        img.save()
        objs = place(b, car["id"], scene, livery=img)
        export_fbx(objs, os.path.join(exp, f"{car['id']}.fbx"))
        col = "ABC".index(car["variant"])
        off = ((col - 1) * 16.0, biomes.index(car["biome"]) * 30.0, 0)
        for ob in objs.values():
            ob.location = off
        tris = b.tris()
        info.append(dict(id=car["id"], name=car["name"], biome=car["biome"], body=car["variant"], tris=sum(tris.values()), parts=tris,
                         wheels=dict(fx=P["fx"], fy=P["fy"], rx=P["rx"], ry=P["ry"], fr=P["fr"], rr=P["rr"], fw=P["fw"], rw=P["rw"])))
        built.append((car, off))
        print("CARRO", car["id"], sum(tris.values()), tris)

    with open(os.path.join(exp, "carros.json"), "w", encoding="utf8") as f:
        json.dump(info, f, indent=1, ensure_ascii=False)

    paths = []
    for car, off in built:
        for c2, _ in built:
            bpy.data.collections[c2["id"]].hide_render = c2 is not car
        L.camera(scene, (off[0] - 15, off[1] - 17.5, 8.2), (off[0], off[1] - 0.6, 1.5), lens=36)
        p = os.path.join(ren, f"{car['id']}.png")
        L.render(scene, p, (800, 450))
        paths.append(p)
    for c2, _ in built:
        bpy.data.collections[c2["id"]].hide_render = False
    if len(paths) > 1:
        L.contact_sheet(paths, os.path.join(root, "renders", "carros_f1.png"), 3)
    if not only:
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(bl, "f1_carros.blend"))
    print("FEITO", len(built))


if __name__ == "__main__":
    main()
