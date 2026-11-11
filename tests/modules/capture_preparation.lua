-- QuestCompanion 2.15.0 / 3.0 : la capture côté joueur. La carte de préparation
-- (CaptureStage.lua) : le clic sur le filet l'ouvre au lieu de lancer, qualité,
-- chance et écart d'une aide, aides cliquables, aide conseillée, Lancer,
-- Passer (et clic droit : ne plus proposer), Échap (le candidat reste, le
-- compte reprend), Réserve pleine ; Maj+clic, le raccourci et le réglage
-- « Lancer directement au clic » ; une aide pour tout le lot ; la pastille de
-- qualité du filet ; la réplique d'un 3 étoiles ; le menu du compagnon (mode
-- chasse) et son indicateur ; la méfiance dans l'infobulle ; les deux styles
-- et leurs contrastes.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local P = { saved = {}, random = math.random, units = {} }
P.rollQuality = NS.CaptureRollQuality
P.blocked = NS.CaptureBlockedReason
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"UnitAffectingCombat", "InCombatLockdown", "IsShiftKeyDown", "IsControlKeyDown", "UnitOnTaxi", "C_Texture", "time" }
for _, name in ipairs(GLOBALS) do P.saved[name] = rawget(_G, name) end
P.savedShiny = NS.SHINY_CHANCE
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
	_G.UnitOnTaxi = function() return w.taxi == true end
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
	ResetWorld()
	P.quality = nil
	NS.CaptureRollQuality = function() return P.quality or 1 end
	NS.CaptureBlockedReason = P.blocked
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
	P.units, P.combat, P.shift, P.taxi, P.wall = {}, false, false, false, 1800000000
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
function P.Net() return NS.captureNetButton end
function P.Stage() return NS.captureStage end
function P.Cell(id)
	for _, cell in ipairs(P.Stage().aidCells) do if cell.id == id then return cell end end
end
function P.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = P.saved[name] end
	math.random = P.random
	NS.SHINY_CHANCE = P.savedShiny
	NS.CaptureRollQuality = P.rollQuality
	NS.CaptureBlockedReason = P.blocked
	HideScenes()
	NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
	NS:DB().capture, NS.captureMergedChar = nil, nil
	ResetWorld()
end
local function Pct(x) return math.floor(x * 100 + 0.5 + 1e-9) end
local function Has(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end
local function Lum(c)
	local function lin(v) if v <= 0.03928 then return v / 12.92 end return ((v + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
end

-- 1. Le clic ouvre la carte de préparation --------------------------------------------------------------------
do
	Say("-- qc215 préparation : le clic ouvre la carte")
	P.Reset()
	P.quality = 3
	local said, say = {}, NS.CompanionSay
	NS.CompanionSay = function(self, pool, ...) said[#said + 1] = pool; return say(self, pool, ...) end
	P.SeeKill(6100, { name = "Raptor des Tarides", level = 20 })
	local candidate = NS:CaptureQueueBest()
	local function Count(pool) local n = 0; for _, p in ipairs(said) do if p == pool then n = n + 1 end end; return n end
	-- une seule fois : le même monstre ne revient pas dans la file
	NS:CaptureOffer(candidate.guid, { zoneID = 1413, npcID = 6100 })
	NS.CompanionSay = say
	Check("[PREP] un 3 étoiles au filet, la réplique du compagnon au coup fatal, une fois par candidat",
		candidate and candidate.stars == 3 and candidate.reason == "new" and #NS:CaptureQueue() == 1
		and Count("CAPTURE_GREAT") == 1, table.concat(said, ","))
	local net = P.Net()
	Check("[PREP] pastille de qualité : les étoiles du meilleur ; liste/infobulle : étoiles + raison courte",
		net.badge:IsShown() and net.badgeStars == 3
		and select(2, net.badge:GetText():gsub("auctionhouse%-icon%-favorite:", "")) == 3
		and Has(NS:CaptureQueueLine(candidate), NS.L.CAPTURE_Q_TAG_new) and Has(NS:CaptureQueueLine(candidate), "|A:"),
		net.badge:GetText())
	NS:CaptureNetClick("LeftButton")
	local stage = P.Stage()
	Check("[PREP] clic : la carte en préparation (plus haute), pas de lancer, le compte à rebours en pause", stage
		and stage:IsShown() and stage.prep == candidate and NS.captureState.rolling == nil and #NS:CaptureQueue() == 1
		and NS:CaptureQueuePaused() and stage:GetHeight() > NS.CAPTURE_STAGE_AZEROTH.h)
	Check("[PREP] … NIV. 20, qualité « Spécimen exceptionnel », Lancer et Passer, pied : Échap",
		(Has(stage.title:GetText(), "NIV. 20") or Has(stage.title:GetText(), "Niv. 20")) and stage.quality:IsShown()
		and Has(stage.quality:GetText(), NS.L.CAPTURE_PREP_Q3) and stage.launch:IsShown() and stage.pass:IsShown()
		and not stage.launch.off and (Has(stage.footer:GetText(), "Échap") or Has(stage.footer:GetText(), "Escape")),
		stage.title:GetText())
	local base = NS:CapturePrepChance(candidate)
	Check("[PREP] … « Chance 30 % » (3 étoiles : ×0,6)", Has(stage.info:GetText(), NS:F("CAPTURE_STAGE_CHANCE", Pct(base)))
		and Pct(base) == 30, stage.info:GetText())
	Check("[PREP] un second clic sur le filet la ferme", NS:CaptureNetClick("LeftButton") == nil and not stage:IsShown()
		and #NS:CaptureQueue() == 1)
end

-- 2. Aides : choix, chance en direct, aide conseillée, Lancer ---------------------------------------------------
do
	Say("-- qc215 préparation : aides et Lancer")
	P.Reset()
	P.quality = 3
	P.SeeKill(6101, { name = "Kodo", level = 20 })
	NS:CaptureGrant("appat", { quiet = true, silent = true })
	NS:CaptureGrant("lasso", { quiet = true, silent = true })
	local candidate = NS:CaptureQueueBest()
	NS:CaptureNetClick("LeftButton")
	local stage = P.Stage()
	Check("[AID] sans sifflet : le lasso est conseillé (3 étoiles)", NS:CapturePrepAdvice(candidate) == "lasso"
		and P.Cell("lasso").advised and P.Cell("lasso").glow:IsShown()
		and Has(stage.legend:GetText(), NS.L.CAPTURE_PREP_ADVICE_lasso), stage.legend:GetText())
	NS:CaptureGrant("sifflet", { quiet = true, silent = true })
	NS:CapturePrepRefresh()
	Check("[AID] un sifflet en poche : conseillé (capture assurée)", NS:CapturePrepAdvice(candidate) == "sifflet"
		and Has(stage.legend:GetText(), NS.L.CAPTURE_PREP_ADVICE_sifflet))
	P.Cell("appat").button:Click()
	local with = NS:CapturePrepChance(candidate, "appat")
	Check("[AID] clic : l'appât choisi, l'écart en direct (30 % → 45 %)", NS:CaptureState().aid == "appat"
		and Pct(with) == 45 and Has(stage.info:GetText(), "45") and Has(stage.info:GetText(), NS.L.CAPTURE_PREP_WITH_appat)
		and P.Cell("appat").chosen, stage.info:GetText())
	P.Cell("appat").button:Click()
	local cleared = NS:CaptureState().aid == nil and not Has(stage.info:GetText(), "→")
	P.Cell("sifflet").button:Click()
	local sure = Has(stage.info:GetText(), NS:F("CAPTURE_PREP_DELTA_SURE", NS.L.CAPTURE_PREP_WITH_sifflet))
	P.Cell("lasso").button:Click()
	Check("[AID] re-clic : plus d'aide ; sifflet : « capture assurée » ; une aide à la fois", cleared and sure
		and NS:CaptureState().aid == "lasso" and not P.Cell("sifflet").chosen)
	-- un monstre ordinaire (1 étoile) : rien de conseillé, la légende des aides
	Check("[AID] 1 étoile : pas d'aide conseillée", NS:CapturePrepAdvice({ stars = 1 }) == nil
		and NS:CapturePrepAdvice({ stars = 1, shiny = true }) == "sifflet")
	local before = NS:CaptureAidCount("lasso")
	stage.launch:Click()
	local rolling = NS.captureState.rolling
	Check("[LANCER] la scène part avec l'aide choisie, sur la même carte (plus en préparation, hauteur d'avant)", rolling
		and rolling.aid == "lasso" and rolling.target.npcID == 6101 and NS:CaptureAidCount("lasso") == before - 1
		and stage:IsShown() and stage.prep == nil and stage.rolling == rolling
		and not stage.launch:IsShown() and not stage.quality:IsShown() and stage:GetHeight() == NS.CAPTURE_STAGE_AZEROTH.h)
	Check("[LANCER] … le candidat a quitté le filet, la pause tient (le lancer)", #NS:CaptureQueue() == 0
		and NS.captureState.queueHolds.throw and not NS.captureState.queueHolds.prep)
	-- bêta 6 : l'aide ne sert qu'à ce lancer ; la carte suivante (3 étoiles) la
	-- conseille sans la choisir, et le lancer suivant part sans
	local s = { bad = {} }
	local function ok(label, cond, extra) if not cond then s.bad[#s.bad + 1] = label .. (extra and (" (" .. extra .. ")") or "") end end
	ok("plus d'aide choisie après le lancer", NS:CaptureState().aid == nil)
	for _ = 1, 12 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	ok("le lancer est fini", NS.captureState.rolling == nil)
	NS:CaptureGrant("lasso", { quiet = true, silent = true })
	P.SeeKill(6102, { name = "Kodo", level = 20 })
	local nextOne = NS:CaptureQueueBest()
	NS:CaptureNetClick("LeftButton")
	stage = P.Stage()
	ok("la carte suivante s'ouvre", stage:IsShown() and stage.prep == nextOne)
	local advice = NS:CapturePrepAdvice(nextOne)
	ok("… le sifflet en poche conseillé, en lueur", advice == "sifflet" and P.Cell("sifflet").advised, tostring(advice))
	ok("… rien de choisi", not P.Cell("sifflet").chosen and not P.Cell("lasso").chosen and not P.Cell("appat").chosen
		and NS:CaptureState().aid == nil)
	ok("… chance sans écart", not Has(stage.info:GetText(), "→"))
	local lassos, whistles = NS:CaptureAidCount("lasso"), NS:CaptureAidCount("sifflet")
	stage.launch:Click()
	ok("… lancée sans aide, lasso et sifflet restent en poche", NS.captureState.rolling and NS.captureState.rolling.aid == nil
		and NS:CaptureAidCount("lasso") == lassos and NS:CaptureAidCount("sifflet") == whistles)
	Check("[AID] après un lancer avec aide : plus rien de choisi ; la carte suivante conseille sans choisir, lancer sans aide",
		#s.bad == 0, table.concat(s.bad, " ; "))
end

-- 3. Passer, clic droit sur Passer, Échap -----------------------------------------------------------------
do
	Say("-- qc215 préparation : Passer et Échap")
	P.Reset()
	P.SeeKill(6201, { name = "Loup", level = 20 })
	P.SeeKill(6202, { name = "Ours", level = 20 })
	P.SeeKill(6203, { name = "Lion", level = 20 })
	local first = NS:CaptureQueueBest()
	NS:CapturePrepOpen(first)
	local stage = P.Stage()
	stage.pass:Click()
	local second = stage.prep
	Check("[PASS] Passer : retiré, la carte passe au suivant", second ~= nil and second ~= first and stage:IsShown()
		and #NS:CaptureQueue() == 2 and NS:CaptureQueuePaused())
	stage.pass:Click("RightButton")
	Check("[PASS] clic droit : « Ne plus proposer cette espèce »", NS:CaptureSkipped(second.npcID) and #NS:CaptureQueue() == 1
		and stage.prep ~= nil and stage.prep ~= second)
	local last = stage.prep
	-- Échap : la carte se ferme, le candidat reste ; le compte reprend avec le temps qui lui restait
	local expires = last.expires
	Mock:Advance(10)
	-- (Échap : UISpecialFrames cache la carte, le client joue son OnHide)
	stage:Hide()
	stage.scripts.OnHide(stage)
	Check("[ECHAP] fermée sans retirer, le compte reprend", #NS:CaptureQueue() == 1 and NS:CaptureQueueBest() == last
		and not NS:CaptureQueuePaused() and last.expires == expires + 10 and stage.prep == nil
		and stage:GetHeight() == NS.CAPTURE_STAGE_AZEROTH.h)
	NS:CapturePrepOpen()
	stage.pass:Click()
	Check("[PASS] dernier passé : la carte se ferme, file vide", not stage:IsShown() and #NS:CaptureQueue() == 0
		and not NS:CaptureQueuePaused())
	-- le candidat parti ailleurs (temps écoulé ailleurs, capturé…) : la carte suit la file
	P.SeeKill(6204, { name = "Tigre", level = 20 })
	NS:CapturePrepOpen()
	NS:CaptureQueueRemove(NS:CaptureQueueBest())
	Check("[PREP] la file se vide : la carte se ferme", not stage:IsShown())
end

-- 4. Raccourcis : Maj+clic, raccourci, réglage « Lancer directement au clic » -----------------------------------
do
	Say("-- qc215 préparation : lancer tout de suite")
	P.Reset()
	P.SeeKill(6301, { name = "Loup", level = 20 })
	P.shift = true
	NS:CaptureNetClick("LeftButton")
	Check("[DIRECT] Maj+clic : le filet part tout de suite", NS.captureState.rolling ~= nil
		and not (P.Stage() and P.Stage().prep))
	P.shift = false
	P.Reset()
	P.SeeKill(6302, { name = "Loup", level = 20 })
	NS:CaptureGrant("appat", { quiet = true, silent = true })
	NS:CaptureToggleAid("appat")
	Check("[DIRECT] raccourci : tout de suite, avec l'aide déjà choisie", NS:BindingThrowNet() == true
		and NS.captureState.rolling and NS.captureState.rolling.aid == "appat")
	P.Reset()
	P.SeeKill(6303, { name = "Loup", level = 20 })
	NS:CaptureNetClick("LeftButton")
	Check("[DIRECT] raccourci, carte ouverte : son candidat (Lancer)", P.Stage().prep ~= nil and NS:BindingThrowNet() == true
		and NS.captureState.rolling and NS.captureState.rolling.target.npcID == 6303)
	P.Reset()
	local default = NS:DB().companionCaptureDirect == false
	NS:DB().companionCaptureDirect = true
	P.SeeKill(6304, { name = "Loup", level = 20 })
	NS:CaptureNetClick("LeftButton")
	local found = false
	for _, row in ipairs(NS.DAILY_OPTION_ROWS or {}) do if row.key == "companionCaptureDirect" then found = true end end
	Check("[DIRECT] réglage « Lancer directement au clic » (coupé par défaut, sa ligne) : comme avant", default and found
		and NS.captureState.rolling ~= nil and not (P.Stage() and P.Stage().prep))
	-- le bandeau : même geste que le filet
	P.Reset()
	P.SeeKill(6305, { name = "Loup", level = 20 })
	local toast = NS.captureToast
	Check("[DIRECT] le bandeau : clic = la carte", toast and toast:IsShown() and toast.button:Click("LeftButton") ~= false
		and P.Stage() and P.Stage().prep ~= nil and NS.captureState.rolling == nil)
end

-- 5. Réserve pleine : Lancer grisé, Passer reste ----------------------------------------------------------------
do
	Say("-- qc215 préparation : Réserve pleine")
	P.Reset()
	P.SeeKill(6401, { name = "Loup", level = 20 })
	NS.CaptureBlockedReason = function() return "reserveFull" end
	NS:CaptureNetClick("LeftButton")
	local stage = P.Stage()
	Check("[FULL] le message sur la carte, Lancer grisé et refusé : rien ne part, il reste au filet", stage.prep
		and stage.launch.off and stage.prepBlocked == "reserveFull"
		and Has(stage.legend:GetText(), NS:F("CAPTURE_PREP_BLOCKED", NS:SpecimenReserveCount(), NS:ReserveCapacity()))
		and NS:CapturePrepLaunch() == false and NS.captureState.rolling == nil and #NS:CaptureQueue() == 1 and stage.prep ~= nil)
	stage.pass:Click()
	Check("[FULL] Passer reste possible", #NS:CaptureQueue() == 0 and not stage:IsShown())
	NS.CaptureBlockedReason = P.blocked
end

-- 6. « Tout capturer » : une aide pour tout le lot --------------------------------------------------------------
do
	Say("-- qc215 préparation : une aide pour le lot")
	P.Reset()
	P.SeeKill(6501, { name = "Loup", level = 20 })
	P.SeeKill(6502, { name = "Ours", level = 20 })
	P.SeeKill(6503, { name = "Lion", level = 20 })
	NS:CaptureGrant("lasso", { quiet = true, silent = true })
	NS:CaptureGrant("lasso", { quiet = true, silent = true })
	NS:CaptureNetClick("LeftButton")
	local chooser = NS.captureChooser
	chooser.aids[2]:Click()
	Check("[LOT] le choix : trois aides, une choisie pour tout le lot", chooser and chooser:IsShown() and #chooser.aids == 3
		and NS:CaptureState().aid == "lasso" and chooser.aids[2].shown == 2)
	P.Roll(0.99)
	chooser.all:Click()
	math.random = P.random
	local batch = NS.captureBatch
	local used = 0
	for _, result in ipairs(batch and batch.results or {}) do if result.aid == "lasso" then used = used + 1 end end
	Check("[LOT] chaque essai la dépense, tant qu'il en reste", batch and used == 2 and batch.short == true
		and NS:CaptureAidCount("lasso") == 0 and #NS:CaptureQueue() == 1)
	if NS.CaptureBatchStop then NS:CaptureBatchStop(true) end
	-- « Capturer : <le meilleur> » ouvre la carte de préparation
	P.Reset()
	P.SeeKill(6511, { name = "Loup", level = 20 })
	P.SeeKill(6512, { name = "Ours", level = 20 })
	NS:CaptureNetClick("LeftButton")
	NS.captureChooser.single:Click()
	Check("[LOT] « Capturer : … » : la carte de préparation", P.Stage() and P.Stage().prep ~= nil and NS.captureState.rolling == nil
		and not NS.captureChooser:IsShown() and NS:CaptureQueuePaused())
	if NS.CaptureBatchStop then NS:CaptureBatchStop(true) end
end

-- 7. Mode chasse : menu du compagnon, indicateur, méfiance ------------------------------------------------------
do
	Say("-- qc215 préparation : mode chasse")
	P.Reset()
	local frame = NS.companionFrame
	-- 3.0.0 : clic droit seul = le carnet ; Maj + clic droit = le menu
	frame.scripts.OnMouseDown(frame)
	frame.scripts.OnMouseUp(frame, "RightButton")
	Check("[HUNT] clic droit seul : le carnet, pas le menu", NS.journalFrame and NS.journalFrame:IsShown()
		and not (NS.companionMenu and NS.companionMenu:IsShown()))
	NS.journalFrame:Hide()
	P.shift = true
	frame.scripts.OnMouseUp(frame, "RightButton")
	P.shift = false
	local menu = NS.companionMenu
	Check("[HUNT] Maj + clic droit : le menu (carnet, mode chasse) ; l'indicateur le dit", menu and menu:IsShown()
		and menu.journal ~= nil and Has(NS.L.COMP_HUNT_TIP_HINT, "Maj + clic droit"))
	local minutes = {}
	for index, button in ipairs(menu.durations) do minutes[index] = button.minutes end
	Check("[HUNT] 5 min / 15 min / 30 min / 1 h, jusqu'à l'arrêt, arrêter", table.concat(minutes, ",") == "5,15,30,60"
		and menu.untilStop and menu.stop and menu.stop.off == true and menu.durations[4].text:GetText() == NS.L.COMP_MENU_HOUR)
	menu.durations[2]:Click()
	Check("[HUNT] 15 min : la chasse est lancée, le menu se ferme", NS:HuntActive() and NS:HuntRemaining() == 900
		and not menu:IsShown())
	local badge = frame.huntBadge
	Check("[HUNT] l'indicateur sur le cadre : l'icône et le temps", badge and badge:IsShown()
		and badge.icon:GetTexture() == NS.COMPANION_HUNT_BADGE.icon and Has(badge.text:GetText(), "15"), badge and badge.text:GetText())
	P.wall = P.wall + 180
	NS:CompanionHuntBadge()
	local minutesShown = Has(badge.text:GetText(), "12")
	P.taxi = true
	NS:CompanionHuntBadge()
	Check("[HUNT] … suit les minutes, caché en vol", minutesShown and not badge:IsShown(), badge.text:GetText())
	P.taxi = false
	NS:CompanionHuntBadge()
	-- méfiance : deux captures de la même espèce aujourd'hui
	NS:CaptureWaryNote(6601)
	NS:CaptureWaryNote(6601)
	local wary = NS:BestiaryTooltipWary(P.Guid(6601))
	Check("[HUNT] infobulle : « Méfiant · 2 captures aujourd'hui (−30 %) », rien pour une espèce pas encore prise",
		wary == NS:F("CAPTURE_WARY", 2, 30) and NS:BestiaryTooltipWary(P.Guid(6602)) == nil, wary)
	NS:CompanionMenuShow()
	Check("[HUNT] en chasse : « Arrêter la chasse » actif", not menu.stop.off and Has(menu.huntStatus:GetText(), "12"))
	menu.untilStop:Click()
	Check("[HUNT] jusqu'à l'arrêt : l'icône seule", NS:HuntRemaining() == -1 and badge:IsShown() and badge.text:GetText() == "")
	NS:CompanionMenuShow()
	menu.stop:Click()
	Check("[HUNT] arrêter : plus de chasse, plus d'indicateur, plus de ligne de méfiance", not NS:HuntActive()
		and not badge:IsShown() and NS:BestiaryTooltipWary(P.Guid(6601)) == nil)
	NS:CompanionMenuShow()
	NS:CompanionMenuToggle()
	Check("[HUNT] second Maj + clic droit : le menu se ferme", not menu:IsShown())
end

-- 8. Les deux styles, et les contrastes ---------------------------------------------------------------------
do
	Say("-- qc215 préparation : styles et contrastes")
	local INK, CONTRAST = NS.AZEROTH_INK, NS.AZEROTH_CONTRAST
	local bad = {}
	for role, entry in pairs(NS.CAPTURE_PREP_CONTRAST) do
		local ratio = NS.AzerothContrast(INK[entry[1]], entry[2])
		if CONTRAST[role] ~= entry or ratio < entry[3] or entry[3] < 4.5 then bad[#bad + 1] = role .. "=" .. string.format("%.2f", ratio) end
	end
	Check("[STYLE] Azeroth : rôles mesurés, versés au tableau, ≥ 4,5:1", #bad == 0, table.concat(bad, " "))
	P.Reset()
	P.quality = 3
	P.SeeKill(6701, { name = "Raptor", level = 20 })
	NS:CaptureGrant("appat", { quiet = true, silent = true })
	NS:CaptureNetClick("LeftButton")
	local stage = P.Stage()
	local inked = stage.azeroth and stage.quality.azRole == "stage.prepQuality"
		and stage.info.azRole == "stage.prepChance" and stage.legend.azRole == "stage.prepQuality"
		and stage.footer.azRole == "stage.prepHint" and stage.launch.azeroth
	NS:CapturePrepClose()
	Check("[STYLE] Azeroth : la carte de parchemin, encres mesurées ; refermée : l'encre du pied d'avant", inked
		and stage.footer.azRole == "stage.status")
	P.Reset("sobre")
	P.quality = 2
	P.SeeKill(6702, { name = "Raptor", level = 20 })
	NS:CaptureNetClick("LeftButton")
	stage = P.Stage()
	Check("[STYLE] Sobre : même carte sur le fond sombre", stage and not stage.azeroth and stage.prep ~= nil
		and stage:GetHeight() > NS.CAPTURE_STAGE_SOBRE.h
		and Has(stage.quality:GetText(), NS.L.CAPTURE_PREP_Q2) and stage.launch:IsShown())
	local low, lowName = 99, ""
	local bg = Lum(NS.Theme.WINDOW)
	for name, color in pairs(NS.CAPTURE_PREP_SOBRE) do
		local ratio = NS.AzerothContrast(color, bg)
		if ratio < low then low, lowName = ratio, name end
	end
	Check("[STYLE] Sobre : couleurs ≥ 4,5:1 sur Theme.WINDOW", low >= 4.5, lowName .. "=" .. string.format("%.2f", low))
	NS:CapturePrepClose()
end

P.Done()
