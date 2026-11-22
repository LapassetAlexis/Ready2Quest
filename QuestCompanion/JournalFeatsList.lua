-- JournalFeatsList.lua -- listes de la page « Hauts faits » (QuestCompanion 3.7.0, chantier C1a)
--
-- Onglets Dresseur, Compagnon et voyage, Aventure (et les résultats d'une
-- recherche ou des « rattrapés ») : catégories de la famille à gauche,
-- filtres (Tous, En cours, Obtenus, Avec récompense), une ligne par série
-- (losange par palier), une ligne par haut fait sinon ; un clic déplie la
-- ligne (liste cochée ou paliers, Suivre, Partager, Carte souvenir si elle
-- existe), Maj + clic suit ou retire, clic droit partage un obtenu ;
-- molette ligne par ligne, « i à j sur n ». Maquette : carnet-j2, carnet-j3.
-- Cases, losanges et étoiles : des textures, jamais des caractères.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme
local FP = ns.FeatsPage
if not FP then return end
local K = ns.JOURNAL_FEATS_LAYOUT

local FR = {
	FEAT_LIST_COUNT     = "%s sur %s · %s points sur %s",
	FEAT_LIST_SECRETS   = "%s sur %s · %s secrets sur %s",
	FEAT_POSITION       = "%d à %d sur %d",
	FEAT_TAG_SERIES     = "Série · palier %d sur %d",
	FEAT_TAG_SERIES_DONE = "Série · complète",
	FEAT_TAG_LIST       = "Liste",
	FEAT_TAG_ACCOUNT    = "Compte",
	FEAT_TAG_CHAR       = "Personnage",
	FEAT_TAG_SECRET     = "Secret",
	FEAT_TAG_SECRET_FOUND = "Secret découvert",
	FEAT_TAG_FOS        = "Tour de force · 0 point",
	FEAT_NEXT           = "Prochain : %s, %s",
	FEAT_HINT_LINE      = "Indice : « %s »",
	FEAT_NO_HINT        = "Pas encore d'indice : ton compagnon en lâche un de temps en temps, au repos.",
	FEAT_FOS_NOTE       = "Les secrets non découverts et les tours de force ne comptent pas dans « %s » : le total reste atteignable.",
	FEAT_EMPTY_all      = "Aucun haut fait dans cette catégorie.",
	FEAT_EMPTY_open     = "Rien en cours ici : aucun haut fait de cette catégorie n'est commencé.",
	FEAT_EMPTY_got      = "Rien d'obtenu dans cette catégorie pour l'instant.",
	FEAT_EMPTY_reward   = "Aucun haut fait de cette catégorie ne donne de récompense en plus des paillettes.",
	FEAT_STEP_TODO      = "à faire",
	FEAT_STEP_PTS       = "%d points",
	FEAT_CHECK_MORE     = "et %d autres",
	FEAT_SHARE          = "Partager",
	FEAT_SOUVENIR       = "Carte souvenir",
	FEAT_FOLD           = "Clic : replier",
}
local EN = {
	FEAT_LIST_COUNT     = "%s of %s · %s of %s points",
	FEAT_LIST_SECRETS   = "%s of %s · %s of %s secrets",
	FEAT_POSITION       = "%d to %d of %d",
	FEAT_TAG_SERIES     = "Series · tier %d of %d",
	FEAT_TAG_SERIES_DONE = "Series · complete",
	FEAT_TAG_LIST       = "List",
	FEAT_TAG_ACCOUNT    = "Account",
	FEAT_TAG_CHAR       = "Character",
	FEAT_TAG_SECRET     = "Secret",
	FEAT_TAG_SECRET_FOUND = "Secret discovered",
	FEAT_TAG_FOS        = "Feat of strength · 0 points",
	FEAT_NEXT           = "Next: %s, %s",
	FEAT_HINT_LINE      = "Hint: \"%s\"",
	FEAT_NO_HINT        = "No hint yet: your companion drops one now and then, while resting.",
	FEAT_FOS_NOTE       = "Undiscovered secrets and feats of strength don't count in \"%s\": the total stays within reach.",
	FEAT_EMPTY_all      = "No achievement in this category.",
	FEAT_EMPTY_open     = "Nothing in progress here: no achievement of this category is started.",
	FEAT_EMPTY_got      = "Nothing earned in this category yet.",
	FEAT_EMPTY_reward   = "No achievement of this category gives a reward beyond glitter.",
	FEAT_STEP_TODO      = "to do",
	FEAT_STEP_PTS       = "%d points",
	FEAT_CHECK_MORE     = "and %d more",
	FEAT_SHARE          = "Share",
	FEAT_SOUVENIR       = "Keepsake card",
	FEAT_FOLD           = "Click: fold",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.JOURNAL_FEATS_LIST_STRINGS = { fr = FR, en = EN } end

local NoWrap, Paint, Num = FP.NoWrap, FP.Paint, FP.Num

-- Une ligne (maquette, largeur 514 ; la partie droite suit le bord droit) :
-- icône 36 à (10, 11), nom à (56, 6), description à (56, 22), récompense ou
-- date à 38, barre 120 finissant à 98 du bord droit (y 45), compte aligné
-- à 54 du bord droit (y 27), losange centré à 27 du bord droit (y 29).
ns.JOURNAL_FEATS_ROW = {
	h = 58, hSeries = 60, icon = 36, textX = 56, nameY = 6, descY = 22, lineY = 38, barW = 120, barR = 98, barY = 45,
	countR = 54, countY = 27, countW = 140, dia = 30, diaR = 27, diaY = 29, pip = 10, pipStep = 12, pipX = 62, pipY = 47,
	pipRoom = 222, sepGap = 2, gridTop = 10, gridStep = 19, gridGap = 28, check = 12, buttonsGap = 4, buttonH = 24,
	bottomPad = 10, rows = 7, tags = 3, catTagGap = 6,
}
local R = ns.JOURNAL_FEATS_ROW

-- ---------------------------------------------------------------------------
-- Briques d'une ligne
-- ---------------------------------------------------------------------------
-- case cochée ou vide : la case du thème, sinon un cadre et la coche du client
local function NewCheck(parent)
	local box = CreateFrame("Frame", nil, parent)
	box:SetSize(R.check, R.check)
	if not Theme.ApplyCheckbox(box, R.check) then
		box.edge = Theme.Border(box, Theme.EDGE, 1)
		box.tick = box:CreateTexture(nil, "OVERLAY")
		box.tick:SetTexture(Theme.CHECK_FILE)
		box.tick:SetSize(R.check + 4, R.check + 4)
		box.tick:SetPoint("CENTER", box, "CENTER", 0, 0)
		box.tick:SetVertexColor(Theme.GREEN[1], Theme.GREEN[2], Theme.GREEN[3], 1)
	end
	function box:SetDone(done)
		self.done = done and true or false
		if self.checkbox then Theme.SetCheckboxState(self, self.done)
		elseif self.done then self.tick:Show() else self.tick:Hide() end
	end
	return box
end

local function CheckItem(row, index)
	row.checks = row.checks or {}
	local item = row.checks[index]
	if item then return item end
	item = CreateFrame("Frame", nil, row)
	item:SetSize(100, 16)
	item.box = NewCheck(item)
	item.box:SetPoint("LEFT", item, "LEFT", 0, 0)
	item.label = NoWrap(Theme.Text(item, Theme.F_BODY, Theme.TEXT))
	item.label:SetJustifyH("LEFT")
	item.label:SetPoint("LEFT", item, "LEFT", R.check + 6, 0)
	item.detail = NoWrap(Theme.Text(item, Theme.F_SMALL, Theme.MUTED_LIGHT))
	item.detail:SetJustifyH("RIGHT")
	item.detail:SetPoint("RIGHT", item, "RIGHT", 0, 0)
	-- palier d'une série : seuil, points, date (colonnes alignées à droite)
	item.need = NoWrap(Theme.Text(item, Theme.F_SMALL, Theme.MUTED_LIGHT))
	item.need:SetJustifyH("RIGHT")
	item.pts = NoWrap(Theme.Text(item, Theme.F_SMALL, Theme.MUTED_LIGHT))
	item.pts:SetJustifyH("RIGHT")
	row.checks[index] = item
	return item
end

local function Pip(row, index)
	row.pips = row.pips or {}
	local pip = row.pips[index]
	if not pip then
		pip = Theme.CreateDiamond(row, R.pip, false)
		row.pips[index] = pip
	end
	return pip
end

local function BuildRow(parent, width)
	local row = Theme.CreateTile(parent, width, R.h)
	row.featsRow = true
	if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(R.icon, R.icon)
	row.name = NoWrap(Theme.Text(row, Theme.F_LABEL, Theme.LABEL))
	row.name:SetJustifyH("LEFT")
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", R.textX, -R.nameY)
	row.tags = {}
	for index = 1, R.tags do row.tags[index] = Theme.CreateTag(row, "") end
	row.desc = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT))
	row.desc:SetJustifyH("LEFT")
	row.desc:SetPoint("TOPLEFT", row, "TOPLEFT", R.textX, -R.descY)
	row.line = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.GOLD_SOFT))
	row.line:SetJustifyH("LEFT")
	row.line:SetPoint("TOPLEFT", row, "TOPLEFT", R.textX, -R.lineY)
	row.bar = Theme.CreateBar(row, R.barW, 4)
	row.bar:SetPoint("TOPRIGHT", row, "TOPRIGHT", -R.barR, -R.barY)
	row.count = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT))
	row.count:SetJustifyH("RIGHT")
	row.count:SetPoint("TOPRIGHT", row, "TOPRIGHT", -R.countR, -R.countY)
	row.count:SetWidth(R.countW)
	row.date = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT))
	row.date:SetJustifyH("RIGHT")
	row.date:SetPoint("TOPRIGHT", row, "TOPRIGHT", -R.countR, -R.lineY)
	row.date:SetWidth(180)
	row.diamond = Theme.CreateDiamond(row, R.dia, false)
	row.diamond:SetPoint("CENTER", row, "TOPRIGHT", -R.diaR, -R.diaY)
	row.pts = Theme.Text(row, Theme.F_NUMBER, Theme.MUTED_LIGHT)
	row.pts:SetPoint("CENTER", row.diamond, "CENTER", 0, 0)
	row.pts:SetJustifyH("CENTER")
	-- dépliée : filet, liste, boutons, « Clic : replier »
	row.sep = Theme.Solid(row, "ARTWORK", Theme.EDGE_SOFT, 1)
	row.sep:SetHeight(1)
	row.more = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED))
	row.more:SetJustifyH("LEFT")
	row.follow, row.unfollow = FP.FollowButtons(row, "auto",
		function(b) FP.Follow(ns, b:GetParent().def, true) end,
		function(b) FP.Follow(ns, b:GetParent().def, false) end)
	row.share = Theme.CreateButton(row, "auto", "sm", L.FEAT_SHARE, function(b)
		local r = b:GetParent()
		if r.def and ns.ShareOpen and ns.ShareItemFromFeat then ns:ShareOpen(b, ns:ShareItemFromFeat(r.def)) end
	end, "normal")
	row.souvenir = Theme.CreateButton(row, "auto", "sm", L.FEAT_SOUVENIR, function(b)
		local r = b:GetParent()
		if r.def and type(ns.SouvenirShow) == "function" then ns:SouvenirShow({ kind = "feat", id = r.def.id }) end
	end, "normal")
	row.fold = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED))
	row.fold:SetJustifyH("RIGHT")
	row.fold:SetText(L.FEAT_FOLD)
	row:SetScript("OnClick", function(r, mouse)
		if not r.item then return end
		if mouse == "RightButton" then
			if r.item.got and r.def and ns.ShareOpen and ns.ShareItemFromFeat then ns:ShareOpen(r, ns:ShareItemFromFeat(r.def)) end
			return
		end
		if FP.Shift() then
			if not FP.Secret(ns, r.def) and not r.item.got then FP.Follow(ns, r.def, nil) end
			return
		end
		ns:JournalFeatsToggle(r.key)
	end)
	row.onEnter = function(r) ns:JournalFeatsTip(r) end
	row.onLeave = function() local tip = rawget(_G, "GameTooltip"); if tip and tip.Hide then tip:Hide() end end
	return row
end
FP.BuildRow = BuildRow

-- ---------------------------------------------------------------------------
-- Ce qu'une ligne montre
-- ---------------------------------------------------------------------------
local function KeyOf(item) return item.defs and ("s:" .. tostring(item.key)) or item.def.id end
FP.KeyOf = KeyOf

local function IsList(def)
	local crit = def.crit or {}
	return crit[1] == "list" or (crit[1] == "meta" and type(crit[2]) == "table")
end

-- détail d'une ligne dépliée : liste cochée ou paliers (gardé le temps d'un
-- rafraîchissement)
local function Details(self, item)
	if item.details ~= nil then return item.details or nil end
	local out = false
	if item.defs then
		out = { kind = "steps", defs = item.defs }
	elseif not FP.Secret(self, item.def) then
		local list = self:FeatChecklist(item.def)
		if list and #list > 0 then out = { kind = "check", items = list } end
	end
	item.details = out
	return out or nil
end

-- rangées de la liste dépliée (deux colonnes pour une liste cochée, une par
-- palier), bornées à `maxRows`
local function DetailRows(details, maxRows)
	if not details then return 0, 0 end
	local count = details.kind == "check" and #details.items or #details.defs
	local rows = details.kind == "check" and math.ceil(count / 2) or count
	return math.min(rows, maxRows), rows
end

local function BaseHeight(item) return item.defs and R.hSeries or R.h end

-- Hauteur d'une ligne ; dépliée : bornée à `room` (la liste se coupe, « et k autres »)
function FP.RowHeight(self, item, open, room)
	local base = BaseHeight(item)
	if not open then return base end
	local top = base + R.sepGap + R.gridTop
	local tail = R.buttonsGap + R.buttonH + R.bottomPad
	local maxRows = math.max(0, math.floor(((room or 1000) - top - tail - 4) / R.gridStep))
	local rows = DetailRows(Details(self, item), maxRows)
	return top + (rows > 0 and rows * R.gridStep + 4 or 0) + tail, maxRows
end

local function SetTags(self, row, list)
	local x = nil
	for index, tag in ipairs(row.tags) do
		local spec = list[index]
		if spec then tag:SetTag(spec[1], spec[2]) else tag:SetTag("") end
	end
	return x
end

-- nom puis étiquettes à sa suite, sans déborder du losange
local function LayoutName(row, width)
	local tagsW = 0
	for _, tag in ipairs(row.tags) do if tag:IsShown() then tagsW = tagsW + (tag:GetWidth() or 0) + 6 end end
	local room = width - R.textX - R.diaR - 26
	-- (marge : la mesure d'une police peut sous-estimer d'un ou deux caractères)
	local nameW = math.min(math.ceil(Theme.TextWidth(row, row.name:GetText(), Theme.F_LABEL) * 1.08) + 6, math.max(40, room - tagsW))
	row.name:SetWidth(nameW)
	local anchor, gap = row.name, 6
	for _, tag in ipairs(row.tags) do
		if tag:IsShown() then
			tag:ClearAllPoints()
			if anchor == row.name then
				tag:SetPoint("LEFT", row, "TOPLEFT", R.textX + nameW + gap, -R.nameY - 7)
			else
				tag:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
			end
			anchor = tag
		end
	end
end

local function Diamond(row, mode, pts)
	-- mode : "got" (or plein, chiffre d'encre), "open" (ardoise), "secret" (?), "fos" (au trait or)
	Theme.SetDiamond(row.diamond, mode == "fos")
	local c = (mode == "got") and Theme.GOLD or (mode == "fos" and Theme.GOLD_LIGHT or Theme.EDGE)
	row.diamond:SetVertexColor(c[1], c[2], c[3], 1)
	row.diamond:Show()
	row.pts:SetText(mode == "secret" and "?" or (mode == "fos" and "" or tostring(pts or 0)))
	Paint(row.pts, mode == "got" and Theme.INK or Theme.MUTED_LIGHT)
	row.diaMode = mode
end

local function Pips(row, item)
	local n = #item.defs
	local step, size = R.pipStep, R.pip
	if n * step > R.pipRoom then
		step = math.max(4, math.floor(R.pipRoom / n))
		size = math.max(4, math.min(R.pip, step - 2))
	end
	for index = 1, n do
		local pip = Pip(row, index)
		pip:SetSize(size, size)
		pip:ClearAllPoints()
		pip:SetPoint("CENTER", row, "TOPLEFT", R.pipX + (index - 1) * step, -R.pipY)
		local done = index <= item.done and ns:FeatGot(item.defs[index]) ~= nil
		local current = not item.got and index == item.index
		Theme.SetDiamond(pip, current)
		local c = done and Theme.GOLD or (current and Theme.GOLD_LIGHT or Theme.EDGE)
		pip:SetVertexColor(c[1], c[2], c[3], 1)
		pip:Show()
	end
	for index = n + 1, #(row.pips or {}) do row.pips[index]:Hide() end
	row.pipCount, row.pipStep, row.pipSize = n, step, size
end

local function HideExtra(row)
	row.sep:Hide(); row.more:Hide(); row.follow:Hide(); row.unfollow:Hide(); row.share:Hide(); row.souvenir:Hide(); row.fold:Hide()
	for _, item in ipairs(row.checks or {}) do item:Hide() end
end

local function FillDetails(self, row, item, width, maxRows)
	local base = BaseHeight(item)
	local gridW = width - R.textX - 12
	row.sep:ClearAllPoints()
	row.sep:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -(base + R.sepGap))
	row.sep:SetWidth(width - 22)
	row.sep:Show()
	local top = base + R.sepGap + R.gridTop
	local details = Details(self, item)
	local rows, allRows = DetailRows(details, maxRows)
	local used = 0
	row.more:Hide()
	if details and details.kind == "check" then
		local colW = math.floor((gridW - R.gridGap) / 2)
		local capacity = rows * 2
		local shownItems = #details.items
		if shownItems > capacity then shownItems = math.max(0, capacity - 1) end
		for index = 1, shownItems do
			local spec = details.items[index]
			local cell = CheckItem(row, index)
			local col, line = (index - 1) % 2, math.floor((index - 1) / 2)
			cell:SetSize(colW, 16)
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", row, "TOPLEFT", R.textX + col * (colW + R.gridGap), -(top + line * R.gridStep))
			cell.box:SetDone(spec.done)
			cell.detail:SetText(spec.detail or "")
			local detailW = spec.detail and math.ceil(Theme.TextWidth(cell, spec.detail, Theme.F_SMALL)) + 6 or 0
			cell.label:SetWidth(colW - R.check - 6 - detailW)
			cell.label:SetText(spec.label or "")
			cell.need:SetText(""); cell.pts:SetText("")
			cell:Show()
			used = index
		end
		if shownItems < #details.items then
			local index = shownItems
			local col, line = index % 2, math.floor(index / 2)
			row.more:ClearAllPoints()
			row.more:SetPoint("TOPLEFT", row, "TOPLEFT", R.textX + col * (colW + R.gridGap), -(top + line * R.gridStep + 2))
			row.more:SetWidth(colW)
			row.more:SetText(self:F("FEAT_CHECK_MORE", #details.items - shownItems))
			row.more:Show()
		end
	elseif details and details.kind == "steps" then
		local shownSteps = #details.defs
		if shownSteps > rows then shownSteps = math.max(0, rows - 1) end
		for index = 1, shownSteps do
			local def = details.defs[index]
			local cell = CheckItem(row, index)
			cell:SetSize(gridW, 16)
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", row, "TOPLEFT", R.textX, -(top + (index - 1) * R.gridStep))
			local got = self:FeatGot(def)
			cell.box:SetDone(got ~= nil)
			cell.label:SetWidth(gridW - R.check - 6 - 250)
			cell.label:SetText(self:FeatName(def))
			cell.need:ClearAllPoints()
			cell.need:SetPoint("RIGHT", cell, "RIGHT", -170, 0)
			cell.need:SetWidth(80)
			cell.need:SetText(Num(ns.FeatThreshold(def)))
			cell.pts:ClearAllPoints()
			cell.pts:SetPoint("RIGHT", cell, "RIGHT", -90, 0)
			cell.pts:SetWidth(76)
			cell.pts:SetText(self:F("FEAT_STEP_PTS", tonumber(def.pts) or 0))
			cell.detail:SetText(got and FP.DateShort(tonumber(got.at) or 0) or L.FEAT_STEP_TODO)
			cell:Show()
			used = index
		end
		if shownSteps < #details.defs then
			row.more:ClearAllPoints()
			row.more:SetPoint("TOPLEFT", row, "TOPLEFT", R.textX, -(top + shownSteps * R.gridStep + 2))
			row.more:SetWidth(gridW)
			row.more:SetText(self:F("FEAT_CHECK_MORE", #details.defs - shownSteps))
			row.more:Show()
		end
	end
	for index = used + 1, #(row.checks or {}) do row.checks[index]:Hide() end
	local by = top + (rows > 0 and rows * R.gridStep + 4 or 0) + R.buttonsGap
	-- boutons : Suivre / Suivi, Partager (obtenu), Carte souvenir (si elle existe)
	local x = R.textX
	local function Put(button)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", row, "TOPLEFT", x, -by)
		button:Show()
		x = x + (button:GetWidth() or 72) + 6
	end
	local secret, got = FP.Secret(self, row.def), item.got
	row.follow:Hide(); row.unfollow:Hide(); row.share:Hide(); row.souvenir:Hide()
	if not secret and not got then
		if FP.Followed(self, row.def.id) then Put(row.unfollow) else Put(row.follow) end
	end
	if got and ns.ShareOpen and ns.ShareItemFromFeat then Put(row.share) end
	if got and type(ns.SouvenirShow) == "function" then Put(row.souvenir) end
	row.fold:ClearAllPoints()
	row.fold:SetPoint("RIGHT", row, "TOPRIGHT", -12, -(by + R.buttonH / 2))
	row.fold:SetWidth(120)
	row.fold:Show()
	return allRows
end

-- Remplit une ligne ; opts : open (dépliée, maxRows), catTag (recherche)
function FP.FillRow(self, row, item, width, opts)
	opts = opts or {}
	local series = item.defs ~= nil
	local def = item.def
	local secret = FP.Secret(self, def)
	local fos = def.cat == ns.FEAT_FOS
	row.item, row.key, row.entry, row.def = item, KeyOf(item), item, def
	row:SetWidth(width)
	local base = BaseHeight(item)
	row.icon:ClearAllPoints()
	row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -math.floor((base - R.icon) / 2))
	row.icon:SetTexture(self:FeatIcon(def))
	if row.icon.SetDesaturated then row.icon:SetDesaturated(not item.got) end

	local tags = {}
	local name, desc, line, date = "", "", "", ""
	local showBar, showCount = false, false
	if series then
		name = FP.SeriesName(self, item.key, item.defs)
		if item.got then
			tags[#tags + 1] = { L.FEAT_TAG_SERIES_DONE, Theme.ARCANE_LIGHT }
			local last = item.defs[#item.defs]
			desc = self:FeatName(last)
			local g = self:FeatGot(last)
			date = FP.DateLong(self, g and tonumber(g.at) or item.at)
			Diamond(row, "got", last.pts)
		else
			tags[#tags + 1] = { self:F("FEAT_TAG_SERIES", item.index, #item.defs), Theme.ARCANE_LIGHT }
			desc = self:F("FEAT_NEXT", self:FeatName(def), FP.LowerFirst(self:FeatDescription(def)))
			showBar, showCount = item.max > 1 or item.cur > 0, true
			Diamond(row, "open", def.pts)
		end
		Pips(row, item)
	else
		for _, pip in ipairs(row.pips or {}) do pip:Hide() end
		name = self:FeatName(def)
		if secret then
			tags[#tags + 1] = { L.FEAT_TAG_SECRET, Theme.RANK.rare }
			local key = "FEATH_" .. tostring(def.id)
			if self:FeatHintKnown(def.id) and L[key] ~= key then desc = self:F("FEAT_HINT_LINE", L[key])
			else desc = L.FEAT_NO_HINT end
			Diamond(row, "secret")
		else
			if def.hidden then tags[#tags + 1] = { L.FEAT_TAG_SECRET_FOUND, Theme.RANK.rare } end
			if fos then tags[#tags + 1] = { L.FEAT_TAG_FOS, Theme.GOLD_LIGHT } end
			if IsList(def) then tags[#tags + 1] = { L.FEAT_TAG_LIST, Theme.MUTED_LIGHT } end
			desc = self:FeatDescription(def)
			if fos then line = self:FeatRewardText(def) else line = FP.RewardLine(self, def) end
			if item.got then
				date = FP.DateLong(self, item.at)
			elseif item.state ~= "pending" and item.max > 1 then
				showCount = true
				showBar = line == ""
			end
			if fos then Diamond(row, "fos") else Diamond(row, item.got and "got" or "open", def.pts) end
		end
	end
	if opts.open and not secret then
		tags[#tags + 1] = def.scope == "account" and { L.FEAT_TAG_ACCOUNT, Theme.ARCANE_LIGHT } or { L.FEAT_TAG_CHAR, Theme.MUTED_LIGHT }
	end
	if opts.catTag then tags[#tags + 1] = { L["FEATC_" .. tostring(def.cat)] or tostring(def.cat), Theme.MUTED_LIGHT } end
	while #tags > R.tags do table.remove(tags, 1) end

	row.name:SetText(name)
	Paint(row.name, item.got and Theme.PARCHMENT or Theme.LABEL)
	SetTags(self, row, tags)
	LayoutName(row, width)

	-- compte et barre à droite ; la description s'arrête avant le compte
	local countText = showCount and self:FeatCountText(item.cur, item.max) or ""
	row.count:SetText(countText)
	if showBar then
		row.bar:SetValue(item.max > 0 and item.cur / item.max or 0)
		row.bar:Show()
	else
		row.bar:Hide()
	end
	local right = width - R.diaR - 22
	if countText ~= "" then right = width - R.countR - math.ceil(Theme.TextWidth(row, countText, Theme.F_SMALL)) - 10 end
	row.desc:SetWidth(math.max(60, right - R.textX))
	-- rien d'autre sous le nom (un secret et son indice) : deux lignes permises
	local alone = line == "" and date == "" and countText == "" and not series
	if row.desc.SetWordWrap then row.desc:SetWordWrap(alone) end
	row.desc:SetText(desc)
	row.date:SetText(date)
	local lineRight = width - R.countR - (date ~= "" and (math.ceil(Theme.TextWidth(row, date, Theme.F_SMALL)) + 10) or 0)
	if showBar then lineRight = math.min(lineRight, width - R.barR - R.barW - 8) end
	row.line:SetWidth(math.max(60, lineRight - R.textX))
	row.line:SetText(line)
	Paint(row.line, fos and Theme.GOLD_SOFT or Theme.GOLD_SOFT)

	row:SetSelected(opts.open and true or false)
	row:SetAccent(nil)
	local height = base
	if opts.open then
		height = FP.RowHeight(self, item, true, opts.room)
		FillDetails(self, row, item, width, opts.maxRows or 99)
	else
		HideExtra(row)
	end
	row:SetHeight(height)
	row:Show()
	return height
end

-- ---------------------------------------------------------------------------
-- La vue « liste »
-- ---------------------------------------------------------------------------
function FP.BuildList(self, frame, pane, view)
	local Place, ui = pane.Place, pane.ui
	view.Place = Place
	-- catégories de la famille (autant de tuiles que la plus grande famille)
	local most, counts = 0, {}
	for _, cat in ipairs(ns.FEAT_CATEGORIES or {}) do
		counts[cat.family or "?"] = (counts[cat.family or "?"] or 0) + 1
		most = math.max(most, counts[cat.family or "?"])
	end
	view.cats = {}
	for index = 1, most do
		local tile = Theme.CreateTile(view, K.catW, K.catH)
		Place(tile, 0, K.catY + (index - 1) * K.catStep)
		tile:SetFill(index % 2 == 0 and Theme.ROW_ALT or Theme.ROW)
		tile.label = Theme.Text(tile, Theme.F_BODY, Theme.LABEL)
		tile.label:SetJustifyH("LEFT")
		tile.label:SetPoint("LEFT", tile, "LEFT", 10, 0)
		tile.value = NoWrap(Theme.Text(tile, Theme.F_SMALL, Theme.MUTED_LIGHT))
		tile.value:SetJustifyH("RIGHT")
		tile.value:SetPoint("RIGHT", tile, "RIGHT", -8, 0)
		tile.value:SetWidth(52)
		tile:SetScript("OnClick", function(t) if t.cat then ns:JournalFeatsPick(t.cat) end end)
		view.cats[index] = tile
	end
	-- filtres et compte
	local defs = {}
	for _, id in ipairs(ns.JOURNAL_FEATS_FILTERS) do defs[#defs + 1] = { id = id, label = L["FEAT_FILTER_" .. id] } end
	view.filters = Theme.CreateChips(view, defs, function(id) ns:JournalFeatsFilter(id) end, { gap = K.tabGap })
	view.filterChips = view.filters.byId
	FP.Relayout(view.filters, K.tabPad, K.tabGap)
	Place(view.filters, K.listX, K.filtersY)
	view.count = NoWrap(ui.Text(view, Theme.F_SMALL, Theme.MUTED_LIGHT, 300))
	view.count:SetJustifyH("RIGHT")
	view.count:SetPoint("TOPRIGHT", pane.content, "TOPLEFT", ui.PAD + ui.INNER, ui.TOP - K.filtersY - 6)
	-- en-tête des résultats (recherche, rattrapés)
	view.head = NoWrap(ui.Text(view, Theme.F_LABEL, Theme.PARCHMENT, ui.INNER))
	Place(view.head, 0, K.filtersY + 5)
	-- lignes
	view.rows = {}
	for index = 1, R.rows do
		local row = BuildRow(view, ui.INNER - K.listX)
		row:Hide()
		view.rows[index] = row
	end
	view.empty = ui.Text(view, Theme.F_BODY, Theme.MUTED, ui.INNER - K.listX)
	if view.empty.SetWordWrap then view.empty:SetWordWrap(true) end
	view.note = ui.Text(view, Theme.F_SMALL, Theme.MUTED, ui.INNER - K.listX)
	if view.note.SetWordWrap then view.note:SetWordWrap(true) end
	view.position = NoWrap(ui.Text(view, Theme.F_SMALL, Theme.MUTED_LIGHT, 200))
	view.position:SetJustifyH("RIGHT")
	view.position:SetPoint("TOPRIGHT", pane.content, "TOPLEFT", ui.PAD + ui.INNER, ui.TOP - K.positionY)
	pane.list = view
end

-- les lignes d'une catégorie selon le filtre (une par série)
function FP.Items(self, cat, filter)
	local out = {}
	for _, item in ipairs(self:FeatSeriesList(cat, "all")) do
		local secret = not item.defs and FP.Secret(self, item.def)
		local keep = true
		if filter == "got" then
			keep = item.got ~= nil
		elseif filter == "open" then
			if item.defs then keep = not item.got and (item.done > 0 or item.cur > 0)
			else keep = not item.got and not secret and item.state == "open" and item.cur > 0 end
		elseif filter == "reward" then
			if item.defs then
				keep = false
				for _, d in ipairs(item.defs) do if FP.HasReward(d) then keep = true end end
			else keep = not secret and FP.HasReward(item.def) end
		end
		if keep then out[#out + 1] = item end
	end
	return out
end

-- résultats d'une recherche (nom et description affichés : un secret non
-- obtenu ne se trouve pas par son vrai nom) ou des rattrapés
function FP.Results(self, frame)
	local out = {}
	if frame.featsResults == "catchup" then
		local catch = self.FeatCatchUp and self:FeatCatchUp()
		for _, id in ipairs(catch and catch.ids or {}) do
			local def = self:FeatDef(id)
			if def then out[#out + 1] = self:FeatEntry(def) end
		end
	else
		local query = FP.Fold(frame.featsSearch or ""):gsub("^%s+", ""):gsub("%s+$", "")
		self:FeatCacheReset()
		for _, def in ipairs(self:FeatDefs()) do
			if not def.pending then
				local hay = FP.Fold(self:FeatName(def) .. "\n" .. self:FeatDescription(def))
				if hay:find(query, 1, true) then out[#out + 1] = self:FeatEntry(def) end
			end
		end
		self:FeatCacheReset()
	end
	table.sort(out, ns.FeatEntryBefore)
	return out
end

local function Filter(self)
	local filter = self:DB().featsFilter
	for _, id in ipairs(ns.JOURNAL_FEATS_FILTERS) do if id == filter then return id end end
	return "all"
end

-- Recalcule les lignes de l'onglet (ou des résultats), puis les pose
function FP.RefreshList(self, frame, pane)
	local view = pane.list
	local results = frame.featsResults or FP.SearchActive(frame)
	local stats = pane.stats or FP.CatStats(self)
	view.results = results and true or false
	view.note:SetText("")
	if results then
		for _, tile in ipairs(view.cats) do tile:Hide() end
		view.filters:Hide()
		view.count:SetText("")
		view.items = FP.Results(self, frame)
		local n = #view.items
		if frame.featsResults == "catchup" then
			view.head:SetText(n == 1 and L.FEAT_CATCH_HEAD_1 or self:F("FEAT_CATCH_HEAD", n))
		else
			local text = frame.featsSearch or ""
			view.head:SetText(n == 1 and self:F("FEAT_SEARCH_HEAD_1", text) or self:F("FEAT_SEARCH_HEAD", n, text))
			view.emptyText = self:F("FEAT_SEARCH_NONE", text)
		end
		view.head:Show()
		view.cat = nil
	else
		view.head:Hide()
		local family = frame.featsTab
		local cats = self:FeatFamilyCategories(family)
		frame.featsCatOf = frame.featsCatOf or {}
		local cat = frame.featsCatOf[family]
		local known = false
		for _, c in ipairs(cats) do if c == cat then known = true end end
		if not known then cat = cats[1]; frame.featsCatOf[family] = cat end
		view.cat = cat
		for index, tile in ipairs(view.cats) do
			local c = cats[index]
			if c then
				tile.cat = c
				local label = L["FEATC_" .. c] or c
				local s = stats[c] or { got = 0, total = 0, rawGot = 0, rawTotal = 0 }
				-- tours de force : hors des totaux, leur compte à eux
				if s.total == 0 then tile.value:SetText(Num(s.rawGot or 0) .. "/" .. Num(s.rawTotal or 0))
				else tile.value:SetText(Num(s.got) .. "/" .. Num(s.total)) end
				-- un nom long : plus petit, puis sur deux lignes
				local room = K.catW - 10 - 8 - 52 - 4
				local font = Theme.F_BODY
				if Theme.TextWidth(tile, label, Theme.F_BODY) > room then font = Theme.F_SMALL end
				if tile.label.SetFontObject then tile.label:SetFontObject(font) end
				tile.label:SetWidth(room)
				if tile.label.SetWordWrap then tile.label:SetWordWrap(Theme.TextWidth(tile, label, font) > room) end
				tile.label:SetText(label)
				Paint(tile.label, c == cat and Theme.PARCHMENT or Theme.LABEL)
				tile:SetSelected(c == cat)
				tile:Show()
			else
				tile.cat = nil
				tile:Hide()
			end
		end
		local filter = Filter(self)
		view.filters:Show()
		view.filters:Select(filter, true)
		local s = stats[cat or ""] or { got = 0, total = 0, pts = 0, ptsMax = 0, secrets = 0, secretsGot = 0 }
		if s.secrets > 0 then
			view.count:SetText(self:F("FEAT_LIST_SECRETS", Num(s.got), Num(s.total), Num(s.secretsGot), Num(s.secrets)))
		else
			view.count:SetText(self:F("FEAT_LIST_COUNT", Num(s.got), Num(s.total), Num(s.pts), Num(s.ptsMax)))
		end
		view.items = cat and FP.Items(self, cat, filter) or {}
		view.emptyText = L["FEAT_EMPTY_" .. filter]
		if cat == "fun" or cat == ns.FEAT_FOS then
			view.noteText = self:F("FEAT_FOS_NOTE", self:F("FEAT_PAIR", Num(stats.all.got), Num(stats.all.total)))
		else
			view.noteText = nil
		end
	end
	if results then view.noteText = nil end
	-- la ligne à montrer (suivi à l'écran) : en tête de la liste
	if frame.featsReveal then
		frame.featsReveal = nil
		for index, item in ipairs(view.items) do
			if KeyOf(item) == frame.featsOpen then frame.featsOffset = index - 1 end
		end
	end
	FP.LayoutList(self, frame, pane)
end

-- Pose les lignes depuis le décalage (molette : sans rien recalculer)
function FP.LayoutList(self, frame, pane, scrollOnly)
	local view = pane.list
	local items = view.items or {}
	local x = view.results and 0 or K.listX
	local width = pane.ui.INNER - x
	local top, bottom = K.listY, K.listBottom
	local room = bottom - top
	local function Height(item)
		return FP.RowHeight(self, item, KeyOf(item) == frame.featsOpen, room)
	end
	-- décalage maximal : la fin de la liste remplit la zone
	local maxOffset, used = #items, (view.noteText and 34 or 0)
	for index = #items, 1, -1 do
		local h = Height(items[index])
		if used + h > room and used > 0 then break end
		used = used + h + K.rowGap
		maxOffset = index - 1
	end
	local offset = math.max(0, math.min(math.floor(tonumber(frame.featsOffset) or 0), maxOffset))
	frame.featsOffset = offset
	local y, placed, last = top, 0, offset
	for index = offset + 1, #items do
		local item = items[index]
		local open = KeyOf(item) == frame.featsOpen
		local h, maxRows = FP.RowHeight(self, item, open, room)
		if y + h > bottom and placed > 0 then break end
		placed = placed + 1
		local row = view.rows[placed]
		if not row then break end
		view.Place(row, x, y)
		FP.FillRow(self, row, item, width, { open = open, room = room, maxRows = maxRows, catTag = view.results })
		y = y + h + K.rowGap
		last = index
	end
	for index = placed + 1, #view.rows do
		local row = view.rows[index]
		row.item, row.def, row.entry, row.key = nil, nil, nil, nil
		row:Hide()
	end
	-- la note des secrets et tours de force, sous la dernière ligne
	if view.noteText and last == #items and y + 28 <= bottom + 4 then
		view.note:SetText(view.noteText)
		view.Place(view.note, x, y + 6)
		view.note:Show()
	else
		view.note:SetText("")
		view.note:Hide()
	end
	if #items == 0 then
		view.empty:SetText(view.emptyText or "")
		view.Place(view.empty, x, top + 6)
		view.empty:Show()
	else
		view.empty:SetText("")
		view.empty:Hide()
	end
	view.position:SetText(#items > 0 and self:F("FEAT_POSITION", offset + 1, last, #items) or "")
	view.first, view.last, view.maxOffset = offset + 1, last, maxOffset
end

-- Déplier / replier une ligne (une seule à la fois)
function ns:JournalFeatsToggle(key)
	local frame = self.journalFrame
	if not frame then return end
	frame.featsOpen = (frame.featsOpen ~= key) and key or nil
	frame.featsNotice = nil
	self:RefreshJournal()
end

if ns.Mark then ns.Mark("JournalFeatsList") end
