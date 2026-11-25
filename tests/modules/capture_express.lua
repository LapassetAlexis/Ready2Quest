-- Compagnon : capture express (CaptureExpress.lua, 3.1.0). Un clic sur le
-- filet tranche tout de suite, combat compris, sans bandeau, carte ni scène ;
-- Maj+clic tout le filet, Ctrl+clic la carte ; le verdict en pastille (fil au-
-- dessus du filet, jamais la souris) ; chat et bulles réservés aux prises qui
-- comptent ; capture automatique (une brillante sans aide attend) ; aide
-- conseillée automatique ; raccourci, liste, /qc filet ; réglage coupé et
-- visite guidée : le déroulé d'avant.
-- (Le déroulé d'avant : capture.lua, capture_lot.lua, capture_preparation.lua.)
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local XP = { saved = {}, random = math.random, units = {}, sounds = {} }
XP.rollQuality, XP.dormant = NS.CaptureRollQuality, NS.captureExpressDormant
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"InCombatLockdown", "UnitAffectingCombat", "PlaySound", "IsShiftKeyDown", "IsControlKeyDown" }
for _, name in ipairs(GLOBALS) do XP.saved[name] = rawget(_G, name) end
local PLAYER = "Player-1-00000001"

function XP.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function XP.Install()
	local w = XP
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
	_G.PlaySound = function(id) w.sounds[#w.sounds + 1] = id; return true end
	_G.IsShiftKeyDown = function() return w.shift == true end
	_G.IsControlKeyDown = function() return w.ctrl == true end
end
function XP.Reset()
	ResetWorld()
	XP.quality = nil
	NS.CaptureRollQuality = function() return XP.quality or 1 end
	if NS.captureBatchFrame then NS.captureBatchFrame:Hide() end
	if NS.captureChooser then NS.captureChooser:Hide() end
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt",
		"captureQueueList", "captureNetButton", "captureToast", "captureExpressFeed" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureToastHideAt, NS.captureAppCache, NS.captureBatch = nil, nil, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	XP.units, XP.combat, XP.sounds, XP.shift, XP.ctrl = {}, false, {}, false, false
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	XP.Install()
	NS.SHINY_CHANCE = 0
	math.random = XP.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().captureMuteUntil = nil
	NS.captureExpressDormant = nil
	-- 3.7.0 : sans le suspense des prises notables (réglage « Capture animée »
	-- coupé) : ces scénarios lisent le verdict tout de suite ; zone_37.lua a le sien
	NS:DB().companionCaptureAnim = false
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling, NS.captureStage.prep = nil, nil end
	NS:CompanionUpdateVisibility()
end
-- le tirage : `value` < chance = prise
function XP.Roll(value)
	math.random = function(a, b)
		if a and b then return XP.random(a, b) end
		if a then return XP.random(a) end
		return value
	end
end
function XP.SeeKill(npcID, fields)
	fields = fields or {}
	fields.guid = fields.guid or XP.Guid(npcID, fields.spawn)
	fields.name = fields.name or ("Bête " .. npcID)
	XP.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, fields.guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, fields.guid, 0)
	return fields.guid
end
function XP.OfferShiny(npcID, name)
	return NS:CaptureOffer(XP.Guid(npcID, "0000005H1N"), { zoneID = 1413, npcID = npcID }, { name = name })
end
function XP.Collect()
	local printed, said = {}, {}
	local oldPrint, oldSay = NS.Print, NS.CompanionSay
	NS.Print = function(_, msg) printed[#printed + 1] = tostring(msg) end
	NS.CompanionSay = function(_, pool) said[#said + 1] = pool; return true end
	return printed, said, function() NS.Print, NS.CompanionSay = oldPrint, oldSay end
end
local function Shown(frame) return frame ~= nil and frame:IsShown() and true or false end
local function Windows()
	return Shown(NS.captureToast) or Shown(NS.captureStage) or Shown(NS.captureChooser) or Shown(NS.captureBatchFrame)
		or Shown(NS.capturePrompt)
end
local function Live() return NS:CaptureExpressUpdate(NS.Now()) end
local function Row(index)
	local feed = NS.captureExpressFeed
	return feed and feed.rows[index], feed and feed.items[index]
end

-- 1. Un clic = un lancer tranché, sans fenêtre --------------------------------------------
do
	Say("-- capture express : un clic, un verdict")
	XP.Reset()
	Check("[EXP] réglages : express par défaut, automatique et aide automatique coupés",
		NS:DB().companionCaptureExpress == true and NS:DB().companionCaptureAuto == false
		and NS:DB().companionCaptureAidAuto == false and NS:CaptureExpressOn() == true)
	XP.Roll(0)
	XP.SeeKill(6100, { name = "Raptor A" })
	Check("[EXP] coup fatal : le filet attend, aucun bandeau ; une pastille l'annonce",
		#NS:CaptureQueueState() == 1 and Shown(NS.captureNetButton) and not Windows()
		and Shown(NS.captureExpressFeed) and select(2, Row(1)).kind == "offer", select(2, Row(1)).kind)
	local printed, said, restore = XP.Collect()
	local rolling = NS:CaptureNetClick("LeftButton")
	restore()
	Check("[EXP] clic : capturée tout de suite, la file vidée, aucune fenêtre ouverte",
		type(rolling) == "table" and rolling.success == true and NS:CaptureIsCaptured(6100)
		and #NS:CaptureQueueState() == 0 and NS:CaptureState().rolling == nil and not Windows())
	local row, item = Row(1)
	Check("[EXP] pastille : espèce nouvelle, sur son liseré doré, affichée",
		item.kind == "notable" and item.text == "Raptor A" and item.right:find(NS.L.CAPTURE_X_NEW, 1, true) ~= nil
		and Live() >= 1 and Shown(row) and row.text:GetText() == "Raptor A", item.kind)
	Check("[EXP] une espèce nouvelle garde son message et sa bulle", #printed >= 1 and #said >= 1, #printed)
	Check("[EXP] un spécimen est rangé, comme par la carte", NS:CaptureStars(6100, false) == 1)
end

-- 2. Prise ordinaire : ni chat ni bulle ; échec : pastille rouge ---------------------------
do
	Say("-- capture express : le chat se tait pour l'ordinaire")
	XP.Reset()
	XP.Roll(0)
	XP.SeeKill(6100, { name = "Raptor A" })
	NS:CaptureExpressThrow()
	local pendingNew = NS.captureResultPending ~= nil
	NS.captureResultPending = nil
	-- la même espèce en mode chasse : proposée, mais ni nouvelle ni meilleure
	NS:CaptureState().queue[1] = nil
	local candidate = { guid = XP.Guid(6100, "0000000002"), npcID = 6100, zoneID = 1413, name = "Raptor A",
		class = "normal", level = 20, stars = 1, hunt = true, serial = 99 }
	table.insert(NS:CaptureQueueState(), candidate)
	local printed, said, restore = XP.Collect()
	local rolling = NS:CaptureExpressThrow(candidate)
	restore()
	local _, item = Row(1)
	Check("[EXP] prise ordinaire : pastille verte, rien dans le chat, pas de bulle",
		type(rolling) == "table" and rolling.success and item.kind == "ok" and #printed == 0 and #said == 0, #printed)
	Check("[EXP] prise ordinaire : pas de bandeau « Capturé ! » en attente ; une prise qui compte garde le sien",
		rolling.quiet == true and NS.captureResultPending == nil and pendingNew)
	Check("[EXP] après le lancer, le chat et les bulles sont rendus", NS.Print ~= nil and NS.captureExpressResolving == nil)
	XP.Roll(0.999)
	XP.SeeKill(6101, { name = "Raptor B" })
	local printed2, _, restore2 = XP.Collect()
	local failed = NS:CaptureExpressThrow()
	restore2()
	local _, lost = Row(1)
	Check("[EXP] échec : pastille rouge « échappée », la créature n'est pas capturée",
		type(failed) == "table" and failed.success == false and lost.kind == "fail" and lost.right == NS.L.CAPTURE_X_FLED
		and not NS:CaptureIsCaptured(6101))
	Check("[EXP] échec d'une espèce nouvelle : le chat le dit", #printed2 >= 1, #printed2)
end

-- 3. En combat ; Maj+clic ; Ctrl+clic -----------------------------------------------------
do
	Say("-- capture express : combat, tout le filet, la carte")
	XP.Reset()
	XP.Roll(0)
	XP.combat = true
	XP.SeeKill(6100, { name = "Raptor A" })
	XP.SeeKill(6101, { name = "Raptor B" })
	XP.SeeKill(6102, { name = "Raptor C" })
	local printed, _, restore = XP.Collect()
	local rolling = NS:CaptureNetClick("LeftButton")
	Check("[EXP] en combat : le clic lance quand même, sans message de refus",
		type(rolling) == "table" and rolling.success and #NS:CaptureQueueState() == 2
		and not (printed[1] and printed[1] == NS.L.CAPTURE_BATCH_COMBAT), printed[1])
	XP.shift = true
	local got, tried = NS:CaptureNetClick("LeftButton")
	restore()
	XP.shift = false
	local _, item = Row(1)
	Check("[EXP] Maj+clic : tout le filet d'un coup, un bilan en pastille, aucune scène",
		got == 2 and tried == 2 and #NS:CaptureQueueState() == 0 and item.kind == "all"
		and item.text == NS:F("CAPTURE_X_ALL", 2, 2) and not Windows(), tostring(got) .. "/" .. tostring(tried))
	XP.combat = false
	XP.SeeKill(6103, { name = "Raptor D" })
	XP.ctrl = true
	NS:CaptureNetClick("LeftButton")
	XP.ctrl = false
	Check("[EXP] Ctrl+clic : la carte de préparation, le candidat reste au filet",
		NS:CapturePrepShown() ~= nil and #NS:CaptureQueueState() == 1)
	NS:CapturePrepClose()
	NS:CaptureNetClick("RightButton")
	Check("[EXP] clic droit : la liste, comme avant", Shown(NS.captureQueueList))
	local frame = NS.captureQueueList
	frame.rows[1]:GetScript("OnClick")(frame.rows[1])
	Check("[EXP] liste : un clic sur une ligne lance, la liste reste ouverte",
		NS:CaptureIsCaptured(6103) and #NS:CaptureQueueState() == 0)
end

-- 4. Le fil : jamais la souris, se retire seul, sans table neuve ---------------------------
do
	Say("-- capture express : le fil de pastilles")
	XP.Reset()
	local X = NS.CAPTURE_EXPRESS
	NS:CaptureExpressPush("ok", "Un", "1")
	local feed = NS.captureExpressFeed
	local first = feed.items[1]
	for index = 2, X.rows + 2 do NS:CaptureExpressPush("ok", "N" .. index, "") end
	Check("[EXP] fil : au plus quatre pastilles, la plus récente en bas, les fiches tournent",
		#feed.items == X.rows and #feed.rows == X.rows and feed.items[1].text == "N" .. (X.rows + 2)
		and (feed.items[1] == first or feed.items[2] == first or feed.items[3] == first or feed.items[4] == first))
	-- lisibilité (règle des contrastes) : les encres sur la plaque posée sur le
	-- pire des sols (neige blanche derrière une plaque à 0,94)
	local Theme = NS.Theme
	local function Over(c, alpha) return { c[1] * alpha + (1 - alpha), c[2] * alpha + (1 - alpha), c[3] * alpha + (1 - alpha) } end
	local plate = Over(Theme.INK, X.plate)
	local worst = math.huge
	for _, ink in ipairs({ Theme.PARCHMENT, Theme.MUTED_LIGHT, Theme.RED, Theme.SHINY }) do
		worst = math.min(worst, Theme.Contrast(ink, plate))
	end
	Check("[EXP] fil : textes lisibles sur la plaque, même sur la neige (contraste >= 4,5)", worst >= 4.5, worst)
	local mouse = false
	for _, row in ipairs(feed.rows) do if row.IsMouseEnabled and row:IsMouseEnabled() then mouse = true end end
	Check("[EXP] fil : ne prend pas la souris", not mouse and not (feed.IsMouseEnabled and feed:IsMouseEnabled()))
	Check("[EXP] fil : affiché tant qu'une pastille vit", Live() == X.rows and Shown(feed))
	Mock.now = Mock.now + X.life + 0.1
	Check("[EXP] fil : tout s'efface au bout de son temps, le fil se cache et sa tâche se retire",
		Live() == 0 and not Shown(feed) and NS.CaptureExpressFrame() == false)
	NS:CaptureExpressPush("notable", "Rare", "")
	Mock.now = Mock.now + X.life + 0.1
	Check("[EXP] fil : une prise qui compte reste plus longtemps", Live() == 1)
	-- (hors glissement : la maquette alloue une table par SetPoint, pas le client)
	NS:CaptureExpressPush("ok", "Raptor", "x")
	Mock.now = Mock.now + X.slide + 0.05
	NS:CaptureExpressUpdate(NS.Now())
	collectgarbage(); collectgarbage("stop")
	local before = collectgarbage("count")
	for _ = 1, 200 do NS:CaptureExpressUpdate(NS.Now()) end
	local grown = collectgarbage("count") - before
	collectgarbage("restart")
	Check("[EXP] fil : 200 images d'une pastille en place sans rien allouer (< 2 Ko)", grown < 2, grown)
end

-- 5. Capture automatique -------------------------------------------------------------------
do
	Say("-- capture express : automatique")
	XP.Reset()
	NS:DB().companionCaptureAuto = true
	XP.Roll(0)
	XP.combat = true
	XP.SeeKill(6100, { name = "Raptor A" })
	local _, item = Row(1)
	Check("[EXP] automatique : capturée au coup fatal, en combat, sans clic ni annonce",
		NS:CaptureIsCaptured(6100) and #NS:CaptureQueueState() == 0 and item.kind == "notable" and not Windows(), item.kind)
	XP.combat = false
	local candidate = XP.OfferShiny(6200, "Raptor doré")
	Check("[EXP] automatique : une brillante sans aide attend au filet",
		candidate ~= nil and #NS:CaptureQueueState() == 1 and NS:CaptureHas(6200, true) ~= true
		and select(2, Row(1)).kind == "shiny")
	NS:CaptureQueueClear()
	NS:DB().companionCaptureAidAuto = true
	NS:CaptureData().items.sifflet = 1
	XP.Roll(0.999)
	XP.OfferShiny(6201, "Raptor doré B")
	Check("[EXP] automatique + aide conseillée : la brillante part avec le sifflet, dépensé, capture assurée",
		NS:CaptureHas(6201, true) == true and NS:CaptureAidCount("sifflet") == 0)
	NS:DB().companionCaptureAuto = false
	XP.SeeKill(6102, { name = "Raptor C" })
	Check("[EXP] automatique coupée : le candidat attend le clic", #NS:CaptureQueueState() == 1)
end

-- 6. Aides : jamais dépensées sans choix ---------------------------------------------------
do
	Say("-- capture express : aides")
	XP.Reset()
	NS:CaptureData().items.appat = 2
	XP.Roll(0)
	XP.quality = 3
	XP.SeeKill(6100, { name = "Raptor A" })
	NS:CaptureExpressThrow()
	Check("[EXP] sans réglage ni choix : aucune aide dépensée, même sur un 3 étoiles", NS:CaptureAidCount("appat") == 2)
	XP.SeeKill(6101, { name = "Raptor B" })
	NS:CaptureToggleAid("appat")
	local rolling = NS:CaptureExpressThrow()
	Check("[EXP] aide choisie dans la liste : elle part avec ce lancer, puis le choix retombe",
		rolling.aid == "appat" and NS:CaptureAidCount("appat") == 1 and NS:CaptureState().aid == nil)
end

-- 7. Raccourci, commande, réglage coupé, visite guidée -------------------------------------
do
	Say("-- capture express : raccourci, commande, réglage coupé")
	XP.Reset()
	XP.Roll(0)
	XP.combat = true
	XP.SeeKill(6100, { name = "Raptor A" })
	Check("[EXP] raccourci : lance en combat", NS:BindingThrowNet() == true and NS:CaptureIsCaptured(6100))
	local printed, _, restore = XP.Collect()
	Check("[EXP] raccourci : filet vide, il le dit", NS:BindingThrowNet() == false and printed[1] == NS.L.CAPTURE_Q_NOTHING)
	XP.combat = false
	XP.SeeKill(6101, { name = "Raptor B" })
	XP.SeeKill(6102, { name = "Raptor C" })
	NS.EXTRA_COMMANDS["filet"](NS, "tout")
	Check("[EXP] /qc filet tout : tout le filet, sans scène", #NS:CaptureQueueState() == 0 and not Windows()
		and NS:CaptureIsCaptured(6101) and NS:CaptureIsCaptured(6102))
	NS.EXTRA_COMMANDS["filet"](NS, "auto")
	local on = NS:DB().companionCaptureAuto
	NS.EXTRA_COMMANDS["filet"](NS, "auto")
	Check("[EXP] /qc filet auto : bascule la capture automatique", on == true and NS:DB().companionCaptureAuto == false)
	NS.EXTRA_COMMANDS["filet"](NS, "express")
	restore()
	Check("[EXP] /qc filet express : coupe la capture express", NS:DB().companionCaptureExpress == false
		and NS:CaptureExpressOn() == false)
	XP.SeeKill(6103, { name = "Raptor D" })
	Check("[EXP] réglage coupé : le bandeau d'avant revient, le lancer express est refusé",
		Shown(NS.captureToast) and NS:CaptureExpressThrow() == false and #NS:CaptureQueueState() == 1)
	NS:DB().companionCaptureExpress = true
	NS.tourState = { id = "capture" }
	-- 3.6.0 : la visite guidée des captures suit la capture express
	Check("[EXP] visite guidée en cours : la capture express reste en service", NS:CaptureExpressOn() == true)
	NS.tourState = nil
end

-- 8. Sons d'une rafale ---------------------------------------------------------------------
do
	Say("-- capture express : sons")
	XP.Reset()
	XP.Roll(0)
	for index = 1, 4 do XP.SeeKill(6100 + index, { name = "Raptor " .. index }) end
	XP.sounds = {}
	Mock.now = Mock.now + 1
	NS:CaptureExpressAll()
	local throws = 0
	for _, id in ipairs(XP.sounds) do if id == NS.CAPTURE_SOUNDS.throw then throws = throws + 1 end end
	Check("[EXP] rafale : un seul bruit de filet, les musiques de réussite ne s'empilent pas",
		throws == 1 and #XP.sounds <= 3, #XP.sounds)
end


-- 9. Où se range le fil : sous le compagnon (retour en jeu, 3.1.0 bêta 9) -----------------
do
	Say("-- capture express : le fil sous le compagnon")
	XP.Reset()
	local X = NS.CAPTURE_EXPRESS
	local frame = NS.companionFrame
	Check("[EXP-PLACE] harnais : compagnon affiché, médaillon forgé", Shown(frame) and frame.ring == "forge"
		and (frame.forgeHitBelow or 0) > 0, frame and frame.ring)
	NS:CaptureExpressPush("ok", "Golem lézardé", "")
	NS:CaptureExpressPush("notable", "Raptor", "")
	NS:CaptureExpressUpdate(NS.Now() + X.slide + 0.05)
	local feed = NS.captureExpressFeed
	local p = feed.lastPoint
	local belowForge = frame.forgeHitBelow
	Check("[EXP-PLACE] forgé : sous le compagnon, centré sur lui, sous l'étiquette d'humeur (plaque et humeur libres)",
		feed.mode == "below" and #feed.points == 1 and p.relTo == frame and p.point == "TOP" and p.relPoint == "BOTTOM"
		and p.x == 0 and p.y == -(belowForge + X.gapBelow), p.point, p.relPoint, p.y)
	local r1, r2 = feed.rows[1].lastPoint, feed.rows[2].lastPoint
	Check("[EXP-PLACE] empilées vers le bas, la plus récente contre le compagnon",
		feed.stack == "down" and r1.point == "TOPLEFT" and r1.y == 0 and r2.point == "TOPLEFT" and r2.y == -(X.h + X.gap)
		and feed.items[1].text == "Raptor", r1.point, r1.y, r2.y)
	-- le filet est à côté, à mi-hauteur (il finit au-dessus du bas du cadre) ;
	-- la fiche au survol se pose sur le bas du cadre et monte ; la bulle au-dessus
	local net = NS:EnsureCaptureNet()
	local half = (frame:GetHeight() or 118) / 2
	Check("[EXP-PLACE] filet à côté du compagnon, plus haut que le fil (badge compris)",
		net.lastPoint.relTo == frame and (net.lastPoint.relPoint == "RIGHT" or net.lastPoint.relPoint == "LEFT")
		and half - NS.CAPTURE_NET_SIZE / 2 - NS.CAPTURE_NET_BADGE.h > 0)
	NS:CompanionShowHover()
	local hp = NS.companionHover.lastPoint
	Check("[EXP-PLACE] fiche au survol : posée sur le bas du cadre, à côté (le fil est dessous)",
		hp.relTo == frame and hp.relPoint == "BOTTOMLEFT" and hp.y == 0 and p.y < 0)
	NS:CompanionHideHover()
	local mouse = feed.IsMouseEnabled and feed:IsMouseEnabled()
	for _, row in ipairs(feed.rows) do if row.IsMouseEnabled and row:IsMouseEnabled() then mouse = true end end
	Check("[EXP-PLACE] le fil ne prend jamais la souris", not mouse)

	-- compagnon Très grand : l'écart suit son échelle, les pastilles gardent leur taille
	NS:DB().companionSize = 4
	NS:CompanionApplySize()
	local scale = frame:GetScale()
	p = feed.lastPoint
	Check("[EXP-PLACE] compagnon agrandi : le fil se replace aussitôt, l'écart suit l'échelle, la pastille garde sa taille",
		scale > 1 and p.relTo == frame and math.abs(p.y + (frame.forgeHitBelow * scale + X.gapBelow)) < 1e-6
		and feed:GetScale() == 1 and feed.rows[1].width == X.w and feed.rows[1].height == X.h, scale, p.y)
	NS:DB().companionSize = 2
	NS:CompanionApplySize()

	-- au bord droit de l'écran : le fil reste dans l'écran
	local width = 1600
	local oldW = UIParent.width
	UIParent.width = width
	frame.GetLeft = function() return width - 60 end
	frame.GetRight = function() return width end
	NS:CaptureExpressPlace()
	p = feed.lastPoint
	Check("[EXP-PLACE] compagnon au bord droit : le fil décale vers la gauche pour rester dans l'écran",
		p.relPoint == "BOTTOM" and math.abs((width - 30) + p.x + X.w / 2 - (width - X.screenPad)) < 1e-6, p.x)
	frame.GetLeft, frame.GetRight = nil, nil
	UIParent.width = oldW

	-- près du bas de l'écran : au-dessus (de la bulle si elle parle), sinon l'ancien emplacement
	local screen = 768
	local oldH = UIParent.height
	UIParent.height = screen
	frame.GetBottom = function() return 30 end
	frame.GetTop = function() return 150 end
	NS:CaptureExpressPlace()
	p = feed.lastPoint
	local aboveFrame = feed.mode == "above" and p.relTo == frame and p.point == "BOTTOM" and p.relPoint == "TOP"
		and p.y == X.gapAbove and feed.stack == "up"
	NS:CaptureExpressUpdate(NS.Now() + X.slide + 0.06)
	local up = feed.rows[1].lastPoint.point == "BOTTOMLEFT"
	Check("[EXP-PLACE] pas la place dessous : au-dessus du compagnon, la plus récente en bas (contre lui)",
		aboveFrame and up, p.point, p.relPoint, feed.mode)
	local bubble = NS:EnsureCompanionBubble()
	bubble:Show()
	bubble.GetTop = function() return 260 end
	NS:CaptureExpressPush("ok", "Loup", "")
	p = feed.lastPoint
	Check("[EXP-PLACE] bulle ouverte : le fil passe au-dessus de la bulle",
		feed.mode == "above" and p.relTo == bubble and p.relPoint == "TOP" and p.y == X.gapBubble, feed.mode)
	bubble.GetTop = function() return screen - 20 end
	NS:CaptureExpressPlace()
	p = feed.lastPoint
	Check("[EXP-PLACE] ni dessous ni dessus : l'ancien emplacement, au-dessus du filet",
		feed.mode == "side" and p.relTo == net and p.relPoint:find("^TOP") ~= nil, feed.mode)
	bubble.GetTop = nil
	bubble:Hide()
	frame.GetBottom, frame.GetTop = nil, nil
	UIParent.height = oldH

	-- compagnon caché : centré au-dessus du filet seul
	frame:Hide()
	NS:CapturePlaceNet()
	p = feed.lastPoint
	Check("[EXP-PLACE] compagnon caché : le fil se replace centré au-dessus du filet seul",
		net.alone == true and feed.mode == "net" and p.relTo == net and p.point == "BOTTOM" and p.relPoint == "TOP", feed.mode)
	frame:Show()
	NS:CapturePlaceNet()
	Check("[EXP-PLACE] compagnon de retour : le fil revient dessous", feed.mode == "below" and feed.lastPoint.relTo == frame)

	-- valeur illisible du client : jamais d'erreur, le fil reste dessous
	frame.GetBottom = function() error("secret") end
	local ok = pcall(NS.CaptureExpressPlace, NS)
	frame.GetBottom = nil
	Check("[EXP-PLACE] coordonnée illisible : pas d'erreur, le fil reste sous le compagnon", ok and feed.mode == "below")
end

-- 10. Sobre : sous le cadre carré -------------------------------------------------------------
do
	Say("-- capture express : le fil sous le cadre Sobre")
	local style = NS:DB().companionStyle
	XP.Reset()
	NS:DB().companionStyle = "sobre"
	NS:ApplyUIStyle()
	if NS.captureExpressFeed then NS.captureExpressFeed:Hide(); NS.captureExpressFeed = nil end
	local frame = NS.companionFrame
	NS:CaptureExpressPush("ok", "Golem", "")
	local feed = NS.captureExpressFeed
	local p = feed.lastPoint
	Check("[EXP-PLACE] Sobre : sous le cadre, centré, empilé vers le bas",
		not feed.forged and frame.ring ~= "forge" and feed.mode == "below" and p.relTo == frame and p.point == "TOP"
		and p.relPoint == "BOTTOM" and p.y == -NS.CAPTURE_EXPRESS.gapBelow and feed.stack == "down", frame.ring, p.y)
	NS:DB().companionStyle = style
	NS:ApplyUIStyle()
	if NS.captureExpressFeed then NS.captureExpressFeed:Hide(); NS.captureExpressFeed = nil end
end

-- 11. La bulle et le thème bougent pendant que des pastilles sont à l'écran ----------------
do
	Say("-- capture express : le fil suit la bulle et la bascule de thème")
	XP.Reset()
	local X = NS.CAPTURE_EXPRESS
	local frame = NS.companionFrame
	local oldH = UIParent.height
	UIParent.height = 768
	frame.GetBottom = function() return 30 end
	frame.GetTop = function() return 150 end
	NS:CaptureExpressPush("ok", "Loup", "")
	local feed = NS.captureExpressFeed
	local before = feed.mode == "above" and feed.lastPoint.relTo == frame
	NS:CompanionSay("HELLO", { force = true, line = "COMP_SAY_HELLO", args = { "Brindille" } })
	local bubble = NS.companionBubble
	local p = feed.lastPoint
	Check("[EXP-PLACE] au-dessus du compagnon, la bulle s'ouvre : le fil monte au-dessus d'elle (jamais dessous)",
		before and bubble and bubble:IsShown() and feed.mode == "above" and p.relTo == bubble and p.relPoint == "TOP"
		and p.y == X.gapBubble, feed.mode, tostring(p.relTo == frame))
	NS:CompanionHideBubble()
	p = feed.lastPoint
	Check("[EXP-PLACE] la bulle se ferme : le fil redescend sur le compagnon",
		feed.mode == "above" and p.relTo == frame and p.y == X.gapAbove, feed.mode)
	frame.GetBottom, frame.GetTop = nil, nil
	UIParent.height = oldH

	-- Sobre -> forgé à chaud, pastilles à l'écran : le fil n'est pas laissé sur la plaque
	local style = NS:DB().companionStyle
	XP.Reset()
	NS:DB().companionStyle = "sobre"
	NS:ApplyUIStyle()
	NS:CaptureExpressPush("ok", "Golem", "")
	local old = NS.captureExpressFeed
	NS:DB().companionStyle = style
	NS:ApplyUIStyle()
	frame = NS.companionFrame
	Check("[EXP-PLACE] bascule Sobre -> forgé : le fil du Sobre est retiré (ni sur la plaque, ni d'un autre style)",
		frame.ring == "forge" and not old:IsShown() and NS.captureExpressFeed == nil, frame.ring)
	NS:CaptureExpressPush("ok", "Golem", "")
	feed = NS.captureExpressFeed
	p = feed.lastPoint
	Check("[EXP-PLACE] après la bascule : fil forgé, sous l'étiquette d'humeur",
		feed.forged and feed.mode == "below" and p.relTo == frame and p.y == -(frame.forgeHitBelow + X.gapBelow), p.y)
	-- même thème réappliqué (le cadre a pu changer) : le fil à l'écran se replace
	feed:ClearAllPoints()
	feed:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	NS:ApplyUIStyle()
	p = feed.lastPoint
	Check("[EXP-PLACE] thème réappliqué : le fil à l'écran se replace sous le compagnon",
		NS.captureExpressFeed == feed and p.relTo == frame and p.y == -(frame.forgeHitBelow + X.gapBelow), p.y)
	feed:Hide()
end

-- 3.1.2 : les aides au survol du filet ---------------------------------------------------
do
	Say("-- capture express : aides au survol du filet")
	XP.Reset()
	local items = NS:CaptureData().items
	items.appat, items.lasso, items.sifflet = 2, 0, 1
	XP.Roll(0.99)                      -- sans aide, raté à coup sûr
	XP.SeeKill(6300, { name = "Loup A" })
	XP.SeeKill(6301, { name = "Loup B", spawn = "00001A2B3D" })
	local net = NS.captureNetButton
	local hooked = net and net.aidBarHooked == true
	local shown = NS:CaptureAidBarShow()
	local bar = NS.captureAidBar
	local counts = {}
	for i, b in ipairs(bar and bar.buttons or {}) do counts[i] = b.aidID .. "=" .. tostring(b.count.text) .. (b.empty and "(gris)" or "") end
	Check("[EXP] survol du filet : la barre des trois aides au-dessus, comptes et aide vide grisée",
		hooked and shown and bar:IsShown() and #bar.buttons == 3
		and bar.lastPoint and bar.lastPoint.relTo == net and bar.lastPoint.point == "BOTTOM"
		and bar.buttons[2].empty == true and bar.buttons[1].empty ~= true, table.concat(counts, ", "))
	local refused, why = NS:CaptureAidBarUse("lasso")
	local stillTwo = #NS:CaptureQueueState() == 2
	local chance, sure = NS:CaptureAidBarChance("sifflet")
	local rolling = NS:CaptureAidBarUse("sifflet")
	Check("[EXP] clic sur une aide : le filet part avec elle (sifflet : assurée), une aide vide refusée, l'aide ne sert qu'une fois",
		not refused and why == "none" and stillTwo and sure == true and chance == 1
		and rolling and rolling.success and rolling.aid == "sifflet" and items.sifflet == 0
		and #NS:CaptureQueueState() == 1 and NS:CaptureState().aid == nil and bar.buttons[3].empty == true)
	NS:CaptureAidBarUse("appat")
	Check("[EXP] filet vidé : la barre se range ; l'infobulle du filet le dit",
		#NS:CaptureQueueState() == 0 and not bar:IsShown())
	XP.SeeKill(6302, { name = "Loup C", spawn = "00001A2B3E" })
	GameTooltip:ClearLines()
	NS:CaptureExpressTipLines(GameTooltip, NS:CaptureQueueState(), "Loup C")
	local tip = {}
	for _, line in ipairs(GameTooltip.lines or {}) do tip[#tip + 1] = tostring(line.text or line) end
	Check("[EXP] infobulle du filet : la ligne des aides au survol",
		table.concat(tip, " | "):find("aides au-dessus du filet", 1, true) ~= nil, table.concat(tip, " | "))
	-- capture express coupée : pas de barre
	NS:DB().companionCaptureExpress = false
	Check("[EXP] capture express coupée : pas de barre d'aides", NS:CaptureAidBarShow() == false)
	NS:DB().companionCaptureExpress = true
	if NS.captureAidBar then NS.captureAidBar:Hide() end
end

-- 3.1.2 : le filet se déplace seul ---------------------------------------------------------
do
	Say("-- filet : déplacé indépendamment du compagnon")
	XP.Reset()
	XP.Roll(0)
	XP.SeeKill(6400, { name = "Raptor M" })
	local net = NS.captureNetButton
	local savedAlt = rawget(_G, "IsAltKeyDown")
	local alt = false
	_G.IsAltKeyDown = function() return alt end
	-- sans Alt (réglage par défaut « Alt + glisser ») : rien ne bouge
	net:GetScript("OnDragStart")(net)
	local refused = net.netDragging == nil
	-- Alt + glisser : détaché, gardé
	alt = true
	net:GetScript("OnDragStart")(net)
	local started = net.netDragging == true
	net:ClearAllPoints()
	net:SetPoint("CENTER", UIParent, "CENTER", 120, -40)
	net:GetScript("OnDragStop")(net)
	local saved = NS:DB().captureNetPoint
	-- le relâcher du glisser ne lance pas le filet
	local before = #NS:CaptureQueueState()
	local clicked = NS:CaptureNetClick("LeftButton")
	local notThrown = clicked == nil and #NS:CaptureQueueState() == before
	-- replacé : la place gardée, plus collé au portrait
	NS:CapturePlaceNet()
	local p = net.lastPoint
	Check("[NET] Alt + glisser détache le filet et garde sa place ; sans Alt rien ; le relâcher ne lance pas",
		refused and started and saved and saved.point == "CENTER" and saved.x == 120 and saved.y == -40 and notThrown
		and p and p.relTo == UIParent and p.x == 120 and p.y == -40 and net.moved == true,
		tostring(saved and saved.x) .. "/" .. tostring(p and p.relTo == UIParent))
	-- le fil des pastilles suit le filet détaché
	NS:EnsureCaptureExpressFeed()
	local feedMode = NS:CaptureExpressPlace()
	local fp = NS.captureExpressFeed.lastPoint
	Check("[NET] filet détaché : les pastilles express le suivent (sous le filet, ou au-dessus de la barre d'aides)",
		(feedMode == "net-below" or feedMode == "net-above") and fp and fp.relTo == net, tostring(feedMode))
	-- un peu plus tard, le clic lance
	Mock:Advance(1)
	local rolling = NS:CaptureNetClick("LeftButton")
	-- rattacher : réglage et commande
	XP.SeeKill(6401, { name = "Raptor N", spawn = "00001A2B3F" })
	local found
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if (page.id == "companionMain" or page.id == "companionQuiet" or page.id == "companionTalk" or page.id == "companionKeys") then for _, row in ipairs(page.rows) do if row.key == "captureNetAttach" then found = row end end end
	end
	NS:RunOptionAction("captureNetAttach")
	local attached = NS:DB().captureNetPoint == nil and net.lastPoint and net.lastPoint.relTo == NS.companionFrame
	NS:DB().captureNetPoint = { point = "CENTER", x = 10, y = 10 }
	NS.EXTRA_COMMANDS["filet"](NS, "rattacher")
	Check("[NET] le clic suivant lance ; « Rattacher le filet au compagnon » (réglage, /qc filet rattacher) le recolle au portrait",
		rolling and found and found.kind == "action" and attached and NS:DB().captureNetPoint == nil)
	_G.IsAltKeyDown = savedAlt
end

-- Rendu au harnais
for _, name in ipairs(GLOBALS) do _G[name] = XP.saved[name] end
math.random = XP.random
NS.CaptureRollQuality = XP.rollQuality
NS.captureExpressDormant = XP.dormant
for _, field in ipairs({ "captureExpressFeed", "captureQueueList", "captureAidBar" }) do
	if NS[field] then NS[field]:Hide() end
end
