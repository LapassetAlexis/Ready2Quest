-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- DoTInfo: what each DoT's ticks really are, learned from Blizzard's damage meter after the fight.
-- Adapted from Does It Die v0.9.1 (Joe Greive, MIT; see LICENSE-DoesItDie.txt), which does the same.
--
-- A spell's description leaves out spell power and attack power, so the tick sizes a DoT is estimated with start low;
-- they used to be corrected by reading the amount of each tick out of UNIT_COMBAT (db.ticks). WoW: Forever now hides
-- those amounts in combat, so nothing was ever learned and the "Learned tick sizes" list stayed empty. The ticks are
-- still matched by their timing and school (Core.lua), which says how many there were; what they were worth is in the
-- damage meter's per-spell total, readable once the fight is over (Core/Meter.lua). So:
--   * during the fight: Core.lua tells this file about every DoT it starts (Learn.Cast), every tick it matched without
--     an amount (Learn.HiddenTick), a cast it could not place (Learn.Untracked) and the sizes a readable tick taught
--     (Learn.Readable). The ticks are counted weighted by their shape (Agony's ticks grow);
--   * after the fight (PLAYER_REGEN_ENABLED): the meter's total for a spell, less the upfront hit of its casts (the
--     description's own figure: Immolate's first hit is in the same total), over the ticks counted, is the real
--     average tick. It is blended into db.ticks, older fights counting for at most WEIGHT_CAP ticks.
-- Only where the two can match: a cast at no known mob, a cast whose DoT never showed a tick, a spell whose upfront hit
-- cannot be told, a DoT cast with Amplify Curse (the description's tick is the unbuffed one), a bleed (its hits cannot be
-- told from white swings) or one total shared by several combo point sizes teach nothing, and a size more than 2.5 times or less than half of the description's is
-- taken for a mixed-in hit and thrown away. Every decision is in the trace log ("LEARN ...").

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("DoTInfo")

local Learn = {}
ns.Learn = Learn

local MIN_FACTORS = 2                   -- at least two (average) ticks' worth this fight
local RATIO_MIN, RATIO_MAX = 0.5, 2.5   -- real against the description's: outside this something else got mixed in
local WEIGHT_CAP = 20                   -- older fights count as at most this many ticks, so a change of gear catches up

-- [learned-size key] = what this fight counted for it, { spellID, name, factors, ticks, direct, descTick, dots, unclear }
local tally = {}
local untracked = {}   -- [spellID] = true: a cast at no known mob (the meter still counts what it deals)
local readable = {}    -- [key] = true: a readable tick taught this key this fight (the meter's total then holds ticks
                       -- the tally did not count)
local inCombat = false

local function trace(message)
  if ns.trace then ns.trace(message) end
end

-- This fight's counts, and fresh ones for the next (a new pull right after must not mix into it).
local function take()
  local counted = { keys = tally, untracked = untracked, readable = readable }
  tally, untracked, readable = {}, {}, {}
  return counted
end

local function tallyFor(dot, name)
  if not dot.tickKey then return nil end
  local t = tally[dot.tickKey]
  if not t then
    t = { spellID = dot.spellID, name = name, factors = 0, ticks = 0, direct = 0,
      descTick = dot.total / dot.totalTicks, dots = {} }
    tally[dot.tickKey] = t
  end
  return t
end

-- The upfront hit of a spell's cast, as its description states it: 0 for a finisher (its point table is no upfront
-- hit), SpellDamageInfo's reading for the others, nil when it cannot be told (the spell is then not learned).
function Learn.Upfront(spellID, isFinisher)
  if isFinisher then return 0 end
  local sdi = BIT.modules and BIT.modules.SpellDamageInfo
  if type(sdi) ~= "table" or type(sdi.UpfrontDamage) ~= "function" then return nil end
  local ok, value = pcall(sdi.UpfrontDamage, spellID)
  if ok and type(value) == "number" then return value end
  return nil
end

-- A DoT of ours was started. upfront: Learn.Upfront's answer for its spell; name: the spell's (for the trace).
function Learn.Cast(dot, upfront, name)
  local t = tallyFor(dot, name)
  if not t then return end
  t.dots[#t.dots + 1] = dot
  -- A physical hit with its amount hidden cannot be told from a white swing at the same moment (a bleed's ticks are
  -- matched by timing alone), so a bleed's ticks may be miscounted: not learned.
  if upfront == nil or (dot.boost and dot.boost ~= 1) or dot.school == 1 then t.unclear = true else t.direct = t.direct + upfront end
end

-- A cast whose mob was not known: the meter has its damage, the tally has not.
function Learn.Untracked(spellID)
  untracked[spellID] = true
end

-- A tick was matched by its timing, its amount hidden; factor is its share of an average tick.
function Learn.HiddenTick(dot, factor)
  local t = tallyFor(dot)
  if t then
    t.factors = t.factors + (factor or 1)
    t.ticks = t.ticks + 1
  end
end

-- A readable tick wrote a size for this key this fight.
function Learn.Readable(key)
  if key then readable[key] = true end
end

-- Why a key is not learned from this fight, or nil. "" skips quietly (nothing was counted).
local function skipReason(key, t, counted, totals, keysPerSpell)
  if t.factors < MIN_FACTORS then
    return t.ticks > 0 and string.format("only %d tick(s) counted", t.ticks) or ""
  end
  if counted.readable[key] then return "a readable tick already taught it" end
  if t.unclear then return "its upfront hit can't be told apart, it was cast with a buff on its ticks, or it is a bleed" end
  -- Ticks of a DoT cast before this fight (Feign Death, an evade) or by a trap: the casts that fed the meter are not in
  -- this tally, so nothing can say whether every tick was seen.
  if #t.dots == 0 then return "not cast this fight" end
  if counted.untracked[t.spellID] then return "a cast had no known target, so the meter has damage not counted here" end
  for _, dot in ipairs(t.dots) do
    if dot.ticksSeen == 0 then return "a cast's DoT never showed a tick (out of sight, or the mob died first)" end
  end
  if not totals[t.spellID] then return "no damage meter total under this spell id" end
  if keysPerSpell[t.spellID] > 1 then return "several combo point sizes share one meter total" end
end

-- totals: the meter's { [spellID] = damage } for the fight; counted: take()'s answer. Learns a real average tick for
-- every DoT whose ticks were counted. Returns how many sizes were learned.
function Learn.FromMeter(totals, counted)
  local db = ns.db
  if not db then return 0 end
  db.tickWeights = db.tickWeights or {}
  local keysPerSpell = {}
  for _, t in pairs(counted.keys) do keysPerSpell[t.spellID] = (keysPerSpell[t.spellID] or 0) + 1 end
  local learned = 0
  for key, t in pairs(counted.keys) do
    local total, name = totals[t.spellID], t.name or tostring(t.spellID)
    local skip = skipReason(key, t, counted, totals, keysPerSpell)
    if skip then
      if skip ~= "" then trace(string.format("LEARN %s skipped: %s", name, skip)) end
    else
      local ratio = total / (t.direct + t.descTick * t.factors)
      if ratio < RATIO_MIN or ratio > RATIO_MAX then
        trace(string.format("LEARN %s skipped: meter %d over %d tick(s) is %.2fx the description", name, total, t.ticks, ratio))
      else
        local tick = ratio * t.descTick
        local old, weight = db.ticks[key], math.min(db.tickWeights[key] or 0, WEIGHT_CAP)
        if not old then weight = 0 end
        local blended = (((old or 0) * weight) + tick * t.factors) / (weight + t.factors)
        db.ticks[key] = math.floor(blended * 10 + 0.5) / 10
        db.tickWeights[key] = weight + t.factors
        if ns.dropSnapshots then ns.dropSnapshots(key) end
        learned = learned + 1
        trace(string.format("LEARN %s: meter %d over %d tick(s)%s = %.1f per tick (description %.1f), saved %.1f", name, total,
          t.ticks, t.direct > 0 and " minus the upfront hit" or "", tick, t.descTick, db.ticks[key]))
      end
    end
  end
  return learned
end

local function attempt(counted, tries)
  if inCombat then
    trace("LEARN skipped: a new fight started before the damage meter could be read")
    return
  end
  local damage, why = BIT.Meter.Totals(tries <= 0)
  if not damage then
    if why == "wait" and tries > 0 and C_Timer and type(C_Timer.After) == "function" then
      C_Timer.After(BIT.Meter.RETRY, function() attempt(counted, tries - 1) end)
      return
    end
    trace("LEARN skipped: damage meter " .. (why == "wait" and "still empty or hidden" or tostring(why)))
    return
  end
  Learn.FromMeter(damage, counted)
end

-- The fight is over: take its counts and read the meter (it can need a moment to stop being secret).
function Learn.FightOver()
  inCombat = false
  local counted = take()
  if ns.off or ns.Retail or not ns.db or next(counted.keys) == nil then return end
  -- nothing the meter could teach (too few ticks, or readable ticks already did): no read, no trace line
  local wanted = false
  for key, t in pairs(counted.keys) do
    if t.factors >= MIN_FACTORS and not counted.readable[key] then wanted = true break end
  end
  if not wanted then return end
  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(BIT.Meter.RETRY, function() attempt(counted, BIT.Meter.TRIES) end)
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    inCombat = true
  else
    Learn.FightOver()
  end
end)
if BIT.Perf then BIT.Perf.Watch(frame, "OnEvent", "DoTInfo.learn") end
