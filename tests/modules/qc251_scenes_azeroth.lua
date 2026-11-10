-- Compagnon : les fenêtres de capture en style « Azeroth » (QuestCompanion
-- 2.5.1) : la scène d'un lancer seul (cadre en bois, plaque, bandeau de
-- verdict or ou gris, pied au-dessus du bois, pas de bandeau « Capturé ! »
-- en double), le choix au filet (bois, boutons dorés, du bon côté du filet,
-- gardé à l'écran), la volée de « Tout capturer » (plaque, cadres d'icône,
-- boucliers, la brillante en dernier), le repli Sobre quand le bois manque,
-- le style Sobre inchangé, le changement de style pendant une scène.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local SZ = { saved = {}, random = math.random, units = {}, sounds = {} }
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

-- 1. La scène d'un lancer seul, réussie --------------------------------------------------------------
do
	Say("-- azeroth 2.5.1 : scène d'un lancer seul")
	SZ.Reset()
	Check("[AZS] atlas présents : fenêtres de capture en Azeroth", NS:AzerothScenesOn() and NS:AzerothSceneAtlasOK())
	SZ.SeeKill(8100, { name = "Grand trotteur" })
	SZ.Roll(0)
	NS:CaptureThrow()
	local stage = NS.captureStage
	Check("[AZS] la scène Azeroth s'ouvre (fenêtre à part, son nom pour Échap)", stage and stage:IsShown() and stage.azeroth
		and stage.uiStyle == "azeroth"
		and Has(_G.UISpecialFrames, "QuestCompanionCaptureStageAzeroth") and stage:GetWidth() == AZS.w and stage:GetHeight() == AZS.h,
		stage and table.concat({ tostring(stage:IsShown()), tostring(stage.azeroth), tostring(stage:GetName()),
		tostring(Has(_G.UISpecialFrames, "QuestCompanionCaptureStageAzeroth")), tostring(stage:GetWidth()), tostring(stage:GetHeight()) }, ","))
	-- 2.14.0 (bêta 3) : carte compacte de parchemin (maquette A), plus le grand cadre en bois sombre
	local K = NS.AZEROTH_CARD
	Check("[AZC14] carte compacte : plus petite que l'ancienne fenêtre (360×504)", AZS.w <= 340 and AZS.h <= 420
		and AZS.w * AZS.h < 360 * 504 * 0.8, AZS.w .. "×" .. AZS.h)
	Check("[AZC14] parchemin des hauts faits (130661) recadré, voile « page », aplat dessous", stage.chrome == "card"
		and stage.cardParch.texture == 130661 and stage.cardParch:IsShown() and stage.cardParch.texCoord[2] < 1
		and stage.cardVeil.azVeilKey == "page" and stage.cardBack ~= nil)
	local border, pieces = stage.cardBorder, 0
	for _, tex in pairs(border and border.pieces or {}) do if tex.texture == 130672 then pieces = pieces + 1 end end
	Check("[AZC14] encadré fin en bois (130672, huit morceaux) et filet d'or dedans", pieces == 8 and border == stage.azWoodBorder
		and #stage.cardGold == 4 and stage.cardGold[1].lastPoint.y == -K.gold, pieces)
	Check("[AZC14] plus de fond sombre ni de grand bois", stage.wood == nil and stage.woodBg == nil and not stage.accent and not stage.topBar)
	Check("[AZS] gardée à l'écran, encadré compris", stage.clampInset == K.out)
	Check("[AZC14] pas de boîte noire (vignette) derrière la créature", stage.stageBg == nil and stage.stageTop == nil
		and stage.stageBottom == nil and NS.CAPTURE_CLIENT_ART.stage == nil)
	local ground, SH = stage.ground, NS.CAPTURE_STAGE_SHADOW
	Check("[AZC14] ombre au sol : lueur douce du client, grisée, sombre, peu opaque, sous les pattes",
		ground and ground.atlas == "ChallengeMode-SoftYellowGlow" and ground.drawLayer == "BORDER"
		and ground.vertex[1] < 0.2 and ground.vertex[4] <= 0.6 and ground.vertex[4] > 0.2
		and ground.lastPoint.relTo == stage.scene and ground.lastPoint.y == SH.y and SH.y < -SH.h
		and ground.width > ground.height * 3, ground and ground.atlas)
	local info = stage.info
	Check("[AZC14] « Chance 50 % » puis les étoiles à gagner (étoiles du client)", info and stage.details:IsShown()
		and info:GetText():find("^Chance 50 %%") ~= nil
		and select(2, info:GetText():gsub("auctionhouse%-icon%-favorite%-off", "")) == 3, info and info:GetText())
	local ink = NS.AZEROTH_INK[NS.AZEROTH_CONTRAST["stage.chance"][1]]
	Check("[AZC14] chance à l'encre mesurée", info.azRole == "stage.chance" and info.textColor[1] == ink[1])
	local cells, icons = stage.aidCells, 0
	for index, cell in ipairs(cells) do
		if cell.icon.texture == NS.CAPTURE_AIDS[index].icon and cell.edge:GetParent() == stage.details then icons = icons + 1 end
	end
	Check("[AZC14] les aides du joueur sous la chance (trois cases), aucune choisie : grisées", icons == 3 and #cells == 3
		and cells[1].icon.alpha < 1 and not cells[1].chosen and stage.details.lastPoint.relTo == stage.scene, icons)
	Check("[AZC14] pied « Le filet bouge… » à l'encre mesurée", stage.footer:GetText() == NS.L.CAPTURE_SHAKING
		and stage.footer.azRole == "stage.status")
	-- pendant le lancer et les secousses : pas de halo derrière la créature
	local r0 = NS.captureState.rolling
	NS:CaptureStageUpdate(r0.start + NS.CAPTURE_THROW_TIME * 0.5)
	local throwHalo = stage.halo:IsShown()
	NS:CaptureStageUpdate(r0.start + NS.CAPTURE_THROW_TIME + 0.5)
	Check("[AZC14] pas de halo blanc pendant le lancer ni les secousses", not throwHalo and not stage.halo:IsShown()
		and stage.ground:IsShown() and stage.details:IsShown())
	local plate = stage.plate
	Check("[AZS] plaque de titre : « CAPTURE · NORMAL » et le nom", plate and plate.bg.atlas == "ui-achievement-alert-background-mini"
		and plate.title:GetText() == "CAPTURE · NORMAL" and plate.text:GetText() == "Grand trotteur"
		and plate:GetWidth() == AZS.plateW and plate.lastPoint.relTo == stage and plate.text.textColor[3] == 1)
	Check("[AZS] le modèle et notre filet dans la scène", stage.model and stage.model:GetParent() == stage.scene
		and stage.net.texture == NS.CAPTURE_ART.net)
	-- les secousses : losanges d'or (éteints : or pâle), sous la scène
	NS:CaptureStageUpdate(NS.captureState.rolling.start + NS.CAPTURE_THROW_TIME + 0.1)
	local dot1, dot3 = stage.shakeDots[1], stage.shakeDots[3]
	Check("[AZS] secousses : losanges d'or sous la scène", dot1:IsShown() and dot1.lastPoint.relTo == stage.scene
		and dot1.vertex[4] == 1 and dot3.vertex[4] < 0.5 and math.abs(dot3.vertex[1] - NS.Theme.GOLD[1]) < 1e-6)
	local rolling = SZ.UntilVerdict()
	Check("[AZS] verdict tombé : la scène le montre, pas de bandeau « Capturé ! » en attente", rolling and rolling.result == "ok"
		and rolling.sceneVerdict == true and NS.captureResultPending == nil)
	NS:CaptureStageUpdate(rolling.resultAt + 0.6)
	local banner = stage.banner
	Check("[AZS] bandeau de verdict : fond des hauts faits, « CAPTURÉ ! », le nom", banner:IsShown() and banner.azeroth
		and banner.bg.atlas == "ui-achievement-alert-background" and banner.title:GetText() == "CAPTURÉ !"
		and banner.text:GetText() == "Grand trotteur" and banner:GetWidth() == AZS.verdictW)
	Check("[AZS] bouclier d'or et son éclat", banner.shieldKind == "gold" and banner.shield.atlas == "ui-achievement-shield-1"
		and banner.shield:IsShown() and banner.bling:IsShown() and banner.bling.atlas == "ui-achievement-bling")
	Check("[AZS] les étoiles du spécimen dans le bandeau", stage.starSlots[1]:GetParent() == banner
		and stage.starSlots[1]:IsShown())
	Check("[AZS] l'ancien ruban n'existe pas ici", stage.ribbonPanel == nil and stage.sheen == nil)
	-- 2.14.0 (bêta 3) : le bandeau se pose sur la chance et les aides (cachées), sous l'ombre
	local sceneBottom = -AZS.sceneY + 196
	Check("[AZC14] verdict posé sur la chance et les aides, qui se cachent", not stage.details:IsShown()
		and -AZS.verdictY < sceneBottom and -AZS.verdictY > -AZS.sceneY + 98 - NS.CAPTURE_STAGE_SHADOW.y + NS.CAPTURE_STAGE_SHADOW.h / 2
		and -AZS.verdictY + AZS.verdictH >= sceneBottom + 26 - AZS.aidsY, AZS.verdictY)
	-- le pied : dans la carte, au-dessus de l'encadré, sous le bandeau
	local footerBottom = Y(stage.footer)
	local verdictBottom = AZS.h + AZS.verdictY - AZS.verdictH   -- depuis le bas du cadre
	Check("[AZS] pied au-dessus de l'encadré et du filet d'or", stage.footer.lastPoint.point == "BOTTOM" and stage.footer.lastPoint.relTo == stage
		and footerBottom >= NS.AZEROTH_CARD.gold + 2, footerBottom)
	Check("[AZS] pied sous le bandeau, sans le toucher", footerBottom + 14 <= verdictBottom, footerBottom .. " / " .. verdictBottom)
	Check("[AZS] pied pas plus large que l'intérieur de la carte", stage.footer.width <= AZS.w - 2 * NS.AZEROTH_CARD.pad)
	NS:CaptureStageUpdate(rolling.resultAt + 1.5)
	Check("[AZS] « Clic ou Échap pour fermer »", stage.footer:GetText() == NS.L.CAPTURE_STAGE_CLOSE)
	-- un clic ferme ; ensuite, pas de bandeau « Capturé ! » en double
	stage.scripts.OnMouseUp(stage)
	local seen = SZ.Close(6)
	Check("[AZS] scène refermée : pas de bandeau « Capturé ! » en double", not seen and NS.captureState.rolling == nil
		and NS.captureResultPending == nil)
end

-- 2. Échappée, brillante, bouclier gris -------------------------------------------------------------
do
	Say("-- azeroth 2.5.1 : échappée et brillante")
	SZ.Reset()
	NS:CaptureOffer(SZ.Guid(8200, "0000005H1N"), { zoneID = 1413, npcID = 8200 }, { name = "Trotteur" })
	SZ.Roll(0.99)
	NS.CaptureChance = (function(base) SZ.chance = base; return function() return 0, false end end)(NS.CaptureChance)
	NS:CaptureThrow()
	NS.CaptureChance = SZ.chance
	local stage = NS.captureStage
	Check("[AZS] brillante : le nom en or sur la plaque", stage.azeroth and stage.plate.text:GetText():find("Trotteur", 1, true)
		and stage.plate.text.textColor[3] < 0.6)
	local rolling = SZ.UntilVerdict()
	NS:CaptureStageUpdate(rolling.resultAt + 0.6)
	local banner = stage.banner
	Check("[AZS] échappée : « ÉCHAPPÉ… », la phrase, bouclier gris", rolling.result == "fail" and banner:IsShown()
		and banner.title:GetText() == "ÉCHAPPÉ…" and banner.text:GetText() == NS.L.CAPTURE_STAGE_FAIL
		and banner.shieldKind == "grey" and banner.shield.atlas == "ui-achievement-shield-1-desaturated"
		and not banner.bling:IsShown(), banner.title:GetText())
	Check("[AZS] échappée : notre filet déchiré", stage.torn == true and stage.net.texCoord[1] == NS.CAPTURE_COORDS.netTorn[1])
	-- 2.14.0 (bêta 3) : l'ombre au sol suit la fuite et s'efface avec la créature
	local fleeShadow = stage.ground
	Check("[AZC14] échappée : l'ombre suit la créature qui file et pâlit", fleeShadow.lastPoint.x > 20
		and fleeShadow.lastPoint.y == NS.CAPTURE_STAGE_SHADOW.y and fleeShadow.vertex[4] < NS.CAPTURE_STAGE_SHADOW.alpha.azeroth,
		fleeShadow.lastPoint.x)
	-- les aides : celle du lancer allumée (liseré d'or), le nombre en poche ; les étoiles du spécimen pris
	NS:CaptureData().items.lasso = 2
	NS:CaptureData().creatures[8299] = { stars = 2, at = 1 }
	NS:CaptureStageDetails(stage, { target = { npcID = 8299, name = "Pris" }, aid = "lasso", chance = 0.8 })
	local lasso, bait = stage.aidCells[2], stage.aidCells[1]
	local stars = stage.info:GetText()
	Check("[AZC14] aide du lancer allumée, liseré d'or, nombre en poche ; les autres grisées", lasso.id == "lasso" and lasso.chosen
		and lasso.icon.alpha == 1 and lasso.edge.vertex[1] == NS.Theme.GOLD[1] and lasso.count:GetText() == "2"
		and not bait.chosen and bait.icon.alpha < 1 and lasso.count.azRole == "stage.aidCount")
	Check("[AZC14] chance du lancer (aide comprise), étoiles du spécimen pleines, les autres à gagner",
		stars:find("^Chance 80 %%") ~= nil and select(2, stars:gsub("favorite:14", "")) == 2
		and select(2, stars:gsub("favorite%-off:14", "")) == 1, stars)
	NS:CaptureStageDetails(stage, { target = { npcID = 8298, name = "Sûr" }, aid = "sifflet", chance = 1 })
	Check("[AZC14] Sifflet : « Capture assurée »", stage.info:GetText():find(NS.L.CAPTURE_STAGE_SURE, 1, true) == 1)
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
		and stage.banner.shieldKind == "grey", tostring(stage.azeroth) .. "," .. tostring(stage.banner.shield.atlas) .. "," .. tostring(stage.banner.shieldKind) .. "," .. tostring(rolling and rolling.result))
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
	Check("[AZS] scène fermée avant le verdict : le bandeau « Capturé ! » est retenu", NS.captureResultPending ~= nil
		and NS.captureResultPending.name == "Kodo")
	local seen = SZ.Close(4)
	Check("[AZS] … et s'affiche", seen and seen.text:GetText() == "Kodo")
	NS:CaptureResultHide()
end

-- 3. Le choix au filet ------------------------------------------------------------------------------
do
	Say("-- azeroth 2.5.1 : le choix au filet")
	SZ.Reset()
	SZ.SeeKill(8300, { name = "Loup gris" })
	SZ.SeeKill(8301, { name = "Raptor" })
	local net = NS.captureNetButton
	_G.UIParent.width = 1000
	net.GetCenter = function() return 900, 400 end
	NS:CaptureNetClick("LeftButton")
	local chooser = NS.captureChooser
	Check("[AZS] choix : panneau en bois, son nom pour Échap", chooser and chooser:IsShown() and chooser.azeroth
		and chooser.wood and chooser.wood.tr.atlas == WOOD.tr
		and Has(_G.UISpecialFrames, "QuestCompanionCaptureChooserAzeroth"))
	Check("[AZS] choix : le glyphe du filet dans le cadre d'icône", chooser.ring.atlas == "ui-achievement-iconframe"
		-- 2.11.0 : l'icône du filet du jeu (INV_Misc_Net_01) ; 2.12.1 : plus de glyphe à nous
		and chooser.glyph.texture == NS.CAPTURE_CLIENT_ART.icon.files[1]
		and chooser.glyph.lastPoint.relTo == chooser.ring)
	Check("[AZS] choix : « 2 CRÉATURES DANS LE FILET »", chooser.title:GetText() == "2 CRÉATURES DANS LE FILET", chooser.title:GetText())
	local one, all = chooser.single, chooser.all
	Check("[AZS] choix : deux boutons dorés (principal, secondaire plus sombre)", one.azeroth and all.azeroth
		and one.style == "gold" and all.style == "dark" and one.border and one.border2 and one.gloss
		and one:GetWidth() == AZC.w - 2 * NS.AZEROTH_WOOD_PAD)
	Check("[AZS] choix : « Capturer : … » et sa chance dessous", one:GetText() == NS:F("CAPTURE_CHOOSE_ONE", "Loup gris")
		and one.sub:IsShown() and one.sub:GetText():find("%%") ~= nil, one.sub:GetText())
	Check("[AZS] choix : « Tout capturer (2) » et ce que coûte chaque essai", all:GetText() == NS:F("CAPTURE_CHOOSE_ALL", 2)
		and all.sub:GetText() == NS.L.CAPTURE_CHOOSE_ALL_FREE)
	Check("[AZS] choix : les raccourcis", chooser.hint:GetText() == NS.L.CAPTURE_CHOOSE_KEYS)
	Check("[AZS] choix : à gauche du filet (filet à droite de l'écran)", chooser.side == "left"
		and chooser.lastPoint.point == "RIGHT" and chooser.lastPoint.relTo == net and chooser.lastPoint.relPoint == "LEFT")
	Check("[AZS] choix : gardé à l'écran, bois compris", chooser.clampInset == NS.AZEROTH_WOOD_OUT)
	-- l'aide choisie : la ligne de dessous le dit
	NS:CaptureData().items.lasso = 3
	NS:CaptureToggleAid("lasso")
	NS:CaptureChooserRefresh()
	Check("[AZS] choix : « chaque essai coûte : Lasso »", all.sub:GetText() == NS:F("CAPTURE_CHOOSE_ALL_AID", NS:CaptureAidLabel("lasso")))
	NS:CaptureChooserHide()
	net.GetCenter = function() return 100, 400 end
	NS:CaptureNetClick("LeftButton")
	Check("[AZS] choix : à droite du filet (filet à gauche de l'écran)", chooser:IsShown() and chooser.side == "right"
		and chooser.lastPoint.point == "LEFT" and chooser.lastPoint.relPoint == "RIGHT")
	one:Click()
	Check("[AZS] choix : « Capturer » lance le filet", not chooser:IsShown() and NS.captureState.rolling ~= nil)
	net.GetCenter = nil
	_G.UIParent.width = SZ.savedWidth
	Check("[AZS] textes : mêmes clés en français et en anglais", (function()
		for key in pairs(NS.CAPTURE_BATCH_STRINGS.fr) do if not NS.CAPTURE_BATCH_STRINGS.en[key] then return false end end
		for key in pairs(NS.CAPTURE_BATCH_STRINGS.en) do if not NS.CAPTURE_BATCH_STRINGS.fr[key] then return false end end
		return true
	end)())
end

-- 4. Tout capturer -------------------------------------------------------------------------------------
do
	Say("-- azeroth 2.5.1 : la volée")
	SZ.Reset()
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
	Check("[AZS] volée : fenêtre en bois à part", batch and batch.tried == 6 and frame:IsShown() and frame.azeroth
		and frame.wood.bottom.atlas == WOOD.bottom and Has(_G.UISpecialFrames, "QuestCompanionCaptureBatchAzeroth"))
	Check("[AZS] volée : plaque « TOUT CAPTURER », « Captures : 0 »", frame.plate.title:GetText() == "TOUT CAPTURER"
		and frame.counter == frame.plate.text and frame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 0))
	Check("[AZS] volée : Arrêter, bouton doré en haut à droite", frame.stop.azeroth and frame.stop:GetText() == NS.L.CAPTURE_BATCH_STOP
		and frame.stop.lastPoint.point == "TOPRIGHT" and frame.stop.lastPoint.y == AZB.rowY)
	local cols, rows = NS:CaptureBatchGrid(6, true)
	Check("[AZS] volée : 6 cases en deux rangées de 3", cols == 3 and rows == 2
		and frame:GetWidth() == math.max(AZB.minW, 3 * AZB.tileW + 2 * AZB.gapX + 2 * AZB.pad)
		and frame:GetHeight() == AZB.head + 2 * AZB.tileH + AZB.gapY + AZB.foot, frame:GetWidth() .. "x" .. frame:GetHeight())
	local tile = frame.tiles[1]
	-- 2.9.1 : l'icône fixe du type remplace le modèle 3D (mal cadré)
	Check("[AZS] case : la créature dans le cadre d'icône doré, devant l'icône", tile.az and tile.ring.atlas == "ui-achievement-iconframe"
		and tile.fx.level > tile.ringFrame.level and tile.model == nil
		and tile.fallback:GetParent() == tile.scene and tile.scene.clipsChildren == true)
	Check("[AZS] case : pas de bouclier avant le verdict", not tile.shield:IsShown())
	Check("[AZS] la brillante tombe en dernier", batch.order[#batch.order].result.target.shiny == true)
	NS:CaptureBatchStop(true)
	local ok, fled, shinyTile
	for _, card in ipairs(batch.cards) do
		local t = card.tile
		if card.result.target.shiny then shinyTile = t
		elseif card.result.success then ok = ok or t
		else fled = fled or t end
	end
	Check("[AZS] prise : bouclier d'or au coin, étoiles", ok and ok.shield:IsShown() and ok.shieldKind == "gold"
		and ok.shield.atlas == "ui-achievement-shield-1" and ok.shield.lastPoint.point == "TOPRIGHT"
		and (ok.stars:GetText() or ""):find("|A:auctionhouse-icon-favorite:", 1, true) ~= nil)
	Check("[AZS] échappée : pas de bouclier (2.9.0), « échappée »", fled and fled.shieldKind == nil and not fled.shield:IsShown() and fled.stars:GetText() == NS.L.CAPTURE_BATCH_FLED)
	Check("[AZS] brillante : nom en or, lueur dorée", shinyTile and shinyTile.name.textColor[3] < 0.6 and shinyTile.halo:IsShown()
		and shinyTile.tag:GetText() == "BRILLANTE")
	Check("[AZS] volée finie : Fermer, « Captures : 5 »", frame.stop:GetText() == NS.L.CAPTURE_BATCH_CLOSE
		and frame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 5))
	Check("[AZS] pied dans le cadre, au-dessus du bois", frame.footer.lastPoint.point == "BOTTOMLEFT"
		and Y(frame.footer) >= NS.AZEROTH_WOOD_INSET + 4 and frame.footer:GetText() == NS.L.CAPTURE_BATCH_DONE)
	frame.stop:Click()
	frame.scripts.OnHide(frame)
	Check("[AZS] Fermer : la volée se ferme, les modèles se vident", not frame:IsShown() and not tile.hasModel)
	-- un second lot : les mêmes cases resservent
	SZ.SeeKill(8410, { name = "Loup" })
	SZ.SeeKill(8411, { name = "Ours" })
	SZ.Roll(0)
	NS:CaptureBatch()
	Check("[AZS] second lot : même fenêtre, mêmes cases", NS.captureBatchFrame == frame and frame.tiles[1] == tile
		and frame.tiles[3] and not frame.tiles[3]:IsShown())
	NS:CaptureBatchStop(true)
	frame:Hide()
	frame.scripts.OnHide(frame)
end

-- 5. Le bois manque : fenêtres Sobre (les bandeaux gardent Azeroth) -----------------------------------
do
	Say("-- azeroth 2.5.1 : repli Sobre sans le bois")
	SZ.Reset({ ["_achievement-wood-nineslice-edgetop"] = true })
	Check("[AZS] bois absent : bandeaux en Azeroth, fenêtres en Sobre", NS:AzerothOn() and not NS:AzerothScenesOn())
	SZ.SeeKill(8500, { name = "Sanglier" })
	SZ.SeeKill(8501, { name = "Loup" })
	NS:CaptureNetClick("LeftButton")
	local chooser = NS.captureChooser
	Check("[AZS] repli : le choix Sobre", chooser and chooser:IsShown() and not chooser.azeroth and chooser.uiStyle == "sobre"
		and chooser.hint:GetText() == NS.L.CAPTURE_CHOOSE_PAUSED)
	SZ.Roll(0)
	chooser.single:Click()
	local stage = NS.captureStage
	Check("[AZS] repli : la scène Sobre (ruban, filet haut)", stage and stage:IsShown() and not stage.azeroth and stage.topBar
		and stage.ribbonPanel and Has(_G.UISpecialFrames, "QuestCompanionCaptureStage"), stage and (tostring(stage:IsShown()) .. "," .. tostring(stage.azeroth) .. "," .. tostring(stage:GetName())))
	SZ.UntilVerdict()
	Check("[AZS] repli : le bandeau « Capturé ! » reste (la scène Sobre n'a que le ruban)", NS.captureResultPending ~= nil)
	stage.scripts.OnMouseUp(stage)
	SZ.Close(5)
	NS:CaptureResultHide()
	SZ.Roll(0)
	SZ.SeeKill(8502, { name = "Ours" })
	NS:CaptureBatch()
	local frame = NS.captureBatchFrame
	Check("[AZS] repli : la volée Sobre", frame and frame:IsShown() and not frame.azeroth and frame.close and not frame.tiles[1].az)
	NS:CaptureBatchStop(true)
	frame:Hide()
	frame.scripts.OnHide(frame)
end

-- 6. Style Sobre : les fenêtres d'avant ------------------------------------------------------------
do
	Say("-- azeroth 2.5.1 : style Sobre inchangé")
	SZ.Reset()
	NS:SetUIStyle("sobre")
	SZ.SeeKill(8600, { name = "Raptor" })
	SZ.Roll(0)
	NS:CaptureThrow()
	local stage = NS.captureStage
	local SBS = NS.CAPTURE_STAGE_SOBRE
	Check("[AZS] Sobre : la carte compacte (340×366, ruban, pied à 11)", stage and not stage.azeroth and stage:GetWidth() == 340
		and stage:GetHeight() == SBS.h and SBS.h < 386 and stage.ribbonPanel and stage.topBar and Y(stage.footer) == 11
		and stage.name:GetParent() == stage and not stage.plate)
	-- 2.14.0 (bêta 3) : même disposition que la carte Azeroth, sur le fond sombre du socle
	Check("[AZC14] Sobre : « CAPTURE · NORMAL », le nom dessous, la scène sans boîte noire, son ombre",
		stage.title:GetText() == "CAPTURE · NORMAL" and stage.name:GetText() == "Raptor" and stage.name.lastPoint.y == SBS.nameY
		and stage.stageBg == nil and stage.ground and stage.ground.vertex[1] == NS.Theme.SHADOW[1]
		and stage.cardParch == nil, stage.title:GetText())
	Check("[AZC14] Sobre : chance, étoiles et aides sous la scène, pied « Le filet bouge… »",
		stage.info:GetText():find("^Chance 50 %%") ~= nil and #stage.aidCells == 3 and stage.details:IsShown()
		and stage.details.lastPoint.relTo == stage.scene and stage.footer:GetText() == NS.L.CAPTURE_SHAKING
		and stage.info.azRole == nil, stage.info:GetText())
	Check("[AZC14] Sobre : le ruban se pose sur la chance et les aides", stage.banner.lastPoint.relTo == stage.scene
		and stage.banner.lastPoint.y == SBS.ribbonY and stage.starSlots[1].lastPoint.relTo == stage.banner)
	local rolling = SZ.UntilVerdict()
	Check("[AZS] Sobre : le verdict n'est pas montré par la scène, « Capturé ! » attend sa fermeture",
		not rolling.sceneVerdict and NS.captureResultPending ~= nil)
	stage.scripts.OnMouseUp(stage)
	local seen = SZ.Close(5)
	Check("[AZS] Sobre : « Capturé ! » après la scène", seen and not seen.azeroth)
	NS:CaptureResultHide()
	NS:SetUIStyle("azeroth")
end

-- 7. Changement de style pendant une scène ---------------------------------------------------------
do
	Say("-- azeroth 2.5.1 : changement de style en direct")
	SZ.Reset()
	SZ.SeeKill(8700, { name = "Kodo" })
	SZ.Roll(0)
	NS:CaptureThrow()
	local az = NS.captureStage
	local ok = pcall(NS.SetUIStyle, NS, "sobre")
	Check("[AZS] → Sobre pendant la scène : sans erreur, elle finit telle quelle", ok and NS.captureStage == az and az:IsShown()
		and NS:EnsureCaptureStage() == az)
	local done = pcall(function()
		local rolling = SZ.UntilVerdict()
		NS:CaptureStageUpdate(rolling.resultAt + 0.5)
	end)
	Check("[AZS] … le verdict s'y joue (bandeau Azeroth)", done and az.banner:IsShown() and az.banner.title:GetText() == "CAPTURÉ !")
	az.scripts.OnMouseUp(az)
	SZ.Close(5)
	az.scripts.OnHide(az)
	SZ.SeeKill(8701, { name = "Ours" })
	SZ.Roll(0)
	NS:CaptureThrow()
	local sobre = NS.captureStage
	Check("[AZS] scène suivante : le style Sobre", sobre and sobre ~= az and not sobre.azeroth and sobre:IsShown())
	sobre:Hide(); sobre.scripts.OnHide(sobre)
	SZ.UntilVerdict()
	SZ.Close(5)
	NS:SetUIStyle("azeroth")
	SZ.SeeKill(8702, { name = "Loup" })
	SZ.Roll(0)
	NS:CaptureThrow()
	Check("[AZS] → Azeroth : la même scène revient (gardée, pas recréée)", NS.captureStage == az and az:IsShown())
	az:Hide(); az.scripts.OnHide(az)
	SZ.UntilVerdict()
	SZ.Close(5)
	-- le choix : ouvert pendant le changement, il reste ; rouvert, il change
	SZ.SeeKill(8710, { name = "A" })
	SZ.SeeKill(8711, { name = "B" })
	NS:CaptureNetClick("LeftButton")
	local chooserAz = NS.captureChooser
	ok = pcall(NS.SetUIStyle, NS, "sobre")
	Check("[AZS] choix ouvert, → Sobre : sans erreur, il reste", ok and chooserAz.azeroth and chooserAz:IsShown())
	NS:CaptureChooserHide()
	NS:CaptureNetClick("LeftButton")
	Check("[AZS] choix rouvert : Sobre", NS.captureChooser ~= chooserAz and not NS.captureChooser.azeroth and NS.captureChooser:IsShown())
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

-- Rangement : les autres modules testent le style Sobre (client sans atlas)
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
