-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module DoTInfo: a public API for other addons (unit frames, nameplates, UI suites), so they
-- can show the DoT estimate on their own frames. Adapted from Does It Die v0.9.0's API.lua by Joe Greive (MIT; issue
-- #24 there). The global is Ready2QuestCombat_DoTAPI, not DoesItDie: both addons can be installed together.
-- Usage and the StatusBar trick a consumer needs are in API.md at the repository root.
--
-- What it hands out is the tracking's own numbers: the remaining damage of the player's DoTs on the mob behind a
-- unit token. Those are plain numbers, but the mob's health is secret in Forever, so a consumer can't compare the
-- two either; it feeds both into a StatusBar, as the nameplate marker does.
--
-- Loaded last: Core.lua calls ns.afterRefresh after every refresh to notice changes.
-- Also exposed through Ready2QuestCombat_API.Get("DoT"); the older global stays compatible.

local ADDON_NAME, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("DoTInfo")

local API_VERSION = 2 -- Adds CanTrack and the shared callback bus.
local EVENT = "DOTS_CHANGED"
local bus = BIT.API
local Root = Ready2QuestCombat_API
-- Unit tokens watched for changes while anyone is registered: what UNIT_COMBAT covers, so what tracking can update.
local WATCHED = { "target", "focus" }
for i = 1, 40 do WATCHED[#WATCHED + 1] = "nameplate" .. i end

local api = {}
local lastSeen = {} -- unit token -> "mob key|identity version|total|count" when last reported
local identityVersions = {} -- Forever's reusable fallback keys need their lifecycle too.
bus.DeclareEvent(EVENT, "DoTInfo", ns.trace)

function ns.apiIdentityChanged(unit)
    if type(unit) ~= "string" or (type(issecretvalue) == "function" and issecretvalue(unit)) then return end
    local key = unit == "target" and unit or (unit:match("^nameplate%d+$") and ("plate:" .. unit))
    if key then identityVersions[key] = (identityVersions[key] or 0) + 1 end
end

local function trackedKey(unit)
    if (type(issecretvalue) == "function" and issecretvalue(unit))
        or type(unit) ~= "string" or not ns.db or not BIT.IsRunning("DoTInfo") then return nil end
    local ok, key = pcall(ns.Internals.unitKey, unit)
    if ok and type(key) == "string" then return key end
end

function api.CanTrack(unit)
    if not trackedKey(unit) then return false end
    local ok, exists = pcall(UnitExists, unit)
    return ok and not (type(issecretvalue) == "function" and issecretvalue(exists)) and exists == true
end

-- Total remaining damage of the player's DoTs on the mob behind `unit` (rounded), and how many DoTs that is.
-- 0, 0 when there are none or the unit can't be tracked.
function api.GetRemainingDamage(unit)
    if not trackedKey(unit) then return 0, 0 end
    local list, total = ns.dotBreakdownForUnit(unit)
    return math.floor(total + 0.5), #list
end

-- The player's DoTs on the mob behind `unit`, oldest first: a new list of new tables (safe to keep or change), each
-- { name, spellID, school (bit mask, 1 = Physical), damage (remaining), appliedAt, expiresAt (GetTime() seconds),
-- provisional (true while it's still being cast) }. DoTs still waiting for their first tick aren't in it.
function api.GetDoTs(unit)
    local result = {}
    if not trackedKey(unit) then return result end
    local list = ns.dotBreakdownForUnit(unit)
    for i, entry in ipairs(list) do
        result[i] = { name = entry.name, spellID = entry.spellID, school = entry.school,
            damage = math.floor(entry.damage + 0.5), appliedAt = entry.appliedAt, expiresAt = entry.expiresAt,
            provisional = entry.provisional or false }
    end
    table.sort(result, function(a, b)
        if a.appliedAt ~= b.appliedAt then return a.appliedAt < b.appliedAt end
        return a.name < b.name
    end)
    return result
end

-- func(event, unit) runs whenever the remaining damage on `unit` (target, focus or nameplateN) changes, or the unit
-- now shows another mob; event is "DOTS_CHANGED". One function per owner (any value, e.g. your addon's name or
-- frame): registering again replaces it.
function api.RegisterCallback(owner, func)
    Root.RegisterCallback(owner, EVENT, func)
end

function api.UnregisterCallback(owner)
    Root.UnregisterCallback(owner, EVENT)
end

local function fire(unit)
    bus.Fire(EVENT, unit)
end

-- After every refresh (0.1s, and on casts and ticks): report each watched unit whose numbers or identity changed.
function ns.afterRefresh()
    if not bus.HasListeners(EVENT) then
        if next(lastSeen) then wipe(lastSeen) end
        return
    end
    for _, unit in ipairs(WATCHED) do
        local state
        local exists = UnitExists(unit)
        local key = exists == true and trackedKey(unit)
        if key then
            local total, count = api.GetRemainingDamage(unit)
            state = key .. "|" .. (identityVersions[key] or 0) .. "|" .. total .. "|" .. count
        end
        if state ~= lastSeen[unit] then
            lastSeen[unit] = state
            fire(unit)
        end
    end
end

api.API_VERSION = API_VERSION
Ready2QuestCombat_DoTAPI = api
bus.Register("DoT", api, { module = "DoTInfo" })
