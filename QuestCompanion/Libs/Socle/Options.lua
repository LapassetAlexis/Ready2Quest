-- Options.lua -- panneau de réglages, même habillage que le reste (Theme)
--
-- v1.19.0 : navigation par pages, à la manière d'ElvUI. Une liste à gauche,
-- le contenu de la page à droite. Chaque page regroupe l'interrupteur d'un
-- module ET ses réglages : avant, l'interrupteur des vivres était dans
-- « Modules » et leur seuil dans « Alertes ». La hauteur du panneau ne dépend
-- plus du nombre de réglages (910 px en 1.18.0 avant refonte, hors écran).
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py. Chaque addon déclare ses pages
-- (ns.AddOptionPage), ses listes (ns.OPTION_LISTS), ses actions
-- (ns.OPTION_ACTIONS) et le bouton principal du pied (ns.OPTIONS_MAIN).
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local FRAME_WIDTH  = 600
local FRAME_HEIGHT = 520   -- 440 -> 480 (v1.23.0) -> 520 (v1.25.0) : modules ajoutés à la navigation
local NAV_WIDTH    = 178   -- place pour « Check avant le départ » + son interrupteur (mesuré en jeu)
local PANE_LEFT    = NAV_WIDTH + 16
local PANE_WIDTH   = FRAME_WIDTH - PANE_LEFT - 14
local ROW_HEIGHT   = 22
local LIST_LINES   = 9

-- ---------------------------------------------------------------------------
-- Pages. `modules` = interrupteurs de checks (ns.checks), `rows` = réglages,
-- `list` = liste défilante (ns.OPTION_LISTS), `buttons` = actions, `info` =
-- paragraphes d'explication. Un module a son interrupteur dans la navigation
-- (`power` = clé de réglage) ; une sous-page porte `parent`. Chaque addon
-- déclare ses pages avec ns.AddOptionPage ; il en faut une d'id « general ».
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
	paneLeft = PANE_LEFT,
	paneWidth = PANE_WIDTH,
	rowWidth = PANE_WIDTH,
	rowHeight = ROW_HEIGHT,
	listLines = LIST_LINES,
	-- [libellé] ... [piste 80] [valeur 44] [-][+]  ou  [libellé] ... [interrupteur]
	valueRight = -78,
	valueWidth = 44,
	trackRight = -128,
	trackWidth = 80,
	toggleRight = -18,
	plusRight = -18,
	minusRight = -50,
	buttonWidth = 22,
	maxHeight = 740,
}
local VALUE_RIGHT = ns.OPT_LAYOUT.valueRight
local VALUE_WIDTH = ns.OPT_LAYOUT.valueWidth
local PLUS_RIGHT  = ns.OPT_LAYOUT.plusRight
local MINUS_RIGHT = ns.OPT_LAYOUT.minusRight

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

	for _, row in ipairs(frame.rows or {}) do
		local suffix = ""
		if row.def and row.def.suffix then
			suffix = " " .. (L[row.def.suffix] or row.def.suffix)
		end
		if row.isModule then
			local on = ns:IsModuleEnabled(row.moduleId)
			row.value:SetText(OnOff(on))
			if row.toggle then row.toggle:SetChecked(on) end
			if on then
				row.label:SetTextColor(0.85, 0.85, 0.85)
			else
				row.label:SetTextColor(0.42, 0.42, 0.42)
			end
		elseif row.def and row.def.kind == "action" then
			if row.def.key == "minimapPos" then
				row.value:SetText(Theme.T_GOLD .. string.format("%d°", math.floor((db.minimapAngle or 225) + 0.5)) .. "|r")
			else
				-- flèche ASCII volontaire : U+25B6 n'existe pas dans
				-- GameFontNormal et s'affiche en losange (cf. 1.12.0)
				row.value:SetText(Theme.T_GOLD .. ">|r")
			end
		elseif row.def then
			local def = row.def
			local value = db[def.key]
			if def.kind == "bool" then
				row.value:SetText(OnOff(value ~= false))
				if row.toggle then row.toggle:SetChecked(value ~= false) end
				if row.note and def.describe then row.note:SetText(def.describe(value ~= false)) end
			else
				if row.track then
					local span = (def.max or 1) - (def.min or 0)
					row.track:SetValue(span > 0 and (((value or 0) - (def.min or 0)) / span) or 0)
				end
				-- l'unité est portée par la valeur, pas par le libellé : la
				-- colonne de gauche reste courte et scannable ; def.display
				-- donne un nom au cran (« Calme ») à la place du nombre
				if def.display then
					row.value:SetText(Theme.T_GOLD .. tostring(def.display(value or 0)) .. "|r")
				else
					row.value:SetText(Theme.T_GOLD .. tostring(value or 0) .. "|r"
						.. Theme.T_GREY .. suffix .. "|r")
				end
				if row.note and def.describe then row.note:SetText(def.describe(value or 0)) end
			end
		end
	end

	for _, nav in ipairs(frame.navButtons or {}) do
		-- le module « Check avant le départ » reste actif quand une de ses
		-- sous-pages est ouverte
		local selected = nav.pageId == frame.currentPage or (nav.pageId == frame.currentParent)
		local state
		if nav.powerKey then
			state = (db[nav.powerKey] ~= false) and "on" or "off"
			nav.power:SetChecked(state == "on")
		end
		nav.state = state
		if selected then
			nav.label:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
			nav.marker:Show(); nav.tint:Show()
			nav.diamond:SetTexture(Theme.DIAMOND)
			nav.diamond:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		else
			-- page dont tous les modules sont coupés : libellé éteint
			if state == "off" then
				nav.label:SetTextColor(0.40, 0.42, 0.44)
			else
				nav.label:SetTextColor(0.68, 0.70, 0.71)
			end
			nav.marker:Hide(); nav.tint:Hide()
			nav.diamond:SetTexture(Theme.DIAMOND_LINE)
			nav.diamond:SetVertexColor(0.35, 0.38, 0.42, 1)
		end
	end

	for _, list in pairs(frame.lists or {}) do self:RefreshOptionList(list) end
end

-- ---------------------------------------------------------------------------
-- Listes défilantes : zones sûres apprises, buffs suivis.
-- Défilement à la molette et par deux boutons « ^ » / « v » (ASCII : les
-- flèches Unicode ne sont pas garanties dans la police), sans dépendre de
-- FauxScrollFrame, dont la présence n'est pas assurée sur Forever.
-- ---------------------------------------------------------------------------
-- ns.OPTION_LISTS[id] = { items = function() -> { { key, text, detail|value,
--   action, onAction, onToggle } }, empty = clé du texte « liste vide »,
--   header = clé du titre, lines = nombre de lignes, extra = function(page, y)
--   -> y (boutons sous la liste) }
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

local function BuildList(page, source, top)
	local def = LIST_SOURCES[source] or {}
	local list = { source = source, lines = {}, offset = 0, emptyText = def.empty }
	local count = def.lines or LIST_LINES

	for index = 1, count do
		local line = CreateFrame("Button", nil, page)
		line:SetSize(PANE_WIDTH, ROW_HEIGHT - 4)
		line:SetPoint("TOPLEFT", page, "TOPLEFT", 0, top - ((index - 1) * ROW_HEIGHT))

		line.text = line:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		line.text:SetPoint("LEFT", line, "LEFT", 2, 0)
		line.text:SetWidth(170)
		line.text:SetJustifyH("LEFT")
		line.text:SetWordWrap(false)
		line.text:SetTextColor(0.86, 0.84, 0.78)

		line.detail = line:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		line.detail:SetPoint("LEFT", line, "LEFT", 178, 0)
		line.detail:SetWidth(150)
		line.detail:SetJustifyH("LEFT")
		line.detail:SetWordWrap(false)

		line.action = Theme.CreateButton(line, 70, 17, L.OPT_REMOVE, function()
			if line.item and line.item.onAction then
				line.item.onAction()
				ns:RefreshOptions()
			end
		end)
		line.action:SetPoint("RIGHT", line, "RIGHT", -2, 0)

		-- clic sur la ligne : bascule (buffs suivis)
		line:SetScript("OnClick", function()
			if line.item and line.item.onToggle then
				line.item.onToggle()
				ns:RefreshOptions()
			end
		end)
		list.lines[index] = line
	end

	local bottom = top - (count * ROW_HEIGHT)
	list.empty = page:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	list.empty:SetPoint("TOPLEFT", page, "TOPLEFT", 2, top - 4)
	list.empty:SetTextColor(0.55, 0.55, 0.55)

	list.position = page:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	list.position:SetPoint("TOPLEFT", page, "TOPLEFT", 2, bottom - 4)
	list.position:SetTextColor(0.55, 0.55, 0.55)

	list.up = Theme.CreateButton(page, 22, 17, "^", function() ns:ScrollOptionList(list, 1) end)
	list.up:SetPoint("TOPRIGHT", page, "TOPRIGHT", -26, bottom - 2)
	list.down = Theme.CreateButton(page, 22, 17, "v", function() ns:ScrollOptionList(list, -1) end)
	list.down:SetPoint("TOPRIGHT", page, "TOPRIGHT", -2, bottom - 2)

	if page.EnableMouseWheel then
		page:EnableMouseWheel(true)
		page:SetScript("OnMouseWheel", function(_, delta) ns:ScrollOptionList(list, delta) end)
	end
	list.bottom = bottom - 22
	return list
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
function ns:EnsureOptions()
	if self.optionsFrame then return self.optionsFrame end
	if not Theme or not Theme.CreatePanel then return nil end

	local frame = Theme.CreatePanel(UIParent, FRAME_WIDTH, FRAME_HEIGHT, L.OPT_TITLE, { name = ns.APP.id .. "OptionsFrame" })
	if not frame then return nil end

	ns:RestorePoint(frame, "optionsPoint", { point = "CENTER", x = 0, y = 20 })
	if frame.subtitle then frame.subtitle:SetText(L.OPT_HINT) end

	frame.rows, frame.pages, frame.navButtons, frame.lists = {}, {}, {}, {}
	local top = frame.contentTop - 8

	-- fond de la colonne de navigation + filet de séparation
	frame.navBackground = frame:CreateTexture(nil, "BORDER")
	frame.navBackground:SetTexture(Theme.SOLID)
	frame.navBackground:SetVertexColor(Theme.SURFACE_2[1], Theme.SURFACE_2[2], Theme.SURFACE_2[3], 1)
	frame.navBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -35)
	frame.navBackground:SetSize(NAV_WIDTH + 5, FRAME_HEIGHT - 35 - 44)
	frame.navLine = Theme.Solid(frame, "ARTWORK", Theme.GOLD_DIM, 1)
	frame.navLine:SetPoint("TOPLEFT", frame, "TOPLEFT", NAV_WIDTH + 6, -35)
	frame.navLine:SetSize(1, FRAME_HEIGHT - 35 - 44)
	frame.footerLine = Theme.Solid(frame, "ARTWORK", Theme.GOLD_DIM, 1)
	frame.footerLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 44)
	frame.footerLine:SetSize(FRAME_WIDTH - 2, 1)

	-- Fabrique d'une ligne de réglage
	local function MakeRow(parent, def)
		local row = CreateFrame("Button", nil, parent)
		row:SetSize(PANE_WIDTH, ROW_HEIGHT - 6)
		row.def = def

		row.label = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.label:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.label:SetJustifyH("LEFT")
		row.label:SetText(L[def.label] or def.key)
		row.label:SetTextColor(0.86, 0.84, 0.78)

		row.value = row:CreateFontString(nil, "OVERLAY", Theme.F_NUMBER)
		row.value:SetPoint("RIGHT", row, "RIGHT", VALUE_RIGHT, 0)
		row.value:SetWidth(VALUE_WIDTH)
		row.value:SetJustifyH("RIGHT")

		if def.kind == "action" then
			row:SetScript("OnClick", function() ns:RunOptionAction(def.key) end)
		elseif def.kind == "bool" then
			-- interrupteur dessiné ; le texte OUI/non reste porté (lecteurs, tests)
			-- mais masqué : l'interrupteur dit déjà l'état
			row.toggle = Theme.CreateToggle(row)
			row.toggle:SetPoint("RIGHT", row, "RIGHT", ns.OPT_LAYOUT.toggleRight, 0)
			row.value:Hide()
			row:SetScript("OnClick", function()
				local db = ns:DB()
				local before = db[def.key] ~= false
				db[def.key] = not before
				ns:RefreshOptions()
				if ns.ApplyDisplayOptions then ns:ApplyDisplayOptions() end
				if def.onChange then def.onChange(db[def.key], before) end
			end)
		else
			local function Step(delta)
				local db = ns:DB()
				local before = db[def.key]
				db[def.key] = Clamp((db[def.key] or 0) + (delta * (def.step or 1)), def.min or 0, def.max or 999)
				ns:RefreshOptions()
				-- l'addon réagit au nouveau cran (bulle de confirmation…)
				if def.onChange and db[def.key] ~= before then def.onChange(db[def.key], before) end
			end
			-- piste : la valeur dans sa plage, d'un coup d'œil
			row.track = Theme.CreateBar(row, ns.OPT_LAYOUT.trackWidth, 3)
			row.track:SetPoint("RIGHT", row, "RIGHT", ns.OPT_LAYOUT.trackRight, 0)
			row.minus = Theme.CreateButton(row, 22, 17, "-", function() Step(-1) end)
			row.minus:SetPoint("RIGHT", row, "RIGHT", MINUS_RIGHT, 0)
			row.plus = Theme.CreateButton(row, 22, 17, "+", function() Step(1) end)
			row.plus:SetPoint("RIGHT", row, "RIGHT", PLUS_RIGHT, 0)
			if row.EnableMouseWheel then
				row:EnableMouseWheel(true)
				row:SetScript("OnMouseWheel", function(_, delta) Step(delta > 0 and 1 or -1) end)
			end
		end
		-- infobulle de la ligne : def.tooltip(valeur) -> { lignes }
		if def.tooltip then
			row:SetScript("OnEnter", function(self)
				if type(GameTooltip) ~= "table" or not GameTooltip.SetOwner then return end
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				for index, line in ipairs(def.tooltip(ns:DB()[def.key]) or {}) do
					if index == 1 then
						GameTooltip:AddLine(line, Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
					else
						GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true)
					end
				end
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", function()
				if type(GameTooltip) == "table" and GameTooltip.Hide then GameTooltip:Hide() end
			end)
		end
		return row
	end

	local function MakeModuleRow(parent, def)
		local row = CreateFrame("Button", nil, parent)
		row:SetSize(PANE_WIDTH, ROW_HEIGHT - 6)
		row.isModule = true
		row.moduleId = def.id
		row.label = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.label:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.label:SetJustifyH("LEFT")
		row.label:SetText(CheckLabel(def))
		row.value = row:CreateFontString(nil, "OVERLAY", Theme.F_NUMBER)
		row.value:SetPoint("RIGHT", row, "RIGHT", VALUE_RIGHT, 0)
		row.value:SetWidth(VALUE_WIDTH)
		row.value:SetJustifyH("RIGHT")
		row.toggle = Theme.CreateToggle(row)
		row.toggle:SetPoint("RIGHT", row, "RIGHT", ns.OPT_LAYOUT.toggleRight, 0)
		row.value:Hide()
		row:SetScript("OnClick", function()
			ns:SetModuleEnabled(def.id, not ns:IsModuleEnabled(def.id))
			ns:RefreshOptions()
		end)
		return row
	end

	local function Header(page, y, key)
		local header = page:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		header:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
		header:SetText(L[key] or key)
		header:SetTextColor(Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3])
		return header
	end

	-- Marque en tête de navigation : logo complet et nom de l'addon (ns.APP.brand)
	frame.brandLogo = frame:CreateTexture(nil, "OVERLAY")
	frame.brandLogo:SetTexture(Theme.LOGO)
	frame.brandLogo:SetSize(34, 34)
	frame.brandLogo:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, top - 2)
	frame.brandName = Theme.CreateTitle(frame, 15)
	frame.brandName:SetPoint("LEFT", frame.brandLogo, "RIGHT", 7, 0)
	frame.brandName:SetText(ns.APP.brand or ns.APP.id)
	frame.brandLine = Theme.Solid(frame, "ARTWORK", Theme.GOLD_DIM, 1)
	frame.brandLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, top - 42)
	frame.brandLine:SetSize(NAV_WIDTH + 5, 1)

	local placed = {}
	local navY, lastGroup = top - 48, nil
	frame.navOrder, frame.navTop = {}, top - 48
	frame.navGroups = {}
	for index, def in ipairs(PAGES) do
		-- titre de groupe dans la navigation (« PRÉPARATION », « INTERFACE »)
		if def.group and def.group ~= lastGroup then
			navY = navY - 6
			local groupLabel = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
			groupLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, navY - 2)
			frame.navOrder[#frame.navOrder + 1] = { group = groupLabel }
			groupLabel:SetText(L[def.group] or def.group)
			groupLabel:SetTextColor(Theme.BLUE[1], Theme.BLUE[2], Theme.BLUE[3])
			frame.navGroups[#frame.navGroups + 1] = groupLabel
			navY = navY - 16
		end
		lastGroup = def.group

		-- bouton de navigation : losange, libellé, liseré ambre + teinte si actif.
		-- Une sous-page est en retrait, plus basse et sans interrupteur.
		local sub = def.parent ~= nil
		local rowH = sub and (ROW_HEIGHT - 2) or ROW_HEIGHT
		local nav = CreateFrame("Button", nil, frame)
		nav:SetSize(NAV_WIDTH - 4, rowH)
		nav:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, navY)
		nav.rowH = rowH
		frame.navOrder[#frame.navOrder + 1] = { nav = nav }
		nav.pageId = def.id
		nav.parentId = def.parent
		nav.tint = Theme.Solid(nav, "BACKGROUND", Theme.GOLD, 0.12)
		nav.tint:SetAllPoints()
		nav.marker = Theme.Solid(nav, "ARTWORK", Theme.GOLD, 1)
		nav.marker:SetPoint("LEFT", nav, "LEFT", 0, 0)
		nav.marker:SetSize(2, rowH)
		nav.diamond = Theme.CreateDiamond(nav, sub and 5 or 7, true)
		nav.diamond:SetPoint("LEFT", nav, "LEFT", sub and 26 or 12, 0)
		nav.label = nav:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		nav.label:SetPoint("LEFT", nav, "LEFT", sub and 38 or 26, 0)
		nav.label:SetJustifyH("LEFT")
		nav.label:SetText(L[def.title] or def.title)
		nav:SetScript("OnClick", function() ns:SelectOptionsPage(def.target or def.id) end)
		frame.navButtons[index] = nav

		-- Interrupteur du module, comme le bouton d'alimentation de la barre
		-- latérale d'EllesmereUI : active ou coupe le module sans y naviguer.
		if def.power then
			nav.powerKey = def.power
			nav.power = Theme.CreateToggle(nav, 22, 10, "Button")
			nav.power:SetPoint("RIGHT", nav, "RIGHT", -8, 0)
			nav.power:SetScript("OnClick", function() ns:ToggleModuleKey(def.power) end)
			nav.power:SetScript("OnEnter", function(self)
				if type(GameTooltip) ~= "table" or not GameTooltip.SetOwner then return end
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine(L[def.title] or def.title, Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
				GameTooltip:AddLine(L.OPT_NAV_POWER_TIP, 0.8, 0.8, 0.8)
				GameTooltip:Show()
			end)
			nav.power:SetScript("OnLeave", function()
				if type(GameTooltip) == "table" and GameTooltip.Hide then GameTooltip:Hide() end
			end)
		end
		navY = navY - rowH

		-- entrée de navigation seule (le module « Check avant le départ » ouvre
		-- sa première sous-page) : pas de page propre
		if def.target then
			-- rien à construire
		else
		-- page
		local page = CreateFrame("Frame", nil, frame)
		page:SetSize(PANE_WIDTH, FRAME_HEIGHT + top - 50)
		page:SetPoint("TOPLEFT", frame, "TOPLEFT", PANE_LEFT, top)
		page.id = def.id
		page.rows = {}
		frame.pages[def.id] = page

		-- titre de page dans la police maison, et une phrase qui dit à quoi
		-- sert la page
		page.title = Theme.CreateTitle(page, 19)
		page.title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
		page.title:SetText(L[def.title] or def.title)
		page.sub = page:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		page.sub:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -24)
		page.sub:SetWidth(PANE_WIDTH)
		page.sub:SetJustifyH("LEFT")
		page.sub:SetText(L[def.title .. "_SUB"] or "")
		page.sub:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
		local y = -48

		-- texte d'explication (paragraphes), pour les modules sans réglage
		if def.info then
			page.infoLines = {}
			for _, key in ipairs(def.info) do
				local text = L[key] or key
				local para = page:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
				para:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
				para:SetWidth(PANE_WIDTH - 8)
				para:SetJustifyH("LEFT")
				if para.SetWordWrap then para:SetWordWrap(true) end
				para:SetText(text)
				para:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3])
				-- hauteur estimée (le client la donne, pas le harnais) : ~5,6 px
				-- par caractère, 14 px par ligne
				local chars = select(2, tostring(text):gsub("[^\128-\191]", ""))
				local lines = math.max(1, math.ceil(chars * 5.6 / (PANE_WIDTH - 8)))
				local height = (para.GetStringHeight and tonumber(para:GetStringHeight()) or 0)
				if height <= 0 or not para.SetWordWrap then height = lines * 14 end
				para.estimatedHeight = height
				page.infoLines[#page.infoLines + 1] = para
				y = y - height - 8
			end
			y = y - 4
		end

		if def.modules then
			-- dans une sous-page du Check avant le départ, ce sont ses contrôles
			page.modulesHeader = Header(page, y, def.parent and "OPT_CHECKS" or "OPT_MODULES")
			y = y - 16
			for _, id in ipairs(def.modules) do
				local check = CheckDef(id)
				if check then
					local row = MakeModuleRow(page, check)
					row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
					frame.rows[#frame.rows + 1] = row
					page.rows[#page.rows + 1] = row
					placed[id] = true
					y = y - ROW_HEIGHT
				end
			end
			y = y - 8
		end

		if def.rows then
			if def.modules then
				page.settingsHeader = Header(page, y, "OPT_SETTINGS")
				y = y - 16
			end
			for _, rowDef in ipairs(def.rows) do
				if rowDef.header then
					y = y - 4
					page.sectionHeaders = page.sectionHeaders or {}
					page.sectionHeaders[#page.sectionHeaders + 1] = Header(page, y, rowDef.header)
					y = y - 16
				else
				local row = MakeRow(page, rowDef)
				row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
				frame.rows[#frame.rows + 1] = row
				page.rows[#page.rows + 1] = row
				y = y - ROW_HEIGHT
				-- phrase sous la ligne, qui suit sa valeur : def.describe(valeur)
				if rowDef.describe then
					row.note = page:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
					row.note:SetPoint("TOPLEFT", page, "TOPLEFT", 10, y + 4)
					row.note:SetWidth(PANE_WIDTH - 14)
					row.note:SetJustifyH("LEFT")
					if row.note.SetWordWrap then row.note:SetWordWrap(true) end
					row.note:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
					y = y - 26
				end
				end
			end
			y = y - 8
		end

		if def.list then
			local source = LIST_SOURCES[def.list] or {}
			page.listHeader = Header(page, y, source.header or def.list)
			y = y - 18
			local list = BuildList(page, def.list, y)
			frame.lists[def.list] = list
			y = list.bottom
			if source.extra then y = source.extra(page, y) or y end
		end

		if def.frameButtons then
			local half = math.floor((PANE_WIDTH - 8) / 2)
			frame.editButton = Theme.CreateButton(page, half, 22, L.OPT_EDIT_BUTTON, function()
				ns:RunOptionAction("editMode")
			end)
			frame.editButton:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - 6)
			frame.resetFramesButton = Theme.CreateButton(page, half, 22, L.OPT_RESET_FRAMES, function()
				ns:HandleCommand("resetpos")
			end)
			frame.resetFramesButton:SetPoint("TOPLEFT", page, "TOPLEFT", half + 8, y - 6)
			y = y - 34
		end

		if def.actions then
			for _, action in ipairs(def.actions) do
				local button = Theme.CreateButton(page, 200, 22, L["OPT_ACTION_" .. action:upper()] or action, function()
					ns:RunOptionAction(action)
				end)
				button:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - 6)
				page.actionButtons = page.actionButtons or {}
				page.actionButtons[action] = button
				y = y - 34
			end
		end

		page.contentBottom = y
		page:Hide()
		end
	end

	-- tout check sans page tombe dans « Général » : un module ajouté plus tard
	-- ne doit pas devenir impossible à couper
	frame.unplaced = {}
	local general = frame.pages.general
	local y = general.contentBottom
	for _, check in ipairs(ns.checks or {}) do
		if not placed[check.id] then
			frame.unplaced[#frame.unplaced + 1] = check.id
			local row = MakeModuleRow(general, check)
			row:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y)
			frame.rows[#frame.rows + 1] = row
			general.rows[#general.rows + 1] = row
			y = y - ROW_HEIGHT
		end
	end
	general.contentBottom = y

	-- Pied : trois boutons sur toute la largeur, en tiers égaux
	local MARGIN, GAP = 16, 8
	local inner = FRAME_WIDTH - (MARGIN * 2)
	local available = inner - (GAP * 2)
	local base = math.floor(available / 3)
	local extra = available - (base * 3)
	local widths = { base + (extra > 0 and 1 or 0), base + (extra > 1 and 1 or 0), base }

	-- bouton principal de l'addon (ns.OPTIONS_MAIN : le check, le carnet…)
	local main = ns.OPTIONS_MAIN or {}
	frame.runButton = Theme.CreateButton(frame, widths[1], 20, L[main.label or ""] or tostring(main.label or ""), function()
		if main.run then main.run(ns) end
	end)
	frame.runButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", MARGIN, 12)
	frame.resetButton = Theme.CreateButton(frame, widths[2], 20, L.OPT_RESET, function()
		ns:HandleCommand("reset")
		ns:RefreshOptions()
	end)
	frame.resetButton:SetPoint("LEFT", frame.runButton, "RIGHT", GAP, 0)
	frame.closeButton = Theme.CreateButton(frame, widths[3], 20, L.OPT_CLOSE, function()
		frame:Hide()
	end, "primary")
	frame.closeButton:SetPoint("LEFT", frame.resetButton, "RIGHT", GAP, 0)

	ns.OPT_LAYOUT.footer = { margin = MARGIN, gap = GAP, inner = inner, widths = widths }
	ns.OPT_LAYOUT.contentLimit = -(FRAME_HEIGHT - 48) - top   -- bas utile d'une page (sous le titre du cadre)

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
	local page
	for _, def in ipairs(PAGES) do if def.id == pageId then page = def end end
	if not page or not page.modules then return end
	local enable = self:PageModuleState(page.modules) ~= "on"
	for _, id in ipairs(page.modules) do
		if CheckDef(id) then self:SetModuleEnabled(id, enable) end
	end
	self:RefreshOptions()
end

-- Navigation repliable : les sous-pages d'un module ne s'affichent que quand
-- ce module (ou l'une de ses sous-pages) est ouvert. Sans ça, chaque module
-- ajouté allongeait la liste jusqu'à passer sous le pied du panneau.
function ns:LayoutNav()
	local frame = self.optionsFrame
	if not frame or not frame.navOrder then return end
	local y = frame.navTop
	for _, item in ipairs(frame.navOrder) do
		if item.group then
			y = y - 6
			item.group:ClearAllPoints()
			item.group:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, y - 2)
			y = y - 16
		else
			local nav = item.nav
			local visible = not nav.parentId or nav.parentId == frame.currentParent
			if visible then
				nav:ClearAllPoints()
				nav:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, y)
				nav:Show()
				y = y - (nav.rowH or ROW_HEIGHT)
			else
				nav:Hide()
			end
		end
	end
	frame.navBottom = y
end

function ns:SelectOptionsPage(id)
	local frame = self.optionsFrame
	if not frame then return end
	-- entrée de navigation sans page propre (module parent) : sa première sous-page
	for _, def in ipairs(PAGES) do
		if def.id == id and def.target then id = def.target; break end
	end
	if not frame.pages[id] then id = "general" end
	frame.currentPage = id
	local parent
	for _, def in ipairs(PAGES) do if def.id == id then parent = def.parent end end
	frame.currentParent = parent
	self:LayoutNav()
	self:DB().optionsPage = id
	for pageId, page in pairs(frame.pages) do
		if pageId == id then page:Show() else page:Hide() end
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
	if panel and type(panel.Hide) == "function" then pcall(panel.Hide, panel) end
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

	canvas.title = canvas:CreateFontString(nil, "OVERLAY", Theme.F_TITLE)
	canvas.title:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -16)
	canvas.title:SetText(ns.APP.brand or name)
	canvas.version = canvas:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	canvas.version:SetPoint("TOPLEFT", canvas.title, "BOTTOMLEFT", 0, -6)
	canvas.version:SetText(ns:F("SETTINGS_VERSION", tostring(ns.APP.version)))
	canvas.hint = canvas:CreateFontString(nil, "OVERLAY", Theme.F_NORMAL)
	canvas.hint:SetPoint("TOPLEFT", canvas.version, "BOTTOMLEFT", 0, -14)
	canvas.hint:SetJustifyH("LEFT")
	canvas.hint:SetText(L.SETTINGS_HINT)
	canvas.open = Theme.CreateButton(canvas, 180, 24, L.SETTINGS_OPEN, function() ns:OpenOptionsFromSettings() end)
	canvas.open:SetPoint("TOPLEFT", canvas.hint, "BOTTOMLEFT", 0, -14)

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
	if not Theme or not Theme.CreatePanel then return nil end

	-- 96 px : le bandeau du haut (36) + l'aide (2 lignes possibles) + le bouton.
	-- À 74 px (avant la v1.20.0 et son bandeau plus haut), l'aide passait
	-- sous le bouton et devenait illisible (vu en jeu).
	local banner = Theme.CreatePanel(UIParent, 320, 96, L.OPT_EDIT_MODE, { strata = "TOOLTIP" })
	if not banner then return nil end
	banner:SetClampedToScreen(true)
	banner:EnableMouse(true)

	banner.hint = banner:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	banner.hint:SetPoint("TOPLEFT", banner, "TOPLEFT", 12, banner.contentTop - 4)
	banner.hint:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -12, banner.contentTop - 4)
	banner.hint:SetJustifyH("LEFT")
	if banner.hint.SetWordWrap then banner.hint:SetWordWrap(true) end
	banner.hint:SetText(L.OPT_EDIT_HINT)
	banner.hint:SetTextColor(0.70, 0.70, 0.70)

	banner.stopButton = Theme.CreateButton(banner, 296, 20, L.OPT_EDIT_STOP, function()
		ns:StopEditMode()
	end, "primary")
	banner.stopButton:SetPoint("BOTTOM", banner, "BOTTOM", 0, 10)

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
