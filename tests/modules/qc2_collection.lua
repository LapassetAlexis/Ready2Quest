-- QuestCompanion 2.0, lot 3 « Collection » (MenagerieCollection.lua) :
-- Exploration séparée de la Ménagerie, sceaux de zone (cosmétique du biome,
-- brillantes plus fréquentes), complétion par type, paliers et titres de
-- dresseur, affichage dans la Ménagerie et la page Exploration.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local CC = { saved = {} }
local GLOBALS = { "UnitFactionGroup", "IsInInstance", "GetRealZoneText", "time" }
for _, name in ipairs(GLOBALS) do CC.saved[name] = rawget(_G, name) end
CC.saved.ZONE_CREATURES, CC.saved.ZONE_QUESTS = rawget(NS, "ZONE_CREATURES"), rawget(NS, "ZONE_QUESTS")
CC.saved.SHINY_CHANCE = NS.SHINY_CHANCE

-- deux zones de savane (Tarides, Mulgore) et une forêt (Elwynn)
local ZONES = {
	[1413] = {
		[101] = { lvl = { 10, 12 }, rank = 0, fr = "Zhévra", en = "Zhevra" },
		[102] = { lvl = { 11, 13 }, rank = 0, fr = "Raptor", en = "Raptor" },
		[103] = { lvl = { 14, 14 }, rank = 4, fr = "Rare des plaines", en = "Plains rare" },
		[104] = { lvl = { 63, 63 }, rank = 3, fr = "Boss du monde", en = "World boss" },
	},
	[1412] = { [201] = { lvl = { 5, 6 }, rank = 0, fr = "Kodo", en = "Kodo" } },
	[1429] = { [301] = { lvl = { 2, 3 }, rank = 0, fr = "Loup", en = "Wolf" } },
}

function CC.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "journalFrame", "optionsFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.menagerieStatic, NS.captureAppCache = nil, nil, nil
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1412] = { mapID = 1412, name = "Mulgore", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 1415, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.maps[1415] = { mapID = 1415, name = "Royaumes de l'Est", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	_G.UnitFactionGroup = function() return "Horde" end
	_G.IsInInstance = function() return false, "none" end
	_G.GetRealZoneText = function() return "" end
	_G.time = function() return 1800000000 end
	NS.ZONE_CREATURES, NS.ZONE_QUESTS = ZONES, nil
	local data = NS:CompanionData()
	data.tutoDone, data.capture, data.collection = true, nil, nil
	for key in pairs(data.unlocked) do
		if key:find("seal_", 1, true) or key:find(":trainer", 1, true) or key:find(":master", 1, true)
			or key:find(":menagerie", 1, true) or key:find(":grandmaster", 1, true) then data.unlocked[key] = nil end
	end
	NS:JournalData().bestiary = {}
	NS:TreatData().treatsInit = true
	NS:TreatData().milestones = {}
	NS:DB().journalTracker = false
	NS.SHINY_CHANCE = 1 / 150
end

-- une capture posée dans la fiche (version normale, ou brillante seule)
function CC.Caught(npcID, fields)
	fields = fields or {}
	local entry = { name = fields.name or ("Créature " .. npcID), class = fields.class or "normal", type = fields.type,
		zoneID = fields.zoneID or 1413, normal = not fields.shinyOnly, shiny = fields.shinyOnly or nil, at = 1 }
	local capture = NS:CaptureData()
	if capture.creatures[npcID] == nil then capture.count = capture.count + 1 end
	capture.creatures[npcID] = entry
	return entry
end

-- 1. Chaînes et contrat ----------------------------------------------------------------------------
do
	Say("-- QC 2.0 collection : contrat et chaînes")
	CC.Reset()
	local missing = {}
	for _, name in ipairs({ "MenagerieSealProgress", "MenagerieSealed", "MenagerieSeals", "MenagerieTypeBonus",
		"TrainerTitle", "TrainerTitleKey" }) do
		if type(NS[name]) ~= "function" then missing[#missing + 1] = name end
	end
	Check("[COLL] l'API du contrat est là", #missing == 0, table.concat(missing, ", "))
	local strings, bad = NS.MENAGERIE_COLLECTION_STRINGS, {}
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" then bad[#bad + 1] = "en:" .. key end
		if NS.L[key] ~= value then bad[#bad + 1] = "fr:" .. key end
	end
	for key in pairs(strings.en) do if strings.fr[key] == nil then bad[#bad + 1] = "fr?" .. key end end
	Check("[COLL] chaînes en français et en anglais", #bad == 0, table.concat(bad, ", "))
	local all = ""
	for _, value in pairs(strings.fr) do all = all .. value end
	Check("[COLL] tutoiement", not all:find("[Vv]ous"))
	local labels = true
	for _, item in ipairs(NS.MENAGERIE_COSMETICS) do
		if NS.L[item.def.label] == item.def.label or NS.COMPANION_STRINGS.en[item.def.label] == nil then labels = false end
	end
	Check("[COLL] cosmétiques nommés (registre du compagnon)", labels)
	Check("[COLL] un cadre et un fond par biome, hors coffres", NS:CompanionStyleDef("frame", "seal_savanna")
		and NS:CompanionStyleDef("bg", "seal_forest") and NS:CompanionStyleDef("frame", "seal_savanna").tier == 0
		and NS.L.COMP_FRAME_SEAL_savanna == "Sceau : savane" and NS.L.COMP_BG_SEAL_forest == "Paysage : forêt")
	local inChest = false
	for _, reward in ipairs(NS:ChestRewards()) do
		if tostring(reward.id):find("seal_", 1, true) or reward.id == "trainer" then inChest = true end
	end
	Check("[COLL] aucun dans les coffres de zone", not inChest)
end

-- 2. Exploration et Ménagerie séparées -----------------------------------------------------------
do
	Say("-- QC 2.0 collection : Exploration sans le bestiaire")
	CC.Reset()
	NS:JournalData().bestiary = { [1413] = { [101] = { name = "Zhévra", seen = true, killed = 2 } } }
	local done = NS:ZoneCompletion(1413)
	local ids = {}
	for _, part in ipairs(done and done.parts or {}) do ids[part.id] = true end
	Check("[COLL] % de la zone : ni bestiaire ni nommés", not ids.bestiary and not ids.named and ids.villages,
		done and #done.parts)
	local bestiary
	for _, def in ipairs(NS.ZONE_PARTS) do if def.id == "bestiary" then bestiary = def end end
	Check("[COLL] la part du bestiaire reste déclarée, hors exploration", bestiary and bestiary.exploration == false
		and bestiary.Compute(NS, 1413).have == 1)
	Check("[COLL] bulle d'une espèce abattue : son compte, à part", NS:NotifyPartText(1413, "bestiary") == "bestiaire 1/4",
		NS:NotifyPartText(1413, "bestiary"))
	-- une part d'exploration hors % : ignorée même si elle s'applique
	local fake = { id = "fakeoff", exploration = false, Compute = function() return { have = 0, need = 9 } end }
	NS.RegisterZonePart(fake)
	local again = NS:ZoneCompletion(1413)
	Check("[COLL] exploration = false : hors du pourcentage", again and again.percent == done.percent
		and #again.parts == #done.parts)
	table.remove(NS.ZONE_PARTS, #NS.ZONE_PARTS)
end

-- 3. Sceau de zone ---------------------------------------------------------------------------------
do
	Say("-- QC 2.0 collection : sceau de zone")
	CC.Reset()
	local have, need = NS:MenagerieSealProgress(1413)
	Check("[SEAL] Tarides : 3 espèces, boss du monde à part", have == 0 and need == 3, have .. "/" .. need)
	Check("[SEAL] zone sans liste : pas de sceau", select(2, NS:MenagerieSealProgress(1416)) == 0)
	NS:JournalData().bestiary = { [1413] = { [105] = { name = "Apprise en route", seen = true, killed = 0 } } }
	have, need = NS:MenagerieSealProgress(1413)
	Check("[SEAL] les espèces apprises en route comptent", need == 4, need)
	CC.Caught(101); CC.Caught(102); CC.Caught(105)
	CC.Caught(103, { shinyOnly = true })
	have, need = NS:MenagerieSealProgress(1413)
	Check("[SEAL] la version normale compte, pas la brillante seule", have == 3 and need == 4, have .. "/" .. need)
	Check("[SEAL] pas complète : pas scellée", NS:MenagerieSealCheck(1413) == false and not NS:MenagerieSealed(1413))
	CC.Caught(103)
	Check("[SEAL] complète : scellée", NS:MenagerieSealCheck(1413) == true and NS:MenagerieSealed(1413)
		and NS:MenagerieSeals()[1] == 1413 and #NS:MenagerieSeals() == 1)
	local unlocked = NS:CompanionData().unlocked
	Check("[SEAL] premier sceau du biome : son cadre", unlocked["frame:seal_savanna"] == true
		and not unlocked["bg:seal_savanna"])
	Check("[SEAL] le cadre se porte", NS:CompanionSetStyle("frame", "seal_savanna") ~= nil
		and NS:CompanionCurrentStyle("frame").id == "seal_savanna")
	Check("[SEAL] une fois seulement", NS:MenagerieSealCheck(1413) == false)
	NS:JournalData().bestiary[1413][106] = { name = "Nouvelle venue", seen = true, killed = 0 }
	Check("[SEAL] une espèce de plus ensuite : le sceau reste", NS:MenagerieSealed(1413)
		and select(2, NS:MenagerieSealProgress(1413)) == 5)
	CC.Caught(201, { zoneID = 1412 })
	NS:MenagerieSealCheck(1412)
	Check("[SEAL] deuxième sceau du biome : son paysage en fond", unlocked["bg:seal_savanna"] == true
		and NS:MenagerieBiomeSeals("savanna") == 2)
	Check("[SEAL] biome d'une zone, forêt par défaut", NS:MenagerieZoneBiome(1429) == "forest"
		and NS:MenagerieZoneBiome(99999) == "forest" and NS:MenagerieZoneBiome(1413) == "savanna")
	-- condition lisible d'un cosmétique verrouillé
	Check("[SEAL] condition : sceau d'une zone de ce biome", NS:CompanionLockText(NS:CompanionStyleDef("frame", "seal_forest"))
		== "sceau d'une zone (forêt)" and NS:CompanionLockText(NS:CompanionStyleDef("bg", "seal_forest"))
		== "sceau de deux zones (forêt)", NS:CompanionLockText(NS:CompanionStyleDef("frame", "seal_forest")))
	local locked
	for _, choice in ipairs(NS:CompanionChoices("frame")) do if choice.value == "seal_forest" then locked = choice end end
	Check("[SEAL] liste des cadres : verrouillé, avec sa condition", locked and locked.disabled and locked.hint:find("forêt", 1, true))
	NS:CompanionSetStyle("frame", "slate")
end

-- 4. Brillantes dans une zone scellée ----------------------------------------------------------------
do
	Say("-- QC 2.0 collection : brillantes")
	local base = 1 / 150
	Check("[SEAL] zone scellée : brillantes ×1,5", math.abs(NS:ShinyChance("normal", 0) - base * 1.5) < 1e-12,
		NS:ShinyChance("normal", 0))
	Mock.world.mapID = 1429
	Check("[SEAL] ailleurs : la chance de toujours", math.abs(NS:ShinyChance("normal", 0) - base) < 1e-12)
	Mock.world.mapID = 1413
end

-- 5. Une capture scelle la zone ---------------------------------------------------------------------
do
	Say("-- QC 2.0 collection : après une capture")
	CC.Reset()
	CC.Caught(101); CC.Caught(102)
	NS:MenagerieCollectionData().init = true
	NS:CaptureResolve({ success = true, target = { npcID = 103, name = "Rare des plaines", class = "rare", zoneID = 1413 } })
	Check("[SEAL] la dernière espèce capturée : zone scellée", NS:MenagerieSealed(1413))
	Check("[SEAL] annoncée dans le chat", Mock:Output():find("Sceau de Les Tarides", 1, true) ~= nil)
	CC.Reset()
	NS:MenagerieCollectionData().init = true
	NS:CaptureResolve({ success = false, target = { npcID = 101, name = "Zhévra", class = "normal", zoneID = 1413 } })
	Check("[SEAL] capture ratée : rien", not NS:MenagerieSealed(1413))
end

-- 6. Complétion par type ----------------------------------------------------------------------------
do
	Say("-- QC 2.0 collection : par type")
	CC.Reset()
	Check("[TYPE] rien capturé : force +0", NS:MenagerieTypeBonus("beast") == 0)
	for index = 1, 9 do CC.Caught(1000 + index, { type = "Bête" }) end
	Check("[TYPE] 9 bêtes : pas encore de palier", NS:MenagerieTypeBonus("beast") == 0
		and select(3, NS:MenagerieTypeTier("beast")) == 10)
	-- type inconnu de la fiche : celui que le carnet a appris
	CC.Caught(1010)
	NS:JournalData().bestiary = { [1413] = { [1010] = { name = "Loup", type = "Beast", seen = true, killed = 1 } } }
	Check("[TYPE] 10 bêtes (dont une par le carnet) : palier 1, force +0,25", NS:MenagerieTypeCounts().beast == 10
		and NS:MenagerieTypeBonus("beast") == 0.25, NS:MenagerieTypeCounts().beast)
	for index = 1, 5 do CC.Caught(2000 + index, { type = "Draconien" }) end
	Check("[TYPE] type rare : palier dès 5", NS:MenagerieTypeBonus("dragonkin") == 0.25
		and NS:MenagerieTypeTiers("dragonkin")[3] == 20)
	local gained = NS:MenagerieTypeCheck()
	Check("[TYPE] paliers annoncés une fois", #gained == 2 and #NS:MenagerieTypeCheck() == 0
		and Mock:Output():find("palier 1", 1, true) ~= nil)
	for index = 11, 40 do CC.Caught(1000 + index, { type = "Bête" }) end
	Check("[TYPE] 40 bêtes : dernier palier, force +0,75", NS:MenagerieTypeBonus("beast") == 0.75
		and select(3, NS:MenagerieTypeTier("beast")) == nil)
	Check("[TYPE] type inconnu : 0", NS:MenagerieTypeBonus(nil) == 0 and NS:MenagerieTypeBonus("critter") == 0)
	Check("[TYPE] décimale à la française", NS.MenagerieDecimal(0.25) == "0,25" and NS.MenagerieDecimal(1.5) == "1,5"
		and NS.MenagerieDecimal(2) == "2")
end

-- 7. Paliers globaux et titres -----------------------------------------------------------------------
do
	Say("-- QC 2.0 collection : titres de dresseur")
	CC.Reset()
	NS:MenagerieCollectionData().init = true
	Check("[RANK] aucun titre au départ", NS:TrainerTitle() == nil and NS:TrainerTitleKey() == nil)
	for index = 1, 9 do CC.Caught(3000 + index) end
	Check("[RANK] 9 espèces : toujours rien", NS:TrainerTitle() == nil and #NS:MenagerieRankCheck() == 0)
	local items = NS:CaptureData().items
	local appat, lasso = items.appat, items.lasso
	CC.Caught(3010, { shinyOnly = true })
	Check("[RANK] 10 espèces (une brillante seule compte) : Apprenti dresseur", NS:TrainerTitle() == "Apprenti dresseur"
		and NS:TrainerTitleKey() == "apprentice")
	local gained = NS:MenagerieRankCheck()
	Check("[RANK] récompense : un appât et un lasso", #gained == 1 and items.appat == appat + 1 and items.lasso == lasso + 1)
	Check("[RANK] une seule fois", #NS:MenagerieRankCheck() == 0 and items.appat == appat + 1)
	for index = 11, 25 do CC.Caught(3000 + index) end
	NS:MenagerieRankCheck()
	Check("[RANK] 25 espèces : Dresseur, et son insigne", NS:TrainerTitle() == "Dresseur"
		and NS:CompanionData().unlocked["frame:trainer"] == true)
	Check("[RANK] condition lisible de l'insigne suivant", NS:CompanionLockText(NS:CompanionStyleDef("frame", "master"))
		== "100 espèces capturées")
	Check("[RANK] cinq paliers : 10, 25, 50, 100, 250", #NS.TRAINER_RANKS == 5 and NS.TRAINER_RANKS[5].count == 250
		and NS.L["TRAINER_" .. NS.TRAINER_RANKS[5].key] == "Grand maître dresseur")
	Check("[RANK] ce que rapporte un palier", NS:TrainerRankGift(NS.TRAINER_RANKS[3]):find("Enclos de la ménagerie", 1, true) ~= nil,
		NS:TrainerRankGift(NS.TRAINER_RANKS[3]))
end

-- 8. Rattrapage des captures d'avant (données sauvegardées) --------------------------------------------
do
	Say("-- QC 2.0 collection : rattrapage")
	CC.Reset()
	for index = 1, 12 do CC.Caught(4000 + index, { type = "Bête" }) end
	CC.Caught(101); CC.Caught(102); CC.Caught(103)
	local sealed, types, ranks = NS:MenagerieCollectionCatchUp()
	Check("[CATCH] une fois : sceaux, types et titres posés en silence", sealed == 1 and types == 1 and ranks == 1
		and NS:MenagerieSealed(1413) and NS:MenagerieCollectionData().init == true)
	Check("[CATCH] un seul message de résumé", Mock:Output():find("Ménagerie : 1 sceaux", 1, true) ~= nil
		and not Mock:Output():find("Sceau de Les Tarides", 1, true))
	Check("[CATCH] pas deux fois", NS:MenagerieCollectionCatchUp() == nil)
	CC.Reset()
	NS:RefreshJournalTracker()
	Check("[CATCH] au premier recalcul du suivi", NS:MenagerieCollectionData().init == true)
	-- tables paresseuses : le rattrapage ne garde pas les zones qu'il lit
	CC.Reset()
	local makers = {}
	for zoneID, zone in pairs(ZONES) do makers[zoneID] = function() return zone end end
	NS.ZONE_CREATURES = NS.LazyZones(makers)
	CC.Caught(101); CC.Caught(102); CC.Caught(103)
	CC.Caught(201, { zoneID = 1412 })
	local sealed = NS:MenagerieCollectionCatchUp()
	Check("[CATCH] tables paresseuses : sceaux posés, zones pas gardées", sealed == 2 and NS:MenagerieSealed(1412)
		and rawget(NS.ZONE_CREATURES, 1413) == nil and rawget(NS.ZONE_CREATURES, 1412) == nil, tostring(sealed))
	Check("[CATCH] … lecture ordinaire ensuite : gardée", NS:BestiaryStaticZone(1429) ~= nil
		and rawget(NS.ZONE_CREATURES, 1429) ~= nil)
	NS.ZONE_CREATURES = ZONES
end

-- 8 bis. Le suivi (chaque monstre abattu) ne revérifie pas le sceau pour rien ---------------------------
do
	Say("-- QC 2.0 collection : sceau vérifié au changement seulement")
	CC.Reset()
	CC.Caught(101)
	NS:MenagerieCollectionData().init = true
	NS.menagerieSealSeen = nil
	local checks, progress = 0, NS.MenagerieSealProgress
	NS.MenagerieSealProgress = function(...) checks = checks + 1; return progress(...) end
	NS:RefreshJournalTracker()
	NS:RefreshJournalTracker()
	NS:RefreshJournalTracker()
	Check("[SEAL] suivi rafraîchi trois fois : une seule vérification", checks == 1, checks)
	local capture = NS:CaptureData()
	capture.serial = (tonumber(capture.serial) or 0) + 1
	NS:RefreshJournalTracker()
	Check("[SEAL] … refaite quand les captures changent", checks == 2, checks)
	Mock.world.mapID = 1412
	NS:RefreshJournalTracker()
	Check("[SEAL] … et au changement de zone", checks == 3, checks)
	NS.MenagerieSealProgress = progress
	Mock.world.mapID = 1413
end

-- 9. Affichage : Ménagerie et Exploration -------------------------------------------------------------
do
	Say("-- QC 2.0 collection : affichage")
	CC.Reset()
	NS:MenagerieCollectionData().init = true
	CC.Caught(101)
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	NS:OpenMenagerieZone(1413)
	local strip = f.men.collection
	Check("[UI] bandeau de la collection dans la Ménagerie", strip ~= nil and strip:IsShown())
	Check("[UI] sceau de la zone choisie et sa progression", strip.title.text == "Sceau de Les Tarides : 1/3 espèces"
		and strip.bar:IsShown(), strip.title.text)
	Check("[UI] ce que donne le sceau", strip.detail.text:find("Sceau : savane", 1, true) and strip.detail.text:find("×1,5", 1, true),
		strip.detail.text)
	Check("[UI] titre : pas encore, le premier à viser", strip.trainer.text == "Pas encore de titre · 1/10 espèces pour « Apprenti dresseur »",
		strip.trainer.text)
	strip.onEnter(strip)
	local tip = table.concat(_G.GameTooltip.lines or {}, " | ")
	Check("[UI] survol : paliers par type et titres", tip:find("Bête", 1, true) and tip:find("Grand maître dresseur", 1, true), tip)
	strip.onLeave(strip)
	local rows = f.men.items
	local last = rows[#rows]
	local lastBottom = select(5, last:GetPoint()) - last:GetHeight()
	Check("[UI] la liste s'arrête au-dessus du bandeau", lastBottom >= select(5, strip:GetPoint()),
		lastBottom .. " / " .. select(5, strip:GetPoint()))
	Check("[UI] bandeau au-dessus de la pagination", select(5, strip:GetPoint()) - strip:GetHeight() > NS.JournalUI.PAGER_Y)
	CC.Caught(102); CC.Caught(103)
	NS:RefreshJournal()
	Check("[UI] zone complète : scellée en ouvrant la Ménagerie", NS:MenagerieSealed(1413)
		and strip.title.text == "Les Tarides scellée" and strip.accent:IsShown(), strip.title.text)
	f.menZone = "all"
	NS:RefreshJournal()
	Check("[UI] toutes les zones : le compte des sceaux", strip.title.text == "Sceaux : 1 zones scellées" and not strip.bar:IsShown(),
		strip.title.text)
	-- page Exploration : la ligne du sceau
	NS:OpenJournalZone(1413)
	local prog = f.prog
	Check("[UI] Exploration : la zone scellée", prog.bestiary.text == "Zone scellée : brillantes ×1,5 ici"
		and prog.bestiary.textColor[1] == NS.Theme.GOLD[1], prog.bestiary.text)
	NS:OpenJournalZone(1412)
	Check("[UI] Exploration : le sceau à faire", prog.bestiary.text:find("Sceau de la zone : 0/1", 1, true) == 1, prog.bestiary.text)
	f:Hide()
end

-- 10. Paliers d'exploration déjà gagnés : acquis -----------------------------------------------------
do
	Say("-- QC 2.0 collection : paliers acquis")
	CC.Reset()
	local fake = { id = "fakeq", label = "JRN_PART_quests", tab = "quests",
		Compute = function(_, zoneID) if zoneID == 1413 then return { have = 0, need = 10 } end end }
	NS.RegisterZonePart(fake)
	-- avant la 2.0, le bestiaire avait porté la zone à 50 % : friandises réclamées
	NS:TreatData().milestones[1413] = 50
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	NS:OpenJournalZone(1413)
	local prog = f.prog
	local done = NS:ZoneCompletion(1413)
	Check("[KEEP] le % a baissé", done and done.percent < 25, done and done.percent)
	Check("[KEEP] 25 et 50 restent franchis, pas 75", prog.marks[1].reached and prog.marks[2].reached
		and not prog.marks[3].reached and not prog.marks[4].reached)
	Check("[KEEP] pas de friandise en double", #NS:TreatCheckZone(1413) == 0 and NS:TreatData().milestones[1413] == 50)
	NS:ChestData()[1413] = { tier = 1, name = "Les Tarides", opened = true }
	NS:RefreshJournal()
	Check("[KEEP] coffre déjà gagné : 100 franchi", prog.marks[4].reached and prog.marks[4].gift.text == "coffre ouvert")
	Check("[KEEP] pas de second coffre", NS:ChestCheck(1413) == nil)
	NS:ChestData()[1413] = nil
	f:Hide()
	for index = #NS.ZONE_PARTS, 1, -1 do if NS.ZONE_PARTS[index] == fake then table.remove(NS.ZONE_PARTS, index) end end
end

-- remise en état
CC.Reset()
for _, name in ipairs(GLOBALS) do _G[name] = CC.saved[name] end
NS.ZONE_CREATURES, NS.ZONE_QUESTS = CC.saved.ZONE_CREATURES, CC.saved.ZONE_QUESTS
NS.SHINY_CHANCE = CC.saved.SHINY_CHANCE
NS.menagerieStatic = nil
NS.journalFrame = nil
local data = NS:CompanionData()
data.capture, data.collection = nil, nil
NS:JournalData().bestiary = nil
