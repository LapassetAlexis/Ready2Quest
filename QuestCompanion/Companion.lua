-- Companion.lua -- module « Compagnon de route » (v1.25.0)
--
-- Une petite créature voyage avec le joueur et réagit à son aventure : elle
-- mange quand il mange, se repose à l'auberge ou au feu de camp, se réjouit
-- d'une quête rendue, s'émerveille d'une zone nouvelle. Elle grandit avec le
-- niveau du joueur et débloque des apparences et des ornements au fil des
-- tampons du Carnet de voyage.
--
-- Ton : bienveillant, jamais punitif. Elle ne meurt pas, ne régresse pas,
-- n'est jamais « malade ». Ses besoins sont cosmétiques : ils baissent
-- doucement pendant le jeu seulement, jamais sous un plancher, et une longue
-- absence la rend juste somnolente au retour (« Tu m'as manqué ! »). Aucune
-- culpabilité : on ne compte pas les jours d'absence contre le joueur.
--
-- Contrat avec le Carnet de voyage (autre module, peut être absent) :
--   * ns:FireCallback("STAMP", { id, kind, name, new }) à chaque tampon ;
--   * ns:JournalCounts() -> { zone, subzone, dungeon, rare, level, total }.
-- Sans lui, tout marche : les compteurs valent zéro, seules les conditions
-- de niveau débloquent des cosmétiques.
--
-- Modèle 3D : CreateFrame("PlayerModel") + SetDisplayInfo (numéros vérifiés
-- dans les deux clients, voir CompanionData.lua). Si l'API manque, la
-- boussole de l'addon prend la place : le compagnon reste là, sans modèle.
--
-- Bulles (répliques dans CompanionLines.lua) : beaucoup de sources (combat,
-- PNJ, repas, besoins, astuces, objectifs, bavardage), donc des règles pour
-- qu'il reste agréable et pas bavard :
--   * priorité : évolution/déblocage > tutoriel > réaction > besoin >
--     astuce/objectif > bavardage. Une bulle n'en remplace jamais une plus
--     importante encore affichée (ni une séquence en cours) ;
--   * écart minimal global entre deux bulles non prioritaires ;
--   * pause par catégorie (combat, PNJ, repas, besoins, astuces…) ;
--   * la sourdine coupe tout, tutoriel compris.
--
-- Contrat avec le suivi d'objectifs du Carnet : ns:CompanionNextUnlocks()
-- (voir sa définition).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local NEED_KEYS  = { "hunger", "energy", "mood", "curiosity" }
local NEED_MAX   = 100
local NEED_FLOOR = 15        -- plancher : jamais vide, jamais « en détresse »
local NEED_START = 80
-- baisse par minute de JEU (rien hors connexion)
local DECAY = { hunger = 0.6, energy = 0.4, mood = 0.3, curiosity = 0.5 }
-- Chaque envie doit rester simple à remonter, même tout exploré, même au
-- niveau maximum. La curiosité se nourrit aussi de nouveauté relative :
-- revenir dans une zone pas vue depuis un moment, bouger, les donjons, les
-- élites et rares, les vols, les coffres, la récolte.
local CURIOSITY = {
	newZone = 15, newSub = 4,              -- premières fois
	revisit = 8, revisitAfter = 2 * 3600,  -- zone pas vue depuis 2 h (temps réel)
	subzone = 1, subzoneGap = 30,          -- changer de sous-zone, au plus toutes les 30 s
	dungeon = 10, dungeonGap = 600,        -- chaque entrée en donjon (pas deux fois en 10 min)
	elite = 8,                             -- chaque élite ou rare vaincu
	flight = 5,                            -- chaque arrivée en griffon
	chest = 20,                            -- chaque coffre de zone ouvert
	gather = 1,                            -- chaque ressource récoltée
}
ns.COMPANION_CURIOSITY = CURIOSITY
-- Plancher une fois toutes ses évolutions faites : il a tout vécu, il est serein
local SERENE_FLOOR = 50
ns.COMPANION_SERENE_FLOOR = SERENE_FLOOR
local REST_GAIN   = 4        -- énergie par minute au repos (auberge, ville, camp)
local EAT_GAIN    = 6        -- faim par minute pendant le repas
local TICK        = 10       -- s entre deux mises à jour des besoins
local MAX_STEP    = 60       -- s comptées au plus par image (écran de chargement)
local BUBBLE_GAP  = 20       -- s minimum entre deux bulles ordinaires
local BUBBLE_TIME = 6        -- s d'affichage d'une bulle
local PET_COOLDOWN = 15      -- s entre deux caresses qui comptent
local SLEEPY_AFTER = 2 * 3600  -- absence au-delà de laquelle il somnole
local SLEEPY_MIN, SLEEPY_MAX = 60, 600   -- s de jeu pour se réveiller (plafond)
local SLEEPY_PER_HOUR = 20   -- s de somnolence par heure d'absence
local NAME_MAX = 24

-- Priorités des bulles : une bulle n'efface jamais une bulle plus importante
local PRIORITY = { chatter = 0, tip = 1, need = 2, reaction = 3, advice = 4, tuto = 5, event = 6 }

-- Réglette « Bavardage » (db.companionChatter, 0 à 4) : ce qu'il dit, et à
-- quel rythme. `allow` = catégories permises (nil = toutes) ; `important` =
-- seuls les conseils marqués importants ; `advice` = écart entre deux
-- conseils de route, `bubble` = entre deux bulles ordinaires (s) ;
-- `cooldown` = facteur des pauses par famille.
local CHATTER = {
	[0] = { allow = {} },
	[1] = { allow = { advice = true, tuto = true }, important = true, advice = 180, bubble = 60, cooldown = 1 },
	[2] = { allow = { advice = true, event = true, tuto = true }, advice = 120, bubble = 60, cooldown = 1 },
	[3] = { advice = 120, bubble = 20, cooldown = 1 },
	[4] = { advice = 60, bubble = 10, cooldown = 0.5 },
}
ns.COMPANION_CHATTER = CHATTER
ns.COMPANION_CHATTER_DEFAULT = 3
local POOL_CATEGORY = {
	EVOLVE = "event", UNLOCK = "event", READY = "event", CHEST = "event", TUTO = "tuto", TIP = "tip", GOAL = "tip", GOAL_STAGE = "tip",
	IDLE = "chatter", NIGHT = "chatter",
	PHOTO = "event", ANNIV = "event", RECALL = "chatter",
	LEVEL = "event",      -- un grand moment : dit dès le cran Calme, comme promis
	NEED_hunger = "need", NEED_energy = "need", NEED_mood = "need", NEED_curiosity = "need",
}
-- Pause (s) par famille : les sources fréquentes (combat, PNJ) ne doivent pas
-- transformer le compagnon en commentateur sportif
local COOLDOWNS = {
	kill = 150, eat = 60, npc = 45, loot = 45, place = 120,
	need = 300,          -- toutes envies confondues
	need_each = 900,     -- la même envie (faim, énergie…)
	goal = 1800, idle = 900, night = 3600,
}
local TIP_GAP, TIP_JITTER = 600, 300   -- astuces : toutes les 10 à 15 min de jeu
local GOAL_FIRST = 900                 -- premier rappel d'objectif après 15 min
local NEED_LOW   = 35                  -- en dessous, il peut exprimer une envie
local HAPPY_MIN  = 70                  -- évolution : les 4 envies au moins à ce niveau
local NEED_GRACE = 120                 -- pas d'envie dans les 2 min après la connexion
local NIGHT_GRACE = 600
local IDLE_REST  = 300                 -- 5 min au repos sans rien dire : un mot
local CONVO_STEP = 3.5                 -- s entre deux bulles d'une conversation
local TUTO_STEP  = 9                   -- s par bulle du tutoriel (« Suivant » accélère)
local HISTORY    = 6                   -- lignes récentes évitées par réservoir (réservoirs triplés en 1.4.0)
local SAME_NPC   = 120                 -- même PNJ (bavardage puis vendeur) : un avis
local SAME_HUB   = 600                 -- même village ré-entré : pas de nouveau mot

ns.COMPANION_RULES = {
	floor = NEED_FLOOR, max = NEED_MAX, decay = DECAY, restGain = REST_GAIN, bubbleGap = BUBBLE_GAP,
	petCooldown = PET_COOLDOWN, sleepyAfter = SLEEPY_AFTER, sleepyMin = SLEEPY_MIN, sleepyMax = SLEEPY_MAX,
	priority = PRIORITY, cooldowns = COOLDOWNS, tipGap = TIP_GAP, tipJitter = TIP_JITTER, needLow = NEED_LOW,
	needGrace = NEED_GRACE, idleRest = IDLE_REST, convoStep = CONVO_STEP, tutoStep = TUTO_STEP,
	goalFirst = GOAL_FIRST, bubbleTime = BUBBLE_TIME,
	-- part des PNJ non humanoïdes jugés sur leur nature plutôt que leur rôle
	-- (lu à chaque fois : les tests le fixent à 0 ou 1)
	npcCreatureChance = 0.5,
}

-- ---------------------------------------------------------------------------
-- Textes (tutoiement, chaleureux, courts)
-- ---------------------------------------------------------------------------
local FR = {
	OPT_PAGE_COMPANION_MAIN = "Compagnon",
	OPT_PAGE_COMPANION_MAIN_SUB = "Sa créature, sa taille, son bavardage et son apparence.",
	OPT_PAGE_COMPANION_ORN = "Ornements",
	OPT_PAGE_COMPANION_ORN_SUB = "Les ornements de son cadre, gagnés en jouant : affiche ceux que tu aimes.",
	OPT_PAGE_COMPANION     = "Compagnon de route",
	OPT_PAGE_COMPANION_SUB = "Une petite créature qui voyage avec toi et réagit à ton aventure.",
	OPT_COMP_SHOW          = "Afficher le compagnon",
	OPT_COMP_SIZE          = "Taille",
	COMP_SIZE_1            = "Petit",
	COMP_SIZE_2            = "Moyen",
	COMP_SIZE_3            = "Grand",
	COMP_SIZE_4            = "Très grand",
	COMP_SIZE_DESC         = "La taille de son cadre ; sa bulle reste lisible et le suit.",
	OPT_COMP_CHATTER       = "Bavardage",
	COMP_CHATTER_0         = "Muet",
	COMP_CHATTER_1         = "Discret",
	COMP_CHATTER_2         = "Calme",
	COMP_CHATTER_3         = "Normal",
	COMP_CHATTER_4         = "Bavard",
	COMP_CHATTER_DESC_0    = "Muet : il t'accompagne sans un mot.",
	COMP_CHATTER_DESC_1    = "Discret : il ne parle que pour un vrai souci (élite repéré, vie basse, munitions, vivres).",
	COMP_CHATTER_DESC_2    = "Calme : tous ses conseils de route et les grands moments (niveau, évolution, coffre), sans bavarder.",
	COMP_CHATTER_DESC_3    = "Normal : conseils, réactions, envies, astuces et petites conversations.",
	COMP_CHATTER_DESC_4    = "Bavard : tout, et plus souvent.",
	COMP_CHATTER_TIP       = "Bavardage : ce que ton compagnon te dit",
	COMP_CHATTER_TIP_HINT  = "Molette ou boutons - / + pour changer. /qc compagnon muet le fait taire d'un coup.",
	OPT_COMP_ORNAMENTS     = "ORNEMENTS",
	COMP_DEFAULT_NAME      = "Brindille",
	COMP_NEED_hunger       = "Faim",
	COMP_NEED_energy       = "Énergie",
	COMP_NEED_mood         = "Moral",
	COMP_NEED_curiosity    = "Curiosité",
	COMP_MSG_READY         = "Compagnon : %s est prêt à devenir %s. Comble ses envies (toutes à %d %%) pour qu'il évolue.",
	COMP_HAPPY_LINE        = "  %s : %d %% — %s",
	COMP_HAPPY_OK          = "  %s : %d %% (comblée)",
	COMP_HOW_hunger        = "mange ou bois (ou pars avec des vivres)",
	COMP_HOW_energy        = "repose-toi à l'auberge ou au feu de camp",
	COMP_HOW_mood          = "caresse-le, rends des quêtes",
	COMP_HOW_curiosity     = "bouge : zones nouvelles ou pas vues depuis un moment, donjons, élites, vols, récolte",
	COMP_MOOD_radiant      = "radieux",
	COMP_MOOD_happy        = "content",
	COMP_MOOD_dreamy       = "rêveur",
	COMP_MOOD_sleepy       = "somnolent",
	COMP_STAGE_1           = "Nouveau-né",
	COMP_STAGE_2           = "Jeune",
	COMP_STAGE_3           = "Aguerri",
	COMP_STAGE_4           = "Vaillant",
	COMP_STAGE_5           = "Légendaire",
	COMP_APP_WHELP_GREEN   = "Dragonnet émeraude",
	COMP_APP_FROG          = "Rainette",
	COMP_APP_WHELP_RED     = "Dragonnet cramoisi",
	COMP_APP_OWL           = "Chouette grise",
	COMP_APP_WISP          = "Feu follet",
	COMP_APP_SPRITE        = "Dragon féerique",
	COMP_APP_WHELP_BLUE    = "Dragonnet azur",
	COMP_APP_WHELP_BRONZE  = "Dragonnet de bronze",
	COMP_APP_WHELP_BLACK   = "Dragonnet sombre",
	COMP_APP_CAT_ORANGE    = "Chaton roux",
	COMP_APP_RABBIT        = "Lapin des prés",
	COMP_APP_TURTLE        = "Tortue",
	COMP_APP_PARROT        = "Ara bleu",
	COMP_APP_SNAKE         = "Serpent cramoisi",
	COMP_APP_CAT_WHITE     = "Chaton blanc",
	COMP_APP_CAT_SILVER    = "Chat tigré argenté",
	COMP_APP_TOAD          = "Crapaud tacheté",
	COMP_APP_CAT_BOMBAY    = "Chat Bombay",
	COMP_APP_MACAW_RED     = "Ara écarlate",
	COMP_APP_PANDA         = "Bébé panda",
	COMP_APP_MURLOC        = "Bébé murloc",
	COMP_APP_CHICKEN       = "Poulet",
	COMP_APP_SQUIRREL_MECH = "Écureuil mécanique",
	COMP_APP_HIPPOGRYPH    = "Bébé hippogriffe",
	COMP_ORN_RIBBON        = "Ruban de voyage",
	COMP_ORN_LANTERN       = "Lanterne",
	COMP_ORN_MEDAL         = "Médaille",
	COMP_ORN_GOLD          = "Cadre doré",
	COMP_ORN_FLOWER        = "Fleur des champs",
	COMP_ORN_PENNANT       = "Fanion",
	COMP_ORN_CRYSTAL       = "Cristal de lune",
	COMP_ORN_CROWN         = "Couronne",
	-- cadres (bordure) et fonds du cadre du compagnon
	COMP_FRAME_SLATE       = "Ardoise",
	COMP_FRAME_COPPER      = "Cuivre",
	COMP_FRAME_OAK         = "Chêne",
	COMP_FRAME_SILVER      = "Argent",
	COMP_FRAME_FROST       = "Givre",
	COMP_FRAME_RUNE        = "Runique",
	COMP_FRAME_FEL         = "Gangrené",
	COMP_FRAME_GILDED      = "Or ciselé",
	COMP_FRAME_STONE       = "Pierre",
	COMP_FRAME_TOAST       = "Messager",
	COMP_FRAME_GLUE        = "Portail",
	COMP_FRAME_CARVED      = "Sculpté",
	COMP_BG_NIGHT          = "Nuit",
	COMP_BG_PARCHMENT      = "Parchemin",
	COMP_BG_FOREST         = "Sous-bois",
	COMP_BG_DUSK           = "Crépuscule",
	COMP_BG_FROST          = "Givre",
	COMP_BG_MARBLE         = "Marbre",
	COMP_BG_EMBER          = "Braise",
	COMP_BG_STARS          = "Voûte étoilée",
	COMP_BG_VELVET         = "Velours doré",
	COMP_BG_MAIL_OG        = "Lettre d'Orgrimmar",
	COMP_BG_MAIL_UC        = "Lettre de Fossoyeuse",
	COMP_BG_MAIL_TB        = "Lettre des Pitons",
	COMP_BG_DEEDS          = "Parchemin des hauts faits",
	COMP_BG_MAIL_ILL       = "Lettre enluminée",
	COMP_BG_MAIL_VAL       = "Lettre d'amour",
	COMP_BG_MAIL_CHR       = "Lettre d'hiver",
	COMP_BG_KALIMDOR       = "Kalimdor",
	COMP_BG_EASTERN        = "Royaumes de l'Est",
	COMP_BG_MOLTENCORE     = "Cœur du Magma",
	COMP_BG_AHNQIRAJ       = "Ahn'Qiraj",
	COMP_KIND_app          = "Apparence",
	COMP_KIND_orn          = "Ornement",
	COMP_KIND_frame        = "Cadre",
	COMP_KIND_bg           = "Fond",
	COMP_TIER              = "Palier %s",
	COMP_TIER_OWNED        = "Possédé",
	COMP_REWARD_LABEL      = "%s : %s",
	OPT_COMP_FRAME         = "Cadre : %s",
	OPT_COMP_BG            = "Fond : %s",
	COMP_REQ_LEVEL         = "niveau %d",
	COMP_REQ_zone          = "%d zones",
	COMP_REQ_subzone       = "%d lieux",
	COMP_REQ_dungeon       = "%d donjons",
	COMP_REQ_rare          = "%d rares",
	COMP_REQ_level         = "%d tampons de niveau",
	COMP_REQ_total         = "%d tampons",
	COMP_REQ_inn           = "%d cartes d'auberge pleines",
	COMP_REQ_missions      = "%d jours aux trois missions",
	COMP_HOVER_HINT        = "Clic : un câlin · Maj + clic : friandises · clic droit : carnet · glisser : déplacer",
	OPT_COMP_TUTO          = "Rejouer le tutoriel",
	COMP_PREVIEW_LINE      = "%s  ·  %s",
	COMP_TUTO_NEXT         = "Suivant",
	COMP_TUTO_SKIP         = "Passer",
	-- reste avant un déblocage (rappel d'objectif) : pluriel, puis singulier
	COMP_LEFT_zone         = "%d zones",
	COMP_LEFT_zone_1       = "une zone",
	COMP_LEFT_subzone      = "%d lieux",
	COMP_LEFT_subzone_1    = "un lieu",
	COMP_LEFT_dungeon      = "%d donjons",
	COMP_LEFT_dungeon_1    = "un donjon",
	COMP_LEFT_rare         = "%d rares",
	COMP_LEFT_rare_1       = "un rare",
	COMP_LEFT_total        = "%d tampons",
	COMP_LEFT_total_1      = "un tampon",
	COMP_LEFT_level        = "%d tampons de niveau",
	COMP_LEFT_level_1      = "un tampon de niveau",
	COMP_LEFT_plevel       = "%d niveaux",
	COMP_LEFT_plevel_1     = "un niveau",
	-- chat et commandes
	COMP_MSG_NEXT          = "Prochain : %s (%d/%d)",
	COMP_MSG_TUTO_MUTED    = "Bulles du compagnon coupées (Bavardage : Muet) : remonte la réglette, ou /qc compagnon muet, pour voir le tutoriel.",
	COMP_MSG_TUTO_COMBAT   = "Le tutoriel du compagnon commencera après le combat.",
	COMP_MSG_TUTO_SKIPPED  = "Tutoriel du compagnon passé (/qc compagnon tuto pour le revoir).",
	COMP_MSG_UNLOCK_APP    = "Compagnon : nouvelle apparence débloquée, %s. Choisis-la dans les réglages.",
	COMP_MSG_UNLOCK_ORN    = "Compagnon : nouvel ornement débloqué, %s.",
	COMP_MSG_EVOLVE        = "Compagnon : %s devient %s !",
	COMP_MSG_STATUS        = "%s (%s, %s) — %s",
	COMP_MSG_NEEDS         = "Faim %d · Énergie %d · Moral %d · Curiosité %d",
	COMP_MSG_COLLECTION    = "Apparences %d/%d · Ornements %d/%d",
	COMP_MSG_RENAMED       = "Ton compagnon s'appelle maintenant %s.",
	COMP_MSG_NAME_BAD      = "Donne-lui un nom : /qc compagnon nom <nom>",
	COMP_MSG_OFF           = "Le compagnon est coupé (/qc module compagnon on).",
	COMP_MSG_APPEARANCE    = "Apparence : %s.",
	COMP_MSG_MUTE          = "Bulles du compagnon : %s.",
	COMP_MSG_FALLBACK      = "Modèle 3D indisponible sur ce client : la boussole le remplace.",
	HELP_COMPANION         = "/qc compagnon [nom <nom> | caresse | apparence | muet | tuto | anim] — ton compagnon de route",
}
local EN = {
	OPT_PAGE_COMPANION_MAIN = "Companion",
	OPT_PAGE_COMPANION_MAIN_SUB = "Its creature, size, chattiness and appearance.",
	OPT_PAGE_COMPANION_ORN = "Ornaments",
	OPT_PAGE_COMPANION_ORN_SUB = "The ornaments of its frame, earned by playing: show the ones you like.",
	OPT_PAGE_COMPANION     = "Road companion",
	OPT_PAGE_COMPANION_SUB = "A little creature that travels with you and reacts to your adventure.",
	OPT_COMP_SHOW          = "Show the companion",
	OPT_COMP_SIZE          = "Size",
	COMP_SIZE_1            = "Small",
	COMP_SIZE_2            = "Medium",
	COMP_SIZE_3            = "Large",
	COMP_SIZE_4            = "Huge",
	COMP_SIZE_DESC         = "The size of its frame; its bubble stays readable and follows it.",
	OPT_COMP_CHATTER       = "Chattiness",
	COMP_CHATTER_0         = "Silent",
	COMP_CHATTER_1         = "Discreet",
	COMP_CHATTER_2         = "Calm",
	COMP_CHATTER_3         = "Normal",
	COMP_CHATTER_4         = "Chatty",
	COMP_CHATTER_DESC_0    = "Silent: it travels with you without a word.",
	COMP_CHATTER_DESC_1    = "Discreet: it only speaks up for a real problem (elite nearby, low health, ammo, food).",
	COMP_CHATTER_DESC_2    = "Calm: all its road advice and the big moments (level, evolution, chest), no small talk.",
	COMP_CHATTER_DESC_3    = "Normal: advice, reactions, needs, tips and little conversations.",
	COMP_CHATTER_DESC_4    = "Chatty: everything, and more often.",
	COMP_CHATTER_TIP       = "Chattiness: what your companion tells you",
	COMP_CHATTER_TIP_HINT  = "Mouse wheel or - / + buttons to change. /qc compagnon muet silences it at once.",
	OPT_COMP_ORNAMENTS     = "ORNAMENTS",
	COMP_DEFAULT_NAME      = "Sprig",
	COMP_NEED_hunger       = "Hunger",
	COMP_NEED_energy       = "Energy",
	COMP_NEED_mood         = "Mood",
	COMP_NEED_curiosity    = "Curiosity",
	COMP_MSG_READY         = "Companion: %s is ready to become %s. Fill its needs (all at %d %%) so it can grow.",
	COMP_HAPPY_LINE        = "  %s: %d %% — %s",
	COMP_HAPPY_OK          = "  %s: %d %% (filled)",
	COMP_HOW_hunger        = "eat or drink (or set out with food)",
	COMP_HOW_energy        = "rest at an inn or a campfire",
	COMP_HOW_mood          = "pet it, turn in quests",
	COMP_HOW_curiosity     = "move around: new zones or ones not seen in a while, dungeons, elites, flights, gathering",
	COMP_MOOD_radiant      = "radiant",
	COMP_MOOD_happy        = "happy",
	COMP_MOOD_dreamy       = "dreamy",
	COMP_MOOD_sleepy       = "sleepy",
	COMP_STAGE_1           = "Hatchling",
	COMP_STAGE_2           = "Youngling",
	COMP_STAGE_3           = "Seasoned",
	COMP_STAGE_4           = "Valiant",
	COMP_STAGE_5           = "Legendary",
	COMP_APP_WHELP_GREEN   = "Emerald whelpling",
	COMP_APP_FROG          = "Tree frog",
	COMP_APP_WHELP_RED     = "Crimson whelpling",
	COMP_APP_OWL           = "Grey owlet",
	COMP_APP_WISP          = "Wisp",
	COMP_APP_SPRITE        = "Sprite darter",
	COMP_APP_WHELP_BLUE    = "Azure whelpling",
	COMP_APP_WHELP_BRONZE  = "Bronze whelpling",
	COMP_APP_WHELP_BLACK   = "Dark whelpling",
	COMP_APP_CAT_ORANGE    = "Ginger kitten",
	COMP_APP_RABBIT        = "Meadow rabbit",
	COMP_APP_TURTLE        = "Turtle",
	COMP_APP_PARROT        = "Blue macaw",
	COMP_APP_SNAKE         = "Crimson snake",
	COMP_APP_CAT_WHITE     = "White kitten",
	COMP_APP_CAT_SILVER    = "Silver tabby",
	COMP_APP_TOAD          = "Spotted toad",
	COMP_APP_CAT_BOMBAY    = "Bombay cat",
	COMP_APP_MACAW_RED     = "Scarlet macaw",
	COMP_APP_PANDA         = "Panda cub",
	COMP_APP_MURLOC        = "Baby murloc",
	COMP_APP_CHICKEN       = "Chicken",
	COMP_APP_SQUIRREL_MECH = "Mechanical squirrel",
	COMP_APP_HIPPOGRYPH    = "Hippogryph hatchling",
	COMP_ORN_RIBBON        = "Travel ribbon",
	COMP_ORN_LANTERN       = "Lantern",
	COMP_ORN_MEDAL         = "Medal",
	COMP_ORN_GOLD          = "Golden frame",
	COMP_ORN_FLOWER        = "Wildflower",
	COMP_ORN_PENNANT       = "Pennant",
	COMP_ORN_CRYSTAL       = "Moon crystal",
	COMP_ORN_CROWN         = "Crown",
	COMP_FRAME_SLATE       = "Slate",
	COMP_FRAME_COPPER      = "Copper",
	COMP_FRAME_OAK         = "Oak",
	COMP_FRAME_SILVER      = "Silver",
	COMP_FRAME_FROST       = "Frost",
	COMP_FRAME_RUNE        = "Runic",
	COMP_FRAME_FEL         = "Fel-touched",
	COMP_FRAME_GILDED      = "Chased gold",
	COMP_FRAME_STONE       = "Stone",
	COMP_FRAME_TOAST       = "Messenger",
	COMP_FRAME_GLUE        = "Gateway",
	COMP_FRAME_CARVED      = "Carved",
	COMP_BG_NIGHT          = "Night",
	COMP_BG_PARCHMENT      = "Parchment",
	COMP_BG_FOREST         = "Undergrowth",
	COMP_BG_DUSK           = "Dusk",
	COMP_BG_FROST          = "Frost",
	COMP_BG_MARBLE         = "Marble",
	COMP_BG_EMBER          = "Embers",
	COMP_BG_STARS          = "Starry vault",
	COMP_BG_VELVET         = "Golden velvet",
	COMP_BG_MAIL_OG        = "Orgrimmar letter",
	COMP_BG_MAIL_UC        = "Undercity letter",
	COMP_BG_MAIL_TB        = "Thunder Bluff letter",
	COMP_BG_DEEDS          = "Deeds parchment",
	COMP_BG_MAIL_ILL       = "Illuminated letter",
	COMP_BG_MAIL_VAL       = "Love letter",
	COMP_BG_MAIL_CHR       = "Winter letter",
	COMP_BG_KALIMDOR       = "Kalimdor",
	COMP_BG_EASTERN        = "Eastern Kingdoms",
	COMP_BG_MOLTENCORE     = "Molten Core",
	COMP_BG_AHNQIRAJ       = "Ahn'Qiraj",
	COMP_KIND_app          = "Appearance",
	COMP_KIND_orn          = "Ornament",
	COMP_KIND_frame        = "Frame",
	COMP_KIND_bg           = "Background",
	COMP_TIER              = "Tier %s",
	COMP_TIER_OWNED        = "Owned",
	COMP_REWARD_LABEL      = "%s: %s",
	OPT_COMP_FRAME         = "Frame: %s",
	OPT_COMP_BG            = "Background: %s",
	COMP_REQ_LEVEL         = "level %d",
	COMP_REQ_zone          = "%d zones",
	COMP_REQ_subzone       = "%d places",
	COMP_REQ_dungeon       = "%d dungeons",
	COMP_REQ_rare          = "%d rares",
	COMP_REQ_level         = "%d level stamps",
	COMP_REQ_total         = "%d stamps",
	COMP_REQ_inn           = "%d full inn cards",
	COMP_REQ_missions      = "%d days with all three missions",
	COMP_HOVER_HINT        = "Click: a cuddle · Shift + click: treats · right-click: journal · drag: move",
	OPT_COMP_TUTO          = "Replay the tutorial",
	COMP_PREVIEW_LINE      = "%s  ·  %s",
	COMP_TUTO_NEXT         = "Next",
	COMP_TUTO_SKIP         = "Skip",
	COMP_LEFT_zone         = "%d zones",
	COMP_LEFT_zone_1       = "one zone",
	COMP_LEFT_subzone      = "%d places",
	COMP_LEFT_subzone_1    = "one place",
	COMP_LEFT_dungeon      = "%d dungeons",
	COMP_LEFT_dungeon_1    = "one dungeon",
	COMP_LEFT_rare         = "%d rares",
	COMP_LEFT_rare_1       = "one rare",
	COMP_LEFT_total        = "%d stamps",
	COMP_LEFT_total_1      = "one stamp",
	COMP_LEFT_level        = "%d level stamps",
	COMP_LEFT_level_1      = "one level stamp",
	COMP_LEFT_plevel       = "%d levels",
	COMP_LEFT_plevel_1     = "one level",
	COMP_MSG_NEXT          = "Next: %s (%d/%d)",
	COMP_MSG_TUTO_MUTED    = "Companion bubbles are off (Chattiness: Silent): raise the slider, or /qc compagnon muet, to see the tutorial.",
	COMP_MSG_TUTO_COMBAT   = "The companion tutorial will start after combat.",
	COMP_MSG_TUTO_SKIPPED  = "Companion tutorial skipped (/qc compagnon tuto to see it again).",
	COMP_MSG_UNLOCK_APP    = "Companion: new appearance unlocked, %s. Pick it in the settings.",
	COMP_MSG_UNLOCK_ORN    = "Companion: new ornament unlocked, %s.",
	COMP_MSG_EVOLVE        = "Companion: %s becomes %s!",
	COMP_MSG_STATUS        = "%s (%s, %s) — %s",
	COMP_MSG_NEEDS         = "Hunger %d · Energy %d · Mood %d · Curiosity %d",
	COMP_MSG_COLLECTION    = "Appearances %d/%d · Ornaments %d/%d",
	COMP_MSG_RENAMED       = "Your companion is now called %s.",
	COMP_MSG_NAME_BAD      = "Give it a name: /qc compagnon nom <name>",
	COMP_MSG_OFF           = "The companion is off (/qc module compagnon on).",
	COMP_MSG_APPEARANCE    = "Appearance: %s.",
	COMP_MSG_MUTE          = "Companion bubbles: %s.",
	COMP_MSG_FALLBACK      = "3D model unavailable on this client: the compass stands in.",
	HELP_COMPANION         = "/qc compagnon [nom <name> | caresse | apparence | muet | tuto | anim] — your road companion",
}
ns.RegisterStrings(FR, EN)
ns.COMPANION_STRINGS = { fr = FR, en = EN }   -- exposé aux tests (parité fr/en)

ns.RegisterDefaults({
	companionEnabled    = true,
	companionShow       = true,
	companionPoint      = { point = "CENTER", x = 330, y = -170 },
	companionSize       = 2,      -- réglette « Taille » : 1 petit, 2 moyen, 3 grand, 4 très grand
	companionOrnRibbon  = true,
	companionOrnLantern = true,
	companionOrnMedal   = true,
	companionOrnGold    = true,
	companionOrnFlower  = true,
	companionOrnPennant = true,
	companionOrnCrystal = true,
	companionOrnCrown   = true,
})

-- Un seul module « Compagnon de route » : le carnet de voyage le fait évoluer.
-- Entrée parente (un interrupteur) et deux sous-pages : Compagnon, Carnet.
ns.AddOptionPage({ id = "companion", title = "OPT_PAGE_COMPANION", group = "OPT_GROUP_MODULES",
	power = "companionEnabled", target = "companionMain" })
ns.AddOptionPage({
	id = "companionMain", title = "OPT_PAGE_COMPANION_MAIN", parent = "companion", group = "OPT_GROUP_MODULES",
	-- aperçu : le compagnon tel qu'il apparaît, avec son cadre et son fond
	-- (CompanionPreview, plus bas)
	preview = function(self, container) return self:CompanionPreview(container) end,
	rows = {
		{ key = "companionShow",       label = "OPT_COMP_SHOW",       kind = "bool" },
		-- réglette « Bavardage » : le nom du cran, une phrase dessous, le détail
		-- au survol, et le compagnon qui confirme
		{ key = "companionSize",       label = "OPT_COMP_SIZE",       kind = "number", min = 1, max = 4, step = 1,
			display = function(value) return L["COMP_SIZE_" .. value] end,
			describe = function() return L.COMP_SIZE_DESC end,
			onChange = function() ns:CompanionApplySize() end },
		{ key = "companionChatter",    label = "OPT_COMP_CHATTER",    kind = "number", min = 0, max = 4, step = 1,
			display = function(value) return L["COMP_CHATTER_" .. value] end,
			describe = function(value) return L["COMP_CHATTER_DESC_" .. value] end,
			tooltip = function() return ns:CompanionChatterTooltip() end,
			onChange = function(value) ns:CompanionOnChatterChanged(value) end },
		-- listes déroulantes : ce qui est gagné se choisit, le reste est grisé
		-- avec sa condition (CompanionChoices) ; l'action garde le choix suivant
		{ key = "companionAppearance", label = "COMP_KIND_app",       kind = "action",
			choices = function() return ns:CompanionChoices("app") end,
			current = function() return ns:CompanionCurrentAppearance().id end,
			choose = function(id) ns:CompanionSetAppearance(id) end },
		{ key = "companionFrameStyle", label = "COMP_KIND_frame",     kind = "action",
			choices = function() return ns:CompanionChoices("frame") end,
			current = function() return ns:CompanionCurrentStyle("frame").id end,
			choose = function(id) ns:CompanionSetStyle("frame", id) end },
		{ key = "companionBackground", label = "COMP_KIND_bg",        kind = "action",
			choices = function() return ns:CompanionChoices("bg") end,
			current = function() return ns:CompanionCurrentStyle("bg").id end,
			choose = function(id) ns:CompanionSetStyle("bg", id) end },
		{ key = "companionTutorial",   label = "OPT_COMP_TUTO",       kind = "action", button = "OPT_BTN_REPLAY" },
	},
})
-- Ornements : sous-page à part (la page principale déborderait du panneau)
ns.AddOptionPage({
	id = "companionOrnaments", title = "OPT_PAGE_COMPANION_ORN", parent = "companion", group = "OPT_GROUP_MODULES",
	rows = {
		{ key = "companionOrnRibbon",  label = "COMP_ORN_RIBBON",     kind = "bool" },
		{ key = "companionOrnLantern", label = "COMP_ORN_LANTERN",    kind = "bool" },
		{ key = "companionOrnMedal",   label = "COMP_ORN_MEDAL",      kind = "bool" },
		{ key = "companionOrnGold",    label = "COMP_ORN_GOLD",       kind = "bool" },
		{ key = "companionOrnFlower",  label = "COMP_ORN_FLOWER",     kind = "bool" },
		{ key = "companionOrnPennant", label = "COMP_ORN_PENNANT",    kind = "bool" },
		{ key = "companionOrnCrystal", label = "COMP_ORN_CRYSTAL",    kind = "bool" },
		{ key = "companionOrnCrown",   label = "COMP_ORN_CROWN",      kind = "bool" },
	},
})
-- « pet » et « compagnon » : ni un contrôle du check, ni un autre module
ns.RegisterModule({ id = "companion", key = "companionEnabled", label = "OPT_PAGE_COMPANION",
	aliases = { "compagnon", "pet", "carnet", "journal" } })

if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_QUICK" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_COMPANION")
		end
	end
end

-- ---------------------------------------------------------------------------
-- Lectures défensives
-- ---------------------------------------------------------------------------
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end
local function Method(object, name, ...)
	if type(object) ~= "table" and type(object) ~= "userdata" then return false end
	local fn = object[name]
	if type(fn) ~= "function" then return false end
	return pcall(fn, object, ...)
end
local function Clock() return (ns.Now and ns.Now()) or 0 end                 -- temps de jeu (GetTime)
local function Wall() return tonumber(Call(rawget(_G, "time"))) or 0 end      -- heure réelle (absence)
local function PlayerLevel() return tonumber((Call(rawget(_G, "UnitLevel"), "player"))) or 1 end
local function Clamp(v, lo, hi) if v < lo then return lo end if v > hi then return hi end return v end
-- Combat : verrou de l'interface OU drapeau de l'unité (les deux existent
-- sur les deux clients, l'un peut manquer sur un client modifié)
local function InCombat()
	if Call(rawget(_G, "InCombatLockdown")) then return true end
	return Call(rawget(_G, "UnitAffectingCombat"), "player") and true or false
end

local function ModuleOn()
	local db = ns:DB()
	return db.enabled ~= false and db.companionEnabled ~= false
end
ns.CompanionOn = function() return ModuleOn() end

-- ---------------------------------------------------------------------------
-- État par personnage
-- ---------------------------------------------------------------------------
function ns:CompanionData()
	local char = self:CharData()
	local data = char.companion
	if type(data) ~= "table" then
		data = {}
		char.companion = data
	end
	if type(data.needs) ~= "table" then data.needs = {} end
	for _, key in ipairs(NEED_KEYS) do
		local v = tonumber(data.needs[key])
		data.needs[key] = v and Clamp(v, NEED_FLOOR, NEED_MAX) or NEED_START
	end
	data.unlocked = type(data.unlocked) == "table" and data.unlocked or {}
	data.seenZones = type(data.seenZones) == "table" and data.seenZones or {}
	data.seenSub = type(data.seenSub) == "table" and data.seenSub or {}
	data.appearance = data.appearance or ns.COMPANION_APPEARANCES[1].id
	return data
end

-- Le nom que tu as donné à ta mascotte (/qc compagnon nom)
function ns:CompanionOwnName()
	local name = self:CompanionData().name
	if type(name) == "string" and name ~= "" then return name end
	return L.COMP_DEFAULT_NAME
end

-- Le nom affiché : une créature capturée garde le sien (« Champion
-- Ravenclaw »), seule la mascotte porte le nom que tu lui as donné (1.5.2)
function ns:CompanionName()
	local data = self:CompanionData()
	local npc = type(data.appearance) == "string" and tonumber(data.appearance:match("^cap:(%d+)$"))
	if npc and self.CaptureData then
		local ok, capture = pcall(self.CaptureData, self)
		local entry = ok and type(capture) == "table" and type(capture.creatures) == "table"
			and (capture.creatures[npc] or capture.creatures[tostring(npc)])
		if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" then return entry.name end
	end
	return self:CompanionOwnName()
end

-- Un besoin ne passe jamais sous le plancher ni au-dessus de 100
function ns:CompanionAdd(key, amount)
	local needs = self:CompanionData().needs
	if needs[key] == nil then return end
	needs[key] = Clamp(needs[key] + (tonumber(amount) or 0), NEED_FLOOR, NEED_MAX)
	self:CompanionRefreshHover()
	-- prêt à évoluer : une envie comblée peut être la dernière qui manquait
	local data = self:CompanionData()
	if data.stageReady and (tonumber(amount) or 0) > 0 and self:CompanionIsHappy() then
		self:CompanionCheckStage(PlayerLevel(), true)
	end
end

function ns:CompanionMood()
	local data = self:CompanionData()
	if data.sleepy then return "sleepy" end
	local sum = 0
	for _, key in ipairs(NEED_KEYS) do sum = sum + data.needs[key] end
	local avg = sum / #NEED_KEYS
	-- pas d'humeur « triste » : le bas de l'échelle est juste rêveur
	if avg >= 75 then return "radiant" end
	if avg >= 50 then return "happy" end
	return "dreamy"
end

-- ---------------------------------------------------------------------------
-- Stades d'évolution (niveau du joueur)
-- ---------------------------------------------------------------------------
function ns:CompanionStageFor(level)
	level = tonumber(level) or 1
	local stage = 1
	for index, def in ipairs(ns.COMPANION_STAGES) do
		if level >= def.level then stage = index end
	end
	return stage
end

function ns:CompanionStage()
	local data = self:CompanionData()
	return data.stage or self:CompanionStageFor(PlayerLevel())
end

function ns:CompanionStageLabel(stage)
	local def = ns.COMPANION_STAGES[stage or self:CompanionStage()] or ns.COMPANION_STAGES[1]
	return L[def.label]
end

-- Heureux = les quatre envies au moins à HAPPY_MIN, et réveillé
function ns:CompanionHappyCount()
	local data, count = self:CompanionData(), 0
	for _, key in ipairs(NEED_KEYS) do
		if (data.needs[key] or 0) >= HAPPY_MIN then count = count + 1 end
	end
	return count, #NEED_KEYS
end

function ns:CompanionIsHappy()
	local count, total = self:CompanionHappyCount()
	return count == total and not self:CompanionData().sleepy
end

-- Survol de l'objectif « heureux » : chaque envie, et comment la remplir
function ns:CompanionHappyHints()
	local data, lines = self:CompanionData(), {}
	for _, key in ipairs(NEED_KEYS) do
		local value = math.floor(data.needs[key] or 0)
		local label = L["COMP_NEED_" .. key]
		if value >= HAPPY_MIN then
			lines[#lines + 1] = self:F("COMP_HAPPY_OK", label, value)
		else
			lines[#lines + 1] = self:F("COMP_HAPPY_LINE", label, value, L["COMP_HOW_" .. key])
		end
	end
	return lines
end
ns.COMPANION_HAPPY_MIN = HAPPY_MIN

-- Le niveau ouvre l'étape, le bonheur la franchit : palier atteint, la
-- créature est « prête » (data.stageReady) et évolue dès que ses quatre
-- envies sont comblées. Jamais de retour en arrière, jamais de punition :
-- elle attend, c'est tout.
-- `celebrate` = false au tout premier relevé : un joueur qui installe
-- l'addon au niveau 45 ne voit pas trois évolutions d'affilée
function ns:CompanionCheckStage(level, celebrate)
	local data = self:CompanionData()
	local target = self:CompanionStageFor(level or PlayerLevel())
	if data.stage == nil then
		data.stage = target
		self:CompanionApplyModel()
		return false
	end
	if target <= data.stage then data.stageReady = nil; return false end   -- jamais de retour en arrière
	if not self:CompanionIsHappy() then
		if data.stageReady ~= target then
			data.stageReady = target
			if celebrate ~= false then
				local label = L[(ns.COMPANION_STAGES[target] or {}).label] or ""
				self:Print(self:F("COMP_MSG_READY", self:CompanionName(), label, HAPPY_MIN))
				self:CompanionSay("READY", { force = true, args = { label } })
			end
			if self.RefreshJournalTracker then pcall(self.RefreshJournalTracker, self) end
		end
		return false
	end
	data.stage, data.stageReady = target, nil
	self:CompanionApplyModel()
	if celebrate ~= false then self:CompanionCelebrate() end
	if self.RefreshJournalTracker then pcall(self.RefreshJournalTracker, self) end
	return true
end

function ns:CompanionCelebrate()
	local label = self:CompanionStageLabel()
	self:Print(self:F("COMP_MSG_EVOLVE", self:CompanionName(), label))
	self:CompanionSay("EVOLVE", { force = true, args = { label } })
	self:CompanionAnimate("dance", 3)
end

-- ---------------------------------------------------------------------------
-- Cosmétiques : apparences et ornements
-- ---------------------------------------------------------------------------
function ns:CompanionCounts()
	local counts = { zone = 0, subzone = 0, dungeon = 0, rare = 0, level = 0, total = 0 }
	if type(self.JournalCounts) == "function" then
		local ok, result = pcall(self.JournalCounts, self)
		if ok and type(result) == "table" then
			for key in pairs(counts) do counts[key] = tonumber(result[key]) or 0 end
		end
	end
	return counts
end

function ns:CompanionMeets(unlock, counts, level)
	if not unlock then return true end
	if unlock.level then return (level or PlayerLevel()) >= unlock.level end
	if unlock.stamp then return ((counts or self:CompanionCounts())[unlock.stamp] or 0) >= (unlock.count or 1) end
	return false
end

function ns:CompanionRequirement(unlock)
	if not unlock then return "" end
	if unlock.level then return self:F("COMP_REQ_LEVEL", unlock.level) end
	if unlock.inn then return self:F("COMP_REQ_inn", unlock.inn) end
	if unlock.missions then return self:F("COMP_REQ_missions", unlock.missions) end
	if unlock.shiny then return self:F("COMP_REQ_shiny", unlock.shiny) end
	return self:F("COMP_REQ_" .. tostring(unlock.stamp), unlock.count or 1)
end

local function CosmeticKey(kind, id) return kind .. ":" .. id end

-- v1.25.0 : un cosmétique à palier (tier >= 1) ne se gagne qu'au coffre
-- d'une zone finie (CompanionChest.lua) ; ce qui a déjà été gagné reste acquis.
local function Tiered(def) return (tonumber(def.tier) or 0) >= 1 end
function ns:CompanionIsUnlocked(kind, def)
	if not def then return false end
	if not def.unlock and not Tiered(def) then return true end
	return self:CompanionData().unlocked[CosmeticKey(kind, def.id)] == true
end

-- Le catalogue des mascottes, puis la ménagerie (créatures capturées,
-- Capture.lua) : toutes les apparences possibles
function ns:CompanionAllAppearances()
	local captured = self.CaptureAppearances and self:CaptureAppearances()
	if type(captured) ~= "table" or #captured == 0 then return ns.COMPANION_APPEARANCES end
	local list = {}
	for _, def in ipairs(ns.COMPANION_APPEARANCES) do list[#list + 1] = def end
	for _, def in ipairs(captured) do list[#list + 1] = def end
	return list
end

function ns:CompanionAppearanceDef(id)
	for _, def in ipairs(self:CompanionAllAppearances()) do
		if def.id == id then return def end
	end
	return nil
end

-- Revérifie tout le catalogue. Un déblocage est définitif : la créature ne
-- perd jamais ce qu'elle a gagné, même si le Carnet est coupé ensuite.
-- `silent` : rien d'annoncé (premier relevé) ; `noBubble` : le chat seul,
-- quand une bulle plus importante occupe déjà la place (évolution)
function ns:CompanionCheckUnlocks(level, silent, noBubble)
	local data = self:CompanionData()
	-- premier relevé de ce personnage, d'où qu'il vienne (connexion, module
	-- activé en cours de partie, tampon) : silencieux. Sinon un joueur qui
	-- installe l'addon au niveau 45 reçoit une rafale de « débloqué ! ».
	if not data.unlockBaseline then
		silent = true
		data.unlockBaseline = true
	end
	local counts = self:CompanionCounts()
	local fresh = {}
	local function Scan(kind, list)
		for _, def in ipairs(list) do
			local key = CosmeticKey(kind, def.id)
			if def.unlock and not Tiered(def) and not data.unlocked[key] and self:CompanionMeets(def.unlock, counts, level) then
				data.unlocked[key] = true
				fresh[#fresh + 1] = { kind = kind, def = def }
			end
		end
	end
	Scan("app", ns.COMPANION_APPEARANCES)
	Scan("orn", ns.COMPANION_ORNAMENTS)
	if #fresh == 0 then return fresh end
	if not silent then
		for _, item in ipairs(fresh) do
			self:Print(self:F(item.kind == "app" and "COMP_MSG_UNLOCK_APP" or "COMP_MSG_UNLOCK_ORN", L[item.def.label]))
		end
		-- une bulle pour le lot (la dernière nouveauté), pas une rafale
		if not noBubble then self:CompanionSay("UNLOCK", { force = true, args = { L[fresh[#fresh].def.label] } }) end
	end
	self:CompanionApplyOrnaments()
	if self.RefreshOptions then self:RefreshOptions() end
	return fresh
end

function ns:CompanionUnlockedAppearances()
	local list = {}
	for _, def in ipairs(self:CompanionAllAppearances()) do
		if self:CompanionIsUnlocked("app", def) then list[#list + 1] = def end
	end
	return list
end

function ns:CompanionCurrentAppearance()
	local data = self:CompanionData()
	local def = self:CompanionAppearanceDef(data.appearance)
	if not (def and self:CompanionIsUnlocked("app", def)) then
		def = ns.COMPANION_APPEARANCES[1]
		data.appearance = def.id
	end
	return def
end

-- Choix d'apparence : passe à la suivante parmi celles débloquées
function ns:CompanionCycleAppearance()
	local list = self:CompanionUnlockedAppearances()
	local current = self:CompanionCurrentAppearance()
	local nextDef = list[1]
	for index, def in ipairs(list) do
		if def.id == current.id then nextDef = list[(index % #list) + 1] end
	end
	self:CompanionData().appearance = nextDef.id
	self:CompanionApplyModel()
	if self.RefreshOptions then self:RefreshOptions() end
	return nextDef
end

-- Choix direct (liste des réglages) ; refusé (nil) si verrouillé
function ns:CompanionSetAppearance(id)
	local def = self:CompanionAppearanceDef(id)
	if not (def and self:CompanionIsUnlocked("app", def)) then return nil end
	self:CompanionData().appearance = def.id
	self:CompanionApplyModel()
	if self.RefreshOptions then self:RefreshOptions() end
	return def
end

function ns:CompanionOrnamentShown(def)
	local db = self:DB()
	return self:CompanionIsUnlocked("orn", def) and db[def.key] ~= false
end

-- Cadres et fonds : même convention que l'apparence (choix par personnage,
-- dans CompanionData ; un choix verrouillé retombe sur le premier, tier 0)
local STYLES = {
	frame = { field = "frameStyle", list = function() return ns.COMPANION_FRAMES end },
	bg    = { field = "background", list = function() return ns.COMPANION_BACKGROUNDS end },
}

function ns:CompanionStyleDef(kind, id)
	local style = STYLES[kind]
	if not style then return nil end
	for _, def in ipairs(style.list()) do
		if def.id == id then return def end
	end
	return nil
end

function ns:CompanionCurrentStyle(kind)
	local style = STYLES[kind]
	if not style then return nil end
	local data = self:CompanionData()
	local def = self:CompanionStyleDef(kind, data[style.field])
	if not (def and self:CompanionIsUnlocked(kind, def)) then
		def = style.list()[1]
		data[style.field] = def.id
	end
	return def
end

-- Choisit un style ; refusé (nil) s'il est inconnu ou verrouillé
function ns:CompanionSetStyle(kind, id)
	local def = self:CompanionStyleDef(kind, id)
	if not (def and self:CompanionIsUnlocked(kind, def)) then return nil end
	self:CompanionData()[STYLES[kind].field] = def.id
	if kind == "frame" then self:CompanionApplyFrame() else self:CompanionApplyBackground() end
	if self.RefreshOptions then self:RefreshOptions() end
	return def
end

-- Style suivant parmi ceux débloqués (clic sur la ligne des réglages)
function ns:CompanionCycleStyle(kind)
	local style = STYLES[kind]
	if not style then return nil end
	local current = self:CompanionCurrentStyle(kind)
	local list = {}
	for _, def in ipairs(style.list()) do
		if self:CompanionIsUnlocked(kind, def) then list[#list + 1] = def end
	end
	local nextDef = list[1] or current
	for index, def in ipairs(list) do
		if def.id == current.id then nextDef = list[(index % #list) + 1] end
	end
	return self:CompanionSetStyle(kind, nextDef.id)
end

-- Nom lisible d'une récompense (entrée de ns.COMPANION_REWARDS) ;
-- `withKind` : préfixé du type (« Cadre : Givre »)
function ns:CompanionRewardLabel(reward, withKind)
	if type(reward) ~= "table" then return "" end
	local name = L[reward.label] or tostring(reward.label or reward.id or "")
	if withKind and reward.kind then
		return self:F("COMP_REWARD_LABEL", L["COMP_KIND_" .. reward.kind] or reward.kind, name)
	end
	return name
end

-- ---------------------------------------------------------------------------
-- Bulles : priorités, écart minimal, pauses par catégorie, sourdine
-- ---------------------------------------------------------------------------
-- État de session (jamais sauvegardé : une pause n'a pas à survivre à un
-- /reload, et un historique perdu ne fait que permettre une répétition)
local function RT()
	local rt = ns.companionRT
	if not rt then
		rt = { cool = {}, recent = {}, hubSeen = {} }
		ns.companionRT = rt
	end
	return rt
end

local function CategoryOf(pool)
	return POOL_CATEGORY[pool] or "reaction"
end

local function Families(cd)
	if cd == nil then return {} end
	if type(cd) == "table" then return cd end
	return { cd }
end

-- Une ligne au hasard dans un réservoir, sans répéter les dernières.
-- `args` absent : les lignes à « %s » / « %d » sont écartées (un PNJ sans nom).
-- `list` : liste de noms à la place d'un réservoir (choix d'une conversation).
function ns:CompanionPick(pool, args, list)
	local keys = list or (ns.COMPANION_POOLS and ns.COMPANION_POOLS[pool])
	if type(keys) ~= "table" or #keys == 0 then return nil end
	local hasArg = type(args) == "table" and args[1] ~= nil
	local usable = {}
	for _, key in ipairs(keys) do
		local text = (not list) and L[key] or ""
		if hasArg or not text:find("%%[sd]") then usable[#usable + 1] = key end
	end
	if #usable == 0 then return nil end
	local rt = RT()
	local recent = rt.recent[pool] or {}
	rt.recent[pool] = recent
	local candidates = {}
	for _, key in ipairs(usable) do
		local seen = false
		for _, old in ipairs(recent) do if old == key then seen = true end end
		if not seen then candidates[#candidates + 1] = key end
	end
	-- tout est récent (petit réservoir filtré) : on évite au moins la dernière
	if #candidates == 0 then
		for _, key in ipairs(usable) do if key ~= recent[#recent] then candidates[#candidates + 1] = key end end
	end
	if #candidates == 0 then candidates = usable end
	local pick = candidates[math.random(#candidates)]
	recent[#recent + 1] = pick
	local keep = math.max(1, math.min(HISTORY, #usable - 1))
	while #recent > keep do table.remove(recent, 1) end
	return pick
end

-- Cran de bavardage (0 muet … 4 bavard). Première lecture : déduit des
-- anciens interrupteurs (bulles coupées -> 0, astuces coupées -> 2), puis
-- enregistré.
function ns:CompanionChatterLevel()
	local db = self:DB()
	local level = tonumber(db.companionChatter)
	if level == nil then
		level = (db.companionBubbles == false and 0) or (db.companionTips == false and 2) or ns.COMPANION_CHATTER_DEFAULT
		db.companionChatter = level
	end
	level = math.floor(level)
	if level < 0 then level = 0 elseif level > 4 then level = 4 end
	return level
end

-- `pool` : nom du réservoir (CompanionLines.lua). Options :
--   force    : passe outre l'écart minimal (évolution, retour, caresse…)
--   category : catégorie de priorité (sinon déduite du réservoir)
--   cd       : famille(s) de pause (COOLDOWNS), vérifiées puis armées
--   line     : clé imposée (astuce choisie, étape de séquence)
--   args     : arguments du texte
--   seq      : étape d'une séquence (conversation, tutoriel)
--   duration : durée d'affichage
--   important: conseil de route important (élite, vie, munitions, vivres) :
--              seul ce qui passe au cran « Discret »
-- Jamais outre la sourdine ni une bulle plus importante encore affichée.
-- Renvoie true, ou false + raison ("off" : coupé/muet/masqué, "busy").
function ns:CompanionSay(pool, opts)
	opts = opts or {}
	if not ModuleOn() then return false, "off" end
	local db = self:DB()
	if db.companionShow == false then return false, "off" end
	local level = CHATTER[self:CompanionChatterLevel()]
	local rt, now = RT(), Clock()
	local category = opts.category or CategoryOf(pool)
	local prio = PRIORITY[category] or PRIORITY.reaction
	-- réglette « Bavardage » : ce que ce cran laisse dire
	if level.allow and not level.allow[category] then return false, "off" end
	if level.important and category == "advice" and not opts.important then return false, "off" end
	if category == "advice" and not opts.force and rt.lastAdvice and now - rt.lastAdvice < (level.advice or 120) then
		return false, "busy"
	end
	local seq = rt.seq
	-- ce qui occupe déjà la place : la bulle affichée, la séquence en cours
	if self.companionBubbleUntil and now < self.companionBubbleUntil and prio < (self.companionBubblePrio or 0) then
		return false, "busy"
	end
	if seq and not opts.seq and prio <= seq.prio then return false, "busy" end
	if not opts.force and not opts.seq and category ~= "advice" and prio < PRIORITY.tuto and self.companionLastBubble
		and now - self.companionLastBubble < (level.bubble or BUBBLE_GAP) then
		return false, "busy"
	end
	local families = Families(opts.cd)
	for _, family in ipairs(families) do
		if rt.cool[family] and now < rt.cool[family] then return false, "busy" end
	end
	local lineKey = opts.line or self:CompanionPick(pool, opts.args)
	if not lineKey then return false, "busy" end
	-- la bulle part du cadre : il doit être affiché
	if not self:CompanionUpdateVisibility() then return false, "off" end
	local bubble = self:EnsureCompanionBubble()
	if not bubble then return false, "off" end
	local text = self:F(lineKey, unpack(opts.args or {}))
	-- plus importante qu'une séquence : la conversation s'arrête, le
	-- tutoriel reprendra son étape après la bulle
	if seq and not opts.seq then
		if seq.kind == "tuto" then
			seq.index = math.max(0, seq.index - 1)
			seq.nextAt = now + BUBBLE_TIME
		else
			rt.seq = nil
		end
	end
	for _, family in ipairs(families) do
		local wait = COOLDOWNS[family]
		if not wait and family:find("^need_") then wait = COOLDOWNS.need_each end
		rt.cool[family] = now + (wait or 0) * (level.cooldown or 1)
	end
	if category == "advice" then rt.lastAdvice = now end
	self.companionLastBubble = now
	self.companionBubbleKey, self.companionBubbleText, self.companionBubbleLine = pool, text, lineKey
	self.companionBubblePrio = prio
	self.companionBubbleUntil = now + (opts.duration or BUBBLE_TIME)
	local tuto = category == "tuto"
	-- la bulle prend la hauteur du texte, plus la rangée de boutons du tutoriel
	bubble:SetText(text, tuto and (Theme.DIALOG_BUTTON_HEIGHT or 28) or 0)
	if bubble.nextButton then
		if tuto then bubble.nextButton:Show(); bubble.skipButton:Show()
		else bubble.nextButton:Hide(); bubble.skipButton:Hide() end
	end
	bubble:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, bubble) end
	return true
end

function ns:CompanionHideBubble()
	self.companionBubbleUntil = nil
	self.companionBubblePrio = nil
	if self.companionBubble then self.companionBubble:Hide() end
end

-- ---------------------------------------------------------------------------
-- Séquences : petite conversation (clic) et tutoriel
-- ---------------------------------------------------------------------------
function ns:CompanionStartSequence(kind, pool, steps, stepTime, args)
	local rt = RT()
	rt.seq = {
		kind = kind, pool = pool, steps = steps, index = 0, step = stepTime, args = args,
		prio = kind == "tuto" and PRIORITY.tuto or PRIORITY.reaction, nextAt = Clock(),
	}
	return self:CompanionSequenceStep()
end

function ns:CompanionSequenceStep()
	local rt = RT()
	local seq = rt.seq
	if not seq then return false end
	local now = Clock()
	-- jamais de tutoriel en combat : il attend, la même étape reviendra
	if seq.kind == "tuto" and InCombat() then
		self:CompanionPauseTutorial()
		return false
	end
	seq.index = seq.index + 1
	local key = seq.steps[seq.index]
	if not key then
		rt.seq = nil
		if seq.kind == "tuto" then self:CompanionFinishTutorial() end
		return false
	end
	local ok, why = self:CompanionSay(seq.pool, {
		seq = true, line = key, args = seq.args, category = seq.kind == "tuto" and "tuto" or "reaction",
		duration = math.max(BUBBLE_TIME, seq.step),
	})
	if ok then
		seq.nextAt = now + seq.step
		return true
	end
	if why == "busy" then
		-- une bulle plus importante occupe la place : on réessaie bientôt
		seq.index = seq.index - 1
		seq.nextAt = now + 1
		return false
	end
	-- coupé, muet ou masqué : la séquence s'arrête (le tutoriel n'est pas
	-- marqué comme vu, il reviendra à la prochaine connexion)
	rt.seq = nil
	return false
end

-- Conversation : une au hasard, jamais la même que les dernières
function ns:CompanionStartConvo()
	local name = self:CompanionPick("CONVOS", nil, ns.COMPANION_CONVOS or {})
	if not name then return false end
	return self:CompanionStartSequence("convo", name, ns.COMPANION_POOLS[name], CONVO_STEP)
end

-- Tutoriel : à la première apparition (par personnage), et à la demande
function ns:CompanionStartTutorial(manual)
	if not ModuleOn() then return false end
	local db = self:DB()
	local rt = RT()
	if self:CompanionChatterLevel() == 0 or db.companionShow == false then
		if manual then self:Print(L.COMP_MSG_TUTO_MUTED) end
		return false
	end
	if InCombat() then
		rt.tutoPending = true
		if manual then self:Print(L.COMP_MSG_TUTO_COMBAT) end
		return false
	end
	rt.tutoPending = nil
	return self:CompanionStartSequence("tuto", "TUTO", ns.COMPANION_POOLS.TUTO, TUTO_STEP, { self:CompanionName() })
end

-- Combat qui commence : la bulle du tutoriel s'efface, son étape reviendra.
-- Appelée dès PLAYER_REGEN_DISABLED, où InCombatLockdown() vaut encore faux.
function ns:CompanionPauseTutorial()
	local seq = self.companionRT and self.companionRT.seq
	if not (seq and seq.kind == "tuto") then return false end
	if self.companionBubblePrio == PRIORITY.tuto and self.companionBubbleUntil then
		self:CompanionHideBubble()
		seq.index = math.max(0, seq.index - 1)
	end
	seq.nextAt = Clock() + 1
	return true
end

function ns:CompanionTutorialActive()
	local seq = self.companionRT and self.companionRT.seq
	return seq ~= nil and seq.kind == "tuto"
end

function ns:CompanionTutorialNext()
	if not self:CompanionTutorialActive() then return false end
	self:CompanionHideBubble()
	self:CompanionSequenceStep()
	return true
end

function ns:CompanionFinishTutorial()
	self:CompanionData().tutoDone = true
	local rt = RT()
	rt.tutoPending = nil
	if rt.seq and rt.seq.kind == "tuto" then rt.seq = nil end
	if self.companionBubblePrio == PRIORITY.tuto then self:CompanionHideBubble() end
end

function ns:CompanionSkipTutorial()
	local active = self:CompanionTutorialActive() or RT().tutoPending
	self:CompanionFinishTutorial()
	if active then self:Print(L.COMP_MSG_TUTO_SKIPPED) end
	return active and true or false
end

-- ---------------------------------------------------------------------------
-- Cadre : modèle 3D (ou boussole), nom, ornements, bulle, survol
-- ---------------------------------------------------------------------------
local FRAME_W, FRAME_H = 104, 118
local MODEL_H = 82
-- Taille du cadre (réglette « Taille », db.companionSize 1 à 4) : échelle du
-- cadre ; la bulle et l'infobulle gardent leur taille (lisibles) et le suivent.
ns.COMPANION_SIZES = { 0.8, 1.0, 1.3, 1.6 }
ns.COMPANION_SIZE_DEFAULT = 2

function ns:CompanionSizeLevel()
	local level = math.floor(tonumber(self:DB().companionSize) or ns.COMPANION_SIZE_DEFAULT)
	if level < 1 then level = 1 elseif level > #ns.COMPANION_SIZES then level = #ns.COMPANION_SIZES end
	return level
end

-- Applique la taille ; la position mémorisée (en unités du cadre) est recalée
-- pour que le compagnon ne saute pas à l'écran quand on change de taille.
function ns:CompanionApplySize()
	local frame = self.companionFrame
	if not frame or not frame.SetScale then return nil end
	local scale = ns.COMPANION_SIZES[self:CompanionSizeLevel()]
	local before = (frame.GetScale and frame:GetScale()) or 1
	if before ~= scale then
		local db = self:DB()
		local point = db.companionPoint
		if type(point) == "table" and before > 0 then
			point.x = (tonumber(point.x) or 0) * before / scale
			point.y = (tonumber(point.y) or 0) * before / scale
			frame:ClearAllPoints()
			frame:SetPoint(point.point or "CENTER", UIParent, point.point or "CENTER", point.x, point.y)
		end
		frame:SetScale(scale)
	end
	return scale
end

-- Un PlayerModel (ou Model) n'est gardé que s'il sait afficher une créature
local function CreateModel(parent)
	for _, kind in ipairs({ "PlayerModel", "Model" }) do
		local ok, model = pcall(CreateFrame, kind, nil, parent)
		if ok and model then
			if type(model.SetDisplayInfo) == "function" or type(model.SetCreature) == "function" then
				return model
			end
			if model.Hide then model:Hide() end
		end
	end
	return nil
end

local function BuildOrnaments(frame)
	local orn = {}
	-- ruban : bandeau bleu de nuit en travers du coin haut gauche, et sa queue
	orn.ribbon = CreateFrame("Frame", nil, frame)
	orn.ribbon:SetSize(34, 10)
	orn.ribbon:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
	orn.ribbon.band = Theme.Solid(orn.ribbon, "OVERLAY", Theme.BLUE, 0.95)
	orn.ribbon.band:SetPoint("TOPLEFT", orn.ribbon, "TOPLEFT", 0, 0)
	orn.ribbon.band:SetSize(34, 5)
	orn.ribbon.tail = Theme.Solid(orn.ribbon, "OVERLAY", Theme.BLUE, 0.75)
	orn.ribbon.tail:SetPoint("TOPLEFT", orn.ribbon, "TOPLEFT", 4, -5)
	orn.ribbon.tail:SetSize(5, 8)
	-- lanterne : un fil, un corps ambre et un halo doux, en haut à droite
	orn.lantern = CreateFrame("Frame", nil, frame)
	orn.lantern:SetSize(14, 24)
	orn.lantern:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 6)
	orn.lantern.wire = Theme.Solid(orn.lantern, "ARTWORK", Theme.GOLD_SOFT, 1)
	orn.lantern.wire:SetPoint("TOP", orn.lantern, "TOP", 0, 0)
	orn.lantern.wire:SetSize(1, 8)
	orn.lantern.glow = Theme.Solid(orn.lantern, "ARTWORK", Theme.GOLD, 0.25)
	orn.lantern.glow:SetPoint("TOP", orn.lantern, "TOP", 0, -6)
	orn.lantern.glow:SetSize(14, 16)
	orn.lantern.body = Theme.Solid(orn.lantern, "OVERLAY", Theme.GOLD, 1)
	orn.lantern.body:SetPoint("TOP", orn.lantern, "TOP", 0, -9)
	orn.lantern.body:SetSize(7, 10)
	-- médaille : losange doré sur un ruban, en bas à gauche
	orn.medal = CreateFrame("Frame", nil, frame)
	orn.medal:SetSize(16, 22)
	orn.medal:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 18)
	orn.medal.strap = Theme.Solid(orn.medal, "ARTWORK", Theme.RED, 0.9)
	orn.medal.strap:SetPoint("TOP", orn.medal, "TOP", 0, 0)
	orn.medal.strap:SetSize(6, 9)
	orn.medal.disc = Theme.CreateDiamond(orn.medal, 14)
	orn.medal.disc:SetPoint("TOP", orn.medal, "TOP", 0, -7)
	orn.medal.disc:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
	-- cadre doré : double liseré ambre autour du cadre
	orn.gold = CreateFrame("Frame", nil, frame)
	orn.gold:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
	orn.gold:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
	orn.gold.outer = Theme.Border(orn.gold, Theme.GOLD, 1, "OVERLAY")
	orn.gold.corner = { Theme.CornerAccent(frame) }
	-- fleur des champs : une tige verte et un losange rose, en bas à droite
	orn.flower = CreateFrame("Frame", nil, frame)
	orn.flower:SetSize(12, 20)
	orn.flower:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 18)
	orn.flower.stem = Theme.Solid(orn.flower, "ARTWORK", Theme.GREEN, 0.9)
	orn.flower.stem:SetPoint("BOTTOM", orn.flower, "BOTTOM", 0, 0)
	orn.flower.stem:SetSize(1, 11)
	orn.flower.leaf = Theme.Solid(orn.flower, "ARTWORK", Theme.GREEN, 0.7)
	orn.flower.leaf:SetPoint("BOTTOM", orn.flower, "BOTTOM", 2, 4)
	orn.flower.leaf:SetSize(3, 2)
	orn.flower.petals = Theme.CreateDiamond(orn.flower, 10)
	orn.flower.petals:SetPoint("TOP", orn.flower, "TOP", 0, 0)
	orn.flower.petals:SetVertexColor(0.95, 0.55, 0.70, 1)
	orn.flower.heart = Theme.Solid(orn.flower, "OVERLAY", Theme.GOLD, 1)
	orn.flower.heart:SetPoint("TOP", orn.flower, "TOP", 0, -4)
	orn.flower.heart:SetSize(2, 2)
	-- fanion : une hampe et un petit drapeau rouge à liseré ambre, flanc gauche
	orn.pennant = CreateFrame("Frame", nil, frame)
	orn.pennant:SetSize(14, 22)
	orn.pennant:SetPoint("LEFT", frame, "LEFT", -6, 14)
	orn.pennant.pole = Theme.Solid(orn.pennant, "ARTWORK", Theme.GOLD_SOFT, 1)
	orn.pennant.pole:SetPoint("TOPLEFT", orn.pennant, "TOPLEFT", 0, 0)
	orn.pennant.pole:SetSize(1, 22)
	orn.pennant.flag = Theme.Solid(orn.pennant, "OVERLAY", Theme.RED, 0.95)
	orn.pennant.flag:SetPoint("TOPLEFT", orn.pennant, "TOPLEFT", 1, -1)
	orn.pennant.flag:SetSize(11, 7)
	orn.pennant.hem = Theme.Solid(orn.pennant, "OVERLAY", Theme.GOLD, 1)
	orn.pennant.hem:SetPoint("TOPLEFT", orn.pennant, "TOPLEFT", 1, -8)
	orn.pennant.hem:SetSize(11, 1)
	-- cristal de lune : losange bleu pâle et son halo, flanc droit
	orn.crystal = CreateFrame("Frame", nil, frame)
	orn.crystal:SetSize(18, 18)
	orn.crystal:SetPoint("RIGHT", frame, "RIGHT", 7, 10)
	orn.crystal.glow = Theme.Solid(orn.crystal, "ARTWORK", { 0.60, 0.85, 1 }, 0.18)
	orn.crystal.glow:SetPoint("CENTER", orn.crystal, "CENTER", 0, 0)
	orn.crystal.glow:SetSize(16, 16)
	orn.crystal.gem = Theme.CreateDiamond(orn.crystal, 12)
	orn.crystal.gem:SetPoint("CENTER", orn.crystal, "CENTER", 0, 0)
	orn.crystal.gem:SetVertexColor(0.70, 0.90, 1, 1)
	orn.crystal.shine = Theme.Solid(orn.crystal, "OVERLAY", { 1, 1, 1 }, 0.9)
	orn.crystal.shine:SetPoint("CENTER", orn.crystal, "CENTER", -1, 2)
	orn.crystal.shine:SetSize(2, 2)
	-- couronne : un bandeau d'or et trois pointes en losange, en haut au centre
	orn.crown = CreateFrame("Frame", nil, frame)
	orn.crown:SetSize(26, 12)
	orn.crown:SetPoint("BOTTOM", frame, "TOP", 0, -4)
	orn.crown.band = Theme.Solid(orn.crown, "OVERLAY", Theme.GOLD, 1)
	orn.crown.band:SetPoint("BOTTOM", orn.crown, "BOTTOM", 0, 0)
	orn.crown.band:SetSize(22, 4)
	orn.crown.points = {}
	for index, x in ipairs({ -8, 0, 8 }) do
		local point = Theme.CreateDiamond(orn.crown, index == 2 and 9 or 7)
		point:SetPoint("BOTTOM", orn.crown, "BOTTOM", x, 2)
		point:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		orn.crown.points[index] = point
	end
	orn.crown.jewel = Theme.Solid(orn.crown, "OVERLAY", Theme.RED, 1)
	orn.crown.jewel:SetPoint("BOTTOM", orn.crown, "BOTTOM", 0, 1)
	orn.crown.jewel:SetSize(2, 2)
	for _, o in pairs(orn) do o:Hide() end
	return orn
end

function ns:EnsureCompanionFrame()
	if self.companionFrame then return self.companionFrame end
	if not (Theme and Theme.CreateDiscreet) then return nil end
	local frame = Theme.CreateDiscreet(UIParent, FRAME_W, FRAME_H)
	if not frame then return nil end
	frame:EnableMouse(true)
	if self.RestorePoint then self:RestorePoint(frame, "companionPoint", { point = "CENTER", x = 330, y = -170 }) end
	-- la position mémorisée est en unités du cadre à sa taille : on pose
	-- l'échelle avant tout recalage
	if frame.SetScale then frame:SetScale(ns.COMPANION_SIZES[self:CompanionSizeLevel()]) end

	frame.model = CreateModel(frame)
	if frame.model then
		frame.model:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
		frame.model:SetSize(FRAME_W - 8, MODEL_H)
	end
	-- repli : la boussole de l'addon, si le client n'offre pas de modèle
	frame.fallback = frame:CreateTexture(nil, "ARTWORK")
	frame.fallback:SetTexture(Theme.LOGO_SMALL)
	frame.fallback:SetSize(56, 56)
	frame.fallback:SetPoint("TOP", frame, "TOP", 0, -14)
	frame.fallback:Hide()

	frame.zzz = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.zzz:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
	frame.zzz:SetText("Zz")
	frame.zzz:SetTextColor(Theme.BLUE[1], Theme.BLUE[2], Theme.BLUE[3])
	frame.zzz:Hide()

	-- plaque du nom : le nom (F_LABEL) et l'humeur dessous, centrés sous le
	-- modèle ; le cadre et le fond gagnés restent ceux de CompanionData.lua
	frame.name = Theme.Text(frame, Theme.F_LABEL, Theme.PARCHMENT)
	frame.name:SetPoint("BOTTOM", frame, "BOTTOM", 0, 19)
	frame.name:SetWidth(FRAME_W - 8)
	frame.name:SetJustifyH("CENTER")
	if frame.name.SetWordWrap then frame.name:SetWordWrap(false) end
	frame.mood = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.mood:SetPoint("BOTTOM", frame, "BOTTOM", 0, 6)
	frame.mood:SetWidth(FRAME_W - 8)
	frame.mood:SetJustifyH("CENTER")
	if frame.mood.SetWordWrap then frame.mood:SetWordWrap(false) end

	frame.ornaments = BuildOrnaments(frame)

	-- clic = caresse, glisser = déplacer. Le clic n'est compté que si la
	-- souris n'a presque pas bougé : l'ordre OnDragStop/OnMouseUp varie.
	frame:SetScript("OnMouseDown", function(f)
		f.downX, f.downY = Call(rawget(_G, "GetCursorPosition"))
	end)
	frame:SetScript("OnMouseUp", function(f, button)
		if button and button ~= "LeftButton" and button ~= "RightButton" then return end
		local x, y = Call(rawget(_G, "GetCursorPosition"))
		if f.downX and x and (math.abs(x - f.downX) > 4 or math.abs((y or 0) - (f.downY or 0)) > 4) then return end
		-- clic droit : son carnet de voyage, ouvert sur les objectifs
		if button == "RightButton" then return ns:CompanionOpenJournal() end
		ns:CompanionPet()
	end)
	frame:SetScript("OnEnter", function() ns:CompanionShowHover() end)
	frame:SetScript("OnLeave", function() ns:CompanionHideHover() end)

	self.companionFrame = frame
	self:CompanionApplyModel()
	self:CompanionApplyOrnaments()
	return frame
end

-- Clic droit sur la créature : le carnet, sur son dernier onglet. Déjà
-- ouvert : on le ferme.
function ns:CompanionOpenJournal()
	if type(self.ToggleJournal) ~= "function" then return nil end
	local current = self.journalFrame
	if current and current:IsShown() then current:Hide(); return current end
	-- le carnet rouvre son dernier onglet (la Zone la première fois)
	return self:ToggleJournal(true)
end

-- Bulle (docs/UI.md, « Carnet et compagnon ») : brique Theme.CreateBubble,
-- au-dessus du cadre, à sa taille de lecture quelle que soit l'échelle du
-- compagnon. Pendant le tutoriel : « Passer » au trait, « Suivant » plein.
local BUBBLE_W = 220
function ns:EnsureCompanionBubble()
	if self.companionBubble then return self.companionBubble end
	local frame = self.companionFrame
	if not frame then return nil end
	local bubble = Theme.CreateBubble and Theme.CreateBubble(UIParent, BUBBLE_W, { strata = "HIGH" })
	if not bubble then return nil end
	bubble:SetPoint("BOTTOM", frame, "TOP", 0, 12)
	if Theme.CreateButton then
		local h = (Theme.DIALOG_BUTTON_HEIGHT or 28) - 6
		bubble.nextButton = Theme.CreateButton(bubble, "auto", h, L.COMP_TUTO_NEXT, function() ns:CompanionTutorialNext() end, "primary")
		bubble.nextButton:SetPoint("BOTTOMRIGHT", bubble, "BOTTOMRIGHT", -Theme.BUBBLE_PAD, Theme.BUBBLE_PAD)
		bubble.skipButton = Theme.CreateButton(bubble, "auto", h, L.COMP_TUTO_SKIP, function() ns:CompanionSkipTutorial() end, "outline")
		bubble.skipButton:SetPoint("BOTTOMLEFT", bubble, "BOTTOMLEFT", Theme.BUBBLE_PAD, Theme.BUBBLE_PAD)
		bubble.nextButton:Hide()
		bubble.skipButton:Hide()
	end
	bubble:Hide()
	self.companionBubble = bubble
	return bubble
end

-- Survol : le nom, le stade et l'humeur (et son caractère), quatre petites
-- barres de besoins, puis l'aide en gris. Tout est placé à chaque
-- rafraîchissement, de haut en bas : une ligne qui passe à la ligne (le
-- caractère, l'aide plus longue d'une langue) pousse la suite au lieu de la
-- recouvrir, et le cadre prend la hauteur de son contenu.
local HOVER_W, HOVER_PAD, HOVER_BAR_ROW = 220, 12, 18
local HOVER_LABEL_W = 70
-- texte posé de bord à bord de la fiche (après le liseré du bandeau)
local function HoverTextWidth(hover) return HOVER_W - (hover.contentLeft or HOVER_PAD) - HOVER_PAD end
local function TextHeight(fontString, font)
	local hover = fontString and fontString.GetParent and fontString:GetParent()
	return Theme.TextHeight(fontString, hover and HoverTextWidth(hover) or (HOVER_W - 2 * HOVER_PAD), font or Theme.F_SMALL)
end
ns.CompanionHoverTextHeight = TextHeight

-- Fiche au survol : bandeau du thème (liseré ambre), le nom en F_TITLE, le
-- stade et l'humeur, quatre envies en barres fines (libellé, barre, valeur),
-- un filet, puis l'aide en pâle. Tout se place de haut en bas
-- (CompanionLayoutHover) : le cadre prend la hauteur de son contenu.
function ns:EnsureCompanionHover()
	if self.companionHover then return self.companionHover end
	local frame = self.companionFrame
	if not frame then return nil end
	local hover = Theme.CreateToast(UIParent, HOVER_W, 118, { strata = "TOOLTIP" })
	if not hover then return nil end
	hover:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -8, 0)
	local left = hover.contentLeft or HOVER_PAD
	local width = HoverTextWidth(hover)
	hover.title = Theme.Text(hover, Theme.F_TITLE, Theme.PARCHMENT)
	hover.title:SetPoint("TOPLEFT", hover, "TOPLEFT", left, -HOVER_PAD)
	hover.title:SetWidth(width)
	hover.title:SetJustifyH("LEFT")
	if hover.title.SetWordWrap then hover.title:SetWordWrap(false) end
	hover.sub = Theme.Text(hover, Theme.F_SMALL, Theme.MUTED_LIGHT)
	hover.sub:SetWidth(width)
	hover.sub:SetJustifyH("LEFT")
	if hover.sub.SetWordWrap then hover.sub:SetWordWrap(true) end
	hover.bars = {}
	for _, key in ipairs(NEED_KEYS) do
		local label = Theme.Text(hover, Theme.F_SMALL, Theme.LABEL)
		label:SetJustifyH("LEFT")
		label:SetText(L["COMP_NEED_" .. key])
		local bar = Theme.CreateBar(hover, width - HOVER_LABEL_W - 36, 4)
		bar.label = label
		bar.value = Theme.Text(hover, Theme.F_SMALL, Theme.MUTED_LIGHT)
		bar.value:SetJustifyH("RIGHT")
		hover.bars[key] = bar
	end
	hover.rule = Theme.Solid(hover, "ARTWORK", Theme.EDGE_SOFT, 1)
	hover.rule:SetSize(width, 1)
	hover.hint = Theme.Text(hover, Theme.F_SMALL, Theme.MUTED)
	hover.hint:SetWidth(width)
	hover.hint:SetJustifyH("LEFT")
	if hover.hint.SetWordWrap then hover.hint:SetWordWrap(true) end
	hover.hint:SetText(L.COMP_HOVER_HINT)
	hover:Hide()
	self.companionHover = hover
	return hover
end

-- Place tout de haut en bas et donne au cadre la hauteur de son contenu
function ns:CompanionLayoutHover()
	local hover = self.companionHover
	if not hover then return nil end
	local left = hover.contentLeft or HOVER_PAD
	local y = -HOVER_PAD - 20
	hover.sub:ClearAllPoints()
	hover.sub:SetPoint("TOPLEFT", hover, "TOPLEFT", left, y)
	hover.sub.top = y
	y = y - TextHeight(hover.sub) - 10
	for _, key in ipairs(NEED_KEYS) do
		local bar = hover.bars[key]
		bar.label:ClearAllPoints()
		bar.label:SetPoint("TOPLEFT", hover, "TOPLEFT", left, y)
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", hover, "TOPLEFT", left + HOVER_LABEL_W, y - 5)
		bar.value:ClearAllPoints()
		bar.value:SetPoint("TOPRIGHT", hover, "TOPRIGHT", -HOVER_PAD, y)
		bar.top = y
		y = y - HOVER_BAR_ROW
	end
	y = y - 4
	hover.rule:ClearAllPoints()
	hover.rule:SetPoint("TOPLEFT", hover, "TOPLEFT", left, y)
	y = y - 8
	hover.hint:ClearAllPoints()
	hover.hint:SetPoint("TOPLEFT", hover, "TOPLEFT", left, y)
	hover.hint.top = y
	local height = math.ceil(-y + TextHeight(hover.hint) + HOVER_PAD)
	hover:SetHeight(height)
	hover.layoutHeight = height
	return height
end

function ns:CompanionRefreshHover()
	local hover = self.companionHover
	if not hover then return end
	local data = self:CompanionData()
	hover.title:SetText(self:CompanionName())
	hover.sub:SetText(Theme.T_GOLD .. self:CompanionStageLabel() .. "|r · " .. tostring(L["COMP_MOOD_" .. self:CompanionMood()]))
	local happyMin = HAPPY_MIN
	for _, key in ipairs(NEED_KEYS) do
		local bar = hover.bars[key]
		local value = tonumber(data.needs[key]) or 0
		bar:SetValue(value / NEED_MAX)
		-- comblée (compte pour son bonheur) : ambre ; sinon gris
		local c = value >= happyMin and Theme.GOLD or Theme.MUTED_LIGHT
		bar:SetColor(c[1], c[2], c[3], 1)
		bar.value:SetText(math.floor(value + 0.5) .. " %")
	end
	self:CompanionLayoutHover()
end

function ns:CompanionShowHover()
	local hover = self:EnsureCompanionHover()
	if not hover then return end
	self:CompanionRefreshHover()
	hover:Show()
end

function ns:CompanionHideHover()
	if self.companionHover then self.companionHover:Hide() end
end

-- Modèle : apparence, échelle du stade, animation de l'humeur. Sans
-- SetDisplayInfo (ou s'il refuse), la boussole prend la place.
function ns:CompanionApplyModel()
	local frame = self.companionFrame
	if not frame then return end
	local app = self:CompanionCurrentAppearance()
	local stageDef = ns.COMPANION_STAGES[self:CompanionStage()] or ns.COMPANION_STAGES[1]
	local model, shown = frame.model, false
	if model then
		if app.display and type(model.SetDisplayInfo) == "function" then
			shown = pcall(model.SetDisplayInfo, model, app.display)
		end
		if not shown and app.npc and type(model.SetCreature) == "function" then
			shown = pcall(model.SetCreature, model, app.npc)
		end
	end
	frame.usesFallback = not shown
	frame.displayID = shown and app.display or nil
	if shown then
		-- créature capturée : un modèle de taille réelle (un ours, un géant…),
		-- cadré de plus loin et sans l'échelle du stade, faite pour les mascottes
		Method(model, "SetModelScale", app.captured and 1 or stageDef.scale)
		Method(model, "SetCamDistanceScale", app.captured and (ns.CAPTURE_CAM_DISTANCE or 2.4) or 1.6)
		model:Show()
		frame.fallback:Hide()
	else
		if model and model.Hide then model:Hide() end
		frame.fallback:Show()
		-- la boussole grandit aussi avec le stade
		frame.fallback:SetSize(48 * stageDef.scale + 8, 48 * stageDef.scale + 8)
	end
	frame.scale = stageDef.scale
	self:CompanionAnimate()
	self:CompanionRefreshLabels()
end

-- Sans `name` : l'animation de l'humeur (sommeil ou repos)
function ns:CompanionAnimate(name, duration)
	local frame = self.companionFrame
	if not frame then return end
	local anims = ns.COMPANION_ANIMS
	if not name then
		name = self:CompanionData().sleepy and "sleep" or "idle"
		self.companionAnimUntil = nil
	elseif duration then
		self.companionAnimUntil = Clock() + duration
	end
	frame.animation = name
	if frame.usesFallback then
		-- repli : un petit fondu remplace la danse ; la boussole pâlit en dormant
		frame.fallback:SetAlpha(name == "sleep" and 0.6 or 1)
		if name ~= "idle" and name ~= "sleep" and Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	elseif frame.model then
		Method(frame.model, "SetAnimation", anims[name] or anims.idle)
	end
	if name == "sleep" then frame.zzz:Show() else frame.zzz:Hide() end
end

function ns:CompanionRefreshLabels()
	local frame = self.companionFrame
	if not frame then return end
	frame.name:SetText(self:CompanionName())
	frame.mood:SetText(tostring(L["COMP_MOOD_" .. self:CompanionMood()]))
end

function ns:CompanionApplyOrnaments()
	local frame = self.companionFrame
	if not frame then return end
	for _, def in ipairs(ns.COMPANION_ORNAMENTS) do
		local o = frame.ornaments[def.id]
		if o then
			local shown = self:CompanionOrnamentShown(def)
			if shown then o:Show() else o:Hide() end
			if def.id == "gold" and o.corner then
				for _, tex in ipairs(o.corner) do if shown then tex:Show() else tex:Hide() end end
			end
		end
	end
	-- cadre et fond suivent les ornements partout où ils sont rafraîchis
	-- (déblocage, affichage, création du cadre)
	self:CompanionApplyFrame()
	self:CompanionApplyBackground()
end

-- ---------------------------------------------------------------------------
-- Cadre (bordure) et fond
-- ---------------------------------------------------------------------------
local function SetColor(tex, color, alpha)
	if tex and color then tex:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1) end
end

-- Cadre BackdropTemplate (Era 1.15 et Forever l'ont) ; repli : cadre simple,
-- qui n'a de bordure que si le client y garde SetBackdrop
local function CreateBackdropFrame(parent)
	local ok, frame = pcall(CreateFrame, "Frame", nil, parent, "BackdropTemplate")
	if ok and frame then return frame end
	ok, frame = pcall(CreateFrame, "Frame", nil, parent)
	if ok then return frame end
	return nil
end

function ns:CompanionApplyFrame()
	local frame = self.companionFrame
	if not frame then return nil end
	local def = self:CompanionCurrentStyle("frame")
	-- filet 1 px : toujours là, c'est aussi le repli d'une bordure absente
	for _, edge in ipairs({ frame.top, frame.bottom, frame.leftEdge, frame.rightEdge }) do
		SetColor(edge, def.edge or ns.COMPANION_FRAMES[1].edge)
	end
	-- second filet, intérieur
	if def.inner then
		if not frame.styleInner then
			frame.styleInnerHolder = CreateFrame("Frame", nil, frame)
			frame.styleInnerHolder:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
			frame.styleInnerHolder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
			frame.styleInner = Theme.Border(frame.styleInnerHolder, def.inner, def.inner[4], "BORDER")
		end
		frame.styleInner:SetColor(def.inner[1], def.inner[2], def.inner[3], def.inner[4])
		frame.styleInnerHolder:Show()
	elseif frame.styleInnerHolder then
		frame.styleInnerHolder:Hide()
	end
	-- bordure du client
	local applied = false
	if def.backdrop then
		if not frame.styleBorder then
			frame.styleBorder = CreateBackdropFrame(frame)
			if frame.styleBorder then
				frame.styleBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
				frame.styleBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
				-- au niveau du cadre : les ornements (enfants, niveau + 1) restent dessus
				Method(frame.styleBorder, "EnableMouse", false)
				local okLevel, level = Method(frame, "GetFrameLevel")
				if okLevel and tonumber(level) then Method(frame.styleBorder, "SetFrameLevel", level) end
			end
		end
		local border = frame.styleBorder
		if border and type(border.SetBackdrop) == "function" then
			local b = def.backdrop
			applied = pcall(border.SetBackdrop, border, {
				edgeFile = b.file, edgeSize = b.size or 16,
				insets = { left = 0, right = 0, top = 0, bottom = 0 },
			}) and true or false
			if applied and b.color then
				Method(border, "SetBackdropBorderColor", b.color[1], b.color[2], b.color[3], b.color[4] or 1)
			end
		end
	end
	if frame.styleBorder then
		if applied then frame.styleBorder:Show() else frame.styleBorder:Hide() end
	end
	frame.frameStyle = def.id
	frame.frameBackdrop = applied
	return def
end

-- Petits points de lumière de la voûte étoilée (positions fixes : pas de
-- hasard, le fond ne « bouge » pas à chaque rechargement)
local STARS = { { 12, -10, 2 }, { 30, -22, 1 }, { 52, -8, 2 }, { 74, -18, 1 }, { 90, -6, 2 },
	{ 20, -40, 1 }, { 84, -36, 1 }, { 60, -30, 1 }, { 8, -62, 1 }, { 94, -58, 2 } }

-- Dégradé vertical : API récente (couleurs CreateColor), sinon l'ancienne
-- (SetGradientAlpha), sinon rien (l'aplat teinté reste)
local function ApplyGradient(tex, top, bottom)
	local createColor = rawget(_G, "CreateColor")
	if type(tex.SetGradient) == "function" and type(createColor) == "function" then
		local okMin, minColor = pcall(createColor, bottom[1], bottom[2], bottom[3], bottom[4] or 1)
		local okMax, maxColor = pcall(createColor, top[1], top[2], top[3], top[4] or 1)
		if okMin and okMax and pcall(tex.SetGradient, tex, "VERTICAL", minColor, maxColor) then return "color" end
	end
	if type(tex.SetGradientAlpha) == "function" then
		if pcall(tex.SetGradientAlpha, tex, "VERTICAL", bottom[1], bottom[2], bottom[3], bottom[4] or 1,
			top[1], top[2], top[3], top[4] or 1) then return "alpha" end
	end
	return nil
end

function ns:CompanionApplyBackground()
	local frame = self.companionFrame
	if not (frame and frame.bg) then return nil end
	local def = self:CompanionCurrentStyle("bg")
	local bg = frame.bg
	-- texture : refusée (erreur, ou false sur les clients qui le disent) -> aplat
	local path, fallback = def.texture or Theme.SOLID, false
	local ok, result = pcall(bg.SetTexture, bg, path)
	if not ok or result == false then
		fallback = def.texture ~= nil
		path = Theme.SOLID
		pcall(bg.SetTexture, bg, path)
	end
	-- image du jeu recadrée (écran de chargement), sinon la texture entière
	if bg.SetTexCoord then
		local c = (not fallback and def.coords) or { 0, 1, 0, 1 }
		pcall(bg.SetTexCoord, bg, c[1], c[2], c[3], c[4])
	end
	frame.bgCoords = (not fallback) and def.coords or nil
	SetColor(bg, def.color or { 0, 0, 0, 0.66 })
	local gradient = nil
	if def.gradient then gradient = ApplyGradient(bg, def.gradient.top, def.gradient.bottom) end
	-- étoiles
	if def.stars and not frame.stars then
		frame.stars = {}
		for index, s in ipairs(STARS) do
			local star = Theme.Solid(frame, "BORDER", Theme.PARCHMENT, 0.8)
			star:SetPoint("TOPLEFT", frame, "TOPLEFT", s[1], s[2])
			star:SetSize(s[3], s[3])
			frame.stars[index] = star
		end
	end
	for _, star in ipairs(frame.stars or {}) do
		if def.stars then star:Show() else star:Hide() end
	end
	frame.bgStyle = def.id
	frame.bgTexture = path
	frame.bgFallback = fallback
	frame.bgGradient = gradient
	return def
end

-- Affiche ou cache selon le module et le réglage « Afficher »
function ns:CompanionUpdateVisibility()
	local db = self:DB()
	if not ModuleOn() or db.companionShow == false then
		if self.companionFrame then self.companionFrame:Hide() end
		self:CompanionHideBubble()
		self:CompanionHideHover()
		return false
	end
	local frame = self:EnsureCompanionFrame()
	if not frame then return false end
	self:CompanionApplyOrnaments()
	self:CompanionRefreshLabels()
	frame:Show()
	return true
end

-- ---------------------------------------------------------------------------
-- Besoins : baisse douce en jeu, gains sur les bons moments
-- ---------------------------------------------------------------------------
local EAT_AURAS = {
	["food"] = true, ["food & drink"] = true, ["refreshment"] = true,
	["nourriture"] = true, ["nourriture et boisson"] = true, ["rafraîchissement"] = true,
}
-- boire seul : une autre réplique (« Glou glou ! »), le même gain
local DRINK_AURAS = { ["drink"] = true, ["boisson"] = true }
local FED_AURAS = { ["well fed"] = true, ["bien nourri"] = true, ["repu"] = true }

-- Renvoie mange-ou-boit ?, bien nourri ?, boit seulement ?
function ns:CompanionAuraState()
	local eating, fed, drinking = false, false, false
	local read = self.AuraByIndex
	if type(read) ~= "function" then return false, false, false end
	for index = 1, 40 do
		local aura = read(index)
		if not aura then break end
		local name = type(aura.name) == "string" and self.AsciiLower(aura.name) or nil
		if name and EAT_AURAS[name] then eating = true end
		if name and DRINK_AURAS[name] then drinking = true end
		if name and FED_AURAS[name] then fed = true end
	end
	return eating or drinking, fed, drinking and not eating
end

-- Repas : un gros coup de faim comblé au début, puis un peu chaque minute
function ns:CompanionCheckAuras()
	local eating, fed, drinkOnly = self:CompanionAuraState()
	if eating and not self.companionEating then
		self:CompanionAdd("hunger", 35)
		self:CompanionSay(drinkOnly and "DRINK" or "EAT", { cd = "eat" })
	end
	if fed and not self.companionFed then self:CompanionAdd("hunger", 15) end
	self.companionEating, self.companionFed = eating, fed
	local atCamp = self.AtCamp and self:AtCamp() or false
	if atCamp and not self.companionAtCamp then
		self:CompanionAdd("energy", 10)
		self:CompanionSay("CAMP")
	end
	self.companionAtCamp = atCamp
end

function ns:CompanionResting()
	if Call(rawget(_G, "IsResting")) then return true end
	return self.AtCamp and self:AtCamp() or false
end

-- `seconds` de jeu écoulées : baisse douce, sauf ce qui remonte
function ns:CompanionTick(seconds)
	if not ModuleOn() then return end
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then return end
	local data = self:CompanionData()
	local minutes = seconds / 60
	local resting = self:CompanionResting()
	-- toutes ses évolutions faites : il ne descend plus sous SERENE_FLOOR
	local floor = (tonumber(data.stage) or 1) >= #ns.COMPANION_STAGES and SERENE_FLOOR or NEED_FLOOR
	for _, key in ipairs(NEED_KEYS) do
		local delta = -DECAY[key] * minutes * (self.CompanionDecayFactor and self:CompanionDecayFactor(key) or 1)
		if key == "energy" and resting then delta = REST_GAIN * minutes end
		if key == "hunger" and self.companionEating then delta = EAT_GAIN * minutes end
		data.needs[key] = Clamp(data.needs[key] + delta, floor, NEED_MAX)
	end
	-- prêt à évoluer : le repos ou le repas a pu combler la dernière envie
	if data.stageReady and self:CompanionIsHappy() then self:CompanionCheckStage(PlayerLevel(), true) end
	-- arrivée en griffon : la fin d'un vol se voit au tick suivant
	local rt = RT()
	local onTaxi = Call(rawget(_G, "UnitOnTaxi"), "player") == true
	if rt.onTaxi and not onTaxi then self:CompanionAdd("curiosity", CURIOSITY.flight) end
	rt.onTaxi = onTaxi
	-- somnolence : il se réveille en jouant, pas en attendant
	if data.sleepy then
		data.sleepyLeft = (tonumber(data.sleepyLeft) or 0) - seconds
		if data.sleepyLeft <= 0 then self:CompanionWake(true) end
	end
	data.lastSeen = Wall()
	self:CompanionRefreshLabels()
	self:CompanionRefreshHover()
	self:CompanionChatter(seconds)
end

-- Ce qu'il dit de lui-même, du plus important au moins important. Chaque
-- source a sa pause ; l'écart global fait qu'une seule parle par relevé.
function ns:CompanionChatter(seconds)
	local rt = RT()
	if rt.tutoPending and not InCombat() then self:CompanionStartTutorial(false) end
	if InCombat() then return end
	if self:CompanionTryNeed() then return end
	if self:CompanionTryGoal() then return end
	if self:CompanionTryTip() then return end
	if self:CompanionTryIdle(seconds) then return end
	self:CompanionTryNight()
end

-- Envie : le besoin le plus bas sous le seuil, jamais en somnolant
function ns:CompanionTryNeed()
	local data = self:CompanionData()
	if data.sleepy or InCombat() then return false end
	local rt, now = RT(), Clock()
	local lowKey, lowValue
	for _, key in ipairs(NEED_KEYS) do
		local value = data.needs[key]
		local cooling = rt.cool["need_" .. key] and now < rt.cool["need_" .. key]
		if value < NEED_LOW and not cooling and (not lowValue or value < lowValue) then lowKey, lowValue = key, value end
	end
	if not lowKey then return false end
	return (self:CompanionSay("NEED_" .. lowKey, { cd = { "need", "need_" .. lowKey } }))
end

-- Astuces : rien avant TIP_GAP (+ un peu de hasard) depuis la précédente
local function TipDelay() return TIP_GAP + math.random(0, TIP_JITTER) end

-- Astuce suivante : au hasard parmi celles pas encore vues (par personnage) ;
-- toutes vues, on recommence un tour, sans redire la dernière
function ns:CompanionNextTip()
	local data = self:CompanionData()
	if type(data.tipsSeen) ~= "table" then data.tipsSeen = {} end
	local all = ns.COMPANION_POOLS.TIP or {}
	local unseen = {}
	for _, key in ipairs(all) do if not data.tipsSeen[key] then unseen[#unseen + 1] = key end end
	if #unseen == 0 then
		data.tipsSeen = {}
		for _, key in ipairs(all) do if key ~= data.lastTip then unseen[#unseen + 1] = key end end
	end
	if #unseen == 0 then return nil end
	return unseen[math.random(#unseen)]
end

function ns:CompanionTryTip(force)
	if self:CompanionChatterLevel() < 3 or InCombat() then return false end
	local rt, now = RT(), Clock()
	if not rt.tipAt then rt.tipAt = now + TipDelay() end
	if not force and now < rt.tipAt then return false end
	local key = self:CompanionNextTip()
	if not key then return false end
	if not self:CompanionSay("TIP", { line = key }) then return false end
	local data = self:CompanionData()
	data.tipsSeen[key] = true
	data.lastTip = key
	rt.tipAt = now + TipDelay()
	return true
end

-- Reste avant un déblocage, en toutes lettres (« 2 zones », « un niveau »)
function ns:CompanionLeftText(item)
	local left = math.max(1, (item.need or 0) - (item.have or 0))
	local stat = item.source == "player" and "plevel" or tostring(item.stat)
	if left == 1 then return L["COMP_LEFT_" .. stat .. "_1"] end
	return self:F("COMP_LEFT_" .. stat, left)
end

-- Objectif : un rappel quand le prochain déblocage est tout proche
local GOAL_NEAR = { player = 2, journal = 3 }
function ns:CompanionTryGoal()
	if InCombat() then return false end
	local rt, now = RT(), Clock()
	if not rt.goalAt then rt.goalAt = now + GOAL_FIRST end
	if now < rt.goalAt then return false end
	local target
	for _, item in ipairs(self:CompanionNextUnlocks()) do
		-- prêt à évoluer : ce qui manque, ce sont des envies, pas des niveaux
		-- (sa bulle READY le dit déjà)
		if not item.ready and item.need - item.have <= (GOAL_NEAR[item.source] or 3) then target = item; break end
	end
	if not target then
		rt.goalAt = now + 300      -- rien de proche : on regardera plus tard
		return false
	end
	local pool = target.kind == "stage" and "GOAL_STAGE" or "GOAL"
	if not self:CompanionSay(pool, { args = { self:CompanionLeftText(target), target.label }, cd = "goal" }) then
		return false
	end
	rt.goalAt = now + COOLDOWNS.goal
	return true
end

-- Bavardage au repos : après IDLE_REST s de repos ininterrompu
function ns:CompanionTryIdle(seconds)
	local rt = RT()
	if not Call(rawget(_G, "IsResting")) then rt.restIdle = 0; return false end
	rt.restIdle = (rt.restIdle or 0) + (tonumber(seconds) or 0)
	if rt.restIdle < IDLE_REST then return false end
	if not self:CompanionSay("IDLE", { cd = "idle" }) then return false end
	rt.restIdle = 0
	return true
end

-- Nuit : l'heure du serveur (GetGameTime, présent sur les deux clients).
-- Pas de pluie : aucune API fiable ne dit la météo.
function ns:CompanionTryNight()
	local hour = tonumber((Call(rawget(_G, "GetGameTime"))))
	if not hour or (hour < 22 and hour >= 5) then return false end
	return (self:CompanionSay("NIGHT", { cd = "night" }))
end

function ns:CompanionWake(say)
	local data = self:CompanionData()
	if not data.sleepy then return false end
	data.sleepy, data.sleepyLeft = nil, nil
	self:CompanionAnimate()
	self:CompanionRefreshLabels()
	if say then self:CompanionSay("AWAKE", { force = true }) end
	return true
end

-- Connexion : une absence le rend somnolent, sans rien retirer à ses besoins
function ns:CompanionLogin()
	local data = self:CompanionData()
	local rt, clock = RT(), Clock()
	local now = Wall()
	local first = data.lastSeen == nil
	local away = first and 0 or math.max(0, now - (tonumber(data.lastSeen) or now))
	data.lastSeen = now
	-- zone de connexion : connue d'emblée, pas de « Quelle vue ! » au chargement
	local mapID = self.CurrentMap and self:CurrentMap()
	if mapID then
		data.seenZones[mapID] = true
		-- et sa date de visite : y revenir plus tard n'est pas un « retour après 2 h » d'office
		if type(data.zoneVisit) ~= "table" then data.zoneVisit = {} end
		data.zoneVisit[mapID] = data.zoneVisit[mapID] or tonumber((Call(rawget(_G, "time")))) or 0
	end
	self:CompanionCheckPlace(true)
	self:CompanionCheckStage(PlayerLevel(), not first)
	self:CompanionCheckUnlocks(nil, first)
	self.companionLastBubble = nil
	-- un temps de répit après la connexion : pas d'envie ni de « bonne
	-- nuit » dès l'écran de chargement
	rt.cool.need = math.max(rt.cool.need or 0, clock + NEED_GRACE)
	rt.cool.night = math.max(rt.cool.night or 0, clock + NIGHT_GRACE)
	if away >= SLEEPY_AFTER then
		data.sleepy = true
		data.sleepyLeft = Clamp(math.floor(away / 3600 * SLEEPY_PER_HOUR), SLEEPY_MIN, SLEEPY_MAX)
		self:CompanionAnimate()
	end
	-- première apparition : le tutoriel tient lieu de bonjour
	if not data.tutoDone then
		self:CompanionStartTutorial(false)
	elseif first then
		self:CompanionSay("HELLO", { force = true, args = { self:CompanionName() } })
	elseif data.sleepy then
		self:CompanionSay("MISSED", { force = true })
	end
	self:CompanionRefreshLabels()
	return away
end

-- Caresse : un peu de moral, puis une petite conversation (2 ou 3 bulles).
-- Pendant le tutoriel, le clic passe à l'étape suivante.
function ns:CompanionPet()
	if not ModuleOn() then return false end
	if self:CompanionTutorialActive() then return self:CompanionTutorialNext() end
	local now = Clock()
	if self.companionLastPet and now - self.companionLastPet < PET_COOLDOWN then return false end
	self.companionLastPet = now
	-- le joueur reprend la main : la conversation précédente s'arrête
	local rt = RT()
	if rt.seq and rt.seq.kind == "convo" then rt.seq = nil end
	local wasSleepy = self:CompanionData().sleepy
	self:CompanionWake(false)
	self:CompanionAdd("mood", 8)
	self:CompanionAnimate("cheer", 2)
	-- réveillé en sursaut : une seule bulle, pas de bavardage
	if wasSleepy then
		self:CompanionSay("PET_sleepy", { force = true })
	else
		self:CompanionStartConvo()
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Réactions
-- ---------------------------------------------------------------------------
function ns:CompanionFoodInBags()
	local kindOf = self.ConsumableKind
	if type(kindOf) ~= "function" or not C_Container then return 0 end
	local count = 0
	for bag = 0, 4 do
		local slots = tonumber((Call(C_Container.GetContainerNumSlots, bag))) or 0
		for slot = 1, slots do
			local info = Call(C_Container.GetContainerItemInfo, bag, slot)
			if type(info) == "table" and info.itemID and kindOf(info.itemID) == "food" then
				count = count + (info.stackCount or 1)
			end
		end
	end
	return count
end

local LINK_COLORS = { ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }
local function LinkQuality(link)
	local _, _, quality = ns.ItemInfo(link)
	if type(quality) == "number" then return quality end
	local iq = link:match("|cnIQ(%d+):")
	if iq then return tonumber(iq) end
	local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
	return hex and LINK_COLORS[hex:lower()] or 0
end

function ns:CompanionOnLoot(message)
	if type(self.ParseSelfLoot) ~= "function" then return end
	local link = self:ParseSelfLoot(message)
	if link and LinkQuality(link) >= 3 then   -- rare ou mieux : un vrai moment
		self:CompanionAdd("mood", 10)
		self:CompanionSay("LOOT", { cd = "loot" })
	end
end

-- Capitale ou village connu (Hubs.lua via ns:KnownHub) : un mot en entrant,
-- pas à chaque sous-zone, ni deux fois de suite pour le même lieu
function ns:CompanionCheckPlace(silent)
	if type(self.KnownHub) ~= "function" then return false end
	local ok, entry, name = pcall(self.KnownHub, self)
	local rt = RT()
	if not ok or not entry or not name then rt.lastHub = nil; return false end
	-- vallée de départ : on y passe d'une sous-zone à l'autre sans cesse
	if entry.kind == "start" then return false end
	local now = Clock()
	-- toujours sur place : on retient l'heure, pour ne pas le refêter s'il
	-- ressort une minute (une sous-zone voisine) puis revient
	if rt.lastHub == name then rt.hubSeen[name] = now; return false end
	rt.lastHub = name
	local seen = rt.hubSeen[name]
	rt.hubSeen[name] = now
	if silent or (seen and now - seen < SAME_HUB) then return false end
	return (self:CompanionSay(entry.kind == "capital" and "CITY" or "VILLAGE", { args = { name }, cd = "place" }))
end

local function RealTime() return tonumber((Call(rawget(_G, "time")))) or 0 end

function ns:CompanionOnZone(newArea)
	local data = self:CompanionData()
	local mapID = self.CurrentMap and self:CurrentMap()
	local rt, now = RT(), Clock()
	if type(data.zoneVisit) ~= "table" then data.zoneVisit = {} end
	if newArea then
		if mapID and not data.seenZones[mapID] then
			data.seenZones[mapID] = true
			self:CompanionAdd("curiosity", CURIOSITY.newZone)
			self:CompanionSay("VIEW")
		elseif mapID and RealTime() - (tonumber(data.zoneVisit[mapID]) or 0) >= CURIOSITY.revisitAfter then
			-- de retour dans une zone pas vue depuis un moment
			self:CompanionAdd("curiosity", CURIOSITY.revisit)
		end
		if mapID then data.zoneVisit[mapID] = RealTime() end
		-- chaque entrée en donjon (pas les allers-retours de la porte)
		if self.InInstance and self:InInstance() and (not rt.lastDungeon or now - rt.lastDungeon >= CURIOSITY.dungeonGap) then
			rt.lastDungeon = now
			self:CompanionAdd("curiosity", CURIOSITY.dungeon)
		end
		self:CompanionCheckPlace()
		return
	end
	local sub = self.CurrentSubZone and self:CurrentSubZone()
	if mapID and sub then
		local key = tostring(mapID) .. ":" .. sub
		if not data.seenSub[key] then
			data.seenSub[key] = true
			self:CompanionAdd("curiosity", CURIOSITY.newSub)   -- sans bulle : il y en aurait trop
		elseif sub ~= rt.lastSub and (not rt.lastSubGain or now - rt.lastSubGain >= CURIOSITY.subzoneGap) then
			-- bouger, tout simplement
			rt.lastSubGain = now
			self:CompanionAdd("curiosity", CURIOSITY.subzone)
		end
		rt.lastSub = sub
	end
	self:CompanionCheckPlace()
end

-- Élite ou rare vaincu (la cible, morte au moment du coup fatal)
local ELITE_CLASSES = { elite = true, rareelite = true, rare = true, worldboss = true }
function ns:CompanionEliteKilled()
	if not Call(rawget(_G, "UnitIsDead"), "target") then return false end
	if not ELITE_CLASSES[Call(rawget(_G, "UnitClassification"), "target") or ""] then return false end
	self:CompanionAdd("curiosity", CURIOSITY.elite)
	return true
end

function ns:CompanionOnLevel(level)
	level = tonumber(level) or PlayerLevel()
	self:CompanionAdd("mood", 25)
	self:CompanionWake(false)
	local evolved = self:CompanionCheckStage(level, true)
	-- l'évolution garde sa bulle ; un déblocage du même niveau passe au chat
	local fresh = self:CompanionCheckUnlocks(level, false, evolved)
	if not evolved and #fresh == 0 then self:CompanionSay("LEVEL", { args = { level } }) end
end

function ns:CompanionOnStamp(stamp)
	if type(stamp) ~= "table" or stamp.new == false then return end
	self:CompanionAdd("curiosity", stamp.kind == "rare" and 15 or 10)
	local fresh = self:CompanionCheckUnlocks()
	-- la bulle du déblocage a priorité sur celle du tampon
	if #fresh == 0 then self:CompanionSay("STAMP", { args = { tostring(stamp.name or "?") } }) end
end

-- Monstre tué par le joueur : PARTY_KILL du journal de combat, ou message
-- d'XP d'un monstre. Les deux arrivent pour la même mort : un seul compte.
function ns:CompanionOnKill()
	local rt, now = RT(), Clock()
	if rt.lastKill and now - rt.lastKill < 2 then return false end
	rt.lastKill = now
	self:CompanionAdd("mood", 1)
	self:CompanionEliteKilled()
	return (self:CompanionSay("KILL", { cd = "kill" }))
end

function ns:CompanionOnCombatLog(...)
	local subevent, sourceGUID
	local fn = rawget(_G, "CombatLogGetCurrentEventInfo")
	if type(fn) == "function" then
		local ok, _, sub, _, source = pcall(fn)
		if not ok then return end
		subevent, sourceGUID = sub, source
	else
		local _, sub, _, source = ...      -- très anciens clients : charge utile passée à l'événement
		subevent, sourceGUID = sub, source
	end
	-- filtre bon marché d'abord : cet événement tombe des dizaines de fois par seconde
	if subevent ~= "PARTY_KILL" or not sourceGUID then return end
	if sourceGUID ~= Call(rawget(_G, "UnitGUID"), "player") then return end
	self:CompanionOnKill()
end

function ns:CompanionOnCombatXP(message)
	if type(message) ~= "string" then return end
	local named
	if type(self.ParseCombatXP) == "function" then
		local ok, xp, isNamed = pcall(self.ParseCombatXP, self, message)
		named = ok and xp ~= nil and isNamed == true
	else
		named = message:find(" dies", 1, true) ~= nil or message:find(" meurt", 1, true) ~= nil
	end
	if named then self:CompanionOnKill() end
end

-- Mort, puis retour : PLAYER_ALIVE tombe aussi en libérant l'esprit (fantôme) ;
-- seul compte le vrai retour à la vie
function ns:CompanionOnDead()
	RT().dead = true
	return (self:CompanionSay("DEAD"))
end

function ns:CompanionOnAlive()
	local rt = RT()
	if not rt.dead then return false end
	if Call(rawget(_G, "UnitIsDeadOrGhost"), "player") then return false end
	rt.dead = nil
	return (self:CompanionSay("REZ"))
end

-- ---------------------------------------------------------------------------
-- Avis sur les PNJ
-- ---------------------------------------------------------------------------
-- UnitCreatureType est traduit par le client : on reconnaît les deux langues
local CREATURE_TYPES = {
	["humanoid"] = "humanoid", ["humanoïde"] = "humanoid",
	["undead"] = "undead", ["mort-vivant"] = "undead",
	["beast"] = "beast", ["bête"] = "beast",
	["demon"] = "demon", ["démon"] = "demon",
	["dragonkin"] = "dragonkin", ["draconien"] = "dragonkin", ["dragon"] = "dragonkin",
	["elemental"] = "elemental", ["élémentaire"] = "elemental", ["Élémentaire"] = "elemental",
	["mechanical"] = "mechanical", ["machine"] = "mechanical", ["mécanique"] = "mechanical",
	["giant"] = "giant", ["géant"] = "giant",
	["critter"] = "critter", ["bestiole"] = "critter",
}
ns.COMPANION_CREATURE_TYPES = CREATURE_TYPES

function ns:CompanionCreatureType(unit)
	local text = Call(rawget(_G, "UnitCreatureType"), unit or "npc")
	if type(text) ~= "string" or text == "" then return nil end
	return CREATURE_TYPES[self.AsciiLower(text)] or CREATURE_TYPES[text]
end

-- Le bavardage d'un aubergiste propose « faire de cette auberge votre
-- foyer » : l'option porte le type « binder » (anciennes et nouvelles API)
local function GossipKind()
	local info = rawget(_G, "C_GossipInfo")
	if type(info) == "table" then
		local options = Call(info.GetOptions)
		if type(options) == "table" then
			for _, option in ipairs(options) do
				-- l'API récente n'a plus de champ « type » : l'icône du foyer (fichier 132052) le dit
				if type(option) == "table" and (option.type == "binder" or option.icon == 132052) then return "innkeeper" end
			end
		end
		local quests = (tonumber((Call(info.GetNumAvailableQuests))) or 0) + (tonumber((Call(info.GetNumActiveQuests))) or 0)
		if quests > 0 then return "quest" end
	end
	local legacy = rawget(_G, "GetGossipOptions")
	if type(legacy) == "function" then
		local list = { pcall(legacy) }
		if list[1] then
			for i = 3, #list, 2 do if list[i] == "binder" then return "innkeeper" end end
		end
	end
	local avail = tonumber((Call(rawget(_G, "GetNumGossipAvailableQuests")))) or 0
	local active = tonumber((Call(rawget(_G, "GetNumGossipActiveQuests")))) or 0
	if avail + active > 0 then return "quest" end
	return "talk"
end
ns.CompanionGossipKind = GossipKind

-- `kind` : merchant, innkeeper, trainer, flight, banker, quest, talk.
-- Un PNJ non humanoïde est parfois jugé sur sa nature (« sent le caveau »).
function ns:CompanionOnNpc(kind)
	local rt, now = RT(), Clock()
	-- bavardage puis fenêtre du vendeur : le même PNJ n'a qu'un avis
	local guid = Call(rawget(_G, "UnitGUID"), "npc")
	if guid and rt.npcGUID == guid and rt.npcAt and now - rt.npcAt < SAME_NPC then return false end
	local name = Call(rawget(_G, "UnitName"), "npc")
	if type(name) ~= "string" or name == "" then name = nil end
	local pool = "NPC_" .. tostring(kind)
	local creature = self:CompanionCreatureType("npc")
	local chance = tonumber(ns.COMPANION_RULES.npcCreatureChance) or 0
	if creature and creature ~= "humanoid" and ns.COMPANION_POOLS["NPC_CT_" .. creature] and math.random() < chance then
		pool = "NPC_CT_" .. creature
	end
	if not ns.COMPANION_POOLS[pool] then pool = "NPC_talk" end
	local ok = self:CompanionSay(pool, { args = name and { name } or nil, cd = "npc" })
	if ok then rt.npcGUID, rt.npcAt = guid, now end
	return ok
end

-- ---------------------------------------------------------------------------
-- Prochains déblocages (contrat avec le suivi d'objectifs du Carnet)
-- ---------------------------------------------------------------------------
-- Renvoie la liste des cosmétiques encore verrouillés et du prochain stade,
-- le plus proche d'abord :
--   { label = "<nom traduit>", kind = "app" | "orn" | "stage",
--     stat = "zone" | "subzone" | "dungeon" | "rare" | "level" | "total",
--     have = n, need = n,
--     -- en plus du contrat : d'où vient le compteur, et l'identifiant
--     source = "journal" (tampons du carnet) | "player" (niveau du joueur),
--     id = <id du cosmétique, ou numéro du stade> }
-- stat = "level" avec source = "player" : niveau du JOUEUR (stades, chouette,
-- cadre doré…) ; avec source = "journal" : tampons de palier du carnet.
-- Ordre : part restante (1 - have/need) croissante, puis reste absolu, puis
-- stade avant apparence avant ornement, puis libellé. Un objectif déjà
-- atteint (débloqué au prochain relevé) n'y figure pas. Lecture seule.
local KIND_ORDER = { stage = 1, app = 2, orn = 3 }
function ns:CompanionNextUnlocks()
	local data = self:CompanionData()
	local counts = self:CompanionCounts()
	local level = PlayerLevel()
	local list = {}
	local function Add(kind, def)
		local unlock = def.unlock
		-- un cosmétique à palier se gagne au coffre d'une zone finie, pas au compteur
		if (tonumber(def.tier) or 0) >= 1 then return end
		if not unlock or data.unlocked[CosmeticKey(kind, def.id)] then return end
		-- gagnés ailleurs (auberge, missions, brillantes) : pas d'objectif au compteur
		if not (unlock.level or unlock.stamp) then return end
		local item = { label = L[def.label], kind = kind, id = def.id }
		if unlock.level then
			item.stat, item.have, item.need, item.source = "level", level, unlock.level, "player"
		else
			item.stat, item.have, item.need, item.source = tostring(unlock.stamp), counts[unlock.stamp] or 0, unlock.count or 1, "journal"
		end
		if item.have < item.need then list[#list + 1] = item end
	end
	for _, def in ipairs(ns.COMPANION_APPEARANCES) do Add("app", def) end
	for _, def in ipairs(ns.COMPANION_ORNAMENTS) do Add("orn", def) end
	local stage = data.stage or self:CompanionStageFor(level)
	local nextStage = ns.COMPANION_STAGES[stage + 1]
	if data.stageReady and ns.COMPANION_STAGES[data.stageReady] then
		local happy, total = self:CompanionHappyCount()
		list[#list + 1] = { label = L[ns.COMPANION_STAGES[data.stageReady].label], kind = "stage", id = data.stageReady,
			stat = "happy", have = math.min(happy, total - 1), need = total, source = "player", ready = true }
	elseif nextStage and level < nextStage.level then
		list[#list + 1] = { label = L[nextStage.label], kind = "stage", id = stage + 1, stat = "level",
			have = level, need = nextStage.level, source = "player" }
	end
	table.sort(list, function(a, b)
		local ra, rb = (a.need - a.have) / a.need, (b.need - b.have) / b.need
		if ra ~= rb then return ra < rb end
		if a.need - a.have ~= b.need - b.have then return a.need - a.have < b.need - b.have end
		if a.kind ~= b.kind then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
		return tostring(a.label) < tostring(b.label)
	end)
	return list
end

ns:RegisterCallback("DEPARTURE", function(self)
	if not ModuleOn() then return end
	if self:CompanionFoodInBags() > 0 then
		self:CompanionAdd("hunger", 10)
		self:CompanionSay("DEPART")
	else
		self:CompanionSay("NOFOOD")
	end
end)
ns:RegisterCallback("RETURN", function(self)
	if not ModuleOn() then return end
	self:CompanionAdd("energy", 5)
	self:CompanionSay("RETURN")
end)
ns:RegisterCallback("STAMP", function(self, stamp)
	if not ModuleOn() then return end
	self:CompanionOnStamp(stamp)
end)

-- ---------------------------------------------------------------------------
-- Réglages : apparence, verrous, visibilité
-- ---------------------------------------------------------------------------
if type(ns.RunOptionAction) == "function" then
	local baseAction = ns.RunOptionAction
	function ns:RunOptionAction(key, ...)
		if key == "companionAppearance" then return self:CompanionCycleAppearance() end
		if key == "companionFrameStyle" then return self:CompanionCycleStyle("frame") end
		if key == "companionBackground" then return self:CompanionCycleStyle("bg") end
		if key == "companionTutorial" then return self:CompanionStartTutorial(true) end
		return baseAction(self, key, ...)
	end
end
if type(ns.ApplyDisplayOptions) == "function" then
	local baseApply = ns.ApplyDisplayOptions
	function ns:ApplyDisplayOptions(...)
		baseApply(self, ...)
		local ok, err = pcall(self.CompanionUpdateVisibility, self)
		if not ok and self.RecordError then self:RecordError("companion:display", err) end
	end
end

-- Ce qui manque pour un cosmétique verrouillé : sa condition (« 10 zones »)
-- s'il en a une, sinon son palier de coffre (« Palier 2 »)
function ns:CompanionLockText(def)
	if def.unlock and not Tiered(def) then return self:CompanionRequirement(def.unlock) end
	return self:F("COMP_TIER", tostring(def.tier or "?"))
end

-- Choix des listes déroulantes (apparence, cadre, fond) : ce qui est gagné
-- d'abord, puis le reste, grisé, avec sa condition
local CHOICE_LISTS = {
	app = function() return ns:CompanionAllAppearances() end,
	frame = function() return ns.COMPANION_FRAMES end,
	bg = function() return ns.COMPANION_BACKGROUNDS end,
}
function ns:CompanionChoices(kind)
	local open, locked = {}, {}
	for _, def in ipairs(CHOICE_LISTS[kind]() or {}) do
		if self:CompanionIsUnlocked(kind, def) then
			open[#open + 1] = { value = def.id, label = L[def.label] }
		else
			locked[#locked + 1] = { value = def.id, label = L[def.label], disabled = true, hint = self:CompanionLockText(def) }
		end
	end
	for _, entry in ipairs(locked) do open[#open + 1] = entry end
	return open
end

-- Infobulle de la réglette : le cran choisi en tête, puis les cinq
function ns:CompanionChatterTooltip()
	local current = self:CompanionChatterLevel()
	local lines = { L.COMP_CHATTER_TIP }
	for level = 0, 4 do
		local text = L["COMP_CHATTER_DESC_" .. level]
		lines[#lines + 1] = (level == current) and (Theme.T_GOLD .. "> " .. text .. "|r") or ("   " .. text)
	end
	lines[#lines + 1] = Theme.T_GREY .. L.COMP_CHATTER_TIP_HINT .. "|r"
	return lines
end

-- Nouveau cran : il le confirme lui-même (sauf muet : la bulle s'en va)
function ns:CompanionOnChatterChanged(level)
	level = self:CompanionChatterLevel()
	if level == 0 then
		self:CompanionHideBubble()
		return false
	end
	return (self:CompanionSay("CHATTER_" .. level, { force = true, category = "tuto" }))
end

-- Ornements pas encore gagnés : la carte montre un verrou (sa condition ou
-- son palier) à la place de l'interrupteur
function ns:CompanionRefreshPage()
	local frame = self.optionsFrame
	if not (frame and frame.rows) then return end
	self:CompanionChatterLevel()   -- cran déduit des anciens réglages avant le premier affichage
	local ornaments = {}
	for _, def in ipairs(ns.COMPANION_ORNAMENTS) do ornaments[def.key] = def end
	for _, row in ipairs(frame.rows) do
		local def = row.def and ornaments[row.def.key]
		if def and row.SetLocked then
			if self:CompanionIsUnlocked("orn", def) then
				row:SetLocked(nil)
			else
				row:SetLocked(self:CompanionLockText(def))
			end
		end
	end
end

-- Portrait : le compagnon dans son cadre et sur son fond gagnés (mêmes
-- styles que le vrai cadre : filet, second filet, bordure du client, fond,
-- dégradé). Carré de `size` px ; box:Refresh(addon) le met à jour. Sert à
-- l'aperçu des réglages et à la page Créature du carnet.
-- zoom : < 1 rapproche la caméra (le grand portrait du carnet : 0.65)
ns.PORTRAIT_CAM_DISTANCE = 1.6
function ns:CompanionPortrait(parent, size, zoom)
	size = size or 76
	local box = CreateFrame("Frame", nil, parent)
	box:SetSize(size, size)
	box.camScale = ns.PORTRAIT_CAM_DISTANCE * (tonumber(zoom) or 1)
	box.bg = box:CreateTexture(nil, "BACKGROUND")
	box.bg:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
	box.bg:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
	box.edge = Theme.Border(box, Theme.GOLD_SOFT, 1, "BORDER")
	box.innerHolder = CreateFrame("Frame", nil, box)
	box.innerHolder:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
	box.innerHolder:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
	box.inner = Theme.Border(box.innerHolder, Theme.GOLD_SOFT, 1, "BORDER")
	box.border = CreateBackdropFrame(box)
	if box.border then
		box.border:SetPoint("TOPLEFT", box, "TOPLEFT", -4, 4)
		box.border:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 4, -4)
	end
	box.model = CreateModel(box)
	if box.model then
		box.model:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
		box.model:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
	end
	box.fallback = box:CreateTexture(nil, "ARTWORK")
	box.fallback:SetTexture(Theme.LOGO_SMALL)
	box.fallback:SetSize(math.floor(size * 0.58), math.floor(size * 0.58))
	box.fallback:SetPoint("CENTER", box, "CENTER", 0, 0)

	function box:Refresh(addon)
		local app = addon:CompanionCurrentAppearance()
		local frameDef, bgDef = addon:CompanionCurrentStyle("frame"), addon:CompanionCurrentStyle("bg")
		-- fond : texture recadrée, teinte, dégradé (comme CompanionApplyBackground)
		local ok, result = pcall(self.bg.SetTexture, self.bg, bgDef.texture or Theme.SOLID)
		if not ok or result == false then pcall(self.bg.SetTexture, self.bg, Theme.SOLID) end
		if self.bg.SetTexCoord then
			local c = bgDef.coords or { 0, 1, 0, 1 }
			pcall(self.bg.SetTexCoord, self.bg, c[1], c[2], c[3], c[4])
		end
		SetColor(self.bg, bgDef.color or { 0, 0, 0, 0.66 })
		if bgDef.gradient then ApplyGradient(self.bg, bgDef.gradient.top, bgDef.gradient.bottom) end
		-- cadre : filet, second filet, bordure du client
		local e = frameDef.edge or ns.COMPANION_FRAMES[1].edge
		self.edge:SetColor(e[1], e[2], e[3], e[4] or 1)
		if frameDef.inner then
			self.inner:SetColor(frameDef.inner[1], frameDef.inner[2], frameDef.inner[3], frameDef.inner[4] or 1)
			self.innerHolder:Show()
		else
			self.innerHolder:Hide()
		end
		local applied = false
		if self.border and frameDef.backdrop and type(self.border.SetBackdrop) == "function" then
			local d = frameDef.backdrop
			applied = pcall(self.border.SetBackdrop, self.border, { edgeFile = d.file, edgeSize = d.size or 16,
				insets = { left = 0, right = 0, top = 0, bottom = 0 } }) and true or false
			if applied and d.color then Method(self.border, "SetBackdropBorderColor", d.color[1], d.color[2], d.color[3], d.color[4] or 1) end
		end
		if self.border then if applied then self.border:Show() else self.border:Hide() end end
		-- la créature : son modèle, sinon la boussole
		local shown = false
		if self.model then
			if app.display and type(self.model.SetDisplayInfo) == "function" then shown = pcall(self.model.SetDisplayInfo, self.model, app.display) end
			if not shown and app.npc and type(self.model.SetCreature) == "function" then shown = pcall(self.model.SetCreature, self.model, app.npc) end
			if shown then
				Method(self.model, "SetCamDistanceScale", self.camScale)
				self.model:Show()
			else
				self.model:Hide()
			end
		end
		if shown then self.fallback:Hide() else self.fallback:Show() end
		self.usesFallback = not shown
		return app, frameDef, bgDef
	end
	return box
end

-- Aperçu des réglages : le portrait, son nom, son apparence et son stade,
-- son cadre et son fond
function ns:CompanionPreview(container)
	local SIZE = 76
	local box = self:CompanionPortrait(container, SIZE)
	box:SetPoint("LEFT", container, "LEFT", 14, 0)
	container.box = box

	container.name = Theme.Text(container, Theme.F_TITLE, Theme.PARCHMENT)
	container.name:SetPoint("TOPLEFT", container, "TOPLEFT", SIZE + 34, -20)
	container.line = Theme.Text(container, Theme.F_BODY, Theme.MUTED_LIGHT)
	container.line:SetPoint("TOPLEFT", container.name, "BOTTOMLEFT", 0, -6)
	container.style = Theme.Text(container, Theme.F_SMALL, Theme.MUTED)
	container.style:SetPoint("TOPLEFT", container.line, "BOTTOMLEFT", 0, -6)

	function container:Refresh(addon)
		local app, frameDef, bgDef = self.box:Refresh(addon)
		self.name:SetText(addon:CompanionName())
		self.line:SetText(addon:F("COMP_PREVIEW_LINE", tostring(L[app.label]), tostring(addon:CompanionStageLabel())))
		self.style:SetText(addon:F("COMP_PREVIEW_LINE", addon:F("OPT_COMP_FRAME", tostring(L[frameDef.label])),
			addon:F("OPT_COMP_BG", tostring(L[bgDef.label]))))
	end
	container:Refresh(self)
	return container
end

if type(ns.RefreshOptions) == "function" then
	local baseRefresh = ns.RefreshOptions
	function ns:RefreshOptions(...)
		baseRefresh(self, ...)
		local ok, err = pcall(self.CompanionRefreshPage, self)
		if not ok and self.RecordError then self:RecordError("companion:options", err) end
		-- « /qc module compagnon off » passe par ici : le cadre suit
		ok, err = pcall(self.CompanionUpdateVisibility, self)
		if not ok and self.RecordError then self:RecordError("companion:display", err) end
	end
end

-- ---------------------------------------------------------------------------
-- Commande : /qc compagnon [nom <nom> | caresse | apparence | muet | tuto [passer]]
-- ---------------------------------------------------------------------------
function ns:CompanionStatusLine()
	local data = self:CompanionData()
	local apps, orns = 0, 0
	for _, def in ipairs(ns.COMPANION_APPEARANCES) do if self:CompanionIsUnlocked("app", def) then apps = apps + 1 end end
	for _, def in ipairs(ns.COMPANION_ORNAMENTS) do if self:CompanionIsUnlocked("orn", def) then orns = orns + 1 end end
	local n = data.needs
	return self:F("COMP_MSG_STATUS", self:CompanionName(), L[self:CompanionCurrentAppearance().label],
			self:CompanionStageLabel(), L["COMP_MOOD_" .. self:CompanionMood()]),
		self:F("COMP_MSG_NEEDS", math.floor(n.hunger + 0.5), math.floor(n.energy + 0.5), math.floor(n.mood + 0.5), math.floor(n.curiosity + 0.5)),
		self:F("COMP_MSG_COLLECTION", apps, #ns.COMPANION_APPEARANCES, orns, #ns.COMPANION_ORNAMENTS)
end

-- Ligne « Prochain : Lanterne (12/25) » du statut, nil si tout est gagné
function ns:CompanionNextLine()
	local item = self:CompanionNextUnlocks()[1]
	if not item then return nil end
	return self:F("COMP_MSG_NEXT", item.label, item.have, item.need)
end

-- Nom : pas de code de couleur ni de lien (« | »), espaces repliés, 24 car.
function ns:CompanionSanitizeName(text)
	if type(text) ~= "string" then return nil end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	if text == "" then return nil end
	if #text > NAME_MAX then
		text = text:sub(1, NAME_MAX)
		-- ne pas couper un caractère UTF-8 en deux : on remonte à l'octet de
		-- tête du dernier caractère, qu'on retire seulement s'il est incomplet
		local lead = #text
		while lead > 1 and text:byte(lead) >= 0x80 and text:byte(lead) < 0xC0 do lead = lead - 1 end
		local byte = text:byte(lead) or 0
		local size = (byte >= 0xF0 and 4) or (byte >= 0xE0 and 3) or (byte >= 0xC0 and 2) or 1
		if lead + size - 1 > #text then text = text:sub(1, lead - 1) end
	end
	return text
end

function ns:CompanionCommand(rest)
	if not ModuleOn() then return self:Print(L.COMP_MSG_OFF) end
	local sub, arg = tostring(rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
	sub = (sub or ""):lower()
	if sub == "nom" or sub == "name" then
		local name = self:CompanionSanitizeName(arg)
		if not name then return self:Print(L.COMP_MSG_NAME_BAD) end
		self:CompanionData().name = name
		self:CompanionRefreshLabels()
		self:CompanionRefreshHover()
		return self:Print(self:F("COMP_MSG_RENAMED", name))
	elseif sub == "caresse" or sub == "pet" then
		self:CompanionUpdateVisibility()
		self:CompanionPet()
		return
	elseif sub == "apparence" or sub == "look" then
		local def = self:CompanionCycleAppearance()
		return self:Print(self:F("COMP_MSG_APPEARANCE", L[def.label]))
	elseif sub == "muet" or sub == "mute" then
		-- sourdine : réglette à 0, en retenant le cran d'avant pour y revenir
		local db = self:DB()
		local level = self:CompanionChatterLevel()
		if level > 0 then
			db.companionChatterBefore = level
			db.companionChatter = 0
			self:CompanionHideBubble()
		else
			db.companionChatter = tonumber(db.companionChatterBefore) or ns.COMPANION_CHATTER_DEFAULT
		end
		if self.RefreshOptions then self:RefreshOptions() end
		return self:Print(self:F("COMP_MSG_MUTE", db.companionChatter > 0 and L.MODULE_ON or L.MODULE_OFF))
	elseif sub == "tuto" or sub == "tutorial" or sub == "tutoriel" then
		local what = (arg or ""):lower()
		if what == "passer" or what == "skip" or what == "stop" then return self:CompanionSkipTutorial() end
		self:CompanionUpdateVisibility()
		return self:CompanionStartTutorial(true)
	end
	self:CompanionCheckUnlocks()
	local line1, line2, line3 = self:CompanionStatusLine()
	self:Print(line1)
	print("   " .. line2)
	print("   " .. line3)
	local nextLine = self:CompanionNextLine()
	if nextLine then print("   " .. nextLine) end
	if self.companionFrame and self.companionFrame.usesFallback then print("   " .. L.COMP_MSG_FALLBACK) end
end

ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["compagnon"] = function(self, rest) self:CompanionCommand(rest) end
ns.EXTRA_COMMANDS["companion"] = ns.EXTRA_COMMANDS["compagnon"]

-- ---------------------------------------------------------------------------
-- Événements propres au module
-- ---------------------------------------------------------------------------
local HANDLERS = {
	PLAYER_ENTERING_WORLD = function(isLogin, isReload)
		-- un seul relevé d'absence par session (pas à chaque écran de chargement)
		if not ns.companionSession then
			ns.companionSession = true
			ns:CompanionUpdateVisibility()
			ns:CompanionLogin()
		else
			ns:CompanionOnZone(true)
		end
		ns:CompanionCheckAuras()
	end,
	PLAYER_LOGOUT          = function() ns:CompanionData().lastSeen = Wall() end,
	PLAYER_LEVEL_UP        = function(level) ns:CompanionOnLevel(level) end,
	PLAYER_DEAD            = function() ns:CompanionOnDead() end,
	PLAYER_ALIVE           = function() ns:CompanionOnAlive() end,
	PLAYER_UNGHOST         = function() ns:CompanionOnAlive() end,
	COMBAT_LOG_EVENT_UNFILTERED = function(...) ns:CompanionOnCombatLog(...) end,
	-- moteur 12.0 (Forever) : journal de combat fermé, l'événement autonome
	PARTY_KILL = function(attacker)
		attacker = ns.Plain(attacker)
		if attacker and attacker == Call(rawget(_G, "UnitGUID"), "player") then ns:CompanionOnKill() end
	end,
	CHAT_MSG_COMBAT_XP_GAIN = function(message) ns:CompanionOnCombatXP(message) end,
	-- avis sur la personne à qui l'on parle
	GOSSIP_SHOW            = function() ns:CompanionOnNpc(ns.CompanionGossipKind()) end,
	MERCHANT_SHOW          = function() ns:CompanionOnNpc("merchant") end,
	TRAINER_SHOW           = function() ns:CompanionOnNpc("trainer") end,
	TAXIMAP_OPENED         = function() ns:CompanionOnNpc("flight") end,
	BANKFRAME_OPENED       = function() ns:CompanionOnNpc("banker") end,
	QUEST_GREETING         = function() ns:CompanionOnNpc("quest") end,
	QUEST_DETAIL           = function() ns:CompanionOnNpc("quest") end,
	CONFIRM_BINDER         = function() ns:CompanionOnNpc("innkeeper") end,
	-- tutoriel : suspendu en combat, (re)lancé à la sortie
	PLAYER_REGEN_DISABLED  = function() ns:CompanionPauseTutorial() end,
	PLAYER_REGEN_ENABLED   = function()
		local rt = ns.companionRT
		if rt and rt.tutoPending then ns:CompanionStartTutorial(false) end
	end,
	QUEST_TURNED_IN        = function()
		ns:CompanionAdd("mood", 12)
		ns:CompanionWake(false)
		ns:CompanionSay("QUEST")
	end,
	CHAT_MSG_LOOT          = function(message) ns:CompanionOnLoot(message) end,
	ZONE_CHANGED_NEW_AREA  = function() ns:CompanionOnZone(true) end,
	ZONE_CHANGED           = function() ns:CompanionOnZone(false) end,
	ZONE_CHANGED_INDOORS   = function() ns:CompanionOnZone(false) end,
	UNIT_AURA              = function(unit) if unit == "player" then ns:CompanionCheckAuras() end end,
	PLAYER_UPDATE_RESTING  = function()
		if Call(rawget(_G, "IsResting")) and not ns:CompanionData().sleepy then ns:CompanionSay("INN") end
	end,
}

local events = CreateFrame("Frame")
ns.RegisterHandlers(events, HANDLERS)
events:SetScript("OnEvent", function(_, event, ...)
	if not ModuleOn() then return end
	local handler = HANDLERS[event]
	if not handler then return end
	local ok, err = pcall(handler, ...)
	if not ok and ns.RecordError then ns:RecordError("companion:" .. tostring(event), err) end
end)

-- Horloge : besoins toutes les TICK s, fin de bulle, fin d'animation,
-- léger balancement du modèle
local pending, sway = 0, 0
events:SetScript("OnUpdate", function(_, delta)
	if not ModuleOn() then return end
	delta = math.min(tonumber(delta) or 0, MAX_STEP)
	pending = pending + delta
	sway = sway + delta
	local now = Clock()
	if ns.companionBubbleUntil and now >= ns.companionBubbleUntil then ns:CompanionHideBubble() end
	if ns.companionAnimUntil and now >= ns.companionAnimUntil then ns:CompanionAnimate() end
	-- séquence (conversation, tutoriel) : bulle suivante à l'heure dite
	local rt = ns.companionRT
	if rt and rt.seq and now >= (rt.seq.nextAt or 0) then
		local ok, err = pcall(ns.CompanionSequenceStep, ns)
		if not ok and ns.RecordError then ns:RecordError("companion:sequence", err) end
	end
	local frame = ns.companionFrame
	if frame and frame.model and not frame.usesFallback and frame:IsShown() then
		Method(frame.model, "SetRotation", 0.35 * math.sin(sway * 0.5))
	end
	if pending < TICK then return end
	local step = pending
	pending = 0
	local ok, err = pcall(ns.CompanionTick, ns, step)
	if not ok and ns.RecordError then ns:RecordError("companion:tick", err) end
end)
ns.companionEvents = events

if ns.Mark then ns.Mark("Companion") end
