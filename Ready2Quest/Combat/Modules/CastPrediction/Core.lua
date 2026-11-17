-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module CastPrediction: while a damage spell with a cast time is on its
-- way to the target, show the damage it is expected to deal as a marker on matching unit frames
-- and the target's nameplate -- the same idea as DoTInfo's remaining-DoT marker, for spells that
-- are not DoTs (Frostbolt, Fireball, Pyroblast, Shadow Bolt, Lightning Bolt, ...). Channels show
-- the damage remaining over their readable channel time; their ticks never calibrate a whole cast.
--
-- A prediction, not a promise: the cast's damage is a range (the description's own numbers plus
-- the player's spell power), and critical strikes, procs and partial resists cannot be predicted.
-- What stays readable on WoW: Forever (target health, player stats and auras are secret in
-- combat):
--   * our own casts (UNIT_SPELLCAST_START/STOP/SUCCEEDED) and the spell description -> the damage
--     range and the school (through the SpellDamageInfo module's parser and coefficient tables)
--   * UNIT_COMBAT amounts on units -> the hits that actually land, which calibrate the estimate
-- StatusBars accept secret values, so the "this cast would be lethal" comparison is done by the
-- widget, not by Lua (see the kill icon notes in the Display section).

local ADDON_NAME, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("CastPrediction")

local UPDATE_INTERVAL = 0.1
local MAX_PLATES = 40
local CAST_MAX_SECONDS = 15 -- a lost end event never leaves a marker behind
local CAST_STOP_GRACE = 0.5 -- STOP and SUCCEEDED can arrive in either order, a hair apart
local PROJECTILE_GRACE = 1.5 -- keep the marker after a successful cast while the hit flies in
local LANDED_GRACE = 0.35 -- a landed hit flashes and the marker lingers this long
local RECHECK = 5 -- re-read a spell's description no more often than this
-- Calibration from UNIT_COMBAT hits: a hit is this spell's when its amount sits within the
-- predicted range with tolerance, or within the crit band of the prediction (crits still count
-- as "landed", they just never teach the estimate).
local LEARN_TOLERANCE = 0.35
local CRIT_MIN_RATIO, CRIT_MAX_RATIO = 1.3, 2.3
-- The learned factor of a spell is the running mean of what its hits say (each hit a sample of the true factor),
-- weighted 1/n until LEARN_FLOOR, so a long-lived factor still follows gear and buff changes (a smaller floor
-- steadies it, a larger one follows a change sooner: 0.2 is about nine hits' memory). LEARN_SHRINK is how many
-- samples' worth of "no information" (a factor of 1) a cast's number is pulled toward: one hit of a spell that rolls
-- 14-23 must not swing the estimate by the full roll.
local LEARN_FLOOR = 0.2
local LEARN_SHRINK = 2
local LEARN_MIN_FACTOR, LEARN_MAX_FACTOR = 0.25, 4
local LEARN_SCHEMA = 2 -- entries saved by the first versions carry no `v`: see ensureDB
local LEARNED_LINES_MAX = 40 -- chat lines /upt castpred learned prints
local COMBAT_FRAME = 0.05 -- two UNIT_COMBAT events this close are one hit on several unit tokens
local MAX_LOG = 500

-- School names (SpellDamageInfo's parser) to the bit the combat log/UNIT_COMBAT reports.
local SCHOOL_MASKS = {
    physical = 1, holy = 2, fire = 4, nature = 8, frost = 16, shadow = 32, arcane = 64,
    -- A combined school reports as one of its parts or as the whole; a hit on any of them was this cast's.
    frostfire = 4 + 16, spellfire = 64 + 4, spellfrost = 64 + 16, shadowfrost = 32 + 16, shadowflame = 32 + 4,
    chimeral = 64 + 4 + 16, chaos = 127,
}
ns.SCHOOL_MASKS = SCHOOL_MASKS

-- Is every school of the reported mask one of the expected cast's?
local function schoolMatches(expects, mask)
    local covered = 0
    for _, bit in ipairs({ 1, 2, 4, 8, 16, 32, 64 }) do
        if math.floor(mask / bit) % 2 == 1 and math.floor(expects / bit) % 2 == 1 then covered = covered + bit end
    end
    return covered > 0 and covered == mask
end

-- User options (edited in the module's settings tab, saved in Ready2QuestCombatDB).
local DEFAULTS = {
    -- The marker on the target frame's health bar
    showMarker = true,
    showTargetFrame = true,
    showFocusFrame = true,
    targetOverMouseover = false, -- a same-named mob under the mouse doesn't blank a target cast (findRecipient)
    showPartyFrames = true,
    showRaidFrames = true,
    showNameplates = true,
    showManaCost = true,
    fillColor = "school",
    fillOpacity = 45,
    outlineStyle = "solid",
    outlineColor = "white",
    outlineOpacity = 100,
    pulseOutline = true,
    showKillIcon = true,
    killIcon = "skull",
    showKillSpellIcon = true,
    killIconSize = 40,
    killIconPosition = "portrait",
    killIconOffsetX = 0,
    killIconOffsetY = 0,
    -- The label
    showLabel = true,
    labelMode = "amount",  -- amount | range | percent
    labelPosition = "center",
    labelSize = 10,
    labelColor = "white",
    -- Nameplates: their own look, since enemy plates are red. Defaults read well on red.
    nameplateMode = "marker", -- off | marker | markerIcon
    plateFillColor = "school",
    plateFillOpacity = 45,
    plateOutlineStyle = "solid",
    plateOutlineColor = "white",
    plateOutlineOpacity = 100,
    plateIconSize = 24,
    plateIconPosition = "left", -- the level badge sits right of the bar on Forever's plates
    plateIconOffsetX = 0,
    plateIconOffsetY = 15,
    -- The prediction itself
    estimate = "average", -- average | min | max
    learn = true,         -- calibrate the estimate from hits seen in combat
    useTalents = true,    -- multiply Forever casts by the detected passive talent percents
    useAuras = true,      -- multiply by readable buffs and target debuffs
    castOnly = true,      -- only spells that are actually cast (not instant casts)
    finisherPreview = true, -- show what the finisher on your action bars would deal at the current combo points
    -- Fill textures (the shared catalog, Core/Looks.lua): a cast, a channel, and the finisher preview each have their own
    castTexture = "flat",
    channelTexture = "dash_v",
    finisherTexture = "fire_v", -- Flame (top to bottom): a texture with its own colours
    finisherColor = "school",
    finisherOpacity = 70,
    manualPower = false,  -- use manualPowerValue instead of the client's spell power reading
    manualPowerValue = 0,
    debug = false,
}

local COLOR_PRESETS = {
    { id = "purple", label = "Purple", rgb = { 0.7, 0.3, 1 } },
    { id = "gold",   label = "Gold",   rgb = { 1, 0.85, 0.1 } },
    { id = "white",  label = "White",  rgb = { 1, 1, 1 } },
    { id = "red",    label = "Red",    rgb = { 1, 0.2, 0.2 } },
    { id = "orange", label = "Orange", rgb = { 1, 0.55, 0.1 } },
    { id = "green",  label = "Green",  rgb = { 0.3, 1, 0.3 } },
    { id = "cyan",   label = "Cyan",   rgb = { 0.2, 0.9, 1 } },
    { id = "pink",   label = "Pink",   rgb = { 1, 0.45, 0.6 } },
    { id = "black",  label = "Black",  rgb = { 0, 0, 0 } },
}
local COLOR_BY_ID = {}
for _, preset in ipairs(COLOR_PRESETS) do COLOR_BY_ID[preset.id] = preset.rgb end
-- The shared palette (Core/Looks.lua) adds the colours these nine do not have; a saved "#rrggbb" id is read by colorOf.
do
    for _, preset in ipairs(BIT.Looks and BIT.Looks.Palette or {}) do
        if not COLOR_BY_ID[preset.id] then
            COLOR_PRESETS[#COLOR_PRESETS + 1] = preset
            COLOR_BY_ID[preset.id] = preset.rgb
        end
    end
end
local COLOR_LIST = {}
for _, preset in ipairs(COLOR_PRESETS) do COLOR_LIST[#COLOR_LIST + 1] = { id = preset.id, label = preset.label } end

local KILL_ICONS = {
    { id = "skull",  label = "Raid skull",  path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    { id = "cross",  label = "Red X",       path = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
    { id = "impact", label = "Impact",      path = "Interface\\SpellShadow\\Spell_Shadow_Shadowfury" },
}

local settings

local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffbb33CastPrediction|r " .. msg)
end

-- Always recorded to SavedVariables (settings.log) for diagnosing accuracy; echoed to chat with
-- /upt castpred debug, like DoTInfo does.
local function trace(msg)
    if not settings then return end
    table.insert(settings.log, string.format("%.1f %s", GetTime(), msg))
    if #settings.log > MAX_LOG then table.remove(settings.log, 1) end
    if settings.debug then print("|cff888888" .. msg .. "|r") end
end
ns.trace = trace

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

local function number(v)
    return not isSecret(v) and type(v) == "number" and v or nil
end

local function read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not isSecret(value) then return value end
end

-- A plate keeps its key until removal, even if one token's GUID becomes hidden.
local plateKeys, plateSerial = {}, 0
local function plateToken(unit)
    if unit:match("^nameplate%d+$") then return unit end
    local plate = read(C_NamePlate and C_NamePlate.GetNamePlateForUnit, unit)
    if type(plate) == "table" then
        local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if not isSecret(token) and type(token) == "string" and token:match("^nameplate%d+$") then return token end
    end
    for i = 1, 40 do
        local token = "nameplate" .. i
        if read(UnitIsUnit, token, unit) == true then return token end
    end
end

local warnedSecretGuid = false
local unitKey -- memoised below (computeUnitKey calls it for the target)
local function computeUnitKey(unit)
    if isSecret(unit) or type(unit) ~= "string" or read(UnitExists, unit) ~= true then return end
    local guid = read(UnitGUID, unit)
    local token = plateToken(unit)
    if token then
        if not plateKeys[token] then
            local plateGUID = read(UnitGUID, token)
            if type(plateGUID) == "string" then
                plateKeys[token] = plateGUID
            elseif type(guid) == "string" then
                plateKeys[token] = guid
            else
                plateSerial = plateSerial + 1
                plateKeys[token] = "cast-plate:" .. plateSerial
            end
        end
        return plateKeys[token]
    end
    if type(guid) == "string" then return guid end
    if unit ~= "target" and read(UnitIsUnit, unit, "target") == true then return unitKey("target") end
    if unit ~= "target" then return nil end
    if not warnedSecretGuid then
        warnedSecretGuid = true
        trace("Target GUID is secret; the current target's own token is used as the key")
    end
    return "target"
end

-- A refresh asks for the key of the same unit up to four times (the preview, the marker, the plates, the recipient search) and
-- a key costs a scan of the 40 plates when the unit has none: the answer is kept for the frame it was read in, and dropped when
-- any event arrives (a new target, a plate coming or going), so it never outlives a change.
local keyMemo, keyMemoAt = {}, nil
unitKey = function(unit)
    if isSecret(unit) or type(unit) ~= "string" then return end
    local now = GetTime()
    if keyMemoAt ~= now then
        for k in pairs(keyMemo) do keyMemo[k] = nil end
        keyMemoAt = now
    end
    local hit = keyMemo[unit]
    if hit ~= nil then return hit or nil end
    local key = computeUnitKey(unit)
    keyMemo[unit] = key or false
    return key
end
ns.ForgetUnitKeys = function() keyMemoAt = nil end

local function targetIsDead()
    local ok, dead = pcall(UnitIsDead, "target")
    return ok and not isSecret(dead) and dead
end

---------------------------------------------------------------------------------------------
-- Spell data (through the SpellDamageInfo module: its parser, coefficients and spell power)
---------------------------------------------------------------------------------------------

local function sdi()
    local module = BIT.modules and BIT.modules.SpellDamageInfo
    if type(module) ~= "table" or type(module.Parser) ~= "table" or type(module.Estimate) ~= "table" then return nil end
    return module
end

local function isRetail()
    local module = sdi()
    return (module and type(module.IsRetail) == "function" and module.IsRetail()) and true or false
end

local function spellName(spellID)
    local fn = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if type(fn) ~= "function" then return nil end
    local ok, name = pcall(fn, spellID)
    if ok and not isSecret(name) and type(name) == "string" then return name end
    return nil
end

local function spellTexture(spellID)
    if isSecret(spellID) or type(spellID) ~= "number" then return nil end
    local fn = C_Spell and C_Spell.GetSpellTexture
    if type(fn) == "function" then
        local ok, texture = pcall(fn, spellID)
        if ok and not isSecret(texture) and (type(texture) == "number" or type(texture) == "string") then
            return texture
        end
    end
    if type(GetSpellTexture) == "function" then
        local ok, texture = pcall(GetSpellTexture, spellID)
        if ok and not isSecret(texture) and (type(texture) == "number" or type(texture) == "string") then
            return texture
        end
    end
    return nil
end

local function getDescription(spellID)
    local fn = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if type(fn) ~= "function" then return nil end
    local ok, text = pcall(fn, spellID)
    if not ok or isSecret(text) or type(text) ~= "string" or text == "" then return nil end
    return text
end

local loadRequested = {}
local function requestLoad(spellID)
    if loadRequested[spellID] then return end
    loadRequested[spellID] = true
    if C_Spell and type(C_Spell.RequestLoadSpellData) == "function" then
        pcall(C_Spell.RequestLoadSpellData, spellID)
    elseif type(RequestLoadSpellData) == "function" then
        pcall(RequestLoadSpellData, spellID)
    end
end

local function getCastTime(spellID)
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and not isSecret(info) and type(info) == "table" then
            local ms = number(info.castTime)
            if ms then return ms / 1000 end
        end
    end
    if type(GetSpellInfo) == "function" then
        local ok, _, _, _, ms = pcall(GetSpellInfo, spellID)
        if ok then
            ms = number(ms)
            if ms then return ms / 1000 end
        end
    end
    return nil
end

-- Last readable spell power by school index (2..7). In combat the client may return secret
-- values; then the last value read out of combat stays in use (as SpellDamageInfo does).
local bonusDamage = {}
local bonusReadAt = 0
local function readBonus()
    local now = GetTime()
    if now - bonusReadAt < 1 and next(bonusDamage) then return end
    bonusReadAt = now
    if type(GetSpellBonusDamage) ~= "function" then return end
    for i = 2, 7 do
        local v = number(read(GetSpellBonusDamage, i))
        if v then bonusDamage[i] = v end
    end
end

-- The parsed view of a spell: { min, max, school, name, castTime, estimated, coefUsed } or false
-- when the spell has no direct damage in its description (a pure DoT, a heal, a utility spell).
-- Cached; a text that cannot be read now leaves the last reading in use.
local viewCache = {}
local function invalidateView()
    for _, cached in pairs(viewCache) do cached.checked = -math.huge end
    bonusReadAt = -math.huge
end
ns.InvalidateView = invalidateView

local function buildView(spellID, channel)
    if isSecret(spellID) or type(spellID) ~= "number" then return false end
    local cacheKey = channel and (spellID .. ":channel") or spellID
    local cached = viewCache[cacheKey]
    if cached and not isSecret(cached.checked) and GetTime() - cached.checked < RECHECK then
        return cached.view
    end
    local module = sdi()
    if not module then return false end
    local text = getDescription(spellID)
    if not text then
        requestLoad(spellID)
        text = cached and cached.text
        if not text then return false end
    end
    -- A selected enemy does not establish who stands inside a ground/area channel.
    if channel then
        local lower = string.lower(text)
        for _, phrase in ipairs({ "target area", "nearby enemies", "all enemies", "zielgebiet", "umkreis" }) do
            if lower:find(phrase, 1, true) then return false end
        end
    end
    local entry = module.Parser.Read(text, module.DescriptionLang and module.DescriptionLang() or nil, isRetail())
    local parsed = entry and (entry.show == "special" and entry.special or entry.parsed)
    if parsed and ((parsed.hits and not channel) or parsed.perAttack or parsed.perBlock
        or parsed.perStrike or parsed.every or parsed.first) then return false end
    local view = false
    if parsed and (parsed.direct or (channel and parsed.dot)) then
        local castTime = getCastTime(spellID)
        local coef = module.SpellCoefficientsFor and module.SpellCoefficientsFor(spellID) or nil
        local bonus
        if not isRetail() and settings and settings.manualPower then
            local perSchool = tonumber(settings.manualPowerValue)
            bonus = perSchool and perSchool > 0 and perSchool or nil
        elseif not isRetail() then
            readBonus()
            bonus = module.Estimate.DamageBonus(parsed.school, bonusDamage)
        end
        -- On Retail the description's numbers already hold the player's spell power.
        -- A scripted volley has no reliable cast-time coefficient for its triggered bolts.
        if parsed.hits and not coef then bonus = nil end
        local applied = module.Estimate.Apply(parsed, castTime, bonus, nil, coef)
        local direct = applied and applied.direct
        local periodic = channel and applied and applied.dot
        if direct or periodic then
            local total = periodic and periodic.total or 0
            view = {
                min = (direct and direct.min or 0) + total,
                max = (direct and direct.max or 0) + total,
                school = parsed.school or applied.school,
                name = spellName(spellID) or parsed.name,
                castTime = castTime,
                estimated = applied.estimated and true or false,
                channelHits = channel and parsed.hits or nil,
            }
        end
    end
    viewCache[cacheKey] = { view = view, text = text, checked = GetTime() }
    if view then
        trace(string.format("SPELL %s (id %d): %d-%d %s%s", tostring(view.name), spellID, math.floor(view.min + 0.5),
            math.floor(view.max + 0.5), tostring(view.school), view.estimated and " (with spell power)" or ""))
    end
    return view
end

ns.BuildView = buildView

---------------------------------------------------------------------------------------------
-- Calibration: hits seen in combat adjust the estimate
---------------------------------------------------------------------------------------------

local function learnedEntry(spellID)
    local entry = settings.learned[spellID]
    if type(entry) ~= "table" then return nil end
    return entry
end

-- How many hits the factor of a spell rests on, nil when none (a spell only refused has an entry and no hits).
local function learnedSamples(spellID)
    local entry = learnedEntry(spellID)
    local samples = entry and tonumber(entry.samples)
    return samples and samples > 0 and samples or nil
end

local function clampFactor(factor)
    if factor < LEARN_MIN_FACTOR then return LEARN_MIN_FACTOR end
    if factor > LEARN_MAX_FACTOR then return LEARN_MAX_FACTOR end
    return factor
end

-- Whether this spell's hits teach its factor. Forever: every school. Retail: direct physical hits only. A Retail
-- description holds the player's own numbers (spell power, talents), not the armor of the target, which takes a share
-- off a direct physical hit and is not readable for an enemy: a hunter's Steady Shot read 86 and hit for 60, 61 and 60,
-- the next one read 101 and hit for 69, then 115 for 80 and 81 (a saved Retail log): 0.70 each time. Magic is not
-- reduced by armor, so there the description stays as it is.
local function learnsFrom(spellID)
    if not settings or not settings.learn then return false end
    if not isRetail() then return true end
    local cached = viewCache[spellID]
    local view = cached and cached.view
    return type(view) == "table" and view.school == "physical"
end

-- The factor one spell is scaled by: its own hits (a running mean, weighted as that many samples) pulled toward 1
-- by LEARN_SHRINK samples' worth.
local function factorFor(spellID)
    if not settings or not settings.learn then return 1 end
    local entry = learnedEntry(spellID)
    local own, samples = entry and tonumber(entry.factor), entry and tonumber(entry.samples) or 0
    if not own or samples <= 0 then return 1 end
    return clampFactor((own * samples + LEARN_SHRINK) / (samples + LEARN_SHRINK))
end

-- The prediction the marker shows: { min, max, value } scaled by what earlier hits taught, by
-- the passive talent percents the client reports (Forever only; Retail descriptions hold them),
-- and by readable buffs and target debuffs (Arcane Power, Improved Scorch,
-- ...; an aura the client will not show, or a Forever combat with hidden auras, adds nothing).
local function predictionFor(view, spellID)
    if not view then return nil end
    local factor = (not isRetail() or view.school == "physical") and factorFor(spellID) or 1
    local min, max = view.min * factor, view.max * factor
    local talentPercent = 0
    if ns.Talents and type(ns.Talents.MultiplierFor) == "function" then
        local okTalents, mult, percent = pcall(ns.Talents.MultiplierFor, view.name, view.school, nil, spellID)
        if okTalents and type(mult) == "number" and mult > 0 then
            min, max = min * mult, max * mult
            talentPercent = type(percent) == "number" and percent or 0
        end
    end
    local auraPercent = 0
    if ns.Auras and type(ns.Auras.MultiplierFor) == "function" then
        local okAuras, amult, apercent = pcall(ns.Auras.MultiplierFor, view.name, view.school)
        if okAuras and type(amult) == "number" and amult > 0 then
            min, max = min * amult, max * amult
            auraPercent = type(apercent) == "number" and apercent or 0
        end
    end
    local value
    if settings.estimate == "min" then
        value = min
    elseif settings.estimate == "max" then
        value = max
    else
        value = (min + max) / 2
    end
    return { min = min, max = max, value = value, factor = factor, talentPercent = talentPercent,
        auraPercent = auraPercent, samples = learnedSamples(spellID) }
end

-- What a cast of this spell is expected to do at once, { min, max, value, ... }, or nil for a heal, a pure DoT, a
-- utility spell or a text that is not read as plain direct damage. TriggerGlow compares it with the target's health.
function ns.PredictDirect(spellID)
    if not settings then return nil end
    local view = buildView(spellID, false)
    if not view then return nil end
    return predictionFor(view, spellID)
end

-- A cast the estimate cannot learn from: damage of its school landed within reach of the prediction, yet no hit
-- matched it (a factor too far from 1 for the window), or a hit matched but fell outside the window. Only counted,
-- so that /upt castpred learned can show a spell that never learns. A cast whose own hit did match is never counted
-- for the other damage of its school that lands meanwhile (a DoT's tick).
local function noteRefused(spellID)
    if not learnsFrom(spellID) then return end
    local entry = learnedEntry(spellID)
    if not entry then
        entry = { factor = 1, samples = 0, v = LEARN_SCHEMA }
        settings.learned[spellID] = entry
    end
    entry.refused = (tonumber(entry.refused) or 0) + 1
end

-- A non-crit hit of `amount` teaches the factor; a hit outside the window is refused (someone
-- else's damage, or a wildly different rank). Crits only prove the cast landed. expected is the middle of the
-- predicted range and applied the factor the prediction was scaled by: the hit says what the factor should have
-- been (ratio * applied), which is what the running mean takes in. (Blending the ratio itself into the factor,
-- as the first versions did, settles on the square root of the truth.)
local function noteHit(spellID, amount, isCrit, expected, applied)
    if not learnsFrom(spellID) then return end -- Retail: physical only, see learnsFrom
    local view = viewCache[spellID] and viewCache[spellID].view
    if type(amount) ~= "number" or amount <= 0 then return end
    if isCrit then return end
    expected = tonumber(expected) or (view and ((view.min + view.max) / 2)) or nil
    if not expected or expected <= 0 then return end
    local ratio = amount / expected
    -- Outside the window it is someone else's damage or a wildly different rank; refuse it
    -- (crits already left above: only the marked CRITICAL flag is trusted for those).
    if ratio < 1 - LEARN_TOLERANCE or ratio > 1 + LEARN_TOLERANCE then
        noteRefused(spellID)
        return
    end
    local entry = learnedEntry(spellID)
    if not entry then
        entry = { factor = 1, samples = 0, v = LEARN_SCHEMA }
        settings.learned[spellID] = entry
    end
    local target = clampFactor(ratio * (tonumber(applied) or 1))
    local samples = (tonumber(entry.samples) or 0) + 1
    local own = tonumber(entry.factor) or 1
    if samples == 1 then
        own = target
    else
        own = own + (target - own) * math.max(1 / samples, LEARN_FLOOR)
    end
    entry.factor = clampFactor(own)
    entry.samples = samples
    entry.v = LEARN_SCHEMA
    trace(string.format("LEARN %s: hit %d vs expected %d -> factor %.2f (%d sample(s))",
        spellName(spellID) or tostring(spellID), math.floor(amount + 0.5), math.floor(expected + 0.5),
        entry.factor, entry.samples))
end

-- What the hits have taught, one chat line per spell: the factor (a cast shows it pulled toward 1 by two hits'
-- worth), how many hits it rests on, and how many hits were too far from the estimate to learn from.
function ns.LearnedLines()
    local lines = {}
    if not settings or type(settings.learned) ~= "table" then return lines end
    local ids = {}
    for id, entry in pairs(settings.learned) do
        if type(entry) == "table" and type(id) == "number" then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for index, id in ipairs(ids) do
        if index > LEARNED_LINES_MAX then
            lines[#lines + 1] = string.format(BIT.L("... and %d more"), #ids - LEARNED_LINES_MAX)
            break
        end
        local entry = settings.learned[id]
        local refused = tonumber(entry.refused) or 0
        lines[#lines + 1] = string.format(BIT.L("%s (%d): x%.2f from %d hit(s)%s"), spellName(id) or "?", id,
            tonumber(entry.factor) or 1, tonumber(entry.samples) or 0,
            refused > 0 and string.format(BIT.L(", %d hit(s) too far from the estimate to learn from"), refused) or "")
    end
    if #lines == 0 then lines[1] = BIT.L("Nothing learned yet: cast damage spells at an enemy.") end
    return lines
end

function ns.resetLearned()
    if not settings then return end
    settings.learned = {}
    trace("learned factors cleared")
    print(BIT.L("Learned factors cleared."))
end

---------------------------------------------------------------------------------------------
-- The cast in progress
---------------------------------------------------------------------------------------------

-- One cast at a time (the player has one cast bar): { key, spellID, name, view, prediction,
-- startedAt, castGUID, stoppedAt, succeededAt, landedAt }
local castInProgress
local lastCombatAt, combatFrameHits = 0, {}

-- A finisher preview is not a cast: what the finisher on the action bars would deal to the target at the combo points
-- it has right now, drawn like a cast prediction. It is never matched against hits and never teaches the estimate
-- (see refreshFinisherPreview). The display code draws shownCast(), the cast logic keeps castInProgress.
local finisherPreview
local finisherScan = { at = -math.huge, dirty = true } -- the bars are re-read when they or the spellbook change
local function shownCast() return castInProgress or finisherPreview end

local function sameCast(cast, castGUID, spellID)
    if not cast then return false end
    local readable = not isSecret(castGUID) and type(castGUID) == "string" and castGUID or nil
    if readable and type(cast.castGUID) == "string" then return readable == cast.castGUID end
    return not isSecret(spellID) and cast.spellID == spellID
end

local function hostileTarget(unit)
    unit = unit or "target"
    return read(UnitExists, unit) == true and read(UnitCanAttack, "player", unit) == true
        and read(UnitIsDeadOrGhost, unit) ~= true
end

local function selectedEnemy()
    if hostileTarget("target") then return "target" end
    return hostileTarget("softenemy") and "softenemy" or nil
end

-- The units a cast can be aimed at decide: the hard target, or focus/mouseover through a macro (two of
-- them with the cast's name but different mobs = unknown). The soft enemy only counts without a hard
-- target. Nameplates are asked only when none of those has the name, and then just one may: other
-- mobs that merely share the name (a wolf pack) must not make an ordinary target cast unknown.
local function findRecipient(name)
    -- Blizzard's own Mouseover Cast: the mob under the mouse takes the cast, same-named target or not.
    local hovered = BIT.Plate and BIT.Plate.MouseoverCastUnit and BIT.Plate.MouseoverCastUnit(name)
    if hovered then return hovered end
    if isSecret(name) or type(name) ~= "string" or name == "" then return selectedEnemy() end
    local found
    local function consider(unit)
        if not hostileTarget(unit) or read(UnitName, unit) ~= name then return true end
        if found and read(UnitIsUnit, unit, found) ~= true then return false end
        found = found or unit
        return true
    end
    local hardTarget = hostileTarget("target")
    -- targetOverMouseover: the mouseover only counts when nothing else has the name.
    local mouseoverLast = settings and settings.targetOverMouseover
    for _, unit in ipairs(mouseoverLast and { "target", "focus", "softenemy", "mouseover" }
        or { "target", "focus", "mouseover", "softenemy" }) do
        if unit == "mouseover" and mouseoverLast and found then return found end
        if not (unit == "softenemy" and hardTarget) and not consider(unit) then return nil end
    end
    if found then return found end
    for i = 1, MAX_PLATES do
        if not consider("nameplate" .. i) then return nil end
    end
    return found
end

local function unitMatchesKey(unit, key)
    if unitKey(unit) == key then return true end
    return key == "target" and read(UnitIsUnit, unit, "target") == true
end

local function findUnitByKey(key)
    if not key then return end
    for _, unit in ipairs({ "target", "focus", "mouseover", "softenemy" }) do
        if read(UnitExists, unit) == true and unitMatchesKey(unit, key) then return unit end
    end
    for i = 1, MAX_PLATES do
        local unit = "nameplate" .. i
        if read(UnitExists, unit) == true and unitMatchesKey(unit, key) then return unit end
    end
end

local function castUnit()
    return castInProgress and findUnitByKey(castInProgress.key)
end

-- Only actual pending casts are public, not the finisher/settings preview or a landed hit.
function ns.apiCast()
    if not BIT.IsRunning("CastPrediction") or not castInProgress or castInProgress.landedAt then return nil end
    return castInProgress, castUnit()
end

function ns.apiAimedAt(unit)
    if isSecret(unit) or type(unit) ~= "string" or not BIT.IsRunning("CastPrediction") then return false end
    return castInProgress ~= nil and not castInProgress.landedAt and unitMatchesKey(unit, castInProgress.key)
end

-- The unit the shown prediction (a cast, or the finisher preview) is aimed at.
local function displayUnit()
    local shown = shownCast()
    return shown and findUnitByKey(shown.key)
end

local recipients = {}
local function castToken(castGUID, spellID)
    if not isSecret(castGUID) and type(castGUID) == "string" then return castGUID end
    return number(spellID)
end

local function recipientUnit(castGUID, spellID)
    local token = castToken(castGUID, spellID)
    local sent = token and recipients[token]
    if sent then return findUnitByKey(sent.key) end
    return selectedEnemy()
end

-- Snapshot SENT so a focus/mouseover macro or a selection change cannot mark the wrong mob.
local function onCastSent(targetName, castGUID, spellID)
    local token = castToken(castGUID, spellID)
    if not token then return end
    local unit = findRecipient(targetName)
    local key = unit and unitKey(unit) or nil
    if not unit then key = nil end
    local now = GetTime()
    for oldToken, sent in pairs(recipients) do
        if now - sent.at > CAST_MAX_SECONDS then recipients[oldToken] = nil end
    end
    recipients[token] = { key = key, at = now }
end

local function targetsSelected(castGUID, spellID, unit)
    local token = castToken(castGUID, spellID)
    local sent = token and recipients[token]
    return not sent or (sent.key ~= nil and sent.key == unitKey(unit))
end

-- Channel times can be secret: never compare or calculate with them before checking.
local function channelTimes(spellID)
    if type(UnitChannelInfo) ~= "function" then return end
    local ok, _, _, _, startMS, endMS, _, _, id, empowered = pcall(UnitChannelInfo, "player")
    startMS, endMS, id = number(startMS), number(endMS), number(id)
    if not ok or (id and id ~= spellID) or isSecret(empowered) or empowered == true then return end
    if not startMS or not endMS or startMS ~= startMS or endMS ~= endMS
        or startMS == math.huge or endMS == math.huge or endMS <= startMS then return end
    return startMS / 1000, endMS / 1000
end

local function dropCast(reason)
    if not castInProgress then return end
    if reason then trace("CAST " .. tostring(castInProgress.name) .. " dropped: " .. reason) end
    castInProgress = nil
end

-- UNIT_SPELLCAST_START (player). Returns true when a marker now shows for the cast.
local function onCastStart(castGUID, spellID, channel)
    dropCast(nil)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    local unit = recipientUnit(castGUID, spellID)
    if not unit or not targetsSelected(castGUID, spellID, unit) then return end
    local key = unitKey(unit)
    if not key then return end
    local startedAt, endsAt
    if channel then
        startedAt, endsAt = channelTimes(spellID)
        if not startedAt or endsAt <= GetTime() then return end
    end
    local view = buildView(spellID, channel)
    if not view then return end
    local prediction = predictionFor(view, spellID)
    if not prediction then return end
    castInProgress = {
        key = key,
        spellID = spellID,
        name = view.name or spellName(spellID) or "?",
        view = view,
        prediction = prediction,
        startedAt = startedAt or GetTime(),
        channel = channel and true or nil,
        endsAt = endsAt,
        channelDuration = channel and (endsAt - startedAt) or nil,
        channelHits = view.channelHits,
        totalPrediction = channel and prediction or nil,
        castGUID = (not isSecret(castGUID) and type(castGUID) == "string") and castGUID or nil,
    }
    trace(string.format("CASTING %s: expected %d-%d (showing %d%s%s%s)", tostring(castInProgress.name),
        math.floor(prediction.min + 0.5), math.floor(prediction.max + 0.5), math.floor(prediction.value + 0.5),
        prediction.samples and (" , factor from " .. prediction.samples .. " hit(s)") or "",
        (prediction.talentPercent or 0) > 0 and string.format(", talents +%.0f%%", prediction.talentPercent * 100) or "",
        (prediction.auraPercent or 0) > 0 and string.format(", auras +%.0f%%", prediction.auraPercent * 100) or ""))
    return true
end

-- UNIT_SPELLCAST_SUCCEEDED also fires for a cast that is then resisted, missed, dodged or met an immunity: no hit
-- follows, and the marker used to hang on the mob for the whole projectile grace. UNIT_COMBAT reports the avoid
-- on the mob (it names no spell), in the frame of the cast's success or a hair before it, so an avoid there that
-- can be the cast's ends the marker at once. A dodge, parry or deflect is never a spell's, and an avoid reported
-- in another school is someone else's. Taking another's avoid for ours only ends a marker a moment early.
local AVOIDS = { MISS = true, RESIST = true, IMMUNE = true, REFLECT = true, EVADE = true,
    DODGE = true, PARRY = true, DEFLECT = true }
local AVOID_LOOKBACK = 0.25
local HIDDEN_HIT_WINDOW = 0.25 -- a hit with a hidden amount counts as the cast landing only this soon after its success
local lastAvoid -- { key, action, school, at }: the latest avoid on any mob, for a success that comes just after

local function avoidEndsCast(cast, avoid)
    if cast.channel or avoid.key ~= cast.key then return false end
    local expects = cast.view and cast.view.school and SCHOOL_MASKS[cast.view.school]
    local action = avoid.action
    if (action == "DODGE" or action == "PARRY" or action == "DEFLECT") and expects and expects ~= SCHOOL_MASKS.physical then
        return false
    end
    local mask = number(avoid.school)
    if mask and mask ~= 0 and expects and not schoolMatches(expects, mask) then return false end
    return true
end

-- UNIT_SPELLCAST_SUCCEEDED (player): the cast went through; the marker stays while the hit flies.
-- An instant cast (no START) shows briefly too, when the option allows it.
local function onCastSucceeded(castGUID, spellID)
    local avoided = lastAvoid and GetTime() - lastAvoid.at <= AVOID_LOOKBACK and lastAvoid or nil
    lastAvoid = nil
    if castInProgress and sameCast(castInProgress, castGUID, spellID) then
        if castInProgress.channel then return true end -- channels succeed at their start
        if avoided and avoidEndsCast(castInProgress, avoided) then
            dropCast(avoided.action .. " (just before the cast event)")
            return true
        end
        castInProgress.succeededAt = GetTime()
        return true
    end
    if settings.castOnly then return end
    local view = buildView(spellID)
    local unit = recipientUnit(castGUID, spellID)
    if not view or not unit or not targetsSelected(castGUID, spellID, unit) then return end
    local key = unitKey(unit)
    if not key then return end
    local prediction = predictionFor(view, spellID)
    if not prediction then return end
    if avoided and avoidEndsCast({ key = key, view = view }, avoided) then return end
    castInProgress = {
        key = key,
        spellID = spellID,
        name = view.name or spellName(spellID) or "?",
        view = view,
        prediction = prediction,
        startedAt = GetTime(),
        succeededAt = GetTime(),
        castGUID = (not isSecret(castGUID) and type(castGUID) == "string") and castGUID or nil,
        instant = true,
    }
    return true
end

-- UNIT_SPELLCAST_STOP / FAILED / INTERRUPTED (player). Returns true when the marker was dropped.
local function onCastEnded(event, castGUID, spellID)
    if not castInProgress or not sameCast(castInProgress, castGUID, spellID) then return false end
    if event == "UNIT_SPELLCAST_STOP" then
        if castInProgress.channel then return false end
        castInProgress.stoppedAt = castInProgress.stoppedAt or GetTime()
        return false
    end
    dropCast(event == "UNIT_SPELLCAST_INTERRUPTED" and "interrupted" or "failed")
    return true
end

-- UNIT_COMBAT on any unit: a WOUND (or ABSORB) whose school matches the cast and whose amount
-- sits in the predicted band is this cast landing; it calibrates the estimate. Crits match the
-- band too (their ratio is inside the tolerated one) but never teach it.
local function onUnitCombat(unit, action, flag, amount, school)
    if isSecret(action) then return end
    if AVOIDS[action] then
        local key = unitKey(unit)
        if not key then return end
        local avoid = { key = key, action = action, school = school, at = GetTime() }
        local cast = castInProgress
        if cast and cast.succeededAt and not cast.landedAt and avoidEndsCast(cast, avoid) then
            dropCast(action)
            return "avoided"
        end
        -- The cast's success may be the next event: keep the avoid for it (onCastSucceeded).
        if cast and not cast.succeededAt and avoidEndsCast(cast, avoid) then lastAvoid = avoid end
        if not cast then lastAvoid = avoid end -- an instant cast has no marker until it succeeds
        return
    end
    if not castInProgress or castInProgress.channel or not castInProgress.succeededAt
        or castInProgress.landedAt then return end
    local key = unitKey(unit)
    if not key or key ~= castInProgress.key then return end
    local absorbed = action == "ABSORB"
    if action ~= "WOUND" and not absorbed then return end
    if isSecret(amount) then
        -- Forever hides the amount but not the school, so no hit ever matched there and a spell that lands with
        -- the cast event (Immolate) kept its marker for the whole projectile grace. A hit of the cast's school on
        -- its mob right on the cast's success is taken as the cast landing. Only right on it: later in the grace
        -- a tick of a DoT of the same school cannot be told from the projectile, and ending the marker on the
        -- wrong hit misleads more than a marker that waits. Nothing is learned from a hidden hit.
        if GetTime() - castInProgress.succeededAt > HIDDEN_HIT_WINDOW then return end
        local hiddenMask = number(school)
        local hiddenExpects = castInProgress.view and castInProgress.view.school and SCHOOL_MASKS[castInProgress.view.school]
        if not (hiddenMask and hiddenExpects and schoolMatches(hiddenExpects, hiddenMask)) then return end
        castInProgress.landedAt = GetTime()
        trace(string.format("HIT (amount hidden) school %d on %s taken as %s landing", hiddenMask, tostring(unit),
            tostring(castInProgress.name)))
        return true
    end
    amount = number(amount)
    if not amount then return end
    local nowHit = GetTime()
    if nowHit - lastCombatAt > COMBAT_FRAME then
        combatFrameHits = {}
        lastCombatAt = nowHit
    end
    local signature = castInProgress.spellID .. ":" .. amount .. ":" .. tostring(school)
    if combatFrameHits[signature] then return end -- the same hit on another token
    combatFrameHits[signature] = true

    local mask = number(school)
    local expects = castInProgress.view and castInProgress.view.school and SCHOOL_MASKS[castInProgress.view.school]
    if mask and expects and not schoolMatches(expects, mask) then return end

    local isCrit = not isSecret(flag) and flag == "CRITICAL"
    local prediction = castInProgress.prediction
    local lo = prediction.min * (1 - LEARN_TOLERANCE)
    local hi = prediction.max * (1 + LEARN_TOLERANCE)
    local withinRange = amount >= lo and amount <= hi
    local withinCrit = amount >= prediction.value * CRIT_MIN_RATIO and amount <= prediction.value * CRIT_MAX_RATIO
    if absorbed then
        -- The shield ate the hit: this cast landed; nothing to learn from a 0 or a partial.
        castInProgress.landedAt = nowHit
        trace(string.format("HIT absorbed on %s; marker holds until it fades", tostring(unit)))
        return true
    end
    if not withinRange and not withinCrit then
        -- Kept for the end of the cast: it counts only if no hit of the cast matches (see housekeep).
        local middle = (prediction.min + prediction.max) / 2
        if middle > 0 and amount >= middle * 0.2 and amount <= middle * 3 then castInProgress.nearMiss = true end
        return
    end
    castInProgress.landedAt = nowHit
    -- Against the middle of the range, not the value the marker shows: with the "min" or "max" estimate that would
    -- teach every hit as a shift of the factor.
    if withinRange then
        noteHit(castInProgress.spellID, amount, isCrit, (prediction.min + prediction.max) / 2, prediction.factor)
    end
    trace(string.format("HIT %s %d%s matched to the cast (expected %d-%d)",
        tostring(castInProgress.name), math.floor(amount + 0.5), isCrit and " CRIT" or "",
        math.floor(castInProgress.prediction.min + 0.5), math.floor(castInProgress.prediction.max + 0.5)))
    return true
end

local function housekeep(now)
    if not castInProgress then return end
    if castInProgress.channel then
        local cast = castInProgress
        -- ponytail: channels without a known tick schedule use time; known schedules use discrete ticks.
        local remaining = math.min(1, math.max(0, (cast.endsAt - now) / cast.channelDuration))
        if remaining <= 0 then return dropCast("channel finished") end
        if cast.channelHits and cast.channelHits > 1 then
            -- Penance's first bolt lands at channel start; only the later scheduled bolts remain.
            remaining = math.ceil(remaining * (cast.channelHits - 1)) / cast.channelHits
        end
        local total = cast.totalPrediction
        cast.prediction = { min = total.min * remaining, max = total.max * remaining,
            value = total.value * remaining }
    elseif castInProgress.landedAt then
        if now - castInProgress.landedAt > LANDED_GRACE then dropCast("impact faded") end
    elseif castInProgress.succeededAt then
        if now - castInProgress.succeededAt > PROJECTILE_GRACE then
            if castInProgress.nearMiss then noteRefused(castInProgress.spellID) end
            dropCast("no hit seen")
        end
    elseif castInProgress.stoppedAt then
        if now - castInProgress.stoppedAt > CAST_STOP_GRACE then dropCast("stopped without succeeding") end
    elseif now - castInProgress.startedAt > CAST_MAX_SECONDS then
        dropCast("never finished")
    end
end

---------------------------------------------------------------------------------------------
-- Display: the marker, its label and the kill icon; drawn while a cast is predicted
---------------------------------------------------------------------------------------------

local function colorOf(id, opacityPercent)
    local rgb = COLOR_BY_ID[id] or (BIT.Looks and BIT.Looks.Rgb(id)) or COLOR_BY_ID.white
    return rgb[1], rgb[2], rgb[3], (opacityPercent or 100) / 100
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CHANNEL_PATTERN = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Modules\\DoTInfo\\Textures\\DashH2"
-- A finisher preview has its own fill: horizontal lines, so it reads differently from a cast (solid), a channel
-- (vertical dashes) and DoTInfo's DoTs (diagonal stripes) on the same health bar.
local PREVIEW_PATTERN = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Modules\\DoTInfo\\Textures\\DashV4"

local function paintDamage(texture, color, opacity, state)
    -- Which texture: a finisher preview, a channel and a cast each have their own (settings, shared catalog).
    local kind = (state and state.preview == true and "finisher") or (state and state.channel == true and "channel") or "cast"
    local entry = BIT.Looks and BIT.Looks.Texture(settings[kind .. "Texture"]) or nil
    local path = entry and entry.path or ((kind == "finisher" and PREVIEW_PATTERN) or (kind == "channel" and CHANNEL_PATTERN) or WHITE)
    local tiled = entry and entry.tiled or false
    if kind == "finisher" then color, opacity = settings.finisherColor, settings.finisherOpacity end
    local r, g, b, a = colorOf(color, opacity)
    local dot = BIT.modules and BIT.modules.DoTInfo
    if color == "school" and dot and type(dot.dotColor) == "function" then
        local school = state and state.school
        local rgb = dot.dotColor({ school = SCHOOL_MASKS[school] or number(school) }, "school")
        r, g, b = rgb[1], rgb[2], rgb[3]
    end
    -- Repainting a texture only when its look changed keeps the bar's shape mask on it between frames.
    local gradient, raw = entry and entry.gradient and true or false, entry and entry.raw and true or false
    local last = texture.uptPaint
    if last and last[1] == path and last[2] == tiled and last[3] == gradient and last[4] == raw
        and last[5] == r and last[6] == g and last[7] == b and last[8] == a then
        return
    end
    texture.uptPaint = { path, tiled, gradient, raw, r, g, b, a }
    texture:SetTexture(path, tiled and "REPEAT" or nil, tiled and "REPEAT" or nil)
    texture:SetHorizTile(tiled)
    texture:SetVertTile(tiled)
    if entry and entry.gradient and CreateColor then
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, a))
    elseif entry and entry.raw then
        texture:SetVertexColor(1, 1, 1, a) -- a texture with colours of its own
    else
        texture:SetVertexColor(r, g, b, a)
    end
    if BIT.UI and BIT.UI.BarMask then BIT.UI.BarMask.RefreshTexture(texture) end
end

-- The native health texture supplies the moving edge. Only public bar dimensions enter Lua;
-- health and maximum health stay in StatusBar setters, including when the client hides them.
local function layoutDamage(markerBar, clip, host)
    if not host then return false end
    local fill = read(host.GetStatusBarTexture, host)
    clip:ClearAllPoints()
    clip:SetAllPoints(host)
    -- The clip's dimensions use our parent scale even if the health widget has a different scale.
    local width, height = number(read(clip.GetWidth, clip)), number(read(clip.GetHeight, clip))
    if not fill or not width or not height or width <= 0 or height <= 0 then return false end
    local vertical = read(host.GetOrientation, host) == "VERTICAL"
    local reverse = read(host.GetReverseFill, host) == true
    markerBar:ClearAllPoints()
    markerBar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    markerBar:SetReverseFill(not reverse)
    if vertical then
        local edge = reverse and "BOTTOM" or "TOP"
        markerBar:SetPoint(edge .. "LEFT", fill, edge .. "LEFT")
        markerBar:SetPoint(edge .. "RIGHT", fill, edge .. "RIGHT")
        markerBar:SetHeight(height)
    else
        local edge = reverse and "LEFT" or "RIGHT"
        -- The native fill is as tall as the bar's frame, which on Blizzard's Camelot frames is taller than the bar the
        -- player sees (the mask only cuts the fill): the marker, outline included, takes the visible bar's height.
        local top, bottom = 0, 0
        if BIT.Plate and BIT.Plate.BarInset then top, bottom = BIT.Plate.BarInset(host) end
        markerBar:SetPoint("TOP" .. edge, fill, "TOP" .. edge, 0, -top)
        markerBar:SetPoint("BOTTOM" .. edge, fill, "BOTTOM" .. edge, 0, bottom)
        markerBar:SetWidth(width)
    end
    return true
end

local function findById(list, id)
    for _, entry in ipairs(list) do
        if entry.id == id then return entry end
    end
    return list[1]
end

-- Damage retreats from the current HP edge; clipping contains overkill within the health bar.
local markerClip = CreateFrame("Frame", nil, UIParent)
markerClip:SetClipsChildren(true)
-- DoTInfo's layer scan of the target frame leaves out marks of ours that sit on the bar (see DoTInfo/Core.lua).
BIT.OwnOverlays = BIT.OwnOverlays or setmetatable({}, { __mode = "k" })
BIT.OwnOverlays[markerClip] = true
local marker = CreateFrame("StatusBar", "Ready2QuestCombat_CastPredictionMarker", markerClip)
marker:SetStatusBarTexture(WHITE)
marker:SetStatusBarColor(0, 0, 0, 0)
marker:Hide()
local span = marker:GetStatusBarTexture()

local fillLayer = CreateFrame("Frame", nil, marker)
fillLayer:SetAllPoints()

local fillTex = fillLayer:CreateTexture(nil, "ARTWORK")
fillTex:SetPoint("TOPLEFT", span, "TOPLEFT")
fillTex:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")

local flashTex = fillLayer:CreateTexture(nil, "OVERLAY")
flashTex:SetPoint("TOPLEFT", span, "TOPLEFT")
flashTex:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
flashTex:SetColorTexture(1, 1, 1, 1)
flashTex:SetBlendMode("ADD")
flashTex:SetAlpha(0)

local flashAnim = flashTex:CreateAnimationGroup()
local flashIn = flashAnim:CreateAnimation("Alpha")
flashIn:SetFromAlpha(0)
flashIn:SetToAlpha(0.8)
flashIn:SetDuration(0.08)
flashIn:SetOrder(1)
local flashOut = flashAnim:CreateAnimation("Alpha")
flashOut:SetFromAlpha(0.8)
flashOut:SetToAlpha(0)
flashOut:SetDuration(0.4)
flashOut:SetSmoothing("OUT")
flashOut:SetOrder(2)

-- The outline: four hairline edges on the span (solid only; no dash textures ship with this
-- module). The span's length is secret-driven, so the edges are anchored to it, never sized.
local outlineLayer = CreateFrame("Frame", nil, marker)
outlineLayer:SetAllPoints()
local edges = {}
do
    local function edge(texture)
        texture:SetTexture(WHITE)
        table.insert(edges, texture)
        return texture
    end
    local top = edge(outlineLayer:CreateTexture(nil, "OVERLAY", nil, 7))
    top:SetPoint("TOPLEFT", span, "TOPLEFT")
    top:SetPoint("TOPRIGHT", span, "TOPRIGHT")
    top:SetHeight(1)
    local bottom = edge(outlineLayer:CreateTexture(nil, "OVERLAY", nil, 7))
    bottom:SetPoint("BOTTOMLEFT", span, "BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
    bottom:SetHeight(1)
    local left = edge(outlineLayer:CreateTexture(nil, "OVERLAY", nil, 7))
    left:SetPoint("TOPLEFT", span, "TOPLEFT")
    left:SetPoint("BOTTOMLEFT", span, "BOTTOMLEFT")
    left:SetWidth(1)
    local right = edge(outlineLayer:CreateTexture(nil, "OVERLAY", nil, 7))
    right:SetPoint("TOPRIGHT", span, "TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
    right:SetWidth(1)
end

local outlinePulse = outlineLayer:CreateAnimationGroup()
outlinePulse:SetLooping("BOUNCE")
do
    local alpha = outlinePulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0.45)
    alpha:SetDuration(0.7)
    alpha:SetSmoothing("IN_OUT")
end

-- The kill icon: addon code cannot compare the (secret) health with the prediction, but a
-- StatusBar can position it, but clipping alone reveals part of it before lethal.
-- Readable health gates visibility exactly; secret health retains the native clipping transition.
local KILL_BAR_LENGTH = 10000
local killHealthUnavailableReported = false
local function setKillValue(bar, health, minimum)
    bar:SetMinMaxValues(0, health)
    bar:SetValue(minimum)
    local readableHealth = number(health)
    if not readableHealth and not killHealthUnavailableReported then
        killHealthUnavailableReported = true
        trace("Kill icon uses native clipping for secret health; it may appear partially before lethal")
    end
    bar:SetAlpha(not readableHealth and 1
        or (readableHealth > 0 and minimum >= readableHealth and 1 or 0))
end
local killWindow = CreateFrame("Frame", "Ready2QuestCombat_CastPredictionKill", UIParent)
killWindow:SetClipsChildren(true)
killWindow:Hide()
local killBar = CreateFrame("StatusBar", nil, killWindow)
killBar:SetPoint("RIGHT", killWindow, "RIGHT")
killBar:SetStatusBarTexture(WHITE)
killBar:SetStatusBarColor(0, 0, 0, 0)
local killIcon = killBar:CreateTexture(nil, "OVERLAY")
killIcon:SetPoint("RIGHT", killBar:GetStatusBarTexture(), "RIGHT")

local killPulse = killIcon:CreateAnimationGroup()
killPulse:SetLooping("BOUNCE")
do
    local alpha = killPulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0.45)
    alpha:SetDuration(0.7)
    alpha:SetSmoothing("IN_OUT")
end

local labelLayer = CreateFrame("Frame", nil, UIParent)
local label = labelLayer:CreateFontString(nil, "OVERLAY")
labelLayer:Hide()

-- Where the marker is attached: the target frame's health bar and portrait (live), or the
-- settings preview's mock frames. previewState is tried first: while the settings window is open
-- out of combat, the preview keeps the marker (see Options.lua).
local healthBar, skullAnchor, targetHost
local previewHost, previewState, previewPlate
local appliedSignature

local function updatePreviewHealth(host)
    if not (host and host.healthBar and previewState) then return end
    local health, maxHealth = number(previewState.health), number(previewState.maxHealth)
    if not health or not maxHealth or maxHealth <= 0 then return end
    host.healthBar:SetMinMaxValues(0, 100)
    host.healthBar:SetValue(math.max(0, math.min(100, health / maxHealth * 100)))
end

local function positionFrameKill(window, bar, portrait)
    window:ClearAllPoints()
    local position = settings.killIconPosition
    local x, y = settings.killIconOffsetX, settings.killIconOffsetY
    if bar and position == "above" then
        window:SetPoint("BOTTOM", bar, "TOP", x, 4 + y)
    elseif bar and position == "below" then
        window:SetPoint("TOP", bar, "BOTTOM", x, -4 + y)
    elseif bar and position == "left" then
        window:SetPoint("RIGHT", bar, "LEFT", -4 + x, y)
    elseif bar and position == "right" then
        window:SetPoint("LEFT", bar, "RIGHT", 4 + x, y)
    else
        window:SetPoint("CENTER", portrait or bar or UIParent, "CENTER", x,
            y + ((not portrait and not bar) and 120 or 0))
    end
end

local function positionKill()
    if not killWindow then return end
    positionFrameKill(killWindow, healthBar, skullAnchor)
end

function ns.setDisplayHost(host)
    previewHost = host
    updatePreviewHealth(host)
    healthBar = host and host.healthBar or nil
    skullAnchor = host and (host.portrait or host.layerFrame) or nil
    targetHost = host and host.layerFrame or nil
    appliedSignature = nil
    -- attach() parents the clip to the target bar, hidden with no target: the preview's own mock bar
    -- would then show no fill. Back on UIParent here; attach() moves it again once the preview ends.
    if host and markerClip:GetParent() ~= UIParent then pcall(markerClip.SetParent, markerClip, UIParent) end
    if not host then
        marker:ClearAllPoints()
        marker:Hide()
        markerClip:Hide()
        labelLayer:Hide()
        killWindow:Hide()
    end
    positionKill()
end

-- state: { name, min, max, value, school, health (percent of max), samples } or nil.
function ns.setPreviewState(state)
    previewState = state
    updatePreviewHealth(previewHost)
    updatePreviewHealth(previewPlate)
    appliedSignature = nil
end

local function attach()
    local portrait, bar, frameHost
    if previewHost then
        portrait, bar = previewHost.portrait, previewHost.healthBar
        frameHost = previewHost.layerFrame
    elseif BIT.Plate and BIT.Plate.UnitFrame then
        frameHost, bar, portrait = BIT.Plate.UnitFrame("target")
    else
        local tf = TargetFrame
        frameHost = tf
        local main = tf and tf.TargetFrameContent and tf.TargetFrameContent.TargetFrameContentMain
        bar = (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
            or (main and main.HealthBar) or TargetFrameHealthBar or (tf and tf.healthbar)
        local portraitHost = tf and tf.TargetFrameContainer
        portrait = (portraitHost and portraitHost.Portrait) or TargetFramePortrait or (tf and tf.portrait)
    end
    healthBar = bar
    targetHost = frameHost or bar
    skullAnchor = portrait or healthBar
    if healthBar then
        if not previewHost and not (type(InCombatLockdown) == "function" and InCombatLockdown()) then
            local parent = markerClip.GetParent and markerClip:GetParent()
            if parent ~= healthBar then
                local ok = pcall(markerClip.SetParent, markerClip, healthBar)
                if not ok then trace("ATTACH marker parent change failed") end
            end
        end
        marker:ClearAllPoints()
        marker:SetAllPoints(healthBar)
    end
    positionKill()
    appliedSignature = nil
    return healthBar ~= nil
end

-- Keeps our frames above everything on the target frame; Blizzard can re-layer it at any time.
local STRATA_RANK = {
    BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}
local layerCheckedAt, lastStrata, lastLevel = 0, nil, nil
-- Highest strata/level of the frame and of what is shown under it. A hidden frame draws nothing, so it cannot cover our
-- marks, and counting it pulled them out of the unit frame's layer: Edit Mode keeps a hidden selection frame (MEDIUM,
-- level 1000) under every Blizzard unit frame whose own art is LOW, and the marks followed it into the strata of the
-- world map, above the map's art. The frame itself always counts, shown or not.
local function topLayerOf(frame)
    -- A missing custom unit frame must not expand the scan to the whole UI.
    if not frame or frame == UIParent then return end
    local topStrata, topLevel = "BACKGROUND", 0
    local function visit(f, depth)
        if f == markerClip or (BIT.OwnOverlays and BIT.OwnOverlays[f]) then return end
        if depth > 0 then
            -- hidden only when the client says so: an unreadable or secret answer counts as shown
            local okShown, shown = pcall(f.IsShown, f)
            if okShown and not isSecret(shown) and shown == false then return end
        end
        local ok, forbidden = pcall(function() return f.IsForbidden and f:IsForbidden() end)
        if not ok or isSecret(forbidden) or forbidden then return end
        local readOK, strata, level = pcall(function() return f:GetFrameStrata(), f:GetFrameLevel() end)
        if readOK and not isSecret(strata) and not isSecret(level) and type(strata) == "string" and type(level) == "number" then
            local rank, topRank = STRATA_RANK[strata] or 0, STRATA_RANK[topStrata] or 0
            if rank > topRank then
                topStrata, topLevel = strata, level
            elseif rank == topRank and level > topLevel then
                topLevel = level
            end
        end
        if depth < 6 then
            local children = { pcall(f.GetChildren, f) }
            if children[1] then
                for i = 2, #children do visit(children[i], depth + 1) end
            end
        end
    end
    visit(frame, 0)
    return topStrata, topLevel
end

local function updateLayering(now)
    if now - layerCheckedAt < 1 then return end
    layerCheckedAt = now
    if not previewHost and not previewState and BIT.Plate and BIT.Plate.UnitFrame then
        local host, bar = BIT.Plate.UnitFrame("target")
        if bar ~= healthBar or (host or bar) ~= targetHost then attach() end
    end
    -- attach() cannot reparent in combat; the marker then hangs on UIParent and would not follow the bar (its alpha,
    -- its scale, hiding with it). Once out of combat it moves onto the bar.
    if healthBar and not previewHost and not (type(InCombatLockdown) == "function" and InCombatLockdown()) then
        local parent = markerClip.GetParent and markerClip:GetParent()
        if parent ~= healthBar then pcall(markerClip.SetParent, markerClip, healthBar) end
    end
    local strata, level
    if previewHost then
        -- One strata above the options window; dropdowns and tooltips sit higher still.
        strata, level = "FULLSCREEN", 1
    else
        local ok
        ok, strata, level = pcall(topLayerOf, targetHost or healthBar or TargetFrame)
        if not ok then return end
        if not strata then
            layerCheckedAt = now - 0.75 -- nothing to scan yet (the custom frame is hidden): look again soon
            return
        end
    end
    for i, frame in ipairs({ markerClip, marker, fillLayer, outlineLayer, labelLayer, killWindow, killBar }) do
        frame:SetFrameStrata(strata)
        frame:SetFrameLevel(level + i)
    end
    if strata ~= lastStrata or level ~= lastLevel then
        lastStrata, lastLevel = strata, level
        trace(string.format("LAYER target frame top is %s/%d", tostring(strata), tonumber(level) or 0))
    end
end

-- The client's small font, with a plain path kept in reach for hosts (and tests) that answer
-- without a font object.
local function labelFontPath()
    if type(GameFontNormalSmall) == "table" and type(GameFontNormalSmall.GetFont) == "function" then
        local ok, path = pcall(GameFontNormalSmall.GetFont, GameFontNormalSmall)
        if ok and type(path) == "string" then return path end
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function applyAppearance(state)
    if not settings then return end
    local parts = {}
    for _, key in ipairs({ "fillColor", "fillOpacity", "outlineStyle", "outlineColor",
        "outlineOpacity", "pulseOutline", "showKillIcon", "killIcon", "showKillSpellIcon", "showLabel", "labelMode", "labelPosition",
        "labelSize", "labelColor", "killIconSize", "killIconPosition", "killIconOffsetX", "killIconOffsetY",
        "castTexture", "channelTexture", "finisherTexture",
        "finisherColor", "finisherOpacity" }) do
        parts[#parts + 1] = tostring(settings[key])
    end
    parts[#parts + 1] = tostring(state and state.school)
    parts[#parts + 1] = tostring(state and state.channel)
    parts[#parts + 1] = tostring(state and state.preview)
    parts[#parts + 1] = tostring(state and state.spellID)
    local signature = table.concat(parts, "|")
    if signature == appliedSignature then return end
    appliedSignature = signature

    paintDamage(fillTex, settings.fillColor, settings.fillOpacity, state)

    local or_, og, ob, oa = colorOf(settings.outlineColor, settings.outlineOpacity)
    for _, texture in ipairs(edges) do
        texture:SetVertexColor(or_, og, ob, oa)
        texture:SetShown(settings.outlineStyle ~= "none")
    end
    -- Blizzard's bar fill is cut to the frame's shape by a mask; ours is a plain rectangle and spilled over the border. Only
    -- the fill takes the mask: the 1 px outline lies on the bar's boundary, which a masked bar cuts away, so it would vanish.
    local barMask = BIT.UI and BIT.UI.BarMask
    if barMask and healthBar then barMask.Apply(fillTex, healthBar, true) end
    if settings.pulseOutline and settings.outlineStyle ~= "none" then
        outlinePulse:Play()
    else
        outlinePulse:Stop()
    end

    local icon = findById(KILL_ICONS, settings.killIcon)
    local spellIcon = settings.showKillSpellIcon and spellTexture(state and state.spellID)
    local size = settings.killIconSize
    killIcon:SetTexture(spellIcon or icon.path)
    killIcon:SetSize(size, size)
    killWindow:SetSize(size, size)
    killBar:SetSize(KILL_BAR_LENGTH, size)
    if settings.showKillIcon then killPulse:Play() else killPulse:Stop() end
    positionKill()

    local fontPath = labelFontPath()
    label:SetFont(fontPath, settings.labelSize, "OUTLINE")
    label:SetTextColor(colorOf(settings.labelColor))
    label:ClearAllPoints()
    if healthBar then
        if settings.labelPosition == "center" then
            label:SetPoint("CENTER", healthBar, "CENTER")
        elseif settings.labelPosition == "right" then
            label:SetPoint("RIGHT", healthBar, "RIGHT", -4, 0)
        else
            label:SetPoint("RIGHT", healthBar, "LEFT", -6, 0)
        end
    end
    label:SetShown(settings.showLabel)
end

-- The label of a cast: "Frostbolt 430", "Frostbolt 410-450" or "Frostbolt 24%" of the target's
-- maximum health. maxHealth may be secret in combat; then the percent mode falls back to damage.
local function labelText(state, maxHealth)
    local name = state.name or "Cast"
    local value = math.floor((state.value or 0) + 0.5)
    if settings.labelMode == "range" then
        return string.format("%s %d-%d", name, math.floor((state.min or 0) + 0.5), math.floor((state.max or 0) + 0.5))
    end
    if settings.labelMode == "percent" then
        local readable = number(maxHealth)
        if readable and readable > 0 then
            return string.format("%s %.0f%%", name, math.min(999, (state.value or 0) / readable * 100))
        end
    end
    return string.format("%s %d", name, value)
end

local function playFlash()
    if settings.showMarker then
        flashAnim:Stop()
        flashAnim:Play()
    end
end
ns.playFlash = playFlash

local function hideAll()
    marker:Hide()
    markerClip:Hide()
    labelLayer:Hide()
    killWindow:Hide()
end

-- Draws one marker. damage may be plain (preview); maxHealth and health may be secret: they only
-- ever go into StatusBar min/max, never into Lua math. The kill icon compares the LOWEST end of
-- the range (a lethal cue must not lie: only damage the spell is certain to reach counts).
local function drawMarker(damage, maxHealth, health, state)
    local killValue = number(state.min) or damage
    if not layoutDamage(marker, markerClip, healthBar) then
        hideAll()
        return false
    end
    marker:SetMinMaxValues(0, maxHealth)
    marker:SetValue(damage)
    setKillValue(killBar, health, killValue)
    applyAppearance(state)
    markerClip:SetShown(settings.showMarker)
    marker:SetShown(settings.showMarker)
    labelLayer:SetShown(settings.showMarker)
    killWindow:SetShown(settings.showKillIcon and state.kill ~= false)
    label:SetText(labelText(state, maxHealth))
    return true
end

-- The target frame's health bar is the host; the preview host replaces it while its window is
-- open out of combat. Returns true when the marker shows.
local function updateMarker(now)
    if previewState then
        local state = previewState
        if not settings.showTargetFrame or not state.value or state.value <= 0
            or (state.health or 1) <= 0 then return hideAll() end
        updateLayering(now)
        local maxHealth = number(state.maxHealth) or math.max(state.health, 0.01)
        return drawMarker(state.value, maxHealth, math.max(state.health, 0.01), state)
    end
    local cast = shownCast()
    if not cast or not settings.showTargetFrame
        or not unitMatchesKey("target", cast.key) or not hostileTarget("target") then
        hideAll()
        return false
    end
    if cast.landedAt then
        local prediction = cast.prediction
        return drawMarker(prediction.value, UnitHealthMax("target"), UnitHealth("target"), {
            name = cast.name, min = prediction.min, max = prediction.max,
            value = prediction.value, school = cast.view.school, spellID = cast.spellID,
        })
    end
    if not UnitExists("target") or targetIsDead() then
        hideAll()
        return false
    end
    if not healthBar then attach() end
    if not healthBar and not previewHost then
        hideAll()
        return false
    end
    updateLayering(now)
    local prediction = cast.prediction
    return drawMarker(prediction.value, UnitHealthMax("target"), UnitHealth("target"), {
        name = cast.name, min = prediction.min, max = prediction.max, value = prediction.value,
        school = cast.view.school, channel = cast.channel, preview = cast.preview, spellID = cast.spellID,
    })
end

---------------------------------------------------------------------------------------------
-- Other unit frames: focus and group frames can show the same prediction when they represent
-- the cast's recipient. They own independent overlays so duplicate frames can be visible too.
---------------------------------------------------------------------------------------------

local frameWidgets = setmetatable({}, { __mode = "k" })
local function targetKnownDead(unit)
    return read(UnitIsDeadOrGhost, unit) == true
end

local function frameHealthBar(frame)
    if type(frame) ~= "table" then return nil end
    local container = frame.HealthBarContainer
    local bar = type(container) == "table" and container.HealthBar
    if type(bar) ~= "table" then bar = frame.HealthBar end
    if type(bar) ~= "table" then bar = frame.healthBar end
    if type(bar) ~= "table" then bar = frame.healthbar end
    return type(bar) == "table" and bar or nil
end

local function frameUnit(frame)
    if type(frame) ~= "table" then return nil end
    local unit = frame.displayedUnit
    if unit == nil then unit = frame.unit end
    return not isSecret(unit) and type(unit) == "string" and unit or nil
end

local function collectPool(pool, out)
    if type(pool) ~= "table" then return end
    local function collect(candidate, unit)
        if type(candidate) ~= "table" then return end
        unit = unit or frameUnit(candidate)
        local bar = frameHealthBar(candidate)
        if unit and bar and (unit:match("^party%d+$") or unit:match("^raid%d+$")) then
            out[#out + 1] = { unit = unit, bar = bar, host = candidate }
        end
    end
    local objects = type(pool.memberUnitFrames) == "table" and pool.memberUnitFrames
        or type(pool.activeObjects) == "table" and pool.activeObjects
    if objects then
        for key, value in pairs(objects) do
            local unit = type(value) == "table" and frameUnit(value)
            if unit then collect(value, unit) else collect(key) end
        end
    elseif type(pool.EnumerateActive) == "function" then
        local ok, iter, state, seed = pcall(pool.EnumerateActive, pool)
        if ok and type(iter) == "function" then
            local guard = 0
            for candidate in iter, state, seed do
                guard = guard + 1
                if guard > 400 then break end
                collect(candidate)
            end
        end
    end
end

local function collectFrameOverlays()
    local out = {}
    local host, bar, portrait
    if BIT.Plate and BIT.Plate.UnitFrame then
        host, bar, portrait = BIT.Plate.UnitFrame("focus")
    else
        host, bar, portrait = FocusFrame, FocusFrameHealthBar, FocusFramePortrait
    end
    if bar then out[#out + 1] = { unit = "focus", bar = bar, host = host or FocusFrame, portrait = portrait } end

    for i = 1, 4 do
        local frame = _G["PartyMemberFrame" .. i]
        local partyBar = frameHealthBar(frame) or _G["PartyMemberFrame" .. i .. "HealthBar"]
        if partyBar then
            out[#out + 1] = { unit = "party" .. i, bar = partyBar, host = frame or partyBar }
        end
    end
    collectPool(_G.PartyFrame and _G.PartyFrame.PartyMemberFramePool, out)
    collectPool(_G.CompactPartyFrame, out)
    collectPool(_G.CompactRaidFrameContainer, out)

    local modules = type(EllesmereUI) == "table" and EllesmereUI._ModuleNS
    local eui = type(modules) == "table" and modules.EllesmereUIRaidFrames
    if type(eui) ~= "table" then return out end
    local internals = type(eui) == "table" and eui._internals
    local function collectEUI(members)
        if type(members) ~= "table" then return end
        for unit, frame in pairs(members) do
            local data = type(eui.GetFFD) == "function" and read(eui.GetFFD, frame)
            if not isSecret(unit) and type(unit) == "string"
                and (unit:match("^party%d+$") or unit:match("^raid%d+$"))
                and type(data) == "table" and type(data.health) == "table"
                and read(frame.IsVisible, frame) == true then
                out[#out + 1] = { unit = unit, bar = data.health, host = frame }
            end
        end
    end
    collectEUI(type(internals) == "table" and internals.unitToButton)
    collectEUI(type(eui) == "table" and eui._partyUnitToButton)
    return out
end

local function createFrameWidgets(bar)
    local w = { layerAt = -math.huge }
    w.clip = CreateFrame("Frame", nil, UIParent)
    w.clip:SetClipsChildren(true)
    BIT.OwnOverlays = BIT.OwnOverlays or setmetatable({}, { __mode = "k" })
    BIT.OwnOverlays[w.clip] = true -- the layer scans of the unit frames leave our own mark out (see DoTInfo/Core.lua)
    w.marker = CreateFrame("StatusBar", nil, w.clip)
    w.marker:SetStatusBarTexture(WHITE)
    w.marker:SetStatusBarColor(0, 0, 0, 0)
    w.fill = w.marker:CreateTexture(nil, "ARTWORK")
    local span = w.marker:GetStatusBarTexture()
    w.fill:SetPoint("TOPLEFT", span, "TOPLEFT")
    w.fill:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
    w.edges = {}
    local function edge(pointA, pointB, width, height)
        local texture = w.marker:CreateTexture(nil, "OVERLAY", nil, 7)
        texture:SetTexture(WHITE)
        texture:SetPoint(pointA, span, pointB)
        if width then texture:SetWidth(width) end
        if height then texture:SetHeight(height) end
        w.edges[#w.edges + 1] = texture
    end
    edge("TOPLEFT", "TOPLEFT")
    w.edges[1]:SetPoint("TOPRIGHT", span, "TOPRIGHT")
    w.edges[1]:SetHeight(1)
    edge("BOTTOMLEFT", "BOTTOMLEFT")
    w.edges[2]:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
    w.edges[2]:SetHeight(1)
    edge("TOPLEFT", "TOPLEFT", 1)
    w.edges[3]:SetPoint("BOTTOMLEFT", span, "BOTTOMLEFT")
    edge("TOPRIGHT", "TOPRIGHT", 1)
    w.edges[4]:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")

    w.labelLayer = CreateFrame("Frame", nil, UIParent)
    w.label = w.labelLayer:CreateFontString(nil, "OVERLAY")
    w.labelLayer:Hide()
    w.killWindow = CreateFrame("Frame", nil, UIParent)
    w.killWindow:SetClipsChildren(true)
    w.killBar = CreateFrame("StatusBar", nil, w.killWindow)
    w.killBar:SetPoint("RIGHT", w.killWindow, "RIGHT")
    w.killBar:SetStatusBarTexture(WHITE)
    w.killBar:SetStatusBarColor(0, 0, 0, 0)
    w.killIcon = w.killBar:CreateTexture(nil, "OVERLAY")
    w.killIcon:SetPoint("RIGHT", w.killBar:GetStatusBarTexture(), "RIGHT")
    w.clip:Hide()
    w.killWindow:Hide()
    frameWidgets[bar] = w
    return w
end

local function keepFrameWidgetsAbove(w, host, now)
    if now - w.layerAt < 1 and w.layerHost == host then return end
    w.layerAt, w.layerHost = now, host
    local ok, strata, level = pcall(topLayerOf, host)
    if not ok then return end
    if not strata then
        w.layerAt = now - 0.75 -- nothing to scan yet: look again soon
        return
    end
    for i, frame in ipairs({ w.clip, w.marker, w.labelLayer, w.killWindow, w.killBar }) do
        frame:SetFrameStrata(strata)
        frame:SetFrameLevel(level + i + 1)
    end
end

local function hideFrameWidgets(w)
    w.clip:Hide()
    w.labelLayer:Hide()
    w.killWindow:Hide()
end

local function drawFrameWidgets(w, entry, now)
    local unit, bar = entry.unit, entry.bar
    local cast = shownCast()
    local prediction = cast.prediction
    local state = {
        name = cast.name, min = prediction.min, max = prediction.max, value = prediction.value,
        school = cast.view.school, channel = cast.channel, preview = cast.preview, spellID = cast.spellID,
    }
    -- Hung on the bar itself, as the target marker is: a mark hung on the screen did not draw on the Forever client's unit
    -- frames. A bar cannot be reparented to in combat; the mark then waits on the screen for the end of it.
    if not (type(InCombatLockdown) == "function" and InCombatLockdown()) then
        local okParent, parent = pcall(w.clip.GetParent, w.clip)
        if okParent and parent ~= bar then pcall(w.clip.SetParent, w.clip, bar) end
    end
    if not layoutDamage(w.marker, w.clip, bar) then hideFrameWidgets(w); return end
    local barMask = BIT.UI and BIT.UI.BarMask
    if barMask and w.maskedBar ~= bar then
        w.maskedBar = bar
        barMask.Apply(w.fill, bar, true)
    end
    keepFrameWidgetsAbove(w, entry.host or bar, now)
    w.marker:SetMinMaxValues(0, UnitHealthMax(unit))
    w.marker:SetValue(prediction.value)
    paintDamage(w.fill, settings.fillColor, settings.fillOpacity, state)
    local r, g, b, a = colorOf(settings.outlineColor, settings.outlineOpacity)
    for _, edgeTexture in ipairs(w.edges) do
        edgeTexture:SetVertexColor(r, g, b, a)
        edgeTexture:SetShown(settings.outlineStyle ~= "none")
    end
    w.clip:SetShown(settings.showMarker)
    w.marker:SetShown(settings.showMarker)
    w.labelLayer:ClearAllPoints()
    w.labelLayer:SetAllPoints(bar)
    w.label:ClearAllPoints()
    w.label:SetFont(labelFontPath(), settings.labelSize, "OUTLINE")
    w.label:SetTextColor(colorOf(settings.labelColor))
    if settings.labelPosition == "center" then
        w.label:SetPoint("CENTER", bar, "CENTER")
    elseif settings.labelPosition == "right" then
        w.label:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    else
        w.label:SetPoint("RIGHT", bar, "LEFT", -6, 0)
    end
    w.label:SetText(labelText(state, UnitHealthMax(unit)))
    w.labelLayer:SetShown(settings.showMarker and settings.showLabel)

    positionFrameKill(w.killWindow, bar, entry.portrait or entry.host)
    local icon = findById(KILL_ICONS, settings.killIcon)
    w.killIcon:SetTexture((settings.showKillSpellIcon and spellTexture(cast.spellID)) or icon.path)
    local size = settings.killIconSize
    w.killWindow:SetSize(size, size)
    w.killBar:SetSize(KILL_BAR_LENGTH, size)
    w.killIcon:SetSize(size, size)
    setKillValue(w.killBar, UnitHealth(unit), number(state.min) or prediction.value)
    w.killWindow:SetShown(settings.showKillIcon)
end

local function refreshFrameOverlays(now, recipient)
    for _, w in pairs(frameWidgets) do hideFrameWidgets(w) end
    if previewHost or previewState then return end
    if not shownCast() or not recipient or targetKnownDead(recipient) then return end
    for _, entry in ipairs(collectFrameOverlays()) do
        local unit = entry.unit
        local enabled = unit == "focus" and settings.showFocusFrame
            or unit:match("^raid%d+$") and settings.showRaidFrames
            or unit:match("^party%d+$") and settings.showPartyFrames
        local sameUnit = read(UnitIsUnit, unit, recipient) == true
        if enabled and (not entry.host or read(entry.host.IsVisible, entry.host) ~= false)
            and sameUnit then
            local w = frameWidgets[entry.bar] or createFrameWidgets(entry.bar)
            drawFrameWidgets(w, entry, now)
        end
    end
end

---------------------------------------------------------------------------------------------
-- Nameplates: the same marker, drawn on the target's own plate
---------------------------------------------------------------------------------------------

local widgetsByPlate = {}

local function createPlateWidgets(plate, healthBar)
    local host = BIT.Plate.WidgetHost(plate)
    local w = { healthBar = healthBar, host = host, signature = nil, displayDamage = 0 }
    w.clip = CreateFrame("Frame", nil, host)
    w.clip:SetClipsChildren(true)
    w.marker = CreateFrame("StatusBar", nil, w.clip)
    w.marker:SetStatusBarTexture(WHITE)
    w.marker:SetStatusBarColor(0, 0, 0, 0)
    w.marker:SetPoint("TOPLEFT", healthBar, "TOPLEFT")
    w.marker:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT")
    w.span = w.marker:GetStatusBarTexture()
    w.fill = w.marker:CreateTexture(nil, "ARTWORK")
    w.fill:SetPoint("TOPLEFT", w.span, "TOPLEFT")
    w.fill:SetPoint("BOTTOMRIGHT", w.span, "BOTTOMRIGHT")
    w.edges = {}
    local function edge(texture)
        texture:SetTexture(WHITE)
        table.insert(w.edges, texture)
        return texture
    end
    local top = edge(w.marker:CreateTexture(nil, "OVERLAY", nil, 7))
    top:SetPoint("TOPLEFT", w.span, "TOPLEFT")
    top:SetPoint("TOPRIGHT", w.span, "TOPRIGHT")
    top:SetHeight(1)
    local bottom = edge(w.marker:CreateTexture(nil, "OVERLAY", nil, 7))
    bottom:SetPoint("BOTTOMLEFT", w.span, "BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT", w.span, "BOTTOMRIGHT")
    bottom:SetHeight(1)
    local left = edge(w.marker:CreateTexture(nil, "OVERLAY", nil, 7))
    left:SetPoint("TOPLEFT", w.span, "TOPLEFT")
    left:SetPoint("BOTTOMLEFT", w.span, "BOTTOMLEFT")
    left:SetWidth(1)
    local right = edge(w.marker:CreateTexture(nil, "OVERLAY", nil, 7))
    right:SetPoint("TOPRIGHT", w.span, "TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", w.span, "BOTTOMRIGHT")
    right:SetWidth(1)
    local iconWindow = CreateFrame("Frame", nil, host)
    iconWindow:SetClipsChildren(true)
    w.iconBar = CreateFrame("StatusBar", nil, iconWindow)
    w.iconBar:SetPoint("RIGHT", iconWindow, "RIGHT")
    w.iconBar:SetStatusBarTexture(WHITE)
    w.iconBar:SetStatusBarColor(0, 0, 0, 0)
    w.icon = w.iconBar:CreateTexture(nil, "OVERLAY")
    w.icon:SetPoint("RIGHT", w.iconBar:GetStatusBarTexture(), "RIGHT")
    w.iconWindow = iconWindow
    w.marker:Hide()
    iconWindow:Hide()
    widgetsByPlate[plate] = w
    return w
end

local function plateStyleSignature()
    return table.concat({ tostring(settings.plateFillColor), tostring(settings.plateFillOpacity),
        tostring(settings.plateOutlineStyle), tostring(settings.plateOutlineColor), tostring(settings.plateOutlineOpacity),
        tostring(settings.nameplateMode), tostring(settings.plateIconSize), tostring(settings.plateIconPosition),
        tostring(settings.plateIconOffsetX), tostring(settings.plateIconOffsetY), tostring(settings.castTexture),
        tostring(settings.showKillSpellIcon), tostring(settings.killIcon),
        tostring(settings.channelTexture), tostring(settings.finisherTexture), tostring(settings.finisherColor),
        tostring(settings.finisherOpacity) }, "|")
end

local function applyPlateStyle(w, state)
    local signature = plateStyleSignature() .. ":" .. tostring(state and state.school)
        .. ":" .. tostring(state and state.channel) .. ":" .. tostring(state and state.preview)
        .. ":" .. tostring(state and state.spellID)
    if w.signature == signature then return end
    w.signature = signature
    paintDamage(w.fill, settings.plateFillColor, settings.plateFillOpacity, state)
    local or_, og, ob, oa = colorOf(settings.plateOutlineColor, settings.plateOutlineOpacity)
    for _, texture in ipairs(w.edges) do
        texture:SetVertexColor(or_, og, ob, oa)
        texture:SetShown(settings.plateOutlineStyle ~= "none")
    end
    local size = settings.plateIconSize
    w.iconWindow:SetSize(size, size)
    w.iconBar:SetSize(KILL_BAR_LENGTH, size)
    w.icon:SetSize(size, size)
    w.icon:SetTexture((settings.showKillSpellIcon and spellTexture(state and state.spellID))
        or findById(KILL_ICONS, settings.killIcon).path)
    w.iconWindow:ClearAllPoints()
    local x, y = settings.plateIconOffsetX, settings.plateIconOffsetY
    if settings.plateIconPosition == "left" then
        w.iconWindow:SetPoint("RIGHT", w.healthBar, "LEFT", -4 + x, y)
    elseif settings.plateIconPosition == "above" then
        w.iconWindow:SetPoint("BOTTOM", w.healthBar, "TOP", x, 4 + y)
    elseif settings.plateIconPosition == "below" then
        w.iconWindow:SetPoint("TOP", w.healthBar, "BOTTOM", x, -4 + y)
    else
        w.iconWindow:SetPoint("LEFT", w.healthBar, "RIGHT", 4 + x, y)
    end
end

local function hidePlateWidgets(w)
    w.displayDamage = 0
    w.marker:Hide()
    w.clip:Hide()
    w.iconWindow:Hide()
end

-- Above the plate's health bar, in its strata, on every draw: the client re-levels plates while
-- they live (the target's, overlapping ones) and can otherwise cover a marker levelled once. The
-- level can be secret on Forever; then a fixed high level.
local FALLBACK_PLATE_LEVEL = 200
local function keepPlateAbove(w)
    local healthBar = w.healthBar
    local ok, level = pcall(healthBar.GetFrameLevel, healthBar)
    if not ok or isSecret(level) or type(level) ~= "number" then level = FALLBACK_PLATE_LEVEL end
    local okStrata, strata = pcall(healthBar.GetFrameStrata, healthBar)
    if not okStrata or isSecret(strata) or type(strata) ~= "string" then strata = nil end
    if level == w.barLevel and strata == w.barStrata then return end
    w.barLevel, w.barStrata = level, strata
    if strata then
        w.clip:SetFrameStrata(strata)
        w.marker:SetFrameStrata(strata)
        w.iconWindow:SetFrameStrata(strata)
        w.iconBar:SetFrameStrata(strata)
    end
    -- The icon sits well above: plate decorations beside the bar (the level badge) must not cover it.
    w.clip:SetFrameLevel(level + 5)
    w.marker:SetFrameLevel(level + 6)
    w.iconWindow:SetFrameLevel(level + 20)
    w.iconBar:SetFrameLevel(level + 21)
end

local function drawPlate(w, damage, maxHealth, health, state)
    keepPlateAbove(w)
    applyPlateStyle(w, state)
    if not layoutDamage(w.marker, w.clip, w.healthBar) then
        hidePlateWidgets(w)
        return false
    end
    w.marker:SetMinMaxValues(0, maxHealth)
    w.marker:SetValue(damage)
    w.marker:SetShown(settings.showMarker)
    w.clip:SetShown(settings.showMarker)
    w.displayDamage = settings.showMarker and damage or 0
    local minimum = number(state and state.min) or damage
    setKillValue(w.iconBar, health, minimum)
    w.iconBar:SetShown(settings.showKillIcon and (not state or state.kill ~= false))
    w.iconWindow:SetShown(settings.showMarker and settings.showKillIcon and settings.nameplateMode == "markerIcon")
    return true
end

local function widgetsFor(plate, healthBar)
    local w = widgetsByPlate[plate]
    if w then
        local host = BIT.Plate.WidgetHost(plate)
        if w.host ~= host then
            w.host = host
            w.clip:SetParent(host)
            w.iconWindow:SetParent(host)
        end
        if w.healthBar ~= healthBar then
            w.healthBar = healthBar
            w.marker:ClearAllPoints()
            w.marker:SetPoint("TOPLEFT", healthBar, "TOPLEFT")
            w.marker:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT")
            w.signature = nil
        end
        return w
    end
    return createPlateWidgets(plate, healthBar)
end

function ns.nameplateDamageBase(plate, bar)
    local w = widgetsByPlate[plate]
    return w and w.healthBar == bar and w.displayDamage or 0
end

-- The options window's mock nameplate: { plate, healthBar }, drawn by the same code as real
-- plates with plain numbers (see Options.lua).
function ns.setPlatePreview(host)
    local old = previewPlate
    previewPlate = host
    updatePreviewHealth(host)
    if old and old ~= host then
        local w = widgetsByPlate[old.plate]
        if w then hidePlateWidgets(w) end
    end
end

local seenPlates = {}

-- The target's own plate, if one is up: the target's plate via its token, else matched by key.
local function findTargetPlate(unit)
    if not (C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function") then return nil end
    local plate = read(C_NamePlate.GetNamePlateForUnit, unit)
    if type(plate) == "table" then return plate end
    local cast = shownCast()
    if not cast then return nil end
    for i = 1, MAX_PLATES do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            local key = unitKey(unit)
            if key and key == cast.key then
                plate = read(C_NamePlate.GetNamePlateForUnit, unit)
                if type(plate) == "table" then return plate end
            end
        end
    end
    return nil
end

local function refreshPlates(now, unit)
    wipe(seenPlates)
    local cast = shownCast()
    -- The options preview keeps the plate marker; the real plates stay hidden then.
    if previewPlate then
        seenPlates[previewPlate.plate] = true
        local w = widgetsFor(previewPlate.plate, previewPlate.healthBar)
        if previewState and previewState.value and previewState.value > 0
            and settings.showNameplates and settings.nameplateMode ~= "off"
            and (previewState.health or 1) > 0 then
            drawPlate(w, previewState.value, number(previewState.maxHealth) or math.max(previewState.health, 0.01),
                math.max(previewState.health, 0.01), previewState)
        else
            hidePlateWidgets(w)
        end
    elseif settings.showNameplates and settings.nameplateMode ~= "off"
        and cast and not cast.landedAt
        and unit and not targetKnownDead(unit) then
        local plate = findTargetPlate(unit)
        if plate then
            local forbidden = read(plate.IsForbidden, plate)
            if not forbidden then
                seenPlates[plate] = true
                local healthBar = BIT.Plate and BIT.Plate.HealthBar and BIT.Plate.HealthBar(plate)
                if healthBar then
                    local w = widgetsFor(plate, healthBar)
                    drawPlate(w, cast.prediction.value, UnitHealthMax(unit), UnitHealth(unit), {
                        school = cast.view.school, channel = cast.channel, preview = cast.preview,
                        spellID = cast.spellID, min = cast.prediction.min,
                    })
                end
            end
        end
    end
    for plate, w in pairs(widgetsByPlate) do
        if not seenPlates[plate] then hidePlateWidgets(w) end
    end
end

---------------------------------------------------------------------------------------------
-- Finisher preview: what the finisher on your action bars would deal to the target right now
---------------------------------------------------------------------------------------------

local FINISHER_SCAN_EVERY = 5 -- the bars are re-read no more often than this, and only after a change
local ACTION_SLOTS = 180

-- Every direct-damage finisher on the action bars (Eviscerate, Ferocious Bite, a rogue rune's Between the Eyes: any
-- description with a damage row per combo point), as a list of spell ids. SpellDamageInfo already reads the same
-- descriptions for the bar numbers, so whatever it can price is found here, on every class. A finisher that only
-- deals damage over time (Rupture, Rip) or none (Kidney Shot, Slice and Dice) is not one.
local function scanFinishers(module)
    local ids, seen = {}, {}
    if type(GetActionInfo) ~= "function" or type(module.Compute) ~= "function" then return ids end
    for slot = 1, ACTION_SLOTS do
        local ok, kind, id, sub = pcall(GetActionInfo, slot)
        if ok and not isSecret(kind) and not isSecret(id) and not isSecret(sub)
            and (kind == "spell" or (kind == "macro" and sub == "spell"))
            and type(id) == "number" and not seen[id] then
            seen[id] = true
            local okView, view = pcall(module.Compute, id, false)
            local finisher = okView and type(view) == "table" and view.finisher
            if type(finisher) == "table" and finisher.kind == "direct" then ids[#ids + 1] = id end
        end
    end
    return ids
end

-- What one finisher would deal at the target's combo points now: min, max, or nil (no points, not priced).
local function finisherDamage(module, id)
    local ok, view = pcall(module.Compute, id, false)
    local at = ok and type(view) == "table" and view.finisherAt
    local direct = type(at) == "table" and at.known and (number(at.n) or 0) >= 1 and view.direct
    if type(direct) ~= "table" then return nil end
    local min, max = number(direct.min), number(direct.max)
    if not min or not max or max <= 0 or min > max then return nil end
    return min, max
end

local finisherState = { view = { school = "physical" }, prediction = {} }

-- Rebuilds finisherPreview every refresh: set only while the option is on, no real cast is shown, a hostile target
-- carries combo points and SpellDamageInfo can price at least one finisher on the bars at that count. With several
-- (Eviscerate and Between the Eyes, Ferocious Bite), the strongest is shown: the question is whether any of them
-- kills. Attack power is not in a Forever description, so the number is what that finisher deals at least.
local function refreshFinisherPreview(now)
    finisherPreview = nil
    if not settings.finisherPreview or castInProgress or previewState or previewHost then return end
    if not hostileTarget("target") then return end
    local module = sdi()
    if not module or type(module.Compute) ~= "function" then return end
    if finisherScan.dirty and now - finisherScan.at >= FINISHER_SCAN_EVERY then
        finisherScan.at, finisherScan.dirty = now, false
        finisherScan.ids = scanFinishers(module)
    end
    local bestID, bestMin, bestMax, bestValue
    for _, id in ipairs(finisherScan.ids or {}) do
        local min, max = finisherDamage(module, id)
        if min then
            local value = (settings.estimate == "min" and min) or (settings.estimate == "max" and max) or (min + max) / 2
            if not bestValue or value > bestValue then bestID, bestMin, bestMax, bestValue = id, min, max, value end
        end
    end
    if not bestID then return end
    local key = unitKey("target")
    if not key then return end
    local name = spellName(bestID) or "?"
    local prediction = finisherState.prediction
    prediction.min, prediction.max, prediction.value = bestMin, bestMax, bestValue
    finisherState.key, finisherState.name, finisherState.spellID, finisherState.preview = key, name, bestID, true
    finisherState.view.name = name
    finisherPreview = finisherState
end

---------------------------------------------------------------------------------------------
-- Refresh loop (DoTInfo's pattern): the OnUpdate tick redraws; errors are reported once
---------------------------------------------------------------------------------------------

local reportedErrors = {}
local function refresh()
    local now = GetTime()
    housekeep(now)
    refreshFinisherPreview(now)
    local recipient = displayUnit()
    updateMarker(now)
    refreshFrameOverlays(now, recipient)
    refreshPlates(now, recipient)
end

local function safeRefresh()
    local ok, err = pcall(refresh)
    if not ok then
        dropCast("display error")
        local cleanupOK, cleanupError = pcall(function()
            hideAll()
            for _, w in pairs(frameWidgets) do hideFrameWidgets(w) end
            for _, w in pairs(widgetsByPlate) do hidePlateWidgets(w) end
        end)
        if not cleanupOK then err = tostring(err) .. "; cleanup: " .. tostring(cleanupError) end
        if not reportedErrors[err] then
            reportedErrors[err] = true
            trace("ERROR in display update: " .. tostring(err))
            print("Display error (logged): " .. tostring(err))
        end
    end
    if ns.afterRefresh then
        local apiOk, apiErr = pcall(ns.afterRefresh)
        if not apiOk and not reportedErrors[apiErr] then
            reportedErrors[apiErr] = true
            trace("ERROR in API update: " .. tostring(apiErr))
        end
    end
end

---------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------

function ns.ensureDB()
    settings = BIT.Settings("CastPrediction", DEFAULTS)
    if settings.killingSpellIconDefaultVersion ~= 1 then
        -- Legacy saves cannot distinguish the old default from a manually selected false.
        settings.showKillSpellIcon = true
        settings.killingSpellIconDefaultVersion = 1
    end
    if settings.markerStyleVersion ~= 2 then
        settings.fillColor, settings.plateFillColor = "school", "school"
        settings.markerStyleVersion = 2
    end
    if type(settings.learned) ~= "table" then settings.learned = {} end
    -- Factors learned before the talent engine (0.9.91) made up for talents the prediction did not know; with the
    -- engine the same talents would count twice until the hits had taught the factor again.
    if settings.talentEngine ~= 1 then
        settings.learned = {}
        settings.talentEngine = 1
    end
    -- Entries saved by the first versions (no `v`) hold the square root of the factor they were meant to find: the old
    -- update blended each hit's ratio to the already scaled prediction into the factor. Squared they are the factor,
    -- as far as it was learned, and worth a few hits only.
    for _, entry in pairs(settings.learned) do
        if type(entry) == "table" and entry.v == nil then
            local factor = tonumber(entry.factor)
            if factor then entry.factor = clampFactor(factor * factor) end
            entry.samples = math.min(tonumber(entry.samples) or 0, 5)
            entry.v = LEARN_SCHEMA
        end
    end
    if type(settings.log) ~= "table" then settings.log = {} end
    if type(settings.talentForce) ~= "table" then settings.talentForce = {} end
    if type(settings.auraForce) ~= "table" then settings.auraForce = {} end
    -- A number the settings want but a stale save holds as a string or nil.
    settings.manualPowerValue = tonumber(settings.manualPowerValue) or 0
    ns.settings = settings
    return settings
end
ns.DEFAULTS = DEFAULTS

function ns.resetLog()
    if settings then settings.log = {} end
end

---------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
pcall(frame.RegisterEvent, frame, "PLAYER_SOFT_ENEMY_CHANGED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
frame:RegisterEvent("UNIT_COMBAT")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
for _, event in ipairs({ "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED",
    "SPELL_TEXT_UPDATE", "SPELL_DATA_LOAD_RESULT", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
    "ACTIONBAR_SLOT_CHANGED" }) do
    pcall(frame.RegisterEvent, frame, event)
end
-- Never register COMBAT_LOG_EVENT_UNFILTERED: Forever forbids it and shows a "blocked" popup.

frame:SetScript("OnEvent", function(self, event, ...)
    keyMemoAt = nil -- an event may have changed who is where: no key read before it is trusted
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        if BIT.ShouldRun and not BIT.ShouldRun("CastPrediction") then
            ns.off = true
            self:UnregisterAllEvents()
            self:SetScript("OnUpdate", nil)
            return
        end
        ns.ensureDB()
        trace("===== session start =====")
        attach()
        self:UnregisterEvent("ADDON_LOADED")

    elseif not settings then
        return

    elseif event == "PLAYER_ENTERING_WORLD" then
        dropCast("loading screen")
        wipe(recipients)
        wipe(plateKeys)
        invalidateView()
        if ns.Talents then ns.Talents.Invalidate() end
        safeRefresh()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        invalidateView()
        if ns.Talents then ns.Talents.Invalidate() end
        dropCast("specialization changed")
        safeRefresh()

    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        local token = ...
        if isSecret(token) or type(token) ~= "string" then return end
        local old = plateKeys[token]
        plateKeys[token] = nil
        if old and old:match("^cast%-plate:") then
            for _, sent in pairs(recipients) do
                if sent.key == old then sent.key = nil end
            end
            if castInProgress and castInProgress.key == old then dropCast("nameplate recycled") end
        end
        safeRefresh()

    elseif event == "UNIT_AURA" then
        local unit = ...
        if not isSecret(unit) and unit == "player" then invalidateView() end

    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        finisherScan.dirty = true

    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_REGEN_ENABLED"
        or event == "SPELL_TEXT_UPDATE" or event == "SPELL_DATA_LOAD_RESULT" or event == "SPELLS_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
        if event == "PLAYER_REGEN_ENABLED" and not previewHost then attach() end
        invalidateView()
        finisherScan.dirty = true
        if ns.Talents and (event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE"
            or event == "TRAIT_CONFIG_UPDATED") then ns.Talents.Invalidate() end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if not previewHost and not (type(InCombatLockdown) == "function" and InCombatLockdown()) then attach() end
        dropCast("target changed")
        for _, sent in pairs(recipients) do
            if sent.key == "target" then sent.key = nil end
        end
        safeRefresh()

    elseif event == "PLAYER_FOCUS_CHANGED" then
        safeRefresh()

    elseif event == "PLAYER_SOFT_ENEMY_CHANGED" then
        safeRefresh()

    elseif event == "UNIT_SPELLCAST_SENT" then
        local _, targetName, castGUID, spellID = ...
        onCastSent(targetName, castGUID, spellID)

    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local _, castGUID, spellID = ...
        if onCastStart(castGUID, spellID, event == "UNIT_SPELLCAST_CHANNEL_START") then safeRefresh() end

    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local _, castGUID, spellID = ...
        if castInProgress and castInProgress.channel and sameCast(castInProgress, castGUID, spellID) then
            local startedAt, endsAt = channelTimes(castInProgress.spellID)
            if endsAt then
                castInProgress.startedAt, castInProgress.endsAt = startedAt, endsAt
                castInProgress.channelDuration = endsAt - startedAt
            else
                dropCast("channel timing unavailable")
            end
            safeRefresh()
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local _, castGUID, spellID = ...
        if castInProgress and castInProgress.channel and sameCast(castInProgress, castGUID, spellID) then
            dropCast("channel stopped")
            safeRefresh()
        end

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local _, castGUID, spellID = ...
        if onCastEnded(event, castGUID, spellID) then safeRefresh() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, castGUID, spellID = ...
        if onCastSucceeded(castGUID, spellID) then safeRefresh() end

    elseif event == "UNIT_COMBAT" then
        local outcome = onUnitCombat(...)
        if outcome then
            safeRefresh()
            if outcome ~= "avoided" then playFlash() end -- an avoided cast just loses its marker
        end
    end
end)

local sinceUpdate = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    if not settings then return end
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL then return end
    sinceUpdate = 0
    safeRefresh()
end)
if BIT.Perf then BIT.Perf.Watch(frame, "OnEvent", "CastPrediction") end
if BIT.Perf then BIT.Perf.Watch(frame, "OnUpdate", "CastPrediction") end


-- /upt castpred layers: what sits where on the target frame, for a report when the marker draws under Blizzard's bar.
function ns.dumpLayers()
    local function label(f)
        local name = read(f.GetName, f)
        if type(name) == "string" and name ~= "" then return name end
        local parent = read(f.GetParent, f)
        if type(parent) == "table" then
            local okKey, key = pcall(function()
                for k, v in pairs(parent) do
                    if v == f and type(k) == "string" then return k end
                end
            end)
            if okKey and key then return "." .. key end
        end
        return "<" .. tostring(read(f.GetObjectType, f)) .. ">"
    end
    local function info(f)
        return string.format("%s %s/%s shown=%s alpha=%.2f", label(f), tostring(read(f.GetFrameStrata, f)),
            tostring(read(f.GetFrameLevel, f)), tostring(read(f.IsShown, f)), number(read(f.GetEffectiveAlpha, f)) or -1)
    end
    local function say(text)
        trace("LAYERS " .. text)
        print(text)
    end
    if not healthBar then
        say("no target health bar attached yet (target something and let the marker show first)")
        return
    end
    say("bar: " .. info(healthBar))
    local chain, f = {}, healthBar
    for _ = 1, 6 do
        f = read(f.GetParent, f)
        if type(f) ~= "table" or f == UIParent then break end
        chain[#chain + 1] = info(f)
    end
    say("parents: " .. (#chain > 0 and table.concat(chain, " < ") or "none"))
    local parent = read(markerClip.GetParent, markerClip)
    say("marker clip parent: " .. (type(parent) == "table" and label(parent) or "none"))
    local maskLooks = BIT.UI and BIT.UI.BarMask
    local foundMask = maskLooks and maskLooks.Find(healthBar)
    local function masks(texture)
        local count = texture and read(texture.GetNumMaskTextures, texture)
        return tostring(number(count) or "?")
    end
    say("shape mask: bar's own mask " .. (foundMask and "found" or "NOT found") .. "; masks on our fill: " .. masks(fillTex)
        .. ", outline: " .. masks(edges[1]))
    say("ours: clip " .. info(markerClip) .. " | marker " .. info(marker) .. " | fill " .. info(fillLayer)
        .. " | outline " .. info(outlineLayer) .. " | label " .. info(labelLayer))
    local left, right = number(read(healthBar.GetLeft, healthBar)), number(read(healthBar.GetRight, healthBar))
    local top, bottom = number(read(healthBar.GetTop, healthBar)), number(read(healthBar.GetBottom, healthBar))
    local root = healthBar
    for _ = 1, 10 do
        local up = read(root.GetParent, root)
        if type(up) ~= "table" or up == UIParent then break end
        root = up
    end
    local found, visited = {}, 0
    local function visit(frame, depth)
        visited = visited + 1
        if visited > 400 or frame == markerClip then return end
        if read(frame.IsForbidden, frame) == true then return end
        if read(frame.IsShown, frame) == true and left then
            local l, r = number(read(frame.GetLeft, frame)), number(read(frame.GetRight, frame))
            local t, b = number(read(frame.GetTop, frame)), number(read(frame.GetBottom, frame))
            if l and r and t and b and l < right and r > left and b < top and t > bottom then
                found[#found + 1] = { frame = frame, rank = STRATA_RANK[read(frame.GetFrameStrata, frame)] or 0,
                    level = number(read(frame.GetFrameLevel, frame)) or 0 }
            end
        end
        if depth < 8 then
            local children = { pcall(frame.GetChildren, frame) }
            if children[1] then
                for i = 2, #children do visit(children[i], depth + 1) end
            end
        end
    end
    visit(root, 0)
    table.sort(found, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.level > b.level
    end)
    say(string.format("frames over the bar under %s (%d seen), highest first:", label(root), visited))
    for i = 1, math.min(12, #found) do say("  " .. info(found[i].frame)) end
end

---------------------------------------------------------------------------------------------
-- Commands (/upt castpred, /upt castprobe, ...)
---------------------------------------------------------------------------------------------

if BIT.RegisterCommand then
    BIT.RegisterCommand("castpred", function(rest)
        local cmd = strlower(strtrim(rest or ""))
        if cmd == "" or cmd == "options" or cmd == "config" then
            if BIT.OpenSettings then BIT.OpenSettings("CastPrediction") end
        elseif cmd == "line" then
            settings.showMarker = not settings.showMarker
            print(settings.showMarker and BIT.L("Health bar marker ON.") or BIT.L("Health bar marker OFF."))
        elseif cmd == "reset" then
            ns.resetLearned()
        elseif cmd == "census" or cmd == "census clear" then
            if not ns.Talents or type(ns.Talents.Census) ~= "function" then
                print("Talents file not loaded.")
            elseif cmd == "census clear" then
                ns.Talents.ClearCensus()
                print("The talent census is cleared from the saved settings.")
            else
                local census, why = ns.Talents.Census()
                if not census then
                    print("No census: " .. tostring(why))
                else
                    print(string.format("%d talents read; %d carry a percent next to damage or healing that the lists do not use. "
                        .. "Kept in the saved settings (CastPrediction, census) until /upt castpred census clear.",
                        #census.nodes, census.candidates))
                    if census.unread > 0 then
                        print(string.format("%d talents have no text yet (not loaded): run it again in a minute.", census.unread))
                    end
                    if census.truncated then print("The tree is bigger than the census keeps: the last talents are missing.") end
                    local shown = 0
                    for _, node in ipairs(census.nodes) do
                        if node.c and shown < 12 then
                            shown = shown + 1
                            print(string.format("  %s %d/%d: %s", tostring(node.n), node.r or 0, node.m or 0, node.t))
                        end
                    end
                end
            end
        elseif cmd == "learned" then
            for _, line in ipairs(ns.LearnedLines()) do print(line) end
        elseif cmd == "talents" then
            if ns.Talents and type(ns.Talents.ProbeLines) == "function" then
                for _, line in ipairs(ns.Talents.ProbeLines()) do print(line) end
            else
                print("Talents file not loaded.")
            end
        elseif cmd == "auras" then
            if ns.Auras and type(ns.Auras.ProbeLines) == "function" then
                for _, line in ipairs(ns.Auras.ProbeLines()) do print(line) end
            else
                print("Auras file not loaded.")
            end
        elseif cmd == "layers" then
            ns.dumpLayers()
        elseif cmd == "debug" then
            settings.debug = not settings.debug
            print("Debug " .. (settings.debug and "ON" or "OFF") .. ".")
        elseif cmd == "help" then
            print(BIT.L("/upt castpred - open the settings; line - toggle the marker; talents - what the talent tree "
                .. "answers; auras - what buffs/debuffs are readable; learned - what the hits taught; census - read the whole talent tree into the saved settings (census clear removes it); reset - forget learned factors; debug - echo the trace log"))
        else
            print("CastPrediction: /upt castpred [line|talents|auras|learned|census|census clear|reset|debug|layers]")
        end
    end)
end

-- What spell is on the player's cast bar right now (diagnostics).
local function probeSpellID()
    if type(UnitChannelInfo) == "function" then
        local ok, _, _, _, _, _, _, _, spellID = pcall(UnitChannelInfo, "player")
        if ok and number(spellID) then return spellID, true end
    end
    if type(UnitCastingInfo) == "function" then
        local ok, _, _, _, _, _, _, _, _, spellID = pcall(UnitCastingInfo, "player")
        if ok then return number(spellID), false end
    end
end

if BIT.RegisterCommand then
    BIT.RegisterCommand("castprobe", function()
        local spellID, channel = probeSpellID()
        if not spellID then
            print("No spell is being cast right now.")
            return
        end
        local view = buildView(spellID, channel)
        local name = spellName(spellID) or "?"
        if not view then
            print(string.format("%s (id %d): no readable damage description for this cast.", name, spellID))
            return
        end
        local prediction = predictionFor(view, spellID)
        print(string.format("%s (id %d): %d-%d %s%s; showing %d%s", name, spellID, math.floor(view.min + 0.5),
            math.floor(view.max + 0.5), tostring(view.school), view.estimated and " (with spell power)" or "",
            math.floor(prediction.value + 0.5),
            prediction.samples and ("; factor from " .. prediction.samples .. " hit(s)") or ""))
    end)
end

-- Shared with the options, aura and talent modules.
ns._settings = function() return settings end
ns._colorList = function() return COLOR_LIST end
ns._defaults = function() return DEFAULTS end
ns._refresh = safeRefresh
