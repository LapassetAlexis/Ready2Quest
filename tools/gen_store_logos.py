#!/usr/bin/env python3
"""Logos des pages CurseForge et Wago (PNG 400x400), dessinés comme le logo
en jeu (Textures/logo.tga) : boussole de poche, monogramme en Alegreya Bold.

Usage : python3 -I tools/gen_store_logos.py
Écrit docs/publication/logo_ready2quest.png et logo_questcompanion.png.
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


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    draw_logo(400, True).save(os.path.join(OUT, "logo_ready2quest.png"))
    draw_logo(400, True, [("Q", CREAM), ("C", AMB)]).save(os.path.join(OUT, "logo_questcompanion.png"))
    print("ok")
