-- FeatsCatJeu.lua -- hauts faits de QuestCompanion, lot C : le jeu lui-même
-- (2.7.x). Catégories par personnage : Personnage, Donjons et raids, Métiers,
-- Quêtes, réputations et honneur ; les lignes d'Insolite qui lisent une
-- statistique du client ; les grands hauts faits qui en dépendent.
-- Conception : docs/QC-HAUTS-FAITS.md §2.6 à §2.11 et §2.13.
--
-- Chargé après FeatsData.lua (FEAT_DEFS, FeatAdd) et avant Feats.lua : on
-- n'appelle le moteur qu'à l'exécution. Les lignes déjà posées par le lot A
-- (char_level_*, char_kills_*, char_hearth_50, dng_visit_*) restent dans
-- FeatsData.lua, telles quelles.
--
-- Détection, du plus sûr au moins sûr :
--   * notre propre suivi (UnitLevel, plus haut GetMoney vu, métiers lus,
--     réputations lues, compteurs d'événements PLAYER_DEAD, QUEST_TURNED_IN,
--     vols, montures, émotes ; boss tués en instance : UNIT_DIED / PARTY_KILL
--     d'un npcID connu, ou ENCOUNTER_END réussi) ;
--   * les statistiques du client (GetStatistic, ns:FeatStat : jamais lues en
--     combat, relues au plus une fois par minute) : elles couvrent toute la vie
--     du personnage, donc le rattrapage silencieux à la connexion ;
--   * une ligne qui n'a qu'une statistique pas encore vérifiée en jeu est
--     `pending` (grisée « détection bientôt disponible », jamais attribuée).
local ADDON, ns = ...
if ns.blocked then return end

local STAT_EXTRA = {}       -- statistiques lues hors critère « stat » (diagnostic)
local SCAN_TTL = 2          -- métiers et réputations relus au plus toutes les 2 s
local KILL_MEMORY = 300     -- un même boss compté une fois par 5 min (deux sources)
local EPIC_SPEED = 13.5     -- monture rapide au sol (m/s ; course 7, monture 60 % 11,2)

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e = pcall(fn, ...)
	if ok then return a, b, c, d, e end
	return nil
end
local function Num(value) return tonumber(ns.Plain(value)) end
local function Now() return (ns.Now and ns.Now()) or 0 end
local function Awake() return not ns.featsDormant and (ns.CompanionOn == nil or ns.CompanionOn()) end
local function Touch(topic) if ns.FeatTouch then ns:FeatTouch(topic) end end
local function Extra(ids) for _, id in ipairs(ids or {}) do STAT_EXTRA[id] = true end end

-- Compteur tenu par le moteur (CharData().feats.ctr, ou db.feats.ctr)
local function Ctr(self, key, scope)
	return tonumber(self:FeatStore(scope == "account" and "account" or "char").ctr[key]) or 0
end
local function CtrMax(self, key, value)
	local ctr = self:FeatStore("char").ctr
	if value and value > (tonumber(ctr[key]) or 0) then ctr[key] = value end
	return tonumber(ctr[key]) or 0
end
local function Bump(key, scope)
	if not Awake() then return end
	ns:FeatCount(key, 1, scope)
end

-- Plus grande des statistiques (nil : aucune lisible)
local function StatMax(self, ids)
	local best
	for _, id in ipairs(ids or {}) do
		local value = self.FeatStat and self:FeatStat(id)
		if value and (not best or value > best) then best = value end
	end
	return best
end

-- ---------------------------------------------------------------------------
-- Boss : statistique de victoires (§2.13), npcID (UNIT_DIED / PARTY_KILL en
-- instance), rencontre (ENCOUNTER_END, table DungeonEncounter de Forever
-- 1.60.1), donjon (relevé d'entrée : repli des boss sans autre détection)
-- ---------------------------------------------------------------------------
-- Une chaîne par boss : « npcIDs/rencontres/statistiques[/donjon] » (listes
-- séparées par des virgules, champ vide = rien), lue à la demande
local BOSSES = {
	-- palier 1
	rfc       = "11519/2735/15027",
	wc        = "3654/592/15028",
	dm        = "639/2747/63570",
	sfk       = "4275/2755/1092",
	stocks    = "1716/2760/15029",
	bfd       = "4829/2767,2891,2910/6137",
	thanes    = "/3496/63573",
	lordaeron = "/3354/63571",
	-- palier 2
	gnomer    = "7800/2772,2940/6140",
	rfk       = "4421/2778/6139",
	sm        = "3977,3976/450/6786,1093",
	rfd       = "7358/2785/6141",
	dalaran   = "/3303/63572",
	-- palier 3
	ulda      = "2748/554/6142",
	zf        = "7267/600/1094",
	mara      = "12201/429/6143",
	st        = "5709/493,2959,3584/6144",
	alcaz     = "//63575/alcaz",
	-- palier 4
	brd       = "9019/2790/1095",
	lbrs      = "9568/275/6145",
	ubrs      = "10363/3069/1096",
	dmaul     = "11501/368/6146",
	scholo    = "1853/2801/15030",
	strat     = "10440/484/1097,15031",
	shaper    = "//63574/shaper",
	-- raids
	ony       = "10184/1084/1098",
	mc        = "11502/672/",
	zg        = "14834/793/",
	bwl       = "11583/617/",
	aq20      = "15339/723/",
	aq40      = "15727/717/",
	naxx      = "15990/1114/",
	hyjal     = "//63580",
	barrow    = "//63581",
}
ns.FEAT_BOSSES = BOSSES
-- boss du monde connus (repli du rang de la table de zone)
local WORLD_BOSSES = { [6109] = true, [12397] = true, [14887] = true, [14888] = true, [14889] = true, [14890] = true }

-- Champ d'un boss : 1 npcIDs, 2 rencontres, 3 statistiques (listes de
-- nombres), 4 donjon de repli (texte ou nil)
local function BossField(key, field)
	local spec = BOSSES[key]
	if not spec then return nil end
	local index = 0
	for part in (spec .. "/"):gmatch("([^/]*)/") do
		index = index + 1
		if index == field then
			if field == 4 then return part ~= "" and part or nil end
			local ids = {}
			for id in part:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
			return ids
		end
	end
	return field ~= 4 and {} or nil
end
ns.FeatBossField = BossField

-- npcID et rencontre -> boss, construits à la première mort vue
local bossByNpc, bossByEnc
local function BossIndex()
	if not bossByNpc then
		bossByNpc, bossByEnc = {}, {}
		for key in pairs(BOSSES) do
			for _, id in ipairs(BossField(key, 1)) do bossByNpc[id] = key end
			for _, id in ipairs(BossField(key, 2)) do bossByEnc[id] = key end
		end
	end
	return bossByNpc, bossByEnc
end

local SOURCES = ns.FEAT_SOURCES or {}
ns.FEAT_SOURCES = SOURCES
local LISTS = ns.FEAT_LISTS or {}
ns.FEAT_LISTS = LISTS

-- Un boss : vaincu (1+) d'après la statistique, notre suivi, ou à défaut
-- l'entrée dans son donjon quand rien d'autre ne peut le dire. Sources
-- « boss_<clé> » créées à la première lecture (métatable de FEAT_SOURCES).
local BOSS_TOPICS = ns.FeatTopics("boss", "kill", "place")
local function BossSource(key)
	return {
		topics = BOSS_TOPICS,
		get = function(self)
			local own = Ctr(self, "boss_" .. key)
			local stats = BossField(key, 3)
			local stat = #stats > 0 and StatMax(self, stats) or nil
			local best = math.max(own, stat or 0)
			local entry = BossField(key, 4)
			if best == 0 and entry and stat == nil then
				local journal = self:CharData().journal
				local stamps = type(journal) == "table" and type(journal.stamps) == "table" and journal.stamps or {}
				if stamps["dungeon:" .. entry] ~= nil then return 1 end
			end
			return best
		end,
	}
end
do
	local meta = getmetatable(SOURCES) or {}
	local base = meta.__index
	meta.__index = function(t, name)
		local key = type(name) == "string" and name:match("^boss_(.+)$")
		if key and BOSSES[key] then
			local source = BossSource(key)
			rawset(t, name, source)
			return source
		end
		if type(base) == "function" then return base(t, name) end
		if type(base) == "table" then return base[name] end
		return nil
	end
	setmetatable(SOURCES, meta)
end

-- Une mort de boss vue par l'une des sources ; rend la clé comptée (ou nil)
local recentKills = {}
function ns:FeatBossKill(npcID, encounterID)
	local byNpc, byEnc = BossIndex()
	local key = (npcID and byNpc[tonumber(npcID)]) or (encounterID and byEnc[tonumber(encounterID)])
	if not key or not Awake() then return nil end
	local now = Now()
	local last = recentKills[key]
	if last and now >= last and now - last < KILL_MEMORY then return nil end
	recentKills[key] = now
	self:FeatCount("boss_" .. key, 1)
	Touch("boss")
	return key
end
function ns:FeatBossKillReset() recentKills = {} end

local function NpcOf(guid)
	guid = ns.Plain(guid)
	if ns.BestiaryNpcID then return ns.BestiaryNpcID(guid) end
	if type(guid) ~= "string" then return nil end
	return tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$"))
end

-- ---------------------------------------------------------------------------
-- Sources : notre suivi, enrichi par les statistiques quand elles se lisent
-- ---------------------------------------------------------------------------
-- plus haut solde vu (cuivre, CharData().feats.ctr.goldMax), en pièces d'or
Extra({ 334 })
SOURCES.goldMax = {
	topics = ns.FeatTopics("money"),
	get = function(self)
		local copper = CtrMax(self, "goldMax", Num(Call(G("GetMoney"))))
		return math.floor(math.max(copper, StatMax(self, { 334 }) or 0) / 10000)
	end,
}
SOURCES.mountSeen = { topics = ns.FeatTopics("mount"), retro = false, get = function(self) return Ctr(self, "mounted") > 0 and 1 or 0 end }
SOURCES.taxiRides = { topics = ns.FeatTopics("taxi"), retro = false, get = function(self) return Ctr(self, "taxi") end }
SOURCES.deaths = { topics = ns.FeatTopics("death"), retro = false, get = function(self) return Ctr(self, "deaths") end }
SOURCES.questsDone = { topics = ns.FeatTopics("quest"), retro = false, get = function(self) return Ctr(self, "quests") end }
SOURCES.emotes = { topics = ns.FeatTopics("emote"), retro = false, get = function(self) return Ctr(self, "emotes", "account") end }
SOURCES.raidEntered = { topics = ns.FeatTopics("instance"), retro = false,
	get = function(self) return self:FeatStore("char").flag.raidEnter and 1 or 0 end }
SOURCES.worldBoss = { topics = ns.FeatTopics("kill"), retro = false, get = function(self) return Ctr(self, "worldBoss") end }
SOURCES.captureInside = { topics = ns.FeatTopics("capture"), retro = false, get = function(self) return Ctr(self, "captureInside") end }

-- Métiers : ns:PlayerProfessions (dernière liste complète gardée par
-- personnage), principaux = tout sauf cuisine, pêche, secourisme
local SECONDARY = { cooking = 1524, fishing = 1519, firstaid = 281 }
local PRIMARY_STATS = { 1527, 1532, 1535, 1536, 1537, 1538, 1541, 1542, 1544 }
Extra(PRIMARY_STATS); Extra({ 1524, 1519, 281, 1199, 1200, 1201 })
local memo = {}
local function Memo(key, fn)
	local entry, now = memo[key], Now()
	if entry and now >= entry.at and now - entry.at < SCAN_TTL then return entry.value end
	local ok, value = pcall(fn)
	memo[key] = { at = now, value = ok and value or nil }
	return memo[key].value
end
function ns:FeatJeuMemoReset() memo = {} end

local function Profs(self)
	return Memo("profs", function()
		local out = { primary = {}, rank = {} }
		for _, entry in ipairs(self.PlayerProfessions and self:PlayerProfessions() or {}) do
			local rank = tonumber(type(entry) == "table" and entry.rank) or 0
			if rank > 0 and entry.key then
				out.rank[entry.key] = math.max(out.rank[entry.key] or 0, rank)
				if not SECONDARY[entry.key] then out.primary[#out.primary + 1] = rank end
			end
		end
		return out
	end) or { primary = {}, rank = {} }
end
SOURCES.profPrimary = { topics = ns.FeatTopics("prof"), get = function(self) return #Profs(self).primary end }
SOURCES.profBest = {
	topics = ns.FeatTopics("prof"),
	get = function(self)
		local best = StatMax(self, PRIMARY_STATS) or 0
		for _, rank in ipairs(Profs(self).primary) do best = math.max(best, rank) end
		return best
	end,
}
SOURCES.profPrimary300 = {
	topics = ns.FeatTopics("prof"),
	get = function(self)
		local count = 0
		for _, rank in ipairs(Profs(self).primary) do if rank >= 300 then count = count + 1 end end
		return count
	end,
}
for key, stat in pairs(SECONDARY) do
	SOURCES["prof_" .. key] = { topics = ns.FeatTopics("prof"),
		get = function(self) return math.max(Profs(self).rank[key] or 0, StatMax(self, { stat }) or 0) end }
end
SOURCES.gathered = {
	topics = ns.FeatTopics("prof"),
	get = function(self)
		local total = 0
		for _, entry in pairs(self.GatheringData and self:GatheringData() or {}) do
			if type(entry) == "table" then total = total + (tonumber(entry.count) or 0) end
		end
		return total
	end,
}

-- Réputations : C_Reputation (moteur récent) ou GetFactionInfo ; le plus
-- haut compte vu est gardé (comme les statistiques « Most factions at… »).
-- nil sans aucune API : le critère reste sur la statistique (ou grisé).
-- Une catégorie repliée cache ses factions : on ne déplie rien (l'interface
-- du joueur), la statistique complète au rattrapage.
local function ScanReputation()
	local honored, exalted, ok = 0, 0, false
	local function Add(standing, header, hasRep)
		standing = tonumber(standing)
		if not standing or (header and not hasRep) then return end
		if standing >= 6 then honored = honored + 1 end
		if standing >= 8 then exalted = exalted + 1 end
	end
	local api = G("C_Reputation")
	if type(api) == "table" and type(api.GetNumFactions) == "function" and type(api.GetFactionDataByIndex) == "function" then
		local total = Num(Call(api.GetNumFactions))
		if total then
			ok = true
			for index = 1, total do
				local data = Call(api.GetFactionDataByIndex, index)
				if type(data) == "table" then Add(Num(data.reaction), data.isHeader, data.isHeaderWithRep) end
			end
		end
	end
	if not ok then
		local total = Num(Call(G("GetNumFactions")))
		if total and type(G("GetFactionInfo")) == "function" then
			ok = true
			for index = 1, total do
				local packed = { pcall(G("GetFactionInfo"), index) }
				if packed[1] then
					local header, hasRep = packed[10], packed[12]
					Add(Num(packed[4]), header == true or header == 1, hasRep == true or hasRep == 1)
				end
			end
		end
	end
	if not ok then return nil end
	return { honored = honored, exalted = exalted }
end
local function RepSource(field)
	return {
		topics = ns.FeatTopics("rep"),
		get = function(self)
			local scan = Memo("rep", ScanReputation)
			local kept = CtrMax(self, "rep_" .. field, scan and scan[field] or nil)
			if not scan and kept == 0 then return nil end
			return kept
		end,
	}
end
SOURCES.repHonored = RepSource("honored")
SOURCES.repExalted = RepSource("exalted")

-- Dernière quête de la chaîne de Lord Valthalak : ns.FEAT_VALTHALAK_QUEST,
-- id à relever (QuestV2) ; d'ici là la ligne reste « à vérifier »
SOURCES.questValthalak = {
	topics = ns.FeatTopics("quest"),
	get = function()
		local id = ns.FEAT_VALTHALAK_QUEST
		if not id then return 0 end
		local log = G("C_QuestLog")
		local fn = type(log) == "table" and log.IsQuestFlaggedCompleted or G("IsQuestFlaggedCompleted")
		return Call(fn, id) and 1 or 0
	end,
}

-- Hauts faits obtenus d'une catégorie (métas composés)
local function EarnedIn(self, cat)
	local count = 0
	for _, def in ipairs(self.FeatDefs and self:FeatDefs() or {}) do
		if def.cat == cat and self:FeatGot(def) then count = count + 1 end
	end
	return count
end
for _, cat in ipairs({ "dng", "prof", "quest" }) do
	SOURCES["featsCat_" .. cat] = { topics = ns.FeatTopics("feat"), get = function(self) return EarnedIn(self, cat) end }
end

-- ---------------------------------------------------------------------------
-- Listes : paliers de donjons (boss final ; entrée seule quand aucun boss
-- n'est connu), héros d'Azeroth
-- ---------------------------------------------------------------------------
local function BossList(items)
	return { topics = ns.FeatTopics("boss", "kill", "place"),
		items = function()
			local out = {}
			for i, item in ipairs(items) do
				out[i] = BOSSES[item] and { "boss_" .. item, 1 } or ("dungeon:" .. item)
			end
			return out
		end }
end
LISTS.dngTier1 = BossList({ "rfc", "wc", "dm", "sfk", "stocks", "bfd", "thanes", "lordaeron" })
LISTS.dngTier2 = BossList({ "gnomer", "rfk", "sm", "rfd", "dalaran", "excavation", "drowned" })
LISTS.dngTier3 = BossList({ "ulda", "zf", "mara", "st", "kroldok", "alcaz" })
LISTS.dngTier4 = BossList({ "brd", "lbrs", "ubrs", "dmaul", "scholo", "strat", "blackmaw", "shaper" })
LISTS.hero = { topics = ns.FeatTopics("feat", "level"),
	items = function() return { { "level", 60 }, { "featsCat_dng", 5 }, { "featsCat_prof", 3 }, { "featsCat_quest", 3 } } end }

-- ---------------------------------------------------------------------------
-- Catalogue (codes n = rang du document §2 ; pending = ⚠️ sans repli),
-- construit à la première lecture (ns.FeatCatalog, FeatsData.lua)
-- ---------------------------------------------------------------------------
local C, A = "char", "account"
ns.FeatCatalog(function()
	for _, row in ipairs({
		-- Personnage (les niveaux, les victimes et la pierre de foyer : FeatsData.lua)
		{ "char_gold_100",    92, "char", 10, C, crit = { "count", "goldMax", 100 } },
		{ "char_gold_1000",   93, "char", 25, C, crit = { "count", "goldMax", 1000 }, reward = { title = 22 } },
		{ "char_gold_looted", 94, "char", 10, C, crit = { "stat", { 333 }, 1000000 }, desc = "FEATD_goldLooted", pending = true },
		{ "char_mount",       95, "char", 10, C, crit = { "stat", { 339 }, 1, alt = "mountSeen" }, desc = "FEATD_mount" },
		{ "char_mount_epic",  96, "char", 25, C, crit = { "flag", "mountEpic" }, desc = "FEATD_mountEpic", pending = true },
		{ "char_flight_25",   97, "char", 10, C, crit = { "stat", { 349 }, 25, alt = "taxiRides" }, desc = "FEATD_flight" },
		{ "char_epic",       101, "char", 10, C, crit = { "stat", { 341, 342 }, 1 }, desc = "FEATD_epic", pending = true },
		{ "char_deaths_1",   102, "char", 5,  C, crit = { "stat", { 60 }, 1, alt = "deaths" }, desc = "FEATD_death1" },
		{ "char_deaths_100", 103, "char", 10, C, crit = { "stat", { 60 }, 100, alt = "deaths" }, desc = "FEATD_deaths", reward = { title = 23 } },
		{ "char_camp_25",    104, "char", 10, C, crit = { "stat", { 64222 }, 25 }, desc = "FEATD_camp", pending = true,
			reward = { cosmetic = { "bg", "feat_campfire" } } },
		{ "char_food_500",   105, "char", 10, C, crit = { "stat", { 346, 347 }, 500 }, desc = "FEATD_food", pending = true },
		{ "char_potions_100", 106, "char", 10, C, crit = { "stat", { 345, 922, 923, 811 }, 100 }, desc = "FEATD_potions", pending = true },
		-- Donjons et raids (les entrées : FeatsData.lua)
		{ "dng_runs_50",     111, "dng", 10, C, crit = { "stat", { 932 }, 50 }, desc = "FEATD_runs", pending = true },
		{ "dng_tier1",       112, "dng", 10, C, crit = { "list", "dngTier1" }, reward = { aids = { lasso = 2 } } },
		{ "dng_tier2",       113, "dng", 10, C, crit = { "list", "dngTier2" }, reward = { aids = { lasso = 2 } } },
		{ "dng_tier3",       114, "dng", 25, C, crit = { "list", "dngTier3" }, reward = { aids = { sifflet = 1 } } },
		{ "dng_tier4",       115, "dng", 25, C, crit = { "list", "dngTier4" }, reward = { aids = { sifflet = 1 } } },
		{ "dng_raid_enter",  116, "dng", 10, C, crit = { "stat", { 934, 64184 }, 1, alt = "raidEntered" }, desc = "FEATD_raidEnter" },
		{ "dng_raid_ony",    117, "dng", 25, C, crit = { "count", "boss_ony", 1 }, desc = "FEATD_boss_ony" },
		{ "dng_raid_mc",     118, "dng", 25, C, crit = { "count", "boss_mc", 1 }, desc = "FEATD_boss_mc" },
		{ "dng_raid_zg",     119, "dng", 25, C, crit = { "count", "boss_zg", 1 }, desc = "FEATD_boss_zg" },
		{ "dng_raid_bwl",    120, "dng", 25, C, crit = { "count", "boss_bwl", 1 }, desc = "FEATD_boss_bwl" },
		{ "dng_raid_aq20",   121, "dng", 25, C, crit = { "count", "boss_aq20", 1 }, desc = "FEATD_boss_aq20" },
		{ "dng_raid_aq40",   122, "dng", 50, C, crit = { "count", "boss_aq40", 1 }, desc = "FEATD_boss_aq40",
			reward = { cosmetic = { "orn", "feat_eye" } } },
		{ "dng_raid_naxx",   123, "dng", 50, C, crit = { "count", "boss_naxx", 1 }, desc = "FEATD_boss_naxx", reward = { title = 25 } },
		{ "dng_raid_hyjal",  124, "dng", 25, C, crit = { "count", "boss_hyjal", 1 }, desc = "FEATD_boss_hyjal", pending = true,
			reward = { cosmetic = { "orn", "feat_wildcrown" } } },
		{ "dng_raid_barrow", 125, "dng", 25, C, crit = { "count", "boss_barrow", 1 }, desc = "FEATD_boss_barrow", pending = true },
		{ "dng_world_boss",  126, "dng", 25, C, crit = { "count", "worldBoss", 1 } },
		{ "dng_capture_inside", 127, "dng", 10, C, crit = { "count", "captureInside", 1 } },
		-- Métiers
		{ "prof_first",      128, "prof", 5,  C, crit = { "count", "profPrimary", 1 } },
		{ "prof_150",        129, "prof", 10, C, crit = { "count", "profBest", 150 } },
		{ "prof_225",        130, "prof", 10, C, crit = { "count", "profBest", 225 } },
		{ "prof_300",        131, "prof", 25, C, crit = { "count", "profBest", 300 }, reward = { title = 26 } },
		{ "prof_double_300", 132, "prof", 25, C, crit = { "count", "profPrimary300", 2 }, reward = { title = 27 } },
		{ "prof_cook_300",   133, "prof", 10, C, crit = { "count", "prof_cooking", 300 }, reward = { title = 28 } },
		{ "prof_fish_300",   134, "prof", 10, C, crit = { "count", "prof_fishing", 300 }, reward = { title = 29 } },
		{ "prof_aid_300",    135, "prof", 10, C, crit = { "count", "prof_firstaid", 300 } },
		{ "prof_secondary_all", 136, "prof", 25, C, crit = { "meta", { "prof_cook_300", "prof_fish_300", "prof_aid_300" } },
			desc = "FEATD_profSecondary" },
		{ "prof_fish_250",   137, "prof", 10, C, crit = { "stat", { 1518 }, 250 }, desc = "FEATD_fishCaught", pending = true },
		{ "prof_gather_100", 138, "prof", 5,  C, crit = { "count", "gathered", 100 } },
		{ "prof_gather_1000", 139, "prof", 10, C, crit = { "count", "gathered", 1000 } },
		-- Quêtes, réputations et honneur
		{ "quest_10",        140, "quest", 5,  C, crit = { "stat", { 98 }, 10, alt = "questsDone" }, desc = "FEATD_quests" },
		{ "quest_100",       141, "quest", 10, C, crit = { "stat", { 98 }, 100, alt = "questsDone" }, desc = "FEATD_quests" },
		{ "quest_500",       142, "quest", 25, C, crit = { "stat", { 98 }, 500, alt = "questsDone" }, desc = "FEATD_quests" },
		{ "quest_1000",      143, "quest", 50, C, crit = { "stat", { 98 }, 1000, alt = "questsDone" }, desc = "FEATD_quests",
			reward = { title = 30 } },
		{ "quest_valthalak", 144, "quest", 25, C, crit = { "count", "questValthalak", 1 }, pending = true },
		{ "rep_honored_10",  145, "quest", 10, C, crit = { "stat", { 529 }, 10, alt = "repHonored" }, desc = "FEATD_repHonored" },
		{ "rep_exalted_1",   146, "quest", 10, C, crit = { "stat", { 377 }, 1, alt = "repExalted" }, desc = "FEATD_repExalted1" },
		{ "rep_exalted_5",   147, "quest", 25, C, crit = { "stat", { 377 }, 5, alt = "repExalted" }, desc = "FEATD_repExalted",
			reward = { title = 31 } },
		{ "pvp_hk_100",      148, "quest", 10, C, crit = { "stat", { 588 }, 100 }, desc = "FEATD_hk", pending = true },
		{ "pvp_bg_win",      149, "quest", 10, C, crit = { "stat", { 840 }, 1 }, desc = "FEATD_bgWin", pending = true },
		{ "pvp_duel_10",     150, "quest", 5,  C, crit = { "stat", { 319 }, 10 }, desc = "FEATD_duels", pending = true },
		-- Insolite (compte : obtenu par l'un de tes personnages ; statistiques)
		{ "fun_hogger_death", 155, "fun", 5, A, crit = { "stat", { 594 }, 1 }, desc = "FEATD_hoggerDeath", pending = true },
		{ "fun_critters_kill", 158, "fun", 5, A, crit = { "stat", { 108 }, 50 }, desc = "FEATD_critters", pending = true },
		{ "fun_drown",       159, "fun", 5, A, crit = { "stat", { 112 }, 1 }, desc = "FEATD_drown", pending = true },
		{ "fun_fall",        160, "fun", 5, A, crit = { "stat", { 114 }, 1 }, desc = "FEATD_fall", pending = true },
		{ "fun_lava",        161, "fun", 5, A, crit = { "stat", { 115 }, 1 }, desc = "FEATD_lava", pending = true },
		{ "fun_emotes",      162, "fun", 5, A, crit = { "stat", { 1042, 1045, 1047, 1065, 1066, 1067 }, 100, alt = "emotes" },
			desc = "FEATD_emotes" },
		{ "fun_respec",      165, "fun", 5, A, crit = { "stat", { 1149 }, 1 }, desc = "FEATD_respec", pending = true },
		-- Grands hauts faits qui dépendent des catégories du jeu
		{ "meta_dungeons",   169, "meta", 50, A, crit = { "meta", { "dng_tier1", "dng_tier2", "dng_tier3", "dng_tier4" } },
			desc = "FEATD_metaDungeons", reward = { title = 36 } },
		{ "meta_hero",       170, "meta", 50, A, crit = { "list", "hero" }, reward = { title = 37 } },
	}) do ns.FeatAdd(row) end
end)

-- Titres de ces hauts faits : registre unique dans FeatsTitles.lua (lot D).

-- ---------------------------------------------------------------------------
-- Chaînes
-- ---------------------------------------------------------------------------
local FR = {
	FEATD_goldMax         = "Avoir possédé %d pièces d'or",
	FEATD_goldLooted      = "Ramasser 100 pièces d'or sur les ennemis",
	FEATD_mount           = "Posséder une monture",
	FEATD_mountEpic       = "Chevaucher une monture rapide",
	FEATD_flight          = "Prendre %d vols de griffon ou de wyverne",
	FEATD_epic            = "Ramasser un objet épique",
	FEATD_death1          = "Mourir une fois",
	FEATD_deaths          = "Mourir %d fois",
	FEATD_camp            = "Faire %d haltes au feu de camp",
	FEATD_food            = "Manger ou boire %d fois",
	FEATD_potions         = "Boire %d potions, élixirs ou flacons",
	FEATD_runs            = "Entrer %d fois dans un donjon",
	FEATD_list_dngTier1   = "Vaincre le dernier boss de %d donjons : Ragefeu, Lamentations, Mortemines, Ombrecroc, Prison, Brassenoire, Salle des Thanes, Ruines de Lordaeron",
	FEATD_list_dngTier2   = "Vaincre le dernier boss de %d donjons : Gnomeregan, Kraal, Monastère, Souilles, Cité de Dalaran (entrer au Site de fouilles des Paluns et dans la Cité engloutie)",
	FEATD_list_dngTier3   = "Vaincre le dernier boss de %d donjons : Uldaman, Zul'Farrak, Maraudon, Temple englouti, Prison d'Alcaz (entrer au Bastion de Krol'dok)",
	FEATD_list_dngTier4   = "Vaincre le dernier boss de %d donjons : Profondeurs de Blackrock, Bas et Haut de la Flèche, Hache-Tripes, Scholomance, Stratholme, Terrasse du Façonneur (entrer à Blackmaw Hold)",
	FEATD_raidEnter       = "Entrer dans un raid",
	FEATD_boss_ony        = "Vaincre Onyxia (Repaire d'Onyxia)",
	FEATD_boss_mc         = "Vaincre Ragnaros (Cœur du Magma)",
	FEATD_boss_zg         = "Vaincre Hakkar (Zul'Gurub)",
	FEATD_boss_bwl        = "Vaincre Nefarian (Repaire de l'Aile noire)",
	FEATD_boss_aq20       = "Vaincre Ossirian (Ruines d'Ahn'Qiraj)",
	FEATD_boss_aq40       = "Vaincre C'Thun (Temple d'Ahn'Qiraj)",
	FEATD_boss_naxx       = "Vaincre Kel'Thuzad (Naxxramas)",
	FEATD_boss_hyjal      = "Vaincre le Roi sauvage (Sommet d'Hyjal)",
	FEATD_boss_barrow     = "Vaincre Sonya Darkhallow (Profondeurs des Tertres)",
	FEATD_worldBoss       = "Vaincre un boss du monde",
	FEATD_captureInside   = "Capturer une créature dans un donjon",
	FEATD_profPrimary     = "Apprendre un métier principal",
	FEATD_profBest        = "Monter un métier principal à %d",
	FEATD_profPrimary300  = "Monter %d métiers principaux à 300",
	FEATD_prof_cooking    = "Monter la cuisine à %d",
	FEATD_prof_fishing    = "Monter la pêche à %d",
	FEATD_prof_firstaid   = "Monter le secourisme à %d",
	FEATD_profSecondary   = "Cuisine, pêche et secourisme à 300",
	FEATD_fishCaught      = "Pêcher %d poissons",
	FEATD_gathered        = "Faire %d récoltes",
	FEATD_quests          = "Rendre %d quêtes",
	FEATD_questValthalak  = "Finir la chaîne de Lord Valthalak",
	FEATD_repHonored      = "Être Honoré ou mieux auprès de %d factions",
	FEATD_repExalted1     = "Être Exalté auprès d'une faction",
	FEATD_repExalted      = "Être Exalté auprès de %d factions",
	FEATD_hk              = "Obtenir %d victoires honorables",
	FEATD_bgWin           = "Gagner un champ de bataille",
	FEATD_duels           = "Gagner %d duels",
	FEATD_hoggerDeath     = "Être tué par Lardeur",
	FEATD_critters        = "Tuer %d bestioles",
	FEATD_drown           = "Mourir noyé",
	FEATD_fall            = "Mourir d'une chute",
	FEATD_lava            = "Mourir dans le feu ou la lave",
	FEATD_emotes          = "Faire %d émotes (câlin, acclamation, salut, rire, violon, paume au front)",
	FEATD_respec          = "Réinitialiser ses talents",
	FEATD_metaDungeons    = "Obtenir les %d paliers de donjons",
	FEATD_list_hero       = "Niveau 60, 5 hauts faits de Donjons et raids, 3 de Métiers et 3 de Quêtes",
	FEAT_char_gold_100    = "Bourse ronde",
	FEAT_char_gold_1000   = "Fortune de prince",
	FEAT_char_gold_looted = "Fouilleur de poches",
	FEAT_char_mount       = "Au galop",
	FEAT_char_mount_epic  = "Le vent dans la crinière",
	FEAT_char_flight_25   = "Passager du ciel",
	FEAT_char_epic        = "Reflets violets",
	FEAT_char_deaths_1    = "Ça arrive à tout le monde",
	FEAT_char_deaths_100  = "Abonné du cimetière",
	FEAT_char_camp_25     = "Veillée",
	FEAT_char_food_500    = "Bon appétit",
	FEAT_char_potions_100 = "Pharmacie ambulante",
	FEAT_dng_runs_50      = "Carte de fidélité",
	FEAT_dng_tier1        = "Premières profondeurs",
	FEAT_dng_tier2        = "Galeries et cryptes",
	FEAT_dng_tier3        = "Ruines oubliées",
	FEAT_dng_tier4        = "Les grands bastions",
	FEAT_dng_raid_enter   = "Quarante en file",
	FEAT_dng_raid_ony     = "La reine noire tombe",
	FEAT_dng_raid_mc      = "Éteindre le Seigneur du feu",
	FEAT_dng_raid_zg      = "Le Dieu sanglant déchu",
	FEAT_dng_raid_bwl     = "L'ombre dissipée",
	FEAT_dng_raid_aq20    = "Sables apaisés",
	FEAT_dng_raid_aq40    = "L'œil se ferme",
	FEAT_dng_raid_naxx    = "La nécropole se tait",
	FEAT_dng_raid_hyjal   = "La couronne sauvage",
	FEAT_dng_raid_barrow  = "Les tertres apaisés",
	FEAT_dng_world_boss   = "Plus gros que moi",
	FEAT_dng_capture_inside = "Souvenir de donjon",
	FEAT_prof_first       = "Un métier en main",
	FEAT_prof_150         = "Compagnon d'atelier",
	FEAT_prof_225         = "Main sûre",
	FEAT_prof_300         = "Chef-d'œuvre",
	FEAT_prof_double_300  = "Double casquette",
	FEAT_prof_cook_300    = "Toque étoilée",
	FEAT_prof_fish_300    = "Patience au bord de l'eau",
	FEAT_prof_aid_300     = "Mains qui soignent",
	FEAT_prof_secondary_all = "Bon à tout",
	FEAT_prof_fish_250    = "Ça mord !",
	FEAT_prof_gather_100  = "Panier plein",
	FEAT_prof_gather_1000 = "Herbier d'Azeroth",
	FEAT_quest_10         = "Petits services",
	FEAT_quest_100        = "Carnet de commandes",
	FEAT_quest_500        = "Toujours partant",
	FEAT_quest_1000       = "Mille et une quêtes",
	FEAT_quest_valthalak  = "Repos pour Valthalak",
	FEAT_rep_honored_10   = "Bonne réputation",
	FEAT_rep_exalted_1    = "Ami pour la vie",
	FEAT_rep_exalted_5    = "Le bienvenu",
	FEAT_pvp_hk_100       = "Honneur rendu",
	FEAT_pvp_bg_win       = "Drapeau planté",
	FEAT_pvp_duel_10      = "Pour l'honneur",
	FEAT_fun_hogger_death = "Lardeur a gagné",
	FEAT_fun_critters_kill = "Pas les lapins !",
	FEAT_fun_drown        = "Respirer, c'est surfait",
	FEAT_fun_fall         = "La gravité gagne toujours",
	FEAT_fun_lava         = "Ça chauffe !",
	FEAT_fun_emotes       = "Expressif",
	FEAT_fun_respec       = "Changement de cap",
	FEAT_meta_dungeons    = "Terreur des cachots",
	FEAT_meta_hero        = "Héros d'Azeroth",
}
local EN = {
	FEATD_goldMax         = "Have owned %d gold",
	FEATD_goldLooted      = "Loot 100 gold from enemies",
	FEATD_mount           = "Own a mount",
	FEATD_mountEpic       = "Ride a swift mount",
	FEATD_flight          = "Take %d gryphon or wyvern flights",
	FEATD_epic            = "Loot an epic item",
	FEATD_death1          = "Die once",
	FEATD_deaths          = "Die %d times",
	FEATD_camp            = "Rest %d times at a campfire",
	FEATD_food            = "Eat or drink %d times",
	FEATD_potions         = "Drink %d potions, elixirs or flasks",
	FEATD_runs            = "Enter a dungeon %d times",
	FEATD_list_dngTier1   = "Defeat the last boss of %d dungeons: Ragefire, Wailing Caverns, Deadmines, Shadowfang, Stockade, Blackfathom, Hall of Thanes, Ruins of Lordaeron",
	FEATD_list_dngTier2   = "Defeat the last boss of %d dungeons: Gnomeregan, Razorfen Kraul, Scarlet Monastery, Razorfen Downs, City of Dalaran (enter the Wetlands Excavation Site and the Drowned City)",
	FEATD_list_dngTier3   = "Defeat the last boss of %d dungeons: Uldaman, Zul'Farrak, Maraudon, Sunken Temple, Alcaz Prison (enter Krol'dok Stronghold)",
	FEATD_list_dngTier4   = "Defeat the last boss of %d dungeons: Blackrock Depths, Lower and Upper Blackrock Spire, Dire Maul, Scholomance, Stratholme, Shaper's Terrace (enter Blackmaw Hold)",
	FEATD_raidEnter       = "Enter a raid",
	FEATD_boss_ony        = "Defeat Onyxia (Onyxia's Lair)",
	FEATD_boss_mc         = "Defeat Ragnaros (Molten Core)",
	FEATD_boss_zg         = "Defeat Hakkar (Zul'Gurub)",
	FEATD_boss_bwl        = "Defeat Nefarian (Blackwing Lair)",
	FEATD_boss_aq20       = "Defeat Ossirian (Ruins of Ahn'Qiraj)",
	FEATD_boss_aq40       = "Defeat C'Thun (Temple of Ahn'Qiraj)",
	FEATD_boss_naxx       = "Defeat Kel'Thuzad (Naxxramas)",
	FEATD_boss_hyjal      = "Defeat the Wild King (Hyjal Summit)",
	FEATD_boss_barrow     = "Defeat Sonya Darkhallow (Barrow Deeps)",
	FEATD_worldBoss       = "Defeat a world boss",
	FEATD_captureInside   = "Capture a creature inside a dungeon",
	FEATD_profPrimary     = "Learn a primary profession",
	FEATD_profBest        = "Raise a primary profession to %d",
	FEATD_profPrimary300  = "Raise %d primary professions to 300",
	FEATD_prof_cooking    = "Raise Cooking to %d",
	FEATD_prof_fishing    = "Raise Fishing to %d",
	FEATD_prof_firstaid   = "Raise First Aid to %d",
	FEATD_profSecondary   = "Cooking, Fishing and First Aid at 300",
	FEATD_fishCaught      = "Catch %d fish",
	FEATD_gathered        = "Gather %d times",
	FEATD_quests          = "Turn in %d quests",
	FEATD_questValthalak  = "Complete the Lord Valthalak chain",
	FEATD_repHonored      = "Reach Honored or better with %d factions",
	FEATD_repExalted1     = "Reach Exalted with a faction",
	FEATD_repExalted      = "Reach Exalted with %d factions",
	FEATD_hk              = "Earn %d honorable kills",
	FEATD_bgWin           = "Win a battleground",
	FEATD_duels           = "Win %d duels",
	FEATD_hoggerDeath     = "Get killed by Hogger",
	FEATD_critters        = "Kill %d critters",
	FEATD_drown           = "Drown",
	FEATD_fall            = "Die from falling",
	FEATD_lava            = "Die in fire or lava",
	FEATD_emotes          = "Use %d emotes (hug, cheer, wave, LOL, violin, facepalm)",
	FEATD_respec          = "Reset your talents",
	FEATD_metaDungeons    = "Earn the %d dungeon tiers",
	FEATD_list_hero       = "Level 60, 5 Dungeons and Raids, 3 Professions and 3 Quests achievements",
	FEAT_char_gold_100    = "A Round Purse",
	FEAT_char_gold_1000   = "A Prince's Fortune",
	FEAT_char_gold_looted = "Pocket Picker",
	FEAT_char_mount       = "At a Gallop",
	FEAT_char_mount_epic  = "Wind in the Mane",
	FEAT_char_flight_25   = "Sky Passenger",
	FEAT_char_epic        = "Purple Glow",
	FEAT_char_deaths_1    = "It Happens",
	FEAT_char_deaths_100  = "Graveyard Regular",
	FEAT_char_camp_25     = "Fireside",
	FEAT_char_food_500    = "Bon Appétit",
	FEAT_char_potions_100 = "Walking Apothecary",
	FEAT_dng_runs_50      = "Loyalty Card",
	FEAT_dng_tier1        = "First Depths",
	FEAT_dng_tier2        = "Halls and Crypts",
	FEAT_dng_tier3        = "Forgotten Ruins",
	FEAT_dng_tier4        = "The Great Strongholds",
	FEAT_dng_raid_enter   = "Forty Strong",
	FEAT_dng_raid_ony     = "The Black Queen Falls",
	FEAT_dng_raid_mc      = "Put Out the Firelord",
	FEAT_dng_raid_zg      = "The Blood God Falls",
	FEAT_dng_raid_bwl     = "The Shadow Lifted",
	FEAT_dng_raid_aq20    = "Quiet Sands",
	FEAT_dng_raid_aq40    = "The Eye Closes",
	FEAT_dng_raid_naxx    = "The Necropolis Falls Silent",
	FEAT_dng_raid_hyjal   = "The Wild Crown",
	FEAT_dng_raid_barrow  = "The Barrows at Rest",
	FEAT_dng_world_boss   = "Bigger Than Me",
	FEAT_dng_capture_inside = "Dungeon Keepsake",
	FEAT_prof_first       = "A Trade in Hand",
	FEAT_prof_150         = "Workshop Hand",
	FEAT_prof_225         = "Steady Hand",
	FEAT_prof_300         = "Masterwork",
	FEAT_prof_double_300  = "Two Hats",
	FEAT_prof_cook_300    = "Starred Toque",
	FEAT_prof_fish_300    = "Patience by the Water",
	FEAT_prof_aid_300     = "Healing Hands",
	FEAT_prof_secondary_all = "Handy",
	FEAT_prof_fish_250    = "They're Biting!",
	FEAT_prof_gather_100  = "Full Basket",
	FEAT_prof_gather_1000 = "Azeroth Herbarium",
	FEAT_quest_10         = "Odd Jobs",
	FEAT_quest_100        = "Order Book",
	FEAT_quest_500        = "Always Up for It",
	FEAT_quest_1000       = "A Thousand and One Quests",
	FEAT_quest_valthalak  = "Rest for Valthalak",
	FEAT_rep_honored_10   = "Good Standing",
	FEAT_rep_exalted_1    = "Friend for Life",
	FEAT_rep_exalted_5    = "Welcome Everywhere",
	FEAT_pvp_hk_100       = "Honor Due",
	FEAT_pvp_bg_win       = "Flag Planted",
	FEAT_pvp_duel_10      = "For Honour's Sake",
	FEAT_fun_hogger_death = "Hogger Wins",
	FEAT_fun_critters_kill = "Not the Bunnies!",
	FEAT_fun_drown        = "Breathing Is Overrated",
	FEAT_fun_fall         = "Gravity Always Wins",
	FEAT_fun_lava         = "Feeling the Heat",
	FEAT_fun_emotes       = "Expressive",
	FEAT_fun_respec       = "Change of Heart",
	FEAT_meta_dungeons    = "Dread of the Dungeons",
	FEAT_meta_hero        = "Hero of Azeroth",
}
ns.RegisterStrings(FR, EN)
-- mode test : les noms rejoignent la table du catalogue (contrôle FR/EN du lot A)
if ns.KEEP_STRINGS then
	ns.FEAT_JEU_STRINGS = { fr = FR, en = EN }
	local data = ns.FEAT_DATA_STRINGS
	if type(data) == "table" then
		for key, value in pairs(FR) do data.fr[key] = value end
		for key, value in pairs(EN) do data.en[key] = value end
	end
end

-- ---------------------------------------------------------------------------
-- Crochets sur les modules existants (posés au chargement, avant Feats.lua :
-- son propre crochet signale le sujet après les nôtres)
-- ---------------------------------------------------------------------------
-- victime comptée par le bestiaire (hors instance) : boss du monde ?
do
	local base = ns.BestiaryOnKill
	if type(base) == "function" then
		function ns:BestiaryOnKill(guid, entry, ...)
			if Awake() and type(entry) == "table" and entry.npcID then
				local npcID, boss = entry.npcID, WORLD_BOSSES[entry.npcID]
				if not boss then
					local static = self.BestiaryStaticZone and self:BestiaryStaticZone(entry.zoneID)
					local known = static and static[npcID]
					boss = type(known) == "table" and tonumber(known.rank) == 3
				end
				if not boss then
					local zone = self:BestiaryData()[entry.zoneID]
					local species = type(zone) == "table" and zone[npcID]
					boss = type(species) == "table" and species.class == "worldboss"
				end
				if boss then pcall(self.FeatCount, self, "worldBoss", 1) end
			end
			return base(self, guid, entry, ...)
		end
	end
end
-- capture réussie en instance
do
	local base = ns.CaptureResolve
	if type(base) == "function" then
		local function After(rolling, ...)
			if (...) and type(rolling) == "table" and rolling.success and Awake() and ns:InInstance() then
				pcall(ns.FeatCount, ns, "captureInside", 1)
			end
			return ...
		end
		function ns:CaptureResolve(rolling, ...) return After(rolling, base(self, rolling, ...)) end
	end
end
-- récolte comptée : sujet « prof »
do
	local base = ns.GatheringRecord
	if type(base) == "function" then
		local function After(...) Touch("prof"); return ... end
		function ns:GatheringRecord(...) return After(base(self, ...)) end
	end
end

-- ---------------------------------------------------------------------------
-- Suivi : or, morts, quêtes, montures, vols, émotes, instance, boss
-- ---------------------------------------------------------------------------
local function GoldSeen()
	if not Awake() then return end
	CtrMax(ns, "goldMax", Num(Call(G("GetMoney"))))
end

local EMOTES = { HUG = true, CHEER = true, FACEPALM = true, WAVE = true, LOL = true, VIOLIN = true }
local function OnEmote(token)
	token = type(token) == "string" and token:upper() or nil
	if token and EMOTES[token] and Awake() then
		ns:FeatCount("emotes", 1, "account")
		Touch("emote")
	end
end
ns.FeatJeuOnEmote = OnEmote

-- Monture : vue une fois (IsMounted) ; monture rapide au sol (en attente)
local watchElapsed           -- horloge des montures et des vols (nil : arrêtée)
local mountCheckAt, wasOnTaxi, taxiUntil = 0, false, 0
local function Mounted() return Call(G("IsMounted")) == true end
local function OnTaxi() return Call(G("UnitOnTaxi"), "player") == true end

local function WatchTick()
	if not Awake() then return end
	local now, mounted = Now(), Mounted()
	local looking = mounted and not ns:FeatStore("char").flag.mountEpic
	if looking and not OnTaxi() and Call(G("IsFlying")) ~= true then
		local speed = Num(Call(G("GetUnitSpeed"), "player"))
		if speed and speed >= EPIC_SPEED then ns:FeatFlag("mountEpic") end
	end
	if now < taxiUntil then
		local onTaxi = OnTaxi()
		if onTaxi and wasOnTaxi == false then Bump("taxi"); Touch("taxi") end
		wasOnTaxi = onTaxi
	end
	if not (looking or now < taxiUntil) then
		watchElapsed = nil
		ns.FeatClock("jeu", nil)
	end
end

local function OnWatch(elapsed)
	watchElapsed = (watchElapsed or 0) + (tonumber(elapsed) or 0)
	if watchElapsed < 1 then return end
	watchElapsed = 0
	local ok, err = pcall(WatchTick)
	if not ok and ns.RecordError then ns:RecordError("feats:jeu", err) end
end
-- (horloge du cadre partagé des hauts faits, FeatsData.lua)
local function Watch()
	watchElapsed = 0
	ns.FeatClock("jeu", OnWatch)
end

function ns:FeatJeuMountCheck(force)
	if not Awake() then return end
	local now = Now()
	if not force and now >= mountCheckAt and now - mountCheckAt < 1 then return end
	mountCheckAt = now
	if Mounted() then
		if Ctr(self, "mounted") == 0 then self:FeatStore("char").ctr.mounted = 1; Touch("mount") end
		Watch()
	end
end

-- Vols : passage de « pas en vol » à « en vol » (UnitOnTaxi), surveillé
-- quelques secondes après la carte des vols et à la perte de contrôle
function ns:FeatJeuTaxiCheck(window)
	if not Awake() then return end
	local onTaxi = OnTaxi()
	if onTaxi and wasOnTaxi == false then Bump("taxi"); Touch("taxi") end
	wasOnTaxi = onTaxi
	if window then taxiUntil = Now() + window; Watch() end
end

-- Instance : raid vu (drapeau), journal des morts ouvert seulement dedans
local combatListening        -- morts écoutées (dans une instance seulement)
local COMBAT_HANDLERS = {
	COMBAT_LOG_EVENT_UNFILTERED = function()
		local fn = G("CombatLogGetCurrentEventInfo")
		if type(fn) ~= "function" then return end
		local ok, _, subevent, _, _, _, _, _, destGUID = pcall(fn)
		if ok and (subevent == "UNIT_DIED" or subevent == "PARTY_KILL") then ns:FeatBossKill(NpcOf(destGUID)) end
	end,
	PARTY_KILL = function(_, target) ns:FeatBossKill(NpcOf(target)) end,
	UNIT_DIED = function(guid) ns:FeatBossKill(NpcOf(guid)) end,
}

function ns:FeatJeuZone()
	if not Awake() then return end
	local inside = self:InInstance()
	if inside then
		local _, kind = Call(G("GetInstanceInfo"))
		if ns.Plain(kind) == "raid" and not self:FeatStore("char").flag.raidEnter then
			self:FeatFlag("raidEnter")
			Touch("instance")
		end
	end
	if inside and not combatListening then
		combatListening = true
		ns.FeatListen(COMBAT_HANDLERS)
	elseif not inside and combatListening then
		combatListening = nil
		ns.FeatUnlisten(COMBAT_HANDLERS)
	end
	return inside
end

-- Diagnostic (/qc hf diag) : les statistiques lues hors critère « stat » ;
-- émotes : hooksecurefunc. Posés une fois, quand tout l'addon est chargé.
local installed = {}
function ns:FeatJeuInit()
	if not installed.diag and type(ns.FeatStatIDs) == "function" then
		installed.diag = true
		local base = ns.FeatStatIDs
		function ns:FeatStatIDs(...)
			local list, set = base(self, ...), {}
			for _, id in ipairs(list) do set[id] = true end
			for key in pairs(BOSSES) do for _, id in ipairs(BossField(key, 3)) do Extra({ id }) end end
			for id in pairs(STAT_EXTRA) do if not set[id] then set[id] = true; list[#list + 1] = id end end
			table.sort(list)
			return list
		end
	end
	local hook, emote = G("hooksecurefunc"), G("DoEmote")
	if not installed.emote and type(hook) == "function" and type(emote) == "function" then
		installed.emote = pcall(hook, "DoEmote", function(token) pcall(OnEmote, token) end) and true or nil
	end
end

local HANDLERS = {
	ADDON_LOADED = function(name) if name == ADDON then ns:FeatJeuInit() end end,
	PLAYER_ENTERING_WORLD = function()
		ns:FeatJeuInit()
		wasOnTaxi = OnTaxi()
		GoldSeen()
		ns:FeatJeuZone()
		ns:FeatJeuMountCheck(true)
	end,
	ZONE_CHANGED_NEW_AREA = function() ns:FeatJeuZone() end,
	PLAYER_MONEY = GoldSeen,
	PLAYER_DEAD = function() Bump("deaths") end,
	QUEST_TURNED_IN = function() Bump("quests") end,
	UNIT_AURA = function(unit) if unit == "player" then ns:FeatJeuMountCheck() end end,
	PLAYER_MOUNT_DISPLAY_CHANGED = function() ns:FeatJeuMountCheck(true) end,
	PLAYER_CONTROL_LOST = function() ns:FeatJeuTaxiCheck(5) end,
	PLAYER_CONTROL_GAINED = function() ns:FeatJeuTaxiCheck() end,
	TAXIMAP_CLOSED = function() ns:FeatJeuTaxiCheck(5) end,
	SKILL_LINES_CHANGED = function() memo.profs = nil; Touch("prof") end,
	UPDATE_FACTION = function() memo.rep = nil; Touch("rep") end,
	-- rencontre réussie (⚠️ jamais vue sur Forever) : id de DungeonEncounter
	ENCOUNTER_END = function(encounterID, _, _, _, success)
		if success == true or Num(success) == 1 then ns:FeatBossKill(nil, Num(encounterID)) end
	end,
}

-- un seul cadre pour tous les hauts faits (FeatsData.lua) : ces événements,
-- l'horloge des montures et des vols, les morts en instance (abonnées
-- seulement dedans, FeatJeuZone)
ns.FeatListen(HANDLERS)

if ns.Mark then ns.Mark("FeatsCatJeu") end
