#!/usr/bin/env python3
"""Peint les paysages des sceaux de zone de QuestCompanion (fonds « sceau »).

Un paysage par biome (MenagerieCollection.lua, ZONE_BIOME), dans l'esprit des
paysages de Warcraft : silhouettes franches, couleurs saturées, lumière d'un
côté. forest (Elwynn), nightforest (Orneval), canyon (Durotar), savanna (les
Tarides), snow (Dun Morogh), swamp (les Paluns), desert (Tanaris), blight
(Tirisfal), jungle (Strangleronce), volcanic (Steppes ardentes). Peints en
1.5.4 pour l'album des souvenirs (retiré en 2.6.0), ils restent le fond
gagné au deuxième sceau d'un biome.

TGA 24 bits non compressé 512x256 (origine en bas à gauche), recadré en jeu
(SetTexCoord). Bruit déterministe (hachage) : même sortie à chaque lancement.

Usage : python3 -I tools/gen_seal_scenes.py
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
# Formes (1.5.4) : silhouettes franches, lumière d'un côté, à la Warcraft
# ---------------------------------------------------------------------------
def put(c, x, y, col, a=1.0):
    if 0 <= x < W and 0 <= y < H and a > 0:
        c.px[y][x] = mix(c.px[y][x], col, a)


def ellipse(c, cx, cy, rx, ry, col, alpha=1.0, light=None, light_dir=(-0.6, -0.8)):
    """disque plein ; light : couleur du côté éclairé (haut gauche par défaut)"""
    for y in range(int(cy - ry - 2), int(cy + ry + 3)):
        for x in range(int(cx - rx - 2), int(cx + rx + 3)):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            d = math.sqrt(dx * dx + dy * dy)
            a = 1 - smooth(1 - 1.5 / max(rx, ry), 1 + 1.5 / max(rx, ry), d)
            if a <= 0:
                continue
            colr = col
            if light is not None:
                lit = -(dx * light_dir[0] + dy * light_dir[1])
                colr = mix(col, light, smooth(0.15, 0.85, lit) * 0.9)
            put(c, x, y, colr, a * alpha)


def polygon(c, pts, col, alpha=1.0, shade=None):
    """polygone plein (règle pair-impair) ; shade(x, y) -> couleur facultative"""
    ys = [p[1] for p in pts]
    for y in range(max(0, int(min(ys))), min(H, int(max(ys)) + 1)):
        yc = y + 0.5
        xs = []
        for i in range(len(pts)):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % len(pts)]
            if (y1 <= yc < y2) or (y2 <= yc < y1):
                xs.append(x1 + (yc - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        for k in range(0, len(xs) - 1, 2):
            for x in range(max(0, int(xs[k])), min(W, int(xs[k + 1]) + 1)):
                put(c, x, y, shade(x, y) if shade else col, alpha)


def line(c, x0, y0, x1, y1, col, width=1.0, alpha=1.0):
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    r = width / 2
    for s in range(steps + 1):
        t = s / steps
        px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for y in range(int(py - r - 1), int(py + r + 2)):
            for x in range(int(px - r - 1), int(px + r + 2)):
                a = 1 - smooth(r - 0.5, r + 0.5, math.hypot(x - px, y - py))
                if a > 0 and 0 <= x < W and 0 <= y < H:
                    c.px[y][x] = mix(c.px[y][x], col, a * alpha)


def mountains(c, seed, base, height, count, dark, light, snow=None, haze=None, haze_t=0.0, sharp=1.0):
    """chaîne de pics : face éclairée à gauche, face d'ombre à droite, neige"""
    if haze is not None:
        dark, light = mix(dark, haze, haze_t), mix(light, haze, haze_t)
        if snow:
            snow = mix(snow, haze, haze_t * 0.7)
    step = W / count
    for i in range(-1, count + 1):
        cx = (i + 0.5) * step + (hash2(i, 1, seed) - 0.5) * step * 0.6
        h = height * H * (0.55 + 0.45 * hash2(i, 2, seed))
        half = step * (0.8 + 0.6 * hash2(i, 3, seed)) / sharp
        top, foot = base * H - h, base * H + 2
        polygon(c, [(cx - half, foot), (cx, top), (cx + half, foot)], light)
        polygon(c, [(cx, top), (cx + half, foot), (cx + half * 0.15, foot)], dark)
        if snow:
            cap = h * 0.28
            polygon(c, [(cx - half * cap / h, top + cap), (cx, top), (cx + half * cap / h, top + cap),
                        (cx + half * cap / h * 0.4, top + cap * 0.75), (cx - half * cap / h * 0.3, top + cap * 0.85)], snow)


def mesas(c, seed, base, count, rock, light, band):
    """plateaux du désert rouge : flancs droits, strates, sommet plat"""
    step = W / count
    for i in range(count + 1):
        cx = i * step + (hash2(i, 5, seed) - 0.5) * step * 0.5
        w = step * (0.5 + 0.5 * hash2(i, 6, seed))
        h = H * (0.12 + 0.16 * hash2(i, 7, seed))
        bottom, top = base * H + 2, base * H - h
        lean = w * 0.12
        pts = [(cx - w / 2 - lean, bottom), (cx - w / 2, top), (cx + w / 2, top), (cx + w / 2 + lean, bottom)]

        def shade(x, y, cx=cx, w=w, top=top, h=h):
            col = mix(light, rock, smooth(cx - w * 0.1, cx + w * 0.5, x))
            if int((y - top) / (h / 5)) % 2 == 1:
                col = mix(col, band, 0.35)
            return col
        polygon(c, pts, rock, 1.0, shade)


def canopy_tree(c, x, ground_y, size, trunk, leaf, light, dark=None):
    """arbre rond à la Warcraft : tronc épais, houppier en boules, lumière en haut à gauche"""
    tw = max(2, size * 0.16)
    polygon(c, [(x - tw, ground_y), (x - tw * 0.6, ground_y - size * 0.9), (x + tw * 0.6, ground_y - size * 0.9),
                (x + tw, ground_y)], trunk)
    dark = dark or mix(leaf, (0, 0, 0), 0.35)
    blobs = [(-0.45, -1.05, 0.55), (0.45, -1.0, 0.55), (0.0, -1.35, 0.65), (-0.2, -1.6, 0.45), (0.3, -1.55, 0.4)]
    for bx, by, br in blobs:
        ellipse(c, x + bx * size, ground_y + by * size, br * size, br * size * 0.85, dark)
    for bx, by, br in blobs:
        ellipse(c, x + bx * size - 2, ground_y + by * size - 2, br * size * 0.85, br * size * 0.75, leaf, 1.0, light)


def pine(c, x, ground_y, size, trunk, leaf, light, snow=None):
    polygon(c, [(x - 2, ground_y), (x - 1.5, ground_y - size * 0.25), (x + 1.5, ground_y - size * 0.25), (x + 2, ground_y)], trunk)
    for k in range(4):
        w = size * (0.42 - k * 0.08)
        yb = ground_y - size * (0.2 + k * 0.2)
        yt = yb - size * 0.36
        polygon(c, [(x - w, yb), (x, yt), (x + w, yb)], leaf)
        polygon(c, [(x - w, yb), (x, yt), (x - w * 0.15, yb)], light)
        if snow:
            polygon(c, [(x - w * 0.45, yt + size * 0.16), (x, yt), (x + w * 0.45, yt + size * 0.16), (x, yt + size * 0.1)], snow)


def acacia(c, x, ground_y, size, trunk, leaf, light):
    line(c, x, ground_y, x + size * 0.1, ground_y - size * 0.7, trunk, max(2, size * 0.08))
    line(c, x + size * 0.1, ground_y - size * 0.7, x - size * 0.35, ground_y - size * 0.95, trunk, max(1.5, size * 0.05))
    line(c, x + size * 0.1, ground_y - size * 0.7, x + size * 0.5, ground_y - size * 0.98, trunk, max(1.5, size * 0.05))
    ellipse(c, x + size * 0.05, ground_y - size * 1.02, size * 0.75, size * 0.16, mix(leaf, (0, 0, 0), 0.3))
    ellipse(c, x + size * 0.02, ground_y - size * 1.06, size * 0.68, size * 0.12, leaf, 1.0, light)


def palm(c, x, ground_y, size, trunk, leaf, light, lean=0.25):
    tx, ty = x + size * lean, ground_y - size
    for s in range(12):
        t0, t1 = s / 12, (s + 1) / 12
        bend = lambda t: (x + (tx - x) * t + math.sin(t * math.pi) * size * 0.08, ground_y + (ty - ground_y) * t)
        (ax, ay), (bx, by) = bend(t0), bend(t1)
        line(c, ax, ay, bx, by, trunk if s % 2 else mix(trunk, (0, 0, 0), 0.25), max(2, size * 0.07 * (1 - t0 * 0.4)))
    for k in range(7):
        ang = math.pi * (0.95 + k / 6 * 1.1)
        ex, ey = tx + math.cos(ang) * size * 0.6, ty + math.sin(ang) * size * 0.32 + size * 0.12
        mx, my = (tx + ex) / 2, min(ty, ey) - size * 0.1
        line(c, tx, ty, mx, my, leaf, max(2, size * 0.06))
        line(c, mx, my, ex, ey, light if k < 3 else leaf, max(1.5, size * 0.05))


def dead_tree(c, x, ground_y, size, col, seed, depth=4):
    def branch(x0, y0, ang, ln, w, d, k):
        x1, y1 = x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln
        line(c, x0, y0, x1, y1, col, w)
        if d == 0:
            return
        for j, spread in enumerate((-0.55, 0.45)):
            jitter = (hash2(k * 3 + j, d, seed) - 0.5) * 0.5
            branch(x1, y1, ang + spread + jitter, ln * (0.62 + 0.15 * hash2(k, j + 7, seed)), max(1, w * 0.6), d - 1, k * 2 + j)
    branch(x, ground_y, -math.pi / 2 + (hash2(1, 1, seed) - 0.5) * 0.3, size * 0.45, max(2, size * 0.09), depth, 1)


def fog(c, y0, y1, col, strength, seed):
    def f(x, y, p):
        if y < y0 - 20 or y > y1 + 20:
            return p
        band = smooth(y0 - 20, y0 + 10, y) * (1 - smooth(y1 - 10, y1 + 20, y))
        n = fbm(x / 70.0, y / 20.0, seed, 3)
        return mix(p, col, band * strength * (0.6 + 0.6 * n))
    c.fill(f)


def water(c, top_frac, deep, shallow, sky_tint, seed):
    top = top_frac * H

    def f(x, y, p):
        if y < top:
            return p
        t = (y - top) / (H - top)
        col = mix(sky_tint, deep, smooth(0, 0.6, t))
        col = mix(col, shallow, 0.25 * (fbm(x / 30.0, y / 3.0, seed, 3)))
        # reflets en traits horizontaux
        if hash2(int(x / 9), int(y), seed) > 0.93:
            col = mix(col, (1, 1, 1), 0.25)
        return col
    c.fill(f)


def wisps(c, col, seed, count, y_min, y_max):
    for i in range(count):
        cx = hash2(i, 81, seed) * W
        cy = y_min + hash2(i, 82, seed) * (y_max - y_min)
        r = 2 + 3 * hash2(i, 83, seed)
        for y in range(int(cy - r * 4), int(cy + r * 4)):
            for x in range(int(cx - r * 4), int(cx + r * 4)):
                d = math.hypot(x - cx, y - cy)
                put(c, x, y, col, math.exp(-(d / (r * 1.6)) ** 2) * 0.8)
        put(c, int(cx), int(cy), (1, 1, 1), 1)


def ground_line(c, seed, base, amp, near, far, scale=90.0, texture=0.08):
    """sol à bord ondulé (au lieu d'un horizon droit)"""
    def f(x, y, p):
        top = base * H - amp * H * fbm(x / scale, 0.3, seed, 3)
        if y < top - 1.5:
            return p
        t = (y - top) / max(1, H - top)
        col = mix(far, near, t)
        n = fbm(x / 16.0, y / 6.0, seed + 5, 3) - 0.5
        col = mix(col, (0, 0, 0) if n < 0 else (1, 1, 1), abs(n) * texture * 2)
        return mix(p, col, smooth(top - 1.5, top + 1.5, y))
    c.fill(f)


def rim_light(c, col, strength):
    """liseré de lumière en haut de l'image : l'ambiance colorée de Warcraft"""
    def f(x, y, p):
        return mix(p, col, (1 - y / H) ** 3 * strength)
    c.fill(f)


GROUND_Y = int(HORIZON * H)


# ---------------------------------------------------------------------------
# Biomes (un par sorte de zone)
# ---------------------------------------------------------------------------
def forest():
    """Elwynn, Loch Modan, Arathi, les Hinterlands : forêt dorée de soleil"""
    c = Canvas()
    sky(c, hexc("#4f86c6"), hexc("#9fc8e8"), hexc("#f3e7c2"))
    sun(c, 380, 46, 14, hexc("#fffbe6"), hexc("#ffe9a8"), 90)
    clouds(c, hexc("#ffffff"), hexc("#c3d2e0"), 201, 15, 80, 0.55, 65, 0.85)
    mountains(c, 203, 0.58, 0.30, 5, hexc("#6d86a8"), hexc("#9db2cc"), hexc("#eef4fb"), hexc("#d6e4ef"), 0.35)
    hills(c, hexc("#3f7d3a"), 205, 0.66, 0.24, 90)
    for i in range(9):
        x = 20 + i * 60 + hash2(i, 1, 207) * 30
        canopy_tree(c, x, GROUND_Y + 2, 16 + 8 * hash2(i, 2, 207), hexc("#4a3020"), hexc("#3f8a3a"), hexc("#9fd36a"))
    ground_line(c, 209, HORIZON + 0.02, 0.03, hexc("#2f6a2a"), hexc("#6aa84a"))
    # chemin de terre
    polygon(c, [(220, H), (250, GROUND_Y + 8), (262, GROUND_Y + 8), (330, H)], hexc("#b08a5a"), 0.85)
    canopy_tree(c, 30, H + 6, 70, hexc("#3d2718"), hexc("#2f7a2f"), hexc("#8fcf5f"))
    canopy_tree(c, 490, H + 10, 80, hexc("#3d2718"), hexc("#2f7a2f"), hexc("#8fcf5f"))
    dots(c, [hexc("#f6e27a"), hexc("#ffffff"), hexc("#e78fb0")], 211, 90, int(H * 0.74), H - 4)
    grass(c, hexc("#235020"), 213, 500, int(H * 0.76))
    rim_light(c, hexc("#fff0c0"), 0.12)
    vignette(c, 0.4)
    return c


def nightforest():
    """Orneval, Sombrivage, Teldrassil, Bois de la Pénombre : nuit violette, troncs géants"""
    c = Canvas()
    sky(c, hexc("#120f2e"), hexc("#3a2f6e"), hexc("#6a5aa8"))
    stars(c, hexc("#ffffff"), 221, 220, int(H * 0.5))
    sun(c, 120, 52, 16, hexc("#e8f0ff"), hexc("#9fb0ff"), 80)
    mountains(c, 223, 0.60, 0.22, 6, hexc("#2c2756"), hexc("#3d3775"), None, hexc("#6a5aa8"), 0.3)
    fog(c, GROUND_Y - 40, GROUND_Y + 10, hexc("#8f7fd0"), 0.35, 225)
    for i in range(7):
        x = 30 + i * 75 + hash2(i, 1, 227) * 30
        canopy_tree(c, x, GROUND_Y + 4, 22 + 10 * hash2(i, 2, 227), hexc("#2a2140"), hexc("#3a3a8a"), hexc("#7a8ae0"))
    ground_line(c, 229, HORIZON + 0.02, 0.03, hexc("#1a1838"), hexc("#3a3470"))
    # deux troncs géants au premier plan
    for x0 in (40, 470):
        polygon(c, [(x0 - 26, H), (x0 - 16, 0), (x0 + 16, 0), (x0 + 30, H)], hexc("#2a1f3a"), 1.0,
                lambda x, y, x0=x0: mix(hexc("#4a3a6a"), hexc("#1a1428"), smooth(x0 - 20, x0 + 25, x)))
        ellipse(c, x0, 10, 70, 40, hexc("#2a2f70"), 1.0, hexc("#5a6ad0"))
    wisps(c, hexc("#a8f0ff"), 231, 14, int(H * 0.35), H - 20)
    grass(c, hexc("#14122a"), 233, 400, int(H * 0.78))
    vignette(c, 0.5, hexc("#05040f"))
    return c


def canyon():
    """Durotar, les Serres-Rocheuses, les Mille pointes, les Terres ingrates : roche rouge"""
    c = Canvas()
    sky(c, hexc("#d07a3a"), hexc("#f2b673"), hexc("#ffe2b0"))
    sun(c, 400, 70, 18, hexc("#fff3d0"), hexc("#ffcf80"), 100)
    clouds(c, hexc("#ffd9a8"), hexc("#c07a50"), 241, 20, 70, 0.62, 80, 0.6)
    mesas(c, 243, 0.62, 5, hexc("#8a3b22"), hexc("#d27a45"), hexc("#5a2614"))
    mountains(c, 245, 0.66, 0.14, 9, hexc("#7a3220"), hexc("#b85a30"), None, None, 0, 1.6)
    ground_line(c, 247, HORIZON + 0.02, 0.03, hexc("#8a4a2a"), hexc("#c98050"), 70, 0.12)
    # rochers pointus au premier plan
    for i, x in enumerate((25, 70, 450, 500)):
        h = 50 + 30 * hash2(i, 1, 249)
        polygon(c, [(x - 22, H), (x - 4, H - h), (x + 6, H - h * 0.8), (x + 24, H)], hexc("#6a2a18"), 1.0,
                lambda xx, yy, x=x: mix(hexc("#c0663a"), hexc("#5a2414"), smooth(x - 10, x + 15, xx)))
    dead_tree(c, 380, GROUND_Y + 30, 40, hexc("#3a2014"), 251, 3)
    rim_light(c, hexc("#ffb060"), 0.15)
    vignette(c, 0.45, hexc("#3a1408"))
    return c


def savanna():
    """Les Tarides, Mulgore, la Marche de l'Ouest : herbes blondes et arbres plats"""
    c = Canvas()
    sky(c, hexc("#5a92c8"), hexc("#a8cde6"), hexc("#f5e6bf"))
    sun(c, 120, 50, 15, hexc("#fffbe6"), hexc("#ffe9a8"), 90)
    clouds(c, hexc("#ffffff"), hexc("#c8d4dc"), 261, 18, 75, 0.58, 75, 0.8)
    mountains(c, 263, 0.60, 0.16, 4, hexc("#8a8aa0"), hexc("#b0b0c0"), None, hexc("#e0dccb"), 0.4, 0.7)
    hills(c, hexc("#b8a050"), 265, 0.65, 0.12, 120)
    for i, (x, s) in enumerate(((90, 34), (300, 26), (420, 40))):
        acacia(c, x, GROUND_Y + 6, s, hexc("#4a3020"), hexc("#6a8a30"), hexc("#b0c860"))
    ground_line(c, 267, HORIZON + 0.02, 0.02, hexc("#a08030"), hexc("#d8c070"), 90, 0.1)
    grass(c, hexc("#7a5a20"), 269, 800, int(H * 0.72), 12)
    grass(c, hexc("#e8d080"), 271, 300, int(H * 0.75), 10)
    rim_light(c, hexc("#fff0c0"), 0.12)
    vignette(c, 0.4, hexc("#3a2a10"))
    return c


def snow():
    """Dun Morogh, Berceau-de-l'Hiver, Alterac : sommets blancs et sapins"""
    c = Canvas()
    sky(c, hexc("#6f9ccf"), hexc("#b8d4ec"), hexc("#eef5fb"))
    sun(c, 360, 50, 13, hexc("#ffffff"), hexc("#e8f4ff"), 80)
    clouds(c, hexc("#ffffff"), hexc("#c8d8e8"), 281, 15, 70, 0.56, 60, 0.85)
    mountains(c, 283, 0.60, 0.40, 4, hexc("#5a6f90"), hexc("#9ab0cc"), hexc("#ffffff"), hexc("#dfe9f4"), 0.4, 0.9)
    mountains(c, 285, 0.65, 0.26, 6, hexc("#4a5c7a"), hexc("#8aa0bc"), hexc("#f4f8ff"))
    ground_line(c, 287, HORIZON + 0.01, 0.03, hexc("#cfdcec"), hexc("#f4f8ff"), 80, 0.05)
    for i in range(10):
        x = 10 + i * 55 + hash2(i, 1, 289) * 25
        y = GROUND_Y + 10 + hash2(i, 2, 289) * 20
        pine(c, x, y, 26 + 14 * hash2(i, 3, 289), hexc("#3a2a20"), hexc("#2a4a3a"), hexc("#4a7a5a"), hexc("#ffffff"))
    pine(c, 20, H + 4, 90, hexc("#3a2a20"), hexc("#23402f"), hexc("#3f6a4f"), hexc("#ffffff"))
    pine(c, 495, H + 4, 100, hexc("#3a2a20"), hexc("#23402f"), hexc("#3f6a4f"), hexc("#ffffff"))
    dots(c, [hexc("#ffffff")], 291, 160, 0, H, 1.0)
    vignette(c, 0.35, hexc("#2a3a5a"))
    return c


def swamp():
    """les Paluns, le marécage d'Âprefange, le marais des Chagrins : eau trouble, brume"""
    c = Canvas()
    sky(c, hexc("#4a5a4a"), hexc("#7f907a"), hexc("#b4c0a0"))
    sun(c, 300, 60, 14, hexc("#f0f0d0"), hexc("#c8d0a0"), 90)
    mountains(c, 301, 0.58, 0.14, 5, hexc("#4a5a48"), hexc("#5f6f58"), None, hexc("#9aa88a"), 0.4, 0.8)
    for i in range(6):
        canopy_tree(c, 40 + i * 90 + hash2(i, 1, 303) * 30, GROUND_Y - 2, 22, hexc("#2a2418"), hexc("#3f5a30"), hexc("#7a9a50"))
    fog(c, GROUND_Y - 30, GROUND_Y + 10, hexc("#c8d4b0"), 0.5, 305)
    water(c, HORIZON + 0.02, hexc("#1f2f22"), hexc("#4a6a40"), hexc("#7f907a"), 307)
    # racines et souches dans l'eau
    for i, x in enumerate((60, 160, 380, 470)):
        dead_tree(c, x, H - 10 - hash2(i, 1, 309) * 30, 30 + 20 * hash2(i, 2, 309), hexc("#2a2016"), 311 + i, 3)
    # roseaux
    for i in range(80):
        x = hash2(i, 1, 313) * W
        y = H - hash2(i, 2, 313) * 40
        line(c, x, y, x + (hash2(i, 3, 313) - 0.5) * 6, y - 12 - 10 * hash2(i, 4, 313), hexc("#4a5a2a"), 1.2)
    vignette(c, 0.5, hexc("#101810"))
    return c


def desert():
    """Tanaris, Silithus, Désolace : dunes et ruines sous le soleil"""
    c = Canvas()
    sky(c, hexc("#4a8ac8"), hexc("#a8cce8"), hexc("#fbe8c0"))
    sun(c, 256, 40, 16, hexc("#ffffff"), hexc("#fff0c0"), 110)
    hills(c, hexc("#d8a860"), 321, 0.60, 0.16, 140, hexc("#f4dcb0"), 0.4, 3, 1.0)
    hills(c, hexc("#c89040"), 323, 0.66, 0.14, 110, None, 0, 3, 1.0)
    # ruines : colonnes et arche
    for x in (90, 118, 146):
        polygon(c, [(x - 6, GROUND_Y + 4), (x - 5, GROUND_Y - 50), (x + 5, GROUND_Y - 50), (x + 6, GROUND_Y + 4)],
                hexc("#c8a070"), 1.0, lambda xx, yy, x=x: mix(hexc("#f0d0a0"), hexc("#9a7040"), smooth(x - 4, x + 5, xx)))
    polygon(c, [(80, GROUND_Y - 50), (156, GROUND_Y - 50), (156, GROUND_Y - 58), (80, GROUND_Y - 58)], hexc("#d8b080"))
    ground_line(c, 325, HORIZON + 0.03, 0.05, hexc("#c08a40"), hexc("#f0c880"), 120, 0.06)
    # vagues de sable au premier plan
    def ripples(x, y, p):
        if y < GROUND_Y + 20:
            return p
        k = math.sin((y + 6 * math.sin(x / 40.0)) / 3.0)
        return mix(p, hexc("#a87030"), 0.15 * smooth(0.6, 1.0, k))
    c.fill(ripples)
    palm(c, 470, H, 70, hexc("#6a4a2a"), hexc("#4a7a30"), hexc("#8ab850"), -0.2)
    rim_light(c, hexc("#fff4d0"), 0.1)
    vignette(c, 0.35, hexc("#4a2a08"))
    return c


def blight():
    """Clairières de Tirisfal, Forêt des Pins-Argentés, Maleterres, Gangrebois : ciel malade, arbres morts"""
    c = Canvas()
    sky(c, hexc("#2a2f2a"), hexc("#5a6a50"), hexc("#a8b880"))
    sun(c, 140, 60, 15, hexc("#e8f0c0"), hexc("#b8c880"), 80)
    clouds(c, hexc("#7a8a6a"), hexc("#3a4038"), 331, 10, 80, 0.5, 70, 0.8)
    mountains(c, 333, 0.60, 0.18, 6, hexc("#3a4038"), hexc("#4f584a"), None, hexc("#8a9a70"), 0.35)
    for i in range(10):
        dead_tree(c, 20 + i * 52 + hash2(i, 1, 335) * 20, GROUND_Y + 4, 28 + 18 * hash2(i, 2, 335), hexc("#2a2a26"), 337 + i, 3)
    fog(c, GROUND_Y - 25, GROUND_Y + 25, hexc("#9ad070"), 0.4, 339)
    ground_line(c, 341, HORIZON + 0.02, 0.03, hexc("#2f3328"), hexc("#5a6448"), 80, 0.1)
    # pierre tombale et grille
    polygon(c, [(400, H - 30), (400, H - 70), (410, H - 80), (420, H - 70), (420, H - 30)], hexc("#7a7a78"), 1.0,
            lambda x, y: mix(hexc("#a0a09a"), hexc("#4a4a48"), smooth(402, 420, x)))
    for x in range(20, 140, 10):
        line(c, x, H, x, H - 50, hexc("#1a1a18"), 2)
        polygon(c, [(x - 3, H - 50), (x, H - 58), (x + 3, H - 50)], hexc("#1a1a18"))
    line(c, 18, H - 40, 140, H - 40, hexc("#1a1a18"), 2)
    dead_tree(c, 490, H + 4, 120, hexc("#1f1f1c"), 343, 4)
    wisps(c, hexc("#c0ff90"), 345, 10, GROUND_Y - 20, H - 10)
    vignette(c, 0.55, hexc("#0a0f08"))
    return c


def jungle():
    """Strangleronce, Un'Goro, Féralas : vert profond, palmiers, brume chaude"""
    c = Canvas()
    sky(c, hexc("#5aa0b8"), hexc("#a8d8d0"), hexc("#f0f0c8"))
    sun(c, 300, 40, 14, hexc("#ffffff"), hexc("#fff0c0"), 100)
    mountains(c, 351, 0.58, 0.30, 4, hexc("#3a6a5a"), hexc("#5a8a70"), None, hexc("#c0e0d0"), 0.45, 1.3)
    fog(c, GROUND_Y - 40, GROUND_Y, hexc("#e0f0d0"), 0.35, 353)
    for i in range(8):
        canopy_tree(c, 20 + i * 66 + hash2(i, 1, 355) * 20, GROUND_Y + 4, 20 + 10 * hash2(i, 2, 355),
                    hexc("#3a2a18"), hexc("#1f6a3a"), hexc("#6ac060"))
    ground_line(c, 357, HORIZON + 0.02, 0.03, hexc("#1a4a20"), hexc("#3f8a3a"), 70, 0.1)
    palm(c, 50, H, 110, hexc("#5a3a20"), hexc("#2f8a3a"), hexc("#8ad060"), 0.35)
    palm(c, 470, H, 95, hexc("#5a3a20"), hexc("#2f8a3a"), hexc("#8ad060"), -0.3)
    # grandes feuilles au premier plan
    for i in range(14):
        x = hash2(i, 1, 359) * W
        ellipse(c, x, H - 5, 22, 9, hexc("#1f5a2a"), 1.0, hexc("#5aa04a"), (0, -1))
    dots(c, [hexc("#ff6a8a"), hexc("#ffd040")], 361, 30, int(H * 0.78), H - 6, 1.8)
    rim_light(c, hexc("#fff8d0"), 0.1)
    vignette(c, 0.45, hexc("#0a200f"))
    return c


def volcanic():
    """Steppes ardentes, Gorge des Vents brûlants, Terres foudroyées : ciel rouge, lave"""
    c = Canvas()
    sky(c, hexc("#2a0f0c"), hexc("#7a2a18"), hexc("#e86a2a"))
    sun(c, 360, int(HORIZON * H) - 40, 22, hexc("#ffd08a"), hexc("#ff7a30"), 130)
    clouds(c, hexc("#5a2a20"), hexc("#200a08"), 371, 0, 90, 0.48, 70, 0.9)
    mountains(c, 373, 0.62, 0.36, 3, hexc("#1a0f0c"), hexc("#3a1f18"), None, hexc("#7a2a18"), 0.25, 1.1)
    # coulées de lave sur les pentes
    for i in range(5):
        x = 60 + i * 100 + hash2(i, 1, 375) * 40
        line(c, x, GROUND_Y - 60, x + 20, GROUND_Y + 4, hexc("#ff8a2a"), 2.5, 0.85)
    ground_line(c, 377, HORIZON + 0.02, 0.03, hexc("#1a120f"), hexc("#3a2620"), 70, 0.15)
    # fissures de lave au sol
    for i in range(18):
        x0 = hash2(i, 1, 379) * W
        y0 = GROUND_Y + 10 + hash2(i, 2, 379) * (H - GROUND_Y - 10)
        line(c, x0, y0, x0 + 20 + 30 * hash2(i, 3, 379), y0 + (hash2(i, 4, 379) - 0.5) * 10, hexc("#ff7a20"), 1.5, 0.9)
    glow(c, 360, GROUND_Y - 20, 140, hexc("#ff5a20"), 0.2)
    dots(c, [hexc("#ffb050"), hexc("#ff7030")], 381, 70, 0, GROUND_Y, 1.0)
    for x in (30, 480):
        polygon(c, [(x - 30, H), (x - 6, H - 80), (x + 10, H - 60), (x + 34, H)], hexc("#140a08"))
    vignette(c, 0.55)
    return c


SCENES = {
    "forest": forest, "nightforest": nightforest, "canyon": canyon, "savanna": savanna,
    "snow": snow, "swamp": swamp, "desert": desert, "blight": blight, "jungle": jungle,
    "volcanic": volcanic,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, painter in SCENES.items():
        painter().save("scene_" + name)
        print("Textures/scene_%s.tga" % name)


if __name__ == "__main__":
    main()
