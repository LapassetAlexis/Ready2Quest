-- Carnet de voyage : objectifs et suivi à l'écran « Carnet » (v1.25.0).
-- Sources (compagnon, villages de la zone, capitales, donjons, palier), tri,
-- masquage, rafraîchissement, repli, combat, position, ancrage, module coupé,
-- onglet « Objectifs », réglages, chaînes.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

-- Mocks propres à ce fichier, restaurés à la fin
local saved, MOCKED = {}, { "IsInInstance", "GetInstanceInfo", "GetRealZoneText", "InCombatLockdown", "UnitFactionGroup",
	"date", "QuestWatchFrame", "ObjectiveTrackerFrame", "QuestObjectiveTracker" }
for _, name in ipairs(MOCKED) do saved[name] = rawget(_G, name) end
saved.GetAreaInfo = C_Map.GetAreaInfo
saved.NextUnlocks = rawget(NS, "CompanionNextUnlocks")

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
		"Lanterne — villages 18/25 | Palier 30 : niveau 27/30 | Feu follet — donjons 1/2 | Villages de Les Tarides 1/3"
		.. " | Capitales 1/6 | Donjons de ton niveau : Shadowfang Keep, Blackfathom Deeps, Excavation Site: Wetlands, Stormwind Stockade 0/4",
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
	Check("[TRK] donjons : ceux de ta tranche, par niveau d'entrée", dungeons and dungeons.label ==
		"Donjons de ton niveau : Ruins of Lordaeron, Wailing Caverns, Deadmines, Shadowfang Keep" and dungeons.progress == "0/4",
		dungeons and dungeons.label)
	K.Stamp("dungeon", "wc", "Wailing Caverns")
	dungeons = K.Find(NS:JournalObjectives(), "dungeons:")
	Check("[TRK] donjons : un tamponné sort de la liste, compté", dungeons and dungeons.progress == "1/4"
		and not dungeons.label:find("Wailing", 1, true), dungeons and dungeons.label)
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
	Check("[TRK] cinq lignes au plus, les plus proches", K.Lines() ==
		"Lanterne — villages 18/25 | Palier 30 : niveau 27/30 | Feu follet — donjons 1/2 | Villages de Les Tarides 1/3 | Capitales 1/6",
		K.Lines())
	local line = tracker.lines[1]
	Check("[TRK] progression grisée, losange par objectif", line.progress.textColor[1] == NS.Theme.MUTED[1]
		and line.diamond and line.diamond.texture == NS.Theme.DIAMOND_LINE)
	Check("[TRK] hauteur : titre + lignes", tracker.height == 18 + 5 * 15, tracker.height)

	-- rafraîchi sur STAMP
	NS:JournalEarn("subzone", 378, "Camp Taurajo")
	Check("[TRK] STAMP : la liste suit (villages 2/3)", K.Lines():find("Villages de Les Tarides 2/3", 1, true), K.Lines())
	-- rafraîchi au changement de zone (Elwynn, Horde : pas de village ami)
	Mock.world.mapID = 1429
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	Check("[TRK] changement de zone : villages de la nouvelle zone", not K.Lines():find("Villages", 1, true)
		and K.Lines():find("Donjons de ton niveau", 1, true), K.Lines())
	Mock.world.mapID = 1413
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	-- rafraîchi à la montée de niveau, même si UnitLevel est en retard
	Mock:Fire("PLAYER_LEVEL_UP", 28)
	Check("[TRK] montée de niveau : palier à jour (niveau de l'événement)", K.Lines():find("niveau 28/30", 1, true), K.Lines())
	Mock:Fire("ZONE_CHANGED")
	Check("[TRK] niveau de l'événement : oublié après", K.Lines():find("niveau 27/30", 1, true), K.Lines())
	Mock.world.level = 28

	-- masquer d'un clic droit
	local first = tracker.lines[1].goal.id
	tracker.lines[1]:Click("LeftButton")
	Check("[TRK] clic gauche : rien de masqué", tracker.lines[1].goal.id == first)
	tracker.lines[1]:Click("RightButton")
	Check("[TRK] clic droit : objectif masqué", tracker.lines[1].goal.id ~= first and not K.Lines():find("Lanterne", 1, true), K.Lines())
	Check("[TRK] masquage retenu par personnage", NS:JournalData().dismissed[first] == true)
	Check("[TRK] une place libérée : le suivant monte", K.Lines():find("Donjons de ton niveau", 1, true), K.Lines())
	Mock:Fire("ZONE_CHANGED")
	Check("[TRK] masqué : le reste après un rafraîchissement", not K.Lines():find("Lanterne", 1, true))
	-- deux masqués sur six : quatre lignes, jamais un masqué pour boucher le trou
	local second = tracker.lines[1].goal.id
	tracker.lines[1]:Click("RightButton")
	Check("[TRK] deux masqués : quatre lignes, sans eux", not tracker.lines[5]:IsShown() and tracker.lines[4]:IsShown()
		and not K.Lines():find("Lanterne", 1, true), K.Lines())
	NS:JournalDismiss(second, false)
	Check("[TRK] remis : de retour dans le suivi", tracker.lines[5]:IsShown() and not NS:JournalData().dismissed[second])

	-- repli
	tracker.title:Click()
	Check("[TRK] clic sur le titre : replié", NS:DB().journalTrackerCollapsed == true and K.Lines() == ""
		and tracker.title.text.text == "Carnet (5)" and tracker.height == 18, tracker.title.text.text)
	Mock:Fire("ZONE_CHANGED")
	Check("[TRK] replié : le reste au rafraîchissement", K.Lines() == "" and tracker:IsShown())
	tracker.title:Click()
	Check("[TRK] second clic : déplié", NS:DB().journalTrackerCollapsed == false and tracker.lines[5]:IsShown())

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

-- 6. Onglet « Objectifs » de la fenêtre -------------------------------------------------
do
	Say("-- suivi du carnet : onglet Objectifs")
	K.Reset(27)
	K.Stamp("subzone", 380); K.Stamp("capital", 1637)
	NS:DB().journalTracker = false              -- l'onglet ne dépend pas du suivi à l'écran
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	Check("[TRK] onglet Objectifs : le premier, ouvert d'office", f.kind == "goals" and f.tabs.goals
		and f.tabs.goals.text.text == "Objectifs")
	Check("[TRK] onglet Objectifs : tous les objectifs (6, pas 5)", f.counter.text == "Objectifs : 6", f.counter.text)
	local row = f.lines[1]
	Check("[TRK] ligne : nom, progression, barre", row.name.text == "Lanterne — villages" and row.detail.text:find("18/25", 1, true)
		and row.bar:IsShown() and math.abs(row.bar.ratio - 0.72) < 1e-6, row.name.text)
	Check("[TRK] la sixième ligne aussi (le suivi s'arrête à 5)", f.lines[6]:IsShown() and f.lines[6].name.text:find("Donjons", 1, true))
	Check("[TRK] invitation au clic droit", f.position.text == NS.L.JRN_GOALS_HINT)
	row.scripts.OnMouseUp(row, "RightButton")
	Check("[TRK] clic droit dans l'onglet : masqué, rangé à la fin", f.lines[6].name.text == "Lanterne — villages"
		and f.lines[6].detail.text:find("masqué", 1, true), f.lines[6].name.text)
	f.lines[6].scripts.OnMouseUp(f.lines[6], "RightButton")
	Check("[TRK] second clic droit : remis", f.lines[1].name.text == "Lanterne — villages"
		and not NS:JournalData().dismissed["comp:orn:Lanterne"])
	f.lines[1].scripts.OnMouseUp(f.lines[1], "LeftButton")
	Check("[TRK] clic gauche : rien", not NS:JournalData().dismissed["comp:orn:Lanterne"])
	f.tabs.capital:Click()
	Check("[TRK] autres onglets : pas de barre par ligne", not f.lines[1].bar:IsShown() and f.counter.text == "Capitales : 1 / 6")
	f.tabs.goals:Click()
	Check("[TRK] retour aux objectifs", f.kind == "goals" and f.lines[1].bar:IsShown())
	-- montée de niveau fenêtre ouverte : l'onglet suit
	Mock.world.level = 29
	Mock:Fire("PLAYER_LEVEL_UP", 29)
	Check("[TRK] fenêtre ouverte : objectifs rafraîchis", f.lines[1].name.text == "Palier 30 : niveau"
		and f.lines[1].detail.text:find("29/30", 1, true), f.lines[1].name.text)
	-- une seule fenêtre à la fois
	NS:ToggleOptions()
	Check("[TRK] une seule fenêtre : les réglages ferment le carnet", not f:IsShown())
	NS.optionsFrame:Hide()
	NS.optionsFrame = nil
	-- rien à faire : invitation
	K.Reset(60)
	NS.CompanionNextUnlocks = nil
	for _, id in ipairs({ 1657, 1537, 1519, 1637, 1638, 1497 }) do K.Stamp("capital", id) end
	for key in pairs(NS.DUNGEONS) do K.Stamp("dungeon", key) end
	Mock.world.mapID = 7777
	NS:ToggleJournal(true)
	Check("[TRK] onglet vide : message", NS.journalFrame.empty.text == NS.L.JRN_GOALS_EMPTY and not NS.journalFrame.lines[1]:IsShown())
	NS.journalFrame:Hide()
end

-- ipairs sur la liste : une globale absente avant (nil) doit le redevenir
for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
C_Map.GetAreaInfo = saved.GetAreaInfo
NS.CompanionNextUnlocks = saved.NextUnlocks
if NS.journalTracker then NS.journalTracker:Hide() end
