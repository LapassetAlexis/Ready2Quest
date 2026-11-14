-- Options.lua -- fenêtre de réglages (refonte 2026-11, docs/UI.md)
--
-- Fenêtre large : navigation à gauche (marque, recherche, groupes, une
-- entrée par page de premier niveau avec l'interrupteur de son module), à
-- droite l'en-tête de la page (grand titre, phrase), ses onglets (les
-- sous-pages, `parent`), un aperçu facultatif (`preview`), puis les réglages
-- en cartes sur deux colonnes, qui défilent à la molette. Pied : l'action
-- principale de l'addon et « Réinitialiser » à gauche, « Terminé » à droite.
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py. Chaque addon déclare ses pages
-- (ns.AddOptionPage), ses listes (ns.OPTION_LISTS), ses actions
-- (ns.OPTION_ACTIONS) et le bouton principal du pied (ns.OPTIONS_MAIN).
-- socle 2.11.0 : corps du fichier dans une fabrique, compilée une fois quand
-- les deux addons ont le même socle (Base.lua, ns.SocleFile). Rien de propre
-- à l'addon au niveau du fichier : tout passe par ADDON et ns, ci-dessous.
local SOCLE_ADDON, SOCLE_NS = ...
;(SOCLE_NS.SocleFile or function(_, factory) return factory end)("Options", function(...)
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local FRAME_WIDTH  = 980
local FRAME_HEIGHT = 680
local NAV_WIDTH    = 220
local FOOTER       = 56
local CONTENT_W    = FRAME_WIDTH - 2 - NAV_WIDTH      -- 758 : zone de droite
local MARGIN       = 24
local INNER        = CONTENT_W - 2 * MARGIN           -- 710 : largeur des cartes
local COL_GAP      = 8
local COL          = math.floor((INNER - COL_GAP) / 2) -- 351 : une carte sur deux colonnes
local PAD          = 12                               -- marge intérieure d'une carte
local CARD_H       = Theme.CARD_HEIGHT or 38
local NOTE_CARD_H  = 54                               -- carte avec sa phrase dessous (une ligne)
local NOTE_LINE    = 14                               -- ligne de plus pour une phrase plus longue
local NOTE_LINES   = 3
local CARD_GAP     = 4
local BLOCK_GAP    = 8
local SECTION_H    = 20
local SECTION_SPACE = 12                              -- au-dessus d'une section (sauf la première)
local PREVIEW_H    = 88
local TABS_TOP     = -(Theme.HEADER_HEIGHT or 100)
local BODY_BOTTOM  = -(FRAME_HEIGHT - 2 - FOOTER - 12) -- bas utile du contenu, sous l'en-tête de la zone
local LIST_LINE    = 24
local LIST_LINES   = 9
local NAV_TOP      = -118                             -- haut de la liste de navigation, sous la recherche
local NAV_VIEW     = FRAME_HEIGHT - 2 + NAV_TOP - 44  -- hauteur visible (au-dessus de la version)
local NAV_HEADER_H = 30                               -- titre de groupe, écart au-dessus compris
local SLIDER_TRACK = 96                               -- piste d'un curseur, demi-carte
local SLIDER_TRACK_WIDE = 180                         -- piste d'un curseur, carte pleine largeur

-- ---------------------------------------------------------------------------
-- Pages. `modules` = interrupteurs de checks (ns.checks), `rows` = réglages
-- (bool, number, action, note ; `header` = titre de section), `list` = liste
-- défilante (ns.OPTION_LISTS), `actions` = boutons, `info` = paragraphes
-- d'explication, `preview` = function(ns, conteneur) qui dessine l'aperçu
-- sous les onglets (conteneur.Refresh, s'il est posé, suit RefreshOptions).
-- Une page de premier niveau a son entrée dans la navigation, avec
-- l'interrupteur de son module (`power` = clé de réglage) ; une sous-page
-- (`parent`) est un onglet de sa page. Chaque addon déclare ses pages avec
-- ns.AddOptionPage ; il en faut une d'id « general ».
-- ---------------------------------------------------------------------------
local PAGES = ns.OPTION_PAGES or {}
ns.OPTION_PAGES = PAGES

-- API d'extension : un module ajoute sa page (ou sa sous-page) aux réglages.
-- Sans `beforeId` : une page du groupe QoL va à la fin du QoL, toute autre
-- page à la fin des MODULES, juste avant la section QoL. À appeler au
-- chargement, avant la première ouverture des réglages.
function ns.AddOptionPage(def, beforeId)
	if not beforeId and def.group ~= "OPT_GROUP_QOL" then
		for index, existing in ipairs(PAGES) do
			if existing.group == "OPT_GROUP_QOL" then table.insert(PAGES, index, def); return end
		end
	end
	if beforeId then
		for index, existing in ipairs(PAGES) do
			if existing.id == beforeId then table.insert(PAGES, index, def); return end
		end
	end
	table.insert(PAGES, def)
end

-- Géométrie exposée aux tests : c'est elle qui se casse silencieusement
ns.OPT_LAYOUT = {
	width = FRAME_WIDTH,
	height = FRAME_HEIGHT,
	navWidth = NAV_WIDTH,
	contentWidth = CONTENT_W,
	margin = MARGIN,
	inner = INNER,
	colWidth = COL,
	colGap = COL_GAP,
	cardPad = PAD,
	cardHeight = CARD_H,
	noteCardHeight = NOTE_CARD_H,
	cardGap = CARD_GAP,
	previewHeight = PREVIEW_H,
	tabsTop = TABS_TOP,
	bodyBottom = BODY_BOTTOM,
	footer = FOOTER,
	listLine = LIST_LINE,
	listLines = LIST_LINES,
	navTop = NAV_TOP,
	navView = NAV_VIEW,
	navHeaderHeight = NAV_HEADER_H,
	maxHeight = 740,
}

local function Clamp(value, minimum, maximum)
	if value < minimum then return minimum end
	if value > maximum then return maximum end
	return value
end

local function CheckDef(id)
	for _, def in ipairs(ns.checks or {}) do
		if def.id == id then return def end
	end
	return nil
end

local function CheckLabel(def)
	local label = def and def.label
	if type(label) == "function" then label = label() end
	return tostring(label or (def and def.id) or "?")
end

local function OnOff(on)
	return on and (Theme.T_GREEN .. L.OPT_ON .. "|r") or (Theme.T_GREY .. L.OPT_OFF .. "|r")
end

local function PageDef(id)
	for _, def in ipairs(PAGES) do
		if def.id == id then return def end
	end
	return nil
end

-- Chaîne déclarée, ou nil (ns.L rend la clé elle-même quand elle manque)
local function Declared(key)
	if type(key) ~= "string" then return nil end
	local text = L[key]
	if text == nil or text == key or text == "" then return nil end
	return text
end

local function Tip(owner, lines)
	if type(GameTooltip) ~= "table" or not GameTooltip.SetOwner then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	for index, line in ipairs(lines) do
		if index == 1 then
			GameTooltip:AddLine(line, Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
		else
			GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true)
		end
	end
	GameTooltip:Show()
end
local function HideTip()
	if type(GameTooltip) == "table" and GameTooltip.Hide then GameTooltip:Hide() end
end

-- Largeur d'un texte dans sa police : mesurée par le client, sinon estimée
-- (6,6 px par caractère, en caractères et non en octets)
local function TextWidth(fontString, text)
	if text ~= nil then fontString:SetText(text) end
	local width = fontString.GetStringWidth and tonumber(fontString:GetStringWidth()) or 0
	if not width or width <= 0 then
		local plain = tostring(fontString:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		width = select(2, plain:gsub("[^\128-\191]", "")) * 6.6
	end
	return width
end
ns.OptionTextWidth = TextWidth

-- Recherche : minuscules, sans accents ni codes de couleur
local FOLD = {
	["à"] = "a", ["â"] = "a", ["ä"] = "a", ["ç"] = "c", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
	["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["ö"] = "o", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ÿ"] = "y",
	["œ"] = "oe", ["æ"] = "ae", ["À"] = "a", ["Â"] = "a", ["Ç"] = "c", ["É"] = "e", ["È"] = "e", ["Ê"] = "e",
	["Î"] = "i", ["Ô"] = "o", ["Ù"] = "u", ["Û"] = "u", ["Œ"] = "oe",
}
local function Fold(text)
	text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("[\195\197][\128-\191]", FOLD)
	return ns.AsciiLower(text) or ""
end
ns.OptionFold = Fold

-- ---------------------------------------------------------------------------
-- Listes défilantes : zones sûres apprises, buffs suivis.
-- Défilement à la molette et par deux boutons « ^ » / « v » (ASCII : les
-- flèches Unicode ne sont pas garanties dans la police), sans dépendre de
-- FauxScrollFrame, dont la présence n'est pas assurée sur Forever.
-- ---------------------------------------------------------------------------
-- ns.OPTION_LISTS[id] = { items = function() -> { { key, text, detail|value,
--   action, onAction, onToggle } }, empty = clé du texte « liste vide »,
--   header = clé du titre, lines = nombre de lignes, clear = { label, run }
--   (bouton sous la liste), hint = clé d'une phrase d'aide sous la liste }
ns.OPTION_LISTS = ns.OPTION_LISTS or {}
local LIST_SOURCES = ns.OPTION_LISTS

function ns:RefreshOptionList(list)
	local items = LIST_SOURCES[list.source].items()
	list.items = items
	local maxOffset = math.max(0, #items - #list.lines)
	list.offset = Clamp(list.offset or 0, 0, maxOffset)

	for index, line in ipairs(list.lines) do
		local item = items[index + list.offset]
		line.item = item
		if item then
			line.text:SetText(item.text)
			line.detail:SetText(item.detail and (Theme.T_GREY .. item.detail .. "|r") or (item.value or ""))
			if line.action then
				if item.action then line.action:Show() else line.action:Hide() end
			end
			line:Show()
		else
			line:Hide()
		end
	end

	list.empty:SetText(#items == 0 and (L[list.emptyText] or "") or "")
	list.position:SetText(#items > #list.lines
		and string.format("%d-%d / %d", list.offset + 1, math.min(#items, list.offset + #list.lines), #items) or "")
	if list.up then
		if list.offset > 0 then list.up:Show() else list.up:Hide() end
		if list.offset < maxOffset then list.down:Show() else list.down:Hide() end
	end
end

function ns:ScrollOptionList(list, delta)
	list.offset = (list.offset or 0) - delta
	self:RefreshOptionList(list)
end

-- socle 3.2 : style d'un bouton d'action selon le thème. En thème forgé, la
-- couleur dit le sens (Theme.FORGE_BUTTONS : or principal, vert ajouter,
-- rouge retirer, bleu arcane action neutre) ; en Sobre, le style d'avant.
local function ActionStyle(sobre, forged)
	return Theme.Forged and Theme.Forged() and forged or sobre
end

-- Bloc de liste : pleine largeur, lignes alternées, pied (position, ^ v)
local function BuildList(page, source)
	local def = LIST_SOURCES[source] or {}
	local list = { source = source, lines = {}, offset = 0, emptyText = def.empty }
	local count = def.lines or LIST_LINES

	local block = CreateFrame("Frame", nil, page)
	block:SetSize(INNER, count * LIST_LINE + 34)
	block.bg = Theme.Solid(block, "BACKGROUND", Theme.FIELD, 1)
	block.bg:SetAllPoints()
	block.border = Theme.Border(block, Theme.EDGE_SOFT, 1)
	list.block = block

	for index = 1, count do
		local line = CreateFrame("Button", nil, block)
		line:SetSize(INNER - 2, LIST_LINE)
		line:SetPoint("TOPLEFT", block, "TOPLEFT", 1, -1 - (index - 1) * LIST_LINE)
		line.bg = Theme.Solid(line, "BACKGROUND", index % 2 == 0 and Theme.ROW_ALT or Theme.ROW, 1)
		line.bg:SetAllPoints()

		line.text = Theme.Text(line, Theme.F_BODY, Theme.LABEL)
		line.text:SetPoint("LEFT", line, "LEFT", PAD, 0)
		line.text:SetWidth(300)
		line.text:SetJustifyH("LEFT")
		line.text:SetWordWrap(false)

		line.detail = Theme.Text(line, Theme.F_SMALL, Theme.MUTED_LIGHT)
		line.detail:SetPoint("LEFT", line, "LEFT", 320, 0)
		line.detail:SetWidth(260)
		line.detail:SetJustifyH("LEFT")
		line.detail:SetWordWrap(false)

		line.action = Theme.CreateButton(line, 76, 18, L.OPT_REMOVE, function()
			if line.item and line.item.onAction then
				line.item.onAction()
				ns:RefreshOptions()
			end
		end, ActionStyle("outline", "danger"))
		line.action:SetPoint("RIGHT", line, "RIGHT", -8, 0)

		-- clic sur la ligne : bascule (buffs suivis)
		line:SetScript("OnClick", function()
			if line.item and line.item.onToggle then
				line.item.onToggle()
				ns:RefreshOptions()
			end
		end)
		list.lines[index] = line
	end

	list.empty = Theme.Text(block, Theme.F_BODY, Theme.MUTED)
	list.empty:SetPoint("TOPLEFT", block, "TOPLEFT", PAD, -8)
	list.empty:SetJustifyH("LEFT")

	list.position = Theme.Text(block, Theme.F_SMALL, Theme.MUTED)
	list.position:SetPoint("BOTTOMLEFT", block, "BOTTOMLEFT", PAD, 9)

	list.down = Theme.CreateButton(block, 24, 20, "v", function() ns:ScrollOptionList(list, -1) end, "outline")
	list.down:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", -8, 6)
	list.up = Theme.CreateButton(block, 24, 20, "^", function() ns:ScrollOptionList(list, 1) end, "outline")
	list.up:SetPoint("RIGHT", list.down, "LEFT", -4, 0)

	if block.EnableMouseWheel then block:EnableMouseWheel(true) end
	block:SetScript("OnMouseWheel", function(_, delta) ns:ScrollOptionList(list, delta) end)
	return list
end

-- ---------------------------------------------------------------------------
-- Cartes de réglage. Chaque carte porte .def (la ligne déclarée), .label,
-- .value (texte de valeur : OUI/non, « 12 s », « 225° »), son contrôle
-- (.toggle, .slider, .dropdown, .button), :Refresh(db), et peut être
-- verrouillée (:SetLocked(texte) : le contrôle cède la place à un verrou en
-- pointillés). Une carte trop étroite pour son libellé prend les deux
-- colonnes (.span = "full").
-- ---------------------------------------------------------------------------
local function NumberText(def, value)
	if def.display then
		local ok, text = pcall(def.display, value or 0)
		return tostring(ok and text or (value or 0))
	end
	local suffix = def.suffix and (" " .. (L[def.suffix] or def.suffix)) or ""
	return tostring(value or 0) .. suffix
end

local function NewCard(page, labelText)
	local card = Theme.CreateSettingCard(page, COL, CARD_H, "Button")
	card.labelText = labelText
	card:SetLabel(labelText)
	if card.label.SetWordWrap then card.label:SetWordWrap(false) end
	-- texte de valeur : porté par toutes les cartes (lecteurs, tests), affiché
	-- seulement quand il dit autre chose que le contrôle (angle du bouton)
	card.value = Theme.Text(card, Theme.F_SMALL, Theme.GOLD)
	card.value:SetJustifyH("RIGHT")
	card.value:Hide()
	card.span = "half"
	card.searchText = Fold(labelText)

	function card:SetLocked(text)
		if text and text ~= "" then
			if not self.lock then
				self.lock = Theme.CreateLockTag(self, text)
				self.lock:SetPoint("RIGHT", self, "RIGHT", -PAD, 0)
			end
			self.lock:SetText(text)
			self.lock:Show()
			if self.controlRegion then self.controlRegion:Hide() end
			self.locked = true
			self.label:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3], 1)
		else
			if self.lock then self.lock:Hide() end
			if self.controlRegion then self.controlRegion:Show() end
			self.locked = nil
			self.label:SetTextColor(Theme.LABEL[1], Theme.LABEL[2], Theme.LABEL[3], 1)
		end
	end

	-- infobulle : libellé entier s'il est tronqué, puis def.tooltip(valeur)
	card:SetScript("OnEnter", function(self)
		self.hover:Show()
		local lines = {}
		if self.truncated then lines[#lines + 1] = self.labelText end
		if self.def and self.def.tooltip then
			local ok, extra = pcall(self.def.tooltip, ns:DB()[self.def.key])
			for _, line in ipairs(ok and extra or {}) do lines[#lines + 1] = line end
		end
		if #lines > 0 then Tip(self, lines) end
	end)
	card:SetScript("OnLeave", function(self) self.hover:Hide(); HideTip() end)
	return card
end

-- Place le libellé et décide de la largeur : demi-carte si le libellé tient
-- à gauche du contrôle, sinon pleine largeur. `noteText` : phrase sous le
-- libellé (carte plus haute, toujours pleine largeur).
local function FitCard(card, controlWidth, wide)
	local need = TextWidth(card.label, card.labelText)
	card.labelWidth = need
	local halfRoom = COL - 2 * PAD - controlWidth - 12
	if wide or need > halfRoom then card.span = "full" end
	local width = card.span == "full" and INNER or COL
	card:SetWidth(width)
	if card.control then card.control:SetWidth(math.max(1, controlWidth)) end
	local room = width - 2 * PAD - controlWidth - 12
	card.labelRoom = room
	card.label:SetWidth(room)
	card.truncated = need > room
	card:SetHeight(card.note and math.max(NOTE_CARD_H, card:GetHeight() or 0) or CARD_H)
	card.label:ClearAllPoints()
	if card.note then
		card.label:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -10)
		card.note:ClearAllPoints()
		card.note:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -29)
		card.note:SetWidth(room)
	else
		card.label:SetPoint("LEFT", card, "LEFT", PAD, 0)
	end
end

local function AddNote(card, def)
	if not def.describe then return end
	card.note = Theme.Text(card, Theme.F_SMALL, Theme.MUTED_LIGHT)
	card.note:SetJustifyH("LEFT")
	card.note:SetJustifyV("TOP")
	if card.note.SetWordWrap then card.note:SetWordWrap(true) end
end

-- phrase sous le libellé, qui suit la valeur : la carte grandit d'une ligne
-- par ligne de texte (trois au plus). Rend vrai si sa hauteur a changé.
local function RefreshNote(card, value)
	if not (card.note and card.def.describe) then return false end
	local ok, text = pcall(card.def.describe, value)
	text = ok and tostring(text or "") or ""
	local lines = math.max(1, math.ceil(TextWidth(card.note, text) / math.max(1, card.labelRoom or 1)))
	lines = math.min(lines, NOTE_LINES)
	card.note:SetHeight(lines * NOTE_LINE)
	local height = NOTE_CARD_H + (lines - 1) * NOTE_LINE
	if math.abs((tonumber(card:GetHeight()) or 0) - height) > 0.5 then
		card:SetHeight(height)
		return true
	end
	return false
end

local function BoolCard(page, def)
	local card = NewCard(page, L[def.label] or def.key)
	card.def = def
	AddNote(card, def)
	card.toggle = Theme.CreateToggle(card)
	card.toggle:SetPoint("RIGHT", card, "RIGHT", -PAD, 0)
	card.controlRegion = card.toggle
	FitCard(card, 32, def.describe ~= nil)
	card:SetScript("OnClick", function(self)
		if self.locked then return end
		local db = ns:DB()
		local before = db[def.key] ~= false
		db[def.key] = not before
		ns:RefreshOptions()
		if ns.ApplyDisplayOptions then ns:ApplyDisplayOptions() end
		if def.onChange then def.onChange(db[def.key], before) end
	end)
	function card:Refresh(db)
		local on = db[def.key] ~= false
		self.value:SetText(OnOff(on))
		self.toggle:SetChecked(on)
		return RefreshNote(self, on)
	end
	return card
end

local function ModuleCard(page, check)
	local card = NewCard(page, CheckLabel(check))
	card.isModule = true
	card.moduleId = check.id
	card.toggle = Theme.CreateToggle(card)
	card.toggle:SetPoint("RIGHT", card, "RIGHT", -PAD, 0)
	card.controlRegion = card.toggle
	FitCard(card, 32)
	card:SetScript("OnClick", function()
		ns:SetModuleEnabled(check.id, not ns:IsModuleEnabled(check.id))
		ns:RefreshOptions()
	end)
	function card:Refresh()
		local on = ns:IsModuleEnabled(check.id)
		self.value:SetText(OnOff(on))
		self.toggle:SetChecked(on)
		local c = on and Theme.LABEL or Theme.MUTED
		self.label:SetTextColor(c[1], c[2], c[3], 1)
	end
	return card
end

local function NumberCard(page, def)
	local card = NewCard(page, L[def.label] or def.key)
	card.def = def
	AddNote(card, def)
	local minimum, maximum, step = def.min or 0, def.max or 999, def.step or 1
	-- case de valeur : assez large pour le plus long des crans (« Très grand »)
	local probe = Theme.Text(card, Theme.F_SMALL, Theme.LABEL)
	probe:Hide()
	local widest, count, value = 0, 0, minimum
	while value <= maximum and count < 60 do
		widest = math.max(widest, TextWidth(probe, NumberText(def, value)))
		value, count = value + step, count + 1
	end
	widest = math.max(widest, TextWidth(probe, NumberText(def, maximum)))
	local valueWidth = Clamp(math.ceil(widest) + 14, Theme.SLIDER_VALUE_WIDTH or 44, 120)
	-- piste de même longueur sur toutes les demi-cartes (alignées d'une
	-- rangée à l'autre) ; plus longue sur une carte pleine largeur, prise
	-- quand le libellé ne tient pas à côté
	local need = TextWidth(card.label, card.labelText)
	local wide = def.describe ~= nil or need > COL - 2 * PAD - 12 - (SLIDER_TRACK + valueWidth + 12)
	local track = wide and SLIDER_TRACK_WIDE or SLIDER_TRACK
	local width = track + valueWidth + 12

	card.slider = Theme.CreateSlider(card, width, minimum, maximum, step, function(new)
		local db = ns:DB()
		local before = db[def.key]
		db[def.key] = new
		ns:RefreshOptions()
		-- l'addon réagit au nouveau cran (bulle de confirmation…)
		if def.onChange and db[def.key] ~= before then def.onChange(db[def.key], before) end
	end, valueWidth)
	card.slider.format = function(v) return NumberText(def, v) end
	card.slider:SetPoint("RIGHT", card, "RIGHT", -PAD, 0)
	card.controlRegion = card.slider
	card.value = card.slider.valueText
	FitCard(card, width, wide)
	-- un cran de plus ou de moins, comme la molette sur le curseur
	function card:Step(delta)
		return self.slider:SetValueByUser((self.slider.value or minimum) + (delta or 0) * step)
	end
	function card:Refresh(db)
		local current = db[def.key]
		self.slider:SetValue(current or 0)
		-- valeur telle qu'enregistrée (le curseur l'arrondit à son cran)
		self.slider.valueText:SetText(NumberText(def, current or 0))
		return RefreshNote(self, current or 0)
	end
	return card
end

-- Action : un bouton sur la carte (et la carte entière cliquable) ; avec
-- def.choices, une liste déroulante (choix verrouillés grisés, avec leur
-- condition). def.choices() -> { { value, label, disabled, hint } },
-- def.current() -> valeur, def.choose(valeur).
local function ActionCard(page, def)
	local card = NewCard(page, L[def.label] or def.key)
	card.def = def
	if def.choices then
		local ok, options = pcall(def.choices)
		options = ok and options or {}
		local probe = Theme.Text(card, Theme.F_BODY, Theme.LABEL)
		local hintProbe = Theme.Text(card, Theme.F_SMALL, Theme.MUTED)
		probe:Hide(); hintProbe:Hide()
		local longest, hint = 0, 0
		for _, entry in ipairs(options) do
			longest = math.max(longest, TextWidth(probe, entry.label or tostring(entry.value)))
			if entry.hint then hint = math.max(hint, TextWidth(hintProbe, entry.hint)) end
		end
		local width = Clamp(math.ceil(longest) + 34, 150, 210)
		local listWidth = Clamp(math.ceil(longest + hint) + 46, width, 330)
		card.dropdown = Theme.CreateDropdown(card, width, function(value)
			if def.choose then def.choose(value) end
			ns:RefreshOptions()
		end, { listWidth = listWidth })
		card.dropdown:SetPoint("RIGHT", card, "RIGHT", -PAD, 0)
		card.dropdown:SetOptions(options)
		card.controlRegion = card.dropdown
		FitCard(card, width)
		card:SetScript("OnClick", function(self)
			if self.dropdown:IsOpen() then self.dropdown:Close() else self.dropdown:Open() end
		end)
		function card:Refresh()
			local okOptions, list = pcall(def.choices)
			self.dropdown:SetOptions(okOptions and list or {})
			local okValue, value = pcall(def.current or function() return nil end)
			self.dropdown:SetValue(okValue and value or nil)
		end
		return card
	end

	local text = L[def.button or "OPT_BTN_RUN"]
	local probe = Theme.Text(card, Theme.F_LABEL, Theme.LABEL)
	probe:Hide()
	local buttonWidth = math.max(84, math.ceil(TextWidth(probe, text)) + 28)
	-- thème forgé : action neutre en bleu arcane ; def.forgeStyle ("danger",
	-- "add"…) pour une action qui retire ou ajoute
	card.button = Theme.CreateButton(card, buttonWidth, 22, text, function() ns:RunOptionAction(def.key) end,
		ActionStyle("outline", def.forgeStyle or "arcane"))
	card.button:SetPoint("RIGHT", card, "RIGHT", -PAD, 0)
	card.controlRegion = card.button
	card.value:ClearAllPoints()
	card.value:SetPoint("RIGHT", card.button, "LEFT", -10, 0)
	-- valeur affichée à gauche du bouton : l'angle du bouton de minicarte
	local valueWidth = def.key == "minimapPos" and 44 or 0
	if valueWidth > 0 then card.value:Show() end
	FitCard(card, buttonWidth + valueWidth)
	card:SetScript("OnClick", function() ns:RunOptionAction(def.key) end)
	function card:Refresh(db)
		if def.key == "minimapPos" then
			self.value:SetText(string.format("%d°", math.floor((db.minimapAngle or 225) + 0.5)))
		else
			self.value:SetText("")
		end
	end
	return card
end

local function MakeCard(page, def)
	if def.kind == "bool" then return BoolCard(page, def) end
	if def.kind == "number" then return NumberCard(page, def) end
	return ActionCard(page, def)
end

-- Bloc de texte pleine largeur (paragraphe d'explication, note d'une page) :
-- `source` = clé de chaîne ou function() -> texte
local function TextBlock(page, source, small)
	local block = CreateFrame("Frame", nil, page)
	block:SetSize(INNER, 16)
	block.text = Theme.Text(block, small and Theme.F_SMALL or Theme.F_BODY, small and Theme.MUTED or Theme.TEXT)
	block.text:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
	block.text:SetWidth(INNER - 8)
	block.text:SetJustifyH("LEFT")
	if block.text.SetWordWrap then block.text:SetWordWrap(true) end
	block.source, block.small = source, small
	-- hauteur : celle du client, sinon estimée (~5,8 px par caractère, 15 par ligne)
	function block:Refresh()
		local text = self.source
		if type(text) == "function" then
			local ok, value = pcall(text)
			text = ok and value or ""
		else
			text = L[text] or text
		end
		text = tostring(text or "")
		self.text:SetText(text)
		local height = self.text.GetStringHeight and tonumber(self.text:GetStringHeight()) or 0
		if not height or height <= 0 or not self.text.SetWordWrap then
			local chars = select(2, text:gsub("[^\128-\191]", ""))
			local perLine = math.floor((INNER - 8) / (self.small and 5.4 or 5.9))
			height = math.max(1, math.ceil(chars / perLine)) * (self.small and 14 or 15)
		end
		local changed = self.blockHeight ~= height
		self.blockHeight = height
		self:SetHeight(height)
		return changed
	end
	block:Refresh()
	return block
end

-- Rangée de boutons en contour (actions d'une page, cadres)
local function ButtonRow(page, specs)
	local block = CreateFrame("Frame", nil, page)
	block:SetSize(INNER, 28)
	local x, buttons = 0, {}
	local probe = Theme.Text(block, Theme.F_LABEL, Theme.LABEL)
	probe:Hide()
	for index, spec in ipairs(specs) do
		local width = math.max(110, math.ceil(TextWidth(probe, spec.label)) + 32)
		local button = Theme.CreateButton(block, width, 28, spec.label, spec.run, "outline")
		button:SetPoint("TOPLEFT", block, "TOPLEFT", x, 0)
		buttons[index] = button
		x = x + width + 10
	end
	block.buttons = buttons
	return block, buttons
end

-- ---------------------------------------------------------------------------
-- Mise en page : sections, cartes sur deux colonnes (ROW / ROW_ALT une
-- rangée visuelle sur deux), blocs pleine largeur. Puis défilement : la
-- page s'arrête sur le haut d'un élément, un élément qui ne tient pas
-- entier dans la zone est masqué (pas de rognage à faire).
-- ---------------------------------------------------------------------------
-- item = { region, kind = "section" | "card" | "block", span = "half" | "full", height }
local function Arrange(items)
	local y, col, rowTop, rowH, visual, first = 0, 0, 0, 0, 0, true
	local function CloseRow()
		if col == 1 then
			y = rowTop + rowH + CARD_GAP
			col = 0
		end
	end
	for _, item in ipairs(items) do
		if not item.filtered then
			item.height = item.region:GetHeight() or item.height or CARD_H
			if item.kind == "section" then
				CloseRow()
				if not first then y = y + SECTION_SPACE end
				item.x, item.y = 0, y
				y = y + SECTION_H + 6
				visual = 0
			elseif item.kind == "card" and item.region.span ~= "full" then
				if col == 0 then
					rowTop, rowH = y, item.height
					item.x, item.y = 0, y
					col = 1
					visual = visual + 1
				else
					item.x, item.y = COL + COL_GAP, rowTop
					rowH = math.max(rowH, item.height)
					col = 0
					y = rowTop + rowH + CARD_GAP
				end
				item.region:SetAlt(visual % 2 == 0)
			else
				CloseRow()
				item.x, item.y = 0, y
				if item.kind == "card" then
					visual = visual + 1
					item.region:SetAlt(visual % 2 == 0)
					y = y + item.height + CARD_GAP
				else
					y = y + item.height + BLOCK_GAP
				end
			end
			first = false
		end
	end
	CloseRow()
	return y
end

-- arrêts du défilement : 0, puis le haut de chaque élément tant que la fin
-- du contenu n'est pas en vue
local function ScrollStops(container)
	local maxOffset = math.max(0, (container.contentHeight or 0) - (container.viewHeight or 0))
	local tops, seen = {}, {}
	for _, item in ipairs(container.items or {}) do
		if not item.filtered and item.y and item.y > 0 and not seen[item.y] then
			seen[item.y] = true
			tops[#tops + 1] = item.y
		end
	end
	table.sort(tops)
	local stops = { 0 }
	if maxOffset > 0 then
		local last
		for _, top in ipairs(tops) do
			if top < maxOffset then stops[#stops + 1] = top
			elseif not last then last = top end
		end
		stops[#stops + 1] = last or maxOffset
	end
	return stops
end

function ns:ApplyOptionsScroll(container)
	local stops = container.stops or { 0 }
	container.stopIndex = Clamp(container.stopIndex or 1, 1, #stops)
	local offset = stops[container.stopIndex]
	container.offset = offset
	local view = container.viewHeight or 0
	for _, item in ipairs(container.items or {}) do
		local region = item.region
		if item.filtered then
			region:Hide()
		else
			local top = item.y - offset
			region:ClearAllPoints()
			region:SetPoint("TOPLEFT", container, "TOPLEFT", item.x, -top)
			if top >= 0 and top + item.height <= view + 1 then region:Show() else region:Hide() end
		end
	end
	-- un titre de section sans rien de visible sous lui est masqué aussi
	local items = container.items or {}
	for index, item in ipairs(items) do
		if item.kind == "section" and not item.filtered and item.region:IsShown() then
			local nextItem = items[index + 1]
			while nextItem and nextItem.filtered do index = index + 1; nextItem = items[index + 1] end
			if nextItem and nextItem.kind ~= "section" and not nextItem.region:IsShown() then item.region:Hide() end
		end
	end
	-- ascenseur : celui du conteneur (navigation), ou celui de la zone de
	-- réglages pour le conteneur affiché
	local frame = self.optionsFrame
	local track, thumb = container.scrollTrack, container.scrollThumb
	if not track and frame and frame.activeContainer == container then track, thumb = frame.scrollTrack, frame.scrollThumb end
	if track then
		local content = container.contentHeight or 0
		if content > view and view > 0 then
			local thumbH = math.max(24, math.floor(view * view / content + 0.5))
			local y = math.floor((view - thumbH) * offset / math.max(1, stops[#stops]) + 0.5)
			thumb:ClearAllPoints()
			thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, -y)
			thumb:SetHeight(thumbH)
			track:SetHeight(view)
			track:Show(); thumb:Show()
		else
			track:Hide(); thumb:Hide()
		end
	end
end

-- (Re)met en page un conteneur (page ou résultats de recherche) : les cartes
-- y sont rattachées (une recherche les emprunte), défilement remis en haut
-- sauf `keepScroll`
function ns:LayoutOptionsContainer(container, keepScroll)
	for _, item in ipairs(container.items or {}) do
		if item.region.GetParent and item.region:GetParent() ~= container then item.region:SetParent(container) end
	end
	container.contentHeight = Arrange(container.items or {})
	container.stops = ScrollStops(container)
	if not keepScroll then container.stopIndex = 1 end
	self:ApplyOptionsScroll(container)
end

-- Molette sur la zone de réglages : delta > 0 remonte
function ns:ScrollOptions(delta)
	local frame = self.optionsFrame
	local container = frame and frame.activeContainer
	if not container then return nil end
	container.stopIndex = (container.stopIndex or 1) - (delta > 0 and 1 or -1)
	self:ApplyOptionsScroll(container)
	return container.offset
end

-- ---------------------------------------------------------------------------
-- Rafraîchissement
-- ---------------------------------------------------------------------------
function ns:RefreshOptions()
	local frame = self.optionsFrame
	if not frame then return end
	local db = self:DB()

	if frame.editButton and frame.editButton.SetText then
		frame.editButton:SetText(self.editMode and L.OPT_EDIT_STOP or L.OPT_EDIT_BUTTON)
	end

	-- cartes et notes dont le texte change de longueur : hauteur suivie
	local grown = false
	for _, card in ipairs(frame.rows or {}) do
		if card.Refresh and card:Refresh(db) then grown = true end
		-- socle 2.11.0 : carte d'un module coupé estompée, mais modifiable
		-- (la carte de module elle-même est l'interrupteur : jamais estompée)
		if not card.isModule and card.SetAlpha then
			local key = self:OptionsPageModuleKey(card.pageId)
			local off = key ~= nil and db[key] == false
			card.dimmed = off or nil
			card:SetAlpha(off and Theme.DIM_ALPHA or 1)
		end
	end
	self:RefreshModuleOffBanner()
	for _, block in ipairs(frame.notes or {}) do
		if type(block.source) == "function" and block:Refresh() then grown = true end
	end
	if grown and frame.activeContainer then self:LayoutOptionsContainer(frame.activeContainer, true) end

	-- navigation : interrupteurs (entrées et titres de groupe), entrée choisie
	local function State(nav)
		if nav.powerKey then return (db[nav.powerKey] ~= false) and "on" or "off" end
		if nav.modules then return (self:PageModuleState(nav.modules) ~= "off") and "on" or "off" end
		return nil
	end
	for _, nav in ipairs(frame.navButtons or {}) do
		nav.state = State(nav)
		nav:SetModuleState(nav.state)
		nav:SetSelected(not frame.searching and nav.pageId == frame.navPage)
	end
	for _, header in ipairs(frame.navHeaders or {}) do
		header.state = State(header)
		header:SetModuleState(header.state)
	end

	for _, list in pairs(frame.lists or {}) do self:RefreshOptionList(list) end

	local preview = frame.currentPreview
	if preview and preview.Refresh then
		local ok, err = pcall(preview.Refresh, preview, self)
		if not ok then self:RecordError("options:preview", err) end
	end
end

-- ---------------------------------------------------------------------------
-- Construction d'une page
-- ---------------------------------------------------------------------------
local function Section(frame, page, key, detail)
	local section = Theme.CreateSection(page, L[key] or key, detail)
	section:SetWidth(INNER)
	page.items[#page.items + 1] = { region = section, kind = "section", height = SECTION_H }
	return section
end

local function AddCard(frame, page, card)
	card.pageId = page.id
	frame.rows[#frame.rows + 1] = card
	page.rows[#page.rows + 1] = card
	page.items[#page.items + 1] = { region = card, kind = "card", height = card:GetHeight() }
	return card
end

local function AddBlock(page, block)
	page.items[#page.items + 1] = { region = block, kind = "block", height = block:GetHeight() }
	return block
end

local BuildPage

-- Page à onglets (`tabs = { { id, label, rows, … } }`) : un conteneur par
-- onglet, d'id « <page>:<onglet> », qui hérite du titre de la page
local function BuildTabbedPage(frame, def, placed)
	frame.tabPages[def.id] = {}
	for _, tab in ipairs(def.tabs) do
		local tabDef = { id = def.id .. ":" .. tostring(tab.id), title = def.title, tabOf = def.id, tabId = tab.id,
			rows = tab.rows, modules = tab.modules, list = tab.list, info = tab.info, actions = tab.actions }
		frame.tabDefs[tabDef.id] = tabDef
		local page = BuildPage(frame, tabDef, placed)
		page.subText = Declared(def.title .. "_SUB")
		frame.tabPages[def.id][#frame.tabPages[def.id] + 1] = page
	end
end

function BuildPage(frame, def, placed)
	if def.tabs then return BuildTabbedPage(frame, def, placed) end
	local page = CreateFrame("Frame", nil, frame.content)
	page:SetSize(INNER, 400)
	page.id = def.id
	page.def = def
	page.rows, page.items = {}, {}
	-- phrase de l'en-tête quand la page est choisie
	page.subText = Declared(def.title .. "_SUB")
	frame.pages[def.id] = page
	frame.pageOrder[#frame.pageOrder + 1] = page

	-- texte d'explication (paragraphes), pour les modules sans réglage
	if def.info then
		page.infoLines = {}
		for _, key in ipairs(def.info) do
			local block = AddBlock(page, TextBlock(page, key))
			page.infoLines[#page.infoLines + 1] = block.text
		end
	end

	if def.modules then
		-- dans une sous-page du Check avant le départ, ce sont ses contrôles
		page.modulesHeader = Section(frame, page, def.parent and "OPT_CHECKS" or "OPT_MODULES")
		for _, id in ipairs(def.modules) do
			local check = CheckDef(id)
			if check then
				AddCard(frame, page, ModuleCard(page, check))
				placed[id] = true
			end
		end
	end

	if def.rows then
		-- une page commence toujours par une section
		local firstHeader = def.rows[1] and def.rows[1].header
		if not firstHeader then
			page.settingsHeader = Section(frame, page, "OPT_SETTINGS")
		end
		for _, rowDef in ipairs(def.rows) do
			if rowDef.header then
				page.sectionHeaders = page.sectionHeaders or {}
				page.sectionHeaders[#page.sectionHeaders + 1] = Section(frame, page, rowDef.header)
			elseif rowDef.kind == "note" then
				local block = AddBlock(page, TextBlock(page, rowDef.text, rowDef.small))
				block.def = rowDef
				frame.notes[#frame.notes + 1] = block
				page.notes = page.notes or {}
				page.notes[rowDef.key or (#page.notes + 1)] = block
			else
				AddCard(frame, page, MakeCard(page, rowDef))
			end
		end
	end

	if def.list then
		local source = LIST_SOURCES[def.list] or {}
		page.listHeader = Section(frame, page, source.header or def.list)
		local list = BuildList(page, def.list)
		frame.lists[def.list] = list
		AddBlock(page, list.block)
		-- sous la liste : un bouton (tout effacer) et une phrase d'aide
		if source.clear or source.hint then
			local block = CreateFrame("Frame", nil, page)
			block:SetSize(INNER, 30)
			local x = 0
			if source.clear then
				local probe = Theme.Text(block, Theme.F_LABEL, Theme.LABEL)
				probe:Hide()
				local label = L[source.clear.label] or source.clear.label
				local width = math.max(110, math.ceil(TextWidth(probe, label)) + 32)
				page.clearButton = Theme.CreateButton(block, width, 26, label, function()
					source.clear.run(ns)
					ns:RefreshOptions()
				end, ActionStyle("outline", "danger"))
				page.clearButton:SetPoint("LEFT", block, "LEFT", 0, 0)
				x = width + 14
			end
			if source.hint then
				page.hint = Theme.Text(block, Theme.F_SMALL, Theme.MUTED)
				page.hint:SetPoint("LEFT", block, "LEFT", x, 0)
				page.hint:SetWidth(INNER - x)
				page.hint:SetJustifyH("LEFT")
				if page.hint.SetWordWrap then page.hint:SetWordWrap(true) end
				page.hint:SetText(L[source.hint] or source.hint)
			end
			AddBlock(page, block)
		end
	end

	if def.frameButtons then
		page.framesHeader = Section(frame, page, "OPT_SECTION_FRAMES")
		local card = NewCard(page, L.OPT_FRAMES_LABEL)
		card.span = "full"
		local probe = Theme.Text(card, Theme.F_LABEL, Theme.LABEL)
		probe:Hide()
		local resetWidth = math.ceil(TextWidth(probe, L.OPT_RESET_FRAMES)) + 28
		local editWidth = math.ceil(math.max(TextWidth(probe, L.OPT_EDIT_BUTTON), TextWidth(probe, L.OPT_EDIT_STOP))) + 28
		frame.resetFramesButton = Theme.CreateButton(card, resetWidth, 22, L.OPT_RESET_FRAMES, function()
			ns:HandleCommand("resetpos")
		end, "outline")
		frame.resetFramesButton:SetPoint("RIGHT", card, "RIGHT", -PAD, 0)
		frame.editButton = Theme.CreateButton(card, editWidth, 22, L.OPT_EDIT_BUTTON, function()
			ns:RunOptionAction("editMode")
		end, "outline")
		frame.editButton:SetPoint("RIGHT", frame.resetFramesButton, "LEFT", -8, 0)
		FitCard(card, resetWidth + editWidth + 8, true)
		card:SetScript("OnClick", nil)
		page.framesCard = card
		page.items[#page.items + 1] = { region = card, kind = "card", height = card:GetHeight() }
	end

	if def.actions then
		page.actionsHeader = Section(frame, page, "OPT_SECTION_ACTIONS")
		local specs = {}
		for _, action in ipairs(def.actions) do
			specs[#specs + 1] = { label = L["OPT_ACTION_" .. action:upper()] or action, run = function() ns:RunOptionAction(action) end }
		end
		local block, buttons = ButtonRow(page, specs)
		page.actionButtons = {}
		for index, action in ipairs(def.actions) do page.actionButtons[action] = buttons[index] end
		AddBlock(page, block)
	end

	page:Hide()
	return page
end

-- ---------------------------------------------------------------------------
-- Construction de la fenêtre
-- ---------------------------------------------------------------------------
local function Children(topId)
	local list = {}
	for _, def in ipairs(PAGES) do
		if def.parent == topId and not def.target then list[#list + 1] = def end
	end
	return list
end

-- la page porte-t-elle ses propres réglages (sinon c'est un simple titre de groupe)
local function HasContent(def)
	return not def.target and (def.rows or def.modules or def.list or def.info or def.actions or def.frameButtons or def.tabs) ~= nil
end

-- clé de l'interrupteur d'une page : `power`, sinon le module enregistré
-- (ns.RegisterModule) qui porte le titre de la page
local function ModuleKey(def)
	if def.power then return def.power end
	for _, module in ipairs(ns.MODULES or {}) do
		if module.label == def.title and module.key then return module.key end
	end
	return nil
end

local function PowerTip(button, def)
	button:SetScript("OnEnter", function(self) Tip(self, { L[def.title] or def.title, L.OPT_NAV_POWER_TIP }) end)
	button:SetScript("OnLeave", HideTip)
end

-- Titre de groupe : capitales ambre. Celui d'une page à sous-pages est
-- cliquable (sa première sous-page) et porte l'interrupteur de son module.
-- Thème forgé : en « pilule » ; or pour une page à sous-pages (une fonction
-- de l'addon, cliquable), arcane pour un simple titre de rangement
-- (navigation) ; l'interrupteur devient un voyant.
local function NavHeader(frame, text, def)
	local header = CreateFrame("Button", nil, frame.navList)
	header:SetSize(NAV_WIDTH - 1, NAV_HEADER_H)
	header.label = Theme.CreateNavGroup(header, text, def and "gold" or "arcane")
	header.label:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 18, 8)
	header.label:SetWidth(NAV_WIDTH - 18 - 40)
	if header.label.SetWordWrap then header.label:SetWordWrap(false) end
	header.power = Theme.CreateNavPower(header, 16)
	header.power:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -12, 4)
	header.power:Hide()
	function header:SetModuleState(state)
		local c = self.label.toneInk or Theme.GOLD
		if state == nil then
			self.moduleOn = nil
			self.power:Hide()
		else
			self.moduleOn = (state == true or state == "on")
			self.power:Show()
			if not self.moduleOn then c = self.label.toneInk and Theme.FORGE_NAV.offInk or Theme.MUTED end
			Theme.SetNavPower(self.power, self.moduleOn)
		end
		self.label:SetTextColor(c[1], c[2], c[3], 1)
	end
	if def then
		header.pageId = def.id
		header:SetScript("OnClick", function()
			local first = Children(def.id)[1]
			ns:SelectOptionsPage(def.target or (HasContent(def) and def.id) or (first and first.id) or def.id)
		end)
		header.powerKey = ModuleKey(def)
		if header.powerKey then
			header.power:SetScript("OnClick", function() ns:ToggleModuleKey(header.powerKey) end)
			PowerTip(header.power, def)
		end
		frame.navHeaders[#frame.navHeaders + 1] = header
	end
	frame.navGroups[#frame.navGroups + 1] = header.label
	return header
end

local function NavItem(frame, def, text, topLevel)
	local item = Theme.CreateNavItem(frame.navList, NAV_WIDTH - 1)
	item:SetText(text or L[def.title] or def.title)
	item.label:SetWidth(NAV_WIDTH - 18 - 40)
	if item.label.SetWordWrap then item.label:SetWordWrap(false) end
	item.pageId = def.id
	item.parentId = def.parent
	item:SetScript("OnClick", function() ns:SelectOptionsPage(def.id) end)
	-- Interrupteur du module, comme le bouton d'alimentation de la barre
	-- latérale d'EllesmereUI : active ou coupe le module sans y naviguer.
	if not text then
		item.powerKey = ModuleKey(def)
		if item.powerKey then
			item.onPower = function() ns:ToggleModuleKey(item.powerKey) end
		elseif topLevel and def.modules then
			item.modules = def.modules
			item.onPower = function() ns:TogglePageModules(def.id) end
		end
		if item.onPower then PowerTip(item.power, def) end
	end
	frame.navButtons[#frame.navButtons + 1] = item
	return item
end

-- Liste de navigation : une page à sous-pages devient un titre de groupe
-- (son titre) suivi d'une entrée par sous-page (« Vue d'ensemble » d'abord
-- si elle a ses propres réglages) ; une page sans sous-page est une entrée
-- sous le titre de son `group`. La liste défile à la molette si elle dépasse.
local function BuildNav(frame)
	local list = CreateFrame("Frame", nil, frame.nav)
	list:SetPoint("TOPLEFT", frame.nav, "TOPLEFT", 0, NAV_TOP)
	list:SetSize(NAV_WIDTH - 1, NAV_VIEW)
	list.items = {}
	list.viewHeight = NAV_VIEW
	list.scrollTrack = Theme.Solid(frame.nav, "BORDER", Theme.EDGE_SOFT, 1)
	list.scrollTrack:SetWidth(2)
	list.scrollTrack:SetPoint("TOPLEFT", frame.nav, "TOPLEFT", NAV_WIDTH - 5, NAV_TOP)
	list.scrollThumb = Theme.Solid(frame.nav, "ARTWORK", Theme.GOLD, 0.8)
	list.scrollThumb:SetWidth(2)
	if list.EnableMouseWheel then list:EnableMouseWheel(true) end
	list:SetScript("OnMouseWheel", function(_, delta) ns:ScrollOptionsNav(delta) end)
	frame.navList = list

	local function Add(region, kind)
		list.items[#list.items + 1] = { region = region, kind = kind, x = 0, height = region:GetHeight() }
	end
	local lastGroup = nil
	for _, def in ipairs(PAGES) do
		if not def.parent then
			local children = Children(def.id)
			if #children > 0 then
				Add(NavHeader(frame, L[def.title] or def.title, def), "section")
				if HasContent(def) then Add(NavItem(frame, def, L.OPT_NAV_OVERVIEW), "card") end
				for _, child in ipairs(children) do Add(NavItem(frame, child), "card") end
				lastGroup = false   -- la page suivante reprend le titre de son groupe
			else
				if def.group and def.group ~= lastGroup then Add(NavHeader(frame, L[def.group] or def.group), "section") end
				lastGroup = def.group
				Add(NavItem(frame, def, nil, true), "card")
			end
		end
	end
	local y = 0
	for _, item in ipairs(list.items) do
		item.y = y
		y = y + item.height
	end
	list.contentHeight = y
	list.stops = ScrollStops(list)
	list.stopIndex = 1
	frame.navBottom = NAV_TOP - NAV_VIEW
	ns:ApplyOptionsScroll(list)
end

-- molette sur la navigation : delta > 0 remonte
function ns:ScrollOptionsNav(delta)
	local list = self.optionsFrame and self.optionsFrame.navList
	if not list then return nil end
	list.stopIndex = (list.stopIndex or 1) - (delta > 0 and 1 or -1)
	self:ApplyOptionsScroll(list)
	return list.offset
end

-- la page choisie est visible dans la navigation (avec son titre de groupe
-- quand c'est la première de son groupe)
local function RevealNav(frame, pageId)
	local list = frame.navList
	for index, item in ipairs(list.items) do
		if item.kind == "card" and item.region.pageId == pageId then
			local previous = list.items[index - 1]
			local top = (previous and previous.kind == "section") and previous.y or item.y
			local bottom = item.y + item.height
			local offset = list.stops[list.stopIndex or 1] or 0
			if top < offset then
				for stop = #list.stops, 1, -1 do
					if list.stops[stop] <= top then list.stopIndex = stop; break end
				end
			elseif bottom > offset + list.viewHeight then
				for stop = 1, #list.stops do
					if list.stops[stop] + list.viewHeight >= bottom then list.stopIndex = stop; break end
				end
			end
			ns:ApplyOptionsScroll(list)
			return
		end
	end
end

function ns:EnsureOptions()
	if self.optionsFrame then return self.optionsFrame end
	if not Theme or not Theme.CreateWindow then return nil end

	local frame = Theme.CreateWindow(UIParent, FRAME_WIDTH, FRAME_HEIGHT,
		{ name = ns.APP.id .. "OptionsFrame", nav = NAV_WIDTH, footer = FOOTER, emblem = Theme.Forged() })
	if not frame then return nil end
	frame:Hide()
	ns:RestorePoint(frame, "optionsPoint", { point = "CENTER", x = 0, y = 20 })

	frame.rows, frame.pages, frame.navButtons, frame.lists, frame.notes = {}, {}, {}, {}, {}
	frame.navGroups, frame.navHeaders, frame.previews, frame.pageOrder = {}, {}, {}, {}
	frame.tabPages, frame.tabDefs, frame.tabChoice = {}, {}, {}
	local content = frame.content

	-- Navigation : marque, recherche, groupes et pages, version en bas
	local nav = frame.nav
	-- thème forgé : colonne plus sombre au bord gauche, séparateur noir et
	-- reflet ; pied en bande plus sombre sous un filet noir et son reflet
	Theme.ForgeNavColumn(nav)
	Theme.ForgeFooter(frame.footer)
	frame.brand = Theme.CreateNavBrand(nav, Theme.LOGO, ns.APP.brand or ns.APP.id, Theme.Forged())
	frame.brand:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -8)
	frame.brand:SetWidth(NAV_WIDTH)
	frame.brandLogo, frame.brandName = frame.brand.logo, frame.brand.name
	frame.search = Theme.CreateSearchBox(nav, NAV_WIDTH - 32, L.OPT_SEARCH, function(text) ns:SetOptionsSearch(text) end)
	frame.search:SetPoint("TOPLEFT", nav, "TOPLEFT", 16, -86)
	BuildNav(frame)

	frame.version = Theme.Text(nav, Theme.F_SMALL, Theme.MUTED)
	frame.version:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 18, 18)
	local client
	if self.ClientFlavour then
		local ok, flavour = pcall(self.ClientFlavour, self)
		if ok then client = flavour end
	end
	frame.version:SetText(self:F("OPT_VERSION_LINE", tostring(ns.APP.version or "?"), tostring(client or "?")))

	-- Zone de droite : en-tête, onglets, aperçu, ascenseur
	frame.header = Theme.CreatePageHeader(content, CONTENT_W)
	frame.header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	frame.header.title:SetWidth(INNER - 40)
	if frame.header.title.SetWordWrap then frame.header.title:SetWordWrap(false) end
	frame.header.subtitle:SetWidth(INNER)
	if frame.header.subtitle.SetWordWrap then frame.header.subtitle:SetWordWrap(false) end
	-- socle 2.11.0 : « Rallumer » d'un module coupé, à droite de la phrase
	frame.offBanner = Theme.CreateButton(frame.header, "auto", 22, L.OPT_PAGE_OFF_ON, function(button)
		if button.key then ns:ToggleModuleKey(button.key) end
	end, ActionStyle("outline", "add"))
	frame.offBanner:SetPoint("TOPRIGHT", frame.header, "TOPRIGHT", -MARGIN, -55)
	frame.offBanner:Hide()

	frame.tabs = Theme.CreateTabs(content, function(id) ns:SelectOptionsPage(id) end)
	frame.tabs:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN, TABS_TOP)
	frame.tabs:SetWidth(INNER)

	frame.previewStrip = CreateFrame("Frame", nil, content)
	frame.previewStrip:SetSize(INNER, PREVIEW_H)
	frame.previewStrip.bg = Theme.Solid(frame.previewStrip, "BACKGROUND", Theme.NAV, 1)
	frame.previewStrip.bg:SetAllPoints()
	frame.previewStrip.border = Theme.Border(frame.previewStrip, Theme.EDGE_SOFT, 1)
	-- thème forgé : le relief d'une carte (voile, reflet d'un pixel)
	if Theme.ForgeHere() then Theme.ForgeRelief(frame.previewStrip, true) end
	frame.previewStrip:Hide()

	frame.scrollTrack = Theme.Solid(content, "BORDER", Theme.EDGE_SOFT, 1)
	frame.scrollTrack:SetWidth(3)
	frame.scrollThumb = Theme.Solid(content, "ARTWORK", Theme.GOLD, 0.8)
	frame.scrollThumb:SetWidth(3)
	frame.scrollTrack:Hide(); frame.scrollThumb:Hide()
	if content.EnableMouseWheel then content:EnableMouseWheel(true) end
	content:SetScript("OnMouseWheel", function(_, delta) ns:ScrollOptions(delta) end)

	-- Pages
	local placed = {}
	for _, def in ipairs(PAGES) do
		if not def.target then BuildPage(frame, def, placed) end
	end

	-- tout check sans page tombe dans « Général » : un module ajouté plus tard
	-- ne doit pas devenir impossible à couper
	frame.unplaced = {}
	local general = frame.pages.general
	for _, check in ipairs(ns.checks or {}) do
		if not placed[check.id] then
			if #frame.unplaced == 0 then general.modulesHeader = Section(frame, general, "OPT_MODULES") end
			frame.unplaced[#frame.unplaced + 1] = check.id
			AddCard(frame, general, ModuleCard(general, check))
		end
	end

	-- Résultats de recherche : un conteneur à part, qui emprunte les cartes
	frame.searchPage = CreateFrame("Frame", nil, content)
	frame.searchPage:SetSize(INNER, 400)
	frame.searchPage.items, frame.searchPage.sections = {}, {}
	frame.searchPage.empty = Theme.Text(frame.searchPage, Theme.F_BODY, Theme.MUTED)
	frame.searchPage.empty:SetPoint("TOPLEFT", frame.searchPage, "TOPLEFT", 0, -4)
	frame.searchPage:Hide()

	-- Pied : action principale de l'addon et remise à zéro à gauche, Terminé à droite
	local foot = frame.footer
	local probe = Theme.Text(foot, Theme.F_LABEL, Theme.LABEL)
	probe:Hide()
	local function Width(text) return math.max(120, math.ceil(TextWidth(probe, text)) + 36) end
	local main = ns.OPTIONS_MAIN or {}
	local mainText = L[main.label or ""] or tostring(main.label or "")
	frame.runButton = Theme.CreateButton(foot, Width(mainText), 28, mainText, function()
		if main.run then main.run(ns) end
	end, "outline")
	frame.runButton:SetPoint("LEFT", foot, "LEFT", MARGIN, 0)
	frame.resetButton = Theme.CreateButton(foot, Width(L.OPT_RESET), 28, L.OPT_RESET, function()
		ns:HandleCommand("reset")
		ns:RefreshOptions()
	end, "outline")
	frame.resetButton:SetPoint("LEFT", frame.runButton, "RIGHT", 10, 0)
	frame.closeButton = Theme.CreateButton(foot, Width(L.OPT_DONE), 28, L.OPT_DONE, function()
		frame:Hide()
	end, ActionStyle("accent", "primary"))
	frame.closeButton:SetPoint("RIGHT", foot, "RIGHT", -MARGIN, 0)

	-- la recherche se vide à la fermeture
	frame:SetScript("OnHide", function()
		if frame.searching then ns:SelectOptionsPage(frame.currentPage) end
	end)

	self.optionsFrame = frame
	self:SelectOptionsPage(self:DB().optionsPage or "general")
	return frame
end

-- Interrupteur d'un module (clé de réglage) ; l'addon réagit dans
-- ns:OnModuleToggled(key, enabled)
function ns:ToggleModuleKey(key)
	local db = self:DB()
	db[key] = not (db[key] ~= false)
	if self.OnModuleToggled then self:OnModuleToggled(key, db[key]) end
	if self.ApplyDisplayOptions then self:ApplyDisplayOptions() end
	self:RefreshOptions()
end

-- "on" (tous actifs), "off" (tous coupés) ou "partial"
function ns:PageModuleState(modules)
	local on, total = 0, 0
	for _, id in ipairs(modules or {}) do
		if CheckDef(id) then
			total = total + 1
			if self:IsModuleEnabled(id) then on = on + 1 end
		end
	end
	if total == 0 or on == total then return "on" end
	if on == 0 then return "off" end
	return "partial"
end

-- Tout actif -> tout coupé ; coupé ou partiel -> tout rallumé
function ns:TogglePageModules(pageId)
	local page = PageDef(pageId)
	if not page or not page.modules then return end
	local enable = self:PageModuleState(page.modules) ~= "on"
	for _, id in ipairs(page.modules) do
		if CheckDef(id) then self:SetModuleEnabled(id, enable) end
	end
	self:RefreshOptions()
end

-- Haut de la zone de réglages sous l'en-tête : sous les onglets s'il y en a,
-- sous l'aperçu s'il y en a un
local function PlaceBody(frame, hasTabs, preview)
	local top = hasTabs and (TABS_TOP - Theme.TABS_HEIGHT - 12) or (TABS_TOP - 4)
	if preview then
		frame.previewStrip:ClearAllPoints()
		frame.previewStrip:SetPoint("TOPLEFT", frame.content, "TOPLEFT", MARGIN, top)
		frame.previewStrip:Show()
		top = top - PREVIEW_H - 12
	else
		frame.previewStrip:Hide()
	end
	frame.bodyTop = top
	frame.scrollTrack:ClearAllPoints()
	frame.scrollTrack:SetPoint("TOPLEFT", frame.content, "TOPLEFT", CONTENT_W - 12, top)
	return top, top - BODY_BOTTOM
end

local function ShowContainer(frame, container, top, view)
	for _, page in pairs(frame.pages) do
		if page ~= container then page:Hide() end
	end
	if frame.searchPage ~= container then frame.searchPage:Hide() end
	container:ClearAllPoints()
	container:SetPoint("TOPLEFT", frame.content, "TOPLEFT", MARGIN, top)
	container:SetSize(INNER, view)
	container.viewHeight = view
	frame.activeContainer = container
	container:Show()
	ns:LayoutOptionsContainer(container)
end

-- aperçu d'une page (ou de sa page parente), construit une fois
local function PreviewFor(frame, def)
	local owner = def.preview and def or nil
	if not owner and def.parent then
		local parent = PageDef(def.parent)
		if parent and parent.preview then owner = parent end
	end
	for _, other in pairs(frame.previews) do other:Hide() end
	if not owner then return nil end
	local container = frame.previews[owner.id]
	if not container then
		container = CreateFrame("Frame", nil, frame.previewStrip)
		container:SetAllPoints(frame.previewStrip)
		container:SetSize(INNER, PREVIEW_H)
		container.pageId = owner.id
		local ok, err = pcall(owner.preview, ns, container)
		if not ok then ns:RecordError("options:preview", err) end
		frame.previews[owner.id] = container
	end
	container:Show()
	return container
end

local function DefOf(frame, id)
	return PageDef(id) or frame.tabDefs[id]
end

-- socle 2.11.0 : clé de réglage du module d'une page (une page à onglets suit
-- sa page parente), nil si la page n'a pas d'interrupteur
function ns:OptionsPageModuleKey(pageId)
	local frame = self.optionsFrame
	if not (frame and pageId) then return nil end
	local def = DefOf(frame, pageId)
	if def and def.tabOf then def = PageDef(def.tabOf) or def end
	if not def then return nil end
	if def.power == nil and def.parent then
		-- sous-page sans clé propre : celle de son groupe
		local own = ModuleKey(def)
		if own then return own end
		local parent = PageDef(def.parent)
		return parent and ModuleKey(parent) or nil
	end
	return ModuleKey(def)
end

-- Bandeau « module coupé » : dans l'en-tête, à la place de la phrase de la
-- page (pas de relayout de la page), avec un bouton « Rallumer »
function ns:RefreshModuleOffBanner()
	local frame = self.optionsFrame
	local banner = frame and frame.offBanner
	if not banner then return end
	local key = self:OptionsPageModuleKey(frame.currentPage)
	local off = key ~= nil and not frame.searching and self:DB()[key] == false
	banner.key = off and key or nil
	if off then
		banner.showing = true
		frame.header:SetSubtitle(L.OPT_PAGE_OFF)
		frame.header.subtitle:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		frame.header.subtitle:SetWidth(INNER - (banner:GetWidth() or 0) - 12)
		banner:Show()
	elseif banner.showing then
		-- la phrase de la page revient (la recherche pose la sienne elle-même)
		banner.showing = nil
		if not frame.searching then frame.header:SetSubtitle(frame.pageSubtitle or "") end
		frame.header.subtitle:SetTextColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3], 1)
		frame.header.subtitle:SetWidth(INNER)
		banner:Hide()
	end
end

function ns:SelectOptionsPage(id)
	local frame = self.optionsFrame
	if not frame then return end
	-- entrée sans page propre (titre de groupe) : sa première sous-page
	local target = PageDef(id)
	if target and target.target then id = target.target end
	target = PageDef(id)
	if target and not HasContent(target) and Children(id)[1] then id = Children(id)[1].id end
	-- page à onglets : son dernier onglet choisi, sinon le premier
	target = PageDef(id)
	if target and target.tabs and target.tabs[1] then
		id = id .. ":" .. tostring(frame.tabChoice[id] or target.tabs[1].id)
	end
	if not frame.pages[id] then id = "general" end
	local def = DefOf(frame, id)
	local owner = def.tabOf and PageDef(def.tabOf) or def

	-- choisir une page referme la recherche
	if frame.searching then
		frame.searching = nil
		frame.search.lastValue = ""
		frame.search:SetText("")
		frame.search:Refresh()
		for _, nav in ipairs(frame.navButtons) do nav:SetBadge(nil) end
	end

	frame.currentPage = id
	frame.currentParent = owner.parent
	frame.navPage = owner.id
	self:DB().optionsPage = id

	-- en-tête : le titre de la page choisie, sa phrase (sinon celle de son groupe)
	local parent = owner.parent and PageDef(owner.parent)
	frame.header:SetTitle(L[owner.title] or owner.title)
	frame.pageSubtitle = Declared(owner.title .. "_SUB") or (parent and Declared(parent.title .. "_SUB")) or ""
	frame.header:SetSubtitle(frame.pageSubtitle)

	if owner.tabs then
		local tabs = {}
		for _, tab in ipairs(owner.tabs) do
			tabs[#tabs + 1] = { id = owner.id .. ":" .. tostring(tab.id), label = L[tab.label] or tab.label or tostring(tab.id) }
		end
		frame.tabs:SetTabs(tabs)
		frame.tabs:Select(id, true)
		frame.tabs:Show()
		frame.tabChoice[owner.id] = def.tabId
	else
		frame.tabs:SetTabs({})
		frame.tabs:Hide()
	end

	frame.currentPreview = PreviewFor(frame, owner)
	local bodyTop, view = PlaceBody(frame, owner.tabs ~= nil, frame.currentPreview)
	ShowContainer(frame, frame.pages[id], bodyTop, view)
	RevealNav(frame, owner.id)
	self:RefreshOptions()
end

-- Éléments d'une page qu'on ne verrait jamais, même en la faisant défiler
-- jusqu'en bas (tests, diagnostic) : liste vide si tout se voit
function ns:OptionsUnreachable(id)
	local frame = self:EnsureOptions()
	if not (frame and frame.pages[id]) then return { id } end
	local page = frame.pages[id]
	self:SelectOptionsPage(id)
	local seen, missing = {}, {}
	for _ = 1, #page.items + 2 do
		for index, item in ipairs(page.items) do
			if item.region:IsShown() then seen[index] = true end
		end
		self:ScrollOptions(-1)
	end
	for index in ipairs(page.items) do
		if not seen[index] then missing[#missing + 1] = id .. "#" .. index end
	end
	page.stopIndex = 1
	self:ApplyOptionsScroll(page)
	return missing
end

-- ---------------------------------------------------------------------------
-- Recherche : les cartes dont le libellé contient tous les mots tapés, de
-- toutes les pages, regroupées par page (titre de la page, onglet entre
-- parenthèses). La navigation compte les résultats de chaque page. Vider le
-- champ (ou choisir une page) rend la vue normale.
-- ---------------------------------------------------------------------------
function ns:FindOptions(text)
	local frame = self.optionsFrame
	local query = Fold(text)
	local words = {}
	for word in query:gmatch("%S+") do words[#words + 1] = word end
	local groups = {}
	if not frame or #words == 0 then return groups, 0 end
	local total = 0
	for _, page in ipairs(frame.pageOrder) do
		local def = page.def
		do
			local found = {}
			for _, card in ipairs(page.rows) do
				local hit = true
				for _, word in ipairs(words) do
					if not card.searchText:find(word, 1, true) then hit = false; break end
				end
				if hit then found[#found + 1] = card end
			end
			if #found > 0 then
				groups[#groups + 1] = { def = def, cards = found }
				total = total + #found
			end
		end
	end
	return groups, total
end

function ns:SetOptionsSearch(text)
	local frame = self.optionsFrame
	if not frame then return end
	text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if Fold(text) == "" then
		if frame.searching then self:SelectOptionsPage(frame.currentPage) end
		return
	end
	frame.searching = true
	frame.searchText = text
	local groups, total = self:FindOptions(text)

	local results = frame.searchPage
	results.items = {}
	local counts = {}
	for index, group in ipairs(groups) do
		local def = group.def
		local owner = def.tabOf and PageDef(def.tabOf) or def
		local parent = owner.parent and PageDef(owner.parent)
		local detail = parent and (L[parent.title] or parent.title) or nil
		if def.tabOf then
			for _, tab in ipairs(owner.tabs) do
				if tab.id == def.tabId then detail = L[tab.label] or tab.label end
			end
		end
		local section = results.sections[index]
		if not section then
			-- résultats : sections de navigation (où vit le réglage), en arcane
			section = Theme.CreateSection(results, "", nil, "arcane")
			section:SetWidth(INNER)
			results.sections[index] = section
		end
		section:SetText(L[owner.title] or owner.title, detail)
		results.items[#results.items + 1] = { region = section, kind = "section", height = SECTION_H }
		for _, card in ipairs(group.cards) do
			results.items[#results.items + 1] = { region = card, kind = "card", height = card:GetHeight() }
		end
		counts[owner.id] = (counts[owner.id] or 0) + #group.cards
	end
	for index = #groups + 1, #results.sections do results.sections[index]:Hide() end
	results.total = total
	results.empty:SetText(total == 0 and self:F("OPT_SEARCH_NONE", text) or "")

	frame.header:SetTitle(L.OPT_SEARCH_TITLE)
	frame.header:SetSubtitle(total > 0 and self:F("OPT_SEARCH_COUNT", total, text) or "")
	frame.tabs:Hide()
	for _, other in pairs(frame.previews) do other:Hide() end
	frame.currentPreview = nil
	local bodyTop, view = PlaceBody(frame, false, nil)
	-- les pages rendent leurs cartes : elles sont rattachées aux résultats
	ShowContainer(frame, results, bodyTop, view)
	for _, nav in ipairs(frame.navButtons) do
		local count = counts[nav.pageId]
		nav:SetBadge(count and tostring(count) or nil)
	end
	self:RefreshOptions()
end

-- « Une seule fenêtre à la fois » : les grandes fenêtres de l'addon ne
-- s'empilent pas. Le carnet de voyage n'y était pas soumis et recouvrait les
-- réglages (signalé en jeu). Les cadres discrets (résumé, compagnon, suivi)
-- ne sont pas concernés.
-- Chaque addon y ajoute ses grandes fenêtres (champ de ns).
ns.EXCLUSIVE_WINDOWS = ns.EXCLUSIVE_WINDOWS or { "optionsFrame" }
function ns:CloseOtherWindows(keep)
	for _, field in ipairs(self.EXCLUSIVE_WINDOWS) do
		local other = self[field]
		if other and other ~= keep and other.IsShown and other:IsShown() then other:Hide() end
	end
end

function ns:ToggleOptions()
	local frame = self:EnsureOptions()
	if not frame then return end
	if frame:IsShown() then
		frame:Hide()
	else
		-- Une seule fenêtre à la fois : les autres se ferment
		self:CloseOtherWindows(frame)
		if self.StopEditMode then self:StopEditMode() end
		self:RefreshOptions()
		frame:Show()
	end
end

-- ---------------------------------------------------------------------------
-- Entrée dans Échap > Options > AddOns (Settings, moteur récent)
-- ---------------------------------------------------------------------------
-- Le grand panneau garde sa taille et sa fermeture : il n'est pas logé dans
-- le cadre de Blizzard. La page native ne porte que le nom, la version, une
-- ligne et un bouton qui ferme les options du jeu puis ouvre les nôtres.
-- Une seule inscription par addon, à la connexion ; la catégorie est gardée
-- (ns.settingsCategory) pour un éventuel Settings.OpenToCategory(category:GetID()).
-- Sans Settings.RegisterCanvasLayoutCategory / RegisterAddOnCategory : rien.
function ns:OpenOptionsFromSettings()
	local panel = rawget(_G, "SettingsPanel")
	local hideUI = rawget(_G, "HideUIPanel")
	if panel and type(hideUI) == "function" then pcall(hideUI, panel)
	elseif panel and type(panel.Hide) == "function" then pcall(panel.Hide, panel) end
	local frame = self:EnsureOptions()
	if frame and not frame:IsShown() then self:ToggleOptions() end
end

function ns:RegisterSettingsCategory()
	if self.settingsTried then return self.settingsCategory end
	local settings = rawget(_G, "Settings")
	if type(settings) ~= "table" or type(settings.RegisterCanvasLayoutCategory) ~= "function"
		or type(settings.RegisterAddOnCategory) ~= "function" or type(CreateFrame) ~= "function" then
		return nil
	end
	self.settingsTried = true

	local made, canvas = pcall(CreateFrame, "Frame")
	if not made or not canvas then return nil end
	local name = tostring(ns.APP.id)
	canvas.name = name

	-- en-tête de page (docs/UI.md) : le nom en grand, la version, le filet
	-- ambre ; puis une ligne et le bouton en contour ambre
	canvas.header = Theme.CreatePageHeader(canvas, 640)
	canvas.header:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
	canvas.title, canvas.version = canvas.header.title, canvas.header.subtitle
	canvas.title:SetText(ns.APP.brand or name)
	canvas.version:SetText(ns:F("SETTINGS_VERSION", tostring(ns.APP.version)))
	canvas.hint = Theme.Text(canvas, Theme.F_BODY, Theme.TEXT)
	canvas.hint:SetPoint("TOPLEFT", canvas, "TOPLEFT", 24, -Theme.HEADER_HEIGHT - 8)
	canvas.hint:SetJustifyH("LEFT")
	canvas.hint:SetText(L.SETTINGS_HINT)
	canvas.open = Theme.CreateButton(canvas, nil, 28, L.SETTINGS_OPEN, function() ns:OpenOptionsFromSettings() end, "accent")
	canvas.open:SetPoint("TOPLEFT", canvas.hint, "BOTTOMLEFT", 0, -16)

	local ok, category = pcall(settings.RegisterCanvasLayoutCategory, canvas, name)
	if not ok or category == nil then return nil end
	if not pcall(settings.RegisterAddOnCategory, category) then return nil end
	self.settingsCategory, self.settingsCanvas = category, canvas
	return category
end

do
	local ok, frame = pcall(CreateFrame, "Frame")
	if ok and frame then
		pcall(frame.RegisterEvent, frame, "PLAYER_LOGIN")
		frame:SetScript("OnEvent", function()
			local done, err = pcall(ns.RegisterSettingsCategory, ns)
			if not done then ns:RecordError("settings", err) end
		end)
		ns.settingsEventFrame = frame
	end
end

-- Applique immédiatement les réglages d'affichage
function ns:ApplyDisplayOptions()
	local db = self:DB()
	if db.showMinimap == false then
		if self.HideMinimapButton then self:HideMinimapButton() end
	else
		if self.ShowMinimapButton then self:ShowMinimapButton() end
	end
end

-- Bandeau du mode édition : toujours visible, jamais recouvert par les
-- cadres à déplacer, et doté de son propre bouton de sortie. Le panneau de
-- réglages se fermant à l'entrée en édition (pour dégager la vue), le bouton
-- « Terminer » qui s'y trouvait disparaissait avec lui : on restait bloqué
-- en édition sans autre issue que la commande /sd move stop.
function ns:EnsureEditBanner()
	if self.editBanner then return self.editBanner end
	if not Theme or not Theme.CreateToast then return nil end

	-- bandeau (docs/UI.md) : liseré ambre, titre et aide à gauche, « Terminer
	-- le déplacement » à droite, côte à côte : l'aide ne passe jamais sous le
	-- bouton (vu en jeu avant la v1.20.0, quand ils étaient empilés)
	local banner = Theme.CreateToast(UIParent, 460, 56, { strata = "TOOLTIP" })
	if not banner then return nil end
	banner:EnableMouse(true)
	local left = banner.contentLeft

	banner.stopButton = Theme.CreateButton(banner, nil, 28, L.OPT_EDIT_STOP, function()
		ns:StopEditMode()
	end, "primary")
	banner.stopButton:SetPoint("RIGHT", banner, "RIGHT", -12, 0)
	local textWidth = 460 - left - banner.stopButton:GetWidth() - 12 - 12

	banner.title = Theme.Text(banner, Theme.F_LABEL, Theme.PARCHMENT)
	banner.title:SetPoint("TOPLEFT", banner, "TOPLEFT", left, -11)
	banner.title:SetWidth(textWidth)
	banner.title:SetJustifyH("LEFT")
	banner.title:SetText(L.OPT_EDIT_MODE)
	if banner.title.SetWordWrap then banner.title:SetWordWrap(false) end

	banner.hint = Theme.Text(banner, Theme.F_SMALL, Theme.MUTED_LIGHT)
	banner.hint:SetPoint("TOPLEFT", banner, "TOPLEFT", left, -29)
	banner.hint:SetWidth(textWidth)
	banner.hint:SetJustifyH("LEFT")
	if banner.hint.SetWordWrap then banner.hint:SetWordWrap(false) end
	banner.hint:SetText(L.OPT_EDIT_HINT)

	self.editBanner = banner
	return banner
end

function ns:ShowEditBanner()
	local banner = self:EnsureEditBanner()
	if not banner then return end
	banner:ClearAllPoints()
	banner:SetPoint("TOP", UIParent, "TOP", 0, -120)
	banner:Show()
end

function ns:HideEditBanner()
	if self.editBanner then self.editBanner:Hide() end
end

-- Actions du panneau de réglages : communes (mode édition, position du bouton
-- de minicarte), puis celles de l'addon (ns.OPTION_ACTIONS[clé] = function(self))
ns.OPTION_ACTIONS = ns.OPTION_ACTIONS or {}
function ns:RunOptionAction(key)
	if self.OPTION_ACTIONS[key] then
		self.OPTION_ACTIONS[key](self)
	elseif key == "editMode" and self.ToggleEditMode then
		-- on ferme les réglages pour laisser voir les deux cadres ; le bandeau
		-- d'édition prend le relais pour en sortir
		if not self.editMode and self.optionsFrame then self.optionsFrame:Hide() end
		self:ToggleEditMode()
		if self.RefreshOptions then self:RefreshOptions() end
	elseif key == "minimapPos" and self.CycleMinimapAngle then
		self:CycleMinimapAngle()
	end
end

_G[ns.APP.id .. "Options"] = function() ns:ToggleOptions() end

ns.Mark("Options")
end)(SOCLE_ADDON, SOCLE_NS)
