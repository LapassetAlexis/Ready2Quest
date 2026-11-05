-- Theme.lua -- identité visuelle « carnet de route », v2 (refonte 2026-11)
--
-- Référence : docs/UI.md (polices, jetons, fenêtre type, contrôles).
-- Règles, appliquées partout :
--   * surfaces plates ardoise, filets fins ; une seule couleur d'accent,
--     l'ambre, réservée à ce qui compte (page active, valeur, action
--     principale, marque) ; vert/ambre/rouge = statut ; bleu = information ;
--   * une seule famille de police embarquée, Inter (OFL, Libs/Socle/Media),
--     en objets de police créés une fois par addon (CreateFont), avec repli
--     sur les polices du jeu si le client refuse le fichier ;
--   * des contrôles dessinés par l'addon (boutons, interrupteurs, curseurs,
--     listes, onglets), sans dépendre d'aucun template : rien ne casse si
--     Forever change son art ;
--   * chaque brique tolère un client sans SetFont réussi, sans SetGradient,
--     etc. : repli silencieux sur un aplat.
-- Textures : celles du socle (Libs/Socle/Media : losange.tga,
-- losange_trait.tga, interrupteur.tga, chevron.tga, police Inter ;
-- tools/gen_socle_media.py) et le logo de chaque addon (Textures/logo.tga,
-- logo_petit.tga). Tout le reste n'utilise que Interface\Buttons\WHITE8X8, teinté.
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
local ADDON, ns = ...

local Theme = {}
ns.Theme = Theme

local MEDIA = "Interface\\AddOns\\" .. tostring(ADDON or "Ready2Quest") .. "\\"
Theme.MEDIA = MEDIA
local SOCLE_MEDIA = MEDIA .. "Libs\\Socle\\Media\\"
Theme.SOCLE_MEDIA = SOCLE_MEDIA

-- Palette ---------------------------------------------------------------------
-- GOLD reste le nom historique de la couleur d'accent : c'est l'ambre.
Theme.GOLD      = { 0.91, 0.65, 0.29 }   -- ambre #e8a54b
Theme.GOLD_LIGHT = { 0.96, 0.78, 0.49 }  -- ambre clair #f6c77d (cœur du filet lumineux)
Theme.GOLD_SOFT = { 0.73, 0.47, 0.17 }   -- ambre sombre #b9782c (sections)
Theme.GOLD_DIM  = { 0.17, 0.19, 0.22 }   -- filets #2a3138
Theme.PARCHMENT = { 0.95, 0.91, 0.83 }   -- titres #f1e8d4
Theme.TEXT      = { 0.85, 0.83, 0.78 }   -- texte courant #d9d4c7
Theme.MUTED     = { 0.49, 0.51, 0.54 }   -- texte secondaire #7d8389
Theme.MUTED_LIGHT = { 0.64, 0.66, 0.68 } -- « MUTED clair » #a3a8ad (sous-titre, sections)
Theme.INK       = { 0.06, 0.07, 0.09 }
Theme.SURFACE   = { 0.075, 0.09, 0.105 } -- fond des fenêtres #13171b
Theme.SURFACE_2 = { 0.06, 0.07, 0.085 }  -- colonne de navigation #0f1215
Theme.CONTROL   = { 0.16, 0.19, 0.21 }   -- piste, bouton au repos #2a3036
Theme.GREEN     = { 0.44, 0.81, 0.48 }   -- statut OK #6fcf7a (pas le vert de rareté)
Theme.RED       = { 0.89, 0.38, 0.31 }   -- statut échec #e2604f
Theme.ORANGE    = { 0.91, 0.65, 0.29 }   -- statut alerte = l'ambre
Theme.ORANGE_DEEP = { 0.93, 0.47, 0.20 } -- statut « pas prêt » #ed7833 (entre l'ambre et le rouge)
Theme.GREY      = { 0.55, 0.55, 0.55 }
-- Deuxième couleur (v1.21.0) : bleu de nuit, l'aiguille de la boussole.
-- Rôle : information et navigation (groupes, statut « info », source d'une
-- zone apprise), et depuis la v1.25.0 l'appel au départ « Partir à
-- l'aventure » (choix de l'utilisateur : c'est la couleur de l'aiguille, celle
-- du voyage). Jamais un statut.
Theme.BLUE      = { 0.357, 0.561, 0.839 } -- #5b8fd6

-- Jetons de la refonte (docs/UI.md, « Palette »)
Theme.WINDOW    = { 0.075, 0.090, 0.106 } -- fond de fenêtre #13171b (= SURFACE)
Theme.NAV       = { 0.051, 0.063, 0.075 } -- colonne de navigation, pied #0d1013
Theme.ROW       = { 0.090, 0.110, 0.129 } -- carte de réglage #171c21
Theme.ROW_ALT   = { 0.106, 0.129, 0.153 } -- carte de réglage, rangée paire #1b2127
Theme.FIELD     = { 0.063, 0.078, 0.094 } -- champ, liste, recherche #101418
Theme.EDGE      = { 0.227, 0.259, 0.290 } -- bord de fenêtre, bouton en contour #3a424a
Theme.EDGE_SOFT = { 0.165, 0.192, 0.220 } -- filets, séparations #2a3138
Theme.LABEL     = { 0.902, 0.882, 0.835 } -- libellé de carte #e6e1d5

Theme.T_GOLD      = "|cffe8a54b"
Theme.T_PARCHMENT = "|cfff1e8d4"
Theme.T_GREY      = "|cff7d8389"
Theme.T_GREEN     = "|cff6fcf7a"
Theme.T_RED       = "|cffe2604f"
Theme.T_ORANGE    = "|cffe8a54b"
Theme.T_ORANGE_DEEP = "|cffed7833"
Theme.T_WHITE     = "|cffffffff"
Theme.T_BLUE      = "|cff5b8fd6"

Theme.BG_DARK  = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
Theme.BG_LIGHT = "Interface\\DialogFrame\\UI-DialogBox-Background"
Theme.SOLID    = "Interface\\Buttons\\WHITE8X8"
Theme.LOGO          = MEDIA .. "Textures\\logo"         -- logo de l'addon (boussole R2Q, dragonnet QC)
Theme.LOGO_SMALL    = MEDIA .. "Textures\\logo_petit"   -- petites tailles : bandeaux, minicarte
Theme.DIAMOND       = SOCLE_MEDIA .. "losange"
Theme.DIAMOND_LINE  = SOCLE_MEDIA .. "losange_trait"
Theme.POWER         = SOCLE_MEDIA .. "interrupteur"     -- rond ouvert « marche/arrêt »
Theme.CHEVRON       = SOCLE_MEDIA .. "chevron"          -- chevron des listes déroulantes
-- Flèche de rafraîchissement : l'icône du jeu (fichier 851904), présente dans
-- les clients Era 1.15.9 et Forever 1.60.1 (listes de fichiers wago.tools).
-- Elle est jaune : on la désature au repos plutôt que de la teinter.
Theme.REFRESH       = "Interface\\Buttons\\UI-RefreshButton"

-- Polices ------------------------------------------------------------------------
-- Inter, réduite aux caractères latins (accents, guillemets, flèches, ▲ ▼ ×
-- compris ; pas de ✕ ni de ▶). Un objet de police par rôle et par addon : les
-- noms sont préfixés par ns.APP.id (« Ready2QuestFontBody ») pour que les deux
-- addons ne se marchent pas dessus.
Theme.FONT_REGULAR  = SOCLE_MEDIA .. "Inter-Regular.ttf"
Theme.FONT_SEMIBOLD = SOCLE_MEDIA .. "Inter-SemiBold.ttf"
Theme.FONT_BOLD     = SOCLE_MEDIA .. "Inter-Bold.ttf"
Theme.FONT_TITLE    = Theme.FONT_BOLD

-- rôle -> graisse, taille (docs/UI.md) et police du jeu de repli. NUMBER sert
-- aux valeurs chiffrées (Inter Bold, chiffres lisibles).
Theme.FONT_ROLES = {
	{ role = "DISPLAY", file = "FONT_BOLD",     size = 26, fallback = "GameFontNormalHuge" },
	{ role = "TITLE",   file = "FONT_BOLD",     size = 16, fallback = "GameFontNormalLarge" },
	{ role = "HEADING", file = "FONT_SEMIBOLD", size = 13, fallback = "GameFontHighlight" },
	{ role = "LABEL",   file = "FONT_SEMIBOLD", size = 12, fallback = "GameFontHighlight" },
	{ role = "BODY",    file = "FONT_REGULAR",  size = 12, fallback = "GameFontHighlightSmall" },
	{ role = "SMALL",   file = "FONT_REGULAR",  size = 11, fallback = "GameFontHighlightSmall" },
	{ role = "CAPS",    file = "FONT_SEMIBOLD", size = 10, fallback = "GameFontNormalSmall" },
	{ role = "NUMBER",  file = "FONT_BOLD",     size = 12, fallback = "NumberFontNormal" },
}

-- Crée (ou reprend) les objets de police d'un préfixe. Chaque SetFont passe
-- par pcall ; s'il échoue, l'objet copie la police du jeu correspondante. Sans
-- CreateFont ou sans copie possible, le rôle désigne directement la police du
-- jeu : le texte s'affiche toujours. Retourne { ROLE = { name, inter, … } }.
function Theme.CreateFonts(prefix)
	local fonts = {}
	local createFont = rawget(_G, "CreateFont")
	for _, spec in ipairs(Theme.FONT_ROLES) do
		local name = tostring(prefix) .. "Font" .. spec.role:sub(1, 1) .. spec.role:sub(2):lower()
		local entry = { role = spec.role, file = Theme[spec.file], size = spec.size, fallback = spec.fallback, inter = false }
		local font = rawget(_G, name)
		if font == nil and type(createFont) == "function" then
			local ok, created = pcall(createFont, name)
			if ok then font = created end
		end
		if font and type(font.SetFont) == "function" then
			local ok, applied = pcall(font.SetFont, font, entry.file, spec.size, "")
			entry.inter = ok and applied ~= false
			local usable = entry.inter
			if not usable then
				local base = rawget(_G, spec.fallback)
				if base and type(font.CopyFontObject) == "function" then
					usable = pcall(font.CopyFontObject, font, base)
				end
				if not usable and base and type(font.SetFontObject) == "function" then
					usable = pcall(font.SetFontObject, font, base)
				end
			end
			if usable then
				if font.SetTextColor then pcall(font.SetTextColor, font, Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3], 1) end
				-- ombre légère : lisible sur le décor ; les textes sombres l'ôtent (NoShadow)
				if font.SetShadowColor then pcall(font.SetShadowColor, font, 0, 0, 0, 0.6) end
				if font.SetShadowOffset then pcall(font.SetShadowOffset, font, 1, -1) end
				entry.name, entry.object = name, font
			end
		end
		entry.name = entry.name or spec.fallback
		fonts[spec.role] = entry
	end
	return fonts
end

local FONT_PREFIX = tostring((ns.APP and ns.APP.id) or ADDON or "Socle")
Theme.fonts = Theme.CreateFonts(FONT_PREFIX)
Theme.F_DISPLAY = Theme.fonts.DISPLAY.name
Theme.F_TITLE   = Theme.fonts.TITLE.name
Theme.F_HEADING = Theme.fonts.HEADING.name
Theme.F_LABEL   = Theme.fonts.LABEL.name
Theme.F_BODY    = Theme.fonts.BODY.name
Theme.F_SMALL   = Theme.fonts.SMALL.name
Theme.F_CAPS    = Theme.fonts.CAPS.name
Theme.F_NUMBER  = Theme.fonts.NUMBER.name
-- ancien nom (GameFontHighlight) : texte courant
Theme.F_NORMAL  = Theme.F_BODY

local function Clamp(value, minimum, maximum)
	if value < minimum then return minimum end
	if value > maximum then return maximum end
	return value
end
Theme.Clamp = Clamp

local function Solid(parent, layer, color, alpha)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK")
	tex:SetTexture(Theme.SOLID)
	tex:SetVertexColor(color[1], color[2], color[3], alpha or 1)
	return tex
end
Theme.Solid = Solid

local function SetColor(region, color, alpha)
	if region and region.SetTextColor then region:SetTextColor(color[1], color[2], color[3], alpha or 1) end
end

-- Texte sombre sur fond plein : sans l'ombre noire de la police (sombre sur
-- sombre, elle bave et rend le texte illisible)
function Theme.NoShadow(fontString)
	if not fontString then return end
	if fontString.SetShadowOffset then fontString:SetShadowOffset(0, 0) end
	if fontString.SetShadowColor then fontString:SetShadowColor(0, 0, 0, 0) end
end

-- Capitales des titres de section : string.upper ignore les lettres
-- accentuées UTF-8, on les traite à part.
local ACCENTS = {
	["à"] = "À", ["â"] = "Â", ["ä"] = "Ä", ["ç"] = "Ç", ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["ë"] = "Ë",
	["î"] = "Î", ["ï"] = "Ï", ["ô"] = "Ô", ["ö"] = "Ö", ["ù"] = "Ù", ["û"] = "Û", ["ü"] = "Ü", ["ÿ"] = "Ÿ",
	["œ"] = "Œ", ["æ"] = "Æ",
}
function Theme.Upper(text)
	text = string.upper(tostring(text or ""))
	return (text:gsub("[\195\197][\128-\191]", ACCENTS))
end

-- Dégradé d'une texture : API récente (CreateColor), sinon l'ancienne
-- (SetGradientAlpha), sinon un aplat à mi-chemin. `orientation` :
-- "HORIZONTAL" (de gauche à droite) ou "VERTICAL" (de bas en haut).
-- Retourne "color", "alpha" ou nil (aplat).
function Theme.Gradient(tex, orientation, fromColor, fromAlpha, toColor, toAlpha)
	if not tex then return nil end
	fromAlpha, toAlpha = fromAlpha or 1, toAlpha or 1
	tex.gradientSpec = { orientation, fromColor, fromAlpha, toColor, toAlpha }
	local createColor = rawget(_G, "CreateColor")
	if type(tex.SetGradient) == "function" and type(createColor) == "function" then
		tex:SetVertexColor(1, 1, 1, 1)
		local okA, minColor = pcall(createColor, fromColor[1], fromColor[2], fromColor[3], fromAlpha)
		local okB, maxColor = pcall(createColor, toColor[1], toColor[2], toColor[3], toAlpha)
		if okA and okB and pcall(tex.SetGradient, tex, orientation, minColor, maxColor) then return "color" end
	end
	if type(tex.SetGradientAlpha) == "function" then
		tex:SetVertexColor(1, 1, 1, 1)
		if pcall(tex.SetGradientAlpha, tex, orientation, fromColor[1], fromColor[2], fromColor[3], fromAlpha,
			toColor[1], toColor[2], toColor[3], toAlpha) then return "alpha" end
	end
	tex:SetVertexColor((fromColor[1] + toColor[1]) / 2, (fromColor[2] + toColor[2]) / 2,
		(fromColor[3] + toColor[3]) / 2, (fromAlpha + toAlpha) / 2)
	return nil
end
local Gradient = Theme.Gradient

-- Police de titre : appliquée sur une FontString existante. Si le client
-- refuse le fichier (chemin, format), on garde la police de l'objet d'origine.
function Theme.TitleFont(fontString, size)
	if not fontString or not fontString.SetFont then return false end
	local ok, applied = pcall(fontString.SetFont, fontString, Theme.FONT_TITLE, size or 14, "")
	fontString.titleFont = ok and applied ~= false
	return fontString.titleFont
end

function Theme.CreateTitle(parent, size, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", Theme.F_TITLE)
	Theme.TitleFont(fs, size)
	fs:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
	return fs
end

-- Texte dans un rôle de police, avec sa couleur
local function Text(parent, font, color, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", font)
	if color then SetColor(fs, color) end
	return fs
end
Theme.Text = Text

-- Bordure 1 px sur les quatre côtés
local function Border(frame, color, alpha, layer)
	local edges = {}
	for _, side in ipairs({ "top", "bottom", "left", "right" }) do
		edges[side] = Solid(frame, layer or "BORDER", color, alpha)
	end
	edges.top:SetPoint("TOPLEFT"); edges.top:SetPoint("TOPRIGHT"); edges.top:SetHeight(1)
	edges.bottom:SetPoint("BOTTOMLEFT"); edges.bottom:SetPoint("BOTTOMRIGHT"); edges.bottom:SetHeight(1)
	edges.left:SetPoint("TOPLEFT"); edges.left:SetPoint("BOTTOMLEFT"); edges.left:SetWidth(1)
	edges.right:SetPoint("TOPRIGHT"); edges.right:SetPoint("BOTTOMRIGHT"); edges.right:SetWidth(1)
	function edges:SetColor(r, g, b, a)
		for _, side in ipairs({ "top", "bottom", "left", "right" }) do self[side]:SetVertexColor(r, g, b, a or 1) end
	end
	return edges
end
Theme.Border = Border

-- Signature : coin supérieur gauche en équerre ambre, 12 px
local function CornerAccent(frame)
	local h = Solid(frame, "OVERLAY", Theme.GOLD, 1)
	h:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	h:SetSize(12, 2)
	local v = Solid(frame, "OVERLAY", Theme.GOLD, 1)
	v:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	v:SetSize(2, 12)
	return h, v
end
Theme.CornerAccent = CornerAccent

-- Échap ferme la fenêtre, comme pour toutes les fenêtres Blizzard
function Theme.RegisterEscapeClose(frame)
	if not frame or type(UISpecialFrames) ~= "table" then return end
	local name = frame.GetName and frame:GetName()
	if type(name) ~= "string" or name == "" then return end
	for _, existing in ipairs(UISpecialFrames) do
		if existing == name then return end
	end
	UISpecialFrames[#UISpecialFrames + 1] = name
end

-- Fenêtre déplaçable à la souris, gardée à l'écran
local function Draggable(frame)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
end

-- Bouton de fermeture dessiné : « × » dans un carré au trait (pas de
-- UIPanelCloseButton). Le filet passe à l'ambre au survol.
function Theme.CreateCloseButton(frame, size)
	local close = CreateFrame("Button", nil, frame)
	size = size or 22
	close:SetSize(size, size)
	close.border = Border(close, Theme.EDGE, 1)
	close.label = Text(close, Theme.F_TITLE, Theme.MUTED_LIGHT)
	close.label:SetPoint("CENTER", 0, 0)
	close.label:SetText("\195\151")   -- × (U+00D7), présent dans Inter et les polices du jeu
	close:SetScript("OnEnter", function()
		close.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		SetColor(close.label, Theme.PARCHMENT)
	end)
	close:SetScript("OnLeave", function()
		close.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1)
		SetColor(close.label, Theme.MUTED_LIGHT)
	end)
	close:SetScript("OnClick", function() frame:Hide() end)
	return close
end

-- ---------------------------------------------------------------------------
-- Panneau (ancienne fenêtre, toujours utilisée par les modules) : fond
-- WINDOW, filet EDGE, coin ambre, bandeau avec la marque
-- ---------------------------------------------------------------------------
local function BuildHeader(frame, titleText, options)
	frame.logo = frame:CreateTexture(nil, "OVERLAY")
	frame.logo:SetTexture(Theme.LOGO_SMALL)
	frame.logo:SetSize(18, 18)
	frame.logo:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -9)

	frame.title = Theme.CreateTitle(frame, options.titleSize or 15)
	frame.title:SetPoint("LEFT", frame.logo, "RIGHT", 7, 0)
	frame.title:SetText(titleText or "")

	frame.subtitle = Text(frame, Theme.F_SMALL, Theme.MUTED)
	frame.subtitle:SetPoint("RIGHT", frame, "TOPRIGHT", -36, -18)
	frame.subtitle:SetText("")

	frame.headerLine = Solid(frame, "ARTWORK", Theme.EDGE_SOFT, 1)
	frame.headerLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -34)
	frame.headerLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -34)
	frame.headerLine:SetHeight(1)

	frame.close = Theme.CreateCloseButton(frame, 20)
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -7)
end

function Theme.CreatePanel(parent, width, height, titleText, options)
	options = options or {}
	local ok, frame = pcall(CreateFrame, "Frame", options.name, parent or UIParent)
	if not ok or not frame then frame = CreateFrame("Frame", options.name, parent or UIParent) end
	if not frame then return nil end

	frame.bg = Solid(frame, "BACKGROUND", Theme.WINDOW, options.alpha or 0.97)
	frame.bg:SetAllPoints()
	frame.border = Border(frame, Theme.EDGE, 1)
	frame.accentH, frame.accentV = CornerAccent(frame)
	frame.chrome = "flat"

	frame:SetSize(width, height)
	frame:SetFrameStrata(options.strata or "DIALOG")
	Draggable(frame)

	if options.title ~= false then
		BuildHeader(frame, titleText, options)
		frame.contentTop = -36
	else
		frame.contentTop = -10
	end

	Theme.RegisterEscapeClose(frame)
	return frame
end

-- ---------------------------------------------------------------------------
-- Fenêtre v2 (docs/UI.md, « Fenêtre type ») : fond WINDOW, filet EDGE,
-- [×] en haut à droite, Échap, déplaçable ; colonne de navigation facultative
-- (opts.nav = sa largeur), pied facultatif (opts.footer = sa hauteur).
-- Retourne la fenêtre avec .content (zone de droite) et .nav.
-- ---------------------------------------------------------------------------
function Theme.CreateWindow(parent, width, height, opts)
	opts = opts or {}
	local ok, frame = pcall(CreateFrame, "Frame", opts.name, parent or UIParent)
	if not ok or not frame then return nil end
	frame:SetSize(width, height)
	frame:SetFrameStrata(opts.strata or "DIALOG")
	frame.chrome = "window"

	frame.bg = Solid(frame, "BACKGROUND", Theme.WINDOW, opts.alpha or 0.98)
	frame.bg:SetAllPoints()
	frame.border = Border(frame, Theme.EDGE, 1, "OVERLAY")
	Draggable(frame)

	local navWidth = tonumber(opts.nav)
	if navWidth and navWidth > 0 then
		frame.nav = CreateFrame("Frame", nil, frame)
		frame.nav:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
		frame.nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
		frame.nav:SetWidth(navWidth)
		frame.nav.bg = Solid(frame.nav, "BACKGROUND", Theme.NAV, 1)
		frame.nav.bg:SetAllPoints()
		frame.nav.separator = Solid(frame.nav, "BORDER", Theme.EDGE_SOFT, 1)
		frame.nav.separator:SetPoint("TOPRIGHT", frame.nav, "TOPRIGHT", 0, 0)
		frame.nav.separator:SetPoint("BOTTOMRIGHT", frame.nav, "BOTTOMRIGHT", 0, 0)
		frame.nav.separator:SetWidth(1)
	end

	frame.content = CreateFrame("Frame", nil, frame)
	if frame.nav then
		frame.content:SetPoint("TOPLEFT", frame.nav, "TOPRIGHT", 0, 0)
	else
		frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	end
	frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	frame.content:SetSize(width - 2 - (navWidth or 0), height - 2)

	local footerHeight = tonumber(opts.footer)
	if footerHeight and footerHeight > 0 then
		frame.footer = CreateFrame("Frame", nil, frame.content)
		frame.footer:SetPoint("BOTTOMLEFT", frame.content, "BOTTOMLEFT", 0, 0)
		frame.footer:SetPoint("BOTTOMRIGHT", frame.content, "BOTTOMRIGHT", 0, 0)
		frame.footer:SetHeight(footerHeight)
		frame.footer.bg = Solid(frame.footer, "BACKGROUND", Theme.NAV, 1)
		frame.footer.bg:SetAllPoints()
		frame.footer.line = Solid(frame.footer, "BORDER", Theme.EDGE_SOFT, 1)
		frame.footer.line:SetPoint("TOPLEFT", frame.footer, "TOPLEFT", 0, 0)
		frame.footer.line:SetPoint("TOPRIGHT", frame.footer, "TOPRIGHT", 0, 0)
		frame.footer.line:SetHeight(1)
	end

	frame.close = Theme.CreateCloseButton(frame, 24)
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -14)
	if frame.close.SetFrameLevel and frame.GetFrameLevel then
		frame.close:SetFrameLevel((tonumber(frame:GetFrameLevel()) or 1) + 20)
	end

	Theme.RegisterEscapeClose(frame)
	return frame
end

-- Filet ambre lumineux : transparent -> ambre -> ambre clair -> transparent,
-- avec un halo plus large et très pâle dessous. Retourne { segments, glow }.
function Theme.CreateGlowRule(parent, height)
	local rule = { segments = {}, glow = {} }
	height = height or 2
	local stops = {
		{ 0.00, 0.35, Theme.GOLD, 0, Theme.GOLD, 1 },
		{ 0.35, 0.65, Theme.GOLD, 1, Theme.GOLD_LIGHT, 1 },
		{ 0.65, 1.00, Theme.GOLD_LIGHT, 1, Theme.GOLD, 0 },
	}
	-- halo : deux moitiés, transparent -> ambre pâle -> transparent
	for index = 1, 2 do
		local glow = parent:CreateTexture(nil, "BORDER")
		glow:SetTexture(Theme.SOLID)
		if index == 1 then
			Gradient(glow, "HORIZONTAL", Theme.GOLD, 0, Theme.GOLD, 0.16)
		else
			Gradient(glow, "HORIZONTAL", Theme.GOLD, 0.16, Theme.GOLD, 0)
		end
		rule.glow[index] = glow
	end
	for index, stop in ipairs(stops) do
		local seg = parent:CreateTexture(nil, "ARTWORK")
		seg:SetTexture(Theme.SOLID)
		Gradient(seg, "HORIZONTAL", stop[3], stop[4], stop[5], stop[6])
		seg.from, seg.to = stop[1], stop[2]
		rule.segments[index] = seg
	end
	-- place le filet de `left` à `left + width`, à la hauteur `y` sous le haut du parent
	function rule:Place(left, y, width)
		for _, seg in ipairs(self.segments) do
			seg:ClearAllPoints()
			seg:SetPoint("TOPLEFT", parent, "TOPLEFT", left + math.floor(width * seg.from + 0.5), y)
			seg:SetSize(math.floor(width * (seg.to - seg.from) + 0.5), height)
		end
		local half = math.floor(width / 2 + 0.5)
		for index, glow in ipairs(self.glow) do
			glow:ClearAllPoints()
			glow:SetPoint("TOPLEFT", parent, "TOPLEFT", left + (index - 1) * half, y + 4)
			glow:SetSize(half, height + 8)
		end
	end
	return rule
end

-- ---------------------------------------------------------------------------
-- En-tête de page : grand titre (F_DISPLAY), sous-titre (F_BODY, MUTED
-- clair), filet ambre lumineux, lueur ambre très discrète en haut.
-- ---------------------------------------------------------------------------
Theme.HEADER_HEIGHT = 100
function Theme.CreatePageHeader(parent, width)
	local header = CreateFrame("Frame", nil, parent)
	width = width or (parent.GetWidth and parent:GetWidth()) or 600
	header:SetSize(width, Theme.HEADER_HEIGHT)

	header.topGlow = header:CreateTexture(nil, "BACKGROUND")
	header.topGlow:SetTexture(Theme.SOLID)
	header.topGlow:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
	header.topGlow:SetSize(width, 72)
	Gradient(header.topGlow, "VERTICAL", Theme.GOLD, 0, Theme.GOLD, 0.06)
	-- coin haut gauche un peu plus chaud
	header.cornerGlow = header:CreateTexture(nil, "BACKGROUND")
	header.cornerGlow:SetTexture(Theme.SOLID)
	header.cornerGlow:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
	header.cornerGlow:SetSize(math.floor(width * 0.45), 72)
	Gradient(header.cornerGlow, "HORIZONTAL", Theme.GOLD, 0.05, Theme.GOLD, 0)

	header.title = Text(header, Theme.F_DISPLAY, Theme.PARCHMENT)
	header.title:SetPoint("TOPLEFT", header, "TOPLEFT", 24, -22)
	header.title:SetJustifyH("LEFT")
	header.title:SetText("")

	header.subtitle = Text(header, Theme.F_BODY, Theme.MUTED_LIGHT)
	header.subtitle:SetPoint("TOPLEFT", header, "TOPLEFT", 24, -60)
	header.subtitle:SetJustifyH("LEFT")
	header.subtitle:SetText("")

	header.rule = Theme.CreateGlowRule(header, 2)
	header.rule:Place(24, -86, width - 48)

	function header:SetTitle(text) self.title:SetText(text or "") end
	function header:SetSubtitle(text) self.subtitle:SetText(text or "") end
	return header
end

-- ---------------------------------------------------------------------------
-- Navigation : marque, groupes, entrées
-- ---------------------------------------------------------------------------
function Theme.CreateNavBrand(parent, logoTexture, name)
	local brand = CreateFrame("Frame", nil, parent)
	local width = (parent.GetWidth and parent:GetWidth()) or 220
	brand:SetSize(width, 64)
	brand.logo = brand:CreateTexture(nil, "ARTWORK")
	brand.logo:SetTexture(logoTexture or Theme.LOGO)
	brand.logo:SetSize(32, 32)
	brand.logo:SetPoint("LEFT", brand, "LEFT", 16, 2)
	brand.name = Text(brand, Theme.F_TITLE, Theme.PARCHMENT)
	brand.name:SetPoint("LEFT", brand.logo, "RIGHT", 10, 0)
	brand.name:SetJustifyH("LEFT")
	brand.name:SetText(name or "")
	brand.rule = Solid(brand, "ARTWORK", Theme.GOLD, 1)
	brand.rule:SetPoint("BOTTOMLEFT", brand, "BOTTOMLEFT", 16, 0)
	brand.rule:SetPoint("BOTTOMRIGHT", brand, "BOTTOMRIGHT", -16, 0)
	brand.rule:SetHeight(1)
	Gradient(brand.rule, "HORIZONTAL", Theme.GOLD, 0.9, Theme.GOLD, 0)
	return brand
end

-- Titre de groupe : ambre, F_CAPS, en capitales
function Theme.CreateNavGroup(parent, text)
	local label = Text(parent, Theme.F_CAPS, Theme.GOLD)
	label:SetJustifyH("LEFT")
	label:SetText(Theme.Upper(text))
	return label
end

Theme.NAV_ITEM_HEIGHT = 28
function Theme.CreateNavItem(parent, width)
	local item = CreateFrame("Button", nil, parent)
	item:SetSize(width or 220, Theme.NAV_ITEM_HEIGHT)

	item.hover = Solid(item, "BACKGROUND", { 1, 1, 1 }, 0.035)
	item.hover:SetAllPoints()
	item.hover:Hide()
	item.tint = item:CreateTexture(nil, "BACKGROUND")
	item.tint:SetTexture(Theme.SOLID)
	item.tint:SetAllPoints()
	Gradient(item.tint, "HORIZONTAL", Theme.GOLD, 0.16, Theme.GOLD, 0)
	item.tint:Hide()
	item.bar = Solid(item, "ARTWORK", Theme.GOLD, 1)
	item.bar:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
	item.bar:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
	item.bar:SetWidth(2)
	item.bar:Hide()

	item.label = Text(item, Theme.F_BODY, Theme.TEXT)
	item.label:SetPoint("LEFT", item, "LEFT", 18, 0)
	item.label:SetJustifyH("LEFT")

	item.badge = Text(item, Theme.F_SMALL, Theme.BLUE)
	item.badge:SetJustifyH("RIGHT")
	item.badge:Hide()

	-- interrupteur de module : rond ouvert, ambre si actif, gris si coupé
	item.power = CreateFrame("Button", nil, item)
	item.power:SetSize(16, 16)
	item.power:SetPoint("RIGHT", item, "RIGHT", -12, 0)
	item.power.icon = item.power:CreateTexture(nil, "ARTWORK")
	item.power.icon:SetTexture(Theme.POWER)
	item.power.icon:SetAllPoints()
	item.power:SetScript("OnClick", function()
		if item.onPower then item.onPower(item, not item.moduleOn) end
	end)
	item.power:Hide()

	local function Paint(self)
		local color = Theme.TEXT
		if self.selected then color = Theme.PARCHMENT
		elseif self.moduleOn == false then color = Theme.MUTED end
		SetColor(self.label, color)
		if self.selected then self.tint:Show(); self.bar:Show() else self.tint:Hide(); self.bar:Hide() end
		if self.hovered and not self.selected then self.hover:Show() else self.hover:Hide() end
	end
	local function PlaceBadge(self)
		self.badge:ClearAllPoints()
		if self.power:IsShown() then
			self.badge:SetPoint("RIGHT", self.power, "LEFT", -6, 0)
		else
			self.badge:SetPoint("RIGHT", self, "RIGHT", -12, 0)
		end
	end

	function item:SetText(text) self.label:SetText(text or "") end
	function item:GetText() return self.label:GetText() end
	function item:SetSelected(on)
		self.selected = on and true or false
		Paint(self)
	end
	-- on = true/"on" (actif), false/"off" (coupé), nil (pas d'interrupteur)
	function item:SetModuleState(state)
		if state == nil then
			self.moduleOn = nil
			self.power:Hide()
		else
			self.moduleOn = (state == true or state == "on")
			self.power:Show()
			local c = self.moduleOn and Theme.GOLD or Theme.MUTED
			self.power.icon:SetVertexColor(c[1], c[2], c[3], 1)
		end
		PlaceBadge(self)
		Paint(self)
	end
	function item:SetBadge(text)
		if text == nil or text == "" then
			self.badge:SetText("")
			self.badge:Hide()
		else
			self.badge:SetText(text)
			self.badge:Show()
		end
		PlaceBadge(self)
	end
	item:SetScript("OnEnter", function(self) self.hovered = true; Paint(self) end)
	item:SetScript("OnLeave", function(self) self.hovered = false; Paint(self) end)
	item:SetSelected(false)
	item:SetModuleState(nil)
	return item
end

-- ---------------------------------------------------------------------------
-- Onglets : F_HEADING, soulignement ambre 2 px sous l'onglet choisi, filet
-- EDGE_SOFT en bas. onSelect(id) au choix d'un onglet.
-- ---------------------------------------------------------------------------
Theme.TABS_HEIGHT = 32
function Theme.CreateTabs(parent, onSelect)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetSize((parent.GetWidth and parent:GetWidth()) or 400, Theme.TABS_HEIGHT)
	bar.tabs, bar.byId = {}, {}
	bar.rule = Solid(bar, "BORDER", Theme.EDGE_SOFT, 1)
	bar.rule:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	bar.rule:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	bar.rule:SetHeight(1)

	local function Paint(tab)
		local on = bar.selected == tab.id
		SetColor(tab.label, on and Theme.PARCHMENT or (tab.hovered and Theme.TEXT or Theme.MUTED_LIGHT))
		if on then tab.underline:Show() else tab.underline:Hide() end
	end

	function bar:SetTabs(list)
		for _, tab in ipairs(self.tabs) do tab:Hide() end
		self.byId = {}
		local x = 0
		for index, def in ipairs(list or {}) do
			local tab = self.tabs[index]
			if not tab then
				tab = CreateFrame("Button", nil, self)
				tab.label = Text(tab, Theme.F_HEADING, Theme.MUTED_LIGHT)
				tab.label:SetPoint("CENTER", tab, "CENTER", 0, 1)
				tab.underline = Solid(tab, "ARTWORK", Theme.GOLD, 1)
				tab.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
				tab.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
				tab.underline:SetHeight(2)
				tab:SetScript("OnClick", function(selfTab) bar:Select(selfTab.id) end)
				tab:SetScript("OnEnter", function(selfTab) selfTab.hovered = true; Paint(selfTab) end)
				tab:SetScript("OnLeave", function(selfTab) selfTab.hovered = false; Paint(selfTab) end)
				self.tabs[index] = tab
			end
			tab.id = def.id
			tab.label:SetText(def.label or tostring(def.id))
			local textWidth = (tab.label.GetStringWidth and tab.label:GetStringWidth()) or 60
			local w = math.floor(textWidth + 0.5) + 24
			tab:SetSize(w, Theme.TABS_HEIGHT)
			tab:ClearAllPoints()
			tab:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, 0)
			tab:Show()
			x = x + w + 4
			self.byId[def.id] = tab
		end
		if not (self.selected and self.byId[self.selected]) then
			self.selected = list and list[1] and list[1].id or nil
		end
		for _, tab in ipairs(self.tabs) do Paint(tab) end
	end

	-- `silent` : sans rappel (rafraîchissement depuis le code)
	function bar:Select(id, silent)
		if not self.byId[id] then return false end
		self.selected = id
		for _, tab in ipairs(self.tabs) do Paint(tab) end
		if onSelect and not silent then onSelect(id) end
		return true
	end
	return bar
end

-- ---------------------------------------------------------------------------
-- Recherche : EditBox FIELD bordée EDGE (ambre au focus), texte indicatif
-- ---------------------------------------------------------------------------
function Theme.CreateSearchBox(parent, width, placeholder, onChange)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetSize(width or 180, 24)
	if box.SetAutoFocus then box:SetAutoFocus(false) end
	if box.SetFontObject then box:SetFontObject(Theme.F_BODY) end
	if box.SetTextInsets then box:SetTextInsets(8, 8, 0, 0) end
	if box.SetMaxLetters then box:SetMaxLetters(60) end
	if box.SetTextColor then box:SetTextColor(Theme.LABEL[1], Theme.LABEL[2], Theme.LABEL[3], 1) end
	box.bg = Solid(box, "BACKGROUND", Theme.FIELD, 1)
	box.bg:SetAllPoints()
	box.border = Border(box, Theme.EDGE, 1)
	box.placeholder = Text(box, Theme.F_BODY, Theme.MUTED, "ARTWORK")
	box.placeholder:SetPoint("LEFT", box, "LEFT", 8, 0)
	box.placeholder:SetJustifyH("LEFT")
	box.placeholder:SetText(placeholder or "")

	function box:Refresh()
		local text = self:GetText() or ""
		if text == "" then self.placeholder:Show() else self.placeholder:Hide() end
		return text
	end
	box:SetScript("OnTextChanged", function(self)
		local text = self:Refresh()
		if text ~= self.lastValue then
			self.lastValue = text
			if onChange then onChange(text, self) end
		end
	end)
	box:SetScript("OnEditFocusGained", function(self) self.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1) end)
	box:SetScript("OnEditFocusLost", function(self) self.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1) end)
	box:SetScript("OnEscapePressed", function(self) if self.ClearFocus then self:ClearFocus() end end)
	box:SetScript("OnEnterPressed", function(self) if self.ClearFocus then self:ClearFocus() end end)
	box.lastValue = ""
	box:Refresh()
	return box
end

-- ---------------------------------------------------------------------------
-- Section : titre F_CAPS en capitales, MUTED clair, détail plus pâle
-- ---------------------------------------------------------------------------
function Theme.CreateSection(parent, text, detail)
	local section = CreateFrame("Frame", nil, parent)
	section:SetSize((parent.GetWidth and parent:GetWidth()) or 400, 20)
	section.label = Text(section, Theme.F_CAPS, Theme.MUTED_LIGHT)
	section.label:SetPoint("LEFT", section, "LEFT", 0, 0)
	section.label:SetJustifyH("LEFT")
	section.detail = Text(section, Theme.F_SMALL, Theme.MUTED)
	section.detail:SetPoint("LEFT", section.label, "RIGHT", 6, 0)
	section.detail:SetJustifyH("LEFT")
	function section:SetText(label, more)
		self.label:SetText(Theme.Upper(label))
		if more and more ~= "" then
			self.detail:SetText("(" .. more .. ")")
			self.detail:Show()
		else
			self.detail:SetText("")
			self.detail:Hide()
		end
	end
	section:SetText(text, detail)
	return section
end

-- ---------------------------------------------------------------------------
-- Carte de réglage : fond ROW (ROW_ALT une rangée sur deux), libellé à
-- gauche, zone .control à droite pour le contrôle (aligné à droite)
-- ---------------------------------------------------------------------------
Theme.CARD_HEIGHT = 38
function Theme.CreateSettingCard(parent, width, height)
	local card = CreateFrame("Frame", nil, parent)
	width, height = width or 340, height or Theme.CARD_HEIGHT
	card:SetSize(width, height)
	card.bg = Solid(card, "BACKGROUND", Theme.ROW, 1)
	card.bg:SetAllPoints()
	card.label = Text(card, Theme.F_LABEL, Theme.LABEL)
	card.label:SetPoint("LEFT", card, "LEFT", 12, 0)
	card.label:SetJustifyH("LEFT")
	card.control = CreateFrame("Frame", nil, card)
	card.control:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, 0)
	card.control:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 0)
	card.control:SetWidth(math.floor(width / 2))
	function card:SetAlt(alt)
		self.alt = alt and true or false
		local c = self.alt and Theme.ROW_ALT or Theme.ROW
		self.bg:SetVertexColor(c[1], c[2], c[3], 1)
	end
	function card:SetLabel(text) self.label:SetText(text or "") end
	card:SetAlt(false)
	return card
end

-- ---------------------------------------------------------------------------
-- Barre : piste ardoise, remplissage plat
-- ---------------------------------------------------------------------------
function Theme.CreateBar(parent, width, height)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetSize(width, height)

	bar.bg = Solid(bar, "BACKGROUND", { 0.15, 0.17, 0.20 }, 1)
	bar.bg:SetAllPoints()

	bar.fill = Solid(bar, "ARTWORK", Theme.GOLD, 1)
	bar.fill:SetPoint("TOPLEFT")
	bar.fill:SetPoint("BOTTOMLEFT")
	bar.fill:SetWidth(0)

	function bar:SetValue(ratio)
		ratio = Clamp(tonumber(ratio) or 0, 0, 1)
		self.ratio = ratio
		local w = self:GetWidth() * ratio
		-- une texture de largeur 0 peut s'afficher sur 1 px : on la masque
		if w <= 0 then self.fill:Hide() else self.fill:Show() end
		self.fill:SetWidth(math.max(0, w))
	end

	function bar:SetColor(r, g, b, a)
		self.fill:SetVertexColor(r, g, b, a or 1)
	end

	return bar
end

-- ---------------------------------------------------------------------------
-- Filet de séparation
-- ---------------------------------------------------------------------------
function Theme.CreateDivider(parent, width, y)
	local line = Solid(parent, "ARTWORK", Theme.EDGE_SOFT, 1)
	line:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y or 0)
	line:SetSize(width or 100, 1)
	return line
end

-- ---------------------------------------------------------------------------
-- Bouton dessiné. Styles :
--   nil / "normal" / "outline" : contour EDGE, texte clair, fond transparent ;
--   "accent"    : contour ambre, texte ambre, fond ambre à 7 % ;
--   "primary"   : plein ambre, encre sombre SANS ombre ;
--   "adventure" : plein bleu de nuit, texte blanc.
-- Au survol, le contour (ou le fond, pour les boutons pleins) s'éclaire.
-- ---------------------------------------------------------------------------
local BUTTON_STYLES = {
	outline   = { bg = Theme.WINDOW, bgAlpha = 0, edge = Theme.EDGE, text = Theme.LABEL, hoverEdge = Theme.GOLD },
	accent    = { bg = Theme.GOLD, bgAlpha = 0.07, hoverAlpha = 0.14, edge = Theme.GOLD, text = Theme.GOLD },
	primary   = { bg = Theme.GOLD, bgAlpha = 1, hoverBg = Theme.GOLD_LIGHT, edge = Theme.GOLD, text = Theme.INK, filled = true },
	adventure = { bg = Theme.BLUE, bgAlpha = 1, hoverBg = { 0.45, 0.64, 0.89 }, edge = Theme.BLUE, text = { 1, 1, 1 }, filled = true },
}
BUTTON_STYLES.normal = BUTTON_STYLES.outline

function Theme.CreateButton(parent, width, height, label, onClick, style)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, height)
	button.style = style or "normal"
	local spec = BUTTON_STYLES[button.style] or BUTTON_STYLES.outline
	button.spec = spec

	button.bg = Solid(button, "BACKGROUND", spec.bg, spec.bgAlpha)
	button.bg:SetAllPoints()
	button.border = Border(button, spec.edge, 1)

	button.text = Text(button, Theme.F_LABEL, spec.text)
	button.text:SetPoint("CENTER", 0, 0)
	button.text:SetText(label)
	if button.style == "adventure" then
		-- texte blanc sur le bleu, ombre légère (texte clair : l'ombre aide)
		if button.text.SetShadowOffset then
			button.text:SetShadowColor(0, 0, 0, 0.5)
			button.text:SetShadowOffset(1, -1)
		end
	elseif button.style == "primary" then
		-- encre sur l'ambre, SANS l'ombre noire de la police
		Theme.NoShadow(button.text)
	end
	button.SetText = function(self, text) self.text:SetText(text) end
	button.GetText = function(self) return self.text:GetText() end

	button:SetScript("OnEnter", function(self)
		local s = self.spec
		if s.hoverBg then self.bg:SetVertexColor(s.hoverBg[1], s.hoverBg[2], s.hoverBg[3], 1) end
		if s.hoverAlpha then self.bg:SetVertexColor(s.bg[1], s.bg[2], s.bg[3], s.hoverAlpha) end
		if s.hoverEdge then self.border:SetColor(s.hoverEdge[1], s.hoverEdge[2], s.hoverEdge[3], 1) end
	end)
	button:SetScript("OnLeave", function(self)
		local s = self.spec
		self.bg:SetVertexColor(s.bg[1], s.bg[2], s.bg[3], s.bgAlpha)
		self.border:SetColor(s.edge[1], s.edge[2], s.edge[3], 1)
	end)
	if onClick then button:SetScript("OnClick", onClick) end
	return button
end

-- ---------------------------------------------------------------------------
-- Interrupteur : piste carrée 32 x 15 ; actif = piste ambre et curseur blanc
-- à droite, coupé = piste CONTROL et curseur MUTED à gauche
-- ---------------------------------------------------------------------------
-- `kind` = "Button" pour un interrupteur cliquable à lui seul (navigation) ;
-- `width`/`height` : 32 x 15 par défaut.
function Theme.CreateToggle(parent, width, height, kind)
	local toggle = CreateFrame(kind or "Frame", nil, parent)
	width, height = width or 32, height or 15
	toggle:SetSize(width, height)
	toggle.track = Solid(toggle, "BACKGROUND", Theme.CONTROL, 1)
	toggle.track:SetAllPoints()
	toggle.edge = Border(toggle, Theme.GOLD, 0)
	toggle.knob = Solid(toggle, "ARTWORK", Theme.MUTED, 1)
	toggle.knob:SetSize(height - 4, height - 4)

	-- partiel : une partie seulement des modules est active (contour ambre,
	-- curseur gris au centre)
	function toggle:SetPartial()
		self.checked, self.partial = nil, true
		self.knob:ClearAllPoints()
		self.knob:SetPoint("CENTER", self, "CENTER", 0, 0)
		self.knob:SetVertexColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3], 1)
		self.track:SetVertexColor(Theme.CONTROL[1], Theme.CONTROL[2], Theme.CONTROL[3], 1)
		self.edge:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
	end

	function toggle:SetChecked(on)
		self.checked = on and true or false
		self.partial = nil
		self.knob:ClearAllPoints()
		if self.checked then
			self.knob:SetPoint("RIGHT", self, "RIGHT", -2, 0)
			self.knob:SetVertexColor(1, 1, 1, 1)
			self.track:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
			self.edge:SetColor(0, 0, 0, 0)
		else
			self.knob:SetPoint("LEFT", self, "LEFT", 2, 0)
			self.knob:SetVertexColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3], 1)
			self.track:SetVertexColor(Theme.CONTROL[1], Theme.CONTROL[2], Theme.CONTROL[3], 1)
			self.edge:SetColor(0, 0, 0, 0)
		end
	end
	function toggle:GetChecked() return self.checked == true end
	toggle:SetChecked(false)
	return toggle
end

-- ---------------------------------------------------------------------------
-- Curseur : piste fine 3 px, part remplie ambre, poignée ambre, valeur dans
-- une petite case à droite. Glisser à la souris ou molette (un cran).
-- onChange(valeur, curseur) seulement sur une action de l'utilisateur ;
-- :SetValue depuis le code ne rappelle pas.
-- ---------------------------------------------------------------------------
Theme.SLIDER_VALUE_WIDTH = 44
function Theme.CreateSlider(parent, width, minValue, maxValue, step, onChange)
	local slider = CreateFrame("Frame", nil, parent)
	width = width or 180
	slider:SetSize(width, 18)
	slider.min, slider.max = tonumber(minValue) or 0, tonumber(maxValue) or 1
	if slider.max < slider.min then slider.min, slider.max = slider.max, slider.min end
	slider.step = tonumber(step) or 0
	slider.trackWidth = width - Theme.SLIDER_VALUE_WIDTH - 12

	slider.box = CreateFrame("Frame", nil, slider)
	slider.box:SetSize(Theme.SLIDER_VALUE_WIDTH, 18)
	slider.box:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
	slider.box.bg = Solid(slider.box, "BACKGROUND", Theme.FIELD, 1)
	slider.box.bg:SetAllPoints()
	slider.box.border = Border(slider.box, Theme.EDGE_SOFT, 1)
	slider.valueText = Text(slider.box, Theme.F_SMALL, Theme.LABEL)
	slider.valueText:SetPoint("CENTER", slider.box, "CENTER", 0, 0)

	-- zone sensible : toute la piste, plus haute que ses 3 px
	slider.hit = CreateFrame("Button", nil, slider)
	slider.hit:SetPoint("LEFT", slider, "LEFT", 0, 0)
	slider.hit:SetSize(slider.trackWidth, 18)
	slider.track = Solid(slider.hit, "BACKGROUND", Theme.CONTROL, 1)
	slider.track:SetPoint("LEFT", slider.hit, "LEFT", 0, 0)
	slider.track:SetSize(slider.trackWidth, 3)
	slider.fill = Solid(slider.hit, "ARTWORK", Theme.GOLD, 1)
	slider.fill:SetPoint("LEFT", slider.hit, "LEFT", 0, 0)
	slider.fill:SetSize(1, 3)
	slider.handle = Solid(slider.hit, "OVERLAY", Theme.GOLD, 1)
	slider.handle:SetSize(8, 12)

	-- valeur ramenée dans la plage, au cran près
	function slider:Snap(value)
		value = tonumber(value) or self.min
		if self.step > 0 then
			value = self.min + math.floor((value - self.min) / self.step + 0.5) * self.step
			-- arrondi flottant : 0.1 * 3 = 0.30000000000000004
			value = tonumber(string.format("%.6f", value))
		end
		return Clamp(value, self.min, self.max)
	end
	-- valeur sous un point de la piste (x en pixels depuis sa gauche)
	function slider:ValueAt(x)
		local ratio = Clamp((tonumber(x) or 0) / math.max(1, self.trackWidth), 0, 1)
		return self:Snap(self.min + ratio * (self.max - self.min))
	end
	function slider:SetValueText(text)
		self.valueOverride = text
		self.valueText:SetText(text or self:FormatValue(self.value))
	end
	function slider:FormatValue(value)
		if self.format then return self.format(value) end
		if value == math.floor(value) then return tostring(value) end
		return string.format("%.1f", value)
	end
	function slider:SetValue(value)
		self.value = self:Snap(value)
		local span = self.max - self.min
		local ratio = span > 0 and (self.value - self.min) / span or 0
		local x = math.floor(ratio * self.trackWidth + 0.5)
		self.fill:SetWidth(math.max(1, x))
		if x <= 0 then self.fill:Hide() else self.fill:Show() end
		self.handle:ClearAllPoints()
		self.handle:SetPoint("CENTER", self.hit, "LEFT", Clamp(x, 4, self.trackWidth - 4), 0)
		self.valueText:SetText(self.valueOverride or self:FormatValue(self.value))
		return self.value
	end
	function slider:GetValue() return self.value end
	-- action de l'utilisateur : rappel si la valeur change
	function slider:SetValueByUser(value)
		local before = self.value
		local after = self:SetValue(value)
		if after ~= before and onChange then onChange(after, self) end
		return after
	end

	local function CursorX(self)
		if type(GetCursorPosition) ~= "function" then return nil end
		local x = GetCursorPosition()
		local scale = (self.GetEffectiveScale and self:GetEffectiveScale()) or 1
		local left = self.hit.GetLeft and self.hit:GetLeft()
		if not (x and left) then return nil end
		return x / scale - left
	end
	slider.hit:SetScript("OnMouseDown", function()
		slider.dragging = true
		local x = CursorX(slider)
		if x then slider:SetValueByUser(slider:ValueAt(x)) end
	end)
	slider.hit:SetScript("OnMouseUp", function() slider.dragging = false end)
	slider.hit:SetScript("OnUpdate", function()
		if not slider.dragging then return end
		local x = CursorX(slider)
		if x then slider:SetValueByUser(slider:ValueAt(x)) end
	end)
	local function Wheel(_, delta)
		local stepSize = slider.step > 0 and slider.step or (slider.max - slider.min) / 20
		slider:SetValueByUser((slider.value or slider.min) + (delta > 0 and stepSize or -stepSize))
	end
	if slider.EnableMouseWheel then slider:EnableMouseWheel(true) end
	slider:SetScript("OnMouseWheel", Wheel)
	slider.hit:SetScript("OnMouseWheel", Wheel)
	slider:SetValue(slider.min)
	return slider
end

-- ---------------------------------------------------------------------------
-- Liste déroulante : case FIELD bordée EDGE, texte et chevron ; un clic
-- ouvre la liste des choix { value, label, disabled, hint }. Un choix
-- désactivé est grisé, avec son indice (« 30 brillantes »), et ne se choisit
-- pas. onSelect(valeur, choix) sur un choix de l'utilisateur.
-- ---------------------------------------------------------------------------
Theme.DROPDOWN_ROW = 22
function Theme.CreateDropdown(parent, width, onSelect)
	local dropdown = CreateFrame("Button", nil, parent)
	width = width or 160
	dropdown:SetSize(width, 22)
	dropdown.options = {}
	dropdown.bg = Solid(dropdown, "BACKGROUND", Theme.FIELD, 1)
	dropdown.bg:SetAllPoints()
	dropdown.border = Border(dropdown, Theme.EDGE, 1)
	dropdown.text = Text(dropdown, Theme.F_BODY, Theme.LABEL)
	dropdown.text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
	dropdown.text:SetPoint("RIGHT", dropdown, "RIGHT", -22, 0)
	dropdown.text:SetJustifyH("LEFT")
	dropdown.chevron = dropdown:CreateTexture(nil, "ARTWORK")
	dropdown.chevron:SetTexture(Theme.CHEVRON)
	dropdown.chevron:SetSize(12, 12)
	dropdown.chevron:SetPoint("RIGHT", dropdown, "RIGHT", -6, 0)
	dropdown.chevron:SetVertexColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3], 1)

	local list = CreateFrame("Frame", nil, dropdown)
	list:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
	list:SetWidth(width)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list.bg = Solid(list, "BACKGROUND", Theme.NAV, 0.98)
	list.bg:SetAllPoints()
	list.border = Border(list, Theme.EDGE, 1)
	list.rows = {}
	list:Hide()
	dropdown.list = list

	local function Entry(value)
		for _, entry in ipairs(dropdown.options) do
			if entry.value == value then return entry end
		end
		return nil
	end

	local function PaintRow(row)
		local entry = row.entry
		if not entry then return end
		local color = Theme.LABEL
		if entry.disabled then color = Theme.MUTED
		elseif entry.value == dropdown.value then color = Theme.GOLD end
		SetColor(row.label, color)
		if row.hovered and not entry.disabled then row.hover:Show() else row.hover:Hide() end
	end

	function dropdown:SetOptions(options)
		self.options = options or {}
		for _, row in ipairs(list.rows) do row:Hide(); row.entry = nil end
		for index, entry in ipairs(self.options) do
			local row = list.rows[index]
			if not row then
				row = CreateFrame("Button", nil, list)
				row:SetSize(width - 2, Theme.DROPDOWN_ROW)
				row.hover = Solid(row, "BACKGROUND", Theme.GOLD, 0.10)
				row.hover:SetAllPoints()
				row.hover:Hide()
				row.label = Text(row, Theme.F_BODY, Theme.LABEL)
				row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
				row.label:SetJustifyH("LEFT")
				row.hint = Text(row, Theme.F_SMALL, Theme.MUTED)
				row.hint:SetPoint("RIGHT", row, "RIGHT", -8, 0)
				row.hint:SetJustifyH("RIGHT")
				row:SetScript("OnClick", function(selfRow) dropdown:Choose(selfRow.entry and selfRow.entry.value) end)
				row:SetScript("OnEnter", function(selfRow) selfRow.hovered = true; PaintRow(selfRow) end)
				row:SetScript("OnLeave", function(selfRow) selfRow.hovered = false; PaintRow(selfRow) end)
				list.rows[index] = row
			end
			row.entry = entry
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -1 - (index - 1) * Theme.DROPDOWN_ROW)
			row.label:SetText(entry.label or tostring(entry.value))
			row.hint:SetText(entry.disabled and entry.hint or "")
			row:Show()
			PaintRow(row)
		end
		list:SetHeight(#self.options * Theme.DROPDOWN_ROW + 2)
		self:SetValue(self.value)
	end
	-- depuis le code : sans rappel, même pour un choix désactivé (état sauvegardé)
	function dropdown:SetValue(value)
		self.value = value
		local entry = Entry(value)
		self.text:SetText(entry and (entry.label or tostring(entry.value)) or "")
		for _, row in ipairs(list.rows) do PaintRow(row) end
	end
	function dropdown:GetValue() return self.value end
	-- choix de l'utilisateur : refusé s'il est désactivé
	function dropdown:Choose(value)
		local entry = Entry(value)
		if not entry or entry.disabled then return false end
		self:SetValue(value)
		self:Close()
		if onSelect then onSelect(value, entry) end
		return true
	end
	function dropdown:Open() list:Show(); self.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1) end
	function dropdown:Close() list:Hide(); self.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1) end
	function dropdown:IsOpen() return list:IsShown() and true or false end
	dropdown:SetScript("OnClick", function(self) if self:IsOpen() then self:Close() else self:Open() end end)
	dropdown:SetScript("OnHide", function(self) self:Close() end)
	return dropdown
end

-- Nuancier : carré bordé, rempli de la couleur
function Theme.CreateSwatch(parent, size)
	local swatch = CreateFrame("Button", nil, parent)
	size = size or 15
	swatch:SetSize(size, size)
	swatch.border = Border(swatch, Theme.EDGE, 1)
	swatch.color = Solid(swatch, "ARTWORK", Theme.GOLD, 1)
	swatch.color:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
	swatch.color:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)
	function swatch:SetColor(r, g, b, a)
		self.rgba = { r, g, b, a or 1 }
		self.color:SetVertexColor(r, g, b, a or 1)
	end
	swatch:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	return swatch
end

-- Verrou : case en pointillés, texte pâle (« 30 brillantes ») pour ce qui
-- n'est pas encore gagné. Les pointillés sont des tirets de 3 px.
function Theme.CreateLockTag(parent, text)
	local tag = CreateFrame("Frame", nil, parent)
	tag.dashes = {}
	tag.label = Text(tag, Theme.F_SMALL, Theme.MUTED)
	tag.label:SetPoint("CENTER", tag, "CENTER", 0, 0)
	local DASH, GAP = 3, 2
	local function Dash(index)
		local dash = tag.dashes[index]
		if not dash then
			dash = Solid(tag, "BORDER", Theme.EDGE, 1)
			tag.dashes[index] = dash
		end
		dash:ClearAllPoints()
		dash:Show()
		return dash
	end
	function tag:SetText(value)
		self.label:SetText(value or "")
		local w = math.floor(((self.label.GetStringWidth and self.label:GetStringWidth()) or 40) + 16 + 0.5)
		local h = 18
		self:SetSize(w, h)
		local count = 0
		for x = 0, w - 1, DASH + GAP do
			local len = math.min(DASH, w - x)
			count = count + 1
			local top = Dash(count); top:SetPoint("TOPLEFT", self, "TOPLEFT", x, 0); top:SetSize(len, 1)
			count = count + 1
			local bottom = Dash(count); bottom:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, 0); bottom:SetSize(len, 1)
		end
		for y = 0, h - 1, DASH + GAP do
			local len = math.min(DASH, h - y)
			count = count + 1
			local left = Dash(count); left:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y); left:SetSize(1, len)
			count = count + 1
			local right = Dash(count); right:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y); right:SetSize(1, len)
		end
		for index = count + 1, #self.dashes do self.dashes[index]:Hide() end
	end
	tag:SetText(text)
	return tag
end

-- Apparition : fondu de 0,15 s (AnimationGroup), si le client le propose
function Theme.FadeIn(frame, duration)
	if not frame or not frame.CreateAnimationGroup then return false end
	if not frame.fadeIn then
		local ok, group = pcall(frame.CreateAnimationGroup, frame)
		if not ok or not group then return false end
		local alpha = group:CreateAnimation("Alpha")
		if alpha.SetFromAlpha then alpha:SetFromAlpha(0); alpha:SetToAlpha(1) end
		alpha:SetDuration(duration or 0.15)
		frame.fadeIn = group
	end
	frame.fadeIn:Stop()
	frame.fadeIn:Play()
	return true
end

-- ---------------------------------------------------------------------------
-- Cadre discret : pas de titre, pas de bouton, un simple filet doré 1 px
-- sur fond noir translucide. Pour les affichages flottants permanents.
-- ---------------------------------------------------------------------------
function Theme.CreateDiscreet(parent, width, height)
	local ok, frame = pcall(CreateFrame, "Frame", nil, parent)
	if not ok or not frame then
		frame = CreateFrame("Frame", nil, parent)
	end
	if not frame then return nil end

	frame:SetSize(width, height)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(false)
	frame:SetMovable(true)
	if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
	-- Sans OnDragStart, RegisterForDrag ne fait STRICTEMENT rien.
	if frame.StartMoving then frame:SetScript("OnDragStart", frame.StartMoving) end
	if frame.StopMovingOrSizing then frame:SetScript("OnDragStop", frame.StopMovingOrSizing) end

	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetTexture(Theme.SOLID)
	frame.bg:SetVertexColor(0, 0, 0, 0.66)
	frame.bg:SetAllPoints()

	local function Edge()
		local edge = frame:CreateTexture(nil, "BORDER")
		edge:SetTexture(Theme.SOLID)
		edge:SetVertexColor(Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3], 0.45)
		return edge
	end

	frame.top = Edge()
	frame.top:SetPoint("TOPLEFT")
	frame.top:SetPoint("TOPRIGHT")
	frame.top:SetHeight(1)

	frame.bottom = Edge()
	frame.bottom:SetPoint("BOTTOMLEFT")
	frame.bottom:SetPoint("BOTTOMRIGHT")
	frame.bottom:SetHeight(1)

	frame.leftEdge = Edge()
	frame.leftEdge:SetPoint("TOPLEFT")
	frame.leftEdge:SetPoint("BOTTOMLEFT")
	frame.leftEdge:SetWidth(1)

	frame.rightEdge = Edge()
	frame.rightEdge:SetPoint("TOPRIGHT")
	frame.rightEdge:SetPoint("BOTTOMRIGHT")
	frame.rightEdge:SetWidth(1)

	frame.contentTop = 0
	return frame
end

-- Losange de statut / puce : plein (échec, alerte, puce) ou au trait (OK)
function Theme.CreateDiamond(parent, size, outline)
	local tex = parent:CreateTexture(nil, "OVERLAY")
	tex:SetTexture(outline and Theme.DIAMOND_LINE or Theme.DIAMOND)
	tex:SetSize(size or 10, size or 10)
	return tex
end

-- ---------------------------------------------------------------------------
-- Icône d'objet / de sort avec liseré coloré
-- ---------------------------------------------------------------------------
function Theme.QualityColor(quality)
	local colors = ITEM_QUALITY_COLORS
	if colors and colors[quality] then
		local c = colors[quality]
		return c.r, c.g, c.b
	end
	return 1, 1, 1
end

function Theme.CreateIcon(parent, size, texture, quality)
	local icon = CreateFrame("Frame", nil, parent)
	icon:SetSize(size, size)

	icon.tex = icon:CreateTexture(nil, "ARTWORK")
	icon.tex:SetPoint("TOPLEFT", 1, -1)
	icon.tex:SetPoint("BOTTOMRIGHT", -1, 1)
	icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- Liseré en quatre traits : fonctionne quelle que soit la taille
	local function Edge()
		local line = icon:CreateTexture(nil, "OVERLAY")
		line:SetTexture(Theme.SOLID)
		return line
	end

	icon.top = Edge()
	icon.top:SetPoint("TOPLEFT")
	icon.top:SetPoint("TOPRIGHT")
	icon.top:SetHeight(1)

	icon.bottom = Edge()
	icon.bottom:SetPoint("BOTTOMLEFT")
	icon.bottom:SetPoint("BOTTOMRIGHT")
	icon.bottom:SetHeight(1)

	icon.left = Edge()
	icon.left:SetPoint("TOPLEFT")
	icon.left:SetPoint("BOTTOMLEFT")
	icon.left:SetWidth(1)

	icon.right = Edge()
	icon.right:SetPoint("TOPRIGHT")
	icon.right:SetPoint("BOTTOMRIGHT")
	icon.right:SetWidth(1)

	function icon:SetItem(texturePath, itemQuality)
		self.tex:SetTexture(texturePath or "Interface\\Icons\\INV_Misc_QuestionMark")
		local r, g, b = Theme.QualityColor(itemQuality or 1)
		for _, edge in ipairs({ self.top, self.bottom, self.left, self.right }) do
			edge:SetVertexColor(r, g, b, 0.95)
		end
	end

	icon:SetItem(texture, quality)
	return icon
end

-- Couleur d'une barre selon le ratio
-- Barème unique de la note (fenêtre, verdict, chat, minicarte, icône) :
--   85 et plus : vert (prêt) ; 60-84 : ambre (prêt avec réserves) ;
--   25-59 : orange (pas prêt) ; 0-24 : rouge (pas prêt du tout)
function Theme.ScoreColor(ratio)
	if ratio >= 0.85 then return Theme.GREEN end
	if ratio >= 0.60 then return Theme.ORANGE end
	if ratio >= 0.25 then return Theme.ORANGE_DEEP end
	return Theme.RED
end

-- Même barème, en code couleur de texte (« |cff… »)
function Theme.ScoreTextColor(ratio)
	if ratio >= 0.85 then return Theme.T_GREEN end
	if ratio >= 0.60 then return Theme.T_ORANGE end
	if ratio >= 0.25 then return Theme.T_ORANGE_DEEP end
	return Theme.T_RED
end

if ns.Mark then ns.Mark("Theme") end
