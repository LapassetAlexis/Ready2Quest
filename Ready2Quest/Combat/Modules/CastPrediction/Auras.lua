-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module CastPrediction: the aura-driven modifiers a damage cast sees --
-- buffs on the player and debuffs on the target that the spell description does NOT hold.
-- Curated from the research (BattleInfoTool-audits/castprediction-research/10- and 30-) and from the
-- beta client's own numbers (ElliotWood/Forever docs/beta-pass, build 1.60.1.69893):
--   * Arcane Power (12042) +30% damage, Power Infusion (10060) +20% damage -- player buffs,
--   * Improved Scorch (22959) +3% per stack fire taken from you, max 5 -- target debuff,
--   * Curse of the Elements (1311676..1311680) +8/10% of every magic school -- target debuff
--     (Forever's version covers all magic schools; Curse of Shadow is gone),
--   * Demonic Sacrifice (Imp 18789 +15% Shadow, Succubus 18791 +15% Fire -- reversed from Classic),
--   * Frigid Power (1326891, +15% Frost for a minute) and Ice Barrier itself (+5% Frost while the shield holds),
--     the mage's Ice Barrier since the 20 and 30 Oct hotfixes,
--   * Improved Shadow Bolt, Shadow and Flame, Decimation (warlock), Power in Light, Shadow Weaving and
--     Shadowform (priest), Stormstrike and Rage of the Farseer (shaman), the Gnome racial Eureka!,
--   * the spell-specific bonus against your own damage-over-time: Incinerate +25% on Immolate.
--   Lava Burst's +20% against Flame Shock is gone with the spell (Blizzard's launch notes of 3 Nov; build 70753 still
--   lists the spell).
--   Not here on purpose: Arcane Blast's stacks. Build 1.60.1.70753 turned 400573 into 12% of Intellect as spell
--   power per stack (aura 174), which GetSpellBonusDamage already holds, so a damage multiplier would count it twice.
--
-- WoW: Forever hides auras in combat, so there these modifiers only ever apply out of combat
-- (the hit calibration carries the in-combat effect instead); an unreadable aura is never
-- treated as absent, it just adds nothing. Retail reads auras normally. Every entry can be
-- switched off in the settings; /upt castpred auras prints what is readable right now.
local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("CastPrediction")

local Auras = {}
ns.Auras = Auras

local MAGIC = { fire = true, frost = true, frostfire = true, arcane = true, shadow = true, nature = true, holy = true }
local ANY = { physical = true, fire = true, frost = true, frostfire = true, arcane = true, shadow = true,
    nature = true, holy = true }
local PLAIN_SCHOOLS = { "physical", "holy", "fire", "nature", "frost", "shadow", "arcane" } -- the mask bits 1, 2, 4 ... 64

-- A combined school counts as each of its parts (a Frost aura applies to Spellfrost), by Core.lua's masks.
local function schoolApplies(schools, school)
    if schools[school] then return true end
    local mask = ns.SCHOOL_MASKS and ns.SCHOOL_MASKS[school]
    for index, name in ipairs(PLAIN_SCHOOLS) do
        if mask and schools[name] and math.floor(mask / 2 ^ (index - 1)) % 2 == 1 then return true end
    end
    return false
end

-- ids: the aura's own spell ids. names: matched when the client reports no id (English first; the names
-- of the ids are added in the client's own language). percent: a flat multiplier (0.30 = +30%).
-- perStack/maxStacks: per application, capped. talent: the key of a Talents.LIST entry whose rank sets the
-- percent (the aura says it is up, the talent says how much). own: only an aura you applied counts (a
-- personal debuff such as Improved Shadow Bolt, or your own Immolate). group: of the entries sharing a
-- group only the first that applies is used (two ways to read one effect). class: the entry is listed in
-- the settings for that class only. notSpells: the aura never applies to these casts. verify: the magnitude or the school list still needs a live read; never applied
-- until then.
Auras.LIST = {
    { key = "PLAYER_ARCANE_POWER", en = "Arcane Power", unit = "player", class = "MAGE",
        ids = { 12042 }, names = { "Arcane Power" }, percent = 0.30, schools = MAGIC },
    { key = "PLAYER_POWER_INFUSION", en = "Power Infusion", unit = "player",
        ids = { 10060 }, names = { "Power Infusion" }, percent = 0.20, schools = MAGIC },
    { key = "TARGET_IMPROVED_SCORCH", en = "Improved Scorch", unit = "target", debuff = true, class = "MAGE",
        ids = { 22959 }, names = { "Improved Scorch" }, perStack = 0.03, maxStacks = 5, schools = { fire = true },
        own = true },
    -- Forever: 1311676 (30), 1311677 (40: 8%), 1311680 (50 and 60: 10%), every magic school, from any warlock.
    -- The dedicated rank-2 entry comes first: the 10% entry below also answers to the name.
    { key = "TARGET_CURSE_OF_ELEMENTS_40", foreverOnly = true, en = "Curse of the Elements (rank 2)", unit = "target",
        debuff = true, ids = { 1311677 }, percent = 0.08, schools = MAGIC, group = "COE" },
    { key = "TARGET_CURSE_OF_ELEMENTS", foreverOnly = true, en = "Curse of the Elements", unit = "target", debuff = true,
        ids = { 1311680 }, names = { "Curse of the Elements", "Fluch der Elemente" },
        percent = 0.10, schools = MAGIC, group = "COE" },
    -- Ice Barrier (build 70753): its description raises your Frost damage by 15% for a minute through Frigid Power
    -- (1326891) and by another 5% while the shield holds. Forever only: Retail's Ice Barrier does neither.
    -- The client probably adds these percent modifiers up (1.20 with the barrier), this file multiplies them (1.2075).
    { key = "PLAYER_FRIGID_POWER", foreverOnly = true, en = "Frigid Power (Ice Barrier)", unit = "player", class = "MAGE",
        ids = { 1326891 }, names = { "Frigid Power" }, percent = 0.15, schools = { frost = true, frostfire = true } },
    { key = "PLAYER_ICE_BARRIER", foreverOnly = true, en = "Ice Barrier (shield up)", unit = "player", class = "MAGE",
        ids = { 11426, 13031, 13032, 13033 }, names = { "Ice Barrier" }, percent = 0.05,
        schools = { frost = true, frostfire = true } },
    -- Fingers of Frost makes the next Ice Lance count as hitting a Frozen target (+300% since the 30 Oct hotfix,
    -- was +200%: x4 now, x3 before).
    -- Kept verify: the client coefficient for Ice Lance is 0 and the sim's fit is ~0.10, so the
    -- x4 only multiplies an estimate that still needs a live read first.
    { key = "PLAYER_FINGERS_OF_FROST", en = "Fingers of Frost", unit = "player", class = "MAGE",
        ids = { 400669 }, names = { "Fingers of Frost" }, percent = 3.00,
        spells = { ["Ice Lance"] = true }, verify = true },

    -- Warlock
    { key = "TARGET_IMPROVED_SHADOW_BOLT", foreverOnly = true, en = "Improved Shadow Bolt", unit = "target", debuff = true,
        class = "WARLOCK", ids = { 17794 }, names = { "Shadow Vulnerability", "Improved Shadow Bolt" },
        talent = "WARLOCK_IMPROVED_SHADOW_BOLT", schools = { shadow = true }, own = true },
    { key = "PLAYER_SHADOW_AND_FLAME", foreverOnly = true, en = "Shadow and Flame", unit = "player", class = "WARLOCK",
        ids = { 1293816, 426311 }, names = { "Shadow and Flame" }, talent = "WARLOCK_SHADOW_AND_FLAME",
        spells = { ["Shadow Bolt"] = true, ["Incinerate"] = true } },
    { key = "PLAYER_DECIMATION", foreverOnly = true, en = "Decimation", unit = "player", class = "WARLOCK",
        ids = { 440873 }, names = { "Decimation" }, talent = "WARLOCK_DECIMATION",
        spells = { ["Shadow Bolt"] = true, ["Searing Pain"] = true } },
    -- Reversed from Classic: the Imp's sacrifice is Shadow, the Succubus's Fire.
    { key = "PLAYER_SACRIFICE_IMP", foreverOnly = true, en = "Demonic Sacrifice (Imp)", unit = "player", class = "WARLOCK",
        ids = { 18789 }, names = { "Burning Shadow" }, percent = 0.15, schools = { shadow = true }, group = "DS" },
    { key = "PLAYER_SACRIFICE_SUCCUBUS", foreverOnly = true, en = "Demonic Sacrifice (Succubus)", unit = "player", class = "WARLOCK",
        ids = { 18791 }, names = { "Touch of Fire" }, percent = 0.15, schools = { fire = true }, group = "DS" },
    -- Incinerate does 25% more against a target with your Immolate on it (the Classic ranks' aura ids).
    { key = "TARGET_IMMOLATE", foreverOnly = true, en = "Immolate (Incinerate +25%)", unit = "target", debuff = true, class = "WARLOCK",
        ids = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 }, names = { "Immolate" }, percent = 0.25,
        spells = { ["Incinerate"] = true }, own = true },

    -- Priest
    { key = "TARGET_POWER_IN_LIGHT", foreverOnly = true, en = "Power in Light (Holy Fire, Shadow Word: Pain)", unit = "target", debuff = true,
        class = "PRIEST", ids = { 14914, 15262, 15263, 15264, 15265, 15266, 15267, 25384,
            589, 594, 970, 992, 2767, 10892, 10893, 10894 }, -- Holy Fire, and since build 70753 Shadow Word: Pain
        names = { "Holy Fire", "Shadow Word: Pain" }, talent = "PRIEST_POWER_IN_LIGHT",
        spells = { ["Smite"] = true, ["Penance"] = true }, own = true },
    -- Shadow Weaving stacks (15258) sit on the target and raise only the priest's own Shadow damage, 2% a
    -- stack to five.
    { key = "TARGET_SHADOW_WEAVING", foreverOnly = true, en = "Shadow Weaving", unit = "target", debuff = true, class = "PRIEST",
        ids = { 15258 }, names = { "Shadow Weaving" }, perStack = 0.02, maxStacks = 5,
        schools = { shadow = true }, own = true },
    { key = "PLAYER_SHADOWFORM", foreverOnly = true, en = "Shadowform", unit = "player", class = "PRIEST",
        ids = { 15473 }, names = { "Shadowform" }, percent = 0.15, schools = { shadow = true } },

    -- Shaman
    { key = "TARGET_STORMSTRIKE", foreverOnly = true, en = "Stormstrike", unit = "target", debuff = true, class = "SHAMAN",
        ids = { 17364 }, names = { "Stormstrike" }, percent = 0.20, own = true,
        spells = { ["Lightning Bolt"] = true, ["Chain Lightning"] = true, ["Earth Shock"] = true } },
    { key = "PLAYER_RAGE_OF_THE_FARSEER", foreverOnly = true, en = "Rage of the Farseer", unit = "player", class = "SHAMAN",
        ids = { 425336 }, names = { "Rage of the Farseer" }, percent = 0.30,
        schools = { fire = true, frost = true, nature = true } },

    -- Gnome racial (16 Oct: +10% to direct, non-periodic damage for 8 s)
    { key = "PLAYER_EUREKA", foreverOnly = true, en = "Eureka! (Gnome)", unit = "player", ids = { 1259821, 1259823 },
        names = { "Eureka!" }, percent = 0.10, schools = ANY },
}

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

local function settings()
    return ns._settings and ns._settings()
end

---------------------------------------------------------------------------------------------
-- Reading one unit's buffs or debuffs, secret-safe
---------------------------------------------------------------------------------------------

local function plainNumber(v)
    return not isSecret(v) and type(v) == "number" and v or nil
end

-- { [spellID or name] = stacks } for the unit's buffs (debuff=false) or debuffs, a set of the keys that are
-- yours (applied by the player or the pet), plus `unreadable` when the client refused to answer (a secret
-- value): the caller then applies nothing.
local function scan(unit, debuff)
    local found, mine, unreadable = {}, {}, false
    local modern = C_UnitAuras and (debuff and type(C_UnitAuras.GetDebuffDataByIndex) == "function"
        or type(C_UnitAuras.GetBuffDataByIndex) == "function")
    local function note(id, name, stacks, own)
        if id then
            found[id] = stacks
            if own then mine[id] = true end
        end
        if name then
            found[name] = stacks
            if own then mine[name] = true end
        end
    end
    for i = 1, 40 do
        if modern then
            local fn = debuff and C_UnitAuras.GetDebuffDataByIndex or C_UnitAuras.GetBuffDataByIndex
            local ok, aura = pcall(fn, unit, i)
            if not ok or isSecret(aura) then
                unreadable = true
                break
            end
            if type(aura) ~= "table" then break end -- the list ended
            local id = aura.spellId
            local name = aura.name
            if isSecret(id) then
                unreadable = true
                id = nil
            elseif type(id) ~= "number" then
                id = nil
            end
            if isSecret(name) or type(name) ~= "string" then name = nil end
            local stacks = plainNumber(aura.applications)
            if stacks == nil or stacks < 1 then stacks = 1 end
            local source = aura.sourceUnit
            local own = (not isSecret(source) and source == "player")
                or (not isSecret(aura.isFromPlayerOrPlayerPet) and aura.isFromPlayerOrPlayerPet == true)
            note(id, name, stacks, own)
        else
            local fn = debuff and UnitDebuff or UnitBuff
            if type(fn) ~= "function" then return nil end
            -- UnitBuff/UnitDebuff: name, icon, count, type, duration, expiration, source,
            -- stealable, nameplateShowPersonal, spellId (pcall adds the ok first).
            local ok, name, _, count, _, _, _, source, _, _, id = pcall(fn, unit, i)
            if not ok then return nil end
            if isSecret(name) then
                unreadable = true
            elseif name == nil then
                break -- the list ended
            else
                if isSecret(id) or isSecret(count) then unreadable = true end
                local stacks = plainNumber(count)
                if stacks == nil or stacks < 1 then stacks = 1 end
                note(plainNumber(id), type(name) == "string" and name or nil, stacks,
                    not isSecret(source) and source == "player")
            end
        end
    end
    return found, unreadable, mine
end
Auras.Scan = scan

local nameCache = {}
-- The aura's names: the ones the entry lists plus its ids' names in the client's own language.
local function namesOf(entry)
    local cached = nameCache[entry]
    if cached then return cached end
    local names = {}
    for _, name in ipairs(entry.names or {}) do names[#names + 1] = name end
    local resolved = 0
    if ns.Talents and ns.Talents.SpellName then
        for _, id in ipairs(entry.ids or {}) do
            local name = ns.Talents.SpellName(id)
            if name then
                names[#names + 1] = name
                resolved = resolved + 1
            end
        end
    end
    -- Only cache a read that found a name for every id (spell data loads late on a fresh login).
    if resolved == #(entry.ids or {}) then nameCache[entry] = names end
    return names
end

-- The stacks of one entry's aura on its unit, or nil when no API answers at all.
local function stacksOf(entry, cache)
    local key = entry.unit .. (entry.debuff and ":d" or ":b")
    local found, unreadable, mine
    local cached = cache[key]
    if cached then
        found, unreadable, mine = cached[1], cached[2], cached[3]
    else
        found, unreadable, mine = scan(entry.unit, entry.debuff)
        cache[key] = { found, unreadable, mine }
    end
    if not found then return nil, true end
    local function lookup(k)
        local stacks = found[k]
        if stacks and (not entry.own or (mine and mine[k])) then return stacks end
    end
    for _, id in ipairs(entry.ids or {}) do
        local stacks = lookup(id)
        if stacks then return stacks end
    end
    for _, name in ipairs(namesOf(entry)) do
        local stacks = lookup(name)
        if stacks then return stacks end
    end
    return 0, unreadable
end

---------------------------------------------------------------------------------------------
-- The multiplier for one cast
---------------------------------------------------------------------------------------------

local function percentOf(entry, stacks)
    if entry.talent then
        local db = settings()
        if db and db.useTalents == false then return nil end
        local talent = ns.Talents and ns.Talents.ByKey and ns.Talents.ByKey(entry.talent)
        if not talent then return nil end
        local rank = ns.Talents.RankOf(talent)
        if rank == nil then return nil end -- the rank is unknown: add nothing, say so
        return ns.Talents.PercentFor(talent, rank)
    end
    if entry.perStack then return entry.perStack * math.min(stacks, entry.maxStacks or stacks) end
    return entry.percent or 0
end

-- Is this entry for this client? The Forever-only ones hold Forever's aura ids and numbers.
function Auras.AppliesHere(entry)
    if entry.foreverOnly and ns.Talents and ns.Talents.IsRetail and ns.Talents.IsRetail() then return false end
    return true
end

-- Multiplication, not addition: Arcane Power multiplies, a taken-debuff multiplies again.
-- Returns multiplier (1 when nothing applies), percent-ish total for the trace, and a note.
function Auras.MultiplierFor(name, school, class)
    local db = settings()
    if db and db.useAuras == false then return 1, 0 end
    local list = Auras.LIST
    local mult, notes, unknown = 1, {}, false
    local cache, usedGroups = {}, {}
    for _, entry in ipairs(list) do
        if not (db and db.auraForce and db.auraForce[entry.key] == "off")
            and not (entry.group and usedGroups[entry.group]) and Auras.AppliesHere(entry) then
            local applies = false
            if entry.spells then
                applies = type(name) == "string" and entry.spells[name] or false
            end
            if not applies and entry.schools and type(school) == "string" then
                applies = schoolApplies(entry.schools, school)
            end
            if applies and entry.notSpells and type(name) == "string" and entry.notSpells[name] then applies = false end
            if applies and entry.verify then applies = false end
            if applies then
                local stacks, unreadable = stacksOf(entry, cache)
                if unreadable then unknown = true end
                if stacks and stacks > 0 then
                    local percent = percentOf(entry, stacks)
                    if percent == nil then
                        unknown = true
                    elseif percent > 0 then
                        mult = mult * (1 + percent)
                        if entry.group then usedGroups[entry.group] = true end
                        notes[#notes + 1] = string.format("%s%s +%.0f%%", entry.en,
                            stacks > 1 and (" x" .. stacks) or "", percent * 100)
                    end
                end
            end
        end
    end
    return mult, mult - 1, table.concat(notes, ", "), unknown
end

-- The probe: what is readable right now for each entry (own unit and target), stacks included.
function Auras.ProbeLines()
    local lines = {}
    lines[#lines + 1] = "auras: " .. (type(C_UnitAuras) == "table" and "C_UnitAuras"
        or (type(UnitBuff) == "function" and "UnitBuff/UnitDebuff") or "no aura API")
    local cache = {}
    for _, entry in ipairs(Auras.LIST) do
        local stacks, unreadable = stacksOf(entry, cache)
        local db = settings()
        local forced = db and db.auraForce and db.auraForce[entry.key] or "auto"
        lines[#lines + 1] = string.format("%s [%s]: stacks %s%s (force %s)%s", entry.en, entry.unit,
            stacks and tostring(stacks) or "?", unreadable and " (unreadable)" or "", tostring(forced),
            entry.verify and " [magnitude to verify]" or "")
    end
    return lines
end

return Auras
