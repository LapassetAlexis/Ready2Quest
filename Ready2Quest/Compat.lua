-- Compat.lua -- détection des capacités du client (Forever / Classic Era / …)
--
-- L'addon utilise une dizaine d'API namespacées récentes. Certaines n'existent
-- pas dans les clients Classic. Plutôt que de tester au cas par cas dans chaque
-- module, on sonde une fois au chargement et on expose ns.Caps.
local ADDON, ns = ...

ns.Caps = {}

function ns:DetectCapabilities()
	local caps = {}

	caps.container = (C_Container and type(C_Container.GetContainerNumSlots) == "function") and true or false
	caps.auramodern = (C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") and true or false
	caps.crafting = (C_TradeSkillUI and type(C_TradeSkillUI.GetRecipesTracked) == "function") and true or false

	-- Chemin « métiers Classic » : recette sélectionnée + réactifs, avec le
	-- nombre possédé fourni par le client.
	caps.tradeskillLegacy = (type(GetTradeSkillLine) == "function"
		and type(GetTradeSkillSelectionIndex) == "function"
		and type(GetTradeSkillInfo) == "function"
		and type(GetTradeSkillNumReagents) == "function"
		and type(GetTradeSkillReagentInfo) == "function") and true or false

	-- Era : Enchantement et dressage du chasseur passent par la fenêtre Craft
	caps.craftLegacy = (type(GetCraftSelectionIndex) == "function"
		and type(GetCraftInfo) == "function"
		and type(GetCraftNumReagents) == "function"
		and type(GetCraftReagentInfo) == "function") and true or false

	caps.questlogNamespaced = (C_QuestLog and type(C_QuestLog.GetNumQuestLogEntries) == "function") and true or false
	caps.questlogLegacy = (type(GetNumQuestLogEntries) == "function" and type(GetQuestLogTitle) == "function") and true or false
	caps.quests = caps.questlogNamespaced or caps.questlogLegacy


	caps.durability = type(GetInventoryItemDurability) == "function"
	caps.equippedLink = type(GetInventoryItemLink) == "function"
	caps.rested = type(GetXPExhaustion) == "function"
	caps.resting = type(IsResting) == "function"
	caps.sanctuary = type(UnitIsPVPSanctuary) == "function"

	ns.Caps = caps
	return caps
end

function ns:BuildInfo()
	if type(GetBuildInfo) ~= "function" then return nil end
	local ok, version, build, date, toc = pcall(GetBuildInfo)
	if not ok then return nil end
	return { version = version, build = build, date = date, toc = tonumber(toc) }
end

-- Nom lisible du client, d'après le numéro d'interface (le plus fiable)
function ns:ClientFlavour()
	local info = self:BuildInfo()
	local toc = info and info.toc
	if toc then
		if toc >= 120000 then return "Retail" end
		if toc >= 16000 and toc < 17000 then return "Forever" end
		if toc >= 50000 and toc < 60000 then return "Mists Classic" end
		if toc >= 20000 and toc < 30000 then return "TBC Classic" end
		if toc >= 30000 and toc < 40000 then return "Titan Reforged" end
		if toc >= 11000 and toc < 12000 then return "Classic Era" end
		return "client " .. tostring(toc)
	end

	-- Repli sur les capacités si GetBuildInfo est absent
	local caps = ns.Caps
	if caps.crafting and caps.questlogNamespaced then return "Forever" end
	if caps.questlogLegacy then return "Classic (Era/MoP)" end
	if caps.auramodern then return "moderne (non identifié)" end
	return "inconnu"
end

function ns:PrintCapabilities()
	local info = self:BuildInfo()
	local build = ""
	if info then
		build = string.format(" |cff8c8c8c(build %s, interface %s)|r",
			tostring(info.version or "?"), tostring(info.toc or "?"))
	end
	self:Print("client = |cffffd100" .. self:ClientFlavour() .. "|r" .. build)
	local keys = {}
	for key in pairs(ns.Caps) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local value = ns.Caps[key]
		local color = value and "|cff1eff00" or "|cffff2020"
		self:Print(string.format("  %-18s %s%s|r", key, color, tostring(value)))
	end
end

ns:DetectCapabilities()

if ns.Mark then ns.Mark("Compat") end
