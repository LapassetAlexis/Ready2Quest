# Ready2Quest et QuestCompanion

Deux addons pour **World of Warcraft Forever**, en français et en anglais. Ils fonctionnent chacun seul, et vont bien ensemble.

| Addon | Ce qu'il fait | Commande |
|---|---|---|
| [**Ready2Quest**](Ready2Quest/README.md) | Prépare ta sortie : check avant de quitter la ville, bilan au retour, fiche de donjon, kit de camp, portée d'aggro, et du confort de jeu (bonne récompense, rythme de leveling, sac plein, place au butin, rangs de sorts, après la mort, marchand). | `/r2q` |
| [**QuestCompanion**](QuestCompanion/README.md) | Un compagnon de route qui collectionne les créatures : capture les monstres (normaux, brillants, étoilés), emmène celui qui t'aide à chasser, scelle les zones, gagne des titres et montre ta fiche de dresseur ; et son carnet de voyage : exploration, missions, coffres cosmétiques. | `/qc` |

Ensemble, le compagnon réagit en plus à tes départs et retours en ville.

## Communauté

Questions, bugs, idées : rejoins le [Discord](https://discord.gg/b9mYCUhxRb) (section « Addons WoW Forever »). Les addons sont aussi sur [CurseForge](https://www.curseforge.com/wow/addons/quest-companion) et [Wago](https://addons.wago.io/addons/quest-companion).

## Installation

Copie le dossier de chaque addon voulu dans `World of Warcraft/<client>/Interface/AddOns/` : `…/AddOns/Ready2Quest/Ready2Quest.toc`, `…/AddOns/QuestCompanion/QuestCompanion.toc`. Le dépôt est rangé comme le dossier `AddOns`.

## Le dépôt

| Dossier | Contenu |
|---|---|
| `Ready2Quest/` | l'addon Ready2Quest, tel qu'il est publié |
| `QuestCompanion/` | l'addon QuestCompanion, tel qu'il est publié |
| `Ready2Quest/Libs/Socle/` | le **socle commun** : sauvegarde, commandes, panneau de réglages, thème, textes communs, bouton de minicarte, lecture du monde (carte, lieux, donjons) |
| `tests/` | tests hors jeu, sur un client WoW simulé |
| `tools/` | générateurs de données et outils de publication |
| `data/` | notre base de données : PNJ, objets, quêtes et zones de Forever (et d'Era, dont les tables ne sont plus livrées) ([docs/DONNEES.md](docs/DONNEES.md)) |
| `docs/` | notes techniques, guide de publication, fiches des pages CurseForge et Wago |

## Pour les développeurs

- **Socle commun** : chaque addon embarque sa copie de `Libs/Socle`, comme une lib WoW. On ne le modifie que dans `Ready2Quest/Libs/Socle`, puis `python3 -I tools/sync_socle.py` le recopie dans `QuestCompanion/Libs/Socle`. Ce qui change d'un addon à l'autre (nom, sauvegarde, commande, logo) est dans son `Config.lua`.
- **Tests** : `python3 tests/run_tests.py` (paquet `lupa` requis), quelques secondes : chaque module dans son propre état Lua, un processus par cœur (`-j N` pour choisir, `--profile` pour les plus lents, `python3 tests/run_tests.py trades capture` pour quelques modules). Ils refusent de tourner si les deux copies du socle diffèrent, ou si un fichier de la racine risque de partir dans un zip publié. Voir `docs/TESTS.md`.
- **Mémoire** : `python3 tests/run_tests.py --memoire` donne la mémoire Lua que prend chaque fichier des deux addons au chargement (comme un client français, sans jouer les tests).
- **Données de zone paresseuses** : les tables générées (`ZoneCreatures_Forever.lua`, `ZoneQuests_Forever.lua`) ne construisent une zone qu'à sa première lecture ; les parcourir avec `ns.ZoneIds` / `ns.ZoneEach` (voir [docs/TECHNIQUE.md](docs/TECHNIQUE.md)).
- **Publication** sur CurseForge et Wago : tag `v*` pour Ready2Quest, `qc-v*` pour QuestCompanion. Voir [docs/PUBLIER.md](docs/PUBLIER.md).
- [Notes techniques et historique des versions](docs/TECHNIQUE.md).
- Zones sûres : `tools/gen_hubs.py` (lieux connus par leur sous-zone, `Libs/Socle/Hubs.lua`) et `tools/gen_places.py` (camps repérés par leurs PNJ de service, `Libs/Socle/Places.lua`), depuis `data/`. Donjons : `tools/gen_dungeons.py`.
- **Notre base de données** (`data/`) : PNJ, objets, quêtes et zones de Forever (et d'Era, gardées pour les outils), importés une fois de [Questie](https://github.com/Questie/QuestieDB) puis corrigés et complétés ici. Les tables de zone de QuestCompanion en sont générées par `tools/gen_zone_data.py`. Voir [docs/DONNEES.md](docs/DONNEES.md).
- Logos des deux addons (en jeu et pages des stores) : `tools/gen_logos.py` ; habillage du thème Azeroth (cadre, plaques, lueurs) : `tools/gen_ui_assets.py`. Les fonds des sceaux de zone et les cosmétiques des hauts faits utilisent des textures du jeu, appelées par leur identifiant (rien n'est embarqué).

## Licence

Logiciels libres sous licence **GPL-3.0** (voir `LICENSE`). Les données de zones de QuestCompanion viennent de Questie, lui-même sous GPL-3.0. Police Inter : licence OFL.
