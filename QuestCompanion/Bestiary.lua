-- Bestiary.lua -- bestiaire de zone et nommés du « Carnet de voyage » (v1.25.0)
--
-- La complétion d'une zone, côté créatures : les espèces de la zone livrées
-- avec l'addon (ZoneCreatures_Forever.lua, tirées de la base de Questie, voir tools/gen_zone_data.py) UNION celles apprises en jouant, par personnage.
--   * Zone préremplie : toutes ses espèces comptent dès l'arrivée, quel que
--              soit leur niveau (100 % strict), sauf celles amicales envers
--              ta faction (champ f de la table).
--   * Zone absente des tables (carte inconnue de ton client) : tout s'apprend en
--              jouant, comme avant.
--   * Vu     : une créature hostile ou neutre (pas un joueur, pas un familier,
--              pas une bestiole) ciblée, survolée ou dont la plaque de nom
--              apparaît. On retient son ESPÈCE (numéro de PNJ tiré du GUID),
--              son nom, son type, sa famille, sa classification et la zone.
--   * Abattu : même règle que les rares du carnet (Journal.lua) — engagée par
--              toi, ton familier ou ton groupe (coup porté, raté, ou coup
--              reçu), puis morte (UNIT_DIED / PARTY_KILL). Un mob tué par un
--              inconnu ne compte pas. Une espèce de la table compte même si
--              elle n'a jamais été « vue » : le journal de combat suffit.
--   * Nommé  : élite, rare, rare élite ou boss (rang Questie 1, 4, 2, 3).
-- On compte des ESPÈCES différentes, jamais un nombre de victimes : pas de
-- « tue 5 sangliers », juste « as-tu déjà abattu un sanglier d'ici ? ».
--
-- Données : ns:JournalData().bestiary[zoneID][npcID] =
--   { name, type, family, class, level, seen = true, killed = n }
-- Jamais en instance (JournalZone renvoie nil) : c'est un bestiaire de zone.
-- Vit sous le module Compagnon (db.companionEnabled), comme Journal.lua :
-- module coupé, plus rien ne s'apprend (ce qui est appris reste lisible).
--
-- Points d'extension utilisés (JournalTracker.lua) :
--   ns.RegisterZonePart : parts « bestiary » et « named » ;
--   ns.RegisterGoalSource : « Bestiaire de <zone> », « Nommés de <zone> ».
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

local HINT_NAMES = 6          -- noms listés au survol, au-delà « … et N autres »
local SEEN_MEMORY = 900       -- un mob vu et jamais engagé est oublié après 15 min
local ENGAGED_MEMORY = 1800   -- un mob engagé qui ne meurt pas (fuite, évasion) : 30 min
local PRUNE_EVERY = 60

-- ---------------------------------------------------------------------------
-- Chaînes
-- ---------------------------------------------------------------------------
local FR = {
	JRN_PART_bestiary   = "Bestiaire",
	JRN_PART_named      = "Nommés",
	BST_GOAL_BESTIARY   = "Bestiaire de %s",
	BST_GOAL_NAMED      = "Nommés de %s",
	BST_UNIT            = "espèces",
	BST_HINT_BESTIARY   = "Encore à abattre :",
	BST_HINT_NAMED      = "Nommés encore à abattre (élites, rares, boss) :",
	BST_HINT_NAME_TYPE  = "%s (%s)",
	BST_COUNT           = "Bestiaire : %d / %d espèces abattues",
	BST_COUNT_NAMED     = "Nommés : %d / %d abattus",
	BST_LEVEL           = "niv. %s",
	-- 2.11.0 (fiche 28) : ligne de /qc diag traduite
	BESTIARY_DIAG = "  bestiaire : %s, journal de combat %d, coups %d, PARTY_KILL %d, UNIT_DIED %d, victimes comptées %d (dont %d par l'XP)",
	BESTIARY_DIAG_CLOG = "journal de combat",
}
local EN = {
	JRN_PART_bestiary   = "Bestiary",
	JRN_PART_named      = "Named foes",
	BST_GOAL_BESTIARY   = "Bestiary of %s",
	BST_GOAL_NAMED      = "Named foes of %s",
	BST_UNIT            = "species",
	BST_HINT_BESTIARY   = "Still to defeat:",
	BST_HINT_NAMED      = "Named foes still to defeat (elites, rares, bosses):",
	BST_HINT_NAME_TYPE  = "%s (%s)",
	BST_COUNT           = "Bestiary: %d / %d species defeated",
	BST_COUNT_NAMED     = "Named foes: %d / %d defeated",
	BST_LEVEL           = "lvl %s",
	BESTIARY_DIAG = "  bestiary: %s, combat log %d, hits %d, PARTY_KILL %d, UNIT_DIED %d, kills counted %d (%d from XP)",
	BESTIARY_DIAG_CLOG = "combat log",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.BESTIARY_STRINGS = { fr = FR, en = EN } end

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
	-- même interrupteur que le compagnon et son carnet (v1.25.0)
	return db.enabled ~= false and db.companionEnabled ~= false
end

local NAMED = { elite = true, rare = true, rareelite = true, worldboss = true }
ns.BESTIARY_NAMED = NAMED

-- UnitCreatureType est traduit : les bestioles et mascottes, langue par langue
local CRITTERS = {
	["Critter"] = true, ["Non-combat Pet"] = true, ["Wild Pet"] = true,
	["Bestiole"] = true, ["Familier pacifique"] = true, ["Mascotte sauvage"] = true,
	["Kleintier"] = true, ["Haustier"] = true, ["Alimaña"] = true, ["Bicho"] = true,
	["Animale"] = true, ["Существо"] = true, ["동물"] = true, ["小动物"] = true, ["小動物"] = true,
}

-- Numéro de PNJ d'un GUID de créature (« Creature-0-srv-inst-zone-npcID-spawn ») ;
-- tout autre format (joueur, familier « Pet- », objet) : nil
local function NpcID(guid)
	guid = ns.Plain(guid)   -- valeur secrète (Forever) : on ne la lit pas
	if type(guid) ~= "string" then return nil end
	local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")
	if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
	id = tonumber(id)
	if not id or id <= 0 then return nil end
	return id
end
ns.BestiaryNpcID = NpcID

-- Hostile ou neutre envers toi : UnitReaction (1-3 hostile, 4 neutre), sinon
-- UnitCanAttack. Sans l'une ni l'autre : rien (on ne devine pas).
local function Attackable(unit)
	local reaction = tonumber(Call("UnitReaction", unit, "player"))
	if reaction then return reaction <= 4 end
	return Call("UnitCanAttack", "player", unit) == true
end

-- ---------------------------------------------------------------------------
-- Données (par personnage, dans le carnet)
-- ---------------------------------------------------------------------------
function ns:BestiaryData()
	local data = self:JournalData()
	if type(data.bestiary) ~= "table" then data.bestiary = {} end
	return data.bestiary
end

-- Espèces APPRISES d'une zone (table npcID -> espèce), nil si rien vu
function ns:BestiaryZone(zoneID)
	local zone = zoneID and self:BestiaryData()[zoneID]
	if type(zone) ~= "table" or next(zone) == nil then return nil end
	return zone
end

-- ---------------------------------------------------------------------------
-- Table livrée (ZoneCreatures_<client>.lua, seule celle de ton client se
-- charge) : ns.ZONE_CREATURES[zoneID][npcID] =
-- { lvl = { min, max }, rank, fr, en, f }. Lue à chaque appel (pas de copie
-- locale) : une zone absente reste 100 % dynamique.
-- ---------------------------------------------------------------------------
-- Rang Questie (cmangos) -> classification du client (UnitClassification)
local RANK_CLASS = { [1] = "elite", [2] = "rareelite", [3] = "worldboss", [4] = "rare" }
ns.BESTIARY_RANK_CLASS = RANK_CLASS

function ns:BestiaryStaticZone(zoneID)
	local all = rawget(ns, "ZONE_CREATURES")
	local zone = type(all) == "table" and zoneID and all[zoneID]
	if type(zone) ~= "table" then return nil end
	return zone
end

-- « A » (Alliance), « H » (Horde), nil si le client ne le dit pas
function ns:BestiaryFaction()
	local group = Call("UnitFactionGroup", "player")
	if group == "Alliance" then return "A" end
	if group == "Horde" then return "H" end
	return nil
end

-- Une espèce de la table compte pour toi : pas amicale envers ta faction
-- (faction inconnue : seules les espèces hostiles ou neutres envers les deux)
local function ForYou(entry, faction)
	local f = entry.f
	if f == nil then return true end
	return faction ~= nil and not tostring(f):find(faction, 1, true)
end

local function IsFrenchClient()
	return Call("GetLocale") == "frFR"
end

function ns:BestiaryStaticName(entry)
	if type(entry) ~= "table" then return nil end
	if IsFrenchClient() then return entry.fr or entry.en end
	return entry.en or entry.fr
end

-- « 5 » ou « 5-7 » (niveaux de la table), nil sans niveau
function ns:BestiaryLevelText(species)
	local lvl = type(species) == "table" and species.lvl
	if type(lvl) == "table" and tonumber(lvl[1]) then
		local lo, hi = tonumber(lvl[1]), tonumber(lvl[2]) or tonumber(lvl[1])
		return lo == hi and tostring(lo) or (lo .. "-" .. hi)
	end
	local level = type(species) == "table" and tonumber(species.level)
	return level and tostring(level) or nil
end

-- Toutes les espèces d'une zone : la table (filtrée par ta faction) UNION ce
-- que tu as appris. npcID -> { name, class, type, lvl, level, seen, killed,
-- static }. Une espèce apprise garde son nom du client et son type.
-- 2.11.1 : les deux règles (espèce de la table, fusion avec l'appris) sont
-- partagées par BestiarySpecies (toute la zone) et BestiarySpeciesOne (une
-- espèce, pour l'infobulle) : une seule façon de fusionner.
local function StaticSpecies(self, npcID, entry, faction)
	if type(entry) ~= "table" or not ForYou(entry, faction) then return nil end
	return { name = self:BestiaryStaticName(entry) or tostring(npcID),
		class = RANK_CLASS[tonumber(entry.rank) or 0], lvl = entry.lvl,
		seen = false, killed = 0, static = true }
end

local function MergeLearned(merged, learned, entry, npcID)
	merged = merged or {}
	merged.name = learned.name or merged.name or tostring(npcID)
	merged.type, merged.family, merged.level = learned.type, learned.family, learned.level
	merged.class = learned.class or merged.class
	if type(entry) == "table" then
		merged.lvl, merged.static = entry.lvl, true
		-- le rang de la table l'emporte sur « normal » (mob vu de loin)
		merged.class = RANK_CLASS[tonumber(entry.rank) or 0] or merged.class
	end
	merged.seen = learned.seen == true
	merged.killed = tonumber(learned.killed) or 0
	return merged
end

function ns:BestiarySpecies(zoneID)
	local list = {}
	if not zoneID then return list end
	local static = self:BestiaryStaticZone(zoneID)
	if static then
		local faction = self:BestiaryFaction()
		for npcID, entry in pairs(static) do
			list[npcID] = StaticSpecies(self, npcID, entry, faction)
		end
	end
	for npcID, learned in pairs(self:BestiaryZone(zoneID) or {}) do
		if type(learned) == "table" then
			list[npcID] = MergeLearned(list[npcID], learned, static and static[npcID], npcID)
		end
	end
	return list
end

-- 2.11.1 : BestiarySpecies(zoneID)[npcID] sans bâtir toute la zone (jusqu'à
-- 208 espèces) : l'infobulle d'unité, à chaque survol, n'en lit qu'une.
function ns:BestiarySpeciesOne(zoneID, npcID)
	if not (zoneID and npcID) then return nil end
	local static = self:BestiaryStaticZone(zoneID)
	local entry = static and static[npcID]
	local species
	if type(entry) == "table" then
		species = StaticSpecies(self, npcID, entry, self:BestiaryFaction())
	end
	local zone = self:BestiaryZone(zoneID)
	local learned = type(zone) == "table" and zone[npcID]
	if type(learned) == "table" then
		species = MergeLearned(species, learned, entry, npcID)
	end
	return species
end

-- ---------------------------------------------------------------------------
-- 2.14.0 (bêta 4) : le nom d'une créature, jamais son numéro quand un nom
-- existe. Une espèce vue sans nom (journal de combat, vignette de la
-- minicarte) gardait « 3632 » comme nom ; capturée, son numéro s'affichait
-- (choix d'allure, infobulle, fiche, plaque du compagnon). Dans l'ordre : le
-- nom de la fiche (`record`, sauf un numéro), celui du carnet (toutes zones),
-- celui de la table livrée (index pnj → zone bâti une fois, au premier nom
-- manquant), celui du client (C_TooltipInfo, s'il le connaît) ; le numéro en
-- dernier recours. Un nom trouvé est rendu à la fiche (`record.name`).
-- ---------------------------------------------------------------------------
local nameCache, staticIndex = {}, nil
function ns.CreatureNameGood(name, npcID)
	if type(name) ~= "string" then return false end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" or name == tostring(npcID) or name:match("^#?%d+$") then return false end
	return true
end
local Good = ns.CreatureNameGood

-- La zone de la table livrée où vit chaque pnj (bâti une fois, puis gardé)
local function StaticIndex()
	if staticIndex then return staticIndex end
	staticIndex = {}
	local all = rawget(ns, "ZONE_CREATURES")
	if type(all) == "table" and ns.ZoneEach then
		ns.ZoneEach(all, function(zoneID, zone)
			for npcID in pairs(type(zone) == "table" and zone or {}) do
				local npc = tonumber(npcID)
				if npc and not staticIndex[npc] then staticIndex[npc] = zoneID end
			end
		end)
	end
	return staticIndex
end
function ns.CreatureNameForget() nameCache, staticIndex = {}, nil end

local function StaticName(self, npc)
	local zoneID = StaticIndex()[npc]
	local zone = zoneID and ns.ZonePeek and ns.ZonePeek(rawget(ns, "ZONE_CREATURES"), zoneID)
	local entry = type(zone) == "table" and zone[npc]
	return type(entry) == "table" and self:BestiaryStaticName(entry) or nil
end

local function ClientName(npc)
	local tips = rawget(_G, "C_TooltipInfo")
	if type(tips) ~= "table" or type(tips.GetHyperlink) ~= "function" then return nil end
	local ok, data = pcall(tips.GetHyperlink, "unit:Creature-0-0-0-0-" .. tostring(npc) .. "-0")
	local line = ok and type(data) == "table" and type(data.lines) == "table" and data.lines[1]
	local text = type(line) == "table" and line.leftText or nil
	return Good(text, npc) and text or nil
end

function ns:CreatureName(npcID, record)
	local npc = tonumber(npcID)
	local own = type(record) == "table" and record.name or nil
	if Good(own, npc or npcID) then return own end
	if not npc then return tostring(npcID or "?") end
	local name = nameCache[npc]
	if not name then
		local book = self.BestiaryData and self:BestiaryData() or {}
		for _, zone in pairs(book) do
			local species = type(zone) == "table" and (zone[npc] or zone[tostring(npc)])
			if type(species) == "table" and Good(species.name, npc) then name = species.name; break end
		end
		name = name or StaticName(self, npc) or ClientName(npc)
		if name then nameCache[npc] = name end
	end
	if not name then return tostring(npc) end
	if type(record) == "table" then record.name = name end
	return name
end

function ns:BestiaryIsNamed(species)
	return type(species) == "table" and NAMED[species.class or ""] == true
end

-- { seen, killed, namedSeen, namedKilled } (zéros si rien vu) ; « seen » =
-- espèces à abattre dans la zone (table + apprises), vues ou non
function ns:BestiaryCounts(zoneID)
	local counts = { seen = 0, killed = 0, namedSeen = 0, namedKilled = 0 }
	for _, species in pairs(self:BestiarySpecies(zoneID)) do
		local killed = (tonumber(species.killed) or 0) > 0
		counts.seen = counts.seen + 1
		if killed then counts.killed = counts.killed + 1 end
		if self:BestiaryIsNamed(species) then
			counts.namedSeen = counts.namedSeen + 1
			if killed then counts.namedKilled = counts.namedKilled + 1 end
		end
	end
	return counts
end

-- Lignes de compte pour la fiche de zone du carnet (vide si rien vu)
function ns:BestiaryCounterLines(zoneID)
	local counts, lines = self:BestiaryCounts(zoneID), {}
	if counts.seen == 0 then return lines end
	lines[1] = self:F("BST_COUNT", counts.killed, counts.seen)
	if counts.namedSeen > 0 then lines[2] = self:F("BST_COUNT_NAMED", counts.namedKilled, counts.namedSeen) end
	return lines
end

-- Survol : les espèces vues et pas encore abattues, triées, coupées à HINT_NAMES
local function MissingHint(self, zoneID, namedOnly, title)
	local names = {}
	for _, species in pairs(self:BestiarySpecies(zoneID)) do
		if (tonumber(species.killed) or 0) == 0 and (not namedOnly or self:BestiaryIsNamed(species)) then
			local name = tostring(species.name or "?")
			local level = species.lvl and self:BestiaryLevelText(species)
			if type(species.type) == "string" and species.type ~= "" then
				name = self:F("BST_HINT_NAME_TYPE", name, species.type)
			elseif level then
				name = self:F("BST_HINT_NAME_TYPE", name, self:F("BST_LEVEL", level))
			end
			names[#names + 1] = name
		end
	end
	if #names == 0 then return {} end
	table.sort(names)
	local lines = { title }
	for index, name in ipairs(names) do
		if index > HINT_NAMES then
			lines[#lines + 1] = self:F("JRN_HINT_MORE", #names - HINT_NAMES)
			break
		end
		lines[#lines + 1] = "  · " .. name
	end
	return lines
end

-- Part de complétion : nil si rien (ou aucun nommé) vu dans la zone
function ns:BestiaryPart(zoneID, namedOnly)
	local counts = self:BestiaryCounts(zoneID)
	local have, need = counts.killed, counts.seen
	if namedOnly then have, need = counts.namedKilled, counts.namedSeen end
	if need == 0 then return nil end
	return { have = have, need = need,
		hint = MissingHint(self, zoneID, namedOnly, namedOnly and L.BST_HINT_NAMED or L.BST_HINT_BESTIARY) }
end

-- ---------------------------------------------------------------------------
-- Vu
-- ---------------------------------------------------------------------------
-- Mémoire de session des mobs croisés (par GUID : une apparition), pour
-- relier le journal de combat à l'espèce et à la zone où on l'a vue
ns.bestiaryUnits = {}

local function Changed()
	-- jamais bloquant : un rafraîchissement raté ne doit pas casser le combat
	if ns.RefreshJournalTracker then pcall(ns.RefreshJournalTracker, ns) end
	local frame = ns.journalFrame
	if frame and frame.IsShown and frame:IsShown() and ns.RefreshJournal then
		pcall(ns.RefreshJournal, ns)
	end
end

local function Prune(now)
	if ns.bestiaryPrunedAt and now - ns.bestiaryPrunedAt < PRUNE_EVERY then return end
	ns.bestiaryPrunedAt = now
	ns.bestiaryRejected = {}
	for guid, entry in pairs(ns.bestiaryUnits) do
		local age = now - (entry.seen or now)
		if age > (entry.engaged and ENGAGED_MEMORY or SEEN_MEMORY) then ns.bestiaryUnits[guid] = nil end
	end
end

ns.BESTIARY_RESEE = 2

-- Une créature repérée (cible, survol, plaque de nom). Renvoie l'espèce
-- retenue, nil si la créature n'entre pas au bestiaire.
function ns:BestiarySeeUnit(unit)
	if type(unit) ~= "string" or not ModuleOn() then return nil end
	if Call("UnitExists", unit) == false then return nil end
	if Call("UnitIsPlayer", unit) then return nil end
	-- familier, gardien, monture d'un joueur : contrôlé par un joueur
	if Call("UnitPlayerControlled", unit) then return nil end
	local guid = ns.Plain(Call("UnitGUID", unit))
	local npcID = NpcID(guid)
	if not npcID then return nil end
	if Call("UnitIsDead", unit) then return nil end
	if not Attackable(unit) then return nil end
	local creatureType = Call("UnitCreatureType", unit)
	if type(creatureType) ~= "string" or creatureType == "" then creatureType = nil end
	if creatureType and CRITTERS[creatureType] then return nil end
	local zoneID = self:JournalZone()       -- nil en instance
	if not zoneID then return nil end

	local now = ns.Now()
	local entry = self.bestiaryUnits[guid] or {}
	-- même créature revue dans les BESTIARY_RESEE s (barre de vie qui
	-- reparaît en tournant la caméra, survol répété) : sa fiche est déjà à
	-- jour, on ne relit pas nom, famille, classe et niveau
	local book = self:BestiaryData()
	local known = entry.seen and entry.zoneID == zoneID and now >= entry.seen
		and now - entry.seen < ns.BESTIARY_RESEE and book[zoneID] and book[zoneID][npcID]
	if known then
		entry.seen = now
		return known
	end
	entry.zoneID, entry.npcID, entry.seen = zoneID, npcID, now
	self.bestiaryUnits[guid] = entry
	Prune(now)

	book[zoneID] = book[zoneID] or {}
	local species = book[zoneID][npcID]
	local new = species == nil
	species = species or { killed = 0 }
	species.seen = true
	local name = Call("UnitName", unit)
	if type(name) == "string" and name ~= "" then species.name = name end
	-- 2.14.0 (bêta 4) : sans nom lu, celui de la table livrée plutôt que le numéro
	if not ns.CreatureNameGood(species.name, npcID) then
		species.name = self:BestiaryStaticName((self:BestiaryStaticZone(zoneID) or {})[npcID]) or species.name or tostring(npcID)
	end
	species.type = creatureType or species.type
	-- 2.11.0 : son displayID, une fois au compte (portrait 2D, Companion.lua)
	if self.ModelLearnDisplay then pcall(self.ModelLearnDisplay, self, unit, npcID) end
	local family = Call("UnitCreatureFamily", unit)
	if type(family) == "string" and family ~= "" then species.family = family end
	local class = Call("UnitClassification", unit)
	if type(class) == "string" and class ~= "" then species.class = class end
	local level = tonumber(Call("UnitLevel", unit))
	if level and level > 0 then species.level = level end
	book[zoneID][npcID] = species
	if new then Changed() end
	return species
end

-- Une créature signalée sans unité à lire (vignette de la minicarte,
-- LiveRares.lua) : vue, avec son nom et son rang s'ils sont connus ; reliée
-- au journal de combat par son GUID, comme une cible. Renvoie l'espèce.
function ns:BestiarySeeGUID(guid, name, class)
	if not ModuleOn() then return nil end
	local npcID = NpcID(guid)
	if not npcID then return nil end
	local zoneID = self:JournalZone()       -- nil en instance
	if not zoneID then return nil end
	local now = ns.Now()
	local entry = self.bestiaryUnits[guid] or {}
	entry.zoneID, entry.npcID, entry.seen = zoneID, npcID, now
	self.bestiaryUnits[guid] = entry
	Prune(now)
	local book = self:BestiaryData()
	book[zoneID] = book[zoneID] or {}
	local species = book[zoneID][npcID]
	local new = species == nil
	species = species or { killed = 0 }
	species.seen = true
	if type(name) == "string" and name ~= "" then species.name = name end
	-- 2.14.0 (bêta 4) : sans nom lu, celui de la table livrée plutôt que le numéro
	if not ns.CreatureNameGood(species.name, npcID) then
		species.name = self:BestiaryStaticName((self:BestiaryStaticZone(zoneID) or {})[npcID]) or species.name or tostring(npcID)
	end
	-- un rang lu sur la créature elle-même (cible, survol) l'emporte
	if type(class) == "string" and (species.class == nil or species.class == "normal") then species.class = class end
	book[zoneID][npcID] = species
	if new then Changed() end
	return species
end

-- ---------------------------------------------------------------------------
-- Abattu
-- ---------------------------------------------------------------------------
-- Dans ton camp : toi, ton familier (affiliation MINE), ton groupe ou ton
-- raid (bits 0x1/0x2/0x4, lus sans la bibliothèque `bit`), comme Journal.lua
-- GUID du joueur : fixe pour la session, lu une fois (chaque coup du journal
-- de combat passe ici)
local playerGUID
local function FromGroup(guid, flags)
	if guid and not playerGUID then playerGUID = Call("UnitGUID", "player") end
	if guid and guid == playerGUID then return true end
	flags = tonumber(flags)
	return flags ~= nil and flags % 8 > 0
end

-- Un mob jamais repéré (ni cible, ni survol, ni plaque) mais engagé : retenu
-- si son espèce est dans la table de la zone où tu es. Les refus sont mis en
-- mémoire (par GUID, vidée avec Prune) : un seul calcul par mob, pas par coup.
ns.bestiaryRejected = {}
local function Adopt(self, guid)
	if not guid or self.bestiaryRejected[guid] or not ModuleOn() then return nil end
	local npcID = NpcID(guid)
	local zoneID = npcID and self:JournalZone()
	local static = zoneID and self:BestiaryStaticZone(zoneID)
	local now = ns.Now()
	Prune(now)
	if not (static and static[npcID]) then
		self.bestiaryRejected[guid] = true
		return nil
	end
	local entry = { zoneID = zoneID, npcID = npcID, seen = now }
	self.bestiaryUnits[guid] = entry
	return entry
end

-- Ce que le journal de combat et les messages d'XP apportent : lu par /qc diag
-- (« bestiaire : … »), pour comprendre un client qui ne compte pas les morts
ns.bestiaryStats = { events = 0, hits = 0, partyKills = 0, died = 0, kills = 0, xpKills = 0 }
-- Morts déjà comptées (par GUID, vidées avec le temps) : le journal de combat
-- et le message d'XP arrivent tous les deux pour la même mort
ns.bestiaryKilled = {}
local KILLED_MEMORY = 120

local function Kill(self, guid, entry, source)
	self.bestiaryUnits[guid] = nil
	if not ModuleOn() then return end
	-- la même mort par les deux sources : le message d'XP ne recompte pas ce
	-- que le journal a compté, ni le journal ce que l'XP a déjà compté
	local now = ns.Now()
	local prior = self.bestiaryKilled[guid]
	local recent = prior and now >= prior.at and now - prior.at < KILLED_MEMORY
	if recent and (source == "xp" or prior.source == "xp") then return end
	self.bestiaryKilled[guid] = { at = now, source = source or "log" }
	for other, mark in pairs(self.bestiaryKilled) do
		if now - mark.at >= KILLED_MEMORY or now < mark.at then self.bestiaryKilled[other] = nil end
	end
	local stats = ns.bestiaryStats
	stats.kills = stats.kills + 1
	if source == "xp" then stats.xpKills = stats.xpKills + 1 end
	-- une mort comptée, quelle que soit sa source : les brillantes et le carnet
	-- s'y accrochent (sur Forever, le journal de combat peut rester muet)
	local ok, err = pcall(self.BestiaryOnKill, self, guid, entry, source or "log")
	if not ok and self.RecordError then self:RecordError("bestiary:onkill", err) end
	local book = self:BestiaryData()
	local zone = book[entry.zoneID]
	local species = zone and zone[entry.npcID]
	if not species then
		-- espèce de la table abattue sans avoir été « vue » : on la crée ici
		local static = self:BestiaryStaticZone(entry.zoneID)
		local known = static and static[entry.npcID]
		if type(known) ~= "table" then return end
		species = { name = self:BestiaryStaticName(known) or tostring(entry.npcID), seen = true, killed = 0,
			class = RANK_CLASS[tonumber(known.rank) or 0] or "normal" }
		book[entry.zoneID] = zone or {}
		book[entry.zoneID][entry.npcID] = species
	end
	local before = tonumber(species.killed) or 0
	species.killed = before + 1
	if before == 0 then Changed() end
end

-- Point d'accroche : une victime vient d'être comptée (journal de combat ou
-- message d'XP). Le carnet tamponne le rare ; Shiny.lua l'enveloppe.
function ns:BestiaryOnKill(guid, entry, source)
	if self.JournalRareKilled then self:JournalRareKilled(guid) end
end

function ns:BestiaryCombat(subevent, sourceGUID, sourceFlags, destGUID, destFlags)
	if type(subevent) ~= "string" then return end
	local units = self.bestiaryUnits
	local target = destGUID and units[destGUID]
	if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
		ns.bestiaryStats.died = ns.bestiaryStats.died + 1
		if target then
			if target.engaged then Kill(self, destGUID, target) else units[destGUID] = nil end
		end
		return
	end
	local hit = subevent:find("_DAMAGE$") or subevent:find("_MISSED$")
	if not hit and subevent ~= "PARTY_KILL" then return end
	if subevent == "PARTY_KILL" then ns.bestiaryStats.partyKills = ns.bestiaryStats.partyKills + 1 end
	if not target and destGUID and FromGroup(sourceGUID, sourceFlags) then
		target = Adopt(self, destGUID)
	end
	if target and FromGroup(sourceGUID, sourceFlags) then
		if subevent == "PARTY_KILL" then
			Kill(self, destGUID, target)
		elseif hit then
			target.engaged = true
			ns.bestiaryStats.hits = ns.bestiaryStats.hits + 1
		end
		return
	end
	-- frappé (ou raté) par un mob repéré : c'est aussi un combat engagé
	if not hit then return end
	local attacker = sourceGUID and units[sourceGUID]
	if not attacker and sourceGUID and FromGroup(destGUID, destFlags) then attacker = Adopt(self, sourceGUID) end
	if attacker and FromGroup(destGUID, destFlags) then attacker.engaged = true end
end

-- ---------------------------------------------------------------------------
-- Complétion de zone et objectifs
-- ---------------------------------------------------------------------------
-- QC 2.0 : hors du pourcentage d'exploration (exploration = false) ; la
-- collection de la zone, c'est le sceau de la Ménagerie (MenagerieCollection.lua)
if ns.RegisterZonePart then
	ns.RegisterZonePart({ id = "bestiary", label = "JRN_PART_bestiary", exploration = false,
		Compute = function(self, zoneID) return self:BestiaryPart(zoneID, false) end })
	ns.RegisterZonePart({ id = "named", label = "JRN_PART_named", exploration = false,
		Compute = function(self, zoneID) return self:BestiaryPart(zoneID, true) end })
end

-- Zone courante seulement ; un objectif atteint disparaît (ns.JournalGoal)
local function BestiaryGoals(self, list)
	local zoneID, zoneName = self:JournalZone()
	if not zoneID or not ns.JournalGoal then return end
	zoneName = tostring(zoneName or "?")
	for _, def in ipairs({
		{ id = "bestiary:", label = "BST_GOAL_BESTIARY", named = false },
		{ id = "named:",    label = "BST_GOAL_NAMED",    named = true },
	}) do
		local part = self:BestiaryPart(zoneID, def.named)
		local goal = part and ns.JournalGoal(def.id .. zoneID, self:F(def.label, zoneName),
			part.have, part.need, nil, "bestiary")
		if goal then
			goal.unit, goal.hint = L.BST_UNIT, part.hint
			list[#list + 1] = goal
		end
	end
end
if ns.RegisterGoalSource then ns.RegisterGoalSource(BestiaryGoals) end

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
local function CombatArgs(...)
	-- clients modernes : charge utile via CombatLogGetCurrentEventInfo ;
	-- très anciens : passée à l'événement
	local fn = rawget(_G, "CombatLogGetCurrentEventInfo")
	local ok, subevent, sourceGUID, sourceFlags, destGUID, destFlags
	if type(fn) == "function" then
		local _
		ok, _, subevent, _, sourceGUID, _, sourceFlags, _, destGUID, _, destFlags = pcall(fn)
		if not ok then return nil end
	else
		local _
		_, subevent, _, sourceGUID, _, sourceFlags, _, destGUID, _, destFlags = ...
	end
	return subevent, sourceGUID, sourceFlags, destGUID, destFlags
end

local HANDLERS = {
	PLAYER_TARGET_CHANGED = function() ns:BestiarySeeUnit("target") end,
	UPDATE_MOUSEOVER_UNIT = function() ns:BestiarySeeUnit("mouseover") end,
	NAME_PLATE_UNIT_ADDED = function(unit) ns:BestiarySeeUnit(unit) end,
	-- deuxième source : « X meurt, vous gagnez N points d'expérience ». Si le
	-- journal de combat n'a rien donné, la cible morte est comptée ici.
	CHAT_MSG_COMBAT_XP_GAIN = function(message) ns:BestiaryOnXP(message) end,
	COMBAT_LOG_EVENT_UNFILTERED = function(...)
		ns.bestiaryStats.events = ns.bestiaryStats.events + 1
		-- coût nul sans mob repéré ni table livrée (ZoneCreatures_Forever :
		-- en pratique, toujours traité)
		if not next(ns.bestiaryUnits) and rawget(ns, "ZONE_CREATURES") == nil then return end
		ns:BestiaryCombat(CombatArgs(...))
	end,
	-- moteur 12.0 (Forever) : journal de combat fermé, ces deux-là le remplacent
	PARTY_KILL = function(attacker, target)
		target = ns.Plain(target)
		if target then ns:BestiaryCombat("PARTY_KILL", ns.Plain(attacker), ns.GroupFlags(attacker), target) end
	end,
	UNIT_DIED = function(guid)
		guid = ns.Plain(guid)
		if guid then ns:BestiaryCombat("UNIT_DIED", nil, nil, guid) end
	end,
}

-- Une victime annoncée par le message d'XP : la cible, si elle est morte
function ns:BestiaryOnXP(message)
	if not ModuleOn() then return false end
	local parse = self.ParseCombatXP
	if type(parse) ~= "function" then return false end
	local ok, xp, named = pcall(parse, self, message)
	if not (ok and xp and named) then return false end
	if not Call("UnitIsDead", "target") then return false end
	local guid = ns.Plain(Call("UnitGUID", "target"))
	if not NpcID(guid) then return false end
	local entry = self.bestiaryUnits[guid] or Adopt(self, guid)
	if not entry then return false end
	local before = ns.bestiaryStats.kills
	Kill(self, guid, entry, "xp")
	return ns.bestiaryStats.kills > before
end

-- /qc diag : ce que le bestiaire a reçu depuis la connexion
do
	local previous = ns.DiagExtra
	function ns:DiagExtra(...)
		if previous then previous(self, ...) end
		local st = ns.bestiaryStats
		self:Print(self:F("BESTIARY_DIAG",
			st.combatLog and L.BESTIARY_DIAG_CLOG or "PARTY_KILL/UNIT_DIED",
			st.events, st.hits, st.partyKills, st.died, st.kills, st.xpKills))
	end
end

-- 3.1.0 : cadre d'événements commun (ns.Listen, Libs/Socle/Compat.lua)
ns.BESTIARY_HANDLERS = HANDLERS
ns.bestiaryStats.combatLog = ns.Listen("bestiary", HANDLERS)

if ns.Mark then ns.Mark("Bestiary") end
