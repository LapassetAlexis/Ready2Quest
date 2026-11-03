-- Reagents.lua -- suivi des recettes de métier et des composants manquants
--
-- Source des recettes : celles que TU as marquées comme suivies dans la fenêtre
-- de métier (l'étoile de Blizzard). Aucune liste codée en dur.
--
-- API utilisée (documentée, aucune restriction sur C_TradeSkillUI) :
--   C_TradeSkillUI.GetRecipesTracked(isRecraft)            -> { recipeSpellID, ... }
--   C_TradeSkillUI.GetCraftableCount(recipeSpellID)        -> nombre fabricable
--   C_TradeSkillUI.GetRecipeSchematic(recipeSpellID, false) -> CraftingRecipeSchematic
--     .reagentSlotSchematics[i].quantityRequired
--     .reagentSlotSchematics[i].reagents[j].itemID
local ADDON, ns = ...
local L = ns.L

local NUM_BAG_SLOTS = 4
local CACHE_TTL = 20   -- secondes

local cache = { at = 0, entries = nil }

local function BagCounts()
	local counts = {}
	if not (C_Container and type(C_Container.GetContainerNumSlots) == "function") then
		return counts
	end
	for bag = 0, NUM_BAG_SLOTS do
		local okSlots, slots = pcall(C_Container.GetContainerNumSlots, bag)
		if okSlots and type(slots) == "number" then
			for slot = 1, slots do
				local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
				if ok and type(info) == "table" and type(info.itemID) == "number" then
					counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
				end
			end
		end
	end
	return counts
end
ns.BagCounts = BagCounts

-- ---------------------------------------------------------------------------
-- Chemins Classic : la recette sélectionnée dans la fenêtre de métier
--   * TradeSkill : la plupart des métiers
--   * Craft      : Enchantement et dressage du chasseur, sur Era
-- Le client donne le nombre possédé (playerCount) au moment du scan ; pour
-- qu'il reste juste quand les sacs changent, on retient l'itemID du composant
-- et on recompte avec GetItemCount au moment du check.
-- ---------------------------------------------------------------------------
local LEGACY_APIS = {
	trade = {
		selection = "GetTradeSkillSelectionIndex", info = "GetTradeSkillInfo",
		num = "GetTradeSkillNumReagents", reagent = "GetTradeSkillReagentInfo",
		link = "GetTradeSkillReagentItemLink", setSelection = "TradeSkillFrame_SetSelection",
	},
	craft = {
		selection = "GetCraftSelectionIndex", info = "GetCraftInfo",
		num = "GetCraftNumReagents", reagent = "GetCraftReagentInfo",
		link = "GetCraftReagentItemLink", setSelection = "CraftFrame_SetSelection",
	},
}
local legacyCaches = { trade = {}, craft = {} }
local hooked = {}

local function Global(name)
	local fn = rawget(_G, name)
	if type(fn) == "function" then return fn end
	return nil
end

local function ItemIDFromLink(link)
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("item:(%d+)"))
end

local function ScanLegacy(kind)
	local api = LEGACY_APIS[kind]
	local getSel, getInfo = Global(api.selection), Global(api.info)
	local getNum, getReagent = Global(api.num), Global(api.reagent)
	if not (getSel and getInfo and getNum and getReagent) then return end

	local okSel, selection = pcall(getSel)
	if not okSel or type(selection) ~= "number" or selection < 1 then return end

	-- GetTradeSkillInfo : name, skillType ; GetCraftInfo : name, subSpellName, craftType
	local okInfo, recipeName, second, third = pcall(getInfo, selection)
	local recipeType = (kind == "craft") and third or second
	if not okInfo or type(recipeName) ~= "string" or recipeType == "header" then return end

	local reagents = {}
	local getLink = Global(api.link)
	local okCount, count = pcall(getNum, selection)
	if okCount and type(count) == "number" then
		for i = 1, count do
			local ok, reagentName, _, required, owned = pcall(getReagent, selection, i)
			if ok and type(reagentName) == "string" and type(required) == "number" then
				local itemID
				if getLink then
					local okLink, link = pcall(getLink, selection, i)
					if okLink then itemID = ItemIDFromLink(link) end
				end
				reagents[#reagents + 1] = { name = reagentName, need = required, have = owned or 0, itemID = itemID }
			end
		end
	end

	local cache = legacyCaches[kind]
	cache.name, cache.reagents, cache.at = recipeName, reagents, ns.Now()
end

-- Sur Era, changer de recette dans la fenêtre ne déclenche pas toujours
-- TRADE_SKILL_UPDATE : on s'accroche à la sélection elle-même. La fonction
-- n'existe qu'une fois l'interface du métier chargée, d'où l'appel répété.
function ns:HookLegacySelection()
	if type(hooksecurefunc) ~= "function" then return end
	for kind, api in pairs(LEGACY_APIS) do
		if not hooked[kind] and Global(api.setSelection) then
			hooked[kind] = true
			hooksecurefunc(api.setSelection, function()
				ScanLegacy(kind)
				ns:InvalidateReagents()
			end)
		end
	end
end

function ns:ScanLegacyTradeSkill()
	self:HookLegacySelection()
	ScanLegacy("trade")
end

function ns:ScanLegacyCraft()
	self:HookLegacySelection()
	ScanLegacy("craft")
end

local function LegacyReagentEntries()
	local entries = {}
	for _, kind in ipairs({ "trade", "craft" }) do
		local cache = legacyCaches[kind]
		if cache.reagents then
			local entry = { recipeID = -1, name = cache.name or "?", craftable = 0, missing = {} }
			for _, reagent in ipairs(cache.reagents) do
				local have = reagent.have or 0
				if reagent.itemID and ns.ItemCount then have = ns.ItemCount(reagent.itemID) end
				if have < reagent.need then
					entry.missing[#entry.missing + 1] = {
						name = reagent.name, need = reagent.need, have = have, deficit = reagent.need - have,
					}
				end
			end
			entry.craftable = (#entry.missing == 0) and 1 or 0
			entries[#entries + 1] = entry
		end
	end
	return entries
end

-- Réservé aux tests : vide les recettes mémorisées
function ns:ResetLegacyReagents()
	legacyCaches.trade, legacyCaches.craft = {}, {}
end

local function ItemName(itemID)
	if C_Item and type(C_Item.GetItemInfo) == "function" then
		local ok, name = pcall(C_Item.GetItemInfo, itemID)
		if ok and type(name) == "string" then return name end
	end
	return "item:" .. tostring(itemID)
end

function ns:InvalidateReagents()
	cache.entries = nil
	cache.at = 0
end

-- Retourne une liste : { { recipeID, name, craftable, missing = { {name, need, have, deficit} } } }
function ns:ReagentStatus()
	local now = ns.Now()
	if cache.entries and (now - cache.at) < CACHE_TTL then
		return cache.entries
	end

	local entries = {}
	cache.entries, cache.at = entries, now

	local caps = ns.Caps or {}
	if not caps.crafting then
		-- Client Classic : pas de « recettes suivies », on utilise la recette
		-- sélectionnée dans la fenêtre de métier.
		if caps.tradeskillLegacy or caps.craftLegacy then
			local legacy = LegacyReagentEntries()
			cache.entries, cache.at = legacy, now
			return legacy
		end
		return entries
	end

	local api = C_TradeSkillUI
	if not (api and type(api.GetRecipesTracked) == "function") then
		return entries
	end

	local okIds, recipeIDs = pcall(api.GetRecipesTracked, false)
	if not okIds or type(recipeIDs) ~= "table" then
		return entries
	end

	local counts = BagCounts()

	for _, recipeID in ipairs(recipeIDs) do
		local entry = {
			recipeID  = recipeID,
			name      = "recipe:" .. tostring(recipeID),
			craftable = 0,
			missing   = {},
		}

		if type(api.GetRecipeSchematic) == "function" then
			local okSchematic, schematic = pcall(api.GetRecipeSchematic, recipeID, false)
			if okSchematic and type(schematic) == "table" then
				if type(schematic.name) == "string" then entry.name = schematic.name end

				local slotSchematics = schematic.reagentSlotSchematics
				if type(slotSchematics) == "table" then
					for _, slot in ipairs(slotSchematics) do
						local required = slot.quantityRequired or 0
						local best, bestItem = -1, nil

						if type(slot.reagents) == "table" then
							for _, reagent in ipairs(slot.reagents) do
								local itemID = reagent.itemID
								if type(itemID) == "number" then
									local have = counts[itemID] or 0
									if have > best then best, bestItem = have, itemID end
								end
							end
						end

						if bestItem and required > 0 and best < required then
							entry.missing[#entry.missing + 1] = {
								name    = ItemName(bestItem),
								need    = required,
								have    = best,
								deficit = required - best,
							}
						end
					end
				end
			end
		end

		if type(api.GetCraftableCount) == "function" then
			local okCount, count = pcall(api.GetCraftableCount, recipeID)
			if okCount and type(count) == "number" then entry.craftable = count end
		end

		entries[#entries + 1] = entry
	end

	table.sort(entries, function(a, b) return tostring(a.name) < tostring(b.name) end)
	return entries
end

-- Résumé pour la checklist : (ok, detail)
function ns:ReagentSummary()
	local entries = self:ReagentStatus()
	if #entries == 0 then
		return true, L.CHK_REAGENTS_NONE
	end

	local blocked = {}
	for _, entry in ipairs(entries) do
		if entry.craftable <= 0 then blocked[#blocked + 1] = entry end
	end

	if #blocked == 0 then
		return true, self:F("CHK_REAGENTS_OK", #entries)
	end

	local first = blocked[1]
	local detail
	if #first.missing > 0 then
		local gap = first.missing[1]
		detail = self:F("CHK_REAGENTS_MISSING", first.name, gap.deficit, gap.name)
	else
		detail = self:F("CHK_REAGENTS_GENERIC", first.name)
	end
	if #blocked > 1 then
		detail = detail .. self:F("CHK_REAGENTS_MORE", #blocked - 1)
	end
	return false, detail
end

-- Commande /sd compo : affiche les recettes suivies et ce qui bloque
function ns:PrintReagents()
	local entries = self:ReagentStatus()
	if #entries == 0 then
		self:Print(L.CHK_REAGENTS_NONE)
		if ns.Caps and (ns.Caps.tradeskillLegacy or ns.Caps.craftLegacy) and not ns.Caps.crafting then
			self:Print("  Ouvre ta fenêtre de métier et sélectionne une recette.")
		else
			self:Print("  Coche l'étoile d'une recette dans ta fenêtre de métier.")
		end
		return
	end

	for _, entry in ipairs(entries) do
		local state = entry.craftable > 0 and ("fabricable x" .. entry.craftable) or "bloquée"
		self:Print(string.format("  %s |cff888888(%s)|r", entry.name, state))
		for _, gap in ipairs(entry.missing) do
			self:Print(string.format("     manque %d %s |cff888888(%d/%d)|r",
				gap.deficit, gap.name, gap.have, gap.need))
		end
	end
end

if ns.Mark then ns.Mark("Reagents") end
