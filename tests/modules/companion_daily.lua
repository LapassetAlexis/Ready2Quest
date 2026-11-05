-- Compagnon : au jour le jour (Daily.lua). Carte de fidélité des auberges (un
-- tampon par jour, Festin au 7e, pas de série), missions du jour (deux de zone
-- faisables, une du caractère ; changer une fois ; friandise, Festin des
-- trois), onglet Jour du carnet, objectifs du bloc à l'écran, réglage.
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
	Check("[DAY] aubergiste : un tampon", NS:CompanionOnNpc("innkeeper") == true and inn.card == 1 and inn.total == 1)
	Check("[DAY] … +20 d'énergie", NS:CompanionData().needs.energy == 40 + NS.INN_ENERGY, NS:CompanionData().needs.energy)
	Check("[DAY] … sa bulle « 1/7 »", NS.companionBubbleKey == "INN_STAMP" and NS.companionBubbleText:find("1/7", 1, true)
		or (NS.companionBubbleText or ""):find("1 sur 7", 1, true), NS.companionBubbleText)
	DY.Quiet()
	NS:CompanionOnNpc("innkeeper")
	Check("[DAY] même jour : pas de second tampon", inn.card == 1 and NS.companionBubbleKey ~= "INN_STAMP")
	DY.day = "2026-11-09"
	NS:InnStamp()
	Check("[DAY] jours sautés : rien de perdu", inn.card == 2)
	for day = 10, 14 do DY.day = "2026-11-" .. day; NS:InnStamp() end
	Check("[DAY] 7e tampon : carte pleine, un Festin", inn.card == 0 and inn.total == 7 and NS:TreatCount("festin") == 1)
	Check("[DAY] … « carte pleine »", NS.companionBubbleKey == "INN_FULL", NS.companionBubbleKey)
	NS:DB().companionEnabled = false
	DY.day = "2026-11-20"
	Check("[DAY] compagnon coupé : pas de tampon", NS:InnStamp() == nil and inn.total == 7)
	NS:DB().companionEnabled = true
end

-- 2. Tirage des missions ------------------------------------------------------------------------
do
	Say("-- au jour le jour : tirage")
	DY.Reset()
	for _, kind in ipairs(NS.DAILY_ZONE_MISSIONS) do
		Check("[MIS] faisable ici : " .. kind, NS:MissionFeasible(kind, 9800))
	end
	DY.counts.killed = 8
	Check("[MIS] moins de 3 espèces à abattre : pas de mission espèces", not NS:MissionFeasible("species", 9800))
	DY.counts.namedKilled = 2
	Check("[MIS] nommés tous abattus : pas de mission nommé", not NS:MissionFeasible("named", 9800))
	DY.band = {}
	Check("[MIS] pas de métier ici : pas de récolte", not NS:MissionFeasible("gather", 9800))
	DY.parts[1].have = 4
	Check("[MIS] tous les lieux vus : pas de visite", not NS:MissionFeasible("village", 9800))
	DY.parts[2].have = 5
	Check("[MIS] moins de 2 quêtes : pas de quêtes", not NS:MissionFeasible("quests", 9800))
	DY.percent = 98
	Check("[MIS] zone presque finie : pas de +3 %", not NS:MissionFeasible("percent", 9800))
	NS:MissionDraw(9800)
	Check("[MIS] zone toute faite : ennemis et gens à qui parler", DY.Kinds() == "kills,talks,pets", DY.Kinds())

	DY.Reset()
	DY.First()
	Check("[MIS] premier passage du jour : tirage", NS:DailyPoll() == true)
	local daily = NS:DailyData()
	Check("[MIS] trois missions : deux de zone différentes, une du caractère", #daily.missions == 3
		and daily.missions[1].source == "zone" and daily.missions[2].source == "zone"
		and daily.missions[1].kind ~= daily.missions[2].kind and daily.missions[3].source == "trait", DY.Kinds())
	Check("[MIS] avant le caractère : « fais-moi 3 caresses »", daily.missions[3].kind == "pets" and daily.missions[3].need == 3)
	Check("[MIS] la créature l'annonce", NS.companionBubbleKey == "MISSION_NEW", NS.companionBubbleKey)
	Check("[MIS] même jour : pas de second tirage", NS:DailyPoll() == false)
	Mock.world.mapID = nil
	DY.day = "2026-11-06"
	Check("[MIS] lendemain, en instance : on attend une zone", NS:DailyPoll() == false)
	Mock.world.mapID = 9800
	NS.CompanionTrait = function() return "glutton" end
	Check("[MIS] lendemain : nouveau tirage", NS:DailyPoll() == true and daily.day == "2026-11-06")
	daily = NS:DailyData()
	Check("[MIS] Gourmande : « mange 3 fois »", daily.missions[3].kind == "meals" and daily.missions[3].trait == "glutton")
	Check("[MIS] libellés", NS:MissionLabel(daily.missions[3]) == "Mange ou bois 3 fois"
		and NS:MissionLabel({ kind = "species", need = 3, zoneID = 9800 }) == "Abats 3 espèces jamais vaincues (Val des missions)"
		and NS:MissionLabel({ kind = "percent", need = 3, zoneID = 9800 }) == "Fais gagner 3 % à Val des missions")
	Check("[MIS] source", NS:MissionSource(daily.missions[3]):find("Gourmand", 1, true) ~= nil, NS:MissionSource(daily.missions[3]))
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
	Check("[MIS] espèces : mesurées au rafraîchissement", daily.missions[1].have == 2 and not daily.missions[1].done)
	DY.Quiet()
	DY.counts.killed = DY.counts.killed + 1
	NS:RefreshJournalTracker()
	Check("[MIS] 3/3 : faite", daily.missions[1].done == true and daily.missions[1].have == 3)
	Check("[MIS] … une friandise (envie la plus basse) et de la curiosité", NS:TreatCount("infusion") == 1
		and NS:CompanionData().needs.curiosity == 50 + NS.MISSION_CURIOSITY, NS:CompanionData().needs.curiosity)
	Check("[MIS] … « mission accomplie »", NS.companionBubbleKey == "MISSION_DONE", NS.companionBubbleKey)
	Mock.world.mapID = 9801
	NS:MissionEvent("elites", 1, 9801)
	Check("[MIS] nommé dans une autre zone : ne compte pas", daily.missions[2].have == 0)
	Mock.world.mapID = 9800
	_G.UnitIsDead = function() return true end
	_G.UnitClassification = function() return "elite" end
	NS:CompanionEliteKilled()
	_G.UnitIsDead, _G.UnitClassification = nil, nil
	Check("[MIS] élite abattu ici : nommé fait", daily.missions[2].done == true)
	-- caresses (pas Maj + clic)
	_G.IsShiftKeyDown = function() return true end
	NS:CompanionPet()
	Check("[MIS] Maj + clic : pas une caresse", daily.missions[3].have == 0)
	_G.IsShiftKeyDown = function() return false end
	NS:CompanionPet()
	Mock:Advance(20); NS:CompanionPet()
	Check("[MIS] caresses comptées", daily.missions[3].have == 2, daily.missions[3].have)
	DY.Quiet()
	local festins = NS:TreatCount("festin")
	Mock:Advance(20); NS:CompanionPet()
	Check("[MIS] les trois faites : un Festin en plus", daily.allDone == true and NS:TreatCount("festin") == festins + 1)
	Check("[MIS] … « festin ! »", NS.companionBubbleKey == "MISSION_ALL", NS.companionBubbleKey)
	Check("[MIS] fait : plus rien n'avance", NS:MissionEvent("pets", 1) == false)
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
	Check("[MIS] repos : pas au repos, rien", m.have == 0)
	DY.resting = true
	NS:CompanionTick(600)
	Check("[MIS] repos : 10 minutes", m.have == 10, m.have)
	DY.resting = false
	m = Set("calm", 15)
	NS:CompanionTick(300)
	NS:CompanionOnDead()
	Check("[MIS] calme : une mort remet à zéro", m.have == 0)
	NS:CompanionTick(15 * 60)
	Check("[MIS] calme : 15 minutes sans tomber", m.done == true)
	m = Set("nightKills", 5)
	DY.hour = 14
	NS:CompanionOnKill()
	Check("[MIS] de jour : ne compte pas de nuit", m.have == 0)
	DY.hour = 23
	Mock:Advance(3)
	NS:CompanionOnKill()
	Check("[MIS] de nuit : compte", m.have == 1)
	Mock:Advance(0.5)
	NS:CompanionOnKill()
	Check("[MIS] même mort comptée deux fois (XP et journal) : une seule", m.have == 1)
	m = Set("gold", 1)
	DY.money = 5000
	NS:CompanionTick(1)
	DY.money = 12000
	NS:CompanionTick(1)
	Check("[MIS] or : 70 pièces d'argent ne font pas une pièce d'or", not m.done and m.have == 0)
	DY.money = 16000
	NS:CompanionTick(1)
	Check("[MIS] or : une pièce d'or gagnée", m.done == true)
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
	Check("[MIS] quête rendue dans la zone : mission « quêtes » de la zone", m.have == 1)
	m = Set("rest", 15)
	DY.resting = true
	NS:DB().companionMissions = false
	NS:CompanionTick(600)
	NS:DB().companionMissions = true
	DY.resting = false
	Check("[MIS] missions coupées : le repos ne compte pas", m.have == 0)
	daily.day = "2026-11-04"
	Check("[MIS] missions d'hier : plus rien n'avance", NS:MissionEvent("rest", 1) == false)
	daily.day = DY.day
	m = Set("talks", 3)
	NS:CompanionOnNpc("merchant")
	Check("[MIS] PNJ : compté", m.have == 1)
	m = Set("turnins", 3)
	Mock:Fire("QUEST_TURNED_IN", 1, 0, 0)
	Check("[MIS] quête rendue : comptée", m.have == 1)
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
	local before = daily.missions[1].kind
	Check("[MIS] mission du caractère : pas changeable", NS:MissionReroll(3) == false)
	Check("[MIS] une mission de zone changée", NS:MissionReroll(1) == true and daily.missions[1].kind ~= before
		and daily.missions[1].kind ~= daily.missions[2].kind and daily.missions[1].have == 0)
	Check("[MIS] une seule fois par jour", NS:MissionReroll(2) == false and daily.rerolled == true)
	DY.day = "2026-11-06"
	NS:DailyPoll()
	daily = NS:DailyData()
	Check("[MIS] lendemain : on peut de nouveau changer", daily.rerolled == nil)
	daily.missions[1].done = true
	Check("[MIS] mission faite : pas changeable", NS:MissionReroll(1) == false)
end

-- 6. Carnet : onglet Jour, objectifs ---------------------------------------------------------------------
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
	Check("[DAYW] onglet Jour, avec les missions qui restent", f.sections.day and f.sections.day.text.text == "Jour (3)",
		f.sections.day and f.sections.day.text.text)
	f.sections.day:Click()
	local day = f.day
	Check("[DAYW] affiché seul", f.kind == "day" and day:IsShown() and not f.comp:IsShown())
	Check("[DAYW] trois missions, libellé et compteur", day.missions[3].label.text == "Fais-moi 3 caresses"
		and day.missions[3].count.text == "0/3", day.missions[3].label.text)
	Check("[DAYW] changer : sur les missions de zone seulement", day.missions[1].reroll:IsShown()
		and not day.missions[3].reroll:IsShown())
	day.missions[1].reroll:Click()
	Check("[DAYW] changé : le bouton disparaît", NS:DailyData().rerolled and not day.missions[2].reroll:IsShown())
	Check("[DAYW] carte : 3 tampons sur 7", day.stamps[3].got and not day.stamps[4].got)
	local slot
	for _, s in ipairs(day.slots) do if s.kind == "bonbon" then slot = s end end
	Check("[DAYW] garde-manger : « 2 / 3 », bouton Donner", slot.count.text == "2 / 3" and slot.give:IsShown())
	slot.give:Click()
	Check("[DAYW] donner : une de moins", NS:TreatCount("bonbon") == 1 and slot.count.text == "1 / 3")
	f:Hide()
	-- objectifs dans le bloc à l'écran
	local found
	for _, goal in ipairs(NS:JournalObjectives()) do if goal.id == "mission:3" then found = goal end end
	Check("[DAYW] objectif : la mission du jour", found and found.label == "Fais-moi 3 caresses" and found.progress == "0/3")
	found.onClick()
	Check("[DAYW] clic sur l'objectif : onglet Jour", f:IsShown() and f.kind == "day")
	f:Hide()
	-- réglage coupé
	NS:DB().companionMissions = false
	Check("[DAYW] missions coupées : rien ne compte", NS:MissionEvent("pets", 1) == false)
	local listed = false
	for _, goal in ipairs(NS:JournalObjectives()) do if goal.id:find("^mission:") then listed = true end end
	Check("[DAYW] … ni objectif", not listed)
	NS:ToggleJournal(true)
	f.sections.day:Click()
	Check("[DAYW] … onglet : il le dit", day.missions[1].label.text == NS.L.MIS_OFF)
	f:Hide()
	DY.day = "2026-11-07"
	Check("[DAYW] … pas de tirage", NS:DailyPoll() == false)
	NS:DB().companionMissions = true
	local page
	for _, p in ipairs(NS.OPTION_PAGES) do if p.id == "companionDaily" then page = p end end
	Check("[DAYW] réglage dans la page « Au jour le jour »", page and page.rows[1].key == "companionMissions")
	local missing = {}
	for key in pairs(NS.DAILY_STRINGS.fr) do if not NS.DAILY_STRINGS.en[key] then missing[#missing + 1] = key end end
	Check("[DAYW] textes fr et en", #missing == 0, table.concat(missing, ", "))
end

DY.Done()
