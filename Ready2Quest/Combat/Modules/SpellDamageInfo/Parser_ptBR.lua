-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: Brazilian Portuguese language pack of the spell parser.
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
--
-- The wordings of WoW: Forever's Portuguese spell descriptions: "causa 15 para 23 de dano de Fogo", "ao longo de
-- 4 s", "a cada 2 s", "1 ponto: 57 de dano ao longo de 12 s", the decimal comma. What a pack is, and how to add one,
-- is in Parser.lua (LANGUAGE PACKS).
-- WRITTEN FROM WOWHEAD'S FOREVER TOOLTIPS (nether.wowhead.com/forever/tooltip/spell/<id>?locale=pt): the wording of the
-- French and Spanish pages matched the game's own texts, the numbers and the range word ("15 para 23" here, "14 a 23" in
-- the Spanish game) did not always, so the range words "para", "a" and "at\195\169" are all read.
-- CHECKED AGAINST A REAL /sdi dump all OF A PORTUGUESE CLIENT (build 1.60.1.70938, 1697 spells, the same ids as the French
-- and Spanish dumps) and corrected where the game words it differently: "causando 19 a 23 de dano", "Curando 200 a cada
-- 1 s por 2 s", "uma cura de 298 na pr\195\179xima vez", ", depois mais 39 de dano ... ao longo de 12 s", "Converte 241 pontos de vida em
-- 241 pontos de mana", "Cada acerto causa de 14 a 46 a mais de dano de Fogo", the school names "de Fogo M\195\173stico", "de Gelo
-- M\195\161gico", "de Sombra G\195\169lida", "de Chama Sombria". 1144 of the 1697 are read (French: 1144), with the tick-only readings of Parser.lua. Not seen in a running game
-- yet. A wording the pack does not know stays unread: it never guesses.
-- Pure Lua 5.1, no game API.

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT and BIT.Module and BIT.Module("SpellDamageInfo") or BIT or {}
local Parser = ns.Parser

local U = Parser.util
local NUM, num, D, hasAny, stripFillers = U.NUM, U.num, U.D, U.hasAny, U.stripFillers
local find, sub, gsub, match = string.find, string.sub, string.gsub, string.match
local tonumber, floor = tonumber, math.floor

local A, E, I, O, C, AT, EC = "\195\161", "\195\169", "\195\173", "\195\179", "\195\167", "\195\163", "\195\170" -- á é í ó ç ã ê
local W = "[a-z\128-\255' %-]" -- the characters of a few words, accents included
local DANO = "dano"
local WEAPON = "dano da arma"
local FEITICO = "feiti" .. C .. "o"

-- School words after "dano", longest first. "dano de Fogo", "de Sombra", "Sagrado", "Arcano", "Físico". The game's own
-- (not Wowhead's) names of the mixed schools: "de Fogo Místico", "de Gelo Mágico", "de Sombra Gélida", "de Chama Sombria",
-- "de Fogofrio".
local SCHOOLS = {
  { "de fogofrio", "frostfire" }, { "de fogofr" .. I .. "o", "frostfire" }, { "de chama sombria", "shadowflame" },
  { "de chamasombria", "shadowflame" }, { "de fogo m" .. I .. "stico", "spellfire" }, { "de gelo m" .. A .. "gico", "spellfrost" },
  { "de sombra g" .. E .. "lida", "shadowfrost" },
  { "de fogo", "fire" }, { "de gelo", "frost" }, { "de natureza", "nature" }, { "de sombra", "shadow" },
  { "sagrado", "holy" }, { "arcano", "arcane" }, { "f" .. I .. "sico", "physical" }, { "de sangramento", "physical" },
  { "de caos", "chaos" }, { "quim" .. E .. "rico", "chimeral" },
}

-- Words that may sit between an amount and its damage word.
local FILLERS_PT = {
  "pontos de ", "ponto de ", "pontos ", "ponto ", "a mais de ", "a mais ", "mais de ", "mais ",
  "adicionais de ", "adicionais ", "de ",
}

-- Words of this language, for telling a Portuguese client's English texts (Forever leaves some of its spells in
-- English, e.g. Ferocious Bite).
local PORTUGUESE_WORDS = { " de ", " do ", " da ", " dos ", " das ", " ao ", " em ", " um ", " uma ", " o alvo", " por ",
  " pontos", DANO .. " " }

-- Capital letters of Latin-1 to lower case (UTF-8): Á -> á, Ç -> ç ...
local function lower(t)
  return (gsub(t, "\195[\128-\150\152-\158]", function(c) return "\195" .. string.char(c:byte(2) + 32) end))
end

local function detect(t)
  return find(t, " de " .. DANO, 1, true) or find(t, " pontos de ", 1, true)
end

-- Numbers as the English readers take them: "1.742" -> "1742", "1 290" -> "1290", "1,2" -> "1.2".
local function englishNumbers(t)
  local prev
  repeat
    prev = t
    t = gsub(t, "%f[0-9]([0-9][0-9]?[0-9]?) ([0-9][0-9][0-9])%f[^0-9]", "%1%2")
    t = gsub(t, "%f[0-9]([0-9][0-9]?[0-9]?)%.([0-9][0-9][0-9])%f[^0-9.]", "%1%2")
  until t == prev
  return (gsub(t, "([0-9]),([0-9])", "%1.%2"))
end

local function toEnglish(text)
  text = englishNumbers(gsub(text, "\194\160", " "))
  return (gsub(text, "([0-9]) s%f[^a-z\128-\255]", "%1 sec"))
end

-- "1.742", "1,2", a bare "s" as a unit ("ao longo de 12 s", "a cada 2 s"), the unit words spelled out.
local function normaliseNumbers(t)
  t = englishNumbers(t)
  t = gsub(t, "([0-9]) s%f[^a-z\128-\255]", "%1 sec")
  t = gsub(t, "([0-9]) segundos?%f[^a-z\128-\255]", "%1 sec")
  t = gsub(t, "([0-9]) minutos?%f[^a-z\128-\255]", "%1 min")
  t = gsub(t, "([0-9]) horas?%f[^a-z\128-\255]", "%1 hora")
  return t
end

-- One spelling of the range words and of the phrases that say a number is weapon damage, so one word covers them.
local function rewrite(t)
  -- ranges: "15 para 23", "15 at\195\169 23", "de 15 a 23", "de 3 a 13" (all read as "15 a 23")
  t = gsub(t, "(" .. NUM .. ") para (" .. NUM .. ")", "%1 a %2")
  t = gsub(t, "(" .. NUM .. ") at" .. E .. " (" .. NUM .. ")", "%1 a %2")
  t = gsub(t, "([ :,]) *de (" .. NUM .. ") a (" .. NUM .. ")", "%1 %2 a %3")
  t = gsub(t, "entre (" .. NUM .. ") e (" .. NUM .. ")", "%1 a %2")
  -- the Judgement phrase of every seal: "Ao liberar a energia do Selo", "Liberar a energia deste Selo"
  t = gsub(t, "liberar a energia d[eo][a-z]* selo", "liberar a energia do selo")
  t = gsub(t, "libera a energia de um " .. FEITICO .. " de selo", "libera a energia de um " .. FEITICO .. " de selo")
  -- weapon damage: "do dano da arma", "o dano da sua arma", "dano normal da arma", "dano da arma corpo a corpo", "dano das duas
  -- armas de combate corpo a corpo"
  t = gsub(t, DANO .. " da sua arma", WEAPON)
  t = gsub(t, DANO .. " normal da arma", WEAPON)
  t = gsub(t, DANO .. " da arma normal", WEAPON)
  t = gsub(t, DANO .. " da arma corpo a corpo", WEAPON)
  t = gsub(t, DANO .. " das duas armas de combate corpo a corpo", WEAPON)
  t = gsub(t, DANO .. " das duas armas", WEAPON)
  t = gsub(t, DANO .. " das armas", WEAPON)
  -- Health Funnel: "D\195\161 12 pontos de vida ao ajudante do lan\195\167ador a cada segundo": the health the caster pays, no heal
  t = gsub(t, "d" .. A .. " (" .. NUM .. ") pontos de vida ([^%.]-)ao ajudante", "aloca %1 pontos de vida %2ao ajudante")
  t = gsub(t, "d" .. A .. " (" .. NUM .. ") pontos de vida ([^%.]-)ao pet", "aloca %1 pontos de vida %2ao pet")
  -- a totem's own health ("com 5 pontos de vida") is no amount of the spell
  t = gsub(t, " com " .. NUM .. " pontos de vida", " ")
  -- Wild Growth: "Cura 336 pontos de vida do alvo e do grupo dele ao longo de 7 s" is one amount over one time
  t = gsub(t, " e do grupo dele ao longo de ", " ao longo de ")
  -- reductions: "reduzindo em 56 o poder de ataque", "Reduz em 4 o dano F\195\173sico causado ao alvo" already say "em"
  -- a stun inside a damage clause: "atordoa o alvo por 2 s e causa 114 de dano ao longo de 18 s"
  t = gsub(t, "atordoa o alvo por " .. NUM .. " sec", "atordoa o alvo")
  -- Shockwave: "atordoando e causando 30 de dano a todos os inimigos em uma \195\161rea c\195\180nica de 10 m \195\160 frente do lan\195\167ador por 4 s": the
  -- 4 s is the stun, not a damage over time
  t = gsub(t, "(atordoando e causando [^%.]-) por " .. NUM .. " sec", "%1")
  -- Lacerate: the stacking tail ("plus 10% weapon damage per existing application") is no part of the first application's damage:
  -- the base is what the text names, and the weapon word would veto the whole reading
  t = gsub(t, ", mais " .. NUM .. " ?%% do " .. WEAPON .. " por aplica[^%.]*", "")
  return (gsub(t, " +", " "))
end

local function takeLasts(t, take)
  t = gsub(t, "dura (" .. NUM .. ") ([a-z]+)", take)
  t = gsub(t, "dura" .. C .. AT .. "o de (" .. NUM .. ") ([a-z]+)", take)
  return t
end

local function takeInterval(c, onNumber, onOne)
  c = gsub(c, "a cada (" .. NUM .. ") ([a-z]+)", onNumber)
  c = gsub(c, "a cada segundo", onOne)
  c = gsub(c, "por segundo", onOne)
  return c
end

-- The school named by the words after "dano": its code, false where a word follows that is no school ("dano
-- recebido", "dano m\195\161gico"), or "physical" where nothing school-like follows ("15 de dano ao longo de 12 s").
local function schoolAfter(s)
  for _, school in ipairs(SCHOOLS) do
    local words = school[1]
    if sub(s, 1, #words) == words and not match(sub(s, #words + 1, #words + 1), "[a-z\128-\255]") then
      return school[2]
    end
  end
  if match(s, "^d[eoa]s? ") or match(s, "^de$") or match(s, "^recebido") or match(s, "^m" .. A .. "gico") or match(s, "^causado")
    or match(s, "^somado") or match(s, "^da ") then
    return false
  end
  return "physical"
end

-- What the words right after an amount say it is: damage of a school, a health drain, health given, or nothing we
-- understand.
local function classifyAfter(after, sentence)
  local s = stripFillers(after, FILLERS_PT)
  if sub(s, 1, #DANO) == DANO then
    local school = schoolAfter((gsub(sub(s, #DANO + 1), "^ +", "")))
    if school then return "damage", school end
    return nil
  end
  if sub(s, 1, 4) == "vida" then
    if find(sentence, "transfere", 1, true) then return "drain", nil end
    if find(sentence, "aloca ", 1, true) then return "petheal", nil end
    -- a bleed: "perde 15 pontos de vida ao longo de 9 s"
    if find(sentence, "sangr", 1, true) and find(sentence, "perde ", 1, true) then return "damage", "physical" end
  end
  return nil
end

-- A heal amount is followed by "pontos de vida", or by nothing ("Cura 260 para 300 ..."): "pontos de mana" and counts of
-- anything else are not.
local function healAmountOK(_, after)
  local s = gsub(after, "^ +", "")
  local rest = match(s, "^pontos?%f[^a-z\128-\255]%s*(.*)$")
  if rest then
    if match(rest, "^de ") then return match(rest, "^de vida%f[^a-z\128-\255]") ~= nil end
    return true
  end
  -- "Cura 45 de dano ao longo de 15 s" (Forever's Spanish does it for Renew): the amount before "de dano"
  if match(s, "^de " .. DANO .. "%f[^a-z\128-\255]") then return true end
  -- "Concede 179 a 191 de cura ao alvo", and an amount with nothing but a time after it ("Curando 134 a cada 1 s por 2 s")
  if match(s, "^de cura%f[^a-z\128-\255]") then return true end
  if match(s, "^[%. #]*$") or match(s, "^ao longo") or match(s, "^por ") then return true end
  -- the interval and the duration are already taken out of the clause: "Curando 126 # por #" (Penance's ticks)
  if match(s, "^# +por ") then return true end
  -- Prayer of Mending: "concede ao alvo uma cura de 298 na pr\195\179xima vez que ele receber dano"
  if match(s, "^na pr" .. O .. "xima vez") then return true end
  return false
end

-- Clauses whose amounts are not the spell's damage or healing: absorbs, amounts per unit of something else, the
-- caster's own damage, damage passed on, a stat lowered.
local function ignoredClause(c)
  -- Hellfire: "causando 86 de dano de Fogo a si pr\195\179prio e 86 ... a todos os inimigos pr\195\179ximos": the caster's own
  return find(c, " a si pr", 1, true) or find(c, "absorv", 1, true) or find(c, "para cada ", 1, true) or find(c, "a cada ponto", 1, true)
    or find(c, "reduz[a-z]* em " .. NUM) or find(c, "reduzindo em " .. NUM)
end

-- Per-combo-point tables ("1 ponto: 20 de dano").
local function perPointTable(t)
  return find(" " .. t, "[^0-9]1 pontos? *:")
end

-- A consumable's amounts: health lo..hi, mana mlo..mhi, and a stated duration.
local function itemHeal(t)
  local lo, hi, mlo, mhi
  local dur, minutes = nil, false
  mlo, mhi = match(t, "restaura (" .. NUM .. ") a (" .. NUM .. ") pontos de mana")
  if not mlo then mlo = match(t, "restaura (" .. NUM .. ") pontos de mana") end
  do
    local a, b, d
    for _, unit in ipairs({ "sec", "min" }) do
      for _, verb in ipairs({ "restaura", "cura" }) do
        if not a then a, b, d = match(t, verb .. " (" .. NUM .. ") a (" .. NUM .. ") pontos de vida ao longo de (" .. NUM .. ") " .. unit) end
        if not a then a, d = match(t, verb .. " (" .. NUM .. ") pontos de vida ao longo de (" .. NUM .. ") " .. unit) end
      end
      if a then if unit == "min" then minutes = true end break end
    end
    if a then lo, hi, dur = a, (b or a), d end
  end
  if not dur then
    for _, verb in ipairs({ "restaura", "cura" }) do
      if not lo then lo, hi = match(t, verb .. " (" .. NUM .. ") a (" .. NUM .. ") pontos de vida") end
      if not lo then lo = match(t, verb .. " (" .. NUM .. ") pontos de vida") end
    end
  end
  return lo, hi, mlo, mhi, dur, minutes
end

-- A drink: mana total, seconds, and the health total where one wording names both.
-- "Uso: Restaura 151 pontos de mana ao longo de 18 s."
local function itemDrink(t)
  local h, m, d = match(t, "restaura (" .. NUM .. ") pontos de vida e (" .. NUM .. ") pontos de mana ao longo de (" .. NUM .. ") sec")
  if m then return m, d, h end
  m, d = match(t, "restaura (" .. NUM .. ") pontos de mana ao longo de (" .. NUM .. ") sec")
  return m, d
end

local REDUCE_VERBS = { "reduz", "diminu" }

-- A debuff's own words: the attack power and damage a clause names.
local function reductionStat(c)
  return find(c, "poder de ataque", 1, true), find(c, DANO, 1, true)
end

-- The school of "dano Sagrado adicional": the words from "dano" on.
local function schoolOfDamage(s)
  return schoolAfter((gsub(s, "^ +", ""))) or nil
end

-- "aumentando em 12 o poder de ataque", "aumentando em 26 o Poder de Ataque de Longo Alcance de todos atacantes": the
-- first amount after "em".
local function attackPowerIn(sentence)
  if not find(sentence, "poder de ataque", 1, true) then return nil end
  if hasAny(sentence, REDUCE_VERBS) or find(sentence, "chance", 1, true) or find(sentence, "menos " .. DANO, 1, true) then
    return nil
  end
  if not hasAny(sentence, { "aument", "concede", "recebe" }) then return nil end
  if find(sentence, "[^0-9]1 pontos? *:") then return nil end
  local a = match(sentence, "aument[a-z\128-\255]* em (" .. NUM .. ") o poder de ataque")
    or match(sentence, "aument[a-z\128-\255]* em (" .. NUM .. ") o poder")
    or match(sentence, "mais (" .. NUM .. ") de poder de ataque")
    or match(sentence, "e em (" .. NUM .. ") o poder de ataque")
  if not a then return nil end
  return { kind = "ap", amount = num(a), ranged = find(sentence, "longo alcance", 1, true) ~= nil,
    plusAgility = find(sentence, "poder de ataque mais agilidade", 1, true) ~= nil }
end

local function weaponPT(t)
  local p, a, b, school
  -- Windfury Weapon and Totem: "chance de conceder a voc\195\170 2 ataques corpo a corpo extras com mais 104 de poder de ataque"
  a, b = match(t, "(" .. NUM .. ") ataques? corpo a corpo extras? com mais (" .. NUM .. ") de poder de ataque")
  if not a then a, b = match(t, "(" .. NUM .. ") ataques? extras? com mais (" .. NUM .. ") de poder de ataque") end
  -- the game's own wording of Windfury Weapon: "chance de conceder a voc\195\170 2 ataques extras com 249 de poder de ataque corpo a
  -- corpo extra"
  if not a then a, b = match(t, "(" .. NUM .. ") ataques? extras? com (" .. NUM .. ") de poder de ataque corpo a corpo extra") end
  if a then return { kind = "extra", attacks = num(a), amount = num(b) } end
  -- Mutilate: "causando 90% do dano da arma mais 40 com cada arma"
  p, a = match(t, "(" .. NUM .. ") ?%% do " .. WEAPON .. " mais (" .. NUM .. ") com cada arma")
  if p then return { kind = "both", pct = num(p), bonus = num(a) } end
  -- Seal of Command: "chance de causar dano Sagrado adicional equivalente a 70% do dano da arma normal"
  school, p = match(t, "chance de causar " .. DANO .. " (" .. W .. "-) [^%d%.]-(" .. NUM .. ") ?%% do " .. WEAPON)
  if p then return { kind = "weapon", pct = num(p), bonus = 0, school = schoolOfDamage(school) } end
  if find(t, "chance", 1, true) or find(t, "com cada arma", 1, true) then return nil end
  -- Flametongue, Seal of Righteousness: "Cada acerto causa de 3 a 13 a mais de dano de Fogo com base na velocidade da arma"
  -- (the game: "Cada acerto causa de 14 a 46 a mais de dano de Fogo com base na velocidade da arma", Seal of Righteousness:
  -- "fazendo com que cada ataque corpo a corpo cause de 2 a 9 de dano Sagrado adicional"; "de 14 a 46" is "14 a 46" by now)
  local lo, hi
  for _, each in ipairs({ "cada acerto ", "cada ataque " }) do
    lo, hi, school = match(t, each .. "[^%.]-caus[ae] (" .. NUM .. ") a (" .. NUM .. ") a mais de " .. DANO .. " (" .. W .. "-) com base na velocidade")
    if not lo then
      lo, hi, school = match(t, each .. "[^%.]-caus[ae] (" .. NUM .. ") a (" .. NUM .. ") de " .. DANO .. " (" .. W .. "-) adicional")
    end
    if not lo then
      lo, hi, school = match(t, each .. "[^%.]-caus[ae] (" .. NUM .. ") a (" .. NUM .. ") de " .. DANO .. " (" .. W .. "-) com base na velocidade")
    end
    if lo then break end
  end
  if lo then
    return { kind = "perhit", min = num(lo), max = num(hi), school = schoolOfDamage(school),
      bySpeed = find(t, "armas mais lentas", 1, true) and true or nil }
  end
  -- Seal of Fury: "fazendo ataques corpo a corpo causarem 14 a mais de dano Sagrado"
  a, school = match(t, "ataques corpo a corpo causarem (" .. NUM .. ") a mais de " .. DANO .. " (" .. W .. "-)[%.,]")
  if a then return { kind = "perhit", min = num(a), max = num(a), school = schoolOfDamage(school) } end
  -- Claw, Ravage, Shred, Savage Bite: "causando 140% do dano normal mais 27", "435% do dano mais 42", "100% do dano normal mais 42"
  p, a = match(t, "(" .. NUM .. ") ?%% do " .. DANO .. " normal mais (" .. NUM .. ")")
  if not p then p, a = match(t, "(" .. NUM .. ") ?%% do " .. DANO .. " mais (" .. NUM .. ")") end
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  -- Holy Strike: "causa 29% do dano da arma, mais 15 a 20 como dano Sagrado"
  p, a, b = match(t, "(" .. NUM .. ") ?%% do " .. WEAPON .. ", mais (" .. NUM .. ") a (" .. NUM .. ") como " .. DANO)
  if p then return { kind = "weapon", pct = num(p), bonus = num(a), bonusMax = num(b) } end
  -- Backstab, Ambush: "causando 150% do dano da arma mais 10 ao alvo"
  p, a = match(t, "(" .. NUM .. ") ?%% do " .. WEAPON .. " mais (" .. NUM .. ")")
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  -- Bloodthirst, Shuriken Toss: "causando dano equivalente a 45% do seu Poder de Ataque mais 30"
  p, a = match(t, "(" .. NUM .. ") ?%% do seu poder de ataque mais (" .. NUM .. ")")
  if not p then p = match(t, "(" .. NUM .. ") ?%% do seu poder de ataque") end
  if p then return { kind = "appct", pct = num(p), bonus = num(a) or 0 } end
  -- "causa 150% do dano da arma", "Voc\195\170 causa 135% do dano da arma", "tamb\195\169m causa 150% do dano da arma"
  p = match(t, "causa[a-z]* " .. W .. "-(" .. NUM .. ") ?%% do " .. WEAPON)
  if p then return { kind = "weapon", pct = num(p), bonus = 0 } end
  -- Heroic Strike's relatives: "causa o dano da arma mais 5", "causando dano da arma mais 32", "causa 3 de dano somado ao dano da
  -- arma", "causa dano da arma corpo a corpo mais 5"
  a = match(t, "causa[a-z]* [a-z ]-" .. WEAPON .. " mais (" .. NUM .. ")")
    or match(t, "causa (" .. NUM .. ") de " .. DANO .. " somado ao " .. WEAPON)
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  -- Hammer of the Righteous: "causando dano Sagrado a cada um equivalente a 3 vezes o dano por segundo da sua arma da m\195\163o principal"
  a = match(t, "equivalente a (" .. NUM .. ") vezes o " .. DANO .. " por segundo da sua arma da m" .. AT .. "o principal")
  if a then return { kind = "dps", times = num(a), school = find(t, "dano sagrado", 1, true) and "holy" or "physical" } end
  -- Sniper Shot: "causa dano de longo alcance mais 320": the ranged weapon's hit plus the amount
  a = match(t, "causa[a-z]* dano de longo alcance mais (" .. NUM .. ")")
  if a then return { kind = "weapon", pct = 100, bonus = num(a), ranged = true } end
  -- Whirlwind: "causando o dano da arma a cada inimigo"
  if find(t, "causando [a-z ]-" .. WEAPON .. " a cada") then return { kind = "weapon", pct = 100, bonus = 0 } end
  -- the next swing, or a shot, gets more: "aumenta em 11 o dano corpo a corpo", "Aumenta em 18 o dano do pr\195\179ximo ataque", "aumenta em
  -- 40 o dano de longo alcance"
  a = match(t, "aumenta em (" .. NUM .. ") o " .. DANO .. " corpo a corpo")
    or match(t, "aumenta em (" .. NUM .. ") o " .. DANO .. " de ataque corpo a corpo")
    or match(t, "aumenta em (" .. NUM .. ") o " .. DANO .. " do pr" .. O .. "ximo ataque")
  if a then return { kind = "next", bonus = num(a) } end
  a = match(t, "aumenta em (" .. NUM .. ") o " .. DANO .. " de longo alcance")
  if a then return { kind = "next", bonus = num(a), ranged = true } end
  -- Seal of the Crusader: "aumentando em 60 o Poder de Ataque Corpo a Corpo. Tamb\195\169m aumenta em 40% a velocidade de ataque"
  a, p = match(t, "aumentando em (" .. NUM .. ") o poder de ataque corpo a corpo%. +tamb" .. E .. "m aumenta em (" .. NUM .. ") ?%% a velocidade de ataque")
  if a then return { kind = "ap", amount = num(a), faster = num(p) } end
  -- Strength of Earth, Grace of Air: "aumenta em 30 a For\195\167a dos integrantes do grupo"
  -- (not Horn of Lordaeron's "aumenta em 6 a For\195\167a e a Agilidade": the Strength alone is not what it gives)
  a = match(t, "aumenta em (" .. NUM .. ") a for" .. C .. "a ")
  if a and not find(t, "for" .. C .. "a e a agilidade", 1, true) then return { kind = "stat", stat = "str", amount = num(a) } end
  a = match(t, "aumenta em (" .. NUM .. ") a agilidade ")
  if a then return { kind = "stat", stat = "agi", amount = num(a) } end
  return nil
end

-- "Ao liberar a energia do Selo, o inimigo ser\195\161 julgado, recebendo 97 a 104 de dano Sagrado"
local function judgement(part)
  local lo, hi, school = match(part, "(" .. NUM .. ") a (" .. NUM .. ") de " .. DANO .. " (" .. W .. "*)")
  if not lo then return nil end
  return lo, hi, schoolAfter((gsub(school, "^ +", "")))
end

local function sealDuration(t)
  return match(t, "por (" .. NUM .. ") sec") or match(t, "dura (" .. NUM .. ") sec")
end

local function special(t)
  local n, m, dur, lo, hi, school, extra, first
  -- shields: "absorvendo 48 de dano", "Absorve 162 de dano de Fogo", with the heal of Plano de Conting\195\170ncia ("come\195\167ar\195\161 a
  -- recuperar 125 pontos de vida ao longo de 15 s")
  n = match(t, "absorv[a-z\128-\255]* (" .. NUM .. ") de " .. DANO)
  if n then
    local r = { absorb = num(n) }
    local total, seconds = match(t, "recuperar (" .. NUM .. ") pontos de vida ao longo de (" .. NUM .. ") sec")
    if total then r.hot = { total = num(total), duration = num(seconds) } end
    return r
  end
  -- Lay on Hands: "em um valor equivalente ao m\195\161ximo de pontos de vida do Paladino"
  if find(t, "equivalente ao m" .. A .. "ximo de pontos de vida do paladino", 1, true) then return { healMaxHealth = true } end
  -- Holy Shock: "causando 175 a 189 de dano Sagrado a um inimigo ou curando 150 a 162 pontos de vida de um aliado"
  local hlo, hhi
  lo, hi, school, hlo, hhi = match(t, "(" .. NUM .. ") a (" .. NUM .. ") de " .. DANO .. " (" .. W .. "-) a um inimigo ou curando (" .. NUM
    .. ") a (" .. NUM .. ") pontos de vida de um aliado")
  if lo then return { direct = D(lo, hi), heal = D(hlo, hhi), school = schoolOfDamage(school) } end
  -- Penance: "causando 45 de dano Sagrado a um inimigo ou curando 134 pontos de vida de um aliado instantaneamente e a cada 1 s
  -- por 2 s": the first hit and the ticks, as the English pack counts them
  local dmg, h, iv
  dmg, school, h, iv, dur = match(t, "causando (" .. NUM .. ") de " .. DANO .. " (" .. W .. "-) a um inimigo ou curando (" .. NUM
    .. ") pontos de vida de um aliado instantaneamente e a cada (" .. NUM .. ") sec por (" .. NUM .. ") sec")
  if dmg then
    local hits = 1 + floor(num(dur) / num(iv) + 0.5)
    return { direct = D(num(dmg) * hits), heal = D(num(h) * hits), school = schoolOfDamage(school), hits = hits }
  end
  -- Death Coil: "causa 285 de dano de Sombra. O lan\195\167ador ganha 100% do dano causado como pontos de vida"
  n, school = match(t, "causa (" .. NUM .. ") de " .. DANO .. " (" .. W .. "-)%. +o lan" .. C .. "ador ganha 100 ?%% do " .. DANO .. " causado como pontos de vida")
  if n then return { direct = D(n), heal = D(n), school = schoolOfDamage(school), transfer = true } end
  -- Execute: "causando 125 de dano e convertendo cada ponto extra de Raiva em mais 3 de dano"
  n, m = match(t, "causando (" .. NUM .. ") de " .. DANO .. " e convertendo cada ponto extra de raiva em mais (" .. NUM .. ") de " .. DANO)
  if n then return { direct = D(n), school = "physical", perRage = num(m) } end
  -- Searing Totem: "que ataca repetidamente um inimigo em um raio de 20 m, causando 9 a 11 de dano de Fogo"
  lo, hi, school = match(t, "ataca repetidamente um inimigo [^%.]-causando (" .. NUM .. ") a (" .. NUM .. ") de " .. DANO .. " (" .. W .. "*)")
  if lo then return { direct = D(lo, hi), school = schoolOfDamage(school), perAttack = true } end
  -- Healing Stream Totem: "que cura 5 pontos de vida a cada 2 s dos integrantes do grupo em um raio de 30 m"
  n, m = match(t, "cura (" .. NUM .. ") pontos de vida a cada (" .. NUM .. ") sec dos integrantes do grupo")
  if n then return { heal = D(n), every = num(m) } end
  -- ... and its other wording: "para curar integrantes do grupo em um raio de 30 m por 11 a cada 2 segundos"
  n, m = match(t, "curar integrantes do grupo [^%.]-por (" .. NUM .. ") a cada (" .. NUM .. ") sec")
  if n then return { heal = D(n), every = num(m) } end
  -- Life Tap: "Converte 241 pontos de vida em 241 pontos de mana para voc\195\170"
  n, m = match(t, "converte (" .. NUM .. ") pontos de vida em (" .. NUM .. ") pontos de mana")
  if n then return { healthCost = num(n), manaGain = num(m) } end
  -- Retribution Aura: "Causa 5 de dano Sagrado a qualquer criatura que atingir um integrante do grupo"
  n, school = match(t, "causa (" .. NUM .. ") de " .. DANO .. " (" .. W .. "-) a qualquer criatura que atingir um integrante do grupo")
  if n then return { direct = D(n), school = schoolOfDamage(school), perStrike = true } end
  -- Holy Shield: "causa 75 de dano Sagrado a cada ataque bloqueado"
  n, school = match(t, "causa (" .. NUM .. ") de " .. DANO .. " (" .. W .. "-) a cada ataque bloqueado")
  if n then return { direct = D(n), school = schoolOfDamage(school), perBlock = true } end
  -- Consecration: "causando 24 de dano Sagrado ao longo de 8 s aos inimigos que entrarem na \195\161rea. Os 4 primeiros inimigos que
  -- entrarem na \195\161rea receber\195\163o 56 a mais de dano ao longo de 8 s"
  n, school, dur, first, extra = match(t, "causando (" .. NUM .. ") de " .. DANO .. " (" .. W .. "-) ao longo de (" .. NUM
    .. ") sec aos inimigos que entrarem na " .. A .. "rea%.? +os (" .. NUM .. ") primeiros inimigos [^%.]-receber" .. AT .. "o (" .. NUM
    .. ") a mais de " .. DANO .. " ao longo de " .. NUM .. " sec")
  if n then
    return { dot = { total = num(n) + num(extra), duration = num(dur) }, school = schoolOfDamage(school), first = num(first) }
  end
  -- Tranquility: "Regenera 91 pontos de vida de todos os integrantes pr\195\179ximos do grupo em um raio de 20 m a cada 2 s por 10 s"
  local every
  n, every, dur = match(t, "regenera (" .. NUM .. ") pontos de vida de todos os integrantes [^%.]-a cada (" .. NUM .. ") sec por (" .. NUM .. ") sec")
  if n then return { hot = { total = num(n) * floor(num(dur) / num(every) + 0.5), duration = num(dur) } } end
  -- Dark Sacrifice: "Canibaliza 400 dos seus pr\195\179prios pontos de vida ao longo de 15 s para ganhar 431 de mana"
  n, dur, m = match(t, "canibaliza (" .. NUM .. ") dos seus pr" .. O .. "prios pontos de vida ao longo de (" .. NUM .. ") sec para ganhar ("
    .. NUM .. ") de mana")
  if n then return { healthCost = num(n), manaGain = num(m), healthCostDuration = num(dur) } end
  -- Seal of Light, per trigger: "chance de restaurar 39 pontos de vida"
  n = match(t, "chance de restaurar (" .. NUM .. ") pontos de vida")
  if n then return { heal = D(n) } end
  return nil
end

-- "1 ponto: 57 de dano ao longo de 12 s": the damage over time in one point's row, or "57 ao longo de 12 sec" where the
-- description names damage elsewhere (damageText).
local function finisherDot(seg, damageText)
  local total, dur = match(seg, "^ *(" .. NUM .. ") de " .. DANO .. " ao longo de (" .. NUM .. ") sec")
  if not total and damageText then total, dur = match(seg, "^ *(" .. NUM .. ") ao longo de (" .. NUM .. ") sec") end
  return total, dur
end

-- The chance per hit: its percent, true where the text names a chance without a figure, or nil.
local function procChance(t)
  -- "Cada acerto tem 20% de chance", "Cada acerto com a m\195\163o principal tem 20% de chance de conceder ao atacante 1 ataque extra"
  local p = match(t, "cada acerto [^%.]-tem (" .. NUM .. ") ?%% de chance")
  if p then return num(p) end
  -- (no "chance de conceder": Drain Soul's "t\195\170m chance de conceder a voc\195\170 um Estilha\195\167o de Alma" is no weapon proc)
  for _, chance in ipairs({ "chance de causar", "chance de envenenar", "chance de restaurar", "chance de curar",
    "tenha chance de", "ataques t" .. EC .. "m chance de conceder" }) do
    if find(t, chance, 1, true) then return true end
  end
  if find(t, "cada acerto [^%.]-tem chance") then return true end
  return nil
end

-- A text that reads as nothing: damage the pack has no wording for, an effect, or a utility spell.
local function unreadKind(t)
  for after in t:gmatch(NUM .. "([^0-9]*)") do
    local s = stripFillers(after, FILLERS_PT)
    if sub(s, 1, #DANO) == DANO then return "unread-damage" end
  end
  if hasAny(t, { DANO, "pontos de vida", "poder de ataque", "absorv" }) and not find(t, "recebido", 1, true) then
    return "unread-effect"
  end
  return "utility"
end

Parser.RegisterPack("pt", {
  rangeWord = "a",
  damageWord = DANO,
  weaponWord = WEAPON,
  pointsMarker = "pontos?",
  healWords = { " cura ", " curar ", " curando ", " curado ", " de cura", " restaura ", " restaurarem ", " regenera ", " recupera ",
    " recuperam " },
  -- ", depois mais 39 de dano de Natureza ao longo de 12 s" (Sunfire), ", mais um adicional de 41 de dano ..." (Shadowflame)
  clauseSeparators = { ", depois mais ", ", mais um adicional de ", ", e ", " e ", " ou ", " mas " },
  reduceVerbs = REDUCE_VERBS,
  enemyWords = { "alvo", "inimigo", "agressor" },
  selfWords = { " voc" .. EC, " seu ", " sua ", " seus ", "recebido" },
  increaseWord = "aument",
  byWord = "em ",
  sealEnergy = "liberar a energia do selo",
  judgementSpell = "libera a energia de um " .. FEITICO .. " de selo",
  words = PORTUGUESE_WORDS,
  units = { sec = 1, segundo = 1, min = 60, hora = 3600 },
  distanceWords = { m = true, metros = true, metro = true },
  hp5 = "em (" .. NUM .. ") a regenera" .. C .. AT .. "o de pontos de vida a cada (" .. NUM .. ") sec",
  tickTails = { "^ *a cada ", "^ *por segundo" },
  durationMarkers = { " sec", " min", "ao longo de ", "a cada " },
  drainWords = { "drena" },
  manaWord = "mana",
  healing = {
    targets = { "e do lan" .. C .. "ador" },
    channel = { "canaliz", "instantaneamente e a cada" },
    trigger = { "clicar", "na pr" .. O .. "xima vez", "chance" },
    stack = { "acumul", "expira" },
    pet = { "ajudante", "pet" },
    target = { " seu alvo", " o alvo", " um alvo aliado", " um aliado", " de um aliado" },
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
  weapon = weaponPT,
  attackPower = attackPowerIn,
  judgement = judgement,
  sealDuration = sealDuration,
  special = special,
  finisherDot = finisherDot,
  procChance = procChance,
  unreadKind = unreadKind,
})
