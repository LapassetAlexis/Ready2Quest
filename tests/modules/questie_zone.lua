-- Carnet de voyage : quêtes de la zone via Questie (QuestieZone.lua, v1.25.0).
-- Faux Questie minimal, de la forme de l'API réelle (Questie 12.4.0) :
-- QuestieLoader:ImportModule, QuestieDB.QuestPointers / QueryQuestSingle,
-- QuestiePlayer.HasRequiredRace / HasRequiredClass (test de bit de Questie),
-- ZoneDB:GetUiMapIdByAreaId / GetParentZoneId, QuestieCorrections.hiddenQuests,
-- QuestieEvent.IsEventQuest.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local saved = {
	QuestieLoader = rawget(_G, "QuestieLoader"), Questie = rawget(_G, "Questie"),
	IsQuestFlaggedCompleted = rawget(_G, "IsQuestFlaggedCompleted"), InCombatLockdown = rawget(_G, "InCombatLockdown"),
	Flagged = C_QuestLog.IsQuestFlaggedCompleted,
}

local Q = { done = {}, queries = 0 }

-- Masques de Questie : PlayableRaceBit (ORC = 2), classes (WARRIOR = 1, MAGE = 128)
local ALLIANCE, HORDE, WARRIOR, MAGE = 1 + 4 + 8 + 64, 2 + 16 + 32 + 128, 1, 128
local QUESTS = {
	[101] = { name = "Sangliers de Durotar", zoneOrSort = 14, questLevel = 5, requiredRaces = HORDE },
	[102] = { name = "Vers Tranchecolline", zoneOrSort = 362, questLevel = 3 },   -- sous-zone de Durotar
	[103] = { name = "Pour l'Alliance", zoneOrSort = 14, questLevel = 4, requiredRaces = ALLIANCE },
	[104] = { name = "Rituel du mage", zoneOrSort = 14, questLevel = 6, requiredClasses = MAGE },
	[105] = { name = "Rituel du guerrier", zoneOrSort = 14, questLevel = 10, requiredClasses = WARRIOR },
	[106] = { name = "Quête cachée", zoneOrSort = 14, questLevel = 4 },
	[107] = { name = "Hors carte", zoneOrSort = 14, questLevel = 8 },
	[108] = { name = "Fête lunaire", zoneOrSort = 14, questLevel = 1 },
	[109] = { name = "Encore des peaux", zoneOrSort = 14, questLevel = 9, specialFlags = 1 },
	[110] = { name = "Journalière", zoneOrSort = 14, questLevel = 9, daily = true },
	[111] = { name = "Herbes rares", zoneOrSort = 14, questLevel = 9, requiredSkill = { 182, 50 } },
	[112] = { name = "Choix A", zoneOrSort = 14, questLevel = 7, exclusiveTo = { 113 } },
	[113] = { name = "Choix B", zoneOrSort = 14, questLevel = 7, exclusiveTo = { 112 } },
	[114] = { name = "Aiguilles", zoneOrSort = 14, requiredLevel = 12 },
	[115] = { name = "Bâton", zoneOrSort = 14, questLevel = 11 },
	[201] = { name = "Loups de la forêt", zoneOrSort = 12, questLevel = 2 },
	[301] = { name = "Quête de classe", zoneOrSort = -81, questLevel = 10 },
}
local DUROTAR_COUNT = 8   -- 101, 102, 105, 107, 112, 113, 114, 115

function Q.Install()
	local modules = {}
	modules.QuestieDB = {
		QuestPointers = {},
		autoBlacklist = {},
		QueryQuestSingle = function(id, key)
			Q.queries = Q.queries + 1
			if Q.broken then error("QuestieDB en panne") end
			local quest = QUESTS[id]
			return quest and quest[key]
		end,
		IsRepeatable = function(id) local q = QUESTS[id]; return q and q.specialFlags == 1 or false end,
		IsDailyQuest = function(id) local q = QUESTS[id]; return q and q.daily == true or false end,
	}
	for id in pairs(QUESTS) do modules.QuestieDB.QuestPointers[id] = 1 end
	local raceFlag, classFlag = 2, WARRIOR
	modules.QuestiePlayer = {
		HasRequiredRace = function(mask) return (not mask) or mask == 0 or (mask % (raceFlag * 2)) >= raceFlag end,
		HasRequiredClass = function(mask) return (not mask) or mask == 0 or (mask % (classFlag * 2)) >= classFlag end,
	}
	local AREA_TO_MAP, PARENT = { [14] = 1411, [12] = 1429 }, { [362] = 14 }
	modules.ZoneDB = {
		GetUiMapIdByAreaId = function(_, areaId) return AREA_TO_MAP[areaId] end,
		GetParentZoneId = function(_, areaId) return PARENT[areaId] end,
	}
	modules.QuestieCorrections = { hiddenQuests = { [106] = true, [107] = "HIDE_ON_MAP" } }
	modules.QuestieEvent = { IsEventQuest = function(id) return id == 108 end }
	Q.modules = modules
	_G.QuestieLoader = {
		ImportModule = function(_, name)
			if Q.importBroken then error("loader en panne") end
			modules[name] = modules[name] or { private = {} }
			return modules[name]
		end,
	}
	_G.Questie = { started = true }
end

function Q.Reset()
	NS.questieZone.index, NS.questieZone.builds, NS.questieZone.done = nil, 0, {}
	Q.done, Q.queries, Q.broken, Q.importBroken = {}, 0, nil, nil
	NS.journalTrackerCombat = nil
	_G.InCombatLockdown = function() return Q.combat == true end
	Q.combat = nil
	NS:DB().companionEnabled, NS:DB().enabled = nil, nil
end

function Q.Names(items)
	local names = {}
	for _, item in ipairs(items) do names[#names + 1] = item.name end
	return table.concat(names, ",")
end

function Q.Part(zoneID, id)
	local done = NS:ZoneCompletion(zoneID)
	for _, part in ipairs(done and done.parts or {}) do
		if part.id == id then return part end
	end
	return nil
end

C_QuestLog.IsQuestFlaggedCompleted = function(id) return Q.done[id] == true end
_G.IsQuestFlaggedCompleted = nil

do
	Say("-- Questie absent")
	ResetWorld()
	_G.QuestieLoader, _G.Questie = nil, nil
	Q.Reset()
	Check("[QZ] sans Questie : indisponible", NS:QuestieAvailable() == false)
	local ok, part = pcall(NS.QuestiePart, NS, 1411)
	Check("[QZ] sans Questie : pas de part, pas d'erreur", ok and part == nil)
	ok = pcall(NS.ZoneCompletion, NS, 1411)
	Check("[QZ] sans Questie : complétion de zone sans erreur", ok and Q.Part(1411, "quests") == nil)
	Check("[QZ] sans Questie : liste vide", #NS:QuestieItems(1411) == 0)
	Check("[QZ] conseil d'installation exposé", type(NS.QUESTIE_HINT) == "string" and NS.QUESTIE_HINT:find("Questie") ~= nil)
	_G.QuestieLoader = { ImportModule = function() return {} end }
	Check("[QZ] Questie sans base (API différente) : indisponible", NS:QuestieAvailable() == false
		and NS:QuestiePart(1411) == nil)
	Q.Install()
	_G.Questie.started = false
	Check("[QZ] Questie en cours d'initialisation : indisponible, pas d'index",
		NS:QuestieAvailable() == false and NS:QuestiePart(1411) == nil and NS.questieZone.builds == 0)
end

do
	Say("-- Quêtes de la zone")
	Q.Install()
	Q.Reset()
	Check("[QZ] Questie installé : disponible", NS:QuestieAvailable() == true)
	local part = NS:QuestiePart(1411)
	Check("[QZ] total des quêtes faisables", part and part.need == DUROTAR_COUNT, part and part.need)
	Check("[QZ] rien de fait", part and part.have == 0)
	local items = NS:QuestieItems(1411)
	local names = Q.Names(items)
	Check("[QZ] filtre faction : quête de l'Alliance exclue", not names:find("Pour l'Alliance", 1, true))
	Check("[QZ] filtre faction : quête de la Horde gardée", names:find("Sangliers de Durotar", 1, true) ~= nil)
	Check("[QZ] filtre classe : mage exclu, guerrier gardé", not names:find("Rituel du mage", 1, true)
		and names:find("Rituel du guerrier", 1, true) ~= nil)
	Check("[QZ] quête cachée exclue, cachée sur la carte gardée", not names:find("Quête cachée", 1, true)
		and names:find("Hors carte", 1, true) ~= nil)
	Check("[QZ] événement, répétable, journalière, métier exclus", not names:find("Fête lunaire", 1, true)
		and not names:find("Encore des peaux", 1, true) and not names:find("Journalière", 1, true)
		and not names:find("Herbes rares", 1, true))
	Check("[QZ] sous-zone ramenée à sa zone", names:find("Vers Tranchecolline", 1, true) ~= nil)
	Check("[QZ] tri par niveau", items[1] and items[1].name == "Vers Tranchecolline" and items[1].detail == "niveau 3"
		and items[#items].name == "Aiguilles" and items[#items].detail == "niveau 12", names)
	Check("[QZ] autre zone : sa propre quête", NS:QuestiePart(1429) and NS:QuestiePart(1429).need == 1)
	Check("[QZ] zone inconnue : nil", NS:QuestiePart(9999) == nil)
	Check("[QZ] quêtes de tri (zoneOrSort négatif) ignorées", not Q.Names(NS:QuestieItems(1429)):find("classe"))
	-- survol : « À faire : » puis 6 noms et « … et 2 autres »
	Check("[QZ] survol : titre", part.hint[1] == "À faire :")
	Check("[QZ] survol : 6 noms puis le reste", #part.hint == 8 and part.hint[2] == "  · Vers Tranchecolline"
		and part.hint[8] == "… et 2 autres", part.hint[8])

	-- complétion de zone
	local zonePart = Q.Part(1411, "quests")
	Check("[QZ] part « Quêtes » dans la complétion", zonePart and zonePart.label == "Quêtes" and zonePart.need == DUROTAR_COUNT)
	local def
	for _, d in ipairs(NS.ZONE_PARTS) do if d.id == "quests" then def = d end end
	Check("[QZ] part enregistrée avec onglet et liste", def and def.tab == "quests" and type(def.Items) == "function"
		and #def.Items(NS, 1411) == DUROTAR_COUNT)

	-- faites + invalidation
	Q.done[101] = true
	Check("[QZ] statut en cache : pas encore vu sans événement", NS:QuestiePart(1411).have == 0)
	Mock:Fire("QUEST_TURNED_IN", 101, 0, 0)
	part = NS:QuestiePart(1411)
	Check("[QZ] QUEST_TURNED_IN : quête comptée faite", part.have == 1 and part.need == DUROTAR_COUNT)
	Q.done[102] = true
	Mock:Fire("QUEST_LOG_UPDATE")
	Check("[QZ] QUEST_LOG_UPDATE : statut relu", NS:QuestiePart(1411).have == 2)
	items = NS:QuestieItems(1411)
	Check("[QZ] faites en fin de liste", items[#items].done == true and items[#items - 1].done == true
		and items[1].done == false and items[#items].name == "Sangliers de Durotar", Q.Names(items))
	Check("[QZ] survol : faites retirées", not table.concat(NS:QuestiePart(1411).hint, "|"):find("Sangliers", 1, true))

	-- exclusives : l'une faite, l'autre ne se fera plus
	Q.done[113] = true
	Mock:Fire("QUEST_TURNED_IN", 113, 0, 0)
	part = NS:QuestiePart(1411)
	Check("[QZ] quête exclusive : l'alternative faite retire l'autre", part.need == DUROTAR_COUNT - 1 and part.have == 3)

	-- cache : index construit une fois
	Check("[QZ] index construit une seule fois", NS.questieZone.builds == 1, NS.questieZone.builds)
	local before = Q.queries
	NS:QuestieIndex()
	Check("[QZ] index réutilisé sans relire la base", Q.queries == before and NS.questieZone.builds == 1)

	-- client sans C_QuestLog.IsQuestFlaggedCompleted : la globale
	C_QuestLog.IsQuestFlaggedCompleted = nil
	_G.IsQuestFlaggedCompleted = function(id) return id == 201 end
	Mock:Fire("QUEST_LOG_UPDATE")
	Check("[QZ] vieux client : IsQuestFlaggedCompleted global", NS:QuestiePart(1429).have == 1)
	C_QuestLog.IsQuestFlaggedCompleted = function(id) return Q.done[id] == true end
	_G.IsQuestFlaggedCompleted = nil

	-- module coupé
	NS:DB().companionEnabled = false
	Check("[QZ] module Compagnon coupé : pas de part", NS:QuestiePart(1411) == nil)
	NS:DB().companionEnabled = nil
end

do
	Say("-- Combat et pannes")
	Q.Install()
	Q.Reset()
	Q.combat = true
	Check("[QZ] combat : pas de construction", NS:QuestiePart(1411) == nil and NS.questieZone.builds == 0)
	Q.combat = nil
	NS.journalTrackerCombat = true
	Check("[QZ] combat (drapeau du suivi) : pas de construction", NS:QuestiePart(1411) == nil and NS.questieZone.builds == 0)
	NS.journalTrackerCombat = nil
	Check("[QZ] hors combat : construit", NS:QuestiePart(1411) ~= nil and NS.questieZone.builds == 1)
	Q.combat = true
	Check("[QZ] combat : l'index existant sert", NS:QuestiePart(1411) and NS:QuestiePart(1411).need == DUROTAR_COUNT
		and NS.questieZone.builds == 1)
	Q.combat = nil

	Q.Reset()
	Q.broken = true
	local ok, part = pcall(NS.QuestiePart, NS, 1411)
	Check("[QZ] base Questie qui plante : nil sans erreur", ok and part == nil)
	ok = pcall(NS.ZoneCompletion, NS, 1411)
	Check("[QZ] base Questie qui plante : complétion sans erreur", ok)
	Q.Reset()
	Q.importBroken = true
	ok, part = pcall(NS.QuestiePart, NS, 1411)
	Check("[QZ] chargeur Questie qui plante : nil sans erreur", ok and part == nil and NS:QuestieAvailable() == false)
	Q.Reset()
	Q.modules.QuestiePlayer.HasRequiredRace = function() error("pas initialisé") end
	ok, part = pcall(NS.QuestiePart, NS, 1411)
	Check("[QZ] QuestiePlayer pas prêt : nil sans erreur", ok and part == nil)
	Q.Reset()
	Q.modules.ZoneDB.GetUiMapIdByAreaId = function() error("cartes absentes") end
	ok, part = pcall(NS.QuestiePart, NS, 1411)
	Check("[QZ] ZoneDB qui plante : nil sans erreur", ok and part == nil)
end

do
	Say("-- Chaînes")
	local S = NS.QUESTIE_ZONE_STRINGS
	Check("[QZ] chaînes fr", S.fr.JRN_PART_quests == "Quêtes" and S.fr.QZ_HINT_TODO == "À faire :"
		and S.fr.QZ_QUESTIE_HINT == "Installe Questie pour suivre les quêtes de chaque zone.")
	Check("[QZ] chaînes en", S.en.JRN_PART_quests == "Quests" and S.en.QZ_LEVEL == "level %d")
	local missing = {}
	for key in pairs(S.fr) do if not S.en[key] then missing[#missing + 1] = key end end
	for key in pairs(S.en) do if not S.fr[key] then missing[#missing + 1] = key end end
	Check("[QZ] mêmes clés fr / en", #missing == 0, table.concat(missing, ","))
	Check("[QZ] libellé de la part actif", NS.L.JRN_PART_quests == "Quêtes")
end

-- Mocks retirés : les autres tests retrouvent un monde sans Questie
_G.QuestieLoader, _G.Questie = saved.QuestieLoader, saved.Questie
_G.IsQuestFlaggedCompleted, _G.InCombatLockdown = saved.IsQuestFlaggedCompleted, saved.InCombatLockdown
C_QuestLog.IsQuestFlaggedCompleted = saved.Flagged
NS.questieZone.index, NS.questieZone.builds, NS.questieZone.done = nil, 0, {}
NS.journalTrackerCombat = nil
ResetWorld()
