-- Favorites.lua -- objets favoris (v1.34.0)
--
-- Un favori est un identifiant d'objet : toutes ses copies le sont. La liste
-- (db.favorites, au compte, comme toute la sauvegarde de Ready2Quest)
-- remplace « Toujours garder » de Sac plein (db.bagspaceKeep, reprise une fois
-- par ns:MigrateFavorites, sans perte). Un favori :
--   * n'est jamais proposé par Sac plein ni Place au butin ;
--   * n'est jamais vendu par la vente automatique des gris (Merchant.lua) ;
--   * porte un cadenas (texture du client) en haut à gauche de sa case, dans
--     les sacs du jeu (ContainerFrameN, sacs combinés) ;
--   * a une ligne dans son infobulle ;
--   * chez un marchand, sa case est couverte par un « bouclier » à nous (un
--     Button non sécurisé, posé PAR-DESSUS la case) : clic droit = demande de
--     confirmation avant de vendre, clic gauche = prendre l'objet, Maj+clic =
--     lien, survol = infobulle. Vendu quand même (glissé sur le marchand, sac
--     d'un autre addon) : on propose de le racheter.
--
-- Aucune souillure (taint) : on ne remplace JAMAIS le OnClick d'une case de
-- sac, on ne pose aucun attribut. Raccourci (Alt+clic par défaut) : post-hook
-- HookScript("OnClick"), après le code du jeu. Rien n'est créé ni déplacé en
-- combat : le rafraîchissement attend PLAYER_REGEN_ENABLED.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local NUM_BAG_SLOTS   = 4
local MAX_CONTAINERS  = 13
local MAX_BAG_ITEMS   = 36
local LOCK_TEXTURE    = "Interface\\PetBattles\\PetBattle-LockIcon"
local HILITE_TEXTURE  = "Interface\\Buttons\\ButtonHilight-Square"
local LOCK_SIZE       = 14
local POPUP_SELL      = "READY2QUEST_FAVORITE_SELL"
local POPUP_BUYBACK   = "READY2QUEST_FAVORITE_BUYBACK"

-- ---------------------------------------------------------------------------
-- Chaînes, réglages
-- ---------------------------------------------------------------------------
local FR = {
	FAV_ADDED            = "%s ajouté aux favoris.",
	FAV_REMOVED          = "%s retiré des favoris.",
	FAV_TOOLTIP          = "Favori : protégé de la vente",
	FAV_SELL_CONFIRM     = "Vendre ce favori ?\n%s",
	FAV_SELL_YES         = "Vendre",
	FAV_SELL_NO          = "Annuler",
	FAV_BUYBACK          = "Tu viens de vendre un favori : %s. Le racheter ?",
	FAV_BUYBACK_YES      = "Racheter",
	FAV_BUYBACK_NO       = "Laisser",
	FAV_SOLD_WARN        = "Tu viens de vendre un favori : %s. Rachète-le dans l'onglet Rachat du marchand.",
	FAV_BUYBACK_GONE     = "%s n'est plus dans la liste de rachat.",
	FAV_MOVED            = "L'objet a bougé dans tes sacs : rien n'a été vendu.",
	OPT_FAV_HEADER       = "FAVORIS",
	OPT_FAV_CLICK        = "Raccourci : marquer un favori",
	OPT_FAV_CLICK_ALT          = "Alt+clic",
	OPT_FAV_CLICK_CTRLALT      = "Ctrl+Alt+clic",
	OPT_FAV_CLICK_SHIFTALT     = "Maj+Alt+clic",
	OPT_FAV_CLICK_ALTRIGHT     = "Alt+clic droit",
	OPT_FAV_CLICK_CTRLALTRIGHT = "Ctrl+Alt+clic droit",
	OPT_FAV_CLICK_OFF          = "Désactivé",
	OPT_FAV_HOWTO        = "%s sur un objet de tes sacs le met en favori, ou l'en retire (aussi : /r2q favori [lien]). Un favori porte un cadenas, n'est jamais proposé à jeter ni vendu avec les gris, et chez un marchand il faut confirmer sa vente (clic droit).",
	OPT_FAV_HOWTO_OFF    = "Raccourci désactivé : /r2q favori [lien] met un objet en favori, ou l'en retire. Un favori porte un cadenas, n'est jamais proposé à jeter ni vendu avec les gris, et chez un marchand il faut confirmer sa vente (clic droit).",
	FAV_NEED_ITEM        = "Indique un objet : /r2q favori [lien] (Maj+clic sur l'objet).",
	HELP_FAVORITES       = "/r2q favori [lien] -- met un objet en favori (protégé de la vente), ou l'en retire",
}
local EN = {
	FAV_ADDED            = "%s added to favorites.",
	FAV_REMOVED          = "%s removed from favorites.",
	FAV_TOOLTIP          = "Favorite: protected from selling",
	FAV_SELL_CONFIRM     = "Sell this favorite?\n%s",
	FAV_SELL_YES         = "Sell",
	FAV_SELL_NO          = "Cancel",
	FAV_BUYBACK          = "You just sold a favorite: %s. Buy it back?",
	FAV_BUYBACK_YES      = "Buy back",
	FAV_BUYBACK_NO       = "Leave it",
	FAV_SOLD_WARN        = "You just sold a favorite: %s. Buy it back from the merchant's Buyback tab.",
	FAV_BUYBACK_GONE     = "%s is no longer in the buyback list.",
	FAV_MOVED            = "The item moved in your bags: nothing was sold.",
	OPT_FAV_HEADER       = "FAVORITES",
	OPT_FAV_CLICK        = "Shortcut: mark a favorite",
	OPT_FAV_CLICK_ALT          = "Alt+click",
	OPT_FAV_CLICK_CTRLALT      = "Ctrl+Alt+click",
	OPT_FAV_CLICK_SHIFTALT     = "Shift+Alt+click",
	OPT_FAV_CLICK_ALTRIGHT     = "Alt+right-click",
	OPT_FAV_CLICK_CTRLALTRIGHT = "Ctrl+Alt+right-click",
	OPT_FAV_CLICK_OFF          = "Disabled",
	OPT_FAV_HOWTO        = "%s on an item in your bags marks it as a favorite, or unmarks it (also: /r2q favori [link]). A favorite shows a padlock, is never suggested for discarding nor sold with the grays, and at a merchant its sale must be confirmed (right-click).",
	OPT_FAV_HOWTO_OFF    = "Shortcut disabled: /r2q favori [link] marks an item as a favorite, or unmarks it. A favorite shows a padlock, is never suggested for discarding nor sold with the grays, and at a merchant its sale must be confirmed (right-click).",
	FAV_NEED_ITEM        = "Name an item: /r2q favori [link] (Shift+click the item).",
	HELP_FAVORITES       = "/r2q favori [link] -- marks an item as a favorite (protected from selling), or unmarks it",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.FAVORITES_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({
	favorites     = {},      -- [itemID] = nom affiché
	favoriteClick = "alt",   -- raccourci (ns.FAVORITE_CLICKS)
})

if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_MISC" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_FAVORITES")
		end
	end
end

-- Raccourcis proposés : modificateurs EXACTS et bouton de la souris. Ni Maj
-- seul (lien, partage de pile) ni Ctrl seul (cabine d'essayage) : ce sont des
-- actions du jeu sur les objets. Alt+clic ne fait rien par défaut sur une case.
ns.FAVORITE_CLICKS = {
	{ id = "alt",          label = "OPT_FAV_CLICK_ALT",          alt = true,                button = "LeftButton" },
	{ id = "ctrlalt",      label = "OPT_FAV_CLICK_CTRLALT",      alt = true, ctrl = true,   button = "LeftButton" },
	{ id = "shiftalt",     label = "OPT_FAV_CLICK_SHIFTALT",     alt = true, shift = true,  button = "LeftButton" },
	{ id = "altright",     label = "OPT_FAV_CLICK_ALTRIGHT",     alt = true,                button = "RightButton" },
	{ id = "ctrlaltright", label = "OPT_FAV_CLICK_CTRLALTRIGHT", alt = true, ctrl = true,   button = "RightButton" },
	{ id = "off",          label = "OPT_FAV_CLICK_OFF" },
}

-- ---------------------------------------------------------------------------
-- Accès robustes au client
-- ---------------------------------------------------------------------------
local function Global(name)
	local value = rawget(_G, name)
	if type(value) == "function" then return value end
	return nil
end

local function ContainerFn(name)
	local api = rawget(_G, "C_Container")
	if type(api) == "table" and type(api[name]) == "function" then return api[name] end
	return Global(name)
end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end

local function Method(object, name, ...)
	if type(object) ~= "table" or type(object[name]) ~= "function" then return nil end
	return Call(object[name], object, ...)
end

local function InCombat()
	return Call(Global("InCombatLockdown")) and true or false
end

local function KeyDown(name)
	return Call(Global(name)) and true or false
end

local function ContainerInfo(bag, slot)
	local ok, info = pcall(ContainerFn("GetContainerItemInfo") or error, bag, slot)
	if ok and type(info) == "table" and info.itemID then return info end
	return nil
end

local function ItemIDFrom(text)
	text = ns.Plain(text)
	if type(text) == "number" then return text end
	if type(text) ~= "string" then return nil end
	return tonumber(text:match("item:(%d+)")) or tonumber(text:match("^%s*(%d+)%s*$"))
end

local function DisplayName(itemID, link)
	if type(link) == "string" then
		local name = link:match("%[(.-)%]")
		if name then return name end
	end
	local name = ns.ItemInfo(itemID)
	if type(name) == "string" then return name end
	return "#" .. tostring(itemID)
end

-- ---------------------------------------------------------------------------
-- La liste
-- ---------------------------------------------------------------------------
local function Favorites(db)
	db = db or ns:DB()
	if type(db.favorites) ~= "table" then db.favorites = {} end
	return db.favorites
end
ns.FavoritesList = function() return Favorites() end

-- « Toujours garder » (db.bagspaceKeep, jusqu'à 1.33.3) -> favoris. La
-- sauvegarde est au compte (pas de liste par personnage) : une seule reprise.
-- Ce qui est déjà favori garde son nom ; rien n'est perdu ; idempotent.
function ns:MigrateFavorites(db)
	local old = db and db.bagspaceKeep
	if type(old) ~= "table" then
		if db then db.bagspaceKeep = nil end
		return 0
	end
	local favorites = Favorites(db)
	local moved = 0
	for itemID, name in pairs(old) do
		local id = tonumber(itemID)
		if id then
			if favorites[id] == nil or favorites[id] == true then
				favorites[id] = type(name) == "string" and name or (favorites[id] or true)
			end
			moved = moved + 1
		end
	end
	db.bagspaceKeep = nil
	return moved
end

function ns:IsFavorite(itemID)
	itemID = tonumber(ns.Plain(itemID))
	if not itemID then return false end
	return Favorites()[itemID] ~= nil
end

-- Ajoute (true) ou retire (false) ; un favori n'est jamais « toujours jeter »
function ns:SetFavorite(itemID, on, name, quiet)
	itemID = tonumber(itemID)
	if not itemID then return nil end
	local db = self:DB()
	local list = Favorites(db)
	name = name or DisplayName(itemID)
	if on then
		list[itemID] = name
		if type(db.bagspaceDiscard) == "table" then db.bagspaceDiscard[itemID] = nil end
	else
		list[itemID] = nil
	end
	if not quiet then self:Print(self:F(on and "FAV_ADDED" or "FAV_REMOVED", name)) end
	if self.RefreshOptions then self:RefreshOptions() end
	self:FavoritesRefresh()
	return on
end

function ns:ToggleFavorite(itemID, name)
	return self:SetFavorite(itemID, not self:IsFavorite(itemID), name)
end

-- ---------------------------------------------------------------------------
-- Raccourci
-- ---------------------------------------------------------------------------
function ns:FavoriteClickChoice()
	local id = self:DB().favoriteClick
	for _, choice in ipairs(ns.FAVORITE_CLICKS) do
		if choice.id == id then return choice end
	end
	return ns.FAVORITE_CLICKS[1]
end

function ns:FavoriteClickChoices()
	local list = {}
	for _, choice in ipairs(ns.FAVORITE_CLICKS) do
		list[#list + 1] = { value = choice.id, label = L[choice.label] }
	end
	return list
end

function ns:SetFavoriteClick(value)
	for _, choice in ipairs(ns.FAVORITE_CLICKS) do
		if choice.id == value then self:DB().favoriteClick = value; return value end
	end
	return nil
end

-- Le clic (bouton, modificateurs exacts) est-il le raccourci choisi ?
function ns:FavoriteClickMatches(mouseButton)
	local choice = self:FavoriteClickChoice()
	if not choice.button or choice.button ~= mouseButton then return false end
	return KeyDown("IsAltKeyDown") == (choice.alt == true)
		and KeyDown("IsControlKeyDown") == (choice.ctrl == true)
		and KeyDown("IsShiftKeyDown") == (choice.shift == true)
end

function ns:FavoriteHowToText()
	local choice = self:FavoriteClickChoice()
	if not choice.button then return L.OPT_FAV_HOWTO_OFF end
	return self:F("OPT_FAV_HOWTO", L[choice.label])
end

-- Clic sur une case (bag, slot) : bascule si c'est le raccourci
function ns:FavoriteOnSlotClick(bag, slot, mouseButton)
	if not self:FavoriteClickMatches(mouseButton) then return false end
	local info = ContainerInfo(bag, slot)
	if not info then return false end
	self:ToggleFavorite(info.itemID, DisplayName(info.itemID, info.hyperlink))
	return true
end

-- ---------------------------------------------------------------------------
-- Cases des sacs du jeu
-- ---------------------------------------------------------------------------
-- Tables à clés faibles : rien n'est écrit dans les cadres du jeu
local locks   = setmetatable({}, { __mode = "k" })   -- [case] = texture du cadenas
local hooked  = setmetatable({}, { __mode = "k" })   -- [case] = true (OnClick accroché)
local framesHooked = setmetatable({}, { __mode = "k" })
ns.favoriteLocks = locks

-- (sac, case) d'un bouton : GetBagID (client récent) ou l'ID du parent
local function ButtonSlot(button)
	local slot = Method(button, "GetID")
	local bag = Method(button, "GetBagID")
	if bag == nil then bag = Method(Method(button, "GetParent"), "GetID") end
	if type(bag) ~= "number" or type(slot) ~= "number" or slot < 1 then return nil end
	return bag, slot
end
ns.FavoriteButtonSlot = ButtonSlot

local function Visible(region)
	if type(region) ~= "table" then return false end
	if type(region.IsVisible) == "function" then return Call(region.IsVisible, region) and true or false end
	return Method(region, "IsShown") and true or false
end

-- Les cadres de sacs du jeu qui existent (séparés, combiné)
local function ContainerFrames()
	local list = {}
	local combined = rawget(_G, "ContainerFrameCombinedBags")
	if type(combined) == "table" then list[#list + 1] = combined end
	for i = 1, MAX_CONTAINERS do
		local frame = rawget(_G, "ContainerFrame" .. i)
		if type(frame) == "table" then list[#list + 1] = frame end
	end
	return list
end

-- Chaque case d'un cadre : .Items (client récent), EnumerateValidItems, ou
-- les globales ContainerFrameNItemM (client classique)
local function EachFrameButton(frame, fn)
	if type(frame.Items) == "table" then
		for _, button in ipairs(frame.Items) do fn(button) end
		return
	end
	if type(frame.EnumerateValidItems) == "function" then
		local ok, iter, state, start = pcall(frame.EnumerateValidItems, frame)
		if ok and type(iter) == "function" then
			for _, button in iter, state, start do fn(button) end
			return
		end
	end
	local name = Method(frame, "GetName")
	if type(name) ~= "string" then return end
	for j = 1, MAX_BAG_ITEMS do
		local button = rawget(_G, name .. "Item" .. j)
		if type(button) ~= "table" then break end
		fn(button)
	end
end

local function HookButton(button)
	if hooked[button] or type(button.HookScript) ~= "function" then return end
	-- post-hook : le code du jeu a déjà traité le clic ; on ne fait que lire
	-- la case et écrire dans notre sauvegarde
	local ok = pcall(button.HookScript, button, "OnClick", function(self, mouseButton)
		local bag, slot = ButtonSlot(self)
		if bag then
			local fine, err = pcall(ns.FavoriteOnSlotClick, ns, bag, slot, mouseButton)
			if not fine and ns.RecordError then ns:RecordError("favorites:click", err) end
		end
	end)
	if ok then hooked[button] = true end
end

local function Lock(button)
	local lock = locks[button]
	if lock or type(button.CreateTexture) ~= "function" then return lock end
	local ok, texture = pcall(button.CreateTexture, button, nil, "OVERLAY", nil, 7)
	if not ok or type(texture) ~= "table" then return nil end
	texture:SetTexture(LOCK_TEXTURE)
	texture:SetSize(LOCK_SIZE, LOCK_SIZE)
	texture:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	texture:Hide()
	locks[button] = texture
	return texture
end

-- ---------------------------------------------------------------------------
-- Boucliers chez le marchand : nos propres boutons, par-dessus les cases
-- ---------------------------------------------------------------------------
local shields = {}            -- réserve, réutilisée
ns.favoriteShields = shields

local function ShieldItem(shield)
	local info = shield.bag and ContainerInfo(shield.bag, shield.slot)
	if not info or info.itemID ~= shield.itemID then return nil end
	return info
end

local function ShieldEnter(shield)
	local tip = rawget(_G, "GameTooltip")
	if type(tip) ~= "table" then return end
	Method(tip, "SetOwner", shield, "ANCHOR_RIGHT")
	if type(tip.SetBagItem) == "function" then
		Call(tip.SetBagItem, tip, shield.bag, shield.slot)
	end
	Method(tip, "Show")
end

local function ShieldLeave()
	Method(rawget(_G, "GameTooltip"), "Hide")
end

function ns:FavoriteShieldClick(shield, mouseButton)
	local info = ShieldItem(shield)
	if not info then self:FavoritesRefresh(); return "moved" end
	-- le raccourci choisi d'abord (la case du jeu est sous le bouclier)
	if self:FavoriteClickMatches(mouseButton) then
		self:ToggleFavorite(info.itemID, DisplayName(info.itemID, info.hyperlink))
		return "toggle"
	end
	if KeyDown("IsShiftKeyDown") or KeyDown("IsControlKeyDown") then
		-- lien dans le chat (Maj), cabine d'essayage (Ctrl) : comme le jeu
		Call(Global("HandleModifiedItemClick"), info.hyperlink)
		return "modified"
	end
	if mouseButton == "RightButton" then
		return self:FavoriteRequestSell(shield.bag, shield.slot) and "confirm" or "none"
	end
	-- clic gauche : prendre (ou poser) l'objet, comme la case
	Call(ContainerFn("PickupContainerItem"), shield.bag, shield.slot)
	return "pickup"
end

local function NewShield()
	local parent = rawget(_G, "UIParent")
	local ok, shield = pcall(CreateFrame, "Button", nil, parent)
	if not ok or type(shield) ~= "table" then return nil end
	Method(shield, "EnableMouse", true)
	Method(shield, "RegisterForClicks", "AnyUp")
	Method(shield, "RegisterForDrag", "LeftButton")
	if type(shield.CreateTexture) == "function" then
		local hilite = shield:CreateTexture(nil, "HIGHLIGHT")
		hilite:SetTexture(HILITE_TEXTURE)
		if hilite.SetBlendMode then hilite:SetBlendMode("ADD") end
		hilite:SetAllPoints(shield)
		shield.hilite = hilite
	end
	shield:SetScript("OnClick", function(self, mouseButton)
		local fine, err = pcall(ns.FavoriteShieldClick, ns, self, mouseButton)
		if not fine and ns.RecordError then ns:RecordError("favorites:shield", err) end
	end)
	shield:SetScript("OnDragStart", function(self) Call(ContainerFn("PickupContainerItem"), self.bag, self.slot) end)
	shield:SetScript("OnReceiveDrag", function(self) Call(ContainerFn("PickupContainerItem"), self.bag, self.slot) end)
	shield:SetScript("OnEnter", ShieldEnter)
	shield:SetScript("OnLeave", ShieldLeave)
	shield:Hide()
	return shield
end

local function PlaceShield(index, button, bag, slot, itemID)
	local shield = shields[index]
	if not shield then
		shield = NewShield()
		if not shield then return false end
		shields[index] = shield
	end
	shield.bag, shield.slot, shield.itemID, shield.target = bag, slot, itemID, button
	shield:ClearAllPoints()
	shield:SetAllPoints(button)
	local strata = Method(button, "GetFrameStrata")
	if strata then Method(shield, "SetFrameStrata", strata) end
	Method(shield, "SetFrameLevel", (tonumber(Method(button, "GetFrameLevel")) or 1) + 5)
	shield:Show()
	return true
end

function ns:FavoritesHideShields()
	if InCombat() then return false end
	for _, shield in ipairs(shields) do
		shield:Hide()
		shield.bag, shield.slot, shield.itemID, shield.target = nil, nil, nil, nil
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Rafraîchissement : cadenas, boucliers, accroches. Jamais en combat (les
-- cadenas et boucliers en place restent tels quels jusqu'à la sortie).
-- ---------------------------------------------------------------------------
local function HookFrame(frame)
	if framesHooked[frame] then return end
	framesHooked[frame] = true
	local refresh = function() ns:FavoritesRefresh() end
	if type(frame.HookScript) == "function" then
		pcall(frame.HookScript, frame, "OnShow", refresh)
		pcall(frame.HookScript, frame, "OnHide", refresh)
	end
	local hook = Global("hooksecurefunc")
	if hook and type(frame.UpdateItems) == "function" then pcall(hook, frame, "UpdateItems", refresh) end
end

function ns:FavoritesRefresh()
	if InCombat() then self.favoritesPending = true; return false end
	self.favoritesPending = nil
	local shieldsOn = self.favoritesMerchant == true
	local used = 0
	for _, frame in ipairs(ContainerFrames()) do
		HookFrame(frame)
		local frameVisible = Visible(frame)
		EachFrameButton(frame, function(button)
			if type(button) ~= "table" then return end
			HookButton(button)
			local bag, slot = ButtonSlot(button)
			local info = bag and frameVisible and Visible(button) and ContainerInfo(bag, slot)
			local favorite = info and self:IsFavorite(info.itemID)
			local lock = favorite and Lock(button) or locks[button]
			if lock then
				if favorite then lock:Show() else lock:Hide() end
			end
			if favorite and shieldsOn and PlaceShield(used + 1, button, bag, slot, info.itemID) then
				used = used + 1
			end
		end)
	end
	for i = used + 1, #shields do
		shields[i]:Hide()
		shields[i].bag, shields[i].slot, shields[i].itemID, shields[i].target = nil, nil, nil, nil
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Vente d'un favori : confirmée (bouclier), sinon rachat proposé
-- ---------------------------------------------------------------------------
local function EnsurePopups()
	local dialogs = rawget(_G, "StaticPopupDialogs")
	if type(dialogs) ~= "table" then return false end
	dialogs[POPUP_SELL] = dialogs[POPUP_SELL] or {
		text = L.FAV_SELL_CONFIRM, button1 = L.FAV_SELL_YES, button2 = L.FAV_SELL_NO,
		OnAccept = function(_, data) ns:FavoriteSell(data) end,
		timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1, preferredIndex = 3,
	}
	dialogs[POPUP_BUYBACK] = dialogs[POPUP_BUYBACK] or {
		text = L.FAV_BUYBACK, button1 = L.FAV_BUYBACK_YES, button2 = L.FAV_BUYBACK_NO,
		OnAccept = function(_, data) ns:FavoriteBuyback(data) end,
		timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
	}
	return true
end

local function ShowPopup(which, text, data)
	if not EnsurePopups() then return nil end
	local dialog = Call(Global("StaticPopup_Show"), which, text, nil, data)
	if type(dialog) == "table" then dialog.data = data end
	return dialog
end

-- Clic droit sur un bouclier : on DEMANDE, rien n'est vendu ici
function ns:FavoriteRequestSell(bag, slot)
	local info = ContainerInfo(bag, slot)
	if not info then return false end
	local data = { bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount or 1,
		link = info.hyperlink or DisplayName(info.itemID) }
	local dialog = ShowPopup(POPUP_SELL, tostring(data.link), data)
	if not dialog then return false end
	self.favoriteSellAsked = data
	return true
end

-- « Vendre » confirmé : le clic du joueur porte UseContainerItem
function ns:FavoriteSell(data)
	self.favoriteSellAsked = nil
	if type(data) ~= "table" or not self.favoritesMerchant then return false end
	local info = ContainerInfo(data.bag, data.slot)
	if not info or info.itemID ~= data.itemID then self:Print(L.FAV_MOVED); return false end
	local use = ContainerFn("UseContainerItem")
	if not use then return false end
	-- vente voulue : pas de proposition de rachat derrière
	self.favoriteSalesAllowed = self.favoriteSalesAllowed or {}
	self.favoriteSalesAllowed[data.itemID] = true
	local ok = pcall(use, data.bag, data.slot)
	return ok
end

-- Combien de chaque favori dans les sacs
local function FavoriteCounts()
	local counts = {}
	local favorites = Favorites()
	local numSlots = ContainerFn("GetContainerNumSlots")
	if not numSlots or next(favorites) == nil then return counts end
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, tonumber(Call(numSlots, bag)) or 0 do
			local info = ContainerInfo(bag, slot)
			if info and favorites[info.itemID] ~= nil then
				counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
			end
		end
	end
	return counts
end

-- Index de rachat le plus récent de cet objet (le dernier vendu est en fin)
local function BuybackIndex(itemID)
	local num, link = Global("GetNumBuybackItems"), Global("GetBuybackItemLink")
	if not (num and link) then return nil end
	for i = tonumber(Call(num)) or 0, 1, -1 do
		if ItemIDFrom(Call(link, i)) == itemID then return i end
	end
	return nil
end

-- Sacs changés chez le marchand : un favori a-t-il disparu ?
function ns:FavoritesCheckSold()
	if not self.favoritesMerchant then return nil end
	local before, now = self.favoriteCounts or {}, FavoriteCounts()
	self.favoriteCounts = now
	local allowed = self.favoriteSalesAllowed or {}
	local found
	for itemID, count in pairs(before) do
		if (now[itemID] or 0) < count then
			if allowed[itemID] then
				allowed[itemID] = nil
			else
				found = found or itemID
			end
		end
	end
	if not found then return nil end
	local name = Favorites()[found]
	name = type(name) == "string" and name or DisplayName(found)
	local index = BuybackIndex(found)
	if index and Global("BuybackItem") then
		local link = Call(Global("GetBuybackItemLink"), index)
		local data = { itemID = found, index = index, link = link or name }
		if ShowPopup(POPUP_BUYBACK, tostring(data.link), data) then
			self.favoriteBuybackAsked = data
			return "popup"
		end
	end
	if index or not Global("GetNumBuybackItems") then
		self:Print(self:F("FAV_SOLD_WARN", name))
		return "warn"
	end
	return nil   -- consommé, jeté, posté : pas une vente
end

-- « Racheter » : l'index a pu bouger (autre vente entre-temps), on le recherche
function ns:FavoriteBuyback(data)
	self.favoriteBuybackAsked = nil
	if type(data) ~= "table" then return false end
	local index = data.index
	if ItemIDFrom(Call(Global("GetBuybackItemLink"), index)) ~= data.itemID then index = BuybackIndex(data.itemID) end
	if not index then self:Print(self:F("FAV_BUYBACK_GONE", tostring(data.link))); return false end
	local ok = pcall(Global("BuybackItem") or error, index)
	return ok
end

-- ---------------------------------------------------------------------------
-- Infobulle
-- ---------------------------------------------------------------------------
function ns:FavoriteTooltipLine(tooltip, data)
	local itemID = type(data) == "table" and tonumber(ns.Plain(data.id)) or nil
	if not itemID and type(tooltip.GetItem) == "function" then
		local ok, _, link = pcall(tooltip.GetItem, tooltip)
		itemID = ok and ItemIDFrom(link) or nil
	end
	if not itemID or not self:IsFavorite(itemID) then return false end
	local c = Theme.GOLD
	tooltip:AddLine(L.FAV_TOOLTIP, c[1], c[2], c[3])
	return true
end

function ns:FavoritesHookTooltip()
	if self.favoriteTooltipHook then return self.favoriteTooltipHook end
	local function Run(tooltip, data)
		if type(tooltip) ~= "table" or tooltip ~= rawget(_G, "GameTooltip") then return end
		local ok, added = pcall(ns.FavoriteTooltipLine, ns, tooltip, data)
		if not ok then
			if ns.RecordError then ns:RecordError("favorites:tooltip", added) end
		elseif added and data == nil and type(tooltip.Show) == "function" then
			pcall(tooltip.Show, tooltip)   -- OnTooltipSetItem : le cadre reprend sa taille
		end
	end
	local processor, enum = rawget(_G, "TooltipDataProcessor"), rawget(_G, "Enum")
	local dataType = type(enum) == "table" and type(enum.TooltipDataType) == "table" and enum.TooltipDataType.Item
	if dataType ~= nil and type(processor) == "table" and type(processor.AddTooltipPostCall) == "function"
		and pcall(processor.AddTooltipPostCall, dataType, Run) then
		self.favoriteTooltipHook = "processor"
		return "processor"
	end
	local tooltip = rawget(_G, "GameTooltip")
	if type(tooltip) == "table" and type(tooltip.HookScript) == "function"
		and pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(tt) Run(tt, nil) end) then
		self.favoriteTooltipHook = "script"
		return "script"
	end
	return nil
end
ns:FavoritesHookTooltip()

-- ---------------------------------------------------------------------------
-- Commande : /r2q favori [lien]
-- ---------------------------------------------------------------------------
ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["favori"] = function(self, rest)
	local itemID = ItemIDFrom(rest)
	if not itemID then return self:Print(L.FAV_NEED_ITEM) end
	self:ToggleFavorite(itemID, DisplayName(itemID, rest))
end
ns.EXTRA_COMMANDS["favorite"] = ns.EXTRA_COMMANDS["favori"]

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
local HANDLERS = {
	MERCHANT_SHOW = function()
		ns.favoritesMerchant = true
		ns.favoriteCounts = FavoriteCounts()
		ns.favoriteSalesAllowed = {}
		ns:FavoritesRefresh()
	end,
	MERCHANT_CLOSED = function()
		ns.favoritesMerchant = nil
		ns.favoriteCounts, ns.favoriteSalesAllowed = nil, nil
		ns:FavoritesHideShields()
	end,
	BAG_UPDATE_DELAYED = function()
		ns:FavoritesCheckSold()
		ns:FavoritesRefresh()
	end,
	PLAYER_REGEN_ENABLED = function()
		if ns.favoritesPending or (not ns.favoritesMerchant and shields[1] and shields[1]:IsShown()) then
			ns:FavoritesRefresh()
		end
	end,
	PLAYER_ENTERING_WORLD = function()
		local hook = Global("hooksecurefunc")
		if hook and Global("ContainerFrame_Update") and not ns.favoritesUpdateHooked then
			ns.favoritesUpdateHooked = pcall(hook, "ContainerFrame_Update", function() ns:FavoritesRefresh() end)
		end
		ns:FavoritesRefresh()
	end,
}

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("favorites:" .. tostring(event), err) end
end)
ns.favoritesEventFrame = eventFrame

if ns.Mark then ns.Mark("Favorites") end
