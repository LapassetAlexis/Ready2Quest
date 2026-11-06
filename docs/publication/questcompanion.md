<!--
Fiche de la page QuestCompanion sur CurseForge et Wago (à copier à la main, voir docs/PUBLIER.md).
Summary EN (256 caractères max, ici 212) :
  A little creature travels with you: it talks, grows and forms a personality. Capture monsters, normal and shiny, for your menagerie, explore every zone, open cosmetic chests, keep photo memories. For WoW Forever.
Summary FR (256 caractères max, ici 227) :
  Une petite créature voyage avec toi : elle parle, grandit et se forge un caractère. Capture les monstres, normaux et brillants, explore chaque zone, ouvre des coffres cosmétiques, garde tes souvenirs en photo. Pour WoW Forever.
Catégories : Companions (principale), Quests & Leveling (additionnelle). Si Companions n'existe pas : Miscellaneous (principale).
Licence : GPLv3. Logo : docs/publication/logo_questcompanion.png.
Relation : Optional Dependency -> Ready2Quest (facultatif).
Captures à prendre en jeu : le compagnon et une bulle, la scène de capture (filet), la page Ménagerie (avec une brillante), la page Compagnon, la page Exploration, la page Missions, le coffre de zone ouvert, l'album Souvenirs.
Deux descriptions complètes ci-dessous : anglais, puis français. Coller celle de la langue voulue.
-->
# QuestCompanion

**A little travel companion, a menagerie to capture and a journal to explore every zone.** A small creature travels with you, talks to you and grows with you. Capture the monsters you defeat, normal and shiny; its journal tracks how explored each zone is and rewards a 100% zone with a chest of cosmetic items.

For **WoW Forever** (1.60). English and French.

**Standalone.** Its own `/qc` command, settings and minimap button. It also pairs well with [Ready2Quest](https://github.com/LapassetAlexis/Ready2Quest): installed together, the companion reacts to your departures and returns.

## The companion

- **It talks**: short bubbles, never in combat, when you kill, eat, rest, talk to an NPC, discover a zone, sit by a campfire… plus tips and small conversations.
- **It looks out for you**: out in the wild, it warns you once about what matters: a dangerous elite or rare, low health after a fight, low food or ammo, damaged gear, full bags, quests ready to turn in.
- **It helps your group**: no healer, someone too low for the dungeon, a member left behind, deaths and disconnects. Nothing in raids.
- **Four needs**: hunger, energy, mood and curiosity. They fill up as you eat, rest, turn in quests and explore. Click it for a pat. Right-click it to open its journal.
- **It grows with you**: Newborn, Young (level 10), Seasoned (20), Valiant (40), Legendary (60). Your level opens the next stage, but it only evolves when it is **happy**, with all four needs at 70% or more.
- **It never punishes you**: it doesn't die, regress or get sick. After a long break, it's just a bit sleepy.
- **It moves**: a bounce when you level up, a shiver in front of an elite, a "!" when it gives advice, hearts when you pat it, crumbs while eating, "Zzz" when asleep, and it floats gently when happy.
- **It has a personality**: after three hours watching you play, it becomes **Curious**, **Glutton**, **Daring**, **Lazy**, **Teasing** or **Cuddly**, depending on what you do most. Several appearances have their own (Wise, Parrot, Mystic, Zen, Sly, Mischievous, Fearful, Tinker). Its personality changes what it says, the need it cares about, what it notices and how it moves.
- **It keeps memories**: the big moments of the road (levels, evolutions, dungeons, capitals, rares, completed zones, first flight, first mount, first full group, even your silliest death) go into an album. If you agree (it asks once), it takes a **photo** of some of them: an in-game screenshot, never in combat, three a day at most. It celebrates your anniversaries and sometimes remembers out loud.
- **Treats**: zone milestones earn treats for its pantry (Shift + click it): biscuit, tea, candy, treasure map, Feast.
- **Cosmetics**: nineteen mascot appearances plus every creature you capture, ornaments, frames and backgrounds.

## Capture your menagerie

- **Capture what you defeat**: a "Capture?" window, one click, one try; a mesh net drops over the creature, shakes once, twice, three times… and it's yours, or it tears and the creature runs off. Odds depend on rank and level; **capture aids** (bait, lasso, tamer's whistle) come from the journal.
- **Every creature of the game**: the **Menagerie** lists every capturable creature (about 3,500 for your faction), numbered like a creature index, "???" until you meet it, its name in its rarity colour, with a 3D card. Click a captured one: it becomes your companion, and keeps its own name.
- **Shinies**: any monster can be shiny (1 in 150, more for elites and rares, and more the more of that species you defeat). A gold diamond sparkles over its nameplate and your companion calls it out. Each species has a **normal and a shiny capture**; a shiny companion glows gold. A spotted shiny stays known in the Menagerie, even uncaught.

## The journal

- **Exploration**: every zone and its percentage. For the chosen zone: its milestones (treats, capture aids, a Feast), its places, the herbs and ores for your professions (including those that need more skill), its quests your character can do, and its chest. A 100% zone opens a chest where you **choose** a cosmetic item (zones 1-19, 20-39, 40-60).
- **Prefilled zones**: creatures, gathering nodes and quests of every zone are known from your first visit (Forever islands and zones included). No other addon needed.
- **Missions**: two of the day in your zone plus one from your companion's personality, three of the week (always a shiny hunt among them); they reward treats and capture aids. An inn loyalty card, too.
- **Companion**: your creature up close, its numbers (captured, shinies, days together, missions done, distance travelled together), its needs and its look (appearances, frames, backgrounds, ornaments).
- **Memories**: the album of your adventure. Each memory gets a photo recreated by your companion, on the game's own loading-screen art for dungeons, raids and Forever's own places, or a Warcraft-style landscape of the zone elsewhere, each with its own shot and gesture.
- **Stamps** for every first, and an **on-screen tracker** with your closest goals.
- **Light**: about 2 MB of memory.

## Commands

`/qc` opens the journal (so does the minimap button, or a right-click on the companion), `/qc options` opens the settings, `/qc compagnon` shows your companion's mood (`/qc compagnon nom <name>` renames it, `/qc compagnon anim` plays its animations), `/qc coffre` opens a pending chest, `/qc capture` sums up your menagerie, `/qc help` lists everything.

## Coming from Ready2Quest 1.25 or earlier?

Update Ready2Quest to 1.26.0 and keep it enabled on first login: your companion, journal, chests and their settings are taken over automatically, for all your characters.

## License and data

Free software, **GPL-3.0**. Zone data (creatures, gathering, quests) is generated from the [Questie](https://github.com/Questie/QuestieDB) database, also GPL-3.0. Source code: https://github.com/LapassetAlexis/Ready2Quest

---

# QuestCompanion (français)

**Un compagnon de route, une ménagerie à capturer et un carnet pour explorer chaque zone.** Une petite créature voyage avec toi, te parle et grandit avec toi. Capture les monstres que tu abats, normaux et brillants ; son carnet suit l'exploration de chaque zone et récompense une zone à 100 % par un coffre d'objets cosmétiques.

Pour **WoW Forever** (1.60). En français et en anglais.

**Autonome.** Sa commande `/qc`, ses réglages et son bouton de minicarte. Il va très bien avec [Ready2Quest](https://github.com/LapassetAlexis/Ready2Quest) : installés ensemble, le compagnon réagit en plus à tes départs et retours en ville.

## Le compagnon

- **Elle te parle** : de courtes bulles, jamais en combat, quand tu abats un monstre, manges, te reposes, parles à un PNJ, découvres une zone, t'assois au feu de camp… avec des astuces et de petites conversations.
- **Elle veille sur toi** : hors d'un lieu sûr, elle te prévient une fois de ce qui compte : un élite ou un rare dangereux, ta vie basse après un combat, tes vivres ou tes munitions bas, ton équipement abîmé, tes sacs pleins, tes quêtes prêtes à rendre.
- **Elle aide ton groupe** : pas de soigneur, un membre trop bas pour le donjon, un autre resté en arrière, les morts et les déconnexions. Rien en raid.
- **Quatre envies** : faim, énergie, moral et curiosité. Elles se remplissent quand tu manges, te reposes, rends une quête ou explores. Clic pour une caresse, clic droit pour ouvrir son carnet.
- **Elle grandit avec toi** : Nouveau-né, Jeune (niveau 10), Aguerri (20), Vaillant (40), Légendaire (60). Ton niveau ouvre l'étape, mais elle n'évolue que si elle est **heureuse**, avec ses quatre envies à 70 % ou plus.
- **Elle ne t'en veut jamais** : elle ne meurt pas, ne régresse pas et ne tombe pas malade. Après une longue absence, elle est juste un peu ensommeillée.
- **Elle bouge** : un rebond quand tu montes de niveau, un tremblement devant un élite, un « ! » quand elle te conseille, des cœurs quand tu la caresses, des miettes au repas, des « Zzz » quand elle dort, et elle flotte doucement quand elle est heureuse.
- **Elle a du caractère** : après trois heures à te regarder jouer, elle devient **Curieuse**, **Gourmande**, **Téméraire**, **Paresseuse**, **Taquine** ou **Câline**, selon ce que tu fais le plus. Plusieurs apparences ont le leur (Sage, Perroquet, Mystique, Zen, Rusé, Espiègle, Peureux, Bricoleur). Son caractère change ses phrases, l'envie qu'elle préfère, ce qu'elle remarque et sa façon de bouger.
- **Elle garde des souvenirs** : les grands moments de la route (niveaux, évolutions, donjons, capitales, rares, zones terminées, premier vol, première monture, premier groupe complet, et même ta mort la plus bête) vont dans un album. Si tu es d'accord (elle le demande une fois), elle prend une **photo** de quelques-uns : une capture d'écran du jeu, jamais en combat, trois par jour au plus. Elle fête vos anniversaires et se souvient parfois à voix haute.
- **Des friandises** : les paliers des zones remplissent son garde-manger (Maj + clic) : biscuit, infusion, bonbon, carte au trésor, Festin.
- **Cosmétiques** : dix-neuf apparences de mascotte et toutes les créatures que tu captures, ornements, cadres et fonds.

## Ta ménagerie à capturer

- **Capture ce que tu abats** : une fenêtre « Capturer ? », un clic, un essai ; un filet maillé tombe sur la créature, bouge une fois, deux fois, trois fois… et elle est à toi, ou il se déchire et elle s'enfuit. La chance dépend du rang et du niveau ; des **aides de capture** (appât, lasso, sifflet du dompteur) se gagnent dans le carnet.
- **Toutes les créatures du jeu** : la **Ménagerie** liste toutes les créatures capturables (environ 3 500 pour ta faction), numérotées comme un Pokédex, « ??? » tant que tu ne les as pas croisées, leur nom à la couleur de leur rareté, avec une fiche en 3D. Clic sur une capturée : elle devient ton compagnon, et garde son nom.
- **Les brillantes** : n'importe quel monstre peut être brillant (une chance sur 150, plus pour un élite ou un rare, et plus tu as abattu de son espèce). Un losange doré scintille sur sa barre de nom et ton compagnon te prévient. Chaque espèce a une **capture normale et une capture brillante** ; un compagnon brillant luit d'or. Une brillante repérée reste connue dans la Ménagerie, même sans capture.

## Le carnet

- **Exploration** : toutes les zones et leur pourcentage. Pour la zone choisie : ses paliers (friandises, aides de capture, un Festin), ses lieux, les herbes et minerais de tes métiers (y compris ceux qui demandent plus de compétence), ses quêtes faisables par ton personnage, et son coffre. Une zone à 100 % ouvre un coffre où tu **choisis** un objet cosmétique (zones 1-19, 20-39, 40-60).
- **Zones préremplies** : créatures, points de récolte et quêtes de chaque zone sont connus dès ta première visite (îles et zones propres à Forever comprises). Aucun autre addon requis.
- **Missions** : deux du jour dans ta zone et une de son caractère, trois de la semaine (dont toujours une chasse au brillant) ; elles rapportent friandises et aides de capture. Et une carte de fidélité des auberges.
- **Compagnon** : ta créature en grand, ses chiffres (capturées, brillantes, jours ensemble, missions faites, distance parcourue ensemble), ses envies et son allure (apparences, cadres, fonds, ornements).
- **Souvenirs** : l'album de ton aventure. Chaque souvenir a sa photo recréée par ton compagnon, sur l'écran de chargement du jeu pour les donjons, raids et lieux propres à Forever, ailleurs sur un paysage façon Warcraft de la zone, chacune avec son cadrage et son geste.
- **Des tampons** pour chaque première fois, et un **suivi à l'écran** de tes objectifs les plus proches.
- **Léger** : environ 2 Mo de mémoire.

## Commandes

`/qc` ouvre le carnet (comme le bouton de minicarte ou un clic droit sur le compagnon), `/qc options` ouvre les réglages, `/qc compagnon` montre son humeur (`/qc compagnon nom <nom>` pour le renommer, `/qc compagnon anim` pour voir ses animations), `/qc coffre` ouvre un coffre en attente, `/qc capture` résume ta ménagerie, `/qc help` liste tout.

## Tu viens de Ready2Quest 1.25 ou avant ?

Mets Ready2Quest à jour (1.26.0) et garde-le activé à la première connexion : ton compagnon, ton carnet, tes coffres et leurs réglages sont repris automatiquement, pour tous tes personnages.

## Licence et données

Logiciel libre, **GPL-3.0**. Les données de zones (créatures, récolte, quêtes) sont générées depuis la base de [Questie](https://github.com/Questie/QuestieDB), elle aussi sous GPL-3.0. Code source : https://github.com/LapassetAlexis/Ready2Quest
