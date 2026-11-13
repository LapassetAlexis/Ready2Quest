# Audit de performance — Ready2Quest 1.34.0 (2026-11-13)

Deuxième passe, sur les seuls modules de Ready2Quest (`Ready2Quest/*.lua`), partie de `main` (00e95ab). La première passe (`docs/AUDIT-PERF.md`) avait traité les événements d'unité (`UNIT_AURA` et `UNIT_STATS` du joueur seulement), la table de travail des buffs et le décompte du camp. Celle-ci vise trois choses :

1. **Abonnements** : un module coupé, ou un événement qui ne sert qu'à un moment (voyage, fenêtre ouverte, hors combat), ne reste plus abonné. Le client ne l'envoie plus du tout au Lua.
2. **Déchets** : plus de tables, chaînes ou fermetures neuves dans les chemins fréquents (marques d'aggro, liserés des rangs de sorts, messages d'erreur, sonde du portrait, zone sûre, infobulles d'objets).
3. **Robustesse** : appels au client protégés là où ils ne l'étaient pas, caches bornés.

Rien ne change à l'écran ni dans la sauvegarde (`Ready2QuestDB` : aucune clé ajoutée, retirée ou renommée). Seule nouveauté visible : une ligne de `/r2q diag` (« abonnements en pause »), pour vérifier tout ça en jeu.

Hors champ : le socle (`Libs/Socle`), QuestCompanion, `Checks.lua`, `Dungeon.lua`, `Locales.lua`, `Config.lua` et le `.toc` (travaux en cours ailleurs).

## 1. Diagnostic

Ready2Quest ne s'abonne pas à `QUEST_LOG_UPDATE`. Le journal de quêtes n'est lu qu'au check (`Checks.lua`), au départ et au retour d'expédition. Les points retenus, du plus coûteux au moins coûteux :

| # | Où | Problème | Fréquence |
|---|---|---|---|
| 1 | `SpellRanks.lua`, liserés | Chaque posture, page de barre, barre bonus ou case changée relit **tout le livre de sorts** (une fiche par sort, `tostring`/`match` par rang) et refait **456 noms de boutons** par `string.format`. En combat aussi (forme de druide, posture de guerrier, camouflage). Module coupé : le passage tourne quand même, pour cacher des liserés absents. | chaque changement de barre ; ≈ 37 Ko de déchets par passage (120 sorts) |
| 2 | Abonnements des modules coupés | Aggro (`NAME_PLATE_*`, `MODIFIER_STATE_CHANGED`, `GET_ITEM_INFO_RECEIVED`, tâche à 5 Hz), Sac plein et Place au butin (`UI_ERROR_MESSAGE`, `LOOT_OPENED`), Rythme (`CHAT_MSG_COMBAT_XP_GAIN`, XP, quêtes), Rangs (barres d'action, livre), Camp (`UNIT_AURA`, tâche à 4 Hz) restent abonnés module coupé : chaque événement arrive, passe un `pcall` et sort au premier test | en continu |
| 3 | Événements d'un moment, abonnés en permanence | `CHAT_MSG_LOOT`, `PLAYER_MONEY`, XP, morts (Expédition) hors voyage ; `GET_ITEM_INFO_RECEIVED` (Récompense) pour chaque objet que charge le client ; `UNIT_STATS` (Résumé de stuff) à chaque buff, proc ou forme ; `BAG_UPDATE`/`BAG_UPDATE_DELAYED` (Sac plein, Place au butin) fenêtres fermées | chaque butin du groupe, chaque objet chargé, chaque buff |
| 4 | Combat | L'aggro cache tout en combat, mais suit les barres de nom, la touche Maj, les objets reçus, et son horloge passe 5 fois par seconde pour rien. `UNIT_AURA` du camp double sa propre horloge (4 Hz). | des dizaines par seconde en groupe |
| 5 | `UI_ERROR_MESSAGE` (Sac plein **et** Place au butin) | Chaque message (« Hors de portée », « Pas assez de rage »…) est normalisé (7 `gsub`/`lower`), ainsi que les deux globales du client qu'on lui compare, deux fois (un par module) | sans cesse en combat ; ≈ 94 Ko par 1 000 messages |
| 6 | `Aggro.lua`, marques | Une fiche `AggroEvaluate` par barre et par passage, `AggroMode` (touche lue) relu pour chaque barre | 5 Hz × barres visibles ; ≈ 0,2 Ko par barre et par passage |
| 7 | `QuestReward.lua`, `Call` | `{ pcall(...) }` puis `unpack` : une table par appel protégé, une dizaine par survol d'objet (classe, niveau, stats et liens des pièces portées) | chaque infobulle d'objet ; 125 Ko par 1 000 appels |
| 8 | `Stats.lua`, sonde du portrait | `pcall(function() return frame.unit end)` : une fermeture neuve par cadre parcouru (jusqu'à 4 par passage) | 10 Hz ; ≈ 47 Ko par 1 000 lectures |
| 9 | `Core.lua`, `IsCurrentZoneSafe` | La liste des signaux vivants (table) refaite à chaque appel hors zone sûre, pour n'en lire que le premier | 1,5 s sur une carte à lieux repérés ; 4 Hz au camp (`CampInTown`) |
| 10 | Divers | `{ true, ns.ItemInfo(...) }` par objet des sacs (Sac plein, Place au butin) ; comparateur de tri du butin recréé ; une fermeture par buff suivi (`EvaluateBuffs`) ; opacités de l'icône atténuée reposées à chaque image pendant une minute ; `UnitClass` non protégé (panneau du portrait) | au fil de l'eau |

## 2. Ce qui a été changé, fichier par fichier

### `Core.lua` : abonnements à la demande

- **`ns.EventGate(nom, porte)`** : chaque module déclare ses « portes » : cadre, événements, tâche d'horloge éventuelle, `want(ns)` (faut-il écouter ?), `onPause`/`onResume`. Au chargement, tout est abonné comme avant. `ns:SyncEventGates()` relit chaque porte et ne touche qu'à celles qui changent (`RegisterGameEvent` pour réabonner, donc `UNIT_*` du joueur seulement ; `UnregisterEvent` sous `pcall`). Un `want` en erreur garde l'abonnement et note l'erreur.
- **Chemins de synchro** :
  - entrée en jeu ;
  - entrée et sortie de combat ;
  - changement de zone ;
  - après **chaque** commande `/r2q` (enveloppe de `ns:HandleCommand`) ;
  - après chaque changement de réglage (`RefreshOptions`, `OptionPages.lua`) ;
  - au fil des états propres aux modules (voyage, récompense, série d'équipement, fenêtres) ;
  - en **filet**, toutes les `ns.GATE_SAFETY` (10 s).
- **Combat** : `ns.gateCombat` est posé par `PLAYER_REGEN_DISABLED`/`ENABLED`, sur le premier cadre qui les reçoit (le cœur ou l'aggro, `ns:SetGateCombat`). Sur `PLAYER_REGEN_DISABLED`, `InCombatLockdown()` est encore faux. Un `/reload` en combat lit `InCombatLockdown()` à l'entrée en jeu. Un `PLAYER_REGEN_ENABLED` perdu est rattrapé par le filet, qui relit le client hors de cet événement.
- `ns:ResetEventGates()` : retour à l'état du chargement (banc de test).
- `/r2q diag` : « abonnements en pause : … (en combat) ».
- `IsCurrentZoneSafe` lit le premier signal vivant sans table (`FirstLiveSignal`, même ordre que `LiveSafeSignals`, qui reste pour `LearnFromSignals` et les tests).

`ns.EventGate` est un candidat pour le socle (QuestCompanion en profiterait aussi). Il est resté dans `Core.lua` parce que le socle était en travaux de son côté.

### Portes posées

| Porte | Fichier | Événements (et tâche) | Ouverte quand |
|---|---|---|---|
| `aggro` | `Aggro.lua` | `NAME_PLATE_UNIT_ADDED/REMOVED`, `MODIFIER_STATE_CHANGED`, `GET_ITEM_INFO_RECEIVED`, tâche `aggro` (5 Hz) | module actif **et hors combat** ; à la reprise, barres relues (`GetNamePlates`), mesures oubliées, un passage tout de suite |
| `bagspace` | `BagSpace.lua` | `UI_ERROR_MESSAGE`, `LOOT_OPENED` | module actif (et addon allumé) |
| `bagspace:bags` | `BagSpace.lua` | `BAG_UPDATE`, `BAG_UPDATE_DELAYED` | module actif et bandeau affiché (ouvert par `ShowBagSpaceFrame`, rendu au premier mouvement qui le trouve fermé) |
| `lootroom` | `LootRoom.lua` | `LOOT_OPENED`, `UI_ERROR_MESSAGE` | module actif |
| `lootroom:bags` | `LootRoom.lua` | `BAG_UPDATE_DELAYED` | fenêtre ouverte (même à la main, module coupé) ou ramassage en attente |
| `expedition` | `Expedition.lua` | `PLAYER_MONEY`, `PLAYER_XP_UPDATE`, `PLAYER_LEVEL_UP`, `PLAYER_DEAD`, `CHAT_MSG_LOOT` | voyage en cours (`ExpeditionStart` … `ExpeditionFinish`) |
| `pace` | `LevelPace.lua` | XP, niveau, `CHAT_MSG_COMBAT_XP_GAIN`, `QUEST_COMPLETE/FINISHED/TURNED_IN` | module actif, sous le niveau maximum ; à l'arrêt, le suivi est oublié (ce que faisait le premier événement reçu module coupé) |
| `reward` | `QuestReward.lua` | `QUEST_ITEM_UPDATE`, `GET_ITEM_INFO_RECEIVED` | écran de récompense ouvert (`QUEST_COMPLETE` … `QUEST_FINISHED`) |
| `spellranks` | `SpellRanks.lua` | livre, barres d'action, postures, fin de combat | module actif, ou fenêtre ouverte à la main ; à l'arrêt, un passage retire les liserés |
| `camp` | `Camp.lua` | tâche `camp` (4 Hz) | décompte actif (module et réglage) ; à l'arrêt, le cadre est rangé |
| `camp:aura` | `Camp.lua` | `UNIT_AURA` (joueur) | décompte actif **et hors combat** (l'horloge suffit en combat ; un passage à la sortie) |
| `gear` | `Stats.lua` | `UNIT_STATS` (joueur), `PLAYER_AVG_ITEM_LEVEL_UPDATE` | série de changements d'équipement en cours (`gearPending`) |
| `favorites:click` | `Favorites.lua` | `GLOBAL_MOUSE_UP` | raccourci des favoris choisi (pas « désactivé ») |

Ce qui sert en combat ou en instance reste abonné. Le butin et l'XP d'un voyage comptent en donjon. L'XP des monstres compte pour le rythme. « Sacs pleins » prévient aussi en combat. Les marques d'aggro servent aux tirages en donjon. Aucune porte ne dépend donc de l'instance.

### Chemins fréquents

- **`SpellRanks.lua`**
  - `SlotUpgrade` est partagé par `SpellRankScan` et les liserés. Les cases à marquer vont dans une table réutilisée, sans liste ni fiche par case.
  - Noms des boutons faits une fois (`ButtonNames`), refaits si `ns.SPELLRANKS_BUTTONS` change.
  - En combat, le livre de sorts est lu une fois et gardé jusqu'à la fin du combat, ou jusqu'à `SPELLS_CHANGED` / `LEARNED_SPELL_IN_TAB` / l'entrée en jeu. Hors combat, il est relu à chaque passage, comme avant.
- **`Aggro.lua`** : `Evaluate` rend portée, fourchette et verdict en valeurs. `AggroEvaluate` (infobulle, tests) garde sa fiche. `AggroTick` lit le mode une fois par passage et le donne à `AggroUpdatePlate(unit, mode)`.
- **`BagSpace.lua`**
  - `IsBagFullError` garde les textes normalisés : ceux des messages reçus (bornés à `ns.BAGSPACE_NORMALIZED_MAX` = 64, vidés au-delà) et ceux des globales du client (rangés par leur texte brut : une globale changée est relue).
  - `ItemInfo` sans table intermédiaire ; prix de vente lu seul (`ItemSellPrice`).
- **`LootRoom.lua`** : `ItemData` sans table intermédiaire ; comparateur du butin fait une fois (`LootBefore`).
- **`QuestReward.lua`** : `Call` passe les retours de `pcall` sans table (`Pass`).
- **`Stats.lua`**
  - Champ `.unit` lu par une fonction faite une fois (`UnitField`).
  - `UnitClass` protégé (`PlayerClassInfo` : `rawget`, `pcall`, `ns.Plain`).
- **`Buffs.lua`** : `EvaluateBuffs` passe par `HasAuraBySpellID` (une fonction faite une fois) sous `pcall`, plus une fermeture par buff.
- **`Favorites.lua`** : noms `ContainerFrameN` faits une fois ; liste des cadres de sacs réutilisée.
- **`Notice.lua`** : la minute d'icône atténuée pose ses opacités une fois, pas à chaque image (reposées après le mode déplacement).

### Tests

- `tests/run_tests.lua` : `ResetWorld` remet les portes à l'état du chargement (`ns:ResetEventGates`). Un monde neuf est hors combat, tout abonné, même si un test précédent a laissé un `PLAYER_REGEN_DISABLED` sans sortie.
- `tests/modules/r2q_performance.lua` (`[R2Q PERF]`, 15 contrôles) :
  - mécanique des portes : synchro au changement seulement, horloge suivie, état du chargement, `want` en erreur ;
  - chaque module coupé puis rouvert par `/r2q module`, par l'interrupteur des réglages, par une carte de réglage (`RefreshOptions`), par `/r2q off|on` et par le filet ;
  - ce qui est rangé à l'arrêt (rythme oublié, cadre du camp) ;
  - combat : coupé, rouvert ; `/reload` en combat ; sortie de combat perdue, rattrapée par le filet ;
  - voyage, récompense, série d'équipement, fenêtres des sacs, raccourci des favoris ;
  - même résultat que l'ancien chemin et rien d'alloué : marques d'aggro, liserés, messages d'erreur, zone sûre, sonde du portrait.

Résultat : **3 253 réussis, 0 échoué** (3 238 avant, plus les 15 du nouveau fichier). Trois graines (`TEST_SEED` 3, 7, 11) : vert.

## 3. Mesures

### Mémoire au chargement

`python3 tests/run_tests.py --memoire`, en Ko, Lua, client français.

| | avant | après |
|---|---|---|
| Ready2Quest, chargement | 1 943,7 | 1 974,9 |
| Après connexion (R2Q seul) | 31,2 | 57,6 |

Au chargement, +31 Ko : le code ajouté (`Core.lua` +9 Ko, 1 à 4 Ko par module), plus le bruit de la table des chaînes déjà signalé en 2.8.1 (`Buffs.lua` +10, `Merchant.lua` −10). Après connexion, +26 Ko : les noms des 456 boutons des barres, gardés par les liserés (`ButtonNames`, mesuré : 30,8 Ko sans eux). C'est un choix : 27 Ko gardés une fois contre autant de déchets à **chaque** passage (chaque posture, chaque page de barre).

### Allocations et temps à l'exécution

Micro-mesures hors jeu (lupa, `collectgarbage("count")` ramasse-miettes arrêté, `os.clock`). L'ancien chemin est rejoué à côté du nouveau, dans le même état. Les chiffres valent pour la comparaison, pas comme mesures absolues du client.

| Chemin | avant | après |
|---|---|---|
| Liserés en combat, 120 sorts, 36 cases, 50 passages | 1 859 Ko, 24 ms | 2 Ko, 8 ms |
| `UI_ERROR_MESSAGE` répété, 1 000 messages | 94 Ko, 3,6 ms | 0 Ko, 0,9 ms |
| Marques d'aggro, 10 barres, 200 passages | 688 Ko, 18 ms | 250 Ko, 16 ms (*) |
| `Call` de QuestReward, 1 000 appels | 125 Ko | 0 Ko |
| Champ `.unit` de la sonde du portrait, 1 000 lectures | 47 Ko | 0 Ko |
| `IsCurrentZoneSafe` hors zone sûre, 1 000 appels | ≈ 62 Ko (la liste des signaux) | 0,1 Ko |

(*) Les 250 Ko restants viennent de la maquette (`SetVertexColor` y range une table neuve). Dans le client, ce passage n'alloue plus rien côté addon.

Liserés hors combat (livre relu à chaque fois, comme avant) : 974 Ko pour 50 passages au lieu de ≈ 1 860 (les noms des boutons ne sont plus refaits).

Non chiffrés hors jeu, mais retirés du Lua (le client ne les envoie plus) :
- tout événement d'un module coupé ;
- butin, argent et XP hors voyage ;
- objets chargés hors écran de récompense ;
- `UNIT_STATS` hors série d'équipement ;
- mouvements des sacs fenêtres fermées ;
- clic global sans raccourci ;
- en combat : barres de nom, touches, objets et horloge de l'aggro, `UNIT_AURA` du camp.

## 4. Volontairement pas fait

- **`UNIT_AURA` du cœur en combat** : il dit l'arrivée au camp et le départ du camp (`Evaluate("camp")`). Le différer à la fin du combat décalerait d'autant l'alerte de sortie (le délai repartirait à la fin du combat). Il nourrit aussi l'apprentissage des buffs (déjà espacé à 2 s).
- **Portes d'instance** : rien de ce qui reste abonné n'est inutile en instance (voir plus haut). `Dungeon.lua` était hors champ.
- **Sonde du portrait coupée avec son module** : elle sort au premier test (10 Hz) ; plusieurs tests écrivent le réglage directement, sans synchro. Gain faible, risque de tests trompés.
- **Mort (`Death.lua`)** : événements rares, horloge à 1 s qui sort au premier test.
- **Favoris : `BAG_UPDATE_DELAYED` en combat** : il ne fait que noter « à refaire ». Le couper obligerait à tout refaire à chaque fin de combat.
- **`FavoritesRefresh` sans fermeture par cadre de sacs** : quelques fermetures par passage, et un risque de réentrée (`hooksecurefunc` sur `ContainerFrame_Update`).
- **Livre de sorts gardé hors combat** : les tests changent le livre sans événement, et `SPELLS_CHANGED` n'a pas été vérifié en jeu sur Forever. En combat, le livre ne peut pas changer : c'est là que le gain compte.
- **`Checks.lua`** (évaluation du check) : hors champ. `EvaluateBuffs` (`Buffs.lua`), qu'il appelle, a perdu sa fermeture par buff.
- **Clé de personnage gardée** (`CharKey`, chaque buff vu) : même raison que la première passe (la maquette change de personnage en cours de test).
- **Infobulle d'objet (`RewardItemUpgradeLine`)** : poids, fiches des pièces portées et statistiques refaits à chaque survol. Un cache demanderait de suivre spé, forme et équipement ; seul le coût de `Call` a été retiré.

## 5. Risques

- **Un réabonnement en retard** : un chemin de réglage oublié serait rattrapé par le filet, en 10 s au plus. Les chemins connus (commande, réglages, combat, entrée en jeu, états des modules) réabonnent tout de suite, et chacun a son test.
- **Aggro après le combat** : les barres apparues en combat ne sont plus suivies par événement. À la sortie, elles sont relues par `C_NamePlate.GetNamePlates`. Si cette API manquait sur Forever, ces barres n'auraient de marque qu'à leur prochaine apparition. Le code d'avant comptait déjà sur elle après un `/reload`.
- **Combat** : le drapeau suit `PLAYER_REGEN_*`. Un `PLAYER_REGEN_ENABLED` perdu laisserait l'aggro fermée jusqu'au filet (10 s), qui relit `InCombatLockdown` et `UnitAffectingCombat`.
- **Rangs de sorts en combat** : si un rang pouvait s'apprendre en combat sans `SPELLS_CHANGED` ni `LEARNED_SPELL_IN_TAB`, les liserés ne le verraient qu'à la fin du combat.
- **Rythme** : coupé au niveau maximum. La porte se relit au plus tard au filet après le passage au niveau max (le premier événement l'oubliait déjà).
- **Récompense** : si l'interface ne renvoie jamais `QUEST_FINISHED`, les objets reçus restent écoutés, comme avant.
- **`UNIT_AURA` / `UNIT_STATS` réabonnés** : par `ns.RegisterGameEvent`, donc pour le joueur seulement, avec le repli de la première passe.
- **Mémoire** : +26 Ko après connexion (noms des boutons), voir plus haut.

## 6. À vérifier en jeu

1. `/r2q diag` :
   - aucune erreur ;
   - en ville, hors voyage : « abonnements en pause : expedition, reward, gear, bagspace:bags, lootroom:bags » (plus tout module coupé) ;
   - en combat : `aggro`, `camp:aura` et « (en combat) » en plus.
2. **Combat de groupe** :
   - marques d'aggro cachées en combat, revenues dès la sortie, y compris sur les monstres apparus pendant le combat ;
   - Maj tenue après le combat.
3. **`/reload` en combat**, puis fin du combat : marques d'aggro et `/r2q diag` sans « (en combat) ».
4. **Réglages** : couper puis rallumer chaque module (interrupteur et `/r2q module <id> off|on`). Le module repart aussitôt :
   - marques d'aggro ;
   - décompte du camp ;
   - carte du rythme ;
   - liserés des rangs (partis à l'arrêt, revenus au rallumage) ;
   - Sac plein et Place au butin.
5. **Voyage** : départ, butin (solo et groupe), argent, XP, une mort, retour. Le bilan compte tout.
6. **Récompense de quête** avec un objet pas encore en cache : le conseil arrive quand l'objet est chargé.
7. **Changement d'équipement** (une pièce, puis un ensemble) : le résumé de stuff s'affiche (relectures `UNIT_STATS`).
8. **Sacs pleins** :
   - le bandeau suit les sacs (vendre ou jeter le ferme) ;
   - Place au butin : jeter puis ramasser.
9. **Rangs de sorts** :
   - guerrier, druide ou voleur : postures ou formes en combat, les liserés restent justes ;
   - un rang appris chez l'entraîneur : annonce et liserés.
10. **Favoris** : raccourci « désactivé », puis Alt+clic remis, Alt+clic fonctionne.
11. **Icône de rapport** : pulsation 8 s, puis atténuée et immobile une minute ; mode « Déplacer les cadres » pendant l'atténuation, puis fin du mode : l'icône redevient atténuée.
12. **Camp** : décompte qui avance en combat au camp, et cadre rangé quand le module est coupé.
