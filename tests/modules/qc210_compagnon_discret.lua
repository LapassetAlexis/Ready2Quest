-- QC 2.10.0 : compagnon discret en combat (fiche 04) ; raccourcis du
-- compagnon et du filet, déplacement verrouillé, espèce écartée (fiche 11).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

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
	D.Reset()
	D.Free()
	NS:CompanionSay("QUEST")
	Check("[DISCRET] hors combat : une bulle s'ouvre", NS.companionBubbleKey == "QUEST")
	D.StartFight()
	Check("[DISCRET] entrée en combat : la bulle ouverte se ferme", not (NS.companionBubble and NS.companionBubble:IsShown())
		and NS.companionBubbleUntil == nil)
	D.Free()
	local said, why = NS:CompanionSay("KILL")
	Check("[DISCRET] en combat : KILL refusé (combat)", said == false and why == "combat")
	D.Free()
	Check("[DISCRET] en combat : une brillante repérée passe", NS:CompanionSay("SHINY_SPOTTED", { force = true, args = { "Loup" } }) == true)
	D.Free()
	Check("[DISCRET] en combat : un rare repéré passe", NS:CompanionSay("RARE_LIVE", { force = true, category = "event", args = { "Rak" } }) == true)
	Check("[DISCRET] cadre estompé à 35 %", math.abs((NS.companionFrame:GetAlpha() or 1) - NS.COMPANION_COMBAT_ALPHA) < 0.01)
	-- InCombatLockdown encore faux sur PLAYER_REGEN_DISABLED : le drapeau suffit
	D.Free()
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	D.w.combat = false
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Check("[DISCRET] dès l'événement, avant les API : refusé", select(2, NS:CompanionSay("QUEST")) == "combat")
	Mock.now = Mock.now + NS.COMPANION_FIGHT_GRACE + 1
	D.Free()
	Check("[DISCRET] drapeau jamais bloqué : les API reprennent la main", NS:CompanionSay("QUEST") == true)
	D.Done()
end

-- 2. Résumé d'après combat ------------------------------------------------------------------
do
	Say("-- 2.10.0 : résumé d'après combat")
	D.Reset()
	D.StartFight()
	for _ = 1, 3 do Mock.now = Mock.now + 3; D.Free(); NS:CompanionOnKill() end
	Check("[DISCRET] trois victoires en combat : aucune bulle", not (NS.companionBubble and NS.companionBubble:IsShown()))
	local delay = D.EndFight()
	Check("[DISCRET] résumé 1,5 s après la fin du combat", delay == NS.COMPANION_SUMMARY_DELAY, tostring(delay))
	Check("[DISCRET] une seule bulle, COMBAT_SUM avec 3", NS.companionBubbleKey == "COMBAT_SUM"
		and NS.companionBubbleText:find("3", 1, true) ~= nil, NS.companionBubbleKey)
	Check("[DISCRET] le compte est vidé", NS.companionRT.combat == nil)

	D.Reset()
	D.StartFight()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	NS:NotifyFound("Loup", 1, "bestiary")
	D.Free()
	D.EndFight()
	Check("[DISCRET] du nouveau au carnet : COMBAT_SUM_NEW", NS.companionBubbleKey == "COMBAT_SUM_NEW", NS.companionBubbleKey)
	Check("[DISCRET] … et pas de FOUND_MANY en double", (NS.notifyState and NS.notifyState.pending or 0) == 0)

	D.Reset()
	D.StartFight()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	NS:CompanionSay("CAPTURE_PROMPT", { args = { "Loup" } })
	D.Free()
	D.EndFight()
	Check("[DISCRET] le filet attend : COMBAT_SUM_NET", NS.companionBubbleKey == "COMBAT_SUM_NET", NS.companionBubbleKey)

	D.Reset()
	D.StartFight()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	D.Free()
	D.EndFight()
	Check("[DISCRET] une seule victoire : une ligne KILL ordinaire", NS.companionBubbleKey == "KILL", NS.companionBubbleKey)

	D.Reset()
	D.StartFight()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	Mock.now = Mock.now + 3; NS:CompanionOnKill()
	NS:CompanionSay("LEVEL", { args = { 12 } })
	D.Free()
	D.EndFight()
	Check("[DISCRET] un niveau en combat : annoncé après, à la place du résumé", NS.companionBubbleKey == "LEVEL", NS.companionBubbleKey)

	D.Reset()
	D.StartFight()
	NS:CompanionSay("GROUP_DEAD", { args = { "Thrall" } })
	Check("[DISCRET] membre mort en combat : rien pendant", not (NS.companionBubble and NS.companionBubble:IsShown()))
	D.Free()
	D.EndFight()
	Check("[DISCRET] … COMBAT_SUM_DEAD après", NS.companionBubbleKey == "COMBAT_SUM_DEAD"
		and NS.companionBubbleText:find("Thrall", 1, true) ~= nil, NS.companionBubbleKey)
	Check("[DISCRET] opacité rendue après le combat", math.abs((NS.companionFrame:GetAlpha() or 0) - 1) < 0.01)

	D.Reset()
	NS:DB().companionCombatFade = false
	D.StartFight()
	Check("[DISCRET] « Estomper » coupé : opacité pleine en combat", math.abs((NS.companionFrame:GetAlpha() or 0) - 1) < 0.01)
	D.EndFight()
	NS:DB().companionCombatFade = true
	D.Done()
end

-- 3. Masquer en donjon et en raid -----------------------------------------------------------
do
	Say("-- 2.10.0 : masqué en donjon")
	D.Reset()
	D.w.instance, D.w.kind = true, "party"
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	Check("[DISCRET] réglage coupé par défaut : visible en donjon", NS:DB().companionHideInstance == false
		and NS.companionFrame:IsShown())
	NS:DB().companionHideInstance = true
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	Check("[DISCRET] donjon + réglage : caché", not NS.companionFrame:IsShown())
	D.Free()
	Check("[DISCRET] … et muet (off)", select(2, NS:CompanionSay("QUEST")) == "off")
	D.w.kind = "pvp"
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	Check("[DISCRET] champ de bataille : pas une instance de groupe, visible", NS.companionFrame:IsShown())
	D.w.instance, D.w.kind = false, "none"
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
	Check("[DISCRET] sortie : il revient", NS.companionFrame:IsShown())
	NS:DB().companionHideInstance = false
	D.Done()
end

-- 4. Alerte « plusieurs monstres sur toi » --------------------------------------------------
do
	Say("-- 2.10.0 : alerte d'aggro à trois crans")
	D.Reset()
	local db = NS:DB()
	db.companionAggroBlink = nil
	Check("[DISCRET] aggro : défaut « solo »", NS:CompanionAggroMode() == "solo")
	db.companionAggroBlink = true
	Check("[DISCRET] aggro : ancienne valeur true lue « solo »", NS:CompanionAggroMode() == "solo")
	db.companionAggroBlink = false
	Check("[DISCRET] aggro : ancienne valeur false lue « off »", NS:CompanionAggroMode() == "off"
		and NS:CompanionAggroAllowed() == false)
	db.companionAggroBlink = "solo"
	Check("[DISCRET] aggro solo, seul dehors : oui", NS:CompanionAggroAllowed() == true)
	D.w.group = true
	Check("[DISCRET] aggro solo, groupé : non", NS:CompanionAggroAllowed() == false)
	D.w.group, D.w.instance = false, true
	Check("[DISCRET] aggro solo, en instance : non", NS:CompanionAggroAllowed() == false)
	db.companionAggroBlink = "always"
	D.w.group = true
	Check("[DISCRET] aggro « toujours », groupé en instance : oui", NS:CompanionAggroAllowed() == true)
	local found = {}
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if page.id == "companionMain" then
			for _, row in ipairs(page.rows) do found[row.key] = row end
		end
	end
	Check("[DISCRET] cartes de la page Compagnon : estomper, donjon, aggro, déplacer, deux raccourcis",
		found.companionCombatFade and found.companionHideInstance and found.companionAggroBlink
		and found.companionMove and found.bindToggle and found.bindNet)
	local aggro = found.companionAggroBlink
	aggro.choose("off")
	Check("[DISCRET] carte aggro : trois crans, le choix est gardé", #aggro.choices() == 3 and aggro.current() == "off"
		and db.companionAggroBlink == "off")
	db.companionAggroBlink = "solo"
	D.Done()
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
	Check("[DISCRET] chaînes 2.10.0 : FR et EN", #missing == 0 and NS.COMPANION_STRINGS and NS.CAPTURE_SKIP_STRINGS,
		table.concat(missing, ", "))
	local lines = NS.COMPANION_LINE_STRINGS
	Check("[DISCRET] résumé : répliques FR / EN", lines and lines.en.COMP_SAY_COMBAT_SUM == "Phew! %d foes down."
		and lines.fr.COMP_SAY_COMBAT_SUM_DEAD ~= nil and lines.en.COMP_SAY_COMBAT_SUM_DEAD ~= nil)
end

-- 6. Raccourcis, commande -------------------------------------------------------------------
do
	Say("-- 2.10.0 : raccourcis du compagnon et du filet")
	D.Reset()
	Check("[RACC] noms du menu Raccourcis", type(_G.BINDING_NAME_QUESTCOMPANION_TOGGLE) == "string"
		and _G.BINDING_NAME_QUESTCOMPANION_TOGGLE ~= "" and type(_G.BINDING_NAME_QUESTCOMPANION_NET) == "string"
		and _G.BINDING_NAME_QUESTCOMPANION_NET ~= "")
	Check("[RACC] deux raccourcis de plus", NS.BINDINGS.toggle == "QUESTCOMPANION_TOGGLE" and NS.BINDINGS.net == "QUESTCOMPANION_NET")
	Mock:Reset()
	_G.QuestCompanion_ToggleCompanion()
	Check("[RACC] afficher / masquer : caché", NS:DB().companionShow == false and not NS.companionFrame:IsShown()
		and Mock:Output():find(NS.L.MODULE_OFF, 1, true) ~= nil)
	_G.QuestCompanion_ToggleCompanion()
	Check("[RACC] … puis réaffiché", NS:DB().companionShow == true and NS.companionFrame:IsShown())
	NS:HandleCommand("compagnon cacher")
	NS:HandleCommand("compagnon cacher")
	Check("[RACC] /qc compagnon cacher deux fois : reste caché", NS:DB().companionShow == false)
	NS:HandleCommand("compagnon show")
	Check("[RACC] /qc compagnon show : revenu", NS:DB().companionShow == true and NS.companionFrame:IsShown())
	Check("[RACC] l'aide nomme cacher et montrer", NS.L.HELP_COMPANION:find("cacher | montrer", 1, true) ~= nil)
	-- le filet au clavier
	Mock:Reset()
	Check("[RACC] filet vide : rien, et il le dit", _G.QuestCompanion_ThrowNet() == false
		and Mock:Output():find(NS.L.CAPTURE_Q_NOTHING, 1, true) ~= nil)
	D.w.combat = true
	Mock:Reset()
	Check("[RACC] en combat : refusé", _G.QuestCompanion_ThrowNet() == false
		and Mock:Output():find(NS.L.BIND_NET_COMBAT, 1, true) ~= nil)
	D.w.combat = false
	D.Done()
end

-- 7. Déplacement ----------------------------------------------------------------------------
do
	Say("-- 2.10.0 : déplacer le compagnon")
	D.Reset()
	local db = NS:DB()
	Check("[MOVE] défaut : Alt + glisser", NS:CompanionMoveMode() == "alt")
	Check("[MOVE] alt sans Alt : non", NS:CompanionMoveAllowed() == false)
	D.w.alt = true
	Check("[MOVE] alt avec Alt : oui", NS:CompanionMoveAllowed() == true)
	db.companionMove = "locked"
	Check("[MOVE] verrouillé : jamais", NS:CompanionMoveAllowed() == false)
	db.companionMove = "free"
	D.w.alt = false
	Check("[MOVE] libre : toujours", NS:CompanionMoveAllowed() == true)
	db.companionMove = "alt"
	local frame = NS.companionFrame
	local moved = false
	frame.StartMoving = function() moved = true end
	frame.scripts.OnDragStart(frame)
	Check("[MOVE] glisser sans Alt : le cadre ne bouge pas", moved == false)
	D.w.alt = true
	frame.scripts.OnDragStart(frame)
	Check("[MOVE] Alt + glisser : il bouge", moved == true)
	Check("[MOVE] l'infobulle le dit", NS:CompanionHoverHint():find("Alt + glisser", 1, true) ~= nil)
	db.companionMove = "locked"
	Check("[MOVE] verrouillé : l'infobulle ne propose plus de glisser", NS:CompanionHoverHint():find("glisser", 1, true) == nil)
	db.companionMove = nil
	D.Done()
end

-- 8. Espèce écartée du filet ----------------------------------------------------------------
do
	Say("-- 2.10.0 : ne plus proposer cette espèce")
	D.Reset()
	NS:DB().capture = nil
	-- 3.1.0 : qualité fixe au coup fatal (tirée au hasard, elle trie la file :
	-- l'ordre dépendait de l'état du générateur laissé par les modules d'avant)
	local rollQuality = NS.CaptureRollQuality
	NS.CaptureRollQuality = function() return 1 end
	NS:CaptureOffer("Creature-0-1-1-1-7001-0000000001", { zoneID = 1, npcID = 7001 })
	NS:CaptureOffer("Creature-0-1-1-1-7002-0000000002", { zoneID = 1, npcID = 7002 })
	NS.CaptureRollQuality = rollQuality
	Check("[SKIP] deux candidats dans la file", #NS:CaptureQueueState() == 2)
	NS:CaptureShowQueueList()
	local list = NS.captureQueueList
	Check("[SKIP] une croix par ligne", list and list.rows[1].skip and list.rows[1].skip:IsShown())
	Mock:Reset()
	list.rows[1].skip:Click()
	local queue = NS:CaptureQueueState()
	Check("[SKIP] croix : l'espèce sort de la file, le chat dit comment annuler", #queue == 1 and queue[1].npcID == 7002
		and Mock:Output():find("Au jour le jour", 1, true) ~= nil and NS:CaptureSkipped(7001))
	Check("[SKIP] une nouvelle mise à mort de l'espèce n'entre pas",
		NS:CaptureOffer("Creature-0-1-1-1-7001-0000000003", { zoneID = 1, npcID = 7001 }) == nil)
	NS:CaptureOffer("Creature-0-1-1-1-7001-0000000004", { zoneID = 1, npcID = 7001 }, { name = "Brillant" })
	local shinyIn
	for _, c in ipairs(NS:CaptureQueueState()) do if c.npcID == 7001 and c.shiny then shinyIn = c end end
	Check("[SKIP] … sauf en brillante", shinyIn ~= nil)
	NS:CaptureShowQueueList()
	local shinyRow
	for _, row in ipairs(list.rows) do if row.candidate == shinyIn then shinyRow = row end end
	Check("[SKIP] pas de croix sur la ligne d'une brillante", shinyRow and not shinyRow.skip:IsShown())
	Check("[SKIP] compte au compte (db.capture.skip)", NS:CaptureSkippedCount() == 1 and NS:CaptureSkippedText() == NS.L.OPT_CAPTURE_SKIPPED_ONE)
	local card
	for _, row in ipairs(NS.DAILY_OPTION_ROWS) do if row.key == "captureSkipReset" then card = row end end
	Check("[SKIP] carte « Espèces écartées du filet » sur la page Au jour le jour", card ~= nil and card.button == "OPT_CAPTURE_UNSKIP")
	NS:RunOptionAction("captureSkipReset")
	Check("[SKIP] « Tout reproposer » : l'espèce revient", not NS:CaptureSkipped(7001)
		and NS:CaptureOffer("Creature-0-1-1-1-7001-0000000005", { zoneID = 1, npcID = 7001 }) ~= nil)
	NS:CaptureHideQueueList()
	NS:CaptureQueueClear()
	D.Done()
end

-- 2.10.0 : « Afficher le filet », réglage indépendant du compagnon
do
	T.Say("-- qc210 : filet affiché à part")
	local NS = T.QNS
	local rows = 0
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		for _, row in ipairs(page.rows or {}) do if row.key == "companionNetShow" then rows = rows + 1 end end
	end
	T.Check("[NETSHOW] réglage présent, filet affiché par défaut", rows == 1 and NS:DB().companionNetShow ~= false
		and NS.L.OPT_COMP_NET_SHOW ~= nil)
	local queue = NS:CaptureQueueState()
	queue[#queue + 1] = { npcID = 99901, name = "Test", class = "normal", serial = 99901, at = NS.Now and NS.Now() or 0 }
	NS:DB().companionNetShow = false
	NS:CaptureQueueRefresh()
	local net = NS.captureNetButton
	T.Check("[NETSHOW] masqué : pas de bouton, le candidat reste dans la file", (not net or not net:IsShown()) and #NS:CaptureQueueState() >= 1)
	NS:DB().companionNetShow = true
	NS:CaptureQueueRefresh()
	T.Check("[NETSHOW] réaffiché : le bouton revient", NS.captureNetButton ~= nil and NS.captureNetButton:IsShown())
	table.remove(queue)
	NS:CaptureQueueRefresh()
end
