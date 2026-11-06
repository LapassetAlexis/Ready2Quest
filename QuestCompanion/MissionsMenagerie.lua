-- MissionsMenagerie.lua -- Lot 4 : missions du jour et de la semaine tournées vers la ménagerie (QuestCompanion 2.0)
--
-- Jour (Daily.lua tire, ce fichier fournit) : toujours une mission de
-- ménagerie quand la capture est allumée, faisable dans la zone du tirage :
--   capNew   : capturer une espèce jamais capturée de la zone ;
--   capType  : capturer N créatures d'un type présent dans la zone ;
--   capNamed : capturer un élite ou un rare de la zone ;
--   captures : à défaut, capturer 2 créatures, où que ce soit (1.4.0).
-- Semaine (Weekly.lua tire) : une mission par type, « emmène un Mort-vivant
-- et capture 2 Morts-vivants » : seule compte une capture de ce type faite
-- avec un compagnon de ce type (effets du compagnon, lot 2, sinon
-- l'apparence en cours et sa fiche de capture).
-- Les captures se comptent par une enveloppe de ns:CaptureResolve.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.MENAGERIE_DAILY_KINDS = { "capNew", "capType", "capNamed" }
ns.MENAGERIE_TYPE_NEED = 2         -- capType du jour
ns.MENAGERIE_WEEKLY_TYPE_NEED = 2  -- typeCapture de la semaine
local MENAGERIE = { capNew = true, capType = true, capNamed = true, captures = true }
local NAMED = { elite = true, rare = true, rareelite = true, worldboss = true }
local FALLBACK_NEED = 2            -- « captures », comme avant (Daily.lua)

local FR = {
	MIS_capNew       = "Capture une espèce jamais capturée (%s)",
	MIS_capNamed     = "Capture un élite ou un rare (%s)",
	MIS_capType      = "Capture %d %s (%s)",
	WK_typeCapture   = "Emmène %s et capture %d %s",
	MMIS_ONE_beast = "Bête", MMIS_ONE_humanoid = "Humanoïde", MMIS_ONE_undead = "Mort-vivant",
	MMIS_ONE_elemental = "Élémentaire", MMIS_ONE_dragonkin = "Draconien", MMIS_ONE_demon = "Démon",
	MMIS_ONE_giant = "Géant", MMIS_ONE_mechanical = "Mécanique",
	MMIS_MANY_beast = "Bêtes", MMIS_MANY_humanoid = "Humanoïdes", MMIS_MANY_undead = "Morts-vivants",
	MMIS_MANY_elemental = "Élémentaires", MMIS_MANY_dragonkin = "Draconiens", MMIS_MANY_demon = "Démons",
	MMIS_MANY_giant = "Géants", MMIS_MANY_mechanical = "Mécaniques",
	MMIS_A_beast = "une Bête", MMIS_A_humanoid = "un Humanoïde", MMIS_A_undead = "un Mort-vivant",
	MMIS_A_elemental = "un Élémentaire", MMIS_A_dragonkin = "un Draconien", MMIS_A_demon = "un Démon",
	MMIS_A_giant = "un Géant", MMIS_A_mechanical = "un Mécanique",
}
local EN = {
	MIS_capNew       = "Capture a species never captured (%s)",
	MIS_capNamed     = "Capture an elite or a rare (%s)",
	MIS_capType      = "Capture %d %s (%s)",
	WK_typeCapture   = "Bring %s and capture %d %s",
	MMIS_ONE_beast = "Beast", MMIS_ONE_humanoid = "Humanoid", MMIS_ONE_undead = "Undead",
	MMIS_ONE_elemental = "Elemental", MMIS_ONE_dragonkin = "Dragonkin", MMIS_ONE_demon = "Demon",
	MMIS_ONE_giant = "Giant", MMIS_ONE_mechanical = "Mechanical",
	MMIS_MANY_beast = "Beasts", MMIS_MANY_humanoid = "Humanoids", MMIS_MANY_undead = "Undead",
	MMIS_MANY_elemental = "Elementals", MMIS_MANY_dragonkin = "Dragonkin", MMIS_MANY_demon = "Demons",
	MMIS_MANY_giant = "Giants", MMIS_MANY_mechanical = "Mechanicals",
	MMIS_A_beast = "a Beast", MMIS_A_humanoid = "a Humanoid", MMIS_A_undead = "an Undead",
	MMIS_A_elemental = "an Elemental", MMIS_A_dragonkin = "a Dragonkin", MMIS_A_demon = "a Demon",
	MMIS_A_giant = "a Giant", MMIS_A_mechanical = "a Mechanical",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.MISSIONS_MENAGERIE_STRINGS = { fr = FR, en = EN } end

local function ModuleOn() return ns.CompanionOn and ns.CompanionOn() or false end
local function Here(self) return self.JournalZone and self:JournalZone() or nil end

local function ZoneName(self, zoneID)
	local info = zoneID and self.MapInfo and self:MapInfo(zoneID)
	return (info and info.name) or tostring(zoneID or "?")
end

function ns:MenagerieMissionsOn()
	return self.CaptureData ~= nil and ModuleOn() and self:DB().companionCapture ~= false
end

-- Une mission du jour de ménagerie ? (y compris « captures » d'avant la 2.0)
function ns:MissionIsMenagerie(mission)
	return type(mission) == "table" and (mission.cat == "menagerie" or MENAGERIE[mission.kind or ""] == true)
end

-- ---------------------------------------------------------------------------
-- Types : d'une fiche, d'une espèce, du compagnon en cours
-- ---------------------------------------------------------------------------
local function TypeKey(self, text)
	return self.CreatureTypeKey and self:CreatureTypeKey(text) or nil
end

-- Type de la créature capturée (fiche de capture, sinon bestiaire)
local function TargetType(self, target)
	local key = TypeKey(self, target.type)
	if key then return key end
	local entry = self:CaptureData().creatures[target.npcID]
	key = type(entry) == "table" and TypeKey(self, entry.type) or nil
	if key then return key end
	local book = self.BestiaryData and self:BestiaryData()
	local zone = book and target.zoneID and book[target.zoneID]
	local species = type(zone) == "table" and zone[target.npcID]
	return type(species) == "table" and TypeKey(self, species.type) or nil
end

-- Type du compagnon emmené : ses effets (lot 2) s'ils existent, sinon
-- l'apparence en cours (« cap:<npc> » ou « cap:<npc>:s ») et sa fiche
function ns:MenagerieCompanionType()
	if self.CompanionEffects then
		local ok, effects = pcall(self.CompanionEffects, self)
		if ok and type(effects) == "table" then return effects.typeKey end
	end
	local data = self:CompanionData()
	local npc = type(data.appearance) == "string" and tonumber(data.appearance:match("^cap:(%d+)"))
	local entry = npc and self:CaptureData().creatures[npc]
	return type(entry) == "table" and TypeKey(self, entry.type) or nil
end

-- Libellés d'un type : « Bête », « Bêtes », « une Bête »
local function TypeText(key, form)
	return L["MMIS_" .. form .. "_" .. tostring(key)] or (ns.CreatureTypeLabel and ns:CreatureTypeLabel(key)) or tostring(key)
end
ns.MenagerieTypeText = TypeText

-- ---------------------------------------------------------------------------
-- Faisabilité : ce qui reste à capturer dans une zone
-- ---------------------------------------------------------------------------
-- Une espèce peut encore se capturer : version normale pas capturée, ou
-- (lot 1) capturée sous 3 étoiles, recapturable
local function Capturable(self, npcID)
	if not (self.CaptureHas and self:CaptureHas(npcID, false)) then return true end
	if self.CaptureStars then
		local ok, stars = pcall(self.CaptureStars, self, npcID, false)
		return ok and (tonumber(stars) or 1) < 3
	end
	return false
end

-- { new = n, named = n, types = { [clé] = n } } : espèces de la zone encore
-- capturables (types : seulement les espèces dont le type est appris)
function ns:MenagerieZoneTargets(zoneID)
	local out = { new = 0, named = 0, types = {} }
	if not zoneID or not self.BestiarySpecies then return out end
	local creatures = self:CaptureData().creatures
	for npcID, species in pairs(self:BestiarySpecies(zoneID)) do
		local npc = tonumber(npcID) or npcID
		if type(species) == "table" then
			if creatures[npc] == nil then out.new = out.new + 1 end
			if Capturable(self, npc) then
				if NAMED[species.class or ""] then out.named = out.named + 1 end
				local key = TypeKey(self, species.type)
				if key then out.types[key] = (out.types[key] or 0) + 1 end
			end
		end
	end
	return out
end

local function Mission(kind, zoneID, need, ctype)
	return { kind = kind, zoneID = zoneID, need = need, have = 0, source = "zone", cat = "menagerie",
		ctype = ctype, start = 0 }
end

-- La mission de ménagerie du jour, faisable dans la zone ; `others` : les
-- missions déjà là (on n'en reprend ni la sorte, ni le type). nil si la
-- capture est coupée ou si rien ne reste à tirer.
function ns:MissionMenagerieDraw(zoneID, others)
	if not self:MenagerieMissionsOn() then return nil end
	local used = {}
	for _, other in ipairs(others or {}) do
		used[tostring(other.kind) .. ":" .. tostring(other.ctype or "")] = true
		if other.kind ~= "capType" then used[tostring(other.kind)] = true end
	end
	local targets = self:MenagerieZoneTargets(zoneID)
	local pool = {}
	if zoneID and targets.new > 0 and not used.capNew then pool[#pool + 1] = Mission("capNew", zoneID, 1) end
	if zoneID and targets.named > 0 and not used.capNamed then pool[#pool + 1] = Mission("capNamed", zoneID, 1) end
	if zoneID then
		local types = {}
		for _, key in ipairs(ns.CREATURE_TYPES or {}) do
			if (targets.types[key] or 0) > 0 and not used["capType:" .. key] then types[#types + 1] = key end
		end
		if #types > 0 then
			local key = types[math.random(#types)]
			-- sans recapture (lot 1), pas plus que d'espèces à prendre
			local need = ns.MENAGERIE_TYPE_NEED
			if not self.CaptureStars then need = math.max(1, math.min(need, targets.types[key])) end
			pool[#pool + 1] = Mission("capType", zoneID, need, key)
		end
	end
	if #pool > 0 then return pool[math.random(#pool)] end
	-- rien de propre à la zone : capturer où que ce soit
	if used.captures then return nil end
	return Mission("captures", nil, FALLBACK_NEED)
end

-- La mission par type de la semaine : un type dont tu as une créature à
-- emmener et assez d'espèces encore capturables (apprises au bestiaire),
-- celles de la zone actuelle d'abord. { kind, need, ctype } ou nil.
function ns:MenagerieWeeklyTypeMission()
	if not self:MenagerieMissionsOn() then return nil end
	local need = ns.MENAGERIE_WEEKLY_TYPE_NEED
	local owned = {}
	for _, entry in pairs(self:CaptureData().creatures) do
		local key = type(entry) == "table" and TypeKey(self, entry.type) or nil
		if key then owned[key] = true end
	end
	local counts = {}
	local book = self.BestiaryData and self:BestiaryData() or {}
	local seen = {}
	for _, zone in pairs(book) do
		if type(zone) == "table" then
			for npcID, species in pairs(zone) do
				local npc = tonumber(npcID) or npcID
				local key = type(species) == "table" and TypeKey(self, species.type) or nil
				if key and not seen[npc] and Capturable(self, npc) then
					seen[npc] = true
					counts[key] = (counts[key] or 0) + 1
				end
			end
		end
	end
	local here = self:MenagerieZoneTargets(Here(self)).types
	local near, far = {}, {}
	for _, key in ipairs(ns.CREATURE_TYPES or {}) do
		if owned[key] and (counts[key] or 0) >= need then
			if (here[key] or 0) > 0 then near[#near + 1] = key else far[#far + 1] = key end
		end
	end
	local pool = #near > 0 and near or far
	if #pool == 0 then return nil end
	return { kind = "typeCapture", need = need, ctype = pool[math.random(#pool)] }
end

-- ---------------------------------------------------------------------------
-- Libellés
-- ---------------------------------------------------------------------------
do
	local label = ns.MissionLabel
	if label then
		function ns:MissionLabel(mission)
			local kind = type(mission) == "table" and mission.kind
			if kind == "capNew" or kind == "capNamed" then
				return self:F("MIS_" .. kind, ZoneName(self, mission.zoneID))
			elseif kind == "capType" then
				local form = (tonumber(mission.need) or 1) > 1 and "MANY" or "ONE"
				return self:F("MIS_capType", mission.need, TypeText(mission.ctype, form), ZoneName(self, mission.zoneID))
			end
			return label(self, mission)
		end
	end
	local weekly = ns.WeeklyLabel
	if weekly then
		function ns:WeeklyLabel(mission)
			if type(mission) == "table" and mission.kind == "typeCapture" then
				local form = (tonumber(mission.need) or 1) > 1 and "MANY" or "ONE"
				return self:F("WK_typeCapture", TypeText(mission.ctype, "A"), mission.need, TypeText(mission.ctype, form))
			end
			return weekly(self, mission)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Compter les captures (enveloppe de ns:CaptureResolve)
-- ---------------------------------------------------------------------------
function ns:MenagerieMissionCapture(target, fresh)
	if type(target) ~= "table" or not target.npcID then return end
	local zoneID = tonumber(target.zoneID) or Here(self)
	if fresh then self:MissionEvent("capNew", 1, zoneID) end
	if NAMED[target.class or ""] then self:MissionEvent("capNamed", 1, zoneID) end
	local key = TargetType(self, target)
	if key then
		local info = { ctype = key }
		self:MissionEvent("capType", 1, zoneID, info)
		if self.WeeklyEvent and self:MenagerieCompanionType() == key then
			self:WeeklyEvent("typeCapture", 1, info)
		end
	end
end

do
	local resolve = ns.CaptureResolve
	if resolve then
		function ns:CaptureResolve(rolling, ...)
			local target = type(rolling) == "table" and rolling.target or nil
			local fresh = type(target) == "table" and target.npcID ~= nil
				and self:CaptureData().creatures[target.npcID] == nil
			local a, b, c = resolve(self, rolling, ...)
			if type(rolling) == "table" and rolling.success and target then
				local ok, err = pcall(self.MenagerieMissionCapture, self, target, fresh)
				if not ok and self.RecordError then self:RecordError("missions:capture", err) end
			end
			return a, b, c
		end
	end
end

if ns.Mark then ns.Mark("MissionsMenagerie") end
