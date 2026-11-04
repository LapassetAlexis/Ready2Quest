#!/usr/bin/env python3
"""Recopie le socle commun de Ready2Quest dans QuestCompanion.

Le socle (Libs/Socle : sauvegarde, commandes, réglages, thème, textes communs,
lecture du monde) est embarqué dans chaque addon, comme une lib WoW : chacun
doit fonctionner seul. Sa source est Ready2Quest/Libs/Socle ; ce script la
recopie à l'identique dans QuestCompanion/Libs/Socle (fichiers en trop
supprimés). tests/run_tests.py refuse de tourner si les deux copies diffèrent.

Usage : python3 -I tools/sync_socle.py
"""
import filecmp
import os
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


def differences(source, target):
    """Fichiers qui diffèrent, manquent ou sont en trop dans la copie."""
    wanted, present = socle_files(source), socle_files(target) if os.path.isdir(target) else set()
    diff = sorted(wanted ^ present)
    for rel in sorted(wanted & present):
        if not filecmp.cmp(os.path.join(source, rel), os.path.join(target, rel), shallow=False):
            diff.append(rel)
    return diff


def main():
    for target in TARGETS:
        if os.path.isdir(target):
            shutil.rmtree(target)
        shutil.copytree(SOURCE, target)
        print("socle recopié : %s" % os.path.relpath(target, ROOT))


if __name__ == "__main__":
    main()
