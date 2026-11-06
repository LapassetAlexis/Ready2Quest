-- ZoneQuests.lua -- quêtes de chaque zone, tables livrées avec l'addon (v1.25.0)
--
-- Le client ne donne pas la liste des quêtes d'une zone : elle est tirée en
-- amont de la base de Questie (tools/gen_zone_data.py) dans
-- ZoneQuests_Forever.lua, qui se garde lui-même : seul le client Forever
-- remplit ns.ZONE_QUESTS. Aucun addon tiers n'est requis en jeu.
--
-- Comptées : les quêtes de la zone faisables par CE personnage (masques de race
-- et de classe de la table), hors quêtes qu'une autre a fermées (ex : choix
-- exclusif, quête d'approche dont la suite est faite). Le niveau n'exclut rien
-- (100 % strict, choix assumé). Faites : C_QuestLog.IsQuestFlaggedCompleted
-- (ou la globale des vieux clients).
--
-- Coût : une zone compte ~100 quêtes ; la liste calculée est gardée en cache
-- (par zone, race, classe et langue) et oubliée à chaque QUEST_TURNED_IN /
-- QUEST_LOG_UPDATE. En combat, l'oubli attend la fin du combat
-- (PLAYER_REGEN_ENABLED) : la liste déjà calculée continue de servir.
-- Vit sous le module Compagnon (db.companionEnabled), comme le carnet.
--
-- En complément (jamais à la place) : les quêtes que le jeu propose sur la
-- carte de la zone (C_QuestLine.GetAvailableQuestLines, C_TaskQuest.
-- GetQuestsOnMap) quand le client les expose. Seules celles absentes de la
-- table et pas encore faites sont gardées (ns:ZoneLiveQuests) ; l'onglet
-- Quêtes du carnet les liste à part, sans toucher au compte « faites / total ».
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

local HINT_NAMES = 6

-- ---------------------------------------------------------------------------
-- Chaînes
-- ---------------------------------------------------------------------------
local FR = {
	JRN_PART_quests = "Quêtes",
	ZQ_HINT_TODO    = "À faire :",
	ZQ_LEVEL        = "niveau %d",
	ZQ_DONE         = "faite",
	ZQ_NO_LIST      = "Pas de liste de quêtes pour ce client.",
	ZQ_LIVE_HEAD    = "Proposées sur la carte : %d",
	ZQ_LIVE         = "sur la carte",
}
local EN = {
	JRN_PART_quests = "Quests",
	ZQ_HINT_TODO    = "To do:",
	ZQ_LEVEL        = "level %d",
	ZQ_DONE         = "done",
	ZQ_NO_LIST      = "No quest list for this client.",
	ZQ_LIVE_HEAD    = "Offered on the map: %d",
	ZQ_LIVE         = "on the map",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.ZONE_QUESTS_STRINGS = { fr = FR, en = EN } end

-- ---------------------------------------------------------------------------
-- Accès robustes
-- ---------------------------------------------------------------------------
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local function ModuleOn()
	local db = ns:DB()
	return db.enabled ~= false and db.companionEnabled ~= false
end

local function InCombat()
	return ns.journalTrackerCombat == true or Call(rawget(_G, "InCombatLockdown")) == true
end

local function French()
	return Call(rawget(_G, "GetLocale")) == "frFR"
end

-- Table du client : présente et non vide
local function Table()
	local all = rawget(ns, "ZONE_QUESTS")
	if type(all) ~= "table" or #ns.ZoneIds(all) == 0 then return nil end
	return all
end

function ns:ZoneQuestsAvailable()
	return Table() ~= nil
end

-- ---------------------------------------------------------------------------
-- Race et classe : masques requiredRaces / requiredClasses de Questie
-- ---------------------------------------------------------------------------
-- raceID (3e retour de UnitRace) -> bit du masque. 2^(raceID-1) jusqu'à 31 ;
-- Forever range ses races Skyborne (95, 96) sur les bits 32 et 33
-- (src/corrections/enum/expansions.lua de QuestieDB, raceMaskById).
local RACE_BIT = { [95] = 2 ^ 32, [96] = 2 ^ 33 }
ns.ZONE_QUESTS_RACE_BIT = RACE_BIT

local function RaceBit(raceID)
	if not raceID then return nil end
	if RACE_BIT[raceID] then return RACE_BIT[raceID] end
	if raceID >= 1 and raceID <= 31 then return 2 ^ (raceID - 1) end
	return nil
end

-- Masques jusqu'à 2^33 : pas de bit.band (32 bits en jeu), de l'arithmétique
local function HasBit(mask, bit)
	return math.floor(mask / bit) % 2 == 1
end

local function PlayerIDs()
	local race = tonumber((select(3, Call(rawget(_G, "UnitRace"), "player"))))
	local class = tonumber((select(3, Call(rawget(_G, "UnitClass"), "player"))))
	return race, class
end

-- Race ou classe inconnue : on ne filtre pas sur ce critère
local function Eligible(quest, race, class)
	local races, classes = tonumber(quest.races) or 0, tonumber(quest.classes) or 0
	if races > 0 then
		local bit = RaceBit(race)
		if bit and not HasBit(races, bit) then return false end
	end
	if classes > 0 and class and class >= 1 and class <= 31 then
		if not HasBit(classes, 2 ^ (class - 1)) then return false end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Statut et cache
-- ---------------------------------------------------------------------------
ns.zoneQuests = ns.zoneQuests or { done = {}, lists = {}, builds = 0, dirty = false, live = {}, requested = {} }
local state = ns.zoneQuests

local function Completed(id)
	local log = rawget(_G, "C_QuestLog")
	local fn = type(log) == "table" and log.IsQuestFlaggedCompleted or rawget(_G, "IsQuestFlaggedCompleted")
	if type(fn) ~= "function" then return false end
	local ok, value = pcall(fn, id)
	return ok and value == true
end

function ns:ZoneQuestDone(id)
	local cached = state.done[id]
	if cached == nil then
		cached = Completed(id)
		state.done[id] = cached
	end
	return cached
end

-- Fermée : une des quêtes de ex (choix exclusif, suite d'une quête
-- d'approche) est faite, celle-ci ne se fera plus
local function Closed(self, quest)
	if type(quest.ex) ~= "table" then return false end
	for _, other in ipairs(quest.ex) do
		if self:ZoneQuestDone(other) then return true end
	end
	return false
end

local function Level(quest)
	for _, value in ipairs({ quest.lvl, quest.req }) do
		value = tonumber(value)
		if value and value > 0 then return value end
	end
	return nil
end

local function Before(a, b)
	if a.done ~= b.done then return not a.done end
	local la, lb = a.level or 999, b.level or 999
	if la ~= lb then return la < lb end
	if a.name ~= b.name then return a.name < b.name end
	return a.id < b.id
end

local function Build(self, zone, race, class, french)
	local list = {}
	for id, quest in pairs(zone) do
		if type(quest) == "table" and Eligible(quest, race, class) then
			local done = self:ZoneQuestDone(id)
			if done or not Closed(self, quest) then
				local name = (french and quest.fr) or quest.en or quest.fr
				name = (type(name) == "string" and name ~= "") and name or tostring(id)
				list[#list + 1] = { id = id, name = name, done = done, level = Level(quest) }
			end
		end
	end
	table.sort(list, Before)
	state.builds = state.builds + 1
	return list
end

-- Quêtes de la zone pour ce personnage, triées (à faire d'abord, par niveau),
-- nil si pas de table pour ce client, zone inconnue ou aucune quête
function ns:ZoneQuestList(zoneID)
	zoneID = tonumber(zoneID)
	if not zoneID or not ModuleOn() then return nil end
	local all = Table()
	local zone = all and all[zoneID]
	if type(zone) ~= "table" then return nil end
	if state.dirty and not InCombat() then
		state.done, state.lists, state.dirty = {}, {}, false
	end
	local race, class = PlayerIDs()
	local french = French()
	local key = table.concat({ zoneID, tostring(race), tostring(class), french and "fr" or "en" }, ":")
	local list = state.lists[key]
	if not list then
		local ok, built = pcall(Build, self, zone, race, class, french)
		if not ok then
			if self.RecordError then self:RecordError("zonequests:build", built) end
			return nil
		end
		list = built
		state.lists[key] = list
	end
	if #list == 0 then return nil end
	return list
end

-- ---------------------------------------------------------------------------
-- Quêtes proposées sur la carte (API du moteur récent, en complément)
-- ---------------------------------------------------------------------------
local function LiveQuestID(info)
	if type(info) ~= "table" then return nil end
	local id = tonumber(ns.Plain(info.questID) or ns.Plain(info.questId))
	return (id and id > 0) and id or nil
end

local function LiveName(text)
	text = ns.Plain(text)
	return (type(text) == "string" and text ~= "") and text or nil
end

local function TaskQuestName(id)
	local task, log = rawget(_G, "C_TaskQuest"), rawget(_G, "C_QuestLog")
	return LiveName(type(task) == "table" and Call(task.GetQuestInfoByQuestID, id))
		or LiveName(type(log) == "table" and Call(log.GetTitleForQuestID, id))
end

local function BuildLive(self, zoneID, static)
	local lines, task = rawget(_G, "C_QuestLine"), rawget(_G, "C_TaskQuest")
	local found, list = {}, {}
	local function Add(id, name)
		if not id or found[id] or static[id] ~= nil or self:ZoneQuestDone(id) then return end
		found[id] = true
		list[#list + 1] = { id = id, name = name or tostring(id), done = false, live = true, detail = L.ZQ_LIVE }
	end
	if type(lines) == "table" then
		-- demande une fois par zone : la réponse arrive par QUESTLINE_UPDATE
		if not state.requested[zoneID] and type(lines.RequestQuestLinesForMap) == "function" then
			state.requested[zoneID] = true
			pcall(lines.RequestQuestLinesForMap, zoneID)
		end
		local available = Call(lines.GetAvailableQuestLines, zoneID)
		for _, info in ipairs(type(available) == "table" and available or {}) do
			local id = LiveQuestID(info)
			Add(id, LiveName(type(info) == "table" and info.questName) or (id and TaskQuestName(id)))
		end
	end
	if type(task) == "table" then
		local onMap = Call(task.GetQuestsOnMap, zoneID)
		for _, info in ipairs(type(onMap) == "table" and onMap or {}) do
			local id = LiveQuestID(info)
			if id then Add(id, TaskQuestName(id)) end
		end
	end
	table.sort(list, Before)
	return list
end

-- Quêtes du jeu pour cette zone, absentes de la table et pas encore faites ;
-- liste vide sans l'API (ou si elle ne rend rien d'exploitable)
function ns:ZoneLiveQuests(zoneID)
	zoneID = tonumber(zoneID)
	if not zoneID or not ModuleOn() then return {} end
	local list = state.live[zoneID]
	if list then return list end
	local all = Table()
	local static = (all and type(all[zoneID]) == "table") and all[zoneID] or {}
	local ok, built = pcall(BuildLive, self, zoneID, static)
	if not ok then
		if self.RecordError then self:RecordError("zonequests:live", built) end
		built = {}
	end
	state.live[zoneID] = built
	return built
end

-- ---------------------------------------------------------------------------
-- Part de complétion « Quêtes »
-- ---------------------------------------------------------------------------
function ns:ZoneQuestsPart(zoneID)
	local list = self:ZoneQuestList(zoneID)
	if not list then return nil end
	local have, todo = 0, {}
	for _, quest in ipairs(list) do
		if quest.done then have = have + 1 else todo[#todo + 1] = quest.name end
	end
	local hint = {}
	if #todo > 0 then
		hint[1] = L.ZQ_HINT_TODO
		for index, name in ipairs(todo) do
			if index > HINT_NAMES then
				hint[#hint + 1] = self:F("JRN_HINT_MORE", #todo - HINT_NAMES)
				break
			end
			hint[#hint + 1] = "  · " .. name
		end
	end
	return { have = have, need = #list, hint = hint }
end

function ns:ZoneQuestsItems(zoneID)
	local items = {}
	for _, quest in ipairs(self:ZoneQuestList(zoneID) or {}) do
		local detail
		if quest.done then
			detail = L.ZQ_DONE
		elseif quest.level then
			detail = self:F("ZQ_LEVEL", quest.level)
		end
		items[#items + 1] = { id = quest.id, name = quest.name, done = quest.done, detail = detail }
	end
	return items
end

if ns.RegisterZonePart then
	ns.RegisterZonePart({ id = "quests", label = "JRN_PART_quests", tab = "quests",
		Compute = function(self, zoneID) return self:ZoneQuestsPart(zoneID) end,
		Items = function(self, zoneID) return self:ZoneQuestsItems(zoneID) end })
end

-- ---------------------------------------------------------------------------
-- Événements : le statut « faite » change, la table non
-- ---------------------------------------------------------------------------
local function Forget()
	state.live = {}
	if InCombat() then
		state.dirty = true
	else
		state.done, state.lists, state.dirty = {}, {}, false
	end
end
local function AfterCombat()
	if state.dirty then state.done, state.lists, state.dirty = {}, {}, false end
end
-- Lignes de quêtes reçues (après RequestQuestLinesForMap) : relire, et
-- rafraîchir le carnet s'il est ouvert
local function QuestLinesUpdated()
	state.live = {}
	local frame = ns.journalFrame
	if frame and frame.IsShown and frame:IsShown() and ns.RefreshJournal then ns:RefreshJournal() end
end
local HANDLERS = { QUEST_TURNED_IN = Forget, QUEST_LOG_UPDATE = Forget, PLAYER_REGEN_ENABLED = AfterCombat,
	QUESTLINE_UPDATE = QuestLinesUpdated }

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("zonequests:" .. tostring(event), err) end
end)
ns.zoneQuestsEventFrame = eventFrame

if ns.Mark then ns.Mark("ZoneQuests") end
