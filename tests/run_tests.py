#!/usr/bin/env python3
"""Exécute la suite de tests des addons Ready2Quest et QuestCompanion en Lua 5.1
(version du client WoW), hors jeu, via lupa.

Usage :
  python3 tests/run_tests.py                 toute la suite, en parallèle (un processus par cœur)
  python3 tests/run_tests.py -j 1            un seul processus (même résultat, plus lent)
  python3 tests/run_tests.py -j 4            quatre processus
  python3 tests/run_tests.py qc30_echanges companion   seulement ces modules (sans les scénarios du cœur)
  python3 tests/run_tests.py core            seulement les scénarios du cœur (tests/run_tests.lua)
  python3 tests/run_tests.py --profile       en plus : les unités les plus lentes, avec leur nombre de contrôles
  python3 tests/run_tests.py --memoire       mémoire Lua de chaque fichier au chargement (sans les tests)

Chaque unité (les scénarios du cœur, puis chaque fichier de tests/modules/)
joue dans son propre état Lua, addons fraîchement chargés (0,1 s) : aucun
module ne dépend de ce qu'un autre a laissé, l'ordre et le découpage entre
processus ne changent rien au résultat. La sortie est remise dans l'ordre
(cœur, puis modules par ordre alphabétique), avec la ligne « RESULTAT: » finale.

Nécessite le paquet `lupa` (pip install lupa).
"""
import glob
import os
import re
import sys
import time
from collections import Counter

sys.path.insert(0, os.environ.get("LUA_PYLIB", "/tmp/pylib"))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:  # pragma: no cover
    print("ERREUR: le paquet python 'lupa' est requis (pip install --target /tmp/pylib lupa)")
    raise SystemExit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST_FILE = os.path.join(ROOT, "tests", "run_tests.lua")
CORE = "core"
RANDOM_SEED = int(os.environ.get("TEST_SEED", "1"))  # TEST_SEED=n : chasse aux tests qui dépendent du hasard
_SOURCE = None


def lua_source():
    global _SOURCE
    if _SOURCE is None:
        with open(TEST_FILE, "r", encoding="utf-8") as handle:
            _SOURCE = handle.read()
    return _SOURCE


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
    # le reste vient du client, par référence (polices .ttf permises).
    # 3.1.0 / 1.35.0 : s'y ajoutent les textures d'habillage du thème Azeroth
    # (formes, reliefs et lueurs générés par tools/gen_ui_assets.py, dans le
    # socle) et le glyphe du logo pour la mini-carte. Toujours aucune
    # illustration, et rien de repris du jeu.
    for f in tracked:
        if f.split("/")[0] in ("Ready2Quest", "QuestCompanion") and os.path.exists(os.path.join(ROOT, f)) \
                and os.path.splitext(f)[1].lower() in IMAGE_EXTS and f not in ALLOWED_IMAGES:
            problems.append("image non autorisée : %s (n'embarquer que le filet, les logos et l'habillage du thème)" % f)
    return problems


IMAGE_EXTS = {".tga", ".blp", ".png", ".jpg", ".jpeg", ".bmp", ".gif", ".dds", ".webp", ".svg"}
ALLOWED_IMAGES = {
    "QuestCompanion/Textures/filet.tga", "QuestCompanion/Textures/corde.tga", "QuestCompanion/Textures/paquet.tga",
    "QuestCompanion/Textures/logo.tga", "QuestCompanion/Textures/logo_petit.tga",
    "Ready2Quest/Textures/logo.tga", "Ready2Quest/Textures/logo_petit.tga",
    "QuestCompanion/Textures/logo_glyphe.tga", "Ready2Quest/Textures/logo_glyphe.tga",
}
UI_ASSETS = ("cadre", "ombre", "coin", "plaque", "creux", "lueur_ligne", "lueur_point", "vignette", "anneau")
for _addon in ("Ready2Quest", "QuestCompanion"):
    for _name in UI_ASSETS:
        ALLOWED_IMAGES.add("%s/Libs/Socle/Media/%s.tga" % (_addon, _name))


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
        # 3.1.0 / 1.35.0 : textures d'habillage du thème (tools/gen_ui_assets.py)
        import gen_ui_assets
        media = os.path.join(ROOT, "Ready2Quest", "Libs", "Socle", "Media")
        for name, draw in gen_ui_assets.ASSETS:
            current = os.path.join(media, name + ".tga")
            if not os.path.exists(current) or open(current, "rb").read() != gen_ui_assets.tga(*draw()):
                problems.append("Ready2Quest/Libs/Socle/Media/%s.tga ne correspond plus à tools/gen_ui_assets.py "
                                "(python3 -I tools/gen_ui_assets.py, puis tools/sync_socle.py)" % name)
        if tuple(name for name, _ in gen_ui_assets.ASSETS) != UI_ASSETS:
            problems.append("tests/run_tests.py : UI_ASSETS ne suit plus tools/gen_ui_assets.py (ASSETS)")
        # 3.1.0 : taille des apparences (data/forever/display_sizes.json)
        import gen_display_sizes
        sizes = os.path.join(out, "DisplaySizes_Forever.lua")
        gen_display_sizes.build(sizes)
        if open(sizes, encoding="utf-8").read() != open(os.path.join(ROOT, "QuestCompanion", "DisplaySizes_Forever.lua"), encoding="utf-8").read():
            problems.append("QuestCompanion/DisplaySizes_Forever.lua ne correspond plus à data/forever/display_sizes.json (python3 -I tools/gen_display_sizes.py)")
    finally:
        shutil.rmtree(out, ignore_errors=True)
    return problems




def preflight():
    """Garde-fous d'avant les tests (une fois, dans le processus principal)."""
    duplicates = check_mock_duplicates(lua_source())
    if duplicates:
        print("ERREUR: méthodes dupliquées dans le mock (la seconde écrase la première) :")
        for name in sorted(duplicates):
            print("  region:%s" % name)
        raise SystemExit(2)
    problems = check_packages() + check_socle() + check_generated()
    if problems:
        print("ERREUR: paquets de publication incomplets :")
        for problem in problems:
            print("  " + problem)
        raise SystemExit(2)


def new_runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ADDON_ROOT = ROOT
    return lua, g


def run_unit(unit):
    """Joue une unité (CORE ou un chemin tests/modules/x.lua) dans un état Lua
    neuf. Rend (unité, sortie sans la ligne RESULTAT, réussis, échoués, secondes,
    erreur Lua ou None)."""
    start = time.perf_counter()
    lua, g = new_runtime()
    g.RUN_CORE = unit == CORE
    g.MODULE_TEST_FILES = lua.table_from([] if unit == CORE else [unit])
    # le tirage de Lua 5.1 (rand() du C) est commun à tout le processus : même
    # graine pour chaque unité, quel que soit ce qui a tourné avant elle
    lua.execute("math.randomseed(%d)" % RANDOM_SEED)
    try:
        lua.execute(lua_source())
    except Exception as exc:  # erreur Lua non gérée
        return unit, g.TEST_PARTIAL or "", 0, 1, time.perf_counter() - start, str(exc)
    lines = (g.TEST_OUTPUT or "").split("\n")
    while lines and (not lines[-1].strip() or lines[-1].startswith("RESULTAT:")):
        lines.pop()
    return (unit, "\n".join(lines), int(g.TEST_PASSED or 0), int(g.TEST_FAILED or 0),
            time.perf_counter() - start, None)


def emit(text):
    # La console Windows est en cp1252 et refuse les caractères hors de sa table
    # (lettres grecques, flèches). Un plantage ici masquerait le vrai résultat :
    # on remplace les caractères non représentables au lieu d'échouer.
    try:
        print(text)
    except UnicodeEncodeError:
        encoding = sys.stdout.encoding or "cp1252"
        print(text.encode(encoding, "replace").decode(encoding, "replace"))


def run_memory():
    """--memoire : mémoire Lua laissée par chaque fichier des addons au chargement
    (code compilé compris), comme sur un client français ; les tests ne tournent
    pas (l'addon tel que le client le charge : sans le mode test)."""
    lua, g = new_runtime()
    g.MODULE_TEST_FILES = lua.table_from([])
    g.MEMORY_REPORT = lua.table()
    g.MEMORY_ONLY = True
    lua.execute(lua_source())
    rows = [(row.name, float(row.kb)) for row in g.MEMORY_REPORT.values()]
    totals = Counter()
    for name, kb in rows:
        totals[name.split("/")[0]] += kb
    print("\n== Mémoire Lua au chargement (Ko, après ramassage) ==")
    for name, kb in sorted(rows, key=lambda r: -r[1])[:25]:
        print("%8.1f  %s" % (kb, name))
    for addon, kb in sorted(totals.items()):
        print("%8.1f  TOTAL %s" % (kb, addon))


def parse_args(argv):
    jobs, profile, memory, names = os.cpu_count() or 1, False, False, []
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "-j" and i + 1 < len(argv):
            jobs = int(argv[i + 1]); i += 1
        elif re.match(r"^-j\d+$", arg):
            jobs = int(arg[2:])
        elif arg == "--profile":
            profile = True
        elif arg == "--memoire":
            memory = True
        elif arg.startswith("-"):
            print("ERREUR: option inconnue %s" % arg)
            raise SystemExit(2)
        else:
            names.append(arg)
        i += 1
    return max(1, jobs), profile, memory, names


def select_units(names):
    modules = sorted(os.path.relpath(p, ROOT) for p in glob.glob(os.path.join(ROOT, "tests", "modules", "*.lua")))
    if not names:
        return [CORE] + modules
    units = []
    for name in names:
        if name == CORE:
            units.append(CORE)
            continue
        base = os.path.splitext(os.path.basename(name))[0]
        match = [m for m in modules if os.path.splitext(os.path.basename(m))[0] == base]
        if not match:
            print("ERREUR: module introuvable : %s" % name)
            raise SystemExit(2)
        units += match
    return units


def main(argv):
    jobs, profile, memory, names = parse_args(argv)
    preflight()
    if memory:
        run_memory()
        return 0
    units = select_units(names)
    start = time.perf_counter()
    if jobs == 1 or len(units) == 1:
        results = [run_unit(unit) for unit in units]
    else:
        import multiprocessing
        # les plus gros d'abord (taille du fichier : bon indice de durée), pour
        # que la file se vide en même temps sur tous les processus
        def weight(unit):
            return 1 << 30 if unit == CORE else os.path.getsize(os.path.join(ROOT, unit))
        ordered = sorted(units, key=weight, reverse=True)
        with multiprocessing.get_context("spawn").Pool(min(jobs, len(units))) as pool:
            results = list(pool.imap_unordered(run_unit, ordered, chunksize=1))
    wall = time.perf_counter() - start
    by_unit = {r[0]: r for r in results}
    passed = failed = 0
    errors = []
    for unit in units:
        _, output, ok, ko, _, error = by_unit[unit]
        if output:
            emit(output)
        if error:
            emit("\n--- fin du journal de %s ---\nERREUR D'EXECUTION LUA (%s) :\n%s" % (unit, unit, error))
            errors.append(unit)
        passed += ok
        failed += ko
    emit("")
    emit("RESULTAT: %d réussis, %d échoués, %d assertions" % (passed, failed, passed + failed))
    if profile:
        rows = sorted(results, key=lambda r: -r[4])
        print("\n== Profil : unités les plus lentes (s, contrôles) ==")
        for unit, _, ok, ko, seconds, _ in rows[:25]:
            print("%6.2f s  %5d  %s" % (seconds, ok + ko, unit))
        print("%6.2f s  %5d  total (%d unités, cumul des processus) ; %.1f s écoulées avec -j %d"
              % (sum(r[4] for r in results), passed + failed, len(results), wall, jobs))
    if errors:
        return 2
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
