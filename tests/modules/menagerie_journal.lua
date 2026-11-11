-- La Ménagerie dans le carnet (QuestCompanion 2.0 → 3.0).
--   1. Collection (MenagerieCollection.lua) : Exploration séparée du bestiaire,
--      sceaux de zone (cosmétiques du biome, brillantes ×1,5), paliers par type,
--      titres de dresseur, rattrapage des captures d'avant, bandeau de la page
--      Créatures, paliers d'exploration déjà gagnés gardés.
--   2. Page Créatures (MenagerieView.lua, ns:MenagerieList) : trois paliers,
--      une inconnue jamais dévoilée (recherche, types), boutons de type, tri par
--      abattues, brillante reconnue sans capture, modèle qui tourne.
--   3. Carnet de la 3.0 : relâcher jamais au-dessus du Codex, « À compléter »,
--      épingles, Localiser, Exploration « n à compléter », Réserve (grille, tri,
--      filtres, fiche, Mettre au Codex, Relâcher confirmé, pleine), Échoppe du
--      dresseur, paillettes des missions et paliers, colonne de navigation,
--      encres mesurées et textes.
--   4. Exploration (2.9.1, retours en jeu) : titres des quêtes dans la langue du
--      client, encres mesurées des quêtes et des zones, roue crantée du carnet.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- 1. Collection ----------------------------------------------------------------------------------------
do
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

	-- 1.1 Chaînes et cosmétiques
	do
		Say("-- collection : chaînes et cosmétiques")
		CC.Reset()
		local strings, bad = NS.MENAGERIE_COLLECTION_STRINGS, {}
		for key, value in pairs(strings.fr) do
			if type(strings.en[key]) ~= "string" or strings.en[key] == "" then bad[#bad + 1] = "en:" .. key end
			if NS.L[key] ~= value then bad[#bad + 1] = "fr:" .. key end
			if value:find("[Vv]ous") then bad[#bad + 1] = "vous:" .. key end
		end
		for key in pairs(strings.en) do if strings.fr[key] == nil then bad[#bad + 1] = "fr?" .. key end end
		Check("[COLL] chaînes en français (tutoiement) et en anglais", #bad == 0, table.concat(bad, ", "))
		local labels = true
		for _, item in ipairs(NS.MENAGERIE_COSMETICS) do
			if NS.L[item.def.label] == item.def.label or NS.COMPANION_STRINGS.en[item.def.label] == nil then labels = false end
		end
		local inChest = false
		for _, reward in ipairs(NS:ChestRewards()) do
			if tostring(reward.id):find("seal_", 1, true) or reward.id == "trainer" then inChest = true end
		end
		Check("[COLL] cosmétiques nommés, un cadre et un fond par biome, aucun dans les coffres", labels and not inChest
			and NS:CompanionStyleDef("frame", "seal_savanna") and NS:CompanionStyleDef("bg", "seal_forest")
			and NS:CompanionStyleDef("frame", "seal_savanna").tier == 0
			and NS.L.COMP_FRAME_SEAL_savanna == "Sceau : savane" and NS.L.COMP_BG_SEAL_forest == "Paysage : forêt")
	end

	-- 1.2 Exploration et Ménagerie séparées
	do
		Say("-- collection : Exploration sans le bestiaire")
		CC.Reset()
		NS:JournalData().bestiary = { [1413] = { [101] = { name = "Zhévra", seen = true, killed = 2 } } }
		local done = NS:ZoneCompletion(1413)
		local ids = {}
		for _, part in ipairs(done and done.parts or {}) do ids[part.id] = true end
		local bestiary
		for _, def in ipairs(NS.ZONE_PARTS) do if def.id == "bestiary" then bestiary = def end end
		Check("[COLL] % de la zone : ni bestiaire ni nommés ; la part du bestiaire reste déclarée, hors exploration",
			not ids.bestiary and not ids.named and ids.villages and bestiary and bestiary.exploration == false
			and bestiary.Compute(NS, 1413).have == 1, done and #done.parts)
		Check("[COLL] bulle d'une espèce abattue : son compte, à part", NS:NotifyPartText(1413, "bestiary") == "bestiaire 1/4",
			NS:NotifyPartText(1413, "bestiary"))
		local fake = { id = "fakeoff", exploration = false, Compute = function() return { have = 0, need = 9 } end }
		NS.RegisterZonePart(fake)
		local again = NS:ZoneCompletion(1413)
		Check("[COLL] exploration = false : hors du pourcentage", again and again.percent == done.percent
			and #again.parts == #done.parts)
		table.remove(NS.ZONE_PARTS, #NS.ZONE_PARTS)
	end

	-- 1.3 Sceau de zone
	do
		Say("-- collection : sceau de zone")
		CC.Reset()
		local have, need = NS:MenagerieSealProgress(1413)
		Check("[SEAL] Tarides : 3 espèces (boss du monde à part) ; zone sans liste : pas de sceau", have == 0 and need == 3
			and select(2, NS:MenagerieSealProgress(1416)) == 0, have .. "/" .. need)
		NS:JournalData().bestiary = { [1413] = { [105] = { name = "Apprise en route", seen = true, killed = 0 } } }
		have, need = NS:MenagerieSealProgress(1413)
		Check("[SEAL] les espèces apprises en route comptent", need == 4, need)
		CC.Caught(101); CC.Caught(102); CC.Caught(105)
		CC.Caught(103, { shinyOnly = true })
		have, need = NS:MenagerieSealProgress(1413)
		Check("[SEAL] la version normale compte, pas la brillante seule : pas scellée", have == 3 and need == 4
			and NS:MenagerieSealCheck(1413) == false and not NS:MenagerieSealed(1413), have .. "/" .. need)
		CC.Caught(103)
		local sealed = NS:MenagerieSealCheck(1413) == true and NS:MenagerieSealed(1413)
			and NS:MenagerieSeals()[1] == 1413 and #NS:MenagerieSeals() == 1
		local unlocked = NS:CompanionData().unlocked
		Check("[SEAL] complète : scellée, le cadre du biome (pas encore le fond), il se porte", sealed
			and unlocked["frame:seal_savanna"] == true and not unlocked["bg:seal_savanna"]
			and NS:CompanionSetStyle("frame", "seal_savanna") ~= nil and NS:CompanionCurrentStyle("frame").id == "seal_savanna")
		local once = NS:MenagerieSealCheck(1413) == false
		NS:JournalData().bestiary[1413][106] = { name = "Nouvelle venue", seen = true, killed = 0 }
		Check("[SEAL] une fois seulement ; une espèce de plus ensuite : le sceau reste", once and NS:MenagerieSealed(1413)
			and select(2, NS:MenagerieSealProgress(1413)) == 5)
		CC.Caught(201, { zoneID = 1412 })
		NS:MenagerieSealCheck(1412)
		Check("[SEAL] deuxième sceau du biome : son paysage en fond", unlocked["bg:seal_savanna"] == true
			and NS:MenagerieBiomeSeals("savanna") == 2)
		Check("[SEAL] biome d'une zone, forêt par défaut", NS:MenagerieZoneBiome(1429) == "forest"
			and NS:MenagerieZoneBiome(99999) == "forest" and NS:MenagerieZoneBiome(1413) == "savanna")
		local locked
		for _, choice in ipairs(NS:CompanionChoices("frame")) do if choice.value == "seal_forest" then locked = choice end end
		Check("[SEAL] condition lisible, liste des cadres : verrouillé avec sa condition",
			NS:CompanionLockText(NS:CompanionStyleDef("frame", "seal_forest")) == "sceau d'une zone (forêt)"
			and NS:CompanionLockText(NS:CompanionStyleDef("bg", "seal_forest")) == "sceau de deux zones (forêt)"
			and locked and locked.disabled and locked.hint:find("forêt", 1, true),
			NS:CompanionLockText(NS:CompanionStyleDef("frame", "seal_forest")))
		NS:CompanionSetStyle("frame", "slate")
		-- brillantes dans la zone scellée
		local base = 1 / 150
		local inSealed = NS:ShinyChance("normal", 0)
		Mock.world.mapID = 1429
		Check("[SEAL] zone scellée : brillantes ×1,5 ; ailleurs, la chance de toujours", math.abs(inSealed - base * 1.5) < 1e-12
			and math.abs(NS:ShinyChance("normal", 0) - base) < 1e-12, inSealed)
		Mock.world.mapID = 1413
	end

	-- 1.4 Une capture scelle la zone
	do
		Say("-- collection : après une capture")
		CC.Reset()
		CC.Caught(101); CC.Caught(102)
		NS:MenagerieCollectionData().init = true
		NS:CaptureResolve({ success = true, target = { npcID = 103, name = "Rare des plaines", class = "rare", zoneID = 1413 } })
		Check("[SEAL] la dernière espèce capturée : zone scellée, annoncée", NS:MenagerieSealed(1413)
			and Mock:Output():find("Sceau de Les Tarides", 1, true) ~= nil)
		CC.Reset()
		NS:MenagerieCollectionData().init = true
		NS:CaptureResolve({ success = false, target = { npcID = 101, name = "Zhévra", class = "normal", zoneID = 1413 } })
		Check("[SEAL] capture ratée : rien", not NS:MenagerieSealed(1413))
	end

	-- 1.5 Complétion par type
	do
		Say("-- collection : par type")
		CC.Reset()
		local none = NS:MenagerieTypeBonus("beast") == 0
		for index = 1, 9 do CC.Caught(1000 + index, { type = "Bête" }) end
		Check("[TYPE] rien, puis 9 bêtes : force +0, pas encore de palier", none and NS:MenagerieTypeBonus("beast") == 0
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
		Check("[TYPE] 40 bêtes : dernier palier, force +0,75 ; type inconnu : 0", NS:MenagerieTypeBonus("beast") == 0.75
			and select(3, NS:MenagerieTypeTier("beast")) == nil and NS:MenagerieTypeBonus(nil) == 0
			and NS:MenagerieTypeBonus("critter") == 0)
		Check("[TYPE] décimale à la française", NS.MenagerieDecimal(0.25) == "0,25" and NS.MenagerieDecimal(1.5) == "1,5"
			and NS.MenagerieDecimal(2) == "2")
	end

	-- 1.6 Paliers globaux et titres
	do
		Say("-- collection : titres de dresseur")
		CC.Reset()
		NS:MenagerieCollectionData().init = true
		local fresh = NS:TrainerTitle() == nil and NS:TrainerTitleKey() == nil
		for index = 1, 9 do CC.Caught(3000 + index) end
		Check("[RANK] aucun titre au départ, ni à 9 espèces", fresh and NS:TrainerTitle() == nil and #NS:MenagerieRankCheck() == 0)
		local items = NS:CaptureData().items
		local appat, lasso = items.appat, items.lasso
		CC.Caught(3010, { shinyOnly = true })
		Check("[RANK] 10 espèces (une brillante seule compte) : Apprenti dresseur", NS:TrainerTitle() == "Apprenti dresseur"
			and NS:TrainerTitleKey() == "apprentice")
		local gained = NS:MenagerieRankCheck()
		Check("[RANK] récompense une seule fois : un appât et un lasso", #gained == 1 and items.lasso == lasso + 1
			and #NS:MenagerieRankCheck() == 0 and items.appat == appat + 1)
		for index = 11, 25 do CC.Caught(3000 + index) end
		NS:MenagerieRankCheck()
		Check("[RANK] 25 espèces : Dresseur et son insigne ; condition lisible du suivant", NS:TrainerTitle() == "Dresseur"
			and NS:CompanionData().unlocked["frame:trainer"] == true
			and NS:CompanionLockText(NS:CompanionStyleDef("frame", "master")) == "100 espèces capturées")
		Check("[RANK] cinq paliers (10 → 250) et ce qu'ils rapportent", #NS.TRAINER_RANKS == 5 and NS.TRAINER_RANKS[5].count == 250
			and NS.L["TRAINER_" .. NS.TRAINER_RANKS[5].key] == "Grand maître dresseur"
			and NS:TrainerRankGift(NS.TRAINER_RANKS[3]):find("Enclos des créatures", 1, true) ~= nil,
			NS:TrainerRankGift(NS.TRAINER_RANKS[3]))
	end

	-- 1.7 Rattrapage des captures d'avant (données sauvegardées)
	do
		Say("-- collection : rattrapage")
		CC.Reset()
		for index = 1, 12 do CC.Caught(4000 + index, { type = "Bête" }) end
		CC.Caught(101); CC.Caught(102); CC.Caught(103)
		local sealed, types, ranks = NS:MenagerieCollectionCatchUp()
		Check("[CATCH] une fois : sceaux, types et titres posés en silence, un seul résumé", sealed == 1 and types == 1 and ranks == 1
			and NS:MenagerieSealed(1413) and NS:MenagerieCollectionData().init == true
			and Mock:Output():find("Créatures : 1 sceaux", 1, true) ~= nil and not Mock:Output():find("Sceau de Les Tarides", 1, true))
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
		local lazy = NS:MenagerieCollectionCatchUp()
		Check("[CATCH] tables paresseuses : sceaux posés, zones pas gardées ; lecture ordinaire ensuite : gardée", lazy == 2
			and NS:MenagerieSealed(1412) and rawget(NS.ZONE_CREATURES, 1413) == nil and rawget(NS.ZONE_CREATURES, 1412) == nil
			and NS:BestiaryStaticZone(1429) ~= nil and rawget(NS.ZONE_CREATURES, 1429) ~= nil, tostring(lazy))
		NS.ZONE_CREATURES = ZONES
	end

	-- 1.8 Le suivi (chaque monstre abattu) ne revérifie pas le sceau pour rien
	do
		Say("-- collection : sceau vérifié au changement seulement")
		CC.Reset()
		CC.Caught(101)
		NS:MenagerieCollectionData().init = true
		NS.menagerieSealSeen = nil
		local checks, progress = 0, NS.MenagerieSealProgress
		NS.MenagerieSealProgress = function(...) checks = checks + 1; return progress(...) end
		NS:RefreshJournalTracker(); NS:RefreshJournalTracker(); NS:RefreshJournalTracker()
		local idle = checks
		local capture = NS:CaptureData()
		capture.serial = (tonumber(capture.serial) or 0) + 1
		NS:RefreshJournalTracker()
		local onCapture = checks
		Mock.world.mapID = 1412
		NS:RefreshJournalTracker()
		Check("[SEAL] suivi rafraîchi trois fois : une vérification ; refaite aux captures et au changement de zone",
			idle == 1 and onCapture == 2 and checks == 3, idle .. "/" .. onCapture .. "/" .. checks)
		NS.MenagerieSealProgress = progress
		Mock.world.mapID = 1413
	end

	-- 1.9 Affichage : Créatures et Exploration
	do
		Say("-- collection : affichage")
		CC.Reset()
		NS:MenagerieCollectionData().init = true
		CC.Caught(101)
		NS:ToggleJournal(true)
		local f = NS.journalFrame
		NS:OpenMenagerieZone(1413)
		local strip = f.men.collection
		Check("[UI] bandeau des Créatures : sceau de la zone, ce qu'il donne, le titre à viser", strip ~= nil and strip:IsShown()
			and strip.title.text == "Sceau de Les Tarides : 1/3 espèces" and strip.bar:IsShown()
			and strip.detail.text:find("Sceau : savane", 1, true) and strip.detail.text:find("×1,5", 1, true)
			and strip.trainer.text == "Pas encore de titre · 1/10 espèces pour « Apprenti dresseur »", strip and strip.title.text)
		strip.onEnter(strip)
		local tip = table.concat(_G.GameTooltip.lines or {}, " | ")
		Check("[UI] survol : paliers par type et titres", tip:find("Bête", 1, true) and tip:find("Grand maître dresseur", 1, true), tip)
		strip.onLeave(strip)
		local rows = f.men.items
		local last = rows[#rows]
		local lastBottom = select(5, last:GetPoint()) - last:GetHeight()
		Check("[UI] le bandeau tient entre la liste et la pagination", lastBottom >= select(5, strip:GetPoint())
			and select(5, strip:GetPoint()) - strip:GetHeight() > NS.JournalUI.PAGER_Y, lastBottom .. " / " .. select(5, strip:GetPoint()))
		CC.Caught(102); CC.Caught(103)
		NS:RefreshJournal()
		local sealedTitle = strip.title.text
		local sealedNow = NS:MenagerieSealed(1413) and strip.accent:IsShown()
		f.menZone = "all"
		NS:RefreshJournal()
		Check("[UI] zone complète : scellée en ouvrant la page ; toutes zones : le compte des sceaux", sealedNow
			and sealedTitle == "Les Tarides scellée" and strip.title.text == "Sceaux : 1 zones scellées" and not strip.bar:IsShown(),
			sealedTitle .. " / " .. strip.title.text)
		NS:OpenJournalZone(1413)
		local prog = f.prog
		local sealedLine = prog.bestiary.text == "Zone scellée : brillantes ×1,5 ici" and prog.bestiary.textColor[1] == NS.Theme.GOLD[1]
		NS:OpenJournalZone(1412)
		Check("[UI] Exploration : la zone scellée, ou le sceau à faire", sealedLine
			and prog.bestiary.text:find("Sceau de la zone : 0/1", 1, true) == 1, prog.bestiary.text)
		f:Hide()
	end

	-- 1.10 Paliers d'exploration déjà gagnés : acquis
	do
		Say("-- collection : paliers acquis")
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
		Check("[KEEP] le % a baissé : 25 et 50 restent franchis, pas 75", done and done.percent < 25 and prog.marks[1].reached
			and prog.marks[2].reached and not prog.marks[3].reached and not prog.marks[4].reached, done and done.percent)
		Check("[KEEP] pas de friandise en double", #NS:TreatCheckZone(1413) == 0 and NS:TreatData().milestones[1413] == 50)
		NS:ChestData()[1413] = { tier = 1, name = "Les Tarides", opened = true }
		NS:RefreshJournal()
		Check("[KEEP] coffre déjà gagné : 100 franchi, pas de second coffre", prog.marks[4].reached
			and prog.marks[4].gift.text == "coffre ouvert" and NS:ChestCheck(1413) == nil)
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
end

-- 2. Page Créatures --------------------------------------------------------------------------------------
do
	local MV = {}
	function MV.Reset()
		ResetWorld()
		for _, field in ipairs({ "companionFrame", "companionBubble", "journalFrame" }) do
			if NS[field] then NS[field]:Hide() end
			NS[field] = nil
		end
		NS.companionRT = nil
		Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
		Mock.world.mapID, Mock.world.level = 1413, 20
		local data = NS:CompanionData()
		NS:DB().capture, NS.captureMergedChar = nil, nil; data.tutoDone, data.capture = true, nil
		NS:TreatData().treatsInit = true
		NS:CompanionUpdateVisibility()
	end
	local function Lines(preview)
		local out = {}
		for _, line in ipairs(preview.lines) do out[#out + 1] = line.text or "" end
		return table.concat(out, " | ")
	end
	local function Row(pane, npc)
		for _, cell in ipairs(pane.items) do
			if cell:IsShown() and cell.entry and cell.entry.npc == npc then return cell end
		end
	end
	local function Shown(pane)
		local out = {}
		for _, cell in ipairs(pane.items) do
			if cell:IsShown() and cell.entry then out[#out + 1] = cell.entry.npc end
		end
		return out
	end
	local function Search(pane, text)
		pane.search:SetText(text)
		if pane.search.scripts and pane.search.scripts.OnTextChanged then pane.search.scripts.OnTextChanged(pane.search) end
		Mock:RunTimers()   -- 2.11.0 : recherche à la fin de la frappe
	end

	Say("-- créatures : paliers, recherche, types")
	MV.Reset()
	local savedTable, savedFaction = rawget(NS, "ZONE_CREATURES"), NS.BestiaryFaction
	local savedShiny = NS.ShinyKnown
	NS.BestiaryFaction = function() return "H" end
	NS.ZONE_CREATURES = {
		[1413] = {
			[3201] = { lvl = { 10, 11 }, rank = 0, fr = "Kodo", en = "Kodo" },
			[3202] = { lvl = { 12, 13 }, rank = 1, fr = "Raptor", en = "Raptor" },
			[3203] = { lvl = { 14, 15 }, rank = 4, fr = "Esprit secret", en = "Secret spirit" },
			[3204] = { lvl = { 16, 17 }, rank = 0, fr = "Golem", en = "Golem" },
		},
	}
	NS.menagerieStatic = nil
	-- croisées : le kodo (capturé), le raptor (vu, jamais abattu), le golem
	-- (abattu deux fois) ; l'esprit, jamais croisé, reste verrouillé
	NS:BestiaryData()[1413] = {
		[3201] = { name = "Kodo des plaines", seen = true, killed = 4, type = "Bête", level = 11 },
		[3202] = { name = "Raptor tranchant", seen = true, killed = 0, type = "Bête", level = 12 },
		[3204] = { name = "Golem de fer", seen = true, killed = 2, type = "Mécanique", level = 16 },
	}
	local data = NS:CaptureData()
	data.creatures[3201] = { name = "Kodo des plaines", class = "normal", type = "Bête", zoneID = 1413, at = 1700000000 }
	data.count = 1
	-- la brillante du raptor a été repérée : reconnue sans capture
	NS.ShinyKnown = function(_, npc) if tonumber(npc) == 3202 then return 1700000500 end return savedShiny and savedShiny(NS, npc) end

	-- 2.1 Données : types, comptes, recherche, tri
	local all, stats = NS:MenagerieList({ zone = 1413 })
	local by = {}
	for _, e in ipairs(all) do by[e.npc] = e end
	Check("[MV] trois paliers (verrouillée, croisée, capturée), type d'une inconnue jamais dit", not by[3203].known
		and by[3202].known and not by[3202].captured and by[3201].captured and by[3203].typeKey == nil
		and by[3201].typeKey == "beast" and by[3204].typeKey == "mechanical")
	Check("[MV] comptes par type (croisées seulement)", stats.types.beast and stats.types.beast.known == 2
		and stats.types.beast.captured == 1 and stats.types.mechanical.known == 1 and stats.types.mechanical.captured == 0
		and stats.types.demon == nil)
	local beasts = NS:MenagerieList({ zone = 1413, ctype = "beast" })
	Check("[MV] filtres de type : Bêtes, Mécanique, rien de croisé, « Tous »", #beasts == 2 and beasts[1].typeKey == "beast"
		and beasts[2].typeKey == "beast" and #NS:MenagerieList({ zone = 1413, ctype = "mechanical" }) == 1
		and #NS:MenagerieList({ zone = 1413, ctype = "demon" }) == 0 and #NS:MenagerieList({ zone = 1413, ctype = "all" }) == 4)
	local leaked = {}
	for _, key in ipairs(NS.CREATURE_TYPES) do
		for _, e in ipairs(NS:MenagerieList({ zone = 1413, ctype = key })) do if e.npc == 3203 then leaked[#leaked + 1] = key end end
	end
	if #NS:MenagerieList({ zone = 1413, search = "esprit" }) > 0 then leaked[#leaked + 1] = "recherche" end
	if #NS:MenagerieList({ zone = "all", search = "secret" }) > 0 then leaked[#leaked + 1] = "recherche (toutes zones)" end
	Check("[MV] une inconnue : dans aucun type, introuvable par son nom", #leaked == 0, table.concat(leaked, ", "))
	local byKills = NS:MenagerieList({ zone = 1413, sort = "kills" })
	Check("[MV] recherche d'une croisée, avec le type ; tri par abattues", #NS:MenagerieList({ zone = 1413, search = "raptor" }) == 1
		and #NS:MenagerieList({ zone = 1413, search = "raptor", ctype = "beast" }) == 1
		and #NS:MenagerieList({ zone = 1413, search = "kodo", ctype = "mechanical" }) == 0
		and #NS:MenagerieList({ zone = 1413, search = "golem", ctype = "mechanical" }) == 1
		and byKills[1].npc == 3201 and byKills[2].npc == 3204)

	-- 2.2 La page : rangées, fiches des trois paliers
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.menZone, f.menState, f.menRank, f.menSearch, f.menSort, f.menType = "here", "all", "all", "", "no", nil
	f.sections.menagerie:Click()
	local pane = f.men
	local kills = false
	for _, option in ipairs(pane.sort.options or {}) do if option.value == "kills" then kills = true end end
	local locked, seen, golem, caught = Row(pane, 3203), Row(pane, 3202), Row(pane, 3204), Row(pane, 3201)
	-- 2.11.0 (fiche 08) : la rareté d'une espèce jamais croisée n'est plus dite
	local muted = NS.Theme.MUTED_LIGHT
	Check("[MV] verrouillée : « ??? » en gris clair, point d'interrogation, case sombre ; tri « abattues » proposé", kills
		and locked and locked.label.text == "???" and locked.icon.texture == "Interface\\Icons\\INV_Misc_QuestionMark"
		and locked.bg.vertex and locked.bg.vertex[1] == NS.Theme.FIELD[1] and locked.detail.text == ""
		and locked.label.textColor[1] == muted[1] and locked.label.textColor[2] == muted[2])
	Check("[MV] croisée : nom et type ; capturée : liseré vert ; brillante reconnue : losange au trait", seen
		and seen.label.text == "Raptor tranchant" and seen.detail.text == "Bête" and caught and caught.caught:IsShown()
		and not seen.caught:IsShown() and not locked.caught:IsShown() and seen.star:IsShown() and seen.star.clientRole == "diamondLine")
	locked.hooks.OnEnter(locked)
	local p = pane.preview
	local text = Lines(p)
	Check("[MV] fiche verrouillée : ni nom, ni niveau, ni modèle ; la zone où la chercher", p.title.text == "???"
		and p.lines[1].text == NS.L.MENV_LOCKED and not text:find("Esprit", 1, true) and not text:find("14", 1, true)
		and p.model.creature == nil and not p.variant:IsShown() and text:find("Les Tarides", 1, true) ~= nil
		and text:find(NS.L.JRN_MEN_NEVER, 1, true) ~= nil, text)
	golem.hooks.OnEnter(golem)
	text = Lines(p)
	Check("[MV] fiche croisée : nom, niveau, modèle, abattues, effets", p.title.text == "Golem de fer" and text:find("16", 1, true)
		and text:find(NS:F("JRN_MEN_KILLED", 2), 1, true) and p.model.creature == 3204 and text:find("Chasse", 1, true) ~= nil, text)
	seen.hooks.OnEnter(seen)
	Check("[MV] brillante reconnue : bouton « Version brillante »", p.variant:IsShown()
		and Lines(p):find("Brillante repérée", 1, true) ~= nil, Lines(p))
	caught.hooks.OnEnter(caught)
	text = Lines(p)
	Check("[MV] fiche capturée : capture, équiper, effets", p.title.text == "Kodo des plaines" and p.model.creature == 3201
		and (text:find("Capturée le", 1, true) or text:find("Qualité", 1, true))
		and text:find(NS.L.JRN_MEN_EQUIP, 1, true) ~= nil and text:find("Chasse", 1, true) ~= nil, text)
	pane.zone:Choose("all")
	locked = Row(pane, 3203)
	Check("[MV] toutes zones : la verrouillée dit sa zone", locked and locked.detail.text == "Les Tarides", locked and locked.detail.text)
	pane.zone:Choose("here")

	-- 2.3 Boutons de type
	local types = pane.types
	local first = pane.items[1]
	local rowBottom = select(5, types:GetPoint()) - types:GetHeight()
	Check("[MV] rangée de types : « Tous » choisi et 8 boutons (icônes du jeu), la liste dessous", types and types.all
		and #types.buttons == 8 and types.buttons.beast and types.buttons.mechanical and types.all.selected
		and not types.buttons.beast.selected and types.buttons.beast.icon.texture:find("^Interface\\Icons\\") ~= nil
		and select(5, first:GetPoint()) <= rowBottom - 4, select(5, first:GetPoint()) .. " / " .. rowBottom)
	types.buttons.beast.scripts.OnEnter(types.buttons.beast)
	local tip = table.concat(_G.GameTooltip.lines or {}, " | ")
	types.buttons.beast.scripts.OnLeave(types.buttons.beast)
	types.buttons.demon.scripts.OnEnter(types.buttons.demon)
	local tipNone = table.concat(_G.GameTooltip.lines or {}, " | ")
	types.buttons.demon.scripts.OnLeave(types.buttons.demon)
	Check("[MV] infobulles : type et compte, ou jamais croisé", tip:find("Bête", 1, true) and tip:find("1 capturées · 2 croisées", 1, true)
		and tipNone:find(NS.L.MENV_TYPE_NONE, 1, true) ~= nil and types.buttons.demon.empty, tip)
	types.buttons.beast:Click()
	local shown = Shown(pane)
	local beastOnly = f.menType == "beast" and #shown == 2 and types.buttons.beast.selected and not types.all.selected
		and types.summary.text == "Bête : 1 capturées / 2 croisées"
	Search(pane, "raptor")
	local found = Shown(pane)
	Search(pane, "esprit")
	Check("[MV] clic sur Bête : les Bêtes, filtre écrit ; recherche + type ; une inconnue reste introuvable", beastOnly
		and #found == 1 and found[1] == 3202 and #Shown(pane) == 0, table.concat(found, ","))
	pane.search:SetText("")
	if pane.search.scripts and pane.search.scripts.OnTextChanged then pane.search.scripts.OnTextChanged(pane.search) end
	types.buttons.beast:Click()
	local off = f.menType == nil and types.all.selected and #Shown(pane) == 4
	types.buttons.mechanical:Click()
	shown = Shown(pane)
	local mech = f.menType == "mechanical" and #shown == 1 and shown[1] == 3204
	types.all:Click()
	Check("[MV] second clic : filtre enlevé ; Mécanique : le golem ; « Tous » : tout revient", off and mech
		and f.menType == nil and #Shown(pane) == 4 and types.summary.text == "")
	types.buttons.beast:Click()
	NS:OpenMenagerieZone(1413)
	Check("[MV] ouverte depuis une zone : filtre de type oublié", f.menType == nil and types.all.selected)

	-- 2.4 Le modèle tourne à la souris
	local model = p.model
	local wired = model.qcRotate == true and model.scripts.OnMouseDown ~= nil
	Mock.world.cursorX = 500
	model.scripts.OnMouseDown(model, "LeftButton")
	local during = model.scripts.OnUpdate ~= nil and model.dragX == 500
	Mock.world.cursorX = 560
	model.scripts.OnUpdate(model)
	model.scripts.OnMouseUp(model, "LeftButton")
	Check("[MV] modèle : glisser branché, suivi pendant le geste seulement", wired and during
		and model.scripts.OnUpdate == nil and model.dragX == nil)
	Mock.world.cursorX = nil

	f:Hide()
	NS.ZONE_CREATURES, NS.BestiaryFaction, NS.menagerieStatic, NS.ShinyKnown = savedTable, savedFaction, nil, savedShiny
	ResetWorld()

	local strings = NS.MENAGERIE_VIEW_STRINGS
	local same = strings ~= nil
	for key in pairs(strings and strings.fr or {}) do if not strings.en[key] then same = false end end
	for key in pairs(strings and strings.en or {}) do if not strings.fr[key] then same = false end end
	Check("[MV] textes : mêmes clés en français et en anglais", same)
end

-- 3. Carnet de la 3.0 ------------------------------------------------------------------------------------
do
	local J = { saved = {} }
	local GLOBALS = { "UnitLevel", "C_Map", "UiMapPoint", "C_SuperTrack", "InCombatLockdown", "UnitAffectingCombat",
		"OpenWorldMap", "C_Timer" }
	for _, name in ipairs(GLOBALS) do J.saved[name] = rawget(_G, name) end
	local FIELDS = { "journalFrame", "trainerFrame", "companionFrame", "companionBubble", "effectsConfirm" }
	local INK = NS.AZEROTH_INK
	local ZONE, OTHER = 1413, 1411
	local savedPos = NS.ZONE_CREATURE_POS

	-- Un petit catalogue : quatre espèces des Tarides, une de Durotar
	local function Catalog()
		local function Item(npc, no, name, zones) return { npc = npc, no = no, staticName = name, class = "normal", lo = 10, hi = 12,
			zones = zones, zoneOrder = 1 } end
		local list = { Item(900, 1, "Raptor", { ZONE }), Item(901, 2, "Kodo", { ZONE }), Item(902, 3, "Hyène", { ZONE }),
			Item(903, 4, "Grue", { ZONE }), Item(904, 5, "Sanglier", { OTHER }) }
		local byNpc = {}
		for _, item in ipairs(list) do byNpc[item.npc] = item end
		NS.menagerieStatic = { faction = NS.BestiaryFaction and NS:BestiaryFaction() or nil, byNpc = byNpc, list = list,
			count = #list, zones = { OTHER, ZONE } }
	end

	function J.Reset(style)
		ResetWorld()
		for _, field in ipairs(FIELDS) do
			if NS[field] then NS[field]:Hide() end
			NS[field] = nil
		end
		NS.effectsConfirmByStyle, NS.uiStyleCache, NS.errors, NS.carnetInkMisses = nil, {}, {}, nil
		NS.mapPin, NS.captureAppCache, NS.specimenCountCache, NS.codexReserveCache, NS.codexZoneCache = nil, nil, nil, nil, nil
		NS:DB().journalState, NS:DB().capture, NS:DB().journalTab = nil, nil, nil
		NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
		Mock.world.maps[ZONE] = { mapID = ZONE, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
		Mock.world.maps[OTHER] = { mapID = OTHER, name = "Durotar", parentMapID = 1414, mapType = 3 }
		Mock.world.mapID, Mock.world.level = ZONE, 20
		_G.UnitLevel = function() return 20 end
		_G.InCombatLockdown = function() return false end
		_G.UnitAffectingCombat = function() return false end
		_G.C_Timer = nil
		if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
		NS:AzerothAtlasOK(true)
		NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
		NS:CompanionData().tutoDone = true
		NS:CompanionData().appearance = nil
		Catalog()
		-- capturées : Raptor 3 étoiles, Kodo 1, Grue 3 (brillante 2) ; Hyène jamais vue ; Sanglier 3
		local data = NS:CaptureData()
		data.creatures[900] = { name = "Raptor", normal = true, stars = 3, zoneID = ZONE, type = "Bête", at = 1793000000 }
		data.creatures[901] = { name = "Kodo", normal = true, stars = 1, zoneID = ZONE, type = "Bête", at = 1793000100 }
		data.creatures[903] = { name = "Grue", normal = true, stars = 3, shiny = true, shinyStars = 2, zoneID = ZONE, type = "Bête" }
		data.creatures[904] = { name = "Sanglier", normal = true, stars = 3, zoneID = OTHER, type = "Bête" }
		data.count = 4
		local book = NS:BestiaryData()
		book[ZONE] = { [900] = { name = "Raptor", seen = true, type = "Bête" }, [901] = { name = "Kodo", seen = true, type = "Bête" },
			[903] = { name = "Grue", seen = true, type = "Bête" } }
		book[OTHER] = { [904] = { name = "Sanglier", seen = true, type = "Bête" } }
		NS:SpecimenMigrate()
		NS.ZONE_CREATURE_POS = { [ZONE] = "900\t300700\n901\t450550\n" }
	end

	function J.Done()
		for _, name in ipairs(GLOBALS) do _G[name] = J.saved[name] end
		for _, field in ipairs(FIELDS) do
			if NS[field] then NS[field]:Hide() end
			NS[field] = nil
		end
		NS.uiStyleCache, NS.mapPin, NS.menagerieStatic = {}, nil, nil
		NS.codexReserveCache, NS.codexZoneCache = nil, nil
		NS:DB().journalState, NS:DB().capture, NS:DB().journalTab = nil, nil, nil
		NS.ZONE_CREATURE_POS = savedPos
		ResetWorld()
	end

	-- l'API du repère, simulée ; `here` : la zone où tu es
	local function PinApi(here)
		local pins = { set = 0, clear = 0, track = 0 }
		_G.UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
		-- le reste de C_Map (noms des zones) vient du monde simulé
		local map = {}
		for key, fn in pairs(J.saved.C_Map or {}) do map[key] = fn end
		map.SetUserWaypoint = function(point) pins.point = point; pins.set = pins.set + 1 end
		map.ClearUserWaypoint = function() pins.point = nil; pins.clear = pins.clear + 1 end
		map.HasUserWaypoint = function() return pins.point ~= nil end
		map.CanSetUserWaypointOnMap = function() return true end
		map.GetBestMapForUnit = function() return here end
		_G.C_Map = map
		_G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) if on then pins.track = pins.track + 1 end end }
		_G.OpenWorldMap = function(id) pins.opened = id end
		return pins
	end

	local function Open(kind)
		local frame = NS:ToggleJournal(true)
		if kind then NS:SelectJournalKind(kind) end
		return NS.journalFrame or frame
	end
	local function RowOf(pane, npc)
		for _, row in ipairs(pane.items) do if row.entry and row.entry.npc == npc and row:IsShown() then return row end end
		return nil
	end
	local function TileOf(rv, id)
		for _, tile in ipairs(rv.tiles) do if tile:IsShown() and tile.spec and tile.spec.id == id then return tile end end
		return nil
	end
	local function ShownTiles(rv)
		local n = 0
		for _, tile in ipairs(rv.tiles) do if tile:IsShown() then n = n + 1 end end
		return n
	end
	local function PreviewText(lines)
		local t = {}
		for _, line in ipairs(lines) do t[#t + 1] = tostring(line:GetText() or "") end
		return table.concat(t, "\n")
	end
	local function NoErrors() return next(NS.errors or {}) == nil end

	-- 3.1 Relâcher : jamais au-dessus du Codex
	do
		Say("-- carnet 3.0 : relâcher ne baisse jamais tes étoiles")
		J.Reset("sobre")
		local ref = NS:SpecimenReference(901, false)
		local three = NS:SpecimenAdd({ npc = 901, stars = 3, name = "Kodo", origin = "capture", by = "Dyokrion", zone = ZONE })
		local swapped = NS:SpecimenIsReference(three) and not NS:SpecimenIsReference(ref.id)
		NS:SpecimenSetReference(ref.id)
		local ok, why = NS:SpecimenCanRelease(three)
		Check("[J215] meilleur spécimen au Codex ; 3 étoiles en Réserve, Codex à 1 : relâcher refusé, raison dite", swapped
			and ok == false and why == "better" and (NS.L.SPECIMEN_ERR_better or ""):find("Codex", 1, true) ~= nil
			and NS.L.RES_WHY_better == "Mets-le au Codex avant de le relâcher.")
		local equal = NS:SpecimenAdd({ npc = 901, stars = 1, name = "Kodo" })
		Check("[J215] même qualité que le Codex : permis", NS:SpecimenCanRelease(equal) == true)
		J.Done()
	end

	-- 3.2 Créatures : « À compléter », « Épinglées »
	do
		Say("-- carnet 3.0 : À compléter, épingles")
		J.Reset("sobre")
		PinApi(ZONE)
		local list, stats = NS:MenagerieList({ zone = ZONE, state = "todo" })
		local ids = {}
		for _, item in ipairs(list) do ids[item.npc] = true end
		Check("[J215] À compléter : Kodo 1★, Hyène pas capturée, Grue brillante 2★ (pas le Raptor 3★)", #list == 3
			and ids[901] and ids[902] and ids[903] and not ids[900] and stats.todo == 3 and stats.pinned == 0
			and #NS:MenagerieList({ zone = ZONE, state = "captured" }) == 3, #list)
		NS:HuntPin(900, true)
		list, stats = NS:MenagerieList({ zone = ZONE, state = "pinned" })
		Check("[J215] Épinglées : la liste de chasse", #list == 1 and list[1].npc == 900 and stats.pinned == 1)
		local f = Open("menagerie")
		local pane = f.men
		f.menZone = ZONE
		pane.states.todo:GetScript("OnClick")(pane.states.todo)
		Check("[J215] puce À compléter : trois lignes, compte dédié", pane.states.pinned and f.menState == "todo"
			and RowOf(pane, 901) and RowOf(pane, 902) and not RowOf(pane, 900)
			and (pane.count:GetText() or ""):find("3 à compléter", 1, true) ~= nil, pane.count:GetText())
		local row = RowOf(pane, 901)
		Check("[J215] ligne connue : épingle et Localiser ; espèce jamais vue : pas d'épingle", row.pin:IsShown()
			and row.locate:IsShown() and not row.pin.on and not RowOf(pane, 902).pin:IsShown())
		Mock:Reset()
		row.pin:GetScript("OnClick")(row.pin)
		row = RowOf(pane, 901)
		Check("[J215] clic sur l'épingle : épinglée, ligne mise en évidence, chat", NS:HuntPinned(901) and row.pin.on
			and row.mark:IsShown() and Mock:Output():find("Kodo", 1, true) ~= nil)
		pane.states.pinned:GetScript("OnClick")(pane.states.pinned)
		local both = RowOf(pane, 900) and RowOf(pane, 901) and not RowOf(pane, 903)
		row = RowOf(pane, 901)
		row.pin:GetScript("OnClick")(row.pin)
		Check("[J215] Épinglées : Raptor et Kodo ; 2e clic : retirée", both and not NS:HuntPinned(901) and not RowOf(pane, 901))
		-- fiche : Réserve et état
		NS:SpecimenAdd({ npc = 900, stars = 1, name = "Raptor" })
		NS:JournalPreviewMenagerie(RowOf(pane, 900).entry)
		local text = PreviewText(pane.preview.lines)
		Check("[J215] fiche : « En Réserve : 1 · Épinglée »", text:find("En Réserve : 1 · Épinglée", 1, true) ~= nil, text)
		local detail = RowOf(pane, 900).detail:GetText()
		f.menZone = "all"
		NS:RefreshJournal()
		Check("[J215] ligne : « Réserve 1 » à la place du type, la zone devant en toutes zones", detail == "Réserve 1"
			and RowOf(pane, 900).detail:GetText() == "Les Tarides · Réserve 1", RowOf(pane, 900).detail:GetText())
		Check("[J215] aucune erreur du carnet", NoErrors())
		J.Done()
	end

	-- 3.3 Localiser : repère, flèche, carte de la zone
	do
		Say("-- carnet 3.0 : Localiser")
		J.Reset("sobre")
		local pins = PinApi(OTHER)
		local set, zone = NS:LocateSpecies(901, { OTHER, ZONE })
		Check("[J215] point de l'espèce (1re zone qui en a un) ; tu es ailleurs : la carte s'ouvre sur sa zone", set == true
			and zone == ZONE and pins.point.map == ZONE and math.abs(pins.point.x - 0.45) < 1e-9 and pins.track == 1
			and pins.opened == ZONE)
		Check("[J215] 2e clic : repère retiré", NS:LocateSpecies(901, ZONE) == false and pins.clear == 1)
		pins = PinApi(ZONE)
		NS:LocateSpecies(900, ZONE)
		local here = pins.set == 1 and pins.opened == nil
		NS:LocateSpecies(900, ZONE)
		Check("[J215] dans sa zone : flèche seulement ; espèce sans point : rien", here and NS:LocateSpecies(903, ZONE) == false
			and pins.set == 1)
		_G.InCombatLockdown = function() return true end
		pins = PinApi(OTHER)
		NS:LocateSpecies(901, ZONE)
		Check("[J215] en combat : repère posé, carte pas ouverte", pins.set == 1 and pins.opened == nil)
		_G.InCombatLockdown = function() return false end
		pins = PinApi(OTHER)
		NS.mapPin = nil
		local f = Open("menagerie")
		f.menZone, f.menState = ZONE, "todo"
		NS:RefreshJournal()
		local row = RowOf(f.men, 901)
		row.locate:GetScript("OnClick")(row.locate)
		Check("[J215] ligne : Localiser pose le repère et ouvre la carte ; sans point : pas d'icône", pins.set == 1
			and pins.opened == ZONE and RowOf(f.men, 901).locate.on and not RowOf(f.men, 903).locate:IsShown())
		J.Done()
	end

	-- 3.4 Exploration : « n à compléter », clic vers les Créatures
	do
		Say("-- carnet 3.0 : Exploration")
		J.Reset("sobre")
		local counts = NS:CodexZoneCounts(ZONE)
		local other = NS:CodexZoneCounts(OTHER)
		Check("[J215] comptes de zone (4 espèces, 3 à compléter, 1 à capturer), gardés ; zone toute en 3★ : complète",
			counts.total == 4 and counts.todo == 3 and counts.missing == 1 and not counts.complete
			and NS:CodexZoneCounts(ZONE) == counts and other.total == 1 and other.todo == 0 and other.complete)
		NS:SpecimenAdd({ npc = 901, stars = 3, name = "Kodo" })
		Check("[J215] un spécimen de plus : recompté", NS:CodexZoneCounts(ZONE).todo == 2)
		NS:ToggleJournal(true)
		NS:OpenJournalZone(ZONE)
		local f = NS.journalFrame
		local tag = f.prog.todoTag
		Check("[J215] tag « 2 à compléter » sur la zone", tag:IsShown() and tag.label:GetText() == "2 à compléter" and not tag.complete,
			tag.label:GetText())
		tag:GetScript("OnClick")(tag)
		Check("[J215] clic : Créatures de la zone, filtre À compléter", f.kind == "menagerie" and f.menZone == ZONE and f.menState == "todo"
			and RowOf(f.men, 902) and not RowOf(f.men, 901))
		NS:OpenJournalZone(OTHER)
		tag = NS.journalFrame.prog.todoTag
		local green = tag:IsShown() and tag.complete and (tag.label:GetText() or ""):find("^complète") ~= nil
			and tag.label.textColor[2] == NS.Theme.GREEN[2]
		tag:GetScript("OnClick")(tag)
		Check("[J215] zone complète : « complète » en vert, le clic mène à toute la zone", green
			and NS.journalFrame.kind == "menagerie" and NS.journalFrame.menState == "all" and NS.journalFrame.menZone == OTHER)
		J.Done()
	end

	-- 3.5 Réserve : grille, tri, filtres, fiche, actions (Azeroth : les encres en plus ; Sobre : la page tient)
	local function FillReserve()
		local a = NS:SpecimenAdd({ npc = 900, stars = 1, name = "Raptor", origin = "capture", by = "Dyokrion", zone = ZONE, at = 1793500000 })
		local b = NS:SpecimenAdd({ npc = 900, stars = 2, name = "Raptor", origin = "capture", by = "Dyokrion", zone = ZONE, at = 1793600000 })
		local ref = NS:SpecimenReference(901, false)
		local c = NS:SpecimenAdd({ npc = 901, stars = 3, name = "Kodo", origin = "capture", by = "Deklatis", zone = ZONE, at = 1793400000 })
		NS:SpecimenSetReference(ref.id)
		NS:SpecimenAdd({ npc = 903, stars = 1, shiny = true, name = "Grue" })
		local s = NS:SpecimenAdd({ npc = 903, stars = 1, shiny = true, name = "Grue", at = 1793700000 })
		return { low = a, mid = b, better = c, ref = ref.id, shiny = s }
	end

	do
		Say("-- carnet 3.0 : Réserve (sobre)")
		J.Reset("sobre")
		local ids = FillReserve()
		local f = NS:OpenReserve()
		local rv = f.res.reserve
		TileOf(rv, ids.better):GetScript("OnClick")(TileOf(rv, ids.better))
		rv.toCodex:GetScript("OnClick")(rv.toCodex)
		Check("[J215] sobre : la page Réserve, « Réserve · 5 / 20 », vignettes, Mettre au Codex, sans erreur", f.kind == "reserve"
			and f.res:IsShown() and f.header.title:GetText() == "Réserve · 5 / 20" and ShownTiles(rv) == 5
			and NS:SpecimenIsReference(ids.better) and NoErrors(), f.header.title:GetText())
		J.Done()
	end

	do
		Say("-- carnet 3.0 : Réserve (azeroth)")
		J.Reset("azeroth")
		local ids = FillReserve()
		local f = NS:OpenReserve()
		local pane = f and f.res
		local rv = pane and pane.reserve
		NS:PaillettesAdd(126, "test")
		NS:RefreshJournal()
		-- 3.0.0 : le solde en pastille (chiffre, « paillettes »)
		Check("[J215] la page Réserve dans la navigation, « Réserve · 5 / 20 », solde de paillettes", f.kind == "reserve"
			and f.sections.reserve ~= nil and pane:IsShown() and rv:IsShown() and not f.shopPane:IsShown()
			and f.header.title:GetText() == "Réserve · 5 / 20" and pane.balance.value:GetText() == "126"
			and pane.balance.label:GetText() == "paillettes", f.header.title:GetText())
		Check("[J215] une vignette par spécimen, la meilleure d'abord, perle des brillants", ShownTiles(rv) == 5
			and rv.tiles[1].spec.id == ids.better and rv.tiles[1].stars[3].full and rv.tiles[1].label:GetText() == "Kodo"
			and TileOf(rv, ids.shiny).gem:IsShown() and not TileOf(rv, ids.low).gem:IsShown())
		local before = #Mock.frames
		NS:RefreshJournal(); NS:RefreshJournal()
		Check("[J215] rafraîchi sans rien créer (vignettes réutilisées)", #Mock.frames == before, #Mock.frames .. "/" .. before)
		local bad = {}
		rv.sort:Choose("date")
		if not (rv.tiles[1].spec.id == ids.shiny and f.resSort == "date") then bad[#bad + 1] = "date" end
		rv.sort:Choose("name")
		if rv.tiles[1].spec.name ~= "Grue" then bad[#bad + 1] = "nom" end
		rv.species:Choose(900)
		if not (ShownTiles(rv) == 2 and TileOf(rv, ids.low) and TileOf(rv, ids.mid)) then bad[#bad + 1] = "espèce" end
		rv.species:Choose("all")
		rv.show:Select("shiny")
		if not (TileOf(rv, ids.shiny) and not TileOf(rv, ids.low)) then bad[#bad + 1] = "brillants" end
		rv.show:Select("all")
		rv.sort:Choose("stars")
		Check("[J215] tris (date, nom) et filtres (espèce, brillants)", #bad == 0, table.concat(bad, ", "))
		-- fiche : origine, meilleur que le Codex, bouton grisé et pourquoi
		TileOf(rv, ids.better):GetScript("OnClick")(TileOf(rv, ids.better))
		local p = rv.preview
		local text = PreviewText(p.lines)
		Check("[J215] fiche : « Capturé par Deklatis · Les Tarides », « Meilleur que ton spécimen du Codex », Relâcher grisé et pourquoi",
			text:find("Capturé par Deklatis · Les Tarides", 1, true) ~= nil and text:find("Meilleur que ton spécimen du Codex", 1, true) ~= nil
			and rv.betterLine ~= nil and rv.release.qcEnabled == false
			and rv.release.disabledTip == "Mets-le au Codex avant de le relâcher." and text:find("Mets-le au Codex", 1, true) ~= nil, text)
		local tile = rv.tiles[1]
		Check("[J215] azeroth : vignettes claires, fiche habillée, encres reserve.* mesurées, aucun rôle manquant",
			tile.azStyle == "light" and tile.label.azRole == "reserve.name" and pane.balance.value.azRole == "currency.value"
			and p.lines[2].azRole == "reserve.detail" and rv.reasonLine and p.lines[rv.betterLine].azRole == "reserve.better"
			and p.lines[rv.reasonLine].azRole == "reserve.reason" and p.azStyle == "light" and p.azWoodBorder ~= nil
			and NS.carnetInkMisses == nil, table.concat(NS.carnetInkMisses or {}, ", "))
		-- Mettre au Codex : échange
		rv.toCodex:GetScript("OnClick")(rv.toCodex)
		Check("[J215] Mettre au Codex : il y entre, l'ancien passe en Réserve, choisi, « Avant la 3.0 »",
			NS:SpecimenIsReference(ids.better) and not NS:SpecimenIsReference(ids.ref) and f.resPick == ids.ref
			and TileOf(rv, ids.ref) ~= nil and not TileOf(rv, ids.better)
			and PreviewText(p.lines):find("Avant la 3.0", 1, true) ~= nil)
		-- Relâcher : confirmation dans la page
		TileOf(rv, ids.low):GetScript("OnClick")(TileOf(rv, ids.low))
		local label = rv.release.qcEnabled == true and (rv.release:GetText() or ""):find("+1", 1, true) ~= nil
		local balance = NS:Paillettes()
		rv.release:GetScript("OnClick")(rv.release)
		local asking = f.resConfirm == ids.low and rv.confirm:IsShown() and rv.confirmYes:IsShown() and not rv.release:IsShown()
			and NS:SpecimenGet(ids.low) ~= nil and NS:Paillettes() == balance
		rv.confirmNo:GetScript("OnClick")(rv.confirmNo)
		Check("[J215] Relâcher (+1) : 1er clic, la confirmation dans la fiche, rien relâché ; Annuler", label and asking
			and f.resConfirm == nil and rv.release:IsShown() and not rv.confirm:IsShown())
		rv.release:GetScript("OnClick")(rv.release)
		rv.confirmYes:GetScript("OnClick")(rv.confirmYes)
		Check("[J215] confirmé : relâché, +1 paillette, le choix passe au suivant", NS:SpecimenGet(ids.low) == nil
			and NS:Paillettes() == balance + 1 and f.resPick ~= ids.low and f.resPick ~= nil and not rv.confirm:IsShown())
		-- Localiser l'espèce
		local pins = PinApi(OTHER)
		TileOf(rv, ids.mid):GetScript("OnClick")(TileOf(rv, ids.mid))
		rv.locate:GetScript("OnClick")(rv.locate)
		local located = pins.set == 1 and pins.point.map == ZONE and pins.opened == ZONE and rv.locate:GetText() == "Effacer le repère"
		TileOf(rv, ids.shiny):GetScript("OnClick")(TileOf(rv, ids.shiny))
		Check("[J215] Localiser l'espèce : repère et carte ; espèce sans point : grisé", located and rv.locate.qcEnabled == false
			and rv.locate.disabledTip ~= nil)
		-- Réserve pleine
		local quiet = (rv.warn:GetText() or "") == ""
		for _ = 1, 17 do NS:SpecimenAdd({ npc = 904, stars = 1, name = "Sanglier" }) end
		NS:RefreshJournal()
		Check("[J215] Réserve pleine : le dire (rien avant)", quiet and NS:ReserveFull()
			and (rv.warn:GetText() or ""):find("Réserve pleine", 1, true) ~= nil)
		-- vide
		NS:DB().capture.specimens, NS:DB().capture.codex = {}, {}
		NS:DB().capture.specDirty = true    -- le Codex se refait d'après les fiches : Réserve vide
		NS:RefreshJournal()
		Check("[J215] Réserve vide : expliquée, fiche vide ; aucune erreur", rv.empty:IsShown() and not rv.release:IsShown()
			and NoErrors(), next(NS.errors or {}))
		J.Done()
	end

	-- 3.6 Échoppe du dresseur (Azeroth : le parcours ; Sobre : la page tient)
	do
		Say("-- carnet 3.0 : Échoppe (sobre)")
		J.Reset("sobre")
		local f = NS:OpenReserve("shop")
		NS:PaillettesAdd(10, "test")
		Check("[J215] sobre : l'onglet Échoppe, un achat, sans erreur", f.kind == "shop" and f.shopPane:IsShown()
			and NS:ShopBuy("appat") == true and NS:Paillettes() == 5 and NoErrors())
		J.Done()
	end

	do
		Say("-- carnet 3.0 : Échoppe (azeroth)")
		J.Reset("azeroth")
		-- 3.0.0 : l'Échoppe a son onglet (OpenReserve("shop") y mène encore)
		local f = NS:OpenReserve("shop")
		local pane = f.res
		local sv = f.shopPane
		Check("[J215] l'onglet Échoppe", f.kind == "shop" and sv:IsShown() and not pane:IsShown()
			and f.header.title:GetText() == "Échoppe du dresseur")
		local rows = {}
		for _, row in ipairs(sv.rows) do rows[row.item.id] = row end
		Check("[J215] articles et prix de la table ; solde à 0 : grisé, il manque n", #sv.rows == #NS.PAILLETTES_SHOP
			and rows.appat.item.price == 5 and rows.lasso.item.price == 15 and rows.sifflet.item.price == 40
			and rows.slots.item.price == 50 and rows.appat.buy.qcEnabled == false
			and rows.appat.buy.disabledTip == "Il te manque 5 paillettes" and not rows.appat.buy:IsEnabled() and rows.appat.state == "short"
			and rows.appat.buy.disabledLook == true)
		NS:PaillettesAdd(200, "test")
		NS:RefreshJournal()
		local items = NS:CaptureData().items
		local had = items.appat or 0
		rows.appat.buy:GetScript("OnClick")(rows.appat.buy)
		local asking = f.shopConfirm == "appat" and rows.appat.yes:IsShown() and not rows.appat.buy:IsShown() and NS:Paillettes() == 200
		rows.appat.no:GetScript("OnClick")(rows.appat.no)
		Check("[J215] Acheter : confirmation dans la ligne ; Annuler", asking and f.shopConfirm == nil and rows.appat.buy:IsShown()
			and NS:Paillettes() == 200)
		Mock:Reset()
		rows.appat.buy:GetScript("OnClick")(rows.appat.buy)
		rows.appat.yes:GetScript("OnClick")(rows.appat.yes)
		Check("[J215] achat : aide dans la besace, −5, ligne dans le chat, solde affiché", (items.appat or 0) == had + 1
			and NS:Paillettes() == 195 and Mock:Output():find("Échoppe du dresseur", 1, true) ~= nil and sv.balance.value:GetText() == "195")
		items.sifflet = 3
		NS:RefreshJournal()
		Check("[J215] besace pleine : grisé, la limite dite", rows.sifflet.state == "full" and rows.sifflet.buy.qcEnabled == false
			and rows.sifflet.buy.disabledTip == "Ta besace est pleine" and select(2, NS:ShopBuy("sifflet")) == "full")
		Check("[J215] places de Réserve : +5", NS:ShopBuy("slots") == true and NS:ReserveCapacity() == 25 and NS:Paillettes() == 145)
		-- cosmétique : au compte, condition « Échoppe du dresseur : n paillettes »
		local frameDef
		for _, def in ipairs(NS.COMPANION_FRAMES) do if def.id == "shop_glitter" then frameDef = def end end
		Check("[J215] cadre de l'échoppe : verrouillé, condition dite ; acheté : débloqué pour le compte", frameDef
			and not NS:CompanionIsUnlocked("frame", frameDef) and NS:CompanionLockText(frameDef) == "Échoppe du dresseur : 80 paillettes"
			and NS:ShopBuy("frame_glitter") == true and NS:CompanionIsUnlocked("frame", frameDef)
			and NS:DB().capture.shopOwned.shop_glitter == true and NS:Paillettes() == 65)
		NS:RefreshJournal()
		Check("[J215] déjà à toi : « Acquis », grisé ; le fond (60) acheté, le lasso (15) : il manque", rows.frame_glitter.state == "owned"
			and rows.frame_glitter.buy:GetText() == "Acquis" and rows.frame_glitter.buy.qcEnabled == false
			and rows.frame_glitter.buy.disabledTip == "Déjà obtenu"
			and select(2, NS:ShopBuy("frame_glitter")) == "owned" and NS:ShopBuy("bg_starfall") == true
			and NS:Paillettes() == 5 and select(2, NS:ShopBuy("lasso")) == "short")
		NS:DB().companionCapture = false
		NS:RefreshJournal()
		Check("[J215] capture coupée : pas d'aides", rows.appat.state == "off" and rows.appat.buy.qcEnabled == false)
		NS:DB().companionCapture = true
		f.sections.reserve:GetScript("OnClick")(f.sections.reserve)
		local back = f.kind == "reserve" and f.resView == "reserve" and pane.reserve:IsShown() and not sv:IsShown()
		NS:OpenShop()
		Check("[J215] onglet Réserve ; lignes de l'échoppe aux encres shop.*, aucun rôle manquant, aucune erreur", back
			and rows.appat.name.azRole == "shop.name" and rows.appat.desc.azRole == "shop.desc"
			and rows.appat.price.azRole == "shop.price" and sv.note.azRole == "reserve.text" and NS.carnetInkMisses == nil
			and NoErrors(), table.concat(NS.carnetInkMisses or {}, ", "))
		J.Done()
	end

	-- 3.7 Paillettes des missions et des paliers
	do
		Say("-- carnet 3.0 : paillettes en récompense")
		J.Reset("sobre")
		NS:MissionGrant("zone")
		local daily = NS:Paillettes() == 3
		NS:MissionGrant("allWeekly")
		Check("[J215] mission du jour +3, les trois de la semaine +10, texte de la récompense", daily and NS:Paillettes() == 13
			and NS:MissionRewardText("zone"):find("3 paillettes", 1, true) ~= nil)
		Check("[J215] paliers de zone : +2 chacun", NS:PaillettesOnMilestones({ { mark = 25 }, { mark = 50 } }, { quiet = true }) == 4
			and NS:Paillettes() == 17)
		NS:DB().companionCapture = false
		local none = NS:PaillettesOnMilestones({ { mark = 75 } }) == 0
		NS:MissionGrant("zone")
		Check("[J215] capture coupée : ni paliers ni missions", none and NS:Paillettes() == 17)
		NS:DB().companionCapture = true
		J.Done()
	end

	-- 3.8 Colonne de navigation : la Réserve et l'Échoppe y tiennent
	do
		Say("-- carnet 3.0 : colonne de navigation")
		for _, style in ipairs({ "sobre", "azeroth" }) do
			J.Reset(style)
			local f = Open("evolution")
			local box = f.navSummary
			local count = 0
			for _ in pairs(f.sections) do count = count + 1 end
			local lay = NS.CARNET_LAYOUT
			local navH = style == "azeroth" and (f:GetHeight() - lay.band - lay.wood) or (f:GetHeight() - 2)
			local top = -(box.lastPoint and box.lastPoint.y or 0)
			local bottom = top + box:GetHeight()
			-- en bas : le total (Sobre) ou le garde-manger (Azeroth, étiquette à 50 px du bas)
			local reserved = style == "azeroth" and 50 + 16 or 18 + 16
			Check("[J215] " .. style .. " : neuf entrées (Réserve puis Échoppe après les Créatures), le résumé tient au-dessus du bas",
				count == 9 and f.sections.reserve ~= nil and NS.JOURNAL_SECTIONS[3] == "reserve" and NS.JOURNAL_SECTIONS[4] == "shop"
				and f.sections.shop ~= nil and bottom <= navH - reserved, bottom .. " / " .. navH)
			J.Done()
		end
	end

	-- 3.9 Encres et textes
	do
		Say("-- carnet 3.0 : encres et textes")
		local bad = {}
		local roles = { "reserve.balance", "reserve.full", "reserve.text", "reserve.hint", "reserve.name", "reserve.shiny",
			"reserve.detail", "reserve.better", "reserve.reason", "reserve.confirm", "shop.name", "shop.desc", "shop.price",
			"shop.short", "codex.todo", "codex.done" }
		for _, role in ipairs(roles) do
			local r = NS.AZEROTH_CONTRAST[role]
			local ratio = r and NS.AzerothContrast(INK[r[1]], r[2]) or 0
			if not r or ratio < r[3] then bad[#bad + 1] = role .. string.format(" %.2f", ratio) end
		end
		Check("[J215] rôles reserve.* / shop.* / codex.* : seuil tenu sur les fonds déjà mesurés", #bad == 0
			and NS.AZEROTH_CONTRAST["reserve.name"][2] == NS.AZEROTH_CONTRAST["tile.text"][2]
			and NS.AZEROTH_CONTRAST["reserve.text"][2] == NS.AZEROTH_CONTRAST["page.ink"][2], table.concat(bad, ", "))
		local fr, en = NS.RESERVE_STRINGS.fr, NS.RESERVE_STRINGS.en
		local missing = {}
		for key in pairs(fr) do if en[key] == nil then missing[#missing + 1] = key end end
		for key in pairs(en) do if fr[key] == nil then missing[#missing + 1] = key end end
		Check("[J215] textes FR/EN au complet", #missing == 0, table.concat(missing, ", "))
		Check("[J215] paillette et icônes des lignes : icônes du client, jamais livrées", NS.PAILLETTES_ICON:find("^Interface\\Icons\\") ~= nil
			and NS.PaillettesGlyph(12):find(NS.PAILLETTES_ICON, 1, true) ~= nil and NS.MEN_ROW_ICONS.pin:find("^Interface\\Icons\\") ~= nil
			and NS.MEN_ROW_ICONS.locate:find("^Interface\\Icons\\") ~= nil)
	end
end

-- 4. Exploration (2.9.1, retours en jeu du 2026-11-09) ----------------------------------------------------
do
	local R = { saved = {} }
	local GLOBALS = { "InCombatLockdown", "UnitAffectingCombat", "C_Timer", "GetLocale", "time" }
	for _, name in ipairs(GLOBALS) do R.saved[name] = rawget(_G, name) end
	R.saved.GetTitle, R.saved.RequestLoad = C_QuestLog.GetTitleForQuestID, C_QuestLog.RequestLoadQuestByID
	R.saved.ZONE_QUESTS = rawget(NS, "ZONE_QUESTS")
	R.savedStyle = NS:DB().companionStyle
	local INK, CONTRAST = NS.AZEROTH_INK, NS.AZEROTH_CONTRAST
	local FIELDS = { "companionFrame", "companionBubble", "companionHover", "journalFrame", "journalToast", "trainerFrame" }

	local function Lin(c) if c <= 0.03928 then return c / 12.92 end return ((c + 0.055) / 1.055) ^ 2.4 end
	local function Lum(c) return 0.2126 * Lin(c[1]) + 0.7152 * Lin(c[2]) + 0.0722 * Lin(c[3]) end
	local function Ratio(c, bg)
		local a, b = Lum(c), bg
		if a < b then a, b = b, a end
		return (a + 0.05) / (b + 0.05)
	end
	local function Same(c, ref)
		return c and ref and math.abs(c[1] - ref[1]) < 0.001 and math.abs(c[2] - ref[2]) < 0.001 and math.abs(c[3] - ref[3]) < 0.001
	end
	local function NoErrors()
		local list = {}
		for _, e in ipairs(NS.errors or {}) do list[#list + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
		return #list == 0, table.concat(list, " | ")
	end
	function R.Reset(atlas)
		ResetWorld()
		for _, field in ipairs(FIELDS) do
			if NS[field] then NS[field]:Hide() end
			NS[field] = nil
		end
		NS.uiStyleCache, NS.errors, NS.carnetMissing = {}, {}, {}
		Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
		Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
		Mock.world.mapID, Mock.world.level = 1413, 20
		_G.InCombatLockdown = function() return false end
		_G.UnitAffectingCombat = function() return false end
		_G.C_Timer = { After = function(_, fn) fn() end }
		_G.GetLocale = function() return "frFR" end
		_G.time = function() return 1800000000 end
		if atlas == false then Mock.InstallAtlas(nil) else Mock.InstallAtlas(atlas or true) end
		NS:AzerothAtlasOK(true)
		NS:DB().companionStyle = "azeroth"
		NS:CompanionData().tutoDone = true
		NS:TreatData().treatsInit = true
		NS:CompanionUpdateVisibility()
	end
	local function ZQReset(zones)
		NS.ZONE_QUESTS = zones
		local s = NS.zoneQuests
		s.done, s.lists, s.builds, s.dirty, s.live, s.requested, s.titles, s.asked = {}, {}, 0, false, {}, {}, {}, {}
	end
	local function Names()
		local names = {}
		for _, q in ipairs(NS:ZoneQuestList(1413) or {}) do names[q.id] = q.name end
		return names
	end

	-- 4.1 Titres des quêtes dans la langue du client
	do
		Say("-- exploration 2.9.1 : titres des quêtes traduits par le client")
		R.Reset()
		local asked, titles = {}, {}
		C_QuestLog.GetTitleForQuestID = function(id) return titles[id] end
		C_QuestLog.RequestLoadQuestByID = function(id) asked[#asked + 1] = id end
		ZQReset({ [1413] = { [9201] = { en = "Wayward Weapons", lvl = 2 }, [9202] = { en = "Admiral's Orders", fr = "Les ordres de l'amiral", lvl = 7 } } })
		local names = Names()
		Check("[R291] titre pas encore en cache : notre nom sans attendre, chargement demandé pour la seule quête sans nom français",
			names[9201] == "Wayward Weapons" and names[9202] == "Les ordres de l'amiral" and #asked == 1 and asked[1] == 9201,
			table.concat(asked, ","))
		NS.zoneQuests.lists = {}
		NS:ZoneQuestList(1413)
		Check("[R291] une seule demande par quête", #asked == 1)
		titles[9201] = "Armes égarées"
		NS.ZoneQuestDataLoaded(9201, true)
		local loaded = Names()[9201] == "Armes égarées" and NS.zoneQuests.titles[9201] == "Armes égarées"
		titles[9201] = nil
		NS.zoneQuests.lists = {}
		Check("[R291] QUEST_DATA_LOAD_RESULT (écouté) : le titre traduit remplace l'anglais, gardé même si le client l'oublie",
			loaded and Names()[9201] == "Armes égarées" and NS.zoneQuestsEventFrame.events.QUEST_DATA_LOAD_RESULT == true)
		-- sans l'API : repli sur nos noms, sans erreur
		C_QuestLog.GetTitleForQuestID, C_QuestLog.RequestLoadQuestByID = nil, nil
		ZQReset({ [1413] = { [9201] = { en = "Wayward Weapons", lvl = 2 } } })
		local plain = NS:ZoneQuestList(1413)
		-- client anglais : pas de demande pour une quête qui a son nom anglais
		asked = {}
		C_QuestLog.GetTitleForQuestID = function() return nil end
		C_QuestLog.RequestLoadQuestByID = function(id) asked[#asked + 1] = id end
		_G.GetLocale = function() return "enUS" end
		ZQReset({ [1413] = { [9201] = { en = "Wayward Weapons", lvl = 2 } } })
		NS:ZoneQuestList(1413)
		local okErr, errs = NoErrors()
		Check("[R291] sans API du client : notre nom anglais ; client anglais : aucune demande ; sans erreur", plain
			and plain[1].name == "Wayward Weapons" and #asked == 0 and okErr, errs)
		C_QuestLog.GetTitleForQuestID, C_QuestLog.RequestLoadQuestByID = R.saved.GetTitle, R.saved.RequestLoad
		ZQReset(R.saved.ZONE_QUESTS)
	end

	-- 4.2 Exploration : encres mesurées des quêtes et des zones
	do
		Say("-- exploration 2.9.1 : encres mesurées")
		local bad = {}
		for _, key in ipairs({ "quest.name", "quest.nameDone", "quest.detail", "quest.detailDone", "zone.label", "zone.unseen" }) do
			local role = CONTRAST[key]
			local color = role and INK[role[1]]
			if not (color and Ratio(color, role[2]) >= 4.5 and role[3] >= 4.5) then bad[#bad + 1] = key end
		end
		Check("[R291] rôles quest.* et zone.* : 4,5:1 au moins sur le pire fond ; « zoneDim » 5,41:1 sur les catégories", #bad == 0
			and math.abs(Ratio(INK.zoneDim, 0.0455) - 5.41) < 0.01, table.concat(bad, ", "))
		R.Reset()
		ZQReset({ [1413] = { [9301] = { en = "Wayward Weapons", lvl = 2 }, [9302] = { en = "Legging It", lvl = 6 } } })
		local f = NS:ToggleJournal(true)
		NS:SelectJournalKind("progress")
		f.progPart = "quests"
		NS:RefreshJournal()
		NS:RefreshJournal()
		local pane = f.prog
		local line
		for _, l in ipairs(pane and pane.items or {}) do
			if l.item and not l.item.header and l:IsShown() then line = line or l end
		end
		local todo = line and line.azStyle == "light" and Same(line.text.textColor, INK[CONTRAST["quest.name"][1]])
			and not (line.detail:GetText() or ""):find("|c", 1, true) and Same(line.detail.textColor, INK[CONTRAST["quest.detail"][1]])
		if line then NS.CarnetQuestLineInk(line, { done = true, detail = NS.L.ZQ_DONE }) end
		Check("[R291] ligne de quête : fond clair, encres « ink » / « inkMuted » sans code couleur ; faite : nom adouci, vert sombre",
			todo and Same(line.text.textColor, INK.inkMuted) and Same(line.detail.textColor, INK.green), line and tostring(line.azStyle))
		-- les zones pas encore vues : rangée opaque, gris mesuré
		local unseen
		for _, row in ipairs(pane and pane.zones or {}) do
			if row.zone and not row.zone.seen and not row.selected and row:IsShown() then unseen = unseen or row end
		end
		if not unseen and pane and pane.zones[2] then
			unseen = pane.zones[2]
			unseen.zone, unseen.selected = { id = 1, name = "Zone test", seen = false }, false
			NS.CarnetZoneRowInk(unseen)
		end
		local okErr, errs = NoErrors()
		Check("[R291] zone pas encore vue : rangée opaque, nom « zoneDim » ; sans erreur", unseen and (unseen.alpha or 1) == 1
			and Same(unseen.name.textColor, INK.zoneDim) and okErr, errs)
		f:Hide()
		ZQReset(R.saved.ZONE_QUESTS)
	end

	-- 4.3 La roue crantée du carnet : la roue grise du journal de quêtes du client
	do
		Say("-- exploration 2.9.1 : roue crantée grise")
		R.Reset()
		local f = NS:ToggleJournal(true)
		local button = f.settingsButton
		local cog = NS.JOURNAL_COG
		Check("[R291] roue : atlas « questlog-icon-setting », sans carré au trait, grise estompée au repos", button
			and button.icon.atlas == "questlog-icon-setting" and button.cogTexture == "questlog-icon-setting"
			and not button.border.top:IsShown() and not button.border.left:IsShown() and not button.border.bottom:IsShown()
			and not button.border.right:IsShown() and Same(button.icon.vertex, cog.rest) and button.icon.alpha == cog.rest[4]
			and button.cogHot == false, button and tostring(button.icon.atlas))
		button:GetScript("OnEnter")(button)
		local hot = Same(button.icon.vertex, cog.hover) and button.icon.alpha == 1 and button.cogHot == true and not button.border.top:IsShown()
		button:GetScript("OnLeave")(button)
		Check("[R291] roue : plus claire au survol, revient au repos", hot and Same(button.icon.vertex, cog.rest) and button.cogHot == false)
		f:Hide()
		-- atlas absent : le second, puis le fichier
		R.Reset({ ["questlog-icon-setting"] = true })
		f = NS:ToggleJournal(true)
		local second = f.settingsButton.icon.atlas == "gm-icon-settings" and f.settingsButton.cogTexture == "gm-icon-settings"
		f:Hide()
		R.Reset(false)
		f = NS:ToggleJournal(true)
		local okErr, errs = NoErrors()
		Check("[R291] roue : repli sur « gm-icon-settings », puis sur le fichier UI-OptionsButton, sans erreur", second
			and f.settingsButton.icon.texture == cog.file and f.settingsButton.cogTexture == cog.file and okErr, errs)
		f:Hide()
	end

	-- remise en état
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:ApplyUIStyle()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	for _, name in ipairs(GLOBALS) do _G[name] = R.saved[name] end
	C_QuestLog.GetTitleForQuestID, C_QuestLog.RequestLoadQuestByID = R.saved.GetTitle, R.saved.RequestLoad
	NS:DB().companionStyle = R.savedStyle
	ResetWorld()
end
