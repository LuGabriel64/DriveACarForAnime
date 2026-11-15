"""
f1_build.py — monta o carro de Fórmula a partir de parâmetros (3 carrocerias: A, B, C).

  A "Rookie"  linhas clássicas: asas menores, sidepods cheios, rodas com raios
  B "Pro"     efeito solo moderno: asa dianteira de 3 elementos, barbatana, calotas, halo
  C "Hyper"   protótipo futurista: canopy fechado, para-lamas, asa traseira alta, 2 turbinas

Uso (em segundo plano):
  blender --background --python arte/blender/f1_build.py -- clay <pasta_de_saida>
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy
from mathutils import Vector

import f1lib as L

CARBON = (0.075, 0.075, 0.085)
DARK = (0.03, 0.03, 0.035)
METAL = (0.55, 0.56, 0.60)
WHITE = (1.0, 1.0, 1.0)
TIRE = (0.04, 0.04, 0.045)
RED_LIGHT = (1.0, 0.12, 0.1)

BASE = dict(
    fx=3.9, fy=-6.0, rx=3.9, ry=5.6, fr=1.5, fw=1.5, rr=1.62, rw=1.95,
    nose_tip=-9.5, nose_z=0.72, fw_span=4.55, fw_elems=3, fw_y=-9.7,
    rw_span=3.0, rw_z=3.35, rw_chord=1.25,
    pod_w=1.0, pod_h=0.7, airbox=1.0,
    fin=True, halo=True, canopy=False, fenders=False, exhaust=1, covers=True,
    helmet=(0.95, 0.95, 0.95), rim=(0.82, 0.82, 0.85), stripe=(1.0, 0.85, 0.1),
)
VARIANTS = {
    "A": dict(BASE, fw_span=4.3, fw_elems=2, rw_span=3.3, rw_z=3.0, rw_chord=1.05, pod_w=1.15, pod_h=0.8,
              fin=False, covers=False, nose_tip=-9.0, nose_z=0.95, airbox=1.15),
    "B": dict(BASE),
    "C": dict(BASE, nose_tip=-10.0, nose_z=0.6, fw_span=4.7, rw_span=3.2, rw_z=3.6, rw_chord=1.4,
              pod_w=0.92, pod_h=0.62, canopy=True, halo=False, fenders=True, exhaust=2),
}


def _wheel(b, role, cx, cy, R, W, side, P):
    """Roda: pneu (preto), miolo escuro, calota ou raios e a faixa colorida do pneu. side = +1 (direita) / -1."""
    o = side
    tire = [(0.60 * R, -W / 2), (0.90 * R, -W / 2), (R, -W / 2 + 0.24), (R, W / 2 - 0.24), (0.90 * R, W / 2), (0.60 * R, W / 2)]
    b.add(role, L.lathe(tire, (cx, cy, R), 28), TIRE)
    hub = [(0.0, -W / 2 + 0.22), (0.61 * R, -W / 2 + 0.22), (0.61 * R, W / 2 - 0.22), (0.0, W / 2 - 0.22)]
    b.add(role, L.lathe(hub, (cx, cy, R), 20), DARK)
    if P["covers"]:
        cover = [(0.0, o * (W / 2 - 0.13)), (0.30 * R, o * (W / 2 - 0.10)), (0.615 * R, o * (W / 2 - 0.03)),
                 (0.615 * R, o * (W / 2 - 0.20)), (0.0, o * (W / 2 - 0.20))]
        b.add(role, L.lathe(cover, (cx, cy, R), 24), P["rim"])
    else:
        xo = cx + o * (W / 2 - 0.12)
        for k in range(5):
            a = 2 * math.pi * k / 5
            tip = (xo, cy + 0.6 * R * math.cos(a), R + 0.6 * R * math.sin(a))
            b.add(role, L.strut((xo, cy, R), tip, 0.22, 0.12), P["rim"], smooth=False)
        ring = [(0.52 * R, o * (W / 2 - 0.2)), (0.62 * R, o * (W / 2 - 0.2)), (0.62 * R, o * (W / 2 - 0.03)), (0.52 * R, o * (W / 2 - 0.03))]
        b.add(role, L.lathe(ring, (cx, cy, R), 24), P["rim"])
    nut = [(0.0, o * (W / 2 - 0.2)), (0.1 * R, o * (W / 2 - 0.2)), (0.08 * R, o * (W / 2 + 0.03)), (0.0, o * (W / 2 + 0.03))]
    b.add(role, L.lathe(nut, (cx, cy, R), 10), METAL)
    stripe = [(0.74 * R, o * (W / 2 - 0.02)), (0.83 * R, o * (W / 2 - 0.02)), (0.83 * R, o * (W / 2 + 0.025)), (0.74 * R, o * (W / 2 + 0.025))]
    b.add(role, L.lathe(stripe, (cx, cy, R), 28), P["stripe"])


def build(P):
    b = L.Builder()
    fx, fy, rx, ry, fr, fw, rr, rw = (P[k] for k in ("fx", "fy", "rx", "ry", "fr", "fw", "rr", "rw"))
    nt, nz, ab = P["nose_tip"], P["nose_z"], P["airbox"]

    # ---- monocoque + bico + capô do motor
    mono = [
        (nt, 0, nz, 0.22, 0.16, 2.2),
        (nt + 1.4, 0, nz + 0.2, 0.48, 0.28, 2.4),
        (-6.0, 0, 1.22, 0.70, 0.42, 2.6),
        (-3.6, 0, 1.42, 0.95, 0.60, 3.0),
        (-1.9, 0, 1.50, 1.15, 0.75, 3.2),
        (0.5, 0, 1.56, 1.20, 0.86, 3.0),
        (1.9, 0, 1.60 + 0.3 * ab, 1.00, 0.85 + 0.3 * ab, 2.4),
        (4.0, 0, 1.65, 0.70, 0.85, 2.2),
        (6.0, 0, 1.32, 0.42, 0.52, 2.0),
        (7.5, 0, 1.12, 0.24, 0.30, 2.0),
    ]
    b.add("Body", L.loft(mono, K=20, sub=4), WHITE)
    b.add("Trim", L.box((0, -1.4, 0.62), (1.5, 5.2, 0.5)), CARBON, smooth=False)  # quilha sob o cockpit

    # ---- sidepods
    pw, ph = P["pod_w"], P["pod_h"]
    pod = [
        (-2.7, 2.05, 1.28, 0.75 * pw, 0.78 * ph, 4.0),
        (-1.2, 2.10, 1.22, 0.95 * pw, 1.00 * ph, 3.5),
        (1.5, 2.05, 1.12, 1.00 * pw, 1.00 * ph, 3.0),
        (3.8, 1.70, 0.95, 0.75 * pw, 0.75 * ph, 2.6),
        (6.0, 1.10, 0.80, 0.38 * pw, 0.42 * ph, 2.2),
    ]
    b.add("Body", L.loft(pod, K=16, sub=4), WHITE, mirror=True)
    b.add("Trim", L.box((2.05, -2.72, 1.28), (1.25 * pw, 0.08, 1.15 * ph)), DARK, smooth=False, mirror=True)  # entrada de ar

    # ---- assoalho, difusor e defletores
    floor = [(-0.9, -3.9), (0.9, -3.9), (2.9, -2.5), (3.05, 3.2), (2.72, 4.1), (2.3, 7.0), (-2.3, 7.0), (-2.72, 4.1), (-3.05, 3.2), (-2.9, -2.5)]
    b.add("Trim", L.prism(floor, "Z", 0.22, 0.40), CARBON, smooth=False)
    b.add("Trim", L.prism([(5.4, 0.22), (7.9, 0.95), (7.9, 1.1), (5.4, 0.4)], "X", -2.2, 2.2), CARBON, smooth=False)
    for sx in (-1.5, -0.5, 0.5, 1.5):
        b.add("Trim", L.prism([(5.6, 0.25), (7.9, 0.25), (7.9, 0.95), (5.6, 0.32)], "X", sx - 0.04, sx + 0.04), CARBON, smooth=False)
    b.add("Trim", L.prism([(-3.3, 0.4), (-2.1, 0.4), (-2.1, 1.15), (-3.3, 0.85)], "X", 2.62, 2.72), CARBON, smooth=False, mirror=True)
    b.add("Trim", L.prism([(-2.0, 0.4), (3.0, 0.4), (3.0, 0.62), (-2.0, 0.7)], "X", 2.96, 3.04), CARBON, smooth=False, mirror=True)

    # ---- asa dianteira
    S, wy, N = P["fw_span"], P["fw_y"], 6
    st = []
    for i in range(-N, N + 1):
        x = S * i / N
        ax = abs(x) / S
        st.append((x, wy + 1.0 * ax ** 1.6, 0.42 + 0.05 * (1 - ax), 0.95 - 0.2 * ax, 5, 0.11))
    b.add("Body", L.wing(st), WHITE, smooth=False)
    for e in range(1, P["fw_elems"]):
        st = []
        for i in range(N + 1):
            x = 0.55 + (S - 0.55) * i / N
            ax = x / S
            st.append((x, wy + 1.0 * ax ** 1.6 + 0.78 * e, 0.44 + 0.27 * e, 0.72 - 0.12 * ax, 12 + 10 * e, 0.08))
        b.add("Body", L.wing(st), WHITE, smooth=False, mirror=True)
    ep_top = 0.9 + 0.3 * P["fw_elems"] / 3
    ep = [(wy + 1.05, 0.2), (wy + 2.9, 0.2), (wy + 3.0, ep_top + 0.25), (wy + 2.1, ep_top + 0.2), (wy + 1.1, 0.62)]
    b.add("Body", L.prism(ep, "X", S - 0.06, S + 0.06), WHITE, smooth=False, mirror=True)
    b.add("Trim", L.box((0.3, nt + 0.55, (nz + 0.42) / 2 + 0.02), (0.1, 0.5, max(0.08, nz - 0.5))), CARBON, smooth=False, mirror=True)

    # ---- asa traseira
    RS, rz, rc = P["rw_span"], P["rw_z"], P["rw_chord"]
    st = [(RS * i / 4, 7.1, rz - 0.16 * (1 - abs(i) / 4), rc, 9, 0.16) for i in range(-4, 5)]
    b.add("Body", L.wing(st), WHITE, smooth=False)
    st = [(RS * i / 4, 7.15 + rc * 0.82, rz + 0.36, rc * 0.48, 30, 0.1) for i in range(-4, 5)]
    b.add("Body", L.wing(st), WHITE, smooth=False)
    ep = [(6.45, 1.55), (8.75, 1.55), (8.85, rz + 0.78), (7.0, rz + 0.55), (6.35, rz - 0.75)]
    b.add("Body", L.prism(ep, "X", RS - 0.06, RS + 0.06), WHITE, smooth=False, mirror=True)
    b.add("Trim", L.wing([(2.1 * i / 2, 7.0, 1.72, 0.62, 14, 0.09) for i in range(-2, 3)]), CARBON, smooth=False)
    b.add("Trim", L.strut((0.28, 6.5, 1.5), (0.28, 7.55, rz - 0.1), 0.09, 0.42), CARBON, smooth=False, mirror=True)
    b.add("Glow", L.box((0, 7.82, 1.18), (0.34, 0.14, 0.5)), RED_LIGHT, smooth=False)

    # ---- barbatana do motor, tomada de ar, espelhos
    if P["fin"]:
        b.add("Body", L.prism([(2.0, 2.2), (2.9, 3.28), (7.0, 2.25), (7.0, 1.45), (4.0, 1.9)], "X", -0.045, 0.045), WHITE, smooth=False)
    top = 1.60 + 0.3 * ab + 0.85 + 0.3 * ab
    b.add("Trim", L.sphere((0, 1.02, top - 0.42), 0.36, 12, 6, (1.15, 0.35, 0.8)), DARK)
    b.add("Trim", L.box((0, 1.75, top + 0.1), (0.75, 0.3, 0.07)), CARBON, smooth=False)  # câmera em T
    b.add("Trim", L.box((0, 1.75, top + 0.0), (0.1, 0.22, 0.2)), CARBON, smooth=False)
    b.add("Body", L.box((1.78, -1.3, 2.28), (0.6, 0.22, 0.32)), WHITE, smooth=False, mirror=True)
    b.add("Trim", L.strut((1.05, -1.3, 2.02), (1.6, -1.3, 2.22), 0.07, 0.07), CARBON, smooth=False, mirror=True)

    # ---- cockpit: abertura escura, capacete, halo ou canopy
    b.add("Trim", L.sphere((0, -0.75, 2.2), 0.82, 14, 6, (1.0, 1.55, 0.3)), DARK)
    if P["canopy"]:
        can = [(-2.9, 0, 2.02, 0.45, 0.2, 2.0), (-1.7, 0, 2.3, 0.9, 0.48, 2.2), (-0.3, 0, 2.5, 0.98, 0.62, 2.2),
               (1.1, 0, 2.62, 0.82, 0.5, 2.2), (2.0, 0, 2.66, 0.5, 0.3, 2.0)]
        b.add("Glass", L.loft(can, K=16, sub=4), (0.08, 0.12, 0.18))
    else:
        b.add("Trim", L.sphere((0, -0.45, 2.56), 0.45, 14, 8, (0.95, 1.08, 0.95)), P["helmet"])
        b.add("Trim", L.box((0, -0.86, 2.6), (0.62, 0.16, 0.2)), DARK, smooth=False)
    if P["halo"]:
        b.add("Trim", L.tube([(0, -2.45, 2.0), (0, -2.05, 2.6), (0, -1.75, 3.0)], 0.12, 8), CARBON)
        ring = [(0, -1.8, 3.02), (0.45, -1.55, 3.08), (0.92, -0.7, 3.08), (1.05, 0.3, 2.95), (0.98, 1.1, 2.62), (0.9, 1.45, 2.35)]
        b.add("Trim", L.tube(ring, 0.12, 8), CARBON, mirror=True)

    # ---- suspensão e semi-eixos
    for cy, R, tubx, hz, top_z in ((fy, fr, 0.70, 1.0, 1.6), (ry, rr, 0.45, 0.85, 1.5)):
        hx = fx - 0.78 if cy == fy else rx - 1.0
        b.add("Trim", L.strut((tubx, cy - 0.95, top_z), (hx, cy, R + 0.42), 0.09, 0.22), CARBON, smooth=False, mirror=True)
        b.add("Trim", L.strut((tubx, cy + 0.95, top_z), (hx, cy, R + 0.42), 0.09, 0.22), CARBON, smooth=False, mirror=True)
        b.add("Trim", L.strut((tubx - 0.1, cy - 0.95, hz), (hx, cy, R - 0.5), 0.09, 0.22), CARBON, smooth=False, mirror=True)
        b.add("Trim", L.strut((tubx - 0.1, cy + 0.95, hz), (hx, cy, R - 0.5), 0.09, 0.22), CARBON, smooth=False, mirror=True)
        b.add("Trim", L.strut((tubx, cy + 0.25, top_z - 0.05), (hx, cy, R - 0.3), 0.08, 0.1), CARBON, smooth=False, mirror=True)
    b.add("Trim", L.tube([(0.3, ry, rr), (rx - 0.95, ry, rr)], 0.13, 8), METAL, mirror=True)

    # ---- escapamento
    if P["exhaust"] == 1:
        ex = [(0.14, 0.0), (0.24, 0.0), (0.26, 0.75), (0.16, 0.75)]
        b.add("Trim", L.lathe(ex, (0, 7.35, 1.3), 14, axis="Y"), METAL)
    else:
        ex = [(0.30, 0.0), (0.46, 0.0), (0.50, 1.7), (0.34, 1.7)]
        b.add("Trim", L.lathe(ex, (0.62, 6.3, 1.78), 16, axis="Y"), METAL, mirror=True)
        b.add("Glow", L.lathe([(0.0, 1.2), (0.33, 1.2), (0.33, 1.3), (0.0, 1.3)], (0.62, 6.3, 1.78), 14, axis="Y"), (1.0, 0.55, 0.1), mirror=True)

    # ---- para-lamas e aletas (carroceria C)
    if P["fenders"]:
        fe = [(fr + 0.12, -fw / 2 - 0.08), (fr + 0.24, -fw / 2 - 0.08), (fr + 0.24, fw / 2 + 0.08), (fr + 0.12, fw / 2 + 0.08)]
        ob = L.lathe(fe, (fx, fy, fr), 12, arc=(28, 188))
        b.add("Body", ob, WHITE, mirror=True)
        fe = [(rr + 0.12, -rw / 2 - 0.08), (rr + 0.24, -rw / 2 - 0.08), (rr + 0.24, rw / 2 + 0.08), (rr + 0.12, rw / 2 + 0.08)]
        b.add("Body", L.lathe(fe, (rx, ry, rr), 12, arc=(60, 190)), WHITE, mirror=True)
        b.add("Body", L.prism([(3.2, 0.9), (6.6, 0.75), (6.9, 2.5), (5.6, 1.5)], "X", 1.55, 1.63), WHITE, smooth=False, mirror=True)

    # ---- rodas
    _wheel(b, "Wheel_FR", fx, fy, fr, fw, 1, P)
    _wheel(b, "Wheel_FL", -fx, fy, fr, fw, -1, P)
    _wheel(b, "Wheel_RR", rx, ry, rr, rw, 1, P)
    _wheel(b, "Wheel_RL", -rx, ry, rr, rw, -1, P)
    return b


def place(builder, prefix, scene, offset=(0, 0, 0), clay=False, livery=None):
    """Cria os objetos na cena e aplica os materiais de pré-visualização."""
    coll = bpy.data.collections.new(prefix)
    scene.collection.children.link(coll)
    objs = L.to_objects(builder, prefix, coll)
    for role, ob in objs.items():
        ob.location = offset
        if clay:
            m = L.mat_clay()
        elif role == "Body" and livery is not None:
            m = L.mat_livery(f"Livery_{prefix}", livery)
        elif role == "Glow":
            m = L.mat_vertex_emit()
        elif role == "Glass":
            m = L.mat_glass()
        elif role.startswith("Wheel"):
            m = L.mat_vertex("WheelVC", 0.75)
        else:
            m = L.mat_vertex("VC", 0.45)
        ob.data.materials.append(m)
    return objs


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = argv[0] if argv else "clay"
    out = argv[1] if len(argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "renders")
    os.makedirs(out, exist_ok=True)
    if mode == "clay":
        scene = L.reset_scene()
        L.add_lights(scene)
        L.add_ground(scene)
        for i, v in enumerate("ABC"):
            bd = build(VARIANTS[v])
            print("TRIS", v, bd.tris(), sum(bd.tris().values()))
            place(bd, f"F1{v}", scene, offset=((i - 1) * 13.0, 0, 0), clay=True)
        L.camera(scene, (-30, -34, 15), (0, -1, 1.2), lens=58)
        L.render(scene, os.path.join(out, "clay_frente.png"), (1600, 720))
        L.camera(scene, (30, 36, 14), (0, 1, 1.2), lens=58)
        L.render(scene, os.path.join(out, "clay_tras.png"), (1600, 720))


if __name__ == "__main__":
    main()
