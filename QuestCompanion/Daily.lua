-- Daily.lua -- au jour le jour : fidélité aux auberges et missions du jour (QuestCompanion 1.1.0)
--
-- Fidélité : une seule carte pour toutes les auberges. Au plus un tampon par
-- jour (date de l'ordinateur), chez n'importe quel aubergiste à qui tu
-- parles : +INN_ENERGY d'énergie et sa joie. Tous les INN_CARD tampons, un
-- Festin. Pas besoin de jours d'affilée : rien ne se perd.
--
-- Missions : chaque jour, à la première zone où tu entres, la créature
-- propose deux missions de cette zone (seulement celles qui y sont
-- faisables) et une mission de son caractère. 2.0 : une de ménagerie
-- (capturer, MissionsMenagerie.lua) et une d'exploration (lieux, récolte,
-- quêtes) ; plus de missions « abattre des espèces ». Une mission de zone peut être
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
-- « captures » (1.4.0) : capturer des créatures, où que ce soit (Capture.lua)
-- 2.0 : ZONE_MISSIONS = les missions d'exploration ; celles de ménagerie
-- (dont « captures ») sont tirées par MissionsMenagerie.lua. « species » et
-- « named » ne sont plus tirées (elles restent lisibles pour les missions en
-- cours d'une sauvegarde).
local ZONE_MISSIONS = { "gather", "quests", "village", "percent" }
local ANYWHERE = { kills = true, talks = true, captures = true }
ns.DAILY_ZONE_MISSIONS = ZONE_MISSIONS
local NEED = { species = 3, named = 1, gather = 5, quests = 2, village = 1, percent = 3, kills = 10, talks = 3, captures = 2 }
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

-- Récompenses (1.4.0) : de quoi nourrir la créature ET de quoi capturer.
-- treat : "need" = la friandise de l'envie la plus basse, "draw" = au hasard,
-- ou une sorte ; aid : une aide de capture (Capture.lua), "draw" = tirage.
-- 2.15.0 : `paillettes` : quelques paillettes en plus (Échoppe du dresseur,
-- JournalReserve.lua), avec les aides : rien si la capture est coupée
ns.MISSION_REWARDS = {
	zone      = { treat = "need",   aid = "appat",   paillettes = 3 },
	trait     = { treat = "need",   aid = "appat",   paillettes = 3 },
	allDaily  = { treat = "festin", aid = "lasso",   paillettes = 5 },
	weekly    = { treat = "draw",   aid = "lasso",   paillettes = 5 },
	allWeekly = { treat = "festin", aid = "sifflet", paillettes = 10 },
}

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
	MIS_captures     = "Capture %d créatures",
	MIS_REWARD       = "Gain : %s",
	MIS_REWARD_PAILLETTES = "%d paillettes",
	MIS_REWARD_TREAT = "friandise",
	MIS_REWARD_AID   = "aide de capture",
	MIS_SOURCE_zone  = "mission de %s",
	MIS_SOURCE_trait = "mission de %s",
	MIS_SOURCE_none  = "sa mission du jour",
	MIS_DONE         = "faite",
	MIS_REROLL       = "Changer",
	MIS_REROLL_TIP   = "Une mission de zone peut être changée une fois par jour.",
	MIS_ALL_BONUS    = "Les 3 missions du jour faites : un Festin et un Lasso tressé en plus. Rien n'est perdu si tu ne les fais pas.",
	MIS_RENEW        = "Nouvelles missions demain.",
	MIS_NONE         = "Entre dans une zone : la créature te proposera ses missions du jour.",
	MIS_OFF          = "Missions du jour coupées (réglages, page Au jour le jour).",
	MIS_GOAL_HINT    = "Mission du jour : clic pour l'onglet Missions du carnet.",
	INN_TITLE        = "Carte de fidélité des auberges",
	INN_HINT         = "Un tampon par jour chez n'importe quel aubergiste (+%d d'énergie). Au %de : un Festin. Pas besoin de jours d'affilée.",
	INN_TOTAL        = "Tampons : %d en tout · cartes pleines : %d",
	INN_GIFT         = "À %d cartes pleines : %s.",
	MIS_PERFECT      = "Jours aux trois missions : %d · à %d : %s.",
	DAILY_MSG_UNLOCK = "Nouvelle apparence : %s !",
	DAY_GROUP_trait  = "Du compagnon",
	DAY_GROUP_zone   = "Du jour",
	DAY_GROUP_week   = "De la semaine",
	DAY_AIDS         = "Besace de capture",
	DAY_AIDS_HINT    = "À choisir dans la liste du filet (clic droit sur le filet du compagnon).",
	DAY_PANTRY       = "Garde-manger",
	DAY_PANTRY_HINT  = "Maj + clic sur la créature",
	DAY_GIVE         = "Donner",
	-- 2.9.1 : page Missions en cartes (bande résumé, tampon, étiquettes)
	MIS_ANYWHERE     = "N'importe où",
	MIS_STAMP        = "Faite",
	SUM_trait        = "Compagnon",
	SUM_zone         = "Du jour",
	SUM_week         = "Semaine",
	SUM_TRAIT        = "Caractère : %s",
	SUM_TRAIT_NONE   = "Sa mission du jour",
	SUM_BONUS        = "Les 3 : %s",
	SUM_WEEK         = "Encore %s · les 3 : %s",
	SUM_LEFT         = "encore %s",
	SUM_DONE         = "Toutes faites !",
	JRN_SEC_day      = "Missions",
	OPT_DAILY_MISSIONS = "Missions du jour",
	OPT_DAILY_MISSIONS_DESC = "Chaque jour une mission de capture, une d'exploration et une de son caractère, dans le carnet (onglet Missions) et le bloc à l'écran.",
}
local EN = {
	MIS_species      = "Defeat %d species never defeated (%s)",
	MIS_named        = "Defeat an elite or a rare (%s)",
	MIS_gather       = "Gather %d times (%s)",
	MIS_quests       = "Turn in %d quests (%s)",
	MIS_village      = "Visit a place never seen (%s)",
	MIS_percent      = "Gain %d%% in %s",
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
	MIS_captures     = "Capture %d creatures",
	MIS_REWARD       = "Gain: %s",
	MIS_REWARD_PAILLETTES = "%d glitter",
	MIS_REWARD_TREAT = "treat",
	MIS_REWARD_AID   = "capture aid",
	MIS_SOURCE_zone  = "%s mission",
	MIS_SOURCE_trait = "%s mission",
	MIS_SOURCE_none  = "its mission of the day",
	MIS_DONE         = "done",
	MIS_REROLL       = "Change",
	MIS_REROLL_TIP   = "A zone mission can be changed once a day.",
	MIS_ALL_BONUS    = "All 3 daily missions done: a Feast and a Braided lasso on top. Nothing is lost if you skip them.",
	MIS_RENEW        = "New missions tomorrow.",
	MIS_NONE         = "Enter a zone: your companion will offer its missions of the day.",
	MIS_OFF          = "Daily missions turned off (settings, Day by day page).",
	MIS_GOAL_HINT    = "Mission of the day: click for the journal's Missions tab.",
	INN_TITLE        = "Inn loyalty card",
	INN_HINT         = "One stamp a day at any innkeeper (+%d energy). On the %dth: a Feast. No need for days in a row.",
	INN_TOTAL        = "Stamps: %d in all · full cards: %d",
	INN_GIFT         = "At %d full cards: %s.",
	MIS_PERFECT      = "Days with all three missions: %d · at %d: %s.",
	DAILY_MSG_UNLOCK = "New appearance: %s!",
	DAY_GROUP_trait  = "From your companion",
	DAY_GROUP_zone   = "Of the day",
	DAY_GROUP_week   = "Of the week",
	DAY_AIDS         = "Capture pack",
	DAY_AIDS_HINT    = "Pick one in the net's list (right-click the net on your companion).",
	DAY_PANTRY       = "Pantry",
	DAY_PANTRY_HINT  = "Shift + click the creature",
	DAY_GIVE         = "Give",
	MIS_ANYWHERE     = "Anywhere",
	MIS_STAMP        = "Done",
	SUM_trait        = "Companion",
	SUM_zone         = "Today",
	SUM_week         = "This week",
	SUM_TRAIT        = "Character: %s",
	SUM_TRAIT_NONE   = "Its mission of the day",
	SUM_BONUS        = "All 3: %s",
	SUM_WEEK         = "%s left · all 3: %s",
	SUM_LEFT         = "%s left",
	SUM_DONE         = "All done!",
	JRN_SEC_day      = "Missions",
	OPT_DAILY_MISSIONS = "Missions of the day",
	OPT_DAILY_MISSIONS_DESC = "Every day a capture mission, an exploration mission and one from its character, in the journal (Missions tab) and the on-screen block.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.DAILY_STRINGS = { fr = FR, en = EN } end

local P = {
	MISSION_NEW = {
		{ "Nouvelles missions du jour ! Regarde dans mon carnet.", "New missions of the day! Have a look in my journal." },
		{ "J'ai des idées pour aujourd'hui… onglet Missions !", "I've got ideas for today… Missions tab!" },
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
-- enregistrement commun (CompanionLines.lua) ; listes de clés en test seulement
local POOLS = ns.RegisterCompanionLines(P)
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
			-- « parle à N personnes » : chaque PNJ compte une fois par jour (le même
			-- donneur de quête ouvre souvent deux fenêtres de suite)
			if kind then
				local guid = ns.Plain(Call(G("UnitGUID"), "npc"))
				local daily = self:DailyData()
				daily.talked = type(daily.talked) == "table" and daily.talked or {}
				if not guid or not daily.talked[guid] then
					if guid then daily.talked[guid] = true end
					pcall(self.MissionEvent, self, "talks", 1)
				end
			end
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
	if kind == "captures" then return self.CaptureData ~= nil and ModuleOn() and self:DB().companionCapture ~= false end
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

-- Tire les deux missions du jour (une de ménagerie si la capture est
-- allumée, une d'exploration ; faisables, différentes) et celle du caractère
function ns:MissionDraw(zoneID)
	local daily = self:DailyData()
	local pool = {}
	for _, kind in ipairs(ZONE_MISSIONS) do
		if self:MissionFeasible(kind, zoneID) then pool[#pool + 1] = kind end
	end
	local missions = {}
	-- ménagerie (MissionsMenagerie.lua) : nil si la capture est coupée
	local own = self.MissionMenagerieDraw and self:MissionMenagerieDraw(zoneID)
	if own then missions[1] = own end
	while #missions < 2 and #pool > 0 do
		local kind = table.remove(pool, math.random(#pool))
		missions[#missions + 1] = NewMission(self, kind, not ANYWHERE[kind] and zoneID or nil, nil, "zone")
	end
	-- zone toute faite : des gens à qui parler, des ennemis à abattre, où que ce soit
	for _, kind in ipairs({ "talks", "kills" }) do
		if #missions < 2 then missions[#missions + 1] = NewMission(self, kind, nil, NEED[kind], "zone") end
	end
	local trait = self.CompanionTrait and self:CompanionTrait()
	local def = TRAIT_MISSIONS[trait or ""] or GENERIC
	local own = NewMission(self, def.kind, nil, def.need, "trait")
	own.trait = TRAIT_MISSIONS[trait or ""] and trait or nil
	missions[3] = own
	daily.day, daily.zoneID, daily.missions, daily.rerolled, daily.allDone = self:DailyToday(), zoneID, missions, nil, nil
	daily.talked, daily.percentV = {}, ns.MISSION_PERCENT_V
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
	-- une mission de ménagerie se change contre une autre de ménagerie
	if self.MissionIsMenagerie and self:MissionIsMenagerie(mission) then
		local other = self.MissionMenagerieDraw and self:MissionMenagerieDraw(daily.zoneID, daily.missions)
		if not other then return false end
		daily.missions[index] = other
		daily.rerolled = true
		self:DailyChanged()
		return true
	end
	local pool = {}
	for _, kind in ipairs(ZONE_MISSIONS) do
		if not used[kind] and self:MissionFeasible(kind, daily.zoneID) then pool[#pool + 1] = kind end
	end
	for _, kind in ipairs({ "talks", "kills" }) do
		if not used[kind] and #pool == 0 then pool[1] = kind end
	end
	if #pool == 0 then return false end
	local kind = pool[math.random(#pool)]
	daily.missions[index] = NewMission(self, kind, not ANYWHERE[kind] and daily.zoneID or nil, nil, "zone")
	daily.rerolled = true
	self:DailyChanged()
	return true
end

-- Récompense d'une mission (ns.MISSION_REWARDS[scope]) : rend ce qui a été
-- gagné, { { kind = "treat"|"aid", id } }
function ns:MissionGrant(scope)
	local def = ns.MISSION_REWARDS[scope]
	local got = {}
	if not def then return got end
	if def.treat and self.TreatGrant then
		local kind = def.treat
		if kind == "need" then kind = self.TreatForLowestNeed and self:TreatForLowestNeed() end
		if kind == "draw" then kind = self.TreatRandom and self:TreatRandom() end
		if kind then self:TreatGrant(kind, { quiet = true }); got[#got + 1] = { kind = "treat", id = kind } end
	end
	if def.aid and self.CaptureGrant and self:DB().companionCapture ~= false then
		local result, id = self:CaptureGrant(def.aid, { quiet = true, silent = true })
		if result == "ok" then got[#got + 1] = { kind = "aid", id = id } end
	end
	-- 2.15.0 : les paillettes (hors de `got` : friandise et aide, comme avant)
	if def.paillettes and self.PaillettesAdd and self:DB().companionCapture ~= false then
		self:PaillettesAdd(def.paillettes, "mission:" .. tostring(scope))
	end
	return got
end

-- Ce que rapporte une mission, en clair (« friandise + Appât savoureux »)
function ns:MissionRewardText(scope)
	local def = ns.MISSION_REWARDS[scope]
	if not def then return "" end
	local parts = {}
	if def.treat == "festin" then parts[#parts + 1] = self.TreatLabel and self:TreatLabel("festin") or "festin"
	elseif def.treat then parts[#parts + 1] = L.MIS_REWARD_TREAT end
	if def.aid and self.CaptureAidLabel and self:DB().companionCapture ~= false then
		parts[#parts + 1] = def.aid == "draw" and L.MIS_REWARD_AID or self:CaptureAidLabel(def.aid)
	end
	if def.paillettes and self.PaillettesAdd and self:DB().companionCapture ~= false then
		parts[#parts + 1] = self:F("MIS_REWARD_PAILLETTES", def.paillettes)
	end
	return self:F("MIS_REWARD", table.concat(parts, " + "))
end

-- Avance une mission ; faite : sa récompense, et le Festin des trois
local function Advance(self, mission, have)
	if mission.done then return false end
	mission.have = math.max(mission.have or 0, math.min(have, mission.need))
	if mission.have < mission.need then return true end
	mission.done = true
	-- compteur de toujours (page Compagnon du carnet)
	local companion = self:CompanionData()
	companion.missionsDone = (tonumber(companion.missionsDone) or 0) + 1
	self:MissionGrant(mission.source == "trait" and "trait" or "zone")
	if self.WeeklyEvent then pcall(self.WeeklyEvent, self, "dailies", 1) end
	self:CompanionAdd("curiosity", ns.MISSION_CURIOSITY)
	if self.CompanionFx then self:CompanionFx("bounce") end
	local daily = self:DailyData()
	local all = true
	for _, other in ipairs(daily.missions) do if not other.done then all = false end end
	if all then
		daily.allDone = true
		daily.perfect = (tonumber(daily.perfect) or 0) + 1
		if daily.perfect >= ns.MISSION_APPEARANCE_DAYS then self:DailyGrantAppearance(ns.MISSION_APPEARANCE) end
		self:MissionGrant("allDaily")
		self:CompanionSay("MISSION_ALL", { force = true, category = "event" })
	else
		self:CompanionSay("MISSION_DONE", { force = true, category = "event" })
	end
	return true
end

-- Un événement de jeu : chaque mission concernée avance
-- (kind : pets, meals, elites, kills, nightKills, turnins, talks, places,
-- gather, village, rest, calm, gold ; capNew, capNamed, capType : captures
-- de MissionsMenagerie.lua ; zoneID : là où ça s'est passé ; info : détails,
-- { ctype = clé de type } pour une mission par type)
function ns:MissionEvent(kind, amount, zoneID, info)
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
			-- mission par type : seulement ce type
			if match and mission.ctype and (type(info) ~= "table" or info.ctype ~= mission.ctype) then match = false end
			if match then
				moved = Advance(self, mission, (mission.have or 0) + (tonumber(amount) or 1)) or moved
			end
		end
	end
	if moved then self:DailyChanged() end
	return moved
end

-- Formule du pourcentage d'exploration d'une zone : 2 = QC 2.0 (lieux,
-- récolte, quêtes ; le bestiaire et les nommés en sont sortis). Une mission
-- « pourcentage » tirée avec l'ancienne formule (le jour de la mise à jour)
-- a un départ mesuré autrement : il est remesuré, le progrès gardé.
ns.MISSION_PERCENT_V = 2
local function PercentMigrate(self, daily)
	if daily.percentV == ns.MISSION_PERCENT_V then return end
	for _, mission in ipairs(daily.missions) do
		if not mission.done and mission.zoneID and mission.kind == "percent" then
			-- mesure pas encore disponible : on réessaiera au prochain relevé
			if not (self.ZoneCompletion and self:ZoneCompletion(mission.zoneID)) then return end
			mission.start = self:MissionMeasure("percent", mission.zoneID) - (tonumber(mission.have) or 0)
		end
	end
	daily.percentV = ns.MISSION_PERCENT_V
end

-- Missions mesurées (espèces, pourcentage) : relues au rafraîchissement
function ns:MissionRemeasure()
	if not self:DailyMissionsOn() then return false end
	local daily = self:DailyData()
	if daily.day ~= self:DailyToday() then return false end
	PercentMigrate(self, daily)
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
	return self:F("MIS_SOURCE_zone", ZoneName(self, mission.zoneID or self:DailyData().zoneID))
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
	-- 2.11.2 (fiche 25) : regardé dix fois par seconde sur l'horloge de
	-- l'addon (l'échéance reste ns.dailyPollAt), plus d'OnUpdate permanent
	ns.Every("daily", ns.CLOCK_POLL, function()
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
-- 2.10.0 : la clé porte le jour et la mission (sorte, type de créature), plus
-- l'emplacement seul : masquer ne vaut que pour cette mission, ce jour-là ;
-- une mission changée (« Changer ») ou celle du lendemain réapparaît
local MISSION_KEY = "mission:%s:%d:%s"
function ns:MissionGoalKey(day, index, mission)
	local what = tostring(mission and mission.kind)
	if mission and mission.ctype then what = what .. "/" .. tostring(mission.ctype) end
	return string.format(MISSION_KEY, tostring(day), index, what)
end
-- Purge (une fois par jour et par session) : les anciennes clés « mission:N »
-- (migration) et celles des jours passés (les dates ISO se comparent en texte)
local purgedDay
function ns:MissionPurgeDismissed(today)
	if purgedDay == today then return end
	purgedDay = today
	local dismissed = self:JournalData().dismissed
	if type(dismissed) ~= "table" then return end
	for key in pairs(dismissed) do
		local day = type(key) == "string" and key:match("^mission:(%d%d%d%d%-%d%d%-%d%d):")
		if type(key) == "string" and (key:match("^mission:%d+$") or (day and day < today)) then dismissed[key] = nil end
	end
end
function ns:MissionPurgeReset() purgedDay = nil end

if ns.RegisterGoalSource then
	ns.RegisterGoalSource(function(self, list)
		if not self:DailyMissionsOn() then return end
		local daily = self:DailyData()
		if daily.day ~= self:DailyToday() then return end
		self:MissionPurgeDismissed(daily.day)
		for index, mission in ipairs(daily.missions) do
			if not mission.done then
				local goal = ns.JournalGoal(self:MissionGoalKey(daily.day, index, mission), self:MissionLabel(mission),
					mission.have or 0, mission.need, nil, "mission")
				if goal then
					goal.hint = { self:MissionSource(mission), L.MIS_GOAL_HINT }
					-- la page du jour ; déjà affichée : le clic referme (OpenJournalFor)
					goal.page = "day"
					goal.onClick = function() return ns:OpenJournalFor(goal) end
					list[#list + 1] = goal
				end
			end
		end
	end)
end

if ns.Mark then ns.Mark("Daily") end
