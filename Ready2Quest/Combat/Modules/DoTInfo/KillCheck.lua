-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- DoTInfo: the kill check behind the kill icon. It builds on DoTInfo's DoT tracking (Core.lua).
-- Copyright (c) 2026 Rogerio Camorim. GPL-3.0-or-later, see LICENSE.
--
-- The icon is lit by a StatusBar whose fill is compared to the mob's health by the widget (health is secret in
-- combat), so everything here only decides the number the bar is given:
--   * casts still in progress are left out (an interrupt or a miss would take them back);
--   * the optional weapon hit (settings: swingKill) adds one average swing, wand or ranged shot;
--   * the Kill margin (killMargin, 50-100%) leaves room for heals, regeneration and estimate error;
--   * a mob whose shield absorbed one of our ticks in the last seconds shows no icon (ns.shielded).
local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("DoTInfo")

local ABSORB_SECONDS = 5

-- The damage the kill icon is judged on. `entries` is the DoT breakdown (Core.lua dotBreakdown). The weapon hit is
-- an absolute amount, so it is added only where the health is a real one (`withSwing`): the options preview
-- counts in percent of health and would be lit by it at once.
function ns.lethalDamage(entries, withSwing)
    local sum = 0
    for _, entry in ipairs(entries) do
        -- A cast in progress is left out, but the DoT it would refresh is still ticking (entry.running).
        if not entry.provisional then sum = sum + entry.damage else sum = sum + (entry.running or 0) end
    end
    local db = ns.db
    local margin = math.max(0, math.min(db and tonumber(db.killMargin) or 100, 100)) / 100
    local swing = 0
    if withSwing and db and db.swingKill and sum > 0 then
        local sdi = BIT.modules.SpellDamageInfo
        if type(sdi) == "table" and type(sdi.SwingAverage) == "function" then
            local ok, value = pcall(sdi.SwingAverage)
            if ok and type(value) == "number" then swing = value end
        end
    end
    return (sum + swing) * margin
end

-- Core.lua's check (absorbs, known protection auras) plus what the combat log taught us: an ABSORB on one of our
-- ticks (ns._absorbedAt[mob key], set in onUnitCombat) is readable proof of a shield even when auras are secret.
local baseShielded = ns.shielded
function ns.shielded(unit, entries)
    local absorbedAt = ns._absorbedAt
    if absorbedAt and next(absorbedAt) then
        local now, key = GetTime(), ns.Internals.unitKey(unit)
        for other, at in pairs(absorbedAt) do
            if now - at >= ABSORB_SECONDS then absorbedAt[other] = nil end
        end
        if key and absorbedAt[key] then return true end
    end
    return baseShielded(unit, entries)
end
