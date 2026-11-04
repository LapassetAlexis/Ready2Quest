#!/usr/bin/env python3
"""Importe des tables du client WoW dans NOTRE base de données (data/).

Tables du jeu publiées par wago.tools (extraites des fichiers du client), pour
chaque client :
    AreaTable        -> data/<client>/areas.jsonl  zones et sous-zones : nom
                        anglais, zone parente, continent, drapeaux (0x100 =
                        capitale)
    UiMapAssignment  -> data/<client>/maps.json    étendue de chaque carte de
                        zone, en mètres du jeu (yards) : sert à mesurer une
                        distance à partir de coordonnées de carte (0-100 %)
Provenance (builds, date) : data/<client>/client.json.

Usage :
    python3 -I tools/import_client.py [--from DOSSIER] [--date AAAA-MM-JJ]
Sans --from, les CSV sont téléchargés sur wago.tools ; avec --from, ils sont
lus dans DOSSIER (AreaTable_<build>.csv, UiMapAssignment_<build>.csv).
Sortie déterministe.
"""
import argparse
import csv
import datetime
import io
import json
import os
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
BUILDS = {"era": "1.15.9.70576", "forever": "1.60.1.70753"}
URL = "https://wago.tools/db2/%s/csv?build=%s"


def fetch(table, build, folder):
    if folder:
        with open(os.path.join(folder, "%s_%s.csv" % (table, build)), encoding="utf-8") as handle:
            return list(csv.DictReader(handle))
    request = urllib.request.Request(URL % (table, build), headers={"User-Agent": "Ready2Quest-data-import"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return list(csv.DictReader(io.StringIO(response.read().decode("utf-8"))))


def export(client, folder, date):
    build = BUILDS[client]
    out = os.path.join(DATA, client)
    os.makedirs(out, exist_ok=True)
    areas = fetch("AreaTable", build, folder)
    rows = []
    for row in sorted(areas, key=lambda r: int(r["ID"])):
        record = {"id": int(row["ID"]), "name": row["AreaName_lang"], "zone": row["ZoneName"],
                  "parent": int(row["ParentAreaID"] or 0), "continent": int(row["ContinentID"] or 0),
                  "flags": int(row["Flags_0"] or 0)}
        rows.append(record)
    with open(os.path.join(out, "areas.jsonl"), "w", encoding="utf-8", newline="\n") as handle:
        for record in rows:
            handle.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")

    maps = {}
    for row in fetch("UiMapAssignment", build, folder):
        # une carte de zone entière : coordonnées 0..1 sur toute la carte
        if float(row["UiMin_0"]) != 0 or float(row["UiMin_1"]) != 0 or float(row["UiMax_0"]) != 1 \
                or float(row["UiMax_1"]) != 1:
            continue
        ui_map = int(row["UiMapID"])
        x0, y0 = float(row["Region_0"]), float(row["Region_1"])
        x1, y1 = float(row["Region_3"]), float(row["Region_4"])
        # carte : x (gauche -> droite) suit -Y du monde, y (haut -> bas) suit -X
        maps[str(ui_map)] = {"area": int(row["AreaID"]), "width": round(y1 - y0, 2), "height": round(x1 - x0, 2)}
    with open(os.path.join(out, "maps.json"), "w", encoding="utf-8", newline="\n") as handle:
        json.dump(dict(sorted(maps.items(), key=lambda kv: int(kv[0]))), handle, ensure_ascii=False, indent=0)
        handle.write("\n")
    with open(os.path.join(out, "client.json"), "w", encoding="utf-8", newline="\n") as handle:
        json.dump({"source": "wago.tools (tables du client)", "build": build, "imported": date,
                   "tables": ["AreaTable", "UiMapAssignment"], "areas": len(rows), "maps": len(maps)},
                  handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print("data/%s : %d zones et sous-zones, %d cartes de zone (build %s)" % (client, len(rows), len(maps), build))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Importe AreaTable et UiMapAssignment dans data/.")
    parser.add_argument("--from", dest="folder", help="dossier des CSV déjà téléchargés")
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    args = parser.parse_args(argv)
    for client in ("era", "forever"):
        export(client, args.folder, args.date)


if __name__ == "__main__":
    main()
