-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- DoTInfo, German (deDE) spell descriptions and names. Registers itself with Locale.lua, before the other languages
-- (Locale_esES.lua, ...), so the German reader runs first. Moved out of Locale.lua, which is now only the registry.
-- Based on the standalone DoT addon's locale file at e4faef4 by Joe Greive (MIT).
--
-- The German wording is Classic Era deDE (Wowhead and Blizzard API tooltips); Forever's own German text is
-- unverified. How it differs from English:
--   * the duration usually comes first: "verursacht 12 Sek. lang 40 Punkt(e) Schattenschaden", but not always:
--     "75 Schattenschaden im Verlauf von 3 Sek." (Mind Flay), and it can change between ranks (Wyvern Sting)
--   * the school is glued to the noun: Schattenschaden, Feuerschaden; plain "Schaden" is physical
--   * numbers: "1.132" is a thousand one hundred and thirty-two, "7,1 Sek." is seven point one seconds

local ADDON_NAME, BIT = "Ready2Quest", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("DoTInfo")

local PHYSICAL = 1

-- The school word glued to "schaden", lower-cased. Anything else (Blutungs-, Vulkan-) counts as physical, like
-- an English school word missing from SCHOOL_MASKS.
local GERMAN_SCHOOLS = {
    heilig = 2, feuer = 4, natur = 8, frost = 16, schatten = 32, arkan = 64,
    frostfeuer = 4 + 16, schattenflammen = 4 + 32,
}

-- Words that may sit between the amount and "...schaden": "40 Punkt(e) Schattenschaden", "20 zusätzlichen
-- Feuerschaden", "42 körperlichen Schaden". Longer spellings first ("zusätzlichen" before "zusätzlich").
local GERMAN_FILLERS = { "Punkt%(en%)", "Punkt%(e%)", "Punkte", "zusätzlichen", "zusätzlich", "insgesamt", "körperlichen" }

-- Where a DoT's duration stands before its amount: "12 Sek. lang", "im Verlauf von 12 Sek.", "über 12 Sek.",
-- also written out ("über 8 Sekunden"). Captures: start, seconds, end.
local DURATION_FIRST = {
    "()(%d+%.?%d*) Sek%a*%.? lang()",
    "()im Verlauf von (%d+%.?%d*) Sek%a*%.?()",
    "()über (%d+%.?%d*) Sek%a*%.?()",
}
-- Where it stands after: "75 Schattenschaden im Verlauf von 3 Sek.", "39 Punkt(e) zusätzlichen Schaden über 9 Sek."
-- Captures: start, amount, words before "schaden", seconds.
local DURATION_AFTER = {
    "()(%d+)([^%d%.\n]-)[Ss]chaden%s+im Verlauf von (%d+%.?%d*) Sek",
    "()(%d+)([^%d%.\n]-)[Ss]chaden%s+über (%d+%.?%d*) Sek",
    -- Forever's German client leaves some texts English but with the German unit: "bleed for 119 damage over
    -- 21 Sek.." (Lacerate ranks 1-3). The empty capture reads as physical.
    "()(%d+)( ?)damage over (%d+%.?%d*) Sek",
}

-- Finisher lines between the amount and the seconds: "1 Punkt: 40 Schaden über 8 Sekunden." (Rupture),
-- "2 Punkte: 66 Schaden im Verlauf von 12 Sek." (Rip); Retail leaves out "Schaden".
local FINISHER_LINE_WORDS = {
    ["Schaden über"] = true, ["Schaden im Verlauf von"] = true, ["über"] = true, ["im Verlauf von"] = true,
}

-- German names of the spells in Core.lua's name-keyed tables (KNOWN_TICK_INTERVALS, TICK_SHAPES,
-- SCHOOL_BY_NAME, IGNORED_SPELLS): C_Spell.GetSpellName returns these on a German client.
local GERMAN_NAMES = {
    ["Insect Swarm"] = { "Insektenschwarm" },
    ["Curse of Agony"] = { "Fluch der Pein" },
    ["Bane of Agony"] = { "Omen der Pein" }, -- Cataclysm's German name; Forever's is unverified
    ["Fireball"] = { "Feuerball" },
    ["Pyroblast"] = { "Pyroschlag" },
    ["Frostfire Bolt"] = { "Frostfeuerblitz" },
    ["Serpent Sting"] = { "Schlangengift", "Schlangenbiss" },
    ["Holy Fire"] = { "Heiliges Feuer" },
    ["Rip"] = { "Zerfetzen" },
    ["Rupture"] = { "Blutung" },
    -- The rogue/druid bleed and poison family: tracked like any other DoT (Garrote, Rupture, Rake, Rip, Rend,
    -- Lacerate). Poison tooltips read as DoTs where they name one (Deadly Poison's proc); the weapon-enchant
    -- cast itself is not a cast on a target (see parseDot), and Wound/Instant Poison have no periodic damage.
    ["Garrote"] = { "Erdrosseln" },
    ["Rake"] = { "Krallenhieb" },
    ["Rend"] = { "Verwunden" },
    ["Lacerate"] = { "Aufschlitzen" },
    ["Deadly Poison"] = { "Tödliches Gift" },
    ["Instant Poison"] = { "Sofort wirkendes Gift" },
    ["Wound Poison"] = { "Wundgift" },
    ["Siphon Life"] = { "Lebensentzug" },
    ["Rain of Fire"] = { "Feuerregen" },
    ["Hellfire"] = { "Höllenfeuer" },
    ["Blizzard"] = { "Blizzard" },
    ["Flamestrike"] = { "Flammenstoß" },
    ["Consecration"] = { "Weihe" },
    ["Hurricane"] = { "Hurrikan" },
    ["Volley"] = { "Salve" },
    ["Drain Life"] = { "Blutsauger" },
    ["Drain Soul"] = { "Seelendieb" },
    ["Drain Mana"] = { "Mana entziehen" },
    ["Health Funnel"] = { "Lebenslinie" },
    ["Mind Flay"] = { "Gedankenschinden" },
    ["Arcane Missiles"] = { "Arkane Geschosse" },
    ["Starshards"] = { "Sternensplitter" },
    ["Immolation Trap"] = { "Feuerbrandfalle" },
    ["Explosive Trap"] = { "Sprengfalle" },
    ["Wyvern Sting"] = { "Stich des Flügeldrachen" },
}

local function germanIsFinisher(desc)
    return desc:find("Finishing%-Move") ~= nil
end

-- "Gewährt 1 Combopunkt." (Retail: "Gewährt für jeden Treffer 1 Combopunkt.")
local function germanComboPointsAwarded(desc)
    return tonumber(desc:match("Gewährt[^%.]-(%d+) Combopunkt"))
end

-- German number formats to Lua's: "1.132" -> "1132", "7,1" -> "7.1".
local function plainNumbers(desc)
    local text, count = desc, 1
    while count > 0 do text, count = text:gsub("(%d)%.(%d%d%d)%f[%D]", "%1%2") end
    return (text:gsub("(%d),(%d)", "%1.%2"))
end

-- The school of "<amount><words>schaden", or nil if `words` holds more than fillers and a school word.
local function schoolFromGerman(words)
    for _, filler in ipairs(GERMAN_FILLERS) do words = words:gsub(filler, " ") end
    local school = words:match("^%s*(%a*)$")
    if not school then return nil end
    return GERMAN_SCHOOLS[school:lower()] or PHYSICAL
end

-- The first "<amount> ...schaden" in `clause`: amount, school, and where it starts.
local function firstDamage(clause)
    for start, amount, words in clause:gmatch("()(%d+)([^%d]-)[Ss]chaden") do
        local school = schoolFromGerman(words)
        if school then return tonumber(amount), school, start end
    end
end

-- Same shape as parseFinisher in Core.lua.
local function parseFinisher(text, comboPoints)
    local byPoints, highest = {}, 0
    for pointsText, amount, words, secs in text:gmatch("(%d+) Punkte?%s*:%s*(%d+)%s+([^%d\n]-)(%d+%.?%d*) Sek") do
        if FINISHER_LINE_WORDS[words:match("^(.-)%s*$")] then
            local points = tonumber(pointsText)
            byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
            highest = math.max(highest, points)
        end
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, PHYSICAL, entry.duration
end

-- Same returns as parseDot in Core.lua: total damage, school mask, duration, stated tick interval.
--   "verursacht 12 Sek. lang 40 Punkt(e) Schattenschaden."  (Corruption)
--   "fügt ihm 11 Feuerschaden sowie im Verlauf von 15 Sek. insgesamt 20 zusätzlichen Feuerschaden zu."  (Immolate:
--       the clause after the duration holds the periodic part)
--   "lässt es 9 Sek. lang bluten und fügt damit 15 Punkt(e) Schaden zu."  (Rend: words in between)
--   "Überträgt alle 3 Sek. 15 Punkt(e) Gesundheit vom Ziel auf den Zaubernden. Hält 30 Sek. lang an."  (Siphon Life)
-- Like the English reader, the last DoT clause wins, and per-second channels ("6 Sek. lang pro Sekunde 50 ...")
-- and minutes ("Hält 1 Min. lang an") aren't read. Neither is a buff or debuff whose duration comes before direct
-- damage ("30 Sek. lang um 10% und fügt ihnen 103 Schaden zu"), which English words so that it isn't read either.
local function germanParseDot(desc, comboPoints)
    if germanIsFinisher(desc) then return parseFinisher(plainNumbers(desc), comboPoints) end
    -- Rogue poisons: "Überzieht eine Waffe mit Gift", Retail "Überzieht Eure Waffen".
    if desc:find("Überzieht %a+ Waffe") then return nil end
    -- Heals over time: Rejuvenation reads "Heilt beim Ziel 12 Sek. lang 32 Punkt(e) Schaden."
    if desc:find("^Heilt") then return nil end
    local text = plainNumbers(desc)

    local best, total, school, duration
    for _, pattern in ipairs(DURATION_FIRST) do
        for start, secs, after in text:gmatch(pattern) do
            -- The amount follows in the same clause.
            local clause = text:sub(after):match("^[^%.\n]*")
            local amount, amountSchool, at = firstDamage(clause)
            -- Words between the duration and the amount that make it the duration of something else: per second
            -- (a channel), or a percentage (Thunder Clap: "erhöht die Zeit zwischen ihren Angriffen 30 Sek. lang um
            -- 10% und fügt ihnen 103 Schaden zu"; Holy Shield: "Erhöht die Blockchance 10 Sek. lang um 30% und
            -- verursacht ... 130 Heiligschaden"), or each attack (Forever's Seal of Fury: "30 Sek. lang mit
            -- göttlichem Furor, wodurch jeder Nahkampfangriff zusätzlich 14 Heiligschaden verursacht").
            local between = amount and clause:sub(1, at - 1)
            -- A stat amount introduced by "um" before the damage makes the duration belong to
            -- that line, not to a DoT: "Verringert 10 Sek. lang die Rüstung des Ziels um 200
            -- und verursacht 50 Schaden." (OFF-2 follow-up). Plain counts stay readable --
            -- Arcane Missiles names "5 Wellen ... 2.189 Arkanschaden", Explosive Trap
            -- "10 Metern, indem ... 150 Feuerschaden" -- so this only rejects " um N".
            if amount and not between:find(" um %d") and not between:find("Sekunde") and not between:find("%%")
                and not between:find("[Jj]ede") and (not best or start > best) then
                best, total, school, duration = start, amount, amountSchool, tonumber(secs)
            end
        end
    end
    for _, pattern in ipairs(DURATION_AFTER) do
        for start, amount, words, secs in text:gmatch(pattern) do
            local amountSchool = schoolFromGerman(words)
            if amountSchool and (not best or start > best) then
                best, total, school, duration = start, tonumber(amount), amountSchool, tonumber(secs)
            end
        end
    end
    -- Black Arrow: "verursacht 150 Schattenschaden und zieht 30 Sek. lang 150 Mana ab."
    if not total then
        local drained, words, secs = text:match("(%d+)([^%d%.\n]-)[Ss]chaden und zieht (%d+%.?%d*) Sek%a*%.? lang %d+ Mana ab")
        local drainSchool = drained and schoolFromGerman(words)
        if drainSchool then total, school, duration = tonumber(drained), drainSchool, tonumber(secs) end
    end
    if total and duration > 0 then return total, school, duration end

    -- "alle 1 Sek. 72 Naturschaden ... Hält 10 Sek. lang an."
    local every, amount, words = text:match("alle (%d+%.?%d*) Sek%a*%.?%s*(%d+)([^%d%.\n]-)[Ss]chaden")
    school = words and schoolFromGerman(words)
    if not school then
        every, amount, words = text:match("alle (%d+%.?%d*) Sek%a*%.?%s*(%d+)([^%d%.\n]-)Gesundheit")
        school = words and schoolFromGerman(words) and PHYSICAL
    end
    local lasts = text:match("Hält (%d+%.?%d*) Sek")
    if school and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), school, lasts, every
        end
    end
end

ns.locale.register({
    tag = "deDE",
    parseDot = germanParseDot,
    isFinisher = germanIsFinisher,
    comboPointsAwarded = germanComboPointsAwarded,
    names = GERMAN_NAMES,
})
