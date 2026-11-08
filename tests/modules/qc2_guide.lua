-- QuestCompanion 2.3.0 : le tutoriel de la ménagerie (Companion.lua,
-- CompanionLines.lua, accroché par CaptureQueue.lua) et la page Guide du
-- carnet (JournalGuide.lua) ; Échap et le « × » ferment la scène de capture
-- et la liste du filet (CaptureStage.lua, CaptureQueue.lua).
--   * le tutoriel commence à la première occasion de capture, hors combat
--     (en combat : à la fin du combat), jamais à la connexion à vide ;
--   * sa première bulle attend le lancer du filet (pas le temps, pas
--     « Suivant »), le filet bat ; la scène se joue en silence ; la suite
--     reprend après sa fermeture (réussi / échappé), au rythme du tutoriel ;
--   * candidat parti avant le clic : « Trop tard », reprise à l'occasion
--     suivante ; une fois par personnage ; jamais si la capture est coupée ;
--   * /qc compagnon tuto menagerie et le bouton de la page Guide rejouent au
--     temps ; les chiffres des bulles viennent des constantes ; parité FR/EN ;
--   * la page Guide : sommaire, sections, table des types avec les vraies
--     valeurs, pagination, bouton « Revoir », aucun chevauchement (FR et EN).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()

local G = { saved = {}, random = math.random, units = {}, sounds = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"UnitAffectingCombat", "InCombatLockdown", "PlaySound" }
for _, name in ipairs(GLOBALS) do G.saved[name] = rawget(_G, name) end
G.savedShiny, G.savedAuto = NS.SHINY_CHANCE, NS.TUTO_MENAGERIE_AUTO
local PLAYER = "Player-1-00000001"
local POOLS = NS.COMPANION_POOLS
local RULES = NS.COMPANION_RULES

function G.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function G.Install()
	local w = G
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = w.units[unit]; return u and u.name end
	_G.UnitExists = function(unit) return unit == "player" or w.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function() return false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function(unit) local u = w.units[unit]; return u and u.class or "normal" end
	_G.UnitCreatureType = function() return "Bête" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function(unit)
		if unit == "player" or unit == nil then return 20 end
		local u = w.units[unit]; return u and u.level or 20
	end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.InCombatLockdown = function() return w.combat == true end
	_G.UnitAffectingCombat = function() return w.combat == true end
	_G.PlaySound = function(id) w.sounds[#w.sounds + 1] = id; return true end
end
-- Monde neuf : compagnon connu (tutoriel de base vu), capture allumée, scène
-- animée coupée (la petite fenêtre suffit), tutoriel automatique allumé
function G.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt",
		"captureQueueList", "captureNetButton", "captureToast" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.captureAppCache = nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	G.units, G.combat, G.sounds = {}, false, {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	G.Install()
	NS.SHINY_CHANCE = 1 / 150
	G.Roll(0.99)                      -- jamais de brillante au hasard
	NS.TUTO_MENAGERIE_AUTO = true
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = false
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	NS:CompanionUpdateVisibility()
end
function G.Roll(value)
	math.random = function(a, b)
		if a and b then return G.random(a, b) end
		if a then return G.random(a) end
		return value
	end
end
function G.SeeKill(npcID, fields)
	fields = fields or {}
	local guid = G.Guid(npcID, fields.spawn)
	fields.guid = guid
	fields.name = fields.name or ("Bête " .. npcID)
	G.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
	return guid
end
-- La bulle affichée : son réservoir (nil si rien n'est affiché)
function G.Key()
	local bubble = NS.companionBubble
	if not (bubble and bubble:IsShown()) then return nil end
	return NS.companionBubbleKey
end
function G.Text() return NS.companionBubbleText or "" end
function G.Login()
	NS.companionSession = nil
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
end
-- Joue la capture lancée jusqu'au verdict, puis jusqu'à la fermeture
function G.PlayCapture()
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Mock:Advance(NS.CAPTURE_STAGE_HOLD + 0.5); NS:CaptureTick(NS.Now())
end
function G.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = G.saved[name] end
	math.random = G.random
	NS.SHINY_CHANCE = G.savedShiny
	NS.TUTO_MENAGERIE_AUTO = G.savedAuto
	ResetWorld()
end
local function Count(list, value)
	local n = 0
	for _, v in ipairs(list) do if v == value then n = n + 1 end end
	return n
end

-- 1. Première occasion de capture : le tutoriel guidé ---------------------------------------------
do
	Say("-- qc2 guide : tutoriel à la première occasion de capture")
	G.Reset()
	G.Login()
	Mock:Advance(120)
	Check("[GUIDE] connexion d'un personnage connu : aucune bulle de tutoriel à vide",
		not NS:CompanionTutorialActive() and not tostring(G.Key() or ""):find("^TUTO"), G.Key())
	G.SeeKill(5001, { name = "Sanglier" })
	Check("[GUIDE] un monstre dans le filet, hors combat : le tutoriel commence, bulle « clique sur le filet »",
		NS:CompanionTutorialActive() and G.Key() == "TUTO_MENAGERIE_START"
		and NS.companionBubbleLine == POOLS.TUTO_MENAGERIE_START[1], G.Key())
	Check("[GUIDE] … l'étape attend le filet", NS:CompanionSequenceWaits("net"))
	Check("[GUIDE] … le carillon du bandeau a sonné une fois, le tutoriel ne le rejoue pas",
		Count(G.sounds, NS.CAPTURE_SOUNDS.ready) == 1, #G.sounds)
	Mock:Advance(RULES.tutoStep + 1)
	Check("[GUIDE] le temps ne passe pas l'étape", G.Key() == "TUTO_MENAGERIE_START" and NS:CompanionSequenceWaits("net"))
	NS.companionBubble.nextButton:Click()
	Check("[GUIDE] « Suivant » non plus : la consigne est redite", G.Key() == "TUTO_MENAGERIE_START" and NS:CompanionSequenceWaits("net"))
	Mock:Advance(0.1)
	local net = NS.captureNetButton
	Check("[GUIDE] le filet bat tant que l'étape attend", net and net.pulseUntil and net.pulseUntil > Mock.now)
	Mock:Advance(NS.CAPTURE_NET_PULSE + 1)
	Check("[GUIDE] … et bat encore après le battement d'arrivée", net.pulseUntil and net.pulseUntil > Mock.now)
	Check("[GUIDE] pendant l'attente, les autres bulles patientent", NS:CompanionSay("QUEST", { force = true }) == false)
	-- le filet part : silence pendant la scène
	G.Roll(0)
	Check("[GUIDE] clic sur le filet : le filet part", NS:CaptureThrow() == true and NS:CaptureState().rolling ~= nil)
	Check("[GUIDE] … la bulle s'efface, l'étape attend la fin de la scène", G.Key() == nil and NS:CompanionSequenceWaits("stage")
		and NS:CompanionTutorialActive())
	Check("[GUIDE] … silence : rien d'autre ne parle", NS:CompanionSay("QUEST", { force = true }) == false)
	G.PlayCapture()
	Check("[GUIDE] scène refermée, capturée : « Voilà ! »", NS:CaptureState().rolling == nil and G.Key() == "TUTO_MENAGERIE_OK", G.Key())
	Mock:Advance(RULES.tutoStep)
	Check("[GUIDE] puis la suite, au rythme du tutoriel : le filet et ses %d s", G.Key() == "TUTO_MENAGERIE"
		and NS.companionBubbleLine == POOLS.TUTO_MENAGERIE[1] and G.Text():find(NS.CAPTURE_QUEUE_TIME .. " s", 1, true) ~= nil, G.Text())
	NS.companionBubble.nextButton:Click()
	Check("[GUIDE] étoiles : la chance de 3 étoiles vient des constantes", NS.companionBubbleLine == POOLS.TUTO_MENAGERIE[2]
		and G.Text():find(NS.CAPTURE_STAR_ODDS[3] .. " %", 1, true) ~= nil, G.Text())
	NS.companionBubble.nextButton:Click()
	Check("[GUIDE] brillantes : 1 sur 150, 1 sur 40 après 50 abattus", NS.companionBubbleLine == POOLS.TUTO_MENAGERIE[3]
		and G.Text():find("sur 150", 1, true) and G.Text():find("sur 40", 1, true) and G.Text():find("50 abattus", 1, true), G.Text())
	NS.companionBubble.nextButton:Click()
	NS.companionBubble.nextButton:Click()
	Check("[GUIDE] emmener : les effets après 2 min", NS.companionBubbleLine == POOLS.TUTO_MENAGERIE[5]
		and G.Text():find(math.floor(NS.EFFECT_DELAY / 60) .. " min", 1, true) ~= nil, G.Text())
	NS.companionBubble.nextButton:Click()
	Check("[GUIDE] envies : le seuil des effets entiers", G.Text():find(NS.EFFECT_NEED_OK .. " %", 1, true) ~= nil, G.Text())
	NS.companionBubble.nextButton:Click()
	Check("[GUIDE] sceaux : +50 % de brillantes", G.Text():find("+" .. math.floor((NS.SEAL_SHINY_MULT - 1) * 100 + 0.5) .. " %", 1, true) ~= nil, G.Text())
	NS.companionBubble.nextButton:Click()
	Check("[GUIDE] titres : premier et dernier paliers", G.Text():find(NS.TRAINER_RANKS[1].count .. " espèces", 1, true)
		and G.Text():find("à " .. NS.TRAINER_RANKS[#NS.TRAINER_RANKS].count, 1, true), G.Text())
	-- combat au milieu : la bulle s'efface, la même étape revient
	local line = NS.companionBubbleLine
	G.combat = true
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Check("[GUIDE] combat : la bulle s'efface, le tutoriel attend", G.Key() == nil and NS:CompanionTutorialActive())
	G.combat = false
	Mock:Advance(1.5)
	Check("[GUIDE] fin du combat : la même bulle revient", NS.companionBubbleLine == line and G.Key() == "TUTO_MENAGERIE", NS.companionBubbleLine)
	for _ = 1, 3 do NS.companionBubble.nextButton:Click() end
	Check("[GUIDE] dernière bulle : le renvoi au Guide", NS.companionBubbleLine == POOLS.TUTO_MENAGERIE[#POOLS.TUTO_MENAGERIE]
		and G.Text():find("tuto collection", 1, true) ~= nil and not NS:CompanionData().tutoMenagerieDone)
	Mock:Advance(RULES.tutoStep)
	Check("[GUIDE] fini : vu pour ce personnage, bulle fermée", NS:CompanionData().tutoMenagerieDone == true
		and not NS:CompanionTutorialActive() and G.Key() == nil)
	Check("[GUIDE] … et le carnet s'ouvre sur la page Guide", NS.journalFrame and NS.journalFrame:IsShown()
		and NS.journalFrame.kind == "guide", NS.journalFrame and NS.journalFrame.kind)
	NS.journalFrame:Hide()
	G.SeeKill(5002, { name = "Loup" })
	Check("[GUIDE] une seule fois par personnage : la capture suivante ne le relance pas",
		not NS:CompanionTutorialActive() and G.Key() ~= "TUTO_MENAGERIE_START", G.Key())
	Check("[GUIDE] le tutoriel de base reste vu", NS:CompanionData().tutoDone == true)
end

-- 2. En combat, échec, trop tard, capture coupée, muet ---------------------------------------------
do
	Say("-- qc2 guide : combat, échappé, trop tard, capture coupée")
	G.Reset()
	G.combat = true
	G.SeeKill(5101, { name = "Raptor" })
	Check("[GUIDE] monstre abattu en combat : le tutoriel attend la fin du combat", not NS:CompanionTutorialActive())
	G.combat = false
	Mock:Advance(0.2); NS:CaptureTick(NS.Now())
	Check("[GUIDE] fin du combat (le compte démarre) : le tutoriel commence", NS:CompanionTutorialActive()
		and G.Key() == "TUTO_MENAGERIE_START" and NS:CompanionSequenceWaits("net"), G.Key())
	-- échappé
	G.Roll(0.99)
	NS:CaptureThrow()
	G.PlayCapture()
	Check("[GUIDE] échappé : « Il s'est échappé », puis la suite", G.Key() == "TUTO_MENAGERIE_FAIL", G.Key())
	Mock:Advance(RULES.tutoStep)
	Check("[GUIDE] … la suite reprend", G.Key() == "TUTO_MENAGERIE" and NS.companionBubbleLine == POOLS.TUTO_MENAGERIE[1])
	NS:CompanionSkipTutorial()
	-- trop tard : le candidat expire avant le clic
	G.Reset()
	G.SeeKill(5201, { name = "Crocilisque" })
	Check("[GUIDE] tutoriel lancé", NS:CompanionSequenceWaits("net"))
	Mock:Advance(NS.CAPTURE_QUEUE_TIME + 2); NS:CaptureTick(NS.Now())
	Check("[GUIDE] candidat parti avant le clic : « Trop tard », tutoriel en pause, pas vu",
		#NS:CaptureQueue() == 0 and not NS:CompanionTutorialActive() and G.Key() == "TUTO_MENAGERIE_LATE"
		and not NS:CompanionData().tutoMenagerieDone, G.Key())
	Mock:Advance(RULES.bubbleTime + 1)
	G.SeeKill(5202, { name = "Zhévra" })
	Check("[GUIDE] occasion suivante : il repart", NS:CompanionTutorialActive() and G.Key() == "TUTO_MENAGERIE_START", G.Key())
	-- « Ignorer » sur le bandeau vide le filet : pareil
	NS.captureToast.ignore:Click()
	Check("[GUIDE] Ignorer le seul candidat : « Trop tard » aussi", not NS:CompanionTutorialActive() and G.Key() == "TUTO_MENAGERIE_LATE", G.Key())
	-- « Passer » pendant l'attente : vu
	Mock:Advance(RULES.bubbleTime + 1)
	G.SeeKill(5203, { name = "Kodo" })
	NS.companionBubble.skipButton:Click()
	Check("[GUIDE] « Passer » : fini, vu, message du chat", NS:CompanionData().tutoMenagerieDone == true
		and not NS:CompanionTutorialActive() and Mock:Output():find("tuto collection", 1, true) ~= nil)
	-- capture coupée
	G.Reset()
	NS:DB().companionCapture = false
	G.SeeKill(5301, { name = "Hyène" })
	Mock:Advance(60)
	Check("[GUIDE] capture coupée : rien, drapeau à faux", not NS:CompanionTutorialActive()
		and not NS:CompanionData().tutoMenagerieDone and G.Key() ~= "TUTO_MENAGERIE_START")
	Mock:Reset()
	NS:HandleCommand("compagnon tuto collection")
	Check("[GUIDE] … à la demande : le chat dit pourquoi", not NS:CompanionTutorialActive()
		and Mock:Output():find(NS.L.COMP_MSG_TUTO_MEN_OFF, 1, true) ~= nil)
	-- muet
	G.Reset()
	NS:DB().companionChatter = 0
	G.SeeKill(5302, { name = "Lion" })
	Check("[GUIDE] bulles coupées : rien, drapeau à faux", not NS:CompanionTutorialActive() and not NS:CompanionData().tutoMenagerieDone)
end

-- 3. Nouveau personnage : le tutoriel de base d'abord, sans enchaîner -------------------------------
do
	Say("-- qc2 guide : nouveau personnage")
	G.Reset()
	NS:CompanionData().tutoDone = nil
	G.Login()
	Check("[GUIDE] nouveau personnage : le tutoriel de base", G.Key() == "TUTO" and NS:CompanionTutorialActive())
	Check("[GUIDE] sa dernière bulle annonce le filet", NS.L[POOLS.TUTO[#POOLS.TUTO]]:find("filet", 1, true) ~= nil)
	G.SeeKill(5401, { name = "Sanglier" })
	Check("[GUIDE] un monstre pendant le tutoriel de base : il continue, la collection attendra", G.Key() == "TUTO")
	for _ = 1, #POOLS.TUTO do NS.companionBubble.nextButton:Click() end
	Check("[GUIDE] tutoriel de base fini : rien n'enchaîne", NS:CompanionData().tutoDone == true and not NS:CompanionTutorialActive())
	Mock:Advance(90)
	Check("[GUIDE] … et rien ne part à vide", not NS:CompanionTutorialActive() and G.Key() ~= "TUTO_MENAGERIE_START")
	G.SeeKill(5402, { name = "Loup" })
	Check("[GUIDE] occasion suivante : le tutoriel des créatures, guidé", NS:CompanionTutorialActive()
		and G.Key() == "TUTO_MENAGERIE_START" and NS:CompanionSequenceWaits("net"), G.Key())
	NS:CompanionSkipTutorial()
end

-- 4. Rejeu : /qc compagnon tuto menagerie, bouton de la page Guide ----------------------------------
do
	Say("-- qc2 guide : rejeu")
	G.Reset()
	NS:CompanionData().tutoMenagerieDone = true
	Mock:Reset()
	NS:HandleCommand("compagnon tuto collection")
	Check("[GUIDE] /qc compagnon tuto collection : l'intro, sans attendre de capture", NS:CompanionTutorialActive()
		and G.Key() == "TUTO_MENAGERIE_INTRO" and not NS:CompanionSequenceWaits("net"), G.Key())
	Mock:Advance(RULES.tutoStep)
	Check("[GUIDE] … l'étape passe au temps", G.Key() == "TUTO_MENAGERIE" and NS.companionBubbleLine == POOLS.TUTO_MENAGERIE[1])
	NS:HandleCommand("compagnon tuto passer")
	Check("[GUIDE] … « passer » : fini, message de la collection", not NS:CompanionTutorialActive()
		and Mock:Output():find(NS.L.COMP_MSG_TUTO_MEN_SKIPPED, 1, true) ~= nil)
	NS:HandleCommand("compagnon tuto")
	Check("[GUIDE] /qc compagnon tuto : toujours le tutoriel de base", G.Key() == "TUTO")
	NS:HandleCommand("compagnon tuto passer")
	Check("[GUIDE] l'aide de la commande nomme « collection »", NS.L.HELP_COMPANION:find("collection", 1, true) ~= nil)
	-- rejeu jusqu'au bout : le carnet ne s'ouvre pas tout seul
	NS:HandleCommand("compagnon tuto collection")
	for _ = 1, #POOLS.TUTO_MENAGERIE + 1 do Mock:Advance(RULES.tutoStep) end
	Check("[GUIDE] rejeu fini : pas de carnet ouvert", not NS:CompanionTutorialActive()
		and not (NS.journalFrame and NS.journalFrame:IsShown()))
	-- en combat : il attend la fin du combat
	G.combat = true
	Mock:Reset()
	NS:HandleCommand("compagnon tuto collection")
	Check("[GUIDE] rejeu en combat : après le combat", not NS:CompanionTutorialActive()
		and Mock:Output():find(NS.L.COMP_MSG_TUTO_COMBAT, 1, true) ~= nil)
	G.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Check("[GUIDE] … fin du combat : il part", NS:CompanionTutorialActive() and G.Key() == "TUTO_MENAGERIE_INTRO")
	NS:CompanionSkipTutorial()
	-- le bouton de la page Guide
	NS:ToggleJournal(true)
	NS:SelectJournalKind("guide")
	local pane = NS.journalFrame.guide
	pane.replay:Click()
	Check("[GUIDE] « Revoir le tutoriel » : le carnet se ferme, les bulles repartent", not NS.journalFrame:IsShown()
		and NS:CompanionTutorialActive() and G.Key() == "TUTO_MENAGERIE_INTRO", G.Key())
	NS:CompanionSkipTutorial()
end

-- 5. Parité FR/EN des bulles et des textes du guide ----------------------------------------------------
do
	Say("-- qc2 guide : parité fr/en")
	local function Specs(text)
		local list = {}
		for spec in tostring(text or ""):gsub("%%%%", ""):gmatch("%%[sd]") do list[#list + 1] = spec end
		return table.concat(list, ",")
	end
	local lines = NS.COMPANION_LINE_STRINGS
	local bad = {}
	for _, pool in ipairs({ "TUTO_MENAGERIE", "TUTO_MENAGERIE_START", "TUTO_MENAGERIE_OK", "TUTO_MENAGERIE_FAIL",
		"TUTO_MENAGERIE_LATE", "TUTO_MENAGERIE_INTRO" }) do
		for _, key in ipairs(POOLS[pool] or {}) do
			local fr, en = lines.fr[key], lines.en[key]
			if type(fr) ~= "string" or fr == "" or type(en) ~= "string" or en == "" or Specs(fr) ~= Specs(en) then bad[#bad + 1] = key end
		end
	end
	Check("[GUIDE] bulles : chaque clé en français et en anglais, mêmes arguments", #bad == 0, table.concat(bad, ", "))
	Check("[GUIDE] bulles : la suite tient en une dizaine", #POOLS.TUTO_MENAGERIE >= 9 and #POOLS.TUTO_MENAGERIE <= 12, #POOLS.TUTO_MENAGERIE)
	-- les arguments de chaque bulle de la suite, prêts pour sa ligne
	local steps, stepArgs = NS:CompanionMenagerieTutorialSteps(true)
	local unformatted = {}
	for index, step in ipairs(steps) do
		if type(step) == "string" then
			local text = NS:F(step, unpack(stepArgs[index] or {}))
			if text:find("%%[sd]") then unformatted[#unformatted + 1] = step end
		end
	end
	Check("[GUIDE] bulles : aucun « %d » laissé sans argument (guidé)", #unformatted == 0 and #steps == #POOLS.TUTO_MENAGERIE + 2,
		table.concat(unformatted, ", "))
	local guide = NS.GUIDE_STRINGS
	bad = {}
	for key, fr in pairs(guide.fr) do
		local en = guide.en[key]
		if type(en) ~= "string" or en == "" or Specs(fr) ~= Specs(en) then bad[#bad + 1] = key end
	end
	for key in pairs(guide.en) do if guide.fr[key] == nil then bad[#bad + 1] = key .. " (en seul)" end end
	table.sort(bad)
	Check("[GUIDE] page Guide : mêmes clés et arguments en français et en anglais", #bad == 0, table.concat(bad, ", "))
	Check("[GUIDE] la scène : « Clic ou Échap pour fermer », en deux langues",
		NS.CAPTURE_STAGE_STRINGS.fr.CAPTURE_STAGE_CLOSE:find("Échap", 1, true) ~= nil
		and NS.CAPTURE_STAGE_STRINGS.en.CAPTURE_STAGE_CLOSE:find("Escape", 1, true) ~= nil)
end

-- 6. La page Guide du carnet -------------------------------------------------------------------------
do
	Say("-- qc2 guide : page Guide")
	G.Reset()
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	Check("[GUIDE] entrée « Guide » au menu, en dernier", f.sections.guide and f.sections.guide.text.text == NS.L.JRN_SEC_guide
		and f.sections.guide.points[1].y < f.sections.progress.points[1].y)
	NS:SelectJournalKind("guide")
	local pane = f.guide
	Check("[GUIDE] la page s'ouvre, titre et sous-titre", f.kind == "guide" and pane:IsShown()
		and f.header.title.text == NS.L.JRN_SEC_guide and f.header.subtitle.text == NS.L.JRN_SUB_guide)
	Check("[GUIDE] sommaire : neuf sections, dans l'ordre", #pane.rows == 9 and #NS.GUIDE_SECTIONS == 9
		and pane.rows[1].label.text == NS.L.GUIDE_SEC_net and pane.rows[4].label.text == NS.L.GUIDE_SEC_effects
		and pane.rows[9].label.text == NS.L.GUIDE_SEC_settings)
	Check("[GUIDE] la première section ouverte : Le filet", f.guideSection == "net" and pane.rows[1].selected
		and pane.title.text == NS.L.GUIDE_SEC_net and pane.shown >= 3)
	Check("[GUIDE] Le filet : les chiffres des constantes (12 monstres, 30 s, 30 %)",
		pane.paras[2].text:find(NS.CAPTURE_QUEUE_MAX .. " monstres", 1, true) and pane.paras[2].text:find(NS.CAPTURE_QUEUE_TIME .. " s", 1, true)
		and pane.paras[5].text:find("normal " .. math.floor(NS.CAPTURE_RATES.normal * 100 + 0.5) .. " %", 1, true), pane.paras[5].text)
	Check("[GUIDE] Le filet : bandeau (Ignorer, Sourdine 5, 15, 30 et 60 min), sons, Échap",
		pane.paras[4].text:find("Sourdine", 1, true) and pane.paras[4].text:find("5, 15, 30 et 60 min", 1, true)
		and pane.paras[4].text:find(NS.L.OPT_DAILY_CAPTURE_SOUND, 1, true) and pane.paras[3].text:find("Échap", 1, true), pane.paras[4].text)
	Check("[GUIDE] Le filet : les aides avec leur facteur", pane.paras[5].text:find(NS:CaptureAidLabel("appat") .. " ×1,5", 1, true)
		and pane.paras[5].text:find(NS:CaptureAidLabel("sifflet"), 1, true), pane.paras[5].text)
	pane.rows[2]:Click()
	Check("[GUIDE] Les étoiles : 60 / 30 / 10 %", f.guideSection == "stars" and pane.title.text == NS.L.GUIDE_SEC_stars
		and pane.paras[1].text:find(NS.CAPTURE_STAR_ODDS[1] .. " %", 1, true) and pane.paras[1].text:find(NS.CAPTURE_STAR_ODDS[3] .. " %", 1, true)
		and pane.paras[3].text:find("+0,25", 1, true), pane.paras[1].text)
	NS:JournalGuidePick("shiny")
	Check("[GUIDE] Les brillantes : 1 sur 150, ×3, 1 sur 40 après 50, ×1,5 en zone scellée",
		pane.paras[1].text:find("1 chance sur 150", 1, true) and pane.paras[1].text:find("×" .. NS.SHINY_RANK_MULT, 1, true)
		and pane.paras[2].text:find("1 sur 40", 1, true) and pane.paras[2].text:find(NS.SHINY_CHAIN_KILLS .. " abattus", 1, true)
		and pane.paras[2].text:find("×1,5", 1, true), pane.paras[2].text)
	-- la table des types
	NS:JournalGuidePick("effects")
	local rows = NS:JournalGuideTypeRows()
	Check("[GUIDE] table des types : les huit types et la mascotte", #rows == 9 and rows[1].key == "beast" and rows[9].key == "mascot"
		and rows[2].label == NS:CreatureTypeLabel("humanoid"))
	Check("[GUIDE] … les vraies valeurs (base et plafond) depuis CompanionEffects",
		rows[2].hunt == NS:F("GUIDE_CAP", NS:F("EFF_capture_humanoid", 10), 40)
		and rows[1].comfort == NS:F("GUIDE_CAP", NS:F("EFF_decay_hunger", 10), 40)
		and rows[9].hunt == NS:F("GUIDE_CAP", NS:F("EFF_capture_all", 2), 10), rows[2].hunt)
	Check("[GUIDE] … en-tête Type · Chasse · Confort et les rangées affichées", pane.theads[1]:IsShown()
		and pane.theads[1].cells[2].text == NS.Theme.Upper(NS.L.GUIDE_COL_HUNT) and pane.trows[1]:IsShown()
		and pane.trows[1].cells[1].text == NS:CreatureTypeLabel("beast") and pane.trows[1].cells[2].text == rows[1].hunt)
	Check("[GUIDE] … la page est paginée, la pagination le dit", pane.blocks > pane.shown and pane.pager.position.text ~= ""
		and pane.hint.text == NS.L.GUIDE_MORE, pane.pager.position.text)
	local first = pane.shown
	NS:ScrollJournal(-1)
	Check("[GUIDE] molette : un bloc de plus", f.guideOffset == 1)
	for _ = 1, 40 do NS:ScrollJournal(-1) end
	local last = f.guideOffset
	Check("[GUIDE] … bornée : la dernière page montre le dernier bloc", last < pane.blocks and f.guideOffset + pane.shown == pane.blocks
		and pane.paras[pane.shown - 3] ~= nil, f.guideOffset .. " / " .. pane.blocks)
	local blocks = NS:JournalGuideBlocks("effects", pane.cols)
	local strength
	for _, block in ipairs(blocks) do if block.kind == "p" and block.text:find("rang normal", 1, true) then strength = block.text end end
	Check("[GUIDE] la force : ×1, ×1,5, ×2, ×2,5, +0,5 brillante, +0,25 par étoile, +0,25 par palier", strength
		and strength:find("×1,5", 1, true) and strength:find("×2,5", 1, true) and strength:find("+0,5", 1, true)
		and strength:find("+0,25 par étoile", 1, true) and strength:find("+0,25 par palier", 1, true), strength)
	local delay
	for _, block in ipairs(blocks) do if block.kind == "p" and block.text:find("confirmation", 1, true) then delay = block.text end end
	Check("[GUIDE] le délai de 2 minutes et le seuil de 50 %", delay and delay:find("2 minutes", 1, true)
		and blocks[#blocks - 1].text:find(NS.EFFECT_NEED_OK .. " %", 1, true), delay)
	for _ = 1, 40 do NS:ScrollJournal(1) end
	Check("[GUIDE] … retour en haut", f.guideOffset == 0 and pane.shown == first)
	pane.pager.down:Click()
	Check("[GUIDE] chevron : une page entière", f.guideOffset == first)
	-- sceaux, titres, missions, fiche, réglages
	NS:JournalGuidePick("seals")
	Check("[GUIDE] Sceaux : brillantes ×1,5", pane.paras[2].text:find("×" .. NS.MenagerieDecimal(NS.SEAL_SHINY_MULT), 1, true) ~= nil)
	NS:JournalGuidePick("titles")
	local titleBlocks = NS:JournalGuideBlocks("titles", pane.cols)
	local ranks = {}
	for _, block in ipairs(titleBlocks) do if block.kind == "row" and not block.head then ranks[#ranks + 1] = block end end
	Check("[GUIDE] Titres : paliers par type (10, 20 et 40 ; 5, 10 et 20) et les types rares",
		titleBlocks[1].text:find("10, 20 et 40", 1, true) and titleBlocks[1].text:find("5, 10 et 20", 1, true)
		and titleBlocks[1].text:find(NS:CreatureTypeLabel("dragonkin"), 1, true), titleBlocks[1].text)
	Check("[GUIDE] Titres : cinq rangs, 10 à 250 espèces, leurs noms et leurs récompenses", #ranks == #NS.TRAINER_RANKS
		and ranks[1].cells[1] == "10" and ranks[5].cells[1] == "250" and ranks[1].cells[2] == NS.L.TRAINER_apprentice
		and ranks[5].cells[2] == NS.L.TRAINER_grandmaster and ranks[1].cells[3] == NS:TrainerRankGift(NS.TRAINER_RANKS[1])
		and ranks[1].cells[3]:find(NS:CaptureAidLabel("appat"), 1, true), ranks[1].cells[3])
	NS:JournalGuidePick("missions")
	Check("[GUIDE] Missions : récompenses depuis MISSION_REWARDS, sifflet toutes les 10 captures",
		pane.paras[1].text:find(NS:CaptureAidLabel("appat"), 1, true) and pane.paras[1].text:find(NS:TreatLabel("festin"), 1, true)
		and pane.paras[2].text:find(NS:CaptureAidLabel("sifflet"), 1, true)
		and pane.paras[3].text:find(NS.CAPTURE_GIFT_EVERY .. " captures", 1, true), pane.paras[1].text)
	NS:JournalGuidePick("card")
	Check("[GUIDE] Fiche : /qc fiche, l'entrée du menu et le réglage", pane.paras[2].text:find("/qc fiche", 1, true)
		and pane.paras[2].text:find(NS.L.TRAINER_MENU, 1, true) and pane.paras[3].text:find(NS.L.OPT_DAILY_TRAINER, 1, true))
	NS:JournalGuidePick("settings")
	Check("[GUIDE] Réglages : sons, cadrage (Portrait, Buste, En pied), commandes", pane.paras[1].text:find(NS.L.OPT_DAILY_CAPTURE_SOUND, 1, true)
		and pane.paras[2].text:find(NS.L.OPT_COMP_FRAMING, 1, true) and pane.paras[2].text:find(NS.L.COMP_FRAMING_pied, 1, true)
		and pane.paras[3].text:find("/qc compagnon tuto collection", 1, true) and pane.paras[3].text:find("sourdine", 1, true)
		and pane.paras[4].text:find(NS.L.GUIDE_REPLAY, 1, true), pane.paras[2].text)
	Check("[GUIDE] anciens noms de page : inchangés", (function() NS:SelectJournalKind("collection"); return f.kind == "evolution" end)())
	NS:SelectJournalKind("guide")
	Check("[GUIDE] la page retenue pour la prochaine ouverture", NS:DB().journalTab == "guide")
	f:Hide()
	-- ouverture directe sur une section
	NS:OpenJournalGuide("titles")
	Check("[GUIDE] OpenJournalGuide : ouvert sur la section demandée", f:IsShown() and f.kind == "guide" and f.guideSection == "titles")
	f:Hide()
end

-- 7. Aperçu : aucun chevauchement, en français puis en anglais -------------------------------------
do
	Say("-- qc2 guide : aperçu, chaque section sans chevauchement")
	local savedW, savedH = UIParent.width, UIParent.height
	local savedColor = rawget(_G, "CreateColor")
	_G.CreateColor = savedColor or Mock.CreateColor
	local ok, frame = pcall(Snap.scenes["qc-journal-guide"], T)
	_G.CreateColor = savedColor
	Check("[GUIDE] scène qc-journal-guide construite", ok and frame ~= nil, frame)
	if ok and frame then
		local function Clean(lang)
			local bad = {}
			for _, key in ipairs(NS.GUIDE_SECTIONS) do
				NS:JournalGuidePick(key)
				local pane = frame.guide
				local pages = 0
				repeat
					local overlaps, outside, count = Snap.Layout(frame)
					for _, o in ipairs(overlaps) do bad[#bad + 1] = lang .. " " .. key .. " : " .. o end
					for _, o in ipairs(outside) do bad[#bad + 1] = lang .. " " .. key .. " hors cadre : " .. o end
					if count < 10 then bad[#bad + 1] = lang .. " " .. key .. " : trop peu de texte" end
					-- le dernier bloc au-dessus de la pagination
					local pager = Snap.Rect(pane.pager, { memo = {} })
					for _, list in ipairs({ pane.paras, pane.heads, pane.trows, pane.theads }) do
						for _, region in ipairs(list) do
							if Snap.Visible(region) then
								local r = Snap.Rect(region, { memo = {} })
								if r and pager and r.top + r.height > pager.top - 4 then bad[#bad + 1] = lang .. " " .. key .. " : sous la pagination" end
							end
						end
					end
					local before = frame.guideOffset
					NS:ScrollJournal(-pane.shown)
					pages = pages + 1
				until frame.guideOffset == before or pages > 8
			end
			return bad
		end
		local bad = Clean("fr")
		Check("[GUIDE] français : aucun chevauchement, rien ne sort, le dernier bloc au-dessus de la pagination", #bad == 0, table.concat(bad, " | "))
		-- en anglais : les textes du guide, des effets, des types et des titres
		local swapped = {}
		for _, pack in ipairs({ NS.GUIDE_STRINGS, NS.EFFECT_STRINGS, NS.CREATURE_TYPE_STRINGS, NS.MENAGERIE_COLLECTION_STRINGS }) do
			for key, text in pairs(pack.en) do NS.L[key] = text; swapped[#swapped + 1] = key end
		end
		bad = Clean("en")
		local leftover = {}
		for _, key in ipairs(NS.GUIDE_SECTIONS) do
			for _, block in ipairs(NS:JournalGuideBlocks(key, frame.guide.cols)) do
				local texts = block.kind == "row" and block.cells or { block.text }
				for _, text in ipairs(texts) do if text:find("%%[sd]") then leftover[#leftover + 1] = key end end
			end
		end
		for _, key in ipairs(swapped) do NS.L[key] = nil end
		Check("[GUIDE] anglais : aucun chevauchement, rien ne sort", #bad == 0, table.concat(bad, " | "))
		Check("[GUIDE] anglais : aucun argument laissé en plan", #leftover == 0, table.concat(leftover, ", "))
		Check("[GUIDE] retour au français", NS.L.GUIDE_SEC_net == NS.GUIDE_STRINGS.fr.GUIDE_SEC_net)
		frame:Hide()
	end
	UIParent.width, UIParent.height = savedW, savedH
	ResetWorld()
end

-- 8. Échap et « × » : la scène de capture et la liste du filet ----------------------------------------
do
	Say("-- qc2 guide : fermer la scène et la liste")
	G.Reset()
	NS.TUTO_MENAGERIE_AUTO = false
	NS:DB().companionCaptureAnim = true
	G.SeeKill(5501, { name = "Ours" })
	NS.captureNetButton:Click("RightButton")
	local list = NS.captureQueueList
	Check("[GUIDE] la liste a un nom et un « × »", list and list:GetName() == "QuestCompanionCaptureList" and list.close ~= nil)
	local function Registered(name)
		for _, entry in ipairs(UISpecialFrames) do if entry == name then return true end end
		return false
	end
	Check("[GUIDE] la liste est inscrite pour Échap", Registered("QuestCompanionCaptureList"))
	list.close:Click()
	Check("[GUIDE] « × » : la liste se ferme", not list:IsShown())
	NS.captureNetButton:Click("RightButton")
	Check("[GUIDE] rouverte", list:IsShown())
	G.Roll(0)
	list.rows[1]:Click()
	Check("[GUIDE] clic sur une ligne : le filet part, la liste se ferme", not list:IsShown() and NS:CaptureState().rolling ~= nil)
	local stage = NS.captureStage
	-- (dans le mock, GetName() rend le champ `name`, où la scène range la
	-- FontString du nom de la créature : on lit l'inscription elle-même)
	Check("[GUIDE] la scène est inscrite pour Échap sous son nom", stage and Registered("QuestCompanionCaptureStage") and stage:IsShown(),
		table.concat(UISpecialFrames, ","))
	-- Échap avant le verdict : la scène se cache, la capture se résout quand même
	Mock:Reset()
	stage:Hide()
	stage:GetScript("OnHide")(stage)
	Check("[GUIDE] Échap avant le verdict : scène cachée, le lancer continue", not stage:IsShown() and stage.rolling == nil
		and NS:CaptureState().rolling ~= nil)
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[GUIDE] … le verdict tombe et s'annonce dans le chat", NS:CaptureState().rolling.result == "ok"
		and Mock:Output():find("Ours", 1, true) ~= nil, Mock:Output())
	Mock:Advance(NS.CAPTURE_STAGE_HOLD + 0.5); NS:CaptureTick(NS.Now())
	Check("[GUIDE] … et le lancer se termine", NS:CaptureState().rolling == nil)
	-- Échap après le verdict : la scène se ferme et le lancer se termine au relevé suivant
	G.SeeKill(5502, { name = "Loup", spawn = "00000000AB" })
	G.Roll(0)
	NS:CaptureThrow()
	local rolling = NS:CaptureState().rolling
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[GUIDE] verdict tombé, scène affichée", rolling.result == "ok" and stage:IsShown() and rolling.closeAt > Mock.now)
	NS:CaptureStageUpdate(rolling.resultAt + 1.3)
	Check("[GUIDE] le pied dit « Clic ou Échap pour fermer »", stage.footer:GetText() == NS.L.CAPTURE_STAGE_CLOSE)
	stage:Hide()
	stage:GetScript("OnHide")(stage)
	NS:CaptureTick(NS.Now())
	Check("[GUIDE] Échap après le verdict : terminé", NS:CaptureState().rolling == nil and not stage:IsShown())
	-- un nouveau lancer pendant les 3,5 s du verdict : il part sans attendre
	G.SeeKill(5503, { name = "Cerf", spawn = "00000000AC" })
	NS:CaptureThrow()
	rolling = NS:CaptureState().rolling
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	G.SeeKill(5504, { name = "Hibou", spawn = "00000000AD" })
	Check("[GUIDE] verdict à l'écran, un autre monstre dans le filet", rolling.result == "ok" and #NS:CaptureQueue() == 1)
	Check("[GUIDE] clic sur le filet : le verdict se referme, le nouveau lancer part", NS:CaptureThrow() == true
		and NS:CaptureState().rolling ~= rolling and NS:CaptureState().rolling.target.name == "Hibou")
	Check("[GUIDE] un seul essai à la fois, toujours", NS:CaptureThrow() == false)
	G.PlayCapture()
end

G.Done()
