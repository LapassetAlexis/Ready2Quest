-- QuestCompanion 2.11.0 : carnet (patch B) : plaques de chiffres (B1),
-- étoiles des Créatures (B2), bande résumé des Missions (B3), intertitres à
-- l'encre (B4), « Localiser » (B6), confirmation au style Azeroth (B8) ;
-- fiche 08 (rôles déclarés), 13 (filtre et recherche des zones), 14 (colonne
-- de navigation en tableau de bord), 27 (état du carnet mémorisé).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local C = { saved = {} }
local GLOBALS = { "UnitLevel", "UnitFactionGroup", "C_Map", "UiMapPoint", "C_SuperTrack", "InCombatLockdown", "UnitAffectingCombat" }
for _, name in ipairs(GLOBALS) do C.saved[name] = rawget(_G, name) end
local FIELDS = { "journalFrame", "trainerFrame", "companionFrame", "companionBubble", "effectsConfirm" }
local INK = NS.AZEROTH_INK

function C.Reset(style)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle = nil
	NS.uiStyleCache = {}
	NS.errors = {}
	NS.carnetInkMisses = nil
	NS.mapPin = nil
	NS:DB().journalState = nil
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
	NS:CompanionData().tutoDone = true
end
function C.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = C.saved[name] end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle = nil
	NS.uiStyleCache = {}
	NS:DB().journalState = nil
	NS.mapPin = nil
	ResetWorld()
end
local function Open(kind)
	local frame = NS:ToggleJournal(true)
	if kind then NS:SelectJournalKind(kind) end
	return frame
end
local function Ratio(role)
	local r = NS.AZEROTH_CONTRAST[role]
	return r and NS.AzerothContrast(INK[r[1]], r[2]) or 0
end
local function Same(c, ink) return c and ink and math.abs(c[1] - ink[1]) < 1e-6 and math.abs(c[2] - ink[2]) < 1e-6 and math.abs(c[3] - ink[3]) < 1e-6 end
-- l'API du repère, simulée
local function PinApi(can)
	local pins = { set = 0, clear = 0, track = 0 }
	_G.UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
	_G.C_Map = {
		SetUserWaypoint = function(point) pins.point = point; pins.set = pins.set + 1 end,
		ClearUserWaypoint = function() pins.point = nil; pins.clear = pins.clear + 1 end,
		HasUserWaypoint = function() return pins.point ~= nil end,
		CanSetUserWaypointOnMap = function() return can ~= false end,
		GetBestMapForUnit = function() return 1413 end,
	}
	_G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) if on then pins.track = pins.track + 1 end end }
	return pins
end

-- 1. Contraste : les nouveaux rôles, recalculés ------------------------------------------------------------
do
	Say("-- 2.11.0 : rôles mesurés du carnet")
	local roles = { "stat.value", "stat.label", "summary.label", "summary.count", "summary.detail", "mheader.label",
		"mheader.detail", "chip.trait", "plate.count", "preview.title", "shield.count", "pantry.count", "mark.giftGold",
		"mark.giftGrey", "field.text", "navSum.name", "navSum.label", "navSum.value", "dialog.title", "dialog.sub", "dialog.text" }
	local bad = {}
	for _, role in ipairs(roles) do
		local r = NS.AZEROTH_CONTRAST[role]
		local min = r and (r[4] >= 16 and 3 or 4.5)
		if not r or Ratio(role) < min or r[3] < min then bad[#bad + 1] = role .. "=" .. string.format("%.2f", Ratio(role)) end
	end
	Check("[C211] 21 rôles nouveaux ou remesurés : tous au seuil", #bad == 0, table.concat(bad, ", "))
	Check("[C211] étiquette du caractère : #5a3a14, blanc 10:1", math.abs(NS.AZEROTH_MISSION.chipTrait[1] - 0.353) < 1e-6
		and Ratio("chip.trait") > 10)
	-- B2 : le cerne des étoiles (objet graphique, 3:1) sur le pire fond d'une ligne claire
	local edge = NS.MEN_STAR.edge
	Check("[C211] étoiles : cerne brun ≥ 3:1 sur la ligne claire", NS.AzerothContrast(edge, NS.AZEROTH_CONTRAST["men.name"][2]) >= 3,
		string.format("%.2f", NS.AzerothContrast(edge, NS.AZEROTH_CONTRAST["men.name"][2])))
end

-- 2. B1 : plaques de chiffres ------------------------------------------------------------------------------
do
	Say("-- 2.11.0 : B1, page Compagnon")
	C.Reset("sobre")
	local f = Open("evolution")
	local S = NS.JOURNAL_STAT_LAYOUT
	local tile = f.evo.stats.missions
	local vp, lp = tile.value.lastPoint, tile.label.lastPoint
	Check("[C211] plaques plus hautes, chiffre et libellé centrés", S.h == 58 and tile.height == 58 and vp.point == "CENTER"
		and lp.point == "CENTER" and vp.y > 0 and lp.y < 0, tostring(tile.height))
	Check("[C211] libellés courts « missions », « parcourus »", tile.label.text == "missions"
		and f.evo.stats.km.label.text == "parcourus", f.evo.stats.km.label.text)
	C.Reset("azeroth")
	f = Open("evolution")
	tile = f.evo.stats.days
	Check("[C211] Azeroth : chiffre et libellé à leur rôle", tile.value.azRole == "stat.value" and tile.label.azRole == "stat.label"
		and Same(tile.label.textColor, INK.statLabel))
	C.Done()
end

-- 3. B2 : étoiles des Créatures ----------------------------------------------------------------------------
do
	Say("-- 2.11.0 : B2, étoiles des Créatures")
	C.Reset("azeroth")
	local f = Open("menagerie")
	local row = f.men.items[1]
	Check("[C211] trois étoiles par ligne, atlas du jeu, construites une fois", row.stars and #row.stars == 3
		and row.stars[1].star.atlas == "auctionhouse-icon-favorite" and row.stars[1].edge.atlas == "auctionhouse-icon-favorite")
	NS.MenagerieRowStars(row, 2)
	local s1, s3 = row.stars[1], row.stars[3]
	Check("[C211] 2 sur 3 : pleines dorées, la 3e brun grisé, cerne sombre", s1.star.full and not s3.star.full
		and Same(s1.star.vertex, NS.MEN_STAR.full) and Same(s3.star.vertex, NS.MEN_STAR.empty)
		and Same(s1.edge.vertex, NS.MEN_STAR.edge) and s1.edge:IsShown() and s1.edge.width > s1.star.width)
	NS.MenagerieRowStars(row, nil)
	Check("[C211] sans capture : pas d'étoile", not s1.star:IsShown() and not s1.edge:IsShown())
	C.Done()
end

-- 4. B3 / B4 : page Missions -------------------------------------------------------------------------------
do
	Say("-- 2.11.0 : B3, B4, page Missions")
	C.Reset("azeroth")
	local f = Open("day")
	local MIS = NS.JOURNAL_MISSIONS_LAYOUT
	local plaque = f.day.summary.week
	Check("[C211] bande résumé : 56 px, détail sur deux lignes", MIS.sumH == 56 and plaque.height == 56
		and plaque.detail.wordWrap ~= false and plaque.detail.lastPoint.y == MIS.sumDetailY)
	local pip = plaque.pips[1]
	Check("[C211] pastilles en bas, sous le détail", pip.lastPoint.point == "BOTTOMLEFT" and pip.lastPoint.y == MIS.sumPipY
		and -MIS.sumDetailY + MIS.sumDetailH <= MIS.sumH - MIS.sumPipY - 5)
	Check("[C211] compte sur la ligne du titre", plaque.count.lastPoint.point == "TOPRIGHT"
		and plaque.count.lastPoint.y == plaque.label.lastPoint.y)
	local title = f.day.groups.trait
	Check("[C211] intertitre : encre sur parchemin, filet dessous", title.azSurface == "light" and title.azRule:IsShown()
		and title.label.azRole == "mheader.label" and Same(title.label.textColor, INK.head))
	Check("[C211] étiquette du caractère : aplat foncé, texte blanc", Same(f.day.chips.trait.bg.vertex, NS.AZEROTH_MISSION.chipTrait)
		and f.day.chips.trait.text.azRole == "chip.trait")
	C.Done()
end

-- 5. B6 : Localiser -----------------------------------------------------------------------------------------
do
	Say("-- 2.11.0 : B6, « Localiser »")
	C.Reset("sobre")
	local savedQ, savedC = NS.ZONE_QUEST_POS, NS.ZONE_CREATURE_POS
	NS.ZONE_QUEST_POS = { [1413] = "100\t500250\n200\t010999\n" }
	NS.ZONE_CREATURE_POS = { [1413] = "3201\t300700\n" }
	local x, y = NS:ZonePoint("quest", 1413, 200)
	Check("[C211] point d'une quête lu sans découper la chaîne", x == 0.01 and y == 0.999 and NS:ZonePoint("quest", 1413, 100) == 0.5
		and NS:ZonePoint("quest", 1413, 20) == nil and NS:ZonePoint("quest", 1411, 100) == nil)
	_G.C_Map, _G.UiMapPoint = nil, nil
	Check("[C211] sans API : pas de repère", NS:MapPinAvailable(1413) == false and NS:MapPinToggle("quest:200", 1413, x, y) == false)
	local pins = PinApi()
	local items = NS.JournalProgressItems
	NS.JournalProgressItems = function() return { { id = 200, name = "Consumé par la haine", detail = "niveau 20" },
		{ id = 300, name = "Sans donneur", detail = "niveau 3" } }, {} end
	local f = Open("progress")
	f.progPart = "quests"
	NS:RefreshJournal()
	local pane = f.prog
	Check("[C211] rien de choisi : pas de bouton", not pane.locate:IsShown())
	pane.items[1]:GetScript("OnClick")(pane.items[1])
	Check("[C211] quête choisie : « Localiser » sur sa ligne", f.progQuest == 200 and pane.locate:IsShown()
		and pane.locate.lastPoint.relTo == pane.items[1] and pane.locate.text.text == "Localiser")
	pane.locate:GetScript("OnClick")(pane.locate)
	Check("[C211] clic : repère posé (carte, coordonnées), suivi à l'écran", pins.set == 1 and pins.point.map == 1413
		and pins.point.x == 0.01 and pins.track == 1 and pane.locate.text.text == "Effacer")
	pane.locate:GetScript("OnClick")(pane.locate)
	Check("[C211] 2e clic : repère retiré", pins.clear == 1 and pins.point == nil and pane.locate.text.text == "Localiser")
	pane.items[2]:GetScript("OnClick")(pane.items[2])
	Check("[C211] quête sans point connu : pas de bouton", f.progQuest == 300 and not pane.locate:IsShown())
	NS.JournalProgressItems = items
	-- la créature choisie
	PinApi()
	local preview = f.men and f.men.preview
	if preview then
		preview.entry = nil
		NS:JournalPreviewMenagerie({ npc = 3201, known = true, name = "Kodo", zoneID = 1413, class = "normal" })
		Check("[C211] fiche d'une créature : « Localiser » si son point est connu", preview.locate:IsShown())
		NS:JournalPreviewMenagerie({ npc = 9999, known = true, name = "Inconnu", zoneID = 1413, class = "normal" })
		Check("[C211] … caché sinon", not preview.locate:IsShown())
	end
	NS.ZONE_QUEST_POS, NS.ZONE_CREATURE_POS = savedQ, savedC
	Check("[C211] tables générées : points des quêtes et des créatures", type(savedQ) == "table" and type(savedC) == "table"
		and NS:ZonePoint("quest", 1411, 784) ~= nil)
	C.Done()
end

-- 6. B8 : confirmation au style Azeroth -----------------------------------------------------------------
do
	Say("-- 2.11.0 : B8, « Changer de compagnon ? »")
	C.Reset("azeroth")
	local az = NS:EnsureEffectsConfirm()
	Check("[C211] Azeroth : parchemin, encadré en bois, encres mesurées", az and az.azDialog and az.azBg.texture == 130661
		and az.azWoodBorder ~= nil and not az.bg:IsShown() and az.title.azRole == "dialog.title" and az.text.azRole == "dialog.text"
		and Same(az.text.textColor, INK.ink))
	Check("[C211] … bouton principal rouge, Annuler brun", az.ok.azSkin == "red" and az.cancel.azSkin == "brown")
	Check("[C211] … construite une fois", NS:EnsureEffectsConfirm() == az)
	NS:DB().companionStyle = "sobre"
	local sobre = NS:EnsureEffectsConfirm()
	Check("[C211] Sobre : sa propre fenêtre, inchangée", sobre and sobre ~= az and not sobre.azDialog and NS.effectsConfirm == sobre)
	NS:DB().companionStyle = "azeroth"
	Check("[C211] retour en Azeroth : la même fenêtre reprise", NS:EnsureEffectsConfirm() == az)
	C.Done()
end

-- 7. Fiche 08 : aucun texte repeint par devinette -----------------------------------------------------------
do
	Say("-- 2.11.0 : fiche 08, rôles déclarés")
	C.Reset("azeroth")
	for _, kind in ipairs({ "evolution", "menagerie", "feats", "day", "progress", "guide" }) do Open(kind) end
	local f = NS.journalFrame
	local misses = NS.carnetInkMisses or {}
	Check("[C211] carnet : aucun texte au repli « assombri »", #misses == 0, table.concat(misses, " | "))
	local unknownRole = {}
	for _, fs in ipairs(f.azReg.texts) do
		if fs.azRole and not NS.AZEROTH_CONTRAST[fs.azRole] then unknownRole[#unknownRole + 1] = fs.azRole end
	end
	Check("[C211] chaque rôle posé existe dans la table", #unknownRole == 0, table.concat(unknownRole, ", "))
	local roled, total = 0, 0
	for _, fs in ipairs(f.azReg.texts) do
		total = total + 1
		if fs.azRole then roled = roled + 1 end
	end
	Check("[C211] les textes repeints portent leur rôle", roled > 0 and roled <= total, roled .. " / " .. total)
	local plate = f.azPlate
	if plate and plate.count then Check("[C211] case des points : rôle plate.count", plate.count.azRole == "plate.count") end
	local pantryOK = true
	for _, button in pairs(f.pantry or {}) do
		if button.count and (button.count.azRole ~= "pantry.count" or not (button.azShade and button.azShade:IsShown())) then pantryOK = false end
	end
	Check("[C211] garde-manger : chiffre sur son ombre, rôle pantry.count", pantryOK)
	C.Done()
end

-- 8. Fiche 13 : filtre et recherche des zones ----------------------------------------------------------------
do
	Say("-- 2.11.0 : fiche 13, liste des zones")
	C.Reset("sobre")
	_G.UnitLevel = function() return 8 end
	_G.UnitFactionGroup = function() return "Horde" end
	local all = {
		{ id = 1411, name = "Durotar", seen = true, here = true, lo = 1, hi = 10, percent = 40 },
		{ id = 1429, name = "Elwynn", seen = false, lo = 1, hi = 10 },
		{ id = 1412, name = "Mulgore", seen = false, lo = 1, hi = 10 },
		{ id = 1440, name = "Ashenvale", seen = true, lo = 18, hi = 30, percent = 20 },
		{ id = 1434, name = "Strangleorn", seen = false, lo = 30, hi = 45 },
		{ id = 1413, name = "Barrens", seen = true, lo = 10, hi = 25, percent = 100 },
	}
	local function Ids(list) local out = {} for _, z in ipairs(list) do out[#out + 1] = z.id end return table.concat(out, ",") end
	Check("[C211] « Pour moi » : ici, commencées, de mon niveau, sans l'autre faction",
		Ids(NS:JournalFilterZones(all, "mine")) == "1411,1412,1440,1413", Ids(NS:JournalFilterZones(all, "mine")))
	Check("[C211] « Commencées » : les zones vues", Ids(NS:JournalFilterZones(all, "seen")) == "1411,1440,1413")
	Check("[C211] « Toutes » : tout", #NS:JournalFilterZones(all, "all") == 6)
	Check("[C211] recherche : sur le nom, sans casse", Ids(NS:JournalFilterZones(all, "all", "MUL")) == "1412")
	local f = Open("progress")
	local pane = f.prog
	Check("[C211] filtre « Pour moi » par défaut, au-dessus des zones", pane.zoneFilter:GetValue() == "mine"
		and pane.zoneSearch ~= nil and pane.zones[1].lastPoint.y < pane.zoneFilter.lastPoint.y)
	pane.zoneFilter:Choose("all")
	Check("[C211] filtre choisi : mémorisé", f.progFilter == "all" and NS:DB().journalState.progFilter == "all")
	local calls, base = 0, NS.JournalAllZones
	NS.JournalAllZones = function(...) calls = calls + 1; return base(...) end
	pane.zoneSearch:SetText("zz")
	pane.zoneSearch.scripts.OnTextChanged(pane.zoneSearch)
	Mock:RunTimers()
	NS.JournalAllZones = base
	Check("[C211] recherche : liste vide, message affiché", f.progSearch == "zz" and #pane.zoneList == 0 and pane.zoneEmpty:IsShown())
	Check("[C211] un cran de molette ne recalcule pas les zones", (function()
		local n = 0
		NS.JournalAllZones = function(...) n = n + 1; return base(...) end
		NS:ScrollJournal(-1)
		NS.JournalAllZones = base
		return n == 0
	end)())
	C.Done()
end

-- 9. Fiche 14 : colonne de navigation en tableau de bord ------------------------------------------------------
do
	Say("-- 2.11.0 : fiche 14, colonne de navigation")
	C.Reset("sobre")
	local f = Open("evolution")
	local box = f.navSummary
	Check("[C211] trois blocs sous les entrées", box and box.pet and box.zone and box.missions and #box.pet.needs == 4)
	local before = #Mock.frames
	NS:RefreshJournal(); NS:RefreshJournal()
	Check("[C211] rafraîchi sans rien créer", #Mock.frames == before, #Mock.frames .. " / " .. before)
	Check("[C211] nom et humeur du compagnon", box.pet.name.text:find(NS:CompanionName(), 1, true) ~= nil, box.pet.name.text)
	box.missions:GetScript("OnClick")(box.missions)
	Check("[C211] clic sur les missions : la page Missions", f.kind == "day")
	box.pet:GetScript("OnClick")(box.pet)
	Check("[C211] clic sur le compagnon : sa page", f.kind == "evolution")
	C.Reset("azeroth")
	f = Open("evolution")
	box = f.navSummary
	Check("[C211] Azeroth : encres mesurées sur le parchemin de la colonne", box.pet.name.azRole == "navSum.name"
		and box.pet.needs[1].label.azRole == "navSum.label" and box.missions.rows[2].label.azRole == "navSum.label")
	C.Done()
end

-- 10. Fiche 27 : état mémorisé, recherche différée -------------------------------------------------------------
do
	Say("-- 2.11.0 : fiche 27, état du carnet")
	C.Reset("sobre")
	local f = Open("menagerie")
	local pane = f.men
	pane.rank:Choose("rare")
	pane.sort:Choose("name")
	pane.stateRow.chips[2]:GetScript("OnClick")(pane.stateRow.chips[2])
	NS:JournalProgressPart("quests")
	local state = NS:DB().journalState
	Check("[C211] choix notés dans journalState", state.menRank == "rare" and state.menSort == "name" and state.progPart == "quests"
		and state.menState ~= nil)
	state.menState = "obsolete"
	f:Hide()
	NS.journalFrame = nil
	NS.uiStyleCache = {}
	f = Open("menagerie")
	Check("[C211] carnet reconstruit : choix retrouvés, valeur inconnue ignorée", f.menRank == "rare" and f.menSort == "name"
		and f.progPart == "quests" and f.menState == "all" and f.men.rank:GetValue() == "rare")
	NS:OpenMenagerieZone(1413)
	Check("[C211] ouvrir une zone depuis sa fiche ne touche pas aux choix", NS:DB().journalState.menRank == "rare")
	local refresh, count = NS.RefreshJournal, 0
	NS.RefreshJournal = function(...) count = count + 1; return refresh(...) end
	for _, text in ipairs({ "k", "ko", "kod", "kodo" }) do
		f.men.search:SetText(text)
		f.men.search.scripts.OnTextChanged(f.men.search)
	end
	local typed = count
	Mock:RunTimers()
	NS.RefreshJournal = refresh
	Check("[C211] recherche : un seul rafraîchissement après la frappe", typed == 0 and count == 1 and f.menSearch == "kodo",
		typed .. " / " .. count)
	C.Done()
end
