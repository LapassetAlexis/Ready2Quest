#!/usr/bin/env python3
"""Logos des deux addons (QuestCompanion 3.1.0, Ready2Quest 1.35.0).

Une famille : le même médaillon d'or (tools/gen_ui_assets.py, ring), un glyphe
et une couleur par addon.
  Ready2Quest    : l'écu coché (« prêt »), échancré au sommet pour porter le
                   « ! » doré des quêtes en cimier (« ... à partir en quête »).
  QuestCompanion : l'empreinte du compagnon, en bleu arcane.
Dessins d'origine, en SVG ci-dessous ; rien n'est repris du jeu.

Écrit, pour chaque addon :
  <Addon>/Textures/logo.tga         128x128  médaillon, glyphe complet
                                    (marque des réglages, emblème des fenêtres)
  <Addon>/Textures/logo_petit.tga    64x64   médaillon, glyphe simplifié pour
                                    20 à 32 px (liste des addons, bandeaux)
  <Addon>/Textures/logo_glyphe.tga   64x64   glyphe simplifié sur son disque,
                                    sans anneau (bouton de la mini-carte, qui a
                                    déjà le sien)
  docs/publication/logo_<addon>.png 400x400  page des stores

Nécessite rsvg-convert (librsvg : `brew install librsvg`) et Pillow.
Usage : python3 tools/gen_logos.py
"""
import base64
import io
import os
import subprocess
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_ui_assets  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DEFS = '''<defs>
<linearGradient id="gG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff0c8"/><stop offset=".45" stop-color="#f3c069"/><stop offset="1" stop-color="#a8691c"/></linearGradient>
<linearGradient id="gD" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b9782c"/><stop offset="1" stop-color="#5e3a10"/></linearGradient>
<linearGradient id="bG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#eef6ff"/><stop offset=".45" stop-color="#9cc3f5"/><stop offset="1" stop-color="#3f6fb5"/></linearGradient>
<filter id="glow" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="2.2" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
</defs>'''

# Glyphes dans un repère 100 x 100, centrés sur (50, 50), dans le rayon 33.
R2Q = '''<g filter="url(#glow)"><path d="M23 26.0 L42.8 18.5 V36.5 A7.2 7.2 0 0 0 57.2 36.5 V18.5 L77 26.0 V50 C77 67 65 79 50 86 C35 79 23 67 23 50 Z" fill="url(#gD)" stroke="#140d04" stroke-width="1.6" stroke-linejoin="round"/><path d="M29 30.5 L39.8 25.0 V36.5 A10.2 10.2 0 0 0 60.2 36.5 V25.0 L71 30.5 V50 C71 63 62 73 50 79 C38 73 29 63 29 50 Z" fill="#17120a" stroke="#f6c77d" stroke-width="1.2" stroke-linejoin="round"/><path d="M37 54 L46 64 L64.5 42" fill="none" stroke="url(#gG)" stroke-width="7.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M45.7 16.0 Q50 14.2 54.3 16.0 L51.8 30.0 Q50 31.2 48.2 30.0 Z" fill="url(#gG)" stroke="#0c0905" stroke-width="2.0" stroke-linejoin="round" paint-order="stroke"/><circle cx="50" cy="36.5" r="3.5" fill="url(#gG)" stroke="#0c0905" stroke-width="2.0" paint-order="stroke"/></g>'''
R2Q_SMALL = '''<g filter="url(#glow)"><path d="M23 26.0 L42.4 18.5 V33.0 A7.6 7.6 0 0 0 57.6 33.0 V18.5 L77 26.0 V50 C77 67 65 79 50 86 C35 79 23 67 23 50 Z" fill="url(#gD)" stroke="#140d04" stroke-width="1.6" stroke-linejoin="round"/><path d="M29 30.5 L42.4 25.0 V33.0 A7.6 7.6 0 0 0 57.6 33.0 V25.0 L71 30.5 V50 C71 63 62 73 50 79 C38 73 29 63 29 50 Z" fill="#17120a" stroke-linejoin="round"/><path d="M35 54 L45.5 64.5 L65.5 41.5" fill="none" stroke="url(#gG)" stroke-width="10.0" stroke-linecap="round" stroke-linejoin="round"/><path d="M45.0 13.5 Q50 11.7 55.0 13.5 L52.5 26.0 Q50 27.2 47.5 26.0 Z" fill="#ffe2a6" stroke="#0c0905" stroke-width="2.0" stroke-linejoin="round" paint-order="stroke"/><circle cx="50" cy="32.5" r="4.0" fill="#ffe2a6" stroke="#0c0905" stroke-width="2.0" paint-order="stroke"/></g>'''
QC = '''<g filter="url(#glow)" fill="url(#bG)" stroke="#06101f" stroke-width="1.6" stroke-linejoin="round"><path d="M50 49 C61 49 70 59 70 68 C70 77 61 76 50 76 C39 76 30 77 30 68 C30 59 39 49 50 49 Z"/><ellipse cx="29.5" cy="46" rx="6.6" ry="8.6" transform="rotate(-22 29.5 46)"/><ellipse cx="42" cy="33" rx="6.6" ry="9"/><ellipse cx="58" cy="33" rx="6.6" ry="9"/><ellipse cx="70.5" cy="46" rx="6.6" ry="8.6" transform="rotate(22 70.5 46)"/></g>'''

LOGOS = {
    "Ready2Quest": {"large": R2Q, "small": R2Q_SMALL, "disc": ("#2b3540", "#0a0c0f"), "store": "logo_ready2quest.png"},
    "QuestCompanion": {"large": QC, "small": QC, "disc": ("#213556", "#070b13"), "store": "logo_questcompanion.png"},
}


def ring_uri():
    return "data:image/png;base64," + base64.b64encode(gen_ui_assets.png(*gen_ui_assets.ring(512))).decode()


def medallion(glyph, disc, ring):
    """Le médaillon complet : disque sombre, glyphe, anneau d'or par-dessus."""
    return ('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 100 100">' + DEFS +
            '<defs><radialGradient id="dk" cx="50%%" cy="36%%" r="60%%"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></radialGradient>'
            '<mask id="hole"><rect width="100" height="100" fill="#fff"/><circle cx="50" cy="50" r="38.2" fill="#000"/></mask></defs>'
            '<circle cx="50" cy="50" r="39.5" fill="url(#dk)"/>%s'
            '<image x="0" y="0" width="100" height="100" mask="url(#hole)" xlink:href="%s" href="%s"/></svg>'
            % (disc[0], disc[1], glyph, ring, ring))


def bare(glyph, disc):
    """Le glyphe sur son disque plein cadre, sans anneau (la mini-carte a le sien)."""
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="12 12 76 76">' + DEFS +
            '<defs><radialGradient id="dk" cx="50%%" cy="36%%" r="60%%"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></radialGradient></defs>'
            '<circle cx="50" cy="50" r="38" fill="url(#dk)"/>%s</svg>' % (disc[0], disc[1], glyph))


def rasterize(svg_text, size):
    with tempfile.TemporaryDirectory() as tmp:
        src, out = os.path.join(tmp, "logo.svg"), os.path.join(tmp, "logo.png")
        with open(src, "w", encoding="utf-8") as handle:
            handle.write(svg_text)
        done = subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), src, "-o", out], capture_output=True, text=True)
        if done.returncode != 0:
            raise SystemExit("rsvg-convert : " + done.stderr.strip())
        with open(out, "rb") as handle:
            return Image.open(io.BytesIO(handle.read())).convert("RGBA")


def write_tga(path, image):
    raw = image.tobytes()
    pixels = [tuple(raw[i:i + 4]) for i in range(0, len(raw), 4)]
    with open(path, "wb") as handle:
        handle.write(gen_ui_assets.tga(image.width, image.height, pixels))


def main():
    ring = ring_uri()
    for addon, spec in LOGOS.items():
        textures = os.path.join(ROOT, addon, "Textures")
        os.makedirs(textures, exist_ok=True)
        write_tga(os.path.join(textures, "logo.tga"), rasterize(medallion(spec["large"], spec["disc"], ring), 128))
        write_tga(os.path.join(textures, "logo_petit.tga"), rasterize(medallion(spec["small"], spec["disc"], ring), 64))
        write_tga(os.path.join(textures, "logo_glyphe.tga"), rasterize(bare(spec["small"], spec["disc"]), 64))
        store = os.path.join(ROOT, "docs", "publication", spec["store"])
        rasterize(medallion(spec["large"], spec["disc"], ring), 400).save(store)
        print("%s : logo.tga, logo_petit.tga, logo_glyphe.tga, %s" % (addon, os.path.relpath(store, ROOT)))


if __name__ == "__main__":
    main()
