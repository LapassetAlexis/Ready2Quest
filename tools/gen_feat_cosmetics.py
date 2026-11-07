#!/usr/bin/env python3
"""Peint les cosmétiques gagnés par les hauts faits de QuestCompanion (2.7.0, lot E).

TGA non compressés (origine en bas à gauche), puissances de deux, écrits dans
QuestCompanion/Textures/ :

  feat_atlas.tga      256x256 24 bits  fond « Atlas » (zone_100_10) : vieille
                                       carte sépia, côtes, quadrillage, routes du
                                       vent et rose des vents (au centre du
                                       portrait, donc visible aussi dans le disque
                                       du style Azeroth).
  feat_campfire.tga   256x256 24 bits  fond « Feu de camp » (char_camp_25) : nuit
                                       étoilée, pins, feu aux pieds du compagnon,
                                       halo orangé et braises qui montent.
  feat_ornaments.tga  512x64  32 bits  huit cases de 64 px (SetTexCoord) :
                                       0 chaîne du colosse, 1 trois étoiles d'or,
                                       2 œil clos, 3 couronne sauvage, 4 boussole,
                                       5 ruban d'anniversaire, 6 prisme (blanc,
                                       teinté en jeu, teinte qui tourne), 7 halo
                                       (anneau blanc doux : le cadre prismatique
                                       autour de l'anneau du style Azeroth).

Les deux cadres (huit familles, prismatique) n'ont pas de texture : filets,
bordures du client et losanges du thème (FeatsCosmetics.lua).

Rendu : champs de distance numpy peints 4x (cases) ou 2x (fonds) puis réduits
par Pillow (BOX). Sortie déterministe : aucun aléa non semé, même sortie octet
pour octet à chaque lancement (empreintes dans tests/modules/qc27_hf_cosmetiques.lua).

Usage :
  python3 -I tools/gen_feat_cosmetics.py                 # écrit les TGA
  python3 -I tools/gen_feat_cosmetics.py --apercu DIR    # + planche PNG dans DIR
  python3 -I tools/gen_feat_cosmetics.py --sortie DIR    # TGA ailleurs (essais)
  python3 -I tools/gen_feat_cosmetics.py --empreintes    # empreintes des TGA du dépôt
  python3 -I tools/gen_feat_cosmetics.py --verifier      # repeint en mémoire, compare au dépôt
Nécessite Pillow et numpy.
"""
import argparse
import hashlib
import math
import os
import struct

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "QuestCompanion", "Textures")
FILES = ("feat_atlas.tga", "feat_campfire.tga", "feat_ornaments.tga")

INK = (0.13, 0.08, 0.04)
CELL = 64          # case d'ornement finale
SS = 4             # suréchantillonnage des cases
BG = 256           # fond final
BSS = 2            # suréchantillonnage des fonds
# cadre du compagnon 104x118 : le fond est recadré en largeur (u 0,06 à 0,94) ;
# le centre du portrait (et du disque Azeroth) tombe à v = 45/118
PORTRAIT_V = 45 / 118


# ---------------------------------------------------------------------------
# Outils : toile RGBA flottante, champs de distance
# ---------------------------------------------------------------------------
class Canvas:
    def __init__(self, w, h, rgb=(0, 0, 0), alpha=0.0):
        self.rgb = np.empty((h, w, 3), np.float64)
        self.rgb[:] = rgb
        self.a = np.full((h, w), alpha, np.float64)
        ys, xs = np.mgrid[0:h, 0:w]
        self.x = xs + 0.5
        self.y = ys + 0.5

    def over(self, color, alpha):
        alpha = np.clip(alpha, 0.0, 1.0)
        color = np.broadcast_to(np.asarray(color, np.float64), self.rgb.shape) if np.ndim(color) == 1 \
            else color
        out_a = alpha + self.a * (1 - alpha)
        safe = np.where(out_a > 1e-6, out_a, 1.0)
        self.rgb = (color * alpha[..., None] + self.rgb * (self.a * (1 - alpha))[..., None]) / safe[..., None]
        self.a = out_a

    def add(self, color, amount):
        self.rgb = self.rgb + np.asarray(color, np.float64) * np.clip(amount, 0, None)[..., None]

    def image(self, size):
        rgba = np.dstack([np.clip(self.rgb, 0, 1), np.clip(self.a, 0, 1)])
        img = Image.fromarray(np.round(rgba * 255).astype(np.uint8), "RGBA")
        return img.resize(size, Image.BOX)


def cov(d, aa=1.0):
    """couverture d'un champ de distance (négatif dedans), bord adouci"""
    return np.clip(0.5 - d / aa, 0.0, 1.0)


def sd_circle(x, y, cx, cy, r):
    return np.hypot(x - cx, y - cy) - r


def sd_ellipse(x, y, cx, cy, a, b, angle=0.0):
    c, s = math.cos(angle), math.sin(angle)
    dx, dy = x - cx, y - cy
    u, v = dx * c + dy * s, -dx * s + dy * c
    k = np.hypot(u / a, v / b)
    return (k - 1) * min(a, b)


def sd_segment(x, y, ax, ay, bx, by, r):
    px, py = x - ax, y - ay
    ex, ey = bx - ax, by - ay
    h = np.clip((px * ex + py * ey) / (ex * ex + ey * ey), 0, 1)
    return np.hypot(px - ex * h, py - ey * h) - r


def sd_polygon(x, y, pts):
    n = len(pts)
    d = np.full(x.shape, np.inf)
    sign = np.ones(x.shape)
    for i in range(n):
        ax, ay = pts[i]
        bx, by = pts[i - 1]
        ex, ey = bx - ax, by - ay
        wx, wy = x - ax, y - ay
        h = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1)
        d = np.minimum(d, np.hypot(wx - ex * h, wy - ey * h))
        c1 = y >= ay
        c2 = y < by
        c3 = ex * wy > ey * wx
        flip = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
        sign = np.where(flip, -sign, sign)
    return sign * d


def star_points(cx, cy, r_out, r_in, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def mix(a, b, t):
    a, b = np.asarray(a, np.float64), np.asarray(b, np.float64)
    t = np.clip(t, 0, 1)[..., None]
    return a + (b - a) * t


def hexc(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) / 255 for i in (0, 2, 4))


def value_noise(w, h, cell, seed, octaves=4):
    """bruit de valeur lissé, déterministe (RandomState semé)"""
    rng = np.random.RandomState(seed)
    total = np.zeros((h, w))
    norm, amp = 0.0, 1.0
    ys, xs = np.mgrid[0:h, 0:w]
    for o in range(octaves):
        c = cell / (2 ** o)
        gw, gh = int(w / c) + 3, int(h / c) + 3
        grid = rng.rand(gh, gw)
        fx, fy = xs / c, ys / c
        x0, y0 = np.floor(fx).astype(int), np.floor(fy).astype(int)
        tx, ty = fx - x0, fy - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = grid[y0, x0]
        b = grid[y0, x0 + 1]
        cc = grid[y0 + 1, x0]
        d = grid[y0 + 1, x0 + 1]
        total += amp * (a + (b - a) * tx + (cc - a) * ty + (a - b - cc + d) * tx * ty)
        norm += amp
        amp *= 0.5
    return total / norm


def stroke(cv, d, width, color, alpha=1.0, aa=1.0):
    """trait d'épaisseur `width` le long de la courbe d = 0"""
    cv.over(color, cov(np.abs(d) - width / 2, aa) * alpha)


# ---------------------------------------------------------------------------
# Cases d'ornements (peintes en 256x256, réduites à 64x64)
# ---------------------------------------------------------------------------
S = CELL * SS
OW = 7.0   # liseré d'encre (≈ 1,75 px final)


def cyl_shade(d, half):
    """ombrage cylindrique d'un trait : 1 au milieu, 0 au bord"""
    t = np.clip(1 - np.abs(d) / half, 0, 1)
    return np.sqrt(t)


def cell_chain(cv):
    steel_d, steel_m, steel_l = hexc("2e3138"), hexc("7d8591"), hexc("e3e8ef")
    ang = -math.pi / 4
    links = [(76, 180, "ring"), (128, 128, "bar"), (180, 76, "ring")]
    for cx, cy, kind in links:
        if kind == "ring":
            e = sd_ellipse(cv.x, cv.y, cx, cy, 46, 28, ang)
            half = 11.0
            d = np.abs(e) - half
            cv.over(INK, cov(d - OW))
            shade = cyl_shade(e, half)
            light = np.clip(0.5 + ((cv.x - cx) * -0.5 + (cv.y - cy) * -0.6) / 120, 0, 1)
            col = mix(steel_d, steel_m, shade)
            col = mix(col, steel_l, np.clip(shade ** 6 * light * 1.4, 0, 1))
            cv.over(col, cov(d))
        else:
            # maillon vu de profil : une barre épaisse
            dx, dy = 40 * math.cos(ang), 40 * math.sin(ang)
            d = sd_segment(cv.x, cv.y, cx - dx, cy - dy, cx + dx, cy + dy, 15)
            cv.over(INK, cov(d - OW))
            e = sd_segment(cv.x, cv.y, cx - dx, cy - dy, cx + dx, cy + dy, 0)
            shade = cyl_shade(e, 15)
            col = mix(steel_d, steel_m, shade)
            col = mix(col, steel_l, np.clip(shade ** 8 * 1.2, 0, 1))
            cv.over(col, cov(d))


def gold_star(cv, cx, cy, ro, ri, rot=-math.pi / 2):
    pts = star_points(cx, cy, ro, ri, 5, rot)
    d = sd_polygon(cv.x, cv.y, pts)
    cv.over(INK, cov(d - OW))
    ang = np.arctan2(cv.y - cy, cv.x - cx) - rot
    seg = np.mod(ang, 2 * math.pi / 5) / (2 * math.pi / 5)     # 0..1 dans une branche
    light_half = seg < 0.5
    dark, mid, light = hexc("8a5a12"), hexc("e3a733"), hexc("fff0b0")
    r = np.hypot(cv.x - cx, cv.y - cy) / ro
    col = np.where(light_half[..., None], mix(light, mid, r), mix(mid, dark, r * 0.8))
    cv.over(col, cov(d))
    # éclat au cœur
    cv.add((1.0, 0.95, 0.75), np.exp(-((cv.x - cx) ** 2 + (cv.y - cy) ** 2) / (2 * (ro * 0.18) ** 2)) * 0.35 * cov(d))


def cell_goldstars(cv):
    gold_star(cv, 50, 150, 46, 19, -math.pi / 2 - 0.25)
    gold_star(cv, 206, 150, 46, 19, -math.pi / 2 + 0.25)
    gold_star(cv, 128, 112, 74, 30)


def cell_eye(cv):
    cx, cy = 128, 132
    # lueur violette du vide
    r2 = (cv.x - cx) ** 2 + (cv.y - cy) ** 2
    cv.over(hexc("7a3fb0"), np.exp(-r2 / (2 * 70 ** 2)) * 0.55)
    # amande : intersection de deux cercles
    d1 = sd_circle(cv.x, cv.y, cx, cy - 100, 150)
    d2 = sd_circle(cv.x, cv.y, cx, cy + 100, 150)
    lens = np.maximum(d1, d2)
    cv.over(INK, cov(lens - OW))
    lid_top, lid_low = hexc("b77fe0"), hexc("3a1752")
    t = np.clip((cv.y - (cy - 50)) / 100, 0, 1)
    cv.over(mix(lid_top, lid_low, t), cov(lens))
    # reflet de la paupière
    hi = sd_ellipse(cv.x, cv.y, cx - 10, cy - 24, 56, 9, -0.05)
    cv.over((1, 0.92, 1), cov(hi, 3.0) * 0.45)
    # la ligne des cils, courbée vers le bas, et les cils
    arc = sd_circle(cv.x, cv.y, cx, cy - 150, 168)
    inside = cov(lens + 2)
    cv.over(hexc("120614"), cov(np.abs(arc) - 5) * inside)
    for i in range(7):
        u = -0.75 + i * 0.25
        a = math.pi / 2 + u * 0.55
        px, py = cx + 168 * math.cos(a), cy - 150 + 168 * math.sin(a)
        ln = 22 + (1 - abs(u)) * 12
        qx, qy = px + ln * math.cos(a), py + ln * math.sin(a)
        d = sd_segment(cv.x, cv.y, px, py, qx, qy, 4.2)
        cv.over(hexc("120614"), cov(d))
    # trois petites larmes de vide sous l'œil
    for i, (x, y, r) in enumerate(((cx - 52, cy + 66, 7), (cx, cy + 80, 9), (cx + 52, cy + 66, 7))):
        d = sd_circle(cv.x, cv.y, x, y, r)
        cv.over(INK, cov(d - 4))
        cv.over(hexc("c79bea"), cov(d))


def cell_wildcrown(cv):
    bark_d, bark_m, bark_l = hexc("3b2412"), hexc("7a4f28"), hexc("b88a52")
    leaf_d, leaf_m, leaf_l = hexc("1f4a1a"), hexc("3f8a2c"), hexc("9ed163")
    shapes = []
    # bandeau de bois tressé : deux brins qui ondulent
    for phase in (0.0, math.pi):
        pts = []
        for i in range(25):
            x = 34 + i * 7.83
            y = 196 + 9 * math.sin(i * 0.9 + phase)
            pts.append((x, y))
        shapes.append(("bark", pts, 10))
    # bois : trois andouillers à gauche, en miroir à droite
    prongs = [
        [(70, 190), (56, 140), (40, 96)],
        [(56, 140), (24, 120)],
        [(98, 188), (100, 120), (92, 60)],
        [(100, 124), (74, 92)],
        [(128, 188), (128, 100), (128, 34)],
    ]
    for p in list(prongs):
        if p[0][0] != 128:
            prongs.append([(256 - x, y) for x, y in p])
    for p in prongs:
        shapes.append(("bark", p, 8 if p[0][1] > 150 else 6))
    # liseré, puis bois
    for kind, pts, r in shapes:
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            cv.over(INK, cov(sd_segment(cv.x, cv.y, ax, ay, bx, by, r) - OW))
    for kind, pts, r in shapes:
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            e = sd_segment(cv.x, cv.y, ax, ay, bx, by, 0)
            col = mix(bark_d, bark_m, cyl_shade(e, r))
            col = mix(col, bark_l, cyl_shade(e, r) ** 6)
            cv.over(col, cov(e - r))
    # feuilles aux pointes et sur le bandeau
    leaves = [(40, 92, -2.4), (24, 116, -2.9), (92, 56, -1.9), (74, 88, -2.6), (128, 30, -1.57),
              (60, 200, -0.3), (100, 206, 0.2), (128, 198, -0.1)]
    leaves += [(256 - x, y, math.pi - a) for x, y, a in leaves if x != 128]
    for x, y, a in leaves:
        e = sd_ellipse(cv.x, cv.y, x, y, 17, 8, a)
        cv.over(INK, cov(e - OW * 0.8))
    for x, y, a in leaves:
        e = sd_ellipse(cv.x, cv.y, x, y, 17, 8, a)
        side = (cv.x - x) * -math.sin(a) + (cv.y - y) * math.cos(a)
        col = np.where((side < 0)[..., None], mix(leaf_l, leaf_m, np.clip(-e / 8, 0, 1) * 0),
                       mix(leaf_m, leaf_d, np.clip(side / 8, 0, 1)))
        cv.over(col, cov(e))
    # baies rouges au centre du bandeau
    for x, y in ((112, 184), (128, 178), (144, 184)):
        d = sd_circle(cv.x, cv.y, x, y, 7)
        cv.over(INK, cov(d - 4))
        cv.over(hexc("d2382c"), cov(d))
        cv.over((1, 0.8, 0.7), cov(sd_circle(cv.x, cv.y, x - 2, y - 2, 2)))


def cell_compass(cv):
    cx, cy = 128, 136
    brass_d, brass_m, brass_l = hexc("6b4a14"), hexc("c8952e"), hexc("ffe29a")
    # anneau de suspension
    e = sd_circle(cv.x, cv.y, cx, 28, 14)
    cv.over(INK, cov(np.abs(e) - 5 - OW))
    cv.over(mix(brass_d, brass_l, cyl_shade(e, 5)), cov(np.abs(e) - 5))
    outer = sd_circle(cv.x, cv.y, cx, cy, 104)
    cv.over(INK, cov(outer - OW))
    light = np.clip(0.5 - ((cv.x - cx) + (cv.y - cy)) / 260, 0, 1)
    cv.over(mix(brass_d, brass_l, light), cov(outer))
    face = sd_circle(cv.x, cv.y, cx, cy, 84)
    cv.over(INK, cov(np.abs(face) - 3))
    t = np.clip(np.hypot(cv.x - cx, cv.y - cy) / 84, 0, 1)
    cv.over(mix(hexc("fbf2dc"), hexc("d9c79e"), t), cov(face))
    # graduations
    for i in range(16):
        a = i * math.pi / 8
        r0 = 64 if i % 4 else 54
        d = sd_segment(cv.x, cv.y, cx + r0 * math.cos(a), cy + r0 * math.sin(a),
                       cx + 78 * math.cos(a), cy + 78 * math.sin(a), 2.6 if i % 4 else 4)
        cv.over(hexc("4a3420"), cov(d))
    # aiguille : nord rouge, sud acier
    rot = -math.pi / 2 + 0.35
    tip_n = (cx + 70 * math.cos(rot), cy + 70 * math.sin(rot))
    tip_s = (cx - 70 * math.cos(rot), cy - 70 * math.sin(rot))
    side = (cx + 14 * math.cos(rot + math.pi / 2), cy + 14 * math.sin(rot + math.pi / 2))
    side2 = (cx - 14 * math.cos(rot + math.pi / 2), cy - 14 * math.sin(rot + math.pi / 2))
    north = sd_polygon(cv.x, cv.y, [tip_n, side, side2])
    south = sd_polygon(cv.x, cv.y, [tip_s, side2, side])
    cv.over(INK, cov(np.minimum(north, south) - 4))
    cv.over(hexc("d63a2a"), cov(north))
    cv.over(hexc("4c6c9a"), cov(south))
    pin = sd_circle(cv.x, cv.y, cx, cy, 10)
    cv.over(INK, cov(pin - 3))
    cv.over(mix(brass_l, brass_m, np.clip(np.hypot(cv.x - cx + 3, cv.y - cy + 3) / 10, 0, 1)), cov(pin))


def cell_anniversary(cv):
    cx, cy = 128, 104
    red_d, red_m, red_l = hexc("6e0f12"), hexc("c0262b"), hexc("f06a5a")
    gold_d, gold_l = hexc("9a6a18"), hexc("ffe08a")
    # queues : deux bandes encochées
    for sgn in (-1, 1):
        x0, y0 = cx + sgn * 14, cy + 30
        x1, y1 = cx + sgn * 62, 236
        w = 24
        nx, ny = (y1 - y0), -(x1 - x0)
        ln = math.hypot(nx, ny)
        nx, ny = nx / ln * w, ny / ln * w
        notch = (x1 - (x1 - x0) * 0.16, y1 - (y1 - y0) * 0.16)
        pts = [(x0 - nx, y0 - ny), (x0 + nx, y0 + ny), (x1 + nx, y1 + ny), notch, (x1 - nx, y1 - ny)]
        d = sd_polygon(cv.x, cv.y, pts)
        cv.over(INK, cov(d - OW))
        t = np.clip((cv.y - y0) / (y1 - y0), 0, 1)
        cv.over(mix(red_m, red_d, t), cov(d))
        # liseré d'or le long des deux bords
        for s2 in (-1, 1):
            e = sd_segment(cv.x, cv.y, x0 + s2 * nx * 0.72, y0 + s2 * ny * 0.72,
                           x1 + s2 * nx * 0.72, y1 + s2 * ny * 0.72, 3)
            cv.over(gold_l, cov(e) * cov(d + 2))
    # cocarde plissée
    ang = np.arctan2(cv.y - cy, cv.x - cx)
    r = np.hypot(cv.x - cx, cv.y - cy)
    pleat = np.cos(ang * 18)
    d = r - (76 + 7 * pleat)
    cv.over(INK, cov(d - OW))
    cv.over(mix(red_d, red_l, 0.5 + 0.5 * pleat), cov(d))
    ring = r - 54
    cv.over(INK, cov(ring - 5))
    cv.over(mix(gold_l, gold_d, np.clip(r / 54, 0, 1) ** 2), cov(ring))
    # une étoile en relief au cœur
    s = sd_polygon(cv.x, cv.y, star_points(cx, cy, 32, 13))
    cv.over(gold_d, cov(np.abs(s) - 2.5))
    cv.over(hexc("fff4c4"), cov(s + 3))


def cell_prism(cv):
    """gemme blanche à facettes (teintée en jeu) et une étincelle"""
    cx, cy = 116, 140
    top, mid_y, bot = cy - 92, cy - 30, cy + 96
    pts = [(cx, top), (cx + 62, mid_y), (cx, bot), (cx - 62, mid_y)]
    outline = sd_polygon(cv.x, cv.y, pts)
    cv.over((0.12, 0.12, 0.14), cov(outline - OW))
    facets = [
        ([(cx, top), (cx + 62, mid_y), (cx, mid_y)], 0.96),
        ([(cx, top), (cx, mid_y), (cx - 62, mid_y)], 1.0),
        ([(cx - 62, mid_y), (cx, mid_y), (cx, bot)], 0.72),
        ([(cx, mid_y), (cx + 62, mid_y), (cx, bot)], 0.55),
        ([(cx - 26, mid_y), (cx + 26, mid_y), (cx, bot - 30)], 0.85),
    ]
    for poly, g in facets:
        d = sd_polygon(cv.x, cv.y, poly)
        cv.over((g, g, g), cov(d) * cov(outline))
    # arêtes claires
    for (ax, ay), (bx, by) in (((cx, top), (cx, bot)), ((cx - 62, mid_y), (cx + 62, mid_y))):
        cv.over((1, 1, 1), cov(sd_segment(cv.x, cv.y, ax, ay, bx, by, 2.2)) * cov(outline) * 0.8)
    # étincelle à quatre branches
    sx, sy = 196, 64
    for a in (0, math.pi / 2):
        for l, w in ((44, 6), (26, 10)):
            d = sd_segment(cv.x, cv.y, sx - l * math.cos(a), sy - l * math.sin(a),
                           sx + l * math.cos(a), sy + l * math.sin(a), 0)
            along = np.abs((cv.x - sx) * math.cos(a) + (cv.y - sy) * math.sin(a)) / l
            cv.over((1, 1, 1), cov(d - w * np.clip(1 - along, 0, 1)))
    r2 = (cv.x - sx) ** 2 + (cv.y - sy) ** 2
    cv.over((1, 1, 1), np.exp(-r2 / (2 * 16 ** 2)) * 0.6)


def cell_halo(cv):
    """anneau blanc doux (ADD, teinté) : le cadre prismatique en style Azeroth"""
    r = np.hypot(cv.x - S / 2, cv.y - S / 2) / (S / 2)
    a = np.exp(-((r - 0.80) / 0.075) ** 2) + 0.35 * np.exp(-((r - 0.80) / 0.17) ** 2)
    cv.rgb[:] = 1.0
    cv.a = np.clip(a, 0, 1) * (r < 0.99)


CELLS = (cell_chain, cell_goldstars, cell_eye, cell_wildcrown, cell_compass, cell_anniversary,
         cell_prism, cell_halo)


def paint_ornaments():
    sheet = Image.new("RGBA", (CELL * len(CELLS), CELL), (0, 0, 0, 0))
    for index, fn in enumerate(CELLS):
        cv = Canvas(S, S, (1, 1, 1), 0.0)
        fn(cv)
        sheet.paste(cv.image((CELL, CELL)), (index * CELL, 0))
    return sheet


# ---------------------------------------------------------------------------
# Fonds (peints en 512x512, réduits à 256x256)
# ---------------------------------------------------------------------------
B = BG * BSS


def paint_atlas():
    cv = Canvas(B, B, (0, 0, 0), 1.0)
    x, y = cv.x, cv.y
    stain = value_noise(B, B, 160, 7, 5)
    paper_l, paper_d = hexc("b89a68"), hexc("6e5232")
    base = mix(paper_d, paper_l, 0.35 + 0.65 * stain)
    cv.rgb = base.copy()
    # terres : seuil d'un bruit, une grande île à gauche et une côte à droite
    land_f = value_noise(B, B, 210, 23, 5)
    land_f = land_f + 0.22 * np.exp(-((x - 90) ** 2 + (y - 300) ** 2) / (2 * 120 ** 2)) \
        + 0.18 * np.exp(-((x - 470) ** 2 + (y - 120) ** 2) / (2 * 110 ** 2)) \
        - 0.18 * np.exp(-((x - 256) ** 2 + (y - 195) ** 2) / (2 * 95 ** 2))
    t = 0.56
    land = land_f > t
    gy, gx = np.gradient(land_f)
    grad = np.hypot(gx, gy) + 1e-6
    dist = (land_f - t) / grad          # distance (px) à la côte, positive sur terre
    sea_col = mix(hexc("5b5a48"), hexc("7c7656"), stain)
    cv.over(sea_col, (~land).astype(float) * 0.55)
    cv.over(hexc("c2a873"), land.astype(float) * 0.30)
    # lignes de rivage dans la mer (vieilles cartes), puis la côte à l'encre
    for k, alpha in ((10, 0.35), (20, 0.22), (32, 0.12)):
        stroke(cv, dist + k, 2.2, hexc("3a2a18"), alpha, 1.5)
    stroke(cv, dist, 4.0, hexc("2a1a0c"), 0.9, 1.5)
    # petites montagnes sur les terres
    rng = np.random.RandomState(1107)
    placed = 0
    for _ in range(400):
        mx, my = rng.randint(30, B - 30), rng.randint(30, B - 60)
        if placed >= 14:
            break
        if dist[my, mx] > 26 and math.hypot(mx - 256, my - 195) > 120:
            pts = [(mx - 13, my + 9), (mx, my - 11), (mx + 13, my + 9)]
            for (ax, ay), (bx, by) in zip(pts, pts[1:]):
                stroke(cv, sd_segment(x, y, ax, ay, bx, by, 0), 3.0, hexc("2a1a0c"), 0.75, 1.5)
            placed += 1
    # quadrillage
    for k in range(64, B, 64):
        stroke(cv, x - k, 1.6, hexc("2a1a0c"), 0.18, 1.2)
        stroke(cv, y - k, 1.6, hexc("2a1a0c"), 0.18, 1.2)
    # routes du vent depuis la rose
    cx, cy = 256, PORTRAIT_V * B
    r = np.hypot(x - cx, y - cy)
    ang = np.arctan2(y - cy, x - cx)
    for i in range(16):
        a = i * math.pi / 8
        d = (x - cx) * -math.sin(a) + (y - cy) * math.cos(a)
        ahead = ((x - cx) * math.cos(a) + (y - cy) * math.sin(a)) > 0
        cv.over(hexc("2a1a0c"), cov(np.abs(d) - 0.9, 1.2) * ahead * (r > 100) * 0.28)
    # rose des vents
    ring1, ring2 = r - 96, r - 84
    stroke(cv, ring1, 3.0, hexc("2a1a0c"), 0.9, 1.4)
    stroke(cv, ring2, 2.0, hexc("2a1a0c"), 0.9, 1.4)
    for i in range(32):
        a = i * math.pi / 16
        d = sd_segment(x, y, cx + 84 * math.cos(a), cy + 84 * math.sin(a),
                       cx + (96 if i % 2 == 0 else 90) * math.cos(a), cy + (96 if i % 2 == 0 else 90) * math.sin(a), 0.9)
        cv.over(hexc("2a1a0c"), cov(d, 1.2) * 0.9)
    cream, ink = hexc("f2e3bf"), hexc("2a1a0c")
    for big in (False, True):
        for i in range(4):
            a = i * math.pi / 2 + (0 if big else math.pi / 4)
            length, width = (110, 20) if big else (66, 14)
            tip = (cx + length * math.cos(a), cy + length * math.sin(a))
            left = (cx + width * math.cos(a - math.pi / 2), cy + width * math.sin(a - math.pi / 2))
            right = (cx + width * math.cos(a + math.pi / 2), cy + width * math.sin(a + math.pi / 2))
            half_l = sd_polygon(x, y, [tip, left, (cx, cy)])
            half_r = sd_polygon(x, y, [tip, (cx, cy), right])
            cv.over(ink, cov(np.minimum(half_l, half_r) - 3, 1.4))
            cv.over(cream, cov(half_l, 1.4))
            cv.over(hexc("7a4c22") if big else hexc("5a3a1c"), cov(half_r, 1.4))
    hub = sd_circle(x, y, cx, cy, 9)
    cv.over(ink, cov(hub - 3, 1.4))
    cv.over(hexc("c8952e"), cov(hub, 1.4))
    # fleur du nord : pointe rouge au-delà du cercle
    nt = sd_polygon(x, y, [(cx, cy - 128), (cx - 9, cy - 112), (cx + 9, cy - 112)])
    cv.over(ink, cov(nt - 2.5, 1.4))
    cv.over(hexc("b8322a"), cov(nt, 1.4))
    # vignettage, plus sombre en bas (le nom du compagnon s'y écrit)
    u, v = x / B - 0.5, y / B - 0.42
    vig = np.clip(1 - (u * u * 1.6 + v * v * 1.3) * 1.25, 0.35, 1)
    low = 1 - 0.40 * np.clip((y / B - 0.70) / 0.30, 0, 1)
    cv.rgb = cv.rgb * (vig * low)[..., None]
    return cv.image((BG, BG)).convert("RGB")


def paint_campfire():
    cv = Canvas(B, B, (0, 0, 0), 1.0)
    x, y = cv.x, cv.y
    fy = 0.70 * B              # le feu, aux pieds du compagnon
    fx = 256
    v = y / B
    sky = np.where((v < 0.55)[..., None], mix(hexc("05071a"), hexc("1a1230"), v / 0.55),
                   mix(hexc("1a1230"), hexc("3a1a14"), (v - 0.55) / 0.2))
    cv.rgb = sky
    # étoiles semées
    rng = np.random.RandomState(365)
    for _ in range(90):
        sx, sy = rng.uniform(0, B), rng.uniform(0, B * 0.58)
        size = rng.choice((1.2, 1.6, 2.4), p=(0.6, 0.3, 0.1))
        bright = rng.uniform(0.45, 1.0) * (1 - np.clip(1 - math.hypot(sx - fx, sy - fy) / 300, 0, 1))
        cv.add((0.85, 0.88, 1.0), np.exp(-((x - sx) ** 2 + (y - sy) ** 2) / (2 * size ** 2)) * bright)
    # collines lointaines
    hills = 0.66 * B - 26 * value_noise(B, 1, 120, 11, 3)[0][None, :] - 10
    cv.over(hexc("0e0c1c"), cov(hills - y, 1.5))
    # sol
    ground = 0.74 * B + 6 * np.sin(x / 70)
    cv.over(hexc("120a08"), cov(ground - y, 1.5))
    # pins de chaque côté
    def pine(px, base, height, width):
        d = np.full(x.shape, np.inf)
        for k in range(4):
            top = base - height + k * height * 0.22
            w = width * (0.45 + 0.18 * k)
            tri = sd_polygon(x, y, [(px, top), (px + w, top + height * 0.42), (px - w, top + height * 0.42)])
            d = np.minimum(d, tri)
        d = np.minimum(d, sd_segment(x, y, px, base - height * 0.2, px, base + 8, 5))
        return d
    for px, base, h, w in ((40, 400, 300, 60), (112, 392, 210, 44), (472, 404, 320, 64), (402, 390, 200, 40),
                           (-6, 410, 360, 70), (520, 410, 360, 70)):
        cv.over(hexc("07060e"), cov(pine(px, base, h, w), 1.5))
    # halo du feu (additif)
    r2 = (x - fx) ** 2 + ((y - fy) * 1.25) ** 2
    cv.add(hexc("ff7a24"), np.exp(-r2 / (2 * 120 ** 2)) * 0.55)
    cv.add(hexc("ffb347"), np.exp(-r2 / (2 * 50 ** 2)) * 0.45)
    # bûches croisées
    for sgn in (-1, 1):
        d = sd_segment(x, y, fx - 40 * sgn, fy + 22, fx + 36 * sgn, fy + 6, 8)
        cv.over(hexc("1c0f08"), cov(d - 2, 1.5))
        cv.over(hexc("5a341a"), cov(d, 1.5))
    # flammes : gouttes déformées, du rouge au jaune
    wob = value_noise(B, B, 22, 5, 2) - 0.5
    for scale, col in ((1.0, hexc("d8401c")), (0.72, hexc("ff8a2a")), (0.46, hexc("ffd25a")), (0.24, hexc("fff4c0"))):
        h = 78 * scale
        w = 30 * scale
        cy = fy + 4 - h * 0.35
        rel_y = (y - cy) / h
        width = w * np.clip(1 - np.clip(-rel_y, 0, 1) ** 1.3, 0, 1) * np.clip(1 - np.clip(rel_y, 0, None) * 2.2, 0, 1)
        dx = np.abs(x - fx - wob * 26 * (1 - rel_y) * scale)
        d = np.where((rel_y > -1) & (rel_y < 0.45), dx - width, 99.0)
        cv.over(col, cov(d, 2.0) * 0.95)
    # braises qui montent (dérive lissée, plus petites et plus pâles en haut)
    rng = np.random.RandomState(25)
    for i in range(70):
        t = rng.uniform(0, 1) ** 0.8
        ey = fy - 30 - t * (fy - 30)
        drift = math.sin(i * 1.7 + t * 6.0) * 30 * t + rng.normal(0, 14) * t
        ex = fx + drift
        size = 2.6 - 1.4 * t
        bright = (1 - t) * 0.9 + 0.15
        col = (1.0, 0.55 + 0.35 * (1 - t), 0.18)
        cv.add(col, np.exp(-((x - ex) ** 2 + (y - ey) ** 2) / (2 * size ** 2)) * bright)
    # bas assombri : le nom s'y lit
    low = 1 - 0.35 * np.clip((y / B - 0.78) / 0.22, 0, 1)
    cv.rgb = cv.rgb * low[..., None]
    return cv.image((BG, BG)).convert("RGB")


# ---------------------------------------------------------------------------
# Sortie
# ---------------------------------------------------------------------------
def tga_bytes(image):
    """TGA non compressé, origine en bas à gauche : BGR(A)"""
    flipped = image.transpose(Image.FLIP_TOP_BOTTOM)
    arr = np.asarray(flipped)
    if image.mode == "RGBA":
        data = arr[..., [2, 1, 0, 3]].tobytes()
        header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, image.width, image.height, 32, 8)
    else:
        data = arr[..., [2, 1, 0]].tobytes()
        header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, image.width, image.height, 24, 0)
    return header + data


def paint_all():
    return {
        "feat_atlas.tga": paint_atlas(),
        "feat_campfire.tga": paint_campfire(),
        "feat_ornaments.tga": paint_ornaments(),
    }


def fingerprints(folder):
    """empreintes : taille, SHA-1 et Adler-32 (celle que refait la suite de tests en Lua)"""
    out = {}
    for name in FILES:
        with open(os.path.join(folder, name), "rb") as handle:
            data = handle.read()
        out[name] = (len(data), hashlib.sha1(data).hexdigest(), adler32(data))
    return out


def adler32(data):
    import zlib
    return zlib.adler32(data) & 0xFFFFFFFF


# ---------------------------------------------------------------------------
# Aperçu (planche PNG, jamais dans le dépôt)
# ---------------------------------------------------------------------------
def planche(tex, path):
    from PIL import ImageDraw
    Z = 2
    fw, fh = 104 * Z, 118 * Z
    pad = 20
    W = max(pad + (fw + pad) * 4, pad + len(CELLS) * (CELL * 2 + 8))
    H = pad + (fh + pad) * 2 + (CELL * 2 + pad) * 2 + 60
    sheet = Image.new("RGB", (W, H), (34, 30, 28))
    draw = ImageDraw.Draw(sheet)

    def crop_bg(img):
        w, h = img.size
        box = (int(0.06 * w), 0, int(0.94 * w), h)
        return img.crop(box).resize((fw, fh), Image.LANCZOS)

    def disc(img):
        out = img.copy().convert("RGBA")
        mask = Image.new("L", (fw, fh), 0)
        md = ImageDraw.Draw(mask)
        cx, cy, r = fw / 2, 45 * Z, 39 * Z
        md.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
        bg = Image.new("RGBA", (fw, fh), (20, 18, 16, 255))
        bg.paste(out, (0, 0), mask)
        d2 = ImageDraw.Draw(bg)
        rr = 52 * Z
        d2.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=(214, 170, 80), width=5 * Z)
        d2.rectangle((0, fh - 42 * Z, fw, fh), fill=(60, 44, 24))
        return bg

    x = pad
    for name in ("feat_atlas.tga", "feat_campfire.tga"):
        img = crop_bg(tex[name])
        sheet.paste(img, (x, pad))
        draw.text((x, pad + fh + 2), name + " (Sobre)", fill=(230, 220, 200))
        x += fw + pad
        sheet.paste(disc(img).convert("RGB"), (x, pad))
        draw.text((x, pad + fh + 2), "disque Azeroth", fill=(230, 220, 200))
        x += fw + pad

    # cadres : maquettes schématiques
    y0 = pad * 2 + fh
    types = [(0.80, 0.55, 0.28), (0.90, 0.80, 0.58), (0.60, 0.85, 0.55), (0.45, 0.80, 1.0),
             (0.95, 0.35, 0.25), (0.70, 0.40, 0.95), (0.62, 0.66, 0.76), (0.85, 0.60, 0.35)]
    atlas = crop_bg(tex["feat_atlas.tga"])
    for col, kind in enumerate(("eight", "eight_az", "prism", "prism_az")):
        x = pad + col * (fw + pad)
        base = Image.new("RGB", (fw, fh), (12, 10, 10))
        base.paste(atlas.point(lambda v: int(v * 0.6)), (0, 0))
        if kind.endswith("_az"):
            base = disc(base).convert("RGB")
        d = ImageDraw.Draw(base)
        if kind == "eight":
            d.rectangle((2, 2, fw - 3, fh - 3), outline=(232, 166, 74), width=3)
            d.rectangle((8, 8, fw - 9, fh - 9), outline=(150, 108, 48), width=2)
            pts = [(0, 0), (0.5, 0), (1, 0), (1, 0.5), (1, 1), (0.5, 1), (0, 1), (0, 0.5)]
            for (u, v), c in zip(pts, types):
                cx, cy = 4 + u * (fw - 8), 4 + v * (fh - 8)
                s = 9 * Z / 2
                d.polygon([(cx, cy - s), (cx + s, cy), (cx, cy + s), (cx - s, cy)], fill=tuple(int(k * 255) for k in c),
                          outline=(40, 24, 8))
        elif kind == "eight_az":
            cx, cy, r = fw / 2, 45 * Z, 50 * Z
            for i, c in enumerate(types):
                a = math.radians(22.5 + 45 * i)
                px, py = cx + r * math.cos(a), cy + r * math.sin(a)
                s = 10 * Z / 2
                d.polygon([(px, py - s), (px + s, py), (px, py + s), (px - s, py)],
                          fill=tuple(int(k * 255) for k in c), outline=(40, 24, 8))
        elif kind == "prism":
            for i, (a, b) in enumerate((((2, 2), (fw - 3, 2)), ((fw - 3, 2), (fw - 3, fh - 3)),
                                        ((fw - 3, fh - 3), (2, fh - 3)), ((2, fh - 3), (2, 2)))):
                import colorsys
                c = colorsys.hsv_to_rgb(i * 0.25, 0.6, 1.0)
                d.line([a, b], fill=tuple(int(k * 255) for k in c), width=4)
        else:
            halo = tex["feat_ornaments.tga"].crop((7 * CELL, 0, 8 * CELL, CELL)).resize((124 * Z, 124 * Z), Image.LANCZOS)
            tint = Image.new("RGBA", halo.size, (140, 220, 255, 255))
            tint.putalpha(halo.split()[3])
            b2 = base.convert("RGBA")
            b2.alpha_composite(tint, (int(fw / 2 - 62 * Z), int(45 * Z - 62 * Z)))
            base = b2.convert("RGB")
        sheet.paste(base, (x, y0))
        draw.text((x, y0 + fh + 2), {"eight": "cadre huit familles", "eight_az": "huit familles (Azeroth)",
                                     "prism": "cadre prismatique", "prism_az": "prismatique (Azeroth)"}[kind],
                  fill=(230, 220, 200))

    # ornements x2 sur fond sombre puis clair
    orn = tex["feat_ornaments.tga"]
    names = ("chaine", "etoiles d'or", "oeil clos", "couronne sauvage", "boussole", "ruban", "prisme", "halo")
    y1 = y0 + fh + pad + 14
    for row, back in enumerate(((24, 22, 30), (200, 186, 160))):
        for i in range(len(CELLS)):
            cell = orn.crop((i * CELL, 0, (i + 1) * CELL, CELL)).resize((CELL * 2, CELL * 2), Image.LANCZOS)
            tile = Image.new("RGBA", cell.size, back + (255,))
            if i == 6:   # le prisme, teinté comme en jeu
                r, g, b, a = cell.split()
                cell = Image.merge("RGBA", (r, g.point(lambda v: int(v * 0.7)), b, a))
            tile.alpha_composite(cell)
            px = pad + i * (CELL * 2 + 8)
            py = y1 + row * (CELL * 2 + 8)
            sheet.paste(tile.convert("RGB"), (px, py))
            if row == 1:
                draw.text((px, py + CELL * 2 + 2), names[i], fill=(230, 220, 200))
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--sortie", default=OUT, help="dossier des TGA (défaut : QuestCompanion/Textures)")
    parser.add_argument("--apercu", help="dossier où écrire la planche PNG (jamais dans le dépôt)")
    parser.add_argument("--empreintes", action="store_true", help="affiche les empreintes des TGA de --sortie")
    parser.add_argument("--verifier", action="store_true", help="repeint en mémoire et compare aux TGA de --sortie")
    args = parser.parse_args()
    if args.verifier:
        diff = []
        for name, image in paint_all().items():
            path = os.path.join(args.sortie, name)
            current = open(path, "rb").read() if os.path.exists(path) else b""
            if current != tga_bytes(image):
                diff.append(name)
        print("identiques" if not diff else "différents : " + ", ".join(diff))
        raise SystemExit(1 if diff else 0)
    if args.empreintes:
        for name, (size, sha, adler) in fingerprints(args.sortie).items():
            print("%-20s %7d  adler32=%10d  sha1=%s" % (name, size, adler, sha))
        return
    tex = paint_all()
    os.makedirs(args.sortie, exist_ok=True)
    for name, image in tex.items():
        with open(os.path.join(args.sortie, name), "wb") as handle:
            handle.write(tga_bytes(image))
        print("écrit", os.path.join(args.sortie, name))
    if args.apercu:
        os.makedirs(args.apercu, exist_ok=True)
        planche(tex, os.path.join(args.apercu, "feat_cosmetics_preview.png"))
        print("aperçu écrit dans", args.apercu)


if __name__ == "__main__":
    main()
