-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module DoTInfo: the registry of client languages. Based on the standalone DoT addon's
-- locale file at e4faef4 by Joe Greive (MIT); the registry and the Spanish, French, Korean, Portuguese and
-- Chinese files follow Does It Die v0.8.3 (MIT). It lives only here now and is edited directly.
-- Core.lua reads English spell descriptions and looks spells up by their English names, so English is the base
-- language and has no file of its own. This file is the registry every other language joins (Locale_deDE.lua,
-- Locale_esES.lua, ... call ns.locale.register) with its wording for the same readings and the non-English
-- names for the name-keyed tables. The English patterns always run first and are unchanged; each other
-- language only sees descriptions the English ones didn't read, in registration order (the TOC's: German
-- first), whatever GetLocale() says: one language's patterns can't match another's text, and on
-- WoW: Forever GetLocale() answers enUS while the spell text is German. Loaded before Core.lua.
--
--     ns.locale.register({
--         tag = "koKR",
--         parseDot = function(desc, comboPoints) ... end,   -- same returns as parseDot in Core.lua
--         isFinisher = function(desc) ... end,              -- a combo point finisher ("Finishing move")
--         comboPointsAwarded = function(desc) ... end,      -- N from "Awards N combo point", or nil
--         names = { ["Rip"] = { "..." }, ... },             -- English name -> names in this language
--     })
--
-- A new language is one more Locale_xxXX.lua after this file in both TOCs, like Locale_deDE.lua.

local ADDON_NAME, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
-- Ready2QuestCombat's own namespace for the module, shared by its four files.
local ns = BIT.Module("DoTInfo")

local L = { languages = {} }
ns.locale = L

-- Every field but tag is optional.
function L.register(language)
    assert(type(language) == "table" and type(language.tag) == "string", "DoTInfo: a language needs a tag")
    table.insert(L.languages, language)
end

-- One spell ID per entry (Classic Era rank 1; all ranks share the name). At load the tables also get the name the
-- client itself reports for it, whatever the language, and Forever's own renames (980 is its Bane of Agony).
-- Frostfire Bolt is Forever's own spell with no known ID: it relies on the names tables of the language files.
L.SPELL_IDS = {
    ["Corruption"] = 172, ["Shadow Word: Pain"] = 589,
    ["Insect Swarm"] = 5570, ["Curse of Agony"] = 980, ["Fireball"] = 133, ["Pyroblast"] = 11366,
    ["Amplify Curse"] = 18288, ["Curse of Weakness"] = 702, ["Curse of Exhaustion"] = 18223, -- Core.lua, ns.AMPLIFY_USES
    ["Serpent Sting"] = 1978, ["Holy Fire"] = 14914,
    ["Rip"] = 1079, ["Rupture"] = 1943, ["Siphon Life"] = 18265,
    -- The rogue/druid bleed and poison family (Classic Era rank 1; Lacerate is Forever's own, ids 24118-24120):
    -- without these the name-keyed tables in Core.lua never learn what this client calls Garrote and friends,
    -- which is what tick intervals/shapes/schools (and any ignore check) are looked up by.
    ["Garrote"] = 703, ["Rake"] = 1822, ["Rend"] = 772, ["Lacerate"] = 24118,
    ["Deadly Poison"] = 2823, ["Instant Poison"] = 8679, ["Wound Poison"] = 13218,
    ["Rain of Fire"] = 5740, ["Hellfire"] = 1949, ["Blizzard"] = 10, ["Flamestrike"] = 2120,
    ["Consecration"] = 26573, ["Hurricane"] = 16914, ["Volley"] = 1510,
    ["Drain Life"] = 689, ["Drain Soul"] = 1120, ["Drain Mana"] = 5138, ["Health Funnel"] = 755,
    ["Mind Flay"] = 15407, ["Arcane Missiles"] = 5143, ["Starshards"] = 10797,
    ["Immolation Trap"] = 13795, ["Explosive Trap"] = 13813, ["Wyvern Sting"] = 19386,
    ["Black Arrow"] = 3674,
}

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------

-- Gives `alias` the entry `englishName` has, in every table that has one and doesn't know `alias` yet.
local function addAlias(tables, englishName, alias)
    if type(alias) ~= "string" or alias == "" or alias == englishName then return false end
    local added = false
    for _, tbl in ipairs(tables) do
        if tbl[englishName] ~= nil and tbl[alias] == nil then
            tbl[alias] = tbl[englishName]
            added = true
        end
    end
    return added
end

-- The names of every registered language.
function L.addNames(tables)
    for _, language in ipairs(L.languages) do
        for englishName, aliases in pairs(language.names or {}) do
            for _, alias in ipairs(aliases) do addAlias(tables, englishName, alias) end
        end
    end
end

-- getName(spellID) returns the client's name for a spell, or nil. Returns what was added, for the log.
function L.addClientNames(tables, getName)
    local added = {}
    for englishName, spellID in pairs(L.SPELL_IDS) do
        local ok, name = pcall(getName, spellID)
        if ok and addAlias(tables, englishName, name) then
            table.insert(added, name .. " = " .. englishName)
        end
    end
    table.sort(added)
    return added
end

---------------------------------------------------------------------------
-- The registry
---------------------------------------------------------------------------

-- The first registered language that reads `desc` as a DoT: total damage, school mask, duration, stated tick
-- interval (the returns of parseDot in Core.lua).
function L.parseDot(desc, comboPoints)
    for _, language in ipairs(L.languages) do
        if language.parseDot then
            local total, school, duration, interval = language.parseDot(desc, comboPoints)
            if total then return total, school, duration, interval end
        end
    end
end

function L.isFinisher(desc)
    for _, language in ipairs(L.languages) do
        if language.isFinisher and language.isFinisher(desc) then return true end
    end
    return false
end

function L.comboPointsAwarded(desc)
    for _, language in ipairs(L.languages) do
        local points = language.comboPointsAwarded and language.comboPointsAwarded(desc)
        if points then return points end
    end
end

-- Words nearly every English description has and other languages' descriptions don't ("sec" is left out: French
-- writes it too).
local ENGLISH_WORDS = { the = true, damage = true, ["and"] = true, ["for"] = true, over = true, of = true,
    to = true, by = true, with = true, your = true, you = true }

local function looksEnglish(desc)
    for word in desc:gmatch("%a+") do
        if ENGLISH_WORDS[word:lower()] then return true end
    end
    return false
end

-- Whether to log a description nothing read as a DoT (once per spell per session), so a play session collects
-- the wording of a language that isn't read yet, or not fully. Decided by the text itself, not GetLocale():
-- Forever's client answers enUS while its text is German, and English descriptions that aren't DoTs (Fireball)
-- aren't logged.
local loggedUnread = {}
function L.shouldLogUnread(spellID, desc)
    if type(desc) ~= "string" or desc == "" or looksEnglish(desc) then return false end
    if not desc:find("%d") then return false end -- a DoT's text has an amount: "Summon a chauffeur" is not worth a log line
    if loggedUnread[spellID] then return false end
    loggedUnread[spellID] = true
    return true
end
