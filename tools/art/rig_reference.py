"""
rig_reference.py — pontos de referência para conferir o Shared.CharacterRig (Roblox) contra a matemática do Blender.

  blender --background --python tools/art/rig_reference.py

Para cada animação e instante, imprime onde vai parar um ponto de teste de cada peça (em studs, já nos eixos do
Roblox: x, z, -y). No Studio, o mesmo ponto calculado com rig._nodes[i].World tem de dar o mesmo número.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "arte", "blender"))

import char_hero as C  # noqa: E402
from mathutils import Vector  # noqa: E402

with open(os.path.join(ROOT, "arte", "export", "personagens_anim.json"), "r", encoding="utf-8") as f:
    data = json.load(f)

PAIRS = (("gokun", "gokun_v3", "gokun"), ("super_gokun", "super_gokun_v3", "super"), ("mini_gokun", "mini_gokun_v3_classic", "mini"))
PROBE = (1.0, -2.0, 3.0)        # ponto de teste, em studs, nos eixos do Blender
out = {}
for game_id, key, anim_id in PAIRS:
    a = data[key]
    scale = C.SPECS["gokun" if anim_id != "mini" else "mini_classic"]["scale"]
    joints = {k: [c / scale for c in v] for k, v in a["joints"].items()}
    drop = a["drop"] / scale
    for t in (0.0, 0.37, 1.9):
        mats = C.pose_mats(C.IDLE[anim_id], joints, scale, t, drop)
        row = {}
        for part in a["joints"]:
            if part == "Root":
                continue
            p = mats[part] @ Vector(PROBE)
            row[part] = [round(p.x, 3), round(p.z, 3), round(-p.y, 3)]
        out[f"{game_id}@{t}"] = row
print("RIGREF " + json.dumps(out))
