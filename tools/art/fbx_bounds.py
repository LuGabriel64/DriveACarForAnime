"""
fbx_bounds.py — caixa (bounding box) de cada objeto de um ou mais FBX, já nos eixos do Roblox (x, z, -y do Blender).

  blender --background --python tools/art/fbx_bounds.py -- arte/export/gokun_v3_game.fbx [...]

Serve para achar onde a origem do Blender (pés do personagem, x = 0, y = 0) caiu depois que o Roblox importou o
modelo: o importador coloca cada MeshPart no centro da caixa da malha. Compare o centro daqui com o Position do
MeshPart no Studio e a diferença é o deslocamento (o mesmo para todas as peças).
"""
import json
import sys

import bpy
from mathutils import Vector

files = sys.argv[sys.argv.index("--") + 1:]
out = {}
for path in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    row = {}
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        c, s = (lo + hi) / 2, hi - lo
        row[ob.name] = dict(center=[round(c.x, 4), round(c.z, 4), round(-c.y, 4)], size=[round(s.x, 4), round(s.z, 4), round(s.y, 4)])
    out[path.replace("\\", "/").split("/")[-1]] = row
print("FBXBOUNDS " + json.dumps(out))
