-- Compat.lua -- détection des capacités du client (WoW Forever, /diag)
--
-- L'addon utilise une dizaine d'API namespacées récentes. Plutôt que de tester
-- au cas par cas dans chaque module, on sonde une fois au chargement et on
-- expose ns.Caps (affiché par /diag : utile pour vérifier ce que le client
-- de Forever expose vraiment).
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
local ADDON, ns = ...

ns.Caps = {}

-- Valeurs « secrètes » (moteur récent, dont WoW Forever) : le client peut
-- rendre la vie, la puissance, une icône de cible… sous une forme qu'un addon
-- peut afficher mais ni comparer ni compter (« attempt to perform arithmetic
-- on a secret number value »). ns.Plain(v) rend la valeur, ou nil si elle est
-- secrète : l'appelant fait alors comme s'il ne savait pas. Sans
-- issecretvalue, la valeur passe telle quelle.
function ns.Plain(value)
	local isSecret = rawget(_G, "issecretvalue")
	if type(isSecret) == "function" then
		local ok, secret = pcall(isSecret, value)
		if not ok or secret then return nil end
	end
	return value
end

-- Fiche d'un objet : mêmes retours que GetItemInfo (tous, sans troncature :
-- certains appelants les captent en table), C_Item.GetItemInfo d'abord, la
-- globale en repli. Objet pas encore en cache client : nil, et on demande
-- son chargement (C_Item.RequestLoadItemDataByID) ; avec onLoad, l'appel
-- est rappelé une fois l'objet chargé (Item:CreateFromItemID, une seule
-- attente par objet et par fonction). Sans ces API : nil, comme avant.
local unpack = unpack or table.unpack   -- Lua 5.1 (client) / 5.4+
local function Pack(...) return { n = select("#", ...), ... } end

local function ItemIDOf(item)
	if type(item) == "number" then return item end
	if type(item) == "string" then return tonumber(item) or tonumber(item:match("item:(%d+)")) end
	return nil
end

local itemWaits = {}   -- itemID -> { [onLoad] = true } : attentes en cours
ns.itemWaits = itemWaits
-- demandes de chargement récentes : itemID -> instant, pour ne pas relancer
-- le serveur à chaque rafraîchissement (sacs, infobulles…)
local itemRequested = {}
local ITEM_REQUEST_GAP = 5

local function RequestItem(item, onLoad)
	local itemID = ItemIDOf(item)
	if not itemID or itemID <= 0 then return end
	local api = rawget(_G, "C_Item")
	local now = (ns.Now and ns.Now()) or 0
	local last = itemRequested[itemID]
	if type(api) == "table" and type(api.RequestLoadItemDataByID) == "function"
		and not (last and now >= last and now - last < ITEM_REQUEST_GAP) then
		itemRequested[itemID] = now
		pcall(api.RequestLoadItemDataByID, itemID)
	end
	if type(onLoad) ~= "function" then return end
	local waits = itemWaits[itemID]
	if waits then waits[onLoad] = true; return end
	local mixin = rawget(_G, "Item")
	if type(mixin) ~= "table" or type(mixin.CreateFromItemID) ~= "function" then return end
	local ok, object = pcall(mixin.CreateFromItemID, mixin, itemID)
	if not ok or type(object) ~= "table" or type(object.ContinueOnItemLoad) ~= "function" then return end
	waits = { [onLoad] = true }
	itemWaits[itemID] = waits
	local queued = pcall(object.ContinueOnItemLoad, object, function()
		itemWaits[itemID] = nil
		for fn in pairs(waits) do
			local done, err = pcall(fn, item)
			if not done and ns.RecordError then ns:RecordError("item:load", err) end
		end
	end)
	if not queued then itemWaits[itemID] = nil end
end

function ns.ItemInfo(item, onLoad)
	if item == nil then return nil end
	local api = rawget(_G, "C_Item")
	local fn = (type(api) == "table" and type(api.GetItemInfo) == "function" and api.GetItemInfo)
		or rawget(_G, "GetItemInfo")
	if type(fn) ~= "function" then return nil end
	local r = Pack(pcall(fn, item))
	if not r[1] then return nil end
	if r[2] ~= nil then return unpack(r, 2, r.n) end
	RequestItem(item, onLoad)
	return nil
end

-- Infobulles : une ligne ajoutée à GameTooltip au survol d'une unité
-- (kind = "Unit") ou d'un objet ("Item"). Moteur récent :
-- TooltipDataProcessor.AddTooltipPostCall, fn(tooltip, data) ; sinon
-- GameTooltip:HookScript("OnTooltipSet<kind>"), fn(tooltip, nil). Une seule
-- accroche par sorte (et par addon) ; seule GameTooltip est touchée, jamais
-- les infobulles de comparaison ni celles d'autres addons. Renvoie la voie
-- prise ("processor", "script") ou nil.
ns.tooltipHooks = ns.tooltipHooks or {}
function ns:HookTooltip(kind, fn)
	if self.tooltipHooks[kind] or type(fn) ~= "function" then return self.tooltipHooks[kind] end
	local function Run(tooltip, data)
		if tooltip == nil or tooltip ~= rawget(_G, "GameTooltip") then return end
		local ok, err = pcall(fn, tooltip, data)
		if not ok and ns.RecordError then ns:RecordError("tooltip:" .. tostring(kind), err) end
	end
	local processor, enum = rawget(_G, "TooltipDataProcessor"), rawget(_G, "Enum")
	local dataType = type(enum) == "table" and type(enum.TooltipDataType) == "table" and enum.TooltipDataType[kind]
	if dataType ~= nil and dataType ~= false and type(processor) == "table"
		and type(processor.AddTooltipPostCall) == "function"
		and pcall(processor.AddTooltipPostCall, dataType, Run) then
		self.tooltipHooks[kind] = "processor"
		return "processor"
	end
	local tooltip = rawget(_G, "GameTooltip")
	if type(tooltip) == "table" and type(tooltip.HookScript) == "function"
		and pcall(tooltip.HookScript, tooltip, "OnTooltipSet" .. kind, function(tt) Run(tt, nil) end) then
		self.tooltipHooks[kind] = "script"
		return "script"
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Journal de combat : fermé aux addons sur le moteur 12.0 (dont WoW Forever).
-- S'y abonner y lève une erreur ; à la place, deux événements autonomes :
-- PARTY_KILL (attackerGUID, targetGUID) et UNIT_DIED (unitGUID).
-- ---------------------------------------------------------------------------
function ns.CombatLogRestricted()
	local api = rawget(_G, "C_CombatLog")
	if type(api) == "table" and type(api.IsCombatLogRestricted) == "function" then
		local ok, restricted = pcall(api.IsCombatLogRestricted)
		if ok and restricted ~= nil then return ns.Plain(restricted) ~= false end
	end
	return type(rawget(_G, "CombatLogGetCurrentEventInfo")) ~= "function"
end

-- Drapeaux d'affiliation façon journal de combat (1 = moi ou mon familier,
-- 2 = groupe, 4 = raid) d'après un GUID : les événements autonomes n'en
-- donnent pas. nil pour un inconnu ou un GUID secret.
function ns.GroupFlags(guid)
	guid = ns.Plain(guid)
	local unitGUID = rawget(_G, "UnitGUID")
	if type(guid) ~= "string" or type(unitGUID) ~= "function" then return nil end
	local function Is(unit)
		local ok, other = pcall(unitGUID, unit)
		return ok and ns.Plain(other) == guid
	end
	if Is("player") or Is("pet") then return 1 end
	for i = 1, 4 do if Is("party" .. i) or Is("partypet" .. i) then return 2 end end
	for i = 1, 40 do if Is("raid" .. i) then return 4 end end
	return nil
end

-- Abonne frame aux événements de handlers. Le journal de combat seulement
-- s'il est ouvert ; sinon (ou s'il refuse) PARTY_KILL et UNIT_DIED prennent
-- le relais, jamais les deux (une mort ne compte qu'une fois). Un événement
-- inconnu du client ne bloque pas les autres. Rend true si le journal est écouté.
local CLEU = "COMBAT_LOG_EVENT_UNFILTERED"
local STANDALONE = { PARTY_KILL = true, UNIT_DIED = true }
function ns.RegisterHandlers(frame, handlers)
	local logOpen = false
	if handlers[CLEU] and not ns.CombatLogRestricted() then
		logOpen = pcall(frame.RegisterEvent, frame, CLEU) and true or false
	end
	for event in pairs(handlers) do
		if event ~= CLEU and not (STANDALONE[event] and logOpen) then
			pcall(frame.RegisterEvent, frame, event)
		end
	end
	return logOpen
end

local probeModel

function ns:DetectCapabilities()
	local caps = {}

	caps.container = (C_Container and type(C_Container.GetContainerNumSlots) == "function") and true or false
	caps.auramodern = (C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") and true or false
	caps.crafting = (C_TradeSkillUI and type(C_TradeSkillUI.GetRecipesTracked) == "function") and true or false

	caps.questlogNamespaced = (C_QuestLog and type(C_QuestLog.GetNumQuestLogEntries) == "function") and true or false
	caps.quests = caps.questlogNamespaced


	caps.durability = type(GetInventoryItemDurability) == "function"
	caps.equippedLink = type(GetInventoryItemLink) == "function"
	caps.rested = type(GetXPExhaustion) == "function"
	caps.resting = type(IsResting) == "function"
	caps.sanctuary = type(UnitIsPVPSanctuary) == "function"

	-- Points encore incertains sur Forever : les replis restent dans le code,
	-- ces sondes (lues par /diag) disent lequel le client prend vraiment.
	--   spellbookModern : livre de sorts C_SpellBook (sinon boucle historique, SpellRanks.lua)
	--   unitAuraLegacy  : UnitAura global (repli de lecture des auras par index)
	--   itemInfoGlobal  : GetItemInfo global (repli quand C_Item.GetItemInfo manque)
	--   specialization  : GetSpecialization (sinon onglet de talents le plus fourni, Stats.lua)
	local spellBook = rawget(_G, "C_SpellBook")
	-- exactement ce dont a besoin la branche récente de SpellRanks.lua
	local enum = rawget(_G, "Enum")
	caps.spellbookModern = (type(spellBook) == "table" and type(spellBook.GetSpellBookItemInfo) == "function"
		and type(spellBook.GetNumSpellBookSkillLines) == "function"
		and type(enum) == "table" and type(enum.SpellBookSpellBank) == "table") and true or false
	caps.unitAuraLegacy = type(rawget(_G, "UnitAura")) == "function"
	caps.itemInfoGlobal = type(rawget(_G, "GetItemInfo")) == "function"
	caps.specialization = type(rawget(_G, "GetSpecialization")) == "function"

	-- API récentes exploitées quand le client les expose (sinon comportement
	-- historique) : chaque module consulte ces drapeaux, /diag les affiche.
	--   vignettes      : C_VignetteInfo (rares signalés en direct)
	--   tooltipData    : TooltipDataProcessor (infobulles enrichies)
	--   mapLevels      : C_Map.GetMapLevels (tranche de niveaux des zones)
	--   lfgDungeons    : GetLFGDungeonInfo (niveaux des donjons)
	--   questsOnMap    : C_QuestLine / C_TaskQuest (quêtes proposées sur la carte)
	--   settingsPanel  : Settings.RegisterCanvasLayoutCategory (Échap > Options > AddOns)
	--   addonCompartment : AddonCompartmentFrame (bouton des addons de la minicarte)
	--   itemAsync      : Item:CreateFromItemID (chargement des objets)
	--   modelAnimation : PlayerModel:SetAnimation (animations du compagnon)
	local function Fn(tbl, key)
		tbl = rawget(_G, tbl)
		return type(tbl) == "table" and type(tbl[key]) == "function"
	end
	caps.vignettes = Fn("C_VignetteInfo", "GetVignettes") and Fn("C_VignetteInfo", "GetVignetteInfo")
	caps.tooltipData = Fn("TooltipDataProcessor", "AddTooltipPostCall")
		and type(rawget(_G, "Enum")) == "table" and type(Enum.TooltipDataType) == "table"
	caps.mapLevels = Fn("C_Map", "GetMapLevels")
	caps.lfgDungeons = type(rawget(_G, "GetLFGDungeonInfo")) == "function"
	caps.questsOnMap = Fn("C_QuestLine", "GetAvailableQuestLines") or Fn("C_TaskQuest", "GetQuestsOnMap")
	caps.settingsPanel = Fn("Settings", "RegisterCanvasLayoutCategory") and Fn("Settings", "RegisterAddOnCategory")
	local compartment = rawget(_G, "AddonCompartmentFrame")
	caps.addonCompartment = type(compartment) == "table" and type(compartment.RegisterAddon) == "function"
	caps.itemAsync = Fn("Item", "CreateFromItemID")
	caps.combatLog = not ns.CombatLogRestricted()
	-- un seul modèle de sonde, jamais affiché, réutilisé à chaque détection
	if probeModel == nil and type(rawget(_G, "CreateFrame")) == "function" then
		local ok, model = pcall(CreateFrame, "PlayerModel")
		probeModel = ok and model or false
	end
	caps.modelAnimation = (probeModel and type(probeModel.SetAnimation) == "function") and true or false

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
