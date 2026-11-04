-- Theme.lua -- identité visuelle « carnet de route » (v1.20.0)
--
-- L'addon ressemblait à un morceau de l'interface Blizzard (liseré or,
-- fond d'infobulle, boutons UIPanelButtonTemplate). Il a désormais sa propre
-- identité, appliquée partout avec les mêmes règles :
--   * surfaces plates ardoise, filets fins, coin d'accent ambre ;
--   * une seule couleur d'accent, l'ambre, réservée à ce qui compte (page
--     active, valeur, action principale, marque) ; vert/ambre/rouge = statut ;
--   * une police de titre embarquée (Alegreya Bold, OFL, Fonts/) pour les
--     titres et la note ; le texte courant reste en GameFont, lisible partout ;
--   * des contrôles dessinés par l'addon (boutons, interrupteurs, losanges),
--     sans dépendre d'aucun template : rien ne casse si Forever change son art.
-- Textures : celles du socle (Libs/Socle/Media : losange.tga, losange_trait.tga,
-- police Alegreya) et le logo de chaque addon (Textures/logo.tga, logo_petit.tga).
-- Tout le reste n'utilise que Interface\Buttons\WHITE8X8, teinté.
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
Theme.GOLD_SOFT = { 0.73, 0.47, 0.17 }   -- ambre sombre #b9782c (sections)
Theme.GOLD_DIM  = { 0.17, 0.19, 0.22 }   -- filets #2a3138
Theme.PARCHMENT = { 0.95, 0.91, 0.83 }   -- titres #f1e8d4
Theme.TEXT      = { 0.85, 0.83, 0.78 }   -- texte courant #d9d4c7
Theme.MUTED     = { 0.49, 0.51, 0.54 }   -- texte secondaire #7d8389
Theme.INK       = { 0.06, 0.07, 0.09 }
Theme.SURFACE   = { 0.075, 0.09, 0.105 } -- fond des fenêtres #13171b
Theme.SURFACE_2 = { 0.06, 0.07, 0.085 }  -- colonne de navigation #0f1215
Theme.CONTROL   = { 0.16, 0.19, 0.21 }   -- piste, bouton au repos #2a3036
Theme.GREEN     = { 0.44, 0.81, 0.48 }   -- statut OK #6fcf7a (pas le vert de rareté)
Theme.RED       = { 0.89, 0.38, 0.31 }   -- statut échec #e2604f
Theme.ORANGE    = { 0.91, 0.65, 0.29 }   -- statut alerte = l'ambre
Theme.GREY      = { 0.55, 0.55, 0.55 }
-- Deuxième couleur (v1.21.0) : bleu de nuit, l'aiguille de la boussole.
-- Rôle : information et navigation (groupes, statut « info », source d'une
-- zone apprise), et depuis la v1.25.0 l'appel au départ « Partir à
-- l'aventure » (choix de l'utilisateur : c'est la couleur de l'aiguille, celle
-- du voyage). Jamais un statut.
Theme.BLUE      = { 0.357, 0.561, 0.839 } -- #5b8fd6

Theme.T_GOLD      = "|cffe8a54b"
Theme.T_PARCHMENT = "|cfff1e8d4"
Theme.T_GREY      = "|cff7d8389"
Theme.T_GREEN     = "|cff6fcf7a"
Theme.T_RED       = "|cffe2604f"
Theme.T_ORANGE    = "|cffe8a54b"
Theme.T_WHITE     = "|cffffffff"
Theme.T_BLUE      = "|cff5b8fd6"

Theme.BG_DARK  = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
Theme.BG_LIGHT = "Interface\\DialogFrame\\UI-DialogBox-Background"
Theme.SOLID    = "Interface\\Buttons\\WHITE8X8"
Theme.LOGO          = MEDIA .. "Textures\\logo"         -- logo de l'addon (boussole R2Q, dragonnet QC)
Theme.LOGO_SMALL    = MEDIA .. "Textures\\logo_petit"   -- petites tailles : bandeaux, minicarte
Theme.DIAMOND       = SOCLE_MEDIA .. "losange"
Theme.DIAMOND_LINE  = SOCLE_MEDIA .. "losange_trait"
-- Flèche de rafraîchissement : l'icône du jeu (fichier 851904), présente dans
-- les clients Era 1.15.9 et Forever 1.60.1 (listes de fichiers wago.tools).
-- Elle est jaune : on la désature au repos plutôt que de la teinter.
Theme.REFRESH       = "Interface\\Buttons\\UI-RefreshButton"
Theme.FONT_TITLE    = SOCLE_MEDIA .. "Alegreya-Bold.ttf"

Theme.F_TITLE  = "GameFontNormalLarge"
Theme.F_NORMAL = "GameFontHighlight"
Theme.F_BODY   = "GameFontHighlightSmall"
Theme.F_NUMBER = "NumberFontNormal"
Theme.F_SMALL  = "GameFontNormalSmall"

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

-- Police de titre : appliquée sur une FontString existante. Si le client
-- refuse le fichier (chemin, format), on garde la police GameFont d'origine.
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

-- ---------------------------------------------------------------------------
-- Fenêtre : surface plate, filet 1 px, coin ambre, bandeau avec la marque
-- ---------------------------------------------------------------------------
local function BuildHeader(frame, titleText, options)
	frame.logo = frame:CreateTexture(nil, "OVERLAY")
	frame.logo:SetTexture(Theme.LOGO_SMALL)
	frame.logo:SetSize(18, 18)
	frame.logo:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -9)

	frame.title = Theme.CreateTitle(frame, options.titleSize or 15)
	frame.title:SetPoint("LEFT", frame.logo, "RIGHT", 7, 0)
	frame.title:SetText(titleText or "")

	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.subtitle:SetPoint("RIGHT", frame, "TOPRIGHT", -34, -18)
	frame.subtitle:SetText("")
	frame.subtitle:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])

	frame.headerLine = Solid(frame, "ARTWORK", Theme.GOLD_DIM, 1)
	frame.headerLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -34)
	frame.headerLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -34)
	frame.headerLine:SetHeight(1)

	-- bouton de fermeture dessiné : un « x » dans un carré, pas UIPanelCloseButton
	local close = CreateFrame("Button", nil, frame)
	close:SetSize(20, 20)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
	close.border = Border(close, Theme.CONTROL, 1)
	close.label = close:CreateFontString(nil, "OVERLAY", Theme.F_NORMAL)
	close.label:SetPoint("CENTER", 0, 1)
	close.label:SetText("x")
	close.label:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	close:SetScript("OnEnter", function() close.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1) end)
	close:SetScript("OnLeave", function() close.border:SetColor(Theme.CONTROL[1], Theme.CONTROL[2], Theme.CONTROL[3], 1) end)
	close:SetScript("OnClick", function() frame:Hide() end)
	frame.close = close
end

function Theme.CreatePanel(parent, width, height, titleText, options)
	options = options or {}
	local ok, frame = pcall(CreateFrame, "Frame", options.name, parent or UIParent)
	if not ok or not frame then frame = CreateFrame("Frame", options.name, parent or UIParent) end
	if not frame then return nil end

	frame.bg = Solid(frame, "BACKGROUND", Theme.SURFACE, options.alpha or 0.97)
	frame.bg:SetAllPoints()
	-- (pas de reflet : sans dégradé, un aplat plus clair laisse une marche
	-- visible au tiers de la fenêtre)
	frame.border = Border(frame, { 0.17, 0.20, 0.235 }, 1)
	frame.accentH, frame.accentV = CornerAccent(frame)
	frame.chrome = "flat"

	frame:SetSize(width, height)
	frame:SetFrameStrata(options.strata or "DIALOG")
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	if options.title ~= false then
		BuildHeader(frame, titleText, options)
		frame.contentTop = -36
	else
		frame.contentTop = -10
	end

	Theme.RegisterEscapeClose(frame)
	return frame
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
	local line = Solid(parent, "ARTWORK", Theme.GOLD_DIM, 1)
	line:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y or 0)
	line:SetSize(width or 100, 1)
	return line
end

-- ---------------------------------------------------------------------------
-- Bouton dessiné : fond ardoise, filet, libellé ; `primary` = plein ambre.
-- Plus de UIPanelButtonTemplate : l'apparence ne dépend plus du client.
-- ---------------------------------------------------------------------------
function Theme.CreateButton(parent, width, height, label, onClick, style)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, height)
	button.style = style or "normal"

	-- "primary" = plein ambre ; "adventure" = plein bleu de nuit (départ)
	local fill = (button.style == "primary" and Theme.GOLD) or (button.style == "adventure" and Theme.BLUE) or nil
	local primary = fill ~= nil
	button.bg = Solid(button, "BACKGROUND", fill or { 0.085, 0.10, 0.12 }, 1)
	button.bg:SetAllPoints()
	button.border = Border(button, fill or { 0.23, 0.26, 0.29 }, 1)

	button.text = button:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	button.text:SetPoint("CENTER", 0, 0)
	button.text:SetText(label)
	if primary then
		button.text:SetTextColor(0.08, 0.09, 0.11)
	else
		button.text:SetTextColor(0.81, 0.78, 0.72)
	end
	button.SetText = function(self, text) self.text:SetText(text) end
	button.GetText = function(self) return self.text:GetText() end

	-- survol : le filet passe à l'ambre
	button:SetScript("OnEnter", function(self)
		if not primary then self.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1) end
	end)
	button:SetScript("OnLeave", function(self)
		if not primary then self.border:SetColor(0.23, 0.26, 0.29, 1) end
	end)
	if onClick then button:SetScript("OnClick", onClick) end
	return button
end

-- ---------------------------------------------------------------------------
-- Interrupteur : piste 30 x 14, curseur carré ; ambre quand il est actif
-- ---------------------------------------------------------------------------
-- `kind` = "Button" pour un interrupteur cliquable à lui seul (navigation) ;
-- `width`/`height` : 30 x 14 par défaut, 22 x 10 en version compacte.
function Theme.CreateToggle(parent, width, height, kind)
	local toggle = CreateFrame(kind or "Frame", nil, parent)
	width, height = width or 30, height or 14
	toggle:SetSize(width, height)
	toggle.track = Solid(toggle, "BACKGROUND", Theme.CONTROL, 1)
	toggle.track:SetAllPoints()
	toggle.edge = Border(toggle, Theme.GOLD, 0)
	toggle.knob = Solid(toggle, "ARTWORK", { 0.48, 0.51, 0.53 }, 1)
	toggle.knob:SetSize(height - 4, height - 4)

	-- partiel : une partie seulement des modules est active (contour ambre,
	-- curseur gris au centre)
	function toggle:SetPartial()
		self.checked, self.partial = nil, true
		self.knob:ClearAllPoints()
		self.knob:SetPoint("CENTER", self, "CENTER", 0, 0)
		self.knob:SetVertexColor(0.62, 0.64, 0.66, 1)
		self.track:SetVertexColor(Theme.CONTROL[1], Theme.CONTROL[2], Theme.CONTROL[3], 1)
		self.edge:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
	end

	function toggle:SetChecked(on)
		self.checked = on and true or false
		self.partial = nil
		self.knob:ClearAllPoints()
		if self.checked then
			self.knob:SetPoint("RIGHT", self, "RIGHT", -2, 0)
			self.knob:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
			self.track:SetVertexColor(Theme.GOLD[1] * 0.25, Theme.GOLD[2] * 0.25, Theme.GOLD[3] * 0.25, 1)
			self.edge:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		else
			self.knob:SetPoint("LEFT", self, "LEFT", 2, 0)
			self.knob:SetVertexColor(0.48, 0.51, 0.53, 1)
			self.track:SetVertexColor(Theme.CONTROL[1], Theme.CONTROL[2], Theme.CONTROL[3], 1)
			self.edge:SetColor(0, 0, 0, 0)
		end
	end
	toggle:SetChecked(false)
	return toggle
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
function Theme.ScoreColor(ratio)
	if ratio >= 0.85 then return Theme.GREEN end
	if ratio >= 0.55 then return Theme.ORANGE end
	return Theme.RED
end

if ns.Mark then ns.Mark("Theme") end
