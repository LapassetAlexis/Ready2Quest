-- BagSpace.lua -- module QoL « Sac plein » (v1.24.0)
--
-- Sacs pleins loin d'une zone sûre : on propose l'objet qu'on perd le moins à
-- jeter, avec trois boutons [Jeter] [Autre] [Garder toujours]. Le module vit
-- tout entier dans ce fichier et ne s'appuie que sur l'API d'extension
-- (RegisterStrings, RegisterDefaults, AddOptionPage, RegisterModule) et sur
-- ns.EXTRA_COMMANDS, la seule ligne ajoutée à Core.lua.
--
-- Choix de l'objet, et pourquoi :
--   * critère : la valeur marchande de l'emplacement (prix de vente x pile).
--     Un emplacement libéré vaut la même chose quel que soit l'objet ; on
--     sacrifie donc celui qui rapporterait le moins chez le marchand.
--   * égalité : la qualité la plus basse d'abord (gris avant blanc).
--   * prix inconnu (objet pas encore en cache client) : jamais proposé. Mieux
--     vaut un choix de moins qu'un objet précieux classé « sans valeur ».
--   * jamais proposés : objets de quête, clés, pierre de foyer, composants de
--     classe (et munitions du chasseur), composants des recettes suivies,
--     nourriture si la jeter ferait passer sous le seuil des vivres, objets
--     verrouillés, liste « toujours garder ». Les sacs équipés ne sont pas
--     dans les emplacements parcourus : ils ne peuvent pas être proposés.
--   * la liste « toujours jeter » passe devant tout le reste.
--
-- Destruction : uniquement après un clic sur [Jeter] PUIS sur « Oui » dans une
-- fenêtre de confirmation (StaticPopup), jamais automatiquement. Le clic de
-- confirmation est l'événement matériel qui porte DeleteCursorItem.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local NUM_BAG_SLOTS  = 4      -- sacs 0 (sac de dos) à 4
local HEARTHSTONE    = 6948
local CLASS_PROJECTILE, CLASS_QUEST, CLASS_KEY = 6, 12, 13
local CHAT_COOLDOWN  = 30     -- secondes entre deux suggestions dans le chat
local POPUP          = "READY2QUEST_BAGSPACE_DESTROY"
local WIDTH, HEIGHT  = 340, 52
local LIST_SHOWN     = 6      -- objets affichés par liste dans les réglages

-- ---------------------------------------------------------------------------
-- Chaînes, réglages, page d'options, module
-- ---------------------------------------------------------------------------
local FR = {
	OPT_PAGE_BAGSPACE      = "Sac plein",
	OPT_PAGE_BAGSPACE_SUB  = "Sacs pleins en route : l'objet qui te coûte le moins à jeter.",
	OPT_BAGSPACE_ENABLED   = "Activer le module",
	OPT_BAGSPACE_FRAME     = "Cadre avec boutons (sinon chat seul)",
	OPT_BAGSPACE_CONFIRM   = "Confirmation avant de détruire : toujours",
	OPT_BAGSPACE_KEEP      = "TOUJOURS GARDER",
	OPT_BAGSPACE_DISCARD   = "TOUJOURS JETER EN PREMIER",
	OPT_BAGSPACE_EMPTY     = "(vide)",
	OPT_BAGSPACE_MORE      = "et %d autre(s)",
	OPT_BAGSPACE_HINT      = "/r2q garder [lien] et /r2q jeter-toujours [lien] ajoutent un objet, ou le retirent s'il y est déjà.",
	BAG_LINE               = "Sac plein — jette : %s ×%d (%s)",
	BAG_SUGGEST            = "Le moins coûteux à jeter : %s ×%d (%s). Places libres : %d.",
	BAG_NONE               = "Rien à proposer : tout ce qui reste dans tes sacs est protégé.",
	BAG_NO_VALUE           = "sans valeur",
	BAG_BTN_DESTROY        = "Jeter",
	BAG_BTN_NEXT           = "Autre",
	BAG_BTN_KEEP           = "Garder toujours",
	BAG_CONFIRM            = "Détruire %s ×%d ?\nC'est définitif.",
	BAG_YES                = "Détruire",
	BAG_NO                 = "Annuler",
	BAG_DESTROYED          = "Détruit : %s ×%d.",
	BAG_MOVED              = "L'objet a bougé dans tes sacs : rien n'a été détruit.",
	BAG_COMBAT             = "En combat : rien n'est détruit. À jeter à la main : %s ×%d (sac %d, case %d).",
	BAG_MANUAL             = "Destruction impossible depuis l'addon. À jeter à la main : %s ×%d (sac %d, case %d).",
	BAG_KEEP_ADDED         = "%s : toujours gardé, plus jamais proposé.",
	BAG_KEEP_REMOVED       = "%s : retiré de « toujours garder ».",
	BAG_DISCARD_ADDED      = "%s : proposé en premier quand les sacs sont pleins.",
	BAG_DISCARD_REMOVED    = "%s : retiré de « toujours jeter ».",
	BAG_NEED_ITEM          = "Indique un objet : /r2q garder [lien] (Maj+clic sur l'objet).",
	BAG_MODULE_OFF         = "Le module « Sac plein » est coupé (/r2q module sac on).",
	HELP_BAGSPACE          = "/r2q jeter -- l'objet le moins coûteux à jeter ; /r2q garder [lien], /r2q jeter-toujours [lien] -- listes",
}
local EN = {
	OPT_PAGE_BAGSPACE      = "Full bags",
	OPT_PAGE_BAGSPACE_SUB  = "Bags full on the road: the item that costs you the least to discard.",
	OPT_BAGSPACE_ENABLED   = "Enable the module",
	OPT_BAGSPACE_FRAME     = "Frame with buttons (else chat only)",
	OPT_BAGSPACE_CONFIRM   = "Confirmation before destroying: always",
	OPT_BAGSPACE_KEEP      = "ALWAYS KEEP",
	OPT_BAGSPACE_DISCARD   = "ALWAYS DISCARD FIRST",
	OPT_BAGSPACE_EMPTY     = "(empty)",
	OPT_BAGSPACE_MORE      = "and %d more",
	OPT_BAGSPACE_HINT      = "/r2q garder [link] and /r2q jeter-toujours [link] add an item, or remove it if it is already listed.",
	BAG_LINE               = "Bags full — discard: %s ×%d (%s)",
	BAG_SUGGEST            = "Cheapest to discard: %s ×%d (%s). Free slots: %d.",
	BAG_NONE               = "Nothing to suggest: everything left in your bags is protected.",
	BAG_NO_VALUE           = "no value",
	BAG_BTN_DESTROY        = "Discard",
	BAG_BTN_NEXT           = "Other",
	BAG_BTN_KEEP           = "Always keep",
	BAG_CONFIRM            = "Destroy %s ×%d?\nThis cannot be undone.",
	BAG_YES                = "Destroy",
	BAG_NO                 = "Cancel",
	BAG_DESTROYED          = "Destroyed: %s ×%d.",
	BAG_MOVED              = "The item moved in your bags: nothing was destroyed.",
	BAG_COMBAT             = "In combat: nothing destroyed. Discard it by hand: %s ×%d (bag %d, slot %d).",
	BAG_MANUAL             = "The addon cannot destroy it. Discard it by hand: %s ×%d (bag %d, slot %d).",
	BAG_KEEP_ADDED         = "%s: always kept, never suggested again.",
	BAG_KEEP_REMOVED       = "%s: removed from \"always keep\".",
	BAG_DISCARD_ADDED      = "%s: suggested first when bags are full.",
	BAG_DISCARD_REMOVED    = "%s: removed from \"always discard\".",
	BAG_NEED_ITEM          = "Name an item: /r2q garder [link] (Shift+click the item).",
	BAG_MODULE_OFF         = "The \"Full bags\" module is off (/r2q module sac on).",
	HELP_BAGSPACE          = "/r2q jeter -- the cheapest item to discard; /r2q garder [link], /r2q jeter-toujours [link] -- lists",
}
ns.RegisterStrings(FR, EN)
-- exposées aux tests : chaque clé doit exister dans les deux langues
ns.BAGSPACE_STRINGS = { fr = FR, en = EN }

ns.RegisterDefaults({
	bagspaceEnabled = true,
	bagspaceFrame   = true,
	bagspaceKeep    = {},   -- [itemID] = nom affiché
	bagspaceDiscard = {},   -- [itemID] = nom affiché
})

-- Pas de réglage « Demander confirmation » : détruire un objet est
-- irréversible (aucun rachat possible, contrairement à une vente), et un clic
-- égaré sur un cadre qui apparaît en plein combat de butin arrive vite. La
-- confirmation est donc toujours demandée ; la page l'affiche, sans bouton.
if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "bagspace", title = "OPT_PAGE_BAGSPACE", parent = "qol", group = "OPT_GROUP_QOL",
		rows = {
			{ key = "bagspaceEnabled", label = "OPT_BAGSPACE_ENABLED", kind = "bool" },
			{ key = "bagspaceFrame",   label = "OPT_BAGSPACE_FRAME",   kind = "bool" },
		},
	})
end

if ns.RegisterModule then
	ns.RegisterModule({ id = "bagspace", key = "bagspaceEnabled", label = "OPT_PAGE_BAGSPACE",
		aliases = { "sac", "bags", "sacplein" } })
end

-- l'aide liste la commande, dans la rubrique « Divers »
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_MISC" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_BAGSPACE")
		end
	end
end

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

local function InCombat()
	local fn = Global("InCombatLockdown")
	if not fn then return false end
	local ok, res = pcall(fn)
	return ok and res and true or false
end

local function ModuleOn()
	local db = ns:DB()
	return db.enabled ~= false and db.bagspaceEnabled ~= false
end

local function ItemInfo(item)
	local fn = (C_Item and C_Item.GetItemInfo) or Global("GetItemInfo")
	if type(fn) ~= "function" or item == nil then return nil end
	local r = { pcall(fn, item) }
	if not r[1] then return nil end
	-- name, link, quality, level, minLevel, type, subType, maxStack, equipLoc, texture, sellPrice
	return { name = r[2], link = r[3], quality = r[4], maxStack = r[9], sellPrice = r[12] }
end

local function ItemClass(itemID)
	local fn = (C_Item and C_Item.GetItemInfoInstant) or Global("GetItemInfoInstant")
	if type(fn) ~= "function" then return nil end
	local ok, _, _, _, _, _, classID = pcall(fn, itemID)
	if ok then return classID end
	return nil
end

local function ContainerInfo(bag, slot)
	local fn = ContainerFn("GetContainerItemInfo")
	if not fn then return nil end
	local ok, info = pcall(fn, bag, slot)
	if ok and type(info) == "table" and info.itemID then return info end
	return nil
end

local function EachBagItem(fn)
	local numSlots = ContainerFn("GetContainerNumSlots")
	if not numSlots then return end
	for bag = 0, NUM_BAG_SLOTS do
		local ok, slots = pcall(numSlots, bag)
		if ok and type(slots) == "number" then
			for slot = 1, slots do
				local info = ContainerInfo(bag, slot)
				if info then fn(bag, slot, info) end
			end
		end
	end
end

-- Places libres des sacs ordinaires : un sac d'âmes ou un carquois vide ne
-- recevra jamais le butin, il ne compte pas (2e retour = type de sac).
function ns:BagSpaceFreeSlots()
	local fn = ContainerFn("GetContainerNumFreeSlots")
	if not fn then return ns.FreeBagSlots and ns.FreeBagSlots() or 0 end
	local free = 0
	for bag = 0, NUM_BAG_SLOTS do
		local ok, count, bagType = pcall(fn, bag)
		if ok and type(count) == "number" and (bagType == nil or bagType == 0) then free = free + count end
	end
	return free
end

local function ItemIDFrom(text)
	if type(text) == "number" then return text end
	if type(text) ~= "string" then return nil end
	return tonumber(text:match("item:(%d+)")) or tonumber(text:match("^%s*(%d+)%s*$"))
end

-- Nom lisible d'un objet : [Nom] du lien, sinon le nom du client, sinon #id
local function DisplayName(itemID, link)
	if type(link) == "string" then
		local name = link:match("%[(.-)%]")
		if name then return name end
	end
	local info = ItemInfo(itemID)
	if info and type(info.name) == "string" then return info.name end
	return "#" .. tostring(itemID)
end

-- ---------------------------------------------------------------------------
-- Objets protégés
-- ---------------------------------------------------------------------------
local function PlayerClass()
	local fn = Global("UnitClass")
	if not fn then return nil end
	local ok, _, token = pcall(fn, "player")
	if ok then return token end
	return nil
end

-- Composants de classe (table de Checks.lua) et composants des recettes
-- suivies (C_TradeSkillUI des clients récents). Sur Era, la recette ouverte
-- dans la fenêtre de métier n'est connue que de Reagents.lua, qui ne l'expose
-- pas : on ne devine rien plutôt que d'ajouter une dépendance.
local function ProtectedItems()
	local set = { [HEARTHSTONE] = true }
	for _, req in ipairs((ns.CLASS_REAGENTS or {})[PlayerClass() or ""] or {}) do
		for _, itemID in ipairs(req.items or {}) do set[itemID] = true end
	end
	local api = rawget(_G, "C_TradeSkillUI")
	if type(api) == "table" and type(api.GetRecipesTracked) == "function" and type(api.GetRecipeSchematic) == "function" then
		local ok, recipes = pcall(api.GetRecipesTracked, false)
		if ok and type(recipes) == "table" then
			for _, recipeID in ipairs(recipes) do
				local okS, schematic = pcall(api.GetRecipeSchematic, recipeID, false)
				local slots = okS and type(schematic) == "table" and schematic.reagentSlotSchematics
				if type(slots) == "table" then
					for _, slot in ipairs(slots) do
						for _, reagent in ipairs(type(slot.reagents) == "table" and slot.reagents or {}) do
							if type(reagent.itemID) == "number" then set[reagent.itemID] = true end
						end
					end
				end
			end
		end
	end
	return set
end

local function IsQuestSlot(bag, slot)
	local fn = ContainerFn("GetContainerItemQuestInfo")
	if not fn then return false end
	local ok, info = pcall(fn, bag, slot)
	return ok and type(info) == "table" and (info.isQuestItem == true or info.questID ~= nil)
end

local function IsFood(itemID)
	return ns.ConsumableKind ~= nil and ns.ConsumableKind(itemID) == "food"
end

-- ---------------------------------------------------------------------------
-- Candidats
-- ---------------------------------------------------------------------------
local function ListOf(db, key)
	if type(db[key]) ~= "table" then db[key] = {} end
	return db[key]
end

-- Prix de vente unitaire : 0 si l'objet ne se vend pas, nil si inconnu
local function SellPrice(info)
	if info.hasNoValue then return 0 end
	local data = ItemInfo(info.itemID)
	if not data then return nil end
	return tonumber(data.sellPrice)
end

local function Before(a, b)
	if a.forced ~= b.forced then return a.forced end
	if a.value ~= b.value then return a.value < b.value end
	if a.quality ~= b.quality then return a.quality < b.quality end
	if a.bag ~= b.bag then return a.bag < b.bag end
	return a.slot < b.slot
end

function ns:BagSpaceCandidates()
	local db = self:DB()
	local keep, discard = ListOf(db, "bagspaceKeep"), ListOf(db, "bagspaceDiscard")
	local protected = ProtectedItems()
	local hunter = PlayerClass() == "HUNTER"

	-- Nourriture : on ne propose une pile que si, sans elle, il en reste au
	-- moins le seuil des vivres. Jeter sa dernière nourriture loin d'une
	-- auberge coûte bien plus que sa valeur marchande.
	local food = 0
	EachBagItem(function(_, _, info)
		if IsFood(info.itemID) then food = food + (info.stackCount or 1) end
	end)
	local threshold = tonumber(db.vivresThreshold) or 1

	local list = {}
	EachBagItem(function(bag, slot, info)
		local itemID = info.itemID
		local count = info.stackCount or 1
		if protected[itemID] or keep[itemID] ~= nil or info.isLocked then return end
		local classID = ItemClass(itemID)
		if classID == CLASS_QUEST or classID == CLASS_KEY then return end
		if hunter and classID == CLASS_PROJECTILE then return end
		if IsQuestSlot(bag, slot) then return end
		if IsFood(itemID) and food - count < threshold then return end
		local forced = discard[itemID] ~= nil
		local price = SellPrice(info)
		if price == nil and not forced then return end
		local quality = info.quality
		if type(quality) ~= "number" then
			local data = ItemInfo(itemID)
			quality = data and data.quality
		end
		list[#list + 1] = {
			bag = bag, slot = slot, itemID = itemID, count = count,
			quality = tonumber(quality) or 1,
			link = info.hyperlink or DisplayName(itemID),
			value = (price or 0) * count,
			forced = forced,
		}
	end)
	table.sort(list, Before)
	return list
end

function ns:BagSpaceCurrent()
	local state = self.bagspace
	if not state or #state.list == 0 then return nil end
	return state.list[state.index]
end

local function ValueText(candidate)
	if candidate.value <= 0 then return L.BAG_NO_VALUE end
	return ns:FormatMoney(candidate.value)
end

function ns:BagSpaceLine(candidate)
	return self:F("BAG_LINE", tostring(candidate.link), candidate.count, ValueText(candidate))
end

-- Nouvelle liste ; si le cadre montrait un objet encore présent au même
-- endroit, on le garde (un second message d'erreur ne doit pas annuler [Autre]).
function ns:BagSpaceRebuild()
	local previous = self:BagSpaceCurrent()
	local list = self:BagSpaceCandidates()
	local index = 1
	if previous then
		for i, c in ipairs(list) do
			if c.bag == previous.bag and c.slot == previous.slot and c.itemID == previous.itemID then index = i; break end
		end
	end
	self.bagspace = { list = list, index = index }
	return list
end

-- ---------------------------------------------------------------------------
-- Déclenchement
-- ---------------------------------------------------------------------------
-- Messages d'erreur « sacs pleins » : les globales du client (dans sa langue),
-- puis un repli fr/en. ERR_LOOT_GONE (« l'objet n'est plus disponible ») n'en
-- fait pas partie : il dit que quelqu'un d'autre a pris le butin, pas que les
-- sacs débordent.
local ERROR_GLOBALS = { "ERR_INV_FULL", "ERR_BAG_FULL" }
local ERROR_IDS     = { "LE_GAME_ERR_INV_FULL", "LE_GAME_ERR_BAG_FULL" }
local ERROR_FALLBACK = {
	"inventory is full", "that bag is full",
	"l'inventaire est plein", "votre inventaire est plein", "ce sac est plein",
}

local function Normalize(text)
	text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("\226\128\153", "'"):lower()   -- apostrophe typographique
	text = text:gsub("^%s+", ""):gsub("[%s%.!]+$", "")
	return text
end

-- Signature de UI_ERROR_MESSAGE : (messageType, message) sur les clients
-- récents, (message) sur les anciens. On accepte les deux.
function ns:IsBagFullError(a, b)
	if type(a) == "number" then
		for _, name in ipairs(ERROR_IDS) do
			local id = rawget(_G, name)
			if type(id) == "number" and id == a then return true end
		end
	end
	local message = (type(a) == "string" and a) or (type(b) == "string" and b) or nil
	if not message then return false end
	message = Normalize(message)
	if message == "" then return false end
	for _, name in ipairs(ERROR_GLOBALS) do
		local text = rawget(_G, name)
		if type(text) == "string" and Normalize(text) == message then return true end
	end
	for _, text in ipairs(ERROR_FALLBACK) do
		if text == message then return true end
	end
	return false
end

-- Butin ouvert, sacs pleins : un objet du butin rentre-t-il quelque part ?
-- Seulement s'il complète une pile existante du même objet.
function ns:BagSpaceLootBlocked()
	local num, getLink = Global("GetNumLootItems"), Global("GetLootSlotLink")
	if not (num and getLink) then return false end
	local ok, total = pcall(num)
	if not ok or type(total) ~= "number" then return false end
	local hasItem = Global("LootSlotHasItem")
	for i = 1, total do
		local okItem, isItem = true, true
		if hasItem then okItem, isItem = pcall(hasItem, i) end
		if okItem and isItem then
			local okLink, link = pcall(getLink, i)
			local itemID = okLink and ItemIDFrom(link)
			if itemID then
				local data = ItemInfo(itemID)
				local maxStack = data and tonumber(data.maxStack) or 1
				local room = false
				EachBagItem(function(_, _, info)
					if info.itemID == itemID and (info.stackCount or 1) < maxStack then room = true end
				end)
				if not room then return true end
			end
		end
	end
	return false
end

function ns:BagSpaceChat(text, force)
	local now = ns.Now()
	if not force and self.bagspaceChatAt and now - self.bagspaceChatAt < CHAT_COOLDOWN then return false end
	self.bagspaceChatAt = now
	self:Print(text)
	return true
end

-- Sacs pleins détectés : cadre si possible, sinon une ligne dans le chat
function ns:BagSpaceAlert()
	if not ModuleOn() then return nil end
	-- « en route » seulement : en zone sûre ou chez un marchand, on vend
	if self.inSafe == true or self.merchantOpen == true then return nil end
	if self:BagSpaceFreeSlots() > 0 then return nil end

	local list = self:BagSpaceRebuild()
	local candidate = self:BagSpaceCurrent()
	if not candidate then
		self:BagSpaceChat(L.BAG_NONE)
		return nil
	end
	if self:DB().bagspaceFrame ~= false and not InCombat() and self:ShowBagSpaceFrame() then
		return "frame"
	end
	self:BagSpaceChat(self:BagSpaceLine(candidate))
	return #list > 0 and "chat" or nil
end

-- ---------------------------------------------------------------------------
-- Actions : [Autre], [Garder toujours], [Jeter]
-- ---------------------------------------------------------------------------
function ns:BagSpaceNext()
	local state = self.bagspace
	if not state or #state.list == 0 then return nil end
	state.index = (state.index % #state.list) + 1
	self:RefreshBagSpaceFrame()
	return self:BagSpaceCurrent()
end

local function ToggleList(key, otherKey, itemID, name)
	local db = ns:DB()
	local list = ListOf(db, key)
	if list[itemID] ~= nil then list[itemID] = nil; return false end
	list[itemID] = name
	-- un objet ne peut pas être à la fois « garder » et « jeter »
	ListOf(db, otherKey)[itemID] = nil
	return true
end

function ns:BagSpaceToggleKeep(itemID, name)
	local added = ToggleList("bagspaceKeep", "bagspaceDiscard", itemID, name or DisplayName(itemID))
	self:Print(self:F(added and "BAG_KEEP_ADDED" or "BAG_KEEP_REMOVED", name or DisplayName(itemID)))
	if self.RefreshOptions then self:RefreshOptions() end
	return added
end

function ns:BagSpaceToggleDiscard(itemID, name)
	local added = ToggleList("bagspaceDiscard", "bagspaceKeep", itemID, name or DisplayName(itemID))
	self:Print(self:F(added and "BAG_DISCARD_ADDED" or "BAG_DISCARD_REMOVED", name or DisplayName(itemID)))
	if self.RefreshOptions then self:RefreshOptions() end
	return added
end

function ns:BagSpaceKeepCurrent()
	local candidate = self:BagSpaceCurrent()
	if not candidate then return nil end
	local name = DisplayName(candidate.itemID, candidate.link)
	ListOf(self:DB(), "bagspaceKeep")[candidate.itemID] = name
	ListOf(self:DB(), "bagspaceDiscard")[candidate.itemID] = nil
	self:Print(self:F("BAG_KEEP_ADDED", name))
	local list = self:BagSpaceCandidates()
	self.bagspace = { list = list, index = 1 }
	if #list == 0 then
		self:HideBagSpaceFrame()
		self:Print(L.BAG_NONE)
	else
		self:RefreshBagSpaceFrame()
	end
	if self.RefreshOptions then self:RefreshOptions() end
	return self:BagSpaceCurrent()
end

local function DestroyApi()
	local pickup, delete = ContainerFn("PickupContainerItem"), Global("DeleteCursorItem")
	if not (pickup and delete and Global("StaticPopup_Show") and type(rawget(_G, "StaticPopupDialogs")) == "table") then
		return nil
	end
	return pickup, delete
end

local function HandText(key, c)
	-- numéros vus par le joueur : le sac de dos est le sac 1
	return ns:F(key, tostring(c.link), c.count, c.bag + 1, c.slot)
end

local function EnsurePopup()
	local dialogs = rawget(_G, "StaticPopupDialogs")
	if type(dialogs) ~= "table" then return false end
	dialogs[POPUP] = dialogs[POPUP] or {
		text = L.BAG_CONFIRM,
		button1 = L.BAG_YES,
		button2 = L.BAG_NO,
		OnAccept = function(_, data) ns:BagSpaceDestroy(data) end,
		OnCancel = function() ns.bagspacePending = nil end,
		timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1, preferredIndex = 3,
	}
	return true
end

-- Clic sur [Jeter] : on DEMANDE. Aucune destruction ici, quoi qu'il arrive.
function ns:BagSpaceRequestDestroy()
	local c = self:BagSpaceCurrent()
	if not c then return false end
	if InCombat() then self:Print(HandText("BAG_COMBAT", c)); return false end
	if not DestroyApi() or not EnsurePopup() then self:Print(HandText("BAG_MANUAL", c)); return false end
	local data = { bag = c.bag, slot = c.slot, itemID = c.itemID, count = c.count, link = c.link }
	local ok, dialog = pcall(StaticPopup_Show, POPUP, tostring(c.link), c.count, data)
	if not ok or not dialog then self:Print(HandText("BAG_MANUAL", c)); return false end
	if type(dialog) == "table" then dialog.data = data end
	self.bagspacePending = data
	return true
end

-- « Détruire » confirmé (clic du joueur dans la fenêtre de confirmation).
-- On revérifie l'emplacement : entre les deux clics, le joueur a pu trier
-- ses sacs, et c'est alors un autre objet qui serait détruit.
function ns:BagSpaceDestroy(data)
	self.bagspacePending = nil
	if type(data) ~= "table" then return false end
	local c = data
	if InCombat() then self:Print(HandText("BAG_COMBAT", c)); return false end
	local pickup, delete = DestroyApi()
	if not pickup then self:Print(HandText("BAG_MANUAL", c)); return false end
	local info = ContainerInfo(c.bag, c.slot)
	if not info or info.itemID ~= c.itemID or (info.stackCount or 1) ~= c.count or info.isLocked then
		self:Print(L.BAG_MOVED)
		return false
	end
	local cursorInfo, clear = Global("GetCursorInfo"), Global("ClearCursor")
	-- curseur déjà occupé (objet, sort) : on le vide, sinon on détruirait ça
	if cursorInfo and cursorInfo() ~= nil then
		if clear then clear() end
		if cursorInfo() ~= nil then self:Print(L.BAG_MOVED); return false end
	end
	pickup(c.bag, c.slot)
	if cursorInfo then
		local kind, id = cursorInfo()
		if kind ~= "item" or id ~= c.itemID then
			if clear then clear() end
			self:Print(L.BAG_MOVED)
			return false
		end
	end
	delete()
	self:Print(self:F("BAG_DESTROYED", tostring(c.link), c.count))
	self.bagspace = nil
	self:HideBagSpaceFrame()
	return true
end

-- ---------------------------------------------------------------------------
-- Cadre discret, près des sacs
-- ---------------------------------------------------------------------------
function ns:EnsureBagSpaceFrame()
	if self.bagspaceFrame then return self.bagspaceFrame end
	if not Theme or not Theme.CreateDiscreet or not Theme.CreateButton then return nil end
	local ok, frame = pcall(Theme.CreateDiscreet, UIParent, WIDTH, HEIGHT)
	if not ok or not frame then return nil end
	frame:SetFrameStrata("DIALOG")
	-- au-dessus des sacs ouverts, en bas à droite de l'écran
	if self.RestorePoint then self:RestorePoint(frame, "bagspacePoint", { point = "BOTTOMRIGHT", x = -240, y = 180 }) end

	frame.text = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -7)
	frame.text:SetWidth(WIDTH - 36)
	frame.text:SetJustifyH("LEFT")
	frame.text:SetWordWrap(false)

	frame.closeButton = Theme.CreateButton(frame, 16, 16, "x", function() ns:HideBagSpaceFrame() end)
	frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

	frame.destroyButton = Theme.CreateButton(frame, 80, 18, L.BAG_BTN_DESTROY, function() ns:BagSpaceRequestDestroy() end, "primary")
	frame.destroyButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 7)
	frame.nextButton = Theme.CreateButton(frame, 80, 18, L.BAG_BTN_NEXT, function() ns:BagSpaceNext() end)
	frame.nextButton:SetPoint("LEFT", frame.destroyButton, "RIGHT", 6, 0)
	frame.keepButton = Theme.CreateButton(frame, 120, 18, L.BAG_BTN_KEEP, function() ns:BagSpaceKeepCurrent() end)
	frame.keepButton:SetPoint("LEFT", frame.nextButton, "RIGHT", 6, 0)

	frame:Hide()
	self.bagspaceFrame = frame
	return frame
end

function ns:RefreshBagSpaceFrame()
	local frame = self.bagspaceFrame
	local c = self:BagSpaceCurrent()
	if not frame then return end
	if not c then frame:Hide(); return end
	frame.text:SetText(self:BagSpaceLine(c))
end

function ns:ShowBagSpaceFrame()
	local frame = self:EnsureBagSpaceFrame()
	if not frame or not self:BagSpaceCurrent() then return nil end
	self:RefreshBagSpaceFrame()
	if not frame:IsShown() then
		frame:Show()
		if Theme.FadeIn then Theme.FadeIn(frame, 0.15) end
	end
	return frame
end

function ns:HideBagSpaceFrame()
	if self.bagspaceFrame then self.bagspaceFrame:Hide() end
end

-- ---------------------------------------------------------------------------
-- Commandes : /r2q jeter (ou sac), /r2q garder [lien], /r2q jeter-toujours [lien]
-- ---------------------------------------------------------------------------
function ns:BagSpaceCommand()
	if not ModuleOn() then return self:Print(L.BAG_MODULE_OFF) end
	self:BagSpaceRebuild()
	local c = self:BagSpaceCurrent()
	if not c then return self:Print(L.BAG_NONE) end
	self:Print(self:F("BAG_SUGGEST", tostring(c.link), c.count, ValueText(c), self:BagSpaceFreeSlots()))
end

local function ListCommand(toggle)
	return function(self, rest)
		if not ModuleOn() then return self:Print(L.BAG_MODULE_OFF) end
		local itemID = ItemIDFrom(rest)
		if not itemID then return self:Print(L.BAG_NEED_ITEM) end
		toggle(self, itemID, DisplayName(itemID, rest))
	end
end

ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["jeter"] = function(self) self:BagSpaceCommand() end
ns.EXTRA_COMMANDS["sac"] = ns.EXTRA_COMMANDS["jeter"]
ns.EXTRA_COMMANDS["garder"] = ListCommand(ns.BagSpaceToggleKeep)
ns.EXTRA_COMMANDS["jeter-toujours"] = ListCommand(ns.BagSpaceToggleDiscard)

-- ---------------------------------------------------------------------------
-- Page de réglages : la ligne de confirmation et les deux listes, sous les
-- interrupteurs. Options.lua ne sait construire que des réglages : on ajoute
-- ce bloc à la page une fois construite, au premier rafraîchissement.
-- ---------------------------------------------------------------------------
local function ListText(list)
	local names = {}
	for _, name in pairs(list) do names[#names + 1] = tostring(name) end
	if #names == 0 then return Theme.T_GREY .. L.OPT_BAGSPACE_EMPTY .. "|r" end
	table.sort(names)
	local shown = {}
	for i = 1, math.min(#names, LIST_SHOWN) do shown[i] = names[i] end
	local text = table.concat(shown, ", ")
	if #names > LIST_SHOWN then text = text .. " " .. ns:F("OPT_BAGSPACE_MORE", #names - LIST_SHOWN) end
	return text
end

function ns:BagSpaceRefreshPage()
	local frame = self.optionsFrame
	local page = frame and frame.pages and frame.pages.bagspace
	if not page then return end
	if not page.bagspaceBlock then
		local y = page.contentBottom or -100
		local width = page.GetWidth and page:GetWidth() or 360
		local block = {}
		local function Text(font, offset, height)
			local fs = page:CreateFontString(nil, "OVERLAY", font)
			fs:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - offset)
			fs:SetWidth(width)
			if height then fs:SetHeight(height) end
			fs:SetJustifyH("LEFT")
			return fs
		end
		block.confirm = Text(Theme.F_BODY, 0)
		block.confirm:SetText(L.OPT_BAGSPACE_CONFIRM)
		block.keepHeader = Text(Theme.F_SMALL, 26)
		block.keepHeader:SetText(L.OPT_BAGSPACE_KEEP)
		block.keepHeader:SetTextColor(Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3])
		block.keep = Text(Theme.F_BODY, 42, 30)
		block.discardHeader = Text(Theme.F_SMALL, 80)
		block.discardHeader:SetText(L.OPT_BAGSPACE_DISCARD)
		block.discardHeader:SetTextColor(Theme.GOLD_SOFT[1], Theme.GOLD_SOFT[2], Theme.GOLD_SOFT[3])
		block.discard = Text(Theme.F_BODY, 96, 30)
		block.hint = Text(Theme.F_SMALL, 134, 30)
		block.hint:SetText(L.OPT_BAGSPACE_HINT)
		block.hint:SetTextColor(0.55, 0.55, 0.55)
		page.bagspaceBlock = block
		page.contentBottom = y - 164
	end
	local db = self:DB()
	page.bagspaceBlock.keep:SetText(ListText(ListOf(db, "bagspaceKeep")))
	page.bagspaceBlock.discard:SetText(ListText(ListOf(db, "bagspaceDiscard")))
end

if type(ns.RefreshOptions) == "function" then
	local baseRefresh = ns.RefreshOptions
	function ns:RefreshOptions(...)
		baseRefresh(self, ...)
		local ok, err = pcall(self.BagSpaceRefreshPage, self)
		if not ok and self.RecordError then self:RecordError("bagspace:options", err) end
	end
end

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
local function OnBagUpdate()
	-- une place s'est libérée (vente, objet consommé, jeté à la main) : le
	-- cadre n'a plus lieu d'être ; sinon on suit les objets qui ont bougé
	local frame = ns.bagspaceFrame
	if not frame or not frame:IsShown() then return end
	if ns:BagSpaceFreeSlots() > 0 then ns:HideBagSpaceFrame(); return end
	ns:BagSpaceRebuild()
	ns:RefreshBagSpaceFrame()
end

local HANDLERS = {
	UI_ERROR_MESSAGE = function(a, b) if ns:IsBagFullError(a, b) then ns:BagSpaceAlert() end end,
	LOOT_OPENED      = function()
		if ModuleOn() and ns:BagSpaceFreeSlots() == 0 and ns:BagSpaceLootBlocked() then ns:BagSpaceAlert() end
	end,
	BAG_UPDATE_DELAYED = OnBagUpdate,
	BAG_UPDATE         = OnBagUpdate,
}

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do
	-- un événement inconnu du client ne doit pas bloquer les autres
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if not ModuleOn() then return end
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("bagspace:" .. tostring(event), err) end
end)
ns.bagspaceEventFrame = eventFrame

if ns.Mark then ns.Mark("BagSpace") end
