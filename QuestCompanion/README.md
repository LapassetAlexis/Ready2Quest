# QuestCompanion

**English** · [Français](#francais)

**A road companion and its travel journal.** A little creature travels with you, talks to you and grows with you. Its journal tracks the completion of every zone, opens chests of cosmetic items and makes it evolve.

For **World of Warcraft Forever** and **Classic Era**. Interface in English and French.

> **Standalone.** QuestCompanion works on its own: its `/qc` command, its settings panel, its minimap button. It pairs nicely with [Ready2Quest](../Ready2Quest/README.md) but doesn't need it: if Ready2Quest is there, the companion also reacts when you leave town and come back.

---

## Road companion

A little in-game creature (a whelp to start with) keeps you company in a corner of the screen. The companion and the **travel journal** are a single module: the journal makes the creature evolve.

## It talks to you

Short bubbles, never in combat, with several lines for each situation:
- when you **kill a monster**, **eat**, **drink** or **rest**;
- when you **talk to someone**: it gives its opinion on the vendor, the innkeeper, the flight master, the banker, the trainer or the quest giver, and comments on the creatures you target;
- when you leave town without food, die, discover a zone or sit by a campfire;
- now and then, a gameplay **tip**, or a little **conversation** of a few bubbles, as if it were chatting with you.

It also tells you **what it needs**: "I'm a bit peckish…", "Explore?", "2 more zones and I'll get: Crimson whelpling!".

## It looks out for you on the road

Outside a safe spot, it warns you about what matters, once per outing (and again if things get worse), never in combat:
- a hostile **elite or rare**, at least 2 levels above you (your target, what you hover, nameplates), outside dungeons;
- your **low health** at the end of a fight;
- your **ammo** running low, almost out, or sitting in your bags without being equipped (hunter);
- your **food** running low;
- your **gear** wearing out (below 25%, then below 10%);
- your **bags** almost full;
- all your **quests** ready to turn in;
- your **hearthstone** ready again while your bags are loaded.

With Ready2Quest, it uses the same thresholds as its check (bag space, food, durability) and the same idea of a "safe spot". How much it says depends on the **Chattiness** slider: on Discreet, only elites, health, ammo and food get through.

## It helps you in a group

Using what your game already knows about your party members (level, class, position, status):
- when the group forms: **no healer** (priest, druid, shaman, paladin), or a fine full crew;
- at or inside a **dungeon**: the member with the lowest level for the dungeon, or "the whole group fits this dungeon";
- a member **left behind** (out of sight for more than 1 min 30, out of combat and outside a safe spot) or **still elsewhere** when you're at the dungeon ("Thrall is missing, still in Orgrimmar");
- **deaths** (including the healer's: careful!) and **disconnects**.

Nothing in raids, nothing during a flight. Group makeup, dungeon and stragglers are advice (from Calm up); deaths and disconnects are reactions (Normal).

## How to look after it

It has four needs: **hunger**, **energy**, **mood** and **curiosity**. They fill up when you eat, rest, turn in a quest or explore. Click it to give it a cuddle, **right-click** to open its journal on the goals. On first launch, a short **tutorial** in a few bubbles explains all this (replay it with `/qc compagnon tuto`). Even once everything is explored, each need stays easy to fill: curiosity also grows from a zone you haven't seen in 2 hours, every dungeon, every elite or rare you defeat, every gryphon flight, every chest and every gathering node, and even from simply coming and going. Once it has gone through all its evolutions, its needs never drop below 50%.

- **It grows with you**: Hatchling, Youngling (level 10), Seasoned (20), Valiant (40) and Legendary (60). Your level unlocks the stage, but it only evolves if it is **happy**: all four needs at 70% or more. Otherwise it tells you it's ready and what it's missing, and it waits. A little celebration at each stage.
- **It never holds a grudge**: it doesn't die, doesn't regress and doesn't get sick. After a long absence, it's just a bit sleepy: "I missed you!"
- **You can customize it** with **appearances** (whelplings, tree frog, kittens, rabbit, turtle, macaw, snake, owlet, wisp, sprite darter), **ornaments**, **frames** (Copper, Oak, Silver, Frost, Runic, Fel-touched, Chased gold) and **backgrounds** (Parchment, Undergrowth, Dusk, Frost, Marble, Embers, Starry vault, Golden velvet).
- **You earn them from zone chests**: a zone at 100% opens a chest, and you **pick** one item from its tier (zones 1-19, 20-39 or 40-60). The higher the zone, the nicer the item. Once you own a whole tier, the zone turns golden. `/qc coffre` opens a pending chest.
- **It moves**: a bounce when you level up, a shiver in front of an elite, a "!" when it gives you advice, hearts when you pet it, crumbs at mealtime, "Zzz" when it sleeps, and it floats gently when it's happy. `/qc compagnon anim` plays through its animations; if one doesn't work with your appearance, `/qc compagnon anim non <name>` turns it off (the effects stay).
- **It has a character**: after three hours of watching you play, it becomes **Curious**, **Glutton**, **Daring**, **Lazy**, **Teasing** or **Cuddly**, depending on what you do most. The owlet, the macaw, the wisp, the turtle, the snake and the sprite darter each have their own (Wise, Parrot, Mystic, Zen, Sly, Mischievous). Its character changes its lines, its favourite need, what it notices and the way it moves. Settings: **Character** page.
- **Treats**: each milestone of a zone (25, 50 and 75%) earns a treat, kept in its **pantry**. **Shift + click** the creature to open it, then click a treat to give it: Travel biscuit (hunger to 100%), Soothing tea (energy), Fizzy candy (mood, with hearts), Treasure map (curiosity, and it sniffs out what's left in the zone), Feast (all four needs). At 25 and 50% you get the treat for its lowest need, at 75% a Feast, and at 100% the zone chest. Up to three of each kind and two Feasts: an extra one gets eaten on the spot. A golden chest (tier already complete) gives a Feast and two random treats.
- **It keeps memories**: the big moments of the road (levels, evolutions, dungeons, capitals, rares, completed zones, first flight, first mount, first full group, and even your silliest death) go into an album, in the **Memories** part of the journal. If you agree (it asks once), it takes a **photo** of some of them: an in-game screenshot, saved in the Screenshots folder, never in combat, three a day at most. It celebrates your anniversaries and sometimes reminisces out loud. Settings: **Memories** page.

You can rename it with `/qc compagnon nom Nugget`.

## Travel journal

Your travel collection: a **stamp** for every first time.

| Stamp | When |
|---|---|
| Zone | you discover a zone |
| Village | you enter a village or a hub, of your faction or neutral |
| Capital | you visit a capital city, even the other faction's |
| Dungeon | you enter a dungeon |
| Rare | you kill a rare enemy that you engaged yourself, with your pet or your group |
| Milestone | you reach levels 10, 20, 30, 40, 50 and 60 |

Each new stamp is announced by a small banner, never in combat. Everything is earned by playing, no random packs.

The journal (`/qc`, the minimap button, or right-click on the creature) has two parts:
- **Completion**: pick a zone from the list (the one you're in, by default) and see its percentage, its chest and, tab by tab, what's done and what's left:
  - **Exploration**: the zone's villages;
  - **Combat**: the bestiary and the named mobs;
  - **Professions**: the resources of your skill to gather;
  - **Quests**: the zone's quests your character can do (faction, race, class), done and to do. They count toward the 100%. No addon required, on Era as on Forever.
- **Track on screen**: one checkbox per zone. When checked, the zone's goals show in the in-game "Journal" tracker. The zone you're in is tracked by default (uncheck it to hide it); check other zones to keep an eye on them.
- **Evolution**: your creature's stage, the next one, its needs, how it evolves, your chests to open, your collection and your journey (zones, capitals, dungeons, rares, milestones). Hover a need (hunger, energy, mood, curiosity) to see what fills it.

## Goals

The journal sets **goals**: the creature's next stage, the next appearance or ornament, the zone's villages, capitals, dungeons for your level, the next milestone. The closest ones show on screen under the quest tracker, in a **Journal** block: the closest goal highlighted with its bar, then three more in a lighter style.

- **Zone completion**: each zone has its percentage, shown in the **Completion** part of the journal and, for the zone you're in, in the on-screen block. It weighs these equally:
  - the **villages** you've visited;
  - the **bestiary**: the species you've met and killed (it counts different species, not a number of kills);
  - the **named mobs** (elites, rares, bosses) met and killed;
  - **gathering**, if you're an herbalist, miner or skinner: the herbs, ores and leathers of your skill that you've already gathered in the zone.

  Every zone comes **pre-filled**, on Era as on Forever (Forever's own islands and zones included): its creatures (name, level, rank), the herbs and ores that grow there and its quests are known from your first visit. Whatever is missing from this data (recent Forever additions) fills in as you play.
- **Hover a goal** to know what to do: the zone's villages you still have to visit, the missing capitals, the dungeons for your level with their level range, the XP to the next level.
- **Click**: opens the journal. **Right-click**: hides the goal.
- The block collapses with a click on its title, moves by dragging it and hides in combat (configurable in the companion options, Travel journal page).

---

## Installation

1. Copy the `QuestCompanion` folder into `World of Warcraft/<client>/Interface/AddOns/`: `…/Interface/AddOns/QuestCompanion/QuestCompanion.toc`.
2. Start the game, or type `/reload`. The line "QuestCompanion — fichiers chargés" ("files loaded") shows up in the chat.

**Did you have the companion with Ready2Quest 1.25 or earlier**? Update Ready2Quest too (1.26.0 or later) and keep it enabled on your first login: your creature, your journal, your chests and their settings are taken over from its saved data, for all your characters, then stored in QuestCompanion's own (`QuestCompanion.lua` in `SavedVariables`). With a Ready2Quest 1.25, which still contains the companion, QuestCompanion stays in the background and asks you to update it.

## Settings

`/qc options`, or right-click the whelp minimap button.
- **General**: enable the addon, the minimap button and its position.
- **Road companion**: the **Size** slider (Small, Medium, Large, Huge: its frame grows, its bubble stays readable), the **Chattiness** slider (Silent, Discreet, Calm, Normal, Chatty: the line under the slider says what each step does, and it confirms it itself), appearance, frame and background; the **Ornaments** and **Travel journal** sub-pages (banner, chat, on-screen tracking).

## Commands

`/qc` or `/questcompanion`, your pick. `/qc help` shows the full help.

| Command | Effect |
|---|---|
| `/qc` | opens your travel journal (same as `/qc carnet`) |
| `/qc options` | opens the settings |
| `/qc compagnon` | your companion's mood (`nom <name>` to rename it, `tuto` to replay the tutorial, `anim` to see its animations) |
| `/qc coffre` | opens a pending zone chest |
| `/qc module compagnon off` | turns off the companion and its journal |
| `/qc minimap [on\|off]` | the minimap button |
| `/qc reset` | resets the settings, without touching your creature or your journal |
| `/qc diag` | diagnostics, to attach if you report a problem |

## Data and license

QuestCompanion is free software under the **GPL-3.0** license (see `LICENSE`). The zone data (creatures, gathering, quests) is generated from the [Questie](https://github.com/Questie/QuestieDB) database, also under GPL-3.0, by `tools/gen_zone_data.py`: see `NOTICE.md`.

---

<a id="francais"></a>

# QuestCompanion (français)

[English](#questcompanion) · **Français**

**Un compagnon de route et son carnet de voyage.** Une petite créature voyage avec toi, te parle et grandit avec toi. Son carnet suit la complétion de chaque zone, ouvre des coffres d'objets cosmétiques et la fait évoluer.

Pour **World of Warcraft Forever** et **Classic Era**. Interface en français et en anglais.

> **Autonome.** QuestCompanion fonctionne seul : sa commande `/qc`, son panneau de réglages, son bouton de minicarte. Il va très bien avec [Ready2Quest](../Ready2Quest/README.md#francais), sans en avoir besoin : si Ready2Quest est là, le compagnon réagit en plus à tes départs et retours en ville.

---

## Compagnon de route

Une petite créature du jeu (un dragonnet pour commencer) t'accompagne dans un coin de l'écran. Le compagnon et le **carnet de voyage** forment un seul module : le carnet fait évoluer la créature.

## Elle te parle

De courtes bulles, jamais en combat, avec plusieurs phrases pour chaque situation :
- quand tu **abats un monstre**, **manges**, **bois** ou te **reposes** ;
- quand tu **parles à quelqu'un** : elle donne son avis sur le marchand, l'aubergiste, le maître de vol, le banquier, l'entraîneur ou le donneur de quêtes, et commente les créatures que tu cibles ;
- quand tu quittes la ville sans vivres, meurs, découvres une zone ou t'assois au feu de camp ;
- de temps en temps, une **astuce** de jeu, ou une petite **conversation** de quelques bulles, comme si elle te parlait.

Elle dit aussi **ce dont elle a besoin** : « J'ai faim… », « On explore ? », « Encore 2 zones et j'aurai : Dragonnet cramoisi ! ».

## Elle veille sur toi en route

Hors d'un lieu sûr, elle te prévient de ce qui compte, une fois par sortie (et de nouveau si ça empire), jamais en combat :
- un **élite ou un rare** hostile, au moins 2 niveaux au-dessus de toi (ta cible, ce que tu survoles, les barres de vie), hors donjon ;
- ta **vie basse** à la fin d'un combat ;
- tes **munitions** basses, presque à sec, ou rangées dans le sac sans être équipées (chasseur) ;
- tes **vivres** bas ;
- ton **équipement** qui s'abîme (sous 25 %, puis sous 10 %) ;
- tes **sacs** presque pleins ;
- toutes tes **quêtes** prêtes à rendre ;
- ta **pierre de foyer** de nouveau prête alors que tu es chargé.

Avec Ready2Quest, elle suit les mêmes seuils que son check (place dans les sacs, vivres, durabilité) et la même idée de « lieu sûr ». Elle parle plus ou moins selon la réglette **Bavardage** : au cran Discret, seuls l'élite, la vie, les munitions et les vivres passent.

## Elle t'aide en groupe

Avec ce que ton jeu sait déjà de tes compagnons d'armes (niveau, classe, position, état) :
- quand le groupe est formé : **pas de soigneur** (prêtre, druide, chaman, paladin), ou un bel équipage au complet ;
- devant ou dans un **donjon** : le membre le plus bas par rapport au donjon, ou « tout le monde a le niveau » ;
- un membre **resté en arrière** (hors de vue plus d'1 min 30, hors combat et hors lieu sûr) ou **encore ailleurs** quand tu es au donjon (« Il manque Thrall, encore à Orgrimmar ») ;
- les **morts** (et celle du soigneur : prudence !) et les **déconnexions**.

Rien en raid, rien pendant un vol. Composition, donjon et retards sont des conseils (dès le cran Calme) ; morts et déconnexions, des réactions (cran Normal).

## Comment s'en occuper

Elle a quatre envies : **faim**, **énergie**, **moral** et **curiosité**. Elles se remplissent quand tu manges, te reposes, rends une quête ou explores. Clique dessus pour lui faire une caresse, **clic droit** pour ouvrir son carnet sur les objectifs. Au premier lancement, un **tutoriel** en quelques bulles explique tout ça (à revoir avec `/qc compagnon tuto`). Même tout exploré, chacune reste simple à remonter : la curiosité se nourrit aussi d'une zone pas vue depuis 2 h, de chaque donjon, de chaque élite ou rare vaincu, de chaque vol en griffon, de chaque coffre et de chaque récolte, et même de simples allées et venues. Une fois toutes ses évolutions faites, ses envies ne descendent plus sous 50 %.

- **Elle grandit avec toi** : Nouveau-né, Jeune (niveau 10), Aguerri (20), Vaillant (40) et Légendaire (60). Ton niveau ouvre l'étape, mais elle n'évolue que si elle est **heureuse** : ses quatre envies au moins à 70 %. Sinon elle te dit qu'elle est prête et ce qui lui manque, et elle attend. Petite fête à chaque étape.
- **Elle ne t'en veut jamais** : elle ne meurt pas, ne régresse pas et ne tombe pas malade. Après une longue absence, elle est juste un peu ensommeillée : « Tu m'as manqué ! »
- **Elle se personnalise** avec des **apparences** (dragonnets, rainette, chatons, lapin, tortue, ara, serpent, chouette, feu follet, dragon féerique), des **ornements**, des **cadres** (cuivre, chêne, argent, givre, runique, gangrené, or ciselé) et des **fonds** (parchemin, sous-bois, crépuscule, givre, marbre, braise, voûte étoilée, velours doré).
- **Ils se gagnent dans les coffres de zone** : une zone terminée à 100 % ouvre un coffre, et tu **choisis** un objet de son palier (zones 1-19, 20-39 ou 40-60). Plus la zone est haute, plus l'objet est beau. Quand tu possèdes tout un palier, la zone devient dorée. `/qc coffre` ouvre un coffre en attente.
- **Elle bouge** : un rebond quand tu montes de niveau, un tremblement devant un élite, un « ! » quand elle te conseille, des cœurs quand tu la caresses, des miettes au repas, des « Zzz » quand elle dort, et elle flotte doucement quand elle est heureuse. `/qc compagnon anim` fait défiler ses animations ; si l'une ne bouge pas avec ton apparence, `/qc compagnon anim non <nom>` la coupe (les effets restent).
- **Elle a du caractère** : après trois heures à te regarder jouer, elle devient **Curieuse**, **Gourmande**, **Téméraire**, **Paresseuse**, **Taquine** ou **Câline**, selon ce que tu fais le plus. La chouette, l'ara, le feu follet, la tortue, le serpent et le dragon féerique ont chacun le leur (Sage, Perroquet, Mystique, Zen, Rusé, Espiègle). Son caractère change ses phrases, l'envie qu'elle préfère, ce qu'elle remarque et sa façon de bouger. Réglages : page **Caractère**.
- **Des friandises** : chaque palier d'une zone (25, 50 et 75 %) rapporte une friandise, rangée dans son **garde-manger**. **Maj + clic** sur la créature l'ouvre, puis un clic sur une friandise la lui donne : Biscuit de voyage (faim à 100 %), Infusion douce (énergie), Bonbon pétillant (moral, et des cœurs), Carte au trésor (curiosité, et elle flaire ce qui reste dans la zone), Festin (les quatre envies). À 25 et 50 %, la friandise de son envie la plus basse ; à 75 %, un Festin ; à 100 %, le coffre de zone. Trois de chaque sorte et deux Festins au plus : une de trop est mangée tout de suite. Un coffre doré (palier déjà complet) donne un Festin et deux friandises au hasard.
- **Elle garde des souvenirs** : les grands moments de la route (niveaux, évolutions, donjons, capitales, rares, zones terminées, premier vol, première monture, premier groupe complet, et même ta mort la plus bête) vont dans un album, partie **Souvenirs** du carnet. Si tu es d'accord (elle le demande une fois), elle prend une **photo** de quelques-uns : une capture d'écran du jeu, rangée dans le dossier Screenshots, jamais en combat, trois par jour au plus. Elle fête vos anniversaires et se souvient parfois à voix haute. Réglages : page **Souvenirs**.

Tu peux la renommer avec `/qc compagnon nom Pépite`.

## Carnet de voyage

Ta collection de voyage : un **tampon** pour chaque première fois.

| Tampon | Quand |
|---|---|
| Zone | tu découvres une zone |
| Village | tu entres dans un village ou un hub, de ta faction ou neutre |
| Capitale | tu visites une capitale, même celle de l'autre faction |
| Donjon | tu entres dans un donjon |
| Rare | tu abats un ennemi rare que tu as toi-même engagé, avec ton familier ou ton groupe |
| Palier | tu passes les niveaux 10, 20, 30, 40, 50 et 60 |

Chaque nouveau tampon est annoncé par un petit bandeau, jamais en combat. Tout se gagne en jouant, sans paquet aléatoire.

Le carnet (`/qc`, le bouton de minicarte, ou clic droit sur la créature) a deux parties :
- **Complétion** : choisis une zone dans la liste (celle où tu es, par défaut) et vois son pourcentage, son coffre et, par onglet, ce qui est fait et ce qui reste :
  - **Exploration** : les villages de la zone ;
  - **Combat** : le bestiaire et les nommés ;
  - **Métiers** : les ressources de ta compétence à récolter ;
  - **Quêtes** : les quêtes de la zone que ton personnage peut faire (faction, race, classe), faites et à faire. Elles comptent dans les 100 %. Aucun addon requis, sur Era comme sur Forever.
- **Suivre à l'écran** : une case par zone. Cochée, les objectifs de la zone s'affichent dans le bloc « Carnet » en jeu. La zone où tu es est suivie d'office (décoche-la pour la masquer) ; coche d'autres zones pour garder un œil sur elles.
- **Évolution** : l'étape de ta créature, la prochaine, ses envies, comment elle évolue, tes coffres à ouvrir, ta collection et ton parcours (zones, capitales, donjons, rares, paliers). Survole une envie (faim, énergie, moral, curiosité) pour savoir ce qui la remplit.

## Objectifs

Le carnet fixe des **objectifs** : prochaine étape de la créature, prochaine apparence ou ornement, villages de la zone, capitales, donjons de ton niveau, prochain palier. Les plus proches s'affichent à l'écran sous le suivi des quêtes, dans un bloc **Carnet** : l'objectif le plus proche mis en avant avec sa barre, puis trois autres plus discrets.

- **Complétion de zone** : chaque zone a son pourcentage, affiché dans la partie **Complétion** du carnet et, pour la zone où tu es, dans le bloc à l'écran. Il mélange à parts égales :
  - les **villages** visités ;
  - le **bestiaire** : les espèces que tu as croisées et abattues (on compte des espèces différentes, pas un nombre de victimes) ;
  - les **nommés** (élites, rares, boss) croisés et abattus ;
  - la **récolte**, si tu es herboriste, mineur ou dépeceur : les herbes, minerais et cuirs de ta compétence que tu as déjà récoltés dans la zone.

  Chaque zone arrive **préremplie**, sur Era comme sur Forever (îles et zones propres à Forever comprises) : ses créatures (nom, niveau, rang), les herbes et minerais qui y poussent et ses quêtes sont connus dès ta première visite. Ce qui manque à ces données (nouveautés récentes de Forever) se remplit en jouant.
- **Survole un objectif** pour savoir quoi faire : les villages de la zone qu'il te reste à visiter, les capitales manquantes, les donjons de ton niveau avec leur tranche, l'XP avant le prochain niveau.
- **Clic** : ouvre le carnet. **Clic droit** : masque l'objectif.
- Le bloc se replie d'un clic sur son titre, se déplace en le glissant et se cache en combat (réglable dans les options du compagnon, page Carnet).

---

## Installation

1. Copie le dossier `QuestCompanion` dans `World of Warcraft/<client>/Interface/AddOns/` : `…/Interface/AddOns/QuestCompanion/QuestCompanion.toc`.
2. Lance le jeu, ou tape `/reload`. La ligne « QuestCompanion — fichiers chargés » apparaît dans le chat.

**Tu avais le compagnon avec Ready2Quest 1.25 ou avant** ? Mets aussi Ready2Quest à jour (1.26.0 ou plus) et garde-le activé à la première connexion : ta créature, ton carnet, tes coffres et leurs réglages sont repris de sa sauvegarde, pour tous tes personnages, puis rangés dans celle de QuestCompanion (`QuestCompanion.lua` dans `SavedVariables`). Avec un Ready2Quest 1.25, qui contient encore le compagnon, QuestCompanion reste en retrait et te demande de le mettre à jour.

## Réglages

`/qc options`, ou un clic droit sur le bouton de minicarte au dragonnet.
- **Général** : activer l'addon, le bouton de minicarte et sa position.
- **Compagnon de route** : la réglette **Taille** (Petit, Moyen, Grand, Très grand : son cadre grandit, sa bulle reste lisible), la réglette **Bavardage** (Muet, Discret, Calme, Normal, Bavard : la phrase sous la réglette dit ce que fait chaque cran, et il te le confirme lui-même), apparence, cadre et fond ; les sous-pages **Ornements** et **Carnet** (bandeau, chat, suivi à l'écran).

## Commandes

`/qc` ou `/questcompanion`, au choix. `/qc help` affiche l'aide complète.

| Commande | Effet |
|---|---|
| `/qc` | ouvre ton carnet de voyage (comme `/qc carnet`) |
| `/qc options` | ouvre les réglages |
| `/qc compagnon` | l'humeur de ton compagnon (`nom <nom>` pour le renommer, `tuto` pour revoir le tutoriel, `anim` pour voir ses animations) |
| `/qc coffre` | ouvre un coffre de zone en attente |
| `/qc module compagnon off` | coupe le compagnon et son carnet |
| `/qc minimap [on\|off]` | le bouton de minicarte |
| `/qc reset` | remet les réglages à zéro, sans toucher à ta créature ni à ton carnet |
| `/qc diag` | diagnostic, à joindre si tu signales un problème |

## Données et licence

QuestCompanion est un logiciel libre sous licence **GPL-3.0** (voir `LICENSE`). Les données de zones (créatures, récolte, quêtes) sont générées depuis la base de [Questie](https://github.com/Questie/QuestieDB), elle aussi sous GPL-3.0, par `tools/gen_zone_data.py` : voir `NOTICE.md`.
