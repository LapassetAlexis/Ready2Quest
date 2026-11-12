-- Favoris (Favorites.lua, 1.34.0) : reprise de « toujours garder », raccourci
-- configurable, cadenas sur les cases, ligne d'infobulle, protections (vente
-- des gris, Sac plein), boucliers chez le marchand (confirmation avant de
-- vendre), rachat d'un favori vendu quand même, aucune souillure des cases du
-- jeu ; infobulles du candidat de Sac plein et du butin de Place au butin.
local Check, ResetWorld, NS, Mock = T.Check, T.ResetWorld, T.NS, T.Mock

local F = { savedG = {}, keys = {}, touched = {} }
F.saved = {
	CItemGetItemInfo = C_Item.GetItemInfo,
	PickupContainerItem = C_Container.PickupContainerItem,
	UseContainerItem = C_Container.UseContainerItem,
	TooltipDataProcessor = TooltipDataProcessor,
	tooltipCallback = Mock.tooltipCallback,
	ttHooks = GameTooltip.hooks and GameTooltip.hooks.OnTooltipSetItem,
}
for _, name in ipairs({ "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown", "InCombatLockdown",
	"StaticPopup_Show", "StaticPopupDialogs", "GetNumBuybackItems", "GetBuybackItemLink", "BuybackItem",
	"HandleModifiedItemClick", "ContainerFrame1", "ContainerFrameCombinedBags" }) do
	F.savedG[name] = { value = rawget(_G, name) }
end

-- un contrôle par comportement, les étapes ratées nommées
local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local GREY, WHITE, BLUE = 882001, 882002, 882003
function F.Link(id)
	local d = Mock.world.itemInfo[id] or {}
	return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. tostring(d.name or id) .. "]|h|r"
end
C_Item.GetItemInfo = function(item)
	local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
	local d = Mock.world.itemInfo[id]
	if not d then return nil end
	return d.name, F.Link(id), d.quality, 1, 1, "", "", 20, nil, nil, d.sellPrice
end
C_Container.PickupContainerItem = function(bag, slot)
	Mock.world.picked = Mock.world.picked or {}
	Mock.world.picked[#Mock.world.picked + 1] = bag .. ":" .. slot
end
_G.IsAltKeyDown = function() return F.keys.alt == true end
_G.IsControlKeyDown = function() return F.keys.ctrl == true end
_G.IsShiftKeyDown = function() return F.keys.shift == true end
_G.InCombatLockdown = function() return Mock.world.combat == true end
_G.StaticPopup_Show = function(which, a1, a2, data)
	local dialog = { which = which, text_arg1 = a1, data = data }
	Mock.world.popup = dialog
	return dialog
end
_G.HandleModifiedItemClick = function(link) Mock.world.linked = link; return true end
-- rachat : la liste du marchand, le dernier vendu à la fin
_G.GetNumBuybackItems = function() return #(Mock.world.buyback or {}) end
_G.GetBuybackItemLink = function(i) return (Mock.world.buyback or {})[i] end
_G.BuybackItem = function(i) Mock.world.boughtBack = i end

function F.Keys(alt, ctrl, shift) F.keys = { alt = alt, ctrl = ctrl, shift = shift } end

-- Une case du jeu : espionne SetScript et SetAttribute (aucun appel attendu)
function F.Button(bag, slot)
	local button = CreateFrame("Button", nil, UIParent)
	button.GetID = function() return slot end
	button.GetBagID = function() return bag end
	button.IsVisible = function(self) return self.shown == true end
	button.GetFrameLevel = function() return 3 end
	local set = button.SetScript
	button.SetScript = function(self, ...) F.touched[#F.touched + 1] = "SetScript"; return set(self, ...) end
	button.SetAttribute = function() F.touched[#F.touched + 1] = "SetAttribute" end
	button:Show()
	return button
end

function F.Reset()
	ResetWorld()
	F.Keys(false, false, false)
	F.touched = {}
	_G.StaticPopupDialogs = {}
	Mock.world.itemInfo = {
		[GREY]  = { name = "Os précieux", quality = 0, sellPrice = 5 },
		[WHITE] = { name = "Caillou", quality = 1, sellPrice = 5 },
		[BLUE]  = { name = "Épée bleue", quality = 3, sellPrice = 200 },
	}
	local function Item(id) return { itemID = id, stackCount = 1, quality = Mock.world.itemInfo[id].quality, hyperlink = F.Link(id) } end
	Mock.world.bags[0] = { size = 4, items = { [1] = Item(GREY), [2] = Item(WHITE), [3] = Item(BLUE), [4] = Item(GREY) } }
	local db = NS:DB()
	db.favorites, db.bagspaceDiscard, db.favoriteClick = {}, {}, "alt"
	NS.favoritesMerchant, NS.favoriteCounts, NS.favoriteSalesAllowed = nil, nil, nil
	-- le sac du jeu : ContainerFrame1, quatre cases (.Items, client récent)
	local frame = CreateFrame("Frame", "ContainerFrame1", UIParent)
	frame.IsVisible = function(self) return self.shown == true end
	frame.Items = { F.Button(0, 1), F.Button(0, 2), F.Button(0, 3), F.Button(0, 4) }
	frame:Show()
	_G.ContainerFrame1 = frame
	_G.ContainerFrameCombinedBags = nil
	F.frame = frame
	for _, shield in ipairs(NS.favoriteShields) do shield:Hide() end
	Mock:Reset()
end

function F.Lock(i)
	local lock = NS.favoriteLocks[F.frame.Items[i]]
	return lock ~= nil and lock:IsShown() == true
end
function F.Shields()
	local list = {}
	for _, shield in ipairs(NS.favoriteShields) do
		if shield:IsShown() then list[#list + 1] = shield.bag .. ":" .. shield.slot end
	end
	table.sort(list)
	return table.concat(list, ",")
end
function F.Has(text) return Mock:Output():find(text, 1, true) ~= nil end

-- 1. Chaînes ------------------------------------------------------------------
do
	local strings = NS.FAVORITES_STRINGS
	local missing = {}
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" or value == "" then missing[#missing + 1] = key end
	end
	for key in pairs(strings.en) do if strings.fr[key] == nil then missing[#missing + 1] = key end end
	Check("[FAV] chaînes fr + en complètes", #missing == 0 and NS.L.FAV_TOOLTIP == "Favori : protégé de la vente"
		and strings.en.FAV_TOOLTIP == "Favorite: protected from selling", table.concat(missing, ","))
end

-- 2. Reprise de « toujours garder » ------------------------------------------------
do
	local s = Steps()
	local db = { bagspaceKeep = { [GREY] = "Os précieux", [WHITE] = true, [BLUE] = "Épée" }, favorites = { [BLUE] = "Épée bleue" } }
	local moved = NS:MigrateFavorites(db)
	s.ok("trois entrées reprises", moved == 3, moved)
	s.ok("nom gardé", db.favorites[GREY] == "Os précieux")
	s.ok("ancienne entrée `true` gardée", db.favorites[WHITE] ~= nil)
	s.ok("favori déjà là : son nom reste", db.favorites[BLUE] == "Épée bleue")
	s.ok("ancienne liste retirée", db.bagspaceKeep == nil)
	s.ok("idempotent", NS:MigrateFavorites(db) == 0 and db.favorites[GREY] == "Os précieux")
	-- vraie sauvegarde : relue au chargement (ADDON_LOADED -> OnDBReady)
	local saved = NS:DB()
	saved.favorites = {}
	saved.bagspaceKeep = { [GREY] = "Os précieux" }
	NS._dbReady = false
	saved = NS:DB()
	s.ok("au chargement de la sauvegarde", saved.favorites[GREY] == "Os précieux" and saved.bagspaceKeep == nil)
	s.ok("plus de réglage par défaut bagspaceKeep", NS.DEFAULTS.bagspaceKeep == nil)
	s.check("[FAV] reprise de « toujours garder » au compte, sans perte, une fois")
end

-- 3. Raccourci : chaque choix, et Désactivé ---------------------------------------
do
	local s = Steps()
	F.Reset()
	NS:FavoritesRefresh()
	local button = F.frame.Items[2]   -- le Caillou
	local hook = button.hooks and button.hooks.OnClick
	s.ok("post-hook OnClick posé", type(hook) == "function")
	local cases = {
		{ "alt",          { true, false, false }, "LeftButton",  { false, true, false }, "LeftButton" },
		{ "ctrlalt",      { true, true, false },  "LeftButton",  { true, false, false }, "LeftButton" },
		{ "shiftalt",     { true, false, true },  "LeftButton",  { true, false, false }, "LeftButton" },
		{ "altright",     { true, false, false }, "RightButton", { true, false, false }, "LeftButton" },
		{ "ctrlaltright", { true, true, false },  "RightButton", { true, true, false },  "LeftButton" },
	}
	for _, case in ipairs(cases) do
		NS:DB().favorites = {}
		NS:SetFavoriteClick(case[1])
		F.Keys(case[4][1], case[4][2], case[4][3]); hook(button, case[5])
		local wrong = NS:IsFavorite(WHITE)
		F.Keys(case[2][1], case[2][2], case[2][3]); hook(button, case[3])
		local on = NS:IsFavorite(WHITE)
		hook(button, case[3])
		s.ok(case[1] .. " : autre clic sans effet", not wrong)
		s.ok(case[1] .. " : ajouté puis retiré", on and not NS:IsFavorite(WHITE))
	end
	Mock:Reset()
	NS:SetFavoriteClick("alt")
	F.Keys(true, false, false); hook(button, "LeftButton")
	s.ok("message d'ajout", F.Has("Caillou ajouté aux favoris"), Mock:Output())
	hook(button, "LeftButton")
	s.ok("message de retrait", F.Has("Caillou retiré des favoris"), Mock:Output())
	NS:SetFavoriteClick("off")
	hook(button, "LeftButton"); hook(button, "RightButton")
	s.ok("Désactivé : rien", not NS:IsFavorite(WHITE))
	s.ok("Désactivé : la note le dit", NS:FavoriteHowToText():find("désactivé", 1, true) ~= nil)
	NS:SetFavoriteClick("alt")
	s.ok("note : le raccourci choisi", NS:FavoriteHowToText():find("Alt+clic", 1, true) == 1)
	s.ok("choix inconnu refusé", NS:SetFavoriteClick("ctrl") == nil and NS:DB().favoriteClick == "alt")
	local labels = {}
	for _, choice in ipairs(NS:FavoriteClickChoices()) do labels[#labels + 1] = choice.label end
	s.ok("six choix, Alt+clic en premier", #labels == 6 and labels[1] == "Alt+clic" and labels[6] == "Désactivé",
		table.concat(labels, "|"))
	s.ok("défaut : Alt+clic", NS.DEFAULTS.favoriteClick == "alt")
	s.check("[FAV] raccourci : chaque choix bascule, les autres clics et Désactivé ne font rien")
end

-- 4. Cadenas ----------------------------------------------------------------
do
	local s = Steps()
	F.Reset()
	NS:SetFavorite(GREY, true, nil, true)
	s.ok("les deux Os ont leur cadenas", F.Lock(1) and F.Lock(4))
	s.ok("pas de cadenas ailleurs", not F.Lock(2) and not F.Lock(3))
	local lock = NS.favoriteLocks[F.frame.Items[1]]
	s.ok("texture du client, en haut à gauche", lock.texture == "Interface\\Buttons\\LockButton-Locked-Up"
		and (select(1, lock:GetPoint())) == "TOPLEFT")
	s.ok("pas de cadenas créé pour une case non favorite", NS.favoriteLocks[F.frame.Items[2]] == nil)
	-- l'objet bouge : la case 1 se vide, le blanc arrive en case 4
	Mock.world.bags[0].items[1] = nil
	Mock.world.bags[0].items[4] = { itemID = WHITE, stackCount = 1, quality = 1, hyperlink = F.Link(WHITE) }
	Mock:Fire("BAG_UPDATE_DELAYED")
	s.ok("case vidée / autre objet : cadenas caché", not F.Lock(1) and not F.Lock(4))
	s.ok("cadenas réutilisé", NS.favoriteLocks[F.frame.Items[1]] == lock)
	Mock.world.bags[0].items[4] = { itemID = GREY, stackCount = 1, quality = 0, hyperlink = F.Link(GREY) }
	Mock:Fire("BAG_UPDATE_DELAYED")
	NS:SetFavorite(GREY, false, nil, true)
	s.ok("plus favori : caché", not F.Lock(4))
	-- en combat : rien ne bouge, rattrapé à la sortie
	NS:SetFavorite(BLUE, true, nil, true)
	Mock.world.combat = true
	NS:SetFavorite(BLUE, false, nil, true)
	s.ok("combat : rien touché", F.Lock(3) and NS.favoritesPending == true)
	Mock.world.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	s.ok("sortie de combat : à jour", not F.Lock(3) and not NS.favoritesPending)
	-- sacs fermés : aucun cadenas visible exigé, sans erreur
	F.frame:Hide()
	s.ok("sacs fermés : sans erreur", pcall(NS.FavoritesRefresh, NS))
	s.check("[FAV] cadenas : sur chaque copie d'un favori, suit les sacs, jamais en combat")
end

-- 5. Infobulle --------------------------------------------------------------
do
	local s = Steps()
	F.Reset()
	NS:SetFavorite(BLUE, true, nil, true)
	NS.favoriteTooltipHook = nil
	s.ok("voie moderne", NS:FavoritesHookTooltip() == "processor" and type(Mock.tooltipCallback) == "function")
	GameTooltip:ClearLines()
	Mock.tooltipCallback(GameTooltip, { id = BLUE })
	s.ok("ligne sur un favori", GameTooltip.lines[1] == "Favori : protégé de la vente", GameTooltip.lines[1])
	local color = GameTooltip.styled[1].color
	local c = NS.Theme.GOLD
	s.ok("couleur or du thème", color and color[1] == c[1] and color[2] == c[2] and color[3] == c[3])
	-- contraste mesuré sur le fond d'une infobulle (quasi noir)
	local ratio = NS.Theme.Contrast(c, { 0.05, 0.05, 0.05 })
	s.ok("contraste ≥ 4,5", ratio >= 4.5, ratio)
	GameTooltip:ClearLines()
	Mock.tooltipCallback(GameTooltip, { id = WHITE })
	s.ok("rien sur un autre objet", #GameTooltip.lines == 0)
	-- client sans TooltipDataProcessor : OnTooltipSetItem, par le lien
	_G.TooltipDataProcessor = nil
	NS.favoriteTooltipHook = nil
	s.ok("voie ancienne", NS:FavoritesHookTooltip() == "script")
	GameTooltip:ClearLines()
	Mock.world.hoveredLink = F.Link(BLUE)
	GameTooltip.hooks.OnTooltipSetItem(GameTooltip)
	s.ok("ligne par le lien", GameTooltip.lines[1] == "Favori : protégé de la vente")
	_G.TooltipDataProcessor = F.saved.TooltipDataProcessor
	GameTooltip.hooks.OnTooltipSetItem = F.saved.ttHooks
	Mock.world.hoveredLink = nil
	s.check("[FAV] infobulle : « Favori : protégé de la vente », or lisible, deux voies")
end

-- 6. Protections : vente des gris, Sac plein, Place au butin ------------------------
do
	local s = Steps()
	F.Reset()
	NS:SetFavorite(GREY, true, nil, true)
	Mock.world.sold = nil
	NS.sellRun = { count = 0, value = 0 }
	NS.merchantOpen = true
	local sold, _, more = NS:SellGrayBatch()
	s.ok("aucun gris favori vendu", sold == 0 and Mock.world.sold == nil and not more, sold)
	NS:SetFavorite(GREY, false, nil, true)
	sold = NS:SellGrayBatch()
	s.ok("sans favori : les deux gris vendus", sold == 2, sold)
	NS.sellRun, NS.merchantOpen = nil, false
	F.Reset()
	NS:SetFavorite(GREY, true, nil, true)
	local ids = {}
	for _, c in ipairs(NS:BagSpaceCandidates()) do ids[#ids + 1] = c.itemID end
	s.ok("Sac plein : favori jamais proposé", not table.concat(ids, ","):find(tostring(GREY), 1, true), table.concat(ids, ","))
	NS:BagSpaceToggleDiscard(GREY, "Os")
	s.ok("« toujours jeter » retire des favoris", not NS:IsFavorite(GREY) and NS:DB().bagspaceDiscard[GREY] ~= nil)
	NS:SetFavorite(GREY, true, nil, true)
	s.ok("favori retire de « toujours jeter »", NS:DB().bagspaceDiscard[GREY] == nil)
	NS:LootRoomIgnore({ itemID = WHITE, link = F.Link(WHITE) })
	s.ok("Place au butin, Ignorer : favori nommé", NS:DB().favorites[WHITE] == "Caillou")
	s.ok("gris favori : pas compté « à vendre »", (function()
		NS:DB().favorites = { [GREY] = "Os" }
		local check
		for _, c in ipairs(NS.checks or {}) do if c.id == "gray" then check = c end end
		if not check then return false end
		local ok = check.run(NS:DB())
		return ok == true
	end)())
	s.check("[FAV] protections : vente des gris, Sac plein, Place au butin, check des gris")
end

-- 7. Boucliers chez le marchand ------------------------------------------------
do
	local s = Steps()
	F.Reset()
	NS:SetFavorite(BLUE, true, nil, true)
	s.ok("hors marchand : pas de bouclier", F.Shields() == "")
	Mock:Fire("MERCHANT_SHOW")
	s.ok("marchand : bouclier sur le favori seul", F.Shields() == "0:3", F.Shields())
	local shield = NS.favoriteShields[1]
	s.ok("bouclier : notre bouton, au-dessus de la case", shield.allPoints == F.frame.Items[3] and shield.level > 3
		and shield.mockParent == UIParent and shield.mouseEnabled == true)
	-- clic gauche : prendre l'objet
	Mock.world.picked = nil
	shield:Click("LeftButton")
	s.ok("clic gauche : PickupContainerItem(0, 3)", Mock.world.picked and Mock.world.picked[1] == "0:3")
	-- Maj+clic : lien
	F.Keys(false, false, true)
	shield:Click("LeftButton")
	s.ok("Maj+clic : lien", Mock.world.linked == F.Link(BLUE))
	F.Keys(false, false, false)
	-- survol : l'infobulle de la case
	GameTooltip.SetBagItem = function(_, bag, slot) Mock.world.tipBag = bag .. ":" .. slot end
	shield.scripts.OnEnter(shield)
	s.ok("survol : SetBagItem(0, 3)", Mock.world.tipBag == "0:3")
	shield.scripts.OnLeave(shield)
	GameTooltip.SetBagItem = nil
	-- clic droit : confirmation, rien vendu avant
	Mock.world.sold = nil
	shield:Click("RightButton")
	local popup = Mock.world.popup
	local def = StaticPopupDialogs.READY2QUEST_FAVORITE_SELL
	s.ok("clic droit : confirmation qui nomme l'objet", popup and popup.which == "READY2QUEST_FAVORITE_SELL"
		and tostring(popup.text_arg1):find("Épée bleue", 1, true) ~= nil and Mock.world.sold == nil)
	s.ok("confirmation traduite", def and def.text:find("Vendre ce favori", 1, true) and def.button1 == "Vendre"
		and def.button2 == "Annuler")
	s.ok("annuler : rien vendu", def.OnAccept ~= nil and Mock.world.sold == nil and Mock.world.bags[0].items[3] ~= nil)
	def.OnAccept(popup, popup.data)
	s.ok("vendre : UseContainerItem(0, 3)", Mock.world.sold and Mock.world.sold[1] == BLUE and Mock.world.bags[0].items[3] == nil)
	Mock:Fire("BAG_UPDATE_DELAYED")
	s.ok("vente voulue : pas de rachat proposé", Mock.world.popup == popup)
	s.ok("bouclier retiré de la case vide", F.Shields() == "", F.Shields())
	Mock:Fire("MERCHANT_CLOSED")
	s.ok("fermé : aucun bouclier", F.Shields() == "")
	-- combat chez le marchand : aucun bouclier créé ni déplacé
	F.Reset()
	NS:SetFavorite(WHITE, true, nil, true)
	local count = #NS.favoriteShields
	Mock.world.combat = true
	Mock:Fire("MERCHANT_SHOW")
	s.ok("combat : aucun bouclier", F.Shields() == "" and #NS.favoriteShields == count)
	Mock.world.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	s.ok("sortie de combat : posé", F.Shields() == "0:2", F.Shields())
	Mock.world.combat = true
	Mock:Fire("MERCHANT_CLOSED")
	s.ok("fermé en combat : laissé tel quel", F.Shields() == "0:2")
	Mock.world.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	s.ok("puis retiré à la sortie de combat", F.Shields() == "", F.Shields())
	s.check("[FAV] boucliers : seulement chez le marchand, clic droit confirmé, clic gauche, lien, infobulle, combat")
end

-- 8. Vendu quand même : rachat -----------------------------------------------------
do
	local s = Steps()
	F.Reset()
	NS:SetFavorite(BLUE, true, nil, true)
	Mock:Fire("MERCHANT_SHOW")
	Mock.world.popup = nil
	-- glissé sur le marchand : il part dans la liste de rachat
	Mock.world.bags[0].items[3] = nil
	Mock.world.buyback = { F.Link(WHITE), F.Link(BLUE) }
	Mock:Fire("BAG_UPDATE_DELAYED")
	local popup = Mock.world.popup
	local def = StaticPopupDialogs.READY2QUEST_FAVORITE_BUYBACK
	s.ok("rachat proposé", popup and popup.which == "READY2QUEST_FAVORITE_BUYBACK"
		and tostring(popup.text_arg1):find("Épée bleue", 1, true) ~= nil)
	s.ok("textes traduits", def and def.text:find("Tu viens de vendre un favori", 1, true) and def.button1 == "Racheter")
	-- une autre vente entre-temps : l'index a bougé, on le retrouve
	table.insert(Mock.world.buyback, 1, F.Link(GREY))
	def.OnAccept(popup, popup.data)
	s.ok("Racheter : BuybackItem du bon index", Mock.world.boughtBack == 3, Mock.world.boughtBack)
	-- plus dans la liste
	Mock.world.boughtBack = nil
	Mock.world.buyback = {}
	Mock:Reset()
	def.OnAccept(popup, popup.data)
	s.ok("plus dans la liste : rien, prévenu", Mock.world.boughtBack == nil and F.Has("plus dans la liste"), Mock:Output())
	-- favori consommé (pas dans la liste de rachat) : rien
	F.Reset()
	NS:SetFavorite(WHITE, true, nil, true)
	Mock:Fire("MERCHANT_SHOW")
	Mock.world.popup, Mock.world.buyback = nil, {}
	Mock.world.bags[0].items[2] = nil
	Mock:Fire("BAG_UPDATE_DELAYED")
	s.ok("disparu sans vente : rien", Mock.world.popup == nil and not F.Has("vendre un favori"))
	-- client sans API de rachat : un avertissement dans le chat
	F.Reset()
	NS:SetFavorite(WHITE, true, nil, true)
	local num = GetNumBuybackItems
	_G.GetNumBuybackItems = nil
	Mock:Fire("MERCHANT_SHOW")
	Mock.world.popup = nil
	Mock.world.bags[0].items[2] = nil
	Mock:Fire("BAG_UPDATE_DELAYED")
	s.ok("sans rachat : avertissement", Mock.world.popup == nil and F.Has("Tu viens de vendre un favori"), Mock:Output())
	_G.GetNumBuybackItems = num
	Mock:Fire("MERCHANT_CLOSED")
	s.check("[FAV] favori vendu quand même : rachat proposé, BuybackItem au bon index")
end

-- 9. Aucune souillure des cases du jeu ---------------------------------------------
do
	local s = Steps()
	F.Reset()
	NS:SetFavorite(GREY, true, nil, true)
	NS:SetFavorite(BLUE, true, nil, true)
	Mock:Fire("MERCHANT_SHOW")
	F.Keys(true, false, false)
	for _, button in ipairs(F.frame.Items) do button.hooks.OnClick(button, "LeftButton") end
	F.Keys(false, false, false)
	Mock:Fire("BAG_UPDATE_DELAYED")
	Mock:Fire("MERCHANT_CLOSED")
	s.ok("ni SetScript ni SetAttribute sur une case", #F.touched == 0, table.concat(F.touched, ","))
	local replaced = false
	for _, button in ipairs(F.frame.Items) do
		if button.scripts.OnClick ~= nil then replaced = true end
	end
	s.ok("OnClick des cases jamais remplacé", not replaced)
	s.ok("une seule accroche par case", (function()
		local hook = F.frame.Items[1].hooks.OnClick
		NS:FavoritesRefresh()
		return F.frame.Items[1].hooks.OnClick == hook
	end)())
	s.check("[FAV] aucune souillure : les cases du jeu ne sont jamais modifiées")
end

-- 10. Infobulles : candidat de Sac plein, butin de Place au butin -------------------
do
	local s = Steps()
	F.Reset()
	NS.bagspace = { list = {
		{ bag = 0, slot = 2, itemID = WHITE, count = 1, quality = 1, link = F.Link(WHITE), value = 5 },
		{ bag = 0, slot = 3, itemID = BLUE, count = 1, quality = 3, link = F.Link(BLUE), value = 200 },
	}, index = 1 }
	local frame = NS:ShowBagSpaceFrame()
	local area = frame and frame.itemArea
	s.ok("zone de survol sur la ligne", area and area.allPoints == frame.text)
	local calls = {}
	GameTooltip.SetBagItem = function(_, bag, slot) calls[#calls + 1] = "bag " .. bag .. ":" .. slot end
	GameTooltip.SetHyperlink = function(_, link) calls[#calls + 1] = "link " .. link end
	area.scripts.OnEnter(area)
	s.ok("survol : SetBagItem du candidat", calls[1] == "bag 0:2", calls[1])
	NS:BagSpaceNext()
	s.ok("[Autre] sous la souris : l'infobulle suit", calls[2] == "bag 0:3", calls[2])
	Mock.world.bags[0].items[3] = nil
	area.scripts.OnEnter(area)
	s.ok("case changée : repli sur le lien", calls[3] == "link " .. F.Link(BLUE), calls[3])
	GameTooltip.SetBagItem = nil
	Mock.world.bags[0].items[2] = { itemID = WHITE, stackCount = 1, quality = 1, hyperlink = F.Link(WHITE) }
	NS:BagSpaceNext()
	s.ok("sans SetBagItem : le lien", calls[4] == "link " .. F.Link(WHITE), calls[4])
	area.scripts.OnLeave(area)
	F.Keys(false, false, true)
	Mock.world.linked = nil
	area:Click("LeftButton")
	s.ok("Maj+clic : lien du candidat", Mock.world.linked == F.Link(WHITE))
	F.Keys(false, false, false)
	NS:HideBagSpaceFrame()
	NS.bagspace = nil
	-- Place au butin : le butin bloqué
	NS.lootRoom = { target = { slot = 2, link = F.Link(BLUE) } }
	GameTooltip.SetLootItem = function(_, slot) calls[#calls + 1] = "loot " .. slot end
	s.ok("butin bloqué : SetLootItem", NS:LootRoomTargetTooltip(UIParent) == "loot" and calls[#calls] == "loot 2")
	GameTooltip.SetLootItem = nil
	s.ok("butin bloqué : repli sur le lien", NS:LootRoomTargetTooltip(UIParent) == "link")
	GameTooltip.SetHyperlink = nil
	NS.lootRoom = nil
	s.check("[FAV] infobulle du jeu au survol du candidat de Sac plein et du butin bloqué")
end

-- restauration
for _, shield in ipairs(NS.favoriteShields) do shield:Hide() end
NS.favoritesMerchant = nil
C_Item.GetItemInfo = F.saved.CItemGetItemInfo
C_Container.PickupContainerItem = F.saved.PickupContainerItem
C_Container.UseContainerItem = F.saved.UseContainerItem
_G.TooltipDataProcessor = F.saved.TooltipDataProcessor
Mock.tooltipCallback = F.saved.tooltipCallback
for name, entry in pairs(F.savedG) do _G[name] = entry.value end
