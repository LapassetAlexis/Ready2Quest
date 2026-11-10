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
-- 2.10.0 : en combat, seules passent les bulles qui demandent d'agir tout de
-- suite (une brillante, un rare repéré) ; le reste est compté et résumé après
-- (et le Peureux qui s'alarme de ta vie sous 60 %, une fois par combat :
-- c'est une alerte, et sa seule réplique de combat, Personality.lua)
local COMBAT_PASS = { SHINY_SPOTTED = true, RARE_LIVE = true, NOTICE__fearful = true }
ns.COMPANION_COMBAT_PASS = COMBAT_PASS
ns.COMPANION_COMBAT_ALPHA = 0.35     -- opacité du cadre et du filet en combat
ns.COMPANION_SUMMARY_DELAY = 1.5     -- s entre la fin du combat et le résumé
ns.COMPANION_FIGHT_GRACE = 1         -- s où le drapeau d'entrée en combat suffit (les API suivent)
ns.COMPANION_MOVES = { "free", "alt", "locked" }
ns.COMPANION_AGGRO_MODES = { "solo", "always", "off" }

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
	EVOLVE = "event", UNLOCK = "event", READY = "event", CHEST = "event", TUTO = "tuto",
	TIP = "tip", GOAL = "tip", GOAL_STAGE = "tip",
	IDLE = "chatter", NIGHT = "chatter",
	JOKE = "chatter",     -- 2.13.0 : les blagues au repos (CompanionJokes.lua)
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
-- 3.0.0 : le tutoriel de la ménagerie (2.3.0, bulles) est retiré : les
-- visites guidées (GuidedTour.lua) le remplacent ; son drapeau
-- (tutoMenagerieDone) reste dans les sauvegardes, ignoré
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
	OPT_COMP_NET_SHOW      = "Afficher le filet de capture",
	OPT_COMP_NET_SHOW_DESC = "Le bouton filet à côté du compagnon, réglable à part. Masqué : les créatures à capturer attendent dans la file (raccourci « Lancer le filet » ou /qc filet).",
	OPT_COMP_SIZE          = "Taille",
	COMP_SIZE_1            = "Petit",
	COMP_SIZE_2            = "Moyen",
	COMP_SIZE_3            = "Grand",
	COMP_SIZE_4            = "Très grand",
	COMP_SIZE_DESC         = "La taille de son cadre ; sa bulle reste lisible et le suit.",
	OPT_COMP_FRAMING       = "Cadrage",
	COMP_FRAMING_portrait  = "Portrait (la tête)",
	COMP_FRAMING_buste     = "Buste",
	COMP_FRAMING_pied      = "En pied",
	COMP_FRAMING_DESC      = "Comment la créature est cadrée dans son cadre à l'écran. Une créature capturée est de taille réelle : en pied, elle est toute petite.",
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
	COMP_HOVER_HINT        = "Clic : un câlin · Maj + clic : friandises · clic droit : carnet · Maj + clic droit : chasse · glisser : déplacer\nChange de compagnon : toute créature capturée au filet, page Compagnon du carnet",
	-- 2.10.0 : compagnon discret en combat, masqué en donjon, alerte d'aggro réglable, déplacement verrouillé
	OPT_COMP_COMBAT_FADE   = "Estomper en combat",
	OPT_COMP_COMBAT_FADE_DESC = "Le compagnon se fait discret pendant un combat et te raconte tout après.",
	OPT_COMP_HIDE_INSTANCE = "Masquer en donjon et en raid",
	OPT_COMP_HIDE_INSTANCE_DESC = "Le compagnon et son filet reviennent à la sortie.",
	OPT_COMP_AGGRO         = "Alerte « plusieurs monstres sur toi »",
	OPT_COMP_AGGRO_DESC    = "Le cadre du compagnon clignote en rouge quand deux monstres ou plus te visent.",
	COMP_AGGRO_solo        = "Seul, hors instance",
	COMP_AGGRO_always      = "Toujours",
	COMP_AGGRO_off         = "Jamais",
	OPT_COMP_MOVE          = "Déplacer le compagnon",
	OPT_COMP_MOVE_DESC     = "Pour ne plus le déplacer en voulant le caresser.",
	COMP_MOVE_free         = "En le glissant",
	COMP_MOVE_alt          = "Alt + glisser",
	COMP_MOVE_locked       = "Verrouillé",
	COMP_HOVER_HINT_alt    = "Clic : un câlin · Maj + clic : friandises · clic droit : carnet · Maj + clic droit : chasse · Alt + glisser : déplacer\nChange de compagnon : toute créature capturée au filet, page Compagnon du carnet",
	COMP_HOVER_HINT_locked = "Clic : un câlin · Maj + clic : friandises · clic droit : carnet · Maj + clic droit : chasse\nChange de compagnon : toute créature capturée au filet, page Compagnon du carnet",
	COMP_MSG_SHOWN         = "Compagnon : %s.",
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
	HELP_COMPANION         = "/qc compagnon [nom <nom> | caresse | apparence | muet | cacher | montrer | tuto [passer] | anim] — ton compagnon de route",
}
local EN = {
	OPT_PAGE_COMPANION_MAIN = "Companion",
	OPT_PAGE_COMPANION_MAIN_SUB = "Its creature, size, chattiness and appearance.",
	OPT_PAGE_COMPANION_ORN = "Ornaments",
	OPT_PAGE_COMPANION_ORN_SUB = "The ornaments of its frame, earned by playing: show the ones you like.",
	OPT_PAGE_COMPANION     = "Road companion",
	OPT_PAGE_COMPANION_SUB = "A little creature that travels with you and reacts to your adventure.",
	OPT_COMP_SHOW          = "Show the companion",
	OPT_COMP_NET_SHOW      = "Show the capture net",
	OPT_COMP_NET_SHOW_DESC = "The net button next to the companion, set apart from it. Hidden: creatures to capture wait in the queue (\"Throw the net\" key binding or /qc filet).",
	OPT_COMP_SIZE          = "Size",
	COMP_SIZE_1            = "Small",
	COMP_SIZE_2            = "Medium",
	COMP_SIZE_3            = "Large",
	COMP_SIZE_4            = "Huge",
	COMP_SIZE_DESC         = "The size of its frame; its bubble stays readable and follows it.",
	OPT_COMP_FRAMING       = "Framing",
	COMP_FRAMING_portrait  = "Portrait (the head)",
	COMP_FRAMING_buste     = "Bust",
	COMP_FRAMING_pied      = "Full body",
	COMP_FRAMING_DESC      = "How the creature is framed in its on-screen frame. A captured creature is life-size: full body, it looks tiny.",
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
	COMP_HOVER_HINT        = "Click: a cuddle · Shift + click: treats · right-click: journal · Shift + right-click: hunt · drag: move\nSwitch companion: any creature caught with the net, journal's Companion page",
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
	OPT_COMP_COMBAT_FADE   = "Fade in combat",
	OPT_COMP_COMBAT_FADE_DESC = "Your companion keeps quiet during a fight and tells you everything afterwards.",
	OPT_COMP_HIDE_INSTANCE = "Hide in dungeons and raids",
	OPT_COMP_HIDE_INSTANCE_DESC = "The companion and its net come back when you leave.",
	OPT_COMP_AGGRO         = "“Several monsters on you” alert",
	OPT_COMP_AGGRO_DESC    = "The companion's frame flashes red when two or more monsters target you.",
	COMP_AGGRO_solo        = "Solo, outside instances",
	COMP_AGGRO_always      = "Always",
	COMP_AGGRO_off         = "Never",
	OPT_COMP_MOVE          = "Moving the companion",
	OPT_COMP_MOVE_DESC     = "So you no longer move it when you meant to pet it.",
	COMP_MOVE_free         = "By dragging",
	COMP_MOVE_alt          = "Alt + drag",
	COMP_MOVE_locked       = "Locked",
	COMP_HOVER_HINT_alt    = "Click: a cuddle · Shift + click: treats · right-click: journal · Shift + right-click: hunt · Alt + drag: move\nSwitch companion: any creature caught with the net, journal's Companion page",
	COMP_HOVER_HINT_locked = "Click: a cuddle · Shift + click: treats · right-click: journal · Shift + right-click: hunt\nSwitch companion: any creature caught with the net, journal's Companion page",
	COMP_MSG_SHOWN         = "Companion: %s.",
	COMP_MSG_MUTE          = "Companion bubbles: %s.",
	COMP_MSG_FALLBACK      = "3D model unavailable on this client: the compass stands in.",
	HELP_COMPANION         = "/qc compagnon [nom <name> | caresse | apparence | muet | hide | show | tuto | anim] — your road companion",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.COMPANION_STRINGS = { fr = FR, en = EN } end   -- exposé aux tests (parité fr/en)

ns.RegisterDefaults({
	companionEnabled    = true,
	companionShow       = true,
	companionNetShow    = true,     -- 2.10.0 : le bouton filet, réglable à part du compagnon
	companionPoint      = { point = "CENTER", x = 330, y = -170 },
	companionSize       = 2,      -- réglette « Taille » : 1 petit, 2 moyen, 3 grand, 4 très grand
	companionFraming    = "buste",      -- cadrage du modèle : portrait (tête), buste, pied (2.2.0 ; buste par défaut en 2.9.0)
	companionOrnRibbon  = true,
	companionOrnLantern = true,
	companionOrnMedal   = true,
	companionOrnGold    = true,
	companionOrnFlower  = true,
	companionOrnPennant = true,
	companionOrnCrystal = true,
	companionOrnCrown   = true,
	-- 2.10.0 : discret en combat, masqué en donjon (au choix), glisser avec Alt
	companionCombatFade   = true,
	companionHideInstance = false,
	companionMove         = "alt",
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
		{ key = "companionNetShow",    label = "OPT_COMP_NET_SHOW",   kind = "bool",
			describe = function() return L.OPT_COMP_NET_SHOW_DESC end,
			onChange = function() if ns.CaptureQueueRefresh then pcall(ns.CaptureQueueRefresh, ns) end end },
		-- 2.10.0 : discret en combat, masqué en donjon, alerte d'aggro, déplacement
		{ key = "companionCombatFade", label = "OPT_COMP_COMBAT_FADE", kind = "bool",
			describe = function() return L.OPT_COMP_COMBAT_FADE_DESC end,
			onChange = function() ns:CompanionApplyContext() end },
		{ key = "companionHideInstance", label = "OPT_COMP_HIDE_INSTANCE", kind = "bool",
			describe = function() return L.OPT_COMP_HIDE_INSTANCE_DESC end,
			onChange = function() ns:CompanionUpdateVisibility(); if ns.CaptureQueueRefresh then ns:CaptureQueueRefresh() end end },
		{ key = "companionAggroBlink", label = "OPT_COMP_AGGRO",      kind = "action",
			choices = function() return ns:CompanionModeChoices(ns.COMPANION_AGGRO_MODES, "COMP_AGGRO_") end,
			current = function() return ns.CompanionAggroMode and ns:CompanionAggroMode() or "solo" end,
			describe = function() return L.OPT_COMP_AGGRO_DESC end,
			choose = function(id) ns:CompanionSetMode("companionAggroBlink", ns.COMPANION_AGGRO_MODES, id) end },
		{ key = "companionMove",       label = "OPT_COMP_MOVE",       kind = "action",
			choices = function() return ns:CompanionModeChoices(ns.COMPANION_MOVES, "COMP_MOVE_") end,
			current = function() return ns:CompanionMoveMode() end,
			describe = function() return L.OPT_COMP_MOVE_DESC end,
			choose = function(id) ns:CompanionSetMode("companionMove", ns.COMPANION_MOVES, id) end },
		-- réglette « Bavardage » : le nom du cran, une phrase dessous, le détail
		-- au survol, et le compagnon qui confirme
		{ key = "companionSize",       label = "OPT_COMP_SIZE",       kind = "number", min = 1, max = 4, step = 1,
			display = function(value) return L["COMP_SIZE_" .. value] end,
			describe = function() return L.COMP_SIZE_DESC end,
			onChange = function() ns:CompanionApplySize() end },
		{ key = "companionFraming",    label = "OPT_COMP_FRAMING",    kind = "action",
			choices = function() return ns:CompanionFramingChoices() end,
			current = function() return ns:CompanionFraming() end,
			describe = function() return L.COMP_FRAMING_DESC end,
			choose = function(id) ns:CompanionSetFraming(id) end },
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
			-- confirmation qui compare les effets (CompanionEffects.lua)
			choose = function(id)
				if ns.CompanionAskAppearance then ns:CompanionAskAppearance(id) else ns:CompanionSetAppearance(id) end
			end },
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
-- 2.10.0 : PLAYER_REGEN_DISABLED pose ns.companionFighting (l'heure) : sur
-- cet événement, InCombatLockdown() vaut encore faux. Le drapeau ne vaut que
-- quelques secondes (les API prennent le relais) : jamais bloqué si la fin du
-- combat n'arrive pas (module coupé pendant le combat)
local function InCombat()
	local fighting = ns.companionFighting
	if fighting then
		local since = Clock() - fighting
		if since >= 0 and since < ns.COMPANION_FIGHT_GRACE then return true end
	end
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
	local npc = type(data.appearance) == "string" and tonumber(data.appearance:match("^cap:(%d+)"))
	if npc and self.CaptureData then
		local ok, capture = pcall(self.CaptureData, self)
		local entry = ok and type(capture) == "table" and type(capture.creatures) == "table"
			and (capture.creatures[npc] or capture.creatures[tostring(npc)])
		-- 2.14.0 (bêta 4) : le nom, pas le numéro (CreatureName, Bestiary.lua)
		if type(entry) == "table" and self.CreatureName then
			local found = self:CreatureName(npc, entry)
			if ns.CreatureNameGood(found, npc) then return found end
		end
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
	-- 2.14.0 : par CompanionSetAppearance (un compagnon de saison se choisit
	-- sans remplacer l'apparence habituelle, WinterCompanions.lua)
	return self:CompanionSetAppearance(nextDef.id) or nextDef
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
--   asked    : demandé par le joueur (/qc blague) : passe la réglette, et
--              en combat, refusé sans être noté (2.13.0)
--   important: conseil de route important (élite, vie, munitions, vivres) :
--              seul ce qui passe au cran « Discret »
-- Jamais outre la sourdine ni une bulle plus importante encore affichée.
-- Renvoie true, ou false + raison ("off" : coupé/muet/masqué, "busy").
function ns:CompanionSay(pool, opts)
	opts = opts or {}
	if not ModuleOn() then return false, "off" end
	local db = self:DB()
	if db.companionShow == false then return false, "off" end
	-- 2.10.0 : en combat, rien ne s'ouvre (sauf COMBAT_PASS) : c'est noté et
	-- résumé après le combat (CompanionCombatSummary)
	if not opts.seq and not COMBAT_PASS[pool] and InCombat() then
		-- 2.13.0 : une demande du joueur (/qc blague) n'est pas notée : on le lui dit
		if opts.asked then return false, "combat" end
		self:CompanionCombatNote(pool, opts)
		return false, "combat"
	end
	local level = CHATTER[self:CompanionChatterLevel()]
	local rt, now = RT(), Clock()
	local category = opts.category or CategoryOf(pool)
	local prio = PRIORITY[category] or PRIORITY.reaction
	-- réglette « Bavardage » : ce que ce cran laisse dire
	-- (2.13.0 : `asked`, une demande du joueur, passe outre la réglette)
	if level.allow and not level.allow[category] and not opts.asked then return false, "off" end
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
	-- 2.13.0 : la voix du type de la créature (CompanionVoices.lua)
	local lineKey = opts.line or (self.CompanionVoicePick or self.CompanionPick)(self, pool, opts.args)
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
	if self.NotifyGlowArm then self:NotifyGlowArm() end   -- 2.11.2 : l'éclat du liseré
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
-- 2.10.0 : compagnon discret en combat. Ce qui aurait été dit est compté
-- (rt.combat : des compteurs et quelques noms, jamais plus), puis résumé en
-- une bulle après le combat ; un grand moment (évolution, niveau…) est gardé
-- et dit à la place du résumé.
-- ---------------------------------------------------------------------------
local FRESH_POOLS = { STAMP = true, FOUND = true, FOUND_MANY = true }
local DEAD_POOLS = { GROUP_DEAD = true, GROUP_HEALER_DEAD = true }
function ns:CompanionCombatNote(pool, opts)
	local rt = RT()
	local c = rt.combat
	if not c then
		c = { kills = 0, fresh = 0, net = 0, dead = {} }
		rt.combat = c
	end
	if pool == "KILL" then
		c.kills = c.kills + 1
		c.killName = opts and opts.args and opts.args[1] or nil   -- 2.13.0 : pour la voix (« %s : hors service »)
	elseif FRESH_POOLS[pool] then c.fresh = c.fresh + 1
	elseif pool == "CAPTURE_PROMPT" then c.net = c.net + 1
	elseif DEAD_POOLS[pool] then
		local name = opts and opts.args and opts.args[1]
		if name and #c.dead < 3 then c.dead[#c.dead + 1] = name end
	else
		local prio = PRIORITY[(opts and opts.category) or CategoryOf(pool)] or 0
		if prio >= PRIORITY.event and (not c.best or prio > c.best.prio) then
			c.best = { pool = pool, opts = opts, prio = prio }
		end
	end
	return c
end

-- La bulle d'après combat : au plus une. Renvoie ce que dit CompanionSay.
function ns:CompanionCombatSummary()
	local rt = RT()
	local c = rt.combat
	if not c or InCombat() then return false end
	rt.combat = nil
	if c.best then return self:CompanionSay(c.best.pool, c.best.opts) end
	-- les entrées du carnet en attente : comptées ici (pas de FOUND_MANY juste après)
	local notify = self.notifyState
	if notify and (tonumber(notify.pending) or 0) > 0 then
		c.fresh = c.fresh + notify.pending
		notify.pending = 0
	end
	if c.dead[1] then return self:CompanionSay("COMBAT_SUM_DEAD", { force = true, args = { c.dead[1] } }) end
	if c.kills >= 2 and c.net > 0 then return self:CompanionSay("COMBAT_SUM_NET", { args = { c.kills, c.net } }) end
	if c.kills >= 2 and c.fresh > 0 then return self:CompanionSay("COMBAT_SUM_NEW", { args = { c.kills } }) end
	if c.kills >= 2 then return self:CompanionSay("COMBAT_SUM", { args = { c.kills }, cd = "kill" }) end
	if c.kills == 1 then return self:CompanionSay("KILL", { cd = "kill", args = c.killName and { c.killName } or nil }) end
	return false
end

-- Donjon ou raid, avec le réglage « Masquer en donjon et en raid »
local function InstanceHidden(db)
	if not db.companionHideInstance then return false end
	local inside, kind = Call(rawget(_G, "IsInInstance"))
	if not inside then return false end
	-- type inconnu (client ancien) : une instance de groupe quand même
	return kind == nil or kind == "party" or kind == "raid"
end
function ns:CompanionInstanceHidden() return InstanceHidden(self:DB()) end

-- Opacité du cadre et du filet (le filet est un enfant de UIParent : il ne
-- suit pas l'alpha du cadre). Cadre non protégé : permis en combat.
function ns:CompanionContextAlpha()
	local db = self:DB()
	return (db.companionCombatFade ~= false and InCombat()) and ns.COMPANION_COMBAT_ALPHA or 1
end
function ns:CompanionApplyContext()
	local db = self:DB()
	local net = self.captureNetButton
	if InstanceHidden(db) then
		if self.companionFrame then self.companionFrame:Hide() end
		self:CompanionHideBubble()
		self:CompanionHideHover()
		if net then net:Hide() end
		return "hidden"
	end
	local alpha = self:CompanionContextAlpha()
	if self.companionFrame then
		self.companionFrame:SetAlpha(alpha)
		-- B7 (2.11.0) : le modèle 3D ne suit pas l'alpha du cadre ; estompé
		-- aussi (SetModelAlpha), rendu à 1 en fin de combat
		local model = self.companionFrame.model
		if model then
			ns.ModelSetAlpha(model, alpha)
			-- 2.11.1 : revenu à 1 après une estompe : modèle rechargé (rendu
			-- opaque et lumière neufs ; hors combat, rien de protégé)
			if model.alphaDirty then
				model.alphaDirty, model.modelKey = nil, nil
				self:CompanionApplyModel()
			end
		end
	end
	if net then net:SetAlpha(alpha) end
	return alpha
end

-- Le filet après chaque mise à jour de la file (crochet de CaptureQueueRefresh)
function ns:CompanionNetContext(button)
	if not button then return end
	if ModuleOn() and InstanceHidden(self:DB()) then button:Hide(); return end
	button:SetAlpha(self:CompanionContextAlpha())
end

-- Fin de combat : opacité rendue, résumé un peu après (PARTY_KILL du dernier
-- monstre peut arriver après PLAYER_REGEN_ENABLED)
function ns:CompanionCombatEnded()
	self.companionFighting = nil
	self:CompanionApplyContext()
	local timer = rawget(_G, "C_Timer")
	if timer and type(timer.After) == "function" then
		timer.After(ns.COMPANION_SUMMARY_DELAY, function()
			local ok, err = pcall(ns.CompanionCombatSummary, ns)
			if not ok and ns.RecordError then ns:RecordError("companion:summary", err) end
		end)
	else
		self:CompanionCombatSummary()
	end
end

-- Choix à crans (alerte d'aggro, déplacement) : listes des réglages
function ns:CompanionModeChoices(modes, prefix)
	local list = {}
	for _, id in ipairs(modes or {}) do list[#list + 1] = { value = id, label = L[prefix .. id] } end
	return list
end
function ns:CompanionSetMode(key, modes, id)
	local known = false
	for _, mode in ipairs(modes or {}) do if mode == id then known = true end end
	if not known then return nil end
	self:DB()[key] = id
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return id
end

-- 2.10.0 : déplacer le compagnon, en glissant (« free »), avec Alt (« alt »,
-- le défaut : un glisser simple ne fait rien) ou jamais (« locked »)
function ns:CompanionMoveMode()
	local mode = self:DB().companionMove
	if mode == "free" or mode == "locked" then return mode end
	return "alt"
end
function ns:CompanionMoveAllowed()
	local mode = self:CompanionMoveMode()
	if mode == "free" then return true end
	if mode == "locked" then return false end
	return Call(rawget(_G, "IsAltKeyDown")) and true or false
end
function ns:CompanionHoverHint()
	local mode = self:CompanionMoveMode()
	if mode == "free" then return L.COMP_HOVER_HINT end
	return L["COMP_HOVER_HINT_" .. mode]
end

-- Entrée ou sortie d'une instance : le compagnon et le filet suivent le réglage
function ns:CompanionInstanceChanged()
	local hidden = InstanceHidden(self:DB())
	if hidden == (self.companionInstanceHidden or false) and not hidden then return false end
	self.companionInstanceHidden = hidden
	self:CompanionUpdateVisibility()
	if self.CaptureQueueRefresh then pcall(self.CaptureQueueRefresh, self) end
	return true
end

-- Afficher / masquer (raccourci, /qc compagnon cacher|montrer)
function ns:CompanionToggleShown()
	local db = self:DB()
	db.companionShow = db.companionShow == false
	self:CompanionUpdateVisibility()
	if self.CaptureQueueRefresh then pcall(self.CaptureQueueRefresh, self) end
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	self:Print(self:F("COMP_MSG_SHOWN", db.companionShow and L.MODULE_ON or L.MODULE_OFF))
	return db.companionShow
end

-- ---------------------------------------------------------------------------
-- Séquences : petite conversation (clic), tutoriel de base. `steps` : les
-- clés du réservoir `pool`, dites au rythme `stepTime` ; opts.manual : rejeu
-- demandé par le joueur. (3.0.0 : les étapes qui attendaient un geste, pour
-- le tutoriel de la ménagerie, sont parties avec lui : GuidedTour.lua.)
-- ---------------------------------------------------------------------------
function ns:CompanionStartSequence(kind, pool, steps, stepTime, args, opts)
	opts = opts or {}
	local rt = RT()
	rt.seq = {
		kind = kind, pool = pool, steps = steps, index = 0, step = stepTime, args = args,
		manual = opts.manual and true or false,
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
		if seq.kind == "tuto" then self:CompanionFinishTutorial(seq.pool, { manual = seq.manual }) end
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

-- Fin du tutoriel de base (lu jusqu'au bout, ou passé). opts.skipped :
-- passé ; opts.manual : c'était un rejeu.
function ns:CompanionFinishTutorial(pool, opts)
	opts = opts or {}
	local data = self:CompanionData()
	local rt = RT()
	local seq = rt.seq
	if seq and seq.kind == "tuto" then rt.seq = nil end
	if self.companionBubblePrio == PRIORITY.tuto then self:CompanionHideBubble() end
	data.tutoDone = true
	rt.tutoPending = nil
end

function ns:CompanionSkipTutorial()
	local rt = RT()
	local seq = rt.seq
	local pool = (seq and seq.kind == "tuto" and seq.pool) or (rt.tutoPending and "TUTO") or nil
	self:CompanionFinishTutorial(pool or "TUTO", { skipped = true })
	if pool then self:Print(L.COMP_MSG_TUTO_SKIPPED) end
	return pool ~= nil
end

-- ---------------------------------------------------------------------------
-- Cadre : modèle 3D (ou boussole), nom, ornements, bulle, survol
-- ---------------------------------------------------------------------------
local FRAME_W, FRAME_H = 104, 118
local MODEL_H = 82
-- place du modèle dans le cadre (depuis son coin haut gauche) ; le style
-- Azeroth la remplace par l'ouverture de son cadre (frame.modelBase)
ns.COMPANION_MODEL_BASE = { x = 4, y = -4, w = FRAME_W - 8, h = MODEL_H }
ns.COMPANION_FRAME_SIZE = { w = FRAME_W, h = FRAME_H }

-- Pose le modèle à sa place (frame.modelBase), décalé de (dx, dy) par les
-- effets (CompanionFx.lua)
function ns:CompanionPlaceModel(dx, dy)
	local frame = self.companionFrame
	local model = frame and frame.model
	if not (model and model.SetPoint) then return nil end
	local base = frame.modelBase or ns.COMPANION_MODEL_BASE
	model:ClearAllPoints()
	model:SetPoint("TOPLEFT", frame, "TOPLEFT", base.x + (dx or 0), base.y + (dy or 0))
	model:SetSize(base.w, base.h)
	return base
end

-- Le cadrage d'un modèle (zoom portrait, distance, position) : model.framing
-- le repose ; rappelé à la fin du chargement (OnModelLoaded) et à
-- l'affichage, car un réglage posé avant la fin du chargement est perdu
function ns.ModelKeepFraming(model)
	if not model or model.azFramingHooked then return model end
	model.azFramingHooked = true
	local function Again(m) if m.framing then pcall(m.framing, m) end end
	for _, event in ipairs({ "OnModelLoaded", "OnShow" }) do
		if model.HookScript then pcall(model.HookScript, model, event, Again)
		elseif model.SetScript then pcall(model.SetScript, model, event, Again) end
	end
	return model
end
-- 2.11.0 (fiche 10) : un seul cadrage pour tous les modèles 3D de l'add-on.
-- Avant, huit appels posaient sept réglages, souvent avant la fin du
-- chargement (perdus). ns.ShowModel charge display d'abord, sinon npc, ne
-- recharge pas un modèle déjà affiché (clé display:npc:shiny:epoch), pose la
-- caméra à chaque OnModelLoaded et OnShow (ns.ModelKeepFraming) et lit un
-- profil nommé. Le zoom « portrait » (SetPortraitZoom) vise le point
-- d'attache de la tête, absent ou mal placé sur beaucoup de créatures
-- sauvages (la « patte » en gros plan) : il reste réservé aux mascottes
-- (display vérifiés, CompanionData.lua), jamais pour un npc seul.
-- cam : SetCamDistanceScale ; y : SetPosition vertical. Valeurs de départ,
-- à régler en jeu (rat, loup, kodo) avec /qc compagnon anim.
ns.MODEL_PROFILES = {
	companion = { cam = 1.6 },              -- cadre du compagnon (zoom : réglage companionFraming)
	portrait  = { cam = 1.6 },              -- aperçu des réglages, page Créature (cam : box.camScale)
	stage     = { cam = 1.2, y = 0 },       -- scène de capture et cases de « Tout capturer »
	prompt    = { cam = 1.0 },              -- petite fenêtre de capture (sans scène)
	preview   = { cam = 1.1 },              -- aperçu du carnet (JournalWindow)
	cell      = { cam = 1.2 },              -- cellules de la collection (JournalWindow)
	card      = { cam = 1.0 },              -- fiche de dresseur : la créature remplit ses 206 px
	cardTile  = { cam = 1.1 },              -- vitrine de la fiche de dresseur
	-- 2.14.0 (bêta 3) : vignette du choix d'allure (créature sans displayID
	-- appris) ; la distance vient de CompanionModelCam (type, espèce)
	tile      = { cam = 1.5 },
}

local function ModelCall(obj, name, ...)
	if obj and type(obj[name]) == "function" then return pcall(obj[name], obj, ...) end
	return false
end

-- 2.14.0 (bêta 4) : le modèle montré pour une créature quand le sien ne se
-- cadre pas (pnj → pnj montré à sa place) ; rempli par WinterCompanions.lua
ns.MODEL_NPC_LOOK = ns.MODEL_NPC_LOOK or {}

-- Opacité du modèle (B7, 2.11.0) : un PlayerModel ne suit pas l'alpha de son
-- cadre ; SetModelAlpha l'estompe vraiment. Gardée sur le modèle et reposée
-- avec le cadrage (un rechargement la remet à 1).
-- 2.11.1 : SetModelAlpha n'est appelé que si l'opacité change. En 2.11.0,
-- chaque affichage du compagnon posait SetModelAlpha(1) et une estompe de
-- combat laissait le modèle dans le rendu translucide du client : créature
-- sombre, presque noire sur le fond du cadre. Revenu à 1, le modèle est
-- rechargé (model.alphaDirty, voir CompanionApplyContext) : rendu et lumière
-- neufs.
function ns.ModelSetAlpha(model, alpha)
	if not model then return nil end
	alpha = tonumber(alpha) or 1
	model.contextAlpha = alpha
	local was = model.appliedAlpha or 1
	if alpha == was then return alpha end
	local done = ModelCall(model, "SetModelAlpha", alpha)
	if not done then ModelCall(model, "SetAlpha", alpha) end
	model.appliedAlpha = alpha
	if alpha >= 1 and was < 1 then model.alphaDirty = true end
	return alpha
end

-- Affiche une créature dans `model` : opts = { display, npc, shiny, zoom,
-- cam, scale, epoch } ; rend true si elle s'affiche (sinon le modèle est
-- caché : l'appelant montre son repli).
function ns.ShowModel(model, opts, profile)
	if not model then return false end
	opts = opts or {}
	local p = ns.MODEL_PROFILES[profile or "stage"] or ns.MODEL_PROFILES.stage
	local zoom = tonumber(opts.zoom) or p.zoom or 0
	if not opts.display then zoom = 0 end        -- créature sauvage : jamais de zoom « tête »
	local cam = tonumber(opts.cam) or p.cam or 1
	local scale, y = opts.scale, tonumber(opts.y) or p.y or 0
	-- 2.14.0 (bêta 3) : cap (SetFacing), seulement s'il est demandé
	local facing = tonumber(opts.facing)
	model.lightShiny = opts.shiny and true or false
	model.framing = function(m)
		if scale then ModelCall(m, "SetModelScale", scale) end
		ModelCall(m, "SetCamDistanceScale", cam)
		ModelCall(m, "SetPortraitZoom", zoom)
		ModelCall(m, "SetPosition", 0, 0, y)
		if facing then ModelCall(m, "SetFacing", facing) end
		if m.contextAlpha and m.contextAlpha < 1 then
			ModelCall(m, "SetModelAlpha", m.contextAlpha)
			m.appliedAlpha = m.contextAlpha
		end
		-- 2.11.1 : la lumière est reposée avec la caméra (un réglage posé
		-- avant la fin du chargement est perdu : modèle sans lumière, noir)
		m.shinyLit = nil
		ns.ModelShinyLight(m, m.lightShiny)
	end
	model.framingZoom, model.framingCam, model.modelProfile = zoom, cam, profile or "stage"
	ns.ModelKeepFraming(model)
	local npc = opts.npc
	if npc and ns.MODEL_NPC_LOOK[tonumber(npc) or -1] then npc = ns.MODEL_NPC_LOOK[tonumber(npc)] end
	local key = tostring(opts.display) .. ":" .. tostring(npc) .. ":" .. (opts.shiny and "s" or "")
		.. ":" .. tostring(opts.epoch)
	if model.modelKey == key and model.modelShown then
		model.framing(model)
		model:Show()
		return true
	end
	local shown = false
	if opts.display then shown = ModelCall(model, "SetDisplayInfo", opts.display) end
	if not shown and npc then shown = ModelCall(model, "SetCreature", npc) end
	model.modelKey, model.modelShown = key, shown and true or false
	-- 2.14.0 (bêta 5) : ce qui a été demandé au client (/qc noel metzen diag)
	model.modelNpc, model.modelDisplay = npc, opts.display
	-- un modèle rechargé repart opaque (le client remet son opacité à 1)
	model.appliedAlpha, model.alphaDirty = nil, nil
	if shown then
		model.framing(model)
		model:Show()
	else
		ModelCall(model, "ClearModel")
		model:Hide()
	end
	return shown and true or false
end

-- Oublie le modèle affiché (le prochain ShowModel recharge)
function ns.ModelForget(model)
	if not model then return end
	model.modelKey, model.modelShown = nil, nil
	ModelCall(model, "ClearModel")
	if model.Hide then model:Hide() end
end

-- Portrait 2D (2.11.0) : SetPortraitTextureFromCreatureDisplayID existe sur
-- Forever (vérifié en jeu le 9/11/2026). Il faut le displayID de l'espèce :
-- lu une fois, quand elle est vue vivante (BestiarySeeUnit), par un modèle
-- sonde (SetUnit puis GetDisplayInfo), gardé au compte
-- (db.capture.display[npcID]). Jamais en combat, au plus une lecture par
-- seconde.
ns.MODEL_LEARN_GAP = 1
local function ProbeRead(m)
	local npcID = m and m.learnNpc
	if not npcID then return nil end
	local ok, id = ModelCall(m, "GetDisplayInfo")
	id = ok and tonumber(id) or nil
	if id and id > 0 then
		local account = ns.CaptureAccount and ns:CaptureAccount()
		if account then
			account.display = type(account.display) == "table" and account.display or {}
			account.display[npcID] = id
		end
		m.learnNpc = nil
		return id
	end
	return nil
end
function ns:ModelLearnDisplay(unit, npcID)
	npcID = tonumber(npcID)
	if not (unit and npcID) or not self.CaptureAccount then return nil end
	local fighting = rawget(_G, "InCombatLockdown")
	if self.companionFighting or (type(fighting) == "function" and fighting()) then return nil end
	local account = self:CaptureAccount()
	if type(account.display) == "table" and account.display[npcID] then return account.display[npcID] end
	local now = (ns.Now and ns.Now()) or 0
	if self.modelLearnAt and now - self.modelLearnAt < ns.MODEL_LEARN_GAP then return nil end
	self.modelLearnAt = now
	local probe = self.modelLearnProbe          -- une seule sonde (gardée sur ns : /qc diag, tests)
	if probe == nil then
		local ok, made = pcall(CreateFrame, "PlayerModel", nil, UIParent)
		if not (ok and made) then self.modelLearnProbe = false; return nil end
		probe = made
		self.modelLearnProbe = probe
		probe:SetSize(1, 1)
		probe:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -50, -50)   -- hors de l'écran
		ModelCall(probe, "SetAlpha", 0)
		if probe.SetScript then pcall(probe.SetScript, probe, "OnModelLoaded", ProbeRead) end
	end
	if not probe or type(probe.SetUnit) ~= "function" or type(probe.GetDisplayInfo) ~= "function" then return nil end
	probe.learnNpc = npcID
	ModelCall(probe, "SetUnit", unit)
	return ProbeRead(probe)                       -- souvent lisible tout de suite
end

-- 2.14.0 (bêta 3) : apprendre le displayID d'une espèce capturée sans la
-- revoir vivante (le choix d'allure n'avait presque que des icônes de type,
-- toutes pareilles). Une sonde à part (pas celle des unités : deux
-- chargements croisés liraient le mauvais modèle), cachée hors de l'écran :
-- ClearModel, SetCreature(pnj), puis GetDisplayInfo une fois chargé
-- (OnModelLoaded) ou tout de suite si le client l'a déjà. File d'attente
-- remplacée à chaque appel (les vignettes visibles d'abord), au plus une
-- lecture tous les MODEL_LEARN_CREATURE_GAP s, jamais en combat (reprise
-- MODEL_LEARN_COMBAT_WAIT s plus tard). Gardé au compte comme les autres
-- (db.capture.display) : le portrait 2D sert ensuite partout.
ns.MODEL_LEARN_CREATURE_GAP = 0.35   -- ≈ 3 lectures par seconde au plus
ns.MODEL_LEARN_COMBAT_WAIT = 2
local learnQueue, learnSeen = {}, {}
local function Fighting()
	local fn = rawget(_G, "InCombatLockdown")
	return ns.companionFighting or (type(fn) == "function" and fn()) and true or false
end
local function CreatureProbe()
	local probe = ns.modelLearnCreatureProbe
	if probe ~= nil then return probe or nil end
	local ok, made = pcall(CreateFrame, "PlayerModel", nil, UIParent)
	if not (ok and made) then ns.modelLearnCreatureProbe = false; return nil end
	probe = made
	ns.modelLearnCreatureProbe = probe
	probe:SetSize(1, 1)
	probe:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -50, -50)
	ModelCall(probe, "SetAlpha", 0)
	if probe.SetScript then pcall(probe.SetScript, probe, "OnModelLoaded", ProbeRead) end
	return probe
end
function ns:ModelKnownDisplay(npcID)
	local account = self.CaptureAccount and self:CaptureAccount()
	local known = account and type(account.display) == "table" and account.display[tonumber(npcID) or -1]
	return tonumber(known)
end
-- La file : une liste de pnj (rangée par l'appelant) ; rend sa longueur
function ns:ModelLearnCreatures(list)
	for i = #learnQueue, 1, -1 do learnQueue[i] = nil end
	for key in pairs(learnSeen) do learnSeen[key] = nil end
	for _, npc in ipairs(list or {}) do
		npc = tonumber(npc)
		if npc and not learnSeen[npc] and not self:ModelKnownDisplay(npc) then
			learnSeen[npc] = true
			learnQueue[#learnQueue + 1] = npc
		end
	end
	if #learnQueue > 0 and not self.modelLearnPending then self:ModelLearnPump() end
	return #learnQueue
end
function ns:ModelLearnQueue() return learnQueue end
function ns:ModelLearnStop()
	for i = #learnQueue, 1, -1 do learnQueue[i] = nil end
end
-- Une lecture, puis la suivante plus tard (C_Timer) ; rend le pnj lancé
function ns:ModelLearnPump()
	self.modelLearnPending = nil
	if #learnQueue == 0 then return nil end
	local timer = rawget(_G, "C_Timer")
	local function Later(delay)
		if type(timer) == "table" and type(timer.After) == "function" then
			self.modelLearnPending = true
			timer.After(delay, function() ns:ModelLearnPump() end)
		end
	end
	if Fighting() then Later(ns.MODEL_LEARN_COMBAT_WAIT); return nil end
	local now = (ns.Now and ns.Now()) or 0
	local since = now - (self.modelLearnCreatureAt or -1e9)
	if since < ns.MODEL_LEARN_CREATURE_GAP then Later(ns.MODEL_LEARN_CREATURE_GAP - since); return nil end
	local npc = table.remove(learnQueue, 1)
	while npc and self:ModelKnownDisplay(npc) do npc = table.remove(learnQueue, 1) end
	if not npc then return nil end
	local probe = CreatureProbe()
	if not (probe and type(probe.SetCreature) == "function" and type(probe.GetDisplayInfo) == "function") then
		self:ModelLearnStop()
		return nil
	end
	self.modelLearnCreatureAt = now
	local _, before = ModelCall(probe, "GetDisplayInfo")
	ModelCall(probe, "ClearModel")
	probe.learnNpc = npc
	ModelCall(probe, "SetCreature", npc)
	-- lecture immédiate : seulement si ce n'est pas l'ancien modèle resté
	local ok, id = ModelCall(probe, "GetDisplayInfo")
	id = ok and tonumber(id) or nil
	if id and id > 0 and id ~= tonumber(before) then ProbeRead(probe) end
	if #learnQueue > 0 then Later(ns.MODEL_LEARN_CREATURE_GAP) end
	return npc
end

-- Le displayID connu d'une créature (candidat, fiche ou compte)
function ns:CreatureDisplay(target)
	if type(target) ~= "table" then return nil end
	if tonumber(target.display) then return tonumber(target.display) end
	local account = self.CaptureAccount and self:CaptureAccount()
	local known = account and type(account.display) == "table" and account.display[tonumber(target.npcID or target.npc) or -1]
	return tonumber(known)
end

-- Peint le portrait 2D rond de la créature sur `tex` ; sinon l'icône de son
-- type (ns.MENAGERIE_TYPE_ICONS), sinon l'icône des familiers. Rend
-- "portrait" ou "icon".
ns.CREATURE_PORTRAIT_ICON = "Interface\\Icons\\Ability_Hunter_BeastTaming"
function ns:CreaturePortrait(tex, target)
	if not tex then return nil end
	local id = self:CreatureDisplay(target)
	local fn = rawget(_G, "SetPortraitTextureFromCreatureDisplayID")
	if tex.SetDesaturated then tex:SetDesaturated(false) end
	if id and type(fn) == "function" and pcall(fn, tex, id) then
		if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
		tex.portraitKind = "portrait"
		return "portrait"
	end
	local types = ns.MENAGERIE_TYPE_ICONS
	tex:SetTexture((types and target and types[target.type or ""]) or ns.AZEROTH_PORTRAIT_ICON or ns.CREATURE_PORTRAIT_ICON)
	if tex.SetTexCoord then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	tex.portraitKind = "icon"
	return "icon"
end

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

-- 2.11.0 : crochet isolé sur le changement de style (AzerothStyle.lua) :
-- la bande du Sobre suit (cachée en Azeroth, l'humeur en TEXT au retour)
local function HookUIStyle()
	local apply = ns.CompanionApplyUIStyle
	if type(apply) ~= "function" or ns.companionPlateHooked == apply then return end
	local wrapped = function(self, ...)
		local style = apply(self, ...)
		self:CompanionApplySobrePlate()
		return style
	end
	ns.CompanionApplyUIStyle, ns.companionPlateHooked = wrapped, wrapped
end

function ns:EnsureCompanionFrame()
	HookUIStyle()
	if self.companionFrame then return self.companionFrame end
	if not (Theme and Theme.CreateDiscreet) then return nil end
	local frame = Theme.CreateDiscreet(UIParent, FRAME_W, FRAME_H)
	if not frame then return nil end
	frame:EnableMouse(true)
	if self.RestorePoint then self:RestorePoint(frame, "companionPoint", { point = "CENTER", x = 330, y = -170 }) end
	-- 2.10.0 : le glisser du socle (Theme.CreateDiscreet) suit le réglage
	-- « Déplacer le compagnon » ; l'OnDragStop de RestorePoint enregistre la
	-- position (sans glisser réel, il réécrit la même)
	frame:SetScript("OnDragStart", function(f)
		if ns:CompanionMoveAllowed() and f.StartMoving then f:StartMoving() end
	end)
	-- la position mémorisée est en unités du cadre à sa taille : on pose
	-- l'échelle avant tout recalage
	if frame.SetScale then frame:SetScale(ns.COMPANION_SIZES[self:CompanionSizeLevel()]) end

	frame.model = CreateModel(frame)
	frame.modelBase = ns.COMPANION_MODEL_BASE
	if frame.model then
		frame.model:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
		frame.model:SetSize(FRAME_W - 8, MODEL_H)
		-- 2.8.2 : le cadrage (portrait, distance) est reposé quand le modèle a
		-- fini de charger ; posé avant, le client l'ignore et la créature sort
		-- de son cadre (vue de loin, décentrée)
		ns.ModelKeepFraming(frame.model)
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
	-- 2.11.0 (fiche 09) : en Sobre, une bande sombre (noir à 80 %) porte le
	-- nom et l'humeur, quel que soit le fond gagné (papier à lettres clair,
	-- neige) ; l'humeur passe en TEXT : 8,5:1 même sur un sol blanc (avant :
	-- MUTED_LIGHT sur le voile 0,66, 3,0:1). Cachée en Azeroth (sa plaque).
	frame.plate = Theme.Solid(frame, "BORDER", Theme.INK, ns.CompanionPlateAlpha())
	frame.plate:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
	frame.plate:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	frame.plate:SetHeight(ns.COMPANION_PLATE_H)
	frame.mood = Theme.Text(frame, Theme.F_SMALL, Theme.TEXT)
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
		-- 3.0.0 : clic droit = le carnet, d'un geste (comme avant la 3.0) ;
		-- Maj + clic droit = le petit menu (carnet de voyage, mode chasse)
		if button == "RightButton" then
			if Call(rawget(_G, "IsShiftKeyDown")) then return ns:CompanionMenuToggle() end
			ns:CompanionMenuHide()
			return ns:CompanionOpenJournal()
		end
		ns:CompanionPet()
	end)
	frame:SetScript("OnEnter", function() ns:CompanionShowHover() end)
	frame:SetScript("OnLeave", function() ns:CompanionHideHover() end)

	self.companionFrame = frame
	self:CompanionApplyModel()
	self:CompanionApplyOrnaments()
	return frame
end

-- ---------------------------------------------------------------------------
-- 2.15.0 : le menu du clic droit et l'indicateur du mode chasse (maquette
-- capture215, écran 3). Maj + clic droit sur la créature (3.0.0 ; le clic
-- droit seul ouvre de nouveau le carnet) : un petit menu, comme la
-- rangée de sourdine du bandeau de capture : « Carnet de voyage » (le geste
-- d'avant), puis « Mode chasse » : 5 min, 15 min, 30 min, 1 h (ns.HUNT_CHOICES),
-- « Jusqu'à ce que je l'arrête », « Arrêter la chasse » (actif seulement en
-- chasse), « Annuler ». Échap, un clic ailleurs ou un second Maj + clic droit le
-- referment. Pendant la chasse : l'icône de la chasse (client, 132212) et le
-- temps restant en haut à gauche du cadre, à jour au fil des minutes (horloge
-- de l'addon, COMPANION_HUNT_BADGE.refresh), caché en vol (griffon) comme le
-- reste du décor ; au survol, « Mode chasse : encore 12 min ».
-- ---------------------------------------------------------------------------
local MENU_FR = {
	COMP_MENU_JOURNAL   = "Carnet de voyage",
	COMP_MENU_HUNT_STOP = "Arrêter la chasse",
	COMP_MENU_CANCEL    = "Annuler",
	COMP_MENU_HUNT_OFF  = "Chaque monstre abattu au filet, pour la durée choisie.",
	COMP_MENU_HUNT_ON   = "En cours : encore %s.",
	COMP_MENU_HUNT_ON_STOP = "En cours, jusqu'à ce que tu l'arrêtes.",
	COMP_MENU_MIN       = "%d min",
	COMP_MENU_HOUR      = "1 h",
	COMP_HUNT_TIP       = "Mode chasse : encore %s",
	COMP_HUNT_TIP_ON    = "Mode chasse : jusqu'à ce que tu l'arrêtes",
	COMP_HUNT_TIP_HINT  = "Maj + clic droit sur le compagnon : l'arrêter",
}
local MENU_EN = {
	COMP_MENU_JOURNAL   = "Travel journal",
	COMP_MENU_HUNT_STOP = "Stop hunting",
	COMP_MENU_CANCEL    = "Cancel",
	COMP_MENU_HUNT_OFF  = "Every defeated monster in the net, for the time you pick.",
	COMP_MENU_HUNT_ON   = "On: %s left.",
	COMP_MENU_HUNT_ON_STOP = "On, until you stop it.",
	COMP_MENU_MIN       = "%d min",
	COMP_MENU_HOUR      = "1 h",
	COMP_HUNT_TIP       = "Hunt mode: %s left",
	COMP_HUNT_TIP_ON    = "Hunt mode: until you stop it",
	COMP_HUNT_TIP_HINT  = "Shift + right-click the companion: stop it",
}
ns.RegisterStrings(MENU_FR, MENU_EN)
if ns.KEEP_STRINGS then ns.COMPANION_MENU_STRINGS = { fr = MENU_FR, en = MENU_EN } end

ns.COMPANION_MENU = { w = 216, pad = 12, row = 22, gap = 4 }
ns.COMPANION_HUNT_BADGE = { icon = "Interface\\Icons\\Ability_Hunter_SniperShot", size = 14, h = 18, x = 4, y = -4, refresh = 15 }

-- actif ou non (le client a Enable/Disable ; .off le dit partout)
local function SetOn(button, on)
	button.off = not on or nil
	if on then
		if button.Enable then button:Enable() end
	elseif button.Disable then
		button:Disable()
	end
end
local function MenuOver(frame)
	if not (frame and frame.IsMouseOver) then return false end
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and over and true or false
end

function ns:EnsureCompanionMenu()
	if self.companionMenu then return self.companionMenu end
	if not (Theme and Theme.CreateToast and Theme.CreateButton) then return nil end
	local M = ns.COMPANION_MENU
	local frame = Theme.CreateToast(UIParent, M.w, 100, { strata = "DIALOG", name = "QuestCompanionCompanionMenu", accent = Theme.GOLD })
	if not frame then return nil end
	frame:EnableMouse(true)
	if Theme.RegisterEscapeClose then pcall(Theme.RegisterEscapeClose, frame) end
	local left = frame.contentLeft or M.pad
	local width = M.w - left - M.pad
	local y = -M.pad
	frame.journal = Theme.CreateButton(frame, width, M.row, L.COMP_MENU_JOURNAL, function()
		ns:CompanionMenuHide()
		ns:CompanionOpenJournal()
	end, "normal")
	frame.journal:SetPoint("TOPLEFT", frame, "TOPLEFT", left, y)
	y = y - M.row - 10
	frame.huntTitle = Theme.Text(frame, Theme.F_CAPS or Theme.F_SMALL, Theme.GOLD)
	frame.huntTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", left, y)
	frame.huntTitle:SetText(Theme.Upper and Theme.Upper(L.HUNT_TITLE or "") or (L.HUNT_TITLE or ""))
	y = y - 15
	frame.huntStatus = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.huntStatus:SetPoint("TOPLEFT", frame, "TOPLEFT", left, y)
	frame.huntStatus:SetWidth(width)
	frame.huntStatus:SetJustifyH("LEFT")
	if frame.huntStatus.SetWordWrap then frame.huntStatus:SetWordWrap(true) end
	y = y - 28
	frame.durations = {}
	local choices = ns.HUNT_CHOICES or { 5, 15, 30, 60 }
	local w = math.floor((width - (#choices - 1) * M.gap) / #choices)
	for index, minutes in ipairs(choices) do
		local label = minutes >= 60 and L.COMP_MENU_HOUR or ns:F("COMP_MENU_MIN", minutes)
		local button = Theme.CreateButton(frame, w, M.row, label, function()
			ns:CompanionMenuHide()
			if ns.HuntStart then ns:HuntStart(minutes) end
		end, "accent")
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", left + (index - 1) * (w + M.gap), y)
		button.minutes = minutes
		frame.durations[index] = button
	end
	y = y - M.row - M.gap
	frame.untilStop = Theme.CreateButton(frame, width, M.row, L.HUNT_UNTIL_STOP or "", function()
		ns:CompanionMenuHide()
		if ns.HuntStart then ns:HuntStart(nil) end
	end, "accent")
	frame.untilStop:SetPoint("TOPLEFT", frame, "TOPLEFT", left, y)
	y = y - M.row - M.gap
	frame.stop = Theme.CreateButton(frame, width, M.row, L.COMP_MENU_HUNT_STOP, function()
		ns:CompanionMenuHide()
		if ns.HuntStop then ns:HuntStop() end
	end, "normal")
	frame.stop:SetPoint("TOPLEFT", frame, "TOPLEFT", left, y)
	y = y - M.row - M.gap
	frame.cancel = Theme.CreateButton(frame, width, M.row, L.COMP_MENU_CANCEL, function() ns:CompanionMenuHide() end, "outline")
	frame.cancel:SetPoint("TOPLEFT", frame, "TOPLEFT", left, y)
	y = y - M.row
	frame:SetHeight(-y + M.pad)
	-- un clic ailleurs (hors du menu et du compagnon), le combat : on referme
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	pcall(frame.RegisterEvent, frame, "GLOBAL_MOUSE_DOWN")
	frame:SetScript("OnEvent", function(f, event)
		if not f:IsShown() then return end
		if event == "GLOBAL_MOUSE_DOWN" and (MenuOver(f) or MenuOver(ns.companionFrame)) then return end
		ns:CompanionMenuHide()
	end)
	frame:Hide()
	self.companionMenu = frame
	return frame
end

function ns:CompanionMenuRefresh()
	local frame = self.companionMenu
	if not frame then return nil end
	local left = self.HuntRemaining and self:HuntRemaining()
	if not left then
		frame.huntStatus:SetText(L.COMP_MENU_HUNT_OFF)
		SetOn(frame.stop, false)
	elseif left < 0 then
		frame.huntStatus:SetText(L.COMP_MENU_HUNT_ON_STOP)
		SetOn(frame.stop, true)
	else
		frame.huntStatus:SetText(self:F("COMP_MENU_HUNT_ON", self:HuntText() or ""))
		SetOn(frame.stop, true)
	end
	return left
end

function ns:CompanionMenuShow()
	local frame = self:EnsureCompanionMenu()
	if not frame then return self:CompanionOpenJournal() end
	local anchor = self.companionFrame
	frame:ClearAllPoints()
	if anchor then frame:SetPoint("BOTTOM", anchor, "TOP", 0, 8) else frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
	self:CompanionHideHover()
	self:CompanionMenuRefresh()
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame, 0.12) end
	return frame
end

function ns:CompanionMenuHide()
	if self.companionMenu then self.companionMenu:Hide() end
end

function ns:CompanionMenuToggle()
	local frame = self.companionMenu
	if frame and frame:IsShown() then self:CompanionMenuHide(); return nil end
	return self:CompanionMenuShow()
end

-- L'indicateur de chasse sur le cadre : rend true s'il est montré
local function HuntBadgeTip(badge)
	local tooltip = rawget(_G, "GameTooltip")
	if not (type(tooltip) == "table" and tooltip.SetOwner) then return end
	tooltip:SetOwner(badge, "ANCHOR_TOP")
	local left = ns.HuntRemaining and ns:HuntRemaining()
	local line = (left and left >= 0) and ns:F("COMP_HUNT_TIP", ns:HuntText() or "") or L.COMP_HUNT_TIP_ON
	Theme.TooltipLine(tooltip, line, Theme.GOLD)
	Theme.TooltipLine(tooltip, L.COMP_HUNT_TIP_HINT, Theme.MUTED_LIGHT)
	tooltip:Show()
end

function ns:CompanionHuntBadge()
	local frame = self.companionFrame
	if not frame then return false end
	local badge = frame.huntBadge
	local left = ModuleOn() and self.HuntRemaining and self:HuntRemaining()
	-- en vol (griffon) : rangé, comme le reste du décor
	local flying = Call(rawget(_G, "UnitOnTaxi"), "player") == true
	if not left or flying then
		if badge then badge:Hide() end
		return false
	end
	local B = ns.COMPANION_HUNT_BADGE
	if not badge then
		badge = CreateFrame("Frame", nil, frame)
		badge:SetHeight(B.h)
		badge:SetPoint("TOPLEFT", frame, "TOPLEFT", B.x, B.y)
		badge:SetFrameLevel((frame:GetFrameLevel() or 1) + 6)
		badge.bg = Theme.Solid(badge, "BACKGROUND", Theme.INK, 0.85)
		badge.bg:SetAllPoints(badge)
		badge.edge = Theme.Border(badge, Theme.GOLD, 1, "BORDER")
		badge.icon = badge:CreateTexture(nil, "ARTWORK")
		badge.icon:SetSize(B.size, B.size)
		badge.icon:SetPoint("LEFT", badge, "LEFT", 2, 0)
		badge.icon:SetTexture(B.icon)
		badge.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		badge.text = Theme.Text(badge, Theme.F_SMALL, Theme.GOLD_LIGHT)
		badge.text:SetPoint("LEFT", badge.icon, "RIGHT", 3, 0)
		if badge.EnableMouse then badge:EnableMouse(true) end
		badge:SetScript("OnEnter", HuntBadgeTip)
		badge:SetScript("OnLeave", function()
			local tooltip = rawget(_G, "GameTooltip")
			if type(tooltip) == "table" and tooltip.Hide then tooltip:Hide() end
		end)
		frame.huntBadge = badge
	end
	-- jusqu'à l'arrêt : l'icône seule ; minutée : le temps restant
	local text = left >= 0 and (self:HuntText() or "") or ""
	if badge.label ~= text then
		badge.label = text
		badge.text:SetText(text)
		local w = text ~= "" and (Theme.TextWidth and tonumber(Theme.TextWidth(badge, text, Theme.F_SMALL)) or 30) or 0
		badge:SetWidth(B.size + 4 + (text ~= "" and (w + 6) or 0))
	end
	badge:Show()
	return true
end

ns:RegisterCallback("HUNT", function(self)
	self:CompanionHuntBadge()
	if self.companionMenu and self.companionMenu:IsShown() then self:CompanionMenuRefresh() end
end)
ns.Every("companionHunt", ns.COMPANION_HUNT_BADGE.refresh, function()
	local ok, err = pcall(ns.CompanionHuntBadge, ns)
	if not ok and ns.RecordError then ns:RecordError("companion:hunt", err) end
end)

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
	if hover.hint then hover.hint:SetText(self:CompanionHoverHint()) end
	self:CompanionRefreshHover()
	hover:Show()
end

function ns:CompanionHideHover()
	if self.companionHover then self.companionHover:Hide() end
end

-- Modèle : apparence, échelle du stade, animation de l'humeur. Sans
-- SetDisplayInfo (ou s'il refuse), la boussole prend la place.
-- Cadrage du modèle dans le cadre à l'écran (2.2.0)
ns.COMPANION_FRAMINGS = { "portrait", "buste", "pied" }
ns.COMPANION_FRAMING_ZOOM = { portrait = 1, buste = 0.55, pied = 0 }

function ns:CompanionFraming()
	local db = self:DB()
	-- 2.9.0 : l'ancien défaut « portrait » faisait déborder la créature de son
	-- petit cadre ; repassé une fois en « buste » (rechoisissable dans les réglages)
	if not db.companionFramingV29 then
		db.companionFramingV29 = true
		if db.companionFraming == "portrait" then db.companionFraming = "buste" end
	end
	local framing = db.companionFraming
	if ns.COMPANION_FRAMING_ZOOM[framing] then return framing end
	return "buste"   -- 2.9.0 : « portrait » serrait trop, la créature débordait du petit cadre
end

function ns:CompanionFramingChoices()
	local list = {}
	for _, id in ipairs(ns.COMPANION_FRAMINGS) do list[#list + 1] = { value = id, label = L["COMP_FRAMING_" .. id] } end
	return list
end

function ns:CompanionSetFraming(id)
	if not ns.COMPANION_FRAMING_ZOOM[id] then return nil end
	self:DB().companionFraming = id
	self:CompanionApplyModel()
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return id
end

-- 2.11.1 : taille d'une créature capturée dans le cadre. En 2.11.0, toutes
-- à 2,4 (CamDistanceScale) : trop petites, et un grand modèle (dragon) vu de
-- trop près (la caméra du modèle est réglée pour sa taille réelle). Distance
-- par type (noms FR et EN, entry.type de la fiche de capture), surcharge
-- par espèce ([npcID]) ou par apparence (["d" .. displayID]) : { cam, y }
-- (y : SetPosition vertical). Le cadrage du réglage la multiplie.
ns.COMPANION_MODEL_TYPE_CAM = {
	default = 1.6,
	["Bestiole"] = 1.2, Critter = 1.2,
	["Bête"] = 1.5, Beast = 1.5,
	["Humanoïde"] = 1.5, Humanoid = 1.5,
	["Mort-vivant"] = 1.5, Undead = 1.5,
	["Mécanique"] = 1.7, Mechanical = 1.7,
	["Démon"] = 1.8, Demon = 1.8,
	["Élémentaire"] = 1.8, Elemental = 1.8,
	["Géant"] = 2.4, Giant = 2.4,
	["Draconien"] = 2.8, Dragonkin = 2.8,
}
ns.COMPANION_MODEL_OVERRIDES = {}
ns.COMPANION_FRAMING_CAM = { portrait = 0.75, buste = 0.88, pied = 1 }

function ns:CompanionModelCam(app, framing)
	app = app or {}
	local over = ns.COMPANION_MODEL_OVERRIDES
	local spec = (app.display and over["d" .. tostring(app.display)]) or (app.npc and over[tonumber(app.npc)]) or nil
	local cam, y = spec and tonumber(spec.cam), spec and tonumber(spec.y)
	if not cam then
		local entry = app.npc and self.CaptureData and self:CaptureData().creatures[tonumber(app.npc)]
		local kind = app.type or (type(entry) == "table" and entry.type) or nil
		local types = ns.COMPANION_MODEL_TYPE_CAM
		cam = (kind and types[kind]) or types.default
	end
	local factor = ns.COMPANION_FRAMING_CAM[framing or self:CompanionFraming()] or 1
	return cam * factor, y, spec and tonumber(spec.facing) or nil
end

function ns:CompanionApplyModel()
	local frame = self.companionFrame
	if not frame then return end
	local app = self:CompanionCurrentAppearance()
	local stageDef = ns.COMPANION_STAGES[self:CompanionStage()] or ns.COMPANION_STAGES[1]
	local model = frame.model
	-- 2.11.0 : un seul cadrage (ns.ShowModel, profil « companion »). Créature
	-- capturée : taille réelle (un ours, un géant…), cadrée de plus loin, sans
	-- l'échelle du stade (faite pour les mascottes). Le zoom « portrait » du
	-- réglage (2.2.0) ne vaut que pour une mascotte (display) : ShowModel
	-- l'ignore pour une créature sauvage (npc seul).
	local framing = self:CompanionFraming()
	local zoom = ns.COMPANION_FRAMING_ZOOM[framing] or 0
	if not app.display then zoom = 0 end
	local distance, y, facing = zoom > 0 and 1 or 1.6, nil, nil
	-- 2.11.1 : créature capturée, distance selon son type (et son espèce),
	-- rapprochée par le cadrage (portrait, buste, pied)
	-- 2.14.0 : un compagnon de saison (créature du jeu, SetCreature) aussi
	local real = app.captured or app.seasonal
	if real then distance, y, facing = self:CompanionModelCam(app, framing) end
	-- 3.1.0 : la taille du spécimen porté (SpecimenTraits.lua) : échelle du
	-- modèle, rapprochée selon le cadrage, la caméra recule au-dessus de 1
	local sizeScale = 1
	if app.captured and self.CompanionSizeScale then
		local camFactor
		sizeScale, camFactor = self:CompanionSizeScale(framing)
		distance = distance * (camFactor or 1)
	end
	frame.sizeScale = sizeScale
	local shown = model and ns.ShowModel(model, { display = app.display, npc = app.npc, shiny = app.shiny,
		zoom = zoom, cam = distance, y = y, facing = facing, scale = real and sizeScale or stageDef.scale }, "companion") or false
	frame.usesFallback = not shown
	frame.displayID = shown and app.display or nil
	if shown then
		-- B7 : le modèle suit l'opacité du contexte (estompé en combat)
		ns.ModelSetAlpha(model, self:CompanionContextAlpha())
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
	self:CompanionApplySobrePlate()
	-- 2.13.1 : le rabat de l'humeur (Azeroth) suit le mot et sa teinte
	if self.CompanionApplyMoodTab then self:CompanionApplyMoodTab() end
end

-- 2.11.0 (fiche 09) : la bande sombre du Sobre et l'humeur en TEXT ; en
-- Azeroth, la plaque du style porte le texte (bande cachée). Rappelée au
-- retour en Sobre (CompanionApplyFrame, appelé par CompanionApplyUIStyle).
ns.COMPANION_PLATE_H = 34
ns.COMPANION_PLATE_ALPHA = 0.80           -- repli de Theme.PLATE_ALPHA (socle)
function ns.CompanionPlateAlpha()
	return tonumber(Theme.PLATE_ALPHA) or ns.COMPANION_PLATE_ALPHA
end
function ns:CompanionApplySobrePlate()
	local frame = self.companionFrame
	if not (frame and frame.plate) then return nil end
	local az = frame.uiStyle == "azeroth" or (frame.uiStyle == nil and self.AzerothOn and self:AzerothOn())
	if az then frame.plate:Hide(); return "azeroth" end
	frame.plate:Show()
	local t = Theme.TEXT
	if frame.mood and frame.mood.SetTextColor then frame.mood:SetTextColor(t[1], t[2], t[3], 1) end
	return "sobre"
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
	self:CompanionApplySobrePlate()
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
	if not ModuleOn() or db.companionShow == false or InstanceHidden(db) then
		if self.companionFrame then self.companionFrame:Hide() end
		-- en donjon (réglage) : le filet se cache aussi ; il revient à la sortie
		if self.captureNetButton and ModuleOn() and InstanceHidden(db) then self.captureNetButton:Hide() end
		self:CompanionHideBubble()
		self:CompanionHideHover()
		return false
	end
	local frame = self:EnsureCompanionFrame()
	if not frame then return false end
	self:CompanionApplyOrnaments()
	self:CompanionRefreshLabels()
	frame:Show()
	self:CompanionApplyContext()
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

-- Noms d'auras en minuscules, gardés (chaque changement d'aura du joueur relit
-- jusqu'à 40 auras ; les noms sont en nombre fini, liste vidée au-delà de 512)
local lowerNames, lowerCount = {}, 0
local function LowerName(name)
	local lower = lowerNames[name]
	if lower then return lower end
	lower = ns.AsciiLower(name)
	if lowerCount >= 512 then lowerNames, lowerCount = {}, 0 end
	lowerNames[name], lowerCount = lower, lowerCount + 1
	return lower
end

-- Renvoie mange-ou-boit ?, bien nourri ?, boit seulement ?
function ns:CompanionAuraState()
	local eating, fed, drinking = false, false, false
	local read = self.AuraByIndex
	if type(read) ~= "function" then return false, false, false end
	for index = 1, 40 do
		local aura = read(index)
		if not aura then break end
		local name = type(aura.name) == "string" and LowerName(aura.name) or nil
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
	-- 2.13.0 : parfois une blague à la place (CompanionJokes.lua)
	local pool = self.CompanionIdlePool and self:CompanionIdlePool() or "IDLE"
	if not self:CompanionSay(pool, { cd = "idle" }) then return false end
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
			-- 2.13.0 : un mot en entrant (CompanionLines DUNGEON, et la voix)
			local instance = Call(rawget(_G, "GetInstanceInfo"))
			if type(instance) ~= "string" or instance == "" then instance = nil end
			self:CompanionSay("DUNGEON", { args = instance and { instance } or nil, cd = "place" })
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
-- 2.13.0 : `name` = la victime (journal de combat), quand on la connaît
function ns:CompanionOnKill(name)
	local rt, now = RT(), Clock()
	if rt.lastKill and now - rt.lastKill < 2 then return false end
	rt.lastKill = now
	self:CompanionAdd("mood", 1)
	self:CompanionEliteKilled()
	if ns.Plain then name = ns.Plain(name) end
	if type(name) ~= "string" or name == "" then name = nil end
	return (self:CompanionSay("KILL", { cd = "kill", args = name and { name } or nil }))
end

function ns:CompanionOnCombatLog(...)
	local subevent, sourceGUID, destName
	local fn = rawget(_G, "CombatLogGetCurrentEventInfo")
	if type(fn) == "function" then
		local ok, _, sub, _, source, _, _, _, _, dest = pcall(fn)
		if not ok then return end
		subevent, sourceGUID, destName = sub, source, dest
	else
		local _, sub, _, source, _, _, _, _, dest = ...      -- très anciens clients : charge utile passée à l'événement
		subevent, sourceGUID, destName = sub, source, dest
	end
	-- filtre bon marché d'abord : cet événement tombe des dizaines de fois par seconde
	if subevent ~= "PARTY_KILL" or not sourceGUID then return end
	if sourceGUID ~= Call(rawget(_G, "UnitGUID"), "player") then return end
	self:CompanionOnKill(destName)
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

-- Lumière dorée d'une version brillante (1.6.0) : le jeu ne recolore pas
-- un modèle, mais il change la lumière qui l'éclaire. API récente (une
-- table, moteur de Forever) ou historique (une liste) ; la lumière d'origine
-- est lue une fois (GetLight) et remise quand la version n'est plus brillante.
local SHINY_AMBIENT, SHINY_DIFFUSE = { 1.0, 0.82, 0.38 }, { 1.0, 0.9, 0.55 }
-- 2.11.1 : la lumière blanche des modèles (proche de celle du client)
ns.MODEL_LIGHT = { ambient = 0.8, diffuse = 1.0, point = { -1, 1, -1 } }
function ns.ModelDefaultLight(model)
	if not (model and type(model.SetLight) == "function") then return false end
	local L0, p = ns.MODEL_LIGHT, ns.MODEL_LIGHT.point
	local vec, color = rawget(_G, "CreateVector3D"), rawget(_G, "CreateColor")
	if type(vec) == "function" and type(color) == "function" then
		if pcall(model.SetLight, model, true, {
			omnidirectional = false, point = vec(p[1], p[2], p[3]),
			ambientIntensity = L0.ambient, ambientColor = color(1, 1, 1),
			diffuseIntensity = L0.diffuse, diffuseColor = color(1, 1, 1),
		}) then return true end
	end
	return pcall(model.SetLight, model, true, false, p[1], p[2], p[3], L0.ambient, 1, 1, 1, L0.diffuse, 1, 1, 1) and true or false
end
function ns.ModelShinyLight(model, on)
	if not (model and type(model.SetLight) == "function") then return false end
	on = on and true or false
	if model.shinyLit == on then return true end
	if model.baseLight == nil then
		local packed = { pcall(model.GetLight or function() error("no") end, model) }
		model.baseLight = packed[1] and { select(2, unpack(packed)) } or false
	end
	local ok = false
	if on then
		local vec, color = rawget(_G, "CreateVector3D"), rawget(_G, "CreateColor")
		if type(vec) == "function" and type(color) == "function" then
			ok = pcall(model.SetLight, model, true, {
				omnidirectional = false, point = vec(-1, 1, -1),
				ambientIntensity = 1.1, ambientColor = color(SHINY_AMBIENT[1], SHINY_AMBIENT[2], SHINY_AMBIENT[3]),
				diffuseIntensity = 1.0, diffuseColor = color(SHINY_DIFFUSE[1], SHINY_DIFFUSE[2], SHINY_DIFFUSE[3]),
			})
		end
		if not ok then
			ok = pcall(model.SetLight, model, true, false, -1, 1, -1, 1.1, SHINY_AMBIENT[1], SHINY_AMBIENT[2],
				SHINY_AMBIENT[3], 1.0, SHINY_DIFFUSE[1], SHINY_DIFFUSE[2], SHINY_DIFFUSE[3])
		end
	elseif model.baseLight and model.baseLight[1] == true then
		ok = pcall(model.SetLight, model, unpack(model.baseLight))
	else
		-- 2.11.1 : lumière d'origine éteinte ou illisible (lue avant la fin du
		-- chargement) : la lumière blanche par défaut, jamais un modèle noir
		ok = ns.ModelDefaultLight(model)
	end
	if ok then model.shinyLit = on end
	return ok
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
		-- 2.11.0 : un seul cadrage (ns.ShowModel, profil « portrait »)
		local shown = self.model and ns.ShowModel(self.model, { display = app.display, npc = app.npc, shiny = app.shiny,
			cam = self.camScale }, "portrait") or false
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
	elseif sub == "cacher" or sub == "hide" or sub == "montrer" or sub == "afficher" or sub == "show" then
		-- 2.10.0 : idempotent (cacher deux fois ne le remontre pas)
		local want = not (sub == "cacher" or sub == "hide")
		if (self:DB().companionShow ~= false) ~= want then self:CompanionToggleShown()
		else self:Print(self:F("COMP_MSG_SHOWN", want and L.MODULE_ON or L.MODULE_OFF)) end
		return
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
		-- 3.0.0 : « tuto collection / capture / menagerie » (le tutoriel de la
		-- ménagerie, retiré) : la visite guidée des premières captures
		if what == "menagerie" or what == "ménagerie" or what == "capture" or what == "collection"
			or what == "creatures" or what == "créatures" then
			return self.TourCommand and self:TourCommand("capture") or false
		end
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
		ns:CompanionInstanceChanged()
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
	-- 2.10.0 : discret en combat (bulle fermée, cadre et filet estompés)
	PLAYER_REGEN_DISABLED  = function()
		ns.companionFighting = Clock()
		ns:CompanionPauseTutorial()
		ns:CompanionHideBubble()
		ns:CompanionApplyContext()
	end,
	PLAYER_REGEN_ENABLED   = function()
		ns:CompanionCombatEnded()
		local rt = ns.companionRT
		if rt and rt.tutoPending then ns:CompanionStartTutorial(false) end
	end,
	QUEST_TURNED_IN        = function()
		ns:CompanionAdd("mood", 12)
		ns:CompanionWake(false)
		ns:CompanionSay("QUEST")
	end,
	CHAT_MSG_LOOT          = function(message) ns:CompanionOnLoot(message) end,
	ZONE_CHANGED_NEW_AREA  = function() ns:CompanionInstanceChanged(); ns:CompanionOnZone(true) end,
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
-- léger balancement du modèle.
-- 2.11.2 (fiche 25) : échéances et besoins sur l'horloge de l'addon (dix fois
-- par seconde) ; seul le balancement reste image par image, posé sur le cadre
-- d'événements tant que le modèle est affiché, retiré sinon (plus d'OnUpdate
-- permanent quand le compagnon est caché)
local pending, sway = 0, 0
local function SwayModel()
	local frame = ns.companionFrame
	return frame and frame.model and not frame.usesFallback and frame:IsShown() and ModuleOn() and frame or nil
end
local function Sway(f, delta)
	local frame = SwayModel()
	if not frame then f:SetScript("OnUpdate", nil); f.swaying = nil; return end
	sway = sway + math.min(tonumber(delta) or 0, MAX_STEP)
	Method(frame.model, "SetRotation", 0.35 * math.sin(sway * 0.5))
end
ns.Every("companion", ns.CLOCK_POLL, function(step)
	if not ModuleOn() then return end
	pending = pending + math.min(tonumber(step) or 0, MAX_STEP)
	local now = Clock()
	if ns.companionBubbleUntil and now >= ns.companionBubbleUntil then ns:CompanionHideBubble() end
	if ns.companionAnimUntil and now >= ns.companionAnimUntil then ns:CompanionAnimate() end
	-- séquence (conversation, tutoriel) : bulle suivante à l'heure dite
	local rt = ns.companionRT
	if rt and rt.seq and now >= (rt.seq.nextAt or 0) then
		local ok, err = pcall(ns.CompanionSequenceStep, ns)
		if not ok and ns.RecordError then ns:RecordError("companion:sequence", err) end
	end
	if not events.swaying and SwayModel() then
		events.swaying = true
		events:SetScript("OnUpdate", Sway)
	end
	if pending < TICK then return end
	local step = pending
	pending = 0
	local ok, err = pcall(ns.CompanionTick, ns, step)
	if not ok and ns.RecordError then ns:RecordError("companion:tick", err) end
end)
ns.companionEvents = events

if ns.Mark then ns.Mark("Companion") end
