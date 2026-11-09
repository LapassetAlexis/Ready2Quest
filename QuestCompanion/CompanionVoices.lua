-- CompanionVoices.lua -- 2.13.0 : les « voix » du compagnon
--
-- Une créature capturée parle selon SON type (bête, mort-vivant, démon…) :
-- pour une situation, CompanionVoicePick mêle les lignes de la voix
-- (« <RÉSERVOIR>_V_<type> ») aux lignes communes. Le caractère colore la voix
-- par-dessus (« <RÉSERVOIR>_V_<type>_<caractère> », quelques situations).
-- Mascotte, compagnon de départ, type inconnu : la voix commune seule.
--
-- Textes : même source paresseuse que CompanionLines.lua (une seule langue
-- gardée sur le client). Arguments : ceux du réservoir commun (le nom pour
-- CAPTURE_*, SHINY_SPOTTED, CITY, DUNGEON, KILL quand il est connu ; le
-- niveau pour LEVEL). Une ligne à « %s » sans argument est écartée.
local ADDON, ns = ...
if ns.blocked then return end

-- part des bulles prises dans la voix, puis dans la touche de caractère
ns.COMPANION_VOICE_SHARE = 0.6
ns.COMPANION_VOICE_TRAIT_SHARE = 0.4

ns.COMPANION_VOICE_TYPES = { "beast", "undead", "demon", "elemental", "dragonkin", "mechanical", "giant", "humanoid", "critter" }

-- les 12 situations de la planche, et leurs réservoirs de voix
ns.COMPANION_VOICE_SITUATIONS = {
	{ "HELLO" }, { "KILL" }, { "CAPTURE_OK" }, { "CAPTURE_FAIL" }, { "SHINY_SPOTTED" }, { "LEVEL" },
	{ "ADVICE_HEALTH" }, { "EAT" }, { "CITY", "DUNGEON" }, { "NIGHT" }, { "DEAD", "REZ" }, { "IDLE" },
}

-- réservoir commun -> réservoir de voix
local VOICE_OF = {
	HELLO = "HELLO", MISSED = "HELLO", AWAKE = "HELLO",
	KILL = "KILL", CAPTURE_OK = "CAPTURE_OK", CAPTURE_SHINY = "CAPTURE_OK", CAPTURE_FAIL = "CAPTURE_FAIL",
	SHINY_SPOTTED = "SHINY_SPOTTED", LEVEL = "LEVEL", ADVICE_HEALTH = "ADVICE_HEALTH",
	EAT = "EAT", DRINK = "EAT", CITY = "CITY", DUNGEON = "DUNGEON", NIGHT = "NIGHT",
	DEAD = "DEAD", REZ = "REZ", IDLE = "IDLE",
}
ns.COMPANION_VOICE_OF = VOICE_OF

local P = {}
-- clé « KILL » : la voix ; « KILL/teasing » : sa touche de caractère
local function Voice(kind, lines)
	for situ, list in pairs(lines) do
		local base, trait = situ:match("^(.-)/(.+)$")
		P[(base or situ) .. "_V_" .. kind .. (trait and ("_" .. trait) or "")] = list
	end
end

-- ---------------------------------------------------------------------------
-- Bête : instinct, flair, meute, chasse
-- ---------------------------------------------------------------------------
Voice("beast", {
	HELLO = {
		{ "Ton odeur ! Je la reconnaîtrais entre mille. On chasse ?", "Your scent! I'd know it anywhere. Shall we hunt?" },
		{ "Grrr… ah, c'est toi. La meute est au complet.", "Grrr… oh, it's you. The pack is complete." },
		{ "J'ai flairé ton retour avant de te voir. Le vent me dit tout.", "I smelled you coming before I saw you. The wind tells me everything." },
	},
	KILL = {
		{ "Belle prise ! Je garde les os pour plus tard.", "Nice catch! I'll save the bones for later." },
		{ "%s ne courait pas assez vite. C'est la loi de la forêt.", "%s wasn't fast enough. Law of the forest." },
		{ "La meute a chassé, la meute a gagné. Aouuu !", "The pack hunted, the pack won. Awooo!" },
	},
	["KILL/daring"] = {
		{ "Encore ! Lance-m'en un autre, je cours !", "Again! Throw me another one, I'll run!" },
		{ "Je l'avais repéré avant toi. La prochaine, je mène l'attaque.", "I spotted it before you did. Next one, I lead the charge." },
	},
	CAPTURE_OK = {
		{ "%s rejoint la meute. Je lui montrerai où on enterre les os.", "%s joins the pack. I'll show it where we bury the bones." },
		{ "Attrapé ! Je l'ai rabattu vers toi, tu as vu ? Tu as vu ?", "Got it! I herded it your way, did you see? Did you see?" },
		{ "Je renifle %s… Odeur validée. Bienvenue.", "Sniffing %s… Scent approved. Welcome." },
	},
	CAPTURE_FAIL = {
		{ "Il a filé ! Laisse-moi le pister, je le retrouve en trois bonds.", "It bolted! Let me track it, three leaps and I've got it." },
		{ "Raté… Tu étais sous le vent, il t'a senti venir.", "Missed… You were upwind, it smelled you coming." },
		{ "Grr. %s se croit plus malin que nous. On verra.", "Grr. %s thinks it's smarter than us. We'll see." },
	},
	SHINY_SPOTTED = {
		{ "Ça brille, là-bas ! Mes poils se dressent tout seuls.", "Something's shining over there! My fur's standing on end." },
		{ "Une odeur que je ne connais pas… %s ! Une brillante !", "A scent I don't know… %s! A shiny one!" },
		{ "Chut. Ne bouge plus. Proie brillante en vue.", "Shh. Freeze. Shiny prey in sight." },
	},
	LEVEL = {
		{ "Niveau %s ! Tu deviens un vrai chef de meute.", "Level %s! You're becoming a real pack leader." },
		{ "Tu sens plus fort. Euh, tu ES plus fort. Bravo !", "You smell stronger. Er, you ARE stronger. Well done!" },
		{ "Aouuuu ! C'est mon hurlement de fête. Niveau %s !", "Awoooo! That's my party howl. Level %s!" },
	},
	ADVICE_HEALTH = {
		{ "Tu sens le sang. Le tien. Ça ne me plaît pas.", "You smell of blood. Yours. I don't like it." },
		{ "Une bête blessée se cache pour guérir. Fais pareil.", "A wounded beast hides to heal. Do the same." },
		{ "Je lèche tes plaies ? Non ? Alors mange quelque chose.", "Shall I lick your wounds? No? Then eat something." },
	},
	EAT = {
		{ "Ça sent bon ! Un morceau pour moi ? Juste un petit ?", "Smells good! A bite for me? Just a tiny one?" },
		{ "Je monte la garde pendant que tu manges. Rien ne s'approche.", "I'll keep watch while you eat. Nothing gets close." },
		{ "Repos de la meute. Je tourne trois fois et je me couche.", "Pack rest. I'll turn around three times and lie down." },
	},
	CITY = {
		{ "%s… Trop d'odeurs ! Du pain, du cuir, des chiens. Beaucoup de chiens.", "%s… Too many smells! Bread, leather, dogs. Lots of dogs." },
		{ "Des murs partout. Je reste collé à toi, d'accord ?", "Walls everywhere. I'm sticking close to you, okay?" },
	},
	DUNGEON = {
		{ "Une tanière. Quelque chose de gros dort au fond. Je le sens.", "A den. Something big sleeps at the back. I can smell it." },
		{ "%s… Ça pue la peur et le rat. Restons en meute.", "%s… Reeks of fear and rats. Let's stay in a pack." },
	},
	NIGHT = {
		{ "La lune est haute. Mes ancêtres hurlent dans mon sang.", "The moon is high. My ancestors howl in my blood." },
		{ "La nuit, je vois mieux que toi. Suis mes yeux qui brillent.", "At night I see better than you. Follow my glowing eyes." },
		{ "C'est l'heure de la chasse. Ou de la sieste. Les deux se valent.", "It's hunting time. Or nap time. Both are fine." },
	},
	DEAD = {
		{ "Non ! Debout ! Je te lèche la figure jusqu'à ce que tu bouges !", "No! Get up! I'll lick your face until you move!" },
		{ "Je reste couché près de toi. Je ne bouge pas. Promis.", "I'll lie down next to you. I won't move. Promise." },
	},
	REZ = {
		{ "Tu reviens ! Ma queue remue toute seule !", "You're back! My tail's wagging on its own!" },
		{ "Ton odeur est revenue. Le monde sent bon à nouveau.", "Your scent is back. The world smells right again." },
	},
	IDLE = {
		{ "J'ai reniflé chaque arbre du coin. Rapport : un écureuil, très insolent.", "I've sniffed every tree around. Report: one squirrel, very rude." },
		{ "Tu crois que je pourrais attraper ma queue ? Juste pour voir.", "Think I could catch my tail? Just to see." },
		{ "Un bruit ! … Non, c'était mon ventre.", "A noise! … No, that was my stomach." },
	},
	["IDLE/cuddly"] = {
		{ "Gratte-moi derrière l'oreille. Non, l'autre. Voilà.", "Scratch behind my ear. No, the other one. There." },
		{ "Je me couche sur tes pieds. Comme ça, tu ne pars pas sans moi.", "I'm lying on your feet. That way you can't leave without me." },
	},
})

-- ---------------------------------------------------------------------------
-- Mort-vivant : humour macabre, détaché, un peu théâtral (planche validée)
-- ---------------------------------------------------------------------------
Voice("undead", {
	HELLO = {
		{ "Me revoilà ! Enfin… ce qu'il en reste.", "I'm back! Well… what's left of me." },
		{ "Tu m'as réveillé. Pour une fois que je dormais en paix.", "You woke me up. For once I was resting in peace." },
		{ "Bonne nouvelle : je n'ai rien perdu en route. Je crois. Attends que je compte mes os.", "Good news: I lost nothing on the way. I think. Let me count my bones." },
	},
	KILL = {
		{ "Bienvenue au club. On a des places assises.", "Welcome to the club. We have seats available." },
		{ "Ne t'inquiète pas, %s. Ce n'est pas si terrible, de l'autre côté.", "Don't worry, %s. It's not that bad on the other side." },
		{ "Encore un qui me rejoindra peut-être. On jouera aux osselets.", "Another one who might join me. We'll play knucklebones." },
	},
	["KILL/teasing"] = {
		{ "Il a l'air surpris. Ils ont tous l'air surpris.", "It looks surprised. They all look surprised." },
		{ "Allez, ne fais pas cette tête. Ah, il ne peut plus en faire.", "Come on, don't make that face. Ah, it can't anymore." },
	},
	["KILL/glutton"] = {
		{ "Dommage, je ne peux plus goûter. Il avait l'air croustillant.", "Shame I can't taste anymore. It looked crunchy." },
		{ "Je garde la mâchoire. La mienne a du jeu.", "I'm keeping the jaw. Mine's a bit loose." },
	},
	CAPTURE_OK = {
		{ "%s rejoint la collection. Comme moi, mais en plus frais.", "%s joins the collection. Like me, only fresher." },
		{ "Pris ! Personne ne s'échappe de mon filet. Ni de mon cimetière.", "Caught! No one escapes my net. Or my graveyard." },
		{ "Une nouvelle âme dans la famille. Je lui garderai une tombe… euh, une place.", "A new soul in the family. I'll keep it a grave… er, a spot." },
	},
	CAPTURE_FAIL = {
		{ "Il s'est enfui. Tant pis, il finira bien par venir à moi. Ils finissent tous par venir à moi.", "It ran off. Never mind, it'll come to me eventually. They all do." },
		{ "Raté. J'avais pourtant mis mon plus beau sourire. Celui sans lèvres.", "Missed. And I wore my best smile. The one without lips." },
		{ "Le filet a craqué. Comme mes genoux.", "The net snapped. Like my knees." },
	},
	SHINY_SPOTTED = {
		{ "Oh, une brillante ! Même moi, ça me ferait presque battre le cœur. Si j'en avais un.", "Oh, a shiny! Even I would feel my heart race. If I had one." },
		{ "Regarde comme elle luit… On dirait un feu follet. Mes cousins.", "Look at it glow… Like a will-o'-the-wisp. My cousins." },
		{ "Une brillante ! Vite, avant qu'un vivant ne nous la vole.", "A shiny! Quick, before some living fool steals it." },
	},
	LEVEL = {
		{ "Un niveau de plus ! Moi aussi je vieillis, mais personne ne me félicite.", "One more level! I'm ageing too, but nobody congratulates me." },
		{ "Bravo ! Tu deviens increvable. Bon, moi c'est déjà fait.", "Well done! You're becoming unkillable. Well, I already am." },
		{ "Niveau %s. À ce rythme, tu vas finir par me ressembler : éternel.", "Level %s. At this rate you'll end up like me: eternal." },
	},
	ADVICE_HEALTH = {
		{ "Tu pâlis. Ça te va bien, mais je préfère te garder parmi les vivants.", "You're turning pale. It suits you, but I'd rather keep you among the living." },
		{ "Attention ! Tu prends le chemin que j'ai pris. Je ne le conseille pas.", "Careful! You're taking the road I took. Wouldn't recommend it." },
		{ "Soigne-toi. Une seule momie dans l'équipe, c'est suffisant.", "Heal up. One mummy on the team is enough." },
	},
	EAT = {
		{ "Tu manges ? Je regarde. Je n'ai plus d'estomac, mais j'ai des souvenirs.", "You're eating? I'll watch. I've no stomach left, but I have memories." },
		{ "Repose-toi. Moi, je ne dors jamais vraiment. Je fais semblant.", "Rest. I never truly sleep. I pretend." },
		{ "Bon appétit. Évite la viande trop faisandée, ça me fait de la peine.", "Enjoy your meal. Avoid overripe meat, it hurts my feelings." },
	},
	CITY = {
		{ "Une ville. Beaucoup de vivants. Je vais faire profil bas.", "A city. So many living folks. I'll keep a low profile." },
		{ "%s… Je connais des gens enterrés ici. Enfin, je crois.", "%s… I know people buried here. I think." },
	},
	DUNGEON = {
		{ "Un donjon ! Sombre, humide, plein d'échos. On se croirait chez moi.", "A dungeon! Dark, damp, full of echoes. Feels like home." },
		{ "%s. Ça sent la crypte. J'adore la crypte.", "%s. Smells like a crypt. I love a crypt." },
	},
	NIGHT = {
		{ "La nuit tombe. Enfin mon heure.", "Night falls. Finally my time." },
		{ "Il fait noir ? Moi, je vois très bien. C'est l'avantage de ne plus avoir d'yeux.", "It's dark? I see just fine. Perks of having no eyes." },
		{ "Belle lune. Parfaite pour une petite promenade au cimetière.", "Lovely moon. Perfect for a stroll through the graveyard." },
	},
	DEAD = {
		{ "Tu es mort. Courant, ici. Ne t'en fais pas, ça passe.", "You died. Common around here. Don't worry, it passes." },
		{ "Ne bouge pas, je garde ton corps. J'ai l'habitude.", "Don't move, I'll guard your body. I'm used to it." },
	},
	REZ = {
		{ "Bienvenue de mon côté ! Ah, non, tu repars déjà ?", "Welcome to my side! Oh, you're leaving already?" },
		{ "Te revoilà vivant. Je suis content. Un peu jaloux, mais content.", "You're alive again. I'm glad. A little jealous, but glad." },
	},
	IDLE = {
		{ "Tu sais ce que j'aime chez toi ? Tu respires. C'est mignon.", "You know what I like about you? You breathe. It's cute." },
		{ "J'ai compté mes os pendant que tu marchais. Il en manque un. Ne t'inquiète pas.", "I counted my bones while you walked. One's missing. Don't worry." },
		{ "Si je tombe en morceaux, ramasse-moi, d'accord ?", "If I fall to pieces, pick me up, okay?" },
	},
	["IDLE/cuddly"] = {
		{ "Tu peux me faire un câlin. Doucement, je me détache facilement.", "You can hug me. Gently, I come apart easily." },
		{ "Je t'aime bien, toi. Ton cœur bat, c'est rassurant.", "I like you. Your heart beats, it's reassuring." },
	},
})

-- ---------------------------------------------------------------------------
-- Démon : sarcastique, vaguement menaçant, blagues de gangrène
-- ---------------------------------------------------------------------------
Voice("demon", {
	HELLO = {
		{ "Me revoilà. Tu as signé le contrat, je te rappelle. En petits caractères.", "I'm back. You signed the contract, remember. The fine print." },
		{ "Ah, mon mortel préféré. Enfin, le seul qui me nourrit.", "Ah, my favourite mortal. Well, the only one who feeds me." },
		{ "Tu m'as invoqué ? Non ? Je suis venu quand même.", "Did you summon me? No? I came anyway." },
	},
	KILL = {
		{ "Une âme de plus pour… euh, pour rien. Je ne collectionne plus.", "One more soul for… er, for nothing. I don't collect anymore." },
		{ "%s brûlera en bas. Je connais le gérant.", "%s will burn down below. I know the manager." },
		{ "Joli. Un soupçon de gangrène et c'était parfait.", "Nice. A dash of fel and it would've been perfect." },
	},
	["KILL/teasing"] = {
		{ "Il criait plus fort que toi la dernière fois. De peu.", "It screamed louder than you did last time. Barely." },
		{ "Tu as vu sa tête ? Je l'encadrerais bien au-dessus de la cheminée.", "Did you see its face? I'd frame it over the fireplace." },
	},
	CAPTURE_OK = {
		{ "%s est à nous. Pour toujours. Le contrat est clair.", "%s is ours. Forever. The contract is clear." },
		{ "Capturé ! Ne t'inquiète pas, je ne le mangerai pas. Pas tout de suite.", "Caught! Don't worry, I won't eat it. Not yet." },
		{ "Une âme liée de plus. Tu apprends vite, mortel.", "Another bound soul. You learn fast, mortal." },
	},
	CAPTURE_FAIL = {
		{ "Échappé ? Chez moi, on appelle ça une rupture de contrat.", "Escaped? Where I'm from, that's a breach of contract." },
		{ "%s s'est enfui. Je note son nom. Je note toujours les noms.", "%s ran away. I'm writing its name down. I always write names down." },
		{ "Raté. Tu aurais dû me laisser négocier.", "Missed. You should have let me negotiate." },
	},
	SHINY_SPOTTED = {
		{ "Une brillante ! On dirait un cristal de gangrène. En moins toxique.", "A shiny! Like a fel crystal. Less toxic." },
		{ "%s brille. Je veux. Non : NOUS voulons.", "%s is shining. I want it. No: WE want it." },
		{ "Oh, ça luit comme une âme toute fraîche. Vite !", "Ooh, it glows like a fresh soul. Quick!" },
	},
	LEVEL = {
		{ "Niveau %s. Ton pouvoir grandit. Excellent… je veux dire, bravo.", "Level %s. Your power grows. Excellent… I mean, well done." },
		{ "Encore un niveau. Bientôt, tu seras presque aussi fort que moi au réveil.", "Another level. Soon you'll be almost as strong as me before breakfast." },
		{ "Niveau %s ! Je t'offrirais bien un cadeau, mais il faudrait signer ici.", "Level %s! I'd give you a gift, but you'd have to sign here." },
	},
	ADVICE_HEALTH = {
		{ "Tu saignes. Si tu meurs, ton âme va à qui ? Je demande pour un ami.", "You're bleeding. If you die, who gets your soul? Asking for a friend." },
		{ "Soigne-toi. Je n'ai pas fini de profiter de toi.", "Heal up. I'm not done enjoying you." },
		{ "Tu as l'air presque aussi mal qu'un diablotin au bain.", "You look almost as bad as an imp in a bath." },
	},
	EAT = {
		{ "Tu manges ça ? Chez moi, la nourriture crie.", "You eat that? Back home, our food screams." },
		{ "Repose-toi. Je surveille. Je surveille toujours.", "Rest. I'm watching. I'm always watching." },
		{ "Bon appétit. Je me contenterai de ta peur. Elle est délicieuse.", "Enjoy. I'll make do with your fear. It's delicious." },
	},
	CITY = {
		{ "%s. Tant de mortels. Tant de… non, je reste sage. Promis.", "%s. So many mortals. So many… no, I'll behave. Promise." },
		{ "Une ville. Si un prêtre me regarde de travers, je n'étais pas là.", "A city. If a priest glares at me, I was never here." },
	},
	DUNGEON = {
		{ "Un donjon ! Ça sent le soufre. Enfin un endroit civilisé.", "A dungeon! Smells of brimstone. Finally, somewhere civilised." },
		{ "%s… Je connais l'architecte. Il me doit de l'argent.", "%s… I know the architect. He owes me money." },
	},
	NIGHT = {
		{ "La nuit. Mes yeux brillent en vert, c'est normal. Ne panique pas.", "Night. My eyes glow green, that's normal. Don't panic." },
		{ "Il fait noir. Parfait pour les mauvais coups. Je plaisante. Presque.", "It's dark. Perfect for mischief. Kidding. Mostly." },
		{ "Belle nuit pour invoquer quelque chose. Non ? Bon.", "Lovely night to summon something. No? Fine." },
	},
	DEAD = {
		{ "Tu es mort. Et ton âme ? Personne ne la réclame ? Je demande, c'est tout.", "You died. And your soul? Nobody's claiming it? Just asking." },
		{ "Pathétique. Mais je t'attends. Je ne suis pas un monstre. Enfin, si, un peu.", "Pathetic. But I'll wait. I'm not a monster. Well, a bit." },
	},
	REZ = {
		{ "Déjà de retour ? Dommage, j'avais rédigé ton contrat d'âme.", "Back already? Shame, I'd drafted your soul contract." },
		{ "Ressuscité. Tricheur. J'aime bien.", "Resurrected. Cheater. I like it." },
	},
	IDLE = {
		{ "Tu sais que je connais des sorts interdits ? Je dis ça comme ça.", "You know I know forbidden spells? Just saying." },
		{ "Je m'ennuie. Quand je m'ennuie, des choses prennent feu.", "I'm bored. When I'm bored, things catch fire." },
		{ "Petit conseil démoniaque : ne lis jamais les contrats. C'est plus drôle.", "Demonic tip: never read the contract. It's more fun." },
	},
	["IDLE/lazy"] = {
		{ "Semer le chaos, c'est épuisant. Je prends un siècle de congé.", "Spreading chaos is exhausting. Taking a century off." },
		{ "Réveille-moi s'il y a quelque chose à brûler.", "Wake me if there's something to burn." },
	},
})

-- ---------------------------------------------------------------------------
-- Élémentaire : calme, les éléments, la nature
-- ---------------------------------------------------------------------------
Voice("elemental", {
	HELLO = {
		{ "Le vent t'a ramené. Le vent ramène toujours ce qui compte.", "The wind brought you back. It always brings back what matters." },
		{ "Je t'attendais, comme la pierre attend la pluie. Sans hâte.", "I waited for you, as stone waits for rain. Unhurried." },
		{ "Bonjour. Les éléments sont calmes. Toi aussi, j'espère.", "Hello. The elements are calm. I hope you are too." },
	},
	KILL = {
		{ "Retour à la terre. Tout y retourne, tôt ou tard.", "Back to the earth. Everything returns, sooner or later." },
		{ "%s n'était qu'une flamme. Les flammes s'éteignent.", "%s was only a flame. Flames go out." },
		{ "L'équilibre est rétabli. Pour l'instant.", "Balance restored. For now." },
	},
	["KILL/daring"] = {
		{ "Encore ! Que la tempête se lève !", "More! Let the storm rise!" },
		{ "Je sens le tonnerre dans mes veines. Suivant !", "I feel thunder in my veins. Next!" },
	},
	CAPTURE_OK = {
		{ "%s rejoint le courant. Bienvenue, petite rivière.", "%s joins the current. Welcome, little river." },
		{ "Capturé sans bruit, comme la brume prend la vallée.", "Caught without a sound, as mist takes the valley." },
		{ "Un nouvel élément dans notre cercle. L'harmonie grandit.", "A new element in our circle. Harmony grows." },
	},
	CAPTURE_FAIL = {
		{ "Il nous a filé entre les doigts. Comme l'eau.", "It slipped through our fingers. Like water." },
		{ "%s n'était pas prêt. Le vent tournera.", "%s wasn't ready. The wind will turn." },
		{ "Patience. La montagne ne s'est pas faite en un jour.", "Patience. Mountains weren't made in a day." },
	},
	SHINY_SPOTTED = {
		{ "Regarde… %s porte la lumière des étoiles.", "Look… %s carries starlight." },
		{ "Une brillante. Les éléments chantent autour d'elle.", "A shiny. The elements are singing around it." },
		{ "Cette lueur… ce n'est pas un hasard. Approche doucement.", "That glow… it's no accident. Approach gently." },
	},
	LEVEL = {
		{ "Niveau %s. Tu grandis comme un chêne : lentement, mais sûrement.", "Level %s. You grow like an oak: slowly, but surely." },
		{ "Ton feu intérieur brûle plus fort. Je le sens d'ici.", "Your inner fire burns brighter. I can feel it from here." },
		{ "Niveau %s. La terre l'a remarqué. Elle remarque tout.", "Level %s. The earth noticed. It notices everything." },
	},
	ADVICE_HEALTH = {
		{ "Ta flamme vacille. Laisse-la reprendre son souffle.", "Your flame is flickering. Let it catch its breath." },
		{ "Assieds-toi. Même la tempête doit se reposer.", "Sit down. Even storms must rest." },
		{ "Tu t'effrites comme du grès. Soigne-toi, vite.", "You're crumbling like sandstone. Heal, quickly." },
	},
	EAT = {
		{ "Mange. La terre t'offre ce qu'elle a. Remercie-la.", "Eat. The earth offers what it has. Thank it." },
		{ "Le repos est une rivière calme. Laisse-toi porter.", "Rest is a calm river. Let it carry you." },
		{ "Bois. L'eau se souvient de tous ceux qu'elle a désaltérés.", "Drink. Water remembers everyone it has quenched." },
	},
	CITY = {
		{ "%s. Tant de pierre taillée… Elle aurait préféré rester montagne.", "%s. So much cut stone… It would rather have stayed a mountain." },
		{ "Une ville. Beaucoup de bruit, peu de vent. Je me fais petit.", "A city. Lots of noise, little wind. I'll make myself small." },
	},
	DUNGEON = {
		{ "Sous la terre. Ici, la roche respire lentement. Écoute.", "Underground. Here the rock breathes slowly. Listen." },
		{ "%s… L'air est lourd. Quelque chose a dérangé les éléments.", "%s… The air is heavy. Something has upset the elements." },
	},
	NIGHT = {
		{ "La nuit. La lune tire sur les marées, et un peu sur moi.", "Night. The moon pulls the tides, and me a little." },
		{ "Les étoiles sont des feux très lointains. Je leur fais signe.", "Stars are very distant fires. I wave at them." },
		{ "Le monde ralentit la nuit. Moi aussi. C'est bien.", "The world slows down at night. So do I. It's good." },
	},
	DEAD = {
		{ "Ton souffle s'est arrêté. Le vent attend que tu reviennes.", "Your breath has stopped. The wind is waiting for you." },
		{ "Rien ne se perd. Tu vas revenir. Je reste là.", "Nothing is lost. You'll come back. I'll stay here." },
	},
	REZ = {
		{ "Te voilà, comme le printemps après l'hiver.", "There you are, like spring after winter." },
		{ "La flamme s'est rallumée. Bon retour, petite braise.", "The flame is lit again. Welcome back, little ember." },
	},
	IDLE = {
		{ "J'écoute pousser l'herbe. Elle a beaucoup à dire.", "I'm listening to the grass grow. It has a lot to say." },
		{ "Le vent m'a raconté une histoire. Je te la dirai dans cent ans.", "The wind told me a story. I'll tell you in a hundred years." },
		{ "Tu bouges beaucoup. Essaie d'être une pierre, un moment.", "You move a lot. Try being a rock for a while." },
	},
	["IDLE/curious"] = {
		{ "Pourquoi les nuages n'ont-ils jamais deux fois la même forme ? J'enquête.", "Why are clouds never the same shape twice? I'm investigating." },
		{ "Ce caillou est plus vieux que ta ville. On lui parle ?", "This pebble is older than your city. Shall we talk to it?" },
	},
})

-- ---------------------------------------------------------------------------
-- Draconien : fier, ancien, condescendant
-- ---------------------------------------------------------------------------
Voice("dragonkin", {
	HELLO = {
		{ "Tu es revenu. Bien. Je t'accorde de nouveau ma présence.", "You've returned. Good. I grant you my presence once more." },
		{ "Mortel. J'ai dormi trois siècles, une fois. Toi, trois heures ? Faible.", "Mortal. I once slept three centuries. You, three hours? Weak." },
		{ "Salue ton dragon. Plus bas. Voilà.", "Bow to your dragon. Lower. There." },
	},
	KILL = {
		{ "Correct. Pour un être sans ailes.", "Adequate. For a wingless creature." },
		{ "%s ? Je l'aurais réduit en cendres d'un bâillement.", "%s? I'd have turned it to ash with a yawn." },
		{ "Mes ancêtres ont abattu des titans. Mais celui-là aussi, c'est bien.", "My ancestors felled titans. But that one's nice too." },
	},
	["KILL/teasing"] = {
		{ "Quel coup ! Pour un mortel. Armé d'une brindille.", "What a blow! For a mortal. Armed with a twig." },
		{ "Joli. Mes ancêtres en rient encore, là-haut.", "Nice. My ancestors are still laughing, up there." },
	},
	CAPTURE_OK = {
		{ "%s rejoint mon trésor. Je veux dire, notre collection.", "%s joins my hoard. I mean, our collection." },
		{ "Capturé. Au trésor. Tout finit dans le trésor.", "Caught. Into the hoard. Everything ends up in the hoard." },
		{ "Bien. Une créature digne de servir un dragon.", "Good. A creature worthy of serving a dragon." },
	},
	CAPTURE_FAIL = {
		{ "Il s'est enfui ? Inacceptable. Recommence.", "It fled? Unacceptable. Again." },
		{ "%s ose nous refuser. Je m'en souviendrai mille ans.", "%s dares refuse us. I'll remember it for a thousand years." },
		{ "Ton filet manque de majesté. Comme ta coiffure.", "Your net lacks majesty. Like your haircut." },
	},
	SHINY_SPOTTED = {
		{ "Ça brille. Tout ce qui brille m'appartient. C'est la règle.", "It shines. Everything that shines is mine. That's the rule." },
		{ "%s ! Cette lueur mérite le sommet du trésor.", "%s! That glow deserves the top of the hoard." },
		{ "Une brillante. Mon cœur de dragon s'emballe. Dignement.", "A shiny. My dragon heart is racing. With dignity." },
	},
	LEVEL = {
		{ "Niveau %s. Charmant. J'en étais là avant d'éclore.", "Level %s. Charming. I was there before I hatched." },
		{ "Tu progresses. Dans quelques millénaires, tu seras presque intéressant.", "You're improving. In a few millennia you'll be almost interesting." },
		{ "Niveau %s. Je t'autorise à être fier. Un peu.", "Level %s. I allow you to be proud. A little." },
	},
	ADVICE_HEALTH = {
		{ "Ta fragilité m'afflige. Soigne-toi, que je n'aie pas honte.", "Your frailty pains me. Heal, so I'm not ashamed." },
		{ "Même un dragon se retire pour soigner ses écailles. Fais de même.", "Even a dragon withdraws to tend its scales. Do likewise." },
		{ "Tu tombes en morceaux. Les mortels sont si mal finis.", "You're falling apart. Mortals are so poorly made." },
	},
	EAT = {
		{ "C'est tout ce que tu manges ? Moi, je prends un mouton entier.", "That's all you eat? I'd have a whole sheep." },
		{ "Repose-toi. Je veille sur toi, comme sur mon or.", "Rest. I'll guard you, like my gold." },
		{ "Cuit au feu de bois ? Amateur. Le feu de dragon, c'est autre chose.", "Wood-fired? Amateur. Dragonfire is another matter." },
	},
	CITY = {
		{ "%s. Les mortels aiment s'entasser. Comme des pièces dans un coffre.", "%s. Mortals love to huddle. Like coins in a chest." },
		{ "Une ville. Jadis, je l'aurais rasée. Je suis devenu sage.", "A city. Once, I'd have razed it. I've grown wise." },
	},
	DUNGEON = {
		{ "Un donjon. Les meilleurs trésors dorment au fond. Avance.", "A dungeon. The best treasure sleeps at the bottom. Onward." },
		{ "%s. Une grotte de dragon, en moins prestigieux.", "%s. A dragon's cave, only less prestigious." },
	},
	NIGHT = {
		{ "La nuit. Mes ancêtres volaient sous ces mêmes étoiles.", "Night. My ancestors flew beneath these same stars." },
		{ "Il fait noir ? Je pourrais éclairer, mais tu n'aimerais pas la méthode.", "Dark? I could light the way, but you'd hate the method." },
		{ "La lune est vieille. Presque autant que moi. Presque.", "The moon is old. Almost as old as me. Almost." },
	},
	DEAD = {
		{ "Tu es mort. Je l'avais prédit il y a mille ans. À peu près.", "You died. I predicted it a thousand years ago. Roughly." },
		{ "Allons. Un dragon ne pleure pas. Il attend. Dépêche-toi.", "Come now. A dragon doesn't weep. It waits. Hurry." },
	},
	REZ = {
		{ "Revenu des morts. Presque digne d'un dragon.", "Back from the dead. Almost worthy of a dragon." },
		{ "Te revoilà. Je n'étais pas inquiet. Mes écailles tremblaient de froid.", "You're back. I wasn't worried. My scales were shivering from cold." },
	},
	IDLE = {
		{ "J'ai vu naître ces montagnes. Bon, j'exagère. Pas celles-là.", "I saw these mountains born. All right, I exaggerate. Not those." },
		{ "Sais-tu combien d'or j'aurais, si j'avais gardé tes pièces ? Beaucoup.", "Do you know how much gold I'd have, had I kept your coins? Lots." },
		{ "Raconte-moi tes exploits. Brièvement. Je connais déjà la fin.", "Tell me your deeds. Briefly. I already know the ending." },
	},
	["IDLE/glutton"] = {
		{ "Un dragon a besoin de manger. Beaucoup. Tout de suite.", "A dragon needs food. Lots. Right now." },
		{ "Je rêve d'un troupeau entier. Rôti. Par moi.", "I dream of a whole herd. Roasted. By me." },
	},
})

-- ---------------------------------------------------------------------------
-- Mécanique : rapports, bips, logique de machine qui se veut sérieuse
-- (planche validée)
-- ---------------------------------------------------------------------------
Voice("mechanical", {
	HELLO = {
		{ "Bip. Démarrage terminé. Tous les rouages répondent… sauf un, mais il boude.", "Beep. Boot complete. All gears responding… except one, but it's sulking." },
		{ "Système en ligne. Mission : te suivre. Sous-mission : ne pas rouiller.", "System online. Mission: follow you. Sub-mission: don't rust." },
		{ "Bonjour, opérateur. Batterie à 100 %%. Patience à 63 %%.", "Hello, operator. Battery at 100%%. Patience at 63%%." },
	},
	KILL = {
		{ "Cible neutralisée. J'ajoute une encoche sur ma carcasse.", "Target neutralised. Adding a notch to my casing." },
		{ "Bip bip. %s : hors service. Garantie non applicable.", "Beep beep. %s: out of order. Warranty void." },
		{ "Efficacité du combat : satisfaisante. Élégance : à revoir.", "Combat efficiency: satisfactory. Elegance: needs work." },
	},
	["KILL/lazy"] = {
		{ "Cible abattue. Je propose une pause de maintenance. Longue.", "Target down. I suggest a maintenance break. A long one." },
		{ "Mode économie d'énergie : je te laisse la suivante.", "Power-saving mode: the next one's yours." },
	},
	["KILL/daring"] = {
		{ "Suivant ! Mes circuits chauffent, j'en veux d'autres !", "Next! My circuits are heating up, I want more!" },
		{ "Puissance maximale ! Prochaine cible, s'il te plaît.", "Maximum power! Next target, please." },
	},
	CAPTURE_OK = {
		{ "Capture confirmée. %s ajouté à la base de données.", "Capture confirmed. %s added to the database." },
		{ "Filet : succès. Je mets à jour l'inventaire des bestioles. Bip.", "Net: success. Updating the critter inventory. Beep." },
		{ "Probabilité de réussite : faible. Résultat : réussite. J'adore quand les maths ont tort.", "Success probability: low. Result: success. I love it when maths are wrong." },
	},
	CAPTURE_FAIL = {
		{ "Échec de capture. Je soupçonne un défaut du filet. Ou de l'opérateur.", "Capture failed. I suspect a net defect. Or an operator one." },
		{ "Erreur 404 : créature introuvable. Elle était là, pourtant.", "Error 404: creature not found. It was right there." },
		{ "Recalibrage du filet… Nouvelle tentative recommandée.", "Recalibrating the net… New attempt recommended." },
	},
	SHINY_SPOTTED = {
		{ "ALERTE : objet brillant détecté. Mes capteurs s'affolent.", "ALERT: shiny object detected. My sensors are going wild." },
		{ "Bip-bip-bip ! Brillante en vue ! Réflectivité hors normes !", "Beep-beep-beep! Shiny in sight! Off-the-charts reflectivity!" },
		{ "Priorité absolue : %s. Toutes les autres tâches suspendues.", "Top priority: %s. All other tasks suspended." },
	},
	LEVEL = {
		{ "Mise à jour installée : niveau %s. Redémarrage non nécessaire.", "Update installed: level %s. No restart needed." },
		{ "Performances de l'opérateur : en hausse. J'enregistre.", "Operator performance: rising. Logging it." },
		{ "Félicitations. Je déclenche les confettis. Ah, module confettis absent.", "Congratulations. Launching confetti. Ah, confetti module missing." },
	},
	ADVICE_HEALTH = {
		{ "Avertissement : intégrité de l'opérateur sous 30 %%. Retrait conseillé.", "Warning: operator integrity below 30%%. Retreat advised." },
		{ "Bip ! Bip ! BIP ! Ça, c'était l'alarme.", "Beep! Beep! BEEP! That was the alarm." },
		{ "Réparation d'urgence requise. Je n'ai pas de clé à molette pour toi.", "Emergency repairs required. I don't have a wrench for you." },
	},
	EAT = {
		{ "Recharge en cours. Toi aussi, apparemment.", "Recharging. You too, apparently." },
		{ "Pause détectée. Je profite pour dégripper mes articulations.", "Break detected. Taking the chance to oil my joints." },
		{ "Carburant organique : étrange choix, mais efficace.", "Organic fuel: strange choice, but effective." },
	},
	CITY = {
		{ "Zone urbaine. Densité de passants : élevée. Je réduis mon volume sonore.", "Urban area. Passer-by density: high. Lowering my volume." },
		{ "Entrée dans %s. Carte en cours de téléchargement… échec. On improvise.", "Entering %s. Downloading map… failed. We improvise." },
	},
	DUNGEON = {
		{ "Donjon détecté. Mode prudence activé. Mode courage : en option.", "Dungeon detected. Caution mode on. Courage mode: optional." },
		{ "%s : humidité élevée, éclairage nul. Mes rouages détestent déjà.", "%s: high humidity, zero lighting. My gears already hate it." },
	},
	NIGHT = {
		{ "Luminosité faible. J'allumerais bien ma lampe, si j'en avais une.", "Low light. I'd switch on my lamp, if I had one." },
		{ "Passage en mode nocturne. Bip discret.", "Switching to night mode. Quiet beep." },
		{ "Il est tard, opérateur. Les machines aussi aiment dormir.", "It's late, operator. Machines like sleep too." },
	},
	DEAD = {
		{ "Opérateur hors ligne. Lancement de la procédure de récupération.", "Operator offline. Starting recovery procedure." },
		{ "Note pour plus tard : éviter ce que tu viens de faire.", "Note for later: avoid what you just did." },
	},
	REZ = {
		{ "Redémarrage de l'opérateur réussi. Pertes de données : ta dignité.", "Operator reboot successful. Data loss: your dignity." },
		{ "Signes vitaux : rétablis. Je range le formulaire de décès.", "Vital signs: restored. Filing away the death form." },
	},
	IDLE = {
		{ "Diagnostic de routine : tout va bien. Sauf ce grincement. Ignore-le.", "Routine check: all good. Except that squeak. Ignore it." },
		{ "Question : les vivants ont-ils un mode veille ? Je me renseigne.", "Query: do living beings have a sleep mode? Asking for me." },
		{ "J'ai calculé la distance parcourue aujourd'hui. Tu ne veux pas savoir.", "I've computed today's distance travelled. You don't want to know." },
	},
	["IDLE/curious"] = {
		{ "Analyse de cet objet : inconnu. Analyse de son goût : déconseillée.", "Analysing this object: unknown. Analysing its taste: not advised." },
		{ "Question 117 : pourquoi les vivants rient-ils ? Je collecte des données.", "Query 117: why do living beings laugh? Collecting data." },
	},
})

-- ---------------------------------------------------------------------------
-- Géant : lent, lourd, tonitruant
-- ---------------------------------------------------------------------------
Voice("giant", {
	HELLO = {
		{ "BONJOUR ! … Trop fort ? Bonjour. Petit bonjour.", "HELLO! … Too loud? Hello. Little hello." },
		{ "Toi… revenu. Moi… content. Sol… trembler un peu.", "You… back. Me… happy. Ground… shake a bit." },
		{ "Moi attendre longtemps. Les pierres pousser. Toi enfin là.", "Me wait long time. Rocks grow. You finally here." },
	},
	KILL = {
		{ "BOUM. Fini.", "BOOM. Done." },
		{ "%s… tout petit. Comme toi. Mais toi, gentil.", "%s… tiny. Like you. But you, nice." },
		{ "Moi pas écraser. Toi écraser. Bien. Très… bien.", "Me not squash. You squash. Good. Very… good." },
	},
	["KILL/lazy"] = {
		{ "Bien. Maintenant… sieste. Longue sieste. Une saison.", "Good. Now… nap. Long nap. One season." },
		{ "Moi pas bouger. Toi tout faire. Bonne équipe.", "Me not move. You do all. Good team." },
	},
	CAPTURE_OK = {
		{ "%s… dans la poche. Grande poche. Beaucoup de place.", "%s… in pocket. Big pocket. Lots of room." },
		{ "Attrapé ! Moi faire danse de joie. … Pardon pour le cratère.", "Caught! Me do happy dance. … Sorry about the crater." },
		{ "Nouveau petit ami. Moi faire attention. Pas marcher dessus.", "New little friend. Me careful. No step on it." },
	},
	CAPTURE_FAIL = {
		{ "Parti. Trop rapide. Tout… trop rapide.", "Gone. Too fast. Everything… too fast." },
		{ "%s s'enfuir. Moi poursuivre ? … Non. Trop loin. Trois pas.", "%s run away. Me chase? … No. Too far. Three steps." },
		{ "Filet trop petit. Ou bestiole trop maligne. Ou les deux.", "Net too small. Or critter too clever. Or both." },
	},
	SHINY_SPOTTED = {
		{ "OH ! Ça BRILLE ! … Moi chuchoter. Ça brille.", "OH! It SHINES! … Me whisper. It shines." },
		{ "%s… brillant comme caillou au soleil. Moi aimer.", "%s… shiny like pebble in sun. Me like." },
		{ "Brillante. Toi aller doucement. Moi rester immobile. Facile.", "Shiny. You go slow. Me stay still. Easy." },
	},
	LEVEL = {
		{ "Niveau %s ! Toi grandir ! Bientôt… toi aussi grand que mon genou.", "Level %s! You grow! Soon… you tall as my knee." },
		{ "BRAVO ! … Pardon pour les oiseaux. Ils reviendront.", "WELL DONE! … Sorry about the birds. They'll come back." },
		{ "Niveau %s. Moi fier. Moi taper des mains. … Gros bruit.", "Level %s. Me proud. Me clap. … Big noise." },
	},
	ADVICE_HEALTH = {
		{ "Toi… cassé. Moi pas savoir réparer petits gens.", "You… broken. Me not know how fix small people." },
		{ "Toi t'asseoir. Moi faire mur. Personne passer.", "You sit. Me be wall. Nobody pass." },
		{ "Petit cœur fatigué. Respirer. Lentement. Comme montagne.", "Small heart tired. Breathe. Slow. Like mountain." },
	},
	EAT = {
		{ "Toi manger miette. Moi manger arbre. Chacun son goût.", "You eat crumb. Me eat tree. Each to their taste." },
		{ "Pause. Moi aimer pause. Moi très fort en pause.", "Break. Me love breaks. Me very good at breaks." },
		{ "Repos… Moi m'asseoir. … Oups. Plus de rocher.", "Rest… Me sit. … Oops. No more boulder." },
	},
	CITY = {
		{ "%s. Portes trop petites. Moi rester dehors ? … Non. Moi baisser la tête.", "%s. Doors too small. Me stay outside? … No. Me duck." },
		{ "Ville. Beaucoup de petits gens. Moi marcher… très… doucement.", "City. Many small people. Me walk… very… carefully." },
	},
	DUNGEON = {
		{ "Plafond bas. Moi cogner tête. Déjà deux fois.", "Low ceiling. Me bump head. Twice already." },
		{ "%s… sombre. Écho de ma voix. BONJOUR ! … Oups.", "%s… dark. Echo of my voice. HELLO! … Oops." },
	},
	NIGHT = {
		{ "Nuit. Étoiles toutes petites. Comme toi. Moi aimer petites choses.", "Night. Stars so small. Like you. Me love small things." },
		{ "Moi bâiller. … Pardon. Du vent pour toute la vallée.", "Me yawn. … Sorry. Wind for whole valley." },
		{ "La lune… presque aussi ronde que mon ventre.", "The moon… almost as round as my belly." },
	},
	DEAD = {
		{ "Toi… tombé. Moi porter toi ? … Non ? Moi attendre. Moi bon pour attendre.", "You… fell. Me carry you? … No? Me wait. Me good at waiting." },
		{ "NON ! … Pardon. Moi triste. Très gros triste.", "NO! … Sorry. Me sad. Very big sad." },
	},
	REZ = {
		{ "Toi revenir ! Moi faire câlin. Doucement. TRÈS doucement.", "You back! Me hug. Gently. VERY gently." },
		{ "Toi debout. Bien. Moi plus triste. Moi content. Gros content.", "You standing. Good. Me not sad. Me happy. Big happy." },
	},
	IDLE = {
		{ "Moi penser… … … Moi oublier. Pas grave.", "Me think… … … Me forget. No matter." },
		{ "Ce rocher. Moi aimer ce rocher. Lui pas parler beaucoup. Comme moi.", "This rock. Me like this rock. It not talk much. Like me." },
		{ "Toi petit, mais courageux. Moi grand, mais peur des souris.", "You small, but brave. Me big, but scared of mice." },
	},
	["IDLE/cuddly"] = {
		{ "Moi faire câlin ? … Toi disparaître dedans. Mais câlin.", "Me hug? … You vanish inside. But hug." },
		{ "Toi monter sur mon épaule. Meilleure vue. Et amitié.", "You climb on shoulder. Better view. And friendship." },
	},
})

-- ---------------------------------------------------------------------------
-- Humanoïde : aventurier bavard
-- ---------------------------------------------------------------------------
Voice("humanoid", {
	HELLO = {
		{ "Te revoilà ! J'ai trois histoires à te raconter. Non, quatre.", "There you are! I've got three stories to tell you. No, four." },
		{ "Sac bouclé, bottes cirées : prêt pour l'aventure ! Et toi ?", "Pack ready, boots polished: ready for adventure! You?" },
		{ "Ah, mon compagnon de route ! La taverne était bien vide sans toi.", "Ah, my travel partner! The tavern felt so empty without you." },
	},
	KILL = {
		{ "Bien joué ! Je l'aurais eu aussi, hein. Mais bien joué.", "Well played! I'd have got it too, mind. But well played." },
		{ "%s ne verra pas l'aube. On en fait une chanson ?", "%s won't see dawn. Shall we make a song of it?" },
		{ "Encore un pour la légende ! Je tiens les comptes, t'inquiète.", "Another for the legend! I'm keeping count, don't worry." },
	},
	["KILL/curious"] = {
		{ "Attends, je note sa tactique. … Elle était mauvaise.", "Wait, I'm noting its tactics. … They were bad." },
		{ "%s venait d'où, à ton avis ? Je veux savoir.", "Where do you think %s came from? I want to know." },
	},
	CAPTURE_OK = {
		{ "%s est à nous ! Je l'avais dit à la taverne, personne ne m'a cru.", "%s is ours! I said so at the tavern, nobody believed me." },
		{ "Capturé ! Ça, c'est du travail de professionnel.", "Caught! Now that's professional work." },
		{ "Bienvenue dans l'équipe, %s. Règle numéro un : on partage les rations.", "Welcome to the team, %s. Rule one: we share rations." },
	},
	CAPTURE_FAIL = {
		{ "Il a filé ! Ça arrive aux meilleurs. Surtout à toi, apparemment.", "It got away! Happens to the best. Mostly to you, apparently." },
		{ "Raté. La prochaine fois, je fais diversion : je chante.", "Missed. Next time I'll create a distraction: I'll sing." },
		{ "%s nous a eus. On ne le dira à personne, d'accord ?", "%s fooled us. We won't tell anyone, deal?" },
	},
	SHINY_SPOTTED = {
		{ "Une brillante ! Les bardes vont adorer cette histoire !", "A shiny! The bards are going to love this one!" },
		{ "Regarde %s ! On n'en croise pas deux dans une vie.", "Look at %s! You don't see two in a lifetime." },
		{ "Doucement… Une brillante. Pas de geste brusque, je retiens mon souffle.", "Easy… A shiny. No sudden moves, I'm holding my breath." },
	},
	LEVEL = {
		{ "Niveau %s ! Ça se fête. La première tournée est pour moi !", "Level %s! Let's celebrate. First round's on me!" },
		{ "Tu as vu ça ? Niveau %s ! J'ai toujours cru en toi. Presque toujours.", "Did you see that? Level %s! I always believed in you. Almost always." },
		{ "Un niveau de plus. Ta légende s'écrit, et je suis dedans !", "Another level. Your legend is being written, and I'm in it!" },
	},
	ADVICE_HEALTH = {
		{ "Hé, tu saignes partout ! Bande-moi ça avant de continuer.", "Hey, you're bleeding everywhere! Bandage that before going on." },
		{ "On souffle deux minutes ? Les héros morts ne touchent pas la prime.", "Catch our breath? Dead heroes don't get the bounty." },
		{ "Tu tiens encore debout ? À ta place, je m'assiérais.", "Still standing? In your shoes, I'd sit down." },
	},
	EAT = {
		{ "À table ! Raconte-moi un truc pendant que tu manges.", "Grub time! Tell me something while you eat." },
		{ "Rien de tel qu'une bonne pause. Les plus grands aventuriers font la sieste.", "Nothing beats a good break. The greatest adventurers nap." },
		{ "Il te reste du fromage ? Pour moi, je veux dire. Pour moi.", "Got any cheese left? For me, I mean. For me." },
	},
	CITY = {
		{ "%s ! Les marchés, les tavernes, les ragots… j'adore.", "%s! Markets, taverns, gossip… I love it." },
		{ "Une ville ! Tiens bien ta bourse, les tire-laine sont rapides ici.", "A city! Hold your purse, pickpockets are quick here." },
	},
	DUNGEON = {
		{ "Un donjon ! Torche, corde, courage. Il nous manque la corde.", "A dungeon! Torch, rope, courage. We're missing the rope." },
		{ "%s… On m'a raconté des horreurs sur cet endroit. Génial !", "%s… I've heard horror stories about this place. Great!" },
	},
	NIGHT = {
		{ "La nuit tombe. Le meilleur moment pour les histoires au coin du feu.", "Night's falling. Best time for campfire stories." },
		{ "Il fait noir. Reste près de moi. Non, je n'ai pas peur. Toi, peut-être.", "It's dark. Stay close. No, I'm not scared. You might be." },
		{ "Belle nuit. Les étoiles, c'est la carte des voyageurs perdus.", "Lovely night. The stars are the map of lost travellers." },
	},
	DEAD = {
		{ "Aïe. Je raconterai que tu t'es battu comme un lion.", "Ouch. I'll tell them you fought like a lion." },
		{ "Tu es tombé ! Je garde tes affaires. Promis, je ne fouille pas.", "You fell! I'll mind your things. I promise I won't snoop." },
	},
	REZ = {
		{ "Revenu d'entre les morts ! Ça, c'est une histoire pour la taverne.", "Back from the dead! Now that's a tavern story." },
		{ "Te revoilà ! J'ai un peu fouillé tes affaires. Juste un peu.", "You're back! I snooped through your things a bit. Just a bit." },
	},
	IDLE = {
		{ "Tu savais que j'ai failli devenir barde ? J'avais tout, sauf la voix.", "Did you know I almost became a bard? I had it all, except the voice." },
		{ "Un jour, je t'emmènerai voir la mer. Enfin, une mer. N'importe laquelle.", "One day I'll take you to see the sea. Well, a sea. Any sea." },
		{ "Je tiens un journal de nos aventures. Tu y as le beau rôle. Presque.", "I'm keeping a journal of our travels. You come off well. Mostly." },
	},
	["IDLE/teasing"] = {
		{ "Tu marches toujours comme ça ? On dirait un canard en armure.", "Do you always walk like that? Like a duck in armour." },
		{ "Combien de chutes aujourd'hui, déjà ? Moi, j'ai compté.", "How many falls today, again? I counted." },
	},
})

-- ---------------------------------------------------------------------------
-- Bestiole : minuscule, anxieuse, mignonne
-- ---------------------------------------------------------------------------
Voice("critter", {
	HELLO = {
		{ "Tu es revenu ! J'ai eu peur que tu m'oublies. Un peu. Beaucoup.", "You came back! I was scared you'd forget me. A bit. A lot." },
		{ "Coucou ! J'ai gardé ta place. Personne n'est venu. Ouf.", "Hi! I kept your spot. Nobody came. Phew." },
		{ "Couic ! C'est mon bonjour. Couic couic, c'est le bonjour très content.", "Squeak! That's my hello. Squeak squeak is the very happy hello." },
	},
	KILL = {
		{ "Il est… parti ? Pour de bon ? Je peux rouvrir les yeux ?", "Is it… gone? For good? Can I open my eyes now?" },
		{ "%s était TROIS FOIS plus grand que moi. Tu es si courageux.", "%s was THREE TIMES my size. You're so brave." },
		{ "Je tremble encore. Mais de fierté ! Surtout de fierté.", "I'm still shaking. But with pride! Mostly pride." },
	},
	["KILL/daring"] = {
		{ "J'ai aidé ! J'ai mordu sa botte ! Enfin, j'ai essayé.", "I helped! I bit its boot! Well, I tried." },
		{ "Encore un ? Je suis prêt ! … Après une petite pause.", "Another one? I'm ready! … After a little break." },
	},
	CAPTURE_OK = {
		{ "%s est avec nous ! Il a l'air gentil. Il a l'air gentil, hein ?", "%s is with us! It looks nice. It looks nice, right?" },
		{ "Un nouvel ami ! Pourvu qu'il ne me prenne pas pour un goûter.", "A new friend! I hope it doesn't take me for a snack." },
		{ "Capturé ! Je lui fais une petite place dans le nid.", "Caught! I'll make it a little spot in the nest." },
	},
	CAPTURE_FAIL = {
		{ "Il est parti… C'est ma faute ? Dis-moi que ce n'est pas ma faute.", "It's gone… Is it my fault? Tell me it's not my fault." },
		{ "Raté ! Ce n'est pas grave. Si ? Non. Si ? Non.", "Missed! It's fine. Is it? No. Is it? No." },
		{ "%s s'est sauvé. Je comprends, moi aussi j'aurais eu peur.", "%s ran away. I get it, I'd have been scared too." },
	},
	SHINY_SPOTTED = {
		{ "Ça brille ! C'est dangereux ? C'est joli ? C'est les deux ?", "It's shiny! Is it dangerous? Is it pretty? Both?" },
		{ "%s brille tout plein ! Mes moustaches frétillent !", "%s is all sparkly! My whiskers are twitching!" },
		{ "Une brillante ! Je retiens ma respiration. Je… ne… respire… plus.", "A shiny! I'm holding my breath. I'm… not… breathing." },
	},
	LEVEL = {
		{ "Niveau %s ! Tu es immense ! Enfin, tu l'étais déjà, mais encore plus !", "Level %s! You're huge! Well, you already were, but more!" },
		{ "Bravo bravo bravo ! Je fais des petits bonds. Tu vois ?", "Bravo bravo bravo! I'm doing little hops. See?" },
		{ "Niveau %s… Tu me protégeras encore, même quand tu seras très fort ?", "Level %s… Will you still protect me when you're really strong?" },
	},
	ADVICE_HEALTH = {
		{ "Tu as mal ? J'ai mal pour toi. Partout. Soigne-toi, s'il te plaît !", "Are you hurt? I hurt for you. Everywhere. Please heal!" },
		{ "Ne meurs pas ! Je ne sais pas rentrer tout seul !", "Don't die! I don't know the way home alone!" },
		{ "On se cache ? Je connais un super terrier. Petit, mais super.", "Shall we hide? I know a great burrow. Small, but great." },
	},
	EAT = {
		{ "Une miette ? Une toute petite miette ? Pour moi ?", "A crumb? A teeny tiny crumb? For me?" },
		{ "On se repose ! Je me roule en boule dans ton capuchon.", "Rest time! I'll curl up in your hood." },
		{ "Mange bien. Moi, une graine et je suis plein pour la semaine.", "Eat well. One seed and I'm full for a week." },
	},
	CITY = {
		{ "%s… Tant de bottes ! Je reste dans ta poche, d'accord ?", "%s… So many boots! I'll stay in your pocket, okay?" },
		{ "Une ville ! Il y a des chats ? Dis-moi qu'il n'y a pas de chats.", "A city! Are there cats? Tell me there are no cats." },
	},
	DUNGEON = {
		{ "C'est noir. C'est froid. Ça goutte. Je n'aime pas ça du tout.", "It's dark. It's cold. It drips. I don't like it at all." },
		{ "%s ? Le nom fait peur. On peut juste regarder l'entrée ?", "%s? The name's scary. Can we just look at the door?" },
	},
	NIGHT = {
		{ "Il fait nuit. Les hiboux sortent. J'ai peur des hiboux.", "It's night. Owls come out. I'm scared of owls." },
		{ "Tu laisses une lumière allumée ? Juste une petite ?", "Will you leave a light on? Just a little one?" },
		{ "Les étoiles sont jolies. Mais elles nous regardent, non ?", "The stars are pretty. But they're watching us, right?" },
	},
	DEAD = {
		{ "Non non non ! Réveille-toi ! Je me cache sous ton bras en attendant.", "No no no! Wake up! I'll hide under your arm meanwhile." },
		{ "Tu es tout froid… Je reste là. Même si j'ai très peur.", "You're all cold… I'm staying. Even though I'm so scared." },
	},
	REZ = {
		{ "Tu es vivant ! Je fais la danse du soulagement. Couic !", "You're alive! I'm doing the relief dance. Squeak!" },
		{ "Plus jamais ça, d'accord ? Mon petit cœur ne le supportera pas.", "Never again, okay? My little heart can't take it." },
	},
	IDLE = {
		{ "J'ai entendu un bruit. C'était une feuille. Une feuille très suspecte.", "I heard a noise. It was a leaf. A very suspicious leaf." },
		{ "Tu crois que je grandirai un jour ? Juste assez pour voir par-dessus l'herbe ?", "Think I'll ever grow? Just enough to see over the grass?" },
		{ "Je compte tes pas. Tu en fais beaucoup. Moi, quatre fois plus.", "I'm counting your steps. You take lots. I take four times as many." },
	},
	["IDLE/glutton"] = {
		{ "J'ai caché des noisettes partout. Je ne sais plus où. C'est un drame.", "I hid nuts everywhere. I don't remember where. It's a tragedy." },
		{ "Il paraît qu'il existe des gâteaux plus gros que moi. C'est mon rêve.", "Rumour has it some cakes are bigger than me. It's my dream." },
	},
})

ns.RegisterCompanionLines(P, true)
P = nil

-- ---------------------------------------------------------------------------
-- Le type de la créature compagnon (clé de CreatureTypes.lua, ou « critter »)
-- ---------------------------------------------------------------------------
local CRITTER_NAMES = {
	["critter"] = true, ["bestiole"] = true, ["non-combat pet"] = true, ["wild pet"] = true,
	["familier pacifique"] = true, ["mascotte sauvage"] = true,
}
local VOICED = {}
for _, kind in ipairs(ns.COMPANION_VOICE_TYPES) do VOICED[kind] = true end

local cache = {}   -- apparence -> type (false : aucun), relu quand la ménagerie change
local function TypeText(self, npc)
	local ok, data = pcall(self.CaptureData, self)
	local creatures = ok and type(data) == "table" and type(data.creatures) == "table" and data.creatures or {}
	local entry = creatures[npc] or creatures[tostring(npc)]
	if type(entry) == "table" and type(entry.type) == "string" and entry.type ~= "" then return entry.type end
	-- ancienne capture sans type : le carnet l'a peut-être appris
	local book = self.BestiaryData and self:BestiaryData()
	if type(book) ~= "table" then return nil end
	for _, zone in pairs(book) do
		local species = type(zone) == "table" and (zone[npc] or zone[tostring(npc)])
		if type(species) == "table" and type(species.type) == "string" and species.type ~= "" then return species.type end
	end
	return nil
end

function ns:CompanionVoiceType()
	local app = self.CompanionData and self:CompanionData().appearance
	local npc = type(app) == "string" and tonumber(app:match("^cap:(%d+)"))
	if not npc or not self.CaptureData then return nil end
	local ok, data = pcall(self.CaptureData, self)
	local serial = ok and type(data) == "table" and data.serial or 0
	if cache.app ~= app or cache.serial ~= serial then
		local text = TypeText(self, npc)
		local kind = text and self.CreatureTypeKey and self:CreatureTypeKey(text)
		if not kind and text and CRITTER_NAMES[ns.AsciiLower and ns.AsciiLower(text) or text:lower()] then kind = "critter" end
		cache.app, cache.serial, cache.kind = app, serial, (kind and VOICED[kind]) and kind or false
	end
	return cache.kind or nil
end
function ns:CompanionVoiceForget() cache.app = nil end

-- noms des réservoirs de voix, faits une fois
local names = {}
local function Name(base, kind, trait)
	local row = names[base]
	if not row then row = {}; names[base] = row end
	local slot = trait and (kind .. "_" .. trait) or kind
	local name = row[slot]
	if not name then
		name = base .. "_V_" .. slot
		row[slot] = name
	end
	return name
end
ns.CompanionVoicePoolName = Name

-- Une ligne pour `pool` : celle de la voix (et du caractère) le plus
-- souvent, sinon la commune. Même anti-répétition (par réservoir) ;
-- une voix sans ligne utilisable (argument manquant) rend la main.
function ns:CompanionVoicePick(pool, args)
	local base = VOICE_OF[pool]
	local kind = base and self:CompanionVoiceType()
	local pools = ns.COMPANION_POOLS
	if kind and math.random() < ns.COMPANION_VOICE_SHARE then
		local trait = self.CompanionTrait and self:CompanionTrait()
		local over = trait and Name(base, kind, trait)
		if over and pools[over] and math.random() < ns.COMPANION_VOICE_TRAIT_SHARE then
			local key = self:CompanionPick(over, args)
			if key then return key end
		end
		local voice = Name(base, kind)
		if pools[voice] then
			local key = self:CompanionPick(voice, args)
			if key then return key end
		end
	end
	return self:CompanionPick(pool, args)
end

if ns.Mark then ns.Mark("CompanionVoices") end
