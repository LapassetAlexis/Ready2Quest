-- UI.lua -- diagnostic de départ, habillage World of Warcraft
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local unpack = unpack or table.unpack   -- Lua 5.1 (client) / 5.4+

local WIDTH      = 440
local ROW_HEIGHT = 19
local MAX_ADVICE = 3
local DETAIL_TITLE = 38   -- longueur max du texte de détail (évite le débordement)

-- Coupe à `limit` octets sans jamais couper un caractère UTF-8 en deux (é, â…
-- font deux octets) : un octet de continuation (0x80-0xBF) ne peut pas
-- commencer la partie retirée. « ... » en ASCII : « … » n'est pas garanti
-- dans la police des cadres sur Era.
local function Truncate(text, limit)
	text = tostring(text or "")
	if #text <= limit then return text end
	local cut = limit - 3
	while cut > 0 do
		local nextByte = text:byte(cut + 1)
		if not nextByte or nextByte < 0x80 or nextByte > 0xBF then break end
		cut = cut - 1
	end
	return text:sub(1, cut) .. "..."
end
ns.Truncate = Truncate

local function VerdictText(self)
	local label, color = self:ScoreLabel()
	if color == "green" then return Theme.T_GREEN .. label .. "|r" end
	if color == "orange" then return Theme.T_ORANGE .. label .. "|r" end
	return Theme.T_RED .. label .. "|r"
end

-- ---------------------------------------------------------------------------
-- Construction du panneau
-- ---------------------------------------------------------------------------
function ns:EnsureWindow()
	if self.window then return self.window end
	if not Theme or not Theme.CreatePanel then return nil end

	local rowCount = #(self.checks or {})
	local height = self:WindowHeight(rowCount, false)

	local frame = Theme.CreatePanel(UIParent, WIDTH, height, L.ADDON_NAME, { name = "ReadyToQuestDiagFrame" })
	if not frame then return nil end
	ns:RestorePoint(frame, "diagPoint", { point = "CENTER", x = 0, y = 120 })

	-- Le sous-titre du bandeau porte le bilan : lisible sans lire le détail
	frame.subtitle:SetText("")

	local top = frame.contentTop

	-- Bloc préparation -------------------------------------------------------
	frame.scoreLabel = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.scoreLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top)
	frame.scoreLabel:SetText(L.PANEL_PREPARATION)
	frame.scoreLabel:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])

	frame.scoreValue = frame:CreateFontString(nil, "OVERLAY", Theme.F_TITLE)
	frame.scoreValue:SetPoint("LEFT", frame.scoreLabel, "RIGHT", 10, 0)

	frame.scoreSuffix = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.scoreSuffix:SetPoint("LEFT", frame.scoreValue, "RIGHT", 3, 0)
	frame.scoreSuffix:SetText(Theme.T_GREY .. "/ 100|r")

	-- Le verdict à côté de la note, en grand : c'est l'information qu'on lit
	-- en premier. Il était dans le sous-titre du bandeau, en petit.
	frame.verdict = frame:CreateFontString(nil, "OVERLAY", Theme.F_NORMAL)
	frame.verdict:SetPoint("LEFT", frame.scoreSuffix, "RIGHT", 12, 0)
	frame.verdict:SetText("")

	frame.scoreBar = Theme.CreateBar(frame, WIDTH - 28, 11)
	frame.scoreBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 30)

	Theme.CreateDivider(frame, WIDTH - 28, top - 52)

	-- Origine du départ, juste sous la note : c'est le contexte de l'alerte.
	-- « Parti de : Comté-de-l'Or (appris : boîte aux lettres) » permet de
	-- repérer d'un coup d'œil un village appris à tort.
	frame.departed = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.departed:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 60)
	frame.departed:SetWidth(WIDTH - 28)
	frame.departed:SetJustifyH("LEFT")
	frame.departed:SetText("")

	-- Lignes de modules ------------------------------------------------------
	-- Placées à chaque affichage (LayoutWindow) : les modules sans objet sont
	-- masqués et les lignes en échec remontent en tête.
	frame.rows = {}

	for index = 1, rowCount do
		local def = self.checks[index]
		local row = CreateFrame("Frame", nil, frame)
		row:SetSize(WIDTH - 28, ROW_HEIGHT - 3)

		row.icon = Theme.CreateIcon(row, 15, def and def.icon or nil, 1)
		row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

		row.name = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.name:SetPoint("LEFT", row, "LEFT", 23, 0)
		row.name:SetWidth(92)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)

		row.bar = Theme.CreateBar(row, 76, 7)
		row.bar:SetPoint("LEFT", row, "LEFT", 120, 0)

		row.detail = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.detail:SetPoint("LEFT", row, "LEFT", 206, 0)
		row.detail:SetWidth(WIDTH - 28 - 206 - 4)
		row.detail:SetJustifyH("LEFT")
		row.detail:SetWordWrap(false)

		frame.rows[index] = row
	end

	-- Conseils ---------------------------------------------------------------
	frame.adviceDivider = Theme.CreateDivider(frame, WIDTH - 28, 0)

	frame.adviceHeader = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.adviceHeader:SetText(L.PANEL_ADVICE)
	frame.adviceHeader:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])

	frame.adviceLines = {}
	for index = 1, MAX_ADVICE do
		local line = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		line:SetWidth(WIDTH - 34)
		line:SetJustifyH("LEFT")
		line:SetText("")
		frame.adviceLines[index] = line
	end
	self:LayoutWindow(frame, rowCount, false)

	-- Boutons ----------------------------------------------------------------
	-- Les largeurs etaient codees en dur (128/100/90) sans rapport avec le
	-- texte : "Lancer le check maintenant" debordait de son bouton et passait
	-- par-dessus le suivant. On mesure chaque libelle, avec un plancher pour
	-- garder des boutons d'apparence homogene.
	local BUTTON_HEIGHT = 20
	local PADDING       = 22
	local function LabelWidth(label)
		local probe = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		probe:SetText(label or "")
		local w = probe:GetStringWidth()
		probe:SetText("")
		if not w or w <= 0 then
			-- repli sans mesure : on estime, mieux vaut trop large que deborde
			local len = utf8 and utf8.len(label or "") or #(label or "")
			w = len * 7
		end
		return w + PADDING
	end

	local runWidth     = math.max(128, LabelWidth(L.OPT_RUNCHECK))
	local optionsWidth = math.max(100, LabelWidth(L.OPT_TITLE))
	local closeWidth   = math.max(90,  LabelWidth(L.OPT_CLOSE))

	frame.runButton = Theme.CreateButton(frame, runWidth, BUTTON_HEIGHT, L.OPT_RUNCHECK, function()
		ns:RunChecklist("manual")
	end)
	frame.runButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 10)

	frame.optionsButton = Theme.CreateButton(frame, optionsWidth, BUTTON_HEIGHT, L.OPT_TITLE, function()
		ns:ToggleOptions()
	end)
	frame.optionsButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14 + runWidth + 8, 10)

	frame.closeButton = Theme.CreateButton(frame, closeWidth, BUTTON_HEIGHT, L.OPT_CLOSE, function()
		frame:Hide()
	end)
	frame.closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 10)

	ns.DIAG_LAYOUT = {
		width = WIDTH,
		runWidth = runWidth,
		optionsWidth = optionsWidth,
		closeWidth = closeWidth,
		padding = PADDING,
		height = BUTTON_HEIGHT,
		left = 14,
		gap = 8,
	}

	self.window = frame
	return frame
end

-- ---------------------------------------------------------------------------
-- Mise en page variable : nombre de lignes visibles, ligne « Parti de »
-- ---------------------------------------------------------------------------
local DEPARTED_HEIGHT = 14

function ns:WindowHeight(visible, hasDeparted)
	return 40 + 52 + 12 + (hasDeparted and DEPARTED_HEIGHT or 0) + (visible * ROW_HEIGHT)
		+ 12 + 16 + (MAX_ADVICE * 13) + 34
end

function ns:LayoutWindow(frame, visible, hasDeparted)
	local top = frame.contentTop or -36
	local rowsTop = top - 66 - (hasDeparted and DEPARTED_HEIGHT or 0)
	for index, row in ipairs(frame.rows or {}) do
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, rowsTop - ((index - 1) * ROW_HEIGHT))
		if index <= visible then row:Show() else row:Hide() end
	end

	local adviceTop = rowsTop - (visible * ROW_HEIGHT) - 10
	frame.adviceDivider:ClearAllPoints()
	frame.adviceDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, adviceTop)
	frame.adviceHeader:ClearAllPoints()
	frame.adviceHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, adviceTop - 12)
	for index, line in ipairs(frame.adviceLines or {}) do
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, adviceTop - 26 - ((index - 1) * 13))
	end
	frame:SetHeight(self:WindowHeight(visible, hasDeparted))
	frame.visibleRows = visible
end

-- Ordre d'affichage : échecs d'abord (les plus lourds en tête), puis les
-- modules en ordre, puis ceux que le joueur a coupés. Les modules sans objet
-- (inactifs : pas de composant pour un guerrier, réparation jamais mesurée…)
-- sont masqués : une ligne grise « sans objet » ne dit rien.
function ns:DisplayOrder(results)
	local failed, ok, off = {}, {}, {}
	for index, result in ipairs(results or {}) do
		result._order = index
		if result.disabled then
			if not result.inactive then off[#off + 1] = result end
		elseif result.ok or result.info then
			ok[#ok + 1] = result
		else
			failed[#failed + 1] = result
		end
	end
	table.sort(failed, function(a, b)
		if a.weight ~= b.weight then return a.weight > b.weight end
		return a._order < b._order
	end)
	local list = {}
	for _, group in ipairs({ failed, ok, off }) do
		for _, result in ipairs(group) do list[#list + 1] = result end
	end
	return list
end

-- ---------------------------------------------------------------------------
-- Affichage
-- ---------------------------------------------------------------------------
function ns:ShowWindow(results)
	results = results or self.lastResults or {}

	local frame = self:EnsureWindow()
	if not frame then
		return self:PrintSummary(results)
	end

	local score = self.score or 0
	local ratio = score / 100

	frame.scoreValue:SetText(Theme.T_GOLD .. tostring(score) .. "|r")

	local sr, sg, sb = unpack(Theme.ScoreColor(ratio))
	frame.scoreBar:SetColor(sr, sg, sb)
	frame.scoreBar:SetValue(ratio)

	if frame.verdict then frame.verdict:SetText(VerdictText(self)) end
	if frame.subtitle then frame.subtitle:SetText("") end

	local departed = self:DepartedText()
	frame.departed:SetText(departed or "")
	local ordered = self:DisplayOrder(results)
	self:LayoutWindow(frame, #ordered, departed ~= nil)

	for index, row in ipairs(frame.rows or {}) do
		local result = ordered[index]
		if result and frame.rows[index] and row.icon and row.icon.tex and result.icon then
			row.icon.tex:SetTexture(result.icon)
		end
		if result and result.disabled then
			-- Module désactivé : grisé, hors calcul de la note
			row.name:SetText(result.label)
			row.name:SetTextColor(0.42, 0.42, 0.42)
			row.bar:SetColor(0.30, 0.30, 0.30)
			row.bar:SetValue(0)
			row.detail:SetText(Theme.T_GREY .. tostring(result.detail or L.MODULE_OFF) .. "|r")
		elseif result then
			row.name:SetText(result.label)
			row.name:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])

			local r, g, b = unpack(Theme.ScoreColor((result.score or 0) / 100))
			row.bar:SetColor(r, g, b)
			row.bar:SetValue((result.score or 0) / 100)

			-- « ! » devant un échec : l'alerte ne repose pas que sur la couleur
			-- (rouge, orange et vert se confondent pour un daltonien)
			if result.ok or result.info then
				row.detail:SetText(Truncate(result.detail, DETAIL_TITLE))
				row.detail:SetTextColor(0.78, 0.78, 0.78)
			else
				row.detail:SetText("! " .. Truncate(result.detail, DETAIL_TITLE - 2))
				row.detail:SetTextColor(Theme.ORANGE[1], Theme.ORANGE[2], Theme.ORANGE[3])
			end
			if result.info then
				row.bar:SetColor(0.45, 0.45, 0.45)
			end
		else
			row.name:SetText("")
			row.detail:SetText("")
			row.bar:SetValue(0)
		end
	end

	local advice = self.lastAdvice or {}
	if #advice == 0 then
		frame.adviceLines[1]:SetText(Theme.T_GREEN .. L.PANEL_NOADVICE .. "|r")
		for index = 2, MAX_ADVICE do frame.adviceLines[index]:SetText("") end
	else
		for index = 1, MAX_ADVICE do
			local entry = advice[index]
			if entry then
				frame.adviceLines[index]:SetText(Theme.T_GOLD .. "-|r " .. entry.text)
			else
				frame.adviceLines[index]:SetText("")
			end
		end
	end

	-- Une seule fenêtre à la fois : les réglages se ferment
	if self.optionsFrame and self.optionsFrame:IsShown() then
		self.optionsFrame:Hide()
	end

	frame:Show()
	return frame
end

-- ---------------------------------------------------------------------------
-- Résumé chat
-- ---------------------------------------------------------------------------
function ns:PrintSummary(results)
	results = results or self.lastResults or {}

	local score = self.score or 0
	self:Print(string.format("%s%d|r / 100 — %s", Theme.T_GOLD, score, VerdictText(self)))

	local warnings = 0
	for _, result in ipairs(results) do
		if not result.ok then
			warnings = warnings + 1
			self:Print(string.format("  %s %s %s", Theme.T_ORANGE .. "!" .. "|r", result.label, result.detail))
		end
	end
	if warnings == 0 then
		self:Print(Theme.T_GREEN .. L.PANEL_NOADVICE .. "|r")
	end

	for _, entry in ipairs(self.lastAdvice or {}) do
		self:Print("  " .. Theme.T_GOLD .. "•|r " .. entry.text)
	end
	local departed = self:DepartedText()
	if departed then self:Print("  " .. departed) end
end

-- « Parti de : X (appris : source) », ou nil pour un check manuel
function ns:DepartedText()
	local from = self.lastDeparture
	if not from then return nil end
	return self:F("PANEL_DEPARTED", tostring(from.name or "?"), self:SourceLabel(from.source))
end

if ns.Mark then ns.Mark("UI") end
