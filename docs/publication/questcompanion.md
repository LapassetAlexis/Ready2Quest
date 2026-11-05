<!--
Fiche de la page QuestCompanion sur CurseForge et Wago (à copier à la main, voir docs/PUBLIER.md).
Summary EN (256 caractères max, ici 248) :
  A little creature travels with you: it talks, eats, sleeps, grows and develops a personality from how you play. Its travel journal tracks zone completion, opens cosmetic chests and evolves it. Keeps memories and photos. For WoW Forever.
Summary FR (256 caractères max) :
  Une petite créature voyage avec toi : elle parle, mange, dort, grandit et se forge un caractère selon ta façon de jouer. Son carnet suit la complétion des zones, ouvre des coffres cosmétiques et la fait évoluer. Souvenirs et photos. Pour WoW Forever.
Catégories : Companions (principale), Quests & Leveling (additionnelle). Si Companions n'existe pas : Miscellaneous (principale).
Licence : GPLv3. Logo : docs/publication/logo_questcompanion.png.
Relation : Optional Dependency -> Ready2Quest (facultatif).
Captures à prendre en jeu : le compagnon et une bulle, le bloc « Carnet » à l'écran, le carnet partie Complétion (onglet Combat ou Quêtes), le carnet partie Évolution, le coffre de zone ouvert, l'album Souvenirs.
Deux descriptions complètes ci-dessous : anglais, puis français. Coller celle de la langue voulue.
-->
# QuestCompanion

**A little travel companion, and a journal to complete every zone.** A small creature travels with you, talks to you and grows with you. Its journal tracks how complete each zone is and rewards a 100% zone with a chest of cosmetic items.

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
- **It has a personality**: after three hours watching you play, it becomes **Curious**, **Glutton**, **Daring**, **Lazy**, **Teasing** or **Cuddly**, depending on what you do most. The owl, macaw, wisp, turtle, snake and faerie dragon each have their own (Wise, Parrot, Mystic, Zen, Sly, Mischievous). Its personality changes what it says, the need it cares about, what it notices and how it moves.
- **It keeps memories**: the big moments of the road (levels, evolutions, dungeons, capitals, rares, completed zones, first flight, first mount, first full group, even your silliest death) go into an album. If you agree (it asks once), it takes a **photo** of some of them: an in-game screenshot, never in combat, three a day at most. It celebrates your anniversaries and sometimes remembers out loud.
- **Cosmetics**: appearances (whelps, frog, kittens, rabbit, turtle, macaw, snake, owl, wisp, faerie dragon), ornaments, frames and backgrounds.

## The journal

- **Stamps** for every first: zone, village, capital, dungeon, rare foe, level milestone.
- **Zone completion**: pick a zone (your current one by default) and see its percentage, by activity:
  - **Exploration**: the villages of the zone.
  - **Combat**: the bestiary and the named foes.
  - **Professions**: the herbs, ores and leathers of your skill.
  - **Quests**: the quests of the zone your character can do.
- **Prefilled zones**: creatures, gathering nodes and quests of every zone are known from your first visit (Forever islands and zones included). No other addon needed.
- **Zone chests**: complete a zone to 100% and open a chest, then **choose** one cosmetic item of its tier (zones 1-19, 20-39, 40-60). The higher the zone, the finer the item.
- **Evolution**: your creature's stage, its needs, your chests, your collection and your journey.
- **Memories**: the album of your adventure, with its photos.
- **On-screen tracker**: your closest goals under the quest tracker. Hover a goal to see what to do, click to open the journal, right-click to hide it. Choose which zones to follow.

## Commands

`/qc` opens the journal (so does the minimap button, or a right-click on the companion), `/qc options` opens the settings, `/qc compagnon` shows your companion's mood (`/qc compagnon nom <name>` renames it, `/qc compagnon anim` plays its animations), `/qc coffre` opens a pending chest, `/qc help` lists everything.

## Coming from Ready2Quest 1.25 or earlier?

Update Ready2Quest to 1.26.0 and keep it enabled on first login: your companion, journal, chests and their settings are taken over automatically, for all your characters.

## License and data

Free software, **GPL-3.0**. Zone data (creatures, gathering, quests) is generated from the [Questie](https://github.com/Questie/QuestieDB) database, also GPL-3.0. Source code: https://github.com/LapassetAlexis/Ready2Quest

---

# QuestCompanion (français)

**Un compagnon de route et son carnet pour compléter chaque zone.** Une petite créature voyage avec toi, te parle et grandit avec toi. Son carnet suit la complétion de chaque zone et récompense une zone à 100 % par un coffre d'objets cosmétiques.

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
- **Elle a du caractère** : après trois heures à te regarder jouer, elle devient **Curieuse**, **Gourmande**, **Téméraire**, **Paresseuse**, **Taquine** ou **Câline**, selon ce que tu fais le plus. La chouette, l'ara, le feu follet, la tortue, le serpent et le dragon féerique ont chacun le leur (Sage, Perroquet, Mystique, Zen, Rusé, Espiègle). Son caractère change ses phrases, l'envie qu'elle préfère, ce qu'elle remarque et sa façon de bouger.
- **Elle garde des souvenirs** : les grands moments de la route (niveaux, évolutions, donjons, capitales, rares, zones terminées, premier vol, première monture, premier groupe complet, et même ta mort la plus bête) vont dans un album. Si tu es d'accord (elle le demande une fois), elle prend une **photo** de quelques-uns : une capture d'écran du jeu, jamais en combat, trois par jour au plus. Elle fête vos anniversaires et se souvient parfois à voix haute.
- **Cosmétiques** : apparences (dragonnets, rainette, chatons, lapin, tortue, ara, serpent, chouette, feu follet, dragon féerique), ornements, cadres et fonds.

## Le carnet

- **Des tampons** pour chaque première fois : zone, village, capitale, donjon, ennemi rare, palier de niveau.
- **Complétion de zone** : choisis une zone (celle où tu es, par défaut) et vois son pourcentage, par activité :
  - **Exploration** : les villages de la zone.
  - **Combat** : le bestiaire et les nommés.
  - **Métiers** : les herbes, minerais et cuirs de ta compétence.
  - **Quêtes** : les quêtes de la zone que ton personnage peut faire.
- **Zones préremplies** : créatures, points de récolte et quêtes de chaque zone sont connus dès ta première visite (îles et zones propres à Forever comprises). Aucun autre addon requis.
- **Coffres de zone** : une zone à 100 % ouvre un coffre, et tu **choisis** un objet cosmétique de son palier (zones 1-19, 20-39, 40-60). Plus la zone est haute, plus l'objet est beau.
- **Évolution** : l'étape de ta créature, ses envies, tes coffres, ta collection et ton parcours.
- **Souvenirs** : l'album de ton aventure, avec ses photos.
- **Suivi à l'écran** : tes objectifs les plus proches sous le suivi des quêtes. Survole un objectif pour savoir quoi faire, clic pour ouvrir le carnet, clic droit pour le masquer. Choisis les zones à suivre.

## Commandes

`/qc` ouvre le carnet (comme le bouton de minicarte ou un clic droit sur le compagnon), `/qc options` ouvre les réglages, `/qc compagnon` montre son humeur (`/qc compagnon nom <nom>` pour le renommer, `/qc compagnon anim` pour voir ses animations), `/qc coffre` ouvre un coffre en attente, `/qc help` liste tout.

## Tu viens de Ready2Quest 1.25 ou avant ?

Mets Ready2Quest à jour (1.26.0) et garde-le activé à la première connexion : ton compagnon, ton carnet, tes coffres et leurs réglages sont repris automatiquement, pour tous tes personnages.

## Licence et données

Logiciel libre, **GPL-3.0**. Les données de zones (créatures, récolte, quêtes) sont générées depuis la base de [Questie](https://github.com/Questie/QuestieDB), elle aussi sous GPL-3.0. Code source : https://github.com/LapassetAlexis/Ready2Quest
