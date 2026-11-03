-- Theme.lua -- direction artistique World of Warcraft
--
-- Principe : uniquement des textures dont la présence est confirmée dans le
-- client (référencées par le code de Blizzard lui-même) :
--   Interface\DialogFrame\UI-DialogBox-Background
--   Interface\DialogFrame\UI-DialogBox-Background-Dark
--   Interface\Buttons\UI-Panel-Button-Up / Down / Disabled / Highlight
--   Interface\Buttons\WHITE8X8
-- Plus les polices natives GameFont* / NumberFont* et ITEM_QUALITY_COLORS.
--
-- Le cadre doré est dessiné (bordures 1 px teintées) plutôt que délégué à un
-- template NineSlice : Forever utilise une déclinaison d'art « Camelot »
-- propre, et un layout NineSlice nommé pourrait ne pas exister.
local ADDON, ns = ...

local Theme = {}
ns.Theme = Theme

-- ---------------------------------------------------------------------------
-- Palette
-- ---------------------------------------------------------------------------
Theme.GOLD      = { 1.00, 0.82, 0.00 }
Theme.GOLD_SOFT = { 0.85, 0.68, 0.25 }
Theme.GOLD_DIM  = { 0.45, 0.36, 0.10 }
Theme.PARCHMENT = { 0.97, 0.90, 0.75 }
Theme.INK       = { 0.06, 0.05, 0.04 }
-- vert de statut adouci : le vert vif 1eff00 est celui de la rareté
-- « Inhabituel », et un statut ne doit pas se lire comme un objet
Theme.GREEN     = { 0.40, 0.84, 0.36 }
Theme.RED       = { 0.90, 0.20, 0.15 }
Theme.ORANGE    = { 1.00, 0.55, 0.10 }
Theme.GREY      = { 0.55, 0.55, 0.55 }

Theme.T_GOLD      = "|cffffd100"
Theme.T_PARCHMENT = "|cfff8e6c0"
Theme.T_GREY      = "|cff8c8c8c"
Theme.T_GREEN     = "|cff66d65c"
Theme.T_RED       = "|cffff2020"
Theme.T_ORANGE    = "|cffff8c1a"
Theme.T_WHITE     = "|cffffffff"

-- Textures natives
Theme.BG_DARK  = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
Theme.BG_LIGHT = "Interface\\DialogFrame\\UI-DialogBox-Background"
Theme.SOLID    = "Interface\\Buttons\\WHITE8X8"

-- Polices natives
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

-- ---------------------------------------------------------------------------
-- Cadre doré dessiné : fond tiled + liseré or + bandeau de titre
-- ---------------------------------------------------------------------------
local function BuildChrome(frame, background)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile   = background,
			edgeFile = Theme.SOLID,
			tile = true, tileSize = 32, edgeSize = 2,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		})
		if frame.SetBackdropColor then
			frame:SetBackdropColor(1, 1, 1, 1)
		end
		if frame.SetBackdropBorderColor then
			frame:SetBackdropBorderColor(Theme.GOLD_DIM[1], Theme.GOLD_DIM[2], Theme.GOLD_DIM[3], 1)
		end
	end

	-- Filet intérieur clair : donne l'effet « double liseré » des cadres WoW
	frame.innerLine = frame:CreateTexture(nil, "BORDER")
	frame.innerLine:SetTexture(Theme.SOLID)
	frame.innerLine:SetVertexColor(Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3], 0.35)
	frame.innerLine:SetPoint("TOPLEFT", 3, -3)
	frame.innerLine:SetPoint("TOPRIGHT", -3, -3)
	frame.innerLine:SetHeight(1)
end

-- ---------------------------------------------------------------------------
-- Fond d'infobulle + bord d'infobulle : c'est ce qu'utilise AtlasLootClassic
-- pour ses fenêtres. Plus sobre qu'une fenêtre natale à fond de pierre.
-- ---------------------------------------------------------------------------
Theme.BACKDROP_TOOLTIP = {
	bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

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

-- Bandeau de titre : bande sombre + filet doré + titre + sous-titre + croix
local function BuildHeader(frame, width, titleText)
	frame.header = frame:CreateTexture(nil, "BORDER")
	frame.header:SetTexture(Theme.SOLID)
	frame.header:SetVertexColor(0, 0, 0, 0.72)
	frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
	frame.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
	frame.header:SetHeight(22)

	frame.headerGloss = frame:CreateTexture(nil, "BORDER")
	frame.headerGloss:SetTexture(Theme.SOLID)
	frame.headerGloss:SetVertexColor(Theme.GOLD_DIM[1], Theme.GOLD_DIM[2], Theme.GOLD_DIM[3], 0.28)
	frame.headerGloss:SetPoint("TOPLEFT", frame.header, "TOPLEFT", 0, 0)
	frame.headerGloss:SetPoint("TOPRIGHT", frame.header, "TOPRIGHT", 0, 0)
	frame.headerGloss:SetHeight(9)

	frame.headerLine = frame:CreateTexture(nil, "ARTWORK")
	frame.headerLine:SetTexture(Theme.SOLID)
	frame.headerLine:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 0.70)
	frame.headerLine:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, 0)
	frame.headerLine:SetPoint("TOPRIGHT", frame.header, "BOTTOMRIGHT", 0, 0)
	frame.headerLine:SetHeight(1)

	frame.title = frame:CreateFontString(nil, "OVERLAY", Theme.F_TITLE)
	frame.title:SetPoint("LEFT", frame.header, "LEFT", 6, 0)
	frame.title:SetText(titleText or "")
	frame.title:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])

	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.subtitle:SetPoint("RIGHT", frame.header, "RIGHT", -26, 0)
	frame.subtitle:SetText("")
	frame.subtitle:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])

	local ok, close = pcall(CreateFrame, "Button", nil, frame, "UIPanelCloseButton")
	if ok and close then
		close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
		if close.SetFrameLevel and frame.GetFrameLevel then
			close:SetFrameLevel(frame:GetFrameLevel() + 5)
		end
		close:SetScript("OnClick", function() frame:Hide() end)
		frame.close = close
	end
end

function Theme.CreatePanel(parent, width, height, titleText, options)
	options = options or {}
	local frame

	-- 1) fond et bord d'infobulle (BackdropTemplate)
	local okBackdrop, backdropFrame = pcall(CreateFrame, "Frame", options.name, parent or UIParent,
		"BackdropTemplate")
	if okBackdrop and backdropFrame and backdropFrame.SetBackdrop then
		frame = backdropFrame
		frame:SetBackdrop(Theme.BACKDROP_TOOLTIP)
		if frame.SetBackdropColor then
			frame:SetBackdropColor(0.015, 0.015, 0.015, 0.92)
		end
		if frame.SetBackdropBorderColor then
			frame:SetBackdropBorderColor(1, 1, 1, 1)
		end
		frame.chrome = "backdrop"
	else
		-- 2) repli : chrome dessiné, ne dépend d'aucun template
		local okPlain, plain = pcall(CreateFrame, "Frame", options.name, parent or UIParent)
		frame = (okPlain and plain) or CreateFrame("Frame", options.name, parent or UIParent)
		if not frame then return nil end
		BuildChrome(frame, options.light and Theme.BG_LIGHT or Theme.BG_DARK)
		frame.chrome = "drawn"
	end

	frame:SetSize(width, height)
	frame:SetFrameStrata(options.strata or "DIALOG")
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	if options.title ~= false then
		BuildHeader(frame, width, titleText)
		frame.contentTop = -36
	else
		frame.contentTop = -10
	end

	Theme.RegisterEscapeClose(frame)
	return frame
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
		edge:SetVertexColor(Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3], 0.55)
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


function Theme.CreateBar(parent, width, height)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetSize(width, height)

	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetTexture(Theme.SOLID)
	bar.bg:SetVertexColor(0, 0, 0, 0.75)
	bar.bg:SetAllPoints()

	bar.fill = bar:CreateTexture(nil, "ARTWORK")
	bar.fill:SetTexture(Theme.SOLID)
	bar.fill:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 0.95)
	bar.fill:SetPoint("TOPLEFT")
	bar.fill:SetPoint("BOTTOMLEFT")
	bar.fill:SetWidth(0)

	bar.gloss = bar:CreateTexture(nil, "ARTWORK")
	bar.gloss:SetTexture(Theme.SOLID)
	bar.gloss:SetVertexColor(1, 1, 1, 0.16)
	bar.gloss:SetPoint("TOPLEFT", 0, 0)
	bar.gloss:SetPoint("TOPRIGHT", 0, 0)
	bar.gloss:SetHeight(math.max(1, height / 2))

	bar.topLine = bar:CreateTexture(nil, "OVERLAY")
	bar.topLine:SetTexture(Theme.SOLID)
	bar.topLine:SetVertexColor(Theme.GOLD_DIM[1], Theme.GOLD_DIM[2], Theme.GOLD_DIM[3], 0.9)
	bar.topLine:SetPoint("TOPLEFT", 0, 1)
	bar.topLine:SetPoint("TOPRIGHT", 0, 1)
	bar.topLine:SetHeight(1)

	function bar:SetValue(ratio)
		ratio = Clamp(tonumber(ratio) or 0, 0, 1)
		local width = self:GetWidth() * ratio
		self.fill:SetWidth(math.max(0, width))
		self.gloss:SetWidth(math.max(0, width))
		self.gloss:ClearAllPoints()
		self.gloss:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		if width > 0 then
			self.gloss:SetPoint("TOPRIGHT", self, "TOPLEFT", width, 0)
		else
			self.gloss:SetPoint("TOPRIGHT", self, "TOPLEFT", 0, 0)
		end
		self.gloss:SetHeight(math.max(1, self:GetHeight() / 2))
	end

	function bar:SetColor(r, g, b, a)
		self.fill:SetVertexColor(r, g, b, a or 0.95)
	end

	return bar
end

-- ---------------------------------------------------------------------------
-- Filet de séparation
-- ---------------------------------------------------------------------------
function Theme.CreateDivider(parent, width, y)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetTexture(Theme.SOLID)
	line:SetVertexColor(Theme.GOLD_DIM[1], Theme.GOLD_DIM[2], Theme.GOLD_DIM[3], 0.7)
	line:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y or 0)
	line:SetSize(width or 100, 1)
	return line
end

-- ---------------------------------------------------------------------------
-- Bouton natif
-- ---------------------------------------------------------------------------
function Theme.CreateButton(parent, width, height, label, onClick)
	local ok, button = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
	if not ok or not button then
		button = CreateFrame("Button", nil, parent)
		if button.SetBackdrop then
			button:SetBackdrop({
				bgFile = Theme.BG_LIGHT, edgeFile = Theme.SOLID,
				tile = true, tileSize = 16, edgeSize = 1,
				insets = { left = 1, right = 1, top = 1, bottom = 1 },
			})
			if button.SetBackdropBorderColor then
				button:SetBackdropBorderColor(Theme.GOLD_DIM[1], Theme.GOLD_DIM[2], Theme.GOLD_DIM[3], 1)
			end
		end
	end
	button:SetSize(width, height)

	if button.SetText then
		button:SetText(label)
	else
		button.text = button:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		button.text:SetPoint("CENTER")
		button.text:SetText(label)
		button.text:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
		-- même interface que UIPanelButtonTemplate, pour pouvoir relibeller
		button.SetText = function(self, text) self.text:SetText(text) end
	end

	if button.SetNormalFontObject and GameFontNormalSmall then
		button:SetNormalFontObject(GameFontNormalSmall)
	end
	if onClick then button:SetScript("OnClick", onClick) end

	return button
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
