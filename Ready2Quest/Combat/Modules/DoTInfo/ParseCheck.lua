-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module DoTInfo: /dotinfo check. Reads every spell in the player's spellbook the way a
-- cast would be read and says which descriptions look like damage over time (a number and a time in seconds)
-- yet give no DoT. Meant for clients in a language nobody has tried yet: the player pastes the output in an issue.
-- The findings are also kept in the saved settings (census, one entry per class), with the total and duration of
-- every DoT it read, so they can be taken from the SavedVariables file instead of being pasted.

local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("DoTInfo")

local function plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end

local function spellbookIDs()
    local ids, seen = {}, {}
    local function add(id)
        id = plain(id)
        if type(id) == "number" and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    if C_SpellBook and type(C_SpellBook.GetNumSpellBookSkillLines) == "function" then
        local bank = (type(Enum) == "table" and type(Enum.SpellBookSpellBank) == "table" and Enum.SpellBookSpellBank.Player) or 0
        local okN, n = pcall(C_SpellBook.GetNumSpellBookSkillLines)
        n = okN and plain(n) or 0
        for line = 1, type(n) == "number" and n or 0 do
            local ok, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
            if ok and type(info) == "table" and type(info.itemIndexOffset) == "number" and type(info.numSpellBookItems) == "number" then
                for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local ok2, item = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
                    if ok2 and type(item) == "table" then add(item.spellID) end
                end
            end
        end
    elseif type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function" and type(GetSpellBookItemInfo) == "function" then
        local okN, tabs = pcall(GetNumSpellTabs)
        for tab = 1, (okN and type(tabs) == "number" and tabs or 0) do
            local ok, _, _, offset, count = pcall(GetSpellTabInfo, tab)
            if ok and type(offset) == "number" and type(count) == "number" then
                for i = offset + 1, offset + count do
                    local ok2, kind, id = pcall(GetSpellBookItemInfo, i, "spell")
                    if ok2 and kind == "SPELL" then add(id) end
                end
            end
        end
    end
    return ids
end

-- A digit followed by a time unit in the languages the parsers cover (seconds: sec, Sek, seg, s, 초, 秒).
local function mentionsSeconds(desc)
    return desc:find("%d+%.?%d*%s*[Ss]ec") or desc:find("%d+%.?%d*%s*Sek") or desc:find("%d+%.?%d*%s*seg")
        or desc:find("%d+%.?%d*%s*s%f[%A]") or desc:find("%d%s*초") or desc:find("%d%s*秒")
end

-- `text` cut to at most `limit` bytes without splitting a UTF-8 character (the saved file would hold half of one).
local function cutText(text, limit)
    if #text <= limit then return text end
    local cut = limit
    while cut > 0 do
        local nextByte = text:byte(cut + 1)
        if not nextByte or nextByte < 0x80 or nextByte >= 0xC0 then break end
        cut = cut - 1
    end
    return text:sub(1, cut)
end

-- What a check found, kept in the settings: the DoTs it read (id, the total and duration the text gave: next to
-- db.ticks, what the ticks turned out to be, the gap is the power the text leaves out) and the texts that mention
-- seconds but give none. Capped, and one entry per class: the settings are shared by every character.
local CENSUS_MAX, CENSUS_TEXT = 80, 320
local function storeCensus(locale, total, parsed, unread, waiting)
    local internals = ns.Internals
    local db = internals and internals.getDb and internals.getDb()
    if type(db) ~= "table" then return end
    local _, class = UnitClass("player")
    local list = {}
    for i = 1, math.min(#unread, CENSUS_MAX) do
        local entry = unread[i]
        list[i] = { id = entry.id, n = entry.name, t = cutText(entry.desc:gsub("%s+", " "), CENSUS_TEXT) }
    end
    local read = {}
    for i = 1, math.min(#parsed, CENSUS_MAX) do
        local entry = parsed[i]
        read[i] = { id = entry.id, total = entry.total, duration = entry.duration }
    end
    local version, build = GetBuildInfo()
    if type(db.census) ~= "table" then db.census = {} end
    db.census[tostring(class)] = { locale = locale, version = version, build = build, class = class, total = total,
        waiting = waiting, read = read, unread = list }
end

function ns.CheckSpellbook(trace)
    local ids = spellbookIDs()
    if #ids == 0 then print("DoTInfo check: the spellbook could not be read.") return end
    local read, unread, waiting, parsed, errors = {}, {}, 0, {}, 0
    for _, id in ipairs(ids) do
        local okN, name, desc = pcall(function()
            local n = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id))
            local d = ((C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription)(id)
            return n, d
        end)
        name, desc = okN and plain(name) or nil, okN and plain(desc) or nil
        if ns.Retail and not ns.Retail.SpellID(id) then
            -- Retail reads only its own list of spells
        elseif type(name) == "string" and type(desc) == "string" and desc ~= "" then
            local ok, total, school, duration = pcall(ns.ReadSpellText, id, desc)
            if not ok then
                errors = errors + 1
                trace(string.format("CHECK ERROR %s (id %d): %s", name, id, tostring(total)))
                unread[#unread + 1] = { id = id, name = name, desc = desc }
            elseif total then
                read[#read + 1] = string.format("%s (%d over %ss)", name, total, tostring(duration))
                parsed[#parsed + 1] = { id = id, total = total, duration = duration }
            elseif ok and school ~= true and mentionsSeconds(desc) and desc:find("%d") then
                -- (nil, true) is the ignore list answer (Rain of Fire, Mind Flay ...): left out on purpose.
                unread[#unread + 1] = { id = id, name = name, desc = desc }
            end
        else
            waiting = waiting + 1
        end
    end
    local locale = (GetLocale and GetLocale()) or "?"
    storeCensus(locale, #ids, parsed, unread, waiting)
    print(string.format("DoTInfo check (%s): %d spells, %d read as a DoT, %d unread (including %d parser errors)%s.", locale,
        #ids, #read, #unread, errors, waiting > 0 and (", " .. waiting .. " texts not loaded yet, run it again") or ""))
    if #read > 0 then print("Read: " .. table.concat(read, ", ")) end
    trace(string.format("CHECK %s: %d spells, %d read, %d unread", locale, #ids, #read, #unread))
    for i, entry in ipairs(unread) do
        trace(string.format("CHECK NOT READ %s (id %d): %s", entry.name, entry.id, entry.desc))
        if i <= 12 then print(string.format("  not read: %s (id %d)", entry.name, entry.id)) end
    end
    if #unread > 0 then
        print("The full texts are in the saved log (SavedVariables) after /reload, and cut to 320 characters in the census; paste them in an issue if a DoT is among them.")
    end
end
