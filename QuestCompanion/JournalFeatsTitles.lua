-- JournalFeatsTitles.lua -- onglet « Titres » de la page Hauts faits
-- (QuestCompanion 3.7.0, chantier C1b ; maquette validée : carnet-j4)
--
--   * à gauche : le titre affiché (mon nom avec mon titre, la forme
--     masculine ou féminine : automatique ou choisie), puis les titres
--     gagnés à choix unique : Automatique, Aucun titre, chaque titre gagné
--     (étiquette « Tour de force » sur ceux qui en viennent) ; molette ou
--     chevrons au-delà de dix lignes ;
--   * à droite : les titres à gagner, deux tris (les plus proches, par
--     catégorie) ; par ligne le titre avec mon nom, « <haut fait> :
--     <condition> », la barre et « cur / max » ; molette.
-- Le choix passe par FeatsTitles.lua (ns:FeatTitleOptionValue,
-- ns:FeatTitlePick) : la même source que la fiche de dresseur et /qc titre.
-- Jamais dans « À gagner » : un titre d'un secret pas encore découvert, d'un
-- haut fait en attente (pending) ou d'un tour de force (le plus souvent
-- limité dans le temps : il ne se « gagne » plus forcément).
-- Rien n'est calculé tant que l'onglet est fermé ; la molette reprend les
-- listes du dernier rafraîchissement complet.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme
local FP = ns.FeatsPage
if not FP then return end
local K = ns.JOURNAL_FEATS_LAYOUT

local FR = {
	FEAT_TT_FORM       = "Forme :",
	FEAT_TT_FORM_auto  = "automatique",
	FEAT_TT_FORM_m     = "masculine, choisie",
	FEAT_TT_FORM_f     = "féminine, choisie",
	FEAT_TT_FORM_TIP   = "La forme se règle dans les réglages : page Carnet de voyage, « Forme des titres ».",
	FEAT_TT_EARNED     = "Gagnés · %s sur %s",
	FEAT_TT_AUTO       = "Automatique : le plus haut rang d'espèces",
	FEAT_TT_MORE_1     = "et 1 autre : molette ou chevrons",
	FEAT_TT_MORE       = "et %d autres : molette ou chevrons",
	FEAT_TT_TOGO       = "À gagner · %s",
	FEAT_TT_SORT_near  = "Les plus proches",
	FEAT_TT_SORT_cat   = "Par catégorie",
	FEAT_TT_TAG_FOS    = "Tour de force",
	FEAT_TT_TOGO_NONE  = "Tous les titres à ta portée sont gagnés.",
	FEAT_TT_ROW_TIP    = "Clic : ce haut fait, déplié dans sa catégorie.",
	FEAT_TT_UNKNOWN    = "—",
}
local EN = {
	FEAT_TT_FORM       = "Form:",
	FEAT_TT_FORM_auto  = "automatic",
	FEAT_TT_FORM_m     = "masculine, chosen",
	FEAT_TT_FORM_f     = "feminine, chosen",
	FEAT_TT_FORM_TIP   = "Set the form in the settings: Travel journal page, \"Title form\".",
	FEAT_TT_EARNED     = "Earned · %s of %s",
	FEAT_TT_AUTO       = "Automatic: the highest species rank",
	FEAT_TT_MORE_1     = "and 1 more: mouse wheel or chevrons",
	FEAT_TT_MORE       = "and %d more: mouse wheel or chevrons",
	FEAT_TT_TOGO       = "To earn · %s",
	FEAT_TT_SORT_near  = "Closest first",
	FEAT_TT_SORT_cat   = "By category",
	FEAT_TT_TAG_FOS    = "Feat of strength",
	FEAT_TT_TOGO_NONE  = "Every title within your reach is earned.",
	FEAT_TT_ROW_TIP    = "Click: this achievement, expanded in its category.",
	FEAT_TT_UNKNOWN    = "—",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.JOURNAL_FEATS_TITLES_STRINGS = { fr = FR, en = EN } end

local NoWrap, Paint, Num = FP.NoWrap, FP.Paint, FP.Num

-- Mesures de la maquette (carnet_views.py, bloc J4) : x depuis la gauche de
-- la zone utile, y depuis son haut
ns.JOURNAL_FEATS_TITLES = {
	leftW = 340, shownSecY = 86, shownY = 104, shownH = 52, nameX = 12, nameY = 8, formY = 28,
	earnedSecY = 170, radioX = 4, radioY = 190, radioH = 22, radioStep = 24, radioW = 336, radios = 10,
	radio = 11, radioGap = 8, moreY = 436,
	rightX = 356, rightW = 354, togoSecY = 86, sortY = 104, togoY = 136, togoH = 46, togoStep = 50, togos = 6,
	titleY = 5, lineY = 21, barY = 38, barW = 270, countR = 10, countY = 25, countW = 70, positionY = 440,
}
local T = ns.JOURNAL_FEATS_TITLES
ns.JOURNAL_FEATS_TITLE_SORTS = { "near", "cat" }

-- encre du titre à gagner : le gris des libellés, un peu éclairci (maquette #b4b9be)
ns.FEAT_TOGO_LIFT = 0.12
function FP.TogoInk() return Theme.Over(Theme.MUTED_LIGHT, Theme.WHITE, ns.FEAT_TOGO_LIFT) end

local function G(name) return rawget(_G, name) end
local function PlayerName()
	local fn = G("UnitName")
	local ok, name = false, nil
	if type(fn) == "function" then ok, name = pcall(fn, "player") end
	name = ok and (ns.Plain and ns.Plain(name) or name) or nil
	if type(name) ~= "string" or name == "" then return "?" end
	return name
end

-- ---------------------------------------------------------------------------
-- Données
-- ---------------------------------------------------------------------------
-- Le haut fait qui donne un titre : sa source déclarée, sinon le premier qui
-- le donne en récompense
local function SourceIndex(self)
	local byCode = {}
	for _, def in ipairs(self:FeatDefs()) do
		local code = type(def.reward) == "table" and tonumber(def.reward.title)
		if code and not byCode[code] then byCode[code] = def end
	end
	for code, title in pairs(ns.FEAT_TITLES or {}) do
		local def = title.src and self:FeatDef(title.src)
		if def then byCode[code] = def end
	end
	return byCode
end

local function TitleCount()
	local n = 0
	for _ in pairs(ns.FEAT_TITLES or {}) do n = n + 1 end
	return n
end

-- Les options à choix unique : Automatique, Aucun titre, puis chaque titre
-- gagné (ordre des codes, comme la fiche de dresseur). { value, label, fos }
function ns:FeatTitlesPickList(name, sources)
	name = name or PlayerName()
	sources = sources or SourceIndex(self)
	local list = { { value = "auto", label = L.FEAT_TT_AUTO }, { value = "none", label = L.FEAT_TITLE_NONE } }
	for _, code in ipairs(self:FeatTitlesEarned()) do
		local def = sources[code]
		list[#list + 1] = { value = tostring(code), code = code, label = self:FeatTitleText(code, name) or tostring(code),
			fos = def ~= nil and def.cat == ns.FEAT_FOS }
	end
	return list
end

-- Les titres à gagner : { code, def, cur, max, state, ratio, label, line },
-- triés par proximité ("near") ou par catégorie ("cat")
function ns:FeatTitlesToGo(sort, name, sources)
	name = name or PlayerName()
	sources = sources or SourceIndex(self)
	local earned = {}
	for _, code in ipairs(self:FeatTitlesEarned()) do earned[code] = true end
	local catPos = {}
	for index, cat in ipairs(self:FeatCategories()) do catPos[cat] = index end
	if self.FeatCacheReset then self:FeatCacheReset() end
	local list = {}
	for code in pairs(ns.FEAT_TITLES or {}) do
		local def = sources[code]
		if not earned[code] and def and not def.pending and not FP.Secret(self, def) and def.cat ~= ns.FEAT_FOS
			and not self:FeatGot(def) then
			local cur, max, state = self:FeatProgress(def)
			local ratio = (state == "open" and max > 0) and math.min(1, cur / max) or -1
			list[#list + 1] = { code = code, def = def, cur = cur, max = max, state = state, ratio = ratio,
				pos = catPos[def.cat] or 999,
				label = self:FeatTitleText(code, name) or tostring(code),
				line = self:F("FEAT_NEAR_LINE", self:FeatName(def), FP.LowerFirst(self:FeatDescription(def))) }
		end
	end
	if self.FeatCacheReset then self:FeatCacheReset() end
	local function Closer(a, b)
		if a.ratio ~= b.ratio then return a.ratio > b.ratio end
		local pa, pb = tonumber(a.def.pts) or 0, tonumber(b.def.pts) or 0
		if pa ~= pb then return pa < pb end
		return a.code < b.code
	end
	if sort == "cat" then
		table.sort(list, function(a, b)
			if a.pos ~= b.pos then return a.pos < b.pos end
			return Closer(a, b)
		end)
	else
		table.sort(list, Closer)
	end
	return list
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
-- bouton rond : l'anneau du socle (texture), le point lumineux s'il est choisi
local function Radio(parent)
	local size = T.radio
	local radio = CreateFrame("Frame", nil, parent)
	radio:SetSize(size, size)
	radio.ring = Theme.ArtTexture(radio, "ring", "ARTWORK", 0, Theme.MUTED_LIGHT, 1)
	local spec = Theme.ART and Theme.ART.ring
	local full = math.floor(size / ((spec and spec.outer) or 0.94) + 0.5)
	radio.ring:SetSize(full, full)
	radio.ring:SetPoint("CENTER", radio, "CENTER", 0, 0)
	radio.dot = Theme.ArtTexture(radio, "dot", "OVERLAY", 0, Theme.GOLD_LIGHT, 1)
	radio.dot:SetSize(size, size)
	radio.dot:SetPoint("CENTER", radio, "CENTER", 0, 0)
	function radio:SetOn(on)
		self.on = on and true or false
		local c = self.on and Theme.GOLD_LIGHT or Theme.MUTED_LIGHT
		self.ring:SetVertexColor(c[1], c[2], c[3], 1)
		if self.on then self.dot:Show() else self.dot:Hide() end
	end
	radio:SetOn(false)
	return radio
end

local function BuildRadioRow(view, index)
	local row = CreateFrame("Button", nil, view)
	row:SetSize(T.radioW, T.radioH)
	row.radio = Radio(row)
	row.radio:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label = NoWrap(Theme.Text(row, Theme.F_BODY, Theme.TEXT))
	row.label:SetJustifyH("LEFT")
	row.label:SetPoint("LEFT", row, "LEFT", T.radio + T.radioGap, 0)
	row.tag = Theme.CreateTag(row, "")
	row:SetScript("OnClick", function(r) if r.value then ns:FeatTitlePick(r.value) end end)
	view.Place(row, T.radioX, T.radioY + (index - 1) * T.radioStep)
	return row
end

local function BuildTogoRow(view, index)
	local row = Theme.CreateTile(view, T.rightW, T.togoH)
	row.title = NoWrap(Theme.Text(row, Theme.F_LABEL, FP.TogoInk()))
	row.title:SetJustifyH("LEFT")
	row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -T.titleY)
	row.title:SetWidth(T.rightW - 20)
	row.line = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT))
	row.line:SetJustifyH("LEFT")
	row.line:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -T.lineY)
	row.line:SetWidth(T.rightW - T.countW - 24)
	row.bar = Theme.CreateBar(row, T.barW, 4)
	row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -T.barY)
	row.count = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT))
	row.count:SetJustifyH("RIGHT")
	row.count:SetPoint("TOPRIGHT", row, "TOPRIGHT", -T.countR, -T.countY)
	row.count:SetWidth(T.countW)
	row:SetScript("OnClick", function(r) if r.def then ns:OpenJournalFeatsAt(r.def.id) end end)
	row.onEnter = function(r)
		local tip = G("GameTooltip")
		if not (r.def and type(tip) == "table") then return end
		ns.JournalTipAnchor(tip, r, "row")
		if tip.ClearLines then tip:ClearLines() end
		Theme.TooltipTitle(tip, r.title:GetText() or "")
		Theme.TooltipLine(tip, ns:FeatName(r.def), Theme.TEXT, true)
		Theme.TooltipLine(tip, ns:FeatDescription(r.def), Theme.MUTED_LIGHT, true)
		Theme.TooltipHint(tip, L.FEAT_TT_ROW_TIP, true)
		tip:Show()
	end
	row.onLeave = function() local tip = G("GameTooltip"); if tip and tip.Hide then tip:Hide() end end
	view.Place(row, T.rightX, T.togoY + (index - 1) * T.togoStep)
	return row
end

local function Build(self, frame, view, ui, Place)
	view.Place = Place
	local lift = K.sectionLift
	-- titre affiché
	view.shownSec = FP.Section(view, L.FEAT_TITLE_PICK, T.leftW)
	Place(view.shownSec, 0, T.shownSecY - lift)
	local tile = Theme.CreateTile(view, T.leftW, T.shownH, { kind = "Frame" })
	Place(tile, 0, T.shownY)
	tile.name = NoWrap(Theme.Text(tile, Theme.F_HEADING, Theme.GOLD_LIGHT))
	tile.name:SetJustifyH("LEFT")
	tile.name:SetPoint("TOPLEFT", tile, "TOPLEFT", T.nameX, -T.nameY)
	tile.name:SetWidth(T.leftW - 2 * T.nameX)
	tile.formLabel = NoWrap(Theme.Text(tile, Theme.F_SMALL, Theme.MUTED_LIGHT))
	tile.formLabel:SetPoint("TOPLEFT", tile, "TOPLEFT", T.nameX, -T.formY)
	tile.formLabel:SetText(L.FEAT_TT_FORM)
	tile.form = NoWrap(Theme.Text(tile, Theme.F_SMALL, Theme.LABEL))
	tile.form:SetPoint("LEFT", tile.formLabel, "RIGHT", 6, 0)
	tile:EnableMouse(true)
	tile.onEnter = function(t)
		local tip = G("GameTooltip")
		if type(tip) ~= "table" then return end
		ns.JournalTipAnchor(tip, t, "row")
		if tip.ClearLines then tip:ClearLines() end
		Theme.TooltipTitle(tip, L.FEAT_TITLE_PICK)
		Theme.TooltipLine(tip, L.FEAT_TT_FORM_TIP, Theme.TEXT, true)
		tip:Show()
	end
	tile.onLeave = function() local tip = G("GameTooltip"); if tip and tip.Hide then tip:Hide() end end
	view.display = tile

	-- gagnés
	view.earnedSec = FP.Section(view, L.FEAT_TT_EARNED, T.leftW)
	Place(view.earnedSec, 0, T.earnedSecY - lift)
	view.left = CreateFrame("Frame", nil, view)
	view.left:SetSize(T.leftW, T.moreY + 16 - T.earnedSecY)
	Place(view.left, 0, T.earnedSecY)
	view.radios = {}
	for index = 1, T.radios do view.radios[index] = BuildRadioRow(view, index) end
	view.more = NoWrap(Theme.Text(view, Theme.F_SMALL, Theme.MUTED_LIGHT))
	view.more:SetWidth(T.leftW - 60)
	view.more:SetJustifyH("LEFT")
	Place(view.more, T.radioX, T.moreY)
	-- chevrons de la liste de gauche (la position est déjà dans « et k autres »)
	view.pager = Theme.CreatePager(view, function(delta)
		frame.featsTitleOffset = (tonumber(frame.featsTitleOffset) or 0) - delta
		ns:RefreshJournal()
	end)
	view.pager.position:Hide()
	Place(view.pager, T.leftW - 200, T.moreY - 4)

	-- à gagner
	view.togoSec = FP.Section(view, L.FEAT_TT_TOGO, T.rightW)
	Place(view.togoSec, T.rightX, T.togoSecY - lift)
	local defs = {}
	for _, id in ipairs(ns.JOURNAL_FEATS_TITLE_SORTS) do defs[#defs + 1] = { id = id, label = L["FEAT_TT_SORT_" .. id] } end
	view.sorts = Theme.CreateChips(view, defs, function(id)
		frame.featsTitleSort, frame.featsTogoOffset = id, 0
		ns:RefreshJournal()
	end, { gap = K.tabGap })
	FP.Relayout(view.sorts, K.tabPad, K.tabGap)
	Place(view.sorts, T.rightX, T.sortY)
	view.togo = {}
	for index = 1, T.togos do view.togo[index] = BuildTogoRow(view, index) end
	view.togoNone = Theme.Text(view, Theme.F_SMALL, Theme.MUTED)
	view.togoNone:SetWidth(T.rightW)
	view.togoNone:SetJustifyH("LEFT")
	Place(view.togoNone, T.rightX, T.togoY + 4)
	view.position = NoWrap(Theme.Text(view, Theme.F_SMALL, Theme.MUTED_LIGHT))
	view.position:SetJustifyH("LEFT")
	Place(view.position, T.rightX, T.positionY)
end

-- ---------------------------------------------------------------------------
-- Dessin (listes reprises du dernier rafraîchissement complet à la molette)
-- ---------------------------------------------------------------------------
local function Clamp(value, count, page)
	local maxOffset = math.max(0, count - page)
	return math.max(0, math.min(math.floor(tonumber(value) or 0), maxOffset)), maxOffset
end

local function Layout(self, frame, view)
	local picks, togo, current = view.picks or {}, view.togoList or {}, view.current
	-- gauche
	local offset, maxOffset = Clamp(frame.featsTitleOffset, #picks, T.radios)
	frame.featsTitleOffset = offset
	for index, row in ipairs(view.radios) do
		local item = picks[offset + index]
		if item then
			local on = item.value == current
			row.value = item.value
			row.radio:SetOn(on)
			row.label:SetText(item.label)
			row.label:SetFontObject(on and Theme.F_LABEL or Theme.F_BODY)
			Paint(row.label, on and Theme.PARCHMENT or Theme.TEXT)
			local w = math.ceil(Theme.TextWidth(row, item.label, on and Theme.F_LABEL or Theme.F_BODY))
			local room = T.radioW - T.radio - T.radioGap
			if item.fos then
				row.tag:SetTag(L.FEAT_TT_TAG_FOS, Theme.GOLD_LIGHT)
				local tagW = row.tag:GetWidth() or 0
				w = math.min(w, room - tagW - 8)
				row.tag:ClearAllPoints()
				row.tag:SetPoint("LEFT", row, "LEFT", T.radio + T.radioGap + w + 8, 0)
			else
				row.tag:SetTag("")
				w = math.min(w, room)
			end
			row.label:SetWidth(w + 2)
			row:Show()
		else
			row.value = nil
			row:Hide()
		end
	end
	local hidden = #picks - math.min(#picks, T.radios)
	if hidden > 0 then
		view.more:SetText(hidden == 1 and L.FEAT_TT_MORE_1 or self:F("FEAT_TT_MORE", hidden))
		view.pager:Update(offset, T.radios, #picks, maxOffset)
		view.pager:Show()
	else
		view.more:SetText("")
		view.pager:Hide()
	end
	-- droite
	local togoOffset = Clamp(frame.featsTogoOffset, #togo, T.togos)
	frame.featsTogoOffset = togoOffset
	for index, row in ipairs(view.togo) do
		local item = togo[togoOffset + index]
		if item then
			row.def, row.code = item.def, item.code
			row.title:SetText(item.label)
			row.line:SetText(item.line)
			if item.state == "open" then
				row.bar:SetValue(math.max(0, item.ratio))
				row.count:SetText(self:FeatCountText(item.cur, item.max))
			else
				row.bar:SetValue(0)
				row.count:SetText(L.FEAT_TT_UNKNOWN)
			end
			row:Show()
		else
			row.def, row.code = nil, nil
			row:Hide()
		end
	end
	view.togoNone:SetText(#togo == 0 and L.FEAT_TT_TOGO_NONE or "")
	local last = math.min(#togo, togoOffset + T.togos)
	view.position:SetText(#togo > T.togos and self:F("FEAT_POSITION", togoOffset + 1, last, #togo) or "")
end

local function Refresh(self, frame, view)
	if frame.scrollOnly and view.picks then return Layout(self, frame, view) end
	local name = PlayerName()
	local sources = SourceIndex(self)
	view.picks = self:FeatTitlesPickList(name, sources)
	view.current = self:FeatTitleOptionValue()
	-- première ouverture de la session : le titre choisi en vue
	if frame.featsTitleOffset == nil then
		frame.featsTitleOffset = 0
		for index, item in ipairs(view.picks) do
			if item.value == view.current and index > T.radios then frame.featsTitleOffset = index - T.radios end
		end
	end
	local sort = frame.featsTitleSort or "near"
	view.sorts:Select(sort, true)
	view.togoList = self:FeatTitlesToGo(sort, name, sources)
	-- titre affiché, forme
	local code = self:FeatTitleCode()
	view.display.name:SetText(code and self:FeatTitleText(code, name) or name)
	view.display.form:SetText(L["FEAT_TT_FORM_" .. self:FeatTitleForm()] or L.FEAT_TT_FORM_auto)
	view.earnedSec:SetText(self:F("FEAT_TT_EARNED", Num(#view.picks - 2), Num(TitleCount())))
	view.togoSec:SetText(self:F("FEAT_TT_TOGO", Num(#view.togoList)))
	Layout(self, frame, view)
end

-- La molette : la liste sous le pointeur (les titres gagnés à gauche, sinon
-- ceux à gagner)
local function Over(region)
	if not (region and region.IsMouseOver) then return false end
	local ok, over = pcall(region.IsMouseOver, region)
	return ok and over and true or false
end
local function Scroll(self, frame, delta)
	local view = frame.feats and frame.feats.views and frame.feats.views.titles
	delta = tonumber(delta) or 0
	if view and Over(view.left) then
		frame.featsTitleOffset = (tonumber(frame.featsTitleOffset) or 0) - delta
	else
		frame.featsTogoOffset = (tonumber(frame.featsTogoOffset) or 0) - delta
	end
end

ns.JOURNAL_FEATS_VIEWS = ns.JOURNAL_FEATS_VIEWS or {}
ns.JOURNAL_FEATS_VIEWS.titles = { build = Build, refresh = Refresh, scroll = Scroll }

if ns.Mark then ns.Mark("JournalFeatsTitles") end
