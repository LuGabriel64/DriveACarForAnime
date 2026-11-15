"""
f1_themes.py — as 21 pinturas (3 carros por bioma) e os acessórios temáticos dos carros de Fórmula.

PINTURA: uma textura 1024x1024 por carro, pintada por código (numpy), sem arquivo externo e sem logotipo de
marca. Metade de cima = vista lateral (vale para os dois lados); metade de baixo = vista de cima.
As coordenadas são as do carro em studs (Y = comprimento, Z = altura, X = largura), então um desenho feito
em "studs" cai no lugar certo da carroceria (ver f1lib.body_uv).

ACESSÓRIOS: peças com cor por vértice (papel "Acc"), brilho (papel "Glow") ou vidro ("Glass").

Regra de propriedade intelectual: o bioma 1 usa só CORES e FORMAS genéricas do tema (laranja/azul, cabelo
espetado, cauda, aura). Nada de kanji, emblemas, esferas com estrelas ou logotipos.
"""
import math

import bpy
import numpy as np

import f1lib as L
from f1_build import CARBON, DARK, METAL, VARIANTS


def rgb(r, g, b):
    return (r / 255.0, g / 255.0, b / 255.0)


# ============================================================================ tela de pintura


class Canvas:
    def __init__(self, n=1024):
        self.n, self.h = n, n // 2
        Y = L.UV_YMIN + (np.arange(n) + 0.5) / n * (L.UV_YMAX - L.UV_YMIN)
        v = (np.arange(self.h) + 0.5) / self.h
        self.sY, self.sZ = np.meshgrid(Y, v * L.UV_ZMAX)
        self.tY, self.tX = np.meshgrid(Y, (v * 2 - 1) * L.UV_XMAX)
        self.side = np.zeros((self.h, n, 3), np.float32)
        self.top = np.zeros((self.h, n, 3), np.float32)

    def arr(self, region):
        return self.side if region == "s" else self.top

    def coords(self, region):
        return (self.sY, self.sZ) if region == "s" else (self.tY, self.tX)

    def fill(self, col):
        self.side[:] = col
        self.top[:] = col

    def put(self, region, mask, col, a=1.0):
        arr = self.arr(region)
        m = (np.asarray(mask, np.float32) * a)[..., None]
        arr[:] = arr * (1 - m) + np.asarray(col, np.float32) * m

    def image(self, name):
        px = np.ones((self.n, self.n, 4), np.float32)
        px[: self.h, :, :3] = np.clip(self.top, 0, 1)
        px[self.h:, :, :3] = np.clip(self.side, 0, 1)
        img = bpy.data.images.new(name, self.n, self.n, alpha=False)
        img.pixels.foreach_set(px.ravel())
        return img


def vnoise(A, B, freq, seed):
    T = np.random.RandomState(seed).rand(64, 64).astype(np.float32)
    a, b = A * freq, B * freq
    ai, bi = np.floor(a).astype(int), np.floor(b).astype(int)
    fa, fb = a - ai, b - bi
    fa, fb = fa * fa * (3 - 2 * fa), fb * fb * (3 - 2 * fb)

    def t(i, j):
        return T[i % 64, j % 64]

    return (t(ai, bi) * (1 - fa) + t(ai + 1, bi) * fa) * (1 - fb) + (t(ai, bi + 1) * (1 - fa) + t(ai + 1, bi + 1) * fa) * fb


def fbm(A, B, freq, seed, octaves=3):
    out, amp, tot = 0, 1.0, 0.0
    for k in range(octaves):
        out = out + vnoise(A, B, freq * 2 ** k, seed + 7 * k) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def lerp(c0, c1, t):
    t = np.clip(t, 0, 1)[..., None]
    return np.asarray(c0, np.float32) * (1 - t) + np.asarray(c1, np.float32) * t


def scheme(c, body, lower=None, fwing=None, rwing=None, spine=None, lower_z=0.95):
    """Divisão básica: carroceria, parte de baixo, asa dianteira, asa traseira e faixa central."""
    c.fill(body)
    if lower is not None:
        c.put("s", c.sZ < lower_z, lower)
    if fwing is not None:
        c.put("s", (c.sY < -7.45) & (c.sZ < 1.6), fwing)
        c.put("t", (c.tY < -7.45) & (np.abs(c.tX) > 0.75), fwing)
    if rwing is not None:
        c.put("s", (c.sY > 6.3) & (c.sZ > 1.5), rwing)
        c.put("t", c.tY > 6.95, rwing)
    if spine is not None:
        c.put("t", (np.abs(c.tX) < 0.2) & (c.tY > -9) & (c.tY < 6.9), spine)


def band(c, y0, z0, y1, z1, w, col, a=1.0):
    """Faixa inclinada na lateral, de (y0,z0) a (y1,z1)."""
    line = z0 + (c.sY - y0) * (z1 - z0) / (y1 - y0)
    c.put("s", (np.abs(c.sZ - line) < w) & (c.sY > min(y0, y1)) & (c.sY < max(y0, y1)), col, a)


def gradient(c, c0, c1, y0, y1, regions="st", mask_s=None, mask_t=None):
    for r in regions:
        A, _ = c.coords(r)
        colarr = lerp(c0, c1, (A - y0) / (y1 - y0))
        m = np.ones(A.shape, bool)
        if r == "s" and mask_s is not None:
            m = mask_s
        if r == "t" and mask_t is not None:
            m = mask_t
        arr = c.arr(r)
        arr[m] = colarr[m]


def stamps(c, region, n, seed, shape, col, yr, sr, size, a=1.0):
    """Espalha formas pequenas: 'petal', 'star', 'snow', 'dot'."""
    rs = np.random.RandomState(seed)
    A, B = c.coords(region)
    for _ in range(n):
        y0, s0, R, ang = rs.uniform(*yr), rs.uniform(*sr), rs.uniform(*size), rs.uniform(0, 6.283)
        dy, ds = A - y0, B - s0
        win = (np.abs(dy) < R * 1.3) & (np.abs(ds) < R * 1.3)
        if not win.any():
            continue
        ca, sa = math.cos(ang), math.sin(ang)
        p, q = dy * ca + ds * sa, -dy * sa + ds * ca
        r, th = np.sqrt(p * p + q * q), np.arctan2(q, p)
        if shape == "petal":
            m = (p / R) ** 2 + (q / (0.5 * R)) ** 2 < 1
        elif shape == "star":
            m = r < R * (0.38 + 0.62 * (0.5 + 0.5 * np.cos(5 * th)) ** 2.5)
        elif shape == "snow":
            m = ((np.abs(np.sin(3 * th)) < 0.2) & (r < R)) | (r < 0.22 * R)
        else:
            m = r < R
        c.put(region, m & win, col, a)


def both(c, fn, col, a=1.0):
    """Aplica a mesma máscara (função de Y e da 2ª coordenada) na lateral e em cima."""
    c.put("s", fn(c.sY, c.sZ), col, a)
    c.put("t", fn(c.tY, np.abs(c.tX)), col, a)


# ============================================================================ pinturas (uma função por carro)

ORANGE, GI_BLUE, WHITE, BLACK = rgb(255, 128, 30), rgb(36, 84, 200), rgb(245, 245, 245), rgb(20, 20, 24)
GOLD = rgb(245, 190, 55)


def p_warrior_a(c):  # laranja e azul: quimono de treino
    scheme(c, ORANGE, lower=GI_BLUE, fwing=GI_BLUE, rwing=GI_BLUE, spine=WHITE)
    band(c, -6.5, 1.15, 6.5, 1.55, 0.14, GI_BLUE)                       # faixa (cinto) ao longo do carro
    c.put("s", (c.sY > -2.9) & (c.sY < -1.6) & (c.sZ > 0.95) & (c.sZ < 2.0), GI_BLUE)  # munhequeira no sidepod
    c.put("t", (np.abs(c.tX) > 1.3) & (c.tY > -2.9) & (c.tY < -1.7), GI_BLUE)


def p_warrior_b(c):  # branco, azul real e dourado: armadura de príncipe guerreiro
    scheme(c, WHITE, lower=rgb(28, 40, 150), fwing=rgb(28, 40, 150), rwing=GOLD, spine=rgb(28, 40, 150))
    c.put("t", (np.abs(c.tX) > 1.15) & (c.tY > -2.8) & (c.tY < 2.2), GOLD)        # ombreiras douradas (sidepods)
    c.put("s", (c.sY > -2.8) & (c.sY < 2.2) & (c.sZ > 1.25) & (c.sZ < 1.95), GOLD)
    for k in range(5):                                                              # gomos da armadura
        y = -2.4 + k * 1.0
        c.put("s", (np.abs(c.sY - y) < 0.045) & (c.sZ > 1.25) & (c.sZ < 1.95), rgb(170, 120, 20))
        c.put("t", (np.abs(c.tY - y) < 0.045) & (np.abs(c.tX) > 1.15), rgb(170, 120, 20))
    band(c, -9.5, 0.9, -3.0, 1.9, 0.1, rgb(28, 40, 150))


def p_warrior_c(c):  # dourado com aura: transformação
    c.fill(rgb(255, 214, 50))
    gradient(c, rgb(255, 235, 120), rgb(255, 150, 20), -9.5, 8.0)
    fl = lambda Y, S: S < 0.55 + 1.15 * np.abs(np.sin(Y * 1.15 + 0.6)) ** 0.7 * np.clip((Y + 9.5) / 6, 0.3, 1)
    c.put("s", fl(c.sY, c.sZ), rgb(255, 245, 190))
    c.put("s", fl(c.sY, c.sZ + 0.35), WHITE)
    c.put("s", (c.sY > 6.3) & (c.sZ > 1.5), BLACK)
    c.put("t", c.tY > 6.95, BLACK)
    c.put("s", (c.sY < -7.45) & (c.sZ < 1.6), BLACK)
    c.put("t", (c.tY < -7.45) & (np.abs(c.tX) > 0.75), BLACK)
    n = fbm(c.sY, c.sZ, 0.9, 11)
    c.put("s", (np.abs(n - 0.5) < 0.012) & (c.sZ > 1.0), rgb(120, 200, 255))        # raios


def p_sakura_a(c):  # rosa e branco com pétalas
    scheme(c, rgb(255, 170, 205), lower=WHITE, fwing=WHITE, rwing=rgb(235, 70, 130), spine=WHITE)
    stamps(c, "s", 46, 21, "petal", WHITE, (-8.5, 6.2), (1.0, 3.0), (0.16, 0.34))
    stamps(c, "s", 24, 22, "petal", rgb(235, 70, 130), (-8.5, 6.2), (1.0, 3.0), (0.14, 0.26))
    stamps(c, "t", 46, 23, "petal", WHITE, (-8.5, 6.5), (-2.8, 2.8), (0.16, 0.34))


def p_sakura_b(c):  # branco e vermelho de santuário, com dourado
    scheme(c, WHITE, lower=rgb(205, 35, 45), fwing=rgb(205, 35, 45), rwing=rgb(205, 35, 45), spine=rgb(205, 35, 45))
    band(c, -8.0, 0.95, 6.5, 2.3, 0.2, rgb(205, 35, 45))
    band(c, -8.0, 1.25, 6.5, 2.6, 0.05, GOLD)
    stamps(c, "s", 14, 31, "petal", rgb(255, 170, 205), (-2.0, 6.0), (1.2, 2.8), (0.16, 0.28))


def p_sakura_c(c):  # noite de lua: roxo profundo virando rosa
    c.fill(rgb(48, 26, 82))
    gradient(c, rgb(36, 20, 70), rgb(240, 110, 170), -9.5, 8.5)
    moon = lambda Y, S: (Y - 2.6) ** 2 + (S - 2.15) ** 2 < 0.62
    c.put("s", moon(c.sY, c.sZ), rgb(255, 244, 200))
    stamps(c, "s", 40, 41, "petal", rgb(255, 190, 220), (-9.0, 6.0), (0.8, 3.0), (0.12, 0.26))
    stamps(c, "t", 40, 42, "petal", rgb(255, 190, 220), (-9.0, 6.5), (-2.8, 2.8), (0.12, 0.26))
    c.put("s", (c.sY > 6.3) & (c.sZ > 1.5), rgb(255, 244, 200))
    c.put("t", c.tY > 6.95, rgb(255, 244, 200))


def p_dunes_a(c):  # areia e marrom, ondas de duna
    scheme(c, rgb(232, 196, 128), fwing=rgb(120, 78, 44), rwing=rgb(120, 78, 44), spine=rgb(120, 78, 44))
    wave = lambda Y, S: S < 1.0 + 0.28 * np.sin(Y * 0.9) + 0.12 * np.sin(Y * 2.3 + 1)
    c.put("s", wave(c.sY, c.sZ), rgb(196, 140, 78))
    c.put("s", wave(c.sY, c.sZ + 0.4), rgb(120, 78, 44))
    n = fbm(c.tY, c.tX, 1.4, 5)
    c.put("t", n > 0.62, rgb(214, 170, 100), 0.6)


def p_dunes_b(c):  # dourado com listras azul-lápis de faraó
    scheme(c, GOLD, lower=rgb(28, 58, 160), fwing=rgb(28, 58, 160), rwing=GOLD, spine=rgb(28, 58, 160))
    stripes = lambda Y, S: (np.mod(Y * 1.15, 1.0) < 0.42) & (Y > 0.6) & (Y < 6.6)
    c.put("s", stripes(c.sY, c.sZ) & (c.sZ > 0.95), rgb(28, 58, 160))
    c.put("t", stripes(c.tY, c.tX), rgb(28, 58, 160))
    band(c, -9.0, 0.95, -2.6, 1.9, 0.12, rgb(30, 170, 170))
    c.put("s", (c.sY > 6.3) & (c.sZ > 1.5) & (np.mod(c.sZ * 2.4, 1.0) < 0.45), rgb(28, 58, 160))


def p_dunes_c(c):  # pôr do sol: laranja virando roxo, com turquesa
    c.fill(rgb(255, 150, 60))
    for r in "st":
        A, B = c.coords(r)
        S = B if r == "s" else 2.2 - np.abs(B) * 0.5
        c.arr(r)[:] = lerp(rgb(110, 40, 130), rgb(255, 190, 70), (S - 0.4) / 2.6)
    sun = lambda Y, S: (Y - 0.2) ** 2 + (S - 1.25) ** 2 < 1.1
    c.put("s", sun(c.sY, c.sZ), rgb(255, 232, 150))
    c.put("s", c.sZ < 0.95, rgb(60, 24, 80))
    c.put("s", (c.sY < -7.45) & (c.sZ < 1.6), rgb(30, 190, 185))
    c.put("t", (c.tY < -7.45) & (np.abs(c.tX) > 0.75), rgb(30, 190, 185))
    c.put("s", (c.sY > 6.3) & (c.sZ > 1.5), rgb(30, 190, 185))
    c.put("t", c.tY > 6.95, rgb(30, 190, 185))


def p_tundra_a(c):  # branco e azul-gelo com flocos
    scheme(c, WHITE, lower=rgb(120, 200, 245), fwing=rgb(120, 200, 245), rwing=rgb(60, 130, 210), spine=rgb(120, 200, 245))
    stamps(c, "s", 30, 51, "snow", rgb(120, 200, 245), (-8.5, 6.0), (1.1, 3.0), (0.2, 0.4))
    stamps(c, "t", 30, 52, "snow", rgb(120, 200, 245), (-8.5, 6.5), (-2.8, 2.8), (0.2, 0.4))
    band(c, -9.5, 0.95, 6.5, 1.4, 0.08, rgb(60, 130, 210))


def p_tundra_b(c):  # geleira: ciano com rachaduras brancas
    scheme(c, rgb(70, 190, 220), lower=rgb(20, 80, 130), fwing=WHITE, rwing=WHITE, spine=WHITE)
    for r in "st":
        A, B = c.coords(r)
        n = fbm(A, B, 0.8, 61)
        c.put(r, np.abs(n - 0.5) < 0.016, WHITE)
        c.put(r, n > 0.66, rgb(150, 230, 245), 0.7)


def p_tundra_c(c):  # aurora: azul-marinho com faixas verdes e roxas
    c.fill(rgb(14, 22, 56))
    for r in "st":
        A, B = c.coords(r)
        S = B if r == "s" else 1.6 + np.abs(B) * 0.4
        w = S - (1.6 + 0.5 * np.sin(A * 0.55) + 0.2 * np.sin(A * 1.7))
        c.put(r, np.exp(-(w * 2.6) ** 2), rgb(60, 240, 160), 0.9)
        w2 = S - (2.3 + 0.4 * np.sin(A * 0.5 + 2))
        c.put(r, np.exp(-(w2 * 3.2) ** 2), rgb(170, 90, 255), 0.85)
    stamps(c, "s", 40, 71, "dot", WHITE, (-9.5, 8.5), (0.5, 4.2), (0.02, 0.05))
    c.put("s", (c.sY > 6.3) & (c.sZ > 1.5), rgb(60, 240, 160))
    c.put("t", c.tY > 6.95, rgb(60, 240, 160))


def p_volcano_a(c):  # carvão com listras laranja
    scheme(c, rgb(42, 40, 44), fwing=rgb(240, 110, 20), rwing=rgb(240, 110, 20), spine=rgb(240, 110, 20))
    band(c, -9.0, 0.9, 6.5, 2.2, 0.16, rgb(240, 110, 20))
    band(c, -9.0, 0.6, 6.5, 1.9, 0.06, rgb(255, 200, 60))


def p_volcano_b(c):  # magma: preto com veios de lava
    scheme(c, rgb(22, 20, 22), fwing=rgb(200, 50, 10), rwing=rgb(22, 20, 22))
    for r in "st":
        A, B = c.coords(r)
        n = fbm(A, B, 0.75, 81)
        c.put(r, np.abs(n - 0.5) < 0.05, rgb(200, 50, 10))
        c.put(r, np.abs(n - 0.5) < 0.022, rgb(255, 150, 20))
        c.put(r, np.abs(n - 0.5) < 0.007, rgb(255, 235, 140))


def p_volcano_c(c):  # inferno: vermelho, preto e dourado com chamas
    scheme(c, rgb(190, 22, 18), fwing=BLACK, rwing=BLACK, spine=GOLD)
    fl = lambda Y, S: S < 0.5 + 1.5 * np.abs(np.sin(Y * 0.95 + 0.3)) ** 0.6 * np.clip(1 - (Y + 9.5) / 20, 0.35, 1)
    c.put("s", fl(c.sY, c.sZ), BLACK)
    c.put("s", fl(c.sY, c.sZ + 0.3), rgb(255, 140, 20))
    c.put("s", fl(c.sY, c.sZ + 0.62), rgb(255, 225, 90))


def p_city_a(c):  # asfalto com verde-limão neon
    scheme(c, rgb(46, 48, 56), fwing=rgb(190, 255, 40), rwing=rgb(190, 255, 40), spine=rgb(190, 255, 40))
    for k in range(4):
        band(c, -6.0 + k * 2.4, 0.5, -3.2 + k * 2.4, 2.9, 0.14, rgb(190, 255, 40))
    c.put("s", c.sZ < 0.7, rgb(20, 20, 24))


def p_city_b(c):  # roxo profundo com circuitos ciano
    scheme(c, rgb(52, 20, 110), lower=rgb(18, 10, 40), fwing=rgb(40, 230, 250), rwing=rgb(40, 230, 250))
    for r in "st":
        A, B = c.coords(r)
        cell = vnoise(np.floor(A * 0.9), np.floor(B * 1.6), 1.0, 91)
        ly = (np.mod(A * 0.9, 1.0) < 0.07) & (cell > 0.45)
        lz = (np.mod(B * 1.6, 1.0) < 0.1) & (cell < 0.6)
        c.put(r, ly | lz, rgb(40, 230, 250))
        dot = ((np.mod(A * 0.9, 1.0) - 0.035) ** 2 * 1.2 + (np.mod(B * 1.6, 1.0) - 0.05) ** 2 * 0.4 < 0.004) & (cell > 0.3)
        c.put(r, dot, rgb(255, 80, 220))


def p_city_c(c):  # glitch: preto com barras magenta e ciano
    scheme(c, rgb(12, 12, 18), fwing=rgb(255, 40, 200), rwing=rgb(40, 230, 250))
    rs = np.random.RandomState(101)
    for _ in range(34):
        y0, z0, ln, th = rs.uniform(-9, 6), rs.uniform(0.5, 3.2), rs.uniform(0.6, 3.2), rs.uniform(0.04, 0.16)
        col = rgb(255, 40, 200) if rs.rand() < 0.5 else rgb(40, 230, 250)
        c.put("s", (c.sY > y0) & (c.sY < y0 + ln) & (np.abs(c.sZ - z0) < th), col)
        x0 = rs.uniform(-2.8, 2.8)
        c.put("t", (c.tY > y0) & (c.tY < y0 + ln) & (np.abs(c.tX - x0) < th * 1.4), col)


def p_celestial_a(c):  # nuvens: branco e azul-céu
    scheme(c, rgb(120, 190, 255), fwing=WHITE, rwing=WHITE, spine=WHITE)
    for r in "st":
        A, B = c.coords(r)
        n = fbm(A, B * 1.6, 0.42, 111)
        c.put(r, n > 0.55, WHITE)
        c.put(r, (n > 0.52) & (n <= 0.55), rgb(200, 228, 255))


def p_celestial_b(c):  # arqueira das estrelas: azul-marinho e dourado
    scheme(c, rgb(20, 28, 84), lower=rgb(10, 14, 44), fwing=GOLD, rwing=GOLD, spine=GOLD)
    stamps(c, "s", 26, 121, "star", GOLD, (-8.5, 6.0), (1.1, 3.1), (0.14, 0.34))
    stamps(c, "t", 26, 122, "star", GOLD, (-8.5, 6.5), (-2.8, 2.8), (0.14, 0.34))
    stamps(c, "s", 50, 123, "dot", WHITE, (-9.5, 6.3), (0.9, 3.4), (0.02, 0.045))
    band(c, -9.5, 0.95, 6.5, 1.25, 0.06, GOLD)


def p_celestial_c(c):  # cometa da origem: branco perolado, dourado e rastro de estrelas
    c.fill(WHITE)
    gradient(c, WHITE, rgb(255, 226, 150), -9.5, 8.5)
    for k, col in enumerate((rgb(255, 200, 80), rgb(150, 200, 255), rgb(230, 170, 255))):
        band(c, -9.5, 0.7 + 0.28 * k, 6.5, 2.0 + 0.36 * k, 0.07, col)
    stamps(c, "s", 16, 131, "star", GOLD, (-6.0, 6.0), (1.6, 3.2), (0.16, 0.36))
    stamps(c, "t", 20, 132, "star", GOLD, (-8.0, 6.5), (-2.6, 2.6), (0.16, 0.36))
    c.put("s", (c.sY > 6.3) & (c.sZ > 1.5), GOLD)
    c.put("t", c.tY > 6.95, GOLD)
    c.put("s", (c.sY < -7.45) & (c.sZ < 1.6), GOLD)
    c.put("t", (c.tY < -7.45) & (np.abs(c.tX) > 0.75), GOLD)


# ============================================================================ acessórios


def _top(P):
    return 1.60 + 0.3 * P["airbox"] + 0.85 + 0.3 * P["airbox"]


def hair(b, P, col, size=1.0, role="Acc", extra=False):
    """Tufo de espinhos sobre a tomada de ar (cabelo espetado)."""
    z = _top(P) - 0.3
    base = (0, 2.2, z)
    fan = [(-1.15, 0.5, 0.75), (-0.6, 0.1, 1.45), (0.0, -0.35, 1.9), (0.6, 0.1, 1.45), (1.15, 0.5, 0.75), (0.0, 1.3, 1.25)]
    if extra:
        fan += [(-0.75, 1.1, 1.0), (0.75, 1.1, 1.0), (0.0, 0.5, 2.2)]
    for dx, dy, dz in fan:
        bs = (base[0] + dx * 0.32, base[1] + dy * 0.3, base[2])
        tp = (base[0] + dx * size, base[1] + dy * size, base[2] + dz * size)
        b.add(role, L.spike(bs, tp, 0.46 * size, 5, bend=(0, 0.12 * size, 0.1 * size)), col, smooth=False)


def tail(b, col):
    pts = [(0, 7.4, 1.25), (0.25, 8.2, 1.35), (0.5, 8.9, 1.9), (0.45, 9.1, 2.7), (0.1, 8.9, 3.3)]
    b.add("Acc", L.tube(pts, 0.16, 8, radii=[0.17, 0.17, 0.16, 0.14, 0.1]), col)


def flames(b, col, spots, role="Glow", r=0.3):
    for base, tip in spots:
        b.add(role, L.spike(base, tip, r, 4, bend=(0, 0.1, 0.15)), col, smooth=False)
        b.add(role, L.spike((-base[0], base[1], base[2]), (-tip[0], tip[1], tip[2]), r, 4, bend=(0, 0.1, 0.15)), col, smooth=False)


def ring(b, center, R, r, col, role="Glow"):
    prof = [(R + r * math.cos(a), r * math.sin(a)) for a in [k * math.pi / 3 for k in range(6)]]
    b.add(role, L.lathe(prof, center, 24, axis="Z"), col)


def feather_wings(b, P, col, tip_col):
    RS, rz = P["rw_span"], P["rw_z"]
    for k in range(5):
        root = (RS + 0.05, 7.3 + 0.1 * k, rz + 0.45 - 0.12 * k)
        tip = (RS + 1.5 + 0.28 * k, 7.9 + 0.55 * k, rz + 2.2 - 0.5 * k)
        b.add("Acc", L.strut(root, tip, 0.55, 0.07), col if k % 2 == 0 else tip_col, smooth=False, mirror=True)


def torii(b, P, red, black):
    RS, rz = P["rw_span"], P["rw_z"]
    b.add("Acc", L.box((RS, 7.9, rz + 1.1), (0.26, 0.26, 1.0)), red, smooth=False, mirror=True)
    b.add("Acc", L.box((0, 7.9, rz + 1.25), (2 * RS + 0.9, 0.24, 0.16)), red, smooth=False)
    b.add("Acc", L.box((0, 7.9, rz + 1.66), (2 * RS + 1.7, 0.34, 0.2)), black, smooth=False)
    b.add("Acc", L.box((0, 7.9, rz + 1.5), (2 * RS + 1.3, 0.28, 0.14)), red, smooth=False)


def neon_tubes(b, col):
    b.add("Glow", L.tube([(3.1, -2.4, 0.5), (3.14, 0.5, 0.5), (3.1, 3.1, 0.5)], 0.08, 6), col, mirror=True)
    b.add("Glow", L.tube([(0.9, -3.9, 0.47), (2.9, -2.55, 0.47)], 0.07, 6), col, mirror=True)


def disc(b, center, R, col, role="Acc", th=0.08):
    b.add(role, L.lathe([(0, -th), (R, -th), (R, th), (0, th)], center, 24, axis="Y"), col)


def flower(b, c, s, petal, mid):
    for k in range(5):
        a = 2 * math.pi * k / 5
        b.add("Acc", L.sphere((c[0] + s * 0.8 * math.cos(a), c[1], c[2] + s * 0.8 * math.sin(a)), s * 0.62, 8, 5, (1, 0.35, 1)), petal)
    b.add("Acc", L.sphere(c, s * 0.4, 8, 5, (1, 0.6, 1)), mid)


def crystals(b, col, spots, r=0.3, role="Acc"):
    for base, tip in spots:
        b.add(role, L.spike(base, tip, r, 4, mid=0.35), col, smooth=False)


def pipes(b, col=METAL):
    for k in range(3):
        y = 3.0 + 0.7 * k
        b.add("Acc", L.tube([(0.55, y, 2.1), (0.95, y + 0.25, 2.75), (1.05, y + 0.35, 3.0)], 0.15, 8), col, mirror=True)


def antenna(b, P, col, tip):
    z = _top(P)
    b.add("Acc", L.tube([(0.5, 2.6, z - 0.4), (0.55, 2.9, z + 1.5)], 0.035, 5), col)
    b.add("Glow", L.sphere((0.55, 2.9, z + 1.55), 0.12, 8, 5), tip)


def a_warrior_a(b, P):
    hair(b, P, rgb(20, 20, 26), 1.0)
    tail(b, rgb(110, 62, 30))


def a_warrior_b(b, P):
    hair(b, P, rgb(20, 20, 26), 1.15)                                    # crista em chama
    b.add("Acc", L.prism([(-2.9, 1.9), (2.4, 2.0), (2.9, 1.7), (-2.4, 1.6)], "X", 2.3, 3.25), GOLD, smooth=False, mirror=True)  # ombreiras
    b.add("Glass", L.box((-1.25, -0.9, 2.75), (0.08, 0.7, 0.5)), rgb(60, 230, 110), smooth=False)                             # visor verde
    b.add("Acc", L.strut((-1.0, -0.4, 2.7), (-1.25, -0.9, 2.75), 0.12, 0.2), WHITE, smooth=False)
    tail(b, rgb(92, 52, 26))


def a_warrior_c(b, P):
    hair(b, P, rgb(255, 222, 70), 1.3, extra=True)
    flames(b, rgb(255, 230, 90), [((2.3, -1.5, 1.9), (2.7, -0.4, 3.3)), ((2.4, 0.6, 1.8), (2.9, 1.9, 3.4)), ((2.0, 3.2, 1.6), (2.5, 4.6, 3.1)),
                                  ((0.6, -6.5, 1.6), (0.9, -5.6, 2.6)), ((1.4, 5.2, 1.6), (1.8, 6.6, 3.0))], r=0.34)
    ring(b, (0, 0.2, 0.34), 3.6, 0.07, rgb(255, 240, 150))


def a_sakura_a(b, P):
    flower(b, (1.78, -1.45, 2.28), 0.3, rgb(255, 190, 220), rgb(255, 220, 90))
    flower(b, (-1.78, -1.45, 2.28), 0.3, rgb(255, 190, 220), rgb(255, 220, 90))
    z = _top(P)
    b.add("Acc", L.tube([(0, 2.4, z - 0.3), (0.2, 3.0, z + 0.5), (0.7, 3.4, z + 0.9)], 0.07, 6), rgb(90, 56, 40))
    flower(b, (0.75, 3.4, z + 1.0), 0.26, rgb(255, 170, 205), rgb(255, 220, 90))
    flower(b, (0.15, 2.9, z + 0.6), 0.2, WHITE, rgb(255, 220, 90))


def a_sakura_b(b, P):
    torii(b, P, rgb(205, 35, 45), BLACK)
    RS, rz = P["rw_span"], P["rw_z"]
    for k in range(-2, 3):                                             # papéis brancos pendurados na trave
        x, z = k * RS * 0.36, rz + 1.2
        b.add("Acc", L.prism([(x - 0.14, z), (x + 0.14, z), (x + 0.2, z - 0.5), (x, z - 0.38), (x - 0.2, z - 0.5)], "Y", 8.05, 8.09), WHITE, smooth=False)


def a_sakura_c(b, P):
    RS, rz = P["rw_span"], P["rw_z"]
    for sx in (-1, 1):
        b.add("Acc", L.tube([(sx * RS, 8.6, rz + 0.5), (sx * RS, 8.75, rz + 0.1)], 0.03, 5), BLACK)
        b.add("Glow", L.sphere((sx * RS, 8.78, rz - 0.25), 0.36, 10, 6, (1, 1, 1.25)), rgb(255, 170, 90))
        b.add("Acc", L.box((sx * RS, 8.78, rz + 0.22), (0.3, 0.3, 0.08)), BLACK, smooth=False)
    ring(b, (0, 2.3, _top(P) + 0.9), 0.75, 0.05, rgb(255, 244, 200))


def a_dunes_a(b, P):
    b.add("Acc", L.tube([(-1.5, 1.9, 2.3), (-1.5, 2.2, 3.5), (1.5, 2.2, 3.5), (1.5, 1.9, 2.3)], 0.12, 8), rgb(60, 60, 66))
    b.add("Acc", L.box((2.25, 2.6, 2.0), (0.5, 1.0, 0.8)), rgb(190, 60, 40), smooth=False, mirror=True)
    b.add("Glow", L.box((0, 2.05, 3.62), (1.6, 0.14, 0.2)), rgb(255, 240, 180), smooth=False)


def a_dunes_b(b, P):
    z = _top(P)
    disc(b, (0, 2.9, z + 0.75), 0.7, rgb(255, 210, 70), role="Glow")
    crystals(b, GOLD, [((0.5, 2.9, z + 0.2), (1.1, 2.9, z + 1.5)), ((-0.5, 2.9, z + 0.2), (-1.1, 2.9, z + 1.5))], r=0.2)
    for k in range(4):
        b.add("Acc", L.prism([(3.2 + k * 0.85, 1.9), (3.6 + k * 0.85, 1.85), (3.6 + k * 0.85, 2.9 - 0.2 * k), (3.2 + k * 0.85, 3.0 - 0.2 * k)], "X", -0.1, 0.1),
              rgb(28, 58, 160) if k % 2 == 0 else GOLD, smooth=False)


def a_dunes_c(b, P):
    for sx in (1,):
        wing = [(1.4, 2.2), (4.6, 2.9), (5.4, 2.3), (4.4, 1.7), (1.6, 1.7)]
        b.add("Acc", L.prism([(y, z) for y, z in wing], "X", 1.25, 1.33), rgb(30, 190, 185), smooth=False, mirror=True)
        b.add("Acc", L.prism([(2.0, 2.1), (4.3, 2.55), (4.6, 2.2), (2.2, 1.85)], "X", 1.33, 1.37), GOLD, smooth=False, mirror=True)
    disc(b, (0, 1.2, _top(P) + 0.7), 0.6, rgb(255, 190, 70), role="Glow")
    crystals(b, rgb(30, 60, 70), [((0.35, -8.6, 0.9), (0.9, -9.9, 1.5)), ((-0.35, -8.6, 0.9), (-0.9, -9.9, 1.5))], r=0.14)


def a_tundra_a(b, P):
    z = _top(P)
    crystals(b, WHITE, [((0.55, 1.6, z - 0.3), (0.95, 1.5, z + 0.9)), ((-0.55, 1.6, z - 0.3), (-0.95, 1.5, z + 0.9))], r=0.36)
    crystals(b, rgb(255, 170, 190), [((0.62, 1.52, z + 0.0), (0.9, 1.47, z + 0.62)), ((-0.62, 1.52, z + 0.0), (-0.9, 1.47, z + 0.62))], r=0.16)
    b.add("Acc", L.tube([(0, 7.4, 1.3), (0, 8.4, 1.7), (0, 9.0, 2.5)], 0.3, 8, radii=[0.2, 0.34, 0.12]), WHITE)


def a_tundra_b(b, P):
    ice = rgb(170, 235, 250)
    crystals(b, ice, [((0, 2.6, 2.6), (0, 3.2, 4.3)), ((0.3, 3.6, 2.4), (0.6, 4.4, 3.7)), ((-0.3, 4.4, 2.2), (-0.6, 5.3, 3.3)),
                      ((2.3, -0.5, 1.8), (2.9, 0.2, 2.9)), ((-2.3, -0.5, 1.8), (-2.9, 0.2, 2.9)), ((2.2, 1.6, 1.7), (2.7, 2.6, 2.6)), ((-2.2, 1.6, 1.7), (-2.7, 2.6, 2.6))],
             r=0.34, role="Glass")


def a_tundra_c(b, P):
    RS, rz = P["rw_span"], P["rw_z"]
    for k, col in enumerate((rgb(60, 240, 160), rgb(170, 90, 255))):
        pts = [(sx, 8.9 + 0.5 * math.sin(sx * 1.4 + k), rz + 0.9 + 0.5 * k + 0.25 * math.sin(sx * 2 + k)) for sx in [-RS + i * (2 * RS / 8) for i in range(9)]]
        b.add("Glow", L.tube(pts, 0.09, 6), col)
    crystals(b, rgb(170, 235, 250), [((RS, 7.6, rz + 0.7), (RS + 0.3, 7.9, rz + 1.9)), ((-RS, 7.6, rz + 0.7), (-RS - 0.3, 7.9, rz + 1.9))], r=0.26, role="Glass")
    neon_tubes(b, rgb(60, 240, 160))


def a_volcano_a(b, P):
    pipes(b)


def a_volcano_b(b, P):
    flames(b, rgb(255, 120, 20), [((0.9, 4.0, 2.0), (1.2, 5.6, 3.3)), ((1.9, 3.0, 1.6), (2.5, 4.8, 2.8)), ((0.3, 6.6, 1.6), (0.5, 8.3, 2.6))], r=0.3)
    crystals(b, rgb(40, 34, 36), [((2.4, -1.0, 1.85), (2.8, -0.4, 2.6)), ((-2.4, -1.0, 1.85), (-2.8, -0.4, 2.6)), ((2.3, 0.8, 1.8), (2.7, 1.5, 2.5)), ((-2.3, 0.8, 1.8), (-2.7, 1.5, 2.5))], r=0.36)


def a_volcano_c(b, P):
    z = _top(P)
    crystals(b, rgb(30, 26, 28), [((0.6, 1.9, z - 0.4), (1.5, 0.9, z + 1.3)), ((-0.6, 1.9, z - 0.4), (-1.5, 0.9, z + 1.3))], r=0.3)   # chifres
    flames(b, rgb(255, 140, 20), [((2.2, -1.4, 1.8), (2.7, 0.2, 3.2)), ((2.2, 1.2, 1.7), (2.8, 3.0, 3.1)), ((1.2, 5.0, 1.5), (1.6, 7.0, 2.9))], r=0.32)
    neon_tubes(b, rgb(255, 110, 20))


def a_city_a(b, P):
    antenna(b, P, rgb(60, 60, 66), rgb(190, 255, 40))
    b.add("Glow", L.box((0, -9.1, 0.95), (0.9, 0.1, 0.1)), rgb(190, 255, 40), smooth=False)


def a_city_b(b, P):
    neon_tubes(b, rgb(40, 230, 250))
    RS, rz = P["rw_span"], P["rw_z"]
    b.add("Glow", L.tube([(-RS, 8.9, rz + 0.75), (RS, 8.9, rz + 0.75)], 0.06, 6), rgb(40, 230, 250))
    antenna(b, P, rgb(60, 60, 66), rgb(255, 80, 220))


def a_city_c(b, P):
    neon_tubes(b, rgb(255, 40, 200))
    b.add("Glass", L.prism([(2.2, 3.2), (3.4, 4.6), (7.2, 3.2), (7.2, 2.3)], "X", -0.03, 0.03), rgb(60, 230, 250), smooth=False)
    for k in range(3):
        b.add("Glow", L.box((0, 3.6 + k * 1.1, 3.9 - k * 0.45), (0.1, 0.5, 0.08)), rgb(255, 40, 200), smooth=False)
    ring(b, (0, 0.2, 0.34), 3.7, 0.06, rgb(40, 230, 250))


def a_celestial_a(b, P):
    for sx in (-1, 1):
        for i, (dy, dz, s) in enumerate(((0, 0, 0.5), (0.5, 0.1, 0.4), (-0.45, 0.05, 0.38), (0.1, 0.3, 0.36))):
            b.add("Acc", L.sphere((sx * 2.35, 1.4 + dy, 2.0 + dz), s, 10, 6, (1, 1.2, 0.8)), WHITE)
    RS, rz = P["rw_span"], P["rw_z"]
    for k in range(3):
        b.add("Acc", L.strut((RS, 7.4, rz + 0.4 - 0.1 * k), (RS + 1.0 + 0.2 * k, 7.9 + 0.4 * k, rz + 1.4 - 0.4 * k), 0.45, 0.07), WHITE, smooth=False, mirror=True)


def a_celestial_b(b, P):
    ring(b, (0, 2.2, _top(P) + 0.75), 0.85, 0.07, rgb(255, 225, 110))
    RS, rz = P["rw_span"], P["rw_z"]
    crystals(b, GOLD, [((RS, 8.0, rz + 0.75), (RS, 8.2, rz + 1.9)), ((-RS, 8.0, rz + 0.75), (-RS, 8.2, rz + 1.9))], r=0.16)
    b.add("Acc", L.tube([(0, -9.8, 0.8), (0, -10.9, 1.0)], 0.06, 5), GOLD)                    # flecha no bico
    crystals(b, GOLD, [((0, -10.8, 1.0), (0, -11.5, 1.1))], r=0.16)


def a_celestial_c(b, P):
    feather_wings(b, P, WHITE, rgb(255, 226, 150))
    ring(b, (0, 1.2, _top(P) + 0.95), 1.0, 0.08, rgb(255, 235, 150))
    crystals(b, rgb(255, 235, 150), [((0, 1.2, _top(P) + 0.4), (0, 1.2, _top(P) + 1.9))], r=0.18, role="Glow")
    neon_tubes(b, rgb(255, 235, 150))


# ============================================================================ a lista dos 21 carros

def car(cid, biome, variant, name, paint, acc, **over):
    P = dict(VARIANTS[variant])
    P.update(over)
    return dict(id=cid, biome=biome, variant=variant, name=name, paint=paint, acc=acc, P=P)


CARS = [
    car("warrior_a", "warrior", "A", "Turtle Trainer", p_warrior_a, a_warrior_a, stripe=ORANGE, rim=rgb(40, 60, 140), helmet=ORANGE),
    car("warrior_b", "warrior", "B", "Prince Vanguard", p_warrior_b, a_warrior_b, stripe=GOLD, rim=WHITE, helmet=rgb(28, 40, 150)),
    car("warrior_c", "warrior", "C", "Golden Aura", p_warrior_c, a_warrior_c, stripe=rgb(255, 240, 120), rim=rgb(255, 214, 50)),
    car("sakura_a", "sakura", "A", "Petal Runner", p_sakura_a, a_sakura_a, stripe=rgb(255, 170, 205), rim=WHITE, helmet=rgb(255, 170, 205)),
    car("sakura_b", "sakura", "B", "Shrine GT", p_sakura_b, a_sakura_b, stripe=rgb(205, 35, 45), rim=GOLD, helmet=rgb(205, 35, 45)),
    car("sakura_c", "sakura", "C", "Moon Blossom", p_sakura_c, a_sakura_c, stripe=rgb(255, 244, 200), rim=rgb(60, 30, 90)),
    car("dunes_a", "dunes", "A", "Sand Skipper", p_dunes_a, a_dunes_a, stripe=rgb(232, 196, 128), rim=rgb(120, 78, 44), helmet=rgb(232, 196, 128)),
    car("dunes_b", "dunes", "B", "Pharaoh", p_dunes_b, a_dunes_b, stripe=GOLD, rim=rgb(28, 58, 160), helmet=GOLD),
    car("dunes_c", "dunes", "C", "Sunset Scarab", p_dunes_c, a_dunes_c, stripe=rgb(30, 190, 185), rim=rgb(255, 190, 70)),
    car("tundra_a", "tundra", "A", "Snow Fox", p_tundra_a, a_tundra_a, stripe=rgb(120, 200, 245), rim=WHITE, helmet=WHITE),
    car("tundra_b", "tundra", "B", "Glacier", p_tundra_b, a_tundra_b, stripe=WHITE, rim=rgb(70, 190, 220), helmet=rgb(70, 190, 220)),
    car("tundra_c", "tundra", "C", "Aurora", p_tundra_c, a_tundra_c, stripe=rgb(60, 240, 160), rim=rgb(14, 22, 56)),
    car("volcano_a", "volcano", "A", "Ember", p_volcano_a, a_volcano_a, stripe=rgb(240, 110, 20), rim=rgb(60, 58, 62), helmet=rgb(240, 110, 20)),
    car("volcano_b", "volcano", "B", "Magma Vein", p_volcano_b, a_volcano_b, stripe=rgb(255, 150, 20), rim=rgb(30, 28, 30), helmet=rgb(200, 50, 10)),
    car("volcano_c", "volcano", "C", "Inferno Titan", p_volcano_c, a_volcano_c, stripe=rgb(255, 225, 90), rim=rgb(190, 22, 18)),
    car("city_a", "city", "A", "Street Volt", p_city_a, a_city_a, stripe=rgb(190, 255, 40), rim=rgb(60, 62, 70), helmet=rgb(190, 255, 40)),
    car("city_b", "city", "B", "Cyber Circuit", p_city_b, a_city_b, stripe=rgb(40, 230, 250), rim=rgb(52, 20, 110), helmet=rgb(40, 230, 250)),
    car("city_c", "city", "C", "Glitch Phantom", p_city_c, a_city_c, stripe=rgb(255, 40, 200), rim=rgb(20, 20, 28)),
    car("celestial_a", "celestial", "A", "Cloud Hopper", p_celestial_a, a_celestial_a, stripe=WHITE, rim=rgb(120, 190, 255), helmet=WHITE),
    car("celestial_b", "celestial", "B", "Star Archer", p_celestial_b, a_celestial_b, stripe=GOLD, rim=rgb(20, 28, 84), helmet=GOLD),
    car("celestial_c", "celestial", "C", "Origin Comet", p_celestial_c, a_celestial_c, stripe=GOLD, rim=WHITE),
]
