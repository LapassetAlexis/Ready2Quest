#!/usr/bin/env python3
"""Recopie le socle commun de Ready2Quest dans QuestCompanion.

Le socle (Libs/Socle : sauvegarde, commandes, réglages, thème, textes communs,
lecture du monde) est embarqué dans chaque addon, comme une lib WoW : chacun
doit fonctionner seul. Sa source est Ready2Quest/Libs/Socle ; ce script la
recopie à l'identique dans QuestCompanion/Libs/Socle (fichiers en trop
supprimés). tests/run_tests.py refuse de tourner si les deux copies diffèrent.

Socle 2.11.0 : avant de recopier, le script écrit l'empreinte du socle
(SHA-1 tronqué de tous ses fichiers, Media compris, la valeur elle-même
exclue) en tête de Base.lua (local SOCLE_ID = "…"). Deux addons au socle de
même empreinte partagent le code compilé (Base.lua, ns.SocleFile).

Usage : python3 -I tools/sync_socle.py
"""
import filecmp
import hashlib
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "Ready2Quest", "Libs", "Socle")
TARGETS = [os.path.join(ROOT, "QuestCompanion", "Libs", "Socle")]


def socle_files(base):
    found = set()
    for folder, _, files in os.walk(base):
        for name in files:
            found.add(os.path.relpath(os.path.join(folder, name), base))
    return found


ID_RE = re.compile(r'(local SOCLE_ID = ")([0-9a-f]{8})(")')


def socle_id(base=None):
    """Empreinte du contenu du socle, la ligne SOCLE_ID neutralisée."""
    base = base or SOURCE
    digest = hashlib.sha1()
    for rel in sorted(socle_files(base)):
        if "__pycache__" in rel or rel.endswith(".pyc"):
            continue
        with open(os.path.join(base, rel), "rb") as handle:
            data = handle.read()
        if rel == "Base.lua":
            data = ID_RE.sub(r"\g<1>00000000\g<3>", data.decode("utf-8")).encode("utf-8")
        digest.update(rel.replace(os.sep, "/").encode("utf-8") + b"\0" + data)
    return digest.hexdigest()[:8]


def written_id(base=None):
    base = base or SOURCE
    with open(os.path.join(base, "Base.lua"), encoding="utf-8") as handle:
        match = ID_RE.search(handle.read())
    return match.group(2) if match else None


def stale_id(base=None):
    """Vrai si l'empreinte écrite dans Base.lua ne correspond plus au contenu."""
    return written_id(base) != socle_id(base)


def stamp(base=None):
    base = base or SOURCE
    path = os.path.join(base, "Base.lua")
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    new = ID_RE.sub(lambda m: m.group(1) + socle_id(base) + m.group(3), text)
    if new != text:
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(new)


def differences(source, target):
    """Fichiers qui diffèrent, manquent ou sont en trop dans la copie."""
    wanted, present = socle_files(source), socle_files(target) if os.path.isdir(target) else set()
    diff = sorted(wanted ^ present)
    for rel in sorted(wanted & present):
        if not filecmp.cmp(os.path.join(source, rel), os.path.join(target, rel), shallow=False):
            diff.append(rel)
    return diff


def main():
    stamp()
    print("empreinte du socle : %s" % written_id())
    for target in TARGETS:
        if os.path.isdir(target):
            shutil.rmtree(target)
        shutil.copytree(SOURCE, target)
        print("socle recopié : %s" % os.path.relpath(target, ROOT))


if __name__ == "__main__":
    main()
