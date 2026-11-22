-- TripRecap.lua -- accueil du jour et bilan de sortie (QuestCompanion 3.7.0, étape 3, S3)
--
-- Deux moments de la session disaient peu de chose :
--   * À LA CONNEXION, la bulle de bonjour qui existe (somnolent au retour
--     d'une absence, Companion.lua) dit où le joueur en était : le haut fait
--     ou le titre le plus proche (ns:FeatNearest), en une phrase (« Encore 2
--     espèces et tu deviens Maître dresseur ! »). Une seule bulle, la même
--     qu'avant : son texte change, pas son nombre. La réplique du repos
--     (CompanionRested.lua) garde la priorité ; rien de proche : la réplique
--     d'avant. Jamais un secret, jamais une ligne en attente.
--   * La BULLE D'OBJECTIF qui existe (une par demi-heure au plus,
--     ns:CompanionTryGoal) cite, quand le compagnon n'a pas d'étape proche à
--     dire, le haut fait suivi ou le plus proche (« Plus que 2 prises pour
--     Cent prises. »). Pas de bulle en plus.
--   * Le BILAN DE SORTIE : une sortie commence quand on quitte un lieu sûr et
--     finit quand on y revient (signal DEPARTURE / RETURN de Ready2Quest s'il
--     est là, sinon la sortie et l'entrée en zone de repos). Après 20 minutes
--     dehors et 5 captures au moins : un bandeau moyen de 6 secondes (celui des
--     hauts faits, ForgeBanners.lua), « RETOUR DE SORTIE », « <n> captures,
--     <k> espèces nouvelles », « <b> brillantes · <p> paillettes », et
--     « Détail » qui ouvre le carnet sur la page « Dernière sortie ». Jamais en
--     combat (la file des bandeaux attend la fin), jamais deux fois pour la
--     même sortie, jamais en mode discret, jamais pour une sortie trop courte.
--     Un rechargement en pleine sortie ne la remet pas à zéro (elle vit dans la
--     sauvegarde du personnage) et ne déclenche aucun bilan.
--   * MOINS DE LIGNES DE CHAT : les lignes des tâches d'étude, des niveaux de
--     lien et des paillettes de palier de zone sont muettes par défaut (elles
--     sont dans le bilan). Un réglage (`tripChat`, page des annonces) les rend.
--     Qui avait déjà allumé les lignes de chat du carnet (`journalChat`, qui
--     portait les paillettes de palier) les garde.
--
-- Les chiffres d'une sortie sont des DIFFÉRENCES entre le départ et le retour
-- de compteurs qui existent déjà (aucun relevé nouveau dans les modules de
-- jeu) : captures (capture.caught), espèces (collection du compte), paillettes
-- (capture.paillettesEarned, et par raison : compteurs glitter:<raison> de
-- Tally.lua), tâches d'étude (source studyTasks des hauts faits), points de
-- lien (compteur bondPoints de Tally.lua). Brillantes et meilleure prise : les
-- spécimens capturés pendant la sortie (date de capture) ; hauts faits : ceux
-- obtenus pendant la sortie (date d'obtention, hors rattrapages).
--
-- Sauvegarde (personnage, ns:CharData()) :
--   trip     = { v, at (début, time()), off (s hors ligne), seen, how, base = { … } }
--   tripLast = le dernier bilan (sortie assez longue), pour la page.
-- Au compte : tripChat (nil tant que pas décidé ; voir TripChatOn).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.TRIP_RECAP = {
	minSeconds = 20 * 60,     -- une sortie compte après 20 minutes dehors…
	minCaptures = 5,          -- … et 5 captures
	seconds = 6,              -- durée du bandeau
	seenEvery = 60,           -- s : l'heure de la dernière présence (temps hors ligne)
	featsKept = 20,           -- hauts faits gardés dans le bilan
	buttonGap = 8,            -- « Détail » : écart après la sous-ligne…
	buttonDrop = 8,           -- … la rangée qui descend sous le nom…
	buttonTrim = 4,           -- … et la marge du bas qu'elle reprend (la maquette)
	icon = "Interface\\Icons\\INV_Misc_Map_01",
	detailIcon = { fallback = "Interface\\Icons\\INV_Misc_Book_09" },
}
-- « proche » : 3 au plus à faire, ou 80 % du chemin, et déjà commencé
ns.TRIP_NEAR = { left = 3, ratio = 0.8, scan = 12 }
-- critères dont on sait dire l'unité (« 2 espèces », « 3 prises ») ; les
-- autres : « Tu en es à 8 sur 10 pour … »
ns.TRIP_UNITS = { species = true, caught = true, shinyCap = true, shinyFound = true, studyMastered = true,
	studyTasks = true, seals = true, missions = true, level = true, glitterEarned = true, captureHunt = true,
	release = true, orderDone = true, bondPoints = true, treat = true, wish = true }
-- raisons de paillettes nommées dans la page (les autres : « autres »)
ns.TRIP_GLITTER_REASONS = { "capture", "study", "milestone", "medal", "seal", "feat", "order", "mission", "release",
	"pantry", "discord" }

local FR = {
	TRIP_TITLE          = "Retour de sortie",
	TRIP_LINE           = "%s, %s",
	TRIP_SUB            = "%s · %s",
	TRIP_CAPTURES       = "%d captures",
	TRIP_CAPTURES_1     = "%d capture",
	TRIP_SPECIES        = "%d espèces nouvelles",
	TRIP_SPECIES_1      = "%d espèce nouvelle",
	TRIP_SPECIES_0      = "aucune espèce nouvelle",
	TRIP_SHINIES        = "%d brillantes",
	TRIP_SHINIES_1      = "%d brillante",
	TRIP_GLITTER        = "%d paillettes",
	TRIP_GLITTER_1      = "%d paillette",
	TRIP_DETAIL         = "Détail",
	TRIP_DETAIL_TIP     = "Dernière sortie",
	TRIP_DETAIL_HINT    = "Le carnet sur le détail de ta sortie.",
	TRIP_PAGE_TITLE     = "Dernière sortie",
	TRIP_PAGE_SUB       = "De ton départ à ton retour en lieu sûr.",
	TRIP_PAGE_WHEN      = "Retour le %s, après %s dehors.",
	TRIP_PAGE_NONE      = "Pas encore de bilan : pars au moins 20 minutes, capture 5 créatures, et le bilan t'attendra à ton retour en lieu sûr.",
	TRIP_STAT_dur       = "dehors",
	TRIP_STAT_captures  = "captures",
	TRIP_STAT_species   = "espèces nouvelles",
	TRIP_STAT_shinies   = "brillantes",
	TRIP_STAT_glitter   = "paillettes",
	TRIP_SECTION        = "En détail",
	TRIP_ROW_best       = "Meilleure prise",
	TRIP_ROW_study      = "Tâches d'étude finies",
	TRIP_ROW_bond       = "Points de lien",
	TRIP_ROW_glitter    = "Paillettes par raison",
	TRIP_ROW_feats      = "Hauts faits obtenus",
	TRIP_BEST           = "%s · %d étoiles",
	TRIP_BEST_1         = "%s · %d étoile",
	TRIP_EMPTY          = "aucun",
	TRIP_REASON         = "%d %s",
	TRIP_REASON_capture = "prises",
	TRIP_REASON_study   = "étude",
	TRIP_REASON_milestone = "paliers de zone",
	TRIP_REASON_medal   = "médailles",
	TRIP_REASON_seal    = "sceaux",
	TRIP_REASON_feat    = "hauts faits",
	TRIP_REASON_order   = "commandes",
	TRIP_REASON_mission = "missions",
	TRIP_REASON_release = "relâchés",
	TRIP_REASON_pantry  = "garde-manger",
	TRIP_REASON_discord = "Discord",
	TRIP_REASON_other   = "autres",
	TRIP_FEATS_MORE     = "%s et %d autres",
	TRIP_DUR_H          = "%d h %02d",
	TRIP_DUR_M          = "%d min",
	TRIP_BACK           = "Revenir au compagnon",
	TRIP_DATE           = "%d/%m à %H:%M",
	-- bonjour et objectif
	TRIP_GREET_TITLE    = "Encore %s et tu deviens %s !",
	TRIP_GREET_FEAT     = "Encore %s et tu obtiens %s !",
	TRIP_GREET_COUNT    = "Tu en es à %d sur %d pour %s !",
	TRIP_GOAL           = "Plus que %s pour %s.",
	TRIP_GOAL_COUNT     = "Tu en es à %d sur %d pour %s.",
	TRIP_UNIT_species       = "%d espèces",           TRIP_UNIT_species_1       = "%d espèce",
	TRIP_UNIT_caught        = "%d prises",            TRIP_UNIT_caught_1        = "%d prise",
	TRIP_UNIT_shinyCap      = "%d brillantes",        TRIP_UNIT_shinyCap_1      = "%d brillante",
	TRIP_UNIT_shinyFound    = "%d brillantes",        TRIP_UNIT_shinyFound_1    = "%d brillante",
	TRIP_UNIT_studyMastered = "%d espèces maîtrisées", TRIP_UNIT_studyMastered_1 = "%d espèce maîtrisée",
	TRIP_UNIT_studyTasks    = "%d tâches d'étude",    TRIP_UNIT_studyTasks_1    = "%d tâche d'étude",
	TRIP_UNIT_seals         = "%d sceaux",            TRIP_UNIT_seals_1         = "%d sceau",
	TRIP_UNIT_missions      = "%d missions",          TRIP_UNIT_missions_1      = "%d mission",
	TRIP_UNIT_level         = "%d niveaux",           TRIP_UNIT_level_1         = "%d niveau",
	TRIP_UNIT_glitterEarned = "%d paillettes",        TRIP_UNIT_glitterEarned_1 = "%d paillette",
	TRIP_UNIT_captureHunt   = "%d prises en chasse",  TRIP_UNIT_captureHunt_1   = "%d prise en chasse",
	TRIP_UNIT_release       = "%d relâchés",          TRIP_UNIT_release_1       = "%d relâché",
	TRIP_UNIT_orderDone     = "%d commandes",         TRIP_UNIT_orderDone_1     = "%d commande",
	TRIP_UNIT_bondPoints    = "%d points de lien",    TRIP_UNIT_bondPoints_1    = "%d point de lien",
	TRIP_UNIT_treat         = "%d friandises",        TRIP_UNIT_treat_1         = "%d friandise",
	TRIP_UNIT_wish          = "%d envies",            TRIP_UNIT_wish_1          = "%d envie",
	-- réglage
	OPT_TRIP_CHAT       = "Lignes de chat : étude, lien, paliers",
	OPT_TRIP_CHAT_DESC  = "Une ligne dans le chat pour chaque tâche d'étude finie, chaque niveau de lien gagné et les paillettes d'un palier de zone. Éteint : tout est dans le bilan de sortie, au retour en lieu sûr.",
}
local EN = {
	TRIP_TITLE          = "Back from the field",
	TRIP_LINE           = "%s, %s",
	TRIP_SUB            = "%s · %s",
	TRIP_CAPTURES       = "%d captures",
	TRIP_CAPTURES_1     = "%d capture",
	TRIP_SPECIES        = "%d new species",
	TRIP_SPECIES_1      = "%d new species",
	TRIP_SPECIES_0      = "no new species",
	TRIP_SHINIES        = "%d shinies",
	TRIP_SHINIES_1      = "%d shiny",
	TRIP_GLITTER        = "%d glitter",
	TRIP_GLITTER_1      = "%d glitter",
	TRIP_DETAIL         = "Details",
	TRIP_DETAIL_TIP     = "Last outing",
	TRIP_DETAIL_HINT    = "The journal, on the details of your outing.",
	TRIP_PAGE_TITLE     = "Last outing",
	TRIP_PAGE_SUB       = "From the moment you left to your return to a safe place.",
	TRIP_PAGE_WHEN      = "Back on %s, after %s out.",
	TRIP_PAGE_NONE      = "No summary yet: head out for at least 20 minutes, capture 5 creatures, and the summary will be waiting when you get back to a safe place.",
	TRIP_STAT_dur       = "out",
	TRIP_STAT_captures  = "captures",
	TRIP_STAT_species   = "new species",
	TRIP_STAT_shinies   = "shinies",
	TRIP_STAT_glitter   = "glitter",
	TRIP_SECTION        = "In detail",
	TRIP_ROW_best       = "Best catch",
	TRIP_ROW_study      = "Study tasks done",
	TRIP_ROW_bond       = "Bond points",
	TRIP_ROW_glitter    = "Glitter by source",
	TRIP_ROW_feats      = "Achievements earned",
	TRIP_BEST           = "%s · %d stars",
	TRIP_BEST_1         = "%s · %d star",
	TRIP_EMPTY          = "none",
	TRIP_REASON         = "%d %s",
	TRIP_REASON_capture = "captures",
	TRIP_REASON_study   = "study",
	TRIP_REASON_milestone = "zone milestones",
	TRIP_REASON_medal   = "medals",
	TRIP_REASON_seal    = "seals",
	TRIP_REASON_feat    = "achievements",
	TRIP_REASON_order   = "orders",
	TRIP_REASON_mission = "missions",
	TRIP_REASON_release = "releases",
	TRIP_REASON_pantry  = "pantry",
	TRIP_REASON_discord = "Discord",
	TRIP_REASON_other   = "other",
	TRIP_FEATS_MORE     = "%s and %d more",
	TRIP_DUR_H          = "%d h %02d",
	TRIP_DUR_M          = "%d min",
	TRIP_BACK           = "Back to the companion",
	TRIP_DATE           = "%m/%d at %H:%M",
	TRIP_GREET_TITLE    = "%s more and you become %s!",
	TRIP_GREET_FEAT     = "%s more and you earn %s!",
	TRIP_GREET_COUNT    = "You're at %d of %d for %s!",
	TRIP_GOAL           = "Only %s left for %s.",
	TRIP_GOAL_COUNT     = "You're at %d of %d for %s.",
	TRIP_UNIT_species       = "%d species",           TRIP_UNIT_species_1       = "%d species",
	TRIP_UNIT_caught        = "%d captures",          TRIP_UNIT_caught_1        = "%d capture",
	TRIP_UNIT_shinyCap      = "%d shinies",           TRIP_UNIT_shinyCap_1      = "%d shiny",
	TRIP_UNIT_shinyFound    = "%d shinies",           TRIP_UNIT_shinyFound_1    = "%d shiny",
	TRIP_UNIT_studyMastered = "%d mastered species",  TRIP_UNIT_studyMastered_1 = "%d mastered species",
	TRIP_UNIT_studyTasks    = "%d study tasks",       TRIP_UNIT_studyTasks_1    = "%d study task",
	TRIP_UNIT_seals         = "%d seals",             TRIP_UNIT_seals_1         = "%d seal",
	TRIP_UNIT_missions      = "%d missions",          TRIP_UNIT_missions_1      = "%d mission",
	TRIP_UNIT_level         = "%d levels",            TRIP_UNIT_level_1         = "%d level",
	TRIP_UNIT_glitterEarned = "%d glitter",           TRIP_UNIT_glitterEarned_1 = "%d glitter",
	TRIP_UNIT_captureHunt   = "%d hunt captures",     TRIP_UNIT_captureHunt_1   = "%d hunt capture",
	TRIP_UNIT_release       = "%d releases",          TRIP_UNIT_release_1       = "%d release",
	TRIP_UNIT_orderDone     = "%d orders",            TRIP_UNIT_orderDone_1     = "%d order",
	TRIP_UNIT_bondPoints    = "%d bond points",       TRIP_UNIT_bondPoints_1    = "%d bond point",
	TRIP_UNIT_treat         = "%d treats",            TRIP_UNIT_treat_1         = "%d treat",
	TRIP_UNIT_wish          = "%d wishes",            TRIP_UNIT_wish_1          = "%d wish",
	OPT_TRIP_CHAT       = "Chat lines: study, bond, milestones",
	OPT_TRIP_CHAT_DESC  = "A chat line for each study task done, each bond level gained and the glitter of a zone milestone. Off: it's all in the outing summary, when you get back to a safe place.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TRIP_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
-- (sans repli « or value » : il rendrait la valeur secrète quand le filtre rend nil)
local function Plain(value)
	if ns.Plain then return ns.Plain(value) end
	return value
end
local function Num(value) return math.max(0, math.floor(tonumber(value) or 0)) end
local function Wall() return tonumber(Call(G("time"))) or 0 end
local function Now() return (ns.Now and ns.Now()) or 0 end
local function InCombat()
	return Plain(Call(G("InCombatLockdown"))) == true or Plain(Call(G("UnitAffectingCombat"), "player")) == true
end
local function Resting() return Plain(Call(G("IsResting"))) == true end

-- « 1 capture » / « 3 captures » (clé _0 facultative pour zéro)
local function Count(self, key, n)
	n = Num(n)
	if n == 0 and L[key .. "_0"] ~= key .. "_0" then return L[key .. "_0"] end
	if n == 1 then return self:F(key .. "_1", n) end
	return self:F(key, n)
end
ns.TripCount = Count

-- ---------------------------------------------------------------------------
-- Bonjour et bulle d'objectif : le haut fait le plus proche
-- ---------------------------------------------------------------------------
local TALLY_KINDS = { count = true, tally = true, tallymax = true }

-- proche : commencé, pas atteint, 3 au plus à faire ou 80 % du chemin
local function Near(item)
	local cur, max = Num(item and item.cur), Num(item and item.max)
	if max < 2 or cur < 1 or cur >= max then return false end
	return max - cur <= ns.TRIP_NEAR.left or cur / max >= ns.TRIP_NEAR.ratio
end
ns.TripNear = Near

-- « 2 espèces » (nil : unité inconnue pour ce critère)
local function LeftText(self, def, left)
	local crit = def and def.crit or {}
	local key = TALLY_KINDS[crit[1] or ""] and ns.TRIP_UNITS[crit[2] or ""] and crit[2]
	if not key then return nil end
	return Count(self, "TRIP_UNIT_" .. key, left)
end

local function TitleOf(self, def)
	local code = type(def.reward) == "table" and tonumber(def.reward.title)
	if not (code and self.FeatTitleText) then return nil end
	local ok, text = pcall(self.FeatTitleText, self, code)
	return ok and type(text) == "string" and text ~= "" and text or nil
end

-- Jamais un secret ni une ligne en attente (FeatNearest les écarte déjà ;
-- un haut fait suivi est revérifié ici)
local function Citable(self, def)
	if type(def) ~= "table" or def.pending or self:FeatGot(def) then return false end
	if def.hidden then return false end
	return self.FeatCountable == nil or self:FeatCountable(def)
end

-- La phrase d'un haut fait : clé et arguments pour la bulle
-- mode : "greet" (bonjour) ou "goal" (bulle d'objectif)
function ns:TripFeatLine(item, mode)
	if type(item) ~= "table" or not Citable(self, item.def) then return nil end
	local def, cur, max = item.def, Num(item.cur), Num(item.max)
	local left = max - cur
	if left <= 0 then return nil end
	local name = self:FeatName(def)
	local unit = LeftText(self, def, left)
	if mode == "goal" then
		if unit then return "TRIP_GOAL", { unit, name } end
		return "TRIP_GOAL_COUNT", { cur, max, name }
	end
	local title = TitleOf(self, def)
	if unit and title then return "TRIP_GREET_TITLE", { unit, title } end
	if unit then return "TRIP_GREET_FEAT", { unit, name } end
	return "TRIP_GREET_COUNT", { cur, max, title or name }
end

local function Nearest(self, count)
	if ns.featsDormant or not self.FeatNearest then return {} end
	local ok, list = pcall(self.FeatNearest, self, count)
	return ok and type(list) == "table" and list or {}
end

-- Bonjour : le plus proche (nil : rien de proche, la réplique d'avant)
function ns:TripGreeting()
	if InCombat() then return nil end   -- (rien du jeu relu en combat)
	-- le premier proche (ordre de FeatNearest) ; à égalité de chemin, celui
	-- qui donne un titre (« … et tu deviens Maître dresseur ! »)
	local pick
	for _, item in ipairs(Nearest(self, ns.TRIP_NEAR.scan)) do
		if Near(item) and Citable(self, item.def) then
			if not pick then
				pick = item
			elseif item.cur / item.max == pick.cur / pick.max and TitleOf(self, item.def) and not TitleOf(self, pick.def) then
				pick = item
			end
		end
	end
	if not pick then return nil end
	return self:TripFeatLine(pick, "greet")
end

-- Bulle d'objectif : un haut fait suivi (le plus avancé), sinon le plus proche
function ns:TripGoalLine()
	if ns.featsDormant or not self.FeatDef then return nil end
	local best
	if self.FeatFollowed then
		for _, id in ipairs(self:FeatFollowed()) do
			local def = self:FeatDef(id)
			if Citable(self, def) then
				local cur, max, state = self:FeatProgress(def)
				cur, max = Num(cur), Num(max)
				if state == "open" and max > 0 and cur < max and (not best or cur / max > best.cur / best.max) then
					best = { def = def, cur = cur, max = max }
				end
			end
		end
	end
	if not best then
		for _, item in ipairs(Nearest(self, ns.TRIP_NEAR.scan)) do
			if Near(item) then best = item; break end
		end
	end
	if not best then return nil end
	return self:TripFeatLine(best, "goal")
end

-- ---------------------------------------------------------------------------
-- Lignes de chat (étude, lien, paliers) : muettes par défaut
-- ---------------------------------------------------------------------------
-- Le choix se pose une fois : qui avait allumé les lignes de chat du carnet
-- (journalChat, qui portait les paillettes de palier) les garde, les autres
-- passent au silence. Pas de défaut déclaré : il remplirait la clé avant
-- qu'on sache si le joueur avait choisi.
function ns:TripChatMigrate()
	local db = self:DB()
	if db.tripChat == nil then db.tripChat = db.journalChat == true end
	return db.tripChat
end
function ns:TripChatOn() return self:TripChatMigrate() == true end

do
	local loaded = ns.OnAddonLoaded
	function ns:OnAddonLoaded(...)
		local a = loaded and loaded(self, ...)
		pcall(self.TripChatMigrate, self)
		return a
	end
end

-- Paillettes de palier (JournalReserve.lua : la ligne part si journalChat) :
-- elles suivent ce réglage-ci le temps de l'appel, journalChat reste celui des tampons
do
	local milestones = ns.PaillettesOnMilestones
	if milestones then
		function ns:PaillettesOnMilestones(...)
			local db = self:DB()
			local kept = db.journalChat
			db.journalChat = self:TripChatOn()
			local ok, a = pcall(milestones, self, ...)
			db.journalChat = kept
			if not ok then
				if self.RecordError then self:RecordError("trip:milestones", a) end
				return 0
			end
			return a
		end
	end
end

-- ---------------------------------------------------------------------------
-- Sortie : départ, retour, chiffres
-- ---------------------------------------------------------------------------
local function Char(self) return self:CharData() end

-- Ready2Quest est là et dit ses départs et retours
local function UsesR2Q(self)
	local r2q = self.r2qBridge
	if type(r2q) ~= "table" then return false end
	if type(r2q.DB) == "function" then
		local ok, db = pcall(r2q.DB, r2q)
		if ok and type(db) == "table" and db.enabled == false then return false end
	end
	return true
end
ns.TripUsesR2Q = UsesR2Q
-- … et enverra RETURN (après un rechargement, il ne sait plus qu'on était
-- parti : l'entrée en zone de repos prend alors le relais)
local function R2QWillReturn(self) return UsesR2Q(self) and self.r2qBridge.departed == true end

local function Species(self)
	local source = ns.FEAT_SOURCES and ns.FEAT_SOURCES.species
	if source and source.get then
		if self.FeatCacheReset then self:FeatCacheReset() end
		local ok, n = pcall(source.get, self, "account")
		if self.FeatCacheReset then self:FeatCacheReset() end
		if ok and tonumber(n) then return Num(n) end
	end
	return Num(self.MenagerieSpeciesCount and Call(self.MenagerieSpeciesCount, self))
end

local function StudyTasks(self)
	local source = ns.FEAT_SOURCES and ns.FEAT_SOURCES.studyTasks
	if not (source and source.get) then return nil end
	local ok, n = pcall(source.get, self)
	return ok and tonumber(n) and Num(n) or nil
end

-- Paillettes gagnées par raison : les compteurs glitter:<raison> de Tally.lua
-- (lus dans leur sauvegarde, sans rien écrire)
local function GlitterByReason(self)
	local out = {}
	local tally = self:DB().tally
	for key, value in pairs(type(tally) == "table" and type(tally.n) == "table" and tally.n or {}) do
		local reason = type(key) == "string" and key:match("^glitter:(.+)$")
		if reason then out[reason] = Num(value) end
	end
	return out
end

local function Counters(self)
	local capture = self.CaptureData and self:CaptureData() or {}
	return {
		caught = Num(capture.caught),
		glitter = Num(capture.paillettesEarned),
		species = Species(self),
		study = StudyTasks(self),
		bond = Num(self.TallyGet and self:TallyGet("bondPoints")),
		by = GlitterByReason(self),
	}
end
ns.TripCounters = Counters

function ns:TripActive() return type(Char(self).trip) == "table" and Char(self).trip or nil end

function ns:TripStart(how)
	local char = Char(self)
	if type(char.trip) == "table" then return false end
	local now = Wall()
	char.trip = { v = 1, at = now, off = 0, seen = now, how = how, base = Counters(self) }
	return true
end

-- Spécimens capturés pendant la sortie : brillantes, meilleure prise
local function TripSpecimens(self, since)
	local capture = self.CaptureData and self:CaptureData() or {}
	local shinies, best, bestScore = 0, nil, -1
	for _, spec in pairs(type(capture.specimens) == "table" and capture.specimens or {}) do
		if type(spec) == "table" and (spec.origin == nil or spec.origin == "capture") and (tonumber(spec.at) or 0) >= since then
			if spec.shiny then shinies = shinies + 1 end
			local size = ns.SPECIMEN_SIZE_BY_ID and ns.SPECIMEN_SIZE_BY_ID[spec.size or ""]
			local score = (spec.shiny and 100 or 0) + Num(spec.stars) * 10 + ((type(size) == "table" and size.rare) and 1 or 0)
			if score > bestScore or (score == bestScore and best and (tonumber(spec.at) or 0) < (tonumber(best.at) or 0)) then
				best, bestScore = spec, score
			end
		end
	end
	local label
	if best then
		label = { name = self.SpecimenLabel and self:SpecimenLabel(best) or tostring(best.name or best.npc), stars = Num(best.stars),
			shiny = best.shiny and true or nil, size = best.size }
	end
	return shinies, label
end

-- Hauts faits obtenus pendant la sortie (hors rattrapages et lignes en attente)
local function TripFeats(self, since)
	local ids = {}
	if not (self.FeatDefs and self.FeatGot) then return ids end
	for _, def in ipairs(self:FeatDefs()) do
		local got = not def.pending and self:FeatGot(def)
		if type(got) == "table" and not got.r and (tonumber(got.at) or 0) >= since then ids[#ids + 1] = def.id end
	end
	while #ids > ns.TRIP_RECAP.featsKept do table.remove(ids) end
	return ids
end

-- Le bilan d'une sortie (sans rien afficher)
function ns:TripSummary(trip, now)
	now = now or Wall()
	local base, cur = type(trip.base) == "table" and trip.base or {}, Counters(self)
	local since = tonumber(trip.at) or now
	local recap = {
		at = since, ended = now, dur = math.max(0, now - since - Num(trip.off)),
		captures = math.max(0, cur.caught - Num(base.caught)),
		species = math.max(0, cur.species - Num(base.species)),
		glitter = math.max(0, cur.glitter - Num(base.glitter)),
		bond = math.max(0, cur.bond - Num(base.bond)),
		by = {},
	}
	if cur.study and base.study then recap.study = math.max(0, cur.study - Num(base.study)) end
	local before = type(base.by) == "table" and base.by or {}
	for reason, n in pairs(cur.by) do
		local gain = n - Num(before[reason])
		if gain > 0 then recap.by[reason] = gain end
	end
	recap.shinies, recap.best = TripSpecimens(self, since)
	recap.feats = TripFeats(self, since)
	return recap
end

function ns:TripQualifies(recap)
	local R = ns.TRIP_RECAP
	return type(recap) == "table" and Num(recap.dur) >= R.minSeconds and Num(recap.captures) >= R.minCaptures
end

-- Fin de sortie. silent : rien ne s'affiche (connexion, rechargement). Rend
-- le bilan et ce qui en est fait : "short", "silent", "quiet", "shown" ; nil
-- sans sortie en cours (un deuxième retour de suite).
function ns:TripFinish(how, silent)
	local char = Char(self)
	local trip = char.trip
	if type(trip) ~= "table" then return nil end
	char.trip = nil
	local ok, recap = pcall(self.TripSummary, self, trip)
	if not ok then
		if self.RecordError then self:RecordError("trip:summary", recap) end
		return nil
	end
	recap.how = how
	if not self:TripQualifies(recap) then return recap, "short" end
	char.tripLast = recap
	if silent then return recap, "silent" end
	if self.Quiet and self:Quiet() then return recap, "quiet" end
	self:TripBanner(recap)
	return recap, "shown"
end

-- ---------------------------------------------------------------------------
-- Le bandeau : le bandeau moyen du carnet, d'autres textes
-- ---------------------------------------------------------------------------
function ns:TripBannerEntry(recap)
	return {
		kind = "trip", size = "medium", title = L.TRIP_TITLE,
		name = self:F("TRIP_LINE", Count(self, "TRIP_CAPTURES", recap.captures), Count(self, "TRIP_SPECIES", recap.species)),
		sub = self:F("TRIP_SUB", Count(self, "TRIP_SHINIES", recap.shinies), Count(self, "TRIP_GLITTER", recap.glitter)),
		icon = ns.TRIP_RECAP.icon, points = Num(recap.captures),
		onClick = function(owner) owner:TripDetailOpen() end,
	}
end

-- Dans la file des bandeaux du haut (Journal.lua) : elle attend la fin d'un
-- combat ; pas par JournalToastPush, dont le réglage est celui des tampons
function ns:TripBanner(recap)
	if type(self.journalToasts) ~= "table" or not self.JournalFlush then return false end
	table.insert(self.journalToasts, self:TripBannerEntry(recap))
	self:JournalFlush()
	return true
end

-- Le bouton « Détail » (la petite plaque du bouton Partager, Share.lua)
local function Look(button, hot)
	if button.forge and button.forgeLook then
		button.forgeLook(button, hot and "hover" or "rest")
	elseif button.hover then
		if hot then button.hover:Show() else button.hover:Hide() end
	end
	if button.icon then button.icon:SetAlpha(hot and 1 or 0.9) end
end

function ns:TripDetailButton(frame)
	if frame.tripButton then return frame.tripButton end
	if not self.ShareButton then return nil end
	local button = self:ShareButton(frame, "trip")
	local base = (frame.button and frame.button.GetFrameLevel and frame.button:GetFrameLevel())
		or (frame.GetFrameLevel and frame:GetFrameLevel()) or 1
	button:SetFrameLevel(base + 4)
	Theme.PaintClient(button.icon, ns.TRIP_RECAP.detailIcon)
	button:SetScript("OnClick", function() ns:TripDetailOpen() end)
	button:SetScript("OnEnter", function(b)
		Look(b, true)
		local tip = G("GameTooltip")
		if type(tip) ~= "table" or not tip.SetOwner then return end
		tip:SetOwner(b, "ANCHOR_TOP")
		Theme.TooltipTitle(tip, L.TRIP_DETAIL_TIP)
		Theme.TooltipHint(tip, L.TRIP_DETAIL_HINT, true)
		tip:Show()
	end)
	button:SetScript("OnLeave", function(b)
		Look(b, false)
		local tip = G("GameTooltip")
		if type(tip) == "table" and tip.Hide then tip:Hide() end
	end)
	Look(button, false)
	frame.tripButton = button
	return button
end

local function Restack(self, frame)
	local stack = frame.forgeStack
	if stack and self.ForgeBannerStack then self:ForgeBannerStack(frame, stack.keys, stack.minH) end
end

-- Après chaque bandeau du carnet : « Détail » sur un bilan, rien ailleurs
function ns:TripToastSync(frame)
	frame = frame or self.journalToast
	if type(frame) ~= "table" then return nil end
	local entry = frame.shownEntry
	local button = frame.tripButton
	if not (type(entry) == "table" and entry.kind == "trip") then
		if button and button:IsShown() then
			button:Hide()
			-- la sous-ligne reprend sa largeur, le bandeau sa hauteur
			if frame.stars and frame.tripStarsW then frame.stars:SetWidth(frame.tripStarsW) end
			frame.tripStarsW = nil
			if frame.forgeBanner and not (frame.shareButton and frame.shareButton:IsShown()) then
				frame.forgeBottomReserve = 0
				Restack(self, frame)
			end
		end
		return nil
	end
	button = button or self:TripDetailButton(frame)
	if not button then return nil end
	local B = ns.SHARE_BUTTON
	button.label:SetText(L.TRIP_DETAIL)
	local ink = button.forge and ns.SHARE_FORGE_INK or Theme.LABEL
	button.label:SetTextColor(ink[1], ink[2], ink[3], 1)
	button:ClearAllPoints()
	if frame.forgeBanner and frame.stars then
		local measure = button.label.GetUnboundedStringWidth or button.label.GetStringWidth
		local w = math.ceil(tonumber(measure and measure(button.label)) or 40)
		button:SetWidth(B.size + B.labelGap + w + B.labelPad)
		button.label:Show()
		-- comme la maquette : « Détail » au bout de la sous-ligne (« 1 brillante
		-- · 31 paillettes »), sur la même rangée ; la sous-ligne lui laisse sa place
		frame.tripStarsW = frame.tripStarsW or tonumber(frame.stars:GetWidth()) or 200
		local gap = ns.TRIP_RECAP.buttonGap
		frame.stars:SetWidth(math.max(40, frame.tripStarsW - button:GetWidth() - gap))
		frame.forgeBottomReserve = 0
		Restack(self, frame)
		-- la rangée descend un peu sous le nom (le bouton est plus haut que la
		-- ligne), le bandeau grandit d'autant
		local K, drop = ns.FORGE_BANNER or {}, ns.TRIP_RECAP.buttonDrop
		frame.stars:ClearAllPoints()
		frame.stars:SetPoint("TOPLEFT", frame.text, "BOTTOMLEFT", 0, -((K.lineGap or 2) + drop))
		frame:SetHeight((tonumber(frame:GetHeight()) or 70) + drop - ns.TRIP_RECAP.buttonTrim)
		button:SetPoint("LEFT", frame.stars, "RIGHT", gap, 0)
	else
		button.label:Hide()
		button:SetWidth(B.size)
		button:SetPoint("RIGHT", frame, "RIGHT", -B.sobreGap, 0)
	end
	button:Show()
	self.journalToastHideAt = Now() + ns.TRIP_RECAP.seconds
	return button
end

do
	local show = ns.ShowNextJournalToast
	if show then
		function ns:ShowNextJournalToast(...)
			local frame = show(self, ...)
			local ok, err = pcall(self.TripToastSync, self, frame or self.journalToast)
			if not ok and self.RecordError then self:RecordError("trip:toast", err) end
			return frame
		end
	end
end

-- ---------------------------------------------------------------------------
-- La page « Dernière sortie » du carnet (page externe sans entrée de
-- navigation : on y vient par « Détail »)
-- ---------------------------------------------------------------------------
ns.TRIP_PAGE = { statH = 58, statGap = 8, rowH = 30, rowGap = 6, labelW = 200, sectionGap = 18 }
local STATS = { "dur", "captures", "species", "shinies", "glitter" }
local ROWS = { "best", "study", "bond", "glitter", "feats" }

local function DurText(self, seconds)
	local minutes = math.floor(Num(seconds) / 60)
	if minutes >= 60 then return self:F("TRIP_DUR_H", math.floor(minutes / 60), minutes % 60) end
	return self:F("TRIP_DUR_M", minutes)
end
ns.TripDurText = DurText

local function DateText(at)
	local date = G("date") or (os and os.date)
	local ok, text = pcall(date, L.TRIP_DATE, Num(at))
	return ok and type(text) == "string" and text or ""
end

local function ReasonsText(self, by)
	local parts, seen = {}, {}
	for _, reason in ipairs(ns.TRIP_GLITTER_REASONS) do
		local n = 0
		for key, value in pairs(by or {}) do
			local head = key:match("^([^:]+)") or key
			if head == reason then n = n + Num(value); seen[key] = true end
		end
		if n > 0 then parts[#parts + 1] = { n = n, text = self:F("TRIP_REASON", n, L["TRIP_REASON_" .. reason]) } end
	end
	local other = 0
	for key, value in pairs(by or {}) do if not seen[key] then other = other + Num(value) end end
	if other > 0 then parts[#parts + 1] = { n = other, text = self:F("TRIP_REASON", other, L.TRIP_REASON_other) } end
	table.sort(parts, function(a, b) return a.n > b.n end)
	local out = {}
	for i, part in ipairs(parts) do out[i] = part.text end
	return #out > 0 and table.concat(out, L.FEAT_REWARD_SEP or " · ") or L.TRIP_EMPTY
end

-- Les lignes de la page : { clé = texte }
function ns:TripRows(recap)
	local rows = {}
	local best = recap.best
	if type(best) == "table" then
		rows.best =best.stars == 1 and self:F("TRIP_BEST_1", best.name, best.stars) or self:F("TRIP_BEST", best.name, best.stars)
		if best.size and self.SpecimenSizeLabel and ns.SPECIMEN_SIZE_BY_ID and ns.SPECIMEN_SIZE_BY_ID[best.size]
			and ns.SPECIMEN_SIZE_BY_ID[best.size].rare then
			rows.best = rows.best .. (L.FEAT_REWARD_SEP or " · ") .. self:SpecimenSizeLabel(best.size)
		end
	else
		rows.best = L.TRIP_EMPTY
	end
	rows.study = recap.study and tostring(Num(recap.study)) or "—"
	rows.bond = tostring(Num(recap.bond))
	rows.glitter = ReasonsText(self, recap.by)
	local names = {}
	for _, id in ipairs(recap.feats or {}) do
		if self.FeatDef and self:FeatDef(id) then names[#names + 1] = self:FeatName(id) end
	end
	if #names == 0 then rows.feats = L.TRIP_EMPTY
	elseif #names <= 2 then rows.feats = #names .. " : " .. table.concat(names, ", ")
	else rows.feats = #names .. " : " .. self:F("TRIP_FEATS_MORE", table.concat(names, ", ", 1, 2), #names - 2) end
	return rows
end

function ns:TripStats(recap)
	return { dur = DurText(self, recap.dur), captures = tostring(Num(recap.captures)), species = tostring(Num(recap.species)),
		shinies = tostring(Num(recap.shinies)), glitter = tostring(Num(recap.glitter)) }
end

local function BuildPage(self, frame, content, ui)
	local At, Text = ui.At, ui.Text
	local TOP, INNER = ui.TOP, ui.INNER
	local P = ns.TRIP_PAGE
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.tripPane = pane
	pane.base = pane:CreateTexture(nil, "BACKGROUND", nil, -8)
	pane.base:SetColorTexture(Theme.WINDOW[1], Theme.WINDOW[2], Theme.WINDOW[3], 1)
	-- (sous l'en-tête de page, qui garde son titre)
	pane.base:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, TOP + 6)
	pane.base:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
	-- cinq chiffres
	local statW = math.floor((INNER - (#STATS - 1) * P.statGap) / #STATS)
	pane.stats = {}
	for index, key in ipairs(STATS) do
		local tile = Theme.CreateTile(pane, statW, P.statH, { kind = "Frame" })
		At(tile, content, (index - 1) * (statW + P.statGap), TOP)
		tile.value = Text(tile, Theme.F_TITLE, Theme.PARCHMENT, statW - 8)
		tile.value:SetJustifyH("CENTER")
		if tile.value.SetWordWrap then tile.value:SetWordWrap(false) end
		tile.label = Text(tile, Theme.F_SMALL, Theme.MUTED_LIGHT, statW - 8)
		tile.label:SetJustifyH("CENTER")
		tile.label:SetText(L["TRIP_STAT_" .. key])
		if tile.label.SetWordWrap then tile.label:SetWordWrap(false) end
		if ns.JournalStatCenter then ns.JournalStatCenter(tile)
		else tile.value:SetPoint("CENTER", tile, "CENTER", 0, 8); tile.label:SetPoint("CENTER", tile, "CENTER", 0, -11) end
		pane.stats[key] = tile
	end
	-- en détail
	local y = TOP - P.statH - P.sectionGap
	pane.section = Theme.CreateSection(pane, "")
	pane.section:SetWidth(INNER)
	pane.section:SetText(L.TRIP_SECTION)
	At(pane.section, content, 0, y)
	y = y - 26
	pane.rows = {}
	for _, key in ipairs(ROWS) do
		local row = Theme.CreateTile(pane, INNER, P.rowH, { kind = "Frame" })
		At(row, content, 0, y)
		row.label = Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT, P.labelW)
		row.label:SetPoint("LEFT", row, "LEFT", 12, 0)
		row.label:SetText(L["TRIP_ROW_" .. key])
		row.value = Text(row, Theme.F_BODY, Theme.PARCHMENT, INNER - P.labelW - 36)
		row.value:SetPoint("LEFT", row, "LEFT", 12 + P.labelW + 12, 0)
		if row.value.SetWordWrap then row.value:SetWordWrap(false) end
		pane.rows[key] = row
		y = y - P.rowH - P.rowGap
	end
	pane.none = Text(pane, Theme.F_BODY, Theme.MUTED_LIGHT, INNER)
	At(pane.none, content, 0, TOP)
	if pane.none.SetWordWrap then pane.none:SetWordWrap(true) end
	pane.back = Theme.CreateButton(pane, "auto", "sm", L.TRIP_BACK, function() ns:SelectJournalKind("evolution") end)
	At(pane.back, content, 0, y - 6)
	pane:Hide()
end

local function RefreshPage(self, frame)
	local pane = frame.tripPane
	if not pane then return end
	local recap = Char(self).tripLast
	local has = type(recap) == "table"
	for _, tile in pairs(pane.stats) do if has then tile:Show() else tile:Hide() end end
	for _, row in pairs(pane.rows) do if has then row:Show() else row:Hide() end end
	if has then pane.section:Show() else pane.section:Hide() end
	pane.none:SetText(has and "" or L.TRIP_PAGE_NONE)
	if not has then return end
	frame.header:SetSubtitle(self:F("TRIP_PAGE_WHEN", DateText(recap.ended), DurText(self, recap.dur)))
	local stats = self:TripStats(recap)
	for key, tile in pairs(pane.stats) do tile.value:SetText(stats[key]) end
	local rows = self:TripRows(recap)
	for key, row in pairs(pane.rows) do row.value:SetText(rows[key] or "") end
end

ns.JOURNAL_PANES = ns.JOURNAL_PANES or {}
ns.JOURNAL_PANES.trip = {
	field = "tripPane", title = "TRIP_PAGE_TITLE", subtitle = "TRIP_PAGE_SUB",
	build = BuildPage, refresh = RefreshPage,
}

-- « Détail » : le carnet sur la page « Dernière sortie » ; la prochaine
-- ouverture du carnet revient à la page d'avant (pas d'entrée de navigation ici)
function ns:TripDetailOpen()
	if InCombat() then return false end
	if not (self.ToggleJournal and self.SelectJournalKind) then return false end
	local db = self:DB()
	local before = db.journalTab
	self:ToggleJournal(true)
	self:SelectJournalKind("trip")
	db.journalTab = (before ~= "trip" and before) or "evolution"
	local toast = self.journalToast
	if toast and toast.shownEntry and toast.shownEntry.kind == "trip" then
		self.journalToastHideAt = nil
		toast:Hide()
		if self.BannerDone then self:BannerDone("journal") end
	end
	return self.journalFrame ~= nil and self.journalFrame.kind == "trip"
end

-- ---------------------------------------------------------------------------
-- Événements : départ et retour (Ready2Quest, zone de repos), connexion
-- ---------------------------------------------------------------------------
-- Zone de repos : entrée = fin (sans Ready2Quest, ou s'il n'enverra pas
-- RETURN) ; sortie = départ (sans Ready2Quest)
function ns:TripOnResting(resting)
	if resting == nil then resting = Resting() end
	local was = self.tripResting
	self.tripResting = resting
	if was == nil or was == resting then return nil end
	if resting then
		if self:TripActive() and not R2QWillReturn(self) then return self:TripFinish("rest") end
	elseif not UsesR2Q(self) then
		self:TripStart("rest")
	end
	return nil
end

-- Écran de chargement : connexion et rechargement ne finissent rien en
-- montrant un bilan ; le temps hors ligne ne compte pas comme du temps dehors
function ns:TripOnEnterWorld(isLogin, isReload)
	local first = not self.tripSession
	self.tripSession = true
	local resting = Resting()
	self.tripResting = resting
	local trip = self:TripActive()
	if not trip then return nil end
	local now = Wall()
	if isLogin or isReload or (first and isLogin == nil and isReload == nil) then
		trip.off = Num(trip.off) + math.max(0, now - (tonumber(trip.seen) or now))
		trip.seen = now
		-- revenu dans une zone de repos pendant la déconnexion : fin sans bandeau
		if resting and not R2QWillReturn(self) then return self:TripFinish("login", true) end
		return nil
	end
	-- un voyage (pierre de foyer) qui arrive dans une zone de repos
	if resting and not R2QWillReturn(self) then return self:TripFinish("rest") end
	return nil
end

if ns.RegisterCallback then
	ns:RegisterCallback("DEPARTURE", function(self)
		if UsesR2Q(self) then self:TripStart("r2q") end
	end)
	ns:RegisterCallback("RETURN", function(self) self:TripFinish("r2q") end)
end
if ns.On then
	ns.On("PLAYER_UPDATE_RESTING", "trip", function()
		local ok, err = pcall(ns.TripOnResting, ns)
		if not ok and ns.RecordError then ns:RecordError("trip:resting", err) end
	end)
	ns.On("PLAYER_ENTERING_WORLD", "trip", function(isLogin, isReload)
		pcall(ns.TripChatMigrate, ns)
		local ok, err = pcall(ns.TripOnEnterWorld, ns, Plain(isLogin), Plain(isReload))
		if not ok and ns.RecordError then ns:RecordError("trip:world", err) end
	end)
	ns.On("PLAYER_LOGOUT", "trip", function()
		local trip = ns:TripActive()
		if trip then trip.seen = Wall() end
	end)
end
-- l'heure de la dernière présence (une plantée du client ne passe pas par la déconnexion)
if ns.Every then
	ns.Every("trip:seen", ns.TRIP_RECAP.seenEvery, function()
		if not ns.savedVariablesLoaded then return end
		local trip = ns:TripActive()
		if trip then trip.seen = Wall() end
	end)
end

if ns.Mark then ns.Mark("TripRecap") end
