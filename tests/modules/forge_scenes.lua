-- Les scènes de capture au thème forgé (ForgeScenes.lua, QuestCompanion
-- 3.1.0) : les fonctions de l'ancien habillage re-logées en matières du
-- socle, dans l'état du produit (thème forgé, ancien habillage coupé, sans
-- atlas). La carte d'un lancer seul (carte du socle, plaque de titre,
-- verdict DANS la scène : portrait, titre, nom ou phrase, niveau sur sa
-- plaque, lueur, éclat, reflet d'une brillante ; pas de bandeau « Capturé ! »
-- en double ; Partager dans le coin), la carte de préparation (aides en
-- petites plaques, lueur de l'aide conseillée, Lancer doré), la volée (plaque
-- et compteur, « Aide : », creux, badge d'étoiles, 3 colonnes à 5 ou 6), le
-- choix au filet (compte, lignes de chance et de coût, raccourcis, Capturer
-- en principal doré, à côté du filet), les clés de cache (une carte née
-- forgée jamais resservie en Sobre), le Sobre sans rien de forgé, et les
-- contrastes de chaque nouveau texte sur son vrai fond.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme

local FS = { saved = {}, random = math.random, units = {} }
FS.rollQuality = NS.CaptureRollQuality
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"InCombatLockdown", "UnitAffectingCombat", "PlaySound", "IsShiftKeyDown", "IsControlKeyDown" }
for _, name in ipairs(GLOBALS) do FS.saved[name] = rawget(_G, name) end
FS.savedShiny, FS.savedWidth = NS.SHINY_CHANCE, _G.UIParent.width
local PLAYER = "Player-1-00000001"
local SCENES = { "captureStage", "captureBatchFrame", "captureChooser" }
local CACHES = { "captureStages", "captureBatchFrames", "captureChoosers" }
local FIELDS = { "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt",
	"captureQueueList", "captureNetButton", "captureToast", "captureResult" }

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end
local function Same(a, b)
	return type(a) == "table" and type(b) == "table" and math.abs(a[1] - b[1]) < 1e-6
		and math.abs(a[2] - b[2]) < 1e-6 and math.abs(a[3] - b[3]) < 1e-6
end
local function Has(list, value) for _, v in ipairs(list) do if v == value then return true end end return false end
local function SliceOf(slice, art)
	if type(slice) ~= "table" or type(slice.parts) ~= "table" then return false end
	local count = 0
	for _, tex in pairs(slice.parts) do
		count = count + 1
		if tex.texture ~= Theme.ART[art].file then return false end
	end
	return count >= 8
end

function FS.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function FS.Install()
	local w = FS
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
	_G.PlaySound = function() return true end
	_G.IsShiftKeyDown = function() return false end
	_G.IsControlKeyDown = function() return false end
end
local function DropScenes()
	for _, field in ipairs(SCENES) do
		local frame = NS[field]
		if frame then frame:Hide(); frame.rolling = nil end
		NS[field] = nil
	end
	for _, field in ipairs(CACHES) do
		for _, frame in pairs(NS[field] or {}) do frame:Hide(); frame.rolling = nil end
		NS[field] = nil
	end
end
-- style : "azeroth" (thème forgé, l'état du produit) ou "sobre" ; keep :
-- garder les scènes déjà construites (clés de cache)
function FS.Reset(style, keep)
	ResetWorld()
	NS:DB().winterVeil = "off"
	NS.CaptureRollQuality = function() return FS.quality or 1 end
	FS.quality = nil
	if not keep then DropScenes() else
		for _, field in ipairs(SCENES) do if NS[field] then NS[field]:Hide(); NS[field].rolling = nil end end
	end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureToastHideAt, NS.captureAppCache, NS.captureBatch = nil, nil, nil
	NS.captureResultPending, NS.captureResultHideAt = nil, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	FS.units = {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	FS.Install()
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style or "azeroth"
	NS:ApplyUIStyle()
	NS.SHINY_CHANCE = 0
	math.random = FS.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = true
	NS:DB().companionCaptureDirect = true
	NS:DB().captureMuteUntil = nil
	NS:DB().companionCaptureToast = true
	NS:DB().shareBanner = nil
	NS:CompanionUpdateVisibility()
end
function FS.Roll(value)
	math.random = function(a, b)
		if a and b then return FS.random(a, b) end
		if a then return FS.random(a) end
		return value
	end
end
function FS.SeeKill(npcID, fields)
	fields = fields or {}
	fields.guid = fields.guid or FS.Guid(npcID, fields.spawn)
	fields.name = fields.name or ("Bête " .. npcID)
	FS.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, fields.guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, fields.guid, 0)
	return fields.guid
end
function FS.OfferShiny(npcID, name)
	return NS:CaptureOffer(FS.Guid(npcID, "0000005H1N"), { zoneID = 1413, npcID = npcID }, { name = name })
end
function FS.UntilVerdict()
	local tries = 0
	while NS.captureState.rolling and not NS.captureState.rolling.result and tries < 10 do
		Mock:Advance(1); NS:CaptureTick(NS.Now()); tries = tries + 1
	end
	return NS.captureState.rolling
end
function FS.Close(seconds)
	local seen
	for _ = 1, seconds or 6 do
		Mock:Advance(1)
		NS:CaptureTick(NS.Now())
		if NS.captureResult and NS.captureResult:IsShown() then seen = seen or NS.captureResult end
	end
	return seen
end
local function NoChance(fn)
	local base = NS.CaptureChance
	NS.CaptureChance = function() return 0, false end
	local ok, err = pcall(fn)
	NS.CaptureChance = base
	if not ok then error(err, 0) end
end

-- ---------------------------------------------------------------------------
-- 1. La carte d'un lancer seul : capturé
-- ---------------------------------------------------------------------------
do
	Say("-- scènes forgées : lancer seul, capturé (verdict dans la scène)")
	FS.Reset()
	local s = Steps()
	FS.SeeKill(8100, { name = "Grand trotteur", class = "rare" })
	FS.Roll(0)
	NS:CaptureThrow()
	local stage = NS.captureStage
	local F = NS.FORGE_SCENE.stage
	s.ok("produit : thème forgé, ancien habillage coupé", NS.QCForged() and not NS:AzerothOn() and NS.AZEROTH_LEGACY == false)
	s.ok("carte née forgée, clé « forge », nom pour Échap, jamais frame.azeroth", stage and stage:IsShown() and stage.forged
		and stage.styleKey == "forge" and stage.uiStyle == "sobre" and not stage.azeroth
		and Has(_G.UISpecialFrames, "QuestCompanionCaptureStageForge") and stage:GetWidth() == F.w and stage:GetHeight() == F.h)
	local chrome = stage.skinChrome
	s.ok("carte du socle : ombre, cadre d'orfèvre, coins et bords assombris ; plus de barre d'accent", stage.chrome == "card"
		and chrome and SliceOf(chrome.frame, "frame") and chrome.vignette and #(chrome.corners or {}) == 4
		and stage.skinDressed and not stage.accent:IsShown())
	s.ok("plaque de titre (ART.plate, teinte froide de l'en-tête) : « CAPTURE · RARE », le nom à la couleur du rang",
		stage.titlePlate and SliceOf(stage.titlePlate.slice, "plate") and Same(stage.titlePlate.slice.color, Theme.FORGE_HEADER.warm)
		and stage.title:GetText() == "CAPTURE · RARE" and stage.name:GetText() == "Grand trotteur"
		and Same(stage.name.textColor, NS.CAPTURE_RARITY.rare.text) and Same(stage.title.textColor, Theme.IDENTITY_LIGHT)
		and stage.topBar == nil and stage.ribbonPanel == nil and stage.bannerText == nil)
	s.ok("le nom en police de titre, à sa taille (il rapetisse pour tenir)", stage.name.fontObject == Theme.F_TITLE
		and stage.name.fitSize == F.nameMax and stage.name.font and stage.name.font.size == F.nameMax and stage.name.width == stage.nameW)
	s.ok("filet lumineux de la rareté sous le nom", stage.rarityRuleL and stage.rarityRuleL.texture == Theme.ART.line.file
		and Same(stage.rarityRuleL.vertex, NS.CAPTURE_RARITY.rare.color))
	local cells = stage.aidCells
	s.ok("aides en petites plaques (le liseré Sobre invisible)", #cells == 3 and cells[1].forged and SliceOf(cells[1].plate, "plate")
		and cells[1].edge.alpha == 0 and cells[1].forgeState == "rest")
	local rolling = FS.UntilVerdict()
	s.ok("le verdict est dit dans la scène : pas de bandeau « Capturé ! » en attente", rolling and rolling.result == "ok"
		and rolling.sceneVerdict == true and NS.captureResultPending == nil)
	NS:CaptureStageUpdate(rolling.resultAt + 0.6)
	local banner = stage.banner
	local inks = NS.ForgeSceneInks()
	s.ok("verdict forgé (pas l'habit du client) : fond, cadre d'orfèvre, portrait en creux", banner:IsShown() and banner.verdict
		and not banner.azeroth and SliceOf(banner.frameSlice, "frame") and SliceOf(banner.portraitInset, "inset")
		and banner.portraitIcon:IsShown() and banner.bg.texture == Theme.SOLID)
	s.ok("« CAPTURÉ ! » à l'encre du titre, le nom clair, le filet de l'identité", banner.title:GetText() == "CAPTURÉ !"
		and banner.text:GetText() == "Grand trotteur" and Same(banner.title.textColor, Theme.TITLE)
		and Same(banner.text.textColor, inks.name) and banner.ruleL and Same(banner.ruleL.vertex, Theme.IDENTITY))
	s.ok("le niveau sur la plaque d'or (encre sombre), son éclat (notre point lumineux, sans atlas), la lueur",
		banner.shieldKind == "gold" and banner.shield:IsShown() and Same(banner.shield.slice.color, Theme.FORGE_PLATE.gold)
		and banner.levelText:GetText() == "20" and banner.levelText:IsShown() and Same(banner.levelText.textColor, Theme.FORGE_INK.gold)
		and banner.bling:IsShown() and banner.bling.texture == Theme.ART.dot.file and banner.glow.texture == Theme.ART.dot.file
		and (banner.glow.alpha or 0) > 0)
	s.ok("les étoiles dans le bandeau ; chance et aides cachées ; pas de reflet (pas une brillante)",
		stage.starSlots[1]:GetParent() == banner and stage.starSlots[1].lastPoint.relTo == banner
		and stage.starSlots[1].lastPoint.y == banner.lineY and not stage.details:IsShown() and not banner.shine:IsShown())
	s.ok("posé sur la chance et les aides, dans la carte, au-dessus du pied", banner.area.lastPoint.relTo == stage.scene
		and banner.area:GetWidth() <= F.w - 24 and banner:GetScale() == 1)
	-- Partager : dans le coin de la scène (rang nommé : rare)
	local button = stage.shareButton
	s.ok("bouton Partager dans le coin de la scène", button and button:IsShown() and button.shareBanner == "stage"
		and button.lastPoint.point == "TOPRIGHT" and button.lastPoint.relTo == stage and button.item ~= nil)
	stage.scripts.OnMouseUp(stage)
	local seen = FS.Close(6)
	s.ok("un clic ferme, sans bandeau « Capturé ! » en double", not seen and NS.captureState.rolling == nil
		and NS.captureResultPending == nil)
	s.check("[FSC] lancer seul forgé : carte du socle, plaque de titre, verdict dans la scène, Partager au coin")
end

-- ---------------------------------------------------------------------------
-- 2. Échappée, brillante, Échap avant le verdict
-- ---------------------------------------------------------------------------
do
	Say("-- scènes forgées : échappée, brillante")
	FS.Reset()
	local s = Steps()
	FS.SeeKill(8200, { name = "Fuyard" })
	FS.Roll(0.99)
	NoChance(function() NS:CaptureThrow() end)
	local stage = NS.captureStage
	local rolling = FS.UntilVerdict()
	NS:CaptureStageUpdate(rolling.resultAt + 0.6)
	local banner = stage.banner
	s.ok("échappée : « ÉCHAPPÉ… » en rouge, la phrase adoucie, le niveau sur l'ardoise, sans éclat",
		rolling.result == "fail" and banner:IsShown() and banner.title:GetText() == "ÉCHAPPÉ…"
		and Same(banner.title.textColor, Theme.RED) and banner.text:GetText() == NS.L.CAPTURE_STAGE_FAIL
		and Same(banner.text.textColor, Theme.MUTED_LIGHT) and banner.shieldKind == "grey"
		and Same(banner.shield.slice.color, Theme.FORGE_PLATE.neutral) and Same(banner.levelText.textColor, Theme.LABEL)
		and not banner.bling:IsShown() and Same(banner.ruleL.vertex, Theme.RED))
	s.ok("échappée : la phrase n'est écrite qu'une fois (pas de doublon au pied)", stage.footer:GetText() ~= NS.L.CAPTURE_STAGE_FAIL,
		stage.footer:GetText())
	NS:CaptureStageUpdate(rolling.resultAt + 1.5)
	s.ok("échappée : puis « Clic ou Échap pour fermer » au pied", stage.footer:GetText() == NS.L.CAPTURE_STAGE_CLOSE)
	stage.scripts.OnMouseUp(stage)
	FS.Close(5)
	-- brillante
	FS.OfferShiny(8201, "Cerf")
	FS.Roll(0)
	NS:CaptureThrow()
	rolling = FS.UntilVerdict()
	rolling.stars = 3
	NS:CaptureStageUpdate(rolling.resultAt + 0.9)
	s.ok("brillante : le nom en or sur la plaque et dans le verdict, le reflet traverse le bandeau (rogné)",
		rolling.result == "ok" and stage.name.textColor[3] < 0.6 and Same(banner.text.textColor, Theme.GOLD_LIGHT)
		and banner.shine:IsShown() and banner.shine:GetParent() == banner.shineClip and banner.shineClip.clipsChildren == true)
	stage.scripts.OnMouseUp(stage)
	FS.Close(5)
	-- un nom très long : la police descend jusqu'au plus petit (la largeur coupe le reste)
	FS.SeeKill(8203, { name = "Ancienne mystique Tranchegroin des collines lointaines" })
	FS.Roll(0)
	NS:CaptureThrow()
	s.ok("nom très long : la police rapetisse jusqu'au plus petit", stage.name.fitSize == NS.FORGE_SCENE.stage.nameMin
		and stage.name.width == stage.nameW, stage.name.fitSize)
	FS.UntilVerdict()
	stage.scripts.OnMouseUp(stage)
	FS.Close(5)
	-- Échap avant le verdict : la scène ne l'a pas montré, le bandeau le dira
	FS.SeeKill(8202, { name = "Kodo" })
	FS.Roll(0)
	NS:CaptureThrow()
	stage:Hide()
	stage.scripts.OnHide(stage)
	FS.UntilVerdict()
	local pending = NS.captureResultPending ~= nil
	local seen = FS.Close(4)
	s.ok("fermée avant le verdict : le bandeau « Capturé ! » le dit quand même", pending and seen and seen.text:GetText() == "Kodo")
	NS:CaptureResultHide()
	s.check("[FSC] échappée (rouge, ardoise), brillante (or, reflet), Échap avant le verdict : le bandeau")
end

-- ---------------------------------------------------------------------------
-- 3. La carte de préparation
-- ---------------------------------------------------------------------------
do
	Say("-- scènes forgées : carte de préparation")
	FS.Reset()
	local s = Steps()
	NS:DB().companionCaptureDirect = nil
	local data = NS:CaptureData()
	data.items.appat, data.items.lasso, data.items.sifflet = 2, 1, 0
	FS.SeeKill(8300, { name = "Ours" })
	FS.quality = 3
	FS.SeeKill(8301, { name = "Loup" })
	local queue = NS:CaptureQueueState()
	local best = queue[1]
	NS:CaptureToggleAid("appat")
	local frame = NS:CapturePrepOpen(best)
	local F = NS.FORGE_SCENE.stage
	s.ok("même carte forgée, agrandie d'autant qu'en Sobre", frame and frame.forged and frame.prep == best
		and frame:GetHeight() == F.h + NS.CAPTURE_PREP.extra.sobre)
	s.ok("« Lancer » en principal doré, « Passer » en second (plaques forgées)", frame.launch.style == "primary"
		and frame.launch.forge and frame.launch.forge.plate == "gold" and frame.pass.style == "normal" and frame.pass.forge.plate == "neutral")
	local cells = {}
	for _, cell in ipairs(frame.aidCells) do cells[cell.id] = cell end
	s.ok("l'aide choisie sur la plaque de la sélection, une aide à 0 éteinte", cells.appat.forgeState == "chosen"
		and Same(cells.appat.plate.color, Theme.FORGE_PLATE.select) and cells.sifflet.forgeState == "off"
		and Same(cells.sifflet.plate.color, Theme.FORGE_PLATE.disabled))
	local advised = best.stars == 3 and cells.lasso
	s.ok("3 étoiles : l'aide conseillée luit (notre point lumineux d'or)", advised and advised.advised
		and advised.glow:IsShown() and advised.glow.texture == Theme.ART.dot.file and Same(advised.glow.vertex, Theme.GOLD_LIGHT)
		and cells.appat.glow:IsShown() == false, best.stars)
	NS:CapturePrepToggleAid("appat")
	s.ok("re-clic : aucune aide, la plaque revient au repos", cells.appat.forgeState == "rest" and Same(cells.appat.plate.color, Theme.FORGE_PLATE.neutral))
	FS.Roll(0)
	frame.launch:Click()
	s.ok("Lancer : la scène sur la même carte, à sa taille", NS.captureState.rolling ~= nil and frame:GetHeight() == F.h
		and frame.prep == nil)
	FS.UntilVerdict()
	frame.scripts.OnMouseUp(frame)
	FS.Close(5)
	s.check("[FSC] carte de préparation forgée : aides en petites plaques, lueur conseillée, Lancer doré")
end

-- ---------------------------------------------------------------------------
-- 4. La volée « Tout capturer »
-- ---------------------------------------------------------------------------
do
	Say("-- scènes forgées : la volée")
	FS.Reset()
	local s = Steps()
	for index = 1, 5 do FS.SeeKill(8400 + index, { name = "Bête " .. index }) end
	FS.OfferShiny(8406, "Brillant")
	NS:CaptureData().items.lasso = 9
	NS:CaptureToggleAid("lasso")
	local base = NS.CaptureChance
	NS.CaptureChance = function(self, info, ...)
		if info and info.npcID == 8402 then return 0, false end
		return 0.95, false
	end
	FS.Roll(0.5)
	local batch = NS:CaptureBatch()
	NS.CaptureChance = base
	local frame = NS.captureBatchFrame
	local B = NS.FORGE_SCENE.batch
	s.ok("fenêtre née forgée (carte du socle, nom pour Échap)", batch and batch.tried == 6 and frame:IsShown() and frame.forged
		and not frame.azeroth and frame.chrome == "card" and Has(_G.UISpecialFrames, "QuestCompanionCaptureBatchForge"))
	s.ok("plaque de titre : « TOUT CAPTURER » et le compteur mis en avant", frame.titlePlate and SliceOf(frame.titlePlate.slice, "plate")
		and frame.title:GetText() == "TOUT CAPTURER" and frame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 0)
		and frame.counter.lastPoint.relTo == frame.titlePlate and frame.counter.fontObject == Theme.F_TITLE
		and Same(frame.counter.textColor, Theme.TITLE))
	s.ok("« Aide : <aide> » sous la plaque", frame.aidText:GetText() == NS:F("CAPTURE_BATCH_AID", NS:CaptureAidLabel("lasso"))
		and frame.aidText:IsShown() and Same(frame.aidText.textColor, Theme.SELECT_LIGHT))
	local cols, rows = NS:CaptureBatchGrid(6, true)
	local t1, t4 = frame.tiles[1], frame.tiles[4]
	s.ok("6 cases en deux rangées de 3", cols == 3 and rows == 2 and t4.lastPoint.y < t1.lastPoint.y
		and t4.lastPoint.x == t1.lastPoint.x)
	s.ok("creux autour de la créature, modèles 3D gardés, badge caché avant le verdict", t1.forged and SliceOf(t1.inset, "inset")
		and t1.model ~= nil and not t1.badge:IsShown())
	NS:CaptureBatchStop(true)
	local ok, okCard, fled, shiny
	for _, card in ipairs(batch.cards) do
		if card.result.target.shiny then shiny = card.tile
		elseif card.result.success then ok = ok or card.tile; okCard = okCard or card
		else fled = card.tile end
	end
	s.ok("prise : badge d'étoiles au coin (plaque d'or, chiffre sombre)", ok and ok.badge:IsShown()
		and ok.badge.text:GetText() == tostring(okCard.result.stars or 1) and SliceOf(ok.badge.slice, "plate")
		and Same(ok.badge.slice.color, Theme.FORGE_PLATE.gold) and Same(ok.badge.text.textColor, Theme.FORGE_INK.gold)
		and ok.badge.lastPoint.point == "TOPRIGHT")
	s.ok("échappée : pas de badge ; brillante : badge et lueur", fled and not fled.badge:IsShown() and shiny and shiny.badge:IsShown()
		and shiny.halo:IsShown())
	s.ok("fin : « Captures : 5 », Fermer", frame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 5)
		and frame.stop:GetText() == NS.L.CAPTURE_BATCH_CLOSE)
	frame:Hide()
	frame.scripts.OnHide(frame)
	-- 3 cases : une rangée de 3 ; 4 cases : 4 colonnes (comme l'ancien habillage)
	local c3 = NS:CaptureBatchGrid(3, true)
	local c4 = NS:CaptureBatchGrid(4, true)
	local c5, r5 = NS:CaptureBatchGrid(5, true)
	s.ok("grille : 3 → 3 colonnes, 4 → 4, 5 → 3 × 2", c3 == 3 and c4 == 4 and c5 == 3 and r5 == 2)
	s.check("[FSC] volée forgée : plaque et compteur, « Aide : », creux, badge d'étoiles, 3 colonnes à 5 ou 6")
end

-- ---------------------------------------------------------------------------
-- 5. Le choix au filet
-- ---------------------------------------------------------------------------
do
	Say("-- scènes forgées : le choix au filet")
	FS.Reset()
	local s = Steps()
	NS:DB().companionCaptureDirect = true
	FS.OfferShiny(8500, "Cerf")
	FS.SeeKill(8501, { name = "Loup" })
	local net = NS.captureNetButton
	_G.UIParent.width = 1000
	net.GetCenter = function() return 900, 400 end
	NS:CaptureNetClick("LeftButton")
	local chooser = NS.captureChooser
	local C = NS.FORGE_SCENE.chooser
	s.ok("panneau né forgé (carte du socle, nom pour Échap)", chooser and chooser:IsShown() and chooser.forged
		and not chooser.azeroth and chooser.chrome == "card" and Has(_G.UISpecialFrames, "QuestCompanionCaptureChooserForge")
		and chooser:GetWidth() == C.w)
	s.ok("le filet du jeu dans un creux, « 2 CRÉATURES DANS LE FILET », le temps en pause", SliceOf(chooser.glyphInset, "inset")
		and chooser.glyph.texture == NS.CAPTURE_CLIENT_ART.icon.files[1]
		and chooser.title:GetText() == "2 CRÉATURES DANS LE FILET" and chooser.paused:GetText() == NS.L.CAPTURE_CHOOSE_PAUSED)
	local one, all = chooser.single, chooser.all
	s.ok("« Capturer : X » en principal doré, sa ligne (brillante, chance)", one.style == "primary" and one.forge.plate == "gold"
		and one:GetText() == NS:F("CAPTURE_CHOOSE_ONE", NS:F("CAPTURE_SHINY_TAG", "Cerf"))
		and one.sub:IsShown() and one.sub:GetText():find(NS.L.CAPTURE_CHOOSE_SHINY, 1, true) ~= nil
		and one.sub:GetText():find("%%") ~= nil and Same(one.text.textColor, Theme.FORGE_INK.gold), one.sub:GetText())
	s.ok("« Tout capturer (2) » en second, son coût", all.style == "normal" and all:GetText() == NS:F("CAPTURE_CHOOSE_ALL", 2)
		and all.sub:GetText() == NS.L.CAPTURE_CHOOSE_ALL_FREE)
	s.ok("les raccourcis", chooser.hint:GetText() == NS.L.CAPTURE_CHOOSE_KEYS)
	s.ok("à gauche du filet (filet à droite de l'écran)", chooser.side == "left" and chooser.lastPoint.point == "RIGHT"
		and chooser.lastPoint.relTo == net and chooser.lastPoint.relPoint == "LEFT" and chooser.lastPoint.x == -C.gap)
	NS:CaptureData().items.lasso = 3
	NS:CaptureToggleAid("lasso")
	NS:CaptureChooserRefresh()
	local lasso
	for _, b in ipairs(chooser.aids) do if b.aid == "lasso" then lasso = b end end
	s.ok("« chaque essai coûte : Lasso », l'aide du lot sur sa plaque", all.sub:GetText() == NS:F("CAPTURE_CHOOSE_ALL_AID", NS:CaptureAidLabel("lasso"))
		and lasso and lasso.forgeState == "hover")
	NS:CaptureChooserHide()
	net.GetCenter = function() return 100, 400 end
	NS:CaptureNetClick("LeftButton")
	local right = chooser:IsShown() and chooser.side == "right" and chooser.lastPoint.point == "LEFT"
	FS.Roll(0)
	one:Click()
	s.ok("à droite du filet (filet à gauche) ; « Capturer » lance le filet", right and not chooser:IsShown()
		and NS.captureState.rolling ~= nil)
	net.GetCenter = nil
	_G.UIParent.width = FS.savedWidth
	FS.UntilVerdict()
	if NS.captureStage then NS.captureStage.scripts.OnMouseUp(NS.captureStage) end
	FS.Close(5)
	s.check("[FSC] choix au filet forgé : compte, pause, Capturer doré et sa ligne, coût, raccourcis, à côté du filet")
end

-- ---------------------------------------------------------------------------
-- 6. Clés de cache : une carte née forgée n'est jamais resservie en Sobre
-- ---------------------------------------------------------------------------
do
	Say("-- scènes forgées : clés de cache")
	FS.Reset()
	local s = Steps()
	local forged = NS:EnsureCaptureStage()
	local batchF = NS:EnsureCaptureBatchFrame()
	local chooserF = NS:EnsureCaptureChooser()
	FS.Reset("sobre", true)
	local stage = NS:EnsureCaptureStage()
	local batch = NS:EnsureCaptureBatchFrame()
	local chooser = NS:EnsureCaptureChooser()
	s.ok("Sobre : d'autres cadres, sans rien de forgé", stage ~= forged and not stage.forged and stage.styleKey == "sobre"
		and batch ~= batchF and not batch.forged and chooser ~= chooserF and not chooser.forged
		and stage.ribbonPanel ~= nil and stage.titlePlate == nil)
	FS.Reset("azeroth", true)
	s.ok("retour au thème forgé : les mêmes cadres forgés reviennent", NS:EnsureCaptureStage() == forged
		and NS:EnsureCaptureBatchFrame() == batchF and NS:EnsureCaptureChooser() == chooserF)
	s.ok("deux ApplyUIStyle de suite : rien ne change", (function()
		NS:ApplyUIStyle(); NS:ApplyUIStyle()
		return NS:EnsureCaptureStage() == forged and NS:EnsureCaptureChooser() == chooserF
	end)())
	s.check("[FSC] clés de cache : forgé et Sobre, chacun ses cadres, jamais resservis à l'autre")
end

-- ---------------------------------------------------------------------------
-- 7. Sobre : rien de forgé (le ruban, le bandeau d'après, le choix d'avant)
-- ---------------------------------------------------------------------------
do
	Say("-- scènes forgées : le Sobre inchangé")
	FS.Reset("sobre")
	local s = Steps()
	FS.SeeKill(8700, { name = "Raptor" })
	FS.Roll(0)
	NS:CaptureThrow()
	local stage = NS.captureStage
	s.ok("carte Sobre : ruban, filet haut, barre d'accent, pas de plaque", stage and not stage.forged and stage.ribbonPanel
		and stage.topBar and stage.accent:IsShown() and stage.titlePlate == nil and not stage.banner.verdict
		and stage.chrome == "toast" and stage.aidCells[1].plate == nil)
	local rolling = FS.UntilVerdict()
	local waits = not rolling.sceneVerdict and NS.captureResultPending ~= nil
	stage.scripts.OnMouseUp(stage)
	local seen = FS.Close(5)
	s.ok("le verdict vient après, dans le bandeau « Capturé ! »", waits and seen ~= nil)
	NS:CaptureResultHide()
	FS.SeeKill(8701, { name = "A" })
	FS.SeeKill(8702, { name = "B" })
	NS:CaptureNetClick("LeftButton")
	local chooser = NS.captureChooser
	s.ok("choix Sobre : au-dessus du filet, « Tout capturer » en principal, le temps en pause", chooser and not chooser.forged
		and chooser.all.style == "primary" and chooser.single.style == "normal" and chooser.hint:GetText() == NS.L.CAPTURE_CHOOSE_PAUSED
		and chooser.lastPoint.point == "BOTTOM" and chooser.single.sub == nil)
	NS:CaptureChooserHide()
	NS:CaptureData().items.lasso = 5
	NS:CaptureToggleAid("lasso")
	FS.Roll(0)
	NS:CaptureBatch()
	local frame = NS.captureBatchFrame
	s.ok("volée Sobre : l'aide sans préfixe, pas de badge ni de creux, 4 colonnes à 5", frame and not frame.forged
		and frame.aidText:GetText() == NS:CaptureAidLabel("lasso") and frame.tiles[1].badge == nil and frame.tiles[1].inset == nil
		and NS:CaptureBatchGrid(5, false) == 4)
	NS:CaptureBatchStop(true)
	frame:Hide()
	frame.scripts.OnHide(frame)
	s.check("[FSC] Sobre : rien de forgé (ruban et bandeau d'après, choix d'avant, volée d'avant)")
end

-- ---------------------------------------------------------------------------
-- 7 bis. La petite fenêtre « Capturer ? » (capture animée coupée) : déjà des
-- briques du socle ; au thème forgé, le titre à l'encre de l'identité
-- ---------------------------------------------------------------------------
do
	Say("-- scènes forgées : la petite fenêtre « Capturer ? »")
	local s = Steps()
	local function Prompt(style)
		FS.Reset(style)
		NS:DB().companionCaptureAnim = false
		FS.SeeKill(8800, { name = "Sanglier" })
		local candidate = NS:CaptureQueueState()[1]
		NS:CaptureState().pending = candidate
		candidate.expires = NS.Now() + 20
		local frame = NS:CaptureShowPrompt()
		frame:Hide()
		return frame
	end
	local forged = Prompt("azeroth")
	s.ok("forgé : titre de l'identité, Lancer en plaque d'or, aides en petites plaques, habillé par le socle",
		forged and forged.forged and Same(forged.title.textColor, Theme.IDENTITY_LIGHT) and forged.throw.forge
		and forged.throw.forge.plate == "gold" and forged.aids[1].forgeLook ~= nil and forged.skinChrome ~= nil)
	NS.capturePrompt = nil
	local sobre = Prompt("sobre")
	s.ok("Sobre : le titre ambre d'avant, sans plaque", sobre and sobre ~= forged and not sobre.forged
		and Same(sobre.title.textColor, Theme.GOLD) and sobre.throw.forge == nil and sobre.aids[1].forgeLook == nil)
	NS.capturePrompt = nil
	s.check("[FSC] « Capturer ? » : briques du socle, titre de l'identité au thème forgé, Sobre inchangé")
end

-- ---------------------------------------------------------------------------
-- 8. Contrastes : chaque nouveau texte sur son vrai fond (WCAG)
-- ---------------------------------------------------------------------------
do
	Say("-- scènes forgées : contrastes")
	FS.Reset()
	local s = Steps()
	local function Plate(tint) return { Theme.ForgeSurface(tint, Theme.FORGE.label.light), Theme.ForgeSurface(tint, Theme.FORGE.label.dark),
		Theme.ForgeSurface(tint, Theme.FORGE.plateTop) } end
	local function Worst(ink, backs)
		local worst = math.huge
		for _, back in ipairs(backs) do worst = math.min(worst, Theme.Contrast(ink, back)) end
		return worst
	end
	local head = Plate(Theme.FORGE_HEADER.warm)
	local verdict = { Theme.Over(Theme.WINDOW, Theme.NAV, 0.96), Theme.NAV }
	local window = { Theme.WINDOW }
	local inks = NS.ForgeSceneInks()
	local pairs_ = {
		{ "plaque : titre « CAPTURE · RANG » (identité)", Theme.IDENTITY_LIGHT, head, 4.5 },
		{ "plaque : compteur de la volée (titre)", Theme.TITLE, head, 3 },
		{ "verdict : « CAPTURÉ ! » (titre)", inks.title, verdict, 3 },
		{ "verdict : « ÉCHAPPÉ… » (rouge)", inks.fail, verdict, 3 },
		{ "verdict : le nom", inks.name, verdict, 4.5 },
		{ "verdict : le nom d'une brillante", inks.shiny, verdict, 4.5 },
		{ "verdict : la phrase", inks.phrase, verdict, 4.5 },
		{ "verdict : niveau sur l'or", inks.levelGold, Plate(Theme.FORGE_PLATE.gold), 4.5 },
		{ "verdict : niveau sur l'ardoise", inks.levelGrey, Plate(Theme.FORGE_PLATE.neutral), 4.5 },
		{ "volée : badge sur l'or", Theme.FORGE_INK.gold, Plate(Theme.FORGE_PLATE.gold), 4.5 },
		{ "volée : « Aide : … » (sélection)", inks.chosen, window, 4.5 },
		{ "choix : la légende (identité)", inks.caption, window, 4.5 },
		{ "choix : temps en pause, lignes de dessous, raccourcis", inks.sub, window, 4.5 },
		{ "choix : « brillante » en or", Theme.GOLD_LIGHT, window, 4.5 },
		{ "« Capturer ? » : le titre (identité)", Theme.IDENTITY_LIGHT, window, 4.5 },
	}
	for class, rarity in pairs(NS.CAPTURE_RARITY) do
		pairs_[#pairs_ + 1] = { "plaque : nom de rang " .. class, rarity.text, head, 4.5 }
	end
	pairs_[#pairs_ + 1] = { "plaque : nom d'une brillante", NS:CaptureRarity({ shiny = true }).text, head, 4.5 }
	for _, p in ipairs(pairs_) do
		local ratio = Worst(p[2], p[3])
		s.ok(p[1], ratio >= p[4], string.format("%.2f < %.1f", ratio, p[4]))
	end
	s.check("[FSC] contrastes des nouveaux textes des scènes forgées (≥ 4,5 texte, ≥ 3 titres)")
end

-- Rangement
do
	DropScenes()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	NS.captureResultPending, NS.captureResultHideAt, NS.captureBatch = nil, nil, nil
	for _, name in ipairs(GLOBALS) do _G[name] = FS.saved[name] end
	_G.UIParent.width = FS.savedWidth
	math.random = FS.random
	NS.SHINY_CHANCE = FS.savedShiny
	NS:DB().winterVeil = nil
	NS:DB().companionStyle = "azeroth"
	ResetWorld()
	NS.Theme.ApplySkin(NS:UISkinChoice())
end
NS.CaptureRollQuality = FS.rollQuality
