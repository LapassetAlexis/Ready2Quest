-- Compagnon : son cadre à l'écran et sa page du carnet.
-- 1. Fiche au survol : tout placé de haut en bas, le cadre prend la hauteur du
--    contenu (signalé en jeu en 1.1.0-beta1 : l'aide passait sous les barres).
-- 2. Réglette « Taille » : échelle du cadre seul, position recalée.
-- 3. Carnet 1.5.0 : route parcourue (CompanionTravel.lua), page Compagnon.
-- 4. QC 2.10.0 : discret en combat (bulles retenues, résumé d'après combat,
--    estompé), masqué en donjon, alerte d'aggro, raccourcis, déplacement
--    verrouillé, espèce écartée du filet, « Afficher le filet ».
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- Un scénario = une assertion ; chaque étape en défaut est nommée dans le message.
local function Scenario(name)
	local bad = {}
	return {
		ok = function(label, cond, extra)
			if not cond then bad[#bad + 1] = label .. (extra ~= nil and (" [" .. tostring(extra) .. "]") or "") end
			return cond
		end,
		done = function() Check(name, #bad == 0, table.concat(bad, " ; ")) end,
	}
end

-- 1. Fiche au survol ==============================================================================
do
	Say("-- compagnon : fiche au survol")
	local S = Scenario("[HOVER] fiche au survol")
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS:CompanionData().tutoDone = true
	NS:CompanionUpdateVisibility()
	NS:CompanionShowHover()
	local hover = NS.companionHover
	local last = hover.bars.curiosity
	S.ok("l'aide sous la dernière barre, sans la toucher", hover.hint.top < last.top - 12,
		tostring(hover.hint.top) .. " / " .. tostring(last.top))
	S.ok("les envies sous la ligne du stade", hover.bars.hunger.top < hover.sub.top)
	local short = hover.layoutHeight
	S.ok("le cadre englobe l'aide", short >= -hover.hint.top + 12, short)
	-- une ligne de stade plus longue (le caractère) : tout descend, le cadre grandit
	local saved = NS.CompanionTrait
	NS.CompanionTrait = function() return "mischievous" end
	NS:CompanionRefreshHover()
	NS.CompanionTrait = saved
	S.done()
	S = Scenario("[HOVER] ligne du stade sur deux lignes, aide plus longue : tout descend, le cadre grandit")
	S.ok("le caractère dans la ligne du stade", hover.sub:GetText():find("Espiègle", 1, true) ~= nil, hover.sub:GetText())
	local subBottom = hover.sub.top - NS.CompanionHoverTextHeight(hover.sub)
	S.ok("ligne du stade sur deux lignes : les barres descendent dessous", hover.bars.hunger.top <= subBottom - 4,
		tostring(hover.bars.hunger.top) .. " / " .. tostring(subBottom))
	S.ok("l'aide reste sous les barres", hover.hint.top < hover.bars.curiosity.top - 12)
	S.ok("une ligne plus longue : le cadre grandit, rien ne se chevauche", hover.layoutHeight >= short)
	local before = hover.layoutHeight
	hover.hint:SetText(string.rep("aide très longue ", 30))   -- 3.0.0 : l'aide réelle est plus longue (Maj + clic droit)
	NS:CompanionLayoutHover()
	S.ok("aide plus longue : le cadre grandit", hover.layoutHeight > before, hover.layoutHeight)
	hover.hint:SetText(NS.L.COMP_HOVER_HINT)
	NS:CompanionHideHover()
	ResetWorld()
	S.done()
end

-- 2. Taille =======================================================================================
do
	Say("-- compagnon : taille")
	local S = Scenario("[SIZE] taille")
	ResetWorld()
	NS.companionRT, NS.companionSession = nil, nil
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS:CompanionData().tutoDone = true
	S.ok("par défaut : Moyen (échelle 1)", NS:DB().companionSize == 2 and NS:CompanionSizeLevel() == 2)
	local frame = NS:EnsureCompanionFrame()
	S.ok("cadre à l'échelle du réglage", frame and frame:GetScale() == 1, frame and frame:GetScale())

	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companionMain")
	local row
	for _, r in ipairs(NS.optionsFrame.rows) do if r.def and r.def.key == "companionSize" then row = r end end
	S.ok("réglette « Taille » dans la page Compagnon", row and row.def.kind == "number" and row.label.text == "Taille"
		and row.value.text:find("Moyen", 1, true), row and row.value.text)
	local point = NS:DB().companionPoint
	local x, y = point.x, point.y
	row:Step(1)
	S.ok("« + » : Grand, cadre agrandi (1,3)", NS:DB().companionSize == 3 and frame:GetScale() == 1.3
		and row.value.text:find("Grand", 1, true))
	S.ok("position recalée : il reste au même endroit à l'écran", math.abs(point.x * 1.3 - x) < 0.01
		and math.abs(point.y * 1.3 - y) < 0.01, point.x .. "," .. point.y)
	row:Step(1)
	row:Step(1)
	S.ok("pas au-delà de Très grand (1,6)", NS:DB().companionSize == 4 and frame:GetScale() == 1.6)
	for _ = 1, 5 do row:Step(-1) end
	S.ok("pas en deçà de Petit (0,8)", NS:DB().companionSize == 1 and frame:GetScale() == 0.8)
	S.ok("repositionné : de retour au même endroit à l'écran", math.abs(point.x * 0.8 - x) < 0.01, point.x)

	NS:CompanionSay("EVOLVE", { force = true, args = { "X" } })
	S.done()
	S = Scenario("[SIZE] bulle à part, hors bornes, cadre créé à la taille réglée, ornements en sous-page")
	S.ok("la bulle garde sa taille", NS.companionBubble and NS.companionBubble:GetScale() == 1)
	NS:DB().companionSize = 9
	S.ok("valeur hors bornes ramenée à 4", NS:CompanionSizeLevel() == 4)
	NS:DB().companionSize = 2
	NS:CompanionApplySize()

	-- réglage déjà sur Très grand : le cadre naît à cette taille
	NS.companionFrame:Hide()
	if NS.companionBubble then NS.companionBubble:Hide() end
	NS.companionFrame, NS.companionBubble, NS.companionHover = nil, nil, nil
	NS:DB().companionSize = 4
	S.ok("cadre créé à la taille réglée (Très grand)", NS:EnsureCompanionFrame():GetScale() == 1.6)
	NS:DB().companionSize = 2
	NS:CompanionApplySize()

	local ornaments
	for _, p in ipairs(NS.OPTION_PAGES) do if p.id == "companionOrnaments" then ornaments = p end end
	S.ok("ornements dans leur sous-page", ornaments and ornaments.parent == "companion" and #ornaments.rows >= 8)
	NS.optionsFrame:Hide()
	ResetWorld()
	S.done()
end

-- 3. Route et page du carnet ======================================================================
local CP = { saved = {} }
local GLOBALS = { "UnitPosition", "C_Map", "GetLocale", "time" }
for _, name in ipairs(GLOBALS) do CP.saved[name] = rawget(_G, name) end

function CP.Reset()
	ResetWorld()
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	NS.travelLast = nil
	local data = NS:CompanionData()
	data.tutoDone, data.travel, data.since, data.missionsDone = true, 0, nil, nil
	NS:CompanionUpdateVisibility()
	CP.pos = { x = 1, y = 1, instance = 1 }
	_G.UnitPosition = function(unit)
		if unit ~= "player" or not CP.pos then return nil end
		return CP.pos.y, CP.pos.x, 0, CP.pos.instance
	end
	_G.time = function() return CP.now or 1800000000 end
end
function CP.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = CP.saved[name] end
	ResetWorld()
end

-- 1. Route parcourue -----------------------------------------------------------------------------
do
	Say("-- compagnon : route parcourue")
	local S = Scenario("[ROUTE] route parcourue")
	CP.Reset()
	S.ok("premier relevé : rien compté", NS:TravelSample(100) == 0)
	CP.pos.x = 11
	local meters = NS:TravelSample(101)
	S.ok("10 yards en 1 s : ~9,1 m", math.abs(meters - 9.144) < 0.01, meters)
	CP.pos.x = 11.2
	S.ok("presque immobile : du bruit, rien", NS:TravelSample(102) == 0)
	CP.pos.x = 5000
	S.ok("saut énorme (téléportation) : ignoré", NS:TravelSample(103) == 0)
	CP.pos.x = 5030
	S.ok("puis on repart du nouvel endroit", NS:TravelSample(104) > 0)
	CP.pos.instance = 2
	CP.pos.x = 5040
	S.ok("autre continent : rien", NS:TravelSample(105) == 0)
	CP.pos = nil
	_G.C_Map = nil
	S.ok("sans position : rien, sans erreur", NS:TravelSample(106) == 0 and NS.travelLast == nil)
	NS:CompanionData().travel = 350
	_G.GetLocale = function() return "frFR" end
	S.done()
	S = Scenario("[ROUTE] affichage m / km selon la langue ; compagnon coupé")
	S.ok("moins d'un km : en mètres", NS:TravelText() == "350 m", NS:TravelText())
	NS:CompanionData().travel = 12437
	S.ok("en km, virgule française", NS:TravelText() == "12,4 km", NS:TravelText())
	NS:CompanionData().travel = 254300
	S.ok("au-delà de 100 km : sans décimale", NS:TravelText() == "254 km", NS:TravelText())
	_G.GetLocale = function() return "enUS" end
	NS:CompanionData().travel = 12437
	S.ok("en anglais : point décimal", NS:TravelText() == "12.4 km", NS:TravelText())
	_G.GetLocale = CP.saved.GetLocale
	NS:DB().companionEnabled = false
	CP.pos = { x = 1, y = 1, instance = 1 }
	NS:TravelSample(200)
	CP.pos.x = 10
	S.ok("compagnon coupé : rien", NS:TravelSample(201) == 0)
	NS:DB().companionEnabled = true
	S.done()
end

-- 2. Page Compagnon ------------------------------------------------------------------------------
do
	Say("-- compagnon : page du carnet")
	local S = Scenario("[CPAGE] page du carnet")
	CP.Reset()
	CP.now = 1800000000
	NS:CompanionData().since = CP.now - 11 * 86400
	NS:CompanionData().missionsDone = 34
	NS:CompanionData().travel = 12437
	local capture = NS:CaptureData()
	capture.creatures[7001] = { name = "Kodo", class = "normal", zoneID = 1413, at = CP.now }
	capture.count = 1
	NS.captureAppCache = nil
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.sections.evolution:Click()
	local evo = f.evo
	S.ok("le menu : sans Souvenirs ni Zones", f.sections.evolution and f.sections.menagerie and f.sections.day
		and f.sections.memories == nil and f.sections.zones == nil and f.sections.collection == nil)
	S.ok("titre : son nom", f.header.title.text == NS:CompanionName(), f.header.title.text)
	S.ok("chiffres : captures, jours, missions, route", evo.stats.captures.value.text == "1"
		and evo.stats.days.value.text == "12" and evo.stats.missions.value.text == "34"
		and evo.stats.km.value.text:find("km", 1, true) ~= nil, evo.stats.days.value.text .. " / " .. evo.stats.km.value.text)
	S.ok("une bulle, jamais vide", (evo.bubble.text.text or "") ~= "")
	S.ok("grand portrait : caméra rapprochée (plus que l'aperçu des réglages)",
		evo.hero.portrait.camScale < NS.PORTRAIT_CAM_DISTANCE and NS:CompanionPortrait(evo.hero, 76).camScale == NS.PORTRAIT_CAM_DISTANCE,
		tostring(evo.hero.portrait.camScale))
	-- cadre et fond : jamais deux listes ouvertes l'une sur l'autre
	evo.frameStyle:Click()
	evo.bgStyle:Click()
	S.ok("cadre puis fond : la liste du cadre se referme", evo.bgStyle:IsOpen() and not evo.frameStyle:IsOpen())
	evo.bgStyle:Click()
	S.ok("envies : quatre lignes", #evo.needs == 4 and evo.needs[1].value.text:find("%%") ~= nil)
	-- 2.14.0 : plus de carrousel ; « Choisir… » ouvre le panneau (CompanionAllure.lua)
	evo.lookChoose:Click()
	local captured
	for _ = 1, 10 do
		for _, tile in ipairs(NS.allurePanel.tiles) do if tile.def and tile.def.id == "cap:7001" and tile:IsShown() then captured = tile end end
		if captured then break end
		NS:AllureScroll(1)
	end
	S.done()
	S = Scenario("[CPAGE] allure : créature capturée, son nom, confirmation")
	S.ok("allure : la créature capturée parmi les apparences", captured ~= nil)
	-- une créature capturée garde son nom ; la mascotte, le sien (1.5.2)
	NS:CompanionData().name = "Brindille"
	NS:CompanionData().appearance = "cap:7001"
	S.ok("compagnon capturé : il s'appelle Kodo, pas Brindille", NS:CompanionName() == "Kodo"
		and NS:CompanionOwnName() == "Brindille")
	NS:CompanionData().appearance = NS.COMPANION_APPEARANCES[1].id
	S.ok("retour à la mascotte : Brindille", NS:CompanionName() == "Brindille")
	captured.scripts.OnClick(captured)
	-- 2.0 : une confirmation qui compare les effets, puis « Emmener »
	S.ok("clic : confirmation demandée d'abord", NS.effectsConfirm:IsShown()
		and NS:CompanionData().appearance ~= "cap:7001")
	NS:CompanionConfirmAnswer(true)
	S.ok("clic : elle devient l'apparence portée", NS:CompanionData().appearance == "cap:7001")
	S.ok("anciennes pages redirigées : Collection -> Compagnon",
		(function() NS:SelectJournalKind("collection"); return f.kind == "evolution" end)())
	NS:AllureClose()
	f:Hide()
	-- jours ensemble sans date : depuis aujourd'hui
	NS:CompanionData().since = nil
	S.ok("compagnon d'avant : jours comptés depuis maintenant", NS:CompanionDaysTogether() >= 1)
	S.done()
end

CP.Done()

-- 4. Discret, raccourcis, déplacement, filet (2.10.0) =============================================
local D = { saved = {}, w = {} }
for _, name in ipairs({ "InCombatLockdown", "UnitAffectingCombat", "IsInInstance", "IsInGroup", "IsAltKeyDown",
	"C_Timer", "UnitIsDeadOrGhost" }) do D.saved[name] = rawget(_G, name) end

function D.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "captureQueueList", "captureNetButton" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.notifyState, NS.captureState = nil, nil, nil, nil
	NS.companionFighting, NS.companionInstanceHidden = nil, nil
	NS.companionLastBubble, NS.companionBubbleKey, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil, nil
	D.w = { combat = false, instance = false, kind = "none", group = false, alt = false, timers = {} }
	_G.InCombatLockdown = function() return D.w.combat end
	_G.UnitAffectingCombat = function() return D.w.combat end
	_G.IsInInstance = function() return D.w.instance, D.w.kind end
	_G.IsInGroup = function() return D.w.group end
	_G.IsAltKeyDown = function() return D.w.alt end
	_G.C_Timer = { After = function(delay, fn) D.w.timers[#D.w.timers + 1] = { delay = delay, fn = fn } end }
	Mock.world.level = 11
	NS:CompanionData().tutoDone = true
	NS:DB().companionChatter = 3
	NS:CompanionUpdateVisibility()
end
-- l'écart entre deux bulles oublié
function D.Free()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	if NS.companionRT then NS.companionRT.cool = {} end
end
function D.StartFight()
	D.w.combat = true
	Mock:Fire("PLAYER_REGEN_DISABLED")
end
function D.EndFight()
	D.w.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	-- (un conseil de route de fin de combat passerait devant : écarté ici)
	D.Free()
	local timers = D.w.timers
	D.w.timers = {}
	local delay
	for _, t in ipairs(timers) do delay = delay or t.delay; t.fn() end
	return delay
end
function D.Done()
	for name, fn in pairs(D.saved) do _G[name] = fn end
	NS.companionFighting = nil
	ResetWorld()
end

-- 1. Barrière de combat ---------------------------------------------------------------------
do
	Say("-- 2.10.0 : compagnon discret en combat")
	local S = Scenario("[DISCRET] compagnon discret en combat")
	D.Reset()
	D.Free()
	NS:CompanionSay("QUEST")
	S.ok("hors combat : une bulle s'ouvre", NS.companionBubbleKey == "QUEST")
	D.StartFight()
	S.ok("entrée en combat : la bulle ouverte se ferme", not (NS.companionBubble and NS.companionBubble:IsShown())
		and NS.companionBubbleUntil == nil)
	D.Free()
	local said, why = NS:CompanionSay("KILL")
	S.ok("en combat : KILL refusé (combat)", said == false and why == "combat")
	D.Free()
	S.ok("en combat : une brillante repérée passe", NS:CompanionSay("SHINY_SPOTTED", { force = true, args = { "Loup" } }) == true)
	D.Free()
	S.ok("en combat : un rare repéré passe", NS:CompanionSay("RARE_LIVE", { force = true, category = "event", args = { "Rak" } }) == true)
	S.ok("cadre estompé à 35 %", math.abs((NS.companionFrame:GetAlpha() or 1) - NS.COMPANION_COMBAT_ALPHA) < 0.01)
	-- InCombatLockdown encore faux sur PLAYER_REGEN_DISABLED : le drapeau suffit
	D.Free()
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	D.w.combat = false
	Mock:Fire("PLAYER_REGEN_DISABLED")
	S.done()
	S = Scenario("[DISCRET] drapeau de combat dès l'événement, jamais bloqué")
	S.ok("dès l'événement, avant les API : refusé", select(2, NS:CompanionSay("QUEST")) == "combat")
	Mock.now = Mock.now + NS.COMPANION_FIGHT_GRACE + 1
	D.Free()
	S.ok("drapeau jamais bloqué : les API reprennent la main", NS:CompanionSay("QUEST") == true)
	D.Done()
	S.done()
end

-- 2. Résumé d'après combat ------------------------------------------------------------------
do
	Say("-- 2.10.0 : résumé d'après combat")
	local S = Scenario("[DISCRET] résumé d'après combat")
	D.Reset()
	D.StartFight()
	for _ = 1, 3 do Mock.now = Mock.now + 3; D.Free(); NS:CompanionOnKill() end
	S.ok("trois victoires en combat : aucune bulle", not (NS.companionBubble and NS.companionBubble:IsShown()))
	local delay = D.EndFight()
	S.ok("résumé 1,5 s après la fin du combat", delay == NS.COMPANION_SUMMARY_DELAY, tostring(delay))
	S.ok("une seule bulle, COMBAT_SUM avec 3", NS.companionBubbleKey == "COMBAT_SUM"
		and NS.companionBubbleText:find("3", 1, true) ~= nil, NS.companionBubbleKey)
	S.ok("le compte est vidé", NS.companionRT.combat == nil)

	D.Reset()
	D.StartFight()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	NS:NotifyFound("Loup", 1, "bestiary")
	D.Free()
	D.EndFight()
	S.done()
	S = Scenario("[DISCRET] variantes du résumé : carnet, filet, une victoire, niveau, mort ; opacité")
	S.ok("du nouveau au carnet : COMBAT_SUM_NEW", NS.companionBubbleKey == "COMBAT_SUM_NEW", NS.companionBubbleKey)
	S.ok("… et pas de FOUND_MANY en double", (NS.notifyState and NS.notifyState.pending or 0) == 0)

	D.Reset()
	D.StartFight()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	NS:CompanionSay("CAPTURE_PROMPT", { args = { "Loup" } })
	D.Free()
	D.EndFight()
	S.ok("le filet attend : COMBAT_SUM_NET", NS.companionBubbleKey == "COMBAT_SUM_NET", NS.companionBubbleKey)

	D.Reset()
	D.StartFight()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	D.Free()
	D.EndFight()
	S.ok("une seule victoire : une ligne KILL ordinaire", NS.companionBubbleKey == "KILL", NS.companionBubbleKey)

	D.Reset()
	D.StartFight()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	NS:CompanionSay("LEVEL", { args = { 12 } })
	D.Free()
	D.EndFight()
	S.ok("un niveau en combat : annoncé après, à la place du résumé", NS.companionBubbleKey == "LEVEL", NS.companionBubbleKey)

	D.Reset()
	D.StartFight()
	NS:CompanionSay("GROUP_DEAD", { args = { "Thrall" } })
	S.ok("membre mort en combat : rien pendant", not (NS.companionBubble and NS.companionBubble:IsShown()))
	D.Free()
	D.EndFight()
	S.ok("… COMBAT_SUM_DEAD après", NS.companionBubbleKey == "COMBAT_SUM_DEAD"
		and NS.companionBubbleText:find("Thrall", 1, true) ~= nil, NS.companionBubbleKey)
	S.ok("opacité rendue après le combat", math.abs((NS.companionFrame:GetAlpha() or 0) - 1) < 0.01)

	D.Reset()
	NS:DB().companionCombatFade = false
	D.StartFight()
	S.ok("« Estomper » coupé : opacité pleine en combat", math.abs((NS.companionFrame:GetAlpha() or 0) - 1) < 0.01)
	D.EndFight()
	NS:DB().companionCombatFade = true
	D.Done()
	S.done()
end

-- 3. Masquer en donjon et en raid -----------------------------------------------------------
do
	Say("-- 2.10.0 : masqué en donjon")
	local S = Scenario("[DISCRET] masqué en donjon")
	D.Reset()
	D.w.instance, D.w.kind = true, "party"
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	S.ok("réglage coupé par défaut : visible en donjon", NS:DB().companionHideInstance == false
		and NS.companionFrame:IsShown())
	NS:DB().companionHideInstance = true
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	S.ok("donjon + réglage : caché", not NS.companionFrame:IsShown())
	D.Free()
	S.ok("… et muet (off)", select(2, NS:CompanionSay("QUEST")) == "off")
	D.w.kind = "pvp"
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	S.ok("champ de bataille : pas une instance de groupe, visible", NS.companionFrame:IsShown())
	D.w.instance, D.w.kind = false, "none"
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	S.ok("sortie : il revient", NS.companionFrame:IsShown())
	NS:DB().companionHideInstance = false
	D.Done()
	S.done()
end

-- 4. Alerte « plusieurs monstres sur toi » --------------------------------------------------
do
	Say("-- 2.10.0 : alerte d'aggro à trois crans")
	local S = Scenario("[DISCRET] alerte d'aggro à trois crans")
	D.Reset()
	local db = NS:DB()
	db.companionAggroBlink = nil
	S.ok("aggro : défaut « solo »", NS:CompanionAggroMode() == "solo")
	db.companionAggroBlink = true
	S.ok("aggro : ancienne valeur true lue « solo »", NS:CompanionAggroMode() == "solo")
	db.companionAggroBlink = false
	S.ok("aggro : ancienne valeur false lue « off »", NS:CompanionAggroMode() == "off"
		and NS:CompanionAggroAllowed() == false)
	db.companionAggroBlink = "solo"
	S.ok("aggro solo, seul dehors : oui", NS:CompanionAggroAllowed() == true)
	D.w.group = true
	S.ok("aggro solo, groupé : non", NS:CompanionAggroAllowed() == false)
	D.w.group, D.w.instance = false, true
	S.ok("aggro solo, en instance : non", NS:CompanionAggroAllowed() == false)
	db.companionAggroBlink = "always"
	D.w.group = true
	S.ok("aggro « toujours », groupé en instance : oui", NS:CompanionAggroAllowed() == true)
	local found = {}
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if page.id == "companionMain" then
			for _, row in ipairs(page.rows) do found[row.key] = row end
		end
	end
	S.done()
	S = Scenario("[DISCRET] cartes de la page Compagnon, aggro à trois crans")
	S.ok("cartes de la page Compagnon : estomper, donjon, aggro, déplacer, deux raccourcis",
		found.companionCombatFade and found.companionHideInstance and found.companionAggroBlink
		and found.companionMove and found.bindToggle and found.bindNet)
	local aggro = found.companionAggroBlink
	aggro.choose("off")
	S.ok("carte aggro : trois crans, le choix est gardé", #aggro.choices() == 3 and aggro.current() == "off"
		and db.companionAggroBlink == "off")
	db.companionAggroBlink = "solo"
	D.Done()
	S.done()
end

-- 5. Parité des chaînes ---------------------------------------------------------------------
do
	local sets = { NS.COMPANION_STRINGS, NS.BINDINGS_STRINGS, NS.CAPTURE_SKIP_STRINGS }
	local missing = {}
	for _, set in ipairs(sets) do
		if set then
			for key in pairs(set.fr) do if set.en[key] == nil then missing[#missing + 1] = key end end
			for key in pairs(set.en) do if set.fr[key] == nil then missing[#missing + 1] = key end end
		end
	end
	for _, key in ipairs({ "OPT_COMP_COMBAT_FADE", "OPT_COMP_HIDE_INSTANCE", "OPT_COMP_AGGRO", "COMP_AGGRO_solo",
		"COMP_MOVE_alt", "COMP_HOVER_HINT_alt", "COMP_MSG_SHOWN", "COMP_SAY_COMBAT_SUM", "COMP_SAY_COMBAT_SUM_3",
		"COMP_SAY_COMBAT_SUM_NEW", "COMP_SAY_COMBAT_SUM_NET", "COMP_SAY_COMBAT_SUM_DEAD", "BIND_TOGGLE", "BIND_NET",
		"OPT_BIND_TOGGLE", "OPT_BIND_NET", "CAPTURE_Q_SKIP_TIP", "OPT_CAPTURE_UNSKIP" }) do
		if NS.L[key] == key or NS.L[key] == nil then missing[#missing + 1] = key end
	end
	local lines = NS.COMPANION_LINE_STRINGS
	if not (lines and lines.en.COMP_SAY_COMBAT_SUM == "Phew! %d foes down." and lines.fr.COMP_SAY_COMBAT_SUM_DEAD ~= nil
		and lines.en.COMP_SAY_COMBAT_SUM_DEAD ~= nil) then missing[#missing + 1] = "COMP_SAY_COMBAT_SUM*" end
	Check("[DISCRET] chaînes 2.10.0 : FR et EN (réglages, raccourcis, résumé)", #missing == 0 and NS.COMPANION_STRINGS and NS.CAPTURE_SKIP_STRINGS,
		table.concat(missing, ", "))
end

-- 6. Raccourcis, commande -------------------------------------------------------------------
do
	Say("-- 2.10.0 : raccourcis du compagnon et du filet")
	local S = Scenario("[RACC] raccourcis du compagnon et du filet")
	D.Reset()
	S.ok("noms du menu Raccourcis", type(_G.BINDING_NAME_QUESTCOMPANION_TOGGLE) == "string"
		and _G.BINDING_NAME_QUESTCOMPANION_TOGGLE ~= "" and type(_G.BINDING_NAME_QUESTCOMPANION_NET) == "string"
		and _G.BINDING_NAME_QUESTCOMPANION_NET ~= "")
	S.ok("deux raccourcis de plus", NS.BINDINGS.toggle == "QUESTCOMPANION_TOGGLE" and NS.BINDINGS.net == "QUESTCOMPANION_NET")
	Mock:Reset()
	_G.QuestCompanion_ToggleCompanion()
	S.ok("afficher / masquer : caché", NS:DB().companionShow == false and not NS.companionFrame:IsShown()
		and Mock:Output():find(NS.L.MODULE_OFF, 1, true) ~= nil)
	_G.QuestCompanion_ToggleCompanion()
	S.ok("… puis réaffiché", NS:DB().companionShow == true and NS.companionFrame:IsShown())
	NS:HandleCommand("compagnon cacher")
	NS:HandleCommand("compagnon cacher")
	S.ok("/qc compagnon cacher deux fois : reste caché", NS:DB().companionShow == false)
	NS:HandleCommand("compagnon show")
	S.ok("/qc compagnon show : revenu", NS:DB().companionShow == true and NS.companionFrame:IsShown())
	-- le filet au clavier
	Mock:Reset()
	S.done()
	S = Scenario("[RACC] filet au clavier : vide, en combat")
	S.ok("filet vide : rien, et il le dit", _G.QuestCompanion_ThrowNet() == false
		and Mock:Output():find(NS.L.CAPTURE_Q_NOTHING, 1, true) ~= nil)
	D.w.combat = true
	Mock:Reset()
	S.ok("en combat : refusé", _G.QuestCompanion_ThrowNet() == false
		and Mock:Output():find(NS.L.BIND_NET_COMBAT, 1, true) ~= nil)
	D.w.combat = false
	D.Done()
	S.done()
end

-- 7. Déplacement ----------------------------------------------------------------------------
do
	Say("-- 2.10.0 : déplacer le compagnon")
	local S = Scenario("[MOVE] déplacer le compagnon")
	D.Reset()
	local db = NS:DB()
	S.ok("défaut : Alt + glisser", NS:CompanionMoveMode() == "alt")
	S.ok("alt sans Alt : non", NS:CompanionMoveAllowed() == false)
	D.w.alt = true
	S.ok("alt avec Alt : oui", NS:CompanionMoveAllowed() == true)
	db.companionMove = "locked"
	S.ok("verrouillé : jamais", NS:CompanionMoveAllowed() == false)
	db.companionMove = "free"
	D.w.alt = false
	S.ok("libre : toujours", NS:CompanionMoveAllowed() == true)
	db.companionMove = "alt"
	local frame = NS.companionFrame
	local moved = false
	frame.StartMoving = function() moved = true end
	frame.scripts.OnDragStart(frame)
	S.ok("glisser sans Alt : le cadre ne bouge pas", moved == false)
	D.w.alt = true
	frame.scripts.OnDragStart(frame)
	S.ok("Alt + glisser : il bouge", moved == true)
	S.ok("l'infobulle le dit", NS:CompanionHoverHint():find("Alt + glisser", 1, true) ~= nil)
	db.companionMove = "locked"
	S.ok("verrouillé : l'infobulle ne propose plus de glisser", NS:CompanionHoverHint():find("glisser", 1, true) == nil)
	db.companionMove = nil
	D.Done()
	S.done()
end

-- 8. Espèce écartée du filet ----------------------------------------------------------------
do
	Say("-- 2.10.0 : ne plus proposer cette espèce")
	local S = Scenario("[SKIP] ne plus proposer cette espèce")
	D.Reset()
	NS:DB().capture = nil
	-- 3.1.0 : qualité fixe au coup fatal (tirée au hasard, elle trie la file :
	-- l'ordre dépendait de l'état du générateur laissé par les modules d'avant)
	local rollQuality = NS.CaptureRollQuality
	NS.CaptureRollQuality = function() return 1 end
	NS:CaptureOffer("Creature-0-1-1-1-7001-0000000001", { zoneID = 1, npcID = 7001 })
	NS:CaptureOffer("Creature-0-1-1-1-7002-0000000002", { zoneID = 1, npcID = 7002 })
	NS.CaptureRollQuality = rollQuality
	S.ok("deux candidats dans la file", #NS:CaptureQueueState() == 2)
	NS:CaptureShowQueueList()
	local list = NS.captureQueueList
	S.ok("une croix par ligne", list and list.rows[1].skip and list.rows[1].skip:IsShown())
	Mock:Reset()
	list.rows[1].skip:Click()
	local queue = NS:CaptureQueueState()
	S.ok("croix : l'espèce sort de la file, le chat dit comment annuler", #queue == 1 and queue[1].npcID == 7002
		and Mock:Output():find("Au jour le jour", 1, true) ~= nil and NS:CaptureSkipped(7001))
	S.ok("une nouvelle mise à mort de l'espèce n'entre pas",
		NS:CaptureOffer("Creature-0-1-1-1-7001-0000000003", { zoneID = 1, npcID = 7001 }) == nil)
	NS:CaptureOffer("Creature-0-1-1-1-7001-0000000004", { zoneID = 1, npcID = 7001 }, { name = "Brillant" })
	local shinyIn
	for _, c in ipairs(NS:CaptureQueueState()) do if c.npcID == 7001 and c.shiny then shinyIn = c end end
	S.ok("… sauf en brillante", shinyIn ~= nil)
	NS:CaptureShowQueueList()
	local shinyRow
	for _, row in ipairs(list.rows) do if row.candidate == shinyIn then shinyRow = row end end
	S.ok("pas de croix sur la ligne d'une brillante", shinyRow and not shinyRow.skip:IsShown())
	S.done()
	S = Scenario("[SKIP] compte, carte « Tout reproposer »")
	S.ok("compte au compte (db.capture.skip)", NS:CaptureSkippedCount() == 1 and NS:CaptureSkippedText() == NS.L.OPT_CAPTURE_SKIPPED_ONE)
	local card
	for _, row in ipairs(NS.DAILY_OPTION_ROWS) do if row.key == "captureSkipReset" then card = row end end
	S.ok("carte « Espèces écartées du filet » sur la page Au jour le jour", card ~= nil and card.button == "OPT_CAPTURE_UNSKIP")
	NS:RunOptionAction("captureSkipReset")
	S.ok("« Tout reproposer » : l'espèce revient", not NS:CaptureSkipped(7001)
		and NS:CaptureOffer("Creature-0-1-1-1-7001-0000000005", { zoneID = 1, npcID = 7001 }) ~= nil)
	NS:CaptureHideQueueList()
	NS:CaptureQueueClear()
	D.Done()
	S.done()
end

-- 2.10.0 : « Afficher le filet », réglage indépendant du compagnon
do
	T.Say("-- qc210 : filet affiché à part")
	local S = Scenario("[NETSHOW] filet affiché à part")
	local NS = T.QNS
	local rows = 0
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		for _, row in ipairs(page.rows or {}) do if row.key == "companionNetShow" then rows = rows + 1 end end
	end
	S.ok("réglage présent, filet affiché par défaut", rows == 1 and NS:DB().companionNetShow ~= false
		and NS.L.OPT_COMP_NET_SHOW ~= nil)
	local queue = NS:CaptureQueueState()
	queue[#queue + 1] = { npcID = 99901, name = "Test", class = "normal", serial = 99901, at = NS.Now and NS.Now() or 0 }
	NS:DB().companionNetShow = false
	NS:CaptureQueueRefresh()
	local net = NS.captureNetButton
	S.ok("masqué : pas de bouton, le candidat reste dans la file", (not net or not net:IsShown()) and #NS:CaptureQueueState() >= 1)
	NS:DB().companionNetShow = true
	NS:CaptureQueueRefresh()
	S.ok("réaffiché : le bouton revient", NS.captureNetButton ~= nil and NS.captureNetButton:IsShown())
	table.remove(queue)
	NS:CaptureQueueRefresh()
	S.done()
end
