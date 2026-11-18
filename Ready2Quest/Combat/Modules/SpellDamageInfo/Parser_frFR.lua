-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: French language pack of the spell parser.
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
--
-- The wordings of WoW: Forever's French spell descriptions: "points de dégâts", "points de vie",
-- "toutes les 2 secondes", "en 8 s", the decimal comma, the no-break space before ":" and "%".
-- What a pack is, and how to add one, is in Parser.lua (LANGUAGE PACKS). Written from the French
-- /sdi dump all (1697 class abilities); the weapon and special readers cover the wordings that
-- dump holds. A wording the pack does not know stays unread: it never guesses.
-- Pure Lua 5.1, no game API.

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT and BIT.Module and BIT.Module("SpellDamageInfo") or BIT or {}
local Parser = ns.Parser

local U = Parser.util
local NUM, num, D, amountOf, hasAny, stripFillers = U.NUM, U.num, U.D, U.amountOf, U.hasAny, U.stripFillers
local find, sub, gsub, match = string.find, string.sub, string.gsub, string.match
local tonumber, floor = tonumber, math.floor

local A, AC, E, EA, EC = "\195\160", "\195\162", "\195\169", "\195\168", "\195\170" -- à â é è ê
local W = "[a-z\128-\255' %-]" -- the characters of a few words, accents included
local DEGATS = "d" .. E .. "g" .. AC .. "ts" -- dégâts
local SACRE = "sacr" .. E -- sacré

-- School words after "dégâts", longest first. "dégâts de Feu", "d'Ombre", "du Sacré", "des Arcanes".
local SCHOOLS = {
  { "de givrefeu", "frostfire" }, { "d'ombreflamme", "shadowflame" },
  { "de givre-sort", "spellfrost" }, { "de feu-sort", "spellfire" }, { "de feu-sorcier", "spellfire" },
  { "de givre-ombre", "shadowfrost" }, { "chim" .. E .. "riques", "chimeral" },
  { "de feu", "fire" }, { "de givre", "frost" }, { "de nature", "nature" }, { "d'ombre", "shadow" },
  { "du " .. SACRE, "holy" }, { "des arcanes", "arcane" }, { "d'arcane", "arcane" }, { "du chaos", "chaos" },
  { "physiques", "physical" }, { "physique", "physical" },
}

-- Words that may sit between an amount and its damage word.
local FILLERS_FR = {
  "points de ", "point de ", "points d'", "point d'", "points ", "point ",
  "suppl" .. E .. "mentaires de ", "suppl" .. E .. "mentaires ", "suppl" .. E .. "mentaire ",
  "additionnels ", "de ",
}

-- Words of this language, for telling a French client's English texts (Forever leaves some of
-- its spells in English, e.g. Mangle's bleed).
local FRENCH_WORDS = { " de ", " la ", " le ", " les ", " des ", " du ", " et ", " " .. A .. " ", " un ", " une ",
  " en ", " au ", " aux ", " vous", " cible", "d" .. E .. "g" .. AC .. "ts", "points" }

-- Capital letters of Latin-1 and Œ to lower case (UTF-8): É -> é, À -> à, Î -> î ...
local function lower(t)
  t = gsub(t, "\195[\128-\150\152-\158]", function(c) return "\195" .. string.char(c:byte(2) + 32) end)
  return (gsub(t, "\197\146", "\197\147"))
end

local function detect(t)
  return find(t, DEGATS, 1, true) or find(t, " points de ", 1, true)
end

-- Numbers as the English readers take them: "1 290" -> "1290", "1,2" -> "1.2".
local function englishNumbers(t)
  local prev
  repeat prev = t; t = gsub(t, "%f[0-9]([0-9][0-9]?[0-9]?) ([0-9][0-9][0-9])%f[^0-9]", "%1%2") until t == prev
  return (gsub(t, "([0-9]),([0-9])", "%1.%2"))
end

local function toEnglish(text)
  text = gsub(text, "\226\128\175", " ")
  return englishNumbers(gsub(text, "\194\160", " "))
end

-- "1 290" (thousands, after the no-break space went), "1,2", a typographic apostrophe, a bare "s" or
-- "m" as a unit ("toutes les 5 s", "à moins de 20 m"), a narrow no-break space.
local function normaliseNumbers(t)
  t = gsub(t, "\226\128\175", " ")
  t = gsub(t, "\226\128\153", "'")
  t = englishNumbers(t)
  t = gsub(t, "([0-9]) s%f[^a-z\128-\255]", "%1 sec")
  t = gsub(t, "([0-9]) h%f[^a-z\128-\255]", "%1 heure")
  return t
end

-- One spelling of the phrases that say a number is weapon damage, so one word covers them:
-- "dégâts de l'arme", "des dégâts normaux de votre arme", "les dégâts des deux armes de mêlée", and the
-- ranges: "de 3 à 13" -> "3 à 13", "entre 2 et 9" -> "2 à 9".
local WEAPON = DEGATS .. " d'arme"
local function rewrite(t)
  t = gsub(t, DEGATS .. " normaux de votre arme", WEAPON)
  t = gsub(t, DEGATS .. " normaux de l'arme", WEAPON)
  t = gsub(t, DEGATS .. " de l'arme de m" .. EC .. "l" .. E .. "e", WEAPON)
  t = gsub(t, DEGATS .. " de l'arme", WEAPON)
  t = gsub(t, DEGATS .. " de votre arme", WEAPON)
  t = gsub(t, DEGATS .. " des deux armes de m" .. EC .. "l" .. E .. "e", WEAPON)
  t = gsub(t, DEGATS .. " des armes", WEAPON)
  -- Health Funnel: "Rend 12 points de vie toutes les secondes au familier du personnage lanceur" gives the pet health
  -- the caster pays, which is no heal: "alloue" is the word classifyAfter looks for
  t = gsub(t, "rend (" .. NUM .. ") points de vie ([^%.]-)au familier", "alloue %1 points de vie %2au familier")
  -- Resurrection: "Rappelle à la vie un personnage mort et lui rend 70 points de vie": the health it comes back with, no heal
  t = gsub(t, "(rappelle " .. A .. " la vie [^%.]-)rend ", "%1donne ")
  -- Living Bomb: "Au bout de 12 sec ou quand le sort est dissipé, la cible explose en infligeant 28 ...": the 12 sec
  -- is the timer before the explosion, not a duration of the 28
  t = gsub(t, "au bout de " .. NUM .. " sec ou quand [^,%.]+, ", "")
  -- "l'étourdit pendant 2 sec en lui infligeant 114 points de dégâts en 18 sec": the stun is no duration of the damage
  t = gsub(t, "tourdit pendant " .. NUM .. " sec", "tourdit")
  -- Shadowflame: "inflige 22 points de dégâts d'ombreflamme, puis 41 supplémentaires en 15 sec": the same school
  t = gsub(t, ", puis (" .. NUM .. ") suppl" .. E .. "mentaires en ", ", puis %1 points de " .. DEGATS .. " suppl" .. E .. "mentaires en ")
  t = gsub(t, "entre (" .. NUM .. ") et (" .. NUM .. ") ", "%1 " .. A .. " %2 ")
  t = gsub(t, "([ :,]) *de (" .. NUM .. ") " .. A .. " (" .. NUM .. ")", "%1 %2 " .. A .. " %3")
  -- Lacerate: the stacking tail ("plus 10% weapon damage per existing application") is no part of the first application's damage:
  -- the base is what the text names, and the weapon word would veto the whole reading
  t = gsub(t, ", plus " .. NUM .. " ?%% des " .. DEGATS .. " d'arme par application[^%.]*", "")
  t = gsub(t, " plus " .. NUM .. " ?%% des " .. DEGATS .. " d'arme par application[^%.]*", "")
  return (gsub(t, " +", " "))
end

local function takeLasts(t, take)
  t = gsub(t, "dure (" .. NUM .. ") ([a-z]+)", take)
  t = gsub(t, "dur" .. E .. "e de (" .. NUM .. ") ([a-z]+)", take)
  -- a totem's time, said before its pulse: "Invoque un Totem de Magma aux pieds du lanceur de sorts pendant 20 sec, ...
  -- inflige 20 points de dégâts de Feu toutes les 2 secondes"
  t = gsub(t, "(invoque [^%.]-pieds [^%.]-pendant) (" .. NUM .. ") ([a-z]+)", function(head, n, unit)
    take(n, unit)
    return head .. " "
  end)
  return t
end

local function takeInterval(c, onNumber, onOne)
  c = gsub(c, "toutes les (" .. NUM .. ") ([a-z]+)", onNumber)
  c = gsub(c, "toutes les secondes", onOne)
  c = gsub(c, "toutes les sec%.?", onOne) -- Forever's "toutes les sec. pendant jusqu'à annulation": a tick with no end
  c = gsub(c, "chaque seconde", onOne)
  c = gsub(c, "par seconde", onOne)
  return c
end

-- The school named by the words after "dégâts": its code, false where a word follows that is no
-- school ("dégâts de l'arme" went through rewrite, "dégâts des sorts", "d'un montant"), or "physical"
-- where nothing school-like follows ("15 points de dégâts en 12 sec").
local function schoolAfter(s)
  for _, school in ipairs(SCHOOLS) do
    local words = school[1]
    if sub(s, 1, #words) == words and not match(sub(s, #words + 1, #words + 1), "[a-z\128-\255]") then
      return school[2]
    end
  end
  if match(s, "^d[eu]s? ") or match(s, "^d'") or match(s, "^de$") or match(s, "^du$") or match(s, "^subis") then return false end
  return "physical"
end

-- What the words right after an amount say it is: damage of a school, a health drain, health given,
-- or nothing we understand.
local function classifyAfter(after, sentence)
  local s = stripFillers(after, FILLERS_FR)
  if sub(s, 1, #DEGATS) == DEGATS then
    local school = schoolAfter((gsub(sub(s, #DEGATS + 1), "^ +", "")))
    if school then return "damage", school end
    return nil
  end
  if sub(s, 1, 3) == "vie" then
    if find(sentence, "transf" .. EA .. "re", 1, true) or find(sentence, "draine", 1, true) then return "drain", nil end
    -- a bleed: "Elle saigne et perd 15 points de vie en 9 sec"
    if find(sentence, "saigne", 1, true) and find(sentence, "perd ", 1, true) then return "damage", "physical" end
    -- Health Funnel, "Rend X points de vie ... au familier": rewrite made it "alloue"
    if find(sentence, "alloue ", 1, true) then
      if find(sentence, "familier", 1, true) or find(sentence, "mascotte", 1, true) then return "petheal", nil end
      return "giveheal", nil
    end
  end
  return nil
end

local function healAmountOK(before, after)
  local s = stripFillers(after, FILLERS_FR)
  if sub(s, 1, 3) == "vie" and not match(sub(s, 4, 4), "[a-z\128-\255]") then return true end
  -- Regrowth: "Soigne une cible amie pour 80 à 94 puis pour 91 points supplémentaires pendant 21 sec": the amount
  -- follows "pour" and nothing but a duration comes after it
  if find(before, " pour $") then
    s = stripFillers(after, { "points ", "point ", "suppl" .. E .. "mentaires ", "suppl" .. E .. "mentaire " })
    return s == "" or find(s, "^pendant") ~= nil or find(s, "^#") ~= nil or find(s, "^[%. ]*$") ~= nil
  end
  return false
end

-- Clauses whose amounts are not the spell's damage or healing: absorbs, amounts per unit of
-- something else, and "augmente de 11 les points de dégâts infligés" (a bonus, not a hit).
local function ignoredClause(c)
  -- Hellfire: "Il subit 82 points de dégâts de Feu et inflige 82 ... à tous les ennemis proches": the caster's own
  -- Blessing of Sacrifice: "transfère 45 points de dégâts subis par la cible au lanceur de sorts"
  return find(c, "^ *il subit ") or find(c, "transf" .. EA .. "re " .. NUM .. " points de " .. DEGATS) or find(c, "absorb", 1, true) or find(c, "pour chaque", 1, true) or find(c, " par point ", 1, true)
    or find(c, " par application", 1, true) or find(c, " par charge", 1, true)
    or find(c, "augment[a-z" .. E .. "]* de " .. NUM .. " " .. W .. "-" .. DEGATS)
    or find(c, "r" .. E .. "duit[a-z]* de " .. NUM .. " " .. W .. "-" .. DEGATS)
end

-- Per-combo-point tables ("1 point : 20 points de dégâts").
local function perPointTable(t)
  return find(" " .. t, "[^0-9]1 points? *:")
end

-- A consumable's amounts: health lo..hi, mana mlo..mhi, and a stated duration.
local function itemHeal(t)
  local lo, hi, mlo, mhi
  local dur, minutes = nil, false
  mlo, mhi = match(t, "rend (" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de mana")
  if not mlo then mlo = match(t, "rend (" .. NUM .. ") points de mana") end
  if not mlo then mlo, mhi = match(t, "restitue (" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de mana") end
  if not mlo then mlo = match(t, "restitue (" .. NUM .. ") points de mana") end
  do
    local a, b, d
    for _, unit in ipairs({ "sec", "min" }) do
      for _, verb in ipairs({ "rend", "restitue", "soigne" }) do
        if not a then a, b, d = match(t, verb .. " (" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de vie en (" .. NUM .. ") " .. unit) end
        if not a then a, d = match(t, verb .. " (" .. NUM .. ") points de vie en (" .. NUM .. ") " .. unit) end
      end
      if a then if unit == "min" then minutes = true end break end
    end
    if a then lo, hi, dur = a, (b or a), d end
  end
  if not dur then
    for _, verb in ipairs({ "rend", "restitue", "soigne" }) do
      if not lo then lo, hi = match(t, verb .. " (" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de vie") end
      if not lo then lo = match(t, verb .. " (" .. NUM .. ") points de vie") end
    end
  end
  return lo, hi, mlo, mhi, dur, minutes
end

-- A drink: mana total, seconds, and the health total where one wording names both.
-- "Utiliser : Rend 151 points de mana en 18 sec.", "Rend 2148 points de vie et 4410 points de mana en 30 sec."
local function itemDrink(t)
  for _, verb in ipairs({ "rend", "restitue" }) do
    local h, m, d = match(t, verb .. " (" .. NUM .. ") points de vie et (" .. NUM .. ") points de mana en (" .. NUM .. ") sec")
    if m then return m, d, h end
    m, d = match(t, verb .. " (" .. NUM .. ") points de mana en (" .. NUM .. ") sec")
    if m then return m, d end
  end
end

local REDUCE_VERBS = { "r" .. E .. "duit", "r" .. E .. "duis", "r" .. E .. "duction", "diminu", "baisse" }

-- A debuff's own words: the attack power and damage a clause names.
local function reductionStat(c)
  return find(c, "puissance d'attaque", 1, true), find(c, DEGATS, 1, true)
end

-- The school of "dégâts du sacré supplémentaires": the words from "dégâts" on.
local function schoolOfDamage(s)
  local school = schoolAfter((gsub(s, "^ +", "")))
  return school or nil
end

-- "Vous adoptez votre forme de félin, qui augmente votre puissance d'attaque de 14 ainsi que votre
-- Agilité", "augmentez de 10 la puissance d'attaque en mêlée des membres du groupe à moins de 20 m",
-- "est augmentée de 50": the amount sits before or after the words "puissance d'attaque".
local function attackPowerIn(sentence)
  local s, e = find(sentence, "puissance d'attaque", 1, true)
  if not s then s, e = find(sentence, "puissance de ses attaques", 1, true) end
  -- Hunter's Mark: "augmentant la puissance des attaques à distance de tous les attaquants de la cible de 26"
  if not s then s, e = find(sentence, "puissance des attaques", 1, true) end
  if not s then return nil end
  if hasAny(sentence, REDUCE_VERBS) or find(sentence, "chance", 1, true) or find(sentence, "moins de d" .. E .. "g" .. AC .. "ts", 1, true)
    or find(sentence, "affaibl", 1, true) then
    return nil
  end
  if not find(sentence, "augment", 1, true) and not find(sentence, "accord", 1, true) then return nil end
  local a = match(sentence, "augment[a-z" .. E .. "]* de (" .. NUM .. ") la puissance")
    or match(sentence, "augment[a-z" .. E .. "]* de (" .. NUM .. ") votre puissance")
  if not a then
    -- after the noun: the first "de N" that is no distance
    local from = e
    while true do
      local ds, de, n = find(sentence, " de (" .. NUM .. ")", from + 1)
      if not ds then break end
      local word = match(sub(sentence, de + 1), "^ ?([a-z\128-\255]+)")
      if not (word == "m" or word == "metres" or word == "m" .. EC .. "tres" or word == "sec" or word == "min") then
        a = n
        break
      end
      from = de
    end
  end
  if not a then return nil end
  return { kind = "ap", amount = num(a), ranged = find(sentence, " " .. A .. " distance", 1, true) ~= nil,
    plusAgility = find(sentence, "ainsi que votre agilit" .. E, 1, true) ~= nil }
end

local function weaponFR(t)
  local p, a, b, school
  -- Windfury Weapon and Totem: "a 20 % de chances de vous octroyer 2 attaques supplémentaires avec un
  -- bonus de 46 à la puissance d'attaque en mêlée"
  a, b = match(t, "(" .. NUM .. ") attaques? suppl" .. E .. "mentaires? avec un bonus de (" .. NUM .. ") " .. A .. " la puissance d'attaque")
  if a then return { kind = "extra", attacks = num(a), amount = num(b) } end
  -- Windfury Totem: "1 attaque supplémentaire avec une puissance d'attaque en mêlée accrue de 95"
  a, b = match(t, "(" .. NUM .. ") attaques? suppl" .. E .. "mentaires? avec une puissance d'attaque en m" .. EC .. "l" .. E .. "e accrue de ("
    .. NUM .. ")")
  if a then return { kind = "extra", attacks = num(a), amount = num(b) } end
  -- Mutilate: "inflige 90 % des dégâts des armes plus 36 points de dégâts avec chacune d'elle"
  p, a = match(t, "(" .. NUM .. ") ?%% des " .. DEGATS .. " d'arme plus (" .. NUM .. ") points de " .. DEGATS .. " avec chacune")
  if p then return { kind = "both", pct = num(p), bonus = num(a) } end
  -- Seal of Command: "une chance d'infliger des dégâts du sacré supplémentaires d'un montant égal à 70 % des dégâts
  -- normaux de l'arme"
  school, p = match(t, "chance d'infliger [^%.]-" .. DEGATS .. " (" .. W .. "-) suppl" .. E .. "mentaires[^%.]-(" .. NUM .. ") ?%% des " .. WEAPON)
  if p then return { kind = "weapon", pct = num(p), bonus = 0, school = schoolOfDamage(school) } end
  -- Seal of Fury: "Chaque attaque de mêlée a une chance d'infliger 14 points de dégâts du sacré supplémentaires"
  a, school = match(t, "chaque attaque de m" .. EC .. "l" .. E .. "e a une chance d'infliger (" .. NUM .. ") points de " .. DEGATS .. " (" .. W
    .. "-) suppl" .. E .. "mentaires")
  if a then return { kind = "perhit", min = num(a), max = num(a), school = schoolOfDamage(school) } end
  if find(t, "chance", 1, true) or find(t, "avec chacune", 1, true) then return nil end
  -- Flametongue, Seal of Righteousness: "Chaque coup inflige de 3 à 13 points de dégâts de feu supplémentaires",
  -- "Chaque attaque en mêlée inflige entre 2 et 9 points de dégâts du sacré supplémentaires"
  local lo, hi
  lo, hi, school = match(t, "chaque " .. W .. "-inflige (" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de " .. DEGATS
    .. " (" .. W .. "-) suppl" .. E .. "mentaires")
  if lo then
    return { kind = "perhit", min = num(lo), max = num(hi), school = schoolOfDamage(school),
      bySpeed = find(t, "plus lentes infligent plus de", 1, true) and true or nil }
  end
  -- Claw, Rake, Shred, Ravage: "inflige 140 % des dégâts normaux plus 37", "200 % de dégâts plus 44"
  p, a = match(t, "(" .. NUM .. ") ?%% des " .. WEAPON .. " plus (" .. NUM .. ")")
  if not p then p, a = match(t, "(" .. NUM .. ") ?%% des " .. DEGATS .. " normaux plus (" .. NUM .. ")") end
  if not p then p, a = match(t, "(" .. NUM .. ") ?%% de " .. DEGATS .. " plus (" .. NUM .. ")") end
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  -- Holy Strike: "29 % des dégâts de l'arme et 4 à 6 points de dégâts du sacré supplémentaires"
  p, a, b = match(t, "(" .. NUM .. ") ?%% des " .. WEAPON .. " et (" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de " .. DEGATS)
  if p then return { kind = "weapon", pct = num(p), bonus = num(a), bonusMax = num(b) } end
  -- Primal Bite: "100 % des dégâts normaux et 42 points de dégâts supplémentaires"
  p, a = match(t, "(" .. NUM .. ") ?%% des " .. DEGATS .. " normaux et (" .. NUM .. ") points de " .. DEGATS .. " suppl")
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  -- Bloodthirst, Shuriken Toss: "égal à 45 % de votre puissance d'attaque plus 30"
  p, a = match(t, "(" .. NUM .. ") ?%% de votre puissance d'attaque plus (" .. NUM .. ")")
  if not p then p = match(t, "(" .. NUM .. ") ?%% de votre puissance d'attaque") end
  if p then return { kind = "appct", pct = num(p), bonus = num(a) or 0 } end
  -- "inflige 250 % des dégâts de l'arme plus 70", "infligeant 100 % des dégâts de l'arme", "inflige également 150 % des
  -- dégâts de l'arme": the number right after the verb, so a stacking "plus 10 % des dégâts de l'arme par ..." is not it
  p = match(t, "inflig[a-z]* " .. W .. "* ?(" .. NUM .. ") ?%% des " .. WEAPON)
  if p then return { kind = "weapon", pct = num(p), bonus = 0 } end
  -- Hammer of the Righteous: "dégâts du sacré équivalant à 3 fois les dégâts par seconde de votre arme en main droite"
  a = match(t, E .. "quivalant " .. A .. " (" .. NUM .. ") fois les " .. DEGATS .. " par seconde de votre arme")
  if a then return { kind = "dps", times = num(a), school = find(t, "du sacr" .. E, 1, true) and "holy" or "physical" } end
  -- Sniper Shot: "inflige les dégâts de l'arme à distance plus 320": the ranged weapon's hit plus the amount
  a = match(t, "inflig[a-z]* les " .. WEAPON .. " " .. A .. " distance plus (" .. NUM .. ")")
  if a then return { kind = "weapon", pct = 100, bonus = num(a), ranged = true } end
  -- "inflige les dégâts de l'arme plus 32", "inflige 3 points de dégâts en plus des dégâts normaux de votre arme"
  a = match(t, "inflig[a-z]* les " .. WEAPON .. " plus (" .. NUM .. ")")
    or match(t, "inflig[a-z]* les points de " .. WEAPON .. " plus (" .. NUM .. ")")
    or match(t, "inflig[a-z]* (" .. NUM .. ") points de " .. DEGATS .. " en plus des " .. WEAPON)
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  -- Whirlwind: "infligez les dégâts des deux armes de mêlée à chacun d'eux"
  if find(t, "inflig[a-z]* les " .. WEAPON .. " " .. A .. " chacun") then return { kind = "weapon", pct = 100, bonus = 0 } end
  -- Heroic Strike, Maul, Aimed Shot: the next swing, or a shot, gets more
  a = match(t, "augmente de (" .. NUM .. ") les points de " .. DEGATS .. " inflig" .. E .. "s en m" .. EC .. "l" .. E .. "e")
    or match(t, "augmente de (" .. NUM .. ") les " .. DEGATS .. " inflig" .. E .. "s en m" .. EC .. "l" .. E .. "e")
    or match(t, "augmente de (" .. NUM .. ") points de " .. DEGATS .. " la prochaine attaque")
  if a then return { kind = "next", bonus = num(a) } end
  a = match(t, "augmente les points de " .. DEGATS .. " inflig" .. E .. "s par votre attaque " .. A .. " distance de (" .. NUM .. ")")
    or match(t, "augmente les " .. DEGATS .. " inflig" .. E .. "s par votre attaque " .. A .. " distance de (" .. NUM .. ")")
  if a then return { kind = "next", bonus = num(a), ranged = true } end
  -- Seal of the Crusader: "Augmente la puissance d'attaque en mêlée de 51. La vitesse d'attaque est augmentée de 40%"
  a, p = match(t, "augmente la puissance d'attaque en m" .. EC .. "l" .. E .. "e de (" .. NUM .. ")%. +la vitesse d'attaque est augment" .. E
    .. "e de (" .. NUM .. ") ?%%")
  if a then return { kind = "ap", amount = num(a), faster = num(p) } end
  -- Strength of Earth, Grace of Air: "augmente de 53 la Force de tous les membres du groupe"
  a = match(t, "augmente de (" .. NUM .. ") la force ")
  if a then return { kind = "stat", stat = "str", amount = num(a) } end
  a = match(t, "augmente de (" .. NUM .. ") l'agilit" .. E)
  if a then return { kind = "stat", stat = "agi", amount = num(a) } end
  return nil
end

-- "Libérez l'énergie de ce Sceau pour juger un ennemi ... lui infliger instantanément 73 à 80 points de dégâts du Sacré"
local function judgement(part)
  local lo, hi, school = match(part, "(" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de " .. DEGATS .. " (" .. W .. "*)")
  if not lo then return nil end
  return lo, hi, schoolAfter((gsub(school, "^ +", "")))
end

local function sealDuration(t)
  return match(t, "pendant (" .. NUM .. ") sec") or match(t, "dure (" .. NUM .. ") sec")
end

local function special(t)
  local n, m, dur, lo, hi, school, extra, first
  -- shields: "absorbe 44 points de dégâts", with the heal of Plan d'urgence ("récupère 125 points de vie en 15 sec")
  n = match(t, "absorb[a-z]* (" .. NUM .. ") points de " .. DEGATS) or match(t, "absorb[a-z]* (" .. NUM .. ") points")
  if n then
    local r = { absorb = num(n) }
    local total, seconds = match(t, "r" .. E .. "cup" .. EA .. "re (" .. NUM .. ") points de vie en (" .. NUM .. ") sec")
    if total then r.hot = { total = num(total), duration = num(seconds) } end
    return r
  end
  -- Lay on Hands: "d'un nombre de points de vie égal aux points de vie maximum du personnage paladin"
  if find(t, "points de vie " .. E .. "gal aux points de vie maximum du personnage paladin", 1, true)
    or find(t, "points de vie " .. E .. "gal aux points de vie maximum du paladin", 1, true) then
    return { healMaxHealth = true }
  end
  -- Dark Sacrifice: "Vous d\195\169vorez 400 points de vie pendant 15 sec afin de r\195\169cup\195\169rer 427 points de mana."
  local dur
  n, dur, m = match(t, "vous d" .. E .. "vorez (" .. NUM .. ") points de vie pendant (" .. NUM .. ") sec afin de r" .. E .. "cup" .. E
    .. "rer (" .. NUM .. ") points de mana")
  if n then return { healthCost = num(n), manaGain = num(m), healthCostDuration = num(dur) } end
  -- Life Tap: "Convertit 48 points de vie en 48 points de mana."
  n, m = match(t, "convertit (" .. NUM .. ") points de vie en (" .. NUM .. ") points de mana")
  if n then return { healthCost = num(n), manaGain = num(m) } end
  -- Holy Shock: "inflige 248 à 268 points de dégâts du Sacré à un ennemi, ou bien rend à un allié 221 à 239 points de vie"
  local hlo, hhi
  lo, hi, school, hlo, hhi = match(t, "inflige (" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de " .. DEGATS .. " (" .. W .. "-) " .. A
    .. " un ennemi, ou bien rend " .. A .. " un alli" .. E .. " (" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de vie")
  if lo then return { direct = D(lo, hi), heal = D(hlo, hhi), school = schoolOfDamage(school) } end
  -- Forever's later Holy Shock: "inflige 129 à 139 points de dégâts du sacré à un adversaire, ou rend 110 à 118 points de vie
  -- à un personnage allié"
  lo, hi, school, hlo, hhi = match(t, "inflige (" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de " .. DEGATS .. " (" .. W .. "-) " .. A
    .. " un " .. W .. "-, ou rend (" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de vie")
  if lo then return { direct = D(lo, hi), heal = D(hlo, hhi), school = schoolOfDamage(school) } end
  -- Penance: "inflige 42 points de dégâts du sacré à un personnage adverse ou rend 126 points de vie à un personnage allié
  -- instantanément et toutes les 1 s pendant 2 sec": the first hit and the ticks, as the English pack counts them
  local dmg, h, iv
  dmg, school, h, iv, dur = match(t, "inflige (" .. NUM .. ") points de " .. DEGATS .. " (" .. W .. "-) " .. A .. " un " .. W .. "- ou rend ("
    .. NUM .. ") points de vie " .. A .. " un " .. W .. "- instantan" .. E .. "ment et toutes les (" .. NUM .. ") sec pendant (" .. NUM .. ") sec")
  if dmg then
    local hits = 1 + floor(num(dur) / num(iv) + 0.5)
    return { direct = D(num(dmg) * hits), heal = D(num(h) * hits), school = schoolOfDamage(school), hits = hits }
  end
  -- Death Coil: "lui inflige 272 points de dégâts d'Ombre. 100% des points de dégâts infligés sont transférés aux points de vie"
  n, school = match(t, "inflige (" .. NUM .. ") points de " .. DEGATS .. " (" .. W .. "-)%. +100 ?%% des points de " .. DEGATS
    .. " inflig" .. E .. "s sont transf" .. E .. "r" .. E .. "s aux points de vie")
  if n then return { direct = D(n), heal = D(n), school = schoolOfDamage(school), transfer = true } end
  -- Execute: "Inflige 125 points de dégâts et convertit chaque point de rage en 3 points de dégâts supplémentaires"
  n, m = match(t, "inflige (" .. NUM .. ") points de " .. DEGATS .. " et convertit chaque point de rage en (" .. NUM .. ") points de " .. DEGATS)
  if n then return { direct = D(n), school = "physical", perRage = num(m) } end
  -- Searing Totem: "attaque tous les ennemis qui se trouvent dans un rayon de 20 mètres et inflige 9 à 11 points de dégâts de Feu"
  lo, hi, school = match(t, "attaque tous les ennemis [^%.]-inflige (" .. NUM .. ") " .. A .. " (" .. NUM .. ") points de " .. DEGATS .. " (" .. W .. "*)")
  if lo then return { direct = D(lo, hi), school = schoolOfDamage(school), perAttack = true } end
  -- Healing Stream Totem: "Il soigne tous les membres du groupe de 5 points de vie toutes les 2 secondes"
  n, m = match(t, "soigne tous les membres du groupe de (" .. NUM .. ") points de vie toutes les (" .. NUM .. ") sec")
  if n then return { heal = D(n), every = num(m) } end
  -- Retribution Aura: "Inflige 5 points de dégâts du sacré à toute créature frappant un membre du groupe"
  n, school = match(t, "inflige (" .. NUM .. ") points de " .. DEGATS .. " (" .. W .. "-) " .. A .. " toute cr" .. E .. "ature frappant un membre du groupe")
  if n then return { direct = D(n), school = schoolOfDamage(school), perStrike = true } end
  -- Holy Shield: "inflige 75 points de dégâts du sacré pour chaque attaque bloquée"
  n, school = match(t, "inflige (" .. NUM .. ") points de " .. DEGATS .. " (" .. W .. "-) pour chaque attaque bloqu" .. E .. "e")
  if n then return { direct = D(n), school = schoolOfDamage(school), perBlock = true } end
  -- Consecration: "inflige 24 points de dégâts du sacré en 8 sec aux adversaires qui entrent dans la zone. Les 4 premiers
  -- adversaires à y pénétrer subissent 56 points de dégâts supplémentaires en 8 sec"
  n, school, dur, first, extra = match(t, "inflige (" .. NUM .. ") points de " .. DEGATS .. " (" .. W .. "-) en (" .. NUM
    .. ") sec aux adversaires qui entrent dans la zone%.? +les (" .. NUM .. ") premiers adversaires [^%.]-subissent (" .. NUM
    .. ") points de " .. DEGATS .. " suppl" .. E .. "mentaires en " .. NUM .. " sec")
  if n then
    return { dot = { total = num(n) + num(extra), duration = num(dur) }, school = schoolOfDamage(school), first = num(first) }
  end
  -- Tranquility: "Régénère de 87 les points de vie des membres du groupe à moins de 20 m toutes les 2 s pendant 10 sec"
  local every
  n, every, dur = match(t, "r" .. E .. "g" .. E .. "n" .. EA .. "re de (" .. NUM .. ") les points de vie des membres du groupe [^%.]-toutes les ("
    .. NUM .. ") sec pendant (" .. NUM .. ") sec")
  if n then return { hot = { total = num(n) * floor(num(dur) / num(every) + 0.5), duration = num(dur) } } end
  -- Seal of Light, per trigger: "une chance de rendre 39 points de vie au paladin"
  n = match(t, "chance de rendre (" .. NUM .. ") points de vie au paladin")
  if n then return { heal = D(n) } end
  -- Holy Nova's ancestors, Well of Light: "pour recevoir 800 points de vie en 10 sec"
  n, dur = match(t, "pour recevoir (" .. NUM .. ") points de vie en (" .. NUM .. ") sec")
  if n then return { hot = { total = num(n), duration = num(dur) } } end
  return nil
end

-- "1 point : 25 points de dégâts en 8 s": the damage over time in one point's row, or "25 en 8 sec" where the
-- description names damage elsewhere (damageText).
local function finisherDot(seg, damageText)
  local total, dur = match(seg, "^ *(" .. NUM .. ") points? de " .. DEGATS .. " en (" .. NUM .. ") sec")
  if not total and damageText then total, dur = match(seg, "^ *(" .. NUM .. ") en (" .. NUM .. ") sec") end
  return total, dur
end

-- The chance per hit: its percent, true where the text names a chance without a figure, or nil.
local function procChance(t)
  local p = match(t, "chaque " .. W .. "- a (" .. NUM .. ") ?%% de chances?")
  if p then return num(p) end
  if find(t, "chaque " .. W .. "- a une chance") or find(t, "une chance d'infliger", 1, true)
    or find(t, "ont une chance", 1, true) then
    return true
  end
  return nil
end

-- A text that reads as nothing: damage the pack has no wording for, an effect, or a utility spell.
local function unreadKind(t)
  for after in t:gmatch(NUM .. "([^0-9]*)") do
    local s = stripFillers(after, FILLERS_FR)
    if sub(s, 1, #DEGATS) == DEGATS then return "unread-damage" end
  end
  if hasAny(t, { DEGATS, "points de vie", "puissance d'attaque", "absorb" }) and not find(t, "subi", 1, true) then
    return "unread-effect"
  end
  return "utility"
end

Parser.RegisterPack("fr", {
  rangeWord = A,
  damageWord = DEGATS,
  weaponWord = WEAPON,
  pointsMarker = "points?",
  healWords = { "^ *rend ", " rend ", " rendent ", " rendre ", " soigne", "^ *soigne", " restitue", " gu" .. E .. "rit",
    " r" .. E .. "cup" .. EA .. "re ", " rendus", " rendues", " re\195\167oit instantan" .. E .. "ment" },
  clauseSeparators = { ", ou bien ", " ou bien ", ", puis ", " puis ", ", r" .. E .. "duit ", " et ", " ainsi que " },
  reduceVerbs = REDUCE_VERBS,
  enemyWords = { "cible", "ennemi", "adversaire" },
  selfWords = { " vous ", " votre ", " vos ", "subi" },
  -- "Ces soins sont réduits de 50 % sur vous-même, et également réduits de 80 % lorsque les dégâts ...": the healing
  skipReduction = "^ *ces soins ",
  increaseWord = "augment",
  byWord = "de ",
  sealEnergy = "lib" .. E .. "rez l'" .. E .. "nergie de ce sceau",
  judgementSpell = "lib" .. EA .. "re l'" .. E .. "nergie d'un sort de sceau",
  words = FRENCH_WORDS,
  units = { sec = 1, min = 60, heure = 3600 },
  distanceWords = { m = true, metres = true, ["m" .. EC .. "tres"] = true, ["m" .. EC .. "tre"] = true },
  hp5 = "r" .. E .. "cup" .. E .. "ration des points de vie de (" .. NUM .. ") points de vie toutes les (" .. NUM .. ") sec",
  tickTails = { "^ *toutes les ", "^ *par seconde" },
  durationMarkers = { " sec", " min", "pendant ", "toutes les " },
  drainWords = { "draine", "absorbe" },
  manaWord = "mana",
  healing = {
    targets = { "et au lanceur", "et le lanceur" },
    channel = { "canalis", "instantan" .. E .. "ment et toutes les" },
    trigger = { "cliquer", "la prochaine fois", "chance" },
    stack = { "cumul", "expire" },
    pet = { "familier", "mascotte" },
    target = { " " .. A .. " la cible", " " .. A .. " une cible alli" .. E .. "e", " " .. A .. " une cible amie", "soigne la cible",
      "la cible de ", " " .. A .. " un alli" .. E },
  },
  lower = lower,
  detect = detect,
  toEnglish = toEnglish,
  normaliseNumbers = normaliseNumbers,
  rewrite = rewrite,
  prepareSentences = function(t) return (gsub(t, "([0-9]) sec%. pendant", "%1 sec pendant")) end,
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
  weapon = weaponFR,
  attackPower = attackPowerIn,
  judgement = judgement,
  sealDuration = sealDuration,
  special = special,
  finisherDot = finisherDot,
  procChance = procChance,
  unreadKind = unreadKind,
})
