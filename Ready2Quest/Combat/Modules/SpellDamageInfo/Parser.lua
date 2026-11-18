-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: adapted from SpellDamageInfo/Parser.lua at 8269edd.
-- Maintained directly in this module.
-- SpellDamageInfo: reads a spell's damage and healing out of its description text.
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
--
-- Parse(text, lang) returns a table or nil:
--   direct = { min = n, max = n }         instant damage
--   dot    = { total = n, duration = s }  damage over time (total over the whole duration)
--   heal   = { min = n, max = n }         instant healing
--   hot    = { total = n, duration = s }  healing over time
--   school = "shadow" | "fire" | "nature" | "frost" | "arcane" | "holy" | "frostfire" | "physical" | "volcanic"
--            | "spellfire" | "spellfrost" | "shadowfrost" | "shadowflame" | "chaos" | "chimeral" | nil
--   transfer = true       "Transfers X health from the target to the caster" (Drain Life): one
--                         amount at both ends, damage in dot/direct and the same healing in
--                         hot/heal
--   petHeal = true        "Gives X health to the caster's pet" (Health Funnel): the pet is given
--                         health the caster pays, so the amount is a cost in healthCost
--   healthCost = n        health the caster pays (the pet transfer above; Life Tap's own pair is
--                         read by ParseSpecial)
--   hp5 = n               "increases health regeneration by X health per Y sec" (Demon Skin),
--                         the regeneration per 5 sec
-- It returns nil (plus a short reason) for any wording it does not understand, and never guesses.
-- ParseReduction(text, lang) reads how much a debuff lowers the enemy's damage or attack power.
-- lang is the code of a registered language pack ("en", "de") or nil (detect from the text).
-- Pure Lua 5.1, no game API, so it can be tested outside the game.
--
-- LANGUAGE PACKS
-- This file is the engine and holds no wording of any language. The wordings live in packs,
-- Parser_enUS.lua ("en", the base language: an unknown code falls back to it),
-- Parser_deDE.lua ("de"), Parser_ruRU.lua ("ru"), Parser_frFR.lua ("fr"), Parser_esES.lua ("es"), Parser_ptBR.lua ("pt"), Parser_zhCN.lua ("zh", zhCN and zhTW) and Parser_koKR.lua ("ko"), each listed after this file in both TOCs and each calling
-- Parser.RegisterPack(code, pack). A pack is only asked to read texts of its own language.
-- The kinds of wording that say WHAT a text is (a per-point table, weapon damage, a seal, who a
-- heal reaches, a tick tail) are asked of every pack, because Forever mixes the languages.
--
-- To add a language (Italian, say):
--   1. /sdi dump all on a client of that language; the unread spells in the dump show the wordings
--   2. copy Parser_frFR.lua (or Parser_deDE.lua) to Parser_itIT.lua, register it as "it" and translate its wordings
--   3. list the file in both TOCs after Parser_koKR.lua; add the client locale to PARSER_LANGS
--      (SpellDamageInfo/Locale.lua) and, if it is missing there, its "Use:" label to USE_PREFIXES
--      (SpellDamageInfo/Core.lua)
-- UTF-8 unit words are read without splitting their bytes; each pack supplies its own case folding.
--
-- A pack is a table. The helpers it needs are in Parser.util (NUM, num, D, amountOf, hasAny,
-- unitSeconds, stripFillers). Fields, with t the lower-cased, number-normalised text:
--   data
--     rangeWord        "to" / "bis": "9 to 12"
--     damageWord       "damage" / "schaden"
--     weaponWord       "weapon damage" / "waffenschaden": text of a weapon attack, no single number
--     pointsMarker     "points?" / "punkte?": a per-combo-point table ("1 point: ...")
--     healWords        patterns that make a clause a heal
--     clauseSeparators the words that split a sentence into clauses, tried in order
--     reduceVerbs, enemyWords, selfWords   plain words of a debuff that lowers damage or attack power
--     reduceVerbAtEnd  true where the verb comes last and covers the whole sentence (German)
--     skipReduction    pattern of a sentence that is no debuff, or nil
--     increaseWord     "increas" / "erh\195\182h": a clause that raises what it names is no reduction
--     byWord           "by " / "um ": what the reduction amount follows
--     sealEnergy       the words that start a seal's Judgement sentence
--     judgementSpell   the words of Judgement's own description
--     words            plain words of this language, for telling a German client's English texts
--     units            unit word prefix -> seconds ("sec", "min", "hour")
--     distanceWords    words that make "by 10 yards" a distance, not an amount
--     hp5              pattern of "health regeneration by X health per Y sec" (amount, interval)
--     tickTails        patterns of what makes an instant percent heal a ticking one
--     durationMarkers  plain words that make an instant item amount an over-time one
--     drainWords, manaWord   "draining 150 mana": the mana drain that shares a damage's duration
--     healing          plain word lists { targets, channel, trigger, stack, pet, target }
--   functions
--     lower(t), detect(t), toEnglish(text)       optional: umlaut case, language sniffing, a
--                                                German client's English text with its numbers
--     normaliseNumbers(t), rewrite(t), prepareSentences(t), takeLasts(t, take), takeInterval(c, num, one)
--     classifyAfter(after, sentence), healAmountOK(before, after), ignoredClause(c)
--     linkClauses(clauses)                       optional
--     perPointTable(t), healthPercent(t), instantPercent(t), extraPercent(t)
--     itemText(t) (optional), itemHeal(t), itemDrink(t), manaPercent(t) (both optional), reductionStat(c), weapon(t), attackPower(sentence)
--     judgement(part), sealDuration(t), special(t), finisherDot(seg, damageText), procChance(t)

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
-- Inside Ready2QuestCombat its own namespace; loaded on its own, the addon's table as before.
local ns = BIT and BIT.Module and BIT.Module("SpellDamageInfo") or BIT or {}

local Parser = {}
ns.Parser = Parser

local find, sub, gsub, match, gmatch = string.find, string.sub, string.gsub, string.match, string.gmatch
local tonumber, floor = tonumber, math.floor

-- Lower case by hand: string.lower and the %a/%d classes follow the process's C locale, and
-- under a code-page locale they would treat the bytes of UTF-8 letters as letters too.
local function asciiLower(c) return string.char(c:byte() + 32) end

-- A number as it looks after normalisation (thousand separators removed, "." as decimal point).
local NUM = "[0-9]+%.?[0-9]*"
local WORD = "[a-z\128-\255]+"

-- The registered packs, in registration order; BASE is what an unknown language code falls back to.
local BASE = "en"
local packs, order = {}, {}
local UNITS, DISTANCE = {}, {} -- every pack's unit prefixes and distance words, merged

function Parser.RegisterPack(code, pack)
  if not packs[code] then order[#order + 1] = code end
  packs[code] = pack
  for prefix, seconds in pairs(pack.units) do UNITS[prefix] = seconds end
  for word in pairs(pack.distanceWords) do DISTANCE[word] = true end
end

local function packFor(lang) return packs[lang] or packs[BASE] end

local function detectLanguage(t)
  for _, code in ipairs(order) do
    local pack = packs[code]
    if pack.detect and pack.detect(t) then return code end
  end
  return BASE
end

-- Wowhead-style formulas such as "[11 * (((1)))]" or "[26 * 8 * (1)]". The game prints the
-- result, so evaluate plain arithmetic (numbers, + - * / and brackets) and nothing else.
local function evalArithmetic(expr)
  local pos = 1
  local parseSum
  local function skip() pos = (find(expr, "[^ ]", pos)) or (#expr + 1) end
  local function parseAtom()
    skip()
    local c = sub(expr, pos, pos)
    if c == "(" then
      pos = pos + 1
      local v = parseSum()
      skip()
      if v == nil or sub(expr, pos, pos) ~= ")" then return nil end
      pos = pos + 1
      return v
    elseif c == "-" then
      pos = pos + 1
      local v = parseAtom()
      return v and -v
    end
    local s, e = find(expr, "^[0-9]+%.?[0-9]*", pos)
    if not s then return nil end
    pos = e + 1
    return tonumber(sub(expr, s, e))
  end
  local function parseProduct()
    local v = parseAtom()
    while v do
      skip()
      local c = sub(expr, pos, pos)
      if c ~= "*" and c ~= "/" then break end
      pos = pos + 1
      local r = parseAtom()
      if not r then return nil end
      if c == "*" then v = v * r elseif r == 0 then return nil else v = v / r end
    end
    return v
  end
  parseSum = function()
    local v = parseProduct()
    while v do
      skip()
      local c = sub(expr, pos, pos)
      if c ~= "+" and c ~= "-" then break end
      pos = pos + 1
      local r = parseProduct()
      if not r then return nil end
      if c == "+" then v = v + r else v = v - r end
    end
    return v
  end
  local v = parseSum()
  skip()
  if v == nil or pos <= #expr then return nil end
  return v
end

local function formatNumber(v)
  if v == floor(v) then return tostring(floor(v)) end
  return (gsub(string.format("%.2f", v), "0+$", ""))
end

local function replaceFormulas(t)
  local n, prev
  repeat
    prev = t
    t, n = gsub(t, "%[([0-9 %.%+%-%*/%(%)]+)%]", function(expr)
      local v = evalArithmetic(expr)
      if v then return formatNumber(v) end
    end)
  until n == 0 or t == prev
  -- Whatever is still in brackets holds words (optional glyph or talent text); it is not
  -- part of the spell's own numbers.
  repeat
    prev = t
    t = gsub(t, "%b[]", " ")
  until t == prev
  return t
end

local function num(v) return v and tonumber(v) or nil end

local function D(lo, hi) return { min = num(lo), max = num(hi or lo) } end

-- Windfury's attack power is sometimes a bracket of arithmetic: "with (122 * 1) extra".
local function amountOf(expr) return expr and evalArithmetic((gsub(expr, " +$", ""))) or nil end

local function hasAny(s, words)
  for _, w in ipairs(words) do
    if find(s, w, 1, true) then return true end
  end
  return false
end

-- "12 sec", "8 secs", "1 min", "30 minutes", "1 hour" / "12 Sek.", "8 Sekunden", "1 Min.", "1 Stunde":
-- the word starts with a unit prefix of any pack
local function unitSeconds(word)
  if not word then return nil end
  for prefix, seconds in pairs(UNITS) do
    if sub(word, 1, #prefix) == prefix then return seconds end
  end
  return nil
end

local function stripFillers(s, fillers)
  local again = true
  while again do
    again = false
    s = gsub(s, "^ +", "")
    for _, f in ipairs(fillers) do
      if sub(s, 1, #f) == f then
        s = sub(s, #f + 1)
        again = true
      end
    end
  end
  return s
end

Parser.util = { NUM = NUM, WORD = WORD, num = num, D = D, amountOf = amountOf, hasAny = hasAny,
  unitSeconds = unitSeconds, stripFillers = stripFillers }

-- Take "lasts N sec" / "Hält N Sek. lang an" out of the text: it is the duration of the whole
-- effect, used by "every N sec" amounts anywhere in the description.
local function extractLasts(t, pack)
  local values = {}
  local function take(num, unit)
    local u = unitSeconds(unit)
    if u then values[#values + 1] = tonumber(num) * u end
    return " "
  end
  t = pack.takeLasts(t, take)
  local lasts
  for _, v in ipairs(values) do
    if lasts and lasts ~= v then return t, nil, true end
    lasts = v
  end
  return t, lasts, false
end

local function splitSentences(t, pack)
  t = pack.prepareSentences(t)
  local out = {}
  for s in gmatch(t .. " ", "(.-)%. ") do out[#out + 1] = s end
  local rest = match(t .. " ", ".*%. (.*)$")
  if rest and find(rest, "[^ ]") then out[#out + 1] = rest end
  if #out == 0 then out[1] = t end
  return out
end

local function splitClauses(s, pack)
  for _, separator in ipairs(pack.clauseSeparators) do s = gsub(s, separator, "\1") end
  local out = {}
  for c in gmatch(s .. "\1", "([^\1]*)\1") do out[#out + 1] = " " .. c .. " " end
  return out
end

-- Remove the "every N sec" part of a clause and return its interval in seconds.
local function takeInterval(c, pack)
  local interval
  local function num(n, unit)
    local u = unitSeconds(unit)
    if u and not interval then interval = tonumber(n) * u end
    return " # "
  end
  local function one() if not interval then interval = 1 end return " # " end
  c = pack.takeInterval(c, num, one)
  return c, interval
end

-- Remove the durations of a clause ("over 12 sec", "12 Sek. lang", "after 1 min") and list them.
local function takeDurations(c)
  local list = {}
  c = gsub(c, "(" .. NUM .. ") ?(" .. WORD .. ")", function(n, unit)
    local u = unitSeconds(unit)
    if not u then return nil end
    list[#list + 1] = tonumber(n) * u
    return " # "
  end)
  return c, list
end

local function isHealClause(c, pack)
  for _, w in ipairs(pack.healWords) do
    if find(c, w) then return true end
  end
  return false
end

local function hasDamageWord(c, pack)
  return find(c, pack.damageWord, 1, true) ~= nil
end

-- Find the amounts in one clause. Each is { kind = "damage"|"heal"|"drain"|"petheal", min, max, school }.
local function findAmounts(c, pack, healMode, sentence)
  local amounts = {}
  local rangeWord = pack.rangeWord
  local pos = 1
  while true do
    local s, e = find(c, NUM, pos)
    if not s then break end
    local prevChar = sub(c, s - 1, s - 1)
    local valueMin = tonumber(sub(c, s, e))
    local valueMax = valueMin
    local stop = e
    -- "9 to 12" / "9 bis 12"
    local rs, re = find(c, "^ +" .. rangeWord .. " +" .. NUM, e + 1)
    if rs then
      local second = match(sub(c, rs, re), "(" .. NUM .. ")$")
      valueMax = tonumber(second)
      stop = re
    end
    pos = stop + 1
    if not match(prevChar, "[a-z0-9\128-\255%-]") and valueMin and valueMax then
      local before = sub(c, 1, s - 1)
      local after = sub(c, stop + 1)
      if healMode then
        if pack.healAmountOK(before, after) then
          amounts[#amounts + 1] = { kind = "heal", min = valueMin, max = valueMax }
        end
      else
        local kind, school = pack.classifyAfter(after, sentence)
        if kind == "damage" or kind == "drain" or kind == "petheal" then
          amounts[#amounts + 1] = { kind = kind, min = valueMin, max = valueMax, school = school }
        elseif kind == "giveheal" then
          amounts[#amounts + 1] = { kind = "heal", min = valueMin, max = valueMax }
        end
      end
    end
  end
  return amounts
end

-- Plain lower-case text with numbers in one format ("1.132" / "1,132" -> "1132", "7,1" -> "7.1"),
-- and the language.
local function prepare(text, lang)
  local t = gsub(text, "[\r\n\t]+", " ")
  t = gsub(t, "\194\160", " ") -- no-break space
  t = gsub(t, "|c[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]", "")
  t = gsub(t, "|r", "")
  t = replaceFormulas(t)
  t = gsub(t, "[A-Z]", asciiLower)
  for _, code in ipairs(order) do
    if packs[code].lower then t = packs[code].lower(t) end
  end
  if not packs[lang] then lang = detectLanguage(t) end
  local pack = packs[lang]
  t = pack.normaliseNumbers(t)
  t = pack.rewrite(t)
  return t, lang
end

-- A German client still shows some texts in English: Forever's does for spells Forever changed
-- ("Converts 52 Health into 52 Mana for you."). TextLanguage(text, lang) gives the base language
-- ("en") for a text with base words and not one word of lang's own, and lang otherwise.
function Parser.TextLanguage(text, lang)
  if type(text) == "string" then
    for _, code in ipairs(order) do
      local p = packs[code]
      if p.detectAlways and p.detect(text) then return code end
    end
  end
  local pack = packs[lang]
  if not pack or lang == BASE or type(text) ~= "string" then return lang end
  local t = " " .. gsub(gsub(text, "[\r\n]+", " "), "[A-Z]", asciiLower) .. " "
  if hasAny(t, packs[BASE].words) and not hasAny(t, pack.words) then return BASE end
  return lang
end

-- The text as the language it is really in, and that language: a German client's English text has
-- the client's own numbers and units, which the pack of the client's language puts the English way.
local function resolveText(text, lang)
  local textLang = Parser.TextLanguage(text, lang)
  local pack = packs[lang]
  if textLang == BASE and textLang ~= lang and pack and pack.toEnglish then text = pack.toEnglish(text) end
  return text, textLang
end

-- "draining 150 mana" / "zieht 30 Sek. lang 150 Mana ab": a pack's drain verb with its mana word
local function drainsMana(raw)
  for _, code in ipairs(order) do
    local p = packs[code]
    if hasAny(raw, p.drainWords) and find(raw, p.manaWord, 1, true) then return true end
  end
  return false
end

function Parser.Parse(text, lang)
  if type(text) ~= "string" or text == "" then return nil, "empty" end
  local t
  t, lang = prepare(text, lang)
  local pack = packs[lang]
  t = gsub(t, NUM .. " ?%%", " pct ")

  -- Per-combo-point tables and weapon-based attacks have no single number.
  for _, code in ipairs(order) do
    if packs[code].perPointTable(t) then return nil, "finisher" end
  end
  for _, code in ipairs(order) do
    if find(t, packs[code].weaponWord, 1, true) then return nil, "weapon" end
  end

  local lasts, lastsAmbiguous
  t, lasts, lastsAmbiguous = extractLasts(t, pack)

  -- "increases health regeneration by X health per Y sec" (Demon Skin / Demon Armor): the figure
  -- the buff is named by, health per 5 sec. Its clause reads as no amount of its own (health, but
  -- nothing transfers or is given), so the figure is read here on its own. The base language's
  -- wording is tried first, then the text's own ("erhöht die Gesundheitsregeneration um X
  -- Gesundheit pro Y Sek.").
  local hp5
  do
    local a, iv = match(t, packs[BASE].hp5)
    if not a and lang ~= BASE then a, iv = match(t, pack.hp5) end
    if a then
      iv = tonumber(iv)
      if iv and iv > 0 then hp5 = tonumber(a) * 5 / iv end
    end
  end

  local result = {}
  local found = false
  local function put(slot, value)
    if result[slot] then return false end
    result[slot] = value
    found = true
    return true
  end
  -- "Deals 21 Fire damage every 3 sec." with no duration anywhere in the text: not a damage over time (nothing says how long),
  -- but one amount per interval. Parse still answers nil for it; the amount comes back as the third value (see ParseSpecial).
  local tick

  for _, sentence in ipairs(splitSentences(t, pack)) do
    local clauses = {}
    local prevHeal = false
    for i, raw in ipairs(splitClauses(sentence, pack)) do
      local c, interval = takeInterval(raw, pack)
      local durations
      c, durations = takeDurations(c)
      local heal = isHealClause(c, pack) or (prevHeal and not hasDamageWord(c, pack))
      prevHeal = heal
      local amounts = {}
      if not pack.ignoredClause(c) then amounts = findAmounts(c, pack, heal, sentence) end
      clauses[i] = { text = c, raw = raw, interval = interval, durations = durations, amounts = amounts }
    end
    if pack.linkClauses then pack.linkClauses(clauses) end
    -- SDI-BLACKARROW: "causing 150 Shadow damage and draining 150 mana over 30 sec":
    -- splitClauses puts the damage and the duration in separate clauses, and the
    -- mana-drain clause holds no damage amount of its own. The "over 30 sec"
    -- belongs to both, so share it with the damage clause ahead of the drain.
    -- German ("verursacht 150 Schattenschaden und zieht 30 Sek. lang 150 Mana ab")
    -- splits the same way; its drain verb is "zieht", not "draining".
    for i = 1, #clauses - 1 do
      local a, b = clauses[i], clauses[i + 1]
      if #a.amounts > 0 and #a.durations == 0 and not a.interval
        and #b.amounts == 0 and #b.durations == 1 and not b.interval
        and drainsMana(b.raw) then
        a.durations = { b.durations[1] }
      end
    end
    for _, cl in ipairs(clauses) do
      local a1 = cl.amounts[1]
      if a1 and cl.interval and #cl.amounts == 1 and #cl.durations == 0 and not lasts and not lastsAmbiguous and not tick and not found
        and (a1.kind == "damage" or a1.kind == "heal") then
        tick = { kind = a1.kind, min = a1.min, max = a1.max, school = a1.school, every = cl.interval }
      elseif #cl.amounts > 0 then
        local periodic, duration, ticks
        if cl.interval then
          duration = (#cl.durations == 1 and cl.durations[1]) or (#cl.durations == 0 and lasts) or nil
          if not duration then
            return nil, lastsAmbiguous and "lasts-ambiguous" or "interval-without-duration"
          end
          ticks = floor(duration / cl.interval + 0.5)
          if ticks < 1 then return nil, "interval" end
          periodic = true
        elseif #cl.durations == 1 then
          if #cl.amounts > 1 then return nil, "two-amounts-one-duration" end
          duration = cl.durations[1]
          ticks = 1
          periodic = true
        elseif #cl.durations > 1 then
          return nil, "several-durations"
        end
        for _, a in ipairs(cl.amounts) do
          if a.kind == "petheal" then
            -- Health Funnel: the health the pet is given is health the caster pays, so it is
            -- the caster's cost (Life Tap's own shape), never a heal
            if periodic and a.min ~= a.max then return nil, "periodic-range" end
            result.petHeal = true
            if not result.healthCost then
              result.healthCost = periodic and (a.min * ticks) or ((a.min + a.max) / 2)
              found = true
            end
          else
            local isHeal = (a.kind == "heal")
            if periodic then
              if a.min ~= a.max then return nil, "periodic-range" end
              local slot = isHeal and "hot" or "dot"
              if not put(slot, { total = a.min * ticks, duration = duration }) then return nil, "second-" .. slot end
            else
              local slot = isHeal and "heal" or "direct"
              if not put(slot, { min = a.min, max = a.max }) then return nil, "second-" .. slot end
            end
            if a.kind == "drain" then
              -- Drain Life: a transfer has both ends - the same amount damages the target and
              -- heals the caster, so the healing sits beside the damage as well
              result.transfer = true
              local slot = periodic and "hot" or "heal"
              if not result[slot] then
                result[slot] = periodic and { total = a.min * ticks, duration = duration }
                  or { min = a.min, max = a.max }
              end
            end
            if not isHeal and result.school == nil and a.kind == "damage" then result.school = a.school end
          end
        end
      end
    end
  end

  if tick then
    -- any other amount in the text and the reading would be a guess
    if found or hp5 then return nil, "interval-without-duration" end
    return nil, "interval-without-duration", tick
  end
  if hp5 then result.hp5 = hp5 end
  if not found and not hp5 then return nil, "no-amount" end
  return result
end

-- Self-healing based on maximum HP: instantaneous Healthstone or a spell's
-- stated total over time. Missing-health, per-tick and pet healing are not equivalent.
function Parser.ParseHealthPercent(text, lang)
  if type(text) ~= "string" or text == "" then return nil, "empty" end
  -- Forever can mix English descriptions with the German client's units and numbers.
  text, lang = resolveText(text, lang)
  local t
  t, lang = prepare(text, lang)
  local pack = packs[lang]
  -- Healthstone states a fraction of maximum HP, never a flat healing amount.
  local percent, duration, interval, manaPercent, fills = pack.healthPercent(t)
  local directPercent
  if not percent then
    local ending
    percent, ending = pack.instantPercent(t)
    -- An unrecognised ticking clause must not become an instant heal.
    local tail = ending and sub(t, ending) or ""
    for _, code in ipairs(order) do
      for _, pattern in ipairs(packs[code].tickTails) do
        if match(tail, pattern) then return nil end
      end
    end
    if percent then
      local extra, seconds = pack.extraPercent(t)
      if extra then
        directPercent = tonumber(percent)
        percent, duration = directPercent + tonumber(extra), seconds
      end
    end
  end
  if percent then
    percent = tonumber(percent)
    duration = duration and tonumber(duration)
    if interval then
      interval = tonumber(interval)
      if interval <= 0 or not duration or duration <= 0 or duration / interval ~= floor(duration / interval) then return nil end
      percent = percent * duration / interval
      -- a food's ticks past the whole bar fill it; a spell's stay unread, as before
      if fills and percent > 100 then percent = 100 end
    end
    if percent and percent > 0 and percent <= 100 and (not duration or duration > 0) then
      -- food that is also a drink names a share of maximum mana beside the health
      manaPercent = tonumber(manaPercent)
      if manaPercent and interval then manaPercent = math.min(100, manaPercent * duration / interval) end
      if manaPercent and (manaPercent <= 0 or manaPercent > 100) then manaPercent = nil end
      return { healPercent = percent, duration = duration, directPercent = directPercent, manaPercent = manaPercent }
    end
    return nil, "invalid-percent"
  end
  return nil
end

-- A drink that states a share of maximum mana: { manaPercent = n, duration = seconds } for
-- the total over a stated time ("Restores 60% mana over 30 sec.", "Restores 4% of your mana
-- per second for 30 sec."), without a duration for an instant amount. An instant wording
-- beside any duration word may tick, so it stays unread.
function Parser.ParseManaPercent(text, lang)
  if type(text) ~= "string" or text == "" then return nil end
  text, lang = resolveText(text, lang)
  local t
  t, lang = prepare(text, lang)
  local pack = packs[lang]
  if not pack.manaPercent then return nil end
  local percent, duration, interval = pack.manaPercent(t)
  percent, duration, interval = tonumber(percent), tonumber(duration), tonumber(interval)
  if not percent then return nil end
  if interval then
    if interval <= 0 or not duration or duration <= 0 or duration / interval ~= floor(duration / interval) then return nil end
    percent = math.min(100, percent * duration / interval) -- ticks past the whole bar fill it
  end
  if percent <= 0 or percent > 100 or (duration and duration <= 0) then return nil, "invalid-percent" end
  if not duration then
    for _, code in ipairs(order) do
      if hasAny(t, packs[code].durationMarkers) then return nil, "over-time" end
    end
  end
  return { manaPercent = percent, duration = duration }
end

-- A consumable's healing or mana out of its use text ("Use: Restores 70 to 90
-- health." / "Benutzen: Stellt 70 bis 90 Punkt(e) Gesundheit wieder her."):
-- { heal = { min, max } } for an instant amount ("Restores"/"Stellt" health as
-- well as "Heals"/"Heilt" health or damage outside over time),
-- { healPercent = n } for instant healing expressed as a percentage of maximum HP,
-- { manaPercent = n, duration = d } for a share of maximum mana (alone, or beside healPercent),
-- { hot = { total, duration } } for a stated total over time: a bandage
-- ("Heals 66 damage over 6 sec." / "Heilt 7 Sek. lang 66 Punkt(e) Schaden.",
-- also "Heilt 66 Schaden über 6 Sek.") or food
-- ("Restores 243 health over 21 sec." / "Stellt 243 Gesundheit über 21 Sek.
-- wieder her."), the stated total averaged over a range exactly like a
-- potion's (70-90 -> 80),
-- { mana = { min, max } } for an instant mana amount ("Restores 140 to 175
-- mana." / "Stellt 140 bis 175 Mana wieder her."),
-- { manaOverTime = { total, duration } } for a drink's stated total ("Restores 151 mana
-- over 18 sec." / "Stellt im Verlauf von 18 Sek. 151 Punkt(e) Mana wieder her."), beside
-- a hot when the item restores both,
-- or nil (plus a short reason). Only stated amounts; any other mana wording with a
-- duration may tick, so it stays unread ("over-time") and is never guessed.
-- Damage wordings are never read here: Parse above keeps reading those
-- exactly as before.
function Parser.ParseItemHeal(text, lang)
  if type(text) ~= "string" or text == "" then return nil, "empty" end
  local percent, reason = Parser.ParseHealthPercent(text, lang)
  if percent then return percent end
  if reason then return nil, reason end
  percent, reason = Parser.ParseManaPercent(text, lang)
  if percent then return percent end
  if reason then return nil, reason end
  text, lang = resolveText(text, lang)
  local t
  t, lang = prepare(text, lang)
  local pack = packs[lang]
  if pack.itemText then t = pack.itemText(t) end
  -- Over-time amounts always come from ONE pattern that spans both the amount
  -- and its duration - a stray "over/\195\188ber" belonging to another sentence
  -- ("Restores 200 to 300 health. Restores 100 mana over 10 sec.") can never
  -- fabricate a hot. Instant wordings stay instant; unknown shapes stay unread.
  local lo, hi, mlo, mhi, dur, minutes = pack.itemHeal(t)
  dur = tonumber(dur)
  if dur and minutes then dur = dur * 60 end
  -- A drink: a stated mana total over a stated time, both out of ONE pattern ("Restores 151
  -- mana over 18 sec."), with the health total of a wording that names both at once
  -- ("Restores 2148 health and 4410 mana over 30 sec.").
  local drink, drinkHealth
  if pack.itemDrink then
    local m, d, h = pack.itemDrink(t)
    m, d, h = tonumber(m), tonumber(d), tonumber(h)
    if m and m > 0 and d and d > 0 then
      drink = { total = m, duration = d }
      drinkHealth = h and h > 0 and { total = h, duration = d } or nil
    end
  end
  if drink then
    if drinkHealth then return { hot = drinkHealth, manaOverTime = drink } end
    if dur and lo then
      lo, hi = tonumber(lo), tonumber(hi or lo)
      if lo and hi then return { hot = { total = (lo + hi) / 2, duration = dur }, manaOverTime = drink } end
    end
    -- an instant health amount beside it could be a tick: unread, as before
    if lo then return nil, "over-time" end
    return { manaOverTime = drink }
  end
  if dur then
    -- Over time: a stated health total is the healing it says - a bandage's
    -- ("Heals 66 damage over 6 sec." / "Heilt 66 Schaden über 6 Sek.") or
    -- food's ("Restores 243 health over 21 sec." / "stellt 243 Gesundheit über
    -- 21 Sek. wieder her"), Heals/Heilt as well as Restores/Stellt. A mana
    -- amount over time may tick, so it stays unread.
    if lo then
      lo, hi = tonumber(lo), tonumber(hi or lo)
      if lo and hi then return { hot = { total = (lo + hi) / 2, duration = dur } } end
    end
    return nil, "over-time"
  end
  -- An instant amount with a stray duration marker but no stated duration
  -- ("every 2 sec") may tick, so it stays unread too.
  if lo or mlo then
    for _, code in ipairs(order) do
      if hasAny(t, packs[code].durationMarkers) then return nil, "over-time" end
    end
  end
  local result
  if lo then
    lo, hi = tonumber(lo), tonumber(hi or lo)
    if not lo or not hi then return nil, "no-amount" end
    result = { heal = { min = lo, max = hi } }
  end
  if mlo then
    mlo, mhi = tonumber(mlo), tonumber(mhi or mlo)
    if mlo and mhi then
      result = result or {}
      result.mana = { min = mlo, max = mhi }
    end
  end
  if not result then return nil, "no-amount" end
  return result
end

---------------------------------------------------------------------------------------------
-- Debuffs that lower the enemy's damage or attack power
---------------------------------------------------------------------------------------------

-- One clause: "Damage caused by the target is reduced by 3", "reduces the melee attack power
-- of all enemies within 10 yards by 45" / "der vom Ziel verursachte Schaden wird ... um 3
-- reduziert", "verringert ... die Nahkampfangriffskraft ... um 45".
-- sentenceVerb: the sentence's verb lowers what this clause names. German puts it at the end,
-- after everything it lowers: "was seine Nahkampfangriffskraft um 43 und die Wirksamkeit
-- jeglicher Heilung um 20% verringert".
local function reductionInClause(c, pack, sentenceVerb)
  if not (sentenceVerb or hasAny(c, pack.reduceVerbs)) or hasAny(c, pack.selfWords) then return nil end
  -- "increasing melee attack power by 20 but reducing armor by 140": the attack power goes up
  if find(c, pack.increaseWord, 1, true) then return nil end
  local ap, dmg = pack.reductionStat(c)
  if not ap and not dmg then return nil end
  local by = pack.byWord
  local s, e, num
  local from = 1
  repeat -- the first "by N" / "um N" that starts a word ("nearby 3" does not)
    s, e, num = find(c, by .. "(" .. NUM .. ")", from)
    if not s then return nil end
    from = e + 1
    local prev = sub(c, s - 1, s - 1)
  until prev == "" or prev == " "
  local rest = sub(c, e + 1)
  local percent = find(rest, "^ ?%%") ~= nil
  if not percent then
    local word = match(rest, "^ ?(" .. WORD .. ")")
    -- "by 3 sec" is a duration; "by 10 yards" a distance
    if unitSeconds(word) or DISTANCE[word] then return nil end
  end
  local amount = tonumber(num)
  if not amount or amount <= 0 then return nil end
  return { amount = amount, percent = percent, stat = ap and "attackpower" or "damage" }
end

-- ParseReduction(text, lang) returns { amount = n, percent = true|false, stat = "damage" |
-- "attackpower" } for a spell that lowers the enemy's damage or attack power, or nil.
function Parser.ParseReduction(text, lang)
  if type(text) ~= "string" or text == "" then return nil end
  local t
  t, lang = prepare(text, lang)
  local pack = packs[lang]
  local found
  for _, sentence in ipairs(splitSentences(t, pack)) do
    -- "This healing is reduced by 50% on self ... by 80% when damage is done": the healing, not an enemy
    if hasAny(sentence, pack.enemyWords) and not (pack.skipReduction and find(sentence, pack.skipReduction)) then
      local verb = pack.reduceVerbAtEnd and hasAny(sentence, pack.reduceVerbs)
      for _, clause in ipairs(splitClauses(sentence, pack)) do
        -- a comma separates what the spell does to whom: "..., die Bewegungsgeschwindigkeit um
        -- 50% verringert"
        for c in gmatch(clause, "[^,]+") do
          local r = reductionInClause(c, pack, verb)
          if r then
            if found and (found.amount ~= r.amount or found.percent ~= r.percent) then return nil end
            found = found or r
          end
        end
      end
    end
  end
  return found
end

---------------------------------------------------------------------------------------------
-- Abilities whose damage comes from the weapon, and spells that raise attack power
---------------------------------------------------------------------------------------------
-- ParseWeapon(text, lang) returns a table or nil:
--   { kind = "next", bonus = n, ranged = bool }       the next swing, or a shot, is a weapon
--                                                      hit plus n: Heroic Strike, Maul, Aimed Shot
--   { kind = "weapon", pct = p, bonus = n, bonusMax = m }
--                                                      p% of a weapon hit plus n (to m):
--                                                      Overpower, Backstab, Shred, Sinister Strike
--   { kind = "both", pct = p, bonus = n }              p% of each weapon's hit plus n with each:
--                                                      Mutilate
--   { kind = "appct", pct = p, bonus = n }             p% of attack power plus n: Bloodthirst
--   { kind = "dps", times = n, school = s }            n times the main hand's damage per second:
--                                                      Hammer of the Righteous
--   { kind = "perhit", min = n, max = m, school = s, bySpeed = bool }
--                                                      what every hit gains while the seal or the
--                                                      imbue lasts: Seal of Righteousness,
--                                                      Flametongue Weapon; bySpeed where the text
--                                                      says slower weapons do more per swing
--   { kind = "ap", amount = n, ranged = bool, plusAgility = bool }
--                                                      attack power the spell adds: Battle Shout,
--                                                      Rockbiter Weapon, Bear Form, Aspect of the Hawk
--   { kind = "stat", stat = "str" | "agi", amount = n } strength or agility the spell adds, which
--                                                      turns into attack power: Strength of Earth
--   { kind = "extra", attacks = n, amount = a }        n extra attacks, each with a more attack
--                                                      power: Windfury Weapon and Totem
-- Parse() leaves the weapon attacks alone (it has no weapon to add the number to). Of the chance
-- effects, Windfury and Seal of Command are read here as what one trigger is worth (a weapon
-- view with school = "holy" for Seal of Command); every other sentence with a chance in it gives
-- nil, as does a sentence that lowers attack power, which is ParseReduction's. A seal's last
-- sentence is its Judgement ("Unleashing this Seal's energy ...") and is read by ParseJudgement,
-- never here. The wordings are the ones in the fixtures, which hold Classic's English and German
-- from Wowhead and Forever's own English, for every rank of every class.

-- A seal without its Judgement sentence, so neither the seal's own number nor its attack power
-- is taken from what the Judgement does.
local function withoutJudgement(t, lang)
  local s = find(t, packFor(lang).sealEnergy, 1, true)
  if s then return sub(t, 1, s - 1) end
  return t
end

function Parser.ParseWeapon(text, lang)
  if type(text) ~= "string" or text == "" then return nil end
  local t
  t, lang = prepare(text, lang)
  local pack = packs[lang]
  t = withoutJudgement((gsub(t, "^ +", "")), lang)
  local w = pack.weapon(t)
  if w then
    if (w.bonus and w.bonus < 0) or (w.pct and w.pct <= 0) then return nil end
    if w.kind == "extra" and not (w.amount and w.attacks > 0) then return nil end
    return w
  end
  for _, sentence in ipairs(splitSentences(t, pack)) do
    local ap = pack.attackPower(sentence)
    if ap and ap.amount > 0 then return ap end
  end
  return nil
end

---------------------------------------------------------------------------------------------
-- Seals and Judgement
---------------------------------------------------------------------------------------------

-- ParseJudgement(text, lang): a seal's Judgement damage, from its last sentence, as
-- { direct = { min, max }, school }, or nil (a seal whose Judgement does no damage, or any other
-- spell). "Unleashing this Seal's energy will cause 170 to 187 Holy damage to an enemy." /
-- "Die Entfesselung der Energie dieses Siegels fügt einem Feind 170 bis 187 Heiligschaden zu."
-- Seal of Command's "169 to 186 Holy damage, 339 to 373 if the target is stunned" gives the
-- first range, the one that applies to a target that is not stunned.
function Parser.ParseJudgement(text, lang)
  if type(text) ~= "string" or text == "" then return nil end
  local t
  t, lang = prepare(text, lang)
  local pack = packs[lang]
  local s = find(t, pack.sealEnergy, 1, true)
  if not s then return nil end
  local lo, hi, school = pack.judgement(sub(t, s))
  if not lo then return nil end
  return { direct = { min = num(lo), max = num(hi) }, school = school }
end

-- Is this Judgement itself? Its description names no damage of its own and points at the seals:
-- "Unleashes the energy of a Seal spell upon an enemy." / "Entfesselt die Energie eines
-- Siegelzaubers über einem Feind."
function Parser.IsJudgement(text, lang)
  if type(text) ~= "string" or text == "" then return false end
  local t
  t, lang = prepare(text, lang)
  return find(t, packs[lang].judgementSpell, 1, true) ~= nil
end

-- Is this a seal? Every seal ends with what its Judgement does, damage or not.
function Parser.IsSeal(text, lang)
  if type(text) ~= "string" or text == "" then return false end
  local t
  t, lang = prepare(text, lang)
  return find(t, packs[lang].sealEnergy, 1, true) ~= nil
end

-- How long a seal lasts, in seconds, or nil: "for 30 sec" / "Lasts 30 sec" / "30 Sek. lang".
function Parser.SealDuration(text, lang)
  if type(text) ~= "string" or text == "" then return nil end
  local t
  t, lang = prepare(withoutJudgement(text, lang), lang)
  return num(packs[lang].sealDuration(t))
end

---------------------------------------------------------------------------------------------
-- Wordings Parse() does not take apart
---------------------------------------------------------------------------------------------
-- ParseSpecial(text, lang), used when Parse() finds nothing or cannot say what it finds, returns
-- Parse()'s shape
-- (direct, dot, heal, hot, school) with, where it applies:
--   absorb = n           a shield: Power Word: Shield, Ice Barrier, the wards
--   healMaxHealth = true Lay on Hands: the paladin's own maximum health
--   perAttack = true     a totem's attack (Searing Totem), perBlock = true (Holy Shield),
--   perStrike = true     damage to whatever strikes the party (Retribution Aura),
--   every = s            a totem's pulse (Healing Stream Totem), perRage = n (Execute)
--   tickOnly = true      with every: one amount per interval and no duration in the text ("Deals 21 Fire damage every 3 sec"),
--                        read by ParseSpecial from Parse's third return value; shown as written, no bonus added
-- Each pattern is one family's own wording, from the fixtures, in the pack's language.
function Parser.ParseSpecial(text, lang)
  if type(text) ~= "string" or text == "" then return nil end
  local percent = Parser.ParseHealthPercent(text, lang)
  if percent then return percent end
  local t
  t, lang = prepare(text, lang)
  t = withoutJudgement(t, lang)
  local special = packs[lang].special(t)
  if special then return special end
  -- one amount per interval and no duration ("Causa 21 de dano de Fogo a cada 3 s", a pulse): shown as that amount, every N sec
  local _, _, tick = Parser.Parse(text, lang)
  if tick then
    local s = { every = tick.every, tickOnly = true }
    if tick.kind == "heal" then
      s.heal = { min = tick.min, max = tick.max }
    else
      s.direct = { min = tick.min, max = tick.max }
      s.school = tick.school
    end
    return s
  end
  return nil
end

---------------------------------------------------------------------------------------------
-- Finishers
---------------------------------------------------------------------------------------------
-- ParseFinisher(text, lang): a finisher's per-combo-point table as { points = { [1] = ...,
-- [5] = ... }, top = the highest point listed }, each entry { min, max } (Eviscerate, Ferocious
-- Bite) or { total, duration } (Rupture, Rip); nil for anything else, including per-point tables
-- of seconds or armour (Kidney Shot, Slice and Dice, Expose Armor). The numbers are the
-- description's own; the attack power the text says it adds is not in them.
function Parser.ParseFinisher(text, lang)
  if type(text) ~= "string" or text == "" then return nil end
  local t
  t, lang = prepare(text, lang)
  local pack = packs[lang]
  t = " " .. t .. " "
  local marker = pack.pointsMarker
  local damageText = find(t, pack.damageWord, 1, true)
  local marks, init = {}, 1
  while true do
    local s, e, n = find(t, "[^0-9]([1-9]%d*) " .. marker .. " *:", init)
    if not s then break end
    n = tonumber(n)
    if not n or n > 20 then return nil end -- bound the tooltip's per-point row walk
    marks[#marks + 1] = { s = s, e = e, n = n }
    init = e + 1
  end
  if #marks < 2 then return nil end
  local points, top, kind = {}, nil, nil
  for i, m in ipairs(marks) do
    local seg = sub(t, m.e + 1, marks[i + 1] and (marks[i + 1].s) or #t)
    local lo, hi = match(seg, "^ *(" .. NUM .. ")%-(" .. NUM .. ") ")
    -- Between the Eyes: "7 to 11 damage, 1 sec Stun" / "7 bis 11 Schaden, 1 Sek. Betäubung"
    if not lo then
      lo, hi = match(seg, "^ *(" .. NUM .. ") " .. pack.rangeWord .. " (" .. NUM .. ") ")
    end
    if lo and not find(seg, pack.damageWord, 1, true) then lo = nil end
    local total, dur = pack.finisherDot(seg, damageText)
    -- Retail can list a single finished amount instead of a min/max range.
    if not lo and not total then
      lo = match(seg, "^ *(" .. NUM .. ") " .. pack.damageWord .. "[%. ]*$")
      hi = lo
    end
    if lo then
      if kind and kind ~= "direct" then return nil end
      kind = "direct"
      points[m.n] = { min = num(lo), max = num(hi) }
    elseif total then
      if kind and kind ~= "dot" then return nil end
      kind = "dot"
      points[m.n] = { total = num(total), duration = num(dur) }
    else
      return nil
    end
    if not top or m.n > top then top = m.n end
  end
  return { points = points, top = top, kind = kind }
end

---------------------------------------------------------------------------------------------
-- Chance effects
---------------------------------------------------------------------------------------------
-- ProcChance(text, lang): the chance per hit of an effect that triggers on a hit, in percent, or
-- true where the text names no figure, or nil. The number shown for such a spell is what one
-- trigger does, and the tooltip says so. "Each hit has a 20% chance", "Each main hand hit has a
-- 20% chance", "Each strike has a 20% chance", "Each hit has a chance", "giving each melee
-- attack a chance", "granting each attack a chance", "Gives the Paladin a chance" / "Bei jedem
-- Treffer besteht eine Chance von 20%", "Bei jedem Schlag besteht eine Chance von 20%", "Bei
-- jedem Treffer besteht eine Chance,", "jedem Nahkampfangriff eine Chance verleiht", "gewährt
-- jedem Angriff die Chance", "gewährt ihm die Chance". A seal's Judgement is not looked at.
function Parser.ProcChance(text, lang)
  if type(text) ~= "string" or text == "" then return nil end
  local t
  t, lang = prepare(text, lang)
  t = withoutJudgement(t, lang)
  return packs[lang].procChance(t)
end

---------------------------------------------------------------------------------------------
-- Everything one description gives, and which of it the addon shows
---------------------------------------------------------------------------------------------

-- ParseSpecial wins over Parse only where it knows something Parse's shape cannot say: a
-- shield, the paladin's own health, a totem's attack or pulse, damage per block, per strike or
-- per extra rage, several hits; or where it reads a part Parse missed (Forever's German Holy
-- Shock, whose damage Parse does not find beside the heal). Where both read the same numbers
-- (Rend, Blizzard), Parse stays. Life Tap's health cost is its own flag.
local SPECIAL_FLAGS = { "absorb", "healMaxHealth", "healPercent", "perAttack", "perBlock", "perStrike", "every", "perRage", "hits", "first", "healthCost" }
local SLOTS = { "direct", "dot", "heal", "hot" }

local function specialWins(s, parsed)
  for _, k in ipairs(SPECIAL_FLAGS) do
    if s[k] then return true end
  end
  for _, k in ipairs(SLOTS) do
    if s[k] and not parsed[k] then return true end
  end
  return false
end

-- Does any pack's list of that kind of wording occur in the text?
local function anyPack(t, kind)
  for _, code in ipairs(order) do
    if hasAny(t, packs[code].healing[kind]) then return true end
  end
  return false
end

-- A readable amount is not proof that casting the spell starts a HoT on the selected friendly.
local function healingInfo(text, lang)
  local t = prepare(text, lang)
  local info = {}
  if anyPack(t, "targets") then
    info.targets = 2
  end
  if anyPack(t, "channel") then
    info.reason = "channel"
  elseif anyPack(t, "trigger") then
    info.reason = "trigger"
  elseif anyPack(t, "stack") then
    info.reason = "stack-or-expiration"
  elseif anyPack(t, "pet") then
    info.reason = "pet"
  elseif anyPack(t, "target") then
    info.target = true
  else
    info.reason = "unknown-recipient"
  end
  return info
end

-- Read(text, lang, noWeapon) runs every reader once and decides, in one place, what the addon
-- shows for the spell (show):
--   "weapon"     the weapon or attack power view (not with noWeapon: Retail's descriptions
--                already hold the player's stats, and Parse reads their finished numbers)
--   "judgement"  Judgement itself: the active seal's Judgement
--   nil          a seal with nothing per hit (its Judgement belongs on Judgement's button), or
--                nothing read at all
--   "special", "parsed", "finisher"  as their readers say; a seal shows its special (Seal of
--                Light's heal per trigger), never the Judgement's numbers
-- The reduction is shown beside any of these, or alone. proc is ProcChance's answer: the number
-- shown is what one trigger does.
function Parser.Read(text, lang, noWeapon)
  text, lang = resolveText(text, lang)
  local parsed, parseReason = Parser.Parse(text, lang)
  local e = {
    parsed = parsed or false,
    reduction = Parser.ParseReduction(text, lang) or false,
    weapon = Parser.ParseWeapon(text, lang) or false,
    special = Parser.ParseSpecial(text, lang) or false,
    finisher = Parser.ParseFinisher(text, lang) or false,
    judgement = Parser.ParseJudgement(text, lang) or false,
    isSeal = Parser.IsSeal(text, lang),
    isJudgement = Parser.IsJudgement(text, lang),
    sealDuration = Parser.SealDuration(text, lang),
    proc = Parser.ProcChance(text, lang) or false,
    lang = lang,
  }
  e.healing = healingInfo(text, lang)
  if e.healing.targets then
    if e.parsed then e.parsed.healTargets = e.healing.targets end
    if e.special then e.special.healTargets = e.healing.targets end
  end
  if e.weapon and not noWeapon then
    e.show = "weapon"
  elseif e.isJudgement then
    e.show = "judgement"
  elseif e.isSeal then
    e.show = e.special and "special" or nil
  elseif e.special and (not e.parsed or specialWins(e.special, e.parsed)) then
    e.show = "special"
  elseif e.parsed then
    e.show = "parsed"
  elseif e.finisher then
    e.show = "finisher"
  end
  if not e.show and not e.reduction and not e.isSeal and packs[lang] and packs[lang].unreadKind then
    local t = prepare(text, lang)
    e.unread = packs[lang].unreadKind(t)
    e.reason = parseReason
  end
  return e
end

return Parser
