-- Checks.lua -- les vérifications de la checklist
--
-- Chaque check expose :
--   { id, label = function|string, advice = clé de locale, weight = nombre,
--     run = function(db) -> ok, detail, score (0..100) }
-- `run` est appelé sous pcall par Core : il ne doit jamais lever d'erreur.
-- Les poids des neuf modules totalisent 100.
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
	if not (C_Item and type(C_Item.GetItemInfoInstant) == "function") then return nil end

	local ok, _, itemType, itemSubType, _, _, classID, subClassID =
		pcall(C_Item.GetItemInfoInstant, itemID)
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

local function CountConsumables(isWanted)
	local count = 0
	EachBagItem(function(_, _, info)
		local data = ItemIdentity(info.itemID)
		if data and data.classID == CONSUMABLE and isWanted(data.subClassID) then
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
		local count = CountConsumables(function(sub) return sub == SUBCLASS_FOODDRINK end)
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
		local count = CountConsumables(function(sub) return SUBCLASS_COMBAT[sub] == true end)
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
	weight = 10,
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
				local okTitle, _, _, _, _, isHeader, _, isComplete = pcall(GetQuestLogTitle, i)
				if okTitle and not isHeader and isComplete == true then ready = ready + 1 end
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

if ns.Mark then ns.Mark("Checks") end
