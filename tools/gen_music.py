#!/usr/bin/env python3
"""Juke-box de QuestCompanion (2.12.0) : catalogue des musiques du client.

Deux temps :

1. --fetch (réseau, rare) : relit les tables du client Forever publiées par
   wago.tools et écrit notre base data/forever/music.json.
     ZoneMusic            https://wago.tools/db2/ZoneMusic/csv?build=1.60.1.70753
     ZoneIntroMusicTable  (intros des capitales, moments, intros C60)
     SoundKitEntry        (kit -> FileDataID)
     AreaTable            (zones qui jouent chaque ensemble)
     liste des fichiers   https://wago.tools/api/files?search=sound/music
   Seuls les fichiers que les tables musicales de CE client désignent sont
   retenus (les extensions de retail n'y sont pas, sauf ce que Forever a
   repris pour ses propres zones). Chaque fichier est téléchargé une fois
   (https://wago.tools/api/casc/<FileDataID>) pour lire sa durée et son
   titre ID3 (mutagen) ; le son n'est jamais livré : l'addon ne garde que
   le FileDataID et joue le fichier du client (PlayMusic).

     python3 -I tools/gen_music.py --fetch --cache <dossier> --pylib <dossier de mutagen>

2. sans option : data/forever/music.json -> QuestCompanion/MusicData.lua
   (catégories, noms FR/EN, durées), sans réseau.

     python3 -I tools/gen_music.py
"""
import collections
import concurrent.futures
import csv
import datetime
import io
import json
import os
import re
import ssl
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = "1.60.1.70753"
DATA = os.path.join(ROOT, "data", "forever", "music.json")
OUT = os.path.join(ROOT, "QuestCompanion", "MusicData.lua")
UA = {"User-Agent": "ReadyToQuest-tools"}
DB2 = "https://wago.tools/db2/%s/csv?build=" + BUILD
LISTFILE = "https://wago.tools/api/files?search=sound/music"
CASC = "https://wago.tools/api/casc/%d"

# écran de connexion : le thème de Vanilla (listfile, présent dans SoundKitEntry)
LOGIN = {53223: ("Thème principal de World of Warcraft", "World of Warcraft main theme")}


# Python de python.org sur macOS : pas de certificats racine, ceux du système
CONTEXT = ssl.create_default_context(cafile="/etc/ssl/cert.pem") if os.path.exists("/etc/ssl/cert.pem") else None


def get(url, timeout=120):
    request = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(request, timeout=timeout, context=CONTEXT) as response:
        return response.read()


def table(name):
    return list(csv.DictReader(io.StringIO(get(DB2 % name).decode("utf-8"))))


def probe(fid, cache, MP3):
    """Durée (s) et titre ID3 d'un fichier du client ; mis en cache (JSON)."""
    meta = os.path.join(cache, "%d.json" % fid)
    if os.path.exists(meta):
        return json.load(open(meta, encoding="utf-8"))
    path = os.path.join(cache, "%d.bin" % fid)
    body = get(CASC % fid)
    with open(path, "wb") as handle:
        handle.write(body)
    info = {"bytes": len(body)}
    try:
        audio = MP3(path)
        info["dur"] = round(audio.info.length, 1)
        tags = audio.tags or {}
        if "TIT2" in tags:
            info["title"] = str(tags["TIT2"]).strip()
    except Exception as exc:  # pas un mp3 (ogg ?) : durée inconnue
        info["error"] = type(exc).__name__
    os.remove(path)  # le son ne reste pas sur le disque
    json.dump(info, open(meta, "w", encoding="utf-8"))
    return info


def fetch(cache, pylib):
    sys.path.insert(0, pylib)
    from mutagen.mp3 import MP3
    os.makedirs(cache, exist_ok=True)
    listfile = {int(k): v for k, v in json.loads(get(LISTFILE)).items()}
    kits = collections.defaultdict(list)
    for row in table("SoundKitEntry"):
        kits[int(row["SoundKitID"])].append(int(row["FileDataID"]))
    areas = collections.defaultdict(list)
    for row in table("AreaTable"):
        if row["ZoneMusic"] != "0" and row["ParentAreaID"] == "0":
            areas[int(row["ZoneMusic"])].append(int(row["ID"]))
    tracks = collections.OrderedDict()

    def add(fid, origin, set_name, area_ids):
        track = tracks.setdefault(fid, {"id": fid, "set": set_name, "origin": origin, "areas": []})
        for area in area_ids:
            if area not in track["areas"]:
                track["areas"].append(area)

    for row in table("ZoneMusic"):
        for kit in dict.fromkeys((int(row["Sounds_0"]), int(row["Sounds_1"]))):
            for fid in kits.get(kit, []):
                add(fid, "zone", row["SetName"].strip(), areas.get(int(row["ID"]), []))
    for row in table("ZoneIntroMusicTable"):
        for fid in kits.get(int(row["SoundID"]), []):
            add(fid, "intro", row["Name"].strip(), [])
    for fid in LOGIN:
        add(fid, "login", "Login", [])
    started = datetime.datetime.now()
    with concurrent.futures.ThreadPoolExecutor(6) as pool:
        infos = dict(zip(tracks, pool.map(lambda fid: probe(fid, cache, MP3), tracks)))
    total = 0
    for fid, track in tracks.items():
        info = infos[fid]
        total += info.get("bytes", 0)
        if fid in listfile:
            track["path"] = listfile[fid]
        for key in ("title", "dur"):
            if key in info:
                track[key] = info[key]
    spent = (datetime.datetime.now() - started).total_seconds()
    print("%d fichiers, %.1f Mo lus, %.0f s" % (len(tracks), total / 1e6, spent), file=sys.stderr)
    data = {"source": "wago.tools (tables du client, fichiers CASC)", "build": BUILD,
            "imported": datetime.date.today().isoformat(), "tracks": list(tracks.values())}
    with open(DATA, "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=0)
        handle.write("\n")


# ---------------------------------------------------------------------------
# Catégories et noms
# ---------------------------------------------------------------------------
CATEGORIES = ["zones", "cities", "dungeons", "raids", "taverns", "forever", "moments", "themes"]

# biomes de Vanilla : (motif du nom d'ensemble ou du titre, FR, EN)
BIOMES = [
    ("evilforest|evil forest|darkforest|dark forest", "Forêt maudite", "Evil forest"),
    ("enchantedforest|enchanted forest", "Forêt enchantée", "Enchanted forest"),
    ("cursedland|plaguelands|bone", "Terres maudites", "Cursed land"),
    ("barrendry|barren", "Terres arides", "Barrens"),
    ("forest", "Forêt", "Forest"),
    ("mountain", "Montagne", "Mountain"),
    ("plains", "Plaines", "Plains"),
    ("desert", "Désert", "Desert"),
    ("jungle", "Jungle", "Jungle"),
    ("soggy|swamp", "Marais", "Swamp"),
    ("volcanic", "Volcans", "Volcanic"),
    ("ghost", "Monde des esprits", "Spirit world"),
    ("haunted", "Hanté", "Haunted"),
    ("mystery", "Mystère", "Mystery"),
    ("magic", "Magie", "Magic"),
]
CITIES = [
    ("stormwind|valleyofheros|valley of heroes|kingstheme|southseas", "Hurlevent", "Stormwind"),
    ("orgrimmar|orgrmmar|crossroads|orc barren", "Orgrimmar", "Orgrimmar"),
    ("ironforge|iron forge|dwarf outpost|monestery", "Forgefer", "Ironforge"),
    ("tinkertown", "Brikabrok", "Tinker Town"),
    ("gnomeragon|gnomeregan", "Gnomeregan", "Gnomeregan"),
    ("darnassus|druidgrove|druid grove|warriorterrace|warrior terrace", "Darnassus", "Darnassus"),
    ("thunderbluff", "Les Pitons-du-Tonnerre", "Thunder Bluff"),
    ("undercity", "Fossoyeuse", "Undercity"),
]
# ensembles nommés : (motif, catégorie, FR, EN)
NAMED = [
    ("naxxramas", "raids", "Naxxramas", "Naxxramas"),
    ("ahnqiraj|scarabdais", "raids", "Ahn'Qiraj", "Ahn'Qiraj"),
    ("zulgurub", "raids", "Zul'Gurub", "Zul'Gurub"),
    ("scarlet enclave", "raids", "Enclave Écarlate", "Scarlet Enclave"),
    ("barrowdeeps", "raids", "Profondeurs des Tertres", "Barrow Deeps"),
    ("drownedcity", "dungeons", "Cité engloutie", "Drowned City"),
    ("dalaran", "dungeons", "Dalaran", "Dalaran"),
    ("karazhan crypts", "dungeons", "Cryptes de Karazhan", "Karazhan Crypts"),
    ("shaper", "dungeons", "Terrasse du Façonneur", "The Shaper's Terrace"),
    ("hyjalpast", "dungeons", "Hyjal (passé)", "Hyjal (past)"),
    ("riverglades", "forever", "Riverglades", "Riverglades"),
    ("zephras", "forever", "Île de Zephras", "Zephras Isle"),
    ("hyjal", "forever", "Mont Hyjal", "Mount Hyjal"),
    ("alterac valley|pvp|battlegrounds", "moments", "Champs de bataille", "Battlegrounds"),
    ("darkmoon", "themes", "Foire de Sombrelune", "Darkmoon Faire"),
]
DUNGEON_KINDS = {"undead": ("Mort-vivant", "Undead"), "forest": ("Forêt", "Forest"), "wetlands": ("Paluns", "Wetlands"),
                 "soggy": ("Marais", "Swamp"), "spiders": ("Araignées", "Spiders"), "underground": ("Souterrain", "Underground"),
                 "alpine": ("Alpin", "Alpine"), "battle percussive": ("Combat, percussions", "Battle, percussion"),
                 "battle boss": ("Combat de boss", "Boss battle"), "horror": ("Horreur", "Horror"),
                 "undergroundpercussive": ("Souterrain, percussions", "Underground, percussion"), "ruins": ("Ruines", "Ruins")}
MOMENTS = {"angelic": ("Angélique", "Angelic"), "sacred": ("Sacré", "Sacred"), "spooky": ("Sinistre", "Spooky"),
           "gloomy": ("Morose", "Gloomy"), "battle": ("Bataille", "Battle"), "swamp": ("Marais", "Swamp")}


def match(patterns, text):
    for entry in patterns:
        if re.search(entry[0], text):
            return entry
    return None


def classify(track):
    """(catégorie, groupe FR, groupe EN) d'une piste."""
    set_name = track["set"].lower()
    path = track.get("path", "").lower()
    title = (track.get("title", "") + " " + path).lower()
    key = set_name + " " + path + " " + title.replace(" ", "").replace("'", "")
    if track["origin"] == "login":
        return "themes", None, None
    if "tavern" in set_name or "restarea" in set_name:
        kinds = [("dwav|dwarf", "naine", "Dwarven"), ("human", "humaine", "Human"), ("pirate", "pirate", "Pirate"),
                 ("undead", "mort-vivante", "Undead"), ("orc|horde", "de la Horde", "Horde"), ("alliance", "de l'Alliance", "Alliance")]
        kind = match(kinds, set_name)
        return "taverns", "Taverne " + kind[1], kind[2] + " tavern"
    named = match(NAMED, key)
    if named:
        return named[1], named[2], named[3]
    # le titre d'abord : certains ensembles mêlent les villes ou les biomes
    city = match(CITIES, title) or match(CITIES, set_name)
    if city:
        return "cities", city[1], city[2]
    if "dungeon" in set_name:
        kind = set_name.split(" - ")[-1].strip()
        fr, en = DUNGEON_KINDS.get(kind, (kind.title(), kind.title()))
        return "dungeons", "Donjon : " + fr.lower(), "Dungeon: " + en.lower()
    if "deadmines" in key or set_name in ("zone-mystery",):
        return "dungeons", "Mystère", "Mystery"
    if set_name.startswith("moment") or "musical moments" in path:
        moment = match([(k,) + v for k, v in MOMENTS.items()], key)
        if moment:
            return "moments", moment[1], moment[2]
    if "cave" in set_name:
        biome = match(BIOMES, set_name)
        return "dungeons", "Grotte : " + biome[1].lower(), "Cave: " + biome[2].lower()
    biome = match(BIOMES, title.replace(" ", "")) or match(BIOMES, key)
    if biome:
        return ("moments" if set_name.startswith("moment") else "zones"), biome[1], biome[2]
    name = track["set"] or track.get("title") or str(track["id"])
    return "moments", name, name


def time_of_day(track):
    text = (track.get("title", "") + " " + track.get("path", "").rsplit("/", 1)[-1]).lower()
    if re.search(r"\bnight|^night|night", text):
        return "nuit", "night"
    if re.search(r"\bday|^day|day", text):
        return "jour", "day"
    if "intro" in text or "intro" in track["set"].lower():
        return "ouverture", "intro"
    return None


def clean(text):
    return re.sub(r"[\t\n|]", " ", text or "").strip()


def build(out_path=OUT):
    data = json.load(open(DATA, encoding="utf-8"))
    groups = collections.OrderedDict()
    seen = set()
    for track in data["tracks"]:
        if track["id"] in seen or track.get("path", "").endswith(".ogg"):
            continue
        seen.add(track["id"])
        cat, fr, en = classify(track)
        # même morceau désigné deux fois (ancien fichier et réencodage C60)
        twin = (cat, re.sub(r"[^a-z0-9]", "", (track.get("title") or "").lower()), int(track.get("dur") or 0))
        if twin[1] and twin in seen:
            continue
        seen.add(twin)
        if track["origin"] == "login":
            fr, en = LOGIN[track["id"]]
        # nouveautés Forever : le lieu est dans le titre (« Farholde Keep A »)
        sub = None
        if cat == "forever" and track.get("title"):
            sub = clean(re.sub(r"^mus[_ ]", "", track["title"], flags=re.I).replace("_", " "))
            if sub.lower().startswith(en.lower() + " "):
                sub = sub[len(en) + 1:]
        tod = time_of_day(track)
        if tod and cat in ("zones", "cities") and not sub:
            fr, en = "%s, %s" % (fr, tod[0]), "%s, %s" % (en, tod[1])
        groups.setdefault((cat, fr, en), []).append((track, sub))
    # nouveautés Forever : rangées par lieu, pas par ensemble du client
    rank = {g: i for i, g in enumerate(groups)}
    order = sorted(groups, key=lambda g: (CATEGORIES.index(g[0]), g[1] if g[0] == "forever" else "", rank[g]))
    group_lines, lines, counts = [], collections.defaultdict(list), collections.Counter()
    for (cat, fr, en) in order:
        tracks = groups[(cat, fr, en)]
        tracks.sort(key=lambda t: (t[1] or "", t[0].get("title") or "", t[0]["id"]))
        areas = sorted({a for t, _ in tracks for a in t["areas"]})[:8]
        group_lines.append("%s\t%s\t%s" % (clean(fr), clean(en) if en != fr else "", ",".join(map(str, areas))))
        for index, (track, sub) in enumerate(tracks, 1):
            suffix = sub or ("%d" % index if len(tracks) > 1 else "")
            dur = int(round(track["dur"])) if track.get("dur") else 0
            title = clean(track.get("title"))
            if title == sub:
                title = ""
            lines[cat].append("%d\t%d\t%d\t%s\t%s" % (track["id"], dur, len(group_lines), suffix, title))
            counts[cat] += 1
    out = io.StringIO()
    w = out.write
    w("-- MusicData.lua -- catalogue du Juke-box (QuestCompanion 2.12.0)\n--\n")
    w("-- FICHIER GÉNÉRÉ par tools/gen_music.py depuis data/forever/music.json, ne\n")
    w("-- pas éditer à la main. Source : %s, client %s,\n" % (data["source"], data["build"]))
    w("-- relevé le %s. Aucun son livré : des FileDataID du client, joués par PlayMusic.\n" % data["imported"])
    w("local ADDON, ns = ...\nif ns.blocked then return end\n\n")
    w("-- Lus en tables à la première ouverture du Juke-box (ns:MusicCatalog, Jukebox.lua),\n")
    w("-- puis libérés. Champs séparés par une tabulation.\n")
    w("-- ns.MUSIC_GROUPS : une ligne par groupe (n° = rang de la ligne) : nom français,\n")
    w("--   nom anglais (vide = le français), zones qui le jouent (AreaID, « , »).\n")
    w("-- ns.MUSIC_RAW[catégorie] : une ligne par piste : FileDataID, durée en s (0 =\n")
    w("--   inconnue), n° du groupe, suffixe du nom (rang ou lieu), titre d'origine (ID3).\n")
    w("ns.MUSIC_CATEGORIES = { %s }\n" % ", ".join('"%s"' % c for c in CATEGORIES if counts[c]))
    w("ns.MUSIC_GROUPS = [[\n%s\n]]\n" % "\n".join(group_lines))
    w("ns.MUSIC_RAW = {\n")
    for cat in CATEGORIES:
        if counts[cat]:
            w("%s = [[\n%s\n]],\n" % (cat, "\n".join(lines[cat])))
    w("}\n\nif ns.Mark then ns.Mark(\"MusicData\") end\n")
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write(out.getvalue())
    known = sum(1 for cat in lines for line in lines[cat] if line.split("\t")[1] != "0")
    print("%d pistes (%d avec durée), %d groupes : %s" % (sum(counts.values()), known, len(group_lines),
          ", ".join("%s %d" % (c, counts[c]) for c in CATEGORIES if counts[c])), file=sys.stderr)


def main(argv):
    if "--fetch" in argv:
        cache = argv[argv.index("--cache") + 1]
        pylib = argv[argv.index("--pylib") + 1] if "--pylib" in argv else ""
        fetch(cache, pylib)
    build()


if __name__ == "__main__":
    main(sys.argv[1:])
