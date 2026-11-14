# Tests hors jeu

Suite de tests des deux addons (Ready2Quest, QuestCompanion), jouée hors du
client : Lua 5.1 (celui du client WoW) via le paquet python `lupa`, sur une
maquette du client. Elle valide la logique, pas les contrats d'API réels
(`/r2q diag`, `/qc diag` et les essais en jeu servent à ça).

## Lancer

```sh
python3 tests/run_tests.py                     # toute la suite, un processus par cœur (~6 s sur 10 cœurs)
python3 tests/run_tests.py -j 1                # un seul processus (~30 s), même sortie
python3 tests/run_tests.py trades capture      # seulement ces modules (nom de fichier sans .lua)
python3 tests/run_tests.py core                # seulement les scénarios du cœur (tests/run_tests.lua)
python3 tests/run_tests.py --profile           # en plus : les 25 unités les plus lentes, avec leurs contrôles
python3 tests/run_tests.py --memoire           # mémoire Lua de chaque fichier au chargement (sans les tests)
TEST_SEED=7 python3 tests/run_tests.py         # autre graine du tirage (chasse aux tests qui dépendent du hasard)
```

`lupa` : `pip install lupa` (ou `pip install --target /tmp/pylib lupa`, le
lanceur regarde aussi `/tmp/pylib`, ou `LUA_PYLIB`). Il faut python 3.10+ avec
lupa ; sur cette machine, `/usr/local/bin/python3`.

Sortie : les lignes `PASS` / `FAIL` de chaque unité, dans l'ordre (cœur, puis
modules par ordre alphabétique), puis `RESULTAT: N réussis, M échoués, T
assertions`. Code de sortie : 0 vert, 1 échec, 2 erreur Lua ou garde-fou de
publication.

## Ce qui tourne avant les tests (`run_tests.py`)

Une fois, dans le processus principal, avant tout test ; un échec arrête tout
(code 2) :

- maquette : pas deux `function region:X` (la seconde écrase la première) ;
- paquets : chaque `.pkgmeta` ignore tout ce qui n'est pas son addon ; aucune
  image embarquée hors `ALLOWED_IMAGES` (filet, cordes, paquet, logos) ;
- socle : les copies de `Ready2Quest/Libs/Socle` sont identiques et l'empreinte
  à jour (`tools/sync_socle.py`) ;
- fichiers générés : tables de zone, `Places.lua`, `Hubs.lua`, `MusicData.lua`,
  `LoreData.lua` régénérés à part et comparés à `data/`.

## Structure

- `tests/run_tests.lua` : la maquette du client (cadres, événements, horloge,
  API), le chargement des deux addons depuis leur `.toc` (comme le client), les
  **scénarios du cœur** de Ready2Quest (unité `core` : migrations de la
  sauvegarde, zones sûres, alerte de sortie, les 13 checks, robustesse aux API
  absentes), puis la section 4.99 qui joue un fichier de module.
- `tests/modules/*.lua` : un fichier par fonctionnalité (plus de fichier par
  version). Chacun reçoit `T = { Check, Say, ResetWorld, Result, NS (R2Q),
  QNS (QC), Mock }`.
- `tests/snapshot.lua` / `tests/snapshot.py` : aperçu HTML hors jeu d'une
  fenêtre, et la géométrie absolue utilisée par `ui_windows.lua`,
  `ui_bricks.lua`, `guide_tours.lua`, `missions.lua`.

**Une unité = un état Lua neuf.** Le cœur et chaque module tournent chacun
dans leur propre `LuaRuntime` : les deux addons fraîchement chargés (0,1 s),
`ResetWorld()`, `ADDON_LOADED`. Aucun module ne voit ce qu'un autre a laissé ;
l'ordre et le découpage entre processus ne changent rien. Le tirage
(`math.random`, le `rand()` du C commun au processus) est réensemencé au début
de chaque unité. Avant (un seul état pour toute la suite), chaque cadre créé
restait dans `Mock.frames` et chaque événement, chaque pas d'horloge les
parcourait tous : 14 minutes en local, plus de 4 Go de mémoire, 30 à 65 minutes
sur GitHub (et des runners coupés).

Par défaut dans le banc (section 4.99) : `SHINY_CHANCE = 0`, `DAILY_AUTO = false`,
`TOUR_AUTO = false`, conseils du compagnon sans examen automatique
(`adviceNextAt = math.huge`). Les modules qui testent ces choses les rallument
eux-mêmes (`shiny.lua`, `companion_daily.lua`, `guide_tours.lua`,
`companion_advice.lua`).

**Thème de QuestCompanion (3.1.0)** : le banc tourne dans l'état du produit,
au thème forgé (choix « azeroth » par défaut, posé sans les atlas du client)
et ancien habillage coupé (`QNS.AZEROTH_LEGACY = false`). Avant, faute de
`C_Texture` dans la maquette, QuestCompanion tournait sans le dire au thème
Sobre. Conséquences :

- `T.Legacy(true)` rallume l'ancien habillage (carnet en parchemin, scènes en
  bois, bandeaux dorés, anneau du compagnon) pour un module ou un sous-cas qui
  l'affirme, `T.Legacy(false)` le recoupe ; le banc remet la valeur du produit
  à la fin de chaque module. Les modules de l'ancien habillage l'appellent en
  tête, sans autre changement de leurs assertions (`azeroth_style`,
  `capture_scene`, `journal_layout`, `menagerie_journal`, `missions`,
  `qc212_jukebox`, `specimen_traits`, `trades`, `ui_windows`, `ui_bricks`,
  `addons_link`, `companion_allure`, `companion_effects`, `feats`,
  `feats_rewards`, `share`, `guide_tours`, `capture_preparation`,
  `winter_veil`) ; `ui_forge_qc` le pose pour ses confirmations sur parchemin.
- Un test du **Sobre** le demande : `companionStyle = "sobre"` puis
  `ApplyUIStyle()` (le filet et le bandeau dans `capture.lua`, `C.Sobre()` ;
  le cadre du suivi dans `journal_tracker.lua`).
- Un reset qui change `companionStyle` après `ResetWorld()` repose aussi le
  thème (`Theme.ApplySkin(QNS:UISkinChoice())`, comme `journal_layout.lua`) :
  sinon le thème posé au chargement reste celui du choix d'avant.
- Le Voile d'hiver suit le choix « azeroth » et l'horloge de la maquette
  (`time()` vers 1970-01-01) tombe en saison : un scénario du filet coupe le
  décor (`winterVeil = "off"`), comme les aperçus (`tests/snapshot.lua`).
- `tests/modules/forge_bascule.lua` (`[BASC]`) épingle l'état du produit,
  avec et sans atlas : thème forgé, surfaces au socle (`uiStyle` « sobre »,
  `styleKey` « forge », fenêtres habillées), bascule à chaud sans fuite.
- Un module par lot du thème forgé, chacun avec son Sobre inchangé et ses
  contrastes mesurés sur le vrai fond (`docs/UI.md`, « QuestCompanion au
  thème forgé ») : `ui_identite.lua` (`[IDENT]`, 5 contrôles : rôles des
  deux addons, Ready2Quest au chiffre près, QuestCompanion inversé, Sobre,
  allers-retours), `journal_forge.lua` (`[JFG]`, 11 : médaillon et plaque du
  carnet, paliers des envies, garde-manger, Hauts faits, fiche, allure et
  confirmation, Voile d'hiver du carnet et son repli),
  `forge_bandeaux.lua` (`[FBAN]`, 8 : médaillon, plaques, apparition, grand
  effet avec et sans atlas, guilde sur deux lignes, Partager, bulle des
  visites), `forge_scenes.lua` (`[FSC]`, 9 : verdict dans la scène,
  préparation, volée, choix au filet, « Capturer ? », clés de cache),
  `companion_forge.lua` (`[FCOMP]`, 13 : médaillon, humeurs, cadre gagné,
  effets, Voile d'hiver, bulle, bascule à chaud sans cadre créé, ancien
  habillage). Les assertions des modules du produit qui décrivaient le
  cadre carré ou le Sobre sous le thème forgé sont épinglées en Sobre
  (`companion_notify`, `companion_rewards`) ou lisent le cadre forgé
  (`share`, `feats_rewards`, `capture_lot`, `companion_fx`).

Avec ces modules, la suite compte 3 592 contrôles (3.1.0 bêta, avant
publication).

## Écrire un test

- **Un `Check` par comportement**, pas par ligne de code. Les étapes d'un même
  scénario vont dans un seul contrôle qui nomme celles qui ratent :

  ```lua
  -- plusieurs étapes d'un même sujet : un contrôle, les étapes ratées nommées
  local function Steps()
  	local s = { bad = {} }
  	function s.ok(label, cond, extra)
  		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
  	end
  	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
  	return s
  end
  ```

  Même idée sous d'autres noms selon les fichiers : `Want(label, ok)` puis
  `Verdict(name)` (`live_api.lua`, `options.lua`, `performance.lua`,
  `socle.lua`, `quest_companion.lua`), `Scenario` (fichiers du compagnon).
  Un échec affiche toutes les étapes ratées dans le `->` de la ligne `FAIL`.
- **Catalogues et listes** : une boucle qui range les fautifs, un seul
  `Check(nom, #bad == 0, table.concat(bad, ", "))`.
- **Mise en page** : un invariant par sujet (« le texte tient dans sa plaque »,
  « rien ne se chevauche », « les lumières restent dans le cadre »), jamais les
  décalages mesurés sur une capture d'une bêta.
- **Garder** ce qui protège les joueurs : migrations de sauvegarde, protocoles
  entre joueurs (échanges, fiche de dresseur, guilde), tables de chances,
  intégrité des catalogues, contrastes mesurés (WCAG), hygiène du code, mémoire
  et performance, chargement sans erreur, cohérence des versions, textes
  français et anglais complets.
- **Autonome** : un module sauve et remet toute globale ou champ de `NS`/`QNS`
  qu'il remplace ; il ne compte sur aucun autre module, ni sur les scénarios du
  cœur (s'il lui faut l'entrée en jeu, il fait `Mock:Fire("PLAYER_ENTERING_WORLD", true, false)`).
- **Déterministe** : tout tirage testé passe par un `math.random` remplacé le
  temps du test ; vérifier avec deux ou trois `TEST_SEED`.
- Un nouveau comportement va dans le fichier de sa fonctionnalité ; un nouveau
  fichier seulement pour une nouvelle fonctionnalité, nommé d'après elle.

## Intégration continue

`.github/workflows/tests.yml` : sur les pull requests (un push plus récent annule
l'exécution en cours de la même PR), sur `main`, et appelé par `release.yml`
avant toute publication (tag `v*` / `qc-v*`, ou essai à blanc). Plus sur chaque
push de branche : une branche sans PR est testée en local, et sa publication
rejoue les tests sur le commit du tag ; un même commit n'est plus testé deux
fois. `timeout-minutes` : 10 pour les tests (une à deux minutes attendues sur un
runner à 4 cœurs), 20 pour le paquet et l'envoi.

## Rationalisation 3.0.0 (2026-11-11)

Avant : 7 510 assertions, 114 fichiers de module + le cœur, ~14 min en local
(805 s pour les 7 025 premières), 30 à 65 min sur GitHub. Après : 3 203
assertions, 68 fichiers + le cœur, ~6 s en local (`-j` sur 10 cœurs), ~9 s sur 4 cœurs, ~30 s
avec `-j 1`.

Une bonne part de la baisse vient du regroupement des étapes d'un scénario
en un seul contrôle (même couverture : chaque condition d'avant est toujours
évaluée, et nommée en cas d'échec) ; le reste est retiré pour de bon :

| Groupe | Avant | Après | Fichiers |
|---|---:|---:|---|
| Cœur de Ready2Quest (`run_tests.lua`) | 767 | 354 | — |
| Modules de Ready2Quest | 915 | 520 | `buffs`, `checks`, `gear_portrait` (fusion des fichiers `r2q_1322`, `r2q_1333_buffs`, `r2q_buffs_caster`, `r2q_diag_lignes`, `r2q_gear_retry`, `r2q_portrait_hover`, `r2q_profcap`, `r2q_travel_quests`) |
| Socle, interface, infrastructure | 934 | 278 | `socle`, `performance`, `live_api`, `ui_bricks`, `ui_windows`, `options` (fusion de 18 fichiers) |
| Capture, spécimens, échanges | 782 | 532 | `capture`, `capture_lot`, `capture_preparation`, `specimens`, `specimen_traits`, `trades`, `companion_aggro` |
| Ménagerie, scènes, visites guidées, effets | 692 | 289 | `menagerie_journal`, `capture_scene`, `guide_tours`, `companion_effects` |
| Compagnon | 847 | 161 | `companion_frame`, `companion_speech`, `companion_rewards` (+ les fichiers `companion_*` allégés) |
| Jour, missions, brillantes, guilde, fiche | 654 | 328 | `missions`, `shiny` |
| Hauts faits, Voile d'hiver, allure | 712 | 209 | `feats`, `feats_catalogue`, `feats_rewards`, `winter_veil`, `companion_allure` |
| Carnet, bestiaire, données de zone | 760 | 321 | `journal`, `zone_data` |
| Style Azeroth, mise en page du carnet | 447 | 211 | `azeroth_style`, `journal_layout`, `companion_models` |
| **Total** | **7 510** | **3 203** | |

### Retiré, par catégorie

- **Fonctionnalités disparues** (~30) : album des Souvenirs (2.6.0, une
  vérification d'absence au lieu d'une dizaine ; le nettoyage de la sauvegarde
  reste), tutoriel de la ménagerie 2.3 (remplacé par les visites guidées 3.0,
  absence vérifiée une fois), limites de recapture et réglettes `companionRetry*`
  (2.15.0, une vérification), tirage d'étoiles après la capture (la qualité se
  tire au coup fatal ; couvert par le test qui la garde), losanges de rang de la
  scène de capture (plus dessinés depuis 2.14.0 bêta 3), ancien panneau de stuff
  de R2Q (v1.16.0, une vérification qui garde le bug `OPT_STUFF_SHORT`),
  `Theme.CreatePanel`/`CreateDivider`, carrousel d'allure, paysages de sceaux
  peints, Questie et tables Era (une seule vérification d'absence).
- **Doublons** (~300) : bouton de minicarte testé dans deux sections du cœur,
  bandeau de verdict testé trois fois (qc28, qc282, qc29), bulle et fondu du
  modèle en combat deux fois, page Complétion re-testée par le suivi du carnet
  (~35), file du filet / « pas de fenêtre automatique » / minuterie dans trois
  fichiers de capture, cartes des missions du jour dans deux pages, parité des
  textes répétée par fichier (une par table), registre des titres vérifié trois
  fois, contraste `allure.*` qui répétait le garde global, Réserve et Échoppe
  jouées en entier dans les deux styles (Azeroth complet, Sobre en fumée).
- **Mesures d'une bêta** (~350) : guirlande du Voile d'hiver `[WV4..WV7]`
  (y = −20, ampoule 11,5, caméra 1,9, bord doré −14/−26…), caméra de Metzen par
  bêta (2,5 / 1 / 0,6), tailles exactes des briques (barre 2 px, carte 38,
  interrupteur 32×15, curseur 3 px…), décalages du résumé de stuff et du bouton
  de minicarte, grille des Missions (420/274/206, plaques 230×56), hauteurs de la
  carte de préparation, filet 44 px, couleurs exactes en hexadécimal. À la place,
  un invariant par sujet (tient, centré, sans chevauchement, dans le cadre) ;
  les tailles canoniques de docs/UI.md « Composants 3.0 » restent, une fois.
- **Boucles d'un contrôle par élément** (~400 → ~60) : textures Azeroth page par
  page, scènes de fenêtres R2Q, cosmétiques de coffre, nouvelles créatures,
  barème et verdicts de l'aggro, réservoirs de répliques, sorties de fenêtre par
  échappe, etc. : un contrôle qui liste les fautifs.
- **Évidences** (~100) : « la fonction existe » suivie d'un appel, `Check(…, true)`,
  « le fichier est chargé », valeurs relues juste après les avoir posées.
- **Étapes d'un même scénario regroupées** (~3 000) : ouvert → titre → boutons →
  fermé, ou réglage coupé → message → remis ; un contrôle par comportement, chaque
  condition toujours évaluée et nommée.

### Gardé (rien n'a été affaibli)

- Migrations de sauvegarde : SacEtDepartDB → ReadyToQuestDB → Ready2QuestDB,
  schémas des buffs et de l'aggro, R2Q 1.25 → QuestCompanion, fiches d'avant
  1.6.0 et brillantes, collection au compte, espèces → spécimens (3.0, idempotent),
  caractère et taille (3.1), cadeau de la 3.0, nettoyage des Souvenirs, tampons
  du carnet → hauts faits, récompenses 2.6 → 2.7 payées une fois.
- Échanges entre joueurs : poignée de main et version, chaque refus, révisions,
  validation en deux temps sans double application, chaque abandon, reprise après
  /reload, abandon à 7 jours, journal.
- Capture : chances par rang et niveau, aides, plafond 95 %, malchance +5 à +25,
  qualité par rang, méfiance ; brillantes 1/150, ×3 élite ou rare, une fois par
  monstre.
- Hauts faits : ids et codes uniques, points, portées, comptes par catégorie,
  empreintes de l'encodage compact (173 et 180 lignes), 40 titres, cosmétiques
  faits d'images du client.
- Protocoles : fiche de dresseur (aller-retour, vieilles versions, morceaux sous
  255 octets, débit), exploits de guilde (format versionné, 18 entrées mal
  formées refusées).
- Contraste : chaque rôle de `ns.AZEROTH_CONTRAST` recalculé (≥ 4,5 texte, ≥ 3
  dès 16 px) sur le pire fond mesuré, désormais contre son propre seuil déclaré ;
  paires du socle, boutons, Missions, Juke-box, Réserve, Échoppe, visites.
- `code_hygiene.lua` intact : couleurs déclarées une fois, pas de `|cff` en dur,
  pas de print littéral, pas de ★/☆.
- Mémoire et performance : chaque raccourci rend ce que rendait le chemin lent,
  infobulle sous 5 Ko, horloge unique sans allocation au repos, aucun cadre créé
  par un rafraîchissement.
- Chargement sans erreur des deux addons, seuls et ensemble (`zz_integration`),
  versions cohérentes (.toc, `ns.APP`), copies du socle, commandes enregistrées,
  textes français et anglais complets, robustesse aux API absentes ou secrètes.
