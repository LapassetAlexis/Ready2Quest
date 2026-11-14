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
-- Textures : la police Inter du socle (Libs/Socle/Media) et le logo de
-- chaque addon (Textures/logo.tga, logo_petit.tga). Socle 2.12.1 : plus
-- aucune image du socle ; pictos du client par référence (Theme.CLIENT_ART),
-- aplats en Interface\Buttons\WHITE8X8, teinté.
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
-- socle 2.11.0 : corps du fichier dans une fabrique, compilée une fois quand
-- les deux addons ont le même socle (Base.lua, ns.SocleFile). Rien de propre
-- à l'addon au niveau du fichier : tout passe par ADDON et ns, ci-dessous.
local SOCLE_ADDON, SOCLE_NS = ...
;(SOCLE_NS.SocleFile or function(_, factory) return factory end)("Theme", function(...)
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
-- socle 2.11.0 : MUTED éclairci d'un cran (#7d8389 -> #91969e) : 4,20:1 sur
-- ROW_ALT avant, 5,49 après ; ≥ 4,5 aussi sur les fonds survolés (n° 7)
Theme.MUTED     = { 0.57, 0.59, 0.62 }   -- texte secondaire #91969e
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
Theme.WHITE     = { 1, 1, 1 }
-- socle 2.11.2 / 1.32.2 (fiche 28) : ombre noire et ses voiles, or d'une
-- brillante (#ffe27a arrondi, déjà la valeur du carnet et des effets)
Theme.SHADOW    = { 0, 0, 0 }
Theme.SHADE     = { soft = 0.25, mid = 0.45, veil = 0.66, strong = 0.8 }
Theme.SHINY     = { 1, 0.89, 0.48 }

-- socle 2.11.0 : états des contrôles (docs/UI.md, « États »)
Theme.HOVER_ALPHA = 0.06   -- voile blanc d'une carte ou d'une ligne survolée (1,18 × la luminance du fond)
Theme.DIM_ALPHA   = 0.45   -- élément inactif (bouton désactivé, carte d'un module coupé)
Theme.PRESS_SHADE = 0.10   -- bouton plein enfoncé : part d'encre mêlée au fond (0,15 de la fiche
                           -- faisait tomber l'encre à 4,41:1 sur le bleu ; 0,10 : 4,81)
-- socle 3.0 (QuestCompanion 3.0.0) : composants canoniques (docs/UI.md, « Composants 3.0 »).
-- Une rangée d'outils (puces, listes déroulantes, recherche, bouton « sm ») a
-- une seule hauteur ; les boutons ont trois tailles nommées ; un bouton
-- désactivé n'est plus estompé (le libellé tombait sous 2:1) : fond CONTROL,
-- filet EDGE_SOFT, libellé MUTED, tous opaques (4,5:1 sur CONTROL).
Theme.CONTROL_HEIGHT = 24
-- socle 3.2 : deux jetons de plus, que le thème change (Theme.ApplySkin) :
-- l'encre des titres de fenêtre et l'accent de l'état actif (onglet, entrée
-- de navigation, pastille ou ligne sélectionnés)
Theme.TITLE     = { 0.95, 0.91, 0.83 }   -- = PARCHMENT en Sobre
Theme.ACTIVE    = { 0.91, 0.65, 0.29 }   -- = GOLD en Sobre
Theme.BUTTON_SIZES = { xs = 18, sm = 24, md = 28 }
Theme.DISABLED = { bg = Theme.CONTROL, edge = Theme.EDGE_SOFT, text = Theme.MUTED }

-- socle 2.11.0 : contraste mesuré (formule WCAG 2.x), partagé par les deux
-- addons et par les tests (tests/modules/socle_211.lua, socle_contrast).
-- Theme.Luminance({ r, g, b }) : luminance relative ; Theme.Contrast(a, b) :
-- rapport de contraste entre deux couleurs { r, g, b } (1 à 21).
local function Channel(value)
	value = tonumber(value) or 0
	if value <= 0.03928 then return value / 12.92 end
	return ((value + 0.055) / 1.055) ^ 2.4
end
function Theme.Luminance(color)
	return 0.2126 * Channel(color[1]) + 0.7152 * Channel(color[2]) + 0.0722 * Channel(color[3])
end
-- `b` : une couleur, ou directement une luminance (nombre)
function Theme.Contrast(a, b)
	local la = Theme.Luminance(a)
	local lb = type(b) == "table" and Theme.Luminance(b) or (tonumber(b) or 0)
	if la < lb then la, lb = lb, la end
	return (la + 0.05) / (lb + 0.05)
end
-- couleur vue quand un aplat `color` à `alpha` couvre `base` (mélange sRGB,
-- comme le moteur) : survols, voiles, boutons enfoncés
function Theme.Over(base, color, alpha)
	alpha = tonumber(alpha) or 0
	return { base[1] + (color[1] - base[1]) * alpha, base[2] + (color[2] - base[2]) * alpha,
		base[3] + (color[3] - base[3]) * alpha }
end

-- socle 2.11.0 : rareté d'une créature, un seul jeton (docs/UI.md). La
-- convention des qualités d'objet du jeu (élite = bleu « rare », rare =
-- violet « épique », boss = orange « légendaire »), éclaircie pour du texte
-- sur fond sombre. Mesures (WCAG) : élite 6,33 / rare 6,31 sur ROW, 5,99 /
-- 5,98 sur ROW_ALT ; toutes ≥ 4,5 sur ROW, ROW_ALT, WINDOW, NAV, FIELD.
-- Sur parchemin, les encres sombres r* (QuestCompanion, AZEROTH_INK) sont
-- choisies par la même clé, Theme.RankKey.
-- API stable : Theme.RANK[clé], Theme.RANK_KEYS[classification du jeu],
-- Theme.RankKey(classification), Theme.RankColor(classification, brillante).
Theme.RANK = {
	trivial = { 0.62, 0.62, 0.62 },
	normal  = Theme.PARCHMENT,
	elite   = { 0.40, 0.62, 0.95 },   -- #669ef2
	rare    = { 0.75, 0.50, 1.00 },   -- #bf80ff
	boss    = { 1.00, 0.50, 0.00 },   -- #ff8000
	shiny   = Theme.GOLD_LIGHT,       -- #f6c77d
}
-- classification renvoyée par UnitClassification -> clé de Theme.RANK
Theme.RANK_KEYS = { trivial = "trivial", minus = "trivial", normal = "normal", elite = "elite",
	rare = "rare", rareelite = "rare", worldboss = "boss", boss = "boss" }

function Theme.RankKey(class)
	return Theme.RANK_KEYS[class or "normal"] or "normal"
end

function Theme.RankColor(class, shiny)
	if shiny then return Theme.RANK.shiny end
	return Theme.RANK[Theme.RankKey(class)]
end

-- code couleur « |cffrrggbb » d'une couleur { r, g, b } (texte coloré)
function Theme.Hex(color)
	local function Byte(v) return math.floor(math.max(0, math.min(1, tonumber(v) or 0)) * 255 + 0.5) end
	return string.format("|cff%02x%02x%02x", Byte(color[1]), Byte(color[2]), Byte(color[3]))
end

-- 2.11.0 / 1.32.0 (fiche 28) : alias des codes déclarés une fois dans Base.lua (ns.TC)
local TC = ns.TC or setmetatable({}, { __index = function() return "" end })   -- hors Base.lua (tests) : sans couleur
Theme.T_GOLD      = TC.GOLD
Theme.T_PARCHMENT = TC.PARCHMENT
Theme.T_GREY      = TC.GREY
Theme.T_GREEN     = TC.GREEN
Theme.T_RED       = TC.RED
Theme.T_ORANGE    = TC.ORANGE
Theme.T_ORANGE_DEEP = TC.ORANGE_DEEP
Theme.T_WHITE     = TC.WHITE
Theme.T_BLUE      = TC.BLUE

Theme.BG_DARK  = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
Theme.BG_LIGHT = "Interface\\DialogFrame\\UI-DialogBox-Background"
Theme.SOLID    = "Interface\\Buttons\\WHITE8X8"
Theme.LOGO          = MEDIA .. "Textures\\logo"         -- logo de l'addon (boussole R2Q, dragonnet QC)
Theme.LOGO_SMALL    = MEDIA .. "Textures\\logo_petit"   -- petites tailles : bandeaux, liste des addons
Theme.LOGO_GLYPH    = MEDIA .. "Textures\\logo_glyphe"  -- le glyphe sans anneau : bouton de la mini-carte
-- socle 2.12.1 : la coche du client (fichier), repli de la case « checkmark-minimal »
-- et de l'interrupteur de module quand l'atlas de la case manque
Theme.CHECK_FILE    = "Interface\\Buttons\\UI-CheckBox-Check"
Theme.POWER         = Theme.CHECK_FILE
-- losange du client en repli (le marqueur de raid « losange », grisé, teinté)
Theme.DIAMOND_FILE  = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3"
-- Flèche de rafraîchissement : l'icône du jeu (fichier 851904), présente dans
-- les clients Era 1.15.9 et Forever 1.60.1 (listes de fichiers wago.tools).
-- Elle est jaune : on la désature au repos plutôt que de la teinter.
Theme.REFRESH       = "Interface\\Buttons\\UI-RefreshButton"

-- socle 2.11.0 : pictos du client par référence (atlas vérifiés en jeu sur
-- Forever 1.60, 2026-11-09), jamais embarqués. Chaque rôle essaie ses atlas
-- dans l'ordre, après une vérification à l'exécution (C_Texture.GetAtlasInfo
-- connaît le nom ET SetAtlas l'accepte) ; sinon un fichier du client (repli),
-- jamais un fichier à nous (socle 2.12.1 : les images du socle sont parties).
-- Theme.PaintClient(tex, rôle) rend le nom de l'atlas posé, ou "fallback".
-- `tint` : l'image est désaturée pour prendre la teinte du jeton (statuts).
Theme.CLIENT_ART = {
	diamond     = { atlases = { "activities-complete-diamond", "genericwidgetbar-marker-diamond" }, fallback = Theme.DIAMOND_FILE, tint = true },
	diamondLine = { atlases = { "activities-incomplete-diamond" }, fallback = Theme.DIAMOND_FILE, tint = true },
	chevron     = { atlases = { "friendslist-categorybutton-arrow-down" } },
	gear        = { atlases = { "questlog-icon-setting", "gm-icon-settings" }, fallback = "Interface\\Buttons\\UI-OptionsButton" },
	checkbox    = { atlases = { "checkbox-minimal" } },
	-- « checkmark-minimal » pas encore vu en jeu : la coche du client en repli
	checkmark   = { atlases = { "checkmark-minimal" }, fallback = Theme.CHECK_FILE },
	partial     = { atlases = { "common-checkbox-partial" } },
}
-- atlas connu du client : réponse gardée (une seule question par nom)
-- (la réponse est oubliée si la table C_Texture change : banc de tests)
local atlasKnown, atlasApi = {}, nil
function Theme.HasAtlas(name)
	local api = rawget(_G, "C_Texture")
	if api ~= atlasApi then atlasApi = api; Theme.ResetAtlasCache() end
	local known = atlasKnown[name]
	if known ~= nil then return known end
	if type(api) ~= "table" or type(api.GetAtlasInfo) ~= "function" then return false end
	local ok, info = pcall(api.GetAtlasInfo, name)
	known = (ok and info ~= nil) and true or false
	atlasKnown[name] = known
	return known
end
-- oublie les réponses gardées (tests : C_Texture posé ou retiré)
function Theme.ResetAtlasCache() for name in pairs(atlasKnown) do atlasKnown[name] = nil end end

function Theme.PaintClient(tex, role)
	local spec = type(role) == "table" and role or Theme.CLIENT_ART[role]
	if not (tex and spec) then return nil end
	-- socle 2.12.1 : le rôle posé, lisible (losange plein ou au trait)
	tex.clientRole = type(role) == "string" and role or nil
	if tex.SetAtlas then
		for _, name in ipairs(spec.atlases or {}) do
			if Theme.HasAtlas(name) then
				local ok, result = pcall(tex.SetAtlas, tex, name)
				if ok and result ~= false then
					if tex.SetDesaturated then tex:SetDesaturated(spec.tint and true or false) end
					tex.clientSource = name
					return name
				end
			end
		end
	end
	if not spec.fallback then tex.clientSource = nil; return nil end
	tex:SetTexture(spec.fallback)
	if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
	-- `fallbackTint` : seul le fichier de repli est grisé (socle 2.12.1)
	if tex.SetDesaturated then tex:SetDesaturated((spec.tint or spec.fallbackTint) and true or false) end
	tex.clientSource = "fallback"
	return "fallback"
end

-- Losange de statut ou de puce : plein (à voir) ou au trait (bon, neutre)
function Theme.SetDiamond(tex, outline)
	return Theme.PaintClient(tex, outline and "diamondLine" or "diamond")
end

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
			-- certains clients ne rendent rien : on relit la police réellement posée
			if ok and applied == nil and type(font.GetFont) == "function" then
				local got, path = pcall(font.GetFont, font)
				applied = got and type(path) == "string" and path ~= ""
			end
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
-- socle 2.11.0 : vraie flèche « → » si Inter est chargée ; socle 1.32.2 :
-- la police réellement utilisée n'a pas toujours la flèche (carré « glyphe
-- manquant » en jeu). Toujours de l'ASCII ; dans une phrase, préférer des mots.
Theme.ARROW = "->"

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

-- socle 2.11.2 / 1.32.2 (fiche 28) : ombre noire d'un texte clair, décalée de
-- (1, dy) (dy : -1 par défaut, -2 sous les grands titres), opaque par défaut
function Theme.TextShadow(fontString, alpha, dy)
	if not fontString then return end
	if fontString.SetShadowColor then fontString:SetShadowColor(0, 0, 0, alpha or 1) end
	if fontString.SetShadowOffset then fontString:SetShadowOffset(1, dy or -1) end
end

-- Teinte noire d'une texture (liseré, ombre portée), au voile alpha
-- (Theme.SHADE.strong par défaut)
function Theme.Shade(texture, alpha)
	if texture and texture.SetVertexColor then
		texture:SetVertexColor(Theme.SHADOW[1], Theme.SHADOW[2], Theme.SHADOW[3], alpha or Theme.SHADE.strong)
	end
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
	if ok and applied == nil and type(fontString.GetFont) == "function" then
		local got, path = pcall(fontString.GetFont, fontString)
		applied = got and type(path) == "string" and path ~= ""
	end
	fontString.titleFont = ok and applied ~= false
	return fontString.titleFont
end

function Theme.CreateTitle(parent, size, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", Theme.F_TITLE)
	Theme.TitleFont(fs, size)
	fs:SetTextColor(Theme.TITLE[1], Theme.TITLE[2], Theme.TITLE[3])
	return fs
end

-- Texte dans un rôle de police, avec sa couleur
local function Text(parent, font, color, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", font)
	if color then SetColor(fs, color) end
	return fs
end
Theme.Text = Text

-- Bordure 1 px sur les quatre côtés (de `around`, une région du cadre, ou
-- du cadre lui-même)
local function Border(frame, color, alpha, layer, around)
	local edges = {}
	for _, side in ipairs({ "top", "bottom", "left", "right" }) do
		edges[side] = Solid(frame, layer or "BORDER", color, alpha)
	end
	local a = around or frame
	edges.top:SetPoint("TOPLEFT", a, "TOPLEFT"); edges.top:SetPoint("TOPRIGHT", a, "TOPRIGHT"); edges.top:SetHeight(1)
	edges.bottom:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT"); edges.bottom:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT"); edges.bottom:SetHeight(1)
	edges.left:SetPoint("TOPLEFT", a, "TOPLEFT"); edges.left:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT"); edges.left:SetWidth(1)
	edges.right:SetPoint("TOPRIGHT", a, "TOPRIGHT"); edges.right:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT"); edges.right:SetWidth(1)
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

-- socle 3.1 : retour d'appui des petits boutons dessinés ([×], bouton-icône,
-- roue crantée), comme Theme.CreateButton : le contenu (`region`, centré)
-- s'enfonce d'un pixel, le filet passe à l'ambre sombre ; au relâché, le
-- survol revient si la souris est encore dessus (sinon le repos). Un bouton
-- désactivé ne bouge pas. Pose OnMouseDown / OnMouseUp (libres sur ces
-- boutons).
function Theme.PressFeedback(button, region)
	if not (button and region and button.SetScript) then return end
	local function Enabled(self)
		if not self.IsEnabled then return true end
		local ok, on = pcall(self.IsEnabled, self)
		return not ok or (on ~= false and on ~= nil and on ~= 0)
	end
	-- les ancres du contenu, relues à l'appui (un module a pu les changer) :
	-- décalées de 1, -1 puis remises telles quelles
	local saved = {}
	local function Anchors()
		for i = #saved, 1, -1 do saved[i] = nil end
		local count = region.GetNumPoints and tonumber(region:GetNumPoints()) or 1
		for i = 1, math.max(1, count) do
			local point, relTo, relPoint, x, y = region:GetPoint(i)
			if point then saved[#saved + 1] = { point, relTo or button, relPoint or point, tonumber(x) or 0, tonumber(y) or 0 } end
		end
	end
	local function Place(dx, dy)
		if #saved == 0 then return end
		region:ClearAllPoints()
		for _, p in ipairs(saved) do region:SetPoint(p[1], p[2], p[3], p[4] + dx, p[5] + dy) end
	end
	button:SetScript("OnMouseDown", function(self, mouse)
		if (mouse and mouse ~= "LeftButton") or not Enabled(self) or self.pressed then return end
		self.pressed = true
		Anchors()
		Place(1, -1)
		if self.border and self.border.SetColor then
			self.border:SetColor(Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3], 1)
		end
		-- socle 3.2 : thème forgé, la petite plaque s'assombrit
		if self.forgeLook then self.forgeLook(self, "pressed") end
	end)
	button:SetScript("OnMouseUp", function(self)
		if not self.pressed then return end
		self.pressed = nil
		Place(0, 0)
		local over = false
		if self.IsMouseOver then
			local ok, value = pcall(self.IsMouseOver, self)
			over = ok and value and true or false
		end
		local script = self:GetScript(over and "OnEnter" or "OnLeave")
		if script then script(self) end
	end)
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
	-- socle 3.2 : thème forgé, petite plaque ; « × » or clair au survol
	if Theme.Forged() then
		Theme.ForgeSmallPlate(close)
	end
	close:SetScript("OnEnter", function()
		close.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		SetColor(close.label, close.forgeLook and Theme.GOLD_LIGHT or Theme.PARCHMENT)
		if close.forgeLook then close.forgeLook(close, "hover") end
	end)
	close:SetScript("OnLeave", function()
		close.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1)
		SetColor(close.label, Theme.MUTED_LIGHT)
		if close.forgeLook then close.forgeLook(close, "rest") end
	end)
	-- socle 3.1 : appui comme un bouton au trait (filet ambre sombre, « × »
	-- enfoncé d'un pixel), relâché : survol ou repos
	Theme.PressFeedback(close, close.label)
	close:SetScript("OnClick", function() frame:Hide() end)
	return close
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
	-- thème : l'habillage forgé se pose (ou s'ôte) à chaque affichage, et dès la
	-- création (une fenêtre née affichée ne reçoit pas OnShow).
	-- opts.chrome = false : jamais (fenêtre qui s'habille elle-même) ;
	-- opts.emblem : le médaillon du logo déborde du coin haut gauche.
	frame.wantsEmblem = opts.emblem and true or nil
	if opts.chrome ~= false and opts.wood ~= false then
		if frame.HookScript then pcall(frame.HookScript, frame, "OnShow", Theme.DressWindow) end
		pcall(Theme.DressWindow, frame)
	else
		frame.skinNoChrome = true
	end
	return frame
end

-- Filet ambre lumineux : transparent -> ambre -> ambre clair -> transparent,
-- avec un halo plus large et très pâle dessous. Retourne { segments, glow }.
-- Thème forgé : une seule texture, notre filet lumineux (ART.line, or ou
-- `tone` = "arcane") qui s'éteint vers la droite ; .segments = { ce filet }
-- (ceux qui cachent les segments le cachent), pas de halo à part.
function Theme.CreateGlowRule(parent, height, tone)
	local rule = { segments = {}, glow = {} }
	height = height or 2
	if Theme.ForgeHere("CreateGlowRule") then
		local K = Theme.FORGE_RULE
		local c = (Theme.FORGE_TONES[tone] or Theme.FORGE_TONES.gold).light
		local line = Theme.ArtTexture(parent, "line", "ARTWORK", 0, c, K.alpha)
		line.from, line.to = 0, 1
		rule.segments[1], rule.forgeLine, rule.forged = line, line, true
		function rule:Place(left, y, width)
			line:ClearAllPoints()
			line:SetPoint("TOPLEFT", parent, "TOPLEFT", left, y + K.lift)
			line:SetSize(math.max(1, math.floor(width + 0.5)), K.height)
		end
		return rule
	end
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
-- En-tête compact (fenêtres des modules) : logo, titre F_TITLE, sous-titre
-- F_BODY dessous, filet ambre ; le grand chiffre de la fenêtre garde F_DISPLAY.
Theme.HEADER_COMPACT_HEIGHT = 64
-- opts.compact : en-tête compact ; opts.logo : texture du logo (compact
-- seulement, Theme.LOGO_SMALL par défaut, false = sans logo) ; opts.pad :
-- marge gauche et droite (24 en grand, 20 en compact)
function Theme.CreatePageHeader(parent, width, opts)
	opts = opts or {}
	local header = CreateFrame("Frame", nil, parent)
	width = width or (parent.GetWidth and parent:GetWidth()) or 600
	local compact = opts.compact and true or false
	local height = compact and Theme.HEADER_COMPACT_HEIGHT or Theme.HEADER_HEIGHT
	local pad = tonumber(opts.pad) or (compact and 20 or 24)
	header:SetSize(width, height)
	header.compact = compact

	local glowHeight = compact and height or 72
	header.topGlow = header:CreateTexture(nil, "BACKGROUND")
	header.topGlow:SetTexture(Theme.SOLID)
	header.topGlow:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
	header.topGlow:SetSize(width, glowHeight)
	Gradient(header.topGlow, "VERTICAL", Theme.GOLD, 0, Theme.GOLD, 0.06)
	-- coin haut gauche un peu plus chaud
	header.cornerGlow = header:CreateTexture(nil, "BACKGROUND")
	header.cornerGlow:SetTexture(Theme.SOLID)
	header.cornerGlow:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
	header.cornerGlow:SetSize(math.floor(width * 0.45), glowHeight)
	Gradient(header.cornerGlow, "HORIZONTAL", Theme.GOLD, 0.05, Theme.GOLD, 0)

	local left = pad
	if compact and opts.logo ~= false and opts.emblem then
		-- thème forgé : le médaillon de la fenêtre (Theme.DressWindow) tient lieu de logo
		left = Theme.EMBLEM.text
	elseif compact and opts.logo ~= false then
		header.logo = header:CreateTexture(nil, "ARTWORK")
		header.logo:SetTexture(opts.logo or Theme.LOGO_SMALL)
		header.logo:SetSize(28, 28)
		header.logo:SetPoint("TOPLEFT", header, "TOPLEFT", pad, -14)
		left = pad + 28 + 10
	end
	header.textLeft = left

	-- thème Azeroth : la plaque de titre (bois sombre) sous l'en-tête
	if Theme.skin == "azeroth" then
		header.plate = Solid(header, "BACKGROUND", Theme.NAV, 1)
		header.plate:SetAllPoints()
		if header.plate.SetDrawLayer then header.plate:SetDrawLayer("BACKGROUND", 1) end
		-- forgé : le bois prend un haut plus chaud (dégradé vers le bas) ; la
		-- lueur ambre du haut et du coin reste par-dessus
		if Theme.ForgeHere("CreatePageHeader") then
			local K = Theme.FORGE_HEADER
			Gradient(header.plate, "VERTICAL", Theme.NAV, K.bottom, K.warm, K.top)
			for _, key in ipairs({ "topGlow", "cornerGlow" }) do
				if header[key].SetDrawLayer then header[key]:SetDrawLayer("BACKGROUND", 2) end
			end
			header.forged = true
		end
	end
	header.title = Text(header, compact and Theme.F_TITLE or Theme.F_DISPLAY, Theme.TITLE)
	header.title:SetPoint("TOPLEFT", header, "TOPLEFT", left, compact and -14 or -22)
	header.title:SetJustifyH("LEFT")
	header.title:SetText("")

	header.subtitle = Text(header, Theme.F_BODY, Theme.MUTED_LIGHT)
	header.subtitle:SetPoint("TOPLEFT", header, "TOPLEFT", left, compact and -35 or -60)
	header.subtitle:SetJustifyH("LEFT")
	header.subtitle:SetText("")

	header.rule = Theme.CreateGlowRule(header, 2)
	header.rule:Place(pad, compact and -56 or -86, width - 2 * pad)

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
	brand.name = Text(brand, Theme.F_TITLE, Theme.TITLE)
	if Theme.Forged() then
		-- thème forgé : le médaillon de la fenêtre tient lieu de logo de la marque
		brand.logo:Hide()
		brand.name:SetPoint("LEFT", brand, "LEFT", Theme.EMBLEM.text - 2, 2)
	else
		brand.name:SetPoint("LEFT", brand.logo, "RIGHT", 10, 0)
	end
	brand.name:SetJustifyH("LEFT")
	brand.name:SetText(name or "")
	if Theme.ForgeHere("CreateNavBrand") then
		-- forgé : notre filet lumineux, qui s'éteint vers la droite
		local K = Theme.FORGE_RULE
		brand.rule = Theme.ArtTexture(brand, "line", "ARTWORK", 0, Theme.GOLD_LIGHT, K.alpha)
		brand.rule:SetPoint("BOTTOMLEFT", brand, "BOTTOMLEFT", 16, -K.lift)
		brand.rule:SetPoint("BOTTOMRIGHT", brand, "BOTTOMRIGHT", -16, -K.lift)
		brand.rule:SetHeight(K.height)
		return brand
	end
	brand.rule = Solid(brand, "ARTWORK", Theme.GOLD, 1)
	brand.rule:SetPoint("BOTTOMLEFT", brand, "BOTTOMLEFT", 16, 0)
	brand.rule:SetPoint("BOTTOMRIGHT", brand, "BOTTOMRIGHT", -16, 0)
	brand.rule:SetHeight(1)
	Gradient(brand.rule, "HORIZONTAL", Theme.GOLD, 0.9, Theme.GOLD, 0)
	return brand
end

-- Titre de groupe : ambre, F_CAPS, en capitales.
-- Thème forgé : une « pilule » derrière le titre (dégradé de son ton vers la
-- droite, filet, reflet d'un pixel), du bord gauche du titre au bord droit
-- du parent ; `tone` : "gold" (par défaut) ou "arcane". label.toneInk : son
-- encre (le module la reprend quand il recolore le titre).
function Theme.CreateNavGroup(parent, text, tone)
	local label = Text(parent, Theme.F_CAPS, Theme.GOLD)
	label:SetJustifyH("LEFT")
	label:SetText(Theme.Upper(text))
	if Theme.ForgeHere("CreateNavGroup") and parent.CreateTexture then
		local K = Theme.FORGE_NAV.pill
		local spec = Theme.FORGE_TONES[tone] or Theme.FORGE_TONES.gold
		label.tone, label.toneInk = Theme.FORGE_TONES[tone] and tone or "gold", spec.light
		SetColor(label, spec.light)
		local pill = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
		pill:SetTexture(Theme.SOLID)
		pill:SetPoint("TOPLEFT", label, "TOPLEFT", -K.padX, K.padY)
		pill:SetPoint("BOTTOMLEFT", label, "BOTTOMLEFT", -K.padX, -K.padY)
		pill:SetPoint("RIGHT", parent, "RIGHT", -K.right, 0)
		Gradient(pill, "HORIZONTAL", spec.color, K.from, spec.color, K.to)
		label.forgePill = pill
		label.forgePillEdge = Border(parent, spec.color, K.edge, "BORDER", pill)
		label.forgePillSheen = Solid(parent, "BORDER", Theme.WHITE, K.sheen)
		label.forgePillSheen:SetPoint("TOPLEFT", pill, "TOPLEFT", 1, -1)
		label.forgePillSheen:SetPoint("TOPRIGHT", pill, "TOPRIGHT", -1, -1)
		label.forgePillSheen:SetHeight(1)
	end
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
	item.bar = Solid(item, "ARTWORK", Theme.ACTIVE, 1)
	item.bar:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
	item.bar:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
	item.bar:SetWidth(2)
	item.bar:Hide()

	item.label = Text(item, Theme.F_BODY, Theme.TEXT)
	item.label:SetPoint("LEFT", item, "LEFT", 18, 0)
	item.label:SetJustifyH("LEFT")
	item.text = item.label          -- même nom que sur un bouton du thème

	item.badge = Text(item, Theme.F_SMALL, Theme.BLUE)
	item.badge:SetJustifyH("RIGHT")
	item.badge:Hide()

	-- thème forgé : fond en retrait des bords de la colonne ; survol voilé,
	-- choix en dégradé arcane qui s'éteint vers la droite, barre arcane claire
	-- à gauche, reflet d'un pixel en haut (montré avec le choix)
	local forged = Theme.ForgeHere("CreateNavItem")
	if forged then
		local K = Theme.FORGE_NAV
		item.forged = true
		for _, tex in ipairs({ item.hover, item.tint, item.bar }) do
			tex:ClearAllPoints()
			tex:SetPoint("TOPLEFT", item, "TOPLEFT", K.inset, -1)
			tex:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", K.inset, 1)
		end
		for _, tex in ipairs({ item.hover, item.tint }) do tex:SetPoint("RIGHT", item, "RIGHT", -K.insetRight, 0) end
		item.hover:SetVertexColor(Theme.WHITE[1], Theme.WHITE[2], Theme.WHITE[3], K.hover)
		Gradient(item.tint, "HORIZONTAL", Theme.BLUE, K.select.from, Theme.BLUE, K.select.to)
		item.bar:SetVertexColor(Theme.ARCANE_LIGHT[1], Theme.ARCANE_LIGHT[2], Theme.ARCANE_LIGHT[3], 1)
		item.bar:SetWidth(K.bar)
		item.forgeSheen = Solid(item, "BORDER", Theme.WHITE, K.sheen)
		item.forgeSheen:SetPoint("TOPLEFT", item.tint, "TOPLEFT", 0, 0)
		item.forgeSheen:SetPoint("TOPRIGHT", item.tint, "TOPRIGHT", 0, 0)
		item.forgeSheen:SetHeight(1)
		item.forgeSheen:Hide()
	end

	-- interrupteur de module : rond ouvert, ambre si actif, gris si coupé
	-- (forgé : voyant, point vert lumineux ou point sombre)
	item.power = Theme.CreateNavPower(item, 16, forged)
	item.power:SetPoint("RIGHT", item, "RIGHT", forged and -14 or -12, 0)
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
		if self.forgeSheen then
			if self.selected then self.forgeSheen:Show() else self.forgeSheen:Hide() end
			-- le compteur reste lisible sur le dégradé arcane (le bleu s'y perd)
			SetColor(self.badge, self.selected and Theme.PARCHMENT or Theme.BLUE)
		end
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
			Theme.SetNavPower(self.power, self.moduleOn)
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
	-- thème forgé : filet noir sous la rangée, reflet d'un pixel dessous ;
	-- l'onglet choisi en dégradé arcane, souligné arcane clair, reflet en haut
	local forged = Theme.ForgeHere("CreateTabs")
	local K = Theme.FORGE_TABS
	if forged then
		bar.forged = true
		bar.rule:SetVertexColor(Theme.SHADOW[1], Theme.SHADOW[2], Theme.SHADOW[3], K.rule)
		bar.forgeRuleLight = Solid(bar, "BORDER", Theme.WHITE, K.ruleLight)
		bar.forgeRuleLight:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
		bar.forgeRuleLight:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
		bar.forgeRuleLight:SetHeight(1)
	end

	bar.dim = {}
	local function Paint(tab)
		local on = bar.selected == tab.id
		tab.selected = on
		local rest = bar.dim[tab.id] and Theme.MUTED or Theme.MUTED_LIGHT
		SetColor(tab.label, on and Theme.PARCHMENT or (tab.hovered and Theme.TEXT or rest))
		if on then tab.underline:Show() else tab.underline:Hide() end
		if tab.forgeGlow then
			if on then tab.forgeGlow:Show(); tab.forgeSheen:Show() else tab.forgeGlow:Hide(); tab.forgeSheen:Hide() end
		end
	end
	-- onglet estompé (MUTED au repos) : il reste cliquable (ex. une liste
	-- absente de ce client, que l'onglet explique au survol)
	function bar:SetDim(id, dim)
		self.dim[id] = dim and true or nil
		local tab = self.byId[id]
		if tab then Paint(tab) end
	end

	-- marge de chaque onglet : 24 (12 de chaque côté), resserrée si la
	-- rangée dépasse la largeur de la barre (jamais sous 10)
	local function Padding(self, list)
		local total, probe = 0, self.probe
		if not probe then
			probe = Text(self, Theme.F_HEADING, Theme.MUTED_LIGHT)
			probe:Hide()
			self.probe = probe
		end
		for _, def in ipairs(list) do
			probe:SetText(def.label or tostring(def.id))
			total = total + ((probe.GetStringWidth and probe:GetStringWidth()) or 60) + 4
		end
		local width = tonumber(self.GetWidth and self:GetWidth()) or 0
		if width <= 0 or #list == 0 then return 24 end
		local pad = math.floor((width - total) / #list)
		return Clamp(pad, 10, 24)
	end

	function bar:SetTabs(list)
		for _, tab in ipairs(self.tabs) do tab:Hide() end
		self.byId = {}
		local x = 0
		self.padding = Padding(self, list or {})
		for index, def in ipairs(list or {}) do
			local tab = self.tabs[index]
			if not tab then
				tab = CreateFrame("Button", nil, self)
				tab.label = Text(tab, Theme.F_HEADING, Theme.MUTED_LIGHT)
				tab.label:SetPoint("CENTER", tab, "CENTER", 0, 1)
				tab.text = tab.label
				tab.underline = Solid(tab, "ARTWORK", Theme.ACTIVE, 1)
				tab.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
				tab.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
				tab.underline:SetHeight(2)
				if forged then
					tab.underline:SetVertexColor(Theme.ARCANE_LIGHT[1], Theme.ARCANE_LIGHT[2], Theme.ARCANE_LIGHT[3], 1)
					tab.forgeGlow = tab:CreateTexture(nil, "BACKGROUND")
					tab.forgeGlow:SetTexture(Theme.SOLID)
					tab.forgeGlow:SetAllPoints()
					Gradient(tab.forgeGlow, "VERTICAL", Theme.BLUE, K.to, Theme.BLUE, K.from)
					tab.forgeSheen = Theme.ForgeEdgeLine(tab, "top", Theme.WHITE, K.sheen)
				end
				tab:SetScript("OnClick", function(selfTab) bar:Select(selfTab.id) end)
				tab:SetScript("OnEnter", function(selfTab) selfTab.hovered = true; Paint(selfTab) end)
				tab:SetScript("OnLeave", function(selfTab) selfTab.hovered = false; Paint(selfTab) end)
				self.tabs[index] = tab
			end
			tab.id = def.id
			tab.label:SetText(def.label or tostring(def.id))
			local textWidth = (tab.label.GetStringWidth and tab.label:GetStringWidth()) or 60
			local w = math.floor(textWidth + 0.5) + self.padding
			tab:SetSize(w, Theme.TABS_HEIGHT)
			tab:ClearAllPoints()
			tab:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, 0)
			tab:Show()
			x = x + w + 4
			self.byId[def.id] = tab
		end
		self.used = x - 4
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
	box:SetSize(width or 180, Theme.CONTROL_HEIGHT)
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
	-- socle 3.2 : thème forgé, champ en creux ; le filet passe au bleu arcane
	-- au focus. Le fond et le contour du Sobre restent, transparents : un
	-- habillage (azSurface, carnet Azeroth) les reprend et retrouve son focus.
	if Theme.Forged() then
		box.bg:SetVertexColor(Theme.FIELD[1], Theme.FIELD[2], Theme.FIELD[3], 0)
		box.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 0)
		box.inset = Theme.ForgeSlice(box, "inset", Theme.EDGE)
	end
	local function Focus(self, on)
		if self.inset and not self.azSurface then
			local c = on and Theme.ACTIVE or Theme.EDGE
			self.inset:SetColor(c[1], c[2], c[3], 1)
			self.focused = on
			return
		end
		local c = on and Theme.GOLD or Theme.EDGE
		self.border:SetColor(c[1], c[2], c[3], 1)
	end

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
	box:SetScript("OnEditFocusGained", function(self) Focus(self, true) end)
	box:SetScript("OnEditFocusLost", function(self) Focus(self, false) end)
	box:SetScript("OnEscapePressed", function(self) if self.ClearFocus then self:ClearFocus() end end)
	box:SetScript("OnEnterPressed", function(self) if self.ClearFocus then self:ClearFocus() end end)
	box.lastValue = ""
	box:Refresh()
	return box
end

-- ---------------------------------------------------------------------------
-- Section : titre F_CAPS en capitales, MUTED clair, détail plus pâle
-- ---------------------------------------------------------------------------
-- Thème forgé : point lumineux à gauche, titre de son ton (or clair ; `tone`
-- = "arcane" pour une section de choix ou de navigation), filet lumineux qui
-- part après le titre (ou son détail) et s'éteint au bord droit.
function Theme.CreateSection(parent, text, detail, tone)
	local section = CreateFrame("Frame", nil, parent)
	section:SetSize((parent.GetWidth and parent:GetWidth()) or 400, 20)
	section.label = Text(section, Theme.F_CAPS, Theme.MUTED_LIGHT)
	section.label:SetPoint("LEFT", section, "LEFT", 0, 0)
	section.label:SetJustifyH("LEFT")
	section.detail = Text(section, Theme.F_SMALL, Theme.MUTED)
	section.detail:SetPoint("LEFT", section.label, "RIGHT", 6, 0)
	section.detail:SetJustifyH("LEFT")
	if Theme.ForgeHere("CreateSection") then
		local K = Theme.FORGE_SECTION
		local spec = Theme.FORGE_TONES[tone] or Theme.FORGE_TONES.gold
		section.forged, section.tone = true, Theme.FORGE_TONES[tone] and tone or "gold"
		section.forgeDot = Theme.ArtTexture(section, "dot", "ARTWORK", 0, spec.light, 1)
		section.forgeDot:SetSize(K.dot, K.dot)
		section.forgeDot:SetPoint("LEFT", section, "LEFT", K.dotX, 0)
		section.label:ClearAllPoints()
		section.label:SetPoint("LEFT", section, "LEFT", K.text, 0)
		SetColor(section.label, spec.light)
		section.forgeLine = Theme.ArtTexture(section, "line", "ARTWORK", 0, spec.light, Theme.FORGE_RULE.alpha)
		section.forgeLine:SetHeight(K.line)
	end
	function section:SetText(label, more)
		self.label:SetText(Theme.Upper(label))
		if more and more ~= "" then
			self.detail:SetText("(" .. more .. ")")
			self.detail:Show()
		else
			self.detail:SetText("")
			self.detail:Hide()
		end
		if self.forgeLine then
			local K = Theme.FORGE_SECTION
			self.forgeLine:ClearAllPoints()
			self.forgeLine:SetPoint("LEFT", self.detail:IsShown() and self.detail or self.label, "RIGHT", K.lineGap, 0)
			self.forgeLine:SetPoint("RIGHT", self, "RIGHT", 0, 0)
		end
	end
	section:SetText(text, detail)
	return section
end

-- ---------------------------------------------------------------------------
-- Carte de réglage : fond ROW (ROW_ALT une rangée sur deux), libellé à
-- gauche, zone .control à droite pour le contrôle (aligné à droite)
-- ---------------------------------------------------------------------------
-- socle 2.11.0 : voile de survol d'une carte ou d'une ligne, blanc à
-- Theme.HOVER_ALPHA, plus un filet EDGE (comme les tuiles) qui suit le voile :
-- hover:Show() / hover:Hide() montrent ou cachent les deux.
-- Thème forgé : le filet (or patiné) plus discret, le voile reste.
function Theme.CreateHover(frame)
	local hover = Solid(frame, "BORDER", Theme.WHITE, Theme.HOVER_ALPHA)
	hover:SetAllPoints()
	local edge = Border(frame, Theme.EDGE, Theme.ForgeHere("CreateHover") and Theme.FORGE_NAV.hoverEdge or 1, "BORDER")
	hover.edge = edge
	local show, hide = hover.Show, hover.Hide
	hover.Show = function(self)
		show(self)
		for _, side in ipairs({ "top", "bottom", "left", "right" }) do edge[side]:Show() end
	end
	hover.Hide = function(self)
		hide(self)
		for _, side in ipairs({ "top", "bottom", "left", "right" }) do edge[side]:Hide() end
	end
	hover:Hide()
	return hover
end

-- `kind` = "Button" : carte cliquable (interrupteur, action), éclairée au survol
Theme.CARD_HEIGHT = 38
-- Thème forgé : la carte garde son fond (ROW / ROW_ALT) ; par-dessus, un
-- relief (Theme.ForgeRelief : voile plus clair en haut, plus sombre en bas,
-- reflet d'un pixel en haut, ombre d'un pixel en bas). Trois textures au
-- lieu des neuf d'une découpe : une page de réglages porte des dizaines de
-- cartes, toutes construites à l'ouverture.
function Theme.CreateSettingCard(parent, width, height, kind)
	local card = CreateFrame(kind or "Frame", nil, parent)
	width, height = width or 340, height or Theme.CARD_HEIGHT
	card:SetSize(width, height)
	card.bg = Solid(card, "BACKGROUND", Theme.ROW, 1)
	card.bg:SetAllPoints()
	if Theme.ForgeHere("CreateSettingCard") then Theme.ForgeRelief(card) end
	card.hover = Theme.CreateHover(card)
	if kind == "Button" then
		card:SetScript("OnEnter", function(self) self.hover:Show() end)
		card:SetScript("OnLeave", function(self) self.hover:Hide() end)
	end
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

	-- socle 3.2 : thème forgé. Piste presque noire ; le remplissage garde sa
	-- couleur (bar:SetColor, les habillages) et reçoit un voile en dégradé
	-- (bas assombri) ; dès 5 px, un reflet d'un pixel en haut du remplissage,
	-- l'ombre en haut de la piste et son filet clair dessous. Jamais de
	-- découpe en 9 tranches : une barre vit souvent sur chaque ligne d'une liste.
	if Theme.Forged() then
		local F = Theme.FORGE
		bar.forge = true
		bar.bg:SetVertexColor(F.track[1], F.track[2], F.track[3], 1)
		bar.fillShade = bar:CreateTexture(nil, "ARTWORK", nil, 1)
		bar.fillShade:SetTexture(Theme.SOLID)
		bar.fillShade:SetPoint("TOPLEFT", bar.fill, "TOPLEFT", 0, 0)
		bar.fillShade:SetPoint("BOTTOMRIGHT", bar.fill, "BOTTOMRIGHT", 0, 0)
		Theme.Gradient(bar.fillShade, "VERTICAL", Theme.SHADOW, 1 - F.fillLow, Theme.SHADOW, 0)
		bar.fillShade:Hide()
		if (tonumber(height) or 0) >= 5 then
			bar.sheen = bar:CreateTexture(nil, "ARTWORK", nil, 2)
			bar.sheen:SetTexture(Theme.SOLID)
			bar.sheen:SetVertexColor(Theme.WHITE[1], Theme.WHITE[2], Theme.WHITE[3], F.sheen)
			bar.sheen:SetPoint("TOPLEFT", bar.fill, "TOPLEFT", 0, 0)
			bar.sheen:SetPoint("TOPRIGHT", bar.fill, "TOPRIGHT", 0, 0)
			bar.sheen:SetHeight(1)
			bar.sheen:Hide()
			bar.trackShade = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
			bar.trackShade:SetTexture(Theme.SOLID)
			bar.trackShade:SetVertexColor(Theme.SHADOW[1], Theme.SHADOW[2], Theme.SHADOW[3], F.trackShade)
			bar.trackShade:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
			bar.trackShade:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
			bar.trackShade:SetHeight(1)
			bar.trackRim = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
			bar.trackRim:SetTexture(Theme.SOLID)
			bar.trackRim:SetVertexColor(Theme.WHITE[1], Theme.WHITE[2], Theme.WHITE[3], F.trackRim)
			bar.trackRim:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
			bar.trackRim:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
			bar.trackRim:SetHeight(1)
		end
	end

	function bar:SetValue(ratio)
		ratio = Clamp(tonumber(ratio) or 0, 0, 1)
		self.ratio = ratio
		local w = self:GetWidth() * ratio
		-- une texture de largeur 0 peut s'afficher sur 1 px : on la masque
		if w <= 0 then self.fill:Hide() else self.fill:Show() end
		self.fill:SetWidth(math.max(0, w))
		-- le relief suit le remplissage ; une barre habillée par son module
		-- (azSurface : le carnet Azeroth) garde ses seules matières
		if self.forge then
			local on = w > 0 and not self.azSurface
			for _, key in ipairs({ "fillShade", "sheen" }) do
				if self[key] then if on then self[key]:Show() else self[key]:Hide() end end
			end
			for _, key in ipairs({ "trackShade", "trackRim" }) do
				if self[key] then if self.azSurface then self[key]:Hide() else self[key]:Show() end end
			end
		end
	end

	function bar:SetColor(r, g, b, a)
		self.fill:SetVertexColor(r, g, b, a or 1)
	end

	return bar
end

-- ---------------------------------------------------------------------------
-- Bouton dessiné. Styles :
--   nil / "normal" / "outline" : contour EDGE, texte clair, fond transparent ;
--   "accent"    : contour ambre, texte ambre, fond ambre à 7 % ;
--   "primary"   : plein ambre, encre sombre SANS ombre ;
--   "adventure" : plein bleu de nuit, encre sombre SANS ombre (socle 2.11.0 :
--                 le blanc tombait à 3,31:1, 2,60 au survol ; l'encre tient
--                 5,67 au repos, 6,69 au survol).
-- Au survol, le contour (ou le fond, pour les boutons pleins) s'éclaire.
-- socle 2.11.0 : enfoncé (libellé décalé de 1, -1 ; fond plein assombri,
-- contour ambre sombre) et désactivé (socle 3.0 : Theme.DISABLED opaque,
-- sans survol ; plus de DIM_ALPHA sur le bouton).
-- Theme.BUTTON_STYLES est exposé (tests de contraste).
-- ---------------------------------------------------------------------------
local BUTTON_STYLES = {
	outline   = { bg = Theme.WINDOW, bgAlpha = 0, edge = Theme.EDGE, text = Theme.LABEL, hoverEdge = Theme.GOLD },
	accent    = { bg = Theme.GOLD, bgAlpha = 0.07, hoverAlpha = 0.14, edge = Theme.GOLD, text = Theme.GOLD },
	primary   = { bg = Theme.GOLD, bgAlpha = 1, hoverBg = Theme.GOLD_LIGHT, edge = Theme.GOLD, text = Theme.INK, filled = true },
	adventure = { bg = Theme.BLUE, bgAlpha = 1, hoverBg = Theme.Over(Theme.BLUE, Theme.WHITE, 0.12), edge = Theme.BLUE,
		text = Theme.INK, filled = true },
}
BUTTON_STYLES.normal = BUTTON_STYLES.outline
-- socle 3.2 : styles qui ont un sens en thème forgé (plaque verte, rouge,
-- bleu arcane : Theme.FORGE_BUTTONS) ; en Sobre, le bouton en contour
BUTTON_STYLES.add = BUTTON_STYLES.outline      -- ajouter, rallumer
BUTTON_STYLES.danger = BUTTON_STYLES.outline   -- retirer, détruire, effacer
BUTTON_STYLES.arcane = BUTTON_STYLES.outline   -- action neutre (ouvrir, changer)
Theme.BUTTON_STYLES = BUTTON_STYLES

-- bouton actif ? (sans IsEnabled : toujours actif)
local function ButtonEnabled(button)
	if not button.IsEnabled then return true end
	local ok, on = pcall(button.IsEnabled, button)
	return not ok or (on ~= false and on ~= nil and on ~= 0)
end
-- socle 3.0 : un seul peintre des états d'un bouton ("rest", "hover",
-- "pressed", "disabled"). Un habillage (style Azeroth de QuestCompanion) pose
-- button.skinPaint(button, état) et peint lui-même ses matières : le thème ne
-- repeint plus par-dessus (avant : l'encre sombre du bouton plein retombait
-- sur le rouge du carnet après chaque Enable).
-- socle 3.2 : thème forgé, la plaque teintée par état (survol éclairé, appui
-- assombri, désactivé désaturé) ; le fond et le contour du Sobre restent,
-- transparents (un habillage les reprend)
local function ForgePaint(self, state)
	local f, F = self.forge, Theme.FORGE
	local tint = Theme.FORGE_PLATE[f.plate] or Theme.FORGE_PLATE.neutral
	local text = f.text
	if state == "disabled" then
		tint, text = Theme.FORGE_PLATE.disabled, Theme.DISABLED.text
	elseif state == "hover" then
		tint = Theme.ForgeHover(tint)
	elseif state == "pressed" then
		tint = Theme.ForgeTint(tint, f.press or F.press)
	end
	self.plate:SetColor(tint[1], tint[2], tint[3], 1)
	self.forgeTint = tint
	self.bg:SetVertexColor(tint[1], tint[2], tint[3], 0)
	self.border:SetColor(tint[1], tint[2], tint[3], 0)
	SetColor(self.text, text)
	-- encre sombre sur l'or : sans ombre ; libellé clair : ombre noire
	if f.noShadow or state == "disabled" then Theme.NoShadow(self.text) else Theme.TextShadow(self.text, 0.7) end
end
local function ButtonPaint(self, state)
	local s = self.spec
	self.paintState = state
	self.disabledLook = (state == "disabled") or nil
	self:SetAlpha(1)
	-- un habillage (carnet Azeroth) peint ses matières : la plaque s'efface
	if self.plate then self.plate:SetShown(not self.skinPaint) end
	if self.skinPaint then return self.skinPaint(self, state) end
	if self.plate then return ForgePaint(self, state) end
	if state == "disabled" then
		local d = Theme.DISABLED
		self.bg:SetVertexColor(d.bg[1], d.bg[2], d.bg[3], s.filled and 1 or 0)
		self.border:SetColor(d.edge[1], d.edge[2], d.edge[3], 1)
		SetColor(self.text, d.text)
		return
	end
	SetColor(self.text, s.text)
	self.bg:SetVertexColor(s.bg[1], s.bg[2], s.bg[3], s.bgAlpha)
	self.border:SetColor(s.edge[1], s.edge[2], s.edge[3], 1)
	if state == "hover" then
		if s.hoverBg then self.bg:SetVertexColor(s.hoverBg[1], s.hoverBg[2], s.hoverBg[3], 1) end
		if s.hoverAlpha then self.bg:SetVertexColor(s.bg[1], s.bg[2], s.bg[3], s.hoverAlpha) end
		if s.hoverEdge then self.border:SetColor(s.hoverEdge[1], s.hoverEdge[2], s.hoverEdge[3], 1) end
	elseif state == "pressed" then
		if s.filled then
			local c = Theme.Over(s.bg, Theme.INK, Theme.PRESS_SHADE)
			self.bg:SetVertexColor(c[1], c[2], c[3], 1)
		else
			self.border:SetColor(Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3], 1)
		end
	end
end
Theme.ButtonPaint = ButtonPaint
-- repos (ou aspect désactivé)
-- socle 3.0 : `inactive` (button:SetInactive) : l'aspect désactivé, mais le
-- clic passe encore (le module dit pourquoi : « il te manque n paillettes »)
local function ButtonOn(button) return ButtonEnabled(button) and not button.inactive end
local function ButtonRest(self)
	self.text:ClearAllPoints()
	self.text:SetPoint("CENTER", 0, 0)
	ButtonPaint(self, ButtonOn(self) and "rest" or "disabled")
end
Theme.ButtonRest = ButtonRest

-- Largeur d'un texte dans un rôle de police : une sonde cachée par parent,
-- réutilisée. Sans mesure possible, 7 px par octet (repli large).
function Theme.TextWidth(parent, text, font)
	text = tostring(text or "")
	local probe = parent and parent.themeProbe
	if parent and not probe and parent.CreateFontString then
		probe = parent:CreateFontString(nil, "OVERLAY", font or Theme.F_LABEL)
		probe:Hide()
		parent.themeProbe = probe
	end
	local width = 0
	if probe then
		if probe.SetFontObject then probe:SetFontObject(font or Theme.F_LABEL) end
		probe:SetText(text)
		width = tonumber(probe.GetStringWidth and probe:GetStringWidth()) or 0
		probe:SetText("")
	end
	if width <= 0 then width = #text * 7 end
	return width
end

-- Largeur d'un bouton qui tient son libellé : texte + 16 de chaque côté,
-- jamais sous `minimum` (72 par défaut)
Theme.BUTTON_PAD = 32
Theme.BUTTON_MIN = 72
function Theme.ButtonWidth(parent, label, minimum)
	local width = math.ceil(Theme.TextWidth(parent, label, Theme.F_LABEL) + Theme.BUTTON_PAD)
	return math.max(tonumber(minimum) or Theme.BUTTON_MIN, width)
end

-- `width` nil ou "auto" : la largeur suit le libellé (Theme.ButtonWidth)
-- socle 3.0 : `height` est un nombre ou une taille nommée de
-- Theme.BUTTON_SIZES ("xs" 18, "sm" 24, "md" 28 ; nil : "md")
function Theme.ButtonHeight(height)
	return Theme.BUTTON_SIZES[height] or tonumber(height) or Theme.BUTTON_SIZES.md
end
function Theme.CreateButton(parent, width, height, label, onClick, style)
	local button = CreateFrame("Button", nil, parent)
	if width == nil or width == "auto" then width = Theme.ButtonWidth(parent, label) end
	button.size = Theme.BUTTON_SIZES[height] and height or nil
	button:SetSize(width, Theme.ButtonHeight(height))
	button.style = style or "normal"
	local spec = BUTTON_STYLES[button.style] or BUTTON_STYLES.outline
	button.spec = spec

	button.bg = Solid(button, "BACKGROUND", spec.bg, spec.bgAlpha)
	button.bg:SetAllPoints()
	button.border = Border(button, spec.edge, 1)
	-- socle 3.2 : thème forgé, plaque de relief teintée selon le style
	if Theme.Forged() then
		button.forge = Theme.FORGE_BUTTONS[button.style] or Theme.FORGE_BUTTONS.outline
		button.plate = Theme.ForgeSlice(button, "plate", Theme.FORGE_PLATE[button.forge.plate])
	end

	button.text = Text(button, Theme.F_LABEL, spec.text)
	button.text:SetPoint("CENTER", 0, 0)
	button.text:SetText(label)
	if spec.filled then
		-- encre sur l'ambre ou le bleu, SANS l'ombre noire de la police
		Theme.NoShadow(button.text)
	end
	button.SetText = function(self, text) self.text:SetText(text) end
	button.GetText = function(self) return self.text:GetText() end

	button:SetScript("OnEnter", function(self)
		if not ButtonOn(self) then
			-- désactivé : pas de survol, mais l'infobulle qui dit pourquoi
			local tooltip = rawget(_G, "GameTooltip")
			if self.disabledTip and type(tooltip) == "table" and tooltip.SetOwner then
				tooltip:SetOwner(self, "ANCHOR_TOP")
				Theme.TooltipLine(tooltip, self.disabledTip, Theme.PARCHMENT)
				tooltip:Show()
			end
			return
		end
		ButtonPaint(self, "hover")
	end)
	button:SetScript("OnLeave", function(self)
		ButtonRest(self)
		local tooltip = rawget(_G, "GameTooltip")
		if self.disabledTip and type(tooltip) == "table" and tooltip.Hide and tooltip.GetOwner
			and tooltip:GetOwner() == self then tooltip:Hide() end
	end)
	button:SetScript("OnHide", ButtonRest)
	-- appui : libellé enfoncé d'un pixel, fond plein assombri ou contour ambre sombre
	button:SetScript("OnMouseDown", function(self, mouse)
		if (mouse and mouse ~= "LeftButton") or not ButtonOn(self) then return end
		self.pressed = true
		self.text:ClearAllPoints()
		self.text:SetPoint("CENTER", 1, -1)
		ButtonPaint(self, "pressed")
	end)
	button:SetScript("OnMouseUp", function(self)
		self.pressed = nil
		local over = false
		if self.IsMouseOver then
			local ok, value = pcall(self.IsMouseOver, self)
			over = ok and value and true or false
		end
		ButtonRest(self)
		if over then self:GetScript("OnEnter")(self) end
	end)
	-- Disable / Enable / SetEnabled : l'aspect suit (méthodes de l'instance
	-- enveloppées ; ce bouton n'est pas un cadre protégé)
	for _, method in ipairs({ "Disable", "Enable", "SetEnabled" }) do
		local original = button[method]
		if type(original) == "function" then
			button[method] = function(self, ...)
				original(self, ...)
				ButtonRest(self)
			end
		end
	end
	-- socle 3.0 : aspect désactivé, clic gardé (le module explique le refus) ;
	-- tip : l'infobulle du survol
	function button:SetInactive(on, tip)
		self.inactive = on and true or nil
		self.disabledTip = on and tip or nil
		ButtonRest(self)
	end
	if onClick then button:SetScript("OnClick", onClick) end
	if button.plate then ButtonRest(button) end
	return button
end

-- ---------------------------------------------------------------------------
-- Interrupteur : piste carrée 32 x 15 ; actif = piste ambre et curseur blanc
-- à droite, coupé = piste CONTROL et curseur MUTED à gauche
-- ---------------------------------------------------------------------------
-- `kind` = "Button" pour un interrupteur cliquable à lui seul (navigation) ;
-- `width`/`height` : 32 x 15 par défaut.
-- socle 2.11.0 : case à cocher du client (atlas « checkbox-minimal », vérifié
-- en jeu sur Forever ; coche « checkmark-minimal », partiel
-- « common-checkbox-partial ») si le client les connaît. Sinon l'interrupteur
-- dessiné d'avant (piste et curseur) : la piste, le curseur et le contour
-- restent tenus à jour dans les deux cas (mêmes champs, mêmes tests).
Theme.CHECKBOX_SIZE = 18
-- coche d'une case : l'atlas du client, sinon un carré ambre plein
local function PaintCheck(tex, size)
	if Theme.PaintClient(tex, "checkmark") then
		tex:SetVertexColor(1, 1, 1, 1)
		tex:SetSize(size, size)
	else
		tex:SetTexture(Theme.SOLID)
		tex:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		tex:SetSize(math.floor(size / 2), math.floor(size / 2))
	end
end
-- socle 3.2 : thème forgé, case en creux (nos textures, sans atlas du
-- client), coche or clair qui luit ; partiel : trait clair. frame.box est le
-- fond du creux, frame.inset la découpe entière (le filet prend la teinte).
local function ForgeCheckbox(frame, size)
	local F = Theme.FORGE
	size = tonumber(size) or Theme.CHECKBOX_SIZE
	frame.inset = frame.inset or Theme.ForgeSlice(frame, "inset", Theme.EDGE, { margin = Theme.ForgeMargin(size, true) })
	frame.box = frame.inset.parts.c
	frame.glow = frame.glow or Theme.ForgeGlow(frame, frame, Theme.GOLD_LIGHT, math.floor(size * F.checkGlow.size + 0.5),
		"ARTWORK", 0, F.checkGlow.alpha)
	frame.check = frame.check or frame:CreateTexture(nil, "OVERLAY")
	frame.check:SetTexture(Theme.CHECK_FILE)
	frame.check:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame.check:SetSize(math.floor(size * F.tick + 0.5), math.floor(size * F.tick + 0.5))
	frame.check:SetVertexColor(Theme.GOLD_LIGHT[1], Theme.GOLD_LIGHT[2], Theme.GOLD_LIGHT[3], 1)
	frame.check:Hide()
	frame.partialMark = frame.partialMark or frame:CreateTexture(nil, "OVERLAY")
	frame.partialMark:SetTexture(Theme.SOLID)
	frame.partialMark:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame.partialMark:SetSize(math.floor(size / 2), 2)
	frame.partialMark:SetVertexColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3], 1)
	frame.partialMark:Hide()
	frame.checkbox, frame.forgeCheck = true, true
	return true
end
-- Habille `frame` d'une case du client (rend vrai) ; faux si l'atlas manque
-- (thème forgé : toujours la case en creux)
function Theme.ApplyCheckbox(frame, size)
	if Theme.Forged() then return ForgeCheckbox(frame, size) end
	local box = frame.box or frame:CreateTexture(nil, "ARTWORK")
	if not Theme.PaintClient(box, "checkbox") then
		if frame.box then frame.box:Hide() end
		return false
	end
	frame.box = box
	box:SetAllPoints()
	box:Show()
	frame.check = frame.check or frame:CreateTexture(nil, "OVERLAY")
	frame.check:SetPoint("CENTER", frame, "CENTER", 0, 0)
	PaintCheck(frame.check, size)
	frame.check:Hide()
	frame.partialMark = frame.partialMark or frame:CreateTexture(nil, "OVERLAY")
	frame.partialMark:SetPoint("CENTER", frame, "CENTER", 0, 0)
	if Theme.PaintClient(frame.partialMark, "partial") then
		frame.partialMark:SetSize(size, size)
	else
		frame.partialMark:SetTexture(Theme.SOLID)
		frame.partialMark:SetVertexColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3], 1)
		frame.partialMark:SetSize(math.floor(size / 2), 2)
	end
	frame.partialMark:Hide()
	frame.checkbox = true
	return true
end
-- état d'une case : true (cochée), false (vide), "partial"
function Theme.SetCheckboxState(frame, state)
	if not frame.checkbox then return end
	if state == true then frame.check:Show() else frame.check:Hide() end
	if state == "partial" then frame.partialMark:Show() else frame.partialMark:Hide() end
	if frame.forgeCheck then
		-- filet or quand la case est cochée, or patiné sinon ; la coche luit
		local c = (state == true) and Theme.GOLD_SOFT or Theme.EDGE
		frame.inset:SetColor(c[1], c[2], c[3], 1)
		frame.checkState = state
		if state == true then frame.glow:Show() else frame.glow:Hide() end
		return
	end
	local c = (state == false) and Theme.MUTED_LIGHT or Theme.WHITE
	frame.box:SetVertexColor(c[1], c[2], c[3], 1)
end

function Theme.CreateToggle(parent, width, height, kind)
	local toggle = CreateFrame(kind or "Frame", nil, parent)
	width, height = width or 32, height or 15
	toggle:SetSize(width, height)
	toggle.track = Solid(toggle, "BACKGROUND", Theme.CONTROL, 1)
	toggle.track:SetAllPoints()
	toggle.edge = Border(toggle, Theme.GOLD, 0)
	toggle.knob = Solid(toggle, "ARTWORK", Theme.MUTED, 1)
	toggle.knob:SetSize(height - 4, height - 4)
	-- socle 3.2 : thème forgé, interrupteur dessiné (nos textures, jamais la
	-- case du client) : piste en creux, curseur en relief ; actif = filet et
	-- curseur bleu arcane, qui luit. toggle.knob (invisible) porte la place du
	-- curseur, toggle.thumb (plaque) le dessine.
	if Theme.Forged() then
		toggle.forgeSwitch = true
		toggle.track:SetAlpha(0)
		toggle.knob:SetAlpha(0)
		toggle.knob:SetSize(math.floor(width / 2 + 0.5), math.max(4, height - 2))
		Theme.ForgeHideBorder(toggle.edge)
		toggle.inset = Theme.ForgeSlice(toggle, "inset", Theme.EDGE, { margin = Theme.ForgeMargin(height, true) })
		toggle.glow = Theme.ForgeGlow(toggle, toggle.knob, Theme.FORGE_PLATE.thumbOn,
			math.floor(height * Theme.FORGE.glowSize + 0.5), "ARTWORK", 0)
		toggle.thumb = Theme.ForgeSlice(toggle, "plate", Theme.FORGE_PLATE.thumb,
			{ layer = "ARTWORK", sub = 1, margin = Theme.FORGE.marginSmall - 1, around = toggle.knob })
	elseif Theme.ApplyCheckbox(toggle, Theme.CHECKBOX_SIZE) then
		toggle:SetSize(Theme.CHECKBOX_SIZE, Theme.CHECKBOX_SIZE)
		toggle.track:Hide()
		toggle.knob:Hide()
		for _, side in ipairs({ "top", "bottom", "left", "right" }) do
			if toggle.edge[side] then toggle.edge[side]:Hide() end
		end
	end

	-- partiel : une partie seulement des modules est active (contour ambre,
	-- curseur gris au centre)
	-- thème forgé : filet, curseur et lueur selon l'état ("on", "off", "partial")
	local function ForgeState(self, state)
		if not self.forgeSwitch then return end
		local P = Theme.FORGE_PLATE
		local rim = (state == "on" and Theme.ACTIVE) or (state == "partial" and Theme.GOLD) or Theme.EDGE
		local thumb = state == "on" and P.thumbOn or P.thumb
		self.inset:SetColor(rim[1], rim[2], rim[3], 1)
		self.thumb:SetColor(thumb[1], thumb[2], thumb[3], 1)
		if state == "on" then self.glow:Show() else self.glow:Hide() end
		self.knob:ClearAllPoints()
		if state == "on" then self.knob:SetPoint("RIGHT", self, "RIGHT", -1, 0)
		elseif state == "off" then self.knob:SetPoint("LEFT", self, "LEFT", 1, 0)
		else self.knob:SetPoint("CENTER", self, "CENTER", 0, 0) end
		self.forgeState = state
	end

	function toggle:SetPartial()
		self.checked, self.partial = nil, true
		self.knob:ClearAllPoints()
		self.knob:SetPoint("CENTER", self, "CENTER", 0, 0)
		self.knob:SetVertexColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3], 1)
		self.track:SetVertexColor(Theme.CONTROL[1], Theme.CONTROL[2], Theme.CONTROL[3], 1)
		self.edge:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], self.checkbox and 0 or 1)
		Theme.SetCheckboxState(self, "partial")
		ForgeState(self, "partial")
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
		Theme.SetCheckboxState(self, self.checked)
		ForgeState(self, self.checked and "on" or "off")
	end
	function toggle:GetChecked() return self.checked == true end
	toggle:SetChecked(false)
	return toggle
end

-- Interrupteur de module (navigation des réglages) : case du client si
-- l'atlas est là (socle 2.11.0), sinon la coche du client (socle 2.12.1,
-- Theme.POWER). `button.icon` porte la teinte ambre/grise.
function Theme.CreatePowerButton(parent, size)
	local button = CreateFrame("Button", nil, parent)
	size = size or 16
	button:SetSize(size, size)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	-- socle 3.2 : thème forgé, un voyant (point lumineux) : vert qui luit
	-- quand le module tourne, petit point éteint sinon
	if Theme.Forged() then
		button.forgeLed = true
		button.icon:SetTexture(Theme.ART.dot.file)
		button.icon:ClearAllPoints()
		button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	elseif Theme.ApplyCheckbox(button, size) then
		button.icon:Hide()
	else
		button.icon:SetTexture(Theme.POWER)
	end
	return button
end
function Theme.SetPowerState(button, on)
	local c = on and Theme.GOLD or Theme.MUTED
	if button.forgeLed then
		local F = Theme.FORGE
		c = on and Theme.GREEN or F.ledOff
		local size = on and F.led or math.floor(F.led * 0.6 + 0.5)
		button.icon:SetSize(size, size)
	end
	button.icon:SetVertexColor(c[1], c[2], c[3], 1)
	Theme.SetCheckboxState(button, on and true or false)
end

-- ---------------------------------------------------------------------------
-- Curseur : piste fine 3 px, part remplie ambre, poignée ambre, valeur dans
-- une petite case à droite. Glisser à la souris ou molette (un cran).
-- onChange(valeur, curseur) seulement sur une action de l'utilisateur ;
-- :SetValue depuis le code ne rappelle pas.
-- ---------------------------------------------------------------------------
-- `valueWidth` : largeur de la case (44 par défaut), plus large pour un nom
-- de cran (« Très grand »)
Theme.SLIDER_VALUE_WIDTH = 44
function Theme.CreateSlider(parent, width, minValue, maxValue, step, onChange, valueWidth)
	local slider = CreateFrame("Frame", nil, parent)
	width = width or 180
	slider:SetSize(width, 18)
	slider.min, slider.max = tonumber(minValue) or 0, tonumber(maxValue) or 1
	if slider.max < slider.min then slider.min, slider.max = slider.max, slider.min end
	slider.step = tonumber(step) or 0
	slider.valueWidth = tonumber(valueWidth) or Theme.SLIDER_VALUE_WIDTH
	slider.trackWidth = width - slider.valueWidth - 12

	slider.box = CreateFrame("Frame", nil, slider)
	slider.box:SetSize(slider.valueWidth, 18)
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
	-- socle 3.2 : thème forgé. Case de valeur en creux ; piste sombre en
	-- creux (ombre en haut, filet clair dessous), part remplie en dégradé or
	-- sombre -> or clair ; poignée claire, liseré noir, qui luit d'or.
	if Theme.Forged() then
		local F = Theme.FORGE
		slider.forge = true
		slider.box.bg:SetAlpha(0)
		Theme.ForgeHideBorder(slider.box.border)
		slider.box.inset = Theme.ForgeSlice(slider.box, "inset", Theme.EDGE, { margin = Theme.ForgeMargin(18, true) })
		slider.track:SetHeight(F.sliderTrack)
		slider.track:SetVertexColor(F.track[1], F.track[2], F.track[3], 1)
		slider.trackShade = Solid(slider.hit, "BACKGROUND", Theme.SHADOW, F.trackShade)
		slider.trackShade:SetPoint("TOPLEFT", slider.track, "TOPLEFT", 0, 0)
		slider.trackShade:SetPoint("TOPRIGHT", slider.track, "TOPRIGHT", 0, 0)
		slider.trackShade:SetHeight(1)
		slider.trackRim = Solid(slider.hit, "BACKGROUND", Theme.WHITE, F.trackRim)
		slider.trackRim:SetPoint("TOPLEFT", slider.track, "BOTTOMLEFT", 0, 0)
		slider.trackRim:SetPoint("TOPRIGHT", slider.track, "BOTTOMRIGHT", 0, 0)
		slider.trackRim:SetHeight(1)
		slider.fill:SetHeight(F.sliderTrack)
		Theme.Gradient(slider.fill, "HORIZONTAL", F.goldDeep, 1, Theme.GOLD_LIGHT, 1)
		slider.handle:SetSize(F.thumb[1], F.thumb[2])
		Theme.Gradient(slider.handle, "VERTICAL", F.thumbBottom, 1, F.thumbTop, 1)
		slider.handleEdge = slider.hit:CreateTexture(nil, "OVERLAY", nil, -1)
		slider.handleEdge:SetTexture(Theme.SOLID)
		slider.handleEdge:SetVertexColor(Theme.SHADOW[1], Theme.SHADOW[2], Theme.SHADOW[3], 1)
		slider.handleEdge:SetPoint("TOPLEFT", slider.handle, "TOPLEFT", -1, 1)
		slider.handleEdge:SetPoint("BOTTOMRIGHT", slider.handle, "BOTTOMRIGHT", 1, -1)
		slider.glow = Theme.ForgeGlow(slider.hit, slider.handle, Theme.GOLD_LIGHT,
			math.floor(F.thumb[2] * F.glowSize * 0.8 + 0.5), "ARTWORK", 1)
		slider.glow:Show()
	end

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
	-- suivi de la souris seulement pendant le glisser (pas d'OnUpdate au repos)
	local function Follow()
		if not slider.dragging then return end
		local x = CursorX(slider)
		if x then slider:SetValueByUser(slider:ValueAt(x)) end
	end
	slider.hit:SetScript("OnMouseDown", function()
		slider.dragging = true
		Follow()
		slider.hit:SetScript("OnUpdate", Follow)
	end)
	slider.hit:SetScript("OnMouseUp", function()
		slider.dragging = false
		slider.hit:SetScript("OnUpdate", nil)
	end)
	local function Wheel(_, delta)
		local stepSize = slider.step > 0 and slider.step or (slider.max - slider.min) / 20
		slider:SetValueByUser((slider.value or slider.min) + (delta > 0 and stepSize or -stepSize))
	end
	if slider.EnableMouseWheel then slider:EnableMouseWheel(true) end
	if slider.hit.EnableMouseWheel then slider.hit:EnableMouseWheel(true) end
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
-- opts.maxRows : lignes visibles (10 par défaut), le reste défile à la
-- molette ; opts.listWidth : liste plus large que la case (indices longs).
-- Une seule liste ouverte à la fois (Theme.openDropdown) : en ouvrir une
-- referme l'autre, sinon deux listes voisines se recouvrent.
-- ---------------------------------------------------------------------------
Theme.DROPDOWN_ROW = 22
Theme.DROPDOWN_MAX_ROWS = 10
function Theme.CreateDropdown(parent, width, onSelect, opts)
	opts = opts or {}
	local dropdown = CreateFrame("Button", nil, parent)
	width = width or 160
	local listWidth = math.max(width, tonumber(opts.listWidth) or width)
	dropdown.maxRows = tonumber(opts.maxRows) or Theme.DROPDOWN_MAX_ROWS
	-- socle 3.0 : à la hauteur des puces et de la recherche (Theme.CONTROL_HEIGHT)
	dropdown:SetSize(width, tonumber(opts.height) or Theme.CONTROL_HEIGHT)
	dropdown.options = {}
	dropdown.offset = 0
	dropdown.bg = Solid(dropdown, "BACKGROUND", Theme.FIELD, 1)
	dropdown.bg:SetAllPoints()
	dropdown.border = Border(dropdown, Theme.EDGE, 1)
	dropdown.text = Text(dropdown, Theme.F_BODY, Theme.LABEL)
	dropdown.text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
	dropdown.text:SetPoint("RIGHT", dropdown, "RIGHT", -22, 0)
	dropdown.text:SetJustifyH("LEFT")
	if dropdown.text.SetWordWrap then dropdown.text:SetWordWrap(false) end
	dropdown.chevron = dropdown:CreateTexture(nil, "ARTWORK")
	Theme.PaintClient(dropdown.chevron, "chevron")
	dropdown.chevron:SetSize(12, 12)
	dropdown.chevron:SetPoint("RIGHT", dropdown, "RIGHT", -6, 0)
	dropdown.chevron:SetVertexColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3], 1)
	-- socle 3.2 : thème forgé. Plaque en relief (éclairée au survol, bleu
	-- arcane ouverte) et chevron or dessiné (un triangle de 4 rangées : pas
	-- d'atlas du client). Le fond et le contour du Sobre restent, transparents :
	-- un habillage (azSurface, carnet Azeroth) les reprend.
	if Theme.Forged() then
		local F = Theme.FORGE
		dropdown.bg:SetVertexColor(Theme.FIELD[1], Theme.FIELD[2], Theme.FIELD[3], 0)
		dropdown.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 0)
		dropdown.plate = Theme.ForgeSlice(dropdown, "plate", Theme.FORGE_PLATE.neutral)
		dropdown.chevron:Hide()
		dropdown.caret = {}
		local rows = #F.caret
		for index, w in ipairs(F.caret) do
			local row = Solid(dropdown, "OVERLAY", Theme.GOLD_LIGHT, 1)
			row:SetSize(w, 1)
			row:SetPoint("CENTER", dropdown, "RIGHT", -12, math.floor(rows / 2) - index + 1)
			dropdown.caret[index] = row
		end
	end
	-- état de la plaque : "rest", "hover", "open"
	local function ForgeLook(self, state)
		if not self.plate then return end
		local P, F = Theme.FORGE_PLATE, Theme.FORGE
		local tint = P.neutral
		if state == "open" then tint = P.arcane
		elseif state == "hover" then tint = Theme.ForgeHover(P.neutral) end
		self.plate:SetShown(not self.azSurface)
		self.plate:SetColor(tint[1], tint[2], tint[3], 1)
		self.forgeState = state
	end
	dropdown.ForgeLook = ForgeLook

	local list = CreateFrame("Frame", nil, dropdown)
	list:SetPoint("TOPRIGHT", dropdown, "BOTTOMRIGHT", 0, -2)
	list:SetWidth(listWidth)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list.bg = Solid(list, "BACKGROUND", Theme.NAV, 1)
	list.bg:SetAllPoints()
	list.border = Border(list, Theme.EDGE, 1)
	-- ascenseur : piste fine à droite, visible seulement si la liste défile
	list.track = Solid(list, "BORDER", Theme.EDGE_SOFT, 1)
	list.track:SetWidth(2)
	list.thumb = Solid(list, "ARTWORK", Theme.GOLD, 0.8)
	list.thumb:SetWidth(2)
	list.rows = {}
	-- thème forgé : la liste ouverte est une carte en relief
	if dropdown.plate then
		list.bg:SetAlpha(0)
		Theme.ForgeHideBorder(list.border)
		list.plate = Theme.ForgeSlice(list, "plate", Theme.FORGE_PLATE.card, { margin = Theme.FORGE.marginSmall })
	end
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
		elseif entry.value == dropdown.value then color = dropdown.plate and Theme.GOLD_LIGHT or Theme.GOLD end
		SetColor(row.label, color)
		if row.hovered and not entry.disabled then row.hover:Show() else row.hover:Hide() end
	end

	-- lignes visibles : options[offset + 1 .. offset + lignes]
	local function Render()
		local count = #dropdown.options
		local shown = math.min(count, dropdown.maxRows)
		dropdown.offset = Clamp(dropdown.offset or 0, 0, math.max(0, count - shown))
		for index = 1, shown do
			local row = list.rows[index]
			local entry = dropdown.options[index + dropdown.offset]
			row.entry = entry
			row.label:SetText(entry.label or tostring(entry.value))
			row.hint:SetText(entry.disabled and entry.hint or "")
			row:Show()
			PaintRow(row)
		end
		for index = shown + 1, #list.rows do list.rows[index]:Hide(); list.rows[index].entry = nil end
		list:SetHeight(shown * Theme.DROPDOWN_ROW + 2)
		if count > shown then
			local trackH = shown * Theme.DROPDOWN_ROW - 4
			list.track:ClearAllPoints()
			list.track:SetPoint("TOPRIGHT", list, "TOPRIGHT", -3, -3)
			list.track:SetHeight(trackH)
			local thumbH = math.max(12, math.floor(trackH * shown / count + 0.5))
			local y = math.floor((trackH - thumbH) * dropdown.offset / (count - shown) + 0.5)
			list.thumb:ClearAllPoints()
			list.thumb:SetPoint("TOPRIGHT", list, "TOPRIGHT", -3, -3 - y)
			list.thumb:SetHeight(thumbH)
			list.track:Show(); list.thumb:Show()
		else
			list.track:Hide(); list.thumb:Hide()
		end
	end
	dropdown.Render = Render

	function dropdown:SetOptions(options)
		self.options = options or {}
		local shown = math.min(#self.options, self.maxRows)
		for index = 1, shown do
			local row = list.rows[index]
			if not row then
				row = CreateFrame("Button", nil, list)
				row:SetSize(listWidth - 2, Theme.DROPDOWN_ROW)
				row.hover = Solid(row, "BACKGROUND", Theme.GOLD, 0.10)
				row.hover:SetAllPoints()
				-- thème forgé : survol en dégradé bleu arcane qui s'estompe
				if dropdown.plate then
					Theme.Gradient(row.hover, "HORIZONTAL", Theme.ACTIVE, Theme.FORGE.rowSelect, Theme.ACTIVE, 0.05)
				end
				row.hover:Hide()
				row.label = Text(row, Theme.F_BODY, Theme.LABEL)
				row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
				row.label:SetJustifyH("LEFT")
				row.hint = Text(row, Theme.F_SMALL, Theme.MUTED)
				row.hint:SetPoint("RIGHT", row, "RIGHT", -10, 0)
				row.hint:SetJustifyH("RIGHT")
				row:SetScript("OnClick", function(selfRow) dropdown:Choose(selfRow.entry and selfRow.entry.value) end)
				row:SetScript("OnEnter", function(selfRow) selfRow.hovered = true; PaintRow(selfRow) end)
				row:SetScript("OnLeave", function(selfRow) selfRow.hovered = false; PaintRow(selfRow) end)
				if row.EnableMouseWheel then row:EnableMouseWheel(true) end
				row:SetScript("OnMouseWheel", function(_, delta) dropdown:Scroll(delta) end)
				list.rows[index] = row
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -1 - (index - 1) * Theme.DROPDOWN_ROW)
		end
		Render()
		self:SetValue(self.value)
	end
	-- molette : delta > 0 remonte la liste
	function dropdown:Scroll(delta)
		self.offset = (self.offset or 0) - (delta > 0 and 1 or -1)
		Render()
		return self.offset
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
	-- la liste s'ouvre vers le bas, ou vers le haut si elle sortirait de
	-- l'écran (`up` : vers le haut d'office)
	function dropdown:Open(up)
		-- une seule liste ouverte à la fois : celle d'à côté se referme
		local other = Theme.openDropdown
		if other and other ~= self and other.IsOpen and other:IsOpen() then other:Close() end
		Theme.openDropdown = self
		-- le choix courant en vue
		for index, entry in ipairs(self.options) do
			if entry.value == self.value and (index <= self.offset or index > self.offset + self.maxRows) then
				self.offset = index - math.floor(self.maxRows / 2)
			end
		end
		Render()
		local bottom = self.GetBottom and tonumber(self:GetBottom())
		if not up and bottom and bottom - (tonumber(list:GetHeight()) or 0) - 2 < 0 then up = true end
		list:ClearAllPoints()
		if up then
			list:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 2)
		else
			list:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
		end
		self.openedUp = up and true or false
		list:Show()
		if self.plate and not self.azSurface then
			ForgeLook(self, "open")
		else
			self.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		end
	end
	function dropdown:Close()
		list:Hide()
		if self.plate and not self.azSurface then
			ForgeLook(self, "rest")
		else
			self.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1)
		end
		if Theme.openDropdown == self then Theme.openDropdown = nil end
	end
	function dropdown:IsOpen() return list:IsShown() and true or false end
	dropdown:SetScript("OnClick", function(self) if self:IsOpen() then self:Close() else self:Open() end end)
	dropdown:SetScript("OnHide", function(self) self:Close() end)
	if dropdown.plate then
		dropdown:SetScript("OnEnter", function(self) if not self:IsOpen() then ForgeLook(self, "hover") end end)
		dropdown:SetScript("OnLeave", function(self) if not self:IsOpen() then ForgeLook(self, "rest") end end)
		ForgeLook(dropdown, "rest")
	end
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
	-- socle 3.2 : thème forgé, la couleur au fond d'un petit creux
	if Theme.Forged() then
		local inset = Theme.FORGE.insetSmall - 1
		Theme.ForgeHideBorder(swatch.border)
		swatch.inset = Theme.ForgeSlice(swatch, "inset", Theme.EDGE, { margin = Theme.FORGE.insetSmall })
		swatch.color:ClearAllPoints()
		swatch.color:SetPoint("TOPLEFT", swatch, "TOPLEFT", inset, -inset)
		swatch.color:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -inset, inset)
	end
	function swatch:SetColor(r, g, b, a)
		self.rgba = { r, g, b, a or 1 }
		self.color:SetVertexColor(r, g, b, a or 1)
	end
	swatch:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	return swatch
end

-- Verrou : case en pointillés, texte pâle (« 30 brillantes ») pour ce qui
-- n'est pas encore gagné. Les pointillés sont des tirets de 3 px.
-- tag:SetText(texte, largeurMax) : au-delà de largeurMax, le texte est coupé
-- (« … » du client) et la case s'arrête à cette largeur.
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
	function tag:SetText(value, maxWidth)
		self.label:SetText(value or "")
		local w = math.floor(((self.label.GetStringWidth and self.label:GetStringWidth()) or 40) + 16 + 0.5)
		maxWidth = tonumber(maxWidth)
		if maxWidth and w > maxWidth then
			w = math.floor(maxWidth)
			self.label:SetWidth(w - 12)
			if self.label.SetWordWrap then self.label:SetWordWrap(false) end
			self.clipped = true
		else
			self.clipped = nil
		end
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
	-- socle 2.11.0 : une disparition en cours est interrompue
	if frame.fadeOut then frame.fadeOut:Stop(); frame.fadeOutPending = nil end
	frame.fadeIn:Stop()
	frame.fadeIn:Play()
	return true
end

-- socle 2.11.0 : pulsations et fondu de sortie en AnimationGroup (n° 24),
-- sans OnUpdate Lua. Vérifié en jeu sur Forever : AnimationGroup:SetLooping,
-- Alpha:SetSmoothing, Scale:SetScaleFrom existent (Scale:SetFromScale NON).
-- Sans l'API, l'effet devient statique (aucune boucle de secours).
-- Demi-périodes (s), reprises des sinus d'avant.
Theme.PULSE = { alert = 0.5, shiny = 0.62, net = 0.52, arrival = 0.63, talk = 0.33, notice = 0.6 }

-- Pulsation aller-retour d'une région : créée une fois (region.pulse),
-- spec = { from, to, period, scale } ; rend le groupe, ou nil
function Theme.Pulse(region, spec)
	if not region then return nil end
	if region.pulse ~= nil then return region.pulse or nil end
	region.pulse = false
	spec = spec or {}
	if not region.CreateAnimationGroup then return nil end
	local ok, group = pcall(region.CreateAnimationGroup, region)
	if not ok or not group or not group.SetLooping or not group.CreateAnimation then return nil end
	group:SetLooping("BOUNCE")
	local alpha = group:CreateAnimation("Alpha")
	if not (alpha and alpha.SetFromAlpha) then return nil end
	alpha:SetFromAlpha(spec.from or 1)
	alpha:SetToAlpha(spec.to or 0.45)
	alpha:SetDuration(spec.period or Theme.PULSE.alert)
	if alpha.SetSmoothing then alpha:SetSmoothing("IN_OUT") end
	if spec.scale then
		local scale = group:CreateAnimation("Scale")
		if scale and scale.SetScaleFrom then
			scale:SetScaleFrom(1, 1)
			scale:SetScaleTo(spec.scale, spec.scale)
			scale:SetDuration(spec.period or Theme.PULSE.alert)
			if scale.SetSmoothing then scale:SetSmoothing("IN_OUT") end
		end
	end
	region.pulse = group
	return group
end

-- Joue (on) ou arrête la pulsation ; à l'arrêt, l'alpha posé revient
-- (l'animation ne touche pas l'alpha de la région). Rend vrai si animé.
function Theme.PulseOn(region, on, spec)
	if not region then return false end
	local group = on and Theme.Pulse(region, spec) or (region.pulse or nil)
	if not group then return false end
	if on then
		local playing = group.IsPlaying and group:IsPlaying()
		if not playing then group:Play() end
		region.pulsing = true
	else
		group:Stop()
		region.pulsing = nil
	end
	return true
end

-- Disparition : fondu (0,2 s), puis Hide et onDone ; sans API, Hide tout
-- de suite. Theme.FadeIn interrompt un fondu de sortie en cours.
function Theme.FadeOut(frame, duration, onDone)
	if not (frame and frame.IsShown and frame:IsShown()) then
		if onDone then onDone() end
		return false
	end
	if frame.fadeIn then frame.fadeIn:Stop() end
	if frame.fadeOut == nil then
		frame.fadeOut = false
		if frame.CreateAnimationGroup then
			local ok, group = pcall(frame.CreateAnimationGroup, frame)
			local alpha = ok and group and group.CreateAnimation and group:CreateAnimation("Alpha")
			if alpha and alpha.SetFromAlpha and group.SetScript then
				alpha:SetFromAlpha(1)
				alpha:SetToAlpha(0)
				alpha:SetDuration(duration or 0.2)
				group:SetScript("OnFinished", function()
					if not frame.fadeOutPending then return end
					frame.fadeOutPending = nil
					frame:Hide()
					local done = frame.onFaded
					frame.onFaded = nil
					if done then done() end
				end)
				frame.fadeOut = group
			end
		end
	end
	if not frame.fadeOut then
		frame:Hide()
		if onDone then onDone() end
		return false
	end
	frame.onFaded = onDone
	frame.fadeOutPending = true
	frame.fadeOut:Stop()
	frame.fadeOut:Play()
	return true
end

-- ---------------------------------------------------------------------------
-- Cadre discret : pas de titre, pas de bouton, un simple filet 1 px sur fond
-- noir translucide. C'est le support du cadre du compagnon : ses cadres et
-- ses fonds gagnés (CompanionData.lua) repeignent ce filet (top, bottom,
-- leftEdge, rightEdge) et ce fond (bg) ; ne pas en changer les champs.
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
	-- thème forgé : bois sombre vers le noir, filets or patiné
	local forged = Theme.ForgeHere("CreateDiscreet")
	if forged then
		local K = Theme.FORGE_DISCREET
		Gradient(frame.bg, "VERTICAL", Theme.SHADOW, K.bottom, Theme.NAV, K.top)
		frame.forged = true
	end

	local function Edge()
		local edge = frame:CreateTexture(nil, "BORDER")
		edge:SetTexture(Theme.SOLID)
		local c = forged and Theme.EDGE or Theme.GOLD_SOFT
		edge:SetVertexColor(c[1], c[2], c[3], forged and Theme.SHADE.veil or 0.45)
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

-- Losange de statut / puce : plein (échec, alerte, puce) ou au trait (OK).
-- Thème forgé : un halo de sa couleur derrière (ART.dot, tex.glow) qui le
-- suit (couleur, affiché / caché).
function Theme.CreateDiamond(parent, size, outline)
	local tex = parent:CreateTexture(nil, "OVERLAY")
	Theme.SetDiamond(tex, outline)
	tex:SetSize(size or 10, size or 10)
	if Theme.ForgeHere("CreateDiamond") and parent.CreateTexture then
		local K = Theme.FORGE_ROW
		local glow = Theme.ArtTexture(parent, "dot", "ARTWORK", 7, Theme.WHITE, K.glowAlpha)
		local side = math.floor((size or 10) * K.glow + 0.5)
		glow:SetSize(side, side)
		glow:SetPoint("CENTER", tex, "CENTER", 0, 0)
		tex.forgeGlow = glow
		local show, hide, tint = tex.Show, tex.Hide, tex.SetVertexColor
		tex.Show = function(self) show(self); glow:Show() end
		tex.Hide = function(self) hide(self); glow:Hide() end
		tex.SetShown = function(self, on) if on then self:Show() else self:Hide() end end
		tex.SetVertexColor = function(self, r, g, b, a)
			tint(self, r, g, b, a)
			glow:SetVertexColor(r, g, b, K.glowAlpha * (a or 1))
		end
	end
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

-- ===========================================================================
-- Briques des fenêtres de modules (refonte 2026-11, lot 3 ; docs/UI.md,
-- « Fenêtres des modules »)
-- ===========================================================================

-- Bouton-icône carré, au trait comme [×] : filet EDGE (ambre au survol),
-- icône du jeu désaturée et estompée au repos, en couleurs au survol.
-- `tip` : texte de l'infobulle (facultatif).
function Theme.CreateIconButton(parent, size, texture, onClick, tip)
	local button = CreateFrame("Button", nil, parent)
	size = size or 24
	button:SetSize(size, size)
	button.border = Border(button, Theme.EDGE, 1)
	button.icon = button:CreateTexture(nil, "OVERLAY")
	button.icon:SetTexture(texture)
	button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.icon:SetSize(size - 8, size - 8)
	-- socle 3.1 : désactivé = filet EDGE_SOFT, icône grise plus pâle, pas de
	-- survol (l'infobulle reste : elle dit à quoi il sert)
	local function Rest(self)
		local off = not ButtonEnabled(self)
		self.disabledLook = off or nil
		if self.icon.SetDesaturated then self.icon:SetDesaturated(true) end
		self.icon:SetAlpha(off and 0.3 or 0.6)
		local edge = off and Theme.DISABLED.edge or Theme.EDGE
		self.border:SetColor(edge[1], edge[2], edge[3], 1)
		if self.forgeLook then self.forgeLook(self, off and "disabled" or "rest") end
	end
	-- socle 3.2 : thème forgé, petite plaque (bronze au survol)
	if Theme.Forged() then Theme.ForgeSmallPlate(button) end
	Rest(button)
	for _, method in ipairs({ "Disable", "Enable", "SetEnabled" }) do
		local original = button[method]
		if type(original) == "function" then
			button[method] = function(self, ...)
				original(self, ...)
				Rest(self)
			end
		end
	end
	button:SetScript("OnEnter", function(self)
		if ButtonEnabled(self) then
			if self.icon.SetDesaturated then self.icon:SetDesaturated(false) end
			self.icon:SetAlpha(1)
			self.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
			if self.forgeLook then self.forgeLook(self, "hover") end
		end
		if tip then
			local tooltip = rawget(_G, "GameTooltip")
			if type(tooltip) == "table" and tooltip.SetOwner then
				tooltip:SetOwner(self, "ANCHOR_BOTTOM")
				Theme.TooltipLine(tooltip, tip, Theme.PARCHMENT)
				tooltip:Show()
			end
		end
	end)
	button:SetScript("OnLeave", function(self)
		Rest(self)
		local tooltip = rawget(_G, "GameTooltip")
		if tip and type(tooltip) == "table" and tooltip.Hide then tooltip:Hide() end
	end)
	Theme.PressFeedback(button, button.icon)
	if onClick then button:SetScript("OnClick", onClick) end
	return button
end

-- Roue crantée : ouvre les réglages de l'addon depuis l'en-tête d'une fenêtre.
-- socle 2.11.0 : la petite roue grise du journal de quêtes du client (atlas
-- « questlog-icon-setting », vérifié en jeu sur Forever ; puis
-- « gm-icon-settings »), sinon le fichier UI-OptionsButton désaturé ; sans
-- carré au trait, grise au repos, plus claire au survol (comme le carnet de
-- QuestCompanion 2.9.1). Plus de « pièce jaune » (INV_Misc_Gear_01).
Theme.GEAR = { size = 16, rest = { 0.78, 0.78, 0.78, 0.85 }, hover = { 1, 1, 1, 1 },
	forgeHover = { Theme.GOLD_LIGHT[1], Theme.GOLD_LIGHT[2], Theme.GOLD_LIGHT[3], 1 } }
local function GearLook(button, hot)
	local c = hot and Theme.GEAR.hover or Theme.GEAR.rest
	-- socle 3.2 : thème forgé, la roue passe à l'or clair au survol
	if hot and button.forgeLook then c = Theme.GEAR.forgeHover end
	if button.icon.SetDesaturated then button.icon:SetDesaturated(true) end
	button.icon:SetVertexColor(c[1], c[2], c[3])
	button.icon:SetAlpha(c[4])
	button.gearHot = hot and true or false
	if button.forgeLook then button.forgeLook(button, hot and "hover" or "rest") end
end
function Theme.CreateGearButton(parent, size, onClick, tip)
	local button = CreateFrame("Button", nil, parent)
	size = size or 22
	button:SetSize(size, size)
	-- pas de carré au trait : contour gardé (champ attendu par les habillages
	-- existants, ns.JournalCogSkin), caché
	button.border = Border(button, Theme.EDGE, 0)
	for _, side in ipairs({ "top", "bottom", "left", "right" }) do button.border[side]:Hide() end
	button.border.SetColor = function() end
	button.icon = button:CreateTexture(nil, "OVERLAY")
	button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.gearSource = Theme.PaintClient(button.icon, "gear")
	button.gearAtlas = button.gearSource ~= "fallback" and button.gearSource or nil
	button.icon:SetSize(Theme.GEAR.size, Theme.GEAR.size)
	if Theme.Forged() then Theme.ForgeSmallPlate(button) end
	GearLook(button, false)
	button:SetScript("OnEnter", function(self)
		GearLook(self, true)
		local tooltip = rawget(_G, "GameTooltip")
		if tip and type(tooltip) == "table" and tooltip.SetOwner then
			tooltip:SetOwner(self, "ANCHOR_BOTTOM")
			Theme.TooltipLine(tooltip, tip, Theme.PARCHMENT)
			tooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function(self)
		GearLook(self, false)
		local tooltip = rawget(_G, "GameTooltip")
		if tip and type(tooltip) == "table" and tooltip.Hide then tooltip:Hide() end
	end)
	Theme.PressFeedback(button, button.icon)
	if onClick then button:SetScript("OnClick", onClick) end
	return button
end

-- Losange de statut : la forme dit l'état autant que la couleur (lisible par
-- un daltonien). Plein = à voir, au trait = bon ou neutre.
Theme.STATUS = {
	ok   = { color = "GREEN",  outline = true },
	info = { color = "BLUE",   outline = true },
	warn = { color = "ORANGE", outline = false },
	bad  = { color = "RED",    outline = false },
	off  = { color = "MUTED",  outline = true },
	item = { color = "GOLD",   outline = true },
}
-- `state` nil ou "none" : losange masqué. Retourne la couleur posée.
function Theme.SetStatus(diamond, state)
	if not diamond then return nil end
	diamond.state = state
	local spec = state and Theme.STATUS[state]
	if not spec then
		diamond:Hide()
		return nil
	end
	local c = Theme[spec.color]
	Theme.SetDiamond(diamond, spec.outline)
	diamond:SetVertexColor(c[1], c[2], c[3], 1)
	diamond:Show()
	return c
end

-- ---------------------------------------------------------------------------
-- Ligne de liste : carte ROW / ROW_ALT (une sur deux), comme les cartes de
-- réglage. opts.status : losange à gauche (taille, ou true = 9) ;
-- opts.icon : icône d'objet (taille) ; opts.detail : texte secondaire aligné
-- à droite ; opts.kind = "Button" : ligne cliquable, éclairée au survol.
-- .text à gauche (après le losange ou l'icône), .control à droite.
-- ---------------------------------------------------------------------------
Theme.LIST_ROW_HEIGHT = 26
Theme.LIST_ROW_GAP = 2
function Theme.CreateListRow(parent, width, height, opts)
	opts = opts or {}
	local row = CreateFrame(opts.kind or "Frame", nil, parent)
	width, height = width or 340, height or Theme.LIST_ROW_HEIGHT
	row:SetSize(width, height)
	row.bg = Solid(row, "BACKGROUND", Theme.ROW, 1)
	row.bg:SetAllPoints()
	-- thème forgé : pas de découpe (une liste en porte beaucoup) : fond en
	-- dégradé qui s'éteint vers la droite ; choisie (row:SetSelected) =
	-- dégradé arcane et barre arcane claire à gauche
	local forged = Theme.ForgeHere("CreateListRow")
	if forged then
		local K = Theme.FORGE_ROW
		row.forged = true
		row.forgeTint = row:CreateTexture(nil, "BACKGROUND", nil, 1)
		row.forgeTint:SetTexture(Theme.SOLID)
		row.forgeTint:SetAllPoints()
		Gradient(row.forgeTint, "HORIZONTAL", Theme.BLUE, K.select.from, Theme.BLUE, K.select.to)
		row.forgeTint:Hide()
		row.forgeBar = Solid(row, "BORDER", Theme.ARCANE_LIGHT, 1)
		row.forgeBar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.forgeBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
		row.forgeBar:SetWidth(Theme.FORGE_NAV.bar)
		row.forgeBar:Hide()
		-- le fond s'éteint vers la droite (voile noir par-dessus)
		row.forgeFade = row:CreateTexture(nil, "BACKGROUND", nil, 1)
		row.forgeFade:SetTexture(Theme.SOLID)
		row.forgeFade:SetAllPoints()
		Gradient(row.forgeFade, "HORIZONTAL", Theme.SHADOW, K.fade.from, Theme.SHADOW, K.fade.to)
	end
	row.hover = Theme.CreateHover(row)
	if opts.kind == "Button" then
		row:SetScript("OnEnter", function(self) self.hover:Show() end)
		row:SetScript("OnLeave", function(self) self.hover:Hide() end)
	end

	local left = 12
	if opts.status then
		local size = tonumber(opts.status) or 9
		row.status = Theme.CreateDiamond(row, size, true)
		row.status:SetPoint("LEFT", row, "LEFT", 12, 0)
		left = 12 + size + 10
	elseif opts.icon then
		local size = tonumber(opts.icon) or 22
		row.icon = Theme.CreateIcon(row, size)
		row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
		left = 6 + size + 10
	end
	row.textLeft = left
	row.text = Text(row, opts.font or Theme.F_BODY, Theme.TEXT)
	row.text:SetPoint("LEFT", row, "LEFT", left, 0)
	row.text:SetJustifyH("LEFT")
	if row.text.SetWordWrap then row.text:SetWordWrap(false) end
	if opts.detail then
		row.detail = Text(row, opts.detailFont or Theme.F_BODY, Theme.MUTED_LIGHT)
		row.detail:SetPoint("RIGHT", row, "RIGHT", -12, 0)
		row.detail:SetJustifyH("RIGHT")
		if row.detail.SetWordWrap then row.detail:SetWordWrap(false) end
	end
	row.control = CreateFrame("Frame", nil, row)
	row.control:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, 0)
	row.control:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 0)
	row.control:SetWidth(math.floor(width / 2))

	function row:SetAlt(alt)
		self.alt = alt and true or false
		local c = self.alt and Theme.ROW_ALT or Theme.ROW
		self.bg:SetVertexColor(c[1], c[2], c[3], 1)
	end
	-- rang dans la liste (1, 2, …) : les rangs pairs en ROW_ALT
	function row:SetIndex(index) self:SetAlt((tonumber(index) or 1) % 2 == 0) end
	-- ligne choisie (forgé : dégradé arcane et barre ; Sobre : rien de dessiné)
	function row:SetSelected(on)
		self.selected = on and true or false
		if self.forgeTint then
			if self.selected then self.forgeTint:Show(); self.forgeBar:Show() else self.forgeTint:Hide(); self.forgeBar:Hide() end
		end
	end
	row:SetAlt(false)
	return row
end

-- ---------------------------------------------------------------------------
-- Bandeau flottant (toast) : fond WINDOW, filet EDGE, barre d'accent à
-- gauche (ambre, ou couleur de statut : toast:SetAccent(c)). Déplaçable en
-- mode édition (souris coupée par défaut, comme les cadres discrets).
-- opts : name, strata (MEDIUM), alpha (0.94), accent (couleur, false = sans).
-- .contentLeft : marge gauche du contenu, après la barre.
-- ---------------------------------------------------------------------------
Theme.TOAST_ACCENT = 3
-- Habille un cadre existant en bandeau : fond, filet, barre d'accent.
-- opts.outset : marge du fond autour du cadre { gauche, haut, droite, bas }
-- (un nombre = les quatre), pour un cadre dont le contenu touche les bords.
function Theme.SkinToast(frame, opts)
	opts = opts or {}
	local o = opts.outset or 0
	if type(o) == "number" then o = { o, o, o, o } end
	frame.chrome = "toast"
	frame.bg = Solid(frame, "BACKGROUND", Theme.WINDOW, opts.alpha or 0.94)
	frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -o[1], o[2])
	frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o[3], -o[4])
	frame.border = Border(frame, Theme.EDGE, 1, "BORDER", frame.bg)
	frame.accent = Solid(frame, "ARTWORK", Theme.GOLD, 1)
	frame.accent:SetPoint("TOPLEFT", frame.bg, "TOPLEFT", 1, -1)
	frame.accent:SetPoint("BOTTOMLEFT", frame.bg, "BOTTOMLEFT", 1, 1)
	frame.accent:SetWidth(Theme.TOAST_ACCENT)
	frame.contentLeft = 1 + Theme.TOAST_ACCENT + 10 - o[1]

	function frame:SetAccent(color)
		if color == false then self.accent:Hide(); return end
		color = color or Theme.GOLD
		self.accentColor = color
		self.accent:SetVertexColor(color[1], color[2], color[3], 1)
		self.accent:Show()
	end
	frame:SetAccent(opts.accent)
	if frame.HookScript then pcall(frame.HookScript, frame, "OnShow", Theme.DressWindow) end
	pcall(Theme.DressWindow, frame)
	return frame
end

function Theme.CreateToast(parent, width, height, opts)
	opts = opts or {}
	local ok, frame = pcall(CreateFrame, "Frame", opts.name, parent or UIParent)
	if not ok or not frame then return nil end
	frame:SetSize(width, height)
	frame:SetFrameStrata(opts.strata or "MEDIUM")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(false)
	frame:SetMovable(true)
	if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
	if frame.StartMoving then frame:SetScript("OnDragStart", frame.StartMoving) end
	if frame.StopMovingOrSizing then frame:SetScript("OnDragStop", frame.StopMovingOrSizing) end
	Theme.SkinToast(frame, opts)
	frame.contentTop = 0
	return frame
end

-- ---------------------------------------------------------------------------
-- Fenêtre de module : Theme.CreateWindow + en-tête compact (logo, titre,
-- sous-titre, filet ambre) + pied facultatif (fond NAV) où s'alignent les
-- boutons (frame:AddFooterButton). .title et .subtitle sont ceux de l'en-tête ;
-- .contentTop = haut de la zone libre sous l'en-tête (négatif, depuis le haut
-- de la fenêtre) ; .pad = marge latérale (20).
-- opts : name, title, subtitle, strata, footer (hauteur, 52 par défaut ;
-- false = sans pied), logo (texture, false = sans).
-- ---------------------------------------------------------------------------
Theme.DIALOG_PAD = 20
Theme.DIALOG_FOOTER = 52
Theme.DIALOG_BUTTON_HEIGHT = 28
function Theme.CreateDialog(parent, width, height, opts)
	opts = opts or {}
	local footer = opts.footer
	if footer == nil then footer = Theme.DIALOG_FOOTER end
	local emblem = Theme.Forged() and opts.logo ~= false
	local frame = Theme.CreateWindow(parent, width, height, { name = opts.name, strata = opts.strata,
		alpha = opts.alpha, footer = footer ~= false and footer or nil, emblem = emblem })
	if not frame then return nil end
	frame.chrome = "dialog"
	frame.pad = Theme.DIALOG_PAD
	frame.close:SetSize(22, 22)
	frame.close:ClearAllPoints()
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -16)

	frame.header = Theme.CreatePageHeader(frame.content, width - 2, { compact = true, logo = opts.logo, pad = Theme.DIALOG_PAD,
		emblem = emblem })
	frame.header:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, 0)
	frame.title, frame.subtitle, frame.logo = frame.header.title, frame.header.subtitle, frame.header.logo
	frame.title:SetText(opts.title or "")
	frame.subtitle:SetText(opts.subtitle or "")
	-- le sous-titre s'arrête avant le [×] (et un bouton-icône à sa gauche)
	local textWidth = width - frame.header.textLeft - Theme.DIALOG_PAD - 2 * (22 + 8)
	frame.subtitle:SetWidth(textWidth)
	if frame.subtitle.SetWordWrap then frame.subtitle:SetWordWrap(false) end
	frame.title:SetWidth(textWidth)
	if frame.title.SetWordWrap then frame.title:SetWordWrap(false) end
	frame.contentTop = -Theme.HEADER_COMPACT_HEIGHT - 1
	frame.innerWidth = width - 2 - 2 * Theme.DIALOG_PAD

	-- boutons du pied : "left" (contour, de gauche à droite), "right" (action
	-- principale, de droite à gauche) ou "center" ; largeur au libellé
	frame.footerButtons = { left = {}, right = {}, center = {} }
	function frame:AddFooterButton(label, onClick, style, side, width)
		local foot = self.footer
		if not foot then return nil end
		side = side or "right"
		local list = self.footerButtons[side] or self.footerButtons.right
		local button = Theme.CreateButton(foot, width or "auto", Theme.DIALOG_BUTTON_HEIGHT, label, onClick, style)
		local previous = list[#list]
		if side == "center" then
			button:SetPoint("CENTER", foot, "CENTER", 0, 0)
		elseif side == "left" then
			if previous then button:SetPoint("LEFT", previous, "RIGHT", 10, 0)
			else button:SetPoint("LEFT", foot, "LEFT", Theme.DIALOG_PAD, 0) end
		else
			if previous then button:SetPoint("RIGHT", previous, "LEFT", -10, 0)
			else button:SetPoint("RIGHT", foot, "RIGHT", -Theme.DIALOG_PAD, 0) end
		end
		list[#list + 1] = button
		return button
	end
	return frame
end

-- ===========================================================================
-- Briques du carnet et du compagnon (refonte 2026-11, lot 4 ; docs/UI.md,
-- « Carnet et compagnon »)
-- ===========================================================================

-- Taille de police d'un rôle (objet du socle), 12 sinon
local ROLE_SIZE = {}
for _, spec in ipairs(Theme.FONT_ROLES) do
	local entry = Theme.fonts[spec.role]
	if entry and entry.name then ROLE_SIZE[entry.name] = spec.size end
end

-- Hauteur d'un texte posé sur `width` px : la mesure du client
-- (GetStringHeight) si elle existe, sinon une estimation (largeur du texte /
-- largeur offerte, 1,25 interligne). Sert à empiler des blocs de texte de
-- haut en bas sans qu'un retour à la ligne en recouvre un autre.
function Theme.TextHeight(fontString, width, font)
	if not fontString then return 0 end
	local measured = fontString.GetStringHeight and tonumber(fontString:GetStringHeight())
	if measured and measured > 0 then return measured end
	local text = tostring(fontString.GetText and fontString:GetText() or "")
	if text == "" then return 0 end
	local size = ROLE_SIZE[font or ""] or 12
	local lines = 0
	local probeParent = fontString.GetParent and fontString:GetParent()
	for line in (text .. "\n"):gmatch("(.-)\n") do
		local w = Theme.TextWidth(probeParent, line, font)
		lines = lines + math.max(1, math.ceil(w / math.max(1, tonumber(width) or 200)))
	end
	return math.ceil(lines * size * 1.25)
end

-- ---------------------------------------------------------------------------
-- Puces de filtre : une rangée de petits boutons au trait (F_BODY), la puce
-- choisie en ambre (filet, texte, fond à 12 %). defs = { { id, label } } ;
-- onSelect(id) au clic. :Select(id, silent) ; .byId[id] = la puce (.text,
-- .selected) ; .used = largeur occupée (pour aligner la rangée à droite).
-- ---------------------------------------------------------------------------
Theme.CHIP_HEIGHT = Theme.CONTROL_HEIGHT
Theme.CHIP_PAD = 24
function Theme.CreateChips(parent, defs, onSelect, opts)
	opts = opts or {}
	local row = CreateFrame("Frame", nil, parent)
	row.chips, row.byId = {}, {}
	local height = tonumber(opts.height) or Theme.CHIP_HEIGHT
	local gap = tonumber(opts.gap) or 6
	-- thème forgé : la puce choisie (un filtre) en bleu arcane : dégradé
	-- vertical, filet arcane clair, texte parchemin ; au repos, filet or sombre
	local forged = Theme.ForgeHere("CreateChips")
	row.forged = forged or nil
	local function Paint(chip)
		local on = row.selected == chip.id
		chip.selected = on
		if forged then
			local K = Theme.FORGE_CHIP
			local edge = on and Theme.ARCANE_LIGHT or (chip.hovered and Theme.EDGE or Theme.EDGE_SOFT)
			chip.border:SetColor(edge[1], edge[2], edge[3], 1)
			Gradient(chip.bg, "VERTICAL", Theme.BLUE, on and K.to or 0, Theme.BLUE, on and K.from or 0)
			SetColor(chip.text, on and Theme.PARCHMENT or (chip.hovered and Theme.LABEL or Theme.MUTED_LIGHT))
			return
		end
		local edge = on and Theme.GOLD or (chip.hovered and Theme.EDGE or Theme.EDGE_SOFT)
		chip.border:SetColor(edge[1], edge[2], edge[3], 1)
		chip.bg:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], on and 0.12 or 0)
		SetColor(chip.text, on and Theme.GOLD or (chip.hovered and Theme.LABEL or Theme.MUTED_LIGHT))
	end
	local x = 0
	for index, def in ipairs(defs or {}) do
		local chip = CreateFrame("Button", nil, row)
		local width = math.ceil(Theme.TextWidth(row, def.label, Theme.F_BODY) + Theme.CHIP_PAD)
		chip:SetSize(width, height)
		chip:SetPoint("LEFT", row, "LEFT", x, 0)
		chip.bg = Solid(chip, "BACKGROUND", Theme.GOLD, 0)
		chip.bg:SetAllPoints()
		chip.border = Border(chip, Theme.EDGE_SOFT, 1)
		chip.text = Text(chip, Theme.F_BODY, Theme.MUTED_LIGHT)
		chip.text:SetPoint("CENTER", chip, "CENTER", 0, 0)
		chip.text:SetText(def.label or tostring(def.id))
		chip.id = def.id
		chip:SetScript("OnClick", function(self) row:Select(self.id) end)
		chip:SetScript("OnEnter", function(self) self.hovered = true; Paint(self) end)
		chip:SetScript("OnLeave", function(self) self.hovered = false; Paint(self) end)
		row.chips[index], row.byId[def.id] = chip, chip
		x = x + width + gap
	end
	row.used = math.max(0, x - gap)
	row:SetSize(math.max(1, row.used), height)
	function row:Select(id, silent)
		if not self.byId[id] then return false end
		self.selected = id
		for _, chip in ipairs(self.chips) do Paint(chip) end
		if onSelect and not silent then onSelect(id) end
		return true
	end
	row.selected = opts.selected or (defs and defs[1] and defs[1].id)
	for _, chip in ipairs(row.chips) do Paint(chip) end
	return row
end

-- ---------------------------------------------------------------------------
-- Tuile : carte cliquable d'une grille (fiche, objet, choix de coffre). Fond
-- ROW, filet EDGE_SOFT (EDGE au survol, ambre si choisie), liseré d'accent
-- facultatif de 3 px (opts.accent = "left" par défaut, "top", false).
-- :SetAccent(couleur | nil), :SetSelected(on), :SetFill(couleur, alpha).
-- Survol et sortie : tile.onEnter(tile) / tile.onLeave(tile), posés par le
-- module (le survol du filet reste celui de la brique).
-- ---------------------------------------------------------------------------
Theme.TILE_ACCENT = 3
function Theme.CreateTile(parent, width, height, opts)
	opts = opts or {}
	local tile = CreateFrame(opts.kind or "Button", nil, parent)
	tile:SetSize(width, height)
	tile.bg = Solid(tile, "BACKGROUND", Theme.ROW, 1)
	tile.bg:SetAllPoints()
	-- thème forgé : le relief d'une carte par-dessus son fond (sans l'ombre du
	-- bas : le filet de la tuile la borde)
	if Theme.ForgeHere("CreateTile") then Theme.ForgeRelief(tile, true) end
	tile.border = Border(tile, Theme.EDGE_SOFT, 1)
	tile.accent = Solid(tile, "ARTWORK", Theme.GOLD, 1)
	if opts.accent == "top" then
		tile.accent:SetPoint("TOPLEFT", tile, "TOPLEFT", 0, 0)
		tile.accent:SetPoint("TOPRIGHT", tile, "TOPRIGHT", 0, 0)
		tile.accent:SetHeight(Theme.TILE_ACCENT)
	else
		tile.accent:SetPoint("TOPLEFT", tile, "TOPLEFT", 0, 0)
		tile.accent:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 0, 0)
		tile.accent:SetWidth(Theme.TILE_ACCENT)
	end
	tile.accent:Hide()
	local function PaintEdge(self)
		local c = self.selected and Theme.ACTIVE or (self.hovered and Theme.EDGE or Theme.EDGE_SOFT)
		self.border:SetColor(c[1], c[2], c[3], 1)
	end
	function tile:SetAccent(color, alpha)
		self.accentColor = color
		if not color or opts.accent == false then self.accent:Hide(); return end
		self.accent:SetVertexColor(color[1], color[2], color[3], alpha or 1)
		self.accent:Show()
	end
	function tile:SetSelected(on) self.selected = on and true or false; PaintEdge(self) end
	function tile:SetFill(color, alpha)
		color = color or Theme.ROW
		self.bg:SetVertexColor(color[1], color[2], color[3], alpha or 1)
	end
	tile:SetScript("OnEnter", function(self)
		self.hovered = true
		PaintEdge(self)
		if self.onEnter then self.onEnter(self) end
	end)
	tile:SetScript("OnLeave", function(self)
		self.hovered = false
		PaintEdge(self)
		if self.onLeave then self.onLeave(self) end
	end)
	tile:SetSelected(false)
	return tile
end

-- ---------------------------------------------------------------------------
-- Étiquette : petit texte F_CAPS en capitales sur un fond teinté à 16 %
-- (rang d'une créature, état). :SetTag(texte, couleur) ; vide = cachée.
-- ---------------------------------------------------------------------------
Theme.TAG_HEIGHT = 15
function Theme.CreateTag(parent, text, color)
	local tag = CreateFrame("Frame", nil, parent)
	tag.bg = Solid(tag, "BACKGROUND", Theme.GOLD, 0.16)
	tag.bg:SetAllPoints()
	tag.label = Text(tag, Theme.F_CAPS, Theme.GOLD)
	tag.label:SetPoint("CENTER", tag, "CENTER", 0, 0)
	-- thème forgé : un filet de sa couleur autour
	if Theme.ForgeHere("CreateTag") then tag.forgeEdge = Border(tag, Theme.GOLD, Theme.FORGE_TAG.edge) end
	function tag:SetTag(value, c)
		value = value and Theme.Upper(value) or ""
		c = c or Theme.GOLD
		self.label:SetText(value)
		self.color = c
		SetColor(self.label, c)
		self.bg:SetVertexColor(c[1], c[2], c[3], 0.16)
		if self.forgeEdge then self.forgeEdge:SetColor(c[1], c[2], c[3], Theme.FORGE_TAG.edge) end
		self:SetSize(math.ceil(Theme.TextWidth(self, value, Theme.F_CAPS) + 10), Theme.TAG_HEIGHT)
		if value == "" then self:Hide() else self:Show() end
	end
	tag:SetTag(text, color)
	return tag
end

-- ---------------------------------------------------------------------------
-- socle 3.0 : pastille de monnaie (solde de paillettes de QuestCompanion),
-- comme les monnaies du client : cadre FIELD au filet EDGE, à la hauteur
-- d'une rangée d'outils, icône du client, chiffre F_NUMBER ambre, libellé
-- F_SMALL MUTED clair. opts = { icon, label, tip = { titre, lignes } }.
-- :SetValue(n, libellé) recalcule la largeur (posée par TOPRIGHT, elle
-- grandit vers la gauche) ; :Flash() secoue la pastille et la rougit un
-- instant (solde trop court) ; animations créées une fois, sans OnUpdate.
-- ---------------------------------------------------------------------------
Theme.CURRENCY = { pad = 8, icon = 16, gap = 5, labelGap = 4, shake = { 4, -8, 8, -4 }, step = 0.05, flash = 0.45,
	flashAlpha = 0.35 }
function Theme.CreateCurrency(parent, opts)
	opts = opts or {}
	local C = Theme.CURRENCY
	local badge = CreateFrame("Frame", nil, parent)
	badge:SetSize(80, Theme.CONTROL_HEIGHT)
	badge.bg = Solid(badge, "BACKGROUND", Theme.FIELD, 1)
	badge.bg:SetAllPoints()
	badge.border = Border(badge, Theme.EDGE, 1)
	-- thème forgé : un creux (ART.inset, filet or patiné) à la place du fond
	-- et du filet plats
	if Theme.ForgeHere("CreateCurrency") then
		badge.forgeInset = Theme.Slice(badge, "inset", { layer = "BACKGROUND", sub = 1, margin = Theme.FORGE_INSET.margin,
			color = Theme.EDGE })
		badge.bg:SetAlpha(0)
		badge.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 0)
	end
	badge.flash = Solid(badge, "ARTWORK", Theme.RED, C.flashAlpha)
	badge.flash:SetPoint("TOPLEFT", badge, "TOPLEFT", 1, -1)
	badge.flash:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -1, 1)
	badge.flash:Hide()
	badge.icon = badge:CreateTexture(nil, "OVERLAY")
	badge.icon:SetSize(C.icon, C.icon)
	badge.icon:SetPoint("LEFT", badge, "LEFT", C.pad, 0)
	badge.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if opts.icon then pcall(badge.icon.SetTexture, badge.icon, opts.icon) end
	badge.value = Text(badge, Theme.F_NUMBER, Theme.GOLD)
	badge.value:SetPoint("LEFT", badge.icon, "RIGHT", C.gap, 0)
	badge.label = Text(badge, Theme.F_SMALL, Theme.MUTED_LIGHT)
	badge.label:SetPoint("LEFT", badge.value, "RIGHT", C.labelGap, 0)
	badge.tip = opts.tip
	function badge:SetValue(n, label)
		local value = tostring(math.floor(tonumber(n) or 0))
		label = label or opts.label or ""
		self.amount = tonumber(n) or 0
		self.value:SetText(value)
		self.label:SetText(label)
		local width = C.pad + C.icon + C.gap + Theme.TextWidth(self, value, Theme.F_NUMBER)
		if label ~= "" then width = width + C.labelGap + Theme.TextWidth(self, label, Theme.F_SMALL) end
		self:SetWidth(math.ceil(width + C.pad + 2))
		return self.amount
	end
	-- la secousse : quatre pas de translation, construits une fois
	if badge.CreateAnimationGroup then
		local ok, group = pcall(badge.CreateAnimationGroup, badge)
		if ok and group and group.CreateAnimation then
			for index, dx in ipairs(C.shake) do
				local move = group:CreateAnimation("Translation")
				if move and move.SetOffset then
					move:SetOffset(dx, 0)
					move:SetDuration(C.step)
					if move.SetOrder then move:SetOrder(index) end
				end
			end
			badge.shake = group
		end
	end
	function badge:Flash()
		self.flashes = (self.flashes or 0) + 1
		if self.shake then self.shake:Stop(); self.shake:Play() end
		self.flash:SetAlpha(1)
		self.flash:Show()
		Theme.FadeOut(self.flash, C.flash)
		return self.flashes
	end
	if badge.EnableMouse then badge:EnableMouse(true) end
	badge:SetScript("OnEnter", function(self)
		local tooltip = rawget(_G, "GameTooltip")
		local tip = self.tip
		if not (tip and type(tooltip) == "table" and tooltip.SetOwner) then return end
		tooltip:SetOwner(self, "ANCHOR_BOTTOM")
		Theme.TooltipTitle(tooltip, tip[1])
		for _, line in ipairs(tip[2] or {}) do Theme.TooltipHint(tooltip, line, true) end
		tooltip:Show()
	end)
	badge:SetScript("OnLeave", function()
		local tooltip = rawget(_G, "GameTooltip")
		if type(tooltip) == "table" and tooltip.Hide then tooltip:Hide() end
	end)
	badge:SetValue(opts.value or 0)
	return badge
end

-- ---------------------------------------------------------------------------
-- Pagination d'une grille ou d'une liste : « 1-15 / 42 » (F_SMALL, MUTED
-- clair) et deux boutons-icônes chevron (haut, bas), alignés à droite.
-- onStep(1) remonte, onStep(-1) descend (comme la molette).
-- :Update(décalage, page, total, décalageMax).
-- ---------------------------------------------------------------------------
Theme.PAGER_HEIGHT = 22
function Theme.CreatePager(parent, onStep)
	local pager = CreateFrame("Frame", nil, parent)
	pager:SetSize(200, Theme.PAGER_HEIGHT)
	pager.down = Theme.CreateIconButton(pager, Theme.PAGER_HEIGHT, nil, function() if onStep then onStep(-1) end end)
	pager.down:SetPoint("RIGHT", pager, "RIGHT", 0, 0)
	pager.up = Theme.CreateIconButton(pager, Theme.PAGER_HEIGHT, nil, function() if onStep then onStep(1) end end)
	pager.up:SetPoint("RIGHT", pager.down, "LEFT", -6, 0)
	-- le chevron pointe vers le bas : retourné pour « haut » (socle 2.11.0 :
	-- flèche du client, tournée d'un demi-tour ; 2.12.1 : plus de repli)
	for _, button in ipairs({ pager.down, pager.up }) do Theme.PaintClient(button.icon, "chevron") end
	if pager.up.icon.clientSource and pager.up.icon.SetRotation then
		pager.up.icon:SetRotation(math.pi)
	end
	pager.position = Text(pager, Theme.F_SMALL, Theme.MUTED_LIGHT)
	pager.position:SetPoint("RIGHT", pager.up, "LEFT", -10, 0)
	pager.position:SetJustifyH("RIGHT")
	function pager:Update(offset, page, total, maxOffset)
		offset, page, total = tonumber(offset) or 0, tonumber(page) or 0, tonumber(total) or 0
		maxOffset = tonumber(maxOffset) or math.max(0, total - page)
		self.position:SetText(total > page and string.format("%d-%d / %d", offset + 1, math.min(total, offset + page), total) or "")
		if offset > 0 then self.up:Show() else self.up:Hide() end
		if offset < maxOffset then self.down:Show() else self.down:Hide() end
	end
	pager:Update(0, 0, 0, 0)
	return pager
end

-- ---------------------------------------------------------------------------
-- Bulle de parole : fond WINDOW, filet EDGE, filet ambre en haut, pointe en
-- losange sous la bulle (au trait EDGE), texte F_BODY clair centré.
-- bubble:SetText(texte, extra) donne à la bulle la hauteur du texte, plus
-- `extra` px (des boutons dessous). opts : name, strata (HIGH).
-- ---------------------------------------------------------------------------
Theme.BUBBLE_PAD = 10
Theme.BUBBLE_MIN = 34
function Theme.CreateBubble(parent, width, opts)
	opts = opts or {}
	local ok, bubble = pcall(CreateFrame, "Frame", opts.name, parent or UIParent)
	if not ok or not bubble then return nil end
	bubble:SetSize(width, Theme.BUBBLE_MIN)
	bubble:SetFrameStrata(opts.strata or "HIGH")
	bubble:SetClampedToScreen(true)
	bubble:EnableMouse(false)
	bubble.chrome = "bubble"
	bubble.bg = Solid(bubble, "BACKGROUND", Theme.WINDOW, 0.96)
	bubble.bg:SetAllPoints()
	bubble.border = Border(bubble, Theme.EDGE, 1)
	if Theme.ForgeHere("CreateBubble") then
		-- thème forgé : notre filet lumineux en haut, qui s'éteint vers la droite
		bubble.rule = Theme.ArtTexture(bubble, "line", "ARTWORK", 0, Theme.GOLD_LIGHT, Theme.FORGE_RULE.alpha)
		bubble.rule:SetHeight(Theme.FORGE_RULE.height)
		bubble.forged = true
	else
		bubble.rule = Solid(bubble, "ARTWORK", Theme.GOLD, 1)
		bubble.rule:SetHeight(2)
	end
	bubble.rule:SetPoint("TOPLEFT", bubble, "TOPLEFT", 1, -1)
	bubble.rule:SetPoint("TOPRIGHT", bubble, "TOPRIGHT", -1, -1)
	-- pointe : un losange EDGE (sa moitié haute sous le fond), un losange
	-- WINDOW plus petit par-dessus, qui efface le filet du bas à cet endroit
	bubble.tailEdge = bubble:CreateTexture(nil, "BACKGROUND", nil, -8)
	Theme.SetDiamond(bubble.tailEdge)
	bubble.tailEdge:SetVertexColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1)
	bubble.tailEdge:SetSize(14, 14)
	bubble.tailEdge:SetPoint("CENTER", bubble, "BOTTOM", 0, 0)
	bubble.tail = bubble:CreateTexture(nil, "ARTWORK")
	Theme.SetDiamond(bubble.tail)
	bubble.tail:SetVertexColor(Theme.WINDOW[1], Theme.WINDOW[2], Theme.WINDOW[3], 1)
	bubble.tail:SetSize(12, 12)
	bubble.tail:SetPoint("CENTER", bubble, "BOTTOM", 0, 1)
	local pad = Theme.BUBBLE_PAD
	bubble.text = Text(bubble, Theme.F_BODY, Theme.LABEL)
	bubble.text:SetPoint("TOPLEFT", bubble, "TOPLEFT", pad, -pad - 1)
	bubble.text:SetWidth(width - 2 * pad)
	bubble.text:SetJustifyH("CENTER")
	if bubble.text.SetWordWrap then bubble.text:SetWordWrap(true) end
	function bubble:SetText(value, extra)
		self.text:SetText(value or "")
		local h = Theme.TextHeight(self.text, width - 2 * pad, Theme.F_BODY)
		local height = math.max(Theme.BUBBLE_MIN, math.ceil(h + 2 * pad + 2 + (tonumber(extra) or 0)))
		self:SetHeight(height)
		self.textHeight = h
		return height
	end
	return bubble
end

-- ---------------------------------------------------------------------------
-- Infobulle du jeu (GameTooltip) aux couleurs du thème : titre ambre, texte
-- courant, aide MUTED clair, paire libellé / valeur.
-- ---------------------------------------------------------------------------
function Theme.TooltipLine(tooltip, text, color, wrap)
	if type(tooltip) ~= "table" or type(tooltip.AddLine) ~= "function" then return end
	color = color or Theme.TEXT
	tooltip:AddLine(text, color[1], color[2], color[3], wrap and true or nil)
end
function Theme.TooltipTitle(tooltip, text) Theme.TooltipLine(tooltip, text, Theme.GOLD) end
function Theme.TooltipHint(tooltip, text, wrap) Theme.TooltipLine(tooltip, text, Theme.MUTED_LIGHT, wrap) end
function Theme.TooltipPair(tooltip, label, value)
	if type(tooltip) ~= "table" then return end
	if type(tooltip.AddDoubleLine) == "function" then
		tooltip:AddDoubleLine(label, value, Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3],
			Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
	else
		Theme.TooltipLine(tooltip, tostring(label) .. " : " .. tostring(value))
	end
end

-- ===========================================================================
-- Thèmes (socle 3.2) : Sobre (ardoise et ambre, à plat) et Azeroth (bois,
-- or patiné, Friz Quadrata, accent arcane). Un thème ne reconstruit rien :
-- il change les jetons que lisent toutes les briques, la police des titres,
-- et pose l'habillage forgé des fenêtres (cadre d'orfèvre, ombre, coins,
-- médaillon), fait de nos textures (tools/gen_ui_assets.py).
--   Theme.ApplySkin(id) : pose le thème (jetons modifiés SUR PLACE : les
--     tables gardent leur identité, tout ce qui les lit suit). Une fenêtre
--     déjà construite garde ses couleurs jusqu'au rechargement de
--     l'interface ; le cadre en bois, lui, suit à l'affichage suivant.
--   Theme.skin : le thème posé ; Theme.Forged() : thème Azeroth (forgé).
-- Les encres du texte courant (TEXT, MUTED, LABEL, PARCHMENT) ne changent
-- pas, et les fonds restent aussi sombres : les contrastes mesurés tiennent
-- (recalculés pour le thème dans tests/modules/ui_skin.lua).
-- ===========================================================================
Theme.SKINS = { "azeroth", "sobre" }
Theme.SKIN_DEFAULT = "azeroth"
Theme.SKIN_FONT = "Fonts\\FRIZQT__.TTF"
-- rôles de police qui passent en Friz Quadrata (titres et sections ; le
-- corps de texte garde sa police, plus lisible en petit)
Theme.SKIN_FONT_ROLES = { "DISPLAY", "TITLE", "CAPS" }
Theme.SKIN_TOKENS = {
	azeroth = {
		EDGE      = { 0.60, 0.42, 0.18 },    -- or patiné : bord de fenêtre, bouton en contour
		EDGE_SOFT = { 0.30, 0.22, 0.12 },    -- or sombre : filets, séparations
		NAV       = { 0.086, 0.063, 0.047 }, -- bois sombre : colonne, pied, plaque de titre
		TITLE     = { 0.96, 0.78, 0.49 },    -- or clair (= GOLD_LIGHT)
		ACTIVE    = { 0.357, 0.561, 0.839 }, -- bleu arcane (= BLUE)
	},
	sobre = {},
}
-- Matières du thème forgé : nos textures (tools/gen_ui_assets.py, dans
-- Libs/Socle/Media). size : côté de la texture ; margin : largeur d'un coin
-- de la découpe en 9 tranches (px de la texture, rendus tels quels à l'écran).
Theme.ART = {
	frame    = { file = SOCLE_MEDIA .. "cadre",  size = 64, margin = 16 },   -- cadre d'orfèvre (en couleurs)
	shadow   = { file = SOCLE_MEDIA .. "ombre",  size = 64, margin = 28 },   -- ombre portée
	corner   = { file = SOCLE_MEDIA .. "coin",   size = 64 },                -- coin haut gauche, retourné pour les autres
	plate    = { file = SOCLE_MEDIA .. "plaque", size = 32, margin = 8 },    -- plaque en relief (grise : se teinte)
	inset    = { file = SOCLE_MEDIA .. "creux",  size = 32, margin = 8 },    -- creux (gris : le filet prend la teinte)
	line     = { file = SOCLE_MEDIA .. "lueur_ligne" },                      -- filet lumineux (blanc : se teinte)
	dot      = { file = SOCLE_MEDIA .. "lueur_point" },                      -- point lumineux (blanc : se teinte)
	vignette = { file = SOCLE_MEDIA .. "vignette" },                         -- bords assombris
}
-- géométrie de l'habillage d'une fenêtre
Theme.CHROME = { shadowOut = 20, frameOut = 1, corner = 46, cornerOut = 3, min = 40, level = 30 }
-- le médaillon du logo : taille, débord hors du coin haut gauche, et où
-- commence le texte de l'en-tête à sa droite
Theme.EMBLEM = { size = 84, x = -24, y = 28, text = 72 }

local skinBase = {}
function Theme.ApplySkin(id)
	if not Theme.SKIN_TOKENS[id] then id = "sobre" end
	local tokens = Theme.SKIN_TOKENS[id]
	-- les valeurs de départ, gardées une fois (retour à Sobre)
	for _, skin in pairs(Theme.SKIN_TOKENS) do
		for key in pairs(skin) do
			if not skinBase[key] and type(Theme[key]) == "table" then
				skinBase[key] = { Theme[key][1], Theme[key][2], Theme[key][3] }
			end
		end
	end
	for key, base in pairs(skinBase) do
		local value = tokens[key] or base
		local token = Theme[key]
		token[1], token[2], token[3] = value[1], value[2], value[3]
	end
	-- la police des titres : celle du jeu en Azeroth, la nôtre en Sobre
	local file
	for _, role in ipairs(Theme.SKIN_FONT_ROLES) do
		local entry = Theme.fonts and Theme.fonts[role]
		if entry and entry.object and type(entry.object.SetFont) == "function" then
			file = id == "azeroth" and Theme.SKIN_FONT or entry.file
			local ok, applied = pcall(entry.object.SetFont, entry.object, file, entry.size, "")
			-- refusée : la police d'avant est reposée
			if not ok or applied == false then pcall(entry.object.SetFont, entry.object, entry.file, entry.size, "") end
			entry.skinFont = (ok and applied ~= false) and file or entry.file
		end
	end
	Theme.FONT_TITLE = id == "azeroth" and Theme.SKIN_FONT or Theme.FONT_BOLD
	Theme.skin = id
	return id
end

-- Le thème forgé est-il posé ? (ses matières sont les nôtres : toujours là)
function Theme.Forged() return Theme.skin == "azeroth" end

-- Découpe en 9 tranches d'une matière (Theme.ART) autour de `around` (ou du
-- cadre) : quatre coins à leur taille, quatre bords et un centre étirés.
-- opts : layer, sub (sous-couche), out (débord en px), margin (taille d'un
-- coin à l'écran, celle de la texture par défaut), fill (false : sans centre),
-- color { r, g, b }, alpha, around. Rend { parts, SetColor, SetAlpha, SetShown }.
function Theme.Slice(frame, art, opts)
	opts = opts or {}
	local spec = type(art) == "table" and art or Theme.ART[art]
	if not (frame and spec and spec.margin) then return nil end
	local layer, sub = opts.layer or "BACKGROUND", opts.sub or 0
	local m, out = tonumber(opts.margin) or spec.margin, tonumber(opts.out) or 0
	local k = spec.margin / spec.size
	local around = opts.around or frame
	local slice = { parts = {}, art = spec, margin = m, out = out }
	local function Part(key, l, r, t, b)
		local tex = frame:CreateTexture(nil, layer, nil, sub)
		tex:SetTexture(spec.file)
		tex:SetTexCoord(l, r, t, b)
		slice.parts[key] = tex
		return tex
	end
	local tl = Part("tl", 0, k, 0, k)
	tl:SetSize(m, m); tl:SetPoint("TOPLEFT", around, "TOPLEFT", -out, out)
	local tr = Part("tr", 1 - k, 1, 0, k)
	tr:SetSize(m, m); tr:SetPoint("TOPRIGHT", around, "TOPRIGHT", out, out)
	local bl = Part("bl", 0, k, 1 - k, 1)
	bl:SetSize(m, m); bl:SetPoint("BOTTOMLEFT", around, "BOTTOMLEFT", -out, -out)
	local br = Part("br", 1 - k, 1, 1 - k, 1)
	br:SetSize(m, m); br:SetPoint("BOTTOMRIGHT", around, "BOTTOMRIGHT", out, -out)
	local function Span(key, l, r, t, b, a1, p1, a2, p2)
		local tex = Part(key, l, r, t, b)
		tex:SetPoint("TOPLEFT", a1, p1, 0, 0)
		tex:SetPoint("BOTTOMRIGHT", a2, p2, 0, 0)
		return tex
	end
	Span("t", k, 1 - k, 0, k, tl, "TOPRIGHT", tr, "BOTTOMLEFT")
	Span("b", k, 1 - k, 1 - k, 1, bl, "TOPRIGHT", br, "BOTTOMLEFT")
	Span("l", 0, k, k, 1 - k, tl, "BOTTOMLEFT", bl, "TOPRIGHT")
	Span("r", 1 - k, 1, k, 1 - k, tr, "BOTTOMLEFT", br, "TOPRIGHT")
	if opts.fill ~= false then Span("c", k, 1 - k, k, 1 - k, tl, "BOTTOMRIGHT", br, "TOPLEFT") end
	function slice:SetColor(r, g, b, a)
		self.color = self.color or {}
		self.color[1], self.color[2], self.color[3], self.color[4] = r, g, b, a or 1
		for _, tex in pairs(self.parts) do tex:SetVertexColor(r, g, b, a or 1) end
	end
	function slice:SetAlpha(a) for _, tex in pairs(self.parts) do tex:SetAlpha(a) end end
	function slice:SetShown(on)
		self.shown = on and true or false
		for _, tex in pairs(self.parts) do if on then tex:Show() else tex:Hide() end end
	end
	function slice:Show() self:SetShown(true) end
	function slice:Hide() self:SetShown(false) end
	slice.shown = true
	if opts.color then slice:SetColor(opts.color[1], opts.color[2], opts.color[3], opts.alpha) end
	return slice
end

-- [controles]
-- Contrôles forgés (thème Azeroth) : boutons en plaque de relief teintée,
-- champs et pistes en creux, coche et curseur qui luisent. Décidé à la
-- création (Theme.Forged()) : en Sobre, les mêmes régions qu'avant, rien de
-- plus. Les couleurs vivent ici, jamais en dur dans les fabriques.
-- Teintes de la plaque (ART.plate, grise : luminance 0,885 en haut, 0,50 en
-- bas, reflet d'un pixel à 1,0) : la couleur vue = teinte x niveau.
Theme.FORGE_PLATE = {
	neutral  = { 0.165, 0.196, 0.239 },  -- bouton secondaire (ardoise)
	bronze   = { 0.400, 0.290, 0.150 },  -- accent : bronze, libellé or
	gold     = { 1.000, 0.820, 0.500 },  -- principal : or, encre sombre
	green    = { 0.180, 0.370, 0.230 },  -- ajouter, rallumer
	red      = { 0.400, 0.170, 0.150 },  -- retirer, détruire
	arcane   = { 0.210, 0.350, 0.560 },  -- action neutre (ouvrir, changer)
	card     = { 0.118, 0.145, 0.176 },  -- liste déroulante ouverte
	thumb    = { 0.420, 0.450, 0.500 },  -- curseur d'un interrupteur coupé
	thumbOn  = { 0.357, 0.561, 0.839 },  -- curseur d'un interrupteur actif (= BLUE)
	disabled = { 0.150, 0.160, 0.170 },  -- désactivé : désaturé, sombre
}
-- Encres posées sur ces plaques (mesurées : tests/modules/ui_forge_controles.lua)
Theme.FORGE_INK = {
	gold   = { 0.060, 0.040, 0.010 },    -- encre sombre sur l'or, sans ombre
	green  = { 0.770, 0.950, 0.790 },
	red    = { 0.960, 0.730, 0.690 },
	arcane = { 0.860, 0.910, 1.000 },
}
-- Style de bouton (Theme.BUTTON_STYLES) -> plaque et encre en thème forgé
Theme.FORGE_BUTTONS = {
	outline   = { plate = "neutral", text = Theme.LABEL },
	accent    = { plate = "bronze", text = Theme.GOLD_LIGHT },
	primary   = { plate = "gold", text = Theme.FORGE_INK.gold, noShadow = true, press = 0.96 },
	adventure = { plate = "gold", text = Theme.FORGE_INK.gold, noShadow = true, press = 0.96 },
	add       = { plate = "green", text = Theme.FORGE_INK.green },
	danger    = { plate = "red", text = Theme.FORGE_INK.red },
	arcane    = { plate = "arcane", text = Theme.FORGE_INK.arcane },
}
Theme.FORGE_BUTTONS.normal = Theme.FORGE_BUTTONS.outline
-- Géométrie et états. hover : part de blanc mêlée à la teinte au survol ;
-- press : facteur de la teinte à l'appui (en plus du libellé enfoncé d'un
-- pixel ; l'or garde le sien, plus doux, pour son encre). label : niveaux de
-- la plaque sous un libellé (tranche du centre, rangées 8 à 23 de la texture),
-- le plus clair et le plus sombre, pour les contrastes. insetFill : niveau du
-- fond d'un creux (le filet du bas est à 1,0).
Theme.FORGE = {
	margin = 7, marginSmall = 5, smallBelow = 24, insetMargin = 6, insetSmall = 4,
	hover = 0.12, press = 0.85,
	label = { light = 0.786, dark = 0.593 }, insetFill = 0.14,
	track = { 0.020, 0.027, 0.039 },          -- fond d'une piste (curseur, barre)
	trackRim = 0.07,                          -- filet clair sous une piste (blanc, alpha)
	trackShade = 0.6,                         -- ombre d'un pixel en haut d'une piste (noir, alpha)
	sheen = 0.45,                             -- reflet d'un pixel en haut d'un remplissage (blanc, alpha)
	fillLow = 0.62, fillHigh = 0.15,          -- remplissage : bas = couleur x 0,62 ; haut = 15 % de blanc
	sliderTrack = 5, thumb = { 9, 15 },       -- curseur : piste, poignée
	thumbTop = { 1.0, 1.0, 1.0 }, thumbBottom = { 0.741, 0.718, 0.663 },
	goldDeep = { 0.541, 0.365, 0.133 },       -- départ du remplissage doré (#8a5d22)
	glow = 0.75, glowSize = 2.4,              -- lueur (ART.dot) : alpha, taille x l'élément
	checkGlow = { size = 1.5, alpha = 0.35 }, -- lueur de la coche, discrète (la case reste lisible)
	tick = 1.15,                              -- coche (UI-CheckBox-Check, marges comprises) : x la case
	caret = { 7, 5, 3, 1 },                   -- chevron d'une liste : rangées du triangle
	led = 20, ledOff = { 0.21, 0.23, 0.26 },  -- voyant d'un module (interrupteur de navigation)
	rowSelect = 0.45,                         -- ligne choisie d'une liste : bleu arcane, alpha de départ
}

-- Teinte multipliée (survol, appui), bornée à 1
function Theme.ForgeTint(color, factor)
	factor = tonumber(factor) or 1
	return { math.min(1, color[1] * factor), math.min(1, color[2] * factor), math.min(1, color[3] * factor) }
end
-- Survol : la teinte éclaircie vers le blanc (FORGE.hover), sans changer de
-- teinte quand une composante est déjà à 1 (l'or)
function Theme.ForgeHover(color)
	return Theme.Over(color, Theme.WHITE, Theme.FORGE.hover)
end
-- Couleur vue d'une matière teinte à un niveau de sa texture (contrastes)
function Theme.ForgeSurface(tint, level)
	return { tint[1] * level, tint[2] * level, tint[3] * level }
end
-- Coin de la découpe à l'écran selon la hauteur du contrôle
function Theme.ForgeMargin(height, inset)
	local F = Theme.FORGE
	height = tonumber(height) or F.smallBelow
	if inset then return height < F.smallBelow - 4 and F.insetSmall or F.insetMargin end
	return height < F.smallBelow and F.marginSmall or F.margin
end
-- Plaque ou creux d'un contrôle (9 tranches), teinte posée
function Theme.ForgeSlice(frame, art, tint, opts)
	opts = opts or {}
	local height = opts.height or (frame.GetHeight and frame:GetHeight())
	local slice = Theme.Slice(frame, art, { layer = opts.layer or "BACKGROUND", sub = opts.sub or -2,
		margin = opts.margin or Theme.ForgeMargin(height, art == "inset"), around = opts.around })
	if slice and tint then slice:SetColor(tint[1], tint[2], tint[3], opts.alpha) end
	return slice
end
-- Lueur (ART.dot teinte) derrière `around`, cachée par défaut
function Theme.ForgeGlow(frame, around, color, size, layer, sub, alpha)
	local glow = frame:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	glow:SetTexture(Theme.ART.dot.file)
	glow:SetSize(size, size)
	glow:SetPoint("CENTER", around or frame, "CENTER", 0, 0)
	glow:SetVertexColor(color[1], color[2], color[3], alpha or Theme.FORGE.glow)
	if glow.SetBlendMode then glow:SetBlendMode("ADD") end
	glow:Hide()
	return glow
end
-- Contour d'un pixel du Sobre gardé (les modules et les tests le lisent)
-- mais caché : le relief le remplace
function Theme.ForgeHideBorder(border)
	if type(border) ~= "table" then return end
	for _, side in ipairs({ "top", "bottom", "left", "right" }) do
		if border[side] and border[side].Hide then border[side]:Hide() end
	end
end
-- Petite plaque d'un bouton dessiné ([×], bouton-icône, roue crantée) :
-- neutre au repos, bronze au survol, assombrie à l'appui, éteinte désactivée.
-- Le contour d'un pixel est caché (Theme.PressFeedback le recolore encore).
-- Pose button.plate et button.forgeLook(button, état).
function Theme.ForgeSmallPlate(button)
	Theme.ForgeHideBorder(button.border)
	button.plate = Theme.ForgeSlice(button, "plate", Theme.FORGE_PLATE.neutral, { margin = Theme.FORGE.marginSmall })
	button.forgeLook = function(self, state)
		local P, F = Theme.FORGE_PLATE, Theme.FORGE
		local tint = P.neutral
		if state == "hover" then tint = Theme.ForgeHover(P.bronze)
		elseif state == "pressed" then tint = Theme.ForgeTint(P.bronze, F.press)
		elseif state == "disabled" then tint = P.disabled end
		self.forgeState = state
		if self.plate then self.plate:SetColor(tint[1], tint[2], tint[3], 1) end
	end
	button.forgeLook(button, "rest")
	return button.plate
end
-- Remplissage d'une barre ou d'un curseur : dégradé vertical (bas sombre,
-- haut éclairci) de la couleur
function Theme.ForgeFill(tex, color, alpha)
	local F = Theme.FORGE
	local low = Theme.ForgeTint(color, F.fillLow)
	local high = Theme.Over(color, Theme.WHITE, F.fillHigh)
	return Theme.Gradient(tex, "VERTICAL", low, alpha or 1, high, alpha or 1)
end

-- L'habillage forgé d'une fenêtre ou d'un bandeau : ombre portée, bords
-- assombris, cadre d'orfèvre, coins, et le médaillon du logo si la fenêtre le
-- demande (frame.wantsEmblem). Créé au premier besoin, montré en thème
-- Azeroth, caché sinon (le filet d'un pixel revient). Le cadre, les coins et
-- le médaillon vivent sur un cadre à part, au-dessus des enfants de la
-- fenêtre (une colonne ou un pied les recouvriraient), sans souris.
-- Une fenêtre déjà habillée par son module (frame.azeroth : le carnet de
-- QuestCompanion) ou trop petite n'en reçoit pas.
function Theme.DressWindow(frame)
	if not frame then return false end
	local K = Theme.CHROME
	local want = Theme.Forged() and not frame.skinNoChrome and not frame.azeroth and frame.uiStyle ~= "azeroth"
	if want and frame.GetWidth and frame.GetHeight then
		want = (tonumber(frame:GetWidth()) or 0) >= K.min and (tonumber(frame:GetHeight()) or 0) >= K.min
	end
	local chrome = frame.skinChrome
	if want and not chrome then
		chrome = {}
		chrome.shadow = Theme.Slice(frame, "shadow", { layer = "BACKGROUND", sub = -8, out = K.shadowOut })
		local ok, top = pcall(CreateFrame, "Frame", nil, frame)
		top = ok and top or frame
		if top ~= frame then
			top:SetAllPoints(frame)
			if top.SetFrameLevel and frame.GetFrameLevel then top:SetFrameLevel((tonumber(frame:GetFrameLevel()) or 1) + K.level) end
			if top.EnableMouse then top:EnableMouse(false) end
		end
		chrome.top = top
		chrome.frame = Theme.Slice(top, "frame", { layer = "BORDER", out = K.frameOut, fill = false })
		if frame.chrome ~= "toast" then
			chrome.vignette = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
			chrome.vignette:SetTexture(Theme.ART.vignette.file)
			chrome.vignette:SetAllPoints(frame)
			chrome.corners = {}
			local o = K.cornerOut
			for _, c in ipairs({ { "TOPLEFT", -o, o, 0, 1, 0, 1 }, { "TOPRIGHT", o, o, 1, 0, 0, 1 },
				{ "BOTTOMLEFT", -o, -o, 0, 1, 1, 0 }, { "BOTTOMRIGHT", o, -o, 1, 0, 1, 0 } }) do
				local tex = top:CreateTexture(nil, "ARTWORK")
				tex:SetTexture(Theme.ART.corner.file)
				tex:SetTexCoord(c[4], c[5], c[6], c[7])
				tex:SetSize(K.corner, K.corner)
				tex:SetPoint(c[1], frame, c[1], c[2], c[3])
				chrome.corners[#chrome.corners + 1] = tex
			end
		end
		frame.skinChrome = chrome
	end
	if chrome then
		-- le médaillon : demandé après coup aussi (frame.wantsEmblem posé par le module)
		if want and frame.wantsEmblem and not chrome.emblem and frame.chrome ~= "toast" then
			local E = Theme.EMBLEM
			chrome.emblem = chrome.top:CreateTexture(nil, "OVERLAY")
			chrome.emblem:SetTexture(Theme.LOGO)
			chrome.emblem:SetSize(E.size, E.size)
			chrome.emblem:SetPoint("TOPLEFT", frame, "TOPLEFT", E.x, E.y)
		end
		chrome.shadow:SetShown(want)
		chrome.frame:SetShown(want)
		if chrome.vignette then if want then chrome.vignette:Show() else chrome.vignette:Hide() end end
		for _, tex in ipairs(chrome.corners or {}) do if want then tex:Show() else tex:Hide() end end
		if chrome.emblem then if want and frame.wantsEmblem then chrome.emblem:Show() else chrome.emblem:Hide() end end
	end
	-- le filet d'un pixel de la fenêtre : remplacé par le cadre forgé
	if frame.border and frame.border.SetColor then
		frame.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], want and 0 or 1)
	end
	-- la fenêtre reste à l'écran, médaillon compris
	if frame.SetClampRectInsets and (chrome or frame.skinDressed ~= nil) then
		local E = Theme.EMBLEM
		local emblem = want and frame.wantsEmblem and chrome and chrome.emblem
		pcall(frame.SetClampRectInsets, frame, emblem and E.x or 0, 0, emblem and E.y or 0, 0)
	end
	frame.skinDressed = want and true or false
	return frame.skinDressed
end

-- [navigation]
-- Thème forgé : navigation, sections, cartes et listes. Les couleurs disent
-- le sens : or = principal, bleu arcane = choisi / navigation. Rien n'est
-- posé en Sobre (mêmes régions qu'avant) ; la décision se prend à la
-- création de la brique (changer de thème demande un rechargement).
Theme.ARCANE_LIGHT = { 0.561, 0.722, 0.941 }  -- bleu arcane clair #8fb8f0 (barre de l'entrée choisie)
-- deux tons de lueur : or (par défaut) et arcane (choix, navigation)
Theme.FORGE_TONES = {
	gold   = { color = Theme.GOLD, light = Theme.GOLD_LIGHT },
	arcane = { color = Theme.BLUE, light = Theme.ARCANE_LIGHT },
}
-- filet lumineux (ART.line) : hauteur de la lueur, décalage vers le haut
-- pour rester centré sur l'ancien filet de 2 px
Theme.FORGE_RULE = { height = 6, lift = 2, alpha = 1 }
-- colonne de navigation : fond d'une entrée en retrait du bord (voile de
-- survol, dégradé arcane du choix et sa barre claire, reflet d'un pixel),
-- titres de groupe en « pilule » (dégradé de leur ton, filet, reflet), voyant
-- de module (point vert lumineux / point sombre)
Theme.FORGE_NAV = {
	inset = 10, insetRight = 8, hover = 0.05, hoverEdge = 0.6, sheen = 0.08, bar = 2,
	select = { from = 0.55, to = 0.07 },
	pill = { from = 0.27, to = 0.03, edge = 0.22, sheen = 0.06, padX = 8, padY = 5, right = 8 },
	led = { size = 16, glow = 16, core = 7, offCore = 11, off = { 0.36, 0.39, 0.43 }, hover = 0.35 },
	shade = { from = 0.34, to = 0.05 },  -- colonne : plus sombre au bord gauche
	edgeLight = 0.04,                    -- reflet d'un pixel à droite du séparateur noir
	offInk = Theme.MUTED_LIGHT,          -- titre de groupe d'un module coupé, lisible sur sa pilule
}
-- titre de section : point lumineux, titre de son ton, filet qui s'éteint à droite
Theme.FORGE_SECTION = { dot = 18, dotX = -5, text = 12, lineGap = 8, line = 6 }
-- onglets : l'onglet choisi en dégradé arcane (vers le bas), souligné clair ;
-- filet noir sous la rangée et reflet d'un pixel dessous
Theme.FORGE_TABS = { from = 0.28, to = 0.02, sheen = 0.07, rule = 0.9, ruleLight = 0.05 }
-- carte de réglage, tuile : relief posé sur le fond (pas de découpe en 9 :
-- une page de réglages en porte des dizaines, toutes construites à
-- l'ouverture) : voile blanc en haut (light) qui passe au noir en bas (dark),
-- reflet d'un pixel en haut, ombre d'un pixel en bas. Le fond garde sa
-- couleur (ROW / ROW_ALT, ou celle du module).
Theme.FORGE_CARD = { light = 0.045, dark = 0.30, sheen = 0.07, shade = 0.55 }
-- ligne de liste : pas de fond (survol voilé), choisie = dégradé arcane et
-- barre claire ; losange de statut avec un halo de sa couleur (ART.dot)
Theme.FORGE_ROW = { select = { from = 0.25, to = 0.04 }, glow = 2.6, glowAlpha = 0.9, fade = { from = 0, to = 0.55 } }
-- en-tête de page : plaque de bois au haut plus chaud ; pied : bande plus
-- sombre et reflet d'un pixel sous son filet noir
Theme.FORGE_HEADER = { warm = { 0.235, 0.165, 0.086 }, top = 0.7, bottom = 0.30 }
Theme.FORGE_FOOT = { from = 0.38, to = 0.12, sheen = 0.045 }
-- étiquette : filet de sa couleur ; pastille de monnaie : creux (ART.inset)
Theme.FORGE_TAG = { edge = 0.35 }
Theme.FORGE_INSET = { margin = 6 }
-- puce choisie (filtres) : dégradé arcane, filet clair
Theme.FORGE_CHIP = { from = 0.30, to = 0.08 }
-- cadre discret : bois sombre vers le noir
Theme.FORGE_DISCREET = { top = 0.80, bottom = 0.62 }

-- Le thème forgé s'applique-t-il aux briques ? Non en Sobre ; non plus
-- pendant qu'un module rhabille lui-même ce qu'il construit en enveloppant
-- des fabriques (carnet de QuestCompanion en Azeroth : Theme[nom] est alors
-- son enveloppe) : rien de forgé ne doit passer sous son habit, même d'une
-- brique qu'il n'enveloppe pas (titre de groupe, losange, filet).
local FORGE_OWN = {}
for _, name in ipairs({ "CreateGlowRule", "CreatePageHeader", "CreateNavBrand", "CreateNavGroup", "CreateNavItem",
	"CreateTabs", "CreateSection", "CreateHover", "CreateSettingCard", "CreateDiamond", "CreateListRow", "CreateChips",
	"CreateTile", "CreateTag", "CreateCurrency", "CreatePager", "CreateBubble", "CreateDiscreet" }) do
	FORGE_OWN[name] = Theme[name]
end
local FORGE_WATCH = { "CreateTile", "CreateListRow", "CreateChips", "CreateTag", "CreateNavItem", "CreatePageHeader",
	"CreateSection", "CreateCurrency", "CreateButton", "CreateDropdown", "CreateSearchBox", "CreateBar", "Text" }
local FORGE_SEEN = {}
for _, name in ipairs(FORGE_WATCH) do FORGE_SEEN[name] = Theme[name] end
function Theme.ForgeHere(name)
	if not Theme.Forged() then return false end
	if name and FORGE_OWN[name] ~= nil and Theme[name] ~= FORGE_OWN[name] then return false end
	for _, watched in ipairs(FORGE_WATCH) do
		if Theme[watched] ~= FORGE_SEEN[watched] then return false end
	end
	return true
end

-- Une texture de nos matières (Theme.ART), teinte posée
function Theme.ArtTexture(parent, art, layer, sub, color, alpha)
	local spec = Theme.ART[art]
	local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	tex:SetTexture(spec and spec.file or Theme.SOLID)
	color = color or Theme.WHITE
	tex:SetVertexColor(color[1], color[2], color[3], alpha or 1)
	return tex
end

-- Reflet (ou ombre) d'un pixel en haut (ou en bas) d'un cadre
function Theme.ForgeEdgeLine(frame, where, color, alpha, layer)
	local tex = Solid(frame, layer or "BORDER", color or Theme.WHITE, alpha or 0.06)
	local top = where ~= "bottom"
	tex:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT", frame, top and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
	tex:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT", frame, top and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
	tex:SetHeight(1)
	return tex
end

-- Relief d'une carte, posé sur son fond : voile vertical (plus clair en
-- haut, plus sombre en bas), reflet d'un pixel en haut, ombre d'un pixel en
-- bas (sauf `noShade`). frame.forgeRelief, .forgeSheen, .forgeShade.
function Theme.ForgeRelief(frame, noShade)
	if not frame or frame.forgeRelief then return false end
	local K = Theme.FORGE_CARD
	frame.forged = true
	frame.forgeRelief = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	frame.forgeRelief:SetTexture(Theme.SOLID)
	frame.forgeRelief:SetAllPoints()
	Gradient(frame.forgeRelief, "VERTICAL", Theme.SHADOW, K.dark, Theme.WHITE, K.light)
	frame.forgeSheen = Theme.ForgeEdgeLine(frame, "top", Theme.WHITE, K.sheen)
	if not noShade then frame.forgeShade = Theme.ForgeEdgeLine(frame, "bottom", Theme.SHADOW, K.shade) end
	return true
end

-- Voyant de module (navigation des réglages). En Sobre : l'interrupteur du
-- thème (Theme.CreatePowerButton). Forgé : un bouton rond, point vert
-- lumineux si le module est actif, point sombre s'il est coupé ; un halo
-- clair au survol (couche HIGHLIGHT : le client le montre seul).
-- `forge` : décision de la brique appelante (nil : le thème posé).
function Theme.CreateNavPower(parent, size, forge)
	if forge == nil then forge = Theme.ForgeHere() end
	if not forge then return Theme.CreatePowerButton(parent, size) end
	local K = Theme.FORGE_NAV.led
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(size or K.size, size or K.size)
	button.led = true
	button.glow = Theme.ArtTexture(button, "dot", "ARTWORK", 0, Theme.GREEN, 1)
	button.glow:SetSize(K.glow, K.glow)
	button.glow:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.core = Theme.ArtTexture(button, "dot", "ARTWORK", 1, K.off, 1)
	button.core:SetSize(K.core, K.core)
	button.core:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.highlight = Theme.ArtTexture(button, "dot", "HIGHLIGHT", 0, Theme.WHITE, K.hover)
	button.highlight:SetAllPoints()
	return button
end
function Theme.SetNavPower(button, on)
	if not (button and button.led) then return Theme.SetPowerState(button, on) end
	button.on = on and true or false
	local K = Theme.FORGE_NAV.led
	if on then
		button.glow:Show()
		button.core:SetVertexColor(Theme.GREEN[1], Theme.GREEN[2], Theme.GREEN[3], 1)
		button.core:SetSize(K.core, K.core)
	else
		button.glow:Hide()
		button.core:SetVertexColor(K.off[1], K.off[2], K.off[3], 1)
		button.core:SetSize(K.offCore, K.offCore)
	end
end

-- Pied d'une fenêtre, forgé : bande plus sombre en haut, filet noir, reflet
-- d'un pixel dessous. Une fois par pied ; rien en Sobre.
function Theme.ForgeFooter(footer)
	if not (footer and Theme.ForgeHere()) or footer.forged then return false end
	local K = Theme.FORGE_FOOT
	footer.forgeShade = footer:CreateTexture(nil, "BACKGROUND", nil, 1)
	footer.forgeShade:SetTexture(Theme.SOLID)
	footer.forgeShade:SetAllPoints()
	Gradient(footer.forgeShade, "VERTICAL", Theme.SHADOW, K.to, Theme.SHADOW, K.from)
	if footer.line then footer.line:SetVertexColor(Theme.SHADOW[1], Theme.SHADOW[2], Theme.SHADOW[3], 1) end
	footer.forgeSheen = Solid(footer, "BORDER", Theme.WHITE, K.sheen)
	footer.forgeSheen:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, -1)
	footer.forgeSheen:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, -1)
	footer.forgeSheen:SetHeight(1)
	footer.forged = true
	return true
end

-- Colonne de navigation, forgée : plus sombre au bord gauche, séparateur
-- noir et reflet d'un pixel à sa droite. Une fois ; rien en Sobre.
function Theme.ForgeNavColumn(nav)
	if not (nav and Theme.ForgeHere()) or nav.forged then return false end
	local K = Theme.FORGE_NAV
	nav.forgeShade = nav:CreateTexture(nil, "BACKGROUND", nil, 1)
	nav.forgeShade:SetTexture(Theme.SOLID)
	nav.forgeShade:SetAllPoints()
	Gradient(nav.forgeShade, "HORIZONTAL", Theme.SHADOW, K.shade.from, Theme.SHADOW, K.shade.to)
	if nav.separator then nav.separator:SetVertexColor(Theme.SHADOW[1], Theme.SHADOW[2], Theme.SHADOW[3], 1) end
	nav.forgeEdge = Solid(nav, "BORDER", Theme.WHITE, K.edgeLight)
	nav.forgeEdge:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
	nav.forgeEdge:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 0, 0)
	nav.forgeEdge:SetWidth(1)
	nav.forged = true
	return true
end

-- Le thème choisi par le joueur : celui de l'addon s'il a son propre réglage
-- (QuestCompanion : ns:UIStyle), sinon le réglage `uiStyle` du socle
function ns:UISkinChoice()
	-- (le style réellement affiché : Sobre si le client n'a pas ses textures)
	if self.UIStyle then return self:UIStyle() end
	local choice = self:DB().uiStyle
	for _, id in ipairs(Theme.SKINS) do if id == choice then return id end end
	return Theme.SKIN_DEFAULT
end
function ns:SetUISkin(id)
	if self.SetUIStyle then return self:SetUIStyle(id) end
	local valid = false
	for _, known in ipairs(Theme.SKINS) do if known == id then valid = true end end
	if not valid then return nil end
	self:DB().uiStyle = id
	Theme.ApplySkin(id)
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return id
end
Theme.skin = "sobre"

if ns.Mark then ns.Mark("Theme") end
end)(SOCLE_ADDON, SOCLE_NS)
