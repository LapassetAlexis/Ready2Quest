-- JournalFeatsStats.lua -- onglet « Statistiques » de la page Hauts faits
-- (QuestCompanion 3.7.0, chantier C1b ; maquette validée : carnet-j5)
--
-- Six blocs de cinq lignes : Captures, Collection, Brillantes, Spécimens,
-- Compagnon, Réserve et Échoppe. Une seule source : ns:FeatStatsBlocks()
-- (l'onglet s'en dessine ; le texte « Copier pour Discord » s'en compose) :
--   { { key, title, rows = { { key, label, value, fresh } } } }
--   * value : le texte affiché, « — » quand la valeur est inconnue (jamais
--     un 0 trompeur) ;
--   * fresh : compté depuis la 3.7 seulement (compteurs de Tally.lua) ; à
--     l'écran, un point bleu après le libellé et la légende en bas.
-- D'où viennent les chiffres : la sauvegarde, lue par les sources des hauts
-- faits (ns.FEAT_SOURCES, leurs relevés gardés) ; Tally.lua pour le reste ;
-- un relevé à nous pour les records de spécimens (fiches d'étude et
-- spécimens, gardé tant que la collection ne bouge pas).
-- Rien n'est calculé tant que l'onglet est fermé, ni à la molette.
-- Le bouton « Copier pour Discord » n'existe que si ns.DiscordCopyShow
-- existe (étape 3) : ns:DiscordCopyShow("stats", ns:FeatStatsBlocks()).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme
local FP = ns.FeatsPage
if not FP then return end
local K = ns.JOURNAL_FEATS_LAYOUT

local FR = {
	FEAT_ST_captures        = "Captures",
	FEAT_ST_caught          = "Prises",
	FEAT_ST_throws          = "Lancers de filet",
	FEAT_ST_success         = "Réussite",
	FEAT_ST_streak          = "Plus longue série de réussites",
	FEAT_ST_hunt            = "Prises en mode chasse",
	FEAT_ST_collection      = "Collection",
	FEAT_ST_species         = "Espèces",
	FEAT_ST_stars3          = "À 3 étoiles",
	FEAT_ST_mastered        = "Maîtrisées",
	FEAT_ST_zones           = "Zones de chasse",
	FEAT_ST_seals           = "Sceaux",
	FEAT_ST_shinies         = "Brillantes",
	FEAT_ST_shinySeen       = "Repérées",
	FEAT_ST_shinyFound      = "Trouvées",
	FEAT_ST_shinyCap        = "Capturées",
	FEAT_ST_shinyChain      = "Plus haute série de chasse",
	FEAT_ST_shinyDay        = "Deux le même jour",
	FEAT_ST_specimens       = "Spécimens",
	FEAT_ST_biggest         = "Le plus grand",
	FEAT_ST_smallest        = "Le plus petit",
	FEAT_ST_mostCaught      = "Espèce la plus capturée",
	FEAT_ST_bond5           = "Inséparables",
	FEAT_ST_nicks           = "Surnommés",
	FEAT_ST_companion       = "Compagnon",
	FEAT_ST_km              = "Kilomètres parcourus",
	FEAT_ST_days            = "Jours ensemble",
	FEAT_ST_radiant         = "Temps Rayonnant",
	FEAT_ST_wishes          = "Envies comblées",
	FEAT_ST_treats          = "Friandises données",
	FEAT_ST_shop            = "Réserve et Échoppe",
	FEAT_ST_glitter         = "Paillettes gagnées",
	FEAT_ST_glitterSpent    = "Paillettes dépensées",
	FEAT_ST_release         = "Relâchers",
	FEAT_ST_orders          = "Commandes livrées",
	FEAT_ST_trades          = "Échanges",
	FEAT_ST_UNKNOWN         = "—",
	FEAT_ST_PCT             = "%d %%",
	FEAT_ST_HOURS           = "%d h %02d",
	FEAT_ST_MINUTES         = "%d min",
	FEAT_ST_ON              = "le %s",
	FEAT_ST_NAMED           = "%s (%s)",
	FEAT_ST_LEGEND          = "compté depuis la 3.7 : rien n'était noté avant",
	FEAT_ST_COPY            = "Copier pour Discord",
	FEAT_ST_FRESH_TIP       = "Compté depuis la 3.7 : rien n'était noté avant.",
}
local EN = {
	FEAT_ST_captures        = "Captures",
	FEAT_ST_caught          = "Catches",
	FEAT_ST_throws          = "Net throws",
	FEAT_ST_success         = "Success rate",
	FEAT_ST_streak          = "Longest success streak",
	FEAT_ST_hunt            = "Catches in hunt mode",
	FEAT_ST_collection      = "Collection",
	FEAT_ST_species         = "Species",
	FEAT_ST_stars3          = "With 3 stars",
	FEAT_ST_mastered        = "Mastered",
	FEAT_ST_zones           = "Hunting grounds",
	FEAT_ST_seals           = "Seals",
	FEAT_ST_shinies         = "Shinies",
	FEAT_ST_shinySeen       = "Spotted",
	FEAT_ST_shinyFound      = "Found",
	FEAT_ST_shinyCap        = "Captured",
	FEAT_ST_shinyChain      = "Highest hunt streak",
	FEAT_ST_shinyDay        = "Two on the same day",
	FEAT_ST_specimens       = "Specimens",
	FEAT_ST_biggest         = "Biggest",
	FEAT_ST_smallest        = "Smallest",
	FEAT_ST_mostCaught      = "Most caught species",
	FEAT_ST_bond5           = "Inseparables",
	FEAT_ST_nicks           = "Nicknamed",
	FEAT_ST_companion       = "Companion",
	FEAT_ST_km              = "Kilometres travelled",
	FEAT_ST_days            = "Days together",
	FEAT_ST_radiant         = "Time Radiant",
	FEAT_ST_wishes          = "Wishes granted",
	FEAT_ST_treats          = "Treats given",
	FEAT_ST_shop            = "Reserve and Shop",
	FEAT_ST_glitter         = "Glitter earned",
	FEAT_ST_glitterSpent    = "Glitter spent",
	FEAT_ST_release         = "Releases",
	FEAT_ST_orders          = "Orders delivered",
	FEAT_ST_trades          = "Trades",
	FEAT_ST_UNKNOWN         = "—",
	FEAT_ST_PCT             = "%d%%",
	FEAT_ST_HOURS           = "%dh %02dm",
	FEAT_ST_MINUTES         = "%d min",
	FEAT_ST_ON              = "on %s",
	FEAT_ST_NAMED           = "%s (%s)",
	FEAT_ST_LEGEND          = "counted since 3.7: nothing was recorded before",
	FEAT_ST_COPY            = "Copy for Discord",
	FEAT_ST_FRESH_TIP       = "Counted since 3.7: nothing was recorded before.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.JOURNAL_FEATS_STATS_STRINGS = { fr = FR, en = EN } end

local NoWrap, Paint, Num = FP.NoWrap, FP.Paint, FP.Num

-- Mesures de la maquette (carnet_views.py, bloc J5)
ns.JOURNAL_FEATS_STATS = {
	tileW = 347, tileH = 126, cols = { 0, 363 }, rowsY = { 82, 216, 350 }, pad = 10, secY = 9, kvY = 28, kvStep = 19,
	dot = 12, dotGap = 1, legendY = 488, copyY = 481, copyW = 140, rows = 5,
}
local S = ns.JOURNAL_FEATS_STATS

-- l'ordre de l'écran : blocs de gauche à droite puis de haut en bas
ns.FEAT_STATS_LAYOUT = {
	{ "captures",   { "caught", "throws", "success", "streak", "hunt" } },
	{ "collection", { "species", "stars3", "mastered", "zones", "seals" } },
	{ "shinies",    { "shinySeen", "shinyFound", "shinyCap", "shinyChain", "shinyDay" } },
	{ "specimens",  { "biggest", "smallest", "mostCaught", "bond5", "nicks" } },
	{ "companion",  { "km", "days", "radiant", "wishes", "treats" } },
	{ "shop",       { "glitter", "glitterSpent", "release", "orders", "trades" } },
}

local A, CH = "account", "char"
local function G(name) return rawget(_G, name) end
local function Sub(t, key) return type(t) == "table" and type(t[key]) == "table" and t[key] or nil end

-- ---------------------------------------------------------------------------
-- Lectures (toutes protégées : une source illisible donne « — »)
-- ---------------------------------------------------------------------------
-- une source des hauts faits (sauvegarde, relevés gardés)
local function Src(self, name, scope)
	local sources = ns.FEAT_SOURCES
	local source = type(sources) == "table" and sources[name]
	if type(source) ~= "table" or type(source.get) ~= "function" then return nil end
	local ok, value = pcall(source.get, self, scope or A)
	return ok and tonumber(value) or nil
end
-- un compteur de Tally.lua (nil s'il n'est pas chargé)
local function Tally(self, fn, key, scope)
	local read = self[fn]
	if type(read) ~= "function" then return nil end
	local ok, value = pcall(read, self, key, scope or A)
	return ok and tonumber(value) or nil
end
local function Capture(self)
	if type(self.CaptureData) ~= "function" then return nil end
	local ok, data = pcall(self.CaptureData, self)
	return ok and type(data) == "table" and data or nil
end

-- Records des spécimens : le plus grand et le plus petit indice de taille
-- (fiches d'étude : lo, hi), l'espèce la plus capturée (n), le premier jour
-- à deux brillantes capturées (spécimens datés). Gardé tant que la
-- collection ne bouge pas.
local records, recordsKey
local function DayOf(at)
	local fn = G("date")
	if type(fn) == "function" then
		local ok, text = pcall(fn, "%Y%m%d", at)
		if ok and type(text) == "string" and text:find("^%d%d%d%d%d%d%d%d$") then return text end
	end
	return tostring(math.floor(at / 86400))
end
local function Records(self)
	local capture = Capture(self)
	if not capture then return {} end
	if self.SpecimenStudyRetro then pcall(self.SpecimenStudyRetro, self) end
	local study = Sub(capture, "study") or {}
	local specimens = Sub(capture, "specimens") or {}
	local key = table.concat({ tostring(study), tostring(specimens), tostring(capture.specSerial), tostring(capture.serial),
		tostring(capture.count), tostring(capture.caught) }, ":")
	if records and recordsKey == key then return records end
	local r = {}
	for npc, row in pairs(study) do
		if type(row) == "table" then
			local id = tonumber(npc) or npc
			local hi, lo, n = tonumber(row.hi), tonumber(row.lo), tonumber(row.n) or 0
			if hi and (not r.big or hi > r.big.v or (hi == r.big.v and tostring(id) < tostring(r.big.npc))) then r.big = { npc = id, v = hi } end
			if lo and (not r.small or lo < r.small.v or (lo == r.small.v and tostring(id) < tostring(r.small.npc))) then r.small = { npc = id, v = lo } end
			if n > 0 and (not r.most or n > r.most.v or (n == r.most.v and tostring(id) < tostring(r.most.npc))) then r.most = { npc = id, v = n } end
		end
	end
	local days = {}
	for _, spec in pairs(specimens) do
		local at = type(spec) == "table" and spec.shiny and tonumber(spec.at)
		local origin = type(spec) == "table" and (spec.origin or "capture")
		if at and at > 0 and (origin == "capture" or origin == "migration") then
			local day = DayOf(at)
			local d = days[day] or { n = 0, at = at }
			d.n, d.at = d.n + 1, math.min(d.at, at)
			days[day] = d
		end
	end
	for _, d in pairs(days) do
		if d.n >= 2 and (not r.twoDay or d.at < r.twoDay) then r.twoDay = d.at end
	end
	records, recordsKey = r, key
	return r
end
function ns:FeatStatsRecordsReset() records, recordsKey = nil, nil end
function ns:FeatStatsRecords() return Records(self) end

local function SpeciesName(self, npc)
	local capture = Capture(self)
	local record = capture and Sub(capture, "creatures") and capture.creatures[npc]
	if type(record) == "table" and type(record.name) == "string" and record.name ~= "" and not ns.STRINGS_SPANISH then return record.name end
	if self.CreatureName then
		local ok, name = pcall(self.CreatureName, self, npc)
		if ok and type(name) == "string" then return name end
	end
	return tostring(npc)
end

-- ---------------------------------------------------------------------------
-- Valeurs : nombre ou texte, nil si inconnue ; fresh : Tally.lua
-- ---------------------------------------------------------------------------
local function Duration(self, minutes)
	minutes = math.max(0, math.floor(minutes))
	if minutes < 60 then return self:F("FEAT_ST_MINUTES", minutes) end
	return self:F("FEAT_ST_HOURS", math.floor(minutes / 60), minutes % 60)
end
-- un maximum de Tally.lua : 0 veut dire « pas encore de record » (inconnu)
local function Best(self, key, scope)
	local v = Tally(self, "TallyBest", key, scope)
	if not v or v <= 0 then return nil end
	return v
end

local FRESH = { streak = true, hunt = true, shinyChain = true, radiant = true, wishes = true, treats = true,
	glitterSpent = true, release = true, orders = true }
ns.FEAT_STATS_FRESH = FRESH

local VALUES = {
	caught = function(self) return Src(self, "caught") end,
	throws = function(self) local c = Capture(self); return c and tonumber(c.tries) or nil end,
	success = function(self)
		local c = Capture(self)
		local tries, caught = c and tonumber(c.tries) or 0, Src(self, "caught")
		if tries <= 0 or not caught then return nil end
		return self:F("FEAT_ST_PCT", math.floor(100 * math.min(caught, tries) / tries + 0.5))
	end,
	streak = function(self) return Best(self, "captureStreak") end,
	hunt = function(self) return Tally(self, "TallyGet", "captureHunt") end,
	species = function(self)
		local have = Src(self, "species", A)
		if not have then return nil end
		local need = 0
		if self.MenagerieAzeroth then
			local ok, _, n = pcall(self.MenagerieAzeroth, self)
			need = ok and tonumber(n) or 0
		end
		if need > 0 then return self:F("FEAT_PAIR", Num(have), Num(need)) end
		return have
	end,
	stars3 = function(self) return Src(self, "stars3") end,
	mastered = function(self) return Src(self, "studyMastered") end,
	zones = function(self) return Src(self, "captureZones") end,
	seals = function(self) return Src(self, "seals") end,
	shinySeen = function(self) return Src(self, "shinySeen") end,
	shinyFound = function(self) return Src(self, "shinyFound") end,
	shinyCap = function(self) return Src(self, "shinyCap", A) end,
	shinyChain = function(self)
		local v = Best(self, "shinyChain")
		if not v then return nil end
		return self:F("FEAT_PAIR", Num(v), Num(tonumber(ns.SHINY_CHAIN_KILLS) or 50))
	end,
	shinyDay = function(self)
		local at = Records(self).twoDay
		if not at then
			local got = self.FeatGot and self:FeatGot("shiny_day_2")
			at = type(got) == "table" and tonumber(got.at) or nil
		end
		local text = at and at > 0 and FP.DateShort(at) or ""
		if text == "" then return nil end
		return self:F("FEAT_ST_ON", text)
	end,
	biggest = function(self)
		local r = Records(self).big
		return r and self:F("FEAT_ST_NAMED", SpeciesName(self, r.npc), Num(r.v)) or nil
	end,
	smallest = function(self)
		local r = Records(self).small
		return r and self:F("FEAT_ST_NAMED", SpeciesName(self, r.npc), Num(r.v)) or nil
	end,
	mostCaught = function(self)
		local r = Records(self).most
		return r and self:F("FEAT_ST_NAMED", SpeciesName(self, r.npc), Num(r.v)) or nil
	end,
	bond5 = function(self) return Src(self, "bond5") end,
	nicks = function(self) return Src(self, "nicks") end,
	km = function(self) return Src(self, "travelKm", CH) end,
	days = function(self) return Src(self, "daysTogether", CH) end,
	radiant = function(self)
		local v = Tally(self, "TallyGet", "radiantMin", CH)
		return v and Duration(self, v) or nil
	end,
	wishes = function(self) return Tally(self, "TallyGet", "wish", CH) end,
	treats = function(self) return Tally(self, "TallyGet", "treat", CH) end,
	glitter = function(self) return Src(self, "glitterEarned") end,
	glitterSpent = function(self) return Tally(self, "TallyGet", "glitterSpent") end,
	release = function(self) return Tally(self, "TallyGet", "release") end,
	orders = function(self) return Tally(self, "TallyGet", "orderDone") end,
	-- compteur du moteur (ctr.trades), tenu depuis les échanges (3.0)
	trades = function(self)
		if type(self.FeatStore) ~= "function" then return nil end
		local ok, store = pcall(self.FeatStore, self, A)
		local ctr = ok and type(store) == "table" and Sub(store, "ctr")
		return ctr and (tonumber(ctr.trades) or 0) or nil
	end,
}
ns.FEAT_STATS_VALUES = VALUES

-- Les six blocs, dans l'ordre de l'écran (forme figée : un autre chantier
-- compose le texte « Copier pour Discord » à partir d'elle)
function ns:FeatStatsBlocks()
	local blocks = {}
	if self.FeatCacheReset then self:FeatCacheReset() end
	for _, spec in ipairs(ns.FEAT_STATS_LAYOUT) do
		local block = { key = spec[1], title = L["FEAT_ST_" .. spec[1]], rows = {} }
		for _, key in ipairs(spec[2]) do
			local fn = VALUES[key]
			local ok, value = false, nil
			if fn then ok, value = pcall(fn, self) end
			if not ok then value = nil end
			if type(value) == "number" then value = Num(value) end
			if type(value) ~= "string" or value == "" then value = L.FEAT_ST_UNKNOWN end
			block.rows[#block.rows + 1] = { key = key, label = L["FEAT_ST_" .. key], value = value, fresh = FRESH[key] == true }
		end
		blocks[#blocks + 1] = block
	end
	if self.FeatCacheReset then self:FeatCacheReset() end
	return blocks
end

-- ---------------------------------------------------------------------------
-- Construction et dessin
-- ---------------------------------------------------------------------------
local function FreshDot(parent)
	local dot = Theme.ArtTexture(parent, "dot", "OVERLAY", 0, Theme.ARCANE_LIGHT, 1)
	dot:SetSize(S.dot, S.dot)
	return dot
end

local function BuildTile(view, index)
	local col, line = (index - 1) % 2 + 1, math.floor((index - 1) / 2) + 1
	local tile = Theme.CreateTile(view, S.tileW, S.tileH, { kind = "Frame" })
	view.Place(tile, S.cols[col], S.rowsY[line])
	local inner = S.tileW - 2 * S.pad
	tile.section = FP.Section(tile, "", inner)
	tile.section:SetPoint("TOPLEFT", tile, "TOPLEFT", S.pad, -(S.secY - K.sectionLift))
	tile.rows = {}
	for r = 1, S.rows do
		local row = CreateFrame("Frame", nil, tile)
		row:SetSize(inner, 14)
		row:SetPoint("TOPLEFT", tile, "TOPLEFT", S.pad, -(S.kvY + (r - 1) * S.kvStep))
		row.label = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT))
		row.label:SetJustifyH("LEFT")
		row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.dot = FreshDot(row)
		row.value = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.LABEL))
		row.value:SetJustifyH("RIGHT")
		row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self)
			local tip = G("GameTooltip")
			if not (self.fresh and type(tip) == "table") then return end
			ns.JournalTipAnchor(tip, self, "row")
			if tip.ClearLines then tip:ClearLines() end
			Theme.TooltipTitle(tip, self.label:GetText() or "")
			Theme.TooltipLine(tip, L.FEAT_ST_FRESH_TIP, Theme.TEXT, true)
			tip:Show()
		end)
		row:SetScript("OnLeave", function() local tip = G("GameTooltip"); if tip and tip.Hide then tip:Hide() end end)
		tile.rows[r] = row
	end
	return tile
end

local function Build(self, frame, view, ui, Place)
	view.Place = Place
	view.tiles = {}
	for index = 1, #ns.FEAT_STATS_LAYOUT do view.tiles[index] = BuildTile(view, index) end
	view.legendDot = FreshDot(view)
	Place(view.legendDot, -S.dot / 2 + 3, S.legendY + 7 - S.dot / 2)
	view.legendDot:Show()
	view.legend = NoWrap(Theme.Text(view, Theme.F_SMALL, Theme.MUTED))
	view.legend:SetText(L.FEAT_ST_LEGEND)
	Place(view.legend, 11, S.legendY + 1)
	view.copy = Theme.CreateButton(view, S.copyW, "sm", L.FEAT_ST_COPY, function()
		if type(ns.DiscordCopyShow) == "function" then ns:DiscordCopyShow("stats", ns:FeatStatsBlocks()) end
	end, "normal")
	local w = math.max(S.copyW, math.ceil(Theme.TextWidth(view, L.FEAT_ST_COPY, Theme.F_LABEL) + 24))
	view.copy:SetWidth(w)
	Place(view.copy, ui.INNER - w, S.copyY)
	view.copy:Hide()
end

local function Refresh(self, frame, view)
	-- la molette ne change aucun chiffre : rien à refaire
	if frame.scrollOnly and view.blocks then return end
	local blocks = self:FeatStatsBlocks()
	view.blocks = blocks
	for index, tile in ipairs(view.tiles) do
		local block = blocks[index]
		tile.section:SetText(block and block.title or "")
		for r, row in ipairs(tile.rows) do
			local item = block and block.rows[r]
			if item then
				row.fresh = item.fresh
				row.label:SetText(item.label)
				local valueW = math.ceil(Theme.TextWidth(row, item.value, Theme.F_SMALL))
				local labelW = math.ceil(Theme.TextWidth(row, item.label, Theme.F_SMALL))
				local room = S.tileW - 2 * S.pad
				local dotW = item.fresh and (S.dot / 2 + 5) or 0
				labelW = math.min(labelW, room - dotW - 40)
				row.label:SetWidth(labelW + 2)
				row.value:SetText(item.value)
				row.value:SetWidth(math.max(40, math.min(valueW + 2, room - labelW - dotW - 10)))
				Paint(row.value, item.value == L.FEAT_ST_UNKNOWN and Theme.MUTED_LIGHT or Theme.LABEL)
				if item.fresh then
					row.dot:ClearAllPoints()
					row.dot:SetPoint("CENTER", row, "LEFT", labelW + 5 + S.dotGap + 2, 0)
					row.dot:Show()
				else
					row.dot:Hide()
				end
				row:Show()
			else
				row.fresh = nil
				row:Hide()
			end
		end
	end
	if type(ns.DiscordCopyShow) == "function" then view.copy:Show() else view.copy:Hide() end
end

ns.JOURNAL_FEATS_VIEWS = ns.JOURNAL_FEATS_VIEWS or {}
ns.JOURNAL_FEATS_VIEWS.stats = { build = Build, refresh = Refresh }

if ns.Mark then ns.Mark("JournalFeatsStats") end
