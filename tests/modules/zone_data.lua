-- Carnet : créatures et récolte de chaque zone, préremplies (v1.25.0).
-- ZoneCreatures.lua / ZoneGathering.lua (générés par tools/gen_zone_data.py
-- depuis la base de Questie) : intégrité des tables, filtres (bestioles,
-- faction, PNJ de service), parts « bestiary » / « named » / « gathering »
-- calculées avec la table (préremplie + apprise), faction, espèce jamais vue
-- listée, kill d'une espèce prérenseignée, zone hors tables (dynamique).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

-- Mocks propres à ce fichier, restaurés à la fin
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

-- 1. Chargement et ordre du .toc ------------------------------------------------------
do
	Say("-- données de zone : chargement")
	Check("[ZDATA] ZoneCreatures.lua et ZoneGathering.lua chargés", NS.Loaded and NS.Loaded.ZoneCreatures
		and NS.Loaded.ZoneGathering)
	local order = {}
	for index, file in ipairs(_G.TOC_FILES or {}) do order[file] = index end
	Check("[ZDATA] .toc : tables avant Bestiary.lua", order["ZoneCreatures.lua"] and order["ZoneGathering.lua"]
		and order["Bestiary.lua"] and order["ZoneCreatures.lua"] < order["Bestiary.lua"]
		and order["ZoneGathering.lua"] < order["Bestiary.lua"] and order["ZoneGathering.lua"] < order["Gathering.lua"])
	Check("[ZDATA] tables présentes", type(NS.ZONE_CREATURES) == "table" and type(NS.ZONE_GATHERING) == "table")
end

-- 2. Intégrité des tables ---------------------------------------------------------------
do
	Say("-- données de zone : intégrité")
	-- zones connues : celles du coffre (ZONE_LEVELS) + Reflet-de-Lune (1450)
	local known = { [1450] = true }
	for zoneID in pairs(NS.ZONE_LEVELS or {}) do known[zoneID] = true end
	local zones, lines, bad, badZones = 0, 0, {}, {}
	for zoneID, list in pairs(NS.ZONE_CREATURES) do
		zones = zones + 1
		if not known[zoneID] then badZones[#badZones + 1] = tostring(zoneID) end
		for npcID, e in pairs(list) do
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
	Check("[ZDATA] créatures : 40 zones, des milliers de lignes", zones == 40 and lines > 2000, zones .. "/" .. lines)
	Check("[ZDATA] créatures : aucune zone inconnue", #badZones == 0, table.concat(badZones, ","))
	Check("[ZDATA] créatures : ids numériques, niveaux min <= max, rang 0-4, noms fr+en, faction A/H/nil",
		#bad == 0, table.concat(bad, ","))
	for zoneID in pairs(NS.ZONE_LEVELS or {}) do
		-- (d'autres tests ajoutent des zones fictives 9000+ à ZONE_LEVELS)
		if zoneID < 9000 and not NS.ZONE_CREATURES[zoneID] then badZones[#badZones + 1] = "absente:" .. zoneID end
	end
	Check("[ZDATA] créatures : chaque zone du coffre a sa table", #badZones == 0, table.concat(badZones, ","))

	local gZones, pairsCount, unknown = 0, 0, {}
	for zoneID, set in pairs(NS.ZONE_GATHERING) do
		gZones = gZones + 1
		if not known[zoneID] then unknown[#unknown + 1] = "zone:" .. zoneID end
		for itemID, flag in pairs(set) do
			pairsCount = pairsCount + 1
			local item = NS.GATHERING_ITEMS[itemID]
			if flag ~= true or not item or item.prof == "skinning" then unknown[#unknown + 1] = tostring(itemID) end
		end
	end
	Check("[ZDATA] récolte : zones et ressources", gZones >= 35 and pairsCount > 300, gZones .. "/" .. pairsCount)
	Check("[ZDATA] récolte : itemID tous connus de GatheringData (herbes, minerais), zones connues",
		#unknown == 0, table.concat(unknown, ","))
end

-- 3. Contenu : quelques espèces et nœuds réels ------------------------------------------
do
	Say("-- données de zone : contenu")
	local durotar, elwynn = NS.ZONE_CREATURES[1411], NS.ZONE_CREATURES[1429]
	local boar = durotar and durotar[3098]
	Check("[ZDATA] Durotar : Sanglier tacheté (3098), niveaux 1-2", boar and boar.en == "Mottled Boar"
		and boar.fr == "Sanglier tacheté" and boar.lvl[1] == 1 and boar.lvl[2] == 2 and boar.rank == 0 and boar.f == nil)
	Check("[ZDATA] Elwynn : Vermine kobold (6)", elwynn and elwynn[6] and elwynn[6].en == "Kobold Vermin")
	Check("[ZDATA] Elwynn : Lardeur élite (448), rares (rang 4)", elwynn[448] and elwynn[448].rank == 1
		and elwynn[61] and elwynn[61].rank == 4)
	-- bestioles et PNJ de service exclus
	Check("[ZDATA] bestioles exclues (vipère 3300, lièvre 5951, lapin 721)", durotar[3300] == nil and durotar[5951] == nil
		and elwynn[721] == nil)
	Check("[ZDATA] PNJ de service exclus (grunt d'Orgrimmar 3296, garde de Hurlevent 68)", durotar[3296] == nil
		and elwynn[68] == nil)
	Check("[ZDATA] faction : marine de Kul Tiras (A), grunt Kor'ja (H)", durotar[3129] and durotar[3129].f == "A"
		and durotar[12430] and durotar[12430].f == "H")
	local herbs = NS.ZONE_GATHERING[1411]
	Check("[ZDATA] Durotar : Pacifique, Terrestrine, Feuillargent, filon de cuivre", herbs and herbs[2447] and herbs[2449]
		and herbs[765] and herbs[2770] and herbs[2835])
	Check("[ZDATA] Durotar : pas de minerai de fer ni de lotus noir", herbs[2772] == nil and herbs[13468] == nil)
	Check("[ZDATA] Berceau-de-l'Hiver : thorium, calot de glace", NS.ZONE_GATHERING[1452][10620]
		and NS.ZONE_GATHERING[1452][13467])
end

-- 4. Parts calculées avec la table, filtrées par la faction -----------------------------
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
	local species = NS:BestiarySpecies(1411)
	Check("[ZDATA] Horde : pas d'espèce amicale envers la Horde (grunt Kor'ja)", species[12430] == nil and species[3129] ~= nil)
	Z.faction = "Alliance"
	species = NS:BestiarySpecies(1411)
	Check("[ZDATA] Alliance : le grunt compte, plus la marine de Kul Tiras", species[12430] ~= nil and species[3129] == nil
		and Z.Part("bestiary").need == Z.Expected(1411, "A"))
	Z.faction = nil
	species = NS:BestiarySpecies(1411)
	Check("[ZDATA] faction inconnue : seulement les espèces hostiles aux deux", species[12430] == nil and species[3129] == nil
		and species[3098] ~= nil)
	Z.faction = "Horde"
	Check("[ZDATA] espèce de la table : nom fr, classification du rang", NS:BestiarySpecies(1411)[3098].name == "Sanglier tacheté"
		and NS:BestiarySpecies(1411)[5808].class == "rare")
	Z.locale = "enUS"
	Check("[ZDATA] client anglais : nom en", NS:BestiarySpecies(1411)[3098].name == "Mottled Boar")
	Z.locale = "frFR"
	-- apprise hors table : s'ajoute (union)
	Z.W.units.target = { guid = Z.Guid(99001), name = "Bête inconnue", type = "Bête", level = 5, class = "normal" }
	Mock:Fire("PLAYER_TARGET_CHANGED")
	part = Z.Part("bestiary")
	Check("[ZDATA] espèce vue hors table : ajoutée au total", part.need == horde + 1, part.need)
	-- vue ET dans la table : pas comptée deux fois
	Z.W.units.target = { guid = Z.Guid(3098), name = "Sanglier tacheté", type = "Bête", level = 2, class = "normal" }
	Mock:Fire("PLAYER_TARGET_CHANGED")
	Check("[ZDATA] espèce de la table vue : pas de doublon", Z.Part("bestiary").need == horde + 1
		and NS:BestiarySpecies(1411)[3098].seen == true)
end

-- 5. Abattre une espèce prérenseignée jamais vue ----------------------------------------
do
	Say("-- données de zone : abattu sans avoir été vu")
	Z.Reset("Horde")
	local guid = Z.Guid(3099, "00000000AA")
	Z.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, guid)
	Z.Log("UNIT_DIED", nil, 0, guid)
	local learned = NS:BestiaryZone(1411)
	Check("[ZDATA] kill d'une espèce de la table jamais vue : comptée", learned and learned[3099] and learned[3099].killed == 1
		and learned[3099].name == "Sanglier tacheté redoutable", learned and learned[3099] and learned[3099].name)
	Check("[ZDATA] part : 1 espèce abattue", Z.Part("bestiary").have == 1)
	-- touché PAR le mob (il t'attaque le premier) : engagé aussi
	local guid2 = Z.Guid(3100, "00000000AB")
	Z.Log("SWING_DAMAGE", guid2, 0xa48, PLAYER_GUID, 0x511)
	Z.Log("UNIT_DIED", nil, 0, guid2)
	Check("[ZDATA] mob qui t'attaque le premier puis meurt : compté", NS:BestiaryZone(1411)[3100].killed == 1)
	-- l'engagement reste requis
	Z.Log("UNIT_DIED", nil, 0, Z.Guid(3101, "00000000AC"))
	Check("[ZDATA] mort sans engagement : rien", NS:BestiaryZone(1411)[3101] == nil)
	Z.Log("SWING_DAMAGE", "Player-1-0000FFFF", 0x548, Z.Guid(3102, "00000000AD"))
	Z.Log("UNIT_DIED", nil, 0, Z.Guid(3102, "00000000AD"))
	Check("[ZDATA] tué par un inconnu : rien", NS:BestiaryZone(1411)[3102] == nil)
	-- espèce hors table jamais vue : pas devinée
	Z.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, Z.Guid(99002, "00000000AE"))
	Z.Log("UNIT_DIED", nil, 0, Z.Guid(99002, "00000000AE"))
	Check("[ZDATA] espèce hors table jamais vue : pas retenue", NS:BestiaryZone(1411)[99002] == nil)
	-- tuée d'un coup (PARTY_KILL sans coup préalable)
	Z.Log("PARTY_KILL", PLAYER_GUID, 0x511, Z.Guid(3105, "00000000AF"))
	Check("[ZDATA] PARTY_KILL direct : compté", NS:BestiaryZone(1411)[3105] and NS:BestiaryZone(1411)[3105].killed == 1)
	-- nommé de la table
	Z.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, Z.Guid(5808, "00000000B0"))
	Z.Log("UNIT_DIED", nil, 0, Z.Guid(5808, "00000000B0"))
	Check("[ZDATA] nommé de la table abattu : part nommés 1/N", Z.Part("named").have == 1
		and NS:BestiaryZone(1411)[5808].class == "rare")
	-- module coupé : rien n'est adopté
	NS:DB().companionEnabled = false
	Z.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, Z.Guid(3106, "00000000B1"))
	Z.Log("UNIT_DIED", nil, 0, Z.Guid(3106, "00000000B1"))
	NS:DB().companionEnabled = nil
	Check("[ZDATA] module coupé : rien de compté", NS:BestiaryZone(1411)[3106] == nil)
end

-- 6. Fenêtre : espèces jamais vues listées -----------------------------------------------
do
	Say("-- données de zone : fenêtre")
	Z.Reset("Horde")
	Z.W.units.target = { guid = Z.Guid(3100), name = "Ancien sanglier tacheté", type = "Bête", level = 9, class = "normal" }
	Mock:Fire("PLAYER_TARGET_CHANGED")
	Z.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, Z.Guid(3099, "00000000C0"))
	Z.Log("UNIT_DIED", nil, 0, Z.Guid(3099, "00000000C0"))
	local rows, byName = Z.Rows(1411, "combat")
	local never = byName["Sanglier tacheté, Bête (niv. 1-2)"] or byName["Sanglier tacheté (niv. 1-2)"]
	Check("[ZDATA] fenêtre : espèce jamais vue listée, avec niveau, « à trouver »", never and never.detail == "à trouver"
		and not never.done, never and never.detail)
	local seen = byName["Ancien sanglier tacheté, Bête (niv. 8-9)"]
	Check("[ZDATA] fenêtre : vue « à abattre »", seen and seen.detail == "à abattre")
	local killed = byName["Sanglier tacheté redoutable (niv. 6-7)"]
	-- abattue : après toutes les espèces restantes du bestiaire
	local last
	for index = 2, #rows do
		if rows[index].header then break end
		last = rows[index]
	end
	Check("[ZDATA] fenêtre : abattue « abattu (1) », en fin de liste", killed and killed.detail == "abattu (1)" and killed.done
		and last == killed)
	local rare = byName["Seigneur de guerre Kolkanis, rare (niv. 9)"]
	Check("[ZDATA] fenêtre : nommé de la table avec son rang", rare and rare.named)
	Check("[ZDATA] fenêtre : en-tête du bestiaire en espèces de la table", rows[1].header
		and rows[1].name:find("Bestiaire : 1/" .. Z.Expected(1411, "H"), 1, true), rows[1].name)
end

-- 7. Zone hors tables : tout reste dynamique ---------------------------------------------
do
	Say("-- données de zone : zone hors tables")
	Z.Reset("Horde")
	Mock.world.mapID = 9200
	Check("[ZDATA] zone hors tables, rien vu : pas de part", Z.Part("bestiary") == nil and Z.Part("named") == nil)
	Z.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, Z.Guid(3098, "00000000D0"))
	Z.Log("UNIT_DIED", nil, 0, Z.Guid(3098, "00000000D0"))
	Check("[ZDATA] zone hors tables : un kill jamais vu n'est pas deviné", NS:BestiaryZone(9200) == nil)
	Z.W.units.target = { guid = Z.Guid(3098, "00000000D1"), name = "Sanglier", type = "Bête", level = 2, class = "normal" }
	Mock:Fire("PLAYER_TARGET_CHANGED")
	local part = Z.Part("bestiary")
	Check("[ZDATA] zone hors tables : appris en jouant (0/1)", part and part.have == 0 and part.need == 1)
end

-- 8. Récolte : ressources présentes dans la zone -----------------------------------------
do
	Say("-- données de zone : récolte")
	Z.Reset("Horde")
	local HEADER = { "Professions", true, true }
	Z.skills = { HEADER, { "Herboristerie", false, true, 60 }, { "Minage", false, true, 60 } }
	-- tranche à 60 : Pacifique, Feuillargent, Terrestrine, Mage royal + cuivre, pierre brute
	Mock.world.mapID = 1429
	local part = Z.Part("gathering")
	Check("[ZDATA] Elwynn : seulement ce qui y pousse (pas de Mage royal) -> 5", part and part.need == 5 and part.have == 0,
		part and part.need)
	Mock.world.mapID = 1411
	part = Z.Part("gathering")
	Check("[ZDATA] Durotar : Mage royal compris -> 6", part and part.need == 6, part and part.need)
	NS:GatheringRecord(2447, 1, 1411)
	part = Z.Part("gathering")
	Check("[ZDATA] Durotar : Pacifique récoltée ici -> 1/6", part.have == 1 and part.need == 6)
	local hint = table.concat(part.hint, " | ")
	Check("[ZDATA] survol : ressources de la zone, pas les autres", hint:find("(50)", 1, true) and hint:find("Durotar", 1, true), hint)
	Mock.world.mapID = 9200
	part = Z.Part("gathering")
	Check("[ZDATA] zone hors tables : toute la tranche -> 6", part and part.need == 6, part and part.need)
	-- rien de ta tranche dans la zone : la part ne s'applique pas
	Z.skills = { HEADER, { "Herboristerie", false, true, 290 } }
	Mock.world.mapID = 1429
	Check("[ZDATA] Elwynn à 290 en herboristerie : aucune part", Z.Part("gathering") == nil)
	-- dépeçage : jamais filtré (pas de données de zone)
	Z.skills = { HEADER, { "Dépeçage", false, true, 60 } }
	part = Z.Part("gathering")
	local band = NS:GatheringBand("skinning", 60)
	Check("[ZDATA] dépeçage : toute la tranche, même en zone préremplie", part and part.need == #band and #band > 0)
	-- fenêtre : même liste que la part
	Z.skills = { HEADER, { "Herboristerie", false, true, 60 } }
	local rows = Z.Rows(1429, "craft")
	Check("[ZDATA] fenêtre Métiers : en-tête + 3 herbes d'Elwynn", #rows == 4 and rows[1].header
		and rows[1].name:find("0/3", 1, true), #rows)
end

-- ipairs sur la liste : une globale absente avant (nil) doit le redevenir
for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
C_Map.GetAreaInfo = saved.GetAreaInfo
NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryRejected = {}, nil, {}
NS.journalRares = {}
if NS.journalTracker then NS.journalTracker:Hide() end
NS.journalTracker = nil
NS.journalFrame = nil
ResetWorld()
