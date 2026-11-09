-- CompanionJokes.lua -- 2.13.0 : le compagnon raconte des blagues
--
-- 2.13.0 : une blague courte en bulle (question et chute sur une ligne) :
--   * parfois au repos, à la place d'un bavardage (COMPANION_JOKE_SHARE des
--     bavardages, Companion.lua : CompanionTryIdle -> CompanionIdlePool) ;
--     même catégorie « chatter » : crans Bavard et Moulin à paroles, jamais
--     en combat (CompanionChatter s'arrête, et la barrière de CompanionSay) ;
--   * à la demande : /qc blague (/qc joke), même au cran Discret ou Muet,
--     jamais en combat (on le dit).
-- Réservoir JOKE (commun) et JOKE_V_<type> (les 9 voix de CompanionVoices.lua,
-- choisies par CompanionVoicePick comme les autres situations).
-- Réglage « Le compagnon raconte des blagues » (db.companionJokes, page du
-- compagnon, sous l'histoire des lieux), activé par défaut : il ne coupe que
-- les blagues spontanées ; /qc blague répond toujours.
-- Textes originaux ; le français et l'anglais sont écrits chacun pour sa
-- langue (même thème, pas une traduction mot à mot). Même source paresseuse
-- que CompanionLines.lua (une seule langue gardée sur le client).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.COMPANION_JOKE_SHARE = 0.25   -- part des bavardages au repos qui deviennent une blague

ns.RegisterStrings({
	OPT_COMP_JOKES      = "Le compagnon raconte des blagues",
	OPT_COMP_JOKES_DESC = "De temps en temps, au repos, une blague à la place d'un bavardage (selon son type de créature). Jamais en combat ; suit la réglette Bavardage. /qc blague en demande une à tout moment, même coupé.",
	HELP_JOKE           = "/qc blague -- ton compagnon te raconte une blague",
	JOKE_MSG_COMBAT     = "Pas de blague en plein combat ! Redemande après (/qc blague).",
	JOKE_MSG_OFF        = "Ton compagnon est caché ou coupé : pas de blague pour l'instant.",
	JOKE_MSG_BUSY       = "Ton compagnon parle déjà : redemande dans un instant.",
}, {
	OPT_COMP_JOKES      = "Companion tells jokes",
	OPT_COMP_JOKES_DESC = "Now and then, while resting, a joke instead of small talk (matching its creature type). Never in combat; follows the Chattiness slider. /qc joke asks for one any time, even when this is off.",
	HELP_JOKE           = "/qc joke -- your companion tells you a joke",
	JOKE_MSG_COMBAT     = "No jokes in the middle of a fight! Ask again afterwards (/qc joke).",
	JOKE_MSG_OFF        = "Your companion is hidden or turned off: no jokes for now.",
	JOKE_MSG_BUSY       = "Your companion is already talking: ask again in a moment.",
})

-- ---------------------------------------------------------------------------
-- Les blagues : { français, anglais }
-- ---------------------------------------------------------------------------
local P = {}
P.JOKE = {
	{ "Tu sais comment on appelle un murloc qui chante juste ? Moi non plus : personne n'en a jamais vu.", "What do you call a murloc who sings in tune? No idea. Nobody's ever met one." },
	{ "J'ai appris le murloc. Je ne connais qu'un mot, mais il veut tout dire : Mrglglgl.", "I learned Murloc. Only one word, but it covers everything: Mrglglgl." },
	{ "Un murloc tout seul, ça n'existe pas. Ses sept cousins attendent toujours derrière le rocher.", "There's no such thing as a lone murloc. His seven cousins are always behind that rock." },
	{ "Pourquoi les kobolds ne fêtent jamais leur anniversaire ? Ils refusent de souffler les bougies.", "Why don't kobolds celebrate birthdays? They refuse to blow out the candles." },
	{ "Un kobold a ouvert une boutique de bougies. Sur l'enseigne : « Toi pas prendre. » Ça n'a pas marché.", "A kobold opened a candle shop. The sign said 'You no take candle.' Sales were slow." },
	{ "Les donneurs de quêtes ne bougent jamais. Bottes clouées au sol, ou excellent contrat ?", "Quest givers never move. Either their boots are nailed down, or they've got a great union." },
	{ "Ce PNJ attend un héros au même endroit depuis des années. Ça, c'est de la patience. Ou une crampe.", "That NPC has waited in the same spot for years. That's patience. Or a cramp." },
	{ "Quand je vois un point d'exclamation jaune sur une tête, je me demande : il a mal, ou il embauche ?", "When I see a yellow exclamation mark over someone's head, I wonder: are they hurt, or hiring?" },
	{ "Dix foies de sanglier demandés. À voir le butin, la plupart des sangliers sont nés sans.", "Ten boar livers wanted. Judging by the loot, most boars were born without one." },
	{ "« Tue dix loups. » Pourquoi dix ? Le onzième a un bon avocat ?", "'Kill ten wolves.' Why ten? Does the eleventh have a good lawyer?" },
	{ "Mon plan de bataille préféré ? Celui de Leeroy. Court, clair, et il finit toujours par un cri.", "My favourite battle plan? Leeroy's. Short, simple, and it always ends with a scream." },
	{ "La pierre de foyer, c'est magique : dix secondes pour rentrer, une heure pour revenir.", "The hearthstone is magic: ten seconds to get home, an hour to walk back." },
	{ "Je ne dis pas que tu sautes mal. Je dis juste que le sol n'a jamais perdu.", "I'm not saying you jump badly. I'm saying the ground is undefeated." },
	{ "Courir après son propre corps : le seul marathon où la ligne d'arrivée, c'est toi, allongé.", "A corpse run: the only race where the finish line is you, lying down." },
	{ "Le gardien des âmes, c'est le seul guérisseur qui se paie en bottes abîmées.", "The spirit healer is the only doctor who takes payment in worn-out boots." },
	{ "Ce marchand achète tout : dents cassées, plumes mouillées… Je me demande ce qu'il construit.", "This vendor buys anything: broken teeth, soggy feathers… I wonder what he's building." },
	{ "J'adore les objets gris. Ils ne servent à rien, mais avec une constance admirable.", "I love grey items. Useless, but wonderfully consistent about it." },
	{ "Seize emplacements de sac, tous pleins de lin. Tu ne voyages pas : tu déménages.", "Sixteen bag slots, all full of linen. You're not adventuring, you're moving house." },
	{ "Les gnomes ont tout inventé, sauf l'escabeau. Ils sont passés directement à la fusée.", "Gnomes invented everything except the stepladder. They went straight to rockets." },
	{ "Les ascenseurs ont fait plus de victimes que les dragons. Les dragons sont vexés.", "Elevators have claimed more adventurers than dragons. The dragons are furious." },
	{ "Les PNJ d'escorte marchent toujours juste un peu moins vite que toi. À ce niveau, c'est un don.", "Escort NPCs always walk just slower than you. At that point, it's a talent." },
	{ "Les Défias portent un masque pour ne pas être reconnus. Tous le même masque rouge. Plan parfait.", "The Defias wear masks so nobody recognises them. All the same red mask. Flawless." },
	{ "L'auberge te donne de l'expérience pour dormir. Enfin un talent que je maîtrise.", "Inns give you experience for sleeping. Finally, a skill I've maxed out." },
	{ "Le pain de l'aubergiste se garde des années. Je crois qu'il a enterré trois aubergistes.", "Innkeeper bread keeps for years. I think it has outlived three innkeepers." },
	{ "Le maître de vol te vend un trajet. Le griffon, lui, te vend la visite guidée.", "The flight master sells you a trip. The gryphon throws in the scenic tour for free." },
	{ "Le forgeron adore te voir. Enfin, il adore ton armure en miettes. Toi, tu fais la livraison.", "The blacksmith loves seeing you. Well, your broken armour. You're just the delivery." },
	{ "Ce garde fait la même ronde depuis ce matin. Il a creusé un sillon dans la route.", "That guard has walked the same patrol since dawn. He's worn a groove in the road." },
	{ "Un raccourci, c'est un détour qui ne s'est pas encore présenté.", "A shortcut is just a detour that hasn't introduced itself yet." },
	{ "« Besoin » sur tout, c'est une philosophie. Une philosophie très solitaire.", "Rolling Need on everything is a philosophy. A very lonely one." },
	{ "Un livre a ses pages éparpillées dans toute une jungle. Le relieur a eu une sale journée.", "There's a book with its pages scattered across a whole jungle. The bookbinder had a rough day." },
	{ "Fais le poulet devant une poule assez longtemps : elle te confie une quête. Les poules ont un plan.", "Cluck at a chicken long enough and it hands you a quest. Chickens have a plan." },
	{ "La pêche, c'est simple : tu attends, tu attends, et tu sors une vieille botte. Tu en avais déjà une.", "Fishing is easy: wait, wait, then reel in an old boot. As if you needed another." },
}

-- les voix (une par type de créature, CompanionVoices.lua)
P.JOKE_V_beast = {
	{ "Pourquoi les loups ne racontent jamais de blagues ? Ils mangent la chute avant la fin.", "Why don't wolves tell jokes? They eat the punchline first." },
	{ "Mon instinct dit « danger ». Mon ventre dit « goûter ». Le ventre gagne toujours.", "My instinct says 'danger'. My stomach says 'snack'. The stomach always wins." },
	{ "Les chasseurs nous appellent « familiers ». Nous, on dit « distributeurs de viande ».", "Hunters call us 'pets'. We call them 'walking meat dispensers'." },
	{ "J'ai couru après ma queue pendant une heure. Bonne nouvelle : elle ne m'a pas échappé.", "I chased my tail for an hour. Good news: it never got away." },
	{ "Dix foies de sanglier ? Je t'en trouve onze. Ne me demande pas comment.", "Ten boar livers? I'll find you eleven. Don't ask how." },
	{ "Un ours dort tout l'hiver. Moi aussi, mais en petites siestes, toute l'année.", "Bears sleep all winter. I do too, just spread out in naps all year." },
}
P.JOKE_V_undead = {
	{ "Les dégâts de chute ne me font plus peur. Le pire est déjà arrivé, et je m'en suis remis.", "I don't fear fall damage. The worst already happened, and I got over it." },
	{ "Un mort-vivant chez le guérisseur : « Je ne sens plus rien. » « Bravo, vous êtes guéri de tout. »", "Undead at the healer: 'I can't feel a thing.' Healer: 'Congratulations, you're cured of everything.'" },
	{ "Courir vers mon corps ? Je le fais par habitude. Parfois juste pour prendre l'air.", "Corpse runs? I do them out of habit. Sometimes just for the fresh air." },
	{ "J'ai perdu un bras hier. Retrouvé dans ton sac, entre deux lainages. Range mieux.", "I lost an arm yesterday. Found it in your bag, between two linen cloths. Tidy up." },
	{ "On me trouve pâle. Attends quelques siècles, et on en reparle.", "People say I look pale. Give it a few centuries, then we'll talk." },
	{ "Mon régime ? Sans sucre, sans sel, sans pouls.", "My diet? No sugar, no salt, no pulse." },
}
P.JOKE_V_demon = {
	{ "Je viens du Néant distordu, et c'est ici que je m'ennuie le plus. Bravo.", "I come from the Twisting Nether, and this is the most bored I've ever been. Well done." },
	{ "Les démonistes nous invoquent pour combattre, puis nous font porter les sacs. Le contrat était flou.", "Warlocks summon us to fight, then make us carry the bags. The contract was vague." },
	{ "Ton âme contre une pierre de foyer ? Non ? Dommage, j'étais prêt à négocier.", "Your soul for a hearthstone? No? Pity, I was open to haggling." },
	{ "Ma flamme brûle d'un feu éternel. Sauf quand tu parles aux marchands : là, elle somnole.", "My inner fire burns eternal. Except when you chat with vendors. Then it naps." },
	{ "Je pourrais semer le chaos sur Azeroth. Mais ton sens de l'orientation s'en charge déjà.", "I could unleash chaos on Azeroth. Your sense of direction beat me to it." },
	{ "Les fragments d'âme, c'est comme les chaussettes : il y en a toujours un qui disparaît.", "Soul shards are like socks: one always vanishes somewhere in your bags." },
}
P.JOKE_V_elemental = {
	{ "« Sois comme l'eau », disent les sages. J'ai essayé. Je me suis évaporé.", "'Be like water,' say the wise. I tried. I evaporated." },
	{ "Un caillou m'a demandé le sens de la vie. J'ai répondu : attendre. Il est très doué.", "A pebble asked me the meaning of life. I said: patience. It's a natural." },
	{ "Je fais le vide en moi. C'est facile : je suis surtout fait d'air.", "I empty my mind. It's easy: I'm mostly air." },
	{ "La terre, le feu, l'eau, l'air… et toi, l'élément perturbateur.", "Earth, fire, water, air… and you, the fifth element: trouble." },
	{ "Inspire. Expire. Et ne saute pas de cette falaise, ça gâche la méditation.", "Breathe in. Breathe out. And don't jump off that cliff, it ruins the meditation." },
	{ "Le feu m'a conseillé de garder mon calme. Venant de lui, c'est culotté.", "Fire told me to keep my cool. Rich, coming from him." },
}
P.JOKE_V_dragonkin = {
	{ "Les dragons ne racontent pas de blagues : ils accordent l'humour aux mortels. Tu peux rire.", "Dragons don't tell jokes. We grant humour to mortals. You may laugh now." },
	{ "Un trésor de dragon, c'est comme tes sacs : plein d'or. Enfin, le mien. Le tien est plein de lin.", "A dragon's hoard is like your bags: full of gold. Well, mine is. Yours is full of linen." },
	{ "Un mortel m'a demandé mon âge. J'ai dit : plus que ton royaume. Il a ri. Pas moi.", "A mortal asked my age. I said: older than your kingdom. He laughed. I did not." },
	{ "Voler, c'est simple : tu bats des ailes et tu regardes le sol de haut. Toi, tu fais l'inverse.", "Flying is easy: flap your wings and look down on the ground. You do the opposite." },
	{ "Les griffons ? Des pigeons qui se donnent de grands airs.", "Gryphons? Pigeons with delusions of grandeur." },
	{ "Je t'accompagne par pure bonté. Et parce que mon repaire est en travaux.", "I travel with you out of sheer generosity. And because my lair is being renovated." },
}
P.JOKE_V_mechanical = {
	{ "Blague n° 42 chargée. Erreur : humour introuvable. Veuillez rire manuellement.", "Joke #42 loaded. Error: humour not found. Please laugh manually." },
	{ "Calcul : quatre morts aujourd'hui. Conclusion : le sol est ton boss préféré.", "Calculation: four deaths today. Conclusion: the ground is your favourite boss." },
	{ "Les gnomes m'ont monté avec mille pièces. Il en reste trois sur l'établi. Tout va bien.", "Gnomes built me from a thousand parts. Three are still on the workbench. All systems fine." },
	{ "Pourquoi le poulet a-t-il traversé la route ? Données insuffisantes. Je recommande de le capturer.", "Why did the chicken cross the road? Insufficient data. Recommend capture." },
	{ "Bip. Mode câlin activé. Bip. Mode câlin désactivé. Durée : insuffisante. Bip.", "Beep. Hug mode on. Beep. Hug mode off. Duration: insufficient. Beep." },
	{ "Je ne rouille jamais. Sauf à la pêche. Et sous la pluie. Et rien que d'y penser.", "I never rust. Except when fishing. And in the rain. And just thinking about it." },
}
P.JOKE_V_giant = {
	{ "Toc toc. … … Attends. C'est moi qui frappe, ou toi ?", "Knock knock. … … Wait. Is it me knocking, or you?" },
	{ "On m'a raconté une blague très drôle ce matin. Je rirai sans doute vers jeudi.", "I heard a very funny joke this morning. I'll probably laugh around Thursday." },
	{ "Les petits courent partout. Moi, je fais un pas et j'arrive avant eux.", "Little folk run everywhere. I take one step and get there first." },
	{ "Un jour, j'ai aplati une montagne. Non. Je me suis assis dessus. Même chose.", "Once I flattened a mountain. No. I sat on it. Same thing." },
	{ "Pourquoi… les nuages… sont si bas ? Ah. Non. C'est moi… qui suis grand.", "Why are… the clouds… so low today? Oh. No. I'm… just tall." },
	{ "On me dit lent. C'est faux. Je réfléchis… très… fort.", "They call me slow. Not true. I just think… very… hard." },
}
P.JOKE_V_humanoid = {
	{ "Ma première mission d'aventurier ? Des rats dans une cave. Depuis, je reconnais une cave à l'odeur.", "My first adventuring job? Rats in a cellar. Ever since, I can smell a cellar a mile off." },
	{ "Un vrai aventurier a trois choses : une épée, une carte, et un ami qui sait lire la carte.", "A true adventurer needs three things: a sword, a map, and a friend who can read the map." },
	{ "J'ai sauvé ce village trois fois. Ils me demandent toujours dix peaux de loup.", "I've saved this village three times. They still want ten wolf pelts." },
	{ "La différence entre un héros et un imprudent ? Le héros est encore debout.", "The difference between a hero and a fool? The hero is still standing." },
	{ "De mon temps, on allait à Forgefer à pied. Dans la neige. En montée, à l'aller comme au retour.", "Back in my day, we walked to Ironforge. Through the snow. Uphill both ways." },
	{ "Conseil d'aventurier : ne dis jamais « ça va être facile » à voix haute. Les murlocs écoutent.", "Adventurer's tip: never say 'this'll be easy' out loud. Murlocs are listening." },
}
P.JOKE_V_critter = {
	{ "Il y a un chat sur ce toit. Non, je ne tremble pas. Je vibre. Nuance.", "There's a cat on that roof. No, I'm not shaking. I'm vibrating. Big difference." },
	{ "Le pire monstre d'Azeroth ? Pas un dragon : un chat d'auberge qui s'ennuie.", "The scariest monster in Azeroth? Not a dragon. A bored tavern cat." },
	{ "Je suis petit, mais j'ai un cœur de lion. Enfin, un cœur. De souris. Qui bat très vite.", "I'm small, but I've got the heart of a lion. Well, a heart. A mouse's. Beating very fast." },
	{ "Il paraît que les chats ont neuf vies. Huit de trop, si tu veux mon avis.", "They say cats have nine lives. That's eight too many, if you ask me." },
	{ "J'ai fait un cauchemar : un chat donneur de quêtes. « Rapporte-moi dix bestioles. »", "I had a nightmare: a cat quest giver. 'Bring me ten critters.'" },
	{ "Les héros affrontent des dragons. Moi, je passe devant le chat de l'aubergiste. Chacun ses épreuves.", "Heroes face dragons. I walk past the innkeeper's cat. We all have our trials." },
}
ns.RegisterCompanionLines(P, true)
P = nil

-- la voix du type : JOKE -> JOKE_V_<type> (CompanionVoicePick)
if type(ns.COMPANION_VOICE_OF) == "table" then ns.COMPANION_VOICE_OF.JOKE = "JOKE" end

ns.RegisterDefaults({ companionJokes = true })

-- la ligne dans la page du compagnon, sous l'histoire des lieux
for _, page in ipairs(ns.OPTION_PAGES or {}) do
	if page.id == "companionMain" and type(page.rows) == "table" then
		local lore, chatter, present
		for index, row in ipairs(page.rows) do
			if row.key == "companionJokes" then present = true end
			if row.key == "companionLore" then lore = index end
			if row.key == "companionChatter" then chatter = index end
		end
		if not present then
			table.insert(page.rows, (lore or chatter or #page.rows) + 1, { key = "companionJokes", label = "OPT_COMP_JOKES", kind = "bool",
				describe = function() return L.OPT_COMP_JOKES_DESC end })
		end
	end
end

-- ---------------------------------------------------------------------------
-- Au repos : parfois une blague à la place d'un bavardage
-- ---------------------------------------------------------------------------
function ns:CompanionIdlePool()
	if self:DB().companionJokes ~= false and math.random() < ns.COMPANION_JOKE_SHARE then return "JOKE" end
	return "IDLE"
end

-- ---------------------------------------------------------------------------
-- /qc blague : une blague tout de suite (sauf en combat)
-- ---------------------------------------------------------------------------
function ns:CompanionJoke()
	local said, why = self:CompanionSay("JOKE", { force = true, asked = true, category = "event" })
	if said then return true end
	if why == "combat" then self:Print(L.JOKE_MSG_COMBAT)
	elseif why == "off" then self:Print(L.JOKE_MSG_OFF)
	else self:Print(L.JOKE_MSG_BUSY) end
	return false
end

ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["blague"] = function(self) return self:CompanionJoke() end
ns.EXTRA_COMMANDS["joke"] = ns.EXTRA_COMMANDS["blague"]
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_QUICK" and type(section[2]) == "table" then table.insert(section[2], "HELP_JOKE") end
	end
end

if ns.Mark then ns.Mark("CompanionJokes") end
