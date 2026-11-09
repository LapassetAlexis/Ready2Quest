#!/usr/bin/env python3
"""Génère DungeonData.lua : la base des donjons du module « Avant le donjon ».

Sources (données du client, publiées par wago.tools) :
  Map / AreaTable Forever 1.60.1.70753  https://wago.tools/db2/<Table>/csv?build=1.60.1.70753
Niveaux : le LFGDungeons de Forever ne porte plus de fourchette (ContentTuning
  n'a qu'un niveau mini). Fourchettes recommandées relevées sur
  https://www.method.gg/wow-forever/dungeons (donjons classiques) et
  https://warcraft.wiki.gg/wiki/Patch_1.60 (les 9 nouveaux), recoupées avec
  games.gg (wow-forever-dungeons-guide), le 2026-11-03.

Les 9 donjons de Forever : seuls 4 ont une carte d'instance dans le client
1.60.1.70753 (City of Dalaran 2959, Ruins of Lordaeron 2999, Excavation Site:
Wetlands 2998, The Hall of Thanes 3065). Les 5 autres (The Drowned City,
Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace) sortent au
lancement : sans mapID, ils sont reconnus par leur nom anglais à l'intérieur,
et par leur sous-zone d'entrée quand le client la connaît déjà.

Entrées : sous-zones extérieures (ContinentID 0/1) portant le nom donné ici,
résolues en areaID. Les entrées partagées (Mont Rochenoire : BRD + BRS) ou
situées dans une capitale (Prison de Hurlevent, Gouffre de Ragefeu, Salle des
Thanes) sont volontairement absentes : on y passe sans aller au donjon.

Usage : python3 -I tools/gen_dungeons.py <dossier des CSV> > Ready2Quest/Libs/Socle/DungeonData.lua
  (fichiers attendus : Map_<build>.csv, AreaTable_<build>.csv)
"""
import csv, os, sys

FOREVER = "1.60.1.70753"

# clé, nom de la carte (Map.MapName_lang), niveaux recommandés,
# sous-zones d'entrée (nom anglais exact dans AreaTable)
DUNGEONS = [
    ("rfc",       "Ragefire Chasm",     (13, 18), []),
    ("wc",        "Wailing Caverns",    (15, 24), []),
    ("dm",        "Deadmines",          (17, 26), []),
    ("sfk",       "Shadowfang Keep",    (20, 30), ["Shadowfang Keep"]),
    ("bfd",       "Blackfathom Deeps",  (24, 32), ["Blackfathom Deeps"]),
    ("stocks",    "Stormwind Stockade", (24, 32), []),
    ("gnomer",    "Gnomeregan",         (29, 38), ["Gnomeregan"]),
    ("rfk",       "Razorfen Kraul",     (29, 38), ["Razorfen Kraul"]),
    ("sm",        "Scarlet Monastery",  (30, 46), []),
    ("rfd",       "Razorfen Downs",     (37, 46), ["Razorfen Downs"]),
    ("ulda",      "Uldaman",            (41, 51), ["Uldaman"]),
    ("zf",        "Zul'Farrak",         (44, 54), ["Zul'Farrak"]),
    ("mara",      "Maraudon",           (46, 55), []),
    ("st",        "Sunken Temple",      (50, 60), []),
    ("brd",       "Blackrock Depths",   (52, 60), []),
    ("brs",       "Blackrock Spire",    (55, 60), []),
    ("dmaul",     "Dire Maul",          (54, 60), ["Dire Maul"]),
    ("scholo",    "Scholomance",        (58, 60), ["Caer Darrow"]),
    ("strat",     "Stratholme",         (58, 60), ["Stratholme"]),
    # Forever (1.60) -- warcraft.wiki.gg/wiki/Patch_1.60
    ("thanes",    "The Hall of Thanes", (13, 18), []),
    ("lordaeron", "Ruins of Lordaeron", (15, 22), ["Ruins of Lordaeron"]),
    ("excavation", "Excavation Site: Wetlands", (24, 29), ["Excavation Site: Wetlands"]),
    ("dalaran",   "City of Dalaran",    (28, 33), ["Dalaran"]),
    ("drowned",   "The Drowned City",   (35, 40), []),
    ("kroldok",   "Krol'dok Stronghold", (40, 45), ["Krol'dok Stronghold"]),
    ("alcaz",     "Alcaz Prison",       (48, 53), []),
    ("blackmaw",  "Blackmaw Hold",      (55, 60), ["Blackmaw Hold"]),
    ("shaper",    "Shaper's Terrace",   (58, 60), ["The Shaper's Terrace"]),
]

# Plans avancés (Advanced Blueprints) de Forever par donjon. Au 2026-11-03,
# aucune source publique ne relie un plan à un boss (games.gg : « the full
# boss-to-Blueprint mapping has not been published »). Vide plutôt que faux.
# Format : clé = [ { "prof": "BS"|"LW"|..., "item": itemID, "name": "...", "source": url } ]
BLUEPRINTS = {}


def load(directory, table, build):
    path = os.path.join(directory, f"{table}_{build}.csv")
    with open(path, encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def lua_str(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main(directory):
    maps = {r["MapName_lang"]: r for r in load(directory, "Map", FOREVER) if r["InstanceType"] == "1"}
    areas = load(directory, "AreaTable", FOREVER)
    out, warnings = [], []
    out.append("-- DungeonData.lua -- GÉNÉRÉ par tools/gen_dungeons.py, ne pas éditer à la main")
    out.append("-- Donjons à 5 de Forever 1.60.1 (module « Avant le donjon »).")
    out.append("-- [clé] = { map = mapID d'instance (GetInstanceInfo, 8e retour) ou nil,")
    out.append("--           area = areaID du nom du donjon (C_Map.GetAreaInfo : nom traduit),")
    out.append("--           name = nom anglais (repli), fo = { min, max } (niveaux recommandés),")
    out.append("--           entrances = { areaID des sous-zones d'entrée } }")
    out.append("-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et")
    out.append("-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis")
    out.append("-- python3 tools/sync_socle.py.")
    out.append("local ADDON, ns = ...")
    out.append("")
    out.append('ns.DUNGEONS = ns.SocleData("DUNGEONS", function() return {')
    for key, map_name, fo_range, entrance_names in DUNGEONS:
        m = maps.get(map_name)
        map_id = int(m["ID"]) if m else None
        area_id = None
        if m:
            area_id = int(m["AreaTableID"]) or None
            if not area_id:
                top = [r for r in areas if r["ContinentID"] == m["ID"] and r["ParentAreaID"] == "0"]
                # le nom du donjon d'abord : la carte des Mortemines (36) contient
                # aussi une zone « Westfall » de premier niveau
                top.sort(key=lambda r: (map_name.lower() not in r["AreaName_lang"].lower(), int(r["ID"])))
                area_id = int(top[0]["ID"]) if top else None
        else:
            warnings.append(f"{map_name}: pas de carte d'instance dans le client")
        entrances = []
        for name in entrance_names:
            ids = sorted({int(r["ID"]) for r in areas
                          if r["AreaName_lang"] == name and r["ContinentID"] in ("0", "1") and r["ParentAreaID"] != "0"})
            if not ids:
                warnings.append(f"{map_name}: entrée « {name} » introuvable")
            entrances.extend(i for i in ids if i not in entrances)
        fields = []
        if map_id: fields.append(f"map = {map_id}")
        if area_id: fields.append(f"area = {area_id}")
        fields.append(f"name = {lua_str(map_name)}")
        fields.append(f"fo = {{ {fo_range[0]}, {fo_range[1]} }}")
        if entrances: fields.append("entrances = { " + ", ".join(str(i) for i in entrances) + " }")
        out.append(f"\t{key} = {{ " + ", ".join(fields) + " },")
    out.append("} end)")
    out.append("")
    out.append("-- Plans avancés de Forever par donjon : aucune source fiable publiée au")
    out.append("-- 2026-11-03 (voir tools/gen_dungeons.py). Vide plutôt que faux.")
    out.append('ns.DUNGEON_BLUEPRINTS = ns.SocleData("DUNGEON_BLUEPRINTS", function() return {')
    for key, items in sorted(BLUEPRINTS.items()):
        rows = ", ".join("{ prof = %s, item = %d, name = %s }" % (lua_str(i["prof"]), i["item"], lua_str(i["name"])) for i in items)
        out.append(f"\t{key} = {{ {rows} }},")
    out.append("} end)")
    out.append("")
    out.append('if ns.Mark then ns.Mark("DungeonData") end')
    print("\n".join(out))
    sys.stderr.write(f"{len(DUNGEONS)} donjons ; remarques : {warnings}\n")


if __name__ == "__main__":
    main(sys.argv[1])
