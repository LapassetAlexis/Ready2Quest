-- Carnet de voyage : quêtes de chaque zone, tables livrées (ZoneQuests.lua,
-- ZoneQuests_Forever.lua, v1.25.0). Plus de Questie en jeu.
-- Intégrité des deux tables, contenu réel connu, filtres race / classe,
-- exclusives et quêtes fermées, faites / à faire, liste triée, cache et
-- invalidation, combat, client sans table, fenêtre.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local ROOT = rawget(_G, "ADDON_ROOT") or "."
local MOCKED = { "UnitRace", "UnitClass", "GetLocale", "InCombatLockdown", "IsQuestFlaggedCompleted",
	"IsInInstance", "GetInstanceInfo", "GetRealZoneText", "UnitFactionGroup", "date" }
local saved = {}
for _, name in ipairs(MOCKED) do saved[name] = rawget(_G, name) end
saved.Flagged = C_QuestLog.IsQuestFlaggedCompleted
saved.GetAreaInfo = C_Map.GetAreaInfo
saved.ZONE_QUESTS = rawget(NS, "ZONE_QUESTS")
saved.ZONE_CREATURES, saved.ZONE_GATHERING = rawget(NS, "ZONE_CREATURES"), rawget(NS, "ZONE_GATHERING")
saved.NextUnlocks = rawget(NS, "CompanionNextUnlocks")

local Q = { done = {}, race = 2, class = 1, locale = "frFR", calls = 0 }
_G.UnitRace = function() return "Orc", "Orc", Q.race end
_G.UnitClass = function() return "Guerrier", "WARRIOR", Q.class end
_G.GetLocale = function() return Q.locale end
_G.InCombatLockdown = function() return Q.combat == true end
_G.IsInInstance = function() return false, "none" end
_G.GetInstanceInfo = function() return "Kalimdor", "none", 0, "", 0, 0, false, 0 end
_G.GetRealZoneText = function() return "" end
_G.UnitFactionGroup = function() return "Horde" end
_G.date = function() return "03/11/2026" end
_G.IsQuestFlaggedCompleted = nil
C_QuestLog.IsQuestFlaggedCompleted = function(id) Q.calls = Q.calls + 1; return Q.done[id] == true end
C_Map.GetAreaInfo = nil

-- table de Forever, rechargée avec un faux ns (garde de client). QuestCompanion
-- 1.2.0 : WoW Forever seulement, plus de table d'Era.
function Q.Load(file, forever)
	local fake = { Mark = function() end, IsForeverClient = function() return forever end }
	assert(loadfile(ROOT .. "/QuestCompanion/" .. file))("QuestCompanion", fake)
	return fake.ZONE_QUESTS
end
Q.FOREVER = Q.Load("ZoneQuests_Forever.lua", true)

local MAPS = {
	[947]  = { mapID = 947,  name = "Azeroth", parentMapID = 0, mapType = 1 },
	[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 },
	[1415] = { mapID = 1415, name = "Royaumes de l'Est", parentMapID = 947, mapType = 2 },
	[1411] = { mapID = 1411, name = "Durotar", parentMapID = 1414, mapType = 3 },
	[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 },
	[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 1415, mapType = 3 },
}

function Q.Reset(tableToUse)
	ResetWorld()
	for id, info in pairs(MAPS) do Mock.world.maps[id] = info end
	Mock.world.mapID = 1411
	NS.ZONE_QUESTS = tableToUse == nil and Q.FOREVER or tableToUse or nil
	NS.ZONE_CREATURES, NS.ZONE_GATHERING = nil, nil
	NS.zoneQuests.done, NS.zoneQuests.lists, NS.zoneQuests.builds, NS.zoneQuests.dirty = {}, {}, 0, false
	Q.done, Q.race, Q.class, Q.locale, Q.combat, Q.calls = {}, 2, 1, "frFR", nil, 0
	NS.journalTrackerCombat = nil
	NS:DB().companionEnabled, NS:DB().enabled = nil, nil
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	if NS.journalTracker then NS.journalTracker:Hide() end
	NS.journalTracker = nil
	NS.journalGroups, NS.journalGroupsFor = nil, nil
end

-- même règle que ZoneQuests.lua, écrite autrement (bits par division entière)
local SKYBORNE = { [95] = 33, [96] = 34 }
function Q.Expected(zone, race, class)
	local ids = {}
	for id, quest in pairs(zone) do
		local raceBit = SKYBORNE[race] or race
		local okRace = quest.races == 0 or math.floor(quest.races / 2 ^ (raceBit - 1)) % 2 == 1
		local okClass = quest.classes == 0 or math.floor(quest.classes / 2 ^ (class - 1)) % 2 == 1
		if okRace and okClass then ids[id] = true end
	end
	return ids
end
function Q.Count(set) local n = 0; for _ in pairs(set) do n = n + 1 end; return n end
function Q.Ids(list)
	local set = {}
	for _, item in ipairs(list or {}) do set[item.id] = item end
	return set
end
function Q.Part(zoneID)
	local done = NS:ZoneCompletion(zoneID)
	for _, part in ipairs(done and done.parts or {}) do if part.id == "quests" then return part end end
	return nil
end
function Q.Size(file)
	local handle = assert(io.open(ROOT .. "/QuestCompanion/" .. file, "rb"))
	local size = handle:seek("end")
	handle:close()
	return size
end

-- 1. Chargement, .toc -----------------------------------------------------------------
do
	Say("-- quêtes de zone : chargement")
	Check("[ZQ] ZoneQuests.lua chargé, table du client (Forever dans le harnais)", NS.Loaded and NS.Loaded.ZoneQuests
		and NS.Loaded.ZoneQuests_Forever and saved.ZONE_QUESTS ~= nil
		and saved.ZONE_QUESTS[2521] ~= nil)
	local order = {}
	for index, file in ipairs(_G.TOC_FILES or {}) do order[(file:gsub("^[^/]+/", ""))] = index end
	Check("[ZQ] .toc : tables avant ZoneQuests.lua, après JournalTracker.lua, avant JournalWindow.lua",
		order["ZoneQuests_Forever.lua"] and order["ZoneQuests.lua"] and order["ZoneQuests_Era.lua"] == nil
		and order["Dungeon.lua"] < order["ZoneQuests_Forever.lua"] and order["ZoneQuests_Forever.lua"] < order["ZoneQuests.lua"]
		and order["JournalTracker.lua"] < order["ZoneQuests.lua"] and order["ZoneQuests.lua"] < order["JournalWindow.lua"])
	local toc = ""
	for _, file in ipairs({ "/Ready2Quest/Ready2Quest.toc", "/QuestCompanion/QuestCompanion.toc" }) do
		local handle = assert(io.open(ROOT .. file, "r"))
		toc = toc .. handle:read("*a")
		handle:close()
	end
	Check("[ZQ] .toc : plus de QuestieZone.lua ni de dépendance à Questie", order["QuestieZone.lua"] == nil
		and not toc:find("Questie", 1, true))
	Check("[ZQ] plus d'API Questie dans l'addon", NS.QuestieAvailable == nil and NS.QuestiePart == nil
		and rawget(NS, "QUESTIE_HINT") == nil)
	Check("[ZQ] garde : la table de Forever ne se charge que sur Forever", Q.Load("ZoneQuests_Forever.lua", false) == nil
		and type(Q.FOREVER) == "table")
end

-- 2. Intégrité ------------------------------------------------------------------------
do
	Say("-- quêtes de zone : intégrité")
	local known = { [1450] = true }
	for zoneID in pairs(NS.ZONE_LEVELS or {}) do known[zoneID] = true end
	for _, client in ipairs({ "Forever" }) do
		local data, tag = Q.FOREVER, "[ZQ] " .. client .. " "
		local zones, count, bad, badZones, seen, twice = 0, 0, {}, {}, {}, 0
		local maxRaces = 0
		for zoneID, list in pairs(data) do
			zones = zones + 1
			if not known[zoneID] and not (client == "Forever" and zoneID > 2000) then badZones[#badZones + 1] = zoneID end
			for id, q in pairs(list) do
				count = count + 1
				if seen[id] then twice = twice + 1 end
				seen[id] = true
				local ok = type(id) == "number" and id > 0 and id == math.floor(id)
					and type(q.lvl) == "number" and q.lvl >= -1 and q.lvl <= 63 and q.lvl == math.floor(q.lvl)
					and type(q.req) == "number" and q.req >= 0 and q.req <= 63
					and type(q.races) == "number" and q.races >= 0 and q.races == math.floor(q.races)
					and type(q.classes) == "number" and q.classes >= 0 and q.classes <= 2047
					and type(q.fr) == "string" and q.fr ~= "" and type(q.en) == "string" and q.en ~= ""
				if ok and q.ex ~= nil then
					ok = type(q.ex) == "table" and #q.ex > 0
					for _, other in ipairs(q.ex or {}) do
						ok = ok and type(other) == "number" and other > 0 and other ~= id
					end
				end
				if q.races > maxRaces then maxRaces = q.races end
				if not ok and #bad < 5 then bad[#bad + 1] = zoneID .. ":" .. tostring(id) end
			end
		end
		Check(tag .. "zones et quêtes", zones >= 39 and count > 2000, zones .. "/" .. count)
		Check(tag .. "zones connues (coffre, Reflet-de-Lune, Forever : ses zones)", #badZones == 0,
			table.concat(badZones, ","))
		Check(tag .. "ids, niveaux, masques, noms fr+en, ex", #bad == 0, table.concat(bad, ","))
		Check(tag .. "une quête dans une seule zone", twice == 0, twice)
		Check(tag .. "masques de race avec Skyborne (bits 32 et 33)", maxRaces >= 2 ^ 32 and maxRaces < 2 ^ 34, maxRaces)
	end
	local foreverKB = Q.Size("ZoneQuests_Forever.lua") / 1024
	Check("[ZQ] taille : moins de 500 Ko", foreverKB < 500, string.format("%.0f Ko", foreverKB))
end

-- 3. Contenu réel ---------------------------------------------------------------------
do
	Say("-- quêtes de zone : contenu")
	local fthreat = Q.FOREVER[1429] and Q.FOREVER[1429][783]
	Check("[ZQ] Forever, Elwynn : 783 ouverte aussi aux Skyborne de l'Alliance (2^32)", fthreat
		and fthreat.races == 77 + 2 ^ 32)
	Check("[ZQ] Forever, Durotar : 4641 aussi, Horde + Skyborne de la Horde (2^33)", Q.FOREVER[1411]
		and Q.FOREVER[1411][4641] and Q.FOREVER[1411][4641].en == "Your Place In The World"
		and Q.FOREVER[1411][4641].races == 178 + 2 ^ 33)
	Check("[ZQ] Forever : Île de Zephras (2521), « Coming of Age » (92460)", Q.FOREVER[2521]
		and Q.FOREVER[2521][92460] and Q.FOREVER[2521][92460].en == "Coming of Age")
	Check("[ZQ] exclusives réelles : éclats de gangrechien / d'infernal (4962 <-> 4963)", Q.FOREVER[1413][4962].ex[1] == 4963
		and Q.FOREVER[1413][4963].ex[1] == 4962 and Q.FOREVER[1413][4962].classes == 256)
	-- exclues en amont : cachée, répétable, métier, événement, JcJ
	local function Anywhere(data, id)
		for _, list in pairs(data) do if list[id] then return true end end
		return false
	end
	local absent = true
	for _, id in ipairs({ 787, 5843, 813, 926, 16, 862, 171, 7141 }) do
		absent = absent and not Anywhere(Q.FOREVER, id)
	end
	Check("[ZQ] exclues : cachées (787, 5843), répétables (813, 926, 16), métier (862), événement (171), JcJ (7141)", absent)
end

-- 4. Filtres race / classe --------------------------------------------------------------
do
	Say("-- quêtes de zone : race et classe")
	Q.Reset()
	Check("[ZQ] table chargée : disponible", NS:ZoneQuestsAvailable() == true)
	local list = NS:ZoneQuestList(1411)
	local ids = Q.Ids(list)
	local expected = Q.Expected(Q.FOREVER[1411], 2, 1)
	Check("[ZQ] orc guerrier, Durotar : exactement les quêtes de sa race et de sa classe",
		list and #list == Q.Count(expected) and #list > 30, list and #list)
	local same = true
	for id in pairs(expected) do same = same and ids[id] ~= nil end
	Check("[ZQ] orc guerrier : mêmes ids que le calcul de contrôle", same)
	Check("[ZQ] orc guerrier : 4641 et « Parchemin simple » (2383) ; ni tablette troll (3065) ni parchemin de chasseur (3087)",
		ids[4641] and ids[2383] and not ids[3065] and not ids[3087])
	Q.race, Q.class = 8, 8   -- troll mage
	ids = Q.Ids(NS:ZoneQuestList(1411))
	Check("[ZQ] troll mage : « Tablette glyphée » (3086), plus de parchemin d'orc", ids[3086] and not ids[2383] and ids[4641])
	Check("[ZQ] troll mage : liste à part (cache par race et classe)", #NS:ZoneQuestList(1411)
		== Q.Count(Q.Expected(Q.FOREVER[1411], 8, 8)))
	Q.race, Q.class = 1, 1   -- humain
	Check("[ZQ] humain, Durotar : aucune quête de la Horde", Q.Ids(NS:ZoneQuestList(1411))[4641] == nil)
	Check("[ZQ] humain, Elwynn : « A Threat Within » comptée", Q.Ids(NS:ZoneQuestList(1429))[783] ~= nil)
	-- race inconnue (UnitRace absent) : pas de filtre de race
	_G.UnitRace = nil
	local all = Q.Ids(NS:ZoneQuestList(1429))
	Check("[ZQ] race inconnue : pas de filtre de race", all[783] ~= nil)
	_G.UnitRace = function() return "Orc", "Orc", Q.race end
	-- Forever : Skyborne de l'Alliance (raceID 95, bit 32)
	Q.Reset(Q.FOREVER)
	Q.race, Q.class = 95, 1
	ids = Q.Ids(NS:ZoneQuestList(1429))
	Check("[ZQ] Forever, Skyborne Alliance : Elwynn 783 comptée (bit 2^32, sans bit.band)", ids[783] ~= nil
		and #NS:ZoneQuestList(1429) == Q.Count(Q.Expected(Q.FOREVER[1429], 95, 1)))
	Check("[ZQ] Forever, Skyborne Alliance : pas les quêtes orques de Durotar", Q.Ids(NS:ZoneQuestList(1411))[4641] == nil)
	Q.race = 96
	Check("[ZQ] Forever, Skyborne Horde : Durotar 4641 et 788 comptées",
		Q.Ids(NS:ZoneQuestList(1411))[4641] ~= nil and Q.Ids(NS:ZoneQuestList(1411))[788] ~= nil)
end

-- 5. Faites, à faire, liste, survol -------------------------------------------------------
do
	Say("-- quêtes de zone : faites et à faire")
	Q.Reset()
	local part = NS:ZoneQuestsPart(1411)
	local total = Q.Count(Q.Expected(Q.FOREVER[1411], 2, 1))
	Check("[ZQ] rien de fait : 0/N", part and part.have == 0 and part.need == total, part and (part.have .. "/" .. part.need))
	Check("[ZQ] survol : « À faire : », 6 noms puis « … et N autres »", part.hint[1] == "À faire :" and #part.hint == 8
		and part.hint[2]:find("^  · ") and part.hint[8] == NS:F("JRN_HINT_MORE", total - 6), part.hint[8])
	local items = NS:ZoneQuestsItems(1411)
	Check("[ZQ] Items : tri par niveau, détail « niveau N »", items[1] and items[1].detail == "niveau 1"
		and items[#items].detail:find("^niveau ") ~= nil)
	local sorted = true
	for index = 2, #items do
		local a, b = Q.FOREVER[1411][items[index - 1].id], Q.FOREVER[1411][items[index].id]
		local la = a.lvl > 0 and a.lvl or (a.req > 0 and a.req or 999)
		local lb = b.lvl > 0 and b.lvl or (b.req > 0 and b.req or 999)
		sorted = sorted and la <= lb
	end
	Check("[ZQ] Items : niveaux croissants", sorted)
	Check("[ZQ] noms en français", NS:ZoneQuestsItems(1411)[1] and Q.Ids(items)[4641].name == "Votre place en ce monde")
	-- faites
	Q.done[4641], Q.done[788] = true, true
	Mock:Fire("QUEST_TURNED_IN", 788, 0, 0)
	part = NS:ZoneQuestsPart(1411)
	Check("[ZQ] deux faites : 2/N", part.have == 2 and part.need == total, part.have .. "/" .. part.need)
	items = NS:ZoneQuestsItems(1411)
	Check("[ZQ] Items : faites en fin de liste, détail « faite »", items[#items].done and items[#items - 1].done
		and items[#items].detail == "faite" and not items[1].done)
	Check("[ZQ] survol : les faites n'y sont plus", not table.concat(part.hint, "|"):find("Votre place", 1, true))
	-- langue du client
	Q.locale = "enUS"
	Check("[ZQ] client anglais : noms anglais", Q.Ids(NS:ZoneQuestList(1411))[4641].name == "Your Place In The World")
	Q.locale = "frFR"
	-- vieux client : la globale
	C_QuestLog.IsQuestFlaggedCompleted = nil
	_G.IsQuestFlaggedCompleted = function(id) return id == 783 end
	Q.race = 1
	Mock:Fire("QUEST_LOG_UPDATE")
	Check("[ZQ] vieux client : IsQuestFlaggedCompleted global", NS:ZoneQuestsPart(1429).have == 1)
	_G.IsQuestFlaggedCompleted = nil
	C_QuestLog.IsQuestFlaggedCompleted = function(id) Q.calls = Q.calls + 1; return Q.done[id] == true end
end

-- 6. Exclusives et quêtes fermées ---------------------------------------------------------
do
	Say("-- quêtes de zone : exclusives")
	Q.Reset()
	Q.race, Q.class = 2, 9   -- orc démoniste
	local ids = Q.Ids(NS:ZoneQuestList(1413))
	Check("[ZQ] démoniste : les deux éclats comptent tant qu'aucun n'est fait", ids[4962] and ids[4963])
	local before = NS:ZoneQuestsPart(1413).need
	-- fermées par 4963 : 4962 (exclusive) et les quêtes qui y mènent
	local closed = 0
	for id in pairs(ids) do
		for _, other in ipairs(Q.FOREVER[1413][id].ex or {}) do if other == 4963 then closed = closed + 1 end end
	end
	Q.done[4963] = true
	Mock:Fire("QUEST_TURNED_IN", 4963, 0, 0)
	ids = Q.Ids(NS:ZoneQuestList(1413))
	local part = NS:ZoneQuestsPart(1413)
	Check("[ZQ] exclusive : l'une faite, l'autre ne compte plus", ids[4962] == nil and ids[4963] and ids[4963].done
		and closed >= 1 and part.need == before - closed and part.have == 1, part.need .. " / " .. before .. " - " .. closed)
	-- quête d'approche : la suite faite (7) ferme 783
	Q.Reset()
	Q.race = 1
	Check("[ZQ] humain : 783 à faire", Q.Ids(NS:ZoneQuestList(1429))[783] and not Q.Ids(NS:ZoneQuestList(1429))[783].done)
	Q.done[7] = true
	Mock:Fire("QUEST_LOG_UPDATE")
	ids = Q.Ids(NS:ZoneQuestList(1429))
	Check("[ZQ] suite faite (7) : 783 fermée, plus comptée", ids[783] == nil and ids[7] and ids[7].done)
	Q.done[783] = true
	Mock:Fire("QUEST_LOG_UPDATE")
	Check("[ZQ] faite elle-même : toujours comptée", Q.Ids(NS:ZoneQuestList(1429))[783] ~= nil)
end

-- 7. Cache, invalidation, combat ----------------------------------------------------------
do
	Say("-- quêtes de zone : cache et combat")
	Q.Reset()
	NS:ZoneQuestsPart(1411)
	local builds, calls = NS.zoneQuests.builds, Q.calls
	NS:ZoneQuestsPart(1411)
	NS:ZoneQuestsItems(1411)
	Check("[ZQ] cache : liste réutilisée, statut pas relu", NS.zoneQuests.builds == builds and Q.calls == calls and builds == 1)
	Q.done[4641] = true
	Check("[ZQ] cache : statut gardé sans événement", NS:ZoneQuestsPart(1411).have == 0)
	Mock:Fire("QUEST_TURNED_IN", 4641, 0, 0)
	Check("[ZQ] QUEST_TURNED_IN : cache oublié, recalculé", NS:ZoneQuestsPart(1411).have == 1 and NS.zoneQuests.builds == 2)
	-- combat : l'oubli attend la fin du combat
	Q.combat = true
	Q.done[788] = true
	Mock:Fire("QUEST_LOG_UPDATE")
	local part = NS:ZoneQuestsPart(1411)
	Check("[ZQ] combat : la liste déjà calculée sert, pas de recalcul", part.have == 1 and NS.zoneQuests.builds == 2
		and NS.zoneQuests.dirty == true)
	Q.combat = nil
	NS.journalTrackerCombat = true
	Check("[ZQ] combat (drapeau du suivi) : toujours la liste en cache", NS:ZoneQuestsPart(1411).have == 1)
	NS.journalTrackerCombat = nil
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Check("[ZQ] fin du combat : statut relu", NS:ZoneQuestsPart(1411).have == 2 and NS.zoneQuests.dirty == false)
	-- module coupé
	NS:DB().companionEnabled = false
	Check("[ZQ] module Compagnon coupé : pas de part", NS:ZoneQuestsPart(1411) == nil and #NS:ZoneQuestsItems(1411) == 0)
	NS:DB().companionEnabled = nil
	Check("[ZQ] zone hors table : nil", NS:ZoneQuestsPart(9999) == nil and NS:ZoneQuestList(nil) == nil)
end

-- 8. Part de complétion, client sans table --------------------------------------------------
do
	Say("-- quêtes de zone : complétion et client sans table")
	Q.Reset()
	local def
	for _, d in ipairs(NS.ZONE_PARTS) do if d.id == "quests" then def = d end end
	Check("[ZQ] part enregistrée : onglet quests, libellé JRN_PART_quests, Items", def and def.tab == "quests"
		and def.label == "JRN_PART_quests" and type(def.Items) == "function" and #def.Items(NS, 1411) > 30)
	local part = Q.Part(1411)
	Check("[ZQ] complétion de zone : part « Quêtes »", part and part.label == "Quêtes"
		and part.need == Q.Count(Q.Expected(Q.FOREVER[1411], 2, 1)))
	-- client inconnu : pas de table
	Q.Reset(false)
	Check("[ZQ] client sans table : indisponible", NS:ZoneQuestsAvailable() == false)
	local ok, value = pcall(NS.ZoneQuestsPart, NS, 1411)
	Check("[ZQ] client sans table : pas de part, pas d'erreur", ok and value == nil and Q.Part(1411) == nil
		and #NS:ZoneQuestsItems(1411) == 0)
	NS.ZONE_QUESTS = {}
	Check("[ZQ] table vide : indisponible", NS:ZoneQuestsAvailable() == false)
	-- table abîmée : pas d'erreur
	NS.ZONE_QUESTS = { [1411] = { [1] = "pas une table", [2] = { en = "Sans masque" } } }
	ok, value = pcall(NS.ZoneQuestsPart, NS, 1411)
	Check("[ZQ] entrée abîmée ignorée, entrée sans masque gardée", ok and value and value.need == 1)
	-- chaînes
	local S = NS.ZONE_QUESTS_STRINGS
	local missing = {}
	for key in pairs(S.fr) do if not S.en[key] then missing[#missing + 1] = key end end
	for key in pairs(S.en) do if not S.fr[key] then missing[#missing + 1] = key end end
	Check("[ZQ] chaînes : mêmes clés fr / en", #missing == 0, table.concat(missing, ","))
	Check("[ZQ] chaînes : « Pas de liste de quêtes pour ce client. »", S.fr.ZQ_NO_LIST == "Pas de liste de quêtes pour ce client."
		and NS.L.JRN_ACT_NO_QUESTS == "Pas de liste de quêtes pour ce client.")
	local all = ""
	for _, key in ipairs({ "JRN_ACT_quests", "JRN_QUESTS_TIP", "JRN_ACT_NO_QUESTS", "JRN_ACT_EMPTY_quests", "JRN_PART_quests" }) do
		all = all .. tostring(NS.L[key])
	end
	for _, value in pairs(S.fr) do all = all .. value end
	for _, value in pairs(S.en) do all = all .. value end
	Check("[ZQ] interface : plus aucune mention de Questie", not all:find("Questie", 1, true)
		and rawget(NS.L, "JRN_ACT_quests_off") == nil and rawget(NS.L, "JRN_ACT_NO_QUESTIE") == nil, all)
end

-- 9. Fenêtre ------------------------------------------------------------------------------
do
	Say("-- quêtes de zone : fenêtre")
	Q.Reset()
	NS.CompanionNextUnlocks = function() return {} end
	NS:JournalData().stamps["zone:1411"] = { id = "zone:1411", kind = "zone", name = "Durotar", at = 0 }
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	NS:SelectJournalKind("completion")
	local f = NS.journalFrame
	local comp = f and f.comp
	Check("[ZQ] fenêtre : Durotar", f and f.zoneID == 1411)
	Check("[ZQ] onglet « Quêtes », pas grisé, sans « Questie »", comp.tabs.quests.text.text == "Quêtes"
		and comp.tabs.quests.text.textColor[1] ~= NS.Theme.MUTED[1], comp.tabs.quests.text.text)
	comp.tabs.quests.hooks.OnEnter(comp.tabs.quests)
	local tip = table.concat(_G.GameTooltip.lines or {}, " ")
	Check("[ZQ] survol : ce que l'onglet compte, sans Questie", tip:find(NS.L.JRN_QUESTS_TIP, 1, true) ~= nil
		and not tip:find("Questie", 1, true), tip)
	comp.tabs.quests.hooks.OnLeave(comp.tabs.quests)
	comp.tabs.quests:Click()
	local first = comp.lines[1].name.text
	Check("[ZQ] onglet Quêtes : en-tête puis quêtes à faire", comp.lines[1].item and comp.lines[1].item.header
		and first:find("Quêtes", 1, true) and comp.lines[2].item and not comp.lines[2].item.done
		and comp.lines[2].detail.text:find("niveau", 1, true), first)
	Check("[ZQ] onglet Quêtes : pas de message vide", comp.empty.text == "")
	local function AllDone(want)
		for _, item in ipairs(f.rows) do
			if not item.header and (item.done == true) ~= want then return false end
		end
		return true
	end
	comp.questFilter.todo:Click()
	local todo = #f.rows
	Check("[ZQ] filtre « À faire » : seulement les quêtes à faire", f.questFilter == "todo" and todo > 0 and AllDone(false), todo)
	comp.questFilter.done:Click()
	Check("[ZQ] filtre « Faites » : seulement les faites", AllDone(true))
	comp.questFilter.all:Click()
	Check("[ZQ] « Toutes » : tout revient", #f.rows >= todo)
	NS:ToggleJournal(false)
	-- client sans table : onglet grisé, message clair
	Q.Reset(false)
	NS.CompanionNextUnlocks = function() return {} end
	NS:JournalData().stamps["zone:1411"] = { id = "zone:1411", kind = "zone", name = "Durotar", at = 0 }
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	NS:SelectJournalKind("completion")
	comp = NS.journalFrame.comp
	Check("[ZQ] client sans table : « Quêtes » grisé", comp.tabs.quests.text.text == "Quêtes"
		and comp.tabs.quests.text.textColor[1] == NS.Theme.MUTED[1])
	comp.tabs.quests:Click()
	Check("[ZQ] client sans table : « Pas de liste de quêtes pour ce client. »",
		comp.empty.text == "Pas de liste de quêtes pour ce client.", comp.empty.text)
	NS:ToggleJournal(false)
	NS:DB().journalTracker = nil
end

-- Mocks retirés, tables du client remises
for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
C_QuestLog.IsQuestFlaggedCompleted = saved.Flagged
C_Map.GetAreaInfo = saved.GetAreaInfo
NS.ZONE_QUESTS = saved.ZONE_QUESTS
NS.ZONE_CREATURES, NS.ZONE_GATHERING = saved.ZONE_CREATURES, saved.ZONE_GATHERING
NS.CompanionNextUnlocks = saved.NextUnlocks
NS.zoneQuests.done, NS.zoneQuests.lists, NS.zoneQuests.builds, NS.zoneQuests.dirty = {}, {}, 0, false
NS.journalTrackerCombat = nil
if NS.journalFrame then NS.journalFrame:Hide() end
NS.journalFrame = nil
ResetWorld()
