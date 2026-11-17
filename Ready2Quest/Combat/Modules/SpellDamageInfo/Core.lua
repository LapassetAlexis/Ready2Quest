-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: adapted from SpellDamageInfo/Core.lua at 8269edd.
-- Maintained directly in this module.
-- SpellDamageInfo: action button numbers, tooltip lines, settings and /sdi.
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
--
-- Everything here stays out of Blizzard's way: the numbers are FontStrings of our own on the
-- action buttons, tooltip lines are added through the tooltip post-call hook, and no Blizzard
-- global or function is replaced. Values the client may hand out as secret (WoW: Forever hides
-- spell power in combat) are checked with issecretvalue before any comparison or maths.

local ADDON, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
-- Inside Ready2QuestCombat its own namespace; loaded on its own, the addon's table as before.
local ns = BIT.Module and BIT.Module("SpellDamageInfo") or BIT
local L, Parser, Estimate, Format = ns.L, ns.Parser, ns.Estimate, ns.Format

local DEFAULTS = {
  estimate = true, button = "total", tooltip = true,
  reduction = true,     -- show by how much a debuff lowers the enemy's damage, in red
  size = 100,           -- button number size in percent of the default (SIZE_MIN..SIZE_MAX)
  position = "bottom",  -- where the number sits on the button: bottom, center or top
  sidePosition = "opposite", -- second line: opposite the number, or forced bottom / top
  skipUtilityBars = true,   -- no numbers on the stance bar or the pet bar
  interfaceLang = "auto",  -- interface language: "auto", "en", "de", "ru"
  weapon = true,        -- potential damage of weapon abilities and attack power spells, in blue
  talents = true,       -- add the percent your talents give a spell (Forever's descriptions leave talents out)
  -- which kinds of number the buttons show (weapon and reduction above are two more); all on by default
  showDamage = true,    -- the damage of one cast (what the spell is predicted to do)
  showDot = true,       -- damage over time
  showHeal = true,      -- healing
  showHot = true,       -- healing over time
  showMana = true,      -- mana a consumable or Life Tap gives
  showAbsorb = true,    -- the shield a spell puts up
  useHistory = true,    -- a spell the parser cannot read shows the average of your last 100 casts of it (History.lua)
}
-- The kinds of number that can be switched off (filterView), and every on/off setting (validSetting, loadSettings).
local SHOW_KEYS = { "showDamage", "showDot", "showHeal", "showHot", "showMana", "showAbsorb" }
local BOOLEAN_KEYS = { estimate = true, tooltip = true, reduction = true, weapon = true, talents = true, useHistory = true,
  skipUtilityBars = true, showDamage = true, showDot = true, showHeal = true, showHot = true, showMana = true,
  showAbsorb = true }
local BUTTON_MODES = { total = true, direct = true, dps = true, off = true }
local POSITIONS = { bottom = true, center = true, top = true }
local SIDE_POSITIONS = { opposite = true, bottom = true, top = true }
local SIZE_MIN, SIZE_MAX = 50, 200

local db = {}
for k, v in pairs(DEFAULTS) do db[k] = v end

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, secret = pcall(issecretvalue, v)
  return ok and secret == true
end

local function say(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSpellDamageInfo|r: " .. msg) end
end

---------------------------------------------------------------------------------------------
-- Spell data
---------------------------------------------------------------------------------------------

-- [spellID] = { parsed = table or false, reduction = table or false, weapon = table or false,
--               text = the description }
local parsedCache = {}

local function clearCache()
  for k in pairs(parsedCache) do parsedCache[k] = nil end
  if ns._clearConsumables then ns._clearConsumables() end
end

local function getDescription(spellID)
  local fn = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
  if type(fn) ~= "function" then return nil end
  local ok, text = pcall(fn, spellID)
  if not ok or isSecret(text) or type(text) ~= "string" or text == "" then return nil end
  return text
end

local loadRequested = {} -- [spellID] = true once the client was asked to load the spell's text

local function requestLoad(spellID)
  if loadRequested[spellID] then return end
  loadRequested[spellID] = true
  if C_Spell and type(C_Spell.RequestLoadSpellData) == "function" then
    pcall(C_Spell.RequestLoadSpellData, spellID)
  elseif type(RequestLoadSpellData) == "function" then
    -- the same request under its older name, on clients without the C_Spell table
    pcall(RequestLoadSpellData, spellID)
  end
end

local itemLoadRequested = {} -- [itemID] = true once the client was asked for the item's data

-- An item's data can arrive after its button was drawn (GetItemSpell answers nothing at
-- all until it does), so the item is asked for once and the bars are painted again when
-- it lands (GET_ITEM_INFO_RECEIVED / ITEM_DATA_LOAD_RESULT). The spelling is the
-- documented C_Item.RequestLoadItemDataByID, the one HunterRangeFinder already uses;
-- the older clients load an item's data simply by being asked for it.
local function requestItemLoad(itemID)
  if itemLoadRequested[itemID] then return end
  itemLoadRequested[itemID] = true
  if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
    pcall(C_Item.RequestLoadItemDataByID, itemID)
  elseif type(GetItemInfo) == "function" then
    pcall(GetItemInfo, itemID)
  elseif C_Item and type(C_Item.GetItemInfo) == "function" then
    pcall(C_Item.GetItemInfo, itemID)
  end
end

-- A spell's parsed description, read again when its text has changed, looked at about every
-- RECHECK seconds a spell (between half of it and one and a half times, see nextCheck). A text can change with no event saying so: after Resurrection Sickness only a
-- /reload brought the numbers back, and the one thing a /reload renews that nothing else did is this
-- cache. (That the sickness is in the text is not proven: no sick description has been read.) A text
-- that cannot be read now leaves the last one in use.
local RECHECK = 2
-- A refresh of the bars spends at most PARSE_BUDGET milliseconds on reading texts (each read costs about a
-- millisecond: on Retail a buff can change every one at once, and after a talent change or a loading screen the
-- cache is empty and every button's spell needs its first reading). A text over budget keeps its last reading, a spell
-- never read yet shows nothing for the moment, and the next refresh goes on from there. This used to count only the
-- changed texts of spells already read, ten a refresh, so a cleared cache was read in one go: a hitch of tens of
-- milliseconds. parseBudget is nil outside a refresh, so a tooltip is never held back.
local PARSE_BUDGET = 4
local clock = type(debugprofilestop) == "function" and debugprofilestop or nil -- without it a read counts as a millisecond
local parseBudget, parseDeferred = nil, false
local function textClock()
  local ok, t = pcall(GetTime)
  return ok and type(t) == "number" and t or 0
end
-- When a spell's text is looked at next, as the cache keeps it (entry.due). The due times lie on a grid of RECHECK
-- seconds, shifted by a share (0 to 1) that depends on the spell, and are at least half a RECHECK away: so the spells of
-- a bar come due in different refreshes however the refreshes fall (they were all stamped alike and came due together,
-- every RECHECK seconds the descriptions of the whole bar were asked for in one refresh). After a long pause every
-- text is overdue at once, once; the grid spreads them out again.
local function nextCheck(spellID)
  local phase = RECHECK * ((spellID % 20) / 20)
  local k = math.ceil((textClock() + RECHECK * 0.5 - phase) / RECHECK)
  return k * RECHECK + phase
end
-- Attacks whose description names no number because the hit is the weapon's own: Attack (the melee swing), Auto Shot, Shoot
-- with a wand / bow / gun / crossbow, Throw. Read as "100% of the weapon hit", from the character sheet like every weapon
-- ability (the ranged ones from the ranged slot, the wand and thrown weapons included). The ids are Forever's own
-- (DB2 SpellName, build 1.60.1): Attack 6603 and 88163, Auto Shot 75 and 413446, Shoot (wand) 5019, Shoot Bow 2480, Shoot Gun
-- 7918, Shoot Crossbow 7919, Throw 2764.
local function plainWeaponAttack(ranged)
  return { show = "weapon", healing = {}, weapon = { kind = "weapon", pct = 100, bonus = 0, ranged = ranged or nil } }
end
local PLAIN_WEAPON_ATTACKS = {
  [6603] = plainWeaponAttack(), [88163] = plainWeaponAttack(),
  [75] = plainWeaponAttack(true), [413446] = plainWeaponAttack(true), [5019] = plainWeaponAttack(true),
  [2480] = plainWeaponAttack(true), [7918] = plainWeaponAttack(true), [7919] = plainWeaponAttack(true),
  [2764] = plainWeaponAttack(true),
}

local function getEntry(spellID)
  if isSecret(spellID) or type(spellID) ~= "number" then return nil end
  if PLAIN_WEAPON_ATTACKS[spellID] then return PLAIN_WEAPON_ATTACKS[spellID] end
  if ns.IsRetail and ns.IsRetail() and C_Spell and type(C_Spell.GetOverrideSpell) == "function" then
    local ok, override = pcall(C_Spell.GetOverrideSpell, spellID)
    if not ok or isSecret(override) then return nil end
    if type(override) == "number" and override > 0 then spellID = override end
  end
  local entry = parsedCache[spellID]
  if entry and entry.due and textClock() < entry.due then return entry end
  -- over budget: nothing is looked at until the next refresh (a text is not even asked for)
  if parseBudget and parseBudget <= 0 then
    parseDeferred = true
    return entry
  end
  local t0 = BIT.Perf and BIT.Perf.Begin()
  local text = getDescription(spellID)
  if BIT.Perf then BIT.Perf.End("SpellDamageInfo.description", t0) end
  if entry and (text == nil or text == entry.text) then
    entry.due = nextCheck(spellID)
    return entry
  end
  if not text then -- not loaded yet; SPELL_TEXT_UPDATE will ask again
    requestLoad(spellID)
    return nil
  end
  -- Parser.Read runs every reader and decides what is shown; see there.
  local started = parseBudget and clock and clock()
  local t1 = BIT.Perf and BIT.Perf.Begin()
  entry = Parser.Read(text, ns.DescriptionLang(), ns.IsRetail and ns.IsRetail())
  if BIT.Perf then BIT.Perf.End("SpellDamageInfo.parse", t1) end
  if parseBudget then parseBudget = parseBudget - (started and (clock() - started) or 1) end
  entry.text = text
  entry.due = nextCheck(spellID)
  parsedCache[spellID] = entry
  return entry
end

local function getParsed(spellID)
  local entry = getEntry(spellID)
  return entry and entry.parsed or nil
end

-- Cast time in seconds, or nil when the client does not say.
local function getCastTime(spellID)
  if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and not isSecret(info) and type(info) == "table" then
      local ms = info.castTime
      if not isSecret(ms) and type(ms) == "number" then return ms / 1000 end
    end
  end
  if type(GetSpellInfo) == "function" then
    local ok, _, _, _, ms = pcall(GetSpellInfo, spellID)
    if ok and not isSecret(ms) and type(ms) == "number" then return ms / 1000 end
  end
  return nil
end

-- Retail's descriptions already hold the player's spell power and attack power in their
-- numbers, so there the estimate and the weapon arithmetic would count them twice. Forever
-- answers WOW_PROJECT_ID like Retail, so the client's version decides: Retail is 10 and up,
-- Forever 1.60, Classic Era 1.15.
local function isRetail()
  if type(GetBuildInfo) ~= "function" then return false end
  local ok, version = pcall(GetBuildInfo)
  if not ok or isSecret(version) or type(version) ~= "string" then return false end
  local major = tonumber(version:match("^(%d+)"))
  return major ~= nil and major >= 10
end
ns.IsRetail = isRetail

-- The player's combo points, as the client says: a count within its resource cap and true,
-- or nil and false when the client cannot say (no API, a failed call, a secret value, or a
-- invalid count: NaN, infinite, negative, fractional). Classic/Forever keep 0..5 points on
-- the target: GetComboPoints("player", "target") is the authority, whatever the player's own
-- UnitPowerMax says (a zero combo bar must not gate the read, and no target GUID is looked at).
-- Retail keeps it on the player: UnitPower("player", combo points), and the target's
-- GetComboPoints is never asked there. The raw value is guarded with issecretvalue before any
-- comparison, arithmetic, formatting or use as a table key.
local COMBO_POWER_TYPE = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4
-- The UNIT_POWER_UPDATE / UNIT_POWER_FREQUENT events hand the powerType over as a cstring,
-- and the combo resource's token is "COMBO_POINTS" (pinned UnitDocumentation.lua payload
-- tables; CombatText.lua compares data == "COMBO_POINTS"). COMBO_POWER_TYPE above is the
-- numeric Enum.PowerType.ComboPoints that the UnitPower API itself takes -- never the shape
-- an event payload arrives in.
local COMBO_EVENT_TOKEN = "COMBO_POINTS"

-- What the game's own combo point display shows: the count for a client that hands insecure code a secret one.
-- Forever's API documentation marks GetComboPoints SecretWhenUnitPowerRestricted, and ResourceDing saw it answer
-- with a secret during a fight (2026-09-19); a finisher's number needs exactly the count of a fight. The display is
-- drawn by secure code that may read the count, and what it keeps is plain state: Forever's ComboFrame (the
-- Camelot Blizzard_UnitFrame, since build 70291) holds RogueComboPointTemplate frames in ComboFrame.ComboPoints,
-- RogueComboPointMixin:Update stores isFull on each, and the frame hides itself at zero (ComboFrameMixin:Update).
-- Returns the number of lit points (0 while the frame is hidden), or nil when the display cannot be read: no
-- ComboFrame of that shape (a unit frame addon may have replaced it) or a value that is secret. Never a guess.
-- A field on ns: the main chunk of this file is close to Lua's limit of 200 local variables.
function ns.DisplayedComboPoints()
  local frame = _G and _G.ComboFrame
  if type(frame) ~= "table" or type(frame.IsShown) ~= "function" then return nil end
  local points = frame.ComboPoints
  if type(points) ~= "table" or #points == 0 then return nil end
  -- A unit frame addon that took the frame over has stopped its events (and may keep it hidden): what it holds is
  -- then not what the target has, and a hidden frame must not read as zero. It listens to this one from OnLoad on.
  if type(frame.IsEventRegistered) == "function" then
    local okEvent, listening = pcall(frame.IsEventRegistered, frame, "PLAYER_TARGET_CHANGED")
    if okEvent and not isSecret(listening) and listening == false then return nil end
  end
  local okShown, shown = pcall(frame.IsShown, frame)
  if not okShown or isSecret(shown) or type(shown) ~= "boolean" then return nil end
  if not shown then return 0 end
  local count = 0
  for index = 1, #points do
    local point = points[index]
    if type(point) ~= "table" or type(point.IsShown) ~= "function" then return nil end
    local okVisible, visible = pcall(point.IsShown, point)
    if not okVisible or isSecret(visible) then return nil end
    -- a point the frame does not draw (past the resource's maximum) is not lit, whatever it last held
    if visible == true then
      local lit = ns.ComboPointLit(point)
      if lit == nil then return nil end
      if lit then count = count + 1 end
    end
  end
  return count
end

-- Is this combo point frame lit? isFull is the answer when it is plain (nil: never drawn yet). It is itself a
-- secret if the client carries the secrecy through the comparison that set it, and then the point's own drawing is
-- the answer, plain state as ResourceDing found the classic frame's highlight alpha to be: a full point shows its
-- BGActive background (the RogueComboPointTemplate animations fade it to alpha 1, an empty point's to 0).
-- true, false, or nil when neither can be read.
function ns.ComboPointLit(point)
  local full = point.isFull
  if not isSecret(full) then
    if full == nil then return false end
    if type(full) == "boolean" then return full end
    return nil
  end
  local background = point.BGActive
  if type(background) ~= "table" or type(background.GetAlpha) ~= "function" then return nil end
  local ok, alpha = pcall(background.GetAlpha, background)
  if not ok or isSecret(alpha) or type(alpha) ~= "number" then return nil end
  return alpha > 0.5
end

-- The count, whether it is known, and where it came from ("display" when GetComboPoints would not say).
local function comboPoints()
  local raw, maximum, source = nil, 5, nil
  if isRetail() then
    if type(UnitPower) ~= "function" then return nil, false end
    local ok, value = pcall(UnitPower, "player", COMBO_POWER_TYPE)
    if not ok then return nil, false end
    raw = value
    if type(UnitPowerMax) ~= "function" then return nil, false end
    local okMax, cap = pcall(UnitPowerMax, "player", COMBO_POWER_TYPE)
    if not okMax or isSecret(cap) or type(cap) ~= "number"
        or cap ~= cap or cap <= 0 or cap == math.huge or cap % 1 ~= 0 then return nil, false end
    maximum = cap
  else
    -- Forever keeps the points on the target. A call that fails, or answers with a secret as it does in a fight,
    -- is not the end of it: the game's own display shows the same count (ns.DisplayedComboPoints).
    local ok, value = false, nil
    if type(GetComboPoints) == "function" then ok, value = pcall(GetComboPoints, "player", "target") end
    if ok and not isSecret(value) and type(value) == "number" then
      raw = value
    else
      raw, source = ns.DisplayedComboPoints(), "display"
      if raw == nil then return nil, false end
    end
  end
  if isSecret(raw) or type(raw) ~= "number" then return nil, false end
  if raw ~= raw or raw < 0 or raw > maximum or raw % 1 ~= 0 then return nil, false end
  return raw, true, source
end

-- For /sdi combo: what this client says about the combo points, and which source the numbers use.
function ns.DescribeCombo(say)
  local function show(v)
    if isSecret(v) then return "secret" end
    return tostring(v)
  end
  local ok, value = false, nil
  if type(GetComboPoints) == "function" then ok, value = pcall(GetComboPoints, "player", "target") end
  say("GetComboPoints(player, target): " .. (ok and show(value) or "not available"))
  local displayed = ns.DisplayedComboPoints()
  say("combo display (ComboFrame): " .. (displayed ~= nil and tostring(displayed) or "cannot be read"))
  local n, known, source = comboPoints()
  say("finishers use: " .. (known and (tostring(n) .. " from " .. (source or "GetComboPoints")) or "unknown (a ? on the button)"))
end

-- Which client's spell tables SpellCoefficients.lua holds for this one: "forever" (1.60),
-- "era" (1.15), or nil for any other client.
local function coefficientClient()
  if type(GetBuildInfo) ~= "function" then return nil end
  local ok, version = pcall(GetBuildInfo)
  if not ok or isSecret(version) or type(version) ~= "string" then return nil end
  local major, minor = version:match("^(%d+)%.(%d+)")
  if tonumber(major) ~= 1 then return nil end
  return (tonumber(minor) >= 60) and "forever" or "era"
end

-- The spell's entry in SpellCoefficients for the running client: a table of shares, false (a
-- totem or trap, whose own spell the tables do not name), or nil when the tables have nothing.
local function spellCoefficients(spellID)
  local all, client = ns.SpellCoefficients, coefficientClient()
  if type(all) ~= "table" or not client or type(spellID) ~= "number" then return nil end
  local byID = all[client]
  if type(byID) ~= "table" then return nil end
  return byID[spellID]
end
ns.SpellCoefficientsFor = spellCoefficients

-- The swing time of the form a shapeshift spell turns into (Cat Form 1.0 sec), or nil.
local function formSpeed(spellID)
  local all, client = ns.FormSpeeds, coefficientClient()
  if type(all) ~= "table" or not client or type(all[client]) ~= "table" then return nil end
  return all[client][spellID]
end

-- Last readable spell power by school index (2..7) and for healing. In combat the client may
-- return secret values; then the last value read out of combat stays in use.
local bonus = { damage = {}, heal = nil }

local function readHealingBonus()
  if type(GetSpellBonusHealing) == "function" then
    local ok, v = pcall(GetSpellBonusHealing)
    if ok and not isSecret(v) and type(v) == "number" then bonus.heal = v end
  end
end
ns.RefreshHealingBonus = readHealingBonus

local function readBonus()
  if type(GetSpellBonusDamage) == "function" then
    for i = 2, 7 do
      local ok, v = pcall(GetSpellBonusDamage, i)
      if ok and not isSecret(v) and type(v) == "number" then bonus.damage[i] = v end
    end
  end
  readHealingBonus()
end

-- The player's weapons and the stats the weapon abilities need, as the client reports them:
-- the average hit (the character sheet's damage, which already holds attack power and form) and
-- the time between swings for the main hand, the off hand and the ranged weapon, attack power,
-- maximum health, class and form. WoW: Forever hides attack power in combat and these come from
-- it, so in combat the last numbers read out of combat stay in use.
local weaponStats = {}

local function number(v) return not isSecret(v) and type(v) == "number" and v or nil end

local function readWeapon()
  if type(UnitDamage) == "function" then
    local ok, lo, hi, olo, ohi = pcall(UnitDamage, "player")
    if ok then
      lo, hi, olo, ohi = number(lo), number(hi), number(olo), number(ohi)
      if lo and hi and hi > 0 then weaponStats.melee = (lo + hi) / 2 end
      -- a single weapon reports its off hand as nothing, or 0
      if olo and ohi then weaponStats.offhand = (ohi > 0) and (olo + ohi) / 2 or nil end
    end
  end
  if type(UnitAttackSpeed) == "function" then
    local ok, speed, off = pcall(UnitAttackSpeed, "player")
    if ok then
      local offSecret = isSecret(off)
      speed = number(speed)
      if speed and speed > 0 then
        weaponStats.meleeSpeed = speed
        -- the seal up while the speed was read: Seal of the Crusader's faster attacks are in it
        weaponStats.speedSeal = ns.ActiveSeal and ns.ActiveSeal() or nil
      end
      off = number(off)
      if not offSecret then weaponStats.offhandSpeed = (off and off > 0) and off or nil end
    end
  end
  if type(UnitRangedDamage) == "function" then
    local ok, speed, lo, hi = pcall(UnitRangedDamage, "player")
    if ok then
      speed, lo, hi = number(speed), number(lo), number(hi)
      if speed and lo and hi then
        if speed > 0 and hi > 0 then
          weaponStats.ranged, weaponStats.rangedSpeed = (lo + hi) / 2, speed
        else
          weaponStats.ranged, weaponStats.rangedSpeed = nil, nil
        end
      end
    end
  end
  if type(UnitAttackPower) == "function" then
    local ok, base, pos, neg = pcall(UnitAttackPower, "player")
    if ok then
      base, pos, neg = number(base), number(pos), number(neg)
      if base and pos and neg then weaponStats.ap = base + pos + neg end
    end
  end
  if type(UnitHealthMax) == "function" then
    local ok, v = pcall(UnitHealthMax, "player")
    v = ok and number(v) or nil
    if v and v > 0 then weaponStats.maxHealth = v end
  end
  if not weaponStats.class and type(UnitClass) == "function" then
    local ok, _, file = pcall(UnitClass, "player")
    if ok and not isSecret(file) and type(file) == "string" then weaponStats.class = file end
  end
  if type(GetShapeshiftFormID) == "function" then
    local ok, form = pcall(GetShapeshiftFormID)
    if ok and not isSecret(form) then weaponStats.form = (type(form) == "number") and form or nil end
  end
end

-- The main hand's average weapon damage without attack power (the sheet's average minus AP / 14 x speed), or nil.
-- Deep Wounds (DoTInfo/ProcDots.lua) pays a share of it. Out of combat reads only: in combat the last ones stay.
function ns.MainHandAverage()
  local avg, speed, ap = weaponStats.melee, weaponStats.meleeSpeed, weaponStats.ap
  if not avg then return nil end
  if speed and ap then avg = avg - ap / 14 * speed end
  return avg > 0 and avg or nil
end

-- The average hit of the player's best weapon attack (melee swing, or wand / bow / gun shot), as the character
-- sheet reports it (attack power included), or nil. DoTInfo's "next hit kills" check adds it to the DoTs' damage.
function ns.SwingAverage()
  local best = math.max(weaponStats.melee or 0, weaponStats.ranged or 0)
  return best > 0 and best or nil
end

-- Whether SwingAverage's best hit is a ranged one (DoTInfo's weapon icon takes the picture of Auto Shot or Shoot then).
function ns.SwingIsRanged()
  return (weaponStats.ranged or 0) > (weaponStats.melee or 0)
end

-- The target's attack speed, for what a lower attack power takes off each of its hits: Classic's
-- rule, 14 attack power are 1 damage for each second of weapon speed (the rule WeaponView uses for
-- the player's own weapon). UnitAttackSpeed can be secret in combat (SecretWhenUnitStatsRestricted):
-- then the speed read before for the same unit, by its GUID when that is not secret too, or none, and
-- the reduction stays in attack power ("-50 AP").
local AP_PER_DPS = 14
local SPEEDS_KEPT = 500 -- GUIDs remembered; past that the list starts again
local targetSpeed
local speedByGUID, speedCount = {}, 0

local function readTargetSpeed()
  targetSpeed = nil
  if type(UnitExists) ~= "function" or type(UnitAttackSpeed) ~= "function" then return end
  local ok, exists = pcall(UnitExists, "target")
  if not ok or isSecret(exists) or not exists then return end
  if type(UnitCanAttack) == "function" then
    local okA, can = pcall(UnitCanAttack, "player", "target")
    if okA and not isSecret(can) and not can then return end -- a friend: no hits to take off
  end
  local guid
  if type(UnitGUID) == "function" then
    local okG, g = pcall(UnitGUID, "target")
    if okG and not isSecret(g) and type(g) == "string" then guid = g end
  end
  local okS, speed = pcall(UnitAttackSpeed, "target")
  speed = okS and number(speed) or nil
  if speed and speed > 0 then
    targetSpeed = speed
    if guid then
      if not speedByGUID[guid] then
        if speedCount >= SPEEDS_KEPT then speedByGUID, speedCount = {}, 0 end
        speedCount = speedCount + 1
      end
      speedByGUID[guid] = speed
    end
  elseif guid then
    targetSpeed = speedByGUID[guid]
  end
end
ns.ReadTargetSpeed = readTargetSpeed
function ns.TargetSpeed() return targetSpeed end

-- What a reduction of attack power takes off each hit of the target, or nil: no target speed, a
-- percentage, or a reduction of damage (per hit already).
function ns.ReductionPerHit(r)
  if isRetail() then return nil end -- 14 AP per DPS is a Classic rule
  if type(r) ~= "table" or r.stat ~= "attackpower" or r.percent or not targetSpeed then return nil end
  local v = r.amount * targetSpeed / AP_PER_DPS
  return v >= 0.5 and v or nil
end

-- Attack power a point of strength or agility gives, by class (Classic's rules). Agility gives
-- melee attack power only to rogues and hunters, and to a druid in Cat Form (form 1).
local STR_AP = { WARRIOR = 2, PALADIN = 2, SHAMAN = 2, DRUID = 2 }
local AGI_AP = { ROGUE = 1, HUNTER = 1 }
local CAT_FORM = 1

local function statToAP(stat, stats)
  if stat == "str" then return STR_AP[stats.class or ""] or 1 end
  if AGI_AP[stats.class or ""] then return 1 end
  if stats.class == "DRUID" and stats.form == CAT_FORM then return 1 end
  return 0
end

-- What a result of Parser.ParseWeapon is worth per hit with the weapon in stats: a hit
-- ({ value, ... }) or a gain added to every hit ({ gain, ... }), or nil while a number it needs
-- is not known. Classic's rule: 14 attack power add 1 damage for each second of weapon speed.
-- Two things make it an estimate, and the tooltip says so: the speed is the one the client
-- reports, which haste shortens, and instant attacks count attack power at a normalised weapon
-- speed rather than the real one; either moves the number by a few percent. Cat Form's
-- "plus Agility" is left out of the gain and named in the tooltip. formSpeed: the swing time of
-- the form the spell shifts into (Cat or Bear Form), which its attack power counts in whatever
-- form the player is in now. sealUp: the speed was read with this seal up, so its faster attacks
-- are already in it.
function ns.WeaponView(w, stats, formSpeed, sealUp)
  if type(w) ~= "table" or type(stats) ~= "table" then return nil end
  local hit = w.ranged and stats.ranged or stats.melee
  local speed = w.ranged and stats.rangedSpeed or stats.meleeSpeed
  if w.kind == "ap" then
    if formSpeed then speed = formSpeed end
    if not speed then return nil end
    -- Seal of the Crusader: its hits come 40% faster, so each counts the attack power over a
    -- shorter swing; the client's speed has that in it already while the seal is up
    if w.faster and not sealUp then speed = speed / (1 + w.faster / 100) end
    return { gain = w.amount / 14 * speed, amount = w.amount, speed = speed, ranged = w.ranged, plusAgility = w.plusAgility,
      faster = w.faster }
  end
  if w.kind == "stat" then
    local factor = statToAP(w.stat, stats)
    if not speed or factor == 0 then return nil end
    return { gain = w.amount * factor / 14 * speed, stat = w.stat, amount = w.amount, factor = factor, speed = speed }
  end
  if w.kind == "perhit" then
    -- Where slower weapons do more per swing, a hit gains in proportion to the weapon's speed (a
    -- 4.0 sec weapon twice what a 2.0 sec one does, the Seal of Righteousness page says). The
    -- client's own text puts the range at base / 87 (or / 77) to base / 25, i.e. base x speed / 100
    -- from about 1.15 (1.3) sec to 4.0 sec, so the top of the range is the 4.0 sec weapon's.
    if w.bySpeed and stats.meleeSpeed then
      local gain = w.max * stats.meleeSpeed / 4
      if gain < w.min then gain = w.min end
      if gain > w.max then gain = w.max end
      return { gain = gain, perhit = true, min = w.min, max = w.max, school = w.school, speed = stats.meleeSpeed }
    end
    return { gain = (w.min + w.max) / 2, perhit = true, min = w.min, max = w.max, school = w.school }
  end
  if w.kind == "appct" then
    if not stats.ap then return nil end
    return { value = stats.ap * w.pct / 100 + (w.bonus or 0), appct = true, ap = stats.ap, pct = w.pct, bonus = w.bonus or 0 }
  end
  if not hit then return nil end
  -- Windfury: each extra attack is a normal swing with the extra attack power on top
  if w.kind == "extra" then
    if not speed then return nil end
    local each = hit + w.amount / 14 * speed
    return { value = w.attacks * each, extra = true, attacks = w.attacks, hit = hit, amount = w.amount, speed = speed }
  end
  if w.kind == "dps" then
    if not speed then return nil end
    local dps = hit / speed
    return { value = w.times * dps, times = w.times, dps = dps }
  end
  local pct = w.pct or 100
  local bonusAvg = w.bonusMax and (w.bonus + w.bonusMax) / 2 or w.bonus or 0
  if w.kind == "both" then
    local off = stats.offhand
    local value = hit * pct / 100 + bonusAvg + (off and (off * pct / 100 + bonusAvg) or 0)
    return { value = value, both = true, hit = hit, off = off, pct = pct, bonus = w.bonus or 0 }
  end
  return { value = hit * pct / 100 + bonusAvg, hit = hit, pct = pct, bonus = w.bonus or 0, bonusMax = w.bonusMax,
    ranged = w.ranged }
end

-- The seal on the player now. The seal's buff has the seal's own spell id, so the player's buffs
-- are read and the first one whose description is a seal's is it. Where the client will not say
-- (a secret aura), the last seal the player cast stands in until it would have run out.
local sealCast = { id = nil, at = 0, duration = 0 }

local function now()
  if type(GetTime) ~= "function" then return nil end
  local ok, t = pcall(GetTime)
  if ok and not isSecret(t) and type(t) == "number" then return t end
  return nil
end

local function buffSpellID(i)
  -- returns id (or nil), done, unreadable
  if C_UnitAuras and type(C_UnitAuras.GetBuffDataByIndex) == "function" then
    local ok, aura = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
    if not ok then return nil, true, false end
    if isSecret(aura) then return nil, true, true end
    if type(aura) ~= "table" then return nil, true, false end
    local id = aura.spellId
    if isSecret(id) then return nil, false, true end
    return type(id) == "number" and id or nil, false, false
  end
  if type(UnitBuff) == "function" then
    local ok, name, _, _, _, _, _, _, _, _, id = pcall(UnitBuff, "player", i)
    if not ok then return nil, true, false end
    if isSecret(name) or isSecret(id) then return nil, false, true end
    if name == nil then return nil, true, false end
    return type(id) == "number" and id or nil, false, false
  end
  return nil, true, false
end

local function activeSeal()
  local unreadable = false
  for i = 1, 40 do
    local id, done, secret = buffSpellID(i)
    if secret then unreadable = true end
    if done then break end
    if id then
      local e = getEntry(id)
      if e and e.isSeal then return id end
    end
  end
  local t = now()
  if unreadable and sealCast.id and t and t - sealCast.at < sealCast.duration then return sealCast.id end
  return nil
end
ns.ActiveSeal = activeSeal

local function noteSealCast(spellID)
  local e = getEntry(spellID)
  if not e or not e.isSeal then return end
  sealCast.id, sealCast.at, sealCast.duration = spellID, now() or 0, e.sealDuration or 30
end

-- A spell name, or nil.
local function spellName(spellID)
  local fn = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
  if type(fn) ~= "function" then return nil end
  local ok, name = pcall(fn, spellID)
  if ok and not isSecret(name) and type(name) == "string" then return name end
  return nil
end

-- The talents of Forever (Core/TalentMods.lua): their percent on the direct and the over-time part of a view. Forever's
-- descriptions leave talents out; Retail's already hold them, so there nothing is added. The spell's numbers (base and
-- spell power) are scaled together, as the game does with a "spell mod".
local function scaleRange(r, factor)
  if r then r.min, r.max = r.min * factor, r.max * factor; if r.added then r.added = r.added * factor end end
end
local function scalePeriodic(p, factor)
  if p then p.total = p.total * factor; if p.added then p.added = p.added * factor end end
end
local function applyTalents(view, spellID, pet)
  local mods = BIT.TalentMods
  if not view or pet or not db.talents or not mods or isRetail() or type(spellID) ~= "number" then return view end
  local ok, dDirect, dPeriodic, hDirect, hPeriodic = pcall(function()
    return (mods.Percent(spellID, view.school, "d", false)), (mods.Percent(spellID, view.school, "o", false)),
      (mods.Percent(spellID, nil, "d", true)), (mods.Percent(spellID, nil, "o", true))
  end)
  if not ok then return view end
  if view.direct and dDirect > 0 then scaleRange(view.direct, 1 + dDirect) end
  if view.dot and dPeriodic > 0 then scalePeriodic(view.dot, 1 + dPeriodic) end
  if view.heal and hDirect > 0 then scaleRange(view.heal, 1 + hDirect) end
  if view.hot and hPeriodic > 0 then scalePeriodic(view.hot, 1 + hPeriodic) end
  if dDirect > 0 or dPeriodic > 0 or hDirect > 0 or hPeriodic > 0 then
    view.talents = { direct = dDirect, dot = dPeriodic, heal = hDirect, hot = hPeriodic }
  end
  return view
end

-- The client's own share of spell power where SpellCoefficients has the spell, Classic's rules
-- otherwise. A totem or trap (false there) shows the description's own number, as a pet's spell
-- does. noBonus: a chance effect; the cast time rule would give it a share of spell power it does
-- not get, so without the tables' share for what it triggers it shows the description's number.
local function withEstimate(parsed, spellID, pet, castTime, noBonus)
  -- (a tick without a duration is the description's own figure: no spell power added to a number of unknown share)
  if pet or not db.estimate or isRetail() or parsed.tickOnly then return applyTalents(Estimate.Apply(parsed, nil, nil, nil), spellID, pet) end
  local coef = spellCoefficients(spellID)
  if coef == false or (noBonus and not coef) then return applyTalents(Estimate.Apply(parsed, nil, nil, nil), spellID, pet) end
  if parsed.hits and not coef then return applyTalents(Estimate.Apply(parsed, nil, nil, nil), spellID, pet) end
  if castTime == nil then castTime = getCastTime(spellID) end
  return applyTalents(Estimate.Apply(parsed, castTime, Estimate.DamageBonus(parsed.school, bonus.damage), bonus.heal, coef), spellID, pet)
end

local function percentHealView(parsed)
  local ok, maximum = pcall(UnitHealthMax, "player")
  maximum = ok and number(maximum) or nil
  if maximum and maximum > 0 and maximum < math.huge then
    local amount = maximum * parsed.healPercent / 100
    if parsed.duration then
      local direct = parsed.directPercent and maximum * parsed.directPercent / 100 or 0
      return { hot = { total = amount - direct, duration = parsed.duration, added = 0 },
        heal = parsed.directPercent and { min = direct, max = direct, added = 0 } or nil }
    end
    return { heal = { min = amount, max = amount, added = 0 } }
  end
  -- A hidden maximum cannot safely be converted or replaced with stale cached HP.
  return { healPercent = parsed.healPercent, duration = parsed.duration, directPercent = parsed.directPercent }
end

-- A drink's share of maximum mana, added to a consumable's view: the amount where the maximum
-- can be read (a class without mana gets none), else the stated percentage itself.
function ns._percentMana(view, parsed)
  local pct = parsed.manaPercent
  if not pct then return view end
  local ok, maximum = pcall(UnitPowerMax, "player", 0)
  maximum = ok and number(maximum) or nil
  if maximum and maximum < math.huge then
    if maximum <= 0 then return view end
    local amount = maximum * pct / 100
    view = view or {}
    if parsed.duration then
      view.manaOverTime = { total = amount, duration = parsed.duration }
    else
      view.mana = { min = amount, max = amount, added = 0 }
    end
    return view
  end
  view = view or { duration = parsed.duration }
  view.manaPercent = pct
  return view
end

local function specialView(s, spellID, pet, noBonus)
  if s.healPercent then return not pet and percentHealView(s) or nil end
  if s.absorb then
    -- Forever: a talent (Improved Power Word: Shield) raises the base amount, and the shield gets its share of spell
    -- power (Power Word: Shield 10%; the other shields carry their own term in the description). Retail: as written.
    local amount = s.absorb
    if not pet and not isRetail() and type(spellID) == "number" then
      -- Rank 1 of Power Word: Shield (id 17) writes the talent into its own description, so it is already in the number.
      if db.talents and BIT.TalentMods and spellID ~= 17 then
        local ok, percent = pcall(BIT.TalentMods.Percent, spellID, nil, "a", true)
        if ok and type(percent) == "number" and percent > 0 then amount = amount * (1 + percent) end
      end
      local share = BIT.AbsorbShares and BIT.AbsorbShares[spellID]
      if db.estimate and share and type(bonus.heal) == "number" and bonus.heal > 0 then
        amount = amount + bonus.heal * share
      end
    end
    return { absorb = amount }
  end
  if s.healthCost then
    return { healthCost = s.healthCost, manaGain = s.manaGain, healthCostDuration = s.healthCostDuration }
  end
  if s.healMaxHealth then
    local mh = weaponStats.maxHealth
    if pet or not mh then return nil end
    return { heal = { min = mh, max = mh, added = 0 }, healMax = true }
  end
  local view = withEstimate(s, spellID, pet, nil, noBonus)
  if view then
    view.perAttack, view.perBlock, view.every, view.perRage, view.hits = s.perAttack, s.perBlock, s.every, s.perRage, s.hits
    view.perStrike, view.first = s.perStrike, s.first
  end
  return view
end

local function finisherView(f, spellID, pet)
  local top = f.points[f.top]
  if not top then return nil end
  -- The damage of a finisher belongs to the combo points the selected target has right now,
  -- not to the highest row the description lists: pick that exact parsed row. When there is no
  -- row for the count, or the client cannot say what the count is, no precise amount is shown:
  -- the tooltip then explains the parsed table as a static preview.
  local n, known, source = comboPoints()
  local picked = known and n >= 1 and n <= f.top and f.points[n]
  local view
  if picked then
    local parsed = { school = "physical" }
    if f.kind == "dot" then parsed.dot = picked else parsed.direct = picked end
    view = applyTalents(Estimate.Apply(parsed, nil, nil, nil), spellID, pet)
    if view then view.finisherAt = { n = n, known = true, source = source } end
  elseif known and n == 0 then
    -- zero combo points (or no selected target): the button hides the amount, the tooltip
    -- explains the table without pretending a count
    view = { finisherAt = { n = 0, known = true, source = source } }
  else
    -- secret, failed or invalid count, or a count the parsed rows do not reach: a neutral
    -- placeholder on the button, and an explicitly static preview in the tooltip -- never the
    -- top row pretending to be current
    view = { finisherAt = { n = nil, known = false } }
  end
  if view then view.finisher, view.finisherRetail = f, isRetail() end
  return view
end

-- Judgement: the active seal's Judgement damage, with the spell power estimate an instant spell
-- gets; nil without a seal, or with one whose Judgement does no damage.
local function judgementView(pet)
  if pet then return nil end
  local sealID = activeSeal()
  if not sealID then return nil end
  local seal = getEntry(sealID)
  if not seal or not seal.judgement then return nil end
  local view = withEstimate(seal.judgement, nil, false, 0)
  if view then view.fromSeal, view.castTime = spellName(sealID) or tostring(sealID), 0 end
  return view
end

-- What to show for a spell: a view from Estimate.Apply, a weapon view ({ weapon = ... }), a
-- shield ({ absorb = n }), or nil. A pet's spell gets the description's numbers only: the pet
-- has its own spell power, and the player's would be wrong; the player's weapon means nothing to
-- it either.
function ns.Compute(spellID, pet)
  local entry = getEntry(spellID)
  if not entry then return nil end
  local show, proc = entry.show, entry.proc
  local view
  -- An ability the parser reads as a weapon attack is shown that way or not at all: the number
  -- Parse finds in some of them ("causing 115 additional damage") is only the part on top.
  if show == "weapon" then
    if pet or not db.weapon then return nil end
    local w = ns.WeaponView(entry.weapon, weaponStats, formSpeed(spellID), weaponStats.speedSeal == spellID)
    view = w and { weapon = w } or nil
  elseif show == "judgement" then
    return judgementView(pet)
  elseif show == "special" then
    view = specialView(entry.special, spellID, pet, proc)
    if view and entry.special.healPercent and entry.parsed then
      local damage = withEstimate(entry.parsed, spellID, pet, nil, proc)
      view.direct, view.dot, view.school = damage.direct, damage.dot, damage.school
      view.percentSelfHeal = damage.direct ~= nil or damage.dot ~= nil
    end
  elseif show == "parsed" then
    view = withEstimate(entry.parsed, spellID, pet, nil, proc)
  elseif show == "finisher" then
    view = finisherView(entry.finisher, spellID, pet)
  end
  -- the cast time the per-second number divides by ("dps" on the buttons); an unreadable one counts as an instant cast
  if view and db.button == "dps" and not view.weapon and view.castTime == nil then
    view.castTime = getCastTime(spellID) or 0
  end
  -- a chance effect: the number is what one trigger does
  if view and proc then view.proc = proc end
  return view
end

-- ns.Compute, and for a spell the parser cannot read (its description loads but nothing in it is understood: another game
-- language, a wording the packs do not know) the average of your last casts of it (History.lua), marked as such. For the
-- buttons and the tooltip only: the plates and the kill markers keep asking ns.Compute for what the description says.
function ns.ComputeOrAverage(spellID, pet)
  local view = ns.Compute(spellID, pet)
  if view or pet or not db.useHistory or not ns.History then return view end
  local entry = getEntry(spellID)
  if not entry or entry.show ~= nil then return nil end
  local average = ns.History.View(spellID)
  if average and db.button == "dps" then average.castTime = getCastTime(spellID) or 0 end
  return average
end

-- The damage of the part of a spell that lands at once, as its description states it (no spell power added): the average of
-- its range, 0 when the spell has none, nil when the text is not read as plain damage. DoTInfo's tick learning takes it off
-- the damage meter's total for the spell (MeterLearning.lua).
function ns.UpfrontDamage(spellID)
  local entry = getEntry(spellID)
  local parsed = entry and entry.show == "parsed" and entry.parsed
  if not parsed then return nil end
  if parsed.direct then return (parsed.direct.min + parsed.direct.max) / 2 end
  return 0
end

-- What a spell's description says one cast does in all (no spell power added): damage (the direct part and the damage over
-- time) and healing (the heal and the heal over time); nil when the text is not read as plain numbers. DoTInfo's list of
-- recorded casts puts it beside what the casts really did.
function ns.DescriptionTotals(spellID)
  local entry = getEntry(spellID)
  local parsed = entry and entry.show == "parsed" and entry.parsed
  if not parsed then return nil end
  local damage, heal = 0, 0
  if parsed.direct then damage = damage + (parsed.direct.min + parsed.direct.max) / 2 end
  if parsed.dot then damage = damage + parsed.dot.total end
  if parsed.heal then heal = heal + (parsed.heal.min + parsed.heal.max) / 2 end
  if parsed.hot then heal = heal + parsed.hot.total end
  return damage, heal
end

-- HealPrediction consumes this independently of action-button options or the module's event loop.
function ns.ComputeHot(spellID)
  local entry = getEntry(spellID)
  if not entry or not entry.healing.target then return nil end
  local parsed = entry.show == "special" and entry.special or (entry.show == "parsed" and entry.parsed)
  if not parsed or not parsed.hot or parsed.direct or parsed.dot or parsed.transfer or parsed.petHeal
    or parsed.hits or parsed.every or entry.proc then return nil end
  readHealingBonus()
  local coef = spellCoefficients(spellID)
  local view
  if isRetail() or coef == false then
    view = Estimate.Apply(parsed, nil, nil, nil)
  else
    view = Estimate.Apply(parsed, getCastTime(spellID), nil, bonus.heal, coef)
  end
  if view then view = applyTalents(view, spellID, false) end
  return view and view.hot, spellName(spellID)
end

-- The use-effect spell of an item (a potion's "Use:" spell), or nil when the item
-- casts none or the client does not say. The client's own API documentation
-- (Blizzard_APIDocumentationGenerated/ItemDocumentation.lua) lists the lookup as
-- C_Item.GetItemSpell answering (name, spellID) and possibly nothing at all while the
-- item's data is still arriving (MayReturnNothing); the bare GetItemSpell is only the
-- deprecated alias of it, kept in a deprecation file some clients load on demand (the
-- same shelf as GetActionCount below), so the namespaced one is asked first. The raw
-- values are guarded with issecretvalue before anything is read from them.
local function itemUseSpell(itemID)
  if isSecret(itemID) or type(itemID) ~= "number" then return nil end
  local fn = (C_Item and C_Item.GetItemSpell) or GetItemSpell
  if type(fn) ~= "function" then return nil end
  local ok, name, id = pcall(fn, itemID)
  if not ok or isSecret(name) or isSecret(id) then return nil end
  if type(id) == "number" then return id end
  if type(name) == "number" then return name end
  return nil
end

-- The "Use:" line of an item's own tooltip ("Use: Heals 611 damage over 6 sec." /
-- "Benutzen: Heilt 611 Schaden über 6 Sek."), for when the use spell's description
-- cannot be read: an item's amounts are stated on the item, and the spell behind them
-- need not be in the client's text cache at all. Read through C_TooltipInfo.GetHyperlink,
-- the accessor StatsInfo already reads enchant lines with; only the item's own use line
-- is taken (never requirements, flavour or price), and ParseItemHeal reads the amounts
-- out of it exactly as out of a spell description. Nil when the client has no tooltip
-- data or the item's data has not arrived yet (a tooltip with no use line). What a built
-- tooltip answered is kept (the use line of an item does not change); a tooltip that is
-- still on its way, or one holding a hidden line, is scanned again like the enchant scan.
local itemTextMemo = {} -- [itemID] = the use line, or "" when a built tooltip has none
-- The "Use:" label of every client language whose wordings the parser may one day read:
-- "Use:" (en), "Benutzen:" (de), "Utiliser :" (fr), "Usar:" (es/pt), "Usa:" (it),
-- "Использование:" (ru). A line starting with one is the item's own use text; an item whose
-- language is not read yet stays without a number instead of guessing.
local USE_PREFIXES = {
  "Use:", "use:", "Benutzen:", "benutzen:", "Utiliser :", "Utiliser:", "utiliser :", "utiliser:", "Utiliser\194\160:", "utiliser\194\160:",
  "Uso:", "uso:", "사용:", "사용 효과:", "使用:", "使用：", "Usar:", "usar:", "Usa:", "usa:",
  "\208\152\209\129\208\191\208\190\208\187\209\140\208\183\208\190\208\178\208\176\208\189\208\184\208\181:",
  "\208\184\209\129\208\191\208\190\208\187\209\140\208\183\208\190\208\178\208\176\208\189\208\184\208\181:",
}
-- A trailing cooldown clause is the item's cooldown, not a duration its amount ticks over:
-- "(2 Min Cooldown)" (en), "(2 Min. Abklingzeit)" (de), "(2 min de recharge)" (fr), "(2 min de reutilización)" (es), "(2 min de recarga)" (pt). ParseItemHeal would read the wording
-- as over-time for it. Stripped in every language whose wordings the parser reads.
local COOLDOWN_WORDS = { "Cooldown", "cooldown", "Abklingzeit", "abklingzeit",
  "Восстановление", "восстановление", "de recharge", "de reutilización", "de recarga", "대기시간", "冷却" }

local function stripCooldownClause(t)
  for _, word in ipairs(COOLDOWN_WORDS) do
    t = t:gsub("%s*%([^(]*" .. word .. "[^)]*%)%s*$", "")
  end
  return t
end

local function itemUseText(itemID)
  if isSecret(itemID) or type(itemID) ~= "number" then return nil end
  local memo = itemTextMemo[itemID]
  if memo ~= nil then return memo ~= "" and memo or nil end
  if type(C_TooltipInfo) ~= "table" or type(C_TooltipInfo.GetHyperlink) ~= "function" then return nil end
  local ok, data = pcall(C_TooltipInfo.GetHyperlink, "item:" .. tostring(itemID))
  if not ok or isSecret(data) or type(data) ~= "table" or isSecret(data.lines) or type(data.lines) ~= "table" then return nil end
  local out, cacheable, shown = {}, true, 0
  for _, line in ipairs(data.lines) do
    if type(line) ~= "table" or isSecret(line) then
      cacheable = false -- the hidden line may be the use line: not a final answer
    else
      shown = shown + 1
      local text = line.leftText
      if isSecret(text) then
        cacheable = false
      elseif type(text) == "string" then
        -- a trailing cooldown clause is the item's cooldown, not a duration its amount
        -- ticks over; ParseItemHeal would read the wording as over-time for it
        local t = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", "")
        t = stripCooldownClause(t)
        for _, prefix in ipairs(USE_PREFIXES) do
          if t:sub(1, #prefix) == prefix then
            out[#out + 1] = t
            break
          end
        end
      end
    end
  end
  local joined = table.concat(out, "\n")
  if joined ~= "" then
    itemTextMemo[itemID] = joined
    return joined
  end
  -- one line is the item's name alone: the tooltip has not built its text yet
  if cacheable and shown >= 2 then itemTextMemo[itemID] = "" end
  return nil
end

-- A weapon poison's per-proc reading from its own coating text: "Each strike has a 20% chance
-- of poisoning the enemy, causing 13 to 17 Nature damage." / "Bei jedem Schlag besteht eine
-- Chance von 20%, den Gegner zu vergiften und ihm sofort 13 bis 17 Naturschaden zuzufuegen."
-- (Deadly Poison's over-time wording reads as a dot.) The coating wording is the only item
-- text that reaches the spell parser from here: bombs, oils or a stray damage line can never
-- become an item number through this path.
-- The stems are case-proof and stray-capital-proof ("Überzieht eine Waffe"): the leading
-- umlaut and the following noun's capital never sit inside the stem.
local COATING_WORDS = { "oats a weapon", "oats your weapon", "berzieht eine ", "berzieht eure " }

local function coatingText(t)
  if type(t) ~= "string" then return nil end
  for _, word in ipairs(COATING_WORDS) do
    if string.find(t, word, 1, true) then return t end
  end
  return nil
end

local function poisonView(text)
  local t = coatingText(text)
  if not t then return nil end
  local entry = Parser.Read(t, ns.DescriptionLang(), ns.IsRetail and ns.IsRetail())
  local p = entry and entry.parsed
  if not p then return nil end
  local view
  if p.direct then
    view = { direct = { min = p.direct.min, max = p.direct.max, added = 0 } }
  end
  if p.dot then
    view = view or {}
    view.dot = { total = p.dot.total, duration = p.dot.duration, added = 0 }
  end
  if not view then return nil end
  if entry.proc then view.proc = entry.proc end
  return view
end

-- What to show for a consumable on the bar: its raw instant healing or mana,
-- or a stated healing total over time -- a bandage's ("Heals 66 damage over 6
-- sec.") or food's ("Restores 243 health over 21 sec."). Fixed amounts stay literal;
-- percentage healing uses the player's current maximum HP. Damage wordings are never read
-- here -- with one exception: a weapon poison's coating text names the per-trigger damage the
-- item buys, so that (and only that) reads as its number. Anything over time without a stated
-- health total stays unread. The text
-- comes from the use spell's description where that can be read, else from the
-- item's own "Use:" line; when neither is readable yet nothing is guessed -- the
-- item's data and the spell's text are asked for and the button is painted again
-- on GET_ITEM_INFO_RECEIVED / SPELL_TEXT_UPDATE.
-- The view of a consumable's parsed use text (Parser.ParseItemHeal): its healing, its mana, over time or at once.
local function consumableView(parsed)
  if parsed.healPercent then
    return ns._percentMana(percentHealView(parsed), parsed)
  end
  if parsed.manaPercent then return ns._percentMana(nil, parsed) end
  local view
  if parsed.heal then
    view = view or {}
    view.heal = { min = parsed.heal.min, max = parsed.heal.max, added = 0 }
  end
  if parsed.hot then
    view = view or {}
    view.hot = { total = parsed.hot.total, duration = parsed.hot.duration, added = 0 }
  end
  if parsed.mana then
    view = view or {}
    view.mana = { min = parsed.mana.min, max = parsed.mana.max, added = 0 }
  end
  if parsed.manaOverTime then
    view = view or {}
    view.manaOverTime = { total = parsed.manaOverTime.total, duration = parsed.manaOverTime.duration }
  end
  return view
end

-- What the effect spell of a consumable does as the player's own buff or cast: food ("Restores 59 health over 18 sec. Must
-- remain seated while eating."), a drink (mana over time), a bandage's, a potion's ("Restores 70 to 90 health."): the view
-- ComputeItem makes of the item, read from the spell's own description, which is what the aura on the player carries. nil
-- when the text states no such amount. HealPrediction draws food and drinks while they run (Hots.lua). Remembered for
-- CONSUMABLE_MEMO seconds a spell: it is asked about for every buff the player has, several times a second.
local consumableMemo = {}
local CONSUMABLE_MEMO = 30
function ns._clearConsumables() consumableMemo = {} end
function ns.ComputeConsumable(spellID)
  if isSecret(spellID) or type(spellID) ~= "number" then return nil end
  local now = textClock()
  local memo = consumableMemo[spellID]
  if memo and now - memo.at < CONSUMABLE_MEMO then return memo.view or nil, memo.name end
  local text = getDescription(spellID)
  if not text then
    requestLoad(spellID)
    return nil
  end
  local parsed = Parser.ParseItemHeal(text, ns.DescriptionLang())
  local view = parsed and consumableView(parsed) or nil
  local name = spellName(spellID)
  if consumableMemo[spellID] == nil and next(consumableMemo) ~= nil then
    local count = 0
    for _ in pairs(consumableMemo) do count = count + 1 end
    if count > 300 then consumableMemo = {} end
  end
  consumableMemo[spellID] = { at = now, view = view or false, name = name }
  return view, name
end

function ns.ComputeItem(itemID)
  if isSecret(itemID) or type(itemID) ~= "number" then return nil end
  local spellID = itemUseSpell(itemID)
  local text = spellID and getDescription(spellID) or nil
  if not text then text = itemUseText(itemID) end
  if not text then
    if spellID then requestLoad(spellID) end
    requestItemLoad(itemID)
    return nil
  end
  local parsed = Parser.ParseItemHeal(text, ns.DescriptionLang())
  local fallback
  if not parsed then
    fallback = itemUseText(itemID)
    if fallback then parsed = Parser.ParseItemHeal(fallback, ns.DescriptionLang()) end
  end
  if not parsed then
    local view = poisonView(text)
    if not view then
      fallback = fallback or itemUseText(itemID)
      view = fallback and poisonView(fallback) or nil
    end
    if view then return view end
    return nil
  end
  return consumableView(parsed)
end

-- A seal's Judgement damage, for the seal's own tooltip, or nil.
function ns.SealJudgement(spellID)
  local entry = getEntry(spellID)
  return entry and entry.judgement or nil
end

function ns.IsJudgementSpell(spellID)
  local entry = getEntry(spellID)
  return entry and entry.isJudgement or false
end

-- How much the spell lowers the enemy's damage or attack power (from Parser.ParseReduction), or nil.
function ns.Reduction(spellID)
  local entry = getEntry(spellID)
  return entry and entry.reduction or nil
end

---------------------------------------------------------------------------------------------
-- Action buttons
---------------------------------------------------------------------------------------------

-- Blizzard's action bars on Classic Era and Forever (ActionButtonUtil lists them where it
-- exists); BonusActionButton is the old stance/stealth bar of earlier Classic clients, and
-- MultiCastActionButton Forever's Totem Bar, whose buttons are action buttons that ActionButtonUtil
-- does not list.
local BAR_PREFIXES = {
  "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarLeftButton",
  "MultiBarRightButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "BonusActionButton",
  "MultiCastActionButton", "OverrideActionBarButton",
}

local buttons = {} -- list of Blizzard action buttons
local euiButtons = {} -- EUI's action slot lives in a secure attribute; never read its .action field.
local gamepadButtons, gamepadHosts = {}, {}
local labels = {}  -- [button] = our FontString for the main number
-- [button] = what its labels were last drawn from (text, colours, layout, count, button size, the size and place settings):
-- a refresh that finds the same again leaves the labels alone. Redrawing every button on every refresh (about a dozen
-- client calls a label) was most of what the module cost; a refresh comes up to ten times a second in a fight.
-- Kept here, not on the button: a field written onto an action button from addon code is tainted state on it.
local drawn = setmetatable({}, { __mode = "k" })
local sideLabels = {} -- [button] = our smaller FontString for a reduction next to a damage number

-- Bars built on LibActionButton (Bartender4, ElvUI and others) keep their buttons in the library,
-- one registry per copy (ElvUI ships its own). [button] = true for the ones we draw on.
local labButtons, labHooked, labOwner = {}, {}, {}
local labSeen = false

local function labLibraries()
  local libs = {}
  if type(LibStub) ~= "table" or type(LibStub.IterateLibraries) ~= "function" then return libs end
  local ok, iter, state, key = pcall(LibStub.IterateLibraries, LibStub)
  if not ok or type(iter) ~= "function" then return libs end
  for name, lib in iter, state, key do
    if type(name) == "string" and name:find("^LibActionButton%-1%.0") and type(lib) == "table" then
      libs[#libs + 1] = lib
    end
  end
  return libs
end

local function collectButtons()
  local prefixes, seenPrefix = {}, {}
  local function addPrefix(p)
    if type(p) == "string" and not seenPrefix[p] then
      seenPrefix[p] = true
      prefixes[#prefixes + 1] = p
    end
  end
  if type(ActionButtonUtil) == "table" and type(ActionButtonUtil.ActionBarButtonNames) == "table" then
    for _, p in ipairs(ActionButtonUtil.ActionBarButtonNames) do addPrefix(p) end
  end
  for _, p in ipairs(BAR_PREFIXES) do addPrefix(p) end

  local seen = {}
  for _, b in ipairs(buttons) do seen[b] = true end
  local function add(b)
    if type(b) == "table" and not seen[b] and type(b.CreateFontString) == "function" then
      seen[b] = true
      buttons[#buttons + 1] = b
    end
  end
  for _, prefix in ipairs(prefixes) do
    for i = 1, 12 do
      add(_G[prefix .. i])
    end
  end
  if type(EllesmereUI) == "table" or type(EABButton1) == "table" then
    for i = 1, 180 do
      local b = _G["EABButton" .. i]
      if type(b) == "table" then euiButtons[b] = true; add(b) end
    end
  end
  for _, lib in ipairs(labLibraries()) do
    labSeen = true
    -- GetAllButtons answers a table keyed by button (current versions) or an iterator (older ones); the
    -- library's own registry is the fallback.
    local found
    if type(lib.GetAllButtons) == "function" then
      local ok, result, state, key = pcall(lib.GetAllButtons, lib)
      if ok and type(result) == "table" then
        found = result
      elseif ok and type(result) == "function" then
        found = {}
        for b in result, state, key do found[b] = true end
      end
    end
    if not found and type(lib.buttonRegistry) == "table" then found = lib.buttonRegistry end
    if found then
      for b in pairs(found) do
        if type(b) == "table" and not seen[b] then
          labButtons[b] = true
          add(b)
        end
      end
    end
    -- New buttons and changed contents (a page switch, a drag) ask for a redraw; the work itself
    -- waits for the coalesced timer, so nothing of ours runs inside the library's secure update.
    if not labHooked[lib] and type(lib.RegisterCallback) == "function" then
      labHooked[lib] = true
      local function again() if ns.Refresh then ns.Refresh() end end
      pcall(lib.RegisterCallback, labOwner, "OnButtonCreated", again)
      pcall(lib.RegisterCallback, labOwner, "OnButtonContentsChanged", again)
    end
  end
  -- Forever's native crossbar stores its buttons in page units, outside ActionButton1..12.
  local host = GamepadMainActionBarFrame
  local page = type(host) == "table" and host.PageUnit
  local bars = type(page) == "table" and page.actionBars
  if type(bars) == "table" then
    for _, bar in pairs(bars) do
      if type(bar) == "table" and type(bar.actionButtons) == "table" then
        for _, b in ipairs(bar.actionButtons) do
          if type(b) == "table" and type(b.CalculateAction) == "function" then
            gamepadButtons[b] = true
            add(b)
          end
        end
      end
    end
    if not gamepadHosts[host] then
      local function refresh() if ns.Refresh then ns.Refresh() end end
      -- Keep addon callbacks out of Blizzard's page-change table used by secure gamepad code.
      if type(hooksecurefunc) == "function" and type(page.OnPageChange) == "function" then
        pcall(hooksecurefunc, page, "OnPageChange", refresh)
      end
      if type(host.HookScript) == "function" then pcall(host.HookScript, host, "OnShow", refresh) end
      gamepadHosts[host] = true
    end
  end
end

-- The pet bar: PetActionButton1..10 on Classic Era and Forever (Forever's bar frame is
-- PetActionBar, as on Retail, and lists its buttons in actionButtons). [button] = pet action slot.
local petButtons = {}
local petSlots = {}

local function readID(button)
  if type(button.GetID) ~= "function" then return nil end
  local ok, id = pcall(button.GetID, button)
  if ok and not isSecret(id) and type(id) == "number" and id >= 1 then return id end
  return nil
end

local function collectPetButtons()
  local main = {}
  for _, b in ipairs(buttons) do main[b] = true end
  local function add(b, slot)
    if type(b) == "table" and not petSlots[b] and not main[b] and type(b.CreateFontString) == "function" and slot then
      petSlots[b] = slot
      petButtons[#petButtons + 1] = b
    end
  end
  local n = NUM_PET_ACTION_SLOTS
  if isSecret(n) or type(n) ~= "number" or n < 1 or n > 20 then n = 10 end
  for i = 1, n do
    local b = _G["PetActionButton" .. i]
    if type(b) == "table" then add(b, readID(b) or i) end
  end
  for _, bar in ipairs({ PetActionBar, PetActionBarFrame }) do
    if type(bar) == "table" and type(bar.actionButtons) == "table" then
      for i, b in ipairs(bar.actionButtons) do
        if type(b) == "table" then add(b, readID(b) or i) end
      end
    end
  end
end

-- The number is sized from the button: FONT_SHARE of its height at size 100%, with an outline.
local FONT_SHARE = 0.45
local SIDE_SHARE = 0.75 -- the reduction next to a damage number, relative to the main number
local SIDE_MAX_CHARS = 4 -- "-146", "-10%": longer ones are left out, the damage number wins
local MIN_FONT = 6

local function readNumber(obj, method)
  if type(obj[method]) ~= "function" then return nil end
  local ok, v = pcall(obj[method], obj)
  if ok and not isSecret(v) and type(v) == "number" and v > 0 then return v end
  return nil
end

local function fontFile()
  local obj = NumberFontNormal or NumberFontNormalSmall
  if type(obj) == "table" and type(obj.GetFont) == "function" then
    local ok, file = pcall(obj.GetFont, obj)
    if ok and not isSecret(file) and type(file) == "string" and file ~= "" then return file end
  end
  return "Fonts\\ARIALN.TTF"
end

-- Font size in points for a button: its height (Blizzard buttons are 36, some bars are
-- smaller or scaled), the share, and the size setting.
local function fontSize(button, share)
  local h = readNumber(button, "GetHeight") or 36
  local size = math.floor(h * FONT_SHARE * share * db.size / 100 + 0.5)
  if size < MIN_FONT then size = MIN_FONT end
  return size
end

local fontSizes = {} -- [our FontString] = its current size

local function setFont(fs, size)
  fontSizes[fs] = size
  pcall(fs.SetFont, fs, fontFile(), size, "OUTLINE")
end

-- Shrink the text until it fits inside the button.
local function fitWidth(fs, button, countShown)
  local w = readNumber(button, "GetWidth")
  if not w or type(fs.GetStringWidth) ~= "function" then return end
  local available = w - 2
  if countShown then
    local count = rawget(button, "Count") or rawget(button, "count")
    local countWidth = type(count) == "table" and readNumber(count, "GetStringWidth") or nil
    available = math.max(MIN_FONT, available - (countWidth or 12) - 4)
  end
  local size, initialSize = fontSizes[fs], fontSizes[fs]
  for _ = 1, 10 do
    local sw = readNumber(fs, "GetStringWidth")
    if not sw or sw <= available then return end
    if size <= MIN_FONT then
      if countShown then
        -- A full cost/gain label cannot fit beside a count: put it just above that corner.
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 14)
        setFont(fs, initialSize)
        fitWidth(fs, button, false)
      end
      return
    end
    size = math.max(MIN_FONT, math.min(size - 1, math.floor(size * available / sw)))
    setFont(fs, size)
  end
end

-- Does the button show a count (reagents, charges) in its bottom right corner? Blizzard's buttons
-- draw C_ActionBar.GetActionDisplayCount, "" when there is none; the global GetActionCount exists
-- on Forever and Classic Era only in a deprecation file that loads when a setting asks for it.
local function hasCount(slot)
  if isSecret(slot) or type(slot) ~= "number" then return false end
  local bar = type(C_ActionBar) == "table" and C_ActionBar or nil
  if bar and type(bar.GetActionDisplayCount) == "function" then
    local ok, text = pcall(bar.GetActionDisplayCount, slot)
    if ok and isSecret(text) then return false end
    if ok and type(text) == "string" then return text ~= "" end
  end
  local get = bar and bar.GetActionUseCount
  if type(get) ~= "function" then get = GetActionCount end
  if type(get) ~= "function" then return false end
  local ok, n = pcall(get, slot)
  return ok and not isSecret(n) and type(n) == "number" and n > 0
end

-- Hotkey text is top right and the count bottom right, so the number stays away from the right
-- edge when the count is shown.
local function placeMain(fs, button, countShown)
  fs:ClearAllPoints()
  if db.position == "center" then
    fs:SetPoint("CENTER", button, "CENTER", 0, 0)
    fs:SetJustifyH("CENTER")
  elseif db.position == "top" then
    fs:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    fs:SetJustifyH("LEFT")
  elseif countShown then
    fs:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
    fs:SetJustifyH("LEFT")
  else
    fs:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    fs:SetJustifyH("CENTER")
  end
end

-- The second line's corner. "opposite" keeps today's place: top when the number is not
-- already there. A choice that lands on the number's own end is nudged to the other end,
-- so Drain Life, Life Tap and a reduction never share the hotkey or the item count.
local function sideAnchor()
  local side = db.sidePosition
  if not SIDE_POSITIONS[side] then side = "opposite" end
  local anchor
  if side == "opposite" then
    anchor = (db.position == "top") and "bottom" or "top"
  else
    anchor = side
  end
  if anchor == db.position then
    anchor = (db.position == "top") and "bottom" or "top"
  end
  return anchor
end

local function placeSide(fs, button)
  fs:ClearAllPoints()
  if sideAnchor() == "bottom" then
    fs:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
  else
    fs:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
  end
  fs:SetJustifyH("LEFT")
end

local function newLabel(button)
  local template = NumberFontNormal and "NumberFontNormal" or "GameFontHighlight"
  return button:CreateFontString(nil, "OVERLAY", template)
end

local function getLabel(button)
  local fs = labels[button]
  if not fs then
    fs = newLabel(button)
    labels[button] = fs
  end
  return fs
end

local function getSideLabel(button)
  local fs = sideLabels[button]
  if not fs then
    fs = newLabel(button)
    sideLabels[button] = fs
  end
  return fs
end

local function hide(fs)
  if fs then fs:SetText(""); fs:Hide() end
end

-- BonusActionButton is the main combat bar in forms/stealth on older clients,
-- not the stance selector. Keep its numbers; StanceButton is never collected.
-- Turning pet skip on drops collected buttons and hides their labels.
local function dropListed(list, pred, slots)
  local i = 1
  while list[i] do
    local button = list[i]
    if pred(button) then
      hide(labels[button])
      hide(sideLabels[button])
      drawn[button] = nil
      if slots then slots[button] = nil end
      table.remove(list, i)
    else
      i = i + 1
    end
  end
end

local function recollectButtons()
  collectButtons()
  if db.skipUtilityBars ~= false then
    dropListed(petButtons, function() return true end, petSlots)
  else
    collectPetButtons()
  end
end
ns.RecollectButtons = recollectButtons

local function spellOnSlot(slot)
  if isSecret(slot) or type(slot) ~= "number" or type(GetActionInfo) ~= "function" then return nil end
  local ok, kind, id, sub = pcall(GetActionInfo, slot)
  if not ok or isSecret(kind) or isSecret(id) or isSecret(sub) then return nil end
  if kind == "spell" and type(id) == "number" then return id end
  -- SDI-MACRO: a /cast macro slot reports ("macro", spellID, "spell") - Blizzard reads
  -- the macro's spell from id (ActionButton.lua:1041), so the number belongs on the button.
  if kind == "macro" and sub == "spell" and type(id) == "number" then return id end
  return nil
end
ns.SpellOnSlot = spellOnSlot

-- The item on an action slot (a potion on the bar reports kind "item", a /use
-- macro reports ("macro", itemID, "item") just as a /cast macro reports
-- ("macro", spellID, "spell") above), or nil for anything else or anything the
-- client hides. Mirrors spellOnSlot: the raw values are guarded with
-- issecretvalue before any comparison.
local function itemOnSlot(slot)
  if isSecret(slot) or type(slot) ~= "number" or type(GetActionInfo) ~= "function" then return nil end
  local ok, kind, id, sub = pcall(GetActionInfo, slot)
  if not ok or isSecret(kind) or isSecret(id) or isSecret(sub) then return nil end
  if kind == "item" and type(id) == "number" then return id end
  -- SDI-MACRO-ITEM: a /use macro's item, same slot shape as /cast above.
  if kind == "macro" and sub == "item" and type(id) == "number" then return id end
  return nil
end
ns.ItemOnSlot = itemOnSlot

-- The spell on a pet action slot, or nil for an empty slot, a command (Attack, Follow, Stay and
-- the stances are tokens) or anything the client hides. GetPetActionInfo returns name, texture,
-- isToken, isActive, autoCastAllowed, autoCastEnabled, spellID.
local function petSpellOnSlot(slot)
  if isSecret(slot) or type(slot) ~= "number" or type(GetPetActionInfo) ~= "function" then return nil end
  local ok, name, _, isToken, _, _, _, spellID = pcall(GetPetActionInfo, slot)
  if not ok or isSecret(name) or name == nil or isSecret(isToken) or isToken then return nil end
  if isSecret(spellID) or type(spellID) ~= "number" or spellID <= 0 then return nil end
  return spellID
end
ns.PetSpellOnSlot = petSpellOnSlot

-- The view with the kinds of number the player switched off (Options: the "Show" checkboxes) taken away. A view is
-- only copied when something has to go; what is left decides the layout, so a spell with damage and healing whose
-- healing is off is an ordinary damage button, and nothing left means no number.
local function filterView(view)
  if not view then return nil end
  local off = {}
  local any = false
  for _, key in ipairs(SHOW_KEYS) do
    if db[key] == false then off[key], any = true, true end
  end
  if not any then return view end
  local v = {}
  for k, x in pairs(view) do v[k] = x end
  if off.showDamage then v.direct = nil end
  if off.showDot then v.dot = nil end
  if off.showHeal then v.heal = nil end
  if off.showHot then v.hot, v.hp5 = nil, nil end
  if off.showMana then v.mana, v.manaOverTime, v.manaPercent, v.manaGain = nil, nil, nil, nil end
  if off.showAbsorb then v.absorb = nil end
  -- A share of maximum health (the maximum is hidden in combat) is a heal, or a heal over time when it has a duration.
  if v.healPercent and ((v.duration and off.showHot) or (not v.duration and off.showHeal)) then
    v.healPercent, v.directPercent, v.duration, v.percentSelfHeal = nil, nil, nil, nil
  end
  -- A finisher's number is the damage (or the damage over time) of its row; with that kind off it has nothing to say
  -- either, not even the "?" for a combo count the client cannot read.
  if v.finisher and ((v.finisher.kind == "dot" and off.showDot) or (v.finisher.kind ~= "dot" and off.showDamage)) then
    return nil
  end
  -- The two ends of a transfer (Drain Life) only mean something together.
  if v.transfer and not ((v.direct or v.dot) and (v.heal or v.hot)) then v.transfer = nil end
  return v
end

-- The "per second" number on the buttons (setting button = "dps"): the view with its amounts turned into rates, which the
-- ordinary "total" arithmetic then adds up. What lands at once (direct damage, a heal) is spread over the time the cast
-- takes, at least the global cooldown (1.5 s; 1 s for energy users: rogues, cats), because that is the time it costs in
-- a rotation; damage, healing and mana over time (a DoT, a HoT, food, a drink, a bandage) are spread over their own
-- duration. Only views of spells carry a castTime (Compute stamps it), so an item's instant amount (a potion), a weapon
-- hit or a shield stays what it is.
local function dpsView(view)
  if not view then return view end
  local v = {}
  for k, x in pairs(view) do v[k] = x end
  if view.castTime ~= nil then
    local gcd = 1.5
    if type(UnitPowerType) == "function" then
      local ok, powerType = pcall(UnitPowerType, "player")
      if ok and not isSecret(powerType) and powerType == 3 then gcd = 1 end
    end
    local window = math.max(view.castTime, gcd)
    for _, key in ipairs({ "direct", "heal" }) do
      local r = view[key]
      if r then v[key] = { min = r.min / window, max = r.max / window, added = (r.added or 0) / window } end
    end
  end
  for _, key in ipairs({ "dot", "hot", "manaOverTime" }) do
    local p = view[key]
    -- a figure without a duration (a tick on its own) cannot be turned into a rate
    if p and p.duration and p.duration > 0 then
      v[key] = { total = p.total / p.duration, duration = p.duration, added = (p.added or 0) / p.duration }
    end
  end
  return v
end

-- A number for a button: Format.Short, except that in "per second" mode a rate under 10 keeps one decimal (food heals
-- 3.2 a second, and "3" would hide that).
local function short(value)
  if db.button == "dps" then
    local r = math.floor(value * 10 + 0.5) / 10
    if r < 10 then return string.format("%.1f", r) end
  end
  return Format.Short(value)
end

-- The text on a button for a view from ns.Compute and a reduction from ns.Reduction (either may
-- be nil), under the current settings: main text, its colour, and the smaller reduction text
-- next to it (or nil). The options window's preview draws its sample spells through this too.
local function buttonTextOf(view, reduction)
  if db.button == "off" then return nil end
  if view and view.healPercent then
    local percent = view.healPercent
    if view.duration and db.button == "direct" then
      if not view.directPercent then return nil end
      percent = view.directPercent
    end
    local fallback = tostring(percent) .. "% HP"
    if view.percentSelfHeal then
      local damage, kind = Estimate.ButtonValue(view, db.button)
      if kind == "damage" and damage and damage >= 0.5 then
        return short(damage), Format.DAMAGE_COLOR, "+" .. fallback, Format.HEAL_COLOR
      end
    end
    return fallback, Format.HEAL_COLOR
  end
  -- A drink's percentage while the mana maximum is hidden: the stated share, in mana blue.
  if view and view.manaPercent and not (view.hot or view.heal or view.healPercent) then
    if view.duration and db.button == "direct" then return nil end
    return tostring(view.manaPercent) .. "% mana", Format.WEAPON_COLOR
  end
  -- Life Tap: vertical dual-label, green -HP on top, blue +mana below.
  if view and view.healthCost then
    local mainText = "-" .. Format.Short(view.healthCost) .. " HP"
    local sideText
    if view.manaGain and view.manaGain >= 0.5 then
      sideText = "+" .. Format.Short(view.manaGain) .. " mana"
    end
    -- Health Funnel: the same cost, but it goes to the pet, so it is a red cost, not a heal
    local mainColor = view.petHeal and Format.REDUCTION_COLOR or Format.HEAL_COLOR
    return mainText, mainColor, sideText, Format.WEAPON_COLOR, "stacked"
  end
  -- Food that is also a drink: the health total in green above the mana total in blue.
  if view and view.manaOverTime and view.hot and db.button ~= "direct"
      and view.hot.total >= 0.5 and view.manaOverTime.total >= 0.5 then
    return short(view.hot.total), Format.HEAL_COLOR,
      short(view.manaOverTime.total), Format.WEAPON_COLOR, "stacked"
  end
  -- Two stacked labels: damage in gold, healing in green. Only simultaneous self-heals get "+".
  if view and (view.transfer or view.percentSelfHeal
      or ((view.direct or view.dot) and (view.heal or view.hot))) then
    local value = Estimate.ButtonValue(view, db.button)
    if value and value >= 0.5 then
      local healValue
      if db.button == "direct" then
        if view.heal then healValue = (view.heal.min + view.heal.max) / 2 end
      else
        healValue = (view.hot and view.hot.total or 0) + (view.heal and (view.heal.min + view.heal.max) / 2 or 0)
      end
      local prefix = (view.transfer or view.percentSelfHeal) and "+" or ""
      local sideText = (healValue and healValue >= 0.5) and (prefix .. short(healValue)) or nil
      return short(value), Format.DAMAGE_COLOR, sideText, Format.HEAL_COLOR, "stacked"
    end
  end
  if not db.reduction then reduction = nil end
  local value, kind = Estimate.ButtonValue(view, db.button)
  if value and value < 0.5 then value = nil end

  local mainText, mainColor, sideText
  local w = view and view.weapon
  if w then
    value = w.gain or w.value
    if value and value < 0.5 then value = nil end
  end
  if value and w then
    mainText = (w.gain and "+" or "") .. Format.Short(value)
    mainColor = Format.WEAPON_COLOR
    if reduction then
      local perHit = ns.ReductionPerHit(reduction)
      local t = perHit and Format.ReductionText(reduction, ns.L, perHit) or Format.ReductionAmount(reduction, ns.L)
      if #t <= SIDE_MAX_CHARS then sideText = t end
    end
  elseif value then
    mainText = short(value)
    -- Mana consumables read in the established mana blue (Life Tap's +mana);
    -- healing stays green, damage stays gold.
    if kind == "heal" then mainColor = Format.HEAL_COLOR
    elseif kind == "mana" then mainColor = Format.WEAPON_COLOR
    else mainColor = Format.DAMAGE_COLOR end
    if reduction then
      -- the small red number beside the damage: per hit where the target's speed is known, else the
      -- amount alone ("-100 AP" does not fit there)
      local perHit = ns.ReductionPerHit(reduction)
      local t = perHit and Format.ReductionText(reduction, ns.L, perHit) or Format.ReductionAmount(reduction, ns.L)
      if #t <= SIDE_MAX_CHARS then sideText = t end
    end
  elseif view and view.absorb and view.absorb >= 0.5 then
    mainText = Format.Short(view.absorb)
    mainColor = Format.ABSORB_COLOR
  elseif view and view.finisher and view.finisherAt and not view.finisherAt.known then
    -- the combo count the client cannot say: a neutral placeholder, never a precise amount
    mainText = "?"
    mainColor = Format.NOTE_COLOR
  elseif view and view.hp5 then
    -- Demon Skin's regeneration: "+5 HP/5s", green like healing
    mainText = "+" .. Format.Short(view.hp5) .. " " .. (ns.L.HP5 or "HP/5s")
    mainColor = Format.HEAL_COLOR
  elseif reduction then
    mainText = Format.ReductionText(reduction, ns.L, ns.ReductionPerHit(reduction))
    mainColor = Format.REDUCTION_COLOR
  end
  return mainText, mainColor, sideText
end

-- Filters the view by the "Show" checkboxes, then draws it; an average of past casts (History.lua) is marked with "~".
local function buttonText(view, reduction)
  view = filterView(view)
  if db.button == "dps" then view = dpsView(view) end
  local mainText, mainColor, sideText, sideColor, layout = buttonTextOf(view, reduction)
  if mainText and view and view.history then
    mainText = "~" .. mainText
    if sideText and layout == "stacked" then sideText = "~" .. sideText end
  end
  return mainText, mainColor, sideText, sideColor, layout
end
ns.ButtonText = buttonText

-- Life Tap has two full labels, not a small reduction in the opposite corner. Keep both
-- below the hotkey even at 200% size; the health cost is always above the mana gained.
local function drawStacked(button, fs, side, mainText, mainColor, sideText, sideColor, countShown)
  local h = readNumber(button, "GetHeight") or 36
  local size = math.min(fontSize(button, SIDE_SHARE), math.max(MIN_FONT, math.floor((h - 18) / 2)))
  placeMain(fs, button, countShown)
  setFont(fs, size)
  fs:SetTextColor(mainColor[1], mainColor[2], mainColor[3])
  fs:SetText(mainText)
  fitWidth(fs, button, countShown and db.position == "bottom")
  fs:Show()
  if side and sideText then
    placeSide(side, button)
    setFont(side, size)
    local c = sideColor or Format.WEAPON_COLOR
    side:SetTextColor(c[1], c[2], c[3])
    side:SetText(sideText)
    fitWidth(side, button, countShown and sideAnchor() == "bottom")
    side:Show()
  else
    hide(side)
  end
end

-- Draws the text from buttonText on a button: fs is the main FontString, side the reduction's
-- (may be nil when there is no sideText). countShown: the button shows a count bottom right.
local function drawNumber(button, fs, side, mainText, mainColor, sideText, countShown, sideColor, layout)
  if not mainText then
    hide(fs)
    hide(side)
    return
  end
  if layout == "stacked" then
    drawStacked(button, fs, side, mainText, mainColor, sideText, sideColor, countShown)
    return
  end
  placeMain(fs, button, countShown)
  setFont(fs, fontSize(button, 1))
  fs:SetTextColor(mainColor[1], mainColor[2], mainColor[3])
  fs:SetText(mainText)
  fitWidth(fs, button, countShown and db.position == "bottom")
  fs:Show()

  if sideText and side then
    placeSide(side, button)
    setFont(side, fontSize(button, SIDE_SHARE))
    local c = sideColor or Format.REDUCTION_COLOR
    side:SetTextColor(c[1], c[2], c[3])
    side:SetText(sideText)
    fitWidth(side, button, countShown and sideAnchor() == "bottom")
    side:Show()
  else
    hide(side)
  end
end
ns.DrawNumber = drawNumber
ns.NewLabel = newLabel

-- Spells on the bars that give no number at all, each kept once, so the player's own client
-- can say which wordings are still not read (/sdi misses). Kept in the saved variables and
-- capped; /sdi misses clear empties the list. Utility spells land here too, which is fine:
-- the list is read by a person.
local MISSES_MAX = 200
local missSeen, missCount = {}, 0

local function noteMiss(spellID)
  if missSeen[spellID] or missCount >= MISSES_MAX or type(db.misses) ~= "table" then return end
  local entry = parsedCache[spellID]
  -- a seal with nothing per hit shows nothing on purpose: its Judgement is on Judgement's button
  if not entry or entry.show or entry.reduction or entry.isSeal then return end
  missSeen[spellID] = true
  missCount = missCount + 1
  local build
  if type(GetBuildInfo) == "function" then
    local ok, _, b = pcall(GetBuildInfo)
    if ok and not isSecret(b) then build = b end
  end
  db.misses[#db.misses + 1] = { id = spellID, name = spellName(spellID), text = entry.text,
    lang = ns.DescriptionLang(), build = build, unread = entry.unread, reason = entry.reason }
end

-- /sdi dump: every spell in the player's spellbook, with the description as this client shows
-- it and what the addon reads from it, into the saved variables (db.dump). Written to disk at
-- the next logout or /reload; for testing the parser against the game's own texts rather than
-- a website's. Spells whose text has not loaded yet are asked for and counted as missing: a
-- second /sdi dump a moment later has them. /sdi dump all does the same for every rank of every
-- class ability (SpellIDs.lua), known or not, into db.dumpAll: one character gives the client's
-- texts for all nine classes. The client holds only the player's own class's spells; the rest
-- arrive over the next seconds after they are asked for, so dump all reads again every 2 seconds
-- until no more arrive (ns.DumpAll).
local function spellbookIDs()
  local ids = {}
  if C_SpellBook and type(C_SpellBook.GetNumSpellBookSkillLines) == "function" then
    local bank = (type(Enum) == "table" and type(Enum.SpellBookSpellBank) == "table" and Enum.SpellBookSpellBank.Player) or 0
    local okN, n = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    n = okN and not isSecret(n) and type(n) == "number" and n or 0
    for line = 1, n do
      local ok, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
      if ok and type(info) == "table" and type(info.itemIndexOffset) == "number" and type(info.numSpellBookItems) == "number" then
        for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
          local ok2, item = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
          if ok2 and type(item) == "table" and not isSecret(item.spellID) and type(item.spellID) == "number" then
            ids[#ids + 1] = item.spellID
          end
        end
      end
    end
  elseif type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function" and type(GetSpellBookItemInfo) == "function" then
    local okN, tabs = pcall(GetNumSpellTabs)
    for tab = 1, (okN and type(tabs) == "number" and tabs or 0) do
      local ok, _, _, offset, count = pcall(GetSpellTabInfo, tab)
      if ok and type(offset) == "number" and type(count) == "number" then
        for i = offset + 1, offset + count do
          local ok2, kind, id = pcall(GetSpellBookItemInfo, i, "spell")
          if ok2 and kind == "SPELL" and type(id) == "number" then ids[#ids + 1] = id end
        end
      end
    end
  end
  return ids
end

local function readsAs(entry)
  local parts = { "show=" .. tostring(entry.show), "lang=" .. tostring(entry.lang) }
  for _, k in ipairs({ "parsed", "reduction", "weapon", "special", "finisher", "judgement" }) do
    if entry[k] then parts[#parts + 1] = k end
  end
  if entry.isSeal then parts[#parts + 1] = "seal" end
  if entry.isJudgement then parts[#parts + 1] = "judgement-spell" end
  if entry.proc then parts[#parts + 1] = "proc=" .. tostring(entry.proc) end
  if entry.unread then parts[#parts + 1] = entry.unread .. ":" .. tostring(entry.reason) end
  return #parts > 0 and table.concat(parts, ",") or "nothing"
end

function ns.Dump(all)
  local build
  if type(GetBuildInfo) == "function" then
    local ok, v, b = pcall(GetBuildInfo)
    if ok and not isSecret(b) then build = tostring(v) .. "." .. tostring(b) end
  end
  local lang = ns.DescriptionLang()
  local out = { build = build, lang = lang, class = weaponStats.class, spells = {}, missing = 0 }
  local ids = {}
  if all then
    for id in string.gmatch(ns.AllSpellIDs or "", "%d+") do ids[#ids + 1] = tonumber(id) end
  else
    ids = spellbookIDs()
  end
  local seen = {}
  for _, id in ipairs(ids) do
    if not seen[id] then
      seen[id] = true
      -- read here rather than through getEntry: most of these are never on a button
      local text = getDescription(id)
      if text then
        local entry = Parser.Read(text, lang, isRetail())
        out.spells[#out.spells + 1] = { id = id, name = spellName(id), text = text, reads = readsAs(entry) }
      else
        -- asked again on every pass of dump all: a request the client dropped is not remembered
        if all and C_Spell and type(C_Spell.RequestLoadSpellData) == "function" then
          pcall(C_Spell.RequestLoadSpellData, id)
        else
          requestLoad(id)
        end
        out.missing = out.missing + 1
      end
    end
  end
  if all then db.dumpAll = out else db.dump = out end
  return out
end

-- /sdi dump items: every item with a use effect in the bags and on the action bars, with its
-- use spell's description, its own "Use:" line and what the addon reads from them, into the
-- saved variables (db.dumpItems). The item wordings (food, drinks, potions, bandages) differ
-- from spell wordings and from one client language to the next; this is how they get reported.
function ns.DumpItems()
  local lang = ns.DescriptionLang()
  local out = { lang = lang, items = {}, missing = 0 }
  local seen = {}
  local function add(itemID)
    if isSecret(itemID) or type(itemID) ~= "number" or seen[itemID] then return end
    seen[itemID] = true
    local spellID = itemUseSpell(itemID)
    local spellText = spellID and getDescription(spellID) or nil
    local useText = itemUseText(itemID)
    if not spellID and not useText then return end -- nothing to use, or not loaded at all yet
    if not spellText and not useText then
      requestLoad(spellID)
      requestItemLoad(itemID)
      out.missing = out.missing + 1
      return
    end
    local parsed, reason = Parser.ParseItemHeal(spellText or useText, lang)
    if not parsed and spellText and useText then parsed, reason = Parser.ParseItemHeal(useText, lang) end
    local reads
    if parsed then
      local keys = {}
      for k in pairs(parsed) do keys[#keys + 1] = tostring(k) end
      table.sort(keys)
      reads = table.concat(keys, ",")
    else
      reads = "unread:" .. tostring(reason)
    end
    local name
    if C_Item and type(C_Item.GetItemNameByID) == "function" then
      local ok, n = pcall(C_Item.GetItemNameByID, itemID)
      if ok and not isSecret(n) and type(n) == "string" then name = n end
    end
    out.items[#out.items + 1] = { id = itemID, name = name, spell = spellID, spellText = spellText,
      useText = useText, reads = reads }
  end
  local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local slotItem = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
  if type(numSlots) == "function" and type(slotItem) == "function" then
    for bag = 0, 4 do
      local ok, n = pcall(numSlots, bag)
      n = ok and not isSecret(n) and type(n) == "number" and n or 0
      for slot = 1, n do
        local ok2, id = pcall(slotItem, bag, slot)
        if ok2 then add(id) end
      end
    end
  end
  for slot = 1, 180 do add(ns.ItemOnSlot(slot)) end
  db.dumpItems = out
  return out
end

-- /sdi dump all: a pass every 2 seconds while spells keep arriving, at most 30; stops after three
-- passes that bring nothing new (spells the client does not have never arrive). Each pass writes
-- db.dumpAll, so a /reload in between keeps what was read so far. done(list) is called once.
local dumpAllRun = 0
function ns.DumpAll(done)
  dumpAllRun = dumpAllRun + 1
  local run = dumpAllRun
  local passes, still, last = 0, 0, nil
  local function pass()
    if run ~= dumpAllRun then return end -- a newer dump all took over
    passes = passes + 1
    local list = ns.Dump(true)
    if last and list.missing >= last then still = still + 1 else still = 0 end
    last = list.missing
    local timer = C_Timer and type(C_Timer.After) == "function"
    if list.missing == 0 or still >= 3 or passes >= 30 or not timer then
      done(list)
      return
    end
    C_Timer.After(2, pass)
  end
  pass()
end

-- A Blizzard button's action slot: its action field, or, where the client keeps that out of reach, what the
-- button itself calculates (the way the gamepad bar's buttons are read).
local function slotOf(button)
  local slot = button.action
  if not isSecret(slot) and type(slot) == "number" and slot > 0 then return slot end
  if type(button.CalculateAction) == "function" then
    local ok, value = pcall(button.CalculateAction, button)
    if ok and not isSecret(value) and type(value) == "number" and value > 0 then return value end
  end
  if isSecret(slot) then return nil end
  return slot
end

-- What a LibActionButton button holds in its current state: an action slot (read like Blizzard's),
-- or a spell, macro or item of its own that has no slot. Returns slot, spellID, itemID, countShown.
local function labContent(button)
  if type(button.GetAction) ~= "function" then return nil end
  local ok, kind, action = pcall(button.GetAction, button)
  if not ok or isSecret(kind) or isSecret(action) then return nil end
  if kind == "action" then
    if type(action) == "number" and action > 0 then return action end
  elseif kind == "spell" then
    if type(action) == "number" then return nil, action end
  elseif kind == "macro" then
    if type(action) == "number" and type(GetMacroSpell) == "function" then
      local okm, id = pcall(GetMacroSpell, action)
      if okm and not isSecret(id) and type(id) == "number" then return nil, id end
    end
  elseif kind == "item" then
    local id = action
    if type(id) == "string" then id = tonumber(id) or tonumber(id:match("item:(%d+)")) end
    if type(id) == "number" then
      local get = type(C_Item) == "table" and C_Item.GetItemCount or GetItemCount
      local okc, n = false, nil
      if type(get) == "function" then okc, n = pcall(get, id) end
      return nil, nil, id, okc and not isSecret(n) and type(n) == "number" and n > 1
    end
  end
  return nil
end

local function updateButton(button, pet)
  local view, reduction
  local slot, labSpell, labItem, labCount
  if not pet then
    if gamepadButtons[button] then
      local ok, value = pcall(button.CalculateAction, button)
      if ok and not isSecret(value) then slot = value end
    elseif euiButtons[button] then
      local ok, value = pcall(button.GetAttribute, button, "action")
      if ok and not isSecret(value) and type(value) == "number" and value > 0 then slot = value end
    elseif labButtons[button] then slot, labSpell, labItem, labCount = labContent(button)
    else slot = slotOf(button) end
  end
  if db.button ~= "off" then
    local spellID
    if pet then spellID = petSpellOnSlot(petSlots[button]) else spellID = labSpell or spellOnSlot(slot) end
    if spellID then
      view = ns.ComputeOrAverage(spellID, pet)
      if db.reduction then reduction = ns.Reduction(spellID) end
      noteMiss(spellID)
    elseif not pet then
      -- SDI-ITEM-HEAL: a consumable on the bar (kind "item", or a /use macro):
      -- its raw healing, bandage total or mana, through the same button text
      -- as spells (Format.Short; healing green, mana blue). No reduction
      -- and no miss tracking: those read spell wordings only.
      local itemID = labItem or itemOnSlot(slot)
      if itemID then view = ns.ComputeItem(itemID) end
    end
  end
  local mainText, mainColor, sideText, sideColor, layout = buttonText(view, reduction)
  local d = drawn[button]
  if not d then
    d = {}
    drawn[button] = d
  end
  if not mainText then
    if d.blank then return end -- already hidden
    d.blank = true
    hide(labels[button])
    hide(sideLabels[button])
    return
  end
  local countShown = (not pet and (labCount or hasCount(slot))) and true or false
  local width, height = readNumber(button, "GetWidth"), readNumber(button, "GetHeight")
  if not d.blank and d.main == mainText and d.color == mainColor and d.side == sideText and d.sideColor == sideColor
    and d.layout == layout and d.count == countShown and d.width == width and d.height == height
    and d.size == db.size and d.position == db.position and d.sidePosition == db.sidePosition then
    return -- the labels already show this
  end
  d.blank, d.main, d.color, d.side, d.sideColor, d.layout = false, mainText, mainColor, sideText, sideColor, layout
  d.count, d.width, d.height, d.size, d.position, d.sidePosition = countShown, width, height, db.size, db.position, db.sidePosition
  local side = sideText and getSideLabel(button) or sideLabels[button]
  drawNumber(button, getLabel(button), side, mainText, mainColor, sideText, countShown, sideColor, layout)
end

-- A refresh walks every button (a hundred on a full set of bars: the character's own bars and the crossbar's pages) and took
-- 5 ms on average, 17 at worst, which is a dropped frame. It now spends at most SLICE_MS at a time and goes on in the next
-- frame from the button it stopped at. Returns true while buttons are left.
local SLICE_MS = 3
local sliceFrom = 1
local function updateAllButtons()
  local main = #buttons
  local total = main + #petButtons
  local started = clock and clock()
  local i = sliceFrom
  if i > total then i = 1 end
  while i <= total do
    if i <= main then updateButton(buttons[i], false) else updateButton(petButtons[i - main], true) end
    i = i + 1
    if started and i <= total and clock() - started >= SLICE_MS then
      sliceFrom = i
      return true
    end
  end
  sliceFrom = 1
  return false
end

-- /sdi buttons: what the number on each collected button was made from (for a bar that shows none).
function ns.DescribeButtons(out)
  local lab, plainCount = 0, 0
  for _, b in ipairs(buttons) do
    if labButtons[b] then lab = lab + 1 else plainCount = plainCount + 1 end
  end
  out(string.format("%d buttons (%d Blizzard/other, %d LibActionButton), %d pet; button mode %s, position %s",
    #buttons, plainCount, lab, #petButtons, tostring(db.button), tostring(db.position)))
  local shown = 0
  for _, b in ipairs(buttons) do
    local slot, labSpell, labItem
    if gamepadButtons[b] then
      local ok, value = pcall(b.CalculateAction, b)
      if ok and not isSecret(value) then slot = value end
    elseif euiButtons[b] then
      local ok, value = pcall(b.GetAttribute, b, "action")
      if ok and not isSecret(value) then slot = value end
    elseif labButtons[b] then slot, labSpell, labItem = labContent(b)
    else slot = slotOf(b) end
    local spellID = labSpell or spellOnSlot(slot)
    local name = "?"
    if type(b.GetName) == "function" then
      local ok, n = pcall(b.GetName, b)
      if ok and not isSecret(n) and n then name = tostring(n) end
    end
    local fs = labels[b]
    if spellID or labItem or (slot and shown < 6) then
      shown = shown + 1
      local view = spellID and ns.Compute(spellID, false) or nil
      local value, kind = Estimate.ButtonValue(view, db.button)
      local raw = ""
      if slot and type(GetActionInfo) == "function" then
        local ok, kindA, idA = pcall(GetActionInfo, slot)
        if ok and not isSecret(kindA) and not isSecret(idA) then raw = tostring(kindA) .. ":" .. tostring(idA) end
      end
      local okV, btnVisible = pcall(b.IsVisible, b)
      out(string.format("%s slot=%s action=%s spell=%s value=%s label=%s%s button=%s", name, tostring(slot), raw,
        tostring(spellID), value and string.format("%.0f %s", value, tostring(kind)) or "none",
        fs and ("'" .. tostring(fs:GetText()) .. "'") or "none", (fs and fs:IsShown()) and " shown" or " hidden",
        (okV and not isSecret(btnVisible)) and (btnVisible and "visible" or "HIDDEN") or "?"))
    end
    if shown >= 14 then break end
  end
  -- Where the first number really is: font, size, alpha, rectangle and layer of the label and its button.
  for _, b in ipairs(buttons) do
    local fs = labels[b]
    if fs and fs:IsShown() then
      local function plainCall(obj, method, ...)
        local ok, a1, a2, a3, a4 = pcall(obj[method], obj, ...)
        if not ok or isSecret(a1) then return "?" end
        local parts = {}
        for _, v in ipairs({ a1, a2, a3, a4 }) do
          if v ~= nil and not isSecret(v) then
            parts[#parts + 1] = type(v) == "number" and string.format("%.1f", v) or tostring(v)
          end
        end
        return table.concat(parts, ",")
      end
      out(string.format("first label: font=%s alpha=%s effAlpha=%s visible=%s size=%sx%s layer=%s",
        plainCall(fs, "GetFont"), plainCall(fs, "GetAlpha"), plainCall(fs, "GetEffectiveAlpha"),
        plainCall(fs, "IsVisible"), plainCall(fs, "GetWidth"), plainCall(fs, "GetHeight"),
        plainCall(fs, "GetDrawLayer")))
      out(string.format("  label center=%s | button center=%s size=%sx%s level=%s strata=%s scale=%s effScale=%s",
        plainCall(fs, "GetCenter"), plainCall(b, "GetCenter"), plainCall(b, "GetWidth"), plainCall(b, "GetHeight"),
        plainCall(b, "GetFrameLevel"), plainCall(b, "GetFrameStrata"), plainCall(b, "GetScale"),
        plainCall(b, "GetEffectiveScale")))
      out(string.format("  text color=%s", plainCall(fs, "GetTextColor")))
      break
    end
  end
end

-- /sdi where: after 4 seconds, which frame the mouse is over (point at an action button first), its chain of
-- parents, and whether this module has a number on it.
function ns.DescribeMouseFrame(out)
  out("Point the mouse at the action button now; reading in 4 seconds.")
  local function read()
    local focus
    if type(GetMouseFoci) == "function" then
      local ok, foci = pcall(GetMouseFoci)
      focus = ok and type(foci) == "table" and foci[1] or nil
    elseif type(GetMouseFocus) == "function" then
      local ok, f = pcall(GetMouseFocus)
      focus = ok and f or nil
    end
    if type(focus) ~= "table" then out("No frame under the mouse.") return end
    local function nameOf(f)
      if type(f) ~= "table" or type(f.GetDebugName) ~= "function" then return "?" end
      local ok, n = pcall(f.GetDebugName, f)
      return (ok and not isSecret(n) and n) and tostring(n) or "(unnamed)"
    end
    local chain, cur = {}, focus
    for _ = 1, 5 do
      chain[#chain + 1] = nameOf(cur)
      local ok, parent = pcall(cur.GetParent, cur)
      if not ok or type(parent) ~= "table" or parent == UIParent then break end
      cur = parent
    end
    out("mouse frame: " .. table.concat(chain, " < "))
    local found
    for _, b in ipairs(buttons) do
      local cur2 = focus
      for _ = 1, 4 do
        if cur2 == b then found = b break end
        local ok, parent = pcall(cur2.GetParent, cur2)
        if not ok or type(parent) ~= "table" then break end
        cur2 = parent
      end
      if found then break end
    end
    if found then
      local fs = labels[found]
      out("collected button " .. nameOf(found) .. " label=" .. (fs and ("'" .. tostring(fs:GetText()) .. "'" ..
        (fs:IsShown() and " shown" or " hidden")) or "none"))
    else
      out("this frame is NOT one of the collected buttons: its action field is " .. tostring(rawget(focus, "action")))
      for _, key in ipairs({ "action", "buttonType", "CalculateAction", "GetAction" }) do
        out("  field " .. key .. " = " .. type(focus[key]) .. " " .. ((type(focus[key]) == "number" or type(focus[key]) == "string") and tostring(focus[key]) or ""))
      end
    end
  end
  if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(4, read) else read() end
end

local pending = false
-- Bars that appear later (EUI, LibActionButton bars, Forever's crossbar) are looked for again at most this often, or at
-- once when an event says the bars changed (collectDue). It used to run before every refresh: a scan of every button
-- name of every bar, the libraries and the crossbar's pages, several times a second.
local COLLECT_EVERY = 1.5
local collectDue, lastCollect = true, -100
-- Two refreshes are at least this far apart: the events that ask for one (every aura change, every cast, every
-- power or attack power tick of the player) came in bursts, and each refresh walks every button.
local REFRESH_GAP = 0.25
local lastRun = -100
local continuing = false -- a refresh was cut into slices and has buttons left
local again = false      -- a request that came in while it was being sliced: another full refresh follows it
local deferred = false   -- a text was left unread in some slice (parse budget): read on the next refresh
local run, requestUpdate
local function schedule(delay)
  if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(delay, run) else run() end
end
run = function()
  pending = false
  lastRun = textClock()
  local runStart = BIT.Perf and BIT.Perf.Begin()
  if not continuing then
    -- EUI can create additional bars after login or defer them until combat ends.
    if type(EllesmereUI) == "table" or type(EABButton1) == "table"
      or type(GamepadMainActionBarFrame) == "table" or labSeen then
      if collectDue or lastRun - lastCollect >= COLLECT_EVERY then
        collectDue, lastCollect = false, lastRun
        local t0 = BIT.Perf and BIT.Perf.Begin()
        collectButtons()
        if BIT.Perf then BIT.Perf.End("SpellDamageInfo.collect", t0) end
      end
    end
    readBonus()
    readWeapon()
  end
  parseBudget, parseDeferred = PARSE_BUDGET, false
  local t1 = BIT.Perf and BIT.Perf.Begin()
  continuing = updateAllButtons()
  if BIT.Perf then BIT.Perf.End("SpellDamageInfo.buttons", t1) end
  parseBudget = nil
  if parseDeferred then deferred = true end
  if BIT.Perf then BIT.Perf.End("SpellDamageInfo.refresh", runStart) end
  if continuing then
    pending = true
    schedule(0) -- the next frame
  elseif again or deferred then
    again, deferred = false, false
    requestUpdate()
  end
end
requestUpdate = function()
  if continuing then again = true end
  if pending then return end
  pending = true
  -- A short delay lets Blizzard's own handlers set button.action after a page change first.
  schedule(math.max(0.1, REFRESH_GAP - (textClock() - lastRun)))
end
ns.Refresh = requestUpdate

---------------------------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------------------------

-- The lines we added to each tooltip, so a combo change can rewrite them in place (never
-- append a second set): [tooltip] = { spellID = id, rows = the indices our rows occupy }.
-- AddLine documents no return (blank wowless binding), so no row handles are kept: the owned
-- rows are found back by index through the documented GetLeftLine accessor and rewritten
-- with SetText/SetTextColor, which never deletes a row and never touches rows that other
-- addons put there. New rows grow the set by an AddLine at the end; surplus rows are blanked,
-- not deleted. A native rebuild (ClearLines) drops the bookkeeping through OnTooltipCleared,
-- so nothing stale is rewritten or hidden later.
local tooltipLines = {}
local tooltipClearedHooked = {}
-- A pet action tooltip can reach us twice: through a tooltip data post-call (on clients that
-- build tooltips from data, and again when the tooltip refreshes) and through the SetPetAction
-- hook right after it. The post-call marks the tooltip so the hook does not add the lines again.
local petLinesDone = {} -- [tooltip] = true

-- Forget our rows when the native content of a tooltip is rebuilt (ClearLines fires
-- OnTooltipCleared; the rows we added are gone with it), and drop a SetPetAction
-- duplicate mark the same way the hookTooltips handler below would.
local function forgetRowsOnClear(tooltip)
  if tooltipClearedHooked[tooltip] or type(tooltip.HookScript) ~= "function" then return end
  tooltipClearedHooked[tooltip] = true
  pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", function(t)
    tooltipLines[t] = nil
    petLinesDone[t] = nil
  end)
end

-- The rows a tooltip holds right now, when the client numbers them.
local function rowsBefore(tooltip)
  if type(tooltip.NumLines) ~= "function" then return nil end
  local ok, n = pcall(tooltip.NumLines, tooltip)
  if not ok or type(n) ~= "number" then return nil end
  return n
end

-- Rewrite the rows we added before (their indices are prev.rows[i]) with the new set;
-- returns false when an owned row could not be addressed (a rebuild without our knowledge,
-- or no GetLeftLine). Rows with no matching new line are blanked, never deleted.
local function rewriteOwnedRows(tooltip, prev, lines, pet)
  if type(tooltip.GetLeftLine) ~= "function" then return false end
  local addressable = true
  for i, index in ipairs(prev.rows) do
    local ok, row = pcall(tooltip.GetLeftLine, tooltip, index)
    if not ok or type(row) ~= "table" or type(row.SetText) ~= "function" then
      addressable = false
    elseif i <= #lines then
      local text = pet and (lines[i][1] .. " (" .. L.PET .. ")") or lines[i][1]
      pcall(row.SetText, row, text)
      if type(row.SetTextColor) == "function" then
        pcall(row.SetTextColor, row, lines[i][2], lines[i][3], lines[i][4])
      end
    else
      pcall(row.SetText, row, "")
    end
  end
  return addressable
end

-- Add lines whose indices we record as they land at the end of the tooltip.
local function appendOwnedRows(tooltip, prev, rows, lines, pet)
  local base = rowsBefore(tooltip) or 0
  for i = 1, #lines do
    local text = pet and (lines[i][1] .. " (" .. L.PET .. ")") or lines[i][1]
    local ok = pcall(tooltip.AddLine, tooltip, text, lines[i][2], lines[i][3], lines[i][4])
    if ok then rows[#rows + 1] = base + i end
  end
  prev.count = #rows
  return #rows > 0
end

-- The row bookkeeping shared by the spell and the item paths: rewrite the rows this tooltip
-- already holds for the same key, else blank a previous key's rows (a native rebuild drops
-- them anyway) and append the new set at the end. "pet" only names the suffix the rows wear.
local function applyOwnedRows(tooltip, key, lines, pet)
  forgetRowsOnClear(tooltip)
  local prev = tooltipLines[tooltip]
  if prev and prev.spellID == key then
    -- the same effect on the same tooltip again: a refresh (a combo change while the tooltip
    -- is open). Rows the tooltip still shows are rewritten in place and the set grows or
    -- shrinks at the end; a tooltip that was rebuilt natively since falls through to a plain
    -- add at the end.
    if rewriteOwnedRows(tooltip, prev, lines, pet) then
      -- a smaller set leaves its surplus rows blanked but tracked, so a later larger set
      -- rewrites them instead of appending duplicates
      if #lines > #prev.rows then
        appendOwnedRows(tooltip, prev, prev.rows, { select(#prev.rows + 1, unpack(lines)) }, pet)
      end
      return #lines
    end
    if type(tooltip.GetLeftLine) ~= "function" then
      -- The rows cannot be addressed at all and the tooltip was not cleared (a clear drops
      -- prev through OnTooltipCleared): appending the same block again would leave two
      -- copies visible. A client without the accessor keeps the first block until the next
      -- native rebuild.
      return #lines
    end
  elseif prev then
    rewriteOwnedRows(tooltip, prev, {}, pet)
    tooltipLines[tooltip] = nil
    prev = nil
  end
  local added = { spellID = key, rows = {} }
  appendOwnedRows(tooltip, added, added.rows, lines, pet)
  if added.count > 0 then tooltipLines[tooltip] = added end
  return #lines
end

-- Adds our lines; returns how many. A pet's spell says so at the end of each line.
local function addTooltipLines(tooltip, spellID, pet)
  if not db.tooltip or isSecret(spellID) or type(spellID) ~= "number" then return 0 end
  local view = ns.Compute(spellID, pet)
  local lines = Format.TooltipLines(view, L)
  local gray = Format.NOTE_COLOR
  -- what the recent casts of the spell really averaged (the damage meter's numbers, read after each fight): beside
  -- the description's own figures, and the only figures of a spell the description gives none for
  if not pet and db.useHistory and ns.History then
    for _, line in ipairs(ns.History.Lines(spellID)) do lines[#lines + 1] = line end
  end
  -- Judgement's number is its seal's; without a seal there is none, and the tooltip says why
  if not view and not pet and ns.IsJudgementSpell(spellID) then
    lines[#lines + 1] = { L.NO_SEAL, gray[1], gray[2], gray[3] }
  end
  -- a seal's own tooltip also says what its Judgement does
  local judgement = not pet and ns.SealJudgement(spellID)
  if judgement then lines[#lines + 1] = Format.JudgementLine(judgement, L) end
  if db.reduction then
    local reduction = ns.Reduction(spellID)
    if reduction then
      lines[#lines + 1] = Format.ReductionLine(reduction, L, ns.ReductionPerHit(reduction), ns.TargetSpeed())
    end
  end
  return applyOwnedRows(tooltip, spellID, lines, pet)
end
ns.AddTooltipLines = addTooltipLines

-- The same lines on an ITEM tooltip for a weapon poison: the per-trigger damage the coating
-- states, with the chance, so the item says what applying it buys. Only coating items reach
-- this path; every other item tooltip is left untouched. The rows go through the same
-- bookkeeping as spell rows, keyed by the item link.
-- Food or a drink that states a share of the maximum ("Restores 60% mana over 30 sec."): the
-- amounts that share comes to for this character, as tooltip rows. Nil for every other item,
-- and while the client hides the maximum.
function ns._percentItemLines(text)
  local parsed = Parser.ParseItemHeal(text, ns.DescriptionLang())
  if not parsed or not (parsed.healPercent or parsed.manaPercent) then return nil end
  local view = ns._percentMana(parsed.healPercent and percentHealView(parsed) or nil, parsed)
  if not view then return nil end
  local lines = {}
  local health = (view.hot and view.hot.total or 0) + (view.heal and (view.heal.min + view.heal.max) / 2 or 0)
  local mana = (view.manaOverTime and view.manaOverTime.total or 0) + (view.mana and (view.mana.min + view.mana.max) / 2 or 0)
  if health >= 0.5 then
    local c = Format.HEAL_COLOR
    lines[#lines + 1] = { Format.Thousands(math.floor(health + 0.5), L) .. " " .. (type(HEALTH) == "string" and HEALTH or "Health"), c[1], c[2], c[3] }
  end
  if mana >= 0.5 then
    local c = Format.WEAPON_COLOR
    lines[#lines + 1] = { Format.Thousands(math.floor(mana + 0.5), L) .. " " .. (type(MANA) == "string" and MANA or "Mana"), c[1], c[2], c[3] }
  end
  return #lines > 0 and lines or nil
end

local function addItemPoisonLines(tooltip)
  if not db.tooltip or type(tooltip) ~= "table" or type(tooltip.GetItem) ~= "function" then return end
  local ok, _, link = pcall(tooltip.GetItem, tooltip)
  if not ok or isSecret(link) or type(link) ~= "string" then return end
  local itemID = tonumber(link:match("item:(%d+)"))
  if not itemID then return end
  local spellID = itemUseSpell(itemID)
  local text = spellID and getDescription(spellID) or nil
  if not text then text = itemUseText(itemID) end
  local view = text and poisonView(text) or nil
  if not view and text then
    local lines = ns._percentItemLines(text)
    if lines then
      applyOwnedRows(tooltip, link, lines, false)
      return
    end
  end
  if not view then
    -- Nothing readable (yet): blank rows left by another item on the same tooltip, and
    -- leave this item's own rows alone (its data may still arrive).
    local prev = tooltipLines[tooltip]
    if prev and prev.spellID ~= link then
      rewriteOwnedRows(tooltip, prev, {}, false)
      tooltipLines[tooltip] = nil
    end
    return
  end
  applyOwnedRows(tooltip, link, Format.TooltipLines(view, L), false)
end

-- The pet action slot of the button a tooltip belongs to, or nil.
local function ownerPetSlot(tooltip)
  if type(tooltip.GetOwner) ~= "function" then return nil end
  local ok, owner = pcall(tooltip.GetOwner, tooltip)
  if ok and type(owner) == "table" then return petSlots[owner] end
  return nil
end

-- Is the tooltip's owner a spell on the spellbook's pet page? Forever's spellbook item keeps its
-- bank (Enum.SpellBookSpellBank) on the frame that holds the button the tooltip belongs to;
-- Classic Era's SpellButton reads the page from SpellBookFrame.bookType.
local function ownerIsPetSpellBook(tooltip)
  if type(tooltip.GetOwner) ~= "function" then return false end
  local ok, owner = pcall(tooltip.GetOwner, tooltip)
  if not ok or type(owner) ~= "table" then return false end
  local banks = type(Enum) == "table" and Enum.SpellBookSpellBank
  if type(banks) == "table" and banks.Pet ~= nil then
    local item = owner
    if owner.spellBank == nil and type(owner.GetParent) == "function" then
      local okP, parent = pcall(owner.GetParent, owner)
      item = okP and parent or nil
    end
    if type(item) == "table" and item.spellBank == banks.Pet then return true end
  end
  if type(SpellButtonMixin) == "table" and owner.OnEnter ~= nil and owner.OnEnter == SpellButtonMixin.OnEnter
    and type(SpellBookFrame) == "table" then
    return SpellBookFrame.bookType == (BOOKTYPE_PET or "pet")
  end
  return false
end

-- A combo change while a finisher's tooltip is open: re-render its lines on the same tooltip,
-- so the number under the cursor follows the selected target's combo. addTooltipLines takes the
-- previous lines for the same spell off first, so this never appends a second set.
local function refreshOpenFinisherTooltip()
  if not db.tooltip then return end
  if type(GameTooltip) ~= "table" or type(GameTooltip.IsShown) ~= "function" then return end
  local ok, shown = pcall(GameTooltip.IsShown, GameTooltip)
  if not ok or not shown then return end
  if type(GameTooltip.GetSpell) ~= "function" then return end
  local ok2, _, spellID = pcall(GameTooltip.GetSpell, GameTooltip)
  -- Forever's native getter returns name, id (pinned TooltipUtil.GetDisplayedSpell), so pcall
  -- yields ok, name, id -- the id is the THIRD value, exactly as the OnTooltipSetSpell hook
  -- below reads it. A fourth slot would always be nil and the open tooltip would never refresh.
  if not ok2 or isSecret(spellID) or type(spellID) ~= "number" then return end
  local entry = getEntry(spellID)
  if not (entry and entry.show == "finisher") then return end
  addTooltipLines(GameTooltip, spellID, ownerIsPetSpellBook(GameTooltip))
end

-- A combo-related change: the finisher numbers on the buttons, and the open tooltip when it
-- shows a finisher.
local function refreshFinishers()
  requestUpdate()
  refreshOpenFinisherTooltip()
end

-- A pet action tooltip can reach us twice: through a tooltip data post-call (on clients that
-- build tooltips from data, and again when the tooltip refreshes) and through the SetPetAction
-- hook right after it. The post-call marks the tooltip so the hook does not add the lines again.
-- (The table itself is declared with the tooltip helpers above; the SetPetAction hook and the
-- OnTooltipCleared handler below both use the same local.)

local function addPetLines(tooltip, slot)
  return addTooltipLines(tooltip, petSpellOnSlot(slot), true)
end

local function hookTooltips()
  local postCalls = type(TooltipDataProcessor) == "table" and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
    and type(Enum) == "table" and type(Enum.TooltipDataType) == "table"
  if postCalls and Enum.TooltipDataType.Spell then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
      local slot = ownerPetSlot(tooltip)
      if slot then
        addPetLines(tooltip, slot)
        petLinesDone[tooltip] = true
      elseif type(data) == "table" then
        addTooltipLines(tooltip, data.id, ownerIsPetSpellBook(tooltip))
      end
    end)
  elseif GameTooltip and type(GameTooltip.HookScript) == "function" then
    GameTooltip:HookScript("OnTooltipSetSpell", function(tooltip)
      if ownerPetSlot(tooltip) then return end -- the SetPetAction hook below handles it
      local _, spellID = tooltip:GetSpell()
      addTooltipLines(tooltip, spellID, ownerIsPetSpellBook(tooltip))
    end)
  end
  if postCalls and Enum.TooltipDataType.PetAction and Enum.TooltipDataType.PetAction ~= Enum.TooltipDataType.Spell then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.PetAction, function(tooltip)
      local slot = ownerPetSlot(tooltip)
      if slot then
        addPetLines(tooltip, slot)
        petLinesDone[tooltip] = true
      end
    end)
  end
  -- Weapon poison items: their coating text states the per-trigger damage, so the item
  -- tooltip gets the same lines a spell would (both hooks are harmless together: the row
  -- bookkeeping rewrites in place instead of appending twice).
  if postCalls and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addItemPoisonLines)
  end
  if type(GameTooltip) == "table" and type(GameTooltip.HookScript) == "function" then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", addItemPoisonLines)
  end
  if type(ItemRefTooltip) == "table" and type(ItemRefTooltip.HookScript) == "function" then
    pcall(ItemRefTooltip.HookScript, ItemRefTooltip, "OnTooltipSetItem", addItemPoisonLines)
  end
  if type(hooksecurefunc) == "function" and GameTooltip and type(GameTooltip.SetPetAction) == "function" then
    if type(GameTooltip.HookScript) == "function" then
      -- SetPetAction clears the tooltip before the post-calls run, so a mark left by an earlier
      -- tooltip is gone by then
      pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", function(tooltip) petLinesDone[tooltip] = nil end)
    end
    hooksecurefunc(GameTooltip, "SetPetAction", function(tooltip, slot)
      if petLinesDone[tooltip] then
        petLinesDone[tooltip] = nil
        return
      end
      if addPetLines(tooltip, slot) > 0 and type(tooltip.Show) == "function" then tooltip:Show() end
    end)
  end
end

---------------------------------------------------------------------------------------------
-- Settings and /sdi
---------------------------------------------------------------------------------------------

local function onOff(v) return v and L.ON or L.OFF end

local function toggleArg(arg, current)
  if arg == "on" or arg == "an" then return true end
  if arg == "off" or arg == "aus" then return false end
  if arg == nil or arg == "" then return not current end
  return nil
end

-- Is value valid for setting key? Used by the options window; the slash handler checks its own.
local function validSetting(key, value)
  if key == "button" then return BUTTON_MODES[value] == true end
  if key == "position" then return POSITIONS[value] == true end
  if key == "sidePosition" then return SIDE_POSITIONS[value] == true end
  -- (talents was missing here, so the options window's "Include talents" box wrote nothing)
  if BOOLEAN_KEYS[key] then return type(value) == "boolean" end
  if key == "size" then return type(value) == "number" and value >= SIZE_MIN and value <= SIZE_MAX end
  if key == "interfaceLang" then return value == "auto" or value == "en" or value == "de" or value == "ru" end
  return false
end

-- Settings changed from outside the options window (/sdi): the window, when open, shows them.
local function settingsChanged()
  if type(ns.OptionsChanged) == "function" then ns.OptionsChanged() end
end

-- For Options.lua: the live settings table (loadSettings replaces it), a checked write, and
-- a reset. Both writes refresh the buttons.
ns.DEFAULTS, ns.SIZE_MIN, ns.SIZE_MAX = DEFAULTS, SIZE_MIN, SIZE_MAX
function ns.GetSettings() return db end

function ns.SetSetting(key, value)
  if not validSetting(key, value) then return false end
  if key == "size" then value = math.floor(value + 0.5) end
  db[key] = value
  if key == "skipUtilityBars" and type(ns.RecollectButtons) == "function" then ns.RecollectButtons() end
  requestUpdate()
  return true
end

function ns.ResetSettings()
  for k, v in pairs(DEFAULTS) do db[k] = v end
  ns.SetInterfaceAndRefreshL(DEFAULTS.interfaceLang)
  -- Reset skips the pet bar again; the main bonus combat bar keeps its numbers.
  if type(ns.RecollectButtons) == "function" then ns.RecollectButtons() end
  requestUpdate()
end

-- Is a bar addon built on LibActionButton (Bartender4, ElvUI and others) loaded? /sdi status says
-- how many of its buttons carry numbers.
local function barAddonLoaded()
  return #labLibraries() > 0
end

local function langLabel(lang)
  if lang == "en" then return L.LANG_EN end
  if lang == "de" then return L.LANG_DE end
  if lang == "ru" then return L.LANG_RU end
  return L.LANG_AUTO
end

local function slash(msg)
  msg = type(msg) == "string" and msg:lower() or ""
  local cmd, arg = msg:match("^%s*(%S*)%s*(%S*)")
  if (cmd == "" or cmd == "options" or cmd == "config") and type(ns.OpenOptions) == "function" then
    ns.OpenOptions()
    return
  end
  if cmd == "" or cmd == "help" or cmd == "hilfe" then
    for _, line in ipairs(L.HELP) do say(line) end
    return
  end
  if cmd == "dump" and arg == "all" then
    say(L.DUMP_WORKING)
    ns.DumpAll(function(list) say(string.format(L.DUMP_ALL_DONE, #list.spells, list.missing)) end)
    return
  end
  if cmd == "dump" and arg == "items" then
    local list = ns.DumpItems()
    say(string.format(L.DUMP_ITEMS_DONE, #list.items, list.missing))
    return
  end
  if cmd == "dump" then
    local list = ns.Dump()
    say(string.format(L.DUMP_DONE, #list.spells, list.missing))
    return
  end
  if cmd == "misses" then
    if arg == "clear" then
      db.misses = {}
      missSeen, missCount = {}, 0
      say(L.MISSES_CLEARED)
      return
    end
    if #db.misses == 0 then say(L.MISSES_NONE) return end
    say(string.format(L.MISSES_HEAD, #db.misses))
    for _, m in ipairs(db.misses) do
      local text = type(m.text) == "string" and m.text:gsub("[\r\n]+", " ") or "?"
      say(tostring(m.id) .. " " .. tostring(m.name or "?") .. ": " .. text)
    end
    return
  end
  if cmd == "history" then
    if arg == "clear" then
      ns.History.Clear()
      requestUpdate()
      say(L.HISTORY_CLEARED)
      return
    end
    if arg == "on" or arg == "off" then
      db.useHistory = arg == "on"
      requestUpdate()
      settingsChanged()
    elseif arg ~= "" and arg ~= "list" then
      say(L.BAD_ARG)
      return
    end
    for _, line in ipairs(ns.History.Status()) do say(line) end
    if arg == "list" then
      for i, e in ipairs(ns.History.List()) do
        if i > 25 then break end
        say(string.format("%d %s: %d casts, damage %.0f, healing %.0f per cast", e.id, e.name or "?", e.casts, e.damage, e.healing))
      end
    end
    return
  end
  -- the kinds of number the buttons show (Options: the "Show" checkboxes)
  local showKey = ({ damage = "showDamage", dot = "showDot", heal = "showHeal", hot = "showHot", mana = "showMana",
    absorb = "showAbsorb" })[cmd]
  if showKey then
    local v = toggleArg(arg, db[showKey])
    if v == nil then say(L.BAD_ARG) return end
    db[showKey] = v
  elseif cmd == "estimate" or cmd == "tooltip" or cmd == "reduction" or cmd == "weapon" then
    local v = toggleArg(arg, db[cmd])
    if v == nil then say(L.BAD_ARG) return end
    db[cmd] = v
  elseif cmd == "button" then
    if not BUTTON_MODES[arg] then say(L.BAD_ARG) return end
    db.button = arg
  elseif cmd == "size" then
    local v = tonumber(arg)
    if not v or v < SIZE_MIN or v > SIZE_MAX then say(L.BAD_ARG) return end
    db.size = math.floor(v + 0.5)
  elseif cmd == "position" then
    if not POSITIONS[arg] then say(L.BAD_ARG) return end
    db.position = arg
  elseif cmd == "buttons" then
    ns.DescribeButtons(say)
    return
  elseif cmd == "combo" then
    ns.DescribeCombo(say)
    return
  elseif cmd == "where" then
    ns.DescribeMouseFrame(say)
    return
  elseif cmd == "lang" then
    if arg == "ruru" then arg = "ru" end
    if not (arg == "auto" or arg == "en" or arg == "de" or arg == "ru") then say(L.BAD_ARG) return end
    db.interfaceLang = arg
    ns.SetInterfaceAndRefreshL(arg)
  elseif cmd ~= "status" then
    say(L.BAD_ARG)
    return
  end
  say(string.format(L.STATUS, onOff(db.estimate), db.button, onOff(db.tooltip), onOff(db.reduction), onOff(db.weapon),
    db.size, db.position, langLabel(db.interfaceLang)))
  say(string.format(L.STATUS_SHOWN, onOff(db.showDamage), onOff(db.showDot), onOff(db.showHeal), onOff(db.showHot),
    onOff(db.showMana), onOff(db.showAbsorb), onOff(db.useHistory)))
  if cmd == "status" and barAddonLoaded() then say(L.BAR_ADDON) end
  requestUpdate()
  settingsChanged()
end

SLASH_R2QSPELLDAMAGE1 = "/r2qsdi"
if type(SlashCmdList) == "table" then
  SlashCmdList["R2QSPELLDAMAGE"] = function(msg)
    if BIT.IsRunning and not BIT.IsRunning("SpellDamageInfo") then BIT.SayOff("SpellDamageInfo") return end
    slash(msg)
  end
end

local function loadSettings()
  if type(Ready2QuestCombat_SpellDamageInfoDB) ~= "table" then Ready2QuestCombat_SpellDamageInfoDB = {} end
  db = Ready2QuestCombat_SpellDamageInfoDB
  for k, v in pairs(DEFAULTS) do
    if db[k] == nil then db[k] = v end
  end
  if not BUTTON_MODES[db.button] then db.button = DEFAULTS.button end
  if type(db.estimate) ~= "boolean" then db.estimate = DEFAULTS.estimate end
  if type(db.tooltip) ~= "boolean" then db.tooltip = DEFAULTS.tooltip end
  if type(db.reduction) ~= "boolean" then db.reduction = DEFAULTS.reduction end
  if type(db.weapon) ~= "boolean" then db.weapon = DEFAULTS.weapon end
  if type(db.talents) ~= "boolean" then db.talents = DEFAULTS.talents end
  for _, key in ipairs(SHOW_KEYS) do
    if type(db[key]) ~= "boolean" then db[key] = DEFAULTS[key] end
  end
  if type(db.useHistory) ~= "boolean" then db.useHistory = DEFAULTS.useHistory end
  -- Not settings: Reset leaves them alone. The recorded casts (History.lua) first, then the lookup noteMiss uses.
  if ns.History then ns.History.Attach(db) end
  if type(db.misses) ~= "table" then db.misses = {} end
  missSeen, missCount = {}, 0
  for i = #db.misses, 1, -1 do
    local m = db.misses[i]
    if type(m) ~= "table" or type(m.id) ~= "number" or missSeen[m.id] then
      table.remove(db.misses, i)
    else
      missSeen[m.id] = true
      missCount = missCount + 1
    end
  end
  if not POSITIONS[db.position] then db.position = DEFAULTS.position end
  if not SIDE_POSITIONS[db.sidePosition] then db.sidePosition = DEFAULTS.sidePosition end
  if type(db.skipUtilityBars) ~= "boolean" then db.skipUtilityBars = DEFAULTS.skipUtilityBars end
  if db.interfaceLang ~= "auto" and db.interfaceLang ~= "en" and db.interfaceLang ~= "de" and db.interfaceLang ~= "ru" then
    db.interfaceLang = DEFAULTS.interfaceLang
  end
  if type(db.size) ~= "number" or db.size ~= db.size then
    db.size = DEFAULTS.size
  elseif db.size < SIZE_MIN then
    db.size = SIZE_MIN
  elseif db.size > SIZE_MAX then
    db.size = SIZE_MAX
  end
end

if BIT.RegisterWaker then
  BIT.RegisterWaker("SpellDamageInfo", function()
    if type(ns.DecideLangsAtLoad) == "function" then ns.DecideLangsAtLoad() end
    loadSettings()
    if type(ns.InitInterfaceL) == "function" then ns.InitInterfaceL(db.interfaceLang) end
  end)
end

---------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------

local frame = CreateFrame("Frame")

local UPDATE_EVENTS = {
  "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
  "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED", "PET_BAR_UPDATE", "PET_BAR_UPDATE_USABLE",
  -- an item's data can arrive after its button was drawn (a consumable dragged onto a
  -- bar): paint the numbers again once it is here
  "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT",
  "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR",
}
local RESET_EVENTS = { "SPELLS_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE",
  "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED", "UPDATE_SHAPESHIFT_FORM" }

local function register(event)
  pcall(frame.RegisterEvent, frame, event) -- an event this client does not know is skipped
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

local isReset = {}
for _, e in ipairs(RESET_EVENTS) do isReset[e] = true end

frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then
      -- switched off in Ready2QuestCombat: silent
      if BIT.ShouldRun and not BIT.ShouldRun("SpellDamageInfo") then frame:UnregisterAllEvents() return end
      ns.DecideLangsAtLoad()
      loadSettings()
      ns.InitInterfaceL(db.interfaceLang)
    elseif arg1 == "Blizzard_GamepadActionBars" then
      collectDue = true
      requestUpdate()
    end
  elseif event == "PLAYER_LOGIN" then
    collectButtons()
    if db.skipUtilityBars == false then collectPetButtons() end
    hookTooltips()
    for _, e in ipairs(UPDATE_EVENTS) do register(e) end
    for _, e in ipairs(RESET_EVENTS) do register(e) end
    register("SPELL_TEXT_UPDATE")
    -- The weapon's numbers change with gear, forms and buffs; these say so for the player.
    -- A seal cast says which seal Judgement unleashes where the buffs cannot be read.
    for _, e in ipairs({ "UNIT_AURA", "UNIT_PET", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE",
      "UNIT_ATTACK_SPEED", "UNIT_RANGEDDAMAGE", "UNIT_MAXHEALTH", "UNIT_SPELLCAST_SUCCEEDED",
      "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER" }) do
      if type(frame.RegisterUnitEvent) == "function" then
        -- the target's attack speed too, for a reduction of its attack power per hit
        pcall(frame.RegisterUnitEvent, frame, e, "player", e == "UNIT_ATTACK_SPEED" and "target" or nil)
      else
        register(e)
      end
    end
    for _, bar in ipairs({ PetActionBar, PetActionBarFrame }) do
      if type(bar) == "table" and type(bar.HookScript) == "function" then
        pcall(bar.HookScript, bar, "OnShow", requestUpdate)
      end
    end
    register("PLAYER_TARGET_CHANGED")
    -- Shift/Ctrl/Alt can swap what a button holds (a modifier-driven bar page, a [mod:shift] macro) without any
    -- bar event: redraw on the key change, and once more when the swap has settled.
    register("MODIFIER_STATE_CHANGED")
    -- the selected target's combo points: the events that say they changed. On clients that
    -- fire a unit variant of COMBO_POINTS / COMBO_TARGET_CHANGED, RegisterEvent still receives
    -- the event name; the payload is guarded as secret before anything is read from it.
    register("COMBO_POINTS")
    register("COMBO_TARGET_CHANGED")
    readBonus()
    readWeapon()
    readTargetSpeed()
    requestUpdate()
  elseif event == "PLAYER_TARGET_CHANGED" then
    readTargetSpeed()
    refreshFinishers()
  elseif event == "COMBO_POINTS" or event == "COMBO_TARGET_CHANGED" then
    if not isSecret(arg1) then refreshFinishers() end
  elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
    -- the payload's powerType is a cstring ("COMBO_POINTS"), never the numeric enum the
    -- UnitPower API takes; unreadable arguments are rejected before any comparison
    if not isSecret(arg1) and not isSecret(arg2) and arg1 == "player" and arg2 == COMBO_EVENT_TOKEN then
      refreshFinishers()
    end
  elseif event == "MODIFIER_STATE_CHANGED" then
    requestUpdate()
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.3, requestUpdate) end
  elseif event == "SPELL_TEXT_UPDATE" then
    if not isSecret(arg1) and type(arg1) == "number" then parsedCache[arg1] = nil end
    requestUpdate()
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if not isSecret(arg1) and arg1 == "player" and not isSecret(arg3) and type(arg3) == "number" then
      noteSealCast(arg3)
      requestUpdate()
    end
  elseif event == "UNIT_AURA" or event == "UNIT_PET" or event == "UNIT_ATTACK_POWER" or event == "UNIT_RANGED_ATTACK_POWER"
    or event == "UNIT_DAMAGE" or event == "UNIT_ATTACK_SPEED" or event == "UNIT_RANGEDDAMAGE" or event == "UNIT_MAXHEALTH" then
    if not isSecret(arg1) and arg1 == "player" then
      requestUpdate()
    elseif event == "UNIT_ATTACK_SPEED" and not isSecret(arg1) and arg1 == "target" then
      readTargetSpeed()
      requestUpdate()
    end
  elseif event == "PET_BAR_UPDATE" then
    -- collectPetButtons only grows. The skip has to drop a bar the event just found.
    if db and db.skipUtilityBars ~= false then
      dropListed(petButtons, function() return true end, petSlots)
    elseif db then
      collectPetButtons()
    end
    requestUpdate()
  else
    if isReset[event] then clearCache() end
    if event == "UPDATE_OVERRIDE_ACTIONBAR" or event == "UPDATE_VEHICLE_ACTIONBAR" then collectButtons() end
    -- out of combat the target's speed can be read again, and bars that were put off until the fight ended exist
    if event == "PLAYER_REGEN_ENABLED" then readTargetSpeed(); collectDue = true end
    if event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" or event == "PET_BAR_UPDATE" then collectDue = true end
    requestUpdate()
  end
end)
if BIT.Perf then BIT.Perf.Watch(frame, "OnEvent", "SpellDamageInfo") end
