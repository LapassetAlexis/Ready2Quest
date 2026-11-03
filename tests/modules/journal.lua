-- Module « Carnet de voyage » (v1.25.0) : tampons de zone, village, capitale,
-- donjon, rare, palier ; contrat STAMP / JournalCounts ; bandeau et chat ;
-- fenêtre ; commandes ; réglages.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

-- Mocks propres à ce fichier, restaurés à la fin
local saved, MOCKED = {}, { "IsInInstance", "GetInstanceInfo", "GetRealZoneText", "UnitClassification", "UnitGUID",
	"UnitIsPlayer", "UnitName", "CombatLogGetCurrentEventInfo", "InCombatLockdown", "UnitFactionGroup", "date" }
for _, name in ipairs(MOCKED) do saved[name] = rawget(_G, name) end
saved.GetAreaInfo = C_Map.GetAreaInfo

local J = { W = {}, stamps = {} }
local PLAYER_GUID = "Player-1-00000001"
_G.IsInInstance = function() return J.W.instance == true, J.W.instType or "none" end
_G.GetInstanceInfo = function()
	if not J.W.instance then return "Royaumes de l'Est", "none", 0, "", 0, 0, false, 0 end
	return J.W.instName, J.W.instType, 1, "Normal", 5, 0, false, J.W.instID
end
_G.GetRealZoneText = function() return J.W.zone or "" end
_G.UnitClassification = function(unit) local u = J.W.units[unit]; return u and u.class or "normal" end
_G.UnitGUID = function(unit)
	if unit == "player" then return PLAYER_GUID end
	local u = J.W.units[unit]; return u and u.guid
end
_G.UnitIsPlayer = function(unit) local u = J.W.units[unit]; return u and u.player == true or false end
_G.UnitName = function(unit)
	-- "player" doit rester « Testeur » : c'est la clé des données du personnage
	local u = J.W.units[unit]; if u then return u.name end
	return "Testeur"
end
_G.CombatLogGetCurrentEventInfo = function() return unpack(J.W.cleu or {}) end
_G.InCombatLockdown = function() return J.W.combat == true end
_G.UnitFactionGroup = function() return J.W.faction or "Alliance" end
_G.date = function() return "03/11/2026" end
C_Map.GetAreaInfo = nil

if not J.registered then
	NS:RegisterCallback("STAMP", function(_, stamp) J.stamps[#J.stamps + 1] = stamp end)
	J.registered = true
end

local ZONES = {
	[1415] = { mapID = 1415, name = "Royaumes de l'Est", parentMapID = 947, mapType = 2 },
	[947]  = { mapID = 947,  name = "Azeroth", parentMapID = 0, mapType = 1 },
	[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 1415, mapType = 3 },
	[1453] = { mapID = 1453, name = "Hurlevent", parentMapID = 1415, mapType = 3 },
	[1436] = { mapID = 1436, name = "Marche de l'Ouest", parentMapID = 1415, mapType = 3 },
	[9001] = { mapID = 9001, name = "Mine de Fargodeep", parentMapID = 1429, mapType = 5 },
}

function J.Reset(level)
	ResetWorld()
	J.W = { units = {}, faction = "Alliance" }
	J.stamps = {}
	for id, info in pairs(ZONES) do Mock.world.maps[id] = info end
	Mock.world.mapID = 1429
	Mock.world.subzone = "Bois"
	Mock.world.level = level or 11
	NS.journalRares = {}
	NS.journalToasts, NS.journalChats = {}, {}
	NS.journalToastHideAt = nil
	if NS.journalToast then NS.journalToast:Hide() end
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	NS.journalGroups, NS.journalGroupsFor = nil, nil
	NS.dungeonIndex = nil
end
function J.Enter() Mock:Fire("PLAYER_ENTERING_WORLD", true, false) end
function J.Map(mapID) Mock.world.mapID = mapID; Mock:Fire("ZONE_CHANGED_NEW_AREA") end
function J.Sub(subzone) Mock.world.subzone = subzone; Mock:Fire("ZONE_CHANGED") end
function J.Ids(kind)
	local ids = {}
	for id, stamp in pairs(NS:JournalData().stamps) do
		if not kind or stamp.kind == kind then ids[#ids + 1] = id end
	end
	table.sort(ids)
	return table.concat(ids, ",")
end
function J.Fired()
	local ids = {}
	for _, s in ipairs(J.stamps) do ids[#ids + 1] = s.id end
	return table.concat(ids, ",")
end
-- un événement du journal de combat
function J.Log(subevent, sourceGUID, sourceFlags, destGUID, destName)
	J.W.cleu = { 1000, subevent, false, sourceGUID, "src", sourceFlags, 0, destGUID, destName, 0x10a48, 0 }
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
end
function J.Target(guid, class, name, player)
	J.W.units.target = { guid = guid, class = class, name = name, player = player }
	Mock:Fire("PLAYER_TARGET_CHANGED")
end

-- 1. Chaînes ------------------------------------------------------------------
do
	Say("-- chaînes")
	Check("[JRN] Journal.lua chargé", NS.Loaded and NS.Loaded.Journal)
	local strings, missing, mismatch = NS.JOURNAL_STRINGS, {}, {}
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" then missing[#missing + 1] = "en:" .. key end
		if value == "" or NS.L[key] ~= value then missing[#missing + 1] = "fr:" .. key end
	end
	for key in pairs(strings.en) do if strings.fr[key] == nil then missing[#missing + 1] = "fr?" .. key end end
	Check("[JRN] chaînes en français et en anglais", #missing == 0, table.concat(missing, ", "))
	local function Placeholders(text)
		local list = {}
		for p in tostring(text):gsub("%%%%", ""):gmatch("%%[%d%$]*[sd]") do list[#list + 1] = p end
		return table.concat(list, ",")
	end
	for key, value in pairs(strings.fr) do
		if key ~= "JRN_DATE_FORMAT" and Placeholders(value) ~= Placeholders(strings.en[key]) then mismatch[#mismatch + 1] = key end
	end
	Check("[JRN] mêmes paramètres dans les deux langues", #mismatch == 0, table.concat(mismatch, ","))
	Check("[JRN] tutoiement (pas de « vous »)", not (strings.fr.JRN_EMPTY .. strings.fr.HELP_JOURNAL):find("[Vv]ous"))
	for _, kind in ipairs(NS.JOURNAL_KINDS) do
		Check("[JRN] onglet " .. kind .. " nommé (fr+en)", strings.fr["JRN_TAB_" .. kind] and strings.en["JRN_TAB_" .. kind])
	end
end

-- 2. Zones ----------------------------------------------------------------------
do
	Say("-- zones")
	J.Reset()
	J.Enter()
	local stamp = NS:JournalData().stamps["zone:1429"]
	Check("[JRN] zone : tamponnée à la première visite", stamp ~= nil, J.Ids())
	Check("[JRN] zone : nom traduit, date, niveau, sorte", stamp and stamp.name == "Forêt d'Elwynn"
		and stamp.date == "03/11/2026" and stamp.level == 11 and stamp.kind == "zone" and stamp.id == "zone:1429")
	Check("[JRN] STAMP émis avec le contrat", J.stamps[1] and J.stamps[1].id == "zone:1429" and J.stamps[1].kind == "zone"
		and J.stamps[1].name == "Forêt d'Elwynn" and J.stamps[1].new == true, J.Fired())
	J.stamps[1].name = "abîmé"
	Check("[JRN] STAMP : une copie, le carnet reste intact", stamp.name == "Forêt d'Elwynn")
	J.Map(9001)
	Check("[JRN] sous-carte (mine) : remonte à sa zone, pas de doublon", J.Ids("zone") == "zone:1429", J.Ids("zone"))
	J.Map(1436)
	Check("[JRN] nouvelle zone : nouveau tampon", J.Ids("zone") == "zone:1429,zone:1436", J.Ids("zone"))
	J.Map(1415)
	Check("[JRN] carte de continent : pas une zone", J.Ids("zone") == "zone:1429,zone:1436", J.Ids("zone"))
	local fired = #J.stamps
	J.Map(1429); J.Map(1436)
	Check("[JRN] retour dans une zone connue : rien de nouveau", #J.stamps == fired, J.Fired())

	-- « session suivante » : la sauvegarde reste, l'addon relit tout
	NS._dbReady = false
	J.stamps = {}
	J.Enter(); J.Map(1429)
	Check("[JRN] après /reload : aucun doublon, aucun STAMP", #J.stamps == 0 and J.Ids("zone") == "zone:1429,zone:1436", J.Fired())

	-- client sans mapType : la carte elle-même
	Mock.world.maps[20] = { mapID = 20, name = "Plaine sauvage", parentMapID = 0 }
	J.Map(20)
	Check("[JRN] client sans mapType : la carte courante", NS:HasStamp("zone:20"))
end

-- 3. Villages, capitales --------------------------------------------------------
do
	Say("-- villages et capitales")
	J.Reset()
	J.Enter()
	J.Sub("Goldshire")
	Check("[JRN] village de la base : tamponné (areaID)", NS:HasStamp("subzone:87"), J.Ids("subzone"))
	Check("[JRN] village : STAMP de sorte subzone", J.stamps[#J.stamps].id == "subzone:87" and J.stamps[#J.stamps].kind == "subzone")
	J.Sub("Bois"); J.Sub("Goldshire")
	Check("[JRN] village revisité : un seul tampon", J.Ids("subzone") == "subzone:87", J.Ids("subzone"))
	J.Sub("Clairière quelconque")
	Check("[JRN] sous-zone hors base : rien", J.Ids("subzone") == "subzone:87", J.Ids("subzone"))
	J.Sub("Razor Hill")
	Check("[JRN] village de l'autre faction : rien", not NS:HasStamp("subzone:362"), J.Ids("subzone"))
	J.Sub("Thunderbrew Distillery")
	Check("[JRN] auberge : pas de tampon (doublerait le village)", not NS:HasStamp("subzone:2102"), J.Ids("subzone"))
	J.Sub("Booty Bay")
	Check("[JRN] ville neutre : tamponnée", NS:HasStamp("subzone:35"))

	J.W.zone = "Stormwind City"
	J.Map(1453); J.Sub("Trade District")
	Check("[JRN] capitale : tamponnée, plus petit areaID (Hurlevent 1519/16509)", J.Ids("capital") == "capital:1519", J.Ids("capital"))
	Check("[JRN] capitale : aussi un tampon de zone", NS:HasStamp("zone:1453"))
	J.Sub("Old Town")
	Check("[JRN] capitale : un seul tampon par visite des quartiers", J.Ids("capital") == "capital:1519", J.Ids("capital"))
	J.W.zone = "Orgrimmar"; J.Sub("Valley of Strength")
	Check("[JRN] capitale de l'autre faction : un voyage, tamponné", NS:HasStamp("capital:1637"), J.Ids("capital"))

	-- noms traduits par le jeu : le nom affiché, et les lieux absents du client
	J.Reset()
	C_Map.GetAreaInfo = function(areaID)
		if areaID == 87 then return "Comté-de-l'Or" end
		if areaID == 1519 then return "Hurlevent" end
		return nil
	end
	NS.hubIndex = nil
	J.Enter(); J.Sub("Comté-de-l'Or")
	local s = NS:JournalData().stamps["subzone:87"]
	Check("[JRN] nom du lieu dans la langue du client", s and s.name == "Comté-de-l'Or", s and s.name)
	local groups = NS:JournalHubGroups()
	Check("[JRN] lieu sans nom dans ce client : hors des totaux", groups["Goldshire"] and groups["Goldshire"].exists == false
		and groups["Comté-de-l'Or"].exists == true)
	C_Map.GetAreaInfo = nil
	NS.hubIndex = nil
end

-- 4. Donjons --------------------------------------------------------------------
do
	Say("-- donjons")
	J.Reset(20)
	J.Enter()
	local zones = J.Ids("zone")
	J.W.instance, J.W.instType, J.W.instName, J.W.instID = true, "party", "Les Mortemines", 36
	J.Enter()
	Check("[JRN] donjon de la base : tamponné par sa clé", NS:HasStamp("dungeon:dm"), J.Ids("dungeon"))
	Check("[JRN] donjon : nom de l'instance", NS:JournalData().stamps["dungeon:dm"].name == "Les Mortemines")
	Check("[JRN] en instance : pas de tampon de zone", J.Ids("zone") == zones, J.Ids("zone"))
	J.W.instance = false; J.Map(1436)
	J.W.instance = true; J.Enter()
	Check("[JRN] donjon revisité : un seul tampon", J.Ids("dungeon") == "dungeon:dm", J.Ids("dungeon"))
	J.W.instType, J.W.instName, J.W.instID = "raid", "Cœur du Magma", 409
	J.Enter()
	Check("[JRN] raid : pas un donjon à 5", J.Ids("dungeon") == "dungeon:dm", J.Ids("dungeon"))
	J.W.instType, J.W.instName, J.W.instID = "pvp", "Goulet des Chanteguerres", 489
	J.Enter()
	Check("[JRN] champ de bataille : rien", J.Ids("dungeon") == "dungeon:dm", J.Ids("dungeon"))
	J.W.instType, J.W.instName, J.W.instID = "party", "Donjon inconnu", 9999
	J.Enter()
	Check("[JRN] donjon hors base : repli sur l'instance", NS:HasStamp("dungeon:i9999"), J.Ids("dungeon"))
end

-- 5. Rares ----------------------------------------------------------------------
do
	Say("-- rares")
	J.Reset(30)
	J.Enter()
	local RARE = "Creature-0-4378-0-12-61-00001A2B3C"
	J.Target(RARE, "rare", "Thuros Doigts-Agiles")
	J.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, RARE)
	J.Log("UNIT_DIED", nil, 0, RARE)
	local s = NS:JournalData().stamps["rare:61"]
	Check("[JRN] rare engagé puis tué : tamponné (id de PNJ)", s ~= nil and s.name == "Thuros Doigts-Agiles", J.Ids("rare"))
	Check("[JRN] rare : STAMP de sorte rare", J.stamps[#J.stamps].id == "rare:61" and J.stamps[#J.stamps].kind == "rare")

	-- même PNJ, autre apparition : pas de doublon
	local RARE2 = "Creature-0-4378-0-12-61-00009999"
	J.Target(RARE2, "rare", "Thuros Doigts-Agiles")
	J.Log("SPELL_DAMAGE", PLAYER_GUID, 0x511, RARE2); J.Log("UNIT_DIED", nil, 0, RARE2)
	Check("[JRN] même rare retué : un seul tampon", J.Ids("rare") == "rare:61", J.Ids("rare"))

	-- le rare d'un autre : vu, jamais touché par toi, mort quand même
	local OTHER = "Creature-0-4378-0-12-462-0000AAAA"
	J.Target(OTHER, "rareelite", "Vultros")
	J.Log("SWING_DAMAGE", "Player-1-00000099", 0x548, OTHER)
	J.Log("UNIT_DIED", nil, 0, OTHER)
	Check("[JRN] rare tué par un inconnu : rien", not NS:HasStamp("rare:462"), J.Ids("rare"))

	-- un membre du groupe le touche : engagé
	local PARTY = "Creature-0-4378-0-12-503-0000BBBB"
	J.Target(PARTY, "rareelite", "Lord Malathrom")
	J.Log("RANGE_MISSED", "Player-1-00000042", 0x512, PARTY)
	J.Log("UNIT_DIED", nil, 0, PARTY)
	Check("[JRN] rare élite engagé par le groupe (même raté) : tamponné", NS:HasStamp("rare:503"), J.Ids("rare"))

	-- coup fatal du groupe : PARTY_KILL suffit
	local KILL = "Creature-0-4378-0-12-584-0000CCCC"
	J.W.units["nameplate3"] = { guid = KILL, class = "rare", name = "Kazon" }
	Mock:Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
	J.Log("PARTY_KILL", PLAYER_GUID, 0x511, KILL)
	Check("[JRN] rare vu sur sa plaque, PARTY_KILL : tamponné", NS:HasStamp("rare:584"), J.Ids("rare"))

	-- pas un rare : élite, normal, joueur
	local ELITE = "Creature-0-4378-0-12-700-0000DDDD"
	J.Target(ELITE, "elite", "Gnoll")
	J.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, ELITE); J.Log("UNIT_DIED", nil, 0, ELITE)
	Check("[JRN] élite ordinaire : rien", not NS:HasStamp("rare:700"))
	J.Target("Player-1-00000077", "rare", "Un joueur", true)
	J.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, "Player-1-00000077"); J.Log("UNIT_DIED", nil, 0, "Player-1-00000077")
	Check("[JRN] un joueur n'est jamais un rare", J.Ids("rare") == "rare:503,rare:584,rare:61", J.Ids("rare"))
	-- jamais vu : le journal de combat seul ne suffit pas
	J.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, "Creature-0-4378-0-12-800-0000EEEE")
	J.Log("UNIT_DIED", nil, 0, "Creature-0-4378-0-12-800-0000EEEE")
	Check("[JRN] rare jamais repéré : rien", not NS:HasStamp("rare:800"))
	Check("[JRN] mémoire des rares vidée après leur mort", next(NS.journalRares) == nil)
end

-- 6. Paliers de niveau ----------------------------------------------------------
do
	Say("-- paliers")
	J.Reset(11)
	J.Enter()
	Check("[JRN] palier déjà atteint : rattrapé en silence", NS:HasStamp("level:10") and NS:JournalData().stamps["level:10"].retro == true)
	local silent = true
	for _, s in ipairs(J.stamps) do if s.kind == "level" then silent = false end end
	Check("[JRN] rattrapage : ni STAMP ni bandeau", silent and #NS.journalToasts == 0, J.Fired())
	J.stamps = {}
	Mock:Fire("PLAYER_LEVEL_UP", 15)
	Check("[JRN] niveau 15 : pas un palier", J.Ids("level") == "level:10" and #J.stamps == 0, J.Ids("level"))
	Mock:Fire("PLAYER_LEVEL_UP", 20)
	Check("[JRN] niveau 20 : tampon et STAMP", NS:HasStamp("level:20") and J.stamps[1] and J.stamps[1].id == "level:20"
		and J.stamps[1].kind == "level" and J.stamps[1].name == "Niveau 20", J.Fired())
	Check("[JRN] palier : niveau du personnage retenu", NS:JournalData().stamps["level:20"].level ~= nil)

	J.Reset(60)
	J.Enter()
	Check("[JRN] personnage 60 à l'installation : 6 paliers", J.Ids("level") == "level:10,level:20,level:30,level:40,level:50,level:60", J.Ids("level"))
end

-- 7. Bandeau, chat, combat, silence -----------------------------------------------
do
	Say("-- annonces")
	J.Reset(5)
	J.Enter()
	local toast = NS.journalToast
	Check("[JRN] bandeau affiché au gain", toast and toast:IsShown() and toast.message == "Nouveau tampon : Forêt d'Elwynn",
		toast and toast.message)
	Check("[JRN] bandeau : le nom en grand", toast and toast.text.text == "Forêt d'Elwynn")
	Check("[JRN] pas de chat par défaut", not Mock:Output():find("Nouveau tampon", 1, true))
	Mock:Advance(5)
	Check("[JRN] bandeau masqué après quelques secondes", not toast:IsShown())

	-- en combat : rien, puis tout à la sortie
	NS:DB().journalChat = true
	J.W.combat = true
	Mock:Reset()
	J.Sub("Goldshire")
	Check("[JRN] en combat : tampon gagné…", NS:HasStamp("subzone:87"))
	Check("[JRN] … mais ni bandeau ni chat", not toast:IsShown() and not Mock:Output():find("Goldshire", 1, true))
	Mock:Advance(10)
	Check("[JRN] toujours en combat : rien ne sort", not toast:IsShown())
	J.W.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Check("[JRN] sortie de combat : bandeau", toast:IsShown() and toast.message == "Nouveau tampon : Goldshire", toast.message)
	Check("[JRN] sortie de combat : ligne de chat", Mock:Output():find("Nouveau tampon (Villages) : Goldshire.", 1, true), Mock:Output())

	-- deux tampons : l'un après l'autre
	Mock:Advance(5)
	J.Map(1436); J.Sub("Sentinel Hill")
	Check("[JRN] deux tampons : le premier d'abord", toast.message == "Nouveau tampon : Marche de l'Ouest", toast.message)
	Mock:Advance(5)
	Check("[JRN] puis le second", toast:IsShown() and toast.message == "Nouveau tampon : Sentinel Hill", toast.message)
	Mock:Advance(5)

	-- une rafale : un seul bandeau groupé
	J.W.combat = true
	J.Sub("Lakeshire"); J.Sub("Darkshire"); J.Sub("Goldshire"); J.Sub("Thelsamar")
	J.W.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Check("[JRN] rafale : un bandeau groupé", toast.message == "3 nouveaux tampons" and #NS.journalToasts == 0, toast.message)
	Mock:Advance(5)

	-- silence
	J.Reset(5)
	NS:DB().journalToast, NS:DB().journalChat = false, false
	Mock:Reset()
	J.Enter(); J.Sub("Goldshire")
	Check("[JRN] bandeau coupé : rien d'affiché", not (NS.journalToast and NS.journalToast:IsShown()) and #NS.journalToasts == 0)
	Check("[JRN] chat coupé : rien dans le chat", not Mock:Output():find("tampon", 1, true))
	Check("[JRN] silence : le tampon est gagné quand même, STAMP aussi", NS:HasStamp("subzone:87") and #J.stamps == 2, J.Fired())
end

-- 8. Comptes (contrat) ------------------------------------------------------------
do
	Say("-- comptes")
	J.Reset(20)
	J.Enter(); J.Sub("Goldshire"); J.Map(1436); J.Sub("Sentinel Hill")
	J.W.zone = "Stormwind City"; J.Map(1453)
	J.W.zone = ""
	J.W.instance, J.W.instType, J.W.instName, J.W.instID = true, "party", "Les Mortemines", 36
	J.Enter()
	local c = NS:JournalCounts()
	Check("[JRN] JournalCounts : chaque sorte", c.zone == 3 and c.subzone == 2 and c.capital == 1 and c.dungeon == 1
		and c.rare == 0 and c.level == 2, string.format("%d %d %d %d %d %d", c.zone, c.subzone, c.capital, c.dungeon, c.rare, c.level))
	Check("[JRN] JournalCounts : total", c.total == 9, c.total)
end

-- 9. Fenêtre, commandes -----------------------------------------------------------
do
	Say("-- fenêtre")
	J.Reset(20)
	J.Enter(); J.Sub("Goldshire")
	J.W.zone = "Stormwind City"; J.Map(1453)
	NS:HandleCommand("carnet")
	local f = NS.journalFrame
	Check("[JRN] /r2q carnet ouvre le carnet", f and f:IsShown())
	Check("[JRN] fenêtre Theme (titre)", f and f.title and f.title.text == "Carnet de voyage")
	Check("[JRN] six onglets", f and f.tabs.zone and f.tabs.subzone and f.tabs.capital and f.tabs.dungeon and f.tabs.rare and f.tabs.level)
	Check("[JRN] total en sous-titre", f.subtitle.text:find("6 tampon", 1, true), f.subtitle.text)
	Check("[JRN] zones : compte seul (pas de total)", f.counter.text == "Zones : 2", f.counter.text)
	f.tabs.capital:Click()
	Check("[JRN] capitales : 1 / 6", f.counter.text == "Capitales : 1 / 6", f.counter.text)
	Check("[JRN] capitales : gagnée d'abord, losange plein", f.lines[1].item.earned and f.lines[1].name.text == "Stormwind City"
		and f.lines[1].stamp.texture == NS.Theme.DIAMOND)
	Check("[JRN] capitales : à découvrir en trait", f.lines[2].item and not f.lines[2].item.earned
		and f.lines[2].stamp.texture == NS.Theme.DIAMOND_LINE and f.lines[2].detail.text:find("à découvrir", 1, true))
	Check("[JRN] date et niveau sur la ligne", f.lines[1].detail.text:find("03/11/2026", 1, true) and f.lines[1].detail.text:find("niv. 20", 1, true), f.lines[1].detail.text)
	f.tabs.dungeon:Click()
	local dungeons = 0
	for _ in pairs(NS.DUNGEONS) do dungeons = dungeons + 1 end
	Check("[JRN] donjons : total de la base (Forever : 28)", f.counter.text == "Donjons : 0 / " .. dungeons, f.counter.text)
	f.tabs.level:Click()
	Check("[JRN] paliers : 2 / 6, dans l'ordre", f.counter.text == "Paliers : 2 / 6" and f.lines[1].name.text == "Niveau 10"
		and f.lines[3].name.text == "Niveau 30", f.counter.text)
	f.tabs.rare:Click()
	Check("[JRN] page vide : invitation à explorer", f.empty.text == NS.L.JRN_EMPTY and not f.lines[1]:IsShown())

	-- défilement
	f.tabs.subzone:Click()
	local items = #f.items
	Check("[JRN] villages : de quoi défiler", items > 10, items)
	Check("[JRN] en haut : pas de ^, un v", not f.up:IsShown() and f.down:IsShown())
	f.scripts.OnMouseWheel(f, -1)
	Check("[JRN] molette : une ligne plus bas", f.offset == 1 and f.lines[1].item == f.items[2])
	f.down:Click()
	Check("[JRN] bouton v", f.offset == 2 and f.up:IsShown())
	f.up:Click()
	Check("[JRN] bouton ^", f.offset == 1)
	for _ = 1, 200 do NS:ScrollJournal(-1) end
	Check("[JRN] butée en bas", f.offset == items - 10 and not f.down:IsShown(), f.offset)
	Check("[JRN] position affichée", f.position.text == string.format("%d-%d / %d", items - 9, items, items), f.position.text)
	f.tabs.zone:Click()
	Check("[JRN] changer d'onglet remonte en haut", f.offset == 0)

	-- un nouveau tampon rafraîchit la fenêtre ouverte
	J.Map(1436)
	Check("[JRN] fenêtre ouverte : rafraîchie au gain", f.counter.text == "Zones : 3", f.counter.text)
	NS:HandleCommand("journal")
	Check("[JRN] /r2q journal : referme", not f:IsShown())
	NS:HandleCommand("carnet")
	Check("[JRN] /r2q carnet : rouvre", f:IsShown())
	f:Hide()
	Check("[JRN] aide : la commande listée", (function()
		for _, section in ipairs(NS.HELP) do
			for _, key in ipairs(section[2]) do if key == "HELP_JOURNAL" then return true end end
		end
	end)())
end

-- 10. Réglages, module coupé -------------------------------------------------------
do
	Say("-- réglages")
	J.Reset(20)
	NS.optionsFrame = nil
	NS:ToggleOptions()
	local o = NS.optionsFrame
	-- v1.25.0 : un seul module « Compagnon de route », le carnet en est une sous-page
	local nav, parentNav
	for _, button in ipairs(o.navButtons) do
		if button.pageId == "journal" then nav = button end
		if button.pageId == "companion" then parentNav = button end
	end
	local page = o.pages.journal
	Check("[JRN] sous-page du Compagnon de route", nav and nav.parentId == "companion" and nav.power == nil and page)
	Check("[JRN] interrupteur unique sur le module parent", parentNav and parentNav.power ~= nil)
	Check("[JRN] page rangée dans MODULES", (function()
		local seen
		for _, def in ipairs(NS.OPTION_PAGES) do
			if def.id == "journal" then seen = true end
			if def.id == "merchant" then return seen == true end
		end
	end)())
	Check("[JRN] phrase d'explication", page and page.sub.text == NS.L.OPT_PAGE_JOURNAL_SUB)
	Check("[JRN] bandeau et chat réglables", page and #page.rows == 2)
	local button = page and page.actionButtons and page.actionButtons.journal
	Check("[JRN] bouton « Ouvrir le carnet »", button and button.text.text == "Ouvrir le carnet")
	if button then button:Click() end
	Check("[JRN] le bouton ouvre le carnet", NS.journalFrame and NS.journalFrame:IsShown())
	-- bug signalé en jeu : le carnet recouvrait les réglages
	Check("[JRN] une seule fenêtre : les réglages se ferment", o:IsShown() == false)
	NS:ToggleOptions()
	Check("[JRN] une seule fenêtre : rouvrir les réglages ferme le carnet", NS.journalFrame:IsShown() == false)
	NS:ToggleJournal(true)
	if button then button:Click() end
	Check("[JRN] le bouton n'est pas une bascule (reste ouvert)", NS.journalFrame:IsShown())
	NS.journalFrame:Hide()
	local minimapAngle = NS:DB().minimapAngle
	NS:RunOptionAction("minimapPos")
	Check("[JRN] relais : les autres actions passent toujours", NS:DB().minimapAngle ~= minimapAngle)
	if parentNav then
		parentNav.power:Click()
		Check("[JRN] interrupteur : module coupé", NS:DB().companionEnabled == false)
		parentNav.power:Click()
		Check("[JRN] interrupteur : rallumé", NS:DB().companionEnabled == true)
	end
	o:Hide()
	NS.optionsFrame = nil

	-- module coupé : rien ne se gagne
	J.Reset(20)
	NS:HandleCommand("module carnet off")
	Check("[JRN] /r2q module carnet off", NS:DB().companionEnabled == false)
	J.Enter(); J.Sub("Goldshire")
	J.W.instance, J.W.instType, J.W.instName, J.W.instID = true, "party", "Les Mortemines", 36
	J.Enter()
	Mock:Fire("PLAYER_LEVEL_UP", 30)
	J.Target("Creature-0-4378-0-12-61-00001A2B3C", "rare", "Thuros")
	J.Log("SWING_DAMAGE", PLAYER_GUID, 0x511, "Creature-0-4378-0-12-61-00001A2B3C")
	J.Log("UNIT_DIED", nil, 0, "Creature-0-4378-0-12-61-00001A2B3C")
	Check("[JRN] module coupé : aucun tampon", NS:JournalCounts().total == 0 and #J.stamps == 0, J.Ids())
	Check("[JRN] module coupé : aucun rare suivi", next(NS.journalRares) == nil)
	Mock:Reset()
	NS:HandleCommand("carnet")
	Check("[JRN] module coupé : le carnet s'ouvre, avec un rappel", NS.journalFrame:IsShown()
		and Mock:Output():find("Carnet coupé", 1, true))
	NS.journalFrame:Hide()
	NS:HandleCommand("module journal on")
	Check("[JRN] /r2q module journal on", NS:DB().companionEnabled == true)
	J.W.instance = false
	Mock:Fire("PLAYER_ENTERING_WORLD", false, false)
	Check("[JRN] rallumé : les paliers manqués sont rattrapés en silence", NS:HasStamp("level:20")
		and NS:JournalData().stamps["level:20"].retro == true)
	Check("[JRN] « carnet » vise le Compagnon de route, sans conflit", NS:FindModule("carnet").id == "companion" and not NS:FindCheck("carnet"))

	-- interrupteur général de l'addon
	J.Reset(20)
	NS:DB().enabled = false
	J.Enter()
	Check("[JRN] addon coupé : aucun tampon", NS:JournalCounts().total == 0)
end

-- 11. Robustesse --------------------------------------------------------------------
do
	Say("-- robustesse")
	J.Reset(20)
	_G.CombatLogGetCurrentEventInfo = function() error("boom") end
	J.Target("Creature-0-4378-0-12-61-00001A2B3C", "rare", "Thuros")
	J.Log("UNIT_DIED", nil, 0, "Creature-0-4378-0-12-61-00001A2B3C")
	Check("[JRN] journal de combat illisible : pas d'erreur, pas de tampon", not NS:HasStamp("rare:61"))
	_G.CombatLogGetCurrentEventInfo = saved.CombatLogGetCurrentEventInfo
	_G.GetInstanceInfo = nil
	J.W.instance = true
	local ok = pcall(J.Enter)
	Check("[JRN] sans GetInstanceInfo : pas d'erreur", ok)
	_G.date = nil
	J.W.instance = false
	J.Map(1436)
	Check("[JRN] sans date() : tampon sans date", NS:HasStamp("zone:1436") and NS:JournalData().stamps["zone:1436"].date == nil)
end

-- ipairs sur la liste : une globale absente avant (nil) doit le redevenir
for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
C_Map.GetAreaInfo = saved.GetAreaInfo
