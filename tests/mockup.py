#!/usr/bin/env python3
"""Aperçu hors-jeu de Sac & Départ (maquette, pas une capture du client).

Reproduit la palette, la hiérarchie et la disposition du code Lua
(Theme.lua / UI.lua / Equip.lua) pour valider la direction artistique.

Les icônes de module sont ici des vignettes portant une initiale : en jeu, ce
sont les vraies icônes du client (INV_Misc_Bag_10, INV_Misc_Food_15, …).
"""
import os

from PIL import Image, ImageDraw, ImageFont

MPL = "/tmp/pylib/matplotlib/mpl-data/fonts/ttf"
FONT_DIRS = [MPL, "/usr/share/fonts/truetype/dejavu", "/usr/share/fonts/TTF"]


def load_font(name, size):
    for directory in FONT_DIRS:
        path = os.path.join(directory, name)
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


F_TITLE = load_font("DejaVuSans-Bold.ttf", 16)
F_BOLD = load_font("DejaVuSans-Bold.ttf", 12)
F_BODY = load_font("DejaVuSans.ttf", 12)
F_SMALL = load_font("DejaVuSans.ttf", 11)
F_TINY = load_font("DejaVuSans-Bold.ttf", 9)
F_BIG = load_font("DejaVuSans-Bold.ttf", 24)

# Palette alignée sur Theme.lua
GOLD = (255, 209, 0)
GOLD_SOFT = (217, 173, 64)
GOLD_DIM = (115, 92, 26)
PARCHMENT = (247, 230, 191)
GREEN = (30, 255, 0)
ORANGE = (255, 140, 26)
RED = (230, 51, 38)
GREY = (140, 140, 140)
PANEL_BG = (18, 16, 14)
PANEL_BG_LIGHT = (26, 23, 20)
CANVAS_BG = (12, 11, 10)

QUALITY = {
    0: (157, 157, 157),
    1: (255, 255, 255),
    2: (30, 255, 0),
    3: (0, 112, 221),
    4: (163, 53, 238),
}


def score_color(ratio):
    if ratio >= 0.85:
        return GREEN
    if ratio >= 0.55:
        return ORANGE
    return RED


def truncate(draw, text, font, max_width):
    if draw.textlength(text, font=font) <= max_width:
        return text
    while text and draw.textlength(text + "…", font=font) > max_width:
        text = text[:-1]
    return text + "…"


def panel(draw, x, y, w, h, title, subtitle=None, title_color=None, light=False, close=True):
    """Cadre doré : bord 2 px sombre, filet intérieur, bandeau de titre."""
    draw.rectangle([x - 2, y - 2, x + w + 2, y + h + 2], fill=GOLD_DIM)
    draw.rectangle([x, y, x + w, y + h], fill=PANEL_BG_LIGHT if light else PANEL_BG)
    draw.line([x + 1, y + 1, x + w - 1, y + 1], fill=GOLD_SOFT)

    # bandeau
    draw.rectangle([x + 2, y + 2, x + w - 2, y + 29], fill=(0, 0, 0))
    draw.rectangle([x + 2, y + 2, x + w - 2, y + 15], fill=(28, 24, 12))
    draw.line([x + 2, y + 30, x + w - 2, y + 30], fill=GOLD)

    reserve = 40 if subtitle else 16
    draw.text((x + 10, y + 8), truncate(draw, title, F_TITLE, w - 10 - reserve),
              font=F_TITLE, fill=title_color or GOLD)
    if subtitle:
        tw = draw.textlength(subtitle, font=F_SMALL)
        draw.text((x + w - 40 - tw, y + 11), subtitle, font=F_SMALL, fill=PARCHMENT)

    # croix
    if close:
        cx, cy = x + w - 18, y + 15
        draw.line([cx - 4, cy - 4, cx + 4, cy + 4], fill=(190, 190, 190), width=1)
        draw.line([cx - 4, cy + 4, cx + 4, cy - 4], fill=(190, 190, 190), width=1)
    return y + 40


def divider(draw, x, y, w):
    draw.line([x, y, x + w, y], fill=GOLD_DIM)


def bar(draw, x, y, w, h, ratio, color):
    draw.rectangle([x, y, x + w, y + h], fill=(0, 0, 0))
    filled = int(w * max(0.0, min(1.0, ratio)))
    if filled > 0:
        draw.rectangle([x, y, x + filled, y + h], fill=color)
        gloss = max(1, h // 2)
        draw.rectangle([x, y, x + filled, y + gloss],
                       fill=tuple(min(255, c + 55) for c in color))
    draw.line([x, y - 1, x + w, y - 1], fill=GOLD_DIM)


def icon(draw, x, y, size, letter, tint=None):
    tint = tint or GOLD_SOFT
    draw.rectangle([x, y, x + size, y + size], fill=(8, 8, 8))
    draw.rectangle([x, y, x + size, y + size], outline=tint, width=1)
    tw = draw.textlength(letter, font=F_TINY)
    draw.text((x + (size - tw) / 2, y + (size - 11) / 2), letter, font=F_TINY, fill=tint)


def button(draw, x, y, w, h, label):
    draw.rectangle([x, y, x + w, y + h], fill=(24, 21, 16), outline=GOLD_DIM, width=1)
    draw.line([x + 1, y + 1, x + w - 1, y + 1], fill=(58, 48, 20))
    tw = draw.textlength(label, font=F_SMALL)
    draw.text((x + (w - tw) / 2, y + (h - 12) / 2), label, font=F_SMALL, fill=GOLD)


# ---------------------------------------------------------------------------
# Contenu
# ---------------------------------------------------------------------------
MODULES = [
    ("S", "Sacs", "12 emplacements libres", 1.00),
    ("G", "Butin à vendre", "3 objets gris", 0.25),
    ("V", "Vivres", "0 nourriture(s)/boisson(s)", 0.00),
    ("P", "Potions & flacons", "2 consommable(s)", 0.85),
    ("B", "Buffs", "manque : Cri de guerre, Bien nourri", 0.50),
    ("R", "Repos", "34% d'un niveau", 0.68),
    ("D", "Durabilité", "usure la plus basse : 78%", 0.78),
    ("C", "Composants", "manque 6 Étoffe de lin", 0.40),
    ("Q", "Quêtes", "2 prête(s) à rendre", 0.70),
]
ADVICE = [
    "Achète des vivres chez l'aubergiste.",
    "Pense à te buffer avant de partir.",
    "Il te manque des composants de métier.",
]
SCORE = 67

EQUIP = [
    ("Heaume de l'ours", 3, 42), ("Collier d'os", 2, 38),
    ("Épaulières usées", 2, 40), ("Plastron de cuir", 2, 41),
    ("Ceinture cloutée", 1, 39), ("Jambières", 2, 42),
    ("Bottes", 2, 38), ("Brassards", 1, 36),
    ("Gantelets", 2, 40), ("Anneau de cuivre", 2, 37),
    ("Anneau terni", 0, 34), ("Œil de pierre", 3, 41),
    ("Plume totem", 2, 35), ("Cape de voyage", 2, 38),
    ("Masse runique", 4, 44), ("Targe de bois", 1, 22),
    (None, None, None),
]
AVERAGE = 38
WEAK = 3

W1 = 440
H1 = 40 + 52 + 12 + len(MODULES) * 19 + 12 + 16 + len(ADVICE) * 13 + 36
W2 = 384
H2 = 40 + 22 + 9 * 19 + 34
W3 = 286
H3 = 40 + 18 + 5 * 14 + 10 + 14 + 3 * 13 + 16 + 30

GAP = 24
CANVAS_W = 30 + W1 + GAP + W2 + GAP + W3 + 30
CANVAS_H = 66 + max(H1, H2, H3) + 44 + 240

img = Image.new("RGB", (CANVAS_W, CANVAS_H), CANVAS_BG)
draw = ImageDraw.Draw(img)

for i in range(CANVAS_H):
    shade = 10 + int(8 * (i / CANVAS_H))
    draw.line([(0, i), (CANVAS_W, i)], fill=(shade + 4, shade + 3, shade + 2))

draw.text((30, 16), "SAC & DÉPART — direction artistique Blizzard", font=F_BOLD, fill=GOLD)
draw.text((30, 34), "Maquette hors-jeu. En jeu : fond UI-DialogBox-Background-Dark, bord or, GameFont, boutons UIPanelButtonTemplate.",
          font=F_SMALL, fill=GREY)

# --- Panneau 1 : diagnostic -------------------------------------------------
x1, y1 = 30, 66
top = panel(draw, x1, y1, W1, H1, "Sac & Départ", "PRÊT, AVEC RÉSERVES")

draw.text((x1 + 16, top + 4), "Préparation", font=F_SMALL, fill=PARCHMENT)
sx = x1 + 16 + int(draw.textlength("Préparation  ", font=F_SMALL))
draw.text((sx, top - 4), str(SCORE), font=F_BIG, fill=GOLD)
draw.text((sx + int(draw.textlength(str(SCORE), font=F_BIG)) + 4, top + 8),
          "/ 100", font=F_SMALL, fill=GREY)
bar(draw, x1 + 16, top + 32, W1 - 32, 11, SCORE / 100, score_color(SCORE / 100))
divider(draw, x1 + 16, top + 52, W1 - 32)

rows_top = top + 64
for index, (letter, label, detail, ratio) in enumerate(MODULES):
    ry = rows_top + index * 19
    color = score_color(ratio)
    icon(draw, x1 + 16, ry, 15, letter, GOLD_SOFT)
    draw.text((x1 + 38, ry + 1), label, font=F_SMALL, fill=PARCHMENT)
    bar(draw, x1 + 136, ry + 4, 76, 7, ratio, color)
    draw.text((x1 + 216, ry + 1), truncate(draw, detail, F_SMALL, W1 - 230),
              font=F_SMALL, fill=(190, 190, 190) if ratio >= 0.85 else ORANGE)

adv_top = rows_top + len(MODULES) * 19 + 12
divider(draw, x1 + 16, adv_top - 6, W1 - 32)
draw.text((x1 + 16, adv_top), "Conseils", font=F_SMALL, fill=GOLD)
for index, line in enumerate(ADVICE):
    draw.text((x1 + 22, adv_top + 15 + index * 13), "•", font=F_SMALL, fill=GOLD)
    draw.text((x1 + 34, adv_top + 15 + index * 13), line, font=F_SMALL, fill=PARCHMENT)

btn_y = y1 + H1 - 32
button(draw, x1 + 16, btn_y, 128, 20, "Lancer le check")
button(draw, x1 + 152, btn_y, 100, 20, "Réglages")
button(draw, x1 + 258, btn_y, 62, 20, "Stuff")
button(draw, x1 + W1 - 106, btn_y, 90, 20, "Fermer")

# --- Panneau 2 : équipement -------------------------------------------------
x2 = x1 + W1 + GAP
sub2 = "ilvl %d   %d à améliorer" % (AVERAGE, WEAK)
top2 = panel(draw, x2, y1, W2, H2, "Équipement", sub2)

col_w = (W2 - 30) // 2
rows_top2 = top2 + 16
weak_threshold = AVERAGE - 3
for index, (name, quality, ilvl) in enumerate(EQUIP):
    column = 0 if index < 9 else 1
    row_in_col = index % 9
    rx = x2 + 16 + column * (col_w + 8)
    ry = rows_top2 + row_in_col * 19

    if name:
        color = QUALITY[quality]
        draw.rectangle([rx, ry + 2, rx + 15, ry + 17], fill=(8, 8, 8), outline=color, width=1)
        draw.rectangle([rx + 4, ry + 6, rx + 11, ry + 13], fill=color)
        draw.text((rx + 21, ry + 2), truncate(draw, name, F_SMALL, col_w - 46),
                  font=F_SMALL, fill=color)
        ilvl_color = ORANGE if ilvl < weak_threshold else PARCHMENT
        tw = draw.textlength(str(ilvl), font=F_BOLD)
        draw.text((rx + col_w - tw, ry + 2), str(ilvl), font=F_BOLD, fill=ilvl_color)
    else:
        draw.rectangle([rx, ry + 2, rx + 15, ry + 17], fill=(8, 8, 8), outline=(70, 70, 70), width=1)
        draw.text((rx + 21, ry + 2), "Vide", font=F_SMALL, fill=(85, 85, 85))

draw.text((x2 + 16, y1 + H2 - 24), "/sd stuff pour afficher ou masquer", font=F_SMALL, fill=(92, 92, 92))

# --- Panneau 3 : réglages ----------------------------------------------------
x3 = x2 + W2 + GAP
top3 = panel(draw, x3, y1, W3, H3, "Réglages", None, close=True)

setting_rows = [
    ("Alerte sac plein", "OUI", True),
    ("Résumé au changement de stuff", "OUI", True),
    ("Stats au survol du portrait", "OUI", True),
    ("Réinitialiser les positions", "▶", None),
    ("Position du bouton de minicarte", "225°", None),
]
for index, (label, value, state) in enumerate(setting_rows):
    ry = top3 + index * 14
    draw.text((x3 + 16, ry), label, font=F_SMALL, fill=(205, 205, 205))
    tw = draw.textlength(value, font=F_BOLD)
    color = GOLD if state is None else (GREEN if state else (110, 110, 110))
    draw.text((x3 + W3 - 16 - tw, ry), value, font=F_BOLD, fill=color)

divider(draw, x3 + 14, top3 + 5 * 14 + 6, W3 - 28)
draw.text((x3 + 16, top3 + 5 * 14 + 14), "MODULES", font=F_BOLD, fill=GOLD)
module_rows = [("Sacs", "OUI", True), ("Vivres", "OUI", True), ("Quêtes", "non", False)]
for index, (label, value, state) in enumerate(module_rows):
    ry = top3 + 5 * 14 + 28 + index * 13
    draw.text((x3 + 22, ry), label, font=F_SMALL, fill=(200, 200, 200) if state else (95, 95, 95))
    tw = draw.textlength(value, font=F_BOLD)
    draw.text((x3 + W3 - 16 - tw, ry), value, font=F_BOLD,
              fill=GREEN if state else (110, 110, 110))

# bouton dédié au déplacement des cadres
btn_y = top3 + 5 * 14 + 28 + 3 * 13 + 8
draw.rectangle([x3 + 14, btn_y, x3 + W3 - 14, btn_y + 18], fill=(46, 42, 32), outline=GOLD_SOFT)
label = "Déplacer les cadres"
lw = draw.textlength(label, font=F_BOLD)
draw.text((x3 + (W3 - lw) / 2, btn_y + 3), label, font=F_BOLD, fill=PARCHMENT)

# --- Ligne 2 : cadres discrets (sans titre, filet 1 px) --------------------
y2 = 66 + max(H1, H2, H3) + 44


def discreet(x, y, w, h):
    """Cadre discret : fond noir translucide + filet doré 1 px, sans titre."""
    draw.rectangle([x, y, x + w, y + h], fill=(13, 12, 10), outline=GOLD_DIM, width=1)
    return y + 7


# Résumé éphémère : une seule ligne, aucun cadre
line_y = y2 + 20
segments = [("+3", "Armure"), ("-0,60 s", "Vitesse d'attaque")]
cursor = 30
for index, (value, label) in enumerate(segments):
    if index:
        sep = "·"
        draw.text((cursor, line_y), sep, font=F_BOLD, fill=(110, 108, 104))
        cursor += draw.textlength(sep, font=F_BOLD) + 14
    text = f"{value} {label}"
    # ombre portée, comme en jeu
    draw.text((cursor + 1, line_y + 1), text, font=F_BOLD, fill=(0, 0, 0))
    draw.text((cursor, line_y), text, font=F_BOLD, fill=GREEN)
    cursor += draw.textlength(text, font=F_BOLD) + 14

draw.text((30, line_y + 22), "une seule ligne, sans cadre — fondu après 6 s",
          font=F_SMALL, fill=(105, 105, 105))

# Stats du portrait
W5, H5 = 176, 118
t5 = discreet(310, y2, W5, H5)
draw.text((317, t5 - 1), "Guerrier · Armes", font=F_SMALL, fill=(198, 155, 110))
ivl = "ilvl 18"
draw.text((310 + W5 - 7 - draw.textlength(ivl, font=F_SMALL), t5 - 1), ivl, font=F_SMALL,
          fill=(150, 150, 150))

portrait_rows = [
    ("Force", "25", PARCHMENT),
    ("Agilité", "14", PARCHMENT),
    ("Intelligence", "12", PARCHMENT),
    ("Endurance", "30", GOLD),
    ("Armure", "506   27,5 %", PARCHMENT),
    ("DPS", "11,2", PARCHMENT),
]
for index, (label, value, color) in enumerate(portrait_rows):
    ry = t5 + 16 + index * 14
    draw.text((317, ry), label, font=F_SMALL, fill=color if color == GOLD else (205, 203, 197))
    tw = draw.textlength(value, font=F_BOLD)
    draw.text((310 + W5 - 7 - tw, ry), value, font=F_BOLD, fill=color)

draw.text((310, y2 + H5 + 6), "au survol du portrait", font=F_SMALL, fill=(105, 105, 105))

# --- Inset : bouton de minicarte -------------------------------------------
import math

mx, my = 640, y2 + 66
radius = 46

draw.ellipse([mx - radius, my - radius, mx + radius, my + radius], fill=(16, 14, 12), outline=GOLD_DIM)
draw.ellipse([mx - radius + 4, my - radius + 4, mx + radius - 4, my + radius - 4], outline=(40, 36, 28))
draw.line([mx, my - radius + 9, mx, my + radius - 9], fill=(34, 30, 24))
draw.line([mx - radius + 9, my, mx + radius - 9, my], fill=(34, 30, 24))

angle = math.radians(200)
bx = mx + math.cos(angle) * 62
by = my + math.sin(angle) * 62
size = 13
draw.ellipse([bx - size, by - size, bx + size, by + size], fill=(18, 16, 12), outline=(168, 138, 62), width=2)
draw.ellipse([bx - size + 3, by - size + 3, bx + size - 3, by + size - 3], outline=(96, 78, 34))
draw.ellipse([bx - 9, by - 9, bx + 9, by + 9], fill=(138, 100, 40))
draw.text((bx - 3, by - 6), "S", font=F_TINY, fill=(22, 17, 7))

draw.text((mx + radius + 16, my - 26), "Bouton de minicarte", font=F_BOLD, fill=GOLD)
draw.text((mx + radius + 16, my - 8), "Clic gauche : réglages", font=F_SMALL, fill=PARCHMENT)
draw.text((mx + radius + 16, my + 6), "Clic droit : lancer le check", font=F_SMALL, fill=PARCHMENT)
draw.text((mx + radius + 16, my + 20), "Glisser pour déplacer", font=F_SMALL, fill=(110, 110, 110))

draw.text((30, CANVAS_H - 20),
          "Chrome : fond et bord d'infobulle (UI-Tooltip-Background/-Border), GameFont, UIPanelCloseButton. Maquette hors-jeu.",
          font=F_SMALL, fill=GREY)

out = "/workspace/SacEtDepart-apercu.png"
img.save(out)
print("écrit:", out, img.size)
