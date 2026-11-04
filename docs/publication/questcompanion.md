<!--
Fiche de la page QuestCompanion sur CurseForge et Wago (à copier à la main, voir docs/PUBLIER.md).
Summary (anglais, 256 caractères max, ici 248) :
  A little creature travels with you: it talks, eats, sleeps, grows and develops a personality from how you play. Its travel journal tracks zone completion, opens cosmetic chests and evolves it. Keeps memories and photos. WoW Forever and Classic Era.
Catégories : Companions (principale), Quests & Leveling (additionnelle). Si Companions n'existe pas : Miscellaneous (principale).
Licence : GPLv3. Logo : docs/publication/logo_questcompanion.png.
Relation : Optional Dependency -> Ready2Quest (facultatif).
Captures à prendre en jeu : le compagnon et une bulle, le bloc « Carnet » à l'écran, le carnet partie Complétion (onglet Combat ou Quêtes), le carnet partie Évolution, le coffre de zone ouvert.
La description commence sous cette ligne.
-->
# QuestCompanion

**A little travel companion, and a journal to complete every zone.** A small creature travels with you, talks to you and grows with you. Its journal tracks how complete each zone is and rewards a 100% zone with a chest of cosmetic items.

For **WoW Forever** (1.60) and **Classic Era** (1.15). English and French.

**Standalone.** Its own `/qc` command, settings and minimap button. It also pairs well with [Ready2Quest](https://github.com/LapassetAlexis/Ready2Quest): installed together, the companion reacts to your departures and returns.

## The companion

- **It talks**: short bubbles, never in combat, when you kill, eat, rest, talk to an NPC, discover a zone, sit by a campfire… plus tips and small conversations.
- **Four needs**: hunger, energy, mood and curiosity. They fill up as you eat, rest, turn in quests and explore. Click it for a pat. Right-click it to open its journal.
- **It grows with you**: Newborn, Young (level 10), Seasoned (20), Valiant (40), Legendary (60). Your level opens the next stage, but it only evolves when it is **happy**, with all four needs at 70% or more.
- **It never punishes you**: it doesn't die, regress or get sick. After a long break, it's just a bit sleepy.
- **Cosmetics**: appearances (whelps, frog, kittens, rabbit, turtle, macaw, snake, owl, wisp, faerie dragon), ornaments, frames and backgrounds.

## The journal

- **Stamps** for every first: zone, village, capital, dungeon, rare foe, level milestone.
- **Zone completion**: pick a zone (your current one by default) and see its percentage, by activity:
  - **Exploration**: the villages of the zone.
  - **Combat**: the bestiary and the named foes.
  - **Professions**: the herbs, ores and leathers of your skill.
  - **Quests**: the quests of the zone your character can do.
- **Prefilled zones**: creatures, gathering nodes and quests of every zone are known from your first visit, on Era and on Forever (Forever islands and zones included). No other addon needed.
- **Zone chests**: complete a zone to 100% and open a chest, then **choose** one cosmetic item of its tier (zones 1-19, 20-39, 40-60). The higher the zone, the finer the item.
- **On-screen tracker**: your closest goals under the quest tracker. Hover a goal to see what to do, click to open the journal, right-click to hide it. Choose which zones to follow.

## Commands

`/qc` opens the journal (so does the minimap button, or a right-click on the companion), `/qc options` opens the settings, `/qc compagnon` shows your companion's mood (`/qc compagnon nom <name>` renames it), `/qc coffre` opens a pending chest, `/qc help` lists everything.

## Coming from Ready2Quest 1.25 or earlier?

Update Ready2Quest to 1.26.0 and keep it enabled on first login: your companion, journal, chests and their settings are taken over automatically, for all your characters.

## License and data

Free software, **GPL-3.0**. Zone data (creatures, gathering, quests) is generated from the [Questie](https://github.com/Questie/QuestieDB) database, also GPL-3.0. Source code: https://github.com/LapassetAlexis/Ready2Quest

---

# QuestCompanion (français)

**Un compagnon de route et son carnet pour compléter chaque zone.** Une petite créature voyage avec toi, te parle et grandit avec toi. Son carnet suit la complétion de chaque zone et récompense une zone à 100 % par un coffre d'objets cosmétiques.

Pour **WoW Forever** (1.60) et **Classic Era** (1.15). En français et en anglais. **Autonome** : `/qc`, ses réglages et son bouton de minicarte. Avec Ready2Quest, le compagnon réagit en plus à tes départs et retours en ville.

- **Elle te parle** : de courtes bulles, jamais en combat, avec des astuces et de petites conversations.
- **Quatre envies** : faim, énergie, moral et curiosité. Clic pour une caresse, clic droit pour le carnet.
- **Elle grandit avec toi** : niveaux 10, 20, 40 et 60, mais elle n'évolue que si elle est **heureuse**, avec ses quatre envies à 70 % ou plus. Elle ne meurt jamais et ne régresse pas.
- **Carnet de voyage** : des tampons pour chaque première fois, et la **complétion de chaque zone** par activité : exploration, combat, métiers, quêtes. Les zones sont **préremplies**, sur Era comme sur Forever.
- **Coffres de zone** : une zone à 100 % ouvre un coffre, et tu **choisis** un objet de son palier : apparence, ornement, cadre ou fond.
- **Suivi à l'écran** : tes objectifs les plus proches. Survole-les pour savoir quoi faire.

Tu avais le compagnon avec Ready2Quest 1.25 ? Mets Ready2Quest à jour (1.26.0) et garde-le activé à la première connexion : tout est repris, pour tous tes personnages.

Logiciel libre, **GPL-3.0**. Données de zones issues de la base de Questie (GPL-3.0).
