-- JournalReserve.lua -- la Réserve et l'Échoppe du dresseur (QuestCompanion 2.15.0)
--
-- 2.15.0 : chaque capture est un spécimen (CaptureSpecimens.lua) ; le
-- meilleur de chaque espèce reste au Codex, les autres vont à la RÉSERVE.
-- Une page du carnet, deux vues (puces en haut) :
--   * Réserve : « Réserve · n / places » et le solde de paillettes ; tri
--     (qualité, date, nom), filtre (espèce, brillants) ; la grille des
--     spécimens en vignettes de l'allure (CompanionAllure.lua : portrait 2D,
--     sinon petit modèle 3D), étoiles et perle des brillants ; la fiche du
--     spécimen choisi : étoiles, « Capturé par X · zone · date » (« Avant la
--     2.15 » pour la migration), « Meilleur que ton spécimen du Codex » ;
--     Mettre au Codex, Relâcher (+n paillettes, confirmation dans la page,
--     jamais de fenêtre), Localiser l'espèce (ZoneQuests.lua). Réserve pleine :
--     le dire.
--   * Échoppe du dresseur : dépenser les paillettes (ns.PAILLETTES_SHOP) :
--     aides de capture (dans la limite de la besace), places de Réserve, et
--     deux cosmétiques du compagnon (FeatsCosmetics.lua, pour tout le compte).
--     Confirmation dans la ligne, une ligne dans le chat à l'achat.
-- Et quelques paillettes en récompense : paliers de zone (ici) et missions
-- (Daily.lua, ns.MISSION_REWARDS).
-- Page externe du carnet : ns.JOURNAL_PANES.reserve (JournalWindow.lua) ;
-- habit Azeroth : PAGE.reserve / POST.reserve (JournalAzeroth.lua), encres
-- « reserve.* », « shop.* » (AzerothStyle.lua). Tout est construit une fois
-- (vignettes, lignes de l'échoppe) puis repeint.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

-- ---------------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------------
-- la paillette : l'icône du diamant du client (relevée dans le listfile de Forever)
ns.PAILLETTES_ICON = "Interface\\Icons\\INV_Misc_Gem_Diamond_02"
-- l'échoppe : prix en paillettes (à équilibrer)
ns.PAILLETTES_SHOP = {
	{ id = "appat",   kind = "aid", aid = "appat",   price = 5,  icon = "Interface\\Icons\\INV_Misc_Food_14" },
	{ id = "lasso",   kind = "aid", aid = "lasso",   price = 15, icon = "Interface\\Icons\\Spell_Nature_StrangleVines" },
	{ id = "sifflet", kind = "aid", aid = "sifflet", price = 40, icon = "Interface\\Icons\\INV_Misc_Horn_01" },
	{ id = "slots",   kind = "slots", slots = 5,     price = 50, icon = "Interface\\Icons\\INV_Misc_Bag_10" },
	{ id = "frame_glitter", kind = "cosmetic", cos = "frame", cosId = "shop_glitter", price = 80,
		icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_02" },
	{ id = "bg_starfall",   kind = "cosmetic", cos = "bg",    cosId = "shop_starfall", price = 60,
		icon = "Interface\\Icons\\INV_Enchant_PrismaticSphere" },
}
-- paillettes d'un palier de zone (25, 50, 75 %) ; celles des missions sont
-- dans ns.MISSION_REWARDS (Daily.lua)
ns.PAILLETTES_MILESTONE = 2
ns.RESERVE_SORTS = { "stars", "date", "name" }
ns.RESERVE_SHOWS = { "all", "shiny" }
ns.RESERVE_VIEWS = { "reserve", "shop" }
-- grille : vignettes de l'allure, un peu plus hautes (étoiles sous le portrait)
ns.RESERVE_LAYOUT = { tileW = 58, tileH = 84, gap = 7, portrait = 46, star = 10, starStep = 11, starY = -55,
	shopH = 50, shopGap = 6, shopIcon = 34, shopButton = 104, actionH = 22, actionGap = 4 }
local LAY = ns.RESERVE_LAYOUT

local FR = {
	JRN_SEC_reserve      = "Réserve",
	JRN_SUB_reserve      = "Tes spécimens en plus du Codex : garde, échange de place avec le Codex, relâche contre des paillettes.",
	RES_VIEW_reserve     = "Réserve",
	RES_VIEW_shop        = "Échoppe du dresseur",
	RES_TITLE            = "Réserve · %d / %d",
	RES_SHOP_TITLE       = "Échoppe du dresseur",
	RES_SHOP_SUB         = "Dépense tes paillettes : aides de capture, places de Réserve, allure du compagnon.",
	RES_BALANCE          = "%s %d paillettes",
	RES_SORT_stars       = "Tri : qualité",
	RES_SORT_date        = "Tri : date",
	RES_SORT_name        = "Tri : nom",
	RES_SHOW_all         = "Tous",
	RES_SHOW_shiny       = "Brillants",
	RES_SPECIES_ALL      = "Toutes les espèces",
	RES_FULL             = "Réserve pleine (%d/%d) : relâche des spécimens ou ajoute des places à l'Échoppe.",
	RES_HINT             = "Clic sur un spécimen : sa fiche. Le meilleur de chaque espèce reste au Codex.",
	RES_EMPTY            = "Ta Réserve est vide : les spécimens moins bons que ceux de ton Codex y arrivent.",
	RES_EMPTY_FILTER     = "Aucun spécimen ne correspond à ce filtre.",
	RES_PICK             = "Choisis un spécimen dans la grille.",
	RES_BY               = "Capturé par %s",
	RES_BY_MIGRATION     = "Avant la 2.15",
	RES_BETTER           = "Meilleur que ton spécimen du Codex (%s)",
	RES_CODEX_REF        = "Au Codex : %s",
	RES_VALUE            = "Relâcher : +%d paillettes",
	RES_TO_CODEX         = "Mettre au Codex",
	RES_TO_CODEX_TIP     = "Il devient ton spécimen de référence (et une apparence possible) ; l'ancien passe en Réserve.",
	RES_RELEASE          = "Relâcher (+%d %s)",
	RES_LOCATE           = "Localiser l'espèce",
	RES_LOCATE_OFF       = "Effacer le repère",
	RES_LOCATE_NONE      = "Pas de point connu pour cette espèce.",
	RES_CONFIRM          = "Relâcher %s ? +%d paillettes, il quitte ta Réserve pour de bon.",
	RES_CONFIRM_YES      = "Relâcher",
	RES_CONFIRM_NO       = "Annuler",
	RES_WHY_better       = "Mets-le au Codex avant de le relâcher.",
	RES_WHY_worn         = "Ton compagnon porte cette apparence.",
	RES_WHY_reference    = "C'est ton spécimen du Codex.",
	RES_WHY_missing      = "Ce spécimen n'existe plus.",
	SHOP_BUY             = "Acheter",
	SHOP_CONFIRM         = "Confirmer",
	SHOP_CANCEL          = "Annuler",
	SHOP_OWNED           = "Acquis",
	SHOP_PRICE           = "%d %s",
	SHOP_SHORT           = "Il te manque %d paillettes.",
	SHOP_FULL            = "Besace pleine (%d/%d) : utilise-en d'abord.",
	SHOP_OWNED_TIP       = "Déjà à toi.",
	SHOP_OFF             = "La capture est coupée dans les réglages.",
	SHOP_AID_HAVE        = "%s Dans ta besace : %d / %d.",
	SHOP_SLOTS           = "+%d places de Réserve",
	SHOP_SLOTS_DESC      = "Ta Réserve compte %d places.",
	SHOP_COS_frame       = "Cadre du compagnon, pour tous tes personnages.",
	SHOP_COS_bg          = "Fond du compagnon, pour tous tes personnages.",
	SHOP_NOTE            = "Gagner des paillettes : relâcher des spécimens (1 / 3 / 8, brillant 20), les missions (3 par mission du jour, plus aux trois et à la semaine), les paliers de zone (2).",
	SHOP_BOUGHT          = "Échoppe du dresseur : %s (−%d paillettes, reste %d).",
	SHOP_REQ             = "Échoppe du dresseur : %d paillettes",
	PAILLETTES_MILESTONE_GAIN = "+%d paillettes : palier de zone (%d %%).",
}
local EN = {
	JRN_SEC_reserve      = "Reserve",
	JRN_SUB_reserve      = "Your specimens beyond the Codex: keep them, swap with the Codex, release them for glitter.",
	RES_VIEW_reserve     = "Reserve",
	RES_VIEW_shop        = "Trainer's Stall",
	RES_TITLE            = "Reserve · %d / %d",
	RES_SHOP_TITLE       = "Trainer's Stall",
	RES_SHOP_SUB         = "Spend your glitter: capture aids, Reserve slots, your companion's look.",
	RES_BALANCE          = "%s %d glitter",
	RES_SORT_stars       = "Sort: quality",
	RES_SORT_date        = "Sort: date",
	RES_SORT_name        = "Sort: name",
	RES_SHOW_all         = "All",
	RES_SHOW_shiny       = "Shiny",
	RES_SPECIES_ALL      = "Every species",
	RES_FULL             = "Reserve full (%d/%d): release specimens or add slots at the Stall.",
	RES_HINT             = "Click a specimen: its card. The best of each species stays in the Codex.",
	RES_EMPTY            = "Your Reserve is empty: specimens weaker than your Codex ones land here.",
	RES_EMPTY_FILTER     = "No specimen matches this filter.",
	RES_PICK             = "Pick a specimen in the grid.",
	RES_BY               = "Captured by %s",
	RES_BY_MIGRATION     = "Before 2.15",
	RES_BETTER           = "Better than your Codex specimen (%s)",
	RES_CODEX_REF        = "In the Codex: %s",
	RES_VALUE            = "Release: +%d glitter",
	RES_TO_CODEX         = "Put in the Codex",
	RES_TO_CODEX_TIP     = "It becomes your reference specimen (and a possible look); the old one goes to the Reserve.",
	RES_RELEASE          = "Release (+%d %s)",
	RES_LOCATE           = "Locate the species",
	RES_LOCATE_OFF       = "Clear the pin",
	RES_LOCATE_NONE      = "No known spot for this species.",
	RES_CONFIRM          = "Release %s? +%d glitter, it leaves your Reserve for good.",
	RES_CONFIRM_YES      = "Release",
	RES_CONFIRM_NO       = "Cancel",
	RES_WHY_better       = "Put it in the Codex before releasing it.",
	RES_WHY_worn         = "Your companion wears this look.",
	RES_WHY_reference    = "It's your Codex specimen.",
	RES_WHY_missing      = "This specimen no longer exists.",
	SHOP_BUY             = "Buy",
	SHOP_CONFIRM         = "Confirm",
	SHOP_CANCEL          = "Cancel",
	SHOP_OWNED           = "Owned",
	SHOP_PRICE           = "%d %s",
	SHOP_SHORT           = "You need %d more glitter.",
	SHOP_FULL            = "Bag full (%d/%d): use some first.",
	SHOP_OWNED_TIP       = "Already yours.",
	SHOP_OFF             = "Capture is turned off in the settings.",
	SHOP_AID_HAVE        = "%s In your bag: %d / %d.",
	SHOP_SLOTS           = "+%d Reserve slots",
	SHOP_SLOTS_DESC      = "Your Reserve has %d slots.",
	SHOP_COS_frame       = "Companion frame, for all your characters.",
	SHOP_COS_bg          = "Companion background, for all your characters.",
	SHOP_NOTE            = "Earning glitter: release specimens (1 / 3 / 8, shiny 20), missions (3 per daily mission, more for all three and weekly ones), zone milestones (2).",
	SHOP_BOUGHT          = "Trainer's Stall: %s (−%d glitter, %d left).",
	SHOP_REQ             = "Trainer's Stall: %d glitter",
	PAILLETTES_MILESTONE_GAIN = "+%d glitter: zone milestone (%d%%).",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.RESERVE_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function UI() return ns.JournalUI or {} end
-- Un bouton actif ou non, et pourquoi (infobulle du bouton grisé, Theme.lua)
local function Enable(button, on, why)
	on = on and true or false
	if button.SetEnabled then button:SetEnabled(on) end
	button.qcEnabled = on
	button.disabledTip = (not on) and why or nil
end
local function CaptureOn() return ns:DB().companionCapture ~= false end

-- La paillette en ligne de texte (icône du client), taille en pixels
function ns.PaillettesGlyph(size)
	size = tonumber(size) or 12
	return string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", ns.PAILLETTES_ICON, size, size)
end

-- ---------------------------------------------------------------------------
-- L'échoppe
-- ---------------------------------------------------------------------------
local SHOP_BY_ID = {}
for _, item in ipairs(ns.PAILLETTES_SHOP) do SHOP_BY_ID[item.id] = item end
function ns:ShopItem(id) return SHOP_BY_ID[id or ""] end

-- Le prix d'un cosmétique de l'échoppe (FeatsCosmetics.lua : condition affichée)
function ns:ShopCosmeticPrice(cosId)
	for _, item in ipairs(ns.PAILLETTES_SHOP) do
		if item.kind == "cosmetic" and item.cosId == cosId then return item.price end
	end
	return nil
end

local function AidDef(id)
	for _, def in ipairs(ns.CAPTURE_AIDS or {}) do if def.id == id then return def end end
	return nil
end

-- Le cosmétique d'un article : sa définition dans la liste du compagnon
local COS_LIST = { frame = "COMPANION_FRAMES", bg = "COMPANION_BACKGROUNDS" }
local function CosmeticDef(item)
	for _, def in ipairs(ns[COS_LIST[item.cos or ""] or ""] or {}) do
		if def.id == item.cosId then return def end
	end
	return nil
end

-- Nom d'un article, en clair
function ns:ShopLabel(item)
	if type(item) ~= "table" then item = self:ShopItem(item) end
	if not item then return "" end
	if item.kind == "aid" then return self:CaptureAidLabel(item.aid) end
	if item.kind == "slots" then return self:F("SHOP_SLOTS", item.slots) end
	local def = CosmeticDef(item)
	return def and tostring(L[def.label]) or item.id
end

-- Peut-on l'acheter ? "ok", ou "short" (manque n), "full" (besace : n, cap),
-- "owned", "off" (capture coupée), "unknown"
function ns:ShopState(item)
	if type(item) ~= "table" then item = self:ShopItem(item) end
	if not item then return "unknown" end
	if item.kind == "aid" then
		if not CaptureOn() then return "off" end
		local def = AidDef(item.aid)
		local have = self:CaptureAidCount(item.aid)
		if def and have >= def.cap then return "full", have, def.cap end
	elseif item.kind == "cosmetic" then
		if self.ShopCosmeticOwned and self:ShopCosmeticOwned(item.cosId) then return "owned" end
		if not CosmeticDef(item) then return "unknown" end
	end
	local balance = self:Paillettes()
	if balance < item.price then return "short", item.price - balance end
	return "ok"
end

-- Achat : true, solde | false, raison (comme ns:ShopState)
function ns:ShopBuy(id)
	local item = self:ShopItem(id)
	local state = self:ShopState(item)
	if state ~= "ok" then return false, state end
	local paid, left = self:PaillettesSpend(item.price, "shop:" .. item.id)
	if not paid then return false, "short" end
	if item.kind == "aid" then
		self:CaptureGrant(item.aid, { quiet = true, silent = true })
	elseif item.kind == "slots" then
		self:ReserveAddSlots(item.slots)
	elseif item.kind == "cosmetic" then
		self:ShopCosmeticGrant(item.cosId)
		if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	end
	self:Print(self:F("SHOP_BOUGHT", self:ShopLabel(item), item.price, left))
	return true, left
end

-- ---------------------------------------------------------------------------
-- Réserve : actions (la page et les tests passent par ici)
-- ---------------------------------------------------------------------------
-- « Mettre au Codex » : l'ancienne référence passe en Réserve et devient le
-- spécimen choisi (l'échange se voit). Rend true, id de l'ancienne | false, raison
function ns:ReserveToCodex(id)
	local spec = self:SpecimenGet(id)
	if not spec then return false, "missing" end
	local old = self:SpecimenReference(spec.npc, spec.shiny)
	local ok, why = self:SpecimenSetReference(spec.id)
	if not ok then return false, why end
	local frame = self.journalFrame
	if frame then frame.resPick, frame.resConfirm = old and old.id or nil, nil end
	if self.CompanionApplyModel then pcall(self.CompanionApplyModel, self) end
	self:RefreshJournal()
	return true, old and old.id or nil
end

-- « Relâcher » : 1er appel, la confirmation s'ouvre dans la page ; 2e
-- (confirm = true) : relâché. Rend "ask" | gain | false, raison
function ns:ReserveRelease(id, confirm)
	local frame = self.journalFrame
	local ok, why = self:SpecimenCanRelease(id)
	if not ok then return false, why end
	if not confirm then
		if frame then frame.resConfirm = id end
		self:RefreshJournal()
		return "ask"
	end
	local list = frame and frame.resList
	local nextPick
	if list then
		for index, spec in ipairs(list) do
			if spec.id == id then nextPick = (list[index + 1] or list[index - 1] or {}).id end
		end
	end
	local gain, err = self:SpecimenRelease(id)
	if not gain then return false, err end
	if frame then frame.resPick, frame.resConfirm = nextPick, nil end
	self:RefreshJournal()
	return gain
end

function ns:ReserveCancelConfirm()
	local frame = self.journalFrame
	if frame then frame.resConfirm, frame.shopConfirm = nil, nil end
	self:RefreshJournal()
end

-- Les zones où chercher l'espèce d'un spécimen : la sienne d'abord, puis
-- celles du catalogue
function ns:SpecimenZones(spec)
	local zones = {}
	if spec and spec.zone then zones[1] = spec.zone end
	local catalog = self.MenagerieCatalog and self:MenagerieCatalog()
	local item = catalog and catalog.byNpc and spec and catalog.byNpc[spec.npc]
	for _, zoneID in ipairs(item and item.zones or {}) do
		if zoneID ~= spec.zone then zones[#zones + 1] = zoneID end
	end
	return zones
end

function ns:ReserveLocate(id)
	local spec = self:SpecimenGet(id)
	if not (spec and self.LocateSpecies) then return false end
	local set = self:LocateSpecies(spec.npc, self:SpecimenZones(spec))
	self:RefreshJournal()
	return set and true or false
end

-- Réserve filtrée et triée (filtre : npc, brillants) : table neuve
function ns:ReserveView(sort, npc, shinyOnly)
	return self:SpecimenList({ where = "reserve", sort = sort or "stars", npc = npc, shiny = shinyOnly and true or nil })
end

-- ---------------------------------------------------------------------------
-- Paillettes en récompense : paliers de zone (25, 50, 75 %), comme l'aide
-- de capture (Capture.lua). Les missions : Daily.lua.
-- ---------------------------------------------------------------------------
-- gained : les paliers que ns:TreatCheckZone vient de donner ({ mark }) ;
-- rend les paillettes gagnées
function ns:PaillettesOnMilestones(gained, opts)
	if type(gained) ~= "table" or #gained == 0 or not CaptureOn() or not self.PaillettesAdd then return 0 end
	local quiet = (opts and opts.quiet) or self:DB().journalChat ~= true
	local total = 0
	for _, gain in ipairs(gained) do
		if type(gain) == "table" and tonumber(gain.mark) then
			self:PaillettesAdd(ns.PAILLETTES_MILESTONE, "milestone")
			total = total + ns.PAILLETTES_MILESTONE
			if not quiet then self:Print(self:F("PAILLETTES_MILESTONE_GAIN", ns.PAILLETTES_MILESTONE, gain.mark)) end
		end
	end
	return total
end
do
	local check = ns.TreatCheckZone
	if check then
		function ns:TreatCheckZone(zoneID, opts, ...)
			local gained = check(self, zoneID, opts, ...)
			local ok, err = pcall(self.PaillettesOnMilestones, self, gained, opts)
			if not ok and self.RecordError then self:RecordError("paillettes:milestone", err) end
			return gained
		end
	end
end

-- ---------------------------------------------------------------------------
-- La page
-- ---------------------------------------------------------------------------
local function StarTex(tile, layer, sub, size)
	local tex = tile:CreateTexture(nil, layer, nil, sub)
	tex:SetSize(size, size)
	local atlas = ns.MEN_STAR and ns.MEN_STAR.atlas or "auctionhouse-icon-favorite"
	local ok = ns.AzerothAtlas and ns.AzerothAtlas(tex, atlas)
	if not ok then
		ok = pcall(tex.SetAtlas, tex, atlas)
		if not ok and ns.CAPTURE_STAR_ICON then tex:SetTexture(ns.CAPTURE_STAR_ICON) end
	end
	return tex
end

-- Trois étoiles sous le portrait d'une vignette (pleines : dorées)
local function BuildTileStars(tile)
	tile.stars = {}
	local x0 = math.floor((LAY.tileW - (2 * LAY.starStep + LAY.star)) / 2)
	for index = 1, (ns.CAPTURE_STAR_MAX or 3) do
		local star = StarTex(tile, "OVERLAY", 2, LAY.star)
		star:SetPoint("TOPLEFT", tile, "TOPLEFT", x0 + (index - 1) * LAY.starStep, LAY.starY)
		tile.stars[index] = star
	end
end
local function PaintTileStars(tile, count)
	local S = ns.MEN_STAR or { full = Theme.GOLD, empty = Theme.MUTED }
	for index, star in ipairs(tile.stars) do
		local full = index <= (count or 0)
		local c = full and S.full or S.empty
		if star.SetDesaturated then star:SetDesaturated(not full) end
		star:SetVertexColor(c[1], c[2], c[3], 1)
		star.full = full
		star:Show()
	end
end

local function Day(at)
	at = tonumber(at)
	local date = G("date")
	if not at or at <= 0 or type(date) ~= "function" then return nil end
	local ok, text = pcall(date, "%d/%m/%Y", at)
	return ok and text or nil
end

local function ZoneName(self, zoneID)
	local info = zoneID and self.MapInfo and self:MapInfo(zoneID)
	return info and info.name or nil
end

-- « Capturé par X · zone · date » (« Avant la 2.15 » pour la migration)
function ns:SpecimenOriginText(spec)
	if type(spec) ~= "table" then return "" end
	local parts = {}
	if spec.origin == "migration" then parts[1] = L.RES_BY_MIGRATION
	elseif spec.by then parts[1] = self:F("RES_BY", spec.by) end
	parts[#parts + 1] = ZoneName(self, spec.zone)
	parts[#parts + 1] = Day(spec.at)
	local out = {}
	for index = 1, 3 do if parts[index] then out[#out + 1] = parts[index] end end
	return table.concat(out, " · ")
end

local function Stars(self, n, size)
	return self.CaptureStarsText and self:CaptureStarsText(n, size or 12) or string.rep("*", n or 0)
end

local function Scroll(self, frame, delta)
	if frame.resView == "shop" then return end
	frame.resOffset = (frame.resOffset or 0) - (tonumber(delta) or 0)
end

local function Build(self, frame, content, ui)
	local At, Text, Tip, HideTip = ui.At, ui.Text, ui.Tip, ui.HideTip
	local TOP, INNER, PAGER_Y, PREVIEW_W, GRID_W = ui.TOP, ui.INNER, ui.PAGER_Y, ui.PREVIEW_W, ui.GRID_W
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.res = pane
	frame.resView = frame.resView or "reserve"
	frame.resSort, frame.resShow, frame.resOffset = frame.resSort or "stars", frame.resShow or "all", frame.resOffset or 0

	-- 1re rangée : la vue (Réserve, Échoppe), le solde à droite
	local views = {}
	for _, key in ipairs(ns.RESERVE_VIEWS) do views[#views + 1] = { id = key, label = L["RES_VIEW_" .. key] } end
	pane.views = Theme.CreateChips(pane, views, function(id)
		frame.resView, frame.resConfirm, frame.shopConfirm = id, nil, nil
		if ns.JournalRemember then ns:JournalRemember("resView", id) end
		ns:RefreshJournal()
	end)
	At(pane.views, content, 0, TOP)
	pane.balance = Text(pane, Theme.F_LABEL, Theme.GOLD, 220)
	pane.balance:SetPoint("TOPRIGHT", content, "TOPLEFT", ui.PAD + INNER, TOP - 4)
	pane.balance:SetJustifyH("RIGHT")

	-- ===== vue Réserve =====
	local rv = CreateFrame("Frame", nil, pane)
	rv:SetAllPoints()
	pane.reserve = rv
	local rowY = TOP - Theme.CHIP_HEIGHT - 10
	rv.sort = Theme.CreateDropdown(rv, 132, function(value)
		frame.resSort, frame.resOffset = value, 0
		if ns.JournalRemember then ns:JournalRemember("resSort", value) end
		ns:RefreshJournal()
	end)
	At(rv.sort, content, 0, rowY)
	local sorts = {}
	for _, key in ipairs(ns.RESERVE_SORTS) do sorts[#sorts + 1] = { value = key, label = L["RES_SORT_" .. key] } end
	rv.sort:SetOptions(sorts)
	rv.species = Theme.CreateDropdown(rv, 180, function(value)
		frame.resNpc, frame.resOffset = (value ~= "all") and value or nil, 0
		ns:RefreshJournal()
	end, { listWidth = 230, maxRows = 12 })
	At(rv.species, content, 142, rowY)
	local shows = {}
	for _, key in ipairs(ns.RESERVE_SHOWS) do shows[#shows + 1] = { id = key, label = L["RES_SHOW_" .. key] } end
	rv.show = Theme.CreateChips(rv, shows, function(id)
		frame.resShow, frame.resOffset = id, 0
		ns:RefreshJournal()
	end)
	At(rv.show, content, 332, rowY + 1)
	-- avertissement (Réserve pleine), au-dessus de la grille
	local warnY = rowY - 30
	rv.warn = Text(rv, Theme.F_SMALL, Theme.RED, GRID_W)
	At(rv.warn, content, 0, warnY)
	if rv.warn.SetWordWrap then rv.warn:SetWordWrap(false) end
	-- la grille : vignettes de l'allure, construites une fois
	local gridTop = warnY - 18
	local cols = math.floor((GRID_W + LAY.gap) / (LAY.tileW + LAY.gap))
	local rows = math.floor((gridTop - PAGER_Y - 8 + LAY.gap) / (LAY.tileH + LAY.gap))
	rv.cols, rv.rows = cols, rows
	rv.grid = CreateFrame("Frame", nil, rv)
	At(rv.grid, content, 0, gridTop)
	rv.grid:SetSize(GRID_W, rows * (LAY.tileH + LAY.gap))
	rv.tiles = {}
	for index = 1, cols * rows do
		local tile = ns.AllureNewTile(frame, rv.grid, { w = LAY.tileW, h = LAY.tileH, portrait = LAY.portrait })
		local slot = index - 1
		tile:ClearAllPoints()
		tile:SetPoint("TOPLEFT", rv.grid, "TOPLEFT", (slot % cols) * (LAY.tileW + LAY.gap), -math.floor(slot / cols) * (LAY.tileH + LAY.gap))
		BuildTileStars(tile)
		tile:SetScript("OnClick", function(t) ns:ReservePick(t.spec and t.spec.id) end)
		tile.onEnter = function(t) ns:ReserveTileTip(t) end
		tile.onLeave = HideTip
		tile:Hide()
		rv.tiles[index] = tile
	end
	rv.empty = Text(rv, Theme.F_BODY, Theme.MUTED_LIGHT, GRID_W - 20)
	At(rv.empty, content, 10, gridTop - 20)
	if rv.empty.SetWordWrap then rv.empty:SetWordWrap(true) end
	ui.Pager(rv, content)
	rv.hint:SetText(L.RES_HINT)

	-- la fiche du spécimen choisi, et ses trois boutons en bas
	local previewTop = rowY
	local previewH = previewTop - PAGER_Y - 12
	local p = ui.BuildPreview(rv, content, INNER - PREVIEW_W, previewTop, previewH)
	rv.preview = p
	local actionsH = 3 * (LAY.actionH + LAY.actionGap) + 8
	p.maxBottom = previewH - 10 - actionsH
	local bw = PREVIEW_W - 24
	rv.toCodex = Theme.CreateButton(p, bw, LAY.actionH, L.RES_TO_CODEX, function()
		if frame.resPick then ns:ReserveToCodex(frame.resPick) end
	end, "primary")
	rv.release = Theme.CreateButton(p, bw, LAY.actionH, "", function(b)
		if frame.resPick and b.qcEnabled ~= false then ns:ReserveRelease(frame.resPick) end
	end, "outline")
	rv.locate = Theme.CreateButton(p, bw, LAY.actionH, L.RES_LOCATE, function(b)
		if frame.resPick and b.qcEnabled ~= false then ns:ReserveLocate(frame.resPick) end
	end, "accent")
	local y = 8
	for _, button in ipairs({ rv.locate, rv.release, rv.toCodex }) do
		button:SetPoint("BOTTOM", p, "BOTTOM", 0, y)
		y = y + LAY.actionH + LAY.actionGap
	end
	if rv.toCodex.HookScript then
		rv.toCodex:HookScript("OnEnter", function(b) Tip(b, L.RES_TO_CODEX, { L.RES_TO_CODEX_TIP }) end)
		rv.toCodex:HookScript("OnLeave", HideTip)
	end
	-- confirmation dans la fiche (jamais de fenêtre) : texte et deux boutons
	rv.confirm = Text(p, Theme.F_SMALL, Theme.LABEL, PREVIEW_W - 28)
	rv.confirm:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 14, 8 + LAY.actionH + 8)
	if rv.confirm.SetWordWrap then rv.confirm:SetWordWrap(true) end
	local half = math.floor((bw - 6) / 2)
	rv.confirmYes = Theme.CreateButton(p, half, LAY.actionH, L.RES_CONFIRM_YES, function()
		if frame.resConfirm then ns:ReserveRelease(frame.resConfirm, true) end
	end, "primary")
	rv.confirmYes:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, 8)
	rv.confirmNo = Theme.CreateButton(p, half, LAY.actionH, L.RES_CONFIRM_NO, function() ns:ReserveCancelConfirm() end, "outline")
	rv.confirmNo:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -12, 8)

	-- ===== vue Échoppe =====
	local sv = CreateFrame("Frame", nil, pane)
	sv:SetAllPoints()
	pane.shop = sv
	sv.rows = {}
	local shopTop = TOP - Theme.CHIP_HEIGHT - 12
	for index, item in ipairs(ns.PAILLETTES_SHOP) do
		local row = Theme.CreateTile(sv, INNER, LAY.shopH, { kind = "Frame" })
		At(row, content, 0, shopTop - (index - 1) * (LAY.shopH + LAY.shopGap))
		row.item = item
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(LAY.shopIcon, LAY.shopIcon)
		row.icon:SetPoint("LEFT", row, "LEFT", 10, 0)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		pcall(row.icon.SetTexture, row.icon, item.icon)
		local textX = 10 + LAY.shopIcon + 10
		local textW = INNER - textX - LAY.shopButton - 90 - 24
		row.name = Text(row, Theme.F_LABEL, Theme.LABEL, textW)
		row.name:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -8)
		if row.name.SetWordWrap then row.name:SetWordWrap(false) end
		row.desc = Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT, textW)
		row.desc:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -26)
		if row.desc.SetWordWrap then row.desc:SetWordWrap(false) end
		row.price = Text(row, Theme.F_LABEL, Theme.GOLD, 84)
		row.price:SetPoint("RIGHT", row, "RIGHT", -(10 + LAY.shopButton + 10), 0)
		row.price:SetJustifyH("RIGHT")
		row.buy = Theme.CreateButton(row, LAY.shopButton, LAY.actionH, L.SHOP_BUY, function(b)
			if b.qcEnabled == false then return end
			frame.shopConfirm = b:GetParent().item.id
			ns:RefreshJournal()
		end, "primary")
		row.buy:SetPoint("RIGHT", row, "RIGHT", -10, 0)
		local small = math.floor((LAY.shopButton - 4) / 2)
		row.yes = Theme.CreateButton(row, small, LAY.actionH, L.SHOP_CONFIRM, function(b)
			frame.shopConfirm = nil
			ns:ShopBuy(b:GetParent().item.id)
			ns:RefreshJournal()
		end, "primary")
		row.no = Theme.CreateButton(row, small, LAY.actionH, L.SHOP_CANCEL, function() ns:ReserveCancelConfirm() end, "outline")
		row.no:SetPoint("RIGHT", row, "RIGHT", -10, 0)
		row.yes:SetPoint("RIGHT", row.no, "LEFT", -4, 0)
		sv.rows[index] = row
	end
	local noteY = shopTop - #ns.PAILLETTES_SHOP * (LAY.shopH + LAY.shopGap) - 6
	sv.note = Text(sv, Theme.F_SMALL, Theme.MUTED_LIGHT, INNER)
	At(sv.note, content, 0, noteY)
	if sv.note.SetWordWrap then sv.note:SetWordWrap(true) end
	sv.note:SetText(L.SHOP_NOTE)

	-- le carnet fermé : plus de confirmation en attente
	if frame.HookScript then
		frame:HookScript("OnHide", function(f)
			f.resConfirm, f.shopConfirm = nil, nil
			-- l'apprentissage des displayID s'arrête avec le carnet (comme l'allure)
			if ns.ModelLearnStop then ns:ModelLearnStop() end
		end)
	end
	pane:Hide()
end

-- Choisir un spécimen dans la grille
function ns:ReservePick(id)
	local frame = self.journalFrame
	if not (frame and id) then return end
	frame.resPick, frame.resConfirm = id, nil
	self:RefreshJournal()
end

function ns:ReserveTileTip(tile)
	local spec = tile and tile.spec
	if not spec then return end
	local lines = { Stars(self, spec.stars, 12), self:SpecimenOriginText(spec) }
	if self:SpecimenBetterThanCodex(spec.id) then
		local ref = self:SpecimenReference(spec.npc, spec.shiny)
		lines[#lines + 1] = self:F("RES_BETTER", Stars(self, ref and ref.stars or 1, 10))
	end
	local tip = UI().Tip
	if tip then tip(tile, self:SpecimenLabel(spec), lines) end
end

-- Les options du filtre d'espèce : les espèces présentes en Réserve
local function SpeciesOptions(self, all)
	local seen, options = {}, {}
	for _, spec in ipairs(all) do
		local item = seen[spec.npc]
		if not item then
			item = { value = spec.npc, label = self.CreatureName and self:CreatureName(spec.npc, { name = spec.name }) or tostring(spec.name or spec.npc), n = 0 }
			seen[spec.npc] = item
			options[#options + 1] = item
		end
		item.n = item.n + 1
	end
	table.sort(options, function(a, b)
		if a.label ~= b.label then return tostring(a.label) < tostring(b.label) end
		return tostring(a.value) < tostring(b.value)
	end)
	for _, option in ipairs(options) do option.hint = tostring(option.n) end
	table.insert(options, 1, { value = "all", label = L.RES_SPECIES_ALL })
	return options, seen
end

local WHY = { better = "RES_WHY_better", worn = "RES_WHY_worn", reference = "RES_WHY_reference", missing = "RES_WHY_missing" }

local function RefreshDetails(self, frame, rv, spec)
	local p = rv.preview
	local ui = UI()
	local confirm = spec and frame.resConfirm == spec.id
	if not spec then
		ui.PreviewSet(p, "", { L.RES_PICK }, {})
		for _, region in ipairs({ rv.toCodex, rv.release, rv.locate, rv.confirm, rv.confirmYes, rv.confirmNo }) do region:Hide() end
		return
	end
	local lines = { Stars(self, spec.stars, 14), self:SpecimenOriginText(spec) }
	local ref = self:SpecimenReference(spec.npc, spec.shiny)
	local better = self:SpecimenBetterThanCodex(spec.id)
	rv.betterLine = nil
	if better then
		lines[#lines + 1] = self:F("RES_BETTER", Stars(self, ref and ref.stars or 1, 10))
		rv.betterLine = #lines
	elseif ref then
		lines[#lines + 1] = self:F("RES_CODEX_REF", Stars(self, ref.stars, 10))
	end
	local canRelease, why = self:SpecimenCanRelease(spec.id)
	local value = self:SpecimenReleaseValue(spec)
	rv.reasonLine = nil
	if canRelease then
		lines[#lines + 1] = self:F("RES_VALUE", value)
	else
		lines[#lines + 1] = L[WHY[why] or "RES_WHY_missing"]
		rv.reasonLine = #lines
	end
	ui.PreviewSet(p, self:SpecimenLabel(spec), lines, { creature = spec.npc, shiny = spec.shiny })
	-- couleurs : « meilleur » en vert, la raison du refus en rouge
	for index, line in ipairs(p.lines) do
		local c = (index == rv.betterLine and Theme.GREEN) or (index == rv.reasonLine and Theme.RED)
			or (index == 1 and Theme.LABEL or Theme.MUTED_LIGHT)
		line:SetTextColor(c[1], c[2], c[3], 1)
		line.azKeep = nil
	end
	if confirm then
		for _, region in ipairs({ rv.toCodex, rv.release, rv.locate }) do region:Hide() end
		rv.confirm:SetText(self:F("RES_CONFIRM", self:SpecimenLabel(spec), value))
		rv.confirm:Show(); rv.confirmYes:Show(); rv.confirmNo:Show()
		return
	end
	rv.confirm:Hide(); rv.confirmYes:Hide(); rv.confirmNo:Hide()
	rv.toCodex:Show()
	Enable(rv.toCodex, true)
	rv.release:SetText(self:F("RES_RELEASE", value, ns.PaillettesGlyph(12)))
	Enable(rv.release, canRelease, L[WHY[why] or "RES_WHY_missing"])
	rv.release:Show()
	local point = self.SpeciesPoint and self:SpeciesPoint(spec.npc, self:SpecimenZones(spec))
	rv.locate:SetText((point and self:MapPinActive("creature:" .. tostring(spec.npc))) and L.RES_LOCATE_OFF or L.RES_LOCATE)
	Enable(rv.locate, point, L.RES_LOCATE_NONE)
	rv.locate:Show()
end

-- les displayID à apprendre (vignettes visibles), table réutilisée
local learnList = {}
local function RefreshReserve(self, frame, pane)
	local rv = pane.reserve
	local count, capacity = self:SpecimenReserveCount(), self:ReserveCapacity()
	frame.header:SetTitle(self:F("RES_TITLE", count, capacity))
	frame.header:SetSubtitle(L.JRN_SUB_reserve)
	local list, all
	if frame.scrollOnly and rv.lastList then
		list, all = rv.lastList, rv.lastAll
	else
		all = self:ReserveView("stars")
		local options, seen = SpeciesOptions(self, all)
		if frame.resNpc and not seen[frame.resNpc] then frame.resNpc = nil end
		rv.species:SetOptions(options)
		rv.species:SetValue(frame.resNpc or "all")
		rv.sort:SetValue(frame.resSort or "stars")
		rv.show:Select(frame.resShow or "all", true)
		list = self:ReserveView(frame.resSort, frame.resNpc, frame.resShow == "shiny")
		rv.lastList, rv.lastAll = list, all
	end
	frame.resList = list
	rv.warn:SetText(self:ReserveFull() and self:F("RES_FULL", count, capacity) or "")
	local cols, rows = rv.cols, rv.rows
	local totalRows = math.ceil(#list / cols)
	local maxOffset = math.max(0, totalRows - rows)
	frame.resOffset = math.max(0, math.min(frame.resOffset or 0, maxOffset))
	-- le choix : gardé s'il est encore là, sinon le premier
	local picked
	for _, spec in ipairs(list) do if spec.id == frame.resPick then picked = spec end end
	if not picked then picked = list[1]; frame.resPick = picked and picked.id or nil end
	if frame.resConfirm and frame.resConfirm ~= frame.resPick then frame.resConfirm = nil end
	local first = frame.resOffset * cols
	local learn = learnList
	for i = #learn, 1, -1 do learn[i] = nil end
	for index, tile in ipairs(rv.tiles) do
		local spec = list[first + index]
		tile.spec = spec
		if spec then
			if self.AllureTileLook then
				self:AllureTileLook(tile, { id = "spec:" .. spec.npc .. (spec.shiny and ":s" or ""), npc = spec.npc, shiny = spec.shiny })
			end
			tile.label:SetText(self.CreatureName and self:CreatureName(spec.npc, { name = spec.name }) or tostring(spec.name or spec.npc))
			local c = spec.shiny and Theme.GOLD_LIGHT or Theme.LABEL
			tile.label:SetTextColor(c[1], c[2], c[3], 1)
			tile.label.azKeep = nil
			PaintTileStars(tile, spec.stars)
			if tile.gem then if spec.shiny then tile.gem:Show() else tile.gem:Hide() end end
			if tile.fav then tile.fav:Hide() end
			local on = spec.id == frame.resPick
			tile:SetSelected(on)
			if ns.AllureShowRing then ns.AllureShowRing(tile, on, frame) end
			local better = self:SpecimenBetterThanCodex(spec.id)
			tile:SetAccent((on and Theme.GOLD) or (better and Theme.GREEN) or (spec.shiny and Theme.GOLD_LIGHT) or nil)
			tile:Show()
			if not (self.ModelKnownDisplay and self:ModelKnownDisplay(spec.npc)) then learn[#learn + 1] = spec.npc end
		else
			tile:Hide()
		end
	end
	if #learn > 0 and self.ModelLearnCreatures then self:ModelLearnCreatures(learn) end
	if #list == 0 then
		rv.empty:SetText(#(all or rv.lastAll or {}) == 0 and L.RES_EMPTY or L.RES_EMPTY_FILTER)
		rv.empty:Show()
	else
		rv.empty:SetText("")
		rv.empty:Hide()
	end
	rv.pager:Update(frame.resOffset, rows, totalRows, maxOffset)
	RefreshDetails(self, frame, rv, picked)
end

local function RefreshShop(self, frame, pane)
	local sv = pane.shop
	frame.header:SetTitle(L.RES_SHOP_TITLE)
	frame.header:SetSubtitle(L.RES_SHOP_SUB)
	local glyph = ns.PaillettesGlyph(14)
	for _, row in ipairs(sv.rows) do
		local item = row.item
		local state, a, b = self:ShopState(item)
		row.state = state
		row.name:SetText(self:ShopLabel(item))
		local desc
		if item.kind == "aid" then
			local def = AidDef(item.aid)
			desc = self:F("SHOP_AID_HAVE", L["CAPTURE_AID_DESC_" .. item.aid] or "", self:CaptureAidCount(item.aid), def and def.cap or 0)
		elseif item.kind == "slots" then
			desc = self:F("SHOP_SLOTS_DESC", self:ReserveCapacity())
		else
			desc = L["SHOP_COS_" .. item.cos] or ""
		end
		row.desc:SetText(desc)
		row.price:SetText(state == "owned" and "" or self:F("SHOP_PRICE", item.price, glyph))
		local c = (state == "short") and Theme.RED or Theme.GOLD
		row.price:SetTextColor(c[1], c[2], c[3], 1)
		row.price.azKeep = nil
		local asking = frame.shopConfirm == item.id and state == "ok"
		if asking then
			row.buy:Hide(); row.yes:Show(); row.no:Show()
		else
			row.yes:Hide(); row.no:Hide()
			row.buy:SetText(state == "owned" and L.SHOP_OWNED or L.SHOP_BUY)
			local tip
			if state == "short" then tip = self:F("SHOP_SHORT", a)
			elseif state == "full" then tip = self:F("SHOP_FULL", a, b)
			elseif state == "owned" then tip = L.SHOP_OWNED_TIP
			elseif state == "off" then tip = L.SHOP_OFF end
			Enable(row.buy, state == "ok", tip)
			row.buy:Show()
		end
		row:SetAccent(asking and Theme.GOLD or nil)
		row:SetAlpha(1)
		row:Show()
	end
	if frame.shopConfirm and not (self:ShopItem(frame.shopConfirm) and self:ShopState(frame.shopConfirm) == "ok") then
		frame.shopConfirm = nil
	end
end

local function Refresh(self, frame, ui)
	local pane = frame.res
	if not pane then return end
	local view = frame.resView == "shop" and "shop" or "reserve"
	frame.resView = view
	pane.views:Select(view, true)
	pane.balance:SetText(self:F("RES_BALANCE", ns.PaillettesGlyph(14), self:Paillettes()))
	if view == "shop" then
		pane.reserve:Hide()
		pane.shop:Show()
		RefreshShop(self, frame, pane)
	else
		pane.shop:Hide()
		pane.reserve:Show()
		RefreshReserve(self, frame, pane)
	end
end

-- Ouvrir la page (vue « reserve » ou « shop »)
function ns:OpenReserve(view)
	local frame = self:EnsureJournalWindow()
	if not frame then return nil end
	if view then frame.resView = view end
	if not frame:IsShown() and self.ToggleJournal then
		self:DB().journalTab = "reserve"
		self:ToggleJournal(true)
	end
	self:SelectJournalKind("reserve")
	return self.journalFrame
end

ns.JOURNAL_PANES = ns.JOURNAL_PANES or {}
ns.JOURNAL_PANES.reserve = {
	field = "res", title = "JRN_SEC_reserve", subtitle = "JRN_SUB_reserve",
	build = Build, refresh = Refresh, scroll = Scroll,
}

if ns.Mark then ns.Mark("JournalReserve") end
