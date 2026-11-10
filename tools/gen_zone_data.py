#!/usr/bin/env python3
"""Génère les tables de zone de QuestCompanion (créatures, récolte, quêtes)
depuis NOTRE base de données (data/).

Usage :
    python3 -I tools/gen_zone_data.py [--date AAAA-MM-JJ]

Lit, pour WoW Forever (data/forever/) : npcs.jsonl, objects.jsonl,
quests.jsonl, zones.json, source.json, et les corrections faites à la main
(fixes.json, voir docs/DONNEES.md). Aucune autre source : ni Questie, ni réseau.

Sorties (dans QuestCompanion/) :
    ZoneCreatures_Forever.lua   ns.ZONE_CREATURES
    ZoneGathering_Forever.lua   ns.ZONE_GATHERING
    ZoneQuests_Forever.lua      ns.ZONE_QUESTS
Chaque fichier se garde lui-même (ns:IsForeverClient()) : un autre client ne
construit pas ces tables. Sortie déterministe. Les fichiers Lua sont réécrits
en entier : ne les édite pas à la main, corrige data/ et relance ce script.
"""
import argparse
import datetime
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zonedb  # noqa: E402  (lecture de data/, tools/zonedb.py)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _num(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


# Client : dossier de data/ et suffixe des fichiers (Classic Era n'est plus
# généré depuis QuestCompanion 1.2.0)
FLAVORS = {
    "forever": {"name": "Forever", "forever": True},
}

# ---------------------------------------------------------------------------
# Zones visées : uiMapID des zones classiques de type « Zone » (mapType 3),
# hors capitales (1453-1458), instances et champs de bataille. Les 39 de
# ns.ZONE_LEVELS (CompanionChest.lua) + Reflet-de-Lune (1450), seule zone
# extérieure classique absente de ZONE_LEVELS (pas de tranche de niveau).
# Forever ajoute ses zones propres (support/Forever/Zones/uiMapIdToAreaId.lua).
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
FOREVER_ZONES = {
    2482: "Mount Hyjal", 2521: "Zephras Isle", 2524: "Darkspear Islands", 2548: "Riverglades",
    2652: "Shen'dralas",
}


def zones_for(flavor):
    zones = dict(ZONES)
    if flavor["forever"]:
        zones.update(FOREVER_ZONES)
    return zones


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
# PNJ masqués par Questie sur Forever (Expansions.Current = Era, l'énumération
# de Questie pour les clients classiques ; retirés du jeu ou d'événements passés)
QUESTIE_NPC_BLACKLIST = {8001, 13151, 13153, 13154, 13319, 13320, 13377, 13446, 13449, 15799}
# Forever : créatures qu'on ne peut ni tuer ni capturer, relevées en jeu
FOREVER_NPC_EXCLUDE = {
    250921: "Forest Sprite (île de Zephras) : 13 000 PV, disparaît dès qu'on l'attaque (Deklatis, 2026-11-10)",
}

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
    text = read(path)
    return {int(i) for i in re.findall(r"^\s*\[(\d+)\]\s*=\s*R\(", text, re.M)}


def spawn_point(spawns, to_map, ui_map, central=False):
    """2.11.0 : un point d'apparition dans la zone ui_map, en millièmes de la
    carte (x, y entiers 0-999), ou None. central : le point le plus proche du
    centre des apparitions (une créature), sinon le premier (un donneur)."""
    points = []
    for area, coords in (spawns or {}).items():
        if to_map(area) != ui_map or not isinstance(coords, dict):
            continue
        for xy in coords.values():
            if isinstance(xy, dict) and _num(xy.get(1)) and _num(xy.get(2)):
                x, y = float(xy[1]), float(xy[2])
                if 0 <= x <= 100 and 0 <= y <= 100:
                    points.append((x, y))
    if not points:
        return None
    if central and len(points) > 1:
        cx = sum(p[0] for p in points) / len(points)
        cy = sum(p[1] for p in points) / len(points)
        points.sort(key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
    x, y = points[0]
    return min(999, int(round(x * 10))), min(999, int(round(y * 10)))


def spawn_zones(spawns, to_map, zones):
    out = set()
    for area in (spawns or {}):
        ui_map = to_map(area)
        if ui_map in zones:
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
    if not name or not isinstance(name, str):
        return "sans nom"
    if npc_id in QUESTIE_NPC_BLACKLIST:
        return "liste noire Questie"
    if npc_id in FOREVER_NPC_EXCLUDE:
        return "intouchable (Forever)"
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


def fr_name(fr, entity_id, en):
    entry = fr.get(entity_id)
    name = entry.get(1) if isinstance(entry, dict) else entry
    return name if isinstance(name, str) and name else en


def build_creatures(entities, fr, to_map, zones_wanted):
    data, keys = entities["npc"]
    zones, reasons = {}, {}
    for npc_id, row in data.items():
        where = spawn_zones(row.get(keys["spawns"]), to_map, zones_wanted)
        if not where:
            continue
        reason = creature_reason(npc_id, row, keys)
        if reason:
            reasons[reason] = reasons.get(reason, 0) + 1
            continue
        en = row[keys["name"]]
        lo = row.get(keys["minLevel"]) or row.get(keys["maxLevel"])
        hi = row.get(keys["maxLevel"]) or lo
        lo, hi = min(lo, hi), max(lo, hi)
        friendly = row.get(keys["friendlyToFaction"])
        entry = (int(lo), int(hi), int(row.get(keys["rank"]) or 0), fr_name(fr, npc_id, en), en,
                 friendly if friendly in ("A", "H") else None)
        for ui_map in where:
            zones.setdefault(ui_map, {})[npc_id] = entry + (spawn_point(row.get(keys["spawns"]), to_map, ui_map, True),)
    return zones, reasons


# ---------------------------------------------------------------------------
# Récolte
# ---------------------------------------------------------------------------
def build_gathering(entities, to_map, known_items, zones_wanted):
    data, keys = entities["object"]
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
        where = spawn_zones(row.get(keys["spawns"]), to_map, zones_wanted)
        if where:
            names_found.add(name)
        for ui_map in where:
            zones.setdefault(ui_map, set()).update(items)
    missing = sorted(set(NODES) - names_found)
    return zones, missing


# ---------------------------------------------------------------------------
# Quêtes
# ---------------------------------------------------------------------------
QUEST_DAILY, QUEST_WEEKLY, QUEST_MONTHLY = 4096, 32768, 65536
SPECIAL_REPEATABLE = 1
# Catégories (zoneOrSort < 0) jamais ramenées à une zone : événements,
# métiers, champs de bataille et guerres d'événement (src/corrections/enum/quests.lua)
SORT_EVENT = {-404, -402, -378, -376, -375, -374, -370, -369, -366, -364, -41, -22, -21, -1000}
SORT_PROFESSION = {-398, -377, -373, -371, -324, -304, -264, -201, -182, -181, -121, -101, -24}
SORT_PVP = {-25, -368, -365, -241}
# Catégories de classe (QuestSort de Questie) -> masque requiredClasses,
# bit = 2^(classID-1) : guerrier 1, paladin 2, chasseur 3, voleur 4,
# prêtre 5, chaman 7, mage 8, démoniste 9, druide 11
CLASS_SORT_MASK = {-81: 1, -141: 2, -261: 4, -162: 8, -262: 16, -82: 64, -161: 128, -61: 256, -263: 1024}


def bit_set(mask, bit):
    return mask is not None and (int(mask) // bit) % 2 == 1


def quest_starter_zone(row, qk, npcs, objects, to_map, zones_wanted):
    """Zone unique des PNJ / objets qui donnent la quête (catégories), sinon None."""
    started = row.get(qk["startedBy"])
    if not isinstance(started, dict):
        return None
    where = set()
    for slot, (data, keys) in ((1, npcs), (2, objects)):
        ids = started.get(slot)
        if not isinstance(ids, dict):
            continue
        for entity_id in ids.values():
            entity = data.get(entity_id)
            spawns = entity.get(keys["spawns"]) if entity else None
            if not spawns:
                return None  # un donneur sans apparition connue : zone incertaine
            for area in spawns:
                ui_map = to_map(area)
                if ui_map not in zones_wanted:
                    return None  # donneur (aussi) hors des zones extérieures
                where.add(ui_map)
    return next(iter(where)) if len(where) == 1 else None


def quest_giver_point(row, qk, npcs, objects, to_map, ui_map):
    """2.11.0 : où prendre la quête dans sa zone : premier donneur (PNJ, puis
    objet) qui apparaît dans ui_map, son premier point ; None sinon."""
    started = row.get(qk["startedBy"])
    if not isinstance(started, dict):
        return None
    for slot, (data, keys) in ((1, npcs), (2, objects)):
        ids = started.get(slot)
        for entity_id in (ids.values() if isinstance(ids, dict) else ()):
            entity = data.get(entity_id)
            point = entity and spawn_point(entity.get(keys["spawns"]), to_map, ui_map)
            if point:
                return point
    return None


def build_quests(entities, fr, to_map, zones_wanted, hidden, events):
    data, qk = entities["quest"]
    zones, reasons = {}, {}
    via_starter = 0

    def drop(reason):
        reasons[reason] = reasons.get(reason, 0) + 1

    for qid in sorted(data):
        row = data[qid]
        name = row.get(qk["name"])
        if not isinstance(name, str) or not name:
            drop("sans nom")
            continue
        sort = row.get(qk["zoneOrSort"])
        sort = int(sort) if _num(sort) else 0
        if hidden and qid in hidden:
            drop("cachée (liste noire Questie)")
            continue
        if (events and qid in events) or sort in SORT_EVENT:
            drop("événement saisonnier")
            continue
        if bit_set(row.get(qk["specialFlags"]), SPECIAL_REPEATABLE):
            drop("répétable")
            continue
        flags = row.get(qk["questFlags"])
        if bit_set(flags, QUEST_DAILY) or bit_set(flags, QUEST_WEEKLY) or bit_set(flags, QUEST_MONTHLY):
            drop("journalière / hebdomadaire")
            continue
        if row.get(qk["requiredSkill"]) or sort in SORT_PROFESSION:
            drop("métier")
            continue
        if sort in SORT_PVP:
            drop("JcJ / guerre d'événement")
            continue
        if sort > 0:
            ui_map = to_map(sort)
            if ui_map in (1459, 1460, 1461):
                drop("JcJ / guerre d'événement")
                continue
            if ui_map not in zones_wanted:
                drop("hors zone extérieure (capitale, donjon…)")
                continue
        else:
            ui_map = quest_starter_zone(row, qk, entities["npc"], entities["object"], to_map, zones_wanted)
            if ui_map is None:
                drop("catégorie sans zone")
                continue
            via_starter += 1
        level = row.get(qk["questLevel"])
        req = row.get(qk["requiredLevel"])
        races = row.get(qk["requiredRaces"])
        classes = row.get(qk["requiredClasses"])
        # quête rangée dans une catégorie de classe (zoneOrSort < 0) sans
        # requiredClasses : la catégorie dit la classe (ex. 93797, mage)
        if not (_num(classes) and int(classes) > 0) and _num(sort) and int(sort) in CLASS_SORT_MASK:
            classes = CLASS_SORT_MASK[int(sort)]
        ex = set()
        for field in ("exclusiveTo",):
            for other in (row.get(qk[field]) or {}).values() if isinstance(row.get(qk[field]), dict) else ():
                if _num(other) and int(other) > 0 and int(other) != qid:
                    ex.add(int(other))
        for field in ("breadcrumbForQuestId", "nextQuestInChain"):
            other = row.get(qk[field])
            if _num(other) and int(other) > 0 and int(other) != qid:
                ex.add(int(other))
        entry = (int(level) if _num(level) else 0, int(req) if _num(req) else 0,
                 int(races) if _num(races) else 0, int(classes) if _num(classes) else 0,
                 fr_name(fr, qid, name), name, tuple(sorted(ex)))
        zones.setdefault(ui_map, {})[qid] = entry + (quest_giver_point(row, qk, entities["npc"], entities["object"],
                                                                       to_map, ui_map),)
    return zones, reasons, via_starter


# ---------------------------------------------------------------------------
# Écriture
# ---------------------------------------------------------------------------
def compact_field(text):
    """Champ d'une ligne compacte : ni tabulation, ni saut de ligne, jamais vide
    (un champ vide veut dire « comme l'anglais » ou « absent »)."""
    assert text and "\t" not in text and "\n" not in text and "\r" not in text, repr(text)
    return text


def long_string(rows):
    """Chaîne longue Lua [=[ … ]=] : une ligne par entrée, terminée par un saut
    de ligne (le premier saut après l'ouverture est ignoré par Lua)."""
    body = "".join(row + "\n" for row in rows)
    level = 0
    while ("]" + "=" * level + "]") in body or body.endswith("]" + "=" * level):
        level += 1
    eq = "=" * level
    return "[%s[\n%s]%s]" % (eq, body, eq)


def header(filename, what, meta, flavor, layers):
    client = "Forever (WoW Forever 1.60.x)" if flavor["forever"] else "Era (Classic Era 1.15.x)"
    lines = [
        "-- %s -- %s, client %s (v1.25.0)" % (filename, what, client),
        "--",
        "-- FICHIER GÉNÉRÉ par tools/gen_zone_data.py, ne pas éditer à la main :",
        "-- corrige data/%s/ et relance le script (voir docs/DONNEES.md)." % flavor["dir"],
        "-- Source : notre base data/%s/, importée de Questie/QuestieDB" % flavor["dir"],
        "--   (commit %s, %s ; Questie %s) le %s. Générée le %s." % (meta["commit"], meta["data"], meta["questie"],
                                                                   meta["imported"], meta["date"]),
        "-- Couches appliquées : %s." % (" -> ".join(["brut"] + layers)),
        "-- Licence : GPL-3.0 (https://www.gnu.org/licenses/gpl-3.0.html), comme la",
        "--   base de Questie dont ces données dérivent ; voir NOTICE.md.",
        "-- Generated by tools/gen_zone_data.py from data/ (derived from Questie's",
        "-- database, GPL-3.0), do not edit by hand.",
        "local ADDON, ns = ...",
        "if ns.blocked then return end",
        "-- garde de client : seul le client %s construit cette table" % flavor["name"],
        "if ns.IsForeverClient and ns:IsForeverClient() ~= %s then return end" % ("true" if flavor["forever"] else "false"),
        "",
    ]
    return "\n".join(lines)


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def positions(table, what, zones, names):
    """2.11.0 : les points du bouton « Localiser », une chaîne par zone jamais
    lue en tables : « id<TAB>xxxyyy » par ligne (millièmes de la carte, sur
    trois chiffres), cherchée à la demande (ns:ZonePoint, ZoneQuests.lua)."""
    out = [
        "-- ns.%s[uiMapID] = chaîne : une ligne « %s<TAB>xxxyyy » (x, y en millièmes" % (table, what),
        "-- de la carte de la zone) ; lue par ns:ZonePoint (ZoneQuests.lua), jamais découpée.",
        "local P = {}",
    ]
    for ui_map in sorted(zones):
        rows = []
        for entity_id in sorted(zones[ui_map]):
            point = zones[ui_map][entity_id][-1]
            if point:
                rows.append("%d\t%03d%03d" % (entity_id, point[0], point[1]))
        if rows:
            out.append("P[%d] = %s -- %s" % (ui_map, long_string(rows), names[ui_map]))
    out.append("ns.%s = P" % table)
    out.append("")
    return out


def write_creatures(path, zones, meta, flavor, layers, names):
    out = [header(os.path.basename(path), "créatures de chaque zone, préremplies", meta, flavor, layers)]
    out.append("\n".join([
        "-- ns.ZONE_CREATURES[uiMapID][npcID] = { lvl = { min, max }, rank = n, fr = \"…\", en = \"…\", f = … }",
        "--   rank : 0 normal, 1 élite, 2 rare élite, 3 boss, 4 rare (codage cmangos de Questie) ;",
        "--   f    : \"A\" / \"H\" = amicale envers l'Alliance / la Horde (exclue pour cette",
        "--          faction), nil = hostile ou neutre envers les deux.",
        "-- Créatures combattables en extérieur : ni bestioles, ni PNJ techniques, ni PNJ",
        "-- amicaux envers les deux factions, ni événements saisonniers (voir le script).",
        "",
        "-- Chargement paresseux : une chaîne compacte par zone, lue en tables à sa",
        "-- première lecture (ns.LazyZones, Core.lua) ; parcourir avec ns.ZoneIds /",
        "-- ns.ZoneEach, pas pairs. Une ligne par créature, champs séparés par une",
        "-- tabulation : npcID, niveau min, niveau max, rang, nom français (vide =",
        "-- comme l'anglais), nom anglais, puis f s'il y en a un.",
        "",
        "local function Zone(text)",
        "\tlocal zone = {}",
        "\tfor npc, lo, hi, rank, fr, en, f in text:gmatch(\"(%d+)\\t(%-?%d+)\\t(%-?%d+)\\t(%-?%d+)\\t([^\\t\\n]*)\\t([^\\t\\n]*)\\t?([^\\t\\n]*)\\n\") do",
        "\t\tzone[tonumber(npc)] = { lvl = { tonumber(lo), tonumber(hi) }, rank = tonumber(rank),",
        "\t\t\tfr = fr ~= \"\" and fr or en, en = en, f = f ~= \"\" and f or nil }",
        "\tend",
        "\treturn zone",
        "end",
        "",
        "local Z = {}",
        "",
    ]))
    for ui_map in sorted(zones):
        out.append("-- %s" % names[ui_map])
        rows = []
        for npc_id in sorted(zones[ui_map]):
            lo, hi, rank, fr, en, f, _point = zones[ui_map][npc_id]
            fields = ["%d" % npc_id, "%d" % lo, "%d" % hi, "%d" % rank,
                      "" if fr == en else compact_field(fr), compact_field(en)]
            if f:
                fields.append(compact_field(f))
            rows.append("\t".join(fields))
        out.append("Z[%d] = %s" % (ui_map, long_string(rows)))
    out.append("")
    out.append("ns.ZONE_CREATURES = ns.LazyZones(Z, Zone)")
    out.append("")
    out.extend(positions("ZONE_CREATURE_POS", "npcID", zones, names))
    out.append('if ns.Mark then ns.Mark("ZoneCreatures") end')
    out.append("")
    write(path, "\n".join(out))


def write_gathering(path, zones, meta, flavor, layers, names):
    out = [header(os.path.basename(path), "herbes et minerais de chaque zone, préremplis", meta, flavor, layers)]
    out.append("\n".join([
        "-- ns.ZONE_GATHERING[uiMapID] = { [itemID] = true } : herbes, minerais et pierres du",
        "-- même gisement dont un nœud apparaît dans la zone (itemID de GatheringData.lua).",
        "-- Pas de dépeçage : Questie n'a pas le type des créatures, il reste appris en jouant.",
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
        out.append("\t[%d] = S(%s), -- %s" % (ui_map, ", ".join(str(i) for i in sorted(zones[ui_map])), names[ui_map]))
    out.append("}")
    out.append("")
    out.append('if ns.Mark then ns.Mark("ZoneGathering") end')
    out.append("")
    write(path, "\n".join(out))


def write_quests(path, zones, meta, flavor, layers, names):
    out = [header(os.path.basename(path), "quêtes de chaque zone", meta, flavor, layers)]
    out.append("\n".join([
        "-- ns.ZONE_QUESTS[uiMapID][questID] = { lvl = n, req = n, races = masque, classes = masque,",
        "--                                     fr = \"…\", en = \"…\", ex = { questID, … } }",
        "--   lvl / req : niveau de la quête / niveau requis (0 = inconnu ; -1 = au niveau du joueur) ;",
        "--   races     : masque requiredRaces de Questie (0 = toutes) ; bit de la race = 2^(raceID-1),",
        "--               sauf Forever : Skyborne Alliance (95) = 2^32, Skyborne Horde (96) = 2^33 ;",
        "--   classes   : masque requiredClasses (0 = toutes), bit = 2^(classID-1) ;",
        "--   ex        : quêtes qui ferment celle-ci une fois faites (exclusiveTo, et la suite",
        "--               d'une quête d'approche : breadcrumbForQuestId, nextQuestInChain).",
        "-- Zone : zoneOrSort (areaID, sous-zone ramenée à sa zone) ; catégorie (zoneOrSort < 0) :",
        "--   zone unique des donneurs. Exclues : quêtes cachées par Questie, d'événement",
        "--   saisonnier, répétables, journalières / hebdomadaires, de métier, JcJ (voir le script).",
        "",
        "-- Chargement paresseux : une chaîne compacte par zone, lue en tables à sa",
        "-- première lecture (ns.LazyZones, Core.lua) ; parcourir avec ns.ZoneIds /",
        "-- ns.ZoneEach, pas pairs. Une ligne par quête, champs séparés par une",
        "-- tabulation : questID, lvl, req, races, classes, nom français (vide =",
        "-- comme l'anglais), nom anglais, puis ex (« id,id,… ») s'il y en a.",
        "",
        "local function Zone(text)",
        "\tlocal zone = {}",
        "\tfor qid, lvl, req, races, classes, fr, en, ex in text:gmatch(\"(%d+)\\t(%-?%d+)\\t(%-?%d+)\\t(%d+)\\t(%d+)\\t([^\\t\\n]*)\\t([^\\t\\n]*)\\t?([^\\t\\n]*)\\n\") do",
        "\t\tlocal list",
        "\t\tif ex ~= \"\" then",
        "\t\t\tlist = {}",
        "\t\t\tfor id in ex:gmatch(\"%d+\") do list[#list + 1] = tonumber(id) end",
        "\t\tend",
        "\t\tzone[tonumber(qid)] = { lvl = tonumber(lvl), req = tonumber(req), races = tonumber(races),",
        "\t\t\tclasses = tonumber(classes), fr = fr ~= \"\" and fr or en, en = en, ex = list }",
        "\tend",
        "\treturn zone",
        "end",
        "",
        "local Z = {}",
        "",
    ]))
    for ui_map in sorted(zones):
        out.append("-- %s" % names[ui_map])
        rows = []
        for qid in sorted(zones[ui_map]):
            lvl, req, races, classes, fr, en, ex, _point = zones[ui_map][qid]
            assert races >= 0 and classes >= 0 and all(int(i) > 0 for i in (ex or []))
            fields = ["%d" % qid, "%d" % lvl, "%d" % req, "%d" % races, "%d" % classes,
                      "" if fr == en else compact_field(fr), compact_field(en)]
            if ex:
                fields.append(",".join(str(i) for i in ex))
            rows.append("\t".join(fields))
        out.append("Z[%d] = %s" % (ui_map, long_string(rows)))
    out.append("")
    out.append("ns.ZONE_QUESTS = ns.LazyZones(Z, Zone)")
    out.append("")
    out.extend(positions("ZONE_QUEST_POS", "questID", zones, names))
    out.append('if ns.Mark then ns.Mark("ZoneQuests_%s") end' % flavor["name"])
    out.append("")
    write(path, "\n".join(out))


def generate(flavor_key, args):
    flavor = dict(FLAVORS[flavor_key], dir=flavor_key)
    db = zonedb.load(flavor_key)
    meta = dict(db.meta, date=args.date)
    entities, to_map = db.entities, db.to_map
    zones_wanted = zones_for(flavor)
    suffix = flavor["name"]

    creatures, c_reasons = build_creatures(entities, db.fr["npc"], to_map, zones_wanted)
    known = gathering_item_ids(os.path.join(args.out, "GatheringData.lua"))
    gathering, missing = build_gathering(entities, to_map, known, zones_wanted)
    quests, q_reasons, via_starter = build_quests(entities, db.fr["quest"], to_map, zones_wanted, db.hidden, db.events)

    paths = [os.path.join(args.out, "ZoneCreatures_%s.lua" % suffix),
             os.path.join(args.out, "ZoneGathering_%s.lua" % suffix),
             os.path.join(args.out, "ZoneQuests_%s.lua" % suffix)]
    layers = db.meta["layers"]
    write_creatures(paths[0], creatures, meta, flavor, layers["npc"], zones_wanted)
    write_gathering(paths[1], gathering, meta, flavor, layers["object"], zones_wanted)
    write_quests(paths[2], quests, meta, flavor, layers["quest"], zones_wanted)

    print("== %s ==" % suffix)
    if db.fixes:
        print("  corrections de data/%s/fixes.json : %d" % (flavor_key, db.fixes))
    species = set()
    for table in creatures.values():
        species.update(table)
    print("  Créatures : %d zones, %d lignes, %d espèces" % (len(creatures), sum(len(t) for t in creatures.values()),
                                                          len(species)))
    print("  Exclues : %s" % ", ".join("%s %d" % kv for kv in sorted(c_reasons.items())))
    print("  Récolte : %d zones, %d paires zone/ressource" % (len(gathering), sum(len(s) for s in gathering.values())))
    if missing:
        print("  Nœuds sans apparition en zone extérieure : %s" % ", ".join(missing))
    kept = sum(len(t) for t in quests.values())
    print("  Quêtes : %d gardées dans %d zones (dont %d par la zone du donneur), sur %d"
          % (kept, len(quests), via_starter, len(entities["quest"][0])))
    print("  Quêtes exclues : %s" % ", ".join("%s %d" % kv for kv in sorted(q_reasons.items())))
    for path in paths:
        print("  %s : %.1f Ko" % (os.path.basename(path), os.path.getsize(path) / 1024.0))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Génère les tables de zone de QuestCompanion depuis data/.")
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    parser.add_argument("--out", default=os.path.join(ROOT, "QuestCompanion"),
                        help="dossier de l'addon (par défaut : QuestCompanion/ du dépôt)")
    args = parser.parse_args(argv)
    # QuestCompanion 1.2.0 : WoW Forever seulement (les tables d'Era ne sont plus livrées)
    for key in FLAVORS:
        generate(key, args)


if __name__ == "__main__":
    main()
