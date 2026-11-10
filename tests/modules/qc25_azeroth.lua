-- Compagnon : le style de l'interface « Azeroth » (QuestCompanion 2.5.0) :
-- bandeaux dorés façon hauts faits (atlas du client), repli Sobre quand le
-- client n'a pas ces textures, réglage appliqué sans /reload, bandeau
-- « Capture possible » (bandeau + bande sombre, sans chevauchement), bandeau
-- de guilde, tampons, bandeau de résultat « Capturé ! » (seul, meilleur
-- d'un lot, brillante, sourdine, combat), cadre du compagnon et filet.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local AZT = { saved = {}, random = math.random, units = {}, sounds = {}, savedCreateFrame = _G.CreateFrame }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"InCombatLockdown", "UnitAffectingCombat", "PlaySound", "C_Texture" }
for _, name in ipairs(GLOBALS) do AZT.saved[name] = rawget(_G, name) end
AZT.savedShiny = NS.SHINY_CHANCE
local PLAYER = "Player-1-00000001"
local LAY = NS.AZEROTH_LAYOUT

function AZT.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function AZT.Install()
	local w = AZT
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
	_G.UnitAffectingCombat = function() return w.combat == true end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.PlaySound = function(id) w.sounds[#w.sounds + 1] = id; return true end
end
local FIELDS = { "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt",
	"captureQueueList", "captureNetButton", "captureToast", "captureResult", "guildFeatToast", "journalToast" }
-- 3.0.0 : qualité tirée au kill : fixée à 1★ (chances attendues stables)
AZT.rollQuality = AZT.rollQuality or NS.CaptureRollQuality
function AZT.Reset(atlas)
	ResetWorld()
	NS.CaptureRollQuality = function() return 1 end
	if NS.captureBatchFrame then NS.captureBatchFrame:Hide() end
	if NS.captureChooser then NS.captureChooser:Hide() end
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
	AZT.units, AZT.combat, AZT.sounds = {}, false, {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	AZT.Install()
	if atlas == false then Mock.InstallAtlas(nil) else Mock.InstallAtlas(atlas or true) end
	NS:AzerothAtlasOK(true)
	NS.SHINY_CHANCE = 0
	math.random = AZT.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = false
	NS:DB().captureMuteUntil = nil
	NS:DB().companionCaptureSound = true
	NS:DB().companionCaptureToast = true
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	NS:CompanionUpdateVisibility()
end
function AZT.Roll(value)
	math.random = function(a, b)
		if a and b then return AZT.random(a, b) end
		if a then return AZT.random(a) end
		return value
	end
end
function AZT.SeeKill(npcID, fields)
	fields = fields or {}
	fields.guid = fields.guid or AZT.Guid(npcID, fields.spawn)
	fields.name = fields.name or ("Bête " .. npcID)
	AZT.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, fields.guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, fields.guid, 0)
	return fields.guid
end
-- l'horloge de la capture, seconde par seconde ; rend le bandeau de résultat
-- s'il est apparu entre-temps
function AZT.Tick(seconds)
	local seen
	for _ = 1, seconds do
		Mock:Advance(1)
		NS:CaptureTick(NS.Now())
		if NS.captureResult and NS.captureResult:IsShown() then seen = seen or NS.captureResult end
	end
	return seen
end
local function Y(region) local _, _, _, _, y = region:GetPoint(1); return y end

-- 1. Par défaut : Azeroth ; sans les atlas du client : Sobre --------------------------------------
do
	Say("-- azeroth : style par défaut et repli")
	AZT.Reset(false)
	Check("[AZ] réglage par défaut : azeroth", NS:DB().companionStyle == "azeroth" and NS:UIStyleChoice() == "azeroth")
	Check("[AZ] client sans C_Texture : repli Sobre", not NS:AzerothAtlasOK() and NS:UIStyle() == "sobre" and not NS:AzerothOn())
	AZT.SeeKill(7100, { name = "Raptor" })
	local toast = NS.captureToast
	Check("[AZ] repli : le bandeau Sobre, sans erreur", toast and toast:IsShown() and toast.uiStyle == "sobre"
		and not toast.azeroth and toast.info:GetText() ~= nil)
	-- un atlas manque : repli aussi, et l'infobulle du réglage le dit
	AZT.Reset({ ["ui-achievement-guild-iconframe"] = true })
	local row
	for _, page in ipairs(NS.OPTION_PAGES) do
		if page.id == "companionMain" then
			for index, r in ipairs(page.rows) do
				if r.key == "companionStyle" then row = r; row.index = index end
				if r.key == "companionFraming" then AZT.framingIndex = index end
			end
		end
	end
	Check("[AZ] un atlas manque : Sobre", NS:UIStyle() == "sobre")
	Check("[AZ] réglage « Style de l'interface », page Compagnon, après le cadrage", row and row.kind == "action"
		and row.index == AZT.framingIndex + 1 and #row.choices() == 2 and row.current() == "azeroth")
	Check("[AZ] infobulle : les textures manquent, Sobre à la place", row.tooltip() == NS.L.OPT_UI_STYLE_MISSING)
	AZT.Reset()
	Check("[AZ] atlas présents : Azeroth, l'infobulle ne dit rien", NS:UIStyle() == "azeroth" and row.tooltip() == nil)
	Check("[AZ] textes : mêmes clés en français et en anglais", (function()
		for key in pairs(NS.AZEROTH_STRINGS.fr) do if not NS.AZEROTH_STRINGS.en[key] then return false end end
		for key in pairs(NS.AZEROTH_STRINGS.en) do if not NS.AZEROTH_STRINGS.fr[key] then return false end end
		return true
	end)())
end

-- 2. « Capture possible » : bandeau doré, bande sombre, rien ne se chevauche ------------------------
do
	Say("-- azeroth : bandeau « Capture possible »")
	AZT.Reset()
	AZT.SeeKill(7200, { name = "Loup A" })
	local toast = NS.captureToast
	Check("[AZ] bandeau Azeroth : fond des hauts faits, cadre carré, bouclier gris", toast and toast:IsShown() and toast.azeroth
		and toast.bg.atlas == "ui-achievement-alert-background" and toast.iconFrame.atlas == "ui-achievement-iconframe"
		and toast.shield:IsShown() and toast.shieldKind == "grey" and toast.shield.atlas == "ui-achievement-shield-1-desaturated")
	Check("[AZ] titre en capitales sur le parchemin, nom au centre", toast.title:GetText() == "CAPTURE POSSIBLE"
		and toast.text:GetText() == "Loup A" and toast.title:GetParent() == toast.banner and toast.text:GetParent() == toast.banner
		and toast.title.justifyH == "CENTER" and toast.text.justifyH == "CENTER")
	Check("[AZ] glyphe du filet dans le cadre", toast.icon:GetParent() == toast.banner and toast.icon.lastPoint.relTo == toast.iconFrame)
	Check("[AZ] infos et aide dans la bande sombre", toast.strip and toast.info.lastPoint.relTo == toast.strip
		and toast.hint.lastPoint.relTo == toast.strip and toast.info:GetText():find("50", 1, true) ~= nil)
	Check("[AZ] hauteur : bandeau + bande - recouvrement", toast:GetHeight() == LAY.h + LAY.strip - LAY.overlap
		and toast:GetWidth() == LAY.w, toast:GetHeight())
	-- géométrie depuis le haut du cadre (y négatifs)
	local stripTop = -(LAY.h - LAY.overlap)
	local infoTop = stripTop + Y(toast.info)
	local hintTop = stripTop + Y(toast.hint)
	local rowTop = -toast:GetHeight() + LAY.rowBottom + LAY.rowH
	Check("[AZ] la ligne d'infos sous le bandeau doré", infoTop < -LAY.h, infoTop)
	Check("[AZ] l'aide sous les infos, au-dessus des boutons", hintTop <= infoTop - 14 and hintTop - 13 >= rowTop, hintTop .. " / " .. rowTop)
	Check("[AZ] boutons dans la bande, en bas à droite", toast.mute.lastPoint.relTo == toast.strip
		and toast.mute.lastPoint.point == "BOTTOMRIGHT" and toast.muteRow.lastPoint.relTo == toast.strip)
	AZT.SeeKill(7201, { name = "Loup B" })
	local row = toast.all:GetWidth() + 6 + toast.ignore:GetWidth() + 6 + toast.mute:GetWidth() + 8
	Check("[AZ] Tout capturer, Ignorer, Sourdine tiennent dans la bande", toast.all:IsShown() and row <= LAY.stripW - 12
		and toast.all.lastPoint.relTo == toast.ignore, row)
	toast.mute:Click()
	local total = toast.muteRow.cancel:GetWidth() + 8
	for _, c in ipairs(toast.muteRow.choices) do total = total + c:GetWidth() + 4 end
	Check("[AZ] durées de sourdine : tout tient dans la bande", toast.muteRow:IsShown() and total <= LAY.stripW - 12, total)
	toast.muteRow.cancel:Click()
	-- l'apparition : éclosion, lueur ; finie au bout de 2,4 s
	toast:Hide()
	NS:CaptureToastShow()
	Check("[AZ] apparition : le bandeau éclot", toast.animating and toast.banner.scripts.OnUpdate ~= nil
		and (toast.banner.frameScale or 1) < 1)
	Mock:Advance(1)
	Mock:Advance(1.5)   -- avant les 3 s d'affichage (2.9.0)
	Check("[AZ] … puis se fige (plus d'horloge)", not toast.animating and toast.banner.scripts.OnUpdate == nil
		and toast.banner.frameScale == 1 and toast.glow.alpha == 0)
	Check("[AZ] clic sur le bandeau : même geste que le filet", toast.button and toast.button.scripts.OnClick ~= nil)
end

-- 3. Nom long : la police rapetisse ; extrême : coupé par la largeur ---------------------------------
do
	Say("-- azeroth : noms longs")
	AZT.Reset()
	AZT.SeeKill(7300, { name = "Kodo" })
	local toast = NS.captureToast
	-- le faux client mesure à la taille de police posée
	function toast.text:GetStringWidth() return #(self.text or "") * ((self.font and self.font.size) or 20) * 0.55 end
	Check("[AZ] nom court : taille pleine", select(1, toast:Fit()) == LAY.nameMax)
	toast.text:SetText("Grand trotteur des plaines ancestrales")
	local size, fits = toast:Fit()
	Check("[AZ] nom long : police plus petite, il tient", size < LAY.nameMax and size >= LAY.nameMin and fits
		and toast.text:GetStringWidth() <= LAY.nameW, size)
	toast.text:SetText(string.rep("Très long nom ", 8))
	size, fits = toast:Fit()
	Check("[AZ] nom extrême : au plus petit, largeur fixe (points de suspension)", size == LAY.nameMin and not fits
		and toast.text.width == LAY.nameW and toast.text.wordWrap == false)
end

-- 4. Le réglage s'applique tout de suite --------------------------------------------------------------
do
	Say("-- azeroth : changement de style en direct")
	AZT.Reset()
	AZT.SeeKill(7400, { name = "Sanglier" })
	local az = NS.captureToast
	Check("[AZ] bandeau Azeroth affiché", az and az.azeroth and az:IsShown())
	NS:SetUIStyle("sobre")
	local sobre = NS.captureToast
	Check("[AZ] → Sobre : le bandeau est remplacé et reste affiché", sobre and sobre ~= az and not sobre.azeroth
		and sobre:IsShown() and not az:IsShown() and sobre.text:GetText() == "Sanglier" and NS:DB().companionStyle == "sobre")
	NS:SetUIStyle("azeroth")
	Check("[AZ] → Azeroth : le même cadre revient (gardé, pas recréé)", NS.captureToast == az and az:IsShown() and not sobre:IsShown())
	Check("[AZ] style inconnu : refusé", NS:SetUIStyle("rose") == nil and NS:DB().companionStyle == "azeroth")
	-- /qc style
	local printed = {}
	local oldPrint = NS.Print
	NS.Print = function(_, msg) printed[#printed + 1] = msg end
	NS.EXTRA_COMMANDS["style"](NS, "sobre")
	Check("[AZ] /qc style sobre", NS:DB().companionStyle == "sobre" and NS.captureToast == sobre
		and printed[1] == NS:F("UI_STYLE_MSG", NS.L.UI_STYLE_sobre), printed[1])
	NS.EXTRA_COMMANDS["style"](NS, "azeroth")
	Check("[AZ] /qc style azeroth", NS:DB().companionStyle == "azeroth" and NS.captureToast == az)
	NS.EXTRA_COMMANDS["style"](NS, "")
	Check("[AZ] /qc style seul : l'usage et le style actuel", printed[#printed]:find("azeroth|sobre", 1, true) ~= nil)
	Mock.InstallAtlas({ ["ui-achievement-alert-background"] = true })
	NS:AzerothAtlasOK(true)
	NS.EXTRA_COMMANDS["style"](NS, "azeroth")
	Check("[AZ] /qc style azeroth sans les textures : dit que Sobre reste", printed[#printed]
		== NS:F("UI_STYLE_MSG_MISSING", NS.L.UI_STYLE_azeroth) and NS:UIStyle() == "sobre" and not NS.captureToast.azeroth)
	NS.Print = oldPrint
end

-- 5. Bandeau de guilde, tampons, sceaux --------------------------------------------------------------
do
	Say("-- azeroth : guilde et carnet")
	AZT.Reset()
	NS:GuildFeatsShowToast({ key = "x", sender = "Xan-Royaume", feat = { kind = "s" }, score = 1000, at = Mock.now,
		info = { line = "Xan a capturé une brillante !", shiny = true, class = "normal", name = "Sanglier", stars = 2 } })
	local f = NS.guildFeatToast
	Check("[AZ] guilde : fond de guilde, cadre rond à volutes, pas de bouclier", f and f.azeroth and f:IsShown()
		and f.bg.atlas == "ui-achievement-guild-background" and f.iconFrame.atlas == "ui-achievement-guild-iconframe"
		and not f.shield:IsShown())
	Check("[AZ] guilde : « GUILDE », la ligne, la créature dessous", f.title:GetText() == "GUILDE"
		and f.text:GetText() == "Xan a capturé une brillante !" and f.info == f.stars and (f.info:GetText() or "") ~= "")
	Check("[AZ] guilde : brillante, nom en or, reflet", f.text.textColor[2] < 0.95 and f.animShine == true)
	Check("[AZ] guilde : clic → fiche, glisser", f.button and f.button.scripts.OnClick ~= nil and f.scripts.OnDragStop ~= nil)
	NS:GuildFeatsHideToast()
	-- tampon
	NS:JournalNotify({ kind = "subzone", name = "Comté-du-Nord", id = "subzone:1" })
	local j = NS.journalToast
	Check("[AZ] tampon : bandeau doré, bouclier d'or et son éclat", j and j.azeroth and j:IsShown()
		and j.shieldKind == "gold" and j.shield.atlas == "ui-achievement-shield-1" and j.animBling == true
		and j.text:GetText() == "Comté-du-Nord" and j.title:GetText():find("NOUVEAU TAMPON", 1, true) == 1, j and j.title:GetText())
	NS:UpdateJournalToast(NS.Now() + 10)
	-- sceau de zone et titre : leur bandeau aussi, dans la file du carnet
	NS:JournalToastPush({ kind = "seal", name = "Mulgore" })
	Check("[AZ] sceau de zone : un bandeau « Sceau de zone »", j:IsShown() and j.text:GetText() == "Mulgore"
		and j.title:GetText():find("SCEAU DE ZONE", 1, true) ~= nil, j.title:GetText())
	NS:UpdateJournalToast(NS.Now() + 10)
	NS:DB().journalToast = false
	Check("[AZ] bandeaux du carnet coupés : pas de sceau", NS:JournalToastPush({ kind = "rank", name = "Dresseur" }) == false)
	NS:DB().journalToast = true
	-- en Sobre, les mêmes bandeaux d'avant
	NS:SetUIStyle("sobre")
	NS:JournalNotify({ kind = "subzone", name = "Bois-Doré", id = "subzone:2" })
	Check("[AZ] Sobre : le bandeau de tampon d'avant", NS.journalToast and not NS.journalToast.azeroth
		and NS.journalToast.diamond ~= nil and NS.journalToast.text:GetText() == "Bois-Doré")
end

-- 6. Bandeau de résultat ------------------------------------------------------------------------------
do
	Say("-- azeroth : « Capturé ! »")
	AZT.Reset()
	AZT.SeeKill(7600, { name = "Raptor" })
	AZT.Roll(0)
	NS:CaptureThrow()
	local tries = 0
	while NS.captureState.rolling and not NS.captureState.rolling.result and tries < 10 do
		Mock:Advance(1); NS:CaptureTick(NS.Now()); tries = tries + 1
	end
	Check("[AZ] verdict tombé : pas encore de bandeau (la scène est là)", NS.captureState.rolling ~= nil
		and not (NS.captureResult and NS.captureResult:IsShown()) and NS.captureResultPending ~= nil)
	local seen = AZT.Tick(3)
	Check("[AZ] scène refermée : « Capturé ! », bouclier d'or, étoiles, éclat", seen and seen.azeroth
		and seen.title:GetText() == "CAPTURÉ !" and seen.text:GetText() == "Raptor" and seen.shieldKind == "gold"
		and (seen.stars:GetText() or "") ~= "" and seen.animBling == true and not seen.animShine, seen and seen.title:GetText())
	AZT.Tick(4)
	Check("[AZ] … puis s'efface (3,5 s)", not NS.captureResult:IsShown())
	-- brillante : titre, nom en or, reflet
	NS:CaptureResultQueue({ name = "Kodo doré", shiny = true, stars = 3 })
	NS:CaptureTick(NS.Now())
	local r = NS.captureResult
	Check("[AZ] brillante : « Brillant capturé ! », nom en or, reflet", r:IsShown() and r.title:GetText() == "BRILLANT CAPTURÉ !"
		and r.text.textColor[3] < 0.6 and r.animShine == true)
	NS:CaptureResultHide()
	-- sourdine : rien
	NS:CaptureMute(15)
	NS:CaptureResultQueue({ name = "Loup", stars = 1 })
	NS:CaptureTick(NS.Now())
	Check("[AZ] sourdine : pas de bandeau, oublié", not r:IsShown() and NS.captureResultPending == nil)
	NS:CaptureUnmute()
	-- combat : il attend la fin, et s'efface si un combat commence
	AZT.combat = true
	NS:CaptureResultQueue({ name = "Loup", stars = 1 })
	NS:CaptureTick(NS.Now())
	Check("[AZ] en combat : il attend", not r:IsShown() and NS.captureResultPending ~= nil)
	AZT.combat = false
	NS:CaptureTick(NS.Now())
	Check("[AZ] fin du combat : il s'affiche", r:IsShown() and r.text:GetText() == "Loup")
	AZT.combat = true
	NS:CaptureTick(NS.Now())
	Check("[AZ] un combat commence : il s'efface", not r:IsShown())
	AZT.combat = false
	-- trop vieux : oublié
	NS:CaptureResultQueue({ name = "Vieux", stars = 1 })
	AZT.combat = true
	Mock.now = Mock.now + NS.CAPTURE_RESULT_STALE + 1
	NS:CaptureTick(NS.Now())
	AZT.combat = false
	Check("[AZ] attendu trop longtemps : oublié", NS.captureResultPending == nil and not r:IsShown())
	-- Sobre : le bandeau du thème
	NS:SetUIStyle("sobre")
	NS:CaptureResultQueue({ name = "Ours", stars = 2 })
	NS:CaptureTick(NS.Now())
	local s = NS.captureResult
	Check("[AZ] Sobre : le bandeau du thème, mêmes textes", s and s ~= r and not s.azeroth and s:IsShown()
		and s.title:GetText() == "CAPTURÉ !" and s.text:GetText() == "Ours")
	NS:CaptureResultHide()
end

-- 7. Tout capturer : un seul bandeau, pour la plus belle prise -----------------------------------------
do
	Say("-- azeroth : résultat d'un lot")
	AZT.Reset()
	NS:DB().companionCaptureAnim = true
	AZT.SeeKill(7700, { name = "Loup gris" })
	AZT.SeeKill(7701, { name = "Chef raptor", class = "elite" })
	AZT.SeeKill(7702, { name = "Sanglier" })
	AZT.Roll(0)
	local batch = NS:CaptureBatch()
	Check("[AZ] lot lancé, la volée à l'écran", batch and batch.tried == 3 and NS.captureBatchFrame:IsShown())
	NS:CaptureBatchStop(true)
	NS:CaptureTick(NS.Now())
	Check("[AZ] volée encore ouverte : pas de bandeau", not (NS.captureResult and NS.captureResult:IsShown())
		and NS.captureResultPending and NS.captureResultPending.name == "Chef raptor")
	NS.captureBatchFrame:Hide()
	NS:CaptureTick(NS.Now())
	local r = NS.captureResult
	Check("[AZ] volée fermée : un bandeau, la plus belle prise (l'élite), « et 2 de plus »", r and r:IsShown()
		and r.text:GetText() == "Chef raptor" and r.stars:GetText():find(NS:F("CAPTURE_RESULT_MORE", 2), 1, true) ~= nil,
		r and r.stars:GetText())
	NS:CaptureResultHide()
	NS:DB().companionCaptureAnim = false
end

-- 8. Cadre du compagnon ---------------------------------------------------------------------------------
do
	Say("-- azeroth : cadre du compagnon")
	AZT.Reset()
	local frame = NS:EnsureCompanionFrame()
	local skin = frame and frame.azSkin
	Check("[AZ] compagnon : anneau à volutes et plaque dorée", skin and skin:IsShown() and frame.uiStyle == "azeroth"
		and skin.ring.atlas == "ui-achievement-guild-iconframe" and skin.plate.atlas == "ui-achievement-alert-background-mini")
	Check("[AZ] compagnon : nom sur la plaque, humeur dans son rabat, nom blanc", frame.name:GetParent() == skin and frame.mood:GetParent() == skin.moodTab
		and frame.name.textColor[1] == 1 and frame.name.textColor[3] == 1)
	do
		-- 2.6.0 : le nom au milieu de la bande sombre, l'humeur dans la bande claire, centrés sur la plaque
		local P = NS.AZEROTH_COMPANION_PLATE
		local np, nrel, nrp, nx, ny = frame.name:GetPoint(1)
		local mp, mrel, mrp, mx, my = frame.mood:GetPoint(1)
		Check("[AZ] compagnon : nom centré dans la bande sombre de la plaque", np == "CENTER" and nrel == skin.plate and nrp == "BOTTOM"
			and nx == 0 and ny == P.nameY and ny < P.height * 0.7, tostring(np) .. " " .. tostring(ny))
		-- 2.13.1 : l'humeur quitte la bande claire (cachée par le cadre gagné) : rabat sous la plaque
		Check("[AZ] compagnon : humeur centrée dans son rabat, sous la plaque", mp == "CENTER" and mrel == skin.moodTab and mx == 0,
			tostring(mp) .. " " .. tostring(mx))
		Check("[AZ] compagnon : plaque à la hauteur des deux lignes", skin.plate:GetHeight() == P.height)
		-- 2.13.1 : rabat de l'humeur, teinté selon l'humeur, encre lisible
		local tab, T = skin.moodTab, NS.AZEROTH_MOOD_TAB
		local tp, trel, trp, tx, ty = tab:GetPoint(1)
		Check("[AZ] humeur : rabat accroché sous la plaque, glissé dessous", tp == "TOP" and trel == skin.plate and trp == "BOTTOM"
			and tx == 0 and ty == T.tuck and tab:GetFrameLevel() < skin:GetFrameLevel())
		Check("[AZ] humeur : deux losanges du jeu", #tab.diamonds == 2)
		local function Lum(c)
			local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
			return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
		end
		local worst, worstMood = 99, nil
		for _, mood in ipairs({ "radiant", "happy", "dreamy", "sleepy" }) do
			local c = T[mood]
			local ratio = (Lum(c.fill) + 0.05) / (Lum(c.ink) + 0.05)
			if ratio < worst then worst, worstMood = ratio, mood end
		end
		Check("[AZ] humeur : encre ≥ 7:1 sur chaque teinte", worst >= 7, string.format("%s %.2f", tostring(worstMood), worst))
		local data = NS:CompanionData()
		data.sleepy = true
		NS:CompanionRefreshLabels()
		Check("[AZ] humeur : somnolent → rabat gris, encre grise", tab.mood == "sleepy" and frame.mood.textColor[1] == T.sleepy.ink[1])
		data.sleepy = nil
		for _, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do data.needs[key] = 90 end
		NS:CompanionRefreshLabels()
		Check("[AZ] humeur : radieux → rabat vert pâle", tab.mood == "radiant" and frame.mood:GetText() == NS.L.COMP_MOOD_radiant)
		Check("[AZ] humeur : rabat à la largeur du mot", tab:GetWidth() >= 2 * T.pad)
		Check("[AZ] humeur : bande claire sans voile", not skin.moodBand or skin.moodBand.mockHidden == true or not skin.moodBand:IsShown())
	end
	Check("[AZ] compagnon : liseré rectangulaire caché", frame.top.mockHidden and frame.leftEdge.mockHidden)
	Check("[AZ] compagnon : l'habillage ne prend pas la souris (caresse, survol)", not skin.mouseEnabled
		and frame.scripts.OnEnter ~= nil and frame.scripts.OnMouseUp ~= nil)
	Check("[AZ] compagnon : même taille de cadre (taille et cadrage inchangés)", frame:GetWidth() == 104 and frame:GetHeight() == 118)
	NS:CompanionSetStyle("frame", NS:CompanionCurrentStyle("frame").id)
	Check("[AZ] le cadre gagné ne revient pas par-dessus l'anneau", frame.top.mockHidden)
	-- taille : l'habillage suit l'échelle du cadre (enfant)
	NS:DB().companionSize = 4
	NS:CompanionApplySize()
	Check("[AZ] taille très grande : l'habillage suit", skin:GetParent() == frame and frame:GetScale() == NS.COMPANION_SIZES[4])
	NS:DB().companionSize = 2
	NS:CompanionApplySize()
	Check("[AZ] cadrage : toujours réglable", NS:CompanionSetFraming("pied") == "pied" and NS:CompanionSetFraming("portrait") == "portrait")
	-- le filet reste à côté du cadre, l'anneau ne déborde pas jusqu'à lui
	AZT.SeeKill(7800, { name = "Raptor" })
	local net = NS.captureNetButton
	local p = net and net.lastPoint
	Check("[AZ] filet à côté du cadre", net and net:IsShown() and p and p.relTo == frame
		and math.abs(p.x or 0) == NS.CAPTURE_NET_GAP)
	Check("[AZ] l'anneau et la plaque ne touchent pas le filet", (NS.AZEROTH_RING.w - frame:GetWidth()) / 2 < NS.CAPTURE_NET_GAP
		and (skin.plate:GetWidth() - frame:GetWidth()) / 2 < NS.CAPTURE_NET_GAP)
	-- Sobre : l'habillage s'en va, le cadre d'avant revient
	NS:SetUIStyle("sobre")
	Check("[AZ] Sobre : cadre d'avant (liseré, nom sur le cadre)", not skin:IsShown() and frame.uiStyle == "sobre"
		and frame.name:GetParent() == frame and not frame.top.mockHidden
		and select(2, frame.name:GetPoint(1)) == frame and select(5, frame.name:GetPoint(1)) == 19)
	Check("[AZ] Sobre : l'humeur revient sur le cadre (hors du rabat)", frame.mood:GetParent() == frame
		and select(2, frame.mood:GetPoint(1)) == frame)
	NS:SetUIStyle("azeroth")
	Check("[AZ] Azeroth de nouveau : rhabillé sur place", skin:IsShown() and frame.name:GetParent() == skin and frame.top.mockHidden)
	-- page Guide : le réglage y est cité
	local found = false
	for _, block in ipairs(NS:JournalGuideBlocks("settings")) do
		local text = type(block) == "table" and (block.text or block[2]) or block
		if type(text) == "string" and text:find(NS.L.UI_STYLE_azeroth, 1, true) then found = true end
	end
	Check("[AZ] page Guide : « Style de l'interface » dans Réglages", found)
end

-- Rangement : les autres modules testent le style Sobre (client sans atlas)
do
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:ApplyUIStyle()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	if NS.captureBatchFrame then NS.captureBatchFrame:Hide() end
	NS.uiStyleCache = {}
	NS.captureResultPending, NS.captureResultHideAt, NS.captureBatch = nil, nil, nil
	for _, name in ipairs(GLOBALS) do _G[name] = AZT.saved[name] end
	_G.CreateFrame = AZT.savedCreateFrame
	math.random = AZT.random
	NS.SHINY_CHANCE = AZT.savedShiny
	if AZT.rollQuality then NS.CaptureRollQuality = AZT.rollQuality end
	ResetWorld()
end
