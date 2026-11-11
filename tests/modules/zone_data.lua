-- Données de zone livrées (v1.25.0, WoW Forever seulement depuis QC 1.2.0) :
-- ZoneCreatures_Forever.lua / ZoneGathering_Forever.lua / ZoneQuests_Forever.lua
-- (générés par tools/gen_zone_data.py depuis la base de Questie) et leur usage.
-- 1. Créatures et récolte : .toc, garde de client, intégrité, contenu réel,
--    parts bestiaire / nommés / récolte calculées avec la table, faction,
--    abattu sans avoir été vu, fenêtre, zone hors tables.
-- 2. Quêtes de zone : intégrité, contenu réel, filtres race / classe (Skyborne),
--    faites / à faire, exclusives, cache et combat, client sans table, fenêtre.
-- 3. Récolte selon le métier (Gathering.lua, GatheringData.lua), en dynamique :
--    table des ressources, métiers et rang, tranche, butin, objectifs, part de
--    zone, par personnage, module coupé, robustesse.
local Check, Say, ResetWorld, Mock = T.Check, T.Say, T.ResetWorld, T.Mock
local NS = T.QNS
local ROOT = rawget(_G, "ADDON_ROOT") or "."

-- liste des écarts : un Check par invariant, le détail de ce qui manque en extra
local function Expect(bad, label, ok) if not ok then bad[#bad + 1] = label end end
local function TocOrder()
	local order = {}
	for index, file in ipairs(_G.TOC_FILES or {}) do order[(file:gsub("^[^/]+/", ""))] = index end
	return order
end

-- ============================================================================
-- 1. Créatures et récolte de chaque zone
-- ============================================================================
do
	local saved, MOCKED = {}, { "IsInInstance", "GetInstanceInfo", "GetRealZoneText", "UnitClassification", "UnitGUID",
		"UnitIsPlayer", "UnitName", "UnitExists", "UnitIsDead", "UnitPlayerControlled", "UnitReaction", "UnitCanAttack",
		"UnitCreatureType", "UnitCreatureFamily", "UnitLevel", "CombatLogGetCurrentEventInfo", "InCombatLockdown",
		"UnitFactionGroup", "GetLocale", "GetNumSkillLines", "GetSkillLineInfo", "date" }
	for _, name in ipairs(MOCKED) do saved[name] = rawget(_G, name) end
	saved.GetAreaInfo = C_Map.GetAreaInfo

	local Z = { W = { units = {} }, faction = "Horde", locale = "frFR", skills = {} }
	local PLAYER_GUID = "Player-1-00000002"
	_G.IsInInstance = function() return false, "none" end
	_G.GetInstanceInfo = function() return "Kalimdor", "none", 0, "", 0, 0, false, 0 end
	_G.GetRealZoneText = function() return "" end
	_G.InCombatLockdown = function() return false end
	_G.UnitFactionGroup = function() return Z.faction end
	_G.GetLocale = function() return Z.locale end
	_G.date = function() return "03/11/2026" end
	_G.UnitGUID = function(unit)
		if unit == "player" then return PLAYER_GUID end
		local u = Z.W.units[unit]; return u and u.guid
	end
	_G.UnitName = function(unit)
		if unit == "player" then return "Testeuse" end
		local u = Z.W.units[unit]; return u and u.name
	end
	_G.UnitExists = function(unit) return Z.W.units[unit] ~= nil end
	_G.UnitIsPlayer = function() return false end
	_G.UnitIsDead = function() return false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function(unit) local u = Z.W.units[unit]; return u and u.class or "normal" end
	_G.UnitCreatureType = function(unit) local u = Z.W.units[unit]; return u and u.type end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function(unit)
		if unit == nil or unit == "player" then return 20 end
		local u = Z.W.units[unit]; return u and u.level
	end
	_G.CombatLogGetCurrentEventInfo = function() return unpack(Z.W.cleu or {}) end
	_G.GetNumSkillLines = function() return #Z.skills end
	_G.GetSkillLineInfo = function(index)
		local s = Z.skills[index]
		if not s then return nil end
		return s[1], s[2] == true, s[3] ~= false, s[4] or 0
	end
	C_Map.GetAreaInfo = nil

	local MAPS = {
		[947]  = { mapID = 947,  name = "Azeroth", parentMapID = 0, mapType = 1 },
		[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 },
		[1415] = { mapID = 1415, name = "Royaumes de l'Est", parentMapID = 947, mapType = 2 },
		[1411] = { mapID = 1411, name = "Durotar", parentMapID = 1414, mapType = 3 },
		[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 1415, mapType = 3 },
		-- une zone que les tables ne connaissent pas (contenu propre à Forever)
		[9200] = { mapID = 9200, name = "Île inconnue", parentMapID = 1414, mapType = 3 },
	}

	function Z.Reset(faction)
		ResetWorld()
		Z.W, Z.faction, Z.locale, Z.skills = { units = {} }, faction or "Horde", "frFR", {}
		for id, info in pairs(MAPS) do Mock.world.maps[id] = info end
		Mock.world.mapID = 1411
		Mock.world.level = 20
		NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryRejected = {}, nil, {}
		NS.journalRares, NS.journalToasts, NS.journalChats = {}, {}, {}
		if NS.journalFrame then NS.journalFrame:Hide() end
		NS.journalFrame = nil
		if NS.journalTracker then NS.journalTracker:Hide() end
		NS.journalTracker = nil
		NS.journalGroups, NS.journalGroupsFor = nil, nil
	end
	function Z.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00002B3C4D") end
	function Z.Log(subevent, sourceGUID, sourceFlags, destGUID, destFlags)
		Z.W.cleu = { 1000, subevent, false, sourceGUID, "src", sourceFlags, 0, destGUID, "dst", destFlags or 0x10a48, 0 }
		Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	end
	function Z.Kill(npcID, spawn)
		Z.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, Z.Guid(npcID, spawn))
		Z.Log("UNIT_DIED", nil, 0, Z.Guid(npcID, spawn))
	end
	function Z.Part(id)
		for _, def in ipairs(NS.ZONE_PARTS or {}) do if def.id == id then return def.Compute(NS, Mock.world.mapID) end end
	end
	-- espèces de la table pour une faction ("A" / "H"), nommées ou non
	function Z.Expected(zoneID, faction, namedOnly)
		local count = 0
		for _, entry in pairs(NS.ZONE_CREATURES[zoneID] or {}) do
			if entry.f ~= faction and (not namedOnly or (entry.rank or 0) > 0) then count = count + 1 end
		end
		return count
	end
	function Z.Rows(zoneID, activity)
		local rows = NS:JournalActivityRows(zoneID, activity)
		local byName = {}
		for _, row in ipairs(rows) do if not row.header then byName[row.name] = row end end
		return rows, byName
	end

	-- 1.1 Chargement, ordre du .toc, garde de client ----------------------------------------
	-- Les fichiers de données se gardent eux-mêmes (ns:IsForeverClient(), Dungeon.lua) :
	-- on les recharge avec un faux ns pour voir chaque client.
	function Z.LoadData(file, forever)
		local fake = { marks = {}, LazyZones = NS.LazyZones }
		if forever ~= "none" then fake.IsForeverClient = function() return forever end end
		fake.Mark = function(name) fake.marks[#fake.marks + 1] = name end
		local chunk = assert(loadfile(ROOT .. "/QuestCompanion/" .. file))
		chunk("QuestCompanion", fake)
		return fake
	end
	Z.DATA = {
		creatures = Z.LoadData("ZoneCreatures_Forever.lua", true).ZONE_CREATURES,
		gathering = Z.LoadData("ZoneGathering_Forever.lua", true).ZONE_GATHERING,
	}
	do
		Say("-- données de zone : chargement")
		local order, bad = TocOrder(), {}
		Expect(bad, "chargées", NS.Loaded and NS.Loaded.ZoneCreatures and NS.Loaded.ZoneGathering and NS.Loaded.ZoneQuests
			and NS.Loaded.ZoneQuests_Forever)
		for _, file in ipairs({ "ZoneCreatures_Forever.lua", "ZoneGathering_Forever.lua", "ZoneQuests_Forever.lua" }) do
			Expect(bad, file, order[file] and order[file] > order["Dungeon.lua"])
		end
		Expect(bad, "créatures/récolte avant Bestiary/Gathering", order["ZoneCreatures_Forever.lua"] < order["Bestiary.lua"]
			and order["ZoneGathering_Forever.lua"] < order["Gathering.lua"])
		Expect(bad, "ZoneQuests entre sa table, JournalTracker et JournalWindow", order["ZoneQuests_Forever.lua"] < order["ZoneQuests.lua"]
			and order["JournalTracker.lua"] < order["ZoneQuests.lua"] and order["ZoneQuests.lua"] < order["JournalWindow.lua"])
		Expect(bad, "tables de Forever (Île de Zephras 2521)", NS:IsForeverClient() == true and NS.ZONE_CREATURES[2521] ~= nil
			and NS.ZONE_GATHERING[2521] ~= nil and NS.ZONE_QUESTS[2521] ~= nil)
		Check("[ZDATA] .toc : 3 tables chargées après Dungeon.lua (IsForeverClient), avant leurs modules", #bad == 0,
			table.concat(bad, ", "))
		-- QC 1.2.0 : plus de tables d'Era ; v1.25.0 : plus de Questie
		local toc = ""
		for _, file in ipairs({ "/Ready2Quest/Ready2Quest.toc", "/QuestCompanion/QuestCompanion.toc" }) do
			local handle = assert(io.open(ROOT .. file, "r"))
			toc = toc .. handle:read("*a")
			handle:close()
		end
		Check("[ZDATA] .toc : plus de tables d'Era, d'anciens fichiers ni de Questie", order["ZoneCreatures.lua"] == nil
			and order["ZoneGathering.lua"] == nil and order["ZoneCreatures_Era.lua"] == nil and order["ZoneGathering_Era.lua"] == nil
			and order["ZoneQuests_Era.lua"] == nil and order["QuestieZone.lua"] == nil and not toc:find("Questie", 1, true)
			and NS.QuestieAvailable == nil and NS.QuestiePart == nil and rawget(NS, "QUESTIE_HINT") == nil)

		-- garde : chaque fichier ne se construit que sur son client, sans marque de chargement
		local guard = {}
		for _, file in ipairs({ "ZoneCreatures", "ZoneGathering", "ZoneQuests" }) do
			local key = "ZONE_" .. (file == "ZoneCreatures" and "CREATURES" or file == "ZoneGathering" and "GATHERING" or "QUESTS")
			local skipped, loaded = Z.LoadData(file .. "_Forever.lua", false), Z.LoadData(file .. "_Forever.lua", true)
			Expect(guard, file, skipped[key] == nil and #skipped.marks == 0 and type(loaded[key]) == "table")
		end
		Expect(guard, "marque", Z.LoadData("ZoneCreatures_Forever.lua", true).marks[1] == "ZoneCreatures")
		Check("[ZDATA] garde de client : tables de Forever sur Forever seulement, ni table ni marque ailleurs", #guard == 0,
			table.concat(guard, ", "))
		local handle = assert(io.open(ROOT .. "/QuestCompanion/ZoneCreatures_Forever.lua", "r"))
		local head = handle:read(2000)
		handle:close()
		Check("[ZDATA] en-tête : généré, source, couches, GPL-3.0", head:find("FICHIER GÉNÉRÉ", 1, true)
			and head:find("Questie/QuestieDB", 1, true) and head:find("delta-base", 1, true) and head:find("GPL-3.0", 1, true)
			and head:find("ne pas éditer", 1, true))
	end

	-- 1.2 Intégrité des tables -----------------------------------------------------------------
	do
		Say("-- données de zone : intégrité")
		local data = Z.DATA
		-- zones connues : celles du coffre (ZONE_LEVELS) + Reflet-de-Lune (1450) + zones propres à Forever
		local known = { [1450] = true, [2482] = true, [2521] = true, [2524] = true, [2548] = true, [2652] = true }
		for zoneID in pairs(NS.ZONE_LEVELS or {}) do known[zoneID] = true end
		local zones, lines, bad, badZones = 0, 0, {}, {}
		for _, zoneID in ipairs(NS.ZoneIds(data.creatures)) do
			zones = zones + 1
			if not known[zoneID] then badZones[#badZones + 1] = "inconnue:" .. zoneID end
			for npcID, e in pairs(data.creatures[zoneID]) do
				lines = lines + 1
				local ok = type(npcID) == "number" and npcID > 0 and npcID == math.floor(npcID)
					and type(e.lvl) == "table" and type(e.lvl[1]) == "number" and type(e.lvl[2]) == "number"
					and e.lvl[1] >= 1 and e.lvl[1] <= e.lvl[2]
					and type(e.rank) == "number" and e.rank >= 0 and e.rank <= 4
					and type(e.fr) == "string" and e.fr ~= "" and type(e.en) == "string" and e.en ~= ""
					and (e.f == nil or e.f == "A" or e.f == "H")
				if not ok and #bad < 5 then bad[#bad + 1] = zoneID .. ":" .. tostring(npcID) end
			end
		end
		for zoneID in pairs(NS.ZONE_LEVELS or {}) do
			if zoneID < 9000 and not data.creatures[zoneID] then badZones[#badZones + 1] = "sans table:" .. zoneID end
		end
		Check("[ZDATA] créatures : 40 zones classiques + zones de Forever, des milliers de lignes", zones >= 43
			and lines > 3000, zones .. "/" .. lines)
		Check("[ZDATA] créatures : zones toutes connues, chaque zone du coffre a sa table", #badZones == 0,
			table.concat(badZones, ","))
		Check("[ZDATA] créatures : ids numériques, niveaux min <= max, rang 0-4, noms fr+en, faction A/H/nil",
			#bad == 0, table.concat(bad, ","))

		local gZones, pairsCount, unknown = 0, 0, {}
		for zoneID, set in pairs(data.gathering) do
			gZones = gZones + 1
			if not known[zoneID] then unknown[#unknown + 1] = "zone:" .. zoneID end
			for itemID, flag in pairs(set) do
				pairsCount = pairsCount + 1
				local item = NS.GATHERING_ITEMS[itemID]
				if flag ~= true or not item or item.prof == "skinning" then unknown[#unknown + 1] = tostring(itemID) end
			end
		end
		Check("[ZDATA] récolte : 35 zones et plus, itemID tous connus de GatheringData (herbes, minerais)",
			gZones >= 35 and pairsCount > 300 and #unknown == 0, gZones .. "/" .. pairsCount .. " " .. table.concat(unknown, ","))
	end

	-- 1.3 Contenu : quelques espèces et nœuds réels ---------------------------------------------
	do
		Say("-- données de zone : contenu")
		local data = Z.DATA
		local durotar, elwynn = data.creatures[1411], data.creatures[1429]
		local boar = durotar and durotar[3098]
		Check("[ZDATA] Durotar : Sanglier tacheté (3098) niv. 1-2 ; Elwynn : Lardeur élite (448), rare (61)", boar
			and boar.en == "Mottled Boar" and boar.fr == "Sanglier tacheté" and boar.lvl[1] == 1 and boar.lvl[2] == 2
			and boar.rank == 0 and boar.f == nil and elwynn[448] and elwynn[448].rank == 1 and elwynn[61] and elwynn[61].rank == 4)
		Check("[ZDATA] exclus : bestioles (3300, 5951, 721), PNJ de service (grunt 3296, garde 68)", durotar[3300] == nil
			and durotar[5951] == nil and elwynn[721] == nil and durotar[3296] == nil and elwynn[68] == nil)
		Check("[ZDATA] faction : marine de Kul Tiras (A), grunt Kor'ja (H)", durotar[3129] and durotar[3129].f == "A"
			and durotar[12430] and durotar[12430].f == "H")
		local herbs, winter = data.gathering[1411], data.gathering[1452]
		Check("[ZDATA] récolte : Durotar (Pacifique, Terrestrine, Feuillargent, cuivre ; ni fer ni lotus), Berceau-de-l'Hiver (thorium)",
			herbs and herbs[2447] and herbs[2449] and herbs[765] and herbs[2770] and herbs[2835] and herbs[2772] == nil
			and herbs[13468] == nil and winter and winter[10620] and winter[13467])
		-- Forever : ses zones propres sont préremplies (delta-base de QuestieDB)
		local zephras, count = data.creatures[2521], 0
		for _ in pairs(zephras or {}) do count = count + 1 end
		Check("[ZDATA] Île de Zephras préremplie (Vuldren 250868, dizaines d'espèces, Pacifique)", zephras
			and zephras[250868] and zephras[250868].en == "Vuldren" and count >= 30 and data.gathering[2521]
			and data.gathering[2521][2447], count)
	end

	-- 1.4 Parts calculées avec la table, filtrées par la faction -----------------------------
	do
		Say("-- données de zone : parts et faction")
		Z.Reset("Horde")
		local part = Z.Part("bestiary")
		local horde = Z.Expected(1411, "H")
		Check("[ZDATA] Durotar (Horde), rien vu : toutes les espèces de la zone comptent", part and part.have == 0
			and part.need == horde and horde > 30, part and (part.have .. "/" .. part.need))
		local named = Z.Part("named")
		Check("[ZDATA] nommés de la table (élites, rares)", named and named.have == 0 and named.need == Z.Expected(1411, "H", true)
			and named.need >= 4, named and named.need)
		local bad = {}
		local species = NS:BestiarySpecies(1411)
		Expect(bad, "Horde", species[12430] == nil and species[3129] ~= nil)
		Z.faction = "Alliance"
		species = NS:BestiarySpecies(1411)
		Expect(bad, "Alliance", species[12430] ~= nil and species[3129] == nil and Z.Part("bestiary").need == Z.Expected(1411, "A"))
		Z.faction = nil
		species = NS:BestiarySpecies(1411)
		Expect(bad, "inconnue", species[12430] == nil and species[3129] == nil and species[3098] ~= nil)
		Z.faction = "Horde"
		Check("[ZDATA] faction : les espèces amicales envers la faction exclues (inconnue : hostiles aux deux)", #bad == 0,
			table.concat(bad, ", "))
		local frName, rare = NS:BestiarySpecies(1411)[3098].name, NS:BestiarySpecies(1411)[5808].class
		Z.locale = "enUS"
		Check("[ZDATA] espèce de la table : nom dans la langue du client, classification du rang", frName == "Sanglier tacheté"
			and rare == "rare" and NS:BestiarySpecies(1411)[3098].name == "Mottled Boar")
		Z.locale = "frFR"
		-- apprise hors table : s'ajoute (union) ; vue ET dans la table : pas comptée deux fois
		Z.W.units.target = { guid = Z.Guid(99001), name = "Bête inconnue", type = "Bête", level = 5, class = "normal" }
		Mock:Fire("PLAYER_TARGET_CHANGED")
		local union = Z.Part("bestiary").need
		Z.W.units.target = { guid = Z.Guid(3098), name = "Sanglier tacheté", type = "Bête", level = 2, class = "normal" }
		Mock:Fire("PLAYER_TARGET_CHANGED")
		Check("[ZDATA] espèce vue hors table ajoutée ; vue dans la table : pas de doublon", union == horde + 1
			and Z.Part("bestiary").need == horde + 1 and NS:BestiarySpecies(1411)[3098].seen == true, union)
	end

	-- 1.5 Abattre une espèce prérenseignée jamais vue ----------------------------------------
	-- (engagement, inconnu, module coupé : bestiary.lua)
	do
		Say("-- données de zone : abattu sans avoir été vu")
		Z.Reset("Horde")
		Z.Kill(3099, "00000000AA")
		Z.Log("PARTY_KILL", PLAYER_GUID, 0x511, Z.Guid(3105, "00000000AF"))
		local learned = NS:BestiaryZone(1411)
		Check("[ZDATA] kill (ou PARTY_KILL direct) d'une espèce de la table jamais vue : comptée, nom de la table",
			learned and learned[3099] and learned[3099].killed == 1 and learned[3099].name == "Sanglier tacheté redoutable"
			and learned[3105] and learned[3105].killed == 1 and Z.Part("bestiary").have == 2,
			learned and learned[3099] and learned[3099].name)
		Z.Kill(99002, "00000000AE")
		Check("[ZDATA] espèce hors table jamais vue : pas devinée", NS:BestiaryZone(1411)[99002] == nil)
		Z.Kill(5808, "00000000B0")
		Check("[ZDATA] nommé de la table abattu : part nommés 1/N", Z.Part("named").have == 1
			and NS:BestiaryZone(1411)[5808].class == "rare")
	end

	-- 1.6 Fenêtre : espèces jamais vues listées -----------------------------------------------
	do
		Say("-- données de zone : fenêtre")
		Z.Reset("Horde")
		Z.W.units.target = { guid = Z.Guid(3100), name = "Ancien sanglier tacheté", type = "Bête", level = 9, class = "normal" }
		Mock:Fire("PLAYER_TARGET_CHANGED")
		Z.Kill(3099, "00000000C0")
		local rows, byName = Z.Rows(1411, "combat")
		local never = byName["Sanglier tacheté, Bête (niv. 1-2)"] or byName["Sanglier tacheté (niv. 1-2)"]
		local seen = byName["Ancien sanglier tacheté, Bête (niv. 8-9)"]
		local killed = byName["Sanglier tacheté redoutable (niv. 6-7)"]
		local last
		for index = 2, #rows do
			if rows[index].header then break end
			last = rows[index]
		end
		Check("[ZDATA] fenêtre : jamais vue « à trouver » (avec niveau), vue « à abattre », abattue « abattu (1) » en fin",
			never and never.detail == "à trouver" and not never.done and seen and seen.detail == "à abattre"
			and killed and killed.detail == "abattu (1)" and killed.done and last == killed, never and never.detail)
		local rare = byName["Seigneur de guerre Kolkanis, rare (niv. 9)"]
		Check("[ZDATA] fenêtre : nommé de la table avec son rang, en-tête en espèces de la table", rare and rare.named
			and rows[1].header and rows[1].name:find("Bestiaire : 1/" .. Z.Expected(1411, "H"), 1, true), rows[1].name)
	end

	-- 1.7 Zone hors tables : tout reste dynamique ---------------------------------------------
	do
		Say("-- données de zone : zone hors tables")
		Z.Reset("Horde")
		Mock.world.mapID = 9200
		local empty = Z.Part("bestiary") == nil and Z.Part("named") == nil
		Z.Kill(3098, "00000000D0")
		local guessed = NS:BestiaryZone(9200) ~= nil
		Z.W.units.target = { guid = Z.Guid(3098, "00000000D1"), name = "Sanglier", type = "Bête", level = 2, class = "normal" }
		Mock:Fire("PLAYER_TARGET_CHANGED")
		local part = Z.Part("bestiary")
		Check("[ZDATA] zone hors tables : pas de part, kill jamais vu pas deviné, appris en jouant (0/1)", empty and not guessed
			and part and part.have == 0 and part.need == 1)
	end

	-- 1.8 Récolte : ressources présentes dans la zone -----------------------------------------
	do
		Say("-- données de zone : récolte")
		Z.Reset("Horde")
		local HEADER = { "Professions", true, true }
		Z.skills = { HEADER, { "Herboristerie", false, true, 60 }, { "Minage", false, true, 60 } }
		-- tranche à 60 : Pacifique, Feuillargent, Terrestrine, Mage royal + cuivre, pierre brute
		Mock.world.mapID = 1429
		local elwynn = Z.Part("gathering")
		Mock.world.mapID = 1411
		local durotar = Z.Part("gathering")
		Mock.world.mapID = 9200
		local outside = Z.Part("gathering")
		Check("[ZDATA] part récolte : ce qui pousse ici (Elwynn 5, Durotar 6 avec Mage royal), hors tables toute la tranche (6)",
			elwynn and elwynn.need == 5 and elwynn.have == 0 and durotar and durotar.need == 6 and outside and outside.need == 6,
			string.format("%s/%s/%s", tostring(elwynn and elwynn.need), tostring(durotar and durotar.need), tostring(outside and outside.need)))
		Mock.world.mapID = 1411
		NS:GatheringRecord(2447, 1, 1411)
		local part = Z.Part("gathering")
		local hint = table.concat(part.hint, " | ")
		Check("[ZDATA] Pacifique récoltée ici -> 1/6, survol sur la zone", part.have == 1 and part.need == 6
			and hint:find("(50)", 1, true) and hint:find("Durotar", 1, true), hint)
		-- herboriste confirmé en zone de départ (1.5.1) : les herbes grises comptent, marquées
		Z.skills = { HEADER, { "Herboristerie", false, true, 290 } }
		Mock.world.mapID = 1429
		part = Z.Part("gathering")
		local list = NS:GatheringZoneList(1429)
		Check("[ZDATA] Elwynn à 290 : les 3 herbes de la zone, grises, hors tranche à points", part and part.need == 3
			and #list == 3 and list[1].grayed and list[3].grayed and #(NS:GatheringZoneBand(1429)) == 0, part and part.need)
		-- 1.5.5 : ce qui pousse ici mais demande plus de compétence est montré, verrouillé, jamais compté
		Z.skills = { HEADER, { "Herboristerie", false, true, 10 } }
		part = Z.Part("gathering")
		local all, locked = NS:GatheringZoneList(1429, true), nil
		for _, entry in ipairs(all) do if entry.locked then locked = entry end end
		local rows = NS:JournalProgressItems(1429, "craft")
		local lastRow = rows[#rows]
		Check("[ZDATA] Elwynn à 10 : Terrestrine (15) pas comptée (2), montrée verrouillée en fin de carnet",
			part and part.need == 2 and #all == 3 and locked and locked.itemID == 2449 and locked.req == 15 and not locked.grayed
			and lastRow and lastRow.locked and lastRow.detail == "compétence 15 requise", lastRow and lastRow.detail)
		-- rien à ta portée mais tout pour plus tard : la liste le montre quand même
		Z.skills = { HEADER, { "Minage", false, true, 1 } }
		Mock.world.mapID = 1419
		local later = NS:JournalProgressItems(1419, "craft")
		Check("[ZDATA] Terres foudroyées à 1 en minage : pas de part, minerais pour plus tard listés",
			Z.Part("gathering") == nil and #later > 0 and later[1].locked, #later)
		Mock.world.mapID = 1429
		-- dépeçage : jamais filtré (pas de données de zone)
		Z.skills = { HEADER, { "Dépeçage", false, true, 60 } }
		part = Z.Part("gathering")
		local band = NS:GatheringBand("skinning", 60)
		Check("[ZDATA] dépeçage : toute la tranche, même en zone préremplie", part and part.need == #band and #band > 0)
		Z.skills = { HEADER, { "Herboristerie", false, true, 60 } }
		rows = Z.Rows(1429, "craft")
		Check("[ZDATA] fenêtre Métiers : en-tête + 3 herbes d'Elwynn", #rows == 4 and rows[1].header
			and rows[1].name:find("0/3", 1, true), #rows)
	end

	for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
	C_Map.GetAreaInfo = saved.GetAreaInfo
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryRejected = {}, nil, {}
	NS.journalRares = {}
	if NS.journalTracker then NS.journalTracker:Hide() end
	NS.journalTracker = nil
	NS.journalFrame = nil
	ResetWorld()
end

-- ============================================================================
-- 2. Quêtes de zone (ZoneQuests.lua + ZoneQuests_Forever.lua)
-- ============================================================================
do
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
	local function Flagged(id) Q.calls = Q.calls + 1; return Q.done[id] == true end
	C_QuestLog.IsQuestFlaggedCompleted = Flagged
	C_Map.GetAreaInfo = nil

	function Q.Load(file, forever)
		local fake = { Mark = function() end, IsForeverClient = function() return forever end, LazyZones = NS.LazyZones }
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
	-- la liste donne exactement les ids du calcul de contrôle
	function Q.Same(zoneID, race, class)
		local ids, expected = Q.Ids(NS:ZoneQuestList(zoneID)), Q.Expected(Q.FOREVER[zoneID], race, class)
		if Q.Count(ids) ~= Q.Count(expected) then return false end
		for id in pairs(expected) do if not ids[id] then return false end end
		return true
	end
	function Q.Part(zoneID)
		local done = NS:ZoneCompletion(zoneID)
		for _, part in ipairs(done and done.parts or {}) do if part.id == "quests" then return part end end
		return nil
	end
	function Q.OpenCompletion()
		NS.CompanionNextUnlocks = function() return {} end
		NS:JournalData().stamps["zone:1411"] = { id = "zone:1411", kind = "zone", name = "Durotar", at = 0 }
		NS:DB().journalTracker = false
		NS:ToggleJournal(true)
		NS:SelectJournalKind("completion")
		return NS.journalFrame, NS.journalFrame.prog
	end

	-- 2.1 Intégrité ------------------------------------------------------------------------
	do
		Say("-- quêtes de zone : intégrité")
		local known = { [1450] = true }
		for zoneID in pairs(NS.ZONE_LEVELS or {}) do known[zoneID] = true end
		local data = Q.FOREVER
		local zones, count, bad, badZones, seen = 0, 0, {}, {}, {}
		local maxRaces = 0
		for _, zoneID in ipairs(NS.ZoneIds(data)) do
			zones = zones + 1
			if not known[zoneID] and zoneID <= 2000 then badZones[#badZones + 1] = zoneID end
			for id, q in pairs(data[zoneID]) do
				count = count + 1
				local ok = not seen[id] and type(id) == "number" and id > 0 and id == math.floor(id)
					and type(q.lvl) == "number" and q.lvl >= -1 and q.lvl <= 63 and q.lvl == math.floor(q.lvl)
					and type(q.req) == "number" and q.req >= 0 and q.req <= 63
					and type(q.races) == "number" and q.races >= 0 and q.races == math.floor(q.races)
					and type(q.classes) == "number" and q.classes >= 0 and q.classes <= 2047
					and type(q.fr) == "string" and q.fr ~= "" and type(q.en) == "string" and q.en ~= ""
				seen[id] = true
				if ok and q.ex ~= nil then
					ok = type(q.ex) == "table" and #q.ex > 0
					for _, other in ipairs(q.ex or {}) do
						ok = ok and type(other) == "number" and other > 0 and other ~= id
					end
				end
				if type(q.races) == "number" and q.races > maxRaces then maxRaces = q.races end
				if not ok and #bad < 5 then bad[#bad + 1] = zoneID .. ":" .. tostring(id) end
			end
		end
		Check("[ZQ] zones et quêtes, zones connues (coffre, Reflet-de-Lune, Forever), Skyborne (bits 32 et 33)",
			zones >= 39 and count > 2000 and #badZones == 0 and maxRaces >= 2 ^ 32 and maxRaces < 2 ^ 34,
			zones .. "/" .. count .. " " .. table.concat(badZones, ","))
		Check("[ZQ] ids, niveaux, masques, noms fr+en, ex ; une quête dans une seule zone", #bad == 0, table.concat(bad, ","))
		local handle = assert(io.open(ROOT .. "/QuestCompanion/ZoneQuests_Forever.lua", "rb"))
		local kb = handle:seek("end") / 1024
		handle:close()
		Check("[ZQ] taille : moins de 500 Ko", kb < 500, string.format("%.0f Ko", kb))
	end

	-- 2.2 Contenu réel ---------------------------------------------------------------------
	do
		Say("-- quêtes de zone : contenu")
		local F = Q.FOREVER
		Check("[ZQ] Skyborne : Elwynn 783 (Alliance, 2^32), Durotar 4641 (Horde, 2^33)", F[1429] and F[1429][783]
			and F[1429][783].races == 77 + 2 ^ 32 and F[1411] and F[1411][4641] and F[1411][4641].en == "Your Place In The World"
			and F[1411][4641].races == 178 + 2 ^ 33)
		-- catégorie de classe de Questie (zoneOrSort -161) sans requiredClasses : la classe en vient (2.8.3)
		Check("[ZQ] Île de Zephras : « Coming of Age » (92460), « Boughs in the Wind » (93797) réservée aux mages",
			F[2521] and F[2521][92460] and F[2521][92460].en == "Coming of Age" and F[2521][93797] and F[2521][93797].classes == 128)
		Check("[ZQ] exclusives réelles : éclats de gangrechien / d'infernal (4962 <-> 4963)", F[1413][4962].ex[1] == 4963
			and F[1413][4963].ex[1] == 4962 and F[1413][4962].classes == 256)
		-- exclues en amont : cachée, répétable, métier, événement, JcJ
		local present = {}
		for _, id in ipairs({ 787, 5843, 813, 926, 16, 862, 171, 7141 }) do
			for _, zoneID in ipairs(NS.ZoneIds(F)) do if F[zoneID][id] then present[#present + 1] = id end end
		end
		Check("[ZQ] exclues : cachées (787, 5843), répétables (813, 926, 16), métier (862), événement (171), JcJ (7141)",
			#present == 0, table.concat(present, ","))
	end

	-- 2.3 Filtres race / classe --------------------------------------------------------------
	do
		Say("-- quêtes de zone : race et classe")
		Q.Reset()
		local list = NS:ZoneQuestList(1411)
		local ids = Q.Ids(list)
		Check("[ZQ] orc guerrier, Durotar : exactement les quêtes de sa race et de sa classe (4641, 2383 ; pas 3065, 3087)",
			NS:ZoneQuestsAvailable() == true and #list > 30 and Q.Same(1411, 2, 1) and ids[4641] and ids[2383]
			and not ids[3065] and not ids[3087], list and #list)
		Q.race, Q.class = 8, 8   -- troll mage
		ids = Q.Ids(NS:ZoneQuestList(1411))
		Check("[ZQ] troll mage : sa liste à part (3086, plus de parchemin d'orc)", ids[3086] and not ids[2383] and ids[4641]
			and Q.Same(1411, 8, 8))
		Q.race, Q.class = 1, 1   -- humain
		Check("[ZQ] humain : pas de quête de la Horde à Durotar, « A Threat Within » à Elwynn",
			Q.Ids(NS:ZoneQuestList(1411))[4641] == nil and Q.Ids(NS:ZoneQuestList(1429))[783] ~= nil)
		-- race inconnue (UnitRace absent) : pas de filtre de race
		_G.UnitRace = nil
		Check("[ZQ] race inconnue : pas de filtre de race", Q.Ids(NS:ZoneQuestList(1429))[783] ~= nil)
		_G.UnitRace = function() return "Orc", "Orc", Q.race end
		-- Skyborne (raceID 95 / 96, bits 32 / 33, sans bit.band)
		Q.Reset(Q.FOREVER)
		Q.race, Q.class = 95, 1
		local alliance = Q.Ids(NS:ZoneQuestList(1429))[783] ~= nil and Q.Same(1429, 95, 1)
			and Q.Ids(NS:ZoneQuestList(1411))[4641] == nil
		Q.race = 96
		ids = Q.Ids(NS:ZoneQuestList(1411))
		Check("[ZQ] Skyborne : Alliance compte Elwynn 783, pas Durotar ; Horde compte Durotar 4641 et 788", alliance
			and ids[4641] ~= nil and ids[788] ~= nil)
	end

	-- 2.4 Faites, à faire, liste, survol -------------------------------------------------------
	do
		Say("-- quêtes de zone : faites et à faire")
		Q.Reset()
		local part = NS:ZoneQuestsPart(1411)
		local total = Q.Count(Q.Expected(Q.FOREVER[1411], 2, 1))
		Check("[ZQ] rien de fait : 0/N ; survol « À faire : », 6 noms puis « … et N autres »", part and part.have == 0
			and part.need == total and part.hint[1] == "À faire :" and #part.hint == 8 and part.hint[2]:find("^  · ")
			and part.hint[8] == NS:F("JRN_HINT_MORE", total - 6), part and part.hint[8])
		local items = NS:ZoneQuestsItems(1411)
		local sorted = items[1] and items[1].detail == "niveau 1" and items[#items].detail:find("^niveau ") ~= nil
		for index = 2, #items do
			local a, b = Q.FOREVER[1411][items[index - 1].id], Q.FOREVER[1411][items[index].id]
			local la = a.lvl > 0 and a.lvl or (a.req > 0 and a.req or 999)
			local lb = b.lvl > 0 and b.lvl or (b.req > 0 and b.req or 999)
			sorted = sorted and la <= lb
		end
		Check("[ZQ] Items : niveaux croissants, détail « niveau N », noms en français", sorted
			and Q.Ids(items)[4641].name == "Votre place en ce monde")
		Q.done[4641], Q.done[788] = true, true
		Mock:Fire("QUEST_TURNED_IN", 788, 0, 0)
		part = NS:ZoneQuestsPart(1411)
		items = NS:ZoneQuestsItems(1411)
		Check("[ZQ] deux faites : 2/N, en fin de liste « faite », hors du survol", part.have == 2 and part.need == total
			and items[#items].done and items[#items - 1].done and items[#items].detail == "faite" and not items[1].done
			and not table.concat(part.hint, "|"):find("Votre place", 1, true), part.have .. "/" .. part.need)
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
		C_QuestLog.IsQuestFlaggedCompleted = Flagged
	end

	-- 2.5 Exclusives et quêtes fermées ---------------------------------------------------------
	do
		Say("-- quêtes de zone : exclusives")
		Q.Reset()
		Q.race, Q.class = 2, 9   -- orc démoniste
		local ids = Q.Ids(NS:ZoneQuestList(1413))
		local both = ids[4962] and ids[4963]
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
		Check("[ZQ] exclusive : les deux comptent, l'une faite, l'autre ne compte plus", both and ids[4962] == nil
			and ids[4963] and ids[4963].done and closed >= 1 and part.need == before - closed and part.have == 1,
			part.need .. " / " .. before .. " - " .. closed)
		-- quête d'approche : la suite faite (7) ferme 783 ; 783 faite elle-même reste comptée
		Q.Reset()
		Q.race = 1
		local todo = Q.Ids(NS:ZoneQuestList(1429))[783]
		Q.done[7] = true
		Mock:Fire("QUEST_LOG_UPDATE")
		ids = Q.Ids(NS:ZoneQuestList(1429))
		local closedBySequel = ids[783] == nil and ids[7] and ids[7].done
		Q.done[783] = true
		Mock:Fire("QUEST_LOG_UPDATE")
		Check("[ZQ] suite faite (7) : 783 fermée ; faite elle-même : comptée", todo and not todo.done and closedBySequel
			and Q.Ids(NS:ZoneQuestList(1429))[783] ~= nil)
	end

	-- 2.6 Cache, invalidation, combat ----------------------------------------------------------
	do
		Say("-- quêtes de zone : cache et combat")
		Q.Reset()
		NS:ZoneQuestsPart(1411)
		local builds, calls = NS.zoneQuests.builds, Q.calls
		NS:ZoneQuestsPart(1411)
		NS:ZoneQuestsItems(1411)
		Q.done[4641] = true
		Check("[ZQ] cache : liste réutilisée, statut ni relu ni changé sans événement", NS.zoneQuests.builds == builds
			and Q.calls == calls and builds == 1 and NS:ZoneQuestsPart(1411).have == 0)
		Mock:Fire("QUEST_TURNED_IN", 4641, 0, 0)
		Check("[ZQ] QUEST_TURNED_IN : cache oublié, recalculé", NS:ZoneQuestsPart(1411).have == 1 and NS.zoneQuests.builds == 2)
		-- combat : l'oubli attend la fin du combat (verrou du client ou drapeau du suivi)
		Q.combat = true
		Q.done[788] = true
		Mock:Fire("QUEST_LOG_UPDATE")
		local part = NS:ZoneQuestsPart(1411)
		Q.combat = nil
		NS.journalTrackerCombat = true
		local flagged = NS:ZoneQuestsPart(1411).have
		NS.journalTrackerCombat = nil
		Check("[ZQ] combat : la liste en cache sert, pas de recalcul", part.have == 1 and NS.zoneQuests.builds == 2
			and NS.zoneQuests.dirty == true and flagged == 1)
		Mock:Fire("PLAYER_REGEN_ENABLED")
		Check("[ZQ] fin du combat : statut relu", NS:ZoneQuestsPart(1411).have == 2 and NS.zoneQuests.dirty == false)
		NS:DB().companionEnabled = false
		local off = NS:ZoneQuestsPart(1411) == nil and #NS:ZoneQuestsItems(1411) == 0
		NS:DB().companionEnabled = nil
		Check("[ZQ] module coupé ou zone hors table : rien", off and NS:ZoneQuestsPart(9999) == nil
			and NS:ZoneQuestList(nil) == nil)
	end

	-- 2.7 Part de complétion, client sans table --------------------------------------------------
	do
		Say("-- quêtes de zone : complétion et client sans table")
		Q.Reset()
		local def
		for _, d in ipairs(NS.ZONE_PARTS) do if d.id == "quests" then def = d end end
		local part = Q.Part(1411)
		Check("[ZQ] part « Quêtes » enregistrée (onglet quests, Items) et dans la complétion de zone", def and def.tab == "quests"
			and def.label == "JRN_PART_quests" and #def.Items(NS, 1411) > 30 and part and part.label == "Quêtes"
			and part.need == Q.Count(Q.Expected(Q.FOREVER[1411], 2, 1)))
		Q.Reset(false)
		local unavailable = NS:ZoneQuestsAvailable() == false
		local ok, value = pcall(NS.ZoneQuestsPart, NS, 1411)
		NS.ZONE_QUESTS = {}
		Check("[ZQ] client sans table (ou table vide) : indisponible, pas de part, pas d'erreur", unavailable and ok
			and value == nil and #NS:ZoneQuestsItems(1411) == 0 and NS:ZoneQuestsAvailable() == false)
		NS.ZONE_QUESTS = { [1411] = { [1] = "pas une table", [2] = { en = "Sans masque" } } }
		ok, value = pcall(NS.ZoneQuestsPart, NS, 1411)
		Check("[ZQ] entrée abîmée ignorée, entrée sans masque gardée", ok and value and value.need == 1)
		local S = NS.ZONE_QUESTS_STRINGS
		local missing = {}
		for key in pairs(S.fr) do if not S.en[key] then missing[#missing + 1] = key end end
		for key in pairs(S.en) do if not S.fr[key] then missing[#missing + 1] = key end end
		local all = ""
		for _, key in ipairs({ "JRN_ACT_quests", "JRN_QUESTS_TIP", "JRN_ACT_NO_QUESTS", "JRN_ACT_EMPTY_quests", "JRN_PART_quests" }) do
			all = all .. tostring(NS.L[key])
		end
		for _, v in pairs(S.fr) do all = all .. v end
		for _, v in pairs(S.en) do all = all .. v end
		Check("[ZQ] chaînes : mêmes clés fr / en, plus aucune mention de Questie", #missing == 0
			and S.fr.ZQ_NO_LIST == "Pas de liste de quêtes pour ce client." and NS.L.JRN_ACT_NO_QUESTS == S.fr.ZQ_NO_LIST
			and not all:find("Questie", 1, true) and rawget(NS.L, "JRN_ACT_quests_off") == nil
			and rawget(NS.L, "JRN_ACT_NO_QUESTIE") == nil, table.concat(missing, ","))
	end

	-- 2.8 Fenêtre (la page Complétion elle-même : journal.lua) -------------------------------------
	do
		Say("-- quêtes de zone : fenêtre")
		Q.Reset()
		local f, prog = Q.OpenCompletion()
		local quests = prog.parts.quests
		quests.onEnter(quests)
		local tip = table.concat(_G.GameTooltip.lines or {}, " ")
		quests.onLeave(quests)
		Check("[ZQ] fenêtre : part « Quêtes » de Durotar, pas grisée, survol sans Questie", f.kind == "progress"
			and f.zoneID == 1411 and quests.label.text == "Quêtes" and quests.label.textColor[1] ~= NS.Theme.MUTED[1]
			and not quests.dim and tip:find(NS.L.JRN_QUESTS_TIP, 1, true) and not tip:find("Questie", 1, true), tip)
		quests:Click()
		local first = prog.items[1]
		local ordered, seenDone, todo = true, false, 0
		for _, item in ipairs(f.progRows) do
			if not item.header then
				if item.done then seenDone = true elseif seenDone then ordered = false else todo = todo + 1 end
			end
		end
		Check("[ZQ] liste : en-tête, quêtes à faire d'abord (niveau), faites ensuite", prog.head.text:find("Quêtes", 1, true)
			and first.item and not first.item.header and not first.item.done and first.detail.text:find("niveau", 1, true)
			and prog.empty.text == "" and ordered and todo > 0, prog.head.text)
		NS:ToggleJournal(false)
		-- client sans table : part grisée, message clair
		Q.Reset(false)
		f, prog = Q.OpenCompletion()
		local dim = prog.parts.quests.label.textColor[1] == NS.Theme.MUTED[1]
		prog.parts.quests:Click()
		Check("[ZQ] client sans table : « Quêtes » grisé, « Pas de liste de quêtes pour ce client. »", dim
			and prog.empty.text == "Pas de liste de quêtes pour ce client.", prog.empty.text)
		NS:ToggleJournal(false)
		NS:DB().journalTracker = nil
	end

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
end

-- ============================================================================
-- 3. Récolte selon le métier (comportement dynamique : tables de zone mises de côté)
-- ============================================================================
do
	local saved, MOCKED = {}, { "GetNumSkillLines", "GetSkillLineInfo", "GetProfessions", "GetProfessionInfo", "IsInInstance",
		"UnitName", "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }
	for _, name in ipairs(MOCKED) do saved[name] = rawget(_G, name) end
	saved.ZONE_CREATURES, saved.ZONE_GATHERING = rawget(NS, "ZONE_CREATURES"), rawget(NS, "ZONE_GATHERING")
	saved.ZONE_QUESTS = rawget(NS, "ZONE_QUESTS")
	NS.ZONE_CREATURES, NS.ZONE_GATHERING, NS.ZONE_QUESTS = nil, nil, nil

	local G = { skills = {}, instance = false, char = "Testeur" }
	_G.GetNumSkillLines = function() return #G.skills end
	-- name, isHeader, isExpanded, skillRank
	_G.GetSkillLineInfo = function(index)
		local s = G.skills[index]
		if not s then return nil end
		return s[1], s[2] == true, s[3] ~= false, s[4] or 0
	end
	local SkillCount, SkillLine = _G.GetNumSkillLines, _G.GetSkillLineInfo
	_G.IsInInstance = function() return G.instance == true, G.instance and "party" or "none" end
	_G.UnitName = function() return G.char end
	_G.LOOT_ITEM_SELF = "Vous recevez le butin : %s."
	_G.LOOT_ITEM_SELF_MULTIPLE = "Vous recevez le butin : %sx%d."
	_G.LOOT_ITEM_PUSHED_SELF = "Vous recevez l'objet : %s."
	_G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "Vous recevez l'objet : %sx%d."

	local MAPS = {
		[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 },
		[1415] = { mapID = 1415, name = "Royaumes de l'Est", parentMapID = 947, mapType = 2 },
		[947]  = { mapID = 947,  name = "Azeroth", parentMapID = 0, mapType = 1 },
		[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 },
		[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 1415, mapType = 3 },
	}

	local HEADER = { "Professions", true, true }
	function G.Fresh(skills)
		ResetWorld()
		for id, info in pairs(MAPS) do Mock.world.maps[id] = info end
		Mock.world.mapID = 1413
		Mock.world.level = 30
		G.skills, G.instance, G.char = skills or {}, false, "Testeur"
		if NS.journalTracker then NS.journalTracker:Hide() end
		NS.journalTracker = nil
		NS.journalFrame = nil
	end
	function G.Link(itemID, name) return "|cffffffff|Hitem:" .. itemID .. "::::::::|h[" .. (name or "Objet") .. "]|h|r" end
	function G.Loot(itemID, count)
		Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : " .. G.Link(itemID) .. (count and ("x" .. count) or "") .. ".")
	end
	function G.Find(prefix)
		for _, goal in ipairs(NS:JournalObjectives()) do
			if goal.id:sub(1, #prefix) == prefix then return goal end
		end
	end
	function G.Ids(band)
		local out = {}
		for _, entry in ipairs(band) do out[#out + 1] = tostring(entry.itemID) end
		return table.concat(out, ",")
	end
	function G.Keys(list)
		local keys = {}
		for _, entry in ipairs(list) do keys[#keys + 1] = entry.key .. "=" .. entry.rank end
		return table.concat(keys, ",")
	end
	function G.Part()
		for _, def in ipairs(NS.ZONE_PARTS or {}) do if def.id == "gathering" then return def end end
	end
	local HERB_120 = { HEADER, { "Herboristerie", false, true, 120 }, { "Minage", false, true, 80 }, { "Couture", false, true, 50 } }

	-- 3.1 Table des ressources --------------------------------------------------------------------
	do
		Say("-- récolte : table des ressources")
		local items, profs = NS.GATHERING_ITEMS, NS.GATHERING_PROFESSIONS
		local bad, perProf = {}, {}
		for itemID, entry in pairs(items or {}) do
			local ok = type(itemID) == "number" and itemID > 0 and profs[entry.prof] ~= nil
				and type(entry.req) == "number" and type(entry.gray) == "number" and entry.req >= 1 and entry.req < entry.gray
				and type(entry.fr) == "string" and entry.fr ~= "" and type(entry.en) == "string" and entry.en ~= ""
			if not ok then bad[#bad + 1] = tostring(itemID) end
			perProf[entry.prof] = (perProf[entry.prof] or 0) + 1
		end
		Check("[GTH] table : chaque entrée a métier, requise < grise, noms fr/en ; les trois métiers fournis", items and #bad == 0
			and (perProf.herbalism or 0) >= 25 and (perProf.mining or 0) >= 10 and (perProf.skinning or 0) >= 8,
			table.concat(bad, ",") .. string.format(" %s/%s/%s", tostring(perProf.herbalism), tostring(perProf.mining), tostring(perProf.skinning)))
		Check("[GTH] table : repères (Pacifique, Lotus noir, cuivre, thorium, cuir épais), gris à requise + 100",
			items[2447].en == "Peacebloom" and items[2447].req == 1 and items[13468].fr == "Lotus noir" and items[13468].req == 300
			and items[2770].prof == "mining" and items[10620].req == 245 and items[4304].fr == "Cuir épais"
			and items[3369].gray == 220 and items[2771].gray == 165)
		local fr, en, mismatch = NS.GATHERING_STRINGS.fr, NS.GATHERING_STRINGS.en, {}
		local function Jokers(text) local out = {} for j in tostring(text):gmatch("%%[sd]") do out[#out + 1] = j end return table.concat(out) end
		for key, value in pairs(fr) do
			if en[key] == nil or Jokers(value) ~= Jokers(en[key]) then mismatch[#mismatch + 1] = key end
		end
		for key in pairs(en) do if fr[key] == nil then mismatch[#mismatch + 1] = key end end
		Check("[GTH] chaînes fr/en : mêmes clés, mêmes %s", #mismatch == 0, table.concat(mismatch, ","))
	end

	-- 3.2 Métiers et tranche ------------------------------------------------------------------------
	do
		Say("-- récolte : métiers et tranche")
		G.Fresh(HERB_120)
		local bad = {}
		local found = NS:GatheringProfessions()
		Expect(bad, "fr", found.herbalism == 120 and found.mining == 80 and found.skinning == nil and found.tailoring == nil)
		G.skills = { HEADER, { "Skinning", false, true, 42 } }
		found = NS:GatheringProfessions()
		Expect(bad, "en", found.skinning == 42 and found.herbalism == nil)
		G.skills = { HEADER, { "  MINAGE ", false, true, 3 } }
		Expect(bad, "casse", NS:GatheringProfessions().mining == 3)
		G.skills = { HEADER, { "Dépeçage", false, true, 7 } }
		Expect(bad, "accent", NS:GatheringProfessions().skinning == 7)
		Check("[GTH] métiers de récolte lus avec leur rang (fr, en, casse, accents), couture ignorée", #bad == 0,
			table.concat(bad, ", "))
		-- catégorie repliée : le dernier rang connu sert ; dépliée et sans le métier : oublié
		G.skills = HERB_120
		NS:GatheringProfessions()
		G.skills = { { "Professions", true, false } }
		local collapsed = NS:GatheringProfessions()
		G.skills = { HEADER, { "Minage", false, true, 81 } }
		found = NS:GatheringProfessions()
		Check("[GTH] catégorie repliée : dernier rang connu ; métier désappris : oublié", collapsed.herbalism == 120
			and collapsed.mining == 80 and found.herbalism == nil and found.mining == 81)

		-- tous les métiers (1.5.1) : récolte, artisanat et secondaires, nommés
		G.skills = { { "Compétences secondaires", true, true }, { "Pêche", false, true, 40 }, { "Cuisine", false, true, 75 },
			{ "Secourisme", false, true, 60 }, HEADER, { "Forge", false, true, 180 }, { "Minage", false, true, 215 } }
		local keys = G.Keys(NS:PlayerProfessions())
		local lines = NS:JournalCraftLines()
		Check("[GTH] tous les métiers : récolte, artisanat puis secondaires, en clair dans la carte Métiers",
			keys == "mining=215,blacksmithing=180,cooking=75,fishing=40,firstaid=60"
			and NS:PlayerProfessionsText() == "Minage 215  ·  Forge 180  ·  Cuisine 75  ·  Pêche 40  ·  Secourisme 60"
			and lines[1]:find("Forge 180", 1, true) and lines[2] == NS.L.GATHER_ONLY_GATHER, keys)
		G.skills = { { "Professions", true, false } }
		local kept = #NS:PlayerProfessions() == 5
		G.skills = { HEADER }
		Check("[GTH] catégorie repliée : dernière liste ; aucun métier : nil et message", kept
			and NS:PlayerProfessionsText() == nil and NS:JournalCraftLines()[1] == NS.L.GATHER_PROFS_NONE)
		G.skills = { HEADER, { "Minage", false, true, 81 } }
		NS:GatheringProfessions()

		-- moteur récent (WoW Forever) : GetProfessions / GetProfessionInfo, sans fenêtre de compétences (1.5.2)
		_G.GetNumSkillLines, _G.GetSkillLineInfo = nil, nil
		local PROFS = { [3] = { "Minage", 215, 186 }, [7] = { "Forge", 180, 164 }, [9] = { "Pêche", 40, 356 },
			[10] = { "Cuisine", 75, 185 } }
		_G.GetProfessions = function() return 7, 3, nil, 9, 10 end
		_G.GetProfessionInfo = function(index)
			local p = PROFS[index]
			return p[1], "icon", p[2], 300, 4, 0, p[3], 0
		end
		keys = G.Keys(NS:PlayerProfessions())
		local mining = NS:GatheringProfessions().mining
		-- nom inconnu mais ligne connue : reconnu quand même
		PROFS[3] = { "Mining (beta)", 216, 186 }
		Check("[GTH] GetProfessions : métiers lus par leur ligne de compétence (186 = minage, quel que soit le nom)",
			keys == "mining=215,blacksmithing=180,cooking=75,fishing=40" and mining == 215
			and NS:GatheringProfessions().mining == 216, keys)
		_G.GetProfessionInfo = function() error("panne") end
		local ok = pcall(NS.PlayerProfessions, NS)
		_G.GetProfessions, _G.GetProfessionInfo = nil, nil
		Check("[GTH] GetProfessionInfo en panne, puis aucune API : la dernière liste sert", ok
			and NS:GatheringProfessions().mining ~= nil)
		-- /qc metiers : diagnostic
		local printed = {}
		local oldPrint = NS.Print
		NS.Print = function(_, msg) printed[#printed + 1] = msg end
		NS.EXTRA_COMMANDS["metiers"](NS)
		NS.Print = oldPrint
		Check("[GTH] /qc metiers : API vues et métiers", #printed == 2 and printed[1]:find("API", 1, true) ~= nil, table.concat(printed, " | "))
		_G.GetNumSkillLines, _G.GetSkillLineInfo = SkillCount, SkillLine
		G.skills = { HEADER, { "Minage", false, true, 81 } }
		NS:GatheringProfessions()

		local band, low = NS:GatheringBand("herbalism", 120)
		Check("[GTH] tranche 120 : de Mage royal à Tombeline, gris exclus", G.Ids(band) == "785,2450,3820,2453,3355,3369" and low == 120,
			G.Ids(band) .. " low=" .. tostring(low))
		bad = {}
		band, low = NS:GatheringBand("herbalism", 101)
		Expect(bad, "101", G.Ids(band) == "2449,785,2450,3820,2453" and low == 100)
		band, low = NS:GatheringBand("herbalism", 100)
		Expect(bad, "100", band[#band].itemID == 2453 and low == 100 and #band == 7)
		band, low = NS:GatheringBand("mining", 80)
		Expect(bad, "minage 80", #band == 5 and low == 75)
		Expect(bad, "sans rang", #NS:GatheringBand("herbalism", nil) == 0)
		Check("[GTH] bornes : grise exclue, requise incluse ; minage ; sans rang vide", #bad == 0, table.concat(bad, ", "))
		local fallback = NS:GatheringItemName(785)
		Mock.world.itemInfo[785] = { name = "Mage royal (client)" }
		Check("[GTH] nom : celui du client s'il le connaît, sinon le français", fallback == "Mage royal"
			and NS:GatheringItemName(785) == "Mage royal (client)")
	end

	-- 3.3 Butin ---------------------------------------------------------------------------------------
	do
		Say("-- récolte : butin")
		G.Fresh(HERB_120)
		G.Loot(785)
		G.Loot(785, 3)
		Mock.world.mapID = 1429
		G.Loot(785)
		local data = NS:GatheringData()
		Check("[GTH] butin : ressource comptée (quantité comprise), par zone", data[785] and data[785].count == 5
			and data[785].zones[1413] == 4 and data[785].zones[1429] == 1)
		Mock:Fire("CHAT_MSG_LOOT", "Bob reçoit le butin : " .. G.Link(2450) .. ".")
		G.Loot(2000)
		Mock:Fire("CHAT_MSG_LOOT", "Vous recevez l'objet : " .. G.Link(2450) .. ".")
		G.Loot(2318)
		Check("[GTH] ignorés : butin d'un autre, objet hors table, objet reçu (achat, quête), cuir sans dépeçage",
			data[2450] == nil and data[2000] == nil and data[2318] == nil)
		G.instance = true
		G.Loot(2770)
		G.instance = false
		Check("[GTH] en instance : compté, sans zone", data[2770] and data[2770].count == 1 and next(data[2770].zones) == nil)
		Check("[GTH] analyse : repli anglais reconnu ; message vide ou étranger : rien",
			NS:GatheringParseLoot("You receive loot: " .. G.Link(2771) .. "x2.") == 2771
			and NS:GatheringParseLoot(nil) == nil and NS:GatheringParseLoot("bonjour") == nil)
	end

	-- 3.4 Objectifs et survol -------------------------------------------------------------------------
	do
		Say("-- récolte : objectifs")
		G.Fresh(HERB_120)
		G.Loot(785)
		local goal = G.Find("gather:herbalism:")
		local hint = goal and table.concat(goal.hint, " | ") or ""
		Check("[GTH] objectif : id stable, libellé, progression ; survol : manquantes avec leur compétence, aide minicarte",
			goal and goal.id == "gather:herbalism:120" and goal.label == "Récolte à ton niveau : Herboristerie"
			and goal.progress == "1/6" and goal.unit == "ressources" and hint:find("À récolter à ta compétence :", 1, true)
			and hint:find("Églantine (70)", 1, true) and hint:find("Tombeline (120)", 1, true)
			and not hint:find("Mage royal", 1, true) and hint:find("Découverte d'herbes", 1, true), hint)
		local mining = G.Find("gather:mining:")
		Check("[GTH] un objectif par métier de récolte", mining and mining.id == "gather:mining:75" and mining.progress == "0/5"
			and table.concat(mining.hint, " "):find("Découverte de gisements", 1, true), mining and mining.id)
		local tip = NS:ShowJournalGoalTooltip(UIParent, goal)
		local text = tip and table.concat(tip.lines or {}, " | ") or ""
		Check("[GTH] bulle du carnet : unité et noms", text:find("1/6 ressources", 1, true) and text:find("Doulourante (100)", 1, true), text)
		tip:Hide()
		G.skills = { HEADER, { "Herboristerie", false, true, 300 } }
		goal = G.Find("gather:herbalism:")
		hint = goal and table.concat(goal.hint, " | ") or ""
		Check("[GTH] 300 : borne basse 300, 13 herbes, liste coupée à 6", goal and goal.id == "gather:herbalism:300"
			and goal.need == 13 and hint:find("… et 7 autres", 1, true), hint)
		G.skills = HERB_120
		for _, entry in ipairs((NS:GatheringBand("herbalism", 120))) do G.Loot(entry.itemID) end
		Check("[GTH] tranche complète : plus d'objectif", G.Find("gather:herbalism:") == nil)
		-- masquage par id (contrat du carnet) ; nouvelle ressource dans la tranche : nouvel id, de retour
		NS:JournalDismiss("gather:mining:75", true)
		local dismissed = G.Find("gather:mining:").dismissed == true
		G.skills = { HEADER, { "Minage", false, true, 125 } }
		Check("[GTH] objectif masquable ; nouvelle ressource dans la tranche : nouvel id visible", dismissed
			and G.Find("gather:mining:").id == "gather:mining:125" and not G.Find("gather:mining:").dismissed)
	end

	-- 3.5 Part de complétion de zone ------------------------------------------------------------------
	do
		Say("-- récolte : part de zone")
		G.Fresh(HERB_120)
		local part = G.Part()
		G.Loot(785); G.Loot(2770)
		Mock.world.mapID = 1429
		G.Loot(2450)
		local tarides = part.Compute(NS, 1413)
		local hint = tarides and table.concat(tarides.hint, " | ") or ""
		Check("[GTH] part « gathering » : récoltées dans la zone / tranches réunies, survol concret", part
			and part.label == "JRN_PART_gathering" and NS.L.JRN_PART_gathering == "Récolte" and tarides and tarides.have == 2
			and tarides.need == 11 and hint:find("dans Les Tarides", 1, true) and hint:find("Églantine (70)", 1, true)
			and hint:find("Découverte de gisements", 1, true), hint)
		local elwynn = part.Compute(NS, 1429)
		Check("[GTH] part : autre zone à part, zone inconnue 0, sans zone nil", elwynn and elwynn.have == 1
			and elwynn.need == 11 and part.Compute(NS, 4242).have == 0 and part.Compute(NS, nil) == nil)
		G.skills = { HEADER, { "Herboristerie", false, true, 120 } }
		for _, entry in ipairs((NS:GatheringBand("herbalism", 120))) do NS:GatheringRecord(entry.itemID, 1, 1413) end
		local done = part.Compute(NS, 1413)
		Check("[GTH] part complète : message de fin", done.have == 6 and done.need == 6 and done.hint[1]:find("Toutes", 1, true), done.hint[1])
	end

	-- 3.6 Sans métier, par personnage, interrupteur, robustesse -----------------------------------------
	do
		Say("-- récolte : sans métier, personnage, module, robustesse")
		G.Fresh({ HEADER, { "Couture", false, true, 50 } })
		G.Loot(785)
		local noProf = NS:GatheringData()[785] == nil and G.Find("gather:") == nil and G.Part().Compute(NS, 1413) == nil
		G.skills = {}
		Check("[GTH] sans métier (ou fenêtre vide) : ni butin, ni objectif, ni part", noProf
			and next(NS:GatheringProfessions()) == nil and G.Find("gather:") == nil)

		G.Fresh(HERB_120)
		G.Loot(785)
		G.char = "Autre"
		local other = NS:GatheringData()[785] == nil and G.Find("gather:herbalism:").progress == "0/6"
		G.Loot(2450)
		G.char = "Testeur"
		Check("[GTH] par personnage : l'autre vierge, le premier intact, rangé dans le carnet", other
			and NS:GatheringData()[785].count == 1 and NS:GatheringData()[2450] == nil
			and NS:JournalData().gathering == NS:GatheringData())

		NS:DB().companionEnabled = false
		G.Loot(2450)
		local off = NS:GatheringData()[2450] == nil and G.Find("gather:") == nil and G.Part().Compute(NS, 1413) == nil
		NS:DB().companionEnabled = true
		G.Loot(2450)
		local back = NS:GatheringData()[2450] ~= nil
		NS:DB().enabled = false
		Check("[GTH] module coupé : rien ; rallumé : compté ; addon coupé : rien", off and back and G.Find("gather:") == nil)
		NS:DB().enabled = true

		-- API en panne : jamais d'erreur
		local bad = {}
		_G.GetSkillLineInfo = function() error("panne") end
		local ok, found = pcall(NS.GatheringProfessions, NS)
		Expect(bad, "GetSkillLineInfo en panne", ok and next(found) == nil)
		_G.GetNumSkillLines = function() return "?" end
		ok, found = pcall(NS.GatheringProfessions, NS)
		Expect(bad, "GetNumSkillLines incohérent", ok and next(found) == nil)
		_G.GetNumSkillLines, _G.GetSkillLineInfo = nil, nil
		ok, found = pcall(NS.GatheringProfessions, NS)
		Expect(bad, "API absente", ok and next(found) == nil)
		local before = #(NS.errors or {})
		Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : " .. G.Link(785) .. ".")
		Mock:Fire("SKILL_LINES_CHANGED")
		Expect(bad, "événements", #(NS.errors or {}) == before)
		Expect(bad, "hors table", NS:GatheringRecord(2000, 1, 1413) == nil)
		Check("[GTH] API en panne, incohérente ou absente : pas de métier, aucune erreur ; hors table refusé", #bad == 0,
			table.concat(bad, ", "))
	end

	for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
	NS.ZONE_CREATURES, NS.ZONE_GATHERING = saved.ZONE_CREATURES, saved.ZONE_GATHERING
	NS.ZONE_QUESTS = saved.ZONE_QUESTS
	if NS.journalTracker then NS.journalTracker:Hide() end
	NS.journalTracker = nil
end
