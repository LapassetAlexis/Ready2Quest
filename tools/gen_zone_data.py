#!/usr/bin/env python3
"""Génère les tables de zone de l'addon (créatures, récolte, quêtes) depuis QuestieDB.

Usage :
    python3 -I tools/gen_zone_data.py /chemin/vers/QuestieDB [--questie-src /chemin/vers/Questie]
        [--flavor classic|forever|all] [--commit SHA] [--date AAAA-MM-JJ]

Sorties (dans le dossier de l'addon), une paire par client :
    ZoneCreatures_Era.lua  / ZoneCreatures_Forever.lua   ns.ZONE_CREATURES
    ZoneGathering_Era.lua  / ZoneGathering_Forever.lua   ns.ZONE_GATHERING
    ZoneQuests_Era.lua     / ZoneQuests_Forever.lua      ns.ZONE_QUESTS
Chaque fichier se garde lui-même (ns:IsForeverClient(), Dungeon.lua) : un client
ne construit que SES tables.

Source : la base de données de Questie, publiée à part depuis Questie 12
(dépôt GitHub Questie/QuestieDB, branche master ; GPL-3.0). Fichiers lus,
chemins relatifs à la racine (<F> = Classic ou Forever, <f> = classic ou forever) :
    data/<F>/<f>QuestDB.lua / <f>NpcDB.lua / <f>ObjectDB.lua   données brutes
    l10n/<F>/lookupQuests|lookupNpcs|lookupObjects/frFR.lua    noms français
    support/Zones/*.lua (Era), support/Forever/Zones/*.lua      areaID -> uiMapID,
                                                                sous-zone -> zone
    src/corrections/enum/*.lua                                  constantes des corrections
    src/corrections/Era/classicQuestFixes.lua                   corrections Era (quêtes)
    src/corrections/Forever/...                                 couches Forever, dans
        l'ordre de src/config.lua (ownedCorrections) et de docs/forever.md :
        brut -> legacy/ (corrections Era héritées) -> generated/ (delta-base)
        -> traces/ -> forever*Fixes.lua (corrections Forever écrites à la main)
    Seules les corrections statiques (Load) s'appliquent ; les dynamiques
    (LoadFactionFixes, LoadDynamic : selon le personnage) ne sont pas lues.
Questie/Questie (facultatif, --questie-src ; Questie 12.4.0, commit 3a1b930) :
    Database/Corrections/QuestieQuestBlacklist.lua   quêtes cachées (hors HIDE_ON_MAP)
    Database/Corrections/Holidays/quests/*.lua       quêtes d'événements saisonniers
    (+ Database/Corrections/QuestieNPCBlacklist.lua, recopié dans ERA_BLACKLIST)

Créatures et récolte d'Era : données brutes, sans couche (contenu inchangé
depuis la première version). Quêtes d'Era : brut + corrections Era statiques.

Aucune dépendance externe : un petit évaluateur Lua suffit (littéraux, constantes,
opérateurs ; tout appel de fonction ou nom inconnu rend la valeur « non résolue »
et le champ corrigé est ignoré, compté dans le résumé). Sortie déterministe.
Les fichiers Lua de l'addon sont réécrits en entier : ne les édite pas à la main,
relance ce script.
"""
import argparse
import datetime
import glob
import os
import re
import sys

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
# Zones visées : uiMapID des zones classiques de type « Zone » (mapType 3),
# hors capitales (1453-1458), instances et champs de bataille. Les 39 de
# ns.ZONE_LEVELS (CompanionChest.lua) + Reflet-de-Lune (1450), seule zone
# extérieure classique absente de ZONE_LEVELS (pas de tranche de niveau).
# Forever ajoute ses zones propres (support/Forever/Zones/uiMapIdToAreaId.lua).
# ---------------------------------------------------------------------------
ZONES = {
    1411: "Durotar", 1412: "Mulgore", 1413: "The Barrens", 1416: "Alterac Mountains",
    1417: "Arathi Highlands", 1418: "Badlands", 1419: "Blasted Lands", 1420: "Tirisfal Glades",
    1421: "Silverpine Forest", 1422: "Western Plaguelands", 1423: "Eastern Plaguelands",
    1424: "Hillsbrad Foothills", 1425: "The Hinterlands", 1426: "Dun Morogh", 1427: "Searing Gorge",
    1428: "Burning Steppes", 1429: "Elwynn Forest", 1430: "Deadwind Pass", 1431: "Duskwood",
    1432: "Loch Modan", 1433: "Redridge Mountains", 1434: "Stranglethorn Vale", 1435: "Swamp of Sorrows",
    1436: "Westfall", 1437: "Wetlands", 1438: "Teldrassil", 1439: "Darkshore", 1440: "Ashenvale",
    1441: "Thousand Needles", 1442: "Stonetalon Mountains", 1443: "Desolace", 1444: "Feralas",
    1445: "Dustwallow Marsh", 1446: "Tanaris", 1447: "Azshara", 1448: "Felwood", 1449: "Un'Goro Crater",
    1450: "Moonglade", 1451: "Silithus", 1452: "Winterspring",
}
FOREVER_ZONES = {
    2482: "Mount Hyjal", 2521: "Zephras Isle", 2524: "Darkspear Islands", 2548: "Riverglades",
    2652: "Shen'dralas",
}


def zones_for(flavor):
    zones = dict(ZONES)
    if flavor["forever"]:
        zones.update(FOREVER_ZONES)
    return zones


# ---------------------------------------------------------------------------
# Filtres des créatures
# ---------------------------------------------------------------------------
# Bestioles : Questie n'a pas le type de créature. Heuristique vérifiée sur la
# base : rat, lapin, écureuil, cerf, faon, mouton, poulet, chien de prairie,
# lièvre, cochon (gabarit de faction 31 « Prey ») ; crapaud, cafard, gazelle,
# chats, perroquets (188 « Ambient ») ; vache, serpent, bélier (190). En
# gabarit 7 (« Creature », neutre, aussi porté par de vrais mobs comme les
# crabes ou les zombies de Tirisfal) : seuls les serpents de niveau 1 relevés
# à la main (vipère de Durotar, mocassin du Marais des Chagrins).
CRITTER_FACTIONS = {31, 188, 190}
CRITTER_NAMES_FACTION_7 = {"Adder", "Moccasin", "Cured Gazelle"}

# Créatures « amicales envers les deux » selon Questie (friendlyToFaction
# "AH") : Questie note ainsi TOUT ce qui n'est pas hostile, donc aussi les
# bêtes neutres (jaunes) qu'on peut attaquer. On ne garde que les gabarits
# de faction neutres combattables relevés dans la base (sanglier tacheté =
# 189, crabes et vautours = 7, loups de Dun Morogh = 32, chouettes de
# Teldrassil = 15, sangliers de Loch Modan = 1094, troggs = 36, mages de
# Dalaran = 76) ; le reste (35 amical, 1630 Invasion du Fléau,
# 114 déclencheurs, 1555 Foire de Sombrelune, gardes gobelins…) sort.
NEUTRAL_COMBAT_FACTIONS = {7, 15, 32, 36, 76, 189, 1094}

# PNJ techniques (noms) ; « Stalker » seul n'est PAS filtré : « Moss Stalker »,
# « Leech Stalker »… sont de vrais mobs (l'« Invisible Stalker » tombe sur
# « Invisible »).
TECHNICAL = re.compile(
    r"Trigger|Invisible|\[DND\]|\bDND\b|Bunny|Dummy|\bTarget\b|Credit|Marker|Generator|Spawner|"
    r"Debug|Only GM|Waypoint|Spawn Point|Buffer|Scourge Structure|\(PH\)|\[PH\]|\bTest\b|UNUSED|^zz", re.I)
# Événements saisonniers (noms, titres) et faction de la Foire de Sombrelune
SEASONAL = re.compile(
    r"Lunar Festival|Halloween|Hallow|Headless Horseman|Wickerman|Love Fool|Midsummer|Winter Veil|"
    r"Greatfather Winter|Smokywood|Noblegarden|Children's Week|Darkmoon|Harvest Festival|Festival|Firebreather", re.I)
SEASONAL_FACTIONS = {1555}
# QuestieNPCBlacklist (Questie : Database/Corrections/QuestieNPCBlacklist.lua) :
# PNJ masqués par Questie sur Era et Forever (Expansions.Current = Era sur les
# deux ; retirés du jeu ou d'événements passés)
ERA_BLACKLIST = {8001, 13151, 13153, 13154, 13319, 13320, 13377, 13446, 13449, 15799}

# ---------------------------------------------------------------------------
# Récolte : nom de l'objet du monde -> itemID de GatheringData.lua
# (minerai + pierre du même gisement). Les « Ooze Covered … » de Gangrebois
# et Silithus donnent les mêmes ressources. Ignorés : Incendicite, Indurium,
# Lesser Bloodstone (absents de GatheringData), Hakkari Thorium Vein (Zul'Gurub).
# ---------------------------------------------------------------------------
NODES = {
    "Peacebloom": [2447], "Silverleaf": [765], "Earthroot": [2449], "Mageroyal": [785],
    "Briarthorn": [2450], "Stranglekelp": [3820], "Bruiseweed": [2453], "Wild Steelbloom": [3355],
    "Grave Moss": [3369], "Kingsblood": [3356], "Liferoot": [3357], "Fadeleaf": [3818],
    "Goldthorn": [3821], "Khadgar's Whisker": [3358], "Wintersbite": [3819], "Firebloom": [4625],
    "Purple Lotus": [8831], "Arthas' Tears": [8836], "Sungrass": [8838], "Blindweed": [8839],
    "Ghost Mushroom": [8845], "Gromsblood": [8846], "Golden Sansam": [13464], "Dreamfoil": [13463],
    "Mountain Silversage": [13465], "Plaguebloom": [13466], "Icecap": [13467], "Black Lotus": [13468],
    "Copper Vein": [2770, 2835], "Tin Vein": [2771, 2836], "Silver Vein": [2775],
    "Iron Deposit": [2772, 2838], "Gold Vein": [2776], "Mithril Deposit": [3858, 7912],
    "Truesilver Deposit": [7911], "Dark Iron Deposit": [11370],
    "Small Thorium Vein": [10620, 12365], "Rich Thorium Vein": [10620, 12365],
}
NODES.update({
    "Ooze Covered Silver Vein": NODES["Silver Vein"], "Ooze Covered Iron Deposit": NODES["Iron Deposit"],
    "Ooze Covered Gold Vein": NODES["Gold Vein"], "Ooze Covered Mithril Deposit": NODES["Mithril Deposit"],
    "Ooze Covered Truesilver Deposit": NODES["Truesilver Deposit"],
    "Ooze Covered Thorium Vein": NODES["Small Thorium Vein"],
    "Ooze Covered Rich Thorium Vein": NODES["Rich Thorium Vein"],
})


def gathering_item_ids(path):
    """itemID déclarés dans GatheringData.lua (contrôle de la table NODES)."""
    text = read(path)
    return {int(i) for i in re.findall(r"^\s*\[(\d+)\]\s*=\s*R\(", text, re.M)}


# ---------------------------------------------------------------------------
# Zones : areaID (clé des spawns, zoneOrSort) -> uiMapID
# ---------------------------------------------------------------------------
def zone_mapper(root, support):
    blocks, _ = lua_blocks(os.path.join(root, support, "areaIdToUiMapId.lua"))
    area_to_map = dict(blocks["ZoneDB.private.areaIdToUiMapId"])
    area_to_map.update(blocks["ZoneDB.private.areaIdToUiMapIdOverride"])
    blocks, _ = lua_blocks(os.path.join(root, support, "subZoneToParentZone.lua"))
    parent = dict(blocks["ZoneDB.private.subZoneToParentZone"])
    parent.update(blocks["ZoneDB.private.subZoneToParentZoneOverride"])

    def to_map(area):
        seen = set()
        while area in parent and area not in seen and parent[area] != area:
            seen.add(area)
            area = parent[area]
        return area_to_map.get(area)
    return to_map


def spawn_zones(spawns, to_map, zones):
    out = set()
    for area in (spawns or {}):
        ui_map = to_map(area)
        if ui_map in zones:
            out.add(ui_map)
    return out


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


# ---------------------------------------------------------------------------
# Créatures
# ---------------------------------------------------------------------------
def creature_reason(npc_id, row, keys):
    """None si la créature entre au bestiaire, sinon la raison de l'exclusion."""
    name = row.get(keys["name"]) or ""
    faction = row.get(keys["factionID"])
    friendly = row.get(keys["friendlyToFaction"])
    sub_name = row.get(keys["subName"]) or ""
    if not name or not isinstance(name, str):
        return "sans nom"
    if npc_id in ERA_BLACKLIST:
        return "liste noire Questie"
    if TECHNICAL.search(name):
        return "technique"
    if SEASONAL.search(name) or SEASONAL.search(sub_name) or faction in SEASONAL_FACTIONS:
        return "saisonnier"
    if faction in CRITTER_FACTIONS or (faction == 7 and name in CRITTER_NAMES_FACTION_7):
        return "bestiole"
    if friendly == "AH" and faction not in NEUTRAL_COMBAT_FACTIONS:
        return "amical envers les deux"
    if friendly is not None and (row.get(keys["npcFlags"]) or sub_name
                                 or row.get(keys["questStarts"]) or row.get(keys["questEnds"])):
        # PNJ de service (marchand, maître de vol, donneur de quête, titre) :
        # pas une cible de combat, même pour la faction adverse
        return "PNJ de service"
    if friendly in ("A", "H") and (row.get(keys["maxLevel"]) or 0) <= 1:
        # civils de niveau 1 d'une faction (enfants de Comté-de-l'Or, paysans,
        # chiens de ferme, essaims) : pas des cibles, même pour l'adversaire
        return "civil de faction"
    if (row.get(keys["maxLevel"]) or 0) <= 0:
        return "niveau inconnu"
    return None


def fr_name(fr, entity_id, en):
    entry = fr.get(entity_id)
    name = entry.get(1) if isinstance(entry, dict) else entry
    return name if isinstance(name, str) and name else en


def build_creatures(entities, fr, to_map, zones_wanted):
    data, keys = entities["npc"]
    zones, reasons = {}, {}
    for npc_id, row in data.items():
        where = spawn_zones(row.get(keys["spawns"]), to_map, zones_wanted)
        if not where:
            continue
        reason = creature_reason(npc_id, row, keys)
        if reason:
            reasons[reason] = reasons.get(reason, 0) + 1
            continue
        en = row[keys["name"]]
        lo = row.get(keys["minLevel"]) or row.get(keys["maxLevel"])
        hi = row.get(keys["maxLevel"]) or lo
        lo, hi = min(lo, hi), max(lo, hi)
        friendly = row.get(keys["friendlyToFaction"])
        entry = (int(lo), int(hi), int(row.get(keys["rank"]) or 0), fr_name(fr, npc_id, en), en,
                 friendly if friendly in ("A", "H") else None)
        for ui_map in where:
            zones.setdefault(ui_map, {})[npc_id] = entry
    return zones, reasons


# ---------------------------------------------------------------------------
# Récolte
# ---------------------------------------------------------------------------
def build_gathering(entities, to_map, known_items, zones_wanted):
    data, keys = entities["object"]
    for name, items in NODES.items():
        for item in items:
            if item not in known_items:
                raise SystemExit("ERREUR : %s -> itemID %d absent de GatheringData.lua" % (name, item))
    names_found, zones = set(), {}
    for row in data.values():
        name = row.get(keys["name"])
        items = NODES.get(name)
        if not items:
            continue
        where = spawn_zones(row.get(keys["spawns"]), to_map, zones_wanted)
        if where:
            names_found.add(name)
        for ui_map in where:
            zones.setdefault(ui_map, set()).update(items)
    missing = sorted(set(NODES) - names_found)
    return zones, missing


# ---------------------------------------------------------------------------
# Quêtes
# ---------------------------------------------------------------------------
QUEST_DAILY, QUEST_WEEKLY, QUEST_MONTHLY = 4096, 32768, 65536
SPECIAL_REPEATABLE = 1
# Catégories (zoneOrSort < 0) jamais ramenées à une zone : événements,
# métiers, champs de bataille et guerres d'événement (src/corrections/enum/quests.lua)
SORT_EVENT = {-404, -402, -378, -376, -375, -374, -370, -369, -366, -364, -41, -22, -21, -1000}
SORT_PROFESSION = {-398, -377, -373, -371, -324, -304, -264, -201, -182, -181, -121, -101, -24}
SORT_PVP = {-25, -368, -365, -241}


def bit_set(mask, bit):
    return mask is not None and (int(mask) // bit) % 2 == 1


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


def quest_starter_zone(row, qk, npcs, objects, to_map, zones_wanted):
    """Zone unique des PNJ / objets qui donnent la quête (catégories), sinon None."""
    started = row.get(qk["startedBy"])
    if not isinstance(started, dict):
        return None
    where = set()
    for slot, (data, keys) in ((1, npcs), (2, objects)):
        ids = started.get(slot)
        if not isinstance(ids, dict):
            continue
        for entity_id in ids.values():
            entity = data.get(entity_id)
            spawns = entity.get(keys["spawns"]) if entity else None
            if not spawns:
                return None  # un donneur sans apparition connue : zone incertaine
            for area in spawns:
                ui_map = to_map(area)
                if ui_map not in zones_wanted:
                    return None  # donneur (aussi) hors des zones extérieures
                where.add(ui_map)
    return next(iter(where)) if len(where) == 1 else None


def build_quests(entities, fr, to_map, zones_wanted, hidden, events):
    data, qk = entities["quest"]
    zones, reasons = {}, {}
    via_starter = 0

    def drop(reason):
        reasons[reason] = reasons.get(reason, 0) + 1

    for qid in sorted(data):
        row = data[qid]
        name = row.get(qk["name"])
        if not isinstance(name, str) or not name:
            drop("sans nom")
            continue
        sort = row.get(qk["zoneOrSort"])
        sort = int(sort) if _num(sort) else 0
        if hidden and qid in hidden:
            drop("cachée (liste noire Questie)")
            continue
        if (events and qid in events) or sort in SORT_EVENT:
            drop("événement saisonnier")
            continue
        if bit_set(row.get(qk["specialFlags"]), SPECIAL_REPEATABLE):
            drop("répétable")
            continue
        flags = row.get(qk["questFlags"])
        if bit_set(flags, QUEST_DAILY) or bit_set(flags, QUEST_WEEKLY) or bit_set(flags, QUEST_MONTHLY):
            drop("journalière / hebdomadaire")
            continue
        if row.get(qk["requiredSkill"]) or sort in SORT_PROFESSION:
            drop("métier")
            continue
        if sort in SORT_PVP:
            drop("JcJ / guerre d'événement")
            continue
        if sort > 0:
            ui_map = to_map(sort)
            if ui_map in (1459, 1460, 1461):
                drop("JcJ / guerre d'événement")
                continue
            if ui_map not in zones_wanted:
                drop("hors zone extérieure (capitale, donjon…)")
                continue
        else:
            ui_map = quest_starter_zone(row, qk, entities["npc"], entities["object"], to_map, zones_wanted)
            if ui_map is None:
                drop("catégorie sans zone")
                continue
            via_starter += 1
        level = row.get(qk["questLevel"])
        req = row.get(qk["requiredLevel"])
        races = row.get(qk["requiredRaces"])
        classes = row.get(qk["requiredClasses"])
        ex = set()
        for field in ("exclusiveTo",):
            for other in (row.get(qk[field]) or {}).values() if isinstance(row.get(qk[field]), dict) else ():
                if _num(other) and int(other) > 0 and int(other) != qid:
                    ex.add(int(other))
        for field in ("breadcrumbForQuestId", "nextQuestInChain"):
            other = row.get(qk[field])
            if _num(other) and int(other) > 0 and int(other) != qid:
                ex.add(int(other))
        entry = (int(level) if _num(level) else 0, int(req) if _num(req) else 0,
                 int(races) if _num(races) else 0, int(classes) if _num(classes) else 0,
                 fr_name(fr, qid, name), name, tuple(sorted(ex)))
        zones.setdefault(ui_map, {})[qid] = entry
    return zones, reasons, via_starter


# ---------------------------------------------------------------------------
# Écriture
# ---------------------------------------------------------------------------
def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r") + '"'


def header(filename, what, meta, flavor, layers):
    client = "Forever (WoW Forever 1.60.x)" if flavor["forever"] else "Era (Classic Era 1.15.x)"
    lines = [
        "-- %s -- %s, client %s (v1.25.0)" % (filename, what, client),
        "--",
        "-- FICHIER GÉNÉRÉ par tools/gen_zone_data.py, ne pas éditer à la main :",
        "-- relance le script (voir son en-tête) pour le refaire.",
        "-- Source : base de données de Questie, dépôt GitHub Questie/QuestieDB",
        "--   (branche master, commit %s), données %s/ ;" % (meta["commit"], "data/" + flavor["dir"]),
        "--   données importées de Questie/Questie (Questie %s). Générée le %s." % (meta["questie"], meta["date"]),
        "-- Couches appliquées : %s." % (" -> ".join(["brut"] + layers)),
        "-- Licence : GPL-3.0 (https://www.gnu.org/licenses/gpl-3.0.html), comme la",
        "--   base de Questie dont ces données dérivent ; voir NOTICE.md.",
        "-- Generated by tools/gen_zone_data.py, do not edit by hand; data derived",
        "-- from Questie's database (GPL-3.0).",
        "local ADDON, ns = ...",
        "-- garde de client : seul le client %s construit cette table" % flavor["name"],
        "if ns.IsForeverClient and ns:IsForeverClient() ~= %s then return end" % ("true" if flavor["forever"] else "false"),
        "",
    ]
    return "\n".join(lines)


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def write_creatures(path, zones, meta, flavor, layers, names):
    out = [header(os.path.basename(path), "créatures de chaque zone, préremplies", meta, flavor, layers)]
    out.append("\n".join([
        "-- ns.ZONE_CREATURES[uiMapID][npcID] = { lvl = { min, max }, rank = n, fr = \"…\", en = \"…\", f = … }",
        "--   rank : 0 normal, 1 élite, 2 rare élite, 3 boss, 4 rare (codage cmangos de Questie) ;",
        "--   f    : \"A\" / \"H\" = amicale envers l'Alliance / la Horde (exclue pour cette",
        "--          faction), nil = hostile ou neutre envers les deux.",
        "-- Créatures combattables en extérieur : ni bestioles, ni PNJ techniques, ni PNJ",
        "-- amicaux envers les deux factions, ni événements saisonniers (voir le script).",
        "",
        "local function C(lo, hi, rank, fr, en, f)",
        "\treturn { lvl = { lo, hi }, rank = rank, fr = fr, en = en, f = f }",
        "end",
        "",
        "local Z = {}",
        "ns.ZONE_CREATURES = Z",
        "",
    ]))
    for ui_map in sorted(zones):
        out.append("-- %s" % names[ui_map])
        out.append("Z[%d] = {" % ui_map)
        for npc_id in sorted(zones[ui_map]):
            lo, hi, rank, fr, en, f = zones[ui_map][npc_id]
            args = "%d,%d,%d,%s,%s" % (lo, hi, rank, lua_string(fr), lua_string(en))
            if f:
                args += ',"%s"' % f
            out.append("[%d]=C(%s)," % (npc_id, args))
        out.append("}")
    out.append("")
    out.append('if ns.Mark then ns.Mark("ZoneCreatures") end')
    out.append("")
    write(path, "\n".join(out))


def write_gathering(path, zones, meta, flavor, layers, names):
    out = [header(os.path.basename(path), "herbes et minerais de chaque zone, préremplis", meta, flavor, layers)]
    out.append("\n".join([
        "-- ns.ZONE_GATHERING[uiMapID] = { [itemID] = true } : herbes, minerais et pierres du",
        "-- même gisement dont un nœud apparaît dans la zone (itemID de GatheringData.lua).",
        "-- Pas de dépeçage : Questie n'a pas le type des créatures, il reste appris en jouant.",
        "",
        "local function S(...)",
        "\tlocal set = {}",
        "\tfor index = 1, select(\"#\", ...) do set[(select(index, ...))] = true end",
        "\treturn set",
        "end",
        "",
        "ns.ZONE_GATHERING = {",
    ]))
    for ui_map in sorted(zones):
        out.append("\t[%d] = S(%s), -- %s" % (ui_map, ", ".join(str(i) for i in sorted(zones[ui_map])), names[ui_map]))
    out.append("}")
    out.append("")
    out.append('if ns.Mark then ns.Mark("ZoneGathering") end')
    out.append("")
    write(path, "\n".join(out))


def write_quests(path, zones, meta, flavor, layers, names):
    out = [header(os.path.basename(path), "quêtes de chaque zone", meta, flavor, layers)]
    out.append("\n".join([
        "-- ns.ZONE_QUESTS[uiMapID][questID] = { lvl = n, req = n, races = masque, classes = masque,",
        "--                                     fr = \"…\", en = \"…\", ex = { questID, … } }",
        "--   lvl / req : niveau de la quête / niveau requis (0 = inconnu ; -1 = au niveau du joueur) ;",
        "--   races     : masque requiredRaces de Questie (0 = toutes) ; bit de la race = 2^(raceID-1),",
        "--               sauf Forever : Skyborne Alliance (95) = 2^32, Skyborne Horde (96) = 2^33 ;",
        "--   classes   : masque requiredClasses (0 = toutes), bit = 2^(classID-1) ;",
        "--   ex        : quêtes qui ferment celle-ci une fois faites (exclusiveTo, et la suite",
        "--               d'une quête d'approche : breadcrumbForQuestId, nextQuestInChain).",
        "-- Zone : zoneOrSort (areaID, sous-zone ramenée à sa zone) ; catégorie (zoneOrSort < 0) :",
        "--   zone unique des donneurs. Exclues : quêtes cachées par Questie, d'événement",
        "--   saisonnier, répétables, journalières / hebdomadaires, de métier, JcJ (voir le script).",
        "",
        "local function Q(lvl, req, races, classes, fr, en, ex)",
        "\treturn { lvl = lvl, req = req, races = races, classes = classes, fr = fr or en, en = en, ex = ex }",
        "end",
        "",
        "local Z = {}",
        "ns.ZONE_QUESTS = Z",
        "",
    ]))
    for ui_map in sorted(zones):
        out.append("-- %s" % names[ui_map])
        out.append("Z[%d] = {" % ui_map)
        for qid in sorted(zones[ui_map]):
            lvl, req, races, classes, fr, en, ex = zones[ui_map][qid]
            args = "%d,%d,%d,%d,%s,%s" % (lvl, req, races, classes, "nil" if fr == en else lua_string(fr),
                                         lua_string(en))
            if ex:
                args += ",{%s}" % ",".join(str(i) for i in ex)
            out.append("[%d]=Q(%s)," % (qid, args))
        out.append("}")
    out.append("")
    out.append('if ns.Mark then ns.Mark("ZoneQuests_%s") end' % flavor["name"])
    out.append("")
    write(path, "\n".join(out))


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


def generate(root, flavor_key, args, meta, enums, policy):
    flavor = FLAVORS[flavor_key]
    stats = {}
    entities = load_entities(root, flavor, enums, stats)
    to_map = zone_mapper(root, flavor["support"])
    zones_wanted = zones_for(flavor)
    suffix = flavor["name"]
    hidden, events = policy

    npc_layers = [label for _, label in flavor["layers"]["npc"]]
    quest_layers = [label for _, label in flavor["layers"]["quest"]]
    creatures, c_reasons = build_creatures(entities, load_fr(root, flavor, "lookupNpcs"), to_map, zones_wanted)
    known = gathering_item_ids(os.path.join(args.out, "GatheringData.lua"))
    gathering, missing = build_gathering(entities, to_map, known, zones_wanted)
    quests, q_reasons, via_starter = build_quests(entities, load_fr(root, flavor, "lookupQuests"), to_map,
                                                   zones_wanted, hidden and hidden["hidden"], events)

    paths = [os.path.join(args.out, "ZoneCreatures_%s.lua" % suffix),
             os.path.join(args.out, "ZoneGathering_%s.lua" % suffix),
             os.path.join(args.out, "ZoneQuests_%s.lua" % suffix)]
    quest_layers_label = quest_layers + (["liste noire et événements de Questie %s" % meta["questie"]]
                                         if hidden is not None else [])
    write_creatures(paths[0], creatures, meta, flavor, npc_layers, zones_wanted)
    write_gathering(paths[1], gathering, meta, flavor, [label for _, label in flavor["layers"]["object"]],
                    zones_wanted)
    write_quests(paths[2], quests, meta, flavor, quest_layers_label, zones_wanted)

    print("== %s ==" % suffix)
    for (kind, label), s in sorted(stats.items(), key=lambda kv: (kv[0][0], 0)):
        print("  couche %s / %s : %d champs, %d nouvelles entités, %d valeurs non résolues ignorées"
              % (kind, label, s.get("fields", 0), s.get("new", 0), s.get("unresolved", 0)))
    species = set()
    for table in creatures.values():
        species.update(table)
    print("  Créatures : %d zones, %d lignes, %d espèces" % (len(creatures), sum(len(t) for t in creatures.values()),
                                                          len(species)))
    print("  Exclues : %s" % ", ".join("%s %d" % kv for kv in sorted(c_reasons.items())))
    print("  Récolte : %d zones, %d paires zone/ressource" % (len(gathering), sum(len(s) for s in gathering.values())))
    if missing:
        print("  Nœuds sans apparition en zone extérieure : %s" % ", ".join(missing))
    kept = sum(len(t) for t in quests.values())
    print("  Quêtes : %d gardées dans %d zones (dont %d par la zone du donneur), sur %d"
          % (kept, len(quests), via_starter, len(entities["quest"][0])))
    print("  Quêtes exclues : %s" % ", ".join("%s %d" % kv for kv in sorted(q_reasons.items())))
    for path in paths:
        print("  %s : %.1f Ko" % (os.path.basename(path), os.path.getsize(path) / 1024.0))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Génère les tables de zone (créatures, récolte, quêtes) depuis QuestieDB.")
    parser.add_argument("questiedb", help="racine de la source QuestieDB (data/, l10n/, support/, src/)")
    parser.add_argument("--questie-src", help="racine de Questie/Questie (liste noire de quêtes, événements)")
    parser.add_argument("--flavor", choices=("classic", "forever", "all"), default="all")
    parser.add_argument("--commit", help="commit QuestieDB (lu dans .git si absent)")
    parser.add_argument("--questie", default="12.4.0", help="version de Questie correspondante")
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    parser.add_argument("--out", default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "QuestCompanion"),
                        help="dossier de l'addon (par défaut : QuestCompanion/ du dépôt)")
    args = parser.parse_args(argv)
    root = args.questiedb
    meta = {"commit": args.commit or git_head(root) or "inconnu", "questie": args.questie, "date": args.date}
    enums = load_enums(root)
    hidden, events = load_questie_policy(args.questie_src)
    if hidden is None:
        print("ATTENTION : sans --questie-src, ni liste noire de quêtes ni quêtes d'événement de Questie.")
    elif hidden["unresolved"]:
        print("Liste noire : %d entrées non résolues ignorées" % hidden["unresolved"])
    for key in (("classic", "forever") if args.flavor == "all" else (args.flavor,)):
        generate(root, key, args, meta, enums, (hidden, events))
    return 0


if __name__ == "__main__":
    sys.exit(main())
