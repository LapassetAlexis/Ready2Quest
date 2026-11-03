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

lua = LuaRuntime(unpack_returned_tuples=True)
globals_ = lua.globals()
globals_.ADDON_ROOT = ROOT
# Tests des modules : tests/modules/*.lua, dans l'ordre alphabétique
import glob
module_tests = sorted(os.path.relpath(p, ROOT) for p in glob.glob(os.path.join(ROOT, "tests", "modules", "*.lua")))
globals_.MODULE_TEST_FILES = lua.table_from(module_tests)

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
failed = int(globals_.TEST_FAILED or 0)
raise SystemExit(1 if failed else 0)
