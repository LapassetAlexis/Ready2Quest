-- QuestCompanion 2.0, lot 4 : missions de ménagerie (MissionsMenagerie.lua,
-- Daily.lua, Weekly.lua). Jour : une mission de ménagerie faisable dans la
-- zone (espèce nouvelle, type, élite ou rare ; à défaut « captures »), une
-- d'exploration, celle du caractère. Semaine : « emmène un X et capture 2 X ».
-- Captures comptées par l'enveloppe de ns:CaptureResolve.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local QM = { saved = {}, random = math.random,
	savedTable = rawget(NS, "ZONE_CREATURES"), savedFaction = NS.BestiaryFaction,
	savedStars = NS.CaptureStars, savedEffects = NS.CompanionEffects }
local GLOBALS = { "date", "time", "C_DateAndTime" }
for _, name in ipairs(GLOBALS) do QM.saved[name] = rawget(_G, name) end

function QM.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "journalFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT = nil
	Mock.world.maps[9900] = { mapID = 9900, name = "Val ménagerie", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[9901] = { mapID = 9901, name = "Val voisin", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 9900, 20
	QM.now = 1000000
	_G.time = function() return QM.now end
	_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return 3 * 86400 end }
	_G.date = function(format) if format == "%Y-%m-%d" then return "2026-11-06" end return "06/11/2026" end
	math.random = function(a) if a then return 1 end return 0 end   -- tirage imposé : le premier
	-- ce que les autres lots ajouteront : absent ici, ajouté au cas par cas
	NS.CaptureStars, NS.CompanionEffects = nil, nil
	NS.BestiaryFaction = function() return "H" end
	NS.ZONE_CREATURES = {
		[9900] = { [5001] = { lvl = { 10, 11 }, rank = 0, fr = "Loup", en = "Wolf" },
			[5002] = { lvl = { 12, 12 }, rank = 1, fr = "Gardien", en = "Guard" },
			[5003] = { lvl = { 10, 10 }, rank = 0, fr = "Squelette", en = "Skeleton" } },
		[9901] = { [5005] = { lvl = { 14, 15 }, rank = 0, fr = "Goule", en = "Ghoul" },
			[5006] = { lvl = { 14, 15 }, rank = 0, fr = "Zombie", en = "Zombie" } },
	}
	NS.menagerieStatic = nil
	local data = NS:CompanionData()
	data.tutoDone, data.weekly, data.capture, data.daily = true, nil, nil, nil
	data.appearance = nil
	NS:JournalData().bestiary = {
		[9900] = { [5001] = { name = "Loup", seen = true, killed = 0, type = "Bête" },
			[5003] = { name = "Squelette", seen = true, killed = 0, type = "Mort-vivant" } },
		[9901] = { [5005] = { name = "Goule", seen = true, killed = 0, type = "Mort-vivant" },
			[5006] = { name = "Zombie", seen = true, killed = 0, type = "Undead" } },
	}
	NS:TreatData().treatsInit = true
	NS:DB().companionCapture, NS:DB().companionMissions = true, true
	NS:CompanionUpdateVisibility()
end
function QM.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = QM.saved[name] end
	math.random = QM.random
	NS.ZONE_CREATURES, NS.BestiaryFaction, NS.menagerieStatic = QM.savedTable, QM.savedFaction, nil
	NS.CaptureStars, NS.CompanionEffects = QM.savedStars, QM.savedEffects
	ResetWorld()
end
function QM.Capture(npcID, class, ctype, zoneID, success)
	return NS:CaptureResolve({ success = success ~= false,
		target = { npcID = npcID, name = "Bestiole " .. npcID, class = class or "normal", type = ctype, zoneID = zoneID } })
end

-- 1. Faisabilité et tirage du jour ---------------------------------------------------------------
do
	Say("-- qc2 missions : tirage du jour")
	QM.Reset()
	local t = NS:MenagerieZoneTargets(9900)
	Check("[QM] zone : 3 espèces nouvelles, 1 nommé, 1 Bête, 1 Mort-vivant", t.new == 3 and t.named == 1
		and t.types.beast == 1 and t.types.undead == 1 and t.types.humanoid == nil)
	local m = NS:MissionMenagerieDraw(9900)
	Check("[QM] ménagerie : espèce nouvelle de la zone", m.kind == "capNew" and m.zoneID == 9900 and m.need == 1
		and m.source == "zone" and m.cat == "menagerie")
	m = NS:MissionMenagerieDraw(9900, { { kind = "capNew" } })
	Check("[QM] … sinon un élite ou un rare", m.kind == "capNamed" and m.need == 1)
	m = NS:MissionMenagerieDraw(9900, { { kind = "capNew" }, { kind = "capNamed" } })
	Check("[QM] … sinon un type présent ici (une seule espèce : 1 à capturer)", m.kind == "capType" and m.ctype == "beast"
		and m.need == 1)
	m = NS:MissionMenagerieDraw(9900, { { kind = "capNew" }, { kind = "capNamed" }, { kind = "capType", ctype = "beast" } })
	Check("[QM] changer un type : un autre type", m.kind == "capType" and m.ctype == "undead")
	NS.CaptureStars = function() return 1 end
	m = NS:MissionMenagerieDraw(9900, { { kind = "capNew" }, { kind = "capNamed" } })
	Check("[QM] recapture possible (lot 1) : 2 à capturer", m.need == NS.MENAGERIE_TYPE_NEED)
	NS.CaptureStars = nil
	m = NS:MissionMenagerieDraw(9902)
	Check("[QM] zone sans rien à capturer : « captures », partout", m.kind == "captures" and m.zoneID == nil and m.need == 2)
	Check("[QM] … déjà là : rien d'autre", NS:MissionMenagerieDraw(9902, { m }) == nil)
	-- tout capturé dans la zone
	local creatures = NS:CaptureData().creatures
	for _, npc in ipairs({ 5001, 5002, 5003 }) do creatures[npc] = { name = "x", class = "normal", normal = true } end
	Check("[QM] tout capturé ici : « captures »", NS:MissionMenagerieDraw(9900).kind == "captures")
	NS:CompanionData().capture = nil
	NS:DB().companionCapture = false
	Check("[QM] capture coupée : pas de mission de ménagerie", NS:MissionMenagerieDraw(9900) == nil)
	NS:MissionDraw(9900)
	local daily = NS:DailyData()
	Check("[QM] capture coupée : deux missions quand même, aucune de capture", #daily.missions == 3
		and not NS:MissionIsMenagerie(daily.missions[1]) and not NS:MissionIsMenagerie(daily.missions[2]))
	NS:DB().companionCapture = true
	NS:MissionDraw(9900)
	daily = NS:DailyData()
	Check("[QM] le jour : ménagerie, exploration, caractère", daily.missions[1].kind == "capNew"
		and not NS:MissionIsMenagerie(daily.missions[2]) and daily.missions[3].source == "trait")
	local explore = {}
	for _, kind in ipairs(NS.DAILY_ZONE_MISSIONS) do explore[kind] = true end
	Check("[QM] plus de missions « abattre des espèces » au tirage", not explore.species and not explore.named
		and explore.gather and explore.quests and explore.village and explore.percent)
	Check("[QM] changer la ménagerie : une autre de ménagerie", NS:MissionReroll(1) == true
		and daily.missions[1].kind == "capNamed" and daily.rerolled)
end

-- 2. Libellés -------------------------------------------------------------------------------------
do
	Say("-- qc2 missions : libellés")
	QM.Reset()
	Check("[QM] libellé : espèce nouvelle", NS:MissionLabel({ kind = "capNew", need = 1, zoneID = 9900 })
		== "Capture une espèce jamais capturée (Val ménagerie)")
	Check("[QM] libellé : élite ou rare", NS:MissionLabel({ kind = "capNamed", need = 1, zoneID = 9900 })
		== "Capture un élite ou un rare (Val ménagerie)")
	Check("[QM] libellé : type, pluriel", NS:MissionLabel({ kind = "capType", need = 2, ctype = "undead", zoneID = 9900 })
		== "Capture 2 Morts-vivants (Val ménagerie)", NS:MissionLabel({ kind = "capType", need = 2, ctype = "undead", zoneID = 9900 }))
	Check("[QM] libellé : type, singulier", NS:MissionLabel({ kind = "capType", need = 1, ctype = "beast", zoneID = 9900 })
		== "Capture 1 Bête (Val ménagerie)")
	Check("[QM] libellé : semaine par type", NS:WeeklyLabel({ kind = "typeCapture", need = 2, ctype = "undead" })
		== "Emmène un Mort-vivant et capture 2 Morts-vivants", NS:WeeklyLabel({ kind = "typeCapture", need = 2, ctype = "undead" }))
	Check("[QM] anciens libellés intacts", NS:WeeklyLabel({ kind = "captures", need = 6 }) == "Capture 6 créatures"
		and NS:MissionLabel({ kind = "captures", need = 2 }) == "Capture 2 créatures")
	Check("[QM] source d'une mission sans zone : la zone du tirage", (function()
		NS:DailyData().zoneID = 9900
		return NS:MissionSource({ kind = "captures", source = "zone" }) == "mission de Val ménagerie"
	end)())
	local S = NS.MISSIONS_MENAGERIE_STRINGS
	local missing = {}
	for key in pairs(S.fr) do if not S.en[key] then missing[#missing + 1] = key end end
	for key in pairs(S.en) do if not S.fr[key] then missing[#missing + 1] = key end end
	for _, key in ipairs(NS.CREATURE_TYPES) do
		for _, form in ipairs({ "ONE", "MANY", "A" }) do
			if not S.fr["MMIS_" .. form .. "_" .. key] then missing[#missing + 1] = form .. "_" .. key end
		end
	end
	Check("[QM] textes fr et en, chaque type", #missing == 0, table.concat(missing, ", "))
end

-- 3. Compter les captures du jour --------------------------------------------------------------------
do
	Say("-- qc2 missions : captures du jour")
	QM.Reset()
	local daily = NS:DailyData()
	daily.day, daily.zoneID = NS:DailyToday(), 9900
	daily.missions = {
		{ kind = "capNew", zoneID = 9900, need = 1, have = 0, source = "zone", cat = "menagerie" },
		{ kind = "capType", zoneID = 9900, need = 2, have = 0, source = "zone", cat = "menagerie", ctype = "beast" },
		{ kind = "capNamed", zoneID = 9900, need = 1, have = 0, source = "zone", cat = "menagerie" },
	}
	local m = daily.missions
	QM.Capture(5001, "normal", "Bête", 9900, false)
	Check("[QM] capture ratée : rien", m[1].have == 0 and m[2].have == 0)
	QM.Capture(5001, "normal", "Bête", 9901)
	Check("[QM] autre zone : rien", m[1].have == 0 and m[2].have == 0)
	NS:CompanionData().capture.creatures[5001] = nil
	QM.Capture(5003, "normal", "Mort-vivant", 9900)
	Check("[QM] espèce nouvelle ici : faite ; un autre type ne compte pas", m[1].done and m[2].have == 0)
	m[1].done, m[1].have = nil, 0
	QM.Capture(5003, "normal", "Mort-vivant", 9900, true)
	Check("[QM] espèce déjà capturée : pas « nouvelle »", m[1].have == 0)
	QM.Capture(5001, "normal", nil, 9900)
	Check("[QM] type lu au bestiaire si la cible ne le dit pas", m[2].have == 1, m[2].have)
	QM.Capture(5004, "normal", "Beast", 9900)
	Check("[QM] type en anglais : 2/2, faite", m[2].done)
	QM.Capture(5002, "elite", "Humanoïde", 9900)
	Check("[QM] élite capturé ici : fait", m[3].done)
	-- mission « captures » d'avant (sauvegarde) : toujours comptée
	daily.missions = { { kind = "captures", need = 2, have = 0, source = "zone" },
		{ kind = "species", zoneID = 9900, need = 3, have = 0, source = "zone", start = 0 } }
	QM.Capture(5006, "normal", "Undead", 9901)
	Check("[QM] ancienne mission « captures » : comptée", daily.missions[1].have == 1)
	Check("[QM] ancienne mission « species » : lisible, de ménagerie ou non", NS:MissionLabel(daily.missions[2]):find("Abats", 1, true) ~= nil
		and NS:MissionIsMenagerie(daily.missions[1]) and not NS:MissionIsMenagerie(daily.missions[2]))
end

-- 4. Semaine : emmène un X et capture 2 X ------------------------------------------------------------
do
	Say("-- qc2 missions : semaine par type")
	QM.Reset()
	Check("[QM] aucune créature à emmener : pas de mission par type", NS:MenagerieWeeklyTypeMission() == nil)
	local creatures = NS:CaptureData().creatures
	creatures[5003] = { name = "Squelette", class = "normal", type = "Mort-vivant", normal = true, zoneID = 9900 }
	local def = NS:MenagerieWeeklyTypeMission()
	Check("[QM] un Mort-vivant à emmener, deux à capturer (bestiaire) : mission", def and def.kind == "typeCapture"
		and def.ctype == "undead" and def.need == 2)
	creatures[5005] = { name = "Goule", class = "normal", type = "Mort-vivant", normal = true }
	Check("[QM] plus qu'un Mort-vivant à capturer : pas faisable", NS:MenagerieWeeklyTypeMission() == nil)
	NS.CaptureStars = function() return 2 end
	Check("[QM] … sauf recapture (lot 1)", NS:MenagerieWeeklyTypeMission() ~= nil)
	NS.CaptureStars = nil
	creatures[5005] = nil
	NS:WeeklyDraw()
	local weekly = NS:WeeklyCurrent()
	local typed, shiny
	for _, mission in ipairs(weekly.missions) do
		if mission.kind == "typeCapture" then typed = mission end
		if NS.WEEKLY_SHINY_KINDS[mission.kind] then shiny = mission end
	end
	Check("[QM] semaine : la mission par type, et la chasse au brillant gardée", typed and typed.ctype == "undead"
		and typed.need == 2 and shiny ~= nil and #weekly.missions == 3)
	NS:DB().companionCapture = false
	NS:WeeklyDraw()
	typed = nil
	for _, mission in ipairs(NS:WeeklyCurrent().missions) do if mission.kind == "typeCapture" then typed = mission end end
	Check("[QM] capture coupée : pas de mission par type", typed == nil)
	NS:DB().companionCapture = true

	-- compter : seulement avec un compagnon de ce type
	weekly = NS:WeeklyData()
	weekly.week = NS:WeeklyId()
	weekly.missions = { { kind = "typeCapture", need = 2, have = 0, source = "week", ctype = "undead" } }
	local w = weekly.missions[1]
	NS:CompanionData().appearance = "chicken"
	QM.Capture(5006, "normal", "Mort-vivant", 9901)
	Check("[QM] compagnon d'un autre genre : ne compte pas", w.have == 0)
	NS:CompanionData().appearance = "cap:5003"
	Check("[QM] type du compagnon : l'apparence et sa fiche", NS:MenagerieCompanionType() == "undead")
	QM.Capture(5001, "normal", "Bête", 9900)
	Check("[QM] avec un Mort-vivant, une Bête : ne compte pas", w.have == 0)
	QM.Capture(5005, "normal", "Mort-vivant", 9901)
	Check("[QM] avec un Mort-vivant, un Mort-vivant : compte", w.have == 1)
	NS.CompanionEffects = function() return { typeKey = "beast", strength = 1 } end
	QM.Capture(5006, "normal", "Mort-vivant", 9901)
	Check("[QM] effets du compagnon (lot 2) : leur type l'emporte", w.have == 1 and NS:MenagerieCompanionType() == "beast")
	NS.CompanionEffects = function() return { typeKey = "undead" } end
	local lassos = NS:CaptureData().items.lasso
	QM.Capture(5006, "normal", "Mort-vivant", 9901)
	Check("[QM] 2/2 : faite, récompense de la semaine", w.done and NS:CaptureData().items.lasso == lassos + 1)
	weekly.missions = { { kind = "typeCapture", need = 2, have = 0, source = "week", ctype = "undead" } }
	NS:WeeklyEvent("typeCapture", 1)
	Check("[QM] événement sans type : ne compte pas", weekly.missions[1].have == 0)
	NS:WeeklyEvent("typeCapture", 1, { ctype = "beast" })
	Check("[QM] événement d'un autre type : ne compte pas", weekly.missions[1].have == 0)
	NS:WeeklyEvent("typeCapture", 1, { ctype = "undead" })
	Check("[QM] événement du bon type : compte", weekly.missions[1].have == 1)
end

QM.Done()
