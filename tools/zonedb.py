"""Lecture de NOTRE base de données (data/), pour les générateurs.

    import zonedb
    db = zonedb.load("era")          # ou "forever"
    db.entities["npc"]               # (données, clés) : {id: {champ: valeur}}, {champ: champ}
    db.fr["quest"][id]               # nom français
    db.to_map(areaID)                # uiMapID de la zone (sous-zone -> zone), ou None
    db.hidden, db.events             # quêtes cachées, quêtes d'événement saisonnier
    db.meta                          # provenance (source.json)

Les tables Lua d'origine sont rendues telles quelles : une liste JSON redevient
une table indexée 1..n, une clé numérique redevient un nombre.

Corrections faites à la main : data/<client>/fixes.json, appliquées après
lecture, jamais écrasées par un nouvel import (tools/import_questie.py) :
    {
      "npc":    { "<id>": { "<champ>": valeur, "<autre>": null } },
      "object": { ... },
      "quest":  { ... }
    }
Une valeur remplace celle de la base, null retire le champ, un identifiant
inconnu crée l'entité. Les clés commençant par « _ » sont des commentaires.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
FILES = {"npc": "npcs.jsonl", "object": "objects.jsonl", "quest": "quests.jsonl"}


def from_json(value):
    """JSON -> table Lua (dict Python) : liste -> {1: …, n: …}, clé « 12 » -> 12."""
    if isinstance(value, list):
        return {index + 1: from_json(item) for index, item in enumerate(value)}
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            if isinstance(key, str) and key.lstrip("-").isdigit():
                key = int(key)
            out[key] = from_json(item)
        return out
    return value


class Database(object):
    pass


def apply_fixes(entities, fr, path):
    if not os.path.exists(path):
        return 0
    with open(path, encoding="utf-8") as handle:
        fixes = json.load(handle)
    count = 0
    for kind, by_id in fixes.items():
        if kind.startswith("_") or kind not in entities:
            continue
        data = entities[kind][0]
        for raw_id, fields in by_id.items():
            if raw_id.startswith("_"):
                continue
            entity_id = int(raw_id)
            row = data.setdefault(entity_id, {})
            for field, value in fields.items():
                if field.startswith("_"):
                    continue
                if field == "name_fr":
                    if value is None:
                        fr[kind].pop(entity_id, None)
                    else:
                        fr[kind][entity_id] = value
                elif field in ("hidden", "event"):
                    row[field] = value
                elif value is None:
                    row.pop(field, None)
                else:
                    row[field] = from_json(value)
                count += 1
    return count


def load(client):
    folder = os.path.join(DATA, client)
    db = Database()
    db.entities, db.fr = {}, {}
    for kind, filename in FILES.items():
        data, names, fr = {}, set(), {}
        with open(os.path.join(folder, filename), encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                record = json.loads(line)
                entity_id = record.pop("id")
                name_fr = record.pop("name_fr", None)
                if name_fr:
                    fr[entity_id] = name_fr
                row = {}
                for field, value in record.items():
                    row[field] = value if field in ("hidden", "event") else from_json(value)
                    names.add(field)
                data[entity_id] = row
        db.fr[kind] = fr
        db.entities[kind] = (data, {})
    db.fixes = apply_fixes(db.entities, db.fr, os.path.join(folder, "fixes.json"))
    # clés : chaque champ s'appelle par son nom (les générateurs font row.get(keys["name"]))
    for kind in db.entities:
        data, _ = db.entities[kind]
        fields = set()
        for row in data.values():
            fields.update(row)
        db.entities[kind] = (data, KeyNames(fields))
    quests = db.entities["quest"][0]
    db.hidden = {qid for qid, row in quests.items() if row.get("hidden")}
    db.events = {qid for qid, row in quests.items() if row.get("event")}

    with open(os.path.join(folder, "zones.json"), encoding="utf-8") as handle:
        zones = json.load(handle)
    area_to_map = {int(k): v for k, v in zones["areaToUiMap"].items()}
    parent = {int(k): v for k, v in zones["subZoneParent"].items()}

    def to_map(area):
        seen = set()
        while area in parent and area not in seen and parent[area] != area:
            seen.add(area)
            area = parent[area]
        return area_to_map.get(area)
    db.to_map = to_map
    db.area_to_map, db.subzone_parent = area_to_map, parent

    with open(os.path.join(folder, "source.json"), encoding="utf-8") as handle:
        db.meta = json.load(handle)
    return db


class KeyNames(dict):
    """keys["champ"] -> "champ" (même un champ absent de toutes les lignes)."""

    def __init__(self, fields):
        dict.__init__(self, {name: name for name in fields})

    def __missing__(self, key):
        return key
