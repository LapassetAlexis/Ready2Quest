-- Carnet 1.5.0 : page Complétion (JournalCompletion.lua). Liste des zones à
-- gauche, carte de la zone (%, paliers et ce qu'ils donnent, coffre, suivi),
-- cartes de part qui choisissent la liste, ligne du bestiaire vers la
-- Ménagerie, molette.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- Mocks propres à ce fichier, restaurés à la fin
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

-- 1. Enregistrement et chaînes -------------------------------------------------------------------
do
	Say("-- carnet : Complétion, enregistrement")
	local def = NS.JOURNAL_PANES and NS.JOURNAL_PANES.progress
	Check("[PROG] page externe « progress » (champ prog)", def and def.field == "prog" and type(def.build) == "function"
		and type(def.refresh) == "function" and type(def.scroll) == "function")
	Check("[PROG] titre et sous-titre", def and NS.L[def.title] == "Exploration"
		and NS.L[def.subtitle]:find("paliers, coffres", 1, true) ~= nil)
	local strings, missing = NS.JOURNAL_PROGRESS_STRINGS, {}
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" then missing[#missing + 1] = "en:" .. key end
		if NS.L[key] ~= value then missing[#missing + 1] = "fr:" .. key end
	end
	for key in pairs(strings.en) do if strings.fr[key] == nil then missing[#missing + 1] = "fr?" .. key end end
	Check("[PROG] chaînes en français et en anglais", #missing == 0, table.concat(missing, ", "))
	local all = ""
	for _, value in pairs(strings.fr) do all = all .. value end
	Check("[PROG] tutoiement", not all:find("[Vv]ous"))
end

-- 2. Ouverture : la zone d'ici, la liste des zones ----------------------------------------------
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
	Check("[PROG] page construite", pane ~= nil and pane.card ~= nil and #pane.zones > 10 and #pane.items > 5)
	Check("[PROG] entrée « Exploration » au menu", f.sections.progress and f.sections.progress.text.text == "Exploration")
	NS:SelectJournalKind("progress")
	Check("[PROG] page affichée seule", f.kind == "progress" and pane:IsShown() and not f.evo:IsShown())
	Check("[PROG] en-tête : titre de la page", f.header.title.text == "Exploration", f.header.title.text)
	Check("[PROG] anciens noms (zones, completion) : la Complétion", (function()
		NS:SelectJournalKind("zones"); local a = f.kind
		NS:SelectJournalKind("completion"); return a == "progress" and f.kind == "progress"
	end)())
	Check("[PROG] par défaut : la zone où tu es", f.zoneID == 1413 and pane.name.text == "Les Tarides (ici)"
		and pane.levels.text == "niveaux 10-25", pane.name.text .. " / " .. pane.levels.text)

	local list = NS:JournalAllZones("all", "lvl")
	local ordered = true
	for index = 2, #pane.zones do
		local a, b = pane.zones[index - 1].zone, pane.zones[index].zone
		if a and b and a.lo > b.lo then ordered = false end
	end
	Check("[PROG] toutes les zones, par niveau", #list > #pane.zones and ordered)
	Check("[PROG] lignes = la liste à partir du décalage", pane.zones[1].zoneID == list[(f.progOffset or 0) + 1].id)
	local here = P.Row(pane, 1413)
	Check("[PROG] la zone choisie est visible, surlignée (liseré or)", here and here.selected and here.accent:IsShown()
		and here.accent.vertex[1] == NS.Theme.GOLD[1])
	Check("[PROG] « ici » sur la zone où tu es", here and here.here:IsShown() and here.here.text == "ici")
	local ghost
	for _, row in ipairs(pane.zones) do if row:IsShown() and row.zone and not row.zone.seen then ghost = row end end
	Check("[PROG] jamais visitée : en retrait, « — », sans barre", ghost and ghost.alpha < 1 and ghost.percent.text == "—"
		and not ghost.bar:IsShown() and not ghost.here:IsShown())
	local other
	for _, row in ipairs(pane.zones) do if row:IsShown() and row.zoneID ~= 1413 then other = row end end
	Check("[PROG] les autres : pas surlignées", other and not other.selected and not other.accent:IsShown())

	-- une seule part suivie (villages) : pas de %, on dit pourquoi
	Check("[PROG] une seule activité : « — » et pourquoi", pane.percent.text == "—" and pane.nopct:IsShown()
		and pane.nopct.text == NS.L.JRN_ZONE_NOPCT and not pane.bar:IsShown() and not pane.marks[1]:IsShown())
	Check("[PROG] suivi à l'écran dans la carte, coché pour la zone d'ici", pane.watch:IsShown() and pane.watch.checked == true
		and pane.watchLabel.text == NS.L.JRN_WATCH, tostring(pane.watch:IsShown()) .. "/" .. tostring(pane.watch.checked)
		.. "/" .. tostring(pane.watchLabel.text))
	pane.watch:Click()
	Check("[PROG] clic sur le suivi : décochée", NS:JournalIsWatched(1413) == false and pane.watch.checked == false)
	pane.watch:Click()
	Check("[PROG] … et recochée", NS:JournalIsWatched(1413) == true)
end

-- 3. Parts et liste -----------------------------------------------------------------------------
do
	Say("-- carnet : Complétion, parts")
	local explore, craft, quests = pane.parts.explore, pane.parts.craft, pane.parts.quests
	Check("[PROG] trois cartes : Lieux, Métiers, Quêtes", explore and craft and quests
		and explore.label.text == "Lieux" and craft.label.text == "Métiers" and quests.label.text == "Quêtes")
	Check("[PROG] Exploration : 1/3, choisie par défaut", explore.count.text == "1/3" and explore.selected
		and explore.accent:IsShown() and not craft.selected, explore.count.text)
	Check("[PROG] Métiers sans métier : estompée", craft.dim and craft.alpha < 1 and craft.count.text == "—")
	Check("[PROG] Quêtes sans liste pour ce client : grisée", quests.dim and quests.alpha < 1)
	Check("[PROG] en-tête de la liste : la part", pane.head.text == "Villages : 1/3", pane.head.text)
	local first, last = pane.items[1], pane.items[3]
	Check("[PROG] à faire d'abord, au trait", first.item and not first.item.done and first:IsShown()
		and first.status.texture == NS.Theme.DIAMOND_LINE and first.detail.text:find("à visiter", 1, true))
	Check("[PROG] fait ensuite, losange plein", last.item and last.item.done and last.text.text == "The Crossroads"
		and last.status.texture == NS.Theme.DIAMOND, last.text.text)
	Check("[PROG] rien d'autre, pas de pagination", not pane.items[4]:IsShown() and pane.listPager.position.text == ""
		and pane.empty.text == "")
	quests:Click()
	Check("[PROG] clic sur Quêtes : la liste change", f.progPart == "quests" and quests.selected and not explore.selected
		and not pane.items[1]:IsShown() and pane.empty.text == NS.L.JRN_ACT_NO_QUESTS, pane.empty.text)
	craft:Click()
	Check("[PROG] Métiers : son message, et aucun métier repéré", f.progPart == "craft"
		and pane.empty.text == NS.L.JRN_ACT_EMPTY_craft .. "\n" .. NS.L.GATHER_PROFS_NONE, pane.empty.text)
	explore:Click()
	Check("[PROG] retour à Exploration", f.progPart == "explore" and pane.items[1]:IsShown())
	quests.onEnter(quests)
	local tip = table.concat(_G.GameTooltip.lines or {}, " ")
	Check("[PROG] survol de Quêtes : pas de liste pour ce client", tip:find(NS.L.JRN_ACT_NO_QUESTS, 1, true) ~= nil, tip)
	quests.onLeave(quests)
end

-- 4. Pourcentage, paliers, coffre ---------------------------------------------------------------
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
	Check("[PROG] deux activités : grand % et barre", done and #done.parts >= 2
		and pane.percent.text == done.percent .. " %" and pane.bar:IsShown() and not pane.nopct:IsShown(), pane.percent.text)
	Check("[PROG] zone avancée (25 et 50 franchis, pas 100)", done.percent >= 50 and done.percent < 100, done.percent)
	local states = true
	for _, tile in ipairs(pane.marks) do
		local reached = done.percent >= tile.mark
		if tile.reached ~= reached or (tile.label.textColor[1] == NS.Theme.GOLD[1]) ~= reached
			or tile.accent:IsShown() ~= reached or not tile:IsShown() then states = false end
	end
	Check("[PROG] quatre paliers ; franchis en or", #pane.marks == 4 and states)
	Check("[PROG] 25 % : friandise + Appât savoureux", pane.marks[1].label.text == "25 %"
		and pane.marks[1].gift.text == "friandise + Appât savoureux", pane.marks[1].gift.text)
	Check("[PROG] 50 % : friandise + Lasso tressé", pane.marks[2].gift.text == "friandise + Lasso tressé", pane.marks[2].gift.text)
	Check("[PROG] 75 % : Festin + une aide de capture", pane.marks[3].gift.text == "Festin + une aide de capture",
		pane.marks[3].gift.text)
	Check("[PROG] 100 % : le coffre et son palier", pane.marks[4].gift.text == "coffre (palier 1)", pane.marks[4].gift.text)
	Check("[PROG] pas de coffre : pas de bouton", not pane.openChest:IsShown())
	local row = P.Row(pane, 1413)
	Check("[PROG] la liste suit : % de la zone", row and row.percent.text == done.percent .. " %" and row.bar:IsShown())

	NS:ChestData()[1413] = { tier = 1, name = "Les Tarides" }
	NS:RefreshJournal()
	Check("[PROG] coffre gagné : « Ouvrir le coffre », liseré or", pane.openChest:IsShown()
		and pane.openChest.text.text == NS.L.JRN_OPEN_CHEST and pane.card.accent:IsShown()
		and pane.marks[4].gift.text == "coffre à ouvrir !")
	local opened
	NS.OpenChest = function(_, zoneID) opened = zoneID end
	pane.openChest:Click()
	NS.OpenChest = saved.OpenChest
	Check("[PROG] clic : le coffre de cette zone", opened == 1413)
	NS:ChestData()[1413].opened = true
	NS:RefreshJournal()
	Check("[PROG] coffre ouvert : plus de bouton", not pane.openChest:IsShown() and pane.marks[4].gift.text == "coffre ouvert")
	NS:ChestData()[1413] = nil
end

-- 5. Bestiaire -> Ménagerie ---------------------------------------------------------------------
do
	Say("-- carnet : Complétion, bestiaire")
	NS:RefreshJournal()
	local counts = NS:BestiaryCounts(1413)
	local expected = string.format("Bestiaire : %d/%d abattues (nommés %d/%d)", counts.killed, counts.seen,
		counts.namedKilled, counts.namedSeen)
	Check("[PROG] une ligne : abattues et nommés", pane.bestiary.text:find(expected, 1, true) == 1
		and pane.bestiary.text:find("Créatures", 1, true), pane.bestiary.text)
	Check("[PROG] bouton Créatures", pane.toMen:IsShown() and pane.toMen.text.text == "Créatures")
	pane.toMen:Click()
	Check("[PROG] clic : la Créatures sur cette zone", f.kind == "menagerie" and f.menZone == 1413 and not pane:IsShown())
	NS:SelectJournalKind("progress")
	Check("[PROG] retour : même zone", f.kind == "progress" and f.zoneID == 1413)
end

-- 6. Choix d'une zone, il tient jusqu'à la fermeture ---------------------------------------------
do
	Say("-- carnet : Complétion, choix de zone")
	for _ = 1, 40 do f.scripts.OnMouseWheel(f, 1) end
	Check("[PROG] molette vers le haut : en butée", f.progOffset == 0)
	local elwynn = P.Row(pane, 1429)
	Check("[PROG] Elwynn (1-10) en haut de la liste", elwynn ~= nil)
	if elwynn then elwynn:Click() end
	Check("[PROG] clic : la zone choisie", f.zoneID == 1429 and f.zonePicked and pane.name.text == "Forêt d'Elwynn"
		and P.Row(pane, 1429).selected and not (P.Row(pane, 1413) and P.Row(pane, 1413).selected), pane.name.text)
	Check("[PROG] Elwynn (Horde) : pas de village ami", pane.empty.text == NS.L.JRN_ACT_EMPTY_explore, pane.empty.text)
	Check("[PROG] la liste ne bouge pas au clic", f.progOffset == 0)
	Mock:Fire("ZONE_CHANGED")
	Check("[PROG] le choix tient tant que la fenêtre est ouverte", f.zoneID == 1429)
	f:Hide()
	NS:ToggleJournal(true)
	Check("[PROG] rouverte : la Complétion, de retour sur la zone d'ici", f.kind == "progress" and f.zoneID == 1413
		and P.Row(pane, 1413) ~= nil, f.kind)
	NS:OpenJournalZone(1429)
	Check("[PROG] ouvrir une zone (objectif) : la Complétion sur elle", f.kind == "progress" and f.zoneID == 1429
		and P.Row(pane, 1429) and P.Row(pane, 1429).selected)
end

-- 7. Molette et pagination ----------------------------------------------------------------------
do
	Say("-- carnet : Complétion, molette")
	local list = NS:JournalAllZones("all", "lvl")
	local page = #pane.zones
	f.progOffset = 0
	NS:RefreshJournal()
	f.scripts.OnMouseWheel(f, -1)
	Check("[PROG] molette : trois zones plus bas", f.progOffset == 3 and pane.zones[1].zoneID == list[4].id, f.progOffset)
	for _ = 1, 100 do NS:ScrollJournal(-1) end
	Check("[PROG] butée en bas : la dernière zone visible", f.progOffset == #list - page
		and pane.zones[page].zoneID == list[#list].id, f.progOffset)
	Check("[PROG] position de la liste", pane.zonePager.position.text:find("/ " .. #list, 1, true) ~= nil,
		pane.zonePager.position.text)
	f.scripts.OnMouseWheel(f, 1)
	Check("[PROG] molette vers le haut", f.progOffset == #list - page - 3)

	-- une longue liste : à faire d'abord, pagination, molette sur la liste
	NS.JournalActivityRows = function(_, zoneID, activity)
		local rows = { { header = true, name = "Villages : 8/20" } }
		for index = 1, 20 do rows[#rows + 1] = { name = "Lieu " .. index, done = index % 2 == 0, detail = "d" } end
		return rows
	end
	NS:RefreshJournal()
	local items, step = pane.items, #pane.items
	local order = true
	for index, line in ipairs(items) do if line.item.done then order = false end end
	Check("[PROG] à faire d'abord", order and items[1].text.text == "Lieu 1" and items[2].text.text == "Lieu 3")
	Check("[PROG] pagination de la liste", pane.listPager.position.text == "1-" .. step .. " / 20"
		and pane.listPager.down:IsShown() and not pane.listPager.up:IsShown(), pane.listPager.position.text)
	pane.listPager.down:Click()
	Check("[PROG] chevron : page suivante", f.progItemOffset == step and items[1].text.text == f.progRows[step + 1].name)
	local zoneOffset = f.progOffset
	pane.itemArea.IsMouseOver = function() return true end
	f.scripts.OnMouseWheel(f, 1)
	pane.itemArea.IsMouseOver = nil
	Check("[PROG] molette sur la liste : une ligne, les zones ne bougent pas", f.progItemOffset == step - 1
		and f.progOffset == zoneOffset, f.progItemOffset)
	pane.parts.craft:Click()
	Check("[PROG] changer de part remonte en haut", f.progItemOffset == 0)
	pane.parts.explore:Click()
	NS.JournalActivityRows = saved.ActivityRows
end

-- 8. Mise en page : rien ne déborde -------------------------------------------------------------
do
	Say("-- carnet : Complétion, mise en page")
	local ui = NS.JournalUI
	local lastZone, lastItem = pane.zones[#pane.zones], pane.items[#pane.items]
	Check("[PROG] liste des zones : au-dessus de la pagination", P.Y(lastZone) - lastZone:GetHeight() > ui.PAGER_Y)
	Check("[PROG] liste de la part : au-dessus de la ligne du bestiaire", P.Y(lastItem) - lastItem:GetHeight() > ui.PAGER_Y)
	local cardBottom = P.Y(pane.card) - pane.card:GetHeight()
	Check("[PROG] cartes de part sous la carte de zone", P.Y(pane.parts[1]) < cardBottom)
	Check("[PROG] liste sous les cartes de part", P.Y(pane.items[1]) < P.Y(pane.parts[1]) - pane.parts[1]:GetHeight())
	local mark = pane.marks[4]
	Check("[PROG] paliers dans la carte", P.Y(mark) - mark:GetHeight() >= -pane.card:GetHeight()
		and select(4, mark:GetPoint()) + mark:GetWidth() <= pane.card:GetWidth())
	Check("[PROG] colonne de droite dans la zone utile", select(4, pane.card:GetPoint()) - ui.PAD + pane.card:GetWidth() <= ui.INNER)
	Check("[PROG] textes sans retour à la ligne : coupés à leur largeur", pane.name.width and pane.bestiary.width
		and pane.zones[1].name.width and pane.zones[1].name.width < pane.zones[1]:GetWidth())
end

-- 9. Aucune zone connue -------------------------------------------------------------------------
do
	Say("-- carnet : Complétion, aucune zone")
	f:Hide()
	P.Reset()
	Mock.world.mapID = 947
	NS:ToggleJournal(true)
	f = NS.journalFrame
	pane = f.prog
	NS:SelectJournalKind("progress")
	Check("[PROG] hors zone et carnet vide : un message, pas de carte", f.zoneID == nil and pane.none:IsShown()
		and pane.none.text == NS.L.JRN_ZONE_NONE and not pane.card:IsShown() and not pane.toMen:IsShown(), tostring(f.zoneID))
	Check("[PROG] la liste des zones reste là", pane.zones[1]:IsShown())
	f:Hide()
end

-- remise en état
for index = #NS.ZONE_PARTS, 1, -1 do if NS.ZONE_PARTS[index] == P.fakeQuests then table.remove(NS.ZONE_PARTS, index) end end
for _, name in ipairs(MOCKED) do _G[name] = saved[name] end
C_Map.GetAreaInfo = saved.GetAreaInfo
NS.ZONE_CREATURES, NS.ZONE_GATHERING, NS.ZONE_QUESTS = saved.ZONE_CREATURES, saved.ZONE_GATHERING, saved.ZONE_QUESTS
NS.OpenChest, NS.JournalActivityRows = saved.OpenChest, saved.ActivityRows
NS.journalFrame = nil
