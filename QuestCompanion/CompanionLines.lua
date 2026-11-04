-- CompanionLines.lua -- répliques du « Compagnon de route » (v1.25.0)
--
-- Données seules : toutes les bulles, rangées par situation (« réservoir »).
-- Companion.lua en tire une au hasard, sans répéter les dernières, et décide
-- QUAND parler (priorités, écarts, pauses par catégorie). Ici, on ne décide
-- que QUOI dire.
--
-- Ton : tutoiement, chaleureux, court (une bulle fait ~190 px de large), un
-- peu drôle, jamais culpabilisant. Textes originaux.
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
}
P.MISSED = {
	{ "Tu m'as manqué ! Zzz… je me réveille doucement.", "I missed you! Zzz… waking up slowly." },
	{ "Te revoilà ! J'ai gardé ta place au chaud… zzz.", "You're back! I kept your spot warm… zzz." },
	{ "Oh, c'est toi ! Je rêvais de toi. Enfin… de goûter.", "Oh, it's you! I was dreaming of you. Well… of snacks." },
}
P.AWAKE = {
	{ "Me revoilà en pleine forme !", "Wide awake again!" },
	{ "Bon, je suis réveillé. Presque. Oui. Allons-y !", "Right, I'm awake. Mostly. Yes. Let's go!" },
	{ "Tout frais, tout pimpant !", "Fresh as a daisy!" },
}
P.PET_sleepy = {
	{ "Hein ? Oh, c'est toi ! Bonjour !", "Huh? Oh, it's you! Hello!" },
	{ "Mmh… cinq minutes encore… non, je suis debout !", "Mmh… five more minutes… no, I'm up!" },
	{ "Oh ! Un câlin pour me réveiller, le luxe.", "Oh! A wake-up cuddle, what luxury." },
}

-- ---------------------------------------------------------------------------
-- Départ et retour (module Check avant le départ)
-- ---------------------------------------------------------------------------
P.NOFOOD = {
	{ "On part sans rien à grignoter ? Pense à moi au prochain marchand !", "Leaving without a snack? Think of me at the next vendor!" },
	{ "Tes sacs sentent… rien. Un casse-croûte au prochain marchand ?", "Your bags smell of… nothing. A snack at the next vendor?" },
	{ "Pas de vivres ? Bon, je chasserai les miettes.", "No food? Fine, I'll hunt for crumbs." },
	{ "Je dis ça pour toi : un peu de pain, ça aide en route.", "Just saying: a bit of bread helps on the road." },
}
P.DEPART = {
	{ "En route ! J'ai vu le goûter dans ton sac.", "Off we go! I saw the snacks in your bag." },
	{ "Cap sur l'aventure ! Je passe devant… non, toi d'abord.", "Adventure ahoy! I'll lead… no, you first." },
	{ "Sacs prêts, cœur léger : on y va !", "Bags ready, heart light: let's go!" },
	{ "J'adore ce moment où on quitte la ville.", "I love the moment we leave town." },
	{ "En route ! J'ai déjà hâte de voir ce qu'il y a là-bas.", "On our way! Can't wait to see what's out there." },
}
P.RETURN = {
	{ "Ouf, on est rentrés ! Bien joué.", "Phew, we're back! Well done." },
	{ "Retour au bercail ! On a bien mérité une pause.", "Home sweet home! We've earned a break." },
	{ "On est rentrés entiers. Enfin, toi surtout.", "Back in one piece. You, mostly." },
	{ "Ah, la civilisation ! Et ses marchands.", "Ah, civilisation! And its vendors." },
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
}
P.DEAD = {
	{ "Aïe… Je t'attends, prends ton temps.", "Ouch… I'll wait for you, take your time." },
	{ "Oups. Je garde ton sac, promis.", "Oops. I'll guard your bag, promise." },
	{ "Ça arrive aux meilleurs. Je reste ici.", "Happens to the best of us. I'll stay right here." },
	{ "Respire… enfin, quand tu pourras. Je suis là.", "Breathe… well, when you can. I'm here." },
	{ "On retentera, ensemble. Pas de souci.", "We'll try again, together. No worries." },
}
P.REZ = {
	{ "Te revoilà ! Tu m'as fait une de ces peurs.", "You're back! You gave me quite a scare." },
	{ "Debout ! On reprend là où on en était ?", "Up you get! Pick up where we left off?" },
	{ "Bon retour parmi les vivants !", "Welcome back to the living!" },
	{ "Ouf. Je savais que tu reviendrais.", "Phew. I knew you'd come back." },
	{ "On souffle un coup et on repart ?", "Catch your breath and off again?" },
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
}
P.READY = {   -- %s = nom du prochain stade
	{ "Je me sens prêt à devenir %s… il me faut juste être bien.", "I feel ready to become %s… I just need to feel good." },
	{ "Ça me chatouille partout : bientôt %s ! Prends soin de moi ?", "Everything tingles: soon %s! Take care of me?" },
	{ "Je peux devenir %s ! Un bon repas, du repos, un peu d'aventure…", "I can become %s! A good meal, some rest, a bit of adventure…" },
}
P.CHEST = {   -- %s = nom de la zone
	{ "On a tout vu de %s ! Un coffre pour toi… pour nous !", "We've seen all of %s! A chest for you… for us!" },
	{ "%s, terminé ! Ouvre le coffre, je veux voir !", "%s, done! Open the chest, I want to see!" },
	{ "Tout %s dans le carnet. On a bien mérité un coffre.", "All of %s in the journal. We've earned a chest." },
}
P.EVOLVE = {  -- %s = nom du stade
	{ "Je grandis ! Me voilà %s !", "I'm growing! Now I'm %s!" },
	{ "Regarde-moi ! Je deviens %s !", "Look at me! I'm becoming %s!" },
	{ "Ça pousse ! Me voilà %s, grâce à toi.", "Growing up! Now I'm %s, thanks to you." },
	{ "Nouveau moi : %s ! Je me trouve très beau.", "New me: %s! I look rather dashing." },
}
P.UNLOCK = {  -- %s = cosmétique débloqué
	{ "Regarde : %s !", "Look: %s!" },
	{ "Pour moi ? %s ! Merci !", "For me? %s! Thank you!" },
	{ "Nouveau : %s ! Je me sens tout chic.", "New: %s! I feel so fancy." },
	{ "%s ! On le montre à tout le monde ?", "%s! Shall we show everyone?" },
}
P.QUEST = {
	{ "Mission accomplie !", "Mission complete!" },
	{ "Et une de plus ! Quel talent.", "Another one done! Such talent." },
	{ "Quête rendue ! J'espère que la récompense se mange.", "Quest done! I hope the reward is edible." },
	{ "Bravo ! Il te doit une fière chandelle.", "Well done! They owe you big time." },
	{ "Encore un problème réglé grâce à toi.", "One more problem solved, thanks to you." },
	{ "Je l'avais dit : du gâteau !", "Told you: piece of cake!" },
	{ "Une quête rendue, un sourire gagné.", "One quest turned in, one smile earned." },
}
P.LOOT = {
	{ "Oh, ça brille !", "Ooh, shiny!" },
	{ "Ooh, un trésor ! On le garde ?", "Ooh, treasure! Are we keeping it?" },
	{ "Ça, c'est une belle trouvaille !", "Now that's a nice find!" },
	{ "Je savais qu'il cachait quelque chose.", "I knew it was hiding something." },
	{ "Brillant, précieux… presque autant que moi.", "Shiny, precious… almost as much as me." },
	{ "Jolie prise ! Tu as l'œil.", "Nice catch! You've got the eye." },
}
P.STAMP = {   -- %s = nom du tampon
	{ "Un tampon de plus : %s !", "One more stamp: %s!" },
	{ "Hop, dans le carnet : %s !", "Into the journal it goes: %s!" },
	{ "%s : tamponné ! Quelle collection.", "%s: stamped! What a collection." },
	{ "Le carnet grossit : %s !", "The journal grows: %s!" },
	{ "Souvenir de voyage : %s.", "Travel memory: %s." },
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
}
P.CITY = {    -- %s = nom de la capitale (facultatif dans le texte)
	{ "%s ! Que de monde, reste près de moi.", "%s! So many people, stay close." },
	{ "La grande ville ! J'ai peur de me perdre.", "The big city! I might get lost." },
	{ "Ici, il y a tout : maîtres, banque, marchands.", "Everything's here: trainers, bank, vendors." },
	{ "Ça grouille ! Tiens-moi la patte.", "It's bustling! Hold my paw." },
	{ "Bienvenue à %s ! Je fais le guide ? Non, je me perdrais.", "Welcome to %s! Shall I guide? No, I'd get lost." },
}
P.VILLAGE = { -- %s = nom du village
	{ "Un village ! Ça sent le pain et le foin.", "A village! Smells of bread and hay." },
	{ "%s : coin tranquille, j'aime bien.", "%s: quiet spot, I like it." },
	{ "On souffle un peu ici ? Il y a sûrement une auberge.", "A breather here? Surely there's an inn." },
	{ "Des gens gentils, des maisons… et des quêtes, je parie.", "Kind folk, houses… and quests, I bet." },
	{ "Halte à %s ! Je dis bonjour à tout le monde.", "Stop at %s! I'm saying hi to everyone." },
}
P.INN = {
	{ "Une auberge… petite sieste ?", "An inn… little nap?" },
	{ "Ça sent la soupe ! On reste un peu ?", "Smells like soup! Shall we stay a bit?" },
	{ "Un vrai lit ! Je réserve le coin de l'oreiller.", "A real bed! I call the corner of the pillow." },
	{ "Ici, tu gagnes de l'expérience reposée en dormant.", "Here you build rested experience while you sleep." },
	{ "Une auberge : chaud, sec, et plein de gens bavards.", "An inn: warm, dry, and full of chatty folk." },
}
P.CAMP = {
	{ "On se réchauffe ?", "Shall we warm up?" },
	{ "Un feu de camp ! Je m'installe tout près.", "A campfire! I'm sitting right up close." },
	{ "Ça crépite… j'adore ce bruit.", "Crackle crackle… love that sound." },
	{ "Une pause au coin du feu, ça te dit ?", "A fireside break, fancy it?" },
	{ "Raconte-moi une histoire au coin du feu !", "Tell me a fireside story!" },
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
}
P.DRINK = {
	{ "Glou glou ! L'eau, c'est la vie.", "Glug glug! Water is life." },
	{ "Une petite gorgée, et ça repart !", "A little sip and we're off again!" },
	{ "Tu bois, je te regarde. C'est mon travail.", "You drink, I watch. It's my job." },
	{ "Rafraîchissant ! Garde de l'eau pour la route.", "Refreshing! Keep some water for the road." },
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
}
P.NPC_innkeeper = {
	{ "Un aubergiste ! Ça sent le pain chaud.", "An innkeeper! Smells of warm bread." },
	{ "%s a une tête de bon vivant. J'aime bien.", "%s looks like good company. I like them." },
	{ "Tu te lies ici ? C'est un bon coin où revenir.", "Binding here? Nice place to come back to." },
	{ "Demande-lui s'il reste de la soupe !", "Ask if there's any soup left!" },
	{ "Les aubergistes savent tout. Mais ils ne disent rien.", "Innkeepers know everything. They just don't tell." },
}
P.NPC_trainer = {
	{ "Un maître ! Apprends-moi aussi, je prends des notes.", "A trainer! Teach me too, I'm taking notes." },
	{ "%s a l'air sévère… mais juste.", "%s looks strict… but fair." },
	{ "De nouveaux sorts ? Fais-moi une démonstration !", "New spells? Give me a demo!" },
	{ "Ça coûte cher, le savoir. Mais ça vaut le coup.", "Knowledge is pricey. Worth it, though." },
	{ "Écoute bien, je te ferai réciter après.", "Listen well, I'll quiz you later." },
}
P.NPC_flight = {
	{ "On s'envole ? Je m'accroche à ton sac !", "Flying off? I'm holding on to your bag!" },
	{ "%s s'occupe bien de ses montures, ça se voit.", "%s takes good care of the mounts, you can tell." },
	{ "Vu d'en haut, tout a l'air minuscule. Même toi.", "From up there, everything looks tiny. Even you." },
	{ "Un vol ? J'espère avoir la place près du hublot.", "A flight? Hope I get the window seat." },
	{ "La route du ciel ! Bien plus rapide à pied.", "The sky road! Much faster than walking." },
}
P.NPC_banker = {
	{ "Un banquier ! Range bien tes trésors.", "A banker! Tuck your treasures away." },
	{ "%s compte vite. Très vite. Trop vite ?", "%s counts fast. Very fast. Too fast?" },
	{ "Dépose ce qui encombre tes sacs, tu respireras.", "Drop off what clutters your bags. Breathe easy." },
	{ "Tout est en sécurité ici. Même mes biscuits ?", "It's all safe here. Even my biscuits?" },
	{ "J'adore la banque : ça sent les vieilles pièces.", "I love the bank: smells of old coins." },
}
P.NPC_quest = {
	{ "Encore quelqu'un qui a besoin de toi !", "Someone else needs you!" },
	{ "%s a l'air inquiet. On l'aide ?", "%s looks worried. Shall we help?" },
	{ "Une quête ! Dis oui, dis oui !", "A quest! Say yes, say yes!" },
	{ "Lis bien, je n'ai pas compris la moitié.", "Read carefully, I missed half of it." },
	{ "Ça sent l'aventure… et peut-être les sangliers.", "Smells like adventure… and maybe boars." },
	{ "%s compte sur toi. Moi aussi !", "%s is counting on you. So am I!" },
}
P.NPC_talk = {
	{ "Quelqu'un de bavard ! J'adore les potins.", "A chatterbox! I love gossip." },
	{ "%s a l'air sympathique. On papote ?", "%s seems nice. Shall we chat?" },
	{ "Demande-lui s'il connaît un bon coin pour goûter.", "Ask if they know a good snack spot." },
	{ "Hmm… je ne sais pas quoi en penser. Je reste poli.", "Hmm… not sure what to think. I'll stay polite." },
	{ "Encore une rencontre ! Le monde est plein de gens.", "Another encounter! The world is full of people." },
}
P.NPC_CT_undead = {
	{ "Il sent un peu le caveau, mais il a l'air gentil.", "Smells a bit like a crypt, but seems nice." },
	{ "%s a perdu quelques couleurs… et un peu de peau.", "%s has lost some colour… and a bit of skin." },
	{ "Je ne fixe pas ses os. Je ne fixe pas ses os.", "Not staring at the bones. Not staring at the bones." },
}
P.NPC_CT_beast = {
	{ "Une bête qui parle ? Ou alors c'est moi ?", "A talking beast? Or is it me?" },
	{ "On se renifle d'abord, c'est la politesse.", "Sniff first, that's manners." },
	{ "Lui, je le comprends. On est collègues.", "This one I get. We're colleagues." },
}
P.NPC_CT_demon = {
	{ "Des cornes et un sourire. Je n'aime pas trop ça.", "Horns and a smile. Not a fan." },
	{ "Garde ta bourse près de toi avec %s.", "Keep your purse close around %s." },
	{ "Ça sent le soufre… mais poliment.", "Smells of brimstone… politely." },
}
P.NPC_CT_dragonkin = {
	{ "Un cousin éloigné ! Enfin… très éloigné.", "A distant cousin! Well… very distant." },
	{ "%s a de belles écailles. Je suis jaloux.", "%s has lovely scales. I'm jealous." },
	{ "Parle doucement, les dragons ont l'oreille fine.", "Speak softly, dragons hear everything." },
}
P.NPC_CT_elemental = {
	{ "Il est fait de quoi, au juste ? De vent ?", "What's it even made of? Wind?" },
	{ "Je ne m'approche pas trop, j'ai peur de fondre.", "Not getting too close, I might melt." },
	{ "%s brille un peu. C'est normal ?", "%s glows a bit. Is that normal?" },
}
P.NPC_CT_mechanical = {
	{ "Bip boup ? Je crois qu'il m'a compris.", "Beep boop? I think it understood me." },
	{ "%s fait tic-tac. Il faut le remonter ?", "%s ticks. Does it need winding?" },
	{ "Une machine qui parle ! Les gnomes sont fous.", "A talking machine! Gnomes are mad." },
}
P.NPC_CT_giant = {
	{ "Lève la tête… encore… encore… voilà.", "Look up… more… more… there." },
	{ "%s est grand. Très grand. Je reste derrière toi.", "%s is big. Very big. I'll stay behind you." },
}
P.NPC_CT_critter = {
	{ "Oh, un tout petit ! On devient amis ?", "Aww, a tiny one! Friends?" },
	{ "Celui-là, je peux le regarder dans les yeux.", "This one I can look in the eye." },
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
}
P.NIGHT = {
	{ "Il fait nuit… regarde les étoiles !", "It's night… look at the stars!" },
	{ "La nuit, tout fait un peu peur. Sauf toi.", "Everything's a bit spooky at night. Except you." },
	{ "Chut… la nuit, même les loups chuchotent.", "Shh… at night, even wolves whisper." },
	{ "Une balade au clair de lune, c'est joli, non ?", "A moonlit stroll, lovely, isn't it?" },
}

-- ---------------------------------------------------------------------------
-- Besoins exprimés (jamais de reproche : une envie, pas une plainte)
-- ---------------------------------------------------------------------------
P.NEED_hunger = {
	{ "J'ai un petit creux… on s'arrête manger ?", "I'm a bit peckish… snack stop?" },
	{ "Mon ventre fait des bruits rigolos. Une pause repas ?", "My tummy's making funny noises. Lunch break?" },
	{ "Quand tu manges, je me régale aussi, tu sais.", "When you eat, I get a treat too, you know." },
	{ "Un bout de pain, et je repars comme neuf !", "A bit of bread and I'm good as new!" },
}
P.NEED_energy = {
	{ "Je tombe de sommeil… une auberge, peut-être ?", "I'm so sleepy… an inn, maybe?" },
	{ "Un coin de repos, une sieste, et je suis à toi.", "A resting spot, a nap, and I'm all yours." },
	{ "Mes petites pattes fatiguent. On se pose un moment ?", "My little legs are tired. Sit a while?" },
	{ "Bâille… pardon. On se repose bientôt ?", "Yawn… sorry. Rest soon?" },
}
P.NEED_mood = {
	{ "Tu me fais un câlin ? Juste un petit.", "A cuddle? Just a tiny one?" },
	{ "Raconte-moi une quête ! Une qui finit bien.", "Tell me a quest! One with a happy ending." },
	{ "Une quête rendue, ça me ferait sourire.", "A quest turned in would make me smile." },
	{ "Tu es là, c'est déjà bien. Mais un câlin…", "You're here, that's already great. But a cuddle…" },
}
P.NEED_curiosity = {
	{ "On n'a rien vu de neuf depuis longtemps… on explore ?", "Haven't seen anything new in ages… explore?" },
	{ "Et si on allait voir derrière cette colline ?", "What if we peeked behind that hill?" },
	{ "Un nouveau coin sur la carte, ça te tente ?", "A new spot on the map, fancy it?" },
	{ "J'ai envie de découvrir un endroit inconnu !", "I'm itching to discover somewhere new!" },
}

-- ---------------------------------------------------------------------------
-- Objectifs : le prochain déblocage (%s = reste, %s = récompense)
-- ---------------------------------------------------------------------------
P.GOAL = {
	{ "Encore %s et j'aurai : %s !", "%s more and I'll get: %s!" },
	{ "Plus que %s avant %s. On y va ?", "Just %s to go before %s. Shall we?" },
	{ "Psst : encore %s et je débloque %s.", "Psst: %s more and I unlock %s." },
}
P.GOAL_STAGE = {
	{ "Encore %s et je deviendrai %s !", "%s more and I'll become %s!" },
	{ "Dans %s, je serai %s. J'ai hâte !", "In %s, I'll be %s. Can't wait!" },
}

-- ---------------------------------------------------------------------------
-- Astuces de progression (liées à l'addon et au jeu), jamais en combat
-- ---------------------------------------------------------------------------
P.TIP = {
	{ "Astuce : lie-toi à l'auberge du village, ta pierre de foyer t'y ramènera.", "Tip: bind at the village inn, your hearthstone will bring you back." },
	{ "Astuce : /qc options règle mes bulles et mes astuces.", "Tip: /qc options sets my bubbles and my tips." },
	{ "Astuce : le carnet compte les ennemis rares que TU as engagés.", "Tip: the journal counts the rares YOU actually engaged." },
	{ "Astuce : /qc ouvre mon carnet, un clic droit sur moi aussi.", "Tip: /qc opens my journal, and so does a right-click on me." },
	{ "Astuce : déconnecte-toi à l'auberge pour gagner de l'expérience reposée.", "Tip: log out at an inn to build rested experience." },
	{ "Astuce : les quêtes grises ne rapportent presque plus d'expérience.", "Tip: grey quests give almost no experience." },
	{ "Astuce : manger et boire en même temps fait repartir plus vite.", "Tip: eating and drinking together gets you going faster." },
	{ "Astuce : répare ton équipement en ville avant une longue sortie.", "Tip: repair your gear in town before a long trip." },
	{ "Astuce : regroupe les quêtes d'une même zone, moins de trajets.", "Tip: group quests from one area, less walking." },
	{ "Astuce : ton maître de classe a du nouveau tous les deux niveaux.", "Tip: your class trainer has something new every two levels." },
	{ "Astuce : un plus grand sac, c'est moins d'allers-retours.", "Tip: a bigger bag means fewer round trips." },
	{ "Astuce : garde une potion de soins pour les mauvaises surprises.", "Tip: keep a healing potion for nasty surprises." },
	{ "Astuce : chaque nouveau lieu ajoute un tampon au carnet (/qc carnet).", "Tip: every new place adds a journal stamp (/qc carnet)." },
	{ "Astuce : les tampons du carnet débloquent mes apparences et ornements.", "Tip: journal stamps unlock my looks and ornaments." },
	{ "Astuce : survole-moi pour voir ma faim, mon énergie, mon moral, ma curiosité.", "Tip: hover me to see my hunger, energy, mood and curiosity." },
	{ "Astuce : tu peux me renommer avec /qc compagnon nom.", "Tip: you can rename me with /qc compagnon nom." },
	{ "Astuce : parle à chaque maître de vol croisé, ça fait gagner un temps fou.", "Tip: talk to every flight master you pass, huge time saver." },
	{ "Astuce : un ennemi bien plus fort que toi ? Mieux vaut le contourner.", "Tip: enemy far above you? Better go around." },
	{ "Astuce : relis l'objectif, un objet de quête tombe parfois d'un seul type d'ennemi.", "Tip: reread objectives, quest items sometimes drop from one enemy type." },
	{ "Astuce : un métier de récolte rapporte de l'or en chemin.", "Tip: a gathering profession earns gold along the way." },
	{ "Astuce : rends tes quêtes avant de partir, le check te le rappelle.", "Tip: turn in quests before leaving, the check reminds you." },
	{ "Astuce : deux donjons visités, et je change d'allure !", "Tip: visit two dungeons and I get a new look!" },
	{ "Astuce : le résumé de stuff montre ce que t'apporte un nouvel objet.", "Tip: the gear summary shows what a new item gives you." },
	{ "Astuce : flèches, balles ou réactifs ? Fais le plein avant de partir.", "Tip: arrows, bullets or reagents? Stock up before leaving." },
	{ "Astuce : l'auberge et la ville me redonnent de l'énergie.", "Tip: inns and towns restore my energy." },
	{ "Astuce : je ne t'en veux jamais. Absent ? Je somnole et je t'attends.", "Tip: I never hold a grudge. Away? I just doze and wait." },
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
	{ "Les tampons du carnet (/qc carnet) débloquent mes apparences et ornements.", "Journal stamps (/qc carnet) unlock my looks and ornaments." },
	{ "En route, je te préviens : sacs pleins, vivres, réparations, munitions, un élite dans le coin…", "On the road, I'll warn you: full bags, food, repairs, ammo, an elite nearby…" },
	{ "Je parle trop ? Pas assez ? Règle-moi avec la réglette « Bavardage », page Compagnon.", "Too chatty? Not enough? Tune me with the \"Chattiness\" slider, Companion page." },
	{ "Pour me personnaliser : réglages, page Compagnon. Et je ne me fâche jamais !", "To customise me: settings, Companion page. And I never get cross!" },
}

-- ---------------------------------------------------------------------------
-- Conseils de route (Advice.lua) : %s = nom, %d = nombre ou pourcentage
-- ---------------------------------------------------------------------------
P.ADVICE_ELITE = {
	{ "Attention, %s par là ! C'est un élite, ça pique.", "Careful, %s over there! It's an elite, it bites." },
	{ "%s… celui-là est costaud, on le contourne ?", "%s… that one's tough, shall we go around?" },
}
P.ADVICE_RARE = {
	{ "Oh, %s ! Un rare, mais il a l'air coriace.", "Oh, %s! A rare, but it looks tough." },
	{ "%s rôde par ici : rare, et plus fort que toi.", "%s is prowling around: rare, and stronger than you." },
}
P.ADVICE_HEALTH = {
	{ "Ouf… tu es bien amoché. On se pose un peu ?", "Phew… you're badly hurt. Shall we rest a bit?" },
	{ "Mange un morceau avant de repartir, tu en as besoin.", "Have a bite before moving on, you need it." },
}
P.ADVICE_AMMO = {
	{ "Plus que %d munitions, pense à en racheter.", "Only %d ammo left, think about buying more." },
	{ "%d munitions… ça va partir vite.", "%d ammo… that won't last long." },
}
P.ADVICE_AMMO_EMPTY = {
	{ "On est presque à sec de munitions (%d) : sans elles, pas de tir !", "We're nearly out of ammo (%d): no ammo, no shooting!" },
	{ "Plus que %d munitions, il faut vraiment rentrer.", "Only %d ammo left, we really need to head back." },
}
P.ADVICE_AMMO_UNEQUIPPED = {
	{ "Tes munitions sont dans le sac (%d), pas dans ton emplacement de munitions !", "Your ammo is in your bag (%d), not in your ammo slot!" },
}
P.ADVICE_FOOD = {
	{ "Il ne reste que %d de quoi manger, et on est loin du village.", "Only %d bites of food left, and we're far from town." },
	{ "Plus que %d vivres… on en garde pour plus tard ?", "Just %d food left… shall we save some?" },
}
P.ADVICE_FOOD_EMPTY = {
	{ "Plus rien à manger… on rentre faire des provisions ?", "Nothing left to eat… head back for supplies?" },
}
P.ADVICE_DURA = {
	{ "Ton équipement souffre (%d %%), pense à réparer.", "Your gear is suffering (%d %%), think about repairs." },
	{ "Ton armure s'use : %d %%, un forgeron serait le bienvenu.", "Your armor is wearing out: %d %%, a blacksmith would be welcome." },
}
P.ADVICE_DURA_CRIT = {
	{ "Ton équipement va casser (%d %%) ! Il faut réparer.", "Your gear is about to break (%d %%)! Time to repair." },
}
P.ADVICE_BAGS = {
	{ "Plus que %d places dans les sacs… on garde quoi ?", "Only %d bag slots left… what do we keep?" },
	{ "Les sacs se remplissent : %d places libres.", "Bags are filling up: %d free slots." },
}
P.ADVICE_BAGS_LAST = {
	{ "Dernière place dans les sacs !", "Last free bag slot!" },
}
P.ADVICE_BAGS_FULL = {
	{ "Les sacs sont pleins, le prochain butin restera par terre !", "Bags are full, the next loot stays on the ground!" },
}
P.ADVICE_QUESTS = {
	{ "Tout est fini ici : on rentre rendre les quêtes ?", "All done here: shall we go turn in the quests?" },
	{ "Toutes tes quêtes sont prêtes à rendre !", "All your quests are ready to turn in!" },
}
P.ADVICE_HEARTH = {
	{ "Ta pierre de foyer est prête. On rentre ?", "Your hearthstone is ready. Going home?" },
	{ "Le foyer est rechargé, et on est bien chargés : retour à l'auberge ?", "The hearthstone is back, and we're loaded: back to the inn?" },
}

-- ---------------------------------------------------------------------------
-- En groupe (Group.lua) : %s = nom (ou carte), %d = niveaux d'écart
-- ---------------------------------------------------------------------------
P.GROUP_NO_HEALER = {
	{ "Pas de soigneur dans le groupe… prévoyez des potions !", "No healer in the group… bring potions!" },
	{ "Personne pour soigner : on y va doucement ?", "Nobody to heal: shall we take it slow?" },
}
P.GROUP_BALANCED = {
	{ "Bel équipage ! Un soigneur, du monde : on est prêts.", "Nice crew! A healer, enough people: we're ready." },
}
P.GROUP_LOW_LEVEL = {
	{ "%s est %d niveau(x) sous ce donjon, gardez un œil sur lui.", "%s is %d level(s) below this dungeon, keep an eye on them." },
}
P.GROUP_IN_RANGE = {
	{ "Tout le groupe a le niveau de ce donjon, en route !", "The whole group fits this dungeon, let's go!" },
}
P.GROUP_BEHIND = {
	{ "%s est resté en arrière, on l'attend ?", "%s fell behind, shall we wait?" },
	{ "On a perdu %s de vue…", "We've lost sight of %s…" },
}
P.GROUP_ELSEWHERE = {
	{ "Il manque %s, encore à %s.", "%s is missing, still in %s." },
}
P.GROUP_DEAD = {
	{ "Paix à %s… on l'attend ?", "Rest in peace, %s… shall we wait?" },
	{ "Oh non, %s est tombé !", "Oh no, %s went down!" },
}
P.GROUP_HEALER_DEAD = {
	{ "%s est tombé : plus de soins, prudence !", "%s went down: no more heals, careful!" },
}
P.GROUP_OFFLINE = {
	{ "%s s'est déconnecté.", "%s disconnected." },
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
}
P.RECALL = {  -- %s = le souvenir
	{ "Tu te souviens ? %s", "Remember? %s" },
	{ "Je repensais à ça : %s", "I was thinking about this: %s" },
	{ "Ah, le bon vieux temps… %s", "Ah, the good old days… %s" },
	{ "Dans mon album, j'aime bien celui-là : %s", "In my album, I like this one: %s" },
}
P.ANNIV = {  -- %s = la durée (« une semaine »)
	{ "Ça fait %s qu'on voyage ensemble !", "We've been travelling together for %s!" },
	{ "Déjà %s ensemble ! Merci de m'emmener partout.", "%s together already! Thanks for taking me everywhere." },
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
ns.COMPANION_LINE_STRINGS = { fr = FR, en = EN }   -- exposé aux tests (parité fr/en)

if ns.Mark then ns.Mark("CompanionLines") end
