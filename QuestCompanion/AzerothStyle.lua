-- AzerothStyle.lua -- style de l'interface « Azeroth » (QuestCompanion 2.5.0)
--
-- Deux styles pour les bandeaux et le cadre du compagnon (réglage « Style de
-- l'interface », page Compagnon de route, /qc style azeroth|sobre) :
--   * Azeroth (par défaut) : le bandeau doré des hauts faits du jeu (« Haut
--     fait obtenu »), l'icône dans son cadre doré à gauche, le titre en
--     petites capitales sur la bande de parchemin, le nom en grand au centre,
--     un bouclier à droite (gris : pas encore à toi ; or : gagné), et une
--     apparition façon haut fait (éclosion, lueur, reflet, éclat) ; le
--     compagnon dans un cadre rond à volutes, son nom sur une plaque dorée ;
--   * Sobre : le style d'avant (aplats du thème, liseré ambre).
-- Les textures sont celles du client, désignées par leur nom d'atlas
-- (UiTextureAtlas « ui-achievement-* »), jamais embarquées. Leur présence
-- dans les données ne prouve pas qu'elles sont dans le client : on demande
-- au client (C_Texture.GetAtlasInfo) ; s'il en manque une, le style Sobre
-- s'affiche à la place, sans bruit (l'infobulle du réglage le dit).
-- Le changement de style s'applique tout de suite : chaque bandeau a un
-- cadre par style, créé à la demande et gardé (ns:StyleCached), le cadre du
-- compagnon est rhabillé sur place.
-- Aussi ici : le bandeau de résultat « Capturé ! » (les deux styles), et les
-- bandeaux des sceaux de zone et des titres de dresseur (file du carnet).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.UI_STYLES = { "azeroth", "sobre" }
ns.UI_STYLE_DEFAULT = "azeroth"
-- atlas du client (UiTextureAtlas 1771, fichier 4035524)
ns.AZEROTH_ATLAS = {
	bg         = "ui-achievement-alert-background",
	bgGuild    = "ui-achievement-guild-background",
	plate      = "ui-achievement-alert-background-mini",
	glow       = "ui-achievement-alert-glow-glow",
	shine      = "ui-achievement-alert-glow-shine",
	bling      = "ui-achievement-bling",
	frame      = "ui-achievement-iconframe",
	frameRound = "ui-achievement-guild-iconframe",
	shield     = "ui-achievement-shield-1",
	shieldGrey = "ui-achievement-shield-desaturated",
}
-- celles sans lesquelles le style ne tient pas (le reste est décoratif)
ns.AZEROTH_REQUIRED = { "bg", "bgGuild", "plate", "frame", "frameRound", "shield" }
-- police des hauts faits (Friz Quadrata, celle du client)
ns.AZEROTH_FONT = "Fonts\\FRIZQT__.TTF"
-- géométrie du bandeau (maquette validée : 310×101 à l'échelle 1,25) et de
-- la bande sombre du bandeau « Capture possible »
ns.AZEROTH_LAYOUT = {
	w = 388, h = 126, overlap = 10, stripW = 330, strip = 76,
	infoY = -16, hintY = -32, rowH = 18, rowBottom = 7,
	titleY = -28, titleW = 252, nameY = -50, nameW = 260, nameWide = 290, starsY = -82,
	nameMax = 20, nameMin = 11, titleMax = 12, titleMin = 9,
}
ns.CAPTURE_RESULT_SECONDS = 3.5   -- s d'affichage du bandeau « Capturé ! »
ns.CAPTURE_RESULT_STALE = 30      -- s d'attente au plus (combat) avant de l'oublier
local AZ = ns.AZEROTH_ATLAS
local LAY = ns.AZEROTH_LAYOUT
local INK = { 0.23, 0.14, 0.06 }          -- brun foncé du parchemin (#3a2410)
local SHINY_NAME = { 1, 0.886, 0.478 }    -- nom d'une brillante (#ffe27a)
local STAR_GOLD = { 1, 0.84, 0.29 }

local FR = {
	OPT_UI_STYLE           = "Style de l'interface",
	OPT_UI_STYLE_DESC      = "Bandeaux et cadre du compagnon. Azeroth : dorés, façon hauts faits. Sobre : le style d'avant.",
	OPT_UI_STYLE_MISSING   = "Les textures des hauts faits manquent sur ce client : le style Sobre s'affiche à la place.",
	UI_STYLE_azeroth       = "Azeroth (doré)",
	UI_STYLE_sobre         = "Sobre",
	UI_STYLE_MSG           = "Style de l'interface : %s.",
	UI_STYLE_MSG_MISSING   = "Style de l'interface : %s. Ses textures manquent sur ce client : le style Sobre reste affiché.",
	UI_STYLE_USAGE         = "/qc style azeroth|sobre (actuel : %s)",
	HELP_STYLE             = "/qc style azeroth|sobre — style des bandeaux et du cadre du compagnon",
	CAPTURE_RESULT         = "Capturé !",
	CAPTURE_RESULT_SHINY   = "Brillant capturé !",
	CAPTURE_RESULT_MORE    = "et %d de plus",
	JRN_KIND_seal          = "Sceau de zone",
	JRN_KIND_rank          = "Titre de dresseur",
}
local EN = {
	OPT_UI_STYLE           = "Interface style",
	OPT_UI_STYLE_DESC      = "Banners and companion frame. Azeroth: golden, achievement-style. Plain: the previous look.",
	OPT_UI_STYLE_MISSING   = "This client lacks the achievement textures: the Plain style is shown instead.",
	UI_STYLE_azeroth       = "Azeroth (golden)",
	UI_STYLE_sobre         = "Plain",
	UI_STYLE_MSG           = "Interface style: %s.",
	UI_STYLE_MSG_MISSING   = "Interface style: %s. Its textures are missing on this client: the Plain style stays on screen.",
	UI_STYLE_USAGE         = "/qc style azeroth|sobre (current: %s)",
	HELP_STYLE             = "/qc style azeroth|sobre — style of the banners and the companion frame",
	CAPTURE_RESULT         = "Captured!",
	CAPTURE_RESULT_SHINY   = "Shiny captured!",
	CAPTURE_RESULT_MORE    = "and %d more",
	JRN_KIND_seal          = "Zone seal",
	JRN_KIND_rank          = "Trainer title",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.AZEROTH_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({ companionStyle = ns.UI_STYLE_DEFAULT })

local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end
local function Method(obj, name, ...)
	local fn = obj and obj[name]
	if type(fn) ~= "function" then return false end
	return pcall(fn, obj, ...)
end
local function InCombat()
	if Call(G("InCombatLockdown")) then return true end
	return Call(G("UnitAffectingCombat"), "player") and true or false
end
local function Upper(text) return Theme.Upper and Theme.Upper(text) or text end
local function Clamp01(x) if x < 0 then return 0 elseif x > 1 then return 1 end return x end

-- ---------------------------------------------------------------------------
-- Le style : choix, textures du client, style effectif
-- ---------------------------------------------------------------------------
-- Les atlas sont-ils dans ce client ? Gardé tant que l'API ne change pas
-- (refresh : redemander)
local atlasCache = {}
function ns:AzerothAtlasOK(refresh)
	local api = G("C_Texture")
	if not refresh and atlasCache.checked and atlasCache.api == api then return atlasCache.ok end
	local ok = type(api) == "table" and type(api.GetAtlasInfo) == "function"
	if ok then
		for _, key in ipairs(ns.AZEROTH_REQUIRED) do
			local done, info = pcall(api.GetAtlasInfo, AZ[key])
			info = done and ns.Plain and ns.Plain(info) or (done and info or nil)
			if info == nil or info == false then ok = false; break end
		end
	end
	atlasCache.checked, atlasCache.api, atlasCache.ok = true, api, ok and true or false
	return atlasCache.ok
end

-- Le choix du joueur (réglage), valide
function ns:UIStyleChoice()
	local choice = self:DB().companionStyle
	for _, id in ipairs(ns.UI_STYLES) do if id == choice then return id end end
	return ns.UI_STYLE_DEFAULT
end

-- Le style affiché : Azeroth seulement si le client a ses textures
function ns:UIStyle()
	if self:UIStyleChoice() == "azeroth" and self:AzerothAtlasOK() then return "azeroth" end
	return "sobre"
end
function ns:AzerothOn() return self:UIStyle() == "azeroth" end

function ns:UIStyleChoices()
	local list = {}
	for _, id in ipairs(ns.UI_STYLES) do list[#list + 1] = { value = id, label = L["UI_STYLE_" .. id] } end
	return list
end

-- Les bandeaux mis de côté au changement de style : cache[clé][style]
ns.uiStyleCache = ns.uiStyleCache or {}
local STYLED_FRAMES = { "captureToast", "guildFeatToast", "journalToast", "captureResult" }

-- Un cadre déjà construit pour le style courant (et retiré du cache), ou nil
function ns:StyleCached(key)
	local slot = self.uiStyleCache[key]
	if not slot then return nil end
	local style = self:UIStyle()
	local frame = slot[style]
	slot[style] = nil
	return frame
end

-- Copie les textes d'un bandeau à l'autre (rhabillage d'un bandeau affiché)
local function CopyTexts(from, to)
	for _, field in ipairs({ "title", "text", "info", "hint", "stars" }) do
		local a, b = from[field], to[field]
		if a and b and a ~= b and a.GetText and b.SetText then b:SetText(a:GetText() or "") end
	end
end

-- Applique le style tout de suite : les bandeaux du mauvais style sont mis de
-- côté (et remplacés s'ils étaient affichés), le compagnon est rhabillé
function ns:ApplyUIStyle()
	local style = self:UIStyle()
	for _, key in ipairs(STYLED_FRAMES) do
		local frame = self[key]
		if frame and (frame.uiStyle or "sobre") ~= style then
			local shown = frame:IsShown()
			frame:Hide()
			self.uiStyleCache[key] = self.uiStyleCache[key] or {}
			self.uiStyleCache[key][frame.uiStyle or "sobre"] = frame
			self[key] = nil
			if shown then
				if key == "captureToast" then
					local hideAt = self.captureToastHideAt
					if self.CaptureToastShow then self:CaptureToastShow() end
					self.captureToastHideAt = hideAt or self.captureToastHideAt
				else
					local ensure = (key == "guildFeatToast" and self.EnsureGuildFeatToast)
						or (key == "journalToast" and self.EnsureJournalToast) or nil
					local fresh = ensure and ensure(self)
					if fresh then
						CopyTexts(frame, fresh)
						fresh:Show()
						self:StyleShown(fresh, { shield = key == "journalToast" and "gold" or nil })
					end
				end
			end
		end
	end
	if self.CompanionApplyUIStyle then self:CompanionApplyUIStyle() end
	return style
end

-- Choix du style (réglage, commande) ; nil si inconnu
function ns:SetUIStyle(id)
	id = type(id) == "string" and id:lower() or nil
	if id == "plain" then id = "sobre" end
	local valid = false
	for _, known in ipairs(ns.UI_STYLES) do if known == id then valid = true end end
	if not valid then return nil end
	self:DB().companionStyle = id
	self:ApplyUIStyle()
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return id
end

-- ---------------------------------------------------------------------------
-- Le bandeau Azeroth
-- ---------------------------------------------------------------------------
local function Atlas(tex, name)
	if not (tex and name) then return false end
	local ok, result = pcall(tex.SetAtlas, tex, name)
	return ok and result ~= false
end

-- Police des hauts faits ; refusée : la police du thème reste
local function AzFont(fs, size, flags)
	local ok, result = pcall(fs.SetFont, fs, ns.AZEROTH_FONT, size, flags or "")
	return ok and result ~= false
end

-- Largeur réelle du texte, sans la borne de la largeur posée
local function Measure(fs)
	local ok, w
	if fs.GetUnboundedStringWidth then ok, w = pcall(fs.GetUnboundedStringWidth, fs) end
	if not (ok and tonumber(w)) and fs.GetStringWidth then ok, w = pcall(fs.GetStringWidth, fs) end
	return (ok and tonumber(w)) or 0
end

-- Rapetisse la police jusqu'à ce que le texte tienne dans `width` ; au plus
-- petit, trop long quand même : la largeur fixe le coupe (points de
-- suspension du client). Rend la taille retenue et si le texte tient.
function ns.AzerothFit(fs, width, maxSize, minSize)
	if not fs then return nil end
	local size = maxSize
	while true do
		AzFont(fs, size)
		if Measure(fs) <= width or size <= minSize then break end
		size = size - 1
	end
	fs:SetWidth(width)
	if fs.SetWordWrap then fs:SetWordWrap(false) end
	fs.fitSize = size
	return size, Measure(fs) <= width
end

-- L'apparition : éclosion (0,6 → 1,05 → 1), lueur, reflet qui traverse le
-- bandeau, éclat sur le bouclier. Une horloge OnUpdate le temps de
-- l'animation (2,4 s), retirée ensuite ; rien d'alloué à chaque image.
local ANIM_TIME = 2.4
local function AnimStep(banner)
	local frame = banner.owner
	local t = Clock() - (frame.animAt or 0)
	local scale, alpha = 1, 1
	if t < 0.6 then
		local p = t / 0.6
		scale = p < 0.7 and (0.6 + 0.45 * p / 0.7) or (1.05 - 0.05 * (p - 0.7) / 0.3)
		alpha = Clamp01(t / 0.3)
	end
	banner:SetScale(scale)
	banner:SetAlpha(alpha)
	local g = t - 0.2
	local glow = g < 0 and 0 or (g < 0.36 and 0.8 * g / 0.36 or 0.8 * Clamp01(1 - (g - 0.36) / 1.08))
	frame.glow:SetAlpha(glow)
	if frame.animShine then
		local s = (t - 0.5) / 1.3
		if s >= 0 and s <= 1 then
			frame.shine:ClearAllPoints()
			frame.shine:SetPoint("CENTER", banner, "CENTER", -170 + 340 * s, 0)
			frame.shine:SetAlpha(s < 0.35 and 0.9 * s / 0.35 or 0.9 * Clamp01(1 - (s - 0.35) / 0.65))
			frame.shine:Show()
		else
			frame.shine:Hide()
		end
	end
	if frame.animBling then
		local b = (t - 0.8) / 1.4
		if b >= 0 and b <= 1 then
			local size = 44 + 88 * Clamp01(b / 0.6)
			frame.bling:SetSize(size, size)
			frame.bling:SetAlpha(b < 0.25 and b / 0.25 or Clamp01(1 - (b - 0.25) / 0.35))
			if frame.bling.SetRotation then pcall(frame.bling.SetRotation, frame.bling, 0.7 * b) end
			frame.bling:Show()
		else
			frame.bling:Hide()
		end
	end
	if t >= ANIM_TIME then
		banner:SetScale(1); banner:SetAlpha(1)
		frame.glow:SetAlpha(0); frame.shine:Hide(); frame.bling:Hide()
		banner:SetScript("OnUpdate", nil)
		frame.animating = nil
	end
end

local function Play(frame, opts)
	opts = opts or {}
	frame.animAt = Clock()
	frame.animShine, frame.animBling = opts.shine and true or nil, opts.bling and frame.shield:IsShown() or nil
	frame.animating = true
	frame.shine:Hide(); frame.bling:Hide()
	frame.banner:SetScript("OnUpdate", function(banner)
		if not frame:IsShown() then return end
		local ok, err = pcall(AnimStep, banner)
		if not ok then
			banner:SetScript("OnUpdate", nil)
			banner:SetScale(1); banner:SetAlpha(1)
			if ns.RecordError then ns:RecordError("azeroth:anim", err) end
		end
	end)
	AnimStep(frame.banner)
	return true
end

-- Crée un bandeau Azeroth. opts : name, strata, guild (fond de guilde),
-- round (cadre rond à volutes), strip (bande sombre dessous : infos et
-- boutons). Champs : .banner (les textures dorées), .icon, .title, .text
-- (le nom), .stars, .shield, .glow, .shine, .bling ; avec strip : .strip
-- (la bande, sert d'ancre), .info, .hint. Méthodes : SetAccent (gardée pour
-- les appelants du style Sobre), SetShield("grey" | "gold" | nil), Fit(), Play(opts).
function ns:AzerothCreateBanner(opts)
	opts = opts or {}
	local stripH = opts.strip and LAY.strip or 0
	local ok, frame = pcall(CreateFrame, "Frame", opts.name, UIParent)
	if not ok or not frame then return nil end
	frame:SetSize(LAY.w, LAY.h + (opts.strip and (stripH - LAY.overlap) or 0))
	frame:SetFrameStrata(opts.strata or "MEDIUM")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(false)
	frame:SetMovable(true)
	if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
	if frame.StartMoving then frame:SetScript("OnDragStart", frame.StartMoving) end
	if frame.StopMovingOrSizing then frame:SetScript("OnDragStop", frame.StopMovingOrSizing) end
	frame.uiStyle, frame.azeroth, frame.chrome = "azeroth", true, "azeroth"
	frame.contentLeft, frame.contentTop = 0, 0

	-- la zone du bandeau (fixe) et le bandeau lui-même (il éclot depuis son centre)
	local area = CreateFrame("Frame", nil, frame)
	area:SetSize(LAY.w, LAY.h)
	area:SetPoint("TOP", frame, "TOP", 0, 0)
	frame.bannerArea = area
	local banner = CreateFrame("Frame", nil, area)
	banner:SetSize(LAY.w, LAY.h)
	banner:SetPoint("CENTER", area, "CENTER", 0, 0)
	banner.owner = frame
	frame.banner = banner

	frame.bg = banner:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints(banner)
	Atlas(frame.bg, opts.guild and AZ.bgGuild or AZ.bg)
	frame.glow = banner:CreateTexture(nil, "BACKGROUND", nil, -1)
	frame.glow:SetSize(520, 200)
	frame.glow:SetPoint("CENTER", banner, "CENTER", 0, 0)
	Atlas(frame.glow, AZ.glow)
	if frame.glow.SetBlendMode then frame.glow:SetBlendMode("ADD") end
	frame.glow:SetAlpha(0)

	-- l'icône dans son cadre, à cheval sur le bout gauche
	frame.iconFrame = banner:CreateTexture(nil, "ARTWORK", nil, 2)
	if opts.round then
		frame.iconFrame:SetSize(92, 88)
		frame.iconFrame:SetPoint("TOPLEFT", banner, "TOPLEFT", -34, -18)
	else
		frame.iconFrame:SetSize(86, 86)
		frame.iconFrame:SetPoint("TOPLEFT", banner, "TOPLEFT", -30, -20)
	end
	Atlas(frame.iconFrame, opts.round and AZ.frameRound or AZ.frame)
	frame.icon = banner:CreateTexture(nil, "ARTWORK", nil, 1)
	frame.icon:SetSize(opts.round and 48 or 52, opts.round and 48 or 52)
	frame.icon:SetPoint("CENTER", frame.iconFrame, "CENTER", 0, 0)

	-- titre (petites capitales, brun sur le parchemin), nom (blanc, ombré), étoiles
	frame.title = banner:CreateFontString(nil, "OVERLAY", Theme.F_CAPS)
	frame.title:SetPoint("TOP", banner, "TOP", 2, LAY.titleY)
	frame.title:SetJustifyH("CENTER")
	AzFont(frame.title, LAY.titleMax)
	frame.title:SetTextColor(INK[1], INK[2], INK[3], 1)
	if Theme.NoShadow then Theme.NoShadow(frame.title) end
	frame.title:SetWidth(LAY.titleW)
	if frame.title.SetWordWrap then frame.title:SetWordWrap(false) end
	frame.nameWidth = opts.guild and LAY.nameWide or LAY.nameW
	frame.text = banner:CreateFontString(nil, "OVERLAY", Theme.F_TITLE)
	frame.text:SetPoint("TOP", banner, "TOP", opts.guild and 10 or 2, LAY.nameY)
	frame.text:SetJustifyH("CENTER")
	AzFont(frame.text, LAY.nameMax)
	frame.text:SetTextColor(1, 1, 1, 1)
	if frame.text.SetShadowColor then frame.text:SetShadowColor(0, 0, 0, 1) end
	if frame.text.SetShadowOffset then frame.text:SetShadowOffset(1, -2) end
	frame.text:SetWidth(frame.nameWidth)
	if frame.text.SetWordWrap then frame.text:SetWordWrap(false) end
	frame.stars = banner:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.stars:SetPoint("TOP", banner, "TOP", opts.guild and 10 or 0, LAY.starsY)
	frame.stars:SetJustifyH("CENTER")
	frame.stars:SetWidth(frame.nameWidth)
	if frame.stars.SetWordWrap then frame.stars:SetWordWrap(false) end
	frame.stars:SetTextColor(STAR_GOLD[1], STAR_GOLD[2], STAR_GOLD[3], 1)

	-- bouclier à droite, et l'éclat qui le traverse ; le reflet du bandeau
	frame.shield = banner:CreateTexture(nil, "ARTWORK", nil, 2)
	frame.shield:SetSize(70, 62)
	frame.shield:SetPoint("TOPRIGHT", banner, "TOPRIGHT", 12, -30)
	frame.shield:Hide()
	frame.bling = banner:CreateTexture(nil, "OVERLAY", nil, 2)
	frame.bling:SetSize(110, 110)
	frame.bling:SetPoint("CENTER", frame.shield, "CENTER", 0, 0)
	Atlas(frame.bling, AZ.bling)
	if frame.bling.SetBlendMode then frame.bling:SetBlendMode("ADD") end
	frame.bling:Hide()
	frame.shine = banner:CreateTexture(nil, "OVERLAY", nil, 1)
	frame.shine:SetSize(70, 96)
	frame.shine:SetPoint("CENTER", banner, "CENTER", 0, 0)
	Atlas(frame.shine, AZ.shine)
	if frame.shine.SetBlendMode then frame.shine:SetBlendMode("ADD") end
	frame.shine:Hide()

	-- la bande sombre (liseré doré), glissée sous le bas du bandeau
	if opts.strip then
		frame.strip = Theme.Solid(frame, "BACKGROUND", Theme.WINDOW or { 0.06, 0.05, 0.04 }, 0.94)
		frame.strip:SetSize(LAY.stripW, stripH)
		frame.strip:SetPoint("TOP", area, "BOTTOM", 0, LAY.overlap)
		frame.stripEdge = Theme.Border(frame, Theme.GOLD_SOFT, 0.9, "BORDER", frame.strip)
		local textW = LAY.stripW - 24
		frame.info = Theme.Text(frame, Theme.F_SMALL, Theme.GOLD)
		frame.info:SetPoint("TOPLEFT", frame.strip, "TOPLEFT", 12, LAY.infoY)
		frame.info:SetWidth(textW)
		frame.info:SetJustifyH("LEFT")
		if frame.info.SetWordWrap then frame.info:SetWordWrap(false) end
		frame.hint = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED)
		frame.hint:SetPoint("TOPLEFT", frame.strip, "TOPLEFT", 12, LAY.hintY)
		frame.hint:SetWidth(textW)
		frame.hint:SetJustifyH("LEFT")
		if frame.hint.SetWordWrap then frame.hint:SetWordWrap(false) end
	end

	function frame:SetAccent(color) self.accentColor = color end
	function frame:SetShield(kind)
		if kind == "gold" or kind == "grey" then
			local done = Atlas(self.shield, kind == "gold" and AZ.shield or AZ.shieldGrey)
			-- pas de bouclier gris dans ce client : le doré, désaturé
			if not done and kind == "grey" then
				Atlas(self.shield, AZ.shield)
				if self.shield.SetDesaturated then pcall(self.shield.SetDesaturated, self.shield, true) end
			elseif self.shield.SetDesaturated then
				pcall(self.shield.SetDesaturated, self.shield, false)
			end
			self.shieldKind = kind
			self.shield:Show()
		else
			self.shieldKind = nil
			self.shield:Hide()
		end
	end
	function frame:Fit()
		ns.AzerothFit(self.title, LAY.titleW, LAY.titleMax, LAY.titleMin)
		return ns.AzerothFit(self.text, self.nameWidth, LAY.nameMax, LAY.nameMin)
	end
	function frame:Play(o) return Play(self, o) end
	frame:Hide()
	return frame
end

-- Après avoir rempli un bandeau : en Azeroth, couleur du nom (or pour une
-- brillante), nom ajusté, bouclier, apparition. En Sobre : rien.
-- opts : shiny, shield ("grey" | "gold"), play, bling, shine
function ns:StyleShown(frame, opts)
	if not (frame and frame.azeroth) then return false end
	opts = opts or {}
	local c = opts.shiny and SHINY_NAME or { 1, 1, 1 }
	frame.text:SetTextColor(c[1], c[2], c[3], 1)
	frame:SetShield(opts.shield)
	frame:Fit()
	if opts.play then
		frame:Play({ bling = opts.bling or opts.shield == "gold", shine = opts.shine or opts.shiny })
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Le bandeau de résultat : « Capturé ! » / « Brillant capturé ! »
-- Montré quand la scène de capture se referme (lancer seul) ou quand la
-- volée de « Tout capturer » est fermée (la plus belle prise du lot) ; jamais
-- en combat (il attend la fin, CAPTURE_RESULT_STALE s au plus), rien en
-- sourdine ; CAPTURE_RESULT_SECONDS s d'affichage.
-- ---------------------------------------------------------------------------
function ns:EnsureCaptureResult()
	if self.captureResult then return self.captureResult end
	local cached = self:StyleCached("captureResult")
	if cached then self.captureResult = cached; return cached end
	local art = ns.CAPTURE_ART
	local glyph = art and art.icon or Theme.LOGO_SMALL
	local frame
	if self:AzerothOn() then
		frame = self:AzerothCreateBanner({ strata = "HIGH", name = "QuestCompanionCaptureResultAzeroth" })
		if not frame then return nil end
		frame.icon:SetTexture(glyph)
		if art and art.icon then frame.icon:SetVertexColor(Theme.GOLD_LIGHT[1], Theme.GOLD_LIGHT[2], Theme.GOLD_LIGHT[3], 1) end
	else
		if not (Theme and Theme.CreateToast) then return nil end
		frame = Theme.CreateToast(UIParent, 300, 66, { strata = "HIGH", accent = Theme.GOLD, name = "QuestCompanionCaptureResult" })
		if not frame then return nil end
		frame.uiStyle = "sobre"
		local left = frame.contentLeft or 14
		frame.icon = frame:CreateTexture(nil, "ARTWORK")
		frame.icon:SetTexture(glyph)
		if art and art.icon then frame.icon:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1) end
		frame.icon:SetSize(34, 34)
		frame.icon:SetPoint("LEFT", frame, "LEFT", left, 0)
		local textLeft, textW = left + 44, 300 - left - 44 - 12
		local function Line(font, color, y)
			local fs = Theme.Text(frame, font, color)
			fs:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, y)
			fs:SetWidth(textW)
			fs:SetJustifyH("LEFT")
			if fs.SetWordWrap then fs:SetWordWrap(false) end
			return fs
		end
		frame.title = Line(Theme.F_CAPS, Theme.MUTED_LIGHT, -9)
		frame.text = Line(Theme.F_TITLE, Theme.PARCHMENT, -23)
		frame.stars = Line(Theme.F_SMALL, Theme.GOLD, -44)
	end
	if self.RestorePoint then self:RestorePoint(frame, "captureResultPoint", { point = "TOP", x = 0, y = -200 }) end
	frame:Hide()
	self.captureResult = frame
	return frame
end

-- Retient le résultat à montrer : { name, shiny, stars, more }
function ns:CaptureResultQueue(result)
	if type(result) ~= "table" or not result.name then return nil end
	result.at = Clock()
	self.captureResultPending = result
	return result
end

-- La scène (lancer seul ou volée) est-elle encore à l'écran ?
function ns:CaptureSceneBusy()
	local state = self.captureState
	if state and state.rolling then return true end
	local batch = self.captureBatchFrame
	if batch and batch:IsShown() then return true end
	local stage = self.captureStage
	return stage ~= nil and stage:IsShown() and stage.rolling ~= nil
end

function ns:CaptureResultShow(result)
	local frame = self:EnsureCaptureResult()
	if not frame then return nil end
	frame.title:SetText(Upper(result.shiny and L.CAPTURE_RESULT_SHINY or L.CAPTURE_RESULT))
	frame.text:SetText(result.name)
	local line = (result.stars and self.CaptureStarsText) and self:CaptureStarsText(result.stars, 14) or ""
	if (tonumber(result.more) or 0) > 0 then
		local more = self:F("CAPTURE_RESULT_MORE", result.more)
		line = line ~= "" and (line .. "  ·  " .. more) or more
	end
	frame.stars:SetText(line)
	if not frame.azeroth then
		local c = result.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or Theme.PARCHMENT
		frame.text:SetTextColor(c[1], c[2], c[3])
		if frame.SetAccent then frame:SetAccent(result.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or Theme.GOLD) end
	end
	frame.result = result
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame, 0.2) end
	self:StyleShown(frame, { shiny = result.shiny, shield = "gold", play = true, bling = true, shine = result.shiny })
	self.captureResultHideAt = Clock() + ns.CAPTURE_RESULT_SECONDS
	return frame
end

function ns:CaptureResultHide()
	self.captureResultHideAt = nil
	if self.captureResult then self.captureResult:Hide() end
end

-- Horloge (celle de la capture, 10 fois par seconde)
function ns:CaptureResultTick(now)
	now = now or Clock()
	if self.captureResultHideAt and (now >= self.captureResultHideAt or InCombat()) then self:CaptureResultHide() end
	local pending = self.captureResultPending
	if not pending then return false end
	if self.CaptureMuted and self:CaptureMuted() then self.captureResultPending = nil; return false end
	-- la scène est encore là : l'attente ne compte pas
	if self:CaptureSceneBusy() then pending.at = now; return false end
	if now - (pending.at or now) > ns.CAPTURE_RESULT_STALE then self.captureResultPending = nil; return false end
	if InCombat() then return false end
	self.captureResultPending = nil
	return self:CaptureResultShow(pending) ~= nil
end

-- Lancer seul : le verdict retenu, montré quand la scène se referme
do
	local base = ns.CaptureResolve
	if base then
		function ns:CaptureResolve(rolling, ...)
			local result = base(self, rolling, ...)
			local target = rolling and rolling.target
			if target and rolling.success and not rolling.batch and not self.captureBatchResolving then
				self:CaptureResultQueue({ name = target.name, shiny = target.shiny and true or false, stars = rolling.stars })
			end
			return result
		end
	end
end

-- Tout capturer : la plus belle prise du lot, montrée quand la volée est fermée
do
	local base = ns.CaptureBatchFlush
	if base then
		function ns:CaptureBatchFlush(batch, ...)
			if batch and not batch.flushed then
				local strength = ns.CaptureBatchStrength
				local best, got = nil, 0
				for _, result in ipairs(batch.results or {}) do
					if result.success then
						got = got + 1
						if not best or (strength and strength(result) > strength(best)) then best = result end
					end
				end
				if best then
					self:CaptureResultQueue({ name = best.target.name, shiny = best.target.shiny and true or false,
						stars = best.stars, more = got - 1 })
				end
			end
			return base(self, batch, ...)
		end
	end
end

do
	local base = ns.CaptureTick
	if base then
		function ns:CaptureTick(now, ...)
			local a, b = base(self, now, ...)
			local ok, err = pcall(self.CaptureResultTick, self, now)
			if not ok and self.RecordError then self:RecordError("capture:result", err) end
			return a, b
		end
	end
end

-- ---------------------------------------------------------------------------
-- Sceaux de zone et titres de dresseur : un bandeau aussi (file du carnet)
-- ---------------------------------------------------------------------------
do
	local label = ns.JournalKindLabel
	if label then
		function ns:JournalKindLabel(kind)
			if kind == "seal" or kind == "rank" then return L["JRN_KIND_" .. kind] end
			return label(self, kind)
		end
	end
	local seal = ns.MenagerieSealCheck
	if seal then
		function ns:MenagerieSealCheck(zoneID, opts, ...)
			local sealed = seal(self, zoneID, opts, ...)
			if sealed and not (type(opts) == "table" and opts.quiet) and self.JournalToastPush then
				local info = self.MapInfo and self:MapInfo(tonumber(zoneID) or zoneID)
				self:JournalToastPush({ kind = "seal", name = (info and info.name) or tostring(zoneID) })
			end
			return sealed
		end
	end
	local rank = ns.MenagerieRankCheck
	if rank then
		function ns:MenagerieRankCheck(opts, ...)
			local gained = rank(self, opts, ...)
			if type(gained) == "table" and #gained > 0 and not (type(opts) == "table" and opts.quiet) and self.JournalToastPush then
				local best = gained[#gained]
				self:JournalToastPush({ kind = "rank", name = L["TRAINER_" .. tostring(best.key)] or tostring(best.count) })
			end
			return gained
		end
	end
end

-- ---------------------------------------------------------------------------
-- Le cadre du compagnon : cadre rond à volutes autour du portrait, plaque
-- dorée sous le nom. Même taille de cadre (taille, cadrage, filet, survol
-- inchangés) ; le fond gagné est arrondi par un masque si le client en a.
-- ---------------------------------------------------------------------------
local RING_W, RING_H, RING_Y = 108, 104, -45   -- centre du portrait (modèle de 82 px sous 4 px)
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
ns.AZEROTH_RING = { w = RING_W, h = RING_H, y = RING_Y }

local function BuildCompanionSkin(frame)
	local skin = CreateFrame("Frame", nil, frame)
	skin:SetAllPoints(frame)
	skin:SetFrameLevel((frame:GetFrameLevel() or 1) + 4)
	skin.ring = skin:CreateTexture(nil, "ARTWORK")
	skin.ring:SetSize(RING_W, RING_H)
	skin.ring:SetPoint("CENTER", frame, "TOP", 0, RING_Y)
	Atlas(skin.ring, AZ.frameRound)
	local w = (frame:GetWidth() or 104) + 8
	skin.plate = skin:CreateTexture(nil, "BACKGROUND")
	skin.plate:SetSize(w, 34)
	skin.plate:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
	Atlas(skin.plate, AZ.plate)
	-- le fond gagné, en disque sous l'anneau (masque du client, s'il existe)
	if frame.CreateMaskTexture then
		local ok, mask = pcall(frame.CreateMaskTexture, frame)
		if ok and mask then
			pcall(mask.SetTexture, mask, MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetSize(RING_W - 30, RING_W - 30)
			mask:SetPoint("CENTER", frame, "TOP", 0, RING_Y)
			skin.mask = mask
		end
	end
	skin:Hide()
	return skin
end

local function Masked(frame, on)
	local mask = frame.azSkin and frame.azSkin.mask
	if not mask then return false end
	local regions = { frame.bg }
	for _, star in ipairs(frame.stars or {}) do regions[#regions + 1] = star end
	for _, region in ipairs(regions) do
		if region then
			if on and not region.azMasked then
				if Method(region, "AddMaskTexture", mask) then region.azMasked = true end
			elseif not on and region.azMasked then
				Method(region, "RemoveMaskTexture", mask)
				region.azMasked = nil
			end
		end
	end
	return on
end

local function EdgesShown(frame, shown)
	for _, edge in ipairs({ frame.top, frame.bottom, frame.leftEdge, frame.rightEdge }) do
		if edge then if shown then edge:Show() else edge:Hide() end end
	end
	if not shown then
		if frame.styleBorder then frame.styleBorder:Hide() end
		if frame.styleInnerHolder then frame.styleInnerHolder:Hide() end
	end
end

function ns:CompanionApplyUIStyle()
	local frame = self.companionFrame
	if not frame then return nil end
	local az = self:AzerothOn()
	if az and not frame.azSkin then frame.azSkin = BuildCompanionSkin(frame) end
	local skin = frame.azSkin
	if az then
		skin:Show()
		EdgesShown(frame, false)
		Masked(frame, true)
		-- nom et humeur sur la plaque (au-dessus du modèle et de l'anneau)
		for _, fs in ipairs({ frame.name, frame.mood }) do
			if fs and fs.SetParent then fs:SetParent(skin) end
		end
		if frame.name then
			frame.name:SetTextColor(1, 1, 1, 1)
			if frame.name.SetShadowColor then frame.name:SetShadowColor(0, 0, 0, 1) end
			if frame.name.SetShadowOffset then frame.name:SetShadowOffset(1, -1) end
		end
		if frame.mood then
			frame.mood:SetTextColor(INK[1], INK[2], INK[3], 1)
			if Theme.NoShadow then Theme.NoShadow(frame.mood) end
		end
	elseif frame.uiStyle == "azeroth" then
		if skin then skin:Hide() end
		Masked(frame, false)
		for _, fs in ipairs({ frame.name, frame.mood }) do
			if fs and fs.SetParent then fs:SetParent(frame) end
		end
		if frame.name then frame.name:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3], 1) end
		if frame.mood then frame.mood:SetTextColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3], 1) end
		if frame.mood and frame.mood.SetShadowColor then frame.mood:SetShadowColor(0, 0, 0, 0.6); frame.mood:SetShadowOffset(1, -1) end
		EdgesShown(frame, true)
	end
	frame.uiStyle = az and "azeroth" or "sobre"
	-- le cadre gagné (bordure du client) revient en Sobre
	if not az and self.CompanionApplyFrame then self:CompanionApplyFrame() end
	return frame.uiStyle
end

do
	local ensure = ns.EnsureCompanionFrame
	if ensure then
		function ns:EnsureCompanionFrame(...)
			local fresh = not self.companionFrame
			local frame = ensure(self, ...)
			if frame and fresh then self:CompanionApplyUIStyle() end
			return frame
		end
	end
	-- le cadre gagné ne réapparaît pas par-dessus l'anneau
	local apply = ns.CompanionApplyFrame
	if apply then
		function ns:CompanionApplyFrame(...)
			local a, b = apply(self, ...)
			local frame = self.companionFrame
			if frame and frame.uiStyle == "azeroth" then EdgesShown(frame, false) end
			return a, b
		end
	end
end

-- ---------------------------------------------------------------------------
-- Réglage (page Compagnon de route, après le cadrage) et commande
-- ---------------------------------------------------------------------------
do
	for _, page in ipairs(ns.OPTION_PAGES or {}) do
		if page.id == "companionMain" and type(page.rows) == "table" then
			local present, at = false, #page.rows + 1
			for index, row in ipairs(page.rows) do
				if row.key == "companionStyle" then present = true end
				if row.key == "companionFraming" then at = index + 1 end
			end
			if not present then
				table.insert(page.rows, at, { key = "companionStyle", label = "OPT_UI_STYLE", kind = "action",
					choices = function() return ns:UIStyleChoices() end,
					current = function() return ns:UIStyleChoice() end,
					describe = function() return L.OPT_UI_STYLE_DESC end,
					tooltip = function() if not ns:AzerothAtlasOK() then return L.OPT_UI_STYLE_MISSING end end,
					choose = function(id) ns:SetUIStyle(id) end })
			end
		end
	end
end

function ns:UIStyleCommand(rest)
	local word = tostring(rest or ""):match("^%s*(%S*)")
	word = (word or ""):lower()
	if word == "" then
		self:Print(self:F("UI_STYLE_USAGE", L["UI_STYLE_" .. self:UIStyleChoice()]))
		return nil
	end
	local id = self:SetUIStyle(word)
	if not id then
		self:Print(self:F("UI_STYLE_USAGE", L["UI_STYLE_" .. self:UIStyleChoice()]))
		return nil
	end
	local missing = id == "azeroth" and not self:AzerothAtlasOK()
	self:Print(self:F(missing and "UI_STYLE_MSG_MISSING" or "UI_STYLE_MSG", L["UI_STYLE_" .. id]))
	return id
end

if ns.EXTRA_COMMANDS then
	ns.EXTRA_COMMANDS["style"] = function(self, rest) self:UIStyleCommand(rest) end
end
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_QUICK" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_STYLE")
		end
	end
end

if ns.Mark then ns.Mark("AzerothStyle") end
