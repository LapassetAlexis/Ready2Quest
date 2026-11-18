# Traduction (espagnol, socle 3.6)

Les deux addons parlent français, anglais et espagnol (clients `esES` et
`esMX`, un seul texte espagnol). La langue vient du client (`GetLocale`) :
`ns.STRINGS_LANG` vaut `"fr"`, `"es"` ou `"en"`. Sur un client espagnol, une
clé sans traduction prend l'anglais, puis le français.

## Les textes de l'addon

- Français et anglais : déclarés dans le code, comme avant
  (`ns.RegisterStrings(FR, EN)`).
- Espagnol : `Ready2Quest/Locales_es.lua` et `QuestCompanion/Locales_es.lua`,
  chargés en dernier (`ns.RegisterLocaleStrings("es", {...})`). Seul un client
  espagnol (ou les tests) les garde.
- Circuit, avec `tools/i18n.py` (lupa, comme `tests/snapshot.py`) :
  1. `export <dossier>` : les clés sans espagnol, par lots JSON
     (`{ clé: { en, fr } }`, ~2 500 mots) ;
  2. traduction de chaque lot en `<lot>.es.json` (`{ clé: texte }`), avec les
     mêmes codes (`%s`, `%d`, `|c…|r`, `|T…|t`, `\n`) et les commandes
     (`/qc joke`, `/r2q options`) telles quelles ;
  3. `import <dossier>` : réécrit les deux `Locales_es.lua` (les textes déjà là,
     plus les lots) ; `misc-001.es.json` donne les groupes du juke-box
     (`ns.MUSIC_GROUPS_ES`) et les titres (`ns.FEAT_TITLES_ES`, masculin et
     féminin), `lore-001.es.json` l'histoire des lieux
     (`data/forever/lore/lore_es.json`, puis `tools/gen_lore.py`) ;
  4. `check` : aucune clé sans espagnol, mêmes codes que l'anglais ;
  5. `fit` : les réglages des deux addons ouverts sur un client espagnol
     simulé, ce qui ne tient pas à sa place.
- Aperçu en espagnol : `SNAPSHOT_LOCALE=esES python3 tests/snapshot.py <scène> <sortie.html>`.
- Tests : `tests/modules/spanish.lua` (couverture, codes, titres, juke-box,
  histoire des lieux, noms du jeu).

## Les noms du jeu

Le client espagnol donne lui-même les noms des objets, sorts et zones. Pour
les noms que nos tables gardent en français et en anglais (créatures et quêtes
des zones, objets de récolte, sous-zones de l'histoire des lieux) :
`tools/gen_names_es.py import` lit les fichiers `l10n/Forever/*/esES.lua` et
`esMX.lua` de QuestieDB et les tables `AreaTable` du client (wago.tools,
espagnol et anglais : un nom de lieu n'est gardé que si le lieu porte encore
le même nom anglais que sur Forever) -> `data/forever/names_es.json` ;
`tools/gen_names_es.py lua` -> `QuestCompanion/NamesES.lua`
(`ns.SpanishName(sorte, id)`, le nom mexicain quand il diffère).
