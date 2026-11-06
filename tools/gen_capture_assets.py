#!/usr/bin/env python3
"""Peint les textures de la scène de capture de QuestCompanion (2.1.0).

Toutes en TGA 32 bits non compressé (origine en bas à gauche), puissances de
deux, écrites dans QuestCompanion/Textures/ :

  filet.tga        512x256  deux images 256x256 : le filet entier (gauche) et le
                            filet déchiré (droite) ; cordes torsadées, nœuds,
                            lest au bord, ombre portée. Pas teinté.
  paquet.tga       64x64    le filet roulé en boule, lancé en tournant.
  corde.tga        128x16   un bout de corde effiloché : les morceaux qui volent
                            quand le filet se déchire.
  halo.tga         128x128  halo doux blanc (ADD, teinté à la rareté).
  rayons.tga       256x256  gerbe de rayons blancs (ADD, teintée, tournée).
  particules.tga   128x32   quatre sprites 32x32 blancs : point doux, étoile à
                            quatre branches, étincelle à six, anneau (poussière).
  etoiles.tga      128x64   l'étoile du spécimen, pleine (gauche) et vide (droite),
                            blanche : teintée or ou gris.
  ruban.tga        256x128  le ruban de la bannière : panneau ombré (haut, blanc,
                            teinté sombre) et liseré (bas, blanc, teinté à la rareté).
  vignette.tga     128x128  fond de scène : vignettage d'encre et sol.
  filet_icone.tga  32x32    glyphe blanc du bouton filet (teinté ambre / or).

Rendu : champs de distance numpy (cordes cylindriques, torsade, nœuds), puis
Pillow pour les ombres, le rééchantillonnage et les aperçus. Sortie déterministe
(aucun aléa non semé).

Usage :
  python3 -I tools/gen_capture_assets.py                 # écrit les TGA
  python3 -I tools/gen_capture_assets.py --apercu DIR    # + planche et maquettes PNG dans DIR
  python3 -I tools/gen_capture_assets.py --sortie DIR    # TGA ailleurs (essais)
Nécessite Pillow et numpy.
"""
import argparse
import math
import os
import random
import struct

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "QuestCompanion", "Textures")
MEDIA = os.path.join(ROOT, "Ready2Quest", "Libs", "Socle", "Media")

# couleurs (0-255)
ROPE_LIGHT = (236, 206, 150)
ROPE_MID = (190, 150, 92)
ROPE_DARK = (104, 72, 36)
INK = (16, 12, 8)
LEAD_LIGHT = (150, 150, 158)
LEAD_DARK = (46, 46, 52)
LIGHT_DIR = (-0.55, -0.83)   # lumière en haut à gauche (y vers le bas)


# ---------------------------------------------------------------------------
# Toile numpy : compositing « over » en alpha prémultiplié
# ---------------------------------------------------------------------------
class Canvas:
    def __init__(self, width, height):
        self.w, self.h = width, height
        self.rgb = np.zeros((height, width, 3), np.float32)   # prémultiplié
        self.a = np.zeros((height, width), np.float32)
        ys, xs = np.mgrid[0:height, 0:width]
        self.x = xs.astype(np.float32) + 0.5
        self.y = ys.astype(np.float32) + 0.5

    def box(self, x0, y0, x1, y1):
        x0, y0 = max(0, int(math.floor(x0))), max(0, int(math.floor(y0)))
        x1, y1 = min(self.w, int(math.ceil(x1)) + 1), min(self.h, int(math.ceil(y1)) + 1)
        if x1 <= x0 or y1 <= y0:
            return None
        return (slice(y0, y1), slice(x0, x1))

    def over(self, sl, rgb, alpha):
        """rgb : (h,w,3) 0-1 droit ou tuple 0-255 ; alpha : (h,w) 0-1"""
        if sl is None:
            return
        if isinstance(rgb, tuple):
            rgb = np.array(rgb, np.float32)[None, None, :] / 255.0
        a = np.clip(alpha, 0, 1)[..., None]
        self.rgb[sl] = rgb * a + self.rgb[sl] * (1 - a)
        self.a[sl] = a[..., 0] + self.a[sl] * (1 - a[..., 0])

    def image(self, fill=None):
        """Image RGBA (alpha droit). fill : couleur des pixels transparents."""
        a = np.clip(self.a, 0, 1)
        rgb = self.rgb / np.maximum(a, 1e-4)[..., None]
        rgb = np.clip(rgb, 0, 1)
        if fill is not None:
            f = np.array(fill, np.float32)[None, None, :] / 255.0
            w = np.clip(a / 0.02, 0, 1)[..., None]
            rgb = rgb * w + f * (1 - w)
        out = np.concatenate([rgb, a[..., None]], axis=2)
        return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def value_noise(width, height, cell, seed, octaves=3):
    """Bruit de valeur lissé (0..1), déterministe : grilles aléatoires agrandies."""
    rng = np.random.default_rng(seed)
    total, norm, amp = np.zeros((height, width), np.float32), 0.0, 1.0
    for octave in range(octaves):
        n = max(2, int(round(max(width, height) / cell)))
        grid_ = rng.random((n, n)).astype(np.float32)
        img = Image.fromarray((grid_ * 255).astype(np.uint8), "L").resize((width, height), Image.BICUBIC)
        total += amp * (np.asarray(img).astype(np.float32) / 255.0)
        norm += amp
        amp *= 0.5
        cell = max(2, cell / 2)
    return total / norm


def material(canvas, seed, cell=40):
    """Variation de matière : luminosité (usure, saleté) et chaleur de teinte."""
    bright = 0.86 + 0.26 * value_noise(canvas.w, canvas.h, cell, seed)
    warm = value_noise(canvas.w, canvas.h, cell * 1.6, seed + 1, 2) - 0.5
    canvas.variation = (bright.astype(np.float32), warm.astype(np.float32))


def lerp3(a, b, t):
    a = np.array(a, np.float32)[None, None, :] / 255.0
    b = np.array(b, np.float32)[None, None, :] / 255.0
    return a + (b - a) * np.clip(t, 0, 1)[..., None]


def seg_field(cx, cy, p0, p1):
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dy) or 1e-6
    t = ((cx - p0[0]) * dx + (cy - p0[1]) * dy) / (length * length)
    tc = np.clip(t, 0, 1)
    qx, qy = p0[0] + tc * dx, p0[1] + tc * dy
    d = np.hypot(cx - qx, cy - qy)
    s = ((cx - p0[0]) * dy - (cy - p0[1]) * dx) / length     # signé, à la droite
    return d, s, t * length, length, (-dy / length, dx / length)


def rope(canvas, pts, width, colors=(ROPE_LIGHT, ROPE_MID, ROPE_DARK), outline=1.0, outline_alpha=0.9,
         pitch=None, taper=None, phase=0.0, shade=None, width_at=None):
    """Corde torsadée le long d'une polyligne (coordonnées de la toile).
    width : épaisseur ; taper(t 0..1) -> facteur d'épaisseur ; pitch : pas de la torsade ;
    shade(cx, cy) -> facteur de lumière par pixel ; width_at(x, y) -> facteur d'épaisseur au point."""
    light, mid, dark = colors
    pitch = pitch or width * 1.7
    total = sum(math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(len(pts) - 1)) or 1
    # 1. contour d'encre (tous les segments), 2. corps
    for pass_ in ("outline", "body"):
        done = 0.0
        for i in range(len(pts) - 1):
            p0, p1 = pts[i], pts[i + 1]
            hw = width / 2
            if width_at:
                hw *= width_at((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
            if taper:
                hw *= taper((done + 0.5 * math.hypot(p1[0] - p0[0], p1[1] - p0[1])) / total)
            margin = hw + outline + 2
            sl = canvas.box(min(p0[0], p1[0]) - margin, min(p0[1], p1[1]) - margin,
                            max(p0[0], p1[0]) + margin, max(p0[1], p1[1]) + margin)
            if sl is None:
                continue
            cx, cy = canvas.x[sl], canvas.y[sl]
            d, s, along, length, n = seg_field(cx, cy, p0, p1)
            if pass_ == "outline":
                if outline > 0:
                    canvas.over(sl, INK, np.clip(hw + outline + 0.5 - d, 0, 1) * outline_alpha)
            else:
                cov = np.clip(hw + 0.5 - d, 0, 1)
                u = np.clip(s / max(hw, 1e-3), -1, 1)
                h = np.sqrt(np.clip(1 - u * u, 0, 1))
                lit = n[0] * LIGHT_DIR[0] + n[1] * LIGHT_DIR[1]
                b = 0.30 + 0.70 * h * (0.78 + 0.32 * lit * u)
                tw = 1 - 0.3 * (0.5 + 0.5 * np.sin(2 * math.pi * (along + done + phase) / pitch + 2.2 * u))
                b = b * tw
                if shade is not None:
                    b = b * shade(cx, cy)
                b = np.clip(b, 0, 1)
                variation = getattr(canvas, "variation", None)
                if variation is not None:
                    b = np.clip(b * variation[0][sl], 0, 1)
                rgb = np.where((b < 0.5)[..., None], lerp3(dark, mid, b * 2), lerp3(mid, light, (b - 0.5) * 2))
                if variation is not None:
                    warm = variation[1][sl][..., None]
                    rgb = np.clip(rgb * np.concatenate([1 + 0.10 * warm, 1 + 0.02 * warm, 1 - 0.14 * warm], axis=2), 0, 1)
                canvas.over(sl, rgb, cov)
            done += length


def glow(canvas, center, radius, color, alpha):
    """Tache douce (occlusion sous un nœud, lueur) : gaussienne."""
    sl = canvas.box(center[0] - radius * 2, center[1] - radius * 2, center[0] + radius * 2, center[1] + radius * 2)
    if sl is None:
        return
    d = np.hypot(canvas.x[sl] - center[0], canvas.y[sl] - center[1])
    canvas.over(sl, color, np.exp(-(d / radius) ** 2) * alpha)


def hairs(canvas, pts, rng, width, step=11.0, length=3.2, alpha=0.55):
    """Poils de chanvre le long d'une corde : brins fins qui dépassent."""
    acc = 0.0
    for i in range(len(pts) - 1):
        p0, p1 = pts[i], pts[i + 1]
        seglen = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        if seglen < 1e-6:
            continue
        ux, uy = (p1[0] - p0[0]) / seglen, (p1[1] - p0[1]) / seglen
        t = step - acc
        while t < seglen:
            x, y = p0[0] + ux * t, p0[1] + uy * t
            side = rng.choice((-1, 1))
            ang = math.atan2(uy, ux) + side * (math.pi / 2 - rng.uniform(-0.6, 0.6))
            n = rng.uniform(0.6, 1.4) * length
            end = (x + math.cos(ang) * n, y + math.sin(ang) * n)
            curl = rng.uniform(-0.5, 0.5)
            midp = ((x + end[0]) / 2 + curl * (end[1] - y) * 0.5, (y + end[1]) / 2 - curl * (end[0] - x) * 0.5)
            rope(canvas, [(x, y), midp, end], width * 0.22, outline=0.0, outline_alpha=0.0,
                 colors=(ROPE_LIGHT, ROPE_MID, ROPE_DARK), taper=lambda q: 1 - 0.6 * q)
            t += step * rng.uniform(0.6, 1.5)
        acc = (acc + seglen) % step


def sphere(canvas, center, radius, light=ROPE_LIGHT, mid=ROPE_MID, dark=ROPE_DARK, outline=1.0, outline_alpha=0.85):
    sl = canvas.box(center[0] - radius - outline - 2, center[1] - radius - outline - 2,
                    center[0] + radius + outline + 2, center[1] + radius + outline + 2)
    if sl is None:
        return
    cx, cy = canvas.x[sl], canvas.y[sl]
    dx, dy = cx - center[0], cy - center[1]
    d = np.hypot(dx, dy)
    if outline > 0:
        canvas.over(sl, INK, np.clip(radius + outline + 0.5 - d, 0, 1) * outline_alpha)
    cov = np.clip(radius + 0.5 - d, 0, 1)
    u = np.clip(d / radius, 0, 1)
    h = np.sqrt(np.clip(1 - u * u, 0, 1))
    lit = (dx * LIGHT_DIR[0] + dy * LIGHT_DIR[1]) / radius
    b = np.clip(0.25 + 0.75 * h * (0.7 + 0.45 * lit), 0, 1)
    rgb = np.where((b < 0.5)[..., None], lerp3(dark, mid, b * 2), lerp3(mid, light, (b - 0.5) * 2))
    canvas.over(sl, rgb, cov)


def shadow_under(image, offset=(2, 3), blur=2.5, alpha=0.55, color=(12, 8, 4)):
    """Ombre portée sous une image RGBA : même alpha floutée, décalée."""
    a = image.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
    shadow = Image.new("RGBA", image.size, color + (0,))
    shadow.putalpha(a.point(lambda v: int(v * alpha)))
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, offset)
    out.alpha_composite(image)
    return out


def downsample(image, factor):
    if factor == 1:
        return image
    # alpha prémultiplié avant le rééchantillonnage : pas de franges sombres
    arr = np.asarray(image).astype(np.float32) / 255.0
    rgb, a = arr[..., :3], arr[..., 3:4]
    pm = Image.fromarray((np.concatenate([rgb * a, a], 2) * 255 + 0.5).astype(np.uint8), "RGBA")
    small = pm.resize((image.width // factor, image.height // factor), Image.LANCZOS)
    arr = np.asarray(small).astype(np.float32) / 255.0
    a = arr[..., 3:4]
    rgb = np.clip(arr[..., :3] / np.maximum(a, 1e-4), 0, 1)
    return Image.fromarray((np.concatenate([rgb, a], 2) * 255 + 0.5).astype(np.uint8), "RGBA")


def write_tga(path, image):
    """TGA 32 bits non compressé, origine en bas à gauche, BGRA."""
    if image.mode != "RGBA":
        image = image.convert("RGBA")
    arr = np.asarray(image)
    bgra = arr[::-1, :, [2, 1, 0, 3]]      # lignes du bas vers le haut
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, image.width, image.height, 32, 8)
    with open(path, "wb") as handle:
        handle.write(header + bgra.tobytes())


# ---------------------------------------------------------------------------
# Le filet
# ---------------------------------------------------------------------------
NET_SIZE = 256


def net_boundary(theta, scale):
    return (116 + 3 * math.sin(3 * theta + 0.4) + 2 * math.sin(7 * theta)) * scale


def net_hole(theta, scale):
    return (40 + 9 * math.sin(2 * theta + 1.0) + 5 * math.sin(5 * theta + 2.0)) * scale


def inside_boundary(x, y, c, scale, margin=0):
    theta = math.atan2(y - c, x - c)
    return math.hypot(x - c, y - c) <= net_boundary(theta, scale) - margin


def inside_hole(x, y, c, scale, margin=0):
    theta = math.atan2(y - c, x - c)
    return math.hypot(x - c, y - c) <= net_hole(theta, scale) + margin


def clip_polyline(pts, keep):
    """Découpe une polyligne (points très rapprochés) en morceaux gardés."""
    pieces, current = [], []
    for p in pts:
        if keep(p):
            current.append(p)
        elif current:
            pieces.append(current)
            current = []
    if current:
        pieces.append(current)
    return [piece for piece in pieces if len(piece) >= 2]


def thin_polyline(pts, step):
    """Garde un point tous les `step` px (et le dernier)."""
    out, acc = [pts[0]], 0.0
    for i in range(1, len(pts)):
        acc += math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])
        if acc >= step:
            out.append(pts[i])
            acc = 0.0
    if out[-1] != pts[-1]:
        out.append(pts[-1])
    return out


def fray(canvas, end, direction, scale, rng, width, length=9):
    """Bout de corde effiloché : trois brins fins qui s'écartent et s'enroulent."""
    for k in range(3):
        angle = math.atan2(direction[1], direction[0]) + (k - 1) * 0.5 + rng.uniform(-0.25, 0.25)
        curl = rng.uniform(0.18, 0.34) * rng.choice((-1, 1))
        pts, x, y = [end], end[0], end[1]
        for step in range(7):
            x += math.cos(angle) * length * scale / 7
            y += math.sin(angle) * length * scale / 7
            angle += curl
            pts.append((x, y))
        rope(canvas, pts, width * 0.4, outline=0.6 * scale, outline_alpha=0.6, taper=lambda t: 1 - 0.75 * t)


DOME = 0.6            # part de bombé : 0 = plat, 1 = demi-sphère vue de dessus
DOME_LIGHT = (-0.42, -0.55, 0.72)


def net_boundary_np(theta, scale):
    return (116 + 3 * np.sin(3 * theta + 0.4) + 2 * np.sin(7 * theta)) * scale


def dome_map(x, y, c, scale, radius_fn=net_boundary, dome=DOME):
    """Le filet plat posé sur une calotte vue de face : les mailles du milieu
    paraissent plus proches (plus grandes), celles du bord se tassent."""
    dx, dy = x - c, y - c
    r = math.hypot(dx, dy)
    if r < 1e-6:
        return x, y
    theta = math.atan2(dy, dx)
    radius = radius_fn(theta, scale)
    rho = min(r / radius, 1.0)
    rho2 = (1 - dome) * rho + dome * math.sin(rho * math.pi / 2)
    return c + dx / r * rho2 * radius, c + dy / r * rho2 * radius


def dome_rho(x, y, c, scale, radius_fn=net_boundary):
    dx, dy = x - c, y - c
    r = math.hypot(dx, dy)
    return min(r / radius_fn(math.atan2(dy, dx), scale), 1.0) if r > 1e-6 else 0.0


def dome_shade(c, scale, radius_fn_np=net_boundary_np, strength=0.62):
    """Facteur de lumière par pixel : la calotte éclairée d'en haut à gauche,
    son bord bas-droit dans l'ombre."""
    lx, ly, lz = DOME_LIGHT

    def shade(cx, cy):
        dx, dy = cx - c, cy - c
        r = np.hypot(dx, dy)
        theta = np.arctan2(dy, dx)
        rho = np.clip(r / radius_fn_np(theta, scale), 0, 1)
        nz = np.sqrt(np.clip(1 - rho * rho, 0, 1))
        lit = np.clip(rho * np.cos(theta) * lx + rho * np.sin(theta) * ly + nz * lz, 0, 1)
        return (1 - strength * 0.68) + strength * lit
    return shade


def shade_at(shade, x, y):
    return float(shade(np.array([[x]], np.float32), np.array([[y]], np.float32))[0, 0])


def march_to_edge(p, direction, c, scale, inside, step):
    """Avance depuis p dans la direction jusqu'à sortir : le point du bord."""
    x, y = p
    for _ in range(200):
        nx_, ny_ = x + direction[0] * step, y + direction[1] * step
        if not inside((nx_, ny_)):
            return (nx_, ny_)
        x, y = nx_, ny_
    return (x, y)


def knot_net(canvas, c, scale, rng, gap, mesh_w, rim_w, radius_fn, radius_fn_np, dome, torn=False,
             jitter=3.2, seed=80, sag=1.2, hang=0.9, hairs_on=True, knots_on=True):
    """Un filet comme un réseau de nœuds : quadrillage en diagonale dérangé par
    un bruit lisse, cordes qui pendent entre les nœuds, projeté sur une calotte.
    Rend (chaînes dessinées, nœuds)."""
    N = int(math.ceil(radius_fn(0, scale) * 1.5 / gap)) + 1
    n = 2 * N + 1
    noise_x = value_noise(n, n, 5, seed, 2) - 0.5
    noise_y = value_noise(n, n, 5, seed + 1, 2) - 0.5
    ax, bx = (1 / math.sqrt(2), 1 / math.sqrt(2)), (1 / math.sqrt(2), -1 / math.sqrt(2))
    flat = {}
    for i in range(-N, N + 1):
        for j in range(-N, N + 1):
            x = c + (i * ax[0] + j * bx[0]) * gap + noise_x[j + N, i + N] * 2 * jitter * scale
            y = c + (i * ax[1] + j * bx[1]) * gap + noise_y[j + N, i + N] * 2 * jitter * scale
            flat[(i, j)] = (x, y)

    def in_rim(p, margin=3 * scale):
        theta = math.atan2(p[1] - c, p[0] - c)
        return math.hypot(p[0] - c, p[1] - c) <= radius_fn(theta, scale) - margin

    def in_hole(p):
        return torn and inside_hole(p[0], p[1], c, scale)

    def inside(p):
        return in_rim(p) and not in_hole(p)

    shade = dome_shade(c, scale, radius_fn_np, strength=0.62 if dome < 0.9 else 0.8)

    def width_at(x, y):
        rho = dome_rho(x, y, c, scale, radius_fn)
        return 0.78 + 0.42 * (1 - rho * rho)

    def mapped(p):
        return dome_map(p[0], p[1], c, scale, radius_fn, dome)

    # les chaînes de nœuds, le long des deux diagonales
    chains = []
    for fixed in ("i", "j"):
        for k in range(-N, N + 1):
            run = []
            for m in range(-N, N + 1):
                key = (k, m) if fixed == "i" else (m, k)
                if inside(flat[key]):
                    run.append(key)
                else:
                    if len(run) >= 2:
                        chains.append((fixed, run))
                    run = []
            if len(run) >= 2:
                chains.append((fixed, run))
    # trois cordes coupées ailleurs que dans le trou
    pieces = []
    cut_ids = set()
    if torn:
        long_chains = [idx for idx, (_, run) in enumerate(chains) if len(run) >= 6]
        cut_ids = set(rng.sample(long_chains, min(3, len(long_chains))))
    for idx, (fixed, run) in enumerate(chains):
        if idx in cut_ids:
            mid = len(run) // 2
            pieces.append((fixed, run[:mid], "end", "cut"))
            pieces.append((fixed, run[mid:], "cut", "end"))
        else:
            pieces.append((fixed, run, "end", "end"))

    def neighbour(key, fixed, side):
        k, m = (key[0], key[1]) if fixed == "i" else (key[1], key[0])
        m2 = m + side
        return (k, m2) if fixed == "i" else (m2, k)

    drawn = []
    for fixed, run, head, tail in pieces:
        pts_flat = [flat[key] for key in run]
        ends = []
        for side, kind, key_end, key_prev in ((-1, head, run[0], run[1]), (1, tail, run[-1], run[-2])):
            p_end, p_prev = flat[key_end], flat[key_prev]
            d = (p_end[0] - p_prev[0], p_end[1] - p_prev[1])
            length = math.hypot(*d) or 1
            d = (d[0] / length, d[1] / length)
            beyond = neighbour(key_end, fixed, side)
            if kind == "cut":
                ext = (p_end[0] + d[0] * gap * 0.3, p_end[1] + d[1] * gap * 0.3)
                ends.append((ext, "fray"))
            elif beyond in flat and in_hole(flat[beyond]):
                ext = (p_end[0] + d[0] * gap * 0.45, p_end[1] + d[1] * gap * 0.45)
                ends.append((ext, "fray"))
            else:
                ext = march_to_edge(p_end, d, c, scale, lambda q: in_rim(q, margin=1.2 * scale), max(1, scale * 0.5))
                ends.append((ext, "rim"))
        chain = [ends[0][0]] + pts_flat + [ends[1][0]]
        chain = [mapped(p) for p in chain]
        # cordes qui pendent entre les nœuds : un point au milieu de chaque
        # segment, décalé un peu de côté et vers le bas
        poly = [chain[0]]
        for a, b in zip(chain, chain[1:]):
            mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            nx_, ny_ = -(b[1] - a[1]), b[0] - a[0]
            length = math.hypot(nx_, ny_) or 1
            w = rng.uniform(-sag, sag) * scale
            poly.append((mx + nx_ / length * w, my + ny_ / length * w + hang * scale))
            poly.append(b)
        rope(canvas, poly, mesh_w, outline=0.9 * scale, phase=rng.uniform(0, 20), shade=shade, width_at=width_at)
        drawn.append(poly)
        for (ext, kind), key_end, key_prev in ((ends[0], run[0], run[1]), (ends[1], run[-1], run[-2])):
            if kind == "fray":
                a, b = mapped(ext), mapped(flat[key_end])
                fray(canvas, a, (a[0] - b[0], a[1] - b[1]), scale, rng, mesh_w, length=7)
    if hairs_on:
        for poly in drawn:
            hairs(canvas, poly, rng, mesh_w, step=12 * scale, length=3.4 * scale)
    knots = [mapped(p) for key, p in flat.items() if inside(p)]
    if knots_on:
        for knot in knots:
            glow(canvas, knot, 4.5 * scale, INK, 0.38)
        for knot in knots:
            k = width_at(knot[0], knot[1]) * rng.uniform(0.85, 1.2)
            f = shade_at(shade, knot[0], knot[1])
            sphere(canvas, knot, 2.5 * scale * k, outline=0.8 * scale,
                   light=tuple(int(min(255, v * f)) for v in ROPE_LIGHT), mid=tuple(int(min(255, v * f)) for v in ROPE_MID),
                   dark=tuple(int(min(255, v * f)) for v in ROPE_DARK))
    return shade


def paint_net(scale, torn, rng):
    """Une image du filet (256*scale carrée), déchirée ou non."""
    size = NET_SIZE * scale
    c = size / 2
    canvas = Canvas(size, size)
    material(canvas, seed=21 if torn else 20, cell=34 * scale)
    gap, mesh_w, rim_w = 25 * scale, 2.9 * scale, 7.0 * scale
    shade = knot_net(canvas, c, scale, rng, gap, mesh_w, rim_w, net_boundary, net_boundary_np, DOME, torn=torn)
    # corde du bord (la plus épaisse), coupée d'un côté si déchiré
    rim = []
    steps = 180
    for i in range(steps + 1):
        theta = 2 * math.pi * i / steps
        r = net_boundary(theta, scale)
        rim.append((c + r * math.cos(theta), c + r * math.sin(theta)))
    if torn:
        gap_at = 5.3    # radians : en haut à droite
        half = 0.12
        rim_pieces = clip_polyline(rim, lambda p: abs(((math.atan2(p[1] - c, p[0] - c) - gap_at + math.pi) % (2 * math.pi)) - math.pi) > half)
        # la polyligne est fermée : recoller le dernier morceau au premier
        if len(rim_pieces) >= 2 and rim_pieces[0][0] == rim[0]:
            rim_pieces = [rim_pieces[-1] + rim_pieces[0]] + rim_pieces[1:-1]
        for piece in rim_pieces:
            thin = thin_polyline(piece, 6 * scale)
            rope(canvas, thin, rim_w, outline=1.1 * scale, pitch=rim_w * 1.4, shade=shade)
            hairs(canvas, thin, rng, rim_w, step=10 * scale, length=3.5 * scale, alpha=0.5)
            for end, prev in ((piece[0], piece[1]), (piece[-1], piece[-2])):
                fray(canvas, end, (end[0] - prev[0], end[1] - prev[1]), scale, rng, rim_w, length=12)
    else:
        thin = thin_polyline(rim, 6 * scale)
        rope(canvas, thin, rim_w, outline=1.1 * scale, pitch=rim_w * 1.4, shade=shade)
        hairs(canvas, thin, rng, rim_w, step=10 * scale, length=3.5 * scale, alpha=0.5)
    # lest : des billes de plomb suspendues au bord par un bout de corde
    for i in range(12):
        theta = 2 * math.pi * i / 12 + 0.26 + rng.uniform(-0.08, 0.08)
        if torn and abs(((theta - 5.3 + math.pi) % (2 * math.pi)) - math.pi) < 0.2:
            continue
        r = net_boundary(theta, scale)
        on_rim = (c + r * math.cos(theta), c + r * math.sin(theta))
        # le bout pend un peu vers le bas (gravité)
        dx, dy = math.cos(theta), math.sin(theta) + 0.55
        length = math.hypot(dx, dy)
        dx, dy = dx / length, dy / length
        stub = (on_rim[0] + dx * 6.5 * scale, on_rim[1] + dy * 6.5 * scale)
        rope(canvas, [on_rim, ((on_rim[0] + stub[0]) / 2, (on_rim[1] + stub[1]) / 2 + 0.6 * scale), stub], 2.4 * scale, outline=0.9 * scale)
        f = 0.75 + 0.35 * max(0.0, -math.cos(theta) * 0.6 - math.sin(theta) * 0.8)
        sphere(canvas, (stub[0] + dx * 3.2 * scale, stub[1] + dy * 3.2 * scale), 4.4 * scale * rng.uniform(0.9, 1.1),
               light=tuple(int(v * f) for v in LEAD_LIGHT), mid=tuple(int(v * f) for v in (96, 96, 104)),
               dark=tuple(int(v * f) for v in LEAD_DARK), outline=1.0 * scale)
    return canvas.image(fill=ROPE_MID)


def paint_filet(scale=2):
    rng = random.Random(7)
    whole = paint_net(scale, False, rng)
    rng = random.Random(7)
    torn = paint_net(scale, True, rng)
    sheet = Image.new("RGBA", (NET_SIZE * 2 * scale, NET_SIZE * scale), ROPE_MID + (0,))
    # le fond derrière le filet : la pénombre sous les mailles (le filet retient la lumière)
    sheet.alpha_composite(shadow_under(whole, offset=(3 * scale, 5 * scale), blur=3.2 * scale, alpha=0.6), (0, 0))
    sheet.alpha_composite(shadow_under(torn, offset=(3 * scale, 5 * scale), blur=3.2 * scale, alpha=0.6), (NET_SIZE * scale, 0))
    return downsample(sheet, scale)


# ---------------------------------------------------------------------------
# Le paquet (filet roulé) et la corde
# ---------------------------------------------------------------------------
def paint_paquet(scale=4):
    """Le filet roulé en boule : mailles projetées sur une sphère, bouts de
    corde du bord qui dépassent, lest qui pend."""
    size = 64 * scale
    c = size / 2
    rng = random.Random(3)
    canvas = Canvas(size, size)
    material(canvas, seed=30, cell=18 * scale)
    ball = 21.0

    def radius_fn(theta, sc):
        return (ball + 1.2 * math.sin(3 * theta + 0.7) + 0.8 * math.sin(5 * theta)) * sc

    def radius_fn_np(theta, sc):
        return (ball + 1.2 * np.sin(3 * theta + 0.7) + 0.8 * np.sin(5 * theta)) * sc

    knot_net(canvas, c, scale, rng, 9.5 * scale, 2.6 * scale, 4 * scale, radius_fn, radius_fn_np, 1.0,
             jitter=1.6, seed=90, sag=0.7, hang=0.5)
    # la sphère : son contour d'ombre, et des bouts de la corde du bord qui dépassent
    shade = dome_shade(c, scale, radius_fn_np, strength=0.8)
    for start_a, span in ((0.4, 1.3), (2.5, 1.0), (4.3, 1.5)):
        pts = []
        for k in range(16):
            theta = start_a + span * k / 15
            r = radius_fn(theta, scale) * (1.0 + 0.1 * math.sin(k / 15 * math.pi))
            pts.append((c + r * math.cos(theta), c + r * math.sin(theta)))
        rope(canvas, pts, 4.2 * scale, outline=1.0 * scale, pitch=6 * scale, shade=shade, phase=rng.uniform(0, 10))
        hairs(canvas, pts, rng, 4.2 * scale, step=8 * scale, length=3 * scale)
    # lest qui pend sous la boule
    for ang, drop in ((math.pi / 2 - 0.35, 7), (math.pi / 2 + 0.3, 9)):
        r = radius_fn(ang, scale)
        on_rim = (c + r * math.cos(ang), c + r * math.sin(ang))
        stub = (on_rim[0] + math.cos(ang) * drop * scale * 0.4, on_rim[1] + drop * scale)
        rope(canvas, [on_rim, stub], 2.2 * scale, outline=0.9 * scale)
        sphere(canvas, (stub[0], stub[1] + 2.6 * scale), 2.9 * scale, light=LEAD_LIGHT, mid=(96, 96, 104), dark=LEAD_DARK, outline=1.0 * scale)
    image = shadow_under(canvas.image(fill=ROPE_MID), offset=(1 * scale, 2 * scale), blur=1.5 * scale, alpha=0.5)
    return downsample(image, scale)


def paint_corde(scale=4):
    w, h = 128 * scale, 16 * scale
    rng = random.Random(11)
    canvas = Canvas(w, h)
    material(canvas, seed=40, cell=20 * scale)
    pts = []
    for i in range(0, 41):
        t = i / 40
        x = (10 + 108 * t) * scale
        y = (8 + 1.8 * math.sin(math.pi * t)) * scale
        pts.append((x, y))
    rope(canvas, pts, 5.2 * scale, outline=1.0 * scale)
    hairs(canvas, pts, rng, 5.2 * scale, step=8 * scale, length=3.2 * scale)
    fray(canvas, pts[0], (-1, 0), scale, rng, 5.2 * scale, length=8)
    fray(canvas, pts[-1], (1, 0), scale, rng, 5.2 * scale, length=8)
    return downsample(canvas.image(fill=ROPE_MID), scale)


# ---------------------------------------------------------------------------
# Lumières : halo, rayons, particules (blancs, alpha)
# ---------------------------------------------------------------------------
def white_alpha(alpha):
    alpha = np.clip(alpha, 0, 1)
    out = np.zeros(alpha.shape + (4,), np.uint8)
    out[..., :3] = 255
    out[..., 3] = (alpha * 255 + 0.5).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def grid(size):
    ys, xs = np.mgrid[0:size, 0:size]
    x = (xs + 0.5) / size * 2 - 1
    y = (ys + 0.5) / size * 2 - 1
    return x.astype(np.float32), y.astype(np.float32)


def paint_halo(size=128):
    x, y = grid(size)
    r = np.hypot(x, y)
    turb = 0.82 + 0.36 * value_noise(size, size, 28, 50, 3)
    a = (0.55 * np.exp(-(r / 0.28) ** 2) + 0.62 * np.clip(1 - r, 0, 1) ** 2.4) * turb
    return white_alpha(a)


def paint_rayons(size=256):
    rng = random.Random(5)
    x, y = grid(size)
    r = np.hypot(x, y)
    theta = np.arctan2(y, x)
    a = np.zeros_like(r)
    rays = []
    for i in range(14):
        rays.append((2 * math.pi * i / 14 + rng.uniform(-0.1, 0.1), rng.uniform(0.045, 0.09), rng.uniform(0.7, 1.0), rng.uniform(0.72, 1.0)))
    for i in range(14):
        rays.append((2 * math.pi * (i + 0.5) / 14 + rng.uniform(-0.12, 0.12), rng.uniform(0.02, 0.04), rng.uniform(0.3, 0.55), rng.uniform(0.55, 0.85)))
    streaks = value_noise(size, size, 6, 51, 2)        # stries le long des rayons
    for angle, sigma, amp, length in rays:
        curve = rng.uniform(-0.12, 0.12)
        d = np.angle(np.exp(1j * (theta - angle - curve * r)))
        # plus étroit loin du centre, longueur qui varie
        width = sigma * (0.35 + 0.65 * np.clip(1 - r / length, 0, 1))
        lobe = np.exp(-(d / np.maximum(width, 1e-3)) ** 2)
        fade = np.clip((length - r) / 0.25, 0, 1) * np.clip((r - 0.04) / 0.14, 0, 1)
        a += amp * lobe * fade * np.clip(1 - r, 0, 1) ** 0.5 * (0.7 + 0.5 * streaks)
    # trois larges lobes faibles qui cassent la symétrie
    for angle, amp in ((0.9, 0.16), (2.8, 0.12), (4.9, 0.14)):
        d = np.angle(np.exp(1j * (theta - angle)))
        a += amp * np.exp(-(d / 0.45) ** 2) * np.clip(1 - r / 0.9, 0, 1) ** 1.4
    # éclats près du cœur
    for _ in range(9):
        ang, dist = rng.uniform(0, 2 * math.pi), rng.uniform(0.12, 0.42)
        fx, fy = dist * math.cos(ang), dist * math.sin(ang)
        a += rng.uniform(0.25, 0.6) * np.exp(-(np.hypot(x - fx, y - fy) / rng.uniform(0.018, 0.035)) ** 2)
    a += 0.5 * np.exp(-(r / 0.16) ** 2)
    return white_alpha(np.clip(a, 0, 1))


def spike(x, y, length, width, power=1.6):
    """Une pointe le long de l'axe x (symétrique), x et y en pixels."""
    along = np.abs(x)
    across = np.abs(y)
    core = np.clip(1 - along / length, 0, 1) ** power
    w = width * (0.15 + 0.85 * core)
    return core * np.exp(-(across / np.maximum(w, 1e-3)) ** 2)


def paint_particules():
    sheet = Image.new("RGBA", (128, 32), (255, 255, 255, 0))
    x, y = grid(32)
    px, py = x * 16, y * 16
    r = np.hypot(px, py)
    # 0. point doux
    sheet.alpha_composite(white_alpha(np.exp(-(r / 5.5) ** 2) + 0.25 * np.exp(-(r / 10) ** 2)), (0, 0))
    # 1. étoile à quatre branches
    a = np.maximum(spike(px, py, 14, 2.6), spike(py, px, 14, 2.6)) + 0.7 * np.exp(-(r / 3.2) ** 2)
    sheet.alpha_composite(white_alpha(a), (32, 0))
    # 2. étincelle à six branches (plus un éclat diagonal court)
    a = np.zeros_like(r)
    for k in range(3):
        ang = k * math.pi / 3
        rx = px * math.cos(ang) + py * math.sin(ang)
        ry = -px * math.sin(ang) + py * math.cos(ang)
        a = np.maximum(a, spike(rx, ry, 13, 1.8))
    a = np.maximum(a, 0.8 * np.exp(-(r / 3.5) ** 2))
    sheet.alpha_composite(white_alpha(a), (64, 0))
    # 3. anneau de poussière
    a = 0.9 * np.exp(-((r - 10.5) / 2.4) ** 2) + 0.15 * np.exp(-(r / 8) ** 2)
    sheet.alpha_composite(white_alpha(a), (96, 0))
    return sheet


# ---------------------------------------------------------------------------
# Étoiles du spécimen (pleine, vide)
# ---------------------------------------------------------------------------
def star_points(cx, cy, outer, inner, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(2 * n):
        r = outer if i % 2 == 0 else inner
        a = rot + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def paint_etoiles(scale=4):
    size = 64 * scale
    sheet = Image.new("RGBA", (2 * size, size), (255, 255, 255, 0))
    c = size / 2
    outer, inner = 28 * scale, 12 * scale
    # pleine : fond ombré, cœur en dégradé, arête claire en haut à gauche
    full = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    d = ImageDraw.Draw(full)
    d.polygon(star_points(c, c + 1 * scale, outer, inner), fill=(255, 255, 255, 255))
    mask = full.getchannel("A")
    # dégradé vertical : clair en haut, plus sombre en bas
    ys = np.linspace(0, 1, size, dtype=np.float32)[:, None]
    shade = (235 - 95 * ys) * np.ones((1, size), np.float32)
    body = np.zeros((size, size, 4), np.uint8)
    body[..., 0] = body[..., 1] = body[..., 2] = shade.astype(np.uint8)
    body[..., 3] = np.asarray(mask)
    full = Image.fromarray(body, "RGBA")
    # facettes : dix triangles du centre aux pointes, clairs face à la lumière
    facets = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    df = ImageDraw.Draw(facets)
    pts = star_points(c, c + 1 * scale, outer, inner)
    light_angle = math.atan2(-0.83, -0.55)
    for i in range(10):
        p1, p2 = pts[i], pts[(i + 1) % 10]
        mx, my = (p1[0] + p2[0]) / 2 - c, (p1[1] + p2[1]) / 2 - c - 1 * scale
        ang = math.atan2(my, mx)
        lit = 0.5 + 0.5 * math.cos(ang - light_angle)
        v = int(150 + 95 * lit + (18 if i % 2 == 0 else -18))
        df.polygon([(c, c + 1 * scale), p1, p2], fill=(v, v, v, 255))
    facets.putalpha(Image.fromarray(np.minimum(np.asarray(facets.getchannel("A")), np.asarray(mask))))
    full.alpha_composite(facets)
    # arête claire en haut à gauche, sombre en bas à droite
    bevel = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    db = ImageDraw.Draw(bevel)
    db.polygon(star_points(c + 1.5 * scale, c + 2.5 * scale, outer * 0.86, inner * 0.86), fill=(90, 90, 90, 90))
    db.polygon(star_points(c - 1.2 * scale, c - 0.3 * scale, outer * 0.86, inner * 0.86), fill=(255, 255, 255, 110))
    bevel.putalpha(Image.fromarray(np.minimum(np.asarray(bevel.getchannel("A")), np.asarray(mask))))
    full.alpha_composite(bevel)
    # reflet
    d = ImageDraw.Draw(full)
    d.ellipse([c - 8 * scale, c - 13 * scale, c - 3 * scale, c - 8 * scale], fill=(255, 255, 255, 170))
    # contour d'encre
    outline = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    ImageDraw.Draw(outline).polygon(star_points(c, c + 1 * scale, outer + 1.2 * scale, inner + 1.0 * scale), fill=(40, 30, 16, 220))
    layered = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    # lueur douce autour (teintée or en jeu : l'étoile éclaire)
    gx, gy = grid(size)
    layered.alpha_composite(white_alpha(0.35 * np.exp(-(np.hypot(gx, gy) / 0.62) ** 2)))
    layered.alpha_composite(outline)
    layered.alpha_composite(full)
    sheet.alpha_composite(shadow_under(layered, offset=(1 * scale, 2 * scale), blur=1.5 * scale, alpha=0.45), (0, 0))
    # vide : contour seul, trait blanc, fond très léger
    hollow = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    dh = ImageDraw.Draw(hollow)
    dh.polygon(star_points(c, c + 1 * scale, outer, inner), fill=(255, 255, 255, 38))
    pts = star_points(c, c + 1 * scale, outer - 1.5 * scale, inner - 0.5 * scale)
    dh.line(pts + [pts[0]], fill=(255, 255, 255, 255), width=int(2.6 * scale), joint="curve")
    sheet.alpha_composite(hollow, (size, 0))
    return downsample(sheet, scale)


# ---------------------------------------------------------------------------
# Le ruban de la bannière : panneau (teinté sombre) et liseré (teinté rareté)
# ---------------------------------------------------------------------------
def paint_ruban(scale=4):
    w, h = 256 * scale, 64 * scale
    sheet = Image.new("RGBA", (w, 2 * h), (255, 255, 255, 0))
    s = scale
    # géométrie (en px de la version 256x64)
    px0, px1, py0, py1 = 38, 218, 13, 49          # panneau
    tail_y0, tail_y1 = 20, 58                     # queues, plus bas
    notch = 13

    def P(x, y):
        return (x * s, y * s)

    panel = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    d = ImageDraw.Draw(panel)
    # queues, derrière (plus sombres)
    left_tail = [P(4, tail_y0), P(px0 + 8, tail_y0 - 2), P(px0 + 8, tail_y1 + 2), P(4, tail_y1), P(4 + notch, (tail_y0 + tail_y1) / 2)]
    right_tail = [P(252, tail_y0), P(px1 - 8, tail_y0 - 2), P(px1 - 8, tail_y1 + 2), P(252, tail_y1), P(252 - notch, (tail_y0 + tail_y1) / 2)]
    for tail in (left_tail, right_tail):
        d.polygon(tail, fill=(168, 168, 168, 255))
    # le tissu des queues : plus sombre vers le panneau, pli clair en haut
    tails = np.asarray(panel).astype(np.float32)
    xs_t = np.abs(np.linspace(-1, 1, w, dtype=np.float32))[None, :]
    ys_t = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    tone = -26 * np.clip((xs_t - 0.55) / 0.2, 0, 1) * np.clip((0.75 - xs_t) / 0.2, 0, 1) + 10 * np.exp(-((ys_t - 0.33) / 0.05) ** 2)
    for ch in range(3):
        tails[..., ch] = np.clip(tails[..., ch] + tone * (tails[..., 3] > 0), 0, 255)
    panel = Image.fromarray(tails.astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(panel)
    # pli : triangle sombre entre la queue et le panneau
    d.polygon([P(px0, py1), P(px0 + 8, py1), P(px0 + 8, tail_y1 + 2)], fill=(88, 88, 88, 255))
    d.polygon([P(px1, py1), P(px1 - 8, py1), P(px1 - 8, tail_y1 + 2)], fill=(88, 88, 88, 255))
    d.polygon([P(px0, py0), P(px0 + 8, py0), P(px0 + 8, tail_y0 - 2)], fill=(120, 120, 120, 255))
    d.polygon([P(px1, py0), P(px1 - 8, py0), P(px1 - 8, tail_y0 - 2)], fill=(120, 120, 120, 255))
    # panneau : dégradé vertical, bords un peu bombés, plis du tissu qui pend
    ys = np.linspace(0, 1, (py1 - py0) * s, dtype=np.float32)[:, None]
    xs = np.linspace(-1, 1, (px1 - px0) * s, dtype=np.float32)[None, :]
    folds = 9 * np.sin(xs * 9.5 + 0.8) * (0.4 + 0.6 * ys) + 5 * np.sin(xs * 23 + 2.0) * ys
    weave = 3 * value_noise((px1 - px0) * s, (py1 - py0) * s, 3, 60, 1) - 1.5
    shade = 236 - 42 * ys - 16 * (xs ** 6) + folds + weave * 2
    # ourlet : un filet clair sous le bord haut, sombre au-dessus du bord bas
    shade += 12 * np.exp(-((ys - 0.06) / 0.035) ** 2) - 14 * np.exp(-((ys - 0.94) / 0.04) ** 2)
    body = np.zeros(((py1 - py0) * s, (px1 - px0) * s, 4), np.uint8)
    body[..., 0] = body[..., 1] = body[..., 2] = np.clip(shade, 0, 255).astype(np.uint8)
    body[..., 3] = 255
    body_img = Image.fromarray(body, "RGBA")
    # masque du panneau : bords haut et bas légèrement incurvés
    mask = Image.new("L", body_img.size, 0)
    md = ImageDraw.Draw(mask)
    bw, bh = body_img.size
    wave = random.Random(61)
    pts = [(0, 0)]
    for i in range(0, bw + 1, s):
        u = i / bw
        pts.append((i, 2.4 * s * math.sin(math.pi * u) + 0.5 * s * math.sin(u * 40) ))
    pts.append((bw, 0))
    pts.append((bw, bh))
    for i in range(bw, -1, -s):
        u = i / bw
        pts.append((i, bh - 2.4 * s * math.sin(math.pi * u) - 0.5 * s * math.sin(u * 37 + 1)))
    pts.append((0, bh))
    md.polygon(pts, fill=255)
    body_img.putalpha(mask)
    panel.alpha_composite(body_img, P(px0, py0))
    # grain de tissu discret
    rng = np.random.default_rng(9)
    grain = rng.normal(0, 5.0, (h, w)).astype(np.float32)
    arr = np.asarray(panel).astype(np.float32)
    for ch in range(3):
        arr[..., ch] = np.clip(arr[..., ch] + grain * (arr[..., 3] > 0), 0, 255)
    panel = Image.fromarray(arr.astype(np.uint8), "RGBA")
    # contour d'encre autour de tout
    outline = panel.getchannel("A").filter(ImageFilter.MaxFilter(int(2 * s) * 2 + 1))
    ink = Image.new("RGBA", (w, h), (30, 24, 16, 0))
    ink.putalpha(outline.point(lambda v: int(v * 0.85)))
    layered = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    layered.alpha_composite(ink)
    layered.alpha_composite(panel)
    layered = shadow_under(layered, offset=(0, 3 * s), blur=3 * s, alpha=0.5)
    sheet.alpha_composite(layered, (0, 0))
    # liseré : deux filets dans le panneau, un losange à chaque bout, l'arête des queues
    trim = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    t = ImageDraw.Draw(trim)
    inset = 4
    # filets brodés : pointillés serrés
    for yy in (py0 + inset, py1 - inset):
        xx = px0 + 10
        while xx < px1 - 10:
            t.line([P(xx, yy), P(min(xx + 2.6, px1 - 10), yy)], fill=(255, 255, 255, 255), width=int(1.7 * s))
            xx += 3.8
    for xx in (px0 + 10, px1 - 10):
        cy = (py0 + py1) / 2
        t.polygon([P(xx, cy - 4), P(xx + 3, cy), P(xx, cy + 4), P(xx - 3, cy)], fill=(255, 255, 255, 255))
    for xx in (px0 + 10, px1 - 10):
        t.line([P(xx, py0 + inset), P(xx, (py0 + py1) / 2 - 6)], fill=(255, 255, 255, 255), width=int(1.6 * s))
        t.line([P(xx, (py0 + py1) / 2 + 6), P(xx, py1 - inset)], fill=(255, 255, 255, 255), width=int(1.6 * s))
    for x0_, x1_ in ((6, px0 + 2), (250, px1 - 2)):
        step_ = 3.6 if x1_ > x0_ else -3.6
        xx = x0_
        while (xx < x1_) == (step_ > 0):
            t.line([P(xx, tail_y0 + 3), P(xx + step_ * 0.65, tail_y0 + 3)], fill=(255, 255, 255, 150), width=int(1.3 * s))
            xx += step_
    sheet.alpha_composite(trim, (0, h))
    return downsample(sheet, scale)


# ---------------------------------------------------------------------------
# Fond de scène : vignettage et sol
# ---------------------------------------------------------------------------
def paint_vignette(size=128):
    """Fond de scène : un projecteur froid derrière la créature (fondu jusqu'au
    bord : pas de boîte), un sol clair et l'ombre de la créature dessus."""
    x, y = grid(size)
    r = np.hypot(x, y * 1.1)
    spot = np.clip(1 - r / 0.98, 0, 1) ** 1.5 * 0.42
    ex, ey = x / 0.74, (y - 0.5) / 0.24
    ground = np.clip(1 - np.hypot(ex, ey), 0, 1) ** 1.1 * 0.5
    ring = np.exp(-((np.hypot(ex, ey) - 0.92) / 0.08) ** 2) * 0.22 * np.clip(1 - (abs(x) / 0.78) ** 6, 0, 1)
    shadow = np.exp(-(np.hypot(x / 0.36, (y - 0.47) / 0.11)) ** 2) * 0.75
    slate = np.array([54, 66, 80], np.float32)[None, None, :] / 255
    pale = np.array([96, 108, 122], np.float32)[None, None, :] / 255
    ink = np.array([8, 10, 13], np.float32)[None, None, :] / 255
    # matière : sol moucheté, rai de lumière venu d'en haut à gauche
    mottle = 0.8 + 0.4 * value_noise(size, size, 14, 70, 3)
    beam = 0.16 * np.exp(-(((x + 0.15) * 0.8 + (y + 0.1) * 0.6) / 0.28) ** 2) * np.clip(1 - r / 1.05, 0, 1)
    spot = spot * (0.85 + 0.3 * value_noise(size, size, 40, 71, 2)) + beam
    ground = ground * mottle
    # lumière (projecteur + sol + liseré du sol) puis l'ombre par-dessus
    light_a = np.clip(spot + ground + ring, 0, 1)
    rgb = slate * (1 - ring[..., None] * 3).clip(0, 1) + pale * (ring[..., None] * 3).clip(0, 1)
    a = light_a * (1 - shadow) + shadow
    rgb = (rgb * (light_a * (1 - shadow))[..., None] + ink * shadow[..., None]) / np.maximum(a, 1e-4)[..., None]
    out = np.concatenate([np.clip(rgb, 0, 1), np.clip(a, 0, 1)[..., None]], 2)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------------------
# Glyphe du bouton filet (blanc)
# ---------------------------------------------------------------------------
def paint_filet_icone(scale=8):
    size = 32 * scale
    c = size / 2
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    r = 13 * scale
    d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 255, 255, 255), width=int(2.4 * scale))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([c - r + 1.5 * scale, c - r + 1.5 * scale, c + r - 1.5 * scale, c + r - 1.5 * scale], fill=255)
    mesh = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    md = ImageDraw.Draw(mesh)
    gap = 7.5 * scale
    for direction in (1, -1):
        k = -4
        while k <= 4:
            off = k * gap * math.sqrt(2)
            md.line([(0, c + off * direction - direction * c), (size, c + off * direction + direction * c)]
                    if direction == 1 else [(0, c + off + c), (size, c + off - c)],
                    fill=(255, 255, 255, 255), width=int(1.7 * scale))
            k += 1
    mesh.putalpha(Image.fromarray(np.minimum(np.asarray(mesh.getchannel("A")), np.asarray(mask))))
    img.alpha_composite(mesh)
    # trois billes de lest en bas
    for ang in (math.pi / 2 - 0.5, math.pi / 2, math.pi / 2 + 0.5):
        x, y = c + r * math.cos(ang), c + r * math.sin(ang)
        d.ellipse([x - 2.4 * scale, y - 2.4 * scale, x + 2.4 * scale, y + 2.4 * scale], fill=(255, 255, 255, 255))
    return downsample(img, scale)


# ---------------------------------------------------------------------------
# Tout peindre
# ---------------------------------------------------------------------------
def paint_all():
    return {
        "filet": paint_filet(),
        "paquet": paint_paquet(),
        "corde": paint_corde(),
        "halo": paint_halo(),
        "rayons": paint_rayons(),
        "particules": paint_particules(),
        "etoiles": paint_etoiles(),
        "ruban": paint_ruban(),
        "vignette": paint_vignette(),
        "filet_icone": paint_filet_icone(),
    }


# ---------------------------------------------------------------------------
# Aperçus (PNG, jamais versionnés) : planche des assets et maquettes
# ---------------------------------------------------------------------------
WINDOW = (19, 23, 27)
EDGE = (58, 66, 74)
GOLD = (232, 165, 75)
GOLD_LIGHT = (246, 199, 125)
PARCHMENT = (241, 232, 212)
MUTED_LIGHT = (163, 168, 173)
RED = (226, 96, 79)
RARE = (163, 54, 237)
ELITE = (0, 112, 222)


def font(name, size):
    path = os.path.join(MEDIA, "Inter-%s.ttf" % name)
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def tint_image(img, tint=None, alpha=1.0):
    arr = np.asarray(img).astype(np.float32)
    if tint is not None:
        for ch in range(3):
            arr[..., ch] *= tint[ch] / 255.0
    arr[..., 3] *= alpha
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def blit(canvas, img, cx, cy, size=None, rot=0.0, tint=None, alpha=1.0, add=False, crop=None):
    """Pose un sprite centré en (cx, cy) ; crop = (l, t, r, b) en fraction (SetTexCoord)."""
    if crop:
        l, t, r, b = crop
        img = img.crop((int(l * img.width), int(t * img.height), int(r * img.width), int(b * img.height)))
    if size:
        img = img.resize((max(1, int(round(size[0]))), max(1, int(round(size[1])))), Image.LANCZOS)
    img = tint_image(img, tint, alpha)
    if rot:
        img = img.rotate(rot, resample=Image.BICUBIC, expand=True)
    x0, y0 = int(round(cx - img.width / 2)), int(round(cy - img.height / 2))
    if not add:
        canvas.alpha_composite(img, (x0, y0))
        return
    # fusion additive (SetBlendMode("ADD")) : couleur * alpha ajoutée
    region = canvas.crop((x0, y0, x0 + img.width, y0 + img.height))
    src = np.asarray(img).astype(np.float32)
    dst = np.asarray(region).astype(np.float32)
    a = src[..., 3:4] / 255.0
    dst[..., :3] = np.clip(dst[..., :3] + src[..., :3] * a, 0, 255)
    canvas.paste(Image.fromarray(dst.astype(np.uint8), "RGBA"), (x0, y0))


def text(canvas, xy, label, fnt, color, anchor="mm", shadow=True):
    d = ImageDraw.Draw(canvas)
    if shadow:
        d.text((xy[0] + 1, xy[1] + 1), label, font=fnt, fill=(0, 0, 0, 150), anchor=anchor)
    d.text(xy, label, font=fnt, fill=color + (255,), anchor=anchor)


def backdrop(w, h):
    """Un faux coin de monde (dégradé vert-brun et bruit) sous la fenêtre."""
    rng = np.random.default_rng(1)
    ys, xs = np.mgrid[0:h, 0:w]
    t = ys / h
    base = np.stack([30 + 25 * t, 44 + 30 * t, 34 + 18 * t], axis=2).astype(np.float32)
    base += rng.normal(0, 6, (h, w, 1))
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").filter(ImageFilter.GaussianBlur(1.2)).convert("RGBA")
    return img


def creature(canvas, cx, cy, alpha=1.0, flip=False, scale=1.0):
    """Silhouette tenant lieu de modèle 3D (un ours, de profil)."""
    s = scale
    col = (52, 62, 72, int(255 * alpha))
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - 44 * s, cy - 26 * s, cx + 36 * s, cy + 30 * s], fill=col)
    d.ellipse([cx + 18 * s, cy - 46 * s, cx + 58 * s, cy - 8 * s], fill=col)
    d.polygon([(cx + 24 * s, cy - 42 * s), (cx + 30 * s, cy - 56 * s), (cx + 38 * s, cy - 42 * s)], fill=col)
    d.polygon([(cx + 42 * s, cy - 42 * s), (cx + 50 * s, cy - 56 * s), (cx + 56 * s, cy - 40 * s)], fill=col)
    for lx in (-34, -14, 10, 26):
        d.rounded_rectangle([cx + lx * s, cy + 10 * s, cx + (lx + 14) * s, cy + 44 * s], radius=5 * s, fill=col)
    if flip:
        layer = layer.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.alpha_composite(layer)


def toast(width, height, rarity):
    img = Image.new("RGBA", (width, height), WINDOW + (240,))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, width - 1, height - 1], outline=EDGE + (255,))
    d.rectangle([1, 1, 3, height - 2], fill=GOLD + (255,))
    d.rectangle([1, 1, width - 2, 3], fill=rarity + (255,))
    return img


SCENE = 196
STAGE_W, STAGE_H = 340, 372


def mock_frame(tex, phase, rarity, shiny=False):
    """Une image clé de la scène, en pixels du jeu (échelle 1)."""
    W, H = STAGE_W, STAGE_H
    img = toast(W, H, rarity)
    f_caps, f_display, f_heading, f_small, f_body = font("SemiBold", 10), font("Bold", 26), font("SemiBold", 13), font("Regular", 11), font("Regular", 12)
    text(img, (W / 2, 12), "CAPTURE", f_caps, MUTED_LIGHT)
    sx, sy = W / 2, 30 + SCENE / 2          # centre de la scène
    # fond de scène
    blit(img, tex["vignette"], sx, sy, size=(SCENE, SCENE))
    name = "Ours gris"
    pips = 3
    if shiny:
        name = "Ours gris brillant"
    if phase == "throw":
        text(img, (W / 2 + 92, 12), "· Appât", f_caps, GOLD)
        blit(img, tex["halo"], sx, sy, size=(200, 200), tint=rarity, alpha=0.35, add=True)
        creature(img, sx, sy + 10)
        # trajectoire : du bas à gauche vers le centre, en arc
        p = 0.45
        trail = []
        for k in range(6):
            q = p - 0.06 * k
            if q < 0:
                break
            x = sx - 120 + 120 * q
            y = sy + 150 - 150 * q - 70 * math.sin(math.pi * q)
            trail.append((x, y, k))
        for x, y, k in reversed(trail):
            blit(img, tex["particules"], x, y, size=(22 - 2 * k, 22 - 2 * k), crop=(0, 0, 0.25, 1), tint=GOLD_LIGHT, alpha=0.55 * (1 - k / 6), add=True)
        x, y, _ = trail[0]
        blit(img, tex["paquet"], x, y, size=(52, 52), rot=p * 720)
        text(img, (W / 2, H - 12), "Le filet bouge…", f_small, MUTED_LIGHT)
    elif phase == "shake":
        blit(img, tex["halo"], sx, sy, size=(220, 220), tint=rarity, alpha=0.5, add=True)
        creature(img, sx + 3, sy + 10, alpha=0.9)
        # poussière de l'impact : un anneau qui s'élargit au sol, quelques grains
        blit(img, tex["particules"], sx, sy + 56, size=(150, 44), crop=(0.75, 0, 1, 1), tint=(150, 140, 120), alpha=0.3, add=True)
        for k in range(6):
            a = k / 6 * 2 * math.pi + 0.4
            blit(img, tex["particules"], sx + math.cos(a) * 72, sy + 52 + math.sin(a) * 16, size=(10, 10), crop=(0, 0, 0.25, 1), tint=(170, 160, 140), alpha=0.5, add=True)
        blit(img, tex["filet"], sx + 3, sy, size=(222, 222), crop=(0, 0, 0.5, 1), rot=2.5)
        # secousses : losanges allumés
        for k in range(3):
            lit = k < 2
            d = ImageDraw.Draw(img)
            x = W / 2 + (k - 1) * 14
            y = H - 30
            c = GOLD if lit else EDGE
            d.polygon([(x, y - 5), (x + 5, y), (x, y + 5), (x - 5, y)], fill=c + (255,))
        text(img, (W / 2, H - 12), "Le filet bouge…", f_small, MUTED_LIGHT)
    elif phase in ("ok", "shiny"):
        col = GOLD_LIGHT if shiny else rarity
        blit(img, tex["rayons"], sx, sy, size=(300, 300), tint=col, alpha=0.7 if shiny else 0.85, rot=12, add=True)
        if shiny:
            blit(img, tex["rayons"], sx, sy, size=(240, 240), tint=GOLD, alpha=0.4, rot=-30, add=True)
        blit(img, tex["halo"], sx, sy, size=(230, 230), tint=col, alpha=0.8, add=True)
        creature(img, sx, sy + 10, flip=True)
        blit(img, tex["filet"], sx, sy + 4, size=(130, 130), crop=(0, 0, 0.5, 1), alpha=0.45)
        rng = random.Random(4)
        for k in range(18):
            a = k / 18 * 2 * math.pi + (k % 2) * 0.2
            reach = (95 + (k % 3) * 20) * 0.7
            frame = (1, 2, 0)[k % 3]
            size = (14, 18, 10)[k % 3]
            blit(img, tex["particules"], sx + math.cos(a) * reach, sy + math.sin(a) * reach - 6, size=(size, size),
                 crop=(frame / 4, 0, (frame + 1) / 4, 1), tint=col, alpha=0.9, add=True)
        if shiny:
            for k in range(14):
                x = sx + rng.uniform(-105, 105)
                y = sy + rng.uniform(-100, 100)
                blit(img, tex["particules"], x, y, size=(rng.choice([8, 10, 14]),) * 2, crop=(0, 0, 0.25, 1), tint=GOLD_LIGHT, alpha=rng.uniform(0.4, 0.9), add=True)
        # ruban
        by = 30 + SCENE + 34
        panel_tint = tuple(int(c * 0.42) for c in (GOLD if shiny else rarity))
        if shiny:
            panel_tint = (120, 78, 24)
        blit(img, tex["ruban"], W / 2, by, size=(300, 75), crop=(0, 0, 1, 0.5), tint=panel_tint)
        blit(img, tex["ruban"], W / 2, by, size=(300, 75), crop=(0, 0.5, 1, 1), tint=col)
        if shiny:
            blit(img, tex["halo"], W / 2 - 40, by, size=(60, 90), tint=(255, 255, 255), alpha=0.35, add=True)
        text(img, (W / 2, by - 2), "Capturé !", f_display, PARCHMENT)
        text(img, (W / 2, by + 46), ("✦ " if shiny else "") + name, f_heading, col)
        d = ImageDraw.Draw(img)
        for k in range(pips):
            x = W / 2 + (k - (pips - 1) / 2) * 13
            y = by + 62
            d.polygon([(x, y - 4.5), (x + 4.5, y), (x, y + 4.5), (x - 4.5, y)], fill=col + (255,))
        stars = 3 if shiny else 2
        for k in range(3):
            x = W / 2 + (k - 1) * 20
            y = by + 80
            filled = k < stars
            blit(img, tex["etoiles"], x, y, size=(18, 18), crop=(0, 0, 0.5, 1) if filled else (0.5, 0, 1, 1), tint=GOLD_LIGHT if filled else (120, 126, 132))
        blit(img, tex["particules"], W / 2 + (stars - 2) * 20 + 7, by + 74, size=(16, 16), crop=(0.5, 0, 0.75, 1), tint=(255, 255, 255), alpha=0.9, add=True)
        text(img, (W / 2, H - 12), "Nouvelle apparence pour ton compagnon" if not shiny else "Brillante ! Nouvelle apparence pour ton compagnon", f_small, MUTED_LIGHT)
    elif phase == "fail":
        blit(img, tex["halo"], sx, sy, size=(200, 200), tint=RED, alpha=0.25, add=True)
        run = 0.5
        creature(img, sx + 100 * run, sy + 10, alpha=1 - run * 1.3)
        for k in range(4):
            blit(img, tex["particules"], sx + 20 + k * 18, sy + 44 + (k % 2) * 6, size=(24 + k * 4,) * 2, crop=(0.75, 0, 1, 1), tint=(150, 140, 120), alpha=0.3 - k * 0.05, add=True)
        blit(img, tex["filet"], sx - 6, sy + 34, size=(216, 216), crop=(0.5, 0, 1, 1), rot=-7, alpha=0.75)
        rng = random.Random(2)
        for k in range(7):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(60, 125)
            blit(img, tex["corde"], sx + math.cos(a) * r, sy + math.sin(a) * r * 0.8 - 20, size=(rng.uniform(34, 60), 7), rot=rng.uniform(0, 360), alpha=0.9)
        by = 30 + SCENE + 34
        blit(img, tex["ruban"], W / 2, by, size=(300, 75), crop=(0, 0, 1, 0.5), tint=(52, 58, 66))
        blit(img, tex["ruban"], W / 2, by, size=(300, 75), crop=(0, 0.5, 1, 1), tint=(120, 90, 86))
        text(img, (W / 2, by - 2), "Échappé…", f_display, RED)
        text(img, (W / 2, by + 46), name, f_heading, rarity)
        d = ImageDraw.Draw(img)
        for k in range(pips):
            x = W / 2 + (k - (pips - 1) / 2) * 13
            y = by + 62
            d.polygon([(x, y - 4.5), (x + 4.5, y), (x, y + 4.5), (x - 4.5, y)], fill=rarity + (255,))
        text(img, (W / 2, H - 12), "Il reviendra. Toi aussi.", f_small, MUTED_LIGHT)
    return img


def mock_button(tex):
    """Le bouton filet (ambre, puis or brillant) et trois lignes de la liste."""
    W, H = 340, 120
    img = Image.new("RGBA", (W, H), WINDOW + (240,))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, H - 1], outline=EDGE + (255,))
    f_small, f_body, f_caps = font("Regular", 11), font("Regular", 12), font("SemiBold", 10)
    text(img, (12, 12), "BOUTON FILET ET LISTE", f_caps, MUTED_LIGHT, anchor="lm")
    for k, (shiny, count) in enumerate(((False, 2), (True, 3))):
        x, y = 24 + k * 40, 44
        if shiny:
            blit(img, tex["halo"], x, y, size=(44, 44), tint=GOLD_LIGHT, alpha=0.6, add=True)
        d = ImageDraw.Draw(img)
        d.rectangle([x - 11, y - 11, x + 11, y + 11], outline=(GOLD_LIGHT if shiny else EDGE) + (255,))
        blit(img, tex["filet_icone"], x, y, size=(16, 16), tint=GOLD_LIGHT if shiny else GOLD, alpha=1 if shiny else 0.85)
        text(img, (x + 13, y + 11), str(count), f_small, PARCHMENT, anchor="rm")
    text(img, (92, 44), "ambre au repos · or + halo si brillante", f_small, MUTED_LIGHT, anchor="lm")
    rows = [("Ours gris", "Pas encore capturée · Rare 30 % · 24 s", 0, RARE), ("Loup", "Meilleur spécimen possible", 2, PARCHMENT), ("✦ Cerf", "Brillante ! · 45 % · 12 s", 0, GOLD_LIGHT)]
    for k, (nm, detail, stars, col) in enumerate(rows):
        y = 74 + k * 15
        text(img, (14, y), nm, f_body, col, anchor="lm")
        if stars:
            for s_ in range(3):
                blit(img, tex["etoiles"], 80 + s_ * 13, y, size=(11, 11), crop=(0, 0, 0.5, 1) if s_ < stars else (0.5, 0, 1, 1), tint=GOLD_LIGHT if s_ < stars else (110, 116, 122))
        text(img, (124, y), detail, f_small, MUTED_LIGHT, anchor="lm")
    return img


def planche_assets(tex, path):
    """Chaque texture sur fond ardoise, et ses teintes en jeu."""
    f_label, f_small = font("SemiBold", 13), font("Regular", 11)
    cells = [
        ("filet.tga 512×256", "entier | déchiré · non teinté", tex["filet"], None, (512, 256)),
        ("rayons.tga 256×256", "ADD, teinté rareté, tourné", tex["rayons"], RARE, (256, 256)),
        ("ruban.tga 256×128", "panneau teinté sombre + liseré teinté", tex["ruban"], None, (256, 128)),
        ("halo.tga 128×128", "ADD, teinté", tex["halo"], ELITE, (128, 128)),
        ("vignette.tga 128×128", "fond de scène, étiré", tex["vignette"], None, (128, 128)),
        ("etoiles.tga 128×64", "pleine | vide · teintées or / gris", tex["etoiles"], None, (256, 128)),
        ("particules.tga 128×32", "point, étoile 4, étincelle 6, anneau (ADD)", tex["particules"], GOLD_LIGHT, (256, 64)),
        ("paquet.tga 64×64", "le filet roulé, lancé", tex["paquet"], None, (128, 128)),
        ("corde.tga 128×16", "morceau qui vole (déchirure)", tex["corde"], None, (256, 32)),
        ("filet_icone.tga 32×32", "glyphe du bouton, teinté ambre", tex["filet_icone"], GOLD, (64, 64)),
    ]
    pad = 24
    col_w = [560, 300, 300]
    layout = [[0], [1, 3, 4], [2, 5, 6], [7, 8, 9]]
    W = pad + 560 + pad + 300 + pad + 300 + pad
    H = 40 + 256 + 60 + 300
    img = Image.new("RGBA", (1240, 980), WINDOW + (255,))
    text(img, (pad, 20), "QuestCompanion 2.1.0 · assets de la scène de capture (générés par tools/gen_capture_assets.py)", f_label, PARCHMENT, anchor="lm")
    positions = {}
    # colonne 1 : filet (grand), puis ruban, étoiles, particules
    x, y = pad, 50
    for idx in (0, 2, 5, 6):
        label, detail, image, tint, size = cells[idx]
        positions[idx] = (x, y)
        y += size[1] + 50
    x2 = pad + 560 + pad
    y = 50
    for idx in (1, 3, 4):
        label, detail, image, tint, size = cells[idx]
        positions[idx] = (x2, y)
        y += size[1] + 50
    x3 = x2 + 300 + pad
    y = 50
    for idx in (7, 8, 9):
        label, detail, image, tint, size = cells[idx]
        positions[idx] = (x3, y)
        y += size[1] + 50
    for idx, (label, detail, image, tint, size) in enumerate(cells):
        x, y = positions[idx]
        d = ImageDraw.Draw(img)
        d.rectangle([x - 1, y - 1, x + size[0], y + size[1]], outline=EDGE + (255,))
        if idx == 2:
            # ruban : montré teinté comme en jeu (rare), avec son texte
            blit(img, image, x + 128, y + 32, size=(256, 64), crop=(0, 0, 1, 0.5), tint=tuple(int(c * 0.42) for c in RARE))
            blit(img, image, x + 128, y + 32, size=(256, 64), crop=(0, 0.5, 1, 1), tint=RARE)
            text(img, (x + 128, y + 30), "Capturé !", font("Bold", 22), PARCHMENT)
            blit(img, image, x + 128, y + 96, size=(256, 64), crop=(0, 0, 1, 0.5), tint=(52, 58, 66))
            blit(img, image, x + 128, y + 96, size=(256, 64), crop=(0, 0.5, 1, 1), tint=(120, 90, 86))
            text(img, (x + 128, y + 94), "Échappé…", font("Bold", 22), RED)
        elif idx == 5:
            blit(img, image, x + 64, y + 64, size=(128, 128), crop=(0, 0, 0.5, 1), tint=GOLD_LIGHT)
            blit(img, image, x + 192, y + 64, size=(128, 128), crop=(0.5, 0, 1, 1), tint=(120, 126, 132))
        elif tint is not None:
            blit(img, image, x + size[0] / 2, y + size[1] / 2, size=size, tint=tint, add=True)
        else:
            blit(img, image, x + size[0] / 2, y + size[1] / 2, size=size)
        text(img, (x, y + size[1] + 14), label, f_label, PARCHMENT, anchor="lm")
        text(img, (x, y + size[1] + 30), detail, f_small, MUTED_LIGHT, anchor="lm")
    img.convert("RGB").save(path)


def maquette_scenes(tex, path):
    frames = [
        ("1. Lancer (t ≈ 0,3 s) : paquet en vol, traînée d'étincelles", mock_frame(tex, "throw", RARE)),
        ("2. Filet posé, 2e secousse : halo qui pulse, poussière, losanges", mock_frame(tex, "shake", RARE)),
        ("3. Capturé ! (rare) : rayons, gerbe, filet refermé, ruban, étoiles", mock_frame(tex, "ok", RARE)),
        ("4. Échappé : filet déchiré qui tombe, cordes, fuite", mock_frame(tex, "fail", RARE)),
        ("5. Brillante capturée : tout en or, motes, reflet sur le ruban", mock_frame(tex, "shiny", RARE, shiny=True)),
        ("6. Bouton filet (glyphe dédié) et étoiles de la liste", mock_button(tex)),
    ]
    k = 2        # zoom x2 pour lire les détails
    cell_w, cell_h = STAGE_W * k + 40, STAGE_H * k + 70
    img = Image.new("RGBA", (cell_w * 3, cell_h * 2 + 40), (10, 12, 14, 255))
    f_label = font("SemiBold", 15)
    text(img, (20, 20), "QuestCompanion 2.1.0 · maquette des images clés de la capture (zoom ×2, silhouette = modèle 3D du jeu)", f_label, PARCHMENT, anchor="lm")
    for index, (label, frame) in enumerate(frames):
        cx, cy = index % 3, index // 3
        x0, y0 = cx * cell_w + 20, 40 + cy * cell_h + 20
        if frame.height < STAGE_H:
            back = backdrop(STAGE_W, STAGE_H)
            back.alpha_composite(frame, (0, 0))
            frame = back
        else:
            back = backdrop(STAGE_W + 40, STAGE_H + 40)
            back.alpha_composite(frame, (20, 20))
            frame = back
        big = frame.resize((frame.width * k, frame.height * k), Image.LANCZOS)
        img.alpha_composite(big, (x0, y0))
        text(img, (x0, y0 + big.height + 16), label, f_label, MUTED_LIGHT, anchor="lm")
    img.convert("RGB").save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sortie", default=OUT, help="dossier des TGA (QuestCompanion/Textures par défaut)")
    parser.add_argument("--apercu", help="dossier où écrire la planche et les maquettes PNG (jamais dans le dépôt)")
    args = parser.parse_args()
    tex = paint_all()
    os.makedirs(args.sortie, exist_ok=True)
    total = 0
    for name, image in tex.items():
        path = os.path.join(args.sortie, name + ".tga")
        write_tga(path, image)
        total += os.path.getsize(path)
        print("%-16s %4dx%-4d %6.0f Ko" % (name + ".tga", image.width, image.height, os.path.getsize(path) / 1024))
    print("total %.2f Mo dans %s" % (total / 1048576, args.sortie))
    if args.apercu:
        os.makedirs(args.apercu, exist_ok=True)
        planche_assets(tex, os.path.join(args.apercu, "planche_assets.png"))
        maquette_scenes(tex, os.path.join(args.apercu, "maquette_scenes.png"))
        print("aperçus écrits dans", args.apercu)


if __name__ == "__main__":
    main()
