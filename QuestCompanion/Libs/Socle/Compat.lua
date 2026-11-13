-- Compat.lua -- détection des capacités du client (WoW Forever, /diag)
--
-- L'addon utilise une dizaine d'API namespacées récentes. Plutôt que de tester
-- au cas par cas dans chaque module, on sonde une fois au chargement et on
-- expose ns.Caps (affiché par /diag : utile pour vérifier ce que le client
-- de Forever expose vraiment).
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
-- socle 2.11.0 : corps du fichier dans une fabrique, compilée une fois quand
-- les deux addons ont le même socle (Base.lua, ns.SocleFile). Rien de propre
-- à l'addon au niveau du fichier : tout passe par ADDON et ns, ci-dessous.
local SOCLE_ADDON, SOCLE_NS = ...
;(SOCLE_NS.SocleFile or function(_, factory) return factory end)("Compat", function(...)
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
-- Jetons d'unité faits une fois (appelé à chaque mort vue : pas de
-- concaténation ni de fermeture par appel)
local PARTY_UNITS, RAID_UNITS = {}, {}
for i = 1, 4 do PARTY_UNITS[#PARTY_UNITS + 1] = "party" .. i; PARTY_UNITS[#PARTY_UNITS + 1] = "partypet" .. i end
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end
local function SameGUID(unitGUID, unit, guid)
	local ok, other = pcall(unitGUID, unit)
	return ok and ns.Plain(other) == guid
end
function ns.GroupFlags(guid)
	guid = ns.Plain(guid)
	local unitGUID = rawget(_G, "UnitGUID")
	if type(guid) ~= "string" or type(unitGUID) ~= "function" then return nil end
	if SameGUID(unitGUID, "player", guid) or SameGUID(unitGUID, "pet", guid) then return 1 end
	for i = 1, #PARTY_UNITS do if SameGUID(unitGUID, PARTY_UNITS[i], guid) then return 2 end end
	for i = 1, #RAID_UNITS do if SameGUID(unitGUID, RAID_UNITS[i], guid) then return 4 end end
	return nil
end

-- Abonne frame aux événements de handlers. Le journal de combat seulement
-- s'il est ouvert ; sinon (ou s'il refuse) PARTY_KILL et UNIT_DIED prennent
-- le relais, jamais les deux (une mort ne compte qu'une fois). Un événement
-- inconnu du client ne bloque pas les autres. Rend true si le journal est écouté.
-- Événements d'unité que les deux addons ne lisent que pour le joueur : le
-- client les envoie aussi pour la cible, le groupe, le raid et chaque barre
-- de vie (des centaines par seconde en combat). RegisterUnitEvent les filtre
-- côté client ; repli sur RegisterEvent (les gestionnaires gardent leur test
-- unit == "player"). Un gestionnaire ajouté ici ne voit plus que le joueur.
ns.PLAYER_UNIT_EVENTS = { UNIT_AURA = true, UNIT_STATS = true }
function ns.RegisterGameEvent(frame, event)
	if ns.PLAYER_UNIT_EVENTS[event] and type(frame.RegisterUnitEvent) == "function" then
		if pcall(frame.RegisterUnitEvent, frame, event, "player") then return true end
	end
	return pcall(frame.RegisterEvent, frame, event) and true or false
end

local CLEU = "COMBAT_LOG_EVENT_UNFILTERED"
local STANDALONE = { PARTY_KILL = true, UNIT_DIED = true }
function ns.RegisterHandlers(frame, handlers)
	local logOpen = false
	if handlers[CLEU] and not ns.CombatLogRestricted() then
		logOpen = pcall(frame.RegisterEvent, frame, CLEU) and true or false
	end
	for event in pairs(handlers) do
		if event ~= CLEU and not (STANDALONE[event] and logOpen) then
			ns.RegisterGameEvent(frame, event)
		end
	end
	return logOpen
end

-- ---------------------------------------------------------------------------
-- socle 3.1.0 : un seul cadre d'événements par addon (passe de performance 2)
-- ---------------------------------------------------------------------------
-- Avant, chaque module avait son cadre : un événement suivi par cinq modules
-- (barre de vie qui apparaît, changement de zone…) faisait cinq appels du
-- client vers le Lua. Ici, un cadre (créé au premier abonné) et une liste
-- d'abonnés par événement : l'événement est enregistré auprès du client au
-- premier abonné actif, retiré au dernier. Chaque abonné est appelé sous
-- pcall, dans l'ordre d'abonnement ; une erreur est notée (« où:ÉVÉNEMENT »).
--   ns.On(événement, qui, fn[, où]) : abonne (ou remplace la fonction de) `qui`
--     (chaîne ou table) ; rend true si le client écoute l'événement.
--   ns.Off(événement, qui) ; ns.Unlisten(qui) : désabonne (tout `qui`).
--   ns.Listen(qui, handlers[, porte[, nom]]) : comme ns.RegisterHandlers (journal de
--     combat s'il est ouvert, sinon PARTY_KILL / UNIT_DIED) ; rend true si le
--     journal est écouté. porte() rend false : les événements de `qui` ne
--     sont plus écoutés (module coupé), jusqu'au prochain ns.EventsResync() ;
--     nom : préfixe des erreurs notées (sinon `qui`).
--   ns.EventGate(qui, porte) : la même porte, posée seule.
--   ns.EventHold(qui, oui) : écoute de `qui` mise en attente / reprise (ce
--     qui ne sert pas en combat), sans perdre son rang dans l'ordre d'appel.
--   ns.EventsResync() : relit les portes (réglage changé). Tant qu'une porte
--     est fermée, elle est relue toutes les EVENT_GATE_POLL s (un réglage
--     changé par un autre chemin rouvre l'écoute dans la seconde).
--   ns.EventDeliver(qui, événement, ...) : le gestionnaire de `qui` seul,
--     protégé (tests, simulation).
--   ns.Listening(événement[, qui]) : écouté (par `qui`, s'il est donné).
-- Les gestionnaires gardent leurs propres tests (ModuleOn…) : la porte
-- n'économise que les appels, jamais elle ne remplace un test.
ns.EVENT_GATE_POLL = 1
local hubFrame                 -- nil : pas encore créé ; false : création impossible
local hubSubs = {}             -- événement -> { entrée, … } dans l'ordre d'abonnement
local hubActive = {}           -- événement -> nombre d'abonnés actifs
local hubHeard = {}            -- événement -> true si le client l'envoie au cadre
local hubGates = {}            -- qui -> porte ; hubOpen[qui] : dernière lecture
local hubOpen = {}
local hubHeld = {}             -- qui -> true : mis en attente (ns.EventHold)
local hubDepth, hubDirty = 0, false

local function HubCompact()
	for _, list in pairs(hubSubs) do
		for i = #list, 1, -1 do if list[i].dead then table.remove(list, i) end end
	end
	hubDirty = false
end

local function HubDispatch(_, event, ...)
	local list = hubSubs[event]
	if not list then return end
	hubDepth = hubDepth + 1
	for i = 1, #list do
		local entry = list[i]
		if entry.active then
			local ok, err = pcall(entry.fn, ...)
			if not ok and ns.RecordError then ns:RecordError(entry.where or (tostring(entry.label) .. ":" .. tostring(event)), err) end
		end
	end
	hubDepth = hubDepth - 1
	if hubDirty and hubDepth == 0 then HubCompact() end
end
ns.EventDispatch = function(event, ...) return HubDispatch(nil, event, ...) end

local function Hub()
	if hubFrame == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		hubFrame = (ok and frame) or false
		if hubFrame then
			hubFrame:SetScript("OnEvent", HubDispatch)
			ns.eventHub = hubFrame
		end
	end
	return hubFrame
end

-- un abonné de plus ou de moins sur `event` : le client suit
local function HubCount(event, delta)
	local count = (hubActive[event] or 0) + delta
	hubActive[event] = count
	local frame = Hub()
	if not frame then return false end
	if count > 0 and not hubHeard[event] then
		hubHeard[event] = ns.RegisterGameEvent(frame, event) or nil
	elseif count <= 0 then
		hubActive[event] = 0
		if hubHeard[event] then
			hubHeard[event] = nil
			if type(frame.UnregisterEvent) == "function" then pcall(frame.UnregisterEvent, frame, event) end
		end
	end
	return hubHeard[event] == true
end

-- le client accepte-t-il `event` sur ce cadre ? (essayé une fois, sans
-- laisser l'événement enregistré s'il n'a pas encore d'abonné actif)
local hubAccepts = {}
local function HubAccepts(event)
	if hubHeard[event] then return true end
	if hubAccepts[event] == nil then
		local frame = Hub()
		local ok = frame and ns.RegisterGameEvent(frame, event) or false
		if ok and (hubActive[event] or 0) <= 0 and type(frame.UnregisterEvent) == "function" then
			pcall(frame.UnregisterEvent, frame, event)
		elseif ok then
			hubHeard[event] = true
		end
		hubAccepts[event] = ok and true or false
	end
	return hubAccepts[event]
end

local function Find(event, owner)
	local list = hubSubs[event]
	if not list then return nil end
	for i = 1, #list do
		local entry = list[i]
		if entry.owner == owner and not entry.dead then return entry end
	end
	return nil
end

local function SetActive(entry, on)
	if entry.active == on then return end
	entry.active = on
	HubCount(entry.event, on and 1 or -1)
end

function ns.On(event, owner, fn, where)
	if type(event) ~= "string" or owner == nil or type(fn) ~= "function" then return false end
	local entry = Find(event, owner)
	if entry then
		entry.fn, entry.where = fn, where
	else
		local list = hubSubs[event]
		if not list then list = {}; hubSubs[event] = list end
		entry = { event = event, owner = owner, fn = fn, where = where, active = false,
			label = type(owner) == "string" and owner or "event" }
		list[#list + 1] = entry
	end
	SetActive(entry, hubOpen[owner] ~= false and not hubHeld[owner])
	if not entry.active then return false end
	return hubHeard[event] == true
end

function ns.Off(event, owner)
	local entry = Find(event, owner)
	if not entry then return end
	SetActive(entry, false)
	entry.dead, entry.fn = true, nil
	if hubDepth > 0 then hubDirty = true else HubCompact() end
end

function ns.Unlisten(owner)
	for event in pairs(hubSubs) do ns.Off(event, owner) end
	hubGates[owner], hubOpen[owner], hubHeld[owner] = nil, nil, nil
end

-- toutes les entrées de `owner` suivent sa porte et sa mise en attente ;
-- elles gardent leur place dans l'ordre d'appel
local function OwnerSync(owner)
	local on = hubOpen[owner] ~= false and not hubHeld[owner]
	for _, list in pairs(hubSubs) do
		for i = 1, #list do
			local entry = list[i]
			if entry.owner == owner and not entry.dead then SetActive(entry, on) end
		end
	end
end

-- Met en attente (held vrai) ou reprend l'écoute de `owner`, sans perdre
-- son rang : pour ce qui ne sert qu'en combat, ou hors combat
function ns.EventHold(owner, held)
	held = held and true or nil
	if hubHeld[owner] == held then return end
	hubHeld[owner] = held
	OwnerSync(owner)
end

local function GateOpen(gate)
	local ok, open = pcall(gate)
	return not ok or open ~= false and open ~= nil
end

local function GatePoll() ns.EventsResync() end
function ns.EventsResync()
	local closed = false
	for owner, gate in pairs(hubGates) do
		local open = GateOpen(gate)
		if hubOpen[owner] ~= open then
			hubOpen[owner] = open
			OwnerSync(owner)
		end
		if not open then closed = true end
	end
	-- une porte fermée est relue de temps en temps (filet de sécurité) ;
	-- toutes ouvertes : aucune tâche
	if ns.Every then
		if closed then
			ns.Every("events:gates", ns.EVENT_GATE_POLL, GatePoll)
		elseif ns.Cancel then
			ns.Cancel("events:gates")
		end
	end
	return closed
end

-- porte de `owner` (relue par ns.EventsResync) ; ouverte jusqu'à la relecture
function ns.EventGate(owner, gate)
	if type(gate) ~= "function" then return end
	hubGates[owner] = gate
	if hubOpen[owner] == nil then hubOpen[owner] = true end
end

function ns.Listen(owner, handlers, gate, label)
	ns.EventGate(owner, gate)
	local logOpen = false
	if handlers[CLEU] and not ns.CombatLogRestricted() and HubAccepts(CLEU) then
		logOpen = true
		ns.On(CLEU, owner, handlers[CLEU], label and (label .. ":" .. CLEU))
	end
	for event, fn in pairs(handlers) do
		if event ~= CLEU and not (STANDALONE[event] and logOpen) then
			ns.On(event, owner, fn, label and (label .. ":" .. tostring(event)))
		end
	end
	return logOpen
end

function ns.EventDeliver(owner, event, ...)
	local entry = Find(event, owner)
	if not (entry and entry.fn) then return false end
	local ok, err = pcall(entry.fn, ...)
	if not ok and ns.RecordError then ns:RecordError(entry.where or (tostring(entry.label) .. ":" .. tostring(event)), err) end
	return ok
end

function ns.Listening(event, owner)
	if owner ~= nil then
		local entry = Find(event, owner)
		return (entry and entry.active and hubHeard[event]) and true or false
	end
	return hubHeard[event] == true
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
	if caps.auramodern then return (ns.L and ns.L.MSG_CLIENT_MODERN) or "modern" end
	return (ns.L and ns.L.MSG_CLIENT_UNKNOWN) or "unknown"
end

-- 2.11.0 / 1.32.0 (fiche 28) : couleurs du thème (Compat passe avant Theme.lua :
-- lues à l'appel, quand tout est chargé)
function ns:PrintCapabilities()
	local Theme = ns.Theme
	local info = self:BuildInfo()
	local build = ""
	if info then
		build = string.format(" " .. Theme.T_GREY .. "(build %s, interface %s)|r",
			tostring(info.version or "?"), tostring(info.toc or "?"))
	end
	self:Print("client = " .. Theme.T_GOLD .. self:ClientFlavour() .. "|r" .. build)
	local keys = {}
	for key in pairs(ns.Caps) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local value = ns.Caps[key]
		local color = value and Theme.T_GREEN or Theme.T_RED
		self:Print(string.format("  %-18s %s%s|r", key, color, tostring(value)))
	end
end

-- ---------------------------------------------------------------------------
-- socle 3.0.1 : un autre addon (l'autre addon du projet, page « Addons liés »)
--   ns.AddonStatus(nom, globale) -> "loaded" | "disabled" | "missing", version
--   ns.AddonEnable(nom)          -> true si activé pour ce personnage (hors combat)
--   ns:AskReload(titre)          -> demande de recharger l'interface
--   ns:ShowCopyLinks(titre, liens) -> fenêtre avec un lien à copier ; un
--                                   bouton par lien ({ { label, url }, … })
-- C_AddOns d'abord, sinon les anciennes globales ; tout est gardé.
-- ---------------------------------------------------------------------------
local function AddonApi(name)
	local api = rawget(_G, "C_AddOns")
	if type(api) == "table" and type(api[name]) == "function" then return api[name] end
	local fn = rawget(_G, name)
	if type(fn) == "function" then return fn end
	return nil
end

local function Try(fn, ...)
	if type(fn) ~= "function" then return nil end
	local r = Pack(pcall(fn, ...))
	if not r[1] then return nil end
	return unpack(r, 2, r.n)
end

function ns.AddonStatus(name, global)
	local other = type(global) == "string" and rawget(_G, global) or nil
	if type(other) ~= "table" then other = nil end
	local version = ns.Plain(Try(AddonApi("GetAddOnMetadata"), name, "Version"))
	if type(version) ~= "string" and other then version = other.version end
	if Try(AddonApi("IsAddOnLoaded"), name) or (other and other.version) then return "loaded", version end
	local exists = AddonApi("DoesAddOnExist")
	if exists then
		local ok, yes = pcall(exists, name)
		if ok and yes == false then return "missing" end
		if ok and yes then return "disabled", version end
	end
	local info = AddonApi("GetAddOnInfo")
	if info then
		local ok, found, _, _, _, reason = pcall(info, name)
		if ok and found ~= nil and reason ~= "MISSING" then return "disabled", version end
	end
	return "missing"
end

function ns.AddonEnable(name)
	if Try(rawget(_G, "InCombatLockdown")) then return false end
	local enable = AddonApi("EnableAddOn")
	if not enable then return false end
	local who = Try(rawget(_G, "UnitName"), "player")
	return (pcall(enable, name, who)) and true or false
end

local function PopupKey(suffix) return string.upper(tostring(ns.APP and ns.APP.id or ADDON)) .. "_" .. suffix end

function ns:AskReload(title)
	local dialogs, show = rawget(_G, "StaticPopupDialogs"), rawget(_G, "StaticPopup_Show")
	local reload = rawget(_G, "ReloadUI")
	if type(dialogs) ~= "table" or type(show) ~= "function" or type(reload) ~= "function" then return nil end
	local key = PopupKey("RELOAD")
	dialogs[key] = dialogs[key] or {
		text = ns.L.LINK_RELOAD_ASK, button1 = ns.L.LINK_RELOAD, button2 = ns.L.OPT_CLOSE,
		OnAccept = function() local fn = rawget(_G, "ReloadUI"); if type(fn) == "function" then fn() end end,
		timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
	}
	return Try(show, key, tostring(title or ""))
end

-- Le champ ne se modifie pas : chaque frappe remet le lien, tout sélectionné
function ns.CopyBoxLock(box, url)
	box.copyURL = url
	if box.SetText then box:SetText(url) end
	if box.HighlightText then box:HighlightText() end
end

function ns:ShowCopyLinks(title, links)
	local dialogs, show = rawget(_G, "StaticPopupDialogs"), rawget(_G, "StaticPopup_Show")
	if type(dialogs) ~= "table" or type(show) ~= "function" or type(links) ~= "table" or not links[1] then return nil end
	local key = PopupKey("COPY_LINK")
	local function Pick(dialog, index)
		local data = dialog and dialog.data
		local link = data and data.links and data.links[index]
		local box = dialog and (dialog.editBox or dialog.EditBox)
		if link and box then ns.CopyBoxLock(box, link[2]) end
		return true   -- reste ouverte : on passe d'un lien à l'autre
	end
	dialogs[key] = {
		text = ns.L.LINK_COPY_TEXT, hasEditBox = 1, editBoxWidth = 360,
		button1 = links[1][1], button2 = links[2] and links[2][1] or nil, button3 = ns.L.OPT_CLOSE,
		OnShow = function(dialog) Pick(dialog, 1) end,
		OnAccept = function(dialog) return Pick(dialog, 1) end,
		OnCancel = function(dialog, _, reason) if reason == "clicked" then return Pick(dialog, 2) end end,
		OnAlt = function() end,
		EditBoxOnTextChanged = function(box) if box.copyURL and box:GetText() ~= box.copyURL then ns.CopyBoxLock(box, box.copyURL) end end,
		EditBoxOnEscapePressed = function(box) local parent = box:GetParent(); if parent and parent.Hide then parent:Hide() end end,
		timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
	}
	local dialog = Try(show, key, tostring(title or ""), nil, { links = links })
	if type(dialog) == "table" then
		dialog.data = dialog.data or { links = links }
		Pick(dialog, 1)
	end
	return dialog
end

ns:DetectCapabilities()

if ns.Mark then ns.Mark("Compat") end
end)(SOCLE_ADDON, SOCLE_NS)
