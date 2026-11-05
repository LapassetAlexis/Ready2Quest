#!/usr/bin/env python3
"""Génère les petites textures blanches du socle (teintées en jeu).

- Media/interrupteur.tga (32x32) : rond ouvert en haut et trait vertical, le
  symbole « marche/arrêt » de l'interrupteur de module de la navigation ;
- Media/chevron.tga (16x16) : chevron vers le bas des listes déroulantes.

TGA 32 bits non compressé (origine en bas à gauche), comme losange.tga.
Anticrénelage par suréchantillonnage 4x4. Sortie déterministe.

Usage : python3 -I tools/gen_socle_media.py  (puis python3 -I tools/sync_socle.py)
"""
import math
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA = os.path.join(ROOT, "Ready2Quest", "Libs", "Socle", "Media")
SAMPLES = 4


def write_tga(path, size, coverage):
    """coverage(x, y) -> 0..1 pour un point de l'image (y vers le bas)."""
    pixels = bytearray()
    for row in range(size - 1, -1, -1):  # origine en bas à gauche
        for col in range(size):
            total = 0.0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    total += coverage(col + (sx + 0.5) / SAMPLES, row + (sy + 0.5) / SAMPLES)
            alpha = int(round(255 * total / (SAMPLES * SAMPLES)))
            pixels += bytes((255, 255, 255, alpha))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 8)
    with open(path, "wb") as handle:
        handle.write(header + bytes(pixels))


def power(x, y):
    cx = cy = 16.0
    radius, stroke = 11.0, 3.4
    dx, dy = x - cx, y - cy
    dist = math.hypot(dx, dy)
    on_ring = abs(dist - radius) <= stroke / 2
    # ouverture en haut (±38° autour de la verticale)
    angle = math.degrees(math.atan2(dx, -dy))
    if on_ring and abs(angle) > 38:
        return 1.0
    # trait vertical, du centre au haut de l'anneau
    if abs(dx) <= stroke / 2 and 2.5 <= y <= cy + 1:
        return 1.0
    return 0.0


def chevron(x, y):
    # deux segments épais : (3,5) -> (8,10) -> (13,5)
    def segment(px, py, ax, ay, bx, by):
        vx, vy = bx - ax, by - ay
        t = max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy)))
        return math.hypot(px - (ax + t * vx), py - (ay + t * vy))
    d = min(segment(x, y, 3.5, 5.5, 8, 10.5), segment(x, y, 8, 10.5, 12.5, 5.5))
    return 1.0 if d <= 1.1 else 0.0


def main():
    write_tga(os.path.join(MEDIA, "interrupteur.tga"), 32, power)
    write_tga(os.path.join(MEDIA, "chevron.tga"), 16, chevron)
    print("textures écrites dans", os.path.relpath(MEDIA, ROOT))


if __name__ == "__main__":
    main()
