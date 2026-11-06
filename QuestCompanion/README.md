# QuestCompanion

**English** · [Français](#francais)

**A road companion and its travel journal.** A little creature travels with you, talks to you and grows with you. Its journal tracks the completion of every zone, opens chests of cosmetic items and makes it evolve.

For **World of Warcraft Forever**. Interface in English and French.

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

It has four needs: **hunger**, **energy**, **mood** and **curiosity**. They fill up when you eat, rest, turn in a quest or explore. Click it to give it a cuddle, **Shift + click** to open its pantry, **right-click** to open its journal. On first launch, a short **tutorial** in a few bubbles explains all this (replay it with `/qc compagnon tuto`). Even once everything is explored, each need stays easy to fill: curiosity also grows from a zone you haven't seen in 2 hours, every dungeon, every elite or rare you defeat, every gryphon flight, every chest and every gathering node, and even from simply coming and going. Once it has gone through all its evolutions, its needs never drop below 50%.

- **It grows with you**: Hatchling, Youngling (level 10), Seasoned (20), Valiant (40) and Legendary (60). Your level unlocks the stage, but it only evolves if it is **happy**: all four needs at 70% or more. Otherwise it tells you it's ready and what it's missing, and it waits. A little celebration at each stage.
- **It never holds a grudge**: it doesn't die, doesn't regress and doesn't get sick. After a long absence, it's just a bit sleepy: "I missed you!"
- **You can customize it** with **appearances** (whelplings, tree frog, kittens, rabbit, turtle, macaw, snake, owlet, wisp, sprite darter, and since 1.2.0 silver tabby, spotted toad, Bombay cat, scarlet macaw, panda cub, baby murloc, chicken, mechanical squirrel, hippogryph hatchling), **ornaments**, **frames** (Copper, Oak, Silver, Frost, Runic, Fel-touched, Chased gold) and **backgrounds** (Parchment, Undergrowth, Dusk, Frost, Marble, Embers, Starry vault, Golden velvet).
- **You earn them from zone chests**: a zone at 100% opens a chest, and you **pick** one item from its tier (zones 1-19, 20-39 or 40-60). The higher the zone, the nicer the item. Once you own a whole tier, the zone turns golden. `/qc coffre` opens a pending chest.
- **It moves**: a bounce when you level up, a shiver in front of an elite, a "!" when it gives you advice, hearts when you pet it, crumbs at mealtime, "Zzz" when it sleeps, and it floats gently when it's happy. `/qc compagnon anim` plays through its animations; if one doesn't work with your appearance, `/qc compagnon anim non <name>` turns it off (the effects stay).
- **It has a character**: after three hours of watching you play, it becomes **Curious**, **Glutton**, **Daring**, **Lazy**, **Teasing** or **Cuddly**, depending on what you do most. The owlet, the macaw, the wisp, the turtle, the snake, the sprite darter, the chicken and the mechanical squirrel each have their own (Wise, Parrot, Mystic, Zen, Sly, Mischievous, Fearful, Tinker). Its character changes its lines, its favourite need, what it notices and the way it moves. Settings: **Character** page.
- **Treats**: each milestone of a zone (25, 50 and 75%) earns a treat, kept in its **pantry**. **Shift + click** the creature to open it, then click a treat to give it: Travel biscuit (hunger to 100%), Soothing tea (energy), Fizzy candy (mood, with hearts), Treasure map (curiosity, and it sniffs out what's left in the zone), Feast (all four needs). At 25 and 50% you get the treat for its lowest need, at 75% a Feast, and at 100% the zone chest. Up to three of each kind and two Feasts: an extra one gets eaten on the spot. A golden chest (tier already complete) gives a Feast and two random treats.
- **Capture monsters (menagerie)**: since 1.4.0, every monster you defeat can be **captured**. A small "Capture?" window shows up for 12 seconds with its model, its rank and your chance: one click, one try. The net shakes once, twice, three times… and it's yours, or it gets away (and your companion teases you about it). Chance depends on rank (normal 30%, elite 15%, rare 8%, rare elite 5%, boss 2%) and level (harder above your level). **Capture aids** come at random from journal stamps, zone milestones and shinies: **Tasty bait** (×1.5), **Braided lasso** (×2.5), **Tamer's whistle** (guaranteed); click one in the window to use it for that try. A captured species becomes a **companion appearance** (settings and journal Collection), and a captured shiny keeps its sparkle. Every 10 captures, a free whistle. The journal's **Menagerie** tab works like a creature index: every capturable creature in the game (about 3,500 species for your faction), numbered, "???" until you've met it, your current zone by default with a list to pick any zone (or all), filters (captured, to capture, to defeat, rarity), a name search and sorting (number, name, level, rarity, capture date). Each name (or "???") shows in its rarity colour, captured ones with a green edge on the left, zones listed alphabetically, with a 3D preview; click one to make it your companion. `/qc capture` sums up your menagerie. Settings: **Day by day** page.
- **Shiny creatures**: the first time you target or hover a monster, it has a 1 in 150 chance of being shiny (three times more for an elite or a rare). Your companion spots it (bubble, "!", sparkles) and puts a **star** above its head if you play solo or lead the group. Defeat it: its bestiary card turns golden, your companion gets a treat (sometimes a Feast) and keeps a memory. At **5, 15 and 30** shinies, three cosmetics no chest gives: the **Sparkling** frame, the **Stardust** background and a **Shimmering aura**.
- **Day by day**: one loyalty card for every inn, one stamp a day at any innkeeper (+20 energy), a Feast on the 7th stamp, no need for days in a row. And **missions of the day**: on your first zone of the day, your companion offers two missions there (only feasible ones: new species, an elite or a rare, gathering, quests, a place never seen, +3% completion) and one from its character. You can change a zone mission once a day. Since 1.4.0 there are also **three missions of the week** (capture creatures, capture an elite or a rare, complete daily missions, defeat enemies, earn stamps, gather, turn in quests), renewed at the weekly reset. Rewards feed both your creature and your menagerie: each daily mission gives a treat and a Tasty bait, all three a Feast and a Braided lasso; each weekly mission a treat and a Braided lasso, all three a Feast and a Tamer's whistle. Everything is in the journal's **Missions** tab (with your inn card, pantry and capture pack) and in the on-screen block. Settings: **Day by day** page.
- **It announces your progress**: each new entry in the journal (a species defeated for the first time, a named mob, a resource gathered for the first time in the zone, a zone quest turned in) gets a short bubble with where the zone part stands ("bestiary 13/24"). And its frame glows softly while it speaks, to catch your eye.
- **It keeps memories**: the big moments of the road (levels, evolutions, dungeons, capitals, rares, completed zones, first flight, first mount, first full group, and even your silliest death) go into an album, in the **Memories** part of the journal. If you agree (it asks once), it takes a **photo** of some of them: an in-game screenshot, saved in the Screenshots folder, never in combat, three a day at most. It celebrates your anniversaries and sometimes reminisces out loud. Settings: **Memories** page.

You can rename it with `/qc compagnon nom Nugget`.

## Travel journal

**Since 1.5.0, five pages** (`/qc`, or right-click your companion):
- **Companion**: your creature up close (portrait with its frame and background, character, evolution steps, its last line), five numbers (captured, shinies, days together, missions done, **distance travelled together**), its needs, and its look: appearances (mascots and captured creatures), frame, background, ornaments.
- **Menagerie**: every capturable creature, as one numbered list to filter (zone, captured / to capture / to defeat, rarity, name search, sorting), with a 3D card.
- **Missions**: companion, daily and weekly missions with their rewards, the capture pack, the pantry and the inn card.
- **Exploration** (called Completion until 1.5.0): every zone and its progress; for the chosen zone, its milestones and what they give, places, professions (the gathering of the zone, grey resources included, and every profession you know) and quests, and the zone chest.
- **Souvenirs**: the album of the road, each memory with a photo recreated by your companion on a painted backdrop (meadow, dawn, dusk, cave, city, treasure, storm, above the clouds), each with its own shot (close-up, far away, from behind, mid-air…) and gesture (in-game screenshots stay in the Screenshots folder: addons can't read them).

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

The journal (`/qc`, the minimap button, or right-click on the creature) opens on the last tab you used (the first time, on **Creature**, the first tab). Its tabs run down the right side, and your **pantry** (treats) sits in its header: click a treat to give it.
- **Creature**: its stage, the next one, its character, its needs, how it evolves, your chests to open, your collection and your journey (zones, capitals, dungeons, rares, milestones). Hover a need (hunger, energy, mood, curiosity) to see what fills it.
- **Zones**: a grid of every zone in the game, Forever's own zones included, the ones you've never visited shown greyed out. Each tile gives its level range and percentage, and says if a chest is waiting. Filter by continent, sort by level or by percentage, click a tile to open it.
- **Zone**: one zone, with arrows to the previous and next one (the mouse back button returns to the grid). Its percentage, its milestones (25, 50 and 75% give a treat, 100% the chest) and, tab by tab, what's done and what's left:
  - **Exploration**: the zone's villages, on two columns;
  - **Combat**: a card for each creature of the bestiary, its border coloured by rank (elite, rare, boss), "???" for those you've never met. Hover a card to see the creature in 3D next to the grid;
  - **Professions**: the icons of the resources of your skill, in colour once gathered here;
  - **Quests**: the zone's quests your character can do (faction, race, class), on two columns, filtered by to do or done. They count toward the 100%. No addon required.
- **Track on screen** (Zone tab): when on, the zone's goals show in the in-game "Journal" tracker. The zone you're in is tracked by default (turn it off to hide it); turn other zones on to keep an eye on them.
- **Day**: the missions of the day (with the button to change one), the inn loyalty card and the pantry.
- **Collection**: every appearance, ornament, frame and background, the locked ones greyed out with where to get them. Hover an item to preview it, click to equip it (an ornament: click to wear it or take it off).
- **Memories**: the album.

## Goals

The journal sets **goals**: the creature's next stage, the next appearance or ornament, the zone's villages, capitals, dungeons for your level, the next milestone. The closest ones show on screen under the quest tracker, in a **Journal** block: the closest goal highlighted with its bar, then three more in a lighter style.

- **Zone completion**: each zone has its percentage, shown in the **Exploration** page of the journal and, for the zone you're in, in the on-screen block. It weighs these equally:
  - the **villages** you've visited;
  - the **bestiary**: the species you've met and killed (it counts different species, not a number of kills);
  - the **named mobs** (elites, rares, bosses) met and killed;
  - **gathering**, if you're an herbalist, miner or skinner: the herbs, ores and leathers of your skill that you've already gathered in the zone.

  Every zone comes **pre-filled** (Forever's own islands and zones included): its creatures (name, level, rank), the herbs and ores that grow there and its quests are known from your first visit. Whatever is missing from this data (recent Forever additions) fills in as you play.
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
| `/qc capture` | your menagerie and capture aids |
| `/qc metiers` | the professions the game gives the addon (to report a bug) |
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

Pour **World of Warcraft Forever**. Interface en français et en anglais.

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

Elle a quatre envies : **faim**, **énergie**, **moral** et **curiosité**. Elles se remplissent quand tu manges, te reposes, rends une quête ou explores. Clique dessus pour lui faire une caresse, **Maj + clic** pour son garde-manger, **clic droit** pour ouvrir son carnet. Au premier lancement, un **tutoriel** en quelques bulles explique tout ça (à revoir avec `/qc compagnon tuto`). Même tout exploré, chacune reste simple à remonter : la curiosité se nourrit aussi d'une zone pas vue depuis 2 h, de chaque donjon, de chaque élite ou rare vaincu, de chaque vol en griffon, de chaque coffre et de chaque récolte, et même de simples allées et venues. Une fois toutes ses évolutions faites, ses envies ne descendent plus sous 50 %.

- **Elle grandit avec toi** : Nouveau-né, Jeune (niveau 10), Aguerri (20), Vaillant (40) et Légendaire (60). Ton niveau ouvre l'étape, mais elle n'évolue que si elle est **heureuse** : ses quatre envies au moins à 70 %. Sinon elle te dit qu'elle est prête et ce qui lui manque, et elle attend. Petite fête à chaque étape.
- **Elle ne t'en veut jamais** : elle ne meurt pas, ne régresse pas et ne tombe pas malade. Après une longue absence, elle est juste un peu ensommeillée : « Tu m'as manqué ! »
- **Elle se personnalise** avec des **apparences** (dragonnets, rainette, chatons, lapin, tortue, ara, serpent, chouette, feu follet, dragon féerique, et depuis la 1.2.0 chat tigré argenté, crapaud tacheté, chat Bombay, ara écarlate, bébé panda, bébé murloc, poulet, écureuil mécanique, bébé hippogriffe), des **ornements**, des **cadres** (cuivre, chêne, argent, givre, runique, gangrené, or ciselé) et des **fonds** (parchemin, sous-bois, crépuscule, givre, marbre, braise, voûte étoilée, velours doré).
- **Ils se gagnent dans les coffres de zone** : une zone terminée à 100 % ouvre un coffre, et tu **choisis** un objet de son palier (zones 1-19, 20-39 ou 40-60). Plus la zone est haute, plus l'objet est beau. Quand tu possèdes tout un palier, la zone devient dorée. `/qc coffre` ouvre un coffre en attente.
- **Elle bouge** : un rebond quand tu montes de niveau, un tremblement devant un élite, un « ! » quand elle te conseille, des cœurs quand tu la caresses, des miettes au repas, des « Zzz » quand elle dort, et elle flotte doucement quand elle est heureuse. `/qc compagnon anim` fait défiler ses animations ; si l'une ne bouge pas avec ton apparence, `/qc compagnon anim non <nom>` la coupe (les effets restent).
- **Elle a du caractère** : après trois heures à te regarder jouer, elle devient **Curieuse**, **Gourmande**, **Téméraire**, **Paresseuse**, **Taquine** ou **Câline**, selon ce que tu fais le plus. La chouette, l'ara, le feu follet, la tortue, le serpent, le dragon féerique, le poulet et l'écureuil mécanique ont chacun le leur (Sage, Perroquet, Mystique, Zen, Rusé, Espiègle, Peureux, Bricoleur). Son caractère change ses phrases, l'envie qu'elle préfère, ce qu'elle remarque et sa façon de bouger. Réglages : page **Caractère**.
- **Des friandises** : chaque palier d'une zone (25, 50 et 75 %) rapporte une friandise, rangée dans son **garde-manger**. **Maj + clic** sur la créature l'ouvre, puis un clic sur une friandise la lui donne : Biscuit de voyage (faim à 100 %), Infusion douce (énergie), Bonbon pétillant (moral, et des cœurs), Carte au trésor (curiosité, et elle flaire ce qui reste dans la zone), Festin (les quatre envies). À 25 et 50 %, la friandise de son envie la plus basse ; à 75 %, un Festin ; à 100 %, le coffre de zone. Trois de chaque sorte et deux Festins au plus : une de trop est mangée tout de suite. Un coffre doré (palier déjà complet) donne un Festin et deux friandises au hasard.
- **Capturer les monstres (ménagerie)** : depuis la 1.4.0, chaque monstre abattu peut être **capturé**. Une petite fenêtre « Capturer ? » apparaît 12 secondes avec son modèle, son rang et ta chance : un clic, un essai. Le filet bouge une fois, deux fois, trois fois… et il est à toi, ou il s'échappe (et ton compagnon se moque). La chance dépend du rang (normal 30 %, élite 15 %, rare 8 %, rare élite 5 %, boss 2 %) et du niveau (plus dur au-dessus du tien). Des **aides de capture** tombent au hasard des tampons du carnet, des paliers de zone et des brillantes : **Appât savoureux** (×1,5), **Lasso tressé** (×2,5), **Sifflet du dompteur** (assurée) ; clique dessus dans la fenêtre pour l'utiliser à cet essai. Une espèce capturée devient une **apparence du compagnon** (réglages et Collection du carnet), une brillante capturée garde son éclat. Toutes les 10 captures, un Sifflet offert. L'onglet **Ménagerie** du carnet fait office de Pokédex : toutes les créatures capturables du jeu (environ 3 500 espèces pour ta faction), numérotées, « ??? » tant que tu ne les as pas croisées, la zone où tu es par défaut avec une liste pour en choisir une autre (ou toutes), des filtres (capturées, à capturer, à abattre, rareté), une recherche par nom et des tris (numéro, nom, niveau, rareté, date de capture). Chaque nom (ou « ??? ») s'affiche à la couleur de sa rareté, les capturées avec un liseré vert à gauche, les zones par ordre alphabétique, avec un aperçu 3D ; un clic en fait ton compagnon. `/qc capture` résume ta ménagerie. Réglages : page **Au jour le jour**.
- **Des créatures brillantes** : la première fois que tu cibles ou survoles un monstre, il a une chance sur 150 d'être brillant (trois fois plus pour un élite ou un rare). Ta créature le repère (bulle, « ! », étincelles) et pose une **étoile** au-dessus de lui si tu joues seul ou mènes le groupe. Abats-le : sa fiche du bestiaire devient dorée, ta créature reçoit une friandise (parfois un Festin) et garde un souvenir. À **5, 15 et 30** brillantes, trois cosmétiques qu'aucun coffre ne donne : le cadre **Étincelant**, le fond **Poussière d'étoiles** et une **aura scintillante**.
- **Au jour le jour** : une carte de fidélité pour toutes les auberges, un tampon par jour chez n'importe quel aubergiste (+20 d'énergie), un Festin au 7e tampon, sans jours d'affilée. Et des **missions du jour** : à ta première zone de la journée, ta créature t'en propose deux dans cette zone (seulement des faisables : espèces nouvelles, un élite ou un rare, récolte, quêtes, un lieu jamais vu, +3 % de complétion) et une de son caractère. Une mission de zone se change une fois par jour. Depuis la 1.4.0, il y a aussi **trois missions de la semaine** (capturer des créatures, capturer un élite ou un rare, enchaîner les missions du jour, abattre, tamponner le carnet, récolter, rendre des quêtes), renouvelées à la remise à zéro hebdomadaire. Les récompenses nourrissent ta créature ET ta ménagerie : chaque mission du jour donne une friandise et un Appât savoureux, les trois un Festin et un Lasso tressé ; chaque mission de la semaine une friandise et un Lasso tressé, les trois un Festin et un Sifflet du dompteur. Tout est dans l'onglet **Missions** du carnet (avec la carte des auberges, le garde-manger et la besace de capture) et dans le bloc à l'écran. Réglages : page **Au jour le jour**.
- **Elle annonce tes progrès** : chaque nouvelle entrée du carnet (une espèce abattue pour la première fois, un nommé, une ressource récoltée pour la première fois dans la zone, une quête de la zone rendue) a sa courte bulle, avec où en est la partie de la zone (« bestiaire 13/24 »). Et son cadre brille doucement quand elle parle, pour attirer l'œil.
- **Elle garde des souvenirs** : les grands moments de la route (niveaux, évolutions, donjons, capitales, rares, zones terminées, premier vol, première monture, premier groupe complet, et même ta mort la plus bête) vont dans un album, partie **Souvenirs** du carnet. Si tu es d'accord (elle le demande une fois), elle prend une **photo** de quelques-uns : une capture d'écran du jeu, rangée dans le dossier Screenshots, jamais en combat, trois par jour au plus. Elle fête vos anniversaires et se souvient parfois à voix haute. Réglages : page **Souvenirs**.

Tu peux la renommer avec `/qc compagnon nom Pépite`.

## Carnet de voyage

**Depuis la 1.5.0, cinq pages** (`/qc`, ou clic droit sur ton compagnon) :
- **Compagnon** : ta créature en grand (portrait avec son cadre et son fond, caractère, étapes d'évolution, sa dernière réplique), cinq chiffres (capturées, brillantes, jours ensemble, missions faites, **distance parcourue ensemble**), ses envies, et son allure : apparences (mascottes et créatures capturées), cadre, fond, ornements.
- **Ménagerie** : toutes les créatures capturables, en une liste numérotée à filtrer (zone, capturées / à capturer / à abattre, rareté, recherche par nom, tris), avec une fiche en 3D.
- **Missions** : missions du compagnon, du jour et de la semaine avec leurs récompenses, la besace de capture, le garde-manger et la carte des auberges.
- **Exploration** (« Complétion » jusqu'à la 1.5.0) : toutes les zones et leur progression ; pour la zone choisie, ses paliers et ce qu'ils rapportent, les lieux, les métiers (la récolte de la zone, ressources grises comprises, et tous les métiers que tu connais) et les quêtes, et le coffre de zone.
- **Souvenirs** : l'album de la route, chaque souvenir avec sa photo recréée par ton compagnon sur un décor peint (prairie, aube, crépuscule, grotte, ville, trésor, orage, au-dessus des nuages), chacune avec son cadrage (gros plan, au loin, de dos, en l'air…) et son geste (les captures d'écran du jeu restent dans le dossier Screenshots : un addon ne peut pas les lire).

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

Le carnet (`/qc`, le bouton de minicarte, ou clic droit sur la créature) s'ouvre sur le dernier onglet utilisé (la première fois, sur **Créature**, le premier onglet). Ses onglets sont rangés sur le côté droit, et ton **garde-manger** (les friandises) est dans l'en-tête : un clic sur une friandise la donne.
- **Créature** : l'étape de ta créature, la prochaine, son caractère, ses envies, comment elle évolue, tes coffres à ouvrir, ta collection et ton parcours (zones, capitales, donjons, rares, paliers). Survole une envie (faim, énergie, moral, curiosité) pour savoir ce qui la remplit.
- **Zones** : une grille de toutes les zones du jeu, celles propres à Forever comprises, celles jamais visitées en gris. Chaque tuile donne sa tranche de niveaux et son pourcentage, et dit si un coffre t'attend. Filtre par continent, trie par niveau ou par pourcentage, clique sur une tuile pour l'ouvrir.
- **Zone** : une zone, avec des flèches vers la précédente et la suivante (le bouton retour de la souris revient à la grille). Son pourcentage, ses paliers (25, 50 et 75 % donnent une friandise, 100 % le coffre) et, par onglet, ce qui est fait et ce qui reste :
  - **Exploration** : les villages de la zone, sur deux colonnes ;
  - **Combat** : une fiche par créature du bestiaire, au liseré de son rang (élite, rare, boss), « ??? » pour celles jamais croisées. Survole une fiche pour voir la créature en 3D à côté de la grille ;
  - **Métiers** : les icônes des ressources de ta compétence, en couleur une fois récoltées ici ;
  - **Quêtes** : les quêtes de la zone que ton personnage peut faire (faction, race, classe), sur deux colonnes, filtrées à faire ou faites. Elles comptent dans les 100 %. Aucun addon requis.
- **Suivre à l'écran** (onglet Zone) : activé, les objectifs de la zone s'affichent dans le bloc « Carnet » en jeu. La zone où tu es est suivie d'office (désactive-la pour la masquer) ; active d'autres zones pour garder un œil sur elles.
- **Jour** : les missions du jour (avec le bouton pour en changer une), la carte de fidélité des auberges et le garde-manger.
- **Collection** : toutes les apparences, ornements, cadres et fonds, ceux verrouillés en gris avec où les trouver. Survole un objet pour le voir, clique pour l'équiper (un ornement : clic pour le porter ou l'enlever).
- **Souvenirs** : l'album.

## Objectifs

Le carnet fixe des **objectifs** : prochaine étape de la créature, prochaine apparence ou ornement, villages de la zone, capitales, donjons de ton niveau, prochain palier. Les plus proches s'affichent à l'écran sous le suivi des quêtes, dans un bloc **Carnet** : l'objectif le plus proche mis en avant avec sa barre, puis trois autres plus discrets.

- **Complétion de zone** : chaque zone a son pourcentage, affiché dans la page **Exploration** du carnet et, pour la zone où tu es, dans le bloc à l'écran. Il mélange à parts égales :
  - les **villages** visités ;
  - le **bestiaire** : les espèces que tu as croisées et abattues (on compte des espèces différentes, pas un nombre de victimes) ;
  - les **nommés** (élites, rares, boss) croisés et abattus ;
  - la **récolte**, si tu es herboriste, mineur ou dépeceur : les herbes et minerais de la zone que ta compétence permet (même gris : un mineur confirmé finit aussi les zones de départ) et les cuirs de ta compétence, déjà récoltés dans la zone.

  Chaque zone arrive **préremplie** (îles et zones propres à Forever comprises) : ses créatures (nom, niveau, rang), les herbes et minerais qui y poussent et ses quêtes sont connus dès ta première visite. Ce qui manque à ces données (nouveautés récentes de Forever) se remplit en jouant.
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
| `/qc capture` | ta ménagerie et tes aides de capture |
| `/qc metiers` | les métiers que le jeu donne à l'addon (pour signaler un bogue) |
| `/qc module compagnon off` | coupe le compagnon et son carnet |
| `/qc minimap [on\|off]` | le bouton de minicarte |
| `/qc reset` | remet les réglages à zéro, sans toucher à ta créature ni à ton carnet |
| `/qc diag` | diagnostic, à joindre si tu signales un problème |

## Données et licence

QuestCompanion est un logiciel libre sous licence **GPL-3.0** (voir `LICENSE`). Les données de zones (créatures, récolte, quêtes) sont générées depuis la base de [Questie](https://github.com/Questie/QuestieDB), elle aussi sous GPL-3.0, par `tools/gen_zone_data.py` : voir `NOTICE.md`.
