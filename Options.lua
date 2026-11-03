-- Options.lua -- panneau de réglages, même habillage que le reste (Theme)
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local WIDTH      = 460
local ROW_HEIGHT = 22
local HEAD_HEIGHT = 26

-- Le panneau était une liste de quinze lignes de même poids : on ne voyait
-- ni où commençaient les réglages d'alerte, ni où finissaient les options
-- d'affichage. Les lignes sont désormais groupées par section, et chaque
-- section a son titre. Les libellés ont été raccourcis : la phrase entière
-- en colonne de gauche obligeait à lire chaque ligne pour en trouver une.
local SECTIONS = {
	{
		title = "OPT_SECTION_DISPLAY",
		rows = {
			{ key = "showWindow",        label = "OPT_SHOWWINDOW", kind = "bool" },
			{ key = "showMinimap",       label = "OPT_MINIMAP",    kind = "bool" },
			{ key = "showGearToast",     label = "OPT_TOAST",      kind = "bool" },
			{ key = "showPortraitStats", label = "OPT_PORTRAIT",   kind = "bool" },
			{ key = "minimapPos",        label = "OPT_MINIMAP_POS", kind = "action" },
		},
	},
	{
		title = "OPT_SECTION_ALERTS",
		hint = "OPT_SECTION_ALERTS_HINT",
		rows = {
			{ key = "continuousBagAlert", label = "OPT_BAGALERT",         kind = "bool" },
			{ key = "bagFreeThreshold",   label = "OPT_BAGTHRESHOLD",     kind = "number", min = 0,  max = 40,  step = 1 },
			{ key = "grayItemThreshold",  label = "OPT_GRAYTHRESHOLD",    kind = "number", min = 0,  max = 50,  step = 1 },
			{ key = "vivresThreshold",    label = "OPT_VIVRESTHRESHOLD",  kind = "number", min = 0,  max = 200, step = 5 },
			{ key = "potionsThreshold",   label = "OPT_POTIONSTHRESHOLD", kind = "number", min = 0,  max = 50,  step = 1 },
			{ key = "restMinPercent",     label = "OPT_RESTMIN",          kind = "number", min = 0,  max = 150, step = 5, suffix = "OPT_REST_UNIT" },
			{ key = "durabilityMinPct",   label = "OPT_DURAMIN",          kind = "number", min = 0,  max = 100, step = 5, suffix = "OPT_PCT_UNIT" },
		},
	},
	{
		title = "OPT_SECTION_MISC",
		rows = {
			{ key = "learnBuffs", label = "OPT_LEARNBUFFS", kind = "bool" },
		},
	},
}

-- Colonne de droite commune à toutes les lignes : les valeurs s'alignent
-- quelle que soit leur nature (OUI/non, nombre, flèche), et les boutons +/-
-- se placent dans une marge réservée.
-- Exposées aux tests : la géométrie de la colonne de droite doit rester
-- vérifiable, c'est elle qui se casse silencieusement quand on retouche.
ns.OPT_LAYOUT = {
	width = WIDTH,
	rowHeight = ROW_HEIGHT,
	valueRight = -96,
	valueWidth = 86,
	plusRight = -18,
	minusRight = -50,
	buttonWidth = 22,
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
			row.value:SetText(on and (Theme.T_GREEN .. L.OPT_ON .. "|r")
				or (Theme.T_GREY .. L.OPT_OFF .. "|r"))
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
		else
			local def = row.def
			local value = db[def.key]
			if def.kind == "bool" then
				local on = value ~= false
				row.value:SetText(on and (Theme.T_GREEN .. L.OPT_ON .. "|r")
					or (Theme.T_GREY .. L.OPT_OFF .. "|r"))
			else
				-- l'unité est portée par la valeur, pas par le libellé : la
				-- colonne de gauche reste courte et scannable
				row.value:SetText(Theme.T_GOLD .. tostring(value or 0) .. "|r"
					.. Theme.T_GREY .. suffix .. "|r")
			end
		end
	end
end

function ns:EnsureOptions()
	if self.optionsFrame then return self.optionsFrame end
	if not Theme or not Theme.CreatePanel then return nil end

	-- hauteur provisoire : la vraie est fixée en fin de construction, une
	-- fois la dernière ligne réellement posée (voir plus bas)
	local height = 600
	local frame = Theme.CreatePanel(UIParent, WIDTH, height, L.OPT_TITLE, { name = "SacEtDepartOptionsFrame" })
	if not frame then return nil end

	ns:RestorePoint(frame, "optionsPoint", { point = "CENTER", x = 0, y = 20 })
	if frame.subtitle then frame.subtitle:SetText(L.OPT_HINT) end

	frame.rows = {}

	-- Fabrique d'une ligne : le placement (colonne de droite, boutons) est
	-- défini ici une fois pour toutes, pas recopié à chaque endroit.
	local function MakeRow(parent, def)
		local row = CreateFrame("Button", nil, parent)
		row:SetSize(WIDTH - 28, ROW_HEIGHT - 6)
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
			row:SetScript("OnClick", function()
				ns:RunOptionAction(def.key)
			end)
		elseif def.kind == "bool" then
			row:SetScript("OnClick", function()
				local db = ns:DB()
				db[def.key] = not (db[def.key] ~= false)
				ns:RefreshOptions()
				if ns.ApplyDisplayOptions then ns:ApplyDisplayOptions() end
			end)
		else
			local function Step(delta)
				local db = ns:DB()
				db[def.key] = Clamp((db[def.key] or 0) + (delta * (def.step or 1)),
					def.min or 0, def.max or 999)
				ns:RefreshOptions()
			end

			row.minus = Theme.CreateButton(row, 22, 17, "-", function() Step(-1) end)
			row.minus:SetPoint("RIGHT", row, "RIGHT", MINUS_RIGHT, 0)

			row.plus = Theme.CreateButton(row, 22, 17, "+", function() Step(1) end)
			row.plus:SetPoint("RIGHT", row, "RIGHT", PLUS_RIGHT, 0)
		end

		return row
	end

	local y = frame.contentTop - 12

	for _, section in ipairs(SECTIONS) do
		-- titre de section : petit, en capitales dorées, précédé d'un filet
		frame.sections = frame.sections or {}
		local header = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		header:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
		header:SetText(L[section.title] or section.title)
		header:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
		frame.sections[#frame.sections + 1] = header

		if section.hint then
			local hint = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
			hint:SetPoint("LEFT", header, "RIGHT", 8, 0)
			hint:SetText(L[section.hint] or section.hint)
			hint:SetTextColor(0.48, 0.48, 0.48)
			frame.sections[#frame.sections + 1] = hint
		end

		y = y - 16

		for _, def in ipairs(section.rows) do
			local row = MakeRow(frame, def)
			row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
			frame.rows[#frame.rows + 1] = row
			y = y - ROW_HEIGHT
		end

		y = y - 6
		frame.sections[#frame.sections + 1] = Theme.CreateDivider(frame, WIDTH - 28, y + 10)
		y = y - 10
	end

	-- Section « Modules » : même gabarit que les autres sections, pour que la
	-- colonne d'interrupteurs ne se casse pas en deux styles d'alignement.
	local checks = ns.checks or {}
	local sectionY = y

	frame.modulesDivider = Theme.CreateDivider(frame, WIDTH - 28, sectionY + 12)

	frame.modulesHeader = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.modulesHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, sectionY)
	frame.modulesHeader:SetText(L.OPT_MODULES)
	frame.modulesHeader:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])

	frame.modulesHint = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.modulesHint:SetPoint("LEFT", frame.modulesHeader, "RIGHT", 8, 0)
	frame.modulesHint:SetText(L.OPT_MODULES_HINT)
	frame.modulesHint:SetTextColor(0.48, 0.48, 0.48)

	local moduleY = sectionY - 16

	for _, def in ipairs(checks) do
		local row = CreateFrame("Button", nil, frame)
		row:SetSize(WIDTH - 28, ROW_HEIGHT - 6)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, moduleY)
		row.isModule = true
		row.moduleId = def.id

		row.label = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.label:SetPoint("LEFT", row, "LEFT", 2, 0)
		local labelText = def.label
		if type(labelText) == "function" then labelText = labelText() end
		row.label:SetText(tostring(labelText or def.id))

		-- même colonne de valeurs que les autres sections : sinon les OUI
		-- des modules tombaient 70 px plus a droite que ceux du dessus
		row.value = row:CreateFontString(nil, "OVERLAY", Theme.F_NUMBER)
		row.value:SetPoint("RIGHT", row, "RIGHT", VALUE_RIGHT, 0)
		row.value:SetWidth(VALUE_WIDTH)
		row.value:SetJustifyH("RIGHT")

		row:SetScript("OnClick", function()
			ns:SetModuleEnabled(def.id, not ns:IsModuleEnabled(def.id))
			ns:RefreshOptions()
		end)

		frame.rows[#frame.rows + 1] = row
		moduleY = moduleY - ROW_HEIGHT
	end

	-- moduleY est maintenant la coordonnee du haut de la derniere ligne de
	-- module. La hauteur reelle du panneau n'est connue qu'ici : on la fixe
	-- d'apres le contenu effectivement place, au lieu de l'additionner a
	-- l'avance (c'est cette addition qui laissait un trou avant les boutons).
	-- moduleY est deja descendu sous la derniere ligne : c'est son bas.
	local gapBeforeButtons = 18
	local footerTopOffset = 62              -- bouton edit : 40 de bas + 22 de haut
	local realHeight = -(moduleY - gapBeforeButtons) + footerTopOffset
	ns.OPT_LAYOUT.gapBeforeButtons = gapBeforeButtons
	ns.OPT_LAYOUT.footerTopOffset = footerTopOffset
	frame:SetHeight(realHeight)
	ns.OPT_LAYOUT.contentBottom = moduleY
	ns.OPT_LAYOUT.realHeight = realHeight

	-- Pied : deux rangées, mais une seule grille. La rangée du bas est
	-- découpée en trois tiers égaux, si bien que « Réinitialiser » est
	-- centré entre « Lancer le check » et « Fermer » — il flottait avant,
	-- collé au bouton de gauche, avec un grand vide jusqu'à « Fermer ».
	local MARGIN = 16
	local GAP    = 8
	local inner  = WIDTH - (MARGIN * 2)
	-- le reste de la division est distribue aux deux premiers boutons : sinon
	-- floor laissait 1 px de vide a droite et les marges n'etaient pas egales
	local available = inner - (GAP * 2)
	local base  = math.floor(available / 3)
	local extra = available - (base * 3)
	local widths = { base + (extra > 0 and 1 or 0),
	                 base + (extra > 1 and 1 or 0),
	                 base }
	local third = base

	local half = math.floor((inner - GAP) / 2)
	frame.editButton = Theme.CreateButton(frame, half, 22, L.OPT_EDIT_BUTTON, function()
		ns:RunOptionAction("editMode")
	end)
	frame.editButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", MARGIN, 40)
	if frame.editButton.SetText then
		frame.editButton:SetText(L.OPT_EDIT_BUTTON)
	end

	-- le bouton des cadres est jumeau de celui du déplacement : mêmes
	-- dimensions, même rangée, séparés par le même espacement
	frame.resetFramesButton = Theme.CreateButton(frame, (inner - GAP) - half, 22, L.OPT_RESET_FRAMES, function()
		ns:HandleCommand("resetpos")
	end)
	frame.resetFramesButton:SetPoint("TOPLEFT", frame.editButton, "TOPLEFT", half + GAP, 0)

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
	end)
	frame.closeButton:SetPoint("LEFT", frame.resetButton, "RIGHT", GAP, 0)

	ns.OPT_LAYOUT.footer = {
		margin = MARGIN, gap = GAP, third = third, inner = inner, widths = widths,
		half = half,
	}

	self.optionsFrame = frame
	self:RefreshOptions()
	return frame
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

_G.SacEtDepartOptions = function() ns:ToggleOptions() end

ns.Mark("Options")
