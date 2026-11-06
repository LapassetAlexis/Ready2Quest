<!--
Fiche de la page Ready2Quest sur CurseForge et Wago (à copier à la main, voir docs/PUBLIER.md).
Summary EN (256 caractères max, ici 218) :
  Leave town ready: a readiness score before each outing (food, bag space, durability, buffs, hearthstone), trip reports when you return, dungeon briefs, campfire kit tracking and gear stat diffs. For WoW Forever. EN/FR.
Summary FR (256 caractères max, ici 240) :
  Pars prêt : une note de préparation avant chaque sortie (vivres, place dans les sacs, durabilité, buffs, pierre de foyer), le bilan au retour, la fiche du donjon, le kit de camp et le résumé de stuff. Pour WoW Forever. FR/EN.
Catégories : Quests & Leveling (principale), Bags & Inventory (additionnelle).
Licence : GPLv3. Logo : docs/publication/logo_ready2quest.png.
Captures à prendre en jeu : la fenêtre « Avant le départ », le bilan de retour, la fiche de donjon, l'étiquette « Pour toi » d'une récompense de quête, le cadre « Sac plein ».
Deux descriptions complètes ci-dessous : anglais, puis français. Coller celle de la langue voulue.
-->
# Ready2Quest

**Get ready before you leave town.** When you step out of a village, a capital or a camp, Ready2Quest checks that you are ready: food and water, room in your bags, gear in good shape, your usual buffs, your hearthstone… and tells you at the right moment, not when it is too late.

For **WoW Forever** (1.60). English and French.

## Modules

Each one can be switched on or off in one click (`/r2q options`).

- **Pre-departure check**: when you leave a safe place, a readiness score out of 100 with tips. It checks bags, greys, food and water, potions, buffs, durability, repair gold, class reagents, spells to learn, hearthstone, profession, quests to turn in and rest. If the score is high, it's a single chat line. If it's low, a "!" icon pulses in the color of your score: click it to open the report. Nothing opens by itself.
- **Safe places, out of the box**: 80 capitals, villages and hubs, plus neutral towns and Forever's new zones. Small camps are learned as you play (innkeeper, flight master, mailbox…). On Forever, your campfire counts too.
- **Expedition report**: back in town, a summary of your trip: duration, XP and levels, gold earned and spent, notable loot, deaths, wear, quests ready, what to restock.
- **Before the dungeon**: at the entrance, a sheet for *that* dungeon, with suggested level, your quests for it and a short prep. It covers the 19 classic dungeons and 9 new Forever dungeons.
- **Camp kit** *(Forever)*: your campfire kit and camp item ready, and a countdown for camp buffs.
- **Gear summary**: a short toast with the stats you gained or lost when you swap an item.
- **Portrait stats**: hover your portrait to see your main stats, picked for your class and spec.
- **Aggro range**: hold Shift out of combat and each hostile nameplate gets a small diamond (or a line, or a ring): red inside its estimated aggro radius, amber close, green safe; its tooltip gives the radius, your distance and the verdict.

## Quality of life

- **Best quest reward**: the reward that helps you most is highlighted ("For you"). If none is an upgrade, the one that sells best gets the "To sell" tag.
- **Leveling pace**: XP per hour, time to next level, rested XP you would gain by logging out here (`/r2q xp`).
- **Full bags**: out in the wild with full bags? It suggests the item you lose least by dropping, and always asks before destroying anything.
- **Room for loot**: loot that won't fit in your full bags? It offers your cheapest items (vendor and auction price), drops the one you pick and picks the loot up for you; anything better than white asks first.
- **Spell ranks**: after training, it tells you which action bar buttons still use an old rank of a spell and swaps them in one click, out of combat.
- **After death**: run back or use the spirit healer? Both options with the numbers.
- **Merchant**: auto-sell greys and auto-repair (both can be turned off).

## Companion

The **travel companion** and its **journal** are a separate, standalone addon: **QuestCompanion** (`/qc`). Installed together, the companion also reacts to your departures and returns.

## Commands

`/r2q` runs the check, `/r2q options` opens the settings, `/r2q help` lists everything, `/r2q diag` prints a diagnostic to attach to a bug report.

## License

Free software, **GPL-3.0**. Source code: https://github.com/LapassetAlexis/Ready2Quest

---

# Ready2Quest (français)

**Prépare ta sortie avant de quitter la ville.** Quand tu quittes un village, une capitale ou un camp, Ready2Quest vérifie que tu es prêt : vivres, place dans les sacs, équipement en état, tes buffs habituels, ta pierre de foyer… et te le dit au bon moment, pas quand il est trop tard.

Pour **WoW Forever** (1.60). En français et en anglais.

## Modules

Chacun s'active ou se coupe d'un clic (`/r2q options`).

- **Check avant le départ** : quand tu quittes un lieu sûr, une note de préparation sur 100 et des conseils. Il contrôle les sacs, les gris, les vivres, les potions, les buffs, la durabilité, l'or de réparation, les réactifs de classe, les sorts à apprendre, la pierre de foyer, le métier, les quêtes à rendre et le repos. Note haute : une seule ligne dans le chat. Note basse : une icône « ! » clignote à la couleur de ta note, clique dessus pour ouvrir le rapport. Rien ne s'ouvre tout seul.
- **Lieux sûrs connus dès l'installation** : 80 capitales, villages et hubs, plus les villes neutres et les nouvelles zones de Forever. Les petits camps s'apprennent en jouant (aubergiste, maître de vol, boîte aux lettres…). Sur Forever, ton feu de camp compte aussi.
- **Retour d'expédition** : de retour en ville, le bilan de ta sortie : durée, XP et niveaux, or gagné et dépensé, butin notable, morts, usure, quêtes prêtes, quoi racheter.
- **Avant le donjon** : à l'entrée, la fiche de *ce* donjon, avec le niveau conseillé, tes quêtes pour lui et une préparation courte. Les 19 donjons classiques et les 9 nouveaux donjons de Forever.
- **Kit de camp** *(Forever)* : ton kit de feu de camp et ton objet de camp prêts, et le compte à rebours des buffs au camp.
- **Résumé de stuff** : un petit résumé éphémère des stats gagnées ou perdues quand tu changes d'objet.
- **Stats du portrait** : survole ton portrait pour voir tes stats principales, choisies selon ta classe et ta spécialisation.
- **Portée d'aggro** : maintiens Maj hors combat et chaque barre de nom hostile reçoit un petit losange (ou un trait, ou un anneau) : rouge dans son rayon d'aggro estimé, ambre tout près, vert tranquille ; son infobulle donne le rayon, ta distance et le verdict.

## Confort

- **La bonne récompense de quête** : celle qui t'aide le plus est mise en avant (« Pour toi »). Si aucune n'est une amélioration, celle qui se vend le mieux porte l'étiquette « À vendre ».
- **Rythme de leveling** : XP par heure, temps avant le prochain niveau, XP de repos gagnée si tu te déconnectes ici (`/r2q xp`).
- **Sac plein** : en pleine nature avec les sacs pleins ? Il te propose l'objet que tu perds le moins à jeter, et demande toujours avant de détruire quoi que ce soit.
- **Place au butin** : un butin qui ne rentre pas dans tes sacs pleins ? Il te propose tes objets les moins chers (prix marchand et hôtel des ventes), jette celui que tu choisis et ramasse le butin à ta place ; au-delà du blanc, il demande d'abord.
- **Rangs de sorts** : après l'entraîneur, il te dit quels boutons de tes barres utilisent encore un ancien rang d'un sort et les remplace d'un clic, hors combat.
- **Après la mort** : courir jusqu'au corps ou passer par le gardien des âmes ? Les deux choix, avec les chiffres.
- **Marchand** : vente automatique des gris et réparation automatique (les deux se coupent).

## Compagnon

Le **compagnon de route** et son **carnet de voyage** sont un addon à part et autonome : **QuestCompanion** (`/qc`). Installés ensemble, le compagnon réagit en plus à tes départs et retours en ville.

## Commandes

`/r2q` lance le check, `/r2q options` ouvre les réglages, `/r2q help` liste tout, `/r2q diag` affiche un diagnostic à joindre à un signalement de bug.

## Licence

Logiciel libre, **GPL-3.0**. Code source : https://github.com/LapassetAlexis/Ready2Quest
