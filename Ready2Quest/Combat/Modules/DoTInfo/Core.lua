-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module DoTInfo: the module's own runtime. Based on the standalone DoT addon's
-- runtime file at e4faef4 by Joe Greive (MIT); it lives only here now and is edited directly.
-- DoTInfo
-- Tracks your DoTs on the target and shows the damage they still have to deal as a marker on its health
-- bar (if the health ends inside the marker, the DoTs will kill it), plus a skull on the portrait when
-- they're lethal. Look and animation are configurable in the options panel (/dotinfo).
--
-- In WoW: Forever, target health, player stats and auras are secret in combat, so addon code can
-- never compare "health vs DoT damage" itself. What stays readable:
--   * our own casts (UNIT_SPELLCAST_SUCCEEDED) and spell descriptions -> which DoT, base damage, duration
--   * UNIT_COMBAT damage amounts on units -> actual tick sizes (already include resists/reductions)
-- StatusBars accept secret values, so the "damage >= health" comparison is done by the widget, not
-- by Lua: see the skull notes in the Display section.

local ADDON_NAME, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
-- Ready2QuestCombat's own namespace for the module, shared by its four files.
local ns = BIT.Module("DoTInfo")

local UPDATE_INTERVAL = 0.1
local DEFAULT_TICK_INTERVAL = 3
-- Seconds either side of an expected tick time. Observed on Forever: the first tick lands within ~0.1s of one
-- interval after the cast, and later ticks within ~0.1s of the first tick's rhythm. Tight windows keep melee
-- auto-attacks (same Physical school as bleeds, similar size, ~1s rhythm) from passing as ticks.
local TICK_MATCH_WINDOW = 0.45
local TICK_MATCH_WINDOW_ANCHORED = 0.25
local MISSED_TICKS_BEFORE_DROP = 2  -- a DoT that never ticks was resisted/immune
-- Projectile DoTs start when the projectile lands, not on the cast event: Serpent Sting's first tick came
-- 3.6-3.9s after the cast instead of 3s (DoesItDie log 253548.7, 12 casts). Their first tick may be this much
-- later; the same allowance keeps housekeep from counting a missed tick before the projectile has landed.
local PROJECTILE_DOTS = {
    travel = 1.5,
    ["Serpent Sting"] = true, ["Fireball"] = true, ["Pyroblast"] = true, ["Frostfire Bolt"] = true,
}
-- Once a DoT's tick size is known, same-school hits further off than this are someone else's (the Imp's
-- Firebolt next to Immolate, white hits next to Rip). Ticks within one cast barely vary (15,15,15,16);
-- the minimum slack of 1 covers rounding (3 vs 4).
local TICK_AMOUNT_TOLERANCE = 0.25
-- Check for the first tick against a size learned on an earlier cast (gear/AP may have changed a little).
local FIRST_TICK_AMOUNT_TOLERANCE = 0.3
-- A crit tick is 1.5-2x a normal one; anything else flagged as a crit (white-hit crits) isn't this DoT.
local CRIT_MIN_RATIO, CRIT_MAX_RATIO = 1.3, 2.3
local DB_VERSION = 6                -- bump to discard learned data from older, buggier versions (6: learned sizes per character)

-- Tick intervals that differ from the 3s default and aren't stated in the description.
local KNOWN_TICK_INTERVALS = {
    ["Insect Swarm"] = 2,
    ["Curse of Agony"] = 2,
    ["Bane of Agony"] = 2, -- Forever's name for Curse of Agony
    ["Fireball"] = 2,
    ["Holy Fire"] = 2,
    ["Rip"] = 2,
    ["Rupture"] = 2,
    ["Black Arrow"] = 2, -- the description gives the total over 30 sec only
    ["Wyvern Sting"] = 2, -- client data: its DoT (24336) ticks every 2 s
}

-- DoTs whose ticks aren't even: each tick is the average tick times its factor (factors average 1, so the
-- tooltip total still holds). Agony is back-loaded; seen in-game on Forever (log 166015.8, 72 over 24s):
-- ticks 3,3,3,3 then 6,6,... then 9s. Everything else ticks evenly.
local TICK_SHAPES = {}
do
    local agony = { 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 1, 1.5, 1.5, 1.5, 1.5 }
    TICK_SHAPES["Bane of Agony"] = agony -- Forever's name
    TICK_SHAPES["Curse of Agony"] = agony
end

-- Amplify Curse (Forever spell 18288): "Increases the effect of your next Curse of Weakness or Bane of Agony by 50%, or
-- your next Curse of Exhaustion by 20%. Lasts 30 sec." One charge, 3 min cooldown (the client's tables, build 70790).
-- A tooltip number and a learned tick size are both what the spell does without the buff, and a buffed tick is far
-- outside what the tick matching accepts, so Agony's buffed ticks were thrown away as someone else's hits and the
-- marker stayed on the unbuffed damage. The buff itself is secret in combat, its cast is not: the charge goes to the next
-- cast of one of the curses below (by name: the tables answer to every language), whatever becomes of that cast.
-- "start" is the Amplify Curse cast itself (also found by its spell id), "boost" raises that DoT's ticks by `boost`, and
-- "charge" only takes the charge (those curses deal no damage). A DoT flagged this way is checked against its ticks
-- (tryRelearn): if they say the buff did not reach it, it goes back to its own size. Nothing else ever flags a DoT, so
-- every DoT cast without Amplify Curse behaves exactly as before.
ns.AMPLIFY = { spellID = 18288, seconds = 30, boost = 1.5 }
ns.AMPLIFY_USES = {
    ["Amplify Curse"] = "start",
    ["Bane of Agony"] = "boost", ["Curse of Agony"] = "boost", -- Forever's name and Classic's
    ["Curse of Weakness"] = "charge", ["Curse of Exhaustion"] = "charge",
}

-- Descriptions that don't name their school (Siphon Life's, and in Chinese also Corruption's, Fireball's and
-- Pyroblast's periodic part). Ported from Does It Die v0.8.3.
local SCHOOL_BY_NAME = {
    ["Siphon Life"] = 32, ["Corruption"] = 32, ["Fireball"] = 4, ["Pyroblast"] = 4,
}

-- Read like DoTs but aren't one on the current target: ground/area effects, channels, traps, and
-- delayed damage (Wyvern Sting is handled apart, see DELAYED_DOTS).
local IGNORED_SPELLS = {
    ["Rain of Fire"] = true, ["Hellfire"] = true, ["Blizzard"] = true, ["Flamestrike"] = true,
    ["Consecration"] = true, ["Hurricane"] = true, ["Volley"] = true,
    ["Drain Life"] = true, ["Drain Soul"] = true, ["Drain Mana"] = true, ["Health Funnel"] = true,
    ["Mind Flay"] = true, ["Arcane Missiles"] = true, ["Starshards"] = true,
    ["Explosive Trap"] = true,
}

-- The name-keyed tables also answer to the German names, and on ADDON_LOADED to the names this client reports
-- for them (Locale.lua).
-- A gold edge on the segment when the refresh window is open. German names are listed
-- here on purpose: the cue must not depend on alias tables being applied first.
ns.refreshNames = {
    ["Curse of Agony"] = true, ["Bane of Agony"] = true,
    ["Corruption"] = true, ["Shadow Word: Pain"] = true,
    ["Fluch der Pein"] = true, ["Omen der Pein"] = true,
    ["Verderbnis"] = true, ["Schattenwort: Schmerz"] = true,
}

-- Traps that put a DoT on the first enemy to walk in (ProcDots.lua): placing one only arms it.
ns.TRAP_DOTS = { ["Immolation Trap"] = true }
-- Cast at a mob, but the DoT starts later (ProcDots.lua finds the start by its rhythm).
ns.DELAYED_DOTS = { ["Wyvern Sting"] = true }
-- Any new Fire trap replaces the armed one (by name, so it works in every language).
ns.FIRE_TRAPS = { ["Immolation Trap"] = true, ["Explosive Trap"] = true }
-- This projectile has no direct damage confirming that the cast actually landed.
ns.CONFIRM_PROJECTILE_DOTS = { ["Serpent Sting"] = true }

local NAME_TABLES = { KNOWN_TICK_INTERVALS, TICK_SHAPES, SCHOOL_BY_NAME, IGNORED_SPELLS, PROJECTILE_DOTS, ns.refreshNames,
    ns.TRAP_DOTS, ns.FIRE_TRAPS, ns.DELAYED_DOTS, ns.AMPLIFY_USES, ns.CONFIRM_PROJECTILE_DOTS }
ns.locale.addNames(NAME_TABLES)

local SCHOOL_MASKS = {
    Physical = 1, Holy = 2, Fire = 4, Nature = 8, Frost = 16, Shadow = 32, Arcane = 64,
    Frostfire = 4 + 16, -- Forever's Frostfire Bolt: combined schools report as the OR of their masks
    Shadowflame = 4 + 32, -- Forever's Shadowflame (SpellMisc.SchoolMask 36)
}

-- User options (edited in the options panel, saved in Ready2QuestCombat_DoTInfoDB).
local DEFAULTS = {
    -- Skull
    showSkull = true,
    skullIcon = "cross",
    skullSize = 72,
    skullPosition = "portrait",
    skullPulse = true,
    skullOffsetX = 0,
    skullOffsetY = 0,
    -- Damage marker
    showMarkers = true,
    targetMarkers = true, -- off: the marker stays on nameplates/focus only (target frame addons it can't follow)
    fillTexture = "stripes",
    fillColor = "red",
    fillOpacity = 100,
    fillDirection = "auto", -- auto follows the health bar (mirrored unit frames fill right to left)
    dotColors = "each",
    segmentDividers = true,
    outlineStyle = "dashed",
    dashLength = 4,
    outlineThickness = 1,
    outlineColor = "red",
    outlineOpacity = 85,
    -- Animation
    smoothMotion = true,
    flashOnApply = true,
    pulseOutline = true,
    -- Effects
    showSpark = true,
    showGlow = true,
    glowSize = 7,
    showShine = true,
    shineInterval = 3,
    scrollStripes = true,
    -- Damage text
    showLabel = false,
    refreshCue = true, -- gold edge on Agony, Corruption and Shadow Word: Pain inside the refresh window
    labelPosition = "center",
    labelSize = 10,
    labelColor = "white",
    -- Misc
    procDots = true, -- Ignite (mage) and Deep Wounds (warrior), lit by crits (ProcDots.lua)
    deathMark = false, -- experimental: Death Mark (rogue) stored damage (DeathMark.lua); counts others' hits in a group
    debug = false,
    -- Accuracy
    waitFirstTick = "off",
    estimateDuringCast = true,
    swingKill = true, -- a weapon icon shows when the DoTs plus one average weapon hit (melee swing, wand or ranged shot) kill
    killMargin = 90, -- % of the estimate the kill icon trusts: heals, regen and estimate error eat the rest
    targetOverMouseover = false, -- a same-named mob under the mouse doesn't blank a target cast (_namedEnemyKey)
    -- Nameplates (Nameplates.lua): their own look, since enemy plates are red. Defaults read well on red.
    nameplateMode = "markerIcon",
    focusMode = "markerIcon",       -- the focus frame's marker (Focus.lua), in the nameplates' look
    nameplateIconSize = 24,
    nameplateIconPosition = "above",
    plateIconOffsetX = 0,
    plateIconOffsetY = 0,
    plateIcon = "skull",
    plateDotColors = "rainbow",
    plateFillDirection = "auto",
    plateFillTexture = "flat",
    plateFillColor = "white",
    plateFillOpacity = 45,
    plateOutlineStyle = "solid",
    plateDashLength = 2,
    plateOutlineThickness = 1,
    plateOutlineColor = "white",
    plateOutlineOpacity = 100,
}

-- "Wait for first tick": whether a DoT counts toward the marker before its first tick has landed.
-- "unsure" = only when the starting estimate is shaky (finisher with unknown combo points, or no tick size
-- learned yet for that spell).
local WAIT_MODES = {
    { id = "off",    label = "Never (estimate straight away)" },
    { id = "unsure", label = "When unsure" },
    { id = "always", label = "Always (real ticks only)" },
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
    local looks = BIT.Looks
    for _, preset in ipairs(looks and looks.Palette or {}) do
        if not COLOR_BY_ID[preset.id] then
            COLOR_PRESETS[#COLOR_PRESETS + 1] = preset
            COLOR_BY_ID[preset.id] = preset.rgb
        end
    end
end

local MAX_TRACE_LINES = 500

local db
local dotsByTarget = {}     -- targetKey -> { [spellName] = dot }
local warnedSecretGuid = false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff6666DoTInfo|r " .. msg)
end

-- Always recorded to SavedVariables (db.log) for diagnosing accuracy; echoed to chat with /dotinfo debug.
local function trace(msg)
    if not db then return end
    table.insert(db.log, string.format("%.1f %s", GetTime(), msg))
    if #db.log > MAX_TRACE_LINES then table.remove(db.log, 1) end
    if db.debug then print("|cff888888" .. msg .. "|r") end
end

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- ponytail: known shields/immunities only; extend this list when another relevant aura is identified.
do
local protectionSpells = {
    [17] = true, [11426] = true, [1463] = true, [7812] = true, -- priest, mage, warlock shields
    [642] = true, [1022] = true, [45438] = true, [31224] = true, [48707] = true,
    [212295] = true, -- Nether Ward
}
local protectionNames = {}
local bopName
for id in pairs(protectionSpells) do
    local getName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if type(getName) == "function" then
        local ok, name = pcall(getName, id)
        if ok and not isSecret(name) and type(name) == "string" then
            protectionNames[name] = true
            if id == 1022 then bopName = name end
        end
    end
end

-- Only a positively detected absorb or known protection aura hides the kill icon. Secret/unreadable
-- state (common on Forever in combat) counts as unshielded: hiding on "unknown" hid it on plain mobs.
function ns.shielded(unit, entries)
    -- Mixed damage and weapon hits cannot safely count their physical portion through BoP.
    local physical = not entries or #entries == 0 or (ns.db and ns.db.swingKill)
    for _, entry in ipairs(entries or {}) do
        if isSecret(entry.school) or type(entry.school) ~= "number" or entry.school % 2 == 1 then physical = true break end
    end
    if type(UnitGetTotalAbsorbs) == "function" then
        local ok, amount = pcall(UnitGetTotalAbsorbs, unit)
        if ok and not isSecret(amount) and type(amount) == "number" and amount > 0 then return true end
    end
    local getAura = C_UnitAuras and (C_UnitAuras.GetBuffDataByIndex or C_UnitAuras.GetAuraDataByIndex)
    if type(getAura) ~= "function" and type(UnitBuff) ~= "function" then return false end
    for i = 1, 40 do
        local ok, aura, name, id
        if type(getAura) == "function" then
            ok, aura = pcall(getAura, unit, i, "HELPFUL")
            if not ok or aura == nil then return false end
            if not isSecret(aura) and type(aura) == "table" then
                ok, name, id = pcall(function() return aura.name, aura.spellId end)
            end
        else
            local icon, count, debuffType, duration, expires, source, stealable, consolidate
            ok, name, icon, count, debuffType, duration, expires, source, stealable, consolidate, id =
                pcall(UnitBuff, unit, i)
            if not ok or name == nil then return false end
        end
        -- Unreadable entries are skipped so a readable shield further down still counts.
        if ok and not isSecret(id) and type(id) == "number" and protectionSpells[id]
            and not (not physical and id == 1022) then return true end
        if ok and not isSecret(name) and type(name) == "string" and protectionNames[name]
            and not (not physical and name == bopName) then return true end
    end
    return false
end
end

-- The nameplate token ("nameplate3") of the mob behind `unit`, or nil (no plate, plates off, or unreadable).
-- Mob GUIDs are secret in Forever's instances (Does It Die PR #8, verified in a dungeon), but a mob keeps its
-- nameplate token from NAME_PLATE_UNIT_ADDED to NAME_PLATE_UNIT_REMOVED, and C_NamePlate.GetNamePlateForUnit
-- still finds the target's plate. So the token stands in for the GUID while the plate is up; the nameplate events
-- drop its DoTs before the token goes to another mob. A field on ns: this chunk is at Lua 5.1's 200-local limit.
function ns._plateTokenFor(unit)
    if type(unit) == "string" and unit:match("^nameplate%d+$") then return unit end
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or isSecret(plate) or type(plate) ~= "table" then return nil end
    local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    if type(token) ~= "string" or isSecret(token) or not token:match("^nameplate%d+$") then return nil end
    return token
end

-- Stable key for the mob behind a unit token, or nil if the unit can't be tracked: its GUID when readable (open
-- world); "plate:nameplateN" when the GUID is secret (instances) and the mob has a nameplate; "target" as the last
-- resort (secret GUID, no plate: only the current target is tracked, and target changes drop its DoTs).
-- The same hit arrives for target, nameplateN and softenemy, and their GUIDs may not all be readable,
-- so a hidden GUID only affects that one unit token.
local function unitKey(unit)
    if ns.Retail then return ns.Retail.UnitKey(unit) end
    local ok, guid = pcall(UnitGUID, unit)
    if ok and not isSecret(guid) then return guid end
    -- A secret action-target GUID can still identify the same mob as a readable nameplate.
    -- Only trust the game's plain identity answer, then keep that plate's real GUID across switches.
    -- (A nameplate token is its own plate: the loop could only find itself.)
    if ok and isSecret(guid) and type(UnitIsUnit) == "function" and not unit:match("^nameplate%d+$") then
        for i = 1, 40 do
            local plateUnit = "nameplate" .. i
            local sameOK, same = pcall(UnitIsUnit, plateUnit, unit)
            if sameOK and not isSecret(same) and same == true then
                local guidOK, plateGUID = pcall(UnitGUID, plateUnit)
                if guidOK and not isSecret(plateGUID) and plateGUID then return plateGUID end
            end
        end
    end
    local token = ns._plateTokenFor(unit)
    if token then
        if warnedSecretGuid ~= "plate" then
            warnedSecretGuid = "plate"
            trace("Mob GUIDs are secret here (instance?); tracking each mob by its nameplate instead")
        end
        return "plate:" .. token
    end
    if unit ~= "target" then return nil end
    if warnedSecretGuid ~= "target" then
        warnedSecretGuid = "target"
        trace("Target GUID is secret and it has no nameplate; tracking DoTs on the current target only"
            .. " (turn on enemy nameplates to track several mobs)")
    end
    return "target"
end

function ns._selectedEnemyKey()
    local ok, attackable = pcall(UnitCanAttack, "player", "target")
    -- A corpse can't be cast at: with a dead hard target the game uses the soft target.
    local deadOK, dead = pcall(UnitIsDeadOrGhost, "target")
    local key = ok and not isSecret(attackable) and attackable == true
        and not (deadOK and not isSecret(dead) and dead == true) and unitKey("target")
    return key or unitKey("softenemy")
end

local function spellNameAndDescription(spellID)
    local name, desc
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(spellID)
    else
        name = GetSpellInfo(spellID)
    end
    local descFn = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if descFn then desc = descFn(spellID) end
    return name, desc
end

local function schoolFromWords(words)
    local school = SCHOOL_MASKS.Physical
    for word in words:gmatch("%a+") do
        if SCHOOL_MASKS[word] then school = SCHOOL_MASKS[word] end
    end
    return school
end

-- Finishers (Rip, Rupture) list their DoT per combo point:
--   "1 point : 243 damage over 12 sec. 2 points: 396 damage over 12 sec. ..."   (Rip; note the stray space)
--   "1 point: 25 damage over 8 secs\n ... 5 points: 87 damage over 16 secs"      (Rupture)
-- Returns total, school, duration for the given points (clamped to the listed range), or nil if the
-- finisher has no per-point DoT (e.g. Eviscerate).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    for pointsText, amount, secs in desc:gmatch("(%d+) points?%s*:%s*(%d+) damage over (%d+%.?%d*) sec") do
        local points = tonumber(pointsText)
        byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
        highest = math.max(highest, points)
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, SCHOOL_MASKS.Physical, entry.duration
end

-- Returns total damage, school mask, duration and (if the description states it) tick interval.
--   "... 10 Nature damage over 15 sec."  Takes the last such clause, so Immolate's
--       "11 Fire damage and then an additional 20 Fire damage over 15 sec" yields the periodic part.
--   "Transfers 15 health from the target to the caster every 3 sec. Lasts 30 sec."  (Siphon Life)
-- comboPoints is only used for finishers. (Rake/Garrote merely award a combo point, so finishers are
-- recognised by "Finishing move", not "combo point".)
local function parseDot(desc, comboPoints)
    if type(desc) ~= "string" or isSecret(desc) then return nil end
    -- Strip English thousands separators only for the English patterns; locales keep their original text.
    local text, count = desc, 1
    while count > 0 do text, count = text:gsub("(%d),(%d%d%d)%f[%D]", "%1%2") end
    if text:find("Finishing move") then return parseFinisher(text, comboPoints or 5) end
    -- Weapon enchants (rogue poisons) describe a proc DoT but aren't cast on the target. Match the enchant
    -- wording only: Lacerate's tooltip also mentions "weapon damage".
    if text:find("[Cc]oats a weapon") then return nil end
    -- Heals over time: Forever's Renew reads "Heals the target of 830 damage over 15 sec".
    if text:find("^Heals") then return nil end

    local total, school, duration
    for amount, words, secs in text:gmatch("(%d+)%s*([%a ]-)%s*damage over (%d+%.?%d*) sec") do
        total, school, duration = tonumber(amount), schoolFromWords(words), tonumber(secs)
    end
    if total and duration > 0 then return total, school, duration end

    -- Black Arrow: "causing 150 Shadow damage and draining 150 mana over 30 sec" (the damage and the mana drain share the time).
    local drained, drainWords, drainSecs = text:match("(%d+)%s*([%a ]-)%s*damage and draining %d+ mana over (%d+%.?%d*) sec")
    if drained and tonumber(drainSecs) > 0 then
        return tonumber(drained), schoolFromWords(drainWords), tonumber(drainSecs)
    end

    local amount, words, every = text:match("(%d+)%s*([%a ]-)%s*damage every (%d+%.?%d*) sec")
    if not amount then
        amount, every = text:match("(%d+) health.-every (%d+%.?%d*) sec")
        words = ""
    end
    -- Saber Slash states the time after the interval: "to bleed for 100 damage every 2 sec for 12 sec".
    local lasts = text:match("[Ll]asts (%d+%.?%d*) sec") or text:match("damage every %d+%.?%d* sec for (%d+%.?%d*) sec")
    if amount and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), schoolFromWords(words), lasts, every
        end
    end
    -- Not English DoT wording: try the other languages (Locale.lua).
    return ns.locale.parseDot(desc, comboPoints or 5)
end

---------------------------------------------------------------------------
-- DoT tracking
---------------------------------------------------------------------------

-- Best known average damage per tick: observed average of non-crit ticks, else learned from earlier casts,
-- else the description. Crits are one-offs, so they never raise the expectation for later ticks. For shaped
-- DoTs (TICK_SHAPES) ticks are stored divided by their factor, so this is the average tick, not the latest.
-- Before its own first tick a DoT keeps the size it was applied with (learnedAtApply): the store is shared by
-- every mob, so another mob's tick (a different debuff set) must not move this one's marker. A DoT applied with
-- nothing learned still picks up a size learned since.
-- dot.boost (Amplify Curse, ns.AMPLIFY) is what the cast's buff adds to a DoT's own size: the learned size and the
-- description hold the unbuffed one, so they are scaled; the observed ticks are the buffed DoT's own and are not.
local function expectedTick(dot)
    if dot.normalTicks > 0 then return dot.tickSum / dot.normalTicks end
    return (dot.learnedAtApply or (dot.tickKey and db.ticks[dot.tickKey]) or (dot.total / dot.totalTicks))
        * (dot.boost or 1)
end

-- Which tick of the DoT (1 = first) lands around `when`.
local function tickNumberAt(dot, when)
    return math.max(1, math.floor((when - dot.appliedAt) / dot.interval + 0.5))
end

-- The factor for tick `number` (1 for evenly ticking DoTs). Shapes are stretched to the DoT's tick count.
local function tickShape(dot, number)
    local shape = dot.shape
    if not shape then return 1 end
    local i = math.ceil(math.min(math.max(number, 1), dot.totalTicks) / dot.totalTicks * #shape)
    return shape[math.max(1, math.min(i, #shape))]
end

-- A waiting DoT doesn't count toward the marker until its first tick lands (see WAIT_MODES).
local function isWaiting(dot)
    if dot.predictionOnly then return false end
    if dot.confirmationPending then
        -- A tick from the old application cannot prove that a refresh landed.
        return not (dot.ticksSeen > 0 and dot.lastTickAt
            and (not dot.replaced or dot.lastTickAt > dot.replaced.expiresAt + TICK_MATCH_WINDOW))
    end
    if dot.ticksSeen > 0 then return false end
    -- An avoid right after the cast that may not have been its own: always wait for the first tick.
    if dot.doubtful or db.waitFirstTick == "always" then return true end
    return db.waitFirstTick == "unsure" and dot.unsure
end

-- Combo points, for finishers. By UNIT_SPELLCAST_SUCCEEDED they're already spent, so they're read when the
-- cast is sent. They were unreadable in combat on the Forever beta, so the addon also counts them itself:
-- builders say "Awards N combo point(s)" in their tooltips; a dodge/parry/miss right after takes them back;
-- a finisher or a target change resets the count. If neither source knows, finishers assume the lowest
-- entry, so the estimate errs low (no false skull) and nothing is learned from that cast.
local COMBO_CAP = 5
local COMBO_CACHE_SECONDS = 3
local comboAtSend, lastComboPoints, lastComboAt = nil, nil, 0
local countedPoints = 0
-- Retain even an unknown SENT recipient: a target appearing later cannot identify that cast's mob.
-- Readable GUIDs survive target changes; the current-target-only alias cannot.
local pendingCast -- { key (possibly nil), castGUID, spellID, sentAt, stoppedAt }
ns._retailPending = {} -- An off-GCD/queued SENT must not replace another cast's snapshot.

local function sameCast(cast, castGUID, spellID)
    if cast.castGUID and castGUID ~= nil and not isSecret(castGUID) then return castGUID == cast.castGUID end
    return not isSecret(spellID) and spellID == cast.spellID
end

function ns._pendingForCast(castGUID, spellID)
    if ns.Retail and not isSecret(castGUID) and type(castGUID) == "string" then
        return ns._retailPending[castGUID]
    end
    if ns.Retail then
        if isSecret(spellID) then return end
        local found = pendingCast and sameCast(pendingCast, castGUID, spellID) and pendingCast or nil
        for _, cast in pairs(ns._retailPending) do
            if cast.spellID == spellID then
                if found and found ~= cast then return end -- Hidden cast GUID cannot choose between queued copies.
                found = cast
            end
        end
        return found
    end
    if pendingCast and sameCast(pendingCast, castGUID, spellID) then return pendingCast end
end

function ns._forgetRecipient(key)
    if pendingCast and pendingCast.key == key then pendingCast.key = nil end
    for _, cast in pairs(ns._retailPending) do
        if cast.key == key then cast.key = nil end
    end
end

local function castRecipient(castGUID, spellID)
    local sent = ns._pendingForCast(castGUID, spellID)
    if sent then
        if sent.key then return sent.key end
        -- A NAMED recipient that stayed unknown must not move to whatever is targeted now
        -- (DOT-1). Only dynamic targeting -- SENT carried no target name at all, the client
        -- picks the victim itself -- lands on the mob it picked by the time of SUCCEEDED.
        if not sent.dynamic then return end
        return ns._selectedEnemyKey()
    end
    if ns.Retail then return end -- No SENT snapshot can prove a delayed event's recipient.
    return ns._selectedEnemyKey()
end

local function outcomeRecipient()
    if pendingCast then
        if pendingCast.key then return pendingCast.key end
        if not pendingCast.dynamic then return end
    end
    return ns._selectedEnemyKey()
end

-- Cast outcomes. UNIT_COMBAT reports a dodge/parry/miss/resist/immune on the target, but not which attack it
-- belongs to. A cast's own result arrives almost at once (same frame in the logs), so the first outcome on the
-- target right after a cast decides: a hit means it landed, an avoid means it didn't. A recast replaced a DoT that
-- is still ticking, so that one is put back instead. Results can also arrive just before the cast event, hence
-- the short look-back.
--
-- Only MISS/DODGE/PARRY/EVADE are shared with auto-attacks: a dual-wielder swings about every 0.7s and misses a
-- quarter of them, so one of those outcomes lands right after most melee casts. Bleeds with no initial damage
-- (Garrote, Rupture, Rip, Lacerate) never get a hit of their own to prove the cast landed (the shield Rake has
-- in "Rake hit, then an auto-attack dodged"), so the wide window dropped a large share of them the moment they
-- landed. Resists and immunities can only belong to the cast (a white swing is never resisted), so those keep
-- the wide window; the auto-attack class only decides close to the cast, where the code's own notes place the
-- cast's own result ("same frame in the logs"). A MISS immediately after a cast still drops the DoT,
-- preferring a rare dropped bleed over a phantom one.
-- Each entry is { window after the cast, look-back before it }.
local AVOIDED_ACTIONS = {
    MISS = { 0.15, 0.15 }, DODGE = { 0.15, 0.15 }, PARRY = { 0.15, 0.15 }, EVADE = { 0.15, 0.15 },
    IMMUNE = { 0.4, 0.25 }, DEFLECT = { 0.4, 0.25 }, RESIST = { 0.4, 0.25 }, REFLECT = { 0.4, 0.25 },
}
local lastBuilder    -- { key, points, at }: builder whose outcome isn't known yet
local lastDotCast    -- { key, name, dot, previous, at, landedAt }: DoT cast whose outcome isn't known yet
local lastOutcome    -- { key, avoided, action, school, at, immune }: most recent outcome on a tracked unit

local function describeReading(ok, value)
    if not ok then return "error" end
    if value == nil then return "nil" end
    if isSecret(value) then return "secret" end
    return tostring(value)
end

-- The client may expose either modern ComboPoints or classic ComboPointN highlights.
local function displayedComboPoints()
    local resource = BIT.modules and BIT.modules.ResourceDing
    if type(resource) == "table" and type(resource.DisplayedComboPoints) == "function" then
        return resource.DisplayedComboPoints()
    end
end

-- Returns the best plain reading (or nil) and a description of what each API returned, for the log.
local function readComboPoints()
    if ns.Retail then
        local points = ns.Retail.ComboPoints()
        if points then return points, "UnitPower=" .. points end
        return nil, "UnitPower=unknown"
    end
    local best, parts = nil, {}
    local function consider(label, ok, points)
        table.insert(parts, label .. "=" .. describeReading(ok, points))
        -- A plain 0 is a reading. Maxing it with a stale UnitPower or with fading
        -- highlights would spend a finisher as if the bar were still full.
        if best == nil and ok and type(points) == "number" and not isSecret(points) then
            best = points
        end
    end
    -- Forever points belong to the selected target. GetComboPoints wins over UnitPower,
    -- which can still show the previous target's points (same order as ResourceDing).
    if GetComboPoints then consider("GetComboPoints", pcall(GetComboPoints, "player", "target")) end
    if UnitPower and Enum and Enum.PowerType and Enum.PowerType.ComboPoints then
        consider("UnitPower", pcall(UnitPower, "player", Enum.PowerType.ComboPoints))
    end
    -- The display is only a fallback for when both APIs are secret. It is read by
    -- appearance, so it must never raise a number the API already gave.
    if best == nil then
        consider("display", true, displayedComboPoints())
    else
        table.insert(parts, "display=not needed")
    end
    return best, table.concat(parts, " ")
end

local function rememberComboPoints()
    local points = readComboPoints()
    if points and points > 0 then lastComboPoints, lastComboAt = points, GetTime() end
    return points
end

local function isFinisherDescription(desc)
    return type(desc) == "string" and not isSecret(desc)
        and (desc:find("Finishing move") ~= nil or ns.locale.isFinisher(desc))
end

-- Readable SENT name, Forever. Same rule as Retail.Recipient: the name must pick one
-- attackable unit among target, softenemy, mouseover and focus. Two keys, or a match
-- whose key can't be read, is unknown. A field on ns: this chunk is at Lua 5.1's
-- 200-local limit, so it cannot gain another local function.
function ns._namedEnemyKey(sentName)
    local matched, hardTarget
    -- targetOverMouseover: the mouseover only counts when nothing else has the name.
    local mouseoverLast = db and db.targetOverMouseover
    for _, unit in ipairs(mouseoverLast and { "target", "softenemy", "focus", "mouseover" }
        or { "target", "softenemy", "mouseover", "focus" }) do
        if unit == "mouseover" and mouseoverLast and matched then return matched end
        local existsOK, exists = pcall(UnitExists, unit)
        if not (unit == "softenemy" and hardTarget) and existsOK and not isSecret(exists) and exists == true then
            local attackOK, canAttack = pcall(UnitCanAttack, "player", unit)
            local nameOK, unitName = pcall(UnitName, unit)
            local deadOK, dead = pcall(UnitIsDeadOrGhost, unit)
            -- A dead unit is never the recipient, and a living hard target beats the soft target (same rule as
            -- Retail.Recipient): a pack of same-named mobs is the normal case with action targeting.
            if attackOK and not isSecret(canAttack) and canAttack == true
                and not (deadOK and not isSecret(dead) and dead == true)
                and nameOK and not isSecret(unitName) and unitName == sentName then
                local key = unitKey(unit)
                if not key or (matched and matched ~= key) then return nil end
                matched = key
                if unit == "target" then hardTarget = true end
            end
        end
    end
    return matched
end

local function onCastSent(spellID, castGUID, targetName)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    -- DOT-1: remember who the cast is aimed at while the target is still it.
    -- SUCCEEDED only names the spell, so onPlayerCast uses this instead of
    -- the (maybe tabbed-away) current target. Never cleared by target change.
    -- Only an attackable hard target takes precedence over softenemy; unitKey only uses
    -- a soft target whose own GUID or matching nameplate's GUID can be read safely.
    local recipient, dynamicTargeting
    if ns.Retail then
        recipient = ns.Retail.Recipient(targetName)
        if not recipient then
            -- The CAST line later says only "no target"; this says why the recipient stayed unknown.
            local shown = targetName
            if isSecret(targetName) then shown = "<secret>"
            elseif type(shown) ~= "string" then shown = tostring(shown) end
            local function state(unit)
                local existsOK, exists = pcall(UnitExists, unit)
                if not existsOK or isSecret(exists) or exists ~= true then return "none" end
                local deadOK, dead = pcall(UnitIsDeadOrGhost, unit)
                return (deadOK and not isSecret(dead) and dead == true) and "dead" or "alive"
            end
            trace("SENT id " .. tostring(spellID) .. " target=" .. shown .. ": recipient unknown (hard=" .. state("target")
                .. " soft=" .. state("softenemy") .. " mouseover=" .. state("mouseover") .. " focus=" .. state("focus") .. ")")
        end
    else
        -- Forever's dynamic targeting: the client picks the victim itself, so SENT names no
        -- target at all. Such a cast may land on the current target at SUCCEEDED. A readable
        -- name that is not exactly one known enemy stays unknown and must not move there (DOT-1).
        dynamicTargeting = targetName == nil or (not isSecret(targetName) and targetName == "")
        -- Blizzard's own Mouseover Cast puts the spell on the mob under the mouse, same-named target or not.
        local hovered = BIT.Plate and BIT.Plate.MouseoverCastUnit and BIT.Plate.MouseoverCastUnit(targetName)
        recipient = hovered and unitKey(hovered) or nil
        if recipient then
            trace("SENT id " .. tostring(spellID) .. ": native Mouseover Cast, the mob under the mouse takes it")
        elseif not dynamicTargeting and not isSecret(targetName) and type(targetName) == "string" then
            recipient = ns._namedEnemyKey(targetName)
        else
            recipient = ns._selectedEnemyKey()
        end
        local shown = targetName
        if isSecret(targetName) then shown = "<secret>"
        elseif shown == nil then shown = "nil"
        elseif type(shown) ~= "string" then shown = "<" .. type(shown) .. ">" end
        trace("SENT id " .. tostring(spellID) .. " target=" .. tostring(shown) .. " dynamic=" .. tostring(dynamicTargeting)
            .. " key=" .. tostring(recipient or "none"))
    end
    pendingCast = { key = recipient, dynamic = dynamicTargeting, spellID = spellID,
        castGUID = not isSecret(castGUID) and castGUID or nil, sentAt = GetTime() }
    if ns.Retail and type(pendingCast.castGUID) == "string" then ns._retailPending[pendingCast.castGUID] = pendingCast end
    comboAtSend = nil
    local ok, name, desc
    if ns.Retail then
        lastComboPoints, lastComboAt = nil, 0
        ok, name, desc = pcall(ns.Retail.SpellDescription, spellID, spellNameAndDescription)
    else ok, name, desc = pcall(spellNameAndDescription, spellID) end
    if ns.Retail and ok and not isSecret(name) and not isSecret(desc) then
        pendingCast.name, pendingCast.desc = name, desc -- Capture before a finisher spends its points.
    end
    local finisher = isFinisherDescription(desc) or (ns.Retail and ns.Retail.IsFinisher(spellID))
    if not ok or not finisher then return end
    local points, readings = readComboPoints()
    comboAtSend = points
    if ns.Retail then pendingCast.comboPoints = points end
    trace("COMBO at send: " .. readings .. ", counted=" .. countedPoints)
end

-- An avoid that arrived just before the cast event (see AVOIDED_ACTIONS' look-back), or nil.
local function avoidJustBefore(key, includeImmune)
    if not lastOutcome or lastOutcome.key ~= key then return end
    local outcome = lastOutcome.avoided and lastOutcome or (includeImmune and lastOutcome.immune)
    if outcome then
        local windows = AVOIDED_ACTIONS[outcome.action]
        if windows and GetTime() - outcome.at <= windows[2] then
            return outcome.action, outcome.school
        end
    end
end

-- A builder was cast: count its points unless it was already avoided, else wait for its outcome.
local function onBuilderCast(points, key)
    local avoided = avoidJustBefore(key)
    if avoided then
        trace("COMBO builder " .. avoided .. " (before cast event), counted=" .. countedPoints)
        return
    end
    countedPoints = math.min(COMBO_CAP, countedPoints + points)
    lastBuilder = { key = key, points = points, at = GetTime() }
end

-- A DoT cast whose result was avoided isn't on the target: drop it. (Waiting for a first tick to prove it
-- instead doesn't work for bleeds: melee white hits look just like ticks.) A recast replaced a DoT that is
-- still ticking, so that one is put back.
-- Spell DoTs are different: the pet and other players' melee miss all the time, and their ticks are told apart
-- from melee by school. So an avoid that can't be the spell's is ignored, and one that might not be (not
-- reported in the spell's school) makes a new DoT wait for its first tick instead of dropping it.
-- Returns false when the avoid was ignored, so the cast's own outcome may still come.
local function removeAvoidedDot(cast, action, school)
    local dot = cast.dot
    local dots = dotsByTarget[cast.key]
    if not dots or dots[cast.name] ~= dot then return true end
    local spellSchool = type(school) == "number" and not isSecret(school) and school == dot.school
    if dot.school ~= SCHOOL_MASKS.Physical and not spellSchool then
        -- Spells can't be dodged, parried or deflected: next to a spell DoT, these were someone's melee.
        if action == "DODGE" or action == "PARRY" or action == "DEFLECT" then
            trace(string.format("AVOID %s (school %s) right after %s: not the spell, ignored", action,
                tostring(school), cast.name))
            return false
        end
        -- A resist, reflect or immune is never a melee swing. One that names no school at all, right on the cast,
        -- has nothing pointing at anyone else: it is the cast's own, and falls through to the drop below.
        local noSchool = isSecret(school) or type(school) ~= "number" or school == 0
        local ownResist = noSchool and (action == "RESIST" or action == "REFLECT" or action == "IMMUNE")
            and math.abs(GetTime() - cast.at) <= AVOIDED_ACTIONS.MISS[1]
        if not cast.previous and not ownResist then
            dot.doubtful = true
            trace(string.format("AVOID %s (school %s) right after %s: may be someone else's, waiting for its first tick",
                action, tostring(school), cast.name))
            return true
        end
    end
    if cast.previous then
        dots[cast.name] = cast.previous
        trace("AVOID " .. action .. " right after " .. cast.name .. " recast; keeping the earlier one")
    else
        dots[cast.name] = nil
        trace("AVOID " .. action .. " right after " .. cast.name .. "; dropped")
    end
    -- A cat's or rogue's white swing missing in that instant looks the same as the finisher missing. A finisher
    -- that misses keeps its combo points, one that lands spends them, so a finisher whose points were read at
    -- send is judged again once they have settled (ns._resolveFinisherCheck). From Does It Die v0.9.4 (MIT).
    if cast.comboRead then
        ns._finisherCheck = { cast = cast, dot = dot, replaced = dots[cast.name], action = action, at = GetTime() + 0.5 }
    end
    return true
end

local function onTargetAvoided(action, key, school)
    local now = GetTime()
    local window = (AVOIDED_ACTIONS[action] or AVOIDED_ACTIONS.RESIST)[1]
    if key == outcomeRecipient() then
        lastOutcome = { key = key, avoided = true, action = action, school = school, at = now }
    end
    if lastBuilder and lastBuilder.key == key then
        if now - lastBuilder.at <= window then
            countedPoints = math.max(0, countedPoints - lastBuilder.points)
            trace("COMBO builder " .. action .. ", counted=" .. countedPoints)
        end
        lastBuilder = nil
    end
    if lastDotCast and lastDotCast.key == key then
        if now - lastDotCast.at > window then
            lastDotCast = nil
        elseif not lastDotCast.landedAt or action == "IMMUNE" then
            if removeAvoidedDot(lastDotCast, action, school) then lastDotCast = nil end
        end
    end
end

-- A matching direct hit leaves the DoT pending for a possible IMMUNE on its periodic part.
local function onTargetHit(key, school)
    local now = GetTime()
    if key == outcomeRecipient() then
        local prior = lastOutcome
        lastOutcome = { key = key, avoided = false, at = now }
        local immune = prior and (prior.action == "IMMUNE" and prior or prior.immune)
        if immune and immune.key == key and now - immune.at <= AVOIDED_ACTIONS.IMMUNE[2] then
            lastOutcome.immune = immune
        end
    end
    if lastBuilder and lastBuilder.key == key then lastBuilder = nil end
    if lastDotCast and lastDotCast.key == key and not lastDotCast.landedAt
        and (lastDotCast.dot.school == SCHOOL_MASKS.Physical
            or (not isSecret(school) and lastDotCast.dot.school == school)) then
        lastDotCast.landedAt = now
    end
end

local function resetComboCount()
    countedPoints, lastBuilder = 0, nil
    -- the cache belongs to the old target too: without this a finisher on a
    -- fresh target reuses points built on the dead one (DOT-2)
    lastComboPoints, lastComboAt = nil, 0
end

local function forgetPendingOutcomes()
    lastBuilder, lastDotCast, lastOutcome = nil, nil, nil
end

-- Returns points and where they came from, or nil and "unknown".
local function comboPointsForCast()
    local points, source = comboAtSend, "read"
    if not (points and points > 0) then
        if lastComboPoints and GetTime() - lastComboAt <= COMBO_CACHE_SECONDS then
            points, source = lastComboPoints, "cached"
        elseif countedPoints > 0 then
            points, source = countedPoints, "counted"
        else
            points, source = nil, "unknown"
        end
    end
    comboAtSend = nil
    resetComboCount()
    return points, source
end

-- A DoT as it stands the moment it's applied, before any tick.
local function newDot(spellID, tickKey, name, total, school, duration, statedInterval, now)
    local interval = statedInterval or KNOWN_TICK_INTERVALS[name] or DEFAULT_TICK_INTERVAL
    local dot = {
        spellID = spellID,
        familyID = ns.RogueEffects and ns.RogueEffects.Family(spellID),
        tickKey = tickKey,
        -- The size learned on earlier casts, as it stood when this DoT was applied. Same-slot collisions are
        -- judged against it (referenceTickSize): the store may have just been written by the disputed tick.
        learnedAtApply = tickKey and db.ticks[tickKey] or nil,
        school = SCHOOL_BY_NAME[name] or school,
        total = total,
        duration = duration,
        interval = interval,
        totalTicks = math.max(1, math.floor(duration / interval + 0.5)),
        shape = TICK_SHAPES[name],
        travel = PROJECTILE_DOTS[name] and PROJECTILE_DOTS.travel or nil,
        appliedAt = now,
        expiresAt = now + duration,
        nextTickAt = now + interval,
        tickSum = 0,        -- non-crit ticks only
        normalTicks = 0,
        ticksSeen = 0,      -- including crits
        missed = 0,
    }
    if ns.Retail then ns.Retail.Prepare(dot) end
    return dot
end

ns.TraceRogueAura = trace

function ns.ParseRogueAura(spellID, desc, config)
    if isSecret(desc) or type(desc) ~= "string" then return end
    -- Weapon-coating descriptions are read only after an identified damaging aura, never on coating casts.
    desc = desc:gsub("[Cc]oats", ""):gsub("Überzieht", "")
    if ns.Retail then return ns.Retail.Parse(spellID, desc, nil, parseDot, config) end
    if isFinisherDescription(desc) then return end -- Spent CP cannot be reconstructed from a new aura's rows.
    return parseDot(desc)
end

function ns.RogueAuraPrevious(unit, familyID)
    local key = unitKey(unit)
    for name, dot in pairs(key and dotsByTarget[key] or {}) do
        if dot.familyID == familyID or dot.spellID == familyID then return dot, name end
    end
end

function ns.ObserveRogueAura(unit, aura, signal)
    local key = unitKey(unit)
    if not key then return end
    local previous, previousName = ns.RogueAuraPrevious(unit, aura.familyID)
    if previous and previous.auraInstanceID and previous.auraInstanceID ~= aura.auraInstanceID then
        dotsByTarget[key][previousName], previous = nil, nil
    end
    local now = GetTime()
    local expiresAt = aura.expirationTime
    if not expiresAt then
        -- A scan cannot date an existing hidden timer; only an identified application/update can.
        if previous and (not signal or (signal == "updated" and not aura.refreshOnUpdate)) then
            expiresAt = previous.expiresAt
        elseif signal then expiresAt = now + aura.clockDuration
        else return end
    end
    if expiresAt <= now then return end
    if aura.keepTicks and previous then
        previous.auraObserved, previous.auraInstanceID = true, aura.auraInstanceID
        previous.expiresAt = expiresAt
        return true -- Keep Forever's learned/AP-adjusted bleed ticks instead of replacing them with base damage.
    end
    if previous and previous.auraInstanceID == aura.auraInstanceID
        and previous.duration == aura.duration and previous.total == aura.total
        and math.abs(previous.expiresAt - expiresAt) < 0.05 then return true end
    dotsByTarget[key] = dotsByTarget[key] or {}
    if previousName then dotsByTarget[key][previousName] = nil end
    local dot = newDot(aura.spellID, nil, aura.name, aura.total, aura.school, aura.duration, aura.interval, now)
    dot.predictionOnly, dot.auraObserved, dot.unsure = true, true, true
    dot.estimatedClock = not aura.expirationTime
    dot.segmentOrder = previous and previous.segmentOrder
    dot.poison, dot.familyID, dot.noRefreshCue = aura.poison, aura.familyID, not aura.manual
    dot.stacks = aura.stacks
    dot.auraInstanceID, dot.expiresAt = aura.auraInstanceID, expiresAt
    dotsByTarget[key][aura.name] = dot
    trace(string.format("%s %s %s on %s: %.1f dmg, %.1fs remaining (%s)", aura.poison and "POISON" or "BLEED",
        previous and "REFRESH" or "APPLY", aura.name, unit, aura.total,
        expiresAt - now, aura.expirationTime and "readable expiration" or "own clock"))
    return true
end

function ns.RemoveRogueAuras(unit, seen, removed, resetReason)
    local key = unitKey(unit)
    local dots = key and dotsByTarget[key]
    local now = GetTime()
    for name, dot in pairs(dots or {}) do
        -- Fresh casts/procs can precede the combat flag; explicit aura removals need no grace period.
        local absent = seen and not seen[dot.familyID] and (dot.auraObserved or (resetReason and dot.familyID))
            and (not resetReason or now - dot.appliedAt > TICK_MATCH_WINDOW)
        if absent or (removed and dot.auraInstanceID and removed[dot.auraInstanceID]) then
            dots[name] = nil
            trace((dot.poison and "POISON" or "BLEED") .. " REMOVE " .. name .. " on " .. unit
                .. (resetReason and (" (idle NPC; " .. resetReason .. ")") or ""))
        end
    end
end

-- For /dotinfo check (ParseCheck.lua): what the addon reads from one spell's description.
function ns.ReadSpellText(spellID, desc)
    local name = spellID and select(2, pcall(spellNameAndDescription, spellID))
    if IGNORED_SPELLS[name] then return nil, true end
    if ns.Retail then return ns.Retail.Parse(spellID, desc, nil, parseDot) end
    return parseDot(desc, 1)
end

-- Amplify Curse (ns.AMPLIFY). Every successful cast of the player comes here first: the Amplify Curse cast leaves a
-- charge, and the next cast of a curse in ns.AMPLIFY_USES takes it, whatever becomes of that cast (a resisted curse
-- spends it too). Returns the factor that cast's DoT is raised by, or nil. `name` may be missing (the spell's name did
-- not load): the Amplify Curse cast is found by its id as well. Fields on ns: this file is at Lua's limit of 200
-- local variables.
function ns._amplifyCast(spellID, name)
    if ns.Retail then return nil end -- no such buff there, and Retail reads its auras
    local amplify = ns.AMPLIFY
    local use = type(name) == "string" and not isSecret(name) and ns.AMPLIFY_USES[name] or nil
    if spellID == amplify.spellID or use == "start" then
        ns._amplifyAt = GetTime()
        trace(string.format("AMPLIFY CURSE cast: its charge goes to the next curse within %ds", amplify.seconds))
        return nil
    end
    if not use or not ns._amplifyAt then return nil end
    local age = GetTime() - ns._amplifyAt
    ns._amplifyAt = nil
    if age > amplify.seconds then
        trace(string.format("AMPLIFY CURSE had run out %.1fs before %s", age - amplify.seconds, name))
        return nil
    end
    if use == "boost" then return amplify.boost end
    trace(string.format("AMPLIFY CURSE charge went into %s", name))
end

-- The sizes the ticks of a DoT may have, the expected one first. Only a DoT the cast events flagged as buffed has
-- two: the buffed one, or its own when the buff did not reach it. An unflagged DoT keeps its own size alone: ticks
-- 1.5 times the usual are not allowed to turn it into a buffed one, since other players' DoTs and the next DoT's
-- ticks pass for such hits now and then.
function ns._boostChoices(dot)
    if dot.boost and dot.boost ~= 1 then return { dot.boost, 1 } end
    return { 1 }
end

-- Returns the target key the DoT was applied to, or nil if the cast wasn't a tracked DoT.
local function onPlayerCast(spellID, castGUID)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    local key = castRecipient(castGUID, spellID)
    local sent = ns._pendingForCast(castGUID, spellID)
    if sent then
        if pendingCast == sent then pendingCast = nil end
        if ns.Retail and type(sent.castGUID) == "string" then ns._retailPending[sent.castGUID] = nil end
    end
    local ok, name, desc
    if ns.Retail then ok, name, desc = pcall(ns.Retail.SpellDescription, spellID, spellNameAndDescription) end
    if not ns.Retail then ok, name, desc = pcall(spellNameAndDescription, spellID) end
    if ns.Retail and sent and sent.name and sent.desc then ok, name, desc = true, sent.name, sent.desc end
    -- Amplify Curse: the factor this cast's DoT is raised by, or nil. Before the name check: its own cast is found by id.
    local amplified = ns._amplifyCast(spellID, ok and name or nil)
    if not ok or not name or isSecret(name) then return end
    if ns.ProcDots then ns.ProcDots.NoteCast(key, spellID, name, desc) end
    if type(desc) == "string" and not isSecret(desc) then
        local awarded = tonumber(desc:match("Awards (%d+) combo point")) or ns.locale.comboPointsAwarded(desc)
        if awarded and not ns.Retail then onBuilderCast(awarded, key) end
    end
    if IGNORED_SPELLS[name] then
        -- DOT-7: this drop used to be silent (no marker, no log line), which made an ignore or a name
        -- collision look exactly like "the addon does not handle this spell". Record it like every other
        -- decision, so a cast that shows nothing always has its reason in the log.
        trace(string.format("IGNORED %s (id %d): on the ignore list", name, spellID))
        return
    end
    local isFinisher = isFinisherDescription(desc) or (ns.Retail and ns.Retail.IsFinisher(spellID))
    local comboPoints, comboSource
    if isFinisher then
        comboPoints, comboSource = comboPointsForCast()
        if ns.Retail then
            comboPoints = sent and sent.comboPoints or nil
            comboSource = comboPoints and "read" or "unknown"
        end
    end
    -- Death Mark stores damage instead of dealing it over time (DeathMark.lua).
    if ns.DeathMark then
        local handled, markedKey = ns.DeathMark.OnCast(key, spellID, name, desc, comboPoints, comboSource)
        if handled then return markedKey end
    end
    local total, school, duration, statedInterval
    if ns.Retail then total, school, duration, statedInterval = ns.Retail.Parse(spellID, desc, comboPoints, parseDot)
    else total, school, duration, statedInterval = parseDot(desc, comboPoints or 1) end
    if not total then
        if not isSecret(desc) and ns.locale.shouldLogUnread(spellID, desc) then
            trace(string.format("NOT READ %s (id %d): %s", name, spellID, desc))
        end
        return
    end
    -- A finisher's tick size depends on the points spent, so learned sizes are kept per point count.
    local tickKey = spellID
    if isFinisher then tickKey = comboPoints and (spellID .. "x" .. comboPoints) or nil end

    -- A trap only arms: the DoT starts when it springs (ProcDots.lua).
    if ns.ProcDots and ns.TRAP_DOTS[name] and ns.ProcDots.ArmTrap(spellID, name, desc, total, school, duration, statedInterval) then
        return
    end

    -- Wyvern Sting: the DoT starts when the sleep ends (ProcDots.lua).
    if ns.ProcDots and ns.DELAYED_DOTS[name] then
        ns.ProcDots.ArmDelayed(key, spellID, name, total, school, duration, statedInterval or KNOWN_TICK_INTERVALS[name] or 3)
        return
    end

    -- DOT-1: SUCCEEDED names only the spell, so the cast belongs to the mob
    -- remembered at SENT time, not to whatever is targeted now (a tab
    -- mid-cast must not move the DoT). Fall back to the current target only
    -- when no matching SENT was seen; an unreadable SENT recipient stays unknown.
    if not key then
        -- DOT-5b: SUCCEEDED with no readable target silently vanished (0 log
        -- lines, breaking "always recorded"). Log it and stay silent in chat.
        trace(string.format("CAST %s (id %d): no target, not tracked", name, spellID))
        if ns.Learn then ns.Learn.Untracked(spellID) end -- the damage meter still counts what this cast deals
        return
    end

    local now = GetTime()
    dotsByTarget[key] = dotsByTarget[key] or {}
    local previous = dotsByTarget[key][name]
    if not ns.Retail and previous and previous.confirmationPending and isWaiting(previous) then
        previous = previous.replaced
    end
    if not ns.Retail and ns.CONFIRM_PROJECTILE_DOTS[name]
        and previous and now > previous.expiresAt + TICK_MATCH_WINDOW then previous = nil end
    local dot = newDot(spellID, tickKey, name, total, school, duration, statedInterval, now)
    dot.boost = amplified
    dot.confirmationPending = not ns.Retail and ns.CONFIRM_PROJECTILE_DOTS[name] or nil
    if ns.Retail then ns.Retail.ApplyRefresh(dot, previous, now) end
    -- A recast may keep the old DoT's tick timer: remember its rhythm and tick size (ns.discoverRhythm), unbuffed:
    -- the old DoT may have had Amplify Curse's buff and this one may not, or the other way round.
    if not ns.Retail and previous and previous.lastTickAt and previous.interval == dot.interval then
        dot.oldRhythmAt = previous.lastTickAt
        dot.oldTickSize = previous.normalTicks > 0 and previous.tickSum / previous.normalTicks / (previous.boost or 1) or nil
    end
    dot.segmentOrder = previous and previous.segmentOrder
    if not ns.Retail then
        -- The mob's debuffs are looked at once the cast's own debuff has had time to show (ns._verifyAuras).
        if previous then previous.replaced = nil end -- one step back is enough; never a chain of old casts
        dot.replaced = previous
        dot.verifyAt = now + ns._auraCheck.delay + (dot.travel or 0)
    end
    dotsByTarget[key][name] = dot
    lastDotCast = { key = key, name = name, dot = dot, previous = previous, at = now,
        comboRead = not ns.Retail and isFinisher and comboSource == "read" and comboPoints or nil }
    -- The damage meter teaches this DoT's real tick size after the fight (MeterLearning.lua).
    if ns.Learn and not ns.Retail then ns.Learn.Cast(dot, ns.Learn.Upfront(spellID, isFinisher), name) end
    local learned = not ns.Retail and tickKey and db.ticks[tickKey]
    -- The starting estimate is shaky without a learned tick size (description numbers leave out spell power
    -- and attack power) or, for finishers, without knowing the combo points.
    dot.unsure = not learned
    trace(string.format("CAST %s (id %d)%s: %d dmg over %ss, school %d, tick every %ss, per-tick %s%s%s", name, spellID,
        isFinisher and string.format(" %s combo points (%s)", comboPoints or "?", comboSource) or "",
        total, duration, dot.school, dot.interval, learned and ("learned " .. learned) or "from description",
        amplified and string.format(", amplified x%.2f -> %.1f", amplified, expectedTick(dot)) or "",
        isWaiting(dot) and ", waiting for first tick" or ""))
    local avoided, avoidedSchool
    if not ns.Retail then avoided, avoidedSchool = avoidJustBefore(key, true) end
    if avoided and removeAvoidedDot(lastDotCast, avoided, avoidedSchool) then
        lastDotCast = nil
        return nil
    end
    return key, isWaiting(dot)
end

-- "Estimate during casting": a DoT with a cast time shows from UNIT_SPELLCAST_START, with the estimate its
-- cast would make. It's kept out of dotsByTarget, so ticks never match it and housekeeping leaves it alone,
-- and it stands in for a DoT of the same name that the cast would refresh (replaces, never adds). On success
-- onPlayerCast takes over exactly as without it. A failed or interrupted cast, or a target change, just drops
-- it, so a DoT it was about to refresh keeps ticking as if nothing happened. STOP ends every cast, successful
-- or not, and may come just before SUCCEEDED, so a stopped cast is only dropped if no success follows shortly.
local CAST_STOP_GRACE = 0.5
local CAST_MAX_SECONDS = 15 -- a lost end event never leaves an estimate behind
local castInProgress -- { key, name, dot, castGUID, spellID, startedAt, stoppedAt }

local function dropCastInProgress(reason)
    if not castInProgress then return end
    trace("CASTING " .. castInProgress.name .. " " .. reason .. "; estimate removed")
    castInProgress = nil
end

-- UNIT_SPELLCAST_START (player). Returns the target key when a DoT now shows for the cast.
local function onCastStart(castGUID, spellID)
    castInProgress = nil
    if not db.estimateDuringCast or isSecret(spellID) then return end
    local ok, name, desc
    if ns.Retail then ok, name, desc = pcall(ns.Retail.SpellDescription, spellID, spellNameAndDescription) end
    if not ns.Retail then ok, name, desc = pcall(spellNameAndDescription, spellID) end
    local sent = ns._pendingForCast(castGUID, spellID)
    if ns.Retail and sent and sent.name and sent.desc then
        ok, name, desc = true, sent.name, sent.desc
    end
    if not ok or not name or isSecret(name) or IGNORED_SPELLS[name] or isFinisherDescription(desc)
        or (ns.Retail and ns.Retail.IsFinisher(spellID)) then return end
    local total, school, duration, statedInterval
    if ns.Retail then total, school, duration, statedInterval = ns.Retail.Parse(spellID, desc, nil, parseDot)
    else total, school, duration, statedInterval = parseDot(desc, 1) end
    if not total then return end
    local key = castRecipient(castGUID, spellID)
    if not key then return end
    local now = GetTime()
    local dot = newDot(spellID, spellID, name, total, school, duration, statedInterval, now)
    if ns.Retail then ns.Retail.ApplyRefresh(dot, dotsByTarget[key] and dotsByTarget[key][name], now) end
    local learned = not ns.Retail and db.ticks[spellID]
    dot.unsure = not learned
    dot.provisional = true
    castInProgress = { key = key, name = name, dot = dot, spellID = spellID, startedAt = now,
        castGUID = not isSecret(castGUID) and castGUID or nil }
    trace(string.format("CASTING %s (id %d): %d dmg over %ss, per-tick %s%s", name, spellID, total, duration,
        learned and ("learned " .. learned) or "from description", isWaiting(dot) and ", waiting for first tick" or ""))
    return key
end

-- UNIT_SPELLCAST_SUCCEEDED (player), just before onPlayerCast: the cast's own DoT replaces the estimate.
local function onCastSucceeded(castGUID, spellID)
    if castInProgress and sameCast(castInProgress, castGUID, spellID) then castInProgress = nil end
end

-- UNIT_SPELLCAST_STOP / FAILED / INTERRUPTED (player). Returns true when the estimate was removed.
local function onCastEnded(event, castGUID, spellID)
    local sent = ns._pendingForCast(castGUID, spellID)
    if sent then
        if event == "UNIT_SPELLCAST_STOP" then
            sent.stoppedAt = sent.stoppedAt or GetTime()
        else
            if pendingCast == sent then pendingCast, comboAtSend = nil, nil end
            if ns.Retail and type(sent.castGUID) == "string" then ns._retailPending[sent.castGUID] = nil end
        end
    end
    if not castInProgress or not sameCast(castInProgress, castGUID, spellID) then return end
    if event == "UNIT_SPELLCAST_STOP" then
        castInProgress.stoppedAt = castInProgress.stoppedAt or GetTime()
        return
    end
    dropCastInProgress(event == "UNIT_SPELLCAST_INTERRUPTED" and "interrupted" or "failed")
    return true
end

-- Seconds between now and the nearest expected tick time, and that tick's index. Anchored on the first tick
-- once seen (ticks keep its rhythm; anchoring on the latest tick would let jitter add up), else on the cast.
-- Using the nearest multiple of the interval means one missed tick doesn't lose the DoT.
local function distanceToExpectedTick(dot, now)
    local anchor = dot.firstTickAt or dot.appliedAt
    if not dot.firstTickAt and dot.travel then
        -- Still in flight: the DoT started anywhere up to `travel` seconds after the cast.
        local late = now - (anchor + dot.interval)
        if late > 0 then anchor = anchor + math.min(late, dot.travel) end
    end
    local k = math.max(1, math.floor((now - anchor) / dot.interval + 0.5))
    return math.abs(now - (anchor + k * dot.interval)), k
end

local function plausibleTickAmount(dot, amount, isCrit, number)
    local known, tolerance
    if dot.normalTicks > 0 then
        known, tolerance = dot.tickSum / dot.normalTicks, TICK_AMOUNT_TOLERANCE
    else
        known, tolerance = dot.tickKey and db.ticks[dot.tickKey], FIRST_TICK_AMOUNT_TOLERANCE
        known = known and known * (dot.boost or 1) -- the learned size is the unbuffed one
    end
    if not known then
        -- DOT-3: a white hit looks like a Physical tick. Without a learned
        -- size anything passed as tick 1 and anchored the rhythm, so real
        -- ticks were then dropped. For Physical dots fall back to the
        -- description's per-tick share instead of accepting blindly; other
        -- schools keep the old behaviour (no white-hit collision there).
        -- A DoT lit by a crit (Ignite, Deep Wounds) has no learned size either, and the crit that lights the next
        -- one must not pass for its tick.
        if dot.school == SCHOOL_MASKS.Physical or dot.procDot then
            known, tolerance = dot.total / dot.totalTicks * (dot.boost or 1), FIRST_TICK_AMOUNT_TOLERANCE
        else
            return true
        end
    end
    known = known * tickShape(dot, number)
    if isCrit then
        return amount >= known * CRIT_MIN_RATIO - 1 and amount <= known * CRIT_MAX_RATIO + 1
    end
    return math.abs(amount - known) <= math.max(1, known * tolerance)
end

-- Tick size to judge a same-slot collision by: the average of the DoT's earlier ticks, or with fewer than two
-- ticks the size learned on earlier casts (F2), else the description's per-tick share. Learned first (F2): the
-- description's share is what a collision corrupts toward, so judging against it lets a white hit swap out a
-- real tick. The learned size is the one from BEFORE this DoT (newDot's snapshot): saveLearnedTick runs the
-- moment a hit is matched, so a fresh lookup would return the disputed tick's own size, block every swap, and
-- keep a white hit that landed in the tick slot.
local function referenceTickSize(dot)
    if dot.normalTicks > 1 then
        return (dot.tickSum - dot.lastTickAmount / dot.lastTickShape) / (dot.normalTicks - 1)
    end
    return (dot.learnedAtApply or (dot.total / dot.totalTicks)) * (dot.boost or 1)
end

local function saveLearnedTick(dot)
    -- The learned size is the spell's own. A buffed DoT's ticks are not (Amplify Curse), and dividing them by a
    -- percentage that may be off would leave the next unbuffed cast with a wrong size, so a buffed DoT writes nothing.
    if dot.boost and dot.boost ~= 1 then return end
    if dot.tickKey and dot.normalTicks > 0 then
        db.ticks[dot.tickKey] = math.floor(dot.tickSum / dot.normalTicks * 10 + 0.5) / 10
        if ns.Learn then ns.Learn.Readable(dot.tickKey) end -- the meter's total then holds ticks the tally didn't count
    end
end

-- Moves a DoT's tick bookkeeping to the tick in slot `index` that landed at `now`.
local function anchorTick(dot, index, now)
    dot.missed = 0
    if dot.firstTickAt then
        dot.lastTickIndex = index
    else
        dot.firstTickAt, dot.lastTickIndex = now, 0
        -- A projectile DoT started when it landed: count its ticks from there.
        if dot.travel then dot.appliedAt = now - index * dot.interval end
    end
    dot.lastTickAt = now
    dot.nextTickAt = now + dot.interval
    -- Re-anchor expiry on the observed tick: ticks arrive slightly after their nominal time, and an
    -- expiry based on the cast event would otherwise cut off the final tick.
    local tickIndex = math.max(1, math.floor((now - dot.appliedAt) / dot.interval + 0.5))
    dot.expiresAt = now + (dot.totalTicks - tickIndex) * dot.interval
    return tickIndex
end

-- Two same-school hits in one tick slot (e.g. Shadow Bolt landing with a Corruption tick, log 123506.4): the
-- first one was taken as the tick. If this one is closer to the expected size, it was the real tick.
local SAME_SLOT_SECONDS = 0.2
local function trySwapSameSlot(dot, name, amount, isCrit, now)
    if isCrit or amount <= 0 or dot.lastTickCrit or not dot.lastTickAt or now - dot.lastTickAt > SAME_SLOT_SECONDS then
        return false
    end
    local factor = dot.lastTickShape
    local reference = referenceTickSize(dot) * factor
    if math.abs(amount - reference) >= math.abs(dot.lastTickAmount - reference) then return false end
    trace(string.format("SWAP %s tick: %d was another hit, %d is the tick", name, dot.lastTickAmount, amount))
    dot.tickSum = dot.tickSum + (amount - dot.lastTickAmount) / factor
    dot.lastTickAmount = amount
    saveLearnedTick(dot)
    return true
end

-- A learned size that's wrong rejects every real tick (log: Corruption learned 29 from Shadow Bolts, real ticks
-- 10-11, every cast dropped). Hits rejected only on size, but landing on the DoT's rhythm in two consecutive
-- slots and agreeing with each other, are the real ticks: relearn from them.
-- F3: two foreign hits (e.g. Shadow Bolts next to Corruption) also agree with each other, so without a guard
-- they relearn a correct size to theirs (learned 100 -> 500, +233% false skull) and poison db.ticks. Only
-- relearn toward the description's share: a real size is near it (spell power moves it a little), a foreign
-- hit is several times off. A poisoned learned value heals back the same way (29 -> 10 near a share of 10).
local RELEARN_MAX_DESC_RATIO = 3
local function tryRelearn(dot, name, amount, isCrit, index, distance, now)
    local window = dot.firstTickAt and TICK_MATCH_WINDOW_ANCHORED or TICK_MATCH_WINDOW
    local freshSlot = not dot.firstTickAt or index > dot.lastTickIndex
    if isCrit or amount <= 0 or not freshSlot or distance > window then return false end
    local previous = dot.offBeatCandidate
    local factor = tickShape(dot, tickNumberAt(dot, now))
    local average = amount / factor
    dot.offBeatCandidate = { index = index, amount = amount, average = average, at = now }
    if not previous or index ~= previous.index + 1
        or math.abs(average - previous.average) > math.max(1, previous.average * TICK_AMOUNT_TOLERANCE) then
        return false
    end
    local newAverage = (previous.average + average) / 2
    -- F4: two partial-resist ticks agree with each other (60 vs 60) but sit well
    -- below the real size; relearning down poisons db.ticks and then rejects the
    -- real ticks. So relearn only toward something already trusted: the learned
    -- size, or the description's share (which also heals a poisoned learned value
    -- back, e.g. 29 -> 10 near a share of 10).
    local function near(size)
        return size and size > 0
            and math.abs(newAverage - size) <= math.max(1, size * FIRST_TICK_AMOUNT_TOLERANCE)
    end
    local learnedSize = dot.tickKey and db.ticks[dot.tickKey]
    local descShare = dot.total / dot.totalTicks
    -- Trusted sizes: the DoT's own and, for a DoT flagged as buffed by Amplify Curse, the buffed one (see
    -- ns._boostChoices, the expected one first). Ticks that fit the DoT's own size say the buff did not reach it.
    local boost
    for _, choice in ipairs(ns._boostChoices(dot)) do
        if near(learnedSize and learnedSize * choice) or near(descShare * choice) then
            boost = choice
            break
        end
    end
    if not boost then return false end
    trace(string.format("RELEARN %s: ticks of %d and %d on its rhythm didn't fit %.1f/tick", name,
        previous.amount, amount, expectedTick(dot)))
    if boost ~= (dot.boost or 1) then
        trace(string.format("AMPLIFY %s: its ticks say the buff did not reach it", name))
        dot.boost = nil -- before saveLearnedTick: a buffed DoT writes nothing
    end
    dot.offBeatCandidate = nil
    dot.tickSum, dot.normalTicks = previous.average + average, 2
    dot.ticksSeen = dot.ticksSeen + 2
    dot.lastTickAmount, dot.lastTickShape, dot.lastTickCrit = amount, factor, false
    saveLearnedTick(dot)
    if dot.tickKey then ns.dropSnapshots(dot.tickKey) end -- other mobs' DoTs that have not ticked yet must not keep the wrong size
    if not dot.firstTickAt then
        dot.firstTickAt, dot.lastTickIndex = previous.at, 0
        index = 1
    end
    anchorTick(dot, index, now)
    return true
end

-- A DoT whose ticks miss the cast's schedule never matched a tick: nothing was learned and the estimate ran
-- on the clock alone (DoesItDie issue #26 dropped such DoTs as "never ticked"). Two ways that happens:
-- * A recast that keeps the old DoT's tick timer: its ticks stay on the old rhythm, anywhere within the first
--   interval after the cast. A hit exactly on that rhythm (anchored window) and of the old DoT's tick size is
--   tick 1 (`oldRhythmAt`/`oldTickSize`, set by the cast).
-- * A first tick later than the matching window: two hits of its school one interval apart and of the same,
--   plausible size, the first between the missed window and 1.5 s after it. Physical and proc DoTs are left
--   out (melee white hits keep a rhythm), and without a learned size a hit may be at most twice the
--   description's share: a Shadow Bolt next to a resisted Corruption must not become its ticks.
-- Field, not local: this file is at Lua's 200-local limit.
function ns.discoverRhythm(dot, name, amount, isCrit, now)
    if dot.firstTickAt or dot.ticksSeen > 0 or isCrit or amount <= 0 or dot.procDot then return false end
    local since = now - dot.appliedAt
    -- The learned size and the old DoT's (oldTickSize, kept unbuffed) are scaled to this DoT's Amplify Curse buff.
    local boost = dot.boost or 1
    local learned = dot.tickKey and db.ticks[dot.tickKey]
    learned = learned and learned * boost
    local function near(size, reference)
        return math.abs(size - reference) <= math.max(1, reference * FIRST_TICK_AMOUNT_TOLERANCE)
    end
    if dot.oldRhythmAt and since > 0 and since < dot.interval + TICK_MATCH_WINDOW_ANCHORED then
        local k = math.floor((now - dot.oldRhythmAt) / dot.interval + 0.5)
        local size = dot.oldTickSize and dot.oldTickSize * boost or learned
        if k >= 1 and math.abs(now - (dot.oldRhythmAt + k * dot.interval)) <= TICK_MATCH_WINDOW_ANCHORED
            and size and near(amount, size * tickShape(dot, 1)) then
            dot.appliedAt = now - dot.interval
            local factor = tickShape(dot, 1)
            dot.ticksSeen, dot.tickSum, dot.normalTicks = 1, amount / factor, 1
            dot.lastTickAmount, dot.lastTickShape, dot.lastTickCrit = amount, factor, false
            dot.offBeatCandidate, dot.rhythmCandidate, dot.oldRhythmAt = nil, nil, nil
            saveLearnedTick(dot)
            anchorTick(dot, 1, now)
            trace(string.format("RHYTHM %s: tick %d on the recast DoT's old rhythm, %.1fs after the cast", name,
                amount, since))
            return true
        end
    end
    if dot.school == SCHOOL_MASKS.Physical then return false end
    local earliest = dot.interval + TICK_MATCH_WINDOW + (dot.travel or 0)
    local latest = earliest + 1.5
    if since < earliest or since > latest + dot.interval + TICK_MATCH_WINDOW_ANCHORED then return false end
    local share = dot.total / dot.totalTicks * boost
    local function plausible(size, number)
        local factor = tickShape(dot, number)
        if learned then return near(size, learned * factor) end
        return size >= share * factor * 0.5 - 1 and size <= share * factor * 2 + 1
    end
    local previous = dot.rhythmCandidate
    if previous and math.abs(now - previous.at - dot.interval) <= TICK_MATCH_WINDOW_ANCHORED
        and math.abs(amount - previous.amount) <= math.max(1, previous.amount * TICK_AMOUNT_TOLERANCE)
        and plausible(amount, 2) then
        dot.rhythmCandidate = nil
        dot.appliedAt = previous.at - dot.interval
        local first, second = tickShape(dot, 1), tickShape(dot, 2)
        dot.tickSum, dot.normalTicks, dot.ticksSeen = previous.amount / first + amount / second, 2, 2
        dot.lastTickAmount, dot.lastTickShape, dot.lastTickCrit = amount, second, false
        dot.offBeatCandidate = nil
        saveLearnedTick(dot)
        dot.firstTickAt, dot.lastTickIndex = previous.at, 0
        anchorTick(dot, 1, now)
        trace(string.format("RHYTHM %s: ticks of %d and %d %.1fs apart, the first %.1fs after the cast", name,
            previous.amount, amount, now - previous.at, since - (now - previous.at)))
        return true
    end
    if since <= latest and plausible(amount, 1) then
        dot.rhythmCandidate = { at = now, amount = amount }
    end
    return false
end

-- Returns the target key when this hit was the first tick of a DoT that was waiting for it (so the display
-- can flash now that the DoT shows), else nil.
-- F1: two same-school ticks landing in the same instant share one signature
-- (key:amount:school:time), so the second was dropped as a cross-token
-- duplicate and its DoT starved into DROP. Track which DoTs the hit already
-- fed and let a repeat feed a different one — but only from the SAME unit
-- token: a repeat from another token is the same hit seen twice and stays
-- dropped, so one hit can never feed two DoTs (no false skull).
local combatFrameAt
local combatFrameHits = {}

-- Forever hides amounts, not schools (DoesItDie #26): match timing without learning damage.
-- ponytail: foreign hits can consume a hidden tick slot, but physical hits must not move the cast's rhythm.
-- Field, not local: this file is at Lua's 200-local limit.
function ns.onHiddenAmountHit(key, unit, school, absorbed)
    local dots = dotsByTarget[key]
    local tracked = dots ~= nil
    -- An armed trap needs the hit even where no DoT runs (ProcDots.lua).
    if not dots and not (ns.ProcDots and ns.ProcDots.Wants(false, school)) then return end
    dots = dots or {}
    local now = GetTime()
    if combatFrameAt ~= now then
        combatFrameHits = {}
        combatFrameAt = now
    end
    -- The same hit on another unit token is a copy; a repeat from the same token feeds another DoT.
    local signature = key .. ":hidden:" .. school
    local hit = combatFrameHits[signature]
    if hit then
        if unit ~= hit.unit then return end
    else
        hit = { unit = unit, fed = {} }
        combatFrameHits[signature] = hit
    end
    local best, bestName, bestDistance, bestIndex
    for name, dot in pairs(dots) do
        if not dot.predictionOnly and not hit.fed[name] and dot.school == school then
            local distance, index = distanceToExpectedTick(dot, now)
            local window = dot.firstTickAt and TICK_MATCH_WINDOW_ANCHORED or TICK_MATCH_WINDOW
            local freshSlot = index > (dot.firstTickAt and dot.lastTickIndex or (dot.hiddenSlot or 0))
            if freshSlot and distance <= window and (not bestDistance or distance < bestDistance) then
                best, bestName, bestDistance, bestIndex = dot, name, distance, index
            end
        end
    end
    if not best then
        -- An armed trap's ticks, told by their rhythm alone.
        if ns.ProcDots and ns.ProcDots.OnHiddenHit(key, unit, school, now) then return key end
        if tracked then trace(string.format("HIT (amount hidden) school %d on %s not matched to a DoT", school, unit)) end
        return
    end
    if absorbed then
        ns._absorbedAt = ns._absorbedAt or {}
        ns._absorbedAt[key] = now
    end
    if school == SCHOOL_MASKS.Physical and best.firstTickAt then return end
    local wasWaiting = isWaiting(best)
    best.ticksSeen = best.ticksSeen + 1
    -- lastTickAmount keeps the last readable tick (referenceTickSize subtracts it from tickSum); flagged like a
    -- crit so a readable hit in the same slot isn't judged against a size nobody saw (trySwapSameSlot).
    best.lastTickCrit = true
    best.offBeatCandidate, best.rhythmCandidate, best.oldRhythmAt = nil, nil, nil
    local tickIndex
    if school == SCHOOL_MASKS.Physical and not best.firstTickAt then
        best.missed, best.hiddenSlot = 0, bestIndex
        best.nextTickAt = math.max(best.nextTickAt, best.appliedAt + (bestIndex + 1) * best.interval)
        tickIndex = bestIndex
    else
        tickIndex = anchorTick(best, bestIndex, now)
    end
    hit.fed[bestName] = true
    if ns.Learn then ns.Learn.HiddenTick(best, tickShape(best, tickIndex)) end
    local nowShown = wasWaiting and not isWaiting(best)
    trace(string.format("TICK %s (amount hidden) on %s (tick %d/%d, expecting %.1f for this tick)%s", bestName,
        unit, tickIndex, best.totalTicks, expectedTick(best) * tickShape(best, tickIndex),
        nowShown and ", now shown" or ""))
    if nowShown then return key end
end

local function onUnitCombat(unit, action, flag, amount, school)
    if ns.Retail then return end -- No spell/source identity: other players' damage must not teach our estimate.
    if isSecret(action) then return end
    local key = unitKey(unit)
    if not key then return end
    -- DOT-6: an absorbed tick still landed on the mob (the shield ate it),
    -- so it proves the DoT is alive and keeps its rhythm. Treat ABSORB like
    -- WOUND for matching, but never let a 0 feed tickSum/learned sizes.
    local absorbed = action == "ABSORB"
    if AVOIDED_ACTIONS[action] then return onTargetAvoided(action, key, school) end
    if action == "WOUND" or absorbed then onTargetHit(key, school) end
    if action ~= "WOUND" and not absorbed then return end
    if isSecret(amount) and not isSecret(school) and type(school) == "number" then
        return ns.onHiddenAmountHit(key, unit, school, absorbed)
    end
    if isSecret(amount) or isSecret(school) or type(amount) ~= "number" then return end
    local isCrit = not isSecret(flag) and flag == "CRITICAL"
    local dots = dotsByTarget[key]
    local tracked = dots ~= nil -- a mob carrying a DoT of yours: only its unmatched hits are logged
    -- An armed trap or a crit that may light Ignite / Deep Wounds (ProcDots.lua) needs the hit even where no DoT runs.
    if not dots and not (ns.ProcDots and ns.ProcDots.Wants(isCrit, school)) then return end
    dots = dots or {}

    -- The same hit fires for target, nameplateN, softenemy...: handle it once.
    -- F1: two same-school ticks in the same instant share one signature, so
    -- the second was dropped and its DoT starved into DROP. Repeats from the
    -- SAME unit token feed a different unfed DoT; repeats from another token
    -- are the same hit seen twice and stay dropped.
    local now = GetTime()
    -- Keep every signature in this frame: another mob's hit can arrive between a hit and its token copy.
    if combatFrameAt ~= now then
        combatFrameHits = {}
        combatFrameAt = now
    end
    local signature = key .. ":" .. amount .. ":" .. school
    local hit = combatFrameHits[signature]
    if hit then
        if unit ~= hit.unit then return end
    else
        hit = { unit = unit, fed = {} }
        combatFrameHits[signature] = hit
    end
    local lastCombatFed = hit.fed
    if ns.DeathMark then ns.DeathMark.OnHit(key, amount, now) end

    local best, bestName, bestDistance, bestIndex
    -- A shield that ate the whole tick reports ABSORB with amount 0. Zero matches no learned
    -- size, so it used to miss the DoT's slot. Keep the rhythm only when exactly one DoT of
    -- this school is due; zero never reaches tickSum below.
    local zeroAbsorb = absorbed and amount == 0
    local candidates = 0
    for name, dot in pairs(dots) do
        if not dot.predictionOnly and not lastCombatFed[name] and dot.school == school
            and (zeroAbsorb or plausibleTickAmount(dot, amount, isCrit, tickNumberAt(dot, now))) then
            local distance, index = distanceToExpectedTick(dot, now)
            local window = dot.firstTickAt and TICK_MATCH_WINDOW_ANCHORED or TICK_MATCH_WINDOW
            -- Each tick slot takes one hit: a second hit near an already-matched tick is someone else's.
            local freshSlot = not dot.firstTickAt or index > dot.lastTickIndex
            if freshSlot and distance <= window then
                candidates = candidates + 1
                if not bestDistance or distance < bestDistance then
                    best, bestName, bestDistance, bestIndex = dot, name, distance, index
                end
            end
        end
    end
    -- No size to tell two same-school DoTs apart, and no candidate to anchor.
    if zeroAbsorb and candidates ~= 1 then
        if candidates == 0 and ns.ProcDots and ns.ProcDots.Wants(false, school) then
            local now = GetTime()
            if ns.ProcDots.OnUnmatchedHit(key, unit, amount, school, false, now) then return key end
        end
        return
    end
    if not best then
        -- Not a tick as things stand; it may still correct one (same-slot swap, or a wrong learned size).
        for name, dot in pairs(dots) do
            if not dot.predictionOnly and not lastCombatFed[name] and dot.school == school then
                local distance, index = distanceToExpectedTick(dot, now)
                local wasWaiting = isWaiting(dot)
                if trySwapSameSlot(dot, name, amount, isCrit, now) then return end
                if tryRelearn(dot, name, amount, isCrit, index, distance, now) then
                    return wasWaiting and not isWaiting(dot) and key or nil
                end
                if ns.discoverRhythm(dot, name, amount, isCrit, now) then
                    lastCombatFed[name] = true
                    return wasWaiting and not isWaiting(dot) and key or nil
                end
            end
        end
        -- An armed trap's first tick, or the crit behind an Ignite / Deep Wounds: the DoT starts here.
        if ns.ProcDots and ns.ProcDots.OnUnmatchedHit(key, unit, amount, school, isCrit, GetTime()) then return key end
        if tracked then
            trace(string.format("HIT %d%s school %d on %s not matched to a DoT", amount, isCrit and " (crit)" or "",
                school, unit))
        end
        return
    end

    local wasWaiting = isWaiting(best)
    local factor = tickShape(best, tickNumberAt(best, now))
    best.ticksSeen = best.ticksSeen + 1
    best.lastTickAmount, best.lastTickShape, best.lastTickCrit = amount, factor, isCrit
    best.offBeatCandidate = nil
    if not isCrit and amount > 0 then
        best.tickSum = best.tickSum + amount / factor
        best.normalTicks = best.normalTicks + 1
        saveLearnedTick(best)
    end
    -- A shield ate (part of) our own tick: readable proof of an absorb even when the aura list is secret.
    if absorbed then
        ns._absorbedAt = ns._absorbedAt or {}
        ns._absorbedAt[key] = now
    end
    local tickIndex = anchorTick(best, bestIndex, now)
    lastCombatFed[bestName] = true
    if ns.DeathMark then ns.DeathMark.OnTick(key, bestName, amount, now) end
    local nowShown = wasWaiting and not isWaiting(best)
    trace(string.format("TICK %s %d%s on %s (tick %d/%d, expecting %.1f for this tick)%s", bestName, amount,
        isCrit and " CRIT" or "", unit, tickIndex, best.totalTicks, expectedTick(best) * factor,
        nowShown and ", now shown" or ""))
    if nowShown then return key end
end

-- Debuff check (Forever). UNIT_SPELLCAST_SUCCEEDED also fires for a cast that was resisted or missed, and the
-- UNIT_COMBAT outcome that tells them apart names no spell: next to other DoTs of the same school (an affliction
-- warlock's) it can be lost or taken for someone else's, and the DoT that never landed was then fed by the other
-- DoTs' ticks and stayed up. The debuff itself settles it wherever the client lets it be read: shortly after the
-- cast the mob's debuffs from the player either hold the spell or they don't.
--   * there: the DoT is real (a doubt left by an outcome event is over). A recast whose debuff is still the
--     earlier application did not land, so the DoT it replaced is put back.
--   * not there: the cast did not land and the DoT is dropped. Only for spells whose debuff has been read under
--     the cast's name before (db.auras): a DoT whose debuff carries another name is never judged this way.
--   * unreadable (secret auras, mob on no unit token): nothing is decided, the outcome events stand alone.
-- Fields on ns: this chunk is at Lua 5.1's 200-local limit.
ns._auraCheck = { delay = 0.4, giveUp = 3, startSlack = 0.75 }

-- A unit token that currently shows the mob behind `key`, or nil.
function ns._unitForKey(key)
    if key == "target" then return "target" end
    local token = type(key) == "string" and key:match("^plate:(nameplate%d+)$")
    if token then return token end
    for _, unit in ipairs({ "target", "softenemy", "focus", "mouseover" }) do
        if unitKey(unit) == key then return unit end
    end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if unitKey(unit) == key then return unit end
    end
end

-- Whether the player's own debuffs on `unit` hold the spell (by ID or by name), and when that debuff started
-- if its timer is readable. nil when the list cannot be read well enough to say.
function ns._ownDebuff(unit, spellID, name)
    local byIndex = C_UnitAuras and (C_UnitAuras.GetAuraDataByIndex or C_UnitAuras.GetDebuffDataByIndex)
    local filter = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and "HARMFUL|PLAYER" or "PLAYER"
    if type(byIndex) ~= "function" and type(UnitDebuff) ~= "function" then return nil end
    local unsure = false
    for i = 1, 40 do
        local ok, auraName, id, duration, expires
        if type(byIndex) == "function" then
            local aura
            ok, aura = pcall(byIndex, unit, i, filter)
            if not ok or isSecret(aura) then return nil end
            if aura == nil then break end
            if type(aura) ~= "table" then return nil end
            ok, auraName, id, duration, expires = pcall(function()
                return aura.name, aura.spellId, aura.duration, aura.expirationTime
            end)
        else
            local _
            ok, auraName, _, _, _, duration, expires, _, _, _, id = pcall(UnitDebuff, unit, i, "PLAYER")
            if ok and not isSecret(auraName) and auraName == nil then break end
        end
        if not ok then return nil end
        local idKnown = not isSecret(id) and type(id) == "number"
        local nameKnown = not isSecret(auraName) and type(auraName) == "string"
        if (idKnown and id == spellID) or (nameKnown and auraName == name) then
            local startedAt
            if not isSecret(duration) and not isSecret(expires) and type(duration) == "number"
                and type(expires) == "number" and duration > 0 and expires > 0 then
                startedAt = expires - duration
            end
            return true, startedAt
        end
        -- An entry that cannot be identified may be the one looked for.
        if not (idKnown and nameKnown) then unsure = true end
    end
    if unsure then return nil end
    return false
end

function ns._verifyAuras(now)
    local check = ns._auraCheck
    for key, dots in pairs(dotsByTarget) do
        local unit, looked
        for name, dot in pairs(dots) do
            if dot.verifyAt and now >= dot.verifyAt then
                if not looked then unit, looked = ns._unitForKey(key), true end
                local found, startedAt
                if unit then found, startedAt = ns._ownDebuff(unit, dot.spellID, name) end
                if found == nil then
                    if now - dot.verifyAt > check.giveUp then
                        dot.verifyAt = nil
                        if not dot.confirmationPending then dot.replaced = nil end
                    end
                else
                    local replaced = dot.replaced
                    if found then
                        db.auras[name] = true
                        if replaced and startedAt and startedAt < dot.appliedAt - check.startSlack then
                            dots[name] = replaced
                            trace(string.format("AURA %s on %s is still the earlier one (%.1fs old): the recast did not land; keeping the earlier one",
                                name, unit, now - startedAt))
                        elseif dot.confirmationPending and replaced and not startedAt
                            and now <= replaced.expiresAt + TICK_MATCH_WINDOW then
                            -- An undated aura may still be the old application.
                            if now - dot.verifyAt > check.giveUp then dot.verifyAt = nil end
                        else
                            dot.verifyAt, dot.replaced = nil, nil
                            if dot.doubtful or dot.confirmationPending then
                                dot.doubtful, dot.confirmationPending = nil, nil
                                trace(string.format("AURA %s is on %s: it landed", name, unit))
                            end
                        end
                    elseif db.auras[name] then
                        dots[name] = nil
                        trace(string.format("AURA %s is not on %s: resisted or missed; dropped", name, unit))
                    else
                        dot.verifyAt = nil
                        if not dot.confirmationPending then dot.replaced = nil end
                        trace(string.format("AURA %s is not on %s, but its debuff was never read under that name: not judged",
                            name, unit))
                    end
                end
            end
        end
        if next(dots) == nil then dotsByTarget[key] = nil end
    end
end

-- The combo points after a dropped finisher: spent means it landed (the avoid was a white swing), so it is put
-- back; still there, unreadable, or the target changed (the points belong to the target) leaves it dropped.
function ns._resolveFinisherCheck(now)
    local check = ns._finisherCheck
    if not check or now < check.at then return end
    ns._finisherCheck = nil
    local cast = check.cast
    if unitKey("target") ~= cast.key then
        trace("COMBO after " .. cast.name .. "'s " .. check.action .. ": target changed, stays dropped")
        return
    end
    local points, readings = readComboPoints()
    if not points or points >= cast.comboRead then
        trace(string.format("COMBO after %s's %s: %s (had %d), it missed", cast.name, check.action, readings,
            cast.comboRead))
        return
    end
    local dots = dotsByTarget[cast.key]
    if (dots and dots[cast.name]) ~= check.replaced or now >= check.dot.expiresAt then return end
    dotsByTarget[cast.key] = dots or {}
    dotsByTarget[cast.key][cast.name] = check.dot
    trace(string.format("COMBO after %s's %s: %s (had %d), spent: it landed, restored", cast.name, check.action,
        readings, cast.comboRead))
end

local function housekeep(now)
    if ns.ProcDots then ns.ProcDots.Housekeep(now) end
    if not ns.Retail then
        ns._resolveFinisherCheck(now)
        ns._verifyAuras(now)
    end
    for guid, sent in pairs(ns._retailPending) do
        if (sent.stoppedAt and now - sent.stoppedAt > CAST_STOP_GRACE)
            or now - sent.sentAt > CAST_MAX_SECONDS then ns._retailPending[guid] = nil end
    end
    if pendingCast and ((pendingCast.stoppedAt and now - pendingCast.stoppedAt > CAST_STOP_GRACE)
        or now - pendingCast.sentAt > CAST_MAX_SECONDS) then
        pendingCast, comboAtSend = nil, nil
    end
    for key, dots in pairs(dotsByTarget) do
        local onToken -- whether a unit token shows the mob now: ticks only arrive (UNIT_COMBAT) for a mob on one
        for name, dot in pairs(dots) do
            local replaced = dot.confirmationPending and isWaiting(dot) and dot.replaced
            if replaced then
                while replaced.nextTickAt < now - TICK_MATCH_WINDOW and replaced.nextTickAt <= replaced.expiresAt do
                    replaced.nextTickAt = replaced.nextTickAt + replaced.interval
                end
            end
            local late = (dot.ticksSeen == 0 and dot.travel) or 0
            while not dot.predictionOnly and dot.nextTickAt < now - TICK_MATCH_WINDOW - late
                and dot.nextTickAt <= dot.expiresAt do
                dot.nextTickAt = dot.nextTickAt + dot.interval
                if dot.missed == 0 then dot.missedUnseen = 0 end
                dot.missed = dot.missed + 1
                -- A tick due while the mob was on no token (another target, no nameplate) could not be seen:
                -- it says nothing about the DoT having stopped.
                if onToken == nil then onToken = ns._unitForKey(key) ~= nil end
                if not onToken then dot.missedUnseen = (dot.missedUnseen or 0) + 1 end
            end
            if not dot.predictionOnly and not dot.auraObserved and dot.ticksSeen == 0 and dot.missed >= math.max(MISSED_TICKS_BEFORE_DROP, dot.totalTicks) then
                dots[name] = nil
                trace("DROP " .. name .. " never ticked (resisted or immune?)")
            -- Ticked, then went quiet on its known rhythm: dispelled or pushed off by the debuff cap. Its leftover
            -- ticks would keep the kill icon lit. Physical is left out: hidden-amount bleed ticks don't reset
            -- `missed` once anchored (onHiddenAmountHit). Proc DoTs keep their own books (ProcDots.lua).
            -- Only ticks missed while the mob was on a unit token count (missedUnseen: the rest).
            elseif not dot.predictionOnly and not dot.auraObserved and not dot.procDot and dot.firstTickAt
                and dot.school ~= SCHOOL_MASKS.Physical
                and dot.missed - (dot.missedUnseen or 0) >= MISSED_TICKS_BEFORE_DROP + 1 then
                dots[name] = nil
                trace("DROP " .. name .. " stopped ticking (dispelled?)")
            elseif now > dot.expiresAt + TICK_MATCH_WINDOW then
                dots[name] = nil
                trace("EXPIRE " .. name)
            end
        end
        if next(dots) == nil then dotsByTarget[key] = nil end
    end
    if castInProgress then
        if castInProgress.stoppedAt and now - castInProgress.stoppedAt > CAST_STOP_GRACE then
            dropCastInProgress("stopped without succeeding")
        elseif now - castInProgress.startedAt > CAST_MAX_SECONDS then
            dropCastInProgress("never finished")
        end
    end
end

local function remainingDamage(dot)
    -- Death Mark (DeathMark.lua): what it stored lands at once when it ends.
    if dot.burst then return GetTime() <= dot.expiresAt + TICK_MATCH_WINDOW and dot.total or 0 end
    if dot.predictionOnly then
        if ns.Retail then return ns.Retail.Remaining(dot, GetTime()) end
        return dot.total * math.max(0, math.min(1, (dot.expiresAt - GetTime()) / dot.duration))
    end
    if dot.nextTickAt > dot.expiresAt + dot.interval / 2 then return 0 end
    local ticksLeft = math.floor((dot.expiresAt - dot.nextTickAt) / dot.interval + 0.5) + 1
    if not dot.shape then return ticksLeft * expectedTick(dot) end
    local average, total = expectedTick(dot), 0
    for number = math.max(1, dot.totalTicks - ticksLeft + 1), dot.totalTicks do
        total = total + average * tickShape(dot, number)
    end
    return total
end

-- What ProcDots.lua needs from the tracking (kept as fields: this file is at Lua's limit of local variables).
ns.Internals = {
    newDot = newDot, plausibleTickAmount = plausibleTickAmount, saveLearnedTick = saveLearnedTick,
    anchorTick = anchorTick, remainingDamage = remainingDamage, dotsByTarget = dotsByTarget, trace = trace,
    getDb = function() return db end, unitKey = unitKey,
}

-- Known ticks first, description estimates next, own clocks last. Freeze each visible effect's position
-- through damage/clock refinements and refreshes; a corrected amount must not reshuffle its neighbours.
-- DoTs still waiting for their first tick are left out. A cast replaces the DoT it would refresh.
local function dotBreakdown(key)
    local function refreshDueFor(name, dot)
        if ns.Retail then return db and db.refreshCue and ns.Retail.RefreshDue(dot, GetTime()) end
        if not db or db.refreshCue == false or not ns.refreshNames[name] or type(dot) ~= "table" then return false end
        local remaining = (tonumber(dot.expiresAt) or 0) - (GetTime() or 0)
        local duration = dot.duration
        if type(duration) ~= "number" and type(dot.expiresAt) == "number" and type(dot.appliedAt) == "number" then
            duration = dot.expiresAt - dot.appliedAt
        end
        local plate = BIT.Plate
        if type(plate) ~= "table" or type(plate.RefreshDue) ~= "function" then return false end
        return plate.RefreshDue(remaining, duration, dot.interval) and true or false
    end
    local dots = key and dotsByTarget[key]
    local cast = key and castInProgress and castInProgress.key == key and castInProgress or nil
    local castVisible = cast and not isWaiting(cast.dot)
    local list = {}
    if not dots and not cast then return list end
    for name, dot in pairs(dots or {}) do
        if dot.confirmationPending and isWaiting(dot) then
            dot = dot.replaced
            if dot and GetTime() >= dot.expiresAt then dot = nil end
        end
        if dot and not isWaiting(dot) and not (castVisible and name == cast.name) then
            if not dot.segmentOrder then
                dot.segmentOrder = { rank = dot.estimatedClock and 2
                    or ((dot.predictionOnly or (dot.unsure and dot.normalTicks == 0)) and 1 or 0),
                    appliedAt = dot.appliedAt }
            end
            table.insert(list, { name = name, spellID = dot.spellID, school = dot.school, appliedAt = dot.appliedAt,
                expiresAt = dot.expiresAt, damage = remainingDamage(dot), familyID = dot.familyID, segmentOrder = dot.segmentOrder,
                refreshDue = refreshDueFor(name, dot) })
        end
    end
    if castVisible then
        -- `running`: what the DoT this cast would refresh still has to deal. The cast's entry stands in for it
        -- above, so the kill check (KillCheck.lua), which leaves the cast out, counts this instead.
        local refreshed = dots and dots[cast.name]
        table.insert(list, { name = cast.name, spellID = cast.spellID, school = cast.dot.school, appliedAt = cast.dot.appliedAt,
            expiresAt = cast.dot.expiresAt,
            running = refreshed and not isWaiting(refreshed) and remainingDamage(refreshed) or nil,
            segmentOrder = { rank = 3, appliedAt = cast.dot.appliedAt },
            damage = remainingDamage(cast.dot), familyID = cast.dot.familyID, provisional = true, refreshDue = refreshDueFor(cast.name, cast.dot) })
    end
    table.sort(list, function(a, b)
        local first, second = a.segmentOrder, b.segmentOrder
        if first.rank ~= second.rank then return first.rank < second.rank end
        if first.appliedAt ~= second.appliedAt then return first.appliedAt < second.appliedAt end
        return a.name < b.name
    end)
    return list
end

-- Returns what the target's DoTs still have to deal, how many DoTs count toward it, and the per-DoT
-- breakdown (see dotBreakdown).
local function targetRemainingDamage()
    local list = dotBreakdown(unitKey("target"))
    local total = 0
    for _, entry in ipairs(list) do total = total + entry.damage end
    return math.floor(total + 0.5), #list, list
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------

local WHITE = "Interface\\Buttons\\WHITE8X8"
-- Generated by tools/make_textures.py. Under the addon's folder name.
local TEXTURE_DIR = "Interface\\AddOns\\Ready2Quest\\Combat\\Modules\\DoTInfo\\Textures\\"

local SKULL_ICONS = {
    { id = "skull",  label = "Raid skull",      path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    { id = "cross",  label = "Red X",           path = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
    { id = "check",  label = "Green checkmark", path = "Interface\\RaidFrame\\ReadyCheck-Ready" },
    { id = "boss",   label = "Boss skull",      path = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
    { id = "shades", label = "Sunglasses",      path = TEXTURE_DIR .. "Sunglasses" },
    kind = "icon", -- pictures, not fill textures: the menus show them square and untinted
}

local FILL_STYLES = {
    { id = "none",     label = "None", group = "Basic" },
    { id = "flat",     label = "Flat",               path = WHITE, group = "Basic" },
    { id = "gradient", label = "Fade in from left",  path = WHITE, gradient = true, group = "Basic" },
    { id = "smooth",   label = "Health bar texture", path = "Interface\\TargetingFrame\\UI-StatusBar", group = "Blizzard" },
    { id = "raid",     label = "Raid bar texture",   path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill", group = "Blizzard" },
    { id = "stripes",  label = "Diagonal stripes",   path = TEXTURE_DIR .. "Stripes", tiled = true, group = "Patterns" },
}
-- Every texture of the shared catalog (Core/Looks.lua) is a fill too; shared-media ones join when the options open.
if BIT.Looks then BIT.Looks.Merge(FILL_STYLES) end

local OUTLINE_STYLES = {
    { id = "dashed", label = "Dashed" },
    { id = "solid",  label = "Solid" },
    { id = "none",   label = "None" },
}

local DASH_LENGTHS = { -- must match tools/make_textures.py
    { id = 1,  label = "Fine dots (1px)" },
    { id = 2,  label = "Dots (2px)" },
    { id = 4,  label = "Short dashes (4px)" },
    { id = 8,  label = "Dashes (8px)" },
    { id = 16, label = "Long dashes (16px)" },
}

local LABEL_POSITIONS = {
    { id = "left",   label = "Left of the bar" },
    { id = "center", label = "Centered on the bar" },
    { id = "right",  label = "Inside the bar, right end" },
}

local DOT_COLOR_MODES = {
    { id = "single", label = "One color (fill color)" },
    { id = "each",   label = "By effect type" },
    { id = "rainbow", label = "Rainbow" },
}

-- "By spell school" colors, keyed by school mask (Frostfire = Fire + Frost; Forever's other combined schools likewise).
local SCHOOL_COLORS = {
    [1] = { 1, 0.3, 0.3 },      -- Physical (bleeds)
    [2] = { 1, 0.9, 0.45 },     -- Holy
    [4] = { 1, 0.55, 0.15 },    -- Fire
    [8] = { 0.35, 1, 0.35 },    -- Nature
    [16] = { 0.45, 0.8, 1 },    -- Frost
    [20] = { 0.75, 0.6, 1 },    -- Frostfire
    [36] = { 0.85, 0.4, 0.7 },  -- Shadowflame
    [48] = { 0.55, 0.55, 1 },   -- Shadowfrost
    [68] = { 1, 0.5, 0.6 },     -- Spellfire
    [80] = { 0.6, 0.85, 1 },    -- Spellfrost
    [84] = { 0.85, 0.65, 0.75 }, -- Chimeral
    [127] = { 0.85, 0.85, 0.85 }, -- Chaos
    [32] = { 0.7, 0.35, 1 },    -- Shadow
    [64] = { 1, 0.55, 1 },      -- Arcane
}

-- "Rainbow": each spell keeps the palette color it got when first seen this session, so
-- colors don't shuffle when DoTs are recast or expire.
local DOT_PALETTE = {
    { 0.95, 0.3, 0.3 }, { 0.3, 0.75, 1 }, { 1, 0.8, 0.2 }, { 0.45, 1, 0.45 },
    { 0.85, 0.4, 1 }, { 1, 0.55, 0.15 }, { 0.3, 1, 0.9 }, { 1, 0.45, 0.75 },
}
local paletteColorByName, nextPaletteIndex = {}, 1

-- Defaults to the target marker's setting; nameplates and the native poison pass their own.
local function dotColor(entry, mode)
    if (mode or db.dotColors) ~= "rainbow" then
        return SCHOOL_COLORS[entry.school] or COLOR_BY_ID.white
    end
    local color = paletteColorByName[entry.name]
    if not color then
        color = DOT_PALETTE[nextPaletteIndex]
        if not color then
            -- Continue around the hue wheel instead of reusing a previous spell's palette color.
            local hue = (nextPaletteIndex * 0.618033988749895 % 1) * 6
            local rising = 0.25 + 0.75 * (hue - math.floor(hue))
            local falling = 1.25 - rising
            color = ({ { 1, rising, 0.25 }, { falling, 1, 0.25 }, { 0.25, 1, rising },
                { 0.25, falling, 1 }, { rising, 0.25, 1 }, { 1, 0.25, falling } })[math.floor(hue) + 1]
        end
        paletteColorByName[entry.name], nextPaletteIndex = color, nextPaletteIndex + 1
    end
    return color
end

local SMOOTH_RATE = 10 -- how fast the marker glides to a new value (higher = snappier)

local function findById(list, id)
    if list == FILL_STYLES and BIT.Looks and type(id) == "string" and id:sub(1, 4) == "lsm:" then
        return BIT.Looks.Texture(id)
    end
    for _, entry in ipairs(list) do
        if entry.id == id then return entry end
    end
    return list[1]
end

local function colorOf(id, opacityPercent)
    local rgb = COLOR_BY_ID[id] or (BIT.Looks and BIT.Looks.Rgb(id)) or COLOR_BY_ID.white
    return rgb[1], rgb[2], rgb[3], (opacityPercent or 100) / 100
end

local healthBar, targetHost -- nil if the target frame's health bar wasn't found (markers unavailable)
-- While the options window is open, the display is attached to its mock target frame (previewHost:
-- { healthBar, portrait, layerFrame }) and fed its plain numbers (previewState: { health, dots }) instead.
local previewHost, previewState
local skullTestUntil -- /dotinfo skull forces the skull visible until this time

-- Skull: addon code can't compare DoT damage with (secret) health, but a StatusBar can. We feed it
-- max = current health, value = remaining DoT damage; the fill only reaches the bar's right end when
-- damage >= health. The skull rides the fill's right edge, and only the last skull-width of the very
-- long bar is visible (clipped), so the skull appears over the portrait only when lethal.
-- It starts sliding in at skullSize / SKULL_BAR_LENGTH short of lethal (0.2% at 20px, 1.3% at 128px).
local SKULL_BAR_LENGTH = 10000

local skullWindow = CreateFrame("Frame", "Ready2QuestCombat_DoTInfoSkull", UIParent)
skullWindow:SetClipsChildren(true)
skullWindow:Hide()

local skullBar = CreateFrame("StatusBar", nil, skullWindow)
skullBar:SetPoint("RIGHT", skullWindow, "RIGHT")
skullBar:SetStatusBarTexture(WHITE)
skullBar:SetStatusBarColor(0, 0, 0, 0)

local skull = skullBar:CreateTexture(nil, "OVERLAY")
skull:SetPoint("RIGHT", skullBar:GetStatusBarTexture(), "RIGHT")

local skullPulse = skull:CreateAnimationGroup()
skullPulse:SetLooping("BOUNCE")
local skullPulseAlpha = skullPulse:CreateAnimation("Alpha")
skullPulseAlpha:SetFromAlpha(1)
skullPulseAlpha:SetToAlpha(0.45)
skullPulseAlpha:SetDuration(0.7)
skullPulseAlpha:SetSmoothing("IN_OUT")

-- /dotinfo skull diagnostics: an unclipped skull just above the portrait, to tell a placement/strata
-- problem apart from a problem with the clipped status-bar trick.
local plainSkullFrame = CreateFrame("Frame", nil, UIParent)
plainSkullFrame:SetFrameStrata("HIGH")
plainSkullFrame:Hide()

local plainSkull = plainSkullFrame:CreateTexture(nil, "OVERLAY")
plainSkull:SetAllPoints()

-- Damage marker: a StatusBar laid over the whole health bar with max = max health (secret), so it shares
-- the health bar's scale. Its fill (invisible itself) spans the damage the DoTs still have to deal,
-- measured from the bar's left edge; the visible fill, outline and flash are drawn on top of that span.
-- If the green ends inside the marker, the current DoTs will kill the target.
local remainingBar = CreateFrame("StatusBar", "Ready2QuestCombat_DoTInfoRemaining", UIParent)
remainingBar:SetStatusBarTexture(WHITE)
remainingBar:SetStatusBarColor(0, 0, 0, 0)
remainingBar:Hide()
-- The modules that keep their marks above a unit frame (this one, CastPrediction) look at what is on that frame; a mark of
-- ours that sits on the bar must not count as the frame's own, or the two would raise each other without end.
BIT.OwnOverlays = BIT.OwnOverlays or setmetatable({}, { __mode = "k" })
BIT.OwnOverlays[remainingBar] = true
local span = remainingBar:GetStatusBarTexture()

local function coverSpan(texture)
    texture:SetPoint("TOPLEFT", span, "TOPLEFT")
    texture:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
end

local fillLayer = CreateFrame("Frame", nil, remainingBar)
fillLayer:SetAllPoints()

local fillTex = fillLayer:CreateTexture(nil, "ARTWORK")
coverSpan(fillTex)

-- Per-DoT segments ("DoT colors" option): the remaining damage split into one colored segment per DoT, laid
-- end to end. Segment i runs from the end of running-total bar i-1's fill to the end of bar i's fill (bar i
-- filled to DoT 1 + ... + DoT i), so it's exactly that DoT's share on the (secret) health scale.
local MAX_SEGMENTS = 8
local segments = {}
for i = 1, MAX_SEGMENTS do
    local bar = CreateFrame("StatusBar", nil, remainingBar)
    bar:SetAllPoints(remainingBar)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(0, 0, 0, 0)
    local fillEnd = bar:GetStatusBarTexture()

    local texture = fillLayer:CreateTexture(nil, "ARTWORK", nil, 1)
    if i == 1 then
        texture:SetPoint("TOPLEFT", remainingBar, "TOPLEFT")
    else
        texture:SetPoint("TOPLEFT", segments[i - 1].fillEnd, "TOPRIGHT")
    end
    texture:SetPoint("BOTTOMRIGHT", fillEnd, "BOTTOMRIGHT")
    texture:Hide()

    local divider = fillLayer:CreateTexture(nil, "OVERLAY", nil, 1)
    divider:SetColorTexture(0, 0, 0, 0.85)
    divider:SetWidth(1)
    divider:SetPoint("TOP", fillEnd, "TOPRIGHT")
    divider:SetPoint("BOTTOM", fillEnd, "BOTTOMRIGHT")
    divider:Hide()

    local refresh = fillLayer:CreateTexture(nil, "OVERLAY", nil, 3)
    refresh:SetColorTexture(1, 0.82, 0.2, 1)
    refresh:SetWidth(3)
    refresh:SetPoint("TOP", fillEnd, "TOPRIGHT")
    refresh:SetPoint("BOTTOM", fillEnd, "BOTTOMRIGHT")
    refresh:Hide()

    segments[i] = { bar = bar, fillEnd = fillEnd, texture = texture, divider = divider,
        refresh = refresh, target = 0, shown = 0 }
end

-- Single-color fill: one mark on the whole bar's leading edge when any refresh DoT is due.
fillLayer.refreshMark = fillLayer:CreateTexture(nil, "OVERLAY", nil, 3)
fillLayer.refreshMark:SetColorTexture(1, 0.82, 0.2, 1)
fillLayer.refreshMark:SetWidth(3)
fillLayer.refreshMark:SetPoint("TOP", remainingBar:GetStatusBarTexture(), "TOPRIGHT")
fillLayer.refreshMark:SetPoint("BOTTOM", remainingBar:GetStatusBarTexture(), "BOTTOMRIGHT")
fillLayer.refreshMark:Hide()

local flashTex = fillLayer:CreateTexture(nil, "OVERLAY")
coverSpan(flashTex)
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
flashOut:SetDuration(0.5)
flashOut:SetSmoothing("OUT")
flashOut:SetOrder(2)

-- The outline tiles its dash texture along each edge, so it works whatever the (secret) span length is.
local outlineLayer = CreateFrame("Frame", nil, remainingBar)
outlineLayer:SetAllPoints()

local edges = {} -- { texture, horizontal }
local function makeEdge(horizontal, point1, point2)
    local edge = outlineLayer:CreateTexture(nil, "OVERLAY", nil, 7)
    edge:SetPoint(point1, span, point1)
    edge:SetPoint(point2, span, point2)
    table.insert(edges, { texture = edge, horizontal = horizontal })
end
makeEdge(true, "TOPLEFT", "TOPRIGHT")
makeEdge(true, "BOTTOMLEFT", "BOTTOMRIGHT")
makeEdge(false, "TOPLEFT", "BOTTOMLEFT")
makeEdge(false, "TOPRIGHT", "BOTTOMRIGHT")

local outlinePulse = outlineLayer:CreateAnimationGroup()
outlinePulse:SetLooping("BOUNCE")
local outlinePulseAlpha = outlinePulse:CreateAnimation("Alpha")
outlinePulseAlpha:SetFromAlpha(1)
outlinePulseAlpha:SetToAlpha(0.3)
outlinePulseAlpha:SetDuration(0.9)
outlinePulseAlpha:SetSmoothing("IN_OUT")

-- Glow: soft halo around the span in the outline color, one gradient strip per side fading outward.
-- Lives on the outline layer so "Pulse outline" pulses it too.
local glows = {} -- { texture, side }
local function makeGlow(side)
    local glow = outlineLayer:CreateTexture(nil, "BORDER")
    glow:SetTexture(WHITE)
    glow:SetBlendMode("ADD")
    if side == "top" then
        glow:SetPoint("BOTTOMLEFT", span, "TOPLEFT")
        glow:SetPoint("BOTTOMRIGHT", span, "TOPRIGHT")
    elseif side == "bottom" then
        glow:SetPoint("TOPLEFT", span, "BOTTOMLEFT")
        glow:SetPoint("TOPRIGHT", span, "BOTTOMRIGHT")
    elseif side == "left" then
        glow:SetPoint("TOPRIGHT", span, "TOPLEFT")
        glow:SetPoint("BOTTOMRIGHT", span, "BOTTOMLEFT")
    else
        glow:SetPoint("TOPLEFT", span, "TOPRIGHT")
        glow:SetPoint("BOTTOMLEFT", span, "BOTTOMRIGHT")
    end
    table.insert(glows, { texture = glow, side = side })
end
makeGlow("top")
makeGlow("bottom")
makeGlow("left")
makeGlow("right")

-- Clipped to the span: effects that move across the whole health bar but should only show inside the
-- marker (scrolling stripes, the shine sweep). Clipping does the work Lua can't, since the span's width
-- comes from secret health.
local clipLayer = CreateFrame("Frame", nil, remainingBar)
clipLayer:SetPoint("TOPLEFT", span, "TOPLEFT")
clipLayer:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
clipLayer:SetClipsChildren(true)

local STRIPE_SCROLL_PERIOD = 8 -- px; the stripe pattern repeats every 8px horizontally (make_textures.py)

local scrollingStripes = clipLayer:CreateTexture(nil, "ARTWORK")
scrollingStripes:SetTexture(TEXTURE_DIR .. "Stripes", "REPEAT", "REPEAT")
scrollingStripes:SetHorizTile(true)
scrollingStripes:SetVertTile(true)
local stripeScroll = scrollingStripes:CreateAnimationGroup()
stripeScroll:SetLooping("REPEAT")
local stripeMove = stripeScroll:CreateAnimation("Translation")
stripeMove:SetOffset(STRIPE_SCROLL_PERIOD, 0)
stripeMove:SetDuration(0.6)

local SHINE_WIDTH = 36
local SHINE_DURATION = 0.9

local shine = clipLayer:CreateTexture(nil, "OVERLAY")
shine:SetTexture(TEXTURE_DIR .. "Shine")
shine:SetBlendMode("ADD")
shine:SetWidth(SHINE_WIDTH)
local shineSweep = shine:CreateAnimationGroup()
shineSweep:SetLooping("REPEAT")
local shineMove = shineSweep:CreateAnimation("Translation")
shineMove:SetDuration(SHINE_DURATION)
shineMove:SetSmoothing("IN_OUT")

-- Spark: bright flare on the span's right end that only appears when a DoT lands (a constant glow there
-- hides exactly the edge you need to read). Invisible at rest; the punch animation fades it in and out.
local sparkLayer = CreateFrame("Frame", nil, remainingBar)
sparkLayer:SetAllPoints()

local spark = sparkLayer:CreateTexture(nil, "OVERLAY")
spark:SetTexture(TEXTURE_DIR .. "Spark")
spark:SetBlendMode("ADD")
spark:SetWidth(14)
spark:SetPoint("TOP", span, "TOPRIGHT", 0, 7)
spark:SetPoint("BOTTOM", span, "BOTTOMRIGHT", 0, -7)
spark:SetAlpha(0)

-- Scale animations use SetScaleFrom/To on current clients; SetScale (relative) on older ones.
local function scaleStep(group, fromX, fromY, toX, toY, duration, order, smoothing)
    local anim = group:CreateAnimation("Scale")
    if anim.SetScaleFrom then
        anim:SetScaleFrom(fromX, fromY)
        anim:SetScaleTo(toX, toY)
    else
        anim:SetScale(toX / fromX, toY / fromY)
    end
    anim:SetDuration(duration)
    anim:SetOrder(order)
    if smoothing then anim:SetSmoothing(smoothing) end
end

local function alphaStep(group, from, to, duration, order, smoothing)
    local anim = group:CreateAnimation("Alpha")
    anim:SetFromAlpha(from)
    anim:SetToAlpha(to)
    anim:SetDuration(duration)
    anim:SetOrder(order)
    if smoothing then anim:SetSmoothing(smoothing) end
end

local sparkPunch = spark:CreateAnimationGroup()
scaleStep(sparkPunch, 1, 1, 1.9, 1.3, 0.08, 1)
alphaStep(sparkPunch, 0, 1, 0.08, 1)
scaleStep(sparkPunch, 1.9, 1.3, 1, 1, 0.45, 2, "OUT")
alphaStep(sparkPunch, 1, 0, 0.45, 2, "OUT")

local label = remainingBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

-- Pushes the options onto the widgets, but only when one of them changed since the last call, so it
-- can run on every refresh and option changes still show up immediately.
local APPEARANCE_KEYS = {
    "showMarkers", "targetMarkers", "skullIcon", "skullSize", "skullPosition", "skullPulse", "skullOffsetX", "skullOffsetY",
    "swingKill",
    "showSpark", "showGlow", "glowSize", "showShine", "shineInterval", "scrollStripes",
    "fillTexture", "fillColor", "fillOpacity", "dotColors",
    "outlineStyle", "dashLength", "outlineThickness", "outlineColor", "outlineOpacity", "pulseOutline",
    "showLabel", "labelSize", "labelColor", "labelPosition",
}
local appliedSignature
local skullAnchor -- what the skull is centered on (portrait, else target frame, else screen)

local function positionSkull()
    skullWindow:ClearAllPoints()
    local x, y = db.skullOffsetX, db.skullOffsetY
    if healthBar and db.skullPosition == "above" then
        skullWindow:SetPoint("BOTTOM", healthBar, "TOP", x, 4 + y)
    elseif healthBar and db.skullPosition == "below" then
        skullWindow:SetPoint("TOP", healthBar, "BOTTOM", x, -4 + y)
    elseif healthBar and db.skullPosition == "left" then
        skullWindow:SetPoint("RIGHT", healthBar, "LEFT", -4 + x, y)
    elseif healthBar and db.skullPosition == "right" then
        skullWindow:SetPoint("LEFT", healthBar, "RIGHT", 4 + x, y)
    elseif skullAnchor == UIParent then
        skullWindow:SetPoint("CENTER", UIParent, "CENTER", db.skullOffsetX, 120 + db.skullOffsetY)
    elseif skullAnchor then
        skullWindow:SetPoint("CENTER", skullAnchor, "CENTER", db.skullOffsetX, db.skullOffsetY)
    end
end

-- Width of the health bar for the shine sweep; layout values are plain, but guard in case they aren't.
local function healthBarWidth()
    local ok, width = pcall(healthBar.GetWidth, healthBar)
    if ok and not isSecret(width) and type(width) == "number" and width > 0 then return width end
    return 150
end

-- The marker starts at the bar's "no health" end. That is the left edge, except on a bar that drains the other
-- way: a mirrored unit frame (reverse fill) or X-Perl's inverse bars. "Fill direction" follows the bar or is set
-- by hand. Fields on ns: this chunk is at Lua 5.1's 200-local limit.
function ns._markerReversed()
    if db.fillDirection == "rtl" then return true end
    if db.fillDirection == "ltr" or previewHost or not healthBar then return false end
    return BIT.Plate and BIT.Plate.FillsReversed and BIT.Plate.FillsReversed(healthBar) or false
end

-- Turns the marker, its segments and the marks on its leading edge around.
function ns._applyMarkerDirection(reverse)
    local lead, trail = reverse and "LEFT" or "RIGHT", reverse and "RIGHT" or "LEFT"
    if type(remainingBar.SetReverseFill) == "function" then remainingBar:SetReverseFill(reverse) end
    for i, segment in ipairs(segments) do
        if type(segment.bar.SetReverseFill) == "function" then segment.bar:SetReverseFill(reverse) end
        segment.texture:ClearAllPoints()
        if i == 1 then
            segment.texture:SetPoint("TOP" .. trail, remainingBar, "TOP" .. trail)
        else
            segment.texture:SetPoint("TOP" .. trail, segments[i - 1].fillEnd, "TOP" .. lead)
        end
        segment.texture:SetPoint("BOTTOM" .. lead, segment.fillEnd, "BOTTOM" .. lead)
        for _, mark in ipairs({ segment.divider, segment.refresh }) do
            mark:ClearAllPoints()
            mark:SetPoint("TOP", segment.fillEnd, "TOP" .. lead)
            mark:SetPoint("BOTTOM", segment.fillEnd, "BOTTOM" .. lead)
        end
    end
    fillLayer.refreshMark:ClearAllPoints()
    fillLayer.refreshMark:SetPoint("TOP", span, "TOP" .. lead)
    fillLayer.refreshMark:SetPoint("BOTTOM", span, "BOTTOM" .. lead)
    spark:ClearAllPoints()
    spark:SetPoint("TOP", span, "TOP" .. lead, 0, 7)
    spark:SetPoint("BOTTOM", span, "BOTTOM" .. lead, 0, -7)
    -- The options window's mock bar drains the same way, so the preview reads like the real frame.
    local mock = previewHost and previewHost.healthBar
    if mock and type(mock.SetReverseFill) == "function" then mock:SetReverseFill(reverse) end
end

local function applyAppearance()
    local parts = {}
    for i, key in ipairs(APPEARANCE_KEYS) do parts[i] = tostring(db[key]) end
    local reverse = ns._markerReversed()
    parts[#parts + 1] = tostring(reverse)
    local signature = table.concat(parts, "|")
    if signature == appliedSignature then return end
    appliedSignature = signature
    ns._applyMarkerDirection(reverse)

    -- Skull
    local size = db.skullSize
    skullWindow:SetSize(size, size)
    skullBar:SetSize(SKULL_BAR_LENGTH, size)
    skull:SetSize(size, size)
    plainSkullFrame:SetSize(size, size)
    local icon = findById(SKULL_ICONS, db.skullIcon).path
    skull:SetTexture(icon)
    plainSkull:SetTexture(icon)
    if ns.swing then ns.SwingIcon.Style(ns.swing, size, db.swingKill) end
    if db.skullPulse then skullPulse:Play() else skullPulse:Stop() end
    positionSkull()

    -- Fill. Per-DoT colors draw it as segments (same texture and opacity, flat if the style has none; no
    -- scrolling or fade). Otherwise one fill; stripes can scroll, drawn by the clipped, animated texture.
    local fill = findById(FILL_STYLES, db.fillTexture)
    local perDot = db.dotColors ~= "single"
    local segmentPath = (fill.path and not fill.gradient) and fill.path or WHITE
    for _, segment in ipairs(segments) do
        segment.texture:SetTexture(segmentPath, fill.tiled and "REPEAT" or nil, fill.tiled and "REPEAT" or nil)
        segment.texture:SetHorizTile(fill.tiled or false)
        segment.texture:SetVertTile(fill.tiled or false)
        if not perDot then
            segment.texture:Hide()
            segment.divider:Hide()
        end
    end
    if perDot then fill = FILL_STYLES[1] end -- "none": the segments are the fill
    local scrolling = fill.id == "stripes" and db.scrollStripes and healthBar ~= nil
    if scrolling then
        fillTex:Hide()
        scrollingStripes:ClearAllPoints()
        scrollingStripes:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -STRIPE_SCROLL_PERIOD * 2, 0)
        scrollingStripes:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT")
        scrollingStripes:SetVertexColor(colorOf(db.fillColor, db.fillOpacity))
        scrollingStripes:Show()
        stripeScroll:Play()
    else
        stripeScroll:Stop()
        scrollingStripes:Hide()
    end
    if fill.path and not scrolling then
        local r, g, b, a = colorOf(db.fillColor, db.fillOpacity)
        fillTex:SetTexture(fill.path, fill.tiled and "REPEAT" or nil, fill.tiled and "REPEAT" or nil)
        fillTex:SetHorizTile(fill.tiled or false)
        fillTex:SetVertTile(fill.tiled or false)
        if fill.gradient and CreateColor then
            fillTex:SetVertexColor(1, 1, 1, 1)
            -- Solid at the leading edge, whichever way the marker runs.
            fillTex:SetGradient("HORIZONTAL", CreateColor(r, g, b, reverse and a or 0), CreateColor(r, g, b, reverse and 0 or a))
        elseif fill.raw then
            fillTex:SetVertexColor(1, 1, 1, a) -- a texture with colours of its own
        else
            fillTex:SetVertexColor(r, g, b, a)
        end
        fillTex:Show()
    else
        fillTex:Hide()
    end

    -- Outline
    local r, g, b, a = colorOf(db.outlineColor, db.outlineOpacity)
    for _, edge in ipairs(edges) do
        local texture = edge.texture
        if db.outlineStyle == "dashed" then
            local file = (edge.horizontal and "DashH" or "DashV") .. db.dashLength
            texture:SetTexture(TEXTURE_DIR .. file, "REPEAT", "REPEAT")
            texture:SetHorizTile(edge.horizontal)
            texture:SetVertTile(not edge.horizontal)
        else
            texture:SetTexture(WHITE)
            texture:SetHorizTile(false)
            texture:SetVertTile(false)
        end
        texture:SetVertexColor(r, g, b, a)
        if edge.horizontal then
            texture:SetHeight(db.outlineThickness)
        else
            texture:SetWidth(db.outlineThickness)
        end
        texture:SetShown(db.outlineStyle ~= "none")
    end
    if db.pulseOutline then outlinePulse:Play() else outlinePulse:Stop() end

    -- Glow (outline color, fading outward)
    local glowAlpha = a * 0.7
    for _, glow in ipairs(glows) do
        local texture = glow.texture
        local inner, outer = CreateColor(r, g, b, glowAlpha), CreateColor(r, g, b, 0)
        if glow.side == "top" then
            texture:SetHeight(db.glowSize)
            texture:SetGradient("VERTICAL", inner, outer)
        elseif glow.side == "bottom" then
            texture:SetHeight(db.glowSize)
            texture:SetGradient("VERTICAL", outer, inner)
        elseif glow.side == "left" then
            texture:SetWidth(db.glowSize)
            texture:SetGradient("HORIZONTAL", outer, inner)
        else
            texture:SetWidth(db.glowSize)
            texture:SetGradient("HORIZONTAL", inner, outer)
        end
        texture:SetShown(db.showGlow and db.outlineStyle ~= "none")
    end

    -- Spark (outline color, brightened)
    spark:SetVertexColor(math.min(1, r + 0.4), math.min(1, g + 0.4), math.min(1, b + 0.4), 1)
    spark:SetShown(db.showSpark)

    -- Shine sweep: starts just left of the bar, crosses it, then waits out the rest of the interval.
    shineSweep:Stop()
    if db.showShine and healthBar then
        shine:ClearAllPoints()
        shine:SetPoint("TOPRIGHT", healthBar, "TOPLEFT")
        shine:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMLEFT")
        shineMove:SetOffset(healthBarWidth() + SHINE_WIDTH, 0)
        shineMove:SetStartDelay(math.max(0, db.shineInterval - SHINE_DURATION))
        shine:Show()
        shineSweep:Play()
    else
        shine:Hide()
    end

    local markersOn = db.showMarkers and db.targetMarkers ~= false
    fillLayer:SetShown(markersOn)
    clipLayer:SetShown(markersOn)
    outlineLayer:SetShown(markersOn)
    sparkLayer:SetShown(markersOn)

    -- Text
    local fontPath = GameFontNormalSmall:GetFont()
    label:SetFont(fontPath, db.labelSize, "OUTLINE")
    label:SetTextColor(colorOf(db.labelColor))
    label:ClearAllPoints()
    if healthBar then
        if db.labelPosition == "center" then
            label:SetPoint("CENTER", healthBar, "CENTER")
        elseif db.labelPosition == "right" then
            label:SetPoint("RIGHT", healthBar, "RIGHT", -4, 0)
        else
            label:SetPoint("RIGHT", healthBar, "LEFT", -6, 0)
        end
    end
    label:SetShown(db.showLabel)
end

-- Smooth motion: the marker glides toward its value instead of jumping on each tick, and grows in from
-- zero when it first appears or switches target. Values are ours (plain), only the scale is secret.
local markerValue, markerShownValue, markerScale = 0, 0, nil

-- Max value (the scale) for the marker and every segment's running-total bar.
local function setMarkerScale(max)
    remainingBar:SetMinMaxValues(0, max)
    for _, segment in ipairs(segments) do segment.bar:SetMinMaxValues(0, max) end
end

-- value: total remaining damage. scale: identifies what's being shown (target, preview); a change grows the
-- marker in from zero. cumulative: running totals per DoT for the segments, or nil when not drawing them
-- (unused segments sit at the total, i.e. zero width).
local function setMarkerValue(value, scale, cumulative)
    local fresh = scale ~= markerScale
    markerScale, markerValue = scale, value
    if not db.smoothMotion then
        markerShownValue = value
    elseif fresh then
        markerShownValue = 0
    end
    remainingBar:SetValue(markerShownValue)
    for i, segment in ipairs(segments) do
        segment.target = cumulative and (cumulative[i] or value) or value
        if not db.smoothMotion then
            segment.shown = segment.target
        elseif fresh then
            segment.shown = 0
        end
        segment.bar:SetValue(segment.shown)
    end
end

local function approach(shown, target, elapsed)
    shown = shown + (target - shown) * math.min(1, elapsed * SMOOTH_RATE)
    if math.abs(target - shown) < math.max(0.05, math.abs(target) * 0.002) then return target end
    return shown
end

local function animateMarker(elapsed)
    if not remainingBar:IsShown() then return end
    if markerShownValue ~= markerValue then
        markerShownValue = approach(markerShownValue, markerValue, elapsed)
        remainingBar:SetValue(markerShownValue)
    end
    for _, segment in ipairs(segments) do
        if segment.shown ~= segment.target then
            segment.shown = approach(segment.shown, segment.target, elapsed)
            segment.bar:SetValue(segment.shown)
        end
    end
end

-- Shows and colors one segment per entry ({ name, school, damage }), or hides them all when entries is nil.
-- Returns the running totals to pass to setMarkerValue.
local function updateSegments(entries)
    local cumulative, running = {}, 0
    local count = entries and math.min(#entries, MAX_SEGMENTS) or 0
    local alpha = db.fillOpacity / 100
    for i, segment in ipairs(segments) do
        local entry = i <= count and entries[i]
        if entry then
            running = running + entry.damage
            cumulative[i] = running
            local color = dotColor(entry)
            segment.texture:SetVertexColor(color[1], color[2], color[3], alpha)
        end
        segment.texture:SetShown(entry and true or false)
        segment.divider:SetShown(entry and db.segmentDividers and i < count or false)
        if segment.refresh then
            segment.refresh:SetShown(entry and entry.refreshDue and db.refreshCue ~= false or false)
        end
    end
    -- More DoTs than segments: the last segment also covers the rest.
    if entries and #entries > MAX_SEGMENTS then
        for i = MAX_SEGMENTS + 1, #entries do running = running + entries[i].damage end
        cumulative[MAX_SEGMENTS] = running
    end
    return entries and cumulative or nil
end

-- "DoTs: Corruption 60 · Immolate 45", each name in its segment's color.
local function breakdownText(entries)
    local parts = {}
    for _, entry in ipairs(entries) do
        local color = dotColor(entry)
        local function byte(v) return math.floor(v * 255 + 0.5) end
        table.insert(parts, string.format("|cff%02x%02x%02x%s %d|r", byte(color[1]), byte(color[2]),
            byte(color[3]), entry.name, math.floor(entry.damage + 0.5)))
    end
    return string.format(BIT.L("DoTs: %s"), table.concat(parts, " · "))
end

local function playFlash()
    if db.flashOnApply and db.showMarkers and db.targetMarkers ~= false and remainingBar:IsShown() then
        flashAnim:Stop()
        flashAnim:Play()
        if db.showSpark then
            sparkPunch:Stop()
            sparkPunch:Play()
        end
    end
end

local function findTargetPortrait()
    if BIT.Plate and BIT.Plate.UnitFrame then return select(3, BIT.Plate.UnitFrame("target")) end
    local tf = TargetFrame
    return (tf and tf.TargetFrameContainer and tf.TargetFrameContainer.Portrait)
        or TargetFramePortrait
        or (tf and tf.portrait)
end

local function findTargetHealthBar()
    if BIT.Plate and BIT.Plate.UnitFrame then return select(2, BIT.Plate.UnitFrame("target")) end
    local tf = TargetFrame
    local main = tf and tf.TargetFrameContent and tf.TargetFrameContent.TargetFrameContentMain
    return (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
        or (main and main.HealthBar)
        or TargetFrameHealthBar
        or (tf and tf.healthbar)
end

local function regionName(region)
    if not region then return "not found" end
    local ok, name = pcall(region.GetDebugName, region)
    return ok and tostring(name) or "found (unnamed)"
end

local function attach()
    local portrait, bar
    if previewHost then
        portrait, bar = previewHost.portrait, previewHost.healthBar
        targetHost = previewHost.layerFrame
    else
        portrait, bar = findTargetPortrait(), findTargetHealthBar()
        if BIT.Plate and BIT.Plate.UnitFrame then targetHost = BIT.Plate.UnitFrame("target")
        else targetHost = TargetFrame end
    end
    skullAnchor = portrait or targetHost or UIParent
    plainSkullFrame:ClearAllPoints()
    plainSkullFrame:SetPoint("BOTTOM", skullWindow, "TOP", 0, 4)

    healthBar = bar
    ns._anchoredBar = nil -- a new bar: anchor the marker again whatever it was
    if ns.anchorMarker then ns.anchorMarker() end
    if ns.applyMarkerParent then ns.applyMarkerParent() end
    appliedSignature = nil -- re-anchor the skull, label and effects against the (new) frames
    trace("ATTACH portrait: " .. regionName(portrait) .. " | health bar: " .. regionName(healthBar))
    return portrait ~= nil
end

local STRATA_RANK = {
    BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}
local LAYER_CHECK_INTERVAL = 1

-- Highest strata/level of the target frame and of what is shown under it. Blizzard (Edit Mode) re-layers the target
-- frame after addons load, so a level picked once at load ends up underneath the health bar and portrait.
-- A hidden frame draws nothing, so it cannot cover our marks, and counting it pulled them out of the target frame's
-- layer: Edit Mode keeps a hidden selection frame (MEDIUM, level 1000) under every Blizzard unit frame whose own art
-- is LOW, and the marker and skull followed it into the strata of the world map, above the map's art. The frame
-- itself always counts, shown or not. (No new file-level local here: this file is at Lua's limit of 200.)
local function targetFrameTopLayer()
    local root = targetHost or healthBar
    -- Hidden custom frames resolve to nil. Never scan the entire UI as a fallback.
    if not root or root == UIParent then return end
    local topStrata, topLevel = "BACKGROUND", 0
    local function visit(frame, depth)
        if BIT.OwnOverlays[frame] then return end
        if depth > 0 then
            -- hidden only when the client says so: an unreadable or secret answer counts as shown
            local okShown, shown = pcall(frame.IsShown, frame)
            if okShown and not isSecret(shown) and shown == false then return end
        end
        local ok, forbidden = pcall(function() return frame.IsForbidden and frame:IsForbidden() end)
        if not ok or isSecret(forbidden) or forbidden then return end
        -- Some of Blizzard's frames report a secret strata/level in Forever; those can't be compared, so skip
        -- them (their children are still visited).
        local readOK, strata, level = pcall(function() return frame:GetFrameStrata(), frame:GetFrameLevel() end)
        if readOK and not isSecret(strata) and not isSecret(level) and type(strata) == "string" and type(level) == "number" then
            local rank, topRank = STRATA_RANK[strata] or 0, STRATA_RANK[topStrata] or 0
            if rank > topRank then
                topStrata, topLevel = strata, level
            elseif rank == topRank and level > topLevel then
                topLevel = level
            end
        end
        if depth < 6 then
            local children = { pcall(frame.GetChildren, frame) }
            if children[1] then
                for i = 2, #children do visit(children[i], depth + 1) end
            end
        end
    end
    visit(root, 0)
    return topStrata, topLevel
end

-- Keeps our marker and skull above everything on the target frame. Checked while displaying (throttled)
-- because Blizzard can re-layer the frame at any time.
local layerCheckedAt, lastStrata, lastLevel, layerErrorLogged = 0, nil, nil, false

-- Where the damage marker hangs: on the health bar itself, as CastPrediction's cast marker does, or, with db.markerParent
-- "screen" (/dotinfo marker screen), on UIParent, anchored to the bar. On the Forever client a marker on UIParent was
-- never drawn on the target frame although it was shown, sized and levelled right (seen in game 2026-11-14, shown at once
-- when hung on the bar), and the nameplate marks, which hang on their plate, draw. Reparenting is not possible in combat,
-- so it waits for the end of it; the options preview always uses the screen (its mock bar is not the target's). A field
-- on ns: the file's local limit.
function ns.applyMarkerParent()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return end
    local want = (not previewHost and db.markerParent ~= "screen" and healthBar) or UIParent
    -- remembered rather than asked of the client: the marker was created on UIParent and nothing else moves it
    if ns._markerParented == nil then ns._markerParented = UIParent end
    if ns._markerParented ~= want and pcall(remainingBar.SetParent, remainingBar, want) then
        ns._markerParented = want
        layerCheckedAt = 0 -- the new parent may bring its own level: place the marker again at once
        trace("PARENT the marker now hangs on " .. (want == UIParent and "the screen" or "the health bar"))
    end
end

-- Anchors the marker over the health bar the player sees: the HealthBar frame itself, or, where that is taller (Blizzard's
-- Camelot frames: 3 above and 2 below its container), the container's top and bottom, so the outline and glow do not
-- stick out. Looked at again every second (the frame may not have been laid out when it was first attached), and only
-- touched when the answer changed.
function ns.anchorMarker()
    if not healthBar then return end
    local top, bottom = 0, 0
    if not previewHost and BIT.Plate and BIT.Plate.BarInset then top, bottom = BIT.Plate.BarInset(healthBar) end
    if ns._anchoredBar == healthBar and ns._anchoredTop == top and ns._anchoredBottom == bottom then return end
    ns._anchoredBar, ns._anchoredTop, ns._anchoredBottom = healthBar, top, bottom
    remainingBar:ClearAllPoints()
    if top == 0 and bottom == 0 then
        remainingBar:SetAllPoints(healthBar)
    else
        remainingBar:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, -top)
        remainingBar:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, bottom)
    end
end

local function updateLayering(now)
    if now - layerCheckedAt < LAYER_CHECK_INTERVAL then return end
    layerCheckedAt = now
    ns.applyMarkerParent()
    ns.anchorMarker()
    local ok, strata, level
    if previewHost then
        -- One strata above the options window: it's a top-level frame, which WoW raises above everything else
        -- in its own strata (our frames included) when it's shown or clicked. Dropdowns and tooltips sit higher.
        ok, strata, level = true, "FULLSCREEN", 1
    else
        local t0 = BIT.Perf and BIT.Perf.Begin()
        ok, strata, level = pcall(targetFrameTopLayer)
        if BIT.Perf then BIT.Perf.End("DoTInfo layer scan", t0) end
    end
    if not ok then
        if not layerErrorLogged then
            layerErrorLogged = true
            trace("LAYER check failed (logged once): " .. tostring(strata))
        end
        return
    end
    if not strata then
        -- Nothing to scan yet (the custom frame is hidden): look again soon, not after a full second.
        layerCheckedAt = now - LAYER_CHECK_INTERVAL * 0.75
        return
    end
    -- CastPrediction's frames sit on the same bar and are left out of the scan (BIT.OwnOverlays), at up to 7 above the top
    -- it found: ours go above them, as they did when each saw the other's frames.
    for i, frame in ipairs({ remainingBar, fillLayer, clipLayer, outlineLayer, sparkLayer, skullWindow, skullBar }) do
        frame:SetFrameStrata(strata)
        frame:SetFrameLevel(level + 8 + i)
    end
    if strata ~= lastStrata or level ~= lastLevel then
        lastStrata, lastLevel = strata, level
        trace(string.format("LAYER target frame top is %s/%d; marker and skull placed above it", strata, level))
    end
end

local function hideMarkers()
    remainingBar:Hide()
    if ns.Retail and ns.Retail.UpdatePoisonOffset then ns.Retail.UpdatePoisonOffset(TargetFrame) end
    fillLayer.refreshMark:Hide()
    markerScale = nil -- grow in again next time it appears
end

local function hideAll()
    skullWindow:Hide()
    hideMarkers()
end

-- The label lives on the marker bar, so the bar stays up if either is wanted.
local function showMarkers()
    if (db.showMarkers and db.targetMarkers ~= false) or db.showLabel then
        remainingBar:Show()
    else
        hideMarkers()
    end
end

local function rectOf(region)
    if not region then return "nil" end
    local ok, left, bottom, width, height = pcall(region.GetRect, region)
    if not ok then return "error" end
    if left == nil then return "no rect" end
    if isSecret(left) or isSecret(width) then return "secret" end
    return string.format("%.0f,%.0f %.0fx%.0f", left, bottom, width, height)
end

local function describeFrame(frame)
    local ok, strata, level, visible = pcall(function()
        return frame:GetFrameStrata(), frame:GetFrameLevel(), frame:IsVisible()
    end)
    if not ok then return "error" end
    return string.format("%s %s/%d visible=%s", rectOf(frame), tostring(strata), level, tostring(visible))
end

local function traceSkullGeometry()
    local portrait = findTargetPortrait()
    trace("SKULLTEST portrait " .. rectOf(portrait) .. " | TargetFrame " .. (TargetFrame and describeFrame(TargetFrame) or "nil"))
    local clipsOK, clips = pcall(skullWindow.DoesClipChildren, skullWindow)
    trace("SKULLTEST window " .. describeFrame(skullWindow) .. " clips=" .. (clipsOK and tostring(clips) or "unknown"))
    trace("SKULLTEST bar " .. describeFrame(skullBar) .. " fill " .. rectOf(skullBar:GetStatusBarTexture()))
    trace("SKULLTEST skull " .. rectOf(skull) .. " visible=" .. tostring(skull:IsVisible()) .. " texture=" .. tostring(skull:GetTexture()))
    trace("SKULLTEST plain " .. describeFrame(plainSkullFrame) .. " texture=" .. tostring(plainSkull:GetTexture()))
end

-- /dotinfo marker: where the damage marker really is, set beside the health bar it follows and the cast marker (which
-- is known to draw there). Printed and logged. A field on ns: this file is at Lua's limit of 200 locals.
function ns.traceMarker()
    local function say(text)
        trace("MARKER " .. text)
        if not db.debug then print("DoTInfo marker: " .. text) end -- with /dotinfo debug on, the trace is already echoed
    end
    local function call(object, method, ...)
        if type(object) ~= "table" or type(object[method]) ~= "function" then return "n/a" end
        local packed = { pcall(object[method], object, ...) }
        if not packed[1] then return "error" end
        local out = {}
        for i = 2, math.max(2, #packed) do
            local v = packed[i]
            out[#out + 1] = isSecret(v) and "secret" or (type(v) == "number" and string.format("%.2f", v) or tostring(v))
        end
        return table.concat(out, " ")
    end
    local function frameLine(frame)
        return describeFrame(frame) .. " | alpha " .. call(frame, "GetEffectiveAlpha") .. " scale " .. call(frame, "GetEffectiveScale")
    end
    local reversed = BIT.Plate and BIT.Plate.FillsReversed and healthBar and BIT.Plate.FillsReversed(healthBar)
    say("settings: markers " .. tostring(db.showMarkers) .. ", target " .. tostring(db.targetMarkers) .. ", colors "
        .. tostring(db.dotColors) .. ", direction " .. tostring(db.fillDirection) .. ", follows reverse fill "
        .. tostring(reversed) .. ", target " .. tostring(UnitExists("target")))
    say("health bar: " .. (healthBar and (regionName(healthBar) .. " " .. frameLine(healthBar)) or "none"))
    say("marker: " .. frameLine(remainingBar) .. " | parent " .. call(remainingBar:GetParent(), "GetDebugName")
        .. " | range " .. call(remainingBar, "GetMinMaxValues") .. " value " .. call(remainingBar, "GetValue")
        .. " | fill " .. rectOf(span))
    say("marker layers: fill " .. describeFrame(fillLayer) .. " | clip " .. describeFrame(clipLayer)
        .. " | outline " .. describeFrame(outlineLayer))
    local shownSegments = 0
    for i, segment in ipairs(segments) do
        if segment.texture:IsShown() then
            shownSegments = shownSegments + 1
            say(string.format("segment %d: %s visible=%s color %s texture %s", i, rectOf(segment.texture),
                tostring(segment.texture:IsVisible()), call(segment.texture, "GetVertexColor"),
                tostring(segment.texture:GetTexture())))
        end
    end
    say(string.format("ours: damage %s, shown %s, segments shown %d, marker shown %s", tostring(markerValue),
        tostring(markerShownValue), shownSegments, tostring(remainingBar:IsShown())))
    local cast = _G.Ready2QuestCombat_CastPredictionMarker
    say("cast marker: " .. (cast and (frameLine(cast) .. " | parent " .. call(cast:GetParent(), "GetDebugName")) or "none"))
end

local function targetIsDead()
    local ok, dead = pcall(UnitIsDead, "target")
    return ok and not isSecret(dead) and dead
end

local updateErrorShown = false
local lastTracedDamage
local function refresh()
    local function anyRefreshDue(entries)
        if not entries or not db or db.refreshCue == false then return false end
        for _, entry in ipairs(entries) do
            if entry.refreshDue then return true end
        end
        return false
    end
    local now = GetTime()
    if not previewHost and BIT.Plate and BIT.Plate.UnitFrame then
        local host, bar, portrait = BIT.Plate.UnitFrame("target")
        if host ~= targetHost or bar ~= healthBar or (portrait or host or UIParent) ~= skullAnchor then attach() end
    end
    if ns.RogueEffects then ns.RogueEffects.Refresh(unitKey) end
    housekeep(now)
    updateLayering(now)
    applyAppearance()

    if skullTestUntil and now < skullTestUntil then
        skullBar:SetMinMaxValues(0, 1)
        skullBar:SetValue(1)
        skullWindow:Show()
        plainSkullFrame:Show()
        return
    end
    plainSkullFrame:Hide()

    -- Options window preview: the real widgets, attached to its mock target frame, fed its plain numbers.
    -- Same code path as combat, so what you tune there is exactly what you get.
    if previewHost and previewState then
        local entries, total = {}, 0
        for _, dot in ipairs(previewState.dots) do
            if dot.damage > 0 then
                table.insert(entries, dot)
                total = total + dot.damage
            end
        end
        if total <= 0 or (previewState.health or 1) <= 0 then return hideAll() end
        -- UI-4: a dead mock shows "Target died", not a kill skull on a corpse.
        skullBar:SetMinMaxValues(0, math.max(previewState.health, 0.01))
        skullBar:SetValue(ns.lethalDamage(entries))
        -- the sample swing is 8% of the mock mob's health
        if ns.swing then ns.SwingIcon.Draw(ns.swing, math.max(previewState.health, 0.01), ns.lethalDamage(entries) + (db.swingKill and 8 or 0)) end
        skullWindow:SetShown(db.showSkull)
        setMarkerScale(100)
        local perDot = db.dotColors ~= "single"
        setMarkerValue(total, "preview", updateSegments(perDot and entries or nil))
        fillLayer.refreshMark:SetShown((not perDot) and anyRefreshDue(entries))
        label:SetText(perDot and breakdownText(entries)
            or string.format(BIT.L("DoTs: %d"), math.floor(total + 0.5)))
        showMarkers()
        return
    end

    if not UnitExists("target") or targetIsDead() or (not targetHost and not healthBar) then return hideAll() end
    local damage, count, breakdown = targetRemainingDamage()
    if damage ~= lastTracedDamage then
        lastTracedDamage = damage
        trace(string.format("ESTIMATE %d remaining from %d DoT(s)", damage, count))
    end
    if count == 0 then return hideAll() end

    local perDot = db.dotColors ~= "single"
    local ok, err = pcall(function()
        skullBar:SetMinMaxValues(0, UnitHealth("target"))
        skullBar:SetValue(ns.lethalDamage(breakdown))
        if ns.swing then ns.SwingIcon.Draw(ns.swing, UnitHealth("target"), ns.lethalDamage(breakdown, true)) end
        if healthBar then
            setMarkerScale(UnitHealthMax("target"))
            setMarkerValue(damage, unitKey("target"), updateSegments(perDot and breakdown or nil))
            fillLayer.refreshMark:SetShown((not perDot) and anyRefreshDue(breakdown))
        end
    end)
    if not ok then
        if not updateErrorShown then
            updateErrorShown = true
            trace("ERROR in marker update: " .. tostring(err))
            print("Display update failed: " .. tostring(err))
        end
        return hideAll()
    end

    skullWindow:SetShown(db.showSkull and not ns.shielded("target", breakdown))
    if healthBar then
        label:SetText(perDot and breakdownText(breakdown) or string.format(BIT.L("DoTs: %d"), damage))
        showMarkers()
    else
        hideMarkers()
    end
end

-- Runs refresh and reports a Lua error once (log and chat) instead of failing silently every 0.1s: WoW hides
-- Lua errors by default, so a broken display would otherwise just not draw.
local reportedErrors = {}
local function safeRefresh()
    -- Native aura containers render their own protected timers; keep an unavailable host
    -- or API from interrupting the separate cast-based damage estimate.
    if ns.Retail and ns.Retail.UpdateRogueAuras then
        local ok, err = pcall(ns.Retail.UpdateRogueAuras)
        if not ok and not reportedErrors[err] then
            reportedErrors[err] = true
            trace("ERROR in rogue aura update: " .. tostring(err))
            print("Aura display error (logged): " .. tostring(err))
        end
    end
    local ok, err = pcall(refresh)
    if not ok and not reportedErrors[err] then
        reportedErrors[err] = true
        trace("ERROR in display update: " .. tostring(err))
        print("Display error (logged): " .. tostring(err))
    end
    -- API.lua: tells other addons which units' numbers changed.
    if ns.afterRefresh then
        local apiOk, apiErr = pcall(ns.afterRefresh)
        if not apiOk and not reportedErrors[apiErr] then
            reportedErrors[apiErr] = true
            trace("ERROR in API update: " .. tostring(apiErr))
        end
    end
    if ns.Retail and ns.Retail.UpdatePoisonOffset then ns.Retail.UpdatePoisonOffset(TargetFrame) end
end

---------------------------------------------------------------------------
-- Settings, and what the options window (Options.lua) needs
---------------------------------------------------------------------------

local function applyDefaults()
    -- Settings from earlier versions.
    if db.dotColors == "school" then db.dotColors = "each" end
    if db.plateDotColors == "school" then db.plateDotColors = "each" end
    if db.showMarkers == nil and db.showLine ~= nil then db.showMarkers = db.showLine end
    db.showLine, db.showRemaining = nil, nil
    db.showFullLine, db.lineThickness, db.lineColor = nil, nil, nil
    db.preview, db.previewPercent, db.previewOffInCombat = nil, nil, nil
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    -- Defaults changed in 0.9.128: "Count one weapon hit" is on and the nameplate DoT colors are Rainbow. A saved value
    -- that is still what the old defaults gave (or, for the colors, the other mode the presets wrote) follows them once.
    if (db.defaultsRev or 0) < 1 then
        if db.swingKill == false then db.swingKill = true end
        if db.plateDotColors == "single" or db.plateDotColors == "each" then db.plateDotColors = "rainbow" end
        db.defaultsRev = 1
    end
end

-- Saved defaults only. Enable on a switched-off module calls this so the settings page
-- can build; events, the target attach and the options registration stay on ADDON_LOADED.
-- The learned tick sizes belong to the character: gear, level and talents differ from one character to the next (and a
-- deleted character's numbers are nobody's), so they used to teach each character the sizes of whoever was played last.
-- They live in db.chars[player GUID] = { ticks, weights, seen }; db.ticks and db.tickWeights point at the current
-- character's tables, which is what the rest of the code reads (the alias is saved twice and rebuilt on every load). Only
-- the 12 characters played most recently are kept (a file-level local more would break the 200-local limit of this file).
-- Returns whether the player's GUID could be read yet.
function ns.bindTicks()
    local maxCharacters = 12
    local ok, guid = pcall(UnitGUID, "player")
    if not ok or isSecret(guid) or type(guid) ~= "string" or guid == "" then
        db.ticks = type(db.ticks) == "table" and db.ticks or {}
        db.tickWeights = type(db.tickWeights) == "table" and db.tickWeights or {}
        return false
    end
    if type(db.chars) ~= "table" then db.chars = {} end
    local mine = db.chars[guid]
    if type(mine) ~= "table" then
        mine = {}
        db.chars[guid] = mine
    end
    if type(mine.ticks) ~= "table" then mine.ticks = {} end
    if type(mine.weights) ~= "table" then mine.weights = {} end
    mine.seen = type(time) == "function" and time() or 0
    db.ticks, db.tickWeights = mine.ticks, mine.weights
    local count = 0
    for other, entry in pairs(db.chars) do
        if type(other) ~= "string" or type(entry) ~= "table" then db.chars[other] = nil else count = count + 1 end
    end
    while count > maxCharacters do
        local oldest, oldestSeen
        for other, entry in pairs(db.chars) do
            local seen = tonumber(entry.seen) or 0
            if other ~= guid and (not oldest or seen < oldestSeen) then oldest, oldestSeen = other, seen end
        end
        if not oldest then break end
        db.chars[oldest] = nil
        count = count - 1
    end
    return true
end

function ns.ensureDB()
    Ready2QuestCombat_DoTInfoDB = Ready2QuestCombat_DoTInfoDB or {}
    db = Ready2QuestCombat_DoTInfoDB
    if db.version ~= DB_VERSION then
        db.ticks, db.tickWeights, db.intervals, db.chars, db.version = nil, nil, nil, nil, DB_VERSION
    end
    ns.bindTicks()
    db.auras = db.auras or {} -- spell names whose debuff has been read on a mob (ns._verifyAuras)
    db.log = db.log or {}
    applyDefaults()
    ns.db = db
end
if BIT.RegisterWaker then BIT.RegisterWaker("DoTInfo", ns.ensureDB) end

-- ns.db is set on ADDON_LOADED.
ns.DEFAULTS = DEFAULTS
ns.lists = {
    colors = COLOR_PRESETS, icons = SKULL_ICONS, fills = FILL_STYLES, outlines = OUTLINE_STYLES,
    dashLengths = DASH_LENGTHS, labelPositions = LABEL_POSITIONS, dotColors = DOT_COLOR_MODES, waitModes = WAIT_MODES,
}
ns.refresh = safeRefresh
ns.playFlash = playFlash
ns.dotColor = dotColor
ns.colorOf = colorOf
ns.findById = findById
ns.textureDir = TEXTURE_DIR

-- Plain display amounts only; native poison uses them as its starting point on the HP scale.
function ns.nativePoisonBase(unit, parent, bar)
    if unit == "target" then
        return not previewHost and healthBar == bar and remainingBar:IsShown() and markerShownValue or 0
    end
    return ns.nameplateDamageBase and ns.nameplateDamageBase(parent, bar) or 0
end

-- Configure before the native aura factory restricts this segment and its descendants.
function ns.stylePoisonSegment(timer, health, config)
    local style = findById(FILL_STYLES, config.fillTexture)
    local perDot = config.dotColors ~= "single"
    local color = perDot and dotColor({ name = config.name, school = 8 }, config.dotColors) or nil
    local r, g, b, a = colorOf(config.fillColor, config.fillOpacity)
    if color then r, g, b = color[1], color[2], color[3] end
    local poisonSpan = timer:GetStatusBarTexture()
    timer:SetStatusBarColor(0, 0, 0, 0)
    local texture = timer:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", poisonSpan, "TOPLEFT")
    texture:SetPoint("BOTTOMRIGHT", poisonSpan, "BOTTOMRIGHT")
    texture:SetTexture((style.path and not style.gradient) and style.path or WHITE,
        style.tiled and "REPEAT" or nil, style.tiled and "REPEAT" or nil)
    texture:SetHorizTile(style.tiled or false)
    texture:SetVertTile(style.tiled or false)
    if style.raw and not perDot then
        texture:SetVertexColor(1, 1, 1, a) -- a texture with colours of its own: only the opacity applies
    else
        texture:SetVertexColor(r, g, b, a)
    end
    if style.gradient and not perDot and not config.onPlate and CreateColor then
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, a))
    end
    texture:SetShown(perDot or (style.path ~= nil and (not config.onPlate or not style.gradient)))
    if perDot and config.segmentDividers then
        local divider = timer:CreateTexture(nil, "OVERLAY")
        divider:SetColorTexture(0, 0, 0, 0.85)
        divider:SetWidth(1)
        divider:SetPoint("TOP", poisonSpan, "TOPLEFT")
        divider:SetPoint("BOTTOM", poisonSpan, "BOTTOMLEFT")
    end
    local outline = CreateFrame("Frame", nil, timer, "DisableUntrustedLayoutScriptsTemplate")
    outline:SetAllPoints(timer)
    local or_, og, ob, oa = colorOf(config.outlineColor, config.outlineOpacity)
    for _, points in ipairs({ { true, "TOPLEFT", "TOPRIGHT" }, { true, "BOTTOMLEFT", "BOTTOMRIGHT" },
        { false, "TOPLEFT", "BOTTOMLEFT" }, { false, "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = outline:CreateTexture(nil, "OVERLAY")
        edge:SetPoint(points[2], poisonSpan, points[2])
        edge:SetPoint(points[3], poisonSpan, points[3])
        if config.outlineStyle == "dashed" then
            edge:SetTexture(TEXTURE_DIR .. (points[1] and "DashH" or "DashV") .. config.dashLength, "REPEAT", "REPEAT")
            edge:SetHorizTile(points[1])
            edge:SetVertTile(not points[1])
        else edge:SetTexture(WHITE) end
        if points[1] then edge:SetHeight(config.outlineThickness) else edge:SetWidth(config.outlineThickness) end
        edge:SetVertexColor(or_, og, ob, oa)
        edge:SetShown(config.outlineStyle ~= "none")
    end
    if config.pulseOutline then
        local pulse = outline:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local alpha = pulse:CreateAnimation("Alpha")
        alpha:SetFromAlpha(1); alpha:SetToAlpha(0.3); alpha:SetDuration(0.9); alpha:SetSmoothing("IN_OUT")
        pulse:Play()
    end
    if config.showGlow and config.outlineStyle ~= "none" and CreateColor then
        local inner, outer = CreateColor(or_, og, ob, oa * 0.7), CreateColor(or_, og, ob, 0)
        for _, side in ipairs({ "top", "bottom", "left", "right" }) do
            local glow = outline:CreateTexture(nil, "BORDER")
            glow:SetTexture(WHITE); glow:SetBlendMode("ADD")
            if side == "top" or side == "bottom" then
                local own, relative = side == "top" and "BOTTOM" or "TOP", side == "top" and "TOP" or "BOTTOM"
                glow:SetPoint(own .. "LEFT", poisonSpan, relative .. "LEFT")
                glow:SetPoint(own .. "RIGHT", poisonSpan, relative .. "RIGHT")
                glow:SetHeight(config.glowSize)
                glow:SetGradient("VERTICAL", side == "top" and inner or outer, side == "top" and outer or inner)
            else
                local own, relative = side == "left" and "RIGHT" or "LEFT", side == "left" and "LEFT" or "RIGHT"
                glow:SetPoint("TOP" .. own, poisonSpan, "TOP" .. relative)
                glow:SetPoint("BOTTOM" .. own, poisonSpan, "BOTTOM" .. relative)
                glow:SetWidth(config.glowSize)
                glow:SetGradient("HORIZONTAL", side == "left" and outer or inner, side == "left" and inner or outer)
            end
        end
    end
    if config.showShine or (style.id == "stripes" and config.scrollStripes and not perDot) then
        local clip = CreateFrame("Frame", nil, timer, "DisableUntrustedLayoutScriptsTemplate")
        clip:SetPoint("TOPLEFT", poisonSpan, "TOPLEFT"); clip:SetPoint("BOTTOMRIGHT", poisonSpan, "BOTTOMRIGHT")
        clip:SetClipsChildren(true)
        local ok, width = pcall(health.GetWidth, health)
        if not ok or isSecret(width) or type(width) ~= "number" or not (width > 0 and width < math.huge) then width = 150 end
        if style.id == "stripes" and config.scrollStripes and not perDot then
            texture:Hide()
            local stripes = clip:CreateTexture(nil, "ARTWORK")
            stripes:SetTexture(style.path, "REPEAT", "REPEAT"); stripes:SetHorizTile(true); stripes:SetVertTile(true)
            stripes:SetPoint("TOPLEFT", timer, "TOPLEFT", -16, 0); stripes:SetPoint("BOTTOMRIGHT", timer, "BOTTOMRIGHT")
            stripes:SetVertexColor(r, g, b, a)
            local scroll = stripes:CreateAnimationGroup(); scroll:SetLooping("REPEAT")
            local move = scroll:CreateAnimation("Translation"); move:SetOffset(8, 0); move:SetDuration(0.6)
            scroll:Play()
        end
        if config.showShine then
            local shine = clip:CreateTexture(nil, "OVERLAY")
            shine:SetTexture(TEXTURE_DIR .. "Shine"); shine:SetBlendMode("ADD"); shine:SetWidth(36)
            shine:SetPoint("TOPRIGHT", timer, "TOPLEFT"); shine:SetPoint("BOTTOMRIGHT", timer, "BOTTOMLEFT")
            local sweep = shine:CreateAnimationGroup(); sweep:SetLooping("REPEAT")
            local move = sweep:CreateAnimation("Translation"); move:SetOffset(width + 36, 0)
            move:SetDuration(0.9); move:SetSmoothing("IN_OUT"); move:SetStartDelay(math.max(0, config.shineInterval - 0.9))
            sweep:Play()
        end
    end
end

-- The DoTs on the mob behind `unit` (e.g. "nameplate3"): per-DoT breakdown and total remaining damage.
function ns.dotBreakdownForUnit(unit)
    local list = dotBreakdown(unitKey(unit))
    local total = 0
    for _, entry in ipairs(list) do total = total + entry.damage end
    return list, total
end

-- True when this unit is actually drawing a DoT fill. Shields ask before covering it.
-- A tracked DoT with nothing left, a hidden marker, or a player/party frame is not a fill.
-- The focus frame has one too (Focus.lua) unless its mode is off.
function ns.HasMarker(unit)
    if not db or type(unit) ~= "string" or db.showMarkers == false then return false end
    local onPlate = unit:match("^nameplate%d+$") ~= nil
    if unit ~= "target" and unit ~= "focus" and not onPlate then return false end
    if unit == "target" and db.targetMarkers == false then return false end
    if unit == "focus" and db.focusMode == "off" then return false end
    if onPlate and db.nameplateMode == "off" then return false end
    if type(UnitIsDeadOrGhost) == "function" then
        local ok, dead = pcall(UnitIsDeadOrGhost, unit)
        if ok and not isSecret(dead) and dead == true then return false end
    end
    local list = dotBreakdown(unitKey(unit))
    if type(list) ~= "table" then return false end
    local total = 0
    for _, entry in ipairs(list) do total = total + (tonumber(entry.damage) or 0) end
    return total > 0
end
ns.print = print
ns.trace = trace

-- A running DoT that has not ticked yet keeps the size it was applied with (expectedTick). When the store is
-- reset, forgotten or healed, that snapshot is as wrong as the store was: drop it so the DoT follows the store
-- again. key nil = every DoT.
function ns.dropSnapshots(key)
    for _, dots in pairs(dotsByTarget) do
        for _, dot in pairs(dots) do
            if dot.normalTicks == 0 and (key == nil or dot.tickKey == key) then dot.learnedAtApply = nil end
        end
    end
end

function ns.resetLearnedTicks()
    wipe(db.ticks)
    if db.tickWeights then wipe(db.tickWeights) end
    ns.dropSnapshots()
    print(BIT.L("Learned tick sizes cleared."))
end

function ns.forgetLearnedTick(key)
    db.ticks[key] = nil
    if db.tickWeights then db.tickWeights[key] = nil end
    ns.dropSnapshots(key)
    trace("FORGET learned tick size for " .. tostring(key))
end

-- The learned tick sizes viewer's list (TickViewer.lua): per entry its key in db.ticks, spellID, comboPoints
-- (finishers, whose keys are "spellIDxN"), perTick, and when the client has them the spell's name and what its
-- description predicts (tooltipPerTick, ticks, interval, duration, school). Shaped DoTs (Agony) learn their
-- average tick. Sorted by name, then combo points. From Does It Die v0.7.0 (MIT).
function ns.learnedTickList()
    local list = {}
    for key, perTick in pairs(db.ticks) do
        local spellID, points = key, nil
        if type(key) == "string" then
            local id, n = key:match("^(%d+)x(%d+)$")
            spellID, points = tonumber(id), tonumber(n)
        end
        if type(spellID) == "number" and type(perTick) == "number" then
            local entry = { key = key, spellID = spellID, comboPoints = points, perTick = perTick }
            local ok, name, desc = pcall(spellNameAndDescription, spellID)
            if ok and type(name) == "string" and not isSecret(name) then entry.name = name end
            if ok and entry.name and type(desc) == "string" and not isSecret(desc) then
                local total, school, duration, stated = parseDot(desc, points or 1)
                if total then
                    local interval = stated or KNOWN_TICK_INTERVALS[entry.name] or DEFAULT_TICK_INTERVAL
                    entry.ticks = math.max(1, math.floor(duration / interval + 0.5))
                    entry.interval, entry.duration = interval, duration
                    entry.school = SCHOOL_BY_NAME[entry.name] or school
                    entry.tooltipPerTick = total / entry.ticks
                end
            end
            entry.color = entry.school and SCHOOL_COLORS[entry.school]
            table.insert(list, entry)
        end
    end
    table.sort(list, function(a, b)
        local an, bn = a.name or ("~" .. a.spellID), b.name or ("~" .. b.spellID)
        if an ~= bn then return an < bn end
        return (a.comboPoints or 0) < (b.comboPoints or 0)
    end)
    return list
end

-- host: { healthBar, portrait, layerFrame } to draw on the options window's mock target frame, or nil to go
-- back to the real target frame.
function ns.setDisplayHost(host)
    trace(host and "PREVIEW on: drawing on the options window" or "PREVIEW off: back on the target frame")
    previewHost = host
    layerCheckedAt = 0
    attach()
    safeRefresh()
    if host then
        -- Where things ended up on screen, once layout has settled (for diagnosing an invisible preview).
        C_Timer.After(0.5, function()
            if previewHost ~= host then return end
            trace("PREVIEW geometry: health bar " .. rectOf(host.healthBar) .. " | marker " .. describeFrame(remainingBar)
                .. " | icon " .. describeFrame(skullWindow) .. " | window " .. describeFrame(host.layerFrame))
        end)
    end
end

-- state: { health = 0-100, dots = { { name, school, damage }, ... } } (damage in % of max health), or nil.
function ns.setPreviewState(state)
    previewState = state
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")   -- combo points, before a finisher spends them
-- Estimate during casting: DoTs with a cast time show from the cast's start until it ends.
frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")   -- keeps a recent combo point reading as backup
frame:RegisterEvent("UNIT_COMBAT")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- Plate tokens stand in for secret GUIDs (Forever's instances, see ns._plateTokenFor), and Retail keys by plate.
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
-- Never register COMBAT_LOG_EVENT_UNFILTERED: Forever forbids it and shows a "blocked" popup.

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        -- switched off in Ready2QuestCombat: silent
        if BIT.ShouldRun and not BIT.ShouldRun("DoTInfo") then
            ns.off = true
            self:UnregisterAllEvents()
            self:SetScript("OnUpdate", nil)
            return
        end
        ns.ensureDB()
        trace("===== session start =====")
        if ns.Retail and ns.Retail.StartRogueAuras then ns.Retail.StartRogueAuras() end
        if ns.RogueEffects then ns.RogueEffects.Start(unitKey) end
        local added = ns.locale.addClientNames(NAME_TABLES, function(spellID)
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
            if name and not isSecret(name) and type(name) == "string" then return name end
        end)
        if #added > 0 then trace("NAMES from this client: " .. table.concat(added, ", ")) end
        local ok, err = true, nil
        if not BIT.RegisterTab then ok, err = pcall(ns.registerOptions) end
        if not ok then
            trace("Options panel registration failed: " .. tostring(err))
            print(BIT.L("Couldn't create the options panel; slash commands still work (/dotinfo help)."))
        end
        if not attach() then print(BIT.L("Target portrait not found; kill icon shown beside the target frame.")) end
        -- the weapon icon, lit by the DoTs plus one swing where the skull is lit by the DoTs alone (SwingIcon.lua)
        if ns.SwingIcon then ns.swing = ns.SwingIcon.New(skullWindow, skullBar) end
        self:UnregisterEvent("ADDON_LOADED")

    elseif not db then
        return

    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.bindTicks() -- the player's GUID may not have been readable when the addon loaded
        wipe(dotsByTarget)
        if ns._absorbedAt then wipe(ns._absorbedAt) end
        if ns.ProcDots then ns.ProcDots.Reset() end
        pendingCast, comboAtSend = nil, nil
        forgetPendingOutcomes()
        resetComboCount()
        dropCastInProgress("loading screen")
        if ns.Retail then
            wipe(ns._retailPending)
            ns.Retail.Reset()
            ns.Retail.SeedPlates()
        end
        safeRefresh()

    elseif ns.Retail and (event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED") then
        if ns.apiIdentityChanged then ns.apiIdentityChanged(...) end
        local old
        if event == "NAME_PLATE_UNIT_ADDED" then old = ns.Retail.AddPlate(...)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then old = ns.Retail.RemovePlate(...)
        end
        if old then
            dotsByTarget[old] = nil
            ns._forgetRecipient(old)
            if castInProgress and castInProgress.key == old then dropCastInProgress("nameplate removed") end
        end
        safeRefresh()

    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        if ns.apiIdentityChanged then ns.apiIdentityChanged(...) end
        -- Forever: a plate token goes to the next mob that gets a plate, so DoTs keyed by it ("plate:nameplateN",
        -- used while mob GUIDs are secret) belonged to the mob it showed before.
        local token = ...
        local old = type(token) == "string" and not isSecret(token) and ("plate:" .. token) or nil
        if old and ns._absorbedAt then ns._absorbedAt[old] = nil end
        if old and (dotsByTarget[old] or (pendingCast and pendingCast.key == old)
            or (castInProgress and castInProgress.key == old)) then
            trace("PLATE " .. token .. (event == "NAME_PLATE_UNIT_REMOVED" and " removed" or " reused")
                .. ": its DoTs were for the mob it showed before")
            dotsByTarget[old] = nil
            ns._forgetRecipient(old)
            if castInProgress and castInProgress.key == old then dropCastInProgress("nameplate removed") end
            safeRefresh()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if ns.apiIdentityChanged then ns.apiIdentityChanged("target") end
        if ns.Retail then
            local old = ns.Retail.TargetChanged()
            if old then
                dotsByTarget[old] = nil
                ns._forgetRecipient(old)
            end
        end
        dotsByTarget.target = nil -- only used when the target's GUID is secret
        if ns._absorbedAt then ns._absorbedAt.target = nil end
        if pendingCast and pendingCast.key == "target" then pendingCast.key = nil end
        resetComboCount() -- combo points belong to the target they were built on
        forgetPendingOutcomes()
        dropCastInProgress("target changed")
        lastTracedDamage = nil
        trace("TARGET changed to " .. (unitKey("target") or "none"))
        safeRefresh()

    elseif event == "UNIT_SPELLCAST_SENT" then
        local _, targetName, castGUID, spellID = ...
        onCastSent(spellID, castGUID, targetName)

    elseif event == "UNIT_POWER_FREQUENT" then
        local _, powerType = ...
        if not isSecret(powerType) and powerType == "COMBO_POINTS" then rememberComboPoints() end

    elseif event == "UNIT_SPELLCAST_START" then
        local _, castGUID, spellID = ...
        if onCastStart(castGUID, spellID) then safeRefresh() end

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local _, castGUID, spellID = ...
        if onCastEnded(event, castGUID, spellID) then safeRefresh() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, castGUID, spellID = ...
        onCastSucceeded(castGUID, spellID)
        local appliedTo, waiting = onPlayerCast(spellID, castGUID)
        if appliedTo and ns.RogueEffects then ns.RogueEffects.AfterCast(appliedTo, spellID, unitKey) end
        safeRefresh()
        -- A DoT waiting for its first tick isn't drawn yet; it flashes when that tick lands instead.
        if appliedTo and not waiting and appliedTo == unitKey("target") then playFlash() end

    elseif event == "UNIT_COMBAT" then
        local revealed = onUnitCombat(...)
        if revealed and revealed == unitKey("target") then
            safeRefresh()
            playFlash()
        end
    end
end)

local sinceUpdate = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    if db then animateMarker(elapsed) end
    if db and ns.Retail and ns.Retail.UpdatePoisonOffset then ns.Retail.UpdatePoisonOffset(TargetFrame) end
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL or not db then return end
    sinceUpdate = 0
    safeRefresh()
end)
if BIT.Perf then BIT.Perf.Watch(frame, "OnEvent", "DoTInfo") end
if BIT.Perf then BIT.Perf.Watch(frame, "OnUpdate", "DoTInfo") end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

-- Its own command: /dotinfo.
local SLASH = "/r2qdot"
SLASH_R2QDOTINFO1 = SLASH
SlashCmdList.R2QDOTINFO = function(msg)
    if BIT.IsRunning and not BIT.IsRunning("DoTInfo") then BIT.SayOff("DoTInfo") return end
    local cmd = strlower(strtrim(msg or ""))
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.openOptions()
    elseif cmd == "line" then
        db.showMarkers = not db.showMarkers
        if db.showMarkers and not healthBar then
            print(BIT.L("Target frame health bar not found; health bar markers unavailable."))
        else
            local state = BIT.L(db.showMarkers and "Health bar markers ON." or "Health bar markers OFF.")
            if db.showMarkers and db.targetMarkers == false then
                state = state .. " " .. BIT.L("The target frame's stays off (Marker tab).")
            end
            print(state)
        end
    elseif cmd == "marker" then
        ns.traceMarker()
    elseif cmd == "marker bar" or cmd == "marker screen" then
        -- where the damage markers hang: the health bar (the default) or the screen
        db.markerParent = cmd == "marker screen" and "screen" or nil
        ns.applyMarkerParent()
        print("DoTInfo: the damage markers now hang on " .. (db.markerParent == "screen" and "the screen" or "the health bar")
            .. (type(InCombatLockdown) == "function" and InCombatLockdown() and " (the target frame's moves when combat ends)" or "") .. ".")
    elseif cmd == "plates" then
        ns.probeNameplates()
    elseif cmd == "skull" then
        skullTestUntil = GetTime() + 5
        print(BIT.L("Kill icon test for 5 seconds: one icon ON the portrait (the real one) and one ABOVE it (plain test)."))
        C_Timer.After(0.5, traceSkullGeometry)
    elseif cmd == "debug" then
        db.debug = not db.debug
        print(BIT.L(db.debug and "Debug ON." or "Debug OFF."))
    elseif cmd == "reset" then
        ns.resetLearnedTicks()
    elseif cmd == "check" then
        if ns.CheckSpellbook then ns.CheckSpellbook(trace) end
    elseif cmd == "ticks" then
        if ns.toggleTickViewer then ns.toggleTickViewer()
        else print(BIT.L("Tick sizes are not learned on this client.")) end
    else
        print(BIT.L("The kill icon on the target's portrait means your DoTs will kill it."))
        print(BIT.L("/dotinfo - open the options window"))
        print(BIT.L("/dotinfo line - toggle health bar markers on/off"))
        print(BIT.L("/dotinfo skull - show the kill icon for 5 seconds to check its position"))
        print(BIT.L("/dotinfo plates - check what the addon can reach on visible nameplates (logged)"))
        print(BIT.L("/dotinfo marker - report where the damage marker is (also logged); marker screen | marker bar choose what it hangs on"))
        print(BIT.L("/dotinfo debug - toggle echoing the trace log (casts, ticks, estimates) to chat"))
        if not ns.Retail then print(BIT.L("/dotinfo ticks - show the learned tick sizes")) end
        print(BIT.L("/dotinfo check - read every spell in your spellbook and list the DoT descriptions it cannot read"))
        print(BIT.L("/dotinfo reset - forget learned tick sizes"))
    end
end
