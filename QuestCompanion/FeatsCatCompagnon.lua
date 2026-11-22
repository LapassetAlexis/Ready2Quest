-- FeatsCatCompagnon.lua -- hauts faits de QuestCompanion, deuxième édition
-- (3.7.0, étape 1, chantier B2b) : Zones et sceaux, Au jour le jour,
-- Compagnon, Entre dresseurs, Insolite, Tours de force et Grands hauts faits.
-- Catalogue : docs/QC-HAUTS-FAITS.md §7.2 (codes 324 à 447, 104 lignes ;
-- le code 413 reste réservé).
--
-- Chargé juste après FeatsCatJeu.lua (donc avant Feats.lua) : on remplit
-- ns.FEAT_SOURCES / ns.FEAT_LISTS à la première lecture du catalogue. Les
-- enveloppes qui signalent un état en direct sont posées à ADDON_LOADED,
-- quand tous les fichiers du .toc sont chargés (le juke-box, l'histoire des
-- lieux, les surnoms des spécimens viennent après ce fichier) ; elles ne
-- font rien tant que le moteur dort (ns.featsDormant, harnais de tests).
--
-- Sortes de lignes (colonne `calcul` du catalogue) :
--   * retro    : la donnée est déjà dans la sauvegarde (source rétroactive,
--     ou critère existant : compteurs du moteur `streak`, attribués au
--     rattrapage de la connexion par l'enveloppe de ns:FeatRetroScan) ;
--   * etat     : vrai en ce moment ; source rétroactive et enveloppe sur la
--     fonction qui change l'état (ns:FeatTouch) ;
--   * compteur : critère tally / tallymax / tallyset (Tally.lua), jamais
--     rétroactif ;
--   * fonction : clé de compteur réservée à une étape suivante, ligne
--     `pending` (invisible et hors total).
-- Sources qui balaient la collection (spécimens, fiches d'espèce, médailles
-- de zone) : calculées à la demande, gardées tant que la collection ne
-- bouge pas (numéro de série des spécimens, signature des captures).
local ADDON, ns = ...
if ns.blocked then return end

local A, CH = "account", "char"

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function Time() return tonumber(Call(G("time"))) or 0 end
local function Awake() return not ns.featsDormant end
local function Sub(t, key) return type(t) == "table" and type(t[key]) == "table" and t[key] or nil end
local function Touch(topic) if ns.FeatTouch then ns:FeatTouch(topic) end end

ns.FEAT_SOURCES = ns.FEAT_SOURCES or {}
ns.FEAT_LISTS = ns.FEAT_LISTS or {}
local SOURCES, LISTS = ns.FEAT_SOURCES, ns.FEAT_LISTS

-- ---------------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------------
ns.FEAT_PIONEER_YEAR = 2027          -- première capture avant le 1er janvier 2027
ns.FEAT_FIRST_VEIL_YEAR = 2026       -- Voile d'hiver 2026 (15 décembre 2026 au 2 janvier 2027)
ns.FEAT_FULL_BAG = { appat = 10, lasso = 5, sifflet = 3 }
-- cosmétiques du compagnon (CompanionData().unlocked, « sorte:id ») ; les
-- fonds et cadres de fiche de dresseur n'en sont pas
ns.FEAT_WARDROBE_KINDS = { app = true, frame = true, bg = true, orn = true }

-- ---------------------------------------------------------------------------
-- Séries : les échelles prolongées gardent la clé posée par le moteur ; les
-- échelles nouvelles se déclarent ici (même catégorie, même critère, même
-- source, seuils croissants). Les lignes d'avant gagnent leur clé sans
-- changer d'identifiant, de code ni de points.
-- ---------------------------------------------------------------------------
local SERIES_MORE = {
	seals     = { "zone_seal_25", "zone_seal_all" },
	zones100  = { "zone_100_25" },
	missions  = { "day_mission_250", "day_mission_500" },
	rares     = { "day_rare_100" },
	trades    = { "soc_trade_25" },
	cards     = { "soc_card_25" },
}
local SERIES_NEW = {
	medalGold   = { "zone_medal_gold_5", "zone_medal_gold_20" },
	chests      = { "zone_chests_10", "zone_chests_25" },
	golden      = { "zone_golden", "zone_golden_5" },
	milestones  = { "zone_milestones_25", "zone_milestones_100" },
	perfect     = { "day_perfect_10", "day_perfect_30", "day_perfect_100" },
	innDays     = { "day_inn_30", "day_inn_100" },
	weeksDone   = { "day_weekly_10", "day_weekly_25" },
	daysPlayed  = { "day_played_30", "day_played_100", "day_played_365" },
	weekCatch   = { "day_week_1", "day_week_10", "day_week_52" },
	stage       = { "comp_stage_2", "comp_stage_3", "comp_stage_4", "comp_stage_5" },
	radiantTime = { "comp_radiant_60", "comp_radiant_600", "comp_radiant_3000" },
	wishes      = { "comp_wish_10", "comp_wish_50", "comp_wish_250" },
	treats      = { "comp_treat_25", "comp_treat_100", "comp_treat_500" },
	pets        = { "day_pets_100", "comp_pets_500" },
	partners    = { "comp_partners_10", "comp_partners_50" },
	wardrobe    = { "comp_wardrobe_10", "comp_wardrobe_25", "comp_wardrobe_50", "comp_wardrobe_100" },
	shares      = { "soc_share_1", "soc_share_25" },
	guildSeen   = { "soc_guild_cheer", "soc_guild_cheer_100" },
	mentees     = { "soc_mentor_1", "soc_mentor_5", "soc_mentor_10" },
	critters    = { "fun_critter", "fun_critters_10" },
	murlocs     = { "fun_murlocs", "fun_murlocs_10" },
	dances      = { "fun_dance", "fun_dance_100" },
}
-- les paliers de points (critère `points`, un seuil par ligne : hors de
-- ns.FEAT_SERIES, la clé est posée sur chaque ligne, les deux d'avant comprises)
ns.FEAT_POINTS_SERIES = { "meta_points_100", "meta_points_250", "meta_points_500", "meta_points_1000", "meta_points_1500",
	"meta_points_2000", "meta_points_3000", "meta_points_4000", "meta_points_5000" }
do
	local series = ns.FEAT_SERIES
	if type(series) == "table" then
		for key, ids in pairs(SERIES_MORE) do
			local list = series[key]
			if type(list) == "table" then
				local have = {}
				for _, id in ipairs(list) do have[id] = true end
				for _, id in ipairs(ids) do if not have[id] then list[#list + 1] = id end end
			end
		end
		for key, ids in pairs(SERIES_NEW) do
			if series[key] == nil then series[key] = ids end
		end
	end
end
ns.FEAT_COMPAGNON_SERIES = { more = SERIES_MORE, new = SERIES_NEW }

-- ---------------------------------------------------------------------------
-- Collection du compte : signature des captures (fiches d'espèce)
-- ---------------------------------------------------------------------------
local function EachCapture(self, fn)
	local db = self:DB()
	if type(db.capture) == "table" then fn(db.capture, "@account") end
	for key, char in pairs(type(db.chars) == "table" and db.chars or {}) do
		local capture = Sub(Sub(char, "companion"), "capture")
		if capture then fn(capture, key) end
	end
end

local function CaptureSignature(self)
	local parts = {}
	EachCapture(self, function(c, key)
		parts[#parts + 1] = tostring(key) .. ":" .. tostring(c.serial) .. ":" .. tostring(c.count)
	end)
	table.sort(parts)
	return table.concat(parts, "|")
end

-- Fiches d'espèce du compte : brillantes de boss du monde, Lardeur brillant
local scan, scanKey
local function Scan(self)
	local key = CaptureSignature(self)
	if scan and scanKey == key then return scan end
	local s = { shinyBoss = 0, hoggerShiny = 0 }
	local bosses = {}
	EachCapture(self, function(c)
		for npcID, e in pairs(Sub(c, "creatures") or {}) do
			if type(e) == "table" and e.shiny == true then
				local id = tonumber(npcID) or npcID
				if e.class == "worldboss" then bosses[id] = true end
				if id == ns.FEAT_HOGGER then s.hoggerShiny = 1 end
			end
		end
	end)
	for _ in pairs(bosses) do s.shinyBoss = s.shinyBoss + 1 end
	scan, scanKey = s, key
	return s
end

-- Médailles de zone (ZoneMedals.lua, autre chantier : ns:ZoneMedalCounts()
-- rend { [1] = bronze ou mieux, [2] = argent ou mieux, [3] = or }) ; sans la
-- fonction : 0. Relues quand les captures bougent.
local medals, medalsKey
local function Medals(self)
	if type(self.ZoneMedalCounts) ~= "function" then return nil end
	local key = CaptureSignature(self)
	if medals and medalsKey == key then return medals end
	local ok, counts = pcall(self.ZoneMedalCounts, self)
	medals, medalsKey = (ok and type(counts) == "table") and counts or {}, key
	return medals
end

-- Spécimens : jumeaux, surnom = nom du joueur ; relus quand le numéro de
-- série des spécimens change (CaptureSpecimens.lua, Touch)
local specCache = {}
local function Specimens(self)
	local db = self:DB()
	local capture = type(db.capture) == "table" and db.capture or nil
	return capture and type(capture.specimens) == "table" and capture.specimens or nil, capture
end
local function PlayerName()
	local name = Call(G("UnitName"), "player")
	if ns.Plain then name = ns.Plain(name) end
	return type(name) == "string" and name or nil
end
local function Fold(text)
	if type(text) ~= "string" then return nil end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	return ns.AsciiLower and ns.AsciiLower(text) or text:lower()
end
local function SpecScan(self)
	local specimens, capture = Specimens(self)
	if not specimens then return { clones = 0, namesake = 0 } end
	local me = Fold(PlayerName()) or ""
	local key = tostring(capture.specSerial) .. "#" .. me
	if specCache.key == key and specCache.specimens == specimens then return specCache.value end
	local seen, clones, namesake = {}, 0, 0
	for _, spec in pairs(specimens) do
		if type(spec) == "table" then
			local sig = table.concat({ tostring(spec.npc), tostring(spec.shiny and 1 or 0), tostring(spec.stars),
				tostring(spec.size or "normal"), tostring(spec.trait) }, ":")
			if seen[sig] then clones = 1 else seen[sig] = true end
			if me ~= "" and type(spec.nick) == "string" and Fold(spec.nick) == me then namesake = 1 end
		end
	end
	specCache = { key = key, specimens = specimens, value = { clones = clones, namesake = namesake } }
	return specCache.value
end

function ns:FeatCompagnonCacheReset()
	scan, scanKey, medals, medalsKey, specCache = nil, nil, nil, nil, {}
end

-- ---------------------------------------------------------------------------
-- Histoire des lieux : zones racontées (CharData().lore.z, CompanionLore.lua)
-- ---------------------------------------------------------------------------
local loreZones, loreLang
local function LoreZones()
	local raw = ns.LORE_RAW
	if type(raw) ~= "table" then return {} end
	local lang = ns.loreLang or ns.STRINGS_LANG or "fr"
	if loreZones and loreLang == lang then return loreZones end
	local text = raw[lang] or raw.en or raw.fr
	local list, set = {}, {}
	if type(text) == "string" then
		for id in text:gmatch("\nZ\t(%d+)\t") do
			id = tonumber(id)
			if id and not set[id] then set[id] = true; list[#list + 1] = id end
		end
	end
	table.sort(list)
	list.set = set
	loreZones, loreLang = list, lang
	return list
end
ns.FeatLoreZones = LoreZones
local function LoreHeard(self)
	local told = Sub(Sub(self:CharData(), "lore"), "z")
	if not told then return 0 end
	local set, n = LoreZones().set or {}, 0
	for mapID in pairs(told) do if set[tonumber(mapID) or mapID] then n = n + 1 end end
	return n
end

-- ---------------------------------------------------------------------------
-- Sources et listes (première lecture du catalogue)
-- ---------------------------------------------------------------------------
local function Year(at)
	local text = Call(G("date"), "%Y", at)
	if type(text) == "string" and text:find("^%d%d%d%d$") then return tonumber(text) end
	return nil
end

ns.FeatCatalog(function()
	local CAP = ns.FeatTopics("capture", "seal")
	-- Zones et sceaux
	local function Medal(tier)
		return { topics = CAP, get = function(self)
			local counts = Medals(self)
			return counts and tonumber(counts[tier]) or 0
		end }
	end
	SOURCES.medalBronze, SOURCES.medalSilver, SOURCES.medalGold = Medal(1), Medal(2), Medal(3)
	SOURCES.loreHeard = { topics = ns.FeatTopics("lore", "minute"), get = function(self) return LoreHeard(self) end }
	LISTS.loreAll = { topics = SOURCES.loreHeard.topics, items = function()
		local items = {}
		for i = 1, #LoreZones() do items[i] = { "loreHeard", i } end
		return items
	end }

	-- Au jour le jour
	SOURCES.innCards = { topics = ns.FeatTopics("mission"), get = function(self)
		if not self.DailyData then return 0 end
		local _, inn = self:DailyData()
		return inn and tonumber(inn.full) or 0
	end }

	-- Compagnon
	SOURCES.companionStage = { topics = ns.FeatTopics("companion", "level"), get = function(self)
		return tonumber(self:CompanionData().stage) or 0
	end }
	SOURCES.persona = { topics = ns.FeatTopics("companion", "minute"), get = function(self)
		local persona = Sub(self:CompanionData(), "persona")
		return (persona and persona.formed) and 1 or 0
	end }
	SOURCES.wardrobe = { topics = ns.FeatTopics("companion", "zone", "mission", "seal", "shiny", "feat", "minute"),
		get = function(self)
			local n = 0
			for key, on in pairs(Sub(self:CompanionData(), "unlocked") or {}) do
				if on == true and ns.FEAT_WARDROBE_KINDS[tostring(key):match("^(%a+):") or ""] then n = n + 1 end
			end
			return n
		end }
	-- juke-box (au compte : db.juke, Jukebox.lua), lu sans rien écrire
	local function Juke(self) return Sub(self:DB(), "juke") end
	SOURCES.jukeFav = { topics = ns.FeatTopics("juke"), get = function(self)
		local n = 0
		for _, on in pairs(Sub(Juke(self), "fav") or {}) do if on == true then n = n + 1 end end
		return n
	end }
	SOURCES.jukeList = { topics = ns.FeatTopics("juke"), get = function(self)
		for _, list in pairs(Sub(Juke(self), "lists") or {}) do
			if type(list) == "table" and #list > 0 then return 1 end
		end
		return 0
	end }

	-- Insolite
	SOURCES.hoggerPartner = { topics = ns.FeatTopics("companion", "minute"), get = function(self)
		if self.CompanionWinterKey and Call(self.CompanionWinterKey, self) then return 0 end
		local look = self:CompanionData().appearance
		local npc = type(look) == "string" and tonumber(look:match("^cap:(%d+)"))
		return npc == ns.FEAT_HOGGER and 1 or 0
	end }
	SOURCES.hoggerShiny = { topics = ns.FeatTopics("capture", "shiny"), get = function(self) return Scan(self).hoggerShiny end }
	SOURCES.namesake = { topics = ns.FeatTopics("specimen"), get = function(self) return SpecScan(self).namesake end }
	SOURCES.clones = { topics = ns.FeatTopics("specimen", "capture"), get = function(self) return SpecScan(self).clones end }
	SOURCES.fullBag = { topics = ns.FeatTopics("aids", "capture"), get = function(self)
		local db = self:DB()
		local items = Sub(Sub(db, "capture"), "items")
		if not items then return 0 end
		for id, need in pairs(ns.FEAT_FULL_BAG) do
			if (tonumber(items[id]) or 0) < need then return 0 end
		end
		return 1
	end }

	-- Tours de force
	SOURCES.pioneer = { topics = ns.FeatTopics("capture"), get = function(self)
		local at = self.CaptureEarliestAt and Call(self.CaptureEarliestAt, self)
		at = tonumber(at)
		if not at or at <= 0 then return 0 end
		local year = Year(at)
		return (year and year < ns.FEAT_PIONEER_YEAR) and 1 or 0
	end }
	-- le drapeau « winterVeil » (fun_winter_veil) ne se pose qu'en saison,
	-- une fois : sa date dit l'année du Voile fêté
	SOURCES.firstVeil = { topics = ns.FeatTopics("flag"), get = function(self)
		local at = tonumber(self:FeatStore(A).flag.winterVeil)
		if not at or at <= 0 then return 0 end
		local ok, t = pcall(G("date") or os.date, "*t", at)
		if not (ok and type(t) == "table") then return 0 end
		local y = ns.FEAT_FIRST_VEIL_YEAR
		if (t.year == y and t.month == 12 and t.day >= 15) or (t.year == y + 1 and t.month == 1 and t.day <= 2) then return 1 end
		return 0
	end }
	SOURCES.shinyBoss = { topics = ns.FeatTopics("capture", "shiny"), get = function(self) return Scan(self).shinyBoss end }

	-- Grands hauts faits : secrets découverts (lignes `hidden` obtenues)
	SOURCES.secretsFound = { topics = ns.FeatTopics("feat"), get = function(self)
		local n = 0
		for _, def in ipairs(self:FeatDefs()) do
			if def.hidden and self:FeatGot(def) then n = n + 1 end
		end
		return n
	end }
end)

-- ---------------------------------------------------------------------------
-- Catalogue : codes 324 à 447 (413 réservé), docs/QC-HAUTS-FAITS.md §7.2
-- ---------------------------------------------------------------------------
local function T(key, n, scope) return { "tally", key, n, scope } end
local function TS(key, n, scope) return { "tallyset", key, n, scope } end

ns.FEAT_COMPAGNON_IDS = {}
ns.FeatCatalog(function()
	local sealAll = 0
	for _ in ipairs(ns.ZoneIds and ns.ZoneIds(ns.ZONE_CREATURES or {}) or {}) do sealAll = sealAll + 1 end
	if sealAll <= 25 then sealAll = 44 end   -- (données absentes : les 44 zones à espèces de Forever)
	ns.FEAT_SEAL_ALL = sealAll
	local ROWS = {
		-- Zones et sceaux (personnage)
		{ "zone_medal_bronze_1", 324, "zone", 5,  CH, crit = { "count", "medalBronze", 1 }, desc = "FEATD_zone_medal_bronze_1" },
		{ "zone_medal_silver_5", 325, "zone", 10, CH, crit = { "count", "medalSilver", 5 }, desc = "FEATD_zone_medal_silver_5" },
		{ "zone_medal_gold_5",   326, "zone", 25, CH, crit = { "count", "medalGold", 5 }, desc = "FEATD_zone_medal_gold_5", series = "medalGold" },
		{ "zone_medal_gold_20",  327, "zone", 50, CH, crit = { "count", "medalGold", 20 }, desc = "FEATD_zone_medal_gold_20", series = "medalGold",
			reward = { soon = { "cardbg", "card_gold_zones" } } },
		{ "zone_seal_25",        328, "zone", 50, CH, crit = { "count", "seals", 25 }, desc = "FEATD_zone_seal_25", series = "seals" },
		{ "zone_seal_all",       329, "zone", 50, CH, crit = { "count", "seals", sealAll }, desc = "FEATD_zone_seal_all", series = "seals",
			reward = { title = 59 } },
		{ "zone_chests_25",      330, "zone", 25, CH, crit = { "count", "chests", 25 }, series = "chests" },
		{ "zone_golden_5",       331, "zone", 25, CH, crit = { "count", "golden", 5 }, desc = "FEATD_zone_golden_5", series = "golden" },
		{ "zone_100_25",         332, "zone", 50, CH, crit = { "count", "zones100", 25 }, desc = "FEATD_zone_100_25", series = "zones100" },
		{ "zone_lore_10",        333, "zone", 5,  CH, crit = { "count", "loreHeard", 10 }, desc = "FEATD_zone_lore_10" },
		{ "zone_lore_all",       334, "zone", 25, CH, crit = { "list", "loreAll" }, desc = "FEATD_zone_lore_all" },
		{ "zone_milestones_100", 335, "zone", 25, CH, crit = { "count", "milestones", 100 }, desc = "FEATD_zone_milestones_100", series = "milestones" },
		-- Au jour le jour (personnage)
		{ "day_mission_250",  336, "day", 25, CH, crit = { "count", "missions", 250 }, desc = "FEATD_day_missions", series = "missions" },
		{ "day_mission_500",  337, "day", 50, CH, crit = { "count", "missions", 500 }, desc = "FEATD_day_missions", series = "missions",
			reward = { soon = { "orn", "feat_volunteer" } } },
		{ "day_perfect_30",   338, "day", 25, CH, crit = { "count", "perfect", 30 }, desc = "FEATD_day_perfect", series = "perfect" },
		{ "day_perfect_100",  339, "day", 50, CH, crit = { "count", "perfect", 100 }, desc = "FEATD_day_perfect", series = "perfect",
			reward = { soon = { "bg", "feat_perfect" } } },
		{ "day_weekly_10",    340, "day", 25, CH, crit = T("weeklyAll", 10, CH), desc = "FEATD_day_weekly", series = "weeksDone" },
		{ "day_weekly_25",    341, "day", 50, CH, crit = T("weeklyAll", 25, CH), desc = "FEATD_day_weekly", series = "weeksDone" },
		{ "day_inn_100",      342, "day", 25, CH, crit = { "count", "innDays", 100 }, series = "innDays" },
		{ "day_inn_cards_10", 343, "day", 10, CH, crit = { "count", "innCards", 10 }, desc = "FEATD_day_inn_cards_10" },
		{ "day_rare_100",     344, "day", 25, CH, crit = { "count", "placeRare", 100 }, desc = "FEATD_day_rare_100", series = "rares" },
		{ "day_played_30",    345, "day", 10, CH, crit = T("days", 30, CH), desc = "FEATD_day_played_30", series = "daysPlayed" },
		{ "day_played_100",   346, "day", 25, CH, crit = T("days", 100, CH), desc = "FEATD_day_played", series = "daysPlayed" },
		{ "day_played_365",   347, "day", 50, CH, crit = T("days", 365, CH), desc = "FEATD_day_played", series = "daysPlayed" },
		{ "day_week_1",       348, "day", 5,  CH, crit = T("weekCatch", 1), desc = "FEATD_day_week_1", series = "weekCatch" },
		{ "day_week_10",      349, "day", 10, CH, crit = T("weekCatch", 10), desc = "FEATD_day_week", series = "weekCatch" },
		{ "day_week_52",      350, "day", 50, CH, crit = T("weekCatch", 52), desc = "FEATD_day_week", series = "weekCatch" },
		{ "day_swarm_10",     351, "day", 10, CH, crit = TS("swarmZones", 10), desc = "FEATD_day_swarm_10" },
		-- Compagnon (personnage)
		{ "comp_stage_2",      352, "comp", 5,  CH, crit = { "count", "companionStage", 2 }, desc = "FEATD_comp_stage_2", series = "stage" },
		{ "comp_stage_3",      353, "comp", 5,  CH, crit = { "count", "companionStage", 3 }, desc = "FEATD_comp_stage_3", series = "stage" },
		{ "comp_stage_4",      354, "comp", 10, CH, crit = { "count", "companionStage", 4 }, desc = "FEATD_comp_stage_4", series = "stage" },
		{ "comp_stage_5",      355, "comp", 25, CH, crit = { "count", "companionStage", 5 }, desc = "FEATD_comp_stage_5", series = "stage" },
		{ "comp_persona",      356, "comp", 10, CH, crit = { "count", "persona", 1 }, desc = "FEATD_comp_persona" },
		{ "comp_radiant_60",   357, "comp", 10, CH, crit = T("radiantMin", 60, CH), desc = "FEATD_comp_radiant_60", series = "radiantTime" },
		{ "comp_radiant_600",  358, "comp", 25, CH, crit = T("radiantMin", 600, CH), desc = "FEATD_comp_radiant_600", series = "radiantTime" },
		{ "comp_radiant_3000", 359, "comp", 50, CH, crit = T("radiantMin", 3000, CH), desc = "FEATD_comp_radiant_3000", series = "radiantTime",
			reward = { title = 60 } },
		{ "comp_wish_10",      360, "comp", 5,  CH, crit = T("wish", 10, CH), desc = "FEATD_comp_wish", series = "wishes" },
		{ "comp_wish_50",      361, "comp", 10, CH, crit = T("wish", 50, CH), desc = "FEATD_comp_wish", series = "wishes" },
		{ "comp_wish_250",     362, "comp", 25, CH, crit = T("wish", 250, CH), desc = "FEATD_comp_wish", series = "wishes", reward = { title = 64 } },
		{ "comp_treat_25",     363, "comp", 5,  CH, crit = T("treat", 25, CH), desc = "FEATD_comp_treat", series = "treats" },
		{ "comp_treat_100",    364, "comp", 10, CH, crit = T("treat", 100, CH), desc = "FEATD_comp_treat", series = "treats" },
		{ "comp_treat_500",    365, "comp", 25, CH, crit = T("treat", 500, CH), desc = "FEATD_comp_treat", series = "treats" },
		{ "comp_treat_all",    366, "comp", 10, CH, crit = TS("treatKinds", 5, CH), desc = "FEATD_comp_treat_all" },
		{ "comp_pets_500",     367, "comp", 25, CH, crit = { "streak", "pets", 500 }, series = "pets" },
		{ "comp_partners_10",  368, "comp", 10, CH, crit = TS("partners", 10, CH), desc = "FEATD_comp_partners", series = "partners" },
		{ "comp_partners_50",  369, "comp", 25, CH, crit = TS("partners", 50, CH), desc = "FEATD_comp_partners", series = "partners" },
		{ "comp_wardrobe_10",  370, "comp", 5,  CH, crit = { "count", "wardrobe", 10 }, desc = "FEATD_comp_wardrobe", series = "wardrobe" },
		{ "comp_wardrobe_25",  371, "comp", 10, CH, crit = { "count", "wardrobe", 25 }, desc = "FEATD_comp_wardrobe", series = "wardrobe" },
		{ "comp_wardrobe_50",  372, "comp", 25, CH, crit = { "count", "wardrobe", 50 }, desc = "FEATD_comp_wardrobe", series = "wardrobe" },
		{ "comp_wardrobe_100", 373, "comp", 50, CH, crit = { "count", "wardrobe", 100 }, desc = "FEATD_comp_wardrobe", series = "wardrobe",
			reward = { title = 65 } },
		{ "comp_juke_fav_10",  374, "comp", 5,  CH, crit = { "count", "jukeFav", 10 }, desc = "FEATD_comp_juke_fav_10" },
		{ "comp_juke_list",    375, "comp", 5,  CH, crit = { "count", "jukeList", 1 }, desc = "FEATD_comp_juke_list" },
		{ "comp_juke_100",     376, "comp", 10, CH, crit = TS("jukeHeard", 100), desc = "FEATD_comp_juke_100" },
		{ "comp_jokes_25",     377, "comp", 5,  CH, crit = T("joke", 25, CH), desc = "FEATD_comp_jokes_25" },
		-- Entre dresseurs (compte)
		{ "soc_share_1",          397, "soc", 5,  A, crit = T("share", 1), desc = "FEATD_soc_share_1", series = "shares" },
		{ "soc_share_25",         398, "soc", 10, A, crit = T("share", 25), desc = "FEATD_soc_share_25", series = "shares" },
		{ "soc_trade_25",         399, "soc", 25, A, crit = { "streak", "trades", 25 }, desc = "FEATD_soc_trade_25", series = "trades",
			reward = { title = 66 } },
		{ "soc_trade_partners_5", 400, "soc", 10, A, crit = TS("tradePartners", 5), desc = "FEATD_soc_trade_partners_5" },
		{ "soc_guild_feat_10",    401, "soc", 10, A, crit = T("guildSent", 10), desc = "FEATD_soc_guild_feat_10" },
		{ "soc_guild_cheer_100",  402, "soc", 10, A, crit = { "streak", "guildSeen", 100 }, series = "guildSeen" },
		{ "soc_group_50",         403, "soc", 10, A, crit = T("captureGroup", 50), desc = "FEATD_soc_group_50" },
		{ "soc_holders_10",       404, "soc", 5,  A, crit = TS("holders", 10), desc = "FEATD_soc_holders_10" },
		-- l'ensemble des fiches consultées du moteur (50 noms au plus) : son compteur
		{ "soc_card_25",          405, "soc", 25, A, crit = { "streak", "cards", 25 }, series = "cards",
			reward = { soon = { "cardbg", "card_directory" } } },
		{ "soc_photo_1",          406, "soc", 5,  A, crit = T("souvenir", 1), desc = "FEATD_soc_photo_1" },
		{ "soc_code_1",           407, "soc", 5,  A, crit = T("codeCopy", 1), desc = "FEATD_soc_code_1" },
		{ "soc_code_5",           408, "soc", 10, A, crit = T("codeOpen", 5), desc = "FEATD_soc_code_5" },
		{ "soc_compare",          409, "soc", 5,  A, crit = T("compare", 1), desc = "FEATD_soc_compare" },
		{ "soc_mentor_1",         410, "soc", 5,  A, crit = TS("mentees", 1), desc = "FEATD_soc_mentor_1", series = "mentees" },
		{ "soc_mentor_5",         411, "soc", 10, A, crit = TS("mentees", 5), desc = "FEATD_soc_mentor", series = "mentees" },
		{ "soc_mentor_10",        412, "soc", 25, A, crit = TS("mentees", 10), desc = "FEATD_soc_mentor", series = "mentees",
			reward = { title = 67 } },
		-- (code 413 réservé : soc_pack_25, pas dans ce lot)
		{ "soc_discord",          414, "soc", 10, A, crit = T("discordWord", 1), desc = "FEATD_soc_discord",
			reward = { soon = { "orn", "feat_worlds" } } },
		{ "soc_feedback",         415, "soc", 5,  A, crit = T("feedback", 1), desc = "FEATD_soc_feedback" },
		-- Insolite (compte ; dix secrets)
		{ "fun_critters_10",    416, "fun", 10, A, crit = { "count", "critter", 10 }, desc = "FEATD_fun_critters_10", series = "critters" },
		{ "fun_murlocs_10",     417, "fun", 10, A, crit = { "count", "murlocs", 10 }, series = "murlocs" },
		{ "fun_dance_100",      418, "fun", 5,  A, crit = { "streak", "dances", 100 }, series = "dances" },
		{ "fun_winter_all",     419, "fun", 10, A, crit = TS("winterMates", 3), desc = "FEATD_fun_winter_all" },
		{ "fun_hogger_partner", 420, "fun", 10, A, crit = { "count", "hoggerPartner", 1 }, desc = "FEATD_fun_hogger_partner", hidden = true },
		{ "fun_hogger_shiny",   421, "fun", 25, A, crit = { "count", "hoggerShiny", 1 }, desc = "FEATD_fun_hogger_shiny", hidden = true },
		{ "fun_namesake",       422, "fun", 5,  A, crit = { "count", "namesake", 1 }, desc = "FEATD_fun_namesake", hidden = true },
		{ "fun_clones",         423, "fun", 5,  A, crit = { "count", "clones", 1 }, desc = "FEATD_fun_clones", hidden = true },
		{ "fun_close_call",     424, "fun", 10, A, crit = T("closeCall", 1), desc = "FEATD_fun_close_call", hidden = true },
		{ "fun_boss_miss",      425, "fun", 5,  A, crit = T("bossFail", 1), desc = "FEATD_fun_boss_miss", hidden = true },
		{ "fun_winter_song",    426, "fun", 5,  A, crit = T("winterSong", 1), desc = "FEATD_fun_winter_song", hidden = true },
		{ "fun_small_game",     427, "fun", 5,  A, crit = T("smallGame", 1), desc = "FEATD_fun_small_game", hidden = true },
		{ "fun_wake",           428, "fun", 5,  A, crit = T("wake", 1, CH), desc = "FEATD_fun_wake", hidden = true },
		{ "fun_full_bag",       429, "fun", 5,  A, crit = { "count", "fullBag", 1 }, desc = "FEATD_fun_full_bag", hidden = true },
		-- Tours de force (compte, 0 point, hors des totaux)
		{ "fos_pioneer",       430, "fos", 0, A, crit = { "count", "pioneer", 1 }, desc = "FEATD_fos_pioneer", reward = { title = 68 } },
		{ "fos_first_veil",    431, "fos", 0, A, crit = { "count", "firstVeil", 1 }, desc = "FEATD_fos_first_veil" },
		{ "fos_unfindable",    432, "fos", 0, A, crit = T("unfindable", 1), desc = "FEATD_fos_unfindable",
			reward = { soon = { "orn", "feat_unfindable" } } },
		{ "fos_golden_legend", 433, "fos", 0, A, crit = { "count", "shinyBoss", 1 }, desc = "FEATD_fos_golden_legend" },
		-- Grands hauts faits (compte)
		{ "meta_points_100",  434, "meta", 5,  A, crit = { "points", 100 },  series = "points" },
		{ "meta_points_250",  435, "meta", 5,  A, crit = { "points", 250 },  series = "points" },
		{ "meta_points_1000", 436, "meta", 10, A, crit = { "points", 1000 }, series = "points", reward = { soon = { "cardframe", "card_rank_silver" } } },
		{ "meta_points_2000", 437, "meta", 25, A, crit = { "points", 2000 }, series = "points", reward = { soon = { "cardframe", "card_rank_gold" } } },
		{ "meta_points_3000", 438, "meta", 25, A, crit = { "points", 3000 }, series = "points" },
		{ "meta_points_4000", 439, "meta", 50, A, crit = { "points", 4000 }, series = "points", reward = { soon = { "cardframe", "card_rank_glow" } } },
		{ "meta_points_5000", 440, "meta", 50, A, crit = { "points", 5000 }, series = "points", reward = { title = 69 } },
		{ "meta_spec",    441, "meta", 25, A, crit = { "meta", "spec", 15 } },
		{ "meta_comp",    442, "meta", 25, A, crit = { "meta", "comp", 15 } },
		{ "meta_shop",    443, "meta", 25, A, crit = { "meta", "shop", 10 } },
		{ "meta_soc",     444, "meta", 25, A, crit = { "meta", "soc", 10 }, reward = { title = 70 } },
		{ "meta_fun",     445, "meta", 25, A, crit = { "meta", "fun", 15 }, reward = { title = 71 } },
		{ "meta_secrets", 446, "meta", 25, A, crit = { "count", "secretsFound", 5 }, desc = "FEATD_meta_secrets" },
		-- grands hauts faits de catégorie de la famille « dresseur »
		{ "meta_all",     447, "meta", 50, A, crit = { "meta", { "meta_menagerie", "meta_shiny", "meta_spec", "meta_shop", "meta_soc",
			"meta_fun" } }, desc = "FEATD_meta_all", reward = { title = 72 } },
	}
	-- lignes d'avant : la clé de leur échelle (paliers de points), et le cadre
	-- de fiche de « Un nom qui circule » (500 points), ajouté à ce qu'elle donne
	local points = {}
	for _, id in ipairs(ns.FEAT_POINTS_SERIES) do points[id] = true end
	for _, def in ipairs(ns.FEAT_DEFS) do
		if points[def.id] and def.series == nil then def.series = "points" end
		if def.id == "meta_points_500" then
			local reward = def.reward
			if type(reward) ~= "table" then def.reward = { soon = { "cardframe", "card_rank_bronze" } }
			elseif not (reward.soon or reward.cosmetic) then reward.soon = { "cardframe", "card_rank_bronze" } end
		end
	end
	for _, row in ipairs(ROWS) do
		ns.FeatAdd(row)
		ns.FEAT_COMPAGNON_IDS[#ns.FEAT_COMPAGNON_IDS + 1] = row[1]
	end
	if ns.FeatResolveSoon then ns.FeatResolveSoon() end
end)

-- ---------------------------------------------------------------------------
-- Rattrapage : les lignes sur un compteur du moteur (`streak`) dont la donnée
-- est déjà dans la sauvegarde ; le moteur ne rattrape pas ce critère à la
-- connexion (il le réévalue au prochain sujet « flag ») : on les ajoute au
-- rattrapage silencieux de ns:FeatRetroScan.
-- ---------------------------------------------------------------------------
ns.FEAT_RETRO_STREAKS = { "comp_pets_500", "soc_trade_25", "soc_guild_cheer_100", "soc_card_25", "fun_dance_100" }
local retroHooked = false
local function HookRetro()
	if retroHooked or type(ns.FeatRetroScan) ~= "function" then return false end
	retroHooked = true
	local base = ns.FeatRetroScan
	function ns:FeatRetroScan(...)
		local found = base(self, ...)
		if type(found) ~= "table" then found = {} end
		for _, id in ipairs(ns.FEAT_RETRO_STREAKS) do
			local def = self:FeatDef(id)
			if def and not def.pending and not self:FeatGot(def) then
				local cur, max, state = self:FeatProgress(def)
				if state == "open" and max > 0 and cur >= max and self:FeatAward(def, { silent = true }) then
					found[#found + 1] = def
				end
			end
		end
		return found
	end
	return true
end
ns.FeatCompagnonHookRetro = HookRetro

-- ---------------------------------------------------------------------------
-- En direct : les fonctions qui changent un état signalent leur sujet
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

local hooked = false
function ns:FeatCompagnonHook()
	if hooked then return false end
	hooked = true
	HookRetro()
	local function TouchOf(topic) return function() Touch(topic) end end
	-- histoire d'un lieu racontée (CharData().lore.z noté juste après)
	Wrap("LoreTell", function(_, ok) if ok then Touch("lore") end end)
	-- stade, caractère, apparence, cosmétiques du compagnon
	Wrap("CompanionCheckStage", TouchOf("companion"))
	Wrap("PersonaForm", TouchOf("companion"))
	Wrap("CompanionSetAppearance", function(_, def) if def then Touch("companion") end end)
	Wrap("CompanionCheckUnlocks", TouchOf("companion"))
	Wrap("DailyGrantAppearance", function(_, fresh) if fresh then Touch("companion") end end)
	-- juke-box : favoris et listes
	Wrap("JukeToggleFav", function(_, on) if on ~= nil then Touch("juke") end end)
	Wrap("JukeListToggle", function(_, on) if on ~= nil then Touch("juke") end end)
	-- spécimens : ajout (capture, échange), surnom
	Wrap("SpecimenAdd", function(_, id) if id ~= nil then Touch("specimen") end end)
	Wrap("SpecimenSetNick", TouchOf("specimen"))
	-- aides de capture rangées dans la besace
	Wrap("CaptureGrant", function(_, result) if result == "ok" then Touch("aids") end end)
	return true
end

-- posées quand tous les fichiers sont chargés (comme Tally.lua)
do
	local ok, frame = pcall(CreateFrame, "Frame")
	if ok and frame then
		frame:RegisterEvent("ADDON_LOADED")
		frame:SetScript("OnEvent", function(f, _, name)
			if name ~= ADDON then return end
			if f.UnregisterEvent then f:UnregisterEvent("ADDON_LOADED") end
			local done, err = pcall(ns.FeatCompagnonHook, ns)
			if not done and ns.RecordError then ns:RecordError("feats:compagnon", err) end
		end)
		ns.featCompagnonFrame = frame
	end
end

-- ---------------------------------------------------------------------------
-- Chaînes : noms (FEAT_<id>), descriptions (FEATD_*), indices (FEATH_<id>)
-- ---------------------------------------------------------------------------
local FR = {
	FEATD_zone_medal_bronze_1 = "Gagner la médaille de bronze d'une zone (25 %% des espèces)",
	FEATD_zone_medal_silver_5 = "Avoir %d zones à la médaille d'argent (50 %%)",
	FEATD_zone_medal_gold_5   = "Avoir %d zones à la médaille d'or (75 %%)",
	FEATD_zone_medal_gold_20  = "Avoir %d zones à la médaille d'or",
	FEATD_zone_seal_25        = "Sceller %d zones",
	FEATD_zone_seal_all       = "Sceller les %d zones à sceau",
	FEATD_zone_golden_5       = "Rendre %d zones dorées",
	FEATD_zone_100_25         = "Accomplir %d zones à 100 %%",
	FEATD_zone_lore_10        = "Écouter l'histoire de %d zones",
	FEATD_zone_lore_all       = "Écouter l'histoire de toutes les zones racontées (%d)",
	FEATD_zone_milestones_100 = "Franchir %d paliers de zone",
	FEATD_day_missions        = "Accomplir %d missions du compagnon",
	FEATD_day_perfect         = "Boucler toutes les missions du jour %d fois",
	FEATD_day_weekly          = "Boucler toutes les missions de %d semaines",
	FEATD_day_inn_cards_10    = "Remplir %d cartes d'auberge",
	FEATD_day_rare_100        = "Vaincre %d ennemis rares",
	FEATD_day_played_30       = "Jouer %d jours différents (pas forcément d'affilée)",
	FEATD_day_played          = "Jouer %d jours différents",
	FEATD_day_week_1          = "Capturer la créature de la semaine",
	FEATD_day_week            = "Capturer %d créatures de la semaine",
	FEATD_day_swarm_10        = "Capturer l'espèce en pullulation dans %d zones différentes",
	FEATD_comp_stage_2        = "Voir ton compagnon atteindre le deuxième stade",
	FEATD_comp_stage_3        = "Voir ton compagnon atteindre le troisième stade",
	FEATD_comp_stage_4        = "Voir ton compagnon atteindre le quatrième stade",
	FEATD_comp_stage_5        = "Voir ton compagnon atteindre le dernier stade",
	FEATD_comp_persona        = "Voir le caractère de ta mascotte se former",
	FEATD_comp_radiant_60     = "Passer %d minutes Rayonnant (au total)",
	FEATD_comp_radiant_600    = "Passer 10 heures Rayonnant",
	FEATD_comp_radiant_3000   = "Passer 50 heures Rayonnant",
	FEATD_comp_wish           = "Combler %d envies",
	FEATD_comp_treat          = "Donner %d friandises",
	FEATD_comp_treat_all      = "Donner les %d sortes de friandises",
	FEATD_comp_partners       = "Voyager avec %d créatures différentes",
	FEATD_comp_wardrobe       = "Débloquer %d cosmétiques du compagnon",
	FEATD_comp_juke_fav_10    = "Avoir %d morceaux favoris au juke-box",
	FEATD_comp_juke_list      = "Créer une liste au juke-box",
	FEATD_comp_juke_100       = "Écouter %d morceaux différents",
	FEATD_comp_jokes_25       = "Écouter %d blagues du compagnon",
	FEATD_soc_share_1         = "Partager un moment dans le chat",
	FEATD_soc_share_25        = "Partager %d moments",
	FEATD_soc_trade_25        = "Conclure %d échanges",
	FEATD_soc_trade_partners_5 = "Échanger avec %d dresseurs différents",
	FEATD_soc_guild_feat_10   = "Annoncer %d exploits à ta guilde",
	FEATD_soc_group_50        = "Capturer %d créatures en groupe",
	FEATD_soc_holders_10      = "Croiser %d dresseurs",
	FEATD_soc_photo_1         = "Créer une carte souvenir",
	FEATD_soc_code_1          = "Copier ton code de dresseur",
	FEATD_soc_code_5          = "Ouvrir %d fiches reçues par code",
	FEATD_soc_compare         = "Comparer tes hauts faits avec ceux d'un dresseur",
	FEATD_soc_mentor_1        = "Faire découvrir Quest Companion à un joueur",
	FEATD_soc_mentor          = "Faire découvrir Quest Companion à %d joueurs",
	FEATD_soc_discord         = "Saisir le mot de la version trouvé sur le Discord (page Communauté)",
	FEATD_soc_feedback        = "Composer un avis sur la page Communauté",
	FEATD_fun_critters_10     = "Capturer %d bestioles différentes",
	FEATD_fun_winter_all      = "Voyager avec les %d compagnons du Voile d'hiver",
	FEATD_fun_hogger_partner  = "Partir avec Lardeur",
	FEATD_fun_hogger_shiny    = "Capturer Lardeur en version brillante",
	FEATD_fun_namesake        = "Donner ton propre nom à un spécimen",
	FEATD_fun_clones          = "Avoir deux spécimens identiques (espèce, étoiles, taille, caractère)",
	FEATD_fun_close_call      = "Capturer une créature juste après avoir survécu de justesse",
	FEATD_fun_boss_miss       = "Rater la capture d'un boss du monde",
	FEATD_fun_winter_song     = "Écouter un morceau au juke-box, la nuit, pendant le Voile d'hiver",
	FEATD_fun_small_game      = "Au niveau 60, capturer une créature de niveau 5 ou moins",
	FEATD_fun_wake            = "Réveiller le compagnon d'une caresse",
	FEATD_fun_full_bag        = "Avoir en même temps 10 appâts, 5 lassos et 3 sifflets",
	FEATD_fos_pioneer         = "Avoir fait ta première capture avant le 1er janvier 2027",
	FEATD_fos_first_veil      = "Avoir fêté le Voile d'hiver 2026 avec un compagnon de saison",
	FEATD_fos_unfindable      = "Capturer une brillante à 3 étoiles et de taille rare (1 sur 53 571)",
	FEATD_fos_golden_legend   = "Capturer un boss du monde en version brillante",
	FEATD_meta_secrets        = "Découvrir %d hauts faits secrets",
	FEATD_meta_all            = "Obtenir tous les grands hauts faits de dresseur",
	FEAT_zone_medal_bronze_1 = "Premier bronze",
	FEAT_zone_medal_silver_5 = "Cinq d'argent",
	FEAT_zone_medal_gold_5   = "Cinq d'or",
	FEAT_zone_medal_gold_20  = "Vingt d'or",
	FEAT_zone_seal_25        = "Grand sceau",
	FEAT_zone_seal_all       = "Azeroth scellé",
	FEAT_zone_chests_25      = "Coffres en série",
	FEAT_zone_golden_5       = "Cinq zones d'or",
	FEAT_zone_100_25         = "Vingt-cinq zones accomplies",
	FEAT_zone_lore_10        = "Oreille attentive",
	FEAT_zone_lore_all       = "Mémoire des lieux",
	FEAT_zone_milestones_100 = "Cent paliers",
	FEAT_day_mission_250     = "Toujours volontaire",
	FEAT_day_mission_500     = "Cinq cents missions",
	FEAT_day_perfect_30      = "Trente journées parfaites",
	FEAT_day_perfect_100     = "Cent journées parfaites",
	FEAT_day_weekly_10       = "Dix semaines bouclées",
	FEAT_day_weekly_25       = "Vingt-cinq semaines bouclées",
	FEAT_day_inn_100         = "Cent nuits à l'auberge",
	FEAT_day_inn_cards_10    = "Habitué de la maison",
	FEAT_day_rare_100        = "Cent têtes mises à prix",
	FEAT_day_played_30       = "Trente jours de route",
	FEAT_day_played_100      = "Cent jours de route",
	FEAT_day_played_365      = "Une année de route",
	FEAT_day_week_1          = "Prise de la semaine",
	FEAT_day_week_10         = "Dix prises de la semaine",
	FEAT_day_week_52         = "Une année de prises",
	FEAT_day_swarm_10        = "Chasseur de pullulations",
	FEAT_comp_stage_2        = "Il grandit",
	FEAT_comp_stage_3        = "Aguerri",
	FEAT_comp_stage_4        = "Vaillant",
	FEAT_comp_stage_5        = "Légendaire",
	FEAT_comp_persona        = "Un sacré caractère",
	FEAT_comp_radiant_60     = "Une heure de bonheur",
	FEAT_comp_radiant_600    = "Dix heures de bonheur",
	FEAT_comp_radiant_3000   = "Bonheur au long cours",
	FEAT_comp_wish_10        = "Aux petits soins",
	FEAT_comp_wish_50        = "Devin",
	FEAT_comp_wish_250       = "Ses désirs sont des ordres",
	FEAT_comp_treat_25       = "Bonne table",
	FEAT_comp_treat_100      = "Cordon-bleu",
	FEAT_comp_treat_500      = "Gourmandise",
	FEAT_comp_treat_all      = "Menu dégustation",
	FEAT_comp_pets_500       = "Mille caresses, ou presque",
	FEAT_comp_partners_10    = "Chacun son tour",
	FEAT_comp_partners_50    = "Toute la troupe",
	FEAT_comp_wardrobe_10    = "Garde-robe",
	FEAT_comp_wardrobe_25    = "Belle garde-robe",
	FEAT_comp_wardrobe_50    = "Grande garde-robe",
	FEAT_comp_wardrobe_100   = "Dressing complet",
	FEAT_comp_juke_fav_10    = "Mélomane",
	FEAT_comp_juke_list      = "Ma sélection",
	FEAT_comp_juke_100       = "Tour de chant",
	FEAT_comp_jokes_25       = "Bon public",
	FEAT_soc_share_1         = "Fier de sa prise",
	FEAT_soc_share_25        = "Grand bavard",
	FEAT_soc_trade_25        = "Grand négociant",
	FEAT_soc_trade_partners_5 = "Réseau",
	FEAT_soc_guild_feat_10   = "Porte-voix",
	FEAT_soc_guild_cheer_100 = "Premier rang",
	FEAT_soc_group_50        = "Meute soudée",
	FEAT_soc_holders_10      = "Du beau monde",
	FEAT_soc_card_25         = "Annuaire",
	FEAT_soc_photo_1         = "Souriez !",
	FEAT_soc_code_1          = "Carte de visite",
	FEAT_soc_code_5          = "Correspondants",
	FEAT_soc_compare         = "Jeu des différences",
	FEAT_soc_mentor_1        = "Passeur",
	FEAT_soc_mentor_5        = "Cinq filleuls",
	FEAT_soc_mentor_10       = "Dix filleuls",
	FEAT_soc_discord         = "Porte ouverte",
	FEAT_soc_feedback        = "Mon grain de sel",
	FEAT_fun_critters_10     = "Arche de poche",
	FEAT_fun_murlocs_10      = "Mrgl mrgl mrgl !",
	FEAT_fun_dance_100       = "Roi de la piste",
	FEAT_fun_winter_all      = "Trois de saison",
	FEAT_fun_hogger_partner  = "Lardeur en promenade",
	FEAT_fun_hogger_shiny    = "Lardeur doré",
	FEAT_fun_namesake        = "Mon double",
	FEAT_fun_clones          = "Jumeaux",
	FEAT_fun_close_call      = "Du bout des doigts",
	FEAT_fun_boss_miss       = "Tout ça pour ça",
	FEAT_fun_winter_song     = "Douce nuit",
	FEAT_fun_small_game      = "Petit gibier",
	FEAT_fun_wake            = "Debout là-dedans !",
	FEAT_fun_full_bag        = "Besace pleine",
	FEAT_fos_pioneer         = "Pionnier",
	FEAT_fos_first_veil      = "Premier Voile d'hiver",
	FEAT_fos_unfindable      = "L'introuvable",
	FEAT_fos_golden_legend   = "Légende dorée",
	FEAT_meta_points_100     = "Premiers lauriers",
	FEAT_meta_points_250     = "On en parle",
	FEAT_meta_points_1000    = "Réputation faite",
	FEAT_meta_points_2000    = "Illustre",
	FEAT_meta_points_3000    = "Célèbre dans tout Azeroth",
	FEAT_meta_points_4000    = "Légende vivante",
	FEAT_meta_points_5000    = "Au sommet de la renommée",
	FEAT_meta_spec           = "Maître des spécimens",
	FEAT_meta_comp           = "Meilleur ami",
	FEAT_meta_shop           = "Pilier de l'Échoppe",
	FEAT_meta_soc            = "Figure connue",
	FEAT_meta_fun            = "Cabinet de curiosités",
	FEAT_meta_secrets        = "Dans la confidence",
	FEAT_meta_all            = "Dresseur accompli",
	-- indices des secrets : le compagnon met sur la voie
	FEATH_fun_hogger_partner = "Il paraît qu'un gros gnoll grognon rêve de partir en balade… avec toi.",
	FEATH_fun_hogger_shiny   = "On raconte que la terreur d'Elwynn brille, certains jours. J'aimerais bien voir ça !",
	FEATH_fun_namesake       = "Et si l'une de tes créatures portait un nom que tu connais très, très bien ?",
	FEATH_fun_clones         = "Je vois double… Deux bestioles pareilles en tout point, ça existe, tu crois ?",
	FEATH_fun_close_call     = "Rien de tel qu'une belle prise quand on vient d'échapper au pire.",
	FEATH_fun_boss_miss      = "Les géants du monde ne se laissent pas toujours faire. Un échec, ça forge le caractère !",
	FEATH_fun_winter_song    = "Une mélodie sous les étoiles, quand la neige et les cadeaux sont de sortie…",
	FEATH_fun_small_game     = "Même les plus grands héros aiment parfois chasser… tout petit.",
	FEATH_fun_wake           = "Zzz… Si je pique du nez, tu sais comment me tirer du sommeil en douceur ?",
	FEATH_fun_full_bag       = "Une besace qui déborde de tout ce qu'il faut pour capturer : quel bonheur ce serait !",
}
local EN = {
	FEATD_zone_medal_bronze_1 = "Earn a zone's bronze medal (25%% of its species)",
	FEATD_zone_medal_silver_5 = "Have %d zones at the silver medal (50%%)",
	FEATD_zone_medal_gold_5   = "Have %d zones at the gold medal (75%%)",
	FEATD_zone_medal_gold_20  = "Have %d zones at the gold medal",
	FEATD_zone_seal_25        = "Seal %d zones",
	FEATD_zone_seal_all       = "Seal all %d sealable zones",
	FEATD_zone_golden_5       = "Turn %d zones golden",
	FEATD_zone_100_25         = "Complete %d zones at 100%%",
	FEATD_zone_lore_10        = "Hear the story of %d zones",
	FEATD_zone_lore_all       = "Hear the story of every zone that has one (%d)",
	FEATD_zone_milestones_100 = "Reach %d zone milestones",
	FEATD_day_missions        = "Complete %d companion missions",
	FEATD_day_perfect         = "Finish all daily missions %d times",
	FEATD_day_weekly          = "Finish every mission of %d weeks",
	FEATD_day_inn_cards_10    = "Fill %d inn cards",
	FEATD_day_rare_100        = "Defeat %d rare enemies",
	FEATD_day_played_30       = "Play on %d different days (not necessarily in a row)",
	FEATD_day_played          = "Play on %d different days",
	FEATD_day_week_1          = "Capture the creature of the week",
	FEATD_day_week            = "Capture %d creatures of the week",
	FEATD_day_swarm_10        = "Capture the swarming species in %d different zones",
	FEATD_comp_stage_2        = "See your companion reach its second stage",
	FEATD_comp_stage_3        = "See your companion reach its third stage",
	FEATD_comp_stage_4        = "See your companion reach its fourth stage",
	FEATD_comp_stage_5        = "See your companion reach its final stage",
	FEATD_comp_persona        = "See your mascot's personality take shape",
	FEATD_comp_radiant_60     = "Spend %d minutes Radiant (in total)",
	FEATD_comp_radiant_600    = "Spend 10 hours Radiant",
	FEATD_comp_radiant_3000   = "Spend 50 hours Radiant",
	FEATD_comp_wish           = "Fulfil %d wishes",
	FEATD_comp_treat          = "Give %d treats",
	FEATD_comp_treat_all      = "Give all %d kinds of treats",
	FEATD_comp_partners       = "Travel with %d different creatures",
	FEATD_comp_wardrobe       = "Unlock %d companion cosmetics",
	FEATD_comp_juke_fav_10    = "Have %d favourite tracks in the jukebox",
	FEATD_comp_juke_list      = "Make a jukebox playlist",
	FEATD_comp_juke_100       = "Listen to %d different tracks",
	FEATD_comp_jokes_25       = "Hear %d of your companion's jokes",
	FEATD_soc_share_1         = "Share a moment in chat",
	FEATD_soc_share_25        = "Share %d moments",
	FEATD_soc_trade_25        = "Complete %d trades",
	FEATD_soc_trade_partners_5 = "Trade with %d different trainers",
	FEATD_soc_guild_feat_10   = "Announce %d feats to your guild",
	FEATD_soc_group_50        = "Capture %d creatures in a group",
	FEATD_soc_holders_10      = "Cross paths with %d trainers",
	FEATD_soc_photo_1         = "Make a keepsake card",
	FEATD_soc_code_1          = "Copy your trainer code",
	FEATD_soc_code_5          = "Open %d trainer cards received by code",
	FEATD_soc_compare         = "Compare your achievements with another trainer's",
	FEATD_soc_mentor_1        = "Introduce a player to Quest Companion",
	FEATD_soc_mentor          = "Introduce %d players to Quest Companion",
	FEATD_soc_discord         = "Enter this version's word, found on the Discord (Community page)",
	FEATD_soc_feedback        = "Write a review on the Community page",
	FEATD_fun_critters_10     = "Capture %d different critters",
	FEATD_fun_winter_all      = "Travel with all %d Winter Veil companions",
	FEATD_fun_hogger_partner  = "Head out with Hogger",
	FEATD_fun_hogger_shiny    = "Capture a shiny Hogger",
	FEATD_fun_namesake        = "Give a specimen your own name",
	FEATD_fun_clones          = "Own two identical specimens (species, stars, size, personality)",
	FEATD_fun_close_call      = "Capture a creature right after a narrow escape",
	FEATD_fun_boss_miss       = "Fail to capture a world boss",
	FEATD_fun_winter_song     = "Listen to a jukebox track at night during Winter Veil",
	FEATD_fun_small_game      = "At level 60, capture a creature of level 5 or lower",
	FEATD_fun_wake            = "Wake your companion with a pat",
	FEATD_fun_full_bag        = "Hold 10 baits, 5 lassos and 3 whistles at once",
	FEATD_fos_pioneer         = "Make your first capture before January 1, 2027",
	FEATD_fos_first_veil      = "Celebrate Winter Veil 2026 with a seasonal companion",
	FEATD_fos_unfindable      = "Capture a 3-star shiny of a rare size (1 in 53,571)",
	FEATD_fos_golden_legend   = "Capture a shiny world boss",
	FEATD_meta_secrets        = "Uncover %d secret achievements",
	FEATD_meta_all            = "Earn every trainer Feat of Feats",
	FEAT_zone_medal_bronze_1 = "First Bronze",
	FEAT_zone_medal_silver_5 = "Silver Five",
	FEAT_zone_medal_gold_5   = "Golden Five",
	FEAT_zone_medal_gold_20  = "Twenty Golds",
	FEAT_zone_seal_25        = "Great Seal",
	FEAT_zone_seal_all       = "Azeroth Sealed",
	FEAT_zone_chests_25      = "Chest After Chest",
	FEAT_zone_golden_5       = "Five Golden Zones",
	FEAT_zone_100_25         = "Twenty-Five Zones Complete",
	FEAT_zone_lore_10        = "All Ears",
	FEAT_zone_lore_all       = "Memory of Places",
	FEAT_zone_milestones_100 = "A Hundred Milestones",
	FEAT_day_mission_250     = "Always Volunteering",
	FEAT_day_mission_500     = "Five Hundred Missions",
	FEAT_day_perfect_30      = "Thirty Perfect Days",
	FEAT_day_perfect_100     = "A Hundred Perfect Days",
	FEAT_day_weekly_10       = "Ten Weeks Wrapped Up",
	FEAT_day_weekly_25       = "Twenty-Five Weeks Wrapped Up",
	FEAT_day_inn_100         = "A Hundred Nights at the Inn",
	FEAT_day_inn_cards_10    = "Regular Guest",
	FEAT_day_rare_100        = "A Hundred Bounties",
	FEAT_day_played_30       = "Thirty Days on the Road",
	FEAT_day_played_100      = "A Hundred Days on the Road",
	FEAT_day_played_365      = "A Year on the Road",
	FEAT_day_week_1          = "Catch of the Week",
	FEAT_day_week_10         = "Ten Catches of the Week",
	FEAT_day_week_52         = "A Year of Catches",
	FEAT_day_swarm_10        = "Swarm Chaser",
	FEAT_comp_stage_2        = "Growing Up",
	FEAT_comp_stage_3        = "Seasoned",
	FEAT_comp_stage_4        = "Valiant",
	FEAT_comp_stage_5        = "Legendary",
	FEAT_comp_persona        = "Quite a Character",
	FEAT_comp_radiant_60     = "An Hour of Bliss",
	FEAT_comp_radiant_600    = "Ten Hours of Bliss",
	FEAT_comp_radiant_3000   = "Lasting Happiness",
	FEAT_comp_wish_10        = "Doting",
	FEAT_comp_wish_50        = "Mind Reader",
	FEAT_comp_wish_250       = "At Its Beck and Call",
	FEAT_comp_treat_25       = "Fine Dining",
	FEAT_comp_treat_100      = "Cordon Bleu",
	FEAT_comp_treat_500      = "Sweet Tooth",
	FEAT_comp_treat_all      = "Tasting Menu",
	FEAT_comp_pets_500       = "A Thousand Pats, Almost",
	FEAT_comp_partners_10    = "Taking Turns",
	FEAT_comp_partners_50    = "The Whole Troupe",
	FEAT_comp_wardrobe_10    = "Wardrobe",
	FEAT_comp_wardrobe_25    = "Fine Wardrobe",
	FEAT_comp_wardrobe_50    = "Grand Wardrobe",
	FEAT_comp_wardrobe_100   = "Walk-In Closet",
	FEAT_comp_juke_fav_10    = "Music Lover",
	FEAT_comp_juke_list      = "My Mixtape",
	FEAT_comp_juke_100       = "Song Recital",
	FEAT_comp_jokes_25       = "Easy Crowd",
	FEAT_soc_share_1         = "Proud of the Catch",
	FEAT_soc_share_25        = "Chatterbox",
	FEAT_soc_trade_25        = "Master Trader",
	FEAT_soc_trade_partners_5 = "Networking",
	FEAT_soc_guild_feat_10   = "Town Crier",
	FEAT_soc_guild_cheer_100 = "Front Row",
	FEAT_soc_group_50        = "Tight-Knit Pack",
	FEAT_soc_holders_10      = "Good Company",
	FEAT_soc_card_25         = "Who's Who",
	FEAT_soc_photo_1         = "Say Cheese!",
	FEAT_soc_code_1          = "Calling Card",
	FEAT_soc_code_5          = "Pen Pals",
	FEAT_soc_compare         = "Spot the Difference",
	FEAT_soc_mentor_1        = "Word of Mouth",
	FEAT_soc_mentor_5        = "Five Protégés",
	FEAT_soc_mentor_10       = "Ten Protégés",
	FEAT_soc_discord         = "Open Door",
	FEAT_soc_feedback        = "My Two Cents",
	FEAT_fun_critters_10     = "Pocket Ark",
	FEAT_fun_murlocs_10      = "Mrgl Mrgl Mrgl!",
	FEAT_fun_dance_100       = "Lord of the Dance",
	FEAT_fun_winter_all      = "Seasonal Trio",
	FEAT_fun_hogger_partner  = "Walkies with Hogger",
	FEAT_fun_hogger_shiny    = "Golden Hogger",
	FEAT_fun_namesake        = "Mini-Me",
	FEAT_fun_clones          = "Double Trouble",
	FEAT_fun_close_call      = "By the Skin of Your Teeth",
	FEAT_fun_boss_miss       = "All That for Nothing",
	FEAT_fun_winter_song     = "Silent Night",
	FEAT_fun_small_game      = "Small Fry",
	FEAT_fun_wake            = "Rise and Shine!",
	FEAT_fun_full_bag        = "Packed to the Brim",
	FEAT_fos_pioneer         = "Pioneer",
	FEAT_fos_first_veil      = "First Winter Veil",
	FEAT_fos_unfindable      = "The Unfindable",
	FEAT_fos_golden_legend   = "Golden Legend",
	FEAT_meta_points_100     = "First Laurels",
	FEAT_meta_points_250     = "Talk of the Town",
	FEAT_meta_points_1000    = "Reputation Made",
	FEAT_meta_points_2000    = "Illustrious",
	FEAT_meta_points_3000    = "Famous Across Azeroth",
	FEAT_meta_points_4000    = "Living Legend",
	FEAT_meta_points_5000    = "Height of Fame",
	FEAT_meta_spec           = "Specimen Master",
	FEAT_meta_comp           = "Best Friend",
	FEAT_meta_shop           = "Pillar of the Stall",
	FEAT_meta_soc            = "Familiar Face",
	FEAT_meta_fun            = "Curio Cabinet",
	FEAT_meta_secrets        = "In on the Secret",
	FEAT_meta_all            = "Accomplished Trainer",
	FEATH_fun_hogger_partner = "Word is a certain grumpy gnoll dreams of going for a stroll… with you.",
	FEATH_fun_hogger_shiny   = "They say the terror of Elwynn sparkles on some days. I'd love to see that!",
	FEATH_fun_namesake       = "What if one of your creatures wore a name you know very, very well?",
	FEATH_fun_clones         = "Am I seeing double? Two creatures alike in every way, could that even happen?",
	FEATH_fun_close_call     = "Nothing beats a good catch right after a narrow escape.",
	FEATH_fun_boss_miss      = "The world's giants don't always go quietly. A miss builds character!",
	FEATH_fun_winter_song    = "A tune under the stars, when the snow and the presents come out…",
	FEATH_fun_small_game     = "Even the greatest heroes like to hunt something… really small now and then.",
	FEATH_fun_wake           = "Zzz… If I nod off, do you know a gentle way to wake me up?",
	FEATH_fun_full_bag       = "A satchel overflowing with everything a catcher could need: what a dream that would be!",
}
ns.RegisterStrings(FR, EN)
-- exposées aux tests (et versées dans les chaînes du catalogue : chaque nom
-- doit exister dans les deux langues)
if ns.KEEP_STRINGS then
	ns.FEAT_COMPAGNON_STRINGS = { fr = FR, en = EN }
	local data = ns.FEAT_DATA_STRINGS
	if data then
		for key, text in pairs(FR) do data.fr[key] = text end
		for key, text in pairs(EN) do data.en[key] = text end
	end
end

if ns.Mark then ns.Mark("FeatsCatCompagnon") end
