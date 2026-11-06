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
	JRN_SEC_memories       = "Souvenirs",
	JRN_ZONE_PICK          = "Zone : %s",
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
	JRN_CHEST_TODO         = "À 100 %% : un coffre, un objet au choix (palier %d)",
	JRN_CHEST_READY        = "Coffre gagné : à ouvrir !",
	JRN_CHEST_OPENED       = "Coffre ouvert : %s",
	JRN_CHEST_GOLDEN       = "Zone dorée : tout le palier %d est déjà à toi",
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
	JRN_EVO_CHESTS         = "Coffres à ouvrir : %d",
	JRN_EVO_COLLECTION     = "Collection : %d/%d  (palier 1 : %d/%d · palier 2 : %d/%d · palier 3 : %d/%d)",
	JRN_EVO_ROAD           = "Parcours : %d zones · %d/%d capitales · %d donjons · %d rares · %d/%d paliers",
}
local EN = {
	JRN_SEC_evolution      = "Companion",
	JRN_SEC_memories       = "Memories",
	JRN_ZONE_PICK          = "Zone: %s",
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
	JRN_CHEST_TODO         = "At 100 %%: a chest, one item of your choice (tier %d)",
	JRN_CHEST_READY        = "Chest earned: open it!",
	JRN_CHEST_OPENED       = "Chest opened: %s",
	JRN_CHEST_GOLDEN       = "Golden zone: you already own all of tier %d",
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
	JRN_EVO_CHESTS         = "Chests to open: %d",
	JRN_EVO_COLLECTION     = "Collection: %d/%d  (tier 1: %d/%d · tier 2: %d/%d · tier 3: %d/%d)",
	JRN_EVO_ROAD           = "Road: %d zones · %d/%d capitals · %d dungeons · %d rares · %d/%d milestones",
}
ns.RegisterStrings(FR, EN)
ns.JOURNAL_WINDOW_STRINGS = { fr = FR, en = EN }

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
--   Souvenirs  l'album (Memories.lua)
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
-- 1.5.0 : cinq pages. « progress » (Complétion : zones et fiche de zone) et
-- l'album viennent d'ailleurs (ns.JOURNAL_PANES) ; Collection rejoint Compagnon
local SECTIONS = { "evolution", "menagerie", "day", "progress", "memories" }
local MEN_STATES = { "all", "captured", "missing", "tokill", "shiny" }
local MEN_RANKS = { "all", "normal", "elite", "rare", "boss" }
local MEN_SORTS = { "no", "name", "level", "rank", "date" }
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
local SHINY_COLOR = { 1.0, 0.89, 0.48 }  -- fiche d'une brillante abattue
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
	JRN_ZONES_SUM          = "%d/%d visitées · %d à 100 %%",
	JRN_ZONE_LEVELS        = "niveaux %d-%d",
	JRN_TILE_UNSEEN        = "jamais visitée",
	JRN_TILE_HERE          = "ici",
	JRN_TILE_CHEST         = "coffre !",
	JRN_UNSEEN_ZONE        = "Zone jamais visitée : tout se dévoilera à ta première visite.",
	JRN_MARK               = "%d %%",
	JRN_MARK_TIP           = "Paliers : une friandise à 25 et 50 %%, un Festin à 75 %%, le coffre à 100 %%.",
	JRN_CARD_UNSEEN        = "???",
	JRN_PREV_HINT_combat   = "Survole une fiche : la créature s'affiche ici.",
	JRN_PREV_HINT_explore  = "Les villages et lieux de la zone. Un losange plein : visité.",
	JRN_PREV_HINT_quests   = "Les quêtes de la zone que ton personnage peut faire. Elles comptent dans les 100 %.",
	JRN_PREV_HINT_craft    = "Les ressources de ta compétence qui poussent ici. En couleur : déjà récoltées dans la zone.",
	JRN_PREV_LEVEL         = "Niveau : %s",
	JRN_PREV_RANK          = "Rang : %s",
	JRN_PREV_KILLED        = "Abattus : %d",
	JRN_PREV_NOTYET        = "Pas encore abattue.",
	JRN_PREV_UNSEEN        = "Jamais croisée.",
	JRN_RANK_normal        = "normal",
	JRN_Q_all              = "Toutes",
	JRN_Q_todo             = "À faire",
	JRN_Q_done             = "Faites",
	JRN_COLL_app           = "Apparences",
	JRN_COLL_orn           = "Ornements",
	JRN_COLL_frame         = "Cadres",
	JRN_COLL_bg            = "Fonds",
	JRN_COLL_COUNT         = "%d / %d possédés",
	JRN_COLL_EQUIPPED      = "Équipé.",
	JRN_COLL_CLICK         = "Clic : équiper.",
	JRN_COLL_ORN_ON        = "Porté. Clic : l'enlever.",
	JRN_COLL_ORN_OFF       = "Clic : le porter.",
	JRN_COLL_LOCKED        = "Verrouillé.",
	JRN_COLL_SOURCE        = "Source : %s",
	JRN_COLL_SRC_BASE      = "possédé d'office",
	JRN_COLL_SRC_TIER      = "coffre de zone, palier %d",
	JRN_COLL_HINT          = "Survole un objet pour le voir sur ta créature.",
	JRN_SEC_menagerie      = "Ménagerie",
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
	JRN_MEN_SORT_date      = "Tri : capture",
	JRN_MEN_SEARCH         = "Chercher un nom…",
	JRN_MEN_UNKNOWN        = "???",
	JRN_MEN_NEVER          = "Jamais croisée : approche-toi, cible-la.",
	JRN_MEN_NOT_KILLED     = "Pas encore abattue",
	JRN_MEN_NONE           = "Aucune créature ne correspond à ces filtres.",
	JRN_BACK_ZONES         = "< Zones",
	JRN_COMBAT_MEN         = "Le bestiaire de la zone vit dans la Ménagerie : abattues, capturées, et celles qui restent à trouver.",
	JRN_COMBAT_OPEN        = "Voir dans la Ménagerie",
	JRN_MEN_NO             = "n° %03d",
	JRN_MEN_RANK           = "%s · niveau %s",
	JRN_MEN_ZONE           = "Zone : %s",
	JRN_MEN_CAUGHT         = "Capturée le %s",
	JRN_MEN_NOTYET         = "Pas encore capturée · chance ~%d %%",
	JRN_MEN_KILLED         = "Abattue %d fois",
	JRN_MEN_EQUIP          = "Clic : en faire ton compagnon",
	JRN_MEN_EQUIPPED       = "C'est ton compagnon",
	JRN_MEN_EMPTY          = "Aucune créature croisée pour l'instant : cible ou survole des monstres.",
	JRN_BACK_HINT          = "Bouton retour de la souris : revenir aux zones.",
	JRN_EVO_TRAIT          = "Caractère : %s",
	JRN_SUB_companion      = "Ton compagnon de route : son humeur, ses envies, son allure.",
	JRN_EVO_STAT_captures  = "capturées",
	JRN_EVO_STAT_shiny     = "brillantes",
	JRN_EVO_STAT_days      = "jours ensemble",
	JRN_EVO_STAT_missions  = "missions faites",
	JRN_EVO_LOOKS          = "Son allure",
	JRN_EVO_LOOKS_COUNT    = "%d apparences",
	JRN_EVO_FRAME          = "Cadre",
	JRN_EVO_BG             = "Fond",
	JRN_EVO_ORNS           = "Ornements",
	JRN_EVO_ORN_NONE       = "Pas encore d'ornement : les coffres de zone en donnent.",
	JRN_EVO_LOOK_TIP       = "Clic : la porter. Les mascottes viennent des coffres et des cartes, les autres de la Ménagerie.",
	JRN_EVO_QUIET          = "…",
	JRN_EVO_STEP           = "Étape %d / %d",
	JRN_EVO_ROAD_TITLE     = "Parcours",
	JRN_NAV_GROUP          = "Carnet",
	JRN_ZONE_STEP_PREV     = "Zone précédente",
	JRN_ZONE_STEP_NEXT     = "Zone suivante",
	JRN_SUB_day            = "Missions du compagnon, du jour et de la semaine : de quoi nourrir ta créature et capturer.",
	JRN_SUB_collection     = "Ce que la route t'a fait gagner : clic pour l'équiper.",
	JRN_SUB_memories       = "Les grands moments de la route, dans l'ordre.",
}
local EN2 = {
	JRN_FILTER_all         = "All",
	JRN_FILTER_ek          = "Eastern Kingdoms",
	JRN_FILTER_ka          = "Kalimdor",
	JRN_FILTER_other       = "Other",
	JRN_SORT_lvl           = "By level",
	JRN_SORT_pct           = "By %",
	JRN_ZONES_SUM          = "%d/%d visited · %d at 100%%",
	JRN_ZONE_LEVELS        = "levels %d-%d",
	JRN_TILE_UNSEEN        = "never visited",
	JRN_TILE_HERE          = "here",
	JRN_TILE_CHEST         = "chest!",
	JRN_UNSEEN_ZONE        = "Never visited: everything will show on your first visit.",
	JRN_MARK               = "%d%%",
	JRN_MARK_TIP           = "Milestones: a treat at 25 and 50%%, a Feast at 75%%, the chest at 100%%.",
	JRN_CARD_UNSEEN        = "???",
	JRN_PREV_HINT_combat   = "Hover a card: the creature shows here.",
	JRN_PREV_HINT_explore  = "The zone's villages and places. A full diamond: visited.",
	JRN_PREV_HINT_quests   = "The zone's quests your character can do. They count toward 100%.",
	JRN_PREV_HINT_craft    = "The resources of your skill that grow here. In colour: already gathered in the zone.",
	JRN_PREV_LEVEL         = "Level: %s",
	JRN_PREV_RANK          = "Rank: %s",
	JRN_PREV_KILLED        = "Defeated: %d",
	JRN_PREV_NOTYET        = "Not defeated yet.",
	JRN_PREV_UNSEEN        = "Never met.",
	JRN_RANK_normal        = "normal",
	JRN_Q_all              = "All",
	JRN_Q_todo             = "To do",
	JRN_Q_done             = "Done",
	JRN_COLL_app           = "Appearances",
	JRN_COLL_orn           = "Ornaments",
	JRN_COLL_frame         = "Frames",
	JRN_COLL_bg            = "Backgrounds",
	JRN_COLL_COUNT         = "%d / %d owned",
	JRN_COLL_EQUIPPED      = "Equipped.",
	JRN_COLL_CLICK         = "Click: equip.",
	JRN_COLL_ORN_ON        = "Worn. Click: take it off.",
	JRN_COLL_ORN_OFF       = "Click: wear it.",
	JRN_COLL_LOCKED        = "Locked.",
	JRN_COLL_SOURCE        = "Source: %s",
	JRN_COLL_SRC_BASE      = "owned from the start",
	JRN_COLL_SRC_TIER      = "zone chest, tier %d",
	JRN_COLL_HINT          = "Hover an item to see it on your creature.",
	JRN_SEC_menagerie      = "Menagerie",
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
	JRN_MEN_SORT_date      = "Sort: capture",
	JRN_MEN_SEARCH         = "Search a name…",
	JRN_MEN_UNKNOWN        = "???",
	JRN_MEN_NEVER          = "Never met: get close, target it.",
	JRN_MEN_NOT_KILLED     = "Not defeated yet",
	JRN_MEN_NONE           = "No creature matches these filters.",
	JRN_BACK_ZONES         = "< Zones",
	JRN_COMBAT_MEN         = "The zone's bestiary lives in the Menagerie: defeated, captured, and the ones left to find.",
	JRN_COMBAT_OPEN        = "Open in the Menagerie",
	JRN_MEN_NO             = "No. %03d",
	JRN_MEN_RANK           = "%s · level %s",
	JRN_MEN_ZONE           = "Zone: %s",
	JRN_MEN_CAUGHT         = "Captured on %s",
	JRN_MEN_NOTYET         = "Not captured yet · chance ~%d%%",
	JRN_MEN_KILLED         = "Defeated %d times",
	JRN_MEN_EQUIP          = "Click: make it your companion",
	JRN_MEN_EQUIPPED       = "It's your companion",
	JRN_MEN_EMPTY          = "No creature met yet: target or hover some monsters.",
	JRN_BACK_HINT          = "Mouse back button: back to the zones.",
	JRN_EVO_TRAIT          = "Character: %s",
	JRN_SUB_companion      = "Your road companion: its mood, its needs, its look.",
	JRN_EVO_STAT_captures  = "captured",
	JRN_EVO_STAT_shiny     = "shinies",
	JRN_EVO_STAT_days      = "days together",
	JRN_EVO_STAT_missions  = "missions done",
	JRN_EVO_LOOKS          = "Its look",
	JRN_EVO_LOOKS_COUNT    = "%d looks",
	JRN_EVO_FRAME          = "Frame",
	JRN_EVO_BG             = "Background",
	JRN_EVO_ORNS           = "Ornaments",
	JRN_EVO_ORN_NONE       = "No ornament yet: zone chests give some.",
	JRN_EVO_LOOK_TIP       = "Click: wear it. Mascots come from chests and cards, the rest from the Menagerie.",
	JRN_EVO_QUIET          = "…",
	JRN_EVO_STEP           = "Stage %d / %d",
	JRN_EVO_ROAD_TITLE     = "Road so far",
	JRN_NAV_GROUP          = "Journal",
	JRN_ZONE_STEP_PREV     = "Previous zone",
	JRN_ZONE_STEP_NEXT     = "Next zone",
	JRN_SUB_day            = "Companion, daily and weekly missions: food for your creature and capture aids.",
	JRN_SUB_collection     = "What the road has earned you: click to equip it.",
	JRN_SUB_memories       = "The big moments of the road, in order.",
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

local function Tip(owner, title, lines)
	local tip = rawget(_G, "GameTooltip")
	if type(tip) ~= "table" then return end
	pcall(tip.SetOwner, tip, owner, "ANCHOR_RIGHT")
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
		for zoneID in pairs(type(source) == "table" and source or {}) do
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
	for index = 1, 5 do
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
		if opts.creature then
			if p.model.SetCreature then pcall(p.model.SetCreature, p.model, opts.creature) end
			p.model.creature = opts.creature
			if ns.ModelShinyLight then ns.ModelShinyLight(p.model, opts.shiny) end
			p.model:Show()
		elseif opts.display then
			if p.model.SetDisplayInfo then pcall(p.model.SetDisplayInfo, p.model, opts.display) end
			p.model.display = opts.display
			p.model:Show()
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
-- (ns.JOURNAL_PANES : JournalCompletion.lua, Memories.lua…)
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
local STAT_H = 54
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
		tile.value:SetPoint("TOP", tile, "TOP", 0, -9)
		tile.value:SetJustifyH("CENTER")
		tile.label = Text(tile, Theme.F_SMALL, Theme.MUTED, statW - 8)
		tile.label:SetPoint("TOP", tile, "TOP", 0, -33)
		tile.label:SetJustifyH("CENTER")
		tile.key = key
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
			if c.def and ns:CompanionSetAppearance(c.def.id) then
				if ns.CompanionApplyModel then pcall(ns.CompanionApplyModel, ns) end
				ns:RefreshJournal()
			end
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

local function BuildMenagerie(self, frame, content)
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.men = pane
	frame.menZone, frame.menState = frame.menZone or "here", frame.menState or "all"
	frame.menRank, frame.menSort, frame.menSearch = frame.menRank or "all", frame.menSort or "no", frame.menSearch or ""
	local function Changed() frame.menOffset = 0; ns:RefreshJournal() end
	-- 1re rangée : zone, rareté, tri
	pane.zone = Theme.CreateDropdown(pane, 200, function(value) frame.menZone = value; Changed() end,
		{ listWidth = 260, maxRows = 14 })
	At(pane.zone, content, 0, TOP)
	pane.rank = Theme.CreateDropdown(pane, 124, function(value) frame.menRank = value; Changed() end)
	At(pane.rank, content, 210, TOP)
	local ranks = {}
	for _, key in ipairs(MEN_RANKS) do ranks[#ranks + 1] = { value = key, label = L["JRN_MEN_RANK_" .. key] } end
	pane.rank:SetOptions(ranks)
	pane.sort = Theme.CreateDropdown(pane, GRID_W - 344, function(value) frame.menSort = value; Changed() end)
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
		Changed()
	end)
	At(pane.stateRow, content, 0, rowY)
	-- la recherche va jusqu'au bord droit (au-dessus de l'aperçu, qui commence
	-- plus bas) : cinq puces d'état tiennent à côté (1.6.0)
	local searchW = math.max(120, INNER - (pane.stateRow.used or 300) - 12)
	pane.search = Theme.CreateSearchBox(pane, searchW, L.JRN_MEN_SEARCH, function(text)
		frame.menSearch = text or ""
		Changed()
	end)
	pane.search:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + INNER, rowY)
	-- la liste, façon Pokédex : numéro, type, nom, marques ; la fiche à droite
	pane.items = {}
	local gridTop = rowY - Theme.CHIP_HEIGHT - 12
	local rowH = MEN_ROW_H
	local count = math.floor((gridTop - PAGER_Y - 12) / rowH)
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
		row.text:SetWidth(GRID_W - 58 - rowH - 128)
		row.label = row.text
		-- nom (ou « ??? ») à la couleur de sa rareté, type à droite, et
		-- l'étoile d'une brillante ; capturée : liseré vert à gauche (1.5.1)
		row.detail:ClearAllPoints()
		row.detail:SetPoint("RIGHT", row, "RIGHT", -30, 0)
		row.detail:SetWidth(90)
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
end

-- Missions : à gauche, celles du compagnon, du jour et de la semaine (avec
-- leur récompense) ; à droite, carte des auberges, garde-manger et besace de
-- capture (Daily.lua, Weekly.lua, Treats.lua, Capture.lua)
local MISSION_H, MISSION_STEP, GROUP_H = 52, 58, 26
-- rangées : 1 = compagnon (mission 3 du jour), 2-3 = jour (missions 1-2),
-- 4-6 = semaine
local MISSION_GROUPS = {
	{ id = "trait", rows = { { daily = 3 } } },
	{ id = "zone",  rows = { { daily = 1 }, { daily = 2 } } },
	{ id = "week",  rows = { { weekly = 1 }, { weekly = 2 }, { weekly = 3 } } },
}
local AID_TILE_H = 64

local function BuildDay(self, frame, content)
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.day = pane
	local rightX = HALF + COL_GAP
	pane.missions, pane.groups = {}, {}
	local y = TOP
	for _, group in ipairs(MISSION_GROUPS) do
		local title = Theme.CreateSection(pane, L["DAY_GROUP_" .. group.id])
		title:SetWidth(HALF)
		At(title, content, 0, y)
		pane.groups[group.id] = title
		y = y - GROUP_H
		for _, slot in ipairs(group.rows) do
			local row = Theme.CreateTile(pane, HALF, MISSION_H, { kind = "Frame" })
			At(row, content, 0, y)
			row.slot, row.group = slot, group.id
			if slot.daily and group.id == "zone" then
				row.reroll = Theme.CreateButton(row, "auto", 18, L.MIS_REROLL, function() ns:MissionReroll(slot.daily) end)
				row.reroll:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -26)
				row.reroll:SetScript("OnEnter", function(b) Tip(b, L.MIS_REROLL, { L.MIS_REROLL_TIP }) end)
				row.reroll:SetScript("OnLeave", HideTip)
			end
			local textW = HALF - 14 - 12 - 70 - 10
			row.label = Text(row, Theme.F_LABEL, Theme.LABEL, textW)
			row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -8)
			if row.label.SetWordWrap then row.label:SetWordWrap(false) end
			row.source = Text(row, Theme.F_SMALL, Theme.MUTED, textW)
			row.source:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -25)
			if row.source.SetWordWrap then row.source:SetWordWrap(false) end
			row.count = Text(row, Theme.F_NUMBER, Theme.PARCHMENT, 70)
			row.count:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -8)
			row.count:SetJustifyH("RIGHT")
			row.bar = Theme.CreateBar(row, HALF - 28, 3)
			row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 14, 7)
			pane.missions[#pane.missions + 1] = row
			y = y - MISSION_STEP
		end
		y = y - 4
	end
	pane.missionsHint = Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, HALF)
	if pane.missionsHint.SetWordWrap then pane.missionsHint:SetWordWrap(true) end
	pane.weekHint = Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, HALF)
	if pane.weekHint.SetWordWrap then pane.weekHint:SetWordWrap(true) end
	pane.perfect = Text(pane, Theme.F_SMALL, Theme.MUTED, HALF)
	if pane.perfect.SetWordWrap then pane.perfect:SetWordWrap(true) end
	pane.hintTop = y + 2

	pane.innTitle = Theme.CreateSection(pane, L.INN_TITLE)
	pane.innTitle:SetWidth(HALF)
	At(pane.innTitle, content, rightX, TOP)
	pane.stamps = {}
	local size, gap = 26, math.floor((HALF - 7 * 26) / 6)
	for index = 1, 7 do
		local stamp = pane:CreateTexture(nil, "ARTWORK")
		stamp:SetSize(size, size)
		At(stamp, content, rightX + (index - 1) * (size + gap), TOP - 28)
		stamp:SetTexture(Theme.DIAMOND_LINE)
		pane.stamps[index] = stamp
	end
	pane.innTotal = Text(pane, Theme.F_LABEL, Theme.LABEL, HALF)
	At(pane.innTotal, content, rightX, TOP - 28 - size - 10)
	pane.innHint = Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, HALF)
	if pane.innHint.SetWordWrap then pane.innHint:SetWordWrap(true) end
	pane.innGift = Text(pane, Theme.F_SMALL, Theme.MUTED, HALF)
	if pane.innGift.SetWordWrap then pane.innGift:SetWordWrap(true) end
	pane.innTop = TOP - 28 - size - 10 - 20

	pane.pantryTitle = Theme.CreateSection(pane, L.DAY_PANTRY)
	pane.pantryTitle:SetWidth(HALF)
	pane.pantryHint = Text(pane, Theme.F_SMALL, Theme.MUTED, HALF)
	if pane.pantryHint.SetWordWrap then pane.pantryHint:SetWordWrap(true) end
	pane.slots = {}
	local count = #(ns.TREAT_KINDS or {})
	local slotW = count > 0 and math.floor((HALF - (count - 1) * 8) / count) or HALF
	for index, kind in ipairs(ns.TREAT_KINDS or {}) do
		local slot = Theme.CreateTile(pane, slotW, 112, { kind = "Frame" })
		slot.kind, slot.slotX = kind, rightX + (index - 1) * (slotW + 8)
		slot.icon = slot:CreateTexture(nil, "ARTWORK")
		slot.icon:SetSize(28, 28)
		slot.icon:SetPoint("TOP", slot, "TOP", 0, -8)
		slot.icon:SetTexture(ns.TREAT_ICONS[kind])
		slot.count = Text(slot, Theme.F_LABEL, Theme.PARCHMENT, slotW - 8)
		slot.count:SetPoint("TOP", slot, "TOP", 0, -40)
		slot.count:SetJustifyH("CENTER")
		slot.name = Text(slot, Theme.F_SMALL, Theme.MUTED_LIGHT, slotW - 8)
		slot.name:SetPoint("TOP", slot, "TOP", 0, -56)
		slot.name:SetJustifyH("CENTER")
		if slot.name.SetWordWrap then slot.name:SetWordWrap(true) end
		slot.give = Theme.CreateButton(slot, slotW - 12, 20, L.DAY_GIVE, function() ns:TreatGive(kind); ns:RefreshJournal() end)
		slot.give:SetPoint("BOTTOM", slot, "BOTTOM", 0, 6)
		pane.slots[index] = slot
	end

	-- besace de capture : les trois aides et leur nombre
	pane.aidTitle = Theme.CreateSection(pane, L.DAY_AIDS)
	pane.aidTitle:SetWidth(HALF)
	pane.aids = {}
	local aids = ns.CAPTURE_AIDS or {}
	local aidW = #aids > 0 and math.floor((HALF - (#aids - 1) * 8) / #aids) or HALF
	for index, aid in ipairs(aids) do
		local tile = Theme.CreateTile(pane, aidW, AID_TILE_H, { kind = "Frame" })
		tile.aid, tile.slotX = aid.id, rightX + (index - 1) * (aidW + 8)
		tile.icon = tile:CreateTexture(nil, "ARTWORK")
		tile.icon:SetSize(28, 28)
		tile.icon:SetPoint("LEFT", tile, "LEFT", 10, 0)
		tile.icon:SetTexture(aid.icon)
		tile.count = Text(tile, Theme.F_LABEL, Theme.PARCHMENT, aidW - 50)
		tile.count:SetPoint("TOPLEFT", tile, "TOPLEFT", 46, -12)
		tile.name = Text(tile, Theme.F_SMALL, Theme.MUTED_LIGHT, aidW - 50)
		tile.name:SetPoint("TOPLEFT", tile, "TOPLEFT", 46, -30)
		if tile.name.SetWordWrap then tile.name:SetWordWrap(true) end
		if tile.EnableMouse then tile:EnableMouse(true) end
		tile:SetScript("OnEnter", function(t)
			Tip(t, ns:CaptureAidLabel(aid.id), { L["CAPTURE_AID_DESC_" .. aid.id], L.DAY_AIDS_HINT })
		end)
		tile:SetScript("OnLeave", HideTip)
		pane.aids[index] = tile
	end
end

-- empile la colonne de droite des Missions (textes de longueur variable)
local function LayoutDay(pane, content)
	local rightX = HALF + COL_GAP
	local y = pane.innTop
	At(pane.innHint, content, rightX, y)
	y = y - Theme.TextHeight(pane.innHint, HALF, Theme.F_SMALL) - 4
	At(pane.innGift, content, rightX, y)
	local gift = Theme.TextHeight(pane.innGift, HALF, Theme.F_SMALL)
	y = y - gift - (gift > 0 and 4 or 0)
	-- les jours aux trois missions : ici, la colonne de gauche est pleine
	At(pane.perfect, content, rightX, y)
	local perfect = Theme.TextHeight(pane.perfect, HALF, Theme.F_SMALL)
	y = y - perfect - 14
	At(pane.pantryTitle, content, rightX, y)
	y = y - 22
	At(pane.pantryHint, content, rightX, y)
	y = y - Theme.TextHeight(pane.pantryHint, HALF, Theme.F_SMALL) - 8
	for _, slot in ipairs(pane.slots) do At(slot, content, slot.slotX, y) end
	y = y - 112 - 16
	At(pane.aidTitle, content, rightX, y)
	y = y - 24
	for _, tile in ipairs(pane.aids) do At(tile, content, tile.slotX, y) end
	pane.pantryBottom = y - AID_TILE_H
	-- colonne de gauche : les aides des missions, puis les jours parfaits
	local left = pane.hintTop
	At(pane.missionsHint, content, 0, left)
	left = left - Theme.TextHeight(pane.missionsHint, HALF, Theme.F_SMALL) - 4
	At(pane.weekHint, content, 0, left)
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
			Tip(b, ns:TreatLabel(b.kind), { L["TREAT_DESC_" .. b.kind], ns:F("TREAT_COUNT", ns:TreatCount(b.kind), ns:TreatCap(b.kind)) })
		end)
		button:SetScript("OnLeave", function(b)
			b.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1)
			HideTip()
		end)
		frame.pantry[kind] = button
		x = x + 30 + 8
	end
end

function ns:EnsureJournalWindow()
	if self.journalFrame then return self.journalFrame end
	if not Theme or not Theme.CreateWindow then return nil end
	local frame = Theme.CreateWindow(UIParent, WIDTH, HEIGHT, { name = "Ready2QuestJournalFrame", nav = NAV_W, footer = FOOTER_H })
	if not frame then return nil end
	frame.chrome = "journal"
	if self.RestorePoint then self:RestorePoint(frame, "journalPoint", { point = "CENTER", x = 0, y = 20 }) end
	frame.kind, frame.activity, frame.offset = "evolution", "explore", 0
	frame.zoneFilter, frame.zoneSort, frame.zoneOffset = "all", "lvl", 0
	frame.questFilter, frame.collKind = "all", "app"
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
		local builtin = section == "evolution" or (section == "memories" and self.BuildMemoriesPane)
			or (section == "day" and self.DailyData) or (section == "menagerie" and self.MenagerieList)
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
	if self.BuildMemoriesPane then self:BuildMemoriesPane(frame, content, { pad = PAD, top = TOP, width = INNER,
		pagerTop = PAGER_Y }) end
	BuildPantry(self, frame)

	if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
	frame:SetScript("OnMouseWheel", function(_, delta) ns:ScrollJournal(delta) end)
	frame.closeButton = Theme.CreateButton(frame.footer, "auto", 28, L.OPT_CLOSE, function() frame:Hide() end, "accent")
	frame.closeButton:SetPoint("RIGHT", frame.footer, "RIGHT", -PAD, 0)
	frame:Hide()
	self.journalFrame = frame
	return frame
end


-- ---------------------------------------------------------------------------
-- Navigation
-- ---------------------------------------------------------------------------
-- « goals » / « evolution » : Créature ; « memories », « zones »,
-- « collection » ; tout le reste : Zone (« completion », ou un ancien nom)
local function KindOf(frame, kind)
	local external = ns.JOURNAL_PANES[kind]
	if external and frame[external.field] then return kind end
	-- anciens noms (Zones, Zone, Collection, Jour) : leur page d'aujourd'hui
	local progress = ns.JOURNAL_PANES.progress
	if (kind == "zones" or kind == "completion") and progress and frame[progress.field] then return "progress" end
	if kind == "memories" and frame.mem then return "memories" end
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
	elseif frame.kind == "memories" then
		frame.offset = (frame.offset or 0) - delta
	else
		frame.offset = (frame.offset or 0) - delta * (frame.step or 1)
	end
	self:RefreshJournal()
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
-- Jours passés ensemble : depuis le premier souvenir (ou le premier passage
-- par cette page, pour un compagnon d'avant la 1.5.0)
function ns:CompanionSince()
	local data = self:CompanionData()
	if not tonumber(data.since) then
		local oldest
		local mem = self.MemoryData and self:MemoryData()
		for _, memory in ipairs(mem and mem.memories or {}) do
			local at = tonumber(memory.at)
			if at and at > 0 and (not oldest or at < oldest) then oldest = at end
		end
		local now = tonumber((select(2, pcall(rawget(_G, "time") or function() return 0 end)))) or 0
		data.since = oldest or now
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
	if cell.model and cell.lookKey ~= key then
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
		tile.label:SetText(key == "km" and L.TRAVEL_LABEL or L["JRN_EVO_STAT_" .. key])
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
	local rank = L["CAPTURE_RANK_" .. tostring(entry.class or "normal")]
	local lines = { self:F("JRN_MEN_RANK", rank, LevelText(entry)) }
	if entry.zoneID then lines[#lines + 1] = self:F("JRN_MEN_ZONE", ZoneName(self, entry.zoneID)) end
	if not entry.known then
		lines[#lines + 1] = L.JRN_MEN_NEVER
		PreviewSet(frame.men.preview, L.JRN_MEN_UNKNOWN, lines, {})
		frame.men.preview.entry = entry
		return
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
		if when then lines[#lines + 1] = self:F(shinyView and "JRN_MEN_SHINY_CAUGHT" or "JRN_MEN_CAUGHT", when) end
		lines[#lines + 1] = current == id and L.JRN_MEN_EQUIPPED or L.JRN_MEN_EQUIP
	else
		local chance = self.CaptureChance and self:CaptureChance({ class = entry.class, level = entry.level or entry.lo }) or 0
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
end

-- Clic : une créature capturée devient le compagnon
-- La version montrée dans la fiche si elle est capturée, sinon l'autre
function ns:JournalMenagerieEquip(entry)
	if not (entry and entry.captured and self.CompanionSetAppearance) then return false end
	local preview = self.journalFrame and self.journalFrame.men and self.journalFrame.men.preview
	local wantShiny = preview and preview.entry and preview.entry.npc == entry.npc and preview.shiny == true
	local hasNormal, hasShiny = entry.normal ~= false, entry.shiny == true
	local shiny = (wantShiny and hasShiny) or (not hasNormal and hasShiny)
	if not self:CompanionSetAppearance("cap:" .. tostring(entry.npc) .. (shiny and ":s" or "")) then return false end
	if self.CompanionApplyModel then pcall(self.CompanionApplyModel, self) end
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	self:RefreshJournal()
	self:JournalPreviewMenagerie(entry)
	return true
end

-- La Ménagerie d'une zone (bouton de la fiche de zone, onglet Combat)
function ns:OpenMenagerieZone(zoneID)
	local frame = self:EnsureJournalWindow()
	if not frame then return end
	frame.menZone = tonumber(zoneID) or "here"
	frame.menState, frame.menRank, frame.menSearch, frame.menOffset = "all", "all", "", 0
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
	pane.zone:SetOptions(MenagerieZoneOptions(self))
	pane.zone:SetValue(frame.menZone or "here")
	pane.rank:SetValue(frame.menRank or "all")
	pane.sort:SetValue(frame.menSort or "no")
	pane.stateRow:Select(frame.menState or "all", true)
	local list, stats = self:MenagerieList({ zone = self:MenagerieZoneValue(frame.menZone or "here"),
		state = frame.menState, rank = frame.menRank, search = frame.menSearch, sort = frame.menSort })
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
			local lc = RarityColor(entry)
			row.label:SetTextColor(lc[1], lc[2], lc[3])
			row.label:SetAlpha(entry.known and 1 or 0.75)
			row.detail:SetText(entry.known and (entry.type or "") or "")
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
			local mc = worn and Theme.GOLD or { 1, 1, 1 }
			row.mark:SetVertexColor(mc[1], mc[2], mc[3], worn and 0.12 or 0.05)
			row:Show()
		else
			row:Hide()
		end
	end
	pane.pager:Update(frame.menOffset, page, #list, maxOffset)
	local still = false
	for _, entry in ipairs(list) do if shown and entry.npc == shown.npc then still = true end end
	if list[1] and not still then self:JournalPreviewMenagerie(list[1])
	elseif not list[1] then PreviewSet(pane.preview, "", {}, {}); pane.preview.entry = nil end
end

local function MissionRow(self, row, mission, label, reward)
	row.mission = mission
	row.label:SetText(label)
	row.source:SetText(reward or "")
	row.count:SetText(mission.done and (Theme.T_GREEN .. L.MIS_DONE .. "|r")
		or string.format("%d/%d", mission.have or 0, mission.need))
	row.bar:SetValue((mission.have or 0) / mission.need)
	local c = mission.done and Theme.GREEN or (row.group == "week" and Theme.BLUE or Theme.GOLD)
	row.bar:SetColor(c[1], c[2], c[3], 1)
	row.bar:Show()
	row:SetAccent(c)
	row:Show()
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
	pane.groups.trait:SetText(L.DAY_GROUP_trait, traitLabel)
	pane.groups.week:SetText(L.DAY_GROUP_week, weekly and self.WeeklyEndsText and self:WeeklyEndsText() or nil)
	local firstEmpty = {}
	for _, row in ipairs(pane.missions) do
		local mission, label, reward
		if row.slot.daily and on and today then
			mission = daily.missions[row.slot.daily]
			if mission then
				label = self:MissionLabel(mission)
				reward = self.MissionRewardText and self:MissionRewardText(mission.source == "trait" and "trait" or "zone")
			end
		elseif row.slot.weekly and weekly then
			mission = weekly.missions[row.slot.weekly]
			if mission then
				label = self:WeeklyLabel(mission)
				reward = self.MissionRewardText and self:MissionRewardText("weekly")
			end
		end
		if mission then
			MissionRow(self, row, mission, label, reward)
			if row.reroll then
				if not mission.done and not daily.rerolled then row.reroll:Show() else row.reroll:Hide() end
			end
			row.bar:SetWidth(row.reroll and row.reroll:IsShown() and (HALF - 28 - row.reroll:GetWidth() - 8) or (HALF - 28))
		else
			-- un groupe vide : une seule rangée qui explique
			local empty = not firstEmpty[row.group]
			firstEmpty[row.group] = true
			row.mission = nil
			row.label:SetText(empty and (on and L.MIS_NONE or L.MIS_OFF) or "")
			row.source:SetText("")
			row.count:SetText("")
			row.bar:Hide()
			if row.reroll then row.reroll:Hide() end
			row:SetAccent(nil)
			if empty then row:Show() else row:Hide() end
		end
	end
	pane.missionsHint:SetText(on and today and (daily.allDone and L.MIS_RENEW or L.MIS_ALL_BONUS) or "")
	pane.weekHint:SetText(weekly and (weekly.allDone and L.WK_ALL_DONE or L.WK_ALL_BONUS) or "")
	for index, stamp in ipairs(pane.stamps) do
		local got = index <= inn.card
		stamp:SetTexture(got and Theme.DIAMOND or Theme.DIAMOND_LINE)
		local c = got and Theme.GOLD or Theme.MUTED
		stamp:SetVertexColor(c[1], c[2], c[3], 1)
		stamp.got = got
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
		slot.name:SetText(self:TreatLabel(slot.kind))
		if slot.icon.SetDesaturated then slot.icon:SetDesaturated(count == 0) end
		if count > 0 then slot.give:Show() else slot.give:Hide() end
		slot:SetAccent(count > 0 and Theme.GOLD or nil)
	end
	for _, tile in ipairs(pane.aids) do
		local count = self.CaptureAidCount and self:CaptureAidCount(tile.aid) or 0
		local cap
		for _, def in ipairs(ns.CAPTURE_AIDS or {}) do if def.id == tile.aid then cap = def.cap end end
		tile.count:SetText(self:F("TREAT_COUNT", count, cap or 0))
		tile.name:SetText(self:CaptureAidLabel(tile.aid))
		if tile.icon.SetDesaturated then tile.icon:SetDesaturated(count == 0) end
		tile:SetAccent(count > 0 and Theme.GOLD or nil)
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

local PANES = { day = "day", evolution = "evo", memories = "mem", menagerie = "men" }
function ns:RefreshJournal()
	local frame = self.journalFrame
	if not frame then return end
	local section = KindOf(frame, frame.kind)
	frame.kind = section
	frame.header.title:SetWidth(INNER - 100)
	for key, item in pairs(frame.sections) do item:SetSelected(key == section) end
	local counts = self:JournalCounts()
	frame.subtitle:SetText(self:F("JRN_TOTAL", counts.total)
		.. (ModuleOn() and "" or ("|n" .. Theme.T_GREY .. L.MODULE_OFF .. "|r")))
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
	if ns.JOURNAL_PANES[section] then
		local def = ns.JOURNAL_PANES[section]
		frame.header:SetTitle(def.title and L[def.title] or "")
		frame.header:SetSubtitle(def.subtitle and L[def.subtitle] or "")
		local ok, err = pcall(def.refresh, self, frame, ns.JournalUI)
		if not ok and self.RecordError then self:RecordError("journal:" .. section, err) end
	elseif section == "memories" then
		frame.header:SetTitle(L.JRN_SEC_memories)
		frame.header:SetSubtitle(L.JRN_SUB_memories)
		self:RefreshMemoriesPane(frame)
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