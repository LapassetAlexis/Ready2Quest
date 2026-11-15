-- Gardes de mémoire et de performance (QC 1.6.1 → 3.0, R2Q 1.29.3 → 1.33,
-- docs/AUDIT-PERF.md). Chaque raccourci rend exactement ce que l'ancien
-- chemin rendait, et se refait quand il le faut :
--   * tables de zones paresseuses (fonctions ou chaînes compactes), lecteurs
--     des fichiers livrés ; textes et répliques d'une seule langue sur le
--     client (mêmes réservoirs, clés et textes qu'en tout déclarant) ;
--   * animation du compagnon sans travail inutile (immobile, caché), repère
--     des brillantes ;
--   * infobulle d'unité : une espèce lue (BestiarySpeciesOne) ; ns:AtCamp lu
--     une fois par image ; UNIT_AURA du joueur seulement ; AsciiLower,
--     MapChain, MemoGlobals, erreurs bornées, molette du carnet, conseils en rafale ;
--   * passe 2 (3.1.0) : cadre d'événements commun (ns.On), portes et attente,
--     menu du compagnon, UNIT_AURA rafraîchie sans relecture.
-- La mesure de la mémoire elle-même : python3 tests/run_tests.py --memoire.
local Check, Say, NS, QNS, Mock = T.Check, T.Say, T.NS, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local failed = {}
local function Want(label, ok) if not ok then failed[#failed + 1] = label end return ok end
local function Verdict(name) Check(name, #failed == 0, table.concat(failed, " | ")); failed = {} end
local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do if b[k] ~= v then return false end end
	for k, v in pairs(b) do if a[k] ~= v then return false end end
	return true
end

-- 1. Tables de zones paresseuses ---------------------------------------------------------------------
do
	Say("-- mémoire : tables de zones paresseuses")
	local built = {}
	local t = QNS.LazyZones({
		[20] = function() built[20] = (built[20] or 0) + 1; return { [1] = "b" } end,
		[10] = function() built[10] = (built[10] or 0) + 1; return { [1] = "a" } end,
	})
	Want("rien au chargement", next(built) == nil and rawget(t, 10) == nil)
	Want("ids triés sans construire", table.concat(QNS.ZoneIds(t), ",") == "10,20" and next(built) == nil)
	Want("première lecture construit", t[10][1] == "a" and built[10] == 1)
	local again = t[10]
	Want("seconde lecture gardée", again[1] == "a" and built[10] == 1 and rawget(t, 10) == again)
	Want("inconnue : nil", t[99] == nil)
	local seen = {}
	QNS.ZoneEach(t, function(zoneID, zone) seen[#seen + 1] = zoneID .. "=" .. zone[1] end)
	Want("parcours dans l'ordre", table.concat(seen, ",") == "10=a,20=b")
	Want("parcours : zone pas lue pas gardée", rawget(t, 20) == nil and built[20] == 1)
	local ids = QNS.ZoneIds({ [5] = { 1 }, [3] = { 2 } })
	table.sort(ids)
	Want("table ordinaire", table.concat(ids, ",") == "3,5")
	Verdict("[MEM] LazyZones : construite à la première lecture, gardée ensuite, parcours sans garder")

	local count = 0
	local s = QNS.LazyZones({ [7] = "texte", [3] = function() return { "fn" } end }, function(text) count = count + 1; return { text } end)
	Want("rien au chargement", count == 0 and rawget(s, 7) == nil)
	Want("lue puis gardée", s[7][1] == "texte" and s[7][1] == "texte" and count == 1)
	Want("fonction acceptée", s[3][1] == "fn")
	Want("inconnue / nil", s[99] == nil and s[nil] == nil)
	Want("ZonePeek", QNS.ZonePeek(QNS.LazyZones({ [1] = "x" }, function(x) return { x } end), 1)[1] == "x")
	Verdict("[OPT] zones en chaînes compactes : construites à la lecture, gardées, fonctions acceptées, ZonePeek")

	-- les lecteurs des deux fichiers, sur des lignes faites à la main
	local builders = {}
	for _, file in ipairs({ "ZoneCreatures_Forever", "ZoneQuests_Forever" }) do
		local fake = { IsForeverClient = function() return true end,
			LazyZones = function(_, build) builders[file] = build; return {} end }
		assert(loadfile(ROOT .. "/QuestCompanion/" .. file .. ".lua"))("QuestCompanion", fake)
	end
	local c = builders.ZoneCreatures_Forever("5\t-1\t3\t4\t\tSame\tH\n6\t2\t2\t0\tFr\tEn\n")
	Want("créatures : niveaux négatifs, nom fr vide, f", c[5].lvl[1] == -1 and c[5].lvl[2] == 3 and c[5].rank == 4
		and c[5].fr == "Same" and c[5].en == "Same" and c[5].f == "H" and c[6].fr == "Fr" and c[6].en == "En" and c[6].f == nil)
	local q = builders.ZoneQuests_Forever("9\t-1\t-1\t8589934592\t0\t\tName\t3,40\n10\t5\t3\t0\t4\tNom\tName\n")
	Want("quêtes : -1, grands masques, ex", q[9].lvl == -1 and q[9].req == -1 and q[9].races == 8589934592
		and q[9].classes == 0 and q[9].fr == "Name" and q[9].ex[1] == 3 and q[9].ex[2] == 40 and #q[9].ex == 2
		and q[10].ex == nil and q[10].classes == 4 and q[10].fr == "Nom")
	Verdict("[OPT] lecteurs des fichiers de zones : lignes faites à la main relues champ par champ")

	-- les vraies tables livrées : paresseuses, mais complètes
	local boar = QNS.ZONE_CREATURES[1411] and QNS.ZONE_CREATURES[1411][3098]
	local withF, sameName, withEx, sameQuest
	QNS.ZoneEach(QNS.ZONE_CREATURES, function(_, zone)
		for _, cr in pairs(zone) do
			if cr.f and not withF then withF = cr end
			if cr.fr == cr.en and not sameName then sameName = cr end
		end
	end)
	QNS.ZoneEach(QNS.ZONE_QUESTS, function(_, zone)
		for _, qu in pairs(zone) do
			if qu.ex and not withEx then withEx = qu end
			if qu.fr == qu.en and not sameQuest then sameQuest = qu end
		end
	end)
	Want("des dizaines de zones", #QNS.ZoneIds(QNS.ZONE_CREATURES) > 40 and #QNS.ZoneIds(QNS.ZONE_QUESTS) > 40
		and QNS:ZoneQuestsAvailable())
	Want("Sanglier tacheté", type(boar) == "table" and boar.lvl[1] == 1 and boar.lvl[2] == 2 and boar.rank == 0
		and boar.fr == "Sanglier tacheté" and boar.en == "Mottled Boar" and boar.f == nil)
	Want("faction gardée", withF and (withF.f == "A" or withF.f == "H"))
	Want("nom identique fr = en", sameName and sameName.fr == sameName.en and sameName.fr ~= "" and sameQuest
		and sameQuest.fr == sameQuest.en)
	Want("quête fermée par d'autres : nombres", withEx and type(withEx.ex[1]) == "number" and withEx.ex[1] > 0)
	Verdict("[OPT] tables livrées (créatures, quêtes) : lues à la demande, champs relus comme avant")
end

-- 2. Textes et répliques : une seule langue sur le client ---------------------------------------------
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
	local fr = LoadStrings("frFR")
	_G.GetLocale, _G.ADDON_TESTING = savedLocale, savedTesting
	Want("anglais", en.L.A == "en A" and en.L.C == "en C")
	Want("repli français", en.L.B == "fr B")
	Want("sources non gardées", en.KEEP_STRINGS == false)
	Want("français", fr.L.A == "fr A" and fr.L.B == "fr B" and fr.L.C == "fr C")
	Want("en test : les deux langues", QNS.KEEP_STRINGS == true and type(QNS.COMPANION_LINE_STRINGS) == "table"
		and type(QNS.COMPANION_LINE_STRINGS.en) == "table")
	Verdict("[MEM] textes : la langue du client, repli français, tables sources jetées (gardées en test)")

	local function LoadLines(locale)
		_G.GetLocale = function() return locale end
		_G.ADDON_TESTING = nil
		local fake = { Mark = function() end }
		local ok, err = pcall(function()
			assert(loadfile(ROOT .. "/QuestCompanion/Libs/Socle/Strings.lua"))("QuestCompanion", fake)
			for _, file in ipairs({ "CompanionLines", "PersonalityLines" }) do
				assert(loadfile(ROOT .. "/QuestCompanion/" .. file .. ".lua"))("QuestCompanion", fake)
			end
		end)
		_G.GetLocale, _G.ADDON_TESTING = savedLocale, savedTesting
		assert(ok, err)
		return fake
	end
	local shared = QNS.COMPANION_LINE_STRINGS
	for _, case in ipairs({ { "frFR", "fr" }, { "enUS", "en" } }) do
		local fake = LoadLines(case[1])
		Want("ni clés ni sources gardées", fake.KEEP_STRINGS == false and fake.COMPANION_LINE_STRINGS == nil
			and fake.PERSONALITY_POOLS == nil and rawget(fake.COMPANION_POOLS, "HELLO") == nil)
		local pools, lines, bad = 0, 0, {}
		for name, keys in pairs(QNS.COMPANION_POOLS) do
			local lazy = fake.COMPANION_POOLS[name]
			if lazy then
				pools = pools + 1
				if #lazy ~= #keys then bad[#bad + 1] = name .. "#" end
				for index, key in ipairs(keys) do
					lines = lines + 1
					local want = shared[case[2]][key]
					if want == nil then want = shared.fr[key] end
					if lazy[index] ~= key or fake.L[key] ~= want then bad[#bad + 1] = key end
				end
			end
		end
		Want("équivalence " .. table.concat(bad, ",", 1, math.min(#bad, 8)) .. " / " .. pools .. " / " .. lines,
			#bad == 0 and pools > 300 and lines > 2000)
		Want("liste gardée après lecture", rawget(fake.COMPANION_POOLS, "HELLO") ~= nil
			and fake.COMPANION_POOLS.HELLO == fake.COMPANION_POOLS.HELLO)
		Want("clé hors réservoir rendue telle quelle", fake.L.COMP_SAY_HELLO_1 == "COMP_SAY_HELLO_1"
			and fake.L.COMP_SAY_HELLO_02 == "COMP_SAY_HELLO_02" and fake.L.COMP_SAY_HELLO_999 == "COMP_SAY_HELLO_999"
			and fake.L.COMP_SAY_NOPE == "COMP_SAY_NOPE" and fake.COMPANION_POOLS.NOPE == nil)
		Verdict("[OPT] " .. case[1] .. " : répliques chargées comme sur le client = mêmes réservoirs, clés et textes qu'en tout déclarant")
	end
	local function Has(name) return rawget(QNS.COMPANION_POOLS, name) ~= nil end
	local wrong = {}
	for name, keys in pairs(QNS.COMPANION_POOLS) do
		for index, key in ipairs(keys) do
			local n, i = QNS.CompanionLineParse(key, Has)
			if n ~= name or i ~= index then wrong[#wrong + 1] = key end
		end
	end
	-- le client lit d'abord les textes déclarés : une réplique ne doit pas l'être aussi
	for _, source in pairs({ QNS.COMPANION_STRINGS, QNS.QC_STRINGS, QNS.CAPTURE_STRINGS, QNS.DAILY_STRINGS, QNS.SHINY_STRINGS,
		QNS.WEEKLY_STRINGS, QNS.NOTIFY_STRINGS }) do
		for key in pairs(source and source.fr or {}) do
			if type(key) == "string" and key:find("^COMP_SAY_") then wrong[#wrong + 1] = "déclarée : " .. key end
		end
	end
	Check("[OPT] chaque clé de réplique se relit en son réservoir et son rang, aucune déclarée en texte ordinaire", #wrong == 0,
		table.concat(wrong, ","))
end

-- 3. Animation du compagnon : rien d'inutile à chaque image ---------------------------------------------
do
	Say("-- mémoire : animation au repos, compagnon caché")
	T.ResetWorld()
	QNS:CompanionData().tutoDone = true
	QNS:CompanionUpdateVisibility()
	local frame = QNS:EnsureCompanionFrame()
	local target = frame and (frame.model or frame.fallback)
	if target then
		local calls = 0
		local setPoint = target.SetPoint
		target.SetPoint = function(self, ...) calls = calls + 1; return setPoint(self, ...) end
		QNS.companionFx = nil
		local isHappy = QNS.CompanionIsHappy
		QNS.CompanionIsHappy = function() return false end
		QNS:CompanionFxUpdate(1000)
		local first = calls
		for i = 1, 60 do QNS:CompanionFxUpdate(1000 + i / 60) end
		local still = calls - first
		QNS:CompanionFx("bounce")
		local before = calls
		QNS:CompanionFxUpdate(1000.2)
		Check("[MEM] compagnon immobile : aucun repositionnement par image ; en mouvement : il bouge", still == 0 and calls > before, still)
		target.SetPoint = setPoint
		QNS.CompanionIsHappy = isHappy
		QNS.companionFx = nil
	else
		Check("[MEM] compagnon affiché pour le test", false)
	end
	local driver = QNS.companionFxFrame
	local update = driver and driver.scripts and driver.scripts.OnUpdate
	if frame and update then
		local calls, real = 0, QNS.CompanionFxUpdate
		QNS.CompanionFxUpdate = function(...) calls = calls + 1; return real(...) end
		frame:Show()
		update(driver, 1 / 60)
		Want("affiché : animé", calls == 1)
		frame:Hide()
		for _ = 1, 30 do update(driver, 1 / 60) end
		Want("caché : aucun calcul (" .. calls .. ")", calls == 1)
		frame:Show()
		update(driver, 1 / 60)
		Want("de nouveau affiché : reprend", calls == 2)
		QNS.CompanionFxUpdate = real
	else
		Want("horloge des effets en place", false)
	end
	Verdict("[OPT] animation du compagnon seulement s'il est affiché")
	-- le repère des brillantes : posé, son losange suit l'éclat
	local plate = CreateFrame("Frame")
	_G.C_NamePlate = _G.C_NamePlate or {}
	local savedPlate = _G.C_NamePlate.GetNamePlateForUnit
	_G.C_NamePlate.GetNamePlateForUnit = function() return plate end
	QNS.shinyPlates["nameplate9"] = nil
	local guid = "Creature-0-1-2-3-4-3098-0000000009"
	local savedGUID = _G.UnitGUID
	_G.UnitGUID = function(unit) if unit == "nameplate9" then return guid end return savedGUID(unit) end
	QNS:ShinyState().live[guid] = { at = 1 }
	QNS:ShinyPlateUpdate("nameplate9")
	local mark = QNS.shinyPlateMarks[plate]
	local pulse = mark and mark.scripts and mark.scripts.OnUpdate
	local c1, c2
	if pulse then
		local saved = Mock.now
		pulse(mark); c1 = mark.gem.vertex and mark.gem.vertex[1]
		Mock.now = Mock.now + 0.3
		pulse(mark); c2 = mark.gem.vertex and mark.gem.vertex[1]
		Mock.now = saved
	end
	Check("[OPT] repère de brillante posé, la couleur du losange suit l'éclat", mark ~= nil and mark:IsShown() and type(c1) == "number"
		and type(c2) == "number" and c1 ~= c2, tostring(c1) .. "/" .. tostring(c2))
	QNS:ShinyState().live[guid] = nil
	_G.UnitGUID, _G.C_NamePlate.GetNamePlateForUnit = savedGUID, savedPlate
end

-- 4. Infobulle d'unité : une espèce lue (2.11.1) -----------------------------------------------------
do
	Say("-- 2.11.1 : infobulle du bestiaire, une espèce lue")
	local ZONE = 990001
	local savedAll = rawget(QNS, "ZONE_CREATURES")
	local savedOn, savedZone, savedFaction = rawget(QNS, "CompanionOn"), rawget(QNS, "JournalZone"), rawget(QNS, "BestiaryFaction")
	-- zone livrée de 208 espèces (la plus grosse, Les Tarides) : amicales A, H, AH, neutres
	local zone, factions = {}, { nil, "A", "H", "AH" }
	for i = 1, 208 do
		zone[5000 + i] = { en = "Mob " .. i, fr = "Bête " .. i, rank = i % 7 == 0 and 1 or 0, lvl = { 10, 12 }, f = factions[i % 4 + 1] }
	end
	QNS.ZONE_CREATURES = { [ZONE] = zone }
	-- apprises : une de la table (rang livré prioritaire), une amicale filtrée, une hors table
	QNS:BestiaryData()[ZONE] = {
		[5007] = { name = "Vu", class = "normal", type = "Bête", seen = true, killed = 3, level = 11 },
		[5002] = { name = "Ami", class = "normal", type = "Humanoïde", seen = true, level = 10 },
		[9999] = { name = "Hors table", class = "rare", type = "Bête", seen = true, killed = 1, level = 14 },
	}
	local bad = {}
	for _, faction in ipairs({ "A", "H", false }) do
		QNS.BestiaryFaction = function() return faction or nil end
		local all = QNS:BestiarySpecies(ZONE)
		for _, npcID in ipairs({ 5001, 5002, 5003, 5004, 5007, 5014, 9999, 424242 }) do
			if not Same(QNS:BestiarySpeciesOne(ZONE, npcID), all[npcID]) then bad[#bad + 1] = tostring(faction) .. ":" .. npcID end
		end
		for npcID in pairs(zone) do
			if not Same(QNS:BestiarySpeciesOne(ZONE, npcID), all[npcID]) then bad[#bad + 1] = tostring(faction) .. ":" .. npcID end
		end
	end
	Check("[PERF 2.11.1] BestiarySpeciesOne = BestiarySpecies[npc], chaque espèce, chaque faction", #bad == 0, table.concat(bad, ","))
	QNS.BestiaryFaction = function() return "A" end
	local one = QNS:BestiarySpeciesOne(ZONE, 5007)
	Check("[PERF 2.11.1] fusion (rang livré, mises à mort apprises) ; amicale jamais vue, sans zone ou sans npc : rien",
		one and one.class == "elite" and one.killed == 3 and one.static == true and one.name == "Vu"
		and QNS:BestiarySpeciesOne(ZONE, 5003) == nil and QNS:BestiarySpeciesOne(nil, 5001) == nil
		and QNS:BestiarySpeciesOne(ZONE, nil) == nil, one and one.class)
	-- allocations par survol (200 survols, ramasse-miettes arrêté)
	QNS.CompanionOn = function() return true end
	QNS.JournalZone = function() return ZONE end
	local guid = "Creature-0-4378-1-12-5004-00001A2B3C"
	local function Measure()
		collectgarbage("collect"); collectgarbage("stop")
		local before = collectgarbage("count")
		for _ = 1, 200 do QNS:BestiaryTooltipLine(guid, 11) end
		local kb = (collectgarbage("count") - before) / 200
		collectgarbage("restart")
		return kb
	end
	local lineAfter = QNS:BestiaryTooltipLine(guid, 11)
	local after = Measure()
	local fast = QNS.BestiarySpeciesOne
	QNS.BestiarySpeciesOne = function(self, z, n) return self:BestiarySpecies(z)[n] end   -- l'ancien chemin
	local lineBefore = QNS:BestiaryTooltipLine(guid, 11)
	local before = Measure()
	QNS.BestiarySpeciesOne = fast
	Say(string.format("   allocations par survol : avant %.2f Ko, après %.2f Ko", before, after))
	Check("[PERF 2.11.1] infobulle : même ligne qu'avant", lineAfter ~= nil and lineAfter == lineBefore, tostring(lineAfter))
	Check("[PERF 2.11.1] infobulle : moins de 5 Ko par survol, au moins 10 fois moins qu'avant", after < 5 and after * 10 < before,
		string.format("%.2f / %.2f", after, before))
	QNS:BestiaryData()[ZONE] = nil
	QNS.ZONE_CREATURES, QNS.CompanionOn, QNS.JournalZone, QNS.BestiaryFaction = savedAll, savedOn, savedZone, savedFaction
end

-- 5. AtCamp : une lecture par image (1.32.1) ------------------------------------------------------------
do
	Say("-- 1.32.1 : AtCamp lu une fois par image")
	local CAMP = NS.CAMP_AURAS[1]
	local savedRead, savedAura = C_UnitAuras.GetPlayerAuraBySpellID, Mock.world.auras[CAMP]
	local reads = 0
	C_UnitAuras.GetPlayerAuraBySpellID = function(id, ...) if id == CAMP then reads = reads + 1 end return savedRead(id, ...) end
	Mock.world.auras[CAMP] = { name = "Campfire Nearby", duration = 0 }
	Mock:Advance(1)
	local a, b, c = NS:AtCamp(), NS:AtCamp(), NS:AtCamp()
	Want("trois fois : une lecture", a == true and b == true and c == true and reads == 1)
	Mock.world.auras[CAMP] = nil
	Want("même image : gardée", NS:AtCamp() == true and reads == 1)
	Mock:Advance(0.05)
	Want("image suivante : relue", NS:AtCamp() == false and reads == 2)
	Mock.world.auras[CAMP] = { name = "Campfire Nearby", duration = 0 }
	NS.atCampAt = nil
	Want("atCampAt = nil : relue", NS:AtCamp() == true and reads == 3)
	Want("QC : son cache", QNS:AtCamp() == true and reads == 4 and QNS:AtCamp() == true and reads == 4)
	Verdict("[PERF 1.32.1] AtCamp : une lecture par image et par addon, relue à l'image suivante ou sur demande")
	-- un UNIT_AURA du joueur : Core, cadre du camp, zone sûre… une seule lecture par addon
	Mock:Advance(1)
	NS.wasAtCamp, NS.atCampAt, QNS.atCampAt = false, nil, nil
	reads = 0
	local savedHook = Mock.OnNewFrame
	Mock.OnNewFrame = nil
	Mock:Fire("UNIT_AURA", "player")
	Mock.OnNewFrame = savedHook
	local afterReads = reads
	local cached = NS.AtCamp
	NS.AtCamp = function(self)   -- l'ancien AtCamp (sans cache), pour la mesure « avant »
		for _, spellID in ipairs(self.CAMP_AURAS) do
			local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
			if ok and aura then return true end
		end
		return false
	end
	Mock:Advance(1)
	NS.wasAtCamp, QNS.atCampAt = false, nil
	reads = 0
	Mock.OnNewFrame = nil
	Mock:Fire("UNIT_AURA", "player")
	Mock.OnNewFrame = savedHook
	NS.AtCamp = cached
	Say(string.format("   lectures de l'aura du camp par UNIT_AURA (R2Q + QC) : avant %d, après %d", reads, afterReads))
	Check("[PERF 1.32.1] UNIT_AURA du joueur : au plus une lecture par addon", afterReads >= 1 and afterReads <= 2
		and afterReads < reads, afterReads .. " / " .. reads)
	Mock.world.auras[CAMP] = savedAura
	C_UnitAuras.GetPlayerAuraBySpellID = savedRead
	NS.atCampAt, QNS.atCampAt = nil, nil
	Mock:Fire("UNIT_AURA", "player")
end

-- 6. Audit de performance (docs/AUDIT-PERF.md) --------------------------------------------------------
do
	Say("-- audit perf : UNIT_AURA du joueur seulement")
	local seen = {}
	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(_, event, unit) seen[#seen + 1] = event .. ":" .. tostring(unit) end)
	Want("accepté", NS.RegisterGameEvent(frame, "UNIT_AURA") == true and frame.events.UNIT_AURA == true)
	Mock:Fire("UNIT_AURA", "target")
	Mock:Fire("UNIT_AURA", "nameplate4")
	Mock:Fire("UNIT_AURA", "player")
	Want("seul le joueur arrive : " .. table.concat(seen, ","), #seen == 1 and seen[1] == "UNIT_AURA:player")
	frame:UnregisterEvent("UNIT_AURA")
	Mock:Fire("UNIT_AURA", "player")
	Want("désabonné", #seen == 1)
	local old = frame.RegisterUnitEvent
	frame.RegisterUnitEvent = nil
	Want("repli RegisterEvent", NS.RegisterGameEvent(frame, "UNIT_AURA") == true and frame.events.UNIT_AURA == true
		and not (frame.unitFilter and frame.unitFilter.UNIT_AURA))
	frame.RegisterUnitEvent = old
	frame:UnregisterEvent("UNIT_AURA")
	Want("autre événement ordinaire", NS.RegisterGameEvent(frame, "PLAYER_LOGIN") == true
		and not (frame.unitFilter and frame.unitFilter.PLAYER_LOGIN))
	Verdict("[PERF] RegisterGameEvent : UNIT_AURA filtré au joueur, repli RegisterEvent, autres événements ordinaires")
	local hub = QNS.eventHub
	Check("[PERF] abonnements réels au joueur seulement : R2Q, camp, stats, cadre commun de QC",
		NS.eventFrame.unitFilter and NS.eventFrame.unitFilter.UNIT_AURA and NS.eventFrame.unitFilter.UNIT_AURA.player == true
		and NS.campEventFrame.unitFilter.UNIT_AURA.player == true and NS.statsEventFrame.unitFilter.UNIT_STATS.player == true
		and (not hub.events.UNIT_AURA or hub.unitFilter.UNIT_AURA.player == true))

	local cases = { { "Bénédiction De PUISSANCE", "bénédiction de puissance" }, { "  Well   Fed\t", "well fed" },
		{ "Aura\194\160de Dévotion", "aura de dévotion" }, { "ÉLAN", "Élan" }, { "", "" } }
	local wrong = {}
	for _, case in ipairs(cases) do
		if NS.AsciiLower(case[1]) ~= case[2] then wrong[#wrong + 1] = case[1] .. " -> " .. tostring(NS.AsciiLower(case[1])) end
	end
	Check("[PERF] AsciiLower par table : mêmes résultats, non-chaîne rendue telle quelle ; famille de buff stable", #wrong == 0
		and NS.AsciiLower(nil) == nil and NS.AsciiLower(5) == 5
		and NS.BuffFamily("Bénédiction de puissance") == NS.BuffFamily("Bénédiction de puissance") and NS.BuffFamily(nil) == nil,
		table.concat(wrong, " / "))

	Mock.world.maps[97001] = { mapID = 97001, name = "Sous-carte", parentMapID = 97002 }
	Mock.world.maps[97002] = { mapID = 97002, name = "Zone", parentMapID = 0 }
	local m = NS:MapChain(97001)
	local incomplete = NS:MapChain(97003)
	Mock.world.maps[97003] = { mapID = 97003, name = "Tardive", parentMapID = 97002 }
	local late = NS:MapChain(97003)
	Check("[PERF] MapChain : carte puis parent, gardée ; incomplète relue", #m == 2 and m[1] == 97001 and m[2] == 97002
		and NS:MapChain(97001) == m and #incomplete == 1 and #late == 2 and late[2] == 97002)
	Mock.world.maps[97001], Mock.world.maps[97002], Mock.world.maps[97003] = nil, nil, nil

	local builds = 0
	_G.QC_PERF_FORMAT = "a"
	local get = NS.MemoGlobals({ "QC_PERF_FORMAT" }, function() builds = builds + 1; return { _G.QC_PERF_FORMAT } end)
	local first = get()
	Want("construit une fois", get() == first and builds == 1 and first[1] == "a")
	_G.QC_PERF_FORMAT = "b"
	Want("globale changée", get()[1] == "b" and builds == 2)
	_G.QC_PERF_FORMAT = nil
	Want("globale retirée", get()[1] == nil and builds == 3)
	Verdict("[PERF] MemoGlobals : gardé tant que les globales du client ne bougent pas")
	local xp, named = NS:ParseCombatXP("Gnoll meurt, vous gagnez 45 points d'expérience.")
	local xp2 = NS:ParseCombatXP("Gnoll meurt, vous gagnez 46 points d'expérience.")
	Check("[PERF] ParseCombatXP (motif gardé) : deux messages de suite, autre texte nil", xp == 45 and named == true and xp2 == 46
		and NS:ParseCombatXP("Bonjour") == nil, tostring(xp) .. "/" .. tostring(xp2))

	local saved, savedPrint = NS.errors, _G.print
	NS.errors, NS.errorsDropped = {}, nil
	_G.print = function() end
	for i = 1, NS.ERRORS_MAX + 7 do NS:RecordError("perf", "erreur " .. i) end
	NS:RecordError("perf", "erreur 1")
	Check("[PERF] erreurs : au plus ERRORS_MAX, le reste compté", #NS.errors == NS.ERRORS_MAX and NS.errorsDropped == 7)
	NS.errors, NS.errorsDropped, _G.print = saved, nil, savedPrint

	local journal = QNS.EnsureJournalWindow and QNS:EnsureJournalWindow()
	if journal then
		local during
		local refresh = QNS.RefreshJournal
		QNS.RefreshJournal = function() during = journal.scrollOnly end
		QNS:ScrollJournal(-1)
		local cleared = journal.scrollOnly == nil
		QNS.RefreshJournal = function() error("boum") end
		local ok = pcall(QNS.ScrollJournal, QNS, 1)
		QNS.RefreshJournal = refresh
		Check("[PERF] ScrollJournal : scrollOnly pendant, effacé après, même sur erreur", during == true and cleared
			and not ok and journal.scrollOnly == nil)
	end

	local calls = 0
	local evaluate = QNS.AdviceEvaluate
	QNS.AdviceEvaluate = function() calls = calls + 1 end
	QNS.adviceNextAt = Mock.now + 100
	for _ = 1, 5 do QNS.ADVICE_HANDLERS.QUEST_LOG_UPDATE() end
	QNS.ADVICE_HANDLERS.BAG_UPDATE_DELAYED()
	local burst = calls == 0 and math.abs(QNS.adviceNextAt - (Mock.now + QNS.ADVICE_SOON)) < 1e-6
	QNS.ADVICE_HANDLERS.PLAYER_REGEN_ENABLED()
	Check("[PERF] conseils : rafale de QUEST_LOG_UPDATE regroupée (poll avancé), fin de combat examinée tout de suite",
		burst and calls == 1)
	QNS.AdviceEvaluate = evaluate
	QNS.adviceNextAt = nil
end

-- 7. Passe 2 (3.1.0, docs/AUDIT-PERF.md) : cadre d'événements commun -----------------------------------
do
	Say("-- passe 2 : un seul cadre d'événements (ns.On / ns.Off / ns.Listen)")
	local hub = QNS.eventHub
	local EV = "QC_PERF_TEST_EVENT"
	local calls = {}
	local function Sub(name) return function(...) calls[#calls + 1] = name .. ":" .. table.concat({ ... }, ",") end end
	Want("cadre commun créé", hub ~= nil)
	Want("abonné : écouté", QNS.On(EV, "a", Sub("a")) == true and hub.events[EV] == true)
	QNS.On(EV, "b", Sub("b"))
	Mock:Fire(EV, "x", "y")
	Want("ordre d'abonnement, arguments transmis : " .. table.concat(calls, " "), table.concat(calls, " ") == "a:x,y b:x,y")
	-- une erreur notée sous « qui:ÉVÉNEMENT », les suivants appelés
	local savedErrors, savedPrint = QNS.errors, _G.print
	QNS.errors, _G.print = {}, function() end
	calls = {}
	QNS.On(EV, "a", function() error("boum") end)
	Mock:Fire(EV, "z")
	Want("erreur notée, le suivant appelé", #QNS.errors == 1 and QNS.errors[1].where == "a:" .. EV and calls[1] == "b:z")
	QNS.errors, _G.print = savedErrors, savedPrint
	-- désabonné pendant l'appel : la boucle tient, l'autre n'est plus appelé
	calls = {}
	QNS.On(EV, "a", function() calls[#calls + 1] = "a"; QNS.Off(EV, "b") end)
	Mock:Fire(EV)
	Mock:Fire(EV)
	Want("Off pendant l'appel : " .. table.concat(calls, " "), table.concat(calls, " ") == "a a" and hub.events[EV] == true)
	QNS.Off(EV, "a")
	Want("dernier désabonné : plus écouté par le client", hub.events[EV] == nil and not QNS.Listening(EV))
	-- réabonné : à la fin de l'ordre d'appel, comme un cadre réabonné
	calls = {}
	QNS.On(EV, "b", Sub("b")); QNS.On(EV, "a", Sub("a"))
	Mock:Fire(EV, 1)
	Want("réabonnés dans l'ordre : " .. table.concat(calls, " "), table.concat(calls, " ") == "b:1 a:1")
	-- mise en attente : rang gardé
	calls = {}
	QNS.EventHold("b", true)
	Mock:Fire(EV, 2)
	QNS.EventHold("b", false)
	Mock:Fire(EV, 3)
	Want("attente puis reprise, rang gardé : " .. table.concat(calls, " "), table.concat(calls, " ") == "a:2 b:3 a:3")
	QNS.Unlisten("a"); QNS.Unlisten("b")
	Want("tout retiré", hub.events[EV] == nil)
	-- événement inconnu du client : pas d'erreur, rien d'écouté
	Mock.world.unknownEvents = { QC_PERF_UNKNOWN = true }
	local okUnknown, heard = pcall(QNS.On, "QC_PERF_UNKNOWN", "a", Sub("a"))
	Mock.world.unknownEvents = nil
	Want("événement refusé : sans erreur, non écouté", okUnknown and heard == false and not QNS.Listening("QC_PERF_UNKNOWN"))
	QNS.Unlisten("a")
	-- UNIT_AURA sur le cadre commun : le joueur seulement
	Want("UNIT_AURA du joueur seulement", hub.unitFilter and hub.unitFilter.UNIT_AURA and hub.unitFilter.UNIT_AURA.player == true)
	Verdict("[PERF2] cadre commun : ordre, erreurs isolées, désabonnement (même pendant l'appel), attente, événement refusé")

	-- un seul cadre de QC pour les événements fréquents
	local many = {}
	for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "ZONE_CHANGED",
		"CHAT_MSG_LOOT", "QUEST_TURNED_IN", "PLAYER_ENTERING_WORLD" }) do
		local count = 0
		for _, frame in ipairs(Mock.frames) do
			if frame.mockAddon == hub.mockAddon and frame.events and frame.events[event] then count = count + 1 end
		end
		if count ~= 1 then many[#many + 1] = event .. "=" .. count end
	end
	Check("[PERF2] QC : un seul cadre reçoit chaque événement fréquent (barres de vie, survol, cible, zone, butin, quête)",
		#many == 0, table.concat(many, ", "))

	-- compagnon coupé : ses événements (et ceux de la récolte, du groupe) ne sont plus écoutés
	local db = QNS:DB()
	local savedOn = db.companionEnabled
	QNS:ToggleModuleKey("companionEnabled")
	Want("coupé par les réglages", db.companionEnabled == false)
	Want("butin plus écouté", not QNS.Listening("CHAT_MSG_LOOT"))
	Want("groupe plus écouté", not QNS.Listening("GROUP_ROSTER_UPDATE", "group"))
	Want("compagnon plus abonné", not QNS.Listening("QUEST_TURNED_IN", "companion"))
	Want("le reste (bestiaire, suivi) toujours", QNS.Listening("UPDATE_MOUSEOVER_UNIT") and QNS.Listening("PLAYER_REGEN_ENABLED"))
	local function Polling()
		local count, list = QNS.ClockJobs()
		for i = 1, count do if list[i] == "events:gates" then return true end end
		return false
	end
	Want("porte fermée relue de temps en temps", Polling())
	-- rallumé par un autre chemin (sauvegarde écrite directement) : rouvert à la relecture suivante
	db.companionEnabled = true
	QNS.clockFrame.scripts.OnUpdate(QNS.clockFrame, QNS.EVENT_GATE_POLL + 0.05)
	Want("rouvert par la relecture", QNS.Listening("CHAT_MSG_LOOT") and QNS.Listening("QUEST_TURNED_IN", "companion"))
	Want("toutes ouvertes : plus de relecture", not Polling())
	-- par la commande
	QNS:HandleCommand("module companion off")
	Want("« module companion off » : plus écouté", not QNS.Listening("CHAT_MSG_LOOT"))
	QNS:HandleCommand("module companion on")
	Want("« module companion on » : écouté", QNS.Listening("CHAT_MSG_LOOT"))
	local mood = QNS:CompanionData().needs.mood
	Mock:Fire("QUEST_TURNED_IN", 1)
	Want("rallumé : le compagnon réagit de nouveau", QNS:CompanionData().needs.mood > mood or mood >= 100)
	db.companionEnabled = savedOn
	QNS.EventsResync()
	Verdict("[PERF2] compagnon coupé : butin, groupe et compagnon plus écoutés, rouverts au rallumage (réglage, commande ou relecture)")

	-- conseils : cible, survol, barres de vie mis en attente en combat
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Want("en combat : survol des conseils en attente", not QNS.Listening("UPDATE_MOUSEOVER_UNIT", "advice:units")
		and QNS.Listening("UPDATE_MOUSEOVER_UNIT", "bestiary"))
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Want("hors combat : repris", QNS.Listening("UPDATE_MOUSEOVER_UNIT", "advice:units")
		and QNS.Listening("NAME_PLATE_UNIT_ADDED", "advice:units"))
	Verdict("[PERF2] conseils : cible, survol et barres de vie pas écoutés en combat")

	-- menu du compagnon : GLOBAL_MOUSE_DOWN seulement menu ouvert
	local menu = QNS.EnsureCompanionMenu and QNS:EnsureCompanionMenu()
	if menu then
		Want("menu fermé : pas de clic écouté", not menu.events.GLOBAL_MOUSE_DOWN and menu.events.PLAYER_REGEN_DISABLED)
		QNS:CompanionMenuShow()
		Want("menu ouvert : clics écoutés", menu:IsShown() and menu.events.GLOBAL_MOUSE_DOWN == true)
		menu.IsMouseOver = function() return false end
		Mock:Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
		menu.IsMouseOver = nil
		Want("clic ailleurs : menu fermé, clics plus écoutés", not menu:IsShown() and not menu.events.GLOBAL_MOUSE_DOWN)
		Verdict("[PERF2] menu du compagnon : GLOBAL_MOUSE_DOWN écouté seulement menu ouvert")
	end

	-- UNIT_AURA : des auras seulement rafraîchies ne relancent pas la lecture des auras
	local scans = 0
	local savedState = QNS.CompanionAuraState
	QNS.CompanionAuraState = function(...) scans = scans + 1; return savedState(...) end
	Mock:Fire("UNIT_AURA", "player", { isFullUpdate = false, updatedAuraInstanceIDs = { 12 } })
	local refreshOnly = scans
	Mock:Fire("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { { name = "Food" } } })
	Mock:Fire("UNIT_AURA", "player", { isFullUpdate = false, removedAuraInstanceIDs = { 12 } })
	Mock:Fire("UNIT_AURA", "player", { isFullUpdate = true })
	Mock:Fire("UNIT_AURA", "player")
	QNS.CompanionAuraState = savedState
	Check("[PERF2] UNIT_AURA : rafraîchies seulement -> pas de lecture ; ajoutée, retirée, complète ou sans détail -> lue",
		refreshOnly == 0 and scans == 4, refreshOnly .. " / " .. scans)
end
