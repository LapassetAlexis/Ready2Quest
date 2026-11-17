-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- DoesItDiePlus: what the talents of WoW: Forever add to the numbers of your spells.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- Forever's spell descriptions leave talents out (unlike Retail's), so a spell's number is its base plus spell power.
-- TalentModsData.lua (generated from the client's tables) lists every talent that raises damage or healing: for the
-- spell ids or schools it reaches and the percent each rank adds. This file turns that into one answer: the
-- percent your talents add to one spell's direct part or periodic part, read from the ranks the talent tree reports.
-- Retail gets 0 (its descriptions already hold the talents), so nothing is counted twice.
--
--   BIT.TalentMods.Percent(spellID, school, part, isHeal) -> fraction (0.1 = +10%), notes
--     part: "d" the direct damage or healing, "o" the damage or healing over time.
--     school: "fire", "shadow"..., for a damage spell; the school talents ("Moonfury") only reach damage.
--   BIT.TalentMods.Invalidate() drops the cached answers (the talents changed).
--   BIT.TalentMods.RankProvider(talentSpellID, name) -> rank or nil: set by CastPrediction's tree reader.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
BIT = BIT or {}

local TM = {}
BIT.TalentMods = TM

local SCHOOL_BIT = { physical = 1, holy = 2, fire = 4, nature = 8, frost = 16, shadow = 32, arcane = 64 }

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, r = pcall(issecretvalue, v)
  return ok and r == true
end

local function isRetail()
  if type(GetBuildInfo) ~= "function" then return false end
  local ok, version = pcall(GetBuildInfo)
  if not ok or isSecret(version) or type(version) ~= "string" then return false end
  local major = tonumber(version:match("^(%d+)"))
  return major ~= nil and major >= 10
end

local function playerClass()
  if type(UnitClass) ~= "function" then return nil end
  local ok, _, token = pcall(UnitClass, "player")
  if ok and not isSecret(token) and type(token) == "string" then return token end
  return nil
end

-- "769,779-780,9754" -> { [769] = true, [779] = true, [780] = true, [9754] = true }, built once per list.
local setCache = {}
local function idSet(list)
  local set = setCache[list]
  if set then return set end
  set = {}
  for token in list:gmatch("[^,]+") do
    local a, b = token:match("^(%d+)%-(%d+)$")
    if a then
      for id = tonumber(a), tonumber(b) do set[id] = true end
    else
      local id = tonumber(token)
      if id then set[id] = true end
    end
  end
  setCache[list] = set
  return set
end

-- A combined school takes what any of its parts takes.
local COMPOUND = {
  frostfire = { "fire", "frost" }, spellfire = { "arcane", "fire" }, spellfrost = { "arcane", "frost" },
  shadowfrost = { "shadow", "frost" }, shadowflame = { "shadow", "fire" }, chimeral = { "arcane", "fire", "frost" },
  chaos = { "physical", "holy", "fire", "nature", "frost", "shadow", "arcane" },
}

-- A mask holds the school: every power of two in `mask` is a school, `school` is a name ("frostfire" is two).
local function maskHas(mask, school)
  local function has(bitValue) return bitValue and math.floor(mask / bitValue) % 2 == 1 end
  local parts = COMPOUND[school]
  if not parts then return has(SCHOOL_BIT[school]) end
  for _, part in ipairs(parts) do
    if has(SCHOOL_BIT[part]) then return true end
  end
  return false
end

local answers = {}
function TM.Invalidate()
  answers = {}
end

local function rankOf(talent)
  local provider = TM.RankProvider
  if type(provider) ~= "function" then return nil end
  local ok, rank = pcall(provider, talent.id, talent.en)
  if ok and type(rank) == "number" and not isSecret(rank) then return rank end
  return nil
end

-- The talents the player has: { talent, rank } for every listed talent of the class with at least one rank.
local function activeTalents()
  local class = playerClass()
  local data = BIT.TalentModData and BIT.TalentModData[class]
  if not data then return {} end
  local list = {}
  for _, talent in ipairs(data) do
    local forced = BIT.TalentModForce and BIT.TalentModForce[talent.id]
    local rank = rankOf(talent)
    if forced == "off" then rank = 0 elseif forced == "max" then rank = talent.max end
    if rank and rank > 0 then list[#list + 1] = { talent = talent, rank = math.min(rank, talent.max) } end
  end
  return list
end

function TM.Percent(spellID, school, part, isHeal)
  if isRetail() then return 0 end
  local key = tostring(spellID) .. "|" .. tostring(school) .. "|" .. tostring(part) .. "|" .. tostring(isHeal)
  local hit = answers[key]
  if hit then return hit[1], hit[2] end
  local total, notes = 0, {}
  for _, active in ipairs(activeTalents()) do
    local talent, rank = active.talent, active.rank
    for _, mod in ipairs(talent.mods) do
      local applies = false
      if mod.k == "s" then
        applies = not isHeal and type(school) == "string" and maskHas(mod.m, school)
      elseif mod.k == part or mod.k == "b" then
        applies = type(spellID) == "number" and idSet(mod.ids)[spellID] or false
      end
      if applies then
        local percent = mod.p[math.min(rank, #mod.p)] or 0
        if percent ~= 0 then
          total = total + percent / 100
          notes[#notes + 1] = string.format("%s %d/%d +%g%%", talent.en, rank, talent.max, percent)
        end
      end
    end
  end
  local text = table.concat(notes, ", ")
  answers[key] = { total, text }
  return total, text
end

-- A short list of what is read for the class (for /upt probes): talent, rank and percent at that rank.
function TM.Describe()
  local lines = {}
  local class = playerClass()
  local data = BIT.TalentModData and BIT.TalentModData[class]
  if not data then return { "no talent data for class " .. tostring(class) } end
  for _, talent in ipairs(data) do
    local rank = rankOf(talent)
    lines[#lines + 1] = string.format("%s: rank %s/%d", talent.en, rank and tostring(rank) or "?", talent.max)
  end
  return lines
end
