-- QuestCompanion 3.7.0, étape 4, chantier E1 : médailles de zone (ZoneMedals.lua),
-- série de chasse visible (Tooltips.lua), suspense de la capture express
-- (CaptureExpress.lua), bien reposé (CompanionRested.lua).
--   1. Médailles : seuils aux bornes, zone vide, zone scellée, cache, paillettes
--      une seule fois, rattrapage en une ligne, franchissement en direct,
--      ZoneMedalCounts, mode discret.
--   2. Encadré de la page Créatures (0, 1, 3 médailles) et ligne du suivi.
--   3. Infobulle : 9 et 10 abattus, plafond, espèce qui ne peut pas briller.
--   4. Suspense : qui tremble, combien, verdict déjà inscrit, réglage
--      d'animation, prises ordinaires instantanées, file de prises.
--   5. Bien reposé : 7 h 59, 8 h, 3 jours, état déjà plus long, première connexion.
--   6. Contrastes des textes nouveaux.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local Z = { saved = {} }
local GLOBALS = { "UnitFactionGroup", "IsInInstance", "GetRealZoneText", "time", "UnitGUID", "UnitName", "UnitExists",
	"UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled", "UnitReaction", "UnitCanAttack", "UnitClassification",
	"UnitCreatureType", "UnitCreatureFamily", "UnitLevel", "GetRaidTargetIndex", "SetRaidTarget", "IsInGroup",
	"UnitIsGroupLeader", "Screenshot", "C_Timer", "InCombatLockdown", "UnitAffectingCombat", "PlaySound",
	"IsShiftKeyDown", "IsControlKeyDown" }
for _, name in ipairs(GLOBALS) do Z.saved[name] = rawget(_G, name) end
Z.saved.ZONE_CREATURES = rawget(NS, "ZONE_CREATURES")
Z.saved.SHINY_CHANCE = NS.SHINY_CHANCE
Z.saved.medalsDormant, Z.saved.restedDormant = NS.zoneMedalsDormant, NS.companionRestedDormant
Z.saved.expressDormant, Z.saved.rollQuality = NS.captureExpressDormant, NS.CaptureRollQuality
Z.saved.random, Z.saved.Quiet = math.random, rawget(NS, "Quiet")
local NOW = 1800000000
local PLAYER = "Player-1-00000001"

-- Les Tarides : 179 espèces (plus un boss du monde, hors compte) ; Mulgore : 4
local ZONES = { [1413] = {}, [1412] = {} }
for index = 1, 179 do ZONES[1413][5000 + index] = { lvl = { 10, 12 }, rank = 0, fr = "Bête " .. index, en = "Beast " .. index } end
ZONES[1413][5999] = { lvl = { 63, 63 }, rank = 3, fr = "Boss", en = "Boss" }
for index = 1, 4 do ZONES[1412][6000 + index] = { lvl = { 5, 6 }, rank = 0, fr = "Kodo " .. index, en = "Kodo " .. index } end

function Z.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "journalTracker",
		"captureNetButton", "captureToast", "captureExpressFeed", "captureQueueList" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.menagerieStatic, NS.captureAppCache = nil, nil, nil, nil
	NS.shinyState, NS.captureState, NS.captureBatch, NS.captureResultPending = nil, nil, nil, nil
	NS.bestiaryUnits, NS.bestiaryKilled = {}, {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1412] = { mapID = 1412, name = "Mulgore", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	_G.UnitFactionGroup = function() return "Horde" end
	_G.IsInInstance = function() return false, "none" end
	_G.GetRealZoneText = function() return "" end
	_G.time = function() return NOW end
	NS.ZONE_CREATURES = ZONES
	local data = NS:CompanionData()
	data.tutoDone, data.collection = true, nil
	NS:JournalData().bestiary = {}
	NS:TreatData().treatsInit = true
	NS:DB().journalTracker = false
	NS.SHINY_CHANCE = 1 / 150
	NS.zoneMedalsDormant, NS.zoneMedalCaughtUp = nil, nil
	NS.Quiet = Z.saved.Quiet
	NS.ZoneMedalReset()
	NS:MenagerieCollectionData().init = true
	NS:CaptureData().zoneMedalsInit = true
end

-- n espèces des Tarides capturées (à partir de la première)
function Z.Caught(count, zoneID, base)
	local capture = NS:CaptureData()
	for index = 1, count do
		local npc = (base or 5000) + index
		if capture.creatures[npc] == nil then capture.count = capture.count + 1 end
		capture.creatures[npc] = { name = "Bête " .. index, class = "normal", zoneID = zoneID or 1413, normal = true, at = 1 }
	end
	capture.serial = (tonumber(capture.serial) or 0) + 1
end

function Z.Collect()
	local printed, said = {}, {}
	local oldPrint, oldSay = NS.Print, NS.CompanionSay
	NS.Print = function(_, msg) printed[#printed + 1] = tostring(msg) end
	NS.CompanionSay = function(_, pool, opts) said[#said + 1] = { pool = pool, opts = opts or {} }; return true end
	return printed, said, function() NS.Print, NS.CompanionSay = oldPrint, oldSay end
end

local function Glitter() return NS:Paillettes() end

-- 1. Médailles ------------------------------------------------------------------------------
do
	Say("-- médailles de zone : seuils, zone vide, scellée")
	Z.Reset()
	local s = Steps()
	local b, a, o = NS:ZoneMedalThresholds(179)
	s.ok("179 espèces : 45, 90, 135", b == 45 and a == 90 and o == 135, b .. "/" .. a .. "/" .. o)
	local b2, a2, o2 = NS:ZoneMedalThresholds(100)
	s.ok("100 espèces : 25, 50, 75 (arrondi juste)", b2 == 25 and a2 == 50 and o2 == 75)
	local level, have, need, nextNeed = NS:ZoneMedal(1413)
	s.ok("aucune capture : 0, 0/179, prochain 45", level == 0 and have == 0 and need == 179 and nextNeed == 45)
	for _, case in ipairs({ { 44, 0, 45 }, { 45, 1, 90 }, { 89, 1, 90 }, { 90, 2, 135 }, { 134, 2, 135 }, { 135, 3, 179 }, { 178, 3, 179 } }) do
		Z.Caught(case[1])
		local l, h, _, n = NS:ZoneMedal(1413)
		s.ok(case[1] .. " espèces : médaille " .. case[2] .. ", prochain " .. case[3], l == case[2] and h == case[1] and n == case[3],
			l .. "/" .. tostring(n))
	end
	local l0, h0, n0, x0 = NS:ZoneMedal(9999)
	s.ok("zone sans liste : 0, 0, 0, rien", l0 == 0 and h0 == 0 and n0 == 0 and x0 == nil)
	s.ok("zone absente : 0", NS:ZoneMedal(nil) == 0)
	Z.Caught(179)
	NS:MenagerieSealCheck(1413, { quiet = true })
	local ls, hs, ns_, xs = NS:ZoneMedal(1413)
	s.ok("zone scellée : les trois, plus de seuil", NS:MenagerieSealed(1413) and ls == 3 and hs == 179 and ns_ == 179 and xs == nil)
	s.check("[ZM] seuils aux bornes, zone vide, zone scellée")
end

do
	Say("-- médailles de zone : cache, paillettes une fois, en direct")
	Z.Reset()
	local s = Steps()
	local calls, progress = 0, NS.MenagerieSealProgress
	NS.MenagerieSealProgress = function(self, ...) calls = calls + 1; return progress(self, ...) end
	NS:ZoneMedal(1413); NS:ZoneMedal(1413); NS:ZoneMedal(1413)
	s.ok("calcul à la demande, gardé", calls == 1, calls)
	Z.Caught(10)
	NS:ZoneMedal(1413)
	s.ok("une capture remet le cache à zéro", calls == 2, calls)
	NS.ZoneMedalReset()
	NS:ZoneMedal(1413)
	s.ok("remise à zéro explicite", calls == 3, calls)
	NS.MenagerieSealProgress = progress
	-- franchissement en direct (une vraie capture : ns:CaptureResolve)
	Z.Caught(44)
	local before = Glitter()
	local printed, said, restore = Z.Collect()
	NS:CaptureResolve({ success = true, stars = 1, target = { npcID = 5045, zoneID = 1413, name = "Bête 45", class = "normal", level = 10, stars = 1 } })
	restore()
	local medalLine
	for _, line in ipairs(printed) do if line:find("Médaille de bronze", 1, true) then medalLine = line end end
	local bubble
	for _, call in ipairs(said) do if call.opts.line == "ZONE_MEDAL_SAY" then bubble = call end end
	s.ok("45e espèce : +3 paillettes", Glitter() - before == 3, Glitter() - before)
	s.ok("une ligne de chat avec les paillettes", medalLine ~= nil and medalLine:find("+3 paillettes", 1, true) ~= nil, medalLine)
	s.ok("une bulle d'événement, pas une astuce", bubble ~= nil and bubble.opts.category == "event" and bubble.opts.force == true)
	s.ok("médaille notée au compte", NS:ZoneMedalRecord()[1413] == 1)
	before = Glitter()
	printed, said, restore = Z.Collect()
	NS:ZoneMedalCheck(1413)
	NS:CaptureResolve({ success = true, stars = 1, target = { npcID = 5046, zoneID = 1413, name = "Bête 46", class = "normal", level = 10, stars = 1 } })
	restore()
	s.ok("déjà payée : ni paillettes ni ligne", Glitter() == before and #printed <= 1, #printed)
	-- argent puis or d'un coup : la somme, une fois
	Z.Caught(135)
	before = Glitter()
	NS:ZoneMedalCheck(1413, { quiet = true })
	s.ok("argent et or ensemble : 5 + 10", Glitter() - before == 15, Glitter() - before)
	s.ok("plus rien à payer après l'or", NS:ZoneMedalCheck(1413) == nil and NS:ZoneMedalRecord()[1413] == 3)
	-- une capture qui scelle : la bulle reste au sceau
	Z.Caught(178)
	printed, said, restore = Z.Collect()
	NS:CaptureResolve({ success = true, stars = 1, target = { npcID = 5179, zoneID = 1413, name = "Bête 179", class = "normal", level = 10, stars = 1 } })
	restore()
	s.ok("le sceau garde ce qu'il donne", NS:MenagerieSealed(1413))
	s.check("[ZM] cache remis à zéro par une capture, paillettes une seule fois, franchissement en direct")
end

do
	Say("-- médailles de zone : rattrapage, compte, mode discret")
	Z.Reset()
	local s = Steps()
	NS:CaptureData().zoneMedalsInit = nil
	Z.Caught(90)                          -- Tarides : argent
	Z.Caught(4, 1412, 6000)               -- Mulgore : les 4 (or, puis scellée)
	NS:MenagerieCollectionData().seals[1412] = 1
	local before = Glitter()
	local printed, said, restore = Z.Collect()
	NS:RefreshJournalTracker()
	NS:RefreshJournalTracker()
	restore()
	s.ok("une seule ligne de chat", #printed == 1, #printed)
	s.ok("la ligne dit chaque métal et les paillettes", printed[1] and printed[1] == "Médailles de zone : 2 de bronze, 2 d'argent, 1 d'or. +26 paillettes.", printed[1])
	s.ok("payé d'un coup, en silence (aucune bulle)", Glitter() - before == 26 and #said == 0, Glitter() - before)
	local counts = NS:ZoneMedalCounts()
	s.ok("ZoneMedalCounts : { bronze ou mieux, argent ou mieux, or ou mieux }", counts[1] == 2 and counts[2] == 2 and counts[3] == 1
		and #counts == 3, table.concat(counts, ","))
	NS.zoneMedalCaughtUp = nil
	before = Glitter()
	NS:ZoneMedalCatchUp()
	s.ok("rattrapage une fois par compte", Glitter() == before)
	-- mode discret : rien ne parle, la médaille se paie
	NS.Quiet = function() return true end
	Z.Caught(135)
	printed, said, restore = Z.Collect()
	before = Glitter()
	NS:ZoneMedalCheck(1413)
	restore()
	s.ok("mode discret : ni ligne ni bulle, paillettes payées", #printed == 0 and #said == 0 and Glitter() - before == 10)
	NS.Quiet = Z.saved.Quiet
	-- endormi (harnais) : rien
	NS.zoneMedalsDormant = true
	Z.Caught(179)
	s.ok("endormi : aucune paie", NS:ZoneMedalCheck(1413) == nil)
	NS.zoneMedalsDormant = nil
	s.check("[ZM] rattrapage silencieux en une ligne, compte des médailles, mode discret")
end

-- 2. Encadré et suivi ----------------------------------------------------------------------
local function Strip(count)
	Z.Reset()
	Z.Caught(count)
	NS:ToggleJournal(true)
	NS:OpenMenagerieZone(1413)
	return NS.journalFrame.men.collection
end
do
	Say("-- médailles de zone : encadré de la page Créatures")
	local s = Steps()
	local strip = Strip(5)
	local lit = 0
	for _, dia in ipairs(strip.medals) do if dia.lit then lit = lit + 1 end end
	s.ok("0 médaille : quatre losanges éteints", #strip.medals == 4 and lit == 0)
	s.ok("titre « Les Tarides : 5 sur 179 espèces »", strip.title.text == "Les Tarides : 5 sur 179 espèces", strip.title.text)
	s.ok("à droite « encore 40 pour le bronze »", strip.next.text == "encore 40 pour le bronze", strip.next.text)
	s.ok("seuils sous la barre", strip.marks[1].text == "bronze 45" and strip.marks[2].text == "argent 90"
		and strip.marks[3].text == "or 135 · sceau 179" and strip.bar:IsShown(), strip.marks[3].text)
	s.ok("trois repères à 25, 50, 75 %", #strip.ticks == 3 and strip.ticks[2]:IsShown())
	s.ok("en bas à droite, le titre à viser", strip.trainer.text == "5/10 pour « Apprenti dresseur »", strip.trainer.text)
	s.ok("le titre s'arrête avant le texte de droite", strip.title:GetWidth() + NS.MENAGERIE_STRIP.titleX + strip.next:GetStringWidth()
		<= strip:GetWidth() - NS.MENAGERIE_STRIP.pad)
	local off = Theme[NS.ZONE_MEDAL_TINTS.off]
	s.ok("éteint : la teinte du jeton « éteint »", strip.medals[1].vertexColor == nil or strip.medals[1].vertexColor[1] == off[1])
	NS.journalFrame:Hide()
	strip = Strip(50)
	s.ok("1 médaille : bronze allumé, au jeton bronze", strip.medals[1].lit and not strip.medals[2].lit
		and strip.next.text == "encore 40 pour l'argent", strip.next.text)
	NS.journalFrame:Hide()
	strip = Strip(140)
	s.ok("3 médailles : vers le sceau", strip.medals[3].lit and not strip.medals[4].lit and strip.next.text == "encore 39 pour le sceau",
		strip.next.text)
	NS.journalFrame:Hide()
	strip = Strip(179)
	s.ok("scellée : quatre allumés, ce que l'encadré dit déjà", strip.medals[4].lit and strip.title.text == "Les Tarides scellée"
		and strip.next.text:find("×1,5", 1, true) ~= nil)
	NS.journalFrame.menZone = "all"
	NS:RefreshJournal()
	s.ok("toutes zones : sceaux et médailles comptés", strip.title.text == "Sceaux : 1 zones scellées"
		and strip.note.text == "Médailles de zone : 1 bronze · 1 argent · 1 or" and not strip.bar:IsShown(), strip.note.text)
	NS.journalFrame:Hide()
	s.check("[ZM-UI] encadré : losanges, compte, seuil suivant, barre et repères, titre à viser")
end

do
	Say("-- médailles de zone : ligne du suivi")
	Z.Reset()
	local s = Steps()
	Z.Caught(5)
	local goal
	for _, g in ipairs(NS:JournalObjectives()) do if g.id:find("^medal:1413") then goal = g end end
	s.ok("« Les Tarides : médaille de bronze », 5/45", goal and goal.label == "Les Tarides : médaille de bronze"
		and goal.progress == "5/45" and goal.rank == NS.TRACKER_GOAL_RANKS.zone, goal and goal.progress)
	Z.Caught(140)
	goal = nil
	for _, g in ipairs(NS:JournalObjectives()) do if g.id:find("^medal:1413") then goal = g end end
	s.ok("après l'or : le sceau, 140/179", goal and goal.label == "Les Tarides : sceau" and goal.progress == "140/179",
		goal and goal.label)
	Z.Reset()
	local none = true
	for _, g in ipairs(NS:JournalObjectives()) do if g.id:find("^medal:") then none = false end end
	s.ok("aucune capture dans la zone : pas de ligne de médaille", none)
	NS:DB().journalTracker = true
	Z.Caught(5)
	local shown = NS:JournalTrackerObjectives()
	s.ok("quatre lignes au plus", #shown <= 4)
	NS:DB().journalTracker = false
	s.check("[ZM-TRK] suivi : prochaine médaille puis sceau, rang inchangé")
end

-- 3. Infobulle : la série de chasse ---------------------------------------------------------
do
	Say("-- série de chasse dans l'infobulle")
	Z.Reset()
	local s = Steps()
	local guid = "Creature-0-4378-1-12-5001-00001A2B3C"
	NS:JournalData().bestiary = { [1413] = { [5001] = { name = "Bête 1", seen = true, killed = 9 } } }
	s.ok("9 abattus : pas de ligne", NS:BestiaryTooltipChain(guid) == nil)
	NS:JournalData().bestiary[1413][5001].killed = 10
	s.ok("10 abattus : « 10 sur 50 · brillantes ×1,6 »", NS:BestiaryTooltipChain(guid) == "Série de chasse : 10 sur 50 · brillantes ×1,6",
		NS:BestiaryTooltipChain(guid))
	NS:JournalData().bestiary[1413][5001].killed = 23
	s.ok("23 abattus : ×2,3 (maquette)", NS:BestiaryTooltipChain(guid) == "Série de chasse : 23 sur 50 · brillantes ×2,3",
		NS:BestiaryTooltipChain(guid))
	NS:JournalData().bestiary[1413][5001].killed = 80
	s.ok("plafond : 50 sur 50, ×3,8", NS:BestiaryTooltipChain(guid) == "Série de chasse : 50 sur 50 · brillantes ×3,8",
		NS:BestiaryTooltipChain(guid))
	local chance = NS.SHINY_CHANCE
	NS.SHINY_CHANCE = 0
	s.ok("espèce qui ne peut pas briller : pas de ligne", NS:BestiaryTooltipChain(guid) == nil)
	NS.SHINY_CHANCE = chance
	local mult = NS.SHINY_CHAIN_MAX
	s.ok("aucun taux changé", NS.SHINY_CHAIN_KILLS == 50 and mult == 3.75)
	s.check("[ZM-TIP] série de chasse : seuil de 10 abattus, plafond, multiplicateur réel")
end

-- 4. Suspense de la capture express ---------------------------------------------------------
local X = { units = {}, combat = false }
local function Install()
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = X.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = X.units[unit]; return u and u.name end
	_G.UnitExists = function(unit) return unit == "player" or X.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function() return false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function(unit) local u = X.units[unit]; return u and u.class or "normal" end
	_G.UnitCreatureType = function() return "Bête" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function() return 20 end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.Screenshot = function() end
	_G.InCombatLockdown = function() return X.combat == true end
	_G.UnitAffectingCombat = function() return X.combat == true end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.PlaySound = function() return true end
	_G.IsShiftKeyDown = function() return false end
	_G.IsControlKeyDown = function() return false end
end
local function XReset()
	Z.Reset()
	Install()
	X.units, X.combat = {}, false
	NS.SHINY_CHANCE = 0
	NS.CaptureRollQuality = function() return 1 end
	math.random = function(a, b) if a and b then return Z.saved.random(a, b) end if a then return Z.saved.random(a) end return 0 end
	NS.captureExpressDormant = nil
	NS:DB().captureMuteUntil = nil
	NS:DB().companionCaptureAnim = true
	NS:CompanionUpdateVisibility()
end
local function SeeKill(npcID, class)
	local guid = string.format("Creature-0-4378-1-12-%d-%s", npcID, "00001A2B3C")
	X.units.target = { guid = guid, name = "Bête " .. npcID, class = class }
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
	return guid
end
local function Item(index) local feed = NS.captureExpressFeed; return feed and feed.items[index] end

do
	Say("-- capture express : le suspense d'une prise notable")
	XReset()
	local s = Steps()
	s.ok("espèce nouvelle : 1 secousse", NS:CaptureExpressShakes({ class = "normal", npcID = 1 }, nil) == 1)
	s.ok("élite : 2", NS:CaptureExpressShakes({ class = "elite", npcID = 1 }, 2) == 2)
	s.ok("rare : 3", NS:CaptureExpressShakes({ class = "rare", npcID = 1 }, 2) == 3)
	s.ok("brillante : 3 (le plus fort l'emporte sur « nouvelle »)", NS:CaptureExpressShakes({ class = "normal", shiny = true, npcID = 1 }, nil) == 3)
	s.ok("prise ordinaire : aucune", NS:CaptureExpressShakes({ class = "normal", npcID = 1 }, 2) == 0)
	local pinned = NS.HuntPinned
	NS.HuntPinned = function(_, npc) return npc == 7 end
	s.ok("épinglée : 1", NS:CaptureExpressShakes({ class = "normal", npcID = 7 }, 2) == 1)
	NS.HuntPinned = pinned
	s.ok("une seconde au plus", 3 * NS.CAPTURE_EXPRESS.shake <= 1.05)
	-- un lancer sur une élite nouvelle : le verdict inscrit tout de suite, la pastille tremble
	SeeKill(5003, "elite")
	local printed, said, restore = Z.Collect()
	local rolling = NS:CaptureExpressThrow()
	restore()
	local item = Item(1)
	s.ok("verdict tiré et inscrit tout de suite", type(rolling) == "table" and rolling.success and NS:CaptureIsCaptured(5003))
	s.ok("pastille « le filet tremble… », deux secousses", item and item.kind == "suspense" and item.right == "le filet tremble…"
		and item.shakes == 2, item and item.kind)
	s.ok("chat et bulle attendent le verdict", #printed == 0 and #said == 0, #printed)
	local born = item.born
	NS:CaptureExpressUpdate(born + 0.1)
	local row = NS.captureExpressFeed.rows[1]
	local _, _, _, dx = row:GetPoint()
	s.ok("la pastille tremble (décalage)", dx ~= nil and dx ~= 0, dx)
	-- une prise ordinaire pendant le suspense : instantanée, pas retardée
	NS:CaptureData().creatures[5004] = { name = "Bête 4", normal = true, zoneID = 1413, stars = 1 }
	NS:CaptureData().count = NS:CaptureData().count + 1
	NS:CaptureStars(5004, false)
	NS.CaptureRollQuality = function() return 2 end   -- un meilleur spécimen d'une espèce connue : pas de suspense
	SeeKill(5004, "normal")
	NS:CaptureExpressThrow()
	NS.CaptureRollQuality = function() return 1 end
	local ordinary = Item(1)
	s.ok("prise ordinaire suivante : sa pastille tout de suite", ordinary and ordinary.kind ~= "suspense" and ordinary.verdict == nil,
		ordinary and ordinary.kind)
	local still = false
	for index = 2, NS.CAPTURE_EXPRESS.rows do if Item(index) == item then still = true end end
	s.ok("la pastille en suspens reste en file, toujours en suspens", still and item.verdict ~= nil)
	local printed2, said2, restore2 = Z.Collect()
	NS:CaptureExpressUpdate(born + 2 * NS.CAPTURE_EXPRESS.shake + 0.01)
	restore2()
	s.ok("après les secousses : le verdict « nouvelle »", item.kind == "notable" and item.right:find("nouvelle", 1, true) ~= nil, item.kind)
	s.ok("ce qui attendait part au verdict (chat, bulle)", #printed2 >= 1 and #said2 >= 1, #printed2 .. "/" .. #said2)
	s.check("[ZM-SUS] suspense : qui tremble, combien, verdict déjà inscrit, prises ordinaires instantanées")
end

do
	Say("-- capture express : suspense coupé, échec, file")
	XReset()
	local s = Steps()
	NS:DB().companionCaptureAnim = false
	SeeKill(5010, "rare")
	NS:CaptureExpressThrow()
	s.ok("réglage « Capture animée » coupé : verdict tout de suite", Item(1).kind ~= "suspense" and Item(1).verdict == nil, Item(1).kind)
	NS:DB().companionCaptureAnim = true
	SeeKill(5011, "rare")
	math.random = function(a, b) if a and b then return Z.saved.random(a, b) end if a then return Z.saved.random(a) end return 0.999 end
	NS:CaptureExpressThrow()
	local item = Item(1)
	s.ok("un échec a le même suspense (trois secousses)", item.kind == "suspense" and item.shakes == 3 and item.verdict[1] == "fail"
		and not NS:CaptureIsCaptured(5011))
	-- quatre prises de plus : la pastille en suspens est reprise, rien ne se perd
	local printed, said, restore = Z.Collect()
	for index = 1, 4 do
		NS:CaptureExpressPush("ok", "x" .. index, "")
	end
	restore()
	s.ok("pastille reprise avant son verdict : ce qu'elle retenait part", item.verdict == nil and #printed >= 1, #printed)
	s.check("[ZM-SUS] réglage d'animation, échec, file de prises")
end

-- 5. Bien reposé ------------------------------------------------------------------------------
do
	Say("-- bien reposé")
	Z.Reset()
	local s = Steps()
	NS.companionRestedDormant = nil
	local data = NS:CompanionData()
	local S = NS.COMPANION_STATE
	local function Login(away, needs)
		for _, key in ipairs(NS.COMPANION_NEED_KEYS) do data.needs[key] = (needs and needs[key]) or S.on end
		data.sleepy, data.sleepyLeft = nil, nil
		NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubbleLine = nil, nil, nil
		if NS.companionRT then NS.companionRT.cool, NS.companionRT.seq = {}, nil end
		data.lastSeen = NOW - away
		NS:CompanionLogin()
		return data.needs
	end
	data.restedV = nil
	local needs = Login(9 * 3600)
	s.ok("première connexion avec cette version : rien", needs.energy == S.on and data.restedV == 1)
	needs = Login(8 * 3600 - 60)
	s.ok("7 h 59 : rien", needs.energy == S.on)
	needs = Login(8 * 3600)
	s.ok("8 h : Reposé, 45 minutes", needs.energy == S.full and needs.hunger == S.on and NS:CompanionStateMinutes("energy") >= 44.9,
		needs.energy)
	s.ok("la bulle de bonjour le dit", NS.companionBubbleLine == "COMP_SAY_RESTED" and NS.companionBubbleKey == "MISSED",
		NS.companionBubbleLine)
	needs = Login(3 * 86400)
	local twenty = S.on + 20 * S.rate
	s.ok("3 jours : les trois états, Rayonnant", math.abs(needs.hunger - twenty) < 1e-6 and math.abs(needs.curiosity - twenty) < 1e-6
		and needs.energy == S.full and NS:CompanionRadiant(), needs.hunger)
	s.ok("« Content de te revoir ! »", NS.companionBubbleLine == "COMP_SAY_RESTED_LONG", NS.companionBubbleLine)
	s.ok("somnolent, et le bonus des états reste", data.sleepy == true and NS:CompanionRadiant())
	needs = Login(3 * 86400, { hunger = S.max, energy = S.max, curiosity = S.on })
	s.ok("état déjà plus long : jamais raccourci", needs.hunger == S.max and needs.energy == S.max)
	needs = Login(30 * 86400)
	s.ok("rien ne s'accumule au-delà", needs.energy == S.full and math.abs(needs.hunger - twenty) < 1e-6)
	NS.companionRestedDormant = Z.saved.restedDormant
	s.check("[ZM-REST] bien reposé : 7 h 59, 8 h, 3 jours, état plus long, première connexion")
end

-- 6. Chaînes et contrastes ------------------------------------------------------------------
do
	Say("-- chaînes et contrastes des textes nouveaux")
	local s = Steps()
	for _, set in ipairs({ NS.ZONE_MEDAL_STRINGS, NS.COMPANION_RESTED_STRINGS }) do
		for key, value in pairs(set and set.fr or {}) do
			if type(set.en[key]) ~= "string" or set.en[key] == "" then s.ok("en:" .. key, false) end
			for _, glyph in ipairs({ "★", "☆", "✓", "✗" }) do
				if value:find(glyph, 1, true) or set.en[key]:find(glyph, 1, true) then s.ok("glyphe:" .. key, false) end
			end
		end
	end
	s.ok("chaînes de l'infobulle et du filet", NS.L.MEN_TIP_CHAIN ~= nil and NS.L.CAPTURE_X_SHAKE ~= nil)
	local card = NS.QC_FORGE.card
	local top = NS.QC_FORGE.plateTop
	local plate = { card[1] * top, card[2] * top, card[3] * top }
	local field = Theme.FIELD
	local hover = Theme.Over(field, Theme.WHITE, Theme.HOVER_ALPHA)
	for _, item in ipairs({
		{ "encadré : titre", Theme.LABEL, field, 3 }, { "encadré : seuil suivant", Theme.MUTED_LIGHT, hover, 4.5 },
		{ "encadré : seuils sous la barre", Theme.MUTED, hover, 4.5 }, { "encadré : titre à viser", Theme.GOLD, hover, 4.5 },
		{ "infobulle : série de chasse", Theme.GOLD, Theme.SURFACE, 4.5 },
		{ "pastille : « le filet tremble… »", NS.CAPTURE_EXPRESS_FORGE.right, plate, 4.5 },
		{ "pastille : nom", Theme.PARCHMENT, plate, 4.5 },
	}) do
		local c = Theme.Contrast(item[2], item[3])
		s.ok(item[1] .. string.format(" %.2f", c), c >= item[4])
	end
	s.check("[ZM] chaînes FR/EN sans glyphes, contrastes mesurés (≥ 4,5 texte, ≥ 3 titres)")
end

-- remise en place
for name, value in pairs(Z.saved) do
	if name == "ZONE_CREATURES" then NS.ZONE_CREATURES = value
	elseif name == "SHINY_CHANCE" then NS.SHINY_CHANCE = value
	elseif name == "medalsDormant" then NS.zoneMedalsDormant = value
	elseif name == "restedDormant" then NS.companionRestedDormant = value
	elseif name == "expressDormant" then NS.captureExpressDormant = value
	elseif name == "rollQuality" then NS.CaptureRollQuality = value
	elseif name == "random" then math.random = value
	elseif name == "Quiet" then NS.Quiet = value
	else _G[name] = value end
end
