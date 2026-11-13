-- LootRoom.lua -- module QoL « Place au butin » (Ready2Quest 1.27.0)
--
-- Inspiré de l'addon Delete Cheapest Item : sacs pleins devant un butin, une
-- fenêtre s'ouvre toute seule (ou /r2q place). En haut, l'objet du butin qui
-- ne rentre pas (une quête d'abord, sinon le plus cher) ; dessous, les objets
-- les moins chers de tes sacs, prix du marchand et de l'hôtel des ventes
-- (Auctionator ou TSM, s'ils sont installés). Chaque ligne : [Jeter] et
-- [Ignorer]. Après [Jeter], l'objet du butin est ramassé tout seul.
--   * même choix d'objets que « Sac plein » (BagSpace.lua) : jamais d'objet
--     de quête, de clé, de pierre de foyer, de composant de classe ou de
--     recette suivie, ni de dernière nourriture ; la liste « toujours garder »
--     est celle de [Ignorer] ;
--   * 1.32.2 : ni outil de métier, ni objet de camp, ni composant d'un
--     métier connu, ni recette, caisse ou bandage (LootRoomKeepReason) ; la
--     liste entière défile à la molette ;
--   * un objet qui vaut plus que le butin reste proposé, mais en gris ;
--   * confirmation (réglable) pour un objet vert ou mieux : un clic de trop
--     dans un combat de butin arrive vite. Gris et blancs partent au clic.
-- Le clic sur [Jeter] (ou sur « Oui ») est l'événement matériel qui porte
-- DeleteCursorItem ; rien n'est jamais détruit sans clic.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

ns.LOOTROOM_ROWS = 8
local POPUP = "READY2QUEST_LOOTROOM_DESTROY"
local WIDTH = 480
local ROW_CARD, ROW_H = 36, 38       -- carte d'un objet, pas d'une ligne à l'autre
local TARGET_CARD, GAP = 44, 14

local FR = {
	OPT_PAGE_LOOTROOM      = "Place au butin",
	OPT_PAGE_LOOTROOM_SUB  = "Sacs pleins devant un butin : jette le moins cher, le butin est ramassé.",
	OPT_LOOTROOM_ENABLED   = "Activer le module",
	OPT_LOOTROOM_CONFIRM   = "Confirmer avant de jeter un objet vert ou mieux",
	OPT_LOOTROOM_AUCTION   = "Prix de l'hôtel des ventes (Auctionator, TSM)",
	LOOTROOM_TITLE         = "Place au butin",
	LOOTROOM_SUB           = "Les moins chers de tes sacs, à jeter pour le butin.",
	LOOTROOM_TARGET        = "Butin : %s ×%d — %s",
	LOOTROOM_TARGET_QUEST  = "Butin : %s ×%d — objet de quête",
	LOOTROOM_NO_TARGET     = "Les objets les moins chers de tes sacs.",
	LOOTROOM_EMPTY         = "Rien à proposer : tout ce qui reste dans tes sacs est protégé.",
	LOOTROOM_VENDOR        = "marchand %s",
	LOOTROOM_AUCTION       = "HV %s",
	LOOTROOM_NO_VALUE      = "sans valeur",
	LOOTROOM_DEARER        = "Vaut plus que le butin.",
	LOOTROOM_BTN_DELETE    = "Jeter",
	LOOTROOM_BTN_IGNORE    = "Ignorer",
	LOOTROOM_HINT          = "Jeter : détruit l'objet et ramasse le butin. Ignorer : ne plus jamais le proposer.",
	LOOTROOM_HINT_SCROLL   = "Molette : objets %d à %d sur %d. Jeter détruit, Ignorer ne propose plus.",
	LOOTROOM_CONFIRM       = "Détruire %s ×%d ?\nC'est définitif.",
	LOOTROOM_YES           = "Détruire",
	LOOTROOM_NO            = "Annuler",
	LOOTROOM_DELETED       = "Jeté : %s ×%d.",
	LOOTROOM_IGNORED       = "%s ne sera plus proposé (ajouté aux favoris).",
	HELP_LOOTROOM          = "/r2q place — les objets les moins chers de tes sacs, à jeter pour un butin",
}
local EN = {
	OPT_PAGE_LOOTROOM      = "Room for loot",
	OPT_PAGE_LOOTROOM_SUB  = "Full bags in front of loot: drop the cheapest item, the loot gets picked up.",
	OPT_LOOTROOM_ENABLED   = "Enable the module",
	OPT_LOOTROOM_CONFIRM   = "Confirm before dropping a green item or better",
	OPT_LOOTROOM_AUCTION   = "Auction house prices (Auctionator, TSM)",
	LOOTROOM_TITLE         = "Room for loot",
	LOOTROOM_SUB           = "The cheapest items in your bags, to drop for the loot.",
	LOOTROOM_TARGET        = "Loot: %s ×%d — %s",
	LOOTROOM_TARGET_QUEST  = "Loot: %s ×%d — quest item",
	LOOTROOM_NO_TARGET     = "The cheapest items in your bags.",
	LOOTROOM_EMPTY         = "Nothing to offer: everything left in your bags is protected.",
	LOOTROOM_VENDOR        = "vendor %s",
	LOOTROOM_AUCTION       = "AH %s",
	LOOTROOM_NO_VALUE      = "no value",
	LOOTROOM_DEARER        = "Worth more than the loot.",
	LOOTROOM_BTN_DELETE    = "Drop",
	LOOTROOM_BTN_IGNORE    = "Ignore",
	LOOTROOM_HINT          = "Drop: destroys the item and picks up the loot. Ignore: never offer it again.",
	LOOTROOM_HINT_SCROLL   = "Wheel: items %d to %d of %d. Drop destroys, Ignore never offers again.",
	LOOTROOM_CONFIRM       = "Destroy %s ×%d?\nThis cannot be undone.",
	LOOTROOM_YES           = "Destroy",
	LOOTROOM_NO            = "Cancel",
	LOOTROOM_DELETED       = "Dropped: %s ×%d.",
	LOOTROOM_IGNORED       = "%s will not be offered again (added to favorites).",
	HELP_LOOTROOM          = "/r2q place — the cheapest items in your bags, to drop for some loot",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.LOOTROOM_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({
	lootroomEnabled = true,
	lootroomConfirm = true,
	lootroomAuction = true,
})

if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "lootroom", title = "OPT_PAGE_LOOTROOM", parent = "qol", group = "OPT_GROUP_QOL",
		rows = {
			{ key = "lootroomEnabled", label = "OPT_LOOTROOM_ENABLED", kind = "bool" },
			{ key = "lootroomConfirm", label = "OPT_LOOTROOM_CONFIRM", kind = "bool" },
			{ key = "lootroomAuction", label = "OPT_LOOTROOM_AUCTION", kind = "bool" },
		},
	})
end
if ns.RegisterModule then
	ns.RegisterModule({ id = "lootroom", key = "lootroomEnabled", label = "OPT_PAGE_LOOTROOM", aliases = { "place", "butin" } })
end
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_MISC" and type(section[2]) == "table" then table.insert(section[2], "HELP_LOOTROOM") end
	end
end

-- ---------------------------------------------------------------------------
-- Accès au client
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
	local ok, a, b, c, d, e, f, g, h, i = pcall(fn, ...)
	if ok then return a, b, c, d, e, f, g, h, i end
	return nil
end
local function ModuleOn()
	local db = ns:DB()
	return db.enabled ~= false and db.lootroomEnabled ~= false
end
local function ItemIDFrom(link)
	return tonumber(tostring(link or ""):match("item:(%d+)"))
end
-- GetItemInfo rend 11 valeurs (le prix de vente en dernier) : on les garde toutes
local function ItemData(item)
	if item == nil then return nil end
	local name, link, quality, _, _, _, _, maxStack, _, texture, sellPrice = ns.ItemInfo(item)
	if not name then return nil end
	return { name = name, link = link, quality = quality, maxStack = maxStack, texture = texture, sellPrice = sellPrice }
end
local function Money(value)
	if not value or value <= 0 then return L.LOOTROOM_NO_VALUE end
	return ns.FormatMoney and ns:FormatMoney(value) or tostring(value)
end

-- Prix de l'hôtel des ventes d'une pile, si Auctionator ou TSM le connaît
function ns:LootRoomAuction(link, count)
	if self:DB().lootroomAuction == false or not link then return nil end
	local price
	local auctionator = rawget(_G, "Auctionator")
	local api = type(auctionator) == "table" and auctionator.API and auctionator.API.v1
	if type(api) == "table" and type(api.GetAuctionPriceByItemLink) == "function" then
		price = tonumber((Call(api.GetAuctionPriceByItemLink, ADDON, link)))
	end
	local tsm = rawget(_G, "TSM_API")
	if not price and type(tsm) == "table" and type(tsm.GetCustomPriceValue) == "function" and type(tsm.ToItemString) == "function" then
		local itemString = Call(tsm.ToItemString, link)
		if itemString then price = tonumber((Call(tsm.GetCustomPriceValue, "DBMarket", itemString))) end
	end
	if not price or price <= 0 then return nil end
	return price * (tonumber(count) or 1)
end

-- ---------------------------------------------------------------------------
-- Le butin qui ne rentre pas
-- ---------------------------------------------------------------------------
local function HasStackRoom(itemID, maxStack)
	local room = false
	local numSlots = ContainerFn("GetContainerNumSlots")
	local getInfo = ContainerFn("GetContainerItemInfo")
	for bag = 0, 4 do
		for slot = 1, tonumber((Call(numSlots, bag))) or 0 do
			local info = Call(getInfo, bag, slot)
			if type(info) == "table" and info.itemID == itemID and (info.stackCount or 1) < maxStack then room = true end
		end
	end
	return room
end

-- quêtes d'abord, puis les plus chers, puis l'ordre du butin
local function LootBefore(a, b)
	if a.quest ~= b.quest then return a.quest end
	if a.value ~= b.value then return a.value > b.value end
	return a.slot < b.slot
end

-- Objets du butin qui ne trouvent pas de place, du plus utile au moins utile :
-- les objets de quête d'abord, puis les plus chers
function ns:LootRoomLoot()
	local list = {}
	local total = tonumber((Call(Global("GetNumLootItems")))) or 0
	if total == 0 or (self.BagSpaceFreeSlots and self:BagSpaceFreeSlots() > 0) then return list end
	for slot = 1, total do
		local isItem = true
		if Global("LootSlotHasItem") then isItem = Call(Global("LootSlotHasItem"), slot) and true or false end
		local link = isItem and Call(Global("GetLootSlotLink"), slot)
		local itemID = ItemIDFrom(link)
		if itemID then
			local texture, _, quantity, _, quality, locked, isQuest, questID = Call(Global("GetLootSlotInfo"), slot)
			local data = ItemData(itemID) or {}
			local count = tonumber(quantity) or 1
			if not locked and not HasStackRoom(itemID, tonumber(data.maxStack) or 1) then
				local vendor = (tonumber(data.sellPrice) or 0) * count
				local auction = self:LootRoomAuction(link, count)
				list[#list + 1] = { slot = slot, itemID = itemID, link = link, count = count, texture = texture,
					quality = tonumber(quality) or 1, quest = (isQuest == true or questID ~= nil),
					vendor = vendor, auction = auction, value = math.max(vendor, auction or 0) }
			end
		end
	end
	table.sort(list, LootBefore)
	return list
end

-- ---------------------------------------------------------------------------
-- 1.32.2 : objets jamais proposés. « Sac plein » proposait des outils de
-- métier, des objets de camp, des composants : tout ce que le joueur garde.
-- Règles par données, dans l'ordre (la première qui protège l'emporte) :
--   1. outils de métier (pioche, marteau, couteau à dépecer, canne à pêche,
--      clé plate, bâtonnets runiques…) : par numéro, puis par nom FR/EN ;
--   2. objets de camp Forever : kits de feu de camp et objets de camp
--      (Camp.lua, ns.CAMP_DATA) ;
--   3. composants : classe « Composant » (5) toujours ; « Artisanat » (7)
--      si le personnage connaît un métier qui s'en sert (sous-classe →
--      métiers ; sous-classe générique : n'importe quel métier ; fenêtre de
--      compétences illisible : protégé par prudence) ;
--   4. recettes (9), objets de quête (12) et clés (13) ;
--   5. objets qui s'ouvrent (caisse, coffret : « hasLoot » du sac, ou le nom) ;
--   6. consommables dont les vérifications ont besoin : bandages et
--      trousses de soins (la dernière nourriture reste gardée par Sac plein).
-- Un objet de la liste « toujours jeter » de Sac plein passe quand même.
-- ---------------------------------------------------------------------------
local KEEP_TOOLS = {
	[2901] = true, [756] = true, [778] = true, [1819] = true, [1959] = true, [9465] = true, [20723] = true,  -- pioches
	[5956] = true,                                                                                       -- marteau de forgeron
	[7005] = true, [12709] = true, [19901] = true,                                                       -- couteaux à dépecer
	[6256] = true, [6365] = true, [6366] = true, [6367] = true, [12225] = true, [19022] = true, [19970] = true, -- cannes à pêche
	[6219] = true, [10498] = true,                                                                       -- clé plate, micro-ajusteur
	[6218] = true, [6339] = true, [11130] = true, [11145] = true, [16207] = true,                         -- bâtonnets runiques
	[9149] = true, [4471] = true,                                                                        -- pierre philosophale, briquet
}
-- repli par nom (objets Forever aux numéros inconnus), minuscules (ns.AsciiLower)
local KEEP_TOOL_NAMES = { "pioche de mineur", "mining pick", "marteau de forgeron", "blacksmith hammer",
	"couteau à dépecer", "skinning knife", "canne à pêche", "fishing pole", "clé plate", "arclight spanner",
	"bâtonnet runique", "runed copper rod", "runed silver rod", "runed golden rod", "runed truesilver rod",
	"runed arcanite rod" }
local CLASS_CONSUMABLE, CLASS_REAGENT, CLASS_TRADEGOODS, CLASS_RECIPE, CLASS_QUEST, CLASS_KEY = 0, 5, 7, 9, 12, 13
local SUBCLASS_BANDAGE = 7
-- Artisanat : sous-classe → métiers qui s'en servent (numéros de compétence)
local TRADE_SKILLS = {
	[1] = { 202 }, [2] = { 202 }, [3] = { 202 },              -- pièces, explosifs, appareils : ingénierie
	[5] = { 197, 129 },                                       -- tissu : couture, secourisme
	[6] = { 165 },                                            -- cuir : travail du cuir
	[7] = { 164, 202, 186 },                                  -- métal et pierre : forge, ingénierie, minage
	[8] = { 185 },                                            -- viande : cuisine
	[9] = { 171, 182 },                                       -- herbes : alchimie, herboristerie
	[10] = { 164, 165, 197, 171, 202, 333 },                  -- élémentaire
	[12] = { 333 },                                           -- enchantement
}
local OPENABLE_NAMES = { "caisse", "crate", "coffret", "lockbox", "sacoche de", "satchel" }
local CARE_NAMES = { "bandage", "trousse de premiers soins", "first aid kit", "trousse de soins" }

local function NameHas(name, words)
	if type(name) ~= "string" then return false end
	local low = ns.AsciiLower(name)
	for _, word in ipairs(words) do
		if low:find(word, 1, true) then return true end
	end
	return false
end

local function ItemKind(itemID)
	local fn = (C_Item and C_Item.GetItemInfoInstant) or Global("GetItemInfoInstant")
	local _, _, _, _, _, classID, subClassID = Call(fn, itemID)
	return tonumber(classID), tonumber(subClassID)
end

-- Contexte d'un passage : métiers connus, objets de camp
function ns:LootRoomKeepContext()
	local ctx = { camp = {}, skills = {}, anySkill = false, skillsKnown = false }
	local data = ns.CAMP_DATA or {}
	for _, list in ipairs({ data.kits or {}, data.objects or {} }) do
		for _, entry in ipairs(list) do ctx.camp[entry.item] = true end
	end
	if self.CampSkillRanks then
		local ranks, readable = self:CampSkillRanks()
		ctx.skillsKnown = readable == true
		for skill in pairs(ranks or {}) do ctx.skills[skill] = true; ctx.anySkill = true end
	end
	return ctx
end

-- Pourquoi garder cet objet ("tool", "camp", "trade", "recipe", "quest",
-- "open", "care"), ou nil s'il peut être proposé
function ns:LootRoomKeepReason(candidate, ctx)
	ctx = ctx or self:LootRoomKeepContext()
	local itemID = candidate.itemID
	local name = ns.ItemInfo(itemID)
	if type(name) ~= "string" and type(candidate.link) == "string" then name = candidate.link:match("%[(.-)%]") end
	if KEEP_TOOLS[itemID] or NameHas(name, KEEP_TOOL_NAMES) then return "tool" end
	if ctx.camp[itemID] then return "camp" end
	local classID, subClassID = ItemKind(itemID)
	if classID == CLASS_REAGENT then return "trade" end
	if classID == CLASS_TRADEGOODS then
		if not ctx.skillsKnown then return "trade" end
		local skills = TRADE_SKILLS[subClassID or 0]
		if not skills then
			if ctx.anySkill then return "trade" end
		else
			for _, skill in ipairs(skills) do
				if ctx.skills[skill] then return "trade" end
			end
		end
	end
	if classID == CLASS_RECIPE then return "recipe" end
	if classID == CLASS_QUEST or classID == CLASS_KEY then return "quest" end
	local info = Call(ContainerFn("GetContainerItemInfo"), candidate.bag, candidate.slot)
	if (type(info) == "table" and info.hasLoot == true) or NameHas(name, OPENABLE_NAMES) then return "open" end
	if (classID == CLASS_CONSUMABLE and subClassID == SUBCLASS_BANDAGE) or NameHas(name, CARE_NAMES) then return "care" end
	return nil
end

-- Les objets des sacs à proposer, les moins chers d'abord (choix de Sac plein).
-- 1.32.2 : tous les candidats (la fenêtre défile), objets gardés exclus.
function ns:LootRoomRows(target)
	local rows = {}
	if not self.BagSpaceCandidates then return rows end
	local ctx = self:LootRoomKeepContext()
	for _, candidate in ipairs(self:BagSpaceCandidates()) do
		if candidate.forced or not self:LootRoomKeepReason(candidate, ctx) then
			local auction = self:LootRoomAuction(candidate.link, candidate.count)
			local value = math.max(candidate.value or 0, auction or 0)
			rows[#rows + 1] = { bag = candidate.bag, slot = candidate.slot, itemID = candidate.itemID, link = candidate.link,
				count = candidate.count, quality = candidate.quality, vendor = candidate.value or 0, auction = auction,
				value = value, dearer = target ~= nil and not target.quest and value >= target.value }
		end
	end
	return rows
end

-- ---------------------------------------------------------------------------
-- Jeter, ignorer, ramasser
-- ---------------------------------------------------------------------------
-- Détruit la pile (si elle est toujours à sa place), puis ramasse le butin
-- dès que les sacs ont bougé (BAG_UPDATE_DELAYED)
function ns:LootRoomDestroy(row)
	if not row then return false end
	local info = Call(ContainerFn("GetContainerItemInfo"), row.bag, row.slot)
	if type(info) ~= "table" or info.itemID ~= row.itemID then return false end
	Call(ContainerFn("PickupContainerItem"), row.bag, row.slot)
	local hasItem = Global("CursorHasItem")
	if hasItem and not Call(hasItem) then return false end
	Call(Global("DeleteCursorItem"))
	self:Print(self:F("LOOTROOM_DELETED", tostring(row.link), row.count))
	local target = self.lootRoom and self.lootRoom.target
	if target then self.lootRoomPending = target.slot end
	-- le ramassage attend BAG_UPDATE_DELAYED (même fenêtre fermée entre-temps)
	if self.SyncEventGate then self:SyncEventGate("lootroom:bags") end
	return true
end

function ns:LootRoomDelete(row)
	if not row then return false end
	local db = self:DB()
	if db.lootroomConfirm ~= false and (tonumber(row.quality) or 1) >= 2 then
		local dialogs = rawget(_G, "StaticPopupDialogs")
		if type(dialogs) == "table" then
			dialogs[POPUP] = dialogs[POPUP] or {
				text = "%s", button1 = L.LOOTROOM_YES, button2 = L.LOOTROOM_NO,
				OnAccept = function(_, data) ns:LootRoomDestroy(data) end,
				timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
			}
			local popup = Call(Global("StaticPopup_Show"), POPUP, self:F("LOOTROOM_CONFIRM", tostring(row.link), row.count))
			if type(popup) == "table" then popup.data = row end
			self.lootRoomAsking = row
			return "confirm"
		end
	end
	return self:LootRoomDestroy(row)
end

function ns:LootRoomIgnore(row)
	if not row then return false end
	-- 1.34.0 : « Ignorer » met l'objet en favori (ex « toujours garder » de
	-- Sac plein), avec son nom affiché ; le message ci-dessous suffit
	local name = type(row.link) == "string" and row.link:match("%[(.-)%]") or nil
	if self.SetFavorite then
		self:SetFavorite(row.itemID, true, name or ("#" .. tostring(row.itemID)), true)
	else
		local db = self:DB()
		if type(db.favorites) ~= "table" then db.favorites = {} end
		db.favorites[row.itemID] = name or ("#" .. tostring(row.itemID))
	end
	self:Print(self:F("LOOTROOM_IGNORED", tostring(row.link)))
	self:LootRoomRefresh()
	return true
end

-- Les sacs ont bougé : le butin attendu se ramasse
function ns:LootRoomAfterBags()
	local slot = self.lootRoomPending
	if not slot then return false end
	self.lootRoomPending = nil
	Call(Global("LootSlot"), slot)
	self:LootRoomRefresh()
	return true
end

-- ---------------------------------------------------------------------------
-- La fenêtre
-- ---------------------------------------------------------------------------
local function Tooltip(owner, link, extra)
	local tip = rawget(_G, "GameTooltip")
	if type(tip) ~= "table" or not tip.SetOwner then return end
	tip:SetOwner(owner, "ANCHOR_RIGHT")
	if link and tip.SetHyperlink then pcall(tip.SetHyperlink, tip, link) end
	if extra then Theme.TooltipHint(tip, extra, true) end
	tip:Show()
end
local function HideTip() local tip = rawget(_G, "GameTooltip"); if tip and tip.Hide then tip:Hide() end end

-- Butin bloqué : l'infobulle du jeu pour sa case de butin, sinon son lien
function ns:LootRoomTargetTooltip(owner)
	local target = self.lootRoom and self.lootRoom.target
	local tip = rawget(_G, "GameTooltip")
	if not target or type(tip) ~= "table" or not tip.SetOwner then return nil end
	tip:SetOwner(owner, "ANCHOR_RIGHT")
	local how
	if type(tip.SetLootItem) == "function" and target.slot and pcall(tip.SetLootItem, tip, target.slot) then
		how = "loot"
	elseif type(target.link) == "string" and tip.SetHyperlink and pcall(tip.SetHyperlink, tip, target.link) then
		how = "link"
	end
	tip:Show()
	return how
end

-- hauteur pour `count` lignes (au moins une : la phrase « rien à proposer »)
local function LootRoomHeight(count)
	return Theme.HEADER_COMPACT_HEIGHT + 1 + GAP + TARGET_CARD + GAP + math.max(1, count) * ROW_H
		- (ROW_H - ROW_CARD) + GAP + Theme.DIALOG_FOOTER
end

function ns:EnsureLootRoom()
	if self.lootRoomFrame then return self.lootRoomFrame end
	if not (Theme and Theme.CreateDialog) then return nil end
	local frame = Theme.CreateDialog(UIParent, WIDTH, LootRoomHeight(ns.LOOTROOM_ROWS), { name = "Ready2QuestLootRoom",
		title = L.LOOTROOM_TITLE, subtitle = L.LOOTROOM_SUB })
	if not frame then return nil end
	frame:SetPoint("CENTER", UIParent, "CENTER", 260, 60)
	local pad, inner = frame.pad + 1, frame.innerWidth
	local top = frame.contentTop - GAP

	-- le butin bloqué, en tête : une carte à liseré ambre
	frame.targetCard = CreateFrame("Frame", nil, frame)
	frame.targetCard:SetSize(inner, TARGET_CARD)
	frame.targetCard:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, top)
	frame.targetCard.bg = Theme.Solid(frame.targetCard, "BACKGROUND", Theme.ROW, 1)
	frame.targetCard.bg:SetAllPoints()
	frame.targetCard.bar = Theme.Solid(frame.targetCard, "ARTWORK", Theme.GOLD, 1)
	frame.targetCard.bar:SetPoint("TOPLEFT", frame.targetCard, "TOPLEFT", 0, 0)
	frame.targetCard.bar:SetPoint("BOTTOMLEFT", frame.targetCard, "BOTTOMLEFT", 0, 0)
	frame.targetCard.bar:SetWidth(2)
	frame.targetIcon = Theme.CreateIcon(frame.targetCard, 28)
	frame.targetIcon:SetPoint("LEFT", frame.targetCard, "LEFT", 12, 0)
	frame.target = Theme.Text(frame.targetCard, Theme.F_LABEL, Theme.LABEL)
	frame.target:SetPoint("LEFT", frame.targetCard, "LEFT", 52, 0)
	frame.target:SetWidth(inner - 64)
	frame.target:SetJustifyH("LEFT")
	if frame.target.SetWordWrap then frame.target:SetWordWrap(false) end
	-- 1.34.0 : l'infobulle du butin bloqué (SetLootItem, sinon son lien)
	frame.targetZone = CreateFrame("Button", nil, frame.targetCard)
	frame.targetZone:SetAllPoints(frame.targetCard)
	frame.targetZone:SetScript("OnEnter", function(h) ns:LootRoomTargetTooltip(h) end)
	frame.targetZone:SetScript("OnLeave", HideTip)
	frame.targetZone:SetScript("OnClick", function()
		local target = ns.lootRoom and ns.lootRoom.target
		local shift = rawget(_G, "IsShiftKeyDown")
		if target and type(shift) == "function" and shift() then Call(Global("HandleModifiedItemClick"), target.link) end
	end)

	local rowsTop = top - TARGET_CARD - GAP
	frame.rows = {}
	for index = 1, ns.LOOTROOM_ROWS do
		local row = Theme.CreateListRow(frame, inner, ROW_CARD, { icon = 24 })
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, rowsTop - (index - 1) * ROW_H)
		row:SetIndex(index)
		row.ignore = Theme.CreateButton(row, nil, 24, L.LOOTROOM_BTN_IGNORE, function() ns:LootRoomIgnore(row.data) end, "outline")
		row.ignore:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		row.delete = Theme.CreateButton(row, nil, 24, L.LOOTROOM_BTN_DELETE, function() ns:LootRoomDelete(row.data) end, "primary")
		row.delete:SetPoint("RIGHT", row.ignore, "LEFT", -6, 0)
		local textWidth = inner - row.textLeft - row.delete:GetWidth() - row.ignore:GetWidth() - 8 - 6 - 12
		row.name = row.text
		row.name:ClearAllPoints()
		row.name:SetPoint("TOPLEFT", row, "TOPLEFT", row.textLeft, -5)
		row.name:SetWidth(textWidth)
		row.price = Theme.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT)
		row.price:SetPoint("TOPLEFT", row, "TOPLEFT", row.textLeft, -20)
		row.price:SetWidth(textWidth)
		row.price:SetJustifyH("LEFT")
		if row.price.SetWordWrap then row.price:SetWordWrap(false) end
		-- l'infobulle de l'objet au survol de son icône et de son nom
		row.tipZone = CreateFrame("Button", nil, row)
		row.tipZone:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.tipZone:SetSize(row.textLeft + textWidth, ROW_CARD)
		row.tipZone:SetScript("OnEnter", function(h)
			local data = row.data
			if data then Tooltip(h, data.link, data.dearer and L.LOOTROOM_DEARER or nil) end
		end)
		row.tipZone:SetScript("OnLeave", HideTip)
		-- 1.32.2 : la molette fait défiler la liste, où que soit la souris
		for _, part in ipairs({ row, row.tipZone }) do
			if part.EnableMouseWheel then part:EnableMouseWheel(true) end
			part:SetScript("OnMouseWheel", function(_, delta) ns:LootRoomScroll(delta) end)
		end
		row:Hide()
		frame.rows[index] = row
	end
	if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
	frame:SetScript("OnMouseWheel", function(_, delta) ns:LootRoomScroll(delta) end)
	-- 1.32.2 : glissière dans la marge droite (fond de ligne, curseur or)
	frame.track = Theme.Solid(frame, "ARTWORK", Theme.ROW, 1)
	frame.track:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + inner + 3, rowsTop)
	frame.track:SetSize(3, ns.LOOTROOM_ROWS * ROW_H - (ROW_H - ROW_CARD))
	frame.thumb = Theme.Solid(frame, "OVERLAY", Theme.GOLD, 1)
	frame.thumb:SetWidth(3)
	frame.rowsTop = rowsTop
	frame.track:Hide()
	frame.thumb:Hide()
	frame.empty = Theme.Text(frame, Theme.F_BODY, Theme.MUTED_LIGHT)
	frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 12, rowsTop - 6)
	frame.empty:SetWidth(inner - 24)
	frame.empty:SetJustifyH("LEFT")
	-- l'aide, dans le pied
	frame.hint = Theme.Text(frame.footer, Theme.F_SMALL, Theme.MUTED)
	frame.hint:SetPoint("LEFT", frame.footer, "LEFT", Theme.DIALOG_PAD, 0)
	frame.hint:SetWidth(inner)
	frame.hint:SetJustifyH("LEFT")
	frame.hint:SetText(L.LOOTROOM_HINT)
	frame:Hide()
	self.lootRoomFrame = frame
	return frame
end

function ns:LootRoomRefresh()
	local frame = self.lootRoomFrame
	if not (frame and frame:IsShown()) then return nil end
	local loot = self:LootRoomLoot()
	local target = loot[1]
	local rows = self:LootRoomRows(target)
	self.lootRoom = { target = target, rows = rows, loot = loot }
	if target then
		frame.target:SetText(target.quest and self:F("LOOTROOM_TARGET_QUEST", tostring(target.link), target.count)
			or self:F("LOOTROOM_TARGET", tostring(target.link), target.count, Money(target.value)))
		if frame.targetIcon.tex then frame.targetIcon.tex:SetTexture(target.texture) end
		frame.targetIcon:Show()
	else
		frame.target:SetText(L.LOOTROOM_NO_TARGET)
		frame.targetIcon:Hide()
	end
	-- 1.32.2 : fenêtre de ns.LOOTROOM_ROWS lignes sur la liste entière
	local visible = ns.LOOTROOM_ROWS
	local offset = math.max(0, math.min(tonumber(self.lootRoomOffset) or 0, #rows - visible))
	self.lootRoomOffset = offset
	self.lootRoom.offset = offset
	for index, row in ipairs(frame.rows) do
		local data = rows[offset + index]
		row.data = data
		if data then
			local item = ItemData(data.itemID) or {}
			if row.icon.tex then row.icon.tex:SetTexture(item.texture) end
			row.name:SetText(string.format("%s ×%d", tostring(data.link), data.count))
			local price = self:F("LOOTROOM_VENDOR", Money(data.vendor))
			if data.auction then price = price .. "  ·  " .. self:F("LOOTROOM_AUCTION", Money(data.auction)) end
			row.price:SetText(price)
			local c = data.dearer and Theme.MUTED or Theme.MUTED_LIGHT
			row.price:SetTextColor(c[1], c[2], c[3])
			-- 1.35.0 : plus cher que le butin = icône estompée, prix MUTED ; la
			-- ligne reste opaque (estompée à 55 %, le prix tombait à 2,6:1 et
			-- « Jeter » avait l'air désactivé alors qu'il marche)
			row:SetAlpha(1)
			if row.icon then row.icon:SetAlpha(data.dearer and 0.55 or 1) end
			row:Show()
		else
			row:Hide()
		end
	end
	frame.empty:SetText(#rows == 0 and L.LOOTROOM_EMPTY or "")
	local scrollable = #rows > visible
	if scrollable then
		frame.hint:SetText(self:F("LOOTROOM_HINT_SCROLL", offset + 1, offset + visible, #rows))
		local trackH = visible * ROW_H - (ROW_H - ROW_CARD)
		local thumbH = math.max(12, trackH * visible / #rows)
		frame.thumb:SetHeight(thumbH)
		frame.thumb:ClearAllPoints()
		frame.thumb:SetPoint("TOPLEFT", frame.track, "TOPLEFT", 0, -(trackH - thumbH) * offset / (#rows - visible))
		frame.track:Show()
		frame.thumb:Show()
	else
		frame.hint:SetText(L.LOOTROOM_HINT)
		frame.track:Hide()
		frame.thumb:Hide()
	end
	-- la fenêtre suit la liste : pas de cartes vides sous la dernière
	frame:SetHeight(LootRoomHeight(math.min(#rows, ns.LOOTROOM_ROWS)))
	return self.lootRoom
end

-- 1.32.2 : défilement d'une ligne par cran de molette
function ns:LootRoomScroll(delta)
	self.lootRoomOffset = (tonumber(self.lootRoomOffset) or 0) - (tonumber(delta) or 0)
	return self:LootRoomRefresh()
end

-- Ouvre la fenêtre ; `manual` : même sans butin bloqué
function ns:LootRoomOpen(manual)
	if not ModuleOn() and not manual then return nil end
	local frame = self:EnsureLootRoom()
	if not frame then return nil end
	if not manual and #self:LootRoomLoot() == 0 then return nil end
	local fresh = not frame:IsShown()
	if fresh then self.lootRoomOffset = 0 end
	frame:Show()
	-- la fenêtre suit les sacs tant qu'elle est ouverte
	if self.SyncEventGate then self:SyncEventGate("lootroom:bags") end
	self:LootRoomRefresh()
	-- 1.34.0 : à côté d'une fenêtre de QuestCompanion déjà ouverte (socle)
	if fresh and ns.PopupPlace then ns.PopupPlace(frame) end
	return frame
end

-- « Sac plein » laisse la place pendant un butin (BagSpace.lua le lit)
function ns:LootRoomActive()
	if not ModuleOn() then return false end
	return (tonumber((Call(Global("GetNumLootItems")))) or 0) > 0
end

-- ---------------------------------------------------------------------------
-- Événements, commande
-- ---------------------------------------------------------------------------
local HANDLERS = {
	LOOT_OPENED = function() if ModuleOn() then ns:LootRoomOpen(false) end end,
	LOOT_CLOSED = function()
		ns.lootRoomPending = nil
		if ns.lootRoomFrame then ns.lootRoomFrame:Hide() end
		if ns.SyncEventGate then ns:SyncEventGate("lootroom:bags") end
	end,
	UI_ERROR_MESSAGE = function(a, b)
		if ModuleOn() and ns.IsBagFullError and ns:IsBagFullError(a, b) and ns:LootRoomActive() then ns:LootRoomOpen(false) end
	end,
	BAG_UPDATE_DELAYED = function()
		if not ns:LootRoomAfterBags() and not ns:LootRoomRefresh() then
			-- fenêtre fermée (bouton, Échap), rien à ramasser : plus besoin des sacs
			if ns.SyncEventGate then ns:SyncEventGate("lootroom:bags") end
		end
	end,
}
local ok, eventFrame = pcall(CreateFrame, "Frame")
if ok and eventFrame then
	for event in pairs(HANDLERS) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
	eventFrame:SetScript("OnEvent", function(_, event, ...)
		local done, err = pcall(HANDLERS[event], ...)
		if not done and ns.RecordError then ns:RecordError("lootroom:" .. tostring(event), err) end
	end)
	ns.lootRoomEventFrame = eventFrame
	-- Module coupé : ni butin ni messages d'erreur. Les sacs (BAG_UPDATE_DELAYED)
	-- ne servent qu'à la fenêtre ouverte (même ouverte à la main, /r2q place,
	-- module coupé) ou à un ramassage en attente. LOOT_CLOSED reste abonné.
	if ns.FrameGate then
		ns.FrameGate("lootroom", {
			frame = eventFrame,
			events = { "LOOT_OPENED", "UI_ERROR_MESSAGE" },
			want = function() return ModuleOn() end,
		})
		ns.FrameGate("lootroom:bags", {
			frame = eventFrame,
			events = { "BAG_UPDATE_DELAYED" },
			want = function(self)
				local frame = self.lootRoomFrame
				return self.lootRoomPending ~= nil or (frame ~= nil and frame:IsShown() == true)
			end,
		})
	end
end

if type(ns.EXTRA_COMMANDS) == "table" then
	ns.EXTRA_COMMANDS["place"] = function(self) self:LootRoomOpen(true) end
end
if type(ns.EXCLUSIVE_WINDOWS) == "table" then table.insert(ns.EXCLUSIVE_WINDOWS, "lootRoomFrame") end

if ns.Mark then ns.Mark("LootRoom") end
