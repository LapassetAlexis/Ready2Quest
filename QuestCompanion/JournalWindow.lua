-- JournalWindow.lua -- fenêtre du Carnet de voyage (v1.25.0, refonte)
--
-- Retour joueur : « le carnet n'est pas clair ». Deux endroits, pas plus :
--   * Complétion : une zone (liste déroulante, la zone où tu es par défaut),
--     son pourcentage, son coffre, et un onglet par activité : Exploration,
--     Combat, Métiers, Quêtes. Chaque onglet montre ce qui est fait et ce qui
--     reste, à partir des parts de complétion (ns.ZONE_PARTS).
--   * Évolution : où en est le compagnon, comment il évolue, son prochain
--     objectif, ses envies, ses coffres, sa collection et ton parcours
--     (zones, capitales, donjons, rares, paliers).
-- Les anciens onglets par sorte de tampon disparaissent : leurs données sont
-- rangées dans la zone (villages, rares) ou dans le parcours (le reste).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local WIDTH, HEIGHT = 980, 680
local ZONE_LIST_MAX = 12
local ACTIVITIES = { "explore", "combat", "craft", "quests" }
ns.JOURNAL_ACTIVITIES = ACTIVITIES
-- part de complétion -> onglet, quand la part ne le dit pas elle-même
local PART_TAB = { villages = "explore", bestiary = "combat", named = "combat", gathering = "craft", quests = "quests" }

local FR = {
	JRN_SEC_evolution      = "Compagnon",
	JRN_SETTINGS_TIP       = "Réglages de QuestCompanion",
	JRN_ZONE_HERE          = "%s (ici)",
	JRN_ZONE_NONE          = "Aucune zone pour l'instant : explore, ton carnet se remplit tout seul.",
	JRN_ACT_explore        = "Lieux",
	JRN_ACT_combat         = "Combat",
	JRN_ACT_craft          = "Métiers",
	JRN_ACT_quests         = "Quêtes",
	JRN_QUESTS_TIP         = "Les quêtes de la zone que ton personnage peut faire (race, classe), livrées avec l'addon. Elles comptent dans les 100 %.",
	JRN_WATCH              = "Suivre à l'écran",
	JRN_WATCH_TIP          = "Cochée : les objectifs de cette zone s'affichent dans le bloc « Carnet » en jeu. La zone où tu es est suivie d'office ; décoche-la pour la masquer.",
	JRN_ACT_EMPTY_explore  = "Aucun village connu dans cette zone.",
	JRN_ACT_EMPTY_combat   = "Aucune créature croisée ici : cible-les ou survole-les pour les noter.",
	JRN_ACT_EMPTY_craft    = "Rien à récolter ici pour tes métiers.",
	JRN_ACT_EMPTY_quests   = "Aucune quête connue pour toi dans cette zone.",
	JRN_ACT_NO_QUESTS      = "Pas de liste de quêtes pour ce client.",
	JRN_ZONE_PERCENT       = "%d %%",
	JRN_ZONE_NOPCT         = "Pourcentage dès que deux activités sont suivies ici.",
	JRN_OPEN_CHEST         = "Ouvrir le coffre",
	JRN_PART_HEAD          = "%s : %d/%d",
	JRN_ITEM_KILLED        = "abattu (%d)",
	JRN_ITEM_TO_KILL       = "à abattre",
	JRN_ITEM_TO_FIND       = "à trouver",
	JRN_ITEM_LEVEL         = "%s (niv. %s)",
	JRN_ITEM_GATHERED      = "récolté",
	JRN_ITEM_TO_GATHER     = "à récolter (%d)",
	JRN_ITEM_TO_GATHER_GRAY = "à récolter (gris)",
	JRN_ITEM_GATHER_LOCKED = "compétence %d requise",
	JRN_ITEM_NAMED         = "%s, %s",
	JRN_EVO_STAGE          = "%s — %s (étape %d/%d)",
	JRN_EVO_NEXT_LEVEL     = "Prochaine étape : %s au niveau %d (tu es niveau %d).",
	JRN_EVO_NEXT_READY     = "Prêt à devenir %s : rends-le heureux, il évoluera aussitôt.",
	JRN_EVO_MAX            = "Dernière étape atteinte. Bravo !",
	JRN_EVO_NEEDS          = "Ses envies (heureux = toutes à %d %%)",
	-- infobulle d'une envie : quoi faire pour la remplir
	JRN_NEED_TIP_TITLE     = "%s : %d %%",
	JRN_NEED_TIP_HAPPY     = "Comblée : à partir de %d %%, elle compte pour son bonheur.",
	JRN_NEED_TIP_LOW       = "Encore %d %% pour qu'elle compte (heureux à %d %%).",
	JRN_NEED_TIP_HOW       = "Pour la remplir :",
	JRN_NEED_TIP_DECAY     = "Elle baisse doucement pendant que tu joues, jamais hors connexion.",
	JRN_NEED_hunger_1      = "mange ou bois : un repas la remplit vite",
	JRN_NEED_hunger_2      = "garde des vivres dans ton sac quand tu pars",
	JRN_NEED_energy_1      = "repose-toi dans une auberge ou une capitale",
	JRN_NEED_energy_2      = "installe-toi près d'un feu de camp",
	JRN_NEED_energy_3      = "rentre en ville après une sortie (avec Ready2Quest)",
	JRN_NEED_mood_1        = "caresse-le : un clic sur lui",
	JRN_NEED_mood_2        = "rends des quêtes, prends des niveaux",
	JRN_NEED_mood_3        = "un butin rare lui plaît, chaque ennemi vaincu un peu",
	JRN_NEED_curiosity_1   = "découvre de nouvelles zones et sous-zones",
	JRN_NEED_curiosity_2   = "gagne des tampons : villages, capitales, donjons, rares",
	JRN_NEED_curiosity_3   = "même tout exploré : reviens dans une zone pas vue depuis 2 h, entre en donjon, vaincs un élite ou un rare, prends un griffon, ouvre un coffre, récolte",
	JRN_NEED_TIP_SERENE    = "Toutes ses évolutions faites : il ne descend plus sous %d %%.",
	JRN_EVO_HOW            = "Comment ça marche",
	JRN_EVO_HOW_1          = "Ton niveau ouvre chaque étape : 10, 20, 40 et 60.",
	JRN_EVO_HOW_2          = "Pour la franchir, il doit être heureux : ses quatre envies à %d %% ou plus. Mange, repose-toi, rends des quêtes, explore.",
	JRN_EVO_HOW_3          = "Finis une zone à 100 %% (page Exploration) : un coffre s'ouvre, tu y choisis une apparence, un ornement, un cadre ou un fond.",
}
local EN = {
	JRN_SEC_evolution      = "Companion",
	JRN_SETTINGS_TIP       = "QuestCompanion settings",
	JRN_ZONE_HERE          = "%s (here)",
	JRN_ZONE_NONE          = "No zone yet: explore, your journal fills itself.",
	JRN_ACT_explore        = "Places",
	JRN_ACT_combat         = "Combat",
	JRN_ACT_craft          = "Professions",
	JRN_ACT_quests         = "Quests",
	JRN_QUESTS_TIP         = "The zone's quests your character can do (race, class), shipped with the addon. They count toward 100%.",
	JRN_WATCH              = "Track on screen",
	JRN_WATCH_TIP          = "Checked: this zone's goals show in the in-game \"Journal\" tracker. The zone you are in is tracked by default; uncheck it to hide it.",
	JRN_ACT_EMPTY_explore  = "No known village in this zone.",
	JRN_ACT_EMPTY_combat   = "No creature met here yet: target or hover them to log them.",
	JRN_ACT_EMPTY_craft    = "Nothing to gather here for your professions.",
	JRN_ACT_EMPTY_quests   = "No known quest for you in this zone.",
	JRN_ACT_NO_QUESTS      = "No quest list for this client.",
	JRN_ZONE_PERCENT       = "%d %%",
	JRN_ZONE_NOPCT         = "Percentage as soon as two activities are tracked here.",
	JRN_OPEN_CHEST         = "Open the chest",
	JRN_PART_HEAD          = "%s: %d/%d",
	JRN_ITEM_KILLED        = "defeated (%d)",
	JRN_ITEM_TO_KILL       = "to defeat",
	JRN_ITEM_TO_FIND       = "to find",
	JRN_ITEM_LEVEL         = "%s (lvl %s)",
	JRN_ITEM_GATHERED      = "gathered",
	JRN_ITEM_TO_GATHER     = "to gather (%d)",
	JRN_ITEM_TO_GATHER_GRAY = "to gather (grey)",
	JRN_ITEM_GATHER_LOCKED = "needs skill %d",
	JRN_ITEM_NAMED         = "%s, %s",
	JRN_EVO_STAGE          = "%s — %s (stage %d/%d)",
	JRN_EVO_NEXT_LEVEL     = "Next stage: %s at level %d (you are level %d).",
	JRN_EVO_NEXT_READY     = "Ready to become %s: make it happy and it grows at once.",
	JRN_EVO_MAX            = "Final stage reached. Well done!",
	JRN_EVO_NEEDS          = "Its needs (happy = all at %d %%)",
	JRN_NEED_TIP_TITLE     = "%s: %d %%",
	JRN_NEED_TIP_HAPPY     = "Met: from %d %%, it counts towards its happiness.",
	JRN_NEED_TIP_LOW       = "%d %% more until it counts (happy at %d %%).",
	JRN_NEED_TIP_HOW       = "To fill it:",
	JRN_NEED_TIP_DECAY     = "It slowly goes down while you play, never while offline.",
	JRN_NEED_hunger_1      = "eat or drink: a meal fills it fast",
	JRN_NEED_hunger_2      = "keep food in your bags when you set out",
	JRN_NEED_energy_1      = "rest in an inn or a capital",
	JRN_NEED_energy_2      = "settle by a campfire",
	JRN_NEED_energy_3      = "come back to town after a trip (with Ready2Quest)",
	JRN_NEED_mood_1        = "pet it: click on it",
	JRN_NEED_mood_2        = "turn in quests, gain levels",
	JRN_NEED_mood_3        = "rare loot pleases it, every foe defeated a little",
	JRN_NEED_curiosity_1   = "discover new zones and subzones",
	JRN_NEED_curiosity_2   = "earn stamps: villages, capitals, dungeons, rares",
	JRN_NEED_curiosity_3   = "even with everything explored: come back to a zone unseen for 2 h, enter a dungeon, defeat an elite or a rare, take a flight, open a chest, gather",
	JRN_NEED_TIP_SERENE    = "All its evolutions done: it never goes below %d %%.",
	JRN_EVO_HOW            = "How it works",
	JRN_EVO_HOW_1          = "Your level opens each stage: 10, 20, 40 and 60.",
	JRN_EVO_HOW_2          = "To go through, it must be happy: all four needs at %d %% or more. Eat, rest, turn in quests, explore.",
	JRN_EVO_HOW_3          = "Complete a zone to 100 %% (Exploration page): a chest opens and you pick a look, an ornament, a frame or a background.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.JOURNAL_WINDOW_STRINGS = { fr = FR, en = EN } end

local function ModuleOn()
	local db = ns:DB()
	return db.enabled ~= false and db.companionEnabled ~= false
end

local function ZoneName(self, zoneID)
	local info = self.MapInfo and self:MapInfo(zoneID)
	if info and info.name and info.name ~= "" then return info.name end
	local stamp = self:JournalData().stamps["zone:" .. tostring(zoneID)]
	return (stamp and stamp.name) or tostring(zoneID)
end

-- ---------------------------------------------------------------------------
-- Détail des parts : ce que chaque onglet liste
-- ---------------------------------------------------------------------------
-- Bestiaire : chaque espèce croisée, à abattre d'abord ; les nommés portent
-- leur rang (élite, rare…). La part « nommés » n'a pas de liste à elle : ses
-- espèces sont déjà là, on ne les montre pas deux fois.
local CLASS_LABEL = { elite = "BST_CLASS_elite", rare = "BST_CLASS_rare", rareelite = "BST_CLASS_rareelite", worldboss = "BST_CLASS_worldboss" }
FR.BST_CLASS_elite, FR.BST_CLASS_rare, FR.BST_CLASS_rareelite, FR.BST_CLASS_worldboss = "élite", "rare", "rare élite", "boss"
EN.BST_CLASS_elite, EN.BST_CLASS_rare, EN.BST_CLASS_rareelite, EN.BST_CLASS_worldboss = "elite", "rare", "rare elite", "boss"
ns.RegisterStrings({ BST_CLASS_elite = FR.BST_CLASS_elite, BST_CLASS_rare = FR.BST_CLASS_rare,
	BST_CLASS_rareelite = FR.BST_CLASS_rareelite, BST_CLASS_worldboss = FR.BST_CLASS_worldboss },
	{ BST_CLASS_elite = EN.BST_CLASS_elite, BST_CLASS_rare = EN.BST_CLASS_rare,
	BST_CLASS_rareelite = EN.BST_CLASS_rareelite, BST_CLASS_worldboss = EN.BST_CLASS_worldboss })

-- Zone préremplie (ZoneCreatures_<client>.lua) : aussi les espèces jamais croisées,
-- « à trouver », avec leur niveau ; vues : « à abattre » ; puis « abattu (n) ».
local function BestiaryItems(self, zoneID)
	local items = {}
	if not self.BestiarySpecies then return items end
	for npcID, species in pairs(self:BestiarySpecies(zoneID)) do
		local name = tostring(species.name or "?")
		local rawName = name
		local tag = CLASS_LABEL[species.class or ""]
		if tag then name = self:F("JRN_ITEM_NAMED", name, L[tag]) elseif species.type then name = self:F("JRN_ITEM_NAMED", name, species.type) end
		local level = self.BestiaryLevelText and self:BestiaryLevelText(species)
		if level then name = self:F("JRN_ITEM_LEVEL", name, level) end
		local killed = tonumber(species.killed) or 0
		local detail = L.JRN_ITEM_TO_FIND
		if killed > 0 then detail = self:F("JRN_ITEM_KILLED", killed) elseif species.seen then detail = L.JRN_ITEM_TO_KILL end
		local lvl = type(species.lvl) == "table" and tonumber(species.lvl[1]) or tonumber(species.level) or 0
		items[#items + 1] = { name = name, done = killed > 0, named = tag ~= nil, seen = species.seen == true,
			level = lvl, detail = detail, id = npcID, class = species.class, rawName = rawName, levelText = level,
			killed = killed }
	end
	table.sort(items, function(a, b)
		if a.done ~= b.done then return not a.done end
		if a.named ~= b.named then return a.named end
		if a.level ~= b.level then return a.level < b.level end
		return a.name < b.name
	end)
	return items
end

-- Récolte : ce que la zone t'offre à ta compétence (même gris), récolté ou non
local function GatheringItems(self, zoneID)
	local items = {}
	if not (self.GatheringZoneList and self.GatheringData) then return items end
	local data = self:GatheringData()
	-- zone préremplie (ZoneGathering_<client>.lua) : seulement ce qui y pousse
	-- ce qui demande plus de compétence vient aussi, grisé, en fin de liste
	for _, entry in ipairs((self:GatheringZoneList(zoneID, true))) do
		local record = data[entry.itemID]
		local done = record and type(record.zones) == "table" and (tonumber(record.zones[zoneID]) or 0) > 0
		local todo = entry.grayed and L.JRN_ITEM_TO_GATHER_GRAY or self:F("JRN_ITEM_TO_GATHER", entry.req)
		if entry.locked then todo = self:F("JRN_ITEM_GATHER_LOCKED", entry.req) end
		items[#items + 1] = { name = entry.name, done = done == true, req = entry.req, itemID = entry.itemID,
			locked = entry.locked and not done or nil, detail = done and L.JRN_ITEM_GATHERED or todo }
	end
	table.sort(items, function(a, b)
		if a.done ~= b.done then return not a.done end
		if a.req ~= b.req then return a.req < b.req end
		return a.name < b.name
	end)
	return items
end

local ITEMS = { bestiary = BestiaryItems, gathering = GatheringItems }

local function PartTab(def) return def.tab or PART_TAB[def.id] end

local function PartItems(self, def, zoneID)
	local fn = def.Items or ITEMS[def.id]
	if type(fn) ~= "function" then return {} end
	local ok, items = pcall(fn, self, zoneID)
	if ok and type(items) == "table" then return items end
	return {}
end

-- Lignes d'un onglet : pour chaque part de cet onglet, un titre « Villages :
-- 1/3 », puis ses éléments
function ns:JournalActivityRows(zoneID, activity)
	local rows = {}
	if not zoneID then return rows end
	for _, def in ipairs(ns.ZONE_PARTS or {}) do
		if PartTab(def) == activity then
			local ok, part = pcall(def.Compute, self, zoneID)
			if ok and type(part) == "table" and tonumber(part.need) and part.need > 0 then
				rows[#rows + 1] = { header = true, name = self:F("JRN_PART_HEAD", L[def.label] or def.label or def.id,
					math.min(tonumber(part.have) or 0, part.need), part.need), ratio = (tonumber(part.have) or 0) / part.need }
				for _, item in ipairs(PartItems(self, def, zoneID)) do rows[#rows + 1] = item end
			elseif ok and part == nil and def.id == "gathering" then
				-- rien à ta portée ici, mais des ressources pour plus tard : montrées, grisées
				for _, item in ipairs(PartItems(self, def, zoneID)) do
					if item.locked then rows[#rows + 1] = item end
				end
			end
		end
	end
	-- Quêtes proposées sur la carte par le jeu, absentes de la table (API
	-- récente, ZoneQuests.lua) : à part, hors du compte faites / total
	if activity == "quests" and self.ZoneLiveQuests then
		local ok, live = pcall(self.ZoneLiveQuests, self, zoneID)
		if ok and type(live) == "table" and #live > 0 then
			rows[#rows + 1] = { header = true, live = true, name = self:F("ZQ_LIVE_HEAD", #live) }
			for _, item in ipairs(live) do rows[#rows + 1] = item end
		end
	end
	return rows
end

-- Zones connues : celle où tu es, puis toutes celles du carnet (tampon,
-- bestiaire, récolte, coffre), par nom
function ns:JournalKnownZones()
	local seen, list = {}, {}
	local here = self.JournalZone and self:JournalZone()
	local function Add(zoneID)
		zoneID = tonumber(zoneID)
		if not zoneID or seen[zoneID] then return end
		seen[zoneID] = true
		list[#list + 1] = { id = zoneID, name = ZoneName(self, zoneID), here = zoneID == here }
	end
	if here then Add(here) end
	for id, stamp in pairs(self:JournalData().stamps) do
		if stamp.kind == "zone" then Add(id:match("^zone:(%d+)$")) end
	end
	if self.BestiaryData then for zoneID in pairs(self:BestiaryData()) do Add(zoneID) end end
	if self.GatheringData then
		for _, record in pairs(self:GatheringData()) do
			if type(record) == "table" and type(record.zones) == "table" then
				for zoneID in pairs(record.zones) do Add(zoneID) end
			end
		end
	end
	if self.ChestData then for zoneID in pairs(self:ChestData()) do Add(zoneID) end end
	table.sort(list, function(a, b)
		if a.here ~= b.here then return a.here end
		return a.name < b.name
	end)
	return list
end

-- ---------------------------------------------------------------------------
-- Fenêtre (refonte 2026-11, docs/UI.md « Carnet et compagnon ») : fenêtre v2
-- avec colonne de navigation, une page par entrée
--   Créature   portrait (cadre et fond gagnés), étape, envies, comment elle
--              évolue, parcours
--   Zones      liste de toutes les zones (jamais visitées en silhouette)
--   Zone       une zone : progression et paliers, coffre, Exploration /
--              Combat / Métiers / Quêtes ; fiches du bestiaire et aperçu 3D
--   Jour       missions, carte des auberges, garde-manger (Daily.lua)
--   Collection apparences, ornements, cadres, fonds : clic = équiper
-- Le garde-manger (Treats.lua) est aussi dans le pied, quelle que soit la page.
-- ---------------------------------------------------------------------------
local NAV_W, FOOTER_H = 220, 56
local CONTENT_W = WIDTH - 2 - NAV_W               -- 758 : zone de droite
local PAD = 24
local INNER = CONTENT_W - 2 * PAD                 -- 710 : largeur utile
local TOP = -(Theme.HEADER_HEIGHT or 100) - 6     -- première rangée sous l'en-tête
local PAGER_Y = -(HEIGHT - 2 - FOOTER_H) + 8 + 22 -- haut de la pagination, 8 au-dessus du pied
local PREVIEW_W = 210
local GRID_W = INNER - PREVIEW_W - 16             -- grille à côté de l'aperçu
local COL_GAP = 24
local HALF = math.floor((INNER - COL_GAP) / 2)    -- 343 : une colonne sur deux
local ZONE_COLS, ZONE_ROWS, ZONE_H, ZONE_STEP = 2, 12, 34, 36
local LIST_COLS, LIST_ROWS, LIST_ROW_H = 2, 12, 26
local CARD_COLS, CARD_ROWS, CARD_H, CARD_GAP = 2, 6, 46, 6
local ICON_COLS, ICON_ROWS, ICON_SIZE, ICON_STEP_X, ICON_STEP_Y = 10, 5, 44, 70, 62
local COLL_COLS, COLL_ROWS, COLL_H, COLL_GAP = 5, 5, 80, 8
local CARD_W = math.floor((GRID_W - (CARD_COLS - 1) * 10) / CARD_COLS)
local COLL_W = math.floor((GRID_W - (COLL_COLS - 1) * COLL_GAP) / COLL_COLS)
local ZONE_W = math.floor((INNER - (ZONE_COLS - 1) * 12) / ZONE_COLS)
local LIST_W = math.floor((INNER - (LIST_COLS - 1) * 12) / LIST_COLS)
-- la Créature d'abord : c'est elle, le cœur de l'addon
-- 1.4.0 : la Ménagerie (Pokédex des captures) juste après la Créature
-- la fiche d'une zone (« completion ») s'ouvre depuis Zones : pas d'entrée à elle
-- 1.5.0 : « progress » (Complétion : zones et fiche de zone) vient d'ailleurs
-- (ns.JOURNAL_PANES) ; Collection rejoint Compagnon
-- 2.3.0 : « guide » (la ménagerie expliquée, JournalGuide.lua), en dernier
-- 2.6.0 : plus de page « Souvenirs » (l'album est retiré)
-- 2.7.0 : « feats » (Hauts faits, JournalFeats.lua) après la Ménagerie
local SECTIONS = { "evolution", "menagerie", "feats", "day", "progress", "guide" }
local MEN_STATES = { "all", "captured", "missing", "tokill", "shiny" }
local MEN_RANKS = { "all", "normal", "elite", "rare", "boss" }
local MEN_SORTS = { "no", "name", "level", "rank", "kills", "date" }

-- 2.11.0 : l'état du carnet tient au /reload (QuestCompanionDB.journalState,
-- au niveau du compte comme journalTab) : filtres de la page Créatures, part,
-- filtre et quête choisie d'Exploration. Chaque valeur est vérifiée contre sa
-- liste : une valeur d'une autre version est ignorée. La zone de la page
-- Créatures repart sur « ici », sauf « toutes les zones » ; la recherche
-- tapée n'est pas retenue. OpenMenagerieZone ne mémorise rien.
local STATE_VALID = {
	menRank = MEN_RANKS, menSort = MEN_SORTS, menState = MEN_STATES,
	progPart = { "explore", "craft", "quests" }, progFilter = { "mine", "seen", "all" },
}
local function Valid(list, value)
	for _, v in ipairs(list or {}) do if v == value then return true end end
	return false
end
ns.JOURNAL_STATE_VALID = STATE_VALID
function ns:JournalRemember(key, value)
	local db = self:DB()
	if type(db.journalState) ~= "table" then db.journalState = {} end
	db.journalState[key] = value
end
function ns:JournalRestoreState(frame)
	local state = self:DB().journalState
	if not (frame and type(state) == "table") then return end
	for key, list in pairs(STATE_VALID) do
		if Valid(list, state[key]) then frame[key] = state[key] end
	end
	local icons = ns.MENAGERIE_TYPE_ICONS
	if type(state.menType) == "string" and icons and icons[state.menType] then frame.menType = state.menType end
	if state.menZoneAll == true then frame.menZone = "all" end
	if tonumber(state.progQuest) then frame.progQuest = tonumber(state.progQuest) end
end

-- 2.11.0 : une recherche attend la fin de la frappe : un seul rafraîchissement
-- 0,25 s après la dernière touche (sans C_Timer : tout de suite)
ns.JOURNAL_SEARCH_DELAY = 0.25
local soonToken = {}
function ns:JournalSoon(key)
	local timer = rawget(_G, "C_Timer")
	if type(timer) ~= "table" or type(timer.After) ~= "function" then return self:RefreshJournal() end
	soonToken[key] = (soonToken[key] or 0) + 1
	local mine = soonToken[key]
	timer.After(ns.JOURNAL_SEARCH_DELAY, function()
		if soonToken[key] ~= mine then return end
		local frame = ns.journalFrame
		if frame and frame.IsShown and frame:IsShown() then ns:RefreshJournal() end
	end)
end
local MEN_ROW_H = 30
local COLL_KINDS = { "app", "orn", "frame", "bg" }
local MARKS = { 25, 50, 75, 100 }
local CONTINENTS = { [1415] = "ek", [1414] = "ka" }
ns.JOURNAL_LAYOUT = { width = WIDTH, height = HEIGHT, nav = NAV_W, footer = FOOTER_H, pad = PAD, inner = INNER,
	top = TOP, pagerTop = PAGER_Y, listCols = LIST_COLS, listRows = LIST_ROWS, cardCols = CARD_COLS, cardRows = CARD_ROWS,
	iconCols = ICON_COLS, iconRows = ICON_ROWS, tileCols = ZONE_COLS, tileRows = ZONE_ROWS, collCols = COLL_COLS,
	collRows = COLL_ROWS, zoneStep = ZONE_COLS * 3 }
-- liseré des fiches : rang du bestiaire
local RANK_COLOR = {
	elite = { 0.79, 0.80, 0.82 }, rareelite = { 0.29, 0.56, 0.88 }, rare = { 0.29, 0.56, 0.88 }, worldboss = Theme.GOLD,
}
ns.BESTIARY_RANK_COLOR = RANK_COLOR      -- repris par l'infobulle des créatures (Tooltips.lua)
local SHINY_COLOR = Theme.SHINY           -- fiche d'une brillante abattue (2.11.2 : jeton du socle, même valeur)
local APP_ICON = "Interface\\Icons\\Ability_Hunter_BeastCall"
local ORN_ICON = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02"
local LOCK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local FR2 = {
	JRN_FILTER_all         = "Toutes",
	JRN_FILTER_ek          = "Royaumes de l'Est",
	JRN_FILTER_ka          = "Kalimdor",
	JRN_FILTER_other       = "Autres",
	JRN_SORT_lvl           = "Par niveau",
	JRN_SORT_pct           = "Par %",
	JRN_PREV_HINT_combat   = "Survole une fiche : la créature s'affiche ici.",
	JRN_PREV_HINT_explore  = "Les villages et lieux de la zone. Un losange plein : visité.",
	JRN_PREV_HINT_quests   = "Les quêtes de la zone que ton personnage peut faire. Elles comptent dans les 100 %.",
	JRN_PREV_HINT_craft    = "Les ressources de ta compétence qui poussent ici. En couleur : déjà récoltées dans la zone.",
	JRN_RANK_normal        = "normal",
	JRN_Q_all              = "Toutes",
	JRN_Q_todo             = "À faire",
	JRN_Q_done             = "Faites",
	JRN_COLL_app           = "Apparences",
	JRN_COLL_orn           = "Ornements",
	JRN_COLL_frame         = "Cadres",
	JRN_COLL_bg            = "Fonds",
	JRN_COLL_SRC_BASE      = "possédé d'office",
	JRN_COLL_SRC_TIER      = "coffre de zone, palier %d",
	JRN_SEC_menagerie      = "Créatures",
	JRN_SUB_menagerie      = "Toutes les créatures capturables, numérotées : en couleur celles que tu as capturées.",
	JRN_MEN_all            = "Toutes",
	JRN_MEN_captured       = "Capturées",
	JRN_MEN_missing        = "À capturer",
	JRN_MEN_tokill         = "À abattre",
	JRN_MEN_shiny          = "Brillantes",
	JRN_MEN_COUNT          = "%d capturées · %d croisées · %d en tout",
	JRN_MEN_COUNT_SHINY    = "%d capturées · brillantes : %d · %d croisées · %d en tout",
	JRN_MEN_SEE_SHINY      = "Version brillante",
	JRN_MEN_SEE_NORMAL     = "Version normale",
	JRN_MEN_SHINY_CAUGHT   = "Brillante capturée le %s",
	JRN_MEN_SHINY_SEEN     = "Brillante repérée le %s · pas encore capturée",
	JRN_MEN_SHINY_UNSEEN   = "Brillante jamais repérée : abats-en, ta chance monte",
	JRN_MEN_HINT           = "Survol : sa fiche. Clic sur une créature capturée : elle devient ton compagnon.",
	JRN_MEN_ZONE_HERE      = "Zone actuelle (%s)",
	JRN_MEN_ZONE_ALL       = "Toutes les zones",
	JRN_MEN_RANK_all       = "Toutes raretés",
	JRN_MEN_RANK_normal    = "Normal",
	JRN_MEN_RANK_elite     = "Élite",
	JRN_MEN_RANK_rare      = "Rare",
	JRN_MEN_RANK_boss      = "Boss",
	JRN_MEN_SORT_no        = "Tri : numéro",
	JRN_MEN_SORT_name      = "Tri : nom",
	JRN_MEN_SORT_level     = "Tri : niveau",
	JRN_MEN_SORT_rank      = "Tri : rareté",
	JRN_MEN_SORT_kills     = "Tri : abattues",
	JRN_MEN_SORT_date      = "Tri : capture",
	JRN_MEN_SEARCH         = "Chercher un nom…",
	JRN_MEN_UNKNOWN        = "???",
	JRN_MEN_NEVER          = "Jamais croisée : approche-toi, cible-la.",
	JRN_MEN_NOT_KILLED     = "Pas encore abattue",
	JRN_MEN_NONE           = "Aucune créature ne correspond à ces filtres.",
	JRN_MEN_NO             = "n° %03d",
	JRN_MEN_RANK           = "%s · niveau %s",
	JRN_MEN_ZONE           = "Zone : %s",
	JRN_MEN_CAUGHT         = "Capturée le %s",
	JRN_MEN_NOTYET         = "Pas encore capturée · chance ~%d %%",
	JRN_MEN_KILLED         = "Abattue %d fois",
	JRN_MEN_EQUIP          = "Clic : en faire ton compagnon",
	JRN_MEN_EQUIPPED       = "C'est ton compagnon",
	JRN_MEN_EMPTY          = "Aucune créature croisée pour l'instant : cible ou survole des monstres.",
	JRN_SUB_companion      = "Ton compagnon de route : son humeur, ses envies, son allure.",
	JRN_EVO_STAT_captures  = "capturées",
	JRN_EVO_STAT_shiny     = "brillantes",
	JRN_EVO_STAT_days      = "jours ensemble",
	JRN_EVO_STAT_missions  = "missions",           -- 2.11.0 : plus court, tient sur la plaque
	JRN_EVO_STAT_km        = "parcourus",
	-- 2.11.0 : colonne de navigation en tableau de bord
	JRN_NAVSUM_COMPANION_TIP = "Ton compagnon : clic pour sa page.",
	JRN_NAVSUM_ZONE_TIP    = "La zone où tu es : clic pour son exploration.",
	JRN_NAVSUM_ZONE_NONE   = "Zone sans exploration",
	JRN_NAVSUM_DAY         = "Jour",
	JRN_NAVSUM_WEEK        = "Semaine",
	JRN_NAVSUM_MISSIONS_TIP = "Missions du jour et de la semaine : clic pour la page Missions.",
	JRN_EVO_LOOKS          = "Son allure",
	JRN_EVO_LOOKS_COUNT    = "%d apparences",
	JRN_EVO_FRAME          = "Cadre",
	JRN_EVO_BG             = "Fond",
	JRN_EVO_ORNS           = "Ornements",
	JRN_EVO_ORN_NONE       = "Pas encore d'ornement : les coffres de zone en donnent.",
	JRN_EVO_LOOK_TIP       = "Clic : la porter. Les mascottes viennent des coffres et des cartes, les autres de la page Créatures.",
	JRN_EVO_QUIET          = "…",
	JRN_NAV_GROUP          = "Carnet",
	JRN_SUB_day            = "Missions du compagnon, du jour et de la semaine : de quoi nourrir ta créature et capturer.",
	JRN_SUB_collection     = "Ce que la route t'a fait gagner : clic pour l'équiper.",
}
local EN2 = {
	JRN_FILTER_all         = "All",
	JRN_FILTER_ek          = "Eastern Kingdoms",
	JRN_FILTER_ka          = "Kalimdor",
	JRN_FILTER_other       = "Other",
	JRN_SORT_lvl           = "By level",
	JRN_SORT_pct           = "By %",
	JRN_PREV_HINT_combat   = "Hover a card: the creature shows here.",
	JRN_PREV_HINT_explore  = "The zone's villages and places. A full diamond: visited.",
	JRN_PREV_HINT_quests   = "The zone's quests your character can do. They count toward 100%.",
	JRN_PREV_HINT_craft    = "The resources of your skill that grow here. In colour: already gathered in the zone.",
	JRN_RANK_normal        = "normal",
	JRN_Q_all              = "All",
	JRN_Q_todo             = "To do",
	JRN_Q_done             = "Done",
	JRN_COLL_app           = "Appearances",
	JRN_COLL_orn           = "Ornaments",
	JRN_COLL_frame         = "Frames",
	JRN_COLL_bg            = "Backgrounds",
	JRN_COLL_SRC_BASE      = "owned from the start",
	JRN_COLL_SRC_TIER      = "zone chest, tier %d",
	JRN_SEC_menagerie      = "Creatures",
	JRN_SUB_menagerie      = "Every creature you can capture, numbered: the ones you captured are in colour.",
	JRN_MEN_all            = "All",
	JRN_MEN_captured       = "Captured",
	JRN_MEN_missing        = "To capture",
	JRN_MEN_tokill         = "To defeat",
	JRN_MEN_shiny          = "Shiny",
	JRN_MEN_COUNT          = "%d captured · %d met · %d in all",
	JRN_MEN_COUNT_SHINY    = "%d captured · %d shiny · %d met · %d in all",
	JRN_MEN_SEE_SHINY      = "Shiny version",
	JRN_MEN_SEE_NORMAL     = "Normal version",
	JRN_MEN_SHINY_CAUGHT   = "Shiny captured on %s",
	JRN_MEN_SHINY_SEEN     = "Shiny spotted on %s · not captured yet",
	JRN_MEN_SHINY_UNSEEN   = "Shiny never spotted: defeat more, your odds go up",
	JRN_MEN_HINT           = "Hover: its card. Click a captured creature: it becomes your companion.",
	JRN_MEN_ZONE_HERE      = "Current zone (%s)",
	JRN_MEN_ZONE_ALL       = "All zones",
	JRN_MEN_RANK_all       = "All rarities",
	JRN_MEN_RANK_normal    = "Normal",
	JRN_MEN_RANK_elite     = "Elite",
	JRN_MEN_RANK_rare      = "Rare",
	JRN_MEN_RANK_boss      = "Boss",
	JRN_MEN_SORT_no        = "Sort: number",
	JRN_MEN_SORT_name      = "Sort: name",
	JRN_MEN_SORT_level     = "Sort: level",
	JRN_MEN_SORT_rank      = "Sort: rarity",
	JRN_MEN_SORT_kills     = "Sort: kills",
	JRN_MEN_SORT_date      = "Sort: capture",
	JRN_MEN_SEARCH         = "Search a name…",
	JRN_MEN_UNKNOWN        = "???",
	JRN_MEN_NEVER          = "Never met: get close, target it.",
	JRN_MEN_NOT_KILLED     = "Not defeated yet",
	JRN_MEN_NONE           = "No creature matches these filters.",
	JRN_MEN_NO             = "No. %03d",
	JRN_MEN_RANK           = "%s · level %s",
	JRN_MEN_ZONE           = "Zone: %s",
	JRN_MEN_CAUGHT         = "Captured on %s",
	JRN_MEN_NOTYET         = "Not captured yet · chance ~%d%%",
	JRN_MEN_KILLED         = "Defeated %d times",
	JRN_MEN_EQUIP          = "Click: make it your companion",
	JRN_MEN_EQUIPPED       = "It's your companion",
	JRN_MEN_EMPTY          = "No creature met yet: target or hover some monsters.",
	JRN_SUB_companion      = "Your road companion: its mood, its needs, its look.",
	JRN_EVO_STAT_captures  = "captured",
	JRN_EVO_STAT_shiny     = "shinies",
	JRN_EVO_STAT_days      = "days together",
	JRN_EVO_STAT_missions  = "missions",
	JRN_EVO_STAT_km        = "travelled",
	JRN_NAVSUM_COMPANION_TIP = "Your companion: click for its page.",
	JRN_NAVSUM_ZONE_TIP    = "The zone you are in: click for its exploration.",
	JRN_NAVSUM_ZONE_NONE   = "No exploration here",
	JRN_NAVSUM_DAY         = "Day",
	JRN_NAVSUM_WEEK        = "Week",
	JRN_NAVSUM_MISSIONS_TIP = "Daily and weekly missions: click for the Missions page.",
	JRN_EVO_LOOKS          = "Its look",
	JRN_EVO_LOOKS_COUNT    = "%d looks",
	JRN_EVO_FRAME          = "Frame",
	JRN_EVO_BG             = "Background",
	JRN_EVO_ORNS           = "Ornaments",
	JRN_EVO_ORN_NONE       = "No ornament yet: zone chests give some.",
	JRN_EVO_LOOK_TIP       = "Click: wear it. Mascots come from chests and cards, the rest from the Creatures page.",
	JRN_EVO_QUIET          = "…",
	JRN_NAV_GROUP          = "Journal",
	JRN_SUB_day            = "Companion, daily and weekly missions: food for your creature and capture aids.",
	JRN_SUB_collection     = "What the road has earned you: click to equip it.",
}
ns.RegisterStrings(FR2, EN2)
for key, text in pairs(FR2) do FR[key], EN[key] = text, EN2[key] end

-- ---------------------------------------------------------------------------
-- Petites aides de mise en page (tout se place depuis le haut gauche de la
-- zone de droite, marge PAD comprise)
-- ---------------------------------------------------------------------------
local function At(region, content, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + x, y)
	return region
end

local function Text(parent, font, color, width)
	local text = Theme.Text(parent, font or Theme.F_BODY, color or Theme.TEXT)
	text:SetJustifyH("LEFT")
	if width then text:SetWidth(width) end
	return text
end

-- Où poser l'infobulle (2.8.2) : ANCHOR_RIGHT la posait AU-DESSUS du coin
-- droit de l'élément, sur la rangée de commandes (boutons de type de la
-- Ménagerie) ou loin à droite d'une ligne des hauts faits.
--   "row"   : à droite de la ligne, son haut à hauteur de la ligne ; pas la
--             place à droite de l'écran : sous la ligne, alignée à droite ;
--   "below" : sous l'élément, centrée (les boutons : rien au-dessus caché) ;
--   "above" : au-dessus (boutons du bas de la fenêtre).
-- L'infobulle du jeu reste bornée à l'écran.
ns.JOURNAL_TIP_GAP = 8
ns.JOURNAL_TIP_ROOM = 300   -- largeur à prévoir à droite d'une ligne
function ns.JournalTipAnchor(tip, owner, mode)
	if type(tip) ~= "table" or not owner then return nil end
	pcall(tip.SetOwner, tip, owner, "ANCHOR_NONE")
	if tip.ClearAllPoints then tip:ClearAllPoints() end
	local gap = ns.JOURNAL_TIP_GAP
	if mode == "row" then
		local right = owner.GetRight and tonumber(owner:GetRight())
		local screen = UIParent and UIParent.GetRight and tonumber(UIParent:GetRight())
		if right and screen and screen > 0 and right + gap + ns.JOURNAL_TIP_ROOM > screen then
			tip:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2)
			return "below"
		end
		tip:SetPoint("TOPLEFT", owner, "TOPRIGHT", gap, 0)
		return "right"
	end
	if mode == "above" then
		tip:SetPoint("BOTTOM", owner, "TOP", 0, 4)
		return "above"
	end
	tip:SetPoint("TOP", owner, "BOTTOM", 0, -4)
	return "below"
end

local function Tip(owner, title, lines, mode)
	local tip = rawget(_G, "GameTooltip")
	if type(tip) ~= "table" then return end
	ns.JournalTipAnchor(tip, owner, mode)
	if tip.ClearLines then tip:ClearLines() end
	Theme.TooltipTitle(tip, title)
	for _, line in ipairs(lines or {}) do Theme.TooltipLine(tip, line, Theme.TEXT, true) end
	tip:Show()
end
local function HideTip() local tip = rawget(_G, "GameTooltip"); if tip and tip.Hide then tip:Hide() end end

-- Titre de section : « Ses envies (heureux = …) » -> SES ENVIES (heureux = …)
local function SectionText(section, text)
	text = tostring(text or "")
	local label, detail = text:match("^(.-)%s*%((.*)%)%s*$")
	section:SetText(label or text, detail)
	section.raw = text
end

-- Carte sombre de l'aperçu : fond NAV, filet EDGE_SOFT
local function Panel(parent, width, height)
	local p = CreateFrame("Frame", nil, parent)
	p:SetSize(width, height)
	p.bg = Theme.Solid(p, "BACKGROUND", Theme.NAV, 1)
	p.bg:SetAllPoints()
	p.border = Theme.Border(p, Theme.EDGE_SOFT, 1)
	return p
end

-- Infobulle d'une envie du compagnon : valeur, seuil du bonheur, et ce qui la
-- remplit (les gains réels de Companion.lua : repas, repos, caresse, quêtes,
-- niveaux, butin rare, exploration, tampons)
ns.NEED_TIP_LINES = { hunger = 2, energy = 3, mood = 3, curiosity = 3 }
function ns:NeedTooltipLines(key)
	local data = self.CompanionData and self:CompanionData() or { needs = {} }
	local value = math.floor(tonumber(data.needs and data.needs[key]) or 0)
	local happyMin = ns.COMPANION_HAPPY_MIN or 70
	local lines = { self:F("JRN_NEED_TIP_TITLE", L["COMP_NEED_" .. key] or key, value) }
	if value >= happyMin then
		lines[#lines + 1] = self:F("JRN_NEED_TIP_HAPPY", happyMin)
	else
		lines[#lines + 1] = self:F("JRN_NEED_TIP_LOW", happyMin - value, happyMin)
	end
	lines[#lines + 1] = L.JRN_NEED_TIP_HOW
	for index = 1, ns.NEED_TIP_LINES[key] or 0 do
		lines[#lines + 1] = "- " .. tostring(L["JRN_NEED_" .. key .. "_" .. index])
	end
	lines[#lines + 1] = L.JRN_NEED_TIP_DECAY
	if (tonumber(data.stage) or 1) >= #(ns.COMPANION_STAGES or {}) and ns.COMPANION_SERENE_FLOOR then
		lines[#lines + 1] = self:F("JRN_NEED_TIP_SERENE", ns.COMPANION_SERENE_FLOOR)
	end
	return lines, value >= happyMin
end

function ns:ShowNeedTooltip(owner, key)
	if type(GameTooltip) ~= "table" or not GameTooltip.SetOwner then return end
	local lines, happy = self:NeedTooltipLines(key)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	if happy then Theme.TooltipTitle(GameTooltip, lines[1]) else Theme.TooltipLine(GameTooltip, lines[1], Theme.PARCHMENT) end
	for index = 2, #lines do
		if index == #lines then Theme.TooltipHint(GameTooltip, lines[index], true)
		else Theme.TooltipLine(GameTooltip, lines[index], Theme.TEXT, true) end
	end
	GameTooltip:Show()
end

-- ---------------------------------------------------------------------------
-- Toutes les zones : celles du jeu (ZONE_LEVELS) et celles du carnet
-- ---------------------------------------------------------------------------
function ns:JournalContinentOf(zoneID)
	local info = self.MapInfo and self:MapInfo(zoneID)
	return CONTINENTS[info and tonumber(info.parentMapID) or 0] or "other"
end

function ns:JournalAllZones(filter, sort)
	local known, list, here = {}, {}, self.JournalZone and self:JournalZone()
	for _, zone in ipairs(self:JournalKnownZones()) do known[zone.id] = true end
	-- les zones du jeu : la table des niveaux et les zones préremplies du client
	-- (créatures, quêtes ; celles propres à Forever comprises), puis le carnet
	local ids = {}
	for _, source in ipairs({ ns.ZONE_LEVELS, ns.ZONE_CREATURES, ns.ZONE_QUESTS }) do
		for _, zoneID in ipairs(ns.ZoneIds(source)) do
			if tonumber(zoneID) then ids[tonumber(zoneID)] = true end
		end
	end
	for zoneID in pairs(known) do ids[zoneID] = true end
	for zoneID in pairs(ids) do
		local continent = self:JournalContinentOf(zoneID)
		if not filter or filter == "all" or filter == continent then
			local range = self.ZoneLevelRange and self:ZoneLevelRange(zoneID)
			local done = known[zoneID] and self.ZoneCompletion and self:ZoneCompletion(zoneID)
			local percent = (done and #done.parts >= 2) and done.percent or nil
			list[#list + 1] = { id = zoneID, name = ZoneName(self, zoneID), seen = known[zoneID] == true,
				here = zoneID == here, continent = continent, lo = range and range[1] or 99, hi = range and range[2] or 99,
				percent = percent, chest = self.ChestData and self:ChestData()[zoneID] or nil }
		end
	end
	table.sort(list, function(a, b)
		if sort == "pct" and (a.percent or -1) ~= (b.percent or -1) then return (a.percent or -1) > (b.percent or -1) end
		if a.lo ~= b.lo then return a.lo < b.lo end
		if a.hi ~= b.hi then return a.hi < b.hi end
		return a.name < b.name
	end)
	return list
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
-- Aperçu (fiche survolée, objet de la collection) : carte sombre, modèle 3D ou
-- nuancier en haut, nom, puis des lignes empilées de haut en bas
local PREVIEW_MODEL_H = 168
local function BuildPreview(parent, content, x, y, height)
	local p = Panel(parent, PREVIEW_W, height)
	At(p, content, x, y)
	p.stage = Theme.Solid(p, "BORDER", Theme.WINDOW, 1)
	p.stage:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
	p.stage:SetSize(PREVIEW_W - 2, PREVIEW_MODEL_H)
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, p)
	if ok and model then
		model:SetSize(PREVIEW_W - 16, PREVIEW_MODEL_H - 12)
		model:SetPoint("TOP", p, "TOP", 0, -7)
		p.model = model
	end
	p.swatch = p:CreateTexture(nil, "ARTWORK")
	p.swatch:SetSize(PREVIEW_W - 16, PREVIEW_MODEL_H - 12)
	p.swatch:SetPoint("TOP", p, "TOP", 0, -7)
	p.swatch:Hide()
	p.rule = Theme.Solid(p, "ARTWORK", Theme.EDGE_SOFT, 1)
	p.rule:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1 - PREVIEW_MODEL_H)
	p.rule:SetSize(PREVIEW_W - 2, 1)
	p.title = Text(p, Theme.F_TITLE, Theme.PARCHMENT, PREVIEW_W - 28)
	p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -PREVIEW_MODEL_H - 14)
	if p.title.SetWordWrap then p.title:SetWordWrap(false) end
	p.lines = {}
	for index = 1, 8 do
		local line = Text(p, index == 1 and Theme.F_BODY or Theme.F_SMALL, index == 1 and Theme.LABEL or Theme.MUTED_LIGHT,
			PREVIEW_W - 28)
		if line.SetWordWrap then line:SetWordWrap(true) end
		p.lines[index] = line
	end
	p.maxBottom = height - 10
	return p
end

-- lignes de l'aperçu, de haut en bas (une ligne longue pousse la suivante)
local function PreviewLayout(p)
	local y = -PREVIEW_MODEL_H - 14 - 22
	for index, line in ipairs(p.lines) do
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y)
		local h = Theme.TextHeight(line, PREVIEW_W - 28, index == 1 and Theme.F_BODY or Theme.F_SMALL)
		line.top = y
		if h > 0 then y = y - h - 6 end
		-- plus de place : la ligne attend (rien ne déborde de la carte)
		if -y > p.maxBottom then line:Hide() else line:Show() end
	end
	p.bottom = y
end

local function PreviewSet(p, title, lines, opts)
	opts = opts or {}
	p.title:SetText(title or "")
	for index, line in ipairs(p.lines) do line:SetText(lines and lines[index] or "") end
	PreviewLayout(p)
	if p.model then
		p.model.creature, p.model.display = nil, nil
		-- 2.11.0 : un seul chargeur de modèles, profil « preview » (Companion.lua)
		if (opts.creature or opts.display) and ns.ShowModel then
			ns.ShowModel(p.model, { display = opts.display, npc = opts.creature, shiny = opts.shiny }, "preview")
			p.model.creature, p.model.display = opts.creature, opts.display
		elseif opts.creature then
			if p.model.SetCreature then pcall(p.model.SetCreature, p.model, opts.creature) end
			p.model.creature = opts.creature
			if ns.ModelShinyLight then ns.ModelShinyLight(p.model, opts.shiny) end
			p.model:Show()
		elseif opts.display then
			if p.model.SetDisplayInfo then pcall(p.model.SetDisplayInfo, p.model, opts.display) end
			p.model.display = opts.display
			p.model:Show()
		elseif ns.ModelForget then
			ns.ModelForget(p.model)
		else
			if p.model.ClearModel then pcall(p.model.ClearModel, p.model) end
			p.model:Hide()
		end
	end
	if opts.color then
		p.swatch:SetTexture(Theme.SOLID)
		p.swatch:SetVertexColor(opts.color[1], opts.color[2], opts.color[3], opts.color[4] or 1)
		p.swatch:Show()
	elseif opts.texture then
		pcall(p.swatch.SetTexture, p.swatch, opts.texture)
		p.swatch:SetVertexColor(1, 1, 1, 1)
		p.swatch:Show()
	else
		p.swatch:Hide()
	end
end

local function Chips(parent, keys, prefix, onPick)
	local defs = {}
	for _, key in ipairs(keys) do defs[#defs + 1] = { id = key, label = L[prefix .. key] or key } end
	local row = Theme.CreateChips(parent, defs, onPick)
	return row, row.byId
end

-- Pagination : position et chevrons alignés à droite, une aide à gauche
local function Pager(pane, content)
	local pager = Theme.CreatePager(pane, function(delta) ns:ScrollJournal(delta) end)
	pager:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + INNER, PAGER_Y)
	pane.pager, pane.position, pane.up, pane.down = pager, pager.position, pager.up, pager.down
	pane.hint = Text(pane, Theme.F_SMALL, Theme.MUTED, INNER - 240)
	At(pane.hint, content, 0, PAGER_Y - 4)
	if pane.hint.SetWordWrap then pane.hint:SetWordWrap(false) end
	return pager
end

-- Zones : filtres et tri, liste sur deux colonnes (nom, niveaux, état, %)
-- Briques et mesures du carnet, pour les pages construites ailleurs
-- (ns.JOURNAL_PANES : JournalCompletion.lua, JournalGuide.lua…)
ns.JournalUI = {
	At = At, Text = Text, Tip = Tip, HideTip = HideTip, Panel = Panel, Chips = Chips, Pager = Pager,
	BuildPreview = BuildPreview, PreviewSet = PreviewSet,
	PAD = PAD, INNER = INNER, TOP = TOP, PAGER_Y = PAGER_Y, HALF = HALF, COL_GAP = COL_GAP,
	PREVIEW_W = PREVIEW_W, GRID_W = GRID_W, CONTENT_W = CONTENT_W, WIDTH = WIDTH, HEIGHT = HEIGHT,
	FOOTER_H = FOOTER_H, NAV_W = NAV_W,
}
-- Pages externes : ns.JOURNAL_PANES[section] = { field = "<frame.champ>",
-- title, subtitle (clés L), build(self, frame, content, ui),
-- refresh(self, frame, ui), scroll(self, frame, delta) facultatif }
ns.JOURNAL_PANES = ns.JOURNAL_PANES or {}

-- Compagnon (1.5.0) : le héros (grand portrait, nom, caractère, étapes, sa
-- dernière bulle), cinq chiffres (captures, brillantes, jours ensemble,
-- missions, route parcourue), ses envies, son allure (apparences, cadre, fond,
-- ornements : l'ancienne Collection)
local HERO_H, EVO_ROW, EVO_STEP = 176, 30, 34
local PORTRAIT = 148
-- caméra rapprochée : le compagnon remplit le grand cadre du héros
local PORTRAIT_ZOOM = 0.65
-- 2.11.0 : plaques plus hautes, chiffre et libellé centrés ensemble
local STAT_H = 58
local STAT_VALUE_Y, STAT_LABEL_Y = 8, -11
ns.JOURNAL_STAT_LAYOUT = { h = STAT_H, valueY = STAT_VALUE_Y, labelY = STAT_LABEL_Y, gap = 6, glyph = 0.8 }

-- 2.11.1 (B1, suite) : le chiffre et le libellé forment un groupe centré
-- sur la plaque. En 2.11.0, +8 et −11 du centre les collaient aux bords
-- (chiffre en haut, libellé en bas). Hauteurs lues sur la police posée
-- (GetFont), sinon celles du thème, ramenées à la hauteur des glyphes
-- (glyph : chiffres et minuscules, sans l'interligne de la ligne) ; le fond
-- des plaques a un biseau : écart serré (6 px entre les glyphes, les lignes
-- de texte se touchent sans se chevaucher). Rappelée quand le
-- style change de police.
local function FontHeight(fs, fallback)
	local ok, _, size = false, nil, nil
	if fs and fs.GetFont then ok, _, size = pcall(fs.GetFont, fs) end
	size = ok and tonumber(size) or nil
	return (size and size > 0) and size or fallback
end
function ns.JournalStatCenter(tile)
	if not (tile and tile.value and tile.label) then return nil end
	local S = ns.JOURNAL_STAT_LAYOUT
	local hv, hl = FontHeight(tile.value, 16) * S.glyph, FontHeight(tile.label, 11) * S.glyph
	local half = (hv + S.gap + hl) / 2
	local vy, ly = math.floor(half - hv / 2 + 0.5), -math.floor(half - hl / 2 + 0.5)
	tile.value:ClearAllPoints()
	tile.value:SetPoint("CENTER", tile, "CENTER", 0, vy)
	tile.label:ClearAllPoints()
	tile.label:SetPoint("CENTER", tile, "CENTER", 0, ly)
	tile.valueY, tile.labelY = vy, ly
	return vy, ly
end
local LOOK_COUNT, LOOK_W, LOOK_H = 5, 52, 66
local STATS = { "captures", "shiny", "days", "missions", "km" }

local function BuildEvolution(self, frame, content)
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.evo = pane
	pane.stage = frame.header.subtitle

	local hero = Theme.CreateTile(pane, INNER, HERO_H, { kind = "Frame" })
	At(hero, content, 0, TOP)
	hero:SetFill(Theme.NAV)
	hero:SetAccent(Theme.GOLD)
	pane.hero = hero
	if self.CompanionPortrait then
		hero.portrait = self:CompanionPortrait(hero, PORTRAIT, PORTRAIT_ZOOM)
		hero.portrait:SetPoint("LEFT", hero, "LEFT", 14, 0)
	end
	local textX = 14 + PORTRAIT + 20
	local textW = INNER - textX - 16
	pane.name = Text(hero, Theme.F_TITLE, Theme.PARCHMENT, 260)
	pane.name:SetPoint("TOPLEFT", hero, "TOPLEFT", textX, -16)
	if pane.name.SetWordWrap then pane.name:SetWordWrap(false) end
	pane.traitTag = Theme.CreateTag(hero, "", Theme.GOLD)
	pane.traitTag:SetPoint("LEFT", pane.name, "RIGHT", 10, 0)
	pane.look = Text(hero, Theme.F_BODY, Theme.MUTED_LIGHT, textW)
	pane.look:SetPoint("TOPLEFT", hero, "TOPLEFT", textX, -42)
	if pane.look.SetWordWrap then pane.look:SetWordWrap(false) end
	-- étapes : un losange par étape, plein jusqu'à l'actuelle, puis la suivante
	pane.steps = {}
	for index = 1, #(ns.COMPANION_STAGES or {}) do
		local step = Theme.CreateDiamond(hero, 11, true)
		step:SetPoint("TOPLEFT", hero, "TOPLEFT", textX + (index - 1) * 17, -66)
		pane.steps[index] = step
	end
	pane.stepsHover = CreateFrame("Frame", nil, hero)
	pane.stepsHover:SetPoint("TOPLEFT", hero, "TOPLEFT", textX - 2, -60)
	pane.stepsHover:SetSize(#pane.steps * 17 + 4, 22)
	pane.stepsHover:SetScript("OnEnter", function(owner)
		local happy = ns.COMPANION_HAPPY_MIN or 70
		Tip(owner, L.JRN_EVO_HOW, { L.JRN_EVO_HOW_1, ns:F("JRN_EVO_HOW_2", happy), ns:F("JRN_EVO_HOW_3") })
	end)
	pane.stepsHover:SetScript("OnLeave", HideTip)
	local nextX = textX + #pane.steps * 17 + 10
	pane.next = Text(hero, Theme.F_BODY, Theme.TEXT, INNER - nextX - 16)
	pane.next:SetPoint("TOPLEFT", hero, "TOPLEFT", nextX, -64)
	if pane.next.SetWordWrap then pane.next:SetWordWrap(false) end
	-- sa dernière bulle (ou un mot de son caractère), sur papier clair
	pane.bubble = Theme.CreateTile(hero, textW, 52, { kind = "Frame" })
	pane.bubble:SetPoint("TOPLEFT", hero, "TOPLEFT", textX, -94)
	pane.bubble:SetFill(Theme.PARCHMENT)
	pane.bubble.text = Text(pane.bubble, Theme.F_BODY, Theme.INK, textW - 24)
	pane.bubble.text:SetPoint("LEFT", pane.bubble, "LEFT", 12, 0)
	if pane.bubble.text.SetWordWrap then pane.bubble.text:SetWordWrap(true) end
	if Theme.NoShadow then Theme.NoShadow(pane.bubble.text) end
	pane.openChest = Theme.CreateButton(hero, "auto", 24, L.JRN_OPEN_CHEST, function() ns:OpenChest() end, "primary")
	pane.openChest:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -14, -14)

	-- cinq chiffres
	local statY = TOP - HERO_H - 10
	local statW = math.floor((INNER - (#STATS - 1) * 8) / #STATS)
	pane.stats = {}
	for index, key in ipairs(STATS) do
		local tile = Theme.CreateTile(pane, statW, STAT_H, { kind = "Frame" })
		At(tile, content, (index - 1) * (statW + 8), statY)
		tile.value = Text(tile, Theme.F_TITLE, Theme.PARCHMENT, statW - 8)
		tile.value:SetPoint("CENTER", tile, "CENTER", 0, STAT_VALUE_Y)
		tile.value:SetJustifyH("CENTER")
		if tile.value.SetWordWrap then tile.value:SetWordWrap(false) end
		tile.label = Text(tile, Theme.F_SMALL, Theme.MUTED, statW - 8)
		tile.label:SetPoint("CENTER", tile, "CENTER", 0, STAT_LABEL_Y)
		tile.label:SetJustifyH("CENTER")
		if tile.label.SetWordWrap then tile.label:SetWordWrap(false) end
		tile.key = key
		ns.JournalStatCenter(tile)
		pane.stats[key] = tile
	end

	-- deux colonnes : envies | allure
	local colY = statY - STAT_H - 16
	pane.needsTitle = Theme.CreateSection(pane, "")
	pane.needsTitle:SetWidth(HALF)
	At(pane.needsTitle, content, 0, colY)
	pane.needs = {}
	for index, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do
		local row = Theme.CreateListRow(pane, HALF, EVO_ROW, { detail = true, font = Theme.F_LABEL })
		At(row, content, 0, colY - 26 - (index - 1) * EVO_STEP)
		row:SetIndex(index)
		row.key = key
		row.label, row.value = row.text, row.detail
		row.value:SetWidth(52)
		row.bar = Theme.CreateBar(row, HALF - 120 - 76, 5)
		row.bar:SetPoint("LEFT", row, "LEFT", 120, 0)
		row.shine = row.hover
		row.hover = CreateFrame("Button", nil, row)
		row.hover:SetAllPoints()
		row.hover:SetScript("OnEnter", function(region) row.shine:Show(); ns:ShowNeedTooltip(region, key) end)
		row.hover:SetScript("OnLeave", function() row.shine:Hide(); HideTip() end)
		pane.needs[index] = row
	end

	local rx = HALF + COL_GAP
	pane.looksTitle = Theme.CreateSection(pane, L.JRN_EVO_LOOKS)
	pane.looksTitle:SetWidth(HALF)
	At(pane.looksTitle, content, rx, colY)
	-- apparences : une rangée de vignettes 3D, chevrons pour défiler
	pane.looks = {}
	local arrows = 22
	local lookGap = math.floor((HALF - 2 * arrows - 8 - LOOK_COUNT * LOOK_W) / (LOOK_COUNT - 1))
	pane.lookPrev = Theme.CreateButton(pane, arrows, LOOK_H, "<", function() ns:CompanionLooksScroll(-1) end)
	At(pane.lookPrev, content, rx, colY - 26)
	pane.lookNext = Theme.CreateButton(pane, arrows, LOOK_H, ">", function() ns:CompanionLooksScroll(1) end)
	At(pane.lookNext, content, rx + HALF - arrows, colY - 26)
	for index = 1, LOOK_COUNT do
		local cell = Theme.CreateTile(pane, LOOK_W, LOOK_H, { accent = "top" })
		At(cell, content, rx + arrows + 4 + (index - 1) * (LOOK_W + lookGap), colY - 26)
		local okModel, model = pcall(CreateFrame, "PlayerModel", nil, cell)
		if okModel and model then
			model:SetPoint("TOPLEFT", cell, "TOPLEFT", 2, -2)
			model:SetSize(LOOK_W - 4, LOOK_H - 20)
			cell.model = model
		end
		cell.label = Text(cell, Theme.F_SMALL, Theme.MUTED_LIGHT, LOOK_W - 4)
		cell.label:SetPoint("BOTTOM", cell, "BOTTOM", 0, 4)
		cell.label:SetJustifyH("CENTER")
		if cell.label.SetWordWrap then cell.label:SetWordWrap(false) end
		cell.onEnter = function(c) if c.def then Tip(c, L[c.def.label] or c.def.label, { L.JRN_EVO_LOOK_TIP }) end end
		cell:SetScript("OnLeave", HideTip)
		cell:SetScript("OnClick", function(c)
			if not c.def then return end
			local function Done()
				if ns.CompanionApplyModel then pcall(ns.CompanionApplyModel, ns) end
				ns:RefreshJournal()
			end
			-- confirmation qui compare les effets (CompanionEffects.lua)
			if ns.CompanionAskAppearance then ns:CompanionAskAppearance(c.def.id, Done)
			elseif ns:CompanionSetAppearance(c.def.id) then Done() end
		end)
		pane.looks[index] = cell
	end
	-- cadre et fond : deux listes ; ornements : des bascules
	local ddY = colY - 26 - LOOK_H - 12
	local ddW = math.floor((HALF - 10) / 2)
	pane.frameLabel = Text(pane, Theme.F_CAPS, Theme.MUTED_LIGHT, ddW)
	At(pane.frameLabel, content, rx, ddY)
	pane.frameLabel:SetText(Theme.Upper(L.JRN_EVO_FRAME))
	pane.bgLabel = Text(pane, Theme.F_CAPS, Theme.MUTED_LIGHT, ddW)
	At(pane.bgLabel, content, rx + ddW + 10, ddY)
	pane.bgLabel:SetText(Theme.Upper(L.JRN_EVO_BG))
	pane.frameStyle = Theme.CreateDropdown(pane, ddW, function(value)
		ns:CompanionSetStyle("frame", value); ns:RefreshJournal()
	end, { listWidth = 220 })
	At(pane.frameStyle, content, rx, ddY - 16)
	pane.bgStyle = Theme.CreateDropdown(pane, ddW, function(value)
		ns:CompanionSetStyle("bg", value); ns:RefreshJournal()
	end, { listWidth = 220 })
	At(pane.bgStyle, content, rx + ddW + 10, ddY - 16)
	pane.ornLabel = Text(pane, Theme.F_CAPS, Theme.MUTED_LIGHT, HALF)
	At(pane.ornLabel, content, rx, ddY - 48)
	pane.ornLabel:SetText(Theme.Upper(L.JRN_EVO_ORNS))
	pane.ornTop, pane.ornX = ddY - 64, rx
	pane.orns = {}
	pane.ornNone = Text(pane, Theme.F_SMALL, Theme.MUTED, HALF)
	At(pane.ornNone, content, rx, ddY - 66)
	-- ses effets, sous les envies (CompanionEffects.lua)
	if self.CompanionEffectsBuildPane then self:CompanionEffectsBuildPane(pane, content, 0, colY - 26 - 4 * EVO_STEP - 4, HALF) end
end

-- Collection : sortes en puces, grille d'objets (verrou pour ce qui n'est
-- pas gagné), aperçu à droite
-- Ménagerie : le Pokédex des captures. Grille numérotée (toutes les espèces
-- croisées ; en couleur de rareté celles qui sont capturées), aperçu 3D
-- (Capture.lua, ns:MenagerieList)
local TYPE_ICONS = {
	["Bête"] = "Interface\\Icons\\Ability_Hunter_Pet_Wolf", Beast = "Interface\\Icons\\Ability_Hunter_Pet_Wolf",
	["Humanoïde"] = "Interface\\Icons\\INV_Misc_Head_Human_01", Humanoid = "Interface\\Icons\\INV_Misc_Head_Human_01",
	["Démon"] = "Interface\\Icons\\Spell_Shadow_SummonImp", Demon = "Interface\\Icons\\Spell_Shadow_SummonImp",
	["Draconien"] = "Interface\\Icons\\INV_Misc_Head_Dragon_01", Dragonkin = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
	["Élémentaire"] = "Interface\\Icons\\Spell_Fire_Fire", Elemental = "Interface\\Icons\\Spell_Fire_Fire",
	["Géant"] = "Interface\\Icons\\Spell_Nature_Earthquake", Giant = "Interface\\Icons\\Spell_Nature_Earthquake",
	["Mort-vivant"] = "Interface\\Icons\\Spell_Shadow_RaiseDead", Undead = "Interface\\Icons\\Spell_Shadow_RaiseDead",
	["Mécanique"] = "Interface\\Icons\\INV_Misc_Gear_01", Mechanical = "Interface\\Icons\\INV_Misc_Gear_01",
}
local MEN_DEFAULT_ICON = "Interface\\Icons\\Ability_Hunter_BeastTaming"
ns.MENAGERIE_TYPE_ICONS = TYPE_ICONS

-- 2.11.0 : les étoiles d'une ligne de Créatures : l'étoile dorée du jeu
-- (atlas « auctionhouse-icon-favorite », vérifié en jeu), posée sur sa propre
-- silhouette brun sombre 2 px plus grande (le cerne qui la détache du
-- parchemin) ; vides : désaturées, brun grisé. Construites une fois.
ns.MEN_STAR = { atlas = "auctionhouse-icon-favorite", size = 12, step = 12, outline = 2,
	full = { 1, 0.80, 0.20 }, empty = { 0.62, 0.55, 0.43 }, edge = { 0.23, 0.13, 0.02 }, edgeEmpty = 0.45 }
local function StarTex(row, layer, sub, size)
	local tex = row:CreateTexture(nil, layer, nil, sub)
	tex:SetSize(size, size)
	local ok = ns.AzerothAtlas and ns.AzerothAtlas(tex, ns.MEN_STAR.atlas)
	if not ok then
		ok = pcall(tex.SetAtlas, tex, ns.MEN_STAR.atlas)
		if not ok and ns.CAPTURE_STAR_ICON then tex:SetTexture(ns.CAPTURE_STAR_ICON) end
	end
	tex:Hide()
	return tex
end
local function BuildStars(row)
	local S = ns.MEN_STAR
	row.stars = {}
	for index = 1, (ns.CAPTURE_STAR_MAX or 3) do
		local edge = StarTex(row, "ARTWORK", 1, S.size + S.outline)
		local star = StarTex(row, "ARTWORK", 2, S.size)
		star:SetPoint("LEFT", row, "RIGHT", -150 + (index - 1) * S.step, 0)
		edge:SetPoint("CENTER", star, "CENTER", 0, 0)
		row.stars[index] = { star = star, edge = edge }
	end
end
-- n étoiles pleines (nil : aucune affichée)
function ns.MenagerieRowStars(row, count)
	local S = ns.MEN_STAR
	for index, pair in ipairs(row.stars or {}) do
		if count then
			local full = index <= count
			local c = full and S.full or S.empty
			if pair.star.SetDesaturated then pair.star:SetDesaturated(not full) end
			pair.star:SetVertexColor(c[1], c[2], c[3], 1)
			if pair.edge.SetDesaturated then pair.edge:SetDesaturated(true) end
			pair.edge:SetVertexColor(S.edge[1], S.edge[2], S.edge[3], full and 1 or S.edgeEmpty)
			pair.star.full = full
			pair.star:Show(); pair.edge:Show()
		else
			pair.star:Hide(); pair.edge:Hide()
		end
	end
end

local function BuildMenagerie(self, frame, content)
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.men = pane
	frame.menZone, frame.menState = frame.menZone or "here", frame.menState or "all"
	frame.menRank, frame.menSort, frame.menSearch = frame.menRank or "all", frame.menSort or "no", frame.menSearch or ""
	local function Changed() frame.menOffset = 0; ns:RefreshJournal() end
	-- 1re rangée : zone, rareté, tri
	pane.zone = Theme.CreateDropdown(pane, 200, function(value)
		frame.menZone = value
		ns:JournalRemember("menZoneAll", value == "all" or nil)
		Changed()
	end,
		{ listWidth = 260, maxRows = 14 })
	At(pane.zone, content, 0, TOP)
	pane.rank = Theme.CreateDropdown(pane, 124, function(value) frame.menRank = value; ns:JournalRemember("menRank", value); Changed() end)
	At(pane.rank, content, 210, TOP)
	local ranks = {}
	for _, key in ipairs(MEN_RANKS) do ranks[#ranks + 1] = { value = key, label = L["JRN_MEN_RANK_" .. key] } end
	pane.rank:SetOptions(ranks)
	pane.sort = Theme.CreateDropdown(pane, GRID_W - 344, function(value) frame.menSort = value; ns:JournalRemember("menSort", value); Changed() end)
	At(pane.sort, content, 344, TOP)
	local sorts = {}
	for _, key in ipairs(MEN_SORTS) do sorts[#sorts + 1] = { value = key, label = L["JRN_MEN_SORT_" .. key] } end
	pane.sort:SetOptions(sorts)
	pane.count = Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, PREVIEW_W)
	pane.count:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + INNER, TOP - 4)
	pane.count:SetJustifyH("RIGHT")
	-- 2e rangée : état, recherche
	local rowY = TOP - 32
	pane.stateRow, pane.states = Chips(pane, MEN_STATES, "JRN_MEN_", function(key)
		frame.menState = key
		ns:JournalRemember("menState", key)
		Changed()
	end)
	At(pane.stateRow, content, 0, rowY)
	-- la recherche va jusqu'au bord droit (au-dessus de l'aperçu, qui commence
	-- plus bas) : cinq puces d'état tiennent à côté (1.6.0)
	local searchW = math.max(120, INNER - (pane.stateRow.used or 300) - 12)
	pane.search = Theme.CreateSearchBox(pane, searchW, L.JRN_MEN_SEARCH, function(text)
		frame.menSearch = text or ""
		frame.menOffset = 0
		-- 2.11.0 : vidée : tout de suite ; sinon à la fin de la frappe
		if frame.menSearch == "" then ns:RefreshJournal() else ns:JournalSoon("menSearch") end
	end)
	-- Entrée : la recherche part sans attendre
	if pane.search.HookScript then
		pane.search:HookScript("OnEnterPressed", function() ns:JournalSoon("menSearch"); ns:RefreshJournal() end)
	end
	pane.search:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + INNER, rowY)
	-- 3e rangée (2.4) : boutons de type, « Tous » (MenagerieView.lua)
	local typeH = 0
	if self.MenagerieViewBuild then
		typeH = tonumber(self:MenagerieViewBuild(pane, content, 0, rowY - Theme.CHIP_HEIGHT - 8, frame)) or 0
	end
	-- la liste, façon Pokédex : numéro, type, nom, marques ; la fiche à droite
	pane.items = {}
	local gridTop = rowY - Theme.CHIP_HEIGHT - 12 - (typeH > 0 and typeH + 8 or 0)
	local rowH = MEN_ROW_H
	-- QC 2.0 : bandeau de la collection sous la liste (MenagerieCollection.lua)
	local collH = self.MenagerieCollectionBuild and (tonumber(ns.MENAGERIE_COLLECTION_H) or 0) or 0
	local count = math.floor((gridTop - PAGER_Y - 12 - (collH > 0 and collH + 8 or 0)) / rowH)
	for index = 1, count do
		local row = Theme.CreateListRow(pane, GRID_W, rowH - 2, { kind = "Button", detail = true, detailFont = Theme.F_SMALL })
		At(row, content, 0, gridTop - (index - 1) * rowH)
		row:SetIndex(index)
		row.no = Text(row, Theme.F_SMALL, Theme.MUTED, 50)
		row.no:SetPoint("LEFT", row, "LEFT", 8, 0)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(rowH - 8, rowH - 8)
		row.icon:SetPoint("LEFT", row, "LEFT", 58, 0)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.text:ClearAllPoints()
		row.text:SetPoint("LEFT", row, "LEFT", 58 + rowH - 8 + 8, 0)
		row.text:SetWidth(GRID_W - 58 - rowH - 158)
		row.label = row.text
		-- nom (ou « ??? ») à la couleur de sa rareté, type à droite, et
		-- l'étoile d'une brillante ; capturée : liseré vert à gauche (1.5.1)
		row.detail:ClearAllPoints()
		row.detail:SetPoint("RIGHT", row, "RIGHT", -30, 0)
		-- 2.11.0 : les étoiles à gauche du type (textures, plus de texte)
		row.detail:SetWidth(150 - 30 - 3 * ns.MEN_STAR.step - 4)
		if row.detail.SetJustifyH then row.detail:SetJustifyH("RIGHT") end
		BuildStars(row)
		row.star = Theme.CreateDiamond(row, 8)
		row.star:SetPoint("RIGHT", row, "RIGHT", -12, 0)
		row.star:SetVertexColor(Theme.GOLD_LIGHT[1], Theme.GOLD_LIGHT[2], Theme.GOLD_LIGHT[3], 1)
		row.star:Hide()
		row.caught = Theme.Solid(row, "ARTWORK", Theme.GREEN, 1)
		row.caught:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.caught:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
		row.caught:SetWidth(3)
		row.caught:Hide()
		-- choisie dans la fiche, ou portée : la ligne s'éclaire
		row.mark = Theme.Solid(row, "BORDER", Theme.GOLD, 0.10)
		row.mark:SetAllPoints()
		row.mark:Hide()
		row:HookScript("OnEnter", function(r) if r.entry then ns:JournalPreviewMenagerie(r.entry) end end)
		row:SetScript("OnClick", function(r)
			if not r.entry then return end
			if not ns:JournalMenagerieEquip(r.entry) then ns:JournalPreviewMenagerie(r.entry) end
		end)
		row:Hide()
		pane.items[index] = row
	end
	if collH > 0 then
		self:MenagerieCollectionBuild(pane, content, { x = 0, y = gridTop - count * rowH - 6, w = GRID_W, h = collH })
	end
	Pager(pane, content)
	pane.hint:SetText(L.JRN_MEN_HINT)
	pane.empty = Text(pane, Theme.F_BODY, Theme.MUTED_LIGHT, GRID_W)
	At(pane.empty, content, 0, gridTop - 10)
	if pane.empty.SetWordWrap then pane.empty:SetWordWrap(true) end
	pane.preview = BuildPreview(pane, content, INNER - PREVIEW_W, gridTop, gridTop - PAGER_Y - 12)
	-- normale / brillante : la fiche montre l'une ou l'autre (1.6.0)
	pane.preview.variant = Theme.CreateButton(pane.preview, "auto", 20, L.JRN_MEN_SEE_SHINY, function()
		local preview = frame.men.preview
		preview.shiny = not preview.shiny
		if preview.entry then ns:JournalPreviewMenagerie(preview.entry, true) end
	end)
	pane.preview.variant:SetPoint("TOPRIGHT", pane.preview, "TOPRIGHT", -6, -6)
	pane.preview.variant:Hide()
	-- 2.11.0 : « Localiser » : repère sur la carte, là où l'espèce apparaît
	pane.preview.locate = Theme.CreateButton(pane.preview, "auto", 20, L.JRN_LOCATE or "Localiser", function()
		ns:JournalMenagerieLocate()
	end, "accent")
	pane.preview.locate:SetPoint("TOPLEFT", pane.preview, "TOPLEFT", 6, -6)
	pane.preview.locate:SetScript("OnEnter", function(owner) Tip(owner, L.JRN_LOCATE, { L.JRN_LOCATE_TIP_creature }) end)
	pane.preview.locate:SetScript("OnLeave", HideTip)
	pane.preview.locate:Hide()
end

-- 2.11.0 : le point d'une espèce dans sa zone (ns:ZonePoint), ou nil
local function CreaturePoint(self, entry)
	if not (entry and entry.npc and entry.zoneID and self.ZonePoint) then return nil end
	return self:ZonePoint("creature", entry.zoneID, entry.npc)
end
local function PreviewLocate(self, preview, entry)
	local button = preview and preview.locate
	if not button then return end
	local x = CreaturePoint(self, entry)
	if x and self.MapPinAvailable and self:MapPinAvailable(entry.zoneID) then
		button:SetText(self:MapPinActive("creature:" .. entry.npc) and L.JRN_LOCATE_OFF or L.JRN_LOCATE)
		button:Show()
	else
		button:Hide()
	end
end
function ns:JournalMenagerieLocate()
	local preview = self.journalFrame and self.journalFrame.men and self.journalFrame.men.preview
	local entry = preview and preview.entry
	local x, y = CreaturePoint(self, entry)
	if not x then return false end
	local set = self:MapPinToggle("creature:" .. entry.npc, entry.zoneID, x, y)
	PreviewLocate(self, preview, entry)
	return set
end

-- Missions (2.9.1 : refonte d'après la maquette validée). En haut, une bande
-- résumé : trois plaques sombres (compagnon, jour, semaine) avec leur compte,
-- leurs pastilles et le bonus des 3. À gauche, les missions en CARTES sur
-- deux colonnes (une carte seule, ou la dernière d'un nombre impair, prend
-- toute la largeur) : icône de sa sorte dans un cadre, titre, zone, vraie
-- barre et compte, gains en icônes d'objet (et en clair sur une carte
-- large) ; faite : carte vert clair et tampon « Faite » ; « Changer » devient
-- un petit bouton ↻ dans le coin de la carte du jour ; le bonus des 3 est un
-- encart cadeau en pointillés sous chaque groupe ; la zone du jour et le
-- décompte de la semaine sont des étiquettes à côté des intertitres. À
-- droite, plus compacts : carte des auberges en 7 tampons ronds, garde-manger
-- (compte, Donner), besace de capture (Daily.lua, Weekly.lua, Treats.lua,
-- Capture.lua). Tout est construit une fois puis réutilisé (pas de création
-- au rafraîchissement, sauf les pointillés d'un encart qui grandit).
local MIS = {
	leftW = 420, gap = 16,                         -- colonne des missions, écart avec la droite
	-- 2.11.0 : plaques plus hautes ; ligne 1 titre + compte, détail sur deux
	-- lignes au besoin, pastilles en bas (plus par-dessus le texte)
	sumH = 56, sumGap = 8, sumColGap = 10,        -- bande résumé
	sumCount = 40,                                -- compte, à droite de la ligne 1
	sumTop = 5, sumDetailY = -21, sumDetailH = 24, sumPipY = 5,
	rightGroupH = 22,                             -- intertitres de droite (la bande a grandi)
	cardH = 68, cardGap = 8, cardVGap = 6,        -- cartes : hauteur, écarts
	groupH = 24, groupGap = 8,                    -- intertitre, écart après un groupe
	icon = 30, textX = 52, pad = 8, countW = 44,  -- dans une carte
	swap = 22, reward = 14, calloutMin = 30,
	dash = 10, dashGap = 6,                       -- pointillés des encarts
	stamp = 20, stampStep = 37, cellGap = 4, cellH = 84, aidIcon = 24,
}
MIS.rightX = MIS.leftW + MIS.gap                                        -- 436
MIS.rightW = INNER - MIS.rightX                                         -- 274
MIS.half = math.floor((MIS.leftW - MIS.cardGap) / 2)                    -- 206
MIS.sumW = math.floor((INNER - 2 * MIS.sumColGap) / 3)                  -- 230
ns.JOURNAL_MISSIONS_LAYOUT = MIS
-- rangées : 1 = compagnon (mission 3 du jour), 2-3 = jour (missions 1-2),
-- 4-6 = semaine
local MISSION_GROUPS = {
	{ id = "trait", rows = { { daily = 3 } } },
	{ id = "zone",  rows = { { daily = 1 }, { daily = 2 } }, bonus = "allDaily" },
	{ id = "week",  rows = { { weekly = 1 }, { weekly = 2 }, { weekly = 3 } }, bonus = "allWeekly" },
}
-- 2.9.1 : l'icône d'une sorte de mission (icônes d'objet et de sort du client)
local ICON_DIR = "Interface\\Icons\\"
local KIND_ICON = {
	captures = "Spell_Nature_Web", captureNamed = "Spell_Nature_Web", capNew = "Spell_Nature_Web",
	capNamed = "Spell_Nature_Web", capType = "Spell_Nature_Web", typeCapture = "Spell_Nature_Web",
	shinyKill = "INV_Misc_Gem_Pearl_04", shinyCapture = "INV_Misc_Gem_Pearl_04",
	quests = "INV_Misc_Book_09", turnins = "INV_Misc_Book_09",
	village = "INV_Misc_Map_01", places = "INV_Misc_Map_01", percent = "INV_Misc_Map_01",
	gather = "Trade_Mining", meals = "Spell_Misc_Food",
	kills = "INV_Sword_04", species = "INV_Sword_04", nightKills = "Ability_Stealth",
	elites = "INV_Misc_Head_Dragon_01", named = "INV_Misc_Head_Dragon_01",
	rest = "Spell_Nature_Sleep", pets = "Ability_Hunter_MendPet", talks = "INV_Letter_15",
	calm = "Spell_Holy_DevotionAura", gold = "INV_Misc_Coin_01",
	dailies = "INV_Misc_PocketWatch_01", stamps = "INV_Scroll_03",
}
for kind, name in pairs(KIND_ICON) do KIND_ICON[kind] = ICON_DIR .. name end
local KIND_ICON_DEFAULT = ICON_DIR .. "INV_Misc_QuestionMark"
ns.MISSION_KIND_ICONS = KIND_ICON
function ns.MissionKindIcon(kind) return KIND_ICON[kind or ""] or KIND_ICON_DEFAULT end
-- plaques du résumé, tampons de la carte des auberges (pierre de foyer :
-- l'auberge ; le 7e, le Festin promis)
local SUMMARY_ICON = { trait = ICON_DIR .. "Ability_Hunter_BeastTaming", zone = ICON_DIR .. "INV_Misc_PocketWatch_01",
	week = ICON_DIR .. "Spell_Nature_TimeStop" }
local INN_STAMP_ICON = ICON_DIR .. "INV_Misc_Rune_01"
local INN_GIFT_ICON = ICON_DIR .. "INV_Misc_Food_15"
ns.MISSION_SUMMARY_ICONS, ns.INN_STAMP_ICONS = SUMMARY_ICON, { stamp = INN_STAMP_ICON, gift = INN_GIFT_ICON }
-- couleurs de l'habit Sobre (l'habit Azeroth pose les siennes, mesurées)
-- 2.11.0 (fiche 28) : les teintes du thème lues dans le jeton (mêmes valeurs)
local function Tint(c, alpha) return { c[1], c[2], c[3], alpha } end
local MIS_COLORS = {
	tint = Tint(Theme.GREEN, 0.10),                -- carte faite
	stamp = { 0.12, 0.37, 0.12 },                  -- tampon « Faite » (texte blanc : 7,81:1)
	chipZone = { 0.165, 0.31, 0.54 }, chipTrait = { 0.42, 0.29, 0.10 },   -- étiquettes (blanc : 8,13 / 8,02)
	callout = Tint(Theme.GOLD, 0.06), dash = Tint(Theme.GOLD_SOFT, 0.9),
	pipOn = Theme.GOLD, pipOff = Theme.EDGE,
}
ns.MISSION_COLORS = MIS_COLORS
local REROLL_TIP = {}

local function AidIcon(id)
	for _, def in ipairs(ns.CAPTURE_AIDS or {}) do if def.id == id then return def.icon end end
	return KIND_ICON_DEFAULT
end
local function AidCap(id)
	for _, def in ipairs(ns.CAPTURE_AIDS or {}) do if def.id == id then return def.cap end end
	return 0
end

-- les icônes de ce que rapporte une mission (ns.MISSION_REWARDS[scope]) :
-- friandise (celle de l'envie la plus basse, ou le Festin), aide de capture
local function RewardIcons(self, scope)
	local def = ns.MISSION_REWARDS and ns.MISSION_REWARDS[scope]
	if not def then return nil, nil end
	local treat = def.treat
	if treat == "need" then treat = self.TreatForLowestNeed and self:TreatForLowestNeed() or "bonbon" end
	if treat == "draw" then treat = "bonbon" end
	local treatIcon = treat and ns.TREAT_ICONS and ns.TREAT_ICONS[treat]
	local aidIcon
	if def.aid and self:DB().companionCapture ~= false then
		aidIcon = def.aid == "draw" and KIND_ICON_DEFAULT or AidIcon(def.aid)
	end
	return treatIcon, aidIcon
end
ns.MissionRewardIcons = RewardIcons

-- le bonus en bref : « Festin + Lasso tressé »
local function RewardShort(self, scope)
	local def = ns.MISSION_REWARDS and ns.MISSION_REWARDS[scope]
	if not def then return "" end
	local treat = def.treat == "festin" and self:TreatLabel("festin") or (def.treat and L.MIS_REWARD_TREAT)
	local aid = def.aid and self:DB().companionCapture ~= false
		and (def.aid == "draw" and L.MIS_REWARD_AID or self:CaptureAidLabel(def.aid))
	if treat and aid then return treat .. " + " .. aid end
	return treat or aid or ""
end

-- titre et zone d'une mission : « Capture 2 Démons (Durotar) » ->
-- « Capture 2 Démons » et « Durotar » ; sans zone : « N'importe où »
local function MissionZone(self, mission)
	local info = mission.zoneID and self.MapInfo and self:MapInfo(mission.zoneID)
	return info and info.name or nil
end
local function SplitLabel(label, zone)
	if zone then
		local suffix = " (" .. zone .. ")"
		if #label > #suffix and label:sub(-#suffix) == suffix then return label:sub(1, -#suffix - 1) end
	end
	return label
end

local function Pips(parent, count, anchor, x, y)
	local pips = {}
	for index = 1, count do
		local pip = Theme.Solid(parent, "ARTWORK", MIS_COLORS.pipOff, 1)
		pip:SetSize(14, 5)
		pip:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", x - (count - index) * 17, y)
		pips[index] = pip
	end
	return pips
end

-- une étiquette à côté d'un intertitre (zone du jour, caractère, décompte)
local function GroupChip(pane, section, color)
	local chip = CreateFrame("Frame", nil, section)
	chip:SetSize(40, 15)
	chip:SetPoint("LEFT", section.label, "RIGHT", 8, 0)
	chip.bg = Theme.Solid(chip, "BACKGROUND", color, 1)
	chip.bg:SetAllPoints()
	chip.text = Text(chip, Theme.F_CAPS, Theme.WHITE)
	chip.text:SetPoint("CENTER", chip, "CENTER", 0, 0)
	chip.azSurface = "dark"
	function chip:SetChip(text)
		if not text or text == "" then self.text:SetText(""); self:Hide(); return end
		self.text:SetText(text)
		self:SetWidth(math.ceil(Theme.TextWidth(pane, text, Theme.F_CAPS)) + 12)
		self:Show()
	end
	chip:Hide()
	return chip
end

-- une carte de mission (taille posée à la mise en page : demie ou large)
local function MissionCard(self, pane, slot, group)
	local card = Theme.CreateTile(pane, MIS.half, MIS.cardH, { kind = "Frame" })
	card.slot, card.group, card.cardW = slot, group.id, MIS.half
	card.tint = card:CreateTexture(nil, "BACKGROUND", nil, 3)
	card.tint:SetTexture(Theme.SOLID)
	card.tint:SetAllPoints(card)
	card.tint:SetVertexColor(MIS_COLORS.tint[1], MIS_COLORS.tint[2], MIS_COLORS.tint[3], MIS_COLORS.tint[4])
	card.tint:Hide()
	card.icon = card:CreateTexture(nil, "ARTWORK")
	card.icon:SetSize(MIS.icon, MIS.icon)
	card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -10)
	card.iconEdge = Theme.Border(card, Theme.GOLD_SOFT, 1, "OVERLAY", card.icon)
	card.label = Text(card, Theme.F_LABEL, Theme.LABEL, MIS.half - MIS.textX - MIS.pad)
	if card.label.SetWordWrap then card.label:SetWordWrap(false) end
	if card.label.SetJustifyV then card.label:SetJustifyV("TOP") end
	card.zone = Text(card, Theme.F_SMALL, Theme.MUTED, MIS.half - MIS.textX - MIS.pad)
	card.zone:SetPoint("TOPLEFT", card, "TOPLEFT", MIS.textX, -22)
	if card.zone.SetWordWrap then card.zone:SetWordWrap(false) end
	card.bar = Theme.CreateBar(card, MIS.half - MIS.textX - MIS.pad - MIS.countW - 4, 3)
	card.bar:SetPoint("TOPLEFT", card, "TOPLEFT", MIS.textX, -41)
	card.count = Text(card, Theme.F_NUMBER, Theme.PARCHMENT, MIS.countW)
	card.count:SetPoint("TOPRIGHT", card, "TOPRIGHT", -MIS.pad, -37)
	card.count:SetJustifyH("RIGHT")
	card.rewards = {}
	for index = 1, 2 do
		local icon = card:CreateTexture(nil, "ARTWORK")
		icon:SetSize(MIS.reward, MIS.reward)
		icon:SetPoint("TOPLEFT", card, "TOPLEFT", MIS.textX + (index - 1) * (MIS.reward + 4), -52)
		card.rewards[index] = icon
	end
	-- ce que rapporte la mission, en clair : seulement sur une carte large
	card.source = Text(card, Theme.F_SMALL, Theme.MUTED, MIS.leftW - MIS.textX - 2 * (MIS.reward + 4) - MIS.pad)
	card.source:SetPoint("TOPLEFT", card, "TOPLEFT", MIS.textX + 2 * (MIS.reward + 4) + 2, -52)
	if card.source.SetWordWrap then card.source:SetWordWrap(false) end
	-- tampon « Faite » en haut à droite (vert sombre, texte blanc)
	card.stamp = CreateFrame("Frame", nil, card)
	card.stamp:SetHeight(16)
	card.stamp:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -6)
	card.stamp.bg = Theme.Solid(card.stamp, "BACKGROUND", MIS_COLORS.stamp, 1)
	card.stamp.bg:SetAllPoints()
	card.stamp.check = card.stamp:CreateTexture(nil, "ARTWORK")
	card.stamp.check:SetSize(10, 10)
	card.stamp.check:SetPoint("LEFT", card.stamp, "LEFT", 4, 0)
	local checked, result = pcall(card.stamp.check.SetAtlas, card.stamp.check, "Tracker-Check")
	if not checked or result == false then card.stamp.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready") end
	card.stamp.text = Text(card.stamp, Theme.F_CAPS, Theme.WHITE)
	card.stamp.text:SetPoint("LEFT", card.stamp.check, "RIGHT", 3, 0)
	card.stamp.text:SetText(L.MIS_STAMP)
	card.stamp:SetWidth(math.ceil(Theme.TextWidth(pane, L.MIS_STAMP, Theme.F_CAPS)) + 22)
	card.stamp.azSurface = "dark"
	card.stamp:Hide()
	if slot.daily and group.id == "zone" then
		-- 2.9.1 : « Changer » devient un petit bouton ↻ (même action, une fois par jour)
		local button = CreateFrame("Button", nil, card)
		button:SetSize(MIS.swap, MIS.swap)
		button:SetPoint("TOPRIGHT", card, "TOPRIGHT", -5, -5)
		button.bg = Theme.Solid(button, "BACKGROUND", Theme.NAV, 1)
		button.bg:SetSize(MIS.swap - 6, MIS.swap - 6)
		button.bg:SetPoint("CENTER", button, "CENTER", 0, 0)
		button.border = Theme.Border(button, Theme.EDGE, 1)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetSize(MIS.swap - 6, MIS.swap - 6)
		button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
		button.icon:SetTexture(Theme.REFRESH)
		button:SetScript("OnClick", function() ns:MissionReroll(slot.daily) end)
		button:SetScript("OnEnter", function(b)
			b.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
			REROLL_TIP[1] = L.MIS_REROLL_TIP
			Tip(b, L.MIS_REROLL, REROLL_TIP)
		end)
		button:SetScript("OnLeave", function(b)
			b.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1)
			HideTip()
		end)
		card.reroll = button
	end
	card.tipLines = {}
	if card.EnableMouse then card:EnableMouse(true) end
	card.onEnter = function(c)
		if c.mission and c.fullLabel then Tip(c, c.fullLabel, c.tipLines, "row") end
	end
	card.onLeave = HideTip
	return card
end

-- l'encart cadeau des 3 : fond doré pâle, pointillés, icônes du bonus
local function Callout(pane, scope)
	local box = CreateFrame("Frame", nil, pane)
	box:SetSize(MIS.leftW, MIS.calloutMin)
	box.scope, box.dashes, box.dashColor = scope, {}, MIS_COLORS.dash
	box.bg = box:CreateTexture(nil, "BACKGROUND", nil, 1)
	box.bg:SetTexture(Theme.SOLID)
	box.bg:SetAllPoints(box)
	local c = MIS_COLORS.callout
	box.bg:SetVertexColor(c[1], c[2], c[3], c[4])
	box.icons = {}
	for index = 1, 2 do
		local icon = box:CreateTexture(nil, "ARTWORK")
		icon:SetSize(16, 16)
		icon:SetPoint("LEFT", box, "LEFT", 10 + (index - 1) * 19, 0)
		box.icons[index] = icon
	end
	box.text = Text(box, Theme.F_SMALL, Theme.MUTED_LIGHT, MIS.leftW - 58)
	box.text:SetPoint("TOPLEFT", box, "TOPLEFT", 50, -8)
	if box.text.SetWordWrap then box.text:SetWordWrap(true) end
	return box
end

-- les pointillés d'un encart (réutilisés ; créés seulement s'il en manque)
local function Dashes(box, width, height)
	local used = 0
	local function Dash(x, y, w, h)
		used = used + 1
		local dash = box.dashes[used]
		if not dash then
			dash = box:CreateTexture(nil, "BORDER")
			dash:SetTexture(Theme.SOLID)
			box.dashes[used] = dash
		end
		local c = box.dashColor
		dash:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		dash:ClearAllPoints()
		dash:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
		dash:SetSize(w, h)
		dash:Show()
	end
	local step = MIS.dash + MIS.dashGap
	for x = 0, width - 1, step do
		local w = math.min(MIS.dash, width - x)
		Dash(x, 0, w, 1)
		Dash(x, -(height - 1), w, 1)
	end
	for y = step, height - 2, step do
		local h = math.min(MIS.dash, height - 1 - y)
		Dash(0, -y, 1, h)
		Dash(width - 1, -y, 1, h)
	end
	for index = used + 1, #box.dashes do box.dashes[index]:Hide() end
end
ns.JournalCalloutDashes = Dashes

local function BuildDay(self, frame, content)
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.day = pane
	local rightX, rightW = MIS.rightX, MIS.rightW

	-- bande résumé
	pane.summary = {}
	for index, id in ipairs({ "trait", "zone", "week" }) do
		local plaque = Theme.CreateTile(pane, MIS.sumW, MIS.sumH, { kind = "Frame" })
		At(plaque, content, (index - 1) * (MIS.sumW + MIS.sumColGap), TOP)
		plaque.id = id
		plaque.icon = plaque:CreateTexture(nil, "ARTWORK")
		plaque.icon:SetSize(26, 26)
		plaque.icon:SetPoint("LEFT", plaque, "LEFT", 9, 0)
		plaque.icon:SetTexture(SUMMARY_ICON[id])
		-- libellé à gauche, compte calé à droite avant les pastilles
		plaque.label = Text(plaque, Theme.F_LABEL, Theme.GOLD, MIS.sumW - 44 - MIS.sumCount - MIS.pad - 4)
		plaque.label:SetPoint("TOPLEFT", plaque, "TOPLEFT", 44, -MIS.sumTop)
		if plaque.label.SetWordWrap then plaque.label:SetWordWrap(false) end
		plaque.label:SetText(L["SUM_" .. id])
		plaque.count = Text(plaque, Theme.F_NUMBER, Theme.PARCHMENT, MIS.sumCount)
		plaque.count:SetPoint("TOPRIGHT", plaque, "TOPRIGHT", -MIS.pad, -MIS.sumTop)
		plaque.count:SetJustifyH("RIGHT")
		plaque.detail = Text(plaque, Theme.F_SMALL, Theme.MUTED_LIGHT, MIS.sumW - 44 - MIS.pad)
		plaque.detail:SetPoint("TOPLEFT", plaque, "TOPLEFT", 44, MIS.sumDetailY)
		if plaque.detail.SetWordWrap then plaque.detail:SetWordWrap(true) end
		if plaque.detail.SetMaxLines then pcall(plaque.detail.SetMaxLines, plaque.detail, 2) end
		if plaque.detail.SetHeight then plaque.detail:SetHeight(MIS.sumDetailH) end
		if plaque.detail.SetJustifyV then plaque.detail:SetJustifyV("TOP") end
		-- pastilles en bas, à gauche sous le détail
		local count = id == "trait" and 1 or 3
		plaque.pips = Pips(plaque, count, plaque, 0, 0)
		for index, pip in ipairs(plaque.pips) do
			pip:ClearAllPoints()
			pip:SetPoint("BOTTOMLEFT", plaque, "BOTTOMLEFT", 44 + (index - 1) * 17, MIS.sumPipY)
		end
		plaque.tipLines = {}
		if plaque.EnableMouse then plaque:EnableMouse(true) end
		plaque.onEnter = function(p) Tip(p, L["SUM_" .. p.id], p.tipLines, "below") end
		plaque.onLeave = HideTip
		pane.summary[id] = plaque
		pane.summary[index] = plaque
	end

	-- missions : intertitres, étiquettes, cartes, encarts
	pane.missions, pane.groups, pane.chips, pane.callouts, pane.groupCards = {}, {}, {}, {}, {}
	for _, group in ipairs(MISSION_GROUPS) do
		local title = Theme.CreateSection(pane, L["DAY_GROUP_" .. group.id])
		title:SetWidth(MIS.leftW)
		pane.groups[group.id] = title
		pane.chips[group.id] = GroupChip(pane, title, group.id == "trait" and MIS_COLORS.chipTrait or MIS_COLORS.chipZone)
		local cards = {}
		for _, slot in ipairs(group.rows) do
			local card = MissionCard(self, pane, slot, group)
			cards[#cards + 1] = card
			pane.missions[#pane.missions + 1] = card
		end
		pane.groupCards[group.id] = cards
		if group.bonus then pane.callouts[group.id] = Callout(pane, group.bonus) end
	end
	pane.missionsHint = pane.callouts.zone.text
	pane.weekHint = pane.callouts.week.text

	-- carte des auberges : 7 tampons ronds, compte, règle, cadeaux
	pane.innTitle = Theme.CreateSection(pane, L.INN_TITLE)
	pane.innTitle:SetWidth(rightW)
	pane.innPanel = Theme.CreateTile(pane, rightW, 120, { kind = "Frame" })
	pane.stamps = {}
	for index = 1, ns.INN_CARD or 7 do
		local stamp = pane.innPanel:CreateTexture(nil, "ARTWORK")
		stamp:SetSize(MIS.stamp, MIS.stamp)
		local cx = MIS.pad + 18 + (index - 1) * MIS.stampStep
		stamp:SetPoint("CENTER", pane.innPanel, "TOPLEFT", cx, -26)
		stamp:SetTexture(index == (ns.INN_CARD or 7) and INN_GIFT_ICON or INN_STAMP_ICON)
		pane.stamps[index] = stamp
	end
	local innTextW = rightW - 20
	pane.innTotal = Text(pane.innPanel, Theme.F_LABEL, Theme.LABEL, innTextW)
	pane.innTotal:SetPoint("TOPLEFT", pane.innPanel, "TOPLEFT", 10, -48)
	pane.innHint = Text(pane.innPanel, Theme.F_SMALL, Theme.MUTED_LIGHT, innTextW)
	if pane.innHint.SetWordWrap then pane.innHint:SetWordWrap(true) end
	pane.innGift = Text(pane.innPanel, Theme.F_SMALL, Theme.MUTED, innTextW)
	if pane.innGift.SetWordWrap then pane.innGift:SetWordWrap(true) end
	pane.perfect = Text(pane.innPanel, Theme.F_SMALL, Theme.MUTED, innTextW)
	if pane.perfect.SetWordWrap then pane.perfect:SetWordWrap(true) end

	-- garde-manger : une case par friandise (icône, compte, Donner)
	pane.pantryTitle = Theme.CreateSection(pane, L.DAY_PANTRY)
	pane.pantryTitle:SetWidth(rightW)
	pane.pantryPanel = Theme.CreateTile(pane, rightW, 120, { kind = "Frame" })
	pane.pantryHint = Text(pane.pantryPanel, Theme.F_SMALL, Theme.MUTED, innTextW)
	pane.pantryHint:SetPoint("TOPLEFT", pane.pantryPanel, "TOPLEFT", 10, -8)
	if pane.pantryHint.SetWordWrap then pane.pantryHint:SetWordWrap(true) end
	pane.slots = {}
	local count = #(ns.TREAT_KINDS or {})
	local cellW = count > 0 and math.floor((rightW - 2 * MIS.pad - (count - 1) * MIS.cellGap) / count) or rightW
	MIS.cellW = cellW
	for index, kind in ipairs(ns.TREAT_KINDS or {}) do
		local slot = CreateFrame("Frame", nil, pane.pantryPanel)
		slot:SetSize(cellW, MIS.cellH)
		slot.kind, slot.slotX = kind, MIS.pad + (index - 1) * (cellW + MIS.cellGap)
		slot.icon = slot:CreateTexture(nil, "ARTWORK")
		slot.icon:SetSize(28, 28)
		slot.icon:SetPoint("TOP", slot, "TOP", 0, -6)
		slot.icon:SetTexture(ns.TREAT_ICONS[kind])
		slot.count = Text(slot, Theme.F_LABEL, Theme.PARCHMENT, cellW)
		slot.count:SetPoint("TOP", slot, "TOP", 0, -45)
		slot.count:SetJustifyH("CENTER")
		slot.give = Theme.CreateButton(slot, cellW - 2, 18, L.DAY_GIVE, function() ns:TreatGive(kind); ns:RefreshJournal() end)
		slot.give:SetPoint("BOTTOM", slot, "BOTTOM", 0, 2)
		if slot.give.text and slot.give.text.SetFontObject then slot.give.text:SetFontObject(Theme.F_SMALL) end
		if slot.EnableMouse then slot:EnableMouse(true) end
		slot:SetScript("OnEnter", function(s)
			Tip(s, ns:TreatLabel(s.kind), { L["TREAT_DESC_" .. s.kind], ns:F("TREAT_COUNT", ns:TreatCount(s.kind), ns:TreatCap(s.kind)) })
		end)
		slot:SetScript("OnLeave", HideTip)
		pane.slots[index] = slot
	end

	-- besace de capture : les trois aides et leur nombre
	pane.aidTitle = Theme.CreateSection(pane, L.DAY_AIDS)
	pane.aidTitle:SetWidth(rightW)
	pane.aidPanel = Theme.CreateTile(pane, rightW, 60, { kind = "Frame" })
	pane.aids = {}
	local aids = ns.CAPTURE_AIDS or {}
	local aidW = #aids > 0 and math.floor((rightW - 2 * MIS.pad - (#aids - 1) * MIS.cellGap) / #aids) or rightW
	MIS.aidW = aidW
	for index, aid in ipairs(aids) do
		local tile = CreateFrame("Frame", nil, pane.aidPanel)
		tile:SetSize(aidW, 40)
		tile.aid, tile.slotX = aid.id, MIS.pad + (index - 1) * (aidW + MIS.cellGap)
		tile:SetPoint("TOPLEFT", pane.aidPanel, "TOPLEFT", tile.slotX, -MIS.pad)
		tile.icon = tile:CreateTexture(nil, "ARTWORK")
		tile.icon:SetSize(MIS.aidIcon, MIS.aidIcon)
		tile.icon:SetPoint("TOPLEFT", tile, "TOPLEFT", 2, -2)
		tile.icon:SetTexture(aid.icon)
		tile.count = Text(tile, Theme.F_LABEL, Theme.PARCHMENT, aidW - 32)
		tile.count:SetPoint("TOPLEFT", tile, "TOPLEFT", 32, 0)
		tile.name = Text(tile, Theme.F_SMALL, Theme.MUTED_LIGHT, aidW - 32)
		tile.name:SetPoint("TOPLEFT", tile, "TOPLEFT", 32, -16)
		if tile.name.SetWordWrap then tile.name:SetWordWrap(true) end
		if tile.EnableMouse then tile:EnableMouse(true) end
		tile:SetScript("OnEnter", function(t)
			Tip(t, ns:CaptureAidLabel(aid.id), { L["CAPTURE_AID_DESC_" .. aid.id], L.DAY_AIDS_HINT })
		end)
		tile:SetScript("OnLeave", HideTip)
		pane.aids[index] = tile
	end
end

-- taille et contenu d'une carte selon sa largeur et son état
local function SizeCard(card, width)
	if card.cardW ~= width then
		card:SetWidth(width)
		card.cardW = width
		card.bar:SetWidth(width - MIS.textX - MIS.pad - MIS.countW - 4)
	end
	card.label:ClearAllPoints()
	if card.empty then
		card.label:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
		card.label:SetWidth(width - 24)
		card.label:SetHeight(MIS.cardH - 20)
		if card.label.SetWordWrap then card.label:SetWordWrap(true) end
		if card.label.SetMaxLines then pcall(card.label.SetMaxLines, card.label, 3) end
		card.source:Hide()
		return
	end
	card.label:SetPoint("TOPLEFT", card, "TOPLEFT", MIS.textX, -7)
	-- le titre s'arrête avant le tampon « Faite » ou le bouton ↻ ; faite sur
	-- une demie carte : le titre peut tenir sur deux lignes, à la place de la
	-- zone (elle reste dans l'infobulle)
	local right = MIS.pad
	if card.stamp:IsShown() then right = card.stamp:GetWidth() + 10
	elseif card.reroll and card.reroll:IsShown() then right = MIS.swap + 9 end
	local twoLines = card.stamp:IsShown() and width < MIS.leftW
	if card.label.SetWordWrap then card.label:SetWordWrap(twoLines) end
	if card.label.SetMaxLines then pcall(card.label.SetMaxLines, card.label, twoLines and 2 or 1) end
	card.label:SetHeight(twoLines and 30 or 15)   -- borne aussi sans SetMaxLines : pas sur la barre
	if twoLines then card.zone:Hide() else card.zone:Show() end
	card.label:SetWidth(width - MIS.textX - right)
	-- la zone passe sous le tampon, pas sous le bouton ↻ (plus haut)
	card.zone:SetWidth(width - MIS.textX - (card.reroll and card.reroll:IsShown() and right or MIS.pad))
	-- le gain en clair, s'il y a la place (carte large)
	if width >= MIS.leftW and (card.source:GetText() or "") ~= "" then card.source:Show() else card.source:Hide() end
end
ns.JournalSizeMissionCard = SizeCard

-- place un groupe : intertitre, cartes (deux par rangée ; seule ou dernière
-- d'un nombre impair : toute la largeur), encart ; rend le y suivant
local function PlaceGroup(pane, content, id, y)
	At(pane.groups[id], content, 0, y)
	y = y - MIS.groupH
	local cards, shown = pane.groupCards[id], 0
	for _, card in ipairs(cards) do if card:IsShown() then shown = shown + 1 end end
	local col, index = 0, 0
	for _, card in ipairs(cards) do
		if card:IsShown() then
			index = index + 1
			local wide = shown == 1 or (index == shown and shown % 2 == 1)
			card.wide = wide
			if wide then
				if col == 1 then y = y - MIS.cardH - MIS.cardVGap; col = 0 end
				SizeCard(card, MIS.leftW)
				At(card, content, 0, y)
				y = y - MIS.cardH - MIS.cardVGap
			else
				SizeCard(card, MIS.half)
				At(card, content, col * (MIS.half + MIS.cardGap), y)
				if col == 1 then y = y - MIS.cardH - MIS.cardVGap; col = 0 else col = 1 end
			end
		end
	end
	if col == 1 then y = y - MIS.cardH - MIS.cardVGap end
	local box = pane.callouts[id]
	if box and box:IsShown() then
		local textH = Theme.TextHeight(box.text, MIS.leftW - 58, Theme.F_SMALL)
		local h = math.max(MIS.calloutMin, math.ceil(textH) + 16)
		if box.boxH ~= h then
			box:SetHeight(h)
			box.boxH = h
			Dashes(box, MIS.leftW, h)
		end
		box.text:ClearAllPoints()
		box.text:SetPoint("TOPLEFT", box, "TOPLEFT", 50, -math.floor((h - textH) / 2))
		At(box, content, 0, y)
		y = y - h
	else
		y = y + MIS.cardVGap
	end
	return y - MIS.groupGap
end

-- met en page les Missions (textes de longueur variable)
local function LayoutDay(pane, content)
	local y = TOP - MIS.sumH - MIS.sumGap
	for _, group in ipairs(MISSION_GROUPS) do y = PlaceGroup(pane, content, group.id, y) end
	pane.missionsBottom = y + MIS.groupGap
	-- colonne de droite
	local rightX, w = MIS.rightX, MIS.rightW - 20
	y = TOP - MIS.sumH - MIS.sumGap
	At(pane.innTitle, content, rightX, y)
	y = y - MIS.rightGroupH
	local inner = 48 + Theme.TextHeight(pane.innTotal, w, Theme.F_LABEL) + 4
	for _, fs in ipairs({ pane.innHint, pane.innGift, pane.perfect }) do
		local h = Theme.TextHeight(fs, w, Theme.F_SMALL)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", pane.innPanel, "TOPLEFT", 10, -inner)
		if h > 0 then inner = inner + h + 4 end
	end
	pane.innPanel:SetHeight(inner + 4)
	At(pane.innPanel, content, rightX, y)
	y = y - inner - 4 - MIS.groupGap
	At(pane.pantryTitle, content, rightX, y)
	y = y - MIS.rightGroupH
	local hint = Theme.TextHeight(pane.pantryHint, w, Theme.F_SMALL)
	local cellsY = 8 + hint + 4
	for _, slot in ipairs(pane.slots) do
		slot:ClearAllPoints()
		slot:SetPoint("TOPLEFT", pane.pantryPanel, "TOPLEFT", slot.slotX, -cellsY)
	end
	pane.pantryPanel:SetHeight(cellsY + MIS.cellH + 4)
	At(pane.pantryPanel, content, rightX, y)
	y = y - cellsY - MIS.cellH - 4 - MIS.groupGap
	At(pane.aidTitle, content, rightX, y)
	y = y - MIS.rightGroupH
	local tallest = MIS.aidIcon + 4
	for _, tile in ipairs(pane.aids) do
		local h = 16 + Theme.TextHeight(tile.name, MIS.aidW - 32, Theme.F_SMALL)
		if h > tallest then tallest = h end
	end
	for _, tile in ipairs(pane.aids) do tile:SetHeight(tallest) end
	pane.aidPanel:SetHeight(tallest + 2 * MIS.pad)
	At(pane.aidPanel, content, rightX, y)
	pane.pantryBottom = y - tallest - 2 * MIS.pad
end

-- Garde-manger dans le pied : un clic donne la friandise
local function BuildPantry(self, frame)
	if not ns.TREAT_KINDS or not frame.footer then return end
	local foot = frame.footer
	frame.pantry = {}
	frame.pantryLabel = Text(foot, Theme.F_CAPS, Theme.MUTED_LIGHT)
	frame.pantryLabel:SetPoint("LEFT", foot, "LEFT", PAD, 0)
	frame.pantryLabel:SetText(Theme.Upper(L.DAY_PANTRY))
	local x = PAD + math.ceil(Theme.TextWidth(foot, Theme.Upper(L.DAY_PANTRY), Theme.F_CAPS)) + 14
	for _, kind in ipairs(ns.TREAT_KINDS) do
		local button = CreateFrame("Button", nil, foot)
		button:SetSize(30, 30)
		button:SetPoint("LEFT", foot, "LEFT", x, 0)
		button.border = Theme.Border(button, Theme.EDGE, 1)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		button.icon:SetTexture(ns.TREAT_ICONS[kind])
		button.count = Theme.Text(button, Theme.F_NUMBER, Theme.PARCHMENT)
		button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
		button.kind = kind
		button:SetScript("OnClick", function(b) if ns.TreatGive then ns:TreatGive(b.kind); ns:RefreshJournal() end end)
		button:SetScript("OnEnter", function(b)
			b.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
			Tip(b, ns:TreatLabel(b.kind), { L["TREAT_DESC_" .. b.kind], ns:F("TREAT_COUNT", ns:TreatCount(b.kind), ns:TreatCap(b.kind)) }, "above")
		end)
		button:SetScript("OnLeave", function(b)
			b.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1)
			HideTip()
		end)
		frame.pantry[kind] = button
		x = x + 30 + 8
	end
end

-- 2.9.1 : la roue crantée du carnet, comme celle du journal de quêtes du
-- client (et des addons qui la reprennent) : une roue grise, sans cadre doré,
-- désaturée et estompée au repos, plus claire au survol. Atlas du client
-- (UiTextureAtlasMember du build 1.60.1) : « questlog-icon-setting » (15×16),
-- sinon « gm-icon-settings » (40×40), sinon le fichier UI-OptionsButton.
ns.JOURNAL_COG = { atlases = { "questlog-icon-setting", "gm-icon-settings" },
	file = "Interface\\Buttons\\UI-OptionsButton", size = 16,
	rest = { 0.78, 0.78, 0.78, 0.85 }, hover = { 1, 1, 1, 1 } }
local function CogPaint(button, hot)
	local icon, cog = button.icon, ns.JOURNAL_COG
	local c = hot and cog.hover or cog.rest
	if icon.SetDesaturated then pcall(icon.SetDesaturated, icon, true) end
	icon:SetVertexColor(c[1], c[2], c[3])
	icon:SetAlpha(c[4])
	button.cogHot = hot and true or false
end
function ns.JournalCogSkin(button)
	if not (button and button.icon) then return nil end
	local icon, cog = button.icon, ns.JOURNAL_COG
	local has = ns.AzerothHasAtlas or function() return false end
	local chosen
	for _, name in ipairs(cog.atlases) do
		if has(name) and ns.AzerothAtlas and ns.AzerothAtlas(icon, name) then chosen = name; break end
	end
	if not chosen then
		icon:SetTexture(cog.file)
		if icon.SetTexCoord then icon:SetTexCoord(0, 1, 0, 1) end
		chosen = cog.file
	end
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	icon:SetSize(cog.size, cog.size)
	-- pas de carré au trait autour (la référence n'en a pas)
	if button.border then
		for _, side in ipairs({ "top", "bottom", "left", "right" }) do
			local edge = button.border[side]
			if edge and edge.Hide then edge:Hide() end
		end
		button.border.SetColor = function() end
	end
	button.cogTexture = chosen
	local enter, leave = button:GetScript("OnEnter"), button:GetScript("OnLeave")
	button:SetScript("OnEnter", function(self, ...)
		if enter then enter(self, ...) end
		CogPaint(self, true)
	end)
	button:SetScript("OnLeave", function(self, ...)
		if leave then leave(self, ...) end
		CogPaint(self, false)
	end)
	CogPaint(button, false)
	return chosen
end

function ns:EnsureJournalWindow()
	if self.journalFrame then return self.journalFrame end
	if not Theme or not Theme.CreateWindow then return nil end
	-- 2.10.0 : un nom global par style (et plus de préfixe Ready2Quest), sinon Échap vise la fenêtre de l'autre style restée en cache
	local style = (self.JournalStyle and self:JournalStyle()) or "sobre"
	local name = style == "azeroth" and "QuestCompanionJournalFrameAzeroth" or "QuestCompanionJournalFrame"
	local frame = Theme.CreateWindow(UIParent, WIDTH, HEIGHT, { name = name, nav = NAV_W, footer = FOOTER_H })
	if not frame then return nil end
	frame.chrome = "journal"
	if self.RestorePoint then self:RestorePoint(frame, "journalPoint", { point = "CENTER", x = 0, y = 20 }) end
	frame.kind, frame.activity, frame.offset = "evolution", "explore", 0
	frame.zoneFilter, frame.zoneSort, frame.zoneOffset = "all", "lvl", 0
	frame.questFilter, frame.collKind = "all", "app"
	self:JournalRestoreState(frame)
	local content, nav = frame.content, frame.nav

	-- navigation : marque, une entrée par page, le total du carnet en bas
	frame.brand = Theme.CreateNavBrand(nav, Theme.LOGO, L.JRN_TITLE)
	frame.brand:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -8)
	frame.brand:SetWidth(NAV_W)
	frame.title = frame.brand.name
	frame.navGroup = Theme.CreateNavGroup(nav, L.JRN_NAV_GROUP)
	frame.navGroup:SetPoint("TOPLEFT", nav, "TOPLEFT", 18, -92)
	frame.sections = {}
	local y = -112
	for _, section in ipairs(SECTIONS) do
		local external = ns.JOURNAL_PANES[section]
		local builtin = section == "evolution" or (section == "day" and self.DailyData) or (section == "menagerie" and self.MenagerieList)
		if external or builtin then
			local item = Theme.CreateNavItem(nav, NAV_W - 1)
			item:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, y)
			item:SetText(L["JRN_SEC_" .. section])
			item.section = section
			item:SetScript("OnClick", function() ns:SelectJournalKind(section) end)
			frame.sections[section] = item
			y = y - Theme.NAV_ITEM_HEIGHT
		end
	end
	frame.subtitle = Text(nav, Theme.F_SMALL, Theme.MUTED_LIGHT, NAV_W - 36)
	frame.subtitle:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 18, 18)
	-- 2.11.0 : sous les entrées, trois blocs qui résument (fiche 14)
	frame.navY = y
	self:JournalNavSummaryBuild(frame)

	-- en-tête de page : titre et sous-titre de la page choisie
	frame.header = Theme.CreatePageHeader(content, CONTENT_W)
	frame.header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	frame.header.title:SetWidth(INNER - 100)
	if frame.header.title.SetWordWrap then frame.header.title:SetWordWrap(false) end
	frame.header.subtitle:SetWidth(INNER)
	if frame.header.subtitle.SetWordWrap then frame.header.subtitle:SetWordWrap(false) end

	BuildEvolution(self, frame, content)
	if self.MenagerieList then BuildMenagerie(self, frame, content) end
	if self.DailyData then BuildDay(self, frame, content) end
	for section, def in pairs(ns.JOURNAL_PANES) do
		local ok, err = pcall(def.build, self, frame, content, ns.JournalUI)
		if not ok and self.RecordError then self:RecordError("journal:" .. section, err) end
	end
	BuildPantry(self, frame)

	if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
	frame:SetScript("OnMouseWheel", function(_, delta) ns:ScrollJournal(delta) end)
	-- Roue crantée dans l'en-tête, à gauche du × : les réglages de l'addon
	if Theme.CreateGearButton and frame.close then
		frame.settingsButton = Theme.CreateGearButton(frame, 22, function() ns:ToggleOptions() end, L.JRN_SETTINGS_TIP)
		frame.settingsButton:SetPoint("RIGHT", frame.close, "LEFT", -8, 0)
		ns.JournalCogSkin(frame.settingsButton)
		frame.settingsButton:Show()
		if frame.settingsButton.SetFrameLevel and frame.close.GetFrameLevel then
			frame.settingsButton:SetFrameLevel(tonumber(frame.close:GetFrameLevel()) or 20)
		end
	end
	frame.closeButton = Theme.CreateButton(frame.footer, "auto", 28, L.OPT_CLOSE, function() frame:Hide() end, "accent")
	frame.closeButton:SetPoint("RIGHT", frame.footer, "RIGHT", -PAD, 0)
	frame:Hide()
	self.journalFrame = frame
	return frame
end


-- ---------------------------------------------------------------------------
-- Navigation
-- ---------------------------------------------------------------------------
-- « goals » / « evolution » : Créature ; « zones », « completion » : la
-- Complétion ; tout le reste (« memories » d'avant la 2.6.0 compris) : Créature
local function KindOf(frame, kind)
	local external = ns.JOURNAL_PANES[kind]
	if external and frame[external.field] then return kind end
	-- anciens noms (Zones, Zone, Collection, Jour) : leur page d'aujourd'hui
	local progress = ns.JOURNAL_PANES.progress
	if (kind == "zones" or kind == "completion") and progress and frame[progress.field] then return "progress" end
	if kind == "day" and frame.day then return "day" end
	if kind == "menagerie" and frame.men then return "menagerie" end
	return "evolution"
end

function ns:SelectJournalKind(kind)
	local frame = self:EnsureJournalWindow()
	if not frame then return end
	frame.kind = KindOf(frame, kind)
	frame.offset = 0
	self:DB().journalTab = frame.kind
	self:RefreshJournal()
end

-- Une zone dans la Complétion (objectif du suivi, liste des zones)
function ns:SelectJournalZone(zoneID) return self:OpenJournalZone(zoneID) end

function ns:OpenJournalZone(zoneID)
	local frame = self:EnsureJournalWindow()
	if not frame then return end
	frame.zoneID, frame.zonePicked = tonumber(zoneID), true
	self:SelectJournalKind("completion")
end

-- Molette : une rangée de la grille ou de la liste affichée
function ns:ScrollJournal(delta)
	local frame = self.journalFrame
	if not frame then return end
	delta = tonumber(delta) or 0
	if frame.kind == "menagerie" then
		frame.menOffset = (frame.menOffset or 0) - delta * 3
	elseif ns.JOURNAL_PANES[frame.kind] then
		local def = ns.JOURNAL_PANES[frame.kind]
		if def.scroll then def.scroll(self, frame, delta) end
	else
		frame.offset = (frame.offset or 0) - delta * (frame.step or 1)
	end
	-- un cran de molette ne change aucune donnée : les pages reprennent la
	-- liste de leur dernier rafraîchissement complet (frame.scrollOnly) au
	-- lieu de tout recalculer (Progression : toutes les zones du jeu)
	frame.scrollOnly = true
	local ok, err = pcall(self.RefreshJournal, self)
	frame.scrollOnly = nil
	if not ok then error(err, 0) end
end

-- ---------------------------------------------------------------------------
-- Aperçus
-- ---------------------------------------------------------------------------
-- Catalogue d'une sorte de cosmétique : { kind, def, owned, equipped, label, tier }
local CATALOG = { app = "COMPANION_APPEARANCES", orn = "COMPANION_ORNAMENTS", frame = "COMPANION_FRAMES",
	bg = "COMPANION_BACKGROUNDS" }
function ns:JournalCollection(kind)
	local list = {}
	local data = self:CompanionData()
	local current = {
		app = data.appearance,
		frame = self.CompanionCurrentStyle and self:CompanionCurrentStyle("frame").id,
		bg = self.CompanionCurrentStyle and self:CompanionCurrentStyle("bg").id,
	}
	-- les créatures capturées vivent dans la Ménagerie : ici, les cosmétiques
	local catalog = ns[CATALOG[kind]] or {}
	for _, def in ipairs(catalog) do
		local owned = self:CompanionIsUnlocked(kind, def)
		local equipped
		if kind == "orn" then equipped = owned and self:CompanionOrnamentShown(def)
		else equipped = current[kind] == def.id end
		list[#list + 1] = { kind = kind, def = def, owned = owned, equipped = equipped and true or false,
			label = L[def.label] or def.id, tier = tonumber(def.tier) or 0 }
	end
	return list
end

function ns:JournalCosmeticSource(entry)
	if entry.def.captured then
		local when = entry.def.at and rawget(_G, "date") and select(2, pcall(date, "%d/%m/%Y", entry.def.at))
		return self:F("CAPTURE_SRC", tostring(when or "?"))
	end
	if entry.tier >= 1 then return self:F("JRN_COLL_SRC_TIER", entry.tier) end
	if entry.def.unlock and self.CompanionRequirement then
		local ok, text = pcall(self.CompanionRequirement, self, entry.def.unlock)
		if ok and type(text) == "string" and text ~= "" then return text end
	end
	return L.JRN_COLL_SRC_BASE
end

-- ---------------------------------------------------------------------------
-- Rafraîchissement
-- ---------------------------------------------------------------------------
-- Jours passés ensemble : depuis le premier passage par cette page (la
-- reprise de la 2.6.0, Core.lua, l'a recalé sur le plus vieux souvenir)
function ns:CompanionSince()
	local data = self:CompanionData()
	if not tonumber(data.since) then
		data.since = tonumber((select(2, pcall(rawget(_G, "time") or function() return 0 end)))) or 0
	end
	return tonumber(data.since)
end

function ns:CompanionDaysTogether()
	local since = self:CompanionSince() or 0
	local okNow, now = pcall(rawget(_G, "time") or function() return 0 end)
	now = okNow and tonumber(now) or 0
	if since <= 0 or now <= 0 then return 1 end
	return math.max(1, math.floor((now - since) / 86400) + 1)
end

-- Vignettes d'apparence : défilement d'une à la fois
function ns:CompanionLooksScroll(delta)
	local frame = self.journalFrame
	if not frame then return end
	frame.lookOffset = (frame.lookOffset or 0) + (tonumber(delta) or 0)
	self:RefreshJournal()
end

local function PaintLook(cell, def, worn)
	cell.def = def
	cell.label:SetText(L[def.label] or def.label)
	-- le modèle n'est rechargé que s'il change (sinon l'animation repart à
	-- chaque rafraîchissement)
	local key = tostring(def.display) .. ":" .. tostring(def.npc) .. (def.shiny and ":s" or "")
	if cell.model and ns.ShowModel then
		-- 2.11.0 : chargeur unique, profil « cell » (ne recharge pas un modèle affiché)
		cell.lookKey = key
		ns.ShowModel(cell.model, { display = def.display, npc = def.npc, shiny = def.shiny }, "cell")
	elseif cell.model and cell.lookKey ~= key then
		cell.lookKey = key
		local shown = false
		if def.display and cell.model.SetDisplayInfo then shown = pcall(cell.model.SetDisplayInfo, cell.model, def.display) end
		if not shown and def.npc and cell.model.SetCreature then shown = pcall(cell.model.SetCreature, cell.model, def.npc) end
		if shown and ns.ModelShinyLight then ns.ModelShinyLight(cell.model, def.shiny) end
		if shown then cell.model:Show() else cell.model:Hide() end
	end
	local rarity = def.captured and ns.CAPTURE_RARITY and ns.CAPTURE_RARITY[def.class or "normal"]
	cell:SetAccent(worn and Theme.GOLD or (def.shiny and Theme.GOLD_LIGHT) or (rarity and rarity.color) or nil)
	cell:SetSelected(worn)
	cell:Show()
end

local function RefreshEvolution(self, frame)
	local pane = frame.evo
	local content = frame.content
	local stages = ns.COMPANION_STAGES or {}
	local data = self.CompanionData and self:CompanionData() or { needs = {} }
	local stage = self.CompanionStage and self:CompanionStage() or 1
	local name = self.CompanionName and self:CompanionName() or "?"
	local stageLabel = (self.CompanionStageLabel and self:CompanionStageLabel(stage)) or ""
	frame.header:SetTitle(name)
	pane.stage:SetText(L.JRN_SUB_companion)
	local hero = pane.hero
	if hero.portrait and hero.portrait.Refresh then hero.portrait:Refresh(self) end
	pane.name:SetText(name)
	local trait = self.CompanionTrait and self:CompanionTrait()
	local traitLabel = trait and self.PersonaLabel and self:PersonaLabel(trait)
	if traitLabel and traitLabel ~= "" then pane.traitTag:SetTag(traitLabel); pane.traitTag:Show() else pane.traitTag:Hide() end
	local app = self.CompanionCurrentAppearance and self:CompanionCurrentAppearance()
	pane.look:SetText(self:F("JRN_EVO_STAGE", app and tostring(L[app.label]) or name, stageLabel, stage, #stages))
	for index, step in ipairs(pane.steps) do
		local reached = index <= stage
		step:SetTexture(reached and Theme.DIAMOND or Theme.DIAMOND_LINE)
		local c = reached and Theme.GOLD or Theme.MUTED
		step:SetVertexColor(c[1], c[2], c[3], 1)
	end
	local unitLevel = rawget(_G, "UnitLevel")
	local ok, rawLevel = pcall(unitLevel or function() return 1 end, "player")
	local level = tonumber(ok and ns.Plain(rawLevel)) or 1
	local nextStage = stages[stage + 1]
	if data.stageReady and stages[data.stageReady] then
		pane.next:SetText(self:F("JRN_EVO_NEXT_READY", L[stages[data.stageReady].label]))
		pane.next:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	elseif nextStage then
		pane.next:SetText(self:F("JRN_EVO_NEXT_LEVEL", L[nextStage.label], nextStage.level, level))
		pane.next:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3])
	else
		pane.next:SetText(L.JRN_EVO_MAX)
		pane.next:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	end
	-- sa dernière bulle ; à défaut, un mot de repos de son réservoir
	-- (tirée une seule fois : chaque tirage remplit la mémoire anti-répétition)
	local said = self.companionBubbleText
	if not said and not pane.bubbleLine and self.CompanionPick then
		local key = self:CompanionPick("IDLE")
		said = key and L[key] or nil
	end
	pane.bubbleLine = said or pane.bubbleLine or L.JRN_EVO_QUIET
	pane.bubble.text:SetText(pane.bubbleLine)
	local pending = self.ChestPending and #self:ChestPending() or 0
	if pending > 0 then pane.openChest:Show() else pane.openChest:Hide() end

	-- chiffres
	local values = {
		captures = self.CaptureData and self:CaptureData().count or 0,
		shiny = self.ShinyData and self:ShinyData().count or 0,
		days = self:CompanionDaysTogether(),
		missions = math.floor(tonumber(data.missionsDone) or 0),
		km = self.TravelText and self:TravelText() or "-",
	}
	for key, tile in pairs(pane.stats) do
		tile.value:SetText(tostring(values[key]))
		tile.label:SetText(L["JRN_EVO_STAT_" .. key])
	end

	local happyMin = ns.COMPANION_HAPPY_MIN or 70
	SectionText(pane.needsTitle, self:F("JRN_EVO_NEEDS", happyMin))
	for _, row in ipairs(pane.needs) do
		local value = math.floor(tonumber(data.needs and data.needs[row.key]) or 0)
		row.label:SetText(L["COMP_NEED_" .. row.key] or row.key)
		row.bar:SetValue(value / 100)
		local c = value >= happyMin and Theme.GOLD or Theme.MUTED
		row.bar:SetColor(c[1], c[2], c[3], 1)
		row.value:SetText(value .. " %")
		local vc = value >= happyMin and Theme.GOLD or Theme.LABEL
		row.value:SetTextColor(vc[1], vc[2], vc[3])
	end

	-- allure : les apparences portables (mascottes gagnées, puis la ménagerie)
	local looks = self.CompanionUnlockedAppearances and self:CompanionUnlockedAppearances() or {}
	SectionText(pane.looksTitle, L.JRN_EVO_LOOKS .. " (" .. self:F("JRN_EVO_LOOKS_COUNT", #looks) .. ")")
	local maxOffset = math.max(0, #looks - LOOK_COUNT)
	if frame.lookOffset == nil then
		-- la première fois : la portée en vue
		for index, def in ipairs(looks) do if app and def.id == app.id then frame.lookOffset = index - 1 end end
	end
	frame.lookOffset = math.max(0, math.min(frame.lookOffset or 0, maxOffset))
	for index, cell in ipairs(pane.looks) do
		local def = looks[index + frame.lookOffset]
		if def then PaintLook(cell, def, app and def.id == app.id) else cell.def = nil; cell:Hide() end
	end
	if frame.lookOffset > 0 then pane.lookPrev:Show() else pane.lookPrev:Hide() end
	if frame.lookOffset < maxOffset then pane.lookNext:Show() else pane.lookNext:Hide() end
	if self.CompanionChoices then
		pane.frameStyle:SetOptions(self:CompanionChoices("frame"))
		pane.frameStyle:SetValue(self:CompanionCurrentStyle("frame").id)
		pane.bgStyle:SetOptions(self:CompanionChoices("bg"))
		pane.bgStyle:SetValue(self:CompanionCurrentStyle("bg").id)
	end
	-- ornements gagnés : une bascule chacun, à la ligne quand la place manque
	local x, y, count = 0, 0, 0
	for _, def in ipairs(ns.COMPANION_ORNAMENTS or {}) do
		if self:CompanionIsUnlocked("orn", def) then
			count = count + 1
			local button = pane.orns[count]
			if not button then
				button = Theme.CreateButton(pane, "auto", 20, "", nil)
				pane.orns[count] = button
			end
			local label = L[def.label] or def.id
			button.text:SetText(label)
			button:SetWidth(Theme.ButtonWidth(pane, label))
			button:SetScript("OnClick", function()
				local db = ns:DB()
				db[def.key] = not ns:CompanionOrnamentShown(def)
				if ns.CompanionApplyOrnaments then pcall(ns.CompanionApplyOrnaments, ns) end
				ns:RefreshJournal()
			end)
			local on = self:CompanionOrnamentShown(def)
			local c = on and Theme.GOLD or Theme.EDGE
			if button.border and button.border.SetColor then button.border:SetColor(c[1], c[2], c[3], 1) end
			local tc = on and Theme.GOLD or Theme.MUTED_LIGHT
			button.text:SetTextColor(tc[1], tc[2], tc[3])
			local w = button:GetWidth()
			if x > 0 and x + w > HALF then x, y = 0, y + 24 end
			At(button, content, pane.ornX + x, pane.ornTop - y)
			x = x + w + 6
			button:Show()
		end
	end
	for index = count + 1, #pane.orns do pane.orns[index]:Hide() end
	if count == 0 then pane.ornNone:SetText(L.JRN_EVO_ORN_NONE) else pane.ornNone:SetText("") end
	if self.CompanionEffectsRefreshPane then self:CompanionEffectsRefreshPane(pane) end
end

local function RarityColor(entry)
	if entry.shiny then return Theme.GOLD_LIGHT end
	local rarity = ns.CAPTURE_RARITY and ns.CAPTURE_RARITY[entry.class or "normal"]
	return rarity and rarity.color or Theme.PARCHMENT
end

local function LevelText(entry)
	if entry.level then return tostring(entry.level) end
	if entry.lo then return entry.lo == entry.hi and tostring(entry.lo) or (entry.lo .. "-" .. entry.hi) end
	return "?"
end

local function ZoneName(self, zoneID)
	local info = zoneID and self.MapInfo and self:MapInfo(zoneID)
	return (info and info.name) or tostring(zoneID or "?")
end

-- keep : garder la version montrée (normale ou brillante) ; sinon, une autre
-- créature repart sur la normale, sauf si seule la brillante est capturée
function ns:JournalPreviewMenagerie(entry, keep)
	local frame = self.journalFrame
	if not (frame and frame.men and entry) then return end
	local preview = frame.men.preview
	if not keep and (preview.entry == nil or preview.entry.npc ~= entry.npc) then
		preview.shiny = entry.shiny and entry.normal == false or false
	end
	local canShiny = entry.known and (entry.shiny or entry.shinySeen) and true or false
	if not canShiny then preview.shiny = false end
	local shinyView = preview.shiny == true
	if preview.variant then
		if canShiny then
			preview.variant:SetText(shinyView and L.JRN_MEN_SEE_NORMAL or L.JRN_MEN_SEE_SHINY)
			preview.variant:Show()
		else
			preview.variant:Hide()
		end
	end
	-- 2.4 : trois paliers. Jamais croisée : verrouillée (ni nom, ni niveau, ni
	-- modèle ; la zone où la chercher). Croisée : nom, niveaux, modèle,
	-- abattues, chance. Capturée : tout (les effets de chasse et de confort se voient dès la croisée).
	if not entry.known then
		local lines = { L.MENV_LOCKED }
		if entry.zoneID then lines[#lines + 1] = self:F("JRN_MEN_ZONE", ZoneName(self, entry.zoneID)) end
		lines[#lines + 1] = L.JRN_MEN_NEVER
		PreviewSet(frame.men.preview, L.JRN_MEN_UNKNOWN, lines, {})
		frame.men.preview.entry = entry
		PreviewLocate(self, frame.men.preview, entry)
		return
	end
	local rank = L["CAPTURE_RANK_" .. tostring(entry.class or "normal")]
	local lines = { self:F("JRN_MEN_RANK", rank, LevelText(entry)) }
	if entry.zoneID then lines[#lines + 1] = self:F("JRN_MEN_ZONE", ZoneName(self, entry.zoneID)) end
	-- « Chasse : … / Confort : … » de cette créature (CompanionEffects.lua) :
	-- dès qu'elle est croisée, pour choisir quoi capturer
	if self.CompanionEffectsLines then
		for _, line in ipairs(self:CompanionEffectsLines(entry, shinyView)) do lines[#lines + 1] = line end
	end
	local function Day(at)
		local when = (tonumber(at) or 0) > 0 and rawget(_G, "date") and select(2, pcall(date, "%d/%m/%Y", at))
		return type(when) == "string" and when or nil
	end
	local current = self:CompanionData().appearance
	local id = "cap:" .. entry.npc .. (shinyView and ":s" or "")
	local caught = shinyView and entry.shiny or (not shinyView and entry.normal ~= false and entry.captured)
	if caught then
		local when = Day(shinyView and entry.shinyAt or entry.at)
		-- 2.0 : la qualité du spécimen gardé (CaptureQueue.lua), sur la même ligne
		local stars = self.CaptureStars and self:CaptureStars(entry.npc, shinyView)
		stars = stars and self:CaptureStarsText(stars, 12)
		if when then
			lines[#lines + 1] = self:F(shinyView and "JRN_MEN_SHINY_CAUGHT" or "JRN_MEN_CAUGHT", when) .. (stars and ("  " .. stars) or "")
		elseif stars then
			lines[#lines + 1] = self:F("CAPTURE_STARS_LABEL", stars)
		end
		lines[#lines + 1] = current == id and L.JRN_MEN_EQUIPPED or L.JRN_MEN_EQUIP
	else
		local chance = self.CaptureChance and self:CaptureChance({ class = entry.class, level = entry.level or entry.lo,
			type = entry.type, npcID = entry.npc, shiny = shinyView or nil }) or 0
		if shinyView then
			lines[#lines + 1] = self:F("JRN_MEN_SHINY_SEEN", Day(entry.shinySeen) or "?")
		else
			lines[#lines + 1] = self:F("JRN_MEN_NOTYET", math.floor(chance * 100 + 0.5 + 1e-9))
		end
	end
	lines[#lines + 1] = (entry.killed or 0) > 0 and self:F("JRN_MEN_KILLED", entry.killed) or L.JRN_MEN_NOT_KILLED
	if not shinyView then
		if entry.shiny then
			lines[#lines + 1] = self:F("JRN_MEN_SHINY_CAUGHT", Day(entry.shinyAt) or "?")
		elseif entry.shinySeen then
			lines[#lines + 1] = self:F("JRN_MEN_SHINY_SEEN", Day(entry.shinySeen) or "?")
		else
			lines[#lines + 1] = L.JRN_MEN_SHINY_UNSEEN
		end
	end
	local title = shinyView and self:F("CAPTURE_SHINY_TAG", entry.name) or entry.name
	PreviewSet(preview, title, lines, { creature = entry.npc, shiny = shinyView })
	preview.entry = entry
	PreviewLocate(self, preview, entry)
end

-- Clic : une créature capturée devient le compagnon
-- La version montrée dans la fiche si elle est capturée, sinon l'autre
function ns:JournalMenagerieEquip(entry)
	if not (entry and entry.captured and self.CompanionSetAppearance) then return false end
	local preview = self.journalFrame and self.journalFrame.men and self.journalFrame.men.preview
	local wantShiny = preview and preview.entry and preview.entry.npc == entry.npc and preview.shiny == true
	local hasNormal, hasShiny = entry.normal ~= false, entry.shiny == true
	local shiny = (wantShiny and hasShiny) or (not hasNormal and hasShiny)
	local id = "cap:" .. tostring(entry.npc) .. (shiny and ":s" or "")
	local function Done()
		if self.CompanionApplyModel then pcall(self.CompanionApplyModel, self) end
		if self.RefreshOptions then pcall(self.RefreshOptions, self) end
		self:RefreshJournal()
		self:JournalPreviewMenagerie(entry)
	end
	-- confirmation qui compare les effets (CompanionEffects.lua)
	if self.CompanionAskAppearance then return self:CompanionAskAppearance(id, Done) ~= nil end
	if not self:CompanionSetAppearance(id) then return false end
	Done()
	return true
end

-- La Ménagerie d'une zone (bouton de la fiche de zone, onglet Combat)
function ns:OpenMenagerieZone(zoneID)
	local frame = self:EnsureJournalWindow()
	if not frame then return end
	frame.menZone = tonumber(zoneID) or "here"
	frame.menState, frame.menRank, frame.menSearch, frame.menOffset = "all", "all", "", 0
	frame.menType = nil
	if frame.men and frame.men.search then frame.men.search:SetText("") end
	self:SelectJournalKind("menagerie")
end

-- « here » : la zone où l'on est (toutes en instance)
function ns:MenagerieZoneValue(value)
	if value == "here" then return (self.JournalZone and self:JournalZone()) or "all" end
	return value or "all"
end

-- clé de tri alphabétique : minuscules sans accents, sans article de tête
-- (« Les Tarides » se range à T, « The Barrens » à B)
local function SortKey(name)
	local text = ns.OptionFold and ns.OptionFold(name) or string.lower(tostring(name or ""))
	text = text:gsub("^%s+", "")
	for _, article in ipairs({ "les ", "le ", "la ", "l'", "the " }) do
		if text:sub(1, #article) == article then return text:sub(#article + 1) end
	end
	return text
end

ns.ZoneSortKey = SortKey

local function MenagerieZoneOptions(self)
	local here = self.JournalZone and self:JournalZone()
	local options = {
		{ value = "here", label = self:F("JRN_MEN_ZONE_HERE", here and ZoneName(self, here) or "-") },
		{ value = "all", label = L.JRN_MEN_ZONE_ALL },
	}
	-- les zones par ordre alphabétique (accents ignorés), sous « ici » et « toutes »
	local zones = {}
	for _, zoneID in ipairs(self.MenagerieZones and self:MenagerieZones() or {}) do
		local levels = ns.ZONE_LEVELS and ns.ZONE_LEVELS[zoneID]
		local name = ZoneName(self, zoneID)
		zones[#zones + 1] = { value = zoneID, label = name, key = SortKey(name),
			hint = levels and (levels[1] .. "-" .. levels[2]) or nil }
	end
	table.sort(zones, function(a, b)
		if a.key ~= b.key then return a.key < b.key end
		return a.value < b.value
	end)
	for _, option in ipairs(zones) do options[#options + 1] = option end
	return options
end

local function RefreshMenagerie(self, frame)
	local pane = frame.men
	frame.header:SetTitle(L.JRN_SEC_menagerie)
	frame.header:SetSubtitle(L.JRN_SUB_menagerie)
	local list, stats
	if frame.scrollOnly and pane.lastList then
		-- molette : mêmes filtres, même liste ; seule la page change
		list, stats = pane.lastList, pane.lastStats
	else
		pane.zone:SetOptions(MenagerieZoneOptions(self))
		pane.zone:SetValue(frame.menZone or "here")
		pane.rank:SetValue(frame.menRank or "all")
		pane.sort:SetValue(frame.menSort or "no")
		pane.stateRow:Select(frame.menState or "all", true)
		list, stats = self:MenagerieList({ zone = self:MenagerieZoneValue(frame.menZone or "here"),
			state = frame.menState, rank = frame.menRank, search = frame.menSearch, sort = frame.menSort, ctype = frame.menType })
		pane.lastList, pane.lastStats = list, stats
	end
	-- boutons de type : sélection et comptes (MenagerieView.lua)
	if pane.types and self.MenagerieViewRefresh then
		local ok, err = pcall(self.MenagerieViewRefresh, self, pane, frame, stats)
		if not ok and self.RecordError then self:RecordError("menagerie:types", err) end
	end
	if (stats.shinySeen or 0) > 0 then
		pane.count:SetText(self:F("JRN_MEN_COUNT_SHINY", stats.captured, stats.shinySeen, stats.known, stats.total))
	else
		pane.count:SetText(self:F("JRN_MEN_COUNT", stats.captured, stats.known, stats.total))
	end
	pane.empty:SetText(#list == 0 and (stats.total == 0 and L.JRN_MEN_EMPTY or L.JRN_MEN_NONE) or "")
	local page = #pane.items
	local maxOffset = math.max(0, #list - page)
	frame.menOffset = math.max(0, math.min(frame.menOffset or 0, maxOffset))
	local current = self:CompanionData().appearance
	local shown = pane.preview.entry
	for index, row in ipairs(pane.items) do
		local entry = list[index + frame.menOffset]
		row.entry = entry
		if entry then
			local icon = entry.known and (TYPE_ICONS[entry.type or ""] or MEN_DEFAULT_ICON) or LOCK_ICON
			pcall(row.icon.SetTexture, row.icon, icon)
			if row.icon.SetDesaturated then row.icon:SetDesaturated(not entry.captured) end
			row.icon:SetAlpha(entry.captured and 1 or (entry.known and 0.5 or 0.3))
			row.no:SetText(self:F("JRN_MEN_NO", entry.no))
			row.label:SetText(entry.known and entry.name or L.JRN_MEN_UNKNOWN)
			-- 2.11.0 (fiche 08) : une espèce inconnue n'est plus délavée (alpha 1) ;
			-- son nom prend le gris clair du thème (7,75:1 sur FIELD), pas sa rareté
			local lc = entry.known and RarityColor(entry) or Theme.MUTED_LIGHT
			row.label:SetTextColor(lc[1], lc[2], lc[3])
			row.label:SetAlpha(1)
			-- 2.4 : une espèce jamais croisée est verrouillée, case sombre
			if entry.known then row:SetAlt(row.alt) else row.bg:SetVertexColor(Theme.FIELD[1], Theme.FIELD[2], Theme.FIELD[3], 1) end
			-- 2.0 : les étoiles du meilleur spécimen (CaptureQueue.lua), avant le type
			-- 2.11.0 : étoiles dessinées (ns.MenagerieRowStars), le type seul en texte
			local stars = entry.captured and tonumber(entry.stars or entry.shinyStars) or nil
			ns.MenagerieRowStars(row, stars)
			-- verrouillée : pas de type, seulement la zone où la chercher (toutes zones)
			local hint = (not entry.known and frame.menZone == "all" and entry.zoneID) and ZoneName(self, entry.zoneID) or ""
			row.detail:SetText(entry.known and (entry.type or "") or hint)
			-- liseré vert : la version normale capturée ; losange doré : la
			-- brillante, plein si capturée, au trait si seulement reconnue
			if entry.captured and entry.normal ~= false then row.caught:Show() else row.caught:Hide() end
			if entry.shiny or entry.shinySeen then
				row.star:SetTexture(entry.shiny and Theme.DIAMOND or Theme.DIAMOND_LINE)
				row.star:Show()
			else
				row.star:Hide()
			end
			local worn = current == ("cap:" .. entry.npc) or current == ("cap:" .. entry.npc .. ":s")
			local picked = shown and shown.npc == entry.npc
			if picked or worn then row.mark:Show() else row.mark:Hide() end
			local mc = worn and Theme.GOLD or Theme.WHITE
			row.mark:SetVertexColor(mc[1], mc[2], mc[3], worn and 0.12 or 0.05)
			row:Show()
		else
			row:Hide()
		end
	end
	pane.pager:Update(frame.menOffset, page, #list, maxOffset)
	if pane.collection and self.MenagerieCollectionRefresh then
		local ok, err = pcall(self.MenagerieCollectionRefresh, self, pane, self:MenagerieZoneValue(frame.menZone or "here"))
		if not ok and self.RecordError then self:RecordError("menagerie:collection", err) end
	end
	local still = false
	for _, entry in ipairs(list) do if shown and entry.npc == shown.npc then still = true end end
	if list[1] and not still then self:JournalPreviewMenagerie(list[1])
	elseif not list[1] then
		PreviewSet(pane.preview, "", {}, {}); pane.preview.entry = nil
		if pane.preview.locate then pane.preview.locate:Hide() end
	end
end

-- 2.9.1 : une carte de mission remplie (titre, zone, barre, compte, gains, état)
local function MissionRow(self, row, mission, label, scope)
	row.mission, row.empty, row.fullLabel = mission, nil, label
	local zone = MissionZone(self, mission)
	row.label:SetText(SplitLabel(label, zone))
	row.zone:SetText(zone or L.MIS_ANYWHERE)
	local reward = self.MissionRewardText and self:MissionRewardText(scope) or ""
	row.source:SetText(reward)
	row.icon:SetTexture(ns.MissionKindIcon(mission.kind))
	row.icon:Show()
	if row.icon.SetDesaturated then row.icon:SetDesaturated(false) end
	for _, edge in pairs(row.iconEdge) do if type(edge) == "table" and edge.Show and not row.azNoEdge then edge:Show() end end
	local treat, aid = RewardIcons(self, scope)
	row.rewards[1]:SetTexture(treat); if treat then row.rewards[1]:Show() else row.rewards[1]:Hide() end
	row.rewards[2]:SetTexture(aid); if aid then row.rewards[2]:Show() else row.rewards[2]:Hide() end
	row.zone:Show()
	row.count:SetText(string.format("%d/%d", mission.have or 0, mission.need))
	local cc = mission.done and Theme.GREEN or Theme.PARCHMENT
	row.count:SetTextColor(cc[1], cc[2], cc[3])
	row.bar:SetValue((mission.have or 0) / mission.need)
	local c = mission.done and Theme.GREEN or (row.group == "week" and Theme.BLUE or Theme.GOLD)
	row.bar:SetColor(c[1], c[2], c[3], 1)
	row.bar:Show()
	-- 2.9.1 : plus de liseré de couleur (la carte faite a son voile et son tampon)
	row:SetAccent(nil)
	if mission.done then row.tint:Show(); row.stamp:Show() else row.tint:Hide(); row.stamp:Hide() end
	local lines = row.tipLines
	lines[1] = zone or L.MIS_ANYWHERE
	lines[2] = reward ~= "" and reward or nil
	row:Show()
end

-- une carte vide : le groupe n'a pas de mission (une seule carte l'explique)
local function EmptyRow(row, text)
	row.mission, row.empty, row.fullLabel = nil, true, nil
	row.label:SetText(text)
	row.zone:SetText(""); row.zone:Hide()
	row.source:SetText("")
	row.count:SetText("")
	row.bar:Hide()
	row.icon:Hide()
	for _, edge in pairs(row.iconEdge) do if type(edge) == "table" and edge.Hide then edge:Hide() end end
	row.rewards[1]:Hide(); row.rewards[2]:Hide()
	row.tint:Hide(); row.stamp:Hide()
	if row.reroll then row.reroll:Hide() end
	row:SetAccent(nil)
end

-- une plaque du résumé : compte, pastilles, détail (et son infobulle)
local function SummaryPlaque(plaque, done, total, detail)
	plaque.count:SetText(total > 0 and string.format("%d/%d", done, total) or "-")
	for index, pip in ipairs(plaque.pips) do
		local c = index <= done and MIS_COLORS.pipOn or MIS_COLORS.pipOff
		pip:SetVertexColor(c[1], c[2], c[3], 1)
		pip.on = index <= done
		if index <= math.max(total, 1) then pip:Show() else pip:Hide() end
	end
	plaque.detail:SetText(detail or "")
	plaque.tipLines[1] = detail
end

local function RefreshDay(self, frame)
	local pane = frame.day
	local daily, inn = self:DailyData()
	frame.header:SetTitle(L.JRN_SEC_day)
	frame.header:SetSubtitle(L.JRN_SUB_day)
	local today = daily.day == self:DailyToday()
	local on = self:DailyMissionsOn()
	local weekly = on and self.WeeklyCurrent and self:WeeklyCurrent() or nil
	local trait = self.CompanionTrait and self:CompanionTrait()
	local traitLabel = trait and self.PersonaLabel and self:PersonaLabel(trait)
	local ends = weekly and self.WeeklyEndsText and self:WeeklyEndsText() or nil
	local zoneInfo = daily.zoneID and self.MapInfo and self:MapInfo(daily.zoneID)
	pane.chips.trait:SetChip(traitLabel)
	pane.chips.zone:SetChip(on and today and zoneInfo and zoneInfo.name or nil)
	pane.chips.week:SetChip(ends and self:F("SUM_LEFT", ends) or nil)
	local firstEmpty = {}
	for _, row in ipairs(pane.missions) do
		local mission, label, scope
		if row.slot.daily and on and today then
			mission = daily.missions[row.slot.daily]
			if mission then
				label = self:MissionLabel(mission)
				scope = mission.source == "trait" and "trait" or "zone"
			end
		elseif row.slot.weekly and weekly then
			mission = weekly.missions[row.slot.weekly]
			if mission then
				label = self:WeeklyLabel(mission)
				scope = "weekly"
			end
		end
		if mission then
			MissionRow(self, row, mission, label, scope)
			if row.reroll then
				if not mission.done and not daily.rerolled then row.reroll:Show() else row.reroll:Hide() end
			end
		else
			-- un groupe vide : une seule carte qui explique
			local empty = not firstEmpty[row.group]
			firstEmpty[row.group] = true
			EmptyRow(row, empty and (on and L.MIS_NONE or L.MIS_OFF) or "")
			if empty then row:Show() else row:Hide() end
		end
	end
	-- encarts des 3 : le bonus (ou « nouvelles missions demain »)
	local box = pane.callouts.zone
	box.text:SetText(on and today and (daily.allDone and L.MIS_RENEW or L.MIS_ALL_BONUS) or "")
	if box.text:GetText() ~= "" then box:Show() else box:Hide() end
	local week = pane.callouts.week
	week.text:SetText(weekly and (weekly.allDone and L.WK_ALL_DONE or L.WK_ALL_BONUS) or "")
	if week.text:GetText() ~= "" then week:Show() else week:Hide() end
	for _, b in ipairs({ box, week }) do
		local treat, aid = RewardIcons(self, b.scope)
		b.icons[1]:SetTexture(treat); if treat then b.icons[1]:Show() else b.icons[1]:Hide() end
		b.icons[2]:SetTexture(aid); if aid then b.icons[2]:Show() else b.icons[2]:Hide() end
	end
	-- bande résumé : compagnon, jour (les 3 du jour, compagnon compris), semaine
	local traitDone, traitTotal, dayDone, dayTotal, weekDone, weekTotal = 0, 0, 0, 0, 0, 0
	if on and today then
		for _, mission in ipairs(daily.missions) do
			dayTotal = dayTotal + 1
			if mission.done then dayDone = dayDone + 1 end
			if mission.source == "trait" then
				traitTotal = traitTotal + 1
				if mission.done then traitDone = traitDone + 1 end
			end
		end
	end
	for _, mission in ipairs(weekly and weekly.missions or {}) do
		weekTotal = weekTotal + 1
		if mission.done then weekDone = weekDone + 1 end
	end
	local sum = pane.summary
	SummaryPlaque(sum.trait, traitDone, traitTotal,
		not on and L.MIS_OFF or (traitLabel and self:F("SUM_TRAIT", traitLabel) or L.SUM_TRAIT_NONE))
	SummaryPlaque(sum.zone, dayDone, dayTotal, not on and L.MIS_OFF or (dayTotal == 0 and L.MIS_NONE)
		or (daily.allDone and L.SUM_DONE or self:F("SUM_BONUS", RewardShort(self, "allDaily"))))
	local weekDetail = weekly and (weekly.allDone and L.SUM_DONE
		or (ends and self:F("SUM_WEEK", ends, RewardShort(self, "allWeekly")) or self:F("SUM_BONUS", RewardShort(self, "allWeekly"))))
	SummaryPlaque(sum.week, weekDone, weekTotal, weekDetail or (not on and L.MIS_OFF) or "")
	-- carte des auberges
	local size = #pane.stamps
	for index, stamp in ipairs(pane.stamps) do
		local got = index <= inn.card
		stamp.got = got
		if stamp.SetDesaturated then stamp:SetDesaturated(not got) end
		stamp:SetAlpha(got and 1 or (index == size and 0.7 or 0.35))
	end
	pane.innTotal:SetText(self:F("INN_TOTAL", inn.total, inn.full or 0))
	local chicken = self.CompanionAppearanceDef and self:CompanionAppearanceDef(ns.INN_APPEARANCE or "")
	pane.innGift:SetText(chicken and self:F("INN_GIFT", ns.INN_APPEARANCE_CARDS, L[chicken.label]) or "")
	local squirrel = self.CompanionAppearanceDef and self:CompanionAppearanceDef(ns.MISSION_APPEARANCE or "")
	pane.perfect:SetText(squirrel and self:F("MIS_PERFECT", daily.perfect or 0, ns.MISSION_APPEARANCE_DAYS, L[squirrel.label]) or "")
	pane.innHint:SetText(self:F("INN_HINT", ns.INN_ENERGY, ns.INN_CARD))
	pane.pantryHint:SetText(L.DAY_PANTRY_HINT)
	for _, slot in ipairs(pane.slots) do
		local count = self:TreatCount(slot.kind)
		slot.count:SetText(self:F("TREAT_COUNT", count, self:TreatCap(slot.kind)))
		if slot.icon.SetDesaturated then slot.icon:SetDesaturated(count == 0) end
		if count > 0 then slot.give:Show() else slot.give:Hide() end
	end
	for _, tile in ipairs(pane.aids) do
		local count = self.CaptureAidCount and self:CaptureAidCount(tile.aid) or 0
		tile.count:SetText(self:F("TREAT_COUNT", count, AidCap(tile.aid)))
		tile.name:SetText(self:CaptureAidLabel(tile.aid))
		if tile.icon.SetDesaturated then tile.icon:SetDesaturated(count == 0) end
	end
	LayoutDay(pane, frame.content)
end

-- la page Missions compte les missions qui restent, jour et semaine (pastille)
local function DayNavLabel(self, frame)
	local nav = frame.sections.day
	if not (nav and self.DailyData) then return end
	local daily = self:DailyData()
	local open = 0
	if self:DailyMissionsOn() then
		if daily.day == self:DailyToday() then
			for _, mission in ipairs(daily.missions) do if not mission.done then open = open + 1 end end
		end
		local weekly = self.WeeklyCurrent and self:WeeklyCurrent()
		for _, mission in ipairs(weekly and weekly.missions or {}) do if not mission.done then open = open + 1 end end
	end
	nav:SetText(L.JRN_SEC_day)
	nav:SetBadge(open > 0 and tostring(open) or nil)
end

local function RefreshPantry(self, frame)
	if not frame.pantry then return end
	for kind, button in pairs(frame.pantry) do
		local count = self:TreatCount(kind)
		button.count:SetText(tostring(count))
		if button.icon.SetDesaturated then button.icon:SetDesaturated(count == 0) end
		button:SetAlpha(count == 0 and 0.45 or 1)
	end
end

-- ---------------------------------------------------------------------------
-- 2.11.0 : la colonne de navigation sert de tableau de bord (fiche 14) :
-- compagnon (nom, humeur, quatre envies), zone où l'on est (%), missions du
-- jour et de la semaine (losanges pleins = faites). Chaque bloc mène à sa
-- page. Construit une fois ; rafraîchi avec le carnet (pas à la molette).
-- ---------------------------------------------------------------------------
local NAVSUM = { w = NAV_W - 36, x = 18, gap = 16, row = 14, labelW = 66, bar = 2, block = 10 }
ns.JOURNAL_NAVSUM = NAVSUM
local NEED_KEYS = { "hunger", "energy", "mood", "curiosity" }
local function NavBlock(box, height, onClick, tipKey)
	local b = CreateFrame("Button", nil, box)
	b:SetSize(NAVSUM.w, height)
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(owner) Tip(owner, L[tipKey], {}) end)
	b:SetScript("OnLeave", HideTip)
	b.rule = Theme.Solid(b, "BORDER", Theme.EDGE_SOFT, 1)
	b.rule:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.rule:SetSize(NAVSUM.w, 1)
	return b
end
function ns:JournalNavSummaryBuild(frame)
	if frame.navSummary or not frame.nav then return frame.navSummary end
	local W, R = NAVSUM.w, NAVSUM.row
	local box = CreateFrame("Frame", nil, frame.nav)
	box:SetSize(W, 10)
	box:SetPoint("TOPLEFT", frame.nav, "TOPLEFT", NAVSUM.x, (frame.navY or -280) - NAVSUM.gap)
	-- compagnon
	local petH = 6 + R + 4 + #NEED_KEYS * R
	local pet = NavBlock(box, petH, function() ns:SelectJournalKind("evolution") end, "JRN_NAVSUM_COMPANION_TIP")
	pet:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	pet.name = Text(pet, Theme.F_LABEL, Theme.LABEL, W)
	pet.name:SetPoint("TOPLEFT", pet, "TOPLEFT", 0, -6)
	if pet.name.SetWordWrap then pet.name:SetWordWrap(false) end
	pet.needs = {}
	for index, key in ipairs(NEED_KEYS) do
		local y = -6 - R - 4 - (index - 1) * R
		local row = { key = key }
		row.label = Text(pet, Theme.F_SMALL, Theme.MUTED_LIGHT, NAVSUM.labelW)
		row.label:SetPoint("TOPLEFT", pet, "TOPLEFT", 0, y)
		row.label:SetText(L["COMP_NEED_" .. key] or key)
		row.bar = Theme.CreateBar(pet, W - NAVSUM.labelW, NAVSUM.bar)
		row.bar:SetPoint("TOPLEFT", pet, "TOPLEFT", NAVSUM.labelW, y - 5)
		pet.needs[index] = row
	end
	box.pet = pet
	-- zone
	local zone = NavBlock(box, 6 + R + 8, function()
		local here = ns.JournalZone and ns:JournalZone()
		if here and ns.OpenJournalZone then ns:OpenJournalZone(here) else ns:SelectJournalKind("progress") end
	end, "JRN_NAVSUM_ZONE_TIP")
	zone:SetPoint("TOPLEFT", pet, "BOTTOMLEFT", 0, -NAVSUM.block)
	zone.name = Text(zone, Theme.F_LABEL, Theme.LABEL, W - 44)
	zone.name:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -6)
	if zone.name.SetWordWrap then zone.name:SetWordWrap(false) end
	zone.percent = Text(zone, Theme.F_SMALL, Theme.PARCHMENT, 40)
	zone.percent:SetPoint("TOPRIGHT", zone, "TOPRIGHT", 0, -7)
	zone.percent:SetJustifyH("RIGHT")
	zone.bar = Theme.CreateBar(zone, W, NAVSUM.bar)
	zone.bar:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -6 - R - 3)
	box.zone = zone
	-- missions
	local mis = NavBlock(box, 6 + 2 * R + 2, function() ns:SelectJournalKind("day") end, "JRN_NAVSUM_MISSIONS_TIP")
	mis:SetPoint("TOPLEFT", zone, "BOTTOMLEFT", 0, -NAVSUM.block)
	mis.rows = {}
	for index, key in ipairs({ "day", "week" }) do
		local y = -6 - (index - 1) * (R + 2)
		local row = { key = key, pips = {} }
		row.label = Text(mis, Theme.F_SMALL, Theme.MUTED_LIGHT, NAVSUM.labelW)
		row.label:SetPoint("TOPLEFT", mis, "TOPLEFT", 0, y)
		row.label:SetText(L[key == "day" and "JRN_NAVSUM_DAY" or "JRN_NAVSUM_WEEK"])
		for p = 1, 3 do
			local d = Theme.CreateDiamond(mis, 9, true)
			d:SetPoint("TOPLEFT", mis, "TOPLEFT", NAVSUM.labelW + (p - 1) * 14, y - 2)
			row.pips[p] = d
		end
		row.left = Text(mis, Theme.F_SMALL, Theme.MUTED_LIGHT, 60)
		row.left:SetPoint("TOPRIGHT", mis, "TOPRIGHT", 0, y)
		row.left:SetJustifyH("RIGHT")
		mis.rows[index] = row
	end
	box.missions = mis
	box:SetHeight(petH + 2 * NAVSUM.block + zone:GetHeight() + mis:GetHeight())
	frame.navSummary = box
	ns.JournalNavSummaryFit(box, W)
	return box
end

-- 2.11.1 : largeur des blocs, barres et textes du résumé, bornée à la
-- largeur intérieure de la colonne (en Azeroth, 196 − 2 × 12 : avant, les
-- barres, « 73 % » et « 1 j » dépassaient à droite). Rappelée par le skin.
function ns.JournalNavSummaryFit(box, w)
	if not box then return nil end
	w = math.floor(tonumber(w) or NAVSUM.w)
	box.fitW = w
	box:SetWidth(w)
	local barW = math.max(20, w - NAVSUM.labelW)
	for _, block in ipairs({ box.pet, box.zone, box.missions }) do
		block:SetWidth(w)
		if block.rule then block.rule:SetWidth(w) end
	end
	box.pet.name:SetWidth(w)
	for _, row in ipairs(box.pet.needs) do
		row.bar:SetWidth(barW)
		if row.bar.ratio then row.bar:SetValue(row.bar.ratio) end
	end
	box.zone.name:SetWidth(w - 44)
	box.zone.bar:SetWidth(w)
	if box.zone.bar.ratio then box.zone.bar:SetValue(box.zone.bar.ratio) end
	-- reste de la semaine : à droite des losanges, sans les chevaucher
	local leftW = math.max(24, w - NAVSUM.labelW - 3 * 14)
	for _, row in ipairs(box.missions.rows) do row.left:SetWidth(leftW) end
	return w
end

local function NavMissions(row, list)
	for index, pip in ipairs(row.pips) do
		local mission = list and list[index]
		Theme.SetStatus(pip, mission and (mission.done and "warn" or "item") or nil)
	end
end
function ns:JournalNavSummaryRefresh(frame)
	local box = frame and frame.navSummary
	if not box then return end
	local on = ModuleOn()
	-- compagnon
	if on and self.CompanionData then
		local data = self:CompanionData()
		local mood = self.CompanionMood and L["COMP_MOOD_" .. tostring(self:CompanionMood())]
		box.pet.name:SetText((self.CompanionName and self:CompanionName() or "") .. (mood and (" · " .. mood) or ""))
		local happy = ns.COMPANION_HAPPY_MIN or 70
		for _, row in ipairs(box.pet.needs) do
			local value = tonumber(data.needs and data.needs[row.key]) or 0
			row.bar:SetValue(math.max(0, math.min(1, value / 100)))
			local c = value >= happy and Theme.GOLD or Theme.MUTED_LIGHT
			row.bar:SetColor(c[1], c[2], c[3], 1)
			row.value = value
		end
		box.pet:Show()
	else
		box.pet:Hide()
	end
	-- zone : ZoneCompletion seulement si la zone a changé ou au rafraîchissement complet
	local here = self.JournalZone and self:JournalZone()
	local cache = box.zone
	if not frame.scrollOnly or cache.zoneID ~= here then
		cache.zoneID = here
		local done = here and self.ZoneCompletion and self:ZoneCompletion(here)
		cache.done = (done and #(done.parts or {}) >= 2) and done or nil
	end
	local info = here and self.MapInfo and self:MapInfo(here)
	if cache.done then
		cache.name:SetText(info and info.name or tostring(here))
		cache.percent:SetText(self:F("JRN_ZONE_PERCENT", cache.done.percent))
		cache.bar:SetValue(cache.done.ratio or (cache.done.percent / 100))
		local c = cache.done.percent >= 100 and Theme.GOLD or Theme.MUTED_LIGHT
		cache.bar:SetColor(c[1], c[2], c[3], 1)
		cache.bar:Show()
	else
		cache.name:SetText(info and info.name or L.JRN_NAVSUM_ZONE_NONE)
		cache.percent:SetText("")
		cache.bar:Hide()
	end
	-- missions
	local mis = box.missions
	if self.DailyData and self.DailyMissionsOn and self:DailyMissionsOn() then
		local daily = self:DailyData()
		NavMissions(mis.rows[1], daily.day == self:DailyToday() and daily.missions or nil)
		local weekly = self.WeeklyCurrent and self:WeeklyCurrent()
		NavMissions(mis.rows[2], weekly and weekly.missions or nil)
		mis.rows[1].left:SetText("")
		mis.rows[2].left:SetText(weekly and self.WeeklyEndsText and tostring(self:WeeklyEndsText() or "") or "")
		mis:Show()
	else
		mis:Hide()
	end
end

local PANES = { day = "day", evolution = "evo", menagerie = "men" }
function ns:RefreshJournal()
	local frame = self.journalFrame
	if not frame then return end
	local section = KindOf(frame, frame.kind)
	frame.kind = section
	frame.header.title:SetWidth(INNER - 100)
	for key, item in pairs(frame.sections) do item:SetSelected(key == section) end
	-- 2.7.0 : les points de hauts faits (compte + personnage) remplacent le
	-- nombre de tampons (devenus des relevés silencieux)
	-- (molette : le total n'a pas bougé, pas de nouveau passage sur les hauts faits)
	if not frame.scrollOnly then
		local total
		if self.FeatPoints then total = self:F("JRN_TOTAL_FEATS", (self:FeatPoints()))
		else total = self:F("JRN_TOTAL", self:JournalCounts().total) end
		frame.subtitle:SetText(total
			.. (ModuleOn() and "" or ("|n" .. Theme.T_GREY .. L.MODULE_OFF .. "|r")))
	end
	for key, field in pairs(PANES) do
		local pane = frame[field]
		if pane then if key == section then pane:Show() else pane:Hide() end end
	end
	for key, def in pairs(ns.JOURNAL_PANES) do
		local pane = frame[def.field]
		if pane then if key == section then pane:Show() else pane:Hide() end end
	end
	RefreshPantry(self, frame)
	DayNavLabel(self, frame)
	do
		local ok, err = pcall(self.JournalNavSummaryRefresh, self, frame)
		if not ok and self.RecordError then self:RecordError("journal:navsum", err) end
	end
	if ns.JOURNAL_PANES[section] then
		local def = ns.JOURNAL_PANES[section]
		frame.header:SetTitle(def.title and L[def.title] or "")
		frame.header:SetSubtitle(def.subtitle and L[def.subtitle] or "")
		local ok, err = pcall(def.refresh, self, frame, ns.JournalUI)
		if not ok and self.RecordError then self:RecordError("journal:" .. section, err) end
	elseif section == "day" then
		RefreshDay(self, frame)
	elseif section == "menagerie" then
		RefreshMenagerie(self, frame)
	else
		-- page par défaut : une erreur ici ne doit pas casser tout le carnet
		local ok, err = pcall(RefreshEvolution, self, frame)
		if not ok and self.RecordError then self:RecordError("journal:evolution", err) end
	end
end

-- À l'ouverture : le dernier onglet utilisé (la Zone la première fois), et la
-- zone revient à « ici »
do
	local previous = ns.ToggleJournal
	function ns:ToggleJournal(forceShow)
		local frame = self.journalFrame
		local opening = not (frame and frame:IsShown()) or forceShow
		if opening then
			frame = frame or self:EnsureJournalWindow()
			if frame and not frame:IsShown() then
				frame.zonePicked = nil
				frame.offset = 0
				frame.kind = KindOf(frame, self:DB().journalTab or "evolution")
			end
		end
		return previous(self, forceShow)
	end
end

-- Le garde-manger change (friandise gagnée ou donnée) : l'en-tête suit
do
	local refresh = ns.TreatMenuRefresh
	if refresh then
		function ns:TreatMenuRefresh(...)
			local a = refresh(self, ...)
			local frame = self.journalFrame
			if frame and frame:IsShown() then RefreshPantry(self, frame) end
			return a
		end
	end
end

-- une seule grande fenêtre à la fois (socle commun, ns:CloseOtherWindows)
if type(ns.EXCLUSIVE_WINDOWS) == "table" then table.insert(ns.EXCLUSIVE_WINDOWS, "journalFrame") end

if ns.Mark then ns.Mark("JournalWindow") end