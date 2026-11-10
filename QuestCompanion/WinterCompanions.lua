-- WinterCompanions.lua -- compagnons de saison du Voile d'hiver (QuestCompanion 2.14.0)
--
-- Pendant le Voile d'hiver (ns:WinterVeilSeason, WinterVeil.lua : du 15
-- décembre au 2 janvier), trois créatures du jeu se choisissent comme une
-- apparence (« Son allure », réglages, carnet), sans remplacer l'apparence
-- habituelle : le choix vit à part (CompanionData().winter.pick), l'apparence
-- habituelle (data.appearance) ne bouge pas. Elle revient d'elle-même quand
-- le joueur rechoisit une apparence ordinaire, ou quand la saison finit (un
-- mot d'au revoir, une fois).
--   * Grand-père Hiver (PNJ 13444) : friandise en plus aux paliers de zone
--     (sorte treatZone) + « La hotte » : un cadeau par jour (friandise ou
--     aide de capture) à la première connexion du jour, ou au premier choix ;
--   * Metzen le renne (15664) : l'énergie baisse moins vite (decay) + « Le
--     nez qui brille » : la nuit (heure du jeu, 20 h à 6 h), un peu de
--     capture en plus (par l'enveloppe CompanionCaptureBonus) ;
--   * Petit bonhomme de neige (15710) : une caresse compte plus (pet) + « Il
--     aime le froid » : en zone froide (uiMapID), les envies baissent moins
--     vite ; en zone chaude, le moral baisse plus vite (il fond).
-- Effets et textes de la page « Ses effets » : CompanionEffects.lua
-- (COMPANION_WINTER_EFFECTS). Modèles par SetCreature (vérifiés en jeu).
-- Chacun a sa voix (réservoirs « <SITUATION>_V_<clé> »), prise à la place de
-- la voix du type de créature.
-- Visite surprise : pendant la saison, au plus une fois par session, hors
-- combat et hors instance, Grand-père Hiver passe dans un coin de l'écran
-- avec une bulle (~6 s, un clic le renvoie). Réglage dans la page du
-- compagnon.
-- Haut fait « Joyeux Voile d'hiver » (fun_winter_veil, FeatsCatMenagerie.lua) :
-- une heure de jeu ou 10 captures avec un compagnon de saison (le drapeau
-- « winterVeil » ne se pose qu'en saison ; le haut fait reste affiché après).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

-- ---------------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------------
ns.WINTER_SEASON_TTL = 60          -- s : la saison relue au plus une fois par minute
ns.WINTER_VOICE_SHARE = 0.8        -- part des bulles prises dans la voix de saison
ns.WINTER_SACK_TREAT = 0.5         -- la hotte : friandise (sinon une aide de capture)
ns.WINTER_NIGHT_FROM, ns.WINTER_NIGHT_TO = 20, 6   -- nuit du nez qui brille (heure du jeu)
ns.WINTER_MELT = 1.5               -- en zone chaude, le moral du bonhomme de neige baisse ×1,5
ns.WINTER_FEAT_TIME = 3600         -- s de jeu avec un compagnon de saison pour le haut fait
ns.WINTER_FEAT_CAPTURES = 10       -- ou captures avec lui
ns.WINTER_TICK = 15                -- s entre deux relevés (fin de saison, visite)
ns.WINTER_LOGIN_DELAY = 8          -- s après la connexion : au revoir, hotte
ns.WINTER_VISIT_DELAY = { 600, 2400 }  -- s de jeu avant la visite (au hasard)
ns.WINTER_VISIT_TIME = 6           -- s à l'écran
ns.WINTER_VISIT_FADE = 0.6         -- s de fondu, à l'arrivée et au départ
ns.WINTER_VISIT_NPC = 13444        -- Grand-père Hiver
ns.WINTER_VISIT_W, ns.WINTER_VISIT_H = 110, 140
ns.WINTER_VISIT_POINT = { "BOTTOMRIGHT", -90, 240 }   -- coin bas droit, au-dessus des barres
ns.WINTER_VISIT_CAM = 1.5
ns.WINTER_VISIT_BUBBLE_W = 220

-- Les trois compagnons : défs d'apparence (comme le catalogue), `seasonal` =
-- clé de leurs effets et de leur voix
ns.WINTER_COMPANIONS = {
	{ id = "winter:gfw",     seasonal = "gfw",     npc = 13444, label = "WINTER_COMP_gfw" },
	{ id = "winter:metzen",  seasonal = "metzen",  npc = 15664, label = "WINTER_COMP_metzen" },
	{ id = "winter:snowman", seasonal = "snowman", npc = 15710, label = "WINTER_COMP_snowman" },
}
local BY_ID, BY_KEY = {}, {}
for _, def in ipairs(ns.WINTER_COMPANIONS) do BY_ID[def.id], BY_KEY[def.seasonal] = def, def end

-- Cadrage dans le cadre du compagnon (CompanionModelCam : distance par PNJ).
-- Valeurs de départ, à régler en jeu : Grand-père Hiver a une taille
-- d'humanoïde, le renne celle d'un grand cerf, le bonhomme de neige celle
-- d'une mascotte.
if type(ns.COMPANION_MODEL_OVERRIDES) == "table" then
	ns.COMPANION_MODEL_OVERRIDES[13444] = { cam = 1.5 }
	ns.COMPANION_MODEL_OVERRIDES[15664] = { cam = 2.0 }
	ns.COMPANION_MODEL_OVERRIDES[15710] = { cam = 1.2 }
end

-- Zones froides et chaudes (uiMapID, data/forever/maps.json ; la neige :
-- drapeau 1 de la table des zones pour Dun Morogh et Berceau-de-l'Hiver)
ns.WINTER_COLD_MAPS = {
	[1426] = true,   -- Dun Morogh
	[1452] = true,   -- Berceau-de-l'Hiver
	[1416] = true,   -- Montagnes d'Alterac
	[1459] = true,   -- Vallée d'Alterac
}
ns.WINTER_HOT_MAPS = {
	[1446] = true,   -- Tanaris
	[1413] = true,   -- Les Tarides
	[1428] = true,   -- Steppes ardentes
	[1427] = true,   -- Gorge des Vents brûlants
	[1449] = true,   -- Cratère d'Un'Goro
	[1451] = true,   -- Silithus
	[1443] = true,   -- Désolace
	[1441] = true,   -- Mille pointes
	[1418] = true,   -- Terres ingrates
	[1411] = true,   -- Durotar
}

-- ---------------------------------------------------------------------------
-- Textes
-- ---------------------------------------------------------------------------
ns.RegisterStrings({
	WINTER_COMP_gfw     = "Grand-père Hiver",
	WINTER_COMP_metzen  = "Metzen le renne",
	WINTER_COMP_snowman = "Petit bonhomme de neige",
	WINTER_MSG_BYE      = "%s repart vers le Nord : ton compagnon habituel reprend sa place.",
	WINTER_MSG_SACK     = "La hotte de Grand-père Hiver : %s pour toi aujourd'hui.",
	OPT_COMP_WINTER_VISIT      = "Visite surprise de Grand-père Hiver",
	OPT_COMP_WINTER_VISIT_DESC = "Pendant le Voile d'hiver (15 décembre - 2 janvier), il passe parfois dire bonjour dans un coin de l'écran : une fois par session au plus, jamais en combat ni en donjon. Un clic le renvoie.",
}, {
	WINTER_COMP_gfw     = "Greatfather Winter",
	WINTER_COMP_metzen  = "Metzen the Reindeer",
	WINTER_COMP_snowman = "Tiny Snowman",
	WINTER_MSG_BYE      = "%s heads back north: your usual companion takes its place again.",
	WINTER_MSG_SACK     = "Greatfather Winter's sack: %s for you today.",
	OPT_COMP_WINTER_VISIT      = "Surprise visit from Greatfather Winter",
	OPT_COMP_WINTER_VISIT_DESC = "During Winter Veil (December 15 - January 2), he sometimes drops by in a corner of the screen: once per session at most, never in combat or in a dungeon. A click sends him off.",
})

-- ---------------------------------------------------------------------------
-- Les voix : { français, anglais }. Arguments : ceux du réservoir commun (le
-- nom pour KILL, CAPTURE_*, SHINY_SPOTTED, CITY, DUNGEON ; le niveau pour
-- LEVEL) ; PET, NEED, VIEW, COMBAT n'en ont pas.
-- ---------------------------------------------------------------------------
local P = {}
local function Voice(key, lines)
	for situ, list in pairs(lines) do P[situ .. "_V_" .. key] = list end
end

-- Grand-père Hiver : jovial, les cadeaux, la liste des sages et des vilains,
-- les rennes, le traîneau
Voice("gfw", {
	HELLO = {
		{ "Ho ho ho ! Tu as été sage cette année ? Les mobs que tu as tués, eux, ne diront rien.", "Ho ho ho! Have you been good this year? The mobs you slew won't tell a soul." },
		{ "Me voilà ! J'ai garé le traîneau derrière l'auberge, ne le dis pas au garde.", "Here I am! I parked the sled behind the inn. Don't tell the guard." },
		{ "Ho ho ! Une tournée de cadeaux, et toi en premier sur ma liste.", "Ho ho! A round of gifts, and you're first on my list." },
	},
	KILL = {
		{ "%s ? Liste des vilains. Je raye le nom, c'est plus simple.", "%s? Naughty list. I'll just cross the name off." },
		{ "Pas de cadeau pour celui-là cette année. Ni les suivantes.", "No gift for that one this year. Or any year after." },
		{ "Ho ho ! Un de moins à livrer, la tournée sera plus courte.", "Ho ho! One less stop on the round. A shorter night for me." },
	},
	CAPTURE_OK = {
		{ "Encore un pour la hotte !", "Another one for the sack!" },
		{ "%s, bienvenue ! Il reste de la place entre les jouets et les mandarines.", "%s, welcome! There's room between the toys and the tangerines." },
		{ "Joli paquet ! Je n'aurais pas mieux emballé.", "Nice package! I couldn't have wrapped it better." },
	},
	CAPTURE_FAIL = {
		{ "Il s'est sauvé comme un lutin un jour d'inventaire.", "It bolted like an elf on stocktaking day." },
		{ "Raté ! Pas grave, la hotte est patiente. Moi aussi.", "Missed! No matter, the sack is patient. So am I." },
		{ "%s file sans son cadeau. Tant pis pour lui.", "%s runs off without its present. Its loss." },
	},
	SHINY_SPOTTED = {
		{ "Ça brille comme une guirlande ! Là-bas, regarde !", "It's shining like tinsel! Over there, look!" },
		{ "%s qui scintille ? Voilà un cadeau qui se déballe tout seul.", "A sparkling %s? Now that's a gift that unwraps itself." },
	},
	LEVEL = {
		{ "Niveau %s ! Ho ho ho, je l'écris en lettres d'or sur ma liste.", "Level %s! Ho ho ho, I'm writing that in gold on my list." },
		{ "Tu grandis ! L'an prochain, il me faudra un plus gros paquet.", "You're growing! Next year I'll need a bigger box." },
	},
	EAT = {
		{ "Un biscuit ? Les rennes ont les carottes, moi je garde les biscuits.", "A biscuit? The reindeer get the carrots, I keep the biscuits." },
		{ "Mange, mange. Une nuit de livraisons, ça creuse.", "Eat up. A night of deliveries works up an appetite." },
	},
	CITY = {
		{ "%s ! Tant de cheminées… Voilà ma nuit toute trouvée.", "%s! So many chimneys… There goes my whole night." },
		{ "Une grande ville : il me faudra tous les rennes et un second traîneau.", "A big city: I'll need every reindeer and a second sled." },
	},
	DUNGEON = {
		{ "Mes rennes refusent d'entrer ici. Moi j'ai l'habitude, j'ai déjà livré des cadeaux à Ragnaros.", "My reindeer won't come in here. I'm used to it, I've delivered presents to Ragnaros." },
		{ "%s… Personne ici n'est sur la liste des sages. Personne.", "%s… Nobody in here is on the nice list. Nobody." },
		{ "Pas de cheminée, pas de sapin. Qui peut vivre dans un endroit pareil ?", "No chimney, no tree. Who could live in a place like this?" },
	},
	NIGHT = {
		{ "La nuit, c'est mon heure. Toutes les cheminées sont à moi.", "Night is my time. Every chimney in the land is mine." },
		{ "Les étoiles sont de sortie. Parfait pour mener le traîneau.", "The stars are out. Perfect for steering the sled." },
	},
	DEAD = {
		{ "Oh non ! Debout, debout, tu vas rater la distribution !", "Oh no! Up, up, you'll miss the gift-giving!" },
		{ "Je t'attends ici. Les sages, on les attend toujours.", "I'll wait right here. We always wait for the nice ones." },
	},
	REZ = {
		{ "Te revoilà ! Le plus beau cadeau de la journée.", "You're back! Best present of the day." },
		{ "Ho ho ! Tu es un peu pâle. Rien qu'un bon lait de poule ne règle.", "Ho ho! You look a bit pale. Nothing a good eggnog can't fix." },
	},
	IDLE = {
		{ "Ma liste des sages tient sur un parchemin. Celle des gnolls en fait trois.", "My nice list fits on one scroll. The gnolls alone fill three." },
		{ "Je compte les cadeaux. Il en manque un. Ah non, c'était le mien, je l'ai mangé.", "I'm counting the presents. One's missing. Oh wait, it was mine. I ate it." },
		{ "Un gobelin voulait m'acheter le traîneau. J'ai dit non. Il a dit : « Location ? »", "A goblin offered to buy my sled. I said no. He said: 'Rental, then?'" },
		{ "Ma barbe ? Des siècles de neige. Et un peu de sucre glace.", "My beard? Centuries of snow. And a dusting of icing sugar." },
	},
	PET = {
		{ "Ho ho ho ! Ça chatouille la barbe !", "Ho ho ho! That tickles my beard!" },
		{ "Toi, tu passes tout droit en haut de la liste des sages.", "You just jumped straight to the top of the nice list." },
		{ "Une caresse ? Ça vaut bien un bonbon. Tiens, il colle à peine.", "A pat? That's worth a sweet. Here, it's barely sticky." },
	},
	NEED = {
		{ "Ho… ho… Même Grand-père Hiver a besoin d'une pause.", "Ho… ho… Even Greatfather Winter needs a break." },
		{ "Un bol de lait de poule et un coin au chaud, et je repars.", "A bowl of eggnog and a warm corner, and I'm good to go." },
	},
	VIEW = {
		{ "Un nouveau pays ! Je l'ajoute à ma tournée.", "A new land! I'm adding it to my round." },
		{ "Belle vue. Je me demande si les cheminées sont larges, par ici.", "Lovely view. I wonder if the chimneys are wide around here." },
	},
	COMBAT = {
		{ "Ho ho ! Quelle mêlée. Je n'ai rien vu : je livre tout le monde, moi.", "Ho ho! Quite a scrap. I saw nothing: I deliver to everyone." },
		{ "Tous sur la liste des vilains. Je vais manquer d'encre.", "All on the naughty list. I'm running out of ink." },
	},
})

-- Metzen : fier, pressé, un renne de traîneau qui se respecte
Voice("metzen", {
	HELLO = {
		{ "Metzen, renne de traîneau. On ne fait pas attendre un renne de traîneau.", "Metzen, sled reindeer. One does not keep a sled reindeer waiting." },
		{ "Me voilà ! Harnais lustré, sabots cirés. On part ?", "Here I am! Harness polished, hooves waxed. Shall we go?" },
		{ "Tu es en retard. Moi, jamais. Question de métier.", "You're late. I never am. It's a professional matter." },
	},
	KILL = {
		{ "%s ? Trop lent. Tout le monde est trop lent.", "%s? Too slow. Everyone's too slow." },
		{ "Un coup de bois et c'est réglé. Suivant !", "One flick of the antlers and done. Next!" },
		{ "Vite fait, bien fait. J'approuve.", "Quick and clean. I approve." },
	},
	CAPTURE_OK = {
		{ "%s rejoint l'attelage. Il tirera à l'arrière.", "%s joins the team. It pulls at the back." },
		{ "Capturé ! Mon nez l'avait repéré bien avant toi.", "Caught! My nose spotted it long before you did." },
		{ "Bien. Rapide, efficace. Presque digne d'un renne.", "Good. Fast, efficient. Almost worthy of a reindeer." },
	},
	CAPTURE_FAIL = {
		{ "Raté. Moi, je l'aurais rattrapé au galop.", "Missed. I'd have caught it at a gallop." },
		{ "Personne n'échappe à un renne. Sauf celui-là, apparemment.", "Nobody outruns a reindeer. Except that one, apparently." },
		{ "%s se croit rapide. C'est mignon.", "%s thinks it's fast. How sweet." },
	},
	SHINY_SPOTTED = {
		{ "Ça brille presque autant que mon nez. Presque.", "That shines almost as bright as my nose. Almost." },
		{ "%s qui scintille ! Fonce, je couvre le flanc.", "A sparkling %s! Go, I'll cover the flank." },
	},
	LEVEL = {
		{ "Niveau %s ! Tu pourrais presque suivre mon rythme.", "Level %s! You could almost keep up with me." },
		{ "Un niveau de plus. Je hoche les bois : chez nous, c'est applaudir.", "Another level. I nod my antlers: that's how we clap." },
	},
	EAT = {
		{ "Une carotte ? Non ? Du lichen, alors. Je ne suis pas difficile.", "A carrot? No? Lichen, then. I'm not fussy." },
		{ "Mange vite. On a un horaire à tenir.", "Eat quickly. We have a schedule to keep." },
	},
	CITY = {
		{ "%s. Trop de monde, pas assez de neige. On traverse au trot.", "%s. Too many people, not enough snow. We trot straight through." },
		{ "Des toits partout. Je les connais tous, vus d'en haut.", "Rooftops everywhere. I know every one of them, from above." },
	},
	DUNGEON = {
		{ "%s ? Je refuse d'y poser un sabot. Bon. Un seul, alors.", "%s? I refuse to set hoof in there. Fine. One hoof." },
		{ "Pas de ciel, pas de piste d'envol. Je déteste déjà cet endroit.", "No sky, no runway. I already hate this place." },
		{ "Mon nez éclaire le couloir. Tu me remercieras plus tard.", "My nose lights the corridor. You can thank me later." },
	},
	NIGHT = {
		{ "La nuit tombe, mon nez s'allume : c'est l'heure des captures.", "Night falls, my nose lights up: capture time." },
		{ "De nuit, je vois tout. Rien ne nous échappera.", "At night I see everything. Nothing escapes us." },
	},
	DEAD = {
		{ "Debout ! Un renne n'abandonne jamais son meneur.", "Up! A reindeer never leaves its driver behind." },
		{ "Je monte la garde. Personne ne touche à mon attelage.", "I'm standing guard. Nobody touches my team." },
	},
	REZ = {
		{ "Enfin. On a perdu un temps précieux.", "Finally. We've lost precious time." },
		{ "Te revoilà. Je n'étais pas inquiet. Mes sabots tremblaient de froid, c'est tout.", "You're back. I wasn't worried. My hooves were shaking from the cold, that's all." },
	},
	IDLE = {
		{ "On ne fait pas attendre un renne de traîneau. Tu le sais, ça ?", "You don't keep a sled reindeer waiting. You do know that?" },
		{ "J'ai fait le tour d'Azeroth en une nuit. Toi, tu as fait le tour de l'auberge.", "I've circled Azeroth in one night. You've circled the inn." },
		{ "Je m'étire les pattes. Une livraison, ça se prépare.", "Stretching my legs. A delivery takes preparation." },
		{ "Les griffons se croient rapides. Je les laisse croire.", "Gryphons think they're fast. I let them believe it." },
	},
	PET = {
		{ "Pas les bois ! Le cou, oui. Voilà, là.", "Not the antlers! The neck, yes. There." },
		{ "Hmm. Acceptable. Tu peux continuer.", "Hmm. Acceptable. You may continue." },
		{ "Je fais semblant de ne pas aimer ça. Ne le dis à personne.", "I pretend not to like this. Don't tell anyone." },
	},
	NEED = {
		{ "Même un renne doit souffler. Une courte pause, pas plus.", "Even a reindeer needs a breather. A short one, no more." },
		{ "Mes sabots traînent. Ça ne m'arrive jamais. Enfin, presque.", "My hooves are dragging. That never happens. Well, hardly ever." },
	},
	VIEW = {
		{ "Nouvelle route ! Je la retiens pour la tournée.", "New route! I'm memorising it for the round." },
		{ "Belle piste. Parfaite pour prendre de l'élan.", "Nice stretch. Perfect for a running start." },
	},
	COMBAT = {
		{ "Combat terminé. Temps correct, peut mieux faire.", "Fight over. Decent time, room for improvement." },
		{ "Et voilà. Le traîneau n'a pas une égratignure.", "And done. Not a scratch on the sled." },
	},
})

-- Petit bonhomme de neige : naïf, émerveillé par la neige, inquiet de la chaleur
Voice("snowman", {
	HELLO = {
		{ "Bonjour ! Je suis tout neuf. Enfin, je crois. Il a neigé hier ?", "Hello! I'm brand new. I think. Did it snow yesterday?" },
		{ "Coucou ! J'ai gardé ma carotte. C'est mon nez, tu sais.", "Hi! I kept my carrot. It's my nose, you know." },
		{ "Me voilà ! Un peu de travers, mais entier.", "Here I am! A little lopsided, but all in one piece." },
	},
	KILL = {
		{ "Oh ! %s est tombé. Il avait froid, lui aussi ?", "Oh! %s fell over. Was it cold too?" },
		{ "Tu es fort ! Moi, je ne sais faire que des boules.", "You're so strong! All I can make is snowballs." },
		{ "Il ne bouge plus… Il fait le bonhomme de neige ?", "It's not moving… Is it playing snowman?" },
	},
	CAPTURE_OK = {
		{ "%s vient avec nous ! Je lui tricoterai une écharpe.", "%s is coming with us! I'll knit it a scarf." },
		{ "Un nouvel ami ! Il a l'air chaud. Pas trop près, d'accord ?", "A new friend! It looks warm. Not too close, okay?" },
		{ "Attrapé ! Comme un flocon, mais en plus gros.", "Caught! Like a snowflake, only bigger." },
	},
	CAPTURE_FAIL = {
		{ "Il est parti… Peut-être qu'il n'aime pas le froid ?", "It left… Maybe it doesn't like the cold?" },
		{ "Raté ! On réessaie ? Je ne fonds pas de honte. Pas encore.", "Missed! Try again? I'm not melting with shame. Not yet." },
		{ "%s s'est sauvé. Je lui avais pourtant souri.", "%s ran away. And I smiled at it, too." },
	},
	SHINY_SPOTTED = {
		{ "Ça brille comme du givre ! C'est joli !", "It sparkles like frost! So pretty!" },
		{ "Regarde %s ! Il brille comme la neige au soleil. Pas trop de soleil, hein.", "Look at %s! It shines like snow in the sun. Not too much sun, though." },
	},
	LEVEL = {
		{ "Niveau %s ! J'applaudirais bien, mais j'ai des branches.", "Level %s! I'd clap, but I've only got twigs." },
		{ "Tu grandis ! Moi, je grandis seulement quand il neige.", "You're growing! I only grow when it snows." },
	},
	EAT = {
		{ "Tu manges chaud ? Mange un peu plus loin, s'il te plaît.", "Is that hot food? Eat it a bit further away, please." },
		{ "Moi, je ne mange que des flocons. Ils fondent sur mon charbon.", "I only eat snowflakes. They melt on my coal." },
	},
	CITY = {
		{ "%s ! Tant de monde… Personne ne m'a encore marché dessus.", "%s! So many people… Nobody's stepped on me yet." },
		{ "Il y a des forges, ici ? Je reste au milieu de la rue.", "Are there forges here? I'm staying in the middle of the street." },
	},
	DUNGEON = {
		{ "Il fait sombre… et humide. Humide, c'est mauvais signe.", "It's dark… and damp. Damp is a bad sign." },
		{ "%s ? Il y a du feu, là-dedans ? Dis-moi qu'il n'y a pas de feu.", "%s? Is there fire in there? Tell me there's no fire." },
		{ "J'ai peur, mais je suis tout blanc : ça ne se voit pas.", "I'm scared, but I'm all white: it doesn't show." },
	},
	NIGHT = {
		{ "La nuit, il fait plus frais. Je suis bien.", "It's cooler at night. I feel great." },
		{ "Les étoiles, ce sont des flocons qui ne tombent jamais ?", "Are stars just snowflakes that never fall?" },
	},
	DEAD = {
		{ "Non ! Lève-toi ! Je te prête mon écharpe !", "No! Get up! You can have my scarf!" },
		{ "Je reste là. Je ne bouge pas. De toute façon, je ne sais pas bouger.", "I'll stay right here. I won't move. I can't really move anyway." },
	},
	REZ = {
		{ "Tu es revenu ! J'en ai perdu un bouton.", "You're back! I popped a button." },
		{ "Ouf ! J'ai eu si peur que j'ai gelé. Plus que d'habitude.", "Phew! I was so scared I froze. More than usual." },
	},
	IDLE = {
		{ "Chaque flocon est différent. J'en ai compté trois cents. Tous différents !", "Every snowflake is different. I counted three hundred. All different!" },
		{ "Tu crois que je suis né d'une boule ou de trois ?", "Do you think I was born from one snowball or three?" },
		{ "Mon nez de carotte me regarde. Enfin, je crois.", "My carrot nose is looking at me. I think." },
		{ "Un jour, je verrai la mer. De loin. Bien couvert.", "One day I'll see the sea. From afar. Well wrapped up." },
	},
	PET = {
		{ "Hihi ! Doucement, tu vas me faire fondre de joie !", "Hehe! Gently, you'll melt me with joy!" },
		{ "Tes mains sont chaudes… mais c'est gentil. Encore un peu.", "Your hands are warm… but it's nice. A little more." },
		{ "Tu as remis mon bouton en place ! Merci !", "You put my button back! Thank you!" },
	},
	NEED = {
		{ "Je me sens tout mou… Il me faudrait un peu de neige.", "I feel all soft… I need a bit of snow." },
		{ "Un coin d'ombre, un petit vent frais, et je repars.", "A shady corner, a cool breeze, and I'm good." },
	},
	VIEW = {
		{ "Un endroit nouveau ! Il y a de la neige ? Non ? C'est joli quand même.", "Somewhere new! Is there snow? No? It's still pretty." },
		{ "Waouh ! Je n'avais jamais vu ça. Je n'ai jamais rien vu, en fait.", "Wow! I've never seen this. I've never seen anything, really." },
	},
	COMBAT = {
		{ "C'est fini ? J'avais fermé les yeux. Enfin, mes cailloux.", "Is it over? I had my eyes shut. Well, my pebbles." },
		{ "Ça chauffe, les combats. J'ai un peu rétréci.", "Fights get hot. I've shrunk a little." },
	},
})

-- La hotte (%s = le cadeau), le froid et la chaleur (bonhomme de neige),
-- l'au revoir de fin de saison (dit par le compagnon habituel), la visite
P.WINTER_SACK = {
	{ "Ho ho ho ! Ce matin, dans la hotte : %s. Pour toi !", "Ho ho ho! In the sack this morning: %s. For you!" },
	{ "Tu as été sage hier. Tiens, %s. Ne le dis pas aux gnolls.", "You were good yesterday. Here, %s. Don't tell the gnolls." },
	{ "Un cadeau par jour, c'est la règle. Aujourd'hui : %s !", "One gift a day, that's the rule. Today: %s!" },
}
P.WINTER_HOT = {
	{ "Je… ruisselle.", "I'm… dripping." },
	{ "Il fait chaud ici. Très chaud. Ma carotte glisse.", "It's hot here. Very hot. My carrot's slipping." },
	{ "Ne t'inquiète pas, je fonds juste un peu. Beaucoup. Un peu beaucoup.", "Don't worry, I'm only melting a little. A lot. A little a lot." },
}
P.WINTER_COLD = {
	{ "De la neige ! Partout ! Je suis chez moi !", "Snow! Everywhere! I'm home!" },
	{ "Ce froid… c'est merveilleux. Je me sens tout neuf.", "This cold… it's wonderful. I feel brand new." },
	{ "Regarde, il neige ! Je vais pouvoir me refaire un bras.", "Look, it's snowing! I can make myself a new arm." },
}
P.WINTER_BYE_gfw = {
	{ "Grand-père Hiver repart vers le Nord… Ho ho ho, à l'année prochaine !", "Greatfather Winter heads back north… Ho ho ho, see you next year!" },
}
P.WINTER_BYE_metzen = {
	{ "Metzen repart tirer le traîneau vers le Nord. Pas d'au revoir : il était pressé.", "Metzen heads north to pull the sled. No goodbye: he was in a hurry." },
}
P.WINTER_BYE_snowman = {
	{ "Le petit bonhomme de neige repart vers le Nord, là où il fait bon froid. Il t'a laissé son écharpe.", "The tiny snowman heads north, where it's nice and cold. He left you his scarf." },
}
P.WINTER_VISIT = {
	{ "Ho ho ho ! Je passais dans le coin. Tu as été sage, j'espère ?", "Ho ho ho! Just passing by. You've been good, I hope?" },
	{ "Ne fais pas attention à moi, je vérifie juste ma liste.", "Don't mind me, just checking my list." },
	{ "Joyeux Voile d'hiver ! Laisse un biscuit près de ta pierre de foyer.", "Merry Winter Veil! Leave a biscuit by your hearthstone." },
	{ "Metzen m'attend sur le toit. Je repars aussi vite que je suis venu !", "Metzen's waiting on the roof. Off as fast as I came!" },
	{ "Ho ho ! Tu tues beaucoup de kobolds. Je ne juge pas. Je note.", "Ho ho! You kill a lot of kobolds. I don't judge. I take notes." },
	{ "Un petit bonjour du Nord ! Couvre-toi bien, il gèle à Berceau-de-l'Hiver.", "A little hello from the north! Bundle up, it's freezing in Winterspring." },
	{ "Ton journal de quêtes est plus long que ma liste. Courage !", "Your quest log is longer than my list. Chin up!" },
	{ "Ho ho ho ! Les gobelins m'ont encore fait payer le stationnement du traîneau.", "Ho ho ho! The goblins charged me for sled parking again." },
}
ns.RegisterCompanionLines(P, true)
P = nil

-- Réservoir commun -> situation de la voix de saison
local VOICE_OF = {
	HELLO = "HELLO", MISSED = "HELLO", AWAKE = "HELLO",
	KILL = "KILL", CAPTURE_OK = "CAPTURE_OK", CAPTURE_SHINY = "CAPTURE_OK", CAPTURE_FAIL = "CAPTURE_FAIL",
	SHINY_SPOTTED = "SHINY_SPOTTED", LEVEL = "LEVEL", EAT = "EAT", DRINK = "EAT",
	CITY = "CITY", VILLAGE = "CITY", DUNGEON = "DUNGEON", NIGHT = "NIGHT", DEAD = "DEAD", REZ = "REZ",
	IDLE = "IDLE", INN = "IDLE", CAMP = "IDLE", PET = "PET", PET_sleepy = "PET",
	NEED_hunger = "NEED", NEED_energy = "NEED", NEED_mood = "NEED", NEED_curiosity = "NEED",
	VIEW = "VIEW", COMBAT_SUM = "COMBAT", COMBAT_SUM_NEW = "COMBAT", COMBAT_SUM_NET = "COMBAT",
}
ns.WINTER_VOICE_OF = VOICE_OF
-- les situations de chaque voix (contrôle des tests)
ns.WINTER_VOICE_SITUATIONS = { "HELLO", "KILL", "CAPTURE_OK", "CAPTURE_FAIL", "SHINY_SPOTTED", "LEVEL", "EAT", "CITY",
	"DUNGEON", "NIGHT", "DEAD", "REZ", "IDLE", "PET", "NEED", "VIEW", "COMBAT" }

-- ---------------------------------------------------------------------------
-- Lectures défensives
-- ---------------------------------------------------------------------------
local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function ModuleOn() return ns.CompanionOn and ns.CompanionOn() or false end
local function InCombat()
	if Call(G("InCombatLockdown")) then return true end
	return Call(G("UnitAffectingCombat"), "player") and true or false
end
local function Today() local day = Call(G("date"), "%Y-%m-%d"); return type(day) == "string" and day or nil end

-- ---------------------------------------------------------------------------
-- Saison et compagnon choisi
-- ---------------------------------------------------------------------------
-- La saison (WinterVeil.lua, peut manquer), relue au plus toutes les
-- WINTER_SEASON_TTL secondes : elle est lue à chaque relevé des effets
local seasonAt, seasonOn = nil, false
local function Season()
	local now = Clock()
	if seasonAt and now >= seasonAt and now - seasonAt < ns.WINTER_SEASON_TTL then return seasonOn end
	local fn = ns.WinterVeilSeason
	seasonOn = type(fn) == "function" and Call(fn, ns) and true or false
	seasonAt = now
	return seasonOn
end
function ns:WinterCompanionsForget() seasonAt = nil end
function ns:WinterCompanionsSeason() return Season() end

local function WData(self)
	local data = self:CompanionData()
	if type(data.winter) ~= "table" then data.winter = {} end
	return data.winter
end

-- La déf du compagnon de saison porté (saison en cours), ou nil
local function Pick(self)
	if not self.CompanionData then return nil end
	local winter = self:CompanionData().winter
	local def = type(winter) == "table" and BY_KEY[winter.pick or ""]
	if not def or not Season() then return nil end
	return def
end
function ns:CompanionWinterSpec() return Pick(self) end
function ns:CompanionWinterKey() local def = Pick(self); return def and def.seasonal or nil end

-- ---------------------------------------------------------------------------
-- Apparences : les trois compagnons en tête de liste, en saison seulement
-- ---------------------------------------------------------------------------
do
	local all = ns.CompanionAllAppearances
	function ns:CompanionAllAppearances(...)
		local list = all(self, ...)
		if not Season() then return list end
		local out = {}
		for _, def in ipairs(ns.WINTER_COMPANIONS) do out[#out + 1] = def end
		for _, def in ipairs(list) do out[#out + 1] = def end
		return out
	end
	local byId = ns.CompanionAppearanceDef
	function ns:CompanionAppearanceDef(id, ...)
		if BY_ID[id or ""] then return Season() and BY_ID[id] or nil end
		return byId(self, id, ...)
	end
	local current = ns.CompanionCurrentAppearance
	function ns:CompanionCurrentAppearance(...)
		return Pick(self) or current(self, ...)
	end
	-- Choisir un compagnon de saison : l'apparence habituelle reste en place ;
	-- choisir une apparence ordinaire le renvoie
	local set = ns.CompanionSetAppearance
	function ns:CompanionSetAppearance(id, ...)
		local def = BY_ID[id or ""]
		local winter = WData(self)
		if not def then
			local was = winter.pick
			winter.pick = nil
			local result = set(self, id, ...)
			if not result then winter.pick = was end
			return result
		end
		if not Season() then return nil end
		local was = winter.pick
		winter.pick = def.seasonal
		self:CompanionApplyModel()
		if self.CompanionEffectsSync then pcall(self.CompanionEffectsSync, self) end
		if self.EffectPlatesRefresh then pcall(self.EffectPlatesRefresh, self) end
		if self.RefreshOptions then pcall(self.RefreshOptions, self) end
		if was ~= def.seasonal then
			self:CompanionSay("HELLO", { force = true, args = { self:CompanionName() } })
			-- la hotte : le cadeau du jour, s'il n'a pas encore été donné
			self:WinterSackCheck()
		end
		return def
	end
	local name = ns.CompanionName
	function ns:CompanionName(...)
		local def = Pick(self)
		if def then return L[def.label] end
		return name(self, ...)
	end
	-- les animations qu'il ne joue pas : retenues sous sa propre clé
	local animOff = ns.CompanionAnimOff
	if animOff then
		function ns:CompanionAnimOff(...)
			local def = Pick(self)
			if not def then return animOff(self, ...) end
			local data = self:CompanionData()
			if type(data.animOff) ~= "table" then data.animOff = {} end
			if type(data.animOff[def.id]) ~= "table" then data.animOff[def.id] = {} end
			return data.animOff[def.id]
		end
	end
end

-- ---------------------------------------------------------------------------
-- Voix : la sienne à la place de celle du type de créature
-- ---------------------------------------------------------------------------
do
	local names = {}
	local function VoiceName(base, key)
		local row = names[key]
		if not row then row = {}; names[key] = row end
		local name = row[base]
		if not name then name = base .. "_V_" .. key; row[base] = name end
		return name
	end
	ns.WinterVoiceName = VoiceName
	local pick = ns.CompanionVoicePick or ns.CompanionPick
	function ns:CompanionVoicePick(pool, args, ...)
		local def = Pick(self)
		if not def then return pick(self, pool, args, ...) end
		local base = VOICE_OF[pool]
		if base then
			local name = VoiceName(base, def.seasonal)
			local pools = ns.COMPANION_POOLS
			-- une situation qu'aucun réservoir commun ne couvre (caresse, envie…) : toujours la voix
			if pools[name] and (not pools[pool] or math.random() < ns.WINTER_VOICE_SHARE) then
				local key = self:CompanionPick(name, args)
				if key then return key end
			end
		end
		return self:CompanionPick(pool, args)
	end
	-- caresse : une réplique à lui, pas une conversation de mascotte
	local convo = ns.CompanionStartConvo
	function ns:CompanionStartConvo(...)
		if Pick(self) then return (self:CompanionSay("PET", { force = true })) end
		return convo(self, ...)
	end
end

-- ---------------------------------------------------------------------------
-- Particularités
-- ---------------------------------------------------------------------------
-- Grand-père Hiver, « La hotte » : un cadeau par jour (friandise ou aide de
-- capture, l'autre si la première est pleine). Rend le libellé donné.
function ns:WinterSackCheck()
	if not ModuleOn() then return nil end
	local def = Pick(self)
	if not def or def.seasonal ~= "gfw" then return nil end
	local winter = WData(self)
	local today = Today()
	if not today or winter.sackDay == today then return nil end
	local label
	local function Treat()
		if not (self.TreatGrant and self.TreatRandom) then return nil end
		local kind = self:TreatRandom()
		if kind and self:TreatGrant(kind, { quiet = true }) then return self:TreatLabel(kind) end
		return nil
	end
	local function Aid()
		if not self.CaptureGrant then return nil end
		local result, id = self:CaptureGrant("draw", { quiet = true, silent = true })
		if result == "ok" then return self:CaptureAidLabel(id) end
		return nil
	end
	if math.random() < ns.WINTER_SACK_TREAT then label = Treat() or Aid() else label = Aid() or Treat() end
	if not label then return nil end
	winter.sackDay = today
	self:Print(self:F("WINTER_MSG_SACK", label))
	self:CompanionSay("WINTER_SACK", { force = true, category = "event", args = { label } })
	return label
end

-- Metzen, « Le nez qui brille » : la nuit (heure du jeu)
function ns:WinterNight()
	local hour = tonumber((Call(G("GetGameTime"))))
	if not hour then return false end
	return hour >= ns.WINTER_NIGHT_FROM or hour < ns.WINTER_NIGHT_TO
end
do
	local bonus = ns.CompanionCaptureBonus
	if bonus then
		function ns:CompanionCaptureBonus(info, ...)
			local value = tonumber(bonus(self, info, ...)) or 0
			local found = self.CompanionEffectActive and self:CompanionEffectActive("nightCapture")
			if found and self:WinterNight() then value = value + found[1].value end
			return value
		end
	end
end

-- Bonhomme de neige, « Il aime le froid » : "cold", "hot" ou nil
function ns:WinterZoneTemp()
	local mapID = self.CurrentMap and self:CurrentMap()
	if not mapID then return nil end
	if ns.WINTER_COLD_MAPS[mapID] then return "cold" end
	if ns.WINTER_HOT_MAPS[mapID] then return "hot" end
	return nil
end
do
	local decay = ns.CompanionDecayFactor
	function ns:CompanionDecayFactor(key, ...)
		local factor = decay and decay(self, key, ...) or 1
		local found = self.CompanionEffectActive and self:CompanionEffectActive("cold")
		if not found then return factor end
		local temp = self:WinterZoneTemp()
		if temp == "cold" then
			factor = factor * (1 - found[1].value)
		elseif temp == "hot" and key == "mood" then
			factor = factor * ns.WINTER_MELT   -- il fond
		end
		return factor
	end
	-- un mot en entrant dans le froid ou la chaleur (seulement au changement)
	local onZone = ns.CompanionOnZone
	function ns:CompanionOnZone(newArea, ...)
		local result = onZone(self, newArea, ...)
		if newArea then
			local def = Pick(self)
			local temp = def and def.seasonal == "snowman" and self:WinterZoneTemp() or nil
			if temp and temp ~= self.winterTemp then
				self:CompanionSay(temp == "hot" and "WINTER_HOT" or "WINTER_COLD", { force = true })
			end
			self.winterTemp = temp
		end
		return result
	end
end

-- ---------------------------------------------------------------------------
-- Haut fait « Joyeux Voile d'hiver » : une heure ou 10 captures avec lui
-- ---------------------------------------------------------------------------
local function FeatProgress(self, field, amount)
	local winter = WData(self)
	winter[field] = (tonumber(winter[field]) or 0) + (tonumber(amount) or 0)
	if winter.feat then return false end
	if (tonumber(winter.time) or 0) >= ns.WINTER_FEAT_TIME or (tonumber(winter.caps) or 0) >= ns.WINTER_FEAT_CAPTURES then
		winter.feat = true
		if self.FeatFlag then pcall(self.FeatFlag, self, "winterVeil", "account") end
		return true
	end
	return false
end
do
	local tick = ns.CompanionTick
	function ns:CompanionTick(seconds, ...)
		local result = tick(self, seconds, ...)
		if ModuleOn() and (tonumber(seconds) or 0) > 0 and Pick(self) then FeatProgress(self, "time", seconds) end
		return result
	end
	local resolve = ns.CaptureResolve
	if resolve then
		function ns:CaptureResolve(rolling, ...)
			local result = resolve(self, rolling, ...)
			if type(rolling) == "table" and rolling.success and Pick(self) then
				local ok, err = pcall(FeatProgress, self, "caps", 1)
				if not ok and self.RecordError then self:RecordError("winter:feat", err) end
			end
			return result
		end
	end
end

-- ---------------------------------------------------------------------------
-- Fin de saison : le compagnon de saison repart (un mot, une fois)
-- ---------------------------------------------------------------------------
function ns:WinterCompanionsCheck()
	local winter = self.CompanionData and self:CompanionData().winter
	local key = type(winter) == "table" and winter.pick
	if not key then return false end
	if BY_KEY[key] and Season() then return false end
	winter.pick = nil
	self:CompanionApplyModel()
	if self.CompanionEffectsSync then pcall(self.CompanionEffectsSync, self) end
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	local def = BY_KEY[key]
	if def then
		self:Print(self:F("WINTER_MSG_BYE", L[def.label]))
		self:CompanionSay("WINTER_BYE_" .. key, { force = true, category = "event" })
	end
	return true
end

-- Connexion : saison relue, au revoir s'il le faut, la hotte du jour
function ns:WinterCompanionsLogin()
	if not ModuleOn() then return nil end
	self:WinterCompanionsForget()
	self:WinterCompanionsCheck()
	return self:WinterSackCheck()
end
do
	local login = ns.CompanionLogin
	function ns:CompanionLogin(...)
		local result = login(self, ...)
		-- après l'écran de chargement et le bonjour
		if ns.Soon then
			ns.Soon("winterCompanions:login", ns.WINTER_LOGIN_DELAY, function()
				local ok, err = pcall(ns.WinterCompanionsLogin, ns)
				if not ok and ns.RecordError then ns:RecordError("winter:login", err) end
			end)
		else
			self:WinterCompanionsLogin()
		end
		return result
	end
end

-- ---------------------------------------------------------------------------
-- Visite surprise de Grand-père Hiver
-- ---------------------------------------------------------------------------
-- Prête maintenant ? true, ou false + raison
function ns:WinterVisitReady()
	if self.winterVisited then return false, "done" end
	if not ModuleOn() then return false, "off" end
	if self:DB().companionWinterVisit == false then return false, "setting" end
	if not Season() then return false, "season" end
	local def = Pick(self)
	if def and def.seasonal == "gfw" then return false, "here" end   -- il voyage déjà avec toi
	if InCombat() then return false, "combat" end
	if self.InInstance and self:InInstance() then return false, "instance" end
	return true
end

local function VisitUpdate(frame, elapsed)
	frame.age = frame.age + (tonumber(elapsed) or 0)
	local age, total, fade = frame.age, ns.WINTER_VISIT_TIME, ns.WINTER_VISIT_FADE
	if age >= total or InCombat() then ns:WinterVisitHide(); return end
	local alpha = 1
	if age < fade then alpha = age / fade elseif age > total - fade then alpha = (total - age) / fade end
	if alpha ~= frame.shownAlpha then
		frame.shownAlpha = alpha
		frame:SetAlpha(alpha)
		frame.bubble:SetAlpha(alpha)
		if frame.model and ns.ModelSetAlpha then ns.ModelSetAlpha(frame.model, alpha) end
	end
end

function ns:EnsureWinterVisit()
	if self.winterVisitFrame then return self.winterVisitFrame end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
	if not ok or not frame then return nil end
	local point = ns.WINTER_VISIT_POINT
	frame:SetSize(ns.WINTER_VISIT_W, ns.WINTER_VISIT_H)
	frame:SetPoint(point[1], UIParent, point[1], point[2], point[3])
	frame:SetFrameStrata("HIGH")
	if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
	local okModel, model = pcall(CreateFrame, "PlayerModel", nil, frame)
	if okModel and model then
		model:SetAllPoints()
		frame.model = model
	end
	frame.bubble = Theme.CreateBubble and Theme.CreateBubble(UIParent, ns.WINTER_VISIT_BUBBLE_W, { strata = "HIGH" })
	if not frame.bubble then return nil end
	frame.bubble:SetPoint("BOTTOM", frame, "TOP", 0, 6)
	frame.bubble:Hide()
	-- un clic le renvoie
	frame:EnableMouse(true)
	frame:SetScript("OnMouseUp", function() ns:WinterVisitHide() end)
	frame:Hide()
	self.winterVisitFrame = frame
	return frame
end

function ns:WinterVisitShow()
	local frame = self:EnsureWinterVisit()
	if not frame then return false end
	local key = self:CompanionPick("WINTER_VISIT")
	if not key then return false end
	self.winterVisited = true
	frame.bubble:SetText(L[key], 0)
	if frame.model then
		ns.ShowModel(frame.model, { npc = ns.WINTER_VISIT_NPC, cam = ns.WINTER_VISIT_CAM }, "prompt")
	end
	frame.age, frame.shownAlpha = 0, nil
	frame:SetAlpha(0)
	frame.bubble:SetAlpha(0)
	frame:Show()
	frame.bubble:Show()
	-- fondu image par image, seulement pendant la visite
	frame:SetScript("OnUpdate", VisitUpdate)
	return true
end

function ns:WinterVisitHide()
	local frame = self.winterVisitFrame
	if not frame then return end
	frame:SetScript("OnUpdate", nil)
	frame:Hide()
	frame.bubble:Hide()
	if frame.model and ns.ModelSetAlpha then ns.ModelSetAlpha(frame.model, 1) end
end

function ns:WinterVisitTick()
	if self.winterVisited then return false end
	local now = Clock()
	if not self.winterVisitAt then
		local delay = ns.WINTER_VISIT_DELAY
		self.winterVisitAt = now + math.random(delay[1], delay[2])
	end
	if now < self.winterVisitAt then return false end
	if not self:WinterVisitReady() then return false end
	return self:WinterVisitShow()
end

-- ---------------------------------------------------------------------------
-- Réglage, horloge
-- ---------------------------------------------------------------------------
ns.RegisterDefaults({ companionWinterVisit = true })
for _, page in ipairs(ns.OPTION_PAGES or {}) do
	if page.id == "companionMain" and type(page.rows) == "table" then
		local after, present
		for index, row in ipairs(page.rows) do
			if row.key == "companionWinterVisit" then present = true end
			if row.key == "companionJokes" or row.key == "companionLore" or row.key == "companionChatter" then
				after = math.max(after or 0, index)
			end
		end
		if not present then
			table.insert(page.rows, (after or #page.rows) + 1, { key = "companionWinterVisit", label = "OPT_COMP_WINTER_VISIT",
				kind = "bool", describe = function() return L.OPT_COMP_WINTER_VISIT_DESC end })
		end
	end
end

ns.Every("winterCompanions", ns.WINTER_TICK, function()
	if not ModuleOn() then return end
	local ok, err = pcall(ns.WinterCompanionsCheck, ns)
	if ok then ok, err = pcall(ns.WinterVisitTick, ns) end
	if not ok and ns.RecordError then ns:RecordError("winter:tick", err) end
end)

if ns.Mark then ns.Mark("WinterCompanions") end
