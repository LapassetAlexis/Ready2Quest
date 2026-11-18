#!/usr/bin/env python3
"""Noms espagnols du jeu (socle 3.6, client esES / esMX).

Le client espagnol dit déjà presque tout dans sa langue (objets, sorts, zones
du jeu). Restent les noms que NOS tables gardent en français et en anglais
pour les cas où le client ne les connaît pas encore : créatures
(ZoneCreatures_Forever.lua), quêtes (ZoneQuests_Forever.lua), objets de récolte
(GatheringData.lua), sous-zones de l'histoire des lieux (LoreData).

  python3 -I tools/gen_names_es.py import <dossier Questie l10n> <AreaTable esES.csv> <AreaTable esMX.csv> <AreaTable enUS.csv>
      -> data/forever/names_es.json (notre base : seulement les identifiants
         dont nos tables se servent ; [esES, esMX] quand ils diffèrent)
  python3 -I tools/gen_names_es.py lua
      -> QuestCompanion/NamesES.lua

Sources : Questie/QuestieDB (GPL-3.0), l10n/Forever/lookup{Npcs,Quests,Items}/
esES.lua et esMX.lua, au commit de data/forever/source.json ; tables du client
(AreaTable, wago.tools) pour les noms de lieux.
"""
import csv
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data", "forever", "names_es.json")
QC = os.path.join(ROOT, "QuestCompanion")


def used_ids():
    ids = {"npc": set(), "quest": set(), "item": set(), "area": set()}
    for kind, name in (("npc", "ZoneCreatures_Forever.lua"), ("quest", "ZoneQuests_Forever.lua")):
        text = open(os.path.join(QC, name), encoding="utf-8").read()
        for m in re.finditer(r"^(\d+)\t", text, re.M):
            ids[kind].add(int(m.group(1)))
    text = open(os.path.join(QC, "GatheringData.lua"), encoding="utf-8").read()
    for m in re.finditer(r"\[(\d+)\]\s*=\s*R\(", text):
        ids["item"].add(int(m.group(1)))
    # sous-zones de l'histoire des lieux : areaID dont le nom anglais
    # normalisé est la clé de l'entrée, dans la zone de l'entrée
    lore = json.load(open(os.path.join(ROOT, "data", "forever", "lore", "lore.json"), encoding="utf-8"))
    keys = {e["key"] for entries in lore["subzones"].values() for e in entries}
    for line in open(os.path.join(ROOT, "data", "forever", "areas.jsonl"), encoding="utf-8"):
        area = json.loads(line)
        if normalise(area.get("name", "")) in keys:
            ids["area"].add(area["id"])
    return ids


def normalise(name):
    s = name.lower()
    s = re.sub(r"^the\s+", "", s).replace("'", "").replace("’", "")
    s = re.sub(r"[^a-z0-9]+", " ", s).strip()
    return s


def questie(folder, kind, loc):
    path = os.path.join(folder, "%s-%s.lua" % (kind, loc))
    text = open(path, encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'^\[(\d+)\] = \{?"((?:[^"\\]|\\.)*)"', text, re.M):
        out[int(m.group(1))] = m.group(2).replace('\\"', '"').replace("\\\\", "\\")
    return out


def areas(path):
    out = {}
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            name = row.get("AreaName_lang") or ""
            if name:
                out[int(row["ID"])] = name
    return out


def do_import(folder, es_csv, mx_csv, en_csv=None):
    ids = used_ids()
    result = {}
    for kind, lookup in (("npc", "lookupNpcs"), ("quest", "lookupQuests"), ("item", "lookupItems")):
        es, mx = questie(folder, lookup, "esES"), questie(folder, lookup, "esMX")
        result[kind] = {}
        for i in sorted(ids[kind]):
            a, b = es.get(i), mx.get(i)
            if a or b:
                result[kind][str(i)] = [a or b] if (a or b) == (b or a) else [a or b, b or a]
    es, mx = areas(es_csv), areas(mx_csv)
    # les tables du client actuel ont renommé quelques lieux depuis Classic
    # (Gnomeregan -> New Tinkertown) : un nom espagnol ne vaut que si le nom
    # anglais de la même table est encore celui de Forever (data/forever/areas.jsonl)
    en = areas(en_csv) if en_csv else {}
    forever = {}
    for line in open(os.path.join(ROOT, "data", "forever", "areas.jsonl"), encoding="utf-8"):
        area = json.loads(line)
        forever[area["id"]] = area.get("name", "")
    result["area"] = {}
    for i in sorted(ids["area"]):
        if en and normalise(en.get(i, "")) != normalise(forever.get(i, "")):
            continue
        a, b = es.get(i), mx.get(i)
        if a or b:
            result["area"][str(i)] = [a or b] if (a or b) == (b or a) else [a or b, b or a]
    result["_source"] = {"questie": json.load(open(os.path.join(ROOT, "data", "forever", "source.json")))["commit"],
                         "areas": "wago.tools AreaTable esES / esMX"}
    with open(DATA, "w", encoding="utf-8", newline="\n") as f:
        json.dump(result, f, ensure_ascii=False, indent=0, sort_keys=True)
        f.write("\n")
    for kind in ("npc", "quest", "item", "area"):
        print("%s : %d noms (sur %d utilisés)" % (kind, len(result[kind]), len(ids[kind])))


HEAD = """-- NamesES.lua -- noms espagnols des créatures, quêtes et objets de nos tables
--
-- FICHIER GÉNÉRÉ par tools/gen_names_es.py depuis data/forever/names_es.json,
-- ne pas éditer à la main. Source : Questie/QuestieDB (GPL-3.0, voir
-- NOTICE.md), l10n/Forever esES et esMX. Seul un client espagnol garde ces
-- noms ; le Mexique prend son nom quand il diffère (deuxième colonne).
-- ns.SpanishName(kind, id) : "npc" | "quest" | "item" -> nom, ou nil.
local ADDON, ns = ...
if ns.blocked then return end
if not (ns.STRINGS_SPANISH or ns.KEEP_STRINGS) then return end

local MX = rawget(_G, "GetLocale") and GetLocale() == "esMX"
local RAW = {
"""

TAIL = """}
if ns.KEEP_STRINGS then ns.NAMES_ES_RAW = RAW end
if not ns.STRINGS_SPANISH then return end

-- lu en table à la première demande de chaque sorte, puis la chaîne est libérée
local names = {}
function ns.SpanishName(kind, id)
	local list = names[kind]
	if not list then
		list = {}
		for nid, es, mx in (RAW[kind] or ""):gmatch("(%d+)\\t([^\\t\\n]*)\\t?([^\\t\\n]*)\\n") do
			list[tonumber(nid)] = (MX and mx ~= "") and mx or es
		end
		names[kind], RAW[kind] = list, nil
	end
	return list[tonumber(id)]
end

if ns.Mark then ns.Mark("NamesES") end
"""


def do_lua():
    data = json.load(open(DATA, encoding="utf-8"))
    parts = [HEAD]
    for kind in ("npc", "quest", "item"):
        rows = []
        for i in sorted(data[kind], key=int):
            names = data[kind][i]
            rows.append("%s\t%s\t%s" % (i, names[0], names[1] if len(names) > 1 else ""))
        body = "\n".join(rows)
        assert "]]" not in body
        parts.append("\t%s = [[\n%s\n]],\n" % (kind, body))
    parts.append(TAIL)
    path = os.path.join(QC, "NamesES.lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(parts))
    print("%s : %.1f Ko" % (path, os.path.getsize(path) / 1024))


def main():
    if len(sys.argv) >= 5 and sys.argv[1] == "import":
        do_import(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else None)
    elif len(sys.argv) >= 2 and sys.argv[1] == "lua":
        do_lua()
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
