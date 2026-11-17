-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: Spanish language pack of the spell parser.
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
--
-- The wordings of WoW: Forever's Spanish spell descriptions: "14 a 23 p. de daño de Fuego", "durante 12 s",
-- "cada 2 s", "1 punto: 62-82 p. de daño", the decimal comma. What a pack is, and how to add one, is in
-- Parser.lua (LANGUAGE PACKS). Written from the Spanish /sdi dump all (1697 class abilities) and checked
-- against the French one of the same build; the weapon and special readers cover the wordings that dump holds.
-- A wording the pack does not know stays unread: it never guesses.
-- Pure Lua 5.1, no game API.

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT and BIT.Module and BIT.Module("SpellDamageInfo") or BIT or {}
local Parser = ns.Parser

local U = Parser.util
local NUM, num, D, hasAny, stripFillers = U.NUM, U.num, U.D, U.hasAny, U.stripFillers
local find, sub, gsub, match = string.find, string.sub, string.gsub, string.match
local tonumber, floor = tonumber, math.floor

local N, A, E, I, O = "\195\177", "\195\161", "\195\169", "\195\173", "\195\179" -- ñ á é í ó
local W = "[a-z\128-\255' %-]" -- the characters of a few words, accents included
local DANO = "da" .. N .. "o" -- daño
local MANA = "man" .. A -- maná
local WEAPON = DANO .. " de arma"

-- School words after "daño", longest first. "daño de Fuego", "de las Sombras", "Sagrado", "Arcano", "físico".
local SCHOOLS = {
  { "de pirofr" .. I .. "o", "frostfire" }, { "de pirosombra", "shadowflame" }, { "de piroarcano", "spellfire" },
  { "de fr" .. I .. "oarcano", "spellfrost" }, { "de fr" .. I .. "osombra", "shadowfrost" },
  { "de fuego", "fire" }, { "de escarcha", "frost" }, { "de naturaleza", "nature" }, { "de las sombras", "shadow" },
  { "sagrado", "holy" }, { "arcano", "arcane" }, { "f" .. I .. "sico", "physical" }, { "de sangrado", "physical" },
  { "de caos", "chaos" }, { "quim" .. E .. "rico", "chimeral" },
}

-- Words that may sit between an amount and its damage word.
local FILLERS_ES = {
  "p de ", "p ", "puntos de ", "punto de ", "puntos ", "punto ", "m" .. A .. "s de ", "m" .. A .. "s ",
  "adicionales de ", "adicionales ", "de ",
}

-- Words of this language, for telling a Spanish client's English texts (Forever leaves some of its spells
-- in English, e.g. Mangle's bleed).
local SPANISH_WORDS = { " de ", " la ", " el ", " los ", " las ", " del ", " con ", " una ", " un ", " al ", " y ", " tu ", " objetivo",
  " en ", " p.", DANO }

-- Capital letters of Latin-1 to lower case (UTF-8): Á -> á, Ñ -> ñ ...
local function lower(t)
  return (gsub(t, "\195[\128-\150\152-\158]", function(c) return "\195" .. string.char(c:byte(2) + 32) end))
end

local function detect(t)
  return find(t, DANO, 1, true) or find(t, " p. de ", 1, true)
end

-- Numbers as the English readers take them: "1.742" -> "1742", "1 290" -> "1290", "1,2" -> "1.2".
local function englishNumbers(t)
  local prev
  repeat
    prev = t
    t = gsub(t, "%f[0-9]([0-9][0-9]?[0-9]?) ([0-9][0-9][0-9])%f[^0-9]", "%1%2")
    t = gsub(t, "%f[0-9]([0-9][0-9]?[0-9]?)%.([0-9][0-9][0-9])%f[^0-9]", "%1%2")
  until t == prev
  return (gsub(t, "([0-9]),([0-9])", "%1.%2"))
end

local function toEnglish(text)
  text = englishNumbers(gsub(text, "\194\160", " "))
  return (gsub(text, "([0-9]) s%f[^a-z\128-\255]", "%1 sec"))
end

-- "1.742", "1,2", a bare "s" as a unit ("durante 12 s", "cada 2 s").
local function normaliseNumbers(t)
  t = englishNumbers(t)
  t = gsub(t, "([0-9]) s%f[^a-z\128-\255]", "%1 sec")
  t = gsub(t, "([0-9]) h%f[^a-z\128-\255]", "%1 hora")
  t = gsub(t, "([0-9]) segundos?%f[^a-z\128-\255]", "%1 sec")
  t = gsub(t, "([0-9]) minutos?%f[^a-z\128-\255]", "%1 min")
  return t
end

-- "p." (puntos) is an abbreviation, not the end of a sentence; one spelling of the phrases that say a number is
-- weapon damage, so one word covers them; and the ranges: "de 3 a 13" -> "3 a 13", "entre 2 p. y 9 p. más de
-- daño" -> "2 a 9 p de daño".
local function rewrite(t)
  t = gsub(t, "%f[%a]p%.", "p")
  -- Black Arrow (Forever's own wording): "causa un daño de Sombras de 150 p. y absorbe más de 30 s p. de su maná de 150" is "150 damage
  -- and drains 150 mana over 30 sec"
  t = gsub(t, DANO .. " de sombras de (" .. NUM .. ") p y absorbe m" .. A .. "s de (" .. NUM .. ") sec p de su " .. MANA .. " de ([0-9]+)",
    "%1 p de " .. DANO .. " de las sombras y drena %3 p de " .. MANA .. " durante %2 sec")
  -- Divine Favor's sibling: "por debajo del 50% de salud durante 131 a 167 y elimina Alma debilitada" is the heal, 131 to 167
  t = gsub(t, "de salud durante (" .. NUM .. ") a (" .. NUM .. ") y ", "de salud, restaurando %1 a %2 p de salud y ")
  -- the Judgement phrase of every seal: "Desatar / Liberar / Al soltar la energía de este sello"
  for _, verb in ipairs({ "liberar", "soltar", "al soltar", "desata", "libera", "suelta" }) do
    t = gsub(t, verb .. " la energ" .. I .. "a de este sello", "desatar la energ" .. I .. "a de este sello")
  end
  t = gsub(t, "al desatar la energ" .. I .. "a de este sello", "desatar la energ" .. I .. "a de este sello")
  t = gsub(t, "desata la energ" .. I .. "a de un hechizo de sello", "desata la energ" .. I .. "a de un hechizo de sello")
  t = gsub(t, DANO .. " normal con arma", WEAPON)
  t = gsub(t, DANO .. " de arma normal", WEAPON)
  t = gsub(t, DANO .. " de arma cuerpo a cuerpo", WEAPON)
  t = gsub(t, DANO .. " con ambas armas cuerpo a cuerpo", WEAPON)
  t = gsub(t, DANO .. " con arma cuerpo a cuerpo", WEAPON)
  t = gsub(t, DANO .. " con arma", WEAPON)
  t = gsub(t, "de un arma normal", "del " .. WEAPON)
  -- Health Funnel: "Otorga 12 p. de salud a la mascota del taumaturgo cada segundo": the health the caster pays,
  -- no heal; "asigna" is the word classifyAfter looks for
  t = gsub(t, "otorga (" .. NUM .. ") p de salud ([^%.]-)a la ma", "asigna %1 p de salud %2a la ma")
  -- Dreadlord's stun: "Salta y aturde al objetivo durante 2 s, causando 114 p. de daño durante 18 s"
  t = gsub(t, "aturde al objetivo durante " .. NUM .. " sec", "aturde al objetivo")
  -- "y un daño extra de 60 p. durante 9 s"
  t = gsub(t, DANO .. " (extra) de (" .. NUM .. ") p", "%2 p de " .. DANO .. " %1")
  t = gsub(t, DANO .. " (adicional) de (" .. NUM .. ") p", "%2 p de " .. DANO .. " %1")
  -- a totem's own health ("con 5 p. de salud") is no amount of the spell
  t = gsub(t, " con " .. NUM .. " p de salud", " ")
  -- Wild Growth: "Sana 280 p. al objetivo y a su grupo durante 7 s": one amount over one time
  t = gsub(t, " y a su grupo durante ", " durante ")
  -- Sniper Shot: "inflige daño a distancia más 320 p. de daño": weapon-based, not a flat hit
  t = gsub(t, DANO .. " a distancia m" .. A .. "s", WEAPON .. " a distancia m" .. A .. "s")
  -- reductions: "reduce 43 p. el poder de ataque" / "reduce el daño causado por el objetivo 4 p." -> "reduce en 43 p."
  t = gsub(t, "(reduc[a-z\128-\255]+) (" .. NUM .. ") p ", "%1 en %2 p ")
  t = gsub(t, "(causado por el objetivo) (" .. NUM .. ") p", "%1 en %2 p")
  t = gsub(t, "entre (" .. NUM .. ") p y (" .. NUM .. ") p m" .. A .. "s de ", "%1 a %2 p de ")
  t = gsub(t, "entre (" .. NUM .. ") p a (" .. NUM .. ") p", "%1 a %2 p")
  t = gsub(t, "entre (" .. NUM .. ") p y (" .. NUM .. ") p", "%1 a %2 p")
  t = gsub(t, "entre (" .. NUM .. ") y (" .. NUM .. ") p", "%1 a %2 p")
  t = gsub(t, "entre (" .. NUM .. ") y (" .. NUM .. ") de ", "%1 a %2 p de ")
  t = gsub(t, "(" .. NUM .. ") p a (" .. NUM .. ") p", "%1 a %2 p")
  t = gsub(t, "([0-9]) a([0-9])", "%1 a %2")
  t = gsub(t, "([ :,]) *de (" .. NUM .. ") a (" .. NUM .. ")", "%1 %2 a %3")
  -- Lacerate: the stacking tail ("plus 10% weapon damage per existing application") is no part of the first application's damage:
  -- the base is what the text names, and the weapon word would veto the whole reading
  t = gsub(t, " m" .. A .. "s un " .. NUM .. " ?%% de " .. WEAPON .. " por cada aplicaci[^%.]*", "")
  return (gsub(t, " +", " "))
end

local function takeLasts(t, take)
  t = gsub(t, "dura (" .. NUM .. ") ([a-z]+)", take)
  t = gsub(t, "duraci" .. O .. "n de (" .. NUM .. ") ([a-z]+)", take)
  return t
end

local function takeInterval(c, onNumber, onOne)
  c = gsub(c, "cada (" .. NUM .. ") ([a-z]+)", onNumber)
  c = gsub(c, "cada segundo", onOne)
  c = gsub(c, "por segundo", onOne)
  return c
end

-- The school named by the words after "daño": its code, false where a word follows that is no school
-- ("daño recibido", "daño de los hechizos"), or "physical" where nothing school-like follows ("15 p. de daño
-- durante 12 s").
local function schoolAfter(s)
  for _, school in ipairs(SCHOOLS) do
    local words = school[1]
    if sub(s, 1, #words) == words and not match(sub(s, #words + 1, #words + 1), "[a-z\128-\255]") then
      return school[2]
    end
  end
  if match(s, "^de ") or match(s, "^del ") or match(s, "^de$") or match(s, "^recibido") or match(s, "^aparte") then return false end
  return "physical"
end

-- What the words right after an amount say it is: damage of a school, a health drain, health given, or nothing
-- we understand.
local function classifyAfter(after, sentence)
  local s = stripFillers(after, FILLERS_ES)
  if sub(s, 1, #DANO) == DANO then
    local school = schoolAfter((gsub(sub(s, #DANO + 1), "^ +", "")))
    if school then return "damage", school end
    return nil
  end
  if sub(s, 1, 5) == "salud" then
    if find(sentence, "transfiere", 1, true) then return "drain", nil end
    if find(sentence, "asigna ", 1, true) then return "petheal", nil end
    -- a bleed: "pierde 15 p. de salud durante 9 s"
    if find(sentence, "sangr", 1, true) and find(sentence, "pierde ", 1, true) then return "damage", "physical" end
  end
  return nil
end

-- A heal amount is followed by "p. de salud" / "p. de sanación", or by a bare "p." ("Cura a tu objetivo en 250 a 290
-- p."); "p. de maná" and counts of anything else are not.
local function healAmountOK(_, after)
  local s = gsub(after, "^ +", "")
  local rest = match(s, "^p%f[^a-z\128-\255]%s*(.*)$") or match(s, "^puntos?%f[^a-z\128-\255]%s*(.*)$")
  if not rest then return false end
  if match(rest, "^de ") then
    return match(rest, "^de salud%f[^a-z\128-\255]") ~= nil or match(rest, "^de sanaci") ~= nil
      or match(rest, "^de " .. DANO .. "%f[^a-z\128-\255]") ~= nil
  end
  return true
end

-- Clauses whose amounts are not the spell's damage or healing: absorbs, amounts per unit of something else, the
-- caster's own damage ("se inflige a sí misma"), damage passed on.
local function ignoredClause(c)
  return find(c, "absorb", 1, true) or find(c, "amortigua", 1, true) or find(c, "por cada ", 1, true)
    or find(c, "se inflige a s", 1, true) or find(c, "reduc[a-z\128-\255]* en " .. NUM .. " p") or find(c, "transfiere " .. NUM .. " p de " .. DANO)
end

-- Per-combo-point tables ("1 punto: 20 p. de daño").
local function perPointTable(t)
  return find(" " .. t, "[^0-9]1 puntos? *:") or find(" " .. t, "[^0-9]1 p *:")
end

-- A consumable's amounts: health lo..hi, mana mlo..mhi, and a stated duration.
local function itemHeal(t)
  local lo, hi, mlo, mhi
  local dur, minutes = nil, false
  mlo, mhi = match(t, "restaura (" .. NUM .. ") a (" .. NUM .. ") p de " .. MANA)
  if not mlo then mlo = match(t, "restaura (" .. NUM .. ") p de " .. MANA) end
  do
    local a, b, d
    for _, unit in ipairs({ "sec", "min" }) do
      for _, verb in ipairs({ "restaura", "cura" }) do
        if not a then a, b, d = match(t, verb .. " (" .. NUM .. ") a (" .. NUM .. ") p de salud durante (" .. NUM .. ") " .. unit) end
        if not a then a, d = match(t, verb .. " (" .. NUM .. ") p de salud durante (" .. NUM .. ") " .. unit) end
      end
      if a then if unit == "min" then minutes = true end break end
    end
    if a then lo, hi, dur = a, (b or a), d end
  end
  if not dur then
    for _, verb in ipairs({ "restaura", "cura" }) do
      if not lo then lo, hi = match(t, verb .. " (" .. NUM .. ") a (" .. NUM .. ") p de salud") end
      if not lo then lo = match(t, verb .. " (" .. NUM .. ") p de salud") end
    end
  end
  return lo, hi, mlo, mhi, dur, minutes
end

-- A drink: mana total, seconds, and the health total where one wording names both.
-- "Uso: Restaura 151 p. de maná durante 18 s."
local function itemDrink(t)
  local h, m, d = match(t, "restaura (" .. NUM .. ") p de salud y (" .. NUM .. ") p de " .. MANA .. " durante (" .. NUM .. ") sec")
  if m then return m, d, h end
  m, d = match(t, "restaura (" .. NUM .. ") p de " .. MANA .. " durante (" .. NUM .. ") sec")
  return m, d
end

local REDUCE_VERBS = { "reduc", "disminu" }

-- A debuff's own words: the attack power and damage a clause names.
local function reductionStat(c)
  return find(c, "poder de ataque", 1, true), find(c, DANO, 1, true)
end

-- The school of "daño Sagrado adicional": the words from "daño" on.
local function schoolOfDamage(s)
  return schoolAfter((gsub(s, "^ +", ""))) or nil
end

-- "aumenta en 21 p. el poder de ataque de los miembros del grupo", "aumentando el poder de ataque 12 p. más
-- agilidad", "aumenta el poder de ataque a distancia de todos los que ataquen al objetivo en 26 p.", "obtienes 70 p. de
-- poder de ataque cuerpo a cuerpo": the first amount of points of the sentence.
local function attackPowerIn(sentence)
  if not find(sentence, "poder de ataque", 1, true) then return nil end
  if hasAny(sentence, REDUCE_VERBS) or find(sentence, "probabilidad", 1, true) or find(sentence, "menos " .. DANO, 1, true) then
    return nil
  end
  if not hasAny(sentence, { "aument", "otorg", "obtien", "concede" }) then return nil end
  -- a per-point table of damage ("aumenta según tu poder de ataque: 1 punto: 6-10 p. de daño") is no attack power
  if find(sentence, "[^0-9]1 puntos? *:") or find(sentence, "[^0-9]1 p *:") then return nil end
  local a = match(sentence, "aument[a-z\128-\255]* en (" .. NUM .. ") p%f[^a-z\128-\255]")
    or match(sentence, "(" .. NUM .. ") p de poder de ataque")
    or match(sentence, "(" .. NUM .. ") p el poder de ataque")
    or match(sentence, "poder de ataque [a-z ]-(" .. NUM .. ") p%f[^a-z\128-\255]")
    or match(sentence, "poder de ataque [^%.]- en (" .. NUM .. ") p%f[^a-z\128-\255]")
  if not a then return nil end
  return { kind = "ap", amount = num(a), ranged = find(sentence, " a distancia", 1, true) ~= nil,
    plusAgility = find(sentence, a .. " p m" .. A .. "s agilidad", 1, true) ~= nil }
end

local function weaponES(t)
  local p, a, b, school
  -- Windfury Weapon and Totem: "probabilidad de otorgarte 2 ataques extras con 46 p. de poder de ataque cuerpo a cuerpo
  -- adicional"
  a, b = match(t, "(" .. NUM .. ") ataques? extras? con (" .. NUM .. ") p de poder de ataque")
  if a then return { kind = "extra", attacks = num(a), amount = num(b) } end
  -- Mutilate: "un 90% de daño de arma más 36 p. adicionales con cada arma"
  p, a = match(t, "(" .. NUM .. ") ?%% de " .. WEAPON .. " m" .. A .. "s (" .. NUM .. ") p adicionales con cada arma")
  if p then return { kind = "both", pct = num(p), bonus = num(a) } end
  -- Seal of Command: "probabilidad de infligir daño Sagrado adicional equivalente al 70% del daño de arma"
  school, p = match(t, "probabilidad de %a+ " .. DANO .. " (" .. W .. "-) [^%d%.]-(" .. NUM .. ") ?%% del? " .. WEAPON)
  if p then return { kind = "weapon", pct = num(p), bonus = 0, school = schoolOfDamage(school) } end
  if find(t, "probabilidad", 1, true) or find(t, "posibilidad", 1, true) or find(t, "con cada arma", 1, true) then return nil end
  -- Flametongue, Seal of Righteousness: "Cada golpe inflige de 3 a 13 p. de daño de Fuego adicional en función de la
  -- velocidad del arma", "otorga entre 2 p. y 9 p. más de daño Sagrado a cada ataque cuerpo a cuerpo"
  local lo, hi
  lo, hi, school = match(t, "cada golpe [^%.]-inflige (" .. NUM .. ") a (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "-) en funci" .. O .. "n de la velocidad")
  if not lo then
    lo, hi, school = match(t, "otorga (" .. NUM .. ") a (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "-) a cada ataque")
  end
  if lo then
    return { kind = "perhit", min = num(lo), max = num(hi), school = schoolOfDamage(school),
      bySpeed = find(t, "armas m" .. A .. "s lentas", 1, true) and true or nil }
  end
  -- Seal of Fury: "hace que los ataques cuerpo a cuerpo inflijan 14 p. de daño Sagrado extra"
  a, school = match(t, "ataques cuerpo a cuerpo infli%a+ (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "-) extra")
  if not a then
    a, school = match(t, "ataques cuerpo a cuerpo infli%a+ (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "-) adicional")
  end
  if a then return { kind = "perhit", min = num(a), max = num(a), school = schoolOfDamage(school) } end
  -- Claw, Ravage, Savage Bite: "inflige un 140% del daño normal más 37 p.", "un 435% de daño más 183 p.", "un 200% de
  -- daño y 44 al objetivo", "un 100% de daño normal más 42 p."
  p, a = match(t, "(" .. NUM .. ") ?%% del? " .. DANO .. " normal m" .. A .. "s (" .. NUM .. ")")
  if not p then p, a = match(t, "(" .. NUM .. ") ?%% de " .. DANO .. " m" .. A .. "s (" .. NUM .. ")") end
  if not p then p, a = match(t, "(" .. NUM .. ") ?%% de " .. DANO .. " y (" .. NUM .. ") al objetivo") end
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  -- Backstab, Ambush: "un 150% de daño de arma más 15 al objetivo", Holy Strike: "un 29% de daño de arma y 4 a 6 p. más
  -- de daño Sagrado"
  p, a, b = match(t, "(" .. NUM .. ") ?%% de " .. WEAPON .. " y (" .. NUM .. ") a (" .. NUM .. ") p m" .. A .. "s de " .. DANO)
  if p then return { kind = "weapon", pct = num(p), bonus = num(a), bonusMax = num(b) } end
  p, a = match(t, "(" .. NUM .. ") ?%% de " .. WEAPON .. " m" .. A .. "s (" .. NUM .. ")")
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  -- Bloodthirst, Shuriken Toss: "un daño equivalente al 45% de tu poder de ataque y 30 p. más"
  p, a = match(t, "(" .. NUM .. ") ?%% de tu poder de ataque y (" .. NUM .. ") p m" .. A .. "s")
  if not p then p = match(t, "(" .. NUM .. ") ?%% de tu poder de ataque") end
  if p then return { kind = "appct", pct = num(p), bonus = num(a) or 0 } end
  -- "infliges un 135% de daño de arma", "también inflige un 150% de daño de arma", "le infliges un 100% de daño de arma"
  p = match(t, "inflig[a-z\128-\255]* " .. W .. "-(" .. NUM .. ") ?%% de " .. WEAPON)
  if p then return { kind = "weapon", pct = num(p), bonus = 0 } end
  -- Hammer of the Righteous: "inflige una cantidad de da\195\177o Sagrado igual a 3 veces el da\195\177o por segundo de tu arma de la mano derecha"
  a = match(t, "igual a (" .. NUM .. ") veces el " .. DANO .. " por segundo de tu arma de la mano derecha")
  if a then return { kind = "dps", times = num(a), school = find(t, DANO .. " sagrado", 1, true) and "holy" or "physical" } end
  -- Sniper Shot: "inflige daño a distancia más 320 p. de daño", rewritten to "daño de arma a distancia más": the ranged weapon's hit
  -- plus the amount
  a = match(t, "inflig[a-z\128-\255]* " .. WEAPON .. " a distancia m" .. A .. "s (" .. NUM .. ")")
  if a then return { kind = "weapon", pct = 100, bonus = num(a), ranged = true } end
  -- Heroic Strike's relatives: "inflige tu daño de arma más 5 p. de daño al objetivo", "causando daño de arma más 32 p.",
  -- "inflige daño de arma cuerpo a cuerpo más 5 p.", "causa 3 p. de daño aparte del daño de arma"
  a = match(t, "inflig[a-z\128-\255]* [a-z ]-" .. WEAPON .. " m" .. A .. "s (" .. NUM .. ")")
    or match(t, "inflige " .. WEAPON .. ", adem" .. A .. "s de (" .. NUM .. ") p")
    or match(t, "causando " .. WEAPON .. " m" .. A .. "s (" .. NUM .. ")")
    or match(t, "causa (" .. NUM .. ") p de " .. DANO .. " aparte del " .. WEAPON)
    or match(t, "inflige el " .. WEAPON .. " m" .. A .. "s (" .. NUM .. ")")
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  -- Whirlwind: "les infliges daño de arma a cada uno"
  if find(t, "inflig[a-z]* " .. WEAPON .. " a cada") then return { kind = "weapon", pct = 100, bonus = 0 } end
  -- the next swing, or a shot, gets more: "aumenta el daño cuerpo a cuerpo en 11 p.", "Aumenta en 18 p. el daño infligido
  -- en el ataque siguiente", "aumenta 40 p. el daño a distancia"
  a = match(t, "aumenta el " .. DANO .. " cuerpo a cuerpo en (" .. NUM .. ") p")
    or match(t, "aumenta en (" .. NUM .. ") p el " .. DANO .. " infligido en el ataque siguiente")
  if a then return { kind = "next", bonus = num(a) } end
  a = match(t, "aumenta (" .. NUM .. ") p el " .. DANO .. " a distancia")
  if a then return { kind = "next", bonus = num(a), ranged = true } end
  -- Seal of the Crusader: "otorgando 51 p. de poder de ataque cuerpo a cuerpo. El paladín ataca un 40% más rápido"
  a, p = match(t, "otorgando (" .. NUM .. ") p de poder de ataque cuerpo a cuerpo%. +el palad" .. I .. "n ataca un (" .. NUM .. ") ?%% m" .. A .. "s r" .. A .. "pido")
  if a then return { kind = "ap", amount = num(a), faster = num(p) } end
  -- Strength of Earth, Grace of Air: "aumenta la fuerza de los miembros del grupo o de la banda en 7 p."
  a = match(t, "aumenta la fuerza [^%.]-en (" .. NUM .. ") p")
  if a then return { kind = "stat", stat = "str", amount = num(a) } end
  a = match(t, "aumenta la agilidad [^%.]-en (" .. NUM .. ") p")
  if a then return { kind = "stat", stat = "agi", amount = num(a) } end
  return nil
end

-- "Desatar la energía de este sello infligirá 25 a 27 p. de daño Sagrado a un enemigo"
local function judgement(part)
  local lo, hi, school = match(part, "(" .. NUM .. ") a (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "*)")
  if not lo then return nil end
  return lo, hi, schoolAfter((gsub(school, "^ +", "")))
end

local function sealDuration(t)
  return match(t, "durante (" .. NUM .. ") sec") or match(t, "dura (" .. NUM .. ") sec")
end

local function special(t)
  local n, m, dur, lo, hi, school, extra, first
  -- shields: "absorbe 44 p. de daño", "amortiguando 86 p. de daño", with the heal of Plan de contingencia
  -- ("le sanará 125 p. de salud durante 15 s")
  n = match(t, "absorb[a-z\128-\255]* (" .. NUM .. ") p") or match(t, "amortigua[a-z\128-\255]* (" .. NUM .. ") p")
  if n then
    local r = { absorb = num(n) }
    local total, seconds = match(t, "sanar" .. A .. " (" .. NUM .. ") p de salud durante (" .. NUM .. ") sec")
    if total then r.hot = { total = num(total), duration = num(seconds) } end
    return r
  end
  -- Lay on Hands: "en una cantidad equivalente a la salud máxima del paladín"
  if find(t, "equivalente a la salud m" .. A .. "xima del palad" .. I .. "n", 1, true) then return { healMaxHealth = true } end
  -- Life Tap: "Convierte 49 p. de salud en 49 p. de maná."
  n, m = match(t, "convierte (" .. NUM .. ") p de salud en (" .. NUM .. ") p de " .. MANA)
  if n then return { healthCost = num(n), manaGain = num(m) } end
  -- Holy Shock: "causando 175 a 189 p. de daño Sagrado a un enemigo o curando 150 a 162 p. a un aliado", "inflige 129 a 139
  -- p. de daño Sagrado a un enemigo o sana 110 a 118 p. a un aliado"
  local hlo, hhi
  lo, hi, school, hlo, hhi = match(t, "(" .. NUM .. ") a (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "-) a un enemigo o %a+ ("
    .. NUM .. ") a (" .. NUM .. ") p a un aliado")
  if lo then return { direct = D(lo, hi), heal = D(hlo, hhi), school = schoolOfDamage(school) } end
  -- Penance: "inflige 42 p. de daño Sagrado a un enemigo o aplica 126 p. de sanación a un aliado de forma instantánea y cada
  -- 1 s durante 2 s": the first hit and the ticks, as the English pack counts them
  local dmg, h, iv
  dmg, school, h, iv, dur = match(t, "inflige (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "-) a un enemigo o aplica (" .. NUM
    .. ") p de sanaci" .. O .. "n a un aliado de forma instant" .. A .. "nea y cada (" .. NUM .. ") sec durante (" .. NUM .. ") sec")
  if dmg then
    local hits = 1 + floor(num(dur) / num(iv) + 0.5)
    return { direct = D(num(dmg) * hits), heal = D(num(h) * hits), school = schoolOfDamage(school), hits = hits }
  end
  -- Death Coil: "causa 272 p. de daño de las Sombras. El taumaturgo transforma en salud el 100% del daño causado"
  n, school = match(t, "causa (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "-)%. +el taumaturgo transforma en salud el 100 ?%% del " .. DANO .. " causado")
  if n then return { direct = D(n), heal = D(n), school = schoolOfDamage(school), transfer = true } end
  -- Execute: "causando 125 p. de daño y convirtiendo cada punto extra de ira en 3 p. de daño extra"
  n, m = match(t, "causando (" .. NUM .. ") p de " .. DANO .. " y convirtiendo cada punto extra de ira en (" .. NUM .. ") p de " .. DANO)
  if n then return { direct = D(n), school = "physical", perRage = num(m) } end
  -- Searing Totem: "ataca repetidamente al enemigo que está en un radio de 20 metros causando 9 a 11 p. de daño de Fuego"
  lo, hi, school = match(t, "ataca repetidamente al enemigo [^%.]-causando (" .. NUM .. ") a (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "*)")
  if lo then return { direct = D(lo, hi), school = schoolOfDamage(school), perAttack = true } end
  -- Healing Stream Totem: "cura a los miembros del grupo en 5 p. en un radio de 30 metros cada 2 segundos"
  n, m = match(t, "cura a los miembros del grupo en (" .. NUM .. ") p en un radio de " .. NUM .. " metros cada (" .. NUM .. ") sec")
  if n then return { heal = D(n), every = num(m) } end
  -- Retribution Aura: "Inflige 5 p. de daño Sagrado a cualquier criatura que golpee a un miembro del grupo"
  n, school = match(t, "inflige (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "-) a cualquier criatura que golpee a un miembro del grupo")
  if n then return { direct = D(n), school = schoolOfDamage(school), perStrike = true } end
  -- Holy Shield: "inflige 75 p. de daño Sagrado por cada ataque bloqueado"
  n, school = match(t, "inflige (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "-) por cada ataque bloqueado")
  if n then return { direct = D(n), school = schoolOfDamage(school), perBlock = true } end
  -- Consecration: "inflige 24 p. de daño Sagrado durante 8 s a los enemigos que lo pisen. Los primeros 4 enemigos que pisen
  -- el suelo consagrado reciben 56 p. más de daño durante 8 s"
  n, school, dur, first, extra = match(t, "inflige (" .. NUM .. ") p de " .. DANO .. " (" .. W .. "-) durante (" .. NUM
    .. ") sec a los enemigos que lo pisen%.? +los primeros (" .. NUM .. ") enemigos [^%.]-reciben (" .. NUM .. ") p m" .. A
    .. "s de " .. DANO .. " durante " .. NUM .. " sec")
  if n then
    return { dot = { total = num(n) + num(extra), duration = num(dur) }, school = schoolOfDamage(school), first = num(first) }
  end
  -- Tranquility: "Regenera 87 p. a todos los miembros del grupo en un radio de 20 m cada 2 s durante 10 s"
  local every
  n, every, dur = match(t, "regenera (" .. NUM .. ") p a todos los miembros del grupo [^%.]-cada (" .. NUM .. ") sec durante (" .. NUM .. ") sec")
  if n then return { hot = { total = num(n) * floor(num(dur) / num(every) + 0.5), duration = num(dur) } } end
  -- Dark Sacrifice: "Canibalizas 400 p. de tu propia salud durante 15 s para obtener 428 p. de man\195\161"
  n, dur, m = match(t, "canibalizas (" .. NUM .. ") p de tu propia salud durante (" .. NUM .. ") sec para obtener (" .. NUM .. ") p de " .. MANA)
  if n then return { healthCost = num(n), manaGain = num(m), healthCostDuration = num(dur) } end
  -- Seal of Light, per trigger: "la posibilidad de curar 39 p. al paladín"
  n = match(t, "posibilidad de curar (" .. NUM .. ") p al palad" .. I .. "n")
  if n then return { heal = D(n) } end
  -- Well of Light: "para recuperar 800 p. de salud durante 10 s"
  n, dur = match(t, "para recuperar (" .. NUM .. ") p de salud durante (" .. NUM .. ") sec")
  if n then return { hot = { total = num(n), duration = num(dur) } } end
  return nil
end

-- "1 punto: 25 p. de daño durante 8 s": the damage over time in one point's row, or "25 durante 8 sec" where the
-- description names damage elsewhere (damageText).
local function finisherDot(seg, damageText)
  local total, dur = match(seg, "^ *(" .. NUM .. ") p de " .. DANO .. " durante (" .. NUM .. ") sec")
  if not total then total, dur = match(seg, "^ *(" .. NUM .. ") de " .. DANO .. " durante (" .. NUM .. ") sec") end
  if not total and damageText then total, dur = match(seg, "^ *(" .. NUM .. ") durante (" .. NUM .. ") sec") end
  return total, dur
end

-- The chance per hit: its percent, true where the text names a chance without a figure, or nil.
local function procChance(t)
  local p = match(t, "cada [^%.]- tiene un (" .. NUM .. ") ?%% de probabilidad")
  if p then return num(p) end
  for _, chance in ipairs({ "probabilidad de infligir", "probabilidad de causar", "probabilidad de envenenar",
    "probabilidad de otorg", "posibilidad de curar", "posibilidad de infligir", "posibilidad de restaurar" }) do
    if find(t, chance, 1, true) then return true end
  end
  return nil
end

-- A text that reads as nothing: damage the pack has no wording for, an effect, or a utility spell.
local function unreadKind(t)
  for after in t:gmatch(NUM .. "([^0-9]*)") do
    local s = stripFillers(after, FILLERS_ES)
    if sub(s, 1, #DANO) == DANO then return "unread-damage" end
  end
  if hasAny(t, { DANO, "p de salud", "poder de ataque", "absorb" }) and not find(t, "recib", 1, true) then
    return "unread-effect"
  end
  return "utility"
end

Parser.RegisterPack("es", {
  rangeWord = "a",
  damageWord = DANO,
  weaponWord = WEAPON,
  pointsMarker = "p[a-z]*",
  healWords = { " cura ", " curar ", " curando ", " curas ", " sana ", " sanar ", " sanando ", " sanado ", " sanar" .. A .. " ", " restaura ", " restaurar ",
    " restablece ", " recupera ", " regenera ", "sanaci" },
  clauseSeparators = { ", y ", " y ", " e ", " pero ", " o " },
  reduceVerbs = REDUCE_VERBS,
  enemyWords = { "objetivo", "enemigo", "atacante" },
  selfWords = { " te ", " tu ", " tus ", "recib" },
  increaseWord = "aument",
  byWord = "en ",
  sealEnergy = "desatar la energ" .. I .. "a de este sello",
  judgementSpell = "desata la energ" .. I .. "a de un hechizo de sello",
  words = SPANISH_WORDS,
  units = { sec = 1, segundo = 1, min = 60, hora = 3600 },
  distanceWords = { m = true, metros = true, metro = true },
  hp5 = "(" .. NUM .. ") p la regeneraci" .. O .. "n de salud cada (" .. NUM .. ") sec",
  tickTails = { "^ *cada ", "^ *por segundo" },
  durationMarkers = { " sec", " min", "durante ", "cada " },
  drainWords = { "drena" },
  manaWord = MANA,
  healing = {
    targets = { "y al taumaturgo" },
    channel = { "canaliz", "de forma instant" .. A .. "nea y cada" },
    trigger = { "hacer clic", "la pr" .. O .. "xima vez", "probabilidad", "posibilidad" },
    stack = { "acumul", "expira" },
    pet = { "mascota", "macota", "ayudante" },
    target = { " a tu objetivo", " tu objetivo", " un objetivo amigo", " un objetivo amistoso", " a un aliado", " un aliado" },
  },
  lower = lower,
  detect = detect,
  toEnglish = toEnglish,
  normaliseNumbers = normaliseNumbers,
  rewrite = rewrite,
  prepareSentences = function(t) return t end,
  takeLasts = takeLasts,
  takeInterval = takeInterval,
  classifyAfter = classifyAfter,
  healAmountOK = healAmountOK,
  ignoredClause = ignoredClause,
  perPointTable = perPointTable,
  healthPercent = function() end,
  instantPercent = function() end,
  extraPercent = function() end,
  itemHeal = itemHeal, itemDrink = itemDrink,
  reductionStat = reductionStat,
  weapon = weaponES,
  attackPower = attackPowerIn,
  judgement = judgement,
  sealDuration = sealDuration,
  special = special,
  finisherDot = finisherDot,
  procChance = procChance,
  unreadKind = unreadKind,
})
