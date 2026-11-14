-- Les fenêtres de capture (CaptureStage.lua, CaptureQueue.lua, CaptureBatch.lua) :
-- la carte d'un lancer seul en Azeroth (parchemin, encadré, plaque, chance et
-- aides, verdict, pied ; un invariant de placement au lieu des mesures de
-- bêta), l'échappée et la brillante, le bouclier gris absent, Échap avant le
-- verdict ; le choix au filet (côté du filet, boutons) ; la volée de « Tout
-- capturer » (icône du type au lieu du modèle 3D et nombre d'étoiles dans
-- l'écu : retours en jeu 2.9.1) ; le repli Sobre sans le bois ; le style
-- Sobre ; le changement de style pendant une scène.
-- 3.1.0 : affirme l'ancien habillage (carnet en parchemin, scènes en bois, bandeaux
-- dorés, anneau) : le drapeau QNS.AZEROTH_LEGACY rallumé pour tout le module
-- (remis à la valeur du produit à sa fin, tests/run_tests.lua)
T.Legacy(true)
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local SZ = { saved = {}, random = math.random, units = {}, sounds = {} }
SZ.rollQuality = NS.CaptureRollQuality   -- 2.15.0 : rendue à la fin du module
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"InCombatLockdown", "UnitAffectingCombat", "PlaySound", "C_Texture" }
for _, name in ipairs(GLOBALS) do SZ.saved[name] = rawget(_G, name) end
SZ.savedShiny = NS.SHINY_CHANCE
SZ.savedWidth = _G.UIParent.width
SZ.savedAnim, SZ.savedStyle = NS:DB().companionCaptureAnim, NS:DB().companionStyle
local PLAYER = "Player-1-00000001"
local WOOD = NS.AZEROTH_WOOD
local AZS, AZB, AZC = NS.CAPTURE_STAGE_AZEROTH, NS.CAPTURE_BATCH_AZEROTH, NS.CAPTURE_CHOOSER_AZEROTH

function SZ.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function SZ.Install()
	local w = SZ
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
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.PlaySound = function(id) w.sounds[#w.sounds + 1] = id; return true end
end
local FIELDS = { "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt",
	"captureQueueList", "captureNetButton", "captureToast", "captureResult", "guildFeatToast", "journalToast" }
local SCENES = { "captureStage", "captureBatchFrame", "captureChooser" }
local CACHES = { "captureStages", "captureBatchFrames", "captureChoosers" }
local function HideScenes()
	for _, field in ipairs(SCENES) do
		local frame = NS[field]
		if frame then frame:Hide(); frame.rolling = nil end
	end
	for _, field in ipairs(CACHES) do
		for _, frame in pairs(NS[field] or {}) do frame:Hide(); frame.rolling = nil end
	end
end
function SZ.Reset(atlas)
	ResetWorld()
	-- 2.15.0 : qualité tirée au coup fatal figée à 1 étoile (sauf SZ.quality) :
	-- les chances attendues restent celles du rang
	SZ.quality = nil
	NS.CaptureRollQuality = function() return SZ.quality or 1 end
	HideScenes()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureToastHideAt, NS.captureAppCache, NS.captureBatch = nil, nil, nil
	NS.captureResultPending, NS.captureResultHideAt = nil, nil
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	SZ.units, SZ.sounds = {}, {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	SZ.Install()
	if atlas == false then Mock.InstallAtlas(nil) else Mock.InstallAtlas(atlas or true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = "azeroth"
	NS.SHINY_CHANCE = 0
	math.random = SZ.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = true
	-- 2.15.0 : ces scénarios jouent le lancer d'un clic (réglage « Lancer directement au clic ») ;
	-- la carte de préparation a les siens (capture_preparation.lua)
	NS:DB().companionCaptureDirect = true
	NS:DB().captureMuteUntil = nil
	NS:DB().companionCaptureSound = true
	NS:DB().companionCaptureToast = true
	-- 2.14.0 : sans le décor du Voile d'hiver (l'horloge des tests tombe le
	-- 1er janvier 1970, en saison) : le filet garde son glyphe
	NS:DB().winterVeil = "off"
	NS:CompanionUpdateVisibility()
end
function SZ.Roll(value)
	math.random = function(a, b)
		if a and b then return SZ.random(a, b) end
		if a then return SZ.random(a) end
		return value
	end
end
function SZ.SeeKill(npcID, fields)
	fields = fields or {}
	fields.guid = fields.guid or SZ.Guid(npcID, fields.spawn)
	fields.name = fields.name or ("Bête " .. npcID)
	SZ.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, fields.guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, fields.guid, 0)
	return fields.guid
end
-- l'horloge jusqu'au verdict du lancer seul (au plus 10 s)
function SZ.UntilVerdict()
	local tries = 0
	while NS.captureState.rolling and not NS.captureState.rolling.result and tries < 10 do
		Mock:Advance(1); NS:CaptureTick(NS.Now()); tries = tries + 1
	end
	return NS.captureState.rolling
end
-- puis jusqu'à la fermeture de la scène ; rend le bandeau « Capturé ! » s'il est apparu
function SZ.Close(seconds)
	local seen
	for _ = 1, seconds or 6 do
		Mock:Advance(1)
		NS:CaptureTick(NS.Now())
		if NS.captureResult and NS.captureResult:IsShown() then seen = seen or NS.captureResult end
	end
	return seen
end
local function Y(region) return region.lastPoint and region.lastPoint.y or 0 end
local function Has(list, value) for _, v in ipairs(list) do if v == value then return true end end return false end
local function NoErrors()
	local list = {}
	for _, e in ipairs(NS.errors or {}) do list[#list + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
	return #list == 0, table.concat(list, " | ")
end

-- 1. La scène d'un lancer seul, réussie --------------------------------------------------------------
do
	Say("-- scène de capture : lancer seul (Azeroth)")
	SZ.Reset()
	SZ.SeeKill(8100, { name = "Grand trotteur" })
	SZ.Roll(0)
	NS:CaptureThrow()
	local stage = NS.captureStage
	Check("[AZS] atlas présents : la scène Azeroth s'ouvre (fenêtre à part, son nom pour Échap)", NS:AzerothScenesOn()
		and NS:AzerothSceneAtlasOK() and stage and stage:IsShown() and stage.azeroth and stage.uiStyle == "azeroth"
		and Has(_G.UISpecialFrames, "QuestCompanionCaptureStageAzeroth") and stage:GetWidth() == AZS.w and stage:GetHeight() == AZS.h,
		stage and tostring(stage:GetName()))
	-- 2.14.0 (bêta 3) : carte compacte de parchemin, plus le grand cadre en bois sombre
	local K = NS.AZEROTH_CARD
	local border, pieces = stage.cardBorder, 0
	for _, tex in pairs(border and border.pieces or {}) do if tex.texture == 130672 then pieces = pieces + 1 end end
	Check("[AZC14] carte de parchemin (130661, voile « page »), encadré fin en bois (8 morceaux) et filet d'or, gardée à l'écran",
		stage.chrome == "card" and stage.cardParch.texture == 130661 and stage.cardParch:IsShown() and stage.cardParch.texCoord[2] < 1
		and stage.cardVeil.azVeilKey == "page" and stage.cardBack ~= nil and pieces == 8 and border == stage.azWoodBorder
		and #stage.cardGold == 4 and stage.clampInset == K.out, pieces)
	Check("[AZC14] plus de fond sombre, de grand bois ni de boîte noire derrière la créature", stage.wood == nil and stage.woodBg == nil
		and not stage.accent and not stage.topBar and stage.stageBg == nil and stage.stageTop == nil and stage.stageBottom == nil
		and NS.CAPTURE_CLIENT_ART.stage == nil)
	local ground = stage.ground
	Check("[AZC14] ombre au sol : lueur douce du client, sombre, peu opaque, sous la scène", ground
		and ground.atlas == "ChallengeMode-SoftYellowGlow" and ground.vertex[1] < 0.2 and ground.vertex[4] <= 0.6
		and ground.vertex[4] > 0.2 and ground.lastPoint.relTo == stage.scene, ground and ground.atlas)
	local info = stage.info
	local ink = NS.AZEROTH_INK[NS.AZEROTH_CONTRAST["stage.chance"][1]]
	Check("[AZC14] « Chance 50 % » puis les étoiles à gagner (étoiles du client), encre mesurée", info and stage.details:IsShown()
		and info:GetText():find("^Chance 50 %%") ~= nil
		and select(2, info:GetText():gsub("auctionhouse%-icon%-favorite%-off", "")) == 3
		and info.azRole == "stage.chance" and info.textColor[1] == ink[1], info and info:GetText())
	local cells, icons = stage.aidCells, 0
	for index, cell in ipairs(cells) do
		if cell.icon.texture == NS.CAPTURE_AIDS[index].icon and cell.edge:GetParent() == stage.details then icons = icons + 1 end
	end
	Check("[AZC14] les aides sous la chance (trois cases grisées), pied « Le filet bouge… » à l'encre mesurée", icons == 3
		and #cells == 3 and cells[1].icon.alpha < 1 and not cells[1].chosen and stage.details.lastPoint.relTo == stage.scene
		and stage.footer:GetText() == NS.L.CAPTURE_SHAKING and stage.footer.azRole == "stage.status", icons)
	local plate = stage.plate
	Check("[AZS] plaque « CAPTURE · NORMAL » et le nom ; le modèle et notre filet dans la scène", plate
		and plate.bg.atlas == "ui-achievement-alert-background-mini" and plate.title:GetText() == "CAPTURE · NORMAL"
		and plate.text:GetText() == "Grand trotteur" and plate.lastPoint.relTo == stage
		and stage.model and stage.model:GetParent() == stage.scene and stage.net.texture == NS.CAPTURE_ART.net)
	-- pendant le lancer et les secousses : pas de halo ; les secousses : losanges d'or sous la scène
	local r0 = NS.captureState.rolling
	NS:CaptureStageUpdate(r0.start + NS.CAPTURE_THROW_TIME * 0.5)
	local throwHalo = stage.halo:IsShown()
	NS:CaptureStageUpdate(r0.start + NS.CAPTURE_THROW_TIME + 0.1)
	local dot1, dot3 = stage.shakeDots[1], stage.shakeDots[3]
	local dots = dot1:IsShown() and dot1.lastPoint.relTo == stage.scene and dot1.vertex[4] == 1 and dot3.vertex[4] < 0.5
	NS:CaptureStageUpdate(r0.start + NS.CAPTURE_THROW_TIME + 0.5)
	Check("[AZC14] pas de halo pendant le lancer ni les secousses ; secousses en losanges d'or", not throwHalo
		and not stage.halo:IsShown() and stage.ground:IsShown() and stage.details:IsShown() and dots)
	local rolling = SZ.UntilVerdict()
	Check("[AZS] verdict tombé : la scène le montre, pas de bandeau « Capturé ! » en attente", rolling and rolling.result == "ok"
		and rolling.sceneVerdict == true and NS.captureResultPending == nil)
	NS:CaptureStageUpdate(rolling.resultAt + 0.6)
	local banner = stage.banner
	Check("[AZS] bandeau de verdict : fond des hauts faits, « CAPTURÉ ! », bouclier d'or et son éclat, étoiles ; chance et aides cachées",
		banner:IsShown() and banner.azeroth and banner.bg.atlas == "ui-achievement-alert-background"
		and banner.title:GetText() == "CAPTURÉ !" and banner.text:GetText() == "Grand trotteur" and banner.shieldKind == "gold"
		and banner.shield.atlas == "ui-achievement-shield-1" and banner.shield:IsShown() and banner.bling:IsShown()
		and stage.starSlots[1]:GetParent() == banner and stage.starSlots[1]:IsShown() and stage.ribbonPanel == nil
		and not stage.details:IsShown())
	-- 2.14.0 (bêta 4) : le bandeau tenait tout le bas de la carte ; un invariant : il tient dans la carte,
	-- au-dessus du pied, et le pied au-dessus de l'encadré
	local vs = AZS.verdictScale
	local vw = AZS.verdictW * vs
	local footerBottom = Y(stage.footer)
	local verdictBottom = AZS.h + AZS.verdictY - AZS.verdictH   -- depuis le bas du cadre
	Check("[AZS4] verdict dans la carte (marges), pied entre l'encadré et le bandeau, pas plus large que la carte",
		math.abs(banner:GetScale() - vs) < 1e-6 and vw <= AZS.w - 60 and stage.footer.lastPoint.relTo == stage
		and footerBottom >= NS.AZEROTH_CARD.gold + 2 and footerBottom + 14 <= verdictBottom
		and stage.footer.width <= AZS.w - 2 * NS.AZEROTH_CARD.pad, footerBottom .. " / " .. verdictBottom)
	NS:CaptureStageUpdate(rolling.resultAt + 1.5)
	local closeText = stage.footer:GetText() == NS.L.CAPTURE_STAGE_CLOSE
	stage.scripts.OnMouseUp(stage)
	local seen = SZ.Close(6)
	Check("[AZS] « Clic ou Échap pour fermer » ; un clic ferme, sans bandeau « Capturé ! » en double", closeText and not seen
		and NS.captureState.rolling == nil and NS.captureResultPending == nil)
end

-- 2. Échappée, brillante, bouclier gris -------------------------------------------------------------
do
	Say("-- scène de capture : échappée et brillante")
	SZ.Reset()
	NS:CaptureOffer(SZ.Guid(8200, "0000005H1N"), { zoneID = 1413, npcID = 8200 }, { name = "Trotteur" })
	SZ.Roll(0.99)
	NS.CaptureChance = (function(base) SZ.chance = base; return function() return 0, false end end)(NS.CaptureChance)
	NS:CaptureThrow()
	NS.CaptureChance = SZ.chance
	local stage = NS.captureStage
	local gold = stage.azeroth and stage.plate.text:GetText():find("Trotteur", 1, true) and stage.plate.text.textColor[3] < 0.6
	local rolling = SZ.UntilVerdict()
	NS:CaptureStageUpdate(rolling.resultAt + 0.6)
	local banner = stage.banner
	-- 2.14.0 (bêta 3) : l'ombre au sol suit la fuite et s'efface avec la créature
	Check("[AZS] brillante : nom en or ; échappée : « ÉCHAPPÉ… », bouclier gris, filet déchiré, l'ombre suit et pâlit", gold
		and rolling.result == "fail" and banner:IsShown() and banner.title:GetText() == "ÉCHAPPÉ…"
		and banner.text:GetText() == NS.L.CAPTURE_STAGE_FAIL and banner.shieldKind == "grey"
		and banner.shield.atlas == "ui-achievement-shield-1-desaturated" and not banner.bling:IsShown()
		and stage.torn == true and stage.net.texCoord[1] == NS.CAPTURE_COORDS.netTorn[1]
		and stage.ground.lastPoint.x > 20 and stage.ground.vertex[4] < NS.CAPTURE_STAGE_SHADOW.alpha.azeroth, banner.title:GetText())
	-- les aides : celle du lancer allumée, le nombre en poche ; les étoiles du spécimen pris
	NS:CaptureData().items.lasso = 2
	NS:CaptureData().creatures[8299] = { stars = 2, at = 1 }
	NS:CaptureStageDetails(stage, { target = { npcID = 8299, name = "Pris" }, aid = "lasso", chance = 0.8 })
	local lasso, bait = stage.aidCells[2], stage.aidCells[1]
	local stars = stage.info:GetText()
	local aidLit = lasso.id == "lasso" and lasso.chosen and lasso.icon.alpha == 1 and lasso.edge.vertex[1] == NS.Theme.GOLD[1]
		and lasso.count:GetText() == "2" and not bait.chosen and bait.icon.alpha < 1 and lasso.count.azRole == "stage.aidCount"
	NS:CaptureStageDetails(stage, { target = { npcID = 8298, name = "Sûr" }, aid = "sifflet", chance = 1 })
	Check("[AZC14] aide du lancer allumée (liseré d'or, nombre en poche) ; chance aide comprise, étoiles du spécimen ; Sifflet : assurée",
		aidLit and stars:find("^Chance 80 %%") ~= nil and select(2, stars:gsub("favorite:14", "")) == 2
		and select(2, stars:gsub("favorite%-off:14", "")) == 1
		and stage.info:GetText():find(NS.L.CAPTURE_STAGE_SURE, 1, true) == 1, stars)
	NS:CaptureData().creatures[8299] = nil
	stage.scripts.OnMouseUp(stage)
	SZ.Close(5)
	-- pas de bouclier gris dans ce client : le doré, désaturé
	SZ.Reset({ ["ui-achievement-shield-1-desaturated"] = true })
	SZ.SeeKill(8201, { name = "Fuyard" })
	SZ.Roll(0.99)
	NS.CaptureChance = (function(base) SZ.chance = base; return function() return 0, false end end)(NS.CaptureChance)
	NS:CaptureThrow()
	NS.CaptureChance = SZ.chance
	stage = NS.captureStage
	rolling = SZ.UntilVerdict()
	NS:CaptureStageUpdate(rolling.resultAt + 0.6)
	Check("[AZS] sans bouclier gris : le doré désaturé", stage.azeroth and stage.banner.shield.atlas == "ui-achievement-shield-1"
		and stage.banner.shieldKind == "grey", tostring(stage.banner.shield.atlas) .. "," .. tostring(rolling and rolling.result))
	stage.scripts.OnMouseUp(stage)
	SZ.Close(5)
	-- Échap avant le verdict : la scène ne l'a pas montré, le bandeau « Capturé ! » le dira
	SZ.Reset()
	SZ.SeeKill(8202, { name = "Kodo" })
	SZ.Roll(0)
	NS:CaptureThrow()
	stage = NS.captureStage
	stage:Hide()
	stage.scripts.OnHide(stage)
	SZ.UntilVerdict()
	local pending = NS.captureResultPending ~= nil and NS.captureResultPending.name == "Kodo"
	local seen = SZ.Close(4)
	Check("[AZS] scène fermée avant le verdict : le bandeau « Capturé ! » est retenu, puis s'affiche", pending
		and seen and seen.text:GetText() == "Kodo")
	NS:CaptureResultHide()
end

-- 3. Le choix au filet ------------------------------------------------------------------------------
do
	Say("-- scène de capture : le choix au filet")
	SZ.Reset()
	SZ.SeeKill(8300, { name = "Loup gris" })
	SZ.SeeKill(8301, { name = "Raptor" })
	local net = NS.captureNetButton
	_G.UIParent.width = 1000
	net.GetCenter = function() return 900, 400 end
	NS:CaptureNetClick("LeftButton")
	local chooser = NS.captureChooser
	-- 2.11.0 : l'icône du filet du jeu (INV_Misc_Net_01) ; 2.12.1 : plus de glyphe à nous
	Check("[AZS] choix : panneau en bois (nom pour Échap), filet du jeu dans le cadre d'icône, « 2 CRÉATURES DANS LE FILET »",
		chooser and chooser:IsShown() and chooser.azeroth and chooser.wood and chooser.wood.tr.atlas == WOOD.tr
		and Has(_G.UISpecialFrames, "QuestCompanionCaptureChooserAzeroth") and chooser.ring.atlas == "ui-achievement-iconframe"
		and chooser.glyph.texture == NS.CAPTURE_CLIENT_ART.icon.files[1] and chooser.glyph.lastPoint.relTo == chooser.ring
		and chooser.title:GetText() == "2 CRÉATURES DANS LE FILET", chooser and chooser.title:GetText())
	local one, all = chooser.single, chooser.all
	Check("[AZS] choix : deux boutons dorés, « Capturer : … » et sa chance, « Tout capturer (2) » et son coût, raccourcis",
		one.azeroth and all.azeroth and one.style == "gold" and all.style == "dark"
		and one:GetText() == NS:F("CAPTURE_CHOOSE_ONE", "Loup gris") and one.sub:IsShown() and one.sub:GetText():find("%%") ~= nil
		and all:GetText() == NS:F("CAPTURE_CHOOSE_ALL", 2) and all.sub:GetText() == NS.L.CAPTURE_CHOOSE_ALL_FREE
		and chooser.hint:GetText() == NS.L.CAPTURE_CHOOSE_KEYS, one.sub:GetText())
	Check("[AZS] choix : à gauche du filet (filet à droite de l'écran), gardé à l'écran", chooser.side == "left"
		and chooser.lastPoint.point == "RIGHT" and chooser.lastPoint.relTo == net and chooser.lastPoint.relPoint == "LEFT"
		and chooser.clampInset == NS.AZEROTH_WOOD_OUT)
	NS:CaptureData().items.lasso = 3
	NS:CaptureToggleAid("lasso")
	NS:CaptureChooserRefresh()
	Check("[AZS] choix : « chaque essai coûte : Lasso »", all.sub:GetText() == NS:F("CAPTURE_CHOOSE_ALL_AID", NS:CaptureAidLabel("lasso")))
	NS:CaptureChooserHide()
	net.GetCenter = function() return 100, 400 end
	NS:CaptureNetClick("LeftButton")
	local right = chooser:IsShown() and chooser.side == "right" and chooser.lastPoint.point == "LEFT" and chooser.lastPoint.relPoint == "RIGHT"
	one:Click()
	Check("[AZS] choix : à droite du filet (filet à gauche) ; « Capturer » lance le filet", right and not chooser:IsShown()
		and NS.captureState.rolling ~= nil)
	net.GetCenter = nil
	_G.UIParent.width = SZ.savedWidth
	local missing = {}
	for key in pairs(NS.CAPTURE_BATCH_STRINGS.fr) do if not NS.CAPTURE_BATCH_STRINGS.en[key] then missing[#missing + 1] = key end end
	for key in pairs(NS.CAPTURE_BATCH_STRINGS.en) do if not NS.CAPTURE_BATCH_STRINGS.fr[key] then missing[#missing + 1] = key end end
	Check("[AZS] textes : mêmes clés en français et en anglais", #missing == 0, table.concat(missing, ", "))
end

-- 4. Tout capturer -------------------------------------------------------------------------------------
do
	Say("-- scène de capture : la volée")
	SZ.Reset()
	NS.errors = {}
	for index = 1, 5 do SZ.SeeKill(8400 + index, { name = "Bête " .. index }) end
	NS:CaptureOffer(SZ.Guid(8406, "0000005H1N"), { zoneID = 1413, npcID = 8406 }, { name = "Brillant" })
	local base = NS.CaptureChance
	NS.CaptureChance = function(self, info, ...)
		if info and info.npcID == 8402 then return 0, false end
		return 0.95, false
	end
	SZ.Roll(0.5)
	local batch = NS:CaptureBatch()
	NS.CaptureChance = base
	local frame = NS.captureBatchFrame
	local cols, rows = NS:CaptureBatchGrid(6, true)
	Check("[AZS] volée : fenêtre en bois à part, plaque « TOUT CAPTURER », « Captures : 0 », Arrêter, 6 cases en 2 × 3",
		batch and batch.tried == 6 and frame:IsShown() and frame.azeroth and frame.wood.bottom.atlas == WOOD.bottom
		and Has(_G.UISpecialFrames, "QuestCompanionCaptureBatchAzeroth") and frame.plate.title:GetText() == "TOUT CAPTURER"
		and frame.counter == frame.plate.text and frame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 0)
		and frame.stop.azeroth and frame.stop:GetText() == NS.L.CAPTURE_BATCH_STOP and cols == 3 and rows == 2)
	local tile = frame.tiles[1]
	local beast = tile
	for _, card in ipairs(batch.cards) do if card.result.target.npcID == 8401 then beast = card.tile end end
	-- 2.9.1 (retour en jeu) : l'icône fixe du type remplace le modèle 3D, mal cadré
	local icons = NS.MENAGERIE_TYPE_ICONS or {}
	local hole = NS.AZEROTH_ICON_HOLE
	local size = math.floor(AZB.ring * (hole.r - hole.l) + 0.5)
	Check("[R291] case : l'icône du type (Bête) dans le cadre d'icône doré, à la taille de son trou, sans modèle 3D", tile.az
		and tile.ring.atlas == "ui-achievement-iconframe" and tile.fx.level > tile.ringFrame.level and tile.model == nil
		and not tile.hasModel and frame.tiles[2].model == nil and beast.fallback.texture == icons["Bête"]
		and tile.fallback.width == size and tile.fallback.height == size and tile.fallback:IsShown()
		and tile.fallback:GetParent() == tile.scene and tile.scene.clipsChildren == true, tostring(beast.fallback.texture))
	Check("[AZS] avant le verdict : ni bouclier ni nombre ; la brillante tombe en dernier", not tile.shield:IsShown()
		and not tile.shieldText:IsShown() and batch.order[#batch.order].result.target.shiny == true)
	NS:CaptureBatchStop(true)
	local ok, okCard, fled, shinyTile
	for _, card in ipairs(batch.cards) do
		local t = card.tile
		if card.result.target.shiny then shinyTile = t
		elseif card.result.success then ok = ok or t; okCard = okCard or card
		else fled = fled or t end
	end
	local point = ok and ok.shieldText.lastPoint
	Check("[R291] prise : bouclier d'or au coin portant le nombre d'étoiles, centré dessus, la créature reste visible", ok
		and ok.shield:IsShown() and ok.shieldKind == "gold" and ok.shield.atlas == "ui-achievement-shield-1"
		and ok.shield.lastPoint.point == "TOPRIGHT" and ok.shieldText:IsShown()
		and ok.shieldText:GetText() == tostring(okCard.result.stars or 1) and point and point.point == "CENTER"
		and point.relTo == ok.shield and ok.fallback:IsShown()
		and (ok.stars:GetText() or ""):find("|A:auctionhouse-icon-favorite:", 1, true) ~= nil, ok and tostring(ok.shieldText:GetText()))
	Check("[AZS] échappée : ni bouclier ni nombre, « échappée » ; brillante : nom en or, lueur, « BRILLANTE »", fled
		and fled.shieldKind == nil and not fled.shield:IsShown() and not fled.shieldText:IsShown()
		and fled.stars:GetText() == NS.L.CAPTURE_BATCH_FLED and shinyTile and shinyTile.name.textColor[3] < 0.6
		and shinyTile.halo:IsShown() and shinyTile.tag:GetText() == "BRILLANTE")
	Check("[AZS] volée finie : Fermer, « Captures : 5 », pied dans le cadre au-dessus du bois", frame.stop:GetText() == NS.L.CAPTURE_BATCH_CLOSE
		and frame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 5) and Y(frame.footer) >= NS.AZEROTH_WOOD_INSET + 4
		and frame.footer:GetText() == NS.L.CAPTURE_BATCH_DONE)
	frame.stop:Click()
	frame.scripts.OnHide(frame)
	local closed = not frame:IsShown() and not tile.hasModel
	-- un second lot : les mêmes cases resservent
	SZ.SeeKill(8410, { name = "Loup" })
	SZ.SeeKill(8411, { name = "Ours" })
	SZ.Roll(0)
	NS:CaptureBatch()
	local okErr, errs = NoErrors()
	Check("[AZS] Fermer : la volée se ferme ; second lot : même fenêtre, mêmes cases ; sans erreur", closed
		and NS.captureBatchFrame == frame and frame.tiles[1] == tile and frame.tiles[3] and not frame.tiles[3]:IsShown() and okErr, errs)
	NS:CaptureBatchStop(true)
	frame:Hide()
	frame.scripts.OnHide(frame)
end

-- 5. Le bois manque : fenêtres Sobre (les bandeaux gardent Azeroth) -----------------------------------
do
	Say("-- scène de capture : repli Sobre sans le bois")
	SZ.Reset({ ["_achievement-wood-nineslice-edgetop"] = true })
	SZ.SeeKill(8500, { name = "Sanglier" })
	SZ.SeeKill(8501, { name = "Loup" })
	NS:CaptureNetClick("LeftButton")
	local chooser = NS.captureChooser
	Check("[AZS] bois absent : bandeaux en Azeroth, fenêtres en Sobre (le choix Sobre)", NS:AzerothOn() and not NS:AzerothScenesOn()
		and chooser and chooser:IsShown() and not chooser.azeroth and chooser.uiStyle == "sobre"
		and chooser.hint:GetText() == NS.L.CAPTURE_CHOOSE_PAUSED)
	SZ.Roll(0)
	chooser.single:Click()
	local stage = NS.captureStage
	local sobreStage = stage and stage:IsShown() and not stage.azeroth and stage.topBar and stage.ribbonPanel
		and Has(_G.UISpecialFrames, "QuestCompanionCaptureStage")
	SZ.UntilVerdict()
	local pending = NS.captureResultPending ~= nil
	stage.scripts.OnMouseUp(stage)
	SZ.Close(5)
	NS:CaptureResultHide()
	SZ.Roll(0)
	SZ.SeeKill(8502, { name = "Ours" })
	NS:CaptureBatch()
	local frame = NS.captureBatchFrame
	Check("[AZS] repli : scène Sobre (le bandeau « Capturé ! » reste), volée Sobre", sobreStage and pending
		and frame and frame:IsShown() and not frame.azeroth and frame.close and not frame.tiles[1].az)
	NS:CaptureBatchStop(true)
	frame:Hide()
	frame.scripts.OnHide(frame)
end

-- 6. Style Sobre ------------------------------------------------------------------------------------
do
	Say("-- scène de capture : style Sobre")
	SZ.Reset()
	NS:SetUIStyle("sobre")
	SZ.SeeKill(8600, { name = "Raptor" })
	SZ.Roll(0)
	NS:CaptureThrow()
	local stage = NS.captureStage
	-- 2.14.0 (bêta 3) : même disposition que la carte Azeroth, sur le fond sombre du socle
	Check("[AZC14] Sobre : carte compacte, « CAPTURE · NORMAL », le nom, la scène sans boîte noire et son ombre, chance et aides dessous, ruban posé dessus",
		stage and not stage.azeroth and stage.ribbonPanel and stage.topBar and not stage.plate and stage.cardParch == nil
		and stage.title:GetText() == "CAPTURE · NORMAL" and stage.name:GetText() == "Raptor" and stage.stageBg == nil
		and stage.ground and stage.ground.vertex[1] == NS.Theme.SHADOW[1] and stage.info:GetText():find("^Chance 50 %%") ~= nil
		and #stage.aidCells == 3 and stage.details:IsShown() and stage.details.lastPoint.relTo == stage.scene
		and stage.footer:GetText() == NS.L.CAPTURE_SHAKING and stage.info.azRole == nil
		and stage.banner.lastPoint.relTo == stage.scene and stage.starSlots[1].lastPoint.relTo == stage.banner,
		stage and stage.title:GetText())
	local rolling = SZ.UntilVerdict()
	local waits = not rolling.sceneVerdict and NS.captureResultPending ~= nil
	stage.scripts.OnMouseUp(stage)
	local seen = SZ.Close(5)
	Check("[AZS] Sobre : le verdict n'est pas montré par la scène, « Capturé ! » après sa fermeture", waits and seen and not seen.azeroth)
	NS:CaptureResultHide()
	NS:SetUIStyle("azeroth")
end

-- 7. Changement de style pendant une scène ---------------------------------------------------------
do
	Say("-- scène de capture : changement de style en direct")
	SZ.Reset()
	SZ.SeeKill(8700, { name = "Kodo" })
	SZ.Roll(0)
	NS:CaptureThrow()
	local az = NS.captureStage
	local ok = pcall(NS.SetUIStyle, NS, "sobre")
	local kept = ok and NS.captureStage == az and az:IsShown() and NS:EnsureCaptureStage() == az
	local done = pcall(function()
		local rolling = SZ.UntilVerdict()
		NS:CaptureStageUpdate(rolling.resultAt + 0.5)
	end)
	Check("[AZS] → Sobre pendant la scène : sans erreur, elle finit telle quelle (bandeau Azeroth)", kept and done
		and az.banner:IsShown() and az.banner.title:GetText() == "CAPTURÉ !")
	az.scripts.OnMouseUp(az)
	SZ.Close(5)
	az.scripts.OnHide(az)
	SZ.SeeKill(8701, { name = "Ours" })
	SZ.Roll(0)
	NS:CaptureThrow()
	local sobre = NS.captureStage
	local next1 = sobre and sobre ~= az and not sobre.azeroth and sobre:IsShown()
	sobre:Hide(); sobre.scripts.OnHide(sobre)
	SZ.UntilVerdict()
	SZ.Close(5)
	NS:SetUIStyle("azeroth")
	SZ.SeeKill(8702, { name = "Loup" })
	SZ.Roll(0)
	NS:CaptureThrow()
	Check("[AZS] scène suivante en Sobre ; → Azeroth : la même scène revient (gardée)", next1 and NS.captureStage == az and az:IsShown())
	az:Hide(); az.scripts.OnHide(az)
	SZ.UntilVerdict()
	SZ.Close(5)
	-- le choix : ouvert pendant le changement, il reste ; rouvert, il change
	SZ.SeeKill(8710, { name = "A" })
	SZ.SeeKill(8711, { name = "B" })
	NS:CaptureNetClick("LeftButton")
	local chooserAz = NS.captureChooser
	ok = pcall(NS.SetUIStyle, NS, "sobre")
	local stays = ok and chooserAz.azeroth and chooserAz:IsShown()
	NS:CaptureChooserHide()
	NS:CaptureNetClick("LeftButton")
	Check("[AZS] choix ouvert, → Sobre : il reste ; rouvert : Sobre", stays and NS.captureChooser ~= chooserAz
		and not NS.captureChooser.azeroth and NS.captureChooser:IsShown())
	NS:CaptureChooserHide()
	-- la volée : Sobre maintenant, Azeroth gardée pour plus tard
	SZ.Roll(0)
	NS:CaptureBatch()
	local frame = NS.captureBatchFrame
	ok = pcall(NS.SetUIStyle, NS, "azeroth")
	Check("[AZS] volée ouverte, → Azeroth : sans erreur, elle finit en Sobre", ok and frame and not frame.azeroth and frame:IsShown()
		and pcall(NS.CaptureBatchUpdate, NS, NS.Now() + 5))
	NS:CaptureBatchStop(true)
	frame:Hide()
	frame.scripts.OnHide(frame)
end

-- Rangement
do
	HideScenes()
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:ApplyUIStyle()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	for _, field in ipairs(SCENES) do NS[field] = nil end
	for _, field in ipairs(CACHES) do NS[field] = nil end
	NS.uiStyleCache = {}
	NS.captureResultPending, NS.captureResultHideAt, NS.captureBatch = nil, nil, nil
	for _, name in ipairs(GLOBALS) do _G[name] = SZ.saved[name] end
	_G.UIParent.width = SZ.savedWidth
	math.random = SZ.random
	NS.SHINY_CHANCE = SZ.savedShiny
	NS:DB().companionCaptureAnim, NS:DB().companionStyle = SZ.savedAnim, SZ.savedStyle
	NS:DB().winterVeil = nil
	ResetWorld()
end
NS.CaptureRollQuality = SZ.rollQuality
