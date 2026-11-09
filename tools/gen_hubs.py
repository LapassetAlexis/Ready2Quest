#!/usr/bin/env python3
"""Génère Hubs.lua : la base des zones sûres livrée avec l'addon.

Sources (données du client, publiées par wago.tools) :
  AreaTable Forever 1.60.1.70753  https://wago.tools/db2/AreaTable/csv?build=1.60.1.70753
Liste des lieux : croisée warcraft.wiki.gg (Inn, Innkeeper), page Blizzard des
trajets aériens Classic et warcraft.wiki.gg (Zephras Isle, Patch 1.60) pour Forever.

Le client ne marque que les capitales (drapeau CAPITAL 0x100) : aucun drapeau
« village » n'existe sur Forever (le 0x00100000 de TBC est
AREA_FLAG_LOWLEVEL). La liste des villages est donc éditée ici, à la main,
et résolue en identifiants de zone ; le jeu traduit les noms à l'exécution
(C_Map.GetAreaInfo), ce qui rend la base valable dans toutes les langues.

Usage : python3 -I tools/gen_hubs.py > Ready2Quest/Libs/Socle/Hubs.lua
Lit AreaTable dans notre base (data/forever/areas.jsonl, importée par
tools/import_client.py).
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CAPITAL_FACTION = {"Stormwind City": "A", "Ironforge": "A", "Darnassus": "A",
                   "Orgrimmar": "H", "Thunder Bluff": "H", "Undercity": "H"}

# (nom anglais exact dans AreaTable, faction A/H/N, type)
#   town = village ou hub avec auberge et/ou maître de vol
#   inn  = auberge qui est sa propre sous-zone (rattachée à son village)
#   hub  = base neutre sans auberge (maître de vol, PNJ de service)
HUBS = [
    # Alliance
    ("Goldshire", "A", "town"), ("Sentinel Hill", "A", "town"), ("Lakeshire", "A", "town"),
    ("Darkshire", "A", "town"), ("Kharanos", "A", "town"), ("Thelsamar", "A", "town"),
    ("Menethil Harbor", "A", "town"), ("Southshore", "A", "town"), ("Refuge Pointe", "A", "town"),
    ("Aerie Peak", "A", "town"), ("Wildhammer Keep", "A", "inn"), ("Chillwind Camp", "A", "hub"),
    ("Nethergarde Keep", "A", "hub"), ("Morgan's Vigil", "A", "hub"), ("Rut'theran Village", "A", "town"),
    ("Dolanaar", "A", "town"), ("Auberdine", "A", "town"), ("Astranaar", "A", "town"),
    ("Stonetalon Peak", "A", "hub"), ("Nijel's Point", "A", "town"), ("Theramore Isle", "A", "town"),
    ("Feathermoon Stronghold", "A", "town"), ("Thalanaar", "A", "hub"), ("Talrendis Point", "A", "hub"),
    ("Thunderbrew Distillery", "A", "inn"), ("Stoutlager Inn", "A", "inn"), ("Deepwater Tavern", "A", "inn"),
    # Horde
    ("Brill", "H", "town"), ("Gallows' End Tavern", "H", "inn"), ("The Sepulcher", "H", "town"),
    ("Tarren Mill", "H", "town"), ("Hammerfall", "H", "town"), ("Revantusk Village", "H", "town"),
    ("Kargath", "H", "town"), ("Flame Crest", "H", "hub"), ("Stonard", "H", "town"),
    ("Grom'gol Base Camp", "H", "town"), ("Razor Hill", "H", "town"), ("Bloodhoof Village", "H", "town"),
    ("The Crossroads", "H", "town"), ("Camp Taurajo", "H", "town"), ("Splintertree Post", "H", "town"),
    ("Zoram'gar Outpost", "H", "hub"), ("Sun Rock Retreat", "H", "town"), ("Freewind Post", "H", "town"),
    ("Shadowprey Village", "H", "town"), ("Camp Mojache", "H", "town"), ("Brackenwall Village", "H", "hub"),
    ("Valormok", "H", "hub"),
    # Neutres
    ("Booty Bay", "N", "town"), ("Ratchet", "N", "town"), ("Gadgetzan", "N", "town"),
    ("Everlook", "N", "town"), ("Cenarion Hold", "N", "town"), ("Light's Hope Chapel", "N", "town"),
    ("Thorium Point", "N", "hub"), ("Nighthaven", "N", "hub"), ("Marshal's Refuge", "N", "hub"),
    ("Steamwheedle Port", "N", "hub"), ("Mirage Raceway", "N", "hub"),
    # Forever (1.60) : Zephras Isle (départ Skyborne, sanctuaire), Riverglades, Dalaran
    ("Valanaar", "N", "town"), ("Valanaar Skydocks", "N", "hub"), ("Shen'dar Village", "N", "town"),
    ("Thendal Village", "N", "town"), ("Falaath Village", "N", "town"), ("Powderfuse Port", "N", "town"),
    ("The Eventide", "A", "hub"),
]

# Vallées de départ (niveaux 1-5) et leurs sous-zones internes : une seule
# zone sûre de type « start ». Les sous-zones (la Tanière, Anvilmar…) ne sont
# pas rattachées à leur vallée dans AreaTable (elles dépendent de la zone) :
# elles sont donc listées ici. Les passages de sortie (Coldridge Pass) n'y
# sont pas : les franchir, c'est quitter la vallée.
START = [
    ("H", ["Valley of Trials", "The Den", "Burning Blade Coven"]),
    ("H", ["Camp Narache", "Brambleblade Ravine"]),
    ("H", ["Deathknell", "Night Web's Hollow"]),
    ("A", ["Northshire Valley", "Northshire Abbey", "Northshire Vineyards", "Northshire River", "Echo Ridge Mine"]),
    ("A", ["Coldridge Valley", "Anvilmar", "Frostmane Hold"]),
    ("A", ["Shadowglen", "Aldrassil", "Shadowthread Cave"]),
]

def load(client):
    """AreaTable de notre base, sous la forme qu'avait le CSV de wago.tools."""
    rows = {}
    with open(os.path.join(ROOT, "data", client, "areas.jsonl"), encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                r = json.loads(line)
                rows[r["id"]] = {"AreaName_lang": r["name"], "Flags_0": r["flags"]}
    return rows

def main():
    fo = load("forever")
    seen, entries, missing = set(), [], []
    def add(area_id, name, faction, kind):
        if area_id in seen: return
        seen.add(area_id)
        entries.append((area_id, name, faction, kind))
    for i, r in fo.items():
        if int(r["Flags_0"]) & 0x100 and r["AreaName_lang"] in CAPITAL_FACTION:
            add(i, r["AreaName_lang"], CAPITAL_FACTION[r["AreaName_lang"]], "capital")
    for name, faction, kind in HUBS:
        ids = sorted(i for i, r in fo.items() if r["AreaName_lang"] == name)
        if not ids: missing.append(name)
        for i in ids:
            add(i, name, faction, kind)
    for faction, names in START:
        for name in names:
            ids = sorted(i for i, r in fo.items() if r["AreaName_lang"] == name)
            if not ids: missing.append(name)
            for i in ids:
                add(i, name, faction, "start")
    entries.sort(key=lambda e: (e[3] != "capital", e[2], e[1], e[0]))
    out = []
    out.append("-- Hubs.lua -- GÉNÉRÉ par tools/gen_hubs.py, ne pas éditer à la main")
    out.append("-- Zones sûres connues dès l'installation : capitales (drapeau CAPITAL du")
    out.append("-- client), villages, hubs et auberges-sous-zones de Forever 1.60.1.")
    out.append("-- [areaID] = { faction = \"A\"|\"H\"|\"N\", kind = \"capital\"|\"town\"|\"inn\"|\"hub\"|\"start\", name = nom anglais (repli) }")
    out.append("--   start : vallée de départ (niveaux 1-5) ; en partir ne déclenche aucune alerte.")
    out.append("-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et")
    out.append("-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis")
    out.append("-- python3 tools/sync_socle.py.")
    out.append("local ADDON, ns = ...")
    out.append("")
    out.append('ns.HUBS = ns.SocleData("HUBS", function() return {')
    for area_id, name, faction, kind in entries:
        esc = name.replace('"', '\\"')
        out.append(f'\t[{area_id}] = {{ faction = "{faction}", kind = "{kind}", name = "{esc}" }},')
    out.append("} end)")
    out.append("")
    out.append("if ns.Mark then ns.Mark(\"Hubs\") end")
    print("\n".join(out))
    sys.stderr.write(f"{len(entries)} entrées ; introuvables : {missing}\n")

if __name__ == "__main__":
    main()
