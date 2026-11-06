-- Mémoire des addons (QuestCompanion 1.6.1, Ready2Quest 1.29.3) : tables de
-- zones paresseuses (construites à la première lecture), textes d'une seule
-- langue sur le client (repli français pour l'anglais), animation du
-- compagnon sans travail inutile à chaque image.
-- La mesure elle-même : python3 tests/run_tests.py --memoire.
local Check, Say, NS = T.Check, T.Say, T.QNS
local ROOT = rawget(_G, "ADDON_ROOT") or "."

-- 1. Tables de zones paresseuses -------------------------------------------------------------
do
	Say("-- mémoire : tables de zones paresseuses")
	local built = {}
	local makers = {
		[20] = function() built[20] = (built[20] or 0) + 1; return { [1] = "b" } end,
		[10] = function() built[10] = (built[10] or 0) + 1; return { [1] = "a" } end,
	}
	local t = NS.LazyZones(makers)
	Check("[MEM] rien n'est construit au chargement", next(built) == nil and rawget(t, 10) == nil)
	Check("[MEM] identifiants triés, sans rien construire", table.concat(NS.ZoneIds(t), ",") == "10,20" and next(built) == nil)
	Check("[MEM] première lecture : la zone est construite", t[10][1] == "a" and built[10] == 1)
	local again = t[10]
	Check("[MEM] lue une seconde fois : gardée, pas reconstruite", again[1] == "a" and built[10] == 1 and rawget(t, 10) == again)
	Check("[MEM] zone inconnue : nil", t[99] == nil)
	local seen = {}
	NS.ZoneEach(t, function(zoneID, zone) seen[#seen + 1] = zoneID .. "=" .. zone[1] end)
	Check("[MEM] parcours : chaque zone, dans l'ordre", table.concat(seen, ",") == "10=a,20=b")
	Check("[MEM] parcours : la zone pas encore lue n'est pas gardée", rawget(t, 20) == nil and built[20] == 1)
	local plain = { [5] = { 1 }, [3] = { 2 } }
	local ids = NS.ZoneIds(plain)
	table.sort(ids)
	Check("[MEM] table ordinaire : ZoneIds et ZoneEach marchent aussi", table.concat(ids, ",") == "3,5")
	-- la vraie table livrée : paresseuse, mais complète
	local zones = NS.ZoneIds(NS.ZONE_CREATURES)
	Check("[MEM] créatures livrées : des dizaines de zones, lues à la demande", #zones > 40
		and type(NS.ZONE_CREATURES[1411]) == "table" and next(NS.ZONE_CREATURES[1411]) ~= nil)
	Check("[MEM] quêtes livrées : paresseuses aussi", #NS.ZoneIds(NS.ZONE_QUESTS) > 40 and NS:ZoneQuestsAvailable())
end

-- 2. Textes : une seule langue sur le client -----------------------------------------------------
do
	Say("-- mémoire : une seule langue")
	local savedLocale, savedTesting = _G.GetLocale, rawget(_G, "ADDON_TESTING")
	local function LoadStrings(locale)
		_G.GetLocale = function() return locale end
		_G.ADDON_TESTING = nil
		local fake = {}
		assert(loadfile(ROOT .. "/QuestCompanion/Libs/Socle/Strings.lua"))("QuestCompanion", fake)
		fake.RegisterStrings({ A = "fr A", B = "fr B" }, { A = "en A" })
		fake.RegisterStrings({ C = "fr C" }, { C = "en C" })
		return fake
	end
	local en = LoadStrings("enUS")
	Check("[MEM] client anglais : l'anglais", en.L.A == "en A" and en.L.C == "en C")
	Check("[MEM] client anglais : repli français pour une clé sans traduction", en.L.B == "fr B")
	Check("[MEM] client : les tables sources ne sont pas gardées", en.KEEP_STRINGS == false)
	local fr = LoadStrings("frFR")
	Check("[MEM] client français : le français", fr.L.A == "fr A" and fr.L.B == "fr B" and fr.L.C == "fr C")
	_G.GetLocale, _G.ADDON_TESTING = savedLocale, savedTesting
	Check("[MEM] en test : les deux langues et les tables exposées", NS.KEEP_STRINGS == true
		and type(NS.COMPANION_LINE_STRINGS) == "table" and type(NS.COMPANION_LINE_STRINGS.en) == "table")
end

-- 3. Animation : rien à repositionner au repos ------------------------------------------------------
do
	Say("-- mémoire : animation au repos")
	T.ResetWorld()
	NS:CompanionData().tutoDone = true
	NS:CompanionUpdateVisibility()
	local frame = NS:EnsureCompanionFrame()
	local target = frame and (frame.model or frame.fallback)
	Check("[MEM] compagnon affiché pour le test", target ~= nil)
	if target then
		local calls = 0
		local setPoint = target.SetPoint
		target.SetPoint = function(self, ...) calls = calls + 1; return setPoint(self, ...) end
		NS.companionFx = nil
		local isHappy = NS.CompanionIsHappy
		NS.CompanionIsHappy = function() return false end
		NS:CompanionFxUpdate(1000)
		local first = calls
		for i = 1, 60 do NS:CompanionFxUpdate(1000 + i / 60) end
		Check("[MEM] compagnon immobile : pas de repositionnement à chaque image", calls == first, calls - first)
		NS:CompanionFx("bounce")
		local before = calls
		NS:CompanionFxUpdate(1000.2)
		Check("[MEM] en mouvement : il bouge", calls > before)
		target.SetPoint = setPoint
		NS.CompanionIsHappy = isHappy
		NS.companionFx = nil
	end
end
