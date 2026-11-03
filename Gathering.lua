-- Gathering.lua -- carnet : récolte selon le métier (v1.25.0)
--
-- Demande joueur : « ramasser tel compo en fonction du métier », et que ça
-- compte dans la complétion d'une zone. Pour chaque métier de récolte connu
-- (Herboristerie, Minage, Dépeçage) :
--   * objectif « Récolte à ton niveau » : ressources de ta tranche de
--     compétence (requise <= compétence < grise) déjà récoltées au moins
--     une fois, sur le total de la tranche. On compte des ressources
--     DIFFÉRENTES, pas des quantités ;
--   * part « Récolte » de la complétion de zone : ressources de ta tranche
--     déjà récoltées DANS cette zone.
-- Données : GatheringData.lua (itemID, métier, requise, grise, noms de repli).
-- Les zones ne sont pas dans la table : on retient en jouant où chaque
-- ressource a été récoltée (par personnage, dans les données du carnet).
-- Pas de module à part : même interrupteur que le carnet (Compagnon de route).
local ADDON, ns = ...
local L = ns.L

local HINT_NAMES = 6    -- noms listés au survol, au-delà « … et N autres »

-- ---------------------------------------------------------------------------
-- Chaînes
-- ---------------------------------------------------------------------------
local FR = {
	GATHER_PROF_herbalism   = "Herboristerie",
	GATHER_PROF_mining      = "Minage",
	GATHER_PROF_skinning    = "Dépeçage",
	GATHER_GOAL             = "Récolte à ton niveau : %s",
	GATHER_UNIT             = "ressources",
	GATHER_HINT_TODO        = "À récolter à ta compétence :",
	GATHER_HINT_ITEM        = "%s (%d)",
	GATHER_HINT_SKILL       = "%s : %d",
	GATHER_HINT_herbalism   = "Les nœuds apparaissent sur la minicarte avec Découverte d'herbes.",
	GATHER_HINT_mining      = "Les gisements apparaissent sur la minicarte avec Découverte de gisements.",
	GATHER_HINT_skinning    = "Dépèce les bêtes que tu tues : plus elles sont fortes, meilleur est le cuir.",
	JRN_PART_gathering      = "Récolte",
	GATHER_PART_TODO        = "Ressources de ta compétence pas encore récoltées dans %s :",
	GATHER_PART_DONE        = "Toutes les ressources de ta compétence ont été récoltées dans %s.",
}
local EN = {
	GATHER_PROF_herbalism   = "Herbalism",
	GATHER_PROF_mining      = "Mining",
	GATHER_PROF_skinning    = "Skinning",
	GATHER_GOAL             = "Gathering at your skill: %s",
	GATHER_UNIT             = "resources",
	GATHER_HINT_TODO        = "To gather at your skill:",
	GATHER_HINT_ITEM        = "%s (%d)",
	GATHER_HINT_SKILL       = "%s: %d",
	GATHER_HINT_herbalism   = "Herb nodes show on the minimap with Find Herbs.",
	GATHER_HINT_mining      = "Mineral veins show on the minimap with Find Minerals.",
	GATHER_HINT_skinning    = "Skin the beasts you kill: the stronger they are, the better the leather.",
	JRN_PART_gathering      = "Gathering",
	GATHER_PART_TODO        = "Resources of your skill not gathered yet in %s:",
	GATHER_PART_DONE        = "Every resource of your skill has been gathered in %s.",
}
ns.RegisterStrings(FR, EN)
ns.GATHERING_STRINGS = { fr = FR, en = EN }

-- ---------------------------------------------------------------------------
-- Accès robustes
-- ---------------------------------------------------------------------------
local function Call(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e = pcall(fn, ...)
	if ok then return a, b, c, d, e end
	return nil
end

local function ModuleOn()
	local db = ns:DB()
	-- même interrupteur que le carnet et le compagnon (v1.25.0)
	return db.enabled ~= false and db.companionEnabled ~= false
end

local function Items() return ns.GATHERING_ITEMS or {} end
local function Professions() return ns.GATHERING_PROFESSIONS or {} end

local function Lower(text)
	if ns.AsciiLower then return ns.AsciiLower(text) end
	return type(text) == "string" and text:lower() or text
end

local function IsFrench()
	local locale = Call("GetLocale")
	return type(locale) ~= "string" or locale:sub(1, 2) == "fr"
end

-- Nom affiché : celui du client s'il connaît l'objet, sinon le repli
function ns:GatheringItemName(itemID)
	local entry = Items()[itemID]
	local itemAPI = rawget(_G, "C_Item")
	local fn = (type(itemAPI) == "table" and itemAPI.GetItemInfo) or rawget(_G, "GetItemInfo")
	if type(fn) == "function" then
		local ok, name = pcall(fn, itemID)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	if not entry then return tostring(itemID) end
	return (IsFrench() and entry.fr or entry.en) or entry.en or entry.fr or tostring(itemID)
end

-- ---------------------------------------------------------------------------
-- Données par personnage : data[itemID] = { count = n, zones = { [zoneID] = n } }
-- ---------------------------------------------------------------------------
function ns:GatheringData()
	local journal = self:JournalData()
	if type(journal.gathering) ~= "table" then journal.gathering = {} end
	return journal.gathering
end

-- ---------------------------------------------------------------------------
-- Métiers : { herbalism = rang, mining = rang, skinning = rang } (connus seuls)
-- ---------------------------------------------------------------------------
-- La fenêtre de compétences ne liste pas les lignes d'une catégorie repliée :
-- le dernier rang lu est gardé (par personnage) et sert dans ce seul cas.
local BY_NAME
local function ProfessionByName()
	if BY_NAME then return BY_NAME end
	BY_NAME = {}
	for prof, def in pairs(Professions()) do
		for _, name in ipairs(def.names or {}) do BY_NAME[Lower(name)] = prof end
	end
	return BY_NAME
end

function ns:GatheringProfessions()
	local found = {}
	local count, info = rawget(_G, "GetNumSkillLines"), rawget(_G, "GetSkillLineInfo")
	if type(count) ~= "function" or type(info) ~= "function" then return found end
	local ok, total = pcall(count)
	if not ok or type(total) ~= "number" then return found end
	local byName, collapsed = ProfessionByName(), false
	for index = 1, total do
		local okLine, name, isHeader, isExpanded, rank = pcall(info, index)
		if okLine and type(name) == "string" then
			if isHeader == true or isHeader == 1 then
				if isExpanded == false or isExpanded == 0 then collapsed = true end
			else
				local prof = byName[Lower(name)]
				if prof then found[prof] = tonumber(rank) or 0 end
			end
		end
	end
	local journal = self:JournalData()
	if collapsed and type(journal.gatheringSkills) == "table" then
		for prof, rank in pairs(journal.gatheringSkills) do
			if found[prof] == nil and Professions()[prof] then found[prof] = tonumber(rank) or 0 end
		end
	end
	journal.gatheringSkills = {}
	for prof, rank in pairs(found) do journal.gatheringSkills[prof] = rank end
	return found
end

-- ---------------------------------------------------------------------------
-- Tranche de compétence
-- ---------------------------------------------------------------------------
local function ByReq(a, b)
	if a.req ~= b.req then return a.req < b.req end
	return a.name < b.name
end

-- Ressources d'un métier récoltables avec des points : requise <= rang < grise.
-- Renvoie la liste triée { itemID, req, gray, name } et la borne basse (la
-- plus haute compétence requise atteinte : l'identifiant de l'objectif ne
-- change que lorsqu'une nouvelle ressource entre dans ta tranche).
function ns:GatheringBand(prof, rank)
	rank = tonumber(rank)
	local band, low = {}, nil
	if not prof or not rank then return band, nil end
	for itemID, entry in pairs(Items()) do
		if entry.prof == prof and entry.req <= rank then
			if not low or entry.req > low then low = entry.req end
			if rank < entry.gray then
				band[#band + 1] = { itemID = itemID, req = entry.req, gray = entry.gray, name = self:GatheringItemName(itemID) }
			end
		end
	end
	table.sort(band, ByReq)
	return band, low
end

local function NameLines(lines, entries)
	for index, entry in ipairs(entries) do
		if index > HINT_NAMES then
			lines[#lines + 1] = ns:F("JRN_HINT_MORE", #entries - HINT_NAMES)
			break
		end
		lines[#lines + 1] = "  · " .. ns:F("GATHER_HINT_ITEM", entry.name, entry.req)
	end
	return lines
end

-- ---------------------------------------------------------------------------
-- Récolte : messages de butin du joueur
-- ---------------------------------------------------------------------------
-- Seules les formes « butin » comptent : « Vous recevez l'objet » (achat,
-- récompense de quête, courrier) n'est pas une récolte.
local LOOT_GLOBALS = { "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF" }
local LOOT_FALLBACK = {
	"You receive loot: %sx%d.", "You receive loot: %s.",
	"Vous recevez le butin : %sx%d.", "Vous recevez le butin : %s.",
}

local function FormatToPattern(format)
	local pattern = format:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
	pattern = pattern:gsub("%%%d%%%$s", "\1"):gsub("%%%d%%%$d", "\2")
	pattern = pattern:gsub("%%s", "\1"):gsub("%%d", "\2")
	pattern = pattern:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
	return "^" .. pattern .. "$"
end

local function LootPatterns()
	local patterns = {}
	for _, name in ipairs(LOOT_GLOBALS) do
		local format = rawget(_G, name)
		if type(format) == "string" and format ~= "" then patterns[#patterns + 1] = FormatToPattern(format) end
	end
	-- le repli toujours en plus : la forme française / anglaise reste reconnue
	for _, format in ipairs(LOOT_FALLBACK) do patterns[#patterns + 1] = FormatToPattern(format) end
	return patterns
end

-- itemID, quantité si le message est un butin du joueur, sinon nil
function ns:GatheringParseLoot(message)
	if type(message) ~= "string" then return nil end
	for _, pattern in ipairs(LootPatterns()) do
		local item, count = message:match(pattern)
		if item then
			local itemID = tonumber(item:match("|Hitem:(%d+)") or item:match("item:(%d+)"))
			if itemID then return itemID, tonumber(count) or 1 end
		end
	end
	return nil
end

-- Compte une récolte. zoneID nil (instance, carte inconnue) : le total suit,
-- pas la zone. Renvoie true si c'est la première fois pour cette ressource.
function ns:GatheringRecord(itemID, count, zoneID)
	local entry = Items()[itemID]
	if not entry then return nil end
	count = tonumber(count) or 1
	local data = self:GatheringData()
	local record = data[itemID]
	local first = record == nil
	if type(record) ~= "table" then record = { count = 0, zones = {} }; data[itemID] = record end
	if type(record.zones) ~= "table" then record.zones = {} end
	record.count = (tonumber(record.count) or 0) + count
	if zoneID then record.zones[zoneID] = (tonumber(record.zones[zoneID]) or 0) + count end
	return first
end

-- Message de butin -> compté si : module allumé, butin du joueur, ressource de
-- la table, et métier correspondant connu (des restes de cuir tombés d'un
-- humanoïde ne sont pas une récolte de dépeceur).
function ns:GatheringLoot(message)
	if not ModuleOn() then return nil end
	local itemID, count = self:GatheringParseLoot(message)
	local entry = itemID and Items()[itemID]
	if not entry then return nil end
	if self:GatheringProfessions()[entry.prof] == nil then return nil end
	local zoneID = self.JournalZone and self:JournalZone() or nil
	self:GatheringRecord(itemID, count, zoneID)
	pcall(self.RefreshJournalTracker, self)
	if self.journalFrame and self.journalFrame:IsShown() and self.journalFrame.kind == "goals" and self.RefreshJournal then
		pcall(self.RefreshJournal, self)
	end
	return itemID
end

-- ---------------------------------------------------------------------------
-- Objectifs « Récolte à ton niveau »
-- ---------------------------------------------------------------------------
local function GatheringGoals(self, list)
	if not ModuleOn() then return end
	local professions, data = self:GatheringProfessions(), self:GatheringData()
	for _, prof in ipairs(ns.GATHERING_PROFESSION_ORDER or {}) do
		local rank = professions[prof]
		if rank then
			local band, low = self:GatheringBand(prof, rank)
			local have, missing = 0, {}
			for _, entry in ipairs(band) do
				if data[entry.itemID] then have = have + 1 else missing[#missing + 1] = entry end
			end
			local profName = L["GATHER_PROF_" .. prof]
			local goal = ns.JournalGoal and ns.JournalGoal("gather:" .. prof .. ":" .. tostring(low or 0),
				self:F("GATHER_GOAL", profName), have, #band, nil, "gathering")
			if goal then
				goal.short, goal.unit, goal.prof = profName, L.GATHER_UNIT, prof
				goal.hint = NameLines({ self:F("GATHER_HINT_SKILL", profName, rank), L.GATHER_HINT_TODO }, missing)
				goal.hint[#goal.hint + 1] = L["GATHER_HINT_" .. prof]
				list[#list + 1] = goal
			end
		end
	end
end
ns.GatheringGoals = GatheringGoals
if ns.RegisterGoalSource then ns.RegisterGoalSource(GatheringGoals) end

-- ---------------------------------------------------------------------------
-- Part « Récolte » de la complétion de zone
-- ---------------------------------------------------------------------------
-- Toutes tes tranches réunies (herboriste et mineur : herbes + minerais).
-- nil sans métier de récolte (ou module coupé) : la part ne s'applique pas.
function ns:GatheringZonePart(zoneID)
	if not ModuleOn() or not zoneID then return nil end
	local professions, data = self:GatheringProfessions(), self:GatheringData()
	local band, profs = {}, {}
	for _, prof in ipairs(ns.GATHERING_PROFESSION_ORDER or {}) do
		if professions[prof] then
			profs[#profs + 1] = prof
			for _, entry in ipairs((self:GatheringBand(prof, professions[prof]))) do band[#band + 1] = entry end
		end
	end
	if #band == 0 then return nil end
	table.sort(band, ByReq)
	local have, missing = 0, {}
	for _, entry in ipairs(band) do
		local record = data[entry.itemID]
		if record and type(record.zones) == "table" and (tonumber(record.zones[zoneID]) or 0) > 0 then
			have = have + 1
		else
			missing[#missing + 1] = entry
		end
	end
	local zoneName
	if self.MapInfo then
		local info = self:MapInfo(zoneID)
		zoneName = info and info.name
	end
	zoneName = tostring(zoneName or zoneID)
	local hint
	if #missing == 0 then
		hint = { self:F("GATHER_PART_DONE", zoneName) }
	else
		hint = NameLines({ self:F("GATHER_PART_TODO", zoneName) }, missing)
		for _, prof in ipairs(profs) do hint[#hint + 1] = L["GATHER_HINT_" .. prof] end
	end
	return { have = have, need = #band, hint = hint }
end

if ns.RegisterZonePart then
	ns.RegisterZonePart({ id = "gathering", label = "JRN_PART_gathering",
		Compute = function(self, zoneID) return self:GatheringZonePart(zoneID) end })
end

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
local HANDLERS = {
	CHAT_MSG_LOOT        = function(message) ns:GatheringLoot(message) end,
	-- un point de compétence gagné peut faire entrer une ressource dans ta tranche
	SKILL_LINES_CHANGED  = function()
		if ModuleOn() and ns.RefreshJournalTracker then ns:RefreshJournalTracker() end
	end,
}

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("gathering:" .. tostring(event), err) end
end)
ns.gatheringEventFrame = eventFrame

if ns.Mark then ns.Mark("Gathering") end
