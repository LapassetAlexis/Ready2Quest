-- Daily.lua -- au jour le jour : fidélité aux auberges et missions du jour (QuestCompanion 1.1.0)
--
-- Fidélité : une seule carte pour toutes les auberges. Au plus un tampon par
-- jour (date de l'ordinateur), chez n'importe quel aubergiste à qui tu
-- parles : +INN_ENERGY d'énergie et sa joie. Tous les INN_CARD tampons, un
-- Festin. Pas besoin de jours d'affilée : rien ne se perd.
--
-- Missions : chaque jour, à la première zone où tu entres, la créature
-- propose deux missions de cette zone (seulement celles qui y sont
-- faisables) et une mission de son caractère. Une mission de zone peut être
-- changée une fois par jour. Chaque mission faite : une friandise (envie la
-- plus basse) et un peu de curiosité ; les trois : un Festin. Une mission
-- non faite est simplement remplacée le lendemain.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.DAILY_AUTO = ns.DAILY_AUTO ~= false      -- tirage automatique (coupé dans le banc de test)
ns.INN_ENERGY = 20
ns.INN_CARD = 7
ns.MISSION_CURIOSITY = 10
ns.MISSION_POLL = 2
-- Apparences gagnées au jour le jour (QuestCompanion 1.2.0, CompanionData.lua)
ns.INN_APPEARANCE, ns.INN_APPEARANCE_CARDS = "chicken", 3
ns.MISSION_APPEARANCE, ns.MISSION_APPEARANCE_DAYS = "squirrel_mech", 10

-- Missions de zone : cible, faisable ?, mesure de départ
local ZONE_MISSIONS = { "species", "named", "gather", "quests", "village", "percent" }
ns.DAILY_ZONE_MISSIONS = ZONE_MISSIONS
local NEED = { species = 3, named = 1, gather = 5, quests = 2, village = 1, percent = 3, kills = 10, talks = 3 }
-- Missions de caractère : sorte et cible
local TRAIT_MISSIONS = {
	curious = { kind = "places", need = 2 },  glutton = { kind = "meals", need = 3 },
	daring = { kind = "elites", need = 1 },   lazy = { kind = "rest", need = 15 },
	teasing = { kind = "kills", need = 20 },  cuddly = { kind = "pets", need = 3 },
	wise = { kind = "turnins", need = 3 },    parrot = { kind = "talks", need = 3 },
	mystic = { kind = "nightKills", need = 5 }, zen = { kind = "calm", need = 15 },
	sly = { kind = "gold", need = 1 },         mischievous = { kind = "pets", need = 5 },
	fearful = { kind = "rest", need = 10 },    tinker = { kind = "talks", need = 4 },
}
ns.DAILY_TRAIT_MISSIONS = TRAIT_MISSIONS
local GENERIC = { kind = "pets", need = 3 }

local FR = {
	MIS_species      = "Abats %d espèces jamais vaincues (%s)",
	MIS_named        = "Abats un élite ou un rare (%s)",
	MIS_gather       = "Récolte %d fois (%s)",
	MIS_quests       = "Rends %d quêtes (%s)",
	MIS_village      = "Visite un lieu jamais vu (%s)",
	MIS_percent      = "Fais gagner %d %% à %s",
	MIS_kills        = "Abats %d ennemis",
	MIS_places       = "Découvre %d lieux",
	MIS_meals        = "Mange ou bois %d fois",
	MIS_elites       = "Abats %d élite ou rare",
	MIS_rest         = "Repose-toi %d minutes",
	MIS_pets         = "Fais-moi %d caresses",
	MIS_turnins      = "Rends %d quêtes",
	MIS_talks        = "Parle à %d personnes",
	MIS_nightKills   = "Abats %d ennemis de nuit",
	MIS_calm         = "Joue %d minutes sans tomber",
	MIS_gold         = "Gagne %d pièce d'or",
	MIS_SOURCE_zone  = "mission de %s",
	MIS_SOURCE_trait = "mission de %s",
	MIS_SOURCE_none  = "sa mission du jour",
	MIS_DONE         = "faite",
	MIS_REROLL       = "Changer",
	MIS_REROLL_TIP   = "Une mission de zone peut être changée une fois par jour.",
	MIS_ALL_BONUS    = "Les 3 missions faites : un Festin en plus. Rien n'est perdu si tu ne les fais pas.",
	MIS_RENEW        = "Nouvelles missions demain.",
	MIS_NONE         = "Entre dans une zone : la créature te proposera ses missions du jour.",
	MIS_OFF          = "Missions du jour coupées (réglages, page Au jour le jour).",
	MIS_GOAL_HINT    = "Mission du jour : clic pour l'onglet Jour du carnet.",
	INN_TITLE        = "Carte de fidélité des auberges",
	INN_HINT         = "Un tampon par jour chez n'importe quel aubergiste (+%d d'énergie). Au %de : un Festin. Pas besoin de jours d'affilée.",
	INN_TOTAL        = "Tampons : %d en tout · cartes pleines : %d",
	INN_GIFT         = "À %d cartes pleines : %s.",
	MIS_PERFECT      = "Jours aux trois missions : %d · à %d : %s.",
	DAILY_MSG_UNLOCK = "Nouvelle apparence : %s !",
	DAY_MISSIONS     = "Missions du jour",
	DAY_PANTRY       = "Garde-manger",
	DAY_PANTRY_HINT  = "Maj + clic sur la créature",
	DAY_GIVE         = "Donner",
	JRN_SEC_day      = "Jour",
	OPT_DAILY_MISSIONS = "Missions du jour",
	OPT_DAILY_MISSIONS_DESC = "Deux missions de zone et une de son caractère chaque jour, dans le carnet (onglet Jour) et le bloc à l'écran.",
}
local EN = {
	MIS_species      = "Defeat %d species never defeated (%s)",
	MIS_named        = "Defeat an elite or a rare (%s)",
	MIS_gather       = "Gather %d times (%s)",
	MIS_quests       = "Turn in %d quests (%s)",
	MIS_village      = "Visit a place never seen (%s)",
	MIS_percent      = "Bring %s up %d%%",
	MIS_kills        = "Defeat %d enemies",
	MIS_places       = "Discover %d places",
	MIS_meals        = "Eat or drink %d times",
	MIS_elites       = "Defeat %d elite or rare",
	MIS_rest         = "Rest for %d minutes",
	MIS_pets         = "Give me %d cuddles",
	MIS_turnins      = "Turn in %d quests",
	MIS_talks        = "Talk to %d people",
	MIS_nightKills   = "Defeat %d enemies at night",
	MIS_calm         = "Play %d minutes without dying",
	MIS_gold         = "Earn %d gold coin",
	MIS_SOURCE_zone  = "%s mission",
	MIS_SOURCE_trait = "%s mission",
	MIS_SOURCE_none  = "its mission of the day",
	MIS_DONE         = "done",
	MIS_REROLL       = "Change",
	MIS_REROLL_TIP   = "A zone mission can be changed once a day.",
	MIS_ALL_BONUS    = "All 3 missions done: a Feast on top. Nothing is lost if you skip them.",
	MIS_RENEW        = "New missions tomorrow.",
	MIS_NONE         = "Enter a zone: your companion will offer its missions of the day.",
	MIS_OFF          = "Daily missions turned off (settings, Day by day page).",
	MIS_GOAL_HINT    = "Mission of the day: click for the journal's Day tab.",
	INN_TITLE        = "Inn loyalty card",
	INN_HINT         = "One stamp a day at any innkeeper (+%d energy). On the %dth: a Feast. No need for days in a row.",
	INN_TOTAL        = "Stamps: %d in all · full cards: %d",
	INN_GIFT         = "At %d full cards: %s.",
	MIS_PERFECT      = "Days with all three missions: %d · at %d: %s.",
	DAILY_MSG_UNLOCK = "New appearance: %s!",
	DAY_MISSIONS     = "Missions of the day",
	DAY_PANTRY       = "Pantry",
	DAY_PANTRY_HINT  = "Shift + click the creature",
	DAY_GIVE         = "Give",
	JRN_SEC_day      = "Day",
	OPT_DAILY_MISSIONS = "Missions of the day",
	OPT_DAILY_MISSIONS_DESC = "Two zone missions and one from its character every day, in the journal (Day tab) and the on-screen block.",
}
ns.RegisterStrings(FR, EN)
ns.DAILY_STRINGS = { fr = FR, en = EN }

local P = {
	MISSION_NEW = {
		{ "Nouvelles missions du jour ! Regarde dans mon carnet.", "New missions of the day! Have a look in my journal." },
		{ "J'ai des idées pour aujourd'hui… onglet Jour !", "I've got ideas for today… Day tab!" },
	},
	MISSION_DONE = {
		{ "Mission accomplie ! Une friandise pour moi ?", "Mission done! A treat for me?" },
		{ "Et une mission de faite !", "One mission done!" },
	},
	MISSION_ALL = {
		{ "Les trois missions ! Ce soir, c'est festin !", "All three missions! Tonight, we feast!" },
	},
	INN_STAMP = {   -- %d = tampons sur la carte, %d = taille de la carte
		{ "Un tampon sur ma carte : %d/%d !", "A stamp on my card: %d/%d!" },
		{ "Tampon ! %d sur %d. J'adore les auberges.", "Stamp! %d of %d. I love inns." },
	},
	INN_FULL = {
		{ "Carte pleine ! L'aubergiste m'offre un festin !", "Card full! The innkeeper treats me to a feast!" },
	},
}
local LINES_FR, LINES_EN, POOLS = {}, {}, {}
for name, lines in pairs(P) do
	local keys = {}
	for index, pair in ipairs(lines) do
		local key = "COMP_SAY_" .. name .. (index > 1 and ("_" .. index) or "")
		LINES_FR[key], LINES_EN[key] = pair[1], pair[2]
		keys[index] = key
	end
	POOLS[name] = keys
end
ns.RegisterStrings(LINES_FR, LINES_EN)
if type(ns.COMPANION_POOLS) == "table" then
	for name, keys in pairs(POOLS) do ns.COMPANION_POOLS[name] = keys end
end
local shared = ns.COMPANION_LINE_STRINGS
if type(shared) == "table" then
	for key, text in pairs(LINES_FR) do shared.fr[key], shared.en[key] = text, LINES_EN[key] end
end
ns.DAILY_POOLS = POOLS

ns.RegisterDefaults({ companionMissions = true })
if type(ns.DAILY_OPTION_ROWS) == "table" then
	table.insert(ns.DAILY_OPTION_ROWS, 1, { key = "companionMissions", label = "OPT_DAILY_MISSIONS", kind = "bool",
		describe = function() return L.OPT_DAILY_MISSIONS_DESC end })
end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function ModuleOn() return ns.CompanionOn and ns.CompanionOn() or false end

function ns:DailyToday()
	local date = G("date") or (os and os.date)
	return tostring(Call(date, "%Y-%m-%d") or "?")
end

local function ZoneName(self, zoneID)
	local info = zoneID and self.MapInfo and self:MapInfo(zoneID)
	return (info and info.name) or tostring(zoneID or "?")
end

-- ---------------------------------------------------------------------------
-- Données
-- ---------------------------------------------------------------------------
function ns:DailyData()
	local data = self:CompanionData()
	local daily = type(data.daily) == "table" and data.daily or {}
	daily.missions = type(daily.missions) == "table" and daily.missions or {}
	data.daily = daily
	local inn = type(data.inn) == "table" and data.inn or {}
	inn.card = math.max(0, math.floor(tonumber(inn.card) or 0))
	inn.total = math.max(0, math.floor(tonumber(inn.total) or 0))
	inn.full = math.max(0, math.floor(tonumber(inn.full) or 0))
	daily.perfect = math.max(0, math.floor(tonumber(daily.perfect) or 0))
	data.inn = inn
	return daily, inn
end

-- Une apparence gagnée au jour le jour (une fois) : chat et bulle
function ns:DailyGrantAppearance(id)
	local unlocked = self:CompanionData().unlocked
	local key = "app:" .. tostring(id)
	if unlocked[key] then return false end
	local def = self.CompanionAppearanceDef and self:CompanionAppearanceDef(id)
	if not def then return false end
	unlocked[key] = true
	local label = L[def.label] or id
	self:Print(self:F("DAILY_MSG_UNLOCK", label))
	self:CompanionSay("UNLOCK", { force = true, category = "event", args = { label } })
	return true
end

function ns:DailyMissionsOn()
	return ModuleOn() and self:DB().companionMissions ~= false
end

-- ---------------------------------------------------------------------------
-- Fidélité aux auberges
-- ---------------------------------------------------------------------------
function ns:InnStamp()
	if not ModuleOn() then return nil end
	local _, inn = self:DailyData()
	local today = self:DailyToday()
	if inn.day == today then return nil end
	inn.day = today
	inn.card, inn.total = inn.card + 1, inn.total + 1
	self:CompanionAdd("energy", ns.INN_ENERGY)
	if self.CompanionFx then self:CompanionFx("hearts") end
	if inn.card >= ns.INN_CARD then
		inn.card = 0
		inn.full = inn.full + 1
		if inn.full >= ns.INN_APPEARANCE_CARDS then self:DailyGrantAppearance(ns.INN_APPEARANCE) end
		if self.TreatGrant then self:TreatGrant("festin", { quiet = true }) end
		self:CompanionSay("INN_FULL", { force = true, category = "event" })
		self:DailyChanged()
		return "full"
	end
	self:CompanionSay("INN_STAMP", { force = true, category = "event", args = { inn.card, ns.INN_CARD } })
	self:DailyChanged()
	return "stamp"
end

do
	local onNpc = ns.CompanionOnNpc
	if onNpc then
		function ns:CompanionOnNpc(kind, ...)
			if kind == "innkeeper" then
				local ok, result = pcall(self.InnStamp, self)
				if ok and result then return true end
				if not ok and self.RecordError then self:RecordError("daily:inn", result) end
			end
			local said = onNpc(self, kind, ...)
			if kind then pcall(self.MissionEvent, self, "talks", 1) end
			return said
		end
	end
end

-- ---------------------------------------------------------------------------
-- Missions : faisabilité et mesure
-- ---------------------------------------------------------------------------
local function Part(self, zoneID, id)
	local done = self.ZoneCompletion and self:ZoneCompletion(zoneID)
	if not done then return nil, nil end
	for _, part in ipairs(done.parts) do if part.id == id then return part, done end end
	return nil, done
end

-- La mesure d'une mission de zone : un nombre qui monte
function ns:MissionMeasure(kind, zoneID)
	if kind == "species" then
		return self.BestiaryCounts and self:BestiaryCounts(zoneID).killed or 0
	elseif kind == "percent" then
		local done = self.ZoneCompletion and self:ZoneCompletion(zoneID)
		return done and done.percent or 0
	end
	return 0
end

function ns:MissionFeasible(kind, zoneID)
	if not zoneID then return kind == "kills" end
	if kind == "species" then
		local counts = self.BestiaryCounts and self:BestiaryCounts(zoneID)
		return counts ~= nil and counts.seen - counts.killed >= NEED.species
	elseif kind == "named" then
		local counts = self.BestiaryCounts and self:BestiaryCounts(zoneID)
		return counts ~= nil and counts.namedSeen > counts.namedKilled
	elseif kind == "gather" then
		return self.GatheringZoneBand ~= nil and #((self:GatheringZoneBand(zoneID))) > 0
	elseif kind == "quests" then
		local part = Part(self, zoneID, "quests")
		return part ~= nil and part.need - part.have >= NEED.quests
	elseif kind == "village" then
		local part = Part(self, zoneID, "villages")
		return part ~= nil and part.have < part.need
	elseif kind == "percent" then
		local _, done = Part(self, zoneID, "")
		return done ~= nil and #done.parts >= 2 and done.percent <= 100 - NEED.percent
	end
	return kind == "kills"
end

local function NewMission(self, kind, zoneID, need, source)
	return { kind = kind, zoneID = zoneID, need = need or NEED[kind] or 1, have = 0, source = source,
		start = zoneID and self:MissionMeasure(kind, zoneID) or 0 }
end

-- Tire les deux missions de zone (faisables, différentes) et celle du caractère
function ns:MissionDraw(zoneID)
	local daily = self:DailyData()
	local pool = {}
	for _, kind in ipairs(ZONE_MISSIONS) do
		if self:MissionFeasible(kind, zoneID) then pool[#pool + 1] = kind end
	end
	local missions = {}
	while #missions < 2 and #pool > 0 do
		local kind = table.remove(pool, math.random(#pool))
		missions[#missions + 1] = NewMission(self, kind, zoneID, nil, "zone")
	end
	-- zone toute faite : des ennemis à abattre, des gens à qui parler, où que ce soit
	for _, kind in ipairs({ "kills", "talks" }) do
		if #missions < 2 then missions[#missions + 1] = NewMission(self, kind, nil, NEED[kind], "zone") end
	end
	local trait = self.CompanionTrait and self:CompanionTrait()
	local def = TRAIT_MISSIONS[trait or ""] or GENERIC
	local own = NewMission(self, def.kind, nil, def.need, "trait")
	own.trait = TRAIT_MISSIONS[trait or ""] and trait or nil
	missions[3] = own
	daily.day, daily.zoneID, daily.missions, daily.rerolled, daily.allDone = self:DailyToday(), zoneID, missions, nil, nil
	self:CompanionSay("MISSION_NEW", { force = true, category = "event" })
	self:DailyChanged()
	return missions
end

-- Une mission de zone remplacée (une fois par jour)
function ns:MissionReroll(index)
	local daily = self:DailyData()
	local mission = daily.missions[index]
	if daily.rerolled or not mission or mission.source ~= "zone" or mission.done then return false end
	local used = {}
	for _, other in ipairs(daily.missions) do used[other.kind] = true end
	local pool = {}
	for _, kind in ipairs(ZONE_MISSIONS) do
		if not used[kind] and self:MissionFeasible(kind, daily.zoneID) then pool[#pool + 1] = kind end
	end
	if not used.kills and #pool == 0 then pool[1] = "kills" end
	if #pool == 0 then return false end
	local kind = pool[math.random(#pool)]
	daily.missions[index] = NewMission(self, kind, kind ~= "kills" and daily.zoneID or nil, kind == "kills" and NEED.kills or nil, "zone")
	daily.rerolled = true
	self:DailyChanged()
	return true
end

-- Avance une mission ; faite : sa récompense, et le Festin des trois
local function Advance(self, mission, have)
	if mission.done then return false end
	mission.have = math.max(mission.have or 0, math.min(have, mission.need))
	if mission.have < mission.need then return true end
	mission.done = true
	if self.TreatGrant and self.TreatForLowestNeed then self:TreatGrant(self:TreatForLowestNeed(), { quiet = true }) end
	self:CompanionAdd("curiosity", ns.MISSION_CURIOSITY)
	if self.CompanionFx then self:CompanionFx("bounce") end
	local daily = self:DailyData()
	local all = true
	for _, other in ipairs(daily.missions) do if not other.done then all = false end end
	if all then
		daily.allDone = true
		daily.perfect = (tonumber(daily.perfect) or 0) + 1
		if daily.perfect >= ns.MISSION_APPEARANCE_DAYS then self:DailyGrantAppearance(ns.MISSION_APPEARANCE) end
		if self.TreatGrant then self:TreatGrant("festin", { quiet = true }) end
		self:CompanionSay("MISSION_ALL", { force = true, category = "event" })
	else
		self:CompanionSay("MISSION_DONE", { force = true, category = "event" })
	end
	return true
end

-- Un événement de jeu : chaque mission concernée avance
-- (kind : pets, meals, elites, kills, nightKills, turnins, talks, places,
-- gather, village, rest, calm, gold ; zoneID : là où ça s'est passé)
function ns:MissionEvent(kind, amount, zoneID)
	if not self:DailyMissionsOn() then return false end
	local daily = self:DailyData()
	if daily.day ~= self:DailyToday() then return false end
	local moved = false
	for _, mission in ipairs(daily.missions) do
		if not mission.done then
			local match = mission.kind == kind
			-- missions de zone : seulement dans leur zone
			if kind == "elites" and mission.kind == "named" then match = true end
			if kind == "turnins" and mission.kind == "quests" then match = true end
			if kind == "places" and mission.kind == "village" then match = true end
			if match and mission.zoneID and zoneID ~= mission.zoneID then match = false end
			if match then
				moved = Advance(self, mission, (mission.have or 0) + (tonumber(amount) or 1)) or moved
			end
		end
	end
	if moved then self:DailyChanged() end
	return moved
end

-- Missions mesurées (espèces, pourcentage) : relues au rafraîchissement
function ns:MissionRemeasure()
	if not self:DailyMissionsOn() then return false end
	local daily = self:DailyData()
	if daily.day ~= self:DailyToday() then return false end
	local moved = false
	for _, mission in ipairs(daily.missions) do
		if not mission.done and mission.zoneID and (mission.kind == "species" or mission.kind == "percent") then
			local have = self:MissionMeasure(mission.kind, mission.zoneID) - (mission.start or 0)
			if have > (mission.have or 0) then moved = Advance(self, mission, have) or moved end
		end
	end
	if moved then self:DailyChanged() end
	return moved
end

function ns:MissionLabel(mission)
	local zone = ZoneName(self, mission.zoneID)
	if mission.kind == "percent" then return self:F("MIS_percent", mission.need, zone) end
	if mission.kind == "named" or mission.kind == "village" then return self:F("MIS_" .. mission.kind, zone) end
	if mission.zoneID then return self:F("MIS_" .. mission.kind, mission.need, zone) end
	return self:F("MIS_" .. mission.kind, mission.need)
end

function ns:MissionSource(mission)
	if mission.source == "trait" then
		if mission.trait and self.PersonaLabel then return self:F("MIS_SOURCE_trait", self:PersonaLabel(mission.trait)) end
		return L.MIS_SOURCE_none
	end
	return self:F("MIS_SOURCE_zone", ZoneName(self, mission.zoneID))
end

-- Le tirage du jour : à la première zone où l'on entre (pas en instance)
function ns:DailyPoll()
	if not self:DailyMissionsOn() then return false end
	local daily = self:DailyData()
	if daily.day == self:DailyToday() then return false end
	local zoneID = self.JournalZone and self:JournalZone()
	if not zoneID then return false end
	self:MissionDraw(zoneID)
	return true
end

function ns:DailyChanged()
	if self.RefreshJournalTracker then pcall(self.RefreshJournalTracker, self) end
	if self.journalFrame and self.journalFrame:IsShown() and self.RefreshJournal then pcall(self.RefreshJournal, self) end
end

-- ---------------------------------------------------------------------------
-- Ce qui fait avancer les missions
-- ---------------------------------------------------------------------------
local function Here(self) return self.JournalZone and self:JournalZone() or nil end
local function Night()
	local hour = tonumber((Call(G("GetGameTime"))))
	return hour ~= nil and (hour >= 21 or hour < 6)
end

local function Wrap(name, after)
	local original = ns[name]
	if type(original) ~= "function" then return end
	ns[name] = function(self, ...)
		local before = after.before and after.before(self, ...)
		local a, b, c = original(self, ...)
		local ok, err = pcall(after.run, self, a, before, ...)
		if not ok and self.RecordError then self:RecordError("daily:" .. name, err) end
		return a, b, c
	end
end

Wrap("CompanionPet", { before = function() return Call(G("IsShiftKeyDown")) end,
	run = function(self, accepted, shift) if accepted and not shift then self:MissionEvent("pets", 1) end end })
Wrap("CompanionOnKill", { before = function(self) return self.companionRT and self.companionRT.lastKill end,
	run = function(self, _, before)
		local rt = self.companionRT
		if not rt or rt.lastKill == before then return end
		self:MissionEvent("kills", 1)
		if Night() then self:MissionEvent("nightKills", 1) end
	end })
Wrap("CompanionEliteKilled", { run = function(self, elite) if elite then self:MissionEvent("elites", 1, Here(self)) end end })
Wrap("CompanionCheckAuras", { before = function(self) return self.companionEating end,
	run = function(self, _, wasEating) if self.companionEating and not wasEating then self:MissionEvent("meals", 1) end end })
Wrap("CompanionOnStamp", { run = function(self, _, _, stamp)
	if type(stamp) ~= "table" or stamp.new == false then return end
	if stamp.kind == "subzone" or stamp.kind == "zone" then self:MissionEvent("places", 1, Here(self)) end
end })
Wrap("GatheringRecord", { run = function(self, _, _, _, count, zoneID)
	self:MissionEvent("gather", 1, tonumber(zoneID) or Here(self))
end })
Wrap("CompanionOnDead", { run = function(self)
	local daily = self:DailyData()
	for _, mission in ipairs(daily.missions) do
		if mission.kind == "calm" and not mission.done then mission.have, mission.carry = 0, 0 end
	end
end })
Wrap("CompanionTick", { run = function(self, _, _, seconds)
	if not self:DailyMissionsOn() then return end
	seconds = tonumber(seconds) or 0
	local daily = self:DailyData()
	if daily.day ~= self:DailyToday() then return end
	for _, mission in ipairs(daily.missions) do
		if not mission.done then
			if mission.kind == "rest" and self:CompanionResting() then
				mission.carry = (mission.carry or 0) + seconds
			elseif mission.kind == "calm" then
				mission.carry = (mission.carry or 0) + seconds
			end
			if mission.carry and mission.carry >= 60 then
				local minutes = math.floor(mission.carry / 60)
				mission.carry = mission.carry - minutes * 60
				Advance(self, mission, (mission.have or 0) + minutes)
			end
			if mission.kind == "gold" then
				local money = tonumber((Call(G("GetMoney")))) or 0
				mission.money = mission.money or money
				local gained = math.floor((money - mission.money) / 10000)
				if gained > (mission.have or 0) then Advance(self, mission, gained) end
			end
		end
	end
end })

-- Quêtes rendues : l'événement du jeu, la zone où l'on est
local ok, frame = pcall(CreateFrame, "Frame")
if ok and frame then
	pcall(frame.RegisterEvent, frame, "QUEST_TURNED_IN")
	frame:SetScript("OnEvent", function()
		local done, err = pcall(ns.MissionEvent, ns, "turnins", 1, Here(ns))
		if not done and ns.RecordError then ns:RecordError("daily:quest", err) end
	end)
	frame:SetScript("OnUpdate", function()
		local now = Clock()
		if not ns.DAILY_AUTO or (ns.dailyPollAt or 0) > now then return end
		ns.dailyPollAt = now + ns.MISSION_POLL
		local done, err = pcall(ns.DailyPoll, ns)
		if not done and ns.RecordError then ns:RecordError("daily:poll", err) end
	end)
	ns.dailyEventFrame = frame
end

-- Le suivi se recalcule (kill, récolte, tampon) : les missions mesurées aussi
do
	local refresh = ns.RefreshJournalTracker
	if refresh then
		local busy = false
		function ns:RefreshJournalTracker(...)
			local a, b = refresh(self, ...)
			if not busy then
				busy = true
				local done, err = pcall(self.MissionRemeasure, self)
				busy = false
				if not done and self.RecordError then self:RecordError("daily:measure", err) end
			end
			return a, b
		end
	end
end

-- Objectifs : les missions du jour dans le bloc « Carnet »
if ns.RegisterGoalSource then
	ns.RegisterGoalSource(function(self, list)
		if not self:DailyMissionsOn() then return end
		local daily = self:DailyData()
		if daily.day ~= self:DailyToday() then return end
		for index, mission in ipairs(daily.missions) do
			if not mission.done then
				local goal = ns.JournalGoal("mission:" .. index, self:MissionLabel(mission), mission.have or 0, mission.need,
					nil, "mission")
				if goal then
					goal.hint = { self:MissionSource(mission), L.MIS_GOAL_HINT }
					goal.onClick = function()
						if ns.ToggleJournal then ns:ToggleJournal(true) end
						if ns.SelectJournalKind then ns:SelectJournalKind("day") end
					end
					list[#list + 1] = goal
				end
			end
		end
	end)
end

if ns.Mark then ns.Mark("Daily") end
