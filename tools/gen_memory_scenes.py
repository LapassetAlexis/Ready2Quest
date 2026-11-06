#!/usr/bin/env python3
"""Peint les décors des photos souvenirs de QuestCompanion (1.5.2).

Huit scènes, une par sorte de moment (Memories.lua, KIND_SCENE) :
meadow (prairie), dawn (aube), dusk (crépuscule), cave (donjon), city
(capitale), gold (trésor, brillante), storm (orage, mort), sky (au-dessus
des nuages, vol). Chaque décor : ciel en dégradé, astre et halo, nuages,
collines en plans successifs (les plus lointaines dans la brume), sol, herbes
au premier plan, vignettage. L'horizon est aux deux tiers : le compagnon
pose sur le sol.

TGA 24 bits non compressé 512x256 (origine en bas à gauche), recadré en jeu
(SetTexCoord) selon la photo : un cadrage différent par souvenir.
Bruit déterministe (hachage) : même sortie à chaque lancement.

Usage : python3 -I tools/gen_memory_scenes.py
"""
import math
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "QuestCompanion", "Textures")
W, H = 512, 256
HORIZON = 0.64          # part de la hauteur où commence le sol (depuis le haut)


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------
def hexc(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) / 255 for i in (0, 2, 4))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(edge0, edge1, x):
    if edge0 == edge1:
        return 1.0 if x >= edge1 else 0.0
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def hash2(x, y, seed):
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def noise(x, y, seed):
    """bruit de valeur lissé, x et y en cellules"""
    xi, yi = math.floor(x), math.floor(y)
    xf, yf = x - xi, y - yi
    u, v = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    a = hash2(xi, yi, seed)
    b = hash2(xi + 1, yi, seed)
    c = hash2(xi, yi + 1, seed)
    d = hash2(xi + 1, yi + 1, seed)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def fbm(x, y, seed, octaves=4):
    total, amp, freq, norm = 0.0, 1.0, 1.0, 0.0
    for o in range(octaves):
        total += amp * noise(x * freq, y * freq, seed + o * 31)
        norm += amp
        amp *= 0.5
        freq *= 2.0
    return total / norm


def ridge(x, seed, base, height, scale, octaves=4):
    """hauteur d'une ligne de crête (0 = haut de l'image) à l'abscisse x"""
    return base - height * fbm(x / scale, 0.5, seed, octaves)


class Canvas:
    def __init__(self):
        self.px = [[(0.0, 0.0, 0.0)] * W for _ in range(H)]

    def fill(self, fn):
        for y in range(H):
            row = self.px[y]
            for x in range(W):
                row[x] = fn(x, y, row[x])

    def save(self, name):
        data = bytearray()
        for y in range(H - 1, -1, -1):          # origine en bas à gauche
            for r, g, b in self.px[y]:
                data += bytes((
                    int(round(max(0, min(1, b)) * 255)),
                    int(round(max(0, min(1, g)) * 255)),
                    int(round(max(0, min(1, r)) * 255)),
                ))
        header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 24, 0)
        with open(os.path.join(OUT, name + ".tga"), "wb") as handle:
            handle.write(header + bytes(data))


# ---------------------------------------------------------------------------
# Calques
# ---------------------------------------------------------------------------
def sky(c, top, mid, low):
    hy = HORIZON * H

    def f(x, y, _):
        t = y / hy
        return mix(top, mid, t / 0.6) if t < 0.6 else mix(mid, low, (t - 0.6) / 0.4)
    c.fill(f)


def sun(c, cx, cy, radius, core, glow, glow_r):
    def f(x, y, p):
        d = math.hypot(x - cx, (y - cy) * 1.0)
        halo = math.exp(-(d / glow_r) ** 2) * 0.55
        p = mix(p, glow, halo)
        disc = 1 - smooth(radius - 1.5, radius + 1.5, d)
        return mix(p, core, disc)
    c.fill(f)


def clouds(c, color, shade, seed, y0, y1, density, scale=60.0, alpha=0.9):
    def f(x, y, p):
        if y < y0 - 20 or y > y1 + 20:
            return p
        band = smooth(y0 - 20, y0 + 10, y) * (1 - smooth(y1 - 10, y1 + 20, y))
        n = fbm(x / scale, y / (scale * 0.45), seed, 5)
        cover = smooth(density, density + 0.12, n) * band
        if cover <= 0:
            return p
        # ombre en bas du nuage
        lit = fbm(x / scale, (y - 6) / (scale * 0.45), seed, 5)
        col = mix(shade, color, smooth(density, density + 0.25, lit))
        return mix(p, col, cover * alpha)
    c.fill(f)


def hills(c, color, seed, base, height, scale, haze=None, haze_t=0.0, octaves=4, edge=1.5):
    if haze is not None:
        color = mix(color, haze, haze_t)

    def f(x, y, p):
        top = ridge(x, seed, base * H, height * H, scale, octaves)
        a = smooth(top - edge, top + edge, y)
        if a <= 0:
            return p
        # un peu de modelé : plus clair près de la crête
        light = mix(color, mix(color, (1, 1, 1), 0.08), 1 - smooth(top, top + 30, y))
        return mix(p, light, a)
    c.fill(f)


def ground(c, near, far, seed, texture=0.08):
    hy = HORIZON * H

    def f(x, y, p):
        if y < hy - 2:
            return p
        t = (y - hy) / (H - hy)
        col = mix(far, near, t)
        n = fbm(x / 18.0, y / 6.0, seed, 3) - 0.5
        col = mix(col, (0, 0, 0) if n < 0 else (1, 1, 1), abs(n) * texture * 2)
        return mix(p, col, smooth(hy - 2, hy + 2, y))
    c.fill(f)


def grass(c, color, seed, count, y_min, length=9):
    """touffes : traits fins penchés au premier plan"""
    blades = []
    for i in range(count):
        bx = hash2(i, 1, seed) * W
        by = y_min + hash2(i, 2, seed) * (H - y_min)
        tilt = (hash2(i, 3, seed) - 0.5) * 0.9
        ln = length * (0.6 + 0.8 * hash2(i, 4, seed)) * (0.5 + (by - y_min) / (H - y_min))
        blades.append((bx, by, tilt, ln))
    for bx, by, tilt, ln in blades:
        steps = int(ln * 2) + 1
        for s in range(steps):
            t = s / steps
            x = int(bx + tilt * ln * t)
            y = int(by - ln * t)
            if 0 <= x < W and 0 <= y < H:
                c.px[y][x] = mix(c.px[y][x], color, 0.75 * (1 - t * 0.5))


def dots(c, colors, seed, count, y_min, y_max, size=1.6):
    for i in range(count):
        cx = hash2(i, 7, seed) * W
        cy = y_min + hash2(i, 8, seed) * (y_max - y_min)
        col = colors[i % len(colors)]
        r = size * (0.7 + hash2(i, 9, seed) * 0.6)
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if 0 <= x < W and 0 <= y < H:
                    a = 1 - smooth(r - 0.7, r + 0.7, math.hypot(x - cx, y - cy))
                    if a > 0:
                        c.px[y][x] = mix(c.px[y][x], col, a)


def stars(c, color, seed, count, y_max):
    for i in range(count):
        x = int(hash2(i, 11, seed) * W)
        y = int(hash2(i, 12, seed) * y_max)
        b = 0.3 + 0.7 * hash2(i, 13, seed) ** 3
        c.px[y][x] = mix(c.px[y][x], color, b * (1 - y / y_max))


def sparkles(c, color, seed, count, y_min, y_max):
    for i in range(count):
        cx = hash2(i, 21, seed) * W
        cy = y_min + hash2(i, 22, seed) * (y_max - y_min)
        arm = 2 + 4 * hash2(i, 23, seed)
        for k in range(-int(arm), int(arm) + 1):
            fade = 1 - abs(k) / (arm + 1)
            for (x, y) in ((int(cx + k), int(cy)), (int(cx), int(cy + k))):
                if 0 <= x < W and 0 <= y < H:
                    c.px[y][x] = mix(c.px[y][x], color, fade * 0.9)


def rain(c, color, seed, count):
    for i in range(count):
        x0 = hash2(i, 31, seed) * (W + 60)
        y0 = hash2(i, 32, seed) * H
        ln = 8 + 10 * hash2(i, 33, seed)
        for s in range(int(ln)):
            x, y = int(x0 - s * 0.35), int(y0 + s)
            if 0 <= x < W and 0 <= y < H:
                c.px[y][x] = mix(c.px[y][x], color, 0.35)


def bolt(c, color, x0, seed):
    x, y = x0, 0.0
    end = HORIZON * H * 0.85
    i = 0
    while y < end:
        nx = x + (hash2(i, 41, seed) - 0.5) * 14
        ny = y + 6 + hash2(i, 42, seed) * 8
        steps = int(max(abs(nx - x), abs(ny - y))) + 1
        for s in range(steps):
            t = s / steps
            px, py = x + (nx - x) * t, y + (ny - y) * t
            for dx in (-2, -1, 0, 1, 2):
                xx, yy = int(px + dx), int(py)
                if 0 <= xx < W and 0 <= yy < H:
                    a = 1.0 if dx == 0 else (0.45 if abs(dx) == 1 else 0.15)
                    c.px[yy][xx] = mix(c.px[yy][xx], color, a)
        x, y = nx, ny
        i += 1


def buildings(c, color, lit, seed, base, count):
    """silhouettes de toits, de tours et de flèches, fenêtres allumées"""
    x = -10.0
    i = 0
    rects = []
    while x < W + 10 and i < count:
        w = 18 + hash2(i, 51, seed) * 34
        h = 24 + hash2(i, 52, seed) * 46
        tower = hash2(i, 53, seed) > 0.72
        if tower:
            w, h = w * 0.55, h * 1.6
        rects.append((x, w, h, tower, i))
        x += w + hash2(i, 54, seed) * 6
        i += 1
    bottom = base * H
    for (x0, w, h, tower, k) in rects:
        top = bottom - h
        roof = 10 + hash2(k, 55, seed) * 10 if not tower else 22
        for y in range(int(top - roof) - 1, int(bottom) + 1):
            for xx in range(int(x0), int(x0 + w) + 1):
                if not (0 <= xx < W and 0 <= y < H):
                    continue
                cx = x0 + w / 2
                inside = y >= top or (y >= top - roof and abs(xx - cx) <= (y - (top - roof)) / roof * w / 2)
                if inside:
                    c.px[y][xx] = color
                    # fenêtres
                    if y > top + 4 and y < bottom - 4 and int(xx - x0) % 7 in (2, 3) and int(y - top) % 9 in (3, 4, 5):
                        if hash2(int(xx - x0) // 7 + k * 13, int(y - top) // 9, seed) > 0.55:
                            c.px[y][xx] = lit


def stalactites(c, color, seed, count):
    for i in range(count):
        cx = hash2(i, 61, seed) * W
        w = 6 + hash2(i, 62, seed) * 16
        ln = 14 + hash2(i, 63, seed) * 42
        for y in range(int(ln)):
            half = w / 2 * (1 - y / ln)
            for x in range(int(cx - half), int(cx + half) + 1):
                if 0 <= x < W and 0 <= y < H:
                    c.px[y][x] = mix(c.px[y][x], color, 0.95)


def glow(c, cx, cy, radius, color, strength):
    def f(x, y, p):
        d = math.hypot(x - cx, y - cy)
        return mix(p, color, math.exp(-(d / radius) ** 2) * strength)
    c.fill(f)


def vignette(c, strength, color=(0.0, 0.0, 0.0)):
    def f(x, y, p):
        dx, dy = (x / W - 0.5) * 2, (y / H - 0.5) * 2
        d = math.sqrt(dx * dx * 0.6 + dy * dy * 0.9)
        return mix(p, color, smooth(0.75, 1.45, d) * strength)
    c.fill(f)


# ---------------------------------------------------------------------------
# Scènes
# ---------------------------------------------------------------------------
def meadow():
    c = Canvas()
    sky(c, hexc("#3f7fc4"), hexc("#86b9e3"), hexc("#d9ecf2"))
    sun(c, 410, 42, 13, hexc("#fffbe8"), hexc("#fff3c4"), 70)
    clouds(c, hexc("#ffffff"), hexc("#b9cde0"), 3, 18, 90, 0.56, 70)
    hills(c, hexc("#7f9fc0"), 5, 0.60, 0.27, 120, hexc("#cfe3ee"), 0.45)
    hills(c, hexc("#5f9a52"), 7, 0.66, 0.20, 80)
    ground(c, hexc("#3f7a33"), hexc("#7db35a"), 9)
    dots(c, [hexc("#f6e27a"), hexc("#ffffff"), hexc("#e78fb0")], 13, 120, int(H * 0.7), H - 4)
    grass(c, hexc("#2c5a25"), 15, 700, int(H * 0.72))
    vignette(c, 0.35)
    return c


def dawn():
    c = Canvas()
    sky(c, hexc("#5b5a9a"), hexc("#e59a87"), hexc("#ffd9a3"))
    sun(c, 120, int(HORIZON * H) - 8, 18, hexc("#fff4d6"), hexc("#ffc98a"), 110)
    clouds(c, hexc("#ffd2b8"), hexc("#b77f8f"), 21, 30, 90, 0.6, 80, 0.75)
    hills(c, hexc("#8a7aa6"), 23, 0.60, 0.24, 130, hexc("#f2c3a8"), 0.55)
    hills(c, hexc("#6d7d74"), 25, 0.66, 0.17, 90, hexc("#f2c3a8"), 0.25)
    ground(c, hexc("#4f6a3c"), hexc("#a3a46b"), 27)
    grass(c, hexc("#33452a"), 29, 600, int(H * 0.74))
    vignette(c, 0.35, hexc("#2a1a2a"))
    return c


def dusk():
    c = Canvas()
    sky(c, hexc("#1d1a3d"), hexc("#7a3a62"), hexc("#f08a4b"))
    stars(c, hexc("#ffffff"), 31, 160, int(H * 0.35))
    sun(c, 300, int(HORIZON * H) - 2, 22, hexc("#ffcf7a"), hexc("#ff8a45"), 120)
    clouds(c, hexc("#c0617a"), hexc("#4a2a4f"), 33, 40, 95, 0.62, 90, 0.7)
    hills(c, hexc("#3b2440"), 35, 0.61, 0.26, 120)
    hills(c, hexc("#22182a"), 37, 0.67, 0.19, 80)
    ground(c, hexc("#140f18"), hexc("#2b1f2c"), 39, 0.05)
    grass(c, hexc("#0b080d"), 41, 600, int(H * 0.74))
    vignette(c, 0.45)
    return c


def cave():
    c = Canvas()
    sky(c, hexc("#14110f"), hexc("#2b241f"), hexc("#3d3129"))
    # parois rocheuses : bruit sombre sur les côtés
    def walls(x, y, p):
        n = fbm(x / 26.0, y / 26.0, 51, 5)
        side = smooth(0.25, 0.0, x / W) + smooth(0.75, 1.0, x / W)
        return mix(p, mix(hexc("#1a1612"), hexc("#4a3d33"), n), min(1, side * 1.4 + n * 0.25))
    c.fill(walls)
    glow(c, 330, 120, 120, hexc("#ff9d45"), 0.55)
    glow(c, 330, 120, 30, hexc("#ffe2a0"), 0.6)
    stalactites(c, hexc("#120f0c"), 53, 26)
    hills(c, hexc("#2a221c"), 55, 0.64, 0.10, 60, None, 0, 5, 1.0)
    ground(c, hexc("#1c1713"), hexc("#3a2f27"), 57, 0.14)
    dots(c, [hexc("#7fd6ff"), hexc("#b38cff")], 59, 26, int(H * 0.68), H - 6, 1.2)
    vignette(c, 0.7)
    return c


def city():
    c = Canvas()
    sky(c, hexc("#3a5f95"), hexc("#8fb2d6"), hexc("#e7d9c4"))
    sun(c, 90, 50, 11, hexc("#fffbe8"), hexc("#fff0c8"), 60)
    clouds(c, hexc("#ffffff"), hexc("#a9bdd2"), 61, 15, 70, 0.6, 70, 0.8)
    buildings(c, hexc("#8a96ab"), hexc("#b9c2d2"), 63, HORIZON - 0.02, 40)   # lointains
    buildings(c, hexc("#4b5468"), hexc("#ffd479"), 65, HORIZON + 0.04, 40)
    ground(c, hexc("#6b6258"), hexc("#a39887"), 67, 0.12)
    # pavés
    def cobbles(x, y, p):
        if y < HORIZON * H + 6:
            return p
        row = int((y - HORIZON * H) / 7)
        off = 6 if row % 2 else 0
        edge = ((x + off) % 12 < 1) or ((y - HORIZON * H) % 7 < 1)
        return mix(p, hexc("#4d463f"), 0.45 if edge else 0)
    c.fill(cobbles)
    vignette(c, 0.4)
    return c


def gold():
    c = Canvas()
    sky(c, hexc("#b4632a"), hexc("#f2b85a"), hexc("#ffe6a6"))
    sun(c, 256, int(HORIZON * H) - 30, 20, hexc("#fffbe2"), hexc("#ffd36b"), 140)
    clouds(c, hexc("#ffe0a0"), hexc("#c98a45"), 71, 25, 85, 0.6, 80, 0.65)
    hills(c, hexc("#b88a4d"), 73, 0.61, 0.22, 120, hexc("#ffe0a0"), 0.45)
    hills(c, hexc("#8a6b2f"), 75, 0.67, 0.17, 90)
    ground(c, hexc("#6e5420"), hexc("#c99b45"), 77, 0.1)
    sparkles(c, hexc("#fff6cf"), 79, 60, 10, H - 10)
    grass(c, hexc("#5a4318"), 81, 400, int(H * 0.76))
    vignette(c, 0.35, hexc("#3a2408"))
    return c


def storm():
    c = Canvas()
    sky(c, hexc("#1e2229"), hexc("#454c57"), hexc("#7d8590"))
    clouds(c, hexc("#5e6672"), hexc("#20242b"), 91, 0, 100, 0.42, 60, 0.95)
    bolt(c, hexc("#e8f0ff"), 360, 93)
    glow(c, 360, 40, 90, hexc("#b9c8ff"), 0.25)
    hills(c, hexc("#2c3530"), 95, 0.62, 0.22, 110, hexc("#5a636e"), 0.35)
    hills(c, hexc("#1d2620"), 97, 0.67, 0.17, 80)
    ground(c, hexc("#141b16"), hexc("#28322b"), 99, 0.08)
    rain(c, hexc("#c4cdd8"), 101, 900)
    vignette(c, 0.55)
    return c


def sky_scene():
    c = Canvas()
    sky(c, hexc("#2a5fb0"), hexc("#73a8e0"), hexc("#cfe6f7"))
    sun(c, 400, 60, 14, hexc("#ffffff"), hexc("#fff5d0"), 90)
    clouds(c, hexc("#ffffff"), hexc("#c2d3e6"), 111, 20, 60, 0.6, 60, 0.6)
    # mer de nuages à la place du sol
    def sea(x, y, p):
        top = ridge(x, 113, HORIZON * H + 6, 30, 50, 5)
        a = smooth(top - 3, top + 3, y)
        if a <= 0:
            return p
        n = fbm(x / 40.0, y / 14.0, 115, 5)
        col = mix(hexc("#a9c0da"), hexc("#ffffff"), smooth(0.35, 0.75, n) * (1 - smooth(top, top + 70, y) * 0.3))
        return mix(p, col, a)
    c.fill(sea)
    vignette(c, 0.3, hexc("#0e2a55"))
    return c


SCENES = {
    "meadow": meadow, "dawn": dawn, "dusk": dusk, "cave": cave,
    "city": city, "gold": gold, "storm": storm, "sky": sky_scene,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, painter in SCENES.items():
        painter().save("scene_" + name)
        print("Textures/scene_%s.tga" % name)


if __name__ == "__main__":
    main()
