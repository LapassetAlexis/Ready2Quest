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
local WIDTH, ROW_H = 400, 30

local FR = {
	OPT_PAGE_LOOTROOM      = "Place au butin",
	OPT_PAGE_LOOTROOM_SUB  = "Sacs pleins devant un butin : jette le moins cher, le butin est ramassé.",
	OPT_LOOTROOM_ENABLED   = "Activer le module",
	OPT_LOOTROOM_CONFIRM   = "Confirmer avant de jeter un objet vert ou mieux",
	OPT_LOOTROOM_AUCTION   = "Prix de l'hôtel des ventes (Auctionator, TSM)",
	LOOTROOM_TITLE         = "Place au butin",
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
	LOOTROOM_CONFIRM       = "Détruire %s ×%d ?\nC'est définitif.",
	LOOTROOM_YES           = "Détruire",
	LOOTROOM_NO            = "Annuler",
	LOOTROOM_DELETED       = "Jeté : %s ×%d.",
	LOOTROOM_IGNORED       = "%s ne sera plus proposé (liste « toujours garder »).",
	HELP_LOOTROOM          = "/r2q place — les objets les moins chers de tes sacs, à jeter pour un butin",
}
local EN = {
	OPT_PAGE_LOOTROOM      = "Room for loot",
	OPT_PAGE_LOOTROOM_SUB  = "Full bags in front of loot: drop the cheapest item, the loot gets picked up.",
	OPT_LOOTROOM_ENABLED   = "Enable the module",
	OPT_LOOTROOM_CONFIRM   = "Confirm before dropping a green item or better",
	OPT_LOOTROOM_AUCTION   = "Auction house prices (Auctionator, TSM)",
	LOOTROOM_TITLE         = "Room for loot",
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
	LOOTROOM_CONFIRM       = "Destroy %s ×%d?\nThis cannot be undone.",
	LOOTROOM_YES           = "Destroy",
	LOOTROOM_NO            = "Cancel",
	LOOTROOM_DELETED       = "Dropped: %s ×%d.",
	LOOTROOM_IGNORED       = "%s will not be offered again (\"always keep\" list).",
	HELP_LOOTROOM          = "/r2q place — the cheapest items in your bags, to drop for some loot",
}
ns.RegisterStrings(FR, EN)
ns.LOOTROOM_STRINGS = { fr = FR, en = EN }

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
	local r = { true, ns.ItemInfo(item) }
	if not r[2] then return nil end
	return { name = r[2], link = r[3], quality = r[4], maxStack = r[9], texture = r[11], sellPrice = r[12] }
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
	table.sort(list, function(a, b)
		if a.quest ~= b.quest then return a.quest end
		if a.value ~= b.value then return a.value > b.value end
		return a.slot < b.slot
	end)
	return list
end

-- Les objets des sacs à proposer, les moins chers d'abord (choix de Sac plein)
function ns:LootRoomRows(target)
	local rows = {}
	if not self.BagSpaceCandidates then return rows end
	for _, candidate in ipairs(self:BagSpaceCandidates()) do
		if #rows >= ns.LOOTROOM_ROWS then break end
		local auction = self:LootRoomAuction(candidate.link, candidate.count)
		local value = math.max(candidate.value or 0, auction or 0)
		rows[#rows + 1] = { bag = candidate.bag, slot = candidate.slot, itemID = candidate.itemID, link = candidate.link,
			count = candidate.count, quality = candidate.quality, vendor = candidate.value or 0, auction = auction,
			value = value, dearer = target ~= nil and not target.quest and value >= target.value }
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
	local db = self:DB()
	if type(db.bagspaceKeep) ~= "table" then db.bagspaceKeep = {} end
	db.bagspaceKeep[row.itemID] = true
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
	if extra then tip:AddLine(extra, 0.85, 0.85, 0.85, true) end
	tip:Show()
end
local function HideTip() local tip = rawget(_G, "GameTooltip"); if tip and tip.Hide then tip:Hide() end end

function ns:EnsureLootRoom()
	if self.lootRoomFrame then return self.lootRoomFrame end
	if not (Theme and Theme.CreatePanel) then return nil end
	local height = 100 + ns.LOOTROOM_ROWS * ROW_H
	local frame = Theme.CreatePanel(UIParent, WIDTH, height, L.LOOTROOM_TITLE, { name = "Ready2QuestLootRoom" })
	if not frame then return nil end
	frame:SetPoint("CENTER", UIParent, "CENTER", 260, 60)
	local top = frame.contentTop - 6
	frame.targetIcon = Theme.CreateIcon(frame, 22)
	frame.targetIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top)
	frame.target = frame:CreateFontString(nil, "OVERLAY", Theme.F_NORMAL)
	frame.target:SetPoint("TOPLEFT", frame, "TOPLEFT", 42, top - 4)
	frame.target:SetWidth(WIDTH - 56)
	frame.target:SetJustifyH("LEFT")
	frame.rows = {}
	for index = 1, ns.LOOTROOM_ROWS do
		local y = top - 34 - (index - 1) * ROW_H
		local row = CreateFrame("Frame", nil, frame)
		row:SetSize(WIDTH - 28, ROW_H - 4)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
		row.icon = Theme.CreateIcon(row, 22)
		row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.name = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -1)
		row.name:SetWidth(200)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row.price = row:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		row.price:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -14)
		row.price:SetWidth(200)
		row.price:SetJustifyH("LEFT")
		row.delete = Theme.CreateButton(row, 60, 20, L.LOOTROOM_BTN_DELETE, function() ns:LootRoomDelete(row.data) end, "primary")
		row.delete:SetPoint("RIGHT", row, "RIGHT", -66, 0)
		row.ignore = Theme.CreateButton(row, 60, 20, L.LOOTROOM_BTN_IGNORE, function() ns:LootRoomIgnore(row.data) end)
		row.ignore:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		row.hover = CreateFrame("Button", nil, row)
		row.hover:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.hover:SetSize(230, ROW_H - 4)
		row.hover:SetScript("OnEnter", function(h)
			local data = row.data
			if data then Tooltip(h, data.link, data.dearer and L.LOOTROOM_DEARER or nil) end
		end)
		row.hover:SetScript("OnLeave", HideTip)
		row:Hide()
		frame.rows[index] = row
	end
	frame.empty = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 40)
	frame.empty:SetWidth(WIDTH - 28)
	frame.empty:SetJustifyH("LEFT")
	frame.hint = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
	frame.hint:SetWidth(WIDTH - 28)
	frame.hint:SetJustifyH("LEFT")
	frame.hint:SetText(L.LOOTROOM_HINT)
	frame.hint:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
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
	for index, row in ipairs(frame.rows) do
		local data = rows[index]
		row.data = data
		if data then
			local item = ItemData(data.itemID) or {}
			if row.icon.tex then row.icon.tex:SetTexture(item.texture) end
			row.name:SetText(string.format("%s ×%d", tostring(data.link), data.count))
			local price = self:F("LOOTROOM_VENDOR", Money(data.vendor))
			if data.auction then price = price .. "  ·  " .. self:F("LOOTROOM_AUCTION", Money(data.auction)) end
			row.price:SetText(price)
			local c = data.dearer and Theme.MUTED or Theme.TEXT
			row.price:SetTextColor(c[1], c[2], c[3])
			row:SetAlpha(data.dearer and 0.55 or 1)
			row:Show()
		else
			row:Hide()
		end
	end
	frame.empty:SetText(#rows == 0 and L.LOOTROOM_EMPTY or "")
	return self.lootRoom
end

-- Ouvre la fenêtre ; `manual` : même sans butin bloqué
function ns:LootRoomOpen(manual)
	if not ModuleOn() and not manual then return nil end
	local frame = self:EnsureLootRoom()
	if not frame then return nil end
	if not manual and #self:LootRoomLoot() == 0 then return nil end
	frame:Show()
	self:LootRoomRefresh()
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
	end,
	UI_ERROR_MESSAGE = function(a, b)
		if ModuleOn() and ns.IsBagFullError and ns:IsBagFullError(a, b) and ns:LootRoomActive() then ns:LootRoomOpen(false) end
	end,
	BAG_UPDATE_DELAYED = function()
		if not ns:LootRoomAfterBags() then ns:LootRoomRefresh() end
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
end

if type(ns.EXTRA_COMMANDS) == "table" then
	ns.EXTRA_COMMANDS["place"] = function(self) self:LootRoomOpen(true) end
end
if type(ns.EXCLUSIVE_WINDOWS) == "table" then table.insert(ns.EXCLUSIVE_WINDOWS, "lootRoomFrame") end

if ns.Mark then ns.Mark("LootRoom") end
