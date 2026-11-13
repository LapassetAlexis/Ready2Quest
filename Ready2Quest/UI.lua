-- UI.lua -- diagnostic de départ, habillage World of Warcraft
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local unpack = unpack or table.unpack   -- Lua 5.1 (client) / 5.4+

-- Mise en page (docs/UI.md, « Fenêtres des modules ») : en-tête compact,
-- bloc note (grand chiffre, tampon, barre), lignes en cartes, conseils, pied
-- avec « Partir à l'aventure ».
local WIDTH       = 480
local ROW_HEIGHT  = 24     -- carte de 22 + 2 d'écart
local ROW_CARD    = 22
local NAME_WIDTH  = 128    -- colonne des noms de module (à la création)
-- 1.31.0 : la colonne des noms prend la largeur du plus long libellé affiché,
-- bornée ; le détail prend le reste, coupé par le client (plus à 46 octets)
local NAME_MIN, NAME_MAX = 110, 170
local MAX_ADVICE  = 3
local ADVICE_STEP = 18     -- interligne des conseils
local SCORE_CARD  = 78     -- bloc note
local SECTION     = 20     -- titre de section
local GAP         = 14     -- entre deux blocs
local ADVICE_PAD  = 10     -- marge haute et basse du bloc conseils
local FOOTER      = 52     -- pied : bouton (28) centré
local BUTTON_HEIGHT = 28

-- Coupe à `limit` octets (1.31.0 : plus utilisé par la fenêtre, gardé pour le chat) sans jamais couper un caractère UTF-8 en deux (é, â…
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

local FR = {
	DIAG_CLICK_BAGS   = "Clic : ouvrir les sacs",
	DIAG_CLICK_QUESTS = "Clic : ouvrir le journal de quêtes",
	DIAG_CLICK_SPELLS = "Clic : la fenêtre Rangs de sorts",
}
local EN = {
	DIAG_CLICK_BAGS   = "Click: open your bags",
	DIAG_CLICK_QUESTS = "Click: open the quest log",
	DIAG_CLICK_SPELLS = "Click: the Spell ranks window",
}
if ns.RegisterStrings then ns.RegisterStrings(FR, EN) end
if ns.KEEP_STRINGS then ns.DIAG_UI_STRINGS = { fr = FR, en = EN } end   -- exposé aux tests (parité fr/en)

-- 1.35.0 : le clic sur une ligne fait la chose évidente (le geste que le
-- conseil demande), quand le client la permet. Une action = { hint = clé
-- du texte, run = fonction qui rend vrai si elle a pu agir, available =
-- fonction facultative }. Les modules en ajoutent (SpellRanks.lua : barranks).
local function OpenWith(...)
	local names = { ... }
	return function()
		for _, name in ipairs(names) do
			local fn = rawget(_G, name)
			if type(fn) == "function" and pcall(fn) then return true end
		end
		return false
	end
end
local function HasGlobal(...)
	local names = { ... }
	return function()
		for _, name in ipairs(names) do if type(rawget(_G, name)) == "function" then return true end end
		return false
	end
end
ns.CHECK_ACTIONS = ns.CHECK_ACTIONS or {}
ns.CHECK_ACTIONS.bags = { hint = "DIAG_CLICK_BAGS", run = OpenWith("OpenAllBags", "ToggleBackpack"),
	available = HasGlobal("OpenAllBags", "ToggleBackpack") }
ns.CHECK_ACTIONS.gray = ns.CHECK_ACTIONS.bags
ns.CHECK_ACTIONS.quests = { hint = "DIAG_CLICK_QUESTS", run = OpenWith("ToggleQuestLog"),
	available = HasGlobal("ToggleQuestLog") }

-- L'action d'une ligne (nil : la ligne n'a pas de clic)
function ns:DiagRowAction(result)
	if type(result) ~= "table" then return nil end
	if result.fold then return { run = function() ns:ToggleDiagFold(); return true end } end
	if result.disabled then return nil end
	local action = result.id and ns.CHECK_ACTIONS[result.id]
	if not action then return nil end
	if action.available and not action.available() then return nil end
	return action
end

-- 1.31.0 : infobulle d'une ligne coupée, en échec ou porteuse d'une liste
-- (buffs manquants) : libellé, texte entier, liste, conseil ; 1.35.0 : l'aide
-- du clic quand la ligne en a un. Le voile de survol ne s'allume que sur une
-- ligne qui répond (infobulle ou clic) : une ligne muette ne fait pas croire
-- qu'on peut cliquer.
local function RowTooltip(row)
	local r = row.result
	local tooltip = rawget(_G, "GameTooltip")
	if not r then return end
	local failed = not r.ok and not r.disabled and not r.info
	local action = ns:DiagRowAction(r)
	if not row.cut and not failed and not r.tip and not action then return end
	if row.hover then row.hover:Show() end
	-- la ligne de repli dit déjà « Afficher » / « Masquer » : le voile suffit
	if type(tooltip) ~= "table" or r.fold then return end
	tooltip:SetOwner(row, "ANCHOR_RIGHT")
	if type(tooltip.ClearLines) == "function" then tooltip:ClearLines() end
	Theme.TooltipTitle(tooltip, r.label)
	if r.detail and r.detail ~= "" then Theme.TooltipLine(tooltip, r.detail, Theme.TEXT, true) end
	if r.tip then
		if r.tip.title then Theme.TooltipHint(tooltip, r.tip.title) end
		for _, line in ipairs(r.tip) do Theme.TooltipLine(tooltip, "  " .. tostring(line), Theme.TEXT) end
	end
	if failed and r.advice and L[r.advice] then Theme.TooltipHint(tooltip, L[r.advice], true) end
	if action and L[action.hint] then Theme.TooltipHint(tooltip, L[action.hint]) end
	tooltip:Show()
end

local function RowLeave(row)
	if row.hover then row.hover:Hide() end
	local tooltip = rawget(_G, "GameTooltip")
	if type(tooltip) ~= "table" then return end
	if type(tooltip.GetOwner) ~= "function" or tooltip:GetOwner() == row then tooltip:Hide() end
end

-- verdict de la couleur de la note (barème unique, Theme.ScoreColor)
local function VerdictText(self)
	local label = self:ScoreLabel()
	return Theme.ScoreTextColor((self.score or 0) / 100) .. label .. "|r"
end

-- ---------------------------------------------------------------------------
-- Construction de la fenêtre
-- ---------------------------------------------------------------------------
function ns:EnsureWindow()
	if self.window then return self.window end
	if not Theme or not Theme.CreateDialog then return nil end

	local rowCount = #(self.checks or {})
	local height = self:WindowHeight(rowCount, false)

	local frame = Theme.CreateDialog(UIParent, WIDTH, height, { name = "Ready2QuestDiagFrame",
		title = L.WIN_TITLE_DIAG, footer = FOOTER })
	if not frame then return nil end
	ns:RestorePoint(frame, "diagPoint", { point = "CENTER", x = 0, y = 120 })

	-- « Parti de Comté-de-l'Or · boîte aux lettres » : le contexte de l'alerte
	-- (et l'endroit où repérer un village appris à tort), en sous-titre
	frame.departed = frame.subtitle
	local pad, inner = frame.pad, frame.innerWidth
	local top = frame.contentTop - GAP

	-- Bloc note : le chiffre en grand (F_DISPLAY), le verdict en tampon à
	-- droite, la barre ambre dessous. C'est ce qu'on lit en premier.
	frame.scoreCard = CreateFrame("Frame", nil, frame)
	frame.scoreCard:SetSize(inner, SCORE_CARD)
	frame.scoreCard:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 1, top)
	frame.scoreCard.bg = Theme.Solid(frame.scoreCard, "BACKGROUND", Theme.ROW, 1)
	frame.scoreCard.bg:SetAllPoints()
	frame.scoreCard.border = Theme.Border(frame.scoreCard, Theme.EDGE_SOFT, 1)

	frame.scoreValue = Theme.Text(frame.scoreCard, Theme.F_DISPLAY, Theme.PARCHMENT)
	frame.scoreValue:SetPoint("TOPLEFT", frame.scoreCard, "TOPLEFT", 16, -12)
	frame.scoreValue:SetJustifyH("LEFT")

	frame.scoreSuffix = Theme.Text(frame.scoreCard, Theme.F_BODY, Theme.MUTED)
	frame.scoreSuffix:SetPoint("BOTTOMLEFT", frame.scoreValue, "BOTTOMRIGHT", 6, 4)
	frame.scoreSuffix:SetText("/ 100")

	frame.stamp = CreateFrame("Frame", nil, frame.scoreCard)
	frame.stamp:SetSize(140, 26)
	frame.stamp:SetPoint("TOPRIGHT", frame.scoreCard, "TOPRIGHT", -16, -14)
	frame.stamp.fill = Theme.Solid(frame.stamp, "BACKGROUND", Theme.GOLD, 0.10)
	frame.stamp.fill:SetAllPoints()
	frame.stamp.border = Theme.Border(frame.stamp, Theme.GOLD, 1)
	frame.verdict = Theme.Text(frame.stamp, Theme.F_LABEL, Theme.GOLD)
	frame.verdict:SetPoint("CENTER", frame.stamp, "CENTER", 0, 0)
	frame.verdict:SetText("")

	frame.scoreBar = Theme.CreateBar(frame.scoreCard, inner - 32, 6)
	frame.scoreBar:SetPoint("BOTTOMLEFT", frame.scoreCard, "BOTTOMLEFT", 16, 14)

	-- Lignes de modules ------------------------------------------------------
	-- Placées à chaque affichage (LayoutWindow) : les modules sans objet sont
	-- masqués et les lignes en échec remontent en tête. Un losange porte le
	-- statut : plein = à voir (ambre) ou en échec (rouge), au trait = OK. La
	-- forme dit l'état autant que la couleur (lisible par un daltonien).
	frame.checksHeader = Theme.CreateSection(frame, L.PANEL_PREPARATION)
	frame.checksHeader:SetWidth(inner)
	frame.rows = {}
	-- 1.32.0 : une ligne de plus, celle du repli des points en ordre
	for index = 1, rowCount + 1 do
		-- 1.31.0 : un bouton, pour le survol et l'infobulle
		local row = Theme.CreateListRow(frame, inner, ROW_CARD, { status = 9, detail = true, kind = "Button" })
		row:SetScript("OnEnter", RowTooltip)
		row:SetScript("OnLeave", RowLeave)
		-- 1.32.0 : la ligne de repli plie ou déplie les points en ordre ;
		-- 1.35.0 : les autres font leur geste (sacs, journal, rangs de sorts)
		row:SetScript("OnClick", function(self)
			local action = ns:DiagRowAction(self.result)
			if action then action.run() end
		end)
		row:SetIndex(index)
		row.name = row.text
		row.name:SetWidth(NAME_WIDTH)
		row.detail:SetWidth(inner - row.textLeft - NAME_WIDTH - 12 - 12)
		frame.rows[index] = row
	end

	-- Conseils : un bloc à liseré ambre, puces en losange -------------------
	frame.adviceHeader = Theme.CreateSection(frame, L.PANEL_ADVICE)
	frame.adviceHeader:SetWidth(inner)
	frame.adviceBlock = CreateFrame("Frame", nil, frame)
	frame.adviceBlock:SetSize(inner, MAX_ADVICE * ADVICE_STEP + 2 * ADVICE_PAD)
	frame.adviceBlock.bg = Theme.Solid(frame.adviceBlock, "BACKGROUND", Theme.ROW, 1)
	frame.adviceBlock.bg:SetAllPoints()
	frame.adviceBlock.bar = Theme.Solid(frame.adviceBlock, "ARTWORK", Theme.GOLD, 1)
	frame.adviceBlock.bar:SetPoint("TOPLEFT", frame.adviceBlock, "TOPLEFT", 0, 0)
	frame.adviceBlock.bar:SetPoint("BOTTOMLEFT", frame.adviceBlock, "BOTTOMLEFT", 0, 0)
	frame.adviceBlock.bar:SetWidth(2)

	frame.adviceLines, frame.adviceBullets = {}, {}
	for index = 1, MAX_ADVICE do
		-- dans le bloc (au-dessus de son fond), placées depuis la fenêtre
		local line = Theme.Text(frame.adviceBlock, Theme.F_BODY, Theme.TEXT)
		line:SetWidth(inner - 34)
		line:SetJustifyH("LEFT")
		if line.SetWordWrap then line:SetWordWrap(false) end
		line:SetText("")
		frame.adviceLines[index] = line
		local bullet = Theme.CreateDiamond(frame.adviceBlock, 6, false)
		bullet:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		frame.adviceBullets[index] = bullet
	end

	-- Animation : la note compte jusqu'à sa valeur, la barre suit (0,45 s)
	frame:SetScript("OnUpdate", function(f) ns:AnimateScore(f) end)
	self:LayoutWindow(frame, rowCount, false)

	-- Pied (v1.25.0) : un seul appel, « Partir à l'aventure », en bleu de nuit,
	-- centré. Les réglages sont déjà au clic droit sur l'icône de la minicarte,
	-- et le check se relance de la flèche de l'en-tête.
	local adventureWidth = math.max(200, Theme.ButtonWidth(frame, L.DIAG_ADVENTURE))
	frame.adventureButton = Theme.CreateButton(frame.footer, adventureWidth, BUTTON_HEIGHT, L.DIAG_ADVENTURE, function()
		frame:Hide()
	end, "adventure")
	frame.adventureButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, (FOOTER - BUTTON_HEIGHT) / 2)

	-- Flèche de rafraîchissement : à gauche du [×]. Elle relance le check et
	-- fait un tour sur elle-même (si le client sait animer une rotation).
	frame.refreshButton = Theme.CreateIconButton(frame, 22, Theme.REFRESH, function(btn)
		ns:SpinRefresh(btn)
		ns:RunChecklist("manual")
	end, L.DIAG_REFRESH_TIP)
	frame.refreshButton:SetPoint("RIGHT", frame.close, "LEFT", -8, 0)
	if frame.refreshButton.SetFrameLevel and frame.close.GetFrameLevel then
		frame.refreshButton:SetFrameLevel(tonumber(frame.close:GetFrameLevel()) or 20)
	end

	-- Roue crantée : les réglages, à gauche de la flèche
	frame.settingsButton = Theme.CreateGearButton(frame, 22, function() ns:ToggleOptions() end, L.DIAG_SETTINGS_TIP)
	frame.settingsButton:SetPoint("RIGHT", frame.refreshButton, "LEFT", -6, 0)
	frame.settingsButton:Show()
	if frame.settingsButton.SetFrameLevel and frame.close.GetFrameLevel then
		frame.settingsButton:SetFrameLevel(tonumber(frame.close:GetFrameLevel()) or 20)
	end
	-- le titre et le « Parti de … » s'arrêtent avant la roue
	for _, fs in ipairs({ frame.subtitle, frame.title }) do
		if fs and fs.GetWidth and fs.SetWidth then fs:SetWidth(math.max(40, (tonumber(fs:GetWidth()) or 0) - (22 + 6))) end
	end

	ns.DIAG_LAYOUT = {
		width = WIDTH,
		adventureWidth = adventureWidth,
		padding = Theme.BUTTON_PAD,
		height = BUTTON_HEIGHT,
		footer = FOOTER,
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
-- Mise en page variable : nombre de lignes visibles. Le « Parti de » est
-- dans le sous-titre de l'en-tête : `hasDeparted` ne change plus rien
-- (paramètre gardé pour les appels existants).
-- ---------------------------------------------------------------------------
local HEADER = Theme and Theme.HEADER_COMPACT_HEIGHT or 64

function ns:WindowHeight(visible)
	return HEADER + 1 + GAP + SCORE_CARD + GAP + SECTION + 4 + (visible * ROW_HEIGHT)
		+ GAP + SECTION + 4 + (MAX_ADVICE * ADVICE_STEP + 2 * ADVICE_PAD) + GAP + FOOTER
end

function ns:LayoutWindow(frame, visible)
	local pad = (frame.pad or 20) + 1
	local sectionTop = -(HEADER + 1) - GAP - SCORE_CARD - GAP
	frame.checksHeader:ClearAllPoints()
	frame.checksHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, sectionTop)
	local rowsTop = sectionTop - SECTION - 4
	for index, row in ipairs(frame.rows or {}) do
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, rowsTop - ((index - 1) * ROW_HEIGHT))
		if index <= visible then row:Show() else row:Hide() end
	end

	local adviceTop = rowsTop - (visible * ROW_HEIGHT) - GAP + (ROW_HEIGHT - ROW_CARD)
	frame.adviceHeader:ClearAllPoints()
	frame.adviceHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, adviceTop)
	local blockTop = adviceTop - SECTION - 4
	frame.adviceBlock:ClearAllPoints()
	frame.adviceBlock:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, blockTop)
	for index, line in ipairs(frame.adviceLines or {}) do
		local y = blockTop - ADVICE_PAD - ((index - 1) * ADVICE_STEP)
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 26, y)
		local bullet = frame.adviceBullets and frame.adviceBullets[index]
		if bullet then
			bullet:ClearAllPoints()
			bullet:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 12, y - 4)
		end
	end
	frame:SetHeight(self:WindowHeight(visible))
	frame.visibleRows = visible
end

-- Ordre d'affichage : échecs d'abord (les plus lourds en tête), puis les
-- modules en ordre, puis ceux que le joueur a coupés. Les modules sans objet
-- (inactifs : pas de composant pour un guerrier, réparation jamais mesurée…)
-- sont masqués : une ligne grise « sans objet » ne dit rien.
-- R2Q 1.32.0 (hiérarchie) :
--   * une ligne info en échec (repos) reste avec les manques, en bleu ;
--   * durabilité et réparation toutes deux OK : une seule ligne (détails
--     réunis par « · »), la note n'est pas touchée ;
--   * `fold` : dès 4 lignes en ordre (OK et coupées), elles sont repliées en
--     une ligne « N points en ordre · Afficher » ; dépliées, une dernière
--     ligne « Masquer » les replie. Rend la liste et le nombre replié.
ns.DIAG_FOLD_MIN = 4
function ns:DisplayOrder(results, fold)
	local failed, ok, off, byId = {}, {}, {}, {}
	for index, result in ipairs(results or {}) do
		result._order = index
		result.shownDetail = nil
		if result.id then byId[result.id] = result end
		if result.disabled then
			if not result.inactive then off[#off + 1] = result end
		elseif result.ok then
			ok[#ok + 1] = result
		else
			failed[#failed + 1] = result
		end
	end
	local dura, repair = byId.durability, byId.repair
	if dura and repair and dura.ok and repair.ok and not dura.disabled and not repair.disabled then
		dura.shownDetail = tostring(dura.detail or "") .. " · " .. tostring(repair.detail or "")
		for i, r in ipairs(ok) do if r == repair then table.remove(ok, i); break end end
	end
	table.sort(failed, function(a, b)
		if a.weight ~= b.weight then return (a.weight or 0) > (b.weight or 0) end
		return a._order < b._order
	end)
	local list, folded = {}, 0
	for _, result in ipairs(failed) do list[#list + 1] = result end
	local quiet = #ok + #off
	if fold ~= nil and quiet >= ns.DIAG_FOLD_MIN then
		if fold then
			folded = quiet
			list[#list + 1] = { fold = true, count = quiet, label = self:FP("CHK_OK_FOLDED", quiet) }
			return list, folded
		end
	end
	for _, group in ipairs({ ok, off }) do
		for _, result in ipairs(group) do list[#list + 1] = result end
	end
	if fold == false and quiet >= ns.DIAG_FOLD_MIN then
		list[#list + 1] = { fold = true, unfold = true, count = quiet, label = L.CHK_OK_UNFOLD }
	end
	return list, folded
end

-- Plie ou déplie les points en ordre (choix mémorisé) et redessine
function ns:ToggleDiagFold()
	local db = self:DB()
	db.diagFoldOk = not (db.diagFoldOk ~= false)
	if self.window and self.window:IsShown() then self:ShowWindow(self.lastResults) end
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
		local label = self:ScoreLabel()
		frame.verdict:SetText(label)
		frame.verdict:SetTextColor(sr, sg, sb)
		frame.stamp.border:SetColor(sr, sg, sb, 1)
		frame.stamp.fill:SetVertexColor(sr, sg, sb, 0.10)
		frame.stamp:SetWidth(math.max(120, math.ceil(Theme.TextWidth(frame.stamp, label, Theme.F_LABEL) + 32)))
	end

	-- check manuel : pas de « Parti de », le sous-titre dit ce qu'est la fenêtre
	frame.departed:SetText(self:DepartedShort() or L.PANEL_SUBTITLE)
	local ordered = self:DisplayOrder(results, self:DB().diagFoldOk ~= false)
	self:LayoutWindow(frame, #ordered, false)

	-- 1.31.0 : colonne des noms à la mesure du plus long libellé affiché
	local nameWidth = NAME_MIN
	for i = 1, #ordered do
		local label = ordered[i] and not ordered[i].fold and ordered[i].label
		if label then nameWidth = math.max(nameWidth, Theme.TextWidth(frame, label, Theme.F_BODY) + 8) end
	end
	nameWidth = math.min(NAME_MAX, math.ceil(nameWidth))
	frame.nameWidth = nameWidth

	for index, row in ipairs(frame.rows or {}) do
		local result = ordered[index]
		local detailWidth = (frame.innerWidth or WIDTH) - row.textLeft - nameWidth - 24
		row.name:SetWidth(nameWidth)
		row.detail:SetWidth(detailWidth)
		row.result = result
		row.cut = result ~= nil and Theme.TextWidth(frame, result.detail, Theme.F_BODY) > detailWidth or false
		if result and result.fold then
			-- 1.32.0 : ligne de repli (« 9 points en ordre · Afficher » / « Masquer »)
			row.name:SetText(result.label)
			row.name:SetTextColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3])
			Theme.SetStatus(row.status, "ok")
			row.detail:SetText("")
			row.cut = false
			row.name:SetWidth((frame.innerWidth or WIDTH) - row.textLeft - 24)
		elseif result and result.disabled then
			-- Module coupé par le joueur : en retrait, en bas, hors calcul de la
			-- note (1.32.0 : MUTED_LIGHT, lisible ≥ 4,5:1 sur ROW et ROW_ALT)
			row.name:SetText(result.label)
			row.name:SetTextColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3])
			Theme.SetStatus(row.status, "off")
			row.detail:SetText(tostring(result.detail or L.MODULE_OFF))
			row.detail:SetTextColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3])
		elseif result then
			row.name:SetText(result.label)
			row.name:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3])
			row.detail:SetText(tostring(result.shownDetail or result.detail or ""))

			if result.ok then
				-- 1.32.0 : point en ordre en retrait (nom et détail MUTED_LIGHT)
				Theme.SetStatus(row.status, result.info and "info" or "ok")
				row.name:SetTextColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3])
				row.detail:SetTextColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3])
			elseif result.info then
				-- information en échec (repos) : avec les manques, en bleu
				local c = Theme.SetStatus(row.status, "info")
				row.detail:SetTextColor(c[1], c[2], c[3])
			else
				-- rouge = échec qui pèse (poids >= 10 : vivres, sacs, durabilité,
				-- réactifs…). Un petit module (gris, quêtes) reste ambre : 2 objets
				-- gris en rouge sous un « PRÊT » vert se contredisaient (vu en jeu).
				local severe = (result.score or 0) < 55 and (result.weight or 0) >= 10
				local c = Theme.SetStatus(row.status, severe and "bad" or "warn")
				row.detail:SetTextColor(c[1], c[2], c[3])
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
