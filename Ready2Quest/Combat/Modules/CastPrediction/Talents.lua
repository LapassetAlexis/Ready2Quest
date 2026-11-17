-- Repris de DoesItDiePlus (Ironship, GPL-3.0-or-later) par tools/sync_combat.py ;
-- voir Ready2Quest/Combat/README.md. Ne pas modifier ici : corriger l'import.
-- Ready2QuestCombat module CastPrediction: the passive talent multipliers a damage cast
-- actually sees on WoW: Forever, where the client's tooltip does NOT fold talents into the
-- numbers (unlike Retail, whose descriptions already hold them; there they must never be added
-- again). The list is curated from the Forever research (BattleInfoTool-audits/castprediction-
-- research/10-forever-classes-talents.md, section 7): only talents that multiply the damage of
-- a cast unconditionally, with their Forever magnitudes.
--
-- Ranks are read from the client's talent tree (C_ClassTalents/C_Traits, the modern trait API on
-- both clients) by matching the node's spell NAME, with IsPlayerSpell as a last resort; a manual
-- Auto/Off/Max override per talent exists in the settings for clients where nothing answers.
-- Everything is pcall'd and cached: an unavailable talent API never stops a cast from showing,
-- it only leaves the multiplier out (and says so in the trace log).
local _, BIT = "Ready2Quest\\Combat", (select(2, ...)).combat
if not BIT then return end   -- module Combat de Ready2Quest coupé (CombatBoot.lua)
local ns = BIT.Module("CastPrediction")

local Talents = {}
ns.Talents = Talents

local CACHE_SECONDS = 30

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- Same rule as SpellDamageInfo: Forever answers like Retail to WOW_PROJECT_ID, so the version
-- decides (Retail is 10 and up, Forever 1.60, Classic Era 1.15).
local function isRetail()
    if type(GetBuildInfo) ~= "function" then return false end
    local ok, version = pcall(GetBuildInfo)
    if not ok or isSecret(version) or type(version) ~= "string" then return false end
    local major = tonumber(version:match("^(%d+)"))
    return major ~= nil and major >= 10
end

Talents.IsRetail = isRetail

local function spellName(spellID)
    local fn = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if type(fn) ~= "function" or type(spellID) ~= "number" then return nil end
    local ok, name = pcall(fn, spellID)
    if ok and not isSecret(name) and type(name) == "string" then return name end
    return nil
end
Talents.SpellName = spellName

local function spellDescription(spellID)
    local fn = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if type(fn) ~= "function" or type(spellID) ~= "number" then return nil end
    local ok, text = pcall(fn, spellID)
    if ok and not isSecret(text) and type(text) == "string" and text ~= "" then return text end
    return nil
end

---------------------------------------------------------------------------------------------
-- The curated list (Forever): includes only what a cast-damage estimate should multiply
---------------------------------------------------------------------------------------------

-- perRank: the percent per rank as a fraction. byRank: the percent of each rank when it is not
-- linear (Searing Light reads 2% then 5%). schools: which parsed schools it multiplies.
-- spells: name-limited talents (only these spells' casts). verify: the magnitude still needs a
-- live tooltip read; it is reported by the probe but never applied until confirmed here.
-- The talents that simply add a percent to a spell or a school (Moonfury, Shadow Mastery, Darkness, Searing Light,
-- Arcane Instability, Aftermath, Concussion, Call of Flame, Agonizing Flames and 29 more) are no longer listed here:
-- they are read, with the value of every rank, from the client's tables (Core/TalentModsData.lua, applied by
-- Core/TalentMods.lua, see Talents.MultiplierFor). This list keeps what those tables cannot express: talents that
-- only matter together with an aura, and the ones whose magnitude depends on the state of the target.
Talents.LIST = {
    -- Since build 70753: 1% a rank (up to 3 ranks) for each Fire effect on the target, up to four effects (3% to 12%;
    -- the client curve of build 70755). The count of effects is not read yet, so it is held back until it is.
    { key = "MAGE_FIRE_POWER", class = "MAGE", en = "Fire Power", ids = { 11124 }, perRank = 0.01, maxRank = 3,
        verify = true, schools = { fire = true } },
    -- Crusade: all damage +1% / +2% (client curve of build 70755; a further 1% / 2% against Demons and Undead is not applied).
    { key = "PALADIN_CRUSADE", class = "PALADIN", en = "Crusade", ids = { 1311083 }, perRank = 0.01, maxRank = 2,
        schools = { physical = true, holy = true, fire = true, nature = true, frost = true, frostfire = true,
            shadow = true, arcane = true, spellfire = true, spellfrost = true, shadowfrost = true, shadowflame = true,
            chimeral = true, chaos = true } },
    { key = "PALADIN_SACRED_ARBITER", class = "PALADIN", en = "Sacred Arbiter", ids = { 1311087 }, perRank = 0.20,
        maxRank = 1, spells = { ["Holy Strike"] = true } },
    -- Ranks that only matter together with an aura (Auras.lua reads them through `talent`); never applied here.
    -- Improved Shadow Bolt 4% a point while the 12 s debuff (17794) is on the target (beta pass).
    { key = "WARLOCK_IMPROVED_SHADOW_BOLT", class = "WARLOCK", en = "Improved Shadow Bolt", ids = { 17793 },
        perRank = 0.04, maxRank = 5, auraOnly = true },
    -- Shadow and Flame 2% a point on Shadow Bolt and Incinerate while its 20 s buffs (1293816, 426311) are up.
    -- Build 70755 still has the 2% a rank in the effects the tooltip names (2, 4 ... 10; its other effects, 4 ... 20 and
    -- 20 ... 100, are not the damage). Blizzard's launch notes of 3 Nov say 4%: 0.04 waits for a build that shows it.
    { key = "WARLOCK_SHADOW_AND_FLAME", class = "WARLOCK", en = "Shadow and Flame", ids = { 426316 },
        perRank = 0.02, maxRank = 5, auraOnly = true },
    -- Decimation 3/6% on Shadow Bolt and Searing Pain while its buff (440873) is up (target under 35%).
    { key = "WARLOCK_DECIMATION", class = "WARLOCK", en = "Decimation", ids = { 440870 }, byRank = { 0.03, 0.06 },
        maxRank = 2, auraOnly = true },
    -- Power in Light 2% a point on Smite and Penance against your own Holy Fire.
    { key = "PRIEST_POWER_IN_LIGHT", class = "PRIEST", en = "Power in Light", ids = { 1309969 }, perRank = 0.02,
        maxRank = 5, auraOnly = true },
}

local function percentFor(entry, rank)
    if entry.byRank then return entry.byRank[math.min(rank, #entry.byRank)] or 0 end
    return (entry.perRank or 0) * rank
end
Talents.PercentFor = percentFor

---------------------------------------------------------------------------------------------
-- Reading the talent tree (C_ClassTalents / C_Traits), by node spell name
---------------------------------------------------------------------------------------------

-- { [name] = { rank = n, maxRank = n, spellID = id } } for every node the client names, or nil.
local function collectTree()
    if type(C_Traits) ~= "table" or type(C_ClassTalents) ~= "table" then return nil end
    local configID
    if type(C_ClassTalents.GetActiveConfigID) == "function" then
        local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
        if ok and not isSecret(id) and type(id) == "number" then configID = id end
    end
    if not configID then return nil end
    local ok, info = pcall(C_Traits.GetConfigInfo, configID)
    if not ok or isSecret(info) or type(info) ~= "table" then return nil end
    local treeIDs = info.treeIDs
    if type(treeIDs) ~= "table" then return nil end

    local found, any = {}, false
    local byId = {}
    local list = {} -- every node with its tree position, for the census
    local function spellIDOf(nodeID, nodeInfo)
        local id = nodeInfo.spellID
        if type(id) == "number" and not isSecret(id) then return id end
        local entry = nodeInfo.activeEntry
        if type(entry) ~= "number" or isSecret(entry) then return nil end
        local okEntry, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entry)
        if not okEntry or isSecret(entryInfo) or type(entryInfo) ~= "table" then return nil end
        local definition = entryInfo.definitionID
        if type(definition) ~= "number" or isSecret(definition) then return nil end
        local okDef, definitionInfo = pcall(C_Traits.GetDefinitionInfo, definition)
        if not okDef or isSecret(definitionInfo) or type(definitionInfo) ~= "table" then return nil end
        id = definitionInfo.spellID or definitionInfo.overrideSpellID
        if type(id) == "number" and not isSecret(id) then return id end
        return nil
    end
    for i = 1, #treeIDs do
        local treeID = treeIDs[i]
        if type(treeID) == "number" and not isSecret(treeID) then
            local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
            if okNodes and not isSecret(nodeIDs) and type(nodeIDs) == "table" then
                for j = 1, #nodeIDs do
                    local nodeID = nodeIDs[j]
                    if type(nodeID) == "number" and not isSecret(nodeID) then
                        local okNode, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                        if okNode and not isSecret(nodeInfo) and type(nodeInfo) == "table" then
                            any = true
                            local rank = nodeInfo.ranksPurchased
                            local maxRank = nodeInfo.maxRanks
                            local spellID = spellIDOf(nodeID, nodeInfo)
                            local name = spellID and spellName(spellID)
                            if name and type(rank) == "number" and not isSecret(rank) then
                                found[name] = { rank = rank, maxRank = maxRank, spellID = spellID }
                            end
                            -- by spell id too: a name is localised, the id is not
                            if spellID and type(rank) == "number" and not isSecret(rank) then
                                byId[spellID] = { rank = rank, maxRank = maxRank, spellID = spellID }
                                list[#list + 1] = { id = spellID, name = name, rank = rank, maxRank = maxRank }
                            end
                        end
                    end
                end
            end
        end
    end
    if not any then return nil end
    return found, byId, list
end
Talents._collectTree = collectTree

local treeCache, idCache, treeCacheAt
function Talents.Invalidate()
    treeCache, idCache, treeCacheAt = nil, nil, nil
    if BIT.TalentMods then BIT.TalentMods.Invalidate() end
end

local function tree()
    local ok, t = pcall(GetTime)
    local now = ok and type(t) == "number" and t or 0
    if treeCache and now - (treeCacheAt or 0) < CACHE_SECONDS then return treeCache, idCache end
    treeCacheAt = now
    local okCollect, collected, byId = pcall(collectTree)
    treeCache = (okCollect and collected) or nil
    idCache = (okCollect and byId) or nil
    return treeCache, idCache
end

-- The rank of one curated talent: the manual override first, else the tree by name, else
-- IsPlayerSpell (only a one-rank talent can be told apart this way). nil when nothing knows.
local function rankOf(entry)
    local settings = ns._settings and ns._settings()
    if not settings then return nil end
    local forced = settings.talentForce and settings.talentForce[entry.key]
    if forced == "off" then return 0 end
    if forced == "max" then return entry.maxRank end

    local t, byId = tree()
    if byId and entry.ids then
        for _, id in ipairs(entry.ids) do
            if byId[id] then return byId[id].rank, byId[id] end
        end
    end
    if t then
        local node = t[entry.en] or (entry.de and t[entry.de])
        if node then return node.rank, node end
    end

    if entry.maxRank == 1 and entry.ids then
        local fn = IsPlayerSpell or IsSpellKnown
        if type(fn) == "function" then
            for _, id in ipairs(entry.ids) do
                local ok, known = pcall(fn, id)
                if ok and not isSecret(known) and known == true then return 1 end
            end
        end
    end
    return nil
end
Talents.RankOf = rankOf

-- The rank the talent tree gives a talent by spell id (else by name), with no settings or overrides involved: for
-- other modules (DoTInfo's Ignite and Deep Wounds). nil when the tree cannot be read or does not list it.
function Talents.NodeRank(ids, name)
    local t, byId = tree()
    if byId and type(ids) == "table" then
        for _, id in ipairs(ids) do
            if byId[id] then return byId[id].rank end
        end
    end
    if t and name and t[name] then return t[name].rank end
    return nil
end

-- The ranks the generated talent list reads (Core/TalentMods.lua), by spell id, else by name.
if BIT.TalentMods then
    BIT.TalentMods.RankProvider = function(id, name) return Talents.NodeRank({ id }, name) end
end

-- The curated entry of a key (Auras.lua asks for the ranks behind its auras).
function Talents.ByKey(key)
    for _, entry in ipairs(Talents.LIST) do
        if entry.key == key then return entry end
    end
end

local function playerClass()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    if ok and not isSecret(token) and type(token) == "string" then return token end
    return nil
end
Talents.PlayerClass = playerClass

-- The multiplier one cast sees on this client: 1 + percent of every applicable talent, or 1
-- when nothing applies or the client is Retail (whose descriptions already hold talents).
-- Returns multiplier, percent (0 when none), and a short note for the trace log.
function Talents.MultiplierFor(name, school, class, spellID)
    if isRetail() then return 1, 0 end
    local settings = ns._settings and ns._settings()
    if settings and settings.useTalents == false then return 1, 0 end
    class = class or playerClass()
    local percent, notes, unknown = 0, {}, false
    for _, entry in ipairs(Talents.LIST) do
        if entry.class == class and not entry.auraOnly then
            local applies = false
            if entry.spells then
                applies = type(name) == "string" and entry.spells[name] or false
            end
            if not applies and entry.schools and type(school) == "string" then
                applies = entry.schools[school] or false
            end
            if applies then
                local rank = rankOf(entry)
                if rank == nil then
                    unknown = true
                elseif rank > 0 and not entry.verify then
                    local add = percentFor(entry, rank)
                    if add > 0 then
                        percent = percent + add
                        notes[#notes + 1] = string.format("%s %d/%d +%.0f%%", entry.en, rank, entry.maxRank, add * 100)
                    end
                end
            end
        end
    end
    -- The talents read from the client's tables: schools (Moonfury) and the direct part of the spells they reach.
    if BIT.TalentMods and not (settings and settings.useTalents == false) then
        local extra, text = BIT.TalentMods.Percent(spellID, school, "d", false)
        if extra and extra > 0 then
            percent = percent + extra
            notes[#notes + 1] = text
        end
    end
    return 1 + percent, percent, table.concat(notes, ", "), unknown
end

---------------------------------------------------------------------------------------------
-- The census: what the talent tree says about talents the list does not know
---------------------------------------------------------------------------------------------

local CENSUS_MAX_NODES, CENSUS_MAX_TEXT, CENSUS_SHORT_TEXT = 400, 240, 90

-- A percent next to a word for damage or healing, in English and German (the clients tried so far): the text of a
-- talent that probably moves a cast's numbers. A guess made only to put such talents first in the census: every
-- talent's text is kept, so a talent it misses is still there to be read.
local function looksLikeMultiplier(text)
    local lower = text:lower()
    if not lower:find("%d+%.?%d*%s*%%") then return false end
    for _, word in ipairs({ "damage", "healing", "schaden", "heilung", "heilt", "wirkung", "effectiveness" }) do
        if lower:find(word, 1, true) then return true end
    end
    return false
end
Talents.LooksLikeMultiplier = looksLikeMultiplier

-- `text` cut to at most `limit` bytes without splitting a UTF-8 character (a German umlaut is two bytes, a Korean or
-- Chinese character three): a half character in the saved file is not text.
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
Talents.CutText = cutText

-- Talent ids acted on outside this file's list (DoTInfo's Ignite and Deep Wounds, ProcDots.lua).
local OTHER_KNOWN_IDS = { [11119] = "DOTINFO_IGNITE", [12834] = "DOTINFO_DEEP_WOUNDS" }

-- Every spell id the lists already act on (this file's talents, Auras.lua's talent ranks), to tell new from known.
local function knownIds()
    local known = {}
    for id, key in pairs(OTHER_KNOWN_IDS) do known[id] = key end
    for _, entry in ipairs(Talents.LIST) do
        for _, id in ipairs(entry.ids or {}) do known[id] = entry.key end
    end
    return known
end

-- Reads the whole tree with each talent's live description and keeps it in settings.census[CLASS] (SavedVariables, so
-- it can be read from the file afterwards: which talents carry a percent the lists do not use is then a matter of
-- reading one table). Only on request (/upt castpred census): it takes some tens of kilobytes of the saved file, which
-- is paid for by whoever asks. Returns the census table, or nil with a reason. A tree whose texts are mostly not
-- loaded yet is not kept; one with a few missing is kept with their count (unread).
function Talents.Census()
    if isRetail() then return nil, "Retail descriptions already hold the talents" end
    local settings = ns._settings and ns._settings()
    if not settings then return nil, "settings not ready" end
    local okCollect, found, _, list = pcall(collectTree)
    if not okCollect or not found or not list or #list == 0 then return nil, "the talent tree cannot be read" end
    local spent = 0
    for _, node in ipairs(list) do spent = spent + (node.rank or 0) end
    local okBuild, version, build = pcall(GetBuildInfo)
    local class = playerClass()
    local known, nodes, candidates, waiting, truncated = knownIds(), {}, 0, 0, false
    for _, node in ipairs(list) do
        if #nodes >= CENSUS_MAX_NODES then
            truncated = true
            break
        end
        local text = spellDescription(node.id)
        if text then
            text = text:gsub("%s+", " ")
            local entry = { id = node.id, n = node.name, r = node.rank, m = node.maxRank }
            if known[node.id] then
                entry.k = known[node.id]
            elseif looksLikeMultiplier(text) then
                entry.c = true
                candidates = candidates + 1
            end
            -- The whole text for what the lists use or may need to; a start of it for the rest, which keeps the saved
            -- file small (a tree has a hundred and more talents).
            entry.t = cutText(text, (entry.k or entry.c) and CENSUS_MAX_TEXT or CENSUS_SHORT_TEXT)
            nodes[#nodes + 1] = entry
        else
            waiting = waiting + 1
        end
    end
    if waiting > #list / 2 then return nil, "the descriptions are not loaded yet; try again in a minute" end
    local census = { class = class, build = okBuild and tostring(build) or nil, version = okBuild and tostring(version) or nil,
        points = spent, candidates = candidates, unread = waiting, truncated = truncated, nodes = nodes }
    -- One census per class: the settings are shared by every character of the account.
    if type(settings.census) ~= "table" then settings.census = {} end
    settings.census[tostring(class)] = census
    return census
end

-- Removes what Census kept (the whole table, every class).
function Talents.ClearCensus()
    local settings = ns._settings and ns._settings()
    if settings then settings.census = nil end
end

-- The probe: what the class's trees answer for the curated talents, with the live description
-- so a magnitude marked verify can be confirmed in game. Returns a list of chat lines.
function Talents.ProbeLines()
    local class = playerClass()
    local lines = {}
    local t = tree()
    lines[#lines + 1] = string.format("class %s; talent tree %s; Retail=%s",
        tostring(class), t and (tostring((next(t) ~= nil) and "read" or "empty")) or "unavailable",
        tostring(isRetail()))
    for _, entry in ipairs(Talents.LIST) do
        if entry.class == class then
            local rank, node = rankOf(entry)
            local settings = ns._settings and ns._settings()
            local forced = settings and settings.talentForce and settings.talentForce[entry.key] or "auto"
            local applied = percentFor(entry, rank or 0)
            lines[#lines + 1] = string.format("%s: rank %s/%d (force %s), applies +%.0f%%%s%s",
                entry.en, rank and tostring(rank) or "?", entry.maxRank, tostring(forced), applied * 100,
                entry.verify and " [magnitude to verify]" or "",
                node and node.spellID and (" [spell " .. node.spellID .. "]") or "")
            if node and node.spellID then
                local text = spellDescription(node.spellID)
                if text then
                    lines[#lines + 1] = "    " .. text:gsub("\n", " ")
                end
            end
        end
    end
    -- The talents read from the client's tables (Core/TalentMods.lua): rank and what it adds in total at that rank.
    if BIT.TalentMods and BIT.TalentMods.Describe then
        lines[#lines + 1] = "talents read from the client data (they add to Forever numbers; Retail adds nothing):"
        for _, line in ipairs(BIT.TalentMods.Describe()) do lines[#lines + 1] = "    " .. line end
    end
    return lines
end

return Talents
