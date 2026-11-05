# Ready2Quest

**English** · [Français](#francais)

**The adventurer's departure companion.** Before you leave town, Ready2Quest checks that your bags are ready: something to eat, room for loot, gear in good shape, your buffs, your hearthstone… and tells you at the right moment, not when it's too late.

For **World of Warcraft Forever**. Interface in English and French.

---

## What the addon does

Ready2Quest brings together **six modules** and a bit of **quality of life** (QoL). Each one can be turned on or off with a click.

| | Module | In one sentence |
|---|---|---|
| ◆ | **Departure check** | When you leave a village, a capital or a camp, a readiness score out of 100 and some advice |
| ◆ | **Expedition report** | When you come back, a summary of your trip: XP, gold, loot, deaths, durability loss, quests to turn in |
| ◆ | **Before the dungeon** | At a dungeon entrance, its sheet: recommended level, your quests for that dungeon, your preparation |
| ◆ | **Camp kit** *(Forever)* | Your campfire kit and camp object ready, and the countdown to the camp buffs |
| ◆ | **Gear summary** | When you change an item, a short-lived summary of the stats you gain or lose |
| ◆ | **Portrait stats** | When you hover your portrait, your main stats, picked for your class and spec |
| ✦ | **The right reward** | When you turn in a quest, the reward that helps you most is highlighted |
| ✦ | **Leveling pace** | XP per hour, time to the next level, rested XP you'd earn by logging out |
| ✦ | **Full bags** | Bags full out in the wild: the item that costs you the least to throw away, in one click |
| ✦ | **After death** | Run back to your corpse or use the spirit healer? Both options, with the numbers |
| ✦ | **Merchant** | Automatic selling of grey items and automatic repairs at merchants |

The **road companion** and its **travel journal** are a separate addon, [QuestCompanion](../QuestCompanion/README.md), which works on its own or with Ready2Quest.

---

## Departure check

### When it triggers

On its own, **the moment you leave a safe area**: city, village, hub or camp. If you come back within 6 seconds, nothing happens, so you don't get an alert at every street corner. On a flight, it waits until you've landed. In combat, it waits until combat ends. If you're dead or a ghost, it stays quiet.

- **Score of 85 or more**: a single line in chat, something like "Bag packed, 92/100. Left Goldshire."
- **Lower score**: a line in chat, and a **"!"** (the quest-available icon) that pulses for a few seconds at the top of the screen, in the color of your score: red below 25, orange from 25 to 59, amber from 60 to 84. Click it: the **Before you leave** window opens, with the score, the verdict (*Ready*, *Ready, with reserves*, *Not ready*) and advice on how to fix things. Right-click: you dismiss it. Nothing opens on its own while you're leaving, and no icon shows up mid-combat: it waits until the fight is over.
- The icon stays visible, dimmed, for a minute after pulsing, then goes away. Prefer the old automatic window? Settings, **General**, uncheck "Reports announced by an icon".

You can also run it whenever you want: `/r2q`, or left-click the minimap button. In the window, the small arrow in the header runs the check again, and **Off on an adventure** closes it. Settings are on right-click on the minimap button.

### What it checks

| Check | What is checked |
|---|---|
| Bags | enough free slots for loot |
| Loot to sell | grey items still cluttering your bags |
| Food & drink | something to eat and drink |
| Potions | a stock of potions (off by default) |
| Buffs | the buffs you usually have (Fortitude, Mark of the Wild…) |
| Durability | a piece of gear that's too worn |
| Repairs | enough gold to repair everything |
| Class reagents | your class reagents: ammo (at least 200, 600 from level 10, 1000 from level 30; it warns you if your arrows are in your bags but not equipped; without ammo a hunter has no auto shot, so it weighs more than food, and below half the minimum your score can't go above "Not ready"), soul shards, powders, candles, seeds, ankhs… |
| Spells | new spells to learn at your trainer |
| Hearth | your hearthstone, ready or on cooldown, and where it takes you |
| Crafting | the reagents missing for the recipe you picked |
| Quests | quests ready to turn in before you head out again |
| Rested XP | your rested XP bonus (for information) |

Checks that don't apply aren't shown: a warrior will never see "Class reagents", and repairs stay silent until a merchant has measured the cost. Each check can be tuned or turned off in the options.

Buffs need no setup: the addon remembers the ones that last several minutes on you. It recognizes the different ranks and the group versions (Prayer of Fortitude covers Fortitude) and ignores food and camp buffs.

### Safe areas

A safe area is a place where you can **get ready without risk**: eat, repair, sell, set your hearthstone at the inn.

- **Known right after install**: the capitals, villages and hubs of your faction, plus the neutral towns (Booty Bay, Gadgetzan, Everlook…). On Forever, the new zones such as Zephras Isle are covered too. That's 80 places, in both English and French.
- **Camps too**: about 160 places on Forever are detected by their service NPCs: an innkeeper, a flight master or a banker, or a group of at least three NPCs with a merchant and a repairer or a trainer. This also works for a camp without a subzone of its own: your position is used. A farm or a lone merchant on a road doesn't count.
- **The starting valleys** (Valley of Trials, Northshire, Coldridge, Shadowglen, Camp Narache, Deathknell, with their caves and buildings) count as a single safe area. Until you've left it, and up to level 6, nothing shows up on its own: the check is still available with `/r2q`. Your first real departure is when you leave the first village outside the valley.
- **What doesn't count**: a village of the other faction, a dungeon, a battleground, a mine or a farm.
- **Forever camps**: near a campfire, you're at camp. When you walk away from it, the check fires, just like leaving a village.
- **The rest is learned** as you play: a small camp missing from the list becomes safe as soon as you find an innkeeper, a flight master, a mailbox or a bank there, or both a merchant and a quest giver. You can also add one yourself with `/r2q safe`.

The window always shows **where you left from** ("Left Goldshire · mailbox"). If a place was learned by mistake, you can remove it in the settings, **Safe areas** page.

---

## Expedition report

The natural follow-up to the departure check: **departure → expedition → return**. When you come back to a safe area (village, capital or camp), a **"?"** (the quest-turn-in icon) appears: blue if all is well, orange if you need to repair or restock, red if you died along the way. One click opens the card that sums up your trip:

- the duration, the XP earned and the levels gained;
- the gold earned and spent, and the net;
- notable items picked up (green and better);
- deaths and the wear on your gear;
- quests ready to turn in;
- what to restock before heading out again.

No report for a pointless round trip: less than a minute, with nothing gained or lost (adjustable). You can prefer a line in chat to the window.

## Before the dungeon

When you reach a dungeon entrance, or go inside, a **"!"** announces the sheet for **that** dungeon (red if your level is too low, orange if something is missing in your preparation, blue otherwise); one click opens it. Only once per visit:

- the recommended level, compared to yours;
- the quests for this dungeon that you have in your log;
- a short preparation check: durability, repairs, food & drink, potions, hearthstone.

It covers the 19 classic dungeons and the 9 new Forever dungeons: City of Dalaran, Ruins of Lordaeron, Hall of Thanes, Excavation Site, Krol'dok… On Forever, it will also list the profession recipes that drop in the dungeon, once that data is known.

## Road companion → QuestCompanion

The road companion and its travel journal (zone completion, chests, progression) have become a separate, standalone addon: **QuestCompanion**, with its own `/qc` command, settings and minimap button. See its [README](../QuestCompanion/README.md). When installed alongside Ready2Quest, its companion also reacts to you leaving and coming back to town.

## Camp kit *(Forever)*

Camping on Forever makes the camp a real place to get ready. Ready2Quest helps you make the most of it:

- **before you leave**, two checks are added to the departure check: do you have a **campfire kit**? is your **camp object** (grindstone, tent, chair…) ready, or still on cooldown (one hour, shared)?
- **at camp**, a small countdown to the minute that grants the buffs, then "Camp buffs active";
- **when you leave camp**, a reminder of the time left: "Camp buffs: 42 min left."


## Gear summary

When you equip a new piece, a small frame shows up for a few seconds with what changes: Strength, Agility, Stamina, Intellect, Spirit, armor, damage, DPS, speed, attack power, crit. An arrow shows the direction, and the color tells you whether it's better or worse. Then it fades away on its own.

To see what it looks like and where it shows up without changing gear: settings, **Gear summary** page, **Simulate a change** button. Each click alternates a gain and a loss on your class's main stat.

## Portrait stats

Hover your portrait: a frame shows your main stats, **only the ones that matter for your class and spec** (no Spirit for a warrior). A feral druid sees other stats in bear form.

## Quality of life (QoL)

### The right reward

At the end of a quest, when you have to pick between several items:
- an amber border and the **"For you"** tag mark the one that upgrades your gear the most. The calculation follows the stats that matter for your class and spec, and compares with what you're wearing;
- an item your class can't make good use of (plate for a mage, a shield for a rogue…) is never recommended;
- if nothing is an upgrade, the **"To sell"** tag goes to the reward that sells for the most;
- the tooltip of each choice shows the difference with your current piece.

### Leveling pace

Hover your experience bar, or type `/r2q xp`:
- your **XP per hour**, over the session and over the last half hour;
- the **estimated time** to the next level, in kills or in quests turned in;
- your **rested XP**, and how much you'd earn by logging out here: "Log out at the inn: +15% of a level by tomorrow".

It goes quiet at max level.

### Full bags

Your bags are full out in the wild and some loot won't fit? A small frame suggests **the item that costs you the least to throw away**, meaning the one worth the least per slot.
- It never suggests a quest item, your hearthstone, your class reagents or your last food and drink.
- **[Discard]** destroys it **after confirmation**, always, since it can't be undone. **[Other]** moves on to the next one. **[Always keep]** sets it aside for good.
- `/r2q jeter` gives the suggestion in chat. `/r2q garder` and `/r2q jeter-toujours` manage your lists.

### After death

When you die, then once you've released your spirit:
- **Run**: the distance to your corpse and the estimated time at ghost speed;
- **Spirit healer**: the extra 25% durability lost, converted into gold, and the length of resurrection sickness for your level;
- and a piece of advice: "Run: 180 m, ~21 s" or "Healer: shorter than the sickness".

It doesn't show up in dungeons or battlegrounds, where the rules are different.

### Merchant

When you open a merchant:
- **selling greys**: only grey-quality items that are worth something, with a summary ("7 gray item(s) sold: 1g 23s");
- **repairs**: if the merchant can repair and you have the gold.

Both are on by default and can be turned off in the settings. They work even if the Departure check is turned off.

---

## Settings

`/r2q options`, or right-click the minimap button.

- **General**: turn the addon on, and everything about display (minimap button, window or chat, reports announced by an icon, the score below which a report is announced, placement of the frames and the icon).
- **Modules**: each module has its own switch right in the list on the left, and its own page explaining what it does. The Departure check has sub-pages: Trigger, Safe areas, Bags & food, Gear & character, Buffs & crafting. Gear summary and Portrait stats have no settings, but their page offers "Place the frame" (and "Show now" for the portrait).
- **QoL**: Quality of life, with its sub-pages Merchant, The right reward, Leveling pace, Full bags and After death. A module's sub-pages only show when it's expanded.

## Commands

`/r2q`, `/sd` or `/sacdepart`, your pick. `/r2q help` shows the full help.

| Command | Effect |
|---|---|
| `/r2q` | runs the check now |
| `/r2q options` | opens the settings |
| `/r2q stats` | shows your main stats |
| `/r2q move` | place the frames with the mouse |
| `/r2q safe` · `unsafe` | adds or removes the current village |
| `/r2q safe list` | lists learned places |
| `/r2q modules` | module status |
| `/r2q module depart off` | turns a module off (`depart`, `expedition`, `dungeon`, `camp`, `stuff`, `portrait`…) |
| `/r2q checks` · `check vivres off` | the departure check controls |
| `/r2q xp` | your leveling pace |
| `/r2q jeter` | what to throw away when your bags are full |
| `/r2q diag` | diagnostics, to attach if you report a problem |

---

## Installation

1. Copy the `Ready2Quest` folder into `World of Warcraft/<client>/Interface/AddOns/`.
2. Check the path: `…/Interface/AddOns/Ready2Quest/Ready2Quest.toc`, with only one `Ready2Quest` folder level.
3. Start the game, or type `/reload`. The line "Ready2Quest — fichiers chargés" shows up in chat.

**Did you have the companion with Ready2Quest 1.25 or earlier**? Install [QuestCompanion](../QuestCompanion/README.md) next to it: your creature, your journal and your chests are carried over automatically, for all your characters, on its first login. Without QuestCompanion, they stay in Ready2Quest's saved data, nothing is lost.

**Did you have the old "Ready to Quest" version**?
- Delete the `AddOns/ReadyToQuest` folder.
- To keep your settings, rename `WTF/Account/<account>/SavedVariables/ReadyToQuest.lua` to `Ready2Quest.lua`.

**Client**: WoW Forever (1.60) only. Classic Era is no longer supported since 1.26.1.

---

## FAQ

**Nothing shows up when I leave the village.**
If your score is 85 or more, that's expected: it's a line in chat. Below that, it's no longer a window but a "!" pulsing at the top of the screen: click it. To always get a report, set "Window below score" to 100 in General; to get the automatic window back, uncheck "Reports announced by an icon". Otherwise, type `/r2q diag` in the village: the "safe (signals)" line should say `true`.

**A village isn't recognized.**
Type `/r2q safe` in the village, or let the addon learn it: an innkeeper, a mailbox or a flight master is enough.

**A place is wrongly treated as safe.**
Settings, **Safe areas** page, **Remove** button. Or `/r2q unsafe` on the spot.

**I'm asked for a buff I don't want anymore.**
Settings, **Buffs & crafting** page: click the buff to turn it off, or **Remove**.

**I don't want the addon to sell my greys.**
Settings, **QoL** › **Merchant** › "Sell gray items".

---

## For developers

See the [repository README](../README.md): tests, shared core, publishing.

## License

Ready2Quest is free software under the **GPL-3.0** license (see `LICENSE`): you can use, modify and share it, as long as you keep the same license. The heading font, Alegreya, is under the OFL license (`Libs/Socle/Media/Alegreya-OFL.txt`).

---

<a id="francais"></a>

# Ready2Quest (français)

[English](#ready2quest) · **Français**

**Le compagnon de départ de l'aventurier.** Avant que tu quittes la ville, Ready2Quest vérifie que ton sac est prêt : de quoi manger, de la place pour le butin, un équipement en état, tes buffs, ta pierre de foyer… et te le dit au bon moment, pas quand il est trop tard.

Pour **World of Warcraft Forever**. Interface en français et en anglais.

---

## Ce que fait l'addon

Ready2Quest réunit **six modules** et un peu de **confort** (QoL). Chacun s'active ou se coupe d'un clic.

| | Module | En une phrase |
|---|---|---|
| ◆ | **Check avant le départ** | Quand tu quittes un village, une capitale ou un camp, une note de préparation sur 100 et des conseils |
| ◆ | **Retour d'expédition** | Quand tu rentres, le bilan de ta sortie : XP, or, butin, morts, usure, quêtes à rendre |
| ◆ | **Avant le donjon** | À l'entrée d'un donjon, sa fiche : niveau conseillé, tes quêtes pour ce donjon, ta préparation |
| ◆ | **Kit de camp** *(Forever)* | Ton kit de feu de camp et ton objet de camp prêts, le compte à rebours des buffs au camp |
| ◆ | **Résumé de stuff** | Quand tu changes d'objet, un petit résumé éphémère des stats gagnées ou perdues |
| ◆ | **Stats du portrait** | Au survol de ton portrait, tes stats principales, choisies selon ta classe et ta spécialisation |
| ✦ | **La bonne récompense** | Au rendu d'une quête, la récompense qui te sert le plus est mise en avant |
| ✦ | **Rythme de leveling** | XP par heure, temps avant le prochain niveau, repos à gagner en te déconnectant |
| ✦ | **Sac plein** | Sac plein en pleine nature : l'objet que tu perds le moins à jeter, en un clic |
| ✦ | **Après la mort** | Courir jusqu'au corps ou le guérisseur des esprits ? Les deux options chiffrées |
| ✦ | **Marchand** | Vente automatique des objets gris et réparation automatique chez les marchands |

Le **compagnon de route** et son **carnet de voyage** sont un addon à part, [QuestCompanion](../QuestCompanion/README.md#francais), qui fonctionne seul ou avec Ready2Quest.

---

## Check avant le départ

### Quand il se déclenche

Tout seul, **au moment où tu quittes une zone sûre** : ville, village, hub ou campement. Si tu y reviens dans les 6 secondes, rien ne se passe, pour ne pas t'alerter à chaque coin de rue. En vol, il attend que tu aies atterri. En combat, il attend la fin du combat. Mort ou fantôme, il ne dit rien.

- **Note de 85 ou plus** : une simple ligne dans le chat, du genre « Sac bouclé, 92/100. Parti de Long-guet. »
- **Note plus basse** : une ligne dans le chat, et un **« ! »** (l'icône des quêtes à prendre) qui pulse quelques secondes en haut de l'écran, dans la couleur de ta note : rouge sous 25, orange de 25 à 59, ambre de 60 à 84. Clique dessus : la fenêtre **Avant le départ** s'ouvre, avec la note, le verdict (*Prêt*, *Prêt avec réserves*, *Pas prêt*) et les conseils pour y remédier. Clic droit : tu l'ignores. Rien ne s'ouvre tout seul pendant que tu pars, et pas d'icône en plein combat : elle attend la fin.
- L'icône reste visible, atténuée, une minute après sa pulsation, puis s'en va. Tu préfères l'ancienne fenêtre automatique ? Réglages, **Général**, décoche « Rapports annoncés par une icône ».

Tu peux aussi le lancer quand tu veux : `/r2q`, ou un clic gauche sur le bouton de la minicarte. Dans la fenêtre, la petite flèche du bandeau relance le check, et **Partir à l'aventure** la referme. Les réglages, eux, sont au clic droit sur le bouton de la minicarte.

### Ce qu'il contrôle

| Contrôle | Ce qui est vérifié |
|---|---|
| Sacs | assez d'emplacements libres pour le butin |
| Butin à vendre | des objets gris qui encombrent encore les sacs |
| Vivres | de quoi manger et boire |
| Potions | une réserve de potions (désactivé par défaut) |
| Buffs | les buffs que tu portes d'habitude (Robustesse, Marque du fauve…) |
| Durabilité | une pièce d'équipement trop usée |
| Réparation | assez d'or pour tout réparer |
| Réactifs | les réactifs de ta classe : munitions (au moins 200, 600 dès le niveau 10, 1000 dès le niveau 30 ; il te prévient si tes flèches sont dans ton sac mais pas équipées ; sans munitions, un chasseur n'a plus de tir automatique : elles pèsent plus que les vivres, et sous la moitié du minimum ta note ne peut pas dépasser « Pas prêt »), fragments d'âme, poudres, chandelles, graines, ankh… |
| Sorts | de nouveaux sorts à apprendre chez ton entraîneur |
| Foyer | ta pierre de foyer, disponible ou en recharge, et l'endroit où elle te ramène |
| Métier | les composants qui manquent pour la recette choisie |
| Quêtes | des quêtes prêtes à rendre avant de repartir |
| Repos | ton bonus d'expérience de repos (pour information) |

Les contrôles sans objet ne s'affichent pas : un guerrier ne verra jamais « Réactifs », et la réparation reste muette tant qu'aucun marchand n'a mesuré son coût. Chaque contrôle se règle ou se coupe dans les options.

Les buffs n'ont rien à configurer : l'addon retient ceux qui durent plusieurs minutes sur toi. Il reconnaît les différents rangs et les versions de groupe (Prière de robustesse couvre Robustesse) et ignore les buffs de nourriture et de campement.

### Les zones sûres

Une zone sûre est un endroit où l'on peut **se préparer sans risque** : manger, réparer, vendre, se lier à l'auberge.

- **Connues dès l'installation** : les capitales, les villages et les hubs de ta faction, ainsi que les villes neutres (Booty Bay, Gadgetzan, Everlook…). Sur Forever, c'est aussi le cas des nouvelles zones comme Zephras Isle. Cela fait 80 lieux, en français comme en anglais.
- **Les camps aussi** : environ 160 lieux sur Forever sont repérés par leurs PNJ de service : un aubergiste, un maître de vol ou un banquier, ou un groupe d'au moins trois PNJ avec un marchand et un réparateur ou un entraîneur. Ça compte aussi pour un camp sans sous-zone à lui : on regarde ta position. Une ferme ou un marchand isolé sur une route ne comptent pas.
- **Les vallées de départ** (Vallée des épreuves, Northshire, Coldridge, Sombrevallon, Camp Narache, Deathknell, avec leurs grottes et bâtiments) forment une seule zone sûre. Tant que tu n'en es pas sorti, et jusqu'au niveau 6, rien ne s'affiche tout seul : le check reste disponible avec `/r2q`. Le premier vrai départ, c'est quand tu quittes le premier village hors de la vallée.
- **Ce qui ne compte pas** : un village de l'autre faction, un donjon, un champ de bataille, une mine ou une ferme.
- **Les camps de Forever** : près d'un feu de camp, tu es au campement. Quand tu t'en éloignes, le check part, comme en quittant un village.
- **Le reste s'apprend** en jouant : un petit camp absent de la liste devient sûr dès que tu y trouves un aubergiste, un maître de vol, une boîte aux lettres ou une banque, ou à la fois un marchand et un donneur de quêtes. Tu peux aussi en ajouter un toi-même avec `/r2q safe`.

La fenêtre indique toujours **d'où tu es parti** (« Parti de Comté-de-l'Or · boîte aux lettres »). Si un endroit a été appris à tort, tu le retires dans les réglages, page **Zones sûres**.

---

## Retour d'expédition

La suite naturelle du check avant le départ : **départ → expédition → retour**. Quand tu reviens dans une zone sûre (village, capitale ou camp), un **« ? »** (l'icône des quêtes à rendre) s'affiche : bleu si tout va bien, orange s'il faut réparer ou racheter, rouge si tu es mort en route. Un clic ouvre la carte qui résume ta sortie :

- la durée, l'XP gagnée et les niveaux pris ;
- l'or gagné et dépensé, et le net ;
- les objets notables ramassés (verts et mieux) ;
- les morts et l'usure de ton équipement ;
- les quêtes prêtes à rendre ;
- ce qu'il faut racheter avant de repartir.

Pas de bilan pour un aller-retour sans intérêt : moins d'une minute, sans rien gagné ni perdu (réglable). Tu peux préférer une ligne dans le chat à la fenêtre.

## Avant le donjon

En arrivant à l'entrée d'un donjon, ou en y entrant, un **« ! »** annonce la fiche de **ce** donjon (rouge si tu es trop bas niveau, orange si ta préparation a un manque, bleu sinon) ; un clic l'ouvre. Une seule fois par visite :

- le niveau conseillé, comparé au tien ;
- les quêtes de ce donjon que tu as dans ton journal ;
- une préparation courte : durabilité, réparation, vivres, potions, pierre de foyer.

Elle couvre les 19 donjons classiques et les 9 nouveaux donjons de Forever : City of Dalaran, Ruins of Lordaeron, Hall of Thanes, Excavation Site, Krol'dok… Sur Forever, elle listera aussi les plans de métier qui tombent dans le donjon, dès que ces données seront connues.

## Compagnon de route → QuestCompanion

Le compagnon de route et son carnet de voyage (complétion de zone, coffres, évolution) sont devenus un addon à part, autonome : **QuestCompanion**, avec sa commande `/qc`, ses réglages et son bouton de minicarte. Voir son [README](../QuestCompanion/README.md#francais). Installé avec Ready2Quest, son compagnon réagit en plus à tes départs et retours en ville.

## Kit de camp *(Forever)*

Le camping de Forever en fait un vrai lieu de préparation. Ready2Quest t'aide à en profiter :

- **avant de partir**, deux contrôles s'ajoutent au check : as-tu un **kit de feu de camp** ? ton **objet de camp** (meule, tente, chaise…) est-il prêt, ou encore en recharge (une heure, partagée) ?
- **au camp**, un petit compte à rebours jusqu'à la minute qui donne les buffs, puis « Buffs du camp actifs » ;
- **en quittant le camp**, un rappel du temps restant : « Buffs du camp : encore 42 min ».


## Résumé de stuff

Quand tu équipes une nouvelle pièce, un petit cadre apparaît quelques secondes et montre ce qui change : Force, Agilité, Endurance, Intelligence, Esprit, armure, dégâts, DPS, vitesse, puissance d'attaque, critique. Une flèche indique le sens, la couleur dit si c'est mieux ou moins bien. Puis il s'efface tout seul.

Pour voir à quoi il ressemble et où il apparaît sans changer d'équipement : réglages, page **Résumé de stuff**, bouton **Simuler un changement**. Chaque clic alterne un gain et une perte sur la stat principale de ta classe.

## Stats du portrait

Survole ton portrait : un cadre affiche tes stats principales, **seulement celles qui comptent pour ta classe et ta spécialisation** (pas d'Esprit pour un guerrier). Un druide farouche voit d'autres stats en forme d'ours.

## Confort de jeu (QoL)

### La bonne récompense

À la fin d'une quête, quand tu dois choisir entre plusieurs objets :
- un liseré ambre et l'étiquette **« Pour toi »** désignent celui qui améliore le plus ton équipement. Le calcul suit les stats qui comptent pour ta classe et ta spé, et compare avec ce que tu portes ;
- un objet que ta classe porte mal (plaques pour un mage, bouclier pour un voleur…) n'est jamais conseillé ;
- si rien n'est une amélioration, l'étiquette **« À vendre »** va à la récompense qui se vend le plus cher ;
- l'infobulle de chaque choix indique l'écart avec ta pièce actuelle.

### Rythme de leveling

Survole ta barre d'expérience, ou tape `/r2q xp` :
- ton **XP par heure**, sur la session et sur la dernière demi-heure ;
- le **temps estimé** avant le niveau suivant, en ennemis tués ou en quêtes rendues ;
- ton **repos d'avance**, et combien tu en gagnerais en te déconnectant ici : « Déconnecte-toi à l'auberge : +15 % d'un niveau d'ici demain ».

Il se tait au niveau maximum.

### Sac plein

Ton sac est plein en pleine nature et un butin ne rentre pas ? Un petit cadre te propose **l'objet que tu perds le moins à jeter**, c'est-à-dire celui qui vaut le moins cher par case.
- Il ne propose jamais un objet de quête, ta pierre de foyer, tes réactifs de classe ou tes derniers vivres.
- **[Jeter]** le détruit **après confirmation**, toujours, puisque c'est irréversible. **[Autre]** passe au suivant. **[Garder toujours]** l'écarte pour de bon.
- `/r2q jeter` donne la proposition dans le chat. `/r2q garder` et `/r2q jeter-toujours` gèrent tes listes.

### Après la mort

À ta mort, puis une fois ton esprit libéré :
- **Courir** : la distance jusqu'à ton corps et le temps estimé à la vitesse du fantôme ;
- **Guérisseur des esprits** : les 25 % de durabilité perdus en plus, convertis en or, et la durée du mal de résurrection selon ton niveau ;
- et un conseil : « Cours : 180 m, ~21 s » ou « Guérisseur : moins long que la faiblesse ».

Il ne s'affiche pas en donjon ni en champ de bataille, où les règles sont différentes.

### Marchand

À l'ouverture d'un marchand :
- **vente des gris** : uniquement les objets de qualité grise qui ont une valeur, avec un récapitulatif (« 7 objet(s) gris vendu(s) : 1 po 23 pa ») ;
- **réparation** : si le marchand répare et que tu as l'or nécessaire.

Les deux sont actifs par défaut et se coupent dans les réglages. Ils fonctionnent même si le Check avant le départ est coupé.

---

## Réglages

`/r2q options`, ou un clic droit sur le bouton de la minicarte.

- **Général** : activer l'addon, et tout ce qui touche à l'affichage (bouton de minicarte, fenêtre ou chat, rapports annoncés par une icône, note sous laquelle un rapport s'annonce, placement des cadres et de l'icône).
- **Modules** : chaque module a son interrupteur directement dans la liste de gauche, et sa page qui explique ce qu'il fait. Le Check avant le départ a ses sous-pages : Déclenchement, Zones sûres, Sacs & vivres, Équipement & perso, Buffs & métier. Résumé de stuff et Stats du portrait n'ont pas de réglage, mais leur page propose « Placer le cadre » (et « Afficher maintenant » pour le portrait).
- **QoL** : Confort de jeu, avec ses sous-pages Marchand, La bonne récompense, Rythme de leveling, Sac plein et Après la mort. Les sous-pages d'un module ne s'affichent que quand il est ouvert.

## Commandes

`/r2q`, `/sd` ou `/sacdepart`, au choix. `/r2q help` affiche l'aide complète.

| Commande | Effet |
|---|---|
| `/r2q` | lance le check maintenant |
| `/r2q options` | ouvre les réglages |
| `/r2q stats` | affiche tes stats principales |
| `/r2q move` | place les cadres à la souris |
| `/r2q safe` · `unsafe` | ajoute ou retire le village actuel |
| `/r2q safe list` | liste les lieux appris |
| `/r2q modules` | état des modules |
| `/r2q module depart off` | coupe un module (`depart`, `expedition`, `dungeon`, `camp`, `stuff`, `portrait`…) |
| `/r2q checks` · `check vivres off` | les contrôles du check avant le départ |
| `/r2q xp` | ton rythme de leveling |
| `/r2q jeter` | quoi jeter quand le sac est plein |
| `/r2q diag` | diagnostic, à joindre si tu signales un problème |

---

## Installation

1. Copie le dossier `Ready2Quest` dans `World of Warcraft/<client>/Interface/AddOns/`.
2. Vérifie le chemin : `…/Interface/AddOns/Ready2Quest/Ready2Quest.toc`, avec un seul niveau de dossier `Ready2Quest`.
3. Lance le jeu, ou tape `/reload`. La ligne « Ready2Quest — fichiers chargés » apparaît dans le chat.

**Tu avais le compagnon avec Ready2Quest 1.25 ou avant** ? Installe [QuestCompanion](../QuestCompanion/README.md#francais) à côté : ta créature, ton carnet et tes coffres sont repris automatiquement, pour tous tes personnages, à sa première connexion. Sans QuestCompanion, ils restent dans la sauvegarde de Ready2Quest, rien n'est perdu.

**Tu avais l'ancienne version « Ready to Quest »** ?
- Supprime le dossier `AddOns/ReadyToQuest`.
- Pour garder tes réglages, renomme `WTF/Account/<compte>/SavedVariables/ReadyToQuest.lua` en `Ready2Quest.lua`.

**Client** : WoW Forever (1.60) seulement. Classic Era n'est plus pris en charge depuis la 1.26.1.

---

## Questions fréquentes

**Rien ne s'affiche quand je quitte le village.**
Si ta note est de 85 ou plus, c'est normal : c'est une ligne dans le chat. En dessous, ce n'est plus une fenêtre mais un « ! » qui pulse en haut de l'écran : clique dessus. Pour avoir toujours un rapport, mets « Fenêtre sous la note » à 100 dans Général ; pour retrouver la fenêtre automatique, décoche « Rapports annoncés par une icône ». Sinon, tape `/r2q diag` dans le village : la ligne « zone sûre » doit indiquer `true`.

**Un village n'est pas reconnu.**
Tape `/r2q safe` dans le village, ou laisse l'addon l'apprendre : un aubergiste, une boîte aux lettres ou un maître de vol suffisent.

**Un endroit est considéré comme sûr à tort.**
Réglages, page **Zones sûres**, bouton **Retirer**. Ou `/r2q unsafe` sur place.

**Un buff m'est réclamé alors que je ne le veux plus.**
Réglages, page **Buffs & métier** : clic sur le buff pour le couper, ou **Retirer**.

**Je ne veux pas que l'addon vende mes gris.**
Réglages, **QoL** › **Marchand** › « Vendre les gris ».

---

## Pour les développeurs

Voir le [README du dépôt](../README.md) : tests, socle commun, publication.

## Licence

Ready2Quest est un logiciel libre sous licence **GPL-3.0** (voir `LICENSE`) : tu peux l'utiliser, le modifier et le partager, à condition de garder la même licence. La police des titres, Alegreya, est sous licence OFL (`Libs/Socle/Media/Alegreya-OFL.txt`).
