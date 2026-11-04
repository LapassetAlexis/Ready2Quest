-- UI.lua -- diagnostic de départ, habillage World of Warcraft
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local unpack = unpack or table.unpack   -- Lua 5.1 (client) / 5.4+

local WIDTH      = 440
local ROW_HEIGHT = 19
local MAX_ADVICE = 3
local DETAIL_TITLE = 46   -- longueur max du texte de détail (évite le débordement)

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

	local frame = Theme.CreatePanel(UIParent, WIDTH, height, L.WIN_TITLE_DIAG, { name = "Ready2QuestDiagFrame", titleSize = 14 })
	if not frame then return nil end
	ns:RestorePoint(frame, "diagPoint", { point = "CENTER", x = 0, y = 120 })

	-- « Parti de Comté-de-l'Or · boîte aux lettres » : à droite du bandeau,
	-- c'est le contexte de l'alerte (et l'endroit où repérer un village appris
	-- à tort). Le sous-titre du bandeau sert à ça.
	frame.subtitle:SetText("")
	frame.subtitle:SetWidth(WIDTH - 214)   -- titre à gauche, flèche + croix à droite
	frame.subtitle:SetJustifyH("RIGHT")
	frame.subtitle:SetWordWrap(false)
	frame.departed = frame.subtitle

	local top = frame.contentTop

	-- Bloc note : le chiffre en grand, dans la police maison, et le verdict en
	-- tampon à droite. C'est ce qu'on lit en premier.
	frame.scoreValue = Theme.CreateTitle(frame, 34)
	frame.scoreValue:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 6)

	frame.scoreSuffix = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.scoreSuffix:SetPoint("BOTTOMLEFT", frame.scoreValue, "BOTTOMRIGHT", 6, 4)
	frame.scoreSuffix:SetText(Theme.T_GREY .. "/ 100|r")

	frame.stamp = CreateFrame("Frame", nil, frame)
	frame.stamp:SetSize(150, 24)
	frame.stamp:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, top - 12)
	frame.stamp.border = Theme.Border(frame.stamp, Theme.GOLD, 1)
	frame.verdict = Theme.CreateTitle(frame.stamp, 12)
	frame.verdict:SetPoint("CENTER", frame.stamp, "CENTER", 0, 0)
	frame.verdict:SetText("")

	frame.scoreBar = Theme.CreateBar(frame, WIDTH - 28, 5)
	frame.scoreBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 46)

	Theme.CreateDivider(frame, WIDTH - 28, top - 58)

	-- Lignes de modules ------------------------------------------------------
	-- Placées à chaque affichage (LayoutWindow) : les modules sans objet sont
	-- masqués et les lignes en échec remontent en tête. Un losange porte le
	-- statut : plein = à voir (ambre) ou en échec (rouge), au trait = OK. La
	-- forme dit l'état autant que la couleur (lisible par un daltonien).
	frame.rows = {}

	for index = 1, rowCount do
		local row = CreateFrame("Frame", nil, frame)
		row:SetSize(WIDTH - 28, ROW_HEIGHT - 3)

		row.status = Theme.CreateDiamond(row, 9, true)
		row.status:SetPoint("LEFT", row, "LEFT", 2, 0)

		row.name = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.name:SetPoint("LEFT", row, "LEFT", 20, 0)
		row.name:SetWidth(100)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)

		row.detail = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.detail:SetPoint("LEFT", row, "LEFT", 128, 0)
		row.detail:SetWidth(WIDTH - 28 - 128 - 4)
		row.detail:SetJustifyH("LEFT")
		row.detail:SetWordWrap(false)

		frame.rows[index] = row
	end

	-- Conseils ---------------------------------------------------------------
	frame.adviceDivider = Theme.CreateDivider(frame, WIDTH - 28, 0)

	frame.adviceHeader = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.adviceHeader:SetText(L.PANEL_ADVICE)
	frame.adviceHeader:SetTextColor(Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3])

	frame.adviceLines, frame.adviceBullets = {}, {}
	for index = 1, MAX_ADVICE do
		local line = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		line:SetWidth(WIDTH - 40)
		line:SetJustifyH("LEFT")
		line:SetText("")
		line:SetTextColor(0.81, 0.78, 0.72)
		frame.adviceLines[index] = line
		local bullet = Theme.CreateDiamond(frame, 6, false)
		bullet:SetTexture(Theme.DIAMOND)
		bullet:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		frame.adviceBullets[index] = bullet
	end

	-- Animation : la note compte jusqu'à sa valeur, la barre suit (0,45 s)
	frame:SetScript("OnUpdate", function(f) ns:AnimateScore(f) end)
	self:LayoutWindow(frame, rowCount, false)

	-- Pied (v1.25.0) : un seul appel, « Partir à l'aventure », en bleu de nuit.
	-- Les réglages sont déjà au clic droit sur l'icône de la minicarte, et le
	-- check se relance d'une flèche discrète dans le bandeau.
	local BUTTON_HEIGHT = 22
	local PADDING       = 28
	local function LabelWidth(label)
		local probe = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		probe:SetText(label or "")
		local w = probe:GetStringWidth()
		probe:SetText("")
		if not w or w <= 0 then
			local len = utf8 and utf8.len(label or "") or #(label or "")
			w = len * 7
		end
		return w + PADDING
	end

	local adventureWidth = math.max(200, LabelWidth(L.DIAG_ADVENTURE))
	frame.adventureButton = Theme.CreateButton(frame, adventureWidth, BUTTON_HEIGHT, L.DIAG_ADVENTURE, function()
		frame:Hide()
	end, "adventure")
	frame.adventureButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)

	-- Flèche de rafraîchissement : à gauche de la croix du bandeau. Elle relance
	-- le check et fait un tour sur elle-même (si le client sait animer une rotation).
	frame.refreshButton = CreateFrame("Button", nil, frame)
	frame.refreshButton:SetSize(16, 16)
	frame.refreshButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -10)
	frame.refreshButton.icon = frame.refreshButton:CreateTexture(nil, "OVERLAY")
	frame.refreshButton.icon:SetTexture(Theme.REFRESH)
	frame.refreshButton.icon:SetAllPoints()
	-- au repos : désaturée et estompée (discrète) ; au survol : ses couleurs
	local function RefreshRest(icon)
		if icon.SetDesaturated then icon:SetDesaturated(true) end
		icon:SetAlpha(0.6)
	end
	RefreshRest(frame.refreshButton.icon)
	frame.refreshButton:SetScript("OnEnter", function(btn)
		if btn.icon.SetDesaturated then btn.icon:SetDesaturated(false) end
		btn.icon:SetAlpha(1)
		if type(GameTooltip) == "table" and GameTooltip.SetOwner then
			GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM")
			GameTooltip:AddLine(L.DIAG_REFRESH_TIP, 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	frame.refreshButton:SetScript("OnLeave", function(btn)
		RefreshRest(btn.icon)
		if type(GameTooltip) == "table" and GameTooltip.Hide then GameTooltip:Hide() end
	end)
	frame.refreshButton:SetScript("OnClick", function(btn)
		ns:SpinRefresh(btn)
		ns:RunChecklist("manual")
	end)
	-- le texte « Parti de … » se décale pour laisser la place à la flèche
	if frame.subtitle then
		frame.subtitle:ClearAllPoints()
		frame.subtitle:SetPoint("RIGHT", frame, "TOPRIGHT", -58, -18)
	end

	ns.DIAG_LAYOUT = {
		width = WIDTH,
		adventureWidth = adventureWidth,
		padding = PADDING,
		height = BUTTON_HEIGHT,
	}

	self.window = frame
	return frame
end

-- Un tour complet de la flèche (AnimationGroup Rotation), si le client le permet
function ns:SpinRefresh(button)
	if not button or not button.icon or not button.CreateAnimationGroup then return false end
	if not button.spin then
		local ok, group = pcall(button.CreateAnimationGroup, button)
		if not ok or not group then return false end
		local rot = group:CreateAnimation("Rotation")
		if rot.SetDegrees then rot:SetDegrees(-360) end
		if rot.SetDuration then rot:SetDuration(0.5) end
		if rot.SetTarget then pcall(rot.SetTarget, rot, button.icon) end
		button.spin = group
	end
	button.spin:Stop()
	button.spin:Play()
	return true
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
		line:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, adviceTop - 26 - ((index - 1) * 13))
		local bullet = frame.adviceBullets and frame.adviceBullets[index]
		if bullet then
			bullet:ClearAllPoints()
			bullet:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, adviceTop - 29 - ((index - 1) * 13))
		end
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
	local sr, sg, sb = unpack(Theme.ScoreColor(ratio))

	frame.scoreValue:SetText(tostring(score))
	frame.scoreBar:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	frame.scoreBar:SetValue(ratio)
	-- départ de l'animation : la note compte de 0 à sa valeur
	frame.animFrom, frame.animTo, frame.animStart = 0, score, ns.Now()

	if frame.verdict then
		frame.verdict:SetText(self:ScoreLabel())
		frame.verdict:SetTextColor(sr, sg, sb)
		frame.stamp.border:SetColor(sr, sg, sb, 1)
	end

	frame.departed:SetText(self:DepartedShort() or "")
	local ordered = self:DisplayOrder(results)
	self:LayoutWindow(frame, #ordered, false)

	for index, row in ipairs(frame.rows or {}) do
		local result = ordered[index]
		if result and result.disabled then
			-- Module coupé par le joueur : grisé, en bas, hors calcul de la note
			row.name:SetText(result.label)
			row.name:SetTextColor(0.42, 0.42, 0.42)
			row.status:SetTexture(Theme.DIAMOND_LINE)
			row.status:SetVertexColor(0.35, 0.37, 0.40, 1)
			row.status.state = "off"
			row.detail:SetText(Theme.T_GREY .. tostring(result.detail or L.MODULE_OFF) .. "|r")
		elseif result then
			row.name:SetText(result.label)
			row.name:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3])
			row.detail:SetText(Truncate(result.detail, DETAIL_TITLE))

			if result.ok or result.info then
				local c = result.info and Theme.BLUE or Theme.GREEN
				row.status:SetTexture(Theme.DIAMOND_LINE)
				row.status:SetVertexColor(c[1], c[2], c[3], 1)
				row.status.state = result.info and "info" or "ok"
				row.detail:SetTextColor(0.55, 0.57, 0.59)
			else
				-- rouge = échec qui pèse (poids >= 10 : vivres, sacs, durabilité,
				-- réactifs…). Un petit module (gris, quêtes) reste ambre : 2 objets
				-- gris en rouge sous un « PRÊT » vert se contredisaient (vu en jeu).
				local severe = (result.score or 0) < 55 and (result.weight or 0) >= 10
				local c = severe and Theme.RED or Theme.ORANGE
				row.status:SetTexture(Theme.DIAMOND)
				row.status:SetVertexColor(c[1], c[2], c[3], 1)
				row.status.state = severe and "bad" or "warn"
				if severe then
					row.detail:SetTextColor(0.94, 0.64, 0.59)
				else
					row.detail:SetTextColor(0.94, 0.78, 0.55)
				end
			end
		else
			row.name:SetText("")
			row.detail:SetText("")
		end
	end

	local advice = self.lastAdvice or {}
	if #advice == 0 then
		frame.adviceLines[1]:SetText(Theme.T_GREEN .. L.PANEL_NOADVICE .. "|r")
		for index = 2, MAX_ADVICE do frame.adviceLines[index]:SetText("") end
		for index, bullet in ipairs(frame.adviceBullets or {}) do
			if index == 1 then bullet:Show() else bullet:Hide() end
		end
	else
		for index = 1, MAX_ADVICE do
			local entry = advice[index]
			local bullet = frame.adviceBullets and frame.adviceBullets[index]
			if entry then
				frame.adviceLines[index]:SetText(entry.text)
				if bullet then bullet:Show() end
			else
				frame.adviceLines[index]:SetText("")
				if bullet then bullet:Hide() end
			end
		end
	end

	-- Une seule fenêtre à la fois : les réglages se ferment
	if self.optionsFrame and self.optionsFrame:IsShown() then
		self.optionsFrame:Hide()
	end

	frame:Show()
	Theme.FadeIn(frame, 0.15)
	return frame
end

-- Note qui compte jusqu'à sa valeur ; la barre suit. Termine toujours sur la
-- valeur exacte, quel que soit le nombre d'images.
local ANIM_DURATION = 0.45
function ns:AnimateScore(frame)
	if not frame.animStart then return end
	local t = (ns.Now() - frame.animStart) / ANIM_DURATION
	if t >= 1 then t = 1 end
	local eased = 1 - (1 - t) * (1 - t)
	local value = math.floor(frame.animFrom + (frame.animTo - frame.animFrom) * eased + 0.5)
	frame.scoreValue:SetText(tostring(value))
	frame.scoreBar:SetValue(value / 100)
	if t >= 1 then frame.animStart = nil end
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

-- Version courte, pour le bandeau : « Parti de Comté-de-l'Or · boîte aux lettres »
function ns:DepartedShort()
	local from = self.lastDeparture
	if not from then return nil end
	return self:F("PANEL_DEPARTED_SHORT", tostring(from.name or "?"),
		Theme.T_BLUE .. self:SourceLabel(from.source) .. "|r")
end

-- « Parti de : X (appris : source) », ou nil pour un check manuel
function ns:DepartedText()
	local from = self.lastDeparture
	if not from then return nil end
	return self:F("PANEL_DEPARTED", tostring(from.name or "?"), self:SourceLabel(from.source))
end

if ns.Mark then ns.Mark("UI") end
