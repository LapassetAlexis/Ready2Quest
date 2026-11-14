-- Compagnon : le style de l'interface « Azeroth » (QuestCompanion 2.5 → 2.11).
-- Défaut Azeroth, repli Sobre quand le client n'a pas les atlas, réglage et
-- /qc style appliqués à chaud ; contraste mesuré (table ns.AZEROTH_CONTRAST
-- recalculée ici, seuils WCAG par rôle sur le pire fond réel) ; bandeaux
-- « Capture possible » (rien ne se chevauche, le nom tient), guilde, tampons,
-- résultat « Capturé ! » (combat, sourdine, lot), verdict (portrait, niveau
-- dans l'écu) ; cadre du compagnon (anneau, plaque, rabat de l'humeur, modèle
-- dans l'ouverture), bande Sobre lisible ; bulle sur le parchemin ; textures
-- du client par référence (QC et R2Q), jamais nos images en repli.
-- 3.1.0 : affirme l'ancien habillage (carnet en parchemin, scènes en bois, bandeaux
-- dorés, anneau) : le drapeau QNS.AZEROTH_LEGACY rallumé pour tout le module
-- (remis à la valeur du produit à sa fin, tests/run_tests.lua)
T.Legacy(true)
local Check, Say, ResetWorld, NS, RNS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.NS, T.Mock
local Theme = NS.Theme

local AZT = { saved = {}, random = math.random, units = {}, sounds = {}, savedCreateFrame = _G.CreateFrame }
local GLOBALS = { "UnitGUID", "UnitName", "UnitFullName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"InCombatLockdown", "UnitAffectingCombat", "PlaySound", "C_Texture", "Ready2Quest" }
for _, name in ipairs(GLOBALS) do AZT.saved[name] = rawget(_G, name) end
AZT.savedShiny = NS.SHINY_CHANCE
AZT.rollQuality = NS.CaptureRollQuality
local PLAYER = "Player-1-00000001"
local LAY = NS.AZEROTH_LAYOUT
local INK = NS.AZEROTH_INK

function AZT.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function AZT.Install()
	local w = AZT
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = w.units[unit]; return u and u.name end
	_G.UnitFullName = function(unit) if unit == "player" then return "Testeur", "Aeternalis" end end
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
local FIELDS = { "companionFrame", "companionBubble", "companionHover", "journalFrame", "trainerFrame", "capturePrompt",
	"captureQueueList", "captureNetButton", "captureToast", "captureResult", "guildFeatToast", "journalToast" }
-- atlas : nil = tous présents, false = client sans C_Texture, table = ces atlas manquent
function AZT.Reset(atlas)
	ResetWorld()
	-- 3.0.0 : qualité tirée au kill : fixée à 1★ (chances attendues stables)
	NS.CaptureRollQuality = function() return 1 end
	if NS.captureBatchFrame then NS.captureBatchFrame:Hide() end
	if NS.captureChooser then NS.captureChooser:Hide() end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache, NS.errors, NS.carnetMissing = {}, {}, {}
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureToastHideAt, NS.captureAppCache, NS.captureBatch = nil, nil, nil
	NS.captureResultPending, NS.captureResultHideAt = nil, nil
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	AZT.units, AZT.combat, AZT.sounds = {}, false, {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	Mock.world.textureRefused = nil
	AZT.Install()
	if atlas == false then Mock.InstallAtlas(nil) else Mock.InstallAtlas(atlas or true) end
	NS:AzerothAtlasOK(true)
	NS.SHINY_CHANCE = 0
	math.random = AZT.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	local db = NS:DB()
	db.companionCaptureAnim, db.captureMuteUntil = false, nil
	db.companionCaptureSound, db.companionCaptureToast = true, true
	db.companionSize, db.companionFraming = nil, nil
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
-- l'horloge de la capture, seconde par seconde ; rend le bandeau de résultat s'il est apparu
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
local function Point(region, name)
	for _, p in ipairs(region and region.points or {}) do if p.point == name then return p end end
	return nil
end
local function Same(c, ref)
	if not (c and ref) then return false end
	for i = 1, 3 do if math.abs((c[i] or -1) - ref[i]) > 0.001 then return false end end
	return true
end
local function NoErrors()
	local list = {}
	for _, e in ipairs(NS.errors or {}) do list[#list + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
	return #list == 0, table.concat(list, " | ")
end
-- Luminance et contraste WCAG 2.x, recalculés ici (sans les fonctions de l'addon)
local function Lin(c) if c <= 0.03928 then return c / 12.92 end return ((c + 0.055) / 1.055) ^ 2.4 end
local function Lum(c) return 0.2126 * Lin(c[1]) + 0.7152 * Lin(c[2]) + 0.0722 * Lin(c[3]) end
local function Ratio(c, bg)
	local a, b = Lum(c), type(bg) == "table" and Lum(bg) or bg
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end
local function Over(top, bottom, alpha)
	return { top[1] * alpha + bottom[1] * (1 - alpha), top[2] * alpha + bottom[2] * (1 - alpha),
		top[3] * alpha + bottom[3] * (1 - alpha) }
end

-- 1. Par défaut : Azeroth ; sans les atlas du client : Sobre -------------------------------------------
do
	Say("-- azeroth : style par défaut et repli")
	AZT.Reset(false)
	Check("[AZ] défaut azeroth ; client sans C_Texture : repli Sobre", NS:DB().companionStyle == "azeroth"
		and NS:UIStyleChoice() == "azeroth" and not NS:AzerothAtlasOK() and NS:UIStyle() == "sobre" and not NS:AzerothOn())
	AZT.SeeKill(7100, { name = "Raptor" })
	local toast = NS.captureToast
	Check("[AZ] repli : le bandeau Sobre, sans erreur", toast and toast:IsShown() and toast.uiStyle == "sobre"
		and not toast.azeroth and toast.info:GetText() ~= nil)
	-- un atlas manque : repli aussi, et l'infobulle du réglage le dit
	AZT.Reset({ ["ui-achievement-guild-iconframe"] = true })
	local row, framingIndex
	for _, page in ipairs(NS.OPTION_PAGES) do
		if page.id == "companionMain" then
			for index, r in ipairs(page.rows) do
				if r.key == "companionStyle" then row = r; row.index = index end
				if r.key == "companionFraming" then framingIndex = index end
			end
		end
	end
	Check("[AZ] un atlas manque : Sobre ; réglage page Compagnon (après le cadrage), l'infobulle le dit", NS:UIStyle() == "sobre"
		and row and row.kind == "action" and row.index == framingIndex + 1 and #row.choices() == 2 and row.current() == "azeroth"
		and row.tooltip() == NS.L.OPT_UI_STYLE_MISSING)
	AZT.Reset()
	Check("[AZ] atlas présents : Azeroth, l'infobulle ne dit rien", NS:UIStyle() == "azeroth" and row.tooltip() == nil)
	local missing = {}
	for key in pairs(NS.AZEROTH_STRINGS.fr) do if not NS.AZEROTH_STRINGS.en[key] then missing[#missing + 1] = "en:" .. key end end
	for key in pairs(NS.AZEROTH_STRINGS.en) do if not NS.AZEROTH_STRINGS.fr[key] then missing[#missing + 1] = "fr:" .. key end end
	Check("[AZ] textes : mêmes clés en français et en anglais", #missing == 0, table.concat(missing, ", "))
end

-- 2. Contraste mesuré : chaque rôle tient son seuil sur le pire fond -----------------------------------
do
	Say("-- contraste mesuré, par rôle")
	Check("[AZ] formule WCAG : noir sur blanc 21:1", math.abs(Ratio({ 0, 0, 0 }, 1) - 21) < 0.01
		and math.abs(NS.AzerothContrast({ 1, 1, 1 }, 0) - 21) < 0.01)
	local count, bad = 0, {}
	for key, role in pairs(NS.AZEROTH_CONTRAST) do
		count = count + 1
		local color = INK[role[1]]
		local ratio = color and Ratio(color, role[2]) or 0
		local floor = role[4] >= 16 and 3 or 4.5      -- 3:1 pour 16 px et plus, 4,5:1 sinon
		if not color or ratio < math.min(role[3], 3) or ratio < floor or role[3] < floor then
			bad[#bad + 1] = key .. "=" .. string.format("%.2f", ratio)
		end
		if color and math.abs(NS.AzerothContrast(color, role[2]) - ratio) > 0.001 then bad[#bad + 1] = key .. " (formule)" end
	end
	Check("[AZ] au moins 55 rôles mesurés", count >= 55, tostring(count))
	Check("[AZ] chaque rôle : 4,5:1 (texte courant) ou 3:1 (16 px et plus) sur le pire fond", #bad == 0, table.concat(bad, ", "))
	-- les rôles signalés en jeu (2.8.2, 2.9.0, 2.11.0) : présents, et à leur propre seuil déclaré
	local roles = { "bubble.text", "bubble.name", "feat.desc", "feat.reward", "feat.date", "feat.scopeAccount", "featOpen.desc",
		"nav.label", "nav.badge", "men.no", "men.name", "men.detail", "seal.title", "seal.detail", "seal.trainer", "guide.text",
		"guide.head", "guide.title", "page.title", "banner.title", "banner.name", "verdict.title", "verdict.name", "cplate.mood",
		"trainer.band", "tile.text", "section.label", "section.detail", "effects.line", "effects.linePending", "effects.state",
		"effects.statePending", "stat.value", "stat.label", "summary.label", "summary.count", "summary.detail", "mheader.label",
		"mheader.detail", "chip.trait", "plate.count", "preview.title", "shield.count", "pantry.count", "mark.giftGold",
		"mark.giftGrey", "field.text", "navSum.name", "navSum.label", "navSum.value", "dialog.title", "dialog.sub", "dialog.text" }
	local off = {}
	for _, key in ipairs(roles) do
		local role = NS.AZEROTH_CONTRAST[key]
		if not role then off[#off + 1] = key .. " absent"
		elseif Ratio(INK[role[1]], role[2]) < role[3] then off[#off + 1] = string.format("%s %.2f<%.1f", key, Ratio(INK[role[1]], role[2]), role[3]) end
	end
	Check("[AZ] rôles signalés : dans la table, chacun à son seuil", #off == 0, table.concat(off, ", "))
	-- 2.11.0 : le cerne des étoiles (objet graphique, 3:1) sur le pire fond d'une ligne claire
	local edge = NS.AzerothContrast(NS.MEN_STAR.edge, NS.AZEROTH_CONTRAST["men.name"][2])
	Check("[AZ] étoiles des Créatures : cerne ≥ 3:1 sur la ligne claire", edge >= 3, string.format("%.2f", edge))
end

-- 3. « Capture possible » : bandeau doré, bande sombre, rien ne se chevauche --------------------------
do
	Say("-- azeroth : bandeau « Capture possible »")
	AZT.Reset()
	AZT.SeeKill(7200, { name = "Loup A" })
	local toast = NS.captureToast
	Check("[AZ] bandeau : fond des hauts faits, cadre carré, bouclier gris, clic = filet", toast and toast:IsShown() and toast.azeroth
		and toast.bg.atlas == "ui-achievement-alert-background" and toast.iconFrame.atlas == "ui-achievement-iconframe"
		and toast.shield:IsShown() and toast.shieldKind == "grey" and toast.shield.atlas == "ui-achievement-shield-1-desaturated"
		and toast.button and toast.button.scripts.OnClick ~= nil)
	Check("[AZ] titre en capitales et nom centrés sur le parchemin, filet dans le cadre", toast.title:GetText() == "CAPTURE POSSIBLE"
		and toast.text:GetText() == "Loup A" and toast.title:GetParent() == toast.banner and toast.text:GetParent() == toast.banner
		and toast.title.justifyH == "CENTER" and toast.text.justifyH == "CENTER" and toast.icon.lastPoint.relTo == toast.iconFrame)
	-- géométrie depuis le haut du cadre (y négatifs) : infos sous le bandeau, aide dessous, boutons en bas
	local stripTop = -(LAY.h - LAY.overlap)
	local infoTop, hintTop = stripTop + Y(toast.info), stripTop + Y(toast.hint)
	local rowTop = -toast:GetHeight() + LAY.rowBottom + LAY.rowH
	Check("[AZ] bande sombre : infos sous le doré, aide au-dessus des boutons, sans chevauchement", toast.strip
		and toast.info.lastPoint.relTo == toast.strip and toast.hint.lastPoint.relTo == toast.strip
		and toast:GetHeight() == LAY.h + LAY.strip - LAY.overlap and infoTop < -LAY.h and hintTop <= infoTop - 14
		and hintTop - 13 >= rowTop and toast.mute.lastPoint.relTo == toast.strip and toast.mute.lastPoint.point == "BOTTOMRIGHT"
		and toast.info:GetText():find("50", 1, true) ~= nil, infoTop .. " / " .. hintTop .. " / " .. rowTop)
	AZT.SeeKill(7201, { name = "Loup B" })
	local row = toast.all:GetWidth() + 6 + toast.ignore:GetWidth() + 6 + toast.mute:GetWidth() + 8
	Check("[AZ] Tout capturer, Ignorer, Sourdine tiennent dans la bande", toast.all:IsShown() and row <= LAY.stripW - 12
		and toast.all.lastPoint.relTo == toast.ignore, row)
	toast.mute:Click()
	local total = toast.muteRow.cancel:GetWidth() + 8
	for _, c in ipairs(toast.muteRow.choices) do total = total + c:GetWidth() + 4 end
	Check("[AZ] durées de sourdine : tout tient dans la bande", toast.muteRow:IsShown() and total <= LAY.stripW - 12
		and toast.muteRow.lastPoint.relTo == toast.strip, total)
	toast.muteRow.cancel:Click()
	-- l'apparition : éclosion, lueur ; figée avant les 3 s d'affichage (2.9.0)
	toast:Hide()
	NS:CaptureToastShow()
	local hatching = toast.animating and toast.banner.scripts.OnUpdate ~= nil and (toast.banner.frameScale or 1) < 1
	Mock:Advance(1)
	Mock:Advance(1.5)
	Check("[AZ] apparition : le bandeau éclot puis se fige (plus d'horloge)", hatching and not toast.animating
		and toast.banner.scripts.OnUpdate == nil and toast.banner.frameScale == 1 and toast.glow.alpha == 0)
	-- noms longs : la police rapetisse ; extrême : coupé par la largeur
	function toast.text:GetStringWidth() return #(self.text or "") * ((self.font and self.font.size) or 20) * 0.55 end
	toast.text:SetText("Kodo")
	local short = select(1, toast:Fit())
	toast.text:SetText("Grand trotteur des plaines ancestrales")
	local size, fits = toast:Fit()
	Check("[AZ] nom long : police plus petite, il tient (nom court : pleine taille)", short == LAY.nameMax and size < LAY.nameMax
		and size >= LAY.nameMin and fits and toast.text:GetStringWidth() <= LAY.nameW, size)
	toast.text:SetText(string.rep("Très long nom ", 8))
	size, fits = toast:Fit()
	Check("[AZ] nom extrême : au plus petit, largeur fixe (points de suspension)", size == LAY.nameMin and not fits
		and toast.text.width == LAY.nameW and toast.text.wordWrap == false)
end

-- 4. Le réglage s'applique tout de suite ----------------------------------------------------------------
do
	Say("-- azeroth : changement de style en direct")
	AZT.Reset()
	AZT.SeeKill(7400, { name = "Sanglier" })
	local az = NS.captureToast
	NS:SetUIStyle("sobre")
	local sobre = NS.captureToast
	Check("[AZ] → Sobre : le bandeau est remplacé et reste affiché", az and az.azeroth and sobre and sobre ~= az and not sobre.azeroth
		and sobre:IsShown() and not az:IsShown() and sobre.text:GetText() == "Sanglier" and NS:DB().companionStyle == "sobre")
	NS:SetUIStyle("azeroth")
	Check("[AZ] → Azeroth : le même cadre revient (gardé, pas recréé) ; style inconnu refusé", NS.captureToast == az
		and az:IsShown() and not sobre:IsShown() and NS:SetUIStyle("rose") == nil and NS:DB().companionStyle == "azeroth")
	local printed = {}
	local oldPrint = NS.Print
	NS.Print = function(_, msg) printed[#printed + 1] = msg end
	NS.EXTRA_COMMANDS["style"](NS, "sobre")
	local toSobre = NS:DB().companionStyle == "sobre" and NS.captureToast == sobre and printed[1] == NS:F("UI_STYLE_MSG", NS.L.UI_STYLE_sobre)
	NS.EXTRA_COMMANDS["style"](NS, "azeroth")
	local toAz = NS:DB().companionStyle == "azeroth" and NS.captureToast == az
	NS.EXTRA_COMMANDS["style"](NS, "")
	Check("[AZ] /qc style sobre | azeroth | seul (usage et style actuel)", toSobre and toAz
		and printed[#printed]:find("azeroth|sobre", 1, true) ~= nil, tostring(printed[1]))
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
	Check("[AZ] guilde : fond de guilde, cadre rond, pas de bouclier ; « GUILDE », la ligne, la créature", f and f.azeroth
		and f:IsShown() and f.bg.atlas == "ui-achievement-guild-background" and f.iconFrame.atlas == "ui-achievement-guild-iconframe"
		and not f.shield:IsShown() and f.title:GetText() == "GUILDE" and f.text:GetText() == "Xan a capturé une brillante !"
		and f.info == f.stars and (f.info:GetText() or "") ~= "")
	Check("[AZ] guilde : brillante en or, reflet ; clic → fiche, glisser", f.text.textColor[2] < 0.95 and f.animShine == true
		and f.button and f.button.scripts.OnClick ~= nil and f.scripts.OnDragStop ~= nil)
	-- 2.11.1 (C1) : une ligne courte sur une ligne ; trop longue : deux lignes, dans le bandeau
	Check("[AZ] guilde : ligne courte sur une ligne", f.text.fitLines == 1 and f.text.wordWrap == false
		and f.text.lastPoint.y == LAY.nameY and f.stars.lastPoint.y == LAY.starsY)
	NS:GuildFeatsHideToast()
	local long = "Dresseur confirmé Dyokrion Aeternalis a capturé 51 espèces, un exploit de longue haleine !"
	NS:GuildFeatsShowToast({ key = "a", sender = "Dyokrion-Royaume", feat = { kind = "r" }, score = 10, at = Mock.now,
		info = { kind = "r", line = long, sub = "Nouveau titre : Dresseur confirmé" } })
	Check("[AZ] guilde : ligne trop longue sur deux lignes, coupée aux mots, lisible, sous-ligne dans le bandeau",
		f.text.fitLines == 2 and f.text.wordWrap == true and (f.text.maxLines == nil or f.text.maxLines == 2)
		and (f.text.fitSize or 0) >= LAY.nameMin and f.stars.lastPoint.y == LAY.starsY2 and LAY.starsY2 > -LAY.h + 20)
	NS:GuildFeatsHideToast()
	-- palier : le titre n'est pas dit deux fois
	local code = NS.FEAT_RANK_TITLES and NS.FEAT_RANK_TITLES.trainer
	NS:GuildFeatsReset()
	local info = code and NS:GuildFeatDescribe(NS:GuildFeatParse("E~1~r~25~0~0~-~0~" .. code .. "~f"), "Bob-Royaume")
	Check("[AZ] guilde, palier : le nom seul dans la ligne, le titre dessous", info and info.line == "Bob a capturé 25 espèces !"
		and info.sub ~= nil and info.sub:find("Nouveau titre", 1, true) ~= nil, info and info.line)
	-- tampon
	NS:JournalNotify({ kind = "subzone", name = "Comté-du-Nord", id = "subzone:1" })
	local j = NS.journalToast
	Check("[AZ] tampon : bandeau doré, bouclier d'or et son éclat", j and j.azeroth and j:IsShown()
		and j.shieldKind == "gold" and j.shield.atlas == "ui-achievement-shield-1" and j.animBling == true
		and j.text:GetText() == "Comté-du-Nord" and j.title:GetText():find("NOUVEAU TAMPON", 1, true) == 1, j and j.title:GetText())
	NS:UpdateJournalToast(NS.Now() + 10)
	NS:JournalToastPush({ kind = "seal", name = "Mulgore" })
	Check("[AZ] sceau de zone : son bandeau, dans la file du carnet", j:IsShown() and j.text:GetText() == "Mulgore"
		and j.title:GetText():find("SCEAU DE ZONE", 1, true) ~= nil, j.title:GetText())
	NS:UpdateJournalToast(NS.Now() + 10)
	NS:DB().journalToast = false
	Check("[AZ] bandeaux du carnet coupés : pas de sceau", NS:JournalToastPush({ kind = "rank", name = "Dresseur" }) == false)
	NS:DB().journalToast = true
	NS:SetUIStyle("sobre")
	NS:JournalNotify({ kind = "subzone", name = "Bois-Doré", id = "subzone:2" })
	Check("[AZ] Sobre : le bandeau de tampon d'avant", NS.journalToast and not NS.journalToast.azeroth
		and NS.journalToast.diamond ~= nil and NS.journalToast.text:GetText() == "Bois-Doré")
end

-- 6. Bandeau de résultat « Capturé ! » ----------------------------------------------------------------
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
	-- espèce nouvelle : le bouton Partager, et ses 3 s de plus (3.1.0)
	AZT.Tick(4 + (NS.SHARE_EXTRA or 0))
	Check("[AZ] … puis s'efface (3,5 s, + le temps du bouton Partager)", not NS.captureResult:IsShown())
	NS:CaptureResultQueue({ name = "Kodo doré", shiny = true, stars = 3 })
	NS:CaptureTick(NS.Now())
	local r = NS.captureResult
	Check("[AZ] brillante : « Brillant capturé ! », nom en or, reflet", r:IsShown() and r.title:GetText() == "BRILLANT CAPTURÉ !"
		and r.text.textColor[3] < 0.6 and r.animShine == true)
	NS:CaptureResultHide()
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
	NS:CaptureResultQueue({ name = "Vieux", stars = 1 })
	Mock.now = Mock.now + NS.CAPTURE_RESULT_STALE + 1
	NS:CaptureTick(NS.Now())
	AZT.combat = false
	Check("[AZ] attendu trop longtemps : oublié", NS.captureResultPending == nil and not r:IsShown())
	NS:SetUIStyle("sobre")
	NS:CaptureResultQueue({ name = "Ours", stars = 2 })
	NS:CaptureTick(NS.Now())
	local s = NS.captureResult
	Check("[AZ] Sobre : le bandeau du thème, mêmes textes", s and s ~= r and not s.azeroth and s:IsShown()
		and s.title:GetText() == "CAPTURÉ !" and s.text:GetText() == "Ours")
	NS:CaptureResultHide()

	-- Tout capturer : un seul bandeau, pour la plus belle prise, après la volée
	Say("-- azeroth : résultat d'un lot")
	AZT.Reset()
	NS:DB().companionCaptureAnim = true
	AZT.SeeKill(7700, { name = "Loup gris" })
	AZT.SeeKill(7701, { name = "Chef raptor", class = "elite" })
	AZT.SeeKill(7702, { name = "Sanglier" })
	AZT.Roll(0)
	local batch = NS:CaptureBatch()
	NS:CaptureBatchStop(true)
	NS:CaptureTick(NS.Now())
	Check("[AZ] lot : volée encore ouverte, pas de bandeau (l'élite en attente)", batch and batch.tried == 3
		and NS.captureBatchFrame:IsShown() and not (NS.captureResult and NS.captureResult:IsShown())
		and NS.captureResultPending and NS.captureResultPending.name == "Chef raptor")
	NS.captureBatchFrame:Hide()
	NS:CaptureTick(NS.Now())
	r = NS.captureResult
	Check("[AZ] volée fermée : un bandeau, la plus belle prise, « et 2 de plus »", r and r:IsShown()
		and r.text:GetText() == "Chef raptor" and r.stars:GetText():find(NS:F("CAPTURE_RESULT_MORE", 2), 1, true) ~= nil,
		r and r.stars:GetText())
	NS:CaptureResultHide()
	NS:DB().companionCaptureAnim = false
end

-- 7. Bandeau de verdict : portrait fixe dans le cadre, niveau dans l'écu --------------------------------
do
	Say("-- azeroth : verdict, portrait et niveau")
	AZT.Reset()
	local banner = NS:AzerothVerdict(UIParent, 330, 107)
	-- 2.9.0 : portrait fixe (icône du type), plus de modèle 3D
	Check("[AZ] verdict : cadre d'icône au-dessus du portrait, pas de modèle 3D", banner.iconFrame
		and banner.iconFrame.atlas == NS.AZEROTH_ATLAS.frame and banner.portrait == nil
		and banner.portraitRing.level > (banner.GetFrameLevel and banner:GetFrameLevel() or 0))
	local anchor = banner.portraitAnchor
	local size = anchor:GetWidth()
	local tl, br = Point(banner.portraitIcon, "TOPLEFT"), Point(banner.portraitIcon, "BOTTOMRIGHT")
	local cx, cy = (tl.x + br.x) / 2, (tl.y + br.y) / 2
	Check("[AZ] verdict : portrait centré dans le trou du cadre d'icône", tl.relTo == anchor and br.relTo == anchor
		and math.abs(cx - size / 2) <= 1 and math.abs(cy + size / 2) <= 1
		and tl.x >= size * NS.AZEROTH_ICON_HOLE.l - 0.5 and br.x <= size * NS.AZEROTH_ICON_HOLE.r + 0.5,
		string.format("centre %.1f,%.1f taille %s", cx, cy, size))
	banner:SetCreature({ npcID = 7001, type = "Bête" })
	local typed = banner.portraitIcon:IsShown() and banner.portraitIcon.texture == NS.MENAGERIE_TYPE_ICONS["Bête"]
		and banner.portraitNpc == 7001
	banner:SetCreature({ npcID = 7001, type = "Inconnu" })
	local fallback = banner.portraitIcon.texture == NS.AZEROTH_PORTRAIT_ICON
	banner:SetCreature(nil)
	Check("[AZ] verdict : l'icône du type, repli si inconnu, vide sans créature", typed and fallback
		and not banner.portraitIcon:IsShown())
	local vs = NS.AZEROTH_SHIELD_SIZE.verdict
	banner:SetShield("grey")
	Check("[AZ] verdict : bouclier à la taille de l'atlas (63×56), le gris de même gabarit", banner.shield:GetWidth() == vs[1]
		and banner.shield:GetHeight() == vs[2] and vs[1] == 63 and vs[2] == 56
		and banner.shield.atlas == "ui-achievement-shield-1-desaturated")
	banner:SetShield("gold")
	banner:SetLevel(12)
	local lp = Point(banner.levelText, "CENTER")
	local face = NS.AZEROTH_SHIELD_FACE
	local ex = math.floor(banner.shield:GetWidth() * face.x + 0.5)
	local ey = math.floor(banner.shield:GetHeight() * face.y + 0.5) + face.digits
	Check("[AZ] verdict : niveau au centre visuel de l'écu, centré", banner.levelText:GetText() == "12" and banner.levelText:IsShown()
		and lp and lp.relTo == banner.shield and lp.x == ex and lp.y == ey and lp.y < 3 and lp.x >= 0
		and banner.levelText.justifyH == "CENTER" and banner.levelText.justifyV == "MIDDLE", lp and (lp.x .. "," .. lp.y))
	banner:SetShield(nil); banner:SetLevel(12)
	Check("[AZ] verdict : sans bouclier, pas de niveau", not banner.levelText:IsShown())
	local toast = NS:AzerothCreateBanner({})
	Check("[AZ] verdict et bandeau : titre à l'encre sur sa bande éclaircie", banner.titleBand and banner.titleBand:IsShown()
		and Same(banner.title.textColor, INK[NS.AZEROTH_CONTRAST["verdict.title"][1]])
		and math.abs(banner.titleBand.vertex[4] - INK.alpha.strip) < 0.001 and toast.titleBand and Same(toast.title.textColor, INK.ink))
	local result = NS:CaptureResultShow({ name = "Kodo", stars = 2, npcID = 7002, level = 18, type = "Bête" })
	Check("[AZ] « Capturé ! » : tête de la créature dans le cadre, niveau 18 dans le bouclier", result and result.azeroth
		and result.banner.portraitRing:IsShown() and result.banner.levelText:GetText() == "18" and result.iconFrame.mockHidden)
	NS:CaptureResultHide()
end

-- 8. Cadre du compagnon : anneau, plaque, rabat de l'humeur ---------------------------------------------
do
	Say("-- azeroth : cadre du compagnon")
	AZT.Reset()
	local frame = NS:EnsureCompanionFrame()
	local skin = frame and frame.azSkin
	local P, TAB = NS.AZEROTH_COMPANION_PLATE, NS.AZEROTH_MOOD_TAB
	Check("[AZ] compagnon : anneau à volutes, plaque dorée, nom blanc sur la plaque, humeur dans son rabat", skin and skin:IsShown()
		and frame.uiStyle == "azeroth" and skin.ring.atlas == "ui-achievement-guild-iconframe"
		and skin.plate.atlas == "ui-achievement-alert-background-mini" and frame.name:GetParent() == skin
		and frame.mood:GetParent() == skin.moodTab and frame.name.textColor[1] == 1 and frame.name.textColor[3] == 1)
	-- 2.6.0 : le nom au milieu de la bande sombre ; 2.13.1 : l'humeur dans un rabat sous la plaque
	local np, nrel, nrp, nx, ny = frame.name:GetPoint(1)
	local mp, mrel, _, mx = frame.mood:GetPoint(1)
	local tab = skin.moodTab
	local tp, trel, trp, tx, ty = tab:GetPoint(1)
	Check("[AZ] compagnon : nom centré dans la bande sombre, humeur centrée dans son rabat glissé sous la plaque",
		np == "CENTER" and nrel == skin.plate and nrp == "BOTTOM" and nx == 0 and ny == P.nameY and ny < P.height * 0.7
		and skin.plate:GetHeight() == P.height and mp == "CENTER" and mrel == tab and mx == 0
		and tp == "TOP" and trel == skin.plate and trp == "BOTTOM" and tx == 0 and ty == TAB.tuck
		and tab:GetFrameLevel() < skin:GetFrameLevel() and #tab.diamonds == 2, tostring(ny) .. " " .. tostring(ty))
	local worst, worstMood = 99, nil
	for _, mood in ipairs({ "radiant", "happy", "dreamy", "sleepy" }) do
		local ratio = Ratio(TAB[mood].ink, TAB[mood].fill)
		if ratio < worst then worst, worstMood = ratio, mood end
	end
	Check("[AZ] humeur : encre ≥ 7:1 sur chaque teinte du rabat", worst >= 7, string.format("%s %.2f", tostring(worstMood), worst))
	local data = NS:CompanionData()
	data.sleepy = true
	NS:CompanionRefreshLabels()
	local sleepy = tab.mood == "sleepy" and frame.mood.textColor[1] == TAB.sleepy.ink[1]
	data.sleepy = nil
	for _, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do data.needs[key] = 90 end
	NS:CompanionRefreshLabels()
	Check("[AZ] humeur : le rabat suit l'humeur (somnolent gris, radieux vert), à la largeur du mot, sans voile", sleepy
		and tab.mood == "radiant" and frame.mood:GetText() == NS.L.COMP_MOOD_radiant and Same(frame.mood.textColor, TAB.radiant.ink)
		and tab:GetWidth() >= 2 * TAB.pad and (not skin.moodBand or skin.moodBand.mockHidden == true or not skin.moodBand:IsShown()))
	Check("[AZ] compagnon : liseré caché, habillage sans souris (caresse, survol), taille 104×118", frame.top.mockHidden
		and frame.leftEdge.mockHidden and not skin.mouseEnabled and frame.scripts.OnEnter ~= nil and frame.scripts.OnMouseUp ~= nil
		and frame:GetWidth() == 104 and frame:GetHeight() == 118)
	NS:CompanionSetStyle("frame", NS:CompanionCurrentStyle("frame").id)
	Check("[AZ] le cadre gagné ne revient pas par-dessus l'anneau", frame.top.mockHidden)
	NS:DB().companionSize = 4
	NS:CompanionApplySize()
	local follows = skin:GetParent() == frame and frame:GetScale() == NS.COMPANION_SIZES[4]
	NS:DB().companionSize = 2
	NS:CompanionApplySize()
	Check("[AZ] taille très grande : l'habillage suit ; cadrage toujours réglable", follows
		and NS:CompanionSetFraming("pied") == "pied" and NS:CompanionSetFraming("portrait") == "portrait")
	AZT.SeeKill(7800, { name = "Raptor" })
	local net = NS.captureNetButton
	local p = net and net.lastPoint
	Check("[AZ] filet à côté du cadre, l'anneau et la plaque ne l'atteignent pas", net and net:IsShown() and p and p.relTo == frame
		and math.abs(p.x or 0) == NS.CAPTURE_NET_GAP and (NS.AZEROTH_RING.w - frame:GetWidth()) / 2 < NS.CAPTURE_NET_GAP
		and (skin.plate:GetWidth() - frame:GetWidth()) / 2 < NS.CAPTURE_NET_GAP)
	NS:SetUIStyle("sobre")
	Check("[AZ] Sobre : cadre d'avant (liseré, nom et humeur sur le cadre)", not skin:IsShown() and frame.uiStyle == "sobre"
		and frame.name:GetParent() == frame and not frame.top.mockHidden and select(2, frame.name:GetPoint(1)) == frame
		and frame.mood:GetParent() == frame and select(2, frame.mood:GetPoint(1)) == frame)
	NS:SetUIStyle("azeroth")
	Check("[AZ] Azeroth de nouveau : rhabillé sur place", skin:IsShown() and frame.name:GetParent() == skin and frame.top.mockHidden)
	local found = false
	for _, block in ipairs(NS:JournalGuideBlocks("settings")) do
		local text = type(block) == "table" and (block.text or block[2]) or block
		if type(text) == "string" and text:find(NS.L.UI_STYLE_azeroth, 1, true) then found = true end
	end
	Check("[AZ] page Guide : « Style de l'interface » dans Réglages", found)
end

-- 9. Le modèle du compagnon dans l'ouverture de l'anneau (4 tailles × 3 cadrages) -------------------------
do
	Say("-- azeroth : modèle dans le cadre du compagnon")
	AZT.Reset()
	if NS.companionFrame then NS.companionFrame:Hide() end
	NS.companionFrame = nil
	-- un client qui sait afficher une créature : PlayerModel avec SetCreature
	local create = _G.CreateFrame
	_G.CreateFrame = function(kind, ...)
		local f = create(kind, ...)
		if kind == "PlayerModel" and f then f.SetCreature = function() return true end; f.SetDisplayInfo = function() return true end end
		return f
	end
	NS:CompanionUpdateVisibility()
	local frame = NS:EnsureCompanionFrame()
	_G.CreateFrame = create
	local R, hole = NS.AZEROTH_RING, NS.AZEROTH_RING_HOLE
	local fw = frame:GetWidth()
	-- 2.13.1 : l'anneau décalé de R.x pour centrer son ouverture
	local left, top = fw / 2 - R.w / 2 + (R.x or 0), R.y + R.h / 2
	local hx0, hx1 = left + R.w * hole.l, left + R.w * hole.r
	local hy0, hy1 = top - R.h * hole.t, top - R.h * hole.b
	local bad = {}
	for size = 1, #NS.COMPANION_SIZES do
		NS:DB().companionSize = size
		NS:CompanionApplySize()
		for _, framing in ipairs(NS.COMPANION_FRAMINGS) do
			NS:CompanionSetFraming(framing)
			local model = frame.model
			local q = Point(model, "TOPLEFT")
			local x0, y0 = q and q.x or 0, q and q.y or 0
			local x1, y1 = x0 + model:GetWidth(), y0 - model:GetHeight()
			if not q or q.relTo ~= frame or x0 < hx0 or x1 > hx1 or y0 > hy0 or y1 < hy1 or model:GetWidth() < 40
				or model.framingZoom ~= NS.COMPANION_FRAMING_ZOOM[framing] then
				bad[#bad + 1] = string.format("%d/%s %s,%s %s×%s", size, framing, x0, y0, model:GetWidth(), model:GetHeight())
			end
		end
	end
	Check("[AZ] 4 tailles × 3 cadrages : le modèle dans l'ouverture, sous l'anneau", frame.model ~= nil and #bad == 0
		and frame.model.level < frame.azSkin.level, table.concat(bad, " | "))
	NS:CompanionPlaceModel(2, -1)
	local p = Point(frame.model, "TOPLEFT")
	Check("[AZ] les effets (rebond) décalent depuis l'ouverture", p.x == frame.modelBase.x + 2 and p.y == frame.modelBase.y - 1)
	NS:CompanionPlaceModel(0, 0)
	NS:SetUIStyle("sobre")
	p = Point(frame.model, "TOPLEFT")
	Check("[AZ] Sobre : le modèle reprend sa place d'avant", frame.modelBase == NS.COMPANION_MODEL_BASE and p.x == 4 and p.y == -4
		and frame.model:GetWidth() == NS.COMPANION_MODEL_BASE.w)
end

-- 10. Sobre : la bande sous le nom et l'humeur, noms élite/rare lisibles (2.11.0, fiche 09) ---------------
do
	Say("-- sobre : humeur lisible, rangs")
	AZT.Reset(false)
	local frame = NS:EnsureCompanionFrame()
	NS:CompanionRefreshLabels()
	local a = NS.CompanionPlateAlpha()
	local c = frame.mood.textColor
	Check("[AZ] Sobre : bande sombre sous le nom et l'humeur, humeur en TEXT", frame.plate and frame.plate:IsShown()
		and frame.plate.height == NS.COMPANION_PLATE_H and c and math.abs(c[1] - Theme.TEXT[1]) < 0.001)
	local white, parchment = { 1, 1, 1 }, { 0.85, 0.78, 0.62 }
	local r1, r2 = Ratio(Theme.TEXT, Over(Theme.INK, white, a)), Ratio(Theme.TEXT, Over(Theme.INK, parchment, a))
	local name = Ratio(Theme.PARCHMENT, Over(Theme.INK, white, a))
	Check("[AZ] Sobre : humeur (sol blanc, parchemin clair) et nom ≥ 4,5:1 sur la bande", r1 >= 4.5 and r2 >= 4.5 and name >= 4.5,
		string.format("%.2f / %.2f / %.2f", r1, r2, name))
	frame.uiStyle = "azeroth"
	NS:CompanionApplySobrePlate()
	local hidden = not frame.plate:IsShown()
	frame.uiStyle = "sobre"
	NS:CompanionApplySobrePlate()
	Check("[AZ] Azeroth : la bande du Sobre se cache ; retour en Sobre : elle revient", hidden and frame.plate:IsShown())
	local elite, rare = NS:CaptureRarity({ class = "elite" }), NS:CaptureRarity({ class = "rareelite" })
	local fb = NS.CAPTURE_RANK_FALLBACK
	Check("[AZ] rangs : la marque garde la couleur du jeu, le nom la variante claire (jeton du socle)",
		elite.color == fb.elite.mark and rare.color == fb.rare.mark and elite.text ~= elite.color and rare.text ~= rare.color
		and (not (type(Theme.RANK) == "table" and Theme.RankKey) or elite.text == Theme.RANK[Theme.RankKey("elite")]))
	local worst = 99
	for _, bg in ipairs({ Theme.ROW, Theme.WINDOW, Theme.FIELD }) do
		for _, r in ipairs({ elite, rare }) do worst = math.min(worst, Ratio(r.text, bg)) end
	end
	Check("[AZ] noms élite et rare ≥ 4,5:1 sur ROW, WINDOW, FIELD", worst >= 4.5, string.format("%.2f", worst))
end

-- 11. La bulle : parchemin des hauts faits sous le texte, habit Sobre masqué ---------------------------
do
	Say("-- azeroth : bulle sur le parchemin")
	AZT.Reset()
	NS:EnsureCompanionFrame()
	Check("[AZ] le compagnon parle", NS:CompanionSay("EAT", { force = true }) == true)
	local bubble = NS.companionBubble
	local skin = bubble and bubble.azTalk
	local bg = skin and skin.bg
	Check("[AZ] bulle : parchemin 130661 par son fichier, sur la bulle, opaque", bubble and bubble:IsShown() and bubble.azBubble
		and bg and bg.texture == 130661 and NS.AZEROTH_TALK_FILE.file == 130661 and bg:GetParent() == bubble
		and bg:IsShown() and bg.vertex[4] == 1 and not bg.atlas)
	Check("[AZ] bulle : aplat clair < parchemin < voile crème (BACKGROUND), nom et texte au-dessus (OVERLAY)",
		bg.drawLayer == "BACKGROUND" and skin.backdrop:IsShown() and skin.backdrop.drawLayer == "BACKGROUND"
		and skin.backdrop.subLevel < bg.subLevel and skin.backdrop.vertex[1] > 0.85 and skin.veil.subLevel > bg.subLevel
		and skin.veil:IsShown() and math.abs(skin.veil.vertex[4] - INK.alpha.bubble) < 0.001
		and skin.text.drawLayer == "OVERLAY" and skin.name.drawLayer == "OVERLAY")
	local c = bg.texCoord
	local texRatio = (c[2] - c[1]) * 512 / ((c[4] - c[3]) * 256)
	Check("[AZ] bulle : parchemin recadré sans déformation", math.abs(texRatio - bubble:GetWidth() / bubble:GetHeight()) < 0.05,
		string.format("%.2f vs %.2f", texRatio, bubble:GetWidth() / bubble:GetHeight()))
	Check("[AZ] bulle : habit Sobre masqué (fond, filet, pointe, texte, bordure), encres de la table", bubble.bg.mockHidden
		and bubble.rule.mockHidden and bubble.tail.mockHidden and bubble.tailEdge.mockHidden and bubble.text.mockHidden
		and bubble.border.top.mockHidden and Same(skin.text.textColor, INK[NS.AZEROTH_CONTRAST["bubble.text"][1]])
		and Same(skin.name.textColor, INK[NS.AZEROTH_CONTRAST["bubble.name"][1]]))
	-- /qc debug bulle
	local printed = {}
	local print0 = NS.Print
	NS.Print = function(_, text) printed[#printed + 1] = tostring(text) end
	local lines = NS:AzerothDebugCommand("bulle")
	local help = NS:AzerothDebugCommand("")
	NS.Print = print0
	local all = table.concat(lines or {}, "\n")
	Check("[AZ] /qc debug bulle : état, couches, alpha, fichier ; autre mot : l'aide", type(NS.EXTRA_COMMANDS.debug) == "function"
		and #printed >= 8 and all:find("az.parchment: shown", 1, true) ~= nil and all:find("tex=130661", 1, true) ~= nil
		and all:find("sobre.bg: hidden", 1, true) ~= nil and all:find("BACKGROUND/1", 1, true) ~= nil
		and all:find("azeroth", 1, true) ~= nil and help == nil, all)
	local ok, errs = NoErrors()
	Check("[AZ] bulle sans erreur", ok, errs)
	NS:SetUIStyle("sobre")
	Check("[AZ] Sobre : la bulle reprend son habit", not bubble.azBubble and not bubble.bg.mockHidden and skin.bg.mockHidden)
	-- fichier refusé par le client : l'aplat clair seul, texte lisible
	AZT.Reset()
	Mock.world.textureRefused = { [130661] = true }
	NS:EnsureCompanionFrame()
	NS:CompanionSay("EAT", { force = true })
	skin = NS.companionBubble and NS.companionBubble.azTalk
	Check("[AZ] bulle : parchemin refusé → l'aplat clair seul, texte sombre", skin and skin.bg.azFailed and not skin.bg:IsShown()
		and skin.backdrop:IsShown() and skin.text.textColor[1] < 0.3)
	Mock.world.textureRefused = nil
end

-- 12. Textures du client par référence, jamais nos images en repli (2.11.0 fiche 12, 2.12.1, R2Q 1.33.1) ----
do
	Say("-- textures du client par référence")
	AZT.Reset(false)
	local tex = UIParent:CreateTexture()
	local none = NS.CaptureArtPaint(tex, "rays") == nil and tex.texture == nil and not tex.clientArt and NS.CAPTURE_ART.rays == nil
	Mock.InstallAtlas({ ["ArtifactsFX-StarBurst"] = true })
	Check("[AZ] scène : sans atlas ou atlas manquant, texture vide, aucune image à nous", none
		and NS.CaptureArtPaint(tex, "rays") == nil and tex.texture == nil)
	Mock.InstallAtlas(true)
	local expect = { rays = "ArtifactsFX-StarBurst", halo = "ChallengeMode-SoftYellowGlow", sparks = "Artifacts-Anim-Sparks",
		stars = "auctionhouse-icon-favorite", ribbon = "BossBanner-BgBanner-Mid", ground = "ChallengeMode-SoftYellowGlow" }
	local got = {}
	for role, atlas in pairs(expect) do
		local t = UIParent:CreateTexture()
		if NS.CaptureArtPaint(t, role) ~= "client" or t.atlas ~= atlas or not t.clientArt then got[#got + 1] = role end
	end
	-- « Bonus-ToastBanner » : écusson bleu sur Forever
	Check("[AZ] scène : atlas du client (rayons, halo, étincelles, étoiles, bannière, sol), pas Bonus-ToastBanner",
		#got == 0 and NS.CAPTURE_CLIENT_ART.ribbon.atlas ~= "Bonus-ToastBanner", table.concat(got, ","))
	Check("[AZ] le filet, ses cordes et le paquet restent les nôtres", NS.CaptureArtPaint(tex, "net") == "own"
		and NS.CaptureArtPaint(tex, "rope") == "own" and NS.CaptureArtPaint(tex, "bundle") == "own")
	-- 2.14.0 : hors décor du Voile d'hiver (l'horloge des tests tombe le 1er janvier 1970)
	NS:DB().winterVeil = "off"
	local icon = UIParent:CreateTexture()
	local netFile, webFile = NS.CAPTURE_CLIENT_ART.icon.files[1], NS.CAPTURE_CLIENT_ART.icon.files[2]
	local first = NS.CaptureArtPaint(icon, "icon") == "client" and icon.texture == netFile and netFile:find("INV_Misc_Net_01", 1, true) ~= nil
	Mock.world.textureRefused = { [netFile] = true }
	local second = NS.CaptureArtPaint(icon, "icon") == "client" and icon.texture == webFile and webFile:find("^Interface\\Icons\\") ~= nil
	Mock.world.textureRefused = { [netFile] = true, [webFile] = true }
	Check("[AZ] glyphe du filet : INV_Misc_Net_01, puis une autre icône du jeu, sinon vide", first and second
		and NS.CaptureArtPaint(icon, "icon") == nil and icon.texture == nil)
	Mock.world.textureRefused = nil
	NS:DB().winterVeil = nil
	-- Ready2Quest : flèches du toast
	local arrow = UIParent:CreateTexture()
	Mock.InstallAtlas(nil)
	Check("[AZ] R2Q flèche : sans atlas, vide", RNS.StatsPaintArrow(arrow, true) == nil and not arrow.clientArrow
		and arrow.texture == nil)
	Mock.InstallAtlas(true)
	local up = RNS.StatsPaintArrow(arrow, true) == "client" and arrow.atlas == RNS.STATS_ARROW_ATLAS
	_G.C_Texture.GetAtlasInfo = function()
		return { file = 555, leftTexCoord = 0.1, rightTexCoord = 0.2, topTexCoord = 0.3, bottomTexCoord = 0.4 }
	end
	local down = UIParent:CreateTexture()
	RNS.StatsPaintArrow(down, false)
	local dc = down.texCoord or {}
	Check("[AZ] R2Q flèches : hausse bags-greenarrow, baisse la même retournée", up and down.texture == 555
		and dc[3] == 0.4 and dc[4] == 0.3, tostring(dc[3]) .. "/" .. tostring(dc[4]))
	Mock.InstallAtlas(nil)
end

-- Rangement
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
	NS:DB().companionStyle, NS:DB().companionSize, NS:DB().companionFraming = nil, nil, nil
	for _, name in ipairs(GLOBALS) do _G[name] = AZT.saved[name] end
	_G.CreateFrame = AZT.savedCreateFrame
	math.random = AZT.random
	NS.SHINY_CHANCE = AZT.savedShiny
	if AZT.rollQuality then NS.CaptureRollQuality = AZT.rollQuality end
	ResetWorld()
end
