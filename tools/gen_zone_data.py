#!/usr/bin/env python3
"""Génère ZoneCreatures.lua et ZoneGathering.lua à partir de la base de Questie.

Usage :
    python3 -I tools/gen_zone_data.py /chemin/vers/QuestieDB [--commit SHA] [--date AAAA-MM-JJ]

Source : la base de données de Questie, publiée à part depuis Questie 12
(dépôt GitHub Questie/QuestieDB, branche master ; données importées de
Questie/Questie, GPL-3.0). Fichiers lus (chemins relatifs à la racine) :
    data/Classic/classicNpcDB.lua            QuestieDB.npcKeys / npcData
    data/Classic/classicObjectDB.lua         QuestieDB.objectKeys / objectData
    l10n/Classic/lookupNpcs/frFR.lua         noms français des PNJ
    support/Zones/areaIdToUiMapId.lua        areaID -> uiMapID (+ Override)
    support/Zones/subZoneToParentZone.lua    sous-zone -> zone (+ Override)
    (+ Questie/Questie : Database/Corrections/QuestieNPCBlacklist.lua, recopié
     dans ERA_BLACKLIST ; Questie 12.4.0, commit 3a1b930)

Aucune dépendance externe : un petit lecteur de littéraux Lua suffit (les
tables de Questie ne contiennent que des nombres, chaînes, nil et tables).
Les fichiers Lua de l'addon sont réécrits en entier : ne les édite pas à la
main, relance ce script.
"""
import argparse
import datetime
import os
import re
import sys

# ---------------------------------------------------------------------------
# Lecteur de littéraux Lua
# ---------------------------------------------------------------------------
TOKEN = re.compile(r"""
    \s*(?:
        (?P<c>--[^\n]*)
      | (?P<s>"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')
      | (?P<n>-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)
      | (?P<i>[A-Za-z_]\w*)
      | (?P<p>[{}\[\]=,;])
    )""", re.S | re.X)

ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


def _unescape(body):
    if "\\" not in body:
        return body
    out, i = [], 0
    while i < len(body):
        ch = body[i]
        if ch != "\\":
            out.append(ch)
            i += 1
            continue
        nxt = body[i + 1]
        if nxt.isdigit():
            m = re.match(r"\d{1,3}", body[i + 1:])
            out.append(chr(int(m.group(0))))
            i += 1 + len(m.group(0))
        else:
            out.append(ESCAPES.get(nxt, nxt))
            i += 2
    return "".join(out)


def _tokens(text):
    pos, end = 0, len(text)
    match = TOKEN.match
    while pos < end:
        m = match(text, pos)
        if not m:
            if text[pos:].strip() == "":
                return
            raise ValueError("lecteur Lua : caractère inattendu à %d : %r" % (pos, text[pos:pos + 40]))
        pos = m.end()
        kind = m.lastgroup
        if kind == "c":
            continue
        yield kind, m.group(kind)


def parse_lua_table(text):
    """Lit un littéral de table Lua ; renvoie un dict (positions -> 1, 2…)."""
    tokens = list(_tokens(text))
    index = 0

    def value():
        nonlocal index
        kind, tok = tokens[index]
        index += 1
        if kind == "p" and tok == "{":
            return table()
        if kind == "s":
            return _unescape(tok[1:-1])
        if kind == "n":
            return float(tok) if ("." in tok or "e" in tok or "E" in tok) else int(tok)
        if kind == "i":
            if tok == "nil":
                return None
            if tok == "true":
                return True
            if tok == "false":
                return False
        raise ValueError("lecteur Lua : jeton inattendu %r" % tok)

    def table():
        nonlocal index
        result, position = {}, 1
        while True:
            kind, tok = tokens[index]
            if kind == "p" and tok == "}":
                index += 1
                return result
            if kind == "p" and tok == "[":
                index += 1
                key = value()
                index += 1  # ]
                index += 1  # =
                result[key] = value()
            elif kind == "i" and tokens[index + 1] == ("p", "="):
                index += 2
                result[tok] = value()
            else:
                v = value()
                if v is not None:
                    result[position] = v
                position += 1
            kind, tok = tokens[index]
            if kind == "p" and tok in ",;":
                index += 1

    kind, tok = tokens[index]
    if tok != "{":
        raise ValueError("lecteur Lua : une table était attendue")
    index += 1
    return table()


def lua_blocks(path):
    """Tables « X = [[return { … }]] » (ou loadstring) d'un fichier : {nom: table}."""
    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()
    blocks = {}
    for m in re.finditer(r"([\w\.\[\]\"']+)\s*=\s*(?:loadstring\()?\[\[return\s*(\{.*?\n\})\]\]", text, re.S):
        blocks[m.group(1)] = parse_lua_table(m.group(2))
    return blocks, text


def lua_keys(text, name):
    """QuestieDB.npcKeys = { ['name'] = 1, … } -> {'name': 1, …}"""
    m = re.search(re.escape(name) + r"\s*=\s*\{(.*?)\n\}", text, re.S)
    if not m:
        raise ValueError("clés %s introuvables" % name)
    return {k: int(v) for k, v in re.findall(r"\['(\w+)'\]\s*=\s*(\d+)", m.group(1))}


# ---------------------------------------------------------------------------
# Zones visées : uiMapID des zones classiques de type « Zone » (mapType 3),
# hors capitales (1453-1458), instances et champs de bataille. Les 39 de
# ns.ZONE_LEVELS (CompanionChest.lua) + Reflet-de-Lune (1450), seule zone
# extérieure classique absente de ZONE_LEVELS (pas de tranche de niveau).
# ---------------------------------------------------------------------------
ZONES = {
    1411: "Durotar", 1412: "Mulgore", 1413: "The Barrens", 1416: "Alterac Mountains",
    1417: "Arathi Highlands", 1418: "Badlands", 1419: "Blasted Lands", 1420: "Tirisfal Glades",
    1421: "Silverpine Forest", 1422: "Western Plaguelands", 1423: "Eastern Plaguelands",
    1424: "Hillsbrad Foothills", 1425: "The Hinterlands", 1426: "Dun Morogh", 1427: "Searing Gorge",
    1428: "Burning Steppes", 1429: "Elwynn Forest", 1430: "Deadwind Pass", 1431: "Duskwood",
    1432: "Loch Modan", 1433: "Redridge Mountains", 1434: "Stranglethorn Vale", 1435: "Swamp of Sorrows",
    1436: "Westfall", 1437: "Wetlands", 1438: "Teldrassil", 1439: "Darkshore", 1440: "Ashenvale",
    1441: "Thousand Needles", 1442: "Stonetalon Mountains", 1443: "Desolace", 1444: "Feralas",
    1445: "Dustwallow Marsh", 1446: "Tanaris", 1447: "Azshara", 1448: "Felwood", 1449: "Un'Goro Crater",
    1450: "Moonglade", 1451: "Silithus", 1452: "Winterspring",
}

# ---------------------------------------------------------------------------
# Filtres des créatures
# ---------------------------------------------------------------------------
# Bestioles : Questie n'a pas le type de créature. Heuristique vérifiée sur la
# base : rat, lapin, écureuil, cerf, faon, mouton, poulet, chien de prairie,
# lièvre, cochon (gabarit de faction 31 « Prey ») ; crapaud, cafard, gazelle,
# chats, perroquets (188 « Ambient ») ; vache, serpent, bélier (190). En
# gabarit 7 (« Creature », neutre, aussi porté par de vrais mobs comme les
# crabes ou les zombies de Tirisfal) : seuls les serpents de niveau 1 relevés
# à la main (vipère de Durotar, mocassin du Marais des Chagrins).
CRITTER_FACTIONS = {31, 188, 190}
CRITTER_NAMES_FACTION_7 = {"Adder", "Moccasin", "Cured Gazelle"}

# Créatures « amicales envers les deux » selon Questie (friendlyToFaction
# "AH") : Questie note ainsi TOUT ce qui n'est pas hostile, donc aussi les
# bêtes neutres (jaunes) qu'on peut attaquer. On ne garde que les gabarits
# de faction neutres combattables relevés dans la base (sanglier tacheté =
# 189, crabes et vautours = 7, loups de Dun Morogh = 32, chouettes de
# Teldrassil = 15, sangliers de Loch Modan = 1094, troggs = 36, mages de
# Dalaran = 76) ; le reste (35 amical, 1630 Invasion du Fléau,
# 114 déclencheurs, 1555 Foire de Sombrelune, gardes gobelins…) sort.
NEUTRAL_COMBAT_FACTIONS = {7, 15, 32, 36, 76, 189, 1094}

# PNJ techniques (noms) ; « Stalker » seul n'est PAS filtré : « Moss Stalker »,
# « Leech Stalker »… sont de vrais mobs (l'« Invisible Stalker » tombe sur
# « Invisible »).
TECHNICAL = re.compile(
    r"Trigger|Invisible|\[DND\]|\bDND\b|Bunny|Dummy|\bTarget\b|Credit|Marker|Generator|Spawner|"
    r"Debug|Only GM|Waypoint|Spawn Point|Buffer|Scourge Structure|\(PH\)|\[PH\]|\bTest\b|UNUSED|^zz", re.I)
# Événements saisonniers (noms, titres) et faction de la Foire de Sombrelune
SEASONAL = re.compile(
    r"Lunar Festival|Halloween|Hallow|Headless Horseman|Wickerman|Love Fool|Midsummer|Winter Veil|"
    r"Greatfather Winter|Smokywood|Noblegarden|Children's Week|Darkmoon|Harvest Festival|Festival|Firebreather", re.I)
SEASONAL_FACTIONS = {1555}
# QuestieNPCBlacklist (Questie : Database/Corrections/QuestieNPCBlacklist.lua) :
# PNJ masqués par Questie sur Era (retirés du jeu ou d'événements passés)
ERA_BLACKLIST = {8001, 13151, 13153, 13154, 13319, 13320, 13377, 13446, 13449, 15799}

# ---------------------------------------------------------------------------
# Récolte : nom de l'objet du monde -> itemID de GatheringData.lua
# (minerai + pierre du même gisement). Les « Ooze Covered … » de Gangrebois
# et Silithus donnent les mêmes ressources. Ignorés : Incendicite, Indurium,
# Lesser Bloodstone (absents de GatheringData), Hakkari Thorium Vein (Zul'Gurub).
# ---------------------------------------------------------------------------
NODES = {
    "Peacebloom": [2447], "Silverleaf": [765], "Earthroot": [2449], "Mageroyal": [785],
    "Briarthorn": [2450], "Stranglekelp": [3820], "Bruiseweed": [2453], "Wild Steelbloom": [3355],
    "Grave Moss": [3369], "Kingsblood": [3356], "Liferoot": [3357], "Fadeleaf": [3818],
    "Goldthorn": [3821], "Khadgar's Whisker": [3358], "Wintersbite": [3819], "Firebloom": [4625],
    "Purple Lotus": [8831], "Arthas' Tears": [8836], "Sungrass": [8838], "Blindweed": [8839],
    "Ghost Mushroom": [8845], "Gromsblood": [8846], "Golden Sansam": [13464], "Dreamfoil": [13463],
    "Mountain Silversage": [13465], "Plaguebloom": [13466], "Icecap": [13467], "Black Lotus": [13468],
    "Copper Vein": [2770, 2835], "Tin Vein": [2771, 2836], "Silver Vein": [2775],
    "Iron Deposit": [2772, 2838], "Gold Vein": [2776], "Mithril Deposit": [3858, 7912],
    "Truesilver Deposit": [7911], "Dark Iron Deposit": [11370],
    "Small Thorium Vein": [10620, 12365], "Rich Thorium Vein": [10620, 12365],
}
NODES.update({
    "Ooze Covered Silver Vein": NODES["Silver Vein"], "Ooze Covered Iron Deposit": NODES["Iron Deposit"],
    "Ooze Covered Gold Vein": NODES["Gold Vein"], "Ooze Covered Mithril Deposit": NODES["Mithril Deposit"],
    "Ooze Covered Truesilver Deposit": NODES["Truesilver Deposit"],
    "Ooze Covered Thorium Vein": NODES["Small Thorium Vein"],
    "Ooze Covered Rich Thorium Vein": NODES["Rich Thorium Vein"],
})


def gathering_item_ids(path):
    """itemID déclarés dans GatheringData.lua (contrôle de la table NODES)."""
    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()
    return {int(i) for i in re.findall(r"^\s*\[(\d+)\]\s*=\s*R\(", text, re.M)}


# ---------------------------------------------------------------------------
# Zones : areaID (clé des spawns) -> uiMapID
# ---------------------------------------------------------------------------
def zone_mapper(root):
    blocks, _ = lua_blocks(os.path.join(root, "support/Zones/areaIdToUiMapId.lua"))
    area_to_map = dict(blocks["ZoneDB.private.areaIdToUiMapId"])
    area_to_map.update(blocks["ZoneDB.private.areaIdToUiMapIdOverride"])
    blocks, _ = lua_blocks(os.path.join(root, "support/Zones/subZoneToParentZone.lua"))
    parent = dict(blocks["ZoneDB.private.subZoneToParentZone"])
    parent.update(blocks["ZoneDB.private.subZoneToParentZoneOverride"])

    def to_map(area):
        seen = set()
        while area in parent and area not in seen and parent[area] != area:
            seen.add(area)
            area = parent[area]
        return area_to_map.get(area)
    return to_map


def spawn_zones(spawns, to_map):
    out = set()
    for area in (spawns or {}):
        ui_map = to_map(area)
        if ui_map in ZONES:
            out.add(ui_map)
    return out


# ---------------------------------------------------------------------------
# Créatures
# ---------------------------------------------------------------------------
def creature_reason(npc_id, row, keys):
    """None si la créature entre au bestiaire, sinon la raison de l'exclusion."""
    name = row.get(keys["name"]) or ""
    faction = row.get(keys["factionID"])
    friendly = row.get(keys["friendlyToFaction"])
    sub_name = row.get(keys["subName"]) or ""
    if not name:
        return "sans nom"
    if npc_id in ERA_BLACKLIST:
        return "liste noire Questie"
    if TECHNICAL.search(name):
        return "technique"
    if SEASONAL.search(name) or SEASONAL.search(sub_name) or faction in SEASONAL_FACTIONS:
        return "saisonnier"
    if faction in CRITTER_FACTIONS or (faction == 7 and name in CRITTER_NAMES_FACTION_7):
        return "bestiole"
    if friendly == "AH" and faction not in NEUTRAL_COMBAT_FACTIONS:
        return "amical envers les deux"
    if friendly is not None and (row.get(keys["npcFlags"]) or sub_name
                                 or row.get(keys["questStarts"]) or row.get(keys["questEnds"])):
        # PNJ de service (marchand, maître de vol, donneur de quête, titre) :
        # pas une cible de combat, même pour la faction adverse
        return "PNJ de service"
    if friendly in ("A", "H") and (row.get(keys["maxLevel"]) or 0) <= 1:
        # civils de niveau 1 d'une faction (enfants de Comté-de-l'Or, paysans,
        # chiens de ferme, essaims) : pas des cibles, même pour l'adversaire
        return "civil de faction"
    if (row.get(keys["maxLevel"]) or 0) <= 0:
        return "niveau inconnu"
    return None


def build_creatures(root, to_map):
    blocks, text = lua_blocks(os.path.join(root, "data/Classic/classicNpcDB.lua"))
    keys = lua_keys(text, "QuestieDB.npcKeys")
    data = blocks["QuestieDB.npcData"]
    fr_blocks, _ = lua_blocks(os.path.join(root, "l10n/Classic/lookupNpcs/frFR.lua"))
    fr = next(iter(fr_blocks.values()))
    zones, reasons = {}, {}
    for npc_id, row in data.items():
        where = spawn_zones(row.get(keys["spawns"]), to_map)
        if not where:
            continue
        reason = creature_reason(npc_id, row, keys)
        if reason:
            reasons[reason] = reasons.get(reason, 0) + 1
            continue
        en = row[keys["name"]]
        fr_entry = fr.get(npc_id)
        fr_name = (fr_entry.get(1) if isinstance(fr_entry, dict) else fr_entry) or en
        lo = row.get(keys["minLevel"]) or row.get(keys["maxLevel"])
        hi = row.get(keys["maxLevel"]) or lo
        lo, hi = min(lo, hi), max(lo, hi)
        friendly = row.get(keys["friendlyToFaction"])
        entry = (lo, hi, row.get(keys["rank"]) or 0, fr_name, en, friendly if friendly in ("A", "H") else None)
        for ui_map in where:
            zones.setdefault(ui_map, {})[npc_id] = entry
    return zones, reasons


# ---------------------------------------------------------------------------
# Récolte
# ---------------------------------------------------------------------------
def build_gathering(root, to_map, known_items):
    blocks, text = lua_blocks(os.path.join(root, "data/Classic/classicObjectDB.lua"))
    keys = lua_keys(text, "QuestieDB.objectKeys")
    data = blocks["QuestieDB.objectData"]
    for name, items in NODES.items():
        for item in items:
            if item not in known_items:
                raise SystemExit("ERREUR : %s -> itemID %d absent de GatheringData.lua" % (name, item))
    names_found, zones = set(), {}
    for row in data.values():
        name = row.get(keys["name"])
        items = NODES.get(name)
        if not items:
            continue
        where = spawn_zones(row.get(keys["spawns"]), to_map)
        if where:
            names_found.add(name)
        for ui_map in where:
            zones.setdefault(ui_map, set()).update(items)
    missing = sorted(set(NODES) - names_found)
    return zones, missing


# ---------------------------------------------------------------------------
# Écriture
# ---------------------------------------------------------------------------
def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def header(filename, what, meta):
    return "\n".join([
        "-- %s -- %s (v1.25.0)" % (filename, what),
        "--",
        "-- FICHIER GÉNÉRÉ par tools/gen_zone_data.py, ne pas éditer à la main :",
        "-- relance le script (voir son en-tête) pour le refaire.",
        "-- Source : base de données de Questie, dépôt GitHub Questie/QuestieDB",
        "--   (branche master, commit %s)," % meta["commit"],
        "--   données importées de Questie/Questie (Questie %s). Générée le %s." % (meta["questie"], meta["date"]),
        "-- Licence : GPL-3.0 (https://www.gnu.org/licenses/gpl-3.0.html), comme la",
        "--   base de Questie dont ces données dérivent ; voir NOTICE.md.",
        "-- Generated by tools/gen_zone_data.py, do not edit by hand; data derived",
        "-- from Questie's database (GPL-3.0).",
        "",
    ])


def write_creatures(path, zones, meta):
    out = [header("ZoneCreatures.lua", "créatures de chaque zone, préremplies", meta)]
    out.append("\n".join([
        "-- ns.ZONE_CREATURES[uiMapID][npcID] = { lvl = { min, max }, rank = n, fr = \"…\", en = \"…\", f = … }",
        "--   rank : 0 normal, 1 élite, 2 rare élite, 3 boss, 4 rare (codage cmangos de Questie) ;",
        "--   f    : \"A\" / \"H\" = amicale envers l'Alliance / la Horde (exclue pour cette",
        "--          faction), nil = hostile ou neutre envers les deux.",
        "-- Créatures combattables en extérieur : ni bestioles, ni PNJ techniques, ni PNJ",
        "-- amicaux envers les deux factions, ni événements saisonniers (voir le script).",
        "local ADDON, ns = ...",
        "",
        "local function C(lo, hi, rank, fr, en, f)",
        "\treturn { lvl = { lo, hi }, rank = rank, fr = fr, en = en, f = f }",
        "end",
        "",
        "local Z = {}",
        "ns.ZONE_CREATURES = Z",
        "",
    ]))
    for ui_map in sorted(zones):
        out.append("-- %s" % ZONES[ui_map])
        out.append("Z[%d] = {" % ui_map)
        for npc_id in sorted(zones[ui_map]):
            lo, hi, rank, fr, en, f = zones[ui_map][npc_id]
            args = "%d,%d,%d,%s,%s" % (lo, hi, rank, lua_string(fr), lua_string(en))
            if f:
                args += ',"%s"' % f
            out.append("[%d]=C(%s)," % (npc_id, args))
        out.append("}")
    out.append("")
    out.append('if ns.Mark then ns.Mark("ZoneCreatures") end')
    out.append("")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(out))


def write_gathering(path, zones, meta):
    out = [header("ZoneGathering.lua", "herbes et minerais de chaque zone, préremplis", meta)]
    out.append("\n".join([
        "-- ns.ZONE_GATHERING[uiMapID] = { [itemID] = true } : herbes, minerais et pierres du",
        "-- même gisement dont un nœud apparaît dans la zone (itemID de GatheringData.lua).",
        "-- Pas de dépeçage : Questie n'a pas le type des créatures, il reste appris en jouant.",
        "local ADDON, ns = ...",
        "",
        "local function S(...)",
        "\tlocal set = {}",
        "\tfor index = 1, select(\"#\", ...) do set[(select(index, ...))] = true end",
        "\treturn set",
        "end",
        "",
        "ns.ZONE_GATHERING = {",
    ]))
    for ui_map in sorted(zones):
        out.append("\t[%d] = S(%s), -- %s" % (ui_map, ", ".join(str(i) for i in sorted(zones[ui_map])), ZONES[ui_map]))
    out.append("}")
    out.append("")
    out.append('if ns.Mark then ns.Mark("ZoneGathering") end')
    out.append("")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(out))


def git_head(root):
    try:
        with open(os.path.join(root, ".git", "HEAD"), "r") as handle:
            ref = handle.read().strip()
        if ref.startswith("ref: "):
            with open(os.path.join(root, ".git", ref[5:]), "r") as handle:
                return handle.read().strip()
        return ref
    except OSError:
        return None


def main(argv=None):
    parser = argparse.ArgumentParser(description="Génère ZoneCreatures.lua et ZoneGathering.lua depuis QuestieDB.")
    parser.add_argument("questiedb", help="racine de la source QuestieDB (data/, l10n/, support/)")
    parser.add_argument("--commit", help="commit QuestieDB (lu dans .git si absent)")
    parser.add_argument("--questie", default="12.4.0", help="version de Questie correspondante")
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    parser.add_argument("--out", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        help="dossier de l'addon (par défaut : celui du script)")
    parser.add_argument("--verbose", action="store_true", help="liste les créatures exclues, par raison")
    args = parser.parse_args(argv)
    root = args.questiedb
    meta = {"commit": args.commit or git_head(root) or "inconnu", "questie": args.questie, "date": args.date}

    to_map = zone_mapper(root)
    creatures, reasons = build_creatures(root, to_map)
    known = gathering_item_ids(os.path.join(args.out, "GatheringData.lua"))
    gathering, missing = build_gathering(root, to_map, known)

    creatures_path = os.path.join(args.out, "ZoneCreatures.lua")
    gathering_path = os.path.join(args.out, "ZoneGathering.lua")
    write_creatures(creatures_path, creatures, meta)
    write_gathering(gathering_path, gathering, meta)

    species = set()
    for table in creatures.values():
        species.update(table)
    print("Zones (créatures) : %d, lignes : %d, espèces distinctes : %d"
          % (len(creatures), sum(len(t) for t in creatures.values()), len(species)))
    print("Exclues : %s" % ", ".join("%s %d" % kv for kv in sorted(reasons.items())))
    print("Zones (récolte) : %d, paires zone/ressource : %d" % (len(gathering), sum(len(s) for s in gathering.values())))
    if missing:
        print("Nœuds sans apparition en zone extérieure : %s" % ", ".join(missing))
    for path in (creatures_path, gathering_path):
        print("%s : %.1f Ko" % (os.path.basename(path), os.path.getsize(path) / 1024.0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
