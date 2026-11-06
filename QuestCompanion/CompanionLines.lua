-- CompanionLines.lua -- répliques du « Compagnon de route » (v1.25.0)
--
-- Données seules : toutes les bulles, rangées par situation (« réservoir »).
-- Companion.lua en tire une au hasard, sans répéter les dernières, et décide
-- QUAND parler (priorités, écarts, pauses par catégorie). Ici, on ne décide
-- que QUOI dire.
--
-- Ton : tutoiement, chaleureux, court (une bulle fait ~190 px de large), un
-- peu drôle, volontiers taquin (il se moque gentiment de tes chutes, de tes
-- détours, de tes sacs pleins de gris), jamais méchant ni culpabilisant.
-- Textes originaux.
--
-- Chaque réservoir est une liste de paires { français, anglais }. La clé de
-- la ligne n vaut COMP_SAY_<RÉSERVOIR> pour n = 1, COMP_SAY_<RÉSERVOIR>_<n>
-- ensuite : la première ligne garde ainsi le nom qu'elle avait avant les
-- réservoirs (« COMP_SAY_VIEW » = « Quelle vue ! »).
--
-- Arguments : un réservoir dont les lignes ont un « %s » / « %d » reçoit
-- toujours ses arguments (STAMP, LEVEL…), SAUF les avis sur les PNJ : là, le
-- nom du PNJ peut manquer, et les lignes à « %s » sont alors écartées.
local ADDON, ns = ...
if ns.blocked then return end

local P = {}

-- ---------------------------------------------------------------------------
-- Accueil, absence, réveil
-- ---------------------------------------------------------------------------
P.HELLO = {   -- %s = nom du compagnon
	{ "Salut ! Moi c'est %s. On part à l'aventure ?", "Hi! I'm %s. Off on an adventure?" },
	{ "Coucou ! %s, à ton service. On va où ?", "Hello! %s, at your service. Where to?" },
	{ "Salut ! Moi c'est %s. Je fais la route, toi tu fais les bêtises.", "Hi! I'm %s. I handle the road, you handle the blunders." },
	{ "%s, présent ! Tu as pensé à prendre ton sens de l'orientation ?", "%s, present! Did you remember to pack your sense of direction?" },
	{ "Coucou, c'est %s ! Promis, je ne compterai pas tes chutes. Enfin…", "Hey, it's %s! I promise not to count your falls. Well…" },
	{ "%s au rapport ! Prêt à te regarder foncer tête baissée.", "%s reporting! Ready to watch you charge in headfirst." },
	{ "Bonjour ! %s, compagnon, garde du corps et témoin de tes exploits.", "Hello! %s: companion, bodyguard and witness to your exploits." },
}
P.MISSED = {
	{ "Tu m'as manqué ! Zzz… je me réveille doucement.", "I missed you! Zzz… waking up slowly." },
	{ "Te revoilà ! J'ai gardé ta place au chaud… zzz.", "You're back! I kept your spot warm… zzz." },
	{ "Oh, c'est toi ! Je rêvais de toi. Enfin… de goûter.", "Oh, it's you! I was dreaming of you. Well… of snacks." },
	{ "Ah, te voilà ! J'ai cru que tu t'étais perdu en allant au marchand.", "Ah, there you are! Thought you got lost on the way to the vendor." },
	{ "Enfin ! J'ai eu le temps de compter tous les cailloux. Deux fois.", "Finally! I had time to count every pebble. Twice." },
	{ "Tu étais où ? Non, laisse, je préfère imaginer une grande aventure.", "Where were you? No, don't tell me, I'll imagine an epic quest." },
	{ "Te revoilà ! Moi ? Non, je n'ai pas pleuré. Un peu bâillé, c'est tout.", "You're back! Me? No, I didn't cry. Just yawned a bit." },
	{ "Zzz… oh ! Déjà ? J'avais commencé un très beau rêve sans monstres.", "Zzz… oh! Already? I'd started a lovely dream with no monsters." },
}
P.AWAKE = {
	{ "Me revoilà en pleine forme !", "Wide awake again!" },
	{ "Bon, je suis réveillé. Presque. Oui. Allons-y !", "Right, I'm awake. Mostly. Yes. Let's go!" },
	{ "Tout frais, tout pimpant !", "Fresh as a daisy!" },
	{ "Debout, debout ! Enfin, moi. Toi, tu l'étais déjà.", "Rise and shine! Well, me. You already were." },
	{ "Réveillé ! Qu'est-ce que j'ai raté ? Rien ? Parfait.", "Awake! What did I miss? Nothing? Perfect." },
	{ "J'ai les oreilles toutes froissées, mais je suis prêt.", "My ears are all crumpled, but I'm ready." },
	{ "Bon, qui a besoin d'être surveillé ? Ah oui. Toi.", "Right, who needs keeping an eye on? Oh yes. You." },
}
P.PET_sleepy = {
	{ "Hein ? Oh, c'est toi ! Bonjour !", "Huh? Oh, it's you! Hello!" },
	{ "Mmh… cinq minutes encore… non, je suis debout !", "Mmh… five more minutes… no, I'm up!" },
	{ "Oh ! Un câlin pour me réveiller, le luxe.", "Oh! A wake-up cuddle, what luxury." },
	{ "Hein ? J'ai dormi longtemps ? Tu t'es perdu combien de fois ?", "Huh? Did I sleep long? How many times did you get lost?" },
	{ "Mmh… tu me réveilles pour un câlin ? Bon, ça vaut le coup.", "Mmh… you woke me for a cuddle? Fine, worth it." },
	{ "Zzz… quoi ? On se bat ? Non ? Alors je me rendors… non, je suis là !", "Zzz… what? A fight? No? Then back to… no, I'm up!" },
	{ "Oh, c'est toi. Je rêvais que tu trouvais le bon chemin du premier coup.", "Oh, it's you. I dreamt you found the right path first try." },
}

-- ---------------------------------------------------------------------------
-- Départ et retour (module Check avant le départ)
-- ---------------------------------------------------------------------------
P.NOFOOD = {
	{ "On part sans rien à grignoter ? Pense à moi au prochain marchand !", "Leaving without a snack? Think of me at the next vendor!" },
	{ "Tes sacs sentent… rien. Un casse-croûte au prochain marchand ?", "Your bags smell of… nothing. A snack at the next vendor?" },
	{ "Pas de vivres ? Bon, je chasserai les miettes.", "No food? Fine, I'll hunt for crumbs." },
	{ "Je dis ça pour toi : un peu de pain, ça aide en route.", "Just saying: a bit of bread helps on the road." },
	{ "Zéro vivre dans les sacs ? Tu comptes manger des pissenlits ?", "Zero food in your bags? Planning to eat dandelions?" },
	{ "Tes sacs sont pleins de gris, mais pas d'un bout de pain. Priorités !", "Bags full of grey junk, but not one bit of bread. Priorities!" },
	{ "On part le ventre vide ? Je te préviens : je râle quand j'ai faim.", "Leaving on an empty stomach? Fair warning: I grumble when hungry." },
	{ "Un aventurier sans casse-croûte, c'est un aventurier qui s'assoit souvent.", "An adventurer with no snacks is an adventurer who sits down a lot." },
}
P.DEPART = {
	{ "En route ! J'ai vu le goûter dans ton sac.", "Off we go! I saw the snacks in your bag." },
	{ "Cap sur l'aventure ! Je passe devant… non, toi d'abord.", "Adventure ahoy! I'll lead… no, you first." },
	{ "Sacs prêts, cœur léger : on y va !", "Bags ready, heart light: let's go!" },
	{ "J'adore ce moment où on quitte la ville.", "I love the moment we leave town." },
	{ "En route ! J'ai déjà hâte de voir ce qu'il y a là-bas.", "On our way! Can't wait to see what's out there." },
	{ "En route ! Essaie de revenir avec autant de vies qu'au départ.", "Off we go! Try to come back with as many lives as you left with." },
	{ "Allez, on sort ! Et cette fois, on regarde la carte, d'accord ?", "Let's head out! And this time, we look at the map, OK?" },
	{ "C'est parti ! Je parie sur ton premier mort avant la colline.", "Here we go! I'm betting on your first death before the hill." },
	{ "On y va ! Moi devant, toi derrière… ah non, c'est toi qui tapes.", "Let's go! Me in front, you behind… oh wait, you do the hitting." },
	{ "Départ ! J'ai prévenu le cimetière, il garde ta place au chaud.", "Departure! I warned the graveyard, they're keeping your spot warm." },
	{ "Sacs bouclés, bottes lacées… et ton casque à l'endroit ? Presque.", "Bags packed, boots laced… helmet on the right way? Almost." },
	{ "En avant ! Le monde est grand, et tu sais te perdre partout.", "Onward! The world is big, and you can get lost anywhere." },
}
P.RETURN = {
	{ "Ouf, on est rentrés ! Bien joué.", "Phew, we're back! Well done." },
	{ "Retour au bercail ! On a bien mérité une pause.", "Home sweet home! We've earned a break." },
	{ "On est rentrés entiers. Enfin, toi surtout.", "Back in one piece. You, mostly." },
	{ "Ah, la civilisation ! Et ses marchands.", "Ah, civilisation! And its vendors." },
	{ "De retour ! Et tu n'es mort qu'un peu. Progrès.", "Back again! And you only died a little. Progress." },
	{ "Ah, la ville ! Tu vas encore vendre tes cailloux gris ?", "Ah, town! Off to sell your grey pebbles again?" },
	{ "On est rentrés ! J'ai cru qu'on n'y arriverait jamais avec tes détours.", "We're back! Thought we'd never make it with all your detours." },
	{ "Retour en ville. Range ce sanglier mort, ça ne se fait pas ici.", "Back in town. Put that dead boar away, it's not done here." },
	{ "Enfin rentrés ! Un bain, un repas, et on oublie ta dernière chute.", "Home at last! A bath, a meal, and we forget your last fall." },
	{ "La civilisation ! Tâche de ne pas te perdre entre la banque et l'auberge.", "Civilisation! Try not to get lost between the bank and the inn." },
	{ "Bien joué, on est rentrés. Je ne dirai rien de la partie au cimetière.", "Well done, we're home. I won't mention the graveyard bit." },
}

-- ---------------------------------------------------------------------------
-- Combat, mort, résurrection
-- ---------------------------------------------------------------------------
P.KILL = {
	{ "Bien joué ! Il ne l'a pas vu venir.", "Nice one! Didn't see that coming." },
	{ "Et un de moins ! Je t'encourageais très fort.", "One less! I was cheering really hard." },
	{ "Paf ! Quelle technique.", "Bam! What technique." },
	{ "Je l'aurais eu aussi… peut-être… un jour.", "I'd have got it too… maybe… someday." },
	{ "Propre et net. Tu as déjà fait ça ?", "Clean and tidy. Done this before?" },
	{ "Bravo ! Je me cache les yeux pour le prochain.", "Bravo! I'll cover my eyes for the next one." },
	{ "Ouf, c'est fini. Tu n'as rien ?", "Phew, it's over. You alright?" },
	{ "Souffle un instant avant le suivant.", "Take a breath before the next one." },
	{ "Tu m'impressionnes à chaque fois.", "You impress me every time." },
	{ "Et il est tombé ! Lui. Pas toi. Pour une fois.", "And down it goes! It. Not you. For once." },
	{ "Joli ! Tu as tapé assez fort pour qu'il ait pitié de toi.", "Nice! You hit hard enough that it took pity on you." },
	{ "Victoire ! Tu peux arrêter de taper, il ne bouge plus.", "Victory! You can stop hitting it, it's not moving." },
	{ "Bravo ! Et tu ne t'es même pas pris les pieds dans ta cape.", "Bravo! And you didn't even trip over your cloak." },
	{ "Un de moins ! Il en reste environ… tous les autres.", "One down! Only about… all the others left." },
	{ "Ce n'était pas un lapin, au moins ? Ouf, non.", "That wasn't a bunny, was it? Phew, no." },
	{ "Bien visé ! Ou bien visé à côté et il s'est jeté dessus.", "Good aim! Or you missed and it walked into it." },
	{ "Il a tenu longtemps… tu tapes avec une cuillère ?", "It lasted a while… are you hitting with a spoon?" },
	{ "Gagné ! Je l'avais affaibli en le regardant méchamment.", "Won! I'd softened it up with a mean stare." },
	{ "Pfiou ! Tu as transpiré pour lui ? Il n'était pas bien gros.", "Phew! You sweated over that one? It wasn't very big." },
	{ "Bien joué ! Je note ça dans la colonne « réussites ». Elle est courte.", "Well done! Noting that in the \"successes\" column. It's short." },
	{ "Et voilà ! Tu fais peur… à ceux de ton niveau.", "There you go! You're terrifying… to things your level." },
	{ "Repos, soldat. Enfin, deux secondes, il y en a un autre derrière.", "At ease, soldier. Well, two seconds, there's another behind." },
	{ "Rapide et propre ! Bon, rapide. Propre, on repassera.", "Quick and clean! Well, quick. Clean, not so much." },
}
P.DEAD = {
	{ "Aïe… Je t'attends, prends ton temps.", "Ouch… I'll wait for you, take your time." },
	{ "Oups. Je garde ton sac, promis.", "Oops. I'll guard your bag, promise." },
	{ "Ça arrive aux meilleurs. Je reste ici.", "Happens to the best of us. I'll stay right here." },
	{ "Respire… enfin, quand tu pourras. Je suis là.", "Breathe… well, when you can. I'm here." },
	{ "On retentera, ensemble. Pas de souci.", "We'll try again, together. No worries." },
	{ "Et paf, par terre. Je t'attends ici, je ne bouge pas, je ne juge pas.", "And splat, on the floor. I'll wait here, not moving, not judging." },
	{ "Mort ? Encore ? Je commence à connaître le chemin du cimetière.", "Dead? Again? I'm starting to know the way to the graveyard." },
	{ "Tu as choisi un joli coin pour tomber, au moins.", "At least you picked a nice spot to fall." },
	{ "Le sol avait l'air confortable ? Je demande pour moi.", "Did the ground look comfy? Asking for myself." },
	{ "Bon. On va dire que c'était une tactique.", "Right. Let's call that a tactic." },
	{ "Ne t'en fais pas, je n'ai rien vu. Sauf tout.", "Don't worry, I saw nothing. Except everything." },
	{ "Petite course jusqu'au cimetière ? Ça entretient les mollets.", "Little jog to the graveyard? Good for the calves." },
	{ "Aïe. Le monstre, lui, a l'air très content de lui.", "Ouch. The monster looks very pleased with itself." },
	{ "Tu fais une sieste ? Non ? Ah. D'accord. Je garde le sac.", "Taking a nap? No? Ah. Right. I'll mind the bag." },
	{ "Ça arrive ! Surtout à toi, mais ça arrive.", "It happens! Mostly to you, but it happens." },
}
P.REZ = {
	{ "Te revoilà ! Tu m'as fait une de ces peurs.", "You're back! You gave me quite a scare." },
	{ "Debout ! On reprend là où on en était ?", "Up you get! Pick up where we left off?" },
	{ "Bon retour parmi les vivants !", "Welcome back to the living!" },
	{ "Ouf. Je savais que tu reviendrais.", "Phew. I knew you'd come back." },
	{ "On souffle un coup et on repart ?", "Catch your breath and off again?" },
	{ "Te revoilà ! Alors, ce petit jogging fantôme ?", "You're back! So, how was the ghostly jog?" },
	{ "Bon retour ! Tu as l'air un peu… pâlichon. Normal.", "Welcome back! You look a bit… peaky. Fair enough." },
	{ "Revenu ! On évite le même monstre, cette fois ?", "Back! Shall we avoid the same monster this time?" },
	{ "Debout ! Ton équipement a pris un coup, ton ego aussi.", "Up you get! Your gear took a hit, and so did your ego." },
	{ "Ressuscité ! Si tu meurs encore, je demande une carte de fidélité au cimetière.", "Revived! Die again and I'm asking the graveyard for a loyalty card." },
	{ "Ah, te voilà ! J'ai gardé ton sac. Et ta dignité, un peu.", "Ah, there you are! I kept your bag. And a bit of your dignity." },
	{ "Retour parmi nous ! Le monstre est toujours là, je préviens.", "Back among us! The monster's still there, just saying." },
	{ "Tu as couru vite, pour un fantôme ! Tu devrais courir comme ça vivant.", "You ran fast for a ghost! You should run like that alive." },
	{ "Te revoilà entier ! Bon, entier et un peu cabossé.", "Back in one piece! Well, one piece and a bit dented." },
	{ "On reprend ? Et on respire avant de foncer, cette fois.", "Shall we resume? And breathe before charging in this time." },
}

-- ---------------------------------------------------------------------------
-- Progrès : niveau, évolution, quête, butin, carnet
-- ---------------------------------------------------------------------------
P.LEVEL = {   -- %d = niveau
	{ "Niveau %d ! Bravo, toi !", "Level %d! Go you!" },
	{ "Niveau %d ! Je l'ai senti passer, celui-là !", "Level %d! I felt that one!" },
	{ "Niveau %d ! Tu deviens une vraie légende.", "Level %d! You're becoming a real legend." },
	{ "Ding ! Niveau %d. Petite danse ?", "Ding! Level %d. Little dance?" },
	{ "Niveau %d, et toujours aussi modeste.", "Level %d, and still so humble." },
	{ "Niveau %d ! Je le note dans mon cœur.", "Level %d! Writing that down in my heart." },
	{ "Niveau %d ! Il en a fallu, des sangliers.", "Level %d! It took a lot of boars." },
	{ "Niveau %d ! Tu brilles ! Ah non, c'est l'effet visuel.", "Level %d! You're glowing! Oh no, that's just the effect." },
	{ "Niveau %d ! Toujours aussi perdu, mais plus fort.", "Level %d! Still just as lost, but stronger." },
	{ "Niveau %d ! Les loups du coin n'ont qu'à bien se tenir. Les petits.", "Level %d! The local wolves had better watch out. The small ones." },
	{ "Niveau %d ! Va voir ton maître, avant d'oublier comme la dernière fois.", "Level %d! Visit your trainer before you forget like last time." },
	{ "Ding, niveau %d ! Je savais que tu y arriverais. Un jour. Aujourd'hui !", "Ding, level %d! Knew you'd get there. Someday. Today!" },
	{ "Niveau %d ! Tu tiendras deux coups de plus avant de tomber.", "Level %d! You'll take two more hits before falling over." },
	{ "Niveau %d ! Ça mérite une petite danse. Pas la tienne, la mienne.", "Level %d! That calls for a little dance. Not yours, mine." },
}
P.READY = {   -- %s = nom du prochain stade
	{ "Je me sens prêt à devenir %s… il me faut juste être bien.", "I feel ready to become %s… I just need to feel good." },
	{ "Ça me chatouille partout : bientôt %s ! Prends soin de moi ?", "Everything tingles: soon %s! Take care of me?" },
	{ "Je peux devenir %s ! Un bon repas, du repos, un peu d'aventure…", "I can become %s! A good meal, some rest, a bit of adventure…" },
	{ "Je pourrais devenir %s… si tu arrêtes de me trimballer au cimetière.", "I could become %s… if you stop dragging me to the graveyard." },
	{ "Bientôt %s ! Il me faut juste un peu d'attention. Beaucoup, même.", "Soon %s! I just need a bit of attention. A lot, actually." },
	{ "Je sens %s pointer le bout de son nez. Nourris-moi, chouchoute-moi !", "I can feel %s coming. Feed me, pamper me!" },
}
P.CHEST = {   -- %s = nom de la zone
	{ "On a tout vu de %s ! Un coffre pour toi… pour nous !", "We've seen all of %s! A chest for you… for us!" },
	{ "%s, terminé ! Ouvre le coffre, je veux voir !", "%s, done! Open the chest, I want to see!" },
	{ "Tout %s dans le carnet. On a bien mérité un coffre.", "All of %s in the journal. We've earned a chest." },
	{ "%s, bouclé ! Même les recoins où tu t'étais perdu.", "%s, wrapped up! Even the corners where you got lost." },
	{ "Tout %s visité ! Je n'y croyais plus. Ouvre vite ce coffre !", "All of %s seen! I'd given up hope. Open that chest, quick!" },
	{ "%s à 100 %% ! Un coffre, et pas un seul détour inutile. Enfin, si, plein.", "%s at 100%%! A chest, and not one useless detour. Well, lots." },
}
P.EVOLVE = {  -- %s = nom du stade
	{ "Je grandis ! Me voilà %s !", "I'm growing! Now I'm %s!" },
	{ "Regarde-moi ! Je deviens %s !", "Look at me! I'm becoming %s!" },
	{ "Ça pousse ! Me voilà %s, grâce à toi.", "Growing up! Now I'm %s, thanks to you." },
	{ "Nouveau moi : %s ! Je me trouve très beau.", "New me: %s! I look rather dashing." },
	{ "Me voilà %s ! Toi, tu n'as pas changé. C'est mignon.", "Now I'm %s! You haven't changed. It's sweet." },
	{ "%s ! Je grandis plus vite que tes compétences en orientation.", "%s! I'm growing faster than your sense of direction." },
	{ "Tadam : %s ! Admire. Prends ton temps.", "Ta-da: %s! Admire. Take your time." },
	{ "Je suis %s ! Je vais pouvoir te porter quand tu tomberas.", "I'm %s! Now I can carry you when you fall." },
}
P.UNLOCK = {  -- %s = cosmétique débloqué
	{ "Regarde : %s !", "Look: %s!" },
	{ "Pour moi ? %s ! Merci !", "For me? %s! Thank you!" },
	{ "Nouveau : %s ! Je me sens tout chic.", "New: %s! I feel so fancy." },
	{ "%s ! On le montre à tout le monde ?", "%s! Shall we show everyone?" },
	{ "%s ! Enfin un peu de classe dans ce duo.", "%s! Finally some class in this duo." },
	{ "Oh, %s ! Plus chic que ton armure dépareillée.", "Ooh, %s! Fancier than your mismatched armour." },
	{ "%s pour moi ! Les autres compagnons vont être jaloux.", "%s for me! The other companions will be jealous." },
	{ "Débloqué : %s ! Je suis le plus beau, c'est officiel.", "Unlocked: %s! I'm the prettiest, it's official." },
}
P.QUEST = {
	{ "Mission accomplie !", "Mission complete!" },
	{ "Et une de plus ! Quel talent.", "Another one done! Such talent." },
	{ "Quête rendue ! J'espère que la récompense se mange.", "Quest done! I hope the reward is edible." },
	{ "Bravo ! Il te doit une fière chandelle.", "Well done! They owe you big time." },
	{ "Encore un problème réglé grâce à toi.", "One more problem solved, thanks to you." },
	{ "Je l'avais dit : du gâteau !", "Told you: piece of cake!" },
	{ "Une quête rendue, un sourire gagné.", "One quest turned in, one smile earned." },
	{ "Quête rendue ! Il t'a fallu trois allers-retours, mais quand même.", "Quest done! Took you three round trips, but still." },
	{ "Bravo ! Encore un villageois qui ne fera plus rien lui-même.", "Well done! Another villager who'll never do anything himself." },
	{ "Mission accomplie ! Tu as même trouvé le bon PNJ du premier coup.", "Mission complete! You even found the right NPC first try." },
	{ "Et voilà ! Dix peaux de loup pour un bonhomme qui en voulait dix. Logique.", "There! Ten wolf pelts for a guy who wanted ten. Makes sense." },
	{ "Quête finie ! La récompense est grise ? Je dis ça, je dis rien.", "Quest done! Is the reward grey? Just saying." },
	{ "Rendue ! Tu as lu le texte, cette fois ? Non ? Moi non plus.", "Turned in! Did you read the text this time? No? Me neither." },
	{ "Bien joué ! Il te remercie, et il a déjà un autre service à te demander.", "Well done! He thanks you, and he already has another favour to ask." },
	{ "Une de plus ! Ton journal de quêtes respire un peu.", "One more! Your quest log can breathe a little." },
	{ "Mission accomplie ! On ne parle pas des deux fois où tu t'es trompé de bête.", "Mission done! We won't mention the two times you killed the wrong beast." },
	{ "Terminé ! Ça valait bien ces six kilomètres à pied.", "Done! Well worth those four miles on foot." },
}
P.LOOT = {
	{ "Oh, ça brille !", "Ooh, shiny!" },
	{ "Ooh, un trésor ! On le garde ?", "Ooh, treasure! Are we keeping it?" },
	{ "Ça, c'est une belle trouvaille !", "Now that's a nice find!" },
	{ "Je savais qu'il cachait quelque chose.", "I knew it was hiding something." },
	{ "Brillant, précieux… presque autant que moi.", "Shiny, precious… almost as much as me." },
	{ "Jolie prise ! Tu as l'œil.", "Nice catch! You've got the eye." },
	{ "Ooh ! Encore un truc gris à trimballer jusqu'au marchand ?", "Ooh! Another grey thing to lug to the vendor?" },
	{ "Une trouvaille ! Tes sacs soupirent déjà.", "A find! Your bags are already sighing." },
	{ "Tu ramasses tout, hein ? Même les dents de rat ?", "You pick up everything, huh? Even rat teeth?" },
	{ "Un butin ! Je parie que ça vaut au moins… trois pièces de cuivre.", "Loot! I bet it's worth at least… three copper." },
	{ "Ça brille ! Ah non, c'est juste propre. Rare, ici.", "Shiny! Oh no, it's just clean. Rare around here." },
	{ "Garde-le ! Ou vends-le. Ou garde-le pour le jeter plus tard, comme d'habitude.", "Keep it! Or sell it. Or keep it to bin later, as usual." },
	{ "Un trésor ! Ton dos va adorer.", "Treasure! Your back is going to love that." },
	{ "Bel objet ! Tu vas le porter, ou le regarder dans ton sac pendant deux mois ?", "Nice item! Wearing it, or staring at it in your bag for two months?" },
	{ "Encore une pièce pour ta collection de choses inutiles !", "Another piece for your collection of useless things!" },
	{ "Ça, c'est du butin ! Les sangliers ont vraiment de tout dans les poches.", "Now that's loot! Boars really keep everything in their pockets." },
}
P.STAMP = {   -- %s = nom du tampon
	{ "Un tampon de plus : %s !", "One more stamp: %s!" },
	{ "Hop, dans le carnet : %s !", "Into the journal it goes: %s!" },
	{ "%s : tamponné ! Quelle collection.", "%s: stamped! What a collection." },
	{ "Le carnet grossit : %s !", "The journal grows: %s!" },
	{ "Souvenir de voyage : %s.", "Travel memory: %s." },
	{ "%s ! Un tampon, et on ne s'est presque pas perdus pour l'avoir.", "%s! A stamp, and we barely got lost getting it." },
	{ "Tamponné : %s. Ton carnet voyage plus que ton sens de l'orientation.", "Stamped: %s. Your journal travels better than your sense of direction." },
	{ "%s dans le carnet ! Je le colle avec de la confiture, c'est plus joli.", "%s in the journal! I'm sticking it with jam, it's prettier." },
	{ "Clac ! %s. Encore une page de remplie.", "Thunk! %s. Another page filled." },
	{ "%s ! Je dessine un petit toi à côté. Tout petit. Perdu.", "%s! I'm drawing a little you next to it. Tiny. Lost." },
}

-- ---------------------------------------------------------------------------
-- Lieux : zone nouvelle, capitale, village, auberge, feu de camp
-- ---------------------------------------------------------------------------
P.VIEW = {
	{ "Quelle vue !", "What a view!" },
	{ "Oh ! Un endroit tout neuf !", "Ooh! A brand new place!" },
	{ "Je n'étais jamais venu ici. Toi non plus ?", "Never been here before. You neither?" },
	{ "Ça sent l'aventure par ici.", "Smells like adventure around here." },
	{ "Regarde le ciel ! Il n'est pas pareil ici.", "Look at the sky! It's different here." },
	{ "Nouvelle région, nouvelles histoires !", "New region, new stories!" },
	{ "Nouvelle zone ! Tu as une carte ? Tu sais t'en servir ?", "New zone! Got a map? Know how to use it?" },
	{ "Oh, c'est joli ! Essaie de ne pas mourir tout de suite, profite.", "Oh, it's lovely! Try not to die right away, enjoy it." },
	{ "Un nouveau coin ! Les monstres d'ici ne te connaissent pas encore. Chanceux.", "A new spot! The monsters here don't know you yet. Lucky them." },
	{ "Ici, tout est neuf. Même les façons de te perdre.", "Everything's new here. Even the ways to get lost." },
	{ "Nouvelle région ! Je repère le cimetière le plus proche, au cas où.", "New region! I'm spotting the nearest graveyard, just in case." },
	{ "Waouh ! On est arrivés ici exprès, ou par hasard ?", "Wow! Did we come here on purpose, or by accident?" },
	{ "Quel paysage ! Arrête-toi deux secondes, il ne va pas te mordre.", "What scenery! Stop for two seconds, it won't bite." },
	{ "Terre inconnue ! Enfin, pour toi. Moi, j'ai lu le guide.", "Uncharted land! Well, for you. I read the guidebook." },
}
P.CITY = {    -- %s = nom de la capitale (facultatif dans le texte)
	{ "%s ! Que de monde, reste près de moi.", "%s! So many people, stay close." },
	{ "La grande ville ! J'ai peur de me perdre.", "The big city! I might get lost." },
	{ "Ici, il y a tout : maîtres, banque, marchands.", "Everything's here: trainers, bank, vendors." },
	{ "Ça grouille ! Tiens-moi la patte.", "It's bustling! Hold my paw." },
	{ "Bienvenue à %s ! Je fais le guide ? Non, je me perdrais.", "Welcome to %s! Shall I guide? No, I'd get lost." },
	{ "%s ! Tiens-toi droit, il y a du monde qui regarde.", "%s! Stand up straight, people are watching." },
	{ "La capitale ! Ne parle pas aux inconnus. Enfin, si, aux marchands.", "The capital! Don't talk to strangers. Well, except vendors." },
	{ "%s ! On va encore tourner une heure pour trouver la banque.", "%s! We'll spend another hour looking for the bank." },
	{ "Que de monde ! Et ils ont tous une plus belle monture que toi.", "So many people! And they all have nicer mounts than you." },
	{ "Bienvenue à %s. Évite de sauter du pont, ce n'est pas un raccourci.", "Welcome to %s. Don't jump off the bridge, it's not a shortcut." },
	{ "Une grande ville ! Parfait pour vendre tes trésors gris à prix d'or. Non.", "A big city! Perfect for selling your grey treasures for a fortune. No." },
}
P.VILLAGE = { -- %s = nom du village
	{ "Un village ! Ça sent le pain et le foin.", "A village! Smells of bread and hay." },
	{ "%s : coin tranquille, j'aime bien.", "%s: quiet spot, I like it." },
	{ "On souffle un peu ici ? Il y a sûrement une auberge.", "A breather here? Surely there's an inn." },
	{ "Des gens gentils, des maisons… et des quêtes, je parie.", "Kind folk, houses… and quests, I bet." },
	{ "Halte à %s ! Je dis bonjour à tout le monde.", "Stop at %s! I'm saying hi to everyone." },
	{ "%s ! Ici, les gens ont des quêtes plein les poches.", "%s! Folks here have pockets full of quests." },
	{ "Un village ! Dis bonjour, ne tape personne.", "A village! Say hello, don't hit anyone." },
	{ "%s : trois maisons, deux poules et un type qui a perdu quelque chose.", "%s: three houses, two hens and a guy who lost something." },
	{ "Un petit village ! Le genre d'endroit où tu reviens en fantôme.", "A little village! The kind of place you come back to as a ghost." },
	{ "Halte à %s. Profites-en pour vider tes sacs, ça déborde.", "Stop at %s. Empty your bags while you're here, they're overflowing." },
	{ "Un village tranquille. Enfin, jusqu'à ce que tu arrives.", "A quiet village. Well, until you showed up." },
}
P.INN = {
	{ "Une auberge… petite sieste ?", "An inn… little nap?" },
	{ "Ça sent la soupe ! On reste un peu ?", "Smells like soup! Shall we stay a bit?" },
	{ "Un vrai lit ! Je réserve le coin de l'oreiller.", "A real bed! I call the corner of the pillow." },
	{ "Ici, tu gagnes de l'expérience reposée en dormant.", "Here you build rested experience while you sleep." },
	{ "Une auberge : chaud, sec, et plein de gens bavards.", "An inn: warm, dry, and full of chatty folk." },
	{ "Une auberge ! Assieds-toi, tu as couru partout pour rien.", "An inn! Sit down, you ran all over for nothing." },
	{ "Ici, on dort, on mange, et on ne meurt pas. Le paradis.", "Here we sleep, we eat, and we don't die. Paradise." },
	{ "L'auberge ! N'oublie pas de te lier ici, pour une fois.", "The inn! Remember to bind here, for once." },
	{ "Une auberge ! Raconte tes exploits aux clients. Pas les morts, hein.", "An inn! Tell the patrons your exploits. Not the deaths, though." },
	{ "Ah, un lit ! Tu ronfles, je te préviens que je le sais.", "Ah, a bed! You snore, just so you know I know." },
	{ "Une auberge : le seul endroit où tu ne te perds pas.", "An inn: the only place you don't get lost." },
}
P.CAMP = {
	{ "On se réchauffe ?", "Shall we warm up?" },
	{ "Un feu de camp ! Je m'installe tout près.", "A campfire! I'm sitting right up close." },
	{ "Ça crépite… j'adore ce bruit.", "Crackle crackle… love that sound." },
	{ "Une pause au coin du feu, ça te dit ?", "A fireside break, fancy it?" },
	{ "Raconte-moi une histoire au coin du feu !", "Tell me a fireside story!" },
	{ "Un feu ! Assieds-toi, et ne mets pas les pieds dedans.", "A fire! Sit down, and keep your feet out of it." },
	{ "On fait une pause au chaud ? Tu l'as bien méritée. À peu près.", "Warm break? You've earned it. More or less." },
	{ "Le feu crépite. Toi, tu grinces un peu. Repose-toi.", "The fire crackles. You creak a bit. Rest." },
	{ "Un feu de camp : idéal pour sécher après ta chute dans la rivière.", "A campfire: ideal for drying off after your fall in the river." },
	{ "On se pose ? Je surveille, toi tu soupires.", "Shall we sit? I'll keep watch, you sigh." },
	{ "Ah, la chaleur ! Rien de mieux après une journée à courir en rond.", "Ah, warmth! Nothing better after a day running in circles." },
}

-- ---------------------------------------------------------------------------
-- Repas
-- ---------------------------------------------------------------------------
P.EAT = {
	{ "Miam ! Merci pour le partage.", "Yum! Thanks for sharing." },
	{ "Ça sent bon ! Tu m'en gardes une miette ?", "Smells great! Save me a crumb?" },
	{ "Pause casse-croûte ! Ma préférée.", "Snack break! My favourite kind." },
	{ "Mange bien, on a de la route.", "Eat up, we've got miles ahead." },
	{ "Mmh… c'est bon, ce truc ? Ça a l'air bon.", "Mmh… is that tasty? It looks tasty." },
	{ "On mange ensemble, c'est plus joyeux.", "Eating together is more fun." },
	{ "Tu manges assis par terre ? Classe.", "Eating sitting on the ground? Classy." },
	{ "Encore une pause repas ? Tu manges plus que moi !", "Another meal break? You eat more than I do!" },
	{ "Mange, mange. Tu tomberas moins vite.", "Eat, eat. You'll fall over less quickly." },
	{ "Ça croustille ! C'est du pain, ou un vieux biscuit de ton sac ?", "Crunchy! Is that bread, or an old biscuit from your bag?" },
	{ "Prends ton temps, le monstre suivant n'est pas pressé. Moi non plus.", "Take your time, the next monster's in no hurry. Neither am I." },
	{ "Tu as des miettes partout. Je peux les avoir ?", "You've got crumbs everywhere. Can I have them?" },
	{ "Bon appétit ! Ça date de quand, ce fromage ?", "Enjoy! How old is that cheese?" },
	{ "Pause repas ! Je profite pour admirer ton armure… tachée.", "Meal break! Gives me time to admire your armour… stained." },
}
P.DRINK = {
	{ "Glou glou ! L'eau, c'est la vie.", "Glug glug! Water is life." },
	{ "Une petite gorgée, et ça repart !", "A little sip and we're off again!" },
	{ "Tu bois, je te regarde. C'est mon travail.", "You drink, I watch. It's my job." },
	{ "Rafraîchissant ! Garde de l'eau pour la route.", "Refreshing! Keep some water for the road." },
	{ "Glou glou. Tu bois comme un sanglier, tu sais ?", "Glug glug. You drink like a boar, you know?" },
	{ "De l'eau ! Tu étais tout sec, ça se voyait.", "Water! You were all dried up, it showed." },
	{ "Bois doucement, tu vas avoir le hoquet.", "Drink slowly, you'll get hiccups." },
	{ "Une gorgée pour toi, une pour… ah, tu as tout bu.", "A sip for you, one for… oh, you drank it all." },
	{ "Tu refais le plein de mana ? Ou tu fais juste semblant d'être occupé ?", "Topping up mana? Or just pretending to be busy?" },
	{ "Santé ! Enfin, à ta santé. Elle en a besoin.", "Cheers! To your health. It needs it." },
}

-- ---------------------------------------------------------------------------
-- Avis sur les PNJ : par rôle, puis par type de créature
-- (%s = nom du PNJ, lignes écartées si le nom manque)
-- ---------------------------------------------------------------------------
P.NPC_merchant = {
	{ "Ce marchand a l'air honnête… je surveille ta bourse quand même.", "This merchant looks honest… I'll still watch your purse." },
	{ "Tu vends tes gris ? Je compte les pièces !", "Selling the greys? I'll count the coins!" },
	{ "%s a de jolies choses. Tu m'achètes un truc ?", "%s has nice things. Buy me something?" },
	{ "Négocie ! Fais les yeux doux, comme moi.", "Haggle! Do the puppy eyes, like me." },
	{ "Un marchand ! Il a des biscuits, tu crois ?", "A merchant! Think they have biscuits?" },
	{ "%s sourit beaucoup. Trop ? Non, ça va.", "%s smiles a lot. Too much? No, it's fine." },
	{ "Tu vas encore lui vendre tes cailloux gris ?", "Selling them your grey pebbles again?" },
	{ "%s va adorer ta collection de dents de loup.", "%s will love your wolf-tooth collection." },
	{ "Achète quelque chose d'utile. Pour une fois.", "Buy something useful. For once." },
	{ "Tes sacs pleins de bric-à-brac vont enfin servir !", "Your bags full of junk finally pay off!" },
	{ "%s compte tes pièces… ça va être rapide.", "%s is counting your coins… won't take long." },
	{ "Vends tout ce qui est gris, garde-moi le biscuit.", "Sell all the greys, keep me the biscuit." },
	{ "Tu marchandes comme un lapin. Laisse-moi faire.", "You haggle like a bunny. Let me handle it." },
	{ "Un marchand ! Il rachète aussi les fourrures abîmées ? Tu en as plein.", "A merchant! Do they buy ruined furs? You've got loads." },
}
P.NPC_innkeeper = {
	{ "Un aubergiste ! Ça sent le pain chaud.", "An innkeeper! Smells of warm bread." },
	{ "%s a une tête de bon vivant. J'aime bien.", "%s looks like good company. I like them." },
	{ "Tu te lies ici ? C'est un bon coin où revenir.", "Binding here? Nice place to come back to." },
	{ "Demande-lui s'il reste de la soupe !", "Ask if there's any soup left!" },
	{ "Les aubergistes savent tout. Mais ils ne disent rien.", "Innkeepers know everything. They just don't tell." },
	{ "Encore toi ? %s va finir par te garder une chambre.", "You again? %s will start saving you a room." },
	{ "Une soupe pour toi, un coussin pour moi.", "Soup for you, a cushion for me." },
	{ "Lie-toi ici : la prochaine fois que tu tombes, ce sera moins loin.", "Bind here: next time you fall, it's a shorter walk." },
	{ "%s a vu passer bien des héros. Toi aussi, maintenant.", "%s has seen many heroes. And now you." },
	{ "Demande une chambre au calme. Tu ronfles.", "Ask for a quiet room. You snore." },
	{ "Ici, on dort au chaud. Pas par terre près d'un sanglier.", "Here we sleep warm. Not on the ground by a boar." },
	{ "L'aubergiste me fait un clin d'œil. On est copains.", "The innkeeper winked at me. We're mates." },
	{ "%s sert la meilleure soupe du coin. Paraît-il.", "%s serves the best soup around. Supposedly." },
}
P.NPC_trainer = {
	{ "Un maître ! Apprends-moi aussi, je prends des notes.", "A trainer! Teach me too, I'm taking notes." },
	{ "%s a l'air sévère… mais juste.", "%s looks strict… but fair." },
	{ "De nouveaux sorts ? Fais-moi une démonstration !", "New spells? Give me a demo!" },
	{ "Ça coûte cher, le savoir. Mais ça vaut le coup.", "Knowledge is pricey. Worth it, though." },
	{ "Écoute bien, je te ferai réciter après.", "Listen well, I'll quiz you later." },
	{ "Tu as oublié de passer le voir depuis combien de niveaux ?", "How many levels since you last visited?" },
	{ "%s va encore te vider la bourse. Mais pour la bonne cause.", "%s will empty your purse again. For a good cause." },
	{ "Nouveau sort ! Essaie de ne pas te le lancer dessus.", "New spell! Try not to cast it on yourself." },
	{ "Pose-lui des questions. Moi, j'ai trop peur.", "Ask them questions. I'm too scared." },
	{ "%s te regarde comme un élève en retard.", "%s looks at you like a late student." },
	{ "Range bien tes nouveaux sorts dans ta barre, hein.", "Put your new spells on your bar, okay?" },
	{ "Tu vas enfin taper plus fort qu'un lapin furieux ?", "Will you finally hit harder than an angry rabbit?" },
	{ "Un maître ! Je fais semblant de tout comprendre.", "A trainer! I'll pretend I understand everything." },
}
P.NPC_flight = {
	{ "On s'envole ? Je m'accroche à ton sac !", "Flying off? I'm holding on to your bag!" },
	{ "%s s'occupe bien de ses montures, ça se voit.", "%s takes good care of the mounts, you can tell." },
	{ "Vu d'en haut, tout a l'air minuscule. Même toi.", "From up there, everything looks tiny. Even you." },
	{ "Un vol ? J'espère avoir la place près du hublot.", "A flight? Hope I get the window seat." },
	{ "La route du ciel ! Bien plus rapide qu'à pied.", "The sky road! Much faster than walking." },
	{ "Un vol ? Enfin, tes pieds vont se reposer.", "A flight? Your feet finally get a break." },
	{ "%s a vu ton sens de l'orientation. Il recommande le vol.", "%s has seen your sense of direction. Flying is advised." },
	{ "Ne te penche pas, tu as déjà assez de bosses.", "Don't lean out, you've got enough bruises." },
	{ "Pense à apprendre ce point de vol, cette fois.", "Remember to learn this flight path this time." },
	{ "Le vol, c'est le seul moment où tu ne te perds pas.", "Flying is the only time you don't get lost." },
	{ "%s caresse sa monture. Moi aussi, j'aime les caresses.", "%s pets the mount. I like pets too." },
	{ "Attache ta ceinture. Ah, il n'y en a pas. Courage.", "Fasten your seatbelt. Oh, there isn't one. Good luck." },
	{ "Une petite sieste en vol ? Je te réveille à l'arrivée.", "A nap in flight? I'll wake you on arrival." },
}
P.NPC_banker = {
	{ "Un banquier ! Range bien tes trésors.", "A banker! Tuck your treasures away." },
	{ "%s compte vite. Très vite. Trop vite ?", "%s counts fast. Very fast. Too fast?" },
	{ "Dépose ce qui encombre tes sacs, tu respireras.", "Drop off what clutters your bags. Breathe easy." },
	{ "Tout est en sécurité ici. Même mes biscuits ?", "It's all safe here. Even my biscuits?" },
	{ "J'adore la banque : ça sent les vieilles pièces.", "I love the bank: smells of old coins." },
	{ "Tu vas encore déposer des trucs dont tu ne te serviras jamais ?", "Stashing things you'll never use again?" },
	{ "%s connaît tous tes secrets. Surtout tes vieilles bottes.", "%s knows all your secrets. Mostly your old boots." },
	{ "Ta banque, c'est un musée du bric-à-brac.", "Your bank is a museum of junk." },
	{ "Dépose, ne dépose pas… tu hésites depuis dix minutes.", "Deposit, don't deposit… you've hesitated for ten minutes." },
	{ "Un coffre bien rangé, c'est rare. Pas le tien, hein.", "A tidy vault is rare. Not yours, mind." },
	{ "%s fronce les sourcils devant ton bazar.", "%s frowns at your clutter." },
	{ "Range tes compos de métier ici, tes sacs te diront merci.", "Store your crafting mats here, your bags will thank you." },
	{ "Je peux être déposé aussi ? Non ? Ouf.", "Can I be deposited too? No? Phew." },
}
P.NPC_quest = {
	{ "Encore quelqu'un qui a besoin de toi !", "Someone else needs you!" },
	{ "%s a l'air inquiet. On l'aide ?", "%s looks worried. Shall we help?" },
	{ "Une quête ! Dis oui, dis oui !", "A quest! Say yes, say yes!" },
	{ "Lis bien, je n'ai pas compris la moitié.", "Read carefully, I missed half of it." },
	{ "Ça sent l'aventure… et peut-être les sangliers.", "Smells like adventure… and maybe boars." },
	{ "%s compte sur toi. Moi aussi !", "%s is counting on you. So am I!" },
	{ "Encore dix sangliers ? Tu dis oui à tout, toi.", "Ten more boars? You say yes to everything." },
	{ "%s a perdu quelque chose. Comme toujours.", "%s lost something. As usual." },
	{ "Lis l'objectif jusqu'au bout, cette fois.", "Read the objective all the way through this time." },
	{ "%s te fait confiance. Ne le déçois pas trop.", "%s trusts you. Don't let them down too much." },
	{ "Une quête de livraison ! Tes pieds vont adorer.", "A delivery quest! Your feet will love it." },
	{ "Tu l'acceptes, tu l'oublies dans le journal, je connais.", "You accept it, forget it in the log, I know the drill." },
	{ "Ça a l'air simple. C'est jamais simple.", "Looks simple. It's never simple." },
	{ "%s a un point d'exclamation. Moi aussi, quand j'ai faim.", "%s has an exclamation mark. So do I, when I'm hungry." },
}
P.NPC_talk = {
	{ "Quelqu'un de bavard ! J'adore les potins.", "A chatterbox! I love gossip." },
	{ "%s a l'air sympathique. On papote ?", "%s seems nice. Shall we chat?" },
	{ "Demande-lui s'il connaît un bon coin pour goûter.", "Ask if they know a good snack spot." },
	{ "Hmm… je ne sais pas quoi en penser. Je reste poli.", "Hmm… not sure what to think. I'll stay polite." },
	{ "Encore une rencontre ! Le monde est plein de gens.", "Another encounter! The world is full of people." },
	{ "Il parle beaucoup. Toi aussi, quand tu es perdu.", "They talk a lot. So do you when you're lost." },
	{ "%s a des histoires à raconter. Moi, j'ai faim.", "%s has stories to tell. I have hunger." },
	{ "Demande-lui ton chemin, pour changer.", "Ask them for directions, for a change." },
	{ "%s te regarde de haut en bas. Ton armure, sûrement.", "%s looks you up and down. The armour, surely." },
	{ "Souris ! On ne sait jamais, il a peut-être une quête.", "Smile! You never know, they might have a quest." },
	{ "Je hoche la tête. C'est ce que je fais quand je décroche.", "I nod. That's what I do when I zone out." },
	{ "Encore un inconnu. Tu te fais des amis partout, toi.", "Another stranger. You make friends everywhere." },
	{ "%s n'a pas l'air pressé. Le contraire de toi.", "%s isn't in a hurry. Unlike you." },
}
P.NPC_CT_undead = {
	{ "Il sent un peu le caveau, mais il a l'air gentil.", "Smells a bit like a crypt, but seems nice." },
	{ "%s a perdu quelques couleurs… et un peu de peau.", "%s has lost some colour… and a bit of skin." },
	{ "Je ne fixe pas ses os. Je ne fixe pas ses os.", "Not staring at the bones. Not staring at the bones." },
	{ "Ne lui demande pas comment il va. C'est délicat.", "Don't ask how they're doing. Touchy subject." },
	{ "%s a l'air plus en forme que toi après une chute.", "%s looks fitter than you after a fall." },
	{ "Il a déjà vu le cimetière. Comme toi, souvent.", "They've seen the graveyard. Like you, often." },
	{ "Il lui manque une mâchoire ? Non, c'est un sourire.", "Missing a jaw? No, that's a smile." },
}
P.NPC_CT_beast = {
	{ "Une bête qui parle ? Ou alors c'est moi ?", "A talking beast? Or is it me?" },
	{ "On se renifle d'abord, c'est la politesse.", "Sniff first, that's manners." },
	{ "Lui, je le comprends. On est collègues.", "This one I get. We're colleagues." },
	{ "Ne lui donne pas ta collation, c'est la mienne.", "Don't give it your snack, that's mine." },
	{ "Il me regarde de travers. Jalousie de poils.", "It's giving me side-eye. Fur envy." },
	{ "Il sent la forêt. Toi, tu sens le voyage.", "It smells of forest. You smell of travel." },
	{ "On est de la même famille, en quelque sorte.", "We're family, sort of." },
}
P.NPC_CT_demon = {
	{ "Des cornes et un sourire. Je n'aime pas trop ça.", "Horns and a smile. Not a fan." },
	{ "Garde ta bourse près de toi avec %s.", "Keep your purse close around %s." },
	{ "Ça sent le soufre… mais poliment.", "Smells of brimstone… politely." },
	{ "Ne signe rien. Vraiment rien.", "Don't sign anything. Really, nothing." },
	{ "%s sourit trop. Je n'aime pas les grands sourires.", "%s smiles too much. I don't trust big grins." },
	{ "Il a de jolies cornes. Je ne le lui dirai pas.", "Nice horns. I won't tell them." },
	{ "On dit bonjour, et on recule doucement.", "We say hello, and back away slowly." },
}
P.NPC_CT_dragonkin = {
	{ "Un cousin éloigné ! Enfin… très éloigné.", "A distant cousin! Well… very distant." },
	{ "%s a de belles écailles. Je suis jaloux.", "%s has lovely scales. I'm jealous." },
	{ "Parle doucement, les dragons ont l'oreille fine.", "Speak softly, dragons hear everything." },
	{ "Ne parle pas de sa grand-mère, on ne sait jamais.", "Don't mention their grandmother, just in case." },
	{ "%s pourrait te griller en un souffle. Sois poli.", "%s could roast you in one breath. Be polite." },
	{ "Il garde un trésor ? Je demande pour un ami.", "Do they guard a hoard? Asking for a friend." },
	{ "Moi aussi, j'aurai des ailes un jour. Peut-être.", "I'll have wings one day too. Maybe." },
}
P.NPC_CT_elemental = {
	{ "Il est fait de quoi, au juste ? De vent ?", "What's it even made of? Wind?" },
	{ "Je ne m'approche pas trop, j'ai peur de fondre.", "Not getting too close, I might melt." },
	{ "%s brille un peu. C'est normal ?", "%s glows a bit. Is that normal?" },
	{ "Ne le touche pas. Je ne sais pas ce qui arriverait.", "Don't touch it. No idea what would happen." },
	{ "%s gronde doucement. C'est de la conversation ?", "%s rumbles softly. Is that small talk?" },
	{ "Il est tout en caillou ? Ou tout en eau ? Je m'y perds.", "All rock? All water? I'm confused." },
	{ "Pas d'éternuement près de lui, s'il te plaît.", "No sneezing near it, please." },
}
P.NPC_CT_mechanical = {
	{ "Bip boup ? Je crois qu'il m'a compris.", "Beep boop? I think it understood me." },
	{ "%s fait tic-tac. Il faut le remonter ?", "%s ticks. Does it need winding?" },
	{ "Une machine qui parle ! Les gnomes sont fous.", "A talking machine! Gnomes are mad." },
	{ "Ne lui demande pas l'heure, il va tout calculer.", "Don't ask it the time, it'll calculate everything." },
	{ "%s fume un peu. Il est en colère ou en marche ?", "%s is smoking a bit. Angry or just running?" },
	{ "Une vis de travers, et pouf. Prudence.", "One loose screw and poof. Careful." },
	{ "Il a plus d'engrenages que toi d'idées. Hihi.", "It has more gears than you have ideas. Hehe." },
}
P.NPC_CT_giant = {
	{ "Lève la tête… encore… encore… voilà.", "Look up… more… more… there." },
	{ "%s est grand. Très grand. Je reste derrière toi.", "%s is big. Very big. I'll stay behind you." },
	{ "Ne lui marche pas sur les pieds. Enfin, l'inverse.", "Don't step on their toes. Well, the reverse." },
	{ "%s a de grandes mains. Restons hors de portée.", "%s has big hands. Let's stay out of reach." },
	{ "Je me sens tout petit. Plus que d'habitude.", "I feel tiny. Tinier than usual." },
	{ "Il éternue, on s'envole. Doucement.", "If they sneeze, we fly. Gently." },
}
P.NPC_CT_critter = {
	{ "Oh, un tout petit ! On devient amis ?", "Aww, a tiny one! Friends?" },
	{ "Celui-là, je peux le regarder dans les yeux.", "This one I can look in the eye." },
	{ "Ne l'attaque pas, hein. Je t'ai vu faire, avec les lapins.", "Don't attack it. I've seen you with the rabbits." },
	{ "Plus mignon que moi ? Impossible.", "Cuter than me? Impossible." },
	{ "Lui, au moins, il ne se perd pas en route.", "At least this one doesn't get lost." },
	{ "Coucou, petit ! Ne fais pas attention à son armure.", "Hi, little one! Ignore their armour." },
}

-- ---------------------------------------------------------------------------
-- Bavardage : repos prolongé, nuit
-- ---------------------------------------------------------------------------
P.IDLE = {
	{ "On est bien ici… on reste encore un peu ?", "It's nice here… stay a bit longer?" },
	{ "Je compte les poutres du plafond. J'en suis à douze.", "Counting the ceiling beams. Up to twelve." },
	{ "Tu fais une pause ? Moi aussi. Je suis très doué.", "Taking a break? Me too. I'm very good at it." },
	{ "Zzz… hein ? Non, je ne dormais pas.", "Zzz… huh? No, I wasn't sleeping." },
	{ "Le repos, c'est aussi l'aventure. Version douce.", "Resting is adventure too. The soft version." },
	{ "Je te raconte mes rêves ? Ils parlent de fromage.", "Want to hear my dreams? They're about cheese." },
	{ "Tu es toujours là ? Je vérifie. Oui ? Bon.", "Are you still there? Just checking. Yes? Good." },
	{ "Je crois que tu t'es endormi debout. C'est un talent.", "I think you fell asleep standing up. That's a talent." },
	{ "On attend quelque chose ? Ou quelqu'un ? Ou rien ?", "Are we waiting for something? Someone? Nothing?" },
	{ "Si tu cherches la quête, elle est sur ta carte. Je dis ça…", "If you're looking for the quest, it's on your map. Just saying…" },
	{ "J'ai fait le tour de toi quatorze fois. Tu n'as pas bougé.", "I've walked around you fourteen times. You haven't moved." },
	{ "Pendant que tu rêvasses, les sangliers se reproduisent.", "While you daydream, the boars are multiplying." },
	{ "Je m'ennuie un peu. Pas de toi ! Enfin… un peu de toi.", "I'm a bit bored. Not of you! Well… a bit of you." },
	{ "Tu fais une pause ou tu as oublié comment marcher ?", "Taking a break, or did you forget how to walk?" },
	{ "Je profite du calme pour compter tes morts d'aujourd'hui. J'ai besoin de mes doigts de pied.", "Using the quiet to count today's deaths. I need my toes." },
	{ "Psst. Le monde est par là. Tout autour, en fait.", "Psst. The world is that way. All around, actually." },
	{ "Je t'ai dessiné dans la poussière. Tu as l'air perdu. C'est ressemblant.", "I drew you in the dust. You look lost. Good likeness." },
	{ "Une pause, très bien. Mais pas jusqu'au niveau suivant, hein ?", "A break, fine. But not until next level, OK?" },
}
P.NIGHT = {
	{ "Il fait nuit… regarde les étoiles !", "It's night… look at the stars!" },
	{ "La nuit, tout fait un peu peur. Sauf toi.", "Everything's a bit spooky at night. Except you." },
	{ "Chut… la nuit, même les loups chuchotent.", "Shh… at night, even wolves whisper." },
	{ "Une balade au clair de lune, c'est joli, non ?", "A moonlit stroll, lovely, isn't it?" },
	{ "La nuit tombe. Toi aussi, souvent, mais ça n'a rien à voir.", "Night is falling. So do you, often, but that's unrelated." },
	{ "Il fait noir ! Reste près de moi. Pour te protéger, bien sûr.", "It's dark! Stay close to me. To protect you, of course." },
	{ "La nuit, on se perd encore plus. Et tu pars de loin.", "At night you get even more lost. And you start from far." },
	{ "Les étoiles sont belles. Elles, au moins, savent où elles vont.", "The stars are lovely. At least they know where they're going." },
	{ "Bonne nuit, monde ! Enfin, pas pour nous, on a des quêtes.", "Good night, world! Well, not for us, we've got quests." },
}

-- ---------------------------------------------------------------------------
-- Besoins exprimés (jamais de reproche : une envie, pas une plainte)
-- ---------------------------------------------------------------------------
P.NEED_hunger = {
	{ "J'ai un petit creux… on s'arrête manger ?", "I'm a bit peckish… snack stop?" },
	{ "Mon ventre fait des bruits rigolos. Une pause repas ?", "My tummy's making funny noises. Lunch break?" },
	{ "Quand tu manges, je me régale aussi, tu sais.", "When you eat, I get a treat too, you know." },
	{ "Un bout de pain, et je repars comme neuf !", "A bit of bread and I'm good as new!" },
	{ "Mon ventre fait plus de bruit que tes combats.", "My tummy is louder than your fights." },
	{ "Tu as des vivres plein le sac et moi, rien. Je dis ça…", "Your bag's full of food and I've got none. Just saying…" },
	{ "Une miette, une seule. Pour le moral de la troupe.", "One crumb, just one. For troop morale." },
	{ "Si tu manges, je pique un bout. Promis, petit.", "If you eat, I'll nibble a bit. A small bit, promise." },
	{ "Je pourrais manger un sanglier. Un petit, d'accord.", "I could eat a boar. A small one, fine." },
}
P.NEED_energy = {
	{ "Je tombe de sommeil… une auberge, peut-être ?", "I'm so sleepy… an inn, maybe?" },
	{ "Un coin de repos, une sieste, et je suis à toi.", "A resting spot, a nap, and I'm all yours." },
	{ "Mes petites pattes fatiguent. On se pose un moment ?", "My little legs are tired. Sit a while?" },
	{ "Bâille… pardon. On se repose bientôt ?", "Yawn… sorry. Rest soon?" },
	{ "Tu cours partout, moi je m'endors debout.", "You run everywhere, I'm falling asleep standing." },
	{ "Une auberge, un feu, et je redeviens adorable.", "An inn, a fire, and I'm adorable again." },
	{ "Mes paupières pèsent plus lourd que ton sac.", "My eyelids weigh more than your bag." },
	{ "On fait une pause ? Je fais des rêves de coussins.", "Break time? I'm dreaming of cushions." },
	{ "Si je ronfle en marchant, c'est normal.", "If I snore while walking, that's normal." },
}
P.NEED_mood = {
	{ "Tu me fais un câlin ? Juste un petit.", "A cuddle? Just a tiny one?" },
	{ "Raconte-moi une quête ! Une qui finit bien.", "Tell me a quest! One with a happy ending." },
	{ "Une quête rendue, ça me ferait sourire.", "A quest turned in would make me smile." },
	{ "Tu es là, c'est déjà bien. Mais un câlin…", "You're here, that's already great. But a cuddle…" },
	{ "Une petite caresse, et je te pardonne tes chutes.", "One little pat and I forgive your falls." },
	{ "Je boude un peu. Un câlin réglerait tout.", "I'm sulking a bit. A cuddle would fix it." },
	{ "On rend une quête ? J'adore les fins heureuses.", "Turn in a quest? I love happy endings." },
	{ "Fais-moi rire. Trébuche, tiens. Non, je plaisante.", "Make me laugh. Trip over, go on. No, kidding." },
	{ "Clique sur moi. Juste pour voir si tu m'aimes.", "Click me. Just to check you love me." },
}
P.NEED_curiosity = {
	{ "On n'a rien vu de neuf depuis longtemps… on explore ?", "Haven't seen anything new in ages… explore?" },
	{ "Et si on allait voir derrière cette colline ?", "What if we peeked behind that hill?" },
	{ "Un nouveau coin sur la carte, ça te tente ?", "A new spot on the map, fancy it?" },
	{ "J'ai envie de découvrir un endroit inconnu !", "I'm itching to discover somewhere new!" },
	{ "On tourne en rond ici. Allons voir ailleurs !", "We're going in circles here. Let's go elsewhere!" },
	{ "Ce chemin, là ? On ne l'a jamais pris !", "That path there? We've never taken it!" },
	{ "Je connais ce caillou par cœur. On bouge ?", "I know this rock by heart. Move on?" },
	{ "Une zone inconnue, rien qu'une, s'il te plaît !", "One unknown area, just one, please!" },
	{ "Tu as peur de te perdre ? On se perd ensemble !", "Scared of getting lost? We'll get lost together!" },
}

-- ---------------------------------------------------------------------------
-- Objectifs : le prochain déblocage (%s = reste, %s = récompense)
-- ---------------------------------------------------------------------------
P.GOAL = {
	{ "Encore %s et j'aurai : %s !", "%s more and I'll get: %s!" },
	{ "Plus que %s avant %s. On y va ?", "Just %s to go before %s. Shall we?" },
	{ "Psst : encore %s et je débloque %s.", "Psst: %s more and I unlock %s." },
	{ "Courage : encore %s, et %s est à moi !", "Keep going: %s more, and %s is mine!" },
	{ "Encore %s… et %s. Ne traîne pas, hein.", "%s more… and %s. Don't dawdle, okay?" },
	{ "Je compte : encore %s avant %s. Tu suis ?", "I'm counting: %s more before %s. Keeping up?" },
}
P.GOAL_STAGE = {
	{ "Encore %s et je deviendrai %s !", "%s more and I'll become %s!" },
	{ "Dans %s, je serai %s. J'ai hâte !", "In %s, I'll be %s. Can't wait!" },
	{ "Encore %s et je serai %s. Plus grand que tes bêtises !", "%s more and I'll be %s. Bigger than your blunders!" },
	{ "Plus que %s ! Après ça, %s. Tu vas voir.", "Just %s! After that, %s. You'll see." },
	{ "Accroche-toi : %s encore, et me voilà %s.", "Hang in there: %s more, and I'll be %s." },
}

-- ---------------------------------------------------------------------------
-- Astuces de progression (liées à l'addon et au jeu), jamais en combat
-- ---------------------------------------------------------------------------
P.TIP = {
	{ "Astuce : lie-toi à l'auberge du village, ta pierre de foyer t'y ramènera.", "Tip: bind at the village inn, your hearthstone will bring you back." },
	{ "Astuce : /qc options règle mes bulles et mes astuces.", "Tip: /qc options sets my bubbles and my tips." },
	{ "Astuce : le carnet compte les ennemis rares que TU as engagés.", "Tip: the journal counts the rares YOU actually engaged." },
	{ "Astuce : /qc ouvre mon carnet, un clic droit sur moi aussi.", "Tip: /qc opens my journal, and so does a right-click on me." },
	{ "Astuce : Maj + clic sur moi ouvre mon garde-manger. Les friandises, c'est la vie.", "Tip: Shift + click on me opens my pantry. Treats are life." },
	{ "Astuce : déconnecte-toi à l'auberge pour gagner de l'expérience reposée.", "Tip: log out at an inn to build rested experience." },
	{ "Astuce : les quêtes grises ne rapportent presque plus d'expérience.", "Tip: grey quests give almost no experience." },
	{ "Astuce : manger et boire en même temps fait repartir plus vite.", "Tip: eating and drinking together gets you going faster." },
	{ "Astuce : répare ton équipement en ville avant une longue sortie.", "Tip: repair your gear in town before a long trip." },
	{ "Astuce : regroupe les quêtes d'une même zone, moins de trajets.", "Tip: group quests from one area, less walking." },
	{ "Astuce : ton maître de classe a du nouveau tous les deux niveaux.", "Tip: your class trainer has something new every two levels." },
	{ "Astuce : un plus grand sac, c'est moins d'allers-retours.", "Tip: a bigger bag means fewer round trips." },
	{ "Astuce : garde une potion de soins pour les mauvaises surprises.", "Tip: keep a healing potion for nasty surprises." },
	{ "Astuce : chaque nouveau lieu ajoute un tampon au carnet (/qc carnet).", "Tip: every new place adds a journal stamp (/qc carnet)." },
	{ "Astuce : chaque zone finie à 100 %% ouvre un coffre, avec une apparence ou un ornement pour moi.", "Tip: every zone finished to 100%% opens a chest, with a look or an ornament for me." },
	{ "Astuce : survole-moi pour voir ma faim, mon énergie, mon moral, ma curiosité.", "Tip: hover me to see my hunger, energy, mood and curiosity." },
	{ "Astuce : tu peux me renommer avec /qc compagnon nom.", "Tip: you can rename me with /qc compagnon nom." },
	{ "Astuce : parle à chaque maître de vol croisé, ça fait gagner un temps fou.", "Tip: talk to every flight master you pass, huge time saver." },
	{ "Astuce : un ennemi bien plus fort que toi ? Mieux vaut le contourner.", "Tip: enemy far above you? Better go around." },
	{ "Astuce : relis l'objectif, un objet de quête tombe parfois d'un seul type d'ennemi.", "Tip: reread objectives, quest items sometimes drop from one enemy type." },
	{ "Astuce : un métier de récolte rapporte de l'or en chemin.", "Tip: a gathering profession earns gold along the way." },
	{ "Astuce : rends tes quêtes avant de partir, le check te le rappelle.", "Tip: turn in quests before leaving, the check reminds you." },
	{ "Astuce : le résumé de stuff montre ce que t'apporte un nouvel objet.", "Tip: the gear summary shows what a new item gives you." },
	{ "Astuce : flèches, balles ou réactifs ? Fais le plein avant de partir.", "Tip: arrows, bullets or reagents? Stock up before leaving." },
	{ "Astuce : l'auberge et la ville me redonnent de l'énergie.", "Tip: inns and towns restore my energy." },
	{ "Astuce : je ne t'en veux jamais. Absent ? Je somnole et je t'attends.", "Tip: I never hold a grudge. Away? I just doze and wait." },
	{ "Astuce : les ennemis jaunes n'attaquent pas tant que tu ne les frappes pas.", "Tip: yellow enemies won't attack unless you hit them first." },
	{ "Astuce : vends tes objets gris avant de repartir, ils ne servent à rien d'autre.", "Tip: sell your grey items before heading out, they're good for nothing else." },
	{ "Astuce : nage moins, contourne plus. La noyade n'est pas un raccourci.", "Tip: swim less, go around more. Drowning isn't a shortcut." },
	{ "Astuce : après une mort, cours vers ton corps plutôt que l'ange.", "Tip: after dying, run back to your body rather than the spirit healer." },
	{ "Astuce : l'ange guérisseur abîme ton équipement et t'affaiblit.", "Tip: the spirit healer damages your gear and weakens you." },
	{ "Astuce : une chute trop haute fait mal. Saute moins, vis plus.", "Tip: long falls hurt. Jump less, live more." },
	{ "Astuce : attaquer un groupe d'un coup, c'est rarement une bonne idée.", "Tip: pulling a whole group at once is rarely a good idea." },
	{ "Astuce : les ennemis rouges sont bien plus forts. Les gris, sans intérêt.", "Tip: red enemies are much stronger. Grey ones aren't worth it." },
	{ "Astuce : la pierre de foyer se recharge en une heure.", "Tip: the hearthstone recharges in one hour." },
	{ "Astuce : Maj + clic sur une quête du journal pour la suivre à l'écran.", "Tip: Shift + click a quest in the log to track it on screen." },
}

-- ---------------------------------------------------------------------------
-- Petites conversations (clic sur le compagnon) : 2 ou 3 bulles d'affilée
-- ---------------------------------------------------------------------------
local CONVOS = {
	{ { "Tu sais ce que je préfère dans l'aventure ?", "Know my favourite part of adventuring?" },
	  { "Les paysages ? Les trésors ?", "The views? The treasure?" },
	  { "Non : les pauses goûter.", "No: the snack breaks." } },
	{ { "Hé ! Tu m'as touché ! C'est toi le chat !", "Hey! Tag! You're it!" },
	  { "Ah non, j'oubliais : je cours tout doucement.", "Oh wait, I forgot: I run really slowly." } },
	{ { "Psst… j'ai un secret.", "Psst… I have a secret." },
	  { "J'ai vu un écureuil tout à l'heure.", "I saw a squirrel earlier." },
	  { "C'est tout. C'était un bel écureuil.", "That's it. It was a lovely squirrel." } },
	{ { "On joue à « je vois quelque chose » ?", "Play I-spy?" },
	  { "Je vois… quelque chose qui a des pattes.", "I spy… something with legs." },
	  { "C'était moi ! J'ai gagné.", "It was me! I win." } },
	{ { "Tu crois qu'on est les héros de l'histoire ?", "Think we're the heroes of this story?" },
	  { "Moi, je crois que oui.", "I think so." },
	  { "Toi, le héros. Moi, le héros mignon.", "You're the hero. I'm the cute one." } },
	{ { "Hihi, ça chatouille !", "Hehe, that tickles!" },
	  { "Encore ? Non, attends… si, encore !", "Again? No, wait… yes, again!" } },
	{ { "J'ai fait un rêve bizarre.", "I had a weird dream." },
	  { "On était des gnomes et on vendait des chapeaux.", "We were gnomes selling hats." },
	  { "Tu étais très doué pour les chapeaux.", "You were really good at hats." } },
	{ { "Tu veux entendre ma chanson ?", "Want to hear my song?" },
	  { "La la laaa… la.", "La la laaa… la." },
	  { "Merci, merci. Pas d'applaudissements, je rougis.", "Thank you, thank you. No applause, I'm blushing." } },
	{ { "Combien de pas aujourd'hui, à ton avis ?", "How many steps today, you reckon?" },
	  { "Moi, j'en ai fait douze mille.", "I did twelve thousand." },
	  { "Petites pattes, grands voyages.", "Little paws, big journeys." } },
	{ { "Merci de m'emmener partout.", "Thanks for taking me everywhere." },
	  { "Sérieusement. C'est le plus beau des voyages.", "Really. Best trip ever." } },
	{ { "Tu sais combien de fois tu es mort aujourd'hui ?", "Know how many times you died today?" },
	  { "Moi oui. Je tiens un carnet.", "I do. I keep a notebook." },
	  { "Il est presque plein.", "It's almost full." } },
	{ { "Pourquoi tu gardes cette vieille botte ?", "Why are you keeping that old boot?" },
	  { "Elle a une valeur sentimentale ?", "Sentimental value?" },
	  { "Ah non. Tu as juste oublié de la vendre.", "Oh no. You just forgot to sell it." } },
	{ { "J'ai une question sérieuse.", "I have a serious question." },
	  { "Tu sais vraiment où on va ?", "Do you actually know where we're going?" },
	  { "C'est bien ce que je pensais.", "That's what I thought." } },
	{ { "Tu cours toujours comme ça ?", "Do you always run like that?" },
	  { "Les bras en avant, la tête baissée ?", "Arms out, head down?" },
	  { "C'est très… héroïque. Oui.", "It's very… heroic. Yes." } },
	{ { "J'ai vu un lapin tout à l'heure.", "I saw a rabbit earlier." },
	  { "Il a eu peur de toi.", "It was scared of you." },
	  { "Enfin… je crois qu'il riait.", "Well… I think it was laughing." } },
	{ { "Tu te souviens de la falaise ?", "Remember the cliff?" },
	  { "Moi oui. Je m'en souviendrai toujours.", "I do. I'll remember it forever." } },
	{ { "Le cimetière m'a demandé de tes nouvelles.", "The graveyard asked about you." },
	  { "Je lui ai dit que tu allais bien.", "I told it you were fine." },
	  { "Pour l'instant.", "For now." } },
	{ { "Si on faisait un concours de vitesse ?", "Shall we race?" },
	  { "Toi contre moi. Petites pattes contre grandes jambes.", "You versus me. Little paws versus long legs." },
	  { "J'ai déjà gagné : tu t'es perdu.", "I've already won: you got lost." } },
	{ { "Tu as fini ta quête des dix sangliers ?", "Finished your ten-boar quest?" },
	  { "Ça fait trois jours, tu sais.", "It's been three days, you know." } },
	{ { "Je t'ai trouvé un surnom.", "I've found you a nickname." },
	  { "« Le Héros-qui-tombe-des-ponts. »", "\"The Hero-who-falls-off-bridges.\"" },
	  { "Ça sonne bien, non ? Non ? Je garde quand même.", "Sounds good, right? No? I'm keeping it anyway." } },
}
ns.COMPANION_CONVOS = {}
for index, steps in ipairs(CONVOS) do
	local name = "CONVO_" .. index
	P[name] = steps
	ns.COMPANION_CONVOS[index] = name
end

-- ---------------------------------------------------------------------------
-- Tutoriel (dans l'ordre ; %s = nom du compagnon, utilisé à la 1re bulle)
-- ---------------------------------------------------------------------------
P.TUTO = {
	{ "Salut ! Moi c'est %s, ton compagnon de route. Je voyage avec toi.", "Hi! I'm %s, your road companion. I travel with you." },
	{ "J'ai quatre besoins : faim, énergie, moral, curiosité. Survole-moi pour les voir.", "I have four needs: hunger, energy, mood, curiosity. Hover me to see them." },
	{ "Mange, repose-toi à l'auberge, rends des quêtes, explore : ça me comble !", "Eat, rest at inns, turn in quests, explore: that fills me up!" },
	{ "Je grandis avec tes niveaux : 10, 20, 40 et 60. Jamais de retour en arrière.", "I grow with your levels: 10, 20, 40 and 60. Never backwards." },
	{ "Finis une zone à 100 %% (carnet, /qc) : un coffre s'ouvre, avec une apparence ou un ornement pour moi.", "Finish a zone to 100%% (journal, /qc): a chest opens, with a look or an ornament for me." },
	{ "En route, je te préviens : sacs pleins, vivres, réparations, munitions, un élite dans le coin…", "On the road, I'll warn you: full bags, food, repairs, ammo, an elite nearby…" },
	{ "Je parle trop ? Pas assez ? Règle-moi avec la réglette « Bavardage », page Compagnon.", "Too chatty? Not enough? Tune me with the \"Chattiness\" slider, Companion page." },
	{ "Pour me personnaliser : réglages, page Compagnon. Et dès que tu abats un monstre, je t'explique le filet !", "To customise me: settings, Companion page. And as soon as you defeat a monster, I'll explain the net!" },
}

-- ---------------------------------------------------------------------------
-- Tutoriel de la ménagerie (2.3.0) : ce qu'apportent la 2.0, la 2.1 et la
-- 2.2. Il commence à la PREMIÈRE OCCASION DE CAPTURE (un monstre dans le
-- filet, hors combat) : START attend que le joueur lance le filet, la scène
-- se joue en silence, puis OK ou FAIL selon le verdict, puis la suite
-- (TUTO_MENAGERIE) au rythme du tutoriel. LATE : le monstre est parti avant
-- le clic (le tutoriel reprendra à l'occasion suivante). INTRO ouvre le rejeu
-- (/qc compagnon tuto menagerie), qui n'attend aucune capture.
-- Chaque bulle de la suite reçoit SES arguments (Companion.lua,
-- ns:CompanionMenagerieTutorialSteps), tirés des constantes des modules :
-- aucun chiffre n'est écrit ici. Tous en « %d », dans l'ordre (la ligne la
-- plus fournie fixe le gabarit du réservoir, tests/modules/companion_lines_more.lua) :
--   1 : %d s de filet après le combat          6 : %d %% d'envie pour la pleine force
--   2 : %d %% de chance de 3 étoiles           7 : +%d %% de brillantes en zone scellée
--   3 : 1 sur %d, jusqu'à 1 sur %d après %d    8 : %d espèces (1er titre), %d (dernier)
--   5 : effets après %d min
-- ---------------------------------------------------------------------------
P.TUTO_MENAGERIE_START = {
	{ "Un monstre qui manque à ma ménagerie ! Clique sur le filet, là, à côté de moi : je le capture.", "A monster missing from my menagerie! Click the net, right there next to me: I'll capture it." },
}
P.TUTO_MENAGERIE_OK = {
	{ "Voilà ! Elle rejoint ma ménagerie (page Ménagerie du carnet, /qc).", "There! It joins my menagerie (Menagerie page of the journal, /qc)." },
}
P.TUTO_MENAGERIE_FAIL = {
	{ "Il s'est échappé, ça arrive ! Au prochain, retente.", "It got away, it happens! Try again on the next one." },
}
P.TUTO_MENAGERIE_LATE = {
	{ "Trop tard, il est parti… la prochaine fois !", "Too late, it's gone… next time!" },
}
P.TUTO_MENAGERIE_INTRO = {
	{ "On révise la ménagerie ? Tu vois le filet, à côté de moi : un monstre abattu qui manque à ta ménagerie y tombe.", "Menagerie refresher? See the net next to me: a defeated monster missing from your menagerie lands in it." },
}
P.TUTO_MENAGERIE = {
	{ "Le filet garde un monstre %d s après le combat. Clic : je capture le meilleur ; clic droit : la liste. Le bandeau te prévient.", "The net keeps a monster %d s after the fight. Click: I capture the best one; right-click: the list. The banner lets you know." },
	{ "Chaque capture vaut 1 à 3 étoiles (3 étoiles : %d %% de chance). Recapture pour tenter mieux : je garde le meilleur.", "Each capture is worth 1 to 3 stars (3 stars: a %d%% chance). Recapture to try for better: I keep the best one." },
	{ "Les brillantes ! 1 chance sur %d au départ, jusqu'à 1 sur %d après %d abattus de la même espèce. Insiste, ça paie.", "Shinies! 1 chance in %d to start, up to 1 in %d after %d kills of the same species. Keep at it, it pays off." },
	{ "Un losange doré sur une barre de nom : une brillante ! Deux versions par espèce à capturer. Et brillant, je suis tout doré.", "A gold diamond on a nameplate: a shiny! Two versions per species to capture. And as a shiny, I'm all golden." },
	{ "Emmène-la : clic sur elle dans la Ménagerie. Selon son type, elle t'aide à chasser et me rend la vie douce, après %d min.", "Take it along: click it in the Menagerie. By its type, it helps you hunt and makes my life sweet, after %d min." },
	{ "Changer se confirme. Mes envies à %d %% ou plus : effets entiers, alors nourris-moi ! Une mascotte reste le compagnon de cœur.", "Switching asks first. My needs at %d%% or more: full effects, so feed me! A mascot stays the companion of the heart." },
	{ "Capture toutes les espèces d'une zone : elle est scellée ! Un cadre, puis un fond à ses couleurs, et +%d %% de brillantes là-bas.", "Capture every species of a zone: it gets sealed! A frame, then a background in its colours, and +%d%% shinies there." },
	{ "Par type, des paliers renforcent mes effets. À %d espèces, ton premier titre de dresseur ; à %d, le dernier. Ça claque.", "Per type, milestones strengthen my effects. At %d species, your first trainer title; at %d, the last one. Fancy." },
	{ "Chaque jour, une mission de ménagerie ; chaque semaine, une chasse au brillant et des missions par type. Friandises et aides !", "Every day, a menagerie mission; every week, a shiny hunt and missions by type. Treats and aids as rewards!" },
	{ "Ta fiche de dresseur : /qc fiche. Ton titre, moi en 3D, une vitrine de 3 créatures. Clic droit sur un autre dresseur : la sienne.", "Your trainer card: /qc fiche. Your title, me in 3D, a showcase of 3 creatures. Right-click another trainer: theirs." },
	{ "Tout est écrit dans le carnet, page Guide (/qc). Pour me réentendre : /qc compagnon tuto menagerie. Allez, à la chasse !", "It's all in the journal, Guide page (/qc). To hear me again: /qc compagnon tuto menagerie. Now, off to the hunt!" },
}

-- ---------------------------------------------------------------------------
-- Conseils de route (Advice.lua) : %s = nom, %d = nombre ou pourcentage
-- ---------------------------------------------------------------------------
P.ADVICE_ELITE = {
	{ "Attention, %s par là ! C'est un élite, ça pique.", "Careful, %s over there! It's an elite, it bites." },
	{ "%s… celui-là est costaud, on le contourne ?", "%s… that one's tough, shall we go around?" },
	{ "%s, élite ! Tu n'as rien à prouver. Si, à moi, mais pas ici.", "%s, elite! Nothing to prove. Well, to me, but not here." },
	{ "%s, là-bas. Lui, il gagne. Contourne.", "%s, over there. That one wins. Go around." },
	{ "Attention à %s ! Je n'ai pas envie de courir au cimetière.", "Watch out for %s! I don't fancy a graveyard jog." },
}
P.ADVICE_RARE = {
	{ "Oh, %s ! Un rare, mais il a l'air coriace.", "Oh, %s! A rare, but it looks tough." },
	{ "%s rôde par ici : rare, et plus fort que toi.", "%s is prowling around: rare, and stronger than you." },
	{ "%s ! Rare, joli… et trop fort. On admire de loin ?", "%s! Rare, pretty… and too strong. Admire from afar?" },
	{ "Un rare : %s. Tentant, mais ton niveau dit non.", "A rare: %s. Tempting, but your level says no." },
	{ "%s traîne par ici. Ne fais pas le malin, hein.", "%s is lurking. Don't get cocky, okay?" },
}
P.ADVICE_HEALTH = {
	{ "Ouf… tu es bien amoché. On se pose un peu ?", "Phew… you're badly hurt. Shall we rest a bit?" },
	{ "Mange un morceau avant de repartir, tu en as besoin.", "Have a bite before moving on, you need it." },
	{ "Tu tiens debout par habitude. Assieds-toi un peu.", "You're standing out of habit. Sit down a bit." },
	{ "Encore un coup et c'est le cimetière. Pause ?", "One more hit and it's the graveyard. Break?" },
	{ "Tu as la mine d'un sanglier battu. Mange un bout.", "You look like a beaten boar. Have a bite." },
}
P.ADVICE_AMMO = {
	{ "Plus que %d munitions, pense à en racheter.", "Only %d ammo left, think about buying more." },
	{ "%d munitions… ça va partir vite.", "%d ammo… that won't last long." },
	{ "Plus que %d munitions. Tu vas les lancer à la main ?", "Only %d ammo. Planning to throw them by hand?" },
	{ "%d munitions restantes. Vise bien, hein.", "%d ammo left. Aim well, okay?" },
	{ "Encore %d tirs. Après, tu pourras jeter des cailloux.", "%d more shots. After that, you can throw rocks." },
}
P.ADVICE_AMMO_EMPTY = {
	{ "On est presque à sec de munitions (%d) : sans elles, pas de tir !", "We're nearly out of ammo (%d): no ammo, no shooting!" },
	{ "Plus que %d munitions, il faut vraiment rentrer.", "Only %d ammo left, we really need to head back." },
	{ "%d munitions ! Bientôt, tu tapes avec ton arc.", "%d ammo! Soon you'll be hitting things with your bow." },
	{ "Plus que %d tirs. Un marchand, vite !", "Just %d shots left. A vendor, quick!" },
	{ "%d munitions… Je ne vais pas faire « pan » pour toi.", "%d ammo… I'm not going to say \"bang\" for you." },
}
P.ADVICE_AMMO_UNEQUIPPED = {
	{ "Tes munitions sont dans le sac (%d), pas dans ton emplacement de munitions !", "Your ammo is in your bag (%d), not in your ammo slot!" },
	{ "%d munitions au fond du sac. Elles ne vont pas se ranger seules !", "%d ammo at the bottom of your bag. They won't equip themselves!" },
	{ "Tu as %d munitions… dans le sac. Mets-les dans leur emplacement !", "You've got %d ammo… in your bag. Put them in the ammo slot!" },
	{ "%d munitions qui dorment dans le sac. Réveille-les.", "%d ammo sleeping in your bag. Wake them up." },
}
P.ADVICE_FOOD = {
	{ "Il ne reste que %d de quoi manger, et on est loin du village.", "Only %d bites of food left, and we're far from town." },
	{ "Plus que %d vivres… on en garde pour plus tard ?", "Just %d food left… shall we save some?" },
	{ "Plus que %d vivres. Je ne partage plus, moi.", "Only %d food left. I'm not sharing anymore." },
	{ "%d vivres… tu as tout grignoté en cachette ?", "%d food… did you snack on the sly?" },
	{ "Encore %d vivres. Le prochain marchand, c'est pour nous.", "%d food left. The next vendor's for us." },
}
P.ADVICE_FOOD_EMPTY = {
	{ "Plus rien à manger… on rentre faire des provisions ?", "Nothing left to eat… head back for supplies?" },
	{ "Plus de vivres. On va manger de l'herbe ?", "No food left. Shall we eat grass?" },
	{ "Sacs vides côté repas. Mon ventre proteste.", "Bags empty of food. My tummy objects." },
	{ "Rien à manger ! Un marchand, et vite.", "Nothing to eat! A vendor, and fast." },
}
P.ADVICE_DURA = {
	{ "Ton équipement souffre (%d %%), pense à réparer.", "Your gear is suffering (%d %%), think about repairs." },
	{ "Ton armure s'use : %d %%, un forgeron serait le bienvenu.", "Your armor is wearing out: %d %%, a blacksmith would be welcome." },
	{ "Ton armure est à %d %%. Elle a vu des choses.", "Your armour's at %d %%. It's seen things." },
	{ "%d %% de solidité. Tu tombes souvent, hein ?", "%d %% durability. You fall a lot, huh?" },
	{ "Équipement à %d %% : un forgeron te ferait du bien.", "Gear at %d %%: a blacksmith would do you good." },
}
P.ADVICE_DURA_CRIT = {
	{ "Ton équipement va casser (%d %%) ! Il faut réparer.", "Your gear is about to break (%d %%)! Time to repair." },
	{ "%d %% ! Encore une mort et tu te bats en caleçon.", "%d %%! One more death and you're fighting in your undies." },
	{ "Équipement à %d %%. Ça tient avec de la ficelle.", "Gear at %d %%. It's held together with string." },
	{ "%d %%… Ton armure demande grâce. Répare !", "%d %%… your armour begs for mercy. Repair!" },
}
P.ADVICE_BAGS = {
	{ "Plus que %d places dans les sacs… on garde quoi ?", "Only %d bag slots left… what do we keep?" },
	{ "Les sacs se remplissent : %d places libres.", "Bags are filling up: %d free slots." },
	{ "Plus que %d places. Tu collectionnes les objets gris ?", "Only %d slots. Collecting grey items, are we?" },
	{ "%d places libres. Les dents de loup, on en garde combien ?", "%d free slots. How many wolf teeth do we keep?" },
	{ "Encore %d places. Ton sac ressemble à un grenier.", "%d slots left. Your bag looks like an attic." },
}
P.ADVICE_BAGS_LAST = {
	{ "Dernière place dans les sacs !", "Last free bag slot!" },
	{ "Une seule place ! Choisis bien ton prochain caillou.", "One slot left! Pick your next pebble wisely." },
	{ "Dernière place. Après, c'est moi qui porte ? Non.", "Last slot. Then I carry stuff? No." },
	{ "Plus qu'une place. Le bric-à-brac déborde !", "One slot left. The junk is overflowing!" },
}
P.ADVICE_BAGS_FULL = {
	{ "Les sacs sont pleins, le prochain butin restera par terre !", "Bags are full, the next loot stays on the ground!" },
	{ "Sacs pleins ! Tu vas laisser les trésors aux corbeaux ?", "Bags full! Leaving treasure for the crows?" },
	{ "Plus de place. Vends tes chiffons gris, sérieusement.", "No room. Sell your grey rags, seriously." },
	{ "Sacs pleins à craquer. Je ne porte rien, moi.", "Bags bursting. I'm not carrying anything." },
}
P.ADVICE_QUESTS = {
	{ "Tout est fini ici : on rentre rendre les quêtes ?", "All done here: shall we go turn in the quests?" },
	{ "Toutes tes quêtes sont prêtes à rendre !", "All your quests are ready to turn in!" },
	{ "Tes quêtes sont finies. On va chercher les récompenses ?", "Your quests are done. Shall we collect the rewards?" },
	{ "Tout est prêt ! Ils attendent ta tête de héros.", "All set! They're waiting for your hero face." },
	{ "Fini ici. Rentrons avant que tu oublies tout.", "Done here. Let's head back before you forget it all." },
}
P.ADVICE_HEARTH = {
	{ "Ta pierre de foyer est prête. On rentre ?", "Your hearthstone is ready. Going home?" },
	{ "Le foyer est rechargé, et on est bien chargés : retour à l'auberge ?", "The hearthstone is back, and we're loaded: back to the inn?" },
	{ "Pierre de foyer prête. Hop, à l'auberge, sans marcher !", "Hearthstone ready. Off to the inn, no walking!" },
	{ "Ton foyer est rechargé. Tes pieds te supplient.", "Hearthstone recharged. Your feet are begging." },
	{ "La pierre de foyer brille. Elle a envie de rentrer.", "The hearthstone glows. It wants to go home." },
}

-- ---------------------------------------------------------------------------
-- En groupe (Group.lua) : %s = nom (ou carte), %d = niveaux d'écart
-- ---------------------------------------------------------------------------
P.GROUP_NO_HEALER = {
	{ "Pas de soigneur dans le groupe… prévoyez des potions !", "No healer in the group… bring potions!" },
	{ "Personne pour soigner : on y va doucement ?", "Nobody to heal: shall we take it slow?" },
	{ "Pas de soigneur ? Alors pas de bêtises, hein.", "No healer? Then no silly stuff, okay?" },
	{ "Sans soigneur, les potions sont vos amies.", "Without a healer, potions are your friends." },
	{ "Personne pour soigner. Je soigne avec mon sourire ?", "Nobody to heal. Shall I heal with my smile?" },
}
P.GROUP_BALANCED = {
	{ "Bel équipage ! Un soigneur, du monde : on est prêts.", "Nice crew! A healer, enough people: we're ready." },
	{ "Tout le monde est là, soigneur compris. Pas d'excuse !", "Everyone's here, healer included. No excuses!" },
	{ "Une vraie équipe ! Même moi, je suis impressionné.", "A real team! Even I'm impressed." },
	{ "Groupe parfait. Essaie de ne pas tirer tout le donjon.", "Perfect group. Try not to pull the whole dungeon." },
}
P.GROUP_LOW_LEVEL = {
	{ "%s est %d niveau(x) sous ce donjon, gardez un œil sur lui.", "%s is %d level(s) below this dungeon, keep an eye on them." },
	{ "%s a %d niveau(x) de retard. Protégez-le bien.", "%s is %d level(s) short. Keep them safe." },
	{ "Attention, %s est %d niveau(x) en dessous.", "Careful, %s is %d level(s) below." },
	{ "%s : %d niveau(x) trop bas. On le couve un peu ?", "%s: %d level(s) too low. Shall we shelter them?" },
}
P.GROUP_IN_RANGE = {
	{ "Tout le groupe a le niveau de ce donjon, en route !", "The whole group fits this dungeon, let's go!" },
	{ "Tout le monde a le bon niveau. Plus d'excuses !", "Everyone's the right level. No more excuses!" },
	{ "Bons niveaux partout. Je suis presque rassuré.", "Right levels all round. I'm almost reassured." },
	{ "Groupe au bon niveau. Le donjon n'a qu'à bien se tenir.", "Group at the right level. The dungeon had better behave." },
}
P.GROUP_BEHIND = {
	{ "%s est resté en arrière, on l'attend ?", "%s fell behind, shall we wait?" },
	{ "On a perdu %s de vue…", "We've lost sight of %s…" },
	{ "%s traîne. Encore pire que toi !", "%s is lagging. Even worse than you!" },
	{ "%s s'est perdu ? Ça me rappelle quelqu'un.", "%s got lost? Reminds me of someone." },
	{ "On attend %s ? Il regarde sûrement les papillons.", "Wait for %s? Probably watching butterflies." },
}
P.GROUP_ELSEWHERE = {
	{ "Il manque %s, encore à %s.", "%s is missing, still in %s." },
	{ "%s est encore à %s. Pas pressé, lui.", "%s is still in %s. In no hurry." },
	{ "On attend %s, coincé à %s.", "Waiting for %s, stuck in %s." },
	{ "%s se promène à %s. Le groupe, c'est ici !", "%s is strolling in %s. The group's here!" },
}
P.GROUP_DEAD = {
	{ "Paix à %s… on l'attend ?", "Rest in peace, %s… shall we wait?" },
	{ "Oh non, %s est tombé !", "Oh no, %s went down!" },
	{ "%s est tombé. Ça ne t'arrive jamais, à toi ? Hum.", "%s fell. Never happens to you, right? Hmm." },
	{ "Aïe, %s est à terre. On le relève ?", "Ouch, %s is down. Shall we help them up?" },
	{ "%s fait une sieste forcée. On l'attend.", "%s is taking a forced nap. Let's wait." },
}
P.GROUP_HEALER_DEAD = {
	{ "%s est tombé : plus de soins, prudence !", "%s went down: no more heals, careful!" },
	{ "%s est tombé. Les soins, c'est fini. Courage !", "%s fell. No more heals. Hang in there!" },
	{ "Plus de %s, plus de soins. On recule, doucement.", "No %s, no heals. Back off, gently." },
	{ "%s à terre ! Sortez les potions, vite.", "%s down! Potions out, quick." },
}
P.GROUP_OFFLINE = {
	{ "%s s'est déconnecté.", "%s disconnected." },
	{ "%s est parti. Sans dire au revoir.", "%s left. Without saying goodbye." },
	{ "%s s'est volatilisé. Son dîner, sûrement.", "%s vanished. Dinner, probably." },
	{ "Plus de %s. On continue sans lui ?", "No more %s. Carry on without them?" },
}

-- Confirmation d'un nouveau cran de la réglette « Bavardage »
P.CHATTER_1 = { { "D'accord, je me fais discret : je ne parle que si ça compte.", "Alright, I'll keep quiet: I only speak up when it matters." } }
P.CHATTER_2 = { { "Je reste calme : mes conseils et les grands moments, c'est tout.", "I'll stay calm: my advice and the big moments, that's all." } }
P.CHATTER_3 = { { "Comme d'habitude, alors ! On papote ?", "Back to normal, then! Shall we chat?" } }
P.CHATTER_4 = { { "Oh, j'ai le droit de bavarder ? J'ai plein de choses à te dire !", "Oh, I'm allowed to chat? I've got so much to tell you!" } }

-- Souvenirs (Memories.lua) : la photo, le rappel d'un souvenir, les anniversaires
P.PHOTO = {
	{ "Clic ! Celle-là, je la garde.", "Click! I'm keeping this one." },
	{ "Clic ! Souris !", "Click! Smile!" },
	{ "Clic ! Pour l'album.", "Click! For the album." },
	{ "Clic ! Un souvenir de plus.", "Click! One more memory." },
	{ "Clic ! Celle-là, avec ta tête de vainqueur. Rare.", "Click! That one, with your winner face. Rare." },
	{ "Clic ! Tu as fermé les yeux. On la garde quand même.", "Click! You blinked. We're keeping it anyway." },
	{ "Clic ! Pour prouver qu'un jour, tu n'étais pas perdu.", "Click! Proof that once, you weren't lost." },
	{ "Clic ! Je l'appellerai « Le héros, de dos ».", "Click! I'll call it \"The hero, from behind\"." },
	{ "Clic ! Elle ira entre ta plus belle chute et ton meilleur détour.", "Click! It goes between your best fall and your finest detour." },
}
P.RECALL = {  -- %s = le souvenir
	{ "Tu te souviens ? %s", "Remember? %s" },
	{ "Je repensais à ça : %s", "I was thinking about this: %s" },
	{ "Ah, le bon vieux temps… %s", "Ah, the good old days… %s" },
	{ "Dans mon album, j'aime bien celui-là : %s", "In my album, I like this one: %s" },
	{ "Hihi, je repense à ça : %s", "Hehe, I keep thinking about this: %s" },
	{ "Ça me fait encore rire : %s", "Still makes me laugh: %s" },
	{ "Page préférée de l'album : %s", "Favourite page in the album: %s" },
}
P.ANNIV = {  -- %s = la durée (« une semaine »)
	{ "Ça fait %s qu'on voyage ensemble !", "We've been travelling together for %s!" },
	{ "Déjà %s ensemble ! Merci de m'emmener partout.", "Together for %s already! Thanks for taking me everywhere." },
	{ "Voilà %s qu'on est ensemble, et tes chutes me font toujours rire.", "%s together now, and your falls still make me laugh." },
	{ "Ça fait %s qu'on voyage ! Tu as presque appris à lire une carte.", "%s on the road together! You've nearly learned to read a map." },
	{ "Joyeux anniversaire de voyage : %s ! Tu m'offres un biscuit ?", "Happy travel-versary: %s! Biscuit for me?" },
}

-- ---------------------------------------------------------------------------
-- Clés et enregistrement
-- ---------------------------------------------------------------------------
local FR, EN, POOLS = {}, {}, {}
for name, lines in pairs(P) do
	local keys = {}
	for index, pair in ipairs(lines) do
		local key = "COMP_SAY_" .. name .. (index > 1 and ("_" .. index) or "")
		-- deux réservoirs aux noms voisins ne doivent jamais se marcher dessus
		if FR[key] ~= nil then error("CompanionLines: clé en double " .. key) end
		FR[key], EN[key] = pair[1], pair[2]
		keys[index] = key
	end
	POOLS[name] = keys
end
ns.RegisterStrings(FR, EN)
ns.COMPANION_POOLS = POOLS
if ns.KEEP_STRINGS then ns.COMPANION_LINE_STRINGS = { fr = FR, en = EN } end   -- exposé aux tests (parité fr/en)

if ns.Mark then ns.Mark("CompanionLines") end
