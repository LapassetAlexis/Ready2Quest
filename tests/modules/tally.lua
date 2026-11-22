-- Compteurs de jeu (Tally.lua, QuestCompanion 3.7.0, étape 1, chantier A) :
-- l'API du magasin (bornes, ensembles plafonnés, bascule de semaine,
-- sauvegarde ancienne ou abîmée), puis chaque clé relevée : on joue
-- l'événement dans le harnais et on lit le compteur. Une action refusée ne
-- compte pas ; une enveloppe rend ce que rend la fonction relevée.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local TL = { saved = {}, random = math.random }
local GLOBALS = { "IsInGroup", "GetNumGroupMembers", "UnitLevel", "UnitName", "C_Timer", "SendChatMessage", "C_ChatInfo",
	"IsInGuild", "GetNormalizedRealmName", "UnitFullName", "PlayMusic", "StopMusic", "date", "InCombatLockdown",
	"UnitAffectingCombat", "IsInInstance" }
for _, name in ipairs(GLOBALS) do TL.saved[name] = rawget(_G, name) end
-- champs de NS remplacés le temps d'un scénario (remis à la fin)
local FIELDS = { "ShinySpeciesKills", "ReserveSelectReleasable", "ShareText", "ShareAllowed", "ShareCopy", "WeeklyId",
	"WinterVeilSeason", "WinterNight", "CompanionWinterKey", "FeatTouch", "CaptureRollQuality", "SpecimenRollSize", "SpecimenRollTrait" }
for _, name in ipairs(FIELDS) do TL.saved["ns:" .. name] = rawget(NS, name) end

local A, CH = "account", "char"

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local function Restore()
	for _, name in ipairs(GLOBALS) do _G[name] = TL.saved[name] end
	for _, name in ipairs(FIELDS) do NS[name] = TL.saved["ns:" .. name] end
	math.random = TL.random
end

local function Errors()
	local list = {}
	for _, entry in ipairs(NS.errors or {}) do
		local where = type(entry) == "table" and (entry.where or entry[1]) or entry
		if tostring(where):find("tally", 1, true) then list[#list + 1] = tostring(where) end
	end
	return list
end

TL.allErrors = {}
function TL.Reset()
	for _, where in ipairs(Errors()) do TL.allErrors[#TL.allErrors + 1] = where end
	Restore()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "captureBatchFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionLastPet = nil, nil, nil
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.errors = {}
	_G.IsInGroup = function() return false end
	_G.GetNumGroupMembers = function() return 0 end
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.C_Timer = { After = function(_, fn) fn() end }
	local db = NS:DB()
	db.winterVeil = "off"
	db.companionCapture = true
	NS:CompanionData().tutoDone = true
	NS.CaptureRollQuality = function() return 1 end
	NS.SpecimenRollSize = function() return "normal" end
	NS.TallyPartnersForget()
	Mock.world.level = 20
	Mock:Reset()
end

local function Target(fields)
	local t = { npcID = 7001, name = "Raptor", class = "normal", zoneID = 1413, level = 20 }
	for k, v in pairs(fields or {}) do t[k] = v end
	return t
end
local function Resolve(success, target, extra)
	local rolling = { success = success, target = Target(target) }
	for k, v in pairs(extra or {}) do rolling[k] = v end
	return NS:CaptureResolve(rolling), rolling
end

-- ---------------------------------------------------------------------------
-- 1. API
-- ---------------------------------------------------------------------------
do
	Say("-- compteurs : l'API")
	TL.Reset()
	local s = Steps()
	local touched = 0
	NS.FeatTouch = function(_, topic) if topic == "tally" then touched = touched + 1 end end
	s.ok("absent : 0", NS:TallyGet("x") == 0 and NS:TallyBest("x") == 0 and NS:TallySize("x") == 0 and NS:TallyHas("x", 1) == false)
	s.ok("lire ne crée rien d'autre que le magasin", NS:DB().tally ~= nil and next(NS:DB().tally.n) == nil)
	s.ok("ajout de 1 par défaut, rend le total", NS:TallyAdd("x") == 1 and NS:TallyAdd("x") == 2)
	s.ok("ajout d'un delta", NS:TallyAdd("x", 5) == 7 and NS:TallyGet("x") == 7)
	s.ok("jamais sous zéro", NS:TallyAdd("x", -100) == 0)
	s.ok("compte et personnage séparés", NS:TallyAdd("y", 3, CH) == 3 and NS:TallyGet("y") == 0 and NS:TallyGet("y", CH) == 3)
	s.ok("magasin du personnage dans CharData().tally", NS:CharData().tally.n.y == 3 and NS:DB().tally.n.y == nil)
	s.ok("maximum : monte, ne descend pas", NS:TallyMax("m", 4) == 4 and NS:TallyMax("m", 2) == 4 and NS:TallyBest("m") == 4
		and NS:TallyMax("m", 9) == 9)
	s.ok("ensemble : ajout, doublon, appartenance", NS:TallyMark("s", "a") == 1 and NS:TallyMark("s", "a") == 1
		and NS:TallyMark("s", "b") == 2 and NS:TallyHas("s", "a") and not NS:TallyHas("s", "c") and NS:TallySize("s") == 2)
	s.ok("ensemble : membre absent, rien", NS:TallyMark("s", nil) == 2)
	for i = 1, 5 do NS:TallyMark("cap", i, A, 3) end
	s.ok("ensemble plafonné (3)", NS:TallySize("cap") == 3 and not NS:TallyHas("cap", 4))
	for i = 1, 210 do NS:TallyMark("big", i) end
	s.ok("plafond par défaut 200", NS:TallySize("big") == 200)
	s.ok("ensemble du personnage à part", NS:TallyMark("s", "z", CH) == 1 and NS:TallySize("s") == 2)
	-- la taille suit une sauvegarde relue (table neuve)
	NS:DB().tally.s.s = { p = true, q = true, r = true }
	s.ok("taille relue d'une sauvegarde", NS:TallySize("s") == 3)
	s.ok("clé nil : 0, rien d'écrit", NS:TallyAdd(nil) == 0 and NS:TallyMax(nil, 3) == 0 and NS:TallyMark(nil, 1) == 0)
	s.ok("FeatTouch(\"tally\") à chaque écriture", touched > 0)
	local before = touched
	NS:TallyGet("x"); NS:TallyBest("m"); NS:TallySize("s"); NS:TallyMark("s", "p"); NS:TallyMax("m", 1)
	s.ok("lectures, doublon et maximum non battu : pas de FeatTouch", touched == before, touched - before)
	NS.FeatTouch = nil
	s.ok("sans moteur : on compte quand même", NS:TallyAdd("x") == 1)
	s.check("[TAL] API : ajout, maximum, ensembles plafonnés, deux magasins")
end

do
	Say("-- compteurs : sauvegarde ancienne ou abîmée")
	TL.Reset()
	local s = Steps()
	local db = NS:DB()
	db.capture = db.capture or {}
	db.capture.paillettes = 12
	db.tally = "abîmée"
	s.ok("magasin abîmé remplacé", NS:TallyAdd("x") == 1 and type(db.tally) == "table" and db.tally.v == 1)
	db.tally = { v = 1, n = { x = 4 }, m = "?", s = 7 }
	s.ok("champs abîmés réparés, compteurs gardés", NS:TallyGet("x") == 4 and NS:TallyMax("m", 2) == 2 and NS:TallyMark("s", 1) == 1)
	s.ok("le reste de la sauvegarde intact", db.capture.paillettes == 12)
	local char = NS:CharData()
	char.companion = char.companion or { keep = true }
	char.tally = nil
	s.ok("personnage sans magasin : créé à la demande", NS:TallyGet("w", CH) == 0 and NS:TallyAdd("w", 1, CH) == 1
		and char.companion ~= nil)
	s.check("[TAL] sauvegarde : créée à la demande, sûre sur une sauvegarde ancienne ou abîmée")
end

do
	Say("-- compteurs : la semaine")
	TL.Reset()
	local s = Steps()
	local week = "w1"
	NS.WeeklyId = function() return week end
	s.ok("semaine en cours", NS:TallyWeekAdd("k") == 1 and NS:TallyWeekAdd("k", 2) == 3 and NS:TallyWeek().id == "w1")
	s.ok("pas encore de semaine d'avant", NS:TallyLastWeek() == nil)
	week = "w2"
	s.ok("bascule : compteur neuf", NS:TallyWeek().id == "w2" and (NS:TallyWeek().n.k or 0) == 0)
	s.ok("la semaine d'avant gardée", NS:TallyLastWeek() and NS:TallyLastWeek().id == "w1" and NS:TallyLastWeek().n.k == 3)
	NS:TallyWeekAdd("k", 5)
	week = "w3"
	NS:TallyWeekAdd("k")
	s.ok("une seule semaine d'avant gardée", NS:TallyLastWeek().id == "w2" and NS:TallyLastWeek().n.k == 5
		and NS:TallyWeek().n.k == 1)
	s.ok("au compte", NS:DB().tally.week.id == "w3")
	s.check("[TAL] semaine : identifiant de ShopWeek, bascule vers lastWeek gardée une fois")
end

-- ---------------------------------------------------------------------------
-- 2. Capture : le verdict
-- ---------------------------------------------------------------------------
do
	Say("-- compteurs : verdict d'un lancer")
	TL.Reset()
	local s = Steps()
	local result = Resolve(false, { npcID = 7001 })
	s.ok("l'enveloppe rend le verdict", result == false)
	s.ok("échec compté", NS:TallyGet("captureFail") == 1)
	s.ok("réussite rendue", Resolve(true, { npcID = 7002 }) == true)
	Resolve(true, { npcID = 7003 })
	Resolve(true, { npcID = 7004 })
	s.ok("série en cours et meilleure", NS:TallyGet("captureStreak") == 3 and NS:TallyBest("captureStreak") == 3)
	Resolve(false, { npcID = 7005 })
	s.ok("échec : série à zéro, meilleure gardée", NS:TallyGet("captureStreak") == 0 and NS:TallyBest("captureStreak") == 3
		and NS:TallyGet("captureFail") == 2)
	Resolve(true, { npcID = 7006 })
	s.ok("série repart", NS:TallyGet("captureStreak") == 1 and NS:TallyBest("captureStreak") == 3)
	Resolve(false, { npcID = 7007, class = "worldboss" })
	s.ok("boss du monde raté", NS:TallyGet("bossFail") == 1)
	Resolve(true, { npcID = 7008, class = "worldboss" })
	s.ok("boss pris : pas bossFail", NS:TallyGet("bossFail") == 1)
	s.ok("rien de compté par erreur", NS:TallyGet("captureHunt") == 0 and NS:TallyGet("captureGroup") == 0
		and NS:TallyGet("captureAided") == 0 and NS:TallyGet("smallGame") == 0 and NS:TallyGet("closeCall") == 0)
	s.ok("aucune erreur de relevé", #Errors() == 0, table.concat(Errors(), ","))
	s.check("[TAL] verdict : captureFail, captureStreak (série et meilleure), bossFail")
end

do
	Say("-- compteurs : chasse, groupe, aides, rares, petit gibier")
	TL.Reset()
	local s = Steps()
	Resolve(true, { npcID = 7101, hunt = true })
	Resolve(false, { npcID = 7102, hunt = true })
	s.ok("prise en mode chasse (ratée : non)", NS:TallyGet("captureHunt") == 1)
	NS:HuntStart(nil)
	Resolve(true, { npcID = 7103 })
	NS:HuntStop()
	s.ok("prise pendant la chasse", NS:TallyGet("captureHunt") == 2)
	_G.IsInGroup = function() return true end
	Resolve(true, { npcID = 7104 })
	Resolve(false, { npcID = 7105 })
	_G.IsInGroup = function() return false end
	s.ok("prise en groupe", NS:TallyGet("captureGroup") == 1)
	Resolve(true, { npcID = 7106 }, { aid = "lasso" })
	Resolve(true, { npcID = 7107 }, { aid = "sifflet" })
	Resolve(false, { npcID = 7108 }, { aid = "sifflet" })
	s.ok("prises avec une aide", NS:TallyGet("captureAided") == 2)
	s.ok("prise au Sifflet", NS:TallyGet("captureWhistle") == 1)
	Resolve(true, { npcID = 7109, class = "rare" })
	Resolve(true, { npcID = 7110, class = "rareelite" })
	Resolve(true, { npcID = 7111, class = "rare" }, { aid = "appat" })
	Resolve(true, { npcID = 7112, class = "elite" })
	Resolve(false, { npcID = 7113, class = "rare" })
	s.ok("rare sans aide (rare, rare élite)", NS:TallyGet("rareNoAid") == 2)
	_G.UnitLevel = function() return 60 end
	Resolve(true, { npcID = 7114, level = 5 })
	Resolve(true, { npcID = 7115, level = 6 })
	Resolve(false, { npcID = 7116, level = 2 })
	Resolve(true, { npcID = 7117, level = nil })
	_G.UnitLevel = function() return 59 end
	Resolve(true, { npcID = 7118, level = 1 })
	s.ok("petit gibier : niveau 60, créature de niveau 5 ou moins", NS:TallyGet("smallGame") == 1)
	s.check("[TAL] verdict : captureHunt, captureGroup, captureAided, captureWhistle, rareNoAid, smallGame")
end

do
	Say("-- compteurs : survie de justesse")
	TL.Reset()
	local s = Steps()
	Resolve(true, { npcID = 7201 })
	s.ok("sans survie : rien", NS:TallyGet("closeCall") == 0)
	NS:CompanionShout("SHOUT_SURVIVED")
	Mock.now = Mock.now + 4
	Resolve(true, { npcID = 7202 })
	s.ok("prise 4 s après le cri", NS:TallyGet("closeCall") == 1)
	Mock.now = Mock.now + 5
	Resolve(false, { npcID = 7203 })
	s.ok("ratée : rien", NS:TallyGet("closeCall") == 1)
	Mock.now = Mock.now + 2
	Resolve(true, { npcID = 7204 })
	s.ok("après 10 s : rien", NS:TallyGet("closeCall") == 1)
	NS:CompanionShout("SHOUT_LOW_HP")
	Resolve(true, { npcID = 7205 })
	s.ok("un autre cri : rien", NS:TallyGet("closeCall") == 1)
	s.check("[TAL] closeCall : prise dans les 10 s qui suivent le cri de survie")
end

-- ---------------------------------------------------------------------------
-- 3. Spécimens, volée, chasse, aides, échoppe, brillantes
-- ---------------------------------------------------------------------------
do
	Say("-- compteurs : spécimens d'exception")
	TL.Reset()
	local s = Steps()
	local function Add(spec) spec.at = 1; spec.zone = 1413; return NS:SpecimenAdd(spec) end
	local id = Add({ npc = 801, stars = 3, size = "giant", origin = "capture" })
	s.ok("l'enveloppe rend l'identifiant", id ~= nil and NS:SpecimenGet(id) ~= nil)
	s.ok("3 étoiles géant : concours", NS:TallyGet("contest") == 1 and NS:TallyGet("shinyRareSize") == 0)
	Add({ npc = 802, stars = 2, size = "tiny", shiny = true, origin = "capture" })
	s.ok("brillante minuscule 2 étoiles", NS:TallyGet("shinyRareSize") == 1 and NS:TallyGet("contest") == 1
		and NS:TallyGet("unfindable") == 0)
	Add({ npc = 803, stars = 3, size = "giant", shiny = true })
	s.ok("brillante 3 étoiles géante (origine par défaut : capture)", NS:TallyGet("unfindable") == 1
		and NS:TallyGet("contest") == 2 and NS:TallyGet("shinyRareSize") == 2)
	Add({ npc = 804, stars = 3, size = "large", shiny = true, origin = "capture" })
	Add({ npc = 805, stars = 3, size = "giant", shiny = true, origin = "trade" })
	s.ok("taille ordinaire ou échange : rien", NS:TallyGet("contest") == 2 and NS:TallyGet("unfindable") == 1)
	-- par le verdict : la taille tirée à la capture
	NS.SpecimenRollSize = function() return "tiny" end
	NS.CaptureRollQuality = function() return 3 end
	Resolve(true, { npcID = 806, stars = 3 }, { stars = 3 })
	s.ok("capture d'un 3 étoiles minuscule (verdict)", NS:TallyGet("contest") == 3)
	s.check("[TAL] spécimen : contest, shinyRareSize, unfindable (captures seulement)")
end

do
	Say("-- compteurs : volée, chasse, aides")
	TL.Reset()
	local s = Steps()
	local function Batch(n, tried)
		local results = {}
		for i = 1, tried do
			results[i] = { target = { name = "R" .. i, npcID = 900 + i }, success = i <= n, stars = 1, shakes = 3 }
		end
		return NS:CaptureBatchFlush({ results = results, tried = tried, total = tried, messages = {} })
	end
	Batch(4, 6)
	s.ok("volée de 4", NS:TallyBest("batch") == 4)
	Batch(2, 2)
	s.ok("plus petite : le maximum reste", NS:TallyBest("batch") == 4)
	Batch(7, 7)
	s.ok("plus grosse : 7", NS:TallyBest("batch") == 7)
	NS:HuntStart(nil)
	NS:HuntStart(10)
	s.ok("chasse lancée une fois (déjà en cours : non)", NS:TallyGet("huntStart") == 1)
	NS:HuntStop()
	NS:HuntToggle()
	s.ok("relancée par la bascule", NS:TallyGet("huntStart") == 2)
	NS:HuntStop()
	local items = NS:CaptureData().items
	items.lasso, items.appat = 1, 0
	s.ok("dépense rendue", NS:CaptureSpend("lasso") == true and NS:CaptureSpend("lasso") == false
		and NS:CaptureSpend("appat") == false and NS:CaptureSpend("rien") == false)
	s.ok("aide dépensée comptée (refus : non)", NS:TallyGet("aidUsed") == 1 and NS:TallyGet("aidUsed:lasso") == 1
		and NS:TallyGet("aidUsed:appat") == 0)
	items.sifflet = 1
	local rolling = NS:CaptureRoll(Target({ npcID = 7301 }), "sifflet")
	s.ok("lancer au Sifflet : dépensé", rolling.aid == "sifflet" and NS:TallyGet("aidUsed:sifflet") == 1 and NS:TallyGet("aidUsed") == 2)
	s.check("[TAL] batch (plus grosse volée), huntStart, aidUsed et aidUsed:<aide>")
end

do
	Say("-- compteurs : échoppe et paillettes")
	TL.Reset()
	local s = Steps()
	NS:PaillettesAdd(50, "test")
	NS:PaillettesAdd(0, "test")
	NS:PaillettesAdd(5)
	s.ok("gagnées par raison", NS:TallyGet("glitter:test") == 50 and NS:TallyGet("glitter:?") == 5)
	local ok = NS:ShopBuy("appat")
	s.ok("achat rendu", ok == true)
	s.ok("achat et aide achetée", NS:TallyGet("shopBuy") == 1 and NS:TallyGet("aidBought") == 1)
	local price = NS:ShopPrice(NS:ShopItem("appat"))
	s.ok("paillettes dépensées, au total et par raison", NS:TallyGet("glitterSpent") == price
		and NS:TallyGet("glitterSpent:shop:appat") == price, NS:TallyGet("glitterSpent"))
	local refused = NS:ShopBuy("patron")
	s.ok("achat refusé (trop cher) : rien", refused == false and NS:TallyGet("shopBuy") == 1
		and NS:TallyGet("glitterSpent") == price)
	s.ok("dépense refusée : rien", NS:PaillettesSpend(10000, "x") == false and NS:TallyGet("glitterSpent:x") == 0)
	NS:PaillettesAdd(200, "test")
	NS:ShopBuy("slots")
	s.ok("autre achat : pas une aide", NS:TallyGet("shopBuy") == 2 and NS:TallyGet("aidBought") == 1)
	s.check("[TAL] shopBuy, aidBought, glitterSpent(:raison), glitter:<raison>")
end

do
	Say("-- compteurs : série de chasse d'une brillante")
	TL.Reset()
	local s = Steps()
	local kills = 12
	NS.ShinySpeciesKills = function() return kills end
	NS:ShinyKill("guid-1", { zoneID = 1413, npcID = 3001, name = "Loup" })
	s.ok("série au moment de la brillante", NS:TallyBest("shinyChain") == 12)
	kills = 80
	NS:ShinyKill("guid-2", { zoneID = 1413, npcID = 3001, name = "Loup" })
	s.ok("plafonnée à 50", NS:TallyBest("shinyChain") == 50)
	s.check("[TAL] shinyChain : série de chasse plafonnée à 50")
end

-- ---------------------------------------------------------------------------
-- 4. Réserve : relâcher, commandes, lien
-- ---------------------------------------------------------------------------
local function ReserveOf(npc, n, zone)
	local ids = {}
	local data = NS:CaptureData()
	data.creatures[npc] = data.creatures[npc] or { name = "Bête " .. npc, normal = true, stars = 3, zoneID = zone, type = "Bête",
		class = "normal", at = 1 }
	NS:SpecimenAdd({ npc = npc, stars = 3, zone = zone, at = 1, origin = "capture", name = "Bête " .. npc, trait = "curious" })
	for i = 1, n do
		ids[i] = NS:SpecimenAdd({ npc = npc, stars = 1, zone = zone, at = 1, origin = "capture", name = "Bête " .. npc,
			trait = "curious" })
	end
	return ids
end

do
	Say("-- compteurs : relâcher")
	TL.Reset()
	local s = Steps()
	local ids = ReserveOf(820, 13, 1413)
	local gain = NS:SpecimenRelease(ids[1])
	s.ok("relâcher rendu", type(gain) == "number")
	s.ok("relâché compté", NS:TallyGet("release") == 1)
	local ref = NS:SpecimenReference(820, false)
	local no, why = NS:SpecimenRelease(ref.id)
	s.ok("refusé (référence du Codex) : rien", no == false and why == "reference" and NS:TallyGet("release") == 1)
	local list = {}
	for i = 2, 11 do list[#list + 1] = NS:SpecimenGet(ids[i]) end
	NS.ReserveSelectReleasable = function() return list end
	local count = NS:ReserveTidyConfirm()
	s.ok("lot de 10", count == 10 and NS:TallyBest("releaseBatch") == 10 and NS:TallyGet("release") == 11)
	list = { NS:SpecimenGet(ids[12]) }
	NS:ReserveTidyConfirm()
	s.ok("petit lot : le maximum reste", NS:TallyBest("releaseBatch") == 10 and NS:TallyGet("release") == 12)
	s.ok("paillettes du relâcher par raison", NS:TallyGet("glitter:release") > 0)
	s.check("[TAL] release (un par un, refus exclu), releaseBatch (plus gros lot)")
end

do
	Say("-- compteurs : commandes de la semaine")
	TL.Reset()
	local s = Steps()
	local ids = ReserveOf(830, 4, 1413)
	local orders = NS:ShopOrders()
	s.ok("relance rendue", NS:ShopOrdersReroll() == true)
	s.ok("relance comptée", NS:TallyGet("orderReroll") == 1)
	orders = NS:ShopOrders()
	for i = 1, 3 do orders.list[i] = { kind = "zone", zone = 1413, reward = 5 } end
	s.ok("livraison rendue", NS:ShopOrderDeliver(1, ids[1]) == true)
	s.ok("livraison refusée (déjà livrée) : rien", NS:ShopOrderDeliver(1, ids[2]) == false and NS:TallyGet("orderDone") == 1)
	s.ok("relance après une livraison refusée : rien", NS:ShopOrdersReroll() == false and NS:TallyGet("orderReroll") == 1)
	s.ok("deux livrées : semaine pas pleine", NS:ShopOrderDeliver(2, ids[2]) == true and NS:TallyGet("orderWeek") == 0)
	NS:ShopOrderDeliver(3, ids[3])
	s.ok("trois livrées : semaine pleine, une fois", NS:TallyGet("orderDone") == 3 and NS:TallyGet("orderWeek") == 1)
	NS:ShopOrderDeliver(3, ids[4])
	s.ok("rien à livrer de plus", NS:TallyGet("orderDone") == 3 and NS:TallyGet("orderWeek") == 1)
	s.check("[TAL] orderDone, orderWeek (les trois livrées), orderReroll")
end

do
	Say("-- compteurs : points de lien")
	TL.Reset()
	local s = Steps()
	ReserveOf(840, 0, 1413)
	s.ok("sans spécimen porté : rien", NS:SpecimenBondAdd("cap", 1) == 0 and NS:TallyGet("bondPoints") == 0)
	NS:CompanionData().appearance = "cap:840"
	local gain = NS:SpecimenBondAdd("cap", 1)
	s.ok("points rendus et comptés", gain > 0 and NS:TallyGet("bondPoints") == gain, gain)
	for _ = 1, 5 do NS:SpecimenBondAdd("cap", 1) end
	local cap = NS.BOND_SOURCES.cap.cap
	s.ok("plafond du jour : seuls les points gagnés comptent", NS:TallyGet("bondPoints") == cap, NS:TallyGet("bondPoints"))
	NS:CompanionData().appearance = nil
	s.check("[TAL] bondPoints : points de lien gagnés")
end

-- ---------------------------------------------------------------------------
-- 5. Entre dresseurs : partage, guilde, détenteurs, échanges
-- ---------------------------------------------------------------------------
do
	Say("-- compteurs : partages")
	TL.Reset()
	local s = Steps()
	local sent = {}
	NS.ShareText = function() return "texte" end
	NS.ShareAllowed = function() return true end
	NS.ShareCopy = function() return true end
	_G.SendChatMessage = function(text, channel) sent[#sent + 1] = channel end
	_G.IsInInstance = function() return false, "none" end
	local item = { key = "k1" }
	s.ok("envoi rendu", NS:ShareSend(item, "GUILD") == true and #sent == 1)
	NS:ShareSend({ key = "k2" }, "PARTY")
	s.ok("partages comptés par canal", NS:TallyGet("share") == 2 and NS:TallyGet("share:GUILD") == 1
		and NS:TallyGet("share:PARTY") == 1)
	NS:ShareSend({ key = "k3" }, "COPY")
	local ok, why = NS:ShareSend({ key = "k4" }, "SAY")
	s.ok("copie, « Dire » hors instance (texte en attente) : rien", NS:TallyGet("share") == 2 and why == "say")
	NS.ShareAllowed = function() return false, "again" end
	NS:ShareSend({ key = "k5" }, "GUILD")
	s.ok("refusé : rien", NS:TallyGet("share") == 2)
	NS.ShareAllowed = function() return true end
	_G.SendChatMessage = function() error("api") end
	NS:ShareSend({ key = "k6" }, "GUILD")
	s.ok("API en erreur : rien", NS:TallyGet("share") == 2)
	s.check("[TAL] share et share:<canal> : partages envoyés pour de bon")
end

local function ChatInfo(log)
	_G.C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return 0 end,
		SendAddonMessage = function(prefix, text, channel, target)
			log[#log + 1] = { prefix = prefix, text = text, channel = channel, target = target }
			return 0
		end,
		InChatMessagingLockdown = function() return false end,
	}
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return nil end
	_G.UnitFullName = nil
	_G.GetNormalizedRealmName = function() return "Royaume" end
end

do
	Say("-- compteurs : exploits de guilde")
	TL.Reset()
	local s = Steps()
	local log = {}
	ChatInfo(log)
	_G.IsInGuild = function() return true end
	NS:DB().trainerShare = true
	if NS.GuildFeatsReset then NS:GuildFeatsReset() end
	s.ok("rien en attente : rien d'envoyé", NS:GuildFeatsFlush(Mock.now) == false and NS:TallyGet("guildSent") == 0)
	NS:GuildFeatNote({ kind = "s", id = 3098, zone = 1411, stars = 3, class = "normal" })
	s.ok("trop tôt : rien", NS:GuildFeatsFlush(Mock.now) == false and NS:TallyGet("guildSent") == 0)
	local sent = NS:GuildFeatsFlush(Mock.now + NS.GFEAT_GATHER + 1)
	s.ok("envoyé et compté", sent == true and NS:TallyGet("guildSent") == 1)
	if NS.GuildFeatsReset then NS:GuildFeatsReset() end
	if NS.TrainerResetSession then NS:TrainerResetSession() end
	s.check("[TAL] guildSent : exploit de guilde envoyé")
end

do
	Say("-- compteurs : dresseurs croisés, partenaires d'échange")
	TL.Reset()
	local s = Steps()
	local log = {}
	ChatInfo(log)
	if NS.TrainerResetSession then NS:TrainerResetSession() end
	if NS.TradeResetSession then NS:TradeResetSession() end
	NS:TrainerMarkHolder("Jaina-Royaume")
	NS:TrainerMarkHolder("jaina-royaume")
	NS:TrainerMarkHolder("Testeur-Royaume")
	s.ok("détenteur noté (clé de joueur), jamais soi-même", NS:TallySize("holders") == 1 and NS:TallyHas("holders", "jaina-royaume"))
	-- un échange préparé, conclu par le F de l'autre
	local capture = NS:CaptureData()
	capture.tradePending = { tid = "t1", peer = "Deklatis-Royaume", at = 1, give = {}, get = {}, gotK = nil }
	NS:TradeOnAddonMessage("QCTrade", "F~1~t1", "WHISPER", "Deklatis-Royaume")
	s.ok("échange conclu", capture.tradePending == nil and #NS:TradeLog() == 1)
	s.ok("partenaire d'échange", NS:TallySize("tradePartners") == 1 and NS:TallyHas("tradePartners", "deklatis-royaume"))
	s.ok("son message l'a noté détenteur", NS:TallyHas("holders", "deklatis-royaume") and NS:TallySize("holders") == 2)
	capture.tradePending = { tid = "t2", peer = "Deklatis-Royaume", at = 1, give = {}, get = {} }
	NS:TradeOnAddonMessage("QCTrade", "X~1~t2", "WHISPER", "Deklatis-Royaume")
	s.ok("échange abandonné : rien", NS:TallySize("tradePartners") == 1)
	capture.tradePending = { tid = "t3", peer = "Deklatis-Royaume", at = 1, give = {}, get = {} }
	NS:TradeOnAddonMessage("QCTrade", "F~1~t3", "WHISPER", "Deklatis-Royaume")
	s.ok("même partenaire : une fois", NS:TallySize("tradePartners") == 1 and #NS:TradeLog() == 3)
	if NS.TrainerResetSession then NS:TrainerResetSession() end
	if NS.TradeResetSession then NS:TradeResetSession() end
	s.check("[TAL] holders (détenteurs croisés), tradePartners (échanges conclus)")
end

-- ---------------------------------------------------------------------------
-- 6. Juke-box
-- ---------------------------------------------------------------------------
do
	Say("-- compteurs : juke-box")
	TL.Reset()
	local s = Steps()
	_G.PlayMusic = function() return true end
	_G.StopMusic = function() end
	_G.C_Timer = nil
	local list = NS:MusicCatalog().list
	local a, b, c = list[1].id, list[2].id, list[3].id
	s.ok("lecture rendue", NS:JukePlay(a, nil, nil, true) == true)
	Mock:Advance(10)
	s.ok("10 s : pas encore", NS:TallySize("jukeHeard") == 0)
	Mock:Advance(21)
	s.ok("30 s : écouté", NS:TallyHas("jukeHeard", a) and NS:TallySize("jukeHeard") == 1)
	NS:JukePlay(b, nil, nil, true)
	Mock:Advance(10)
	NS:JukePlay(c, nil, nil, true)
	Mock:Advance(25)
	s.ok("changé avant 30 s : le premier non, le second pas encore", not NS:TallyHas("jukeHeard", b)
		and not NS:TallyHas("jukeHeard", c))
	Mock:Advance(6)
	s.ok("le second, 30 s après son départ", NS:TallyHas("jukeHeard", c))
	NS:JukePlay(b, nil, nil, true)
	Mock:Advance(5)
	NS:JukeStop(true)
	Mock:Advance(40)
	s.ok("arrêté avant 30 s : rien", not NS:TallyHas("jukeHeard", b))
	-- un morceau écouté la nuit pendant le Voile d'hiver (n'importe lequel : le
	-- catalogue n'a aucun morceau propre à la fête)
	local season, night = false, true
	NS.WinterVeilSeason = function() return season end
	NS.WinterNight = function() return night end
	NS:JukePlay(b, nil, nil, true)
	Mock:Advance(31)
	s.ok("hors saison, de nuit : rien", NS:TallyGet("winterSong") == 0 and NS:TallyHas("jukeHeard", b))
	season, night = true, false
	NS:JukePlay(a, nil, nil, true); Mock:Advance(31)
	s.ok("en saison, de jour : rien", NS:TallyGet("winterSong") == 0)
	night = true
	NS:JukePlay(b, nil, nil, true); Mock:Advance(10)
	s.ok("en saison, de nuit, avant 30 s : pas encore", NS:TallyGet("winterSong") == 0)
	Mock:Advance(21)
	s.ok("en saison, de nuit, 30 s : compté", NS:TallyGet("winterSong") == 1)
	s.ok("absente refusée : rien", (function() _G.PlayMusic = function() return false end; return NS:JukePlay(c, nil, nil, true) end)() == false)
	NS:JukeStop(true)
	s.check("[TAL] jukeHeard (30 s d'écoute), winterSong (de nuit, pendant le Voile d'hiver)")
end

-- ---------------------------------------------------------------------------
-- 7. Compagnon (par personnage)
-- ---------------------------------------------------------------------------
do
	Say("-- compteurs : envies, états, Rayonnant")
	TL.Reset()
	local s = Steps()
	local needs = NS:CompanionData().needs
	for _, key in ipairs(NS.COMPANION_NEED_KEYS) do needs[key] = 0 end
	NS:CompanionData().sleepy = nil
	s.ok("état gagné rendu", NS:CompanionGrant("hunger") == true)
	s.ok("état gagné compté (personnage)", NS:TallyGet("state", CH) == 1 and NS:TallyGet("state") == 0)
	s.ok("déjà plein : refusé, rien", NS:CompanionGrant("hunger") == false and NS:TallyGet("state", CH) == 1)
	NS:CompanionGrant("energy")
	s.ok("deux états : pas Rayonnant", NS:TallyGet("radiant", CH) == 0)
	NS:CompanionGrant("curiosity")
	s.ok("trois : Rayonnant, une fois", NS:TallyGet("radiant", CH) == 1 and NS:CompanionRadiant())
	NS:CompanionGrant("hunger", NS.COMPANION_STATE.max)
	s.ok("déjà Rayonnant : pas de nouveau passage", NS:TallyGet("radiant", CH) == 1)
	NS:CompanionData().sleepy = true
	NS:CompanionWake(false)
	s.ok("réveillé avec ses trois états : Rayonnant de nouveau", NS:TallyGet("radiant", CH) == 2)
	NS:CompanionWake(false)
	s.ok("pas somnolent : rien", NS:TallyGet("radiant", CH) == 2)
	NS:CompanionWishMet("hunger")
	s.ok("envie comblée", NS:TallyGet("wish", CH) == 1)
	needs.energy = 0
	NS:CompanionData().wish = { key = "energy" }
	NS:CompanionGrant("energy")
	s.ok("envie comblée par l'état gagné", NS:TallyGet("wish", CH) == 2 and NS:TallyGet("radiant", CH) == 3)
	s.check("[TAL] wish, state, radiant (passage à Rayonnant, par l'état ou au réveil)")
end

do
	Say("-- compteurs : friandises, semaine, blagues, réveil")
	TL.Reset()
	local s = Steps()
	local pantry = NS:TreatData().pantry
	for _, kind in ipairs(NS.TREAT_KINDS) do pantry[kind] = 2 end
	s.ok("friandise donnée rendue", NS:TreatGive("biscuit") == true)
	NS:TreatGive("biscuit")
	s.ok("garde-manger vide : refusé, rien", NS:TreatGive("biscuit") == false)
	s.ok("friandises comptées par sorte", NS:TallyGet("treat", CH) == 2 and NS:TallyGet("treat:biscuit", CH) == 2)
	for _, kind in ipairs(NS.TREAT_KINDS) do NS:TreatGive(kind) end
	s.ok("cinq sortes données", NS:TallySize("treatKinds", CH) == 5 and NS:TallyGet("treat", CH) == 6)
	NS:MissionGrant("daily")
	NS:MissionGrant("allWeekly")
	s.ok("semaine de missions bouclée", NS:TallyGet("weeklyAll", CH) == 1)
	NS:DB().companionShow = true
	NS:CompanionUpdateVisibility()
	local said = NS:CompanionJoke()
	s.ok("blague demandée, dite", said == true and NS:TallyGet("joke", CH) == 1, said)
	NS.companionBubbleUntil, NS.companionLastBubble, NS.companionBubblePrio = nil, nil, nil
	NS:CompanionSay("JOKE", { force = true })
	s.ok("blague au repos", NS:TallyGet("joke", CH) == 2)
	_G.UnitAffectingCombat = function() return true end
	NS:CompanionJoke()
	_G.UnitAffectingCombat = function() return false end
	s.ok("en combat (pas dite) : rien", NS:TallyGet("joke", CH) == 2)
	NS:CompanionData().sleepy, NS.companionLastPet = true, nil
	s.ok("caresse rendue", NS:CompanionPet() == true)
	s.ok("réveillé d'une caresse", NS:TallyGet("wake", CH) == 1)
	NS.companionLastPet = nil
	NS:CompanionPet()
	s.ok("éveillé : la caresse ne réveille rien", NS:TallyGet("wake", CH) == 1)
	s.check("[TAL] treat, treat:<sorte>, treatKinds, weeklyAll, joke, wake")
end

do
	Say("-- compteurs : horloge d'une minute")
	TL.Reset()
	local s = Steps()
	local day = "20261122"
	_G.date = function(fmt, ...) if fmt == "%Y%m%d" then return day end return TL.saved.date and TL.saved.date(fmt, ...) or os.date(fmt, ...) end
	NS:TallyMinute()
	s.ok("premier jour", NS:TallyGet("days", CH) == 1)
	NS:TallyMinute()
	s.ok("même jour : une fois", NS:TallyGet("days", CH) == 1)
	day = "20261125"
	NS:TallyMinute()
	day = "20261124"
	NS:TallyMinute()
	s.ok("jour nouveau compté ; horloge reculée : rien", NS:TallyGet("days", CH) == 2)
	-- Rayonnant
	local needs = NS:CompanionData().needs
	for _, key in ipairs(NS.COMPANION_NEED_KEYS) do needs[key] = NS.COMPANION_STATE.max end
	NS:CompanionData().sleepy = nil
	NS:TallyMinute(); NS:TallyMinute()
	s.ok("minutes Rayonnant", NS:TallyGet("radiantMin", CH) == 2)
	needs.hunger = 0
	NS:TallyMinute()
	s.ok("plus Rayonnant : rien", NS:TallyGet("radiantMin", CH) == 2)
	-- créatures emmenées
	NS:CompanionData().appearance = "cap:950"
	for _ = 1, 9 do NS:TallyMinute() end
	s.ok("9 minutes : pas encore", NS:TallySize("partners", CH) == 0)
	NS:TallyMinute()
	s.ok("10 minutes : emmenée", NS:TallyHas("partners", 950, CH))
	NS:CompanionData().appearance = "cap:951:s"
	for _ = 1, 10 do NS:TallyMinute() end
	NS:CompanionData().appearance = "beast_wolf"
	for _ = 1, 10 do NS:TallyMinute() end
	s.ok("une autre (brillante), pas une mascotte", NS:TallySize("partners", CH) == 2)
	NS:DB().companionEnabled = false
	NS:CompanionData().appearance = "cap:952"
	for _ = 1, 10 do NS:TallyMinute() end
	needs.hunger = NS.COMPANION_STATE.max
	NS:TallyMinute()
	NS:DB().companionEnabled = nil
	s.ok("compagnon coupé : rien", NS:TallySize("partners", CH) == 2 and NS:TallyGet("radiantMin", CH) == 2)
	-- compagnons de saison
	local winter = "gfw"
	NS.CompanionWinterKey = function() return winter end
	NS:TallyMinute()
	winter = "metzen"; NS:TallyMinute(); NS:TallyMinute()
	winter = "snowman"; NS:TallyMinute()
	winter = "autre"; NS:TallyMinute()
	s.ok("compagnons de saison (au compte, 3 au plus)", NS:TallySize("winterMates") == 3 and NS:TallySize("winterMates", CH) == 0)
	s.ok("compagnon de saison : pas une créature emmenée", not NS:TallyHas("partners", 952, CH))
	-- par l'horloge de l'addon
	NS.CompanionWinterKey = nil
	day = "20261201"
	Mock:Advance(NS.TALLY_TICK + 1)
	s.ok("l'horloge commune la joue", NS:TallyGet("days", CH) == 3)
	s.check("[TAL] horloge : days, radiantMin, partners (10 min), winterMates")
end

do
	Say("-- compteurs : hygiène")
	local s = Steps()
	local ok = NS:TallyHook() == false
	s.ok("enveloppes posées une seule fois", ok)
	for _, where in ipairs(Errors()) do TL.allErrors[#TL.allErrors + 1] = where end
	s.ok("aucune erreur de relevé (tous les scénarios)", #TL.allErrors == 0, table.concat(TL.allErrors, ","))
	s.check("[TAL] enveloppes posées une fois, aucune erreur de relevé")
end

Restore()
ResetWorld()
