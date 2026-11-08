-- JournalFeats.lua -- page « Hauts faits » du carnet (QuestCompanion 2.7.0, lot A)
--
-- Elle remplace les anciennes pages de tampons : les relevés de lieux
-- deviennent des hauts faits (Feats.lua). Mise en page :
--   * en haut : les points (compte et personnage), le nombre obtenu, les
--     filtres Tous / Obtenus / En cours ;
--   * à gauche : « Toutes » puis une ligne par catégorie (obtenus/total et
--     points gagnés) ;
--   * à droite : la liste, paginée (molette, chevrons) : icône, nom, marque
--     de portée (Compte / Perso), description, barre de progression, points,
--     récompense, date d'obtention. Une ligne « détection bientôt
--     disponible » est grisée.
-- Le style Azeroth pose le bouclier doré des hauts faits sous les points ;
-- le style Sobre garde le losange du thème.
-- Page externe du carnet : ns.JOURNAL_PANES.feats (JournalWindow.lua).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local CAT_W, GAP = 180, 16
local CAT_H, CAT_STEP = 30, 32
local ROW_H, ROW_STEP = 58, 62
local HEAD_H = 36                 -- la rangée des points et des filtres
local ICON = 36
local BAR_W = 130

local FR = {
	JRN_SEC_feats       = "Hauts faits",
	JRN_SUB_feats       = "Tes exploits, en jouant : créatures, zones, donjons, niveaux… Les hauts faits de compte valent pour tous tes personnages.",
	FEAT_FILTER_all     = "Tous",
	FEAT_FILTER_got     = "Obtenus",
	FEAT_FILTER_open    = "En cours",
	FEAT_CAT_ALL        = "Toutes",
	FEAT_TOTALS         = "Compte : %d points · Personnage : %d points",
	FEAT_COUNT          = "%d / %d obtenus",
	FEAT_CAT_VALUE      = "%d/%d · %d",
	FEAT_EMPTY          = "Aucun haut fait ici avec ce filtre.",
	FEAT_HINT           = "Survol : le détail. Molette ou chevrons : la suite.",
	FEAT_PROGRESS       = "%d / %d",
	JRN_TOTAL_FEATS     = "%d points de hauts faits",
}
local EN = {
	JRN_SEC_feats       = "Achievements",
	JRN_SUB_feats       = "Your feats, earned by playing: collection, zones, dungeons, levels… Account achievements count for all your characters.",
	FEAT_FILTER_all     = "All",
	FEAT_FILTER_got     = "Earned",
	FEAT_FILTER_open    = "In progress",
	FEAT_CAT_ALL        = "All",
	FEAT_TOTALS         = "Account: %d points · Character: %d points",
	FEAT_COUNT          = "%d / %d earned",
	FEAT_CAT_VALUE      = "%d/%d · %d",
	FEAT_EMPTY          = "No achievement here with this filter.",
	FEAT_HINT           = "Hover: details. Mouse wheel or chevrons: more.",
	FEAT_PROGRESS       = "%d / %d",
	JRN_TOTAL_FEATS     = "%d achievement points",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.JOURNAL_FEATS_STRINGS = { fr = FR, en = EN } end

local function NoWrap(text) if text.SetWordWrap then text:SetWordWrap(false) end return text end
local function Paint(region, c, a) region:SetTextColor(c[1], c[2], c[3], a or 1) end

local function Filter(self)
	local filter = self:DB().featsFilter
	for _, id in ipairs(ns.FEAT_FILTERS) do if id == filter then return id end end
	return "all"
end

-- ---------------------------------------------------------------------------
-- Données de la page
-- ---------------------------------------------------------------------------
-- Lignes d'une catégorie ("all" : toutes) selon un filtre : non obtenus par
-- progression décroissante (grisés à la fin), puis obtenus du plus récent au
-- plus ancien. Chaque ligne : { def, cur, max, state, got, at }
function ns:FeatRows(cat, filter)
	cat, filter = cat or "all", filter or "all"
	if self.FeatCacheReset then self:FeatCacheReset() end
	local rows = {}
	for _, def in ipairs(self:FeatDefs()) do
		if cat == "all" or def.cat == cat then
			local got = self:FeatGot(def)
			local wanted = filter == "all" or (filter == "got" and got) or (filter == "open" and not got)
			if wanted then
				local cur, max, state = self:FeatProgress(def)
				rows[#rows + 1] = { def = def, cur = cur, max = max, state = state, got = got,
					at = got and tonumber(got.at) or 0 }
			end
		end
	end
	local function Rank(row)
		if row.got then return 3 end
		if row.state == "pending" then return 2 end
		return 1
	end
	table.sort(rows, function(a, b)
		local ra, rb = Rank(a), Rank(b)
		if ra ~= rb then return ra < rb end
		if ra == 1 then
			local pa = a.max > 0 and a.cur / a.max or 0
			local pb = b.max > 0 and b.cur / b.max or 0
			if pa ~= pb then return pa > pb end
		elseif ra == 3 and a.at ~= b.at then
			return a.at > b.at
		end
		return (tonumber(a.def.n) or 0) < (tonumber(b.def.n) or 0)
	end)
	return rows
end

-- Obtenus, total, points gagnés, points en jeu d'une catégorie ("all" : tout)
function ns:FeatCategoryStats(cat)
	local got, total, pts, ptsMax = 0, 0, 0, 0
	for _, def in ipairs(self:FeatDefs()) do
		if cat == "all" or def.cat == cat then
			total, ptsMax = total + 1, ptsMax + (tonumber(def.pts) or 0)
			if self:FeatGot(def) then got, pts = got + 1, pts + (tonumber(def.pts) or 0) end
		end
	end
	return got, total, pts, ptsMax
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
local function BuildRow(pane, width)
	local row = Theme.CreateTile(pane, width, ROW_H)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON, ICON)
	row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -11)
	local textX = 10 + ICON + 10
	local textW = width - textX - 70
	row.name = NoWrap(Theme.Text(row, Theme.F_LABEL, Theme.LABEL))
	row.name:SetJustifyH("LEFT")
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -7)
	row.name:SetWidth(textW - 70)
	row.scope = Theme.CreateTag(row, "", Theme.MUTED_LIGHT)
	row.scope:SetPoint("TOPRIGHT", row, "TOPRIGHT", -64, -8)
	row.desc = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT))
	row.desc:SetJustifyH("LEFT")
	row.desc:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -24)
	row.desc:SetWidth(textW)
	row.reward = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.GOLD_SOFT))
	row.reward:SetJustifyH("LEFT")
	row.reward:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -40)
	row.reward:SetWidth(textW - BAR_W - 70)
	row.bar = Theme.CreateBar(row, BAR_W, 4)
	row.bar:SetPoint("TOPRIGHT", row, "TOPRIGHT", -64 - 46, -46)
	row.count = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT))
	row.count:SetJustifyH("RIGHT")
	row.count:SetPoint("TOPRIGHT", row, "TOPRIGHT", -64, -41)
	row.count:SetWidth(44)
	row.date = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED))
	row.date:SetJustifyH("RIGHT")
	row.date:SetPoint("TOPRIGHT", row, "TOPRIGHT", -64, -41)
	row.date:SetWidth(BAR_W + 50)
	-- les points : bouclier des hauts faits (Azeroth) ou losange (Sobre)
	row.shield = row:CreateTexture(nil, "ARTWORK")
	-- 2.9.0 : un peu plus grand (écu de 23×29 : deux chiffres y tiennent),
	-- au rapport de l'atlas (63×56)
	local shieldSize = ns.AZEROTH_SHIELD_SIZE and ns.AZEROTH_SHIELD_SIZE.row or { 52, 46 }
	row.shield:SetSize(shieldSize[1], shieldSize[2])
	row.shield:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	row.shield:Hide()
	row.diamond = Theme.CreateDiamond(row, 30, false)
	row.diamond:SetPoint("RIGHT", row, "RIGHT", -16, 0)
	row.pts = Theme.Text(row, Theme.F_NUMBER, Theme.PARCHMENT)
	row.pts:SetPoint("CENTER", row.diamond, "CENTER", 0, 0)
	row.pts:SetJustifyH("CENTER")
	if row.pts.SetJustifyV then row.pts:SetJustifyV("MIDDLE") end
	row.onEnter = function(r) ns:JournalFeatsTip(r) end
	row.onLeave = function() local tip = rawget(_G, "GameTooltip"); if tip and tip.Hide then tip:Hide() end end
	return row
end

local function Build(self, frame, content, ui)
	local At, Text = ui.At, ui.Text
	local TOP, INNER = ui.TOP, ui.INNER
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.feats = pane
	pane.RX = CAT_W + GAP
	pane.RW = INNER - pane.RX
	local listTop = TOP - HEAD_H
	pane.listTop = listTop
	pane.perPage = math.max(1, math.floor((listTop - (ui.PAGER_Y + 8)) / ROW_STEP))

	-- en haut : points et filtres
	pane.totals = NoWrap(Text(pane, Theme.F_LABEL, Theme.PARCHMENT, INNER - 260))
	At(pane.totals, content, 0, TOP - 2)
	pane.count = NoWrap(Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, INNER - 260))
	At(pane.count, content, 0, TOP - 19)
	pane.filters, pane.filterChips = ui.Chips(pane, ns.FEAT_FILTERS, "FEAT_FILTER_", function(id)
		ns:DB().featsFilter = id
		frame.featsOffset = 0
		ns:RefreshJournal()
	end)
	pane.filters:SetPoint("TOPRIGHT", content, "TOPLEFT", ui.PAD + INNER, TOP)

	-- à gauche : les catégories
	pane.cats = {}
	local keys = { "all" }
	for _, cat in ipairs(self:FeatCategories()) do keys[#keys + 1] = cat end
	for index, key in ipairs(keys) do
		local row = Theme.CreateTile(pane, CAT_W, CAT_H)
		At(row, content, 0, listTop - (index - 1) * CAT_STEP)
		row.cat = key
		row:SetFill(index % 2 == 0 and Theme.ROW_ALT or Theme.ROW)
		row.label = NoWrap(Text(row, Theme.F_BODY, Theme.LABEL, CAT_W - 70))
		row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
		row.label:SetText(key == "all" and L.FEAT_CAT_ALL or L["FEATC_" .. key])
		row.value = NoWrap(Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT, 64))
		row.value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		row.value:SetJustifyH("RIGHT")
		row:SetScript("OnClick", function(r) ns:JournalFeatsPick(r.cat) end)
		pane.cats[index] = row
	end

	-- à droite : la liste
	pane.rows = {}
	for index = 1, pane.perPage do
		local row = BuildRow(pane, pane.RW)
		At(row, content, pane.RX, listTop - (index - 1) * ROW_STEP)
		pane.rows[index] = row
	end
	pane.empty = Text(pane, Theme.F_BODY, Theme.MUTED, pane.RW)
	At(pane.empty, content, pane.RX, listTop - 8)
	ui.Pager(pane, content)
	pane:Hide()
end

-- ---------------------------------------------------------------------------
-- Rafraîchissement
-- ---------------------------------------------------------------------------
local function DateText(self, at)
	local fn = rawget(_G, "date")
	if not (at and at > 0 and type(fn) == "function") then return "" end
	local ok, text = pcall(fn, L.FEAT_DATE_FORMAT, at)
	return ok and type(text) == "string" and self:F("FEAT_EARNED_ON", text) or ""
end

local function FillRow(self, row, entry)
	local def, azeroth = entry.def, self.AzerothOn and self:AzerothOn()
	row.entry = entry
	row.def = def
	row.icon:SetTexture(self:FeatIcon(def))
	if row.icon.SetDesaturated then row.icon:SetDesaturated(not entry.got) end
	row.name:SetText(self:FeatName(def))
	Paint(row.name, entry.got and Theme.PARCHMENT or Theme.LABEL)
	row.scope:SetTag(L["FEAT_SCOPE_" .. tostring(def.scope)] or "", def.scope == "account" and Theme.BLUE or Theme.MUTED_LIGHT)
	local pending = entry.state == "pending"
	local desc = self:FeatDescription(def)
	if pending then desc = desc .. " — " .. L.FEAT_PENDING end
	row.desc:SetText(desc)
	local reward = self:FeatRewardText(def)
	row.reward:SetText(reward ~= "" and self:F("FEAT_REWARD", reward) or "")
	row.pending = pending
	if entry.got then
		row.bar:Hide(); row.count:SetText("")
		row.date:SetText(DateText(self, entry.at))
	elseif pending then
		row.bar:Hide(); row.count:SetText(""); row.date:SetText("")
	else
		row.date:SetText("")
		if entry.max > 1 then
			row.bar:Show()
			row.bar:SetValue(entry.max > 0 and entry.cur / entry.max or 0)
			row.count:SetText(self:F("FEAT_PROGRESS", entry.cur, entry.max))
		else
			row.bar:Hide(); row.count:SetText("")
		end
	end
	row.pts:SetText(tostring(def.pts or 0))
	if azeroth and ns.AzerothShield then
		ns.AzerothShield(row.shield, entry.got and "gold" or "grey")
		row.diamond:Hide()
		ns.AzerothShieldCenter(row.pts, row.shield)
	else
		row.shield:Hide()
		row.diamond:Show()
		local c = entry.got and Theme.GOLD or Theme.MUTED
		row.diamond:SetVertexColor(c[1], c[2], c[3], 1)
		row.pts:ClearAllPoints()
		row.pts:SetPoint("CENTER", row.diamond, "CENTER", 0, 0)
	end
	Paint(row.pts, entry.got and Theme.PARCHMENT or Theme.MUTED_LIGHT)
	row:SetAccent(entry.got and Theme.GOLD or nil)
	row:SetAlpha(pending and 0.45 or 1)
	row:Show()
end

local function Refresh(self, frame, ui)
	local pane = frame.feats
	if not pane then return end
	local cat = frame.featsCat or "all"
	local filter = Filter(self)
	local account, char = self:FeatPoints("account"), self:FeatPoints("char")
	pane.totals:SetText(self:F("FEAT_TOTALS", account, char))
	local got, total = self:FeatCategoryStats("all")
	pane.count:SetText(self:F("FEAT_COUNT", got, total))
	pane.filters:Select(filter, true)
	for _, row in ipairs(pane.cats) do
		local g, t, pts = self:FeatCategoryStats(row.cat)
		row.value:SetText(self:F("FEAT_CAT_VALUE", g, t, pts))
		row:SetSelected(row.cat == cat)
	end
	local rows = self:FeatRows(cat, filter)
	pane.list = rows
	local maxOffset = math.max(0, #rows - pane.perPage)
	local offset = math.max(0, math.min(tonumber(frame.featsOffset) or 0, maxOffset))
	frame.featsOffset = offset
	for index, row in ipairs(pane.rows) do
		local entry = rows[offset + index]
		if entry then FillRow(self, row, entry) else row.entry, row.def = nil, nil; row:Hide() end
	end
	pane.empty:SetText(#rows == 0 and L.FEAT_EMPTY or "")
	pane.pager:Update(offset, pane.perPage, #rows, maxOffset)
	pane.hint:SetText(#rows > pane.perPage and L.FEAT_HINT or "")
end

local function Scroll(self, frame, delta)
	frame.featsOffset = (tonumber(frame.featsOffset) or 0) - (tonumber(delta) or 0)
end

-- Infobulle d'une ligne : nom, description, récompense, portée, date
function ns:JournalFeatsTip(row)
	local def, entry = row and row.def, row and row.entry
	local tip = rawget(_G, "GameTooltip")
	if not (def and type(tip) == "table") then return end
	-- à côté de la ligne survolée (2.8.2 : plus au-dessus, au bord de la fenêtre)
	ns.JournalTipAnchor(tip, row, "row")
	if tip.ClearLines then tip:ClearLines() end
	Theme.TooltipTitle(tip, self:FeatName(def))
	Theme.TooltipLine(tip, self:FeatDescription(def), Theme.TEXT, true)
	local reward = self:FeatRewardText(def)
	if reward ~= "" then Theme.TooltipLine(tip, self:F("FEAT_REWARD", reward), Theme.GOLD, true) end
	if entry and entry.state == "pending" then Theme.TooltipLine(tip, L.FEAT_PENDING, Theme.MUTED, true) end
	Theme.TooltipHint(tip, L["FEAT_SCOPE_TIP_" .. tostring(def.scope)] or "", true)
	if entry and entry.got then Theme.TooltipHint(tip, DateText(self, entry.at), true) end
	tip:Show()
end

function ns:JournalFeatsPick(cat)
	local frame = self.journalFrame
	if not frame then return end
	frame.featsCat, frame.featsOffset = cat or "all", 0
	self:RefreshJournal()
end

-- /qc hf : le carnet sur la page Hauts faits
function ns:OpenJournalFeats(cat)
	if not self.ToggleJournal then return nil end
	local frame = self:ToggleJournal(true)
	if not frame then return nil end
	if cat then frame.featsCat, frame.featsOffset = cat, 0 end
	self:SelectJournalKind("feats")
	return frame
end

ns.JOURNAL_PANES = ns.JOURNAL_PANES or {}
ns.JOURNAL_PANES.feats = {
	field = "feats", title = "JRN_SEC_feats", subtitle = "JRN_SUB_feats",
	build = Build, refresh = Refresh, scroll = Scroll,
}
ns.JOURNAL_FEATS_LAYOUT = { catW = CAT_W, rowH = ROW_H, rowStep = ROW_STEP, headH = HEAD_H }

if ns.Mark then ns.Mark("JournalFeats") end
