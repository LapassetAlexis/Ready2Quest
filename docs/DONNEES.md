# Notre base de données (`data/`)

Les créatures, la récolte et les quêtes de chaque zone (QuestCompanion) et les lieux sûrs (le socle commun : `Hubs.lua`, `Places.lua`) sont générés depuis **notre** base, rangée dans `data/`. Elle est versionnée dans ce dépôt : on la lit, on la corrige et on la complète ici.

Personne ne dépend de Questie :
- **en jeu** : rien n'est lu pendant la partie, tout est déjà dans les fichiers de l'addon ;
- **pour générer** : les générateurs ne lisent que `data/`.

Questie n'a servi qu'à **remplir** la base au départ, avec `tools/import_questie.py`. Les tables du client (zones, cartes) viennent de wago.tools, avec `tools/import_client.py`.

## Contenu

Un dossier par client : `data/forever/` (WoW Forever, seul client pris en charge ; `data/era/` a été retiré avec le support de Classic Era) :

| Fichier | Contenu |
|---|---|
| `npcs.jsonl` | PNJ et créatures : noms (`name`, `name_fr`), niveaux, rang, faction (`factionID`, `friendlyToFaction`), services (`npcFlags`), apparitions par zone (`spawns`), quêtes données et rendues |
| `objects.jsonl` | objets du monde : noms, apparitions, quêtes |
| `quests.jsonl` | quêtes : noms, niveaux, races, classes, donneurs (`startedBy`), suites (`nextQuestInChain`, `exclusiveTo`…), drapeaux `hidden` (cachée) et `event` (événement saisonnier) |
| `zones.json` | `areaToUiMap` : zone de jeu → carte ; `subZoneParent` : sous-zone → zone |
| `source.json` | provenance : commit de QuestieDB, version de Questie, date d'import, corrections appliquées |
| `areas.jsonl` | zones et sous-zones du jeu : nom anglais, zone parente, continent, drapeaux (`0x100` = capitale) — table `AreaTable` du client |
| `maps.json` | étendue de chaque carte de zone en mètres (`width`, `height`) — table `UiMapAssignment` du client |
| `client.json` | provenance des tables du client (build, date) |
| `fixes.json` | **nos corrections**, faites à la main |

Une entité par ligne, triées par identifiant : un `git diff` montre exactement ce qui a changé. Les tables du jeu sont gardées telles quelles (une liste JSON est une table Lua indexée 1, 2, 3…). Les coordonnées des apparitions sont en pourcentage de la carte de la zone : `spawns: { "<areaID>": [[x, y], …] }`.

## Corriger ou compléter

On n'édite pas `npcs.jsonl`, `objects.jsonl` ni `quests.jsonl` à la main : un nouvel import les réécrit. Les corrections vont dans `data/forever/fixes.json`, appliquées par-dessus à chaque génération, jamais écrasées :

```json
{
  "npc": {
    "3":     { "name_fr": "Dévoreur", "maxLevel": 26 },
    "99999": { "name": "Nouveau PNJ de Forever", "npcFlags": 65536, "spawns": { "1519": [[52.1, 60.3]] } }
  },
  "quest": {
    "1234": { "hidden": true },
    "5678": { "requiredRaces": null }
  }
}
```

- Une valeur remplace celle de la base.
- `null` retire le champ.
- Un identifiant inconnu crée l'entité.
- Les clés commençant par `_` sont des commentaires.

Puis on régénère et on vérifie :

```sh
python3 -I tools/gen_zone_data.py                                  # tables de zone de QuestCompanion
python3 -I tools/gen_places.py                                     # lieux repérés (Libs/Socle/Places.lua)
python3 -I tools/gen_hubs.py > Ready2Quest/Libs/Socle/Hubs.lua     # lieux connus par leur sous-zone
python3 -I tools/sync_socle.py                                     # recopie le socle dans QuestCompanion
python3 tests/run_tests.py             # refuse de tourner si un fichier généré ne suit plus data/
```

Les tables de zone de QuestCompanion (`ZoneCreatures_Forever.lua`, `ZoneQuests_Forever.lua`) sont **paresseuses** : une fonction par zone, construite à la première lecture (`ns.LazyZones`, `QuestCompanion/Core.lua`). En Lua, `pairs` n'y voit que les zones déjà lues : on les parcourt avec `ns.ZoneIds(t)` (identifiants) et `ns.ZoneEach(t, fn)` (chaque zone, sans garder celles qui n'étaient pas encore lues).

Un PNJ de service corrigé ou ajouté dans `fixes.json` (par exemple un camp de Forever que Questie ne connaît pas encore) devient un lieu sûr à la prochaine génération de `Places.lua`.

## Reprendre des nouveautés de Questie (facultatif)

Si Questie ajoute du contenu (nouvelles zones ou quêtes de Forever), on peut le reprendre dans notre base. Il faut une copie locale de QuestieDB et de Questie :

```sh
python3 -I tools/import_questie.py /chemin/QuestieDB --questie-src /chemin/Questie
git diff --stat data/                  # relire ce qui change avant de garder
```

L'import réécrit `npcs.jsonl`, `objects.jsonl`, `quests.jsonl`, `zones.json` et `source.json`, jamais `fixes.json`. Import actuel : QuestieDB `c5de61ab`, Questie 12.4.0, le 2026-11-04.

## Reprendre les tables du client (facultatif)

À un nouveau patch, les zones et les cartes peuvent changer :

```sh
python3 -I tools/import_client.py      # télécharge AreaTable et UiMapAssignment sur wago.tools
python3 -I tools/import_client.py --from DOSSIER   # ou depuis des CSV déjà téléchargés
```

Les builds sont dans `tools/import_client.py` (`BUILDS`).

## Licence

La base de Questie est sous GPL-3.0. Ce que nous en avons importé reste sous GPL-3.0, comme nos addons ; la provenance est citée dans `source.json` et dans le `NOTICE.md` des addons qui embarquent ces données.
