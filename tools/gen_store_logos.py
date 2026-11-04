#!/usr/bin/env python3
"""Logos des pages CurseForge et Wago (PNG 400x400), et icône en jeu de
QuestCompanion.

- Ready2Quest : comme le logo en jeu (Textures/logo.tga), boussole de poche,
  monogramme R2Q en Alegreya Bold.
- QuestCompanion : monogramme QC devant l'ombre d'un dragonnet, mêmes couleurs.

Usage : python3 -I tools/gen_store_logos.py
Écrit docs/publication/logo_ready2quest.png, logo_questcompanion.png et
QuestCompanion/Textures/logo_petit.tga (icône de la liste des addons).
Nécessite Pillow.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fontpath = os.path.join(ROOT, "Ready2Quest", "Fonts", "Alegreya-Bold.ttf")
OUT = os.path.join(ROOT, "docs", "publication")

AMB=(232,165,75,255); AMB_D=(185,120,44,255); CREAM=(241,232,212,255)
BLUE=(91,143,214,255); BLUE_D=(59,103,168,255); SOUTH=(91,74,51,255); DIAL=(23,28,33,255)
def draw_logo(size, full, parts=None):
    k=8; S=size*k; u=S/64.0
    im=Image.new("RGBA",(S,S),(0,0,0,0)); d=ImageDraw.Draw(im)
    def P(x,y): return (x*u,y*u)
    # anneau de suspension + attache
    d.ellipse([P(27.8,4.3),P(36.2,12.7)],outline=AMB,width=int(2.2*u))
    d.rectangle([P(28.5,11),P(35.5,15.5)],fill=AMB)
    # boîtier
    d.ellipse([P(7,12),P(57,62)],fill=DIAL,outline=AMB,width=int(3*u))
    # lunette pointillée
    r=20.5
    for i in range(36):
        a=i/36*2*math.pi; x=32+r*math.sin(a); y=37-r*math.cos(a)
        d.ellipse([P(x-0.55,y-0.55),P(x+0.55,y+0.55)],fill=AMB_D)
    # repères cardinaux
    for (x1,y1,x2,y2) in [(32,14.5,32,18),(32,56,32,59.5),(9.5,37,13,37),(51,37,54.5,37)]:
        d.line([P(x1,y1),P(x2,y2)],fill=AMB,width=int(1.8*u))
    # aiguille à 38°
    ang=math.radians(38)
    def rot(x,y):
        dx,dy=x-32,y-37
        return P(32+dx*math.cos(ang)-dy*math.sin(ang),37+dx*math.sin(ang)+dy*math.cos(ang))
    if full:
        north=[(32,18.5),(35.2,37),(28.8,37)]; south=[(32,55.5),(35.2,37),(28.8,37)]
    else:
        north=[(32,16),(37.5,37),(26.5,37)]; south=[(32,58),(37.5,37),(26.5,37)]
    d.polygon([rot(*p) for p in north],fill=BLUE)
    d.polygon([rot(32,north[0][1]),rot(*north[2]),rot(32,37)],fill=BLUE_D)
    d.polygon([rot(*p) for p in south],fill=SOUTH if full else (122,98,64,255))
    pr=2 if full else 3
    d.ellipse([P(32-pr,37-pr),P(32+pr,37+pr)],fill=AMB)
    if full:
        f=ImageFont.truetype(fontpath,int(15.5*u)); fN=ImageFont.truetype(fontpath,int(6*u))
        parts=parts or [("R",CREAM),("2",AMB),("Q",CREAM)]
        total=sum(d.textlength(t,font=f) for t,_ in parts)
        x=32*u-total/2; y=37*u
        for t,c in parts:
            d.text((x,y),t,font=f,fill=c,anchor="lm",stroke_width=int(1.6*u),stroke_fill=DIAL)
            x+=d.textlength(t,font=f)
        d.text((32*u,22.3*u),"N",font=fN,fill=BLUE,anchor="mm")
    return im.resize((size,size),Image.LANCZOS)

SHADOW = (52, 84, 132, 255)
ROUND = 0.4  # rayon d'arrondi des angles de l'ombre (unités de la grille 64)


def bezier(p0, p1, p2, steps=24):
    """Points d'une courbe de Bézier quadratique p0 -> p2 (contrôle p1)."""
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
            for t in (i / steps for i in range(steps + 1))]


def whelp_shadow(d, T, u, color):
    """Silhouette d'un dragonnet assis, de profil (tête à gauche, aile levée,
    queue en fer de lance), tout en courbes, d'une seule couleur : l'« ombre »
    derrière QC."""
    def poly(pts): d.polygon([T(*p) for p in pts], fill=color)
    def ell(x0, y0, x1, y1): d.ellipse([T(x0, y0), T(x1, y1)], fill=color)
    def stroke(pts, width):
        d.line([T(*p) for p in pts], fill=color, width=int(width * u), joint="curve")
        for (x, y) in (pts[0], pts[-1]):
            ell(x - width / 2, y - width / 2, x + width / 2, y + width / 2)
    # queue souple et fer de lance
    stroke(bezier((42, 50), (56, 58), (57.5, 41)), 3.4)
    poly(bezier((57.5, 43.5), (50, 39), (56.3, 30.5)) + bezier((56.3, 30.5), (64.5, 37.5), (57.5, 43.5)))
    # aile : bord d'attaque courbé, trois festons creusés
    wing = (bezier((31, 32), (31, 13), (42, 5)) + bezier((42, 5), (51, 8), (57, 19))
            + bezier((57, 19), (51, 22), (56.5, 28)) + bezier((56.5, 28), (49, 28), (50, 35))
            + bezier((50, 35), (44, 31), (39, 36)))
    poly(wing)
    # corps assis, cuisse, patte avant
    ell(25, 29, 47, 53)
    ell(35, 40, 49, 55)
    ell(25, 43, 32.5, 55.5)
    # cou souple, tête ronde, museau arrondi
    stroke(bezier((20, 22), (27, 27), (33, 34)), 8)
    ell(11, 12.5, 29, 29.5)
    ell(4.5, 18.5, 17.5, 28)
    # cornes en croissant, balayées vers l'arrière
    poly(bezier((21.5, 15.5), (23, 6), (33.5, 5)) + bezier((33.5, 5), (27, 9.5), (27, 17.5)))
    poly(bezier((17, 14.5), (16, 7), (22, 4)) + bezier((22, 4), (19.8, 9), (22.2, 14.5)))
    # petites pointes sur la nuque
    for (x, y) in [(29.5, 22), (33, 26.5)]:
        poly(bezier((x - 2, y + 1.5), (x - 0.5, y - 1), (x + 1.5, y - 3)) + bezier((x + 1.5, y - 3), (x + 1, y), (x + 2, y + 2.5)))


def draw_qc(size):
    """Logo de QuestCompanion : monogramme QC (Alegreya Bold, Q crème, C ambre,
    comme R2Q) centré sur l'ombre d'un dragonnet. Fond transparent.

    L'ombre est dessinée en masque, puis floutée et re-seuillée : les angles
    des polygones s'arrondissent. Le dessin est ensuite centré dans l'image,
    et QC centré sur le dessin."""
    k = 8; S = size * k; u = S / 64.0
    mask = Image.new("L", (S, S), 0)
    T = lambda x, y: (x * u, y * u)
    whelp_shadow(ImageDraw.Draw(mask), T, u, 255)
    mask = mask.filter(ImageFilter.GaussianBlur(ROUND * u)).point(lambda v: 255 if v >= 128 else 0)
    x0, y0, x1, y1 = mask.getbbox()
    margin = 3 * u
    scale = min((S - 2 * margin) / (x1 - x0), (S - 2 * margin) / (y1 - y0))
    w, h = int((x1 - x0) * scale), int((y1 - y0) * scale)
    shape = mask.crop((x0, y0, x1, y1)).resize((w, h), Image.LANCZOS)
    ox, oy = (S - w) // 2, (S - h) // 2
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    im.paste(Image.new("RGBA", (w, h), SHADOW), (ox, oy), shape)
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(fontpath, int(22 * u))
    parts = [("Q", CREAM), ("C", AMB)]
    total = sum(d.textlength(t, font=f) for t, _ in parts)
    # centre vertical : sur les capitales (le Q descend sous la ligne)
    cap = d.textbbox((0, 0), "C", font=f, anchor="ls")
    x = S / 2 - total / 2; y = S / 2 - (cap[1] + cap[3]) / 2
    for t, c in parts:
        d.text((x, y), t, font=f, fill=c, anchor="ls", stroke_width=int(1.5 * u), stroke_fill=DIAL)
        x += d.textlength(t, font=f)
    return im.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    draw_logo(400, True).save(os.path.join(OUT, "logo_ready2quest.png"))
    draw_qc(400).save(os.path.join(OUT, "logo_questcompanion.png"))
    textures = os.path.join(ROOT, "QuestCompanion", "Textures")
    os.makedirs(textures, exist_ok=True)
    draw_qc(64).save(os.path.join(textures, "logo_petit.tga"), compression=None)
    print("ok")
