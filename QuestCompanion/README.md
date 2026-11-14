# QuestCompanion

**English** · [Français](#francais)

**A creature-collecting road companion.** Capture the monsters you defeat, normal and shiny, complete your collection and take the right companion along: each creature helps you hunt. A little creature travels with you, talks to you and grows with you; its journal tracks every zone and your missions.

For **World of Warcraft Forever**. Interface in English and French.

> **Standalone.** QuestCompanion works on its own: its `/qc` command, its settings panel, its minimap button. It pairs nicely with [Ready2Quest](../Ready2Quest/README.md) but doesn't need it: if Ready2Quest is there, the companion also reacts when you leave town and come back.

---

## The collection, at the heart of 2.0

Since 2.0, QuestCompanion is first a **creature-collecting game**: capture what you defeat, complete your collection, take the right companion along.

- **The net**: no more pop-up. When a defeated monster is worth capturing (a missing species, a shiny, or a specimen that could beat yours), a big **net button** shows up beside your companion, with a count, and a **"Capture possible" banner** names the creature, says whether you already own it and with how many stars, your odds, with **Ignore** and **Mute** buttons (click the banner: the net); a chime plays, and a little tune when the capture succeeds (**Capture sounds** setting); it turns gold and sparkles when a shiny is waiting. Whole packs queue up; each one waits **30 s from the end of the fight**. **Click**: captures the best one (shiny, then new species, then rarest, then a star upgrade). **Right-click**: the list (pick one, choose an aid, ignore all). `/qc filet` does the same, and the button stays on screen when the companion is hidden. The list closes by itself once the net is thrown or empty, and has a **×**; **Escape** closes it, and the capture scene too ("Click or Escape to close").
- **Stars**: each capture is a 1 to 3-star specimen (3 stars about one time in ten). Recapture to try for better: the best one is kept.
- **Your companion helps you hunt**: a captured creature you take along gives two effects tied to its **type** — a **hunt** effect and a **comfort** effect:

  | Type | Hunt | Comfort |
  |---|---|---|
  | Beast | a paw on uncaptured Beasts' nameplates, better odds on them | hunger drops slower |
  | Humanoid | better odds on Humanoids | sometimes a treat more at a zone milestone |
  | Undead | better shiny odds on Undead | energy drops slower |
  | Elemental | capture aids sometimes not used up | curiosity drops slower |
  | Dragonkin | the shiny hunt goes faster | mood drops slower |
  | Demon | better odds on elites and rares | more mood from a pat |
  | Giant | sometimes an aid more at a zone milestone | every need drops a little slower |
  | Mechanical | a failed capture sometimes gives the aid back | energy comes back faster at rest |

  The **strength** grows with its rank (elite ×1.5, rare ×2, boss ×2.5), if it's shiny, with its stars and with your type collection. Your **mascots** (the companions you didn't capture) are the companion of the heart: a modest general bonus that grows with their evolution stage. A **happy** companion (all needs at 50% or more) gives its effects in full, never less than half. Switching companion asks for **confirmation** (old and new effects side by side) and the effects kick in after **2 minutes**: you pick a companion for an outing, not for each target. The Companion page shows its effects and the countdown; the monster tooltip shows your odds with the bonus ("to capture · 45% (+15)").
- **Zone seals**: capture every species of a zone (world bosses aside) and it gets a **seal**: a frame, then a background, in the colours of its landscape, and better shiny odds in that zone for good.
- **Type collection and titles**: every 10, 20 and 40 captures of a type (5, 10, 20 for the rarest types) strengthen that type's effect. At 10, 25, 50, 100 and 250 species you earn a **trainer title** (Apprentice trainer … Grand master trainer) and a reward, through their achievement (35 more titles come from other achievements).
- **Trainer card**: your title, your companion in 3D, a **showcase of 3 creatures** you choose, your numbers and your seal badges. Other players who have the addon can open it from the **right-click menu** on you (the entry only shows for players known to have the addon), and you theirs; a "QuestCompanion trainer" line shows in their tooltip. `/qc fiche` opens yours (to pick your showcase), `/qc fiche <name>` asks for someone's. Shared by default, can be turned off (Day by day page): then the addon stays silent.
- **Guided tutorials and Guide page** (3.0.0, replacing the 2.3.0 bubble tutorial): a callout walks you through your first capture (the net, the preparation card, Throw/Skip, Codex or Reserve, hunt mode) and, the first time you open the journal, through each tab, highlighting what it talks about. Once per account, never in combat; "Skip tutorial" or Escape stops it; `/qc tuto [capture|carnet|reset]` and the two buttons of the **Guide** page replay them. The **Guide** page explains everything section by section with the game's own numbers, including the table of the eight types.

## Achievements and titles (2.7)

Forever has no achievement window: QuestCompanion brings its own, with points.

- **174 achievements in 11 categories**: Creatures, Shinies, Zones and seals, Day by day, Guild and friends, Character, Dungeons and raids, Professions, Quests, reputation and honor, Oddities, Feats of feats. They come from your captures and seals, your companion, and from the game itself (levels, gold, mounts, flights, the last boss of each dungeon, raids from Onyxia to Kel'Thuzad, professions, quests, reputation).
- **Account or character**: collection achievements (collection, shinies, guild, oddities, feats of feats) count for all your characters; performance ones (levels, zones, dungeons, professions, quests) belong to each character.
- **Nothing to redo**: what you did before is awarded silently at login (your journal stamps, your milestones, your character statistics). A few achievements whose statistic isn't verified on Forever yet are greyed out "detection coming soon"; `/qc hf diag` shows what your client reads.
- **The Achievements page** of the journal (`/qc hf`): your points, the categories, progress, rewards and dates. An "Achievement earned" banner (golden wings for the big ones), never in combat.
- **40 titles**: "Trainer Dyokrion", "Dyokrion the Tracker"…, masculine or feminine (from your character or your pick). Choose yours on your trainer card or with `/qc title`; it shows on your card with your points, and your big achievements are announced to your guild with your title.

In the Azeroth style (2.8), the travel journal and the trainer card look like the game's achievement frame (wood, parchment, header plate, shields, green bars). The trainer card shows a showcase of 3 achievements. The **Y** key opens your achievements if it was free (Key Bindings menu or Travel journal settings).

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
- **Capture monsters (collection)**: since 1.4.0, every monster you defeat can be **captured**. A net button shows up on your companion (see above): one click, one try. The net shakes once, twice, three times… and it's yours, or it gets away (and your companion teases you about it). Chance depends on rank (normal 50%, elite 25%, rare 15%, rare elite 10%, boss 4%) and level (harder above your level). **Capture aids** come at random from journal stamps, zone milestones and shinies: **Tasty bait** (×1.5), **Braided lasso** (×2.5), **Tamer's whistle** (guaranteed); click one in the window to use it for that try. The capture plays out on screen with its own hand-painted art: the balled net flies in with a spark trail, a rope net drops over the creature, wobbles and tightens with every shake while it struggles, then closes on it in a burst of rays (a ribbon, its stars one by one) or tears and falls if it breaks free; a shiny turns the whole scene golden. A captured species becomes a **companion appearance** (settings and the journal's Companion page) and keeps its **own name** ("Plains Kodo"): the name you gave only goes to your mascot. The monster tooltip tells where you stand: "Creatures: to capture · 50%" (your current odds) or "captured". Every 10 captures, a free whistle. The journal's **Creatures** page works like a creature index: every capturable creature in the game (about 3,500 species for your faction), numbered, "???" until you've met it, your current zone by default with a list to pick any zone (or all), filters (captured, to capture, to defeat, shiny, rarity), a name search and sorting (number, name, level, rarity, capture date). Each name (or "???") shows in its rarity colour, captured ones with a green edge on the left, zones listed alphabetically, with a 3D card; click a captured one to make it your companion. `/qc capture` sums up your collection. Settings: **Day by day** page.
- **Shiny creatures**: the first time you target or hover a monster, it has a 1 in 150 chance of being shiny (three times more for an elite or a rare). Your companion spots it (bubble, "!", sparkles) and puts a **star** above its head if you play solo or lead the group; a sparkling **gold diamond** also sits above its nameplate, solo or in a group, and its tooltip reads "Creatures: SHINY · to capture". Every species can be shiny, and the more of a species you've defeated, the better your odds (up to 1 in 40 after 50). A shiny you've spotted is recognised for good: the Creatures page shows it (outlined gold diamond, **Shiny** filter) even if you never capture it. Each species has **two captures**: the normal one and the shiny one, which becomes a golden-lit companion that sparkles. Every week, one mission is a shiny hunt (defeat or capture one). Defeat it: its bestiary card turns golden, your companion gets a treat (sometimes a Feast). At **5, 15 and 30** shinies, three cosmetics no chest gives: the **Sparkling** frame, the **Stardust** background and a **Shimmering aura**.
- **Day by day**: one loyalty card for every inn, one stamp a day at any innkeeper (+20 energy), a Feast on the 7th stamp, no need for days in a row. And **missions of the day**: on your first zone of the day, your companion offers a **collection** mission there (capture a species you don't have, an elite or a rare, or two creatures of a type found there), an **exploration** mission (gathering, quests, a place never seen, +3%) and one from its character; only feasible ones. You can change a zone mission once a day. Since 1.4.0 there are also **three missions of the week** (capture creatures, capture an elite or a rare, "bring an Undead and capture 2 Undead", complete daily missions, defeat enemies, earn stamps, gather, turn in quests), always with a **shiny hunt** (defeat or capture a shiny), renewed at the weekly reset. Rewards feed both your creature and your collection: each daily mission gives a treat and a Tasty bait, all three a Feast and a Braided lasso; each weekly mission a treat and a Braided lasso, all three a Feast and a Tamer's whistle. Everything is in the journal's **Missions** page (with your inn card, pantry and capture pack) and in the on-screen block. Settings: **Day by day** page.
- **It announces your progress**: each new entry in the journal (a species defeated for the first time, a named mob, a resource gathered for the first time in the zone, a zone quest turned in) gets a short bubble with where the zone part stands ("bestiary 13/24"). And its frame glows softly while it speaks, to catch your eye.

You can rename it with `/qc compagnon nom Nugget`.

## Travel journal

**Six pages** (`/qc`, or right-click your companion; the Memories album was removed in 2.6.0):
- **Companion**: your creature up close (portrait with its frame and background, character, evolution steps, its last line), five numbers (captured, shinies, days together, missions done, **distance travelled together**), its needs, and its look: appearances (mascots and captured creatures), frame, background, ornaments.
- **Creatures**: every capturable creature, as one numbered list to filter (zone, captured / to capture / to defeat, rarity, name search, sorting), with a 3D card.
- **Achievements** (since 2.7.0): your points, the categories and the list with progress, reward and date; All / Earned / In progress filters.
- **Missions**: companion, daily and weekly missions with their rewards, the capture pack, the pantry and the inn card.
- **Exploration** (called Completion until 1.5.0): every zone and its progress; for the chosen zone, its milestones and what they give, places, professions (the gathering of the zone, grey resources included, and every profession you know) and quests, and the zone chest.
- **Guide** (since 2.3.0): the collection explained, section by section (the net, stars, shinies, your companion hunts with you, exploring and sealing zones, trainer titles, missions, trainer card, settings and commands), with a contents list on the left, the mouse wheel to scroll and a **Replay the tutorial** button.

Your travel collection: a **stamp** for every first time.

| Stamp | When |
|---|---|
| Zone | you discover a zone |
| Village | you enter a village or a hub, of your faction or neutral |
| Capital | you visit a capital city, even the other faction's |
| Dungeon | you enter a dungeon |
| Rare | you kill a rare enemy that you engaged yourself, with your pet or your group |
| Milestone | you reach levels 10, 20, 30, 40, 50 and 60 |

Since 2.7.0, stamps are taken silently and give the matching achievements (with their date for the ones you already had). Everything is earned by playing, no random packs.

The journal (`/qc`, the minimap button, or right-click on the creature) opens on the last page you used; your **pantry** (treats) sits in its footer: click a treat to give it.
- **Exploration**: on the left, every zone by level (percentage, "here", a gold bar at 100%; the mouse wheel scrolls it). On the right, the chosen zone: its percentage, level range, the four milestones and what they give (25 and 50%: a treat and a capture aid, 75%: a Feast, 100%: the chest), the chest to open and **Track on screen**. Three cards pick the list below:
  - **Places**: the zone's villages and places, to visit first, then visited;
  - **Professions**: the herbs and ores of the zone for your gathering professions, gathered or not, grey ones included; those that need more skill are listed at the end, greyed out, with the skill they need (not counted). Hover the card: every profession the game knows you have (crafting, cooking, fishing, first aid included);
  - **Quests**: the zone's quests your character can do (faction, race, class), to do first. They count toward the 100%. No addon required.
  
  A bestiary line ("7/95 defeated") sends you to the Creatures page for the details.
- **Track on screen**: when on, the zone's goals show in the in-game "Journal" block. The zone you're in is tracked by default (turn it off to hide it); turn other zones on to keep an eye on them.
- **Creatures**: the name (or "???") in the colour of its rarity; a green edge on the left = the normal version is captured; a gold diamond on the right = its shiny is known (outlined) or captured (filled). Filters: all, captured, to capture, to defeat, **shiny**. The card on the right shows the creature in 3D, its rank, level, zone, capture date and odds; a button flips it between its normal and shiny version, and a click on the row makes the version shown your companion.

## Goals

The journal sets **goals**: the creature's next stage, the next appearance or ornament, the zone's villages, capitals, dungeons for your level, the next milestone. The closest ones show on screen under the quest tracker, in a **Journal** block: the closest goal highlighted with its bar, then three more in a lighter style.

- **Zone completion**: each zone has its percentage, shown in the **Exploration** page of the journal and, for the zone you're in, in the on-screen block. Since 2.0 it only counts exploring (creatures live on the Creatures page, with the zone seal), equally weighted:
  - the **villages and places** you've visited;
  - the zone's **quests** your character can do;
  - **gathering**, if you're an herbalist, miner or skinner: the zone's herbs and ores your skill allows (grey ones too: a seasoned miner also finishes starting zones) and the leathers of your skill, already gathered in the zone.

  Every zone comes **pre-filled** (Forever's own islands and zones included): its creatures (name, level, rank), the herbs and ores that grow there and its quests are known from your first visit. Whatever is missing from this data (recent Forever additions) fills in as you play.
- **Hover a goal** to know what to do: the zone's villages you still have to visit, the missing capitals, the dungeons for your level with their level range, the XP to the next level.
- **Click**: opens the journal. **Right-click**: hides the goal.
- The block collapses with a click on its title, moves by dragging it and hides in combat (configurable in the companion options, Travel journal page).

---

## Installation

1. Copy the `QuestCompanion` folder into `World of Warcraft/<client>/Interface/AddOns/`: `…/Interface/AddOns/QuestCompanion/QuestCompanion.toc`.
2. Start the game, or type `/reload`. The line "QuestCompanion — fichiers chargés" ("files loaded") shows up in the chat.

Light on memory: about 2 MB (zone data is built only when you get there, and only your client's language is kept).

**Did you have the companion with Ready2Quest 1.25 or earlier**? Update Ready2Quest too (1.26.0 or later) and keep it enabled on your first login: your creature, your journal, your chests and their settings are taken over from its saved data, for all your characters, then stored in QuestCompanion's own (`QuestCompanion.lua` in `SavedVariables`). With a Ready2Quest 1.25, which still contains the companion, QuestCompanion stays in the background and asks you to update it.

## Settings

`/qc options`, or right-click the whelp minimap button.
- **General**: enable the addon, the minimap button and its position.
- **Road companion**: the **Size** slider (Small, Medium, Large, Huge: its frame grows, its bubble stays readable), the **Framing** (Portrait, the head like your own portrait; Bust; Full body), the **Chattiness** slider (Silent, Discreet, Calm, Normal, Chatty: the line under the slider says what each step does, and it confirms it itself), appearance, frame and background; the **Ornaments** and **Travel journal** sub-pages (banner, chat, on-screen tracking).

## Commands

`/qc` or `/questcompanion`, your pick. `/qc help` shows the full help.

| Command | Effect |
|---|---|
| `/qc` | opens your travel journal (same as `/qc carnet`) |
| `/qc options` | opens the settings |
| `/qc compagnon` | your companion's mood (`nom <name>` to rename it, `tuto` to replay the tutorial, `anim` to see its animations) |
| `/qc coffre` | opens a pending zone chest |
| `/qc capture` | your collection and capture aids |
| `/qc filet` | captures the best creature waiting in the net |
| `/qc fiche [name]` | your trainer card, or asks for someone's |
| `/qc hf` | your achievements (`/qc hf diag`: the client statistics the addon can read) |
| `/qc title [number\|name\|auto\|none]` | the title on your trainer card (no argument: the list of your titles) |
| `/qc metiers` | the professions the game gives the addon (to report a bug) |
| `/qc module compagnon off` | turns off the companion and its journal |
| `/qc minimap [on\|off]` | the minimap button |
| `/qc reset` | resets the settings, without touching your creature or your journal |
| `/qc diag` | diagnostics, to attach if you report a problem |

## Community

Questions, bugs, ideas: join the [Discord](https://discord.gg/b9mYCUhxRb).

## Data and license

QuestCompanion is free software under the **GPL-3.0** license (see `LICENSE`). The zone data (creatures, gathering, quests) is generated from the [Questie](https://github.com/Questie/QuestieDB) database, also under GPL-3.0, by `tools/gen_zone_data.py`: see `NOTICE.md`.

---

<a id="francais"></a>

# QuestCompanion (français)

[English](#questcompanion) · **Français**

**Un compagnon de route qui collectionne les créatures.** Capture les monstres que tu abats, normaux et brillants, complète ta collection et emmène le bon compagnon : chaque créature t'aide à chasser. Une petite créature voyage avec toi, te parle et grandit avec toi ; son carnet suit chaque zone et tes missions.

Pour **World of Warcraft Forever**. Interface en français et en anglais.

> **Autonome.** QuestCompanion fonctionne seul : sa commande `/qc`, son panneau de réglages, son bouton de minicarte. Il va très bien avec [Ready2Quest](../Ready2Quest/README.md#francais), sans en avoir besoin : si Ready2Quest est là, le compagnon réagit en plus à tes départs et retours en ville.

---

## La collection, au cœur de la 2.0

Depuis la 2.0, QuestCompanion est d'abord un **jeu de collection de créatures** : capture ce que tu abats, complète ta collection, emmène le bon compagnon.

- **Le filet** : plus de fenêtre qui s'ouvre toute seule. Quand un monstre abattu vaut le coup (une espèce qui te manque, une brillante, ou un spécimen qui pourrait battre le tien), un gros **bouton filet** apparaît à côté de ton compagnon, avec un compteur, et un **bandeau « Capture possible »** nomme la créature, dit si tu l'as déjà et avec combien d'étoiles, ta chance, avec des boutons **Ignorer** et **Sourdine** (clic sur le bandeau : le filet) ; un carillon sonne, et une petite musique quand la capture réussit (réglage **Sons de capture**) ; il devient doré et scintille si une brillante attend. Un pack entier se met en file ; chacun attend **30 s à partir de la fin du combat**. **Clic** : la capture du meilleur (brillante, puis espèce nouvelle, puis le plus rare, puis une amélioration d'étoiles). **Clic droit** : la liste (en choisir un, choisir une aide, tout ignorer). `/qc filet` fait la même chose, et le bouton reste à l'écran quand le compagnon est masqué. La liste se ferme d'elle-même quand le filet part ou se vide, et a un **×** ; **Échap** la ferme, ainsi que la scène de capture (« Clic ou Échap pour fermer »).
- **Les étoiles** : chaque capture est un spécimen de 1 à 3 étoiles (3 étoiles environ une fois sur dix). Recapture pour tenter mieux : le meilleur est gardé.
- **Ton compagnon t'aide à chasser** : une créature capturée que tu emmènes donne deux effets liés à son **type**, un de **chasse** et un de **confort** :

  | Type | Chasse | Confort |
  |---|---|---|
  | Bête | une patte sur les barres de nom des Bêtes pas encore capturées, meilleure chance sur elles | la faim baisse moins vite |
  | Humanoïde | meilleure chance sur les Humanoïdes | parfois une friandise de plus aux paliers de zone |
  | Mort-vivant | meilleure chance de brillant sur les Morts-vivants | l'énergie baisse moins vite |
  | Élémentaire | les aides de capture parfois pas consommées | la curiosité baisse moins vite |
  | Draconien | la chasse au brillant va plus vite | le moral baisse moins vite |
  | Démon | meilleure chance sur les élites et les rares | plus de moral à chaque caresse |
  | Géant | parfois une aide de plus aux paliers de zone | toutes les envies baissent un peu moins vite |
  | Mécanique | une capture ratée rend parfois l'aide | l'énergie remonte plus vite au repos |

  La **force** monte avec son rang (élite ×1,5, rare ×2, boss ×2,5), si elle est brillante, avec ses étoiles et avec ta collection du type. Tes **mascottes** (les compagnons que tu n'as pas capturés) sont le compagnon de cœur : un bonus général modeste qui grandit avec leur étape d'évolution. Un compagnon **heureux** (toutes ses envies à 50 % ou plus) donne ses effets en entier, jamais moins de la moitié. Changer de compagnon demande une **confirmation** (anciens et nouveaux effets côte à côte), et les effets arrivent au bout de **2 minutes** : on choisit un compagnon pour une sortie, pas pour chaque cible. La page Compagnon montre ses effets et le compte à rebours ; l'infobulle des monstres montre ta chance avec le bonus (« à capturer · 45 % (+15) »).
- **Les sceaux de zone** : capture toutes les espèces d'une zone (hors boss du monde) et elle reçoit un **sceau** : un cadre, puis un fond, aux couleurs de son paysage, et une meilleure chance de brillant dans cette zone pour toujours.
- **Collection par type et titres** : 10, 20 et 40 captures d'un type (5, 10, 20 pour les types les plus rares) renforcent son effet. À 10, 25, 50, 100 et 250 espèces, tu gagnes un **titre de dresseur** (Apprenti dresseur … Grand maître dresseur) et une récompense, par leur haut fait (35 autres titres viennent d'autres hauts faits).
- **Fiche de dresseur** : ton titre, ton compagnon en 3D, une **vitrine de 3 créatures** que tu choisis, tes chiffres et les badges de tes sceaux. Les autres joueurs qui ont l'addon l'ouvrent depuis le **menu du clic droit** sur toi (l'entrée n'apparaît que pour les joueurs connus comme détenteurs), et toi la leur ; une ligne « Dresseur QuestCompanion » s'affiche dans leur infobulle. `/qc fiche` ouvre la tienne (pour choisir ta vitrine), `/qc fiche <nom>` demande celle de quelqu'un. Partagée par défaut, se coupe (page Au jour le jour) : l'addon reste alors muet.
- **Tutoriels guidés et page Guide** (3.0.0, à la place du tutoriel en bulles de la 2.3.0) : une bulle t'accompagne dans ta première capture (le filet, la carte de préparation, Lancer ou Passer, Codex ou Réserve, le mode chasse) et, à la première ouverture du carnet, dans chaque onglet, en surlignant ce dont elle parle. Une fois par compte, jamais en combat ; « Passer le tutoriel » ou Échap l'arrêtent ; `/qc tuto [capture|carnet|reset]` et les deux boutons de la page **Guide** les rejouent. La page **Guide** explique tout, section par section, avec les chiffres du jeu, dont la table des huit types.

## Hauts faits et titres (2.7)

Forever n'a pas de fenêtre de hauts faits : QuestCompanion apporte la sienne, avec des points.

- **174 hauts faits en 11 catégories** : Créatures, Brillantes, Zones et sceaux, Au jour le jour, Guilde et entraide, Personnage, Donjons et raids, Métiers, Quêtes, réputations et honneur, Insolite, Grands hauts faits. Ils viennent de tes captures et de tes sceaux, de ton compagnon, et du jeu lui-même (niveaux, or, montures, vols, le dernier boss de chaque donjon, les raids d'Onyxia à Kel'Thuzad, métiers, quêtes, réputations).
- **Compte ou personnage** : les hauts faits de collection (créatures, brillantes, guilde, insolite, grands hauts faits) valent pour tous tes personnages ; ceux de performance (niveaux, zones, donjons, métiers, quêtes) sont à chaque personnage.
- **Rien à refaire** : ce que tu as déjà fait est attribué en silence à la connexion (tes tampons du carnet, tes paliers, les statistiques de ton personnage). Quelques hauts faits dont la statistique n'est pas encore vérifiée sur Forever sont grisés « détection bientôt disponible » ; `/qc hf diag` dit ce que ton client sait lire.
- **La page Hauts faits** du carnet (`/qc hf`) : tes points, les catégories, la progression, les récompenses et les dates. Un bandeau « Haut fait obtenu » (des ailes dorées pour les gros), jamais en combat.
- **40 titres** : « Dresseur Dyokrion », « Dyokrion le Traqueur »…, au masculin ou au féminin (selon ton personnage ou à ton choix). Tu choisis le tien sur ta fiche de dresseur ou avec `/qc titre` ; il s'affiche sur ta fiche avec tes points, et tes gros hauts faits sont annoncés à ta guilde avec ton titre.

En style Azeroth (2.8), le carnet de voyage et la fiche de dresseur prennent l'habit du cadre des hauts faits du jeu (bois, parchemin, plaque d'en-tête, boucliers, barres vertes). La fiche montre une vitrine de 3 hauts faits. La touche **Y** ouvre tes hauts faits si elle était libre (menu Raccourcis du jeu ou réglages du Carnet de voyage).

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
- **Capturer les monstres (créatures)** : depuis la 1.4.0, chaque monstre abattu peut être **capturé**. Un bouton filet apparaît sur ton compagnon (voir plus haut) : un clic, un essai. Le filet bouge une fois, deux fois, trois fois… et il est à toi, ou il s'échappe (et ton compagnon se moque). La chance dépend du rang (normal 50 %, élite 25 %, rare 15 %, rare élite 10 %, boss 4 %) et du niveau (plus dur au-dessus du tien). Des **aides de capture** tombent au hasard des tampons du carnet, des paliers de zone et des brillantes : **Appât savoureux** (×1,5), **Lasso tressé** (×2,5), **Sifflet du dompteur** (assurée) ; clique dessus dans la fenêtre pour l'utiliser à cet essai. La capture se joue à l'écran : un filet maillé tombe sur la créature, se resserre à chaque secousse pendant qu'elle se débat, se referme sur elle ou se déchire si elle s'échappe. Une espèce capturée devient une **apparence du compagnon** (réglages et page Compagnon du carnet) et garde **son propre nom** (« Kodo des plaines ») : le nom que tu as donné reste celui de ta mascotte. L'infobulle des monstres dit où tu en es : « Créatures : à capturer · 50 % » (ta chance du moment) ou « capturé ». Toutes les 10 captures, un Sifflet offert. La page **Créatures** du carnet fait office de Pokédex : toutes les créatures capturables du jeu (environ 3 500 espèces pour ta faction), numérotées, « ??? » tant que tu ne les as pas croisées, la zone où tu es par défaut avec une liste pour en choisir une autre (ou toutes), des filtres (capturées, à capturer, à abattre, brillantes, rareté), une recherche par nom et des tris (numéro, nom, niveau, rareté, date de capture). Chaque nom (ou « ??? ») s'affiche à la couleur de sa rareté, les capturées avec un liseré vert à gauche, les zones par ordre alphabétique, avec une fiche en 3D ; un clic sur une capturée en fait ton compagnon. `/qc capture` résume ta collection. Réglages : page **Au jour le jour**.
- **Des créatures brillantes** : la première fois que tu cibles ou survoles un monstre, il a une chance sur 150 d'être brillant (trois fois plus pour un élite ou un rare). Ta créature le repère (bulle, « ! », étincelles) et pose une **étoile** au-dessus de lui si tu joues seul ou mènes le groupe ; un **losange doré** scintille aussi au-dessus de sa barre de nom, seul ou en groupe, et son infobulle dit « Créatures : BRILLANTE · à capturer ». Toutes les espèces peuvent l'être, et plus tu as abattu d'une espèce, plus ta chance monte (jusqu'à une sur 40 après 50). Une brillante repérée est reconnue pour toujours : la page Créatures la montre (losange doré au trait, filtre **Brillantes**), même sans capture. Chaque espèce se capture **deux fois** : la version normale et la version brillante, qui devient un compagnon éclairé d'or et scintillant. Chaque semaine, une mission est une chasse au brillant (en abattre ou en capturer un). Abats-le : sa fiche du bestiaire devient dorée, ta créature reçoit une friandise (parfois un Festin). À **5, 15 et 30** brillantes, trois cosmétiques qu'aucun coffre ne donne : le cadre **Étincelant**, le fond **Poussière d'étoiles** et une **aura scintillante**.
- **Au jour le jour** : une carte de fidélité pour toutes les auberges, un tampon par jour chez n'importe quel aubergiste (+20 d'énergie), un Festin au 7e tampon, sans jours d'affilée. Et des **missions du jour** : à ta première zone de la journée, ta créature t'y propose une mission de **créatures** (capturer une espèce qui te manque, un élite ou un rare, ou deux créatures d'un type présent), une mission d'**exploration** (récolte, quêtes, un lieu jamais vu, +3 %) et une de son caractère ; seulement des faisables. Une mission de zone se change une fois par jour. Depuis la 1.4.0, il y a aussi **trois missions de la semaine** (capturer des créatures, capturer un élite ou un rare, « emmène un Mort-vivant et capture 2 Morts-vivants », enchaîner les missions du jour, abattre, tamponner le carnet, récolter, rendre des quêtes), dont toujours une **chasse au brillant** (en abattre ou en capturer un), renouvelées à la remise à zéro hebdomadaire. Les récompenses nourrissent ta créature ET ta collection : chaque mission du jour donne une friandise et un Appât savoureux, les trois un Festin et un Lasso tressé ; chaque mission de la semaine une friandise et un Lasso tressé, les trois un Festin et un Sifflet du dompteur. Tout est dans la page **Missions** du carnet (avec la carte des auberges, le garde-manger et la besace de capture) et dans le bloc à l'écran. Réglages : page **Au jour le jour**.
- **Elle annonce tes progrès** : chaque nouvelle entrée du carnet (une espèce abattue pour la première fois, un nommé, une ressource récoltée pour la première fois dans la zone, une quête de la zone rendue) a sa courte bulle, avec où en est la partie de la zone (« bestiaire 13/24 »). Et son cadre brille doucement quand elle parle, pour attirer l'œil.

Tu peux la renommer avec `/qc compagnon nom Pépite`.

## Carnet de voyage

**Six pages** (`/qc`, ou clic droit sur ton compagnon ; l'album Souvenirs est retiré depuis la 2.6.0) :
- **Compagnon** : ta créature en grand (portrait avec son cadre et son fond, caractère, étapes d'évolution, sa dernière réplique), cinq chiffres (capturées, brillantes, jours ensemble, missions faites, **distance parcourue ensemble**), ses envies, et son allure : apparences (mascottes et créatures capturées), cadre, fond, ornements.
- **Créatures** : toutes les créatures capturables, en une liste numérotée à filtrer (zone, capturées / à capturer / à abattre, rareté, recherche par nom, tris), avec une fiche en 3D.
- **Hauts faits** (depuis la 2.7.0) : tes points, les catégories et la liste avec progression, récompense et date ; filtres Tous / Obtenus / En cours.
- **Missions** : missions du compagnon, du jour et de la semaine avec leurs récompenses, la besace de capture, le garde-manger et la carte des auberges.
- **Exploration** (« Complétion » jusqu'à la 1.5.0) : toutes les zones et leur progression ; pour la zone choisie, ses paliers et ce qu'ils rapportent, les lieux, les métiers (la récolte de la zone, ressources grises comprises, et tous les métiers que tu connais) et les quêtes, et le coffre de zone.
- **Guide** (depuis la 2.3.0) : la collection expliquée, section par section (le filet, les étoiles, les brillantes, ton compagnon chasse avec toi, explorer et sceller les zones, titres de dresseur, missions, fiche de dresseur, réglages et commandes), avec un sommaire à gauche, la molette pour faire défiler et un bouton **Revoir le tutoriel**.

Ta collection de voyage : un **tampon** pour chaque première fois.

| Tampon | Quand |
|---|---|
| Zone | tu découvres une zone |
| Village | tu entres dans un village ou un hub, de ta faction ou neutre |
| Capitale | tu visites une capitale, même celle de l'autre faction |
| Donjon | tu entres dans un donjon |
| Rare | tu abats un ennemi rare que tu as toi-même engagé, avec ton familier ou ton groupe |
| Palier | tu passes les niveaux 10, 20, 30, 40, 50 et 60 |

Depuis la 2.7.0, les tampons se prennent en silence et donnent les hauts faits qui vont avec (à leur date pour ceux que tu avais déjà). Tout se gagne en jouant, sans paquet aléatoire.

Le carnet (`/qc`, le bouton de minicarte, ou clic droit sur la créature) s'ouvre sur la dernière page utilisée ; ton **garde-manger** (les friandises) est dans son pied : un clic sur une friandise la donne.
- **Exploration** : à gauche, toutes les zones par niveau (pourcentage, « ici », un filet doré à 100 % ; la molette fait défiler). À droite, la zone choisie : son pourcentage, sa tranche de niveaux, les quatre paliers et ce qu'ils rapportent (25 et 50 % : une friandise et une aide de capture, 75 % : un Festin, 100 % : le coffre), le coffre à ouvrir et **Suivre à l'écran**. Trois cartes choisissent la liste du dessous :
  - **Lieux** : les villages et lieux de la zone, à visiter d'abord, puis visités ;
  - **Métiers** : les herbes et minerais de la zone pour tes métiers de récolte, récoltés ou non, gris compris ; ceux qui demandent plus de compétence viennent en fin de liste, grisés, avec la compétence requise (non comptés). Au survol de la carte : tous les métiers que le jeu te connaît (artisanat, cuisine, pêche, secourisme compris) ;
  - **Quêtes** : les quêtes de la zone que ton personnage peut faire (faction, race, classe), à faire d'abord. Elles comptent dans les 100 %. Aucun addon requis.
  
  Une ligne du bestiaire (« 7/95 abattues ») renvoie à la page Créatures pour le détail.
- **Suivre à l'écran** : activé, les objectifs de la zone s'affichent dans le bloc « Carnet » en jeu. La zone où tu es est suivie d'office (désactive-la pour la masquer) ; active d'autres zones pour garder un œil sur elles.
- **Créatures** : le nom (ou « ??? ») à la couleur de sa rareté ; un liseré vert à gauche = la version normale est capturée ; un losange doré à droite = sa brillante est reconnue (au trait) ou capturée (plein). Filtres : toutes, capturées, à capturer, à abattre, **brillantes**. La fiche à droite montre la créature en 3D, son rang, son niveau, sa zone, sa date de capture et ta chance ; un bouton la passe de sa version normale à sa version brillante, et un clic sur la ligne fait de la version montrée ton compagnon.

## Objectifs

Le carnet fixe des **objectifs** : prochaine étape de la créature, prochaine apparence ou ornement, villages de la zone, capitales, donjons de ton niveau, prochain palier. Les plus proches s'affichent à l'écran sous le suivi des quêtes, dans un bloc **Carnet** : l'objectif le plus proche mis en avant avec sa barre, puis trois autres plus discrets.

- **Complétion de zone** : chaque zone a son pourcentage, affiché dans la page **Exploration** du carnet et, pour la zone où tu es, dans le bloc à l'écran. Depuis la 2.0, il ne compte que l'exploration (les créatures vivent dans la page Créatures, avec le sceau de zone), à parts égales :
  - les **villages et lieux** visités ;
  - les **quêtes** de la zone que ton personnage peut faire ;
  - la **récolte**, si tu es herboriste, mineur ou dépeceur : les herbes et minerais de la zone que ta compétence permet (même gris : un mineur confirmé finit aussi les zones de départ) et les cuirs de ta compétence, déjà récoltés dans la zone.

  Chaque zone arrive **préremplie** (îles et zones propres à Forever comprises) : ses créatures (nom, niveau, rang), les herbes et minerais qui y poussent et ses quêtes sont connus dès ta première visite. Ce qui manque à ces données (nouveautés récentes de Forever) se remplit en jouant.
- **Survole un objectif** pour savoir quoi faire : les villages de la zone qu'il te reste à visiter, les capitales manquantes, les donjons de ton niveau avec leur tranche, l'XP avant le prochain niveau.
- **Clic** : ouvre le carnet. **Clic droit** : masque l'objectif.
- Le bloc se replie d'un clic sur son titre, se déplace en le glissant et se cache en combat (réglable dans les options du compagnon, page Carnet).

---

## Installation

1. Copie le dossier `QuestCompanion` dans `World of Warcraft/<client>/Interface/AddOns/` : `…/Interface/AddOns/QuestCompanion/QuestCompanion.toc`.
2. Lance le jeu, ou tape `/reload`. La ligne « QuestCompanion — fichiers chargés » apparaît dans le chat.

Léger en mémoire : environ 2 Mo (les données d'une zone ne sont construites qu'en y arrivant, et seule la langue de ton client est gardée).

**Tu avais le compagnon avec Ready2Quest 1.25 ou avant** ? Mets aussi Ready2Quest à jour (1.26.0 ou plus) et garde-le activé à la première connexion : ta créature, ton carnet, tes coffres et leurs réglages sont repris de sa sauvegarde, pour tous tes personnages, puis rangés dans celle de QuestCompanion (`QuestCompanion.lua` dans `SavedVariables`). Avec un Ready2Quest 1.25, qui contient encore le compagnon, QuestCompanion reste en retrait et te demande de le mettre à jour.

## Réglages

`/qc options`, ou un clic droit sur le bouton de minicarte à l'empreinte.
- **Général** : activer l'addon, le bouton de minicarte et sa position.
- **Compagnon de route** : la réglette **Taille** (Petit, Moyen, Grand, Très grand : son cadre grandit, sa bulle reste lisible), le **Cadrage** (Portrait, la tête comme ton portrait ; Buste ; En pied), la réglette **Bavardage** (Muet, Discret, Calme, Normal, Bavard : la phrase sous la réglette dit ce que fait chaque cran, et il te le confirme lui-même), apparence, cadre et fond ; les sous-pages **Ornements** et **Carnet** (bandeau, chat, suivi à l'écran).

## Commandes

`/qc` ou `/questcompanion`, au choix. `/qc help` affiche l'aide complète.

| Commande | Effet |
|---|---|
| `/qc` | ouvre ton carnet de voyage (comme `/qc carnet`) |
| `/qc options` | ouvre les réglages |
| `/qc compagnon` | l'humeur de ton compagnon (`nom <nom>` pour le renommer, `tuto` pour revoir le tutoriel, `anim` pour voir ses animations) |
| `/qc coffre` | ouvre un coffre de zone en attente |
| `/qc capture` | ta collection et tes aides de capture |
| `/qc filet` | capture la meilleure créature qui attend dans le filet |
| `/qc fiche [nom]` | ta fiche de dresseur, ou demande celle de quelqu'un |
| `/qc hf` | tes hauts faits (`/qc hf diag` : les statistiques du client que l'addon sait lire) |
| `/qc titre [numéro\|nom\|auto\|aucun]` | le titre de ta fiche de dresseur (sans argument : la liste de tes titres) |
| `/qc metiers` | les métiers que le jeu donne à l'addon (pour signaler un bogue) |
| `/qc module compagnon off` | coupe le compagnon et son carnet |
| `/qc minimap [on\|off]` | le bouton de minicarte |
| `/qc reset` | remet les réglages à zéro, sans toucher à ta créature ni à ton carnet |
| `/qc diag` | diagnostic, à joindre si tu signales un problème |

## Communauté

Questions, bugs, idées : rejoins le [Discord](https://discord.gg/b9mYCUhxRb).

## Données et licence

QuestCompanion est un logiciel libre sous licence **GPL-3.0** (voir `LICENSE`). Les données de zones (créatures, récolte, quêtes) sont générées depuis la base de [Questie](https://github.com/Questie/QuestieDB), elle aussi sous GPL-3.0, par `tools/gen_zone_data.py` : voir `NOTICE.md`.
