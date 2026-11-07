-- Compagnon : missions de la semaine (Weekly.lua), récompenses des missions
-- (Daily.lua, ns.MissionGrant) et Ménagerie du carnet (Capture.lua,
-- ns:MenagerieList ; JournalWindow.lua).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local MS = { saved = {}, random = math.random }
local GLOBALS = { "date", "time", "C_DateAndTime" }
for _, name in ipairs(GLOBALS) do MS.saved[name] = rawget(_G, name) end

function MS.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "journalFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT = nil
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	MS.now, MS.left = 1000000, 3 * 86400
	_G.time = function() return MS.now end
	_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return MS.left end }
	_G.date = function(format) if format == "%Y-%m-%d" then return MS.day or "2026-11-05" end return "05/11/2026" end
	math.random = MS.random
	local data = NS:CompanionData()
	data.tutoDone, data.weekly, data.capture = true, nil, nil
	NS:TreatData().treatsInit = true
	NS:CompanionUpdateVisibility()
end
function MS.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = MS.saved[name] end
	math.random = MS.random
	ResetWorld()
end

-- 1. Semaine -----------------------------------------------------------------------------------
do
	Say("-- missions : semaine")
	MS.Reset()
	local week = NS:WeeklyId()
	MS.now, MS.left = MS.now + 86400, MS.left - 86400
	Check("[WEEK] même semaine d'un jour à l'autre (remise à zéro du serveur)", NS:WeeklyId() == week)
	MS.now, MS.left = MS.now + 3 * 86400, 5 * 86400
	Check("[WEEK] remise à zéro passée : autre semaine", NS:WeeklyId() ~= week)
	_G.C_DateAndTime = nil
	Check("[WEEK] sans l'API : la semaine du calendrier", NS:WeeklyId():sub(1, 1) == "w")
	_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return MS.left end }

	Check("[WEEK] tirage à la première zone", NS:WeeklyPoll() == true and #NS:WeeklyCurrent().missions == 3)
	Check("[WEEK] pas deux fois la même semaine", NS:WeeklyPoll() == false)
	local kinds, capture = {}, false
	for _, m in ipairs(NS:WeeklyCurrent().missions) do
		kinds[m.kind] = (kinds[m.kind] or 0) + 1
		if m.kind == "captures" or m.kind == "captureNamed" then capture = true end
	end
	local distinct = true
	for _, n in pairs(kinds) do if n > 1 then distinct = false end end
	Check("[WEEK] trois sortes différentes, dont une capture", distinct and capture)
	NS:DB().companionCapture = false
	NS:WeeklyDraw()
	capture = false
	for _, m in ipairs(NS:WeeklyCurrent().missions) do
		if m.kind == "captures" or m.kind == "captureNamed" then capture = true end
	end
	Check("[WEEK] capture coupée : pas de mission de capture", not capture)
	NS:DB().companionCapture = true
	Check("[WEEK] fin de semaine lisible", NS:WeeklyEndsText() == "5 j", tostring(NS:WeeklyEndsText()))
end

-- 2. Avancer et récompenser ----------------------------------------------------------------------
do
	Say("-- missions : semaine, avancer")
	MS.Reset()
	local weekly = NS:WeeklyData()
	weekly.week = NS:WeeklyId()
	weekly.missions = {
		{ kind = "kills", need = 3, have = 0, source = "week" },
		{ kind = "stamps", need = 1, have = 0, source = "week" },
		{ kind = "captureNamed", need = 1, have = 0, source = "week" },
	}
	local items = NS:CaptureData().items
	NS:MissionEvent("kills", 1)
	NS:MissionEvent("kills", 1)
	Check("[WEEK] les abattus du jour comptent pour la semaine", weekly.missions[1].have == 2 and not weekly.missions[1].done)
	NS:MissionEvent("kills", 5)
	Check("[WEEK] faite : plafonnée, lasso gagné", weekly.missions[1].done and weekly.missions[1].have == 3 and items.lasso == 1)
	NS:FireCallback("STAMP", { kind = "zone", name = "Zone", new = true })
	Check("[WEEK] un tampon compte", weekly.missions[2].done)
	NS:FireCallback("STAMP", { kind = "zone", name = "Zone", new = false })
	NS:WeeklyEvent("captures", 1)
	Check("[WEEK] une capture normale ne vaut pas un élite", not weekly.missions[3].done)
	local sifflets = items.sifflet
	NS:WeeklyEvent("captureNamed", 1)
	Check("[WEEK] les trois : sifflet et festin en plus", weekly.allDone and items.sifflet == sifflets + 1
		and NS:TreatCount("festin") >= 1)
	Check("[WEEK] … le compagnon s'en réjouit", NS.companionBubbleKey == "WEEKLY_ALL")
	NS:DB().companionMissions = false
	Check("[WEEK] missions coupées : rien ne bouge", NS:WeeklyEvent("kills", 1) == false)
	NS:DB().companionMissions = true
	Check("[WEEK] libellés", NS:WeeklyLabel({ kind = "captures", need = 6 }) == "Capture 6 créatures"
		and NS:WeeklyLabel({ kind = "captureNamed", need = 1 }) == "Capture un élite ou un rare")
end

-- 3. Récompenses des missions du jour ----------------------------------------------------------------
do
	Say("-- missions : récompenses")
	MS.Reset()
	local items = NS:CaptureData().items
	local got = NS:MissionGrant("zone")
	Check("[MISR] mission du jour : une friandise et un appât", #got == 2 and got[1].kind == "treat" and got[2].id == "appat"
		and items.appat == 1)
	got = NS:MissionGrant("allDaily")
	Check("[MISR] les trois du jour : festin et lasso", got[1].id == "festin" and got[2].id == "lasso")
	Check("[MISR] texte de la récompense", NS:MissionRewardText("zone") == "Gain : friandise + Appât savoureux",
		NS:MissionRewardText("zone"))
	NS:DB().companionCapture = false
	Check("[MISR] capture coupée : la friandise seule", #NS:MissionGrant("zone") == 1
		and NS:MissionRewardText("zone") == "Gain : friandise")
	NS:DB().companionCapture = true
	Check("[MISR] mission « captures » : faisable partout", NS:MissionFeasible("captures", nil) == true)
	-- une capture fait avancer la mission du jour et la semaine
	local daily = NS:DailyData()
	daily.day = NS:DailyToday()
	daily.missions = { { kind = "captures", need = 2, have = 0, source = "zone" } }
	local weekly = NS:WeeklyData()
	weekly.week, weekly.missions = NS:WeeklyId(), { { kind = "captures", need = 6, have = 0, source = "week" },
		{ kind = "captureNamed", need = 1, have = 0, source = "week" } }
	NS:CaptureResolve({ success = true, target = { npcID = 7001, name = "Raptor", class = "elite", zoneID = 1413 } })
	Check("[MISR] capture : mission du jour, semaine, élite", daily.missions[1].have == 1 and weekly.missions[1].have == 1
		and weekly.missions[2].done)
end

-- 4. Ménagerie ----------------------------------------------------------------------------------
do
	Say("-- missions : ménagerie")
	MS.Reset()
	-- une petite table livrée de test : deux zones, une espèce partagée, une
	-- amicale envers la Horde (exclue pour un Horde)
	local savedTable = rawget(NS, "ZONE_CREATURES")
	local savedFaction = NS.BestiaryFaction
	NS.BestiaryFaction = function() return "H" end
	NS.ZONE_CREATURES = {
		[1411] = { [3100] = { lvl = { 1, 2 }, rank = 0, fr = "Sanglier", en = "Boar" },
			[3101] = { lvl = { 5, 6 }, rank = 1, fr = "Gardien", en = "Guard" },
			[3199] = { lvl = { 3, 3 }, rank = 0, fr = "Garde ami", en = "Friendly", f = "H" } },
		[1413] = { [3200] = { lvl = { 12, 13 }, rank = 4, fr = "Rare des plaines", en = "Plains rare" },
			[3201] = { lvl = { 10, 11 }, rank = 0, fr = "Kodo", en = "Kodo" },
			[3101] = { lvl = { 5, 6 }, rank = 1, fr = "Gardien", en = "Guard" } },
	}
	NS.menagerieStatic = nil
	local all, stats = NS:MenagerieList({ zone = "all" })
	Check("[MEN] toutes les espèces capturables (table livrée, ta faction)", #all == 4 and stats.total == 4 and stats.known == 0,
		#all .. "/" .. stats.total)
	local byNpc = {}
	for _, e in ipairs(all) do byNpc[e.npc] = e end
	Check("[MEN] numéro fixe : zones par niveau, puis niveau", byNpc[3100].no == 1 and byNpc[3101].no == 2
		and byNpc[3201].no == 3 and byNpc[3200].no == 4)
	Check("[MEN] espèce de deux zones : une seule fiche, deux zones", #byNpc[3101].zones == 2)
	Check("[MEN] jamais croisée : inconnue", not byNpc[3100].known)
	-- ce qu'on apprend et capture
	NS:BestiaryData()[1413] = { [3201] = { name = "Kodo des plaines", seen = true, killed = 2, type = "Bête", level = 11 },
		[3999] = { name = "Bête hors table", seen = true, killed = 0, class = "normal" } }
	local data = NS:CaptureData()
	data.creatures[3201] = { name = "Kodo des plaines", class = "normal", zoneID = 1413, at = 1700000000 }
	data.creatures[3200] = { name = "Rare des plaines", class = "rare", zoneID = 1413, at = 1800000000, shiny = true }
	data.count = 2
	local zone, zstats = NS:MenagerieList({ zone = 1413 })
	Check("[MEN] zone choisie : ses espèces seulement", #zone == 4 and zstats.total == 4 and zstats.captured == 2
		and zstats.known == 3, #zone .. " " .. zstats.total .. " " .. zstats.captured .. " " .. zstats.known)
	local extra
	for _, e in ipairs(zone) do if e.npc == 3999 then extra = e end end
	Check("[MEN] espèce hors table : numérotée à la suite", extra and extra.no == 5 and extra.known)
	Check("[MEN] filtre « capturées »", #NS:MenagerieList({ zone = 1413, state = "captured" }) == 2)
	Check("[MEN] filtre « à capturer »", #NS:MenagerieList({ zone = 1413, state = "missing" }) == 2)
	Check("[MEN] filtre « à abattre »", #NS:MenagerieList({ zone = 1413, state = "tokill" }) == 3)
	Check("[MEN] filtre de rareté : rare (rare et rare élite)", #NS:MenagerieList({ zone = "all", rank = "rare" }) == 1)
	Check("[MEN] filtre de rareté : élite", #NS:MenagerieList({ zone = "all", rank = "elite" }) == 1)
	local found = NS:MenagerieList({ zone = "all", search = "kodo" })
	Check("[MEN] recherche par nom (sans casse)", #found == 1 and found[1].npc == 3201)
	Check("[MEN] recherche : les inconnues ne se trouvent pas", #NS:MenagerieList({ zone = "all", search = "sanglier" }) == 0)
	Check("[MEN] recherche sans accents", #NS:MenagerieList({ zone = "all", search = "bete hors" }) == 1)
	local byDate = NS:MenagerieList({ zone = "all", sort = "date" })
	Check("[MEN] tri par capture : la plus récente d'abord", byDate[1].npc == 3200 and byDate[2].npc == 3201)
	local byName = NS:MenagerieList({ zone = "all", sort = "name" })
	Check("[MEN] tri par nom : les connues d'abord", byName[1].known and not byName[#byName].known)
	local byRank = NS:MenagerieList({ zone = "all", sort = "rank" })
	Check("[MEN] tri par rareté : la plus rare d'abord", byRank[1].class == "rare")

	-- carnet : la page, ses filtres, l'aperçu, l'équipement
	Mock.world.mapID = 1413
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.menZone, f.menState, f.menRank, f.menSearch, f.menSort = "here", "all", "all", "", "no"
	f.sections.menagerie:Click()
	local pane = f.men
	Check("[MEN] par défaut : la zone actuelle", f.kind == "menagerie" and pane:IsShown() and pane.zone:GetValue() == "here"
		and pane.count.text == "2 capturées · brillantes : 1 · 3 croisées · 4 en tout", pane.count.text)
	Check("[MEN] liste des zones : actuelle, toutes, puis chaque zone", #pane.zone.options == 4
		and pane.zone.options[2].value == "all" and pane.zone.options[3].value == 1411)
	local keys = {}
	for index = 3, #pane.zone.options do keys[#keys + 1] = NS.ZoneSortKey(pane.zone.options[index].label) end
	local sorted = true
	for index = 2, #keys do if keys[index - 1] > keys[index] then sorted = false end end
	Check("[MEN] zones : par ordre alphabétique", sorted, table.concat(keys, ", "))
	Check("[MEN] clé de tri : accents et article de tête ignorés", NS.ZoneSortKey("Les Tarides") == "tarides"
		and NS.ZoneSortKey("Étangs") == "etangs" and NS.ZoneSortKey("L'Âtreval") == "atreval"
		and NS.ZoneSortKey("The Barrens") == "barrens" and NS.ZoneSortKey("Lesath") == "lesath"
		and NS.ZoneSortKey("Durotar") < NS.ZoneSortKey("Les Tarides"))
	local unknown, kodo
	for _, cell in ipairs(pane.items) do
		if cell.entry and cell.entry.npc == 3101 then unknown = cell end
		if cell.entry and cell.entry.npc == 3201 then kodo = cell end
	end
	Check("[MEN] inconnue : « ??? » et son numéro", unknown and unknown.label.text == "???" and unknown.no.text == "n° 002")
	Check("[MEN] capturée : son nom, en couleur", kodo and kodo.label.text == "Kodo des plaines" and kodo.icon.alpha == 1)
	-- 1.5.1 : nom ou « ??? » à la couleur de la rareté, liseré vert si capturée,
	-- plus de colonnes de marques (tampon, pastille)
	local elite = NS.CAPTURE_RARITY[unknown.entry.class or "normal"].color
	Check("[MEN] inconnue : « ??? » à la couleur de sa rareté", unknown.entry.class ~= "normal"
		and unknown.label.textColor[1] == elite[1] and unknown.label.textColor[2] == elite[2] and unknown.label.textColor[3] == elite[3])
	Check("[MEN] capturée : liseré vert à gauche", kodo.caught:IsShown() and kodo.caught.width == 3
		and kodo.caught.vertex[2] == NS.Theme.GREEN[2] and not unknown.caught:IsShown())
	Check("[MEN] plus de tampon ni de pastille dans la ligne", kodo.stamp == nil)
	unknown.scripts.OnEnter(unknown)
	-- 2.4 : une inconnue est verrouillée (MenagerieView.lua) : plus de niveau,
	-- seulement la zone où la chercher
	local unknownText = table.concat({ pane.preview.lines[1].text or "", pane.preview.lines[2].text or "",
		pane.preview.lines[3].text or "" }, " ")
	Check("[MEN] aperçu d'une inconnue : « ??? », verrouillée, comment la trouver", pane.preview.title.text == "???"
		and pane.preview.lines[1].text == NS.L.MENV_LOCKED and not unknownText:find("5-6", 1, true)
		and unknownText:find(NS.L.JRN_MEN_NEVER, 1, true) ~= nil, unknownText)
	pane.zone:Choose("all")
	Check("[MEN] zone « toutes »", f.menZone == "all" and pane.count.text == "2 capturées · brillantes : 1 · 3 croisées · 5 en tout", pane.count.text)
	pane.search:SetText("kodo")
	if pane.search.scripts and pane.search.scripts.OnTextChanged then pane.search.scripts.OnTextChanged(pane.search) end
	Check("[MEN] recherche dans la page", f.menSearch == "kodo" and pane.items[1].entry and pane.items[1].entry.npc == 3201
		and not pane.items[2]:IsShown())
	pane.search:SetText("")
	if pane.search.scripts and pane.search.scripts.OnTextChanged then pane.search.scripts.OnTextChanged(pane.search) end
	pane.rank:Choose("rare")
	Check("[MEN] rareté dans la page", pane.items[1].entry and pane.items[1].entry.npc == 3200 and not pane.items[2]:IsShown())
	pane.rank:Choose("all")
	local entries = {}
	for _, e in ipairs(NS:MenagerieList({ zone = "all" })) do entries[e.npc] = e end
	Check("[MEN] clic sur une inconnue : rien", NS:JournalMenagerieEquip(entries[3101]) == false)
	-- 2.0 : une confirmation qui compare les effets, puis « Emmener »
	Check("[MEN] clic sur une capturée : confirmation demandée", NS:JournalMenagerieEquip(entries[3201]) == true
		and NS.effectsConfirm:IsShown() and NS:CompanionData().appearance ~= "cap:3201")
	NS:CompanionConfirmAnswer(true)
	Check("[MEN] clic sur une capturée : elle devient le compagnon", NS:CompanionData().appearance == "cap:3201")
	-- depuis la fiche d'une zone
	NS:OpenMenagerieZone(1411)
	Check("[MEN] ouverte depuis une zone : filtrée sur elle", f.kind == "menagerie" and f.menZone == 1411
		and pane.zone:GetValue() == 1411)
	f:Hide()
	NS.ZONE_CREATURES, NS.BestiaryFaction, NS.menagerieStatic = savedTable, savedFaction, nil
end

MS.Done()
