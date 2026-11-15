#!/usr/bin/env python3
"""Taille réelle de chaque apparence de créature (QuestCompanion 3.1.0).

Le cadre du compagnon montre une créature capturée à sa taille réelle, avec
une caméra fixe : un rat y est minuscule, un géant déborde. Pour cadrer toutes
les espèces pareil, sans réglage du joueur, l'addon ramène chaque modèle à la
même taille à l'écran. Il lui faut la taille de chaque apparence (displayID) :

    taille = étendue du modèle (CreatureModelData.GeoBox) x CreatureModelData.ModelScale
             x CreatureDisplayInfo.CreatureModelScale
    étendue = max(hauteur, largeur, LENGTH_WEIGHT x longueur)   (vue de face :
              la longueur est en profondeur, elle compte moins)

Deux temps :
  1. --import [DOSSIER] : lit CreatureDisplayInfo et CreatureModelData (CSV de
     wago.tools, téléchargés, ou lus dans DOSSIER) et écrit NOTRE base
     data/forever/display_sizes.json ;
  2. sans option : écrit QuestCompanion/DisplaySizes_Forever.lua depuis la base.

Format du fichier Lua : une chaîne, trois caractères au moins par apparence :
écart avec le displayID précédent (1, 3 ou 5 caractères en base 85), puis un
caractère de taille (palier logarithmique). Lue à la demande par
ns:DisplaySize (Companion.lua), jamais mise en table.
Sortie déterministe. Usage : python3 -I tools/gen_display_sizes.py [--import [DOSSIER]]
"""
import csv
import io
import json
import math
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data", "forever", "display_sizes.json")
OUT = os.path.join(ROOT, "QuestCompanion", "DisplaySizes_Forever.lua")
BUILD = "1.60.1.70753"
URL = "https://wago.tools/db2/%s/csv?build=%s"

LENGTH_WEIGHT = 0.6
# 85 caractères sûrs dans une chaîne Lua entre crochets longs (ni « \ » ni « ] »)
ALPHABET = "".join(chr(c) for c in range(35, 123) if c not in (92, 93, 91))[:85]
assert len(ALPHABET) == 85
# paliers de taille : SIZE_MIN x SIZE_STEP^n, n de 0 à 84 (0,05 à 135 environ)
SIZE_MIN, SIZE_STEP = 0.05, 1.099


def fetch(table, folder):
    if folder:
        with open(os.path.join(folder, "%s.csv" % table), encoding="utf-8") as handle:
            return list(csv.DictReader(handle))
    request = urllib.request.Request(URL % (table, BUILD), headers={"User-Agent": "data-import"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return list(csv.DictReader(io.StringIO(response.read().decode("utf-8"))))


def import_tables(folder):
    models = {}
    for row in fetch("CreatureModelData", folder):
        box = [float(row["GeoBox_%d" % i]) for i in range(6)]
        length, width, height = box[3] - box[0], box[4] - box[1], box[5] - box[2]
        extent = max(height, width, LENGTH_WEIGHT * length)
        models[row["ID"]] = extent * (float(row["ModelScale"]) or 1)
    sizes = {}
    for row in fetch("CreatureDisplayInfo", folder):
        extent = models.get(row["ModelID"])
        scale = float(row["CreatureModelScale"]) or 1
        if extent and extent > 0:
            sizes[int(row["ID"])] = round(extent * scale, 3)
    payload = {
        "_source": "wago.tools : CreatureDisplayInfo, CreatureModelData",
        "_build": BUILD,
        "_formule": "max(hauteur, largeur, %s x longueur) x ModelScale x CreatureModelScale" % LENGTH_WEIGHT,
        "sizes": {str(key): sizes[key] for key in sorted(sizes)},
    }
    with open(DATA, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=0, sort_keys=False)
        handle.write("\n")
    return len(sizes)


def bucket(size):
    n = int(round(math.log(max(size, SIZE_MIN) / SIZE_MIN) / math.log(SIZE_STEP)))
    return max(0, min(84, n))


def digits(value, count):
    out = []
    for _ in range(count):
        out.append(ALPHABET[value % 85])
        value //= 85
    return "".join(reversed(out))


def encode(sizes):
    parts, last = [], 0
    for display in sorted(sizes):
        delta = display - last
        last = display
        if delta < 80:
            parts.append(ALPHABET[delta])
        elif delta < 4 * 85 * 85:
            parts.append(ALPHABET[80 + delta // (85 * 85)] + digits(delta % (85 * 85), 2))
        else:
            parts.append(ALPHABET[84] + digits(delta, 4))
        parts.append(ALPHABET[bucket(sizes[display])])
    return "".join(parts)


def build(path=OUT):
    with open(DATA, encoding="utf-8") as handle:
        payload = json.load(handle)
    sizes = {int(key): float(value) for key, value in payload["sizes"].items()}
    text = encode(sizes)
    lines = [text[i:i + 120] for i in range(0, len(text), 120)]
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("""-- DisplaySizes_Forever.lua -- taille réelle de chaque apparence de créature (QuestCompanion 3.1.0)
--
-- FICHIER GÉNÉRÉ par tools/gen_display_sizes.py depuis data/forever/display_sizes.json,
-- ne pas éditer à la main. Source : wago.tools (CreatureDisplayInfo, CreatureModelData),
-- client %s. %d apparences.
local ADDON, ns = ...
if ns.blocked then return end
-- garde de client : seul le client Forever lit cette table
if ns.IsForeverClient and ns:IsForeverClient() ~= true then return end

-- Une suite d'apparences, dans l'ordre des displayID : l'écart avec la
-- précédente (1 caractère si < 80 ; sinon un caractère 80..83 et 2 chiffres,
-- ou le caractère 84 et 4 chiffres, en base 85), puis un caractère de taille :
-- taille = SIZE_MIN x SIZE_STEP ^ rang. Lue par ns:DisplaySize (Companion.lua).
ns.DISPLAY_SIZE_ALPHABET = [[%s]]
ns.DISPLAY_SIZE_MIN, ns.DISPLAY_SIZE_STEP = %s, %s
ns.DISPLAY_SIZES = table.concat({
""" % (payload["_build"], len(sizes), ALPHABET, SIZE_MIN, SIZE_STEP))
        for line in lines:
            handle.write("[[%s]],\n" % line)
        handle.write("})\n")
    return len(sizes), len(text)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv and argv[0] == "--import":
        count = import_tables(argv[1] if len(argv) > 1 else None)
        print("data/forever/display_sizes.json : %d apparences" % count)
    count, size = build()
    print("QuestCompanion/DisplaySizes_Forever.lua : %d apparences, %d caractères" % (count, size))


if __name__ == "__main__":
    main()
