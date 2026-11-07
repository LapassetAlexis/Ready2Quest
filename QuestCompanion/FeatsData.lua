-- FeatsData.lua -- hauts faits de QuestCompanion : données seules (2.7.0, lot A)
--
-- Catalogue (docs/QC-HAUTS-FAITS.md §2), catégories, titres et chaînes FR/EN.
-- Le moteur (Feats.lua) lit ces tables ; la page du carnet (JournalFeats.lua)
-- les affiche. Aucun code de jeu ici.
--
-- Une ligne par haut fait :
--   { id, n, cat, pts, scope, crit = { type, ... }, reward = { ... }, pending = true }
--   * id     : chaîne stable, clé de sauvegarde et de chaînes (FEAT_<id> = nom) ;
--   * n      : code numérique stable = rang dans le catalogue du document (§2,
--              1 à 173), jamais réutilisé : c'est lui qui voyagera dans les
--              messages d'addon (lot D) ;
--   * cat    : catégorie (ns.FEAT_CATEGORIES) ; pts : 5, 10, 25 ou 50 ;
--   * scope  : "account" (collection : compte) ou "char" (performance :
--              personnage), règle « collection = compte, performance =
--              personnage » (docs §1.3) ;
--   * crit   : critère, types lus par Feats.lua :
--       { "count", source, n }             valeur d'une source ≥ n
--       { "stat", { statIDs }, n, alt = source }  max(somme des statistiques, alt) ≥ n
--       { "flag", clé }                    fait ponctuel posé par ns:FeatFlag(clé)
--       { "streak", clé, n }               compteur ns:FeatCount(clé) ≥ n
--       { "list", nom }                    tous les éléments de ns.FEAT_LISTS[nom]
--       { "meta", { ids } } / { "meta", cat, n }  hauts faits obtenus
--       { "points", n }                    total de points (compte + personnage) ≥ n
--   * reward : { aids = { appat = 1 }, cosmetic = { "frame", "trainer" },
--              appearance = "id", title = code } ;
--   * pending: détection pas encore vérifiée en jeu (⚠️ du document) : la
--              ligne est grisée « détection bientôt disponible », jamais évaluée.
-- La description est générée : FEATD_<source> (count), FEATD_<desc|alt>
-- (stat), FEATD_list_<nom>, FEATD_points, FEATD_meta_cat, FEATD_meta_ids,
-- FEATD_flag_<clé>, FEATD_streak_<clé> ; def.desc force une clé.
--
-- Lots B et C : ajouter leurs lignes avec ns.FeatAdd({ ... }) (ou directement
-- dans FEAT_DEFS) et leurs chaînes avec ns.RegisterStrings, dans ce fichier
-- ou un fichier chargé après lui. Le moteur reconstruit ses index au besoin.
local ADDON, ns = ...
if ns.blocked then return end

-- ---------------------------------------------------------------------------
-- Catégories : ordre de la page, portée par défaut, icône du bandeau
-- ---------------------------------------------------------------------------
ns.FEAT_CATEGORIES = {
	{ id = "men",   scope = "account", icon = "Interface\\Icons\\Ability_Hunter_BeastCall" },
	{ id = "shiny", scope = "account", icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_04" },
	{ id = "zone",  scope = "char",    icon = "Interface\\Icons\\INV_Misc_Map_01" },
	{ id = "day",   scope = "char",    icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
	{ id = "soc",   scope = "account", icon = "Interface\\Icons\\INV_Letter_15" },
	{ id = "char",  scope = "char",    icon = "Interface\\Icons\\INV_Helmet_08" },
	{ id = "dng",   scope = "char",    icon = "Interface\\Icons\\INV_Misc_Key_10" },
	{ id = "prof",  scope = "char",    icon = "Interface\\Icons\\Trade_BlackSmithing" },
	{ id = "quest", scope = "char",    icon = "Interface\\Icons\\INV_Misc_Book_09" },
	{ id = "fun",   scope = "account", icon = "Interface\\Icons\\INV_Misc_Toy_10" },
	{ id = "meta",  scope = "account", icon = "Interface\\Icons\\INV_Crown_01" },
}

-- capitales du carnet (groupes de Hubs.lua, plus petit areaID du groupe)
local CAPITALS = { 1519, 1537, 1657, 1637, 1638, 1497 }
ns.FEAT_CAPITALS = CAPITALS

-- ---------------------------------------------------------------------------
-- Catalogue, lot A : les tampons convertis et quelques hauts faits par sorte
-- de critère (le reste du catalogue arrive avec les lots B et C)
-- ---------------------------------------------------------------------------
ns.FEAT_DEFS = {
	-- Ménagerie (compte : union des captures de tous tes personnages)
	{ "men_first",        1, "men", 5,  "account", crit = { "count", "species", 1 },   reward = { aids = { appat = 1 } } },
	-- les aides et cosmétiques des paliers restent donnés par MenagerieRankCheck
	-- tant que le lot B ne les a pas déplacés ici (pas de double don)
	{ "men_species_10",   2, "men", 10, "account", crit = { "count", "species", 10 },  reward = { title = 1 } },
	{ "men_species_25",   3, "men", 10, "account", crit = { "count", "species", 25 },  reward = { title = 2 } },
	{ "men_species_50",   4, "men", 10, "account", crit = { "count", "species", 50 },  reward = { title = 3 } },
	{ "men_species_100",  5, "men", 25, "account", crit = { "count", "species", 100 }, reward = { title = 4 } },
	{ "men_species_250",  6, "men", 50, "account", crit = { "count", "species", 250 }, reward = { title = 5 } },
	-- Brillantes (compte)
	{ "shiny_cap_1",     35, "shiny", 10, "account", crit = { "count", "shinyCap", 1 }, reward = { aids = { lasso = 1 } } },
	-- Zones et sceaux (personnage)
	{ "zone_seal_1",     42, "zone", 10, "char", crit = { "count", "seals", 1 },        reward = { aids = { lasso = 1 } } },
	{ "zone_visit_10",   48, "zone", 5,  "char", crit = { "count", "placeZone", 10 },   reward = { aids = { appat = 1 } } },
	{ "zone_visit_25",   49, "zone", 10, "char", crit = { "count", "placeZone", 25 },   reward = { aids = { lasso = 1 } } },
	{ "zone_villages_10", 52, "zone", 5, "char", crit = { "count", "placeSubzone", 10 } },
	{ "zone_villages_25", 53, "zone", 10, "char", crit = { "count", "placeSubzone", 25 } },
	{ "zone_capitals",   54, "zone", 10, "char", crit = { "list", "capitals" },         reward = { title = 17 } },
	{ "zone_capital_enemy", 55, "zone", 10, "char", crit = { "count", "capitalEnemy", 1 } },
	-- Au jour le jour (personnage)
	{ "day_mission_1",   65, "day", 5,  "char", crit = { "count", "missions", 1 } },
	{ "day_rare_1",      71, "day", 5,  "char", crit = { "count", "placeRare", 1 } },
	{ "day_rare_10",     72, "day", 10, "char", crit = { "count", "placeRare", 10 },    reward = { aids = { lasso = 1 } } },
	{ "day_rare_50",     73, "day", 25, "char", crit = { "count", "placeRare", 50 },    reward = { title = 19 } },
	-- Personnage
	{ "char_level_10",   86, "char", 5,  "char", crit = { "count", "level", 10 } },
	{ "char_level_20",   87, "char", 5,  "char", crit = { "count", "level", 20 } },
	{ "char_level_30",   88, "char", 10, "char", crit = { "count", "level", 30 } },
	{ "char_level_40",   89, "char", 10, "char", crit = { "count", "level", 40 } },
	{ "char_level_50",   90, "char", 10, "char", crit = { "count", "level", 50 } },
	{ "char_level_60",   91, "char", 25, "char", crit = { "count", "level", 60 },       reward = { title = 21 } },
	-- statistique du client 107 (« créatures tuées », vérifiée en jeu : 780) ;
	-- repli : les abattus du bestiaire
	{ "char_kills_1000", 99, "char", 10, "char", crit = { "stat", { 107 }, 1000, alt = "bestiaryKills" }, desc = "FEATD_kills" },
	{ "char_kills_10000", 100, "char", 25, "char", crit = { "stat", { 107 }, 10000, alt = "bestiaryKills" }, desc = "FEATD_kills" },
	-- statistique 353 pas encore vérifiée en jeu : grisée
	{ "char_hearth_50",  98, "char", 10, "char", crit = { "stat", { 353 }, 50 }, desc = "FEATD_hearth", pending = true },
	-- Donjons (personnage)
	{ "dng_visit_1",    107, "dng", 5,  "char", crit = { "count", "placeDungeon", 1 },  reward = { aids = { lasso = 1 } } },
	{ "dng_visit_10",   108, "dng", 10, "char", crit = { "count", "placeDungeon", 10 }, reward = { aids = { sifflet = 1 } } },
	{ "dng_visit_20",   109, "dng", 25, "char", crit = { "count", "placeDungeon", 20 } },
	{ "dng_visit_all",  110, "dng", 50, "char", crit = { "list", "dungeons" },          reward = { title = 24 } },
	-- Grands hauts faits (compte)
	{ "meta_menagerie", 166, "meta", 50, "account", crit = { "meta", "men", 20 },       reward = { title = 35 } },
	{ "meta_points_500", 171, "meta", 10, "account", crit = { "points", 500 } },
	{ "meta_points_1500", 172, "meta", 25, "account", crit = { "points", 1500 } },
}

-- Ajout d'une ligne par un autre lot (le moteur reconstruit ses index)
function ns.FeatAdd(def)
	def.id, def.n, def.cat, def.pts, def.scope = def.id or def[1], def.n or def[2], def.cat or def[3],
		def.pts or def[4], def.scope or def[5]
	table.insert(ns.FEAT_DEFS, def)
	ns.featIndexDirty = true
	return def
end

-- ---------------------------------------------------------------------------
-- Titres (registre ; rendu, choix et genre : lot D). Un titre est gagné si
-- son haut fait l'est : rien à stocker. Formes : m (masculin), f (féminin,
-- absente = épicène), en (anglais), enf (anglais féminin si besoin).
-- ---------------------------------------------------------------------------
ns.FEAT_TITLES = {
	[1]  = { m = "Apprenti dresseur %s", f = "Apprentie dresseuse %s", en = "Apprentice Trainer %s" },
	[2]  = { m = "Dresseur %s", f = "Dresseuse %s", en = "Trainer %s" },
	[3]  = { m = "Dresseur confirmé %s", f = "Dresseuse confirmée %s", en = "Seasoned Trainer %s" },
	[4]  = { m = "Maître dresseur %s", f = "Maîtresse dresseuse %s", en = "Master Trainer %s" },
	[5]  = { m = "Grand maître dresseur %s", f = "Grande maîtresse dresseuse %s", en = "Grand Master Trainer %s" },
	[17] = { m = "Ambassadeur %s", f = "Ambassadrice %s", en = "Ambassador %s" },
	[19] = { m = "%s le Traqueur", f = "%s la Traqueuse", en = "%s the Tracker" },
	[21] = { m = "%s l'Aventurier", f = "%s l'Aventurière", en = "%s the Adventurer" },
	[24] = { m = "%s l'Explorateur des abîmes", f = "%s l'Exploratrice des abîmes", en = "%s the Deepdelver" },
	[35] = { m = "%s, Seigneur de la ménagerie", f = "%s, Dame de la ménagerie", en = "%s, Lord of the Menagerie",
		enf = "%s, Lady of the Menagerie" },
}

-- ---------------------------------------------------------------------------
-- Chaînes : noms (FEAT_<id>), descriptions (FEATD_*), catégories (FEATC_*)
-- ---------------------------------------------------------------------------
local FR = {
	FEATC_men   = "Ménagerie",
	FEATC_shiny = "Brillantes",
	FEATC_zone  = "Zones et sceaux",
	FEATC_day   = "Au jour le jour",
	FEATC_soc   = "Guilde et entraide",
	FEATC_char  = "Personnage",
	FEATC_dng   = "Donjons et raids",
	FEATC_prof  = "Métiers",
	FEATC_quest = "Quêtes, réputations et honneur",
	FEATC_fun   = "Insolite",
	FEATC_meta  = "Grands hauts faits",
	FEATD_species       = "Capturer %d espèce(s), tous personnages confondus",
	FEATD_shinyCap      = "Capturer %d brillante(s), tous personnages confondus",
	FEATD_seals         = "Sceller %d zone(s) de la ménagerie",
	FEATD_placeZone     = "Découvrir %d zones",
	FEATD_placeSubzone  = "Découvrir %d villages ou hubs amis",
	FEATD_placeDungeon  = "Entrer dans %d donjon(s) différent(s)",
	FEATD_placeRare     = "Vaincre %d ennemi(s) rare(s)",
	FEATD_capitalEnemy  = "Entrer dans une capitale de l'autre faction",
	FEATD_missions      = "Accomplir %d mission(s) du compagnon",
	FEATD_level         = "Atteindre le niveau %d",
	FEATD_kills         = "Tuer %d créatures",
	FEATD_hearth        = "Rentrer %d fois par la pierre de foyer",
	FEATD_bestiaryKills = "Abattre %d créatures",
	FEATD_list_capitals = "Visiter les %d capitales",
	FEATD_list_dungeons = "Entrer dans les %d donjons d'Azeroth",
	FEATD_points        = "Atteindre %d points de hauts faits",
	FEATD_meta_cat      = "Obtenir %d hauts faits « %s »",
	FEATD_meta_ids      = "Obtenir %d hauts faits",
	FEAT_men_first        = "Premier filet",
	FEAT_men_species_10   = "Petite ménagerie",
	FEAT_men_species_25   = "Ménagerie bien garnie",
	FEAT_men_species_50   = "Enclos animés",
	FEAT_men_species_100  = "Cent pensionnaires",
	FEAT_men_species_250  = "L'arche d'Azeroth",
	FEAT_shiny_cap_1      = "Prise étincelante",
	FEAT_zone_seal_1      = "Premier sceau",
	FEAT_zone_visit_10    = "Bourlingueur",
	FEAT_zone_visit_25    = "Grand voyageur",
	FEAT_zone_villages_10 = "De village en village",
	FEAT_zone_villages_25 = "Toutes les auberges du pays",
	FEAT_zone_capitals    = "Tour des capitales",
	FEAT_zone_capital_enemy = "Touriste en terre hostile",
	FEAT_day_mission_1    = "Au rapport",
	FEAT_day_rare_1       = "Tête mise à prix",
	FEAT_day_rare_10      = "Chasseur de primes",
	FEAT_day_rare_50      = "Le traqueur",
	FEAT_char_level_10    = "Premiers pas",
	FEAT_char_level_20    = "Sur la route",
	FEAT_char_level_30    = "À mi-chemin",
	FEAT_char_level_40    = "En selle",
	FEAT_char_level_50    = "Vétéran",
	FEAT_char_level_60    = "Au sommet",
	FEAT_char_kills_1000  = "Mille adversaires",
	FEAT_char_kills_10000 = "Dix mille adversaires",
	FEAT_char_hearth_50   = "Retour au bercail",
	FEAT_dng_visit_1      = "Dans le noir",
	FEAT_dng_visit_10     = "Habitué des profondeurs",
	FEAT_dng_visit_20     = "Rien ne m'arrête",
	FEAT_dng_visit_all    = "Explorateur des abîmes",
	FEAT_meta_menagerie   = "Maître des lieux",
	FEAT_meta_points_500  = "Un nom qui circule",
	FEAT_meta_points_1500 = "Renommée",
}
local EN = {
	FEATC_men   = "Menagerie",
	FEATC_shiny = "Shinies",
	FEATC_zone  = "Zones and Seals",
	FEATC_day   = "Day by Day",
	FEATC_soc   = "Guild and Friends",
	FEATC_char  = "Character",
	FEATC_dng   = "Dungeons and Raids",
	FEATC_prof  = "Professions",
	FEATC_quest = "Quests, Reputation and Honor",
	FEATC_fun   = "Oddities",
	FEATC_meta  = "Feats of Feats",
	FEATD_species       = "Capture %d species, across all your characters",
	FEATD_shinyCap      = "Capture %d shiny creature(s), across all your characters",
	FEATD_seals         = "Seal %d menagerie zone(s)",
	FEATD_placeZone     = "Discover %d zones",
	FEATD_placeSubzone  = "Discover %d friendly villages or hubs",
	FEATD_placeDungeon  = "Enter %d different dungeon(s)",
	FEATD_placeRare     = "Defeat %d rare enemy(ies)",
	FEATD_capitalEnemy  = "Enter a capital of the other faction",
	FEATD_missions      = "Complete %d companion mission(s)",
	FEATD_level         = "Reach level %d",
	FEATD_kills         = "Kill %d creatures",
	FEATD_hearth        = "Hearth home %d times",
	FEATD_bestiaryKills = "Defeat %d creatures",
	FEATD_list_capitals = "Visit the %d capitals",
	FEATD_list_dungeons = "Enter the %d dungeons of Azeroth",
	FEATD_points        = "Reach %d achievement points",
	FEATD_meta_cat      = "Earn %d \"%s\" achievements",
	FEATD_meta_ids      = "Earn %d achievements",
	FEAT_men_first        = "First Net",
	FEAT_men_species_10   = "A Little Menagerie",
	FEAT_men_species_25   = "Well-Stocked Menagerie",
	FEAT_men_species_50   = "Busy Pens",
	FEAT_men_species_100  = "A Hundred Lodgers",
	FEAT_men_species_250  = "Azeroth's Ark",
	FEAT_shiny_cap_1      = "Sparkling Catch",
	FEAT_zone_seal_1      = "First Seal",
	FEAT_zone_visit_10    = "Wanderer",
	FEAT_zone_visit_25    = "Far Traveller",
	FEAT_zone_villages_10 = "Village to Village",
	FEAT_zone_villages_25 = "Every Inn in the Land",
	FEAT_zone_capitals    = "Grand Tour of Capitals",
	FEAT_zone_capital_enemy = "Tourist in Hostile Land",
	FEAT_day_mission_1    = "Reporting In",
	FEAT_day_rare_1       = "Wanted",
	FEAT_day_rare_10      = "Bounty Hunter",
	FEAT_day_rare_50      = "The Tracker",
	FEAT_char_level_10    = "First Steps",
	FEAT_char_level_20    = "On the Road",
	FEAT_char_level_30    = "Halfway There",
	FEAT_char_level_40    = "In the Saddle",
	FEAT_char_level_50    = "Veteran",
	FEAT_char_level_60    = "At the Summit",
	FEAT_char_kills_1000  = "A Thousand Foes",
	FEAT_char_kills_10000 = "Ten Thousand Foes",
	FEAT_char_hearth_50   = "Homeward Bound",
	FEAT_dng_visit_1      = "Into the Dark",
	FEAT_dng_visit_10     = "Deep Regular",
	FEAT_dng_visit_20     = "Nothing Stops Me",
	FEAT_dng_visit_all    = "Deepdelver",
	FEAT_meta_menagerie   = "Master of the House",
	FEAT_meta_points_500  = "Making a Name",
	FEAT_meta_points_1500 = "Renown",
}
ns.RegisterStrings(FR, EN)
-- exposées aux tests : chaque clé doit exister dans les deux langues
if ns.KEEP_STRINGS then ns.FEAT_DATA_STRINGS = { fr = FR, en = EN } end

if ns.Mark then ns.Mark("FeatsData") end
