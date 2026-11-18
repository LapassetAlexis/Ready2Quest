-- ShopWeek.lua -- l'échoppe de la 3.4 : stock du jour, places, surnom, arrivage, commandes (QuestCompanion 3.4.0)
--
-- 3.4.0 (docs/design-reserve-3.4, § 10) : les paillettes achètent du confort
-- et de l'allure, pas des captures sans fin.
--   * aides : mêmes prix, un STOCK PAR JOUR pour le compte (5 appâts, 2
--     lassos, 1 sifflet) ;
--   * dix places : 40, puis 20 de plus à chaque achat ; 150 places au plus
--     (au-dessus, on garde ses places et l'article dit « au plus grand ») ;
--   * surnom d'un spécimen : 15 (offert une fois au lien 5) ;
--   * ARRIVAGE de la semaine : 2 cosmétiques tournants (60 à 120), tirés
--     dans les articles `arrival` de ns.PAILLETTES_SHOP ;
--   * COMMANDES de la semaine : 3 demandes (type et taille, caractère et
--     étoiles, zone) ; on livre un spécimen de la Réserve, qui part ; 12 à
--     16 paillettes ; les trois livrées : un cosmétique de l'arrivage au choix.
-- Données (au compte, capture) : slotBuys, shopDay = { day, appat, lasso,
-- sifflet }, orders = { week, list = { { kind, …, reward, done } }, bonus }.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.SHOP_STOCK = { appat = 5, lasso = 2, sifflet = 1 }
ns.SHOP_SLOTS = { base = 40, step = 20, slots = 10, max = 150 }
ns.SHOP_NICK_PRICE = 15
ns.SHOP_ARRIVALS = 2
ns.ORDER_REWARDS = { 12, 14, 16 }

local FR = {
	SHOP_DIS_stock   = "Plus en stock aujourd'hui",
	SHOP_STOCK       = "Stock du jour : %d / %d",
	SHOP_MAX         = "Ta Réserve est au plus grand (%d places).",
	SHOP_DIS_max     = "Réserve au plus grand",
	SHOP_SLOTS_NEXT  = "Ta Réserve compte %d places (au plus %d).",
	SHOP_NICK        = "Surnom",
	SHOP_NICK_FREE   = "Surnom offert (lien Inséparable)",
	SHOP_ARRIVALS    = "Arrivage de la semaine",
	SHOP_ORDERS      = "Commandes de la semaine",
	ORDER_typeSize   = "Un %s %s ou plus grand",
	ORDER_traitStars = "Un %s de %d étoiles ou plus",
	ORDER_zone       = "Une créature de la zone %s",
	ORDER_REWARD     = "+%d paillettes",
	ORDER_DELIVER    = "Livrer",
	ORDER_DONE       = "Livrée",
	ORDER_DELIVERED  = "Commande livrée : %s (+%d paillettes).",
	ORDER_BONUS      = "Les trois commandes livrées : choisis un cosmétique de l'arrivage, offert.",
	ORDER_BONUS_TAKE = "Prendre",
	ORDER_BONUS_GOT  = "%s : offert pour tes trois commandes.",
	ORDER_WHY_match  = "Ce spécimen ne correspond pas à la commande.",
	ORDER_WHY_keep   = "Ce spécimen ne peut pas partir (protégé, porté ou meilleur que le Codex).",
}
local EN = {
	SHOP_DIS_stock   = "Out of stock today",
	SHOP_STOCK       = "Today's stock: %d / %d",
	SHOP_MAX         = "Your Reserve is at its largest (%d slots).",
	SHOP_DIS_max     = "Reserve at its largest",
	SHOP_SLOTS_NEXT  = "Your Reserve has %d slots (up to %d).",
	SHOP_NICK        = "Nickname",
	SHOP_NICK_FREE   = "Free nickname (Inseparable bond)",
	SHOP_ARRIVALS    = "This week's arrivals",
	SHOP_ORDERS      = "This week's orders",
	ORDER_typeSize   = "A %s, %s or bigger",
	ORDER_traitStars = "A %s with %d stars or more",
	ORDER_zone       = "A creature from %s",
	ORDER_REWARD     = "+%d glitter",
	ORDER_DELIVER    = "Deliver",
	ORDER_DONE       = "Delivered",
	ORDER_DELIVERED  = "Order delivered: %s (+%d glitter).",
	ORDER_BONUS      = "All three orders delivered: pick one cosmetic from the arrivals, free.",
	ORDER_BONUS_TAKE = "Take",
	ORDER_BONUS_GOT  = "%s: free for your three orders.",
	ORDER_WHY_match  = "This specimen doesn't match the order.",
	ORDER_WHY_keep   = "This specimen can't leave (protected, worn or better than your Codex).",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.SHOP_WEEK_STRINGS = { fr = FR, en = EN } end

local function DayKey() return ns.CaptureDayKey and ns.CaptureDayKey() or "?" end
local function WeekKey(self) return self.WeeklyId and self:WeeklyId() or "?" end

-- Un nombre stable tiré d'une clé (semaine) : même choix pour tout le compte
local function Seed(text)
	local h = 7
	for i = 1, #tostring(text) do h = (h * 31 + tostring(text):byte(i)) % 2147483647 end
	return h
end

-- ---------------------------------------------------------------------------
-- Stock du jour, places
-- ---------------------------------------------------------------------------
local function ShopDay(self)
	local capture = self:CaptureData()
	local day = DayKey()
	if type(capture.shopDay) ~= "table" or capture.shopDay.day ~= day then capture.shopDay = { day = day } end
	return capture.shopDay
end

function ns:ShopStockLeft(aid)
	local cap = ns.SHOP_STOCK[aid]
	if not cap then return nil end
	return math.max(0, cap - (tonumber(ShopDay(self)[aid]) or 0)), cap
end

function ns:ShopSlotBuys()
	local capture = self:CaptureData()
	if capture.slotBuys == nil then
		capture.slotBuys = math.floor(math.max(0, tonumber(capture.reserveBonus) or 0) / ns.SHOP_SLOTS.slots)
	end
	return math.max(0, math.floor(tonumber(capture.slotBuys) or 0))
end

function ns:ShopSlotPrice()
	return ns.SHOP_SLOTS.base + ns.SHOP_SLOTS.step * self:ShopSlotBuys()
end

-- les prix qui bougent (places), posés sur l'article avant toute lecture
local function Sync(self, item)
	if type(item) == "table" and item.kind == "slots" then
		item.price, item.slots = self:ShopSlotPrice(), ns.SHOP_SLOTS.slots
	end
	return item
end

-- ---------------------------------------------------------------------------
-- Arrivage de la semaine
-- ---------------------------------------------------------------------------
function ns:ShopArrivals()
	local pool = {}
	for _, item in ipairs(ns.PAILLETTES_SHOP or {}) do if item.arrival then pool[#pool + 1] = item end end
	local week = WeekKey(self)
	local cache = self.shopArrivalCache
	if cache and cache.week == week and cache.n == #pool then return cache.list end
	local list, taken, seed = {}, {}, Seed(week)
	for _ = 1, math.min(ns.SHOP_ARRIVALS, #pool) do
		local index = seed % #pool + 1
		while taken[index] do index = index % #pool + 1 end
		taken[index] = true
		list[#list + 1] = pool[index]
		seed = math.floor(seed / 7) + 13
	end
	self.shopArrivalCache = { week = week, n = #pool, list = list }
	return list
end

local function InArrivals(self, item)
	for _, arrival in ipairs(self:ShopArrivals()) do if arrival == item then return true end end
	return false
end

-- ---------------------------------------------------------------------------
-- État et achat : enveloppes de JournalReserve.lua
-- ---------------------------------------------------------------------------
do
	local state = ns.ShopState
	function ns:ShopState(item, ...)
		if type(item) ~= "table" then item = self:ShopItem(item) end
		Sync(self, item)
		if type(item) == "table" then
			if item.kind == "slots" and self:ReserveCapacity() >= ns.SHOP_SLOTS.max then return "max", self:ReserveCapacity() end
			if item.arrival and not InArrivals(self, item) and not (self.ShopCosmeticOwned and self:ShopCosmeticOwned(item.cosId)) then
				return "away"
			end
		end
		local result, a, b = state(self, item, ...)
		if result == "ok" and type(item) == "table" and item.kind == "aid" then
			local left = self:ShopStockLeft(item.aid)
			if left and left <= 0 then return "stock", 0, ns.SHOP_STOCK[item.aid] end
		end
		return result, a, b
	end
	local buy = ns.ShopBuy
	function ns:ShopBuy(id, ...)
		local item = Sync(self, self:ShopItem(id))
		local ok, left = buy(self, id, ...)
		if ok and type(item) == "table" then
			if item.kind == "aid" then
				local day = ShopDay(self)
				day[item.aid] = (tonumber(day[item.aid]) or 0) + 1
			elseif item.kind == "slots" then
				local capture = self:CaptureData()
				capture.slotBuys = self:ShopSlotBuys() + 1
				Sync(self, item)
			end
		end
		return ok, left
	end
	local tip = ns.ShopDisabledTip
	function ns:ShopDisabledTip(state, missing, ...)
		if state == "stock" then return L.SHOP_DIS_stock end
		if state == "max" then return L.SHOP_DIS_max end
		return tip(self, state, missing, ...)
	end
	local refused = ns.ShopRefused
	function ns:ShopRefused(id, ...)
		local state, a = self:ShopState(id)
		if state == "max" then self:Print(self:F("SHOP_MAX", tonumber(a) or 0)); return state end
		if state == "stock" then self:Print(L.SHOP_DIS_stock); return state end
		return refused(self, id, ...)
	end
end

-- ---------------------------------------------------------------------------
-- Surnom
-- ---------------------------------------------------------------------------
-- offert une fois au lien 5 (spec.nickFree = déjà utilisé)
function ns:ShopNickPrice(spec)
	if type(spec) ~= "table" then spec = self:SpecimenGet(spec) end
	if spec and not spec.nickFree and self.SpecimenBondLevel and self:SpecimenBondLevel(spec) >= 5 then return 0 end
	return ns.SHOP_NICK_PRICE
end

function ns:ShopNickBuy(id, text)
	local spec = self:SpecimenGet(id)
	if not spec then return false, "missing" end
	local clean = ns.SpecimenCleanNick and ns.SpecimenCleanNick(text)
	local price = self:ShopNickPrice(spec)
	if clean and price > 0 then
		local paid = self:PaillettesSpend(price, "shop:nick")
		if not paid then return false, "short" end
	elseif clean then
		spec.nickFree = true
	end
	local nick = self:SpecimenSetNick(spec.id, clean)
	local label = self:SpecimenLabel(spec)
	if nick then self:Print(self:F("SPEC_NICK_SET", label, nick)) else self:Print(self:F("SPEC_NICK_CLEAR", label)) end
	return true, nick
end

-- ---------------------------------------------------------------------------
-- Commandes de la semaine
-- ---------------------------------------------------------------------------
local ORDER_SIZES = { "large", "giant" }
local function Pick(list, seed) if #list == 0 then return nil end return list[seed % #list + 1] end

-- les zones de tes captures (une commande doit pouvoir être livrée)
local function Zones(self)
	local seen, list = {}, {}
	for _, spec in ipairs(self:SpecimenList({ where = "all", sort = "id" })) do
		local zone = tonumber(spec.zone)
		if zone and not seen[zone] then seen[zone] = true; list[#list + 1] = zone end
	end
	table.sort(list)
	return list
end

local function Draw(self, week)
	local seed = Seed(week .. ":orders")
	local types = ns.CREATURE_TYPES or { "beast" }
	local traits = {}
	for _, pair in ipairs(ns.SPECIMEN_TRAIT_WEIGHTS or {}) do traits[#traits + 1] = pair[1] end
	local list = {
		{ kind = "typeSize", type = Pick(types, seed), size = "large", reward = ns.ORDER_REWARDS[1 + seed % 3] },
		{ kind = "traitStars", trait = Pick(traits, math.floor(seed / 11)), stars = 2, reward = ns.ORDER_REWARDS[1 + math.floor(seed / 5) % 3] },
	}
	local zone = Pick(Zones(self), math.floor(seed / 17))
	if zone then list[#list + 1] = { kind = "zone", zone = zone, reward = ns.ORDER_REWARDS[1 + math.floor(seed / 3) % 3] }
	else list[#list + 1] = { kind = "typeSize", type = Pick(types, seed + 1), size = "large", reward = ns.ORDER_REWARDS[2] } end
	return list
end

function ns:ShopOrders()
	local capture = self:CaptureData()
	local week = WeekKey(self)
	if type(capture.orders) ~= "table" or capture.orders.week ~= week then
		capture.orders = { week = week, list = Draw(self, week) }
	end
	return capture.orders
end

function ns:ShopOrderLabel(order)
	if order.kind == "typeSize" then
		return self:F("ORDER_typeSize", self:CreatureTypeLabel(order.type), self:SpecimenSizeLabel(order.size))
	end
	if order.kind == "traitStars" then
		return self:F("ORDER_traitStars", self.PersonaLabel and self:PersonaLabel(order.trait) or order.trait, order.stars)
	end
	if order.kind == "zone" then return self:F("ORDER_zone", self:ReserveZoneName(order.zone)) end
	return "?"
end

-- le filtre de la Réserve qui montre ce qu'on peut livrer
function ns:ShopOrderFilter(order)
	local f = self:ReserveFilterNew()
	if order.kind == "typeSize" then
		f.sets.type = { [order.type] = true }
		f.sets.size = { large = true, giant = true }
	elseif order.kind == "traitStars" then
		f.sets.trait = { [order.trait] = true }
		f.sets.stars = { [2] = true, [3] = true }
	elseif order.kind == "zone" then
		f.sets.zone = { [order.zone] = true }
	end
	f.sets.state = { releasable = true }
	return f
end

function ns:ShopOrderMatches(order, spec)
	if type(spec) ~= "table" then spec = self:SpecimenGet(spec) end
	if not spec or self:SpecimenIsReference(spec.id) then return false end
	return self:ReserveMatch(spec, self:ShopOrderFilter(order))
end

function ns:ShopOrderDeliver(index, id)
	local orders = self:ShopOrders()
	local order = orders.list[index]
	if not order or order.done then return false, "done" end
	local spec = self:SpecimenGet(id)
	if not spec then return false, "missing" end
	if not self:ShopOrderMatches(order, spec) then return false, "match" end
	if not self:SpecimenCanRelease(spec.id) then return false, "keep" end
	local label = self:SpecimenLabel(spec)
	if not self:SpecimenTake(spec.id) then return false, "keep" end
	order.done = true
	self:PaillettesAdd(order.reward, "order")
	self:Print(self:F("ORDER_DELIVERED", label, order.reward))
	if self:ShopOrdersAllDone() then self:Print(L.ORDER_BONUS) end
	return true
end

function ns:ShopOrdersAllDone()
	local orders = self:ShopOrders()
	for _, order in ipairs(orders.list) do if not order.done then return false end end
	return #orders.list > 0
end

-- le cosmétique offert pour les trois commandes (une fois par semaine)
function ns:ShopOrderBonus(itemId)
	local orders = self:ShopOrders()
	if orders.bonus or not self:ShopOrdersAllDone() then return false, "none" end
	local item = self:ShopItem(itemId)
	if not (item and item.arrival and InArrivals(self, item)) then return false, "away" end
	if self:ShopCosmeticOwned(item.cosId) then return false, "owned" end
	self:ShopCosmeticGrant(item.cosId)
	orders.bonus = item.id
	self:Print(self:F("ORDER_BONUS_GOT", self:ShopLabel(item)))
	return true
end

if ns.Mark then ns.Mark("ShopWeek") end
