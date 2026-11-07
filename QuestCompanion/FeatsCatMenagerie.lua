-- FeatsCatMenagerie.lua -- hauts faits, lot B (2.7.0) : Ménagerie, Brillantes,
-- Zones et sceaux, Au jour le jour, Guilde et entraide, Insolite (ce qui se lit
-- dans la ménagerie, le compagnon et le carnet) et les grands hauts faits qui
-- en dépendent. Catalogue : docs/QC-HAUTS-FAITS.md §2.1 à §2.5, §2.10, §2.11.
--
-- Chargé juste après FeatsData.lua (donc avant Feats.lua) : on remplit
-- ns.FEAT_SOURCES / ns.FEAT_LISTS (Feats.lua les reprend tels quels) et on
-- enveloppe les fonctions des modules déjà chargés (captures, brillantes,
-- compagnon, fiche de dresseur, exploits de guilde). Les enveloppes ne font
-- rien tant que le moteur dort (ns.featsDormant, harnais de tests).
--
-- Portée : Ménagerie, Brillantes, Guilde, Insolite et grands hauts faits =
-- compte (union des captures et brillantes de tous les personnages) ; Zones
-- et Au jour le jour = personnage.
--
-- Récompenses déplacées (une seule source) :
--   * paliers d'espèces (ex-TRAINER_RANKS) : aides et cosmétique donnés par
--     men_species_<n> ; MenagerieRankCheck note toujours le palier (date,
--     annonce de guilde) mais ne donne plus rien quand le haut fait existe
--     (ns:FeatLegacyHandled). Pas de double don : un palier noté avant la
--     2.7 (collection.ranks sans collection.featRanks) vaut « déjà payé »
--     (def.paid) : le haut fait ne redonne pas les aides (le cosmétique est
--     idempotent) ;
--   * paliers de brillantes (ex-SHINY_REWARDS) : shiny_found_<n> ;
--     ShinyCheckRewards ne débloque plus rien quand le haut fait existe
--     (cosmétiques idempotents : rien de perdu ni de doublé).
-- Cosmétiques pas encore fabriqués (lot E) : reward.soon = { sorte, id } ;
-- ils passent en reward.cosmetic dès que le catalogue du compagnon les a.
local ADDON, ns = ...
if ns.blocked then return end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function Time() return tonumber(Call(G("time"))) or 0 end
local function Awake() return not ns.featsDormant end
local function Lower(text)
	if ns.Plain then text = ns.Plain(text) end
	if type(text) ~= "string" then return "" end
	return ns.AsciiLower and ns.AsciiLower(text) or text:lower()
end

ns.FEAT_SOURCES = ns.FEAT_SOURCES or {}
ns.FEAT_LISTS = ns.FEAT_LISTS or {}
local SOURCES, LISTS = ns.FEAT_SOURCES, ns.FEAT_LISTS

-- Le haut fait prend-il le relais d'une ancienne récompense ? (moteur
-- éveillé et ligne au catalogue ; sinon l'ancien système paie, comme avant)
function ns:FeatLegacyHandled(id)
	return not ns.featsDormant and type(self.FeatDef) == "function" and self:FeatDef(id) ~= nil
end

-- ---------------------------------------------------------------------------
-- Données du compte : chaque compagnon de la sauvegarde
-- ---------------------------------------------------------------------------
local function EachCompanion(self, fn)
	local db = self:DB()
	if type(db.chars) ~= "table" then return end
	for key, char in pairs(db.chars) do
		if type(char) == "table" and type(char.companion) == "table" then fn(char.companion, key, char) end
	end
end

local function Sub(t, key) return type(t) == "table" and type(t[key]) == "table" and t[key] or nil end
local function Keys(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end

-- Relevé groupé des captures et brillantes du compte, refait seulement quand
-- une capture, une recapture ou une brillante a bougé (signature)
local NAMED = { elite = true, rare = true, rareelite = true, worldboss = true }
local CRITTER = { trivial = true, minus = true }
local CRITTER_TYPE = { critter = true, bestiole = true }
ns.FEAT_HOGGER = 448
local scan, scanKey, bump = nil, nil, 0

local function Signature(self)
	local parts = {}
	EachCompanion(self, function(data, key)
		local c, s = Sub(data, "capture") or {}, Sub(data, "shiny") or {}
		parts[#parts + 1] = table.concat({ tostring(key), tostring(c.serial), tostring(c.count), tostring(s.count) }, ":")
	end)
	table.sort(parts)
	return table.concat(parts, "|") .. "#" .. bump
end

-- Types appris au bestiaire de ce personnage (fiche sans type)
local function TypeIndex(self)
	local index = {}
	for _, zone in pairs(self.BestiaryData and self:BestiaryData() or {}) do
		if type(zone) == "table" then
			for npcID, species in pairs(zone) do
				if type(species) == "table" and species.type then index[tonumber(npcID) or npcID] = species.type end
			end
		end
	end
	return index
end

local function Scan(self)
	local key = Signature(self)
	if scan and scanKey == key then return scan end
	local npcs, seen, zones, found = {}, {}, {}, 0
	local mine = self:CompanionData()
	local index
	EachCompanion(self, function(data)
		for npcID, e in pairs(Sub(Sub(data, "capture"), "creatures") or {}) do
			if type(e) == "table" then
				local id = tonumber(npcID) or npcID
				local m = npcs[id] or {}
				npcs[id] = m
				local class = e.class
				if class == "elite" then m.elite = true end
				if class == "rare" or class == "rareelite" then m.rare = true end
				if class == "worldboss" then m.boss = true end
				if e.normal ~= false and tonumber(e.stars) == 3 then m.s3 = true end
				if e.shiny then
					if tonumber(e.shinyStars) == 3 then m.sh3 = true end
					if NAMED[class or ""] then m.shNamed = true end
				end
				if Lower(e.name):find("murloc", 1, true) then m.murloc = true end
				if CRITTER[class or ""] or CRITTER_TYPE[Lower(e.type)] then m.critter = true end
				local text = e.type
				if not text and data == mine then
					index = index or TypeIndex(self)
					text = index[id]
				end
				local typeKey = self.CreatureTypeKey and self:CreatureTypeKey(text)
				if typeKey then m.type = typeKey end
			end
		end
		local shiny = Sub(data, "shiny")
		if shiny then
			found = found + math.max(0, math.floor(tonumber(shiny.count) or 0))
			for npcID in pairs(Sub(shiny, "seen") or {}) do seen[tonumber(npcID) or npcID] = true end
			for zoneID in pairs(Sub(shiny, "zones") or {}) do zones[tonumber(zoneID) or zoneID] = true end
		end
	end)
	local s = { elite = 0, rare = 0, boss = 0, stars3 = 0, shiny3 = 0, shinyNamed = 0, murlocs = 0, critter = 0,
		hogger = 0, types = {}, shinyFound = found, shinySeen = Keys(seen), shinyZones = Keys(zones) }
	local FIELDS = { elite = "elite", rare = "rare", boss = "boss", s3 = "stars3", sh3 = "shiny3", shNamed = "shinyNamed",
		murloc = "murlocs", critter = "critter" }
	for id, m in pairs(npcs) do
		for flag, field in pairs(FIELDS) do if m[flag] then s[field] = s[field] + 1 end end
		if m.type then s.types[m.type] = (s.types[m.type] or 0) + 1 end
		if id == ns.FEAT_HOGGER then s.hogger = 1 end
	end
	scan, scanKey = s, key
	return s
end
function ns:FeatMenagerieScan() return Scan(self) end
function ns:FeatMenagerieScanReset() scan, scanKey = nil, nil end

local CAP, SHINY = ns.FeatTopics("capture", "seal"), ns.FeatTopics("shiny", "capture")
local function ScanSource(field, topics)
	return { topics = topics or CAP, get = function(self) return Scan(self)[field] or 0 end }
end

-- Sources et listes : posées à la première lecture du catalogue (ou d'une
-- source absente, métatable de FEAT_SOURCES : FeatsData.lua)
ns.FeatCatalog(function()
	-- Ménagerie
	for _, field in ipairs({ "elite", "rare", "boss", "stars3", "murlocs", "critter", "hogger" }) do
		SOURCES[field] = ScanSource(field)
	end
	for _, typeKey in ipairs(ns.CREATURE_TYPES or {}) do
		SOURCES["type_" .. typeKey] = { topics = CAP,
			get = function(self) return Scan(self).types[typeKey] or 0 end }
	end
	-- types au palier 1 (au moins le premier seuil, union du compte)
	SOURCES.typesTier1 = { topics = CAP, get = function(self)
		local types, n = Scan(self).types, 0
		for _, typeKey in ipairs(ns.CREATURE_TYPES or {}) do
			local need = self.MenagerieTypeTiers and self:MenagerieTypeTiers(typeKey)[1] or 10
			if (types[typeKey] or 0) >= need then n = n + 1 end
		end
		return n
	end }
	-- Brillantes
	SOURCES.shinySeen = ScanSource("shinySeen", SHINY)
	SOURCES.shinyFound = ScanSource("shinyFound", SHINY)
	SOURCES.shinyNamed = ScanSource("shinyNamed", SHINY)
	SOURCES.shiny3 = ScanSource("shiny3", SHINY)
	SOURCES.shinyZones = ScanSource("shinyZones", SHINY)

	-- Compagnons emmenés (effet actif) : types vus, compte
	SOURCES.companionTypes = { topics = ns.FeatTopics("companion"),
		get = function(self) return Keys(self:FeatStore("account").ctypes) end }
end)

-- ---------------------------------------------------------------------------
-- Zones et sceaux (personnage)
-- ---------------------------------------------------------------------------
-- Continent d'une zone extérieure : la table des biomes (MenagerieCollection)
-- range Kalimdor en 1411-1413 et 1438-1452, les Royaumes de l'Est en
-- 1416-1437 ; une autre zone : la carte du client
local function Continent(self, zoneID)
	local z = tonumber(zoneID)
	if not z then return nil end
	if z == 1411 or z == 1412 or z == 1413 or (z >= 1438 and z <= 1452) then return "ka" end
	if z >= 1416 and z <= 1437 then return "ek" end
	return self.JournalContinentOf and Call(self.JournalContinentOf, self, z) or nil
end
ns.FeatContinent = Continent

-- Zones d'un continent (sealable : avec une liste d'espèces, donc un sceau)
local contCache = {}
local function ContinentZones(self, cont, sealable)
	local key = cont .. (sealable and ":s" or "")
	if contCache[key] then return contCache[key] end
	local has
	if sealable and type(ns.ZONE_CREATURES) == "table" and ns.ZoneIds then
		has = {}
		for _, z in ipairs(ns.ZoneIds(ns.ZONE_CREATURES)) do has[tonumber(z) or z] = true end
	end
	local list = {}
	for z in pairs(ns.MENAGERIE_ZONE_BIOME or {}) do
		if Continent(self, z) == cont and (not has or has[z]) then list[#list + 1] = z end
	end
	table.sort(list)
	contCache[key] = list
	return list
end
ns.FeatContinentZones = ContinentZones

local function Seals(self) return self.MenagerieCollectionData and self:MenagerieCollectionData().seals or {} end
local function Milestones(self) return Sub(self:CompanionData(), "milestones") or {} end

local function SealsIn(cont)
	return { topics = ns.FeatTopics("seal", "capture"), get = function(self)
		local seals, n = Seals(self), 0
		for _, z in ipairs(ContinentZones(self, cont, true)) do if seals[z] ~= nil then n = n + 1 end end
		return n
	end }
end
local function DoneIn(cont)
	return { topics = ns.FeatTopics("zone"), get = function(self)
		local marks, n = Milestones(self), 0
		for _, z in ipairs(ContinentZones(self, cont)) do if (tonumber(marks[z]) or 0) >= 100 then n = n + 1 end end
		return n
	end }
end
ns.FeatCatalog(function()
	SOURCES.sealsEk, SOURCES.sealsKa = SealsIn("ek"), SealsIn("ka")
	SOURCES.zones100Ek, SOURCES.zones100Ka = DoneIn("ek"), DoneIn("ka")
end)
-- Liste « toutes les zones » d'un continent : élément i = la source ≥ i
-- (barre x/y sans une source par zone)
local function Ladder(source, cont, sealable)
	return { topics = SOURCES[source].topics, items = function(self)
		local items = {}
		for i = 1, #ContinentZones(self, cont, sealable) do items[i] = { source, i } end
		return items
	end }
end
ns.FeatCatalog(function()
	LISTS.sealsEk, LISTS.sealsKa = Ladder("sealsEk", "ek", true), Ladder("sealsKa", "ka", true)
	LISTS.zones100Ek, LISTS.zones100Ka = Ladder("zones100Ek", "ek"), Ladder("zones100Ka", "ka")
end)

ns.FeatCatalog(function()
	SOURCES.biomesSealed = { topics = ns.FeatTopics("seal", "capture"), get = function(self)
		local n = 0
		for _, biome in ipairs(ns.MENAGERIE_BIOMES or {}) do
			if self.MenagerieBiomeSeals and self:MenagerieBiomeSeals(biome) >= 1 then n = n + 1 end
		end
		return n
	end }
	-- zones à 100 % (le palier 100 des friandises : au moins deux parts)
	SOURCES.zones100 = { topics = ns.FeatTopics("zone"), get = function(self)
		local n = 0
		for _, mark in pairs(Milestones(self)) do if (tonumber(mark) or 0) >= 100 then n = n + 1 end end
		return n
	end }
	SOURCES.milestones = { topics = ns.FeatTopics("zone"), get = function(self)
		local n = 0
		for _, mark in pairs(Milestones(self)) do n = n + math.floor((tonumber(mark) or 0) / 25) end
		return n
	end }
	local function Chests(golden)
		return { topics = ns.FeatTopics("zone"), get = function(self)
			local n = 0
			for _, chest in pairs(self.ChestData and self:ChestData() or {}) do
				if type(chest) == "table" and chest.opened and ((chest.golden and true or false) == golden) then n = n + 1 end
			end
			return n
		end }
	end
	SOURCES.golden, SOURCES.chests = Chests(true), Chests(false)
end)

-- Zones propres à Forever (uiMapID relevés en jeu, C_Map.GetMapInfo) : Mont
-- Hyjal 2482, Riverglades 2548 (données de zone de l'addon), Shen'dralas 2652 ;
-- zones extérieures : ZONE_LEVELS plus celles-ci
ns.FEAT_FOREVER_ZONES = { 2482, 2548, 2652 }
ns.FeatCatalog(function()
	LISTS.foreverZones = { topics = ns.FeatTopics("place"), items = function()
		local items = {}
		for i, z in ipairs(ns.FEAT_FOREVER_ZONES) do items[i] = "zone:" .. z end
		return items
	end }
	LISTS.outdoorZones = { topics = ns.FeatTopics("place"), items = function()
		local items, seen = {}, {}
		for _, z in ipairs(ns.ZoneIds and ns.ZoneIds(ns.ZONE_LEVELS) or {}) do
			if tonumber(z) and not seen[tonumber(z)] then seen[tonumber(z)] = true; items[#items + 1] = "zone:" .. tonumber(z) end
		end
		for _, z in ipairs(ns.FEAT_FOREVER_ZONES) do items[#items + 1] = "zone:" .. z end
		table.sort(items)
		return items
	end }
end)

-- Deux continents le même jour : relevé du jour en cours (changement de
-- zone) ou, pour la migration, les relevés « zone » datés du carnet
local function Day(at)
	local text = Call(G("date"), "%Y%m%d", at)
	if type(text) == "string" and text:find("^%d%d%d%d%d%d%d%d$") then return text end
	return tostring(math.floor((tonumber(at) or 0) / 86400))
end
ns.FeatCatalog(function()
	SOURCES.twoContinents = { topics = ns.FeatTopics("zone", "place"), get = function(self)
		if self:FeatStore("char").flag.twoCont then return 1 end
		local journal = Sub(self:CharData(), "journal")
		local days = {}
		for id, stamp in pairs(Sub(journal, "stamps") or {}) do
			local z = tostring(id):match("^zone:(%d+)$")
			local at = type(stamp) == "table" and tonumber(stamp.at)
			local cont = z and at and at > 0 and Continent(self, z)
			if cont == "ek" or cont == "ka" then
				local d = Day(at)
				days[d] = days[d] or {}
				days[d][cont] = true
				if days[d].ek and days[d].ka then return 1 end
			end
		end
		return 0
	end }
end)

function ns:FeatNoteContinent(zoneID)
	if not Awake() then return nil end
	local cont = Continent(self, zoneID or (self.JournalZone and self:JournalZone()))
	if cont ~= "ek" and cont ~= "ka" then return nil end
	local store = self:FeatStore("char")
	local today = Day(Time())
	local seen = type(store.contDay) == "table" and store.contDay.d == today and store.contDay or { d = today }
	seen[cont] = true
	store.contDay = seen
	if seen.ek and seen.ka then self:FeatFlag("twoCont") end
	self:FeatTouch("zone")
	return cont
end

-- ---------------------------------------------------------------------------
-- Au jour le jour (personnage)
-- ---------------------------------------------------------------------------
local function Daily(self)
	if not self.DailyData then return nil end
	return self:DailyData()
end
ns.FeatCatalog(function()
	SOURCES.perfect = { topics = ns.FeatTopics("mission"), get = function(self)
		local daily = Daily(self)
		return daily and daily.perfect or 0
	end }
	SOURCES.innDays = { topics = ns.FeatTopics("mission"), get = function(self)
		local _, inn = Daily(self)
		return inn and inn.total or 0
	end }
	SOURCES.travelKm = { topics = ns.FeatTopics("minute", "companion"), get = function(self)
		return math.floor((tonumber(self:CompanionData().travel) or 0) / 1000)
	end }
	SOURCES.daysTogether = { topics = ns.FeatTopics("minute", "companion"), get = function(self)
		return self.CompanionDaysTogether and tonumber(self:CompanionDaysTogether()) or 0
	end }
end)

-- ---------------------------------------------------------------------------
-- Guilde et entraide, Insolite (compte)
-- ---------------------------------------------------------------------------
ns.FeatCatalog(function()
	SOURCES.showcase = { topics = ns.FeatTopics("card"), get = function(self)
		local n = 0
		for _, id in pairs(self.TrainerShowcase and self:TrainerShowcase() or {}) do
			if type(id) == "string" and id ~= "" then n = n + 1 end
		end
		return n
	end }
	-- un titre choisi sur l'un des personnages (feats.title, lot D)
	SOURCES.titleSet = { topics = ns.FeatTopics("card", "feat"), get = function(self)
		local db, n = self:DB(), 0
		for _, char in pairs(type(db.chars) == "table" and db.chars or {}) do
			local code = tonumber(Sub(char, "feats") and char.feats.title)
			if code and code > 0 then n = 1 end
		end
		return n
	end }
	SOURCES.companionName = { topics = ns.FeatTopics("companion", "minute"), get = function(self)
		local n = 0
		EachCompanion(self, function(data) if type(data.name) == "string" and data.name ~= "" then n = 1 end end)
		return n
	end }
	SOURCES.hoggerKilled = { topics = ns.FeatTopics("kill"), get = function(self)
		for _, zone in pairs(self.BestiaryData and self:BestiaryData() or {}) do
			local entry = type(zone) == "table" and (zone[ns.FEAT_HOGGER] or zone[tostring(ns.FEAT_HOGGER)])
			if type(entry) == "table" and (tonumber(entry.killed) or 0) > 0 then return 1 end
		end
		return 0
	end }
	-- jour anniversaire de la rencontre (au moins un an) : pas en rattrapage,
	-- pour que le bandeau tombe le jour même
	SOURCES.birthday = { topics = ns.FeatTopics("minute", "companion"), retro = false, get = function(self)
		local since = tonumber(self:CompanionData().since) or 0
		local now = Time()
		if since <= 0 or now - since < 360 * 86400 then return 0 end
		local a, b = Call(G("date"), "%m%d", since), Call(G("date"), "%m%d", now)
		return (type(a) == "string" and a == b) and 1 or 0
	end }

	-- Grands hauts faits : un haut fait obtenu, le total de points
	SOURCES.featPoints = { topics = ns.FeatTopics("feat"),
		get = function(self) return (self:FeatPoints(nil)) end }
	for _, id in ipairs({ "meta_menagerie", "meta_shiny", "meta_zones" }) do
		SOURCES["got_" .. id] = { topics = ns.FeatTopics("feat"),
			get = function(self) return self:FeatGot(id) and 1 or 0 end }
	end
	LISTS.trainerMeta = { topics = ns.FeatTopics("feat"), items = function()
		return { { "got_meta_menagerie", 1 }, { "got_meta_shiny", 1 }, { "got_meta_zones", 1 }, { "featPoints", 1000 } }
	end }
end)

-- ---------------------------------------------------------------------------
-- Catalogue (n = rang dans le document, jamais réutilisé)
-- ---------------------------------------------------------------------------
-- palier d'espèces déjà payé par l'ancien système (2.6) sur un personnage
local function RankPaid(count)
	return function(self)
		local paid = false
		EachCompanion(self, function(data)
			local coll = Sub(data, "collection")
			local ranks, mine = Sub(coll, "ranks"), Sub(coll, "featRanks")
			if ranks and ranks[count] and not (mine and mine[count]) then paid = true end
		end)
		return paid
	end
end

local A, CH = "account", "char"
-- aides : tables partagées (lecture seule) pour les dons d'une unité
local ONE = {}
local function Aids(id, n)
	if n and n ~= 1 then return { [id] = n } end
	ONE[id] = ONE[id] or { [id] = 1 }
	return ONE[id]
end
-- lignes construites à la première lecture du catalogue (FeatsData.lua)
ns.FEAT_MENAGERIE_IDS = {}
ns.FeatCatalog(function()
	local ROWS = {
		-- Ménagerie
		{ "men_species_10",  2, "men", 10, A, crit = { "count", "species", 10 },  reward = { title = 1, aids = { appat = 1, lasso = 1 } }, paid = 10 },
		{ "men_species_25",  3, "men", 10, A, crit = { "count", "species", 25 },  reward = { title = 2, cosmetic = { "frame", "trainer" } }, paid = 25 },
		{ "men_species_50",  4, "men", 10, A, crit = { "count", "species", 50 },  reward = { title = 3, aids = Aids("sifflet"), cosmetic = { "bg", "menagerie" } }, paid = 50 },
		{ "men_species_100", 5, "men", 25, A, crit = { "count", "species", 100 }, reward = { title = 4, aids = Aids("sifflet"), cosmetic = { "frame", "master" } }, paid = 100 },
		{ "men_species_250", 6, "men", 50, A, crit = { "count", "species", 250 }, reward = { title = 5, aids = Aids("sifflet", 2), cosmetic = { "bg", "grandmaster" } }, paid = 250 },
		{ "men_species_500", 7, "men", 50, A, crit = { "count", "species", 500 }, reward = { title = 6, soon = { "cardbg", "card_census" } } },
		{ "men_elite_1",     8, "men", 5,  A, crit = { "count", "elite", 1 } },
		{ "men_rare_1",      9, "men", 10, A, crit = { "count", "rare", 1 },  reward = { aids = Aids("lasso") } },
		{ "men_rare_10",    10, "men", 25, A, crit = { "count", "rare", 10 }, reward = { title = 7 } },
		{ "men_boss_1",     11, "men", 25, A, crit = { "count", "boss", 1 },  reward = { soon = { "orn", "feat_chain" } } },
		{ "men_types_t1",   12, "men", 10, A, crit = { "count", "typesTier1", 8 }, reward = { aids = Aids("lasso") } },
		{ "men_type_beast",      13, "men", 10, A, crit = { "count", "type_beast", 40 },      reward = { aids = Aids("lasso") } },
		{ "men_type_humanoid",   14, "men", 10, A, crit = { "count", "type_humanoid", 40 },   reward = { aids = Aids("lasso") } },
		{ "men_type_undead",     15, "men", 10, A, crit = { "count", "type_undead", 40 },     reward = { aids = Aids("lasso") } },
		{ "men_type_elemental",  16, "men", 10, A, crit = { "count", "type_elemental", 40 },  reward = { aids = Aids("lasso") } },
		{ "men_type_dragonkin",  17, "men", 10, A, crit = { "count", "type_dragonkin", 20 },  reward = { title = 8 } },
		{ "men_type_demon",      18, "men", 10, A, crit = { "count", "type_demon", 20 },      reward = { title = 9 } },
		{ "men_type_giant",      19, "men", 10, A, crit = { "count", "type_giant", 20 },      reward = { aids = Aids("lasso") } },
		{ "men_type_mechanical", 20, "men", 10, A, crit = { "count", "type_mechanical", 20 }, reward = { aids = Aids("lasso") } },
		{ "men_types_master", 21, "men", 25, A, crit = { "meta", { "men_type_beast", "men_type_humanoid", "men_type_undead",
			"men_type_elemental", "men_type_dragonkin", "men_type_demon", "men_type_giant", "men_type_mechanical" } },
			reward = { title = 10, soon = { "frame", "feat_eight" } }, desc = "FEATD_typesMaster" },
		{ "men_stars3_1",   22, "men", 5,  A, crit = { "count", "stars3", 1 } },
		{ "men_stars3_25",  23, "men", 10, A, crit = { "count", "stars3", 25 },  reward = { aids = Aids("appat", 2) } },
		{ "men_stars3_100", 24, "men", 25, A, crit = { "count", "stars3", 100 }, reward = { title = 11, soon = { "orn", "feat_goldstars" } } },
		{ "men_batch_5",    25, "men", 10, A, crit = { "flag", "batch5" } },
		{ "men_bad_luck",   26, "men", 5,  A, crit = { "streak", "capFail", 10 }, reward = { title = 40, aids = Aids("appat", 3) } },
		{ "men_level_gap",  27, "men", 10, A, crit = { "flag", "levelGap" } },
		{ "men_companion_types", 28, "men", 10, A, crit = { "count", "companionTypes", 8 } },
		{ "men_companion_boss",  29, "men", 10, A, crit = { "flag", "companionBoss" } },
		-- Brillantes
		{ "shiny_seen_1",   30, "shiny", 5,  A, crit = { "count", "shinySeen", 1 } },
		{ "shiny_found_5",  31, "shiny", 10, A, crit = { "count", "shinyFound", 5 },  reward = { cosmetic = { "frame", "sparkle" } } },
		{ "shiny_found_15", 32, "shiny", 10, A, crit = { "count", "shinyFound", 15 }, reward = { cosmetic = { "bg", "stardust" } } },
		{ "shiny_found_30", 33, "shiny", 25, A, crit = { "count", "shinyFound", 30 }, reward = { cosmetic = { "orn", "aura" } } },
		{ "shiny_found_50", 34, "shiny", 25, A, crit = { "count", "shinyFound", 50 }, reward = { title = 12, appearance = "hippogryph" } },
		{ "shiny_cap_10",   36, "shiny", 25, A, crit = { "count", "shinyCap", 10 }, reward = { aids = Aids("sifflet") } },
		{ "shiny_cap_25",   37, "shiny", 50, A, crit = { "count", "shinyCap", 25 }, reward = { title = 13 } },
		{ "shiny_elite",    38, "shiny", 10, A, crit = { "count", "shinyNamed", 1 } },
		{ "shiny_3stars",   39, "shiny", 25, A, crit = { "count", "shiny3", 1 }, reward = { soon = { "orn", "feat_prism_orn" } } },
		{ "shiny_sealed",   40, "shiny", 10, A, crit = { "flag", "shinySealed" } },
		{ "shiny_zones_10", 41, "shiny", 25, A, crit = { "count", "shinyZones", 10 } },
		-- Zones et sceaux
		{ "zone_seal_5",     43, "zone", 10, CH, crit = { "count", "seals", 5 },  reward = { aids = Aids("sifflet") } },
		{ "zone_seal_15",    44, "zone", 25, CH, crit = { "count", "seals", 15 }, reward = { title = 14 } },
		{ "zone_seal_ek",    45, "zone", 50, CH, crit = { "list", "sealsEk" }, reward = { soon = { "cardframe", "card_crest_ek" } } },
		{ "zone_seal_ka",    46, "zone", 50, CH, crit = { "list", "sealsKa" }, reward = { soon = { "cardframe", "card_crest_ka" } } },
		{ "zone_all_biomes", 47, "zone", 25, CH, crit = { "count", "biomesSealed", 10 }, reward = { title = 15 } },
		-- uiMapID de Riverglades, Mont Hyjal et Shen'dralas à relever en jeu
		{ "zone_visit_all",  50, "zone", 50, CH, crit = { "list", "outdoorZones" }, reward = { title = 16 }, pending = true },
		{ "zone_forever_new", 51, "zone", 10, CH, crit = { "list", "foreverZones" }, pending = true },
		{ "zone_100_1",      56, "zone", 10, CH, crit = { "count", "zones100", 1 } },
		{ "zone_100_10",     57, "zone", 25, CH, crit = { "count", "zones100", 10 }, reward = { soon = { "bg", "feat_atlas" } } },
		{ "zone_golden",     58, "zone", 10, CH, crit = { "count", "golden", 1 } },
		{ "zone_chests_10",  59, "zone", 10, CH, crit = { "count", "chests", 10 }, reward = { aids = Aids("sifflet") } },
		{ "zone_milestones_25", 60, "zone", 10, CH, crit = { "count", "milestones", 25 } },
		{ "zone_quests_zone", 61, "zone", 10, CH, crit = { "flag", "questZone" } },
		{ "zone_ek_100",     62, "zone", 50, CH, crit = { "list", "zones100Ek" } },
		{ "zone_ka_100",     63, "zone", 50, CH, crit = { "list", "zones100Ka" } },
		{ "zone_two_continents", 64, "zone", 5, CH, crit = { "count", "twoContinents", 1 } },
		-- Au jour le jour
		{ "day_mission_25",  66, "day", 10, CH, crit = { "count", "missions", 25 },  reward = { aids = Aids("lasso") } },
		{ "day_mission_100", 67, "day", 25, CH, crit = { "count", "missions", 100 }, reward = { title = 18 } },
		-- l'écureuil mécanique reste donné par Daily.lua (même condition)
		{ "day_perfect_10",  68, "day", 10, CH, crit = { "count", "perfect", 10 } },
		{ "day_weekly_all",  69, "day", 10, CH, crit = { "flag", "weeklyAll" } },
		{ "day_inn_30",      70, "day", 10, CH, crit = { "count", "innDays", 30 } },
		{ "day_travel_100",  74, "day", 10, CH, crit = { "count", "travelKm", 100 } },
		{ "day_travel_1000", 75, "day", 25, CH, crit = { "count", "travelKm", 1000 }, reward = { soon = { "orn", "feat_compass" } } },
		{ "day_days_30",     76, "day", 10, CH, crit = { "count", "daysTogether", 30 } },
		{ "day_days_365",    77, "day", 25, CH, crit = { "count", "daysTogether", 365 }, reward = { title = 20, soon = { "orn", "feat_anniversary" } } },
		{ "day_pets_100",    78, "day", 10, CH, crit = { "streak", "pets", 100 } },
		-- Guilde et entraide
		{ "soc_card_1",        79, "soc", 5,  A, crit = { "streak", "cards", 1 }, desc = "FEATD_card1" },
		{ "soc_card_10",       80, "soc", 10, A, crit = { "streak", "cards", 10 } },
		{ "soc_showcase",      81, "soc", 5,  A, crit = { "count", "showcase", 3 } },
		{ "soc_guild_feat",    82, "soc", 5,  A, crit = { "flag", "guildFeat" } },
		{ "soc_guild_cheer",   83, "soc", 5,  A, crit = { "streak", "guildSeen", 25 } },
		{ "soc_group_capture", 84, "soc", 5,  A, crit = { "flag", "groupCapture" } },
		{ "soc_title",         85, "soc", 5,  A, crit = { "count", "titleSet", 1 } },
		-- Insolite (ménagerie, compagnon, carnet ; les statistiques : lot C)
		{ "fun_name",           151, "fun", 5,  A, crit = { "count", "companionName", 1 } },
		{ "fun_dance",          152, "fun", 5,  A, crit = { "streak", "dances", 10 } },
		{ "fun_hogger_kill",    153, "fun", 10, A, crit = { "count", "hoggerKilled", 1 } },
		{ "fun_hogger_capture", 154, "fun", 10, A, crit = { "count", "hogger", 1 }, reward = { title = 32 } },
		{ "fun_murlocs",        156, "fun", 10, A, crit = { "count", "murlocs", 5 }, reward = { title = 33 } },
		{ "fun_critter",        157, "fun", 5,  A, crit = { "count", "critter", 1 } },
		{ "fun_night_owl",      163, "fun", 5,  A, crit = { "flag", "nightOwl" }, reward = { title = 34 } },
		{ "fun_birthday",       164, "fun", 10, A, crit = { "count", "birthday", 1 } },
		-- Grands hauts faits
		{ "meta_shiny",   167, "meta", 25, A, crit = { "meta", "shiny", 10 }, reward = { soon = { "frame", "feat_prism" } } },
		{ "meta_zones",   168, "meta", 25, A, crit = { "meta", "zone", 15 },  reward = { soon = { "cardbg", "card_atlas" } } },
		{ "meta_trainer", 173, "meta", 50, A, crit = { "list", "trainerMeta" }, reward = { title = 38, soon = { "cardbg", "card_pantheon" } } },
	}
	-- ligne de départ liée : son fond de fiche (lot E) en attente
	for _, def in ipairs(ns.FEAT_DEFS) do
		if def.id == "meta_points_1500" and not def.reward then def.reward = { soon = { "cardbg", "card_renown" } } end
	end
	for _, row in ipairs(ROWS) do
		if row.paid then row.paid = RankPaid(row.paid) end
		ns.FeatAdd(row)
		ns.FEAT_MENAGERIE_IDS[#ns.FEAT_MENAGERIE_IDS + 1] = row[1]
	end
	ns.FeatResolveSoon()
end)

-- un cosmétique du compagnon existe-t-il déjà ? (sinon : reward.soon)
local LISTS_OF = { frame = "COMPANION_FRAMES", bg = "COMPANION_BACKGROUNDS", orn = "COMPANION_ORNAMENTS", app = "COMPANION_APPEARANCES" }
local function CosmeticExists(kind, id)
	for _, def in ipairs(ns[LISTS_OF[kind] or ""] or {}) do if def.id == id then return true end end
	return false
end
function ns.FeatResolveSoon()
	for _, def in ipairs(ns.FEAT_DEFS) do
		local reward = def.reward
		if type(reward) == "table" and reward.soon and not reward.cosmetic and CosmeticExists(reward.soon[1], reward.soon[2]) then
			reward.cosmetic, reward.soon = reward.soon, nil
		end
	end
end


-- Titres de ce lot : registre unique dans FeatsTitles.lua (lot D).

-- ---------------------------------------------------------------------------
-- Crochets : faits ponctuels et compteurs (rien tant que le moteur dort)
-- ---------------------------------------------------------------------------
local function Wrap(name, after)
	local base = ns[name]
	if type(base) ~= "function" then return false end
	ns[name] = function(self, ...)
		local a, b, c = base(self, ...)
		if Awake() then
			local ok, err = pcall(after, self, a, ...)
			if not ok and self.RecordError then self:RecordError("feats:" .. name, err) end
		end
		return a, b, c
	end
	return true
end

-- Capture résolue : série d'échecs, écart de niveau, groupe, heure
Wrap("CaptureResolve", function(self, success, rolling)
	if type(rolling) ~= "table" then return end
	if not success then
		if not rolling.success then self:FeatCount("capFail", 1, A) end
		return
	end
	-- la série atteinte attend son évaluation (une réussite dans la même volée)
	if self:FeatCount("capFail", nil, A) < 10 or self:FeatGot("men_bad_luck") then self:FeatCountReset("capFail", A) end
	local target = type(rolling.target) == "table" and rolling.target or {}
	local level, mine = tonumber(ns.Plain and ns.Plain(target.level) or target.level), tonumber(Call(G("UnitLevel"), "player"))
	if level and mine and level > 0 and level - mine >= 5 then self:FeatFlag("levelGap", A) end
	if Call(G("IsInGroup")) == true then self:FeatFlag("groupCapture", A) end
	local hour = tonumber(Call(G("date"), "%H"))
	if hour and hour >= 2 and hour < 5 then self:FeatFlag("nightOwl", A) end
end)
-- Volée « Tout capturer » : 5 prises ou plus
Wrap("CaptureBatchFlush", function(self, _, batch)
	if type(batch) == "table" and (tonumber(batch.got) or 0) >= 5 then self:FeatFlag("batch5", A) end
end)
-- Brillante repérée (le relevé du compte change) ; abattue dans une zone scellée
Wrap("ShinySpot", function() bump = bump + 1 end)
Wrap("ShinyKill", function(self, _, _, info)
	local zoneID = type(info) == "table" and info.zoneID or (self.JournalZone and self:JournalZone())
	if zoneID and self.MenagerieSealed and self:MenagerieSealed(zoneID) then self:FeatFlag("shinySealed", A) end
end)
-- Compagnon emmené : son effet devient actif (type, boss du monde)
Wrap("CompanionEffectsTick", function(self, effects)
	if type(effects) ~= "table" or not effects.active then return end
	local store = self:FeatStore(A)
	if effects.typeKey then
		if type(store.ctypes) ~= "table" then store.ctypes = {} end
		if not store.ctypes[effects.typeKey] then
			store.ctypes[effects.typeKey] = true
			self:FeatTouch("companion")
		end
	end
	if effects.class == "worldboss" then self:FeatFlag("companionBoss", A) end
end)
-- Caresse (hors tutoriel)
do
	local base = ns.CompanionPet
	if type(base) == "function" then
		function ns:CompanionPet(...)
			local tutorial = self.CompanionTutorialActive and Call(self.CompanionTutorialActive, self)
			local done = base(self, ...)
			if done and not tutorial and Awake() then pcall(self.FeatCount, self, "pets", 1, CH) end
			return done
		end
	end
end
-- Semaine bouclée
Wrap("MissionGrant", function(self, _, scope)
	if scope == "allWeekly" then self:FeatFlag("weeklyAll", CH) end
end)
-- Paliers de zone : toutes les quêtes d'une zone faites
local questSeen = {}   -- [zoneID] = dernier relevé (une fois par minute au plus)
Wrap("TreatCheckZone", function(self, _, zoneID)
	if not zoneID or self:FeatStore(CH).flag.questZone or not self.ZoneQuestsPart then return end
	local now = (ns.Now and ns.Now()) or 0
	if questSeen[zoneID] and now >= questSeen[zoneID] and now - questSeen[zoneID] < 60 then return end
	questSeen[zoneID] = now
	local part = Call(self.ZoneQuestsPart, self, zoneID)
	if type(part) == "table" and (tonumber(part.need) or 0) > 0 and (tonumber(part.have) or 0) >= part.need then
		self:FeatFlag("questZone", CH)
	end
end)
-- Fiche d'un autre dresseur consultée (10 noms gardés au plus)
Wrap("TrainerOpen", function(self, frame, name)
	if not (frame and name) then return end
	local full = self.TrainerFullName and self:TrainerFullName(name)
	local key = full and self.TrainerKey and self:TrainerKey(full)
	local me = self.TrainerMe and self:TrainerMe()
	if not key or (me and key == self:TrainerKey(me)) then return end
	local store = self:FeatStore(A)
	if type(store.cards) ~= "table" then store.cards = {} end
	if store.cards[key] or Keys(store.cards) >= 10 then return end
	store.cards[key] = true
	self:FeatCount("cards", 1, A)
end)
Wrap("TrainerSetShowcase", function(self, ok) if ok then self:FeatTouch("card") end end)
-- Exploits de guilde : envoyé, vus
Wrap("GuildFeatsFlush", function(self, sent) if sent then self:FeatFlag("guildFeat", A) end end)
Wrap("GuildFeatsEnqueue", function(self) self:FeatCount("guildSeen", 1, A) end)

-- Danse avec le compagnon affiché
local hookSecure = G("hooksecurefunc")
if type(hookSecure) == "function" then
	pcall(hookSecure, "DoEmote", function(emote)
		if not Awake() or type(emote) ~= "string" or emote:upper() ~= "DANCE" then return end
		local frame = ns.companionFrame
		if frame and frame.IsShown and frame:IsShown() then pcall(ns.FeatCount, ns, "dances", 1, A) end
	end)
end

-- Changement de zone (continents du jour) ; horloge d'une minute (temps
-- ensemble, kilomètres, anniversaire, nom de la mascotte)
-- (cadre partagé des hauts faits, FeatsData.lua)
do
	local function Continent() ns:FeatNoteContinent() end
	ns.FeatListen({ ZONE_CHANGED_NEW_AREA = Continent, PLAYER_ENTERING_WORLD = Continent })
	if ns.Throttle then
		local minute = ns.Throttle(60, function() if Awake() then ns:FeatTouch("minute") end end)
		ns.FeatClock("minute", function(elapsed) minute(nil, elapsed) end)
	end
end

-- ---------------------------------------------------------------------------
-- Chaînes : noms (FEAT_<id>) et descriptions (FEATD_*)
-- ---------------------------------------------------------------------------
local FR = {
	FEATD_elite          = "Capturer une créature élite",
	FEATD_rare           = "Capturer %d rare(s) ou rare(s) élite(s)",
	FEATD_boss           = "Capturer un boss du monde",
	FEATD_typesTier1     = "Atteindre le palier 1 dans les %d types de créature",
	FEATD_type_beast     = "Capturer %d bêtes (palier 3)",
	FEATD_type_humanoid  = "Capturer %d humanoïdes (palier 3)",
	FEATD_type_undead    = "Capturer %d morts-vivants (palier 3)",
	FEATD_type_elemental = "Capturer %d élémentaires (palier 3)",
	FEATD_type_dragonkin = "Capturer %d draconiens (palier 3)",
	FEATD_type_demon     = "Capturer %d démons (palier 3)",
	FEATD_type_giant     = "Capturer %d géants (palier 3)",
	FEATD_type_mechanical = "Capturer %d mécaniques (palier 3)",
	FEATD_typesMaster    = "Atteindre le palier 3 dans les %d types de créature",
	FEATD_stars3         = "Avoir %d espèce(s) capturée(s) à 3 étoiles",
	FEATD_flag_batch5    = "Prendre 5 créatures en une seule volée « Tout capturer »",
	FEATD_streak_capFail = "Rater %d captures de suite",
	FEATD_flag_levelGap  = "Capturer une créature d'au moins 5 niveaux de plus que toi",
	FEATD_companionTypes = "Emmener un compagnon de chacun des %d types (effet actif)",
	FEATD_flag_companionBoss = "Emmener un boss du monde capturé (effet actif)",
	FEATD_shinySeen      = "Repérer une brillante",
	FEATD_shinyFound     = "Trouver %d brillantes, tous personnages confondus",
	FEATD_shinyNamed     = "Capturer une brillante élite, rare ou boss",
	FEATD_shiny3         = "Capturer une brillante à 3 étoiles",
	FEATD_flag_shinySealed = "Trouver une brillante dans une zone scellée",
	FEATD_shinyZones     = "Trouver des brillantes dans %d zones différentes",
	FEATD_list_sealsEk   = "Sceller les %d zones à sceau des Royaumes de l'Est",
	FEATD_list_sealsKa   = "Sceller les %d zones à sceau de Kalimdor",
	FEATD_biomesSealed   = "Sceller une zone dans chacun des %d biomes",
	FEATD_list_outdoorZones = "Découvrir les %d zones extérieures d'Azeroth",
	FEATD_list_foreverZones = "Visiter Riverglades, le Mont Hyjal et Shen'dralas",
	FEATD_zones100       = "Accomplir %d zone(s) à 100 %%",
	FEATD_golden         = "Rendre une zone dorée",
	FEATD_chests         = "Ouvrir %d coffres de zone",
	FEATD_milestones     = "Franchir %d paliers de zone (25, 50, 75, 100 %%)",
	FEATD_flag_questZone = "Faire toutes les quêtes d'une zone",
	FEATD_list_zones100Ek = "Accomplir les %d zones des Royaumes de l'Est à 100 %%",
	FEATD_list_zones100Ka = "Accomplir les %d zones de Kalimdor à 100 %%",
	FEATD_twoContinents  = "Découvrir ou revisiter une zone de chaque continent le même jour",
	FEATD_perfect        = "Boucler toutes les missions du jour %d fois (l'écureuil mécanique reste la récompense de Daily)",
	FEATD_flag_weeklyAll = "Boucler toutes les missions d'une semaine",
	FEATD_innDays        = "Passer %d jours à l'auberge",
	FEATD_travelKm       = "Parcourir %d km avec le compagnon",
	FEATD_daysTogether   = "Passer %d jours avec le compagnon",
	FEATD_streak_pets    = "Caresser le compagnon %d fois",
	FEATD_card1          = "Consulter la fiche d'un autre dresseur",
	FEATD_streak_cards   = "Consulter %d fiches de dresseur différentes",
	FEATD_showcase       = "Remplir les %d places de la vitrine",
	FEATD_flag_guildFeat = "Annoncer un exploit à ta guilde",
	FEATD_streak_guildSeen = "Voir %d exploits des membres de ta guilde",
	FEATD_flag_groupCapture = "Capturer une créature en groupe",
	FEATD_titleSet       = "Choisir un titre pour ta fiche de dresseur",
	FEATD_companionName  = "Donner un nom à ta mascotte",
	FEATD_streak_dances  = "Danser %d fois avec le compagnon affiché",
	FEATD_hoggerKilled   = "Vaincre Lardeur",
	FEATD_hogger         = "Capturer Lardeur",
	FEATD_murlocs        = "Capturer %d murlocs différents",
	FEATD_critter        = "Capturer une bestiole",
	FEATD_flag_nightOwl  = "Capturer une créature entre 2 h et 5 h du matin",
	FEATD_birthday       = "Jouer le jour anniversaire de ta rencontre avec le compagnon",
	FEATD_list_trainerMeta = "Obtenir « Maître des lieux », « Tout ce qui brille », « Sceaux et chemins » et 1000 points",
	FEAT_men_species_500 = "Le grand recensement",
	FEAT_men_elite_1     = "Gros gibier",
	FEAT_men_rare_1      = "Pièce rare",
	FEAT_men_rare_10     = "Cabinet des raretés",
	FEAT_men_boss_1      = "Le colosse en cage",
	FEAT_men_types_t1    = "Touche-à-tout",
	FEAT_men_type_beast  = "Meneur de meute",
	FEAT_men_type_humanoid = "Recruteur de talents",
	FEAT_men_type_undead = "Berger des tombes",
	FEAT_men_type_elemental = "Lieur d'éléments",
	FEAT_men_type_dragonkin = "Écailles et griffes",
	FEAT_men_type_demon  = "Pacte scellé",
	FEAT_men_type_giant  = "Haut comme une montagne",
	FEAT_men_type_mechanical = "Boulons et rouages",
	FEAT_men_types_master = "Les huit familles",
	FEAT_men_stars3_1    = "Spécimen parfait",
	FEAT_men_stars3_25   = "Galerie trois étoiles",
	FEAT_men_stars3_100  = "Constellation",
	FEAT_men_batch_5     = "Coup de filet",
	FEAT_men_bad_luck    = "Il s'est encore échappé",
	FEAT_men_level_gap   = "David contre Goliath",
	FEAT_men_companion_types = "Tour de la ménagerie",
	FEAT_men_companion_boss = "Garde du corps",
	FEAT_shiny_seen_1    = "Un éclat dans l'herbe",
	FEAT_shiny_found_5   = "Œil de pie",
	FEAT_shiny_found_15  = "Poussière d'étoiles",
	FEAT_shiny_found_30  = "Aura dorée",
	FEAT_shiny_found_50  = "Le petit hippogriffe",
	FEAT_shiny_cap_10    = "Vitrine scintillante",
	FEAT_shiny_cap_25    = "Trésor vivant",
	FEAT_shiny_elite     = "Éclat d'élite",
	FEAT_shiny_3stars    = "Brillante parfaite",
	FEAT_shiny_sealed    = "Terre bénie",
	FEAT_shiny_zones_10  = "Éclats d'Azeroth",
	FEAT_zone_seal_5     = "Apposeur de sceaux",
	FEAT_zone_seal_15    = "Gardien des sceaux",
	FEAT_zone_seal_ek    = "Sceaux de l'Est",
	FEAT_zone_seal_ka    = "Sceaux de Kalimdor",
	FEAT_zone_all_biomes = "Tour des biomes",
	FEAT_zone_visit_all  = "Tous les chemins",
	FEAT_zone_forever_new = "Terres nouvelles",
	FEAT_zone_100_1      = "Zone accomplie",
	FEAT_zone_100_10     = "Dix zones accomplies",
	FEAT_zone_golden     = "Or massif",
	FEAT_zone_chests_10  = "Chasseur de coffres",
	FEAT_zone_milestones_25 = "Petits pas, grand chemin",
	FEAT_zone_quests_zone = "Zone sans reste",
	FEAT_zone_ek_100     = "L'Est sur le bout des doigts",
	FEAT_zone_ka_100     = "Kalimdor sur le bout des doigts",
	FEAT_zone_two_continents = "Deux continents en un jour",
	FEAT_day_mission_25  = "Bon élément",
	FEAT_day_mission_100 = "Infatigable",
	FEAT_day_perfect_10  = "Journées parfaites",
	FEAT_day_weekly_all  = "Semaine bouclée",
	FEAT_day_inn_30      = "Pilier de comptoir",
	FEAT_day_travel_100  = "Cent kilomètres ensemble",
	FEAT_day_travel_1000 = "Mille kilomètres ensemble",
	FEAT_day_days_30     = "Un mois ensemble",
	FEAT_day_days_365    = "Un an ensemble",
	FEAT_day_pets_100    = "Câlins à volonté",
	FEAT_soc_card_1      = "Enchanté !",
	FEAT_soc_card_10     = "Carnet d'adresses",
	FEAT_soc_showcase    = "Vitrine garnie",
	FEAT_soc_guild_feat  = "Ça jase à la guilde",
	FEAT_soc_guild_cheer = "Supporter",
	FEAT_soc_group_capture = "Chasse en meute",
	FEAT_soc_title       = "Nom de scène",
	FEAT_fun_name        = "Baptême",
	FEAT_fun_dance       = "Danse avec les bêtes",
	FEAT_fun_hogger_kill = "Pas peur de Lardeur",
	FEAT_fun_hogger_capture = "Lardeur en laisse",
	FEAT_fun_murlocs     = "Mrgl mrgl !",
	FEAT_fun_critter     = "Petite bête",
	FEAT_fun_night_owl   = "Oiseau de nuit",
	FEAT_fun_birthday    = "Joyeux anniversaire",
	FEAT_meta_shiny      = "Tout ce qui brille",
	FEAT_meta_zones      = "Sceaux et chemins",
	FEAT_meta_trainer    = "Dresseur de légende",
}
local EN = {
	FEATD_elite          = "Capture an elite creature",
	FEATD_rare           = "Capture %d rare or rare elite creature(s)",
	FEATD_boss           = "Capture a world boss",
	FEATD_typesTier1     = "Reach tier 1 in all %d creature types",
	FEATD_type_beast     = "Capture %d beasts (tier 3)",
	FEATD_type_humanoid  = "Capture %d humanoids (tier 3)",
	FEATD_type_undead    = "Capture %d undead (tier 3)",
	FEATD_type_elemental = "Capture %d elementals (tier 3)",
	FEATD_type_dragonkin = "Capture %d dragonkin (tier 3)",
	FEATD_type_demon     = "Capture %d demons (tier 3)",
	FEATD_type_giant     = "Capture %d giants (tier 3)",
	FEATD_type_mechanical = "Capture %d mechanicals (tier 3)",
	FEATD_typesMaster    = "Reach tier 3 in all %d creature types",
	FEATD_stars3         = "Have %d species captured at 3 stars",
	FEATD_flag_batch5    = "Catch 5 creatures in a single \"Capture all\" volley",
	FEATD_streak_capFail = "Fail %d captures in a row",
	FEATD_flag_levelGap  = "Capture a creature at least 5 levels above you",
	FEATD_companionTypes = "Take along a companion of each of the %d types (active effect)",
	FEATD_flag_companionBoss = "Take along a captured world boss (active effect)",
	FEATD_shinySeen      = "Spot a shiny creature",
	FEATD_shinyFound     = "Find %d shiny creatures, across all your characters",
	FEATD_shinyNamed     = "Capture a shiny elite, rare or boss",
	FEATD_shiny3         = "Capture a 3-star shiny",
	FEATD_flag_shinySealed = "Find a shiny creature in a sealed zone",
	FEATD_shinyZones     = "Find shiny creatures in %d different zones",
	FEATD_list_sealsEk   = "Seal all %d sealable zones of the Eastern Kingdoms",
	FEATD_list_sealsKa   = "Seal all %d sealable zones of Kalimdor",
	FEATD_biomesSealed   = "Seal a zone in each of the %d biomes",
	FEATD_list_outdoorZones = "Discover all %d outdoor zones of Azeroth",
	FEATD_list_foreverZones = "Visit Riverglades, Mount Hyjal and Shen'dralas",
	FEATD_zones100       = "Complete %d zone(s) at 100%%",
	FEATD_golden         = "Turn a zone golden",
	FEATD_chests         = "Open %d zone chests",
	FEATD_milestones     = "Reach %d zone milestones (25, 50, 75, 100%%)",
	FEATD_flag_questZone = "Complete every quest of a zone",
	FEATD_list_zones100Ek = "Complete all %d zones of the Eastern Kingdoms at 100%%",
	FEATD_list_zones100Ka = "Complete all %d zones of Kalimdor at 100%%",
	FEATD_twoContinents  = "Discover or revisit a zone on each continent on the same day",
	FEATD_perfect        = "Finish all daily missions %d times (the clockwork squirrel stays the Daily reward)",
	FEATD_flag_weeklyAll = "Finish every mission of a week",
	FEATD_innDays        = "Spend %d days at the inn",
	FEATD_travelKm       = "Travel %d km with your companion",
	FEATD_daysTogether   = "Spend %d days with your companion",
	FEATD_streak_pets    = "Pet your companion %d times",
	FEATD_card1          = "Look at another trainer's card",
	FEATD_streak_cards   = "Look at %d different trainer cards",
	FEATD_showcase       = "Fill all %d showcase slots",
	FEATD_flag_guildFeat = "Announce a feat to your guild",
	FEATD_streak_guildSeen = "See %d feats from your guild mates",
	FEATD_flag_groupCapture = "Capture a creature in a group",
	FEATD_titleSet       = "Choose a title for your trainer card",
	FEATD_companionName  = "Give your mascot a name",
	FEATD_streak_dances  = "Dance %d times with your companion shown",
	FEATD_hoggerKilled   = "Defeat Hogger",
	FEATD_hogger         = "Capture Hogger",
	FEATD_murlocs        = "Capture %d different murlocs",
	FEATD_critter        = "Capture a critter",
	FEATD_flag_nightOwl  = "Capture a creature between 2 and 5 a.m.",
	FEATD_birthday       = "Play on the anniversary of meeting your companion",
	FEATD_list_trainerMeta = "Earn \"Master of the House\", \"All That Glitters\", \"Seals and Roads\" and 1000 points",
	FEAT_men_species_500 = "The Great Census",
	FEAT_men_elite_1     = "Big Game",
	FEAT_men_rare_1      = "A Rare Find",
	FEAT_men_rare_10     = "Cabinet of Curiosities",
	FEAT_men_boss_1      = "The Caged Colossus",
	FEAT_men_types_t1    = "Jack of All Types",
	FEAT_men_type_beast  = "Pack Leader",
	FEAT_men_type_humanoid = "Talent Scout",
	FEAT_men_type_undead = "Shepherd of Graves",
	FEAT_men_type_elemental = "Element Binder",
	FEAT_men_type_dragonkin = "Scales and Claws",
	FEAT_men_type_demon  = "Pact Sealed",
	FEAT_men_type_giant  = "Mountain High",
	FEAT_men_type_mechanical = "Nuts and Bolts",
	FEAT_men_types_master = "The Eight Families",
	FEAT_men_stars3_1    = "Perfect Specimen",
	FEAT_men_stars3_25   = "Three-Star Gallery",
	FEAT_men_stars3_100  = "Constellation",
	FEAT_men_batch_5     = "Big Haul",
	FEAT_men_bad_luck    = "Got Away Again",
	FEAT_men_level_gap   = "David and Goliath",
	FEAT_men_companion_types = "Menagerie Tour",
	FEAT_men_companion_boss = "Bodyguard",
	FEAT_shiny_seen_1    = "A Glint in the Grass",
	FEAT_shiny_found_5   = "Magpie Eye",
	FEAT_shiny_found_15  = "Stardust",
	FEAT_shiny_found_30  = "Golden Aura",
	FEAT_shiny_found_50  = "The Little Hippogryph",
	FEAT_shiny_cap_10    = "Glittering Showcase",
	FEAT_shiny_cap_25    = "Living Treasure",
	FEAT_shiny_elite     = "Elite Gleam",
	FEAT_shiny_3stars    = "Flawless Shine",
	FEAT_shiny_sealed    = "Blessed Ground",
	FEAT_shiny_zones_10  = "Shards of Azeroth",
	FEAT_zone_seal_5     = "Seal Bearer",
	FEAT_zone_seal_15    = "Keeper of Seals",
	FEAT_zone_seal_ek    = "Seals of the East",
	FEAT_zone_seal_ka    = "Seals of Kalimdor",
	FEAT_zone_all_biomes = "Biome Tour",
	FEAT_zone_visit_all  = "Every Road",
	FEAT_zone_forever_new = "New Lands",
	FEAT_zone_100_1      = "Zone Complete",
	FEAT_zone_100_10     = "Ten Zones Complete",
	FEAT_zone_golden     = "Solid Gold",
	FEAT_zone_chests_10  = "Chest Hunter",
	FEAT_zone_milestones_25 = "Small Steps, Long Road",
	FEAT_zone_quests_zone = "Nothing Left Undone",
	FEAT_zone_ek_100     = "The East by Heart",
	FEAT_zone_ka_100     = "Kalimdor by Heart",
	FEAT_zone_two_continents = "Two Continents in a Day",
	FEAT_day_mission_25  = "Reliable",
	FEAT_day_mission_100 = "Tireless",
	FEAT_day_perfect_10  = "Perfect Days",
	FEAT_day_weekly_all  = "Week Wrapped Up",
	FEAT_day_inn_30      = "Regular at the Bar",
	FEAT_day_travel_100  = "A Hundred Kilometres Together",
	FEAT_day_travel_1000 = "A Thousand Kilometres Together",
	FEAT_day_days_30     = "A Month Together",
	FEAT_day_days_365    = "A Year Together",
	FEAT_day_pets_100    = "Endless Cuddles",
	FEAT_soc_card_1      = "Pleased to Meet You",
	FEAT_soc_card_10     = "Address Book",
	FEAT_soc_showcase    = "Full Showcase",
	FEAT_soc_guild_feat  = "Talk of the Guild",
	FEAT_soc_guild_cheer = "Cheerleader",
	FEAT_soc_group_capture = "Hunting Party",
	FEAT_soc_title       = "Stage Name",
	FEAT_fun_name        = "Christening",
	FEAT_fun_dance       = "Dances with Beasts",
	FEAT_fun_hogger_kill = "Not Afraid of Hogger",
	FEAT_fun_hogger_capture = "Hogger on a Leash",
	FEAT_fun_murlocs     = "Mrgl Mrgl!",
	FEAT_fun_critter     = "Little Critter",
	FEAT_fun_night_owl   = "Night Owl",
	FEAT_fun_birthday    = "Happy Birthday",
	FEAT_meta_shiny      = "All That Glitters",
	FEAT_meta_zones      = "Seals and Roads",
	FEAT_meta_trainer    = "Legendary Trainer",
}
ns.RegisterStrings(FR, EN)
-- exposées aux tests (et versées dans les chaînes du catalogue : chaque nom
-- doit exister dans les deux langues)
if ns.KEEP_STRINGS then
	ns.FEAT_MENAGERIE_STRINGS = { fr = FR, en = EN }
	local data = ns.FEAT_DATA_STRINGS
	if data then
		for key, text in pairs(FR) do data.fr[key] = text end
		for key, text in pairs(EN) do data.en[key] = text end
	end
end

if ns.Mark then ns.Mark("FeatsCatMenagerie") end
