-- Carnet de voyage : bestiaire de zone et nommés (Bestiary.lua, v1.25.0).
-- Vu / abattu, engagement (toi, familier, groupe), exclusions (joueur,
-- familier, bestiole, amical, mort, GUID inattendu), instance, journal de
-- combat fermé (moteur 12.0 : PARTY_KILL, UNIT_DIED, message d'XP), nommés,
-- parts de complétion, objectifs et survol, persistance par personnage,
-- interrupteur du module, robustesse.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- Mocks propres à ce fichier, restaurés à la fin
local saved, MOCKED = {}, { "IsInInstance", "GetInstanceInfo", "GetRealZoneText", "UnitClassification", "UnitGUID",
	"UnitIsPlayer", "UnitName", "UnitExists", "UnitIsDead", "UnitPlayerControlled", "UnitReaction", "UnitCanAttack",
	"UnitCreatureType", "UnitCreatureFamily", "UnitLevel", "CombatLogGetCurrentEventInfo", "InCombatLockdown",
	"UnitFactionGroup", "date" }
for _, name in ipairs(MOCKED) do saved[name] = rawget(_G, name) end
saved.GetAreaInfo = C_Map.GetAreaInfo
saved.NextUnlocks = rawget(NS, "CompanionNextUnlocks")
-- Ces tests couvrent le comportement 100 % dynamique (zone absente des tables
-- livrées, carte inconnue du client) : tables mises de côté, remises à la fin.
-- Les zones préremplies sont testées dans zone_data.lua.
saved.ZONE_CREATURES, saved.ZONE_GATHERING = rawget(NS, "ZONE_CREATURES"), rawget(NS, "ZONE_GATHERING")
saved.ZONE_QUESTS = rawget(NS, "ZONE_QUESTS")
NS.ZONE_CREATURES, NS.ZONE_GATHERING, NS.ZONE_QUESTS = nil, nil, nil

local B = { W = { units = {} } }
local PLAYER_GUID = "Player-1-00000001"
_G.IsInInstance = function() return B.W.instance == true, B.W.instance and "party" or "none" end
_G.GetInstanceInfo = function() return "Kalimdor", "none", 0, "", 0, 0, false, 0 end
_G.GetRealZoneText = function() return "" end
_G.InCombatLockdown = function() return false end
_G.UnitFactionGroup = function() return "Horde" end
_G.date = function() return "03/11/2026" end
_G.UnitGUID = function(unit)
	if unit == "player" then return PLAYER_GUID end
	local u = B.W.units[unit]; return u and u.guid
end
_G.UnitName = function(unit)
	-- "player" : la clé des données du personnage (persistance par personnage)
	if unit == "player" then return B.W.charName or "Testeur" end
	local u = B.W.units[unit]; return u and u.name
end
_G.UnitExists = function(unit) return B.W.units[unit] ~= nil end
_G.UnitIsPlayer = function(unit) local u = B.W.units[unit]; return u and u.player == true or false end
_G.UnitIsDead = function(unit) local u = B.W.units[unit]; return u and u.dead == true or false end
_G.UnitPlayerControlled = function(unit) local u = B.W.units[unit]; return u and u.controlled == true or false end
_G.UnitReaction = function(unit) local u = B.W.units[unit]; return u and (u.reaction or 2) end
_G.UnitCanAttack = function() return true end
_G.UnitClassification = function(unit) local u = B.W.units[unit]; return u and u.class or "normal" end
_G.UnitCreatureType = function(unit) local u = B.W.units[unit]; return u and u.type end
_G.UnitCreatureFamily = function(unit) local u = B.W.units[unit]; return u and u.family end
_G.UnitLevel = function(unit)
	if unit == nil or unit == "player" then return Mock.world.level or 20 end
	local u = B.W.units[unit]; return u and u.level
end
_G.CombatLogGetCurrentEventInfo = function() return unpack(B.W.cleu or {}) end
C_Map.GetAreaInfo = nil

local MAPS = {
	[947]  = { mapID = 947,  name = "Azeroth", parentMapID = 0, mapType = 1 },
	[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 },
	[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 },
	[1411] = { mapID = 1411, name = "Durotar", parentMapID = 1414, mapType = 3 },
	[9100] = { mapID = 9100, name = "Grotte des Tarides", parentMapID = 1413, mapType = 5 },
}

function B.Reset()
	ResetWorld()
	B.W = { units = {} }
	for id, info in pairs(MAPS) do Mock.world.maps[id] = info end
	Mock.world.mapID = 1413
	Mock.world.subzone = "Plaine"
	Mock.world.level = 20
	NS.bestiaryUnits, NS.bestiaryPrunedAt = {}, nil
	NS.journalRares, NS.journalToasts, NS.journalChats = {}, {}, {}
	NS.journalToastHideAt = nil
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	if NS.journalTracker then NS.journalTracker:Hide() end
	NS.journalTracker = nil
	NS.journalTrackerCombat = nil
	NS.journalGroups, NS.journalGroupsFor = nil, nil
	NS.CompanionNextUnlocks = nil
end
-- un GUID de créature au format du client
function B.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
-- une créature sous `unit` (par défaut la cible), puis l'événement qui la fait voir
function B.See(unit, fields, event)
	B.W.units[unit] = fields
	if event == "mouseover" then Mock:Fire("UPDATE_MOUSEOVER_UNIT")
	elseif event == "nameplate" then Mock:Fire("NAME_PLATE_UNIT_ADDED", unit)
	else Mock:Fire("PLAYER_TARGET_CHANGED") end
end
function B.Target(npcID, name, extra, spawn)
	local fields = { guid = B.Guid(npcID, spawn), name = name, type = "Bête", level = 15, class = "normal" }
	for k, v in pairs(extra or {}) do fields[k] = v end
	B.See("target", fields)
	return fields.guid
end
function B.Log(subevent, sourceGUID, sourceFlags, destGUID, destFlags)
	B.W.cleu = { 1000, subevent, false, sourceGUID, "src", sourceFlags, 0, destGUID, "dst", destFlags or 0x10a48, 0 }
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
end
-- engagé par toi puis mort
function B.Kill(guid)
	B.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, guid)
	B.Log("UNIT_DIED", nil, 0, guid)
end
function B.Species(zoneID, npcID)
	local zone = NS:BestiaryData()[zoneID]
	return zone and zone[npcID]
end
function B.Part(id)
	for _, def in ipairs(NS.ZONE_PARTS or {}) do if def.id == id then return def end end
end
function B.Goal(id)
	for _, goal in ipairs(NS:JournalObjectives()) do if goal.id == id then return goal end end
end

local function Expect(bad, label, ok) if not ok then bad[#bad + 1] = label end end

-- 1. Chargement et chaînes ------------------------------------------------------------
do
	Say("-- bestiaire : chargement et chaînes")
	local order = {}
	for index, file in ipairs(_G.TOC_FILES or {}) do order[(file:gsub("^[^/]+/", ""))] = index end
	Check("[BST] Bestiary.lua chargé, après JournalTracker.lua", NS.Loaded and NS.Loaded.Bestiary and order["Bestiary.lua"]
		and order["JournalTracker.lua"] and order["Bestiary.lua"] > order["JournalTracker.lua"])
	local strings, gaps = NS.BESTIARY_STRINGS, {}
	local function Placeholders(text)
		local list = {}
		for p in tostring(text):gsub("%%%%", ""):gmatch("%%[%d%$]*[sd]") do list[#list + 1] = p end
		return table.concat(list, ",")
	end
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" then gaps[#gaps + 1] = "en:" .. key end
		if value == "" or NS.L[key] ~= value then gaps[#gaps + 1] = "fr:" .. key end
		if Placeholders(value) ~= Placeholders(strings.en[key]) then gaps[#gaps + 1] = "%:" .. key end
		if value:find("[Vv]ous") then gaps[#gaps + 1] = "vous:" .. key end
	end
	for key in pairs(strings.en) do if strings.fr[key] == nil then gaps[#gaps + 1] = "fr?" .. key end end
	Check("[BST] chaînes fr/en : mêmes clés, mêmes paramètres, tutoiement", #gaps == 0, table.concat(gaps, ", "))
	Check("[BST] deux parts de complétion déclarées et nommées", B.Part("bestiary") and B.Part("named")
		and B.Part("bestiary").label == "JRN_PART_bestiary" and B.Part("named").label == "JRN_PART_named"
		and strings.fr.JRN_PART_bestiary and strings.en.JRN_PART_named)
	local bad = {}
	Expect(bad, "créature", NS.BestiaryNpcID("Creature-0-4378-1-12-3100-00001A2B3C") == 3100)
	Expect(bad, "véhicule", NS.BestiaryNpcID("Vehicle-0-4378-1-12-3101-00001A2B3C") == 3101)
	for _, guid in ipairs({ PLAYER_GUID, "Pet-0-4378-1-12-416-0100ABCDEF", "Creature-0-4378-1-12-abc-00001A2B3C",
		"Creature-0-4378", "Creature-0-4378-1-12-0-00001A2B3C", 42 }) do
		Expect(bad, tostring(guid), NS.BestiaryNpcID(guid) == nil)
	end
	Expect(bad, "nil", NS.BestiaryNpcID(nil) == nil)
	Check("[BST] numéro de PNJ : créature et véhicule ; joueur, familier, formats inattendus -> nil", #bad == 0,
		table.concat(bad, ", "))
end

-- 2. Vu -------------------------------------------------------------------------------
do
	Say("-- bestiaire : vu")
	B.Reset()
	B.Target(3100, "Sanglier des Tarides", { family = "Sanglier", level = 14 })
	local s = B.Species(1413, 3100)
	Check("[BST] cible : espèce retenue dans la zone, rangée dans le carnet du personnage", s and s.seen == true
		and s.killed == 0 and s.name == "Sanglier des Tarides" and s.type == "Bête" and s.family == "Sanglier"
		and s.class == "normal" and s.level == 14 and NS:CharData().journal.bestiary[1413][3100] == s)
	B.See("mouseover", { guid = B.Guid(3101), name = "Kodo des plaines", type = "Bête", level = 13 }, "mouseover")
	B.See("nameplate2", { guid = B.Guid(3102), name = "Centaure kolkar", type = "Humanoïde", level = 15 }, "nameplate")
	Check("[BST] survol et plaque de nom : espèce retenue", B.Species(1413, 3101) ~= nil and B.Species(1413, 3102)
		and B.Species(1413, 3102).type == "Humanoïde")
	B.Target(3100, "Sanglier des Tarides", nil, "000099999")
	local counts = NS:BestiaryCounts(1413)
	Check("[BST] même espèce, autre apparition : une seule espèce", counts.seen == 3 and counts.killed == 0, counts.seen)
	-- une sous-carte (grotte) remonte à sa zone
	Mock.world.mapID = 9100
	B.Target(3110, "Harpie")
	Mock.world.mapID = 1413
	-- type inconnu : l'espèce entre quand même, sans type
	B.Target(3111, "Chose étrange", { type = false })
	Check("[BST] grotte : rangée dans sa zone ; type inconnu : retenue sans type", B.Species(1413, 3110) ~= nil
		and NS:BestiaryData()[9100] == nil and B.Species(1413, 3111) and B.Species(1413, 3111).type == nil)
end

-- 3. Exclusions -----------------------------------------------------------------------
do
	Say("-- bestiaire : exclusions")
	B.Reset()
	local bad = {}
	local function Excluded(label, ...)
		for _, fields in ipairs({ ... }) do B.See("target", fields) end
		Expect(bad, label, NS:BestiaryZone(1413) == nil)
	end
	Excluded("joueur", { guid = "Player-1-00000077", name = "Un joueur", player = true, type = "Humanoïde" },
		{ guid = B.Guid(4000), name = "Joueur déguisé", player = true })
	Excluded("familier ou gardien", { guid = "Pet-0-4378-1-12-416-0100ABCDEF", name = "Familier", type = "Démon" },
		{ guid = B.Guid(416), name = "Gardien", controlled = true, type = "Élémentaire" })
	Excluded("bestiole fr/en", { guid = B.Guid(4001), name = "Lièvre", type = "Bestiole", reaction = 4 },
		{ guid = B.Guid(4002), name = "Rat", type = "Critter" })
	Excluded("amical", { guid = B.Guid(4003), name = "Garde", type = "Humanoïde", reaction = 5 })
	Excluded("déjà mort", { guid = B.Guid(4004), name = "Cadavre", type = "Bête", dead = true })
	Excluded("GUID absent ou inattendu", { guid = "Creature-bizarre", name = "Bug", type = "Bête" },
		{ guid = nil, name = "Sans GUID", type = "Bête" }, { guid = "GameObject-0-4378-1-12-5000-00001A2B3C", name = "Coffre" })
	Check("[BST] exclus : joueur, familier ou gardien, bestiole (fr et en), PNJ amical, déjà mort, GUID inattendu",
		#bad == 0, table.concat(bad, ", "))
	B.See("target", { guid = B.Guid(4005), name = "Marchand neutre", type = "Humanoïde", reaction = 4 })
	Check("[BST] PNJ neutre : retenu", B.Species(1413, 4005) ~= nil)
	-- sans UnitReaction : UnitCanAttack décide
	_G.UnitReaction = nil
	_G.UnitCanAttack = function() return false end
	B.See("target", { guid = B.Guid(4006), name = "Inattaquable", type = "Bête" })
	_G.UnitCanAttack = function() return true end
	B.See("target", { guid = B.Guid(4007), name = "Attaquable", type = "Bête" })
	Check("[BST] sans UnitReaction : UnitCanAttack fait foi", B.Species(1413, 4006) == nil and B.Species(1413, 4007) ~= nil)
	_G.UnitReaction = function(unit) local u = B.W.units[unit]; return u and (u.reaction or 2) end

	-- instance : jamais au bestiaire de zone
	B.Reset()
	B.W.instance = true
	B.Kill(B.Target(5000, "Rat des profondeurs", { type = "Bête" }))
	Check("[BST] instance : rien de retenu", next(NS:BestiaryData()) == nil and next(NS.bestiaryUnits) == nil)
end

-- 4. Abattu et engagement -------------------------------------------------------------
do
	Say("-- bestiaire : abattu")
	B.Reset()
	local boar = B.Target(3100, "Sanglier des Tarides")
	B.Kill(boar)
	local first = B.Species(1413, 3100).killed == 1 and NS.bestiaryUnits[boar] == nil
	B.Kill(B.Target(3100, "Sanglier des Tarides", nil, "0000BEEF"))
	Check("[BST] engagé par toi puis mort : abattu, mémoire vidée ; retué : compteur, toujours une espèce", first
		and B.Species(1413, 3100).killed == 2 and NS:BestiaryCounts(1413).killed == 1)

	local stolen = B.Target(3200, "Zhévra")
	B.Log("SWING_DAMAGE", "Player-1-00000099", 0x548, stolen)
	B.Log("UNIT_DIED", nil, 0, stolen)
	Check("[BST] tué par un inconnu : pas compté, mémoire vidée quand même", B.Species(1413, 3200).killed == 0
		and NS.bestiaryUnits[stolen] == nil)

	local bad = {}
	local hitter = B.Target(3201, "Raptor")
	B.Log("SWING_DAMAGE", hitter, 0xa48, PLAYER_GUID, 0x511)
	B.Log("UNIT_DIED", nil, 0, hitter)
	Expect(bad, "t'a frappé", B.Species(1413, 3201).killed == 1)
	local petKill = B.Target(3202, "Grue")
	B.Log("SPELL_DAMAGE", "Pet-0-4378-1-12-416-0100ABCDEF", 0x1111, petKill)
	B.Log("UNIT_DIED", nil, 0, petKill)
	Expect(bad, "familier", B.Species(1413, 3202).killed == 1)
	local party = B.Target(3203, "Hyène")
	B.Log("RANGE_MISSED", "Player-1-00000042", 0x512, party)
	B.Log("PARTY_KILL", "Player-1-00000042", 0x512, party)
	B.Log("UNIT_DIED", nil, 0, party)
	Expect(bad, "groupe une fois", B.Species(1413, 3203).killed == 1)
	Check("[BST] engagé aussi : t'a frappé, ton familier, ton groupe (PARTY_KILL puis UNIT_DIED compté une fois)", #bad == 0,
		table.concat(bad, ", "))

	-- jamais vu : le journal de combat seul ne suffit pas
	B.Kill(B.Guid(3999))
	Check("[BST] mob jamais repéré : rien", B.Species(1413, 3999) == nil)
	-- vu aux Tarides, tué après être passé à Durotar : compte pour les Tarides
	local runner = B.Target(3204, "Coureur")
	Mock.world.mapID = 1411
	B.Kill(runner)
	Check("[BST] l'espèce compte dans la zone où tu l'as vue", B.Species(1413, 3204).killed == 1
		and NS:BestiaryZone(1411) == nil)
	Mock.world.mapID = 1413
	-- mémoire : un mob vu sans combat est oublié après 15 min
	B.Target(3205, "Oublié")
	Mock.now = Mock.now + 2000
	B.Target(3206, "Récent")
	Check("[BST] mémoire : vieux mob non engagé oublié", NS.bestiaryUnits[B.Guid(3205)] == nil
		and NS.bestiaryUnits[B.Guid(3206)] ~= nil)
	-- tampon « rare » du carnet : intact, à côté du bestiaire
	B.Kill(B.Target(5800, "Sabot-Sinistre", { class = "rare" }))
	Check("[BST] rare : tampon du carnet gagné, compté aussi au bestiaire", NS:HasStamp("rare:5800")
		and B.Species(1413, 5800).killed == 1)
end

-- 4 bis. Journal de combat fermé (moteur 12.0, WoW Forever) ---------------------------
do
	Say("-- bestiaire : journal de combat fermé (PARTY_KILL, UNIT_DIED, message d'XP)")
	-- sonde et abonnement
	local savedLog, savedCL = rawget(_G, "CombatLogGetCurrentEventInfo"), rawget(_G, "C_CombatLog")
	local bad = {}
	_G.C_CombatLog = { IsCombatLogRestricted = function() return true end }
	Expect(bad, "dit fermé", NS.CombatLogRestricted() == true)
	_G.C_CombatLog = { IsCombatLogRestricted = function() return false end }
	Expect(bad, "dit ouvert", NS.CombatLogRestricted() == false)
	_G.C_CombatLog = { IsCombatLogRestricted = function() error("refusé") end }
	Expect(bad, "en erreur", NS.CombatLogRestricted() == false)
	_G.C_CombatLog = nil
	_G.CombatLogGetCurrentEventInfo = nil
	Expect(bad, "sans API", NS.CombatLogRestricted() == true)
	Check("[CL] sonde : C_CombatLog fait foi, en erreur d'après CombatLogGetCurrentEventInfo, sans lui : fermé", #bad == 0,
		table.concat(bad, ", "))
	local function Frame(refuse)
		local f = { got = {} }
		function f:RegisterEvent(event)
			if refuse and event == refuse then error("forbidden") end
			self.got[event] = true
		end
		return f
	end
	local H = { COMBAT_LOG_EVENT_UNFILTERED = true, PARTY_KILL = true, UNIT_DIED = true, PLAYER_TARGET_CHANGED = true }
	bad = {}
	local closed = Frame()
	Expect(bad, "fermé", NS.RegisterHandlers(closed, H) == false and not closed.got.COMBAT_LOG_EVENT_UNFILTERED
		and closed.got.PARTY_KILL and closed.got.UNIT_DIED and closed.got.PLAYER_TARGET_CHANGED)
	_G.CombatLogGetCurrentEventInfo = savedLog
	local open = Frame()
	Expect(bad, "ouvert", NS.RegisterHandlers(open, H) == true and open.got.COMBAT_LOG_EVENT_UNFILTERED
		and not open.got.PARTY_KILL and not open.got.UNIT_DIED)
	local refused = Frame("COMBAT_LOG_EVENT_UNFILTERED")
	Expect(bad, "refusé", NS.RegisterHandlers(refused, H) == false and refused.got.PARTY_KILL and refused.got.UNIT_DIED)
	Check("[CL] abonnement : fermé ou refusé -> PARTY_KILL et UNIT_DIED ; ouvert -> le journal seul (une mort compte une fois)",
		#bad == 0, table.concat(bad, ", "))
	_G.C_CombatLog = savedCL
	-- affiliation d'après le GUID
	B.W.units.party1 = { guid = "Player-1-00000002" }
	Check("[CL] GroupFlags : toi, ton groupe, un inconnu", NS.GroupFlags(PLAYER_GUID) == 1
		and NS.GroupFlags("Player-1-00000002") == 2 and NS.GroupFlags("Player-1-00000099") == nil and NS.GroupFlags(nil) == nil)

	-- les événements autonomes, tels que le client les envoie
	local OnEvent = NS.bestiaryEventFrame.scripts.OnEvent
	B.Reset()
	local wolf = B.Target(3301, "Loup")
	OnEvent(NS.bestiaryEventFrame, "PARTY_KILL", PLAYER_GUID, wolf)
	local boar = B.Target(3302, "Sanglier")
	OnEvent(NS.bestiaryEventFrame, "PARTY_KILL", "Player-1-00000099", boar)
	local stranger = (B.Species(1413, 3302).killed or 0) == 0
	B.W.units.party1 = { guid = "Player-1-00000002" }
	OnEvent(NS.bestiaryEventFrame, "PARTY_KILL", "Player-1-00000002", boar)
	Check("[CL] PARTY_KILL : de toi ou de ton groupe abattu, d'un inconnu pas pour toi", B.Species(1413, 3301).killed == 1
		and stranger and B.Species(1413, 3302).killed == 1)
	Check("[CL] UNIT_DIED vide : pas d'erreur", pcall(OnEvent, NS.bestiaryEventFrame, "UNIT_DIED", nil))

	-- message d'XP seul : rare tamponné, brillante abattue ; puis PARTY_KILL : rien de plus
	B.Reset()
	local rare = B.Target(5801, "Croc-Gris", { class = "rare" })
	NS:ShinyState().live[rare] = { zoneID = 1413, npcID = 5801, name = "Croc-Gris" }
	local before = NS:ShinyData().count
	B.W.units.target.dead = true
	Mock:Fire("CHAT_MSG_COMBAT_XP_GAIN", "Croc-Gris meurt, vous gagnez 120 points d'expérience.")
	Check("[CL] message d'XP : rare compté au bestiaire, tampon « rare », brillante abattue", B.Species(1413, 5801).killed == 1
		and NS:HasStamp("rare:5801") and NS:ShinyData().count == before + 1 and NS:ShinyState().live[rare] == nil)
	OnEvent(NS.bestiaryEventFrame, "PARTY_KILL", PLAYER_GUID, rare)
	Check("[CL] XP puis PARTY_KILL : compté une seule fois", B.Species(1413, 5801).killed == 1
		and NS:ShinyData().count == before + 1)
end

-- 5. Nommés, parts de complétion ------------------------------------------------------
do
	Say("-- bestiaire : nommés et complétion")
	B.Reset()
	local bestiary, named = B.Part("bestiary"), B.Part("named")
	local nothing = bestiary.Compute(NS, 1413) == nil and named.Compute(NS, 1413) == nil
	B.Target(3100, "Sanglier")
	Check("[BST] parts : rien vu -> nil ; aucun nommé vu -> pas de part nommés", nothing and named.Compute(NS, 1413) == nil)
	local elite = B.Target(3300, "Chef kolkar", { class = "elite", type = "Humanoïde" })
	B.Target(3301, "Sabot-Sinistre", { class = "rare" })
	B.Target(3302, "Gardien ancien", { class = "rareelite", type = "Élémentaire" })
	B.Target(3303, "Dragon du rêve", { class = "worldboss", type = "Dragon" })
	B.Target(3304, "Larbin", { class = "minus" })
	Check("[BST] élite, rare, rare élite, boss : nommés ; normal, minus : non",
		NS:BestiaryCounts(1413).namedSeen == 4 and NS:BestiaryCounts(1413).seen == 6, NS:BestiaryCounts(1413).namedSeen)
	B.Kill(elite)
	local part, npart = bestiary.Compute(NS, 1413), named.Compute(NS, 1413)
	Check("[BST] parts : abattues / vues (nommés compris) 1/6, nommés 1/4, autre zone nil", part.have == 1 and part.need == 6
		and npart.have == 1 and npart.need == 4 and bestiary.Compute(NS, 1411) == nil, part.have .. "/" .. part.need)
	local text = table.concat(npart.hint, " | ")
	Check("[BST] survol nommés : titre et noms restants, avec type", npart.hint[1] == NS.L.BST_HINT_NAMED
		and text:find("Gardien ancien (Élémentaire)", 1, true) and not text:find("Chef kolkar", 1, true)
		and not text:find("Sanglier", 1, true), text)
	Check("[BST] lignes de compte (rien vu : vide)", table.concat(NS:BestiaryCounterLines(1413), " | ")
		== "Bestiaire : 1 / 6 espèces abattues | Nommés : 1 / 4 abattus" and #NS:BestiaryCounterLines(1411) == 0,
		table.concat(NS:BestiaryCounterLines(1413), " | "))
	-- plus de 6 espèces à abattre : 6 noms triés puis « … et N autres »
	for index = 1, 4 do B.Target(3400 + index, "Bête " .. index) end
	part = bestiary.Compute(NS, 1413)
	Check("[BST] survol : 6 noms triés au plus (type entre parenthèses) puis « … et N autres »", #part.hint == 8
		and part.hint[1] == "Encore à abattre :" and part.hint[2] == "  · Bête 1 (Bête)"
		and part.hint[8] == NS:F("JRN_HINT_MORE", 3), table.concat(part.hint, " | "))
end

-- 6. Objectifs et survol --------------------------------------------------------------
do
	Say("-- bestiaire : objectifs")
	B.Reset()
	Check("[BST] rien vu : aucun objectif", B.Goal("bestiary:1413") == nil and B.Goal("named:1413") == nil)
	local a = B.Target(3100, "Sanglier")
	B.Target(3101, "Kodo")
	local goal = B.Goal("bestiary:1413")
	Check("[BST] objectif « Bestiaire de Les Tarides » 0/2 espèces, pas d'objectif nommés sans nommé", goal
		and goal.label == "Bestiaire de Les Tarides" and goal.have == 0 and goal.need == 2 and goal.unit == "espèces"
		and goal.source == "bestiary" and B.Goal("named:1413") == nil, goal and goal.label)
	B.Target(3300, "Chef kolkar", { class = "elite" })
	local ngoal = B.Goal("named:1413")
	Check("[BST] objectif « Nommés de Les Tarides »", ngoal and ngoal.label == "Nommés de Les Tarides" and ngoal.need == 1
		and ngoal.unit == "espèces")
	B.Kill(a)
	local progress = B.Goal("bestiary:1413").have == 1 and B.Goal("bestiary:1413").need == 3
	-- pas un compte de victimes : retuer la même espèce ne fait pas avancer
	B.Kill(B.Target(3100, "Sanglier", nil, "0000C0FFEE"))
	Check("[BST] objectif en espèces abattues (retuer la même : pas de progrès)", progress and B.Goal("bestiary:1413").have == 1)
	local tip = _G.GameTooltip
	NS:ShowJournalGoalTooltip(UIParent, B.Goal("bestiary:1413"))
	local text = table.concat(tip.lines or {}, " | ")
	Check("[BST] survol : progression en espèces et noms à abattre", text:find("1/3 espèces", 1, true)
		and text:find("Encore à abattre", 1, true) and text:find("Kodo (Bête)", 1, true)
		and not text:find("Sanglier", 1, true), text)
	tip:Hide()
	-- zone courante seulement, jamais en instance
	Mock.world.mapID = 1411
	local away = B.Goal("bestiary:1413") == nil
	B.Target(3500, "Scorpide")
	local durotar = B.Goal("bestiary:1411") and B.Goal("bestiary:1411").label == "Bestiaire de Durotar"
	B.W.instance = true
	Check("[BST] objectif de la zone courante seulement (Durotar le sien), aucun en instance", away and durotar
		and B.Goal("bestiary:1411") == nil)
	B.W.instance = false
	Mock.world.mapID = 1413
	B.Kill(B.Target(3101, "Kodo"))
	B.Kill(B.Target(3300, "Chef kolkar", { class = "elite" }))
	Check("[BST] tout abattu : objectifs disparus, part complète", B.Goal("bestiary:1413") == nil
		and B.Goal("named:1413") == nil and B.Part("bestiary").Compute(NS, 1413).have == 3
		and #B.Part("bestiary").Compute(NS, 1413).hint == 0)
	-- nouvelle espèce : le suivi se rafraîchit (le bestiaire seul, ou dans la complétion de zone)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	B.Target(3600, "Nouvelle bête")
	local tracker, found, shownText = NS.journalTracker, false, {}
	for _, line in ipairs(tracker and tracker.lines or {}) do
		if line:IsShown() and line.goal then
			shownText[#shownText + 1] = line.goal.id
			if line.goal.id == "bestiary:1413" then found = true end
			if line.goal.id == "zone:1413" and table.concat(line.goal.hint, " "):find("Bestiaire : 3/4", 1, true) then found = true end
		end
	end
	Check("[BST] nouvelle espèce : dans le suivi (seule ou dans la complétion de zone)", found, table.concat(shownText, ","))
end

-- 7. Persistance par personnage, interrupteur du module, robustesse -------------------
do
	Say("-- bestiaire : personnage, module, robustesse")
	B.Reset()
	B.Kill(B.Target(3100, "Sanglier"))
	B.W.charName = "Autre"
	local blank = NS:BestiaryZone(1413) == nil
	B.Target(3101, "Kodo")
	B.W.charName = nil
	Check("[BST] par personnage : l'autre vierge, le premier garde ses espèces, pas celles de l'autre", blank
		and B.Species(1413, 3100) and B.Species(1413, 3100).killed == 1 and B.Species(1413, 3101) == nil)
	-- interrupteur du Compagnon (et du carnet)
	local engaged = B.Target(3102, "Centaure")
	B.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, engaged)
	NS:DB().companionEnabled = false
	B.Target(3103, "Pas retenu")
	B.Log("UNIT_DIED", nil, 0, engaged)
	Check("[BST] module coupé : rien de vu ni d'abattu, ce qui est appris reste lisible", B.Species(1413, 3103) == nil
		and B.Species(1413, 3102).killed == 0 and NS:BestiaryCounts(1413).seen == 2)
	NS:DB().companionEnabled = nil
	NS:DB().enabled = false
	B.Target(3104, "Pas retenu non plus")
	Check("[BST] addon coupé : rien de vu", B.Species(1413, 3104) == nil)
	NS:DB().enabled = nil

	-- robustesse : API en panne ou absentes
	local bad = {}
	_G.CombatLogGetCurrentEventInfo = function() error("boom") end
	local guid = B.Target(3105, "Robuste")
	Expect(bad, "journal illisible", pcall(B.Kill, guid) and B.Species(1413, 3105).killed == 0)
	_G.CombatLogGetCurrentEventInfo = function() return unpack(B.W.cleu or {}) end
	_G.UnitGUID = function() error("boom") end
	Expect(bad, "UnitGUID en panne", pcall(B.Target, 3106, "Sans GUID") and B.Species(1413, 3106) == nil)
	_G.UnitGUID = function(unit)
		if unit == "player" then return PLAYER_GUID end
		local u = B.W.units[unit]; return u and u.guid
	end
	_G.UnitCreatureType, _G.UnitCreatureFamily, _G.UnitClassification, _G.UnitLevel = nil, nil, nil, nil
	Expect(bad, "API de créature absentes", pcall(B.Target, 3107, "Minimal") and B.Species(1413, 3107)
		and B.Species(1413, 3107).name == "Minimal")
	Expect(bad, "événement vide", pcall(NS.BestiaryCombat, NS, nil) and pcall(NS.BestiaryCombat, NS, "UNIT_DIED"))
	Check("[BST] robustesse : journal illisible, UnitGUID en panne, API de créature absentes, événement vide : pas d'erreur",
		#bad == 0, table.concat(bad, ", "))
end

-- ipairs sur la liste : une globale absente avant (nil) doit le redevenir
for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
C_Map.GetAreaInfo = saved.GetAreaInfo
NS.CompanionNextUnlocks = saved.NextUnlocks
NS.ZONE_CREATURES, NS.ZONE_GATHERING = saved.ZONE_CREATURES, saved.ZONE_GATHERING
NS.ZONE_QUESTS = saved.ZONE_QUESTS
NS.bestiaryUnits, NS.bestiaryPrunedAt = {}, nil
NS.journalRares = {}
if NS.journalTracker then NS.journalTracker:Hide() end
NS.journalTracker = nil
ResetWorld()
