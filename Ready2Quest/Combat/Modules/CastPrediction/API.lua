-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat: the public CastPrediction API. See API.md.
local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("CastPrediction")
local bus = BIT.API
local EVENT = "CAST_PREDICTION_CHANGED"
local FIELDS = { "spellID", "name", "school", "damage", "min", "max", "channel", "instant", "startedAt", "endsAt", "unit" }
local api = { API_VERSION = 1 }
local lastCast, lastState

bus.DeclareEvent(EVENT, "CastPrediction", ns.trace)

local function snapshot(cast, unit)
    local prediction = cast.prediction
    return {
        spellID = cast.spellID,
        name = cast.name,
        school = ns.SCHOOL_MASKS[cast.view.school],
        damage = math.floor(prediction.value + 0.5),
        min = math.floor(prediction.min + 0.5),
        max = math.floor(prediction.max + 0.5),
        channel = cast.channel == true,
        instant = cast.instant == true,
        startedAt = cast.startedAt,
        endsAt = cast.endsAt,
        unit = unit,
    }
end

function api.GetCurrent()
    local cast, unit = ns.apiCast()
    if cast then return snapshot(cast, unit) end
end

function api.GetPredictedDamage(unit)
    if not ns.apiAimedAt(unit) then return 0, 0, 0 end
    local cast = ns.apiCast()
    if not cast then return 0, 0, 0 end
    local prediction = cast.prediction
    return math.floor(prediction.value + 0.5), math.floor(prediction.min + 0.5), math.floor(prediction.max + 0.5)
end

function ns.afterRefresh()
    if not bus.HasListeners(EVENT) then
        lastCast, lastState = nil, nil
        return
    end
    local cast, unit = ns.apiCast()
    local state = cast and snapshot(cast, unit)
    local changed = cast ~= lastCast
    if not changed and state and lastState then
        for _, field in ipairs(FIELDS) do
            if state[field] ~= lastState[field] then changed = true; break end
        end
    end
    if not changed then return end
    if not state then unit = lastState and lastState.unit end
    lastCast, lastState = cast, state
    bus.Fire(EVENT, unit)
end

bus.Register("CastPrediction", api, { module = "CastPrediction" })
