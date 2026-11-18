#!/usr/bin/env python3
"""Textes à traduire et traductions espagnoles (socle 3.6).

  python3 tools/i18n.py export <dossier>   chaque clé de chaque addon : fr, en
      (et es si déjà traduite), par lots JSON de ~N mots, pour la traduction
  python3 tools/i18n.py import <dossier>   les lots traduits (<lot>.es.json :
      { clé: texte }) -> Ready2Quest/Locales_es.lua, QuestCompanion/Locales_es.lua
  python3 tools/i18n.py fit                les réglages des deux addons ouverts
      sur un client espagnol : ce qui ne tient pas à sa place
  python3 tools/i18n.py check              clés sans espagnol, %s/%d ou codes
      (|c, |r, |T, |A, \\n) différents de l'anglais

Les tables viennent du harnais de test (tests/run_tests.lua, mode I18N_DUMP),
qui charge les deux addons et tous leurs modules comme en jeu.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.environ.get("LUA_PYLIB", "/tmp/pylib"))
from lupa.lua51 import LuaRuntime  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDONS = {"r2q": "Ready2Quest", "qc": "QuestCompanion"}
# clés qui ne se traduisent pas (marque, codes) : l'anglais sert tel quel
SKIP = re.compile(r"^(TAG|BRAND)$")
CHUNK_WORDS = int(os.environ.get("I18N_CHUNK_WORDS", "2500"))


def load(locale=None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ADDON_ROOT = ROOT
    g.MODULE_TEST_FILES = lua.table_from([])
    g.I18N_DUMP = True
    if locale:
        g.TEST_LOCALE = locale
    with open(os.path.join(ROOT, "tests", "run_tests.lua"), encoding="utf-8") as f:
        lua.execute(f.read())
    return lua, g


# Les réglages des deux addons ouverts en espagnol : chaque libellé, valeur,
# phrase, onglet et entrée de la colonne tient à sa place (même mesure que
# tests/modules/options.lua, 6,4 px par octet : prudente pour les accents)
FIT_LUA = """
local problems = {}
local function Add(text) problems[#problems + 1] = tostring(text) end
for short, ns in pairs(I18N_NS) do
	local lay = ns.OPT_LAYOUT
	ns.optionsFrame = nil
	ns:ToggleOptions()
	local frame = ns.optionsFrame
	for _, row in ipairs(frame.rows) do
		if row.truncated or (row.labelWidth or 0) > (row.labelRoom or 1e9) then Add(short .. " carte: " .. tostring(row.labelText)) end
		if row.dropdown then
			for _, entry in ipairs(row.dropdown.options or {}) do
				row.dropdown.text:SetText(entry.label)
				if row.dropdown.text:GetStringWidth() > row.dropdown.width - 30 then Add(short .. " liste: " .. tostring(entry.label)) end
			end
		end
		if row.button and row.button.text and row.button.text.GetStringWidth and row.button.GetWidth then
			if row.button.text:GetStringWidth() > (row.button:GetWidth() or 1e9) - 8 then Add(short .. " bouton: " .. tostring(row.button.text.text)) end
		end
	end
	for id in pairs(frame.pages) do
		ns:SelectOptionsPage(id)
		if frame.header.subtitle:GetStringWidth() > (frame.header.subtitle.width or lay.inner) then Add(short .. " phrase " .. id .. ": " .. tostring(frame.header.subtitle.text)) end
		if frame.tabs:IsShown() and frame.tabs.used > lay.inner then Add(short .. " onglets " .. id) end
	end
	for _, nav in ipairs(frame.navButtons) do
		if nav.label:GetStringWidth() > nav.label.width then Add(short .. " colonne: " .. tostring(nav.label.text)) end
		if nav.sub and nav.sub:GetStringWidth() > nav.sub.width then Add(short .. " sous-libellé: " .. tostring(nav.sub.text)) end
	end
	for _, head in ipairs(frame.heads or {}) do
		if head.phrase and head.phrase:GetStringWidth() > head.phrase.width then Add(short .. " tête: " .. tostring(head.phrase.text)) end
	end
	for _, line in ipairs(frame.dashLines or {}) do
		if line.label:GetStringWidth() > line.label.width then Add(short .. " vue: " .. tostring(line.label.text)) end
	end
	frame:Hide()
end
return problems
"""


def fit():
    lua, g = load("esES")
    problems = list(lua.execute(FIT_LUA).values())
    for line in problems:
        print("  ne tient pas :", line)
    print("%d texte(s) qui ne tiennent pas (réglages, en espagnol)" % len(problems))
    return len(problems)


def dump():
    lua, g = load()
    out = {}
    for short in ADDONS:
        tables = g.I18N_RESULT[short]
        langs = {}
        for lang in ("fr", "en", "es"):
            t = tables[lang]
            langs[lang] = {k: v for k, v in t.items() if isinstance(v, str)} if t else {}
        out[short] = langs
    return out


def words(text):
    return len(re.findall(r"[^\W\d_]+", text or ""))


def export(folder):
    os.makedirs(folder, exist_ok=True)
    data = dump()
    seen = {}   # même clé et même anglais dans les deux addons (socle) : traduite une fois
    for short, langs in data.items():
        fr, en, es = langs["fr"], langs["en"], langs["es"]
        keys = sorted(set(fr) | set(en))
        chunk, size, index = {}, 0, 1
        def flush():
            nonlocal chunk, size, index
            if chunk:
                with open(os.path.join(folder, "%s-%03d.json" % (short, index)), "w", encoding="utf-8") as f:
                    json.dump(chunk, f, ensure_ascii=False, indent=1)
                index += 1
            chunk, size = {}, 0
        total = 0
        for key in keys:
            if SKIP.match(key) or key in es:
                continue
            src_en = en.get(key)
            src_fr = fr.get(key)
            if src_en is None and src_fr is None:
                continue
            sig = (key, src_en)
            if sig in seen:
                continue
            seen[sig] = short
            chunk[key] = {"en": src_en, "fr": src_fr}
            n = words(src_en or src_fr)
            size += n
            total += n
            if size >= CHUNK_WORDS:
                flush()
        flush()
        print("%s : %d mots à traduire, %d lots" % (ADDONS[short], total, index - 1))


LUA_HEAD = """-- Locales_es.lua -- textes en espagnol (esES, esMX) de {name}
--
-- Écrit par tools/i18n.py import : les textes déjà ici, plus ceux des lots
-- traduits (export des clés sans espagnol, traduction, import). Une retouche à
-- la main tient (l'import repart de ce fichier), mais garde l'ordre des clés.
-- Seul un client espagnol (ou les tests) garde ces textes ; une clé absente
-- d'ici retombe sur l'anglais.
local ADDON, ns = ...
if ns.blocked then return end
if not (ns.STRINGS_SPANISH or ns.KEEP_STRINGS) then return end
if not ns.RegisterLocaleStrings then return end

"""


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def import_(folder):
    data = dump()
    # les traductions déjà en place (Locales_es.lua) restent ; les lots les
    # complètent ou les remplacent clé par clé
    translated = {short: dict(data[short]["es"]) for short in ADDONS}
    shared = {}
    for name in sorted(os.listdir(folder)):
        m = re.match(r"(r2q|qc)-\d+\.es\.json$", name)
        if not m:
            continue
        with open(os.path.join(folder, name), encoding="utf-8") as f:
            part = json.load(f)
        for key, text in part.items():
            if isinstance(text, str):
                translated[m.group(1)][key] = text
                shared[key] = text
    for short, name in ADDONS.items():
        langs = data[short]
        own = dict(translated[short])
        # clés du socle traduites dans l'autre addon (même anglais) : reprises ici
        for key in set(langs["fr"]) | set(langs["en"]):
            if key not in own and key in shared:
                own[key] = shared[key]
        lines = [LUA_HEAD.format(name=name), "ns.RegisterLocaleStrings(\"es\", {"]
        for key in sorted(own):
            lines.append("\t[%s] = %s," % (lua_string(key), lua_string(own[key])))
        lines.append("})")
        lines.append("")
        if short == "qc":
            lines.extend(qc_extras(folder))
        lines.append("if ns.Mark then ns.Mark(\"Locales_es\") end")
        path = os.path.join(ROOT, name, "Locales_es.lua")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        print("%s : %d textes espagnols" % (path, len(own)))


# titres sur deux lignes dans FeatsTitles.lua (le lot misc ne les a pas)
MANUAL_TITLES = {
    "35": {"m": "%s, Señor de las criaturas", "f": "%s, Señora de las criaturas"},
    "37": {"m": "%s, Héroe de Azeroth", "f": "%s, Heroína de Azeroth"},
}


def qc_extras(folder):
    """Groupes du juke-box et titres (misc-001.es.json) ; l'histoire des lieux
    (lore-001.es.json) va dans data/forever/lore/lore_es.json pour gen_lore.py."""
    out = []
    misc = os.path.join(folder, "misc-001.es.json")
    if os.path.exists(misc):
        part = json.load(open(misc, encoding="utf-8"))
        music = sorted(((int(k.split(":")[1]), v) for k, v in part.items() if k.startswith("MUSIC:")))
        out.append("-- groupes du juke-box (ns.MUSIC_GROUPS, même ordre) et titres des hauts faits")
        out.append("ns.MUSIC_GROUPS_ES = {")
        for _, text in music:
            out.append("\t%s," % lua_string(text))
        out.append("}")
        titles = {k.split(":")[1]: v for k, v in part.items() if k.startswith("TITLE:")}
        titles.update({k: v for k, v in MANUAL_TITLES.items() if k not in titles})
        out.append("ns.FEAT_TITLES_ES = {")
        for code in sorted(titles, key=int):
            t = titles[code]
            out.append("\t[%s] = { m = %s, f = %s }," % (code, lua_string(t["m"]), lua_string(t.get("f") or t["m"])))
        out.append("}")
        out.append("")
    lore = os.path.join(folder, "lore-001.es.json")
    if os.path.exists(lore):
        texts = json.load(open(lore, encoding="utf-8"))
        path = os.path.join(ROOT, "data", "forever", "lore", "lore_es.json")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(texts, f, ensure_ascii=False, indent=1, sort_keys=True)
            f.write("\n")
    return out


CODES = re.compile(r"%[-+ #0]*\d*(?:\.\d+)?[sdifgxXcq%]|\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t|\|A[^|]*\|a|\\n|\n|\|n")


def codes(text):
    return sorted(CODES.findall(text or ""))


def check():
    data = dump()
    problems = 0
    for short, name in ADDONS.items():
        fr, en, es = data[short]["fr"], data[short]["en"], data[short]["es"]
        missing = [k for k in sorted(set(fr) | set(en)) if k not in es and not SKIP.match(k)]
        bad = []
        for key, text in es.items():
            ref = en.get(key) or fr.get(key)
            if ref is not None and codes(ref) != codes(text):
                bad.append(key)
        print("%s : %d clés, %d sans espagnol, %d codes différents" % (name, len(set(fr) | set(en)), len(missing), len(bad)))
        for key in missing[:20]:
            print("  manque", key)
        for key in bad[:40]:
            print("  codes", key, codes(en.get(key) or fr.get(key)), "->", codes(es[key]))
        problems += len(missing) + len(bad)
    return problems


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    cmd = sys.argv[1]
    if cmd == "export":
        export(sys.argv[2])
    elif cmd == "import":
        import_(sys.argv[2])
    elif cmd == "check":
        raise SystemExit(1 if check() else 0)
    elif cmd == "fit":
        raise SystemExit(1 if fit() else 0)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
