-- WorldDaily.lua -- le monde bouge : pullulation du jour, type et créature de la semaine (QuestCompanion 3.7.0)
--
-- Sans réseau, tout se tire de la date : deux joueurs voient la même chose le
-- même jour, quels que soient leur langue, leur personnage, leur faction ou
-- l'ordre de chargement des tables.
--   * Le tirage : une empreinte entière (ns.WorldHash) de « <sorte>:<jour ou
--     semaine>:<zone ou tranche> », sur une liste triée par identifiant de
--     créature. Le jour : ns:DailyToday() (les missions du jour) ; la semaine :
--     ns:WeeklyId() (les missions de la semaine). Pas de math.random.
--   * Pullulation du jour : par zone à sceau (ns.ZONE_CREATURES), une espèce
--     normale (rang 0 de la table : ni élite, ni rare, ni boss) hostile aux deux
--     factions (une espèce amicale à l'une n'est pas proposée à tous). Pour elle,
--     ce jour-là, dans sa zone : brillantes ×2 et tailles rares ×2.
--   * Type de la semaine : un des huit types (ns.CREATURE_TYPES) : capture +5 %
--     sur ce type (ajouté aux bonus de capture du compagnon, sous le plafond).
--   * Créature de la semaine : une espèce par tranche (1-20, 20-40, 40-60), la
--     même pour tous ; celle de la tranche du personnage s'affiche. La capturer
--     (n'importe laquelle des trois) : 10 paillettes ("week") et
--     ns:TallyAdd("weekCatch"), une fois par semaine et par compte. La plus
--     belle prise de la semaine de chaque espèce est gardée (étoiles, puis
--     indice de taille) : ns:WorldWeekBest().
--   * Effets branchés par enveloppe (rien de changé dans les modules de jeu) :
--     ns:ShinyRoll pose l'espèce tirée, ns:ShinyChance la double ;
--     ns:SpecimenAdd pose l'espèce capturée, ns:SpecimenRollSize double le
--     poids des tailles rares ; ns:CompanionCaptureBonus ajoute +0,05.
--   * Affichage : trois tuiles « Aujourd'hui en Azeroth » en tête de la page
--     Missions (JournalWindow.lua), une ligne de l'encadré de la page Créatures
--     (MenagerieCollection.lua), deux lignes du suivi (rangs 6 et 7), une ligne
--     de l'infobulle (Tooltips.lua), la tuile « Cette semaine » de la page
--     Communauté (JournalCommunity.lua).
--   * Bulle à l'entrée d'une zone à sceau : une par zone et par jour, sur le
--     créneau des astuces (catégorie des astuces ; refusée, elle attend la
--     prochaine astuce), jamais en mode discret, jamais en combat.
-- Sauvegarde : CaptureData().worldWeek = { id, paid, best = { [npc] = { stars,
-- size, zi, id } } } (compte) ; CompanionData().worldSaid = { day, zones }
-- (personnage). Les compteurs : swarmZones (ensemble des zones), weekCatch.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.WORLD_DAILY = {
	shiny = 2, sizeRare = 2, typeCapture = 0.05, weekGlitter = 10,
	brackets = { { 1, 20 }, { 20, 40 }, { 40, 60 } },
}
-- le harnais de test l'endort (les scénarios d'avant ne doivent pas voir un
-- type ou une espèce favorisés) ; world_37.lua le réveille
ns.worldDailyDormant = rawget(_G, "ADDON_TESTING") and true or nil

local FR = {
	WORLD_HEAD            = "Aujourd'hui en Azeroth",
	WORLD_TAG_SWARM       = "Pullulation du jour",
	WORLD_TAG_TYPE        = "Type de la semaine",
	WORLD_TAG_WEEK        = "Créature de la semaine",
	WORLD_SWARM_LINE      = "%s · brillantes ×%d, tailles rares ×%d",
	WORLD_SWARM_NONE      = "Pas ici",
	WORLD_SWARM_NONE_LINE = "Chaque zone de créatures a son espèce du jour : entre-y pour la voir.",
	WORLD_SWARM_TOMORROW  = "Demain : une autre espèce",
	WORLD_TYPE_LINE       = "Capture +%d %% sur %s",
	WORLD_TYPE_UNTIL      = "Jusqu'à %s",
	WORLD_TYPE_WEEK       = "Toute la semaine",
	WORLD_TYPE_ALL_beast      = "toutes les bêtes",
	WORLD_TYPE_ALL_humanoid   = "tous les humanoïdes",
	WORLD_TYPE_ALL_undead     = "tous les morts-vivants",
	WORLD_TYPE_ALL_elemental  = "tous les élémentaires",
	WORLD_TYPE_ALL_dragonkin  = "tous les draconiens",
	WORLD_TYPE_ALL_demon      = "tous les démons",
	WORLD_TYPE_ALL_giant      = "tous les géants",
	WORLD_TYPE_ALL_mechanical = "toutes les machines",
	WORLD_WD_1 = "dimanche", WORLD_WD_2 = "lundi", WORLD_WD_3 = "mardi", WORLD_WD_4 = "mercredi",
	WORLD_WD_5 = "jeudi", WORLD_WD_6 = "vendredi", WORLD_WD_7 = "samedi",
	WORLD_WEEK_LEVELS     = "Niveaux %d à %d",
	WORLD_WEEK_BEST       = "%s · ta plus belle prise : %s",
	WORLD_WEEK_NOT_YET    = "%s · pas encore capturée",
	WORLD_WEEK_REWARD     = "+%d paillettes à la première prise",
	WORLD_WEEK_PAID       = "Prise de la semaine faite",
	WORLD_WEEK_NONE       = "Aucune cette semaine",
	WORLD_CATCH           = "%s, %s (%d)",
	WORLD_STARS_1         = "%d étoile",
	WORLD_STARS_N         = "%d étoiles",
	WORLD_SOUVENIR        = "Carte souvenir",
	WORLD_NOTE            = "Le même contenu pour tous les joueurs le même jour, tiré de la date : rien ne passe par le réseau. Rien ne se rate : une autre espèce demain, une autre créature la semaine prochaine.",
	WORLD_STRIP_SWARM     = "Pullulation : %s (brillantes ×%d)",
	WORLD_GOAL_SWARM      = "Pullulation : %s",
	WORLD_GOAL_MULT       = "×%d",
	WORLD_GOAL_WEEK       = "Créature de la semaine",
	WORLD_HINT_SWARM      = "Aujourd'hui dans %s : brillantes ×%d et tailles rares ×%d pour cette espèce.",
	WORLD_HINT_WEEK       = "%s, niveaux %d à %d : +%d paillettes à la première prise de la semaine.",
	WORLD_TIP_SWARM       = "Pullulation du jour : brillantes ×%d",
	WORLD_SAY_SWARM       = "Ça grouille de %s par ici aujourd'hui ! Brillantes ×%d.",
	WORLD_MSG_WEEK        = "Créature de la semaine : %s ! +%d paillettes.",
	COM_WEEK_CATCH_TITLE  = "Prise de la semaine : %s",
	COM_WEEK_CATCH_TEXT   = "Capture-la, fais ta carte souvenir et poste-la dans captures-brillantes.",
	COM_WEEK_CATCH_MINE   = "ta prise : %s",
}
local EN = {
	WORLD_HEAD            = "Today in Azeroth",
	WORLD_TAG_SWARM       = "Swarm of the day",
	WORLD_TAG_TYPE        = "Type of the week",
	WORLD_TAG_WEEK        = "Creature of the week",
	WORLD_SWARM_LINE      = "%s · shinies ×%d, rare sizes ×%d",
	WORLD_SWARM_NONE      = "Not here",
	WORLD_SWARM_NONE_LINE = "Every creature zone has its species of the day: step in to see it.",
	WORLD_SWARM_TOMORROW  = "Tomorrow: another species",
	WORLD_TYPE_LINE       = "Capture +%d%% on %s",
	WORLD_TYPE_UNTIL      = "Until %s",
	WORLD_TYPE_WEEK       = "All week long",
	WORLD_TYPE_ALL_beast      = "all beasts",
	WORLD_TYPE_ALL_humanoid   = "all humanoids",
	WORLD_TYPE_ALL_undead     = "all undead",
	WORLD_TYPE_ALL_elemental  = "all elementals",
	WORLD_TYPE_ALL_dragonkin  = "all dragonkin",
	WORLD_TYPE_ALL_demon      = "all demons",
	WORLD_TYPE_ALL_giant      = "all giants",
	WORLD_TYPE_ALL_mechanical = "all mechanicals",
	WORLD_WD_1 = "Sunday", WORLD_WD_2 = "Monday", WORLD_WD_3 = "Tuesday", WORLD_WD_4 = "Wednesday",
	WORLD_WD_5 = "Thursday", WORLD_WD_6 = "Friday", WORLD_WD_7 = "Saturday",
	WORLD_WEEK_LEVELS     = "Levels %d to %d",
	WORLD_WEEK_BEST       = "%s · your finest catch: %s",
	WORLD_WEEK_NOT_YET    = "%s · not caught yet",
	WORLD_WEEK_REWARD     = "+%d glitter for the first catch",
	WORLD_WEEK_PAID       = "Catch of the week done",
	WORLD_WEEK_NONE       = "None this week",
	WORLD_CATCH           = "%s, %s (%d)",
	WORLD_STARS_1         = "%d star",
	WORLD_STARS_N         = "%d stars",
	WORLD_SOUVENIR        = "Souvenir card",
	WORLD_NOTE            = "The same content for every player on the same day, drawn from the date: nothing goes through the network. Nothing to miss: another species tomorrow, another creature next week.",
	WORLD_STRIP_SWARM     = "Swarm: %s (shinies ×%d)",
	WORLD_GOAL_SWARM      = "Swarm: %s",
	WORLD_GOAL_MULT       = "×%d",
	WORLD_GOAL_WEEK       = "Creature of the week",
	WORLD_HINT_SWARM      = "Today in %s: shinies ×%d and rare sizes ×%d for this species.",
	WORLD_HINT_WEEK       = "%s, levels %d to %d: +%d glitter for the first catch of the week.",
	WORLD_TIP_SWARM       = "Swarm of the day: shinies ×%d",
	WORLD_SAY_SWARM       = "There are %s everywhere around here today! Shinies ×%d.",
	WORLD_MSG_WEEK        = "Creature of the week: %s! +%d glitter.",
	COM_WEEK_CATCH_TITLE  = "Catch of the week: %s",
	COM_WEEK_CATCH_TEXT   = "Catch it, make your souvenir card and post it in captures-brillantes.",
	COM_WEEK_CATCH_MINE   = "your catch: %s",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.WORLD_DAILY_STRINGS = { fr = FR, en = EN } end

local W = ns.WORLD_DAILY
local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end

-- allumé : module du compagnon, capture, et pas endormi (harnais)
function ns:WorldDailyOn()
	if ns.worldDailyDormant then return false end
	if not (ns.CompanionOn and ns.CompanionOn()) then return false end
	return self.CaptureData ~= nil and self:DB().companionCapture ~= false
end
local function On(self) return self:WorldDailyOn() end
local function Quiet(self) return ns.Quiet ~= nil and self:Quiet() and true or false end
local function InCombat()
	local fighting = ns.companionFighting
	if fighting and ns.Now and ns.COMPANION_FIGHT_GRACE then
		local since = ns.Now() - fighting
		if since >= 0 and since < ns.COMPANION_FIGHT_GRACE then return true end
	end
	if Call(G("InCombatLockdown")) then return true end
	return Call(G("UnitAffectingCombat"), "player") and true or false
end

-- ---------------------------------------------------------------------------
-- Le tirage : une empreinte entière, calculée exactement (produits sous 2^53)
-- ---------------------------------------------------------------------------
local HASH_P = 67108859   -- premier sous 2^26 : h * h reste sous 2^52, exact en double
function ns.WorldHash(text)
	text = tostring(text)
	local h = 7
	for i = 1, #text do h = (h * 131 + text:byte(i)) % HASH_P end
	-- brassage non linéaire (carré modulo un premier) : deux clés voisines
	-- (deux jours qui se suivent) donnent des valeurs sans rapport
	for _ = 1, 3 do h = (h * h + 40503) % HASH_P end
	return h
end
local function Pick(list, key)
	if #list == 0 then return nil end
	return list[ns.WorldHash(key) % #list + 1]
end

function ns:WorldDay() return self.DailyToday and self:DailyToday() or "?" end
function ns:WorldWeek() return self.WeeklyId and self:WeeklyId() or "?" end

local function Zones() return rawget(ns, "ZONE_CREATURES") end
local function ZoneTable(zoneID)
	local all = Zones()
	if type(all) ~= "table" or zoneID == nil then return nil end
	local zone = ns.ZonePeek and ns.ZonePeek(all, zoneID) or all[zoneID]
	return type(zone) == "table" and zone or nil
end
-- une espèce que tout le monde peut voir et capturer : rang normal, hostile
-- ou neutre envers les deux factions
local function Normal(entry)
	return type(entry) == "table" and tonumber(entry.rank) == 0 and entry.f == nil
end
local function SortedNpcs(zone, keep)
	local list = {}
	for npcID, entry in pairs(zone) do
		local npc = tonumber(npcID)
		if npc and keep(entry) then list[#list + 1] = npc end
	end
	table.sort(list)
	return list
end
local function NameOf(self, entry, npc)
	local name = entry and self.BestiaryStaticName and self:BestiaryStaticName(entry)
	if (not name or name == "") and self.CreatureName then name = self:CreatureName(npc) end
	return tostring(name or npc)
end

-- ---------------------------------------------------------------------------
-- Pullulation du jour
-- ---------------------------------------------------------------------------
local swarmCache = { day = nil, zones = {} }
function ns.WorldDailyReset() swarmCache.day, swarmCache.zones = nil, {} end

-- ns:WorldSwarm(zone[, day]) -> npcID, nom, ou nil (zone sans table)
function ns:WorldSwarm(zone, day)
	local zoneID = tonumber(zone)
	if not zoneID then return nil end
	day = day or self:WorldDay()
	if swarmCache.day ~= day then swarmCache.day, swarmCache.zones = day, {} end
	local hit = swarmCache.zones[zoneID]
	if hit == nil then
		local tbl = ZoneTable(zoneID)
		hit = false
		if tbl then
			local npc = Pick(SortedNpcs(tbl, Normal), "swarm:" .. tostring(day) .. ":" .. zoneID)
			if npc then hit = { npc = npc, name = NameOf(self, tbl[npc], npc) } end
		end
		swarmCache.zones[zoneID] = hit
	end
	if not hit then return nil end
	return hit.npc, hit.name
end

-- cette espèce est-elle en pullulation dans cette zone aujourd'hui ?
function ns:WorldIsSwarm(zone, npc)
	if not On(self) then return false end
	local want = tonumber(npc)
	return want ~= nil and self:WorldSwarm(zone) == want
end

-- ---------------------------------------------------------------------------
-- Type et créature de la semaine
-- ---------------------------------------------------------------------------
function ns:WorldWeekType(week)
	local types = ns.CREATURE_TYPES or {}
	return Pick(types, "type:" .. tostring(week or self:WorldWeek()))
end

-- tranche d'un niveau (1, 2 ou 3)
function ns.WorldBracketOf(level)
	level = tonumber(level) or 1
	if level < W.brackets[2][1] then return 1 end
	if level < W.brackets[3][1] then return 2 end
	return 3
end
function ns:WorldBracket()
	return ns.WorldBracketOf(ns.Plain(Call(G("UnitLevel"), "player")))
end

local weekCache = { week = nil, picks = {} }
-- ns:WorldWeekCreature(tranche[, semaine]) -> npcID, nom, zone, bas, haut
-- Une zone d'abord (celles dont les niveaux couvrent la tranche, triées), puis
-- une espèce normale de cette zone dans la tranche ; une zone sans candidat
-- passe à la suivante. Une ou deux zones lues, pas toutes.
function ns:WorldWeekCreature(bracket, week)
	bracket = math.max(1, math.min(#W.brackets, math.floor(tonumber(bracket) or self:WorldBracket())))
	week = week or self:WorldWeek()
	if weekCache.week ~= week then weekCache.week, weekCache.picks = week, {} end
	local lo, hi = W.brackets[bracket][1], W.brackets[bracket][2]
	local hit = weekCache.picks[bracket]
	if hit == nil then
		hit = false
		local all, levels = Zones(), ns.ZONE_LEVELS or {}
		local zones = {}
		for _, zoneID in ipairs(type(all) == "table" and ns.ZoneIds and ns.ZoneIds(all) or {}) do
			local z = tonumber(zoneID)
			local range = z and levels[z]
			if range and tonumber(range[1]) <= hi and tonumber(range[2]) >= lo then zones[#zones + 1] = z end
		end
		table.sort(zones)
		local n = #zones
		if n > 0 then
			local start = ns.WorldHash("weekzone:" .. tostring(week) .. ":" .. bracket) % n
			for k = 0, n - 1 do
				local zoneID = zones[(start + k) % n + 1]
				local tbl = ZoneTable(zoneID)
				if tbl then
					local list = SortedNpcs(tbl, function(entry)
						if not Normal(entry) or type(entry.lvl) ~= "table" then return false end
						local a, b = tonumber(entry.lvl[1]), tonumber(entry.lvl[2]) or tonumber(entry.lvl[1])
						return a ~= nil and b ~= nil and a >= lo and b <= hi
					end)
					local npc = Pick(list, "week:" .. tostring(week) .. ":" .. bracket .. ":" .. zoneID)
					if npc then
						hit = { npc = npc, name = NameOf(self, tbl[npc], npc), zone = zoneID }
						break
					end
				end
			end
		end
		weekCache.picks[bracket] = hit
	end
	if not hit then return nil end
	return hit.npc, hit.name, hit.zone, lo, hi
end

-- l'espèce fait-elle partie des créatures de la semaine ? (tranche ou nil)
function ns:WorldIsWeekCreature(npc)
	local want = tonumber(npc)
	if not want then return nil end
	for bracket = 1, #W.brackets do
		if self:WorldWeekCreature(bracket) == want then return bracket end
	end
	return nil
end

-- la semaine au compte (avec les captures)
function ns:WorldWeekRecord()
	local capture = self:CaptureData()
	local week = self:WorldWeek()
	local rec = capture.worldWeek
	if type(rec) ~= "table" or rec.id ~= week then
		rec = { id = week, best = {} }
		capture.worldWeek = rec
	end
	if type(rec.best) ~= "table" then rec.best = {} end
	return rec
end

-- ns:WorldWeekBest([npc]) -> { stars, size, zi, id } ou nil (par défaut :
-- la créature de la semaine de la tranche du personnage)
function ns:WorldWeekBest(npc)
	if not self.CaptureData then return nil end
	npc = tonumber(npc) or self:WorldWeekCreature(self:WorldBracket())
	if not npc then return nil end
	return self:WorldWeekRecord().best[npc]
end

function ns:WorldStarsText(stars)
	stars = math.floor(tonumber(stars) or 1)
	return self:F(stars == 1 and "WORLD_STARS_1" or "WORLD_STARS_N", stars)
end
-- « 2 étoiles, Grand (112) »
function ns:WorldCatchText(best)
	if type(best) ~= "table" then return nil end
	local size = self.SpecimenSizeLabel and self:SpecimenSizeLabel(best.size) or tostring(best.size or "")
	return self:F("WORLD_CATCH", self:WorldStarsText(best.stars), size, tonumber(best.zi) or 100)
end

-- ---------------------------------------------------------------------------
-- Les effets de jeu (enveloppes)
-- ---------------------------------------------------------------------------
-- Brillantes ×2 : le tirage (ShinyRoll) dit quelle espèce, où ; la chance
-- (ShinyChance) double pour elle seulement
do
	local roll = ns.ShinyRoll
	if roll then
		function ns:ShinyRoll(unit, entry, ...)
			local before = self.worldShinyFor
			self.worldShinyFor = type(entry) == "table" and entry or nil
			local ok, result = pcall(roll, self, unit, entry, ...)
			self.worldShinyFor = before
			if not ok then error(result, 0) end
			return result
		end
	end
	local chance = ns.ShinyChance
	if chance then
		function ns:ShinyChance(...)
			local value = chance(self, ...)
			local entry = self.worldShinyFor
			if type(value) == "number" and entry and self:WorldIsSwarm(entry.zoneID, entry.npcID) then
				value = value * W.shiny
			end
			return value
		end
	end
end

-- Tailles rares ×2 : le spécimen capturé (SpecimenAdd) dit quelle espèce,
-- où ; le tirage de la taille double le poids des tailles rares pour elle
function ns.WorldRollSize(mult)
	local by, ids = ns.SPECIMEN_SIZE_BY_ID or {}, ns.SPECIMEN_SIZE_ROLL or {}
	local function Weight(id)
		local def = by[id]
		if not def then return 0 end
		return (tonumber(def.weight) or 0) * (def.rare and mult or 1)
	end
	local total = 0
	for _, id in ipairs(ids) do total = total + Weight(id) end
	local roll = math.random() * total
	for _, id in ipairs(ids) do
		roll = roll - Weight(id)
		if roll < 0 then return id end
	end
	return ids[#ids]
end
do
	local add = ns.SpecimenAdd
	if add then
		function ns:SpecimenAdd(spec, ...)
			local before = self.worldSizeFor
			local capture = type(spec) == "table" and (spec.origin == nil or spec.origin == "capture")
			self.worldSizeFor = capture and spec or nil
			local ok, a, b, c = pcall(add, self, spec, ...)
			self.worldSizeFor = before
			if not ok then error(a, 0) end
			return a, b, c
		end
	end
	local size = ns.SpecimenRollSize
	if size then
		function ns:SpecimenRollSize(...)
			local spec = self.worldSizeFor
			if spec and self:WorldIsSwarm(spec.zone, spec.npc) then return ns.WorldRollSize(W.sizeRare) end
			return size(self, ...)
		end
	end
end

-- Capture +5 % pour le type de la semaine : ajouté aux bonus du compagnon
-- (CompanionEffects.lua l'applique et borne au plafond CAPTURE_MAX)
do
	local bonus = ns.CompanionCaptureBonus
	if bonus then
		function ns:CompanionCaptureBonus(info, ...)
			local value = tonumber(bonus(self, info, ...)) or 0
			if type(info) == "table" and On(self) then
				local key = info.typeKey or (self.CreatureTypeKey and self:CreatureTypeKey(info.type))
				if key and key == self:WorldWeekType() then value = value + W.typeCapture end
			end
			return value
		end
	end
end

-- ---------------------------------------------------------------------------
-- Une capture : pullulation (compteur), créature de la semaine (paillettes,
-- compteur, plus belle prise)
-- ---------------------------------------------------------------------------
local function Better(a, b)
	if not b then return true end
	local sa, sb = tonumber(a.stars) or 0, tonumber(b.stars) or 0
	if sa ~= sb then return sa > sb end
	return (tonumber(a.zi) or 0) > (tonumber(b.zi) or 0)
end

function ns:WorldOnSpecimen(spec)
	if type(spec) ~= "table" or spec.origin ~= "capture" or not On(self) then return nil end
	local npc = tonumber(spec.npc)
	local zone = tonumber(spec.zone)
	local result = {}
	if zone and self:WorldIsSwarm(zone, npc) then
		if self.TallyMark then self:TallyMark("swarmZones", zone) end
		result.swarm = zone
	end
	if npc and self:WorldIsWeekCreature(npc) then
		local rec = self:WorldWeekRecord()
		local zi = self.SpecimenSizeIndex and self:SpecimenSizeIndex(spec) or tonumber(spec.zi) or 100
		local mine = { stars = tonumber(spec.stars) or 1, size = spec.size or "normal", zi = zi, id = spec.id, shiny = spec.shiny or nil }
		if Better(mine, rec.best[npc]) then rec.best[npc] = mine end
		result.week = npc
		if not rec.paid then
			rec.paid = true
			if self.PaillettesAdd then self:PaillettesAdd(W.weekGlitter, "week") end
			if self.TallyAdd then self:TallyAdd("weekCatch") end
			result.paid = W.weekGlitter
			if not Quiet(self) then
				local name = self.CreatureName and self:CreatureName(npc) or tostring(npc)
				self:Print(self:F("WORLD_MSG_WEEK", name, W.weekGlitter))
			end
		end
		if self.RefreshJournalTracker then pcall(self.RefreshJournalTracker, self) end
	end
	return result
end

if ns.RegisterCallback then
	ns:RegisterCallback("SPECIMENS", function(self, what, id)
		if what ~= "add" or not self.SpecimenGet then return end
		local spec = self:SpecimenGet(id)
		if spec then self:WorldOnSpecimen(spec) end
	end)
end

-- ---------------------------------------------------------------------------
-- Textes : encadré de la page Créatures, infobulle
-- ---------------------------------------------------------------------------
function ns:WorldSwarmStripText(zone)
	if not On(self) then return nil end
	local npc, name = self:WorldSwarm(zone)
	if not npc then return nil end
	return self:F("WORLD_STRIP_SWARM", name, W.shiny)
end

-- infobulle d'une créature : « Pullulation du jour : brillantes ×2 » pour
-- l'espèce en pullulation de la zone où l'on est (rien de plus lu du jeu que
-- les lignes d'avant : le GUID survolé, la zone)
function ns:WorldSwarmTooltip(guid)
	if not On(self) then return nil end
	local npc = ns.BestiaryNpcID and ns.BestiaryNpcID(guid)
	local zone = npc and self.JournalZone and self:JournalZone()
	if not zone or not self:WorldIsSwarm(zone, npc) then return nil end
	return self:F("WORLD_TIP_SWARM", W.shiny)
end

-- ---------------------------------------------------------------------------
-- Suivi : deux lignes aux derniers rangs (la limite de quatre ne change pas)
-- ---------------------------------------------------------------------------
if ns.TRACKER_GOAL_RANKS then
	ns.TRACKER_GOAL_RANKS.swarm = 6
	ns.TRACKER_GOAL_RANKS.week = 7
end
local function SwarmGoal(self, list)
	if not (On(self) and ns.JournalGoal and self.JournalZone) then return end
	local zoneID, zoneName = self:JournalZone()
	local npc, name = self:WorldSwarm(zoneID)
	if not npc then return end
	local label = self:F("WORLD_GOAL_SWARM", name)
	local goal = ns.JournalGoal("swarm:" .. self:WorldDay() .. ":" .. zoneID, label, 0, 1, nil, "menagerie")
	if not goal then return end
	goal.rank, goal.short, goal.brief = ns.TRACKER_GOAL_RANKS.swarm, label, label
	goal.progress = self:F("WORLD_GOAL_MULT", W.shiny)
	goal.hint = { self:F("WORLD_HINT_SWARM", tostring(zoneName or zoneID), W.shiny, W.sizeRare) }
	goal.onClick = function() return ns.OpenMenagerieSpecies and ns:OpenMenagerieSpecies(npc) end
	list[#list + 1] = goal
end
local function WeekGoal(self, list)
	if not (On(self) and ns.JournalGoal) then return end
	local npc, name, _, lo, hi = self:WorldWeekCreature(self:WorldBracket())
	if not npc or self:WorldWeekRecord().paid then return end
	local goal = ns.JournalGoal("week:" .. self:WorldWeek(), L.WORLD_GOAL_WEEK, 0, 1, nil, "menagerie")
	if not goal then return end
	goal.rank, goal.short = ns.TRACKER_GOAL_RANKS.week, goal.label
	goal.hint = { self:F("WORLD_HINT_WEEK", name, lo, hi, W.weekGlitter) }
	goal.reward = self:F("MIS_REWARD_PAILLETTES", W.weekGlitter)
	goal.onClick = function() return ns.OpenMenagerieSpecies and ns:OpenMenagerieSpecies(npc) end
	list[#list + 1] = goal
end
if ns.RegisterGoalSource then
	ns.RegisterGoalSource(SwarmGoal)
	ns.RegisterGoalSource(WeekGoal)
end

-- ---------------------------------------------------------------------------
-- Bulle à l'entrée d'une zone à sceau : une par zone et par jour, sur le
-- créneau des astuces
-- ---------------------------------------------------------------------------
local function SaidToday(self)
	local data = self:CompanionData()
	local day = self:WorldDay()
	local said = data.worldSaid
	if type(said) ~= "table" or said.day ~= day then
		said = { day = day, zones = {} }
		data.worldSaid = said
	end
	if type(said.zones) ~= "table" then said.zones = {} end
	return said
end

-- rend vrai si la bulle est dite
function ns:WorldSwarmAnnounce()
	if not On(self) or Quiet(self) or InCombat() then return false end
	if not self.JournalZone then return false end
	local zoneID = self:JournalZone()
	local npc, name = self:WorldSwarm(zoneID)
	if not npc then return false end
	local said = SaidToday(self)
	if said.zones[zoneID] then return false end
	if self.CompanionChatterLevel and self:CompanionChatterLevel() < 3 then return false end
	if not self:CompanionSay("TIP", { line = "WORLD_SAY_SWARM", args = { name, W.shiny } }) then return false end
	said.zones[zoneID] = true
	return true
end

do
	local onZone = ns.CompanionOnZone
	if onZone then
		function ns:CompanionOnZone(newArea, ...)
			local a, b = onZone(self, newArea, ...)
			if newArea then
				local ok, err = pcall(self.WorldSwarmAnnounce, self)
				if not ok and self.RecordError then self:RecordError("world:announce", err) end
			end
			return a, b
		end
	end
	-- refusée à l'entrée (une autre bulle, l'écart des bulles) : elle prend la
	-- prochaine astuce
	local tryTip = ns.CompanionTryTip
	if tryTip then
		function ns:CompanionTryTip(...)
			local ok, said = pcall(self.WorldSwarmAnnounce, self)
			if ok and said then return true end
			return tryTip(self, ...)
		end
	end
end

-- ---------------------------------------------------------------------------
-- « Aujourd'hui en Azeroth » : trois tuiles en tête de la page Missions
-- (JournalWindow.lua, BuildDay / RefreshDay / LayoutDay)
-- ---------------------------------------------------------------------------
-- cotes de la maquette (y depuis le haut de l'encart) ; restY : où le reste
-- de la page reprend
ns.WORLD_TODAY_LAYOUT = { tileY = 20, tileW = 226, tileH = 118, tileStep = 242, pad = 10, tagY = 9, nameY = 32,
	lineY = 50, extraY = 96, buttonY = 86, buttonW = 120, noteY = 148, restY = 196 }
local K = ns.WORLD_TODAY_LAYOUT
local TILES = { "swarm", "type", "week" }

function ns:WorldTodayBuild(pane)
	local ui = ns.JournalUI
	if not (ui and pane) then return nil end
	local box = { tiles = {}, texts = {} }
	box.head = Theme.CreateSection(pane, L.WORLD_HEAD)
	box.head:SetWidth(ui.INNER)
	local inner = K.tileW - 2 * K.pad
	for index, id in ipairs(TILES) do
		local tile = Theme.CreateTile(pane, K.tileW, K.tileH, { kind = "Frame" })
		tile.id = id
		tile.tag = Theme.CreateTag(tile, L["WORLD_TAG_" .. id:upper()])
		tile.tag:SetPoint("TOPLEFT", tile, "TOPLEFT", K.pad, -K.tagY)
		tile.name = ui.Text(tile, Theme.F_LABEL, Theme.PARCHMENT, inner)
		tile.name:SetPoint("TOPLEFT", tile, "TOPLEFT", K.pad, -K.nameY)
		if tile.name.SetWordWrap then tile.name:SetWordWrap(false) end
		tile.line = ui.Text(tile, Theme.F_SMALL, Theme.MUTED_LIGHT, inner)
		tile.line:SetPoint("TOPLEFT", tile, "TOPLEFT", K.pad, -K.lineY)
		if tile.line.SetWordWrap then tile.line:SetWordWrap(true) end
		if tile.line.SetMaxLines then pcall(tile.line.SetMaxLines, tile.line, 3) end
		tile.extra = ui.Text(tile, Theme.F_SMALL, Theme.MUTED, inner)
		tile.extra:SetPoint("TOPLEFT", tile, "TOPLEFT", K.pad, -K.extraY)
		if tile.extra.SetWordWrap then tile.extra:SetWordWrap(false) end
		box.texts[#box.texts + 1] = { tile.name, Theme.PARCHMENT, 3 }
		box.texts[#box.texts + 1] = { tile.line, Theme.MUTED_LIGHT, 4.5 }
		box.texts[#box.texts + 1] = { tile.extra, Theme.MUTED, 4.5 }
		box.tiles[index], box.tiles[id] = tile, tile
	end
	local week = box.tiles.week
	week.button = Theme.CreateButton(week, K.buttonW, "sm", L.WORLD_SOUVENIR, function()
		local best = ns:WorldWeekBest()
		if ns.SouvenirShow and best then ns:SouvenirShow(best.id) end
	end)
	week.button:SetPoint("TOPLEFT", week, "TOPLEFT", K.pad, -K.buttonY)
	week.button:Hide()
	box.note = ui.Text(pane, Theme.F_SMALL, Theme.MUTED, ui.INNER)
	if box.note.SetWordWrap then box.note:SetWordWrap(true) end
	box.texts[#box.texts + 1] = { box.note, Theme.MUTED, 4.5 }
	pane.world = box
	return box
end

-- « Jusqu'à mardi » : le jour de la remise à zéro de la semaine
function ns:WorldWeekEndText()
	local left = self.WeeklyResetIn and self:WeeklyResetIn()
	local now = tonumber(Call(G("time")))
	local date = G("date") or (os and os.date)
	if left and left > 0 and now then
		local t = Call(date, "*t", now + left)
		local wday = type(t) == "table" and tonumber(t.wday)
		if wday and L["WORLD_WD_" .. wday] then return self:F("WORLD_TYPE_UNTIL", L["WORLD_WD_" .. wday]) end
	end
	return L.WORLD_TYPE_WEEK
end

local function Show(region, on) if on then region:Show() else region:Hide() end end

-- remplit les tuiles ; rend vrai si l'encart est affiché
function ns:WorldTodayPaint(pane)
	local box = pane and pane.world
	if not box then return false end
	local on = On(self)
	box.shown = on
	Show(box.head, on)
	Show(box.note, on)
	for _, tile in ipairs(box.tiles) do Show(tile, on) end
	if not on then return false end
	-- pullulation de la zone où l'on est
	local swarm = box.tiles.swarm
	local zoneID, zoneName = nil, nil
	if self.JournalZone then zoneID, zoneName = self:JournalZone() end
	local npc, name = self:WorldSwarm(zoneID)
	if npc then
		swarm.name:SetText(name)
		swarm.line:SetText(self:F("WORLD_SWARM_LINE", tostring(zoneName or zoneID), W.shiny, W.sizeRare))
	else
		swarm.name:SetText(L.WORLD_SWARM_NONE)
		swarm.line:SetText(L.WORLD_SWARM_NONE_LINE)
	end
	swarm.extra:SetText(L.WORLD_SWARM_TOMORROW)
	-- type de la semaine
	local kind = box.tiles.type
	local typeKey = self:WorldWeekType()
	kind.name:SetText(L["MMIS_MANY_" .. tostring(typeKey)] or (self.CreatureTypeLabel and self:CreatureTypeLabel(typeKey)) or "")
	kind.line:SetText(self:F("WORLD_TYPE_LINE", math.floor(W.typeCapture * 100 + 0.5), L["WORLD_TYPE_ALL_" .. tostring(typeKey)] or ""))
	kind.extra:SetText(self:WorldWeekEndText())
	-- créature de la semaine (tranche du personnage)
	local week = box.tiles.week
	local wnpc, wname, _, lo, hi = self:WorldWeekCreature(self:WorldBracket())
	local best = wnpc and self:WorldWeekBest(wnpc) or nil
	if wnpc then
		week.name:SetText(wname)
		local levels = self:F("WORLD_WEEK_LEVELS", lo, hi)
		week.line:SetText(best and self:F("WORLD_WEEK_BEST", levels, self:WorldCatchText(best)) or self:F("WORLD_WEEK_NOT_YET", levels))
	else
		week.name:SetText(L.WORLD_WEEK_NONE)
		week.line:SetText("")
	end
	local souvenir = best ~= nil and ns.SouvenirShow ~= nil
	Show(week.button, souvenir)
	week.extra:ClearAllPoints()
	if souvenir then
		week.extra:SetPoint("TOPRIGHT", week, "TOPRIGHT", -K.pad, -(K.buttonY + 5))
		week.extra:SetJustifyH("RIGHT")
		week.extra:SetWidth(K.tileW - 3 * K.pad - K.buttonW)
	else
		week.extra:SetPoint("TOPLEFT", week, "TOPLEFT", K.pad, -K.extraY)
		week.extra:SetJustifyH("LEFT")
		week.extra:SetWidth(K.tileW - 2 * K.pad)
	end
	local rec = self:WorldWeekRecord()
	week.extra:SetText(wnpc and (rec.paid and L.WORLD_WEEK_PAID or self:F("WORLD_WEEK_REWARD", W.weekGlitter)) or "")
	box.note:SetText(L.WORLD_NOTE)
	return true
end

-- place l'encart à partir de y (cotes de la page) ; rend le y où le reste reprend
function ns:WorldTodayPlace(pane, content, y)
	local box = pane and pane.world
	if not (box and box.shown) then return y end
	local ui = ns.JournalUI
	ui.At(box.head, content, 0, y)
	for index, tile in ipairs(box.tiles) do ui.At(tile, content, (index - 1) * K.tileStep, y - K.tileY) end
	ui.At(box.note, content, 0, y - K.noteY)
	return y - K.restY
end

if ns.Mark then ns.Mark("WorldDaily") end
