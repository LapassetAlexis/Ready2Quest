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
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fontpath = os.path.join(ROOT, "Fonts", "Alegreya-Bold.ttf")
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


def whelp_shadow(d, T, u, color):
    """Silhouette d'un dragonnet assis, de profil (tête à gauche, aile levée,
    queue en fer de lance), d'une seule couleur : l'« ombre » derrière QC."""
    def poly(pts): d.polygon([T(*p) for p in pts], fill=color)
    def ell(x0, y0, x1, y1): d.ellipse([T(x0, y0), T(x1, y1)], fill=color)
    # queue
    d.line([T(44, 50), T(52, 54), T(58, 50), T(59.5, 43), T(57, 37.5)], fill=color,
           width=int(3.2 * u), joint="curve")
    poly([(56.2, 31.5), (60.2, 36.5), (57.2, 40.5), (53.6, 36.2)])
    # aile levée, bord festonné
    poly([(30, 31), (36, 9), (40, 5.5), (44, 11), (54, 18.5), (49, 21), (55, 27.5), (47, 28.5), (50, 34), (40, 34)])
    # corps assis, pattes
    ell(25, 29, 47, 53)
    ell(35, 40, 49, 55)
    ell(25, 44, 32, 55.5)
    # cou et tête
    poly([(18, 25), (26, 18), (34, 31), (27, 37)])
    ell(10, 12, 29, 29)
    poly([(5, 21.5), (12, 16.5), (16, 27), (7.5, 26.5)])
    # cornes
    poly([(23, 15.5), (31, 4.5), (27, 17.5)])
    poly([(19, 13.5), (22, 4), (23.5, 14.5)])
    # crête dorsale
    for (x, y) in [(29, 20), (32.5, 25), (35.5, 30)]:
        poly([(x - 1.8, y + 1.2), (x + 1.6, y - 2.8), (x + 1.8, y + 2.2)])


def draw_qc(size):
    """Logo de QuestCompanion : monogramme QC (Alegreya Bold, Q crème, C ambre,
    comme R2Q) devant l'ombre d'un dragonnet. Fond transparent."""
    k = 8; S = size * k; u = S / 64.0
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    SC = 1.0
    T = lambda x, y: ((32 + (x - 32) * SC) * u, (31 + (y - 32) * SC) * u)
    whelp_shadow(d, T, u * SC, SHADOW)
    f = ImageFont.truetype(fontpath, int(21 * u))
    parts = [("Q", CREAM), ("C", AMB)]
    total = sum(d.textlength(t, font=f) for t, _ in parts)
    x = 33 * u - total / 2; y = 41 * u
    for t, c in parts:
        d.text((x, y), t, font=f, fill=c, anchor="lm", stroke_width=int(1.5 * u), stroke_fill=DIAL)
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
