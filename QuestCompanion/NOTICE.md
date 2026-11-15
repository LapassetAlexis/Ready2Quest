# Notice

## Données de zones

Six fichiers de l'addon sont dérivés de la base de données de [Questie](https://github.com/Questie/Questie), publiée dans le dépôt [Questie/QuestieDB](https://github.com/Questie/QuestieDB) (données importées de Questie), une paire par client :

| Fichier | Contenu |
| --- | --- |
| `ZoneCreatures_Forever.lua` | créatures de chaque zone |
| `ZoneGathering_Forever.lua` | herbes et minerais de chaque zone |
| `ZoneQuests_Forever.lua` | quêtes de chaque zone (niveau, niveau requis, races, classes, noms français et anglais, quêtes exclusives) |

Chaque fichier se garde lui-même : seul le client WoW Forever construit ces tables (Classic Era n'est plus pris en charge depuis la 1.2.0). Aucun addon tiers n'est requis en jeu : les quêtes ne sont plus lues dans Questie.

Ces données sont sous licence [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.html) (voir le `LICENSE.md` de QuestieDB).

### Couches appliquées

- **Forever** : données `data/Forever/`, puis les couches statiques dans l'ordre de QuestieDB (`docs/forever.md`, `src/config.lua`) : corrections Era héritées (`src/corrections/Forever/legacy/`), delta-base générée (`generated/`), traces (`traces/`), corrections Forever écrites à la main (`forever*Fixes.lua`). Zones et sous-zones : `support/Forever/Zones/`. Les zones propres à Forever (Zephras Isle, Riverglades, Shen'dralas, Darkspear Islands, Mount Hyjal) sont incluses.
- Seules les corrections statiques (`Load`) s'appliquent ; les corrections dynamiques (selon la faction ou le personnage) ne sont pas lues. Les quêtes cachées par Questie (`QuestieQuestBlacklist`, sauf `HIDE_ON_MAP`) et les quêtes d'événements saisonniers (`Holidays/quests`) viennent du dépôt [Questie/Questie](https://github.com/Questie/Questie) (GPL-3.0), passé en option `--questie-src`.

### Générer

Ces données ont été importées une fois de QuestieDB (commit `c5de61ab`, Questie 12.4.0) dans **notre** base, `data/` à la racine du dépôt, où on les corrige et les complète (`data/<client>/fixes.json`). Les fichiers de l'addon sont générés depuis `data/` seulement, par `tools/gen_zone_data.py` (Python 3, sans dépendance, sortie déterministe) :

```sh
python3 -I tools/gen_zone_data.py
```

Voir `docs/DONNEES.md` : contenu de la base, corrections, reprise facultative des nouveautés de Questie (`tools/import_questie.py`).

## Lieux sûrs (`Libs/Socle/Places.lua`)

Le socle commun embarque aussi les lieux repérés par leurs PNJ de service, générés depuis la même base par `tools/gen_places.py` (voir le `NOTICE.md` de Ready2Quest).

## Histoire des lieux (`LoreData.lua`)

Depuis la 2.13.0, le compagnon dit une phrase d'histoire des zones et de quelques sous-zones notables (`CompanionLore.lua`). Ces phrases viennent de [Warcraft Wiki](https://warcraft.wiki.gg), publié sous licence [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), telles que choisies, adaptées et traduites en français par le projet [Spoken](https://github.com/rusty-key/spoken-wow) de Rusty Key (`addons/Spoken_Places/Data`, commit `4ccae964bb4e04f40e82417efc2925cf6e147b90`). Merci à eux.

- Nous n'en gardons que le résumé court (`short`) de chaque lieu, réduit au besoin à une phrase ou coupé au mot (« … ») ; les entrées sans source (prose écrite par Spoken) sont écartées. La page du wiki d'où vient chaque ligne est le dernier champ de la ligne (`https://warcraft.wiki.gg/wiki/<page>`) et figure dans l'instantané `data/forever/lore/lore.json`.
- **Licence** : ces textes (`LoreData.lua`, `data/forever/lore/lore.json`) restent sous **CC BY-SA 4.0** (attribution, partage dans les mêmes conditions), et non sous la GPL-3.0 du reste de l'addon (compatibilité à sens unique CC BY-SA 4.0 → GPL-3.0). Le code de Spoken est sous licence MIT ; nous n'en reprenons pas de code, seulement la façon de normaliser les noms de lieux, réécrite dans `tools/gen_lore.py` et `CompanionLore.lua` (GPL-3.0).
- Générer : `python3 -I tools/gen_lore.py --fetch --cache <dossier>` (télécharge au commit épinglé et refait l'instantané), puis `python3 -I tools/gen_lore.py` (refait `LoreData.lua` ; vérifié par `tests/run_tests.py`).
- Si l'addon Spoken Places est chargé, le compagnon se tait sur l'histoire des lieux : Spoken la raconte déjà.

## Tables du client (`DisplaySizes_Forever.lua`, `MusicData.lua`)

Deux fichiers de l'addon sont dérivés des tables du client WoW Forever (build `1.60.1.70753`), publiées par [wago.tools](https://wago.tools) :

- `DisplaySizes_Forever.lua` (depuis la 3.1.0) : la taille de chaque apparence de créature, pour cadrer le compagnon, calculée depuis `CreatureDisplayInfo` et `CreatureModelData`. Générée par `tools/gen_display_sizes.py`, via notre base `data/forever/display_sizes.json`.
- `MusicData.lua` (depuis la 2.12.0) : le catalogue du juke-box, depuis `ZoneMusic`, `ZoneIntroMusicTable`, `SoundKitEntry` et `AreaTable`. Généré par `tools/gen_music.py`, via `data/forever/music.json`. Seuls les numéros des musiques du client y figurent : aucun fichier audio n'est embarqué, le jeu joue les siennes.

## Textures et logos

Les textures du thème (`Libs/Socle/Media/*.tga` : cadre, coin, anneau du médaillon, plaque, creux, lueurs, ombre, vignette), les logos (`Textures/logo*.tga`) et les textures de la scène de capture (`Textures/filet.tga`, `paquet.tga`, `corde.tga`) sont des dessins d'origine, calculés par `tools/gen_ui_assets.py`, `tools/gen_logos.py` et `tools/gen_capture_assets.py`. Rien n'est repris du jeu. Ils sont sous licence GPL-3.0, comme l'addon.

## Police

Inter (Regular, SemiBold, Bold), de Rasmus Andersson ([rsms/inter](https://github.com/rsms/inter), version 4.0), réduite aux caractères latins : `Libs/Socle/Media/Inter-Regular.ttf`, `Inter-SemiBold.ttf`, `Inter-Bold.ttf`. Licence SIL Open Font License 1.1 : voir `Libs/Socle/Media/Inter-OFL.txt`.

## Zone data (English)

`ZoneCreatures_Forever.lua`, `ZoneGathering_Forever.lua` and `ZoneQuests_Forever.lua` are generated by `tools/gen_zone_data.py` from our own database (`data/`), imported once from Questie's database (Questie/QuestieDB, GPL-3.0; quest blacklist and seasonal event lists from Questie/Questie, GPL-3.0) and maintained in this repository. Forever applies QuestieDB's static layers in order: inherited legacy corrections, generated delta-base, traces, authored Forever corrections. Each file only builds its table on the Forever client (Classic Era is no longer supported since 1.2.0). Do not edit them by hand.

## Story of places (English)

Since 2.13.0 the companion tells one line of lore about zones and a few notable subzones (`CompanionLore.lua`). The text comes from [Warcraft Wiki](https://warcraft.wiki.gg), licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), as selected, adapted and translated into French by Rusty Key's [Spoken](https://github.com/rusty-key/spoken-wow) project (`addons/Spoken_Places/Data`, commit `4ccae964`; Spoken's code is MIT). We keep each place's short summary only, cut to one sentence or at a word boundary when needed; entries without a wiki source are dropped. Each line ends with its wiki page (`https://warcraft.wiki.gg/wiki/<page>`). `LoreData.lua` and `data/forever/lore/lore.json` remain under **CC BY-SA 4.0** (attribution, share-alike), not under the addon's GPL-3.0. Generated by `tools/gen_lore.py`. When the Spoken Places addon is loaded, the companion stays quiet on lore.

## Client tables (English)

`DisplaySizes_Forever.lua` (since 3.1.0: the size of each creature display, used to frame the companion, from `CreatureDisplayInfo` and `CreatureModelData`; generated by `tools/gen_display_sizes.py`) and `MusicData.lua` (since 2.12.0: the jukebox catalogue, from `ZoneMusic`, `ZoneIntroMusicTable`, `SoundKitEntry` and `AreaTable`; generated by `tools/gen_music.py`; music IDs only, no audio file is shipped) are derived from the WoW Forever client tables (build `1.60.1.70753`) published by [wago.tools](https://wago.tools).

## Textures and logos (English)

The theme textures (`Libs/Socle/Media/*.tga`), the logos (`Textures/logo*.tga`) and the capture scene textures (`Textures/filet.tga`, `paquet.tga`, `corde.tga`) are original artwork, computed by `tools/gen_ui_assets.py`, `tools/gen_logos.py` and `tools/gen_capture_assets.py`. Nothing is taken from the game. They are licensed under the GPL-3.0, like the addon.

## Font (English)

Inter (Regular, SemiBold, Bold) by Rasmus Andersson ([rsms/inter](https://github.com/rsms/inter), version 4.0), subset to Latin characters: `Libs/Socle/Media/Inter-*.ttf`. Licensed under the SIL Open Font License 1.1: see `Libs/Socle/Media/Inter-OFL.txt`.
