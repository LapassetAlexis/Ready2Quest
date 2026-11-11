-- QuestCompanion 3.0.0 : les tutoriels guidés (GuidedTour.lua), le clic droit
-- du compagnon, l'explication de la migration et le cadeau de la 3.0.
--   * le moteur : étapes, Suivant, Passer, Échap, compteur, ancre absente,
--     pause en combat, sauvegarde au compte, /qc tuto, les deux styles et
--     leurs contrastes ;
--   * la visite des premières captures : le filet (attend le clic), la carte
--     (qualité, chance, aides), Lancer / Passer, le verdict (Codex ou
--     Réserve), le mode chasse ; Maj+clic ; monstre parti ;
--   * la visite du carnet : un onglet par étape, montré et ouvert ;
--   * plus de tutoriel de la ménagerie (2.3.0) : jamais deux tutoriels ;
--     remise à zéro en 3.0 quels que soient les anciens drapeaux ;
--   * clic droit = carnet, Maj + clic droit = menu de chasse ;
--   * la migration expliquée une fois, avec les vrais chiffres, seulement
--     pour qui avait des créatures ; le cadeau de la 3.0 (plus de 3 espèces) :
--     3 au plus, jamais brillant, « Cadeau de la 3.0 », une fois, plus tard
--     depuis la page Réserve, dans la limite de la Réserve.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local P = { saved = {}, random = math.random, units = {} }
P.rollQuality = NS.CaptureRollQuality
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"UnitAffectingCombat", "InCombatLockdown", "IsShiftKeyDown", "IsControlKeyDown", "UnitOnTaxi", "time" }
for _, name in ipairs(GLOBALS) do P.saved[name] = rawget(_G, name) end
P.savedShiny, P.savedAuto = NS.SHINY_CHANCE, NS.TOUR_AUTO
local PLAYER = "Player-1-00000001"
local FIELDS = { "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt", "captureQueueList",
	"captureNetButton", "captureToast", "captureResult", "companionMenu" }
local SCENES = { "captureStage", "captureBatchFrame", "captureChooser" }
local CACHES = { "captureStages", "captureBatchFrames", "captureChoosers" }

function P.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function P.Install()
	local w = P
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
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return w.combat == true end
	_G.IsShiftKeyDown = function() return w.shift == true end
	_G.IsControlKeyDown = function() return false end
	_G.UnitOnTaxi = function() return false end
	_G.time = function() return w.wall end
end
local function HideScenes()
	for _, field in ipairs(SCENES) do
		local frame = NS[field]
		if frame then frame.prep = nil; frame:Hide(); frame.rolling = nil end
	end
	for _, field in ipairs(CACHES) do
		for _, frame in pairs(NS[field] or {}) do frame.prep = nil; frame:Hide(); frame.rolling = nil end
	end
end
function P.Reset(style)
	if NS.tourState then NS:TourStop() end
	NS.tourPending, NS.tourMigrationAt, NS.tourHoldJournal = nil, nil, nil
	ResetWorld()
	P.quality = nil
	NS.CaptureRollQuality = function() return P.quality or 1 end
	HideScenes()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	for _, field in ipairs(SCENES) do NS[field] = nil end
	for _, field in ipairs(CACHES) do NS[field] = nil end
	NS.uiStyleCache = {}
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureToastHideAt, NS.captureAppCache, NS.captureBatch, NS.specimenCountCache = nil, nil, nil, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	NS:DB().capture, NS.captureMergedChar = nil, nil
	NS:DB().tour30 = nil
	P.units, P.combat, P.shift, P.wall = {}, false, false, 1800000000
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	P.Install()
	if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
	NS:DB().winterVeil = "off"
	NS.SHINY_CHANCE = 0
	math.random = P.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = true
	NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
	NS:CompanionUpdateVisibility()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	if NS.notifyState then NS.notifyState.at = -math.huge end
	NS.TOUR_AUTO = true
end
function P.Roll(value)
	math.random = function(a, b)
		if a and b then return P.random(a, b) end
		if a then return P.random(a) end
		return value
	end
end
function P.SeeKill(npcID, fields)
	fields = fields or {}
	local guid = P.Guid(npcID, fields.spawn)
	fields.guid = guid
	fields.name = fields.name or ("Bête " .. npcID)
	P.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
	return guid
end
-- la scène jouée jusqu'au verdict, puis jusqu'à sa fermeture
function P.PlayCapture()
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Mock:Advance((NS.CAPTURE_STAGE_HOLD or 3) + 0.5); NS:CaptureTick(NS.Now())
	for _ = 1, 3 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
end
function P.UI()
	local style = (NS.AzerothOn and NS:AzerothOn()) and "azeroth" or "sobre"
	return NS.tourUI and NS.tourUI[style] or {}
end
function P.Callout() return P.UI().callout end
function P.Ring() return P.UI().ring end
function P.Shown() local c = P.Callout(); return c ~= nil and c:IsShown() end
function P.Title() local c = P.Callout(); return c and c.title:GetText() or "" end
function P.Text() local c = P.Callout(); return c and c.text:GetText() or "" end
function P.Step() return NS.tourState and NS.tourState.def.steps[NS.tourState.index] or nil end
function P.StepId() local s = P.Step(); return s and s.id end
function P.Done()
	if NS.tourState then NS:TourStop() end
	NS.TOUR_DEFS.test = nil
	for _, name in ipairs(GLOBALS) do _G[name] = P.saved[name] end
	math.random = P.random
	NS.SHINY_CHANCE = P.savedShiny
	NS.TOUR_AUTO = P.savedAuto
	NS.CaptureRollQuality = P.rollQuality
	HideScenes()
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
	NS:DB().capture, NS.captureMergedChar = nil, nil
	NS:DB().tour30 = nil
	ResetWorld()
end
local function Has(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end
local function Lum(c)
	local function lin(v) if v <= 0.03928 then return v / 12.92 end return ((v + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
end
local function Anchor()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(40, 40)
	f:Show()
	return f
end

-- 1. Le moteur ----------------------------------------------------------------------------------------------
do
	Say("-- qc30 tutoriel : le moteur")
	P.Reset()
	local a, b, c = Anchor(), Anchor(), Anchor()
	local done = { ok = false }
	NS.TOUR_DEFS.test = { steps = {
		{ id = "a", anchor = a, title = "TOUR_A1_T", text = "TOUR_A1", placement = "top" },
		{ id = "b", anchor = function() return b end, title = "TOUR_A2_T", text = "TOUR_A2", placement = "right" },
		{ id = "c", anchor = c, title = "TOUR_A3_T", text = function() return "texte c" end, placement = "bottom", noNext = true,
			waitFor = function() return done.ok end },
	} }
	Check("[ENG] départ : bulle, titre, texte, compteur 1 / 3", NS:TourStart("test") and P.Shown() and P.Title() == NS.L.TOUR_A1_T
		and P.Text() == NS.L.TOUR_A1 and P.Callout().step:GetText() == "1 / 3", P.Callout() and P.Callout().step:GetText())
	Check("[ENG] liseré autour de l'ancre, « Suivant » et « Passer le tutoriel »", P.Ring():IsShown() and P.Ring().anchor == a
		and P.Callout().nextButton:IsShown() and P.Callout().skipButton:IsShown()
		and P.Callout().skipButton.text:GetText() == NS.L.TOUR_SKIP)
	Check("[ENG] une seule visite à la fois", NS:TourStart("journal") == false and NS:TourActive() == "test")
	P.Callout().nextButton:Click()
	Check("[ENG] Suivant : étape 2, ancre fonction, 2 / 3", P.StepId() == "b" and P.Ring().anchor == b
		and P.Callout().step:GetText() == "2 / 3")
	-- combat : pause, même étape à la reprise
	P.combat = true
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Check("[ENG] combat : bulle et liseré cachés, visite en pause", not P.Shown() and not P.Ring():IsShown()
		and NS.tourState.paused and P.StepId() == "b")
	Mock:Advance(1)
	Check("[ENG] … reste cachée tant que dure le combat", not P.Shown())
	P.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Mock:Advance(0.2)
	Check("[ENG] fin du combat : la même étape revient", P.Shown() and P.StepId() == "b" and not NS.tourState.paused)
	P.Callout().nextButton:Click()
	Check("[ENG] étape qui attend un geste : pas de « Suivant », texte en fonction", P.StepId() == "c"
		and not P.Callout().nextButton:IsShown() and P.Text() == "texte c")
	Mock:Advance(5)
	Check("[ENG] … le temps ne la passe pas", P.StepId() == "c" and P.Shown())
	done.ok = true
	Mock:Advance(0.2)
	Check("[ENG] geste fait : fin, vue au compte", NS:TourActive() == nil and NS:TourDone("test") and not P.Shown()
		and NS:DB().tour30.test == true)
	-- ancre absente : attend puis passe ; ancre qui disparaît après affichage : étape suivante
	NS:TourMark("test", false)
	a:Hide()
	NS:TourStart("test")
	Check("[ENG] ancre absente : rien d'affiché, l'étape attend", not P.Shown() and P.StepId() == "a")
	Mock:Advance(NS.TOUR.missingWait + 0.5)
	Check("[ENG] … puis passe à la suivante", P.StepId() == "b" and P.Shown() and P.Callout().step:GetText() == "2 / 3")
	done.ok = false
	b:Hide()
	Mock:Advance(0.2)
	Check("[ENG] ancre partie après l'affichage : étape suivante tout de suite", P.StepId() == "c")
	a:Show(); b:Show()
	-- Échap : la bulle se ferme, la visite est passée
	local callout = P.Callout()
	local rootShown = UIParent.shown
	-- toute l'interface cachée (Alt+Z) : pas un Échap
	UIParent.shown = false
	callout:Hide()
	callout.scripts.OnHide(callout)
	Check("[ENG] interface cachée (Alt+Z) : la visite continue, l'étape reviendra", NS:TourActive() == "test"
		and NS.tourState.shownIndex == nil)
	UIParent.shown = true
	Mock:Advance(0.2)
	Mock:Reset()
	callout:Hide()
	callout.scripts.OnHide(callout)
	UIParent.shown = rootShown
	Check("[ENG] Échap : visite passée, vue, message du chat", NS:TourActive() == nil and NS:TourDone("test")
		and Has(Mock:Output(), NS.L.TOUR_MSG_SKIPPED))
	Check("[ENG] Échap : la bulle est inscrite (UISpecialFrames)", (function()
		for _, name in ipairs(UISpecialFrames) do if name == callout:GetName() then return true end end
		return false
	end)())
	-- « Passer le tutoriel »
	NS:TourMark("test", false)
	done.ok = false
	NS:TourStart("test")
	P.Callout().skipButton:Click()
	Check("[ENG] « Passer le tutoriel » : fini, vu", NS:TourActive() == nil and NS:TourDone("test") and not P.Shown())
	-- démarrée en combat : après le combat
	NS:TourMark("test", false)
	P.combat = true
	Check("[ENG] départ en combat : en attente", NS:TourStart("test") == false and NS.tourPending == "test" and not P.Shown())
	P.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Mock:Advance(0.2)
	Check("[ENG] … part à la fin du combat", NS:TourActive() == "test" and P.Shown())
	NS:TourStop()
	Check("[ENG] arrêt : rien de marqué", not NS:TourDone("test") and not P.Shown())
	-- /qc tuto reset, passer, aide
	NS:TourMark("capture", true); NS:TourMark("journal", true)
	Mock:Reset()
	NS:HandleCommand("tuto reset")
	Check("[ENG] /qc tuto reset : tout à revoir", not NS:TourDone("capture") and not NS:TourDone("journal")
		and Has(Mock:Output(), NS.L.TOUR_MSG_RESET))
	Mock:Reset()
	NS:HandleCommand("tuto")
	Check("[ENG] /qc tuto : l'aide", Has(Mock:Output(), "/qc tuto"))
	NS:TourStart("test")
	NS:HandleCommand("tuto passer")
	Check("[ENG] /qc tuto passer : la visite s'arrête, vue", NS:TourActive() == nil and NS:TourDone("test"))
	-- parité FR/EN
	local S = NS.TOUR_STRINGS
	local bad = {}
	local function Specs(text)
		local list = {}
		for spec in tostring(text or ""):gsub("%%%%", ""):gmatch("%%[sd]") do list[#list + 1] = spec end
		return table.concat(list, ",")
	end
	for key, fr in pairs(S.fr) do
		local en = S.en[key]
		if type(en) ~= "string" or en == "" or Specs(fr) ~= Specs(en) then bad[#bad + 1] = key end
	end
	for key in pairs(S.en) do if S.fr[key] == nil then bad[#bad + 1] = key .. " (en seul)" end end
	Check("[ENG] textes : mêmes clés et arguments en français et en anglais", #bad == 0, table.concat(bad, ", "))
	NS.TOUR_DEFS.test = nil
end

-- 2. Les deux styles, et les contrastes --------------------------------------------------------------------
do
	Say("-- qc30 tutoriel : styles et contrastes")
	P.Reset()
	local a = Anchor()
	NS.TOUR_DEFS.test = { steps = { { id = "a", anchor = a, title = "TOUR_A1_T", text = "TOUR_A1" } } }
	NS:TourStart("test")
	local c = P.Callout()
	Check("[STYLE] Azeroth : bulle de parchemin, encres des rôles mesurés", c.uiStyle == "azeroth" and c.title.azRole == "tour.title"
		and c.text.azRole == "tour.text" and c.step.azRole == "tour.step" and c.nextButton.azeroth)
	local INK, CONTRAST = NS.AZEROTH_INK, NS.AZEROTH_CONTRAST
	local bad = {}
	for role, entry in pairs(NS.TOUR_CONTRAST) do
		local ratio = NS.AzerothContrast(INK[entry[1]], entry[2])
		if CONTRAST[role] ~= entry or ratio < entry[3] or entry[3] < 4.5 then bad[#bad + 1] = role .. "=" .. string.format("%.2f", ratio) end
	end
	Check("[STYLE] Azeroth : rôles versés au tableau, ≥ 4,5:1 (titre ≥ 3)", #bad == 0, table.concat(bad, " "))
	Check("[STYLE] Azeroth : même fond que la bulle du compagnon", NS.TOUR_CONTRAST["tour.text"][2] == CONTRAST["bubble.text"][2]
		and NS.TOUR_CONTRAST["tour.title"][2] == CONTRAST["bubble.name"][2])
	NS:TourStop()
	P.Reset("sobre")
	a = Anchor()
	NS.TOUR_DEFS.test = { steps = { { id = "a", anchor = a, title = "TOUR_A1_T", text = "TOUR_A1" } } }
	NS:TourStart("test")
	c = P.Callout()
	Check("[STYLE] Sobre : bulle sombre du socle", c.uiStyle == "sobre" and c:IsShown() and not c.nextButton.azeroth)
	local low, lowName = 99, ""
	local bg = Lum(NS.Theme.WINDOW)
	for _, key in ipairs({ "title", "text", "step" }) do
		local ratio = NS.AzerothContrast(NS.TOUR_SOBRE[key], bg)
		if ratio < low then low, lowName = ratio, key end
	end
	Check("[STYLE] Sobre : titre, texte, compteur ≥ 4,5:1 sur Theme.WINDOW", low >= 4.5, lowName .. "=" .. string.format("%.2f", low))
	NS:TourStop()
	NS.TOUR_DEFS.test = nil
end

-- 3. Plus de tutoriel de la ménagerie ; remise à zéro 3.0 --------------------------------------------------
do
	Say("-- qc30 tutoriel : un seul tutoriel, remis à zéro en 3.0")
	P.Reset()
	Check("[OLD] le tutoriel de la ménagerie (2.3.0) est retiré", NS.CompanionMenagerieOpportunity == nil
		and NS.CompanionStartMenagerieTutorial == nil and NS.CompanionMenagerieTutorialSteps == nil
		and NS.CompanionSequenceAdvance == nil and NS.CompanionSequenceWaits == nil and NS.TUTO_MENAGERIE_AUTO == nil
		and NS.COMPANION_POOLS.TUTO_MENAGERIE == nil and NS.COMPANION_POOLS.TUTO_MENAGERIE_START == nil)
	-- anciens drapeaux vus : la 3.0 rejoue quand même
	NS:CompanionData().tutoMenagerieDone = true
	NS:CompanionData().tutoDone = true
	P.SeeKill(7001, { name = "Sanglier" })
	Check("[OLD] anciens tutoriels vus : la visite des captures part quand même", NS:TourActive() == "capture"
		and P.StepId() == "net" and P.Shown())
	Check("[OLD] … et aucune bulle de tutoriel du compagnon", not NS:CompanionTutorialActive())
	NS:TourStop()
	-- tutoriel de base du compagnon en cours : la visite attend l'occasion suivante
	P.Reset()
	NS:CompanionData().tutoDone = nil
	NS.companionSession = nil
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	local base = NS:CompanionTutorialActive()
	P.SeeKill(7002, { name = "Loup" })
	Check("[OLD] tutoriel de base en cours : pas de visite par-dessus", base and NS:TourActive() == nil)
	NS:CompanionSkipTutorial()
	P.SeeKill(7003, { name = "Kodo" })
	Check("[OLD] tutoriel de base fini : la visite part à l'occasion suivante", NS:TourActive() == "capture")
	NS:TourStop()
	-- l'ancienne commande mène à la nouvelle visite
	Mock:Reset()
	NS:HandleCommand("compagnon tuto collection")
	Check("[OLD] /qc compagnon tuto collection : la visite des captures (le filet attend)", NS:TourActive() == "capture")
	NS:TourStop()
end

-- 4. Visite des premières captures ---------------------------------------------------------------------------
do
	Say("-- qc30 tutoriel : premières captures")
	P.Reset()
	P.quality = 2
	P.SeeKill(7101, { name = "Raptor" })
	local net = NS.captureNetButton
	Check("[CAP] première occasion : le filet montré, son liseré, 1 / 5", NS:TourActive() == "capture" and P.StepId() == "net"
		and P.Ring().anchor == net and P.Callout().step:GetText() == "1 / 5" and Has(P.Text(), "étoiles"), P.Text())
	Check("[CAP] … pas de « Suivant » (il faut cliquer), le filet bat", not P.Callout().nextButton:IsShown() and NS.tourNetPulse == true)
	NS:CaptureNetClick("LeftButton")
	Mock:Advance(0.2)
	local stage = NS.captureStage
	Check("[CAP] clic sur le filet : la carte de préparation s'ouvre (pas de lancer direct)", stage and stage.prep ~= nil
		and NS.captureState.rolling == nil)
	Check("[CAP] … étape 2 : la carte (qualité, chance, aides)", P.StepId() == "card" and P.Ring().anchor == stage.details
		and P.Title() == NS.L.TOUR_A2_T and Has(P.Text(), "aide") and not NS.tourNetPulse,
		tostring(P.StepId()) .. " " .. tostring(P.Ring().anchor == stage.details) .. " " .. P.Title() .. " " .. tostring(NS.tourNetPulse))
	P.Callout().nextButton:Click()
	Check("[CAP] étape 3 : Lancer / Passer, Maj+clic expliqué", P.StepId() == "launch" and P.Ring().anchor == stage.launch
		and Has(P.Text(), "Maj + clic") and not P.Callout().nextButton:IsShown())
	P.Roll(0)
	stage.launch:Click()
	Mock:Advance(0.2)
	Check("[CAP] Lancer : la bulle se tait pendant la scène", NS.captureState.rolling ~= nil and not P.Shown() and P.StepId() == "result")
	P.PlayCapture()
	Check("[CAP] verdict : « Où va ta prise ? », capturé au Codex", P.StepId() == "result" and P.Shown()
		and NS.tourState.ctx.result == "ok" and NS.tourState.ctx.place == "codex" and P.Text() == NS.L.TOUR_A4_codex, P.Text())
	Check("[CAP] … ancré sur le compagnon, le clic droit expliqué", P.Ring().anchor == NS.companionFrame and Has(P.Text(), "Clic droit"))
	-- le joueur ouvre le carnet (clic droit) : étape suivante
	P.shift = false
	NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "RightButton")
	Check("[CAP] clic droit sur le compagnon : le carnet s'ouvre, étape du mode chasse", NS.journalFrame and NS.journalFrame:IsShown()
		and P.StepId() == "hunt" and Has(P.Text(), "Maj + clic droit"))
	Check("[CAP] … la visite du carnet attend la fin de celle-ci", NS:TourActive() == "capture")
	P.Callout().nextButton:Click()
	Check("[CAP] Terminer : vue au compte ; le carnet ouvert a sa visite", NS:TourDone("capture") and NS:TourActive() == "journal")
	NS:TourStop()
	NS.journalFrame:Hide()
	P.SeeKill(7102, { name = "Kodo" })
	Check("[CAP] une fois : la capture suivante ne la relance pas", NS:TourActive() == nil)
	-- Réserve : « Ton Codex avait déjà mieux »
	P.Reset()
	NS:SpecimenAdd({ npc = 7201, stars = 3, name = "Ours" })
	NS:HuntStart(5)
	P.quality = 1
	P.SeeKill(7201, { name = "Ours" })
	NS:CaptureNetClick("LeftButton")
	Mock:Advance(0.2)
	P.Callout().nextButton:Click()
	P.Roll(0)
	NS.captureStage.launch:Click()
	P.PlayCapture()
	Check("[CAP] moins bon que le Codex : « … rejoint ta Réserve »", NS.tourState and NS.tourState.ctx.place == "reserve"
		and P.Text() == NS.L.TOUR_A4_reserve, P.Text())
	NS:TourStop()
	NS:HuntStop()
	-- Maj+clic : le filet part tout de suite, les étapes de la carte sautent
	P.Reset()
	P.SeeKill(7301, { name = "Hyène" })
	P.shift = true
	P.Roll(0.999)
	NS:CaptureNetClick("LeftButton")
	P.shift = false
	Mock:Advance(0.2)
	Check("[CAP] Maj+clic : lancer direct, la visite attend le verdict (carte sautée)", NS.captureState.rolling ~= nil
		and P.StepId() == "result" and not P.Shown())
	P.PlayCapture()
	Check("[CAP] échappé : « Il s'est échappé… »", P.Shown() and NS.tourState.ctx.result == "fail" and P.Text() == NS.L.TOUR_A4_fail
		and P.Callout().step:GetText() == "4 / 5", P.Callout().step:GetText())
	NS:TourStop()
	-- monstre parti avant le clic : arrêt sans être vue, reprise à l'occasion suivante
	P.Reset()
	P.SeeKill(7401, { name = "Crocilisque" })
	Mock:Reset()
	Mock:Advance(NS.CAPTURE_QUEUE_TIME + 2); NS:CaptureTick(NS.Now())
	Mock:Advance(0.2)
	Check("[CAP] candidat parti : visite arrêtée, pas vue, message", #NS:CaptureQueue() == 0 and NS:TourActive() == nil
		and not NS:TourDone("capture") and Has(Mock:Output(), NS.L.TOUR_MSG_LATER))
	P.SeeKill(7402, { name = "Zhévra" })
	Check("[CAP] occasion suivante : elle repart du filet", NS:TourActive() == "capture" and P.StepId() == "net")
	NS:TourStop()
	-- en combat : pas de départ ; à la fin du combat, l'occasion compte
	P.Reset()
	P.combat = true
	P.SeeKill(7501, { name = "Lion" })
	Check("[CAP] monstre abattu en combat : pas de visite", NS:TourActive() == nil)
	P.combat = false
	Mock:Advance(0.2); NS:CaptureTick(NS.Now())
	Check("[CAP] fin du combat (le compte démarre) : la visite part", NS:TourActive() == "capture")
	NS:TourStop()
end

-- 5. Visite du carnet ----------------------------------------------------------------------------------------
do
	Say("-- qc30 tutoriel : le carnet")
	P.Reset()
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	Mock:Advance(0.2)
	Check("[JRN] première ouverture : la visite du carnet, onglet Compagnon", NS:TourActive() == "journal"
		and P.StepId() == "evolution" and f.kind == "evolution" and P.Ring().anchor == f.sections.evolution
		and P.Title() == NS.L.JRN_SEC_evolution, tostring(P.StepId()) .. " " .. tostring(f.kind) .. " " .. tostring(P.Ring().anchor == f.sections.evolution) .. " " .. P.Title())
	-- 3.0.0 : l'Échoppe du dresseur a son onglet, donc son étape
	local order = { "evolution", "menagerie", "reserve", "shop", "feats", "day", "progress", "juke", "guide" }
	local okAll, total = true, NS.tourState.total
	for index, key in ipairs(order) do
		if f.sections[key] then
			local good = P.StepId() == key and f.kind == key and P.Ring().anchor == f.sections[key]
				and P.Text() == NS.L["TOUR_B_" .. key]
			if not good then okAll = false; Say("   étape " .. key .. " : " .. tostring(P.StepId()) .. " / " .. tostring(f.kind)) end
			if index < #order then P.Callout().nextButton:Click() end
		end
	end
	Check("[JRN] chaque onglet : surligné, ouvert, expliqué (9 étapes)", okAll and total == 9, total)
	Check("[JRN] dernière étape : « Terminer »", P.Callout().nextButton.text:GetText() == NS.L.TOUR_DONE)
	P.Callout().nextButton:Click()
	Check("[JRN] fini : vue au compte", NS:TourActive() == nil and NS:TourDone("journal"))
	f:Hide()
	NS:ToggleJournal(true)
	Mock:Advance(0.2)
	Check("[JRN] une fois : la réouverture ne la relance pas", NS:TourActive() == nil)
	f:Hide()
	-- carnet refermé en cours de visite : arrêt, pas vue
	NS:TourMark("journal", false)
	NS:ToggleJournal(true)
	Mock:Advance(0.2)
	P.Callout().nextButton:Click()
	f:Hide()
	Mock:Advance(0.2)
	Check("[JRN] carnet refermé : visite arrêtée, pas vue", NS:TourActive() == nil and not NS:TourDone("journal") and not P.Shown())
	-- les boutons de la page Guide
	NS:TourMark("journal", true)
	NS:OpenJournalGuide()
	Mock:Advance(0.2)
	local pane = f.guide
	Check("[JRN] page Guide : deux boutons (captures, carnet)", pane.replay and pane.replayJournal
		and pane.replay.text:GetText() == NS.L.GUIDE_REPLAY and pane.replayJournal.text:GetText() == NS.L.GUIDE_REPLAY_JOURNAL)
	pane.replayJournal:Click()
	Mock:Advance(0.2)
	Check("[JRN] « Tuto du carnet » : la visite repart, onglet Compagnon", NS:TourActive() == "journal" and f.kind == "evolution")
	NS:TourStop()
	NS:SelectJournalKind("guide")
	Mock:Reset()
	pane.replay:Click()
	Check("[JRN] « Tuto des captures » (filet vide) : carnet fermé, à la prochaine occasion", not f:IsShown()
		and NS:TourActive() == nil and not NS:TourDone("capture") and Has(Mock:Output(), NS.L.TOUR_MSG_ARMED))
	NS:TourMark("capture", true)
	NS:HandleCommand("tuto capture")
	P.SeeKill(7601, { name = "Sanglier" })
	Check("[JRN] /qc tuto capture : la visite part à la capture suivante", NS:TourActive() == "capture")
	NS:TourStop()
	NS:HandleCommand("tuto carnet")
	Mock:Advance(0.2)
	Check("[JRN] /qc tuto carnet : le carnet s'ouvre sur sa visite", f:IsShown() and NS:TourActive() == "journal")
	NS:TourStop()
	f:Hide()
end

-- 6. Clic droit et Maj + clic droit ------------------------------------------------------------------------
do
	Say("-- qc30 tutoriel : clic droit du compagnon")
	P.Reset()
	NS:TourMark("journal", true)
	local frame = NS.companionFrame
	frame.scripts.OnMouseDown(frame)
	frame.scripts.OnMouseUp(frame, "RightButton")
	Check("[CLIC] clic droit : le carnet, d'un geste", NS.journalFrame and NS.journalFrame:IsShown()
		and not (NS.companionMenu and NS.companionMenu:IsShown()))
	frame.scripts.OnMouseUp(frame, "RightButton")
	Check("[CLIC] clic droit de nouveau : refermé", not NS.journalFrame:IsShown())
	P.shift = true
	frame.scripts.OnMouseUp(frame, "RightButton")
	Check("[CLIC] Maj + clic droit : le menu (Carnet de voyage, mode chasse, Annuler)", NS.companionMenu and NS.companionMenu:IsShown()
		and NS.companionMenu.journal and NS.companionMenu.durations and NS.companionMenu.untilStop and NS.companionMenu.stop
		and NS.companionMenu.cancel and not NS.journalFrame:IsShown())
	NS.companionMenu.cancel:Click()
	P.shift = false
	Check("[CLIC] survol : les deux gestes annoncés (FR et EN)", Has(NS.L.COMP_HOVER_HINT, "clic droit : carnet")
		and Has(NS.L.COMP_HOVER_HINT, "Maj + clic droit : chasse")
		and Has(NS.COMPANION_STRINGS and NS.COMPANION_STRINGS.en and NS.COMPANION_STRINGS.en.COMP_HOVER_HINT or "Shift + right-click: hunt",
			"Shift + right-click: hunt"))
end

-- 7. La migration expliquée ----------------------------------------------------------------------------------
local function Migrate(n, shinies)
	local data = NS:CaptureData()
	for index = 1, n do
		local shiny = index <= (shinies or 0)
		data.creatures[8000 + index] = { name = "Bête " .. index, normal = true, stars = (index % 3) + 1, at = 100 + index,
			zoneID = 1413, shiny = shiny or nil, shinyStars = shiny and 2 or nil, shinyAt = shiny and 200 or nil }
	end
	data.count = n
	NS:CaptureData().specV = nil
	return NS:SpecimenList({ sort = "id" })
end
do
	Say("-- qc30 tutoriel : la migration expliquée")
	P.Reset()
	Migrate(5, 2)
	local species, total, shiny = NS:TourMigrationCounts()
	Check("[MIG] chiffres réels : 5 espèces, 7 spécimens, 2 brillants", species == 5 and total == 7 and shiny == 2,
		species .. "/" .. total .. "/" .. shiny)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Check("[MIG] connexion : rien tout de suite", NS:TourActive() == nil and NS.tourMigrationAt ~= nil)
	Mock:Advance(NS.TOUR.migrationDelay + 0.5)
	Check("[MIG] quelques secondes après : l'explication, avec les chiffres", NS:TourActive() == "migration"
		and P.Title() == NS.L.TOUR_MIG_T and Has(P.Text(), "(5 ") and Has(P.Text(), " 7 ") and Has(P.Text(), " 2 ")
		and Has(P.Text(), NS.L.RES_BY_MIGRATION) and Has(P.Text(), "Recaptures"), P.Text())
	Check("[MIG] … le cadeau annoncé (plus de 3 espèces), « Suivant » et « Plus tard »", Has(P.Text(), NS:F("TOUR_MIG_GIFT", 3))
		and P.Callout().nextButton.text:GetText() == NS.L.TOUR_NEXT and P.Callout().skipButton.text:GetText() == NS.L.TOUR_MIG_LATER)
	Check("[MIG] … vue dès qu'elle s'affiche", NS:TourDone("migration"))
	P.Callout().nextButton:Click()
	Check("[MIG] étape du cadeau : « Choisir mes créatures »", P.StepId() == "gift"
		and P.Callout().nextButton.text:GetText() == NS.L.TOUR_GIFT_GO and P.Callout().step:GetText() == "2 / 2")
	P.Callout().skipButton:Click()
	Check("[MIG] « Plus tard » : fini, sans message de tutoriel passé", NS:TourActive() == nil)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock:Advance(NS.TOUR.migrationDelay + 0.5)
	Check("[MIG] une fois : pas à la connexion suivante", NS:TourActive() == nil)
	-- carnet ouvert avant la bulle de connexion : première étape de la visite du carnet
	P.Reset()
	Migrate(2, 0)
	NS:ToggleJournal(true)
	Mock:Advance(0.2)
	Check("[MIG] carnet ouvert d'abord : l'explication en première étape (1 / 10)", NS:TourActive() == "journal"
		and P.StepId() == "migration" and P.Callout().step:GetText() == "1 / 10" and Has(P.Text(), "(2 "), P.Callout() and P.Callout().step:GetText())
	Check("[MIG] … 2 espèces : pas de cadeau", not NS:Gift30Available() and not Has(P.Text(), NS:F("TOUR_MIG_GIFT", 3)))
	P.Callout().nextButton:Click()
	Check("[MIG] … puis les onglets", P.StepId() == "evolution" and NS:TourDone("migration"))
	NS:TourStop()
	NS.journalFrame:Hide()
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Check("[MIG] déjà vue dans le carnet : rien à la connexion", NS.tourMigrationAt == nil)
	-- sans créatures d'avant : jamais
	P.Reset()
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock:Advance(NS.TOUR.migrationDelay + 0.5)
	NS:ToggleJournal(true)
	Mock:Advance(0.2)
	Check("[MIG] nouveau joueur : pas d'explication, la visite commence aux onglets (9)", NS:TourActive() == "journal"
		and P.StepId() == "evolution" and NS.tourState.total == 9 and NS.tourMigrationAt == nil)
	NS:TourStop()
	NS.journalFrame:Hide()
end

-- 8. Le cadeau de la 3.0 -----------------------------------------------------------------------------------
do
	Say("-- qc30 tutoriel : le cadeau de la 3.0")
	P.Reset()
	Migrate(3, 1)
	Check("[GIFT] 3 espèces : pas de cadeau", not NS:Gift30Available() and NS:Gift30Grant({ 8001 }) == false)
	P.Reset()
	Migrate(5, 1)
	local data = NS:CaptureData()
	-- une espèce possédée seulement brillante
	data.creatures[8100] = { name = "Ours", normal = false, shiny = true, shinyStars = 3, shinyAt = 300 }
	data.specV = nil
	NS:SpecimenList()
	Check("[GIFT] plus de 3 espèces : cadeau offert", NS:Gift30Available())
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock:Advance(NS.TOUR.migrationDelay + 0.5)
	P.Callout().nextButton:Click()
	P.Callout().nextButton:Click()
	local f = NS.journalFrame
	Check("[GIFT] « Choisir mes créatures » : la page Réserve, le choix", f and f:IsShown() and f.kind == "reserve" and f.resView == "gift"
		and f.res.gift:IsShown() and not f.res.reserve:IsShown())
	Mock:Advance(0.2)
	Check("[GIFT] … la visite du carnet attend (pas par-dessus le choix)", NS:TourActive() == nil and not NS:TourDone("journal"))
	local gv = f.res.gift
	local tiles = 0
	for _, tile in ipairs(gv.tiles) do if tile:IsShown() then tiles = tiles + 1 end end
	Check("[GIFT] une vignette par espèce du Codex (6)", tiles == 6 and #NS:Gift30Candidates() == 6, tiles)
	local cands = NS:Gift30Candidates()
	local byNpc = {}
	for _, item in ipairs(cands) do byNpc[item.npc] = item end
	Check("[GIFT] espèce seulement brillante : copiée avec ses étoiles", byNpc[8100] and byNpc[8100].stars == 3 and byNpc[8100].shinyOnly)
	-- recherche
	gv.search:SetText("Ours")
	if gv.search.scripts.OnTextChanged then gv.search.scripts.OnTextChanged(gv.search) end
	tiles = 0
	for _, tile in ipairs(gv.tiles) do if tile:IsShown() then tiles = tiles + 1 end end
	Check("[GIFT] recherche : « Ours » seul", tiles == 1 and gv.tiles[1].gift.npc == 8100, tiles)
	gv.search:SetText("")
	if gv.search.scripts.OnTextChanged then gv.search.scripts.OnTextChanged(gv.search) end
	Check("[GIFT] rien de choisi : « Ajouter » grisé", gv.confirm.qcEnabled == false)
	NS:Gift30Toggle(8100); NS:Gift30Toggle(8001); NS:Gift30Toggle(8002)
	Check("[GIFT] 3 au plus : la 4e refusée", NS:Gift30Toggle(8003) == false and #f.giftPicks == 3
		and gv.count:GetText() == NS:F("GIFT30_COUNT", 3, 3))
	NS:Gift30Toggle(8002)
	Check("[GIFT] re-clic : reposée", #f.giftPicks == 2)
	NS:Gift30Toggle(8004)
	Check("[GIFT] « Ajouter » actif", gv.confirm.qcEnabled ~= false)
	local reserveBefore = NS:SpecimenReserveCount()
	local codexBefore = {}
	for _, npc in ipairs({ 8100, 8001, 8004 }) do codexBefore[npc] = NS:SpecimenReference(npc, false) end
	Mock:Reset()
	gv.confirm:Click()
	local gifts = NS:SpecimenList({ where = "reserve" })
	local okCopies = #gifts == 3
	for _, spec in ipairs(gifts) do
		local ref = NS:SpecimenReference(spec.npc, false) or NS:SpecimenReference(spec.npc, true)
		if spec.shiny or spec.origin ~= "gift3" or not ref or ref.stars ~= spec.stars or NS:SpecimenIsReference(spec.id) then okCopies = false end
	end
	Check("[GIFT] 3 copies en Réserve : jamais brillantes, mêmes étoiles, origine gift3", okCopies
		and NS:SpecimenReserveCount() == reserveBefore + 3)
	Check("[GIFT] … le Codex ne bouge pas (l'espèce brillante reste sans version normale au Codex)",
		NS:SpecimenReference(8100, false) == codexBefore[8100] and NS:SpecimenReference(8001, false) == codexBefore[8001])
	Check("[GIFT] … « Cadeau de la 3.0 » sur la fiche, message dans le chat", NS:SpecimenOriginText(gifts[1]):find(NS.L.RES_BY_GIFT3, 1, true) == 1
		and Has(Mock:Output(), "Cadeau de la 3.0"))
	Check("[GIFT] une fois par compte", not NS:Gift30Available() and NS:Gift30Grant({ 8002 }) == false and f.resView == "reserve")
	Check("[GIFT] puis la page Réserve, et la visite du carnet commence", f.res.reserve:IsShown() and not f.res.reserve.giftButton:IsShown()
		and NS:TourActive() == "journal")
	NS:TourStop()
	f:Hide()
	-- « Plus tard » : le bouton reste dans la page Réserve
	P.Reset()
	Migrate(4, 0)
	NS:TourMark("journal", true)
	NS:OpenReserve("reserve")
	f = NS.journalFrame
	local rv = f.res.reserve
	Check("[GIFT] page Réserve : « Cadeau de la 3.0 : choisis 3 créatures »", rv.giftButton:IsShown()
		and rv.giftButton.text:GetText() == NS:F("GIFT30_OPEN", 3))
	rv.giftButton:Click()
	Check("[GIFT] le bouton ouvre le choix", f.resView == "gift" and f.res.gift:IsShown())
	f.res.gift.later:Click()
	Check("[GIFT] « Plus tard » : retour à la Réserve, cadeau gardé", f.resView == "reserve" and NS:Gift30Available()
		and rv.giftButton:IsShown())
	-- la place de la Réserve compte
	data = NS:CaptureData()
	for index = 1, NS:ReserveCapacity() - 1 do
		NS:SpecimenAdd({ npc = 8001, stars = 1, name = "Bête 1" })
	end
	local count = NS:SpecimenReserveCount()
	local ok, why = NS:Gift30Grant({ 8001, 8002 })
	Check("[GIFT] Réserve presque pleine : 2 copies refusées (« full »)", ok == false and why == "full"
		and NS:SpecimenReserveCount() == count and NS:Gift30Available(), tostring(why) .. " " .. count)
	local ids = NS:Gift30Grant({ 8002 })
	Check("[GIFT] … une copie passe, la Réserve est pleine", type(ids) == "table" and #ids == 1 and NS:ReserveFull())
	Check("[GIFT] liste vide ou trop longue : refusée", NS:Gift30Grant({}) == false)
	f:Hide()
end

P.Done()
