-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module DoTInfo: Death Mark (WoW: Forever rogue talent). Experimental, off by default.
--
-- A finisher that marks the target ("Marked for Death"): for 6 s it stores a share of the damage your attacks deal
-- to it, 12% per combo point (Garrote and Rupture at twice the rate), then deals what it stored at once, up to a cap
-- the client works out from your attack power and crit chance and writes into the description, one row per combo
-- point. The mark shows as one more segment on the marker: what it has stored so far, never more than the cap,
-- until it goes off.
--
-- UNIT_COMBAT names the mob that was hit, not who hit it, so every hit on the marked mob counts as yours. Alone that
-- is right; in a group the others' damage is counted too and the estimate runs high. Hence the setting (deathMark,
-- Behavior tab) is off by default and says so.
-- Unverified in game: the description's wording (taken from Wowhead's Forever tooltips, which show the cap as a
-- formula), whether the burst is reduced by armor, and that UNIT_COMBAT reports every hit that feeds the mark.
--
-- Everything here is Forever only (Retail has no readable source for a hit, and no Death Mark).
local _, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("DoTInfo")

local M = {}
ns.DeathMark = M

local SPELL_IDS = { [1316709] = true, [1325756] = true, [1325757] = true, [1325758] = true } -- ranks 1-4
local DURATION = 6           -- SpellDuration of every rank: 6000 ms
local RATE_PER_POINT = 0.12  -- when the description's row can't be read
local DOUBLE_RATE_IDS = { 703, 1943 } -- Garrote, Rupture: looked up by id so the names match any client language
local LATE = 0.1             -- a hit this close to the end is taken for the burst itself, not stored

local marks = {}             -- [mob key] = the mark's dot (also in dotsByTarget)
local doubleRateNames

local function I() return ns.Internals end

local function enabled()
    local internals = I()
    local settings = internals and internals.getDb()
    return settings ~= nil and settings.deathMark == true
end

local function trace(msg) I().trace(msg) end

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)
        if ok and type(name) == "string" then return name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, id)
        if ok and type(name) == "string" then return name end
    end
end

local function isDoubleRate(name)
    if not doubleRateNames then
        doubleRateNames = { Garrote = true, Rupture = true }
        for _, id in ipairs(DOUBLE_RATE_IDS) do
            local local_ = spellName(id)
            if local_ then doubleRateNames[local_] = true end
        end
    end
    return doubleRateNames[name] == true
end

-- "1,054" / "1 054" / "1054" -> 1054. A decimal part of one or two digits is kept as such.
local function number(text)
    if not text then return nil end
    text = text:gsub("[%s\194\160]", "")
    local whole, fraction = text:match("^(%d+)[%.,](%d%d?)$")
    if whole then return tonumber(whole .. "." .. fraction) end
    return tonumber((text:gsub("[^%d]", "")))
end

-- The description's row for `points` combo points, e.g. "3 points: 36% stored, 1054 damage cap". Read by its
-- structure (a count, a percentage, then the cap), not its words, so other client languages read the same way.
-- Returns the stored share (0.36) and the cap (1054), or nil.
function M.ReadRow(desc, points)
    if type(desc) ~= "string" then return nil end
    for line in desc:gmatch("[^\r\n]+") do
        local count = tonumber(line:match("^[^%d%%]*(%d+)"))
        local percent = tonumber(line:match("(%d+%.?%d*)%s*%%"))
        if count == points and percent and percent >= 5 * points and percent <= 30 * points then
            return percent / 100, number(line:match("%%[^%d]*(%d[%d,%.\194\160 ]*%d)") or line:match("%%[^%d]*(%d)"))
        end
    end
end

-- From onPlayerCast (Core.lua), before the description is parsed as a DoT. Returns handled, appliedTo.
function M.OnCast(key, spellID, name, desc, comboPoints, comboSource)
    if not SPELL_IDS[spellID] then return false end
    if not enabled() then return true end
    if not key then
        trace(string.format("DEATHMARK %s (id %d): no target, not tracked", name, spellID))
        return true
    end
    local points = comboPoints or 1
    local rate, cap = M.ReadRow(desc, points)
    local readRate = rate ~= nil
    rate = rate or RATE_PER_POINT * points
    local internals, now = I(), GetTime()
    local dot = internals.newDot(spellID, nil, name, 0, 1, DURATION, DURATION, now)
    dot.predictionOnly, dot.burst, dot.unsure = true, true, true
    dot.stored, dot.rate, dot.cap = 0, rate, cap
    local dots = internals.dotsByTarget
    dots[key] = dots[key] or {}
    dots[key][name] = dot
    for other, mark in pairs(marks) do
        if now > mark.expiresAt + 1 then marks[other] = nil end
    end
    marks[key] = dot
    trace(string.format("DEATHMARK %s (id %d) on %s: %s combo points (%s), %.0f%% stored%s, cap %s", name, spellID,
        tostring(key), comboPoints or "?", comboSource or "unknown", rate * 100, readRate and "" or " (assumed)",
        cap and tostring(cap) or "unread"))
    return true, key
end

-- Whether the mark is still tracked: a target change or a removed nameplate drops the mob's DoTs, the mark with them.
local function stillTracked(key, dot)
    for _, tracked in pairs(I().dotsByTarget[key] or {}) do
        if tracked == dot then return true end
    end
    return false
end

local function store(key, amount, now)
    local dot = marks[key]
    if not stillTracked(key, dot) then
        marks[key] = nil
        return
    end
    if now >= dot.expiresAt - LATE or now < dot.appliedAt then return end
    dot.stored = dot.stored + amount * dot.rate
    dot.total = dot.cap and math.min(dot.cap, dot.stored) or dot.stored
end

-- Every hit on a mob (Core.lua's onUnitCombat, after copies from other unit tokens are dropped).
function M.OnHit(key, amount, now)
    if marks[key] and type(amount) == "number" and amount > 0 then store(key, amount, now) end
end

-- A hit that was matched as a tick of `name`: Garrote and Rupture are stored at twice the rate.
function M.OnTick(key, name, amount, now)
    if marks[key] and type(amount) == "number" and amount > 0 and isDoubleRate(name) then store(key, amount, now) end
end
