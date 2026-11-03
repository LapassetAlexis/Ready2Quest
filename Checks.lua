-- Checks.lua -- les vérifications de la checklist
--
-- Chaque check expose :
--   { id, label = function|string, advice = clé de locale, weight = nombre,
--     run = function(db) -> ok, detail, score (0..100) }
-- `run` est appelé sous pcall par Core : il ne doit jamais lever d'erreur.
-- Échelle des poids : fort = 15–20 (vivres, sacs, durabilité, composants de
-- classe), moyen = 10 (potions, repos, foyer, réparation), faible = 5.
local ADDON, ns = ...
local L = ns.L

local NUM_BAG_SLOTS = 4   -- sacs 0 (sac de dos) à 4

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local instantCache = {}

local function ItemIdentity(itemID)
	if not itemID then return nil end
	local cached = instantCache[itemID]
	if cached then return cached end
	-- Era : la fonction globale existe toujours, la version C_Item pas forcément
	local fn = (C_Item and C_Item.GetItemInfoInstant) or rawget(_G, "GetItemInfoInstant")
	if type(fn) ~= "function" then return nil end

	local ok, _, itemType, itemSubType, _, _, classID, subClassID = pcall(fn, itemID)
	if not ok or not classID then return nil end

	local data = { classID = classID, subClassID = subClassID, itemType = itemType, itemSubType = itemSubType }
	instantCache[itemID] = data
	return data
end

local function EachBagItem(fn)
	if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then return end
	for bag = 0, NUM_BAG_SLOTS do
		local slots = C_Container.GetContainerNumSlots(bag)
		if type(slots) == "number" then
			for slot = 1, slots do
				local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
				if ok and type(info) == "table" and info.itemID then
					fn(bag, slot, info)
				end
			end
		end
	end
end

local function FreeBagSlots()
	local free = 0
	if C_Container and type(C_Container.GetContainerNumFreeSlots) == "function" then
		for bag = 0, NUM_BAG_SLOTS do
			local ok, count = pcall(C_Container.GetContainerNumFreeSlots, bag)
			if ok and type(count) == "number" then free = free + count end
		end
		return free
	end
	local total, used = 0, 0
	EachBagItem(function() used = used + 1 end)
	if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
		for bag = 0, NUM_BAG_SLOTS do
			local slots = C_Container.GetContainerNumSlots(bag)
			if type(slots) == "number" then total = total + slots end
		end
	end
	return math.max(0, total - used)
end

ns.FreeBagSlots = FreeBagSlots

-- GetQuestLogTitle n'a pas la même forme partout :
--   Era 1.13+ / Classic modernes : title, level, suggestedGroup, isHeader, isCollapsed, isComplete, …
--   clients historiques (5.x)     : title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, …
-- isHeader est un booléen dans les deux cas : sa position désigne la forme.
-- isComplete vaut 1 (terminée), -1 (échouée) ou nil sur Era, true ailleurs.
function ns.QuestLogReady(index)
	if type(GetQuestLogTitle) ~= "function" then return false end
	local r = { pcall(GetQuestLogTitle, index) }
	if not r[1] or r[2] == nil then return false end
	local isHeader, isComplete
	if type(r[5]) == "boolean" then
		isHeader, isComplete = r[5], r[7]
	else
		isHeader, isComplete = r[6], r[8]
	end
	if isHeader == true or isHeader == 1 then return false end
	return isComplete == true or isComplete == 1
end

local function CountQuality(quality)
	local count = 0
	EachBagItem(function(_, _, info)
		if info.quality == quality then count = count + 1 end
	end)
	return count
end

local CONSUMABLE = 0
local SUBCLASS_FOODDRINK = 5
local SUBCLASS_COMBAT = { [1] = true, [2] = true, [3] = true, [4] = true }

-- Sur Classic Era, les consommables gardent la sous-classe générique 0 de
-- vanilla : nourriture, boissons et potions n'ont pas de sous-classe propre.
-- On les reconnaît alors au sort qu'ils lancent (« Nourriture », « Boisson »)
-- ou, pour les potions, au mot « Potion » dans leur nom.
local FOOD_SPELLS = {
	["nourriture"] = true, ["boisson"] = true, ["food"] = true, ["drink"] = true,
	["refreshment"] = true, ["rafraîchissement"] = true,
	["food & drink"] = true, ["nourriture et boisson"] = true,
}
local kindCache = {}

local function ItemSpellName(itemID)
	local fn = (C_Item and C_Item.GetItemSpell) or rawget(_G, "GetItemSpell")
	if type(fn) ~= "function" then return nil end
	local ok, name = pcall(fn, itemID)
	if ok and type(name) == "string" then return name end
	return nil
end

local function ItemName(itemID)
	local fn = (C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
	if type(fn) ~= "function" then return nil end
	local ok, name = pcall(fn, itemID)
	if ok and type(name) == "string" then return name end
	return nil
end

-- "food", "combat" ou nil. Le résultat n'est mis en cache que s'il est sûr :
-- un objet pas encore en cache client sera réexaminé au prochain check.
local function ConsumableKind(itemID)
	if kindCache[itemID] ~= nil then return kindCache[itemID] or nil end
	local data = ItemIdentity(itemID)
	if not data or data.classID ~= CONSUMABLE then return nil end
	local sub = data.subClassID
	if sub == SUBCLASS_FOODDRINK then kindCache[itemID] = "food"; return "food" end
	if SUBCLASS_COMBAT[sub] then kindCache[itemID] = "combat"; return "combat" end
	if sub ~= 0 and sub ~= nil then kindCache[itemID] = false; return nil end

	local spell = ItemSpellName(itemID)
	if spell and FOOD_SPELLS[ns.AsciiLower(spell)] then kindCache[itemID] = "food"; return "food" end
	local name = ItemName(itemID)
	if name and ns.AsciiLower(name):find("potion", 1, true) then kindCache[itemID] = "combat"; return "combat" end
	if spell or name then kindCache[itemID] = false end
	return nil
end
ns.ConsumableKind = ConsumableKind

local function CountConsumables(kind)
	local count = 0
	EachBagItem(function(_, _, info)
		if ConsumableKind(info.itemID) == kind then
			count = count + (info.stackCount or 1)
		end
	end)
	return count
end

local function Ratio(value, target)
	target = tonumber(target) or 0
	if target <= 0 then return 100 end
	local percent = (tonumber(value) or 0) / target * 100
	if percent > 100 then percent = 100 end
	if percent < 0 then percent = 0 end
	return percent
end

-- ---------------------------------------------------------------------------
-- Définition des checks
-- ---------------------------------------------------------------------------
ns.checks = {}

local function Add(def) ns.checks[#ns.checks + 1] = def end

Add{
	id = "bags",
	icon = "Interface\\Icons\\INV_Misc_Bag_10",
	weight = 15,
	advice = "ADV_BAGS",
	label = function() return L.CHK_BAGS end,
	run = function(db)
		local free = FreeBagSlots()
		local threshold = db.bagFreeThreshold or 4
		local detail = ns:F("CHK_BAGS_DETAIL", free)
		local score = Ratio(free, math.max(1, threshold))
		return free > threshold, detail, score
	end,
}

Add{
	id = "gray",
	-- seuil 0 = module inactif (sinon « 0 objet gris » déclencherait l'alerte)
	active = function(db) return (db.grayItemThreshold or 1) > 0 end,
	icon = "Interface\\Icons\\INV_Misc_Coin_01",
	weight = 5,
	advice = "ADV_GRAY",
	label = function() return L.CHK_GRAY end,
	run = function(db)
		local count = CountQuality(0)
		local score = math.max(0, 100 - (count * 25))
		if count >= (db.grayItemThreshold or 1) then
			return false, ns:F("CHK_GRAY_DETAIL", count), score
		end
		return true, L.CHK_GRAY_GOOD, score
	end,
}

Add{
	id = "vivres",
	active = function(db) return (db.vivresThreshold or 1) > 0 end,
	icon = "Interface\\Icons\\INV_Misc_Food_15",
	weight = 20,
	advice = "ADV_VIVRES",
	label = function() return L.CHK_VIVRES end,
	run = function(db)
		local count = CountConsumables("food")
		local threshold = db.vivresThreshold or 1
		local score = Ratio(count, threshold)
		return count >= threshold, ns:F("CHK_VIVRES_DETAIL", count), score
	end,
}

Add{
	id = "potions",
	active = function(db) return (db.potionsThreshold or 0) > 0 end,
	icon = "Interface\\Icons\\INV_Potion_51",
	weight = 10,
	advice = "ADV_POTIONS",
	label = function() return L.CHK_POTIONS end,
	run = function(db)
		local minimum = db.potionsThreshold or 0
		local count = CountConsumables("combat")
		if minimum <= 0 then
			return true, ns:F("CHK_POTIONS_DETAIL", count), 100
		end
		return count >= minimum, ns:F("CHK_POTIONS_DETAIL", count), Ratio(count, minimum)
	end,
}

Add{
	id = "buffs",
	icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
	weight = 15,
	advice = "ADV_BUFFS",
	label = function() return L.CHK_BUFFS end,
	run = function(db)
		if not ns.EvaluateBuffs then return true, L.CHK_BUFFS_NONE, 100 end
		local missing, watched, unknown = ns:EvaluateBuffs()

		if watched == 0 then return true, L.CHK_BUFFS_NONE, 100 end
		if #missing == 0 and unknown > 0 and watched == unknown then
			return true, L.CHK_BUFFS_UNKNOWN, 80
		end
		if #missing > 0 then
			local shown = { missing[1] }
			if #missing > 1 then shown[#shown + 1] = missing[2] end
			local text = table.concat(shown, ", ")
			if #missing > 2 then text = text .. " +" .. (#missing - 2) end
			local score = math.max(0, 100 - (#missing * 25))
			return false, ns:F("CHK_BUFFS_MISSING", text), score
		end
		return true, L.CHK_BUFFS_GOOD, 100
	end,
}

Add{
	id = "rest",
	icon = "Interface\\Icons\\Spell_Nature_Sleep",
	-- information seulement : le repos ne se corrige pas au moment du départ,
	-- il ne doit donc pas coûter de points
	weight = 0,
	info = true,
	advice = "ADV_REST",
	label = function() return L.CHK_REST end,
	run = function(db)
		if type(GetXPExhaustion) ~= "function" then return true, L.CHK_REST_NA, 100 end
		local ok, rested = pcall(GetXPExhaustion)
		if not ok or type(rested) ~= "number" then return true, L.CHK_REST_NA, 100 end

		local maxXP
		if type(UnitXPMax) == "function" then
			local ok2, value = pcall(UnitXPMax, "player")
			if ok2 then maxXP = value end
		end
		if type(maxXP) ~= "number" or maxXP <= 0 then return true, L.CHK_REST_NA, 100 end

		local percent = math.floor((rested / maxXP) * 100)
		local score = math.min(100, percent * 2)   -- 50 % d'un niveau = plein
		if rested <= 0 then return false, L.CHK_REST_NONE, 0 end
		if percent < (db.restMinPercent or 10) then
			return false, ns:F("CHK_REST_DETAIL", percent), score
		end
		return true, ns:F("CHK_REST_DETAIL", percent), score
	end,
}

Add{
	id = "durability",
	icon = "Interface\\Icons\\Trade_BlackSmithing",
	weight = 15,
	advice = "ADV_DURA",
	label = function() return L.CHK_DURA end,
	run = function(db)
		if type(GetInventoryItemDurability) ~= "function" then return true, L.CHK_DURA_NA, 100 end

		local worst = nil
		for slot = 1, 19 do
			local ok, current, max = pcall(GetInventoryItemDurability, slot)
			if ok and type(current) == "number" and type(max) == "number" and max > 0 then
				local percent = (current / max) * 100
				if not worst or percent < worst then worst = percent end
			end
		end
		if not worst then return true, L.CHK_DURA_NA, 100 end

		local percent = math.floor(worst)
		if percent < (db.durabilityMinPct or 25) then
			return false, ns:F("CHK_DURA_DETAIL", percent), percent
		end
		return true, L.CHK_DURA_GOOD, percent
	end,
}

Add{
	id = "reagents",
	icon = "Interface\\Icons\\Trade_Alchemy",
	weight = 5,
	advice = "ADV_REAGENTS",
	label = function() return L.CHK_REAGENTS end,
	run = function(db)
		if not ns.ReagentSummary then return true, L.CHK_REAGENTS_NONE, 100 end
		local ok, detail = ns:ReagentSummary()
		return ok, detail, ok and 100 or 40
	end,
}

Add{
	id = "quests",
	icon = "Interface\\Icons\\INV_Misc_Note_01",
	weight = 5,
	advice = "ADV_QUESTS",
	label = function() return L.CHK_QUESTS end,
	run = function(db)
		local ready = 0

		if C_QuestLog and type(C_QuestLog.GetNumQuestLogEntries) == "function" then
			-- Clients récents : API namespacée
			local ok, total = pcall(C_QuestLog.GetNumQuestLogEntries)
			if not ok or type(total) ~= "number" then return true, L.CHK_QUESTS_GOOD, 100 end
			for i = 1, total do
				local okInfo, info = pcall(C_QuestLog.GetInfo, i)
				if okInfo and type(info) == "table" and info.questID then
					local okReady, isReady = pcall(C_QuestLog.ReadyForTurnIn, info.questID)
					if okReady and isReady == true then ready = ready + 1 end
				end
			end
		elseif type(GetNumQuestLogEntries) == "function" and type(GetQuestLogTitle) == "function" then
			-- Classic Era : globales historiques
			local ok, total = pcall(GetNumQuestLogEntries)
			if not ok or type(total) ~= "number" then return true, L.CHK_QUESTS_GOOD, 100 end
			for i = 1, total do
				if ns.QuestLogReady(i) then ready = ready + 1 end
			end
		else
			return true, L.CHK_QUESTS_GOOD, 100
		end
		if ready > 0 then
			return false, ns:F("CHK_QUESTS_DETAIL", ready), 70
		end
		return true, L.CHK_QUESTS_GOOD, 100
	end,
}

-- ---------------------------------------------------------------------------
-- v1.18.0 : composants de classe, pierre de foyer, réparation, sorts
-- ---------------------------------------------------------------------------
local function ItemCount(itemID)
	local fn = (C_Item and C_Item.GetItemCount) or rawget(_G, "GetItemCount")
	if type(fn) == "function" then
		local ok, count = pcall(fn, itemID)
		if ok and type(count) == "number" then return count end
	end
	local count = 0
	EachBagItem(function(_, _, info)
		if info.itemID == itemID then count = count + (info.stackCount or 1) end
	end)
	return count
end
ns.ItemCount = ItemCount

local function PlayerLevel()
	if type(UnitLevel) ~= "function" then return 1 end
	local ok, level = pcall(UnitLevel, "player")
	return (ok and tonumber(level)) or 1
end

local function PlayerClass()
	if type(UnitClass) ~= "function" then return nil end
	local ok, _, token = pcall(UnitClass, "player")
	if ok then return token end
	return nil
end

-- Composants consommés par les sorts de classe (Classic Era / Forever).
-- `level` = niveau à partir duquel le sort qui les consomme est appris.
-- `items` = plusieurs objets interchangeables (rangs de Renaissance…).
-- `slot`  = munitions : le client compte l'emplacement 0 (projectiles équipés).
ns.CLASS_REAGENTS = {
	HUNTER  = { { label = "REAGENT_AMMO", ammo = true, min = 200, level = 1 } },
	WARLOCK = { { label = "REAGENT_SHARD", items = { 6265 }, min = 3, level = 10 } },
	ROGUE   = { { label = "REAGENT_FLASH", items = { 5140 }, min = 5, level = 22 } },
	MAGE    = {
		{ label = "REAGENT_TELEPORT", items = { 17031 }, min = 2, level = 20 },
		{ label = "REAGENT_ARCANE", items = { 17020 }, min = 5, level = 56 },
	},
	PRIEST  = { { label = "REAGENT_CANDLE", items = { 17028, 17029 }, min = 5, level = 48 } },
	DRUID   = { { label = "REAGENT_SEED", items = { 17034, 17035, 17036, 17037, 17038 }, min = 1, level = 20 } },
	SHAMAN  = { { label = "REAGENT_ANKH", items = { 17030 }, min = 1, level = 30 } },
	PALADIN = { { label = "REAGENT_SYMBOL", items = { 17033 }, min = 1, level = 30 } },
}

local function AmmoCount()
	if type(GetInventoryItemCount) ~= "function" then return nil end
	local ok, count = pcall(GetInventoryItemCount, "player", 0)
	if ok and type(count) == "number" then return count end
	return nil
end

function ns:ClassReagentNeeds()
	local list = self.CLASS_REAGENTS[PlayerClass() or ""] or {}
	local level, needs = PlayerLevel(), {}
	for _, req in ipairs(list) do
		if level >= (req.level or 1) then
			local have
			if req.ammo then
				have = AmmoCount()
			else
				have = 0
				for _, itemID in ipairs(req.items or {}) do have = have + ItemCount(itemID) end
			end
			if have ~= nil then
				needs[#needs + 1] = { label = L[req.label] or req.label, have = have, min = req.min }
			end
		end
	end
	return needs
end

Add{
	id = "classreagents",
	inactiveText = "MODULE_INACTIVE",
	-- inactif pour les classes sans composant (guerrier) ou avant le niveau requis
	active = function() return #ns:ClassReagentNeeds() > 0 end,
	icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
	weight = 15,
	advice = "ADV_CLASSREAGENTS",
	label = function() return L.CHK_CLASSREAGENTS end,
	run = function()
		local needs = ns:ClassReagentNeeds()
		local total, short = 0, nil
		for _, need in ipairs(needs) do
			local ratio = Ratio(need.have, need.min)
			total = total + ratio
			if need.have < need.min and not short then short = need end
		end
		local score = (#needs > 0) and (total / #needs) or 100
		if short then
			return false, ns:F("CHK_CLASSREAGENTS_LOW", short.label, short.have, short.min), score
		end
		return true, ns:F("CHK_CLASSREAGENTS_GOOD", needs[1].label, needs[1].have), score
	end,
}

local HEARTHSTONE = 6948
local HEARTH_MAX_CD = 600   -- au-delà de 10 min de recharge, le foyer n'est pas une issue

local function HearthCooldown()
	local fn = (C_Container and C_Container.GetItemCooldown) or rawget(_G, "GetItemCooldown")
	if type(fn) ~= "function" then return 0 end
	local ok, start, duration = pcall(fn, HEARTHSTONE)
	if not ok or type(start) ~= "number" or type(duration) ~= "number" or start <= 0 then return 0 end
	local remaining = start + duration - ((ns.Now and ns.Now()) or 0)
	return remaining > 0 and remaining or 0
end
ns.HearthCooldown = HearthCooldown

Add{
	id = "hearth",
	icon = "Interface\\Icons\\INV_Misc_Rune_01",
	weight = 10,
	advice = "ADV_HEARTH",
	label = function() return L.CHK_HEARTH end,
	run = function()
		local where = "?"
		if type(GetBindLocation) == "function" then
			local ok, text = pcall(GetBindLocation)
			if ok and type(text) == "string" and text ~= "" then where = text end
		end
		if ItemCount(HEARTHSTONE) <= 0 then return false, L.CHK_HEARTH_MISSING, 0 end
		local cd = HearthCooldown()
		if cd > HEARTH_MAX_CD then
			return false, ns:F("CHK_HEARTH_CD", where, math.ceil(cd / 60)), 50
		end
		if cd > 0 then
			return true, ns:F("CHK_HEARTH_CD", where, math.ceil(cd / 60)), 80
		end
		return true, ns:F("CHK_HEARTH_READY", where), 100
	end,
}

Add{
	id = "repair",
	inactiveText = "MODULE_INACTIVE",
	-- muet tant qu'aucun coût n'a été mesuré chez un marchand
	active = function() return ns.EstimatedRepairCost ~= nil and ns:EstimatedRepairCost() ~= nil end,
	icon = "Interface\\Icons\\INV_Hammer_20",
	weight = 10,
	advice = "ADV_REPAIR",
	label = function() return L.CHK_REPAIR end,
	run = function()
		local cost = ns:EstimatedRepairCost() or 0
		local money = 0
		if type(GetMoney) == "function" then
			local ok, value = pcall(GetMoney)
			if ok then money = tonumber(value) or 0 end
		end
		if cost <= 0 then return true, L.CHK_REPAIR_NONE, 100 end
		if money < cost then
			return false, ns:F("CHK_REPAIR_POOR", ns:FormatMoney(cost)), Ratio(money, cost)
		end
		return true, ns:F("CHK_REPAIR_OK", ns:FormatMoney(cost)), 100
	end,
}

-- Nouveaux sorts tous les niveaux pairs (Era) : on compare au niveau de la
-- dernière visite chez l'entraîneur de classe.
function ns:PendingSpellLevels()
	local data = self.CharData and self:CharData() or {}
	local trained = tonumber(data.trainerLevel)
	if not trained then return 0 end
	local level = PlayerLevel()
	local count = 0
	for l = trained + 1, level do
		if l % 2 == 0 then count = count + 1 end
	end
	return count
end

Add{
	id = "spells",
	inactiveText = "MODULE_INACTIVE",
	active = function() return ns:PendingSpellLevels() > 0 end,
	icon = "Interface\\Icons\\INV_Misc_Book_09",
	weight = 5,
	advice = "ADV_SPELLS",
	label = function() return L.CHK_SPELLS end,
	run = function()
		local trained = tonumber(ns:CharData().trainerLevel) or 0
		return false, ns:F("CHK_SPELLS_DETAIL", trained, PlayerLevel()), 50
	end,
}

if ns.Mark then ns.Mark("Checks") end
