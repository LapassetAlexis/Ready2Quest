-- QuestCompanion 3.7.0, étape 4, chantier E2 : le monde bouge (WorldDaily.lua).
--   1. Le tirage : même résultat pour deux « joueurs » (faction, noms, ordre de
--      la table), autre le lendemain et la semaine suivante, toujours une
--      espèce normale, aucun math.random, empreinte figée.
--   2. Les effets : brillantes ×2, tailles rares ×2 (la bonne espèce, la bonne
--      zone, ce jour-là), capture +5 % (le bon type, sous le plafond).
--   3. Captures : compteur des pullulations, créature de la semaine (paillettes
--      une fois par semaine et par compte, weekCatch, plus belle prise).
--   4. Bulle d'entrée en zone : une par zone et par jour, créneau des astuces,
--      mode discret, combat.
--   5. Affichage : tuiles de la page Missions (et défilement), encadré de la
--      page Créatures, suivi, infobulle, tuile de la page Communauté.
--   6. Hauts faits livrés, chaînes, contrastes.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme
local L = NS.L

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local Z = { saved = {} }
local GLOBALS = { "UnitFactionGroup", "IsInInstance", "GetRealZoneText", "time", "date", "C_DateAndTime", "UnitLevel",
	"UnitClassification", "UnitCreatureType", "InCombatLockdown", "UnitAffectingCombat", "UnitName", "PlaySound" }
for _, name in ipairs(GLOBALS) do Z.saved[name] = rawget(_G, name) end
Z.saved.ZONE_CREATURES = rawget(NS, "ZONE_CREATURES")
Z.saved.ZONE_LEVELS = NS.ZONE_LEVELS
Z.saved.SHINY_CHANCE = NS.SHINY_CHANCE
Z.saved.dormant, Z.saved.medals = NS.worldDailyDormant, NS.zoneMedalsDormant
Z.saved.random, Z.saved.Quiet = math.random, rawget(NS, "Quiet")
Z.saved.SouvenirShow = rawget(NS, "SouvenirShow")

local WEEK = 7 * 24 * 3600
local NOW0 = 1800000000
local W = { now = NOW0, day = "2026-11-22", level = 25, faction = "Horde", combat = false, left = 2 * 86400 + 600 }

-- Les tables de zone : normales, élites, rares, rares élites, boss, et deux
-- espèces amicales à une faction (jamais tirées)
local function MakeZones(reverse)
	local rows = {}
	local function Add(zone, npc, lo, hi, rank, f)
		rows[#rows + 1] = { zone, npc, { lvl = { lo, hi }, rank = rank, fr = "Bête " .. npc, en = "Beast " .. npc, f = f } }
	end
	for i = 1, 30 do Add(1413, 5000 + i, 10 + i % 8, 12 + i % 8, 0) end
	for i = 31, 40 do Add(1413, 5000 + i, 20 + i % 5, 22 + i % 5, 0) end
	for i = 1, 5 do Add(1413, 5100 + i, 14, 15, 1) end            -- élites
	for i = 1, 3 do Add(1413, 5200 + i, 16, 16, 4) end            -- rares
	Add(1413, 5210, 18, 18, 2)                                    -- rare élite
	Add(1413, 5999, 63, 63, 3)                                    -- boss
	Add(1413, 5301, 12, 12, 0, "A"); Add(1413, 5302, 12, 12, 0, "H")
	for i = 1, 10 do Add(1412, 6000 + i, 3, 5, 0) end
	Add(1412, 6100, 6, 6, 1)
	for i = 1, 10 do Add(1428, 7000 + i, 50, 52, 0) end
	Add(1428, 7100, 55, 55, 4)
	local zones = { [1413] = {}, [1412] = {}, [1428] = {} }
	local first, last, step = 1, #rows, 1
	if reverse then first, last, step = #rows, 1, -1 end
	for i = first, last, step do
		local r = rows[i]
		local entry = {}
		for k, v in pairs(r[3]) do entry[k] = v end
		zones[r[1]][r[2]] = entry
	end
	return zones
end
local ZONES = MakeZones(false)

local function Install()
	_G.UnitFactionGroup = function() return W.faction end
	_G.IsInInstance = function() return false, "none" end
	_G.GetRealZoneText = function() return "" end
	_G.time = function() return W.now end
	_G.date = function(format, t)
		if format == "%Y-%m-%d" then return W.day end
		return os.date(format, t or W.now)
	end
	_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return W.left end }
	_G.UnitLevel = function() return W.level end
	_G.UnitClassification = function() return "normal" end
	_G.UnitCreatureType = function() return "Bête" end
	_G.InCombatLockdown = function() return W.combat end
	_G.UnitAffectingCombat = function() return W.combat end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return nil end
	_G.PlaySound = function() return true end
end

function Z.Reset()
	ResetWorld()
	Install()
	W.now, W.day, W.level, W.faction, W.combat = NOW0, "2026-11-22", 25, "Horde", false
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "journalTracker" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.menagerieStatic, NS.captureAppCache = nil, nil, nil, nil
	NS.shinyState, NS.bestiaryUnits = nil, {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1412] = { mapID = 1412, name = "Mulgore", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1428] = { mapID = 1428, name = "Steppes ardentes", parentMapID = 1415, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.maps[1415] = { mapID = 1415, name = "Royaumes de l'Est", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 25
	NS.ZONE_CREATURES = ZONES
	NS.ZONE_LEVELS = { [1413] = { 10, 25 }, [1412] = { 1, 10 }, [1428] = { 50, 58 } }
	local data = NS:CompanionData()
	data.tutoDone, data.collection = true, nil
	NS:JournalData().bestiary = {}
	NS:TreatData().treatsInit = true
	NS:DB().journalTracker = false
	NS.SHINY_CHANCE = 1 / 150
	NS.worldDailyDormant = nil
	NS.zoneMedalsDormant = true
	NS.Quiet = Z.saved.Quiet
	NS.SouvenirShow = nil
	math.random = Z.saved.random
	NS.WorldDailyReset()
	NS:MenagerieCollectionData().init = true
	NS:CaptureData().zoneMedalsInit = true
end

function Z.Collect()
	local printed, said = {}, {}
	local oldPrint, oldSay = NS.Print, NS.CompanionSay
	NS.Print = function(_, msg) printed[#printed + 1] = tostring(msg) end
	NS.CompanionSay = function(_, pool, opts) said[#said + 1] = { pool = pool, opts = opts or {} }; return true end
	return printed, said, function() NS.Print, NS.CompanionSay = oldPrint, oldSay end
end

-- la date du jour décalée de n jours
local function Day(n)
	local t = os.time({ year = 2026, month = 11, day = 22 + n, hour = 12 })
	return os.date("%Y-%m-%d", t)
end
-- une semaine dont le type est `want` (décalage depuis NOW0, en semaines)
local function WeekOfType(want)
	for k = 0, 200 do
		W.now = NOW0 + k * WEEK
		if NS:WorldWeekType() == want then return k end
	end
	return nil
end
local function Entry(zone, npc) return ZONES[zone][npc] end
local function Glitter() return NS:Paillettes() end

-- 1. Le tirage -------------------------------------------------------------------------------
do
	Say("-- le monde bouge : le même tirage pour tous")
	Z.Reset()
	local s = Steps()
	local function Draw()
		NS.WorldDailyReset()
		local out = {}
		for _, zone in ipairs({ 1413, 1412, 1428 }) do out[#out + 1] = tostring(NS:WorldSwarm(zone)) end
		out[#out + 1] = tostring(NS:WorldWeekType())
		for b = 1, 3 do out[#out + 1] = tostring((NS:WorldWeekCreature(b))) end
		return table.concat(out, ",")
	end
	-- joueur 1 : Horde, table dans un ordre ; joueur 2 : Alliance, noms
	-- anglais, table construite à l'envers, autre niveau
	math.random = function() error("math.random interdit dans le tirage") end
	local ok1, one = pcall(Draw)
	W.faction, W.level = "Alliance", 58
	NS.ZONE_CREATURES = MakeZones(true)
	local static = NS.BestiaryStaticName
	NS.BestiaryStaticName = function(_, entry) return entry.en end
	local ok2, two = pcall(Draw)
	NS.BestiaryStaticName = static
	math.random = Z.saved.random
	NS.ZONE_CREATURES = ZONES
	s.ok("aucun math.random dans le tirage", ok1 and ok2, tostring(one) .. " / " .. tostring(two))
	s.ok("deux joueurs, même date : même tirage", ok1 and ok2 and one == two, tostring(one) .. " / " .. tostring(two))
	s.ok("une créature par tranche, la tranche 40-60 aussi", ok1 and not one:find("nil", 1, true), one)
	-- empreinte figée (stable entre les versions tant que les tables ne changent pas)
	s.ok("empreinte figée", NS.WorldHash("swarm:2026-11-22:1413") == NS.WorldHash("swarm:2026-11-22:1413")
		and NS.WorldHash("swarm:2026-11-22:1413") ~= NS.WorldHash("swarm:2026-11-23:1413"))
	s.ok("empreinte de référence", NS.WorldHash("swarm:2026-11-22:1413") == 4489551, NS.WorldHash("swarm:2026-11-22:1413"))
	s.check("[WD] tirage : même résultat pour deux joueurs (faction, langue, ordre de la table, niveau), sans math.random")
end

do
	Say("-- le monde bouge : autre jour, autre semaine, toujours une espèce normale")
	Z.Reset()
	local s = Steps()
	-- lendemain
	W.day = Day(0)
	local today = NS:WorldSwarm(1413)
	W.day = Day(1)
	local tomorrow = NS:WorldSwarm(1413)
	s.ok("le lendemain : une autre espèce", today and tomorrow and today ~= tomorrow, tostring(today) .. "/" .. tostring(tomorrow))
	-- sur deux mois : ça bouge presque chaque jour, beaucoup d'espèces différentes
	local changes, distinct, prev, bad = 0, {}, nil, {}
	for n = 0, 59 do
		W.day = Day(n)
		for _, zone in ipairs({ 1413, 1412, 1428 }) do
			local npc = NS:WorldSwarm(zone)
			local e = npc and Entry(zone, npc)
			if not (e and e.rank == 0 and e.f == nil) then bad[#bad + 1] = zone .. ":" .. tostring(npc) end
		end
		local npc = NS:WorldSwarm(1413)
		distinct[npc] = true
		if prev and npc ~= prev then changes = changes + 1 end
		prev = npc
	end
	local nd = 0
	for _ in pairs(distinct) do nd = nd + 1 end
	s.ok("60 jours : l'espèce change presque chaque jour", changes >= 50, changes)
	s.ok("60 jours : au moins 20 espèces différentes", nd >= 20, nd)
	s.ok("jamais une élite, une rare, un boss, ni une espèce amicale à une faction", #bad == 0, table.concat(bad, ","))
	-- semaine suivante
	W.day = Day(0)
	local types, typeChanges, prevType, weekChanges, prevWeek = {}, 0, nil, 0, nil
	local weekBad = {}
	for k = 0, 15 do
		W.now = NOW0 + k * WEEK
		local key = NS:WorldWeekType()
		types[key] = true
		if prevType and key ~= prevType then typeChanges = typeChanges + 1 end
		prevType = key
		local npc = NS:WorldWeekCreature(2)
		if prevWeek and npc ~= prevWeek then weekChanges = weekChanges + 1 end
		prevWeek = npc
		for b = 1, 3 do
			local wnpc, _, zone, lo, hi = NS:WorldWeekCreature(b)
			local e = wnpc and Entry(zone, wnpc)
			if not (e and e.rank == 0 and e.f == nil and e.lvl[1] >= lo and e.lvl[2] <= hi) then weekBad[#weekBad + 1] = b .. ":" .. tostring(wnpc) end
		end
	end
	local nt = 0
	for _ in pairs(types) do nt = nt + 1 end
	s.ok("16 semaines : au moins 5 types différents", nt >= 5, nt)
	s.ok("16 semaines : le type change souvent", typeChanges >= 10, typeChanges)
	s.ok("16 semaines : la créature de la semaine change souvent", weekChanges >= 10, weekChanges)
	s.ok("créature de la semaine : normale et dans sa tranche", #weekBad == 0, table.concat(weekBad, ","))
	W.now = NOW0
	local a = NS:WorldWeekCreature(1)
	W.now = NOW0 + WEEK
	local b = NS:WorldWeekCreature(1)
	s.ok("la semaine suivante : une autre créature", a and b and a ~= b, tostring(a) .. "/" .. tostring(b))
	s.ok("tranches : 19 -> 1, 20 -> 2, 39 -> 2, 40 -> 3, 60 -> 3", NS.WorldBracketOf(19) == 1 and NS.WorldBracketOf(20) == 2
		and NS.WorldBracketOf(39) == 2 and NS.WorldBracketOf(40) == 3 and NS.WorldBracketOf(60) == 3)
	s.ok("zone sans table : rien", NS:WorldSwarm(9999) == nil and NS:WorldSwarm(nil) == nil)
	s.check("[WD] tirage : autre le lendemain, autre la semaine suivante, toujours une espèce normale")
end

-- 2. Les effets ------------------------------------------------------------------------------
do
	Say("-- le monde bouge : brillantes ×2 et tailles rares ×2 pour l'espèce en pullulation")
	Z.Reset()
	local s = Steps()
	local swarm = NS:WorldSwarm(1413)
	local other = swarm == 5001 and 5002 or 5001
	local base = NS:ShinyChance("normal", 0)
	-- le tirage : un dé juste au-dessus de la chance de base
	math.random = function(a, b) if a then return Z.saved.random(a, b) end return base * 1.5 end
	s.ok("espèce en pullulation, dans sa zone : brillante (chance ×2)", NS:ShinyRoll("target", { npcID = swarm, zoneID = 1413 }) == true)
	s.ok("autre espèce : chance inchangée", NS:ShinyRoll("target", { npcID = other, zoneID = 1413 }) == false)
	s.ok("même espèce, autre zone : chance inchangée", NS:ShinyRoll("target", { npcID = swarm, zoneID = 1412 }) == false)
	s.ok("hors tirage : ShinyChance n'est pas touchée", NS:ShinyChance("normal", 0) == base)
	W.day = Day(1)
	local again = NS:WorldSwarm(1413) == swarm
	s.ok("le lendemain : l'effet est parti", again or NS:ShinyRoll("target", { npcID = swarm, zoneID = 1413 }) == false)
	W.day = Day(0)
	-- tailles : le dé tombe sur « grand » à 94 %, sur « minuscule » quand les rares pèsent double
	math.random = function(a, b) if a then return Z.saved.random(a, b) end return 0.94 end
	local normalRoll = NS:SpecimenRollSize()
	local doubled = NS.WorldRollSize(2)
	s.ok("tirage ordinaire à 0,94 : grand ; rares ×2 : minuscule", normalRoll == "large" and doubled == "tiny", normalRoll .. "/" .. doubled)
	local idS = NS:SpecimenAdd({ npc = swarm, zone = 1413, stars = 1, origin = "capture" })
	local idO = NS:SpecimenAdd({ npc = other, zone = 1413, stars = 1, origin = "capture" })
	local idZ = NS:SpecimenAdd({ npc = swarm, zone = 1412, stars = 1, origin = "capture" })
	math.random = Z.saved.random
	s.ok("spécimen de l'espèce en pullulation : taille rare", NS:SpecimenGet(idS).size == "tiny", NS:SpecimenGet(idS).size)
	s.ok("autre espèce : tirage ordinaire", NS:SpecimenGet(idO).size == "large", NS:SpecimenGet(idO).size)
	s.ok("autre zone : tirage ordinaire", NS:SpecimenGet(idZ).size == "large", NS:SpecimenGet(idZ).size)
	-- proportions : sur un grand nombre de tirages, les rares pèsent double
	local rare = 0
	for i = 1, 4000 do
		local id = NS.WorldRollSize(2)
		if id == "tiny" or id == "giant" then rare = rare + 1 end
	end
	s.ok("rares ×2 : autour de 8 sur 104", rare > 4000 * 0.055 and rare < 4000 * 0.10, rare)
	-- endormi : rien
	NS.worldDailyDormant = true
	math.random = function(a, b) if a then return Z.saved.random(a, b) end return base * 1.5 end
	s.ok("endormi : aucun effet", NS:ShinyRoll("target", { npcID = swarm, zoneID = 1413 }) == false)
	math.random = Z.saved.random
	NS.worldDailyDormant = nil
	s.check("[WD-FX] brillantes ×2 et tailles rares ×2 : la bonne espèce, la bonne zone, ce jour-là")
end

do
	Say("-- le monde bouge : capture +5 % pour le type de la semaine")
	Z.Reset()
	local s = Steps()
	s.ok("une semaine des Bêtes existe", WeekOfType("beast") ~= nil)
	local beast = { class = "normal", level = 25, type = "Bête", npcID = 5001, stars = 1 }
	local undead = { class = "normal", level = 25, type = "Mort-vivant", npcID = 5002, stars = 1 }
	-- ce que le type de la semaine ajoute aux autres bonus du compagnon
	local function Delta(info)
		NS.worldDailyDormant = true
		local off = NS:CompanionCaptureBonus(info)
		NS.worldDailyDormant = nil
		return NS:CompanionCaptureBonus(info) - off
	end
	s.ok("bonus du compagnon : +0,05 pour une bête", math.abs(Delta(beast) - 0.05) < 1e-9, Delta(beast))
	s.ok("autre type : rien", Delta(undead) == 0, Delta(undead))
	s.ok("type donné par sa clé : pareil", math.abs(Delta({ class = "normal", typeKey = "beast" }) - 0.05) < 1e-9)
	local others = NS:CompanionCaptureBonus(beast) - 0.05
	local value, sure = NS:CaptureChance(beast)
	local plain = NS:CaptureChanceBase(beast)
	s.ok("chance : base × (1 + bonus, +0,05 compris)", not sure and math.abs(value - math.min(NS.CAPTURE_MAX, plain * (1 + others + 0.05))) < 1e-9,
		value .. "/" .. plain)
	-- sous le plafond existant
	local rates = NS.CAPTURE_RATES.normal
	NS.CAPTURE_RATES.normal = NS.CAPTURE_MAX
	s.ok("plafond : jamais au-dessus de CAPTURE_MAX", NS:CaptureChance(beast) <= NS.CAPTURE_MAX + 1e-9, NS:CaptureChance(beast))
	NS.CAPTURE_RATES.normal = rates
	-- la semaine suivante (autre type) : parti
	local k = WeekOfType("beast")
	W.now = NOW0 + (k + 1) * WEEK
	local nextType = NS:WorldWeekType()
	s.ok("la semaine suivante : le bonus suit le nouveau type", nextType ~= "beast" and Delta(beast) == 0, nextType)
	s.ok("la semaine suivante : le nouveau type a le sien", math.abs(Delta({ class = "normal", typeKey = nextType }) - 0.05) < 1e-9)
	s.check("[WD-FX] capture +5 % : le bon type, ajouté aux bonus, sous le plafond, une semaine")
end

-- 3. Captures --------------------------------------------------------------------------------
local function Catch(npc, zone, stars, size)
	return NS:SpecimenAdd({ npc = npc, zone = zone, stars = stars or 1, size = size, origin = "capture" })
end
do
	Say("-- le monde bouge : compteur des pullulations")
	Z.Reset()
	local s = Steps()
	local swarm = NS:WorldSwarm(1413)
	local swarmB = NS:WorldSwarm(1412)
	Catch(swarm == 5001 and 5002 or 5001, 1413)
	s.ok("autre espèce : rien", NS:TallySize("swarmZones") == 0)
	Catch(swarm, 1413)
	s.ok("espèce en pullulation : la zone comptée", NS:TallySize("swarmZones") == 1 and NS:TallyHas("swarmZones", 1413))
	Catch(swarm, 1413)
	s.ok("même zone : une seule fois", NS:TallySize("swarmZones") == 1)
	Catch(swarmB, 1412)
	s.ok("autre zone : deux", NS:TallySize("swarmZones") == 2)
	NS:SpecimenAdd({ npc = swarm, zone = 1428, stars = 1, origin = "trade" })
	s.ok("un échange ne compte pas", NS:TallySize("swarmZones") == 2)
	s.check("[WD-CAP] pullulation capturée : ns:TallyMark(\"swarmZones\", zone)")
end

do
	Say("-- le monde bouge : créature de la semaine, paillettes une fois par semaine et par compte")
	Z.Reset()
	local s = Steps()
	local npc = NS:WorldWeekCreature(2)
	local low = NS:WorldWeekCreature(1)
	local before = Glitter()
	local printed, said, restore = Z.Collect()
	local id1 = Catch(npc, 1413, 1, "normal")
	restore()
	s.ok("première prise : +10 paillettes", Glitter() - before == 10, Glitter() - before)
	s.ok("weekCatch : 1", NS:TallyGet("weekCatch") == 1, NS:TallyGet("weekCatch"))
	s.ok("une ligne de chat", #printed == 1 and printed[1]:find("+10 paillettes", 1, true) ~= nil, printed[1])
	s.ok("paillettes de la raison « week »", NS:TallyGet("glitter:week") == 10, NS:TallyGet("glitter:week"))
	local best = NS:WorldWeekBest(npc)
	s.ok("plus belle prise gardée", best and best.stars == 1 and best.id == id1 and best.size == "normal")
	before = Glitter()
	Catch(npc, 1413, 2, "large")
	s.ok("deuxième prise : rien de plus", Glitter() == before and NS:TallyGet("weekCatch") == 1)
	best = NS:WorldWeekBest(npc)
	s.ok("plus belle prise : plus d'étoiles l'emportent", best.stars == 2 and best.size == "large")
	Catch(npc, 1413, 1, "giant")
	s.ok("moins d'étoiles : gardée telle quelle", NS:WorldWeekBest(npc).stars == 2)
	-- même étoiles : l'indice de taille départage
	local rec = NS:WorldWeekRecord()
	rec.best[npc] = { stars = 2, size = "normal", zi = 100, id = 1 }
	local idG = Catch(npc, 1413, 2, "giant")
	s.ok("mêmes étoiles : le plus grand indice", NS:WorldWeekBest(npc).id == idG and NS:WorldWeekBest(npc).zi > 100)
	before = Glitter()
	Catch(low, 1412)
	s.ok("une autre créature de la semaine, même semaine : rien de plus", Glitter() == before)
	-- un autre personnage du compte : déjà payé
	s.ok("compte : la sauvegarde est celle des captures", NS:CaptureData().worldWeek.paid == true)
	-- semaine suivante
	W.now = NOW0 + WEEK
	local nextNpc = NS:WorldWeekCreature(2)
	s.ok("semaine suivante : nouvelle sauvegarde", NS:WorldWeekRecord().paid == nil and NS:WorldWeekBest(nextNpc) == nil)
	before = Glitter()
	NS.Quiet = function() return true end
	printed, said, restore = Z.Collect()
	Catch(nextNpc, 1413)
	restore()
	NS.Quiet = Z.saved.Quiet
	s.ok("semaine suivante : +10 de nouveau, weekCatch 2", Glitter() - before == 10 and NS:TallyGet("weekCatch") == 2)
	s.ok("mode discret : payée sans ligne de chat", #printed == 0, #printed)
	NS.worldDailyDormant = true
	W.now = NOW0 + 2 * WEEK
	before = Glitter()
	Catch(NS:WorldWeekCreature(2), 1413)
	s.ok("endormi : rien", Glitter() == before)
	NS.worldDailyDormant = nil
	s.check("[WD-CAP] créature de la semaine : 10 paillettes et weekCatch une fois par semaine et par compte, plus belle prise")
end

-- 4. Bulle d'entrée en zone ------------------------------------------------------------------
do
	Say("-- le monde bouge : bulle d'entrée en zone")
	Z.Reset()
	local s = Steps()
	local function Enter(mapID)
		Mock.world.mapID = mapID
		local printed, said, restore = Z.Collect()
		NS:CompanionOnZone(true)
		restore()
		local mine = 0
		for _, call in ipairs(said) do
			if call.opts.line == "WORLD_SAY_SWARM" then
				mine = mine + 1
				s.ok("créneau des astuces", call.pool == "TIP")
			end
		end
		return mine
	end
	s.ok("entrée aux Tarides : une bulle", Enter(1413) == 1)
	s.ok("ressortie, retour le même jour : rien", Enter(1412) == 1 and Enter(1413) == 0)
	s.ok("le lendemain : de nouveau", (function() W.day = Day(1); return Enter(1413) end)() == 1)
	W.day = Day(2)
	NS.Quiet = function() return true end
	s.ok("mode discret : rien", Enter(1413) == 0)
	NS.Quiet = Z.saved.Quiet
	W.combat = true
	s.ok("en combat : rien (et rien de noté pour après)", Enter(1413) == 0)
	W.combat = false
	-- refusée (une autre bulle) : elle prend la prochaine astuce
	local _, said, restore = Z.Collect()
	NS.CompanionSay = function(_, pool, opts) said[#said + 1] = { pool = pool, opts = opts or {} }; return true end
	restore()
	local tried = 0
	local saySaved = NS.CompanionSay
	NS.CompanionSay = function() tried = tried + 1; return false end
	Mock.world.mapID = 1413
	NS:CompanionOnZone(true)
	NS.CompanionSay = saySaved
	local printed2, said2, restore2 = Z.Collect()
	NS:CompanionTryTip()
	restore2()
	local got = false
	for _, call in ipairs(said2) do if call.opts.line == "WORLD_SAY_SWARM" then got = true end end
	s.ok("refusée à l'entrée, dite à l'astuce suivante", tried >= 1 and got)
	local _, said3, restore3 = Z.Collect()
	NS:CompanionTryTip()
	restore3()
	local again = false
	for _, call in ipairs(said3) do if call.opts.line == "WORLD_SAY_SWARM" then again = true end end
	s.ok("une seule fois", not again)
	Mock.world.mapID = 9999
	s.ok("zone sans sceau : rien", Enter(30) == 0)
	s.check("[WD-SAY] bulle : une par zone et par jour, astuce, jamais en mode discret ni en combat")
end

-- 5. Affichage -------------------------------------------------------------------------------
local function OpenDay()
	NS:ToggleJournal(true)
	NS:SelectJournalKind("day")
	return NS.journalFrame, NS.journalFrame.day
end
local function Top(region)
	local _, _, _, _, y = region:GetPoint()
	return y
end
do
	Say("-- le monde bouge : « Aujourd'hui en Azeroth » en tête de la page Missions")
	Z.Reset()
	local s = Steps()
	local k = WeekOfType("beast")
	local npc, name = NS:WorldWeekCreature(2)
	Catch(npc, 1413, 2, "large")
	NS:WorldWeekRecord().best[npc].zi = 112
	local frame, pane = OpenDay()
	local box = pane.world
	s.ok("trois tuiles et l'intertitre", box and #box.tiles == 3 and box.head:IsShown() and box.shown)
	local swarmNpc, swarmName = NS:WorldSwarm(1413)
	local t1, t2, t3 = box.tiles[1], box.tiles[2], box.tiles[3]
	s.ok("pullulation : l'espèce de la zone où l'on est", t1.name.text == swarmName and t1.line.text == "Les Tarides · brillantes ×2, tailles rares ×2",
		t1.line.text)
	s.ok("« Demain : une autre espèce »", t1.extra.text == "Demain : une autre espèce")
	s.ok("étiquettes", t1.tag.label.text == "PULLULATION DU JOUR" and t2.tag.label.text == "TYPE DE LA SEMAINE"
		and t3.tag.label.text == "CRÉATURE DE LA SEMAINE", t1.tag.label.text)
	s.ok("type : « Bêtes », « Capture +5 % sur toutes les bêtes »", t2.name.text == "Bêtes" and t2.line.text == "Capture +5 % sur toutes les bêtes",
		t2.line.text)
	s.ok("type : jusqu'au jour de la remise à zéro", t2.extra.text:find("^Jusqu'à ") ~= nil, t2.extra.text)
	s.ok("créature : la tranche du personnage et ta plus belle prise", t3.name.text == name
		and t3.line.text == "Niveaux 20 à 40 · ta plus belle prise : 2 étoiles, Grand (112)", t3.line.text)
	s.ok("sans ns.SouvenirShow : pas de bouton", not t3.button:IsShown())
	s.ok("la note sous les tuiles", box.note.text:find("tiré de la date", 1, true) ~= nil)
	-- le reste descend de l'encart
	local K = NS.WORLD_TODAY_LAYOUT
	local ui = NS.JournalUI
	s.ok("le reste de la page descend", math.abs(Top(pane.summary[1]) - (ui.TOP - K.restY)) < 0.01 and math.abs(Top(box.head) - ui.TOP) < 0.01,
		Top(pane.summary[1]))
	-- molette : un cran, bornée
	s.ok("la page déborde : la molette a de quoi défiler", (pane.scrollMax or 0) > 0, pane.scrollMax)
	NS:ScrollJournal(-1)
	s.ok("un cran : tout remonte de 40 px", math.abs(Top(pane.summary[1]) - (ui.TOP - K.restY + 40)) < 0.01 and frame.offset == 1,
		Top(pane.summary[1]))
	for _ = 1, 40 do NS:ScrollJournal(-1) end
	s.ok("borné à ce qui déborde", frame.offset == pane.scrollMax, frame.offset)
	NS:ScrollJournal(80)
	s.ok("revenu en haut", frame.offset == 0 and math.abs(Top(box.head) - ui.TOP) < 0.01)
	s.ok("la page coupe ce qui sort de sa bande", pane.clipsChildren == true)
	-- pas encore capturée
	NS:WorldWeekRecord().best = {}
	NS:RefreshJournal()
	s.ok("pas encore capturée", t3.line.text == "Niveaux 20 à 40 · pas encore capturée", t3.line.text)
	-- hors zone à sceau
	Mock.world.mapID = 30
	NS:RefreshJournal()
	s.ok("hors zone de créatures : la tuile le dit", t1.name.text == L.WORLD_SWARM_NONE)
	Mock.world.mapID = 1413
	-- endormi (ou capture coupée) : la page d'avant
	NS.worldDailyDormant = true
	NS:RefreshJournal()
	s.ok("éteint : pas d'encart, la page d'avant", not box.head:IsShown() and not t1:IsShown()
		and math.abs(Top(pane.summary[1]) - ui.TOP) < 0.01)
	NS.worldDailyDormant = nil
	frame:Hide()
	s.check("[WD-UI] Missions : trois tuiles en tête, le reste descend, la molette fait défiler")
end

do
	Say("-- le monde bouge : encadré, suivi, infobulle, Communauté")
	Z.Reset()
	local s = Steps()
	local swarm, swarmName = NS:WorldSwarm(1413)
	-- encadré de la page Créatures
	NS:ToggleJournal(true)
	NS:OpenMenagerieZone(1413)
	local strip = NS.journalFrame.men.collection
	s.ok("encadré : « Pullulation : <espèce> (brillantes ×2) »", strip.swarm.text == "Pullulation : " .. swarmName .. " (brillantes ×2)",
		strip.swarm.text)
	NS.journalFrame.menZone = "all"
	NS:RefreshJournal()
	s.ok("toutes zones : pas de ligne", strip.swarm.text == "")
	NS.journalFrame:Hide()
	-- suivi
	local swarmGoal, weekGoal
	for _, g in ipairs(NS:JournalObjectives()) do
		if g.id:find("^swarm:") then swarmGoal = g end
		if g.id:find("^week:") then weekGoal = g end
	end
	s.ok("suivi : « Pullulation : <espèce> », « ×2 », rang 6", swarmGoal and swarmGoal.label == "Pullulation : " .. swarmName
		and swarmGoal.progress == "×2" and swarmGoal.rank == 6, swarmGoal and swarmGoal.progress)
	s.ok("suivi : « Créature de la semaine », « 0/1 », rang 7", weekGoal and weekGoal.label == "Créature de la semaine"
		and weekGoal.progress == "0/1" and weekGoal.rank == 7)
	NS:DB().journalTracker = true
	local shown = NS:JournalTrackerObjectives()
	local all = NS:JournalObjectives()
	s.ok("dans la liste : la pullulation puis la créature, en dernier", #all >= 2 and all[#all - 1].id:find("^swarm:") ~= nil
		and all[#all].id:find("^week:") ~= nil, all[#all] and all[#all].id)
	s.ok("quatre lignes au plus", #shown <= 4, #shown)
	for index = 1, #all - 2 do NS:JournalDismiss(all[index].id, true) end
	shown = NS:JournalTrackerObjectives()
	s.ok("les autres masqués : les deux lignes se voient", #shown == 2 and shown[1].id:find("^swarm:") ~= nil, #shown)
	NS:DB().journalTracker = false
	Catch(NS:WorldWeekCreature(2), 1413)
	weekGoal = nil
	for _, g in ipairs(NS:JournalObjectives()) do if g.id:find("^week:") then weekGoal = g end end
	s.ok("prise faite : la ligne disparaît", weekGoal == nil)
	Mock.world.mapID = 30
	swarmGoal = nil
	for _, g in ipairs(NS:JournalObjectives()) do if g.id:find("^swarm:") then swarmGoal = g end end
	s.ok("hors zone à sceau : pas de ligne de pullulation", swarmGoal == nil)
	Mock.world.mapID = 1413
	-- infobulle
	local guid = string.format("Creature-0-4378-1-12-%d-00001A2B3C", swarm)
	local other = string.format("Creature-0-4378-1-12-%d-00001A2B3C", swarm == 5001 and 5002 or 5001)
	s.ok("infobulle : « Pullulation du jour : brillantes ×2 »", NS:WorldSwarmTooltip(guid) == "Pullulation du jour : brillantes ×2")
	s.ok("infobulle d'une autre espèce : rien", NS:WorldSwarmTooltip(other) == nil)
	-- Communauté
	NS:ToggleJournal(true)
	NS:CommunityOpen("discord")
	local week = NS.journalFrame.community.views.discord.week
	local wnpc, wname = NS:WorldWeekCreature(2)
	s.ok("Communauté : « Prise de la semaine : <espèce> »", week.title.text == "Prise de la semaine : " .. wname, week.title.text)
	s.ok("ta prise : étoiles, taille (indice)", week.mine.text:find("^ta prise : 1 étoile, ") ~= nil, week.mine.text)
	s.ok("sans ns.SouvenirShow : pas de bouton", not week.button:IsShown())
	local shownWith
	NS.SouvenirShow = function(_, subject) shownWith = subject end
	NS:CommunityWeekPaint()
	s.ok("avec ns.SouvenirShow : le bouton", week.button:IsShown())
	week.button:Click()
	s.ok("le bouton ouvre la carte de la plus belle prise", type(shownWith) == "table" and shownWith.kind == "specimen"
		and shownWith.id == NS:WorldWeekBest(wnpc).id, tostring(shownWith))
	NS.SouvenirShow = nil
	NS:WorldWeekRecord().best = {}
	NS:CommunityWeekPaint()
	s.ok("pas de prise : pas de « ta prise »", week.mine.text == "")
	NS.journalFrame:Hide()
	s.check("[WD-UI] encadré, suivi (deux lignes), infobulle, tuile « Cette semaine »")
end

-- 6. Hauts faits, chaînes, contrastes --------------------------------------------------------
do
	Say("-- le monde bouge : hauts faits, chaînes, contrastes")
	local s = Steps()
	for _, id in ipairs({ "day_week_1", "day_week_10", "day_week_52", "day_swarm_10" }) do
		local def = NS:FeatDef(id)
		s.ok(id .. " livré (plus en attente)", def and not def.pending and NS:FeatCountable(def))
	end
	local set = NS.WORLD_DAILY_STRINGS
	for key, value in pairs(set and set.fr or {}) do
		if type(set.en[key]) ~= "string" or set.en[key] == "" then s.ok("en:" .. key, false) end
		for _, glyph in ipairs({ "★", "☆", "✓", "✗" }) do
			if value:find(glyph, 1, true) or set.en[key]:find(glyph, 1, true) then s.ok("glyphe:" .. key, false) end
		end
	end
	local row, field = Theme.ROW, Theme.FIELD
	local hover = Theme.Over(field, Theme.WHITE, Theme.HOVER_ALPHA)
	local tag = Theme.Over(row, Theme.GOLD, 0.16)
	local low = 99
	for _, item in ipairs({
		{ "tuile : nom", Theme.PARCHMENT, row, 3 }, { "tuile : ligne", Theme.MUTED_LIGHT, row, 4.5 },
		{ "tuile : bas", Theme.MUTED, row, 4.5 }, { "tuile : étiquette", Theme.GOLD, tag, 4.5 },
		{ "note sous les tuiles", Theme.MUTED, Theme.SURFACE, 4.5 },
		{ "encadré : pullulation", Theme.GOLD, field, 4.5 }, { "encadré survolé : pullulation", Theme.GOLD, hover, 4.5 },
		{ "infobulle : pullulation", Theme.GOLD, Theme.SURFACE, 4.5 },
		{ "Communauté : ta prise", Theme.MUTED_LIGHT, row, 4.5 },
	}) do
		local c = Theme.Contrast(item[2], item[3])
		if c < low then low = c end
		s.ok(item[1] .. string.format(" %.2f", c), c >= item[4])
	end
	Say(string.format("   contraste le plus faible : %.2f", low))
	s.check("[WD] hauts faits livrés, chaînes FR/EN sans glyphes, contrastes mesurés (≥ 4,5 texte, ≥ 3 titres)")
end

-- remise en place
for name, value in pairs(Z.saved) do
	if name == "ZONE_CREATURES" then NS.ZONE_CREATURES = value
	elseif name == "ZONE_LEVELS" then NS.ZONE_LEVELS = value
	elseif name == "SHINY_CHANCE" then NS.SHINY_CHANCE = value
	elseif name == "dormant" then NS.worldDailyDormant = value
	elseif name == "medals" then NS.zoneMedalsDormant = value
	elseif name == "random" then math.random = value
	elseif name == "Quiet" then NS.Quiet = value
	elseif name == "SouvenirShow" then NS.SouvenirShow = value
	else _G[name] = value end
end
