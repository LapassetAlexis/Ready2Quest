#!/usr/bin/env python3
"""Aperçu hors-jeu d'une fenêtre de l'addon, en HTML (rien à lancer en jeu).

Charge l'addon dans le harnais de test (tests/run_tests.lua, même Mock), joue
une scène de tests/snapshot.lua et écrit un HTML autonome : divs positionnées
d'après les ancres, couleurs, textes, police Inter. Les textures de l'addon
(.tga) sont incrustées en PNG (teintées par leur couleur de sommet) ; celles
du jeu restent des vignettes portant le nom du fichier.

Thème (socle 3.2) : chaque scène est rendue dans le thème Azeroth (forgé, le
thème par défaut des deux addons) ; préfixer le nom par « sobre: » la rend dans
le thème Sobre (« azeroth: » est accepté aussi). Le thème est posé dans les
deux addons avant la construction des fenêtres et tenu pendant la scène.

Rendu du thème forgé : une couleur de sommet MULTIPLIE la texture (une plaque
grise en relief garde son relief, l'alpha de la texture découpe la forme) ;
SetTexCoord découpe la texture et la retourne (gauche > droite : miroir
horizontal, haut > bas : vertical) ; ADD passe en fusion additive ; l'ordre
de dessin suit strate, niveau du cadre (comme en jeu : parent + 1, ou
SetFrameLevel), couche et sous-couche ; la scène s'agrandit pour tout ce qui
déborde des fenêtres (ombre portée, médaillon), sur un fond de paysage estompé.

Usage :
  python3 tests/snapshot.py <scène> <sortie.html>          (Azeroth)
  python3 tests/snapshot.py sobre:<scène> <sortie.html>    (Sobre)
  python3 tests/snapshot.py all <dossier>       (toutes les scènes ; « sobre:all » en Sobre)
  python3 tests/snapshot.py list
Scènes (Snap.scenes dans tests/snapshot.lua ; « list » les donne toutes) :
  thème forgé : forge-bricks (chaque matière de Theme.ART, plaque et creux en
  9 tranches à plusieurs tailles et teintes, lueurs, boutons), forge-dialog-toast
  (fenêtre de dialogue et bandeau côte à côte) ; bricks ; réglages : r2q-options, r2q-options-bags, r2q-options-nav, r2q-options-spellranks,
  qc-options-companion, qc-options-ornaments, options-search ; fenêtres de Ready2Quest :
  r2q-check, r2q-dungeon, r2q-expedition, r2q-death, r2q-lootroom, r2q-spellranks ; bandeaux :
  r2q-bagspace, r2q-camp, r2q-gear-toast, r2q-portrait, r2q-edit-banner, r2q-notice,
  r2q-exit-alert ; infobulles et divers : r2q-pace, r2q-minimap-tooltip, r2q-reward,
  r2q-settings-canvas ; QuestCompanion (3.1.0 : tout au thème forgé) : carnet
  qc-journal-creature, qc-journal-progress, qc-journal-day, qc-journal-menagerie,
  qc-journal-guide, qc-journal-feats, qc-journal-reserve, qc-journal-juke,
  qc-journal-confirm, qc-journal-winter, qc-trainer, qc-allure (et
  qc-journal-day-azeroth : l'ancien habillage, sous son drapeau) ; compagnon
  qc-companion, qc-companion-hover, qc-companion-frame-tint, qc-companion-talk,
  qc-companion-sad, qc-companion-winter, qc-tutorial, qc-pantry ; capture
  qc-capture, qc-capture-shake, qc-capture-ok, qc-capture-fail, qc-capture-toast,
  qc-capture-shiny, qc-capture-prep, qc-capture-batch3, qc-capture-batch6,
  qc-capture-chooser ; bandeaux qc-result-forge, qc-result-shiny-forge,
  qc-feat-forge, qc-feat-big-forge, qc-guild-forge, qc-tour-forge ; divers
  qc-chest, qc-notify, qc-tracker, qc-tooltip.
Ne pas versionner les HTML produits.
"""
import base64
import html
import os
import re
import struct
import sys
import zlib

sys.path.insert(0, os.environ.get("LUA_PYLIB", "/tmp/pylib"))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:  # pragma: no cover
    print("ERREUR: le paquet python 'lupa' est requis (pip install --target /tmp/pylib lupa)")
    raise SystemExit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST_FILE = os.path.join(ROOT, "tests", "run_tests.lua")


def scene_names():
    text = open(os.path.join(ROOT, "tests", "snapshot.lua"), encoding="utf-8").read()
    names = re.findall(r'Snap\.scenes(?:\.([A-Za-z0-9_]+)|\["([^"]+)"\])\s*=\s*function', text)
    return [a or b for a, b in names]


def render(scene, out):
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ADDON_ROOT = ROOT
    g.MODULE_TEST_FILES = lua.table_from([])
    g.SNAPSHOT_SCENE = scene
    g.SNAPSHOT_OUT = out
    with open(TEST_FILE, "r", encoding="utf-8") as handle:
        lua.execute(handle.read())
    embed_textures(out)
    return g.SNAPSHOT_RESULT


# -- textures de l'addon : TGA -> PNG --------------------------------------------
def tga_to_png(path):
    data = open(path, "rb").read()
    id_len, cmap_type, img_type = data[0], data[1], data[2]
    width, height, bpp, desc = struct.unpack("<HHBB", data[12:18])
    if cmap_type != 0 or img_type not in (2, 10) or bpp not in (24, 32):
        return None
    channels = bpp // 8
    pos = 18 + id_len
    pixels = bytearray()
    total = width * height * channels
    if img_type == 2:
        pixels = bytearray(data[pos:pos + total])
    else:  # RLE
        while len(pixels) < total:
            head = data[pos]
            pos += 1
            count = (head & 0x7F) + 1
            if head & 0x80:
                pixels += data[pos:pos + channels] * count
                pos += channels
            else:
                pixels += data[pos:pos + channels * count]
                pos += channels * count
    rows = []
    for y in range(height):
        src_row = y if desc & 0x20 else height - 1 - y
        row = pixels[src_row * width * channels:(src_row + 1) * width * channels]
        out = bytearray()
        for x in range(width):
            b, gg, r = row[x * channels:x * channels + 3]
            a = row[x * channels + 3] if channels == 4 else 255
            out += bytes((r, gg, b, a))
        rows.append(b"\x00" + bytes(out))
    raw = b"".join(rows)

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    return "data:image/png;base64," + base64.b64encode(png).decode("ascii")


def addon_file(game_path):
    """Interface\\AddOns\\<Addon>\\x\\y -> fichier du dépôt (avec .tga au besoin)."""
    path = game_path.replace("\\\\", "\\").replace("\\", "/")
    match = re.match(r"(?i)interface/addons/([^/]+)/(.+)$", path)
    if not match:
        return None
    base = os.path.join(ROOT, match.group(1), match.group(2))
    for candidate in (base, base + ".tga"):
        if os.path.isfile(candidate) and candidate.lower().endswith(".tga"):
            return candidate
    return None


def embed_textures(out):
    text = open(out, encoding="utf-8").read()
    cache = {}
    pattern = re.compile(r'<div class="tex file" data-src="([^"]*)" data-tint="([^"]*)"(?: data-crop="([^"]*)")? style="([^"]*)" title="[^"]*">[^<]*</div>')

    def replace(match):
        src, tint, crop, style = html.unescape(match.group(1)), match.group(2), match.group(3), match.group(4)
        local = addon_file(src)
        if not local:
            return match.group(0)
        if local not in cache:
            cache[local] = tga_to_png(local)
        uri = cache[local]
        if not uri:
            return match.group(0)
        pos = ";".join(part for part in style.split(";") if not part.startswith("background"))
        tint_match = re.match(r"rgba\((\d+),(\d+),(\d+),([\d.]+)\)", tint)
        if tint_match:
            r, g, b, a = (int(tint_match.group(1)), int(tint_match.group(2)), int(tint_match.group(3)),
                          float(tint_match.group(4)))
        else:
            r, g, b, a = 255, 255, 255, 1.0
        # découpe d'une feuille de sprites (SetTexCoord) : position et taille du fond
        geometry = "center/100% 100%"
        if crop:
            left, right, top, bottom = (float(v) for v in crop.split(","))   # l'ordre de SetTexCoord
            width, height = max(right - left, 1e-6), max(bottom - top, 1e-6)
            px = left / (1 - width) * 100 if width < 0.9999 else 0
            py = top / (1 - height) * 100 if height < 0.9999 else 0
            geometry = "%.3f%% %.3f%%/%.3f%% %.3f%%" % (px, py, 100 / width, 100 / height)
        if (r, g, b) == (255, 255, 255):
            look = "background:url(%s) %s no-repeat;opacity:%.3f" % (uri, geometry, a)
        else:
            # couleur de sommet : comme le client, elle MULTIPLIE la texture
            # (une plaque grise en relief garde son relief, une lueur blanche
            # prend la couleur) ; l'alpha de la texture découpe la forme
            # (masque), l'alpha du sommet passe par l'opacité
            look = ("background:url(%s) %s no-repeat,rgb(%d,%d,%d);background-blend-mode:multiply;"
                    "-webkit-mask:url(%s) %s no-repeat;mask:url(%s) %s no-repeat;opacity:%.3f"
                    % (uri, geometry, r, g, b, uri, geometry, uri, geometry, a))
        return '<div class="tex" title="%s" style="%s;%s"></div>' % (html.escape(src), pos, look)

    text = pattern.sub(replace, text)
    with open(out, "w", encoding="utf-8") as handle:
        handle.write(text)


def main(argv):
    if len(argv) >= 1 and argv[0] == "list":
        print("\n".join(scene_names()))
        return 0
    if len(argv) != 2:
        print(__doc__)
        return 2
    scene, out = argv
    if scene in ("all", "sobre:all", "azeroth:all"):
        prefix = scene[:-len("all")]
        os.makedirs(out, exist_ok=True)
        for name in scene_names():
            path = os.path.join(out, prefix.replace(":", "-") + name + ".html")
            print(render(prefix + name, os.path.abspath(path)))
        return 0
    print(render(scene, os.path.abspath(out)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
