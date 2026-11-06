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
	local book = NS:BestiaryData()
	book[1413] = {
		[3100] = { name = "Loup", class = "normal", level = 12, type = "Bête", seen = true, killed = 4 },
		[3101] = { name = "Kodo", class = "normal", level = 14, type = "Bête", seen = true },
		[3102] = { name = "Raptor", class = "elite", level = 16, type = "Bête", seen = true, killed = 1 },
	}
	local data = NS:CaptureData()
	data.creatures[3101] = { name = "Kodo", class = "normal", level = 14, zoneID = 1413, at = 0 }
	data.count = 1
	local list, captured, seen = NS:MenagerieList("all")
	Check("[MEN] toutes les espèces croisées", #list == 3 and captured == 1 and seen == 3)
	Check("[MEN] numérotées par niveau la première fois", list[1].npc == 3100 and list[1].no == 1 and list[3].no == 3)
	book[1413][3099] = { name = "Lapin géant", class = "normal", level = 5, seen = true }
	list = NS:MenagerieList("all")
	Check("[MEN] une nouvelle espèce prend le numéro suivant (les autres ne bougent pas)",
		list[1].npc == 3100 and list[1].no == 1 and list[4].npc == 3099 and list[4].no == 4)
	local only = NS:MenagerieList("captured")
	Check("[MEN] filtre « capturées »", #only == 1 and only[1].captured and only[1].npc == 3101)
	Check("[MEN] filtre « à capturer »", #NS:MenagerieList("missing") == 3)
	-- carnet : la page, la grille, l'aperçu, l'équipement
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	Check("[MEN] onglet Ménagerie juste après la Créature", f.sections.menagerie ~= nil)
	f.sections.menagerie:Click()
	local pane = f.men
	Check("[MEN] page affichée, compteur", f.kind == "menagerie" and pane:IsShown()
		and pane.count.text == "1 capturées · 4 croisées", pane.count.text)
	Check("[MEN] cases : numéro et nom", pane.items[1].no.text == "n° 001" and pane.items[1].label.text == "Loup")
	local kodo
	for _, cell in ipairs(pane.items) do if cell.entry and cell.entry.npc == 3101 then kodo = cell end end
	Check("[MEN] capturée : en couleur ; croisée : grisée", kodo and kodo.icon.alpha == 1 and pane.items[1].icon.alpha < 1)
	NS:JournalPreviewMenagerie(pane.items[1].entry)
	Check("[MEN] aperçu d'une non capturée : sa chance", pane.preview.lines[3].text:find("chance", 1, true) ~= nil,
		pane.preview.lines[3].text)
	Check("[MEN] clic sur une non capturée : rien", NS:JournalMenagerieEquip(pane.items[1].entry) == false)
	Check("[MEN] clic sur une capturée : elle devient le compagnon", NS:JournalMenagerieEquip(kodo.entry) == true
		and NS:CompanionData().appearance == "cap:3101")
	f:Hide()
end

MS.Done()
