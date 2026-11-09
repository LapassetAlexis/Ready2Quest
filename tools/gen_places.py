#!/usr/bin/env python3
"""Génère Libs/Socle/Places.lua : les lieux sûrs repérés par leurs PNJ de service.

Hubs.lua (tools/gen_hubs.py) connaît les capitales et les villages par le nom
de leur sous-zone. Il manque les petits camps et tout lieu sans sous-zone à
lui. Ici, on les trouve dans NOTRE base (data/forever/npcs.jsonl) : un lieu
sûr est un groupe de PNJ de service amicaux, proches les uns des autres, où
l'on peut se préparer.

Règle (même esprit que les indices appris en jeu, Core.lua, CLUE_STRENGTH) :
    * un aubergiste, un maître de vol ou un banquier suffit ;
    * sinon, au moins 3 PNJ, dont un marchand ET un réparateur ou un
      entraîneur (une ferme avec un marchand et un donneur de quêtes, un PNJ
      isolé sur une route ne comptent pas) ;
    * PNJ techniques et d'événements saisonniers écartés, PNJ hostiles aux
      deux factions ignorés.
Groupes : PNJ à moins de LINK mètres (yards) l'un de l'autre, de proche en
proche. Rayon d'un lieu : son PNJ le plus éloigné du centre, plus MARGIN.

Lit : data/forever/npcs.jsonl, zones.json (zone -> carte), maps.json
(dimensions des cartes, tools/import_client.py). Sortie déterministe.

Usage : python3 -I tools/gen_places.py
"""
import json
import math
import os
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import zonedb  # noqa: E402
from gen_zone_data import TECHNICAL, SEASONAL, SEASONAL_FACTIONS  # noqa: E402

ROOT = os.path.dirname(TOOLS)
OUT = os.path.join(ROOT, "Ready2Quest", "Libs", "Socle", "Places.lua")

LINK = 60          # deux PNJ à moins de 60 m sont du même lieu
MARGIN = 25        # marge autour du PNJ le plus éloigné
MIN_RADIUS, MAX_RADIUS = 35, 160

# npcFlags de Questie (énumération Classic, aussi celle de Forever)
NPC_FLAGS = {"quest": 2, "vendor": 4, "taxi": 8, "trainer": 16, "inn": 128, "bank": 256, "repair": 16384}
# services dans Places.lua (masque)
SERVICE_BITS = {"inn": 1, "taxi": 2, "bank": 4, "vendor": 8, "repair": 16, "trainer": 32, "quest": 64}
STRONG = {"inn", "taxi", "bank"}


def services(flags):
    return {name for name, bit in NPC_FLAGS.items() if flags & bit}


def keep(svc, count):
    if svc & STRONG:
        return True
    return "vendor" in svc and ("repair" in svc or "trainer" in svc) and count >= 3


def faction_of(values):
    """friendlyToFaction des PNJ ("A", "H", "AH") -> faction du lieu."""
    alliance = any(v == "A" for v in values)
    horde = any(v == "H" for v in values)
    if alliance and not horde:
        return "A"
    if horde and not alliance:
        return "H"
    return "N"


def load_scales(client):
    with open(os.path.join(ROOT, "data", client, "maps.json"), encoding="utf-8") as handle:
        maps = json.load(handle)
    # mètres pour 1 % de la carte, en x et en y
    return {int(k): (v["width"] / 100.0, v["height"] / 100.0) for k, v in maps.items()}


def build(client):
    db = zonedb.load(client)
    scales = load_scales(client)
    points = {}
    for npc_id, row in sorted(db.entities["npc"][0].items()):
        flags, friendly = row.get("npcFlags"), row.get("friendlyToFaction")
        if not isinstance(flags, int) or friendly not in ("A", "H", "AH"):
            continue
        svc = services(flags)
        if not svc:
            continue
        name = row.get("name") or ""
        if TECHNICAL.search(name) or SEASONAL.search(name) or SEASONAL.search(row.get("subName") or "") \
                or row.get("factionID") in SEASONAL_FACTIONS:
            continue
        for area, coords in sorted((row.get("spawns") or {}).items()):
            ui_map = db.to_map(area)
            if ui_map not in scales or not isinstance(coords, dict):
                continue
            for xy in coords.values():
                if isinstance(xy, dict) and isinstance(xy.get(1), (int, float)) and xy.get(1) >= 0:
                    points.setdefault(ui_map, []).append((xy[1], xy[2], svc, friendly, npc_id))

    places = {}
    for ui_map, members in sorted(points.items()):
        sx, sy = scales[ui_map]
        parent = list(range(len(members)))

        def find(i):
            while parent[i] != i:
                parent[i] = parent[parent[i]]
                i = parent[i]
            return i
        for i in range(len(members)):
            for j in range(i + 1, len(members)):
                dx = (members[i][0] - members[j][0]) * sx
                dy = (members[i][1] - members[j][1]) * sy
                if dx * dx + dy * dy <= LINK * LINK:
                    parent[find(i)] = find(j)
        groups = {}
        for i, member in enumerate(members):
            groups.setdefault(find(i), []).append(member)
        for group in groups.values():
            svc = set().union(*[m[2] for m in group])
            if not keep(svc, len(group)):
                continue
            cx = sum(m[0] for m in group) / len(group)
            cy = sum(m[1] for m in group) / len(group)
            far = max(math.hypot((m[0] - cx) * sx, (m[1] - cy) * sy) for m in group)
            radius = int(round(min(MAX_RADIUS, max(MIN_RADIUS, far + MARGIN))))
            mask = sum(SERVICE_BITS[s] for s in svc if s in SERVICE_BITS)
            places.setdefault(ui_map, []).append((round(cx, 1), round(cy, 1), radius,
                                                  faction_of({m[3] for m in group}), mask))
    for ui_map in places:
        places[ui_map].sort()
    return places, scales, db.meta


def lua(client_places, scales):
    lines = ["\t\tscale = {"]
    for ui_map in sorted(client_places):
        sx, sy = scales[ui_map]
        lines.append("\t\t\t[%d] = { %s, %s }," % (ui_map, repr(round(sx, 3)), repr(round(sy, 3))))
    lines.append("\t\t},")
    lines.append("\t\tplaces = {")
    for ui_map in sorted(client_places):
        cells = ", ".join('{ %s, %s, %d, "%s", %d }' % (repr(x), repr(y), r, f, s)
                          for x, y, r, f, s in client_places[ui_map])
        lines.append("\t\t\t[%d] = { %s }," % (ui_map, cells))
    lines.append("\t\t},")
    return lines


def main(out_path=OUT):
    out = [
        "-- Places.lua -- GÉNÉRÉ par tools/gen_places.py, ne pas éditer à la main :",
        "-- corrige data/ et relance le script (voir docs/DONNEES.md).",
        "-- Lieux sûrs repérés par leurs PNJ de service (aubergiste, maître de vol,",
        "-- banquier, ou marchand + réparateur ou entraîneur), sur Forever, en",
        "-- complément de Hubs.lua (lieux connus par le nom de leur sous-zone).",
        "-- Source : notre base data/ (PNJ importés de Questie/QuestieDB, GPL-3.0 ;",
        "--   dimensions des cartes : tables du client, wago.tools).",
        "-- ns.PLACE_DATA.forever.scale[uiMapID]  = { mètres pour 1 % en x, en y }",
        "-- ns.PLACE_DATA.forever.places[uiMapID] = { { x %, y %, rayon en mètres,",
        "--     faction \"A\"|\"H\"|\"N\", services }, … }",
        "--   services : 1 auberge, 2 vol, 4 banque, 8 marchand, 16 réparation,",
        "--   32 entraîneur, 64 quêtes.",
        "-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et",
        "-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis",
        "-- python3 tools/sync_socle.py.",
        "local ADDON, ns = ...",
        "",
        'ns.PLACE_DATA = ns.SocleData("PLACE_DATA", function() return {',
    ]
    summary = []
    for client in ("forever",):
        places, scales, meta = build(client)
        out.append("\t%s = {" % client)
        out.extend(lua(places, scales))
        out.append("\t},")
        total = sum(len(v) for v in places.values())
        strong = sum(1 for v in places.values() for p in v if p[4] & 7)
        summary.append("%s : %d lieux sur %d cartes (%d avec auberge, vol ou banque)" % (client, total, len(places),
                                                                                     strong))
    out.append("} end)")
    out.append("")
    out.append('if ns.Mark then ns.Mark("Places") end')
    with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(out) + "\n")
    for line in summary:
        print(line)


if __name__ == "__main__":
    main()
