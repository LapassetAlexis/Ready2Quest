-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Shared rogue aura clocks. Identified applications/updates are required; melee hits are not proc signals.
local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("DoTInfo")
local E = { spells = {} }
ns.RogueEffects = E
local retail = ns.Retail ~= nil
local events, status, lastScan = nil, {}, nil

local function add(ids, config)
    for _, id in ipairs(ids) do E.spells[id] = config end
end

add(retail and { 703 } or { 703, 8631, 8632, 8633, 11289, 11290 },
    { familyID = 703, school = 1, manual = true })
add(retail and { 1943 } or { 1943, 8639, 8640, 11273, 11274, 11275 },
    { familyID = 1943, school = 1, manual = true, finisher = true })
if retail then
    add({ 2818 }, { familyID = 2818, descriptionID = 2823, school = 8, poison = true })
    add({ 385627 }, { familyID = 385627, school = 8, poison = true, dynamic = true, refreshOnUpdate = false })
    add({ 360194 }, { familyID = 360194, school = 1 }) -- Deathmark's own bleed, not its damage multiplier.
    add({ 381628 }, { familyID = 381628, school = 1, dynamic = true }) -- Internal Bleeding
    add({ 394021 }, { familyID = 394021, school = 1, dynamic = true }) -- Mutilated Flesh / Doomblade
else
    for auraID, coatingID in pairs({ [2818] = 2823, [2819] = 2824, [11353] = 11355,
        [11354] = 11356, [25349] = 25351 }) do
        add({ auraID }, { familyID = 2818, descriptionID = coatingID, school = 8, poison = true, stacked = true })
    end
end

local function secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function plain(value, kind)
    return not secret(value) and type(value) == kind
end

local function boolean(fn, unit)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, unit)
    if ok and plain(value, "boolean") then return value end
end

-- Leaving our combat does not reset a PvP opponent or an NPC still fighting somebody else.
local function idleNPC(unit)
    return boolean(UnitAffectingCombat, "player") == false
        and boolean(UnitExists, unit) == true and boolean(UnitIsVisible, unit) == true
        and boolean(UnitIsPlayer, unit) == false and boolean(UnitAffectingCombat, unit) == false
end

local function positive(value)
    return plain(value, "number") and value > 0 and value < math.huge
end

function E.Family(spellID)
    local config = plain(spellID, "number") and E.spells[spellID]
    return config and config.familyID
end

local function report(unit, reason)
    if status[unit] == reason then return end
    status[unit] = reason
    ns.TraceRogueAura("ROGUE " .. unit .. ": " .. reason)
end

local function hostile(unit)
    if not plain(unit, "string") or (unit ~= "target" and unit ~= "softenemy"
        and not unit:match("^nameplate%d+$")) then return false end
    local ok, value = pcall(UnitCanAttack, "player", unit)
    return ok and plain(value, "boolean") and value
end

local function normalize(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("\194\160", " "):gsub("\226\128\175", " ")
    local german = text:find("Sek") ~= nil
    local count = 1
    while count > 0 do
        if german then text, count = text:gsub("(%d)%.(%d%d%d)%f[%D]", "%1%2")
        else text, count = text:gsub("(%d),(%d)", "%1%2") end
    end
    if german then text = text:gsub("(%d),(%d)", "%1.%2") end
    return (text:gsub("%d+%.?%d*%s*%%", "")) -- A percentage is not a damage amount.
end

local function auraText(unit, instanceID)
    local getter = C_TooltipInfo and C_TooltipInfo.GetUnitAuraByAuraInstanceID
    if type(getter) ~= "function" then return end
    local ok, text = pcall(function()
        local data = getter(unit, instanceID)
        if not plain(data, "table") or not plain(data.lines, "table") then return end
        local lines = {}
        for _, line in ipairs(data.lines) do
            if not plain(line, "table") or secret(line.leftText) then return end
            if type(line.leftText) == "string" then lines[#lines + 1] = line.leftText end
        end
        return normalize(table.concat(lines, "\n"))
    end)
    if ok then return text end
end

local function periodic(text, duration)
    if not text or not duration then return end
    local amount, interval = text:match("(%d+%.?%d*)[^%d\n]-[Dd]amage%s+every%s+(%d+%.?%d*)%s*sec")
    if not amount then
        interval, amount = text:match("alle%s+(%d+%.?%d*)%s*Sek%a*%.?%s*(%d+%.?%d*)[^%d\n]-[Ss]chaden")
    end
    if not amount then
        amount, interval = text:match("(%d+%.?%d*)[^%d\n]-[Ss]chaden%s+alle%s+(%d+%.?%d*)%s*Sek")
    end
    amount, interval = tonumber(amount), tonumber(interval)
    if positive(amount) and positive(interval) then return amount * duration / interval, interval end
end

local function describe(unit, aura, filtered)
    if not plain(aura, "table") then return nil, "aura data hidden" end
    local spellID = aura.spellId
    if not plain(spellID, "number") then return nil, "aura spell ID hidden" end
    local config = E.spells[spellID]
    if not config then return end
    if not filtered then
        local source = aura.sourceUnit
        if not plain(source, "string") then return nil, "effect owner hidden" end
        if source ~= "player" then return end
        if not plain(aura.isHarmful, "boolean") or not aura.isHarmful then return end
    end
    local instanceID = aura.auraInstanceID
    if not positive(instanceID) then return nil, "effect instance ID hidden" end
    local previous = ns.RogueAuraPrevious(unit, config.familyID)
    if previous and previous.auraInstanceID and previous.auraInstanceID ~= instanceID then previous = nil end
    local name = C_Spell.GetSpellName(spellID)
    if not plain(name, "string") then return nil, "effect name unavailable" end
    local desc = C_Spell.GetSpellDescription(config.descriptionID or spellID)
    local total, _, duration, interval = ns.ParseRogueAura(spellID, desc, config)
    local actualDuration = positive(aura.duration) and aura.duration or nil
    local clockDuration = actualDuration or duration or (previous and previous.duration)
    local text = auraText(unit, instanceID)
    local currentTotal, currentInterval = periodic(text, clockDuration)
    local currentDuration = clockDuration
    if not currentTotal and text then
        currentTotal, _, currentDuration, currentInterval = ns.ParseRogueAura(spellID, text, config)
        if currentTotal then clockDuration = actualDuration or currentDuration end
    end
    local keepTicks, stacks
    if currentTotal then
        -- The aura tooltip already describes its current stacks/scaling; never multiply it again.
        total, duration, interval = currentTotal, currentDuration, currentInterval
        -- A bleed that already matched real ticks keeps its learned (AP-adjusted) size: the
        -- description-derived reading would drop it to a prediction (ObserveRogueAura's
        -- non-keepTicks path) and the remaining ticks would stop matching. A dot with no
        -- tick yet (a fresh cast) takes the aura's reading as before.
        if previous and not retail and not previous.predictionOnly
            and (previous.ticksSeen or 0) > 0 then keepTicks = true end
    elseif config.dynamic then
        return nil, "current effect damage unavailable" -- Talent percentages are not current periodic damage.
    elseif config.stacked then
        stacks = aura.applications
        if not plain(stacks, "number") or stacks < 0 or stacks > 5 or stacks ~= math.floor(stacks) then
            return nil, "effect stacks hidden"
        end
        stacks = math.max(1, stacks)
        if total then total = total * stacks end
        duration = actualDuration or duration
    elseif config.poison then
        duration = actualDuration or duration
    elseif previous then
        total, duration = previous.total, previous.duration
        clockDuration = actualDuration or duration
        keepTicks = not retail and not previous.predictionOnly
    end
    if not positive(total) or not positive(duration) or not positive(clockDuration) then
        return nil, "effect damage/duration unavailable"
    end
    return { spellID = spellID, familyID = config.familyID, auraInstanceID = instanceID,
        name = name, total = total, school = config.school, duration = duration, clockDuration = clockDuration,
        interval = interval, poison = config.poison, manual = config.manual, stacks = stacks,
        refreshOnUpdate = config.refreshOnUpdate ~= false, keepTicks = keepTicks,
        expirationTime = positive(aura.expirationTime) and aura.expirationTime or nil }
end

local function observe(unit, aura, filtered, signal, seen)
    local info, reason = describe(unit, aura, filtered)
    if reason then return reason end
    if not info then return end
    if seen then seen[info.familyID] = true end
    if ns.ObserveRogueAura(unit, info, signal) then
        report(unit, info.expirationTime and "clock synchronized" or "own clock running")
    else report(unit, "waiting for a readable effect application") end
end

local function scan(unit)
    local seen = {}
    local ok, reason = pcall(function()
        if not C_UnitAuras then return "aura API unavailable" end
        local auras
        if type(C_UnitAuras.GetUnitAuras) == "function" then
            auras = C_UnitAuras.GetUnitAuras(unit, "HARMFUL|PLAYER")
        elseif type(C_UnitAuras.GetAuraDataByIndex) == "function" then
            auras = {}
            for index = 1, 255 do
                local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HARMFUL|PLAYER")
                if not secret(aura) and aura == nil then break end
                auras[#auras + 1] = aura
            end
        else return "aura API unavailable" end
        if not plain(auras, "table") then return "aura list hidden" end
        local unavailable
        for _, aura in ipairs(auras) do unavailable = observe(unit, aura, true, false, seen) or unavailable end
        return unavailable
    end)
    if not ok then reason = "aura access denied" end
    if reason then report(unit, reason) end
    -- An idle, visible NPC has left combat even when Retail still restricts its aura list.
    -- Keep effects actually read in a partial scan; an unavailable scan alone never clears PvP/combat.
    local resetReason = idleNPC(unit) and (reason and "aura unavailable" or "aura absent") or nil
    if not reason or resetReason then ns.RemoveRogueAuras(unit, seen, nil, resetReason) end
end

function E.Refresh(unitKey)
    if not events or ns.off then return end
    if retail and boolean(UnitAffectingCombat, "player") ~= false then return end
    local now = GetTime()
    if lastScan and now - lastScan < 0.25 then return end
    lastScan = now
    local seen = {}
    local function check(unit)
        if not hostile(unit) then return end
        if retail and not idleNPC(unit) then return end
        local key = unitKey(unit)
        if key and not seen[key] then
            seen[key] = true
            scan(unit) -- A scan uses the real expiry; it never restarts an existing hidden clock.
        end
    end
    check("target")
    check("softenemy")
    for i = 1, 40 do check("nameplate" .. i) end
end

function E.AfterCast(key, spellID, unitKey)
    if not events or not E.Family(spellID) then return end
    -- Aura updates can precede SUCCEEDED; synchronize after its estimate replaces the old DoT.
    for _, unit in ipairs({ "target", "softenemy" }) do
        if hostile(unit) and unitKey(unit) == key then scan(unit); return end
    end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if hostile(unit) and unitKey(unit) == key then scan(unit); return end
    end
end

local function update(unit, updateInfo)
    if not hostile(unit) then return end
    local ok, reason = pcall(function()
        if not plain(updateInfo, "table") or secret(updateInfo.isFullUpdate) then return "aura update hidden" end
        if updateInfo.isFullUpdate then scan(unit); return end
        local added, updated, removed = updateInfo.addedAuras,
            updateInfo.updatedAuraInstanceIDs, updateInfo.removedAuraInstanceIDs
        if secret(added) or secret(updated) or secret(removed) then return "aura update hidden" end
        local unavailable
        for _, aura in ipairs(added or {}) do unavailable = observe(unit, aura, false, "added") or unavailable end
        for _, id in ipairs(updated or {}) do
            if not positive(id) then unavailable = "effect instance ID hidden"
            elseif C_UnitAuras and type(C_UnitAuras.GetAuraDataByAuraInstanceID) == "function" then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
                -- shortcut: hidden expiration makes a refreshable aura's identified update a refresh signal;
                -- live testing must distinguish refreshes from other updates of that same aura.
                if secret(aura) then unavailable = "aura data hidden"
                elseif aura ~= nil then unavailable = observe(unit, aura, false, "updated") or unavailable end
            else unavailable = "aura API unavailable" end
        end
        local ids = {}
        for _, id in ipairs(removed or {}) do if positive(id) then ids[id] = true end end
        ns.RemoveRogueAuras(unit, nil, ids)
        return unavailable
    end)
    if not ok then reason = "aura access denied" end
    if reason then scan(unit) end
end

function E.Start(unitKey)
    if events or ns.off or not ns.db then return end
    local ok, _, class = pcall(UnitClass, "player")
    if not ok or secret(class) or class ~= "ROGUE" then return end
    events = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD",
        "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_REGEN_ENABLED" }) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event, unit, updateInfo)
        if event == "PLAYER_REGEN_ENABLED" then
            lastScan = nil
            E.Refresh(unitKey) -- Nameplates can outlive the target lost on Vanish.
        elseif event == "UNIT_AURA" then update(unit, updateInfo)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if plain(unit, "string") then status[unit] = nil end
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            if hostile(unit) then scan(unit) end
        else
            wipe(status)
            for _, token in ipairs({ "target", "softenemy" }) do if hostile(token) then scan(token) end end
            if event == "PLAYER_ENTERING_WORLD" then
                for i = 1, 40 do
                    local token = "nameplate" .. i
                    if hostile(token) then scan(token) end
                end
            end
        end
    end)
end
