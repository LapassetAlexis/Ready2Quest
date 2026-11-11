-- Compagnon : missions (Weekly.lua, Daily.lua, MissionsMenagerie.lua) et page
-- Missions du carnet. Semaine (identifiant, tirage, avancer, récompenses
-- sans doublon), récompenses des missions du jour, Ménagerie du carnet
-- (ns:MenagerieList, filtres, tri, page, équiper), missions de créatures
-- (tirage faisable dans la zone, libellés, captures comptées, semaine par
-- type, pourcentage remesuré), page Missions 2.9.1 (cartes, tampon, ↻ une
-- fois par jour, résumé, encarts, colonne de droite, rôles d'encre mesurés).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local SAVED = { random = math.random }
local GLOBALS = { "date", "time", "C_DateAndTime", "C_Texture" }
for _, name in ipairs(GLOBALS) do SAVED[name] = rawget(_G, name) end
SAVED.ZONE_CREATURES, SAVED.BestiaryFaction = rawget(NS, "ZONE_CREATURES"), NS.BestiaryFaction
SAVED.CaptureStars, SAVED.CompanionEffects, SAVED.CompanionTrait = NS.CaptureStars, NS.CompanionEffects, NS.CompanionTrait
local function RestoreAll()
	for _, name in ipairs(GLOBALS) do _G[name] = SAVED[name] end
	math.random = SAVED.random
	NS.ZONE_CREATURES, NS.BestiaryFaction, NS.menagerieStatic = SAVED.ZONE_CREATURES, SAVED.BestiaryFaction, nil
	NS.CaptureStars, NS.CompanionEffects, NS.CompanionTrait = SAVED.CaptureStars, SAVED.CompanionEffects, SAVED.CompanionTrait
	ResetWorld()
end
local function ClearFrames()
	for _, field in ipairs({ "companionFrame", "companionBubble", "journalFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT = nil
end

-- A. Semaine, récompenses, Ménagerie ======================================================
local MS = {}
function MS.Reset()
	ResetWorld()
	ClearFrames()
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	MS.now, MS.left = 1000000, 3 * 86400
	_G.time = function() return MS.now end
	_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return MS.left end }
	_G.date = function(format) if format == "%Y-%m-%d" then return MS.day or "2026-11-05" end return "05/11/2026" end
	math.random = SAVED.random
	local data = NS:CompanionData()
	NS:DB().capture, NS.captureMergedChar = nil, nil; data.tutoDone, data.weekly, data.capture = true, nil, nil
	NS:TreatData().treatsInit = true
	NS:CompanionUpdateVisibility()
end

-- A1. Semaine : identifiant, tirage
do
	Say("-- missions : semaine")
	MS.Reset()
	local week = NS:WeeklyId()
	MS.now, MS.left = MS.now + 86400, MS.left - 86400
	local sameWeek = NS:WeeklyId() == week
	MS.now, MS.left = MS.now + 3 * 86400, 5 * 86400
	local nextWeek = NS:WeeklyId() ~= week
	_G.C_DateAndTime = nil
	local calendar = NS:WeeklyId():sub(1, 1) == "w"
	_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return MS.left end }
	Check("[WEEK] semaine : même d'un jour à l'autre, autre après la remise à zéro, calendrier sans l'API",
		sameWeek and nextWeek and calendar)
	Check("[WEEK] tirage à la première zone, pas deux fois la même semaine", NS:WeeklyPoll() == true
		and #NS:WeeklyCurrent().missions == 3 and NS:WeeklyPoll() == false)
	local kinds, capture = {}, false
	for _, m in ipairs(NS:WeeklyCurrent().missions) do
		kinds[m.kind] = (kinds[m.kind] or 0) + 1
		if m.kind == "captures" or m.kind == "captureNamed" then capture = true end
	end
	local distinct = true
	for _, n in pairs(kinds) do if n > 1 then distinct = false end end
	NS:DB().companionCapture = false
	NS:WeeklyDraw()
	local captureOff = false
	for _, m in ipairs(NS:WeeklyCurrent().missions) do
		if m.kind == "captures" or m.kind == "captureNamed" then captureOff = true end
	end
	NS:DB().companionCapture = true
	Check("[WEEK] trois sortes différentes dont une capture ; capture coupée : aucune", distinct and capture and not captureOff)
	Check("[WEEK] fin de semaine lisible", NS:WeeklyEndsText() == "5 j", tostring(NS:WeeklyEndsText()))
end

-- A2. Semaine : avancer, récompenser
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
	local partial = weekly.missions[1].have == 2 and not weekly.missions[1].done
	NS:MissionEvent("kills", 5)
	Check("[WEEK] les abattus du jour comptent ; faite : plafonnée, un lasso gagné", partial and weekly.missions[1].done
		and weekly.missions[1].have == 3 and items.lasso == 1)
	NS:FireCallback("STAMP", { kind = "zone", name = "Zone", new = true })
	NS:FireCallback("STAMP", { kind = "zone", name = "Zone", new = false })
	NS:WeeklyEvent("captures", 1)
	Check("[WEEK] un tampon compte ; une capture normale ne vaut pas un élite", weekly.missions[2].done
		and not weekly.missions[3].done)
	local sifflets = items.sifflet
	NS:WeeklyEvent("captureNamed", 1)
	local bonus = weekly.allDone and items.sifflet == sifflets + 1 and NS:TreatCount("festin") >= 1
		and NS.companionBubbleKey == "WEEKLY_ALL"
	local festins = NS:TreatCount("festin")
	NS:WeeklyEvent("captureNamed", 1)
	Check("[WEEK] les trois : sifflet et festin en plus, le compagnon s'en réjouit ; pas de second bonus", bonus
		and items.sifflet == sifflets + 1 and NS:TreatCount("festin") == festins)
	NS:DB().companionMissions = false
	Check("[WEEK] missions coupées : rien ne bouge", NS:WeeklyEvent("kills", 1) == false)
	NS:DB().companionMissions = true
end

-- A3. Récompenses des missions du jour
do
	Say("-- missions : récompenses")
	MS.Reset()
	local items = NS:CaptureData().items
	local got = NS:MissionGrant("zone")
	local zone = #got == 2 and got[1].kind == "treat" and got[2].id == "appat" and items.appat == 1
	got = NS:MissionGrant("allDaily")
	Check("[MISR] mission du jour : friandise et appât ; les trois : festin et lasso", zone and got[1].id == "festin"
		and got[2].id == "lasso")
	-- 2.15.0 : plus quelques paillettes (Échoppe du dresseur)
	Check("[MISR] texte de la récompense", NS:MissionRewardText("zone") == "Gain : friandise + Appât savoureux + 3 paillettes",
		NS:MissionRewardText("zone"))
	NS:DB().companionCapture = false
	Check("[MISR] capture coupée : la friandise seule", #NS:MissionGrant("zone") == 1
		and NS:MissionRewardText("zone") == "Gain : friandise")
	NS:DB().companionCapture = true
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

-- A4. Ménagerie du carnet
do
	Say("-- missions : créatures")
	MS.Reset()
	-- une petite table livrée de test : deux zones, une espèce partagée, une
	-- amicale envers la Horde (exclue pour un Horde)
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
	local byNpc = {}
	for _, e in ipairs(all) do byNpc[e.npc] = e end
	Check("[MEN] espèces capturables de ta faction, numéro fixe (zones par niveau), une fiche pour deux zones, inconnues",
		#all == 4 and stats.total == 4 and stats.known == 0 and byNpc[3100].no == 1 and byNpc[3101].no == 2
		and byNpc[3201].no == 3 and byNpc[3200].no == 4 and #byNpc[3101].zones == 2 and not byNpc[3100].known,
		#all .. "/" .. stats.total)
	-- ce qu'on apprend et capture
	NS:BestiaryData()[1413] = { [3201] = { name = "Kodo des plaines", seen = true, killed = 2, type = "Bête", level = 11 },
		[3999] = { name = "Bête hors table", seen = true, killed = 0, class = "normal" } }
	local data = NS:CaptureData()
	data.creatures[3201] = { name = "Kodo des plaines", class = "normal", zoneID = 1413, at = 1700000000 }
	data.creatures[3200] = { name = "Rare des plaines", class = "rare", zoneID = 1413, at = 1800000000, shiny = true }
	data.count = 2
	local zone, zstats = NS:MenagerieList({ zone = 1413 })
	local extra
	for _, e in ipairs(zone) do if e.npc == 3999 then extra = e end end
	Check("[MEN] zone choisie : ses espèces, l'espèce hors table numérotée à la suite", #zone == 4 and zstats.total == 4
		and zstats.captured == 2 and zstats.known == 3 and extra and extra.no == 5 and extra.known,
		#zone .. " " .. zstats.total .. " " .. zstats.captured .. " " .. zstats.known)
	Check("[MEN] filtres « capturées », « à capturer », « à abattre », rareté rare / élite",
		#NS:MenagerieList({ zone = 1413, state = "captured" }) == 2 and #NS:MenagerieList({ zone = 1413, state = "missing" }) == 2
		and #NS:MenagerieList({ zone = 1413, state = "tokill" }) == 3 and #NS:MenagerieList({ zone = "all", rank = "rare" }) == 1
		and #NS:MenagerieList({ zone = "all", rank = "elite" }) == 1)
	local found = NS:MenagerieList({ zone = "all", search = "kodo" })
	Check("[MEN] recherche : sans casse, sans accents, les inconnues ne se trouvent pas", #found == 1 and found[1].npc == 3201
		and #NS:MenagerieList({ zone = "all", search = "sanglier" }) == 0
		and #NS:MenagerieList({ zone = "all", search = "bete hors" }) == 1)
	local byDate = NS:MenagerieList({ zone = "all", sort = "date" })
	local byName = NS:MenagerieList({ zone = "all", sort = "name" })
	local byRank = NS:MenagerieList({ zone = "all", sort = "rank" })
	Check("[MEN] tris : capture la plus récente, connues d'abord par nom, la plus rare d'abord", byDate[1].npc == 3200
		and byDate[2].npc == 3201 and byName[1].known and not byName[#byName].known and byRank[1].class == "rare")

	-- carnet : la page, ses filtres, l'aperçu, l'équipement
	Mock.world.mapID = 1413
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.menZone, f.menState, f.menRank, f.menSearch, f.menSort = "here", "all", "all", "", "no"
	f.sections.menagerie:Click()
	local pane = f.men
	local keys = {}
	for index = 3, #pane.zone.options do keys[#keys + 1] = NS.ZoneSortKey(pane.zone.options[index].label) end
	local sorted = true
	for index = 2, #keys do if keys[index - 1] > keys[index] then sorted = false end end
	Check("[MEN] page : la zone actuelle par défaut, compte, zones (actuelle, toutes, puis par ordre alphabétique)",
		f.kind == "menagerie" and pane:IsShown() and pane.zone:GetValue() == "here"
		and pane.count.text == "2 capturées · brillantes : 1 · 3 croisées · 4 en tout" and #pane.zone.options == 4
		and pane.zone.options[2].value == "all" and sorted, pane.count.text .. " / " .. table.concat(keys, ", "))
	Check("[MEN] clé de tri : accents et article de tête ignorés", NS.ZoneSortKey("Les Tarides") == "tarides"
		and NS.ZoneSortKey("Étangs") == "etangs" and NS.ZoneSortKey("L'Âtreval") == "atreval"
		and NS.ZoneSortKey("The Barrens") == "barrens" and NS.ZoneSortKey("Lesath") == "lesath"
		and NS.ZoneSortKey("Durotar") < NS.ZoneSortKey("Les Tarides"))
	local unknown, kodo
	for _, cell in ipairs(pane.items) do
		if cell.entry and cell.entry.npc == 3101 then unknown = cell end
		if cell.entry and cell.entry.npc == 3201 then kodo = cell end
	end
	-- 2.11.0 (fiche 08) : une inconnue ne montre plus sa rareté, ni ne pâlit
	local muted = NS.Theme.MUTED_LIGHT
	Check("[MEN] inconnue : « ??? » en gris clair opaque, son numéro, pas de liseré",
		unknown and unknown.label.text == "???" and unknown.no.text == "n° 002" and unknown.entry.class ~= "normal"
		and unknown.label.textColor[1] == muted[1] and unknown.label.textColor[3] == muted[3]
		and (unknown.label.alpha or 1) == 1 and not unknown.caught:IsShown())
	Check("[MEN] capturée : son nom, en couleur, liseré vert", kodo and kodo.label.text == "Kodo des plaines"
		and kodo.icon.alpha == 1 and kodo.caught:IsShown() and kodo.caught.vertex[2] == NS.Theme.GREEN[2])
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
	Mock:RunTimers()   -- 2.11.0 : la recherche attend la fin de la frappe
	local searched = f.menSearch == "kodo" and pane.items[1].entry and pane.items[1].entry.npc == 3201
		and not pane.items[2]:IsShown()
	pane.search:SetText("")
	if pane.search.scripts and pane.search.scripts.OnTextChanged then pane.search.scripts.OnTextChanged(pane.search) end
	pane.rank:Choose("rare")
	Check("[MEN] recherche et rareté dans la page", searched and pane.items[1].entry and pane.items[1].entry.npc == 3200
		and not pane.items[2]:IsShown())
	pane.rank:Choose("all")
	local entries = {}
	for _, e in ipairs(NS:MenagerieList({ zone = "all" })) do entries[e.npc] = e end
	-- 2.0 : une confirmation qui compare les effets, puis « Emmener »
	Check("[MEN] clic : rien sur une inconnue, confirmation sur une capturée", NS:JournalMenagerieEquip(entries[3101]) == false
		and NS:JournalMenagerieEquip(entries[3201]) == true and NS.effectsConfirm:IsShown()
		and NS:CompanionData().appearance ~= "cap:3201")
	NS:CompanionConfirmAnswer(true)
	Check("[MEN] confirmée : elle devient le compagnon", NS:CompanionData().appearance == "cap:3201")
	NS:OpenMenagerieZone(1411)
	Check("[MEN] ouverte depuis une zone : filtrée sur elle", f.kind == "menagerie" and f.menZone == 1411
		and pane.zone:GetValue() == 1411)
	f:Hide()
	NS.ZONE_CREATURES, NS.BestiaryFaction, NS.menagerieStatic = SAVED.ZONE_CREATURES, SAVED.BestiaryFaction, nil
end
RestoreAll()

-- B. Missions de créatures (2.0, lot 4) =====================================================
-- Jour : une mission de créatures faisable dans la zone (espèce nouvelle,
-- élite ou rare, type ; à défaut « captures »), une d'exploration, celle du
-- caractère. Semaine : « emmène un X et capture 2 X ».
local QM = {}
-- QM.Reset simule l'absence des lots 1 et 2 ; la vraie fonction des étoiles
-- (lot 1) est remise là où les captures passent réellement par lui
local REAL_STARS = SAVED.CaptureStars
function QM.Reset()
	ResetWorld()
	ClearFrames()
	Mock.world.maps[9900] = { mapID = 9900, name = "Val créatures", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[9901] = { mapID = 9901, name = "Val voisin", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 9900, 20
	_G.time = function() return 1000000 end
	_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return 3 * 86400 end }
	_G.date = function(format) if format == "%Y-%m-%d" then return "2026-11-06" end return "06/11/2026" end
	math.random = function(a) if a then return 1 end return 0 end   -- tirage imposé : le premier
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
function QM.Capture(npcID, class, ctype, zoneID, success)
	return NS:CaptureResolve({ success = success ~= false,
		target = { npcID = npcID, name = "Bestiole " .. npcID, class = class or "normal", type = ctype, zoneID = zoneID } })
end

-- B1. Faisabilité et tirage du jour
do
	Say("-- missions de créatures : tirage du jour")
	QM.Reset()
	local t = NS:MenagerieZoneTargets(9900)
	Check("[QM] zone : 3 espèces nouvelles, 1 nommé, 1 Bête, 1 Mort-vivant", t.new == 3 and t.named == 1
		and t.types.beast == 1 and t.types.undead == 1 and t.types.humanoid == nil)
	local a = NS:MissionMenagerieDraw(9900)
	local b = NS:MissionMenagerieDraw(9900, { { kind = "capNew" } })
	Check("[QM] ordre : espèce nouvelle de la zone, sinon un élite ou un rare", a.kind == "capNew" and a.zoneID == 9900
		and a.need == 1 and a.source == "zone" and a.cat == "menagerie" and b.kind == "capNamed" and b.need == 1)
	a = NS:MissionMenagerieDraw(9900, { { kind = "capNew" }, { kind = "capNamed" } })
	b = NS:MissionMenagerieDraw(9900, { { kind = "capNew" }, { kind = "capNamed" }, { kind = "capType", ctype = "beast" } })
	Check("[QM] … sinon un type présent (1 à capturer), changer un type : un autre", a.kind == "capType" and a.ctype == "beast"
		and a.need == 1 and b.kind == "capType" and b.ctype == "undead")
	NS.CaptureStars = function() return 1 end
	local m = NS:MissionMenagerieDraw(9900, { { kind = "capNew" }, { kind = "capNamed" } })
	Check("[QM] recapture possible (lot 1) : 2 à capturer", m.need == NS.MENAGERIE_TYPE_NEED)
	NS.CaptureStars = nil
	m = NS:MissionMenagerieDraw(9902)
	local empty = m.kind == "captures" and m.zoneID == nil and m.need == 2 and NS:MissionMenagerieDraw(9902, { m }) == nil
	local creatures = NS:CaptureData().creatures
	for _, npc in ipairs({ 5001, 5002, 5003 }) do creatures[npc] = { name = "x", class = "normal", normal = true } end
	Check("[QM] rien à capturer (zone vide ou tout capturé) : « captures », partout, une seule",
		empty and NS:MissionMenagerieDraw(9900).kind == "captures")
	NS:DB().capture, NS.captureMergedChar = nil, nil; NS:CompanionData().capture = nil
	NS:DB().companionCapture = false
	local offDraw = NS:MissionMenagerieDraw(9900) == nil
	NS:MissionDraw(9900)
	local daily = NS:DailyData()
	Check("[QM] capture coupée : trois missions quand même, aucune de capture", offDraw and #daily.missions == 3
		and not NS:MissionIsMenagerie(daily.missions[1]) and not NS:MissionIsMenagerie(daily.missions[2]))
	NS:DB().companionCapture = true
	NS:MissionDraw(9900)
	daily = NS:DailyData()
	Check("[QM] le jour : créatures, exploration, caractère", daily.missions[1].kind == "capNew"
		and not NS:MissionIsMenagerie(daily.missions[2]) and daily.missions[3].source == "trait")
	local explore = {}
	for _, kind in ipairs(NS.DAILY_ZONE_MISSIONS) do explore[kind] = true end
	Check("[QM] plus de missions « abattre des espèces » au tirage", not explore.species and not explore.named
		and explore.gather and explore.quests and explore.village and explore.percent)
	Check("[QM] changer la collection : une autre de créatures", NS:MissionReroll(1) == true
		and daily.missions[1].kind == "capNamed" and daily.rerolled)
end

-- B2. Libellés
do
	Say("-- missions de créatures : libellés")
	QM.Reset()
	local undead2 = NS:MissionLabel({ kind = "capType", need = 2, ctype = "undead", zoneID = 9900 })
	Check("[QM] libellés du jour : nouvelle, élite ou rare, type (pluriel, singulier)",
		NS:MissionLabel({ kind = "capNew", need = 1, zoneID = 9900 }) == "Capture une espèce jamais capturée (Val créatures)"
		and NS:MissionLabel({ kind = "capNamed", need = 1, zoneID = 9900 }) == "Capture un élite ou un rare (Val créatures)"
		and undead2 == "Capture 2 Morts-vivants (Val créatures)"
		and NS:MissionLabel({ kind = "capType", need = 1, ctype = "beast", zoneID = 9900 }) == "Capture 1 Bête (Val créatures)"
		and NS:MissionLabel({ kind = "captures", need = 2 }) == "Capture 2 créatures", undead2)
	local typed = NS:WeeklyLabel({ kind = "typeCapture", need = 2, ctype = "undead" })
	Check("[QM] libellés de la semaine : par type, captures, élite", typed == "Emmène un Mort-vivant et capture 2 Morts-vivants"
		and NS:WeeklyLabel({ kind = "captures", need = 6 }) == "Capture 6 créatures"
		and NS:WeeklyLabel({ kind = "captureNamed", need = 1 }) == "Capture un élite ou un rare", typed)
	NS:DailyData().zoneID = 9900
	Check("[QM] source d'une mission sans zone : la zone du tirage",
		NS:MissionSource({ kind = "captures", source = "zone" }) == "mission de Val créatures")
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
	-- « +3 % » en anglais : le format reçoit le nombre et la zone (relecture 1.2.0)
	local ok, text = pcall(string.format, NS.DAILY_STRINGS.en.MIS_percent, 3, "Westfall")
	Check("[QM] mission « +3 % » en anglais : lisible", ok and text == "Gain 3% in Westfall", tostring(text))
end

-- B3. Compter les captures du jour
do
	Say("-- missions de créatures : captures du jour")
	QM.Reset()
	NS.CaptureStars = REAL_STARS
	local daily = NS:DailyData()
	daily.day, daily.zoneID = NS:DailyToday(), 9900
	daily.missions = {
		{ kind = "capNew", zoneID = 9900, need = 1, have = 0, source = "zone", cat = "menagerie" },
		{ kind = "capType", zoneID = 9900, need = 2, have = 0, source = "zone", cat = "menagerie", ctype = "beast" },
		{ kind = "capNamed", zoneID = 9900, need = 1, have = 0, source = "zone", cat = "menagerie" },
	}
	local m = daily.missions
	QM.Capture(5001, "normal", "Bête", 9900, false)
	local failed = m[1].have == 0 and m[2].have == 0
	QM.Capture(5001, "normal", "Bête", 9901)
	Check("[QM] capture ratée, ou dans une autre zone : rien", failed and m[1].have == 0 and m[2].have == 0)
	NS:CaptureData().creatures[5001] = nil
	QM.Capture(5003, "normal", "Mort-vivant", 9900)
	local newDone = m[1].done and m[2].have == 0
	m[1].done, m[1].have = nil, 0
	QM.Capture(5003, "normal", "Mort-vivant", 9900, true)
	Check("[QM] espèce nouvelle ici : faite (un autre type ne compte pas) ; déjà capturée : pas « nouvelle »",
		newDone and m[1].have == 0)
	QM.Capture(5001, "normal", nil, 9900)
	local fromBestiary = m[2].have == 1
	QM.Capture(5004, "normal", "Beast", 9900)
	Check("[QM] type lu au bestiaire si la cible ne le dit pas, type en anglais : 2/2", fromBestiary and m[2].done, m[2].have)
	QM.Capture(5002, "elite", "Humanoïde", 9900)
	Check("[QM] élite capturé ici : fait", m[3].done)
	-- missions d'avant (sauvegarde) : toujours comptées et lisibles
	daily.missions = { { kind = "captures", need = 2, have = 0, source = "zone" },
		{ kind = "species", zoneID = 9900, need = 3, have = 0, source = "zone", start = 0 } }
	QM.Capture(5006, "normal", "Undead", 9901)
	Check("[QM] anciennes missions « captures » (comptée) et « species » (lisible)", daily.missions[1].have == 1
		and NS:MissionLabel(daily.missions[2]):find("Abats", 1, true) ~= nil
		and NS:MissionIsMenagerie(daily.missions[1]) and not NS:MissionIsMenagerie(daily.missions[2]))
end

-- B4. Semaine : emmène un X et capture 2 X
do
	Say("-- missions de créatures : semaine par type")
	QM.Reset()
	local none = NS:MenagerieWeeklyTypeMission() == nil
	local creatures = NS:CaptureData().creatures
	creatures[5003] = { name = "Squelette", class = "normal", type = "Mort-vivant", normal = true, zoneID = 9900 }
	local def = NS:MenagerieWeeklyTypeMission()
	Check("[QM] rien à emmener : pas de mission ; un Mort-vivant à emmener, deux à capturer : mission", none
		and def and def.kind == "typeCapture" and def.ctype == "undead" and def.need == 2)
	creatures[5005] = { name = "Goule", class = "normal", type = "Mort-vivant", normal = true }
	NS.CaptureStars = nil
	local infeasible = NS:MenagerieWeeklyTypeMission() == nil
	NS.CaptureStars = function() return 2 end
	Check("[QM] plus qu'un à capturer : pas faisable, sauf recapture (lot 1)", infeasible
		and NS:MenagerieWeeklyTypeMission() ~= nil)
	NS.CaptureStars = REAL_STARS
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
	local otherKind = w.have == 0
	NS:CompanionData().appearance = "cap:5003"
	local companionType = NS:MenagerieCompanionType() == "undead"
	QM.Capture(5001, "normal", "Bête", 9900)
	local wrongPrey = w.have == 0
	QM.Capture(5005, "normal", "Mort-vivant", 9901)
	Check("[QM] compte seulement avec un compagnon du type (lu sur l'apparence) et une capture du type",
		otherKind and companionType and wrongPrey and w.have == 1)
	NS.CompanionEffects = function() return { typeKey = "beast", strength = 1 } end
	QM.Capture(5006, "normal", "Mort-vivant", 9901)
	Check("[QM] effets du compagnon (lot 2) : leur type l'emporte", w.have == 1 and NS:MenagerieCompanionType() == "beast")
	NS.CompanionEffects = function() return { typeKey = "undead" } end
	local lassos = NS:CaptureData().items.lasso
	QM.Capture(5006, "normal", "Mort-vivant", 9901)
	Check("[QM] 2/2 : faite, récompense de la semaine", w.done and NS:CaptureData().items.lasso == lassos + 1)
	weekly.missions = { { kind = "typeCapture", need = 2, have = 0, source = "week", ctype = "undead" } }
	NS:WeeklyEvent("typeCapture", 1)
	NS:WeeklyEvent("typeCapture", 1, { ctype = "beast" })
	local ignored = weekly.missions[1].have == 0
	NS:WeeklyEvent("typeCapture", 1, { ctype = "undead" })
	Check("[QM] événement sans type ou d'un autre type : rien ; du bon type : compte", ignored
		and weekly.missions[1].have == 1)
end

-- B5. Mission « pourcentage » tirée le jour de la mise à jour (ancienne formule)
do
	Say("-- missions de créatures : pourcentage remesuré")
	QM.Reset()
	local percent = 20
	local savedCompletion = NS.ZoneCompletion
	NS.ZoneCompletion = function(_, zoneID) if zoneID == 9900 then return { percent = percent, parts = { {}, {} } } end end
	local daily = NS:DailyData()
	-- tirée ce matin avec l'ancienne formule (bestiaire compris : 50 %), 1 point déjà gagné
	daily.day, daily.zoneID, daily.percentV = NS:DailyToday(), 9900, nil
	daily.missions = { { kind = "percent", zoneID = 9900, need = 3, have = 1, start = 50, source = "zone" },
		{ kind = "talks", need = 3, have = 0, source = "zone" }, { kind = "pets", need = 3, have = 0, source = "trait" } }
	NS:MissionRemeasure()
	local mission = daily.missions[1]
	local remeasured = mission.start == 19 and mission.have == 1 and not mission.done and daily.percentV == NS.MISSION_PERCENT_V
	percent = 22
	NS:MissionRemeasure()
	Check("[QM] pourcentage : départ remesuré, progrès gardé, la mission avance de nouveau", remeasured
		and mission.done == true, tostring(mission.start) .. " " .. tostring(mission.have))
	mission.start, mission.done, mission.have = 0, nil, 0
	NS:MissionRemeasure()
	local once = mission.start == 0
	NS:MissionDraw(9900)
	Check("[QM] remesure une seule fois ; tirage du jour : formule notée", once
		and NS:DailyData().percentV == NS.MISSION_PERCENT_V)
	NS.ZoneCompletion = savedCompletion
end
RestoreAll()

-- C. Page Missions du carnet (2.9.1, maquette validée) ======================================
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()
local L = NS.L
local INK = NS.AZEROTH_INK
local MIS = NS.JOURNAL_MISSIONS_LAYOUT
local function Near(a, b) return math.abs((a or 0) - (b or 0)) < 0.011 end
local function Same(c, ref) return c and ref and Near(c[1], ref[1]) and Near(c[2], ref[2]) and Near(c[3], ref[3]) end
local function Role(key) return INK[NS.AZEROTH_CONTRAST[key][1]] end
local function Rect(region, frame) return Snap.Rect(region, { memo = {}, root = frame }) end
local function PageReset(style)
	ResetWorld()
	ClearFrames()
	NS.uiStyleCache = {}
	Mock.world.maps[9800] = { mapID = 9800, name = "Val des missions", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 9800, 20
	_G.date = function(format) if format == "%Y-%m-%d" then return "2026-11-09" end return "2026-45" end
	_G.time = function() return 1800000000 end
	_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return 2 * 86400 + 600 end }
	if style == "azeroth" then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "azeroth" and "azeroth" or "sobre"
	NS:DB().companionMissions = true
	NS:CompanionData().tutoDone = true
	NS.CompanionTrait = function() return "glutton" end
	-- jour : 1 = quêtes (faite), 2 = récolte, 3 = caresses (compagnon)
	local daily, inn = NS:DailyData()
	daily.day, daily.zoneID, daily.rerolled, daily.allDone = NS:DailyToday(), 9800, nil, nil
	daily.missions = {
		{ kind = "quests", need = 2, have = 2, done = true, zoneID = 9800, source = "zone" },
		{ kind = "gather", need = 5, have = 1, zoneID = 9800, source = "zone" },
		{ kind = "pets", need = 3, have = 0, source = "trait", trait = "glutton" },
	}
	inn.card, inn.total, inn.full = 3, 10, 0
	-- semaine : captures (faite), brillante, récolte
	local weekly = NS:WeeklyData()
	weekly.week, weekly.allDone = NS:WeeklyId(), nil
	weekly.missions = {
		{ kind = "captures", need = 6, have = 6, done = true, source = "week" },
		{ kind = "shinyKill", need = 1, have = 0, source = "week" },
		{ kind = "gather", need = 20, have = 15, source = "week" },
	}
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	NS:SelectJournalKind("day")
	return NS.journalFrame
end
local function PageDone()
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	NS.uiStyleCache = {}
	NS:AzerothAtlasOK(true)
	RestoreAll()
end

-- C1. Sortes de missions : icônes et textes
do
	Say("-- page Missions : icônes, textes")
	local missing = {}
	for _, kind in ipairs({ "species", "named", "gather", "quests", "village", "percent", "kills", "places", "meals", "elites",
		"rest", "pets", "turnins", "talks", "nightKills", "calm", "gold", "captures", "capNew", "capNamed", "capType",
		"captureNamed", "dailies", "stamps", "shinyKill", "shinyCapture", "typeCapture" }) do
		if not NS.MISSION_KIND_ICONS[kind] then missing[#missing + 1] = kind end
	end
	Check("[M291] chaque sorte de mission a son icône, une sorte inconnue le point d'interrogation", #missing == 0
		and NS.MissionKindIcon("inconnue"):find("QuestionMark", 1, true) ~= nil, table.concat(missing, ","))
	local fr, en = NS.DAILY_STRINGS and NS.DAILY_STRINGS.fr, NS.DAILY_STRINGS and NS.DAILY_STRINGS.en
	local bad = {}
	for _, key in ipairs({ "MIS_ANYWHERE", "MIS_STAMP", "SUM_trait", "SUM_zone", "SUM_week", "SUM_TRAIT", "SUM_BONUS",
		"SUM_WEEK", "SUM_LEFT", "SUM_DONE" }) do
		if not (fr and fr[key] and en and en[key]) then bad[#bad + 1] = key end
	end
	for key in pairs(fr or {}) do if not en[key] then bad[#bad + 1] = "en:" .. key end end
	Check("[M291] textes FR et EN", fr ~= nil and #bad == 0, table.concat(bad, ","))
end

-- C2. Cartes, grille, tampon, bouton ↻ (habit Sobre)
do
	Say("-- page Missions : cartes")
	local f = PageReset("sobre")
	local day = f.day
	local m = day.missions
	local r = {}
	for i = 1, 6 do r[i] = Rect(m[i], f) end
	Check("[M291] six cartes : compagnon seul en large, deux du jour côte à côte, semaine 2 + la dernière impaire en large",
		#m == 6 and m[1].group == "trait" and m[2].group == "zone" and m[4].group == "week"
		and m[1].wide == true and m[1].cardW == MIS.leftW and m[2].cardW == MIS.half and m[3].cardW == MIS.half
		and Near(r[2].top, r[3].top) and r[3].left > r[2].left + m[2].cardW - 1
		and m[6].cardW == MIS.leftW and Near(r[6].left, r[4].left) and r[6].top >= r[4].top + MIS.cardH
		and r[1].top >= Rect(day.summary.trait, f).top + MIS.sumH)
	Check("[M291] titre et zone séparés, « N'importe où » pour le compagnon", m[2].label.text == "Rends 2 quêtes"
		and m[2].zone.text == "Val des missions" and m[1].zone.text == L.MIS_ANYWHERE and m[1].label.text == "Fais-moi 3 caresses",
		m[2].label.text .. " / " .. tostring(m[2].zone.text))
	local appat, lasso = NS.CAPTURE_AIDS[1].icon, NS.CAPTURE_AIDS[2].icon
	Check("[M291] icône de la sorte, vraie barre et compte, gains en icônes (texte sur carte large seulement)",
		m[2].icon.texture == NS.MISSION_KIND_ICONS.quests and m[5].icon.texture == NS.MISSION_KIND_ICONS.shinyKill
		and m[6].count.text == "15/20" and Near(m[6].bar.ratio, 0.75) and m[6].bar:IsShown()
		and m[1].rewards[2].texture == appat and m[4].rewards[2].texture == lasso
		and m[1].source:IsShown() and not m[4].source:IsShown() and m[4].source.text:find("Lasso tressé", 1, true) ~= nil)
	-- faite : voile vert et tampon, le titre s'arrête avant
	local stamp, title = Rect(m[2].stamp, f), Rect(m[2].label, f)
	Check("[M291] faite : voile et tampon « Faite », titre (deux lignes au plus) qui ne passe pas dessous",
		m[2].tint:IsShown() and m[2].stamp:IsShown() and m[2].stamp.text.text == L.MIS_STAMP
		and not m[3].stamp:IsShown() and not m[3].tint:IsShown() and m[2].label.wordWrap == true and not m[2].zone:IsShown()
		and m[2].label:GetHeight() <= 30 and title.left + title.width <= stamp.left - 2
		and stamp.left + stamp.width <= r[2].left + r[2].width, (title.left + title.width) .. " / " .. stamp.left)
	-- bouton ↻ : seulement sur la carte du jour pas faite, une fois par jour
	local swap = m[3].reroll
	local sr, tr = Rect(swap, f), Rect(m[3].label, f)
	Check("[M291] ↻ : sur la carte du jour pas faite seulement, le titre s'arrête avant", swap and swap:IsShown()
		and m[1].reroll == nil and m[4].reroll == nil and m[2].reroll and not m[2].reroll:IsShown()
		and tr.left + tr.width <= sr.left - 2, (tr.left + tr.width) .. " / " .. sr.left)
	local tip = rawget(_G, "GameTooltip")
	if tip then tip.lines = {} end
	swap:GetScript("OnEnter")(swap)
	local found = false
	for _, line in ipairs(tip and tip.lines or {}) do if tostring(line):find(L.MIS_REROLL_TIP, 1, true) then found = true end end
	if swap:GetScript("OnLeave") then swap:GetScript("OnLeave")(swap) end
	local called
	local reroll = NS.MissionReroll
	NS.MissionReroll = function(self, index) called = index; return reroll(self, index) end
	swap:Click()
	NS.MissionReroll = reroll
	NS:RefreshJournal()
	Check("[M291] ↻ : infobulle, même action (MissionReroll de la mission 2), une fois par jour (caché ensuite)", found
		and called == 2 and NS:DailyData().rerolled == true and not swap:IsShown(), tostring(called))

	-- bande résumé : comptes, pastilles, bonus
	local sum = day.summary
	Check("[M291] résumé : compagnon 0/1 et son caractère, du jour 1/3 (une pastille sur trois), semaine 1/3",
		sum.trait.count.text == "0/1" and #sum.trait.pips == 1 and not sum.trait.pips[1].on
		and sum.trait.detail.text:find(NS:PersonaLabel("glutton"), 1, true) ~= nil
		and sum.zone.count.text == "1/3" and sum.zone.pips[1].on and not sum.zone.pips[2].on and not sum.zone.pips[3].on
		and sum.week.count.text == "1/3" and sum.week.pips[1].on, sum.trait.detail.text)
	Check("[M291] résumé : bonus des 3 du jour (Festin + Lasso), de la semaine (jours restants, Sifflet)",
		sum.zone.detail.text:find(NS:TreatLabel("festin"), 1, true) and sum.zone.detail.text:find(NS:CaptureAidLabel("lasso"), 1, true)
		and sum.week.detail.text:find("2", 1, true) and sum.week.detail.text:find(NS:CaptureAidLabel("sifflet"), 1, true),
		sum.zone.detail.text .. " / " .. sum.week.detail.text)
	Check("[M291] étiquettes : zone du jour, caractère, décompte de la semaine", day.chips.zone:IsShown()
		and day.chips.zone.text.text == "Val des missions" and day.chips.trait.text.text == NS:PersonaLabel("glutton")
		and day.chips.week:IsShown() and day.chips.week.text.text == NS:F("SUM_LEFT", NS:WeeklyEndsText()))
	local zbox, wbox = day.callouts.zone, day.callouts.week
	local zr, last = Rect(zbox, f), Rect(m[3], f)
	Check("[M291] encarts des 3 (jour : Festin et Lasso ; semaine : Sifflet), en pointillés, sous leur groupe",
		zbox:IsShown() and zbox.text.text == L.MIS_ALL_BONUS and zbox.icons[1].texture == NS.TREAT_ICONS.festin
		and zbox.icons[2].texture == lasso and wbox:IsShown() and wbox.text.text == L.WK_ALL_BONUS
		and wbox.icons[2].texture == NS.CAPTURE_AIDS[3].icon and #zbox.dashes > 0 and zbox.dashes[1]:IsShown()
		and zr.top >= last.top + MIS.cardH)
	-- droite : 7 tampons ronds, garde-manger, besace
	local inn, pantry, aid = Rect(day.innPanel, f), Rect(day.pantryPanel, f), Rect(day.aidPanel, f)
	Check("[M291] colonne de droite : 7 tampons (3 obtenus, le 7e le Festin), garde-manger, besace, empilés au-dessus du pied",
		#day.stamps == 7 and day.stamps[3].got and not day.stamps[4].got and day.stamps[7].texture == NS.TREAT_ICONS.festin
		and #day.slots == 5 and day.slots[1]:GetParent() == day.pantryPanel and #day.aids == 3
		and day.aids[1]:GetParent() == day.aidPanel and pantry.top > inn.top + inn.height
		and aid.top > pantry.top + pantry.height and aid.top + aid.height <= Rect(f.footer, f).top,
		(aid.top + aid.height) .. " / " .. Rect(f.footer, f).top)
	-- construit une fois : un rafraîchissement ne crée rien
	local before, card1 = #zbox.dashes, m[1]
	NS:RefreshJournal()
	Check("[M291] rafraîchi : mêmes cartes, mêmes tirets", day.missions[1] == card1 and #zbox.dashes == before)
	NS:DB().companionMissions = false
	NS:RefreshJournal()
	Check("[M291] coupées : une carte large par groupe le dit, résumé sans compte, pas d'encart", m[1].label.text == L.MIS_OFF
		and m[1].cardW == MIS.leftW and not m[1].bar:IsShown() and not m[1].stamp:IsShown() and m[2].label.text == L.MIS_OFF
		and not m[3]:IsShown() and day.summary.zone.count.text == "-" and not day.callouts.zone:IsShown())
	NS:DB().companionMissions = true
	f:Hide()
	PageDone()
end

-- C3. Habit Azeroth : encres des rôles mesurés
do
	Say("-- page Missions : habit Azeroth")
	local f = PageReset("azeroth")
	local day = f.day
	local m = day.missions
	Check("[M291] Azeroth : carnet habillé, cartes sur le fond recadré, encres des rôles (à faire, faite, tampon, résumé, encart)",
		f.azeroth == true and m[1].azBg ~= nil and m[1].azCoverW == m[1].cardW and m[2].azCoverW == m[2].cardW
		and Same(m[2].label.textColor, Role("mcardDone.title")) and Same(m[3].label.textColor, Role("mcard.title"))
		and Same(m[1].source.textColor, Role("mcard.reward")) and Same(m[2].stamp.text.textColor, Role("mission.stamp"))
		and Same(day.summary.zone.count.textColor, Role("summary.count")) and Same(day.callouts.zone.text.textColor, Role("bonus.text"))
		and Same(day.chips.zone.text.textColor, Role("chip.zone")) and Same(day.innTotal.textColor, Role("panel.text")))
	-- les rôles mesurés de la page
	local bad = {}
	for _, key in ipairs({ "mcard.title", "mcard.zone", "mcard.count", "mcard.reward", "mcardDone.title", "mcardDone.zone",
		"mcardDone.count", "mcardDone.reward", "mission.stamp", "chip.zone", "chip.trait", "summary.label", "summary.count",
		"summary.detail", "bonus.text", "panel.text", "panel.soft", "panel.muted", "pager.position" }) do
		local role = NS.AZEROTH_CONTRAST[key]
		if not role or NS.AzerothContrast(INK[role[1]], role[2]) < role[3] then bad[#bad + 1] = key end
	end
	Check("[M291] rôles mesurés de la page Missions : 4,5:1 au moins", #bad == 0, table.concat(bad, ","))
	-- les aplats : la luminance déclarée est celle de leur couleur
	Check("[M291] aplats : luminance exacte du tampon et des étiquettes",
		Near(NS.AzerothLuminance(NS.AZEROTH_MISSION.stamp), NS.AZEROTH_CONTRAST["mission.stamp"][2])
		and Near(NS.AzerothLuminance(NS.AZEROTH_MISSION.chipZone), NS.AZEROTH_CONTRAST["chip.zone"][2])
		and Near(NS.AzerothLuminance(NS.AZEROTH_MISSION.chipTrait), NS.AZEROTH_CONTRAST["chip.trait"][2]))
	-- 2.9.1 : compteur des pagers (Exploration, Créatures) à l'encre mesurée
	NS:SelectJournalKind("progress")
	local prog = f.prog
	Check("[M291] compteurs des pagers (Exploration, Créatures) à l'encre mesurée", prog
		and Same(prog.zonePager.position.textColor, Role("pager.position")) and prog.zonePager.position.azKeep
		and Same(prog.listPager.position.textColor, Role("pager.position"))
		and f.men and Same(f.men.pager.position.textColor, Role("pager.position")))
	f:Hide()
	PageDone()
end
