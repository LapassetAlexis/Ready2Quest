-- Lieux sûrs repérés par leurs PNJ de service (Libs/Socle/Places.lua, généré
-- par tools/gen_places.py depuis data/) : données, ns:KnownPlace, et leur
-- place dans le check avant le départ (entrée et sortie sans changement de
-- sous-zone, vues par la vérification périodique).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local P = { saved = rawget(C_Map, "GetPlayerMapPosition") }
function P.Near(list, x, y, tolerance)
	for _, place in ipairs(list or {}) do
		if math.abs(place[1] - x) <= tolerance and math.abs(place[2] - y) <= tolerance then return place end
	end
	return nil
end
function P.Reset(faction)
	ResetWorld()
	Mock.world.maps[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 1415, mapType = 3 }
	Mock.world.maps[1415] = { mapID = 1415, name = "Royaumes de l'Est", parentMapID = 947, mapType = 2 }
	Mock.world.mapID = 1429
	Mock.world.subzone = nil
	Mock.world.faction = faction or "Alliance"
	Mock.world.px, Mock.world.py = 42.4, 67.1
	C_Map.GetPlayerMapPosition = function(mapID)
		if mapID ~= Mock.world.mapID or not Mock.world.px then return nil end
		return { x = Mock.world.px / 100, y = Mock.world.py / 100 }
	end
	_G.UnitFactionGroup = function() return Mock.world.faction end
	_G.IsInInstance = function() return Mock.world.instance == true end
	NS.nextPlaceCheck = nil
end
function P.Done()
	C_Map.GetPlayerMapPosition = P.saved
	_G.UnitFactionGroup, _G.IsInInstance = nil, nil
	ResetWorld()
end

-- 1. Données générées -------------------------------------------------------------------
do
	Say("-- lieux : données")
	local bad, counts = {}, {}
	for _, client in ipairs({ "forever" }) do
		local data = NS.PLACE_DATA and NS.PLACE_DATA[client]
		counts[client] = 0
		for mapID, list in pairs(data and data.places or {}) do
			if not (data.scale[mapID] and data.scale[mapID][1] > 0 and data.scale[mapID][2] > 0) then
				bad[#bad + 1] = client .. ":" .. mapID .. " sans échelle"
			end
			for _, p in ipairs(list) do
				counts[client] = counts[client] + 1
				if not (p[1] >= 0 and p[1] <= 100 and p[2] >= 0 and p[2] <= 100 and p[3] >= 35 and p[3] <= 160
					and (p[4] == "A" or p[4] == "H" or p[4] == "N") and p[5] > 0) then
					bad[#bad + 1] = client .. ":" .. mapID
				end
			end
		end
	end
	Check("[PLC] lieux de Forever générés, plus de lieux d'Era", counts.forever >= 120 and NS.PLACE_DATA.era == nil,
		counts.forever)
	Check("[PLC] chaque lieu est bien formé (position, rayon, faction, services)", #bad == 0, table.concat(bad, ", "))
	local places = NS.PLACE_DATA.forever.places
	local goldshire = P.Near(places[1429], 42.4, 67.1, 2)
	local razor = P.Near(places[1411], 52.0, 42.2, 2)
	local neutral
	for _, p in ipairs(places[1434] or {}) do if p[4] == "N" and p[5] % 2 == 1 then neutral = p end end
	Check("[PLC] Comté-de-l'Or (Alliance, auberge), Razor Hill (Horde), Booty Bay (neutre, auberge)", goldshire
		and goldshire[4] == "A" and goldshire[5] % 2 == 1 and razor and razor[4] == "H" and neutral ~= nil)
	Check("[PLC] socle : Places.lua dans le .toc", (function()
		for _, file in ipairs(TOC_FILES) do
			if file == "Ready2Quest/Libs/Socle/Places.lua" then return true end
		end
	end)())
end

-- 2. ns:KnownPlace -------------------------------------------------------------------------
do
	Say("-- lieux : sous le joueur")
	P.Reset()
	local place, mapID = NS:KnownPlace()
	Check("[PLC] au cœur de Comté-de-l'Or : le lieu et sa carte", place and place[4] == "A" and mapID == 1429)
	Mock.world.px = 42.4 + 10
	Check("[PLC] à 500 m : aucun lieu", NS:KnownPlace() == nil)
	Mock.world.px = 42.4
	Mock.world.faction = "Horde"
	local none, where, hostile = NS:KnownPlace()
	Check("[PLC] lieu de l'autre faction : signalé hostile", none == nil and where == 1429 and hostile == true)
	Mock.world.faction = "Alliance"
	Mock.world.instance = true
	local inInstance = NS:KnownPlace()
	Mock.world.instance = false
	C_Map.GetPlayerMapPosition = function() return nil end
	local unknown = NS:KnownPlace()
	C_Map.GetPlayerMapPosition = nil
	Check("[PLC] en instance, position inconnue, sans l'API : rien, sans erreur", inInstance == nil and unknown == nil
		and NS:KnownPlace() == nil)
	P.Reset()
	Mock.world.mapID = 20
	Check("[PLC] carte sans lieu repéré", NS:MapHasPlaces() == false and NS:KnownPlace() == nil)
	P.Done()
end

-- 3. Check avant le départ -----------------------------------------------------------------
do
	Say("-- lieux : départ et retour")
	P.Reset()
	NS:DB().exitDelay = 0
	local safe, _, reason, entry = NS:IsCurrentZoneSafe()
	Mock.world.subzone = "Comté-de-l'Or"
	local _, _, namedReason, named = NS:IsCurrentZoneSafe()
	Check("[PLC] zone sûre : un lieu repéré, nommé d'après la carte ou la sous-zone", safe and reason == "place"
		and entry.name == "Forêt d'Elwynn" and entry.source == "known"
		and namedReason == "place" and named.name == "Comté-de-l'Or")
	Mock.world.subzone = nil
	Mock.world.faction = "Horde"
	local hostileSafe, _, hostileReason = NS:IsCurrentZoneSafe()
	Check("[PLC] lieu de l'autre faction : pas une zone sûre", hostileSafe == false and hostileReason == "hostile")
	Mock.world.faction = "Alliance"

	local events = {}
	NS:RegisterCallback("DEPARTURE", function() events[#events + 1] = "depart" end)
	NS:RegisterCallback("RETURN", function() events[#events + 1] = "retour" end)
	NS:Evaluate("login")
	Check("[PLC] connexion dans le lieu : en zone sûre", NS.inSafe == true and NS.safeReason == "place")

	Mock:Advance(NS.EXIT_TICK)           -- une vérification, toujours au village (1.32.2 : horloge à 0,1 s)
	Mock.world.px = 42.4 + 12            -- on s'éloigne, sans changer de sous-zone
	Mock:Advance(0.5)
	Check("[PLC] vérification espacée : rien avant 1,5 s", NS.inSafe == true)
	Mock:Advance(1.5)
	local left = NS.inSafe == false
	Mock:Advance(1)
	Check("[PLC] sortie du lieu vue sans événement de zone, départ annoncé", left and events[1] == "depart", table.concat(events, ","))

	Mock.world.px = 42.4                 -- retour au village
	Mock:Advance(2)
	Check("[PLC] retour vu sans événement de zone", NS.inSafe == true and events[#events] == "retour",
		table.concat(events, ","))

	-- carte sans lieu repéré : aucune évaluation périodique
	local calls, evaluate = 0, NS.Evaluate
	NS.Evaluate = function(self, trigger) calls = calls + 1; return evaluate(self, trigger) end
	Mock.world.mapID = 20
	Mock:Advance(5)
	NS.Evaluate = evaluate
	Check("[PLC] ailleurs : pas de vérification périodique", calls == 0, calls)
	NS.callbacks.DEPARTURE[#NS.callbacks.DEPARTURE] = nil
	NS.callbacks.RETURN[#NS.callbacks.RETURN] = nil
	P.Done()
end
