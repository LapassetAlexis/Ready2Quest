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
	Check("[EXP] visite guidée en cours : le déroulé d'avant", NS:CaptureExpressOn() == false)
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

-- Rendu au harnais
for _, name in ipairs(GLOBALS) do _G[name] = XP.saved[name] end
math.random = XP.random
NS.CaptureRollQuality = XP.rollQuality
NS.captureExpressDormant = XP.dormant
for _, field in ipairs({ "captureExpressFeed", "captureQueueList" }) do
	if NS[field] then NS[field]:Hide() end
end
