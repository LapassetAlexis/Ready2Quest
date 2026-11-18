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
-- sifflet }, orders = { week, list = { { kind, …, reward, done } }, bonus,
-- rerolled, rerolls }, patron = points de mécène.
--
-- 3.6.0 (docs/audit-pokemon-like-3.5/PLAN.md, lot 1C) : des puits pour les
-- gros joueurs.
--   * un cosmétique d'arrivage HORS DE SA SEMAINE s'achète quand même, une
--     fois et demie plus cher (ns:ShopPrice, ns:ShopAwayList) ;
--   * MÉCÉNAT : 100 paillettes pour 1 point de mécène, sans limite ; titres
--     à 10, 50 et 100 points (hauts faits men_patron_*, FeatsTitles.lua) ;
--   * RELANCE des commandes : la première de la semaine gratuite, les
--     suivantes 10 paillettes (toujours tant qu'aucune n'est livrée).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.SHOP_STOCK = { appat = 5, lasso = 2, sifflet = 1 }
ns.SHOP_SLOTS = { base = 40, step = 20, slots = 10, max = 150 }
ns.SHOP_NICK_PRICE = 15
ns.SHOP_ARRIVALS = 2
ns.ORDER_REWARDS = { 12, 14, 16 }
ns.ORDER_BONUS_GLITTER = 30   -- 3.5.1 : les trois livrées, arrivages déjà possédés
ns.SHOP_AWAY_FACTOR = 1.5     -- 3.6.0 : un arrivage hors de sa semaine
ns.ORDER_REROLL_PRICE = 10    -- 3.6.0 : une relance après la gratuite
ns.SHOP_PATRON = { price = 100, titles = { 10, 50, 100 } }   -- 3.6.0 : mécénat

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
	ORDER_typeSize   = "Type %s, taille %s ou plus",
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
	ORDER_BONUS_GLITTER = "Les trois commandes livrées, l'arrivage déjà à toi : +%d paillettes.",
	ORDER_REROLL     = "Relancer",
	ORDER_REROLL_TIP = "Trois nouvelles commandes, une fois par semaine, tant qu'aucune n'est livrée.",
	ORDER_REROLLED   = "Commandes de la semaine : trois nouvelles demandes.",
	ORDER_WHY_keep   = "Ce spécimen ne peut pas partir (protégé, porté ou meilleur que le Codex).",
	-- 3.6.0 : hors de leur semaine, mécénat, relance payante
	SHOP_AWAY        = "Hors de leur semaine",
	SHOP_AWAY_PRICE  = "prix ×1,5",
	SHOP_AWAY_BACK   = "Revient dans %d semaines",
	SHOP_AWAY_BACK1  = "Revient la semaine prochaine",
	SHOP_AWAY_LATER  = "Hors de sa semaine",
	SHOP_AWAY_TIP    = "Un cosmétique de l'arrivage, hors de sa semaine : tout de suite, une fois et demie son prix (%d au lieu de %d).",
	SHOP_AWAY_NONE   = "Tous les cosmétiques d'arrivage sont à toi.",
	SHOP_PATRON      = "Mécénat",
	SHOP_PATRON_NAME = "Points de mécène : %d",
	SHOP_PATRON_DESC = "Titres à 10, 50 et 100 points",
	SHOP_PATRON_TIP  = "%d paillettes = 1 point de mécène, sans limite. Titres à 10, 50 et 100 points. Rien d'autre.",
	SHOP_PATRON_GIVE = "Donner",
	SHOP_PATRON_DONE = "Mécénat : +1 point de mécène (%d en tout).",
	ORDER_REROLL_PAID = "Relancer · %d",
	ORDER_REROLL_PAID_TIP = "Trois nouvelles commandes pour %d paillettes, tant qu'aucune n'est livrée.",
	ORDER_REROLL_USED = "relance gratuite utilisée",
	ORDER_REROLLED_PAID = "Commandes de la semaine : trois nouvelles demandes (−%d paillettes).",
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
	ORDER_typeSize   = "Type %s, size %s or bigger",
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
	ORDER_BONUS_GLITTER = "All three orders delivered and the arrivals already yours: +%d glitter.",
	ORDER_REROLL     = "Reroll",
	ORDER_REROLL_TIP = "Three new orders, once a week, as long as none is delivered.",
	ORDER_REROLLED   = "This week's orders: three new requests.",
	ORDER_WHY_keep   = "This specimen can't leave (protected, worn or better than your Codex).",
	SHOP_AWAY        = "Out of their week",
	SHOP_AWAY_PRICE  = "price ×1.5",
	SHOP_AWAY_BACK   = "Back in %d weeks",
	SHOP_AWAY_BACK1  = "Back next week",
	SHOP_AWAY_LATER  = "Out of its week",
	SHOP_AWAY_TIP    = "An arrival cosmetic out of its week: right now, for one and a half times its price (%d instead of %d).",
	SHOP_AWAY_NONE   = "Every arrival cosmetic is already yours.",
	SHOP_PATRON      = "Patronage",
	SHOP_PATRON_NAME = "Patron points: %d",
	SHOP_PATRON_DESC = "Titles at 10, 50 and 100 points",
	SHOP_PATRON_TIP  = "%d glitter = 1 patron point, no limit. Titles at 10, 50 and 100 points. Nothing else.",
	SHOP_PATRON_GIVE = "Give",
	SHOP_PATRON_DONE = "Patronage: +1 patron point (%d in total).",
	ORDER_REROLL_PAID = "Reroll · %d",
	ORDER_REROLL_PAID_TIP = "Three new orders for %d glitter, as long as none is delivered.",
	ORDER_REROLL_USED = "free reroll used",
	ORDER_REROLLED_PAID = "This week's orders: three new requests (−%d glitter).",
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
-- 3.5.1 : par paquet mélangé : sur un cycle de ceil(n / SHOP_ARRIVALS)
-- semaines, chaque cosmétique passe une fois (avant : un tirage par semaine,
-- les mêmes revenaient)
local function WeekNumber(week)
	local r = tostring(week):match("^r(%d+)$")
	if r then return tonumber(r) end
	local y, w = tostring(week):match("^w(%d+)%-(%d+)$")
	if y then return tonumber(y) * 53 + tonumber(w) end
	return Seed(week)
end
-- 3.6.0 : le tirage d'une semaine donnée par son numéro (la semaine en
-- cours, ou une à venir pour dire quand un cosmétique revient)
local function ArrivalPool()
	local pool = {}
	for _, item in ipairs(ns.PAILLETTES_SHOP or {}) do if item.arrival then pool[#pool + 1] = item end end
	return pool
end
local function ArrivalsOf(pool, n)
	local per = math.max(1, ns.SHOP_ARRIVALS)
	local weeks = math.max(1, math.ceil(#pool / per))
	local cycle, slot = math.floor(n / weeks), n % weeks
	-- le paquet du cycle (mélange de Fisher-Yates, graine du cycle)
	local deck, seed = {}, Seed("arrivals:" .. cycle)
	for i = 1, #pool do deck[i] = pool[i] end
	for i = #deck, 2, -1 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local j = seed % i + 1
		deck[i], deck[j] = deck[j], deck[i]
	end
	local list = {}
	for k = 1, math.min(per, #deck) do
		local item = deck[slot * per + k] or deck[k]
		list[#list + 1] = item
	end
	return list, weeks
end

function ns:ShopArrivals()
	local pool = ArrivalPool()
	local week = WeekKey(self)
	local cache = self.shopArrivalCache
	if cache and cache.week == week and cache.n == #pool then return cache.list end
	local list = ArrivalsOf(pool, WeekNumber(week))
	self.shopArrivalCache = { week = week, n = #pool, list = list }
	return list
end

local function InArrivals(self, item)
	for _, arrival in ipairs(self:ShopArrivals()) do if arrival == item then return true end end
	return false
end

-- 3.6.0 : un cosmétique d'arrivage hors de sa semaine, pas encore à toi
function ns:ShopIsAway(item)
	if type(item) ~= "table" then item = self:ShopItem(item) end
	return type(item) == "table" and item.arrival and not InArrivals(self, item)
		and not (self.ShopCosmeticOwned and self:ShopCosmeticOwned(item.cosId)) or false
end

-- Dans combien de semaines il revient à l'arrivage (nil : pas sur deux cycles)
function ns:ShopAwayWeeks(item)
	if type(item) ~= "table" then item = self:ShopItem(item) end
	if type(item) ~= "table" or not item.arrival then return nil end
	local pool = ArrivalPool()
	local n = WeekNumber(WeekKey(self))
	local _, weeks = ArrivalsOf(pool, n)
	for k = 1, 2 * weeks do
		for _, other in ipairs((ArrivalsOf(pool, n + k))) do if other == item then return k end end
	end
	return nil
end

-- Les cosmétiques hors de leur semaine : ceux qui reviennent le plus tôt d'abord
function ns:ShopAwayList()
	local list, back = {}, {}
	for _, item in ipairs(ArrivalPool()) do
		if self:ShopIsAway(item) then
			list[#list + 1] = item
			back[item] = self:ShopAwayWeeks(item) or 99
		end
	end
	table.sort(list, function(a, b)
		if back[a] ~= back[b] then return back[a] < back[b] end
		return a.id < b.id
	end)
	return list, back
end

-- Le prix à payer : une fois et demie hors de la semaine
function ns:ShopPrice(item)
	if type(item) ~= "table" then item = self:ShopItem(item) end
	if type(item) ~= "table" then return 0 end
	if self:ShopIsAway(item) then return math.floor(item.price * ns.SHOP_AWAY_FACTOR + 0.5) end
	return item.price
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
			-- 3.6.0 : hors de sa semaine, il s'achète (ns:ShopPrice : ×1,5)
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
-- 3.6.0 : Mécénat (un puits pur : du prestige, rien d'autre)
-- ---------------------------------------------------------------------------
function ns:ShopPatronPoints()
	return math.max(0, math.floor(tonumber(self:CaptureData().patron) or 0))
end

-- appelé par ns:ShopBuy (article « patron », payé) : un point de plus
function ns:ShopPatronAdd()
	local capture = self:CaptureData()
	capture.patron = self:ShopPatronPoints() + 1
	if self.FeatTouch then pcall(self.FeatTouch, self, "flag") end
	self:Print(self:F("SHOP_PATRON_DONE", capture.patron))
	return capture.patron
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
local function Pick(list, seed) if #list == 0 then return nil end return list[seed % #list + 1] end

-- les zones de tes captures (une commande doit pouvoir être livrée) ;
-- 3.5.1 : celles de ta Réserve (l'exemplaire du Codex ne se livre pas)
local function Zones(self)
	local seen, list = {}, {}
	for _, spec in ipairs(self:SpecimenList({ where = "reserve", sort = "id" })) do
		local zone = tonumber(spec.zone)
		if zone and not seen[zone] then seen[zone] = true; list[#list + 1] = zone end
	end
	table.sort(list)
	return list
end

local function Draw(self, week)
	local seed = Seed(week .. ":orders")
	-- bêta 2 (en jeu) : un type que tu as déjà capturé (pas « Géant » à qui n'en a jamais vu)
	local types, have = {}, {}
	for _, entry in pairs(self:CaptureData().creatures or {}) do
		local key = type(entry) == "table" and (entry.typeKey or (self.CreatureTypeKey and self:CreatureTypeKey(entry.type)))
		if key then have[key] = true end
	end
	for _, key in ipairs(ns.CREATURE_TYPES or {}) do if have[key] then types[#types + 1] = key end end
	if #types == 0 then types = ns.CREATURE_TYPES or { "beast" } end
	-- 3.5.1 : pas de caractère rare (Zen, Espiègle) ; ceux de ta Réserve d'abord
	local traits, inReserve = {}, {}
	for _, spec in ipairs(self:SpecimenList({ where = "reserve", sort = "id" })) do
		if spec.trait then inReserve[spec.trait] = true end
	end
	for _, pair in ipairs(ns.SPECIMEN_TRAIT_WEIGHTS or {}) do
		if not (ns.SPECIMEN_TRAIT_RARE or {})[pair[1]] and inReserve[pair[1]] then traits[#traits + 1] = pair[1] end
	end
	if #traits == 0 then
		for _, pair in ipairs(ns.SPECIMEN_TRAIT_WEIGHTS or {}) do
			if not (ns.SPECIMEN_TRAIT_RARE or {})[pair[1]] then traits[#traits + 1] = pair[1] end
		end
	end
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

-- 3.5.1 : une relance gratuite par semaine, tant qu'aucune commande n'est livrée
-- 3.6.0 : les suivantes coûtent ORDER_REROLL_PRICE. Rend true, prix |
-- false, raison ("started", ou "short" et ce qui manque)
function ns:ShopOrdersRerollPrice()
	return self:ShopOrders().rerolled and ns.ORDER_REROLL_PRICE or 0
end
function ns:ShopOrdersCanReroll()
	local orders = self:ShopOrders()
	for _, order in ipairs(orders.list) do if order.done then return false, "started" end end
	local price = self:ShopOrdersRerollPrice()
	if price > 0 and self:Paillettes() < price then return false, "short", price - self:Paillettes() end
	return true, price
end
function ns:ShopOrdersReroll()
	local ok, why = self:ShopOrdersCanReroll()
	if not ok then return false, why end
	local orders = self:ShopOrders()
	local price = self:ShopOrdersRerollPrice()
	if price > 0 and not self:PaillettesSpend(price, "shop:reroll") then return false, "short" end
	-- la première garde sa graine d'avant (« :again ») ; les suivantes, la leur
	orders.rerolls = (tonumber(orders.rerolls) or 0) + 1
	local seed = orders.week .. ":again" .. (orders.rerolls > 1 and orders.rerolls or "")
	orders.list, orders.rerolled = Draw(self, seed), true
	if price > 0 then self:Print(self:F("ORDER_REROLLED_PAID", price)) else self:Print(L.ORDER_REROLLED) end
	return true
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
	if self:ShopOrdersAllDone() then
		-- 3.5.1 : les deux arrivages déjà à toi : 30 paillettes à la place
		local free = false
		for _, item in ipairs(self:ShopArrivals()) do
			if not self:ShopCosmeticOwned(item.cosId) then free = true end
		end
		if free then
			self:Print(L.ORDER_BONUS)
		elseif not orders.bonus then
			orders.bonus = "glitter"
			self:PaillettesAdd(ns.ORDER_BONUS_GLITTER, "order")
			self:Print(self:F("ORDER_BONUS_GLITTER", ns.ORDER_BONUS_GLITTER))
		end
	end
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
