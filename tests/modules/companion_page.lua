-- Carnet 1.5.0 : page Compagnon (héros, chiffres, envies, allure) et route
-- parcourue ensemble (CompanionTravel.lua).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local CP = { saved = {} }
local GLOBALS = { "UnitPosition", "C_Map", "GetLocale", "time" }
for _, name in ipairs(GLOBALS) do CP.saved[name] = rawget(_G, name) end

function CP.Reset()
	ResetWorld()
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	NS.travelLast = nil
	local data = NS:CompanionData()
	data.tutoDone, data.travel, data.since, data.missionsDone = true, 0, nil, nil
	NS:CompanionUpdateVisibility()
	CP.pos = { x = 1, y = 1, instance = 1 }
	_G.UnitPosition = function(unit)
		if unit ~= "player" or not CP.pos then return nil end
		return CP.pos.y, CP.pos.x, 0, CP.pos.instance
	end
	_G.time = function() return CP.now or 1800000000 end
end
function CP.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = CP.saved[name] end
	ResetWorld()
end

-- 1. Route parcourue -----------------------------------------------------------------------------
do
	Say("-- compagnon : route parcourue")
	CP.Reset()
	Check("[ROUTE] premier relevé : rien compté", NS:TravelSample(100) == 0)
	CP.pos.x = 11
	local meters = NS:TravelSample(101)
	Check("[ROUTE] 10 yards en 1 s : ~9,1 m", math.abs(meters - 9.144) < 0.01, meters)
	CP.pos.x = 11.2
	Check("[ROUTE] presque immobile : du bruit, rien", NS:TravelSample(102) == 0)
	CP.pos.x = 5000
	Check("[ROUTE] saut énorme (téléportation) : ignoré", NS:TravelSample(103) == 0)
	CP.pos.x = 5030
	Check("[ROUTE] puis on repart du nouvel endroit", NS:TravelSample(104) > 0)
	CP.pos.instance = 2
	CP.pos.x = 5040
	Check("[ROUTE] autre continent : rien", NS:TravelSample(105) == 0)
	CP.pos = nil
	_G.C_Map = nil
	Check("[ROUTE] sans position : rien, sans erreur", NS:TravelSample(106) == 0 and NS.travelLast == nil)
	NS:CompanionData().travel = 350
	_G.GetLocale = function() return "frFR" end
	Check("[ROUTE] moins d'un km : en mètres", NS:TravelText() == "350 m", NS:TravelText())
	NS:CompanionData().travel = 12437
	Check("[ROUTE] en km, virgule française", NS:TravelText() == "12,4 km", NS:TravelText())
	NS:CompanionData().travel = 254300
	Check("[ROUTE] au-delà de 100 km : sans décimale", NS:TravelText() == "254 km", NS:TravelText())
	_G.GetLocale = function() return "enUS" end
	NS:CompanionData().travel = 12437
	Check("[ROUTE] en anglais : point décimal", NS:TravelText() == "12.4 km", NS:TravelText())
	_G.GetLocale = CP.saved.GetLocale
	NS:DB().companionEnabled = false
	CP.pos = { x = 1, y = 1, instance = 1 }
	NS:TravelSample(200)
	CP.pos.x = 10
	Check("[ROUTE] compagnon coupé : rien", NS:TravelSample(201) == 0)
	NS:DB().companionEnabled = true
end

-- 2. Page Compagnon ------------------------------------------------------------------------------
do
	Say("-- compagnon : page du carnet")
	CP.Reset()
	CP.now = 1800000000
	NS:CompanionData().since = CP.now - 11 * 86400
	NS:CompanionData().missionsDone = 34
	NS:CompanionData().travel = 12437
	local capture = NS:CaptureData()
	capture.creatures[7001] = { name = "Kodo", class = "normal", zoneID = 1413, at = CP.now }
	capture.count = 1
	NS.captureAppCache = nil
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.sections.evolution:Click()
	local evo = f.evo
	Check("[CPAGE] le menu : cinq pages", f.sections.evolution and f.sections.menagerie and f.sections.day
		and f.sections.memories and f.sections.zones == nil and f.sections.collection == nil)
	Check("[CPAGE] titre : son nom", f.header.title.text == NS:CompanionName(), f.header.title.text)
	Check("[CPAGE] chiffres : captures, jours, missions, route", evo.stats.captures.value.text == "1"
		and evo.stats.days.value.text == "12" and evo.stats.missions.value.text == "34"
		and evo.stats.km.value.text:find("km", 1, true) ~= nil, evo.stats.days.value.text .. " / " .. evo.stats.km.value.text)
	Check("[CPAGE] une bulle, jamais vide", (evo.bubble.text.text or "") ~= "")
	Check("[CPAGE] envies : quatre lignes", #evo.needs == 4 and evo.needs[1].value.text:find("%%") ~= nil)
	local captured
	for _, cell in ipairs(evo.looks) do if cell.def and cell.def.id == "cap:7001" then captured = cell end end
	for _ = 1, 10 do
		if captured then break end
		NS:CompanionLooksScroll(1)
		for _, cell in ipairs(evo.looks) do if cell.def and cell.def.id == "cap:7001" then captured = cell end end
	end
	Check("[CPAGE] allure : la créature capturée parmi les apparences", captured ~= nil)
	captured.scripts.OnClick(captured)
	Check("[CPAGE] clic : elle devient l'apparence portée", NS:CompanionData().appearance == "cap:7001")
	Check("[CPAGE] cadre et fond : deux listes", #evo.frameStyle.options > 0 and #evo.bgStyle.options > 0)
	Check("[CPAGE] anciennes pages redirigées : Collection -> Compagnon",
		(function() NS:SelectJournalKind("collection"); return f.kind == "evolution" end)())
	f:Hide()
	-- jours ensemble sans date : depuis aujourd'hui
	NS:CompanionData().since = nil
	Check("[CPAGE] compagnon d'avant : jours comptés depuis maintenant", NS:CompanionDaysTogether() >= 1)
end

CP.Done()
