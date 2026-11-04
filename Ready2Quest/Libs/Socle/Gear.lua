-- Gear.lua -- lecture de l'inventaire du joueur (socle commun)
--
-- Ce que Ready2Quest (check avant le départ) et QuestCompanion (conseils de
-- route du compagnon) lisent tous les deux, avec les mêmes règles :
--   * sacs : ns.EachBagItem, ns.FreeBagSlots, ns.CountConsumables(kind) ;
--   * quêtes : ns.QuestLogReady(index), ns:QuestCounts() -> total, prêtes ;
--   * équipement : ns:LowestDurability() -> % de la pièce la plus usée ;
--   * pierre de foyer : ns.HearthCooldown() -> secondes restantes ;
--   * munitions : ns.AmmoCount, ns.AmmoInBags, ns.ReagentMinimum,
--     ns.AMMO_MINIMUM (paliers du chasseur) ;
--   * joueur : ns.PlayerLevelNow, ns.PlayerClassToken.
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
local ADDON, ns = ...

-- ---------------------------------------------------------------------------
-- Sacs et quêtes
-- ---------------------------------------------------------------------------
local NUM_BAG_SLOTS = 4   -- sacs 0 (sac de dos) à 4

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

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
ns.EachBagItem = EachBagItem

local function CountConsumables(kind)
	local ConsumableKind = ns.ConsumableKind
	local count = 0
	EachBagItem(function(_, _, info)
		if ConsumableKind(info.itemID) == kind then
			count = count + (info.stackCount or 1)
		end
	end)
	return count
end
ns.CountConsumables = CountConsumables


-- Quêtes du journal : total, et prêtes à rendre (API namespacée récente, ou
-- globales historiques d'Era). nil si le journal ne se lit pas.
function ns:QuestCounts()
	local total, ready = 0, 0
	if C_QuestLog and type(C_QuestLog.GetNumQuestLogEntries) == "function" then
		local ok, entries = pcall(C_QuestLog.GetNumQuestLogEntries)
		if not ok or type(entries) ~= "number" then return nil end
		for i = 1, entries do
			local okInfo, info = pcall(C_QuestLog.GetInfo, i)
			if okInfo and type(info) == "table" and info.questID and not info.isHeader then
				total = total + 1
				local okReady, isReady = pcall(C_QuestLog.ReadyForTurnIn, info.questID)
				if okReady and isReady == true then ready = ready + 1 end
			end
		end
	elseif type(GetNumQuestLogEntries) == "function" and type(GetQuestLogTitle) == "function" then
		local ok, entries = pcall(GetNumQuestLogEntries)
		if not ok or type(entries) ~= "number" then return nil end
		for i = 1, entries do
			local r = { pcall(GetQuestLogTitle, i) }
			if r[1] and r[2] ~= nil then
				local isHeader = (type(r[5]) == "boolean") and r[5] or r[6]
				if not (isHeader == true or isHeader == 1) then total = total + 1 end
			end
			if ns.QuestLogReady(i) then ready = ready + 1 end
		end
	else
		return nil
	end
	return total, ready
end

-- Pièce d'équipement la plus usée, en % (nil sans API ou sans pièce)
function ns:LowestDurability()
	if type(GetInventoryItemDurability) ~= "function" then return nil end
	local worst = nil
	for slot = 1, 19 do
		local ok, current, max = pcall(GetInventoryItemDurability, slot)
		if ok and type(current) == "number" and type(max) == "number" and max > 0 then
			local percent = (current / max) * 100
			if not worst or percent < worst then worst = percent end
		end
	end
	return worst
end

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
ns.PlayerLevelNow, ns.PlayerClassToken = PlayerLevel, PlayerClass

local function AmmoCount()
	if type(GetInventoryItemCount) ~= "function" then return nil end
	local ok, count = pcall(GetInventoryItemCount, "player", 0)
	if ok and type(count) == "number" then return count end
	return nil
end

-- Projectiles rangés dans les sacs (classe d'objet 6), équipés ou non
local PROJECTILE = 6
local function AmmoInBags()
	local fn = (C_Item and C_Item.GetItemInfoInstant) or rawget(_G, "GetItemInfoInstant")
	if type(fn) ~= "function" then return 0 end
	local count = 0
	EachBagItem(function(_, _, info)
		local ok, _, _, _, _, _, classID = pcall(fn, info.itemID)
		if ok and classID == PROJECTILE then count = count + (info.stackCount or 1) end
	end)
	return count
end

-- Minimum du palier atteint (min = nombre, ou { { niveau, minimum }, … })
local function MinimumFor(min, level)
	if type(min) ~= "table" then return min end
	local value = 0
	for _, step in ipairs(min) do
		if level >= step[1] then value = step[2] end
	end
	return value
end
ns.ReagentMinimum = MinimumFor
ns.AmmoCount, ns.AmmoInBags = AmmoCount, AmmoInBags

-- Munitions du chasseur : minimum par paliers de niveau
ns.AMMO_MINIMUM = { { 1, 200 }, { 10, 600 }, { 30, 1000 } }

local HEARTHSTONE = 6948
local function HearthCooldown()
	local fn = (C_Container and C_Container.GetItemCooldown) or rawget(_G, "GetItemCooldown")
	if type(fn) ~= "function" then return 0 end
	local ok, start, duration = pcall(fn, HEARTHSTONE)
	if not ok or type(start) ~= "number" or type(duration) ~= "number" or start <= 0 then return 0 end
	local remaining = start + duration - ((ns.Now and ns.Now()) or 0)
	return remaining > 0 and remaining or 0
end
ns.HearthCooldown = HearthCooldown

if ns.Mark then ns.Mark("Gear") end
