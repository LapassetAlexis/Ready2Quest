#!/usr/bin/env python3
"""Logos des pages CurseForge et Wago (PNG 400x400), et icône en jeu de
QuestCompanion.

- Ready2Quest : comme le logo en jeu (Textures/logo.tga), boussole de poche,
  monogramme R2Q en Alegreya Bold.
- QuestCompanion : un dragonnet dans le même boîtier à anneau, mêmes couleurs.

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

BLUE_L = (140, 182, 235, 255)


def draw_whelp(size):
    """Dragonnet de QuestCompanion, dans le boîtier à anneau de Ready2Quest."""
    k=8; S=size*k; u=S/64.0
    im=Image.new("RGBA",(S,S),(0,0,0,0)); d=ImageDraw.Draw(im)
    P=lambda x,y:(x*u,y*u)
    SC=0.86
    T=lambda x,y:((32+(x-32)*SC)*u,(38.5+(y-32)*SC)*u)
    def poly(pts,fill,outline=None,w=0): d.polygon([T(*p) for p in pts],fill=fill)
    def ell(x0,y0,x1,y1,fill,outline=None,w=0): d.ellipse([T(x0,y0),T(x1,y1)],fill=fill)
    # boîtier à anneau, comme le logo de Ready2Quest
    d.ellipse([P(27.8,4.3),P(36.2,12.7)],outline=AMB,width=int(2.2*u))
    d.rectangle([P(28.5,11),P(35.5,15.5)],fill=AMB)
    d.ellipse([P(7,12),P(57,62)],fill=DIAL,outline=AMB,width=int(3*u))
    for i in range(36):
        a=i/36*2*math.pi; x=32+20.5*math.sin(a); y=37-20.5*math.cos(a)
        d.ellipse([P(x-.55,y-.55),P(x+.55,y+.55)],fill=AMB_D)
    # queue enroulée (derrière le corps), pointe en fer de lance
    d.line([T(38,48),T(44.5,51.8),T(49.5,50.2),T(52,46.5),T(51.6,42.6)],fill=BLUE_D,width=int(3*u*SC),joint="curve")
    poly([(51.4,35.6),(54.4,40.2),(51.6,43.4),(48.8,40.2)],AMB)
    # ailes
    poly([(25,33),(10,18),(13,27),(9,30),(14,34),(12,38),(24,39)],BLUE_D)
    poly([(24,34),(13,22),(14.5,28),(11.5,30.5),(15.5,33.5),(14.5,37),(23,37.5)],AMB_D)
    poly([(39,33),(54,18),(51,27),(55,30),(50,34),(52,38),(40,39)],BLUE_D)
    poly([(40,34),(51,22),(49.5,28),(52.5,30.5),(48.5,33.5),(49.5,37),(41,37.5)],AMB_D)
    # corps
    ell(23,31,41,52,BLUE)
    ell(27,35,37,51,CREAM)
    for yy in (39,42.5,46):
        d.line([T(28.3,yy),T(35.7,yy)],fill=(214,200,170,255),width=int(.6*u))
    # pattes
    ell(22.5,47,29,53,BLUE_D); ell(35,47,41.5,53,BLUE_D)
    for x in (23.5,25.8,28):
        ell(x-.8,51.6,x+.8,53.4,CREAM)
    for x in (36,38.3,40.6):
        ell(x-.8,51.6,x+.8,53.4,CREAM)
    # cornes
    poly([(25.5,19),(21,9.5),(28.5,16.5)],AMB)
    poly([(38.5,19),(43,9.5),(35.5,16.5)],AMB)
    # tête
    ell(19.5,14,44.5,36,BLUE)
    ell(24.5,26,39.5,36.5,BLUE_L)   # museau
    ell(28.3,29.5,29.9,31.1,BLUE_D); ell(34.1,29.5,35.7,31.1,BLUE_D)  # narines
    # crête
    poly([(30,14.5),(32,10.5),(34,14.5)],AMB)
    # yeux
    for cx in (26,38):
        ell(cx-3.6,19.5,cx+3.6,27.2,CREAM)
        ell(cx-2.4,20.6,cx+2.2,26.6,DIAL)
        ell(cx-1.6,21.2,cx-0.1,22.8,(255,255,255,255))
    # sourire
    d.arc([T(29.2,30.4),T(34.8,34.6)],start=20,end=160,fill=BLUE_D,width=int(.8*u))
    # joues
    ell(20.8,27.5,24.2,30,(230,140,120,150)); ell(39.8,27.5,43.2,30,(230,140,120,150))
    return im.resize((size,size),Image.LANCZOS)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    draw_logo(400, True).save(os.path.join(OUT, "logo_ready2quest.png"))
    draw_whelp(400).save(os.path.join(OUT, "logo_questcompanion.png"))
    textures = os.path.join(ROOT, "QuestCompanion", "Textures")
    os.makedirs(textures, exist_ok=True)
    draw_whelp(64).save(os.path.join(textures, "logo_petit.tga"), compression=None)
    print("ok")
