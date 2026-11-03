-- QuestieZone.lua -- quêtes de la zone, via l'addon Questie s'il est chargé (v1.25.0)
--
-- Le client ne donne pas la liste des quêtes d'une zone : on la lit dans la
-- base de Questie. Sans Questie (ou avec une version dont l'API diffère),
-- rien ne casse : la part « Quêtes » ne s'applique simplement pas.
--
-- Source lue : Questie/Questie, branche master, Questie 12.4.0
-- (Questie_Vanilla.toc ## Version: 12.4.0, Questie_Camelot.toc pour Forever).
--   Modules/Libs/QuestieLoader.lua   QuestieLoader:ImportModule(name)
--   Database/QuestieDB.lua           QuestieDB.QuestPointers (table questID -> …,
--                                    liée à l'initialisation de Questie),
--                                    QuestieDB.QueryQuestSingle(id, champ)
--                                    (champs "name", "questLevel", "requiredLevel",
--                                    "requiredRaces", "requiredClasses",
--                                    "zoneOrSort", "requiredSkill", "exclusiveTo"),
--                                    QuestieDB.IsRepeatable / IsDailyQuest /
--                                    IsWeeklyQuest (facultatives),
--                                    QuestieDB.autoBlacklist (facultative)
--   Modules/QuestiePlayer.lua        QuestiePlayer.HasRequiredRace(masque),
--                                    QuestiePlayer.HasRequiredClass(masque)
--   Database/Zones/zoneDB.lua        ZoneDB:GetUiMapIdByAreaId(areaID),
--                                    ZoneDB:GetParentZoneId(areaID) (facultative)
--   Database/Corrections/QuestieCorrections.lua  QuestieCorrections.hiddenQuests
--                                    (valeur "HIDE_ON_MAP" : quête réelle, gardée)
--   Database/Corrections/Holidays/QuestieEvent.lua  QuestieEvent.IsEventQuest(id)
--   Questie.started (Modules/QuestieInit.lua) : false tant que Questie s'initialise
-- Même filtre que ZoneDB.GetZonesWithQuests (onglet « Quêtes par zone » du
-- Journal de Questie), qu'on n'appelle pas : il remplace la table partagée de
-- Questie et range aussi des PNJ parmi les quêtes quand zoneOrSort <= 0.
--
-- zoneOrSort est un areaID (AreaTable), PAS un uiMapID : sous-zone ramenée à sa
-- zone (GetParentZoneId), puis areaID -> uiMapID (GetUiMapIdByAreaId), la clé
-- des zones du carnet (ns:JournalZone).
--
-- Comptées : les quêtes de la zone faisables par CE personnage (race/faction,
-- classe), hors quêtes cachées, d'événement, répétables, journalières,
-- hebdomadaires, de métier, et hors quêtes exclusives dont l'alternative est
-- déjà faite. Le niveau n'exclut rien (100 % strict, choix assumé).
-- Faites : C_QuestLog.IsQuestFlaggedCompleted (ou la globale des vieux clients).
--
-- Coût : l'index zone -> quêtes (~10 000 quêtes à parcourir) est construit une
-- fois par session, au premier besoin, jamais en combat. Le statut « faite »
-- est mis en cache et oublié à chaque QUEST_TURNED_IN / QUEST_LOG_UPDATE.
-- Vit sous le module Compagnon (db.companionEnabled), comme le carnet.
local ADDON, ns = ...
local L = ns.L

local HINT_NAMES = 6

-- ---------------------------------------------------------------------------
-- Chaînes
-- ---------------------------------------------------------------------------
local FR = {
	JRN_PART_quests = "Quêtes",
	QZ_HINT_TODO    = "À faire :",
	QZ_LEVEL        = "niveau %d",
	QZ_QUESTIE_HINT = "Installe Questie pour suivre les quêtes de chaque zone.",
}
local EN = {
	JRN_PART_quests = "Quests",
	QZ_HINT_TODO    = "To do:",
	QZ_LEVEL        = "level %d",
	QZ_QUESTIE_HINT = "Install Questie to track the quests of each zone.",
}
ns.RegisterStrings(FR, EN)
ns.QUESTIE_ZONE_STRINGS = { fr = FR, en = EN }
ns.QUESTIE_HINT = L.QZ_QUESTIE_HINT

-- ---------------------------------------------------------------------------
-- Accès robustes
-- ---------------------------------------------------------------------------
local function Call(name, ...)
	local fn = rawget(_G, name)
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
	return ns.journalTrackerCombat == true or Call("InCombatLockdown") == true
end

-- État de session : index zone -> quêtes, statut « faite » en cache
ns.questieZone = ns.questieZone or { index = nil, builds = 0, done = {} }
local state = ns.questieZone

-- Modules de Questie, nil si l'un manque ou n'a pas la forme attendue
local function Modules()
	local loader = rawget(_G, "QuestieLoader")
	if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then return nil end
	local function Import(name)
		local ok, module = pcall(loader.ImportModule, loader, name)
		if ok and type(module) == "table" then return module end
		return nil
	end
	local db, zones, player = Import("QuestieDB"), Import("ZoneDB"), Import("QuestiePlayer")
	if not db or not zones or not player then return nil end
	if type(db.QueryQuestSingle) ~= "function" or type(db.QuestPointers) ~= "table" then return nil end
	if type(zones.GetUiMapIdByAreaId) ~= "function" then return nil end
	if type(player.HasRequiredRace) ~= "function" or type(player.HasRequiredClass) ~= "function" then return nil end
	return { db = db, zones = zones, player = player,
		corrections = Import("QuestieCorrections"), event = Import("QuestieEvent") }
end

-- Questie chargé, initialisé et à l'API reconnue
function ns:QuestieAvailable()
	local questie = rawget(_G, "Questie")
	if type(questie) == "table" and questie.started == false then return false end
	return Modules() ~= nil
end

-- ---------------------------------------------------------------------------
-- Index zone (uiMapID) -> { questID, … }
-- ---------------------------------------------------------------------------
local function Flag(fn, id)
	if type(fn) ~= "function" then return false end
	local ok, value = pcall(fn, id)
	return ok and value and true or false
end

local function Keep(q, id, hidden)
	local mark = hidden and hidden[id]
	if mark and mark ~= "HIDE_ON_MAP" then return nil end
	if q.event and Flag(q.event.IsEventQuest, id) then return nil end
	if type(q.db.autoBlacklist) == "table" and q.db.autoBlacklist[id] then return nil end
	local Query = q.db.QueryQuestSingle
	local area = tonumber(Query(id, "zoneOrSort"))
	if not area or area <= 0 then return nil end
	if not q.player.HasRequiredRace(Query(id, "requiredRaces")) then return nil end
	if not q.player.HasRequiredClass(Query(id, "requiredClasses")) then return nil end
	if Query(id, "requiredSkill") then return nil end
	if Flag(q.db.IsRepeatable, id) or Flag(q.db.IsDailyQuest, id) or Flag(q.db.IsWeeklyQuest, id) then return nil end
	return area
end

local function UiMap(q, area, memo)
	if memo[area] ~= nil then return memo[area] or nil end
	local zone = area
	if type(q.zones.GetParentZoneId) == "function" then
		local ok, parent = pcall(q.zones.GetParentZoneId, q.zones, area)
		if ok and tonumber(parent) then zone = tonumber(parent) end
	end
	local ok, mapID = pcall(q.zones.GetUiMapIdByAreaId, q.zones, zone)
	mapID = ok and tonumber(mapID) or nil
	memo[area] = mapID or false
	return mapID
end

local function Build()
	local q = Modules()
	if not q then return nil end
	local hidden = q.corrections and type(q.corrections.hiddenQuests) == "table" and q.corrections.hiddenQuests or nil
	local index, memo = {}, {}
	for id in pairs(q.db.QuestPointers) do
		local ok, area = pcall(Keep, q, id, hidden)
		local mapID = ok and area and UiMap(q, area, memo)
		if mapID then
			index[mapID] = index[mapID] or {}
			table.insert(index[mapID], id)
		end
	end
	return index, q
end

-- L'index, construit au premier besoin ; nil en combat tant qu'il n'existe pas
function ns:QuestieIndex()
	if state.index then return state.index end
	if InCombat() or not self:QuestieAvailable() then return nil end
	local ok, index = pcall(Build)
	if not ok or type(index) ~= "table" then
		if not ok and self.RecordError then self:RecordError("questie:index", index) end
		return nil
	end
	state.index = index
	state.builds = state.builds + 1
	return index
end

-- ---------------------------------------------------------------------------
-- Statut
-- ---------------------------------------------------------------------------
local function Completed(id)
	local log = rawget(_G, "C_QuestLog")
	local fn = type(log) == "table" and log.IsQuestFlaggedCompleted or rawget(_G, "IsQuestFlaggedCompleted")
	if type(fn) ~= "function" then return false end
	local ok, value = pcall(fn, id)
	return ok and value == true
end

function ns:QuestieQuestDone(id)
	local cached = state.done[id]
	if cached == nil then
		cached = Completed(id)
		state.done[id] = cached
	end
	return cached
end

-- Une quête exclusive (choix entre deux) dont l'autre branche est faite ne
-- se fera plus : on ne la compte pas
local function Excluded(self, q, id)
	local ok, others = pcall(q.db.QueryQuestSingle, id, "exclusiveTo")
	if not ok or type(others) ~= "table" then return false end
	for _, other in pairs(others) do
		if other ~= id and self:QuestieQuestDone(other) then return true end
	end
	return false
end

local function Level(q, id)
	for _, field in ipairs({ "questLevel", "requiredLevel" }) do
		local ok, value = pcall(q.db.QueryQuestSingle, id, field)
		value = ok and tonumber(value)
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

-- Quêtes de la zone pour ce personnage, triées (à faire d'abord, par niveau),
-- nil si Questie absent, zone inconnue ou aucune quête
function ns:QuestieZoneQuests(zoneID)
	zoneID = tonumber(zoneID)
	if not zoneID or not ModuleOn() then return nil end
	local index = self:QuestieIndex()
	local ids = index and index[zoneID]
	if not ids or #ids == 0 then return nil end
	local q = Modules()
	if not q then return nil end
	local list = {}
	for _, id in ipairs(ids) do
		local done = self:QuestieQuestDone(id)
		if done or not Excluded(self, q, id) then
			local ok, name = pcall(q.db.QueryQuestSingle, id, "name")
			name = (ok and type(name) == "string" and name ~= "") and name or tostring(id)
			list[#list + 1] = { id = id, name = name, done = done, level = Level(q, id) }
		end
	end
	if #list == 0 then return nil end
	table.sort(list, Before)
	return list
end

-- ---------------------------------------------------------------------------
-- Part de complétion « Quêtes »
-- ---------------------------------------------------------------------------
function ns:QuestiePart(zoneID)
	local list = self:QuestieZoneQuests(zoneID)
	if not list then return nil end
	local have, todo = 0, {}
	for _, quest in ipairs(list) do
		if quest.done then have = have + 1 else todo[#todo + 1] = quest.name end
	end
	local hint = {}
	if #todo > 0 then
		hint[1] = L.QZ_HINT_TODO
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

function ns:QuestieItems(zoneID)
	local items = {}
	for _, quest in ipairs(self:QuestieZoneQuests(zoneID) or {}) do
		items[#items + 1] = { id = quest.id, name = quest.name, done = quest.done,
			detail = quest.level and self:F("QZ_LEVEL", quest.level) or nil }
	end
	return items
end

if ns.RegisterZonePart then
	ns.RegisterZonePart({ id = "quests", label = "JRN_PART_quests", tab = "quests",
		Compute = function(self, zoneID) return self:QuestiePart(zoneID) end,
		Items = function(self, zoneID) return self:QuestieItems(zoneID) end })
end

-- ---------------------------------------------------------------------------
-- Événements : le statut « faite » change, l'index non
-- ---------------------------------------------------------------------------
local function Forget() state.done = {} end
local HANDLERS = { QUEST_TURNED_IN = Forget, QUEST_LOG_UPDATE = Forget }

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("questie:" .. tostring(event), err) end
end)
ns.questieEventFrame = eventFrame

if ns.Mark then ns.Mark("QuestieZone") end
