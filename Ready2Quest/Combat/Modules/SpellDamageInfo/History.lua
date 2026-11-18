-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module SpellDamageInfo: what your casts really did, learned after each fight.
-- Copyright (c) 2026 Ironship. MIT licence, see LICENSE.
--
-- A spell whose description the parser cannot read (another game language, a wording it does not know)
-- has no number of its own. For those the action button shows the average of your last WINDOW_CASTS casts
-- of that spell, marked with "~", and every spell's tooltip says what the recent casts averaged.
--
-- Where the numbers come from: UNIT_COMBAT hands the damage of a hit to addons as a secret value in combat
-- on WoW: Forever, and the combat log is closed to addons on purpose. Blizzard's own damage meter
-- (C_DamageMeter) keeps per-spell totals for the local player; they are secret while the fight lasts
-- (SecretWhenInCombat in the client's API documentation) and readable once it is over. This is the way
-- Does It Die reads real tick sizes (its v0.9.1). So the two halves are kept apart:
--   * during the fight: the player's own UNIT_SPELLCAST_SUCCEEDED events are counted per spell (a cast that
--     resisted or missed counts too: the average is what a cast is really worth);
--   * after the fight (PLAYER_REGEN_ENABLED): the meter's DamageDone and HealingDone rows are read, retrying
--     for a few seconds while the client still hides them, and every counted spell the meter has a row
--     for gets one record { n = casts, d = damage, h = healing } in the saved variables.
-- A spell with no row of its own (a buff, or a cast whose damage the meter books under another spell id)
-- records nothing. The records of a spell are trimmed to its latest WINDOW_CASTS casts, so an upgrade in
-- gear shows up within a few fights and a spell that is no longer cast does not age.
--
-- Pure Lua 5.1 apart from the few client calls, each guarded: a failed or hidden read just records nothing.

local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
-- Inside Ready2QuestCombat its own namespace; loaded on its own, the addon's table as before.
local ns = BIT and BIT.Module and BIT.Module("SpellDamageInfo") or BIT or {}

local History = {}
ns.History = History

local WINDOW_CASTS = 100   -- the average covers the latest casts of a spell, this many
local MAX_RECORDS = 30     -- records kept per spell: the two oldest are merged beyond this (the saved file stays small)
local MIN_CASTS = 3        -- fewer casts than this are not put on a button (the tooltip shows from the first)
local PULL_SECONDS = 6     -- a cast this long before combat begins is the pull's own, the first hit of the fight
local MAX_SPELLS = 400     -- spells kept; the one that was cast longest ago goes first
local MAX_PENDING = 2000   -- casts remembered within one fight

local saved                -- the module's saved variables (Core's db), set by History.Attach
local store                -- this character's records: [spellID] = { { n =, d =, h = }, ... } oldest first; they live in
                           -- saved.castHistory[player GUID] (the saved variables are account-wide, and two characters
                           -- that cast the same spell id do not do the same damage)
local pending, inCombat = {}, false -- { id =, at = } for each cast of the fight (or of its pull)
local last = "nothing read yet" -- what the latest read said, for /sdi history

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, secret = pcall(issecretvalue, v)
  return ok and secret == true
end

local function now()
  local ok, t = pcall(GetTime)
  return ok and type(t) == "number" and t or 0
end

local function finite(v)
  return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

---------------------------------------------------------------------------------------------
-- The saved records
---------------------------------------------------------------------------------------------

-- Saved variables can be edited or damaged: keep only well-formed records.
local function sanitize(records)
  for id, list in pairs(records) do
    local ok = type(id) == "number" and type(list) == "table"
    if ok then
      for i = #list, 1, -1 do
        local r = list[i]
        if type(r) ~= "table" or not finite(r.n) or r.n < 1 or not finite(r.d) or r.d < 0
          or not finite(r.h) or r.h < 0 then
          table.remove(list, i)
        end
      end
      ok = #list > 0
    end
    if not ok then records[id] = nil end
  end
end

-- db: the module's saved variables; the records live in db.castHistory (not a setting: Reset leaves it alone).
function History.Attach(db)
  saved, store = db, nil
  if type(db.castHistory) ~= "table" then db.castHistory = {} end
  for key, bucket in pairs(db.castHistory) do
    if type(key) ~= "string" or type(bucket) ~= "table" then db.castHistory[key] = nil end
  end
end

-- This character's records, opened on first use (the player's GUID may not be there yet when the addon loads);
-- nil while it cannot be told.
local function open()
  if store then return store end
  if not saved then return nil end
  local ok, guid = pcall(UnitGUID, "player")
  if not ok or isSecret(guid) or type(guid) ~= "string" or guid == "" then return nil end
  if type(saved.castHistory[guid]) ~= "table" then saved.castHistory[guid] = {} end
  store = saved.castHistory[guid]
  sanitize(store)
  return store
end

function History.Enabled()
  return saved ~= nil and saved.useHistory ~= false
end

local function round(v) return math.floor(v * 100 + 0.5) / 100 end

-- Total casts of a list of records.
local function castsOf(list)
  local n = 0
  for _, r in ipairs(list) do n = n + r.n end
  return n
end

-- Keep the latest WINDOW_CASTS casts: whole old records go, the oldest one that is left is cut down in
-- proportion (its damage and healing with it), so the average it stands for stays what it was.
local function trim(list)
  local excess = castsOf(list) - WINDOW_CASTS
  while excess > 0 and list[1] do
    local first = list[1]
    if first.n <= excess then
      excess = excess - first.n
      table.remove(list, 1)
    else
      local keep = (first.n - excess) / first.n
      first.n, first.d, first.h = first.n - excess, round(first.d * keep), round(first.h * keep)
      excess = 0
    end
  end
end

local function spellCount()
  local n = 0
  for _ in pairs(store) do n = n + 1 end
  return n
end

-- The spell cast longest ago leaves when the store is full (a record carries no time: the first spell
-- of the walk is dropped, which is enough to keep the file bounded).
local function makeRoom()
  if spellCount() < MAX_SPELLS then return end
  local oldest
  for id in pairs(store) do
    if not oldest or id < oldest then oldest = id end
  end
  if oldest then store[oldest] = nil end
end

local function add(spellID, casts, damage, healing)
  local list = store[spellID]
  if not list then
    makeRoom()
    list = {}
    store[spellID] = list
  end
  list[#list + 1] = { n = casts, d = round(damage), h = round(healing) }
  trim(list)
  -- Many short fights: the two oldest records become one (their sums), which keeps the mean and the window.
  while #list > MAX_RECORDS do
    local a, b = table.remove(list, 1), list[1]
    b.n, b.d, b.h = a.n + b.n, round(a.d + b.d), round(a.h + b.h)
  end
end

-- Test and tooling hook: one finished fight's counts and totals ([spellID] = amount) go in as records.
-- Returns how many spells got one.
function History.Record(counts, damage, healing)
  if not open() then return 0 end
  local recorded = 0
  for id, casts in pairs(counts) do
    local d, h = damage[id] or 0, healing[id] or 0
    if casts >= 1 and (d > 0 or h > 0) then
      add(id, casts, d, h)
      recorded = recorded + 1
    end
  end
  return recorded
end

---------------------------------------------------------------------------------------------
-- What the records say
---------------------------------------------------------------------------------------------

-- casts, damage per cast, healing per cast of a spell over its recorded window, or nil.
function History.Average(spellID)
  local list = open() and type(spellID) == "number" and store[spellID]
  if not list then return nil end
  local n, d, h = 0, 0, 0
  for _, r in ipairs(list) do n, d, h = n + r.n, d + r.d, h + r.h end
  if n < 1 then return nil end
  return n, d / n, h / n
end

-- A view for ButtonText: the average damage and healing of one cast, marked as an average of past
-- casts (view.history). nil with fewer than MIN_CASTS casts, or when neither reaches half a point.
function History.View(spellID)
  local n, damage, healing = History.Average(spellID)
  if not n or n < MIN_CASTS then return nil end
  local view = { history = { casts = n } }
  if damage >= 0.5 then view.direct = { min = damage, max = damage, added = 0 } end
  if healing >= 0.5 then view.heal = { min = healing, max = healing, added = 0 } end
  if not view.direct and not view.heal then return nil end
  return view
end

-- Tooltip lines ({ text, r, g, b }): what the recent casts of the spell averaged. Empty without records.
function History.Lines(spellID)
  local lines = {}
  local n, damage, healing = History.Average(spellID)
  if not n then return lines end
  local L, Format = ns.L, ns.Format
  if not (L and Format) then return lines end
  local casts = Format.Thousands(math.floor(n + 0.5), L)
  if damage >= 0.5 then
    local c = Format.DAMAGE_COLOR
    lines[#lines + 1] = { string.format(L.HISTORY_DAMAGE, casts, Format.Thousands(damage, L)), c[1], c[2], c[3] }
  end
  if healing >= 0.5 then
    local c = Format.HEAL_COLOR
    lines[#lines + 1] = { string.format(L.HISTORY_HEAL, casts, Format.Thousands(healing, L)), c[1], c[2], c[3] }
  end
  return lines
end

-- One spell's records forgotten.
function History.Forget(spellID)
  if open() and type(spellID) == "number" then store[spellID] = nil end
end

function History.Clear()
  if open() then
    for id in pairs(store) do store[id] = nil end
  end
  pending = {}
  last = "records cleared"
end

---------------------------------------------------------------------------------------------
-- Reading the damage meter (after the fight)
---------------------------------------------------------------------------------------------

local function read(counts, tries)
  if inCombat then
    last = "skipped: a new fight began before the meter could be read"
    return
  end
  local damage, healingOrWhy = BIT.Meter.Totals(tries <= 0)
  if not damage then
    if healingOrWhy == "wait" and tries > 0 and C_Timer and type(C_Timer.After) == "function" then
      C_Timer.After(BIT.Meter.RETRY, function() read(counts, tries - 1) end)
      return
    end
    last = "not read: " .. (healingOrWhy == "wait" and "the meter still hides its numbers" or tostring(healingOrWhy))
    return
  end
  local cast = 0
  for _ in pairs(counts) do cast = cast + 1 end
  local recorded = History.Record(counts, damage, healingOrWhy)
  last = string.format("recorded %d of %d cast spells", recorded, cast)
  if recorded > 0 and type(ns.Refresh) == "function" then ns.Refresh() end
end

---------------------------------------------------------------------------------------------
-- Counting the casts of a fight
---------------------------------------------------------------------------------------------

local function running()
  return saved ~= nil and (not BIT.IsRunning or BIT.IsRunning("SpellDamageInfo")) and History.Enabled()
end

local function dropEarly(t)
  while pending[1] and t - pending[1].at > PULL_SECONDS do table.remove(pending, 1) end
end

local function noteCast(spellID)
  local t = now()
  -- Out of combat only a cast that starts a pull can belong to a fight: anything older is forgotten.
  if not inCombat then dropEarly(t) end
  pending[#pending + 1] = { id = spellID, at = t }
  if #pending > MAX_PENDING then table.remove(pending, 1) end
end

local function fightOver()
  inCombat = false
  if #pending == 0 then return end
  local counts = {}
  for _, cast in ipairs(pending) do counts[cast.id] = (counts[cast.id] or 0) + 1 end
  pending = {}
  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(BIT.Meter.RETRY, function() read(counts, BIT.Meter.TRIES) end)
  end
end

-- Exposed for tooling: the fight's own event handling, with no frame.
function History.OnEvent(event, unit, _, spellID)
  if not running() then
    if event == "PLAYER_REGEN_ENABLED" then inCombat, pending = false, {} end
    return
  end
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    if isSecret(unit) or unit ~= "player" or isSecret(spellID) or type(spellID) ~= "number" then return end
    noteCast(spellID)
  elseif event == "PLAYER_REGEN_DISABLED" then
    inCombat = true
    dropEarly(now())
  elseif event == "PLAYER_REGEN_ENABLED" then
    fightOver()
  end
end

---------------------------------------------------------------------------------------------
-- /sdi history
---------------------------------------------------------------------------------------------

-- Lines for chat: the meter's state, what is recorded and what the last read did.
function History.Status()
  local lines = {}
  local DM = C_DamageMeter
  local meter
  if type(DM) ~= "table" or type(DM.GetCombatSessionSourceFromType) ~= "function" then
    meter = "this client has no damage meter"
  elseif type(DM.IsDamageMeterAvailable) == "function" then
    local ok, available, reason = pcall(DM.IsDamageMeterAvailable)
    if not ok then meter = "unreadable"
    elseif available == false then meter = "not available" .. (type(reason) == "string" and reason ~= "" and (" (" .. reason .. ")") or "")
    else meter = "available" end
  else
    meter = "available"
  end
  local spells = open() and spellCount() or 0
  local casts = 0
  if store then
    for _, list in pairs(store) do casts = casts + castsOf(list) end
  end
  lines[1] = string.format("damage meter: %s; recording %s; %d spells, %d casts recorded; %s", meter,
    History.Enabled() and "on" or "off", spells, casts, last)
  return lines
end

-- Every spell with records, for /sdi history list: id, name, casts, damage and healing per cast.
function History.List()
  local out = {}
  for id in pairs(open() and store or {}) do
    local n, d, h = History.Average(id)
    if n then
      local name
      if C_Spell and type(C_Spell.GetSpellName) == "function" then
        local ok, value = pcall(C_Spell.GetSpellName, id)
        if ok and not isSecret(value) and type(value) == "string" then name = value end
      end
      out[#out + 1] = { id = id, name = name, casts = n, damage = d, healing = h }
    end
  end
  table.sort(out, function(a, b) return a.casts > b.casts or (a.casts == b.casts and a.id < b.id) end)
  return out
end

---------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
  if event == "UNIT_SPELLCAST_SUCCEEDED" and type(frame.RegisterUnitEvent) == "function" then
    pcall(frame.RegisterUnitEvent, frame, event, "player")
  else
    pcall(frame.RegisterEvent, frame, event)
  end
end
frame:SetScript("OnEvent", function(_, event, ...)
  History.OnEvent(event, ...)
end)
if BIT.Perf then BIT.Perf.Watch(frame, "OnEvent", "SpellDamageInfo.History") end
