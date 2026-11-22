#!/usr/bin/env python3
"""Importe le moteur de combat de DoesItDiePlus dans Ready2Quest/Combat.

DoesItDiePlus (UsefulPlatesAndTooltips), d'Ironship, GPL-3.0-or-later ;
DoTInfo vient de « Does It Die » de Joe Greive (MIT) ; SpellDamageInfo est
sous MIT. Ready2Quest est sous GPL-3.0 : la reprise est permise, avec le
crédit et les licences recopiés dans Ready2Quest/Combat/.

Le script :
  * prend les fichiers du TOC Forever (UsefulPlatesAndTooltips.toc) des
    parties retenues (cœur, SpellDamageInfo, CastPrediction, DoTInfo, Range),
    dans l'ordre du TOC ;
  * les range sous Ready2Quest/Combat/ (même arborescence) ;
  * les isole : leur espace de noms (`local X, BIT = ...`) devient
    Ready2Quest.combat (créé par Ready2Quest/CombatBoot.lua, nil quand le
    module Combat ne doit pas tourner : chaque fichier s'arrête alors) ;
  * renomme leurs noms globaux (variables sauvegardées, cadres, API),
    leurs commandes et leurs entrées de SlashCmdList : aucun conflit quand
    DoesItDiePlus est aussi installé ;
  * recopie textures et licences, écrit Combat/files.txt (ordre de
    chargement, lu par tools/combat_toc.py et les tests) et UPSTREAM.txt.

Usage : python3 -I tools/sync_combat.py <dossier du dépôt amont>
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "Ready2Quest", "Combat")
TOC = "UsefulPlatesAndTooltips.toc"

KEEP_MODULES = ("SpellDamageInfo", "CastPrediction", "DoTInfo", "Range")
KEEP_LOCALE_PARTS = ("Core", "CastPrediction", "DoTInfo", "Range")
TEXTURE_DIRS = ("Core/Textures", "Modules/DoTInfo/Textures", "Modules/ResourceDing/Textures")
LICENSES = ("LICENSE", "Modules/DoTInfo/LICENSE-DoesItDie.txt")

# noms globaux et commandes : ordre important (le plus long d'abord)
RENAMES = [
    ("Interface\\\\AddOns\\\\UsefulPlatesAndTooltips\\\\", "Interface\\\\AddOns\\\\Ready2Quest\\\\Combat\\\\"),
    ("UsefulPlatesAndTooltips", "Ready2QuestCombat"),
    ("USEFULPLATESANDTOOLTIPS", "R2QCOMBAT"),
    ("BITDOTINFO", "R2QDOTINFO"),
    ("SPELLDAMAGEINFO", "R2QSPELLDAMAGE"),
    ('"/usefulplates"', '"/r2qcombat"'),
    ('"/upt"', '"/r2qc"'),
    ('"/dotinfo"', '"/r2qdot"'),
    ('"/sdi"', '"/r2qsdi"'),
    ("|cff66bbffDoesItDiePlus|r", "|cff66bbffReady2Quest Combat|r"),
    ('"DoesItDiePlus: "', '"Ready2Quest Combat: "'),
    ('"DoesItDiePlus"', '"Ready2Quest Combat"'),
]
# "Interface\\AddOns\\" .. ADDON_NAME .. "\\  (ou (ADDON or "…") ) -> chemin sous Ready2Quest\Combat
DYNAMIC_PATH = re.compile(r'"Interface\\\\AddOns\\\\"\s*\.\.\s*\(?\s*[A-Za-z_]+(?:\s+or\s+"[^"]*")?\s*\)?\s*\.\.\s*"\\\\')
HEADER = re.compile(r"^local\s+([A-Za-z_]+)\s*,\s*BIT\s*=\s*\.\.\.\s*$", re.M)


def toc_files(src):
    files = []
    with open(os.path.join(src, TOC), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            files.append(line.replace("\\", "/"))
    return files


def wanted(path):
    parts = path.split("/")
    if parts[0] == "Core":
        return True
    if parts[0] == "Locales":
        return os.path.splitext(parts[-1])[0] in KEEP_LOCALE_PARTS
    if parts[0] == "Modules":
        return parts[1] in KEEP_MODULES
    return False


def transform(text, path):
    count = len(HEADER.findall(text))
    if count != 1:
        raise SystemExit("%s : en-tête d'espace de noms introuvable ou multiple (%d)" % (path, count))
    # 1.38.0 bêta 2 : le nom reste celui de l'addon hôte (« Ready2Quest ») :
    # trois modules comparent ADDON_LOADED à cette variable ; avec un autre
    # nom, ils ne démarraient jamais. Seuls les chemins de textures changent.
    text = DYNAMIC_PATH.sub(r'"Interface\\\\AddOns\\\\Ready2Quest\\\\Combat\\\\', text)
    text = HEADER.sub(
        lambda m: "local %s, BIT = \"Ready2Quest\", (select(2, ...)).combat\n"
                  "if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)" % m.group(1),
        text)
    for old, new in RENAMES:
        text = text.replace(old, new)
    # le nom de l'addon hôte, pour ADDON_LOADED et les métadonnées
    text = text.replace('BIT.name = ADDON or "Ready2QuestCombat"', 'BIT.name = "Ready2Quest"')
    # 2.1.0 : la coche de portée reçoit un nom global, pour que Ready2Quest
    # puisse la retirer quand Mot de l'ombre : Mort prend sa place
    # (Ready2Quest/CombatDeath.lua)
    if path.replace("\\", "/").endswith("Modules/Range/Range.lua"):
        old = 'icon = CreateFrame("Frame", nil, UIParent)'
        if text.count(old) != 1:
            raise SystemExit("%s : cadre de la coche introuvable" % path)
        text = text.replace(old, 'icon = CreateFrame("Frame", "Ready2QuestCombat_RangeIcon", UIParent)')
    banner = ("-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;\n"
              "-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.\n")
    return banner + text


TOC_PATH = os.path.join(ROOT, "Ready2Quest", "Ready2Quest.toc")
TOC_BEGIN, TOC_END = "# combat:begin (tools/sync_combat.py)", "# combat:end"


def update_toc(files):
    """Les fichiers importés dans le TOC de Ready2Quest, entre les marqueurs."""
    with open(TOC_PATH, encoding="utf-8", newline="") as f:
        text = f.read()
    nl = "\r\n" if "\r\n" in text else "\n"
    block = nl.join([TOC_BEGIN] + ["Combat\\" + p.replace("/", "\\") for p in files] + [TOC_END])
    if TOC_BEGIN in text:
        start = text.index(TOC_BEGIN)
        end = text.index(TOC_END, start) + len(TOC_END)
        text = text[:start] + block + text[end:]
    else:
        anchor = "CombatBoot.lua" + nl
        if anchor not in text:
            raise SystemExit("Ready2Quest.toc : CombatBoot.lua introuvable (le bloc Combat se pose après lui)")
        text = text.replace(anchor, anchor + block + nl, 1)
    with open(TOC_PATH, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    src = os.path.abspath(sys.argv[1])
    files = [p for p in toc_files(src) if wanted(p)]
    if os.path.isdir(DEST):
        shutil.rmtree(DEST)
    os.makedirs(DEST)
    for path in files:
        with open(os.path.join(src, path), encoding="utf-8") as f:
            text = f.read()
        out = os.path.join(DEST, path)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8", newline="\n") as f:
            f.write(transform(text, path))
    for rel in TEXTURE_DIRS:
        if os.path.isdir(os.path.join(src, rel)):
            shutil.copytree(os.path.join(src, rel), os.path.join(DEST, rel))
    for rel in LICENSES:
        out = os.path.join(DEST, rel)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        shutil.copyfile(os.path.join(src, rel), out)
    with open(os.path.join(DEST, "files.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(files) + "\n")
    update_toc(files)
    commit = subprocess.run(["git", "-C", src, "log", "-1", "--format=%H %cs %s"],
                            capture_output=True, text=True).stdout.strip()
    with open(os.path.join(DEST, "UPSTREAM.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("https://github.com/Ironship/UsefulPlatesAndTooltips\n%s\n" % commit)
    print("Combat : %d fichiers importés (%s)" % (len(files), commit[:7]))


if __name__ == "__main__":
    main()
