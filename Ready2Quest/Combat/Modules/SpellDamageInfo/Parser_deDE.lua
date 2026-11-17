-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: German language pack of the spell parser.
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
--
-- The wordings of Classic's, Forever's and Retail's German spell descriptions: "Punkt(e)", "Sek.",
-- "Gesundheit", "Schaden", the umlauts and the decimal comma. What a pack is, and how to add one,
-- is in Parser.lua (LANGUAGE PACKS). Written from the German /sdi dump and Wowhead's German.
-- Pure Lua 5.1, no game API.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT and BIT.Module and BIT.Module("SpellDamageInfo") or BIT or {}
local Parser = ns.Parser

local U = Parser.util
local NUM, num, D, amountOf, hasAny, unitSeconds, stripFillers =
  U.NUM, U.num, U.D, U.amountOf, U.hasAny, U.unitSeconds, U.stripFillers
local find, sub, gsub, match = string.find, string.sub, string.gsub, string.match
local tonumber, floor = tonumber, math.floor

local AE, OE, UE = "\195\164", "\195\182", "\195\188" -- ä ö ü

-- Capital umlauts (UTF-8) to lower case.
local UMLAUT_LOWER = { ["\195\132"] = "\195\164", ["\195\150"] = "\195\182", ["\195\156"] = "\195\188" }

local SCHOOL_DE = {
  schatten = "shadow", feuer = "fire", natur = "nature", frost = "frost", arkan = "arcane",
  heilig = "holy", frostfeuer = "frostfire", vulkan = "volcanic", blutungs = "physical", [""] = "physical",
  zauberfeuer = "spellfire", zauberfrost = "spellfrost", schattenfrost = "shadowfrost",
  schattenflammen = "shadowflame", chaos = "chaos", ["schim\195\164ren"] = "chimeral",
}

-- Words that may sit between an amount and its damage word.
local FILLERS_DE = {
  "punkt(e) ", "punkt(en) ", "punkte ", "punkt ",
  "zus\195\164tzlichen ", "zus\195\164tzliche ", "zus\195\164tzlich ",
  "insgesamt ", "k\195\182rperlichen ", "weitere ",
}

-- Not "Sek.": the English texts of a German client have it too.
local GERMAN_WORDS = { " und ", " der ", " die ", " das ", " den ", " dem ", " des ", " ein", " um ", " mit ", " von ",
  " zu ", "schaden", " ihr ", " euch", " euer", " eure" }

local REDUCE_VERBS = { "verringer", "reduzier", "senk", "vermindert" }

local function lower(t)
  return (gsub(t, "\195[\132\150\156]", UMLAUT_LOWER))
end

local function detect(t)
  return find(t, "sek%.") or find(t, "schaden") or find(t, "punkt%(e%)") or find(t, "heilt ")
    or find(t, " und ") or find(t, "gesundheit") or find(t, "stellt ") or find(t, "wieder her")
end

-- The English text of a German client still has the client's German numbers and units:
-- "Cannibalize 1.290 of your own Health over 15 Sek.", "suffer 175 bis 189 Holy damage". They are
-- put the English way, so the English readers take them as they are meant.
local function toEnglish(text)
  local t, prev = text, nil
  repeat prev = t; t = gsub(t, "([0-9])%.([0-9][0-9][0-9])", "%1%2") until t == prev
  t = gsub(t, "([0-9]),([0-9])", "%1.%2")
  t = gsub(t, "([0-9]) bis ([0-9])", "%1 to %2")
  t = gsub(t, "([0-9]) [Ss]ek%.", "%1 sec")
  t = gsub(t, "([0-9]) [Mm]in%.", "%1 min")
  return t
end

local function normaliseNumbers(t)
  local prev
  repeat prev = t; t = gsub(t, "([0-9])%.([0-9][0-9][0-9])", "%1%2") until t == prev
  t = gsub(t, "([0-9]),([0-9])", "%1.%2")
  return t
end

-- "der zwischen 42 und 63 Schimärenschaden zufügt": the range the usual "42 bis 63" way, only where the
-- spell deals it (not "wenn Ihr zwischen 5 und 8 Schaden erleidet")
local function rewrite(t)
  for _, verb in ipairs({ "verursacht", "zuf\195\188gt" }) do
    t = gsub(t, "zwischen (" .. NUM .. ") und (" .. NUM .. ") (%S*schaden) " .. verb, "%1 bis %2 %3 " .. verb)
  end
  -- Lacerate: the stacking tail ("plus 10% weapon damage per existing application") is no part of the first application's damage:
  -- the base is what the text names, and the weapon word would veto the whole reading
  t = gsub(t, " und pro existierender anwendung [^%.]-" .. NUM .. "%% waffenschaden", "")
  return t
end

-- "12 Sek. lang" and "1 Min. Kann" do not end a sentence.
local function prepareSentences(t)
  t = gsub(t, "([0-9]) sek%.", "%1 sek")
  t = gsub(t, "([0-9]) min%.", "%1 min")
  return t
end

local function takeLasts(t, take)
  t = gsub(t, "h\195\164lt (" .. NUM .. ") ([a-z]+)%.? lang an", take)
  return t
end

local function takeInterval(c, onNumber, onOne)
  c = gsub(c, "alle (" .. NUM .. ") ([a-z]+)", onNumber)
  c = gsub(c, "pro sekunde", onOne)
  c = gsub(c, "in jeder sekunde", onOne)
  c = gsub(c, "jede sekunde", onOne)
  return c
end

-- What the words right after an amount say it is: damage of a school, a health drain,
-- health given, or nothing we understand.
local function classifyAfter(after, sentence)
  local s = stripFillers(after, FILLERS_DE)
  -- the word ends there: "3 Schadensfähigkeiten" is a count of abilities; "Schimärenschaden"
  -- has an umlaut in its school
  local prefix = match(s, "^([a-z\195\164\182\188]*)schaden$") or match(s, "^([a-z\195\164\182\188]*)schaden[^a-z]")
  if prefix and SCHOOL_DE[prefix] then return "damage", SCHOOL_DE[prefix] end
  if sub(s, 1, 10) == "gesundheit" then
    if find(sentence, "\195\188bertr\195\164gt") then return "drain", nil end
    -- "Gibt dem Begleiter ...", Forever's "Gewährt dem Begleiter ... 12 Gesundheit" (not
    -- Sentry Totem's "über 100 Gesundheit verfügt ... und Sicht ... gewährt")
    if find(sentence, "gibt ") or find(sentence, "gew\195\164hrt dem begleiter") then
      -- Health Funnel, "Gibt dem Begleiter des Zaubernden ... Gesundheit": the caster's own
      if find(sentence, "begleiter", 1, true) then return "petheal", nil end
      return "giveheal", nil
    end
  end
  return nil
end

local function healAmountOK(before, after)
  if find(before, " um $") or find(before, " weitere $") then return true end
  local s = stripFillers(after, FILLERS_DE)
  return sub(s, 1, 7) == "schaden" or sub(s, 1, 10) == "gesundheit"
    or find(after, "^ *punkt") ~= nil
end

-- Clauses whose amounts are not the spell's damage or healing: self-damage, absorbs, and
-- amounts per unit of something else ("Für jeden ... Manapunkt ... 0,5 Punkt(e) Schattenschaden").
local function ignoredClause(c)
  return find(c, " selbst ") or find(c, "absorb") or find(c, "f\195\188r jede")
    or find(c, "erlittenen schadens")
end

-- German sometimes puts a DoT's duration in the clause before its amount:
-- "lässt es 9 Sek. lang bluten und fügt damit 15 Punkt(e) Schaden zu".
local DE_DOT_VERBS = { "blut", "vergift", "brenn" }

local function hasDotVerb(c)
  for _, v in ipairs(DE_DOT_VERBS) do
    if find(c, v) then return true end
  end
  return false
end

local function linkClauses(clauses)
  for i = 1, #clauses - 1 do
    local a, b = clauses[i], clauses[i + 1]
    if #a.amounts == 0 and #a.durations == 1 and not a.interval and hasDotVerb(a.raw)
      and #b.amounts > 0 and #b.durations == 0 and not b.interval then
      b.durations = { a.durations[1] }
    end
  end
end

-- Per-combo-point tables ("1 Punkt: 20 Schaden").
local function perPointTable(t)
  return find(" " .. t, "[^0-9]1 punkte? *:")
end

-- Self-healing based on maximum HP, over time or instant: percent, duration, interval.
local function healthPercent(t)
  local percent, duration, interval, manaPercent
  duration, percent = match(t, "euch im verlauf von (" .. NUM .. ") sek%.? um (" .. NUM .. ")%s*%% eurer maximalen gesundheit heilt")
  if not percent then
    duration, percent, manaPercent = match(t, "stellt im verlauf von (" .. NUM .. ") sek%.? (" .. NUM
      .. ")%% gesundheit und (" .. NUM .. ")%% mana wieder her")
  end
  if not percent then
    duration, percent = match(t, "stellt im verlauf von (" .. NUM .. ") sek%.? (" .. NUM .. ")%s*%% eurer maximalen gesundheit wieder her")
    if not percent then
      duration, percent = match(t, "regeneriert im verlauf von (" .. NUM .. ") sek%.? (" .. NUM .. ")%s*%% eurer maximalen gesundheit")
    end
    if not percent then
      duration, interval, percent = match(t, "werden (" .. NUM .. ") sek%.? lang alle (" .. NUM .. ") sek%.? (" .. NUM .. ")%s*%% der gesamten gesundheit und des manas regeneriert")
      manaPercent = percent
    end
  end
  percent = match(t, "stellt sofort (" .. NUM .. ")%s*%% gesundheit wieder her")
    or match(t, "stellt sofort (" .. NUM .. ")%s*%% eurer maximalen gesundheit wieder her")
    or percent
  return percent, duration, interval, manaPercent
end

-- A drink's share of maximum mana: percent, duration, interval (per tick when stated).
local MANA_OF = { "mana", "eures maximalen manas", "des maximalen manas", "eures gesamten manas", "des gesamten manas", "eures manas" }
local function manaPercent(t)
  for _, of in ipairs(MANA_OF) do
    local d, p = match(t, "stellt im verlauf von (" .. NUM .. ") sek%.? (" .. NUM .. ")%s*%% " .. of .. " wieder her")
    if p then return p, d end
    p, d = match(t, "stellt (" .. NUM .. ")%s*%% " .. of .. " \195\188ber (" .. NUM .. ") sek")
    if p then return p, d end
    local i
    d, i, p = match(t, "(" .. NUM .. ") sek%.? lang alle (" .. NUM .. ") sek%.? (" .. NUM .. ")%s*%% " .. of)
    if p then return p, d, i end
    d, p = match(t, "(" .. NUM .. ") sek%.? lang pro sekunde (" .. NUM .. ")%s*%% " .. of)
    if p then return p, d, 1 end
    -- Instant: only as the whole text, never the tail of another effect.
    for _, lead in ipairs({ "^", "^benutzen: " }) do
      p = match(t, lead .. "stellt sofort (" .. NUM .. ")%s*%% " .. of .. " wieder her[%. ]*$")
        or match(t, lead .. "stellt (" .. NUM .. ")%s*%% " .. of .. " wieder her[%. ]*$")
      if p then return p end
    end
  end
end

-- "Heilt Euch um 20% Eurer maximalen Gesundheit": percent, and where the matched words end.
local function instantPercent(t)
  local percent, ending
  percent, ending = match(t, "heilt euch sofort um (" .. NUM .. ")%s*%% eurer gesamten gesundheit()")
  if not percent then percent, ending = match(t, "heilt euch um (" .. NUM .. ")%s*%% eurer maximalen gesundheit()") end
  if not percent then percent, ending = match(t, "heilt euch f\195\188r (" .. NUM .. ")%s*%% eurer maximalen gesundheit()") end
  if not percent then percent, ending = match(t, "euch um (" .. NUM .. ")%s*%% eurer maximalen gesundheit heilt()") end
  if not percent then percent = match(t, "heilt euch um (" .. NUM .. ")%s*%% und euren begleiter um " .. NUM .. "%s*%% der maximalen gesundheit") end
  return percent, ending
end

-- An instant percent heal with a further percent over time: extra percent, seconds.
local function extraPercent(t)
  local seconds, extra = match(t, "heilt euch im verlauf von (" .. NUM .. ") sek%.? um zus" .. AE .. "tzlich (" .. NUM .. ")%s*%% eurer maximalen gesundheit")
  return extra, seconds
end

-- Classic German prints a points word between the amount and its unit: "Stellt 70 bis 90
-- Punkt(e) Gesundheit wieder her.", "Heilt 7 Sek. lang 161 Punkt(e) Schaden." A points word
-- that names its unit keeps it ("Schadenspunkt(e)" -> "Schaden", "Manapunkt(e)" -> "Mana",
-- "Gesundheitspunkt(e)" -> "Gesundheit"), a bare points word goes, and any other word ending
-- in "Punkt" ("Wutpunkt") is left alone. Spaces collapse, so every wording below reads
-- exactly as its English original ("Restores 70 to 90 health").
local POINTS_FOLDS = {
  [""] = "", schaden = "schaden", schadens = "schaden",
  gesundheit = "gesundheit", gesundheits = "gesundheit",
  leben = "leben", lebens = "leben", mana = "mana", manas = "mana",
}
local function foldPoints(stem, after)
  local unit = POINTS_FOLDS[stem]
  if unit == nil then return nil end -- "Wutpunkt" and friends keep their word
  return unit .. (after or "")
end
local function stripPoints(t)
  t = gsub(t, "([a-z]-)punkt%(e?n?%)", foldPoints) -- "Punkt(e)", "Punkt(en)"
  t = gsub(t, "([a-z]-)punkt[e]?n?([^a-z])", foldPoints) -- "Punkte", "Punkten", "Punkt"
  t = gsub(t, "([a-z]-)punkt[e]?n?$", foldPoints)
  return (gsub(t, " +", " "))
end

-- A consumable's amounts: health lo..hi, mana mlo..mhi, and a stated duration (minutes: the
-- duration is in minutes, not seconds).
local function itemHeal(t)
  local lo, hi
  local mlo, mhi
  local dur, minutes = nil, false
  mlo, mhi = match(t, "stellt (" .. NUM .. ") bis (" .. NUM .. ") mana wieder her")
  if not mlo then mlo = match(t, "stellt (" .. NUM .. ") mana wieder her") end
  if not mlo then mlo, mhi = match(t, "stellt sofort (" .. NUM .. ") bis (" .. NUM .. ") mana wieder her") end
  if not mlo then mlo = match(t, "stellt sofort (" .. NUM .. ") mana wieder her") end
  -- Over time (amount first): "stellt 243 Gesundheit über 21 Sek. wieder her",
  -- "heilt 66 Schaden über 6 Sek.", each also over minutes ("2 Min.").
  do
    local a, b, d
    for _, unit in ipairs({ "sek", "min" }) do
      if not a then a, b, d = match(t, "stellt (" .. NUM .. ") bis (" .. NUM .. ") gesundheit \195\188ber (" .. NUM .. ") " .. unit) end
      if not a then a, d = match(t, "stellt (" .. NUM .. ") gesundheit \195\188ber (" .. NUM .. ") " .. unit) end
      if not a then a, b, d = match(t, "stellt (" .. NUM .. ") bis (" .. NUM .. ") leben \195\188ber (" .. NUM .. ") " .. unit) end
      if not a then a, d = match(t, "stellt (" .. NUM .. ") leben \195\188ber (" .. NUM .. ") " .. unit) end
      if not a then a, b, d = match(t, "heilt (" .. NUM .. ") bis (" .. NUM .. ") schaden \195\188ber (" .. NUM .. ") " .. unit) end
      if not a then a, d = match(t, "heilt (" .. NUM .. ") schaden \195\188ber (" .. NUM .. ") " .. unit) end
      if not a then a, b, d = match(t, "heilt (" .. NUM .. ") bis (" .. NUM .. ") gesundheit \195\188ber (" .. NUM .. ") " .. unit) end
      if not a then a, d = match(t, "heilt (" .. NUM .. ") gesundheit \195\188ber (" .. NUM .. ") " .. unit) end
      if not a then a, b, d = match(t, "heilt (" .. NUM .. ") bis (" .. NUM .. ") leben \195\188ber (" .. NUM .. ") " .. unit) end
      if not a then a, d = match(t, "heilt (" .. NUM .. ") leben \195\188ber (" .. NUM .. ") " .. unit) end
      if a then if unit == "min" then minutes = true end break end
    end
    if a then lo, hi, dur = a, (b or a), d end
  end
  -- Over time (duration first): "stellt im Verlauf von 21 Sek. insgesamt 243
  -- Gesundheit wieder her" - captures are (duration, amount[, amount]).
  if not dur then
    local d, a, b = match(t, "im verlauf von (" .. NUM .. ") sek%. insgesamt (" .. NUM .. ") bis (" .. NUM .. ") gesundheit")
    if not a then d, a = match(t, "im verlauf von (" .. NUM .. ") sek%. insgesamt (" .. NUM .. ") gesundheit") end
    if not a then d, a = match(t, "im verlauf von (" .. NUM .. ") sek%. insgesamt (" .. NUM .. ").- gesundheit") end
    if not a then d, a, b = match(t, "im verlauf von (" .. NUM .. ") sek%. (" .. NUM .. ") bis (" .. NUM .. ") gesundheit") end
    if not a then d, a = match(t, "im verlauf von (" .. NUM .. ") sek%. (" .. NUM .. ").- gesundheit") end
    if not a then d, a, b = match(t, "im verlauf von (" .. NUM .. ") sek%. (" .. NUM .. ") bis (" .. NUM .. ") leben") end
    if not a then d, a = match(t, "im verlauf von (" .. NUM .. ") sek%. (" .. NUM .. ").- leben") end
    if a then lo, hi, dur = a, (b or a), d end
  end
  -- Over time (duration first, the bandage's own word order): "Heilt 7 Sek. lang 161
  -- Punkt(e) Schaden." ("Heals 161 damage over 7 sec.") or "Heilt 7 Sek. lang 161 bis 200
  -- Gesundheit."; the word before "lang" gives the seconds ("1 Min. lang" is a minute).
  if not dur then
    local d, unit, a, b
    for _, unitWord in ipairs({ "schaden", "gesundheit", "leben" }) do
      if not a then
        d, unit, a, b = match(t, "heilt (" .. NUM .. ") ([a-z]+)%.? lang (" .. NUM .. ") bis (" .. NUM .. ") " .. unitWord)
        if not a then d, unit, a = match(t, "heilt (" .. NUM .. ") ([a-z]+)%.? lang (" .. NUM .. ") " .. unitWord) end
      end
    end
    if a then
      local u = unitSeconds(unit)
      if u then lo, hi, dur = a, (b or a), tonumber(d) * u end
    end
  end
  -- Instant: "stellt 70 bis 90 Gesundheit wieder her" (Gesundheit or Leben).
  if not dur then
    lo, hi = match(t, "stellt (" .. NUM .. ") bis (" .. NUM .. ") gesundheit wieder her")
    if not lo then lo = match(t, "stellt (" .. NUM .. ") gesundheit wieder her") end
    if not lo then lo, hi = match(t, "stellt sofort (" .. NUM .. ") bis (" .. NUM .. ") gesundheit wieder her") end
    if not lo then lo = match(t, "stellt sofort (" .. NUM .. ") gesundheit wieder her") end
    if not lo then lo, hi = match(t, "stellt (" .. NUM .. ") bis (" .. NUM .. ") leben wieder her") end
    if not lo then lo = match(t, "stellt (" .. NUM .. ") leben wieder her") end
    if not lo then lo, hi = match(t, "stellt sofort (" .. NUM .. ") bis (" .. NUM .. ") leben wieder her") end
    if not lo then lo = match(t, "stellt sofort (" .. NUM .. ") leben wieder her") end
    if not lo then
      lo, hi = match(t, "heilt (" .. NUM .. ") bis (" .. NUM .. ") schaden")
      if not lo then lo, hi = match(t, "heilt (" .. NUM .. ") bis (" .. NUM .. ") gesundheit") end
      if not lo then lo = match(t, "heilt (" .. NUM .. ") schaden") end
      if not lo then lo = match(t, "heilt (" .. NUM .. ") gesundheit") end
    end
  end
  return lo, hi, mlo, mhi, dur, minutes
end

-- A drink: mana total, seconds, and the health total where one wording names both.
-- "Stellt im Verlauf von 18 Sek. 151 Mana wieder her." (the points word is folded away),
-- "... 2148 Gesundheit und 4410 Mana wieder her.", or amount first: "Stellt 151 Mana über
-- 18 Sek. wieder her."
local function itemDrink(t)
  local d, h, m = match(t, "im verlauf von (" .. NUM .. ") sek%.? (" .. NUM .. ") gesundheit und (" .. NUM .. ") mana")
  if m then return m, d, h end
  d, m = match(t, "im verlauf von (" .. NUM .. ") sek%.? insgesamt (" .. NUM .. ") mana")
  if not m then d, m = match(t, "im verlauf von (" .. NUM .. ") sek%.? (" .. NUM .. ") mana") end
  if m then return m, d end
  h, m, d = match(t, "stellt (" .. NUM .. ") gesundheit und (" .. NUM .. ") mana \195\188ber (" .. NUM .. ") sek")
  if m then return m, d, h end
  m, d = match(t, "stellt (" .. NUM .. ") mana \195\188ber (" .. NUM .. ") sek")
  return m, d
end

-- A debuff's own words: the attack power and damage a clause names. German: the word "Schaden"
-- itself, not a school's damage such as "Frostfeuerschaden".
local function reductionStat(c)
  return find(c, "angriffskraft", 1, true), find(" " .. c, " schaden", 1, true)
end

local function weaponDE(t)
  local p, a = match(t, "(" .. NUM .. ")%% waffenschaden sowie mit jeder waffe zus" .. AE .. "tzlich (" .. NUM .. ")")
  if p then return { kind = "both", pct = num(p), bonus = num(a) } end
  -- "2 zusätzliche Angriffe mit 333 Punkt(en) zusätzlicher Nahkampfangriffskraft", "die Chance,
  -- zusätzlich zum erzielten Waffenschaden, Heiligschaden in Höhe von 70% des normalen
  -- Waffenschadens zuzufügen"
  local b
  a, b = match(t, "(" .. NUM .. ") zus" .. AE .. "tzliche[n]? angriffe? mit ([0-9%(%) %*%.]+)[^%.]-zus" .. AE
    .. "tzlicher nahkampfangriffskraft")
  if a then return { kind = "extra", attacks = num(a), amount = amountOf(b) } end
  b, p = match(t, "chance, zus" .. AE .. "tzlich zum erzielten waffenschaden, ([a-z]*)schaden in h" .. OE .. "he von ("
    .. NUM .. ")%% des normalen waffenschadens")
  if p then return { kind = "weapon", pct = num(p), bonus = 0, school = SCHOOL_DE[b] } end
  -- Forever's rank 1: "eine Chance, zusätzlichen Heiligschaden in Höhe von 70% des normalen
  -- Waffenschadens zu verursachen"
  b, p = match(t, "chance, zus" .. AE .. "tzlichen ([a-z]*)schaden in h" .. OE .. "he von (" .. NUM
    .. ")%% des normalen waffenschadens")
  if p then return { kind = "weapon", pct = num(p), bonus = 0, school = SCHOOL_DE[b] } end
  if find(t, "chance", 1, true) or find(t, "mit jeder waffe", 1, true) then return nil end
  local school, lo, hi = match(t, "jedem nahkampfangriff zus" .. AE .. "tzlichen ([a-z]*)schaden in h" .. OE .. "he von ("
    .. NUM .. ") %- (" .. NUM .. ")")
  if not lo then
    lo, hi, school = match(t, "jeder treffer f" .. UE .. "gt zus" .. AE .. "tzlich (" .. NUM .. ") bis (" .. NUM
      .. ") punkt%(e%) ([a-z]*)schaden")
  end
  -- Forever's own German: "Jeder Treffer fügt 3 bis 14 zusätzlichen Feuerschaden zu", and for the later
  -- Flametongue Totem ranks "Jeder Treffer der Haupthand fügt 9 bis 31 ..."
  if not lo then
    lo, hi, school = match(t, "jeder treffer [a-z ]-f" .. UE .. "gt (" .. NUM .. ") bis (" .. NUM .. ") zus" .. AE
      .. "tzlichen ([a-z]*)schaden")
  end
  -- Classic's Flametongue Totem: "Jeder Treffer mit der Haupthand verursacht zusätzlich 9 bis 31 Feuerschaden"
  if not lo then
    lo, hi, school = match(t, "jeder treffer [a-z ]-verursacht zus" .. AE .. "tzlich (" .. NUM .. ") bis (" .. NUM
      .. ") ([a-z]*)schaden")
  end
  if lo then
    return { kind = "perhit", min = num(lo), max = num(hi), school = SCHOOL_DE[school],
      bySpeed = find(t, "langsamere waffen verursachen mehr", 1, true) and true or nil }
  end
  -- Forever's Seal of Fury: "wodurch jeder Nahkampfangriff zusätzlich 14 Heiligschaden verursacht"; Classic's
  -- "durch den Nahkampfangriffe zusätzlich 14 Heiligschaden verursachen"
  a, school = match(t, "nahkampfangriffe? zus" .. AE .. "tzlich (" .. NUM .. ") ([a-z]*)schaden")
  if a then return { kind = "perhit", min = num(a), max = num(a), school = SCHOOL_DE[school] } end
  p = match(t, "schaden, der (" .. NUM .. ")%% eurer angriffskraft entspricht")
  if p then return { kind = "appct", pct = num(p), bonus = 0 } end
  p, a = match(t, "(" .. NUM .. ")%% eurer angriffskraft plus (" .. NUM .. ")")
  if p then return { kind = "appct", pct = num(p), bonus = num(a) } end
  -- Shuriken Toss: "Schaden in Höhe von 50% Eurer Angriffskraft"
  p = match(t, "schaden in h" .. OE .. "he von (" .. NUM .. ")%% eurer angriffskraft")
  if p then return { kind = "appct", pct = num(p), bonus = 0 } end
  a = match(t, "pro sekunde den (" .. NUM .. ")%-fachen schaden eurer waffenhandwaffe")
    -- Forever's: "pro Sekunde Heiligschaden in Höhe des 3-fachen Schadens Eurer Waffenhandwaffe"
    or match(t, "pro sekunde [a-z]*schaden in h" .. OE .. "he des (" .. NUM .. ")%-fachen schadens eurer waffenhandwaffe")
  if a then return { kind = "dps", times = num(a), school = find(t, "heiligschaden", 1, true) and "holy" or "physical" } end
  p, a = match(t, "(" .. NUM .. ")%% [^%.]-schaden plus (" .. NUM .. ")")
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  p = match(t, "(" .. NUM .. ")%% des normalen schadens")
  if p then return { kind = "weapon", pct = num(p), bonus = 0 } end
  -- Forever's Holy Strike: "29% Waffenschaden sowie zusätzlich 4 bis 6 als Heiligschaden"
  p, a, b = match(t, "(" .. NUM .. ")%% waffenschaden sowie zus" .. AE .. "tzlich (" .. NUM .. ") bis (" .. NUM .. ") als")
  if p then return { kind = "weapon", pct = num(p), bonus = num(a), bonusMax = num(b) } end
  -- Forever's Mongoose Bite: "in Höhe des Nahkampfwaffenschadens plus 15"
  a = match(t, "waffenschadens? plus (" .. NUM .. ")")
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  -- "Rüstung zerreißen verursacht zusätzlich 150% Waffenschaden", "Verursacht 135% Waffenschaden, erneuert ...", "fügt ihm 100%
  -- Waffenschaden zu": the number right after the verb (a stacking "plus 10% Waffenschaden pro Stapel" is not it)
  p = match(t, "verursacht [a-z\128-\255 ]-(" .. NUM .. ")%% waffenschaden")
    or match(t, "f" .. UE .. "gt [a-z\128-\255 ]-(" .. NUM .. ")%% waffenschaden [a-z ]-zu")
  if p then return { kind = "weapon", pct = num(p), bonus = 0 } end
  -- Sniper Shot: "der Distanzschaden plus 320 zufügt": the ranged weapon's hit plus the amount
  a = match(t, "distanzschaden plus (" .. NUM .. ")")
  if a then return { kind = "weapon", pct = 100, bonus = num(a), ranged = true } end
  a = match(t, "waffenschaden sowie (" .. NUM .. ") zus" .. AE .. "tzlichen schaden")
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  a = match(t, "zus" .. AE .. "tzlich zu eurem normalen waffenschaden noch (" .. NUM .. ")")
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  if find(t, "verursacht waffenschaden bei jedem feind", 1, true) then
    return { kind = "weapon", pct = 100, bonus = 0 }
  end
  -- Whirlwind: "fügt jedem von ihnen Waffenschaden mit beiden Nahkampfwaffen zu"
  if find(t, "waffenschaden mit beiden nahkampfwaffen", 1, true) then
    return { kind = "weapon", pct = 100, bonus = 0 }
  end
  a = match(t, "mit klauen beharken und ihm so zus" .. AE .. "tzlich (" .. NUM .. ")")
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  a = match(t, "den nahkampfschaden um (" .. NUM .. ")")
  if a then return { kind = "next", bonus = num(a) } end
  a = match(t, "den n" .. AE .. "chsten angriffsschaden[^%.]- um (" .. NUM .. ")")
  if a then return { kind = "next", bonus = num(a) } end
  a = match(t, "den distanzschaden um (" .. NUM .. ")")
  if a then return { kind = "next", bonus = num(a), ranged = true } end
  -- "verleiht 306 Nahkampfangriffskraft. Außerdem greift der Paladin um 40% schneller an"
  a, p = match(t, "verleiht (" .. NUM .. ") nahkampfangriffskraft%. +au\195\159erdem greift der paladin um (" .. NUM
    .. ")%% schneller an")
  if a then return { kind = "ap", amount = num(a), faster = num(p) } end
  a = match(t, "erh" .. OE .. "ht die st" .. AE .. "rke [^%.]- um (" .. NUM .. ")")
  if a then return { kind = "stat", stat = "str", amount = num(a) } end
  a = match(t, "erh" .. OE .. "ht die beweglichkeit [^%.]- um (" .. NUM .. ")")
  if a then return { kind = "stat", stat = "agi", amount = num(a) } end
  return nil
end

-- One sentence that raises attack power: "wodurch sich die Nahkampfangriffskraft der Gruppe
-- innerhalb eines Radius von 20 Metern um 185 erhöht". The number is the first "um" after
-- the word Angriffskraft, so the 20 meters before it are passed over.
local function attackPowerIn(sentence)
  if not find(sentence, "angriffskraft", 1, true) or not find(sentence, "erh" .. OE .. "h", 1, true) then return nil end
  if hasAny(sentence, REDUCE_VERBS) or find(sentence, "chance", 1, true) or find(sentence, "weniger schaden", 1, true) then
    return nil
  end
  local a = match(sentence, "angriffskraft[^%.]- um (" .. NUM .. ")")
  if not a then return nil end
  return { kind = "ap", amount = num(a), ranged = find(sentence, "distanzangriffskraft", 1, true) ~= nil,
    plusAgility = find(sentence, "um " .. a .. " plus beweglichkeit", 1, true) ~= nil }
end

-- "Die Entfesselung der Energie dieses Siegels fügt einem Feind 170 bis 187 Heiligschaden zu."
local function judgement(part)
  -- "Heiligschaden in Höhe von 169 bis 186, oder 339 bis 373 Heiligschaden, sollte das Ziel
  -- betäubt ... sein": the "in Höhe von" range first, or the stunned one would be taken
  local school, lo, hi = match(part, "([a-z]*)schaden in h" .. OE .. "he von (" .. NUM .. ") bis (" .. NUM .. ")")
  if not lo then lo, hi, school = match(part, "(" .. NUM .. ") bis (" .. NUM .. ") ([a-z]*)schaden") end
  return lo, hi, school and SCHOOL_DE[school]
end

-- "30 Sek. lang"
local function sealDuration(t)
  return match(t, "(" .. NUM .. ") sek%.? lang")
end

local function specialDE(t)
  -- Aderlass: the same cost/gain pair as English Life Tap ("... in 48 Mana für Euch um").
  local hc, mg = match(t, "wandelt (" .. NUM .. ") gesundheit in (" .. NUM .. ") mana")
  if hc then return { healthCost = num(hc), manaGain = num(mg) } end
  -- Dunkles Opfer: "Kannibalisiert 400 Eurer Gesundheit im Verlauf von 15 Sek., um 428 Mana zu erhalten."
  local seconds
  hc, seconds, mg = match(t, "kannibalisiert (" .. NUM .. ") eurer gesundheit im verlauf von (" .. NUM
    .. ") sek%.?,? um (" .. NUM .. ") mana")
  if hc then return { healthCost = num(hc), manaGain = num(mg), healthCostDuration = num(seconds) } end
  local lo, hi, school, hlo, hhi = match(t, "verursacht (" .. NUM .. ") bis (" .. NUM .. ") ([a-z]*)schaden bei feinden oder heilt ("
    .. NUM .. ") bis (" .. NUM .. ") bei verb" .. UE .. "ndeten")
  if lo then return { direct = D(lo, hi), heal = D(hlo, hhi), school = SCHOOL_DE[school] } end
  -- Penance: "die einem Gegner 240 Heiligschaden zufügt oder ein verbündetes Ziel sofort sowie
  -- 2 Sek. lang alle 1 Sek. um 572 Gesundheit heilt"
  local dmg, h, dur2, iv2
  -- Forever's Holy Shock: "die Gegnern 129 bis 139 Heiligschaden zufügt oder Verbündete um 110
  -- bis 118 Gesundheit heilt"
  lo, hi, school, hlo, hhi = match(t, "(" .. NUM .. ") bis (" .. NUM .. ") ([a-z]*)schaden zuf" .. UE .. "gt oder verb" .. UE
    .. "ndete um (" .. NUM .. ") bis (" .. NUM .. ") gesundheit heilt")
  if lo then return { direct = D(lo, hi), heal = D(hlo, hhi), school = SCHOOL_DE[school] } end
  dmg, school, dur2, iv2, h = match(t, "(" .. NUM .. ") ([a-z]*)schaden zuf" .. UE .. "gt oder ein verb" .. UE
    .. "ndetes ziel sofort sowie (" .. NUM .. ") sek%.? lang alle (" .. NUM .. ") sek%.? um (" .. NUM .. ") gesundheit heilt")
  if dmg then
    local hits = 1 + floor(num(dur2) / num(iv2) + 0.5)
    return { direct = D(num(dmg) * hits), heal = D(num(h) * hits), school = SCHOOL_DE[school], hits = hits }
  end
  -- Tranquility: "Regeneriert 10 Sek. lang alle 2 Sek. 87 Gesundheit", Wowhead's "Regeneriert bei
  -- allen Gruppenmitgliedern in der Nähe 10 Sek. lang alle 2 Sek. 98 Gesundheit"
  local dur0, every0, n0 = match(t, "regeneriert [^%.]-(" .. NUM .. ") sek%.? lang alle (" .. NUM .. ") sek%.? (" .. NUM
    .. ") gesundheit")
  if n0 then return { hot = { total = num(n0) * floor(num(dur0) / num(every0) + 0.5), duration = num(dur0) } } end
  local n, dur = match(t, "um im verlauf von (" .. NUM .. ") sek%.? (" .. NUM .. ") gesundheit wiederherzustellen")
  if n then return { hot = { total = num(dur), duration = num(n) } } end
  local per
  n, per = match(t, "verursacht (" .. NUM .. ") punkt%(e%) schaden und jeder zus" .. AE .. "tzliche wutpunkt wird in (" .. NUM .. ")")
  if n then return { direct = D(n), school = "physical", perRage = num(per) } end
  local iv
  iv, lo, hi, school = match(t, "alle (" .. NUM .. ") sekunden einen feind [^%.]- angreift und (" .. NUM .. ") bis (" .. NUM
    .. ") punkt%(e%) ([a-z]*)schaden")
  if lo then return { direct = D(lo, hi), school = SCHOOL_DE[school], perAttack = true } end
  iv, n = match(t, "alle (" .. NUM .. ") sekunden um (" .. NUM .. ") punkt%(e%) heilt")
  if n then return { heal = D(n), every = num(iv) } end
  local f
  lo, hi, f, school = match(t, "entzieht dem ziel (" .. NUM .. ") bis (" .. NUM .. ") punkte mana%. f" .. UE
    .. "r jeden [^%.]- erleidet das ziel (" .. NUM .. ") punkte ([a-z]*)schaden")
  if lo then return { direct = D(num(lo) * num(f), num(hi) * num(f)), school = SCHOOL_DE[school] } end
  n, school = match(t, "verursacht (" .. NUM .. ") punkt%(e%) ([a-z]*)schaden f" .. UE .. "r jede kreatur, die ein gruppenmitglied schl" .. AE .. "gt")
  -- Forever's: "Fügt jeder Kreatur, die ein Gruppenmitglied innerhalb von 30 Metern angreifen, 7
  -- Heiligschaden zu"
  if not n then
    n, school = match(t, "f" .. UE .. "gt jeder kreatur, die ein gruppenmitglied [^,]-, (" .. NUM .. ") ([a-z]*)schaden zu")
  end
  if n then return { direct = D(n), school = SCHOOL_DE[school], perStrike = true } end
  -- Forever's Consecration: "Gegner, die das Gebiet betreten, erleiden im Verlauf von 8 Sek. 56
  -- Heiligschaden"
  -- Heiligschaden. Die ersten 4 Gegner, die das Gebiet betreten, erleiden im Verlauf von 8 Sek.
  -- zusätzlich 24 Schaden": the first 4 take both, as in English. Forever's German says "den Bereich
  -- betreten" where Wowhead's says "das Gebiet betreten".
  local first, extra
  dur, n, school, first, extra = match(t, "erleiden im verlauf von (" .. NUM .. ") sek%.? (" .. NUM .. ") ([a-z]*)schaden%. +die "
    .. "ersten (" .. NUM .. ") gegner, die d[a-z]+ [a-z]+ betreten, erleiden im verlauf von " .. NUM .. " sek%.? zus" .. AE
    .. "tzlich (" .. NUM .. ") schaden")
  if n then
    return { dot = { total = num(n) + num(extra), duration = num(dur) }, school = SCHOOL_DE[school], first = num(first) }
  end
  dur, n, school = match(t, "erleiden im verlauf von (" .. NUM .. ") sek%.? (" .. NUM .. ") ([a-z]*)schaden")
  if n then return { dot = { total = num(n), duration = num(dur) }, school = SCHOOL_DE[school] } end
  -- Lacerate: "was im Verlauf von 15 Sek. 149 Blutungsschaden ... verursacht"
  dur, n = match(t, "im verlauf von (" .. NUM .. ") sek%.? (" .. NUM .. ") blutungsschaden")
  if n then return { dot = { total = num(n), duration = num(dur) }, school = "physical" } end
  n, school = match(t, "mit jedem geblockten angriff (" .. NUM .. ") ([a-z]*)schaden")
  -- Forever's: "verursacht, während der Effekt aktiv ist, mit jedem Blocken 110 Heiligschaden"
  if not n then n, school = match(t, "mit jedem blocken (" .. NUM .. ") ([a-z]*)schaden") end
  if n then return { direct = D(n), school = SCHOOL_DE[school], perBlock = true } end
  -- Forever's: "um einen Betrag, der der maximalen Gesundheit des Paladins entspricht"
  if find(t, "bis zur maximalen gesundheit des paladins", 1, true)
    or find(t, "der maximalen gesundheit des paladins entspricht", 1, true) then
    return { healMaxHealth = true }
  end
  -- "das jedem Nahkampfangriff eine Chance verleiht, den Paladin um 94 Punkt(e) zu heilen"
  n = match(t, "jedem nahkampfangriff eine chance verleiht, den paladin um (" .. NUM .. ") punkt%(e%) zu heilen")
  if n then return { heal = D(n) } end
  -- Forever's: "Absorbiert 162 Feuerschaden", "absorbiert 431 Schaden", "einen Schild, der 155
  -- Schaden absorbiert", "absorbiert dabei 749 Schaden", "der 1 Min. lang 431 Schaden absorbiert"
  local absorbs = gsub(t, "absorbiert dabei ", "absorbiert ")
  n = match(absorbs, "absorbiert (" .. NUM .. ") punkt") or match(absorbs, "absorbiert (" .. NUM .. ") [a-z]*schaden")
    or match(absorbs, "der (" .. NUM .. ") schaden absorbiert") or match(absorbs, "lang (" .. NUM .. ") schaden absorbiert")
  if n then return { absorb = num(n) } end
  return nil
end

-- A finisher's damage over time in one point's row: "25 Schaden über 8 Sekunden", Forever's
-- "44 Schaden über 12 Sek.", or "25 im Verlauf von 8 Sek." where the description names damage
-- elsewhere (damageText).
local function finisherDot(seg, damageText)
  local total, dur = match(seg, "^ *(" .. NUM .. ") schaden " .. UE .. "ber (" .. NUM .. ") sek")
  if not total then total, dur = match(seg, "^ *(" .. NUM .. ") schaden im verlauf von (" .. NUM .. ") sek") end
  if not total and damageText then
    total, dur = match(seg, "^ *(" .. NUM .. ") im verlauf von (" .. NUM .. ") sek")
  end
  return total, dur
end

-- The chance per hit: its percent, true where the text names a chance without a figure, or nil.
-- "Bei jedem Treffer besteht eine Chance von 20%", "Bei jedem Schlag besteht eine Chance von 20%",
-- "Bei jedem Treffer besteht eine Chance,", "jedem Nahkampfangriff eine Chance verleiht", "gewährt
-- jedem Angriff die Chance", "gewährt ihm die Chance".
local function procChance(t)
  local p = match(t, "bei jedem [a-z ]- besteht eine chance von (" .. NUM .. ")%%")
  if p then return num(p) end
  if find(t, "bei jedem [a-z ]- besteht eine chance,") or find(t, "jedem nahkampfangriff eine chance", 1, true)
    or find(t, "jedem angriff die chance", 1, true) or find(t, "gew" .. AE .. "hrt ihm die chance", 1, true)
    or find(t, "gew" .. AE .. "hrt dem paladin eine chance", 1, true) then
    return true
  end
  return nil
end

Parser.RegisterPack("de", {
  rangeWord = "bis",
  damageWord = "schaden",
  weaponWord = "waffenschaden",
  pointsMarker = "punkte?",
  -- "der es um 172 Gesundheit heilt, wenn ...": a comma may follow
  healWords = { " heilt[ ,]", " geheilt[ ,]", " heilen[ ,]" },
  clauseSeparators = { " und ", " sowie " },
  reduceVerbs = REDUCE_VERBS,
  enemyWords = { "ziel", "feind", "gegner" },
  selfWords = { "erlitten", " euer", " eure" },
  -- "was seine Nahkampfangriffskraft um 43 und die Wirksamkeit jeglicher Heilung um 20% verringert"
  reduceVerbAtEnd = true,
  increaseWord = "erh" .. OE .. "h",
  byWord = "um ",
  sealEnergy = "entfesselung der energie dieses siegels",
  judgementSpell = "die energie eines siegelzaubers",
  words = GERMAN_WORDS,
  units = { sek = 1, min = 60, stunde = 3600 },
  distanceWords = { meter = true, metern = true },
  hp5 = "gesundheitsregeneration um (" .. NUM .. ") gesundheit pro (" .. NUM .. ") sek",
  tickTails = { "^ *alle " },
  durationMarkers = { UE .. "ber ", " sek", " min" },
  drainWords = { "zieh" },
  manaWord = "mana",
  healing = {
    targets = { "und den zaubernden" },
    channel = { "kanalisier", "fokussiert", "sofort sowie" },
    trigger = { "anklicken", "n" .. AE .. "chste", "chance" },
    stack = { "stapel", "abl" .. AE .. "uft" },
    pet = { "euer tier", "eurem tier", "begleiter" },
    target = { "heilt das ziel", "heilt beim ziel", "heilt ein befreundetes ziel",
      "heilt ein verb" .. UE .. "ndetes ziel", "heilt das verb" .. UE .. "ndete ziel" },
  },
  lower = lower,
  detect = detect,
  toEnglish = toEnglish,
  normaliseNumbers = normaliseNumbers,
  rewrite = rewrite,
  prepareSentences = prepareSentences,
  takeLasts = takeLasts,
  takeInterval = takeInterval,
  classifyAfter = classifyAfter,
  healAmountOK = healAmountOK,
  ignoredClause = ignoredClause,
  linkClauses = linkClauses,
  perPointTable = perPointTable,
  healthPercent = healthPercent,
  instantPercent = instantPercent,
  extraPercent = extraPercent,
  itemText = stripPoints,
  itemHeal = itemHeal, itemDrink = itemDrink, manaPercent = manaPercent,
  reductionStat = reductionStat,
  weapon = weaponDE,
  attackPower = attackPowerIn,
  judgement = judgement,
  sealDuration = sealDuration,
  special = specialDE,
  finisherDot = finisherDot,
  procChance = procChance,
})
