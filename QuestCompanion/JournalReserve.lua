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
--   * 3.0.0 : Échanges (CaptureTrades.lua) : la fenêtre d'échange avec un
--     autre joueur, l'invitation reçue, l'historique ; et le bouton
--     « Échanger avec ma cible » de la vue Réserve ;
--   * Échoppe du dresseur (3.0.0 : son propre onglet, ns.JOURNAL_PANES.shop ;
--     le solde en pastille Theme.CreateCurrency sur les trois vues ; un achat
--     refusé le dit au clic) : dépenser les paillettes (ns.PAILLETTES_SHOP) :
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
-- l'échoppe : prix en paillettes ; 3.3.1 : aides 5/15/40 -> 4/12/35,
-- places +5 pour 50 -> +10 pour 40 (~13 relâchers)
ns.PAILLETTES_SHOP = {
	{ id = "appat",   kind = "aid", aid = "appat",   price = 4,  icon = "Interface\\Icons\\INV_Misc_Food_14" },
	{ id = "lasso",   kind = "aid", aid = "lasso",   price = 12, icon = "Interface\\Icons\\Spell_Nature_StrangleVines" },
	{ id = "sifflet", kind = "aid", aid = "sifflet", price = 35, icon = "Interface\\Icons\\INV_Misc_Horn_01" },
	{ id = "slots",   kind = "slots", slots = 10,    price = 40, icon = "Interface\\Icons\\INV_Misc_Bag_10" },
	-- 3.6.0 : le mécénat (ShopWeek.lua) : 100 paillettes = 1 point de mécène, sans limite
	{ id = "patron",  kind = "patron", price = 100,  icon = "Interface\\Icons\\INV_Misc_Coin_01" },
	-- 3.4.0 : les deux cosmétiques de la 3.0 entrent dans l'arrivage de la semaine
	{ id = "frame_glitter", kind = "cosmetic", cos = "frame", cosId = "shop_glitter", price = 80, arrival = true,
		icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_02" },
	{ id = "bg_starfall",   kind = "cosmetic", cos = "bg",    cosId = "shop_starfall", price = 60, arrival = true,
		icon = "Interface\\Icons\\INV_Enchant_PrismaticSphere" },
	-- 3.4.0 : l'arrivage de la semaine (deux à la fois, ns:ShopArrivals)
	{ id = "frame_ember",   kind = "cosmetic", cos = "frame", cosId = "shop_ember",   price = 80,  arrival = true,
		icon = "Interface\\Icons\\Spell_Fire_Fire" },
	{ id = "frame_frost",   kind = "cosmetic", cos = "frame", cosId = "shop_frost",   price = 100, arrival = true,
		icon = "Interface\\Icons\\Spell_Frost_FrostNova" },
	{ id = "frame_verdant", kind = "cosmetic", cos = "frame", cosId = "shop_verdant", price = 120, arrival = true,
		icon = "Interface\\Icons\\Spell_Nature_Regeneration" },
	{ id = "bg_dusk",       kind = "cosmetic", cos = "bg",    cosId = "shop_dusk",    price = 60,  arrival = true,
		icon = "Interface\\Icons\\Spell_Shadow_Twilight" },
	{ id = "bg_tide",       kind = "cosmetic", cos = "bg",    cosId = "shop_tide",    price = 80,  arrival = true,
		icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental" },
	{ id = "bg_grove",      kind = "cosmetic", cos = "bg",    cosId = "shop_grove",   price = 100, arrival = true,
		icon = "Interface\\Icons\\Spell_Nature_ProtectionformNature" },
}
-- paillettes d'un palier de zone (25, 50, 75 %) ; celles des missions sont
-- dans ns.MISSION_REWARDS (Daily.lua)
ns.PAILLETTES_MILESTONE = 2
ns.RESERVE_SORTS = { "stars", "date", "name" }
ns.RESERVE_SHOWS = { "all", "shiny" }
-- 3.0.0 : « Échanges » (CaptureTrades.lua : fenêtre d'échange, invitation, historique) ;
-- l'Échoppe du dresseur quitte les puces : elle a son onglet (ns.JOURNAL_PANES.shop)
ns.RESERVE_VIEWS = { "reserve", "trade" }
-- grille : vignettes de l'allure, un peu plus hautes (étoiles sous le portrait)
-- 3.0.0 : boutons à la taille « sm » du thème (Theme.BUTTON_SIZES, 24)
ns.RESERVE_LAYOUT = { tileW = 58, tileH = 84, gap = 7, portrait = 46, star = 10, starStep = 11, starY = -55,
	shopH = 50, shopGap = 6, shopIcon = 34, shopButton = 104, actionH = Theme.BUTTON_SIZES.sm, actionGap = 4,
	hintGap = 10 }
-- 3.1.0 : pavé de la taille sur une vignette (fond Theme.NAV presque opaque)
ns.RESERVE_SIZE_TAG = { w = 20, h = 13, alpha = 0.85 }
local LAY = ns.RESERVE_LAYOUT

local FR = {
	JRN_SEC_reserve      = "Réserve",
	JRN_SUB_reserve      = "Tes spécimens en plus du Codex : garde, échange de place avec le Codex, relâche contre des paillettes.",
	RES_VIEW_reserve     = "Réserve",
	RES_VIEW_trade       = "Échanges",
	-- 3.0.0 : l'Échoppe a son onglet ; le solde en pastille
	JRN_SEC_shop         = "Échoppe du dresseur",
	JRN_SUB_shop         = "Dépense tes paillettes : aides de capture, places de Réserve, allure du compagnon.",
	RES_BALANCE_LABEL    = "paillettes",
	RES_BALANCE_TIP      = "Tes paillettes",
	SHOP_SHORT_FOR       = "Il te manque %d paillettes pour %s.",
	RES_TITLE            = "Réserve · %d / %d",
	RES_SORT_stars       = "Tri : qualité",
	RES_SORT_date        = "Tri : date",
	RES_SORT_name        = "Tri : nom",
	RES_SHOW_all         = "Tous",
	RES_SHOW_shiny       = "Brillants",
	RES_FILTER_SIZE      = "taille",
	RES_FILTER_TRAIT     = "caractère",
	RES_SPECIES_ALL      = "Toutes les espèces",
	RES_FULL             = "Réserve pleine (%d/%d) : relâche des spécimens ou ajoute des places à l'Échoppe.",
	RES_HINT             = "Clic sur un spécimen : sa fiche. Le meilleur de chaque espèce reste au Codex.",
	RES_EMPTY            = "Ta Réserve est vide : les spécimens moins bons que ceux de ton Codex y arrivent.",
	RES_EMPTY_FILTER     = "Aucun spécimen ne correspond à ce filtre.",
	RES_PICK             = "Choisis un spécimen dans la grille.",
	RES_BY               = "Capturé par %s",
	RES_BY_MIGRATION     = "Avant la 3.0",
	RES_BY_GIFT3         = "Cadeau de la 3.0",
	-- 3.0.0 : le cadeau de bienvenue (CaptureSpecimens.lua, ns.GIFT30)
	GIFT30_OPEN          = "Cadeau de la 3.0 : choisis %d créatures",
	GIFT30_TITLE         = "Cadeau de la 3.0",
	GIFT30_SUB           = "Choisis jusqu'à %d créatures de ton Codex : une copie de chacune va dans ta Réserve (version normale, mêmes étoiles).",
	GIFT30_SEARCH        = "Rechercher une créature",
	GIFT30_COUNT         = "%d / %d choisies",
	GIFT30_CONFIRM       = "Ajouter à ma Réserve",
	GIFT30_LATER         = "Plus tard",
	GIFT30_HINT          = "Clic : choisir ou reposer. Le cadeau ne sert qu'une fois.",
	GIFT30_FULL          = "Ta Réserve n'a plus assez de place (%d/%d) : relâche un spécimen d'abord.",
	GIFT30_EMPTY         = "Aucune créature ne correspond à ta recherche.",
	GIFT30_DONE          = "Cadeau de la 3.0 : %s rejoignent ta Réserve.",
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
	-- 3.6.0 : demi-tarif au-delà de 100 paillettes de relâcher dans la journée
	RES_HALF_TODAY       = "Relâcher : demi-tarif aujourd'hui (plus de %d paillettes de relâcher)",
	RES_HALF_SHORT       = "(Demi-tarif aujourd'hui.)",
	RES_CONFIRM_NO       = "Annuler",
	RES_WHY_better       = "Mets-le au Codex avant de le relâcher.",
	RES_WHY_worn         = "Ton compagnon porte cette apparence.",
	RES_WHY_reference    = "C'est ton spécimen du Codex.",
	RES_WHY_missing      = "Ce spécimen n'existe plus.",
	RES_WHY_locked       = "Il est engagé dans un échange en cours.",
	RES_BY_TRADE         = "Échange avec %s",
	RES_TRADE_TARGET     = "Échanger avec ma cible",
	SHOP_BUY             = "Acheter",
	SHOP_CONFIRM         = "Confirmer",
	SHOP_CANCEL          = "Annuler",
	SHOP_OWNED           = "Acquis",
	SHOP_PRICE           = "%d %s",
	SHOP_FULL            = "Besace pleine (%d/%d) : utilise-en d'abord.",
	SHOP_OWNED_TIP       = "Déjà à toi.",
	SHOP_OFF             = "La capture est coupée dans les réglages.",
	-- 3.0.0 : l'infobulle d'« Acheter » grisé
	SHOP_DIS_short       = "Il te manque %d paillettes",
	SHOP_DIS_full        = "Ta besace est pleine",
	SHOP_DIS_owned       = "Déjà obtenu",
	SHOP_AID_HAVE        = "%s Dans ta besace : %d / %d.",
	SHOP_SLOTS           = "+%d places de Réserve",
	SHOP_SLOTS_DESC      = "Ta Réserve compte %d places.",
	SHOP_COS_frame       = "Cadre du compagnon, pour tous tes personnages.",
	SHOP_COS_bg          = "Fond du compagnon, pour tous tes personnages.",
	SHOP_NOTE            = "Gagner des paillettes : relâcher (2 / 4 / 10, brillant 25), les missions (3 par mission du jour, plus aux trois et à la semaine), les paliers de zone (2), l'étude des espèces, les commandes, une friandise en trop (1).",
	SHOP_BOUGHT          = "Échoppe du dresseur : %s (−%d paillettes, reste %d).",
	SHOP_REQ             = "Échoppe du dresseur : %d paillettes",
	PAILLETTES_MILESTONE_GAIN = "+%d paillettes : palier de zone (%d %%).",
	-- 3.4.0 : l'échoppe de la semaine
	SHOP_TOP             = "Les paillettes n'achètent ni lien ni caractère. Les aides ont un stock par jour.",
	SHOP_NICK_DESC       = "Donne un nom à un spécimen, depuis sa fiche dans la Réserve. Offert une fois au lien Inséparable.",
	SHOP_NICK_GO         = "La Réserve",
	SHOP_NOTE_ORDERS     = "Un spécimen livré quitte la Réserve ; les trois commandes livrées : un cosmétique de l'arrivage, offert.",
	ORDER_HAVE           = "%d dans ta Réserve",
	ORDER_NONE           = "Aucun pour l'instant",
}
local EN = {
	JRN_SEC_reserve      = "Reserve",
	JRN_SUB_reserve      = "Your specimens beyond the Codex: keep them, swap with the Codex, release them for glitter.",
	RES_VIEW_reserve     = "Reserve",
	RES_VIEW_trade       = "Trades",
	JRN_SEC_shop         = "Trainer's Stall",
	JRN_SUB_shop         = "Spend your glitter: capture aids, Reserve slots, your companion's look.",
	RES_BALANCE_LABEL    = "glitter",
	RES_BALANCE_TIP      = "Your glitter",
	SHOP_SHORT_FOR       = "You need %d more glitter for %s.",
	RES_TITLE            = "Reserve · %d / %d",
	RES_SORT_stars       = "Sort: quality",
	RES_SORT_date        = "Sort: date",
	RES_SORT_name        = "Sort: name",
	RES_SHOW_all         = "All",
	RES_SHOW_shiny       = "Shiny",
	RES_FILTER_SIZE      = "size",
	RES_FILTER_TRAIT     = "personality",
	RES_SPECIES_ALL      = "Every species",
	RES_FULL             = "Reserve full (%d/%d): release specimens or add slots at the Stall.",
	RES_HINT             = "Click a specimen: its card. The best of each species stays in the Codex.",
	RES_EMPTY            = "Your Reserve is empty: specimens weaker than your Codex ones land here.",
	RES_EMPTY_FILTER     = "No specimen matches this filter.",
	RES_PICK             = "Pick a specimen in the grid.",
	RES_BY               = "Captured by %s",
	RES_BY_MIGRATION     = "Before 3.0",
	RES_BY_GIFT3         = "3.0 gift",
	GIFT30_OPEN          = "3.0 gift: pick %d creatures",
	GIFT30_TITLE         = "3.0 gift",
	GIFT30_SUB           = "Pick up to %d creatures from your Codex: a copy of each goes to your Reserve (normal version, same stars).",
	GIFT30_SEARCH        = "Search a creature",
	GIFT30_COUNT         = "%d / %d picked",
	GIFT30_CONFIRM       = "Add to my Reserve",
	GIFT30_LATER         = "Later",
	GIFT30_HINT          = "Click: pick or put back. The gift works only once.",
	GIFT30_FULL          = "Your Reserve is short of room (%d/%d): release a specimen first.",
	GIFT30_EMPTY         = "No creature matches your search.",
	GIFT30_DONE          = "3.0 gift: %s join your Reserve.",
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
	RES_HALF_TODAY       = "Release: half price today (over %d glitter from releases)",
	RES_HALF_SHORT       = "(Half price today.)",
	RES_CONFIRM_NO       = "Cancel",
	RES_WHY_better       = "Put it in the Codex before releasing it.",
	RES_WHY_worn         = "Your companion wears this look.",
	RES_WHY_reference    = "It's your Codex specimen.",
	RES_WHY_missing      = "This specimen no longer exists.",
	RES_WHY_locked       = "It's part of a trade in progress.",
	RES_BY_TRADE         = "Traded with %s",
	RES_TRADE_TARGET     = "Trade with my target",
	SHOP_BUY             = "Buy",
	SHOP_CONFIRM         = "Confirm",
	SHOP_CANCEL          = "Cancel",
	SHOP_OWNED           = "Owned",
	SHOP_PRICE           = "%d %s",
	SHOP_FULL            = "Bag full (%d/%d): use some first.",
	SHOP_OWNED_TIP       = "Already yours.",
	SHOP_OFF             = "Capture is turned off in the settings.",
	SHOP_DIS_short       = "You need %d more glitter",
	SHOP_DIS_full        = "Your bag is full",
	SHOP_DIS_owned       = "Already owned",
	SHOP_AID_HAVE        = "%s In your bag: %d / %d.",
	SHOP_SLOTS           = "+%d Reserve slots",
	SHOP_SLOTS_DESC      = "Your Reserve has %d slots.",
	SHOP_COS_frame       = "Companion frame, for all your characters.",
	SHOP_COS_bg          = "Companion background, for all your characters.",
	SHOP_NOTE            = "Earning glitter: releasing (2 / 4 / 10, shiny 25), missions (3 per daily mission, more for all three and weekly ones), zone milestones (2), species study, orders, an extra treat (1).",
	SHOP_BOUGHT          = "Trainer's Stall: %s (−%d glitter, %d left).",
	SHOP_REQ             = "Trainer's Stall: %d glitter",
	PAILLETTES_MILESTONE_GAIN = "+%d glitter: zone milestone (%d%%).",
	SHOP_TOP             = "Glitter buys neither bond nor personality. Aids have a daily stock.",
	SHOP_NICK_DESC       = "Name a specimen from its card in the Reserve. Free once at Inseparable bond.",
	SHOP_NICK_GO         = "The Reserve",
	SHOP_NOTE_ORDERS     = "A delivered specimen leaves the Reserve; all three orders delivered: an arrival cosmetic, free.",
	ORDER_HAVE           = "%d in your Reserve",
	ORDER_NONE           = "None for now",
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

-- Le prix à payer (3.6.0 : ShopWeek.lua le relève hors de la semaine)
function ns:ShopPrice(item)
	if type(item) ~= "table" then item = self:ShopItem(item) end
	return type(item) == "table" and item.price or 0
end

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
	if item.kind == "patron" then return L.SHOP_PATRON or item.id end
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
	local balance, price = self:Paillettes(), self:ShopPrice(item)
	if balance < price then return "short", price - balance end
	return "ok"
end

-- Achat : true, solde | false, raison (comme ns:ShopState)
function ns:ShopBuy(id)
	local item = self:ShopItem(id)
	local state = self:ShopState(item)
	if state ~= "ok" then return false, state end
	local price = self:ShopPrice(item)
	local paid, left = self:PaillettesSpend(price, "shop:" .. item.id)
	if not paid then return false, "short" end
	if item.kind == "aid" then
		self:CaptureGrant(item.aid, { quiet = true, silent = true })
	elseif item.kind == "slots" then
		self:ReserveAddSlots(item.slots)
	elseif item.kind == "cosmetic" then
		self:ShopCosmeticGrant(item.cosId)
		if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	elseif item.kind == "patron" then
		if self.ShopPatronAdd then self:ShopPatronAdd() end
		return true, left
	end
	self:Print(self:F("SHOP_BOUGHT", self:ShopLabel(item), price, left))
	return true, left
end

-- 3.0.0 (bêta 6) : l'infobulle d'« Acheter » désactivé : la raison, ou nil
function ns:ShopDisabledTip(state, missing)
	if state == "short" then return self:F("SHOP_DIS_short", tonumber(missing) or 0) end
	if state == "full" then return L.SHOP_DIS_full end
	if state == "owned" then return L.SHOP_DIS_owned end
	if state == "off" then return L.SHOP_OFF end
	return nil
end

-- 3.0.0 : un clic sur « Acheter » refusé : la raison dans le chat
-- (« Il te manque 10 paillettes pour Sifflet du dompteur. ») et, solde trop court, la
-- pastille du solde secouée. Rend l'état (comme ns:ShopState).
function ns:ShopRefused(id)
	local item = self:ShopItem(id)
	local state, a, b = self:ShopState(item)
	if state == "ok" then return state end
	local text
	if state == "short" then text = self:F("SHOP_SHORT_FOR", a, self:ShopLabel(item))
	elseif state == "full" then text = self:F("SHOP_FULL", a, b)
	elseif state == "owned" then text = L.SHOP_OWNED_TIP
	elseif state == "off" then text = L.SHOP_OFF end
	if text then self:Print(text) end
	local pane = self.journalFrame and self.journalFrame.shopPane
	if state == "short" and pane and pane.balance then pane.balance:Flash() end
	return state
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

-- Réserve filtrée et triée : table neuve. `filter` : "all" | "shiny" (ou
-- true) | "size:<taille>" | "trait:<caractère>" (3.3.1, liste « Filtre »)
function ns:ReserveView(sort, npc, filter)
	if filter == true then filter = "shiny" end
	local list = self:SpecimenList({ where = "reserve", sort = sort or "stars", npc = npc,
		shiny = filter == "shiny" or nil })
	local kind, value = tostring(filter or ""):match("^(%a+):(.+)$")
	if kind == "size" or kind == "trait" then
		local kept = {}
		for _, spec in ipairs(list) do
			local have = kind == "size" and (spec.size or "normal") or spec.trait
			if have == value then kept[#kept + 1] = spec end
		end
		list = kept
	end
	return list
end

-- 3.3.1 : les choix de la liste « Filtre » : tous, brillants, les tailles,
-- les caractères tirés à la capture (nom, et sa sorte en indication)
function ns:ReserveFilterChoices()
	local list = { { value = "all", label = L.RES_SHOW_all }, { value = "shiny", label = L.RES_SHOW_shiny } }
	for _, size in ipairs(ns.SPECIMEN_SIZES or {}) do
		list[#list + 1] = { value = "size:" .. size.id, label = self:SpecimenSizeLabel(size.id), hint = L.RES_FILTER_SIZE }
	end
	for _, pair in ipairs(ns.SPECIMEN_TRAIT_WEIGHTS or {}) do
		local label = self.PersonaLabel and self:PersonaLabel(pair[1]) or pair[1]
		list[#list + 1] = { value = "trait:" .. pair[1], label = label, hint = L.RES_FILTER_TRAIT }
	end
	return list
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
	-- 3.4.0 : le spécimen porté (Curieux) en ajoute, jamais aux rattrapages
	local extra = (not (opts and opts.quiet) and self.CompanionMilestoneBonus) and self:CompanionMilestoneBonus() or 0
	local total = 0
	for _, gain in ipairs(gained) do
		if type(gain) == "table" and tonumber(gain.mark) then
			local n = ns.PAILLETTES_MILESTONE + math.max(0, extra)
			self:PaillettesAdd(n, "milestone")
			total = total + n
			if not quiet then self:Print(self:F("PAILLETTES_MILESTONE_GAIN", n, gain.mark)) end
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

-- 3.0.0 : une vignette de spécimen (Réserve, échanges : CaptureTrades.lua),
-- construite une fois : celle de l'allure, ses trois étoiles et, en haut à
-- gauche, le pavé de la taille (3.1.0 : XS, S, L, XL ; rien pour « normal »,
-- sur un pavé sombre lisible sur le portrait, dans les deux styles)
function ns.ReserveNewTile(frame, parent)
	local tile = ns.AllureNewTile(frame, parent, { w = LAY.tileW, h = LAY.tileH, portrait = LAY.portrait })
	BuildTileStars(tile)
	-- 3.4.0 : cadenas, flèche « meilleur », crans du lien, coche (ReserveBrowse.lua)
	if ns.ReserveTileExtras then ns.ReserveTileExtras(tile) end
	tile.sizeBack = Theme.Solid(tile, "ARTWORK", Theme.NAV, ns.RESERVE_SIZE_TAG.alpha)
	if tile.sizeBack.SetDrawLayer then tile.sizeBack:SetDrawLayer("ARTWORK", 5) end
	tile.sizeBack:SetPoint("TOPLEFT", tile, "TOPLEFT", 2, -2)
	tile.sizeBack:SetSize(ns.RESERVE_SIZE_TAG.w, ns.RESERVE_SIZE_TAG.h)
	local tag = Theme.Text(tile, Theme.F_SMALL, Theme.LABEL)
	tag:SetWidth(ns.RESERVE_SIZE_TAG.w)
	tag:SetPoint("CENTER", tile.sizeBack, "CENTER", 0, 0)
	tag:SetJustifyH("CENTER")
	tag.azKeep = true
	tile.sizeTag = tag
	tile.sizeBack:Hide(); tag:Hide()
	return tile
end

-- Peint une vignette d'après un spécimen (ou les données d'un spécimen reçu
-- par message : npc, stars, shiny, size, name) : apparence, nom, étoiles,
-- taille, perle des brillants. Rend true si la vignette montre quelque chose.
function ns:ReserveTilePaint(tile, spec)
	if not (tile and type(spec) == "table" and spec.npc ~= nil) then return false end
	if self.AllureTileLook then
		self:AllureTileLook(tile, { id = "spec:" .. spec.npc .. (spec.shiny and ":s" or ""), npc = spec.npc, shiny = spec.shiny })
	end
	-- 3.4.0 : le surnom d'abord
	local nick = type(spec.nick) == "string" and spec.nick ~= "" and spec.nick or nil
	tile.label:SetText(nick or (self.CreatureName and self:CreatureName(spec.npc, { name = spec.name }) or tostring(spec.name or spec.npc)))
	local c = spec.shiny and Theme.GOLD_LIGHT or Theme.LABEL
	tile.label:SetTextColor(c[1], c[2], c[3], 1)
	tile.label.azKeep = nil
	PaintTileStars(tile, spec.stars)
	if tile.sizeTag then
		local size = spec.size
		if size and size ~= "normal" and ns.SPECIMEN_SIZE_BY_ID and ns.SPECIMEN_SIZE_BY_ID[size] then
			tile.sizeTag:SetText(L["SPEC_SIZE_SHORT_" .. size])
			local sc = self:SpecimenSizeColor(size)
			tile.sizeTag:SetTextColor(sc[1], sc[2], sc[3], 1)
			tile.sizeTag:Show(); tile.sizeBack:Show()
		else
			tile.sizeTag:Hide(); tile.sizeBack:Hide()
		end
	end
	if tile.gem then if spec.shiny then tile.gem:Show() else tile.gem:Hide() end end
	if tile.fav then tile.fav:Hide() end
	return true
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

-- « Capturé par X · zone · date » (« Avant la 3.0 » pour la migration)
-- 3.0.0 : un spécimen reçu par échange : « Échange avec X · Capturé par Y · zone · date »
-- (origine d'avant l'échange gardée dans firstOrigin : migration, cadeau)
function ns:SpecimenOriginText(spec)
	if type(spec) ~= "table" then return "" end
	local parts, n = {}, 0
	if spec.tradedFrom then n = n + 1; parts[n] = self:F("RES_BY_TRADE", spec.tradedFrom) end
	local origin = spec.origin == "trade" and spec.firstOrigin or spec.origin
	local first
	if origin == "migration" then first = L.RES_BY_MIGRATION
	elseif origin == (ns.GIFT30 and ns.GIFT30.origin or "gift3") then first = L.RES_BY_GIFT3
	elseif spec.by then first = self:F("RES_BY", spec.by) end
	if first then n = n + 1; parts[n] = first end
	local zone = ZoneName(self, spec.zone)
	if zone then n = n + 1; parts[n] = zone end
	local day = Day(spec.at)
	if day then n = n + 1; parts[n] = day end
	return table.concat(parts, " · ")
end

local function Stars(self, n, size)
	return self.CaptureStarsText and self:CaptureStarsText(n, size or 12) or string.rep("*", n or 0)
end

local function Scroll(self, frame, delta)
	if frame.resView == "gift" then frame.giftOffset = (frame.giftOffset or 0) - (tonumber(delta) or 0); return end
	-- 3.0.0 : la fenêtre d'échange (sa grille ou l'historique, CaptureTrades.lua)
	if frame.resView == "trade" then frame.tradeOffset = (frame.tradeOffset or 0) - (tonumber(delta) or 0); return end
	frame.resOffset = (frame.resOffset or 0) - (tonumber(delta) or 0)
end

-- 3.0.0 : la pastille du solde (Theme.CreateCurrency : icône du client,
-- chiffre, « paillettes »), la même sur la Réserve, les Échanges et
-- l'Échoppe : en haut à droite de la page, sur la rangée des puces
function ns.PaillettesBadge(parent, content, ui)
	local badge = Theme.CreateCurrency(parent, { icon = ns.PAILLETTES_ICON, label = L.RES_BALANCE_LABEL,
		tip = { L.RES_BALANCE_TIP, { L.SHOP_NOTE } } })
	badge:SetPoint("TOPRIGHT", content, "TOPLEFT", ui.PAD + ui.INNER, ui.TOP)
	return badge
end

local function Build(self, frame, content, ui)
	local At, Text, Tip, HideTip = ui.At, ui.Text, ui.Tip, ui.HideTip
	local TOP, INNER, PAGER_Y, PREVIEW_W, GRID_W = ui.TOP, ui.INNER, ui.PAGER_Y, ui.PREVIEW_W, ui.GRID_W
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.res = pane
	frame.resView = frame.resView or "reserve"
	frame.resSort, frame.resOffset = frame.resSort or "stars", frame.resOffset or 0

	-- 1re rangée : la vue (Réserve, Échanges), le solde à droite ; puces et
	-- pastille à la même hauteur (Theme.CONTROL_HEIGHT)
	local views = {}
	for _, key in ipairs(ns.RESERVE_VIEWS) do views[#views + 1] = { id = key, label = L["RES_VIEW_" .. key] } end
	pane.views = Theme.CreateChips(pane, views, function(id)
		frame.resView, frame.resConfirm, frame.shopConfirm = id, nil, nil
		frame.resTidy, frame.resTidyOrder = nil, nil
		if ns.JournalRemember then ns:JournalRemember("resView", id) end
		ns:RefreshJournal()
	end)
	At(pane.views, content, 0, TOP)
	pane.balance = ns.PaillettesBadge(pane, content, ui)

	-- ===== vue Réserve =====
	local rv = CreateFrame("Frame", nil, pane)
	rv:SetAllPoints()
	pane.reserve = rv
	local rowY = TOP - Theme.CONTROL_HEIGHT - 10
	-- 3.4.0 : rangée 1 (recherche, Filtres, tri, sens, Vues) et rangée 2
	-- (pastilles, Effacer, compte, Sélection), ReserveBrowse.lua ; la liste
	-- des espèces et la ligne d'alerte s'en vont (le compte devient rouge)
	rv.bar = ns.ReserveBuildBar(frame, rv, content, ui, "res", 0, rowY)
	rv.bar.content = content
	local warnY = rowY - Theme.CONTROL_HEIGHT - 8
	local warnH = Theme.BUTTON_SIZES and Theme.BUTTON_SIZES.sm or 24
	rv.gridWidth = GRID_W
	-- la grille : vignettes de l'allure, construites une fois
	local gridTop = warnY - warnH - 8
	rv.warnY, rv.gridTop = warnY, gridTop
	local cols = math.floor((GRID_W + LAY.gap) / (LAY.tileW + LAY.gap))
	local rows = math.floor((gridTop - PAGER_Y - 8 + LAY.gap) / (LAY.tileH + LAY.gap))
	rv.cols, rv.rows = cols, rows
	rv.grid = CreateFrame("Frame", nil, rv)
	At(rv.grid, content, 0, gridTop)
	rv.grid:SetSize(GRID_W, rows * (LAY.tileH + LAY.gap))
	rv.tiles = {}
	for index = 1, cols * rows do
		local tile = ns.ReserveNewTile(frame, rv.grid)
		local slot = index - 1
		tile:ClearAllPoints()
		tile:SetPoint("TOPLEFT", rv.grid, "TOPLEFT", (slot % cols) * (LAY.tileW + LAY.gap), -math.floor(slot / cols) * (LAY.tileH + LAY.gap))
		-- 3.4.0 : sélection (mode, Ctrl+clic, Maj+clic) ou fiche ; la recherche lâche le clavier
		tile:SetScript("OnClick", function(t)
			if rv.bar.search.ClearFocus then rv.bar.search:ClearFocus() end
			if t.spec then ns:ReserveTileClick(t.spec.id) end
		end)
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
	-- le panneau de filtres, posé sur la grille (et sa rangée du bas)
	rv.panel = ns.ReserveBuildPanel(frame, rv, content, ui, "res", 0, gridTop, GRID_W, gridTop - PAGER_Y + 2)

	-- la fiche du spécimen choisi (3.4.0 : modèle plus bas, 8 lignes), trois
	-- boutons en bas ; Localiser et Surnom en icônes sur le modèle
	local previewTop = rowY
	local previewH = previewTop - PAGER_Y - 12
	local p = ui.BuildPreview(rv, content, INNER - PREVIEW_W, previewTop, previewH, { modelH = 126, lines = 8 })
	rv.preview = p
	local actionsH = 3 * (LAY.actionH + LAY.actionGap) + 8
	p.maxBottom = previewH - 10 - actionsH
	-- la fiche d'une sélection n'a qu'une rangée de boutons : plus de place
	rv.maxCard, rv.maxSelect = p.maxBottom, previewH - 10 - (LAY.actionH + 16)
	local bw = PREVIEW_W - 24
	rv.toCodex = Theme.CreateButton(p, bw, "sm", L.RES_TO_CODEX, function()
		if frame.resPick then ns:ReserveToCodexAsk(frame.resPick) end
	end, "primary")
	rv.protect = Theme.CreateButton(p, bw, "sm", L.RES_PROTECT, function()
		if frame.resPick then
			ns:SpecimenProtect(frame.resPick, not ns:SpecimenProtected(frame.resPick))
			ns:RefreshJournal()
		end
	end, "outline")
	rv.release = Theme.CreateButton(p, bw, "sm", "", function(b)
		if not (frame.resPick and b.qcEnabled ~= false) then return end
		if b.order then ns:ReserveDeliver(frame.resPick) else ns:ReserveRelease(frame.resPick) end
	end, "outline")
	local y = 8
	for _, button in ipairs({ rv.release, rv.protect, rv.toCodex }) do
		button:SetPoint("BOTTOM", p, "BOTTOM", 0, y)
		y = y + LAY.actionH + LAY.actionGap
	end
	if rv.toCodex.HookScript then
		rv.toCodex:HookScript("OnEnter", function(b) Tip(b, L.RES_TO_CODEX, { L.RES_TO_CODEX_TIP }) end)
		rv.toCodex:HookScript("OnLeave", HideTip)
	end
	local icons = ns.RESERVE_ICONS
	rv.locate = Theme.CreateIconButton(p, 22, icons.locate, function(b)
		if frame.resPick and b.qcEnabled ~= false then ns:ReserveLocate(frame.resPick) end
	end)
	rv.locate:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)
	rv.nick = Theme.CreateIconButton(p, 22, icons.nick, function(b)
		if frame.resPick and b.qcEnabled ~= false then
			frame.resNick, frame.resConfirm, frame.resCodexAsk = frame.resPick, nil, nil
			ns:RefreshJournal()
			if rv.nickBox.SetFocus then rv.nickBox:SetFocus() end
		end
	end)
	rv.nick:SetPoint("TOPRIGHT", rv.locate, "TOPLEFT", -4, 0)
	for _, button in ipairs({ rv.locate, rv.nick }) do
		if button.HookScript then
			button:HookScript("OnEnter", function(b)
				Tip(b, b.tipTitle or "", { b.disabledTip or b.tipText })
			end)
			button:HookScript("OnLeave", HideTip)
		end
	end
	-- confirmation dans la fiche (jamais de fenêtre) : texte et deux boutons
	rv.confirm = Text(p, Theme.F_SMALL, Theme.LABEL, PREVIEW_W - 28)
	rv.confirm:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 14, 8 + LAY.actionH + 8)
	if rv.confirm.SetWordWrap then rv.confirm:SetWordWrap(true) end
	local half = math.floor((bw - 6) / 2)
	rv.confirmYes = Theme.CreateButton(p, half, "sm", L.RES_CONFIRM_YES, function()
		if frame.resCodexAsk then ns:ReserveToCodexAsk(frame.resCodexAsk, true)
		elseif frame.resConfirm then ns:ReserveRelease(frame.resConfirm, true) end
	end, "primary")
	rv.confirmYes:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, 8)
	rv.confirmNo = Theme.CreateButton(p, half, "sm", L.RES_CONFIRM_NO, function()
		frame.resCodexAsk, frame.resNick = nil, nil
		ns:ReserveCancelConfirm()
	end, "outline")
	rv.confirmNo:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -12, 8)
	-- le surnom : un champ et « Donner (15) » dans la fiche
	rv.nickBox = Theme.CreateSearchBox(p, bw, L.RES_NICK_PLACE, nil)
	if rv.nickBox.SetMaxLetters then rv.nickBox:SetMaxLetters(ns.SPECIMEN_NICK_MAX or 24) end
	rv.nickBox:SetPoint("BOTTOM", p, "BOTTOM", 0, 8 + LAY.actionH + LAY.actionGap)
	rv.nickBox:SetScript("OnEnterPressed", function() rv.nickYes:Click() end)
	rv.nickYes = Theme.CreateButton(p, half, "sm", "", function(b)
		if not (frame.resNick and b.qcEnabled ~= false) then return end
		local ok = ns:ShopNickBuy(frame.resNick, rv.nickBox:GetText() or "")
		if ok then frame.resNick = nil; rv.nickBox:SetText("") end
		if rv.nickBox.ClearFocus then rv.nickBox:ClearFocus() end
		ns:RefreshJournal()
	end, "primary")
	rv.nickYes:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, 8)
	rv.nickNo = Theme.CreateButton(p, half, "sm", L.RES_CONFIRM_NO, function()
		frame.resNick = nil
		if rv.nickBox.ClearFocus then rv.nickBox:ClearFocus() end
		ns:RefreshJournal()
	end, "outline")
	rv.nickNo:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -12, 8)

	-- 3.0.0 : le cadeau de la 3.0, tant qu'il n'a pas servi ; 3.4.0 : sur la
	-- rangée des vues, à gauche du solde
	rv.giftButton = Theme.CreateButton(rv, "auto", "sm", ns:F("GIFT30_OPEN", ns.GIFT30 and ns.GIFT30.max or 3),
		function() ns:Gift30Open() end, "accent")
	rv.giftButton:SetPoint("RIGHT", pane.balance, "LEFT", -10, 0)
	rv.giftButton:Hide()
	-- 3.2.0 : « Faire de la place » (ReserveTidy.lua) ; 3.3.1 : en bas, à
	-- gauche de « Échanger avec ma cible » (placé à chaque rafraîchissement)
	rv.tidyButton = Theme.CreateButton(rv, "auto", "sm", L.RES_TIDY_BUTTON or "", function()
		if ns.ReserveTidyStart then ns:ReserveTidyStart() end
	end, "primary")
	rv.tidyButton:Hide()
	-- la sélection, dans la fiche : « Relâcher (n) » et « Annuler »
	rv.tidyYes = Theme.CreateButton(p, half, "sm", "", function(b)
		if b.qcEnabled ~= false and ns.ReserveTidyConfirm then ns:ReserveTidyConfirm() end
	end, "primary")
	rv.tidyYes:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, 8)
	rv.tidyNo = Theme.CreateButton(p, half, "sm", L.RES_TIDY_NO or "", function()
		if ns.ReserveTidyCancel then ns:ReserveTidyCancel() end
	end, "outline")
	rv.tidyNo:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -12, 8)
	rv.tidyYes:Hide(); rv.tidyNo:Hide()
	-- 3.0.0 : « Échanger avec ma cible » (CaptureTrades.lua). Bêta 6 : en bas
	-- à gauche de la page, sur la ligne de la pagination (centré sur elle),
	-- sous la grille ; l'aide de la page passe à sa droite, sur deux lignes au
	-- plus, jusqu'au bord de la grille (la pagination et la fiche sont à droite)
	rv.tradeButton = Theme.CreateButton(rv, "auto", "sm", L.RES_TRADE_TARGET, function()
		if ns.TradeWithTarget then ns:TradeWithTarget() end
	end, "outline")
	rv.bottomY = PAGER_Y + math.floor((LAY.actionH - (Theme.PAGER_HEIGHT or 22)) / 2)
	rv.bottomAt = function(region, x) At(region, content, x, rv.bottomY) end
	At(rv.tradeButton, content, 0, rv.bottomY)
	local hintX = math.ceil(rv.tradeButton:GetWidth()) + LAY.hintGap
	rv.hint:ClearAllPoints()
	rv.hint:SetPoint("LEFT", rv.tradeButton, "RIGHT", LAY.hintGap, 0)
	rv.hint:SetWidth(GRID_W - hintX)
	if rv.hint.SetWordWrap then rv.hint:SetWordWrap(true) end
	if rv.hint.SetMaxLines then rv.hint:SetMaxLines(2) end
	-- 3.4.0 : la barre de lot, à la place de la rangée du bas pendant une sélection
	rv.batch = {}
	rv.batch.count = Text(rv, Theme.F_LABEL, Theme.LABEL, 120)
	if rv.batch.count.SetWordWrap then rv.batch.count:SetWordWrap(false) end
	rv.batch.protect = Theme.CreateButton(rv, "auto", "sm", L.RES_BATCH_PROTECT, function(b)
		if b.qcEnabled ~= false then ns:ReserveSelectProtect() end
	end, "outline")
	rv.batch.trade = Theme.CreateButton(rv, "auto", "sm", L.RES_BATCH_TRADE, function(b)
		if b.qcEnabled ~= false then ns:ReserveSelectTrade() end
	end, "outline")
	rv.batch.cancel = Theme.CreateButton(rv, "auto", "sm", L.RES_BATCH_CANCEL, function()
		if ns.ReserveTidyCancel then ns:ReserveTidyCancel() end
	end, "outline")
	for _, region in pairs(rv.batch) do region:Hide() end

	-- ===== vue Cadeau de la 3.0 (choix de 3 créatures du Codex) =====
	local gv = CreateFrame("Frame", nil, pane)
	gv:SetAllPoints()
	pane.gift = gv
	gv.search = Theme.CreateSearchBox(gv, 220, L.GIFT30_SEARCH, function(text)
		frame.giftSearch, frame.giftOffset = text, 0
		ns:RefreshJournal()
	end)
	At(gv.search, content, 0, rowY)
	gv.count = Text(gv, Theme.F_LABEL, Theme.GOLD, 140)
	At(gv.count, content, 232, rowY - 5)
	gv.later = Theme.CreateButton(gv, "auto", "sm", L.GIFT30_LATER, function() ns:Gift30Later() end, "outline")
	gv.later:SetPoint("TOPRIGHT", content, "TOPLEFT", ui.PAD + INNER, rowY)
	gv.confirm = Theme.CreateButton(gv, "auto", "sm", L.GIFT30_CONFIRM, function(b)
		if b.qcEnabled ~= false then ns:Gift30Confirm() end
	end, "primary")
	gv.confirm:SetPoint("TOPRIGHT", gv.later, "TOPLEFT", -8, 0)
	gv.warn = Text(gv, Theme.F_SMALL, Theme.RED, INNER)
	At(gv.warn, content, 0, warnY)
	if gv.warn.SetWordWrap then gv.warn:SetWordWrap(false) end
	local gcols = math.floor((INNER + LAY.gap) / (LAY.tileW + LAY.gap))
	gv.cols, gv.rows = gcols, rows
	gv.grid = CreateFrame("Frame", nil, gv)
	At(gv.grid, content, 0, gridTop)
	gv.grid:SetSize(INNER, rows * (LAY.tileH + LAY.gap))
	gv.tiles = {}
	for index = 1, gcols * rows do
		local tile = ns.AllureNewTile(frame, gv.grid, { w = LAY.tileW, h = LAY.tileH, portrait = LAY.portrait })
		local slot = index - 1
		tile:ClearAllPoints()
		tile:SetPoint("TOPLEFT", gv.grid, "TOPLEFT", (slot % gcols) * (LAY.tileW + LAY.gap), -math.floor(slot / gcols) * (LAY.tileH + LAY.gap))
		BuildTileStars(tile)
		tile:SetScript("OnClick", function(t) if t.gift then ns:Gift30Toggle(t.gift.npc) end end)
		tile.onEnter = function(t)
			local tip = UI().Tip
			if tip and t.gift then tip(t, t.gift.name, { Stars(ns, t.gift.stars, 12) }) end
		end
		tile.onLeave = HideTip
		tile:Hide()
		gv.tiles[index] = tile
	end
	gv.empty = Text(gv, Theme.F_BODY, Theme.MUTED_LIGHT, INNER - 20)
	At(gv.empty, content, 10, gridTop - 20)
	ui.Pager(gv, content)
	gv.hint:SetText(L.GIFT30_HINT)
	gv:Hide()

	-- ===== vue Échanges (3.0.0, CaptureTrades.lua) =====
	if ns.TradeBuildView then ns.TradeBuildView(self, frame, pane, content, ui) end

	-- le carnet fermé : plus de confirmation en attente
	if frame.HookScript then
		frame:HookScript("OnHide", function(f)
			f.resConfirm, f.shopConfirm = nil, nil
			f.resTidy, f.resTidyOrder = nil, nil   -- 3.2.0 : la sélection « Faire de la place » aussi
			-- 3.4.0 : le panneau, le surnom, la question du Codex ; la recherche lâche le clavier
			f.resPanel, f.resNick, f.resCodexAsk, f.resTidyPrev = nil, nil, nil, nil
			if rv.bar.search.ClearFocus then rv.bar.search:ClearFocus() end
			-- l'apprentissage des displayID s'arrête avec le carnet (comme l'allure)
			if ns.ModelLearnStop then ns:ModelLearnStop() end
		end)
	end
	pane:Hide()
end

-- ---------------------------------------------------------------------------
-- 3.0.0 : l'Échoppe du dresseur, onglet du carnet (ns.JOURNAL_PANES.shop) :
-- la pastille du solde en haut à droite, une ligne par article (construite
-- une fois, repeinte), la note « Gagner des paillettes » dessous. Un article
-- hors de portée (solde trop court, besace pleine, déjà obtenu, capture
-- coupée) : « Acheter » désactivé (état désactivé du socle, grisé), la raison
-- en infobulle (bêta 6 ; avant : cliquable à l'aspect désactivé). Repeint à
-- chaque mouvement du solde (achat, relâche, gain : MenagerieView.lua).
-- ---------------------------------------------------------------------------
-- 3.4.0 (maquette) : en haut, une ligne d'aide et le solde ; cinq rangées de
-- 44 (pas de 48) : les trois aides (stock du jour), dix places (prix qui
-- monte, 150 au plus), le surnom (dans la fiche du spécimen) ; « Arrivage de
-- la semaine » (y −282 du contenu) : deux demi-rangées ; « Commandes de la
-- semaine » (y −362) : trois cartes, « Livrer » ouvre la Réserve filtrée.
-- 3.6.0 (maquette 3.6, planche 6) : sous l'arrivage, deux demi-colonnes :
-- « Hors de leur semaine » (un cosmétique à la fois, la ligne défile : flèches
-- de la pagination ou molette) et « Mécénat ». Pour les loger, les rangées
-- passent à 40 (pas de 43) et les cartes de commande à 68 : la page tient
-- toujours au-dessus du pied (ui_windows).
ns.SHOP_LAYOUT = { first = 30, step = 43, h = 40, arrivalsY = 248, arrivalsRowY = 268, sideY = 314, sideRowY = 334,
	ordersY = 380, ordersRowY = 400, orderW = 232, orderStep = 240, orderH = 68, noteY = 474 }
local SL = ns.SHOP_LAYOUT

local function ShopRow(sv, content, ui, width, x, y, frame)
	local At, Text = ui.At, ui.Text
	local row = Theme.CreateTile(sv, width, SL.h, { kind = "Frame" })
	At(row, content, x, y)
	-- une texture (Theme.CreateIcon rend un cadre : pas de SetTexture en jeu,
	-- bêta 1 de la 3.4 : l'Échoppe s'arrêtait à sa première rangée)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(LAY.shopIcon - 4, LAY.shopIcon - 4)
	row.icon:SetPoint("LEFT", row, "LEFT", 7, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local textX = 7 + LAY.shopIcon + 4
	-- demi-rangée (arrivage) : le prix tient en 48
	local priceW = width < ui.INNER and 48 or 84
	local textW = width - textX - (10 + LAY.shopButton + 10 + priceW)
	row.name = Text(row, Theme.F_LABEL, Theme.LABEL, textW)
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -6)
	if row.name.SetWordWrap then row.name:SetWordWrap(false) end
	row.desc = Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT, width - textX - (10 + LAY.shopButton + 10))
	row.desc:SetPoint("TOPLEFT", row, "TOPLEFT", textX, -24)
	if row.desc.SetWordWrap then row.desc:SetWordWrap(false) end
	row.price = Text(row, Theme.F_LABEL, Theme.GOLD, priceW)
	row.price:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(10 + LAY.shopButton + 10), -6)
	row.price:SetJustifyH("RIGHT")
	row.buy = Theme.CreateButton(row, LAY.shopButton, "sm", L.SHOP_BUY, function(b)
		local item = b:GetParent().item
		if not item then return end
		if b.bonus then ns:ShopOrderBonus(item.id); ns:RefreshJournal(); return end
		if b.qcEnabled == false then ns:ShopRefused(item.id); return end
		frame.shopConfirm = item.id
		ns:RefreshJournal()
	end, "primary")
	row.buy:SetPoint("RIGHT", row, "RIGHT", -10, 0)
	local small = math.floor((LAY.shopButton - 4) / 2)
	row.yes = Theme.CreateButton(row, small, "sm", L.SHOP_CONFIRM, function(b)
		frame.shopConfirm = nil
		ns:ShopBuy(b:GetParent().item.id)
		ns:RefreshJournal()
	end, "primary")
	row.no = Theme.CreateButton(row, small, "sm", L.SHOP_CANCEL, function() ns:ReserveCancelConfirm() end, "outline")
	row.no:SetPoint("RIGHT", row, "RIGHT", -10, 0)
	row.yes:SetPoint("RIGHT", row.no, "LEFT", -4, 0)
	return row
end

local function BuildShop(self, frame, content, ui)
	local At, Text = ui.At, ui.Text
	local TOP, INNER = ui.TOP, ui.INNER
	local sv = CreateFrame("Frame", nil, content)
	sv:SetAllPoints()
	frame.shopPane = sv
	sv.balance = ns.PaillettesBadge(sv, content, ui)
	sv.top = Text(sv, Theme.F_SMALL, Theme.MUTED_LIGHT, INNER - 200)
	At(sv.top, content, 0, TOP - 6)
	if sv.top.SetWordWrap then sv.top:SetWordWrap(false) end
	sv.top:SetText(L.SHOP_TOP)
	sv.rows = {}
	local regular = {}
	for _, item in ipairs(ns.PAILLETTES_SHOP) do
		if not item.arrival and item.kind ~= "patron" then regular[#regular + 1] = item end
	end
	for index, item in ipairs(regular) do
		local row = ShopRow(sv, content, ui, INNER, 0, TOP - SL.first - (index - 1) * SL.step, frame)
		row.item = item
		pcall(row.icon.SetTexture, row.icon, item.icon)
		sv.rows[#sv.rows + 1] = row
	end
	-- le surnom : un article sans bouton (il se donne depuis la fiche du spécimen)
	sv.nickRow = ShopRow(sv, content, ui, INNER, 0, TOP - SL.first - #regular * SL.step, frame)
	pcall(sv.nickRow.icon.SetTexture, sv.nickRow.icon, ns.RESERVE_ICONS and ns.RESERVE_ICONS.nick or ns.PAILLETTES_ICON)
	sv.nickRow.buy:SetText(L.SHOP_NICK_GO)
	sv.nickRow.buy:SetScript("OnClick", function() ns:OpenReserve("reserve") end)
	-- l'arrivage
	sv.arrivalsHead = Theme.CreateSection(sv, L.SHOP_ARRIVALS)
	sv.arrivalsHead:SetWidth(INNER)
	At(sv.arrivalsHead, content, 0, TOP - SL.arrivalsY)
	sv.arrivals = {}
	local half = math.floor((INNER - 8) / 2)
	for index = 1, ns.SHOP_ARRIVALS or 2 do
		local row = ShopRow(sv, content, ui, half, (index - 1) * (half + 8), TOP - SL.arrivalsRowY, frame)
		sv.arrivals[index] = row
		sv.rows[#sv.rows + 1] = row
	end
	-- 3.6.0 : hors de leur semaine (une ligne qui défile) et mécénat
	sv.awayHead = Theme.CreateSection(sv, L.SHOP_AWAY, L.SHOP_AWAY_PRICE)
	sv.awayHead:SetWidth(half)
	At(sv.awayHead, content, 0, TOP - SL.sideY)
	local function AwayStep(delta)
		frame.shopAwayOffset = (frame.shopAwayOffset or 0) - delta
		frame.shopConfirm = nil
		ns:RefreshJournal()
	end
	sv.awayPager = Theme.CreatePager(sv, AwayStep)
	sv.awayPager:SetPoint("RIGHT", sv.awayHead, "RIGHT", 0, 0)
	sv.awayRow = ShopRow(sv, content, ui, half, 0, TOP - SL.sideRowY, frame)
	if sv.awayRow.EnableMouseWheel then sv.awayRow:EnableMouseWheel(true) end
	sv.awayRow:SetScript("OnMouseWheel", function(_, delta) AwayStep(delta) end)
	sv.awayEmpty = Text(sv, Theme.F_SMALL, Theme.MUTED_LIGHT, half)
	At(sv.awayEmpty, content, 0, TOP - SL.sideRowY - 12)
	sv.awayEmpty:SetText(L.SHOP_AWAY_NONE)
	sv.awayEmpty:Hide()
	sv.patronHead = Theme.CreateSection(sv, L.SHOP_PATRON)
	sv.patronHead:SetWidth(half)
	At(sv.patronHead, content, half + 8, TOP - SL.sideY)
	for _, item in ipairs(ns.PAILLETTES_SHOP) do
		if item.kind == "patron" then
			local row = ShopRow(sv, content, ui, half, half + 8, TOP - SL.sideRowY, frame)
			row.item = item
			sv.patronRow = row
			sv.rows[#sv.rows + 1] = row
		end
	end
	-- l'explication au survol de la ligne (la rangée est courte)
	for _, row in ipairs({ sv.awayRow, sv.patronRow }) do
		if row.EnableMouse then row:EnableMouse(true) end
		row:SetScript("OnEnter", function(r) if r.tipTitle and ui.Tip then ui.Tip(r, r.tipTitle, { r.tipText }) end end)
		row:SetScript("OnLeave", function() if ui.HideTip then ui.HideTip() end end)
	end
	-- les commandes
	sv.ordersHead = Theme.CreateSection(sv, L.SHOP_ORDERS)
	sv.ordersHead:SetWidth(INNER)
	At(sv.ordersHead, content, 0, TOP - SL.ordersY)
	-- 3.5.1 : une relance gratuite par semaine (ShopWeek.lua)
	sv.reroll = Theme.CreateButton(sv, "auto", "sm", L.ORDER_REROLL, function()
		if ns.ShopOrdersReroll then ns:ShopOrdersReroll(); ns:RefreshJournal() end
	end, "outline")
	sv.reroll:SetPoint("TOPRIGHT", content, "TOPLEFT", ui.PAD + INNER, TOP - SL.ordersY + 4)
	if sv.reroll.HookScript and ui.Tip then
		sv.reroll:HookScript("OnEnter", function(b)
			if b.qcEnabled == false then return end
			ui.Tip(b, b:GetText(), { b.tipText or L.ORDER_REROLL_TIP })
		end)
		sv.reroll:HookScript("OnLeave", ui.HideTip)
	end
	sv.reroll:Hide()
	sv.orders = {}
	for index = 1, 3 do
		local card = Theme.CreateTile(sv, SL.orderW, SL.orderH, { kind = "Frame" })
		At(card, content, (index - 1) * SL.orderStep, TOP - SL.ordersRowY)
		card.name = Text(card, Theme.F_LABEL, Theme.LABEL, SL.orderW - 20)
		card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
		if card.name.SetWordWrap then card.name:SetWordWrap(false) end
		card.sub = Text(card, Theme.F_SMALL, Theme.MUTED_LIGHT, SL.orderW - 20)
		card.sub:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -26)
		if card.sub.SetWordWrap then card.sub:SetWordWrap(false) end
		card.reward = Text(card, Theme.F_LABEL, Theme.GOLD, 100)
		card.reward:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 10)
		card.go = Theme.CreateButton(card, "auto", "sm", L.ORDER_DELIVER, function(b)
			if b.qcEnabled ~= false then ns:ShopOrderOpen(b:GetParent().index) end
		end, "primary")
		card.go:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 6)
		card.index = index
		sv.orders[index] = card
	end
	sv.note = Text(sv, Theme.F_SMALL, Theme.MUTED_LIGHT, INNER)
	At(sv.note, content, 0, TOP - SL.noteY)
	if sv.note.SetWordWrap then sv.note:SetWordWrap(true) end
	if frame.HookScript then
		frame:HookScript("OnHide", function(f) f.shopConfirm = nil end)
	end
	sv:Hide()
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
	-- 3.1.0 : taille et caractère ; 3.4.0 : le lien, protégé
	if self.SpecimenTagsShort then lines[#lines + 1] = self:SpecimenTagsShort(spec) end
	if self.SpecimenBondLevel and self:SpecimenBondLevel(spec) >= 2 then
		lines[#lines + 1] = self:F("BOND_LINE_MAX", self:SpecimenBondName(self:SpecimenBondLevel(spec)))
	end
	if self.SpecimenProtected and self:SpecimenProtected(spec.id) then lines[#lines + 1] = L.SPEC_PROTECTED end
	if self:SpecimenBetterThanCodex(spec.id) then
		local ref = self:SpecimenReference(spec.npc, spec.shiny)
		lines[#lines + 1] = self:F("RES_BETTER", Stars(self, ref and ref.stars or 1, 10))
	end
	local tip = UI().Tip
	if tip then tip(tile, self.SpecimenDisplayName and self:SpecimenDisplayName(spec) or self:SpecimenLabel(spec), lines) end
end

local WHY = { better = "RES_WHY_better", worn = "RES_WHY_worn", reference = "RES_WHY_reference", missing = "RES_WHY_missing",
	locked = "RES_WHY_locked", protected = "SPEC_WHY_protected" }

-- les boutons de la fiche, tous cachés (chaque état montre les siens)
local function HideCard(rv)
	for _, key in ipairs({ "toCodex", "protect", "release", "confirm", "confirmYes", "confirmNo", "tidyYes", "tidyNo",
		"nickBox", "nickYes", "nickNo" }) do
		if rv[key] then rv[key]:Hide() end
	end
end

-- 3.2.0 : la sélection (« Faire de la place » ; 3.4.0 : toute sélection) :
-- la liste (12 lignes, puis « et n autres »), le gain, ce qui est laissé de
-- côté, « Relâcher (n) » et « Annuler »
local function RefreshTidy(self, frame, rv)
	local p = rv.preview
	local all = self:ReserveTidySelection()
	local list, gain, aside = self:ReserveSelectReleasable()
	local max = ns.RESERVE_BROWSE.selectLines
	local names = {}
	-- 3.6.0 : la valeur de chacun, demi-tarif du jour compris (dans l'ordre)
	local earned = self:ReleaseToday()
	for index, spec in ipairs(all) do
		if index > max then
			names[#names + 1] = self:F("RES_TIDY_MORE", #all - max)
			break
		end
		local value = self:SpecimenReleaseValue(spec, earned)
		earned = earned + value
		names[#names + 1] = self:F("RES_TIDY_LINE", self:SpecimenDisplayName(spec), Stars(self, spec.stars, 10), value)
	end
	local lines = {}
	lines[1] = #all > 0 and table.concat(names, "\n") or L.RES_SEL_EMPTY
	lines[2] = self:F("RES_TIDY_TOTAL", gain)
	lines[3] = aside > 0 and self:F("RES_SEL_ASIDE", aside) or ""
	lines[4] = #all > 0 and L.RES_TIDY_HINT or ""
	p.maxBottom = rv.maxSelect or p.maxBottom
	UI().PreviewSet(p, self:F("RES_SEL_TITLE", #all), lines, {})
	for index, line in ipairs(p.lines) do
		local c = (index == 2 and Theme.GOLD) or (index == 3 and Theme.ORANGE) or (index == 4 and Theme.MUTED_LIGHT) or Theme.LABEL
		line:SetTextColor(c[1], c[2], c[3], 1)
	end
	HideCard(rv)
	rv.locate:Hide(); rv.nick:Hide()
	rv.tidyYes:SetText(self:F("RES_TIDY_YES", #list))
	Enable(rv.tidyYes, #list > 0)
	rv.tidyYes:Show(); rv.tidyNo:Show()
end

-- « Grand (112) · Curieux »
local function ProfileLine(self, spec)
	local size = self:F("RES_CARD_SIZE", self:SpecimenSizeLabel(spec.size), self:SpecimenSizeIndex(spec))
	local trait = spec.trait and self.PersonaLabel and self:PersonaLabel(spec.trait)
	if trait and trait ~= "" then return size .. L.SPEC_TAGS_SEP .. trait end
	return size
end

-- atouts et revers du spécimen à son lien (revers et taille : dès le lien 2,
-- montrés estompés avant)
local function EffectLines(self, spec, bond)
	local plus, minus, later = {}, {}, {}
	local main = spec.trait and self:CompanionTraitEffect(spec.trait, bond)
	if main then plus[#plus + 1] = main.label end
	for _, item in ipairs(self:CompanionProfileExtras(spec, bond, true)) do
		if not item.active then later[#later + 1] = item.label
		elseif item.minus then minus[#minus + 1] = item.label
		else plus[#plus + 1] = item.label end
	end
	local plusText = #plus > 0 and self:F("EFF_PLUS", table.concat(plus, " ; ")) or ""
	local minusText, minusLater = "", false
	if #minus > 0 then minusText = self:F("EFF_MINUS", table.concat(minus, " ; "))
	elseif #later > 0 then minusText, minusLater = self:F("EFF_MINUS_LATER", table.concat(later, " ; ")), true end
	return plusText, minusText, minusLater
end

local function BondText(self, spec)
	local level = self:SpecimenBondLevel(spec)
	local nextAt = self:SpecimenBondNext(spec)
	if nextAt then return self:F("BOND_LINE", self:SpecimenBondName(level), self:SpecimenBondPoints(spec), nextAt) end
	return self:F("BOND_LINE_MAX", self:SpecimenBondName(level))
end

local function RefreshDetails(self, frame, rv, spec)
	local p = rv.preview
	local ui = UI()
	if frame.resTidy and self.ReserveTidySelection then return RefreshTidy(self, frame, rv) end
	p.maxBottom = rv.maxCard or p.maxBottom
	HideCard(rv)
	if not spec then
		ui.PreviewSet(p, "", { L.RES_PICK }, {})
		rv.locate:Hide(); rv.nick:Hide()
		return
	end
	local bond = self:SpecimenBondLevel(spec)
	local typeKey = self.SpecimenTypeKey and self:SpecimenTypeKey(spec)
	local kind = { Stars(self, spec.stars, 14) }
	if typeKey then kind[#kind + 1] = self:CreatureTypeLabel(typeKey) end
	kind[#kind + 1] = L["RES_FV_rank_" .. (self:SpecimenRankKey(spec) or "normal")]
	local plusText, minusText, minusLater = EffectLines(self, spec, bond)
	-- la place est comptée : l'essentiel d'abord, l'origine en dernier (la
	-- valeur au relâcher est sur son bouton ; seule la raison d'un refus s'écrit)
	local lines = { table.concat(kind, "  "), ProfileLine(self, spec), plusText, minusText, BondText(self, spec) }
	local ref = self:SpecimenReference(spec.npc, spec.shiny)
	local better = self:SpecimenBetterThanCodex(spec.id)
	rv.betterLine, rv.halfLine = nil, nil
	-- 3.6.0 : plus de RELEASE_DAY_FULL paillettes de relâcher aujourd'hui :
	-- le dire tôt (la fiche cache ses dernières lignes quand la place manque)
	if self:ReleaseHalfToday() and self:SpecimenCanRelease(spec.id) then
		lines[#lines + 1] = self:F("RES_HALF_TODAY", ns.RELEASE_DAY_FULL)
		rv.halfLine = #lines
	end
	if better then
		lines[#lines + 1] = self:F("RES_BETTER", Stars(self, ref and ref.stars or 1, 10))
		rv.betterLine = #lines
	elseif ref and ref.id ~= spec.id then
		lines[#lines + 1] = self:F("RES_CODEX_REF", Stars(self, ref.stars, 10))
	end
	-- 3.4.0 : une commande de la semaine en cours : « Livrer »
	local order = frame.resOrder and self.ShopOrders and self:ShopOrders().list[frame.resOrder]
	if order and order.done then order, frame.resOrder = nil, nil end
	local canRelease, why = self:SpecimenCanRelease(spec.id)
	local value = self:SpecimenReleaseValue(spec)
	rv.reasonLine = nil
	if not canRelease then
		lines[#lines + 1] = L[WHY[why] or "RES_WHY_missing"]
		rv.reasonLine = #lines
	end
	lines[#lines + 1] = self:SpecimenOriginText(spec)
	ui.PreviewSet(p, self:SpecimenDisplayName(spec), lines, { creature = spec.npc, shiny = spec.shiny })
	-- couleurs : atout en vert, revers en orange (estompé avant le lien 2),
	-- « meilleur » en vert, la raison du refus en rouge
	for index, line in ipairs(p.lines) do
		local c = (index == rv.betterLine and Theme.GREEN) or (index == rv.reasonLine and Theme.RED)
			or (index == rv.halfLine and Theme.ORANGE)
			or (index == 3 and Theme.GREEN) or (index == 4 and (minusLater and Theme.MUTED or Theme.ORANGE))
			or (index == 2 and self:SpecimenSizeColor(spec.size))
			or (index == 5 and Theme.IDENTITY)
			or (index == 1 and Theme.LABEL or Theme.MUTED_LIGHT)
		line:SetTextColor(c[1], c[2], c[3], 1)
	end
	-- Localiser et Surnom, sur le modèle
	local point = self.SpeciesPoint and self:SpeciesPoint(spec.npc, self:SpecimenZones(spec))
	local pinned = point and self:MapPinActive("creature:" .. tostring(spec.npc))
	rv.locate.tipTitle = pinned and L.RES_LOCATE_OFF or L.RES_LOCATE
	rv.locate.pinned = pinned and true or false
	Enable(rv.locate, point, L.RES_LOCATE_NONE)
	rv.locate:Show()
	local nickPrice = self.ShopNickPrice and self:ShopNickPrice(spec) or 15
	rv.nick.tipTitle = L.RES_NICK
	rv.nick.tipText = nickPrice > 0 and self:F("RES_NICK_TIP", nickPrice) or L.RES_NICK_TIP_FREE
	Enable(rv.nick, true)
	rv.nick:Show()
	-- états : surnom, remplacer un exemplaire lié, relâcher (confirmation)
	if frame.resNick == spec.id then
		rv.nickBox:Show()
		rv.nickYes:SetText(nickPrice > 0 and self:F("RES_NICK_GIVE", nickPrice) or L.RES_NICK_OK)
		local short = nickPrice > self:Paillettes()
		Enable(rv.nickYes, not short, short and self:F("SHOP_DIS_short", nickPrice - self:Paillettes()) or nil)
		rv.nickYes:Show(); rv.nickNo:Show()
		return
	end
	if frame.resCodexAsk == spec.id then
		rv.confirm:SetText(self:F("RES_CODEX_ASK", ref and self:SpecimenBondName(self:SpecimenBondLevel(ref)) or "", self:SpecimenDisplayName(spec)))
		rv.confirmYes:SetText(L.RES_CODEX_YES)
		rv.confirm:Show(); rv.confirmYes:Show(); rv.confirmNo:Show()
		return
	end
	if frame.resConfirm == spec.id then
		local ask = self:F("RES_CONFIRM", self:SpecimenDisplayName(spec), value)
		if rv.halfLine then ask = ask .. " " .. L.RES_HALF_SHORT end   -- 3.6.0
		rv.confirm:SetText(ask)
		rv.confirmYes:SetText(L.RES_CONFIRM_YES)
		rv.confirm:Show(); rv.confirmYes:Show(); rv.confirmNo:Show()
		return
	end
	rv.toCodex:Show()
	Enable(rv.toCodex, not self:SpecimenIsReference(spec.id))
	local protected = self:SpecimenProtected(spec.id)
	rv.protect:SetText(protected and L.RES_UNPROTECT or L.RES_PROTECT)
	Enable(rv.protect, true)
	rv.protect:Show()
	rv.release.order = nil
	if order then
		local fits = self:ShopOrderMatches(order, spec)
		rv.release.order = true
		rv.release:SetText(self:F("RES_ORDER_DELIVER", order.reward, ns.PaillettesGlyph(12)))
		Enable(rv.release, fits and canRelease, (not canRelease) and L[WHY[why] or "RES_WHY_missing"] or self:ShopOrderLabel(order))
	else
		rv.release:SetText(self:F("RES_RELEASE", value, ns.PaillettesGlyph(12)))
		Enable(rv.release, canRelease, L[WHY[why] or "RES_WHY_missing"])
	end
	rv.release:Show()
end

-- la rangée du bas : « Faire de la place », « Échanger avec ma cible » et
-- l'aide ; pendant une sélection, la barre de lot
local function RefreshBottom(self, frame, rv)
	local batch = rv.batch
	-- le panneau de filtres ouvert : la rangée du bas lui laisse la place
	if frame.resPanel then
		for _, region in pairs(batch) do region:Hide() end
		rv.tidyButton:Hide(); rv.tradeButton:Hide(); rv.hint:Hide()
		return
	end
	if frame.resTidy then
		rv.tidyButton:Hide(); rv.tradeButton:Hide(); rv.hint:Hide()
		local n = #(frame.resTidyOrder or {})
		batch.count:SetText(self:F("RES_BATCH_COUNT", n))
		rv.bottomAt(batch.count, 0)
		batch.count:ClearAllPoints()
		UI().At(batch.count, rv.bar.content, 0, rv.bottomY - 5)
		local all = n > 0
		for _, id in ipairs(frame.resTidyOrder or {}) do if not self:SpecimenProtected(id) then all = false end end
		batch.protect:SetText(all and L.RES_BATCH_UNPROTECT or L.RES_BATCH_PROTECT)
		Enable(batch.protect, n > 0)
		local tradeOk, tradeWhy = self:ReserveSelectTradeState()
		Enable(batch.trade, tradeOk, tradeWhy)
		local x = 120
		for _, key in ipairs({ "protect", "trade", "cancel" }) do
			batch[key]:ClearAllPoints()
			rv.bottomAt(batch[key], x)
			batch[key]:Show()
			x = x + math.ceil(batch[key]:GetWidth()) + 6
		end
		batch.count:Show()
		return
	end
	for _, region in pairs(batch) do region:Hide() end
	rv.tradeButton:Show()
	-- 3.2.0 : « Faire de la place », Réserve pleine ou presque
	local offer = self.ReserveNearFull and self:ReserveNearFull() and #self:ReserveTidyCandidates(1) > 0
	-- 3.3.1 (retour en jeu) : en bas à gauche, « Échanger avec ma cible »
	-- juste après, puis l'aide sur la place qui reste
	local tidyW = 0
	rv.tidyButton:ClearAllPoints()
	rv.tradeButton:ClearAllPoints()
	if offer then
		rv.bottomAt(rv.tidyButton, 0)
		rv.tidyButton:Show()
		tidyW = math.ceil(rv.tidyButton:GetWidth()) + 8
	else
		rv.tidyButton:Hide()
	end
	rv.bottomAt(rv.tradeButton, tidyW)
	-- l'aide (« Clic sur un spécimen… ») n'a plus la place à côté des deux
	-- boutons : elle s'efface tant que « Faire de la place » est proposé
	rv.hint:SetWidth(math.max(80, (rv.gridWidth or 0) - math.ceil(rv.tradeButton:GetWidth()) - LAY.hintGap))
	if offer then rv.hint:Hide() else rv.hint:Show() end
end

-- les displayID à apprendre (vignettes visibles), table réutilisée
local learnList = {}
local function RefreshReserve(self, frame, pane)
	local rv = pane.reserve
	local count, capacity = self:SpecimenReserveCount(), self:ReserveCapacity()
	frame.header:SetTitle(self:F("RES_TITLE", count, capacity))
	frame.header:SetSubtitle(L.JRN_SUB_reserve)
	local list
	if frame.scrollOnly and rv.lastList then
		list = rv.lastList
	else
		list = self:ReserveBrowseList("res")
		rv.lastList = list
	end
	frame.resList = list
	self:ReserveBarRefresh(rv.bar, frame)
	-- 3.0.0 : le cadeau de la 3.0, tant qu'il n'a pas servi
	if self.Gift30Available and self:Gift30Available() then rv.giftButton:Show() else rv.giftButton:Hide() end
	RefreshBottom(self, frame, rv)
	-- le panneau de filtres : posé sur la grille, les vignettes dessous se taisent
	local panelOpen = frame.resPanel and true or false
	if panelOpen then
		rv.panel:Show()
		self:ReservePanelRefresh(rv.panel)
	else
		rv.panel:Hide()
	end
	local cols, rows = rv.cols, rv.rows
	local totalRows = math.ceil(#list / cols)
	local maxOffset = math.max(0, totalRows - rows)
	frame.resOffset = math.max(0, math.min(frame.resOffset or 0, maxOffset))
	-- le choix : gardé s'il est encore là, sinon le premier
	local picked
	for _, spec in ipairs(list) do if spec.id == frame.resPick then picked = spec end end
	if not picked then picked = list[1]; frame.resPick = picked and picked.id or nil end
	if frame.resConfirm and frame.resConfirm ~= frame.resPick then frame.resConfirm = nil end
	if frame.resCodexAsk and frame.resCodexAsk ~= frame.resPick then frame.resCodexAsk = nil end
	if frame.resNick and frame.resNick ~= frame.resPick then frame.resNick = nil end
	local first = frame.resOffset * cols
	local learn = learnList
	for i = #learn, 1, -1 do learn[i] = nil end
	for index, tile in ipairs(rv.tiles) do
		local spec = list[first + index]
		tile.spec = spec
		if spec and not panelOpen then
			self:ReserveTilePaint(tile, spec)
			local ticked = frame.resTidy and frame.resTidy[spec.id] or false
			local on = (frame.resTidy and ticked) or (not frame.resTidy and spec.id == frame.resPick)
			tile:SetSelected(on)
			if ns.AllureShowRing then ns.AllureShowRing(tile, on, frame) end
			local better = self:SpecimenBetterThanCodex(spec.id)
			tile:SetAccent((on and Theme.SELECT) or (better and Theme.GREEN) or (spec.shiny and Theme.GOLD_LIGHT) or nil)   -- choisi : la sélection (= or en Sobre)
			if self.ReserveTilePaintExtras then self:ReserveTilePaintExtras(tile, spec, ticked) end
			-- 3.2.0 : pendant une sélection, les autres s'estompent
			tile:SetAlpha((frame.resTidy and not ticked) and ns.RESERVE_TIDY_DIM or 1)
			tile:Show()
			if not (self.ModelKnownDisplay and self:ModelKnownDisplay(spec.npc)) then learn[#learn + 1] = spec.npc end
		else
			tile:Hide()
		end
	end
	if #learn > 0 and self.ModelLearnCreatures then self:ModelLearnCreatures(learn) end
	if #list == 0 and not panelOpen then
		rv.empty:SetText(count == 0 and L.RES_EMPTY or L.RES_EMPTY_FILTER)
		rv.empty:Show()
	else
		rv.empty:SetText("")
		rv.empty:Hide()
	end
	rv.pager:Update(frame.resOffset, rows, totalRows, maxOffset)
	RefreshDetails(self, frame, rv, picked)
end

local function PaintShopRow(self, frame, row, item, glyph, bonus)
	row.item = item
	if not item then row:Hide(); return end
	local state, a = self:ShopState(item)
	row.state = state
	pcall(row.icon.SetTexture, row.icon, item.icon)
	row.name:SetText(self:ShopLabel(item))
	local price = self:ShopPrice(item)
	row.tipTitle, row.tipText = nil, nil
	local desc
	if item.kind == "patron" then
		-- 3.6.0 : le mécénat (ShopWeek.lua)
		row.name:SetText(self:F("SHOP_PATRON_NAME", self.ShopPatronPoints and self:ShopPatronPoints() or 0))
		desc = L.SHOP_PATRON_DESC
		row.tipTitle, row.tipText = L.SHOP_PATRON, self:F("SHOP_PATRON_TIP", price)
	elseif item.kind == "cosmetic" and self.ShopIsAway and self:ShopIsAway(item) then
		-- 3.6.0 : hors de sa semaine : quand il revient, une fois et demie le prix
		local back = self:ShopAwayWeeks(item)
		desc = (back == 1 and L.SHOP_AWAY_BACK1) or (back and self:F("SHOP_AWAY_BACK", back)) or L.SHOP_AWAY_LATER
		row.tipTitle, row.tipText = self:ShopLabel(item), self:F("SHOP_AWAY_TIP", price, item.price)
	elseif item.kind == "aid" then
		local def = AidDef(item.aid)
		desc = self:F("SHOP_AID_HAVE", L["CAPTURE_AID_DESC_" .. item.aid] or "", self:CaptureAidCount(item.aid), def and def.cap or 0)
		local left, cap
		if self.ShopStockLeft then left, cap = self:ShopStockLeft(item.aid) end
		if left and cap then desc = desc .. " " .. self:F("SHOP_STOCK", left, cap) .. "." end
	elseif item.kind == "slots" then
		desc = state == "max" and self:F("SHOP_MAX", self:ReserveCapacity())
			or self:F("SHOP_SLOTS_NEXT", self:ReserveCapacity(), ns.SHOP_SLOTS and ns.SHOP_SLOTS.max or 150)
	else
		desc = L["SHOP_COS_" .. item.cos] or ""
	end
	row.desc:SetText(desc)
	local owned = state == "owned"
	row.price:SetText((owned or state == "max") and "" or self:F("SHOP_PRICE", price, glyph))
	local c = (state == "short") and Theme.RED or Theme.GOLD
	row.price:SetTextColor(c[1], c[2], c[3], 1)
	row.buy.bonus = nil
	local asking = frame.shopConfirm == item.id and state == "ok"
	if asking then
		row.buy:Hide(); row.yes:Show(); row.no:Show()
	else
		row.yes:Hide(); row.no:Hide()
		if bonus and not owned then
			-- les trois commandes livrées : un cosmétique de l'arrivage, offert
			row.buy.bonus = true
			row.buy:SetText(L.ORDER_BONUS_TAKE)
			Enable(row.buy, true)
		else
			row.buy:SetText(owned and L.SHOP_OWNED or (item.kind == "patron" and L.SHOP_PATRON_GIVE) or L.SHOP_BUY)
			-- 3.0.0 (bêta 6) : refusé = désactivé pour de bon (grisé, pas de
			-- clic), la raison en infobulle
			Enable(row.buy, state == "ok", self:ShopDisabledTip(state, a))
		end
		row.buy:Show()
	end
	row:SetAccent(asking and Theme.SELECT or nil)   -- choisi : la sélection (= or en Sobre)
	row:SetAlpha(1)
	row:Show()
end

local function RefreshShop(self, frame)
	local sv = frame.shopPane
	if not sv then return end
	sv.balance:SetValue(self:Paillettes())
	local glyph = ns.PaillettesGlyph(14)
	local orders = self.ShopOrders and self:ShopOrders()
	local bonus = orders and not orders.bonus and self:ShopOrdersAllDone()
	local arrivals = self.ShopArrivals and self:ShopArrivals() or {}
	for index, row in ipairs(sv.arrivals) do row.item = arrivals[index] end
	for _, row in ipairs(sv.rows) do
		local isArrival = false
		for _, a in ipairs(sv.arrivals) do if a == row then isArrival = true end end
		PaintShopRow(self, frame, row, row.item, glyph, isArrival and bonus)
	end
	-- le surnom
	local nick = sv.nickRow
	nick.name:SetText(L.SHOP_NICK)
	nick.desc:SetText(L.SHOP_NICK_DESC)
	nick.price:SetText(self:F("SHOP_PRICE", ns.SHOP_NICK_PRICE or 15, glyph))
	nick.price:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
	nick.yes:Hide(); nick.no:Hide()
	Enable(nick.buy, true)
	nick.buy:Show()
	local head = L.SHOP_ARRIVALS
	local ends = self.WeeklyEndsText and self:WeeklyEndsText()
	if ends then head = head .. " · " .. ends end
	if sv.arrivalsHead.SetText then sv.arrivalsHead:SetText(head) end
	-- 3.6.0 : hors de leur semaine, une ligne qui défile
	local away = self.ShopAwayList and self:ShopAwayList() or {}
	local offset = math.max(0, math.min(#away - 1, frame.shopAwayOffset or 0))
	frame.shopAwayOffset = offset
	if away[offset + 1] then
		PaintShopRow(self, frame, sv.awayRow, away[offset + 1], glyph, false)
		sv.awayEmpty:Hide()
	else
		sv.awayRow.item = nil
		sv.awayRow:Hide()
		sv.awayEmpty:Show()
	end
	sv.awayPager:Update(offset, 1, #away, math.max(0, #away - 1))
	sv.awayPager.position:SetText(#away > 1 and string.format("%d / %d", offset + 1, #away) or "")
	-- relance : gratuite, puis ORDER_REROLL_PRICE (tant qu'aucune n'est livrée)
	if sv.reroll then
		local can, why, missing = false, "started", 0
		if self.ShopOrdersCanReroll then can, why, missing = self:ShopOrdersCanReroll() end
		local price = self.ShopOrdersRerollPrice and self:ShopOrdersRerollPrice() or 0
		if can or why == "short" then
			local text = price > 0 and self:F("ORDER_REROLL_PAID", price) or L.ORDER_REROLL
			sv.reroll:SetText(text)
			sv.reroll:SetWidth(Theme.ButtonWidth(sv, text))
			sv.reroll.tipText = price > 0 and self:F("ORDER_REROLL_PAID_TIP", price) or L.ORDER_REROLL_TIP
			Enable(sv.reroll, can, why == "short" and self:F("SHOP_DIS_short", tonumber(missing) or 0) or nil)
			sv.reroll:Show()
		else
			sv.reroll:Hide()
		end
		if sv.ordersHead.SetText then
			sv.ordersHead:SetText(L.SHOP_ORDERS, (orders and orders.rerolled and why ~= "started") and L.ORDER_REROLL_USED or nil)
		end
	end
	-- les commandes
	for index, card in ipairs(sv.orders) do
		local order = orders and orders.list[index]
		if order then
			card.name:SetText(self:ShopOrderLabel(order))
			card.reward:SetText(self:F("ORDER_REWARD", order.reward))
			if order.done then
				card.sub:SetText(L.ORDER_DONE)
				card.go:Hide()
			else
				local n = 0
				for _, spec in ipairs(self:SpecimenList({ where = "reserve" })) do
					if self:ShopOrderMatches(order, spec) and self:SpecimenCanRelease(spec.id) then n = n + 1 end
				end
				card.sub:SetText(n > 0 and self:F("ORDER_HAVE", n) or L.ORDER_NONE)
				card.go:Show()
				Enable(card.go, n > 0, L.ORDER_NONE)
			end
			card:Show()
		else
			card:Hide()
		end
	end
	sv.note:SetText(bonus and L.ORDER_BONUS or (L.SHOP_NOTE_ORDERS .. " " .. L.SHOP_NOTE))
	if frame.shopConfirm and not (self:ShopItem(frame.shopConfirm) and self:ShopState(frame.shopConfirm) == "ok") then
		frame.shopConfirm = nil
	end
end

-- 3.0.0 : le choix du cadeau de la 3.0. frame.giftPicks = { npc, … } (dans
-- l'ordre du choix), frame.giftSearch, frame.giftOffset.
local function GiftPicked(frame, npc)
	for index, value in ipairs(frame.giftPicks or {}) do if value == npc then return index end end
	return nil
end
local function RefreshGift(self, frame, pane)
	local gv = pane.gift
	local max = ns.GIFT30.max
	frame.giftPicks = frame.giftPicks or {}
	frame.header:SetTitle(L.GIFT30_TITLE)
	frame.header:SetSubtitle(self:F("GIFT30_SUB", max))
	local all = self:Gift30Candidates()
	local needle = tostring(frame.giftSearch or ""):lower()
	local list = all
	if needle ~= "" then
		list = {}
		for _, item in ipairs(all) do
			if tostring(item.name):lower():find(needle, 1, true) then list[#list + 1] = item end
		end
	end
	-- un choix qui n'est plus au Codex s'en va
	for index = #frame.giftPicks, 1, -1 do
		local keep = false
		for _, item in ipairs(all) do if item.npc == frame.giftPicks[index] then keep = true end end
		if not keep then table.remove(frame.giftPicks, index) end
	end
	local picked = #frame.giftPicks
	gv.count:SetText(self:F("GIFT30_COUNT", picked, max))
	local count, capacity = self:SpecimenReserveCount(), self:ReserveCapacity()
	local room = count + math.max(1, picked) <= capacity
	gv.warn:SetText(room and "" or self:F("GIFT30_FULL", count, capacity))
	Enable(gv.confirm, picked > 0 and room, room and nil or self:F("GIFT30_FULL", count, capacity))
	local cols, rows = gv.cols, gv.rows
	local totalRows = math.ceil(#list / cols)
	local maxOffset = math.max(0, totalRows - rows)
	frame.giftOffset = math.max(0, math.min(frame.giftOffset or 0, maxOffset))
	local first = frame.giftOffset * cols
	for index, tile in ipairs(gv.tiles) do
		local item = list[first + index]
		tile.gift = item
		if item then
			if self.AllureTileLook then self:AllureTileLook(tile, { id = "spec:" .. item.npc, npc = item.npc }) end
			tile.label:SetText(item.name)
			tile.label:SetTextColor(Theme.LABEL[1], Theme.LABEL[2], Theme.LABEL[3], 1)
			tile.label.azKeep = nil
			PaintTileStars(tile, item.stars)
			if tile.gem then tile.gem:Hide() end
			if tile.fav then tile.fav:Hide() end
			local on = GiftPicked(frame, item.npc) ~= nil
			tile:SetSelected(on)
			if ns.AllureShowRing then ns.AllureShowRing(tile, on, frame) end
			tile:SetAccent(on and Theme.SELECT or nil)   -- choisi : la sélection (= or en Sobre)
			tile:SetAlpha((on or picked < max) and 1 or 0.55)
			tile:Show()
		else
			tile:Hide()
		end
	end
	if #list == 0 then gv.empty:SetText(L.GIFT30_EMPTY); gv.empty:Show() else gv.empty:SetText(""); gv.empty:Hide() end
	gv.pager:Update(frame.giftOffset, rows, totalRows, maxOffset)
	gv.list = list
end

local function Refresh(self, frame, ui)
	local pane = frame.res
	if not pane then return end
	local view = frame.resView
	if view == "gift" and not (self.Gift30Available and self:Gift30Available()) then view = "reserve" end
	if view == "trade" and not pane.trade then view = "reserve" end
	if view ~= "gift" and view ~= "trade" then view = "reserve" end
	frame.resView = view
	pane.views:Select(view == "gift" and "reserve" or view, true)
	pane.balance:SetValue(self:Paillettes())
	pane.reserve:Hide(); pane.gift:Hide()
	if pane.trade then pane.trade:Hide() end
	if view == "trade" then
		pane.trade:Show()
		self:TradeRefreshView(frame, pane)
	elseif view == "gift" then
		pane.gift:Show()
		RefreshGift(self, frame, pane)
	else
		pane.reserve:Show()
		RefreshReserve(self, frame, pane)
	end
end

-- 3.0.0 : le cadeau de la 3.0 (page Réserve, vue « gift »). La visite du
-- carnet attend qu'il soit choisi ou remis à plus tard (tourHoldJournal).
function ns:Gift30Open()
	if not (self.Gift30Available and self:Gift30Available()) then return nil end
	self.tourHoldJournal = true
	local frame = self:EnsureJournalWindow()
	if frame then frame.giftPicks, frame.giftSearch, frame.giftOffset = {}, "", 0 end
	local opened = self:OpenReserve("gift")
	if frame and frame.res and frame.res.gift and frame.res.gift.search then frame.res.gift.search:SetText("") end
	return opened
end

function ns:Gift30Toggle(npc)
	local frame = self.journalFrame
	if not (frame and npc ~= nil) then return nil end
	frame.giftPicks = frame.giftPicks or {}
	local index = GiftPicked(frame, npc)
	if index then
		table.remove(frame.giftPicks, index)
	elseif #frame.giftPicks < ns.GIFT30.max then
		frame.giftPicks[#frame.giftPicks + 1] = npc
	else
		return false
	end
	self:RefreshJournal()
	return index == nil
end

-- Après le cadeau (choisi ou remis) : la Réserve, et la visite du carnet si elle reste à voir
local function GiftLeave(self)
	local frame = self.journalFrame
	self.tourHoldJournal = nil
	if frame then frame.resView, frame.giftPicks = "reserve", nil end
	self:RefreshJournal()
	if frame and frame:IsShown() and self.TourDone and not self:TourDone("journal") and ns.TOUR_AUTO and self.TourStart then
		self:TourStart("journal", { defer = true })
	end
end

function ns:Gift30Confirm()
	local frame = self.journalFrame
	local picks = frame and frame.giftPicks or {}
	local ids, why = self:Gift30Grant(picks)
	if not ids then
		if why == "full" then self:Print(self:F("GIFT30_FULL", self:SpecimenReserveCount(), self:ReserveCapacity())) end
		self:RefreshJournal()
		return false, why
	end
	local names = {}
	for index, id in ipairs(ids) do names[index] = self:SpecimenLabel(self:SpecimenGet(id)) end
	self:Print(self:F("GIFT30_DONE", table.concat(names, ", ")))
	if frame then frame.resPick = ids[1] end
	GiftLeave(self)
	return ids
end

function ns:Gift30Later()
	GiftLeave(self)
	return true
end

-- Ouvrir la page (vue « reserve », « trade » ou « gift » ; 3.0.0 : « shop »
-- ouvre l'onglet de l'Échoppe)
function ns:OpenReserve(view)
	if view == "shop" then return self:OpenShop() end
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

-- 3.0.0 : l'onglet de l'Échoppe du dresseur
function ns:OpenShop()
	local frame = self:EnsureJournalWindow()
	if not frame then return nil end
	if not frame:IsShown() and self.ToggleJournal then
		self:DB().journalTab = "shop"
		self:ToggleJournal(true)
	end
	self:SelectJournalKind("shop")
	return self.journalFrame
end

ns.JOURNAL_PANES = ns.JOURNAL_PANES or {}
ns.JOURNAL_PANES.reserve = {
	field = "res", title = "JRN_SEC_reserve", subtitle = "JRN_SUB_reserve",
	build = Build, refresh = Refresh, scroll = Scroll,
}
ns.JOURNAL_PANES.shop = {
	field = "shopPane", title = "JRN_SEC_shop", subtitle = "JRN_SUB_shop",
	build = BuildShop, refresh = function(self, frame) RefreshShop(self, frame) end,
}

if ns.Mark then ns.Mark("JournalReserve") end
