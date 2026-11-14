#!/usr/bin/env python3
"""Textures d'habillage du thème Azeroth (socle 3.2), générées par ce script.

Aucune illustration : des formes, des dégradés, des reliefs et des lueurs,
calculés pixel par pixel (anticrénelage par distance signée). Rien n'est
repris d'un jeu ni d'internet. Sortie déterministe, sans dépendance.

Écrit dans Ready2Quest/Libs/Socle/Media/ (recopié dans QuestCompanion par
tools/sync_socle.py) des TGA 32 bits non compressés, côtés en puissances de 2 :

  cadre.tga        64x64   cadre d'orfèvre à coins doux, en 9 tranches (marge 16) :
                           liseré noir, filet d'or en relief, ombre intérieure ;
                           centre vide. En couleurs.
  ombre.tga        64x64   ombre portée, en 9 tranches (marge 28). Noir, alpha.
  coin.tga         64x64   coin d'orfèvre (équerre à double filet, losange, crans),
                           pour l'angle haut gauche ; retourné pour les autres.
  plaque.tga       32x32   plaque en relief, en 9 tranches (marge 8) : bord noir,
                           reflet d'un pixel en haut, dégradé, ombre en bas.
                           En gris : se teinte (SetVertexColor) selon le bouton.
  creux.tga        32x32   creux, en 9 tranches (marge 8) : fond très sombre,
                           ombre intérieure en haut, filet clair en bas. En gris :
                           le filet prend la teinte, le fond reste presque noir.
  lueur_ligne.tga  256x8   filet lumineux qui s'estompe vers la droite. Blanc, alpha.
  lueur_point.tga  32x32   point lumineux (cœur + halo). Blanc, alpha.
  vignette.tga     64x64   assombrit les bords d'une fenêtre. Noir, alpha.

L'anneau du médaillon des logos (ring) est aussi dessiné ici : tools/gen_logos.py
le reprend.

Usage : python3 -I tools/gen_ui_assets.py [--png DOSSIER]
  --png : écrit aussi chaque texture en PNG dans DOSSIER (aperçu, maquettes).
"""
import math
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Ready2Quest", "Libs", "Socle", "Media")

GOLD_HI, GOLD, GOLD_LO = (246, 199, 125), (232, 165, 75), (138, 93, 34)


# ---------------------------------------------------------------------------
# Outils : couleurs, formes, fichiers
# ---------------------------------------------------------------------------
def clamp(value):
    return max(0, min(255, int(round(value))))


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))


def rrect(x, y, w, h, r):
    """Distance signée au bord d'un rectangle arrondi (négative dedans)."""
    cx, cy = x + 0.5 - w / 2, y + 0.5 - h / 2
    qx, qy = abs(cx) - (w / 2 - r), abs(cy) - (h / 2 - r)
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r


def cover(distance):
    """Part du pixel couverte par une forme dont le bord est à `distance`."""
    return max(0.0, min(1.0, 0.5 - distance))


def grey(level, alpha):
    v = clamp(level * 255)
    return (v, v, v, clamp(alpha * 255))


def tga(width, height, pixels):
    """TGA 32 bits non compressé, origine en bas à gauche, BGRA."""
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    rows = []
    for y in range(height - 1, -1, -1):
        row = bytearray()
        for x in range(width):
            r, g, b, a = pixels[y * width + x]
            row += bytes((b, g, r, a))
        rows.append(bytes(row))
    return header + b"".join(rows)


def png(width, height, pixels):
    raw = b"".join(b"\x00" + bytes(v for x in range(width) for v in pixels[y * width + x]) for y in range(height))

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


# ---------------------------------------------------------------------------
# Les textures
# ---------------------------------------------------------------------------
def cadre(size=64, radius=4):
    pixels = []
    for y in range(size):
        for x in range(size):
            d = rrect(x, y, size, size, radius)
            depth = -d
            gold = mix(GOLD_HI, GOLD_LO, y / (size - 1))
            if depth < 1.0:                                   # liseré noir
                colour, alpha = (0, 0, 0), cover(d)
            elif depth < 2.4:                                 # filet d'or, plus sombre vers l'intérieur
                colour = mix((0, 0, 0), gold, min(1.0, depth - 1.0))
                if depth > 2.0:
                    colour = mix(colour, (10, 8, 5), (depth - 2.0) / 0.4 * 0.5)
                alpha = 1.0
            elif depth < 3.6:                                 # ombre intérieure
                colour, alpha = (0, 0, 0), 0.55 * (1 - (depth - 2.4) / 1.2)
            else:
                colour, alpha = (0, 0, 0), 0.0
            pixels.append((clamp(colour[0]), clamp(colour[1]), clamp(colour[2]), clamp(alpha * 255)))
    return size, size, pixels


def ombre(size=64, spread=22, radius=5, strength=0.78):
    pixels = []
    inner = size - 2 * spread
    for y in range(size):
        for x in range(size):
            d = rrect(x - spread, y - spread, inner, inner, radius)
            alpha = strength if d <= 0 else math.exp(-(d / (spread * 0.42)) ** 2) * strength
            pixels.append((0, 0, 0, clamp(alpha * 255)))
    return size, size, pixels


def coin(size=64):
    pixels = []

    def band(value, at, width):
        return max(0.0, min(1.0, width / 2 + 0.5 - abs(value - at)))

    def fade(value):
        return max(0.0, 1 - value / (size * 0.92)) ** 0.8
    for y in range(size):
        for x in range(size):
            alpha = max(band(y, 3.5, 2.2) * fade(x) * (x > 2), band(x, 3.5, 2.2) * fade(y) * (y > 2))          # équerre
            alpha = max(alpha, band(y, 8.5, 1.0) * fade(x * 1.35) * (x > 8), band(x, 8.5, 1.0) * fade(y * 1.35) * (y > 8))
            diamond = abs(x - 9) + abs(y - 9)                                                                    # losange
            alpha = max(alpha, max(0.0, min(1.0, 7.5 - diamond)))
            if diamond < 3.2:
                alpha = min(alpha, 0.25)
            for at in (24, 34):                                                                                  # crans
                alpha = max(alpha, max(0.0, min(1.0, 2.6 - (abs(x - at) + abs(y - 3.5)))),
                            max(0.0, min(1.0, 2.6 - (abs(y - at) + abs(x - 3.5)))))
            colour = mix(GOLD_HI, GOLD_LO, min(1.0, (x + y) / (2 * size) * 2.2))
            pixels.append((clamp(colour[0]), clamp(colour[1]), clamp(colour[2]), clamp(alpha * 255)))
    return size, size, pixels


def plaque(size=32, radius=4, top=0.86, bottom=0.50):
    pixels = []
    for y in range(size):
        for x in range(size):
            d = rrect(x, y, size, size, radius)
            depth = -d
            level = top + (bottom - top) * y / (size - 1)
            if depth < 1.0:
                level = 0.0                                   # bord noir
            elif depth < 2.0 and y < radius + 2:
                level = 1.0                                   # reflet du haut
            elif depth < 2.0 and y > size - radius - 3:
                level = bottom * 0.6                          # ombre du bas
            elif y < size * 0.45:
                level += (1.0 - level) * 0.18 * (1 - y / (size * 0.45))
            pixels.append(grey(level, cover(d)))
    return size, size, pixels


def creux(size=32, radius=3, fill=0.14):
    pixels = []
    for y in range(size):
        for x in range(size):
            d = rrect(x, y, size, size, radius)
            depth = -d
            level = fill
            if depth < 1.0:
                level = 0.55 if y < size / 2 else 1.0         # filet : sombre en haut, clair en bas
            elif y < 5:
                level = fill * max(0.0, (y - 1) / 4)          # ombre intérieure
            pixels.append(grey(level, cover(d)))
    return size, size, pixels


def lueur_ligne(width=256, height=8):
    pixels = []
    for y in range(height):
        core = math.exp(-((y + 0.5 - height / 2) / (height * 0.16)) ** 2)
        halo = math.exp(-((y + 0.5 - height / 2) / (height * 0.42)) ** 2) * 0.35
        for x in range(width):
            ramp = (1 - x / (width - 1)) ** 1.6
            pixels.append((255, 255, 255, clamp(max(core, halo) * ramp * 255)))
    return width, height, pixels


def lueur_point(size=32):
    pixels = []
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - size / 2, y + 0.5 - size / 2) / (size / 2)
            core = max(0.0, 1 - d / 0.26) ** 0.5
            alpha = max(core, math.exp(-(d / 0.44) ** 2) * 0.55)
            pixels.append((255, 255, 255, clamp(alpha * 255)))
    return size, size, pixels


def vignette(size=64):
    pixels = []
    for y in range(size):
        for x in range(size):
            dx, dy = (x + 0.5 - size / 2) / (size / 2), (y + 0.5 - size / 2) / (size / 2)
            d = math.hypot(dx * 0.92, dy * 1.05)
            alpha = min(0.8, max(0.0, (d - 0.45) / 0.75) ** 1.7 * 0.72)
            pixels.append((0, 0, 0, clamp(alpha * 255)))
    return size, size, pixels


def ring(size=352):
    """Médaillon des logos : disque sombre, anneau d'or en relief, filet, quatre pointes."""
    pixels, centre, outer = [], size / 2, size / 2 - size * 10 / 176
    unit = size / 176

    def band(d, at, width):
        return max(0.0, min(1.0, width / 2 + 0.5 - abs(d - at)))
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - centre, y + 0.5 - centre
            d, angle = math.hypot(dx, dy), math.atan2(dy, dx)
            colour, alpha = (0, 0, 0), 0.0
            if d < outer - 7 * unit:
                k = d / (outer - 7 * unit)
                colour = mix((44, 52, 62), (9, 11, 14), min(1.0, k * 1.15 + (dy / outer) * 0.25 + 0.15))
                alpha = 1.0
            lit = 0.5 - 0.5 * math.sin(angle)
            b = band(d, outer - 3 * unit, 6 * unit)
            if b > 0:
                profile = 1 - abs(d - (outer - 3 * unit)) / (3.5 * unit)
                colour = mix(colour, mix((120, 78, 26), (252, 214, 140), max(0.0, min(1.0, lit * 0.8 + profile * 0.35))), b)
                alpha = max(alpha, b)
            thin = band(d, outer - 10.5 * unit, 1.4 * unit)
            if thin > 0:
                colour = mix(colour, GOLD_HI, thin * 0.9)
                alpha = max(alpha, thin)
            edge = band(d, outer + unit, 2.2 * unit)
            if edge > 0 and b < 1:
                colour = mix(colour, (0, 0, 0), edge * (1 - b))
                alpha = max(alpha, edge * 0.9)
            for k in range(4):
                px = centre + math.cos(k * math.pi / 2) * (outer - 3 * unit)
                py = centre + math.sin(k * math.pi / 2) * (outer - 3 * unit)
                diamond = (abs(x + 0.5 - px) + abs(y + 0.5 - py)) / unit
                m = max(0.0, min(1.0, (8.5 - diamond) * unit))
                if m > 0:
                    tip = mix((252, 222, 160), (150, 100, 38), min(1.0, diamond / 8.5))
                    if diamond > 6.6:
                        tip = (20, 14, 6)
                    colour = mix(colour, tip, m)
                    alpha = max(alpha, m)
            pixels.append((clamp(colour[0]), clamp(colour[1]), clamp(colour[2]), clamp(alpha * 255)))
    return size, size, pixels


ASSETS = [("cadre", cadre), ("ombre", ombre), ("coin", coin), ("plaque", plaque), ("creux", creux),
          ("lueur_ligne", lueur_ligne), ("lueur_point", lueur_point), ("vignette", vignette)]


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    preview = argv[1] if len(argv) > 1 and argv[0] == "--png" else None
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for name, draw in ASSETS:
        width, height, pixels = draw()
        data = tga(width, height, pixels)
        with open(os.path.join(OUT, name + ".tga"), "wb") as handle:
            handle.write(data)
        total += len(data)
        if preview:
            os.makedirs(preview, exist_ok=True)
            with open(os.path.join(preview, name + ".png"), "wb") as handle:
                handle.write(png(width, height, pixels))
        print("%-18s %3d x %-3d  %6d octets" % (name + ".tga", width, height, len(data)))
    print("total : %d octets dans %s" % (total, os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()
