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

local WIDTH, HEIGHT = 820, 560
local LINES, LINE_H = 11, 20
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
	JRN_EVO_HOW_3          = "Finis une zone à 100 %% (onglet Complétion) : un coffre s'ouvre, tu y choisis une apparence, un ornement, un cadre ou un fond.",
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
	JRN_EVO_HOW_3          = "Complete a zone to 100 %% (Completion tab): a chest opens and you pick a look, an ornament, a frame or a background.",
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
-- Fenêtre (QuestCompanion 1.1.0) : onglets verticaux à droite
--   Zones      grille de toutes les zones (jamais visitées en silhouette)
--   Zone       une zone : paliers, coffre, Exploration / Combat / Métiers /
--              Quêtes ; fiches du bestiaire et aperçu 3D au survol
--   Créature   étape, envies, comment elle évolue, parcours
--   Collection apparences, ornements, cadres, fonds : clic = équiper
--   Souvenirs  l'album (Memories.lua)
-- Le garde-manger (Treats.lua) est dans l'en-tête, quel que soit l'onglet.
-- ---------------------------------------------------------------------------
local NAV_W = 112
local CONTENT_W = WIDTH - NAV_W - 28
local PREVIEW_W = 200
local BODY_W = CONTENT_W - PREVIEW_W - 8
local LIST_COLS, LIST_ROWS, LIST_ROW_H = 2, 15, 20
local CARD_COLS, CARD_ROWS, CARD_W, CARD_H, CARD_GAP = 4, 7, 114, 40, 6
local ICON_COLS, ICON_ROWS, ICON_SIZE, ICON_GAP = 8, 5, 48, 8
local TILE_COLS, TILE_ROWS, TILE_W, TILE_H, TILE_GAP = 6, 4, 108, 90, 8
local COLL_COLS, COLL_ROWS, COLL_W, COLL_H, COLL_GAP = 5, 5, 88, 62, 8
local SECTIONS = { "zones", "completion", "evolution", "collection", "memories" }
local COLL_KINDS = { "app", "orn", "frame", "bg" }
local MARKS = { 25, 50, 75, 100 }
local CONTINENTS = { [1415] = "ek", [1414] = "ka" }
ns.JOURNAL_LAYOUT = { width = WIDTH, height = HEIGHT, listCols = LIST_COLS, listRows = LIST_ROWS, cardCols = CARD_COLS,
	cardRows = CARD_ROWS, iconCols = ICON_COLS, iconRows = ICON_ROWS, tileCols = TILE_COLS, tileRows = TILE_ROWS,
	collCols = COLL_COLS, collRows = COLL_ROWS }
-- liseré des fiches : rang du bestiaire
local RANK_COLOR = {
	elite = { 0.79, 0.80, 0.82 }, rareelite = { 0.29, 0.56, 0.88 }, rare = { 0.29, 0.56, 0.88 }, worldboss = Theme.GOLD,
}
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
}
ns.RegisterStrings(FR2, EN2)
for key, text in pairs(FR2) do FR[key], EN[key] = text, EN2[key] end

local function TabColor(button, selected)
	if button.text and button.text.SetTextColor then
		local c = selected and Theme.GOLD or { 0.81, 0.78, 0.72 }
		button.text:SetTextColor(c[1], c[2], c[3])
	end
	button.selected = selected
end

local function Text(parent, font, x, y, width)
	local text = parent:CreateFontString(nil, "OVERLAY", font or Theme.F_BODY)
	text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	if width then text:SetWidth(width) end
	text:SetJustifyH("LEFT")
	return text
end

local function Muted(text)
	text:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	return text
end

local function Tip(owner, title, lines)
	local tip = rawget(_G, "GameTooltip")
	if type(tip) ~= "table" then return end
	pcall(tip.SetOwner, tip, owner, "ANCHOR_RIGHT")
	if tip.ClearLines then tip:ClearLines() end
	tip:AddLine(title, Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	for _, line in ipairs(lines or {}) do tip:AddLine(line, 1, 1, 1, true) end
	tip:Show()
end
local function HideTip() local tip = rawget(_G, "GameTooltip"); if tip and tip.Hide then tip:Hide() end end

-- Une case cliquable avec fond, liseré et textes : tuile, fiche, objet
local function Cell(parent, width, height)
	local cell = CreateFrame("Button", nil, parent)
	cell:SetSize(width, height)
	cell.bg = cell:CreateTexture(nil, "BACKGROUND")
	cell.bg:SetTexture(Theme.SOLID)
	cell.bg:SetAllPoints()
	cell.bg:SetVertexColor(0.09, 0.106, 0.125, 1)
	cell.edge = cell:CreateTexture(nil, "BORDER")
	cell.edge:SetTexture(Theme.SOLID)
	cell.edge:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, 0)
	cell.edge:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", 0, 0)
	cell.edge:SetWidth(3)
	cell:Hide()
	return cell
end
local function CellColor(cell, c, alpha)
	cell.edge:SetVertexColor(c[1], c[2], c[3], alpha or 1)
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
	local title = happy and Theme.GOLD or Theme.PARCHMENT
	GameTooltip:AddLine(lines[1], title[1], title[2], title[3])
	for index = 2, #lines do
		local shade = (index == #lines) and 0.6 or 0.85
		GameTooltip:AddLine(lines[index], shade, shade, shade, true)
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
	local ids = {}
	for zoneID in pairs(ns.ZONE_LEVELS or {}) do ids[zoneID] = true end
	for zoneID in pairs(known) do ids[zoneID] = true end
	for zoneID in pairs(ids) do
		local continent = self:JournalContinentOf(zoneID)
		if not filter or filter == "all" or filter == continent then
			local range = (ns.ZONE_LEVELS or {})[zoneID]
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
local function BuildPreview(parent, frame, x, y, height)
	local p = CreateFrame("Frame", nil, parent)
	p:SetSize(PREVIEW_W, height)
	p:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
	p.bg = p:CreateTexture(nil, "BACKGROUND")
	p.bg:SetTexture(Theme.SOLID)
	p.bg:SetAllPoints()
	p.bg:SetVertexColor(0.047, 0.059, 0.071, 1)
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, p)
	if ok and model then
		model:SetSize(PREVIEW_W - 16, 150)
		model:SetPoint("TOP", p, "TOP", 0, -8)
		p.model = model
	end
	p.swatch = p:CreateTexture(nil, "ARTWORK")
	p.swatch:SetSize(PREVIEW_W - 16, 150)
	p.swatch:SetPoint("TOP", p, "TOP", 0, -8)
	p.swatch:Hide()
	p.title = Theme.CreateTitle(p, 14)
	p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -166)
	p.title:SetWidth(PREVIEW_W - 16)
	p.title:SetJustifyH("LEFT")
	p.lines = {}
	for index = 1, 5 do
		local line = Text(p, Theme.F_BODY, 8, -188 - (index - 1) * 18, PREVIEW_W - 16)
		line:SetWordWrap(true)
		p.lines[index] = line
	end
	return p
end

local function PreviewSet(p, title, lines, opts)
	opts = opts or {}
	p.title:SetText(title or "")
	for index, line in ipairs(p.lines) do line:SetText(lines and lines[index] or "") end
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

local function Chips(parent, frame, x, y, keys, prefix, onPick)
	local chips, cx = {}, x
	for _, key in ipairs(keys) do
		local label = L[prefix .. key] or key
		local width = math.max(60, #label * 6 + 18)
		local chip = Theme.CreateButton(parent, width, 18, label, function() onPick(key) end)
		chip:SetPoint("TOPLEFT", frame, "TOPLEFT", cx, y)
		chip.key = key
		chips[key] = chip
		cx = cx + width + 4
	end
	return chips, cx
end

local function BuildZones(self, frame, top)
	local pane = CreateFrame("Frame", nil, frame)
	pane:SetAllPoints()
	frame.zones = pane
	pane.filters = Chips(pane, frame, 14, top, { "all", "ek", "ka", "other" }, "JRN_FILTER_", function(key)
		frame.zoneFilter, frame.zoneOffset = key, 0
		ns:RefreshJournal()
	end)
	pane.sorts = Chips(pane, frame, 14 + CONTENT_W - 170, top, { "lvl", "pct" }, "JRN_SORT_", function(key)
		frame.zoneSort, frame.zoneOffset = key, 0
		ns:RefreshJournal()
	end)
	pane.summary = Muted(Text(pane, Theme.F_SMALL, 14, top - 24, CONTENT_W))
	pane.tiles = {}
	local gridTop = top - 44
	for index = 1, TILE_COLS * TILE_ROWS do
		local col, row = (index - 1) % TILE_COLS, math.floor((index - 1) / TILE_COLS)
		local tile = Cell(pane, TILE_W, TILE_H)
		tile:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + col * (TILE_W + TILE_GAP), gridTop - row * (TILE_H + TILE_GAP))
		tile.name = tile:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		tile.name:SetPoint("TOP", tile, "TOP", 0, -6)
		tile.name:SetWidth(TILE_W - 10)
		tile.name:SetJustifyH("CENTER")
		tile.levels = Muted(tile:CreateFontString(nil, "OVERLAY", Theme.F_SMALL))
		tile.levels:SetPoint("TOP", tile, "TOP", 0, -36)
		tile.percent = Theme.CreateTitle(tile, 16)
		tile.percent:SetPoint("TOP", tile, "TOP", 0, -50)
		tile.bar = Theme.CreateBar(tile, TILE_W - 16, 3)
		tile.bar:SetPoint("BOTTOM", tile, "BOTTOM", 0, 16)
		tile.badge = tile:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		tile.badge:SetPoint("BOTTOM", tile, "BOTTOM", 0, 3)
		tile:SetScript("OnClick", function(t) if t.zoneID then ns:OpenJournalZone(t.zoneID) end end)
		tile:SetScript("OnEnter", function(t)
			if not t.zone then return end
			local zone = t.zone
			local lines = { zone.seen and (zone.percent and ns:F("JRN_ZONE_PERCENT", zone.percent) or L.JRN_ZONE_NOPCT)
				or L.JRN_TILE_UNSEEN }
			if zone.lo < 99 then lines[#lines + 1] = ns:F("JRN_ZONE_LEVELS", zone.lo, zone.hi) end
			Tip(t, zone.name, lines)
		end)
		tile:SetScript("OnLeave", HideTip)
		pane.tiles[index] = tile
	end
	pane.position = Muted(Text(pane, Theme.F_SMALL, 14, gridTop - TILE_ROWS * (TILE_H + TILE_GAP) - 2))
end

local function BuildCompletion(self, frame, top)
	local pane = CreateFrame("Frame", nil, frame)
	pane:SetAllPoints()
	frame.comp = pane

	pane.prev = Theme.CreateButton(pane, 22, 22, "<", function() ns:StepJournalZone(-1) end)
	pane.prev:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top)
	pane.title = Theme.CreateTitle(pane, 17)
	pane.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 44, top - 2)
	pane.levels = Muted(Text(pane, Theme.F_SMALL, 44, top - 22, 300))
	pane.next = Theme.CreateButton(pane, 22, 22, ">", function() ns:StepJournalZone(1) end)
	pane.next:SetPoint("TOPLEFT", frame, "TOPLEFT", 360, top)
	-- suivre la zone dans le bloc « Carnet » en jeu
	pane.watch = Theme.CreateToggle(pane, 30, 14, "Button")
	pane.watch:SetPoint("TOPLEFT", frame, "TOPLEFT", 400, top - 4)
	pane.watch:SetScript("OnClick", function()
		if frame.zoneID then ns:JournalSetWatched(frame.zoneID, not ns:JournalIsWatched(frame.zoneID)) end
	end)
	pane.watchLabel = Text(pane, Theme.F_BODY, 436, top - 4)
	pane.watchLabel:SetText(L.JRN_WATCH)
	pane.watch:SetScript("OnEnter", function(owner) Tip(owner, L.JRN_WATCH, { L.JRN_WATCH_TIP }) end)
	pane.watch:SetScript("OnLeave", HideTip)
	pane.percent = Theme.CreateTitle(pane, 17)
	pane.percent:SetPoint("TOPRIGHT", frame, "TOPLEFT", 14 + CONTENT_W, top - 2)
	pane.percent:SetJustifyH("RIGHT")

	-- barre et paliers 25 / 50 / 75 / 100
	pane.bar = Theme.CreateBar(pane, CONTENT_W, 6)
	pane.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 40)
	pane.marks = {}
	for index, mark in ipairs(MARKS) do
		local m = pane:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		m:SetPoint("TOP", pane.bar, "TOPLEFT", CONTENT_W * mark / 100 - (mark == 100 and 14 or 0), -8)
		m.mark = mark
		pane.marks[index] = m
	end
	pane.marksHover = CreateFrame("Frame", nil, pane)
	pane.marksHover:SetPoint("TOPLEFT", pane.bar, "TOPLEFT", 0, 4)
	pane.marksHover:SetSize(CONTENT_W, 24)
	pane.marksHover:SetScript("OnEnter", function(owner) Tip(owner, ns:F("JRN_MARK_TIP"), {}) end)
	pane.marksHover:SetScript("OnLeave", HideTip)

	pane.chest = Text(pane, Theme.F_BODY, 14, top - 70, CONTENT_W - 150)
	pane.openChest = Theme.CreateButton(pane, 130, 20, L.JRN_OPEN_CHEST, function()
		if frame.zoneID then ns:OpenChest(frame.zoneID) end
	end, "primary")
	pane.openChest:SetPoint("TOPRIGHT", frame, "TOPLEFT", 14 + CONTENT_W, top - 66)

	pane.tabs = {}
	local tabW = math.floor((CONTENT_W - (#ACTIVITIES - 1) * 4) / #ACTIVITIES)
	for index, activity in ipairs(ACTIVITIES) do
		local tab = Theme.CreateButton(pane, tabW, 20, L["JRN_ACT_" .. activity], function() ns:SelectJournalActivity(activity) end)
		tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (index - 1) * (tabW + 4), top - 92)
		tab.activity = activity
		pane.tabs[activity] = tab
		if activity == "quests" and tab.HookScript then
			-- l'onglet dit ce qu'il compte, ou qu'il n'a pas de liste pour ce client
			tab:HookScript("OnEnter", function(owner)
				local available = ns.ZoneQuestsAvailable and ns:ZoneQuestsAvailable()
				Tip(owner, L.JRN_ACT_quests, { available and L.JRN_QUESTS_TIP or L.JRN_ACT_NO_QUESTS })
			end)
			tab:HookScript("OnLeave", HideTip)
		end
	end

	local bodyTop = top - 120
	pane.bodyTop = bodyTop
	-- en-têtes des parts (« Bestiaire : 4/15 · Nommés : 0/1 ») et filtre des quêtes
	pane.heads = Text(pane, Theme.F_BODY, 14, bodyTop, BODY_W - 200)
	pane.heads:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	pane.questFilter = Chips(pane, frame, 14 + BODY_W - 190, bodyTop + 2, { "all", "todo", "done" }, "JRN_Q_", function(key)
		frame.questFilter, frame.offset = key, 0
		ns:RefreshJournal()
	end)
	local gridTop = bodyTop - 22

	-- listes sur deux colonnes (Exploration, Quêtes)
	pane.lines = {}
	local colW = math.floor((BODY_W - 8) / LIST_COLS)
	for index = 1, LIST_COLS * LIST_ROWS do
		local col, row = (index - 1) % LIST_COLS, math.floor((index - 1) / LIST_COLS)
		local line = CreateFrame("Frame", nil, pane)
		line:SetSize(colW, LIST_ROW_H - 2)
		line:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + col * (colW + 8), gridTop - row * LIST_ROW_H)
		line.stamp = Theme.CreateDiamond(line, 9, false)
		line.stamp:SetPoint("LEFT", line, "LEFT", 2, 0)
		line.name = line:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		line.name:SetPoint("LEFT", line, "LEFT", 16, 0)
		line.name:SetWidth(colW - 80)
		line.name:SetJustifyH("LEFT")
		line.name:SetWordWrap(false)
		line.detail = line:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		line.detail:SetPoint("RIGHT", line, "RIGHT", -2, 0)
		line.detail:SetWidth(76)
		line.detail:SetJustifyH("RIGHT")
		line.detail:SetWordWrap(false)
		line:Hide()
		pane.lines[index] = line
	end

	-- fiches du bestiaire (Combat)
	pane.cards = {}
	for index = 1, CARD_COLS * CARD_ROWS do
		local col, row = (index - 1) % CARD_COLS, math.floor((index - 1) / CARD_COLS)
		local card = Cell(pane, CARD_W, CARD_H)
		card:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + col * (CARD_W + CARD_GAP), gridTop - row * (CARD_H + CARD_GAP))
		card.name = card:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 7, -4)
		card.name:SetWidth(CARD_W - 10)
		card.name:SetJustifyH("LEFT")
		card.name:SetWordWrap(false)
		card.detail = Muted(card:CreateFontString(nil, "OVERLAY", Theme.F_SMALL))
		card.detail:SetPoint("TOPLEFT", card, "TOPLEFT", 7, -20)
		card.detail:SetWidth(CARD_W - 10)
		card.detail:SetJustifyH("LEFT")
		card.detail:SetWordWrap(false)
		card:SetScript("OnEnter", function(c) if c.item then ns:JournalPreviewCreature(c.item) end end)
		pane.cards[index] = card
	end

	-- ressources (Métiers)
	pane.icons = {}
	for index = 1, ICON_COLS * ICON_ROWS do
		local col, row = (index - 1) % ICON_COLS, math.floor((index - 1) / ICON_COLS)
		local icon = CreateFrame("Button", nil, pane)
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + col * (ICON_SIZE + ICON_GAP), gridTop - row * (ICON_SIZE + ICON_GAP + 4))
		icon.tex = icon:CreateTexture(nil, "ARTWORK")
		icon.tex:SetAllPoints()
		icon.req = icon:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		icon.req:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
		icon:SetScript("OnEnter", function(i)
			if i.item then Tip(i, i.item.name, { tostring(i.item.detail or "") }) end
		end)
		icon:SetScript("OnLeave", HideTip)
		icon:Hide()
		pane.icons[index] = icon
	end

	local bottom = gridTop - LIST_ROWS * LIST_ROW_H
	pane.empty = Muted(Text(pane, Theme.F_BODY, 16, gridTop - 4, BODY_W - 8))
	pane.empty:SetWordWrap(true)
	pane.position = Muted(Text(pane, Theme.F_SMALL, 16, bottom - 6))
	pane.up = Theme.CreateButton(pane, 22, 17, "^", function() ns:ScrollJournal(1) end)
	pane.up:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + BODY_W - 48, bottom - 4)
	pane.down = Theme.CreateButton(pane, 22, 17, "v", function() ns:ScrollJournal(-1) end)
	pane.down:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + BODY_W - 22, bottom - 4)

	pane.preview = BuildPreview(pane, frame, 14 + BODY_W + 8, bodyTop, bodyTop - bottom + 20)
end

local function BuildEvolution(self, frame, top)
	local pane = CreateFrame("Frame", nil, frame)
	pane:SetAllPoints()
	frame.evo = pane
	local width = CONTENT_W
	pane.stage = Theme.CreateTitle(pane, 17)
	pane.stage:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 2)
	pane.next = Text(pane, Theme.F_NORMAL, 14, top - 28, width)
	pane.next:SetWordWrap(true)
	pane.trait = Text(pane, Theme.F_BODY, 14, top - 50, width)
	pane.needsTitle = Muted(Text(pane, Theme.F_SMALL, 14, top - 76, width))
	pane.needs = {}
	for index, key in ipairs({ "hunger", "energy", "mood", "curiosity" }) do
		local y = top - 94 - (index - 1) * 20
		local row = { key = key }
		row.label = Text(pane, Theme.F_BODY, 14, y, 110)
		row.bar = Theme.CreateBar(pane, 400, 5)
		row.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 130, y - 5)
		row.value = Text(pane, Theme.F_BODY, 540, y, 80)
		-- zone de survol sur toute la ligne : quoi faire pour la remplir
		row.hover = CreateFrame("Button", nil, pane)
		row.hover:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y + 2)
		row.hover:SetSize(600, 18)
		row.hover:SetScript("OnEnter", function(region) ns:ShowNeedTooltip(region, key) end)
		row.hover:SetScript("OnLeave", HideTip)
		pane.needs[index] = row
	end
	pane.howTitle = Text(pane, Theme.F_SMALL, 14, top - 182, width)
	pane.howTitle:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	pane.how = {}
	for index = 1, 3 do
		local line = Text(pane, Theme.F_BODY, 14, top - 200 - (index - 1) * 30, width)
		line:SetWordWrap(true)
		pane.how[index] = line
	end
	pane.divider = Theme.CreateDivider(pane, width, top - 296)
	pane.chests = Text(pane, Theme.F_NORMAL, 14, top - 306, width - 150)
	pane.openChest = Theme.CreateButton(pane, 130, 20, L.JRN_OPEN_CHEST, function() ns:OpenChest() end, "primary")
	pane.openChest:SetPoint("TOPRIGHT", frame, "TOPLEFT", 14 + CONTENT_W, top - 302)
	pane.collection = Text(pane, Theme.F_BODY, 14, top - 332, width)
	pane.road = Text(pane, Theme.F_BODY, 14, top - 354, width)
	pane.road:SetWordWrap(true)
end

local function BuildCollection(self, frame, top)
	local pane = CreateFrame("Frame", nil, frame)
	pane:SetAllPoints()
	frame.coll = pane
	pane.kinds = Chips(pane, frame, 14, top, COLL_KINDS, "JRN_COLL_", function(key)
		frame.collKind = key
		ns:RefreshJournal()
	end)
	pane.count = Muted(Text(pane, Theme.F_SMALL, 14 + BODY_W - 150, top - 3, 150))
	pane.count:SetJustifyH("RIGHT")
	pane.items = {}
	local gridTop = top - 28
	for index = 1, COLL_COLS * COLL_ROWS do
		local col, row = (index - 1) % COLL_COLS, math.floor((index - 1) / COLL_COLS)
		local cell = Cell(pane, COLL_W, COLL_H)
		cell:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + col * (COLL_W + COLL_GAP), gridTop - row * (COLL_H + COLL_GAP))
		cell.icon = cell:CreateTexture(nil, "ARTWORK")
		cell.icon:SetSize(30, 30)
		cell.icon:SetPoint("TOP", cell, "TOP", 0, -6)
		cell.label = cell:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		cell.label:SetPoint("TOP", cell, "TOP", 0, -40)
		cell.label:SetWidth(COLL_W - 6)
		cell.label:SetJustifyH("CENTER")
		cell.label:SetWordWrap(false)
		cell.tier = Muted(cell:CreateFontString(nil, "OVERLAY", Theme.F_SMALL))
		cell.tier:SetPoint("TOPLEFT", cell, "TOPLEFT", 5, -3)
		cell:SetScript("OnEnter", function(c) if c.entry then ns:JournalPreviewCosmetic(c.entry) end end)
		cell:SetScript("OnClick", function(c) if c.entry then ns:JournalEquip(c.entry) end end)
		pane.items[index] = cell
	end
	local bottom = gridTop - COLL_ROWS * (COLL_H + COLL_GAP)
	pane.hint = Muted(Text(pane, Theme.F_SMALL, 14, bottom - 4, BODY_W))
	pane.hint:SetText(L.JRN_COLL_HINT)
	pane.preview = BuildPreview(pane, frame, 14 + BODY_W + 8, top, top - bottom + 4)
end

-- Garde-manger dans l'en-tête : un clic donne la friandise
local function BuildPantry(self, frame)
	if not ns.TREAT_KINDS then return end
	frame.pantry = {}
	local x = -36
	for index = #ns.TREAT_KINDS, 1, -1 do
		local kind = ns.TREAT_KINDS[index]
		local button = CreateFrame("Button", nil, frame)
		button:SetSize(22, 22)
		button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", x, -7)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints()
		button.icon:SetTexture(ns.TREAT_ICONS[kind])
		button.count = button:CreateFontString(nil, "OVERLAY", Theme.F_NUMBER)
		button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
		button.kind = kind
		button:SetScript("OnClick", function(b) if ns.TreatGive then ns:TreatGive(b.kind); ns:RefreshJournal() end end)
		button:SetScript("OnEnter", function(b)
			Tip(b, ns:TreatLabel(b.kind), { L["TREAT_DESC_" .. b.kind], ns:F("TREAT_COUNT", ns:TreatCount(b.kind), ns:TreatCap(b.kind)) })
		end)
		button:SetScript("OnLeave", HideTip)
		frame.pantry[kind] = button
		x = x - 26
	end
	if frame.subtitle then
		frame.subtitle:ClearAllPoints()
		frame.subtitle:SetPoint("RIGHT", frame, "TOPRIGHT", x - 4, -18)
	end
end

function ns:EnsureJournalWindow()
	if self.journalFrame then return self.journalFrame end
	if not Theme or not Theme.CreatePanel then return nil end
	local frame = Theme.CreatePanel(UIParent, WIDTH, HEIGHT, L.JRN_TITLE, { name = "Ready2QuestJournalFrame" })
	if not frame then return nil end
	if self.RestorePoint then self:RestorePoint(frame, "journalPoint", { point = "CENTER", x = 0, y = 40 }) end
	frame.kind, frame.activity, frame.offset = "completion", "explore", 0
	frame.zoneFilter, frame.zoneSort, frame.zoneOffset = "all", "lvl", 0
	frame.questFilter, frame.collKind = "all", "app"
	local top = frame.contentTop - 8

	-- navigation : colonne à droite
	frame.nav = frame:CreateTexture(nil, "BACKGROUND")
	frame.nav:SetTexture(Theme.SOLID)
	frame.nav:SetVertexColor(0.06, 0.07, 0.085, 1)
	frame.nav:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, frame.contentTop + 2)
	frame.nav:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	frame.nav:SetWidth(NAV_W)
	frame.sections = {}
	local index = 0
	for _, section in ipairs(SECTIONS) do
		if section ~= "memories" or self.BuildMemoriesPane then
			index = index + 1
			local button = Theme.CreateButton(frame, NAV_W - 12, 24, L["JRN_SEC_" .. section], function() ns:SelectJournalKind(section) end)
			button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, top - (index - 1) * 28)
			frame.sections[section] = button
		end
	end

	BuildZones(self, frame, top)
	BuildCompletion(self, frame, top)
	BuildEvolution(self, frame, top)
	BuildCollection(self, frame, top)
	if self.BuildMemoriesPane then self:BuildMemoriesPane(frame, top + 30, CONTENT_W) end
	BuildPantry(self, frame)

	if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
	frame:SetScript("OnMouseWheel", function(_, delta) ns:ScrollJournal(delta) end)
	-- bouton retour de la souris : de la zone vers la grille des zones
	frame:SetScript("OnMouseUp", function(_, button)
		if button == "Button4" and frame.kind == "completion" then ns:SelectJournalKind("zones") end
	end)
	frame.closeButton = Theme.CreateButton(frame, NAV_W - 12, 20, L.OPT_CLOSE, function() frame:Hide() end, "primary")
	frame.closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -7, 10)
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
		frame.zoneOffset = (frame.zoneOffset or 0) - delta * TILE_COLS
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
	local rank = L[CLASS_LABEL[item.class or ""] or ""] or L.JRN_RANK_normal
	local lines = {}
	if item.levelText then lines[#lines + 1] = self:F("JRN_PREV_LEVEL", item.levelText) end
	lines[#lines + 1] = self:F("JRN_PREV_RANK", rank)
	lines[#lines + 1] = (item.killed or 0) > 0 and self:F("JRN_PREV_KILLED", item.killed) or L.JRN_PREV_NOTYET
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
	for key, chip in pairs(pane.filters) do TabColor(chip, key == frame.zoneFilter) end
	for key, chip in pairs(pane.sorts) do TabColor(chip, key == frame.zoneSort) end
	local all = self:JournalAllZones("all", "lvl")
	local seen, full = 0, 0
	for _, zone in ipairs(all) do
		if zone.seen then seen = seen + 1 end
		if zone.percent == 100 then full = full + 1 end
	end
	pane.summary:SetText(self:F("JRN_ZONES_SUM", seen, #all, full))
	local list = self:JournalAllZones(frame.zoneFilter, frame.zoneSort)
	frame.zoneList = list
	local page = TILE_COLS * TILE_ROWS
	local maxOffset = math.max(0, math.ceil((#list - page) / TILE_COLS) * TILE_COLS)
	frame.zoneOffset = math.max(0, math.min(frame.zoneOffset or 0, maxOffset))
	for index, tile in ipairs(pane.tiles) do
		local zone = list[index + frame.zoneOffset]
		tile.zone, tile.zoneID = zone, zone and zone.id
		if zone then
			tile.name:SetText(zone.name)
			tile.levels:SetText(zone.lo < 99 and self:F("JRN_ZONE_LEVELS", zone.lo, zone.hi) or "")
			local golden = zone.percent == 100
			tile.percent:SetText(zone.seen and (zone.percent and self:F("JRN_ZONE_PERCENT", zone.percent) or "-") or "?")
			tile.bar:SetValue((zone.percent or 0) / 100)
			local badge = ""
			if zone.here then badge = Theme.T_BLUE .. L.JRN_TILE_HERE .. "|r" end
			if zone.chest and not zone.chest.opened then badge = Theme.T_GOLD .. L.JRN_TILE_CHEST .. "|r" end
			if not zone.seen then badge = Theme.T_GREY .. L.JRN_TILE_UNSEEN .. "|r" end
			tile.badge:SetText(badge)
			CellColor(tile, golden and Theme.GOLD or (zone.seen and Theme.GOLD_SOFT or Theme.GOLD_DIM))
			tile.bg:SetVertexColor(golden and 0.16 or 0.09, golden and 0.13 or 0.106, golden and 0.08 or 0.125, 1)
			tile:SetAlpha(zone.seen and 1 or 0.45)
			tile:Show()
		else
			tile:Hide()
		end
	end
	pane.position:SetText(#list > page and string.format("%d-%d / %d", frame.zoneOffset + 1,
		math.min(#list, frame.zoneOffset + page), #list) or "")
end

local function ShowOnly(pane, what)
	for _, line in ipairs(pane.lines) do if what ~= "lines" then line:Hide() end end
	for _, card in ipairs(pane.cards) do if what ~= "cards" then card:Hide() end end
	for _, icon in ipairs(pane.icons) do if what ~= "icons" then icon:Hide() end end
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
	for key, tab in pairs(pane.tabs) do TabColor(tab, key == (frame.activity or "explore")) end
	pane.preview.item = nil
	if not zoneID then
		pane.title:SetText("-")
		pane.levels:SetText("")
		pane.watch:Hide(); pane.watchLabel:Hide()
		pane.percent:SetText("")
		pane.bar:Hide()
		for _, m in ipairs(pane.marks) do m:SetText("") end
		pane.chest:SetText("")
		pane.openChest:Hide()
		pane.heads:SetText("")
		ShowOnly(pane, "none")
		for _, chip in pairs(pane.questFilter) do chip:Hide() end
		pane.empty:SetText(L.JRN_ZONE_NONE)
		pane.position:SetText("")
		pane.up:Hide(); pane.down:Hide()
		PreviewSet(pane.preview, "", {})
		frame.rows = {}
		return
	end
	local name = ZoneName(self, zoneID)
	pane.title:SetText(zoneID == here and self:F("JRN_ZONE_HERE", name) or name)
	local range = (ns.ZONE_LEVELS or {})[zoneID]
	pane.levels:SetText(range and self:F("JRN_ZONE_LEVELS", range[1], range[2]) or "")

	local done = self.ZoneCompletion and self:ZoneCompletion(zoneID)
	local counted = done and #done.parts >= 2
	if counted then
		pane.percent:SetText(self:F("JRN_ZONE_PERCENT", done.percent))
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
	if chest and chest.golden then
		pane.chest:SetText(self:F("JRN_CHEST_GOLDEN", chest.tier or 1))
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
	elseif counted then
		pane.chest:SetText(self:F("JRN_CHEST_TODO", self.ZoneTier and self:ZoneTier(zoneID) or 1))
	else
		pane.chest:SetText(L.JRN_ZONE_NOPCT)
	end

	pane.watch:SetChecked(self:JournalIsWatched(zoneID))
	pane.watch:Show(); pane.watchLabel:Show()
	local activity = frame.activity or "explore"
	-- Quêtes : grisé si ce client n'a pas de liste de quêtes
	local quests = self.ZoneQuestsAvailable and self:ZoneQuestsAvailable()
	local questsTab = pane.tabs.quests
	questsTab:SetText(L.JRN_ACT_quests)
	if not quests and activity ~= "quests" and questsTab.text.SetTextColor then
		questsTab.text:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	end

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
	pane.heads:SetText(table.concat(heads, "  ·  "))
	for key, chip in pairs(pane.questFilter) do
		if activity == "quests" then chip:Show(); TabColor(chip, key == filter) else chip:Hide() end
	end
	local mode, cells, step = "lines", pane.lines, LIST_COLS
	if activity == "combat" then mode, cells, step = "cards", pane.cards, CARD_COLS end
	if activity == "craft" then mode, cells, step = "icons", pane.icons, ICON_COLS end
	frame.step = step
	ShowOnly(pane, mode)
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
			else
				cell.stamp:Show()
				cell.stamp:SetTexture(item.done and Theme.DIAMOND or Theme.DIAMOND_LINE)
				local c = item.done and Theme.GOLD or Theme.MUTED
				cell.stamp:SetVertexColor(c[1], c[2], c[3], 1)
				local t = item.done and Theme.PARCHMENT or Theme.TEXT
				cell.name:SetTextColor(t[1], t[2], t[3])
				cell.name:SetText(item.name)
				cell.detail:SetText(Theme.T_GREY .. tostring(item.detail or "") .. "|r")
			end
			cell:Show()
		elseif mode == "cards" then
			local known = item.seen or item.done
			cell.name:SetText(known and (item.rawName or item.name) or L.JRN_CARD_UNSEEN)
			local t = known and Theme.PARCHMENT or Theme.MUTED
			cell.name:SetTextColor(t[1], t[2], t[3])
			local level = item.levelText and self:F("JRN_PREV_LEVEL", item.levelText) or ""
			cell.detail:SetText(known and (item.done and (Theme.T_GREEN .. tostring(item.detail) .. "|r") or tostring(item.detail or ""))
				or level)
			CellColor(cell, RANK_COLOR[item.class or ""] or Theme.CONTROL)
			cell.bg:SetVertexColor(known and 0.09 or 0.066, known and 0.106 or 0.08, known and 0.125 or 0.094, 1)
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
	pane.position:SetText(#rows > page
		and string.format("%d-%d / %d", frame.offset + 1, math.min(#rows, frame.offset + page), #rows) or "")
	if frame.offset > 0 then pane.up:Show() else pane.up:Hide() end
	if frame.offset < maxOffset then pane.down:Show() else pane.down:Hide() end
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
	pane.stage:SetText(self:F("JRN_EVO_STAGE", name, self.CompanionStageLabel and self:CompanionStageLabel(stage) or "",
		stage, #stages))
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
	pane.needsTitle:SetText(self:F("JRN_EVO_NEEDS", happyMin))
	for _, row in ipairs(pane.needs) do
		local value = math.floor(tonumber(data.needs and data.needs[row.key]) or 0)
		row.label:SetText(L["COMP_NEED_" .. row.key] or row.key)
		row.bar:SetValue(value / 100)
		local c = value >= happyMin and Theme.GOLD or Theme.MUTED
		row.bar:SetColor(c[1], c[2], c[3], 1)
		row.value:SetText(value .. " %")
	end
	pane.howTitle:SetText(L.JRN_EVO_HOW)
	pane.how[1]:SetText(L.JRN_EVO_HOW_1)
	pane.how[2]:SetText(self:F("JRN_EVO_HOW_2", happyMin))
	pane.how[3]:SetText(self:F("JRN_EVO_HOW_3"))

	local pending = self.ChestPending and #self:ChestPending() or 0
	pane.chests:SetText(self:F("JRN_EVO_CHESTS", pending))
	if pending > 0 then pane.openChest:Show() else pane.openChest:Hide() end
	local owned, total, byTier = CollectionCounts(self)
	pane.collection:SetText(self:F("JRN_EVO_COLLECTION", owned, total, byTier[1][1], byTier[1][2],
		byTier[2][1], byTier[2][2], byTier[3][1], byTier[3][2]))
	local counts = self:JournalCounts()
	local capitals = self.JournalTotal and self:JournalTotal("capital") or counts.capital
	local milestones = #(ns.JOURNAL_MILESTONES or { 10, 20, 30, 40, 50, 60 })
	pane.road:SetText(self:F("JRN_EVO_ROAD", counts.zone or 0, counts.capital or 0, capitals or 0,
		counts.dungeon or 0, counts.rare or 0, counts.level or 0, milestones))
end

local function RefreshCollection(self, frame)
	local pane = frame.coll
	local kind = frame.collKind or "app"
	for key, chip in pairs(pane.kinds) do TabColor(chip, key == kind) end
	local list = self:JournalCollection(kind)
	local owned, equipped = 0, nil
	for _, entry in ipairs(list) do
		if entry.owned then owned = owned + 1 end
		if entry.equipped and not equipped then equipped = entry end
	end
	pane.count:SetText(self:F("JRN_COLL_COUNT", owned, #list))
	for index, cell in ipairs(pane.items) do
		local entry = list[index]
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
			end
			pcall(cell.icon.SetTexture, cell.icon, icon)
			cell.label:SetText(entry.label)
			cell.tier:SetText(entry.tier >= 1 and tostring(entry.tier) or "")
			CellColor(cell, entry.equipped and Theme.GOLD or (entry.owned and Theme.GOLD_SOFT or Theme.GOLD_DIM))
			cell:SetAlpha(entry.owned and 1 or 0.45)
			cell:Show()
		else
			cell:Hide()
		end
	end
	local shown = pane.preview.entry
	if not shown or shown.kind ~= kind then
		if equipped or list[1] then self:JournalPreviewCosmetic(equipped or list[1]) end
	end
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

local PANES = { zones = "zones", completion = "comp", evolution = "evo", collection = "coll", memories = "mem" }
function ns:RefreshJournal()
	local frame = self.journalFrame
	if not frame then return end
	local section = KindOf(frame, frame.kind)
	frame.kind = section
	for key, button in pairs(frame.sections) do TabColor(button, key == section) end
	local counts = self:JournalCounts()
	if frame.subtitle then
		frame.subtitle:SetText(self:F("JRN_TOTAL", counts.total)
			.. (ModuleOn() and "" or ("  " .. Theme.T_GREY .. L.MODULE_OFF .. "|r")))
	end
	for key, field in pairs(PANES) do
		local pane = frame[field]
		if pane then if key == section then pane:Show() else pane:Hide() end end
	end
	RefreshPantry(self, frame)
	if section == "memories" then
		self:RefreshMemoriesPane(frame)
	elseif section == "evolution" then
		RefreshEvolution(self, frame)
	elseif section == "zones" then
		RefreshZones(self, frame)
	elseif section == "collection" then
		RefreshCollection(self, frame)
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
				frame.kind = KindOf(frame, self:DB().journalTab or "completion")
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
