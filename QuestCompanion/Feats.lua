-- Feats.lua -- moteur des hauts faits de QuestCompanion (2.7.0, lot A)
--
-- WoW Forever n'a pas d'interface de hauts faits (GetAchievementInfo est une
-- coquille vide) : QuestCompanion apporte la sienne. Conception :
-- docs/QC-HAUTS-FAITS.md. Données : FeatsData.lua ; page : JournalFeats.lua.
--
-- Règle de portée : « collection = compte, performance = personnage ».
--   * compte (db.feats) : Ménagerie, Brillantes (union des captures de tous
--     les personnages), Grands hauts faits et paliers de points, Guilde,
--     Insolite ; un titre gagné ainsi sert sur tous les personnages ;
--   * personnage (CharData().feats) : niveaux, or, donjons, métiers, quêtes,
--     zones et sceaux, exploration, missions (GetStatistic est par personnage).
--
-- Sauvegarde (les deux tables ont la même forme) :
--   feats = { v = 1 (migration faite), got = { [id] = { at, lvl, r } },
--             ctr = { [clé] = n }, flag = { [clé] = at },
--             -- personnage seulement (lot D) : title = code | 0 | nil, form = "auto" | "m" | "f" }
--   r = true : obtenu en rattrapage ou par migration (aucun bandeau à lui seul).
--
-- Contrats pour les lots suivants :
--   ns.FEAT_SOURCES[nom] = { get = function(self, scope) -> n end, topics = { … },
--                            retro = false (pas de rattrapage ; absent = oui), dateOf = function(self, n) -> ok, at, lvl end }
--   ns.FEAT_LISTS[nom]   = { items = function(self) -> { "kind:clé" | { source, n } } end, topics = { … } }
--   ns:FeatTouch(sujet)  un crochet signale un sujet ; évaluation groupée 0,5 s plus tard
--   ns:FeatFlag(clé, scope) / ns:FeatCount(clé, delta, scope) / ns:FeatCountReset(clé, scope)
--   ns:FeatGrant(def)    récompenses (aides, cosmétiques, apparence ; titre = rien à stocker)
--   ns:FeatPoints(scope) = ns:AchievementPoints(scope) ("account" | "char" | nil = les deux)
--   ns:FeatTitlesEarned() codes des titres gagnés (registre ns.FEAT_TITLES : FeatsTitles.lua)
--   ns:FireCallback("FEAT_EARNED", info) à chaque obtention ; info.announce = vrai
--     pour les annonces de guilde (≥ 25 points ou titre, jamais en rattrapage)
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local EVAL_DELAY = 0.5      -- une passe au plus toutes les 0,5 s
local LOGIN_DELAY = 3       -- rattrapage 3 s après l'entrée dans le monde
local STAT_TTL = 60         -- une statistique du client relue au plus une fois par minute
local FLUSH_DELAY = 1       -- les obtentions d'une même seconde partent ensemble
local TOAST_COLLAPSE = 3    -- à partir de 3 : un seul bandeau groupé
local MAX_LOOPS = 6         -- métas en chaîne dans une même passe
ns.FEAT_POINTS = { [5] = true, [10] = true, [25] = true, [50] = true }
ns.FEAT_FOS = "fos"         -- 3.7.0 : tours de force, 0 point, hors des totaux
-- 3.7.0 : paillettes données par tout haut fait, selon ses points
ns.FEAT_GLITTER = { [0] = 0, [5] = 2, [10] = 5, [25] = 15, [50] = 40 }
-- 3.7.0 : rangs de renommée (points de compte et du personnage connecté)
ns.FEAT_RANKS = { 100, 250, 500, 1000, 1500, 2000, 3000, 4000 }
ns.FEAT_FOLLOW_MAX = 3      -- hauts faits suivis par personnage
ns.FEAT_GUILD_MIN = 25      -- annonce de guilde (lot D) : 25 points ou plus, ou un titre
-- 3.7.0 : la fanfare pour une grande fête (25, 50 points ou un titre), le son
-- court pour une moyenne (10 points), rien pour une petite (5 points)
ns.FEAT_SOUND, ns.FEAT_SOUND_FALLBACK = 12891, 17316
ns.FEAT_STAT_PROBE = 107    -- « créatures tuées », vérifiée en jeu (rend 780)
ns.FEAT_TOAST_COLLAPSE = TOAST_COLLAPSE
ns.FEAT_FILTERS = { "all", "got", "open" }

local FR = {
	OPT_SECTION_FEATS    = "Hauts faits",
	OPT_FEAT_TOAST       = "Bandeau « Haut fait obtenu »",
	OPT_FEAT_CHAT        = "Ligne dans le chat à chaque haut fait",
	OPT_FEAT_SOUND       = "Fanfare des hauts faits",
	OPT_FEAT_STATS       = "Lire les statistiques du client",
	FEAT_TOAST_TITLE     = "Haut fait obtenu",
	FEAT_TOAST_MANY_TITLE = "Hauts faits obtenus",
	FEAT_TOAST_MANY      = "%d hauts faits · +%d points",
	FEAT_TOAST_MANY_HEAD = "%d hauts faits obtenus",
	FEAT_TOAST_MORE_1    = "et 1 autre",
	FEAT_TOAST_MORE      = "et %d autres",
	FEAT_CHAT_MANY       = "Hauts faits obtenus : %s (%d points).",
	FEAT_CHAT_MANY_CONT  = "… %s",
	FEAT_TOAST_NEW_TITLE = "Nouveau titre : %s",
	FEAT_CHAT            = "Haut fait obtenu : %s (+%d points).",
	FEAT_RETRO           = "Hauts faits : %d obtenu(s) d'après ta progression (%d points). /qc hf pour les voir.",
	FEAT_SCOPE_account   = "Compte",
	FEAT_SCOPE_char      = "Perso",
	FEAT_SCOPE_TIP_account = "Haut fait de compte : partagé par tous tes personnages.",
	FEAT_SCOPE_TIP_char  = "Haut fait de ce personnage.",
	FEAT_PENDING         = "détection bientôt disponible",
	FEAT_REWARD          = "Récompense : %s",
	FEAT_REWARD_TITLE    = "titre « %s »",
	FEAT_REWARD_AID      = "%s ×%d",
	FEAT_EARNED_ON       = "Obtenu le %s",
	FEAT_DATE_FORMAT     = "%d/%m/%Y",
	FEAT_DIAG_HEAD       = "Hauts faits — diagnostic des sources",
	FEAT_DIAG_STATS_OK   = "Statistiques du client : lisibles (%d = %s).",
	FEAT_DIAG_STATS_NO   = "Statistiques du client : illisibles sur ce client (les replis prennent le relais).",
	FEAT_DIAG_STATS_OFF  = "Statistiques du client : coupées dans les réglages.",
	FEAT_DIAG_STAT       = "  stat %d : %s (brut « %s »)",
	FEAT_DIAG_UNREADABLE = "illisible",
	FEAT_DIAG_COUNTS     = "Définitions : %d · obtenus : %d compte, %d personnage · en attente : %d · sans source lisible : %d.",
	FEAT_DIAG_POINTS     = "Points : %d compte · %d personnage.",
	HELP_FEATS           = "/qc hf -- tes hauts faits (page du carnet) ; /qc hf diag : sources lisibles",
	FEAT_SECRET_NAME     = "Un secret du compagnon",
	FEAT_SECRET_WAIT     = "Ton compagnon garde ce secret pour lui… pour l'instant.",
	FEAT_GLITTER_CATCHUP = "Hauts faits : +%d paillettes pour %d haut(s) fait(s) déjà obtenu(s).",
	FEAT_CHECK_STEP      = "%d sur %d",
	FEAT_RANK_1          = "Connu au village",
	FEAT_RANK_2          = "Connu du comté",
	FEAT_RANK_3          = "Un nom qui circule",
	FEAT_RANK_4          = "Réputé",
	FEAT_RANK_5          = "De grande renommée",
	FEAT_RANK_6          = "Illustre",
	FEAT_RANK_7          = "Célèbre dans tout Azeroth",
	FEAT_RANK_8          = "Légende vivante",
}
local EN = {
	OPT_SECTION_FEATS    = "Achievements",
	OPT_FEAT_TOAST       = "\"Achievement earned\" banner",
	OPT_FEAT_CHAT        = "Chat line for each achievement",
	OPT_FEAT_SOUND       = "Achievement fanfare",
	OPT_FEAT_STATS       = "Read the client statistics",
	FEAT_TOAST_TITLE     = "Achievement earned",
	FEAT_TOAST_MANY_TITLE = "Achievements earned",
	FEAT_TOAST_MANY      = "%d achievements · +%d points",
	FEAT_TOAST_MANY_HEAD = "%d achievements earned",
	FEAT_TOAST_MORE_1    = "and 1 more",
	FEAT_TOAST_MORE      = "and %d more",
	FEAT_CHAT_MANY       = "Achievements earned: %s (%d points).",
	FEAT_CHAT_MANY_CONT  = "… %s",
	FEAT_TOAST_NEW_TITLE = "New title: %s",
	FEAT_CHAT            = "Achievement earned: %s (+%d points).",
	FEAT_RETRO           = "Achievements: %d earned from your progress (%d points). /qc hf to see them.",
	FEAT_SCOPE_account   = "Account",
	FEAT_SCOPE_char      = "Char",
	FEAT_SCOPE_TIP_account = "Account achievement: shared by all your characters.",
	FEAT_SCOPE_TIP_char  = "Achievement of this character.",
	FEAT_PENDING         = "detection coming soon",
	FEAT_REWARD          = "Reward: %s",
	FEAT_REWARD_TITLE    = "title \"%s\"",
	FEAT_REWARD_AID      = "%s ×%d",
	FEAT_EARNED_ON       = "Earned on %s",
	FEAT_DATE_FORMAT     = "%Y-%m-%d",
	FEAT_DIAG_HEAD       = "Achievements — source diagnostics",
	FEAT_DIAG_STATS_OK   = "Client statistics: readable (%d = %s).",
	FEAT_DIAG_STATS_NO   = "Client statistics: unreadable on this client (fallbacks take over).",
	FEAT_DIAG_STATS_OFF  = "Client statistics: turned off in the settings.",
	FEAT_DIAG_STAT       = "  stat %d: %s (raw \"%s\")",
	FEAT_DIAG_UNREADABLE = "unreadable",
	FEAT_DIAG_COUNTS     = "Definitions: %d · earned: %d account, %d character · pending: %d · no readable source: %d.",
	FEAT_DIAG_POINTS     = "Points: %d account · %d character.",
	HELP_FEATS           = "/qc hf -- your achievements (journal page); /qc hf diag: readable sources",
	FEAT_SECRET_NAME     = "A companion's secret",
	FEAT_SECRET_WAIT     = "Your companion is keeping this one to itself… for now.",
	FEAT_GLITTER_CATCHUP = "Achievements: +%d glitter for %d achievement(s) already earned.",
	FEAT_CHECK_STEP      = "%d of %d",
	FEAT_RANK_1          = "Known in the Village",
	FEAT_RANK_2          = "Known in the County",
	FEAT_RANK_3          = "A Name Going Around",
	FEAT_RANK_4          = "Renowned",
	FEAT_RANK_5          = "Of Great Renown",
	FEAT_RANK_6          = "Illustrious",
	FEAT_RANK_7          = "Famous Across Azeroth",
	FEAT_RANK_8          = "Living Legend",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.FEAT_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({
	featToast = true,    -- bandeau « Haut fait obtenu »
	featChat  = false,   -- une ligne de chat par haut fait (le bandeau suffit)
	featSound = true,    -- fanfare au bandeau
	featStats = true,    -- lire GetStatistic (désactivable si un client les rend fausses)
	featsFilter = "all", -- filtre de la page
})

if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then table.insert(section[2], "HELP_FEATS") end
	end
end

-- ---------------------------------------------------------------------------
-- Accès robustes
-- ---------------------------------------------------------------------------
local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end
local function Now() return (ns.Now and ns.Now()) or 0 end
local function Time() return tonumber(Call(G("time"))) or 0 end
local function Level() return tonumber(ns.Plain(Call(G("UnitLevel"), "player"))) end
local function InCombat()
	return Call(G("InCombatLockdown")) == true or Call(G("UnitAffectingCombat"), "player") == true
end
local function ModuleOn() return ns.CompanionOn and ns.CompanionOn() or false end

-- Les tests chargent tous les modules : le moteur n'y tourne tout seul
-- (crochets, rattrapage à la connexion) que si le test le réveille
-- (ns.featsDormant = false). Ses fonctions répondent toujours à l'appel.
ns.featsDormant = rawget(_G, "ADDON_TESTING") and true or nil

-- ---------------------------------------------------------------------------
-- Sauvegarde : compte (db.feats) et personnage (CharData().feats)
-- ---------------------------------------------------------------------------
-- Répare une table abîmée sans rien perdre de ce qui se lit encore ; une
-- fois par table et par session (FeatGot est appelé dans des boucles)
local fixed = setmetatable({}, { __mode = "k" })
local function FixStore(store)
	if fixed[store] and type(store.got) == "table" and type(store.ctr) == "table" and type(store.flag) == "table" then
		return store
	end
	fixed[store] = true
	if type(store.got) ~= "table" then store.got = {} end
	for id, entry in pairs(store.got) do
		if type(entry) == "number" then store.got[id] = { at = entry }
		elseif entry == true then store.got[id] = { at = 0 }
		elseif type(entry) ~= "table" then store.got[id] = nil end
	end
	if type(store.ctr) ~= "table" then store.ctr = {} end
	if type(store.flag) ~= "table" then store.flag = {} end
	return store
end

function ns:FeatStore(scope)
	if scope == "account" then
		local db = self:DB()
		if type(db.feats) ~= "table" then db.feats = {} end
		return FixStore(db.feats)
	end
	local char = self:CharData()
	if type(char.feats) ~= "table" then char.feats = {} end
	return FixStore(char.feats)
end

-- ---------------------------------------------------------------------------
-- Catalogue : normalisation et index (sujets, catégories), à la demande
-- ---------------------------------------------------------------------------
local index


local CRIT_TOPICS = {
	stat = { "stat", "kill", "death", "quest", "money", "level" },
	flag = { "flag" }, streak = { "flag" }, meta = { "feat" }, points = { "feat" },
	-- 3.7.0 : critères sur les compteurs de Tally.lua (sujet posé à chaque écriture)
	tally = { "tally" }, tallymax = { "tally" }, tallyset = { "tally" },
}
-- critères sur compteurs : la fonction de Tally.lua qui les lit
local TALLY_READ = { tally = "TallyGet", tallymax = "TallyBest", tallyset = "TallySize" }
ns.FEAT_TALLY_KINDS = TALLY_READ

local topicLists = {}
local function TopicsOf(def)
	if def.topics then return def.topics end
	local crit, set = def.crit or {}, {}
	local function Add(list) for _, t in ipairs(list or {}) do set[t] = true end end
	local kind = crit[1]
	if kind == "count" then
		local source = ns.FEAT_SOURCES[crit[2]]
		Add(source and source.topics)
	elseif kind == "list" then
		local list = ns.FEAT_LISTS[crit[2]]
		Add(list and list.topics)
	else
		Add(CRIT_TOPICS[kind])
		if kind == "stat" and crit.alt then
			local alt = ns.FEAT_SOURCES[crit.alt]
			Add(alt and alt.topics)
		end
	end
	local out = {}
	for t in pairs(set) do out[#out + 1] = t end
	table.sort(out)
	-- listes identiques partagées (la plupart des lignes ont les mêmes sujets)
	local key = table.concat(out, ",")
	if not topicLists[key] then topicLists[key] = out end
	return topicLists[key]
end

-- Seuil d'une ligne (rang dans sa série) : n du critère, ou 1
function ns.FeatThreshold(def)
	local crit = type(def) == "table" and def.crit or {}
	if crit[1] == "points" then return tonumber(crit[2]) or 0 end
	if crit[1] == "meta" and type(crit[2]) == "table" then return #crit[2] end
	return tonumber(crit[3]) or 1
end

local function Index()
	-- catalogue construit à la première lecture (FeatsData.lua)
	if ns.FeatLoadCatalog then ns.FeatLoadCatalog() end
	if index and not ns.featIndexDirty and index.count == #ns.FEAT_DEFS then return index end
	index = { byId = {}, list = {}, cats = {}, catList = {}, count = #ns.FEAT_DEFS, byTopic = {}, pos = {}, series = {} }
	for _, cat in ipairs(ns.FEAT_CATEGORIES or {}) do index.cats[cat.id] = cat end
	-- 3.7.0 : séries déclarées à part (FeatsData.lua) : identifiant -> clé
	local seriesOf = {}
	for key, ids in pairs(ns.FEAT_SERIES or {}) do
		for _, id in ipairs(ids) do seriesOf[id] = key end
	end
	for position, def in ipairs(ns.FEAT_DEFS) do
		if ns.FeatCompact then
			def = ns.FeatCompact(def)
			ns.FEAT_DEFS[position] = def
		end
		if def.id and not index.byId[def.id] then
			index.byId[def.id] = def
			index.list[#index.list + 1] = def
			index.pos[def] = #index.list
			def.topicList = TopicsOf(def)
			-- index sujet -> lignes (dans l'ordre du catalogue) : une passe ne
			-- parcourt que les lignes abonnées aux sujets touchés
			for _, topic in ipairs(def.topicList) do
				local list = index.byTopic[topic]
				if not list then list = {}; index.byTopic[topic] = list end
				list[#list + 1] = def
			end
			if def.series == nil and seriesOf[def.id] then def.series = seriesOf[def.id] end
			if def.series then
				local members = index.series[def.series]
				if not members then members = {}; index.series[def.series] = members end
				members[#members + 1] = def
			end
		end
	end
	-- paliers d'une série : seuil croissant (à égalité, le code)
	for _, members in pairs(index.series) do
		table.sort(members, function(a, b)
			local x, y = ns.FeatThreshold(a), ns.FeatThreshold(b)
			if x ~= y then return x < y end
			return (tonumber(a.n) or 0) < (tonumber(b.n) or 0)
		end)
	end
	-- catégories qui ont au moins une ligne, dans l'ordre de FEAT_CATEGORIES
	local used = {}
	for _, def in ipairs(index.list) do used[def.cat] = true end
	for _, cat in ipairs(ns.FEAT_CATEGORIES or {}) do
		if used[cat.id] then index.catList[#index.catList + 1] = cat.id end
	end
	ns.featIndexDirty = nil
	return index
end

function ns:FeatIndex() return Index() end
function ns:FeatDef(id) return Index().byId[id] end
function ns:FeatDefs() return Index().list end
function ns:FeatCategories() return Index().catList end
-- 3.7.0 : une catégorie (table de FEAT_CATEGORIES), les paliers d'une série
function ns:FeatCategory(id) return Index().cats[id] end
function ns:FeatSeries(key) return Index().series[key] end

-- 3.7.0 : points admis (5, 10, 25, 50 ; 0 pour un tour de force seulement)
function ns.FeatPointsOK(def)
	if type(def) ~= "table" then return false end
	if def.pts == 0 then return def.cat == ns.FEAT_FOS end
	return ns.FEAT_POINTS[def.pts] == true
end

-- ---------------------------------------------------------------------------
-- Lecture des données existantes (jamais destructive : vieilles sauvegardes)
-- ---------------------------------------------------------------------------
local cache = {}           -- valeurs des sources, le temps d'une passe
function ns:FeatCacheReset() cache = {} end

local function Cached(key, fn)
	local value = cache[key]
	if value == nil then
		value = fn()
		cache[key] = value == nil and false or value
	end
	return value or 0
end

-- Les tampons du carnet (relevés de lieux) du personnage, tels quels
local function Stamps(self)
	local char = self:CharData()
	local journal = type(char.journal) == "table" and char.journal or nil
	local stamps = journal and type(journal.stamps) == "table" and journal.stamps or nil
	return stamps or {}
end

local function StampKind(id, stamp)
	if type(stamp) == "table" and type(stamp.kind) == "string" then return stamp.kind end
	return tostring(id):match("^(%a+):")
end

local function StampAt(stamp)
	local at = type(stamp) == "table" and tonumber(stamp.at) or nil
	if at and at > 0 then return at end
	return nil
end

-- Relevés d'une sorte, du plus ancien au plus récent (sans date : à la fin)
local function StampList(self, kind, filter)
	local list = {}
	for id, stamp in pairs(Stamps(self)) do
		if StampKind(id, stamp) == kind and (not filter or filter(self, id, stamp)) then
			list[#list + 1] = { id = id, at = StampAt(stamp), lvl = type(stamp) == "table" and tonumber(stamp.level) or nil }
		end
	end
	table.sort(list, function(a, b)
		local x, y = a.at or math.huge, b.at or math.huge
		if x ~= y then return x < y end
		return tostring(a.id) < tostring(b.id)
	end)
	return list
end

-- Chaque compagnon de la sauvegarde (tous les personnages du compte)
local function EachCompanion(self, fn)
	local db = self:DB()
	if type(db.chars) ~= "table" then return end
	for key, char in pairs(db.chars) do
		if type(char) == "table" and type(char.companion) == "table" then fn(char.companion, key) end
	end
end

-- Espèces (ou brillantes) capturées : union sur le compte, ou ce personnage
local function CaptureCount(self, scope, shinyOnly)
	if scope ~= "account" then
		if shinyOnly then return self.CaptureShinyCount and self:CaptureShinyCount() or 0 end
		return self.MenagerieSpeciesCount and self:MenagerieSpeciesCount() or 0
	end
	local seen, count = {}, 0
	-- 2.9.0 : la collection du compte d'abord (QuestCompanionDB.capture), puis
	-- les anciennes collections par personnage pas encore versées
	local db = self.DB and self:DB()
	local account = db and type(db.capture) == "table" and type(db.capture.creatures) == "table" and db.capture.creatures
	for npcID, entry in pairs(account or {}) do
		if type(entry) == "table" and (not shinyOnly or entry.shiny == true) then
			local key = tonumber(npcID) or npcID
			if not seen[key] then seen[key], count = true, count + 1 end
		end
	end
	EachCompanion(self, function(data)
		local capture = type(data.capture) == "table" and data.capture or nil
		local creatures = capture and type(capture.creatures) == "table" and capture.creatures or nil
		for npcID, entry in pairs(creatures or {}) do
			if type(entry) == "table" and (not shinyOnly or entry.shiny == true) then
				local key = tonumber(npcID) or npcID
				if not seen[key] then seen[key], count = true, count + 1 end
			end
		end
	end)
	return count
end

-- Capitales de l'autre faction (groupes de Hubs.lua)
local function EnemyCapital(self, id)
	local areaID = tonumber(tostring(id):match("^capital:(%d+)$"))
	if not areaID or not self.JournalHubGroups then return false end
	local faction = self.PlayerFaction and self:PlayerFaction()
	for _, group in pairs(self:JournalHubGroups()) do
		if group.areaID == areaID then
			return faction ~= nil and group.faction ~= nil and group.faction ~= "N" and group.faction ~= faction
		end
	end
	return false
end

-- Une source « n-ième relevé d'une sorte » (compte + date pour la migration)
local function StampSource(kind, filter, topics)
	return {
		topics = topics or ns.FeatTopics("place"),
		get = function(self) return #StampList(self, kind, filter) end,
		dateOf = function(self, n)
			local list = StampList(self, kind, filter)
			local entry = list[tonumber(n) or 1]
			if not entry then return nil end
			return true, entry.at, entry.lvl
		end,
	}
end

-- ---------------------------------------------------------------------------
-- Sources (lot A) ; les lots B et C ajoutent les leurs dans cette table
-- ---------------------------------------------------------------------------
ns.FEAT_SOURCES = ns.FEAT_SOURCES or {}
local SOURCES = ns.FEAT_SOURCES

SOURCES.species = {
	topics = ns.FeatTopics("capture", "seal"),
	get = function(self, scope) return Cached("species:" .. tostring(scope), function() return CaptureCount(self, scope, false) end) end,
	-- date d'un palier d'espèces déjà payé (collection.ranks, le plus ancien du compte)
	dateOf = function(self, n)
		local best
		EachCompanion(self, function(data)
			local coll = type(data.collection) == "table" and data.collection or nil
			local ranks = coll and type(coll.ranks) == "table" and coll.ranks or nil
			local at = ranks and tonumber(ranks[tonumber(n)])
			if at and at > 0 and (not best or at < best) then best = at end
		end)
		if not best or CaptureCount(self, "account", false) < (tonumber(n) or 0) then return nil end
		return true, best
	end,
}
SOURCES.shinyCap = {
	topics = ns.FeatTopics("capture", "shiny"),
	get = function(self, scope) return Cached("shinyCap:" .. tostring(scope), function() return CaptureCount(self, scope, true) end) end,
}
SOURCES.seals = {
	topics = ns.FeatTopics("seal", "capture"),
	get = function(self) return self.MenagerieSeals and #self:MenagerieSeals() or 0 end,
}
SOURCES.level = {
	topics = ns.FeatTopics("level", "place"),
	get = function(self)
		local level = Level()
		if level then return level end
		local best = 0
		for _, entry in ipairs(StampList(self, "level")) do
			best = math.max(best, tonumber(tostring(entry.id):match(":(%d+)$")) or 0)
		end
		return best
	end,
	dateOf = function(self, n)
		local stamp = Stamps(self)["level:" .. tostring(n)]
		if type(stamp) ~= "table" then return nil end
		return true, StampAt(stamp), tonumber(stamp.level)
	end,
}
SOURCES.placeZone = StampSource("zone")
SOURCES.placeSubzone = StampSource("subzone")
SOURCES.placeDungeon = StampSource("dungeon")
SOURCES.placeRare = StampSource("rare")
SOURCES.capitalEnemy = StampSource("capital", function(self, id) return EnemyCapital(self, id) end)
SOURCES.missions = {
	topics = ns.FeatTopics("mission"),
	get = function(self) return math.floor(tonumber(self:CompanionData().missionsDone) or 0) end,
}
-- repli de la statistique 107 : les abattus du bestiaire (ce personnage)
SOURCES.bestiaryKills = {
	topics = ns.FeatTopics("kill"),
	get = function(self)
		return Cached("bestiaryKills", function()
			local total = 0
			for _, zone in pairs(self.BestiaryData and self:BestiaryData() or {}) do
				if type(zone) == "table" then
					for _, species in pairs(zone) do
						if type(species) == "table" then total = total + (tonumber(species.killed) or 0) end
					end
				end
			end
			return total
		end)
	end,
}

-- Listes cochées : chaque élément est un relevé ("kind:clé") ou { source, n }
ns.FEAT_LISTS = ns.FEAT_LISTS or {}
ns.FEAT_LISTS.capitals = {
	topics = ns.FeatTopics("place"),
	items = function()
		local items = {}
		for i, areaID in ipairs(ns.FEAT_CAPITALS or {}) do items[i] = "capital:" .. areaID end
		return items
	end,
}
ns.FEAT_LISTS.dungeons = {
	topics = ns.FeatTopics("place"),
	items = function(self)
		local items = {}
		for key in pairs(self.DUNGEONS or {}) do items[#items + 1] = "dungeon:" .. tostring(key) end
		table.sort(items)
		return items
	end,
}

local function ListItems(self, name)
	local list = ns.FEAT_LISTS[name]
	if not (list and list.items) then return {} end
	local ok, items = pcall(list.items, self)
	return ok and type(items) == "table" and items or {}
end

local function ItemDone(self, item, scope)
	if type(item) == "string" then return Stamps(self)[item] ~= nil end
	if type(item) == "table" then
		local source = SOURCES[item[1]]
		local ok, value = pcall(source and source.get or function() return 0 end, self, scope)
		return ok and (tonumber(value) or 0) >= (tonumber(item[2]) or 1)
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Statistiques natives (GetStatistic) : lecture défensive
-- ---------------------------------------------------------------------------
-- Rend un nombre (pièces de cuivre pour un montant d'argent), 0 pour « rien »
-- ("--", "", nil), nil pour une forme illisible ou une valeur secrète.
function ns.FeatParseStat(value)
	if value == nil then return 0 end
	if ns.Plain(value) == nil then return nil end
	if type(value) == "number" then return math.floor(value) end
	if type(value) ~= "string" then return nil end
	local text = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	-- icônes d'argent du client -> une lettre
	text = text:gsub("|T[^|]-[Gg]old[^|]*|t", "g"):gsub("|T[^|]-[Ss]ilver[^|]*|t", "s"):gsub("|T[^|]-[Cc]opper[^|]*|t", "c")
	text = text:gsub("\194\160", " "):gsub("\226\128\175", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" or text:find("^%-+$") then return 0 end
	if text:find("|") then return nil end
	text = ns.AsciiLower and ns.AsciiLower(text) or text:lower()
	-- abréviations françaises (po, pa, pc) et anglaises (g, s, c)
	text = text:gsub("(%d)%s*po%f[^%a]", "%1g"):gsub("(%d)%s*pa%f[^%a]", "%1s"):gsub("(%d)%s*pc%f[^%a]", "%1c")
	if text:find("%d%s*[gsc]%f[^%a]") then
		local copper, rest = 0, text
		local mult = { g = 10000, s = 100, c = 1 }
		rest = rest:gsub("(%d[%d%., ]*)%s*([gsc])%f[^%a]", function(num, unit)
			copper = copper + (tonumber((num:gsub("[^%d]", ""))) or 0) * mult[unit]
			return " "
		end)
		if rest:find("[^%s]") then return nil end
		return copper
	end
	if text:find("^[%d%., ]+$") then return tonumber((text:gsub("[^%d]", ""))) end
	return nil
end

local statCache = {}
function ns:FeatStatReset() statCache = {}; self.featStatsOK = nil end

local function RawStat(id)
	local fn = G("GetStatistic")
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, id)
	if not ok then return nil end
	return value
end
-- texte brut d'une statistique, pour le diagnostic (jamais d'erreur)
local function RawText(raw)
	if raw ~= nil and ns.Plain(raw) == nil then return "secret" end
	local ok, text = pcall(tostring, raw)
	return ok and text or "?"
end
ns.FeatRawStat = RawStat

function ns:FeatStatsOn() return self:DB().featStats ~= false end

-- La sonde (stat 107) est-elle lisible et numérique ? Gardé pour la session.
function ns:FeatStatsOK(refresh)
	if not self:FeatStatsOn() then return false end
	if self.featStatsOK == nil or refresh then
		local raw = RawStat(ns.FEAT_STAT_PROBE)
		self.featStatsOK = raw ~= nil and ns.FeatParseStat(raw) ~= nil or false
	end
	return self.featStatsOK
end

-- Une statistique (nombre) ou nil (illisible, coupée) ; en combat : la
-- dernière valeur lue
function ns:FeatStat(id)
	if not self:FeatStatsOK() then return nil end
	local now, entry = Now(), statCache[id]
	if entry and now >= entry.at and now - entry.at < STAT_TTL then return entry.value end
	if InCombat() then return entry and entry.value or nil end
	local value = ns.FeatParseStat(RawStat(id))
	statCache[id] = { at = now, value = value }
	return value
end

-- Somme de statistiques ; nil si aucune n'est lisible
function ns:FeatStatSum(ids)
	local sum, any = 0, false
	for _, id in ipairs(ids or {}) do
		local value = self:FeatStat(id)
		if value then sum, any = sum + value, true end
	end
	return any and sum or nil
end

-- ---------------------------------------------------------------------------
-- Progression et obtention
-- ---------------------------------------------------------------------------
function ns:FeatGot(id)
	local def = type(id) == "table" and id or Index().byId[id]
	if not def then return nil end
	return self:FeatStore(def.scope).got[def.id]
end

-- 3.7.0 : la ligne compte-t-elle dans les totaux, pourcentages et comptes par
-- catégorie ? Non pour une ligne en attente (pending), un tour de force et un
-- secret pas encore obtenu.
function ns:FeatCountable(def)
	if type(def) ~= "table" then def = Index().byId[def] end
	if not def or def.pending or def.cat == ns.FEAT_FOS then return false end
	if def.hidden and not self:FeatGot(def) then return false end
	return true
end

-- Points obtenus : "account", "char" ou nil (les deux) ; rend aussi le nombre
-- de hauts faits obtenus (3.7.0 : comptables seulement, tours de force à part)
function ns:FeatPoints(scope)
	local total, count = 0, 0
	for _, def in ipairs(Index().list) do
		if (scope == nil or def.scope == scope) and self:FeatGot(def) and self:FeatCountable(def) then
			total, count = total + (tonumber(def.pts) or 0), count + 1
		end
	end
	return total, count
end
-- nom demandé pour la fiche de dresseur (lot D)
function ns:AchievementPoints(scope) return self:FeatPoints(scope) end

-- Hauts faits obtenus d'une catégorie (sauf `except`)
local function EarnedIn(self, cat, except)
	local count = 0
	for _, def in ipairs(Index().list) do
		if def.cat == cat and def.id ~= except and self:FeatGot(def) then count = count + 1 end
	end
	return count
end

-- Retourne cur, max, état ("done" | "open" | "pending")
function ns:FeatProgress(def)
	if type(def) ~= "table" then def = Index().byId[def] end
	if not def then return 0, 0, "pending" end
	local crit, got = def.crit or {}, self:FeatGot(def)
	local kind = crit[1]
	local cur, max = 0, 1
	if def.pending then
		return 0, tonumber(crit[3]) or 1, got and "done" or "pending"
	end
	if kind == "count" then
		local source = SOURCES[crit[2]]
		if not source then return 0, 1, got and "done" or "pending" end
		local ok, value = pcall(source.get, self, def.scope)
		cur, max = ok and tonumber(value) or 0, tonumber(crit[3]) or 1
	elseif kind == "stat" then
		local stats = self:FeatStatSum(crit[2])
		local alt
		if crit.alt and SOURCES[crit.alt] then
			local ok, value = pcall(SOURCES[crit.alt].get, self, def.scope)
			alt = ok and tonumber(value) or nil
		end
		max = tonumber(crit[3]) or 1
		if stats == nil and alt == nil then return 0, max, got and "done" or "pending" end
		cur = math.max(stats or 0, alt or 0)
	elseif kind == "flag" then
		cur = self:FeatStore(def.scope).flag[crit[2]] and 1 or 0
	elseif kind == "streak" then
		cur, max = tonumber(self:FeatStore(def.scope).ctr[crit[2]]) or 0, tonumber(crit[3]) or 1
	elseif kind == "list" then
		local items = ListItems(self, crit[2])
		max = #items
		if max == 0 then return 0, 0, got and "done" or "pending" end
		for _, item in ipairs(items) do if ItemDone(self, item, def.scope) then cur = cur + 1 end end
	elseif kind == "meta" then
		if type(crit[2]) == "table" then
			max = #crit[2]
			for _, id in ipairs(crit[2]) do if self:FeatGot(id) then cur = cur + 1 end end
		else
			cur, max = EarnedIn(self, crit[2], def.id), tonumber(crit[3]) or 1
		end
	elseif kind == "points" then
		cur, max = self:FeatPoints(nil), tonumber(crit[2]) or 1
	elseif TALLY_READ[kind] then
		-- 3.7.0 : compteur de Tally.lua ; sans lui (pas chargé) : en attente
		max = tonumber(crit[3]) or 1
		local read = self[TALLY_READ[kind]]
		if type(read) ~= "function" then return 0, max, got and "done" or "pending" end
		local ok, value = pcall(read, self, crit[2], crit[4] == "char" and "char" or "account")
		cur = ok and tonumber(value) or 0
	else
		return 0, 1, got and "done" or "pending"
	end
	if got then return math.max(cur, max), max, "done" end
	return math.min(cur, max), max, "open"
end

-- Peut-on l'attribuer après coup (données qui se recalculent) ?
local function Retro(def)
	local crit = def.crit or {}
	local kind = crit[1]
	if kind == "count" then
		local source = SOURCES[crit[2]]
		return source ~= nil and source.retro ~= false
	end
	-- compteurs de Tally.lua : partis de zéro à la 3.7.0, jamais rétroactifs
	return kind ~= "flag" and kind ~= "streak" and not TALLY_READ[kind]
end
ns.FeatRetro = Retro

-- Les cosmétiques connus du compagnon : libellé d'un id
-- (3.6.0 : et ceux de la fiche de dresseur, TrainerCardStyle.lua)
local COSMETIC_LISTS = { frame = "COMPANION_FRAMES", bg = "COMPANION_BACKGROUNDS", orn = "COMPANION_ORNAMENTS", app = "COMPANION_APPEARANCES",
	cardbg = "TRAINER_CARD_BACKGROUNDS", cardframe = "TRAINER_CARD_FRAMES" }
local function CosmeticLabel(kind, id)
	for _, def in ipairs(ns[COSMETIC_LISTS[kind] or ""] or {}) do
		if def.id == id then return L[def.label] or id end
	end
	return id
end

-- Récompenses d'un haut fait. opts.cosmeticsOnly : rien que les déblocages
-- (synchronisation des hauts faits de compte sur un autre personnage).
-- Rend la liste des libellés donnés.
function ns:FeatGrant(def, opts)
	opts = opts or {}
	local reward, given = def and def.reward, {}
	if type(reward) ~= "table" then return given end
	-- def.paid(self) : aides déjà données par l'ancien système (paliers d'espèces
	-- d'avant la 2.7, lot B) : pas de double don
	local paid = type(def.paid) == "function" and select(2, pcall(def.paid, self)) == true
	if type(reward.aids) == "table" and not opts.cosmeticsOnly and not paid and self.CaptureGrant then
		local ids = {}
		for id in pairs(reward.aids) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			for _ = 1, math.max(0, math.floor(tonumber(reward.aids[id]) or 0)) do
				local ok, result = pcall(self.CaptureGrant, self, id, { quiet = true, silent = true })
				if ok and result == "ok" then given[#given + 1] = id end
			end
		end
	end
	local changed = false
	if type(reward.cosmetic) == "table" then
		local unlocked = self:CompanionData().unlocked
		if type(unlocked) ~= "table" then unlocked = {}; self:CompanionData().unlocked = unlocked end
		local key = tostring(reward.cosmetic[1]) .. ":" .. tostring(reward.cosmetic[2])
		if not unlocked[key] then unlocked[key], changed = true, true; given[#given + 1] = key end
	end
	if reward.appearance and self.DailyGrantAppearance then
		local ok, fresh = pcall(self.DailyGrantAppearance, self, reward.appearance)
		if ok and fresh then given[#given + 1] = "app:" .. tostring(reward.appearance); changed = true end
	end
	if changed and self.CompanionApplyOrnaments then pcall(self.CompanionApplyOrnaments, self) end
	return given
end

-- Hauts faits de compte : leurs cosmétiques suivent sur chaque personnage
function ns:FeatSyncAccountRewards()
	local synced = 0
	for _, def in ipairs(Index().list) do
		if def.scope == "account" and type(def.reward) == "table" and (def.reward.cosmetic or def.reward.appearance)
			and self:FeatGot(def) then
			synced = synced + #self:FeatGrant(def, { cosmeticsOnly = true })
		end
	end
	return synced
end

-- ---------------------------------------------------------------------------
-- Titres : registre, rendu, genre et choix dans FeatsTitles.lua (lot D) :
-- ns:FeatTitleText, ns:FeatTitleGender, ns:FeatTitlesEarned, ns:FeatTitleCode
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Textes d'un haut fait
-- ---------------------------------------------------------------------------
-- 3.7.0 : un secret pas encore obtenu garde son nom pour lui
local function Secret(self, def) return def.hidden and not self:FeatGot(def) end

function ns:FeatName(def)
	if type(def) ~= "table" then def = Index().byId[def] end
	if def and Secret(self, def) then return L.FEAT_SECRET_NAME end
	return def and L["FEAT_" .. def.id] or tostring(def)
end

function ns:FeatIcon(def)
	local cat = def and Index().cats[def.cat]
	return (def and def.icon) or (cat and cat.icon) or (Theme and Theme.LOGO_SMALL)
end

function ns:FeatDescription(def)
	if type(def) ~= "table" then def = Index().byId[def] end
	if not def then return "" end
	-- secret : son indice s'il a été révélé, sinon une phrase d'attente
	if Secret(self, def) then
		local key = "FEATH_" .. tostring(def.id)
		if self:FeatHintKnown(def.id) and L[key] ~= key then return L[key] end
		return L.FEAT_SECRET_WAIT
	end
	local crit = def.crit or {}
	local kind = crit[1]
	if kind == "count" then return self:F(def.desc or ("FEATD_" .. tostring(crit[2])), tonumber(crit[3]) or 1) end
	if TALLY_READ[kind] then return self:F(def.desc or ("FEATD_tally_" .. tostring(crit[2])), tonumber(crit[3]) or 1) end
	if kind == "stat" then return self:F(def.desc or ("FEATD_" .. tostring(crit.alt or "stat")), tonumber(crit[3]) or 1) end
	if kind == "list" then return self:F(def.desc or ("FEATD_list_" .. tostring(crit[2])), #ListItems(self, crit[2])) end
	if kind == "points" then return self:F(def.desc or "FEATD_points", tonumber(crit[2]) or 0) end
	if kind == "meta" then
		if type(crit[2]) == "table" then return self:F(def.desc or "FEATD_meta_ids", #crit[2]) end
		return self:F(def.desc or "FEATD_meta_cat", tonumber(crit[3]) or 1, L["FEATC_" .. tostring(crit[2])])
	end
	if kind == "streak" then return self:F(def.desc or ("FEATD_streak_" .. tostring(crit[2])), tonumber(crit[3]) or 1) end
	return self:F(def.desc or ("FEATD_flag_" .. tostring(crit[2])))
end

-- « titre « Dresseur », Appât savoureux ×1, Cadre doré » (vide sans récompense)
function ns:FeatRewardText(def)
	local reward = def and def.reward
	if type(reward) ~= "table" then return "" end
	local parts = {}
	if reward.title then
		local text = self:FeatTitleText(reward.title)
		if text then parts[#parts + 1] = self:F("FEAT_REWARD_TITLE", text) end
	end
	if type(reward.aids) == "table" then
		local ids = {}
		for id in pairs(reward.aids) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local label = self.CaptureAidLabel and self:CaptureAidLabel(id) or id
			parts[#parts + 1] = self:F("FEAT_REWARD_AID", label, tonumber(reward.aids[id]) or 1)
		end
	end
	if type(reward.cosmetic) == "table" then parts[#parts + 1] = CosmeticLabel(reward.cosmetic[1], reward.cosmetic[2]) end
	if reward.appearance then parts[#parts + 1] = CosmeticLabel("app", reward.appearance) end
	return table.concat(parts, ", ")
end

-- ---------------------------------------------------------------------------
-- Bandeau et chat : file propre au moteur, regroupée, puis la file du carnet
-- ---------------------------------------------------------------------------
ns.featPending = ns.featPending or {}

local Tick
local function EngineClock()
	local fine, err = pcall(Tick)
	if not fine and ns.RecordError then ns:RecordError("feats:tick", err) end
end
-- horloge du moteur sur le cadre partagé des hauts faits (FeatsData.lua)
local function Wake()
	if ns.featsDormant or not ns.FeatClock then return end
	ns.FeatClock("engine", EngineClock)
end

-- 3.7.0 : la fête à la taille de l'exploit. small (5 points) : sans son ;
-- medium (10) : son court ; big (25, 50, un titre, un tour de force) : fanfare.
local SIZE_RANK = { small = 1, medium = 2, big = 3 }
ns.FEAT_SIZE_RANK = SIZE_RANK
function ns:FeatSize(def)
	if type(def) ~= "table" then def = Index().byId[def] end
	if not def then return "small" end
	local pts = tonumber(def.pts) or 0
	if (type(def.reward) == "table" and def.reward.title ~= nil) or pts >= 25 or def.cat == ns.FEAT_FOS then return "big" end
	if pts >= 10 then return "medium" end
	return "small"
end
local function Bigger(a, b)
	if (SIZE_RANK[b] or 0) > (SIZE_RANK[a] or 0) then return b end
	return a
end

-- Son d'une fête : rend l'identifiant joué (nil : aucun)
function ns:FeatPlaySize(size)
	if self:DB().featSound == false or size == "small" then return nil end
	local play = G("PlaySound")
	if type(play) ~= "function" then return nil end
	if size == "medium" then
		if pcall(play, ns.FEAT_SOUND_FALLBACK, "Master") then return ns.FEAT_SOUND_FALLBACK end
		return nil
	end
	if pcall(play, ns.FEAT_SOUND, "Master") then return ns.FEAT_SOUND end
	if pcall(play, ns.FEAT_SOUND_FALLBACK, "Master") then return ns.FEAT_SOUND_FALLBACK end
	return nil
end

local function Record(self, def)
	local title = type(def.reward) == "table" and def.reward.title and self:FeatTitleText(def.reward.title) or nil
	return { id = def.id, name = self:FeatName(def), pts = tonumber(def.pts) or 0, icon = self:FeatIcon(def), title = title,
		size = self:FeatSize(def) }
end

-- Une obtention en attente d'annonce (record), ou un lot déjà compté
-- ({ many = n, pts = p } : rattrapage)
function ns:FeatQueue(record)
	table.insert(self.featPending, record)
	self.featFlushAt = math.max(self.featFlushAt or 0, Now() + FLUSH_DELAY)
	Wake()
end

-- 3.0.1 : le bandeau groupé nomme ses hauts faits. Jusqu'à 3 noms séparés
-- par « · », puis « et N autres » ; `fits(texte)` dit si la ligne tient dans
-- le bandeau : on retire des noms, puis on raccourcit le premier (…).
local NAMES_SHOWN = 3
function ns:FeatNamesLine(names, fits)
	fits = fits or function() return true end
	local count = #names
	local function Line(k, first)
		local shown = { first or names[1] }
		for i = 2, k do shown[i] = names[i] end
		local text = table.concat(shown, " · ")
		local rest = count - k
		if rest == 1 then text = text .. " " .. L.FEAT_TOAST_MORE_1
		elseif rest > 1 then text = text .. " " .. self:F("FEAT_TOAST_MORE", rest) end
		return text
	end
	for k = math.min(NAMES_SHOWN, count), 1, -1 do
		local text = Line(k)
		if fits(text) then return text end
	end
	-- même un seul nom ne tient pas : raccourci, caractère par caractère (UTF-8)
	local first = tostring(names[1] or "")
	while #first > 1 do
		first = first:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
		local text = Line(1, first .. "…")
		if fits(text) then return text end
	end
	return Line(1, "…")
end

-- La ligne de chat d'un lot : tous les noms, en lignes d'environ 250 octets
local CHAT_LINE = 250
function ns:FeatChatLines(names, pts)
	local lines, current = {}, {}
	local function Width(list) return #table.concat(list, ", ") end
	for _, name in ipairs(names) do
		current[#current + 1] = name
		if #current > 1 and Width(current) > CHAT_LINE - 40 then
			table.remove(current)
			lines[#lines + 1] = table.concat(current, ", ")
			current = { name }
		end
	end
	if #current > 0 then lines[#lines + 1] = table.concat(current, ", ") end
	local out = {}
	for index, chunk in ipairs(lines) do
		if index == #lines then
			out[#out + 1] = index == 1 and self:F("FEAT_CHAT_MANY", chunk, pts) or self:F("FEAT_CHAT_MANY_CONT", self:F("FEAT_CHAT_MANY", chunk, pts):match(": (.*)$") or chunk)
		elseif index == 1 then
			out[#out + 1] = (self:F("FEAT_CHAT_MANY", chunk, pts):match("^(.-: )") or "") .. chunk .. ","
		else
			out[#out + 1] = self:F("FEAT_CHAT_MANY_CONT", chunk .. ",")
		end
	end
	return out
end

-- Clic sur un bandeau groupé : la page Hauts faits, les obtenus (du plus
-- récent au plus ancien), en haut de la liste
function ns:FeatOpenRecent()
	self:DB().featsFilter = "got"
	local frame = self.OpenJournalFeats and self:OpenJournalFeats("all")
	if frame then
		frame.featsOffset = 0
		if self.RefreshJournal then pcall(self.RefreshJournal, self) end
	end
	return frame
end

-- Annonce ce qui attend : jamais en combat ni pendant la sourdine de capture.
-- À partir de 3 (ou avec un lot de rattrapage) : un seul bandeau groupé.
function ns:FeatFlush(force)
	local pending = self.featPending
	if #pending == 0 then return nil end
	if InCombat() or (self.CaptureMuted and self:CaptureMuted()) then return false end
	if not force and Now() < (self.featFlushAt or 0) then return false end
	self.featPending, self.featFlushAt = {}, nil
	local db = self:DB()
	local units, pts, grouped = 0, 0, false
	local names, namedPts = {}, 0
	local size = "small"
	for _, record in ipairs(pending) do
		units, pts = units + (record.many or 1), pts + (record.pts or 0)
		size = Bigger(size, record.size or "big")
		if record.many then grouped = true
		else names[#names + 1] = record.name; namedPts = namedPts + (record.pts or 0) end
	end
	local collapse = grouped or units >= TOAST_COLLAPSE
	if collapse then
		-- 3.0.1 : un lot = une ligne de chat qui les nomme tous (même sans le
		-- réglage « une ligne par haut fait » : sinon la liste se perd)
		if #names > 0 then
			for _, line in ipairs(self:FeatChatLines(names, namedPts)) do self:Print(line) end
		end
	elseif db.featChat == true then
		for _, record in ipairs(pending) do self:Print(self:F("FEAT_CHAT", record.name, record.pts or 0)) end
	end
	if db.featToast == false or not self.JournalToastPush then return true end
	-- 3.7.0 : le son suit la taille de la fête (le dessin de la pastille
	-- viendra avec la page ; la taille part avec le bandeau)
	local function Sound(which) return function() ns:FeatPlaySize(which) end end
	local function Open() ns:FeatOpenRecent() end
	if collapse then
		local text = self:F("FEAT_TOAST_MANY", units, pts)
		local metaCat = Index().cats.meta
		-- rattrapage de connexion (sans noms) : le texte d'avant ; sinon les
		-- noms (ajustés au bandeau), le compte et les points dans le titre
		local named = not grouped and #names > 0
		self:JournalToastPush({ kind = "feat", title = named and self:F("FEAT_TOAST_MANY_HEAD", units) or L.FEAT_TOAST_MANY_TITLE,
			name = text, message = text, names = named and names or nil, size = size,
			icon = metaCat and metaCat.icon, points = pts, onShow = Sound(size), onClick = Open, count = units })
	else
		for _, record in ipairs(pending) do
			local one = record.size or "big"
			self:JournalToastPush({ kind = "feat", title = L.FEAT_TOAST_TITLE, name = record.name, id = record.id,
				message = self:F("FEAT_CHAT", record.name, record.pts or 0), icon = record.icon, points = record.pts, size = one,
				sub = record.title and self:F("FEAT_TOAST_NEW_TITLE", record.title) or nil, onShow = Sound(one) })
		end
	end
	return true
end

-- 3.7.0 : paillettes d'un haut fait (2, 5, 15, 40 selon ses points ; 0 pour un
-- tour de force), payées une fois : la marque g = montant reste dans got[id].
-- Rend le montant payé, ou nil si rien n'est dû (déjà payé, pas de porte-monnaie).
function ns:FeatGlitterOf(def)
	return ns.FEAT_GLITTER[tonumber(def and def.pts) or 0] or 0
end
function ns:FeatPayGlitter(def, entry)
	if type(def) ~= "table" or type(entry) ~= "table" or entry.g ~= nil then return nil end
	local amount = self:FeatGlitterOf(def)
	if amount > 0 then
		if type(self.PaillettesAdd) ~= "function" then return nil end
		self:PaillettesAdd(amount, "feat")
	end
	entry.g = amount
	return amount
end

-- Rattrapage des paillettes : les hauts faits du compte et du personnage
-- connecté obtenus avant la 3.7.0 (sans marque g), payés en une fois.
-- Rend le total versé et le nombre de hauts faits payés.
function ns:FeatGlitterCatchUp()
	local total, count = 0, 0
	for _, scope in ipairs({ "account", "char" }) do
		local got = self:FeatStore(scope).got
		local ids = {}
		for id, entry in pairs(got) do
			if type(entry) == "table" and entry.g == nil then ids[#ids + 1] = id end
		end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local def = Index().byId[id]
			if def and def.scope == scope then
				local paid = self:FeatPayGlitter(def, got[id])
				if paid and paid > 0 then total, count = total + paid, count + 1 end
			end
		end
	end
	return total, count
end

-- Attribue un haut fait. opts : silent (ni bandeau ni chat), retro (r = true),
-- at, lvl (date et niveau repris d'une migration)
function ns:FeatAward(def, opts)
	if type(def) ~= "table" then def = Index().byId[def] end
	if not def then return false end
	opts = opts or {}
	local store = self:FeatStore(def.scope)
	if store.got[def.id] then return false end
	local at = tonumber(opts.at)
	store.got[def.id] = { at = (at and at > 0) and at or Time(), lvl = tonumber(opts.lvl) or Level(),
		r = (opts.retro or opts.silent) and true or nil }
	local ok, err = pcall(self.FeatGrant, self, def)
	if not ok and self.RecordError then self:RecordError("feats:grant", err) end
	ok, err = pcall(self.FeatPayGlitter, self, def, store.got[def.id])
	if not ok and self.RecordError then self:RecordError("feats:glitter", err) end
	local titled = type(def.reward) == "table" and def.reward.title ~= nil
	local pts = tonumber(def.pts) or 0
	if not opts.silent then
		self:FeatQueue(Record(self, def))
		if (pts >= ns.FEAT_GUILD_MIN or titled) and self.CompanionSay then
			pcall(self.CompanionSay, self, "UNLOCK", { args = { self:FeatName(def) } })
		end
	end
	self:FireCallback("FEAT_EARNED", { id = def.id, n = def.n, pts = pts, scope = def.scope, cat = def.cat,
		title = titled and def.reward.title or nil, retro = (opts.retro or opts.silent) and true or false,
		announce = not (opts.retro or opts.silent) and (pts >= ns.FEAT_GUILD_MIN or titled) })
	if self.journalFrame and self.journalFrame:IsShown() and self.RefreshJournal then pcall(self.RefreshJournal, self) end
	return true
end

-- ---------------------------------------------------------------------------
-- Évaluation : seuls les hauts faits non obtenus abonnés aux sujets touchés
-- ---------------------------------------------------------------------------
-- 3.7.0 : les lignes abonnées aux sujets touchés, par l'index sujet -> lignes
-- (dans l'ordre du catalogue) ; nil : tout le catalogue
local NONE = {}
local function Candidates(idx, topics)
	if topics == nil then return idx.list end
	local only, count = nil, 0
	for topic in pairs(topics) do only, count = topic, count + 1 end
	if count == 0 then return NONE end
	if count == 1 then return idx.byTopic[only] or NONE end
	local seen, out = {}, {}
	for topic in pairs(topics) do
		for _, def in ipairs(idx.byTopic[topic] or NONE) do
			if not seen[def] then seen[def] = true; out[#out + 1] = def end
		end
	end
	table.sort(out, function(a, b) return idx.pos[a] < idx.pos[b] end)
	return out
end

-- topics : { [sujet] = true } ou nil (tout). opts : silent, retro, retroOnly.
-- Rend la liste des définitions obtenues.
function ns:FeatEvaluate(topics, opts)
	opts = opts or {}
	if not ModuleOn() then return {} end
	local idx = Index()
	local earned, pass, combat = {}, topics, InCombat()
	for _ = 1, MAX_LOOPS do
		self:FeatCacheReset()
		local fresh = false
		for _, def in ipairs(Candidates(idx, pass)) do
			if not def.pending and not self:FeatGot(def)
				and (not opts.retroOnly or Retro(def)) and not (combat and (def.crit or {})[1] == "stat") then
				local cur, max, state = self:FeatProgress(def)
				if state == "open" and max > 0 and cur >= max then
					if self:FeatAward(def, { silent = opts.silent, retro = opts.retro }) then
						earned[#earned + 1] = def
						fresh = true
					end
				end
			end
		end
		if not fresh then break end
		pass = { feat = true }
	end
	self:FeatCacheReset()
	return earned
end

-- Un crochet signale un sujet : une passe groupée un peu plus tard
ns.featDirty = ns.featDirty or {}
function ns:FeatTouch(topic)
	if self.featsDormant or topic == nil then return end
	self.featDirty[topic] = true
	self.featEvalAt = self.featEvalAt or (Now() + EVAL_DELAY)
	Wake()
end

-- Faits ponctuels et compteurs tenus par le moteur (lots B et C)
function ns:FeatFlag(key, scope)
	local store = self:FeatStore(scope == "account" and "account" or "char")
	if not store.flag[key] then store.flag[key] = Time() end
	self:FeatTouch("flag")
	return store.flag[key]
end

function ns:FeatCount(key, delta, scope)
	local store = self:FeatStore(scope == "account" and "account" or "char")
	if delta ~= nil then
		store.ctr[key] = math.max(0, (tonumber(store.ctr[key]) or 0) + (tonumber(delta) or 0))
		self:FeatTouch("flag")
	end
	return tonumber(store.ctr[key]) or 0
end

function ns:FeatCountReset(key, scope)
	self:FeatStore(scope == "account" and "account" or "char").ctr[key] = nil
end

-- ---------------------------------------------------------------------------
-- Migration des tampons et rattrapage à la connexion
-- ---------------------------------------------------------------------------
-- Une définition qui se date depuis les données existantes (relevés du
-- carnet, paliers d'espèces payés) : ok, at, lvl
local function DateOf(self, def)
	local crit = def.crit or {}
	if crit[1] == "count" then
		local source = SOURCES[crit[2]]
		if source and source.dateOf then return source.dateOf(self, tonumber(crit[3]) or 1) end
		return nil
	end
	if crit[1] == "list" then
		local items = ListItems(self, crit[2])
		if #items == 0 then return nil end
		local stamps, last = Stamps(self), 0
		for _, item in ipairs(items) do
			if type(item) ~= "string" or stamps[item] == nil then return nil end
			last = math.max(last, StampAt(stamps[item]) or 0)
		end
		return true, last > 0 and last or nil
	end
	return nil
end

local function MigrateScope(self, scope, out)
	for _, def in ipairs(Index().list) do
		if def.scope == scope and not def.pending and not self:FeatGot(def) then
			local ok, done, at, lvl = pcall(DateOf, self, def)
			if ok and done then
				if self:FeatAward(def, { silent = true, at = at, lvl = lvl }) then out[#out + 1] = def end
			end
		end
	end
end

-- Une fois pour le compte, une fois par personnage ; silencieuse, sans
-- toucher à journal.stamps (la 2.6 relit le carnet intact). Rend les
-- définitions obtenues par la migration.
function ns:FeatMigrate()
	local out = {}
	local account = self:FeatStore("account")
	if not account.v then
		local ok, err = pcall(MigrateScope, self, "account", out)
		if not ok and self.RecordError then self:RecordError("feats:migrate", err) end
		account.v = 1
		-- l'ancienne ligne de chat des tampons devient celle des hauts faits
		local db = self:DB()
		if db.journalChat == true then db.featChat = true end
	end
	local char = self:FeatStore("char")
	if not char.v then
		local ok, err = pcall(MigrateScope, self, "char", out)
		if not ok and self.RecordError then self:RecordError("feats:migrate", err) end
		char.v = 1
	end
	return out
end

-- Tout ce qui est déjà acquis, sans bandeau un par un
function ns:FeatRetroScan()
	return self:FeatEvaluate(nil, { silent = true, retroOnly = true })
end

-- À la connexion (3 s après, hors combat, une fois par session) : migration,
-- cosmétiques de compte, rattrapage ; une seule ligne de chat et au plus un
-- bandeau pour tout ce qui vient d'être trouvé. false : à refaire (combat).
function ns:FeatLogin()
	if self.featLoginDone then return nil end
	if InCombat() then return false end
	if not ModuleOn() then return nil end
	self.featLoginDone = true
	local found = self:FeatMigrate()
	local ok, err = pcall(self.FeatSyncAccountRewards, self)
	if not ok and self.RecordError then self:RecordError("feats:sync", err) end
	for _, def in ipairs(self:FeatRetroScan()) do found[#found + 1] = def end
	if #found > 0 then
		local pts, size = 0, "small"
		for _, def in ipairs(found) do
			pts = pts + (tonumber(def.pts) or 0)
			size = Bigger(size, self:FeatSize(def))
		end
		self:Print(self:F("FEAT_RETRO", #found, pts))
		if #found == 1 then self:FeatQueue(Record(self, found[1]))
		else self:FeatQueue({ many = #found, pts = pts, size = size }) end
	end
	-- 3.7.0 : les paillettes des hauts faits obtenus avant (une ligne de chat)
	local okPay, glitter, paid = pcall(self.FeatGlitterCatchUp, self)
	if not okPay and self.RecordError then self:RecordError("feats:glitter", glitter) end
	if okPay and paid > 0 then self:Print(self:F("FEAT_GLITTER_CATCHUP", glitter, paid)) end
	-- 3.7.0 (page, « Rattrapés avec cette version ») : le relevé du premier
	-- rattrapage, gardé une fois au compte
	local okNote, err2 = pcall(ns.FeatCatchUpNote, self, found, okPay and glitter or 0)
	if not okNote and self.RecordError then self:RecordError("feats:catchup", err2) end
	return found
end

-- 3.7.0 : relevé du rattrapage de la mise à jour, au compte (db.feats.catchup =
-- { v = 1, at, ids = { id… }, pts, glitter }). Posé une seule fois, à la
-- première connexion qui passe par FeatLogin : les hauts faits trouvés
-- (migration et rattrapage), leurs points comptables, les paillettes versées
-- pour eux et celles du rattrapage des paillettes. Rend le relevé posé (nil :
-- il existait déjà).
function ns:FeatCatchUpNote(found, glitter)
	local account = self:FeatStore("account")
	if account.catchup ~= nil then return nil end
	local ids, pts, total = {}, 0, tonumber(glitter) or 0
	for _, def in ipairs(found or {}) do
		ids[#ids + 1] = def.id
		if self:FeatCountable(def) then pts = pts + (tonumber(def.pts) or 0) end
		local got = self:FeatGot(def)
		total = total + (type(got) == "table" and tonumber(got.g) or 0)
	end
	account.catchup = { v = 1, at = Time(), ids = ids, pts = pts, glitter = total }
	return account.catchup
end

-- Le relevé, s'il a donné au moins un haut fait encore au catalogue :
-- { ids, pts, glitter } ; nil sinon
function ns:FeatCatchUp()
	local note = self:FeatStore("account").catchup
	if type(note) ~= "table" or type(note.ids) ~= "table" then return nil end
	local ids = {}
	for _, id in ipairs(note.ids) do if Index().byId[id] then ids[#ids + 1] = id end end
	if #ids == 0 then return nil end
	return { ids = ids, pts = tonumber(note.pts) or 0, glitter = tonumber(note.glitter) or 0, at = tonumber(note.at) or 0 }
end

-- ---------------------------------------------------------------------------
-- 3.7.0 : secrets, rangs, comparaison, suivi, lignes de la page
-- ---------------------------------------------------------------------------
-- Indices révélés des secrets : au compte (db.feats.hints = { [id] = at })
local function Hints(self)
	local store = self:FeatStore("account")
	if type(store.hints) ~= "table" then store.hints = {} end
	return store.hints
end

function ns:FeatHintKnown(id)
	if type(id) == "table" then id = id.id end
	return Hints(self)[id] ~= nil
end

-- Révèle l'indice d'un secret tiré au hasard parmi ceux qui restent (ni
-- obtenus ni déjà révélés, hors lignes en attente). Rend le texte de
-- l'indice et l'identifiant, ou nil s'il n'en reste pas.
function ns:FeatHintNext()
	local hints, left = Hints(self), {}
	for _, def in ipairs(Index().list) do
		if def.hidden and not def.pending and not self:FeatGot(def) and hints[def.id] == nil then left[#left + 1] = def end
	end
	if #left == 0 then return nil end
	local def = left[math.random(#left)]
	hints[def.id] = Time()
	local key = "FEATH_" .. def.id
	return (L[key] ~= key) and L[key] or L.FEAT_SECRET_WAIT, def.id
end

-- Rang de renommée d'un total de points (par défaut : compte + personnage
-- connecté). Rend l'indice du rang (0 : aucun), son nom (nil : aucun), le
-- seuil suivant et son nom (nil au dernier rang), le total.
function ns:FeatRank(points)
	points = tonumber(points) or (self:FeatPoints(nil))
	local index = 0
	for i, at in ipairs(ns.FEAT_RANKS) do if points >= at then index = i end end
	local nextAt = ns.FEAT_RANKS[index + 1]
	return index, index > 0 and L["FEAT_RANK_" .. index] or nil, nextAt, nextAt and L["FEAT_RANK_" .. (index + 1)] or nil, points
end

-- Comparaison : un bit par code n, six bits par caractère (A-Z a-z 0-9 - _),
-- sûrs pour un message d'addon et pour un texte copié ; les zéros de queue
-- sont retirés (« » : rien d'obtenu).
local BITS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
ns.FEAT_BITS_ALPHABET = BITS
local BIT_VALUE = {}
for i = 1, #BITS do BIT_VALUE[BITS:sub(i, i)] = i - 1 end

function ns:FeatBits(codes)
	local cells, last = {}, 0
	local function Set(n)
		n = tonumber(n)
		if not n or n < 1 or n ~= math.floor(n) then return end
		local cell, bit = math.floor((n - 1) / 6) + 1, (n - 1) % 6
		local value = cells[cell] or 0
		if math.floor(value / 2 ^ bit) % 2 == 0 then cells[cell] = value + 2 ^ bit end
		if cell > last then last = cell end
	end
	if type(codes) == "table" then
		for n, on in pairs(codes) do if on then Set(n) end end
	else
		for _, def in ipairs(Index().list) do if self:FeatGot(def) then Set(def.n) end end
	end
	local out = {}
	for cell = 1, last do
		local value = cells[cell] or 0
		out[cell] = BITS:sub(value + 1, value + 1)
	end
	return table.concat(out)
end

-- L'ensemble des codes { [n] = true } d'un texte de FeatBits (caractères
-- inconnus ignorés : ils valent zéro)
function ns:FeatBitsDecode(text)
	local set = {}
	if type(text) ~= "string" then return set end
	for cell = 1, #text do
		local value = BIT_VALUE[text:sub(cell, cell)]
		if value then
			for bit = 0, 5 do
				if math.floor(value / 2 ^ bit) % 2 == 1 then set[(cell - 1) * 6 + bit + 1] = true end
			end
		end
	end
	return set
end

-- Suivre : jusqu'à 3 hauts faits par personnage (CharData().feats.follow).
-- on = true : suivre, false : ne plus suivre, nil : bascule. Rend true si
-- la liste a changé, sinon false et la raison ("unknown", "done", "full").
local function FollowList(self)
	local store = self:FeatStore("char")
	if type(store.follow) ~= "table" then store.follow = {} end
	return store.follow
end

function ns:FeatFollow(id, on)
	if type(id) == "table" then id = id.id end
	local def = Index().byId[id]
	local list = FollowList(self)
	local at
	for i, other in ipairs(list) do if other == id then at = i end end
	if on == nil then on = at == nil end
	if not on then
		if not at then return false end
		table.remove(list, at)
		return true
	end
	if at then return false end
	if not def or def.pending or Secret(self, def) then return false, "unknown" end
	if self:FeatGot(def) then return false, "done" end
	if #self:FeatFollowed() >= ns.FEAT_FOLLOW_MAX then return false, "full" end
	list[#list + 1] = id
	-- premier suivi : le compteur de Tally.lua (s'il est là)
	if type(self.TallyAdd) == "function" and (type(self.TallyGet) ~= "function" or (tonumber(self:TallyGet("follow")) or 0) == 0) then
		pcall(self.TallyAdd, self, "follow")
	end
	return true
end

-- Les hauts faits suivis (identifiants), sans ceux obtenus depuis ni ceux
-- disparus du catalogue (retirés de la liste au passage)
function ns:FeatFollowed()
	local list, out = FollowList(self), {}
	for i = #list, 1, -1 do
		local def = Index().byId[list[i]]
		if not def or def.pending or self:FeatGot(def) then table.remove(list, i) end
	end
	for i, id in ipairs(list) do out[i] = id end
	return out
end

-- Une ligne de la page : { def, cur, max, state, got, at }
function ns:FeatEntry(def)
	local got = self:FeatGot(def)
	local cur, max, state = self:FeatProgress(def)
	return { def = def, cur = cur, max = max, state = state, got = got, at = got and tonumber(got.at) or 0 }
end

-- Ordre de la page : non obtenus par progression décroissante, puis grisés
-- (source illisible), puis obtenus du plus récent au plus ancien ; à
-- égalité, le code
local function EntryRank(entry)
	if entry.got then return 3 end
	if entry.state == "pending" then return 2 end
	return 1
end
function ns.FeatEntryBefore(a, b)
	local ra, rb = EntryRank(a), EntryRank(b)
	if ra ~= rb then return ra < rb end
	if ra == 1 then
		local pa = a.max > 0 and a.cur / a.max or 0
		local pb = b.max > 0 and b.cur / b.max or 0
		if pa ~= pb then return pa > pb end
	elseif ra == 3 and a.at ~= b.at then
		return a.at > b.at
	end
	return (tonumber(a.def.n) or 0) < (tonumber(b.def.n) or 0)
end

-- Lignes d'une catégorie ("all" : toutes) groupées par série, dans l'ordre de
-- la page. Une série devient un groupe { key, defs (seuil croissant), index
-- (palier en cours : le premier non obtenu, le dernier si tous le sont), cur,
-- max (du palier en cours), def (ce palier), state, got (tous obtenus : celui
-- du dernier palier), at, done (paliers obtenus) } ; une ligne sans série
-- reste telle quelle ({ def, cur, max, state, got, at }). filter : "all",
-- "got" (série : tous les paliers), "open" (série : au moins un palier à
-- faire). Lignes en attente jamais listées.
function ns:FeatSeriesList(cat, filter)
	cat, filter = cat or "all", filter or "all"
	self:FeatCacheReset()
	local idx = Index()
	local out, done = {}, {}
	for _, def in ipairs(idx.list) do
		if (cat == "all" or def.cat == cat) and not def.pending then
			local key = def.series
			local members = key and idx.series[key]
			if members and #members > 1 then
				if not done[key] then
					done[key] = true
					local defs, index, count = {}, nil, 0
					for _, member in ipairs(members) do
						if not member.pending and (cat == "all" or member.cat == cat) then
							defs[#defs + 1] = member
							if self:FeatGot(member) then count = count + 1 elseif not index then index = #defs end
						end
					end
					index = index or #defs
					local entry = self:FeatEntry(defs[index])
					entry.key, entry.defs, entry.index, entry.done = key, defs, index, count
					if count < #defs then entry.got, entry.at = nil, 0 end
					local wanted = filter == "all" or (filter == "got" and entry.got) or (filter == "open" and not entry.got)
					if wanted then out[#out + 1] = entry end
				end
			else
				local entry = self:FeatEntry(def)
				local wanted = filter == "all" or (filter == "got" and entry.got) or (filter == "open" and not entry.got)
				if wanted then out[#out + 1] = entry end
			end
		end
	end
	table.sort(out, ns.FeatEntryBefore)
	self:FeatCacheReset()
	return out
end

-- À portée de main : les `count` hauts faits comptables, non obtenus, non
-- secrets, pas encore atteints, les plus proches du but (cur / max décroissant ; à égalité le
-- moins de points, puis le code). Chacun : { def, cur, max }. Calculé à la
-- demande seulement (une passe sur le catalogue).
-- 3.7.0 (page) : `pick(def)` facultatif ne garde que les lignes qu'il accepte
-- (« Récompenses proches » : celles qui donnent un titre, un cosmétique, une aide).
function ns:FeatNearest(count, pick)
	count = math.max(0, math.floor(tonumber(count) or 4))
	self:FeatCacheReset()
	local list = {}
	for _, def in ipairs(Index().list) do
		if not def.hidden and self:FeatCountable(def) and not self:FeatGot(def) and (pick == nil or pick(def)) then
			local cur, max, state = self:FeatProgress(def)
			-- (but déjà atteint : la prochaine passe l'attribue, il n'est plus « à portée »)
			if state == "open" and max > 0 and cur < max then list[#list + 1] = { def = def, cur = cur, max = max, ratio = cur / max } end
		end
	end
	self:FeatCacheReset()
	table.sort(list, function(a, b)
		if a.ratio ~= b.ratio then return a.ratio > b.ratio end
		local pa, pb = tonumber(a.def.pts) or 0, tonumber(b.def.pts) or 0
		if pa ~= pb then return pa < pb end
		return (tonumber(a.def.n) or 0) < (tonumber(b.def.n) or 0)
	end)
	local out = {}
	for i = 1, math.min(count, #list) do out[i] = { def = list[i].def, cur = list[i].cur, max = list[i].max } end
	return out
end

-- Libellé d'un élément de liste cochée : le crochet de la liste
-- (FEAT_LISTS[nom].label(self, item, i, total)), le nom gardé par le relevé,
-- le nom du lieu ou du donjon, un haut fait, sinon la description de la source
local function DungeonLabel(self, key)
	local entry = type(self.DUNGEONS) == "table" and self.DUNGEONS[key]
	if type(entry) == "table" and self.DungeonName then
		local ok, name = pcall(self.DungeonName, self, entry)
		if ok and type(name) == "string" then return name end
	end
	return tostring(key)
end
local function ItemLabel(self, list, item, i, total)
	if list and type(list.label) == "function" then
		local ok, text = pcall(list.label, self, item, i, total)
		if ok and type(text) == "string" and text ~= "" then return text end
	end
	if type(item) == "string" then
		local stamp = Stamps(self)[item]
		if type(stamp) == "table" and type(stamp.name) == "string" and stamp.name ~= "" then return stamp.name end
		local kind, key = item:match("^(%a+):(.+)$")
		if kind == "dungeon" then return DungeonLabel(self, key) end
		if kind == "capital" and self.JournalHubGroups then
			local ok, groups = pcall(self.JournalHubGroups, self)
			for name, group in pairs(ok and groups or {}) do
				if tostring(group.areaID) == key then return name end
			end
		end
		if kind == "zone" then
			local map = G("C_Map")
			local info = type(map) == "table" and Call(map.GetMapInfo, tonumber(key))
			if type(info) == "table" and type(info.name) == "string" then return info.name end
		end
		return tostring(key or item)
	end
	if type(item) == "table" then
		local source, n = tostring(item[1]), tonumber(item[2]) or 1
		local boss = source:match("^boss_(.+)$")
		if boss then return DungeonLabel(self, boss) end
		local feat = source:match("^got_(.+)$")
		if feat then return self:FeatName(feat) end
		local cat = source:match("^featsCat_(.+)$")
		if cat then return self:F("FEATD_meta_cat", n, L["FEATC_" .. cat]) end
		local key = (source == "featPoints") and "FEATD_points" or ("FEATD_" .. source)
		if L[key] ~= key then return self:F(key, n) end
		return self:F("FEAT_CHECK_STEP", i, total)
	end
	return tostring(item)
end

-- Liste cochée d'un critère list ou meta (liste d'identifiants), dans
-- l'ordre du catalogue : { { label, done }, … } ; nil pour les autres
-- critères, un méta « n d'une catégorie » et un secret pas encore obtenu.
function ns:FeatChecklist(def)
	if type(def) ~= "table" then def = Index().byId[def] end
	if not def or Secret(self, def) then return nil end
	local crit = def.crit or {}
	local out = {}
	if crit[1] == "list" then
		self:FeatCacheReset()
		local list = ns.FEAT_LISTS[crit[2]]
		local items = ListItems(self, crit[2])
		for i, item in ipairs(items) do
			out[i] = { label = ItemLabel(self, list, item, i, #items), done = ItemDone(self, item, def.scope) and true or false }
		end
		self:FeatCacheReset()
		return out
	end
	if crit[1] == "meta" and type(crit[2]) == "table" then
		for i, id in ipairs(crit[2]) do out[i] = { label = self:FeatName(id), done = self:FeatGot(id) ~= nil } end
		return out
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Commandes : /qc hf, /qc hf diag
-- ---------------------------------------------------------------------------
-- Statistiques employées par le catalogue (et la sonde), triées
function ns:FeatStatIDs()
	local set, list = { [ns.FEAT_STAT_PROBE] = true }, {}
	for _, def in ipairs(Index().list) do
		local crit = def.crit or {}
		if crit[1] == "stat" then for _, id in ipairs(crit[2] or {}) do set[id] = true end end
	end
	for id in pairs(set) do list[#list + 1] = id end
	table.sort(list)
	return list
end

-- Diagnostic : lignes imprimées (et rendues pour les tests)
function ns:FeatDiag()
	local lines = { L.FEAT_DIAG_HEAD }
	self:FeatStatReset()
	if not self:FeatStatsOn() then
		lines[#lines + 1] = L.FEAT_DIAG_STATS_OFF
	elseif self:FeatStatsOK() then
		lines[#lines + 1] = self:F("FEAT_DIAG_STATS_OK", ns.FEAT_STAT_PROBE, RawText(RawStat(ns.FEAT_STAT_PROBE)))
	else
		lines[#lines + 1] = L.FEAT_DIAG_STATS_NO
	end
	for _, id in ipairs(self:FeatStatIDs()) do
		local raw = RawStat(id)
		local value = raw ~= nil and ns.FeatParseStat(raw) or nil
		lines[#lines + 1] = self:F("FEAT_DIAG_STAT", id, value and tostring(value) or L.FEAT_DIAG_UNREADABLE, RawText(raw))
	end
	local pending, unreadable = 0, 0
	for _, def in ipairs(Index().list) do
		if def.pending then pending = pending + 1
		else
			local _, _, state = self:FeatProgress(def)
			if state == "pending" then unreadable = unreadable + 1 end
		end
	end
	local _, accountCount = self:FeatPoints("account")
	local _, charCount = self:FeatPoints("char")
	lines[#lines + 1] = self:F("FEAT_DIAG_COUNTS", #Index().list, accountCount, charCount, pending, unreadable)
	lines[#lines + 1] = self:F("FEAT_DIAG_POINTS", (self:FeatPoints("account")), (self:FeatPoints("char")))
	for index, line in ipairs(lines) do
		if index == 1 then self:Print(line) else print("   " .. line) end
	end
	return lines
end

function ns:FeatCommand(rest)
	local word = ns.AsciiLower and ns.AsciiLower(tostring(rest or "")) or tostring(rest or "")
	if word == "diag" then return self:FeatDiag() end
	if self.OpenJournalFeats then return self:OpenJournalFeats() end
	return nil
end
ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["hf"] = function(self, rest) return self:FeatCommand(rest) end
ns.EXTRA_COMMANDS["hautsfaits"] = ns.EXTRA_COMMANDS["hf"]
ns.EXTRA_COMMANDS["achievements"] = ns.EXTRA_COMMANDS["hf"]

-- ---------------------------------------------------------------------------
-- Crochets : les modules existants signalent leurs sujets
-- ---------------------------------------------------------------------------
local function After(topic, ...)
	ns:FeatTouch(topic)
	return ...
end
local function AfterIf(topic, ...)
	if (...) then ns:FeatTouch(topic) end
	return ...
end

local function Hook(name, topic, onlyIfTrue)
	local base = ns[name]
	if type(base) ~= "function" then return false end
	if onlyIfTrue then
		ns[name] = function(self, ...) return AfterIf(topic, base(self, ...)) end
	else
		ns[name] = function(self, ...) return After(topic, base(self, ...)) end
	end
	return true
end

Hook("CaptureResolve", "capture", true)        -- capture réussie
Hook("CaptureBatchFlush", "capture")           -- volée « Tout capturer »
Hook("ShinyKill", "shiny")
Hook("ShinySpot", "shiny")
Hook("MenagerieSealCheck", "seal", true)       -- zone scellée
Hook("MenagerieTypeCheck", "seal")
Hook("MenagerieRankCheck", "seal")
Hook("JournalEarn", "place", true)             -- relevé de lieu (tampon)
Hook("MissionGrant", "mission")
Hook("WeeklyEvent", "mission")
Hook("InnStamp", "mission")
Hook("TreatCheckZone", "zone")                 -- paliers de zone (25/50/75/100 %)
Hook("ChestPick", "zone")                      -- coffre de zone ouvert
Hook("BestiaryOnKill", "kill")                 -- victime comptée (repli de la stat 107)

-- ---------------------------------------------------------------------------
-- Horloge et événements
-- ---------------------------------------------------------------------------
function Tick()
	local now = Now()
	if ns.featLoginAt and now >= ns.featLoginAt then
		ns.featLoginAt = nil
		local ok, result = pcall(ns.FeatLogin, ns)
		if not ok and ns.RecordError then ns:RecordError("feats:login", result) end
		if ok and result == false then ns.featLoginAt = now + 1 end
	end
	-- avant le rattrapage de la connexion, les sujets attendent : c'est lui
	-- qui attribue en silence ce qui était déjà acquis (paliers rattrapés…)
	if ns.featEvalAt and now >= ns.featEvalAt and not ns.featLoginAt then
		local topics = ns.featDirty
		ns.featDirty, ns.featEvalAt = {}, nil
		local ok, err = pcall(ns.FeatEvaluate, ns, topics)
		if not ok and ns.RecordError then ns:RecordError("feats:evaluate", err) end
	end
	if #ns.featPending > 0 then
		local ok, err = pcall(ns.FeatFlush, ns)
		if not ok and ns.RecordError then ns:RecordError("feats:flush", err) end
	end
	if not (ns.featLoginAt or ns.featEvalAt or #ns.featPending > 0) and ns.FeatClock then ns.FeatClock("engine", nil) end
end

local HANDLERS = {
	PLAYER_ENTERING_WORLD = function()
		if ns.featsDormant or ns.featLoginDone then return end
		ns.featLoginAt = Now() + LOGIN_DELAY
		Wake()
	end,
	PLAYER_LEVEL_UP      = function() ns:FeatTouch("level") end,
	PLAYER_DEAD          = function() ns:FeatTouch("death") end,
	QUEST_TURNED_IN      = function() ns:FeatTouch("quest") end,
	PLAYER_MONEY         = function() ns:FeatTouch("money") end,
	PLAYER_REGEN_ENABLED = function() if #ns.featPending > 0 or ns.featLoginAt then Wake() end end,
}

-- événements sur le cadre partagé des hauts faits (FeatsData.lua)
if ns.FeatListen then ns.FeatListen(HANDLERS) end
-- pour les tests : une horloge du moteur, à la main
function ns:FeatTick() Tick() end

if ns.Mark then ns.Mark("Feats") end
