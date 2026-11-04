#!/usr/bin/env python3
"""Importe la base de Questie dans NOTRE base de données (data/), une fois.

Ready2Quest et QuestCompanion ne dépendent pas de Questie : ni en jeu (rien
n'est lu pendant la partie), ni pour générer leurs fichiers. Les générateurs
(tools/gen_zone_data.py, tools/gen_places.py) ne lisent que data/, qui est
NOTRE base : versionnée dans ce dépôt, corrigée et complétée ici.

Ce script sert à la remplir au départ, ou à y reprendre plus tard ce que
Questie aurait ajouté (nouveautés de Forever). Il écrit, pour chaque client
(data/era/, data/forever/) :
    npcs.jsonl      PNJ et créatures : noms (en, fr), niveaux, rang, faction,
                    services (npcFlags), apparitions par zone, quêtes
    objects.jsonl   objets du monde (nœuds de récolte, boîtes aux lettres…)
    quests.jsonl    quêtes : noms, niveaux, races, classes, donneurs, suites,
                    drapeaux « cachée » et « événement saisonnier »
    zones.json      zone de jeu (areaID) -> carte (uiMapID), sous-zone -> zone
    source.json     provenance : commit QuestieDB, version de Questie, couches
Une entité par ligne, triées par identifiant : les différences se relisent.
Les corrections faites à la main dans data/ sont dans data/<client>/fixes.json :
elles ne sont jamais écrasées par un nouvel import (voir docs/DONNEES.md).

Usage :
    python3 -I tools/import_questie.py /chemin/vers/QuestieDB --questie-src /chemin/vers/Questie
        [--flavor classic|forever|all] [--commit SHA] [--questie 12.4.0] [--date AAAA-MM-JJ]

Sources lues (chemins relatifs à la racine de QuestieDB, <F> = Classic ou
Forever, <f> = classic ou forever) :
    data/<F>/<f>QuestDB.lua / <f>NpcDB.lua / <f>ObjectDB.lua   données brutes
    l10n/<F>/lookupQuests|lookupNpcs|lookupObjects/frFR.lua    noms français
    support/Zones/*.lua (Era), support/Forever/Zones/*.lua      areaID -> uiMapID,
                                                                sous-zone -> zone
    src/corrections/enum/*.lua, src/corrections/Era|Forever/... corrections
        statiques (Load), dans l'ordre de src/config.lua et docs/forever.md
Questie/Questie (--questie-src) : QuestieQuestBlacklist.lua (quêtes cachées),
Holidays/quests/*.lua (quêtes d'événements saisonniers).

Licence : la base de Questie est sous GPL-3.0 ; ce qui en est importé le reste
(voir NOTICE.md de chaque addon). Aucune dépendance externe : un petit
évaluateur Lua suffit. Sortie déterministe.
"""
import argparse
import datetime
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

# ---------------------------------------------------------------------------
# Évaluateur Lua minimal
# ---------------------------------------------------------------------------
class _Unresolved(object):
    """Valeur impossible à calculer hors du jeu (appel de fonction, nom inconnu)."""
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = object.__new__(cls)
        return cls._instance

    def __repr__(self):
        return "<non résolu>"


UNRESOLVED = _Unresolved()
VARARG = object()

TOKEN = re.compile(r"""
    (?P<ws>\s+)
  | (?P<lc>--\[(?P<lceq>=*)\[.*?\](?P=lceq)\])
  | (?P<c>--[^\n]*)
  | (?P<ls>\[(?P<lseq>=*)\[.*?\](?P=lseq)\])
  | (?P<s>"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')
  | (?P<n>0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?)
  | (?P<i>[A-Za-z_]\w*)
  | (?P<p>\.\.\.|\.\.|==|~=|<=|>=|[-+*/%^\#<>=(){}\[\];:,.])
""", re.S | re.X)

ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "\n": "\n", "a": "\a", "b": "\b",
           "f": "\f", "v": "\v"}
KEYWORDS = {"and", "or", "not", "nil", "true", "false", "function", "end", "local", "return", "if", "then",
            "else", "elseif", "for", "do", "while", "repeat", "until", "in", "break"}


def _unescape(body):
    if "\\" not in body:
        return body
    out, i = [], 0
    while i < len(body):
        ch = body[i]
        if ch != "\\":
            out.append(ch)
            i += 1
            continue
        nxt = body[i + 1]
        if nxt.isdigit():
            m = re.match(r"\d{1,3}", body[i + 1:])
            out.append(chr(int(m.group(0))))
            i += 1 + len(m.group(0))
        else:
            out.append(ESCAPES.get(nxt, nxt))
            i += 2
    return "".join(out)


def tokenize(text, pos=0):
    out = []
    end = len(text)
    match = TOKEN.match
    while pos < end:
        m = match(text, pos)
        if not m:
            raise ValueError("lecteur Lua : caractère inattendu à %d : %r" % (pos, text[pos:pos + 40]))
        pos = m.end()
        kind = m.lastgroup
        if kind in ("ws", "c", "lc", "lceq"):
            continue
        if kind in ("ls", "lseq"):
            raw = m.group("ls")
            eq = len(m.group("lseq"))
            body = raw[2 + eq:-(2 + eq)]
            if body.startswith("\n"):
                body = body[1:]
            out.append(("s", body))
        elif kind == "s":
            out.append(("s", _unescape(m.group("s")[1:-1])))
        elif kind == "n":
            tok = m.group("n")
            if tok[:2] in ("0x", "0X"):
                out.append(("n", int(tok, 16)))
            elif "." in tok or "e" in tok or "E" in tok:
                out.append(("n", float(tok)))
            else:
                out.append(("n", int(tok)))
        elif kind == "i":
            tok = m.group("i")
            out.append(("k" if tok in KEYWORDS else "i", tok))
        else:
            out.append(("p", m.group("p")))
    out.append(("eof", None))
    return out


def truthy(value):
    return not (value is None or value is False)


def _num(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _arith(op, a, b):
    if not (_num(a) and _num(b)):
        return UNRESOLVED
    if op == "+":
        return a + b
    if op == "-":
        return a - b
    if op == "*":
        return a * b
    if op == "/":
        return a / b if b else UNRESOLVED
    if op == "%":
        return a % b if b else UNRESOLVED
    if op == "^":
        return a ** b
    return UNRESOLVED


def _compare(op, a, b):
    if a is UNRESOLVED or b is UNRESOLVED:
        return UNRESOLVED
    if op == "==":
        return a == b and type(a) is type(b) or (_num(a) and _num(b) and a == b)
    if op == "~=":
        return not (a == b and type(a) is type(b) or (_num(a) and _num(b) and a == b))
    if not ((_num(a) and _num(b)) or (isinstance(a, str) and isinstance(b, str))):
        return UNRESOLVED
    return {"<": a < b, "<=": a <= b, ">": a > b, ">=": a >= b}[op]


BINARY = {
    "or": 1, "and": 2,
    "<": 3, ">": 3, "<=": 3, ">=": 3, "~=": 3, "==": 3,
    "..": 4,
    "+": 5, "-": 5,
    "*": 6, "/": 6, "%": 6,
    "^": 8,
}
UNARY_PRIORITY = 7


class LuaEval(object):
    """Évalue des expressions Lua sur une liste de jetons, dans un environnement donné."""

    def __init__(self, tokens, env, index=0):
        self.t = tokens
        self.i = index
        self.env = env

    def peek(self, offset=0):
        return self.t[self.i + offset]

    def take(self):
        tok = self.t[self.i]
        self.i += 1
        return tok

    def expect(self, kind, value):
        tok = self.take()
        if tok != (kind, value):
            raise ValueError("lecteur Lua : %r attendu, %r trouvé" % (value, tok))

    def lookup(self, name):
        for scope in self.env:
            if name in scope:
                return scope[name]
        return UNRESOLVED

    # expr ----------------------------------------------------------------
    def expr(self, limit=0):
        kind, tok = self.peek()
        if (kind == "k" and tok == "not") or (kind == "p" and tok in ("-", "#")):
            self.take()
            operand = self.expr(UNARY_PRIORITY)
            if tok == "not":
                left = UNRESOLVED if operand is UNRESOLVED else (not truthy(operand))
            elif tok == "-":
                left = -operand if _num(operand) else UNRESOLVED
            else:
                left = len(operand) if isinstance(operand, (str, dict)) else UNRESOLVED
        else:
            left = self.simple()
        while True:
            kind, tok = self.peek()
            op = tok if kind in ("p", "k") else None
            prio = BINARY.get(op)
            if prio is None or prio <= limit:
                return left
            self.take()
            # ^ et .. sont associatifs à droite
            right = self.expr(prio - 1 if op in ("^", "..") else prio)
            if op == "or":
                left = UNRESOLVED if left is UNRESOLVED else (left if truthy(left) else right)
            elif op == "and":
                left = UNRESOLVED if left is UNRESOLVED else (right if truthy(left) else left)
            elif op in ("==", "~=", "<", "<=", ">", ">="):
                left = _compare(op, left, right)
            elif op == "..":
                if isinstance(left, (str, int, float)) and isinstance(right, (str, int, float)) \
                        and not isinstance(left, bool) and not isinstance(right, bool):
                    left = str(left) + str(right)
                else:
                    left = UNRESOLVED
            else:
                left = _arith(op, left, right)

    def simple(self):
        kind, tok = self.take()
        if kind == "n" or kind == "s":
            return tok
        if kind == "k":
            if tok == "nil":
                return None
            if tok == "true":
                return True
            if tok == "false":
                return False
            if tok == "function":
                self.skip_function_body()
                return UNRESOLVED
            raise ValueError("lecteur Lua : mot-clé inattendu %r" % tok)
        if kind == "p" and tok == "{":
            return self.suffixes(self.table())
        if kind == "p" and tok == "...":
            return VARARG
        if kind == "p" and tok == "(":
            value = self.expr()
            self.expect("p", ")")
            return self.suffixes(value)
        if kind == "i":
            return self.suffixes(self.lookup(tok))
        raise ValueError("lecteur Lua : jeton inattendu %r" % (tok,))

    def suffixes(self, value):
        while True:
            kind, tok = self.peek()
            if kind == "p" and tok == ".":
                self.take()
                _, name = self.take()
                value = value.get(name) if isinstance(value, dict) else UNRESOLVED
            elif kind == "p" and tok == "[":
                self.take()
                key = self.expr()
                self.expect("p", "]")
                value = value.get(key) if isinstance(value, dict) and key is not UNRESOLVED else UNRESOLVED
            elif kind == "p" and tok == ":":
                self.take()
                self.take()
                self.call_args()
                value = UNRESOLVED
            elif (kind == "p" and tok in ("(", "{")) or kind == "s":
                self.call_args()
                value = UNRESOLVED
            else:
                return value

    def call_args(self):
        kind, tok = self.peek()
        if kind == "s":
            self.take()
            return
        if kind == "p" and tok == "{":
            self.take()
            self.table()
            return
        self.expect("p", "(")
        if self.peek() != ("p", ")"):
            self.expr()
            while self.peek() == ("p", ","):
                self.take()
                self.expr()
        self.expect("p", ")")

    def skip_function_body(self):
        depth = 1
        while depth:
            kind, tok = self.take()
            if kind == "eof":
                raise ValueError("lecteur Lua : fin de fonction introuvable")
            if kind == "k" and tok in ("function", "do", "then", "repeat"):
                # « while … do », « for … do », « if … then » ouvrent un bloc fermé par end ;
                # « elseif … then » n'en ouvre pas ; repeat se ferme par until
                if tok == "then" and self._last_if_was_elseif():
                    continue
                depth += 1
            elif kind == "k" and tok in ("end", "until"):
                depth -= 1

    def _last_if_was_elseif(self):
        j = self.i - 2
        while j >= 0:
            kind, tok = self.t[j]
            if kind == "k" and tok in ("if", "elseif"):
                return tok == "elseif"
            j -= 1
        return False

    def table(self):
        result, position = {}, 1
        while True:
            kind, tok = self.peek()
            if kind == "p" and tok == "}":
                self.take()
                return result
            if kind == "p" and tok == "[":
                self.take()
                key = self.expr()
                self.expect("p", "]")
                self.expect("p", "=")
                value = self.expr()
                if key is not None and key is not UNRESOLVED and value is not None:
                    result[key] = value
            elif kind == "i" and self.peek(1) == ("p", "="):
                self.take()
                self.take()
                value = self.expr()
                if value is not None:
                    result[tok] = value
            else:
                value = self.expr()
                if value is not None and value is not VARARG:
                    result[position] = value
                position += 1
            kind, tok = self.peek()
            if kind == "p" and tok in ",;":
                self.take()

    # instructions (fichiers de constantes) -----------------------------
    def run(self):
        """Exécute une suite d'affectations ; les fonctions et blocs sont sautés."""
        scope = self.env[0]
        while self.peek()[0] != "eof":
            kind, tok = self.peek()
            if kind == "k" and tok == "local":
                self.take()
                if self.peek() == ("k", "function"):
                    self.take()
                    self.take()
                    self.skip_params_and_body()
                    continue
                names = [self.take()[1]]
                while self.peek() == ("p", ","):
                    self.take()
                    names.append(self.take()[1])
                if self.peek() == ("p", "="):
                    self.take()
                    values = [self.expr()]
                    while self.peek() == ("p", ","):
                        self.take()
                        values.append(self.expr())
                    # « local _, Lib = ... » : les noms reçus de l'addon gardent leur valeur
                    pad = VARARG if values[-1] is VARARG else None
                    for index, name in enumerate(names):
                        value = values[index] if index < len(values) else pad
                        if value is not VARARG and (name not in scope or value is not UNRESOLVED):
                            scope[name] = value
            elif kind == "k" and tok == "function":
                self.take()
                while self.peek() != ("p", "("):
                    self.take()
                self.skip_params_and_body()
            elif kind == "k" and tok in ("if", "for", "while", "do"):
                self.take()
                if tok in ("for", "while"):
                    while self.take() != ("k", "do"):
                        pass
                self.skip_block()
            elif kind == "k" and tok == "return":
                return
            elif kind == "i":
                self.assignment()
            elif kind == "p" and tok == ";":
                self.take()
            else:
                raise ValueError("lecteur Lua : instruction inattendue %r" % (tok,))

    def skip_params_and_body(self):
        self.expect("p", "(")
        while self.take() != ("p", ")"):
            pass
        self.skip_function_body()

    def skip_block(self):
        depth = 1
        while depth:
            kind, tok = self.take()
            if kind == "eof":
                raise ValueError("lecteur Lua : bloc non fermé")
            if kind == "k" and tok in ("function", "if", "for", "while", "repeat") and not (
                    tok in ("for", "while")):
                depth += 1
            elif kind == "k" and tok in ("for", "while"):
                depth += 1
                while self.peek() != ("k", "do"):
                    self.take()
                self.take()
            elif kind == "k" and tok == "do":
                depth += 1
            elif kind == "k" and tok in ("end", "until"):
                depth -= 1

    def assignment(self):
        # cible : nom(.champ|[clé])*  puis « = expr » ; sinon appel ignoré
        _, name = self.take()
        target, key = self.env[0], name
        container = None
        path = []
        while True:
            kind, tok = self.peek()
            if kind == "p" and tok == ".":
                self.take()
                path.append(self.take()[1])
            elif kind == "p" and tok == "[":
                self.take()
                path.append(self.expr())
                self.expect("p", "]")
            elif (kind == "p" and tok in ("(", "{", ":")) or kind == "s":
                if tok == ":":
                    self.take()
                    self.take()
                self.call_args()
                return
            else:
                break
        self.expect("p", "=")
        value = self.expr()
        if not path:
            scope = self.env[0]
            for candidate in self.env:
                if name in candidate:
                    scope = candidate
                    break
            scope[name] = value
            return
        container = self.lookup(name)
        for part in path[:-1]:
            container = container.get(part) if isinstance(container, dict) else None
        if isinstance(container, dict) and path[-1] is not UNRESOLVED:
            container[path[-1]] = value


def has_unresolved(value):
    if value is UNRESOLVED:
        return True
    if isinstance(value, dict):
        return any(has_unresolved(v) for v in value.values())
    return False


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def eval_expr(text, env, start=0):
    tokens = tokenize(text, start)
    return LuaEval(tokens, env).expr()


def lua_blocks(path):
    """Tables « X = [[return { … }]] » (ou loadstring) d'un fichier : {nom: table}."""
    text = read(path)
    blocks = {}
    for m in re.finditer(r"([\w\.\[\]\"']+)\s*=\s*(?:loadstring\()?\[\[return\s*(\{.*?\n\})\]\]", text, re.S):
        blocks[m.group(1)] = eval_expr(m.group(2), [{}])
    return blocks, text


def lua_keys(text, name):
    """QuestieDB.npcKeys = { ['name'] = 1, … } -> {'name': 1, …}"""
    m = re.search(re.escape(name) + r"\s*=\s*\{(.*?)\n\}", text, re.S)
    if not m:
        raise ValueError("clés %s introuvables" % name)
    return {k: int(v) for k, v in re.findall(r"\['(\w+)'\]\s*=\s*(\d+)", m.group(1))}


# ---------------------------------------------------------------------------
# Constantes des corrections (src/corrections/enum)
# ---------------------------------------------------------------------------
ENUM_FILES = ["expansions.lua", "quests.lua", "zones.lua", "professions.lua", "factions.lua", "items.lua",
              "phases.lua", "waypoints.lua"]


def load_enums(root):
    constants = {}
    scope = {"LibQuestieDB": {"Enum": constants}}
    for name in ENUM_FILES:
        path = os.path.join(root, "src/corrections/enum", name)
        if not os.path.exists(path):
            continue
        local = {}
        LuaEval(tokenize(read(path)), [local, scope]).run()
    return constants


class FieldKeys(dict):
    """questKeys & co : name -> index ; X_add / X_remove -> (index, "add"|"remove")."""

    def __init__(self, keys):
        dict.__init__(self, keys)
        for name, index in keys.items():
            self[name + "_add"] = (index, "add")
            self[name + "_remove"] = (index, "remove")


def correction_env(enums, flavor_expansion, keys):
    by = enums.get("byExpansion", {})
    classic = by.get("Classic", {})
    own = by.get(flavor_expansion, {})
    db = {
        "questKeys": keys.get("quest"), "npcKeys": keys.get("npc"), "objectKeys": keys.get("object"),
        "itemKeys": {}, "raceKeys": own.get("raceKeys") or classic.get("raceKeys"),
        "classKeys": own.get("classKeys") or classic.get("classKeys"),
        "npcFlags": own.get("npcFlags") or classic.get("npcFlags"),
        "sortKeys": enums.get("sortKeys"), "specialFlags": enums.get("specialFlags"),
        "questFlags": enums.get("questFlags"), "factionIDs": enums.get("factionIDs"),
        "waypointPresets": enums.get("waypointPresets"), "itemClasses": enums.get("itemClasses"),
    }
    prof = {"professionKeys": enums.get("professionKeys"), "specializationKeys": enums.get("specializationKeys"),
            "rankNames": enums.get("rankNames")}
    scope = {
        "QuestieDB": db, "ZoneDB": {"zoneIDs": enums.get("zoneIDs")}, "QuestieProfessions": prof,
        "Phasing": {"phases": enums.get("phases")},
        "questKeys": db["questKeys"], "npcKeys": db["npcKeys"], "objectKeys": db["objectKeys"],
        "itemKeys": {}, "zoneIDs": enums.get("zoneIDs"), "raceIDs": db["raceKeys"], "classIDs": db["classKeys"],
        "sortKeys": db["sortKeys"], "specialFlags": db["specialFlags"], "profKeys": prof["professionKeys"],
        "specKeys": prof["specializationKeys"], "factionIDs": db["factionIDs"], "rankKeys": prof["rankNames"],
        "npcFlags": db["npcFlags"], "waypointPresets": db["waypointPresets"], "phases": enums.get("phases"),
        "itemClasses": db["itemClasses"],
    }
    return scope


def load_corrections(path, env, function="Load"):
    """Table rendue par « function X:Load() … return { … } » d'un fichier de corrections."""
    text = read(path)
    m = re.search(r"^function\s+[\w\.]+[:.]" + function + r"\s*\(\s*\)", text, re.M)
    if not m:
        return {}
    r = re.compile(r"^\s*return\s*\{", re.M).search(text, m.end())
    if not r:
        return {}
    start = text.index("{", r.start())
    value = eval_expr(text, [dict(env)], start)
    return value if isinstance(value, dict) else {}


def _merge_add(old, new):
    """Ajout à une liste ({a, b}), à un tuple de listes ({nil, {…}}) ou à des apparitions ({[zone] = …})."""
    if not isinstance(new, dict):
        return new
    if not isinstance(old, dict):
        return new
    out = dict(old)
    values = list(old.values())
    is_list = all(isinstance(k, int) for k in old) and all(not isinstance(v, dict) for v in values) \
        and all(not isinstance(v, dict) for v in new.values())
    if is_list:
        position = (max(old) if old else 0)
        for v in new.values():
            if v not in values:
                position += 1
                out[position] = v
                values.append(v)
        return out
    for k, v in new.items():
        out[k] = _merge_add(old.get(k), v) if isinstance(v, dict) and isinstance(old.get(k), dict) else v
    return out


def _merge_remove(old, new):
    if not isinstance(old, dict) or not isinstance(new, dict):
        return old
    if all(not isinstance(v, dict) for v in new.values()):
        drop = set(new.values())
        kept = [v for _, v in sorted(old.items()) if not (not isinstance(v, dict) and v in drop)]
        return {index + 1: v for index, v in enumerate(kept)}
    out = dict(old)
    for k, v in new.items():
        if k in out:
            out[k] = _merge_remove(out[k], v)
    return out


def apply_corrections(data, corrections, stats):
    """Applique une couche { [id] = { [champ] = valeur } } ; compte ce qui est ignoré."""
    for entity_id, fields in sorted(corrections.items(), key=lambda kv: str(kv[0])):
        if not isinstance(entity_id, int) or not isinstance(fields, dict):
            stats["ignored"] = stats.get("ignored", 0) + 1
            continue
        row = data.get(entity_id)
        if row is None:
            row = {}
            data[entity_id] = row
            stats["new"] = stats.get("new", 0) + 1
        for field, value in fields.items():
            if has_unresolved(value):
                stats["unresolved"] = stats.get("unresolved", 0) + 1
                continue
            if isinstance(field, tuple):
                index, mode = field
                row[index] = _merge_add(row.get(index), value) if mode == "add" \
                    else _merge_remove(row.get(index), value)
            elif isinstance(field, int):
                row[field] = value
            stats["fields"] = stats.get("fields", 0) + 1
    return data


# ---------------------------------------------------------------------------
# Clients
# ---------------------------------------------------------------------------
FLAVORS = {
    "classic": {
        "name": "Era", "dir": "Classic", "prefix": "classic", "expansion": "Classic", "support": "support/Zones",
        "forever": False,
        "layers": {
            "quest": [("src/corrections/Era/classicQuestFixes.lua", "corrections Era (classicQuestFixes)")],
            "npc": [], "object": [],
        },
    },
    "forever": {
        "name": "Forever", "dir": "Forever", "prefix": "forever", "expansion": "Forever",
        "support": "support/Forever/Zones", "forever": True,
        "layers": {
            "quest": [("src/corrections/Forever/legacy/classicQuestFixes.lua", "legacy (corrections Era héritées)"),
                      ("src/corrections/Forever/generated/foreverBaseQuest.lua", "delta-base générée"),
                      ("src/corrections/Forever/traces/foreverQuestTraces.lua", "traces"),
                      ("src/corrections/Forever/foreverQuestFixes.lua", "corrections Forever")],
            "npc": [("src/corrections/Forever/legacy/classicNPCFixes.lua", "legacy (corrections Era héritées)"),
                    ("src/corrections/Forever/generated/foreverBaseNpc.lua", "delta-base générée"),
                    ("src/corrections/Forever/traces/foreverNpcTraces.lua", "traces"),
                    ("src/corrections/Forever/foreverNPCFixes.lua", "corrections Forever")],
            "object": [("src/corrections/Forever/legacy/classicObjectFixes.lua", "legacy (corrections Era héritées)"),
                       ("src/corrections/Forever/generated/foreverBaseObject.lua", "delta-base générée"),
                       ("src/corrections/Forever/traces/foreverObjectTraces.lua", "traces"),
                       ("src/corrections/Forever/foreverObjectFixes.lua", "corrections Forever")],
        },
    },
}

# ---------------------------------------------------------------------------
# Zones : areaID (clé des spawns, zoneOrSort) -> uiMapID
# ---------------------------------------------------------------------------
def zone_tables(root, support):
    blocks, _ = lua_blocks(os.path.join(root, support, "areaIdToUiMapId.lua"))
    area_to_map = dict(blocks["ZoneDB.private.areaIdToUiMapId"])
    area_to_map.update(blocks["ZoneDB.private.areaIdToUiMapIdOverride"])
    blocks, _ = lua_blocks(os.path.join(root, support, "subZoneToParentZone.lua"))
    parent = dict(blocks["ZoneDB.private.subZoneToParentZone"])
    parent.update(blocks["ZoneDB.private.subZoneToParentZoneOverride"])

    return area_to_map, parent


# ---------------------------------------------------------------------------
# Lecture d'un type d'entité : brut + couches
# ---------------------------------------------------------------------------
DB_FILES = {"quest": ("QuestDB", "questKeys", "questData"), "npc": ("NpcDB", "npcKeys", "npcData"),
            "object": ("ObjectDB", "objectKeys", "objectData")}


def load_raw(root, flavor, kind):
    suffix, keys_name, data_name = DB_FILES[kind]
    path = os.path.join(root, "data", flavor["dir"], flavor["prefix"] + suffix + ".lua")
    blocks, text = lua_blocks(path)
    keys = lua_keys(text, "QuestieDB." + keys_name)
    return blocks["QuestieDB." + data_name], keys


def load_entities(root, flavor, enums, stats):
    """{kind: (data, keys)} avec les couches statiques du client appliquées."""
    raw = {kind: load_raw(root, flavor, kind) for kind in ("quest", "npc", "object")}
    keys = {kind: FieldKeys(raw[kind][1]) for kind in raw}
    env = correction_env(enums, flavor["expansion"], keys)
    for kind in ("quest", "npc", "object"):
        data = raw[kind][0]
        for rel, label in flavor["layers"][kind]:
            path = os.path.join(root, rel)
            if not os.path.exists(path):
                raise SystemExit("ERREUR : couche introuvable %s" % rel)
            layer_stats = stats.setdefault((kind, label), {})
            apply_corrections(data, load_corrections(path, env), layer_stats)
    return {kind: (raw[kind][0], raw[kind][1]) for kind in raw}


def load_fr(root, flavor, lookup):
    blocks, _ = lua_blocks(os.path.join(root, "l10n", flavor["dir"], lookup, "frFR.lua"))
    return next(iter(blocks.values())) if blocks else {}


def load_questie_policy(questie_src):
    """Quêtes cachées (QuestieQuestBlacklist:Load, hors HIDE_ON_MAP) et quêtes d'événement (Questie)."""
    if not questie_src:
        return None, None
    path = os.path.join(questie_src, "Database/Corrections/QuestieQuestBlacklist.lua")
    expansions = {"Era": 1, "Tbc": 2, "Wotlk": 3, "Cata": 4, "MoP": 5, "Current": 1}
    env = {"Expansions": expansions, "Questie": {}, "ContentPhases": {"activePhases": {}},
           "HIDE_ON_MAP": "HIDE_ON_MAP", "QuestieQuestBlacklist": {"HIDE_ON_MAP": "HIDE_ON_MAP"}}
    text = read(path)
    m = re.search(r"^function\s+QuestieQuestBlacklist:Load\(\)", text, re.M)
    start = text.index("{", re.compile(r"local\s+questsToBlacklist\s*=\s*\{").search(text, m.end()).start())
    table = eval_expr(text, [env], start)
    hidden = {qid for qid, flag in table.items() if flag is True}
    unresolved = sum(1 for flag in table.values() if flag is UNRESOLVED)
    events = set()
    for event_file in sorted(glob.glob(os.path.join(questie_src, "Database/Corrections/Holidays/quests/*.lua"))):
        for line in read(event_file).splitlines():
            stripped = line.strip()
            if stripped.startswith("--"):
                continue
            m = re.match(r"tinsert\(\s*eventQuests\s*,\s*\{\s*\"[^\"]*\"\s*,\s*(\d+)", stripped)
            if m:
                events.add(int(m.group(1)))
    return {"hidden": hidden, "unresolved": unresolved}, events


def git_head(root):
    try:
        with open(os.path.join(root, ".git", "HEAD"), "r") as handle:
            ref = handle.read().strip()
        if ref.startswith("ref: "):
            with open(os.path.join(root, ".git", ref[5:]), "r") as handle:
                return handle.read().strip()
        return ref
    except OSError:
        return None



# ---------------------------------------------------------------------------
# Export vers notre base
# ---------------------------------------------------------------------------
# Champs gardés de chaque entité (ceux dont nos générateurs se servent, et ceux
# qui serviront aux lieux sûrs : services, faction).
FIELDS = {
    "npc": ["name", "minLevel", "maxLevel", "rank", "subName", "npcFlags", "factionID", "friendlyToFaction",
            "zoneID", "spawns", "questStarts", "questEnds"],
    "object": ["name", "factionID", "zoneID", "spawns", "questStarts", "questEnds"],
    "quest": ["name", "startedBy", "finishedBy", "zoneOrSort", "questLevel", "requiredLevel", "requiredRaces",
              "requiredClasses", "requiredSkill", "questFlags", "specialFlags", "exclusiveTo",
              "breadcrumbForQuestId", "nextQuestInChain", "preQuestSingle", "preQuestGroup"],
}
FILES = {"npc": "npcs.jsonl", "object": "objects.jsonl", "quest": "quests.jsonl"}
LOOKUPS = {"npc": "lookupNpcs", "object": "lookupObjects", "quest": "lookupQuests"}
CLIENT_DIR = {"classic": "era", "forever": "forever"}


def to_json(value):
    """Table Lua (dict Python) -> JSON : une suite 1..n devient une liste."""
    if isinstance(value, dict):
        keys = list(value.keys())
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [to_json(value[k]) for k in range(1, len(keys) + 1)]
        return {str(k): to_json(v) for k, v in sorted(value.items(), key=lambda kv: str(kv[0]))}
    if value is UNRESOLVED:
        return None
    return value


def dump_lines(path, rows):
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=False, separators=(",", ":")) + "\n")


def export(root, flavor_key, enums, policy, meta):
    flavor = FLAVORS[flavor_key]
    out = os.path.join(DATA, CLIENT_DIR[flavor_key])
    os.makedirs(out, exist_ok=True)
    stats = {}
    entities = load_entities(root, flavor, enums, stats)
    hidden, events = policy
    hidden_ids = (hidden or {}).get("hidden") or set()
    counts = {}
    for kind in ("npc", "object", "quest"):
        data, keys = entities[kind]
        fr = load_fr(root, flavor, LOOKUPS[kind])
        rows = []
        for entity_id in sorted(data):
            row = data[entity_id]
            record = {"id": entity_id}
            for field in FIELDS[kind]:
                index = keys.get(field)
                value = row.get(index) if index is not None else None
                if value is not None and value is not UNRESOLVED:
                    record[field] = to_json(value)
            name_fr = fr.get(entity_id)
            if isinstance(name_fr, dict):
                name_fr = name_fr.get(1)
            if isinstance(name_fr, str) and name_fr:
                record["name_fr"] = name_fr
            if kind == "quest":
                if entity_id in hidden_ids:
                    record["hidden"] = True
                if entity_id in (events or set()):
                    record["event"] = True
            rows.append(record)
        dump_lines(os.path.join(out, FILES[kind]), rows)
        counts[kind] = len(rows)

    area_to_map, parent = zone_tables(root, flavor["support"])
    with open(os.path.join(out, "zones.json"), "w", encoding="utf-8", newline="\n") as handle:
        json.dump({"areaToUiMap": {str(k): v for k, v in sorted(area_to_map.items())},
                   "subZoneParent": {str(k): v for k, v in sorted(parent.items())}},
                  handle, ensure_ascii=False, indent=0, sort_keys=False)
        handle.write("\n")
    layers = {kind: [label for _, label in flavor["layers"][kind]] for kind in ("quest", "npc", "object")}
    if hidden is not None:
        layers["quest"] = layers["quest"] + ["liste noire et événements de Questie %s" % meta["questie"]]
    source = {"source": "Questie/QuestieDB (GPL-3.0)", "branch": "master", "commit": meta["commit"],
              "data": "data/" + flavor["dir"], "questie": meta["questie"], "imported": meta["date"],
              "layers": layers, "counts": counts}
    with open(os.path.join(out, "source.json"), "w", encoding="utf-8", newline="\n") as handle:
        json.dump(source, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print("== %s -> data/%s ==" % (flavor["name"], CLIENT_DIR[flavor_key]))
    for kind in ("npc", "object", "quest"):
        path = os.path.join(out, FILES[kind])
        print("  %s : %d entités, %.1f Mo" % (FILES[kind], counts[kind], os.path.getsize(path) / 1048576.0))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Importe la base de Questie dans data/ (notre base).")
    parser.add_argument("questiedb", help="racine de la source QuestieDB (data/, l10n/, support/, src/)")
    parser.add_argument("--questie-src", help="racine de Questie/Questie (liste noire de quêtes, événements)")
    parser.add_argument("--flavor", choices=("classic", "forever", "all"), default="all")
    parser.add_argument("--commit", help="commit QuestieDB (lu dans .git si absent)")
    parser.add_argument("--questie", default="12.4.0", help="version de Questie correspondante")
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    args = parser.parse_args(argv)
    root = args.questiedb
    meta = {"commit": args.commit or git_head(root) or "inconnu", "questie": args.questie, "date": args.date}
    enums = load_enums(root)
    hidden, events = load_questie_policy(args.questie_src)
    if hidden is None:
        print("ATTENTION : sans --questie-src, ni liste noire de quêtes ni quêtes d'événement de Questie.")
    for key in (("classic", "forever") if args.flavor == "all" else (args.flavor,)):
        export(root, key, enums, (hidden, events), meta)


if __name__ == "__main__":
    main()
