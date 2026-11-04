-- Carnet de voyage : objectifs et suivi à l'écran « Carnet » (v1.25.0).
-- Sources (compagnon, villages de la zone, capitales, donjons, palier), tri,
-- masquage, rafraîchissement, repli, combat, position, ancrage, module coupé,
-- onglet « Objectifs », réglages, chaînes.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- Mocks propres à ce fichier, restaurés à la fin
local saved, MOCKED = {}, { "IsInInstance", "GetInstanceInfo", "GetRealZoneText", "InCombatLockdown", "UnitFactionGroup",
	"date", "QuestWatchFrame", "ObjectiveTrackerFrame", "QuestObjectiveTracker" }
for _, name in ipairs(MOCKED) do saved[name] = rawget(_G, name) end
saved.GetAreaInfo = C_Map.GetAreaInfo
saved.NextUnlocks = rawget(NS, "CompanionNextUnlocks")
-- Ces tests couvrent le comportement 100 % dynamique (zone absente des tables
-- livrées, carte inconnue du client) : tables mises de côté, remises à la fin.
-- Les zones préremplies sont testées dans zone_data.lua et zone_quests.lua.
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

-- Contrat du Compagnon (Companion.lua, agent parallèle) : bouchonné ici
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

-- 1. Chaînes ----------------------------------------------------------------------
do
	Say("-- suivi du carnet : chaînes")
	Check("[TRK] JournalTracker.lua chargé (après Journal.lua)", NS.Loaded and NS.Loaded.JournalTracker and NS.Loaded.Journal)
	local strings, missing, mismatch = NS.JOURNAL_TRACKER_STRINGS, {}, {}
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" then missing[#missing + 1] = "en:" .. key end
		if value == "" or NS.L[key] ~= value then missing[#missing + 1] = "fr:" .. key end
	end
	for key in pairs(strings.en) do if strings.fr[key] == nil then missing[#missing + 1] = "fr?" .. key end end
	Check("[TRK] chaînes en français et en anglais", #missing == 0, table.concat(missing, ", "))
	local function Placeholders(text)
		local list = {}
		for p in tostring(text):gsub("%%%%", ""):gmatch("%%[%d%$]*[sd]") do list[#list + 1] = p end
		return table.concat(list, ",")
	end
	for key, value in pairs(strings.fr) do
		if Placeholders(value) ~= Placeholders(strings.en[key]) then mismatch[#mismatch + 1] = key end
	end
	Check("[TRK] mêmes paramètres dans les deux langues", #mismatch == 0, table.concat(mismatch, ","))
	local all = ""
	for _, value in pairs(strings.fr) do all = all .. value end
	for _, key in ipairs({ "JRN_TAB_goals", "JRN_GOALS_EMPTY", "JRN_GOALS_HINT" }) do all = all .. NS.JOURNAL_STRINGS.fr[key] end
	Check("[TRK] tutoiement (pas de « vous »)", not all:find("[Vv]ous"))
	for _, key in ipairs({ "JRN_TAB_goals", "JRN_GOALS_COUNT", "JRN_GOALS_EMPTY", "JRN_GOALS_HINT", "JRN_GOAL_HIDDEN" }) do
		Check("[TRK] onglet Objectifs : " .. key .. " (fr+en)", NS.JOURNAL_STRINGS.fr[key] and NS.JOURNAL_STRINGS.en[key])
	end
	Check("[TRK] anglais : titre du suivi", strings.en.JRN_TRK_TITLE == "Journal" and strings.fr.JRN_TRK_TITLE == "Carnet")
	for _, stat in ipairs({ "zone", "subzone", "capital", "dungeon", "rare", "level", "total" }) do
		Check("[TRK] stat " .. stat .. " nommée (fr+en)", strings.fr["JRN_STAT_" .. stat] and strings.en["JRN_STAT_" .. stat])
	end
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
	Check("[TRK] compagnon : objectif atteint exclu, entrée sans nom ignorée",
		not K.Labels(list):find("Déjà là", 1, true) and #list == 6, #list)
	local lantern = K.Find(list, "comp:")
	Check("[TRK] compagnon : contrat lu tel quel", lantern and lantern.id == "comp:orn:Lanterne" and lantern.have == 18
		and lantern.need == 25 and lantern.source == "companion" and lantern.kind == "orn")
	local level = K.Find(list, "level:")
	Check("[TRK] palier : prochain palier, trié sur la tranche (27 entre 20 et 30)", level and level.id == "level:30"
		and math.abs(level.ratio - 0.7) < 1e-6, level and level.ratio)
	-- villages : la faction compte (Alliance aux Tarides : Ratchet seul, neutre)
	K.Reset(27, "Alliance")
	local villages = K.Find(NS:JournalObjectives(), "villages:")
	Check("[TRK] villages : faction filtrée (Alliance : Ratchet seul)", villages and villages.progress == "0/1", villages and villages.progress)
	-- zone sans village connu : pas d'objectif de village
	Mock.world.mapID = 7777
	Check("[TRK] zone sans village : rien", K.Find(NS:JournalObjectives(), "villages:") == nil)
	-- village de Forever absent de la table (Falaath, 16636) : appris en passant
	Check("[TRK] village de Forever : pas dans la table livrée", NS.JOURNAL_HUB_ZONE[16636] == nil and NS:JournalHubZone(16636) == nil)
	Mock.world.subzone = "Falaath Village"
	Mock:Fire("ZONE_CHANGED")
	Check("[TRK] village inconnu de la table : zone apprise au passage", NS:JournalHubZone(16636) == 7777
		and NS:DB().journalHubZones[16636] == 7777)
	NS:JournalData().stamps["subzone:16636"] = nil
	villages = K.Find(NS:JournalObjectives(), "villages:7777")
	Check("[TRK] village appris : objectif de sa zone", villages ~= nil and villages.progress == "0/1"
		and villages.label == "Villages de Île nouvelle", villages and villages.label)
	-- donjons : la plage de ton niveau (client Forever du harnais)
	K.Reset(20)
	local dungeons = K.Find(NS:JournalObjectives(), "dungeons:")
	local hint = dungeons and table.concat(dungeons.hint, " | ") or ""
	Check("[TRK] donjons : libellé court, les noms au survol", dungeons and dungeons.label == "Donjons de ton niveau"
		and dungeons.progress == "0/4", dungeons and dungeons.label)
	local a, b, c, d = hint:find("Ruins of Lordaeron (", 1, true), hint:find("Wailing Caverns (", 1, true),
		hint:find("Deadmines (", 1, true), hint:find("Shadowfang Keep (", 1, true)
	Check("[TRK] donjons : ceux de ta tranche, par niveau d'entrée, avec leur plage", a and b and c and d
		and a < b and b < c and c < d and hint:find("%(%d+%-%d+%)") ~= nil, hint)
	K.Stamp("dungeon", "wc", "Wailing Caverns")
	dungeons = K.Find(NS:JournalObjectives(), "dungeons:")
	Check("[TRK] donjons : un tamponné sort de la liste, compté", dungeons and dungeons.progress == "1/4"
		and not table.concat(dungeons.hint, " "):find("Wailing", 1, true), dungeons and table.concat(dungeons.hint, " | "))
	Check("[TRK] donjons : identifiant stable malgré le tampon", dungeons and dungeons.id == "dungeons:dm,lordaeron,sfk,wc", dungeons and dungeons.id)
	K.Reset(5)
	Check("[TRK] niveau 5 : aucun donjon", K.Find(NS:JournalObjectives(), "dungeons:") == nil)
	K.Reset(60)
	Check("[TRK] niveau 60 : plus de palier", K.Find(NS:JournalObjectives(), "level:") == nil)
	-- sans contrat du Compagnon : rien d'inventé
	K.Reset(27)
	NS.CompanionNextUnlocks = nil
	Check("[TRK] sans CompanionNextUnlocks : aucune ligne compagnon", K.Find(NS:JournalObjectives(), "comp:") == nil
		and #NS:JournalObjectives() == 4, K.Labels(NS:JournalObjectives()))
	NS.CompanionNextUnlocks = function() error("boom") end
	Check("[TRK] contrat en panne : les autres sources restent", #NS:JournalObjectives() == 4)
	NS.CompanionNextUnlocks = StubUnlocks
	-- capitales toutes vues : objectif atteint, disparu
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
	Check("[TRK] cadre affiché à l'entrée dans le monde", tracker and tracker:IsShown())
	Check("[TRK] titre ambre « Carnet »", tracker.title.text.text == "Carnet"
		and tracker.title.text.textColor[1] == NS.Theme.GOLD[1], tracker.title.text.text)
	Check("[TRK] quatre lignes au plus, les plus proches ; la première en vedette (libellé court + unité)", K.Lines() ==
		"Lanterne 18/25 villages | Atteins le niveau 30 27/30 | Feu follet — donjons 1/2 | Villages de Les Tarides 1/3",
		K.Lines())
	local line, second = tracker.lines[1], tracker.lines[2]
	Check("[TRK] vedette : fond, filet ambre, losange plein, grande barre", line.featured and line.bg and line.accent
		and line.diamond.texture == NS.Theme.DIAMOND and line.bar.height == 5
		and math.abs(line.bar.ratio - 18 / 25) < 1e-6, line.bar and line.bar.ratio)
	Check("[TRK] secondaires : losange en trait, mini-barre, progression grisée", not second.featured
		and second.diamond.texture == NS.Theme.DIAMOND_LINE and second.bar.height == 3
		and math.abs(second.bar.ratio - 27 / 30) < 1e-6 and second.progress.textColor[1] == NS.Theme.MUTED[1])
	Check("[TRK] hauteur : titre + vedette + secondaires", tracker.height == 18 + 40 + 4 + 3 * 16, tracker.height)

	-- survol : quoi faire, avec des noms
	local tip = _G.GameTooltip
	tracker.lines[4]:GetScript("OnEnter")(tracker.lines[4])
	local text = table.concat(tip.lines or {}, " | ")
	Check("[TRK] survol villages : villages restants nommés", tip.shown and text:find("Villages à visiter dans Les Tarides", 1, true)
		and text:find("Camp Taurajo", 1, true) and not text:find("The Crossroads", 1, true), text)
	Check("[TRK] survol : rappel des clics", text:find("clic droit : masquer", 1, true) ~= nil, text)
	tracker.lines[4]:GetScript("OnLeave")(tracker.lines[4])
	Check("[TRK] fin du survol : bulle fermée", not tip.shown)
	tracker.lines[1]:GetScript("OnEnter")(tracker.lines[1])
	text = table.concat(tip.lines or {}, " | ")
	Check("[TRK] survol compagnon : ce que ça débloque et comment", text:find("ornement", 1, true)
		and text:find("Villages à visiter", 1, true), text)
	tracker.lines[2]:GetScript("OnEnter")(tracker.lines[2])
	text = table.concat(tip.lines or {}, " | ")
	Check("[TRK] survol palier : niveaux restants", text:find("Encore 3 niveau", 1, true) ~= nil, text)
	tracker.lines[2]:GetScript("OnLeave")(tracker.lines[2])

	-- clic gauche : le carnet, onglet Objectifs ; à nouveau : refermé
	NS.journalFrame = nil
	tracker.lines[1]:Click("LeftButton")
	Check("[TRK] clic sur un objectif du compagnon : carnet ouvert sur l'Évolution", NS.journalFrame and NS.journalFrame:IsShown()
		and NS.journalFrame.kind == "evolution")
	tracker.lines[1]:Click("LeftButton")
	Check("[TRK] second clic : carnet refermé", not NS.journalFrame:IsShown())

	-- rafraîchi sur STAMP
	NS:JournalEarn("subzone", 378, "Camp Taurajo")
	Check("[TRK] STAMP : la liste suit (villages 2/3)", K.Lines():find("Villages de Les Tarides 2/3", 1, true), K.Lines())
	-- rafraîchi au changement de zone (Elwynn, Horde : pas de village ami)
	Mock.world.mapID = 1429
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	Check("[TRK] changement de zone : villages de la nouvelle zone", not K.Lines():find("Villages", 1, true)
		and K.Lines():find("Capitales", 1, true), K.Lines())
	Mock.world.mapID = 1413
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	-- rafraîchi à la montée de niveau, même si UnitLevel est en retard
	Mock:Fire("PLAYER_LEVEL_UP", 28)
	Check("[TRK] montée de niveau : palier à jour (niveau de l'événement)", K.Lines():find("niveau 30 28/30", 1, true), K.Lines())
	Mock:Fire("ZONE_CHANGED")
	Check("[TRK] niveau de l'événement : oublié après", K.Lines():find("niveau 30 27/30", 1, true), K.Lines())
	Mock.world.level = 28

	-- masquer d'un clic droit
	local first = tracker.lines[1].goal.id
	tracker.lines[1]:Click("LeftButton")
	Check("[TRK] clic gauche : rien de masqué", tracker.lines[1].goal.id == first)
	tracker.lines[1]:Click("RightButton")
	Check("[TRK] clic droit : objectif masqué", tracker.lines[1].goal.id ~= first and not K.Lines():find("Lanterne", 1, true), K.Lines())
	Check("[TRK] masquage retenu par personnage", NS:JournalData().dismissed[first] == true)
	Check("[TRK] une place libérée : le suivant monte", K.Lines():find("Capitales", 1, true), K.Lines())
	Mock:Fire("ZONE_CHANGED")
	Check("[TRK] masqué : le reste après un rafraîchissement", not K.Lines():find("Lanterne", 1, true))
	-- trois masqués sur six : trois lignes, jamais un masqué pour boucher le trou
	local second = tracker.lines[1].goal.id
	tracker.lines[1]:Click("RightButton")
	local third = tracker.lines[1].goal.id
	tracker.lines[1]:Click("RightButton")
	Check("[TRK] trois masqués : trois lignes, sans eux", not tracker.lines[4]:IsShown() and tracker.lines[3]:IsShown()
		and not K.Lines():find("Lanterne", 1, true), K.Lines())
	Check("[TRK] hauteur suit le nombre de lignes", tracker.height == 18 + 40 + 4 + 2 * 16, tracker.height)
	NS:JournalDismiss(second, false)
	NS:JournalDismiss(third, false)
	Check("[TRK] remis : de retour dans le suivi", tracker.lines[4]:IsShown() and not NS:JournalData().dismissed[second])

	-- repli
	tracker.title:Click()
	Check("[TRK] clic sur le titre : replié", NS:DB().journalTrackerCollapsed == true and K.Lines() == ""
		and tracker.title.text.text == "Carnet (4)" and tracker.height == 18, tracker.title.text.text)
	Mock:Fire("ZONE_CHANGED")
	Check("[TRK] replié : le reste au rafraîchissement", K.Lines() == "" and tracker:IsShown())
	tracker.title:Click()
	Check("[TRK] second clic : déplié", NS:DB().journalTrackerCollapsed == false and tracker.lines[4]:IsShown())

	-- combat
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Check("[TRK] combat : masqué (réglage par défaut)", not tracker:IsShown())
	NS:JournalEarn("subzone", 392, "Ratchet")
	Check("[TRK] combat : un tampon ne le fait pas réapparaître", not tracker:IsShown())
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Check("[TRK] sortie de combat : revient", tracker:IsShown())
	K.W.lockdown = true
	NS:RefreshJournalTracker()
	Check("[TRK] verrou de combat sans événement (/reload) : masqué", not tracker:IsShown())
	K.W.lockdown = false
	NS:DB().journalTrackerCombat = false
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Check("[TRK] « Masquer en combat » coupé : reste affiché", tracker:IsShown())
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
	-- une deuxième part (comme le bestiaire) : 1 espèce sur 4
	local fake = { id = "fake", label = "Bestiaire", Compute = function(_, zoneID)
		if zoneID ~= 1413 then return nil end
		return { have = 1, need = 4, hint = { "  · Sanglier" } }
	end }
	NS.RegisterZonePart(fake)
	local broken = { id = "broken", Compute = function() error("boom") end }
	NS.RegisterZonePart(broken)
	local done = NS:ZoneCompletion(1413)
	Check("[ZONE] parts à poids égal : (1/3 + 1/4) / 2 = 29 %", done and done.percent == 29 and #done.parts == 2,
		done and done.percent)
	Check("[ZONE] part en panne ignorée", done and #done.parts == 2)
	Check("[ZONE] autre zone : seules les parts qui s'appliquent", NS:ZoneCompletion(1429) == nil)
	local goal = K.Find(NS:JournalObjectives(), "zone:1413")
	Check("[ZONE] objectif « Complétion de Les Tarides », en pourcentage", goal and goal.label == "Complétion de Les Tarides"
		and goal.progress == "29 %", goal and (goal.label .. " " .. goal.progress))
	local hint = goal and table.concat(goal.hint, " | ") or ""
	Check("[ZONE] survol : chaque part, puis la plus simple à finir", hint:find("Villages : 1/3", 1, true)
		and hint:find("Bestiaire : 1/4", 1, true) and hint:find("Le plus simple pour avancer — Villages", 1, true)
		and hint:find("Camp Taurajo", 1, true), hint)
	-- le suivi : la complétion remplace ses parts
	NS:RefreshJournalTracker()
	local lines = K.Lines()
	Check("[ZONE] suivi : complétion affichée, villages de la zone absorbés", lines:find("Complétion de Les Tarides", 1, true)
		and not lines:find("Villages de Les Tarides", 1, true), lines)
	Check("[ZONE] onglet Objectifs : les villages restent", K.Find(NS:JournalObjectives(), "villages:1413") ~= nil)
	NS:JournalDismiss("zone:1413", true)
	Check("[ZONE] complétion masquée : ses parts reviennent dans le suivi", K.Lines():find("Villages de Les Tarides", 1, true), K.Lines())
	NS:JournalDismiss("zone:1413", false)
	-- onglet Zones : le pourcentage à côté de la zone tamponnée
	K.Stamp("zone", 1413, "Les Tarides")
	local item
	for _, entry in ipairs(NS:JournalItems("zone")) do if entry.id == "zone:1413" then item = entry end end
	Check("[ZONE] onglet Zones : pourcentage affiché", item and item.detail:find("29 %", 1, true), item and item.detail)
	-- 100 % : plus d'objectif
	fake.Compute = function() return { have = 4, need = 4 } end
	for _, id in ipairs({ 378, 362 }) do K.Stamp("subzone", id) end
	for _, entry in pairs(NS:JournalHubGroups()) do
		if NS:JournalHubZone(entry.areaID) == 1413 then K.Stamp("subzone", entry.areaID) end
	end
	Check("[ZONE] zone finie : 100 %, plus d'objectif", NS:ZoneCompletion(1413).percent == 100
		and K.Find(NS:JournalObjectives(), "zone:") == nil, NS:ZoneCompletion(1413).percent)
	-- retire les parts de test
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
	Check("[TRK] suivi de Blizzard caché : prend sa place en haut", p.relTo == QuestWatchFrame and p.relPoint == "TOPRIGHT", p.relPoint)
	QuestWatchFrame:Show()
	if QuestWatchFrame.hooks and QuestWatchFrame.hooks.OnShow then QuestWatchFrame.hooks.OnShow(QuestWatchFrame) end
	Check("[TRK] suivi de Blizzard réaffiché : de nouveau dessous", tracker.lastPoint.relPoint == "BOTTOMRIGHT")

	-- glisser : position retenue
	tracker.title.scripts.OnDragStart(tracker.title)
	Check("[TRK] glisser par le titre", tracker.isMoving == true)
	tracker:ClearAllPoints()
	tracker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -200)
	tracker.title.scripts.OnDragStop(tracker.title)
	local point = NS:DB().journalTrackerPoint
	Check("[TRK] fin du glisser : position sauvegardée", point and point.point == "TOPLEFT" and point.x == 300 and point.y == -200
		and tracker.isMoving == false)
	NS:RefreshJournalTracker()
	Check("[TRK] déplacé : ne revient pas sous Blizzard au rafraîchissement", tracker.lastPoint.x == 300 and tracker.anchoredTo == "saved")
	-- nouvelle session : la position revient
	NS.journalTracker = nil
	NS:RefreshJournalTracker()
	tracker = NS.journalTracker
	Check("[TRK] /reload : position restaurée", tracker.lastPoint.point == "TOPLEFT" and tracker.lastPoint.x == 300
		and tracker.lastPoint.relTo == UIParent)
	-- réinitialiser (action des réglages)
	Mock:Reset()
	NS:RunOptionAction("journalTrackerReset")
	Check("[TRK] réinitialiser : position oubliée, de nouveau sous Blizzard", NS:DB().journalTrackerPoint == nil
		and tracker.anchoredTo == "QuestWatchFrame" and tracker.lastPoint.relTo == QuestWatchFrame)
	Check("[TRK] réinitialiser : confirmé dans le chat", Mock:Output():find("Suivi du carnet remis", 1, true), Mock:Output())

	-- Forever (client moderne) : ObjectiveTrackerFrame, puis QuestObjectiveTracker
	_G.QuestWatchFrame = nil
	_G.ObjectiveTrackerFrame = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent)
	ObjectiveTrackerFrame:Show()
	NS:PlaceJournalTracker()
	Check("[TRK] Forever : sous ObjectiveTrackerFrame", tracker.anchoredTo == "ObjectiveTrackerFrame"
		and tracker.lastPoint.relTo == ObjectiveTrackerFrame)
	_G.ObjectiveTrackerFrame = nil
	_G.QuestObjectiveTracker = CreateFrame("Frame", "QuestObjectiveTracker", UIParent)
	QuestObjectiveTracker:Show()
	NS:PlaceJournalTracker()
	Check("[TRK] Forever : repli sur QuestObjectiveTracker", tracker.anchoredTo == "QuestObjectiveTracker")
	-- un suivi visible passe avant un suivi caché
	_G.QuestWatchFrame = CreateFrame("Frame", "QuestWatchFrame", UIParent)   -- caché (mock : Hide par défaut)
	NS:PlaceJournalTracker()
	Check("[TRK] le suivi visible d'abord", tracker.anchoredTo == "QuestObjectiveTracker")
	-- aucun suivi de Blizzard (Questie l'a remplacé, client inconnu) : à droite
	_G.QuestWatchFrame, _G.QuestObjectiveTracker = nil, nil
	NS:PlaceJournalTracker()
	p = tracker.lastPoint
	Check("[TRK] sans suivi de Blizzard : à droite de l'écran", tracker.anchoredTo == "UIParent" and p.relTo == UIParent
		and p.point == "TOPRIGHT" and p.x < 0 and p.y < 0, tostring(p.x) .. "," .. tostring(p.y))
	-- un « suivi » qui refuse l'ancre : repli, pas d'erreur
	local bad = CreateFrame("Frame", "QuestWatchFrame", UIParent)
	bad:Show()
	_G.QuestWatchFrame = bad
	local realSetPoint = tracker.SetPoint
	tracker.SetPoint = function(self, point, rel, ...)
		if rel == bad then error("Cannot anchor to itself") end
		return realSetPoint(self, point, rel, ...)
	end
	local ok = pcall(NS.PlaceJournalTracker, NS)
	tracker.SetPoint = realSetPoint
	Check("[TRK] ancre refusée : repli sur l'écran, sans erreur", ok and tracker.anchoredTo == "UIParent")
	_G.QuestWatchFrame = "pas un cadre"
	Check("[TRK] globale QuestWatchFrame bizarre : ignorée", NS:BlizzardQuestTracker() == nil)
	_G.QuestWatchFrame = nil
end

-- 5. Module coupé, réglages -----------------------------------------------------------
do
	Say("-- suivi du carnet : module et réglages")
	K.Reset(27)
	NS:RefreshJournalTracker()
	local tracker = NS.journalTracker
	Check("[TRK] module allumé : affiché", tracker:IsShown())
	NS:HandleCommand("module carnet off")
	Check("[TRK] /r2q module carnet off : suivi caché", not tracker:IsShown())
	Mock:Fire("ZONE_CHANGED")
	Check("[TRK] module coupé : reste caché aux événements", not tracker:IsShown())
	NS:HandleCommand("module carnet on")
	Check("[TRK] module rallumé : suivi de retour", tracker:IsShown())
	NS:DB().enabled = false
	NS:RefreshJournalTracker()
	Check("[TRK] addon coupé : suivi caché", not tracker:IsShown())
	NS:DB().enabled = true

	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("journal")
	local page = NS.optionsFrame.pages.journal
	local rows = {}
	for _, row in ipairs(page.rows) do if row.def then rows[row.def.key] = row end end
	Check("[TRK] réglage « Suivi à l'écran »", rows.journalTracker and rows.journalTracker.label.text == "Suivi à l'écran")
	Check("[TRK] réglage « Masquer en combat »", rows.journalTrackerCombat and rows.journalTrackerCombat.label.text == "Masquer en combat")
	Check("[TRK] action « Réinitialiser la position du suivi »", rows.journalTrackerReset
		and rows.journalTrackerReset.label.text == "Réinitialiser la position du suivi")
	Check("[TRK] la page tient dans le panneau", page.contentBottom >= NS.OPT_LAYOUT.contentLimit, page.contentBottom)
	rows.journalTracker:Click()
	Check("[TRK] interrupteur coupé : suivi caché tout de suite", NS:DB().journalTracker == false and not tracker:IsShown())
	rows.journalTracker:Click()
	Check("[TRK] interrupteur rallumé : suivi de retour", NS:DB().journalTracker == true and tracker:IsShown())
	NS:DB().journalTrackerPoint = { point = "CENTER", relPoint = "CENTER", x = 1, y = 2 }
	rows.journalTrackerReset:Click()
	Check("[TRK] ligne « Réinitialiser » : position oubliée", NS:DB().journalTrackerPoint == nil)
	NS.optionsFrame:Hide()
	NS.optionsFrame = nil
end

-- 6. Fenêtre : Complétion (zone, activités) et Évolution -----------------------------
do
	Say("-- carnet : fenêtre Complétion / Évolution")
	K.Reset(27)
	K.Stamp("subzone", 380, "The Crossroads"); K.Stamp("capital", 1637, "Orgrimmar")
	K.Stamp("zone", 1413, "Les Tarides")
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	local comp = f.comp
	Check("[WIN] ouvre sur la Complétion, zone où tu es", f.kind == "completion" and f.zoneID == 1413
		and comp:IsShown() and not f.evo:IsShown())
	Check("[WIN] liste déroulante : la zone, marquée « ici »", comp.zoneButton.text.text:find("Zone : Les Tarides (ici)", 1, true), comp.zoneButton.text.text)
	Check("[WIN] quatre activités", comp.tabs.explore and comp.tabs.combat and comp.tabs.craft and comp.tabs.quests
		and comp.tabs.explore.text.text == "Exploration")
	Check("[WIN] client sans liste de quêtes : onglet « Quêtes », grisé", NS:ZoneQuestsAvailable() == false
		and comp.tabs.quests.text.text == "Quêtes" and comp.tabs.quests.text.textColor[1] == NS.Theme.MUTED[1],
		comp.tabs.quests.text.text)
	comp.tabs.quests.hooks.OnEnter(comp.tabs.quests)
	local tipText = table.concat(_G.GameTooltip.lines or {}, " ")
	Check("[WIN] Quêtes : le survol dit qu'il n'y a pas de liste pour ce client, sans Questie",
		tipText:find(NS.L.JRN_ACT_NO_QUESTS, 1, true) ~= nil and not tipText:find("Questie", 1, true), tipText)
	comp.tabs.quests.hooks.OnLeave(comp.tabs.quests)
	Check("[WIN] onglet actif : Exploration", comp.tabs.explore.selected and not comp.tabs.combat.selected)
	Check("[WIN] exploration : titre de part « Villages : 1/3 »", comp.lines[1].item and comp.lines[1].item.header
		and comp.lines[1].name.text == "Villages : 1/3", comp.lines[1].name.text)
	Check("[WIN] à visiter d'abord, en trait", comp.lines[2].item and not comp.lines[2].item.done
		and comp.lines[2].stamp.texture == NS.Theme.DIAMOND_LINE and comp.lines[2].detail.text:find("à visiter", 1, true))
	Check("[WIN] visité ensuite, losange plein", comp.lines[4].item and comp.lines[4].item.done
		and comp.lines[4].name.text == "The Crossroads" and comp.lines[4].stamp.texture == NS.Theme.DIAMOND, comp.lines[4].name.text)
	Check("[WIN] une seule activité suivie : pas de pourcentage, on dit pourquoi", comp.percent.text == ""
		and comp.chest.text == NS.L.JRN_ZONE_NOPCT, comp.chest.text)
	comp.tabs.combat:Click()
	Check("[WIN] combat vide : comment remplir", comp.empty.text == NS.L.JRN_ACT_EMPTY_combat and not comp.lines[1]:IsShown())
	comp.tabs.craft:Click()
	Check("[WIN] métiers sans métier : message", comp.empty.text == NS.L.JRN_ACT_EMPTY_craft)
	comp.tabs.quests:Click()
	Check("[WIN] quêtes sans liste : message clair", comp.empty.text == "Pas de liste de quêtes pour ce client.", comp.empty.text)

	-- bestiaire : une deuxième activité -> pourcentage, coffre annoncé, défilement
	local zone = {}
	for index = 1, 14 do
		zone[1000 + index] = { name = "Bête " .. string.format("%02d", index), type = "Bête", seen = true, killed = index <= 4 and 1 or 0 }
	end
	zone[2000] = { name = "Chef kolkar", type = "Humanoïde", class = "elite", seen = true, killed = 0 }
	NS:JournalData().bestiary = { [1413] = zone }
	comp.tabs.combat:Click()
	Check("[WIN] deux activités : pourcentage et barre", comp.percent.text ~= "" and comp.bar:IsShown(), comp.percent.text)
	Check("[WIN] coffre annoncé avec son palier", comp.chest.text:find("palier 1", 1, true), comp.chest.text)
	Check("[WIN] combat : bestiaire puis nommés, à abattre d'abord, nommé en tête", comp.lines[1].name.text == "Bestiaire : 4/15"
		and comp.lines[2].name.text:find("Chef kolkar, élite", 1, true) and comp.lines[2].detail.text:find("à abattre", 1, true),
		comp.lines[1].name.text .. " / " .. tostring(comp.lines[2].name.text))
	local order = true
	for index = 3, #f.rows do
		local previous, item = f.rows[index - 1], f.rows[index]
		if not item.header and not previous.header and previous.done and not item.done then order = false end
	end
	local lastItem
	for _, item in ipairs(f.rows) do if not item.header then lastItem = item end end
	Check("[WIN] combat : toutes les espèces à abattre avant les abattues", order and lastItem and lastItem.done == true)
	Check("[WIN] combat : la part « Nommés » a son titre", f.rows[#f.rows].header and f.rows[#f.rows].name == "Nommés : 0/1",
		f.rows[#f.rows].name)
	local rows = #f.rows
	Check("[WIN] de quoi défiler", rows > 11 and not comp.up:IsShown() and comp.down:IsShown(), rows)
	f.scripts.OnMouseWheel(f, -1)
	Check("[WIN] molette : une ligne plus bas", f.offset == 1 and comp.lines[1].item == f.rows[2])
	for _ = 1, 100 do NS:ScrollJournal(-1) end
	Check("[WIN] butée en bas, position affichée", f.offset == rows - 11 and not comp.down:IsShown()
		and comp.position.text == string.format("%d-%d / %d", rows - 10, rows, rows), comp.position.text)
	comp.tabs.explore:Click()
	Check("[WIN] changer d'onglet remonte en haut", f.offset == 0)

	-- liste des zones
	K.Stamp("zone", 1429, "Forêt d'Elwynn")
	comp.zoneButton:Click()
	local list = comp.zoneList
	Check("[WIN] liste : ouverte, la zone d'ici en premier", list:IsShown() and list.buttons[1].text.text:find("Les Tarides (ici)", 1, true)
		and list.buttons[2]:IsShown(), list.buttons[1].text.text)
	Check("[WIN] liste : le pourcentage à côté", list.buttons[1].text.text:find("%", 1, true) ~= nil, list.buttons[1].text.text)
	local elwynn
	for _, button in ipairs(list.buttons) do if button.zoneID == 1429 then elwynn = button end end
	elwynn:Click()
	Check("[WIN] autre zone choisie : liste fermée, zone affichée", not list:IsShown() and f.zoneID == 1429
		and comp.zoneButton.text.text:find("Forêt d'Elwynn", 1, true) and not comp.zoneButton.text.text:find("ici", 1, true))
	Check("[WIN] Elwynn (Horde) : pas de village ami", comp.empty.text == NS.L.JRN_ACT_EMPTY_explore, comp.empty.text)
	Mock:Fire("ZONE_CHANGED")
	Check("[WIN] le choix tient tant que la fenêtre est ouverte", f.zoneID == 1429)
	f:Hide()
	NS:ToggleJournal(true)
	Check("[WIN] rouverte : de retour sur la zone d'ici", f.zoneID == 1413)

	-- suivre à l'écran : la zone d'ici d'office, une autre si cochée
	NS:DB().journalTracker = true
	f.zonePicked, f.zoneID = nil, nil
	NS:RefreshJournal()
	Check("[WATCH] zone d'ici : cochée d'office", comp.watch.checked == true and comp.watchLabel.text == "Suivre à l'écran")
	NS:RefreshJournalTracker()
	Check("[WATCH] suivi : la complétion d'ici affichée", K.Lines():find("Complétion de Les Tarides", 1, true), K.Lines())
	comp.watch:Click()
	Check("[WATCH] décochée : retenue", NS:JournalData().watch[1413] == false and comp.watch.checked == false)
	Check("[WATCH] décochée : la zone et ses parts quittent le suivi", not K.Lines():find("Les Tarides", 1, true), K.Lines())
	Check("[WATCH] décochée : les objectifs restent calculés", K.Find(NS:JournalObjectives(), "zone:1413") ~= nil)
	NS:JournalDismiss("zone:1413", true)
	NS:JournalDismiss("villages:1413", true)
	comp.watch:Click()
	Check("[WATCH] recochée : de retour", K.Lines():find("Complétion de Les Tarides", 1, true), K.Lines())
	Check("[WATCH] recochée : les objectifs masqués avant sont réactivés", not NS:JournalData().dismissed["zone:1413"]
		and not NS:JournalData().dismissed["villages:1413"])
	-- une autre zone : cochée à la main
	NS:JournalData().bestiary[1429] = { [9] = { name = "Loup", type = "Bête", seen = true, killed = 0 } }
	NS:SelectJournalZone(1429)
	Check("[WATCH] autre zone : décochée d'office", comp.watch.checked == false)
	Check("[WATCH] autre zone non cochée : absente du suivi", not K.Lines():find("Elwynn", 1, true), K.Lines())
	comp.watch:Click()
	Check("[WATCH] autre zone cochée : dans le suivi, même avec une seule activité", NS:JournalIsWatched(1429)
		and K.Lines():find("Complétion de Forêt d'Elwynn", 1, true), K.Lines())
	comp.watch.scripts.OnEnter(comp.watch)
	Check("[WATCH] survol : explication", table.concat(_G.GameTooltip.lines or {}, " "):find("bloc", 1, true) ~= nil)
	comp.watch.scripts.OnLeave(comp.watch)
	NS:JournalSetWatched(1429, false)
	NS:SelectJournalZone(1413)
	NS:DB().journalTracker = false

	-- Évolution
	f.sections.evolution:Click()
	local evo = f.evo
	Check("[WIN] Évolution : section affichée seule", evo:IsShown() and not comp:IsShown() and f.kind == "evolution")
	Check("[WIN] Évolution : étape actuelle", evo.stage.text:find("étape", 1, true), evo.stage.text)
	Check("[WIN] Évolution : prochain objectif", evo.next.text:find("niveau", 1, true), evo.next.text)
	Check("[WIN] Évolution : 4 envies avec barres", #evo.needs == 4 and evo.needs[1].label.text == "Faim"
		and evo.needs[1].value.text:find("%", 1, true))
	Check("[WIN] Évolution : comment ça marche (3 lignes)", evo.howTitle.text == "Comment ça marche"
		and evo.how[2].text:find("70", 1, true) and evo.how[3].text:find("100 %", 1, true) and not evo.how[3].text:find("%%", 1, true), evo.how[3].text)
	Check("[WIN] Évolution : collection", evo.collection.text:find("Collection : ", 1, true), evo.collection.text)
	Check("[WIN] Évolution : parcours (capitales 1/6)", evo.road.text:find("1/6 capitales", 1, true), evo.road.text)
	Check("[WIN] Évolution : pas de coffre, pas de bouton", evo.chests.text == "Coffres à ouvrir : 0" and not evo.openChest:IsShown())
	f.sections.completion:Click()
	Check("[WIN] retour à la Complétion", comp:IsShown() and not evo:IsShown())
	-- une seule fenêtre à la fois
	NS:ToggleOptions()
	Check("[WIN] une seule fenêtre : les réglages ferment le carnet", not f:IsShown())
	NS.optionsFrame:Hide()
	NS.optionsFrame = nil
	NS:JournalData().bestiary = nil
	-- aucune zone connue
	K.Reset(27)
	Mock.world.mapID = nil
	NS:ToggleJournal(true)
	Check("[WIN] aucune zone : invitation à explorer", NS.journalFrame.comp.empty.text == NS.L.JRN_ZONE_NONE, NS.journalFrame.comp.empty.text)
	NS.journalFrame:Hide()
end

-- ipairs sur la liste : une globale absente avant (nil) doit le redevenir
for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
C_Map.GetAreaInfo = saved.GetAreaInfo
NS.CompanionNextUnlocks = saved.NextUnlocks
NS.ZONE_CREATURES, NS.ZONE_GATHERING = saved.ZONE_CREATURES, saved.ZONE_GATHERING
NS.ZONE_QUESTS = saved.ZONE_QUESTS
if NS.journalTracker then NS.journalTracker:Hide() end
