-- ReserveBrowse.lua -- la Réserve 3.4 : chercher, filtrer, trier, choisir par lot (QuestCompanion 3.4.0)
--
-- 3.4.0 (docs/design-reserve-3.4, § 7) : la page Réserve du carnet trie
-- finement ses spécimens (SpecimenFilters.lua fait le calcul, ici l'écran).
--   * Rangée 1 : recherche (nom, surnom, zone), « Filtres (n) », tri, sens,
--     « Vues » (Tout, Doublons, Relâchables, Meilleurs que le Codex, Récents,
--     Protégés, Ma vue). La liste des espèces de la 3.0 disparaît.
--   * Rangée 2 : une pastille par groupe actif (2 au plus, puis « +n » ; clic :
--     le groupe s'efface), « Effacer », le compte « 37 sur 62 » (rouge et
--     « presque pleine » à RESERVE_TIDY_NEAR places de la fin), « Sélection »
--     (en sélection : « Tout (n) »).
--   * Panneau de filtres posé sur la grille (modal), construit une fois :
--     8 rangées de puces avec leur compteur (OU dans un groupe, ET entre
--     groupes, les états se cumulent), la zone en liste ; pied : compte,
--     « Garder comme Ma vue », « Effacer », « Voir ».
--   * Sélection : la sélection de « Faire de la place » (frame.resTidy) sert
--     à tout : clic = cocher en mode Sélection ; Ctrl+clic et Maj+clic (une
--     plage) sans passer par le bouton. Barre de lot à la place de la rangée
--     du bas : compte, « Protéger », « Échanger » (3 au plus), « Annuler » ;
--     la fiche liste la sélection, le gain, ce qui est laissé de côté
--     (protégés, brillants, références du Codex, apparence portée) et
--     « Relâcher (n) ».
--   * Vignettes : cadenas, flèche verte (plus d'étoiles que le Codex), crans
--     du lien, coche de sélection.
-- La barre et le panneau servent aussi au sélecteur d'échange
-- (CaptureTrades.lua), avec leur propre état (clé « trd »).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.RESERVE_BROWSE = {
	search = 166, filters = 86, filtersX = 172, sort = 124, sortX = 264, dir = 24, dirX = 390, views = 64, viewsX = 420,
	rowStep = 32, pillMax = 128, pills = 2, chipH = 20, chipGap = 4, rowGap = 4, labelW = 74, pad = 10,
	selectLines = 10, footerH = 28,
}
local B = ns.RESERVE_BROWSE
-- textures du client (par référence)
ns.RESERVE_ICONS = {
	lock = "Interface\\Buttons\\LockButton-Locked-Up",
	better = "Interface\\Buttons\\Arrow-Up-Up",
	check = "Interface\\Buttons\\UI-CheckBox-Check",
	up = "Interface\\Buttons\\Arrow-Up-Up",
	down = "Interface\\Buttons\\Arrow-Down-Up",
	locate = "Interface\\Icons\\INV_Misc_Map_01",
	nick = "Interface\\Icons\\INV_Scroll_03",
}
local ICON = ns.RESERVE_ICONS

local FR = {
	RES_SEARCH        = "Nom, surnom ou zone",
	RES_FILTERS       = "Filtres",
	RES_FILTERS_N     = "Filtres (%d)",
	RES_VIEWS         = "Vues",
	RES_DIR_DESC      = "Ordre décroissant (clic : croissant)",
	RES_DIR_ASC       = "Ordre croissant (clic : décroissant)",
	RES_CLEAR         = "Effacer",
	RES_PILL          = "%s : %s",
	RES_PILL_MORE     = "+%d",
	RES_PILL_TIP      = "Clic : enlever ce filtre.",
	RES_COUNT         = "%d sur %d",
	RES_COUNT_NEAR    = "%d sur %d, presque pleine",
	RES_COUNT_FULL    = "%d sur %d, pleine",
	RES_COUNT_TIP     = "Spécimens en Réserve sur ses places. Plus de place : l'Échoppe du dresseur.",
	RES_SHOWN         = "%d affiché(s)",
	RES_SELECT        = "Sélection",
	RES_SELECT_ALL    = "Tout (%d)",
	RES_SELECT_TIP    = "Choisir plusieurs spécimens (Ctrl+clic ou Maj+clic sur une vignette : tout de suite).",
	RES_PANEL_COUNT   = "%d trouvé(s)",
	RES_PANEL_SAVE    = "Garder comme Ma vue",
	RES_PANEL_SAVED   = "Ma vue est gardée : « Vues », « Ma vue ».",
	RES_PANEL_SHOW    = "Voir",
	RES_BATCH_COUNT   = "%d choisi(s)",
	RES_BATCH_PROTECT = "Protéger",
	RES_BATCH_UNPROTECT = "Déprotéger",
	RES_BATCH_TRADE   = "Échanger",
	RES_BATCH_CANCEL  = "Annuler",
	RES_BATCH_TRADE_MAX = "Trois spécimens au plus par échange.",
	RES_BATCH_TRADE_NO  = "L'un d'eux ne peut pas être échangé (protégé, au Codex, porté ou engagé).",
	RES_SEL_TITLE     = "Sélection (%d)",
	RES_SEL_ASIDE     = "Laissés de côté : %d (protégés, brillants, au Codex ou portés)",
	RES_SEL_EMPTY     = "Clique des vignettes pour les choisir. Ctrl+clic ou Maj+clic marche aussi hors Sélection.",
	RES_SEL_PROTECT_ON  = "%d spécimen(s) protégé(s).",
	RES_SEL_PROTECT_OFF = "%d spécimen(s) déprotégé(s).",
	RES_CARD_SIZE     = "%s (%d)",
	RES_PROTECT       = "Protéger",
	RES_UNPROTECT     = "Enlever la protection",
	RES_NICK          = "Surnom",
	RES_NICK_TIP      = "Donner un surnom : %d paillettes (effacer : gratuit).",
	RES_NICK_TIP_FREE = "Donner un surnom : offert une fois au lien Inséparable.",
	RES_NICK_PLACE    = "Surnom (24 lettres au plus)",
	RES_NICK_GIVE     = "Donner (%d)",
	RES_NICK_OK       = "Valider",
	RES_CODEX_ASK     = "Ton spécimen du Codex est lié (%s) : %s prend sa place ? Le lien reste à l'ancien, qui passe en Réserve.",
	RES_CODEX_YES     = "Remplacer",
	RES_ORDER_DELIVER = "Livrer (+%d %s)",
	RES_ORDER_HEAD    = "Commande : %s",
}
local EN = {
	RES_SEARCH        = "Name, nickname or zone",
	RES_FILTERS       = "Filters",
	RES_FILTERS_N     = "Filters (%d)",
	RES_VIEWS         = "Views",
	RES_DIR_DESC      = "Descending (click: ascending)",
	RES_DIR_ASC       = "Ascending (click: descending)",
	RES_CLEAR         = "Clear",
	RES_PILL          = "%s: %s",
	RES_PILL_MORE     = "+%d",
	RES_PILL_TIP      = "Click: remove this filter.",
	RES_COUNT         = "%d of %d",
	RES_COUNT_NEAR    = "%d of %d, almost full",
	RES_COUNT_FULL    = "%d of %d, full",
	RES_COUNT_TIP     = "Specimens in the Reserve out of its slots. More room: the Trainer's Stall.",
	RES_SHOWN         = "%d shown",
	RES_SELECT        = "Select",
	RES_SELECT_ALL    = "All (%d)",
	RES_SELECT_TIP    = "Pick several specimens (Ctrl+click or Shift+click a tile: right away).",
	RES_PANEL_COUNT   = "%d found",
	RES_PANEL_SAVE    = "Keep as My view",
	RES_PANEL_SAVED   = "My view is kept: \"Views\", \"My view\".",
	RES_PANEL_SHOW    = "Show",
	RES_BATCH_COUNT   = "%d picked",
	RES_BATCH_PROTECT = "Protect",
	RES_BATCH_UNPROTECT = "Unprotect",
	RES_BATCH_TRADE   = "Trade",
	RES_BATCH_CANCEL  = "Cancel",
	RES_BATCH_TRADE_MAX = "Three specimens at most per trade.",
	RES_BATCH_TRADE_NO  = "One of them can't be traded (protected, in the Codex, worn or in a trade).",
	RES_SEL_TITLE     = "Selection (%d)",
	RES_SEL_ASIDE     = "Left aside: %d (protected, shiny, in the Codex or worn)",
	RES_SEL_EMPTY     = "Click tiles to pick them. Ctrl+click or Shift+click also works outside Select.",
	RES_SEL_PROTECT_ON  = "%d specimen(s) protected.",
	RES_SEL_PROTECT_OFF = "%d specimen(s) unprotected.",
	RES_CARD_SIZE     = "%s (%d)",
	RES_PROTECT       = "Protect",
	RES_UNPROTECT     = "Remove protection",
	RES_NICK          = "Nickname",
	RES_NICK_TIP      = "Give a nickname: %d glitter (clearing it: free).",
	RES_NICK_TIP_FREE = "Give a nickname: free once at Inseparable bond.",
	RES_NICK_PLACE    = "Nickname (24 letters at most)",
	RES_NICK_GIVE     = "Give (%d)",
	RES_NICK_OK       = "Confirm",
	RES_CODEX_ASK     = "Your Codex specimen is bonded (%s): should %s take its place? The bond stays with the old one, which goes to the Reserve.",
	RES_CODEX_YES     = "Replace",
	RES_ORDER_DELIVER = "Deliver (+%d %s)",
	RES_ORDER_HEAD    = "Order: %s",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.RESERVE_BROWSE_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function UI() return ns.JournalUI or {} end
local function Enable(button, on, why)
	on = on and true or false
	if button.SetEnabled then button:SetEnabled(on) end
	button.qcEnabled = on
	button.disabledTip = (not on) and why or nil
end
local function Paint(region, c, alpha)
	if region and c then region:SetTextColor(c[1], c[2], c[3], alpha or 1) end
end
local function KeyDown(name)
	local fn = G(name)
	if type(fn) ~= "function" then return false end
	local ok, down = pcall(fn)
	return ok and down and true or false
end

-- ---------------------------------------------------------------------------
-- État (par clé : « res » la Réserve, « trd » le sélecteur d'échange)
-- ---------------------------------------------------------------------------
function ns:ReserveBrowseFilter(key)
	local frame = self.journalFrame
	if not frame then return self:ReserveFilterNew() end
	key = key or "res"
	local field = key .. "Filter"
	if type(frame[field]) ~= "table" then frame[field] = self:ReserveFilterNew() end
	return frame[field]
end

local function Changed(self, key)
	local frame = self.journalFrame
	if frame then
		frame[(key or "res") .. "Offset"] = 0
		if (key or "res") == "res" then frame.resConfirm, frame.resCodexAsk, frame.resNick = nil, nil, nil end
	end
	if key == "trd" and frame then frame.tradeOffset = 0 end
	self:RefreshJournal()
end

function ns:ReserveSetView(id, key)
	local frame = self.journalFrame
	if not frame then return nil end
	key = key or "res"
	frame[key .. "Filter"] = self:ReserveView2(id)
	frame[key .. "ViewId"] = id
	if key == "res" then frame.resOrder = nil end
	Changed(self, key)
	return frame[key .. "Filter"]
end

function ns:ReserveToggleFilter(group, value, key)
	local f = self:ReserveBrowseFilter(key)
	self:ReserveFilterToggle(f, group, value)
	local frame = self.journalFrame
	if frame then frame[(key or "res") .. "ViewId"] = nil end
	Changed(self, key)
	return f
end

function ns:ReserveClearGroup(group, key)
	local f = self:ReserveBrowseFilter(key)
	if group == "q" then f.q = nil else f.sets[group] = nil end
	Changed(self, key)
	return f
end

function ns:ReserveClearFilter(key)
	local frame = self.journalFrame
	if not frame then return nil end
	key = key or "res"
	frame[key .. "Filter"] = self:ReserveFilterNew()
	frame[key .. "ViewId"] = nil
	if key == "res" then frame.resOrder = nil end
	local bar = frame.res and frame.res.reserve and frame.res.reserve.bar
	if key == "trd" then bar = frame.res and frame.res.trade and frame.res.trade.bar end
	if bar and bar.search then bar.search:SetText("") end
	Changed(self, key)
	return frame[key .. "Filter"]
end

function ns:ReserveSearch(text, key)
	local f = self:ReserveBrowseFilter(key)
	text = tostring(text or "")
	f.q = text ~= "" and text or nil
	local frame = self.journalFrame
	if frame then
		frame[(key or "res") .. "Offset"] = 0
		if key == "trd" then frame.tradeOffset = 0 else frame.resOffset = 0 end
	end
	if self.JournalSoon then self:JournalSoon("reserveSearch") else self:RefreshJournal() end
end

function ns:ReserveSetSort(sort, desc)
	local frame = self.journalFrame
	if not frame then return end
	frame.resSort = sort
	if desc == nil then desc = sort ~= "name" end
	frame.resDesc = desc and true or false
	if self.JournalRemember then self:JournalRemember("resSort", sort); self:JournalRemember("resDesc", frame.resDesc) end
	frame.resOffset = 0
	self:RefreshJournal()
end

function ns:ReserveFlipSort()
	local frame = self.journalFrame
	if not frame then return end
	local sort = frame.resSort or "stars"
	local desc = frame.resDesc
	if desc == nil then desc = sort ~= "name" end
	self:ReserveSetSort(sort, not desc)
end

function ns:ReservePanelOpen(on, key)
	local frame = self.journalFrame
	if not frame then return end
	frame[(key or "res") .. "Panel"] = on and true or nil
	self:RefreshJournal()
end

-- la Réserve vue par la page : filtrée et triée
function ns:ReserveBrowseList(key)
	local frame = self.journalFrame
	key = key or "res"
	local f = self:ReserveBrowseFilter(key)
	local sort = frame and frame[key .. "Sort"] or "stars"
	local desc = frame and frame[key .. "Desc"]
	if key == "trd" then sort, desc = "stars", nil end
	return self:ReserveQuery(f, sort, desc, "reserve")
end

-- ---------------------------------------------------------------------------
-- Sélection par lot (frame.resTidy = { [id] = true }, resTidyOrder = { id… })
-- ---------------------------------------------------------------------------
function ns:ReserveSelectStart()
	local frame = self.journalFrame
	if not frame then return false end
	frame.resTidy, frame.resTidyOrder = frame.resTidy or {}, frame.resTidyOrder or {}
	frame.resConfirm, frame.resCodexAsk, frame.resNick = nil, nil, nil
	self:RefreshJournal()
	return true
end

-- « Tout (n) » : ce que la page montre
function ns:ReserveSelectAll()
	local frame = self.journalFrame
	if not (frame and frame.resTidy) then return 0 end
	local added = 0
	for _, spec in ipairs(frame.resList or {}) do
		if not frame.resTidy[spec.id] then
			frame.resTidy[spec.id] = true
			frame.resTidyOrder[#frame.resTidyOrder + 1] = spec.id
			added = added + 1
		end
	end
	self:RefreshJournal()
	return added
end

-- Ce que « Relâcher (n) » relâche : relâchables, ni brillants ni protégés ;
-- le reste est laissé de côté. Rend liste, gain, laissés de côté
function ns:ReserveSelectReleasable()
	local frame = self.journalFrame
	local list, aside, gain = {}, 0, 0
	for _, id in ipairs(frame and frame.resTidyOrder or {}) do
		local spec = self:SpecimenGet(id)
		if spec then
			if not spec.shiny and self:SpecimenCanRelease(spec.id) then
				list[#list + 1] = spec
				gain = gain + self:SpecimenReleaseValue(spec)
			else
				aside = aside + 1
			end
		end
	end
	return list, gain, aside
end

-- « Protéger » : tous protégés (ou, s'ils le sont déjà tous, plus aucun)
function ns:ReserveSelectProtect()
	local frame = self.journalFrame
	local ids = frame and frame.resTidyOrder or {}
	if #ids == 0 then return 0 end
	local all = true
	for _, id in ipairs(ids) do if not self:SpecimenProtected(id) then all = false end end
	local on, count = not all, 0
	for _, id in ipairs(ids) do
		if self:SpecimenProtected(id) ~= on then self:SpecimenProtect(id, on); count = count + 1 end
	end
	self:Print(self:F(on and "RES_SEL_PROTECT_ON" or "RES_SEL_PROTECT_OFF", count))
	self:RefreshJournal()
	return count, on
end

-- « Échanger » : 1 à 3 spécimens échangeables. Un échange ouvert : ajoutés à
-- l'offre ; sinon l'invitation part vers la cible, l'offre attend son accord
function ns:ReserveSelectTradeState()
	local frame = self.journalFrame
	local ids = frame and frame.resTidyOrder or {}
	if #ids == 0 then return false end
	if #ids > (ns.TRADE_MAX or 3) then return false, L.RES_BATCH_TRADE_MAX end
	for _, id in ipairs(ids) do
		if not self:SpecimenCanTrade(id) then return false, L.RES_BATCH_TRADE_NO end
	end
	return true
end

local function ApplyPreload(self, frame)
	local s = self.TradeSession and self:TradeSession()
	if not (frame and frame.tradePreload and s and s.phase == "open") then return end
	local ids = frame.tradePreload
	frame.tradePreload = nil
	local offered = {}
	for _, id in ipairs(s.mine or {}) do offered[id] = true end
	for _, id in ipairs(ids) do
		if not offered[id] then self:TradeToggleOffer(id) end
	end
end

function ns:ReserveSelectTrade()
	local frame = self.journalFrame
	local ok = self:ReserveSelectTradeState()
	if not ok then return false end
	local ids = {}
	for index, id in ipairs(frame.resTidyOrder) do ids[index] = id end
	frame.resTidy, frame.resTidyOrder = nil, nil
	frame.tradePreload = ids
	local s = self.TradeSession and self:TradeSession()
	if s and s.phase == "open" then
		ApplyPreload(self, frame)
		self:OpenReserve("trade")
		return true
	end
	if s then
		self:OpenReserve("trade")
		return true
	end
	local started = self.TradeWithTarget and self:TradeWithTarget()
	if not started then frame.tradePreload = nil; self:RefreshJournal(); return false end
	return true
end

-- l'offre préparée part dès que l'échange s'ouvre
do
	local refresh = ns.TradeRefreshView
	if refresh then
		function ns:TradeRefreshView(frame, ...)
			ApplyPreload(self, frame)
			return refresh(self, frame, ...)
		end
	end
end

-- Clic sur une vignette de la Réserve : sélection (mode, Ctrl, Maj) ou fiche
function ns:ReserveTileClick(id)
	local frame = self.journalFrame
	if not (frame and id) then return end
	local ctrl, shift = KeyDown("IsControlKeyDown"), KeyDown("IsShiftKeyDown")
	if not frame.resTidy and (ctrl or shift) then
		frame.resTidy, frame.resTidyOrder = {}, {}
		frame.resConfirm, frame.resCodexAsk, frame.resNick = nil, nil, nil
		if frame.resPick and frame.resPick ~= id and shift then
			frame.resTidy[frame.resPick] = true
			frame.resTidyOrder[1] = frame.resPick
		end
	end
	if frame.resTidy then
		-- Maj : la plage depuis le dernier coché, dans l'ordre de la page
		local last = frame.resTidyOrder[#frame.resTidyOrder]
		if shift and last and last ~= id and frame.resList then
			local a, b
			for index, spec in ipairs(frame.resList) do
				if spec.id == last then a = index end
				if spec.id == id then b = index end
			end
			if a and b then
				local step = a < b and 1 or -1
				for index = a, b, step do
					local other = frame.resList[index].id
					if not frame.resTidy[other] then
						frame.resTidy[other] = true
						frame.resTidyOrder[#frame.resTidyOrder + 1] = other
					end
				end
				frame.resPick = id
				return self:RefreshJournal()
			end
		end
		frame.resPick = id
		return self:ReserveTidyToggle(id)
	end
	return self:ReservePick(id)
end

-- ---------------------------------------------------------------------------
-- « Mettre au Codex » quand l'exemplaire du Codex est lié : demander d'abord
-- ---------------------------------------------------------------------------
function ns:ReserveCodexNeedsAsk(id)
	local spec = self:SpecimenGet(id)
	if not spec or self:SpecimenIsReference(spec.id) then return false end
	local ref = self:SpecimenReference(spec.npc, spec.shiny)
	if not ref then return false end
	return (self.SpecimenBondLevel and self:SpecimenBondLevel(ref) >= 2) and true or false, ref
end

function ns:ReserveToCodexAsk(id, confirm)
	local frame = self.journalFrame
	if not confirm and self:ReserveCodexNeedsAsk(id) then
		if frame then frame.resCodexAsk, frame.resConfirm, frame.resNick = id, nil, nil end
		self:RefreshJournal()
		return "ask"
	end
	if frame then frame.resCodexAsk = nil end
	return self:ReserveToCodex(id)
end

-- ---------------------------------------------------------------------------
-- Une puce de filtre (à cocher, avec son compteur)
-- ---------------------------------------------------------------------------
local function NewChip(parent, onClick)
	local chip = CreateFrame("Button", nil, parent)
	chip:SetSize(40, B.chipH)
	chip.bg = Theme.Solid(chip, "BACKGROUND", Theme.SELECT, 0)
	chip.bg:SetAllPoints()
	chip.border = Theme.Border(chip, Theme.EDGE_SOFT, 1)
	chip.text = Theme.Text(chip, Theme.F_SMALL, Theme.MUTED_LIGHT)
	chip.text:SetPoint("LEFT", chip, "LEFT", 7, 0)
	if chip.text.SetWordWrap then chip.text:SetWordWrap(false) end
	chip.count = Theme.Text(chip, Theme.F_SMALL, Theme.MUTED)
	chip.count:SetPoint("RIGHT", chip, "RIGHT", -6, 0)
	chip:SetScript("OnClick", onClick)
	chip:SetScript("OnEnter", function(self) self.hovered = true; ns.ReserveChipPaint(self) end)
	chip:SetScript("OnLeave", function(self) self.hovered = false; ns.ReserveChipPaint(self) end)
	return chip
end

function ns.ReserveChipPaint(chip, label, count, on)
	if label ~= nil then
		chip.label, chip.n, chip.on = label, count, on and true or false
		chip.text:SetText(label)
		chip.count:SetText(count and tostring(count) or "")
		local w = math.ceil(Theme.TextWidth(chip, label, Theme.F_SMALL)) + 14
		if count then w = w + math.ceil(Theme.TextWidth(chip, tostring(count), Theme.F_SMALL)) + 6 end
		chip:SetWidth(w)
	end
	local edge = chip.on and Theme.SELECT_LIGHT or (chip.hovered and Theme.EDGE or Theme.EDGE_SOFT)
	chip.border:SetColor(edge[1], edge[2], edge[3], 1)
	chip.bg:SetVertexColor(Theme.SELECT[1], Theme.SELECT[2], Theme.SELECT[3], chip.on and 0.22 or 0)
	local empty = (chip.n == 0) and not chip.on
	Paint(chip.text, chip.on and Theme.PARCHMENT or (empty and Theme.MUTED or (chip.hovered and Theme.LABEL or Theme.MUTED_LIGHT)))
	Paint(chip.count, chip.on and Theme.LABEL or Theme.MUTED)
end

-- ---------------------------------------------------------------------------
-- La barre (rangées 1 et 2). opts.compact : recherche et Filtres seulement
-- (sélecteur d'échange) ; opts.width : largeur de la rangée
-- ---------------------------------------------------------------------------
function ns.ReserveBuildBar(frame, host, content, ui, key, x, y, opts)
	opts = opts or {}
	local At, Tip, HideTip = ui.At, ui.Tip, ui.HideTip
	local width = opts.width or ui.GRID_W
	local bar = { key = key, x = x, y = y, width = width, compact = opts.compact }
	bar.search = Theme.CreateSearchBox(host, B.search, L.RES_SEARCH, function(text) ns:ReserveSearch(text, key) end)
	At(bar.search, content, x, y)
	bar.filters = Theme.CreateButton(host, B.filters, "sm", L.RES_FILTERS, function()
		ns:ReservePanelOpen(not frame[key .. "Panel"], key)
	end, "outline")
	At(bar.filters, content, x + B.filtersX, y)
	if not opts.compact then
		bar.sort = Theme.CreateDropdown(host, B.sort, function(value) ns:ReserveSetSort(value) end, { listWidth = 150 })
		local sorts = {}
		for _, id in ipairs(ns.RESERVE_SORT_ORDER) do sorts[#sorts + 1] = { value = id, label = L["RES_SORT_" .. id] } end
		bar.sort:SetOptions(sorts)
		At(bar.sort, content, x + B.sortX, y)
		bar.dir = Theme.CreateIconButton(host, B.dir, ICON.down, function() ns:ReserveFlipSort() end)
		At(bar.dir, content, x + B.dirX, y)
		if bar.dir.HookScript then
			bar.dir:HookScript("OnEnter", function(b) Tip(b, b.tipText or "", {}) end)
			bar.dir:HookScript("OnLeave", HideTip)
		end
		bar.views = Theme.CreateDropdown(host, B.views, function(value) ns:ReserveSetView(value, key) end,
			{ listWidth = 190, maxRows = 8 })
		local setValue = bar.views.SetValue
		function bar.views:SetValue(value)
			setValue(self, value)
			self.text:SetText(L.RES_VIEWS)
		end
		At(bar.views, content, x + B.viewsX, y)
		-- rangée 2
		local y2 = y - B.rowStep
		bar.y2 = y2
		bar.pills = {}
		for index = 1, B.pills do
			local pill = NewChip(host, function(p) if p.group then ns:ReserveClearGroup(p.group, key) end end)
			pill:SetHeight(Theme.BUTTON_SIZES and Theme.BUTTON_SIZES.sm or 24)
			if pill.HookScript then
				pill:HookScript("OnEnter", function(p) Tip(p, p.label or "", { L.RES_PILL_TIP }) end)
				pill:HookScript("OnLeave", HideTip)
			end
			pill:Hide()
			bar.pills[index] = pill
		end
		bar.more = Theme.Text(host, Theme.F_SMALL, Theme.MUTED_LIGHT)
		bar.more:Hide()
		bar.clear = Theme.CreateButton(host, "auto", "sm", L.RES_CLEAR, function() ns:ReserveClearFilter(key) end, "outline")
		bar.clear:Hide()
		bar.select = Theme.CreateButton(host, "auto", "sm", L.RES_SELECT, function()
			if frame.resTidy then ns:ReserveSelectAll() else ns:ReserveSelectStart() end
		end, "outline")
		bar.select:SetPoint("TOPRIGHT", content, "TOPLEFT", ui.PAD + x + width, y2)
		if bar.select.HookScript then
			bar.select:HookScript("OnEnter", function(b) if not frame.resTidy then Tip(b, L.RES_SELECT, { L.RES_SELECT_TIP }) end end)
			bar.select:HookScript("OnLeave", HideTip)
		end
		bar.count = Theme.Text(host, Theme.F_SMALL, Theme.MUTED_LIGHT)
		bar.count:SetJustifyH("RIGHT")
		bar.count:SetPoint("RIGHT", bar.select, "LEFT", -10, 0)
		if bar.count.SetWordWrap then bar.count:SetWordWrap(false) end
	end
	return bar
end

-- le libellé d'un groupe actif : « Taille : Grand, Géant »
local function GroupText(self, f, group)
	local set = f.sets and f.sets[group]
	if not set then return nil end
	local parts = {}
	for _, value in ipairs(self:ReserveFilterValues(group)) do
		if set[value] then parts[#parts + 1] = self:ReserveFilterLabel(group, value) end
	end
	for value in pairs(set) do
		local known = false
		for _, v in ipairs(self:ReserveFilterValues(group)) do if v == value then known = true end end
		if not known then parts[#parts + 1] = self:ReserveFilterLabel(group, value) end
	end
	if #parts == 0 then return nil end
	return self:F("RES_PILL", L["RES_FG_" .. group] or group, table.concat(parts, ", "))
end

-- la pastille : le texte coupé à pillMax
local function FitPill(pill, text, max)
	pill.text:SetWidth(0)
	ns.ReserveChipPaint(pill, text, nil, true)
	if pill:GetWidth() > max then
		pill:SetWidth(max)
		pill.text:SetWidth(max - 14)
	end
end

function ns:ReserveBarRefresh(bar, frame)
	local key = bar.key
	local f = self:ReserveBrowseFilter(key)
	local active = self:ReserveFilterActive(f) - ((f.q and f.q ~= "") and 1 or 0)
	bar.filters:SetText(active > 0 and self:F("RES_FILTERS_N", active) or L.RES_FILTERS)
	if bar.search and (bar.search:GetText() or "") ~= (f.q or "") and not (bar.search.HasFocus and bar.search:HasFocus()) then
		bar.search:SetText(f.q or "")
	end
	if bar.compact then return end
	local sort = frame.resSort or "stars"
	bar.sort:SetValue(sort)
	local desc = frame.resDesc
	if desc == nil then desc = sort ~= "name" end
	bar.dir.icon:SetTexture(desc and ICON.down or ICON.up)
	bar.dir.tipText = desc and L.RES_DIR_DESC or L.RES_DIR_ASC
	local views, mine = {}, self:CaptureData().resMyView
	for _, id in ipairs(ns.RESERVE_VIEW_ORDER) do
		views[#views + 1] = { value = id, label = L["RES_VIEW2_" .. id], disabled = id == "mine" and type(mine) ~= "table" or nil }
	end
	bar.views:SetOptions(views)
	bar.views:SetValue(frame[key .. "ViewId"])
	-- rangée 2 : pastilles des groupes actifs, puis « +n » et « Effacer »
	local groups = {}
	for _, group in ipairs(ns.RESERVE_FILTER_GROUPS) do
		local text = GroupText(self, f, group)
		if text then groups[#groups + 1] = { group = group, text = text } end
	end
	local x = 0
	local At = UI().At
	for index, pill in ipairs(bar.pills) do
		local item = groups[index]
		if item then
			pill.group = item.group
			FitPill(pill, item.text, B.pillMax)
			pill:ClearAllPoints()
			At(pill, bar.content or pill:GetParent(), bar.x + x, bar.y2)
			pill:Show()
			x = x + math.ceil(pill:GetWidth()) + 6
		else
			pill.group = nil
			pill:Hide()
		end
	end
	if #groups > #bar.pills then
		bar.more:SetText(self:F("RES_PILL_MORE", #groups - #bar.pills))
		bar.more:ClearAllPoints()
		At(bar.more, bar.content, bar.x + x, bar.y2 - 5)
		bar.more:Show()
		x = x + math.ceil(Theme.TextWidth(bar.more, bar.more:GetText(), Theme.F_SMALL)) + 8
	else
		bar.more:Hide()
	end
	if #groups > 0 or (f.q and f.q ~= "") then
		bar.clear:ClearAllPoints()
		At(bar.clear, bar.content, bar.x + x, bar.y2)
		bar.clear:Show()
	else
		bar.clear:Hide()
	end
	-- le compte (rouge près de la limite) et « Sélection » / « Tout (n) »
	local count, capacity = self:SpecimenReserveCount(), self:ReserveCapacity()
	local full, near = self:ReserveFull(), self.ReserveNearFull and self:ReserveNearFull()
	bar.count:SetText(self:F(full and "RES_COUNT_FULL" or (near and "RES_COUNT_NEAR" or "RES_COUNT"), count, capacity))
	Paint(bar.count, (full or near) and Theme.RED or Theme.MUTED_LIGHT)
	bar.select:SetText(frame.resTidy and self:F("RES_SELECT_ALL", #(frame.resList or {})) or L.RES_SELECT)
end

-- ---------------------------------------------------------------------------
-- Le panneau de filtres (posé sur la grille, modal)
-- ---------------------------------------------------------------------------
-- rangées : groupes à gauche (le premier donne le titre de la rangée)
ns.RESERVE_PANEL_ROWS = {
	{ "stars", "version" }, { "size" }, { "trait" }, { "type" }, { "rank", "zone" }, { "age" }, { "bond" }, { "state" },
}

local function ValueLabel(self, group, value) return self:ReserveFilterLabel(group, value) end

function ns.ReserveBuildPanel(frame, host, content, ui, key, x, y, w, h)
	local At = ui.At
	local panel = ui.Panel and ui.Panel(host, w, h) or CreateFrame("Frame", nil, host)
	panel:SetSize(w, h)
	At(panel, content, x, y)
	if panel.EnableMouse then panel:EnableMouse(true) end
	if panel.SetFrameLevel and host.GetFrameLevel then panel:SetFrameLevel((host:GetFrameLevel() or 1) + 20) end
	panel.key, panel.w, panel.h = key, w, h
	panel.labels, panel.chips = {}, {}
	for index, row in ipairs(ns.RESERVE_PANEL_ROWS) do
		local label = Theme.Text(panel, Theme.F_SMALL, Theme.IDENTITY)
		if label.SetWordWrap then label:SetWordWrap(false) end
		label:SetWidth(B.labelW - 6)
		label:SetText(L["RES_FG_" .. row[1]] or row[1])
		panel.labels[index] = label
		for _, group in ipairs(row) do
			if group == "zone" then
				panel.zone = Theme.CreateDropdown(panel, 150, function(value)
					local f = ns:ReserveBrowseFilter(key)
					f.sets.zone = (value ~= "any") and { [value] = true } or nil
					Changed(ns, key)
				end, { listWidth = 220, maxRows = 10, height = B.chipH })
			else
				panel.chips[group] = {}
			end
		end
	end
	-- pied : compte, Ma vue, Effacer, Voir
	panel.count = Theme.Text(panel, Theme.F_SMALL, Theme.MUTED_LIGHT)
	panel.count:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", B.pad, B.pad + 5)
	panel.show = Theme.CreateButton(panel, "auto", "sm", L.RES_PANEL_SHOW, function() ns:ReservePanelOpen(false, key) end, "primary")
	panel.show:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -B.pad, B.pad)
	panel.clear = Theme.CreateButton(panel, "auto", "sm", L.RES_CLEAR, function() ns:ReserveClearFilter(key) end, "outline")
	panel.clear:SetPoint("RIGHT", panel.show, "LEFT", -6, 0)
	if key == "res" then
		panel.save = Theme.CreateButton(panel, "auto", "sm", L.RES_PANEL_SAVE, function()
			ns:ReserveSaveMyView(ns:ReserveBrowseFilter(key))
			ns:Print(L.RES_PANEL_SAVED)
			ns:RefreshJournal()
		end, "outline")
		panel.save:SetPoint("RIGHT", panel.clear, "LEFT", -6, 0)
	end
	panel:Hide()
	return panel
end

local function ChipFor(panel, group, index)
	local list = panel.chips[group]
	local chip = list[index]
	if not chip then
		chip = NewChip(panel, function(c) ns:ReserveToggleFilter(c.group, c.value, panel.key) end)
		chip.group = group
		list[index] = chip
	end
	return chip
end

-- les valeurs présentes dans la Réserve (types, caractères : les absents se taisent)
local SPARSE = { type = true, trait = true }

function ns:ReservePanelRefresh(panel)
	local key = panel.key
	local f = self:ReserveBrowseFilter(key)
	local counts = self:ReserveFacetCounts(f, "reserve")
	local present = self:ReserveFacetCounts(self:ReserveFilterNew(), "reserve")
	local left, top = B.pad, -B.pad
	local right = panel.w - B.pad
	local bottom = -(panel.h - B.pad - B.footerH)
	local y = top
	for index, row in ipairs(ns.RESERVE_PANEL_ROWS) do
		local label = panel.labels[index]
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", panel, "TOPLEFT", left, y - 4)
		local x = left + B.labelW
		local rowTop = y
		local any = false
		for _, group in ipairs(row) do
			if group == "zone" then
				local options = { { value = "any", label = L.RES_FV_zone_any } }
				for _, zone in ipairs(self:ReserveFilterValues("zone")) do
					options[#options + 1] = { value = zone, label = self:ReserveZoneName(zone), hint = tostring(counts.zone and counts.zone[zone] or 0) }
				end
				panel.zone:SetOptions(options)
				local chosen = f.sets.zone and next(f.sets.zone)
				panel.zone:SetValue(chosen or "any")
				if x + 150 > right then x = left + B.labelW; y = y - B.chipH - B.rowGap end
				panel.zone:ClearAllPoints()
				panel.zone:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
				panel.zone.rowY = y
				any = true
				if -y + B.chipH > -bottom then panel.zone:Hide() else panel.zone:Show() end
				x = x + 150 + B.chipGap
			else
				local set = f.sets[group]
				local shown = 0
				for _, value in ipairs(self:ReserveFilterValues(group)) do
					local n = counts[group] and counts[group][value] or 0
					local on = set and set[value] or false
					local have = present[group] and present[group][value] or 0
					if not SPARSE[group] or have > 0 or on then
						shown = shown + 1
						any = true
						local chip = ChipFor(panel, group, shown)
						chip.value = value
						ns.ReserveChipPaint(chip, ValueLabel(self, group, value), n, on)
						local cw = math.ceil(chip:GetWidth())
						if x + cw > right and x > left + B.labelW then x = left + B.labelW; y = y - B.chipH - B.rowGap end
						chip:ClearAllPoints()
						chip:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
						chip.rowY = y
						-- plus de place : la puce attend (rien ne déborde du panneau)
						if -y + B.chipH > -bottom then chip:Hide() else chip:Show() end
						x = x + cw + B.chipGap
					end
				end
				for index2 = shown + 1, #panel.chips[group] do panel.chips[group][index2]:Hide() end
			end
		end
		-- une rangée sans puce (aucun type connu…) se tait
		if any then
			y = y - B.chipH - B.rowGap - 2
			if -rowTop + 14 > -bottom then label:Hide() else label:Show() end
		else
			label:Hide()
		end
	end
	panel.used = -y
	local list = self:ReserveBrowseList(key)
	panel.count:SetText(self:F("RES_PANEL_COUNT", #list))
	Enable(panel.clear, self:ReserveFilterActive(f) > 0)
	if panel.save then Enable(panel.save, self:ReserveFilterActive(f) - ((f.q and f.q ~= "") and 1 or 0) > 0) end
end

-- ---------------------------------------------------------------------------
-- Vignettes : cadenas, flèche « meilleur », crans du lien, coche
-- ---------------------------------------------------------------------------
local function Badge(tile, texture, size)
	local tex = tile:CreateTexture(nil, "OVERLAY", nil, 6)
	tex:SetSize(size, size)
	tex:SetTexture(texture)
	tex:Hide()
	return tex
end

function ns.ReserveTileExtras(tile)
	if tile.lock then return tile end
	tile.lock = Badge(tile, ICON.lock, 14)
	tile.better = Badge(tile, ICON.better, 14)
	if tile.better.SetDesaturated then tile.better:SetDesaturated(true) end
	tile.better:SetVertexColor(Theme.GREEN[1], Theme.GREEN[2], Theme.GREEN[3], 1)
	tile.check = Badge(tile, ICON.check, 20)
	tile.check:SetPoint("BOTTOMRIGHT", tile, "TOPRIGHT", -1, -50)
	tile.pips = {}
	local pw, gap = 8, 2
	local x0 = math.floor((ns.RESERVE_LAYOUT.tileW - (4 * pw + 3 * gap)) / 2)
	for index = 1, 4 do
		local pip = Theme.Solid(tile, "OVERLAY", Theme.GREEN, 1)
		if pip.SetDrawLayer then pip:SetDrawLayer("OVERLAY", 6) end
		pip:SetSize(pw, 3)
		pip:SetPoint("TOPLEFT", tile, "TOPLEFT", x0 + (index - 1) * (pw + gap), -49)
		pip:Hide()
		tile.pips[index] = pip
	end
	return tile
end

-- spec : un spécimen à soi (avec id) ; ailleurs (offre reçue) : rien
function ns:ReserveTilePaintExtras(tile, spec, selected)
	if not tile.lock then return end
	local mine = type(spec) == "table" and spec.id ~= nil and self:SpecimenGet(spec.id) == spec
	local locked = mine and self:SpecimenProtected(spec.id)
	local better = mine and self:SpecimenBetterThanCodex(spec.id)
	tile.lock:ClearAllPoints()
	tile.lock:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -3, spec and spec.shiny and -20 or -4)
	if locked then tile.lock:Show() else tile.lock:Hide() end
	tile.better:ClearAllPoints()
	local sizeShown = tile.sizeBack and tile.sizeBack.IsShown and tile.sizeBack:IsShown()
	tile.better:SetPoint("TOPLEFT", tile, "TOPLEFT", 3, sizeShown and -17 or -4)
	if better then tile.better:Show() else tile.better:Hide() end
	local level = mine and self.SpecimenBondLevel and self:SpecimenBondLevel(spec) or 1
	for index, pip in ipairs(tile.pips) do
		if index <= level - 1 then pip:Show() else pip:Hide() end
	end
	if selected then tile.check:Show() else tile.check:Hide() end
end

-- ---------------------------------------------------------------------------
-- Commandes de la semaine (ShopWeek.lua) : « Livrer » ouvre la Réserve filtrée
-- ---------------------------------------------------------------------------
function ns:ShopOrderOpen(index)
	local orders = self.ShopOrders and self:ShopOrders()
	local order = orders and orders.list[index]
	if not order or order.done then return false end
	local frame = self:EnsureJournalWindow()
	if not frame then return false end
	frame.resTidy, frame.resTidyOrder, frame.resPanel = nil, nil, nil
	frame.resFilter, frame.resViewId, frame.resOrder, frame.resOffset = self:ShopOrderFilter(order), nil, index, 0
	frame.resView = "reserve"
	self:OpenReserve("reserve")
	self:RefreshJournal()
	return true
end

function ns:ReserveDeliver(id)
	local frame = self.journalFrame
	local index = frame and frame.resOrder
	if not index then return false, "none" end
	local ok, why = self:ShopOrderDeliver(index, id)
	if ok then
		frame.resOrder, frame.resPick = nil, nil
		frame.resFilter, frame.resViewId = self:ReserveFilterNew(), nil
	end
	self:RefreshJournal()
	return ok, why
end

-- la recherche lâche le clavier en entrant en combat
do
	local watcher = CreateFrame("Frame")
	if watcher.RegisterEvent then pcall(watcher.RegisterEvent, watcher, "PLAYER_REGEN_DISABLED") end
	watcher:SetScript("OnEvent", function()
		local frame = ns.journalFrame
		for _, view in ipairs({ "reserve", "trade" }) do
			local bar = frame and frame.res and frame.res[view] and frame.res[view].bar
			if bar and bar.search and bar.search.ClearFocus then bar.search:ClearFocus() end
		end
	end)
end

if ns.Mark then ns.Mark("ReserveBrowse") end
