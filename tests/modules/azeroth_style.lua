-- Compagnon : le style de l'interface « Azeroth » (QuestCompanion 2.5 → 2.11).
-- Défaut Azeroth, repli Sobre quand le client n'a pas les atlas, réglage et
-- /qc style appliqués à chaud ; contraste mesuré (table ns.AZEROTH_CONTRAST
-- recalculée ici, seuils WCAG par rôle sur le pire fond réel) ; bandeaux
-- « Capture possible » (rien ne se chevauche, le nom tient), guilde, tampons,
-- résultat « Capturé ! » (combat, sourdine, lot), verdict (portrait, niveau
-- dans l'écu) ; cadre du compagnon (anneau, plaque, rabat de l'humeur, modèle
-- dans l'ouverture), bande Sobre lisible ; bulle sur le parchemin ; textures
-- du client par référence (QC et R2Q), jamais nos images en repli.
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

-- 1. Textes du style ---------------------------------------------------------------------------
do
	Say("-- azeroth : textes")
	AZT.Reset()
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

-- 4. Le réglage s'applique tout de suite ----------------------------------------------------------------
do
	Say("-- azeroth : changement de style en direct")
	AZT.Reset()
	AZT.SeeKill(7400, { name = "Sanglier" })
	local az = NS.captureToast
	NS:SetUIStyle("sobre")
	local sobre = NS.captureToast
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
	NS.Print = oldPrint
end

-- 10. Sobre : la bande sous le nom et l'humeur, noms élite/rare lisibles (2.11.0, fiche 09) ---------------
do
	Say("-- sobre : humeur lisible, rangs")
	AZT.Reset()
	NS:DB().companionStyle = "sobre"
	local frame = NS:EnsureCompanionFrame()
	NS:CompanionRefreshLabels()
	local a = NS.CompanionPlateAlpha()
	local c = frame.mood.textColor
	local white, parchment = { 1, 1, 1 }, { 0.85, 0.78, 0.62 }
	local r1, r2 = Ratio(Theme.TEXT, Over(Theme.INK, white, a)), Ratio(Theme.TEXT, Over(Theme.INK, parchment, a))
	local name = Ratio(Theme.PARCHMENT, Over(Theme.INK, white, a))
	Check("[AZ] Sobre : humeur (sol blanc, parchemin clair) et nom ≥ 4,5:1 sur la bande", r1 >= 4.5 and r2 >= 4.5 and name >= 4.5,
		string.format("%.2f / %.2f / %.2f", r1, r2, name))
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

-- 3.1.0 : la réplique d'essai de /qc debug bulle ne promet plus un parchemin
-- (thème forgé : la bulle n'en a plus)
do
	local all = NS.AZEROTH_DEBUG_STRINGS or {}
	local fr, en = all.fr and all.fr.AZ_DEBUG_SAMPLE or "", all.en and all.en.AZ_DEBUG_SAMPLE or ""
	Check("[AZ] /qc debug bulle : réplique d'essai sans « parchemin »", fr ~= "" and en ~= ""
		and not fr:lower():find("parchemin", 1, true) and not en:lower():find("parchment", 1, true), fr .. " / " .. en)
end
