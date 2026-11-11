-- Carnet de voyage : objectifs et suivi à l'écran « Carnet » (v1.25.0).
-- Sources (compagnon, villages de la zone, capitales, donjons, palier,
-- complétion de zone), tri, survol, masquage et réaffichage, repli, combat,
-- ancrage et position, module coupé, réglages, chaînes ; dans la fenêtre :
-- « Suivre à l'écran » d'une zone, tri / filtre des zones, Créatures inconnues,
-- page Compagnon (envies au survol). La page Complétion elle-même : journal.lua.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local function Expect(bad, label, ok) if not ok then bad[#bad + 1] = label end end

-- Mocks propres à ce fichier, restaurés à la fin
local saved, MOCKED = {}, { "IsInInstance", "GetInstanceInfo", "GetRealZoneText", "InCombatLockdown", "UnitFactionGroup",
	"date", "QuestWatchFrame", "ObjectiveTrackerFrame", "QuestObjectiveTracker" }
for _, name in ipairs(MOCKED) do saved[name] = rawget(_G, name) end
saved.GetAreaInfo = C_Map.GetAreaInfo
saved.NextUnlocks = rawget(NS, "CompanionNextUnlocks")
-- Ces tests couvrent le comportement 100 % dynamique (zone absente des tables
-- livrées, carte inconnue du client) : tables mises de côté, remises à la fin.
-- Les zones préremplies sont testées dans zone_data.lua.
saved.ZONE_CREATURES, saved.ZONE_GATHERING = rawget(NS, "ZONE_CREATURES"), rawget(NS, "ZONE_GATHERING")
saved.ZONE_QUESTS = rawget(NS, "ZONE_QUESTS")
NS.ZONE_CREATURES, NS.ZONE_GATHERING, NS.ZONE_QUESTS = nil, nil, nil

local K = { W = {} }
_G.IsInInstance = function() return K.W.instance == true, K.W.instance and "party" or "none" end
_G.GetInstanceInfo = function() return "Kalimdor", "none", 0, "", 0, 0, false, 0 end
_G.GetRealZoneText = function() return K.W.zone or "" end
_G.InCombatLockdown = function() return K.W.lockdown == true end
_G.UnitFactionGroup = function() return K.W.faction or "Horde" end
_G.date = function() return "03/11/2026" end
C_Map.GetAreaInfo = nil

local MAPS = {
	[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 },
	[1415] = { mapID = 1415, name = "Royaumes de l'Est", parentMapID = 947, mapType = 2 },
	[947]  = { mapID = 947,  name = "Azeroth", parentMapID = 0, mapType = 1 },
	[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 },
	[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 1415, mapType = 3 },
	[7777] = { mapID = 7777, name = "Île nouvelle", parentMapID = 1414, mapType = 3 },
}

-- Contrat du Compagnon (Companion.lua) : bouchonné ici
K.unlocks = {
	{ label = "Lanterne",   kind = "orn", stat = "subzone", have = 18, need = 25 },   -- 72 %
	{ label = "Feu follet", kind = "app", stat = "dungeon", have = 1,  need = 2 },    -- 50 %
	{ label = "Déjà là",    kind = "app", stat = "zone",    have = 5,  need = 5 },    -- atteint : exclu
	{ kind = "app", stat = "zone", have = 1, need = 9 },                              -- sans nom : ignoré
}
local function StubUnlocks(self) return K.unlocks end

function K.Reset(level, faction)
	ResetWorld()
	K.W = { faction = faction or "Horde" }
	for id, info in pairs(MAPS) do Mock.world.maps[id] = info end
	Mock.world.mapID = 1413
	Mock.world.subzone = "Plaine"
	Mock.world.level = level or 27
	NS.journalRares, NS.journalToasts, NS.journalChats = {}, {}, {}
	NS.journalToastHideAt = nil
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	if NS.journalTracker then NS.journalTracker:Hide() end
	NS.journalTracker = nil
	NS.journalTrackerCombat = nil
	NS.journalGroups, NS.journalGroupsFor = nil, nil
	NS.dungeonIndex = nil
	NS.CompanionNextUnlocks = StubUnlocks
	_G.QuestWatchFrame, _G.ObjectiveTrackerFrame, _G.QuestObjectiveTracker = nil, nil, nil
end
-- un tampon posé directement (sans STAMP) : l'état de départ d'un scénario
function K.Stamp(kind, key, name)
	NS:JournalData().stamps[kind .. ":" .. key] = { id = kind .. ":" .. key, kind = kind, name = name or tostring(key), at = 0 }
end
function K.Labels(list)
	local out = {}
	for _, goal in ipairs(list) do out[#out + 1] = goal.label .. " " .. goal.progress end
	return table.concat(out, " | ")
end
function K.Find(list, prefix)
	for _, goal in ipairs(list) do if goal.id:sub(1, #prefix) == prefix then return goal end end
end
function K.Lines()
	local tracker, out = NS.journalTracker, {}
	if not tracker then return "" end
	for _, line in ipairs(tracker.lines) do
		if line:IsShown() then out[#out + 1] = line.text.text .. " " .. line.progress.text end
	end
	return table.concat(out, " | ")
end
function K.Tip(region, script)
	_G.GameTooltip.lines = {}
	region:GetScript(script or "OnEnter")(region)
	return table.concat(_G.GameTooltip.lines or {}, " | ")
end

-- 1. Chaînes ----------------------------------------------------------------------
do
	Say("-- suivi du carnet : chaînes")
	local strings, gaps = NS.JOURNAL_TRACKER_STRINGS, {}
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
	for _, stat in ipairs({ "zone", "subzone", "capital", "dungeon", "rare", "level", "total" }) do
		Expect(gaps, "stat:" .. stat, strings.fr["JRN_STAT_" .. stat] ~= nil)
	end
	Expect(gaps, "titre", strings.en.JRN_TRK_TITLE == "Journal" and strings.fr.JRN_TRK_TITLE == "Carnet")
	Check("[TRK] chaînes fr/en : mêmes clés et paramètres, tutoiement, stats nommées, titre « Carnet » / « Journal »",
		NS.Loaded and NS.Loaded.JournalTracker and #gaps == 0, table.concat(gaps, ", "))
end

-- 2. Sources et tri -------------------------------------------------------------------
do
	Say("-- suivi du carnet : objectifs")
	K.Reset(27, "Horde")
	K.Stamp("subzone", 380, "The Crossroads")      -- 1 village sur 3 aux Tarides (Horde)
	K.Stamp("capital", 1637, "Orgrimmar")          -- 1 capitale sur 6
	local list = NS:JournalObjectives()
	Check("[TRK] tri : le plus proche du but d'abord", K.Labels(list) ==
		"Lanterne — villages 18/25 | Atteins le niveau 30 27/30 | Feu follet — donjons 1/2 | Villages de Les Tarides 1/3"
		.. " | Capitales 1/6 | Donjons de ton niveau 0/4",
		K.Labels(list))
	local lantern = K.Find(list, "comp:")
	Check("[TRK] compagnon : contrat lu tel quel, objectif atteint exclu, entrée sans nom ignorée", lantern
		and lantern.id == "comp:orn:Lanterne" and lantern.have == 18 and lantern.need == 25 and lantern.source == "companion"
		and lantern.kind == "orn" and not K.Labels(list):find("Déjà là", 1, true) and #list == 6, #list)
	local level = K.Find(list, "level:")
	Check("[TRK] palier : prochain palier, trié sur la tranche (27 entre 20 et 30)", level and level.id == "level:30"
		and math.abs(level.ratio - 0.7) < 1e-6, level and level.ratio)
	-- villages : la faction compte (Alliance aux Tarides : Ratchet seul, neutre) ; zone sans village : rien
	K.Reset(27, "Alliance")
	local villages = K.Find(NS:JournalObjectives(), "villages:")
	Mock.world.mapID = 7777
	Check("[TRK] villages : faction filtrée (Alliance : Ratchet seul) ; zone sans village : rien", villages
		and villages.progress == "0/1" and K.Find(NS:JournalObjectives(), "villages:") == nil, villages and villages.progress)
	-- village de Forever absent de la table (Falaath, 16636) : appris en passant
	local unknown = NS.JOURNAL_HUB_ZONE[16636] == nil and NS:JournalHubZone(16636) == nil
	Mock.world.subzone = "Falaath Village"
	Mock:Fire("ZONE_CHANGED")
	NS:JournalData().stamps["subzone:16636"] = nil
	villages = K.Find(NS:JournalObjectives(), "villages:7777")
	Check("[TRK] village de Forever hors table : zone apprise au passage, objectif de sa zone", unknown
		and NS:JournalHubZone(16636) == 7777 and NS:DB().journalHubZones[16636] == 7777 and villages
		and villages.progress == "0/1" and villages.label == "Villages de Île nouvelle", villages and villages.label)
	-- donjons : la plage de ton niveau (client Forever du harnais)
	K.Reset(20)
	local dungeons = K.Find(NS:JournalObjectives(), "dungeons:")
	local hint = dungeons and table.concat(dungeons.hint, " | ") or ""
	local a, b, c, d = hint:find("Ruins of Lordaeron (", 1, true), hint:find("Wailing Caverns (", 1, true),
		hint:find("Deadmines (", 1, true), hint:find("Shadowfang Keep (", 1, true)
	Check("[TRK] donjons : libellé court, ceux de ta tranche au survol, par niveau d'entrée, avec leur plage", dungeons
		and dungeons.label == "Donjons de ton niveau" and dungeons.progress == "0/4" and a and b and c and d
		and a < b and b < c and c < d and hint:find("%(%d+%-%d+%)") ~= nil, hint)
	K.Stamp("dungeon", "wc", "Wailing Caverns")
	dungeons = K.Find(NS:JournalObjectives(), "dungeons:")
	Check("[TRK] donjons : un tamponné sort de la liste, compté, identifiant stable", dungeons and dungeons.progress == "1/4"
		and not table.concat(dungeons.hint, " "):find("Wailing", 1, true) and dungeons.id == "dungeons:dm,lordaeron,sfk,wc",
		dungeons and dungeons.id)
	K.Reset(5)
	local low = K.Find(NS:JournalObjectives(), "dungeons:") == nil
	K.Reset(60)
	Check("[TRK] niveau 5 : aucun donjon ; niveau 60 : plus de palier", low and K.Find(NS:JournalObjectives(), "level:") == nil)
	-- sans contrat du Compagnon (ou contrat en panne) : rien d'inventé, les autres sources restent
	K.Reset(27)
	NS.CompanionNextUnlocks = nil
	local without = K.Find(NS:JournalObjectives(), "comp:") == nil and #NS:JournalObjectives() == 4
	NS.CompanionNextUnlocks = function() error("boom") end
	Check("[TRK] sans CompanionNextUnlocks ou en panne : aucune ligne compagnon, les autres sources restent", without
		and #NS:JournalObjectives() == 4, K.Labels(NS:JournalObjectives()))
	NS.CompanionNextUnlocks = StubUnlocks
	for _, id in ipairs({ 1657, 1537, 1519, 1637, 1638, 1497 }) do K.Stamp("capital", id) end
	Check("[TRK] capitales 6/6 : plus d'objectif", K.Find(NS:JournalObjectives(), "capitals") == nil)
end

-- 3. Le cadre « Carnet » ------------------------------------------------------------
do
	Say("-- suivi du carnet : cadre")
	K.Reset(27)
	K.Stamp("subzone", 380); K.Stamp("capital", 1637)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	local tracker = NS.journalTracker
	Check("[TRK] cadre affiché à l'entrée dans le monde, titre ambre « Carnet »", tracker and tracker:IsShown()
		and tracker.title.text.text == "Carnet" and tracker.title.text.textColor[1] == NS.Theme.GOLD[1])
	Check("[TRK] quatre lignes au plus, les plus proches ; la première en vedette (libellé court + unité)", K.Lines() ==
		"Lanterne 18/25 villages | Atteins le niveau 30 27/30 | Feu follet — donjons 1/2 | Villages de Les Tarides 1/3",
		K.Lines())
	local line, second = tracker.lines[1], tracker.lines[2]
	-- 2.10.0 : plus de mini-barre sur les secondaires (le compte suffit)
	Check("[TRK] vedette : bandeau du thème (liseré ambre), losange plein, barre ; secondaires : trait, sans barre, grisées",
		line.featured and line.chrome == "toast" and line.bg.vertex[1] == NS.Theme.WINDOW[1] and line.accent:IsShown()
		and line.accent.vertex[1] == NS.Theme.GOLD[1] and line.diamond.clientRole == "diamond"
		and math.abs(line.bar.ratio - 18 / 25) < 1e-6 and not second.featured and second.diamond.clientRole == "diamondLine"
		and second.bar == nil and second.progress.textColor[1] == NS.Theme.MUTED[1], line.bar and line.bar.ratio)
	local fullHeight = tracker.height

	-- survol : quoi faire, avec des noms
	local tip = _G.GameTooltip
	local text = K.Tip(tracker.lines[4])
	tracker.lines[4]:GetScript("OnLeave")(tracker.lines[4])
	Check("[TRK] survol villages : villages restants nommés, rappel des clics ; bulle fermée ensuite",
		text:find("Villages à visiter dans Les Tarides", 1, true) and text:find("Camp Taurajo", 1, true)
		and not text:find("The Crossroads", 1, true) and text:find("clic droit : masquer", 1, true) and not tip.shown, text)
	local comp, lvl = K.Tip(tracker.lines[1]), K.Tip(tracker.lines[2])
	tracker.lines[2]:GetScript("OnLeave")(tracker.lines[2])
	Check("[TRK] survol compagnon : ce que ça débloque et comment ; palier : niveaux restants", comp:find("ornement", 1, true)
		and comp:find("Villages à visiter", 1, true) and lvl:find("Encore 3 niveau", 1, true), comp .. " // " .. lvl)

	-- clic gauche : le carnet ; à nouveau : refermé
	NS.journalFrame = nil
	tracker.lines[1]:Click("LeftButton")
	local opened = NS.journalFrame and NS.journalFrame:IsShown() and NS.journalFrame.kind == "evolution"
	tracker.lines[1]:Click("LeftButton")
	Check("[TRK] clic sur un objectif du compagnon : carnet ouvert sur le Compagnon, second clic : refermé", opened
		and not NS.journalFrame:IsShown())

	-- rafraîchi sur STAMP, au changement de zone (Elwynn, Horde : pas de village ami)
	NS:JournalEarn("subzone", 378, "Camp Taurajo")
	local stamped = K.Lines():find("Villages de Les Tarides 2/3", 1, true)
	Mock.world.mapID = 1429
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	Check("[TRK] rafraîchi sur STAMP et au changement de zone", stamped and not K.Lines():find("Villages", 1, true)
		and K.Lines():find("Capitales", 1, true), K.Lines())
	Mock.world.mapID = 1413
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	-- rafraîchi à la montée de niveau, même si UnitLevel est en retard
	Mock:Fire("PLAYER_LEVEL_UP", 28)
	local up = K.Lines():find("niveau 30 28/30", 1, true)
	Mock:Fire("ZONE_CHANGED")
	Check("[TRK] montée de niveau : palier à jour (niveau de l'événement, oublié après)", up
		and K.Lines():find("niveau 30 27/30", 1, true), K.Lines())
	Mock.world.level = 28

	-- masquer d'un clic droit
	local first = tracker.lines[1].goal.id
	tracker.lines[1]:Click("LeftButton")
	local kept = tracker.lines[1].goal.id == first
	tracker.lines[1]:Click("RightButton")
	Mock:Fire("ZONE_CHANGED")
	Check("[TRK] clic droit (pas gauche) : objectif masqué par personnage, le suivant monte, le reste au rafraîchissement",
		kept and tracker.lines[1].goal.id ~= first and not K.Lines():find("Lanterne", 1, true)
		and NS:JournalData().dismissed[first] == true and K.Lines():find("Capitales", 1, true), K.Lines())
	-- trois masqués sur six : trois lignes, jamais un masqué pour boucher le trou
	local secondId = tracker.lines[1].goal.id
	tracker.lines[1]:Click("RightButton")
	local third = tracker.lines[1].goal.id
	tracker.lines[1]:Click("RightButton")
	local three = not tracker.lines[4]:IsShown() and tracker.lines[3]:IsShown() and not K.Lines():find("Lanterne", 1, true)
	local smaller = tracker.height < fullHeight
	NS:JournalDismiss(secondId, false)
	NS:JournalDismiss(third, false)
	Check("[TRK] trois masqués : trois lignes, hauteur qui suit ; remis : de retour", three and smaller
		and tracker.lines[4]:IsShown() and not NS:JournalData().dismissed[secondId] and tracker.height == fullHeight,
		tracker.height .. "/" .. fullHeight)

	-- repli
	tracker.title:Click()
	local folded = NS:DB().journalTrackerCollapsed == true and K.Lines() == ""
		and tracker.title.text.text == "Carnet (4) · 1 masqué" and tracker.height < fullHeight
	Mock:Fire("ZONE_CHANGED")
	local stays = K.Lines() == "" and tracker:IsShown()
	tracker.title:Click()
	Check("[TRK] clic sur le titre : replié (compte au titre), le reste au rafraîchissement ; second clic : déplié", folded
		and stays and NS:DB().journalTrackerCollapsed == false and tracker.lines[4]:IsShown(), tracker.title.text.text)

	-- 2.10.0 : les masqués se voient au titre et se réaffichent d'un clic droit
	local oneHidden = NS:JournalHiddenCount() == 1 and tracker.title.text.text == "Carnet · 1 masqué"
	local tipLines = {}
	local savedTip = rawget(_G, "GameTooltip")
	_G.GameTooltip = { SetOwner = function() end, ClearLines = function() end, Show = function() end, Hide = function() end,
		AddLine = function(_, t) tipLines[#tipLines + 1] = t end }
	tracker.title:GetScript("OnEnter")(tracker.title)
	_G.GameTooltip = savedTip
	tracker.lines[1]:Click("RightButton")
	Check("[TRK] masqués comptés au titre (pluriel), infobulle du titre : les trois gestes", oneHidden
		and tracker.title.text.text == "Carnet · 2 masqués" and tipLines[1] == NS.L.JRN_TRK_TIP_TITLE
		and tipLines[2] == NS.L.JRN_TRK_TIP_CLICK and tipLines[3] == NS.L.JRN_TRK_TIP_RESTORE, tracker.title.text.text)
	local printed, oldPrint = {}, NS.Print
	NS.Print = function(_, msg) printed[#printed + 1] = msg end
	tracker.title:Click("RightButton")
	NS.Print = oldPrint
	Check("[TRK] clic droit sur le titre : tout revient, le chat le dit", NS:JournalHiddenCount() == 0
		and tracker.title.text.text == "Carnet" and printed[1] == "2 objectifs réaffichés."
		and NS:DB().journalTrackerCollapsed == false, printed[1])
	-- tout masqué : le titre reste, seul ; le réglage « Réafficher » fait revenir
	for _ = 1, 20 do
		if not tracker.lines[1]:IsShown() then break end
		tracker.lines[1]:Click("RightButton")
	end
	local all = NS:JournalHiddenCount()
	local alone = tracker:IsShown() and not tracker.lines[1]:IsShown() and tracker.title.text.text == "Carnet · " .. all .. " masqués"
	NS:RunOptionAction("journalTrackerRestore")
	Check("[TRK] tout masqué : le titre seul avec le compte ; « Réafficher » : tout revient", alone
		and NS:JournalHiddenCount() == 0 and tracker.lines[4]:IsShown(), tracker.title.text.text)

	-- combat
	Mock:Fire("PLAYER_REGEN_DISABLED")
	local hidden = not tracker:IsShown()
	NS:JournalEarn("subzone", 392, "Ratchet")
	local stillHidden = not tracker:IsShown()
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Check("[TRK] combat : masqué (un tampon ne le fait pas réapparaître), revient à la sortie", hidden and stillHidden
		and tracker:IsShown())
	K.W.lockdown = true
	NS:RefreshJournalTracker()
	local locked = not tracker:IsShown()
	K.W.lockdown = false
	NS:DB().journalTrackerCombat = false
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Check("[TRK] verrou de combat sans événement (/reload) : masqué ; « Masquer en combat » coupé : reste affiché", locked
		and tracker:IsShown())
	Mock:Fire("PLAYER_REGEN_ENABLED")
	NS:DB().journalTrackerCombat = true

	-- rien à suivre : pas de titre seul
	K.Reset(60)
	NS.CompanionNextUnlocks = nil
	for _, id in ipairs({ 1657, 1537, 1519, 1637, 1638, 1497 }) do K.Stamp("capital", id) end
	for key in pairs(NS.DUNGEONS) do K.Stamp("dungeon", key) end
	Mock.world.mapID = 7777
	NS:RefreshJournalTracker()
	Check("[TRK] aucun objectif : cadre caché", not (NS.journalTracker and NS.journalTracker:IsShown()))
end

-- 3 bis. Complétion de zone ----------------------------------------------------------
do
	Say("-- suivi du carnet : complétion de zone")
	K.Reset(27)
	K.Stamp("subzone", 380, "The Crossroads")            -- villages des Tarides : 1/3
	Check("[ZONE] villages seuls : complétion calculée, pas d'objectif dédié",
		NS:ZoneCompletion(1413) and NS:ZoneCompletion(1413).percent == 33
		and K.Find(NS:JournalObjectives(), "zone:") == nil, NS:ZoneCompletion(1413) and NS:ZoneCompletion(1413).percent)
	-- une deuxième part (comme le bestiaire) : 1 espèce sur 4 ; une part en panne
	local fake = { id = "fake", label = "Bestiaire", Compute = function(_, zoneID)
		if zoneID ~= 1413 then return nil end
		return { have = 1, need = 4, hint = { "  · Sanglier" } }
	end }
	NS.RegisterZonePart(fake)
	local broken = { id = "broken", Compute = function() error("boom") end }
	NS.RegisterZonePart(broken)
	local done = NS:ZoneCompletion(1413)
	Check("[ZONE] parts à poids égal ((1/3 + 1/4) / 2 = 29 %), part en panne ignorée, autre zone : rien", done
		and done.percent == 29 and #done.parts == 2 and NS:ZoneCompletion(1429) == nil, done and done.percent)
	local goal = K.Find(NS:JournalObjectives(), "zone:1413")
	local hint = goal and table.concat(goal.hint, " | ") or ""
	Check("[ZONE] objectif « Exploration : Les Tarides » en %, survol : chaque part puis la plus simple à finir", goal
		and goal.label == "Exploration : Les Tarides" and goal.progress == "29 %" and hint:find("Villages : 1/3", 1, true)
		and hint:find("Bestiaire : 1/4", 1, true) and hint:find("Le plus simple pour avancer — Villages", 1, true)
		and hint:find("Camp Taurajo", 1, true), hint)
	-- le suivi : la complétion remplace ses parts ; 2.10.0 : en secondaire, le nom de la zone seul
	NS:RefreshJournalTracker()
	local lines = K.Lines()
	local zoneLine
	for _, l in ipairs(NS.journalTracker.lines) do if l.goal and l.goal.id == "zone:1413" then zoneLine = l end end
	Check("[ZONE] suivi : complétion affichée, villages absorbés (ils restent dans les objectifs)", zoneLine
		and zoneLine.text.text == (zoneLine.featured and "Exploration : Les Tarides" or "Les Tarides")
		and goal.brief == "Les Tarides" and not lines:find("Villages de Les Tarides", 1, true)
		and K.Find(NS:JournalObjectives(), "villages:1413") ~= nil, lines)
	NS:JournalDismiss("zone:1413", true)
	Check("[ZONE] complétion masquée : ses parts reviennent dans le suivi", K.Lines():find("Villages de Les Tarides", 1, true), K.Lines())
	NS:JournalDismiss("zone:1413", false)
	K.Stamp("zone", 1413, "Les Tarides")
	local item
	for _, entry in ipairs(NS:JournalItems("zone")) do if entry.id == "zone:1413" then item = entry end end
	Check("[ZONE] onglet Zones : pourcentage affiché", item and item.detail:find("29 %", 1, true), item and item.detail)
	fake.Compute = function() return { have = 4, need = 4 } end
	for _, entry in pairs(NS:JournalHubGroups()) do
		if NS:JournalHubZone(entry.areaID) == 1413 then K.Stamp("subzone", entry.areaID) end
	end
	Check("[ZONE] zone finie : 100 %, plus d'objectif", NS:ZoneCompletion(1413).percent == 100
		and K.Find(NS:JournalObjectives(), "zone:") == nil, NS:ZoneCompletion(1413).percent)
	for index = #NS.ZONE_PARTS, 1, -1 do
		if NS.ZONE_PARTS[index] == fake or NS.ZONE_PARTS[index] == broken then table.remove(NS.ZONE_PARTS, index) end
	end
end

-- 4. Ancrage, position ----------------------------------------------------------------
do
	Say("-- suivi du carnet : ancrage et position")
	K.Reset(27)
	_G.QuestWatchFrame = CreateFrame("Frame", "QuestWatchFrame", UIParent)
	QuestWatchFrame:Show()
	NS:RefreshJournalTracker()
	local tracker = NS.journalTracker
	local p = tracker.lastPoint
	Check("[TRK] Era : sous QuestWatchFrame", tracker.anchoredTo == "QuestWatchFrame" and p.relTo == QuestWatchFrame
		and p.point == "TOPRIGHT" and p.relPoint == "BOTTOMRIGHT", tracker.anchoredTo)
	QuestWatchFrame:Hide()
	if QuestWatchFrame.hooks and QuestWatchFrame.hooks.OnHide then QuestWatchFrame.hooks.OnHide(QuestWatchFrame) end
	p = tracker.lastPoint
	local top = p.relTo == QuestWatchFrame and p.relPoint == "TOPRIGHT"
	QuestWatchFrame:Show()
	if QuestWatchFrame.hooks and QuestWatchFrame.hooks.OnShow then QuestWatchFrame.hooks.OnShow(QuestWatchFrame) end
	Check("[TRK] suivi de Blizzard caché : prend sa place en haut ; réaffiché : de nouveau dessous", top
		and tracker.lastPoint.relPoint == "BOTTOMRIGHT")

	-- glisser : position retenue, gardée au rafraîchissement et au /reload
	tracker.title.scripts.OnDragStart(tracker.title)
	local moving = tracker.isMoving == true
	tracker:ClearAllPoints()
	tracker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -200)
	tracker.title.scripts.OnDragStop(tracker.title)
	local point = NS:DB().journalTrackerPoint
	Check("[TRK] glisser par le titre : position sauvegardée", moving and point and point.point == "TOPLEFT" and point.x == 300
		and point.y == -200 and tracker.isMoving == false)
	NS:RefreshJournalTracker()
	local kept = tracker.lastPoint.x == 300 and tracker.anchoredTo == "saved"
	NS.journalTracker = nil
	NS:RefreshJournalTracker()
	tracker = NS.journalTracker
	Check("[TRK] déplacé : ne revient pas sous Blizzard ; /reload : position restaurée", kept
		and tracker.lastPoint.point == "TOPLEFT" and tracker.lastPoint.x == 300 and tracker.lastPoint.relTo == UIParent)
	Mock:Reset()
	NS:RunOptionAction("journalTrackerReset")
	Check("[TRK] réinitialiser : position oubliée, de nouveau sous Blizzard, confirmé dans le chat",
		NS:DB().journalTrackerPoint == nil and tracker.anchoredTo == "QuestWatchFrame" and tracker.lastPoint.relTo == QuestWatchFrame
		and Mock:Output():find("Suivi du carnet remis", 1, true), Mock:Output())

	-- Forever (client moderne) : ObjectiveTrackerFrame, puis QuestObjectiveTracker ; le visible d'abord
	local bad = {}
	_G.QuestWatchFrame = nil
	_G.ObjectiveTrackerFrame = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent)
	ObjectiveTrackerFrame:Show()
	NS:PlaceJournalTracker()
	Expect(bad, "ObjectiveTrackerFrame", tracker.anchoredTo == "ObjectiveTrackerFrame" and tracker.lastPoint.relTo == ObjectiveTrackerFrame)
	_G.ObjectiveTrackerFrame = nil
	_G.QuestObjectiveTracker = CreateFrame("Frame", "QuestObjectiveTracker", UIParent)
	QuestObjectiveTracker:Show()
	NS:PlaceJournalTracker()
	Expect(bad, "QuestObjectiveTracker", tracker.anchoredTo == "QuestObjectiveTracker")
	_G.QuestWatchFrame = CreateFrame("Frame", "QuestWatchFrame", UIParent)   -- caché (mock : Hide par défaut)
	NS:PlaceJournalTracker()
	Expect(bad, "visible d'abord", tracker.anchoredTo == "QuestObjectiveTracker")
	Check("[TRK] Forever : sous ObjectiveTrackerFrame, repli sur QuestObjectiveTracker, le suivi visible d'abord", #bad == 0,
		table.concat(bad, ", ") .. " -> " .. tostring(tracker.anchoredTo))
	-- aucun suivi de Blizzard (Questie l'a remplacé, client inconnu) : à droite
	_G.QuestWatchFrame, _G.QuestObjectiveTracker = nil, nil
	NS:PlaceJournalTracker()
	p = tracker.lastPoint
	Check("[TRK] sans suivi de Blizzard : à droite de l'écran", tracker.anchoredTo == "UIParent" and p.relTo == UIParent
		and p.point == "TOPRIGHT" and p.x < 0 and p.y < 0, tostring(p.x) .. "," .. tostring(p.y))
	-- un « suivi » qui refuse l'ancre : repli, pas d'erreur ; globale bizarre : ignorée
	local refusing = CreateFrame("Frame", "QuestWatchFrame", UIParent)
	refusing:Show()
	_G.QuestWatchFrame = refusing
	local realSetPoint = tracker.SetPoint
	tracker.SetPoint = function(self, pt, rel, ...)
		if rel == refusing then error("Cannot anchor to itself") end
		return realSetPoint(self, pt, rel, ...)
	end
	local ok = pcall(NS.PlaceJournalTracker, NS)
	tracker.SetPoint = realSetPoint
	_G.QuestWatchFrame = "pas un cadre"
	Check("[TRK] ancre refusée : repli sur l'écran sans erreur ; globale QuestWatchFrame bizarre : ignorée", ok
		and tracker.anchoredTo == "UIParent" and NS:BlizzardQuestTracker() == nil)
	_G.QuestWatchFrame = nil
end

-- 5. Module coupé, réglages -----------------------------------------------------------
do
	Say("-- suivi du carnet : module et réglages")
	K.Reset(27)
	NS:RefreshJournalTracker()
	local tracker = NS.journalTracker
	local shown = tracker:IsShown()
	NS:HandleCommand("module carnet off")
	local off = not tracker:IsShown()
	Mock:Fire("ZONE_CHANGED")
	Check("[TRK] /r2q module carnet off : suivi caché, même aux événements", shown and off and not tracker:IsShown())
	NS:HandleCommand("module carnet on")
	local on = tracker:IsShown()
	NS:DB().enabled = false
	NS:RefreshJournalTracker()
	Check("[TRK] module rallumé : de retour ; addon coupé : caché", on and not tracker:IsShown())
	NS:DB().enabled = true

	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("journal")
	local page = NS.optionsFrame.pages.journal
	local rows = {}
	for _, row in ipairs(page.rows) do if row.def then rows[row.def.key] = row end end
	Check("[TRK] réglages « Suivi à l'écran », « Masquer en combat », « Réinitialiser la position », page lisible en entier",
		rows.journalTracker and rows.journalTracker.label.text == "Suivi à l'écran" and rows.journalTrackerCombat
		and rows.journalTrackerCombat.label.text == "Masquer en combat" and rows.journalTrackerReset
		and rows.journalTrackerReset.label.text == "Réinitialiser la position du suivi"
		and #NS:OptionsUnreachable(page.id) == 0, table.concat(NS:OptionsUnreachable(page.id), ", "))
	rows.journalTracker:Click()
	local cut = NS:DB().journalTracker == false and not tracker:IsShown()
	rows.journalTracker:Click()
	Check("[TRK] interrupteur : coupé = caché tout de suite, rallumé = de retour", cut and NS:DB().journalTracker == true
		and tracker:IsShown())
	NS:DB().journalTrackerPoint = { point = "CENTER", relPoint = "CENTER", x = 1, y = 2 }
	rows.journalTrackerReset:Click()
	Check("[TRK] ligne « Réinitialiser » : position oubliée", NS:DB().journalTrackerPoint == nil)
	NS.optionsFrame:Hide()
	NS.optionsFrame = nil
end

-- 6. Fenêtre : suivre une zone, zones, Créatures, Compagnon ---------------------------
do
	Say("-- carnet : suivre une zone, Créatures, Compagnon")
	K.Reset(27)
	K.Stamp("subzone", 380, "The Crossroads"); K.Stamp("capital", 1637, "Orgrimmar")
	K.Stamp("zone", 1413, "Les Tarides")
	NS:DB().journalTracker = false
	-- QC 2.0 : le bestiaire ne compte plus dans le % (MenagerieCollection.lua) : une part
	-- d'exploration de test (quêtes) ; le bestiaire garde sa ligne et ses Créatures
	K.fakeQuests = { id = "fakequests", label = "JRN_PART_quests", tab = "quests", Compute = function(_, zoneID)
		if zoneID == 1413 then return { have = 1, need = 4 } end
		if zoneID == 1429 and K.fake1429 then return { have = 0, need = 1 } end
	end }
	NS.RegisterZonePart(K.fakeQuests)
	local zone = {}
	for index = 1, 40 do
		zone[1000 + index] = { name = "Bête " .. string.format("%02d", index), type = "Bête", seen = true, killed = index <= 4 and 1 or 0 }
	end
	zone[2000] = { name = "Chef kolkar", type = "Humanoïde", class = "elite", seen = true, killed = 0 }
	zone[2001] = { name = "Abeille", type = "Bête", seen = false, killed = 0 }
	NS:JournalData().bestiary = { [1413] = zone }
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	NS:SelectJournalKind("completion")
	local prog = f.prog

	-- Créatures : les espèces apprises, une jamais croisée inconnue « ??? »
	prog.toMen:Click()
	local men = f.men
	local list = NS:MenagerieList({ zone = 1413 })
	local chief, bee
	for _, entry in ipairs(list) do
		if entry.npc == 2000 then chief = entry end
		if entry.npc == 2001 then bee = entry end
	end
	Check("[WIN] Créatures ouvertes sur la zone : espèces apprises connues, jamais croisée inconnue", f.kind == "menagerie"
		and men:IsShown() and f.menZone == 1413 and men.zone:GetValue() == 1413 and chief and chief.known
		and chief.class == "elite" and bee and not bee.known)
	local beeCell
	for _, cell in ipairs(men.items) do if cell.entry and cell.entry.npc == 2001 then beeCell = cell end end
	if not beeCell then
		NS:SelectJournalKind("menagerie")
		f.menState = "tokill"
		NS:RefreshJournal()
		for _ = 1, 30 do
			for _, cell in ipairs(men.items) do if cell.entry and cell.entry.npc == 2001 then beeCell = cell end end
			if beeCell then break end
			NS:ScrollJournal(-1)
		end
	end
	-- la ligne montre sa fiche par HookScript (le mock range le crochet dans .hooks)
	if beeCell then (beeCell.hooks and beeCell.hooks.OnEnter or beeCell.scripts.OnEnter)(beeCell) end
	Check("[WIN] jamais croisée : « ??? », sa fiche dit comment la trouver", beeCell and beeCell.label.text == "???"
		and men.preview.title.text == "???"
		and table.concat({ men.preview.lines[1].text or "", men.preview.lines[2].text or "", men.preview.lines[3].text or "" }, " ")
			:find(NS.L.JRN_MEN_NEVER, 1, true) ~= nil, beeCell and beeCell.label.text)
	f.menState = "all"
	NS:OpenJournalZone(1413)

	-- tri et filtre des zones : plus de puces sur la page (liste par niveau), la donnée reste
	K.Stamp("zone", 1429, "Forêt d'Elwynn")
	local byPct, onlyKa = NS:JournalAllZones("all", "pct"), true
	for _, z in ipairs(NS:JournalAllZones("ka", "lvl")) do if z.continent ~= "ka" then onlyKa = false end end
	Check("[ZONES] par niveau (1-10 d'abord), par % (la plus avancée d'abord), filtre Kalimdor",
		NS:JournalAllZones("all", "lvl")[1].lo == 1 and byPct[1] and byPct[1].id == 1413 and onlyKa, byPct[1] and byPct[1].id)

	-- suivre à l'écran : la zone d'ici d'office, une autre si cochée
	local small = {}
	for index = 1, 14 do small[1000 + index] = zone[1000 + index] end
	small[2000] = zone[2000]
	NS:JournalData().bestiary = { [1413] = small }
	NS:DB().journalTracker = true
	f.zonePicked, f.zoneID = nil, nil
	NS:RefreshJournal()
	local checked = prog.watch.checked == true and prog.watchLabel.text == "Suivre à l'écran"
	NS:RefreshJournalTracker()
	Check("[WATCH] zone d'ici : cochée d'office, sa complétion dans le suivi", checked
		and K.Lines():find("Les Tarides 29 %", 1, true), K.Lines())
	prog.watch:Click()
	Check("[WATCH] décochée : retenue, la zone et ses parts quittent le suivi, les objectifs restent calculés",
		NS:JournalData().watch[1413] == false and prog.watch.checked == false and not K.Lines():find("Les Tarides", 1, true)
		and K.Find(NS:JournalObjectives(), "zone:1413") ~= nil, K.Lines())
	NS:JournalDismiss("zone:1413", true)
	NS:JournalDismiss("villages:1413", true)
	prog.watch:Click()
	Check("[WATCH] recochée : de retour, les objectifs masqués avant réactivés", K.Lines():find("Les Tarides 29 %", 1, true)
		and not NS:JournalData().dismissed["zone:1413"] and not NS:JournalData().dismissed["villages:1413"], K.Lines())
	K.fake1429 = true
	NS:SelectJournalZone(1429)
	local otherOff = prog.watch.checked == false and not K.Lines():find("Elwynn", 1, true)
	prog.watch:Click()
	prog.watch.scripts.OnEnter(prog.watch)
	local why = table.concat(_G.GameTooltip.lines or {}, " ")
	prog.watch.scripts.OnLeave(prog.watch)
	Check("[WATCH] autre zone : décochée d'office ; cochée : dans le suivi, même avec une seule activité ; survol expliqué",
		otherOff and NS:JournalIsWatched(1429) and K.Lines():find("Exploration : Forêt d'Elwynn", 1, true)
		and why:find("bloc", 1, true), K.Lines())
	NS:JournalSetWatched(1429, false)
	NS:SelectJournalZone(1413)
	NS:DB().journalTracker = false

	-- Compagnon (ex-Évolution)
	f.sections.evolution:Click()
	local evo = f.evo
	Check("[WIN] Compagnon : section seule, étape, prochain objectif, 4 envies avec barres, son allure, pas de coffre",
		evo:IsShown() and not prog:IsShown() and f.kind == "evolution" and evo.look.text:find("étape", 1, true)
		and evo.next.text:find("niveau", 1, true) and #evo.needs == 4 and evo.needs[1].label.text == "Faim"
		and evo.needs[1].value.text:find("%", 1, true) and evo.looksTitle.raw and evo.looksTitle.raw:find("Son allure", 1, true)
		and evo.looksTitle.raw:find("apparence", 1, true) and not evo.openChest:IsShown(), evo.look.text)
	-- survol d'une envie : quoi faire pour la remplir
	local data = NS:CompanionData()
	data.needs.hunger, data.needs.mood = 40, 85
	local bad = {}
	for index, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do
		local row = evo.needs[index]
		local text = K.Tip(row.hover)
		row.hover.scripts.OnLeave(row.hover)
		Expect(bad, key, row.key == key and text:find(NS.L["COMP_NEED_" .. key], 1, true) and text:find(NS.L.JRN_NEED_TIP_HOW, 1, true)
			and text:find(NS.L["JRN_NEED_" .. key .. "_1"], 1, true) and #_G.GameTooltip.lines >= 5)
	end
	Check("[WIN] chaque envie au survol : nom, valeur, quoi faire", #bad == 0, table.concat(bad, ", "))
	local hunger, mood = K.Tip(evo.needs[1].hover), K.Tip(evo.needs[3].hover)
	Check("[WIN] envie basse : ce qu'il manque pour qu'elle compte ; comblée : dite comblée", hunger:find("Faim : 40 %", 1, true)
		and hunger:find("Encore 30 %", 1, true) and hunger:find("mange ou bois", 1, true) and mood:find("Moral : 85 %", 1, true)
		and mood:find("Comblée", 1, true) and mood:find("caresse-le", 1, true), hunger .. " // " .. mood)
	local missing = {}
	for key, count in pairs(NS.NEED_TIP_LINES) do
		for index = 1, count do
			local name = "JRN_NEED_" .. key .. "_" .. index
			if NS.L[name] == name or NS.JOURNAL_WINDOW_STRINGS.en[name] == nil then missing[#missing + 1] = name end
		end
	end
	Check("[WIN] conseils des envies en français et en anglais", #missing == 0, table.concat(missing, ", "))
	-- « comment ça marche » : l'infobulle des étapes
	_G.GameTooltip.lines = {}
	evo.stepsHover.scripts.OnEnter(evo.stepsHover)
	local how = _G.GameTooltip.lines or {}
	evo.stepsHover.scripts.OnLeave(evo.stepsHover)
	Check("[WIN] Compagnon : comment ça marche (au survol des étapes)", how[1] == "Comment ça marche"
		and tostring(how[3]):find("70", 1, true) and tostring(how[4]):find("100 %", 1, true)
		and not tostring(how[4]):find("%%", 1, true), table.concat(how, " | "))
	f:Hide()
	NS:JournalData().bestiary = nil
	K.fake1429 = nil
	for index = #NS.ZONE_PARTS, 1, -1 do if NS.ZONE_PARTS[index] == K.fakeQuests then table.remove(NS.ZONE_PARTS, index) end end
end

-- ipairs sur la liste : une globale absente avant (nil) doit le redevenir
for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
C_Map.GetAreaInfo = saved.GetAreaInfo
NS.CompanionNextUnlocks = saved.NextUnlocks
NS.ZONE_CREATURES, NS.ZONE_GATHERING = saved.ZONE_CREATURES, saved.ZONE_GATHERING
NS.ZONE_QUESTS = saved.ZONE_QUESTS
if NS.journalTracker then NS.journalTracker:Hide() end
