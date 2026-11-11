-- Compagnon : au jour le jour (Daily.lua). Carte de fidélité des auberges (un
-- tampon par jour, Festin au 7e, pas de série), missions du jour (deux de zone
-- faisables, une du caractère ; 2.0 : la première de créatures, voir
-- missions.lua ; tirage une fois par jour ; chaque sorte avance sur son
-- événement ; changer une fois ; friandise, Festin des trois), onglet
-- Missions du carnet (besace, carte, garde-manger), objectifs du bloc à
-- l'écran (clé, masquer, purge), réglage coupé.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local DY = { saved = {}, random = math.random, day = "2026-11-05",
	savedCounts = NS.BestiaryCounts, savedCompletion = NS.ZoneCompletion, savedBand = NS.GatheringZoneBand,
	savedTrait = NS.CompanionTrait }
local GLOBALS = { "date", "UnitGUID", "UnitName", "IsShiftKeyDown", "GetGameTime", "IsResting", "GetMoney" }
for _, name in ipairs(GLOBALS) do DY.saved[name] = rawget(_G, name) end

function DY.Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.companionBubbleText = nil
	if NS.companionRT then NS.companionRT.cool = {} end
end
function DY.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.companionLastPet = nil, nil, nil, nil
	Mock.world.maps[9800] = { mapID = 9800, name = "Val des missions", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[9801] = { mapID = 9801, name = "Autre val", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 9800, 20
	DY.day, DY.hour, DY.resting, DY.money = "2026-11-05", 12, false, 0
	_G.date = function(format) if format == "%Y-%m-%d" then return DY.day end return "05/11/2026" end
	_G.UnitGUID = function() return nil end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return nil end
	_G.IsShiftKeyDown = function() return false end
	_G.GetGameTime = function() return DY.hour, 0 end
	_G.IsResting = function() return DY.resting end
	_G.GetMoney = function() return DY.money end
	-- une zone dont on règle tout : bestiaire, parts, récolte
	DY.counts = { seen = 10, killed = 2, namedSeen = 2, namedKilled = 0 }
	DY.parts = { { id = "villages", have = 1, need = 4 }, { id = "quests", have = 0, need = 6 }, { id = "bestiary", have = 2, need = 10 } }
	DY.percent, DY.band = 30, { { itemID = 765 } }
	NS.BestiaryCounts = function(_, zoneID) if zoneID == 9800 then return DY.counts end return DY.savedCounts(NS, zoneID) end
	NS.ZoneCompletion = function(_, zoneID)
		if zoneID == 9800 then return { zoneID = 9800, parts = DY.parts, percent = DY.percent, ratio = DY.percent / 100 } end
		return DY.savedCompletion(NS, zoneID)
	end
	NS.GatheringZoneBand = function(_, zoneID) if zoneID == 9800 then return DY.band, {} end return {}, {} end
	NS.CompanionTrait = DY.savedTrait
	math.random = DY.random
	local data = NS:CompanionData()
	data.tutoDone = true
	NS:TreatData().treatsInit = true
	NS:CompanionUpdateVisibility()
	DY.Quiet()
end
function DY.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = DY.saved[name] end
	NS.BestiaryCounts, NS.ZoneCompletion, NS.GatheringZoneBand = DY.savedCounts, DY.savedCompletion, DY.savedBand
	NS.CompanionTrait = DY.savedTrait
	math.random = DY.random
	ResetWorld()
end
function DY.Kinds()
	local kinds = {}
	for _, mission in ipairs(NS:DailyData().missions) do kinds[#kinds + 1] = mission.kind end
	return table.concat(kinds, ",")
end
-- tirage imposé : le premier de la liste à chaque fois
function DY.First() math.random = function(a) if a then return 1 end return 0 end end

-- 1. Carte de fidélité --------------------------------------------------------------------------
do
	Say("-- au jour le jour : auberges")
	DY.Reset()
	local _, inn = NS:DailyData()
	NS:CompanionData().needs.energy = 40
	Check("[DAY] aubergiste : un tampon, +20 d'énergie, sa bulle « 1/7 »", NS:CompanionOnNpc("innkeeper") == true
		and inn.card == 1 and inn.total == 1 and NS:CompanionData().needs.energy == 40 + NS.INN_ENERGY
		and NS.companionBubbleKey == "INN_STAMP" and ((NS.companionBubbleText or ""):find("1/7", 1, true)
		or (NS.companionBubbleText or ""):find("1 sur 7", 1, true)), NS.companionBubbleText)
	DY.Quiet()
	NS:CompanionOnNpc("innkeeper")
	Check("[DAY] même jour : pas de second tampon", inn.card == 1 and NS.companionBubbleKey ~= "INN_STAMP")
	DY.day = "2026-11-09"
	NS:InnStamp()
	local skipped = inn.card == 2
	for day = 10, 14 do DY.day = "2026-11-" .. day; NS:InnStamp() end
	Check("[DAY] jours sautés : rien de perdu ; 7e tampon : carte pleine, un Festin, « carte pleine »", skipped
		and inn.card == 0 and inn.total == 7 and NS:TreatCount("festin") == 1 and NS.companionBubbleKey == "INN_FULL",
		NS.companionBubbleKey)
	NS:DB().companionEnabled = false
	DY.day = "2026-11-20"
	Check("[DAY] compagnon coupé : pas de tampon", NS:InnStamp() == nil and inn.total == 7)
	NS:DB().companionEnabled = true
end

-- 2. Tirage des missions ------------------------------------------------------------------------
do
	Say("-- au jour le jour : tirage")
	DY.Reset()
	local bad = {}
	for _, kind in ipairs(NS.DAILY_ZONE_MISSIONS) do
		if not NS:MissionFeasible(kind, 9800) then bad[#bad + 1] = kind end
	end
	Check("[MIS] zone à faire : chaque mission de zone faisable", #bad == 0, table.concat(bad, ", "))
	-- chaque but atteint rend sa mission infaisable
	DY.counts.killed = 8
	if NS:MissionFeasible("species", 9800) then bad[#bad + 1] = "species" end
	DY.counts.namedKilled = 2
	if NS:MissionFeasible("named", 9800) then bad[#bad + 1] = "named" end
	DY.band = {}
	if NS:MissionFeasible("gather", 9800) then bad[#bad + 1] = "gather" end
	DY.parts[1].have = 4
	if NS:MissionFeasible("village", 9800) then bad[#bad + 1] = "village" end
	DY.parts[2].have = 5
	if NS:MissionFeasible("quests", 9800) then bad[#bad + 1] = "quests" end
	DY.percent = 98
	if NS:MissionFeasible("percent", 9800) then bad[#bad + 1] = "percent" end
	Check("[MIS] infaisables : espèces, nommé, récolte, visite, quêtes, +3 % quand il n'y a plus de quoi", #bad == 0,
		table.concat(bad, ", "))
	NS:DB().companionCapture = false
	NS:MissionDraw(9800)
	local off = DY.Kinds()
	NS:DB().companionCapture = true
	NS:MissionDraw(9800)
	Check("[MIS] zone toute faite : gens à qui parler et ennemis ; capture allumée : une capture, partout faisable",
		off == "talks,kills,pets" and DY.Kinds() == "captures,talks,pets" and NS:MissionFeasible("captures", nil) == true,
		off .. " / " .. DY.Kinds())

	DY.Reset()
	DY.First()
	local first = NS:DailyPoll() == true
	local daily = NS:DailyData()
	Check("[MIS] premier passage du jour : trois missions (deux de zone différentes, « 3 caresses » avant le caractère), annoncées",
		first and #daily.missions == 3 and daily.missions[1].source == "zone" and daily.missions[2].source == "zone"
		and daily.missions[1].kind ~= daily.missions[2].kind and daily.missions[3].source == "trait"
		and daily.missions[3].kind == "pets" and daily.missions[3].need == 3 and NS.companionBubbleKey == "MISSION_NEW", DY.Kinds())
	Check("[MIS] même jour : pas de second tirage", NS:DailyPoll() == false)
	Mock.world.mapID = nil
	DY.day = "2026-11-06"
	local waits = NS:DailyPoll() == false
	Mock.world.mapID = 9800
	NS.CompanionTrait = function() return "glutton" end
	local drawn = NS:DailyPoll() == true and NS:DailyData().day == "2026-11-06"
	daily = NS:DailyData()
	Check("[MIS] lendemain : en instance on attend une zone, puis tirage ; Gourmande : « mange 3 fois »", waits and drawn
		and daily.missions[3].kind == "meals" and daily.missions[3].trait == "glutton")
	Check("[MIS] libellés et source", NS:MissionLabel(daily.missions[3]) == "Mange ou bois 3 fois"
		and NS:MissionLabel({ kind = "species", need = 3, zoneID = 9800 }) == "Abats 3 espèces jamais vaincues (Val des missions)"
		and NS:MissionLabel({ kind = "percent", need = 3, zoneID = 9800 }) == "Fais gagner 3 % à Val des missions"
		and NS:MissionSource(daily.missions[3]):find("Gourmand", 1, true) ~= nil, NS:MissionSource(daily.missions[3]))
end

-- 3. Avancer, finir ---------------------------------------------------------------------------------
do
	Say("-- au jour le jour : avancer")
	DY.Reset()
	DY.First()
	NS:DailyPoll()
	local daily = NS:DailyData()
	-- missions de zone : espèces (mesurée) et nommé (événement)
	daily.missions[1] = { kind = "species", zoneID = 9800, need = 3, have = 0, source = "zone", start = DY.counts.killed }
	daily.missions[2] = { kind = "named", zoneID = 9800, need = 1, have = 0, source = "zone", start = 0 }
	NS:CompanionData().needs = { hunger = 80, energy = 20, mood = 80, curiosity = 50 }
	DY.counts.killed = DY.counts.killed + 2
	NS:RefreshJournalTracker()
	local measured = daily.missions[1].have == 2 and not daily.missions[1].done
	DY.Quiet()
	DY.counts.killed = DY.counts.killed + 1
	NS:RefreshJournalTracker()
	Check("[MIS] espèces : mesurées au rafraîchissement, 3/3 : faite", measured and daily.missions[1].done == true
		and daily.missions[1].have == 3)
	Check("[MIS] … une friandise (envie la plus basse), de la curiosité, « mission accomplie »", NS:TreatCount("infusion") == 1
		and NS:CompanionData().needs.curiosity == 50 + NS.MISSION_CURIOSITY and NS.companionBubbleKey == "MISSION_DONE",
		NS.companionBubbleKey)
	Mock.world.mapID = 9801
	NS:MissionEvent("elites", 1, 9801)
	local elsewhere = daily.missions[2].have == 0
	Mock.world.mapID = 9800
	_G.UnitIsDead = function() return true end
	_G.UnitClassification = function() return "elite" end
	NS:CompanionEliteKilled()
	_G.UnitIsDead, _G.UnitClassification = nil, nil
	Check("[MIS] nommé : pas dans une autre zone, fait par un élite abattu ici", elsewhere and daily.missions[2].done == true)
	-- caresses (pas Maj + clic)
	_G.IsShiftKeyDown = function() return true end
	NS:CompanionPet()
	local shift = daily.missions[3].have == 0
	_G.IsShiftKeyDown = function() return false end
	NS:CompanionPet()
	Mock:Advance(20); NS:CompanionPet()
	Check("[MIS] caresses comptées, pas Maj + clic", shift and daily.missions[3].have == 2, daily.missions[3].have)
	DY.Quiet()
	local festins = NS:TreatCount("festin")
	Mock:Advance(20); NS:CompanionPet()
	Check("[MIS] les trois faites : un Festin en plus, « festin ! », plus rien n'avance", daily.allDone == true
		and NS:TreatCount("festin") == festins + 1 and NS.companionBubbleKey == "MISSION_ALL"
		and NS:MissionEvent("pets", 1) == false, NS.companionBubbleKey)
end

-- 4. Missions du caractère : repos, calme, nuit, or, repas, PNJ, quêtes, lieux, récolte -------------------
do
	Say("-- au jour le jour : caractère")
	DY.Reset()
	DY.First()
	NS:DailyPoll()
	local daily = NS:DailyData()
	local function Set(kind, need, zoneID)
		daily.missions = { { kind = kind, need = need, have = 0, source = "trait", zoneID = zoneID } }
		daily.allDone = nil
		return daily.missions[1]
	end
	local m = Set("rest", 15)
	NS:CompanionTick(600)
	local away = m.have == 0
	DY.resting = true
	NS:CompanionTick(600)
	Check("[MIS] repos : rien hors repos, 10 minutes au repos", away and m.have == 10, m.have)
	DY.resting = false
	m = Set("calm", 15)
	NS:CompanionTick(300)
	NS:CompanionOnDead()
	local reset = m.have == 0
	NS:CompanionTick(15 * 60)
	Check("[MIS] calme : une mort remet à zéro, 15 minutes sans tomber", reset and m.done == true)
	m = Set("nightKills", 5)
	DY.hour = 14
	NS:CompanionOnKill()
	local byDay = m.have == 0
	DY.hour = 23
	Mock:Advance(3)
	NS:CompanionOnKill()
	local byNight = m.have == 1
	Mock:Advance(0.5)
	NS:CompanionOnKill()
	Check("[MIS] de nuit seulement ; la même mort (XP et journal) comptée une fois", byDay and byNight and m.have == 1)
	m = Set("gold", 1)
	DY.money = 5000
	NS:CompanionTick(1)
	DY.money = 12000
	NS:CompanionTick(1)
	local silver = not m.done and m.have == 0
	DY.money = 16000
	NS:CompanionTick(1)
	Check("[MIS] or : 70 pièces d'argent ne font pas une pièce d'or, une pièce d'or gagnée", silver and m.done == true)
	m = Set("meals", 3)
	NS.CompanionAuraState = function() return true, false, false end
	NS:CompanionCheckAuras(); NS:CompanionCheckAuras()
	NS.CompanionAuraState = nil
	NS.companionEating = nil
	Check("[MIS] repas : un par repas", m.have == 1, m.have)
	m = Set("kills", 2)
	NS:MissionEvent("kills", 5)
	Check("[MIS] jamais au-delà du but", m.have == 2 and m.done)
	m = Set("quests", 2, 9800)
	Mock:Fire("QUEST_TURNED_IN", 1, 0, 0)
	local zoneQuest = m.have == 1
	m = Set("turnins", 3)
	Mock:Fire("QUEST_TURNED_IN", 1, 0, 0)
	Check("[MIS] quête rendue : « quêtes » de la zone et « rendre des quêtes »", zoneQuest and m.have == 1)
	m = Set("rest", 15)
	DY.resting = true
	NS:DB().companionMissions = false
	NS:CompanionTick(600)
	NS:DB().companionMissions = true
	DY.resting = false
	local off = m.have == 0
	daily.day = "2026-11-04"
	Check("[MIS] missions coupées, ou d'hier : plus rien n'avance", off and NS:MissionEvent("rest", 1) == false)
	daily.day = DY.day
	-- relecture 1.2.0 : un même PNJ (deux fenêtres) compte une fois
	m = Set("talks", 3)
	daily.talked = {}
	_G.UnitGUID = function(unit) if unit == "npc" then return "Creature-0-1-1-1-777-0001" end return nil end
	NS:CompanionOnNpc("merchant")
	NS:CompanionOnNpc("quest")
	_G.UnitGUID = function() return nil end
	Check("[MIS] PNJ : compté, une fois par PNJ", m.have == 1, m.have)
	m = Set("places", 2)
	NS:CompanionOnStamp({ kind = "subzone", name = "Clairière", new = true })
	NS:CompanionOnStamp({ kind = "subzone", name = "Clairière", new = false })
	Check("[MIS] lieu découvert : compté, pas deux fois", m.have == 1)
	m = Set("gather", 5, 9800)
	NS:GatheringRecord(765, 1, 9800)
	NS:GatheringRecord(765, 1, 9801)
	Check("[MIS] récolte : dans sa zone seulement", m.have == 1)
	m = Set("village", 1, 9800)
	NS:CompanionOnStamp({ kind = "subzone", name = "Hameau", new = true })
	Check("[MIS] lieu jamais vu dans la zone : visite faite", m.done == true)
end

-- 5. Changer une mission --------------------------------------------------------------------------------
do
	Say("-- au jour le jour : changer")
	DY.Reset()
	DY.First()
	NS:DailyPoll()
	local daily = NS:DailyData()
	-- 2.0 : mission 1 = créatures (ici « captures », rien d'autre à capturer
	-- dans la zone : pas d'autre mission de créatures), mission 2 = exploration
	local before = daily.missions[2].kind
	Check("[MIS] pas changeables : celle du caractère, celle de créatures sans autre choix", NS:MissionReroll(3) == false
		and NS:MissionReroll(1) == false and not daily.rerolled)
	Check("[MIS] une mission d'exploration changée, une seule fois par jour", NS:MissionReroll(2) == true
		and daily.missions[2].kind ~= before and daily.missions[2].kind ~= daily.missions[1].kind and daily.missions[2].have == 0
		and NS:MissionReroll(2) == false and daily.rerolled == true)
	DY.day = "2026-11-06"
	NS:DailyPoll()
	daily = NS:DailyData()
	local again = daily.rerolled == nil
	daily.missions[1].done = true
	Check("[MIS] lendemain : on peut de nouveau changer, sauf une mission faite", again and NS:MissionReroll(1) == false)
end

-- 6. Carnet : onglet Missions, objectifs ------------------------------------------------------------------
do
	Say("-- au jour le jour : carnet")
	DY.Reset()
	DY.First()
	NS:DailyPoll()
	NS:TreatData().pantry.bonbon = 2
	local _, inn = NS:DailyData()
	inn.card = 3
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	local tab = f.sections.day and f.sections.day.text.text == "Missions" and f.sections.day.badge.text == "6"
		and f.sections.day.badge:IsShown()
	f.sections.day:Click()
	local day = f.day
	Check("[DAYW] onglet Missions (pastille des missions qui restent), affiché seul", tab and f.kind == "day"
		and day:IsShown() and not f.evo:IsShown(), f.sections.day and f.sections.day.badge.text)
	Check("[DAYW] mission du compagnon en tête (libellé, compteur, récompense), semaine : trois dont une capture",
		day.missions[1].label.text == "Fais-moi 3 caresses" and day.missions[1].count.text == "0/3"
		and day.missions[1].source.text:find("Appât savoureux", 1, true) ~= nil and day.missions[6].mission ~= nil
		and (day.missions[4].mission.kind == "captures" or day.missions[4].mission.kind == "captureNamed"),
		day.missions[1].label.text)
	local slot
	for _, s in ipairs(day.slots) do if s.kind == "bonbon" then slot = s end end
	Check("[DAYW] besace, carte (3 tampons sur 7), garde-manger « 2 / 3 » avec Donner", #day.aids == 3
		and day.aids[1].count.text:find("^%d+ / 10$") ~= nil and day.stamps[3].got and not day.stamps[4].got
		and slot.count.text == "2 / 3" and slot.give:IsShown(), day.aids[1].count.text)
	slot.give:Click()
	Check("[DAYW] donner : une de moins", NS:TreatCount("bonbon") == 1 and slot.count.text == "1 / 3")
	f:Hide()
	-- objectifs dans le bloc à l'écran
	local found
	for _, goal in ipairs(NS:JournalObjectives()) do if goal.id:find("^mission:.-:3:") then found = goal end end
	-- 2.10.0 : la clé porte le jour et la sorte de mission, plus l'emplacement seul
	local today = NS:DailyData().day
	Check("[DAYW] objectif : la mission du jour, clé jour + emplacement + sorte", found and found.label == "Fais-moi 3 caresses"
		and found.progress == "0/3" and found.id == "mission:" .. today .. ":3:" .. tostring(NS:DailyData().missions[3].kind),
		found and found.id)
	found.onClick()
	local opened = f:IsShown() and f.kind == "day"
	found.onClick()
	local closed = not f:IsShown()
	NS:ToggleJournal(true)
	NS:SelectJournalKind("evolution")
	found.onClick()
	Check("[DAYW] clic sur l'objectif : ouvre le Jour, le referme s'il y est, y va s'il est ailleurs", opened and closed
		and f:IsShown() and f.kind == "day")
	f:Hide()
	-- masquer : cette mission, ce jour ; le lendemain et après « Changer », elle revient
	local dismissed = NS:JournalData().dismissed or {}
	NS:JournalData().dismissed = dismissed
	NS:JournalDismiss(found.id, true)
	local function Listed(id)
		for _, goal in ipairs(NS:JournalTrackerObjectives()) do if goal.id == id then return true end end
		return false
	end
	local m3 = NS:DailyData().missions[3]
	Check("[DAYW] mission masquée : hors du suivi, comptée ; le lendemain, une autre clé", not Listed(found.id)
		and NS:JournalHiddenCount() >= 1 and NS:MissionGoalKey("2099-01-01", 3, m3) ~= found.id)
	local m1 = NS:DailyData().missions[1]
	local id1 = NS:MissionGoalKey(today, 1, m1)
	NS:JournalDismiss(id1, true)
	if NS:MissionReroll(1) then
		local id1b = NS:MissionGoalKey(today, 1, NS:DailyData().missions[1])
		Check("[DAYW] … « Changer » : la nouvelle mission revient", id1b ~= id1 and Listed(id1b), id1b)
	end
	-- purge : anciennes clés (« mission:2 ») et jours passés ; la clé du jour reste
	dismissed["mission:2"] = true
	dismissed["mission:2000-01-01:1:kills"] = true
	NS:MissionPurgeReset()
	NS:JournalObjectives()
	Check("[DAYW] purge : ancien format et jours passés supprimés, le jour gardé", dismissed["mission:2"] == nil
		and dismissed["mission:2000-01-01:1:kills"] == nil and dismissed[found.id] == true)
	NS:JournalRestoreDismissed()
	Check("[DAYW] réafficher : plus aucun masqué", NS:JournalHiddenCount() == 0 and dismissed[found.id] == nil)
	-- réglage coupé
	NS:DB().companionMissions = false
	local noEvent = NS:MissionEvent("pets", 1) == false
	local listed = false
	for _, goal in ipairs(NS:JournalObjectives()) do if goal.id:find("^mission:") then listed = true end end
	NS:ToggleJournal(true)
	f.sections.day:Click()
	local said = day.missions[1].label.text == NS.L.MIS_OFF
	f:Hide()
	DY.day = "2026-11-07"
	Check("[DAYW] missions coupées : rien ne compte, ni objectif, l'onglet le dit, pas de tirage", noEvent and not listed
		and said and NS:DailyPoll() == false)
	NS:DB().companionMissions = true
	local page
	for _, p in ipairs(NS.OPTION_PAGES) do if p.id == "companionDaily" then page = p end end
	Check("[DAYW] réglage dans la page « Au jour le jour »", page and page.rows[1].key == "companionMissions")
end

DY.Done()
