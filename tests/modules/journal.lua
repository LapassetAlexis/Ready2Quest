-- Carnet de voyage (v1.25.0, refondu au carnet 1.5.0).
-- 1. Tampons (Journal.lua) : zone, village, capitale, donjon, rare, palier ;
--    contrat STAMP / JournalCounts ; relevés silencieux (2.7.0) et file des
--    bandeaux ; fenêtre et commandes ; réglages, module coupé ; robustesse.
-- 2. Fenêtre (JournalWindow.lua) : roue des réglages, « Son allure » (ex-Collection),
--    tranche de niveaux des zones, garde-manger, caractère de la Créature,
--    objectif qui ouvre sa zone.
-- 3. Page Exploration / Complétion (JournalCompletion.lua) : liste des zones,
--    carte de zone (%, paliers, coffre, suivi), cartes de part, bestiaire vers
--    les Créatures, choix de zone, molette et pagination, mise en page.
local Check, Say, ResetWorld, Mock = T.Check, T.Say, T.ResetWorld, T.Mock
local NS = T.QNS

local function Expect(bad, label, ok) if not ok then bad[#bad + 1] = label end end
-- chaînes d'une table fr/en : mêmes clés, non vides, actives en français, mêmes
-- paramètres, tutoiement ; renvoie la liste des écarts
local function StringGaps(strings, skipPlaceholders)
	local gaps = {}
	local function Placeholders(text)
		local list = {}
		for p in tostring(text):gsub("%%%%", ""):gmatch("%%[%d%$]*[sd]") do list[#list + 1] = p end
		return table.concat(list, ",")
	end
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" then gaps[#gaps + 1] = "en:" .. key end
		if value == "" or NS.L[key] ~= value then gaps[#gaps + 1] = "fr:" .. key end
		if not (skipPlaceholders and skipPlaceholders[key]) and Placeholders(value) ~= Placeholders(strings.en[key]) then
			gaps[#gaps + 1] = "%:" .. key
		end
		if tostring(value):find("[Vv]ous") then gaps[#gaps + 1] = "vous:" .. key end
	end
	for key in pairs(strings.en) do if strings.fr[key] == nil then gaps[#gaps + 1] = "fr?" .. key end end
	return gaps
end

-- ============================================================================
-- 1. Tampons
-- ============================================================================
do
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

	NS:RegisterCallback("STAMP", function(_, stamp) J.stamps[#J.stamps + 1] = stamp end)

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
	function J.Log(subevent, sourceGUID, sourceFlags, destGUID, destName)
		J.W.cleu = { 1000, subevent, false, sourceGUID, "src", sourceFlags, 0, destGUID, destName, 0x10a48, 0 }
		Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	end
	function J.Target(guid, class, name, player)
		J.W.units.target = { guid = guid, class = class, name = name, player = player }
		Mock:Fire("PLAYER_TARGET_CHANGED")
	end
	function J.Kill(guid, subevent, source, flags)
		J.Log(subevent or "SWING_DAMAGE", source or PLAYER_GUID, flags or 0x511, guid)
		J.Log("UNIT_DIED", nil, 0, guid)
	end

	-- 1.1 Chaînes ------------------------------------------------------------------
	do
		Say("-- carnet : chaînes")
		local gaps = StringGaps(NS.JOURNAL_STRINGS, { JRN_DATE_FORMAT = true })
		for _, kind in ipairs(NS.JOURNAL_KINDS) do
			Expect(gaps, "onglet:" .. kind, NS.JOURNAL_STRINGS.fr["JRN_TAB_" .. kind] and NS.JOURNAL_STRINGS.en["JRN_TAB_" .. kind])
		end
		Check("[JRN] chaînes fr/en : mêmes clés, mêmes paramètres, tutoiement, chaque onglet nommé", NS.Loaded
			and NS.Loaded.Journal and #gaps == 0, table.concat(gaps, ", "))
	end

	-- 1.2 Zones ----------------------------------------------------------------------
	do
		Say("-- carnet : zones")
		J.Reset()
		J.Enter()
		local stamp = NS:JournalData().stamps["zone:1429"]
		Check("[JRN] zone : tamponnée à la première visite (nom traduit, date, niveau, sorte)", stamp and stamp.name == "Forêt d'Elwynn"
			and stamp.date == "03/11/2026" and stamp.level == 11 and stamp.kind == "zone" and stamp.id == "zone:1429", J.Ids())
		local fired = J.stamps[1]
		local contract = fired and fired.id == "zone:1429" and fired.kind == "zone" and fired.name == "Forêt d'Elwynn" and fired.new == true
		if fired then fired.name = "abîmé" end
		Check("[JRN] STAMP émis avec le contrat, une copie (le carnet reste intact)", contract and stamp.name == "Forêt d'Elwynn",
			J.Fired())
		J.Map(9001)
		local sub = J.Ids("zone")
		J.Map(1436)
		J.Map(1415)
		Check("[JRN] sous-carte (mine) : sa zone ; nouvelle zone : tampon ; continent : rien", sub == "zone:1429"
			and J.Ids("zone") == "zone:1429,zone:1436", J.Ids("zone"))
		local count = #J.stamps
		J.Map(1429); J.Map(1436)
		local revisit = #J.stamps == count
		-- « session suivante » : la sauvegarde reste, l'addon relit tout
		NS._dbReady = false
		J.stamps = {}
		J.Enter(); J.Map(1429)
		Check("[JRN] retour dans une zone connue, /reload : aucun doublon, aucun STAMP", revisit and #J.stamps == 0
			and J.Ids("zone") == "zone:1429,zone:1436", J.Fired())
		-- client sans mapType : la carte elle-même
		Mock.world.maps[20] = { mapID = 20, name = "Plaine sauvage", parentMapID = 0 }
		J.Map(20)
		Check("[JRN] client sans mapType : la carte courante", NS:HasStamp("zone:20"))
	end

	-- 1.3 Villages, capitales --------------------------------------------------------
	do
		Say("-- carnet : villages et capitales")
		J.Reset()
		J.Enter()
		J.Sub("Goldshire")
		local last = J.stamps[#J.stamps]
		J.Sub("Booty Bay")
		Check("[JRN] village de la base (areaID) et ville neutre : tamponnés, STAMP de sorte subzone", NS:HasStamp("subzone:87")
			and last and last.id == "subzone:87" and last.kind == "subzone" and NS:HasStamp("subzone:35"), J.Ids("subzone"))
		J.Sub("Bois"); J.Sub("Goldshire")
		J.Sub("Clairière quelconque")
		J.Sub("Razor Hill")
		J.Sub("Thunderbrew Distillery")
		Check("[JRN] rien de plus : village revisité, sous-zone hors base, autre faction, auberge",
			J.Ids("subzone") == "subzone:35,subzone:87", J.Ids("subzone"))
		J.W.zone = "Stormwind City"
		J.Map(1453); J.Sub("Trade District")
		J.Sub("Old Town")
		Check("[JRN] capitale : un tampon (plus petit areaID, Hurlevent 1519/16509) par visite des quartiers, plus la zone",
			J.Ids("capital") == "capital:1519" and NS:HasStamp("zone:1453"), J.Ids("capital"))
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
		local groups = NS:JournalHubGroups()
		Check("[JRN] nom du lieu dans la langue du client ; lieu sans nom dans ce client : hors des totaux", s
			and s.name == "Comté-de-l'Or" and groups["Goldshire"] and groups["Goldshire"].exists == false
			and groups["Comté-de-l'Or"].exists == true, s and s.name)
		C_Map.GetAreaInfo = nil
		NS.hubIndex = nil
	end

	-- 1.4 Donjons --------------------------------------------------------------------
	do
		Say("-- carnet : donjons")
		J.Reset(20)
		J.Enter()
		local zones = J.Ids("zone")
		J.W.instance, J.W.instType, J.W.instName, J.W.instID = true, "party", "Les Mortemines", 36
		J.Enter()
		Check("[JRN] donjon de la base : tamponné par sa clé, nom de l'instance, pas de tampon de zone", NS:HasStamp("dungeon:dm")
			and NS:JournalData().stamps["dungeon:dm"].name == "Les Mortemines" and J.Ids("zone") == zones, J.Ids())
		J.W.instance = false; J.Map(1436)
		J.W.instance = true; J.Enter()
		J.W.instType, J.W.instName, J.W.instID = "raid", "Cœur du Magma", 409
		J.Enter()
		J.W.instType, J.W.instName, J.W.instID = "pvp", "Goulet des Chanteguerres", 489
		J.Enter()
		Check("[JRN] donjon revisité, raid, champ de bataille : rien de plus", J.Ids("dungeon") == "dungeon:dm", J.Ids("dungeon"))
		J.W.instType, J.W.instName, J.W.instID = "party", "Donjon inconnu", 9999
		J.Enter()
		Check("[JRN] donjon hors base : repli sur l'instance", NS:HasStamp("dungeon:i9999"), J.Ids("dungeon"))
	end

	-- 1.5 Rares ----------------------------------------------------------------------
	do
		Say("-- carnet : rares")
		J.Reset(30)
		J.Enter()
		local RARE = "Creature-0-4378-0-12-61-00001A2B3C"
		J.Target(RARE, "rare", "Thuros Doigts-Agiles")
		J.Kill(RARE)
		local s = NS:JournalData().stamps["rare:61"]
		local last = J.stamps[#J.stamps]
		Check("[JRN] rare engagé puis tué : tamponné (id de PNJ), STAMP de sorte rare", s and s.name == "Thuros Doigts-Agiles"
			and last.id == "rare:61" and last.kind == "rare", J.Ids("rare"))
		local RARE2 = "Creature-0-4378-0-12-61-00009999"
		J.Target(RARE2, "rare", "Thuros Doigts-Agiles")
		J.Kill(RARE2, "SPELL_DAMAGE")
		Check("[JRN] même rare retué : un seul tampon", J.Ids("rare") == "rare:61", J.Ids("rare"))
		-- le rare d'un autre : vu, jamais touché par toi, mort quand même
		local OTHER = "Creature-0-4378-0-12-462-0000AAAA"
		J.Target(OTHER, "rareelite", "Vultros")
		J.Kill(OTHER, "SWING_DAMAGE", "Player-1-00000099", 0x548)
		Check("[JRN] rare tué par un inconnu : rien", not NS:HasStamp("rare:462"), J.Ids("rare"))
		-- un membre du groupe le touche (même raté) ; coup fatal du groupe vu sur sa plaque
		local PARTY = "Creature-0-4378-0-12-503-0000BBBB"
		J.Target(PARTY, "rareelite", "Lord Malathrom")
		J.Kill(PARTY, "RANGE_MISSED", "Player-1-00000042", 0x512)
		local KILL = "Creature-0-4378-0-12-584-0000CCCC"
		J.W.units["nameplate3"] = { guid = KILL, class = "rare", name = "Kazon" }
		Mock:Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
		J.Log("PARTY_KILL", PLAYER_GUID, 0x511, KILL)
		Check("[JRN] rare engagé par le groupe (même raté), ou vu sur sa plaque puis PARTY_KILL : tamponné",
			NS:HasStamp("rare:503") and NS:HasStamp("rare:584"), J.Ids("rare"))
		-- pas un rare : élite, joueur ; jamais vu : le journal de combat seul ne suffit pas
		local ELITE = "Creature-0-4378-0-12-700-0000DDDD"
		J.Target(ELITE, "elite", "Gnoll")
		J.Kill(ELITE)
		J.Target("Player-1-00000077", "rare", "Un joueur", true)
		J.Kill("Player-1-00000077")
		J.Kill("Creature-0-4378-0-12-800-0000EEEE")
		Check("[JRN] élite ordinaire, joueur, rare jamais repéré : rien ; mémoire des rares vidée",
			J.Ids("rare") == "rare:503,rare:584,rare:61" and next(NS.journalRares) == nil, J.Ids("rare"))
	end

	-- 1.6 Paliers de niveau ----------------------------------------------------------
	do
		Say("-- carnet : paliers")
		J.Reset(11)
		J.Enter()
		local silent = true
		for _, s in ipairs(J.stamps) do if s.kind == "level" then silent = false end end
		Check("[JRN] palier déjà atteint : rattrapé en silence (ni STAMP ni bandeau)", NS:HasStamp("level:10")
			and NS:JournalData().stamps["level:10"].retro == true and silent and #NS.journalToasts == 0, J.Fired())
		J.stamps = {}
		Mock:Fire("PLAYER_LEVEL_UP", 15)
		local none = J.Ids("level") == "level:10" and #J.stamps == 0
		Mock:Fire("PLAYER_LEVEL_UP", 20)
		Check("[JRN] niveau 15 : rien ; niveau 20 : tampon et STAMP, niveau retenu", none and NS:HasStamp("level:20")
			and J.stamps[1] and J.stamps[1].id == "level:20" and J.stamps[1].kind == "level" and J.stamps[1].name == "Niveau 20"
			and NS:JournalData().stamps["level:20"].level ~= nil, J.Fired())
		J.Reset(60)
		J.Enter()
		Check("[JRN] personnage 60 à l'installation : 6 paliers", J.Ids("level") == "level:10,level:20,level:30,level:40,level:50,level:60", J.Ids("level"))
	end

	-- 1.7 Relevés silencieux (2.7.0) : plus de bandeau ni de chat « Nouveau tampon » --
	do
		Say("-- carnet : annonces (relevés silencieux)")
		J.Reset(5)
		NS:DB().journalChat = true
		Mock:Reset()
		J.Enter()
		J.W.combat = true
		J.Sub("Goldshire")
		J.W.combat = false
		Mock:Fire("PLAYER_REGEN_ENABLED")
		Check("[JRN] 2.7.0 : tampons gagnés et STAMP émis, mais ni bandeau ni chat « Nouveau tampon » (même chat allumé, sortie de combat)",
			NS:HasStamp("zone:1429") and NS:HasStamp("subzone:87") and #J.stamps >= 1 and #NS.journalToasts == 0
			and not (NS.journalToast and NS.journalToast:IsShown() and (NS.journalToast.message or ""):find("Nouveau tampon", 1, true))
			and not Mock:Output():find("Nouveau tampon", 1, true) and not Mock:Output():find("Goldshire", 1, true), Mock:Output())
		-- la file du carnet reste : un bandeau poussé à la main (sceau, titre) s'affiche
		NS:DB().journalChat = false
		NS:JournalNotify({ kind = "subzone", name = "Comté-du-Nord", id = "subzone:1" })
		local toast = NS.journalToast
		local shown = toast and toast:IsShown() and toast.message == "Nouveau tampon : Comté-du-Nord"
		Mock:Advance(5)
		Check("[JRN] la file des bandeaux du carnet marche toujours (sceaux, titres), masquée après quelques secondes",
			shown and not toast:IsShown(), toast and toast.message)
		-- rafale de bandeaux simples : groupée ; un bandeau « tout fait » (haut fait) passe à part
		J.W.combat = true
		for i = 1, 3 do NS:JournalToastPush({ kind = "seal", name = "Zone " .. i }) end
		NS:JournalToastPush({ kind = "feat", title = "Haut fait obtenu", name = "Premier filet", points = 5 })
		J.W.combat = false
		Mock:Fire("PLAYER_REGEN_ENABLED")
		local grouped = toast.message == "3 nouveaux tampons" and #NS.journalToasts == 1
		Mock:Advance(5)
		Check("[JRN] rafale : bandeaux simples groupés, puis le haut fait à part", grouped and toast:IsShown()
			and toast.message == "Premier filet" and #NS.journalToasts == 0, toast.message)
		Mock:Advance(5)
		NS:DB().journalToast = false
		Check("[JRN] bandeaux du carnet coupés : rien en file", NS:JournalToastPush({ kind = "seal", name = "X" }) == false)
	end

	-- 1.8 Comptes (contrat) ------------------------------------------------------------
	do
		Say("-- carnet : comptes")
		J.Reset(20)
		J.Enter(); J.Sub("Goldshire"); J.Map(1436); J.Sub("Sentinel Hill")
		J.W.zone = "Stormwind City"; J.Map(1453)
		J.W.zone = ""
		J.W.instance, J.W.instType, J.W.instName, J.W.instID = true, "party", "Les Mortemines", 36
		J.Enter()
		local c = NS:JournalCounts()
		Check("[JRN] JournalCounts : chaque sorte et le total", c.zone == 3 and c.subzone == 2 and c.capital == 1 and c.dungeon == 1
			and c.rare == 0 and c.level == 2 and c.total == 9,
			string.format("%d %d %d %d %d %d / %d", c.zone, c.subzone, c.capital, c.dungeon, c.rare, c.level, c.total))
	end

	-- 1.9 Fenêtre, commandes -----------------------------------------------------------
	do
		Say("-- carnet : fenêtre et commandes")
		-- 3.1.0 : au thème forgé, les points sont sur la plaque sous la marque
		local function PointsText(frame)
			if frame and frame.featPlate then return frame.featPlate.text.text or "" end
			return frame and frame.subtitle.text or ""
		end
		J.Reset(20)
		J.Enter(); J.Sub("Goldshire")
		J.W.zone = "Stormwind City"; J.Map(1453)
		NS:HandleCommand("carnet")
		local f = NS.journalFrame
		Check("[JRN] /r2q carnet : ouvert sur le Compagnon, titre, sections, points de hauts faits (2.7.0)", f and f:IsShown()
			and f.title.text == "Carnet de voyage" and f.sections.progress and f.sections.evolution and f.kind == "evolution"
			and PointsText(f):find("0 points de hauts faits", 1, true), f and PointsText(f))
		f.sections.evolution:Click()
		local before = PointsText(f)
		NS:FeatAward("char_level_10", { silent = true })
		Check("[JRN] fenêtre ouverte : rafraîchie au gain d'un haut fait", PointsText(f) ~= before
			and PointsText(f):find("5 points", 1, true), PointsText(f))
		NS:HandleCommand("journal")
		local closed = not f:IsShown()
		NS:HandleCommand("carnet")
		local help = false
		for _, section in ipairs(NS.HELP) do
			for _, key in ipairs(section[2]) do if key == "HELP_JOURNAL" then help = true end end
		end
		Check("[JRN] /r2q journal referme, /r2q carnet rouvre ; commande dans l'aide", closed and f:IsShown() and help)
		f:Hide()
	end

	-- 1.10 Réglages, module coupé -------------------------------------------------------
	do
		Say("-- carnet : réglages")
		J.Reset(20)
		NS.optionsFrame = nil
		NS:ToggleOptions()
		local o = NS.optionsFrame
		-- v1.25.0 : un seul module « Compagnon de route », le carnet en est une sous-page
		local nav, parentNav, group
		for _, button in ipairs(o.navButtons) do if button.pageId == "journal" then nav = button end end
		for _, header in ipairs(o.navHeaders) do if header.pageId == "companion" then parentNav = header end end
		for _, def in ipairs(NS.OPTION_PAGES) do if def.id == "journal" then group = def.group end end
		local page = o.pages.journal
		nav:Click()
		Check("[JRN] sous-page du Compagnon de route (MODULES), interrupteur unique sur le parent, explication", nav
			and nav.parentId == "companion" and page and o.currentPage == "journal" and o.header.title.text == NS.L.OPT_PAGE_JOURNAL
			and parentNav and parentNav.powerKey == "companionEnabled" and group == "OPT_GROUP_MODULES"
			and page.subText == NS.L.OPT_PAGE_JOURNAL_SUB)
		local button = page and page.actionButtons and page.actionButtons.journal
		if button then button:Click() end
		-- bug signalé en jeu : le carnet recouvrait les réglages
		Check("[JRN] « Ouvrir le carnet » : ouvert, les réglages se ferment (une seule fenêtre)", button
			and button.text.text == "Ouvrir le carnet" and NS.journalFrame and NS.journalFrame:IsShown() and o:IsShown() == false)
		NS:ToggleOptions()
		local closedByOptions = NS.journalFrame:IsShown() == false
		NS:ToggleJournal(true)
		if button then button:Click() end
		Check("[JRN] rouvrir les réglages ferme le carnet ; le bouton n'est pas une bascule", closedByOptions
			and NS.journalFrame:IsShown())
		NS.journalFrame:Hide()
		local minimapAngle = NS:DB().minimapAngle
		NS:RunOptionAction("minimapPos")
		Check("[JRN] relais : les autres actions passent toujours", NS:DB().minimapAngle ~= minimapAngle)
		parentNav.power:Click()
		local off = NS:DB().companionEnabled == false
		parentNav.power:Click()
		Check("[JRN] interrupteur : coupé puis rallumé", off and NS:DB().companionEnabled == true)
		o:Hide()
		NS.optionsFrame = nil

		-- module coupé : rien ne se gagne
		J.Reset(20)
		NS:HandleCommand("module carnet off")
		local cmdOff = NS:DB().companionEnabled == false
		J.Enter(); J.Sub("Goldshire")
		J.W.instance, J.W.instType, J.W.instName, J.W.instID = true, "party", "Les Mortemines", 36
		J.Enter()
		Mock:Fire("PLAYER_LEVEL_UP", 30)
		J.Target("Creature-0-4378-0-12-61-00001A2B3C", "rare", "Thuros")
		J.Kill("Creature-0-4378-0-12-61-00001A2B3C")
		Check("[JRN] /r2q module carnet off : aucun tampon, aucun rare suivi", cmdOff and NS:JournalCounts().total == 0
			and #J.stamps == 0 and next(NS.journalRares) == nil, J.Ids())
		Mock:Reset()
		NS:HandleCommand("carnet")
		Check("[JRN] module coupé : le carnet s'ouvre, avec un rappel", NS.journalFrame:IsShown()
			and Mock:Output():find("Carnet coupé", 1, true))
		NS.journalFrame:Hide()
		NS:HandleCommand("module journal on")
		J.W.instance = false
		Mock:Fire("PLAYER_ENTERING_WORLD", false, false)
		Check("[JRN] /r2q module journal on : les paliers manqués rattrapés en silence", NS:DB().companionEnabled == true
			and NS:HasStamp("level:20") and NS:JournalData().stamps["level:20"].retro == true)
		Check("[JRN] « carnet » vise le Compagnon de route, sans conflit", NS:FindModule("carnet").id == "companion"
			and not (NS.FindCheck and NS:FindCheck("carnet")))
		J.Reset(20)
		NS:DB().enabled = false
		J.Enter()
		Check("[JRN] addon coupé : aucun tampon", NS:JournalCounts().total == 0)
	end

	-- 1.11 Robustesse --------------------------------------------------------------------
	do
		Say("-- carnet : robustesse")
		J.Reset(20)
		_G.CombatLogGetCurrentEventInfo = function() error("boom") end
		J.Target("Creature-0-4378-0-12-61-00001A2B3C", "rare", "Thuros")
		J.Log("UNIT_DIED", nil, 0, "Creature-0-4378-0-12-61-00001A2B3C")
		local noRare = not NS:HasStamp("rare:61")
		_G.CombatLogGetCurrentEventInfo = saved.CombatLogGetCurrentEventInfo
		_G.GetInstanceInfo = nil
		J.W.instance = true
		local ok = pcall(J.Enter)
		_G.date = nil
		J.W.instance = false
		J.Map(1436)
		Check("[JRN] journal de combat illisible, sans GetInstanceInfo, sans date() : pas d'erreur (tampon sans date)", noRare
			and ok and NS:HasStamp("zone:1436") and NS:JournalData().stamps["zone:1436"].date == nil)
	end

	for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
	C_Map.GetAreaInfo = saved.GetAreaInfo
end

-- ============================================================================
-- 2. Fenêtre : allure, zones, garde-manger, Créature, objectif de zone
-- ============================================================================
do
	local W = {}
	function W.Reset()
		ResetWorld()
		if NS.journalFrame then NS.journalFrame:Hide() end
		NS.companionRT, NS.companionSession = nil, nil
		NS:CompanionData().tutoDone = true
		NS:DB().journalTracker = false
	end
	function W.Find(list, id)
		for _, entry in ipairs(list) do if entry.def.id == id then return entry end end
	end

	-- 2.1 Roue, Allure (ex-Collection) -----------------------------------------------------------
	-- Carnet 1.5.0 : la page Collection est retirée ; on porte apparences, cadres,
	-- fonds et ornements depuis la page Compagnon (« Son allure »).
	do
		Say("-- carnet : roue et allure")
		W.Reset()
		local data = NS:CompanionData()
		data.unlocked["app:frog"], data.unlocked["frame:copper"], data.unlocked["orn:ribbon"] = true, true, true
		data.appearance = "whelp_green"
		NS:ToggleJournal(true)
		local f = NS.journalFrame
		local gear = f.settingsButton
		local placed = gear and gear:IsShown() ~= false and select(2, gear:GetPoint()) == f.close
			and select(1, gear:GetPoint()) == "RIGHT"
		if NS.optionsFrame then NS.optionsFrame:Hide() end
		gear:Click()
		Check("[JRN] roue crantée à gauche du × : ouvre les réglages de QuestCompanion", placed and NS.optionsFrame ~= nil
			and NS.optionsFrame:IsShown())
		NS.optionsFrame:Hide()
		NS:ToggleJournal(true)
		f = NS.journalFrame
		local redirected = f.sections.collection == nil and (function()
			NS:SelectJournalKind("collection"); return f.kind == "evolution" and f.evo:IsShown()
		end)()
		local apps = NS:JournalCollection("app")
		Check("[COLL] plus d'onglet Collection (l'ancien nom mène au Compagnon) ; catalogue des apparences, l'équipée",
			redirected and #apps == #NS.COMPANION_APPEARANCES and W.Find(apps, "whelp_green").equipped
			and not W.Find(apps, "owl").owned)
		local evo = f.evo
		-- 2.14.0 : les apparences dans le panneau « Choisir… » (CompanionAllure.lua)
		evo.lookChoose:Click()
		local function Look(id)
			for _, cell in ipairs(NS.allurePanel.tiles) do if cell:IsShown() and cell.def and cell.def.id == id then return cell end end
		end
		local green, frog, owl = Look("whelp_green"), Look("frog"), Look("owl")
		Check("[COLL] allure : la portée en or, les verrouillées grisées", green and frog and owl and owl.locked
			and not frog.locked and green.selected and green.accent:IsShown() and green.accent.vertex[1] == NS.Theme.GOLD[1])
		local refused = NS:CompanionSetAppearance("owl") == nil
		owl:Click()
		Check("[COLL] verrouillée refusée (appel ou clic sur sa vignette)", refused and data.appearance == "whelp_green")
		frog:Click()
		Check("[COLL] clic sur la rainette : équipée", data.appearance == "frog" and W.Find(NS:JournalCollection("app"), "frog").equipped
			and Look("frog").selected)
		NS:AllureClose()
		evo.frameStyle:Choose("copper")
		Check("[COLL] cadres : cuivre équipé, verrouillé refusé", evo.frameStyle.value == "copper"
			and NS:CompanionCurrentStyle("frame").id == "copper" and evo.frameStyle:Choose("oak") == false
			and NS:CompanionCurrentStyle("frame").id == "copper")
		local function Ribbon()
			for _, button in ipairs(evo.orns) do if button:IsShown() and button.text.text == NS.L.COMP_ORN_RIBBON then return button end end
		end
		local worn = Ribbon() and NS:DB().companionOrnRibbon ~= false and W.Find(NS:JournalCollection("orn"), "ribbon").equipped
		Ribbon():Click()
		local removed = NS:DB().companionOrnRibbon == false and not W.Find(NS:JournalCollection("orn"), "ribbon").equipped
		Ribbon():Click()
		Check("[COLL] ornement possédé : porté, un clic l'enlève, un autre le remet", worn and removed
			and NS:DB().companionOrnRibbon == true)
		local base = W.Find(NS:JournalCollection("bg"), "night")
		Check("[COLL] fond de base : possédé d'office", base and base.owned and NS:JournalCosmeticSource(base) == "possédé d'office")
		f:Hide()
	end

	-- 2.2 Zones sans tranche connue : niveaux calculés, et toutes dans la liste ----------------
	do
		Say("-- carnet : tranches des zones")
		W.Reset()
		local creatures = NS.ZONE_CREATURES
		local kept = creatures[99001]
		local zone = {}
		for index = 1, 10 do zone[5000 + index] = { lvl = { 20 + index, 21 + index }, rank = 0 } end
		zone[5100] = { lvl = { 60, 60 }, rank = 1 }        -- un élite : écarté
		zone[5101] = { lvl = { 1, 1 }, rank = 0 }          -- un extrême bas
		creatures[99001] = zone
		NS.ZoneLevelCache[99001] = nil
		local range = NS:ZoneLevelRange(99001)
		Check("[ZONES] tranche calculée (normales, sans extrêmes ni élites) et son palier de coffre", range and range[1] == 21
			and range[2] == 30 and NS:ZoneTier(99001) == 2, range and (range[1] .. "-" .. range[2]))
		creatures[99001] = kept
		NS.ZoneLevelCache[99001] = nil
		local inList = false
		for _, z in ipairs(NS:JournalAllZones("all", "lvl")) do if z.id == 2482 then inList = true end end
		local forever = NS:ZoneLevelRange(2482)
		Check("[ZONES] zone de la table : sa tranche ; propre à Forever : une tranche, dans la liste ; Reflet-de-Lune ; inconnue : rien",
			NS:ZoneLevelRange(1413)[1] == 10 and NS:ZoneLevelRange(1413)[2] == 25 and forever and forever[1] >= 1 and inList
			and NS:ZoneLevelRange(1450) ~= nil and NS:ZoneLevelRange(424242) == nil)
	end

	-- 2.3 Garde-manger dans l'en-tête -----------------------------------------------------------------
	do
		Say("-- carnet : garde-manger")
		W.Reset()
		NS:TreatData().pantry.bonbon = 2
		NS:ToggleJournal(true)
		local f = NS.journalFrame
		Check("[JPAN] friandises dans l'en-tête : compteurs, vides grisées", f.pantry and f.pantry.biscuit and f.pantry.festin
			and f.pantry.bonbon.count.text == "2" and f.pantry.biscuit.count.text == "0" and f.pantry.biscuit.alpha < 1
			and f.pantry.bonbon.alpha == 1)
		NS:CompanionData().needs.mood = 30
		f.pantry.bonbon:Click()
		NS:TreatGrant("carte", { quiet = true })
		f.pantry.carte.scripts.OnEnter(f.pantry.carte)
		local tip = table.concat(_G.GameTooltip.lines or {}, " | ")
		f.pantry.carte.scripts.OnLeave(f.pantry.carte)
		Check("[JPAN] clic : donnée ; friandise gagnée : l'en-tête suit ; survol : nom, effet, nombre", NS:TreatCount("bonbon") == 1
			and NS:CompanionData().needs.mood == 100 and f.pantry.bonbon.count.text == "1" and f.pantry.carte.count.text == "1"
			and tip:find("Carte au trésor", 1, true) and tip:find("1 / 3", 1, true), tip)
		f:Hide()
	end

	-- 2.4 Créature, objectif de zone --------------------------------------------------------------------
	do
		Say("-- carnet : Créature, objectif de zone")
		W.Reset()
		NS:ToggleJournal(true)
		local f = NS.journalFrame
		f.sections.evolution:Click()
		-- pas encore de caractère : pas d'étiquette ; formé : son nom à côté du nom
		local none = NS:CompanionTrait() ~= nil or not f.evo.traitTag:IsShown()
		NS:PersonaData().formed = "curious"
		NS:RefreshJournal()
		local trait = NS:PersonaLabel(NS:CompanionTrait())
		Check("[JRNW] Créature : étiquette du caractère seulement une fois formé", none and trait and trait ~= ""
			and f.evo.traitTag:IsShown() and f.evo.traitTag.label.text == NS.Theme.Upper(trait), f.evo.traitTag.label.text)
		f:Hide()
		NS:OpenJournalFor({ id = "zone:1411", zoneID = 1411, source = "journal" })
		local opened = f:IsShown() and f.kind == "progress" and f.zoneID == 1411
		-- 2.10.0 : le clic ne referme que si la page cible est déjà là
		NS:OpenJournalFor({ id = "zone:1411", zoneID = 1411, source = "journal" })
		Check("[JRNW] objectif de zone : sa zone s'ouvre ; même page, même zone : le clic referme", opened and not f:IsShown())
		NS:ToggleJournal(true)
		NS:SelectJournalKind("menagerie")
		NS:OpenJournalFor({ id = "zone:1411", zoneID = 1411, source = "journal" })
		local moved = f:IsShown() and f.kind == "progress" and f.zoneID == 1411
		NS:OpenJournalFor({ id = "zone:1413", zoneID = 1413, source = "journal" })
		Check("[JRNW] autre page : il y va et reste ouvert ; même page, autre zone : il change de zone", moved
			and f:IsShown() and f.zoneID == 1413, f.kind)
		f:Hide()
		NS:OpenJournalFor({ id = "stage", kind = "stage", source = "companion" })
		Check("[JRNW] objectif du compagnon : Créature", f:IsShown() and f.kind == "evolution")
		f:Hide()
		local missing = {}
		for key in pairs(NS.JOURNAL_WINDOW_STRINGS.fr) do
			if NS.JOURNAL_WINDOW_STRINGS.en[key] == nil then missing[#missing + 1] = key end
		end
		Check("[JRNW] textes de la fenêtre : fr et en", #missing == 0, table.concat(missing, ", "))
	end
	ResetWorld()
end

-- ============================================================================
-- 3. Page Exploration / Complétion (JournalCompletion.lua), en dynamique
-- ============================================================================
do
	local saved, MOCKED = {}, { "IsInInstance", "GetRealZoneText", "UnitFactionGroup" }
	for _, name in ipairs(MOCKED) do saved[name] = rawget(_G, name) end
	saved.GetAreaInfo = C_Map.GetAreaInfo
	saved.ZONE_CREATURES, saved.ZONE_GATHERING = rawget(NS, "ZONE_CREATURES"), rawget(NS, "ZONE_GATHERING")
	saved.ZONE_QUESTS = rawget(NS, "ZONE_QUESTS")
	saved.OpenChest, saved.ActivityRows = NS.OpenChest, NS.JournalActivityRows
	NS.ZONE_CREATURES, NS.ZONE_GATHERING, NS.ZONE_QUESTS = nil, nil, nil
	_G.IsInInstance = function() return false, "none" end
	_G.GetRealZoneText = function() return "" end
	_G.UnitFactionGroup = function() return "Horde" end
	C_Map.GetAreaInfo = nil

	local MAPS = {
		[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 },
		[1415] = { mapID = 1415, name = "Royaumes de l'Est", parentMapID = 947, mapType = 2 },
		[947]  = { mapID = 947,  name = "Azeroth", parentMapID = 0, mapType = 1 },
		[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 },
		[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 1415, mapType = 3 },
	}

	local P = {}
	function P.Reset()
		ResetWorld()
		for id, info in pairs(MAPS) do Mock.world.maps[id] = info end
		Mock.world.mapID = 1413
		Mock.world.subzone = "Plaine"
		Mock.world.level = 27
		if NS.journalFrame then NS.journalFrame:Hide() end
		NS.journalFrame = nil
		NS:CompanionData().tutoDone = true
		NS:DB().journalTracker = false
	end
	function P.Stamp(kind, key, name)
		NS:JournalData().stamps[kind .. ":" .. key] = { id = kind .. ":" .. key, kind = kind, name = name or tostring(key), at = 0 }
	end
	function P.Row(pane, zoneID)
		for _, row in ipairs(pane.zones) do if row:IsShown() and row.zoneID == zoneID then return row end end
	end
	function P.Y(region) return select(5, region:GetPoint()) end

	-- 3.1 Enregistrement et chaînes -------------------------------------------------------------------
	do
		Say("-- carnet : Complétion, enregistrement")
		local def = NS.JOURNAL_PANES and NS.JOURNAL_PANES.progress
		Check("[PROG] page externe « progress » (champ prog), titre et sous-titre", def and def.field == "prog"
			and type(def.build) == "function" and type(def.refresh) == "function" and type(def.scroll) == "function"
			and NS.L[def.title] == "Exploration" and NS.L[def.subtitle]:find("paliers, coffres", 1, true) ~= nil)
		local gaps = StringGaps(NS.JOURNAL_PROGRESS_STRINGS)
		Check("[PROG] chaînes fr/en : mêmes clés, mêmes paramètres, tutoiement", #gaps == 0, table.concat(gaps, ", "))
	end

	-- 3.2 Ouverture : la zone d'ici, la liste des zones ----------------------------------------------
	P.Reset()
	P.Stamp("subzone", 380, "The Crossroads")       -- 1 village sur 3 aux Tarides (Horde)
	P.Stamp("zone", 1413, "Les Tarides")
	P.Stamp("zone", 1429, "Forêt d'Elwynn")
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	local pane = f.prog
	-- 2.11.0 : le filtre par défaut est « Pour moi » ; ces cas parcourent toutes les zones
	f.progFilter = "all"
	do
		Say("-- carnet : Complétion, ouverture")
		Check("[PROG] page construite, entrée « Exploration » au menu", pane ~= nil and pane.card ~= nil and #pane.zones > 10
			and #pane.items > 5 and f.sections.progress and f.sections.progress.text.text == "Exploration")
		NS:SelectJournalKind("progress")
		local shown = f.kind == "progress" and pane:IsShown() and not f.evo:IsShown() and f.header.title.text == "Exploration"
			and f.sections.progress.selected and not f.sections.evolution.selected
		NS:SelectJournalKind("zones"); local a = f.kind
		NS:SelectJournalKind("completion")
		Check("[PROG] page affichée seule, son entrée allumée ; anciens noms (zones, completion) y mènent", shown
			and a == "progress" and f.kind == "progress" and f.sections.completion == nil and f.sections.zones == nil,
			f.header.title.text)
		Check("[PROG] par défaut : la zone où tu es, « ici », ses niveaux", f.zoneID == 1413 and pane.name.text == "Les Tarides (ici)"
			and pane.levels.text == "niveaux 10-25", pane.name.text .. " / " .. pane.levels.text)
		local list = NS:JournalAllZones("all", "lvl")
		local ordered = true
		for index = 2, #pane.zones do
			local za, zb = pane.zones[index - 1].zone, pane.zones[index].zone
			if za and zb and za.lo > zb.lo then ordered = false end
		end
		local total = 0
		for _ in pairs(NS.ZONE_LEVELS) do total = total + 1 end
		Check("[PROG] toutes les zones du jeu, visitées ou non, par niveau, à partir du décalage", #list >= total
			and #list > #pane.zones and ordered and pane.zones[1].zoneID == list[(f.progOffset or 0) + 1].id)
		local here, ghost, other = P.Row(pane, 1413), nil, nil
		for _, row in ipairs(pane.zones) do
			if row:IsShown() and row.zone and not row.zone.seen then ghost = row end
			if row:IsShown() and row.zoneID ~= 1413 then other = row end
		end
		Check("[PROG] lignes : la choisie surlignée en or et « ici », les autres non ; jamais visitée en retrait « — »",
			here and here.selected and here.accent:IsShown() and here.accent.vertex[1] == NS.Theme.GOLD[1]
			and here.here:IsShown() and here.here.text == "ici" and other and not other.selected and not other.accent:IsShown()
			and ghost and ghost.alpha < 1 and ghost.percent.text == "—" and not ghost.bar:IsShown() and not ghost.here:IsShown())
		-- une seule part suivie (villages) : pas de %, on dit pourquoi
		Check("[PROG] une seule activité : « — » et pourquoi", pane.percent.text == "—" and pane.nopct:IsShown()
			and pane.nopct.text == NS.L.JRN_ZONE_NOPCT and not pane.bar:IsShown() and not pane.marks[1]:IsShown())
		local checked = pane.watch:IsShown() and pane.watch.checked == true and pane.watchLabel.text == NS.L.JRN_WATCH
		pane.watch:Click()
		local unchecked = NS:JournalIsWatched(1413) == false and pane.watch.checked == false
		pane.watch:Click()
		Check("[PROG] suivi à l'écran : coché pour la zone d'ici, un clic décoche, un autre recoche", checked and unchecked
			and NS:JournalIsWatched(1413) == true)
	end

	-- 3.3 Parts et liste -----------------------------------------------------------------------------
	do
		Say("-- carnet : Complétion, parts")
		local explore, craft, quests = pane.parts.explore, pane.parts.craft, pane.parts.quests
		Check("[PROG] trois cartes (Lieux 1/3 choisie, Métiers estompée sans métier, Quêtes grisée sans liste) ; plus de Combat",
			explore and craft and quests and pane.parts.combat == nil and explore.label.text == "Lieux"
			and craft.label.text == "Métiers" and quests.label.text == "Quêtes" and explore.count.text == "1/3"
			and explore.selected and explore.accent:IsShown() and not craft.selected and craft.dim and craft.alpha < 1
			and craft.count.text == "—" and quests.dim and quests.alpha < 1, explore.count.text)
		local first, last = pane.items[1], pane.items[3]
		Check("[PROG] liste « Villages : 1/3 » : à faire d'abord au trait, fait ensuite en losange plein, sans pagination",
			pane.head.text == "Villages : 1/3" and first.item and not first.item.done and first:IsShown()
			and first.status.clientRole == "diamondLine" and first.detail.text:find("à visiter", 1, true)
			and last.item and last.item.done and last.text.text == "The Crossroads" and last.status.clientRole == "diamond"
			and not pane.items[4]:IsShown() and pane.listPager.position.text == "" and pane.empty.text == "", pane.head.text)
		quests:Click()
		Check("[PROG] clic sur Quêtes : la liste change, pas de liste pour ce client", f.progPart == "quests" and quests.selected
			and not explore.selected and not pane.items[1]:IsShown() and pane.empty.text == NS.L.JRN_ACT_NO_QUESTS, pane.empty.text)
		craft:Click()
		Check("[PROG] Métiers : son message, et aucun métier repéré", f.progPart == "craft"
			and pane.empty.text == NS.L.JRN_ACT_EMPTY_craft .. "\n" .. NS.L.GATHER_PROFS_NONE, pane.empty.text)
		explore:Click()
		quests.onEnter(quests)
		local tip = table.concat(_G.GameTooltip.lines or {}, " ")
		quests.onLeave(quests)
		Check("[PROG] retour à Exploration ; survol de Quêtes : pas de liste pour ce client, sans Questie", f.progPart == "explore"
			and pane.items[1]:IsShown() and tip:find(NS.L.JRN_ACT_NO_QUESTS, 1, true) ~= nil and not tip:find("Questie", 1, true), tip)
	end

	-- 3.4 Pourcentage, paliers, coffre ---------------------------------------------------------------
	do
		Say("-- carnet : Complétion, paliers et coffre")
		local zone = {}
		for index = 1, 10 do
			zone[1000 + index] = { name = "Bête " .. string.format("%02d", index), type = "Bête", seen = true, killed = 1 }
		end
		zone[2000] = { name = "Chef kolkar", type = "Humanoïde", class = "elite", seen = true, killed = 1 }
		zone[2001] = { name = "Abeille", type = "Bête", seen = false, killed = 0 }
		NS:JournalData().bestiary = { [1413] = zone }
		-- QC 2.0 : le bestiaire ne compte plus dans le % (MenagerieCollection.lua) ;
		-- une seconde activité d'exploration (quêtes, 9/10) pour avoir un %
		P.fakeQuests = { id = "fakequests", label = "JRN_PART_quests", tab = "quests",
			Compute = function(_, zoneID) if zoneID == 1413 then return { have = 9, need = 10 } end end }
		NS.RegisterZonePart(P.fakeQuests)
		NS:RefreshJournal()
		local done = NS:ZoneCompletion(1413)
		local row = P.Row(pane, 1413)
		Check("[PROG] deux activités : grand % et barre, la liste suit ; zone avancée (50 franchi, pas 100)", done
			and #done.parts >= 2 and pane.percent.text == done.percent .. " %" and pane.bar:IsShown() and not pane.nopct:IsShown()
			and done.percent >= 50 and done.percent < 100 and row and row.percent.text == done.percent .. " %" and row.bar:IsShown(),
			pane.percent.text)
		local states = true
		for _, tile in ipairs(pane.marks) do
			local reached = done.percent >= tile.mark
			if tile.reached ~= reached or (tile.label.textColor[1] == NS.Theme.GOLD[1]) ~= reached
				or tile.accent:IsShown() ~= reached or not tile:IsShown() then states = false end
		end
		Check("[PROG] quatre paliers ; franchis en or", #pane.marks == 4 and states)
		local gifts = {}
		for index = 1, 4 do gifts[index] = pane.marks[index].gift.text end
		Check("[PROG] ce que donne chaque palier (friandises, appât, lasso, Festin, coffre)", pane.marks[1].label.text == "25 %"
			and table.concat(gifts, " | ") == "friandise + Appât savoureux | friandise + Lasso tressé | Festin + une aide de capture"
				.. " | coffre (palier 1)" and not pane.openChest:IsShown(), table.concat(gifts, " | "))
		NS:ChestData()[1413] = { tier = 1, name = "Les Tarides" }
		NS:RefreshJournal()
		local won = pane.openChest:IsShown() and pane.openChest.text.text == NS.L.JRN_OPEN_CHEST and pane.card.accent:IsShown()
			and pane.marks[4].gift.text == "coffre à ouvrir !"
		local opened
		NS.OpenChest = function(_, zoneID) opened = zoneID end
		pane.openChest:Click()
		NS.OpenChest = saved.OpenChest
		Check("[PROG] coffre gagné : « Ouvrir le coffre », liseré or ; clic : le coffre de cette zone", won and opened == 1413)
		NS:ChestData()[1413].opened = true
		NS:RefreshJournal()
		Check("[PROG] coffre ouvert : plus de bouton", not pane.openChest:IsShown() and pane.marks[4].gift.text == "coffre ouvert")
		NS:ChestData()[1413] = nil
	end

	-- 3.5 Bestiaire -> Créatures ---------------------------------------------------------------------
	do
		Say("-- carnet : Complétion, bestiaire")
		NS:RefreshJournal()
		local counts = NS:BestiaryCounts(1413)
		local expected = string.format("Bestiaire : %d/%d abattues (nommés %d/%d)", counts.killed, counts.seen,
			counts.namedKilled, counts.namedSeen)
		Check("[PROG] une ligne : abattues et nommés, bouton Créatures", pane.bestiary.text:find(expected, 1, true) == 1
			and pane.bestiary.text:find("Créatures", 1, true) and pane.toMen:IsShown() and pane.toMen.text.text == "Créatures",
			pane.bestiary.text)
		pane.toMen:Click()
		local men = f.kind == "menagerie" and f.menZone == 1413 and not pane:IsShown()
		NS:SelectJournalKind("progress")
		Check("[PROG] clic : les Créatures sur cette zone ; retour : même zone", men and f.kind == "progress" and f.zoneID == 1413)
	end

	-- 3.6 Choix d'une zone, il tient jusqu'à la fermeture ---------------------------------------------
	do
		Say("-- carnet : Complétion, choix de zone")
		for _ = 1, 40 do f.scripts.OnMouseWheel(f, 1) end
		local top = f.progOffset == 0
		local elwynn = P.Row(pane, 1429)
		if elwynn then elwynn:Click() end
		Check("[PROG] molette en butée haute, clic sur Elwynn : choisie (seule surlignée), la liste ne bouge pas", top
			and elwynn and f.zoneID == 1429 and f.zonePicked and pane.name.text == "Forêt d'Elwynn" and P.Row(pane, 1429).selected
			and not (P.Row(pane, 1413) and P.Row(pane, 1413).selected) and f.progOffset == 0, pane.name.text)
		Check("[PROG] Elwynn (Horde) : pas de village ami", pane.empty.text == NS.L.JRN_ACT_EMPTY_explore, pane.empty.text)
		Mock:Fire("ZONE_CHANGED")
		local held = f.zoneID == 1429
		f:Hide()
		NS:ToggleJournal(true)
		Check("[PROG] le choix tient tant que la fenêtre est ouverte ; rouverte : la zone d'ici", held and f.kind == "progress"
			and f.zoneID == 1413 and P.Row(pane, 1413) ~= nil, f.kind)
		NS:OpenJournalZone(1429)
		Check("[PROG] ouvrir une zone (objectif) : la Complétion sur elle", f.kind == "progress" and f.zoneID == 1429
			and P.Row(pane, 1429) and P.Row(pane, 1429).selected)
		-- le dernier onglet est retenu
		f.sections.menagerie:Click()
		f:Hide()
		NS:ToggleJournal(true)
		Check("[PROG] rouverte : le dernier onglet retenu", f.kind == "menagerie" and NS:DB().journalTab == "menagerie")
		NS:SelectJournalKind("progress")
	end

	-- 3.7 Molette et pagination ----------------------------------------------------------------------
	do
		Say("-- carnet : Complétion, molette")
		local list = NS:JournalAllZones("all", "lvl")
		local page = #pane.zones
		f.progOffset = 0
		NS:RefreshJournal()
		f.scripts.OnMouseWheel(f, -1)
		local step = f.progOffset == 3 and pane.zones[1].zoneID == list[4].id
		for _ = 1, 100 do NS:ScrollJournal(-1) end
		local bottom = f.progOffset == #list - page and pane.zones[page].zoneID == list[#list].id
			and pane.zonePager.position.text:find("/ " .. #list, 1, true) ~= nil
		f.scripts.OnMouseWheel(f, 1)
		Check("[PROG] molette : trois zones par cran, butée basse sur la dernière, position affichée", step and bottom
			and f.progOffset == #list - page - 3, f.progOffset)
		-- une longue liste : à faire d'abord, pagination, molette sur la liste
		NS.JournalActivityRows = function()
			local rows = { { header = true, name = "Villages : 8/20" } }
			for index = 1, 20 do rows[#rows + 1] = { name = "Lieu " .. index, done = index % 2 == 0, detail = "d" } end
			return rows
		end
		NS:RefreshJournal()
		local items, size = pane.items, #pane.items
		local order = true
		for _, line in ipairs(items) do if line.item.done then order = false end end
		Check("[PROG] longue liste : à faire d'abord, paginée", order and items[1].text.text == "Lieu 1"
			and items[2].text.text == "Lieu 3" and pane.listPager.position.text == "1-" .. size .. " / 20"
			and pane.listPager.down:IsShown() and not pane.listPager.up:IsShown(), pane.listPager.position.text)
		pane.listPager.down:Click()
		local paged = f.progItemOffset == size and items[1].text.text == f.progRows[size + 1].name
		local zoneOffset = f.progOffset
		pane.itemArea.IsMouseOver = function() return true end
		f.scripts.OnMouseWheel(f, 1)
		pane.itemArea.IsMouseOver = nil
		Check("[PROG] chevron : page suivante ; molette sur la liste : une ligne, les zones ne bougent pas", paged
			and f.progItemOffset == size - 1 and f.progOffset == zoneOffset, f.progItemOffset)
		pane.parts.craft:Click()
		Check("[PROG] changer de part remonte en haut", f.progItemOffset == 0)
		pane.parts.explore:Click()
		NS.JournalActivityRows = saved.ActivityRows
	end

	-- 3.8 Mise en page : rien ne déborde -------------------------------------------------------------
	do
		Say("-- carnet : Complétion, mise en page")
		local ui = NS.JournalUI
		local bad = {}
		local lastZone, lastItem = pane.zones[#pane.zones], pane.items[#pane.items]
		Expect(bad, "zones/pagination", P.Y(lastZone) - lastZone:GetHeight() > ui.PAGER_Y)
		Expect(bad, "liste/bestiaire", P.Y(lastItem) - lastItem:GetHeight() > ui.PAGER_Y)
		Expect(bad, "parts sous la carte", P.Y(pane.parts[1]) < P.Y(pane.card) - pane.card:GetHeight())
		Expect(bad, "liste sous les parts", P.Y(pane.items[1]) < P.Y(pane.parts[1]) - pane.parts[1]:GetHeight())
		local mark = pane.marks[4]
		Expect(bad, "paliers dans la carte", P.Y(mark) - mark:GetHeight() >= -pane.card:GetHeight()
			and select(4, mark:GetPoint()) + mark:GetWidth() <= pane.card:GetWidth())
		Expect(bad, "colonne de droite", select(4, pane.card:GetPoint()) - ui.PAD + pane.card:GetWidth() <= ui.INNER)
		Expect(bad, "textes coupés", pane.name.width and pane.bestiary.width and pane.zones[1].name.width
			and pane.zones[1].name.width < pane.zones[1]:GetWidth())
		Check("[PROG] mise en page : rien ne déborde ni ne se chevauche", #bad == 0, table.concat(bad, ", "))
	end

	-- 3.9 Aucune zone connue -------------------------------------------------------------------------
	do
		Say("-- carnet : Complétion, aucune zone")
		f:Hide()
		P.Reset()
		Mock.world.mapID = 947
		NS:ToggleJournal(true)
		f = NS.journalFrame
		pane = f.prog
		NS:SelectJournalKind("progress")
		Check("[PROG] hors zone et carnet vide : un message, pas de carte, la liste des zones reste", f.zoneID == nil
			and pane.none:IsShown() and pane.none.text == NS.L.JRN_ZONE_NONE and not pane.card:IsShown()
			and not pane.toMen:IsShown() and pane.zones[1]:IsShown(), tostring(f.zoneID))
		f:Hide()
	end

	for index = #NS.ZONE_PARTS, 1, -1 do if NS.ZONE_PARTS[index] == P.fakeQuests then table.remove(NS.ZONE_PARTS, index) end end
	for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
	C_Map.GetAreaInfo = saved.GetAreaInfo
	NS.ZONE_CREATURES, NS.ZONE_GATHERING, NS.ZONE_QUESTS = saved.ZONE_CREATURES, saved.ZONE_GATHERING, saved.ZONE_QUESTS
	NS.OpenChest, NS.JournalActivityRows = saved.OpenChest, saved.ActivityRows
	NS.journalFrame = nil
end
