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
--     PRÉSENTES dans la zone (ZoneGathering_<client>.lua, herbes et minerais tirés de
--     la base de Questie) déjà récoltées DANS cette zone. Zone absente de la
--     table, ou dépeçage (Questie n'a pas le type des bêtes) : toute la
--     tranche, comme avant.
-- Données : GatheringData.lua (itemID, métier, requise, grise, noms de repli),
-- ZoneGathering_<client>.lua (ns.ZONE_GATHERING[zoneID][itemID] = true, celle
-- de ton client seulement). On retient en
-- jouant où chaque ressource a été récoltée (par personnage, dans le carnet).
-- Pas de module à part : même interrupteur que le carnet (Compagnon de route).
local ADDON, ns = ...
if ns.blocked then return end
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
	GATHER_PROFS            = "Tes métiers : %s",
	GATHER_PROFS_NONE       = "Aucun métier repéré (fenêtre de compétences).",
	GATHER_PROF_RANK        = "%s %d",
	GATHER_ONLY_GATHER      = "Seuls l'herboristerie, le minage et le dépeçage se suivent zone par zone.",
	GATHER_REPORT_API       = "Métiers — API : %s (lecture : %s) %s",
	GATHER_REPORT_PARTIAL   = "· catégorie repliée dans la fenêtre de compétences",
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
	GATHER_PROFS            = "Your professions: %s",
	GATHER_PROFS_NONE       = "No profession found (skills window).",
	GATHER_PROF_RANK        = "%s %d",
	GATHER_ONLY_GATHER      = "Only herbalism, mining and skinning are tracked zone by zone.",
	GATHER_REPORT_API       = "Professions — API: %s (read: %s) %s",
	GATHER_REPORT_PARTIAL   = "· collapsed category in the skills window",
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
	local name = ns.ItemInfo(itemID)
	if type(name) == "string" and name ~= "" then return name end
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
-- Lecture des métiers (1.5.2) : deux API selon le client
-- ---------------------------------------------------------------------------
-- * GetProfessions / GetProfessionInfo (moteur récent, dont WoW Forever) :
--   jusqu'à cinq métiers (deux principaux, archéologie, pêche, cuisine ; le
--   secourisme là où il existe), avec leur ligne de compétence ;
-- * GetNumSkillLines / GetSkillLineInfo (fenêtre de compétences historique) :
--   une catégorie repliée ne liste pas ses lignes.
-- Les deux sont lues quand elles existent (l'une peut manquer un métier).
-- Rend { { key, name, rank, order } } (métiers connus seuls), ok (une API au
-- moins a répondu) et partial (catégorie repliée : liste peut-être incomplète).
local BY_NAME, BY_SKILL
local function Tables()
	if BY_NAME then return BY_NAME, BY_SKILL end
	BY_NAME, BY_SKILL = {}, {}
	for order, def in ipairs(ns.PROFESSION_LIST or {}) do
		local entry = { key = def.key, order = order }
		for _, name in ipairs(def.names or {}) do BY_NAME[Lower(name)] = entry end
		if def.skill then BY_SKILL[def.skill] = entry end
	end
	return BY_NAME, BY_SKILL
end

local function Plain(value)
	if ns.Plain then return ns.Plain(value) end
	return value
end

function ns:ReadProfessions()
	local byName, bySkill = Tables()
	local found, seen, ok, partial = {}, {}, false, false
	local function Add(def, name, rank)
		if not def or seen[def.key] then return end
		seen[def.key] = true
		found[#found + 1] = { key = def.key, name = name, rank = tonumber(rank) or 0, order = def.order }
	end
	-- moteur récent
	local list, info = rawget(_G, "GetProfessions"), rawget(_G, "GetProfessionInfo")
	if type(list) == "function" and type(info) == "function" then
		local packed = { pcall(list) }
		if packed[1] then
			ok = true
			for index = 2, 7 do
				local slot = Plain(packed[index])
				if type(slot) == "number" then
					local okInfo, name, _, rank, _, _, _, skillLine = pcall(info, slot)
					name, rank, skillLine = Plain(name), Plain(rank), Plain(skillLine)
					if okInfo and type(name) == "string" then
						Add(bySkill[tonumber(skillLine) or -1] or byName[Lower(name)], name, rank)
					else
						partial = true   -- un métier illisible : ne pas oublier les autres
					end
				end
			end
		end
	end
	-- fenêtre de compétences historique
	local count, line = rawget(_G, "GetNumSkillLines"), rawget(_G, "GetSkillLineInfo")
	if type(count) == "function" and type(line) == "function" then
		local okCount, total = pcall(count)
		if okCount and type(total) == "number" then
			ok = true
			for index = 1, total do
				local okLine, name, isHeader, isExpanded, rank = pcall(line, index)
				if okLine and type(name) == "string" then
					if isHeader == true or isHeader == 1 then
						if not (isExpanded == true or isExpanded == 1) then partial = true end
					else
						Add(byName[Lower(name)], name, rank)
					end
				end
			end
		end
	end
	table.sort(found, function(a, b) return a.order < b.order end)
	return found, ok, partial
end

-- Tous tes métiers, dans l'ordre de ns.PROFESSION_LIST : { { key, name, rank } }.
-- Lecture vide ou incomplète (API absente, catégorie repliée) : la
-- dernière liste complète lue sert (par personnage).
function ns:PlayerProfessions()
	local found, ok, partial = self:ReadProfessions()
	local journal = self:JournalData()
	local cached = type(journal.professions) == "table" and journal.professions or nil
	if ok and not partial then
		journal.professions = found
	elseif cached then
		local have = {}
		for _, entry in ipairs(found) do have[entry.key] = true end
		for _, entry in ipairs(cached) do
			if type(entry) == "table" and entry.key and not have[entry.key] then found[#found + 1] = entry end
		end
		table.sort(found, function(a, b) return (a.order or 99) < (b.order or 99) end)
	end
	return found
end

-- Métiers de récolte : { herbalism = rang, mining = rang, skinning = rang } (connus seuls)
function ns:GatheringProfessions()
	local out = {}
	for _, entry in ipairs(self:PlayerProfessions()) do
		if Professions()[entry.key] then out[entry.key] = tonumber(entry.rank) or 0 end
	end
	return out
end

-- /qc metiers : ce que le client dit de tes métiers (pour un rapport de bogue)
function ns:ProfessionsReport()
	local found, ok, partial = self:ReadProfessions()
	local api = {}
	if type(rawget(_G, "GetProfessions")) == "function" then api[#api + 1] = "GetProfessions" end
	if type(rawget(_G, "GetNumSkillLines")) == "function" then api[#api + 1] = "GetSkillLineInfo" end
	self:Print(self:F("GATHER_REPORT_API", #api > 0 and table.concat(api, ", ") or "-",
		ok and "ok" or "-", partial and L.GATHER_REPORT_PARTIAL or ""))
	local text = self:PlayerProfessionsText()
	self:Print(text and self:F("GATHER_PROFS", text) or L.GATHER_PROFS_NONE)
	return found
end
if ns.EXTRA_COMMANDS then
	ns.EXTRA_COMMANDS["metiers"] = function(self) self:ProfessionsReport() end
	ns.EXTRA_COMMANDS["métiers"] = ns.EXTRA_COMMANDS["metiers"]
	ns.EXTRA_COMMANDS["professions"] = ns.EXTRA_COMMANDS["metiers"]
end

-- « Minage 215 · Forge 180 · Cuisine 75 », nil sans métier
function ns:PlayerProfessionsText()
	local parts = {}
	for _, entry in ipairs(self:PlayerProfessions()) do
		parts[#parts + 1] = self:F("GATHER_PROF_RANK", tostring(entry.name), tonumber(entry.rank) or 0)
	end
	if #parts == 0 then return nil end
	return table.concat(parts, "  ·  ")
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
	-- récolter nourrit la curiosité du compagnon, à chaque fois
	if self.CompanionAdd and ns.COMPANION_CURIOSITY then self:CompanionAdd("curiosity", ns.COMPANION_CURIOSITY.gather) end
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
	if self.journalFrame and self.journalFrame:IsShown() and self.RefreshJournal then
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
-- Ressources présentes dans une zone (table livrée), nil si la zone n'y est pas
function ns:GatheringZoneSet(zoneID)
	local all = rawget(ns, "ZONE_GATHERING")
	local set = type(all) == "table" and zoneID and all[zoneID]
	if type(set) ~= "table" then return nil end
	return set
end

-- Le dépeçage ne dépend pas des nœuds de la zone : jamais filtré
local ZONE_FILTERED = { herbalism = true, mining = true }

-- Tes tranches réunies (herboriste et mineur : herbes + minerais), réduites
-- à ce que la zone contient quand elle est dans la table. Renvoie la liste
-- triée et les métiers concernés.
function ns:GatheringZoneBand(zoneID)
	local professions = self:GatheringProfessions()
	local set = self:GatheringZoneSet(zoneID)
	local band, profs = {}, {}
	for _, prof in ipairs(ns.GATHERING_PROFESSION_ORDER or {}) do
		if professions[prof] then
			local kept = 0
			for _, entry in ipairs((self:GatheringBand(prof, professions[prof]))) do
				if not (set and ZONE_FILTERED[prof]) or set[entry.itemID] then
					band[#band + 1] = entry
					kept = kept + 1
				end
			end
			if kept > 0 then profs[#profs + 1] = prof end
		end
	end
	table.sort(band, ByReq)
	return band, profs
end

-- Ce que la zone t'offre à récolter (1.5.1) : herbes et minerais d'une zone
-- connue que ta compétence permet (requise <= rang), même GRIS — un mineur
-- confirmé finit aussi les zones de départ ; dépeçage et zones hors table :
-- ta tranche seule (sinon le monde entier). grayed = true : plus de points.
-- withLocked (1.5.5) : aussi ce qui pousse ici mais demande plus de
-- compétence (locked = true) — montré dans la liste, jamais compté.
function ns:GatheringZoneList(zoneID, withLocked)
	local professions = self:GatheringProfessions()
	local set = self:GatheringZoneSet(zoneID)
	local list, profs = {}, {}
	for _, prof in ipairs(ns.GATHERING_PROFESSION_ORDER or {}) do
		local rank = tonumber(professions[prof])
		if rank then
			local kept = 0
			if set and ZONE_FILTERED[prof] then
				for itemID, entry in pairs(Items()) do
					if entry.prof == prof and set[itemID] and (entry.req <= rank or withLocked) then
						local locked = entry.req > rank
						list[#list + 1] = { itemID = itemID, req = entry.req, gray = entry.gray,
							grayed = not locked and rank >= entry.gray, locked = locked or nil,
							name = self:GatheringItemName(itemID) }
						if not locked then kept = kept + 1 end
					end
				end
			else
				for _, entry in ipairs((self:GatheringBand(prof, rank))) do
					list[#list + 1] = entry
					kept = kept + 1
				end
			end
			if kept > 0 then profs[#profs + 1] = prof end
		end
	end
	table.sort(list, ByReq)
	return list, profs
end

-- nil sans métier de récolte (ou module coupé), ou si rien de récoltable
-- ne pousse dans la zone : la part ne s'applique pas.
function ns:GatheringZonePart(zoneID)
	if not ModuleOn() or not zoneID then return nil end
	local data = self:GatheringData()
	local band, profs = self:GatheringZoneList(zoneID)
	if #band == 0 then return nil end
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
