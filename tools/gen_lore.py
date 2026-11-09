#!/usr/bin/env python3
"""gen_lore.py -- histoire des lieux du compagnon (QuestCompanion 2.13.0).

Deux temps :
  python3 -I tools/gen_lore.py --fetch [--cache DIR]
      télécharge, au commit épinglé, les données de Spoken_Places
      (github.com/rusty-key/spoken-wow, addons/Spoken_Places/Data) et écrit
      l'instantané réduit data/forever/lore/lore.json (seulement ce qui sert) ;
  python3 -I tools/gen_lore.py
      écrit QuestCompanion/LoreData.lua depuis cet instantané (vérifié par
      tests/run_tests.py, comme les autres fichiers générés).

Licences : le code de Spoken est sous MIT ; les textes des lieux viennent de
Warcraft Wiki (warcraft.wiki.gg), sous CC BY-SA 4.0. Les phrases reprises
gardent cette licence (attribution + partage à l'identique) : voir NOTICE.md.
Les entrées sans source (prose écrite par Spoken) sont écartées.
"""
import json
import os
import re
import sys
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SNAPSHOT = os.path.join(ROOT, "data", "forever", "lore", "lore.json")
OUT = os.path.join(ROOT, "QuestCompanion", "LoreData.lua")
REPO = "rusty-key/spoken-wow"
SHA = "4ccae964bb4e04f40e82417efc2925cf6e147b90"
DATA = "addons/Spoken_Places/Data"
FILES = ["frFR/Zones.lua", "enUS/Zones.lua", "frFR/Subzones.lua", "enUS/Subzones.lua",
         "frFR/Aliases.lua", "AreaZones.lua", "ForeverAreas.lua"]
WIKI = "https://warcraft.wiki.gg/wiki/"
MAX_LEN = 190        # caractères gardés d'une phrase (largeur de la bulle)
MIN_LEN = 50         # une sous-zone plus courte ne dit rien d'intéressant
SUB_CAP = 6          # sous-zones gardées par zone (budget mémoire)
CITIES = [1453, 1454, 1455, 1456, 1457, 1458]   # capitales : cartes à part, sans quêtes de zone


# ---------------------------------------------------------------------------
# Lecture des tables Lua (constructeurs simples : chaînes, nombres, booléens)
# ---------------------------------------------------------------------------
TOKEN = re.compile(r'\s+|--\[\[.*?\]\]|--[^\n]*|"((?:\\.|[^"\\])*)"|(-?\d+(?:\.\d+)?)|([A-Za-z_]\w*)|(.)', re.S)
ESCAPES = {"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'"}


def tokens(text):
    for m in TOKEN.finditer(text):
        if m.group(1) is not None:
            yield ("str", re.sub(r"\\(.)", lambda e: ESCAPES.get(e.group(1), e.group(1)), m.group(1)))
        elif m.group(2) is not None:
            yield ("num", float(m.group(2)) if "." in m.group(2) else int(m.group(2)))
        elif m.group(3) is not None:
            yield ("id", m.group(3))
        elif m.group(4) is not None:
            yield ("sym", m.group(4))


def parse_table(toks, i):
    """toks[i] = '{' ; rend (dict, indice après '}')."""
    out, n = {}, 1
    i += 1
    while toks[i] != ("sym", "}"):
        if toks[i] == ("sym", "["):
            key, i = parse_value(toks, i + 1)
            assert toks[i] == ("sym", "]") and toks[i + 1] == ("sym", "="), toks[i]
            value, i = parse_value(toks, i + 2)
        elif toks[i][0] == "id" and toks[i + 1] == ("sym", "="):
            key = toks[i][1]
            value, i = parse_value(toks, i + 2)
        else:
            key, n = n, n + 1
            value, i = parse_value(toks, i)
        out[key] = value
        if toks[i] in (("sym", ","), ("sym", ";")):
            i += 1
    return out, i + 1


def parse_value(toks, i):
    kind, value = toks[i]
    if (kind, value) == ("sym", "{"):
        return parse_table(toks, i)
    if kind in ("str", "num"):
        return value, i + 1
    if kind == "id" and value in ("true", "false", "nil"):
        return {"true": True, "false": False, "nil": None}[value], i + 1
    raise ValueError("valeur Lua inattendue : %r" % (toks[i],))


def lua_tables(text):
    """Toutes les affectations `nom = { … }` de premier niveau d'un fichier."""
    toks = list(tokens(text))
    found, i = {}, 0
    while i < len(toks) - 2:
        if toks[i][0] == "id" and toks[i + 1] == ("sym", "=") and toks[i + 2] == ("sym", "{"):
            name = toks[i][1]
            if i >= 2 and toks[i - 1] == ("sym", ".") and toks[i - 2][0] == "id":
                pass   # SpokenPlaces.Nom = { … } : le nom après le point
            found[name], i = parse_table(toks, i + 2)
        else:
            i += 1
    return found


# ---------------------------------------------------------------------------
# Choix et coupe des phrases
# ---------------------------------------------------------------------------
def normalise(name):
    """Comme SpokenPlaces:NormaliseAreaKey (et CompanionLore.lua) : minuscules,
    « the » de tête ôté, apostrophes supprimées, ponctuation -> espace."""
    s = name.lower()
    s = re.sub(r"^the\s+", "", s)
    s = s.replace("'", "").replace("\u2019", "")
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return s.strip()


SENTENCE_END = re.compile(r"[.!?…](?=\s|$)")


def cut(text, limit=MAX_LEN):
    """Une phrase entière qui tient, sinon coupe au mot avec « … »."""
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    best = None
    for m in SENTENCE_END.finditer(text):
        if m.end() <= limit:
            best = m.end()
    if best and best >= MIN_LEN:
        return text[:best].strip()
    head = text[:limit - 1]
    space = head.rfind(" ")
    if space > limit // 2:
        head = head[:space]
    return head.rstrip(" ,;:—-") + "…"


def slug(url):
    assert url.startswith(WIKI), url
    return url[len(WIKI):]


def fetch(cache):
    os.makedirs(cache, exist_ok=True)
    texts = {}
    for name in FILES:
        path = os.path.join(cache, name.replace("/", "_"))
        if not os.path.exists(path):
            url = "https://raw.githubusercontent.com/%s/%s/%s/%s" % (REPO, SHA, DATA, name)
            # curl : le Python de macOS n'a pas toujours les certificats
            subprocess.run(["curl", "-sfL", "--max-time", "120", "-o", path, url], check=True)
        texts[name] = open(path, encoding="utf-8").read()
    return texts


def our_zones():
    text = open(os.path.join(ROOT, "QuestCompanion", "ZoneQuests_Forever.lua"), encoding="utf-8").read()
    return sorted({int(m) for m in re.findall(r"^Z\[(\d+)\] = ", text, re.M)} | set(CITIES))


def notable_names():
    """Noms anglais normalisés des villes, hubs et donjons (socle commun)."""
    names = set()
    socle = os.path.join(ROOT, "QuestCompanion", "Libs", "Socle")
    for file in ("Hubs.lua", "DungeonData.lua"):
        text = open(os.path.join(socle, file), encoding="utf-8").read()
        names.update(normalise(n) for n in re.findall(r'name = "((?:\\.|[^"])*)"', text))
    # sous-zones d'entrée des donjons (areaID -> nom anglais, data/forever/areas.jsonl)
    areas = {}
    for line in open(os.path.join(ROOT, "data", "forever", "areas.jsonl"), encoding="utf-8"):
        row = json.loads(line)
        areas[row["id"]] = row["name"]
    text = open(os.path.join(socle, "DungeonData.lua"), encoding="utf-8").read()
    for block in re.findall(r"entrances = \{([^}]*)\}", text):
        for area in re.findall(r"\d+", block):
            if int(area) in areas:
                names.add(normalise(areas[int(area)]))
    return names


# 2.13.0 : le texte français de Spoken garde souvent les noms anglais des lieux
# (« Goldshire », « Stormwind ») alors que le client français dit Comté-de-l'Or,
# Hurlevent. On les remplace par le nom du client : (1) d'après les alias
# français de Spoken (variante anglaise -> nom français officiel), (2) d'après
# une courte table de noms sûrs pour les mots seuls (« Stormwind » sans « Cité »).
FR_CORE = {
    "Stormwind": "Hurlevent", "Northshire": "Comté-du-Nord", "Goldshire": "Comté-de-l'Or",
    "Ironforge": "Forgefer", "Undercity": "Fossoyeuse", "Thunder Bluff": "Les Pitons-du-Tonnerre",
    "Booty Bay": "Baie-du-Butin", "Southshore": "Austrivage", "Tarren Mill": "Moulin-de-Tarren",
    "Ratchet": "Cabestan", "Crossroads": "la Croisée", "Lakeshire": "Comté-du-Lac",
    "Sentinel Hill": "colline des Sentinelles", "Silverpine": "Pins-Argentés", "Hillsbrad": "Hautebrande",
    "Stranglethorn": "Strangleronce", "Ashenvale": "Orneval", "Darkshore": "Sombrivage",
    "Westfall": "la Marche de l'Ouest", "Redridge": "les Carmines", "Duskwood": "le Bois de la Pénombre",
    "Wetlands": "les Paluns", "Badlands": "les Terres ingrates", "Felwood": "Gangrebois",
    "Winterspring": "Berceau-de-l'Hiver", "Moonglade": "Reflet-de-Lune", "Razor Hill": "Tranchecolline",
    "Elwynn Forest": "la forêt d'Elwynn", "Dustwallow": "Âprefange", "Stonetalon": "Serres-Rocheuses",
    "Defias": "Défias", "Bloodhoof": "Sabot-de-Sang", "Thousand Needles": "Mille pointes",
    "Darkshire": "Sombre-Comté",
}
_WORD = "A-Za-zÀ-ÖØ-öø-ÿ'’"


def fr_replacements(aliases, key_names_en):
    """Paires (variante, nom français) : alias de Spoken + mots seuls sûrs."""
    by_key = {}
    for client, key in aliases.items():
        by_key.setdefault(key, set()).add(client.replace("’", "'"))
    pairs = {}
    for key, names in by_key.items():
        en_words = set(normalise(n) for n in key_names_en.get(key, ())) | {key}
        def englishish(n):
            return any(w and w in normalise(n) for w in key.split() if len(w) > 3)
        official = [n for n in names if not englishish(n)]
        if len(official) != 1:
            continue
        for n in names:
            if n != official[0] and englishish(n):
                pairs[n] = official[0]
    for en, fr in FR_CORE.items():
        pairs.setdefault(en, fr)
    return sorted(pairs.items(), key=lambda kv: -len(kv[0]))


_LETTERS = "A-Za-zÀ-ÖØ-öø-ÿ"


def _elide(article, official):
    """« d' » / « l' » devant le nom français : élision gardée devant une voyelle,
    « de » devant une consonne, article supprimé quand le nom n'en prend pas."""
    if official[:1].lower() in "aeiouyàâéèêîôû":   # h aspiré : « de Hautebrande », « de Hurlevent »
        return article + official
    if article.lower() == "d'":
        return ("De " if article[0] == "D" else "de ") + official
    return official[0].upper() + official[1:] if article[0] == "L" else official


def fr_fix(text, pairs):
    for variant, official in pairs:
        if variant not in text:
            continue
        pattern = r"(?<![%s])([dDlL]['’])?%s(?![%s])" % (_LETTERS, re.escape(variant), _WORD)
        text = re.sub(pattern, lambda m: _elide(m.group(1).replace("’", "'"), official) if m.group(1) else official, text)
    return text


def snapshot(texts):
    zones_fr = lua_tables(texts["frFR/Zones.lua"])["zones"]
    zones_en = lua_tables(texts["enUS/Zones.lua"])["zones"]
    subs_fr = lua_tables(texts["frFR/Subzones.lua"])["subzones"]
    subs_en = lua_tables(texts["enUS/Subzones.lua"])["subzones"]
    aliases = lua_tables(texts["frFR/Aliases.lua"])["aliases"]
    moved = lua_tables(texts["AreaZones.lua"])["AreaZones"]
    forever = lua_tables(texts["ForeverAreas.lua"])
    not_on = forever.get("NotOnForever", {})
    renamed = forever.get("ForeverNames", {})
    known = our_zones()
    notable = notable_names()
    key_names_en = {}
    for _mid, en in zones_en.items():
        if isinstance(en, dict) and en.get("name"):
            key_names_en.setdefault(normalise(en["name"]), set()).add(en["name"])
    for _z, entries in subs_en.items():
        for key, en in entries.items():
            if isinstance(en, dict) and en.get("name"):
                key_names_en.setdefault(key, set()).add(en["name"])
    pairs = fr_replacements(aliases, key_names_en)
    fr_names = {}
    for client, key in aliases.items():
        fr_names.setdefault(key, set()).add(client)
    en_names = {}
    for client, key in renamed.items():
        en_names.setdefault(key, set()).add(client)

    zones = {}
    for mid in known:
        fr, en = zones_fr.get(mid), zones_en.get(mid)
        if not (fr and en and fr.get("source") and fr.get("short") and en.get("short")):
            continue
        zones[str(mid)] = {"name": en["name"], "fr": cut(fr_fix(fr["short"], pairs)), "en": cut(en["short"]), "src": slug(fr["source"])}

    # sous-zones : rangées sous la zone où le client les place (AreaZones)
    candidates = {}
    for story_zone, entries in subs_en.items():
        for key, en in entries.items():
            fr = subs_fr.get(story_zone, {}).get(key)
            if not (fr and en.get("source") and fr.get("short") and en.get("short")):
                continue
            if not_on.get(story_zone, {}).get(key):
                continue
            where = moved.get(story_zone, {}).get(key)
            homes = [where.get("zone", story_zone)] + list(where.get("also", {}).values()) if where else [story_zone]
            for home in homes:
                if home not in known:
                    continue
                entry = {"key": key, "fr": cut(fr_fix(fr["short"], pairs)), "en": cut(en["short"]), "src": slug(en["source"]),
                         "names_fr": sorted(fr_names.get(key, ())), "names_en": sorted(en_names.get(key, ()))}
                candidates.setdefault(str(home), []).append(entry)
    subzones = {}
    for home, entries in candidates.items():
        def rank(e):
            return (0 if e["key"] in notable else 1, len(e["fr"]) + len(e["en"]), e["key"])
        kept = [e for e in entries if len(e["fr"]) >= MIN_LEN and len(e["en"]) >= MIN_LEN]
        kept = sorted(kept, key=rank)[:SUB_CAP]
        subzones[home] = sorted(kept, key=lambda e: e["key"])
    return {"source": "https://github.com/%s" % REPO, "commit": SHA, "path": DATA,
            "licence": "CC BY-SA 4.0 (texte : Warcraft Wiki) ; code de Spoken : MIT",
            "zones": zones, "subzones": subzones}


# ---------------------------------------------------------------------------
# Écriture de LoreData.lua
# ---------------------------------------------------------------------------
HEADER = """-- LoreData.lua -- histoire des lieux racontée par le compagnon (QuestCompanion 2.13.0)
--
-- FICHIER GÉNÉRÉ par tools/gen_lore.py depuis data/forever/lore/lore.json, ne
-- pas éditer à la main.
-- Textes : Warcraft Wiki (https://warcraft.wiki.gg), sous licence CC BY-SA 4.0
--   (https://creativecommons.org/licenses/by-sa/4.0/). Choisis et traduits en
--   français par le projet Spoken de Rusty Key (https://github.com/%(repo)s,
--   addons/Spoken_Places/Data, commit %(sha)s) ; ici réduits à une phrase
--   (coupée au besoin). Ces textes restent sous CC BY-SA 4.0 (pas sous la
--   GPL-3.0 du reste de l'addon) : voir NOTICE.md. Source de chaque ligne : la
--   page du wiki en dernier champ (https://warcraft.wiki.gg/wiki/<page>).
-- Lore text from Warcraft Wiki, CC BY-SA 4.0, via Spoken by Rusty Key (MIT code).
local ADDON, ns = ...
if ns.blocked then return end

-- Une ligne par lieu, champs séparés par une tabulation :
--   Z  uiMapID  texte  page
--   S  uiMapID  noms du client (« | » ; anglais : clé normalisée)  texte  page
-- Seule la langue du client est gardée (l'autre chaîne est libérée) ;
-- CompanionLore.lua y cherche la ligne voulue (zone : à l'arrivée ; sous-zones :
-- une petite liste par zone, refaite au changement de zone).
"""


def lines(data, lang):
    out = []
    for mid in sorted(data["zones"], key=int):
        z = data["zones"][mid]
        out.append("Z\t%s\t%s\t%s" % (mid, z[lang], z["src"]))
    for mid in sorted(data["subzones"], key=int):
        for e in data["subzones"][mid]:
            if lang == "fr":
                names = e["names_fr"] or [e["key"]]
            else:
                names = sorted({e["key"]} | set(e["names_en"]))
            out.append("S\t%s\t%s\t%s\t%s" % (mid, "|".join(names), e[lang], e["src"]))
    for line in out:
        assert "]]" not in line and "\n" not in line, line
    return "\n".join(out)


def build(out_path=OUT, snapshot_path=SNAPSHOT):
    data = json.load(open(snapshot_path, encoding="utf-8"))
    body = HEADER % {"repo": REPO, "sha": data["commit"]}
    # [[ saute le premier saut de ligne : le second ouvre la chaîne (motifs « \nZ\t »)
    body += "local FR = [[\n\n%s\n]]\n" % lines(data, "fr")
    body += "local EN = [[\n\n%s\n]]\n" % lines(data, "en")
    body += "if ns.KEEP_STRINGS then\n\tns.LORE_RAW = { fr = FR, en = EN }\nelse\n"
    body += "\tns.LORE_RAW = { [ns.STRINGS_FRENCH ~= false and \"fr\" or \"en\"] = ns.STRINGS_FRENCH ~= false and FR or EN }\nend\n"
    with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(body)
    return data


def main(argv):
    if "--fetch" in argv:
        cache = argv[argv.index("--cache") + 1] if "--cache" in argv else os.path.join(ROOT, ".lore-cache")
        data = snapshot(fetch(cache))
        os.makedirs(os.path.dirname(SNAPSHOT), exist_ok=True)
        with open(SNAPSHOT, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=1, sort_keys=True)
            handle.write("\n")
    data = build()
    subs = sum(len(v) for v in data["subzones"].values())
    print("LoreData.lua : %d zones, %d sous-zones (fr + en), %d octets"
          % (len(data["zones"]), subs, os.path.getsize(OUT)), file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
