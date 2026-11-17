-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Blizzard's damage meter (C_DamageMeter), read for the local player once a fight is over.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- On WoW: Forever the damage of a hit is a secret value in combat (UNIT_COMBAT hands addons no amount) and the combat
-- log is closed to addons, but the meter's per-spell totals are readable once the fight has ended (SecretWhenInCombat in
-- the client's API documentation). This is the one reader of it: SpellDamageInfo's History (what a spell's casts really
-- did) and DoTInfo's tick learning (what a DoT's ticks really are) both take their numbers from here. Does It Die reads
-- real tick sizes the same way (its v0.9.1). The meter feature itself needs nothing switched on: the "damageMeterEnabled"
-- setting only shows or hides Blizzard's meter window, and C_DamageMeter.IsDamageMeterAvailable() says whether the
-- numbers exist at all.
--
--   Meter.Totals(final)   damage, healing: { [spellID] = total } of the current session; or nil and why ("no damage
--                         meter", "switched off", "unreadable", "wait" while the numbers are still hidden). final: nothing
--                         is waited for any more, so empty lists are an answer.
--   Meter.RETRY, Meter.TRIES   how often a caller asks again while the answer is "wait": every RETRY seconds, TRIES times.

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
if not BIT then return end

local Meter = {}
BIT.Meter = Meter

Meter.RETRY, Meter.TRIES = 0.5, 20 -- the meter can need a few seconds after the fight to stop being secret

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, secret = pcall(issecretvalue, v)
  return ok and secret == true
end

local function finite(v)
  return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

local function readableTable(v)
  if isSecret(v) or type(v) ~= "table" then return false end
  if type(canaccesstable) ~= "function" then return true end
  local ok, allowed = pcall(canaccesstable, v)
  return ok and allowed == true
end

-- One meter list as { [spellID] = total }; nil, "wait" while the table or a value in it is still hidden.
local function rows(DM, session, kind, guid)
  local source = DM.GetCombatSessionSourceFromType(session, kind, guid)
  if not readableTable(source) or not readableTable(source.combatSpells) then return nil, "wait" end
  local list = source.combatSpells
  local count = #list
  if isSecret(count) or type(count) ~= "number" then return nil, "wait" end
  local out = {}
  for i = 1, count do
    local row = list[i]
    if readableTable(row) then
      local id, amount = row.spellID, row.totalAmount
      if isSecret(id) or isSecret(amount) then return nil, "wait" end
      if type(id) == "number" and finite(amount) and amount > 0 then out[id] = (out[id] or 0) + amount end
    end
  end
  return out
end

function Meter.Totals(final)
  local DM = C_DamageMeter
  if type(DM) ~= "table" or type(DM.GetCombatSessionSourceFromType) ~= "function" then return nil, "no damage meter" end
  if type(DM.IsDamageMeterAvailable) == "function" then
    local ok, available = pcall(DM.IsDamageMeterAvailable)
    if ok and available == false then return nil, "switched off" end
  end
  local kinds = type(Enum) == "table" and Enum.DamageMeterType or {}
  local sessions = type(Enum) == "table" and Enum.DamageMeterSessionType or {}
  local damageType, healingType, current = kinds.DamageDone or 0, kinds.HealingDone or 2, sessions.Current or 1
  local okGuid, guid = pcall(UnitGUID, "player")
  if not okGuid or isSecret(guid) or type(guid) ~= "string" then return nil, "unreadable" end
  local ok, damage, why = pcall(rows, DM, current, damageType, guid)
  if not ok then return nil, "unreadable" end
  if not damage then return nil, why end
  -- a fight with no healing may answer with nothing at all: that is an empty list, not a failure
  local okHeal, healing = pcall(rows, DM, current, healingType, guid)
  if not okHeal or not healing then healing = {} end
  if not final and next(damage) == nil and next(healing) == nil then return nil, "wait" end
  return damage, healing
end
