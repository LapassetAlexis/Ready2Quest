-- Bestiary.lua -- bestiaire de zone et nommés du « Carnet de voyage » (v1.25.0)
--
-- La complétion d'une zone, côté créatures, SANS base livrée : tout s'apprend
-- en jouant, par personnage.
--   * Vu     : une créature hostile ou neutre (pas un joueur, pas un familier,
--              pas une bestiole) ciblée, survolée ou dont la plaque de nom
--              apparaît. On retient son ESPÈCE (numéro de PNJ tiré du GUID),
--              son nom, son type, sa famille, sa classification et la zone.
--   * Abattu : même règle que les rares du carnet (Journal.lua) — engagée par
--              toi, ton familier ou ton groupe (coup porté, raté, ou coup
--              reçu), puis morte (UNIT_DIED / PARTY_KILL). Un mob tué par un
--              inconnu ne compte pas.
--   * Nommé  : élite, rare, rare élite ou boss.
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
}
ns.RegisterStrings(FR, EN)
ns.BESTIARY_STRINGS = { fr = FR, en = EN }

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

-- Espèces d'une zone (table npcID -> espèce), nil si rien vu
function ns:BestiaryZone(zoneID)
	local zone = zoneID and self:BestiaryData()[zoneID]
	if type(zone) ~= "table" or next(zone) == nil then return nil end
	return zone
end

function ns:BestiaryIsNamed(species)
	return type(species) == "table" and NAMED[species.class or ""] == true
end

-- { seen, killed, namedSeen, namedKilled } (zéros si rien vu)
function ns:BestiaryCounts(zoneID)
	local counts = { seen = 0, killed = 0, namedSeen = 0, namedKilled = 0 }
	for _, species in pairs(self:BestiaryZone(zoneID) or {}) do
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
	for _, species in pairs(self:BestiaryZone(zoneID) or {}) do
		if (tonumber(species.killed) or 0) == 0 and (not namedOnly or self:BestiaryIsNamed(species)) then
			local name = tostring(species.name or "?")
			if type(species.type) == "string" and species.type ~= "" then
				name = self:F("BST_HINT_NAME_TYPE", name, species.type)
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
	for guid, entry in pairs(ns.bestiaryUnits) do
		local age = now - (entry.seen or now)
		if age > (entry.engaged and ENGAGED_MEMORY or SEEN_MEMORY) then ns.bestiaryUnits[guid] = nil end
	end
end

-- Une créature repérée (cible, survol, plaque de nom). Renvoie l'espèce
-- retenue, nil si la créature n'entre pas au bestiaire.
function ns:BestiarySeeUnit(unit)
	if type(unit) ~= "string" or not ModuleOn() then return nil end
	if Call("UnitExists", unit) == false then return nil end
	if Call("UnitIsPlayer", unit) then return nil end
	-- familier, gardien, monture d'un joueur : contrôlé par un joueur
	if Call("UnitPlayerControlled", unit) then return nil end
	local guid = Call("UnitGUID", unit)
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
	entry.zoneID, entry.npcID, entry.seen = zoneID, npcID, now
	self.bestiaryUnits[guid] = entry
	Prune(now)

	local book = self:BestiaryData()
	book[zoneID] = book[zoneID] or {}
	local species = book[zoneID][npcID]
	local new = species == nil
	species = species or { killed = 0 }
	species.seen = true
	local name = Call("UnitName", unit)
	if type(name) == "string" and name ~= "" then species.name = name end
	species.name = species.name or tostring(npcID)
	species.type = creatureType or species.type
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

-- ---------------------------------------------------------------------------
-- Abattu
-- ---------------------------------------------------------------------------
-- Dans ton camp : toi, ton familier (affiliation MINE), ton groupe ou ton
-- raid (bits 0x1/0x2/0x4, lus sans la bibliothèque `bit`), comme Journal.lua
local function FromGroup(guid, flags)
	if guid and guid == Call("UnitGUID", "player") then return true end
	flags = tonumber(flags)
	return flags ~= nil and flags % 8 > 0
end

local function Kill(self, guid, entry)
	self.bestiaryUnits[guid] = nil
	if not ModuleOn() then return end
	local zone = self:BestiaryData()[entry.zoneID]
	local species = zone and zone[entry.npcID]
	if not species then return end
	local before = tonumber(species.killed) or 0
	species.killed = before + 1
	if before == 0 then Changed() end
end

function ns:BestiaryCombat(subevent, sourceGUID, sourceFlags, destGUID, destFlags)
	if type(subevent) ~= "string" then return end
	local units = self.bestiaryUnits
	local target = destGUID and units[destGUID]
	if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
		if target then
			if target.engaged then Kill(self, destGUID, target) else units[destGUID] = nil end
		end
		return
	end
	local hit = subevent:find("_DAMAGE$") or subevent:find("_MISSED$")
	if target and FromGroup(sourceGUID, sourceFlags) then
		if subevent == "PARTY_KILL" then
			Kill(self, destGUID, target)
		elseif hit then
			target.engaged = true
		end
		return
	end
	-- frappé (ou raté) par un mob repéré : c'est aussi un combat engagé
	local attacker = sourceGUID and units[sourceGUID]
	if attacker and hit and FromGroup(destGUID, destFlags) then attacker.engaged = true end
end

-- ---------------------------------------------------------------------------
-- Complétion de zone et objectifs
-- ---------------------------------------------------------------------------
if ns.RegisterZonePart then
	ns.RegisterZonePart({ id = "bestiary", label = "JRN_PART_bestiary",
		Compute = function(self, zoneID) return self:BestiaryPart(zoneID, false) end })
	ns.RegisterZonePart({ id = "named", label = "JRN_PART_named",
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
	COMBAT_LOG_EVENT_UNFILTERED = function(...)
		if not next(ns.bestiaryUnits) then return end      -- coût nul sans mob repéré
		ns:BestiaryCombat(CombatArgs(...))
	end,
}

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do
	-- un événement inconnu du client (plaques de nom) ne bloque pas les autres
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("bestiary:" .. tostring(event), err) end
end)
ns.bestiaryEventFrame = eventFrame

if ns.Mark then ns.Mark("Bestiary") end
