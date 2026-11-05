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
	JRN_SEC_completion     = "Zone",
	JRN_SEC_evolution      = "Créature",
	JRN_SEC_memories       = "Souvenirs",
	JRN_ZONE_PICK          = "Zone : %s",
	JRN_ZONE_HERE          = "%s (ici)",
	JRN_ZONE_NONE          = "Aucune zone pour l'instant : explore, ton carnet se remplit tout seul.",
	JRN_ACT_explore        = "Exploration",
	JRN_ACT_combat         = "Combat",
	JRN_ACT_craft          = "Métiers",
	JRN_ACT_quests         = "Quêtes",
	JRN_QUESTS_TIP         = "Les quêtes de la zone que ton personnage peut faire (race, classe), livrées avec l'addon. Elles comptent dans les 100 %.",
	JRN_WATCH              = "Suivre à l'écran",
	JRN_WATCH_TIP          = "Cochée : les objectifs de cette zone s'affichent dans le bloc « Carnet » en jeu. La zone où tu es est suivie d'office ; décoche-la pour la masquer.",
	JRN_ACT_EMPTY_explore  = "Aucun village connu dans cette zone.",
	JRN_ACT_EMPTY_combat   = "Aucune créature croisée ici : cible-les ou survole-les pour les noter.",
	JRN_ACT_EMPTY_craft    = "Pas de métier de récolte (herboristerie, minage ou dépeçage), ou rien de ta compétence ici.",
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
	JRN_EVO_HOW_3          = "Finis une zone à 100 %% (onglet Zone) : un coffre s'ouvre, tu y choisis une apparence, un ornement, un cadre ou un fond.",
	JRN_EVO_CHESTS         = "Coffres à ouvrir : %d",
	JRN_EVO_COLLECTION     = "Collection : %d/%d  (palier 1 : %d/%d · palier 2 : %d/%d · palier 3 : %d/%d)",
	JRN_EVO_ROAD           = "Parcours : %d zones · %d/%d capitales · %d donjons · %d rares · %d/%d paliers",
}
local EN = {
	JRN_SEC_completion     = "Zone",
	JRN_SEC_evolution      = "Creature",
	JRN_SEC_memories       = "Memories",
	JRN_ZONE_PICK          = "Zone: %s",
	JRN_ZONE_HERE          = "%s (here)",
	JRN_ZONE_NONE          = "No zone yet: explore, your journal fills itself.",
	JRN_ACT_explore        = "Exploration",
	JRN_ACT_combat         = "Combat",
	JRN_ACT_craft          = "Professions",
	JRN_ACT_quests         = "Quests",
	JRN_QUESTS_TIP         = "The zone's quests your character can do (race, class), shipped with the addon. They count toward 100%.",
	JRN_WATCH              = "Track on screen",
	JRN_WATCH_TIP          = "Checked: this zone's goals show in the in-game \"Journal\" tracker. The zone you are in is tracked by default; uncheck it to hide it.",
	JRN_ACT_EMPTY_explore  = "No known village in this zone.",
	JRN_ACT_EMPTY_combat   = "No creature met here yet: target or hover them to log them.",
	JRN_ACT_EMPTY_craft    = "No gathering profession (herbalism, mining or skinning), or nothing of your skill here.",
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
	JRN_EVO_HOW_3          = "Complete a zone to 100 %% (Zone tab): a chest opens and you pick a look, an ornament, a frame or a background.",
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

-- Récolte : les ressources de ta tranche, récoltées ou non dans cette zone
local function GatheringItems(self, zoneID)
	local items = {}
	if not (self.GatheringZoneBand and self.GatheringData) then return items end
	local data = self:GatheringData()
	-- zone préremplie (ZoneGathering_<client>.lua) : seulement ce qui y pousse
	for _, entry in ipairs((self:GatheringZoneBand(zoneID))) do
		local record = data[entry.itemID]
		local done = record and type(record.zones) == "table" and (tonumber(record.zones[zoneID]) or 0) > 0
		items[#items + 1] = { name = entry.name, done = done == true, req = entry.req, itemID = entry.itemID,
			detail = done and L.JRN_ITEM_GATHERED or self:F("JRN_ITEM_TO_GATHER", entry.req) }
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
local SECTIONS = { "evolution", "zones", "completion", "day", "collection", "memories" }
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
	JRN_SEC_zones          = "Zones",
	JRN_SEC_collection     = "Collection",
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
	JRN_BACK_HINT          = "Bouton retour de la souris : revenir aux zones.",
	JRN_EVO_TRAIT          = "Caractère : %s",
	JRN_EVO_STEP           = "Étape %d / %d",
	JRN_EVO_ROAD_TITLE     = "Parcours",
	JRN_NAV_GROUP          = "Carnet",
	JRN_ZONE_STEP_PREV     = "Zone précédente",
	JRN_ZONE_STEP_NEXT     = "Zone suivante",
	JRN_SUB_day            = "Les missions du jour, la carte des auberges et le garde-manger.",
	JRN_SUB_collection     = "Ce que la route t'a fait gagner : clic pour l'équiper.",
	JRN_SUB_memories       = "Les grands moments de la route, dans l'ordre.",
}
local EN2 = {
	JRN_SEC_zones          = "Zones",
	JRN_SEC_collection     = "Collection",
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
	JRN_BACK_HINT          = "Mouse back button: back to the zones.",
	JRN_EVO_TRAIT          = "Character: %s",
	JRN_EVO_STEP           = "Stage %d / %d",
	JRN_EVO_ROAD_TITLE     = "Road so far",
	JRN_NAV_GROUP          = "Journal",
	JRN_ZONE_STEP_PREV     = "Previous zone",
	JRN_ZONE_STEP_NEXT     = "Next zone",
	JRN_SUB_day            = "Today's missions, the inn loyalty card and the pantry.",
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
local function BuildZones(self, frame, content)
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.zones = pane
	pane.filterRow, pane.filters = Chips(pane, { "all", "ek", "ka", "other" }, "JRN_FILTER_", function(key)
		frame.zoneFilter, frame.zoneOffset = key, 0
		ns:RefreshJournal()
	end)
	At(pane.filterRow, content, 0, TOP)
	pane.sortRow, pane.sorts = Chips(pane, { "lvl", "pct" }, "JRN_SORT_", function(key)
		frame.zoneSort, frame.zoneOffset = key, 0
		ns:RefreshJournal()
	end)
	pane.sortRow:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + INNER, TOP)
	pane.summary = frame.header.subtitle
	pane.tiles = {}
	local listTop = TOP - Theme.CHIP_HEIGHT - 14
	for index = 1, ZONE_COLS * ZONE_ROWS do
		local col, row = (index - 1) % ZONE_COLS, math.floor((index - 1) / ZONE_COLS)
		local tile = Theme.CreateTile(pane, ZONE_W, ZONE_H)
		At(tile, content, col * (ZONE_W + 12), listTop - row * ZONE_STEP)
		tile:SetFill(row % 2 == 1 and Theme.ROW_ALT or Theme.ROW)
		tile.rowFill = row % 2 == 1 and Theme.ROW_ALT or Theme.ROW
		tile.name = Text(tile, Theme.F_LABEL, Theme.LABEL, ZONE_W - 14 - 128)
		tile.name:SetPoint("TOPLEFT", tile, "TOPLEFT", 14, -4)
		if tile.name.SetWordWrap then tile.name:SetWordWrap(false) end
		tile.levels = Text(tile, Theme.F_SMALL, Theme.MUTED, 110)
		tile.levels:SetPoint("TOPLEFT", tile, "TOPLEFT", 14, -19)
		tile.percent = Text(tile, Theme.F_LABEL, Theme.PARCHMENT)
		tile.percent:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -14, -4)
		tile.percent:SetJustifyH("RIGHT")
		tile.bar = Theme.CreateBar(tile, 96, 3)
		tile.bar:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -14, -23)
		tile.badge = Text(tile, Theme.F_SMALL, Theme.MUTED_LIGHT, ZONE_W - 14 - 110 - 14 - 96 - 10)
		tile.badge:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -14 - 96 - 10, -18)
		tile.badge:SetJustifyH("RIGHT")
		if tile.badge.SetWordWrap then tile.badge:SetWordWrap(false) end
		tile:SetScript("OnClick", function(t) if t.zoneID then ns:OpenJournalZone(t.zoneID) end end)
		tile.onEnter = function(t)
			if not t.zone then return end
			local zone = t.zone
			local lines = { zone.seen and (zone.percent and ns:F("JRN_ZONE_PERCENT", zone.percent) or L.JRN_ZONE_NOPCT)
				or L.JRN_TILE_UNSEEN }
			if zone.lo < 99 then lines[#lines + 1] = ns:F("JRN_ZONE_LEVELS", zone.lo, zone.hi) end
			Tip(t, zone.name, lines)
		end
		tile.onLeave = HideTip
		tile:Hide()
		pane.tiles[index] = tile
	end
	Pager(pane, content)
end

-- Zone : progression (paliers, coffre), activités en onglets, fiches et aperçu
local function BuildCompletion(self, frame, content)
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.comp = pane
	pane.title, pane.levels = frame.header.title, frame.header.subtitle

	-- zone précédente / suivante : à gauche du [×], dans l'en-tête
	pane.next = Theme.CreateButton(pane, 24, 24, ">", function() ns:StepJournalZone(1) end)
	pane.next:SetPoint("TOPRIGHT", content, "TOPRIGHT", -13 - 24 - 10, -13)
	pane.prev = Theme.CreateButton(pane, 24, 24, "<", function() ns:StepJournalZone(-1) end)
	pane.prev:SetPoint("RIGHT", pane.next, "LEFT", -6, 0)
	for _, b in ipairs({ pane.prev, pane.next }) do
		local tip = b == pane.prev and L.JRN_ZONE_STEP_PREV or L.JRN_ZONE_STEP_NEXT
		b:HookScript("OnEnter", function(owner) Tip(owner, tip, { L.JRN_BACK_HINT }) end)
		b:HookScript("OnLeave", HideTip)
	end

	-- carte de progression : grand pourcentage, barre et paliers, coffre
	local card = Theme.CreateTile(pane, INNER, 80, { kind = "Frame" })
	At(card, content, 0, TOP)
	pane.card = card
	pane.percent = Text(card, Theme.F_DISPLAY, Theme.PARCHMENT)
	pane.percent:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -24)
	local barX, barW = 120, INNER - 120 - 18
	pane.bar = Theme.CreateBar(card, barW, 6)
	pane.bar:SetPoint("TOPLEFT", card, "TOPLEFT", barX, -18)
	pane.marks = {}
	for index, mark in ipairs(MARKS) do
		local m = Text(card, Theme.F_SMALL, Theme.MUTED)
		m:SetPoint("TOPRIGHT", card, "TOPLEFT", barX + math.floor(barW * mark / 100), -30)
		m:SetJustifyH("RIGHT")
		m.mark = mark
		pane.marks[index] = m
	end
	pane.marksHover = CreateFrame("Frame", nil, card)
	pane.marksHover:SetPoint("TOPLEFT", card, "TOPLEFT", barX, -12)
	pane.marksHover:SetSize(barW, 32)
	pane.marksHover:SetScript("OnEnter", function(owner) Tip(owner, ns:F("JRN_MARK_TIP"), {}) end)
	pane.marksHover:SetScript("OnLeave", HideTip)
	pane.openChest = Theme.CreateButton(card, "auto", 24, L.JRN_OPEN_CHEST, function()
		if frame.zoneID then ns:OpenChest(frame.zoneID) end
	end, "primary")
	pane.openChest:SetPoint("TOPRIGHT", card, "TOPRIGHT", -18, -48)
	pane.chest = Text(card, Theme.F_BODY, Theme.LABEL, barW - pane.openChest:GetWidth() - 16)
	pane.chest:SetPoint("TOPLEFT", card, "TOPLEFT", barX, -54)
	if pane.chest.SetWordWrap then pane.chest:SetWordWrap(false) end

	-- activités : onglets soulignés ; suivre la zone à l'écran, à droite
	local tabsY = TOP - 80 - 10
	pane.tabBar = Theme.CreateTabs(pane, function(id) ns:SelectJournalActivity(id) end)
	At(pane.tabBar, content, 0, tabsY)
	pane.tabBar:SetWidth(INNER)
	local defs = {}
	for _, activity in ipairs(ACTIVITIES) do defs[#defs + 1] = { id = activity, label = L["JRN_ACT_" .. activity] } end
	pane.tabBar:SetTabs(defs)
	pane.tabs = pane.tabBar.byId
	local questsTab = pane.tabs.quests
	if questsTab and questsTab.HookScript then
		-- l'onglet dit ce qu'il compte, ou qu'il n'a pas de liste pour ce client
		questsTab:HookScript("OnEnter", function(owner)
			local available = ns.ZoneQuestsAvailable and ns:ZoneQuestsAvailable()
			Tip(owner, L.JRN_ACT_quests, { available and L.JRN_QUESTS_TIP or L.JRN_ACT_NO_QUESTS })
		end)
		questsTab:HookScript("OnLeave", HideTip)
	end
	pane.watch = Theme.CreateToggle(pane, 32, 15, "Button")
	pane.watch:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + INNER, tabsY - 8)
	pane.watch:SetScript("OnClick", function()
		if frame.zoneID then ns:JournalSetWatched(frame.zoneID, not ns:JournalIsWatched(frame.zoneID)) end
	end)
	pane.watch:SetScript("OnEnter", function(owner) Tip(owner, L.JRN_WATCH, { L.JRN_WATCH_TIP }) end)
	pane.watch:SetScript("OnLeave", HideTip)
	pane.watchLabel = Text(pane, Theme.F_BODY, Theme.LABEL)
	pane.watchLabel:SetPoint("RIGHT", pane.watch, "LEFT", -10, 0)
	pane.watchLabel:SetJustifyH("RIGHT")
	pane.watchLabel:SetText(L.JRN_WATCH)

	-- en-têtes des parts (« Bestiaire : 4/15 · Nommés : 0/1 ») et filtre des quêtes
	local headsY = tabsY - Theme.TABS_HEIGHT - 10
	pane.questRow, pane.questFilter = Chips(pane, { "all", "todo", "done" }, "JRN_Q_", function(key)
		frame.questFilter, frame.offset = key, 0
		ns:RefreshJournal()
	end)
	pane.questRow:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + INNER, headsY + 2)
	pane.heads = Text(pane, Theme.F_LABEL, Theme.GOLD, INNER - pane.questRow.used - 16)
	At(pane.heads, content, 0, headsY - 3)
	if pane.heads.SetWordWrap then pane.heads:SetWordWrap(false) end
	local gridTop = headsY - Theme.CHIP_HEIGHT - 10
	pane.gridTop = gridTop

	-- listes sur deux colonnes (Exploration, Quêtes), toute la largeur
	pane.lines = {}
	for index = 1, LIST_COLS * LIST_ROWS do
		local col, row = (index - 1) % LIST_COLS, math.floor((index - 1) / LIST_COLS)
		local line = Theme.CreateListRow(pane, LIST_W, LIST_ROW_H - 2, { status = 9, detail = true })
		At(line, content, col * (LIST_W + 12), gridTop - row * LIST_ROW_H)
		line:SetIndex(row + 1)
		line.rowAlt = line.alt
		line.stamp, line.name = line.status, line.text
		line.detail:SetWidth(96)
		line.name:SetWidth(LIST_W - line.textLeft - 96 - 12 - 8)
		line:Hide()
		pane.lines[index] = line
	end

	-- fiches du bestiaire (Combat) : portrait, rang, tampon ; l'aperçu à droite
	pane.cards = {}
	for index = 1, CARD_COLS * CARD_ROWS do
		local col, row = (index - 1) % CARD_COLS, math.floor((index - 1) / CARD_COLS)
		local card = Theme.CreateTile(pane, CARD_W, CARD_H)
		At(card, content, col * (CARD_W + 10), gridTop - row * (CARD_H + CARD_GAP))
		card.portrait = CreateFrame("Frame", nil, card)
		card.portrait:SetSize(CARD_H - 10, CARD_H - 10)
		card.portrait:SetPoint("LEFT", card, "LEFT", 9, 0)
		card.portrait.bg = Theme.Solid(card.portrait, "BACKGROUND", Theme.FIELD, 1)
		card.portrait.bg:SetAllPoints()
		card.portrait.border = Theme.Border(card.portrait, Theme.EDGE_SOFT, 1)
		card.portrait.unknown = Text(card.portrait, Theme.F_TITLE, Theme.MUTED)
		card.portrait.unknown:SetPoint("CENTER", card.portrait, "CENTER", 0, 0)
		card.portrait.unknown:SetJustifyH("CENTER")
		card.portrait.unknown:SetText("?")
		local okModel, model = pcall(CreateFrame, "PlayerModel", nil, card.portrait)
		if okModel and model then
			model:SetPoint("TOPLEFT", card.portrait, "TOPLEFT", 1, -1)
			model:SetPoint("BOTTOMRIGHT", card.portrait, "BOTTOMRIGHT", -1, 1)
			card.model = model
		end
		local textX = 9 + CARD_H - 10 + 10
		card.textX = textX
		card.name = Text(card, Theme.F_LABEL, Theme.PARCHMENT, CARD_W - textX - 46)
		card.name:SetPoint("TOPLEFT", card, "TOPLEFT", textX, -8)
		if card.name.SetWordWrap then card.name:SetWordWrap(false) end
		card.rank = Theme.CreateTag(card, "", Theme.GOLD)
		card.rank:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -24)
		card.detail = Text(card, Theme.F_SMALL, Theme.MUTED_LIGHT, CARD_W - textX - 10 - 60)
		card.detail:SetPoint("TOPLEFT", card, "TOPLEFT", textX, -25)
		if card.detail.SetWordWrap then card.detail:SetWordWrap(false) end
		-- tampon : losange plein ambre une fois abattue, au trait sinon
		card.stamp = Theme.CreateDiamond(card, 10, true)
		card.stamp:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -9)
		card.star = card:CreateTexture(nil, "OVERLAY")
		card.star:SetSize(14, 14)
		card.star:SetPoint("RIGHT", card.stamp, "LEFT", -4, 0)
		card.star:SetTexture(ns.SHINY_STAR or "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
		card.star:Hide()
		card.onEnter = function(c) if c.item then ns:JournalPreviewCreature(c.item) end end
		card:SetScript("OnClick", function(c) if c.item then ns:JournalPreviewCreature(c.item) end end)
		card:Hide()
		pane.cards[index] = card
	end

	-- ressources (Métiers)
	pane.icons = {}
	for index = 1, ICON_COLS * ICON_ROWS do
		local col, row = (index - 1) % ICON_COLS, math.floor((index - 1) / ICON_COLS)
		local icon = CreateFrame("Button", nil, pane)
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		At(icon, content, col * ICON_STEP_X, gridTop - row * ICON_STEP_Y)
		icon.border = Theme.Border(icon, Theme.EDGE, 1)
		icon.tex = icon:CreateTexture(nil, "ARTWORK")
		icon.tex:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
		icon.tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
		if icon.tex.SetTexCoord then icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
		icon.req = Theme.Text(icon, Theme.F_NUMBER, Theme.PARCHMENT)
		icon.req:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
		icon:SetScript("OnEnter", function(i)
			if i.item then Tip(i, i.item.name, { tostring(i.item.detail or "") }) end
		end)
		icon:SetScript("OnLeave", HideTip)
		icon:Hide()
		pane.icons[index] = icon
	end

	pane.empty = Text(pane, Theme.F_BODY, Theme.MUTED_LIGHT, INNER)
	At(pane.empty, content, 0, gridTop - 6)
	if pane.empty.SetWordWrap then pane.empty:SetWordWrap(true) end
	Pager(pane, content)
	pane.preview = BuildPreview(pane, content, INNER - PREVIEW_W, gridTop, gridTop - PAGER_Y - 12)
end

-- Créature : portrait, étape, envies, comment elle évolue, parcours
local HERO_H, EVO_ROW, EVO_STEP = 104, 32, 36
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
		hero.portrait = self:CompanionPortrait(hero, 72)
		hero.portrait:SetPoint("LEFT", hero, "LEFT", 16, 0)
	end
	local textX = 16 + 72 + 18
	pane.name = Text(hero, Theme.F_TITLE, Theme.PARCHMENT, 300)
	pane.name:SetPoint("TOPLEFT", hero, "TOPLEFT", textX, -22)
	if pane.name.SetWordWrap then pane.name:SetWordWrap(false) end
	pane.look = Text(hero, Theme.F_BODY, Theme.MUTED_LIGHT, 300)
	pane.look:SetPoint("TOPLEFT", hero, "TOPLEFT", textX, -44)
	if pane.look.SetWordWrap then pane.look:SetWordWrap(false) end
	pane.trait = Text(hero, Theme.F_SMALL, Theme.MUTED_LIGHT, 300)
	pane.trait:SetPoint("TOPLEFT", hero, "TOPLEFT", textX, -66)
	if pane.trait.SetWordWrap then pane.trait:SetWordWrap(false) end
	-- étapes : un losange par étape, plein jusqu'à l'actuelle
	local rightX = INNER - 300
	pane.stageLabel = Text(hero, Theme.F_CAPS, Theme.GOLD)
	pane.stageLabel:SetPoint("TOPLEFT", hero, "TOPLEFT", rightX, -22)
	pane.steps = {}
	for index = 1, #(ns.COMPANION_STAGES or {}) do
		local step = Theme.CreateDiamond(hero, 11, true)
		step:SetPoint("TOPLEFT", hero, "TOPLEFT", rightX + 110 + (index - 1) * 18, -21)
		pane.steps[index] = step
	end
	pane.next = Text(hero, Theme.F_BODY, Theme.TEXT, 300 - 16)
	pane.next:SetPoint("TOPLEFT", hero, "TOPLEFT", rightX, -44)
	if pane.next.SetWordWrap then pane.next:SetWordWrap(true) end

	-- deux colonnes : envies à gauche, comment ça marche à droite
	local colY = TOP - HERO_H - 22
	pane.needsTitle = Theme.CreateSection(pane, "")
	pane.needsTitle:SetWidth(HALF)
	At(pane.needsTitle, content, 0, colY)
	pane.needs = {}
	for index, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do
		local row = Theme.CreateListRow(pane, HALF, EVO_ROW, { detail = true, font = Theme.F_LABEL })
		At(row, content, 0, colY - 28 - (index - 1) * EVO_STEP)
		row:SetIndex(index)
		row.key = key
		row.label, row.value = row.text, row.detail
		row.value:SetWidth(52)
		row.bar = Theme.CreateBar(row, HALF - 120 - 76, 4)
		row.bar:SetPoint("LEFT", row, "LEFT", 120, 0)
		-- survol sur toute la carte : quoi faire pour la remplir (la carte
		-- s'éclaire comme une ligne cliquable)
		row.shine = row.hover
		row.hover = CreateFrame("Button", nil, row)
		row.hover:SetAllPoints()
		row.hover:SetScript("OnEnter", function(region) row.shine:Show(); ns:ShowNeedTooltip(region, key) end)
		row.hover:SetScript("OnLeave", function() row.shine:Hide(); HideTip() end)
		pane.needs[index] = row
	end
	local rightCol = HALF + COL_GAP
	pane.howTitle = Theme.CreateSection(pane, "")
	pane.howTitle:SetWidth(HALF)
	At(pane.howTitle, content, rightCol, colY)
	pane.how, pane.howNumbers = {}, {}
	for index = 1, 3 do
		local number = Text(pane, Theme.F_LABEL, Theme.GOLD)
		pane.howNumbers[index] = number
		number:SetText(tostring(index))
		local line = Text(pane, Theme.F_BODY, Theme.TEXT, HALF - 22)
		if line.SetWordWrap then line:SetWordWrap(true) end
		pane.how[index] = line
	end
	pane.howTop = colY - 30

	-- parcours : coffres, collection, route, brillantes
	local roadY = colY - 28 - 4 * EVO_STEP - 18
	pane.roadTitle = Theme.CreateSection(pane, L.JRN_EVO_ROAD_TITLE)
	pane.roadTitle:SetWidth(INNER)
	At(pane.roadTitle, content, 0, roadY)
	pane.facts = {}
	for index, field in ipairs({ "chests", "collection", "road", "shiny" }) do
		local row = Theme.CreateListRow(pane, INNER, EVO_ROW, { status = 9 })
		At(row, content, 0, roadY - 28 - (index - 1) * EVO_STEP)
		row:SetIndex(index)
		Theme.SetStatus(row.status, "item")
		row.text:SetWidth(INNER - row.textLeft - 12 - (index == 1 and 170 or 0))
		pane[field] = row.text
		pane.facts[index] = row
	end
	pane.openChest = Theme.CreateButton(pane.facts[1], "auto", 22, L.JRN_OPEN_CHEST, function() ns:OpenChest() end, "primary")
	pane.openChest:SetPoint("RIGHT", pane.facts[1], "RIGHT", -8, 0)
end

-- les trois lignes « comment ça marche », empilées selon leur hauteur
local function LayoutHow(pane, content)
	local y = pane.howTop
	local x = HALF + COL_GAP
	for index, line in ipairs(pane.how) do
		At(pane.howNumbers[index], content, x, y)
		At(line, content, x + 22, y)
		y = y - Theme.TextHeight(line, HALF - 22, Theme.F_BODY) - 10
	end
	pane.howBottom = y
end

-- Collection : sortes en puces, grille d'objets (verrou pour ce qui n'est
-- pas gagné), aperçu à droite
local function BuildCollection(self, frame, content)
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.coll = pane
	pane.kindRow, pane.kinds = Chips(pane, COLL_KINDS, "JRN_COLL_", function(key)
		frame.collKind, frame.collOffset = key, 0
		ns:RefreshJournal()
	end)
	At(pane.kindRow, content, 0, TOP)
	pane.count = Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, 150)
	pane.count:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + GRID_W, TOP - 6)
	pane.count:SetJustifyH("RIGHT")
	pane.items = {}
	local gridTop = TOP - Theme.CHIP_HEIGHT - 14
	for index = 1, COLL_COLS * COLL_ROWS do
		local col, row = (index - 1) % COLL_COLS, math.floor((index - 1) / COLL_COLS)
		local cell = Theme.CreateTile(pane, COLL_W, COLL_H, { accent = "top" })
		At(cell, content, col * (COLL_W + COLL_GAP), gridTop - row * (COLL_H + COLL_GAP))
		cell.icon = cell:CreateTexture(nil, "ARTWORK")
		cell.icon:SetSize(32, 32)
		cell.icon:SetPoint("TOP", cell, "TOP", 0, -12)
		cell.lock = Theme.CreateLockTag(cell, "")
		cell.lock:SetPoint("TOP", cell, "TOP", 0, -20)
		cell.lock:Hide()
		cell.label = Text(cell, Theme.F_SMALL, Theme.LABEL, COLL_W - 10)
		cell.label:SetPoint("TOP", cell, "TOP", 0, -54)
		cell.label:SetJustifyH("CENTER")
		if cell.label.SetWordWrap then cell.label:SetWordWrap(false) end
		cell.tier = Text(cell, Theme.F_CAPS, Theme.MUTED)
		cell.tier:SetPoint("TOPLEFT", cell, "TOPLEFT", 6, -6)
		cell.onEnter = function(c) if c.entry then ns:JournalPreviewCosmetic(c.entry) end end
		cell:SetScript("OnClick", function(c) if c.entry then ns:JournalEquip(c.entry) end end)
		cell:Hide()
		pane.items[index] = cell
	end
	Pager(pane, content)
	pane.hint:SetText(L.JRN_COLL_HINT)
	pane.preview = BuildPreview(pane, content, INNER - PREVIEW_W, gridTop, gridTop - PAGER_Y - 12)
end

-- Jour : missions à gauche ; carte des auberges et garde-manger à droite
-- (Daily.lua, Treats.lua)
local MISSION_ROWS, MISSION_H, MISSION_STEP = 3, 72, 80
local function BuildDay(self, frame, content)
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.day = pane
	local rightX = HALF + COL_GAP
	pane.missionsTitle = Theme.CreateSection(pane, L.DAY_MISSIONS)
	pane.missionsTitle:SetWidth(HALF)
	At(pane.missionsTitle, content, 0, TOP)
	pane.missions = {}
	for index = 1, MISSION_ROWS do
		local row = Theme.CreateTile(pane, HALF, MISSION_H, { kind = "Frame" })
		At(row, content, 0, TOP - 28 - (index - 1) * MISSION_STEP)
		row.reroll = Theme.CreateButton(row, "auto", 20, L.MIS_REROLL, function() ns:MissionReroll(index) end)
		row.reroll:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -32)
		row.reroll:SetScript("OnEnter", function(b) Tip(b, L.MIS_REROLL, { L.MIS_REROLL_TIP }) end)
		row.reroll:SetScript("OnLeave", HideTip)
		local textW = HALF - 14 - 12 - math.max(row.reroll:GetWidth(), 60) - 10
		row.label = Text(row, Theme.F_LABEL, Theme.LABEL, textW)
		row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -10)
		if row.label.SetWordWrap then row.label:SetWordWrap(false) end
		row.source = Text(row, Theme.F_SMALL, Theme.MUTED, textW)
		row.source:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -30)
		if row.source.SetWordWrap then row.source:SetWordWrap(false) end
		row.count = Text(row, Theme.F_NUMBER, Theme.PARCHMENT, 60)
		row.count:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -10)
		row.count:SetJustifyH("RIGHT")
		row.bar = Theme.CreateBar(row, HALF - 28, 4)
		row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 14, 12)
		pane.missions[index] = row
	end
	local hintY = TOP - 28 - MISSION_ROWS * MISSION_STEP - 4
	pane.missionsHint = Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, HALF)
	At(pane.missionsHint, content, 0, hintY)
	if pane.missionsHint.SetWordWrap then pane.missionsHint:SetWordWrap(true) end
	pane.perfect = Text(pane, Theme.F_SMALL, Theme.MUTED, HALF)
	if pane.perfect.SetWordWrap then pane.perfect:SetWordWrap(true) end
	pane.hintTop = hintY

	pane.innTitle = Theme.CreateSection(pane, L.INN_TITLE)
	pane.innTitle:SetWidth(HALF)
	At(pane.innTitle, content, rightX, TOP)
	pane.stamps = {}
	local size, gap = 30, math.floor((HALF - 7 * 30) / 6)
	for index = 1, 7 do
		local stamp = pane:CreateTexture(nil, "ARTWORK")
		stamp:SetSize(size, size)
		At(stamp, content, rightX + (index - 1) * (size + gap), TOP - 30)
		stamp:SetTexture(Theme.DIAMOND_LINE)
		pane.stamps[index] = stamp
	end
	pane.innTotal = Text(pane, Theme.F_LABEL, Theme.LABEL, HALF)
	At(pane.innTotal, content, rightX, TOP - 30 - size - 12)
	pane.innHint = Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, HALF)
	if pane.innHint.SetWordWrap then pane.innHint:SetWordWrap(true) end
	pane.innGift = Text(pane, Theme.F_SMALL, Theme.MUTED, HALF)
	if pane.innGift.SetWordWrap then pane.innGift:SetWordWrap(true) end
	pane.innTop = TOP - 30 - size - 12 - 20

	pane.pantryTitle = Theme.CreateSection(pane, L.DAY_PANTRY)
	pane.pantryTitle:SetWidth(HALF)
	pane.pantryHint = Text(pane, Theme.F_SMALL, Theme.MUTED, HALF)
	if pane.pantryHint.SetWordWrap then pane.pantryHint:SetWordWrap(true) end
	pane.slots = {}
	local count = #(ns.TREAT_KINDS or {})
	local slotW = count > 0 and math.floor((HALF - (count - 1) * 8) / count) or HALF
	for index, kind in ipairs(ns.TREAT_KINDS or {}) do
		local slot = Theme.CreateTile(pane, slotW, 124, { kind = "Frame" })
		slot.kind, slot.slotX = kind, rightX + (index - 1) * (slotW + 8)
		slot.icon = slot:CreateTexture(nil, "ARTWORK")
		slot.icon:SetSize(32, 32)
		slot.icon:SetPoint("TOP", slot, "TOP", 0, -10)
		slot.icon:SetTexture(ns.TREAT_ICONS[kind])
		slot.count = Text(slot, Theme.F_LABEL, Theme.PARCHMENT, slotW - 8)
		slot.count:SetPoint("TOP", slot, "TOP", 0, -48)
		slot.count:SetJustifyH("CENTER")
		slot.name = Text(slot, Theme.F_SMALL, Theme.MUTED_LIGHT, slotW - 8)
		slot.name:SetPoint("TOP", slot, "TOP", 0, -66)
		slot.name:SetJustifyH("CENTER")
		if slot.name.SetWordWrap then slot.name:SetWordWrap(true) end
		slot.give = Theme.CreateButton(slot, slotW - 12, 20, L.DAY_GIVE, function() ns:TreatGive(kind); ns:RefreshJournal() end)
		slot.give:SetPoint("BOTTOM", slot, "BOTTOM", 0, 8)
		pane.slots[index] = slot
	end
end

-- empile la colonne de droite du Jour (textes de longueur variable)
local function LayoutDay(pane, content)
	local rightX = HALF + COL_GAP
	local y = pane.innTop
	At(pane.innHint, content, rightX, y)
	y = y - Theme.TextHeight(pane.innHint, HALF, Theme.F_SMALL) - 4
	At(pane.innGift, content, rightX, y)
	local gift = Theme.TextHeight(pane.innGift, HALF, Theme.F_SMALL)
	y = y - gift - (gift > 0 and 20 or 16)
	At(pane.pantryTitle, content, rightX, y)
	y = y - 24
	At(pane.pantryHint, content, rightX, y)
	y = y - Theme.TextHeight(pane.pantryHint, HALF, Theme.F_SMALL) - 10
	for _, slot in ipairs(pane.slots) do At(slot, content, slot.slotX, y) end
	pane.pantryBottom = y - 124
	-- colonne de gauche : l'aide des missions puis les jours parfaits
	local left = pane.hintTop - Theme.TextHeight(pane.missionsHint, HALF, Theme.F_SMALL) - 6
	At(pane.perfect, content, 0, left)
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
		if (section ~= "memories" or self.BuildMemoriesPane) and (section ~= "day" or self.DailyData) then
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

	BuildZones(self, frame, content)
	BuildCompletion(self, frame, content)
	BuildEvolution(self, frame, content)
	BuildCollection(self, frame, content)
	if self.DailyData then BuildDay(self, frame, content) end
	if self.BuildMemoriesPane then self:BuildMemoriesPane(frame, content, { pad = PAD, top = TOP, width = INNER,
		pagerTop = PAGER_Y }) end
	BuildPantry(self, frame)

	if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
	frame:SetScript("OnMouseWheel", function(_, delta) ns:ScrollJournal(delta) end)
	-- bouton retour de la souris : de la zone vers la liste des zones
	frame:SetScript("OnMouseUp", function(_, button)
		if button == "Button4" and frame.kind == "completion" then ns:SelectJournalKind("zones") end
	end)
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
	if kind == "evolution" or kind == "goals" then return "evolution" end
	if kind == "memories" then return frame.mem and "memories" or "completion" end
	if kind == "zones" or kind == "collection" then return kind end
	if kind == "day" then return frame.day and "day" or "completion" end
	return "completion"
end

function ns:SelectJournalKind(kind)
	local frame = self:EnsureJournalWindow()
	if not frame then return end
	frame.kind = KindOf(frame, kind)
	frame.offset = 0
	self:DB().journalTab = frame.kind
	self:RefreshJournal()
end

-- Une zone dans l'onglet Zone (tuile, objectif, flèches)
function ns:SelectJournalZone(zoneID)
	local frame = self:EnsureJournalWindow()
	if not frame then return end
	frame.zoneID, frame.offset, frame.zonePicked = tonumber(zoneID), 0, true
	self:RefreshJournal()
end

function ns:OpenJournalZone(zoneID)
	local frame = self:EnsureJournalWindow()
	if not frame then return end
	frame.zoneID, frame.zonePicked = tonumber(zoneID), true
	self:SelectJournalKind("completion")
end

-- Zone voisine dans l'ordre de la grille (par niveau), en boucle
function ns:StepJournalZone(step)
	local frame = self.journalFrame
	if not frame then return end
	local list = self:JournalAllZones("all", "lvl")
	if #list == 0 then return end
	local at = 0
	for index, zone in ipairs(list) do if zone.id == frame.zoneID then at = index end end
	local nextIndex = ((at - 1 + (tonumber(step) or 1)) % #list) + 1
	if at == 0 then nextIndex = 1 end
	self:SelectJournalZone(list[nextIndex].id)
end

function ns:SelectJournalActivity(activity)
	local frame = self:EnsureJournalWindow()
	if not frame then return end
	frame.activity, frame.offset = activity, 0
	self:RefreshJournal()
end

-- Molette : une rangée de la grille ou de la liste affichée
function ns:ScrollJournal(delta)
	local frame = self.journalFrame
	if not frame then return end
	delta = tonumber(delta) or 0
	if frame.kind == "zones" then
		-- trois rangées de la liste des zones par cran
		frame.zoneOffset = (frame.zoneOffset or 0) - delta * ZONE_COLS * 3
	elseif frame.kind == "collection" then
		frame.collOffset = (frame.collOffset or 0) - delta * COLL_COLS
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
function ns:JournalPreviewCreature(item)
	local frame = self.journalFrame
	if not (frame and frame.comp and item) then return end
	local p = frame.comp.preview
	if not item.seen and not item.done then
		local lines = { L.JRN_PREV_UNSEEN }
		if item.levelText then lines[2] = self:F("JRN_PREV_LEVEL", item.levelText) end
		PreviewSet(p, L.JRN_CARD_UNSEEN, lines)
		p.item = item
		return
	end
	-- L rend la clé elle-même quand elle manque : pas de L[""] (qui vaudrait "")
	local tag = CLASS_LABEL[item.class or ""]
	local rank = tag and L[tag] or L.JRN_RANK_normal
	local lines = {}
	if item.levelText then lines[#lines + 1] = self:F("JRN_PREV_LEVEL", item.levelText) end
	lines[#lines + 1] = self:F("JRN_PREV_RANK", rank)
	lines[#lines + 1] = (item.killed or 0) > 0 and self:F("JRN_PREV_KILLED", item.killed) or L.JRN_PREV_NOTYET
	if item.shiny then
		local when = rawget(_G, "date") and select(2, pcall(date, "%d/%m/%Y", item.shiny)) or tostring(item.shiny)
		lines[#lines + 1] = self:F("SHINY_PREV", tostring(when))
	end
	PreviewSet(p, item.rawName or item.name, lines, { creature = tonumber(item.id) })
	p.item = item
end

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
	for _, def in ipairs(ns[CATALOG[kind]] or {}) do
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
	if entry.tier >= 1 then return self:F("JRN_COLL_SRC_TIER", entry.tier) end
	if entry.def.unlock and self.CompanionRequirement then
		local ok, text = pcall(self.CompanionRequirement, self, entry.def.unlock)
		if ok and type(text) == "string" and text ~= "" then return text end
	end
	return L.JRN_COLL_SRC_BASE
end

function ns:JournalPreviewCosmetic(entry)
	local frame = self.journalFrame
	if not (frame and frame.coll and entry) then return end
	local state
	if not entry.owned then state = L.JRN_COLL_LOCKED
	elseif entry.kind == "orn" then state = entry.equipped and L.JRN_COLL_ORN_ON or L.JRN_COLL_ORN_OFF
	else state = entry.equipped and L.JRN_COLL_EQUIPPED or L.JRN_COLL_CLICK end
	local opts = {}
	if entry.kind == "app" then opts.display = entry.def.display
	elseif entry.kind == "frame" then opts.color = entry.def.edge
	elseif entry.kind == "bg" then
		if entry.def.texture then opts.texture = entry.def.texture else opts.color = entry.def.color end
	else
		local look = self.CompanionAppearanceDef and self:CompanionAppearanceDef(self:CompanionData().appearance)
		opts.display = look and look.display
	end
	PreviewSet(frame.coll.preview, entry.label, { state, self:F("JRN_COLL_SOURCE", self:JournalCosmeticSource(entry)) }, opts)
	frame.coll.preview.entry = entry
end

-- Clic dans la Collection : équiper (ornement : le porter ou l'enlever)
function ns:JournalEquip(entry)
	if not (entry and entry.owned) then return false end
	if entry.kind == "app" then
		self:CompanionData().appearance = entry.def.id
		if self.CompanionApplyModel then self:CompanionApplyModel() end
	elseif entry.kind == "orn" then
		local db = self:DB()
		db[entry.def.key] = not self:CompanionOrnamentShown(entry.def)
		if self.CompanionApplyOrnaments then self:CompanionApplyOrnaments() end
	elseif not self:CompanionSetStyle(entry.kind, entry.def.id) then
		return false
	end
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	self:RefreshJournal()
	local frame = self.journalFrame
	for _, fresh in ipairs(self:JournalCollection(entry.kind)) do
		if fresh.def == entry.def and frame then self:JournalPreviewCosmetic(fresh) end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Rafraîchissement
-- ---------------------------------------------------------------------------
local function RefreshZones(self, frame)
	local pane = frame.zones
	pane.filterRow:Select(frame.zoneFilter, true)
	pane.sortRow:Select(frame.zoneSort, true)
	frame.header:SetTitle(L.JRN_SEC_zones)
	local all = self:JournalAllZones("all", "lvl")
	local seen, full = 0, 0
	for _, zone in ipairs(all) do
		if zone.seen then seen = seen + 1 end
		if zone.percent == 100 then full = full + 1 end
	end
	pane.summary:SetText(self:F("JRN_ZONES_SUM", seen, #all, full))
	local list = self:JournalAllZones(frame.zoneFilter, frame.zoneSort)
	frame.zoneList = list
	local page = #pane.tiles
	local maxOffset = math.max(0, math.ceil((#list - page) / ZONE_COLS) * ZONE_COLS)
	frame.zoneOffset = math.max(0, math.min(frame.zoneOffset or 0, maxOffset))
	for index, tile in ipairs(pane.tiles) do
		local zone = list[index + frame.zoneOffset]
		tile.zone, tile.zoneID = zone, zone and zone.id
		if zone then
			tile.name:SetText(zone.name)
			tile.levels:SetText(zone.lo < 99 and self:F("JRN_ZONE_LEVELS", zone.lo, zone.hi) or "")
			local golden = zone.percent == 100
			tile.percent:SetText(zone.seen and (zone.percent and self:F("JRN_ZONE_PERCENT", zone.percent) or "-") or "?")
			local pc = golden and Theme.GOLD or (zone.seen and Theme.PARCHMENT or Theme.MUTED)
			tile.percent:SetTextColor(pc[1], pc[2], pc[3])
			-- jamais visitée : ni barre ni chiffre, l'état suffit
			tile.bar:SetValue((zone.percent or 0) / 100)
			if zone.seen then tile.bar:Show() else tile.bar:Hide() end
			local badge = ""
			if zone.here then badge = Theme.T_BLUE .. L.JRN_TILE_HERE .. "|r" end
			local shinies = self.ShinyZoneCount and self:ShinyZoneCount(zone.id) or 0
			if shinies > 0 then
				badge = (badge ~= "" and (badge .. "  ") or "") .. "|T" .. (ns.SHINY_STAR or "") .. ":10|t " .. shinies
			end
			if zone.chest and not zone.chest.opened then badge = Theme.T_GOLD .. L.JRN_TILE_CHEST .. "|r" end
			if not zone.seen then badge = Theme.T_GREY .. L.JRN_TILE_UNSEEN .. "|r" end
			tile.badge:SetText(badge)
			-- liseré : ambre pour une zone dorée, bleu pour celle où tu es
			tile:SetAccent(golden and Theme.GOLD or (zone.here and Theme.BLUE or nil))
			local nc = zone.seen and Theme.LABEL or Theme.MUTED_LIGHT
			tile.name:SetTextColor(nc[1], nc[2], nc[3])
			tile:SetAlpha(zone.seen and 1 or 0.55)
			tile:Show()
		else
			tile:Hide()
		end
	end
	pane.pager:Update(frame.zoneOffset, page, #list, maxOffset)
end

local function ShowOnly(pane, what)
	for _, line in ipairs(pane.lines) do if what ~= "lines" then line:Hide() end end
	for _, card in ipairs(pane.cards) do if what ~= "cards" then card:Hide() end end
	for _, icon in ipairs(pane.icons) do if what ~= "icons" then icon:Hide() end end
end

-- Une fiche du bestiaire : portrait (modèle de la créature, « ? » jamais
-- croisée), nom, niveau ou état, rang, tampon
local function PaintCard(self, cell, item, zoneID)
	local known = item.seen or item.done
	cell.name:SetText(known and (item.rawName or item.name) or L.JRN_CARD_UNSEEN)
	local t = known and Theme.PARCHMENT or Theme.MUTED
	cell.name:SetTextColor(t[1], t[2], t[3])
	local level = item.levelText and self:F("JRN_PREV_LEVEL", item.levelText) or ""
	cell.detail:SetText(known and (item.done and (Theme.T_GREEN .. tostring(item.detail) .. "|r") or tostring(item.detail or ""))
		or level)
	local rank = RANK_COLOR[item.class or ""]
	cell.rank:SetTag(known and item.class and CLASS_LABEL[item.class] and L[CLASS_LABEL[item.class]] or "", rank or Theme.GOLD)
	-- le détail s'arrête avant l'étiquette du rang
	local tagW = cell.rank:IsShown() and (cell.rank:GetWidth() + 8) or 0
	cell.detail:SetWidth(CARD_W - cell.textX - 10 - tagW)
	cell:SetAccent(rank)
	local edge = rank or Theme.EDGE_SOFT
	cell.portrait.border:SetColor(edge[1], edge[2], edge[3], 1)
	cell:SetFill(known and Theme.ROW or Theme.NAV)
	-- tampon du carnet : plein une fois abattue
	cell.stamp:SetTexture(item.done and Theme.DIAMOND or Theme.DIAMOND_LINE)
	local sc = item.done and Theme.GOLD or Theme.MUTED
	cell.stamp:SetVertexColor(sc[1], sc[2], sc[3], 1)
	if cell.model then
		if known and tonumber(item.id) then
			if cell.model.SetCreature then pcall(cell.model.SetCreature, cell.model, tonumber(item.id)) end
			if cell.model.SetPortraitZoom then pcall(cell.model.SetPortraitZoom, cell.model, 1) end
			cell.model.creature = tonumber(item.id)
			cell.model:Show()
		else
			cell.model.creature = nil
			cell.model:Hide()
		end
	end
	if known then cell.portrait.unknown:Hide() else cell.portrait.unknown:Show() end
	-- brillante abattue : fiche dorée, étoile
	item.shiny = self.ShinyFound and self:ShinyFound(zoneID, item.id) or nil
	if item.shiny then
		cell.star:Show()
		cell:SetFill({ 0.17, 0.15, 0.08 })
		cell:SetAccent(SHINY_COLOR)
	else
		cell.star:Hide()
	end
end

local function RefreshCompletion(self, frame)
	local pane = frame.comp
	-- par défaut la zone où tu es ; un choix tient jusqu'à la fermeture
	if not frame.zonePicked or not frame.zoneID then
		frame.zoneID = self.JournalZone and self:JournalZone() or nil
		if not frame.zoneID then
			local first = self:JournalKnownZones()[1]
			frame.zoneID = first and first.id or nil
		end
	end
	local zoneID = frame.zoneID
	local here = self.JournalZone and self:JournalZone()
	local activity = frame.activity or "explore"
	pane.tabBar:Select(activity, true)
	pane.preview.item = nil
	if not zoneID then
		pane.title:SetText(L.JRN_SEC_completion)
		pane.levels:SetText("")
		pane.watch:Hide(); pane.watchLabel:Hide()
		pane.prev:Hide(); pane.next:Hide()
		pane.percent:SetText("")
		pane.bar:Hide()
		for _, m in ipairs(pane.marks) do m:SetText("") end
		pane.chest:SetText("")
		pane.openChest:Hide()
		pane.card:Hide()
		pane.tabBar:Hide()
		pane.heads:SetText("")
		ShowOnly(pane, "none")
		pane.questRow:Hide()
		pane.empty:SetText(L.JRN_ZONE_NONE)
		At(pane.empty, frame.content, 0, TOP)
		pane.pager:Update(0, 0, 0, 0)
		pane.hint:SetText("")
		pane.preview:Hide()
		frame.rows = {}
		return
	end
	pane.card:Show(); pane.tabBar:Show(); pane.prev:Show(); pane.next:Show()
	At(pane.empty, frame.content, 0, pane.gridTop - 6)
	local name = ZoneName(self, zoneID)
	pane.title:SetText(zoneID == here and self:F("JRN_ZONE_HERE", name) or name)
	local range = self.ZoneLevelRange and self:ZoneLevelRange(zoneID)
	pane.levels:SetText(range and self:F("JRN_ZONE_LEVELS", range[1], range[2]) or "")

	local done = self.ZoneCompletion and self:ZoneCompletion(zoneID)
	local counted = done and #done.parts >= 2
	if counted then
		pane.percent:SetText(self:F("JRN_ZONE_PERCENT", done.percent))
		local pc = done.percent >= 100 and Theme.GOLD or Theme.PARCHMENT
		pane.percent:SetTextColor(pc[1], pc[2], pc[3])
		pane.bar:SetValue(done.ratio)
		pane.bar:Show()
	else
		pane.percent:SetText("")
		pane.bar:Hide()
	end
	local claimed = self.TreatData and tonumber(self:TreatData().milestones[zoneID]) or 0
	for _, m in ipairs(pane.marks) do
		local reached = counted and done.percent >= m.mark
		if counted then
			m:SetText((reached and "+ " or "") .. self:F("JRN_MARK", m.mark))
			local c = (reached and (m.mark == 100 or claimed >= m.mark)) and Theme.GOLD or Theme.MUTED
			m:SetTextColor(c[1], c[2], c[3])
		else
			m:SetText("")
		end
	end
	local chest = self.ChestData and self:ChestData()[zoneID]
	pane.openChest:Hide()
	local accent = nil
	if chest and chest.golden then
		pane.chest:SetText(self:F("JRN_CHEST_GOLDEN", chest.tier or 1))
		accent = Theme.GOLD
	elseif chest and chest.opened then
		local reward = chest.reward and chest.reward:match("^%w+:(.+)$")
		local label = reward
		for _, entry in ipairs(self.ChestRewards and self:ChestRewards() or {}) do
			if chest.reward == entry.kind .. ":" .. entry.id then label = self:ChestRewardLabel(entry) end
		end
		pane.chest:SetText(self:F("JRN_CHEST_OPENED", tostring(label or "?")))
	elseif chest then
		pane.chest:SetText(L.JRN_CHEST_READY)
		pane.openChest:Show()
		accent = Theme.GOLD
	elseif counted then
		pane.chest:SetText(self:F("JRN_CHEST_TODO", self.ZoneTier and self:ZoneTier(zoneID) or 1))
	else
		pane.chest:SetText(L.JRN_ZONE_NOPCT)
	end
	pane.card:SetAccent(accent)
	-- sans pourcentage : le texte du coffre prend la place du grand chiffre
	pane.chest:ClearAllPoints()
	pane.chest:SetPoint("TOPLEFT", pane.card, "TOPLEFT", counted and 120 or 18, counted and -54 or -32)

	pane.watch:SetChecked(self:JournalIsWatched(zoneID))
	pane.watch:Show(); pane.watchLabel:Show()
	-- Quêtes : grisé si ce client n'a pas de liste de quêtes
	local quests = self.ZoneQuestsAvailable and self:ZoneQuestsAvailable()
	pane.tabBar:SetDim("quests", not quests)

	-- lignes de l'onglet : en-têtes de parts à part, puis les éléments
	local all = self:JournalActivityRows(zoneID, activity)
	local heads, rows = {}, {}
	local seenZone = false
	for _, zone in ipairs(self:JournalKnownZones()) do if zone.id == zoneID then seenZone = true end end
	local filter = activity == "quests" and frame.questFilter or "all"
	for _, item in ipairs(all) do
		if item.header then
			heads[#heads + 1] = item.name
			if activity ~= "combat" and activity ~= "craft" then rows[#rows + 1] = item end
		elseif filter == "all" or (filter == "done") == (item.done == true) then
			rows[#rows + 1] = item
		end
	end
	frame.rows = rows
	-- les listes ont déjà une ligne d'en-tête par part : le résumé suffit
	-- pour les fiches et les ressources
	pane.heads:SetText((activity == "combat" or activity == "craft") and table.concat(heads, "  ·  ") or "")
	if activity == "quests" then pane.questRow:Show(); pane.questRow:Select(filter, true) else pane.questRow:Hide() end
	local mode, cells, step = "lines", pane.lines, LIST_COLS
	if activity == "combat" then mode, cells, step = "cards", pane.cards, CARD_COLS end
	if activity == "craft" then mode, cells, step = "icons", pane.icons, ICON_COLS end
	frame.step = step
	ShowOnly(pane, mode)
	-- l'aperçu accompagne les fiches ; ailleurs, l'aide tient dans le bas
	if mode == "cards" then pane.preview:Show(); pane.hint:SetText("") else
		pane.preview:Hide(); pane.hint:SetText(L["JRN_PREV_HINT_" .. activity] or "") end
	local page = #cells
	local maxOffset = math.max(0, math.ceil((#rows - page) / step) * step)
	frame.offset = math.max(0, math.min(frame.offset or 0, maxOffset))
	for index, cell in ipairs(cells) do
		local item = rows[index + frame.offset]
		cell.item = item
		if not item then
			cell:Hide()
		elseif mode == "lines" then
			if item.header then
				cell.stamp:Hide()
				cell.name:SetText(item.name)
				cell.name:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
				cell.detail:SetText("")
				cell.bg:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 0.08)
			else
				cell.stamp:Show()
				cell.stamp:SetTexture(item.done and Theme.DIAMOND or Theme.DIAMOND_LINE)
				local c = item.done and Theme.GOLD or Theme.MUTED
				cell.stamp:SetVertexColor(c[1], c[2], c[3], 1)
				local t = item.done and Theme.PARCHMENT or Theme.TEXT
				cell.name:SetTextColor(t[1], t[2], t[3])
				cell.name:SetText(item.name)
				cell.detail:SetText(Theme.T_GREY .. tostring(item.detail or "") .. "|r")
				cell:SetAlt(cell.rowAlt)
			end
			cell:Show()
		elseif mode == "cards" then
			PaintCard(self, cell, item, zoneID)
			cell:Show()
		else
			local texture
			local getIcon = rawget(_G, "GetItemIcon")
			if item.itemID and getIcon then
				local okIcon, found = pcall(getIcon, item.itemID)
				texture = okIcon and found or nil
			end
			cell.tex:SetTexture(texture or LOCK_ICON)
			if cell.tex.SetDesaturated then cell.tex:SetDesaturated(not item.done) end
			cell:SetAlpha(item.done and 1 or 0.45)
			local edge = item.done and Theme.GOLD_SOFT or Theme.EDGE
			cell.border:SetColor(edge[1], edge[2], edge[3], 1)
			cell.req:SetText(item.req and tostring(item.req) or "")
			cell:Show()
		end
	end
	local empty = ""
	if not seenZone and zoneID ~= here and #rows == 0 then
		empty = L.JRN_UNSEEN_ZONE
	elseif #rows == 0 then
		if activity == "quests" and not quests then
			empty = L.JRN_ACT_NO_QUESTS
		else
			empty = L["JRN_ACT_EMPTY_" .. activity] or ""
		end
	end
	pane.empty:SetText(empty)
	pane.pager:Update(frame.offset, page, #rows, maxOffset)
	PreviewSet(pane.preview, L["JRN_ACT_" .. activity], { L["JRN_PREV_HINT_" .. activity] })
end

local function CollectionCounts(self)
	local total, owned, byTier = 0, 0, { { 0, 0 }, { 0, 0 }, { 0, 0 } }
	local unlocked = self.CompanionData and self:CompanionData().unlocked or {}
	for _, reward in ipairs(self.ChestRewards and self:ChestRewards() or {}) do
		local tier = byTier[tonumber(reward.tier) or 0]
		if tier then
			local has = unlocked[reward.kind .. ":" .. reward.id] == true
			total, tier[2] = total + 1, tier[2] + 1
			if has then owned, tier[1] = owned + 1, tier[1] + 1 end
		end
	end
	return owned, total, byTier
end

local function RefreshEvolution(self, frame)
	local pane = frame.evo
	local stages = ns.COMPANION_STAGES or {}
	local data = self.CompanionData and self:CompanionData() or { needs = {} }
	local stage = self.CompanionStage and self:CompanionStage() or 1
	local name = self.CompanionName and self:CompanionName() or "?"
	local stageLabel = self.CompanionStageLabel and self:CompanionStageLabel(stage) or ""
	frame.header:SetTitle(L.JRN_SEC_evolution)
	pane.stage:SetText(self:F("JRN_EVO_STAGE", name, stageLabel, stage, #stages))
	-- portrait : son cadre et son fond gagnés, son nom, son apparence
	local hero = pane.hero
	if hero.portrait and hero.portrait.Refresh then hero.portrait:Refresh(self) end
	pane.name:SetText(name)
	local app = self.CompanionCurrentAppearance and self:CompanionCurrentAppearance()
	pane.look:SetText(app and (tostring(L[app.label]) .. "  ·  " .. stageLabel) or stageLabel)
	pane.stageLabel:SetText(Theme.Upper(self:F("JRN_EVO_STEP", stage, #stages)))
	for index, step in ipairs(pane.steps) do
		local reached = index <= stage
		step:SetTexture(reached and Theme.DIAMOND or Theme.DIAMOND_LINE)
		local c = reached and Theme.GOLD or Theme.MUTED
		step:SetVertexColor(c[1], c[2], c[3], 1)
	end
	local unitLevel = rawget(_G, "UnitLevel")
	local ok, rawLevel = pcall(unitLevel or function() return 1 end, "player")
	local level = tonumber(ok and rawLevel) or 1
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
	local trait = self.CompanionTrait and self:CompanionTrait()
	pane.trait:SetText(self.PersonaLabel and self:F("JRN_EVO_TRAIT", self:PersonaLabel(trait)) or "")
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
	SectionText(pane.howTitle, L.JRN_EVO_HOW)
	pane.how[1]:SetText(L.JRN_EVO_HOW_1)
	pane.how[2]:SetText(self:F("JRN_EVO_HOW_2", happyMin))
	pane.how[3]:SetText(self:F("JRN_EVO_HOW_3"))
	LayoutHow(pane, frame.content)

	local pending = self.ChestPending and #self:ChestPending() or 0
	pane.chests:SetText(self:F("JRN_EVO_CHESTS", pending))
	if pending > 0 then pane.openChest:Show() else pane.openChest:Hide() end
	Theme.SetStatus(pane.facts[1].status, pending > 0 and "warn" or "off")
	local owned, total, byTier = CollectionCounts(self)
	pane.collection:SetText(self:F("JRN_EVO_COLLECTION", owned, total, byTier[1][1], byTier[1][2],
		byTier[2][1], byTier[2][2], byTier[3][1], byTier[3][2]))
	local counts = self:JournalCounts()
	local capitals = self.JournalTotal and self:JournalTotal("capital") or counts.capital
	local milestones = #(ns.JOURNAL_MILESTONES or { 10, 20, 30, 40, 50, 60 })
	pane.road:SetText(self:F("JRN_EVO_ROAD", counts.zone or 0, counts.capital or 0, capitals or 0,
		counts.dungeon or 0, counts.rare or 0, counts.level or 0, milestones))
	if self.ShinyData then
		local nextReward = self:ShinyNextReward()
		local count = self:ShinyData().count
		pane.shiny:SetText(nextReward and self:F("SHINY_EVO", count, nextReward.count) or self:F("SHINY_EVO_DONE", count))
		pane.facts[4]:Show()
	else
		pane.shiny:SetText("")
		pane.facts[4]:Hide()
	end
end

local function RefreshCollection(self, frame)
	local pane = frame.coll
	local kind = frame.collKind or "app"
	pane.kindRow:Select(kind, true)
	frame.header:SetTitle(L.JRN_SEC_collection)
	frame.header:SetSubtitle(L.JRN_SUB_collection)
	local list = self:JournalCollection(kind)
	local owned, equipped = 0, nil
	for _, entry in ipairs(list) do
		if entry.owned then owned = owned + 1 end
		if entry.equipped and not equipped then equipped = entry end
	end
	pane.count:SetText(self:F("JRN_COLL_COUNT", owned, #list))
	-- plus d'objets qu'une page : la molette avance d'une rangée
	local page = #pane.items
	local maxOffset = math.max(0, math.ceil((#list - page) / COLL_COLS) * COLL_COLS)
	frame.collOffset = math.max(0, math.min(frame.collOffset or 0, maxOffset))
	for index, cell in ipairs(pane.items) do
		local entry = list[index + frame.collOffset]
		cell.entry = entry
		if entry then
			local icon = LOCK_ICON
			cell.icon:SetVertexColor(1, 1, 1, 1)
			if entry.owned then
				if entry.kind == "app" then icon = APP_ICON
				elseif entry.kind == "orn" then icon = ORN_ICON
				else
					local def = entry.def
					icon = def.texture or Theme.SOLID
					local c = entry.kind == "frame" and def.edge or def.color
					if c and not def.texture then cell.icon:SetVertexColor(c[1], c[2], c[3], 1) end
				end
				cell.icon:Show()
				cell.lock:Hide()
			else
				-- pas encore gagné : un verrou qui dit d'où il vient
				cell.icon:Hide()
				local lockText = self.CompanionLockText and entry.def and self:CompanionLockText(entry.def)
					or self:F("JRN_COLL_SRC_TIER", entry.tier)
				cell.lock:SetText(lockText, COLL_W - 10)
				cell.lock:Show()
			end
			pcall(cell.icon.SetTexture, cell.icon, icon)
			cell.label:SetText(entry.label)
			local lc = entry.owned and Theme.LABEL or Theme.MUTED
			cell.label:SetTextColor(lc[1], lc[2], lc[3])
			-- palier en coin (le verrou le dit déjà pour ce qui n'est pas gagné)
			cell.tier:SetText(entry.owned and entry.tier >= 1 and tostring(entry.tier) or "")
			cell:SetAccent(entry.equipped and Theme.GOLD or nil)
			cell:SetSelected(entry.equipped)
			cell:SetFill(entry.owned and Theme.ROW or Theme.NAV)
			cell:SetAlpha(entry.owned and 1 or 0.7)
			cell:Show()
		else
			cell:Hide()
		end
	end
	pane.pager:Update(frame.collOffset, page, #list, maxOffset)
	local shown = pane.preview.entry
	if not shown or shown.kind ~= kind then
		if equipped or list[1] then self:JournalPreviewCosmetic(equipped or list[1]) end
	end
end

local function RefreshDay(self, frame)
	local pane = frame.day
	local daily, inn = self:DailyData()
	frame.header:SetTitle(L.JRN_SEC_day)
	frame.header:SetSubtitle(L.JRN_SUB_day)
	local today = daily.day == self:DailyToday()
	local on = self:DailyMissionsOn()
	for index, row in ipairs(pane.missions) do
		local mission = on and today and daily.missions[index] or nil
		row.mission = mission
		if mission then
			row.label:SetText(self:MissionLabel(mission))
			row.source:SetText(self:MissionSource(mission))
			row.count:SetText(mission.done and (Theme.T_GREEN .. L.MIS_DONE .. "|r")
				or string.format("%d/%d", mission.have or 0, mission.need))
			row.bar:SetValue((mission.have or 0) / mission.need)
			local c = mission.done and Theme.GREEN or Theme.GOLD
			row.bar:SetColor(c[1], c[2], c[3], 1)
			row.bar:Show()
			row:SetAccent(mission.done and Theme.GREEN or Theme.GOLD)
			if mission.source == "zone" and not mission.done and not daily.rerolled then row.reroll:Show() else row.reroll:Hide() end
			row:Show()
		else
			row.label:SetText(index == 1 and (on and L.MIS_NONE or L.MIS_OFF) or "")
			row.source:SetText("")
			row.count:SetText("")
			row.bar:Hide()
			row.reroll:Hide()
			row:SetAccent(nil)
			if index == 1 then row:Show() else row:Hide() end
		end
	end
	pane.missionsHint:SetText(on and today and (daily.allDone and L.MIS_RENEW or L.MIS_ALL_BONUS) or "")
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
	LayoutDay(pane, frame.content)
end

-- la page Jour compte les missions qui restent (pastille bleue)
local function DayNavLabel(self, frame)
	local nav = frame.sections.day
	if not (nav and self.DailyData) then return end
	local daily = self:DailyData()
	local open = 0
	if self:DailyMissionsOn() and daily.day == self:DailyToday() then
		for _, mission in ipairs(daily.missions) do if not mission.done then open = open + 1 end end
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

local PANES = { zones = "zones", completion = "comp", day = "day", evolution = "evo", collection = "coll", memories = "mem" }
function ns:RefreshJournal()
	local frame = self.journalFrame
	if not frame then return end
	local section = KindOf(frame, frame.kind)
	frame.kind = section
	for key, item in pairs(frame.sections) do item:SetSelected(key == section) end
	local counts = self:JournalCounts()
	frame.subtitle:SetText(self:F("JRN_TOTAL", counts.total)
		.. (ModuleOn() and "" or ("|n" .. Theme.T_GREY .. L.MODULE_OFF .. "|r")))
	for key, field in pairs(PANES) do
		local pane = frame[field]
		if pane then if key == section then pane:Show() else pane:Hide() end end
	end
	RefreshPantry(self, frame)
	DayNavLabel(self, frame)
	if section == "memories" then
		frame.header:SetTitle(L.JRN_SEC_memories)
		frame.header:SetSubtitle(L.JRN_SUB_memories)
		self:RefreshMemoriesPane(frame)
	elseif section == "evolution" then
		RefreshEvolution(self, frame)
	elseif section == "zones" then
		RefreshZones(self, frame)
	elseif section == "collection" then
		RefreshCollection(self, frame)
	elseif section == "day" then
		RefreshDay(self, frame)
	else
		RefreshCompletion(self, frame)
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