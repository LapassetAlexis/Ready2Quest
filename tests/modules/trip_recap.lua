-- QuestCompanion 3.7.0, étape 3, chantier S3 : accueil du jour et bilan de
-- sortie (TripRecap.lua).
--   1. Bonjour : le haut fait proche (titre, haut fait, unité inconnue), rien
--      de proche (la réplique d'avant), le repos garde la priorité, jamais un
--      secret ni une ligne en attente, une seule bulle.
--   2. Bulle d'objectif : le haut fait suivi, sinon le plus proche, dans le
--      créneau existant (pas de bulle en plus), coupée en mode discret.
--   3. Sortie sans Ready2Quest : 19 minutes, 4 captures, les deux seuils,
--      combat (le bandeau attend), deux retours de suite, mode discret,
--      rechargement en pleine sortie, temps hors ligne.
--   4. Sortie avec Ready2Quest : DEPARTURE / RETURN, la zone de repos ne
--      coupe pas une sortie qu'il finira, relais après un rechargement.
--   5. Le bandeau et « Détail » : textes, 6 secondes, bouton, page du carnet.
--   6. Lignes de chat : défaut, choix antérieur gardé, réglage, trois familles.
--   7. Contrastes, couleurs du thème, aucun glyphe.
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

local GLOBALS = { "time", "InCombatLockdown", "UnitAffectingCombat", "IsResting", "UnitSex", "date" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end
local savedDormant, savedBridge, savedNearest = NS.featsDormant, NS.r2qBridge, NS.FeatNearest
local savedStudyDormant, savedRested = NS.studyDormant, NS.companionRestedDormant
local savedSay, savedPrint = NS.CompanionSay, NS.Print

local W = { now = 1800000000, combat = false, resting = true, says = {}, printed = {} }
local R = NS.TRIP_RECAP

local function Fresh()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "journalToast", "featPill" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache, NS.errors = {}, {}
	NS.companionSession, NS.companionLastBubble, NS.companionBubbleKey, NS.companionBubbleText = nil, nil, nil, nil
	NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleLine, NS.companionRT = nil, nil, nil, nil
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	NS.featPills, NS.featPillHideAt = {}, nil
	if NS.bannerLane then NS.bannerLane.showing, NS.bannerLane.frame, NS.bannerLane.waiting = nil, nil, {} end
	W.now, W.combat, W.resting, W.says, W.printed = 1800000000, false, true, {}, {}
	_G.time = function() return W.now end
	_G.InCombatLockdown = function() return W.combat end
	_G.UnitAffectingCombat = function() return W.combat end
	_G.IsResting = function() return W.resting end
	_G.UnitSex = function() return 2 end
	NS.featsDormant = true
	NS.r2qBridge = nil
	NS.FeatNearest = savedNearest
	NS.tripResting, NS.tripSession = nil, nil
	NS.CompanionSay = function(self, pool, opts, ...)
		W.says[#W.says + 1] = { pool = pool, opts = opts }
		return savedSay(self, pool, opts, ...)
	end
	NS.Print = function(_, text) W.printed[#W.printed + 1] = tostring(text) end
	local char = NS:CharData()
	char.trip, char.tripLast = nil, nil
	local db = NS:DB()
	db.quiet, db.companionStyle, db.winterVeil, db.journalTracker = false, "azeroth", "off", false
	NS:CompanionData().tutoDone = true
	NS:ApplyUIStyle()
end

local function Done()
	for _, field in ipairs({ "companionFrame", "companionBubble", "journalFrame", "journalToast" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
	NS.featsDormant, NS.r2qBridge, NS.FeatNearest = savedDormant, savedBridge, savedNearest
	NS.studyDormant, NS.companionRestedDormant = savedStudyDormant, savedRested
	NS.CompanionSay, NS.Print = savedSay, savedPrint
	NS.journalToasts, NS.journalToastHideAt = {}, nil
	ResetWorld()
	NS.uiStyleCache = {}
end

local function Minutes(n) W.now = W.now + n * 60 end
local npcSerial = 70000
-- n captures (dont `species` espèces nouvelles, `shiny` brillantes) : les
-- compteurs que l'addon tient déjà (capture.caught, la collection, les spécimens)
local function Capture(n, opts)
	opts = opts or {}
	local capture = NS:CaptureData()
	if type(capture.specimens) ~= "table" then capture.specimens = {} end
	if type(capture.creatures) ~= "table" then capture.creatures = {} end
	for index = 1, n do
		npcSerial = npcSerial + 1
		local npc = index <= (opts.species or 0) and npcSerial or 69999
		capture.creatures[npc] = capture.creatures[npc] or { name = "Bête " .. npc, normal = true, stars = 1, class = "normal" }
		capture.caught = (tonumber(capture.caught) or 0) + 1
		local shiny = index <= (opts.shiny or 0) or nil
		capture.specimens["t" .. npcSerial] = { id = "t" .. npcSerial, npc = npc, stars = opts.stars or 1, shiny = shiny,
			at = W.now, origin = "capture", name = "Bête " .. npc, size = opts.size }
	end
end
local function Shown(frame) return frame ~= nil and frame:IsShown() == true end
local function Toast() return NS.journalToast end
local function Text(fs) return fs and fs.GetText and fs:GetText() or "" end
local function Said(pool)
	for _, said in ipairs(W.says) do if said.pool == pool then return said end end
	return nil
end
local function CountPool(pool)
	local n = 0
	for _, said in ipairs(W.says) do if said.pool == pool then n = n + 1 end end
	return n
end

-- Le départ et le retour sans Ready2Quest : la zone de repos
local function Leave() W.resting = false; Mock:Fire("PLAYER_UPDATE_RESTING") end
local function Back() W.resting = true; Mock:Fire("PLAYER_UPDATE_RESTING") end
local function Login(isLogin, isReload) Mock:Fire("PLAYER_ENTERING_WORLD", isLogin, isReload) end

-- 1. Bonjour ----------------------------------------------------------------------------------
do
	Say("-- bilan de sortie : bonjour")
	Fresh()
	local s = Steps()
	NS.featsDormant = false
	NS.companionRestedDormant = true
	local data = NS:CompanionData()
	local function Hello(away)
		data.sleepy, data.sleepyLeft = nil, nil
		NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubbleLine, NS.companionBubbleKey = nil, nil, nil, nil
		NS.companionBubbleText = nil
		if NS.companionRT then NS.companionRT.cool, NS.companionRT.seq = {}, nil end
		W.says = {}
		data.lastSeen = W.now - (away or 10 * 3600)
		NS:CompanionLogin()
		return NS.companionBubbleText or ""
	end
	-- 98 espèces : « Encore 2 espèces et tu deviens Maître dresseur ! » (titre du palier de 100)
	local capture = NS:CaptureData()
	capture.creatures, capture.caught = {}, 0
	for index = 1, 98 do capture.creatures[80000 + index] = { name = "Bête", normal = true, stars = 1 } end
	local text = Hello()
	s.ok("proche : la phrase de la maquette", text == "Encore 2 espèces et tu deviens Maître dresseur !", text)
	s.ok("la bulle de bonjour d'avant (MISSED), une seule", NS.companionBubbleKey == "MISSED" and #W.says == 1, #W.says)
	-- unité connue, sans titre ; unité inconnue
	local caught = NS:FeatDef("men_caught_100")
	NS.FeatNearest = function() return { { def = caught, cur = 97, max = 100 } } end
	text = Hello()
	s.ok("haut fait sans titre : « Encore 3 prises et tu obtiens Cent prises ! »",
		text == "Encore 3 prises et tu obtiens " .. NS:FeatName(caught) .. " !", text)
	local flag
	for _, def in ipairs(NS:FeatDefs()) do
		local crit = def.crit or {}
		if not flag and crit[1] == "list" and NS:FeatCountable(def) and not def.hidden
			and not (type(def.reward) == "table" and def.reward.title) then flag = def end
	end
	NS.FeatNearest = function() return { { def = flag, cur = 8, max = 10 } } end
	text = Hello()
	s.ok("unité inconnue : « Tu en es à 8 sur 10 pour … »", text == "Tu en es à 8 sur 10 pour " .. NS:FeatName(flag) .. " !", text)
	-- loin : la réplique d'avant
	NS.FeatNearest = function() return { { def = caught, cur = 20, max = 100 } } end
	Hello()
	s.ok("rien de proche : la réplique d'avant (voix du bonjour)", NS.companionBubbleKey == "MISSED"
		and not tostring(NS.companionBubbleLine):find("^TRIP_"), NS.companionBubbleLine)
	NS.FeatNearest = function() return {} end
	Hello()
	s.ok("aucun haut fait : la réplique d'avant", NS.companionBubbleKey == "MISSED"
		and not tostring(NS.companionBubbleLine):find("^TRIP_"))
	-- jamais un secret, jamais une ligne en attente (même si on les lui tend)
	local secret, pending
	for _, def in ipairs(NS:FeatDefs()) do
		if def.hidden and not secret then secret = def end
		if def.pending and not pending then pending = def end
	end
	NS.FeatNearest = function() return { { def = secret, cur = 9, max = 10 } } end
	Hello()
	s.ok("un secret tendu : jamais cité", not tostring(NS.companionBubbleLine):find("^TRIP_") and secret ~= nil)
	if pending then
		NS.FeatNearest = function() return { { def = pending, cur = 9, max = 10 } } end
		Hello()
		s.ok("une ligne en attente tendue : jamais citée", not tostring(NS.companionBubbleLine):find("^TRIP_"))
	end
	-- le vrai FeatNearest : un secret à 9 sur 10 ne sort pas
	NS.FeatNearest = savedNearest
	if secret then
		local list = NS:FeatNearest(50)
		local found = false
		for _, item in ipairs(list) do if item.def.hidden then found = true end end
		s.ok("FeatNearest : aucun secret", not found)
	end
	-- le repos garde la priorité
	NS.companionRestedDormant = nil
	data.restedV = 1
	text = Hello(9 * 3600)
	s.ok("bien reposé : sa réplique d'abord", NS.companionBubbleLine == "COMP_SAY_RESTED", NS.companionBubbleLine)
	NS.companionRestedDormant = true
	-- courte absence : pas de bulle (comme avant), première connexion : HELLO
	Hello(600)
	s.ok("absence courte : pas de bulle de plus", #W.says == 0, #W.says)
	-- mode discret : le bonjour reste
	NS:DB().quiet = true
	text = Hello()
	s.ok("mode discret : le bonjour reste", text == "Encore 2 espèces et tu deviens Maître dresseur !", text)
	NS:DB().quiet = false
	-- le moteur des hauts faits endormi (harnais) : la réplique d'avant
	NS.featsDormant = true
	Hello()
	s.ok("moteur endormi : rien de neuf", not tostring(NS.companionBubbleLine):find("^TRIP_"))
	s.check("[TRIP-HELLO] bonjour : proche (titre, haut fait, sans unité), rien de proche, repos d'abord, jamais un secret ni une ligne en attente, une seule bulle")
	Done()
end

-- 2. Bulle d'objectif ---------------------------------------------------------------------------
do
	Say("-- bilan de sortie : bulle d'objectif")
	Fresh()
	local s = Steps()
	NS.featsDormant = false
	local savedUnlocks = NS.CompanionNextUnlocks
	NS.CompanionNextUnlocks = function() return {} end
	local function Try()
		NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
		NS.companionBubbleLine, NS.companionBubbleText = nil, nil
		NS:CompanionUpdateVisibility()
		if not NS.companionRT then NS:CompanionTryGoal() end   -- (son état d'exécution, créé à la demande)
		local rt = NS.companionRT
		rt.goalAt, rt.cool = 0, {}
		W.says = {}
		return NS:CompanionTryGoal()
	end
	local caught = NS:FeatDef("men_caught_100")
	NS.FeatNearest = function() return { { def = caught, cur = 98, max = 100 } } end
	local ok = Try()
	s.ok("le plus proche : « Plus que 2 prises pour Cent prises. »", ok and NS.companionBubbleText
		== "Plus que 2 prises pour " .. NS:FeatName(caught) .. ".", NS.companionBubbleText)
	s.ok("dans le créneau d'objectif (GOAL), une bulle", Said("GOAL") and #W.says == 1 and NS.companionRT.cool.goal ~= nil)
	-- suivi : il passe devant
	local species = NS:FeatDef("men_species_1000")
	NS:FeatFollow(species.id, true)
	ok = Try()
	s.ok("le haut fait suivi passe devant", ok and tostring(NS.companionBubbleText):find(NS:FeatName(species), 1, true) ~= nil,
		NS.companionBubbleText)
	NS:FeatFollow(species.id, false)
	-- rien de proche : pas de bulle
	NS.FeatNearest = function() return { { def = caught, cur = 10, max = 100 } } end
	s.ok("rien de proche : pas de bulle", Try() == false and #W.says == 0)
	-- pause d'une demi-heure
	NS.FeatNearest = function() return { { def = caught, cur = 98, max = 100 } } end
	Try()
	NS.companionLastBubble, NS.companionBubbleUntil = nil, nil
	s.ok("une par demi-heure au plus", NS:CompanionTryGoal() == false)
	-- mode discret
	NS:DB().quiet = true
	s.ok("mode discret : coupée", Try() == false and #W.says == 0)
	NS:DB().quiet = false
	-- une étape du compagnon toute proche garde la priorité (le créneau d'avant)
	NS.CompanionNextUnlocks = function() return { { label = "Jeune", kind = "stage", stat = "level", have = 8, need = 10,
		source = "player" } } end
	Try()
	s.ok("une étape proche du compagnon garde le créneau", Said("GOAL_STAGE") and not Said("GOAL"))
	NS.CompanionNextUnlocks = savedUnlocks
	s.check("[TRIP-GOAL] bulle d'objectif : le plus proche, le suivi d'abord, rien de proche, pause, mode discret")
	Done()
end

-- 3. Sortie sans Ready2Quest ----------------------------------------------------------------------
do
	Say("-- bilan de sortie : sortie (zone de repos)")
	Fresh()
	local s = Steps()
	Login(true, false)
	s.ok("connexion au repos : pas de sortie", NS:TripActive() == nil)
	Leave()
	s.ok("sortie de la zone de repos : la sortie commence", NS:TripActive() ~= nil)
	-- 19 minutes, 6 captures : trop court
	Minutes(19); Capture(6, { species = 2 })
	Back()
	s.ok("19 minutes : pas de bilan", NS:TripActive() == nil and not Shown(Toast()) and NS:CharData().tripLast == nil)
	-- 25 minutes, 4 captures : trop peu
	Leave(); Minutes(25); Capture(4, { species = 1 })
	Back()
	s.ok("4 captures : pas de bilan", not Shown(Toast()) and NS:CharData().tripLast == nil)
	-- les deux seuils tout juste : le bandeau
	Leave()
	local glitter0 = NS:Paillettes()
	Minutes(20); Capture(5, { species = 2, shiny = 1, stars = 3 })
	NS:PaillettesAdd(12, "study"); NS:PaillettesAdd(10, "milestone")
	NS:TallyAdd("bondPoints", 4)
	Back()
	local last = NS:CharData().tripLast
	s.ok("20 minutes et 5 captures : le bandeau", Shown(Toast()) and last ~= nil)
	s.ok("chiffres : 5 captures, 2 espèces, 1 brillante, 22 paillettes, 4 points de lien", last and last.captures == 5
		and last.species == 2 and last.shinies == 1 and last.glitter == 22 and last.bond == 4
		and NS:Paillettes() - glitter0 == 22, last and (last.captures .. "/" .. last.species .. "/" .. last.shinies .. "/" .. last.glitter))
	s.ok("paillettes par raison", last and last.by.study == 12 and last.by.milestone == 10)
	s.ok("durée : 20 minutes", last and last.dur == 20 * 60, last and last.dur)
	-- deux retours de suite
	NS.journalToasts, NS.journalToastHideAt = {}, nil
	if Toast() then Toast():Hide() end
	Back()
	NS:FireCallback("RETURN", { name = "Auberge" })
	s.ok("deux retours de suite : un seul bilan", NS:TripFinish("rest") == nil and not Shown(Toast()) and #NS.journalToasts == 0)
	-- combat : le bandeau attend la fin
	Leave(); Minutes(30); Capture(6, { species = 1 })
	W.combat = true
	Back()
	s.ok("retour en combat : rien à l'écran, le bilan attend", not Shown(Toast()) and #NS.journalToasts == 1)
	NS:UpdateJournalToast(NS.Now())
	s.ok("toujours en combat : rien", not Shown(Toast()))
	W.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	NS:UpdateJournalToast(NS.Now())
	s.ok("fin du combat : le bandeau", Shown(Toast()) and Toast().shownEntry and Toast().shownEntry.kind == "trip")
	if Toast() then Toast():Hide() end
	NS.journalToasts, NS.journalToastHideAt = {}, nil
	-- mode discret : pas de bandeau, le bilan gardé pour la page
	NS:DB().quiet = true
	Leave(); Minutes(40); Capture(7, { species = 3 })
	Back()
	s.ok("mode discret : pas de bandeau", not Shown(Toast()) and #NS.journalToasts == 0)
	s.ok("mode discret : le bilan gardé pour la page", NS:CharData().tripLast and NS:CharData().tripLast.captures == 7)
	NS:DB().quiet = false
	-- rechargement en pleine sortie : ni remise à zéro, ni bilan
	Leave()
	local start = NS:TripActive().at
	Minutes(15); Capture(3)
	Mock:Fire("PLAYER_LOGOUT")
	NS.tripSession = nil
	Login(false, true)
	s.ok("rechargement : la même sortie, pas de bilan", NS:TripActive() and NS:TripActive().at == start
		and not Shown(Toast()) and #NS.journalToasts == 0)
	Minutes(10); Capture(3)
	Back()
	s.ok("après le rechargement : le bilan compte toute la sortie (25 min, 6 captures)", Shown(Toast())
		and NS:CharData().tripLast.captures == 6 and NS:CharData().tripLast.dur == 25 * 60, NS:CharData().tripLast.dur)
	if Toast() then Toast():Hide() end
	NS.journalToasts, NS.journalToastHideAt = {}, nil
	-- déconnexion dehors : le temps hors ligne ne compte pas
	Leave(); Minutes(10); Capture(5)
	Mock:Fire("PLAYER_LOGOUT")
	Minutes(8 * 60)
	NS.tripSession = nil
	Login(true, false)
	Minutes(5)
	Back()
	s.ok("hors ligne : pas compté (15 min dehors : pas de bilan)", not Shown(Toast()) and NS:TripActive() == nil)
	-- reconnexion dans une zone de repos, sortie en cours : finie sans bandeau
	Leave(); Minutes(30); Capture(8)
	Mock:Fire("PLAYER_LOGOUT")
	W.resting = true
	NS.tripSession = nil
	Login(true, false)
	s.ok("reconnexion au repos : sortie finie, sans bandeau, bilan gardé", NS:TripActive() == nil and not Shown(Toast())
		and #NS.journalToasts == 0 and NS:CharData().tripLast.captures == 8)
	-- pierre de foyer : écran de chargement vers une zone de repos = un retour
	W.resting = false; NS.tripResting = false
	NS:TripStart("rest")
	Minutes(30); Capture(6)
	W.resting = true
	Login(false, false)
	s.ok("voyage vers une zone de repos : le bilan", Shown(Toast()))
	s.check("[TRIP-OUT] sortie : 19 min, 4 captures, seuils, chiffres, deux retours, combat, mode discret, rechargement, hors ligne, foyer")
	Done()
end

-- 4. Sortie avec Ready2Quest ----------------------------------------------------------------------
do
	Say("-- bilan de sortie : avec Ready2Quest")
	Fresh()
	local s = Steps()
	local r2q = { departed = nil, DB = function() return { enabled = true } end }
	NS.r2qBridge = r2q
	Login(true, false)
	Leave()
	s.ok("la zone de repos ne lance rien (Ready2Quest dit les départs)", NS:TripActive() == nil)
	r2q.departed = true
	NS:FireCallback("DEPARTURE", { name = "Orgrimmar" })
	s.ok("DEPARTURE : la sortie commence", NS:TripActive() ~= nil and NS:TripActive().how == "r2q")
	Minutes(25); Capture(5, { species = 1 })
	Back()
	s.ok("zone de repos pendant que Ready2Quest finira : rien", NS:TripActive() ~= nil and not Shown(Toast()))
	r2q.departed = nil
	NS:FireCallback("RETURN", { name = "Orgrimmar" })
	s.ok("RETURN : le bilan", NS:TripActive() == nil and Shown(Toast()))
	NS:FireCallback("RETURN", { name = "Orgrimmar" })
	s.ok("RETURN deux fois : un seul bilan", #NS.journalToasts == 0)
	if Toast() then Toast():Hide() end
	NS.journalToasts, NS.journalToastHideAt = {}, nil
	-- après un rechargement, Ready2Quest ne sait plus qu'on était parti : la zone de repos finit
	W.resting = false; NS.tripResting = false
	r2q.departed = true
	NS:FireCallback("DEPARTURE")
	Minutes(30); Capture(5)
	r2q.departed = nil
	Back()
	s.ok("relais après rechargement : la zone de repos finit la sortie", NS:TripActive() == nil and Shown(Toast()))
	if Toast() then Toast():Hide() end
	NS.journalToasts, NS.journalToastHideAt = {}, nil
	-- Ready2Quest coupé : comme sans lui
	r2q.DB = function() return { enabled = false } end
	Leave()
	s.ok("Ready2Quest coupé : la zone de repos lance la sortie", NS:TripActive() ~= nil)
	s.check("[TRIP-R2Q] avec Ready2Quest : DEPARTURE, RETURN, une fois, relais après rechargement, coupé")
	Done()
end

-- 5. Le bandeau et « Détail » -----------------------------------------------------------------------
do
	Say("-- bilan de sortie : bandeau et détail")
	Fresh()
	local s = Steps()
	local recap = { at = W.now - 5040, ended = W.now, dur = 5040, captures = 14, species = 3, shinies = 1, glitter = 31,
		study = 4, bond = 7, by = { study = 12, milestone = 10, feat = 5, capture = 4 },
		best = { name = "Raptor (brillant)", stars = 3, shiny = true, size = "giant" }, feats = { "men_caught_100" } }
	NS:CharData().tripLast = recap
	NS:TripBanner(recap)
	local toast = Toast()
	s.ok("le bandeau moyen du carnet", Shown(toast) and toast.forgeBanner == true)
	s.ok("« RETOUR DE SORTIE »", Text(toast.title) == "RETOUR DE SORTIE", Text(toast.title))
	s.ok("« 14 captures, 3 espèces nouvelles »", Text(toast.text) == "14 captures, 3 espèces nouvelles", Text(toast.text))
	s.ok("« 1 brillante · 31 paillettes »", Text(toast.stars) == "1 brillante · 31 paillettes", Text(toast.stars))
	s.ok("6 secondes", math.abs((NS.journalToastHideAt or 0) - NS.Now() - R.seconds) < 0.01, (NS.journalToastHideAt or 0) - NS.Now())
	local button = toast.tripButton
	s.ok("« Détail » sur la rangée de la sous-ligne", Shown(button) and Text(button.label) == "Détail"
		and not (toast.shareButton and toast.shareButton:IsShown()))
	s.ok("singuliers et zéro", NS:TripBannerEntry({ captures = 1, species = 0, shinies = 0, glitter = 1 }).name
		== "1 capture, aucune espèce nouvelle")
	-- « Détail » : le carnet sur la page
	NS:DB().journalTab = "menagerie"
	button:Click()
	local frame = NS.journalFrame
	s.ok("« Détail » : le carnet sur « Dernière sortie »", Shown(frame) and frame.kind == "trip" and Shown(frame.tripPane))
	s.ok("le bandeau se range", not Shown(toast))
	s.ok("la prochaine ouverture revient à la page d'avant", NS:DB().journalTab == "menagerie")
	local pane = frame.tripPane
	s.ok("cinq chiffres", Text(pane.stats.dur.value) == "1 h 24" and Text(pane.stats.captures.value) == "14"
		and Text(pane.stats.species.value) == "3" and Text(pane.stats.shinies.value) == "1" and Text(pane.stats.glitter.value) == "31")
	s.ok("meilleure prise", Text(pane.rows.best.value):find("Raptor (brillant) · 3 étoiles", 1, true) ~= nil, Text(pane.rows.best.value))
	s.ok("tâches d'étude, points de lien", Text(pane.rows.study.value) == "4" and Text(pane.rows.bond.value) == "7")
	s.ok("paillettes par raison, la plus grosse d'abord", Text(pane.rows.glitter.value)
		== "12 étude · 10 paliers de zone · 5 hauts faits · 4 prises", Text(pane.rows.glitter.value))
	s.ok("hauts faits obtenus", Text(pane.rows.feats.value) == "1 : " .. NS:FeatName("men_caught_100"), Text(pane.rows.feats.value))
	s.ok("titre de la page", Text(frame.header.title) == "Dernière sortie")
	-- pas de bilan encore
	NS:CharData().tripLast = nil
	NS:RefreshJournal()
	s.ok("sans bilan : une phrase", Text(pane.none) == NS.L.TRIP_PAGE_NONE and not Shown(pane.rows.best))
	frame:Hide()
	-- un autre bandeau ensuite : pas de « Détail », la sous-ligne reprend sa largeur
	NS.journalToasts, NS.journalToastHideAt = {}, nil
	local wide = toast.tripStarsW
	NS:JournalToastPush({ kind = "seal", title = "SCEAU", name = "Durotar" })
	s.ok("bandeau suivant : plus de « Détail »", Shown(toast) and not Shown(button)
		and (wide == nil or math.abs((toast.stars:GetWidth() or 0) - wide) < 0.5))
	-- en combat : « Détail » n'ouvre rien
	toast:Hide()
	W.combat = true
	s.ok("en combat : le carnet ne s'ouvre pas", NS:TripDetailOpen() == false)
	W.combat = false
	s.check("[TRIP-BAN] bandeau moyen, textes, 6 s, « Détail », page « Dernière sortie », bandeau suivant, combat")
	Done()
end

-- 6. Lignes de chat -----------------------------------------------------------------------------------
do
	Say("-- bilan de sortie : lignes de chat")
	Fresh()
	local s = Steps()
	local db = NS:DB()
	db.tripChat, db.journalChat = nil, false
	s.ok("défaut : muettes, et le choix posé", NS:TripChatOn() == false and db.tripChat == false)
	db.tripChat, db.journalChat = nil, true
	s.ok("qui avait allumé les lignes du carnet les garde", NS:TripChatOn() == true and db.tripChat == true)
	db.tripChat, db.journalChat = false, true
	s.ok("un choix posé ne bouge plus", NS:TripChatOn() == false)
	-- la ligne de réglage, dans la page des annonces
	local page
	for _, p in ipairs(NS.OPTION_PAGES or {}) do if p.id == "journal" then page = p end end
	local row, after
	for index, r in ipairs(page and page.rows or {}) do
		if r.key == "tripChat" then row = r end
		if r.key == "announceGuild" then after = index end
	end
	s.ok("réglage dans la page des annonces, après elles", row and row.kind == "bool" and page.rows[after + 1] == row)
	-- paillettes de palier : muettes, puis rendues
	db.tripChat, db.journalChat = false, false
	W.printed = {}
	NS:PaillettesOnMilestones({ { mark = 25 } })
	local muted = #W.printed
	db.tripChat = true
	NS:PaillettesOnMilestones({ { mark = 50 } })
	s.ok("paliers : muets par défaut, rendus par le réglage", muted == 0 and #W.printed == 1, muted .. "/" .. #W.printed)
	s.ok("journalChat (les tampons) n'a pas bougé", db.journalChat == false)
	db.tripChat, db.journalChat = false, true
	W.printed = {}
	NS:PaillettesOnMilestones({ { mark = 75 } })
	s.ok("tampons allumés, réglage éteint : palier muet", #W.printed == 0 and db.journalChat == true)
	-- étude : une tâche finie
	NS.studyDormant = false
	db.tripChat = false
	local capture = NS:CaptureData()
	-- (la toute première capture passe par la reprise de l'étude, sans paiement ni ligne)
	capture.creatures[7951] = { name = "Loup", normal = true, stars = 1, class = "normal" }
	NS:SpecimenAdd({ npc = 7951, stars = 1, name = "Loup", origin = "capture", size = "normal", trait = "zen" })
	capture.creatures[7952] = { name = "Ours", normal = true, stars = 1, class = "normal" }
	W.printed = {}
	NS:SpecimenAdd({ npc = 7952, stars = 1, name = "Ours", origin = "capture", size = "normal", trait = "zen" })
	local function Has(key)
		local head = (NS.L[key] or key):match("^([^%%]+)")
		for _, line in ipairs(W.printed) do if head and line:find(head, 1, true) then return true end end
		return false
	end
	local studyMuted = not Has("STUDY_DONE")
	db.tripChat = true
	capture.creatures[7954] = { name = "Lynx", normal = true, stars = 1, class = "normal" }
	W.printed = {}
	NS:SpecimenAdd({ npc = 7954, stars = 1, name = "Lynx", origin = "capture", size = "normal", trait = "zen" })
	s.ok("étude : muette par défaut, rendue par le réglage", studyMuted and #W.printed > 0, #W.printed)
	-- lien : un niveau gagné
	capture.creatures[7955] = { name = "Lion", normal = true, stars = 3, class = "normal" }
	local id = NS:SpecimenAdd({ npc = 7955, stars = 3, name = "Lion", origin = "capture", size = "normal", trait = "zen" })
	NS:CompanionData().appearance = "cap:7955"
	local spec = NS:SpecimenGet(id)
	local function LevelUp()
		spec.bond = { p = NS.BOND_LEVELS[2] - 1 }
		W.printed = {}
		NS:SpecimenBondAdd("quest", 1)
		local head = NS.L.BOND_UP:match("%%s(.-)%%s")
		for _, line in ipairs(W.printed) do if head and line:find(head, 1, true) then return true end end
		return false
	end
	db.tripChat = false
	local bondMuted = not LevelUp()
	db.tripChat = true
	s.ok("lien : muet par défaut, rendu par le réglage", bondMuted and LevelUp())
	s.check("[TRIP-CHAT] lignes de chat : défaut muet, choix antérieur gardé, réglage, paliers, étude, lien")
	Done()
end

-- 7. Contrastes, thème, glyphes ------------------------------------------------------------------------
do
	Say("-- bilan de sortie : contrastes")
	local s = Steps()
	-- bandeau : fond WINDOW à 0,94 sur un monde blanc (pire cas, comme les fêtes)
	local bg = Theme.Over(Theme.WHITE, Theme.WINDOW, 0.94)
	local name = Theme.Contrast(Theme.PARCHMENT, bg)
	local sub = Theme.Contrast(Theme.GOLD_LIGHT, bg)
	local title = Theme.Contrast(Theme.IDENTITY_LIGHT or Theme.TITLE, bg)
	s.ok("bandeau : ligne ≥ 4,5:1, sous-ligne ≥ 4,5:1, titre ≥ 3:1", name >= 4.5 and sub >= 4.5 and title >= 3,
		string.format("%.2f / %.2f / %.2f", name, sub, title))
	-- page : chiffres et libellés sur la tuile, section sur le fond de la fenêtre
	local value = Theme.Contrast(Theme.PARCHMENT, Theme.ROW)
	local label = Theme.Contrast(Theme.MUTED_LIGHT, Theme.ROW)
	local section = Theme.Contrast(Theme.IDENTITY_LIGHT or Theme.MUTED_LIGHT, Theme.WINDOW)
	local none = Theme.Contrast(Theme.MUTED_LIGHT, Theme.WINDOW)
	s.ok("page : chiffres ≥ 4,5:1, libellés ≥ 4,5:1, section ≥ 3:1, phrase ≥ 4,5:1", value >= 4.5 and label >= 4.5
		and section >= 3 and none >= 4.5, string.format("%.2f / %.2f / %.2f / %.2f", value, label, section, none))
	-- bouton « Détail » : l'encre des libellés sur la plaque neutre (mesure du bouton Partager)
	local ink = Theme.Contrast(NS.SHARE_FORGE_INK or Theme.LABEL, Theme.NAV)
	s.ok("« Détail » ≥ 4,5:1", ink >= 4.5, string.format("%.2f", ink))
	Say(string.format("   contrastes : ligne %.2f, sous-ligne %.2f, titre %.2f, chiffres %.2f, libellés %.2f, section %.2f, phrase %.2f, bouton %.2f",
		name, sub, title, value, label, section, none, ink))
	-- le fichier : aucune couleur codée en dur, aucun glyphe, rien par image
	local file = io.open((rawget(_G, "ADDON_ROOT") or ".") .. "/QuestCompanion/TripRecap.lua", "rb")
	local code = file and file:read("*a") or ""
	if file then file:close() end
	s.ok("fichier lu", #code > 0)
	s.ok("aucune couleur codée en dur (|cff…, SetTextColor(0.…))", not code:find("|cff%x") and not code:find("Color%(%s*%d*%.%d"))
	s.ok("aucun glyphe ★ ☆ ✓ ✗", not code:find("★", 1, true) and not code:find("☆", 1, true) and not code:find("✓", 1, true)
		and not code:find("✗", 1, true))
	s.ok("rien par image", not code:find("OnUpdate", 1, true))
	for key, text in pairs(NS.TRIP_STRINGS.fr) do
		if text:find("★", 1, true) or text:find("✓", 1, true) then s.ok("glyphe dans " .. key, false) end
		s.ok("anglais pour " .. key, type(NS.TRIP_STRINGS.en[key]) == "string")
	end
	s.check("[TRIP-UI] contrastes mesurés, jetons du thème, aucun glyphe, rien par image")
end
