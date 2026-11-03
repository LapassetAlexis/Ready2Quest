-- Options.lua -- panneau de réglages, même habillage que le reste (Theme)
--
-- v1.19.0 : navigation par pages, à la manière d'ElvUI. Une liste à gauche,
-- le contenu de la page à droite. Chaque page regroupe l'interrupteur d'un
-- module ET ses réglages : avant, l'interrupteur des vivres était dans
-- « Modules » et leur seuil dans « Alertes ». La hauteur du panneau ne dépend
-- plus du nombre de réglages (910 px en 1.18.0 avant refonte, hors écran).
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local FRAME_WIDTH  = 600
local FRAME_HEIGHT = 440
local NAV_WIDTH    = 150
local PANE_LEFT    = NAV_WIDTH + 16
local PANE_WIDTH   = FRAME_WIDTH - PANE_LEFT - 14
local ROW_HEIGHT   = 22
local LIST_LINES   = 9

-- ---------------------------------------------------------------------------
-- Pages. `modules` = interrupteurs de checks (ns.checks), `rows` = réglages,
-- `list` = liste défilante (zones sûres, buffs suivis), `buttons` = actions.
-- ---------------------------------------------------------------------------
local PAGES = {
	{
		id = "general", title = "OPT_PAGE_GENERAL",
		rows = {
			{ key = "enabled",         label = "OPT_ENABLED",    kind = "bool" },
			{ key = "showWindow",      label = "OPT_SHOWWINDOW", kind = "bool" },
			{ key = "popupScore",      label = "OPT_POPUPSCORE", kind = "number", min = 0, max = 100, step = 5 },
			{ key = "exitDelay",       label = "OPT_EXITDELAY",  kind = "number", min = 0, max = 15,  step = 1, suffix = "OPT_SEC_UNIT" },
			{ key = "quietAfterLogin", label = "OPT_QUIETLOGIN", kind = "number", min = 0, max = 60,  step = 5, suffix = "OPT_SEC_UNIT" },
			{ key = "alertCooldown",   label = "OPT_COOLDOWN",   kind = "number", min = 0, max = 120, step = 5, suffix = "OPT_SEC_UNIT" },
		},
	},
	{ id = "safe", title = "OPT_PAGE_SAFE", list = "safe" },
	-- groupe « Préparation » : un module par page
	{
		id = "bags", title = "OPT_PAGE_BAGS", modules = { "bags", "gray" }, group = "OPT_GROUP_PREP",
		rows = {
			{ key = "bagFreeThreshold",   label = "OPT_BAGTHRESHOLD",  kind = "number", min = 0, max = 40, step = 1 },
			{ key = "continuousBagAlert", label = "OPT_BAGALERT",      kind = "bool" },
			{ key = "grayItemThreshold",  label = "OPT_GRAYTHRESHOLD", kind = "number", min = 0, max = 50, step = 1 },
			{ key = "autoSellGray",       label = "OPT_AUTOSELL",      kind = "bool" },
		},
	},
	{
		id = "food", title = "OPT_PAGE_FOOD", modules = { "vivres", "potions" }, group = "OPT_GROUP_PREP",
		rows = {
			{ key = "vivresThreshold",  label = "OPT_VIVRESTHRESHOLD",  kind = "number", min = 0, max = 200, step = 5 },
			{ key = "potionsThreshold", label = "OPT_POTIONSTHRESHOLD", kind = "number", min = 0, max = 50,  step = 1 },
		},
	},
	{
		id = "buffs", title = "OPT_PAGE_BUFFS", modules = { "buffs" }, list = "buffs", group = "OPT_GROUP_PREP",
		rows = {
			{ key = "learnBuffs", label = "OPT_LEARNBUFFS", kind = "bool" },
		},
	},
	{
		id = "gear", title = "OPT_PAGE_GEAR", modules = { "durability", "repair" }, group = "OPT_GROUP_PREP",
		rows = {
			{ key = "durabilityMinPct", label = "OPT_DURAMIN",    kind = "number", min = 0, max = 100, step = 5, suffix = "OPT_PCT_UNIT" },
			{ key = "autoRepair",       label = "OPT_AUTOREPAIR", kind = "bool" },
		},
	},
	{
		id = "char", title = "OPT_PAGE_CHAR", modules = { "classreagents", "spells", "hearth", "rest" }, group = "OPT_GROUP_PREP",
		rows = {
			{ key = "restMinPercent", label = "OPT_RESTMIN", kind = "number", min = 0, max = 150, step = 5, suffix = "OPT_REST_UNIT" },
		},
	},
	{ id = "craft", title = "OPT_PAGE_CRAFT", modules = { "reagents", "quests" }, group = "OPT_GROUP_PREP" },
	{
		id = "display", title = "OPT_PAGE_DISPLAY", group = "OPT_GROUP_UI",
		rows = {
			{ key = "showMinimap",       label = "OPT_MINIMAP",     kind = "bool" },
			{ key = "minimapPos",        label = "OPT_MINIMAP_POS", kind = "action" },
			{ key = "showGearToast",     label = "OPT_TOAST",       kind = "bool" },
			{ key = "showPortraitStats", label = "OPT_PORTRAIT",    kind = "bool" },
		},
		frameButtons = true,
	},
}
ns.OPTION_PAGES = PAGES

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
			else
				if row.track then
					local span = (def.max or 1) - (def.min or 0)
					row.track:SetValue(span > 0 and (((value or 0) - (def.min or 0)) / span) or 0)
				end
				-- l'unité est portée par la valeur, pas par le libellé : la
				-- colonne de gauche reste courte et scannable
				row.value:SetText(Theme.T_GOLD .. tostring(value or 0) .. "|r"
					.. Theme.T_GREY .. suffix .. "|r")
			end
		end
	end

	for _, nav in ipairs(frame.navButtons or {}) do
		local selected = nav.pageId == frame.currentPage
		if selected then
			nav.label:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
			nav.marker:Show(); nav.tint:Show()
			nav.diamond:SetTexture(Theme.DIAMOND)
			nav.diamond:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		else
			nav.label:SetTextColor(0.68, 0.70, 0.71)
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
local LIST_SOURCES = {}

function LIST_SOURCES.safe()
	local db = ns:DB()
	local items = {}
	for key, entry in pairs(db.safe or {}) do
		local kind = entry.kind == "city" and L.SAFE_KIND_CITY or L.SAFE_KIND_VILLAGE
		items[#items + 1] = {
			key = key,
			text = tostring(entry.name or "?"),
			detail = kind .. ", " .. ns:SourceLabel(entry.source),
			action = L.OPT_REMOVE,
			onAction = function() ns:ForgetSafeZone(key) end,
		}
	end
	table.sort(items, function(a, b) return a.text < b.text end)
	return items
end

function LIST_SOURCES.buffs()
	local items = {}
	for _, entry in ipairs(ns:TrackedBuffs()) do
		local spellId = entry.spellId
		items[#items + 1] = {
			key = spellId,
			text = tostring(entry.name or spellId),
			value = OnOff(entry.enabled),
			onToggle = function()
				local stored = ns:DB().buffs[spellId]
				if stored then stored.enabled = (stored.enabled == false) end
			end,
			action = L.OPT_REMOVE,
			onAction = function() ns:DB().buffs[spellId] = nil end,
		}
	end
	return items
end

function ns:ForgetSafeZone(key)
	local db = self:DB()
	local entry = db.safe and db.safe[key]
	if not entry then return end
	db.safe[key] = nil
	if db.safeClues then db.safeClues[key] = nil end
	if entry.kind == "city" and entry.mapID and db.cityRest then db.cityRest[entry.mapID] = nil end
	self.inSafe, self.pendingExit = nil, nil
	self:Print(self:F("MSG_SAFE_REMOVED", tostring(entry.name or "?")))
end

function ns:RefreshOptionList(list)
	local items = LIST_SOURCES[list.source]()
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
	local list = { source = source, lines = {}, offset = 0,
		emptyText = source == "safe" and "OPT_SAFE_EMPTY" or "OPT_BUFFS_EMPTY" }
	local count = (source == "safe") and LIST_LINES or (LIST_LINES - 3)

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

	local frame = Theme.CreatePanel(UIParent, FRAME_WIDTH, FRAME_HEIGHT, L.OPT_TITLE, { name = "ReadyToQuestOptionsFrame" })
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
				db[def.key] = not (db[def.key] ~= false)
				ns:RefreshOptions()
				if ns.ApplyDisplayOptions then ns:ApplyDisplayOptions() end
			end)
		else
			local function Step(delta)
				local db = ns:DB()
				db[def.key] = Clamp((db[def.key] or 0) + (delta * (def.step or 1)), def.min or 0, def.max or 999)
				ns:RefreshOptions()
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

	local placed = {}
	local navY, lastGroup = top, nil
	frame.navGroups = {}
	for index, def in ipairs(PAGES) do
		-- titre de groupe dans la navigation (« PRÉPARATION », « INTERFACE »)
		if def.group and def.group ~= lastGroup then
			navY = navY - 6
			local groupLabel = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
			groupLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, navY - 2)
			groupLabel:SetText(L[def.group] or def.group)
			groupLabel:SetTextColor(Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3])
			frame.navGroups[#frame.navGroups + 1] = groupLabel
			navY = navY - 16
		end
		lastGroup = def.group

		-- bouton de navigation : losange, libellé, liseré ambre + teinte si actif
		local nav = CreateFrame("Button", nil, frame)
		nav:SetSize(NAV_WIDTH - 4, ROW_HEIGHT)
		nav:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, navY)
		nav.pageId = def.id
		nav.tint = Theme.Solid(nav, "BACKGROUND", Theme.GOLD, 0.12)
		nav.tint:SetAllPoints()
		nav.marker = Theme.Solid(nav, "ARTWORK", Theme.GOLD, 1)
		nav.marker:SetPoint("LEFT", nav, "LEFT", 0, 0)
		nav.marker:SetSize(2, ROW_HEIGHT)
		nav.diamond = Theme.CreateDiamond(nav, 7, true)
		nav.diamond:SetPoint("LEFT", nav, "LEFT", 12, 0)
		nav.label = nav:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		nav.label:SetPoint("LEFT", nav, "LEFT", 26, 0)
		nav.label:SetJustifyH("LEFT")
		nav.label:SetText(L[def.title] or def.title)
		nav:SetScript("OnClick", function() ns:SelectOptionsPage(def.id) end)
		frame.navButtons[index] = nav
		navY = navY - ROW_HEIGHT

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

		if def.modules then
			page.modulesHeader = Header(page, y, "OPT_MODULES")
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
				local row = MakeRow(page, rowDef)
				row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
				frame.rows[#frame.rows + 1] = row
				page.rows[#page.rows + 1] = row
				y = y - ROW_HEIGHT
			end
			y = y - 8
		end

		if def.list then
			page.listHeader = Header(page, y, def.list == "safe" and "OPT_SAFE_LIST" or "OPT_BUFFS_LIST")
			y = y - 18
			local list = BuildList(page, def.list, y)
			frame.lists[def.list] = list
			y = list.bottom
			if def.list == "safe" then
				page.clearButton = Theme.CreateButton(page, 150, 20, L.OPT_SAFE_CLEAR, function()
					ns:HandleCommand("safe reset")
					ns:RefreshOptions()
				end)
				page.clearButton:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - 6)
				page.hint = page:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
				page.hint:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - 34)
				page.hint:SetWidth(PANE_WIDTH)
				page.hint:SetJustifyH("LEFT")
				page.hint:SetText(L.OPT_SAFE_HINT)
				page.hint:SetTextColor(0.55, 0.55, 0.55)
			end
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

		page.contentBottom = y
		page:Hide()
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

	frame.runButton = Theme.CreateButton(frame, widths[1], 20, L.OPT_RUNCHECK, function()
		ns:RunChecklist("manual")
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

function ns:SelectOptionsPage(id)
	local frame = self.optionsFrame
	if not frame then return end
	if not frame.pages[id] then id = "general" end
	frame.currentPage = id
	self:DB().optionsPage = id
	for pageId, page in pairs(frame.pages) do
		if pageId == id then page:Show() else page:Hide() end
	end
	self:RefreshOptions()
end

function ns:ToggleOptions()
	local frame = self:EnsureOptions()
	if not frame then return end
	if frame:IsShown() then
		frame:Hide()
	else
		-- Une seule fenêtre à la fois : le diagnostic se ferme
		if self.window and self.window:IsShown() then
			self.window:Hide()
		end
		if self.StopEditMode then self:StopEditMode() end
		self:RefreshOptions()
		frame:Show()
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

	local banner = Theme.CreatePanel(UIParent, 320, 74, L.OPT_EDIT_MODE, { strata = "TOOLTIP" })
	if not banner then return nil end
	banner:SetClampedToScreen(true)
	banner:EnableMouse(true)

	banner.hint = banner:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	banner.hint:SetPoint("TOPLEFT", banner, "TOPLEFT", 12, banner.contentTop - 4)
	banner.hint:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -12, banner.contentTop - 4)
	banner.hint:SetJustifyH("LEFT")
	banner.hint:SetText(L.OPT_EDIT_HINT)
	banner.hint:SetTextColor(0.70, 0.70, 0.70)

	banner.stopButton = Theme.CreateButton(banner, 296, 20, L.OPT_EDIT_STOP, function()
		ns:StopEditMode()
	end)
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

-- Actions du panneau de réglages
function ns:RunOptionAction(key)
	if key == "editMode" and self.ToggleEditMode then
		-- on ferme les réglages pour laisser voir les deux cadres ; le bandeau
		-- d'édition prend le relais pour en sortir
		if not self.editMode and self.optionsFrame then self.optionsFrame:Hide() end
		self:ToggleEditMode()
		if self.RefreshOptions then self:RefreshOptions() end
	elseif key == "resetPos" then
		self:HandleCommand("resetpos")
		self:RefreshOptions()
	elseif key == "minimapPos" and self.CycleMinimapAngle then
		self:CycleMinimapAngle()
	end
end

_G.ReadyToQuestOptions = function() ns:ToggleOptions() end

ns.Mark("Options")
