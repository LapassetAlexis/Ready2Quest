#!/usr/bin/env python3
"""Exécute la suite de tests de l'addon Ready2Quest en Lua 5.1 (version du client WoW).

Usage : python3 tests/run_tests.py
Nécessite le paquet `lupa` (pip install lupa).
"""
import os
import re
import sys
from collections import Counter

sys.path.insert(0, os.environ.get("LUA_PYLIB", "/tmp/pylib"))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:  # pragma: no cover
    print("ERREUR: le paquet python 'lupa' est requis (pip install --target /tmp/pylib lupa)")
    raise SystemExit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST_FILE = os.path.join(ROOT, "tests", "run_tests.lua")

with open(TEST_FILE, "r", encoding="utf-8") as handle:
    source = handle.read()


def check_mock_duplicates(text):
    """Garde-fou : deux `function region:X` dans le mock, le second écrase le
    premier silencieusement. Ça a déjà masqué un vrai bug (StartMoving, SetBackdrop)."""
    start = text.find("local function NewRegion")
    if start < 0:
        return []
    end = text.find("_G.CreateFrame", start)
    block = text[start:end if end > 0 else len(text)]
    names = re.findall(r"function region:([A-Za-z0-9_]+)", block)
    return [name for name, count in Counter(names).items() if count > 1]


duplicates = check_mock_duplicates(source)
if duplicates:
    print("ERREUR: méthodes dupliquées dans le mock (la seconde écrase la première) :")
    for name in sorted(duplicates):
        print("  region:%s" % name)
    raise SystemExit(2)

def pkgmeta_ignores(path):
    """Liste `ignore:` d'un .pkgmeta (YAML minimal, comme le lit le packager)."""
    items, phase = [], None
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\r\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if not line.startswith(" "):
                phase = line.split(":", 1)[0]
            elif phase == "ignore" and line.strip().startswith("- "):
                items.append(line.strip()[2:].strip().strip('"'))
    return items


def check_packages():
    """Garde-fou de publication : chaque addon a son dossier à la racine
    (Ready2Quest/, QuestCompanion/). Son .pkgmeta doit ignorer TOUT le reste de
    la racine (l'autre addon, docs, tests, outils), sinon ça part dans son zip."""
    import subprocess
    problems = []
    try:
        tracked = subprocess.check_output(["git", "-C", ROOT, "ls-files", "--cached", "--others", "--exclude-standard"],
                                          text=True).split("\n")
    except (OSError, subprocess.CalledProcessError):
        return problems  # pas de git (archive) : rien à vérifier
    root = {f.split("/")[0] for f in tracked if f and not f.startswith(".")}
    for pkgmeta, addon in ((".pkgmeta", "Ready2Quest"), (".pkgmeta-questcompanion", "QuestCompanion")):
        ignored = set(pkgmeta_ignores(os.path.join(ROOT, pkgmeta)))
        for entry in sorted(root - {addon} - ignored):
            problems.append("%s : « %s » n'est pas ignoré, il partirait dans le zip de %s" % (pkgmeta, entry, addon))
        if addon in ignored:
            problems.append("%s : le dossier %s lui-même est ignoré" % (pkgmeta, addon))
    # 2.12.1 / 1.33.1 : plus aucune image à nous hors du filet et des logos ;
    # le reste vient du client, par référence (polices .ttf permises)
    for f in tracked:
        if f.split("/")[0] in ("Ready2Quest", "QuestCompanion") and os.path.exists(os.path.join(ROOT, f)) \
                and os.path.splitext(f)[1].lower() in IMAGE_EXTS and f not in ALLOWED_IMAGES:
            problems.append("image non autorisée : %s (n'embarquer que le filet et les logos)" % f)
    return problems


IMAGE_EXTS = {".tga", ".blp", ".png", ".jpg", ".jpeg", ".bmp", ".gif", ".dds", ".webp", ".svg"}
ALLOWED_IMAGES = {
    "QuestCompanion/Textures/filet.tga", "QuestCompanion/Textures/corde.tga", "QuestCompanion/Textures/paquet.tga",
    "QuestCompanion/Textures/logo.tga", "QuestCompanion/Textures/logo_petit.tga",
    "Ready2Quest/Textures/logo.tga", "Ready2Quest/Textures/logo_petit.tga",
}


def check_socle():
    """Le socle commun est embarqué dans chaque addon : les copies doivent être
    identiques à la source (Ready2Quest/Libs/Socle). Sinon : tools/sync_socle.py."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import sync_socle
    problems = []
    # socle 2.11.0 : l'empreinte écrite dans Base.lua suit le contenu
    if sync_socle.stale_id():
        problems.append("empreinte du socle périmée (python3 -I tools/sync_socle.py)")
    for target in sync_socle.TARGETS:
        for rel in sync_socle.differences(sync_socle.SOURCE, target):
            problems.append("%s : %s diffère de Ready2Quest/Libs/Socle (python3 tools/sync_socle.py)"
                            % (os.path.relpath(target, ROOT), rel))
    return problems


package_problems = check_packages()
def check_generated():
    """Les tables de zone de QuestCompanion doivent venir de data/ tel qu'il
    est : on les régénère à part et on compare (en-tête daté exclu)."""
    import io
    import contextlib
    import shutil
    import tempfile
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import gen_zone_data
    problems = []
    out = tempfile.mkdtemp()
    try:
        shutil.copy(os.path.join(ROOT, "QuestCompanion", "GatheringData.lua"), out)
        with contextlib.redirect_stdout(io.StringIO()):
            gen_zone_data.main(["--out", out])

        def body(path):
            text = open(path, encoding="utf-8").read()
            return text[text.find("-- garde de client"):]
        for name in sorted(os.listdir(out)):
            if not name.startswith("Zone"):
                continue
            current = os.path.join(ROOT, "QuestCompanion", name)
            if not os.path.exists(current) or body(current) != body(os.path.join(out, name)):
                problems.append("QuestCompanion/%s ne correspond plus à data/ (python3 -I tools/gen_zone_data.py)" % name)
        # lieux sûrs du socle : Places.lua (PNJ de service) et Hubs.lua (sous-zones)
        import gen_places
        import gen_hubs
        places = os.path.join(out, "Places.lua")
        with contextlib.redirect_stdout(io.StringIO()):
            gen_places.main(places)
        hubs = io.StringIO()
        with contextlib.redirect_stdout(hubs), contextlib.redirect_stderr(io.StringIO()):
            gen_hubs.main()
        socle = os.path.join(ROOT, "Ready2Quest", "Libs", "Socle")
        if open(places, encoding="utf-8").read() != open(os.path.join(socle, "Places.lua"), encoding="utf-8").read():
            problems.append("Ready2Quest/Libs/Socle/Places.lua ne correspond plus à data/ (python3 -I tools/gen_places.py)")
        if hubs.getvalue() != open(os.path.join(socle, "Hubs.lua"), encoding="utf-8").read():
            problems.append("Ready2Quest/Libs/Socle/Hubs.lua ne correspond plus à data/ "
                            "(python3 -I tools/gen_hubs.py > Ready2Quest/Libs/Socle/Hubs.lua)")
        # 2.12.0 : catalogue du Juke-box (data/forever/music.json)
        import gen_music
        music = os.path.join(out, "MusicData.lua")
        with contextlib.redirect_stderr(io.StringIO()):
            gen_music.build(music)
        if open(music, encoding="utf-8").read() != open(os.path.join(ROOT, "QuestCompanion", "MusicData.lua"), encoding="utf-8").read():
            problems.append("QuestCompanion/MusicData.lua ne correspond plus à data/forever/music.json (python3 -I tools/gen_music.py)")
        # 2.13.0 : histoire des lieux (data/forever/lore/lore.json)
        import gen_lore
        lore = os.path.join(out, "LoreData.lua")
        gen_lore.build(lore)
        if open(lore, encoding="utf-8").read() != open(os.path.join(ROOT, "QuestCompanion", "LoreData.lua"), encoding="utf-8").read():
            problems.append("QuestCompanion/LoreData.lua ne correspond plus à data/forever/lore/lore.json (python3 -I tools/gen_lore.py)")
    finally:
        shutil.rmtree(out, ignore_errors=True)
    return problems


package_problems += check_socle()
package_problems += check_generated()
if package_problems:
    print("ERREUR: paquets de publication incomplets :")
    for problem in package_problems:
        print("  " + problem)
    raise SystemExit(2)

lua = LuaRuntime(unpack_returned_tuples=True)
globals_ = lua.globals()
globals_.ADDON_ROOT = ROOT
# Tests des modules : tests/modules/*.lua, dans l'ordre alphabétique
import glob
module_tests = sorted(os.path.relpath(p, ROOT) for p in glob.glob(os.path.join(ROOT, "tests", "modules", "*.lua")))
globals_.MODULE_TEST_FILES = lua.table_from(module_tests)

# --memoire : mémoire Lua laissée par chaque fichier des addons au chargement
# (code compilé compris), comme sur un client français ; les tests ne tournent pas
MEMORY = "--memoire" in sys.argv
if MEMORY:
    # l'addon tel que le client le charge : sans le mode test, sans les tests
    globals_.MEMORY_REPORT = lua.table()
    globals_.MEMORY_ONLY = True

try:
    lua.execute(source)
except Exception as exc:  # erreur Lua non gérée
    partial = globals_.TEST_PARTIAL
    if partial:
        print(partial)
        print("\n--- fin du journal ---")
    print("ERREUR D'EXECUTION LUA :\n%s" % exc)
    raise SystemExit(2)

# La console Windows est en cp1252 et refuse les caractères hors de sa table
# (lettres grecques, flèches). Un plantage ici masquerait le vrai résultat :
# on remplace les caractères non représentables au lieu d'échouer.
output = globals_.TEST_OUTPUT
try:
    print(output)
except UnicodeEncodeError:
    encoding = sys.stdout.encoding or "cp1252"
    print(output.encode(encoding, "replace").decode(encoding, "replace"))
if MEMORY:
    rows = [(row.name, float(row.kb)) for row in globals_.MEMORY_REPORT.values()]
    totals = Counter()
    for name, kb in rows:
        totals[name.split("/")[0]] += kb
    print("\n== Mémoire Lua au chargement (Ko, après ramassage) ==")
    for name, kb in sorted(rows, key=lambda r: -r[1])[:25]:
        print("%8.1f  %s" % (kb, name))
    for addon, kb in sorted(totals.items()):
        print("%8.1f  TOTAL %s" % (kb, addon))
failed = int(globals_.TEST_FAILED or 0)
raise SystemExit(1 if failed else 0)
