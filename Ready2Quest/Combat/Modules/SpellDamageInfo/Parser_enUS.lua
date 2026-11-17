-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: English language pack of the spell parser.
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
--
-- The wordings of Classic's and Forever's English spell descriptions. English is the base language
-- of the parser: an unknown language code falls back to this pack. What a pack is, and how to add
-- one, is in Parser.lua (LANGUAGE PACKS).
-- Pure Lua 5.1, no game API.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT and BIT.Module and BIT.Module("SpellDamageInfo") or BIT or {}
local Parser = ns.Parser

local U = Parser.util
local NUM, num, D, amountOf, hasAny, stripFillers = U.NUM, U.num, U.D, U.amountOf, U.hasAny, U.stripFillers
local find, sub, gsub, match = string.find, string.sub, string.gsub, string.match
local floor = math.floor

local SCHOOL_EN = {
  shadow = "shadow", fire = "fire", nature = "nature", frost = "frost", arcane = "arcane",
  holy = "holy", frostfire = "frostfire", physical = "physical", bleed = "physical", volcanic = "volcanic",
  spellfire = "spellfire", spellfrost = "spellfrost", shadowfrost = "shadowfrost", shadowflame = "shadowflame",
  chaos = "chaos", chimeral = "chimeral", chimeric = "chimeral",
}

-- Words that may sit between an amount and its damage word.
local FILLERS_EN = { "additional ", "extra " }

local ENGLISH_WORDS = { " the ", " a ", " you", " for ", " and ", " of ", " to ", " with ", " from ", " into ", " is ",
  " by ", "damage", " sec", "health", "restores", "heals" }

local function normaliseNumbers(t)
  local prev
  repeat prev = t; t = gsub(t, "([0-9]),([0-9][0-9][0-9])", "%1%2") until t == prev
  return t
end

-- Living Bomb: "After 12 sec or when the spell is dispelled, the target explodes dealing 26 ...":
-- the 12 sec is the timer before the explosion, not a duration of the 26
local function rewrite(t)
  t = gsub(t, "after " .. NUM .. " sec or when [^,%.]+, ", "")
  -- Lacerate: the stacking tail ("plus 10% weapon damage per existing application") is no part of the first application's damage:
  -- the base is what the text names, and the weapon word would veto the whole reading
  return (gsub(t, " plus " .. NUM .. "%% weapon damage per existing application[^%.]*", ""))
end

-- Penance: "Healing for 126 every 1 sec. for 2 sec."
local function prepareSentences(t)
  return (gsub(t, "(every " .. NUM .. " sec)%. (for " .. NUM .. " sec)", "%1 %2"))
end

local function takeLasts(t, take)
  t = gsub(t, "lasts for (" .. NUM .. ") ([a-z]+)", take)
  t = gsub(t, "lasts (" .. NUM .. ") ([a-z]+)", take)
  return t
end

local function takeInterval(c, onNumber, onOne)
  c = gsub(c, "every (" .. NUM .. ") ([a-z]+)", onNumber)
  c = gsub(c, "every second", onOne)
  c = gsub(c, "each second", onOne)
  c = gsub(c, "per second", onOne)
  return c
end

-- What the words right after an amount say it is: damage of a school, a health drain,
-- health given, or nothing we understand.
local function classifyAfter(after, sentence)
  local s = stripFillers(after, FILLERS_EN)
  if sub(s, 1, 6) == "damage" then return "damage", "physical" end
  local word = match(s, "^([a-z]+) damage")
  if word and SCHOOL_EN[word] then return "damage", SCHOOL_EN[word] end
  if sub(s, 1, 6) == "health" then
    if find(sentence, "transfers ") then return "drain", nil end
    if find(sentence, "gives ") then
      -- Health Funnel, "Gives X health to the caster's pet": the caster's own
      if (find(sentence, " pet", 1, true) or find(sentence, "pet ", 1, true) or find(sentence, "pet'", 1, true) or find(sentence, "pets", 1, true)) then return "petheal", nil end
      return "giveheal", nil
    end
  end
  return nil
end

local function healAmountOK(before, after)
  -- A count, not an amount: "Heals 3 total targets."
  local word = match(after, "^ *([a-z]+)")
  if word == "total" or word == "target" or word == "targets" or word == "times" or word == "charges" then
    return false
  end
  if find(before, " for $") or find(before, " of $") or find(before, " another $") or find(before, "heals $") then
    return true
  end
  local s = stripFillers(after, FILLERS_EN)
  return sub(s, 1, 6) == "damage" or sub(s, 1, 6) == "health"
end

-- Clauses whose amounts are not the spell's damage or healing: self-damage, absorbs, and
-- amounts per unit of something else ("for each mana destroyed, the target takes 0.5 Shadow damage").
local function ignoredClause(c)
  return find(c, "himself") or find(c, "herself") or find(c, "yourself") or find(c, "absorb")
    or find(c, "for each ") or find(c, "damage taken per hit")
end

-- Per-combo-point tables ("1 point: 20 damage").
local function perPointTable(t)
  return find(t, "[^0-9]1 points? *:")
end

-- Self-healing based on maximum HP, over time or instant: percent, duration, interval.
local function healthPercent(t)
  local percent, duration, interval, manaPercent, fills
  percent, duration = match(t, "heals you for (" .. NUM .. ")%s*%% of your maximum health over (" .. NUM .. ") sec")
  if not percent then
    percent, manaPercent, duration = match(t, "restores (" .. NUM .. ")%% health and (" .. NUM
      .. ")%% mana over (" .. NUM .. ") sec")
  end
  if not percent then
    percent, duration = match(t, "restores (" .. NUM .. ")%s*%% of your maximum health over (" .. NUM .. ") sec")
    if not percent then
      percent, duration = match(t, "restores (" .. NUM .. ")%s*%% of maximum health over (" .. NUM .. ") sec")
    end
    if not percent then
      percent, duration = match(t, "regenerate (" .. NUM .. ")%s*%% of your maximum health over (" .. NUM .. ") sec")
    end
    if not percent then
      percent, interval, duration = match(t, "regenerates (" .. NUM .. ")%s*%% of total health and mana every (" .. NUM .. ") sec for (" .. NUM .. ") sec")
      if not percent then
        percent, duration = match(t, "restores (" .. NUM .. ")%s*%% of your health and mana per second for (" .. NUM .. ") sec")
        if percent then interval, fills = 1, true end
      end
      manaPercent = percent
    end
  end
  percent = match(t, "instantly restores (" .. NUM .. ")%s*%% health")
    or match(t, "instantly restores (" .. NUM .. ")%s*%% of your maximum health")
    or match(t, "instantly restores (" .. NUM .. ")%s*%% of total health")
    or match(t, "restores (" .. NUM .. ")%s*%% health instantly")
    or percent
  return percent, duration, interval, manaPercent, fills
end

-- A drink's share of maximum mana: percent, duration, interval (per tick when stated).
local MANA_OF = { "mana", "of your maximum mana", "of maximum mana", "of your total mana", "of total mana", "of your mana" }
local function manaPercent(t)
  for _, of in ipairs(MANA_OF) do
    local head = "restores (" .. NUM .. ")%s*%% " .. of
    local p, d = match(t, head .. " over (" .. NUM .. ") sec")
    if p then return p, d end
    p, d = match(t, head .. " per second for (" .. NUM .. ") sec")
    if p then return p, d, 1 end
    local i
    p, i, d = match(t, head .. " every (" .. NUM .. ") sec for (" .. NUM .. ") sec")
    if not p then p, i, d = match(t, "regenerates (" .. NUM .. ")%s*%% " .. of .. " every (" .. NUM .. ") sec for (" .. NUM .. ") sec") end
    if p then return p, d, i end
    -- Instant: only as the sentence's own statement, never the tail of another effect
    -- ("Heals the target for 100 and restores 5% mana.").
    p = match(t, "instantly restores (" .. NUM .. ")%s*%% " .. of .. "[%. ]*$")
      or match(t, "^" .. head .. "[%. ]*$") or match(t, "^use: " .. head .. "[%. ]*$")
    if p then return p end
  end
end

-- "Heals you for 20% of your maximum health": percent, and where the matched words end.
local function instantPercent(t)
  local percent, ending
  percent, ending = match(t, "heals you for (" .. NUM .. ")%s*%% of your maximum health()")
  if not percent then percent, ending = match(t, "heals you for (" .. NUM .. ")%s*%% of maximum health()") end
  if not percent then percent, ending = match(t, "healing you for (" .. NUM .. ")%s*%% of your maximum health()") end
  if not percent then percent = match(t, "heals you for (" .. NUM .. ")%s*%% and your pet for " .. NUM .. "%s*%% of maximum health") end
  return percent, ending
end

-- An instant percent heal with a further percent over time: extra percent, seconds.
local function extraPercent(t)
  return match(t, "heals you for an additional (" .. NUM .. ")%s*%% of your maximum health over (" .. NUM .. ") sec")
end

-- A consumable's amounts: health lo..hi, mana mlo..mhi, and a stated duration (minutes: the
-- duration is in minutes, not seconds).
local function itemHeal(t)
  local lo, hi
  local mlo, mhi
  local dur, minutes = nil, false
  mlo, mhi = match(t, "restores (" .. NUM .. ") to (" .. NUM .. ") mana")
  if not mlo then mlo = match(t, "restores (" .. NUM .. ") mana") end
  -- Over time (amount and duration in one pattern).
  do
    local a, b, d = match(t, "restores (" .. NUM .. ") to (" .. NUM .. ") health over (" .. NUM .. ") sec")
    if not a then a, d = match(t, "restores (" .. NUM .. ") health over (" .. NUM .. ") sec") end
    if not a then a, d = match(t, "restores (" .. NUM .. ") life over (" .. NUM .. ") sec") end
    if not a then a, b, d = match(t, "heals (" .. NUM .. ") to (" .. NUM .. ") damage over (" .. NUM .. ") sec") end
    if not a then a, d = match(t, "heals (" .. NUM .. ") damage over (" .. NUM .. ") sec") end
    if not a then a, b, d = match(t, "heals (" .. NUM .. ") to (" .. NUM .. ") health over (" .. NUM .. ") sec") end
    if not a then a, d = match(t, "heals (" .. NUM .. ") health over (" .. NUM .. ") sec") end
    if not a then
      a, b, d = match(t, "restores (" .. NUM .. ") to (" .. NUM .. ") health over (" .. NUM .. ") min")
      if not a then a, d = match(t, "restores (" .. NUM .. ") health over (" .. NUM .. ") min") end
      if a then minutes = true end
    end
    if a then lo, hi, dur = a, (b or a), d end
  end
  -- Instant: "Restores 70 to 90 health." / "Heals 66 damage."
  if not dur then
    lo, hi = match(t, "restores (" .. NUM .. ") to (" .. NUM .. ") health")
    if not lo then lo = match(t, "restores (" .. NUM .. ") health") end
    if not lo then lo, hi = match(t, "restores (" .. NUM .. ") to (" .. NUM .. ") life") end
    if not lo then lo = match(t, "restores (" .. NUM .. ") life") end
    if not lo then
      lo, hi = match(t, "heals (" .. NUM .. ") to (" .. NUM .. ") damage")
      if not lo then lo, hi = match(t, "heals (" .. NUM .. ") to (" .. NUM .. ") health") end
      if not lo then lo = match(t, "heals (" .. NUM .. ") damage") end
      if not lo then lo = match(t, "heals (" .. NUM .. ") health") end
    end
  end
  return lo, hi, mlo, mhi, dur, minutes
end

-- A drink: mana total, seconds, and the health total where one wording names both.
-- "Restores 151 mana over 18 sec." / "Restores 2148 health and 4410 mana over 30 sec."
local function itemDrink(t)
  local h, m, d = match(t, "restores (" .. NUM .. ") health and (" .. NUM .. ") mana over (" .. NUM .. ") sec")
  if m then return m, d, h end
  m, d = match(t, "restores (" .. NUM .. ") mana over (" .. NUM .. ") sec")
  return m, d
end

local REDUCE_VERBS = { "reduc", "lower", "decreas" }

-- A debuff's own words: the attack power and damage a clause names.
local function reductionStat(c)
  return find(c, "attack power", 1, true), find(c, "damage", 1, true)
end

local function weaponEN(t)
  local p, a, b = match(t, "(" .. NUM .. ")%% weapon damage plus an additional (" .. NUM .. ") with each weapon")
  if p then return { kind = "both", pct = num(p), bonus = num(a) } end
  -- Chance effects, what one trigger is worth: Windfury's extra attacks, Seal of Command's hit
  a, b = match(t, "(" .. NUM .. ") extra attacks? with ([0-9%(%) %*%.]+) extra melee attack power")
  if a then return { kind = "extra", attacks = num(a), amount = amountOf(b) } end
  b, p = match(t, "chance to deal additional ([a-z]+) damage equal to (" .. NUM .. ")%% of normal weapon damage")
  if p then return { kind = "weapon", pct = num(p), bonus = 0, school = SCHOOL_EN[b] } end
  if find(t, "chance", 1, true) or find(t, "with each weapon", 1, true) then return nil end
  local lo, hi, school = match(t, "each melee attack an additional (" .. NUM .. ") to (" .. NUM .. ") ([a-z]+) damage")
  -- "Each hit causes 6 to 22 additional ..."; later Flametongue Totem ranks: "Each main hand hit causes  9 to 31 ..."
  if not lo then lo, hi, school = match(t, "each [a-z ]-hit causes +(" .. NUM .. ") to (" .. NUM .. ") additional ([a-z]+) damage") end
  if lo then
    return { kind = "perhit", min = num(lo), max = num(hi), school = SCHOOL_EN[school],
      bySpeed = find(t, "slower weapons cause more", 1, true) and true or nil }
  end
  a, school = match(t, "melee attacks to [a-z]+ an additional (" .. NUM .. ") ([a-z]+) damage")
  if a then return { kind = "perhit", min = num(a), max = num(a), school = SCHOOL_EN[school] } end
  p, a = match(t, "damage equal to (" .. NUM .. ")%% of your attack power plus (" .. NUM .. ")")
  if not p then p = match(t, "damage equal to (" .. NUM .. ")%% of your attack power") end
  if p then return { kind = "appct", pct = num(p), bonus = num(a) or 0 } end
  a = match(t, "equal to (" .. NUM .. ") times the damage per second of your main hand weapon")
  if not a then a = match(t, "causing (" .. NUM .. ") times your main hand damage per second") end
  if a then return { kind = "dps", times = num(a), school = find(t, "holy", 1, true) and "holy" or "physical" } end
  p, a, b = match(t, "(" .. NUM .. ")%% weapon damage plus an additional (" .. NUM .. ") to (" .. NUM .. ")")
  if p then return { kind = "weapon", pct = num(p), bonus = num(a), bonusMax = num(b) } end
  p, a = match(t, "(" .. NUM .. ")%% weapon damage plus (" .. NUM .. ")")
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  -- druid attacks: "225% damage plus 180", Forever's Claw "110% normal damage plus 115"
  p, a = match(t, "(" .. NUM .. ")%% normal damage plus (" .. NUM .. ")")
  if not p then p, a = match(t, "(" .. NUM .. ")%% damage plus (" .. NUM .. ")") end
  if p then return { kind = "weapon", pct = num(p), bonus = num(a) } end
  p = match(t, " for (" .. NUM .. ")%% normal damage")
  if p then return { kind = "weapon", pct = num(p), bonus = 0 } end
  a = match(t, "weapon damage plus (" .. NUM .. ")")
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  -- "Sunder Armor also deals 150% weapon damage, increased by ...", "You deal 135% weapon damage, refreshing ...", "Viciously
  -- slash an enemy for 100% weapon damage": the number right after the verb (a stacking "plus 10% weapon damage per ..." is not it)
  p = match(t, "deals? (" .. NUM .. ")%% weapon damage") or match(t, " for (" .. NUM .. ")%% weapon damage")
  if p then return { kind = "weapon", pct = num(p), bonus = 0 } end
  -- Sniper Shot: "deals ranged damage plus 320": the ranged weapon's hit plus the amount
  a = match(t, "ranged damage plus (" .. NUM .. ")")
  if a then return { kind = "weapon", pct = 100, bonus = num(a), ranged = true } end
  a = match(t, "causes (" .. NUM .. ") damage in addition to your normal weapon damage")
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  if find(t, "causing weapon damage", 1, true) then return { kind = "weapon", pct = 100, bonus = 0 } end
  -- Classic's Claw: the claw's own damage on top of the form's normal hit
  a = match(t, "^claw the enemy, causing (" .. NUM .. ") additional damage")
  if a then return { kind = "weapon", pct = 100, bonus = num(a) } end
  a = match(t, "increases melee damage by (" .. NUM .. ")")
  if a then return { kind = "next", bonus = num(a) } end
  a = match(t, "next attack by (" .. NUM .. ")")
  if a then return { kind = "next", bonus = num(a) } end
  a = match(t, "increases ranged damage by (" .. NUM .. ")")
  if a then return { kind = "next", bonus = num(a), ranged = true } end
  -- Seal of the Crusader: "granting 306 melee attack power. The Paladin also attacks 40% faster,
  -- but deals less damage with each attack": the attack power, counted per faster hit
  a, p = match(t, "granting (" .. NUM .. ") melee attack power%. +the paladin also attacks (" .. NUM .. ")%% faster")
  if a then return { kind = "ap", amount = num(a), faster = num(p) } end
  a = match(t, "increases the strength of [^%.]- by (" .. NUM .. ")")
  if a then return { kind = "stat", stat = "str", amount = num(a) } end
  a = match(t, "increases the agility of [^%.]- by (" .. NUM .. ")")
  if a then return { kind = "stat", stat = "agi", amount = num(a) } end
  return nil
end

-- One sentence that raises attack power: "increasing the melee attack power of all party
-- members within 20 yards by 185". The number is the first "by" after the words attack power,
-- so the 20 yards before it are passed over.
local function attackPowerIn(sentence)
  local s = find(sentence, "attack power", 1, true)
  if not s then return nil end
  local before = sub(sentence, 1, s)
  if not find(before, "increas", 1, true) then return nil end
  if hasAny(sentence, REDUCE_VERBS) or find(sentence, "chance", 1, true) or find(sentence, "less damage", 1, true) then
    return nil
  end
  local a = match(sentence, "attack power[^%.]- by (" .. NUM .. ")")
  if not a then return nil end
  return { kind = "ap", amount = num(a), ranged = find(sentence, "ranged attack power", 1, true) ~= nil,
    plusAgility = find(sentence, "by " .. a .. " plus agility", 1, true) ~= nil }
end

-- "Unleashing this Seal's energy will cause 170 to 187 Holy damage to an enemy."
local function judgement(part)
  local lo, hi, school = match(part, "(" .. NUM .. ") to (" .. NUM .. ") ([a-z]+) damage")
  return lo, hi, school and SCHOOL_EN[school]
end

-- "for 30 sec" / "Lasts 30 sec"
local function sealDuration(t)
  return match(t, "for (" .. NUM .. ") sec") or match(t, "lasts (" .. NUM .. ") sec")
end

local function specialEN(t)
  local lo, hi, school, hlo, hhi = match(t, "causing (" .. NUM .. ") to (" .. NUM .. ") ([a-z]+) damage to an enemy, or ("
    .. NUM .. ") to (" .. NUM .. ") healing to an ally")
  if lo then return { direct = D(lo, hi), heal = D(hlo, hhi), school = SCHOOL_EN[school] } end
  local n, h, iv, dur
  n, school, h, iv, dur = match(t, "causing (" .. NUM .. ") ([a-z]+) damage to an enemy, or (" .. NUM
    .. ") healing to an ally, instantly and every (" .. NUM .. ") sec for (" .. NUM .. ") sec")
  if n then
    local hits = 1 + floor(num(dur) / num(iv) + 0.5)
    return { direct = D(num(n) * hits), heal = D(num(h) * hits), school = SCHOOL_EN[school], hits = hits }
  end
  lo, hi, n, dur = match(t, "heals a friendly target for (" .. NUM .. ") to (" .. NUM .. "), an additional ("
    .. NUM .. ") over (" .. NUM .. ") sec")
  if lo then return { heal = D(lo, hi), hot = { total = num(n), duration = num(dur) } } end
  -- Forever's Consecration: "doing 24 Holy damage over 8 sec to enemies who enter the area The
  -- first 4 enemies who enter the area will take an additional 56 damage over 8 sec". Its German
  -- gives the two amounts the other way round; both say the first 4 take 24 + 56, which is shown.
  local extra, first
  n, school, dur, first, extra = match(t, "doing (" .. NUM .. ") ([a-z]+) damage over (" .. NUM .. ") sec to enemies who enter "
    .. "the area%.? +the first (" .. NUM .. ") enemies who enter the area will take an additional (" .. NUM .. ") damage")
  if n then
    return { dot = { total = num(n) + num(extra), duration = num(dur) }, school = SCHOOL_EN[school], first = num(first) }
  end
  n, school, dur = match(t, "doing (" .. NUM .. ") ([a-z]+) damage over (" .. NUM .. ") sec")
  if n then return { dot = { total = num(n), duration = num(dur) }, school = SCHOOL_EN[school] } end
  -- Tranquility: "Regenerates all nearby party members within 20 yards for 87 every 2 sec for 10 sec"
  local every
  n, every, dur = match(t, "regenerates [^%.]- for (" .. NUM .. ") every (" .. NUM .. ") sec[a-z]* for (" .. NUM .. ") sec")
  if n then return { hot = { total = num(n) * floor(num(dur) / num(every) + 0.5), duration = num(dur) } } end
  n, dur = match(t, "restore (" .. NUM .. ") health over (" .. NUM .. ") sec")
  if n then return { hot = { total = num(n), duration = num(dur) } } end
  local per
  n, per = match(t, "causing (" .. NUM .. ") damage and converting each extra point of rage into (" .. NUM .. ") additional damage")
  if n then return { direct = D(n), school = "physical", perRage = num(per) } end
  n, dur = match(t, "bleed for (" .. NUM .. ") damage over (" .. NUM .. ") sec")
  if n then return { dot = { total = num(n), duration = num(dur) }, school = "physical" } end
  lo, hi, school = match(t, "repeatedly attacks an enemy [^%.]- for (" .. NUM .. ") to (" .. NUM .. ") ([a-z]+) damage")
  if lo then return { direct = D(lo, hi), school = SCHOOL_EN[school], perAttack = true } end
  n, iv = match(t, "heals group members [^%.]- for (" .. NUM .. ") every (" .. NUM .. ") seconds?")
  if n then return { heal = D(n), every = num(iv) } end
  local f
  lo, hi, f, school = match(t, "drains (" .. NUM .. ") to (" .. NUM .. ") mana [^%.]-%. for each mana drained in this way, the target takes ("
    .. NUM .. ") ([a-z]+) damage")
  if lo then return { direct = D(num(lo) * num(f), num(hi) * num(f)), school = SCHOOL_EN[school] } end
  n, school = match(t, "causes (" .. NUM .. ") ([a-z]+) damage to any creature that strikes a party member")
  if n then return { direct = D(n), school = SCHOOL_EN[school], perStrike = true } end
  n, school = match(t, "deals (" .. NUM .. ") ([a-z]+) damage for each attack blocked")
  if n then return { direct = D(n), school = SCHOOL_EN[school], perBlock = true } end
  if find(t, "for an amount equal to the paladin's maximum health", 1, true) then return { healMaxHealth = true } end
  -- Seal of Light, per trigger: "giving each melee attack a chance to heal the Paladin for 94"
  n = match(t, "giving each melee attack a chance to heal the paladin for (" .. NUM .. ")")
  if n then return { heal = D(n) } end
  n = match(t, "absorbing (" .. NUM .. ") damage") or match(t, "absorbs (" .. NUM .. ") [a-z]* ?damage")
  if n then return { absorb = num(n) } end
  -- Life Tap: "Converts 58 Health into 58 Mana for you."
  local hc, mg = match(t, "converts (" .. NUM .. ") health into (" .. NUM .. ") mana")
  if hc then return { healthCost = num(hc), manaGain = num(mg) } end
  -- Dark Sacrifice consumes the stated health over time, not a healing effect.
  local seconds
  hc, seconds, mg = match(t, "cannibalize (" .. NUM .. ") of your own health over (" .. NUM .. ") sec%.? to gain (" .. NUM .. ") mana")
  if hc then return { healthCost = num(hc), manaGain = num(mg), healthCostDuration = num(seconds) } end
  return nil
end

-- A finisher's damage over time in one point's row: "25 damage over 8 sec", or "25 over 8 sec"
-- where the description names damage elsewhere (damageText).
local function finisherDot(seg, damageText)
  local total, dur = match(seg, "^ *(" .. NUM .. ") damage over (" .. NUM .. ") sec")
  if not total and damageText then total, dur = match(seg, "^ *(" .. NUM .. ") over (" .. NUM .. ") sec") end
  return total, dur
end

-- The chance per hit: its percent, true where the text names a chance without a figure, or nil.
local function procChance(t)
  local p = match(t, "each [a-z ]-hit has a (" .. NUM .. ")%% chance") or match(t, "each strike has a (" .. NUM .. ")%% chance")
  if p then return num(p) end
  if find(t, "each [a-z ]-hit has a chance") or find(t, "each melee attack a chance", 1, true)
    or find(t, "each attack a chance", 1, true) or find(t, "gives the paladin a chance", 1, true) then
    return true
  end
  return nil
end

Parser.RegisterPack("en", {
  rangeWord = "to",
  damageWord = "damage",
  weaponWord = "weapon damage",
  pointsMarker = "points?",
  healWords = { "^ *heals ", " heals ", " healing ", " heal ", " healed for " },
  clauseSeparators = { ", and ", " and " },
  reduceVerbs = REDUCE_VERBS,
  -- The enemy has to be named somewhere in the sentence.
  enemyWords = { "target", "enem" },
  -- Damage the caster or the party takes, or the caster's own damage: not an enemy debuff.
  selfWords = { "take", "your ", "yourself" },
  -- "This healing is reduced by 50% on self ... by 80% when damage is done": the healing, not an enemy
  skipReduction = "^ *this healing ",
  increaseWord = "increas",
  byWord = "by ",
  sealEnergy = "unleashing this seal's energy",
  judgementSpell = "the energy of a seal spell",
  words = ENGLISH_WORDS,
  units = { sec = 1, min = 60, hour = 3600 },
  distanceWords = { yard = true, yards = true },
  hp5 = "health regeneration by (" .. NUM .. ") health per (" .. NUM .. ") sec",
  tickTails = { "^ *over ", "^ *every ", "^ *for " .. NUM .. " sec" },
  durationMarkers = { "over ", " sec", " min" },
  drainWords = { "drain" },
  manaWord = "mana",
  healing = {
    targets = { "and the caster" },
    channel = { "channel", "while you focus", "instantly and every" },
    trigger = { "click", "next time", "chance" },
    stack = { "stack", "expires" },
    pet = { "your pet" },
    target = { "heals the target", "heals a friendly target", "heals the friendly target", "heal your target" },
  },
  normaliseNumbers = normaliseNumbers,
  rewrite = rewrite,
  prepareSentences = prepareSentences,
  takeLasts = takeLasts,
  takeInterval = takeInterval,
  classifyAfter = classifyAfter,
  healAmountOK = healAmountOK,
  ignoredClause = ignoredClause,
  perPointTable = perPointTable,
  healthPercent = healthPercent,
  instantPercent = instantPercent,
  extraPercent = extraPercent,
  itemHeal = itemHeal, itemDrink = itemDrink, manaPercent = manaPercent,
  reductionStat = reductionStat,
  weapon = weaponEN,
  attackPower = attackPowerIn,
  judgement = judgement,
  sealDuration = sealDuration,
  special = specialEN,
  finisherDot = finisherDot,
  procChance = procChance,
})
