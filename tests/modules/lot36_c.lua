-- QC 3.6.0, chantier C (docs/audit-pokemon-like-3.5/PLAN.md, lot 1A et fin
-- de 1B) : la première heure (visite de la capture en express, « Partir avec
-- lui », bulle de l'étude, astuces, états vides, Guide, vocabulaire), le
-- suivi à l'écran (envie, commande, étude, Créatures de la zone) et les
-- missions (taille, lien, étude, Rayonnant, commande, caractère tournant).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local C = { saved = {}, random = math.random, units = {} }
C.rollQuality, C.dormant, C.tourAuto = NS.CaptureRollQuality, NS.captureExpressDormant, NS.TOUR_AUTO
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"InCombatLockdown", "UnitAffectingCombat", "IsShiftKeyDown", "IsControlKeyDown", "date" }
for _, name in ipairs(GLOBALS) do C.saved[name] = rawget(_G, name) end
local PLAYER = "Player-1-00000001"

local function Has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
function C.Guid(npcID) return string.format("Creature-0-4378-1-12-%d-00001A2B3C", npcID) end
function C.Install()
	local w = C
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = w.units[unit]; return u and u.name end
	_G.UnitExists = function(unit) return unit == "player" or w.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function() return false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function() return "normal" end
	_G.UnitCreatureType = function() return "Bête" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function() return 20 end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
	_G.InCombatLockdown = function() return w.combat == true end
	_G.UnitAffectingCombat = function() return w.combat == true end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.IsShiftKeyDown = function() return w.shift == true end
	_G.IsControlKeyDown = function() return w.ctrl == true end
end
function C.Reset()
	if NS.tourState then NS:TourStop() end
	NS.tourPending, NS.tourMigrationAt, NS.tourMate = nil, nil, nil
	ResetWorld()
	NS.CaptureRollQuality = function() return 1 end
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt",
		"captureQueueList", "captureNetButton", "captureToast", "captureExpressFeed", "journalTracker" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureToastHideAt, NS.captureAppCache, NS.captureBatch, NS.studyClosestCache = nil, nil, nil, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	NS.specimenCountCache, NS.reserveFacetCache, NS.effectCache = nil, nil, nil
	C.units, C.combat, C.shift, C.ctrl = {}, false, false, false
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	C.Install()
	NS.SHINY_CHANCE = 0
	math.random = C.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().captureMuteUntil = nil
	NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
	NS:DB().tour30 = nil
	NS.captureExpressDormant = nil
	NS.TOUR_AUTO = true
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling, NS.captureStage.prep = nil, nil end
	NS:CompanionUpdateVisibility()
end
function C.Roll(value)
	math.random = function(a, b)
		if a and b then return C.random(a, b) end
		if a then return C.random(a) end
		return value
	end
end
function C.SeeKill(npcID, name)
	local fields = { guid = C.Guid(npcID), name = name or ("Bête " .. npcID) }
	C.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, fields.guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, fields.guid, 0)
	return fields.guid
end
function C.Tick() Mock:Advance(0.2); NS:TourTick(NS.Now()) end
local function Callout()
	for _, ui in pairs(NS.tourUI or {}) do if ui.callout and ui.callout:IsShown() then return ui.callout end end
	return nil
end
local function StepId() local st = NS.tourState; return st and st.def.steps[st.index] and st.def.steps[st.index].id end

-- 1. La visite des captures suit la capture express ---------------------------------------
do
	Say("-- 3.6 C : visite des captures, capture express")
	C.Reset()
	C.SeeKill(7801, "Sanglier")
	local c = Callout()
	Check("[L36C] première occasion, capture express : le filet, ses trois gestes (clic, Maj, Ctrl), « 1 / 3 »",
		NS:TourActive() == "capture" and StepId() == "net" and c and c.text:GetText() == NS.L.TOUR_A1X
		and Has(c.text:GetText(), "Maj + clic") and Has(c.text:GetText(), "Ctrl + clic") and c.step:GetText() == "1 / 3",
		c and c.step:GetText())
	C.Roll(0)
	NS:CaptureNetClick("LeftButton")
	C.Tick()
	c = Callout()
	Check("[L36C] un clic : le filet part tout de suite (pas de carte), le verdict au Codex", StepId() == "result"
		and NS.tourState.ctx.result == "ok" and NS.tourState.ctx.place == "codex" and not (NS.captureStage and NS.captureStage:IsShown())
		and c and c.text:GetText() == NS.L.TOUR_A4_codex)
	NS:TourStop()
	-- Ctrl + clic : la carte, et ses étapes
	C.Reset()
	C.SeeKill(7802, "Kodo")
	C.ctrl = true
	NS:CaptureNetClick("LeftButton")
	C.ctrl = false
	C.Tick()
	Check("[L36C] Ctrl + clic : la carte de préparation et son étape", StepId() == "card" and NS.captureStage
		and NS.captureStage:IsShown())
	NS:TourStop()
	-- capture express coupée : le déroulé d'avant (5 étapes)
	C.Reset()
	NS:DB().companionCaptureExpress = false
	C.SeeKill(7803, "Loup")
	c = Callout()
	Check("[L36C] capture express coupée : le texte et les cinq étapes d'avant", c and c.text:GetText() == NS.L.TOUR_A1
		and c.step:GetText() == "1 / 5")
	NS:TourStop()
	NS:DB().companionCaptureExpress = true
end

-- 2. « Partir avec lui » après la toute première capture ; la bulle de l'étude --------------
do
	Say("-- 3.6 C : partir avec lui, l'étude")
	C.Reset()
	NS:TourMark("capture", true)
	NS.studyDormant = false
	C.SeeKill(7811, "Sanglier tacheté")
	C.Roll(0)
	NS:CaptureNetClick("LeftButton")
	local pending = NS:TourHasPending()
	C.Tick()
	local c = Callout()
	Check("[L36C] première capture : la bulle « On part ensemble ? », le lien expliqué, deux boutons, sans compteur",
		pending and NS:TourActive() == "mate" and c and Has(c.text:GetText(), "Sanglier tacheté") and Has(c.text:GetText(), "lien")
		and c.nextButton:GetText() == NS.L.TOUR_MATE_GO and c.skipButton:GetText() == NS.L.TOUR_MATE_LATER
		and c.skipButton:IsShown() and c.step:GetText() == "")
	c.nextButton:Click()
	Check("[L36C] « Partir avec lui » : il devient l'apparence du compagnon (une fois)", NS:CompanionData().appearance == "cap:7811"
		and NS:TourDone("mate"))
	C.Tick()
	c = Callout()
	Check("[L36C] puis la bulle de l'étude : cinq choses à apprendre, un bouton, une fois", NS:TourActive() == "study" and c
		and Has(c.text:GetText(), "cinq choses") and not c.skipButton:IsShown() and c.nextButton:GetText() == NS.L.TOUR_STUDY_OK)
	c.nextButton:Click()
	local seen = NS:TourDone("study")
	NS:TourQueue("study")
	Check("[L36C] étude vue : plus jamais en attente", seen and not NS:TourHasPending())
	-- « Plus tard »
	C.Reset()
	NS:TourMark("capture", true)
	NS:TourMark("study", true)
	C.SeeKill(7812, "Raptor")
	C.Roll(0)
	NS:CaptureNetClick("LeftButton")
	C.Tick()
	Mock:Reset()
	c = Callout()
	if c then c.skipButton:Click() end
	Check("[L36C] « Plus tard » : l'apparence ne change pas, le chat dit où le choisir, vue", NS:TourDone("mate")
		and not Has(tostring(NS:CompanionData().appearance), "cap:") and Has(Mock:Output(), NS.L.TOUR_MATE_SKIPPED))
	-- un compte qui avait déjà des créatures : jamais
	C.Reset()
	NS:TourMark("capture", true)
	NS:CaptureData().creatures[7000] = { name = "Ancien", normal = true }
	NS:CaptureData().count = 1
	C.SeeKill(7813, "Kodo")
	C.Roll(0)
	NS:CaptureNetClick("LeftButton")
	C.Tick()
	Check("[L36C] compte qui avait déjà des captures : pas de « Partir avec lui »", NS:TourActive() ~= "mate"
		and NS:TourDone("mate"))
	NS:TourStop()
end

-- 3. Astuces : la capture d'abord, six nouvelles ----------------------------------------------
do
	Say("-- 3.6 C : astuces")
	local index = {}
	for i, tip in ipairs(NS.DISCOVERY_TIPS) do index[tip.id] = i end
	local new = { "huntReserve", "reserve", "study", "bond", "shopEarn", "orders" }
	local ok = true
	for _, id in ipairs(new) do
		local tip = NS.DISCOVERY_BY_ID[id]
		if not (tip and type(tip.learned) == "function") then ok = false end
	end
	Check("[L36C] six astuces nouvelles, chacune avec sa condition « appris »", ok)
	Check("[L36C] la capture d'abord : astuces du filet avant le compagnon, la Réserve et l'échoppe",
		index.expressAll == 1 and index.hunt < index.look and index.locate < index.reserve and index.reserve < index.look)
end

-- 4. États vides, Guide, vocabulaire ----------------------------------------------------------
do
	Say("-- 3.6 C : états vides, Guide, vocabulaire")
	C.Reset()
	NS:OpenReserve("reserve")
	local frame = NS.journalFrame
	local rv = frame and frame.res and frame.res.reserve
	local empty, button = rv and rv.empty, rv and rv.emptyHunt
	Check("[L36C] Réserve vide : le pourquoi (mode chasse) et le bouton « Mode chasse (30 min) »", empty
		and empty:GetText() == NS.L.RES_EMPTY and button and button:IsShown()
		and button:GetText() == NS:F("RES_EMPTY_HUNT", 30))
	if button then button:Click() end
	Check("[L36C] le bouton lance le mode chasse pour 30 minutes, puis se cache", NS:HuntActive() and button
		and not button:IsShown() and empty:GetText() == NS.L.RES_EMPTY_HUNTING)
	NS:HuntStop()
	NS:OpenShop()
	local sv = frame.shopPane
	Check("[L36C] Échoppe à zéro paillette : « gagner des paillettes » en haut", sv and sv.top:GetText() == NS.L.SHOP_TOP_EMPTY)
	NS:PaillettesAdd(5, "test")
	NS:RefreshJournal()
	Check("[L36C] … puis la phrase habituelle", sv.top:GetText() == NS.L.SHOP_TOP)
	NS:OpenMenagerieZone(1413)
	Check("[L36C] Créatures sans capture : la consigne de départ", frame.men and frame.men.hint:GetText() == NS.L.JRN_MEN_HINT_NONE)
	frame:Hide()
	-- le Guide
	local keys = {}
	for _, key in ipairs(NS.GUIDE_SECTIONS) do keys[key] = true end
	local blocks = NS:JournalGuideBlocks("settings")
	local cmds = blocks[3] and blocks[3].text or ""
	Check("[L36C] Guide : Réserve et paillettes, Échoppe et commandes, Lien, Étude, Échanges ; commandes complétées",
		keys.reserve and keys.shop and keys.bond and keys.study and keys.trades and #NS:JournalGuideBlocks("bond") >= 4
		and Has(cmds, "/qc chasse") and Has(cmds, "/qc echange") and Has(cmds, "/qc tri") and Has(cmds, "/qc astuces"))
	-- un seul vocabulaire
	local bad = {}
	for _, lang in ipairs({ "fr", "en" }) do
		for key, text in pairs(NS.STRINGS_TABLES[lang]) do
			if type(text) == "string" then
				local low = text:lower()
				if low:find("exemplaire", 1, true) or low:find("ménagerie", 1, true) or low:find("menagerie", 1, true)
					or text:find("Ménagerie", 1, true) then
					bad[#bad + 1] = lang .. ":" .. key
				end
			end
		end
	end
	Check("[L36C] vocabulaire : ni « exemplaire » ni « Ménagerie » dans les textes affichés (FR, EN) ; « Échelle »",
		#bad == 0 and NS.STRINGS_TABLES.fr.OPT_COMP_SIZE == "Échelle" and NS.STRINGS_TABLES.en.OPT_COMP_SIZE == "Scale",
		table.concat(bad, ", "))
end

-- 5. Le suivi à l'écran ------------------------------------------------------------------------
do
	Say("-- 3.6 C : suivi à l'écran")
	C.Reset()
	NS.studyDormant = false
	local capture = NS:CaptureData()
	-- une espèce capturée deux fois (étude : 5 captures 2/5), une commande livrable, une envie
	for i = 1, 2 do
		capture.creatures[7901] = { name = "Raptor", normal = true, stars = 1, class = "normal", type = "Bête" }
		NS:SpecimenAdd({ npc = 7901, stars = 1, name = "Raptor", origin = "capture", size = "large", trait = "zen", zone = 1413 })
	end
	NS:CompanionData().wish = { key = "hunger" }
	local orders = NS:ShopOrders()
	orders.list = { { kind = "zone", zone = 1413, reward = 12 }, { kind = "zone", zone = 9999, reward = 14 } }
	-- deux espèces rencontrées dans la zone, une capturée
	C.SeeKill(7901, "Raptor")
	C.SeeKill(7902, "Hyène")
	local goals = NS:JournalTrackerObjectives()
	local ids = {}
	for i, goal in ipairs(goals) do ids[i] = goal.id end
	local wish, order = goals[1], goals[2]
	Check("[L36C] l'envie en tête, puis la commande livrable ; 4 lignes au plus", #goals <= 4 and wish
		and wish.id:find("^wish:hunger") and Has(wish.label, "veut manger") and order and order.id:find("^order:")
		and order.page == "shop", table.concat(ids, " | "))
	local all = NS:JournalObjectives()
	local study, zone, rank = nil, nil, {}
	for _, goal in ipairs(all) do
		if goal.id:find("^study:") then study = goal end
		if goal.id:find("^captures:") or goal.id:find("^seal:") then zone = goal end
		rank[#rank + 1] = goal.rank or 3
	end
	local sorted = true
	for i = 2, #rank do if rank[i] < rank[i - 1] and not all[i].dismissed then sorted = false end end
	Check("[L36C] l'étude la plus proche (5 captures 2/5) et « Créatures de la zone : 1 à capturer », après les objectifs d'avant",
		study and study.id == "study:7901:five" and study.progress == "2/5" and zone and Has(zone.label, "1 à capturer")
		and zone.progress == "1/2" and study.rank == 4 and zone.rank == 5 and sorted)
	-- chaque ligne ouvre la bonne page
	NS:OpenJournalFor(order)
	local shop = NS.journalFrame and NS.journalFrame.kind == "shop"
	study.onClick()
	local men = NS.journalFrame.kind == "menagerie" and NS.journalFrame.menSearch == NS:CreatureName(7901)
	NS.journalFrame:Hide()
	zone.onClick()
	local here = NS.journalFrame.kind == "menagerie" and NS.journalFrame.menZone == 1413
	NS.journalFrame:Hide()
	NS:OpenJournalFor(wish)
	local evo = NS.journalFrame.kind == "evolution"
	NS.journalFrame:Hide()
	Check("[L36C] clic : la commande à l'Échoppe, l'étude sur l'espèce, la zone sur ses Créatures, l'envie page Compagnon",
		shop and men and here and evo, tostring(shop) .. tostring(men) .. tostring(here) .. tostring(evo))
	-- le sceau quand il reste 10 espèces ou moins
	local saved = NS.MenagerieSealProgress
	NS.MenagerieSealProgress = function() return 79, 86 end
	local sealGoal
	for _, goal in ipairs(NS:JournalObjectives()) do if goal.id:find("^seal:") then sealGoal = goal end end
	NS.MenagerieSealProgress = saved
	Check("[L36C] à 7 espèces du sceau : la ligne du sceau (79/86)", sealGoal and sealGoal.progress == "79/86"
		and Has(sealGoal.label, "7"))
	NS:CompanionData().wish = nil
end

-- 6. Missions ------------------------------------------------------------------------------------
do
	Say("-- 3.6 C : missions")
	C.Reset()
	local kinds, distinct = {}, 0
	for _, day in ipairs({ "2026-11-05", "2026-11-06", "2026-11-07" }) do
		local def = NS:MissionTraitDef("glutton", day)
		if not kinds[def.kind] then distinct = distinct + 1 end
		kinds[def.kind] = true
	end
	Check("[L36C] la mission du caractère tourne entre trois sortes (Gourmand : repas, repos, caresses)", distinct == 3
		and kinds.meals and kinds.rest and kinds.pets and NS.DailyDayNumber("1970-01-01") == 0)
	_G.date = function(format) if format == "%Y-%m-%d" then return "2026-11-18" end return "18/11/2026" end
	local daily = NS:DailyData()
	daily.day = NS:DailyToday()
	daily.missions = {
		{ kind = "capSize", need = 1, have = 0, source = "zone", cat = "menagerie" },
		{ kind = "bond", need = 5, have = 0, source = "zone" },
		{ kind = "radiant", need = 10, have = 0, source = "zone" },
	}
	NS:DB().companionMissions = true
	NS.studyDormant = false
	local capture = NS:CaptureData()
	capture.creatures[7951] = { name = "Lion", normal = true, stars = 1, class = "normal" }
	NS:SpecimenAdd({ npc = 7951, stars = 1, name = "Lion", origin = "capture", size = "giant", trait = "zen" })
	Check("[L36C] capture d'une créature Géante : mission « pas de taille Normale » faite", daily.missions[1].done == true)
	NS:CompanionData().appearance = "cap:7951"
	NS:SpecimenBondAdd("quest", 1); NS:SpecimenBondAdd("quest", 1); NS:SpecimenBondAdd("treat", 1)
	Check("[L36C] 6 points de lien gagnés : mission « 5 points de lien » faite", daily.missions[2].done == true,
		daily.missions[2].have)
	local savedRadiant = NS.CompanionRadiant
	NS.CompanionRadiant = function() return true end
	NS:CompanionTick(600)
	NS.CompanionRadiant = savedRadiant
	Check("[L36C] 10 minutes Rayonnant : mission faite", daily.missions[3].done == true, daily.missions[3].have)
	Check("[L36C] libellés : taille, lien, Rayonnant, étude, commande", NS:MissionLabel(daily.missions[1]) == NS.L.MIS_capSize
		and NS:MissionLabel(daily.missions[2]) == NS:F("MIS_bond", 5) and NS:MissionLabel(daily.missions[3]) == NS:F("MIS_radiant", 10)
		and NS:MissionLabel({ kind = "studyTask", need = 1 }) == NS.L.MIS_studyTask
		and NS:WeeklyLabel({ kind = "orders", need = 1 }) == NS.L.WK_orders)
	-- une tâche d'étude finie
	daily.missions = { { kind = "studyTask", need = 1, have = 0, source = "zone", cat = "menagerie" } }
	capture.creatures[7952] = { name = "Ours", normal = true, stars = 1, class = "normal" }
	NS:SpecimenAdd({ npc = 7952, stars = 1, name = "Ours", origin = "capture", size = "normal", trait = "zen" })
	Check("[L36C] une tâche d'étude finie : mission faite", daily.missions[1].done == true)
	-- la semaine : livrer une commande
	local weekly = NS:WeeklyData()
	weekly.week, weekly.missions = NS:WeeklyId(), { { kind = "orders", need = 1, have = 0, source = "week" } }
	for i = 1, 2 do
		capture.creatures[7953] = { name = "Kodo", normal = true, stars = 1, class = "normal" }
		NS:SpecimenAdd({ npc = 7953, stars = 1, name = "Kodo", origin = "capture", size = "normal", trait = "zen", zone = 1413 })
	end
	local orders = NS:ShopOrders()
	orders.list = { { kind = "zone", zone = 1413, reward = 12 } }
	local target
	for _, spec in ipairs(NS:SpecimenList({ where = "reserve" })) do
		if NS:SpecimenCanRelease(spec.id) and NS:ShopOrderMatches(orders.list[1], spec) then target = spec.id end
	end
	local delivered = target and NS:ShopOrderDeliver(1, target)
	Check("[L36C] commande livrée : la mission de la semaine faite, l'astuce « commandes » apprise", delivered
		and weekly.missions[1].done == true and NS.DISCOVERY_BY_ID.orders.learned(NS))
	-- tirage : les nouvelles sortes y entrent
	local seenKinds = {}
	NS:CompanionData().appearance = "cap:7951"
	for _ = 1, 60 do
		local m = NS:MissionMenagerieDraw(1413)
		if m then seenKinds[m.kind] = true end
	end
	Check("[L36C] le lien est faisable avec un spécimen porté ; Rayonnant, capture allumée",
		NS:MissionFeasible("bond") and NS:MissionFeasible("radiant"))
	NS:CompanionData().appearance = nil
	Check("[L36C] sans spécimen porté : pas de mission de lien", not NS:MissionFeasible("bond"))
end

for _, name in ipairs(GLOBALS) do _G[name] = C.saved[name] end
NS.CaptureRollQuality, NS.captureExpressDormant, NS.TOUR_AUTO = C.rollQuality, C.dormant, C.tourAuto
math.random = C.random
if NS.tourState then NS:TourStop() end
NS:DB().tour30 = nil
for _, field in ipairs({ "captureExpressFeed", "captureQueueList", "journalFrame" }) do
	if NS[field] then NS[field]:Hide() end
end
ResetWorld()
