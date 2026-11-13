# Audit de performance — QuestCompanion 2.9.1 / Ready2Quest 1.30.1 (2026-11-09)

Branche `AlexisLapasset/audit-perf`, partie de `main` (c329f91). Objectif : moins de travail et moins de déchets (ramasse-miettes) à l'exécution, surtout en combat, sans rien changer à l'écran ni dans les sauvegardes (`QuestCompanionDB` / `Ready2QuestDB` : aucune clé ajoutée ni retirée).

La passe 2.8.1 avait déjà traité la mémoire au chargement (zones en chaînes compactes, une seule langue, répliques à la demande ; voir `docs/TECHNIQUE.md`). Cette passe vise le **processeur** et les **allocations** des chemins fréquents : événements de combat et d'unité, `OnUpdate`, rafraîchissements du carnet.

## 1. Diagnostic

Sur l'architecture, rien d'alarmant : un cadre d'événements par module, des abonnements protégés (`pcall(frame.RegisterEvent, …)`), des gestionnaires sous `pcall`, des `OnUpdate` espacés par `ns.Throttle` ou portés par des cadres cachés. Les widgets sont mis en commun et réutilisés partout (aucune fuite de cadres, de textures ou de textes trouvée dans les 15 fichiers d'interface). Le journal de combat est déjà filtré (sous-événement d'abord, `PARTY_KILL` / `UNIT_DIED` sur Forever).

Points critiques retenus, du plus coûteux au moins coûteux :

| # | Où | Problème | Fréquence |
|---|---|---|---|
| 1 | `UNIT_AURA` (QC compagnon, hauts faits ; R2Q cœur, camp), `UNIT_STATS` (R2Q) | Abonnés pour **toutes** les unités alors que seuls les messages du joueur servent : cible, groupe, raid et chaque barre de vie arrivent jusqu'au Lua (recherche, `ModuleOn`, `pcall`) | des centaines par seconde en combat |
| 2 | `ParseCombatXP`, `ParseSelfLoot` (socle), `GatheringParseLoot` (QC) | Motifs Lua reconstruits **à chaque message** (≈ 7 `gsub` par format, tables, fermeture) ; table de captures par motif essayé | chaque ligne de butin (celles du groupe comprises) et d'XP |
| 3 | `ns.AsciiLower` (socle) | Une fermeture neuve et un `string.char` par lettre à chaque appel | chaque aura lue (compagnon, buffs), chaque nom comparé |
| 4 | Conseils du compagnon (`Advice.lua`) | Examen complet (sacs, quêtes, durabilité, lieux) à chaque `QUEST_LOG_UPDATE` / `BAG_UPDATE_DELAYED` | plusieurs fois par butin ou objectif, en rafales |
| 5 | Carnet, molette (`ScrollJournal`) | Chaque cran recalcule toute la page : Progression parcourt toutes les zones du jeu (2 à 3 `C_Map.GetMapInfo` par zone, complétion de chaque zone connue), Ménagerie tout le catalogue, Hauts faits la progression de chaque haut fait, Guide remesure chaque bloc | chaque cran |
| 6 | Carte (`MapChain`, `KnownHub`, socle) | Chaîne de cartes refaite (table + `GetMapInfo` par niveau) toutes les 1,5 s sur une carte à lieux repérés, et à chaque créature vue (`JournalZone`) | 1,5 s, plus chaque barre de vie / survol |
| 7 | Page Progression → `ZoneLevelRange` | Lecture directe `ns.ZONE_CREATURES[zone]` : construit et **garde** les créatures de presque toutes les zones, défaisant le chargement paresseux de 1.6.1 | à l'ouverture de la page |
| 8 | Bestiaire (`BestiarySeeUnit`) | ~10 appels d'API protégés pour une créature déjà vue il y a une seconde (barre de vie qui reparaît, survol répété) | chaque barre de vie / survol |
| 9 | Divers `OnUpdate` | Bandeaux de guilde : table neuve 5 fois par seconde même file vide ; cadre prisme : table par image ; aggro du compagnon : `Hide()` à chaque image, concaténation par barre | chaque image |
| 10 | Robustesse | `OnUpdate` non protégés (bandeau du carnet, choix au filet, filet) : une erreur s'y répéterait à chaque image ; liste d'erreurs sans borne ; saisie de raccourci qui garde le clavier en combat | rare, mais en boucle si ça arrive |

## 2. Ce qui a été changé, fichier par fichier

### Socle (`Ready2Quest/Libs/Socle`, recopié dans QC par `tools/sync_socle.py`)

- **`Compat.lua`**
  - `ns.PLAYER_UNIT_EVENTS` (`UNIT_AURA`, `UNIT_STATS`) et `ns.RegisterGameEvent(frame, event)` : ces événements passent par `RegisterUnitEvent(event, "player")` ; repli sur `RegisterEvent` sans cette API (les gestionnaires gardent leur test `unit == "player"`). `ns.RegisterHandlers` s'en sert.
  - `ns.GroupFlags` : jetons d'unité faits une fois, plus de fermeture ni de concaténation par appel.
- **`Base.lua`**
  - `ns.MemoGlobals(names, build)` : résultat gardé tant que les globales du client nommées gardent leur valeur.
  - `RecordError` est bornée à `ns.ERRORS_MAX` (50) erreurs distinctes ; les suivantes sont comptées dans `ns.errorsDropped`, sans impression.
- **`Strings.lua`** : `AsciiLower` remplace par une table (`gsub("[A-Z]", ASCII_LOWER)`) ; résultat identique.
- **`World.lua`**
  - `MapChain` est gardée par carte, seulement quand elle est complète (une carte sans infos sera relue). La chaîne est partagée : ne pas la modifier.
  - `KnownHub` lit la sous-zone puis la zone sans table temporaire.
  - `ParseCombatXP` et `LootPatterns` passent par `MemoGlobals` ; la capture de l'XP est prise par son rang (`select`), sans table.

### Ready2Quest

- **`Core.lua`**
  - `RegisterEvents` passe par `ns.RegisterGameEvent` (`UNIT_AURA` du joueur seulement).
  - `Evaluate` garde `lastSafePlace` quand le lieu n'a pas changé (une table de moins toutes les 1,5 s en ville).
- **`Buffs.lua`**
  - `BuffFamily` est gardée par nom (bornée à 512).
  - La table de travail de `ScanBuffs` est réutilisée (`ns.buffScanKnown`).
- **`Camp.lua`**
  - `UNIT_AURA` du joueur seulement.
  - Le texte du décompte n'est reposé que s'il change (4 Hz au camp).
- **`Stats.lua`** : `UNIT_STATS` du joueur seulement.

### QuestCompanion

- **`Companion.lua`** : noms d'auras en minuscules gardés (`LowerName`, borné à 512). Le cadre est passé à `RegisterUnitEvent` via `ns.RegisterHandlers`.
- **`CompanionFx.lua`** : jetons `…target` gardés (`TARGET_OF`) ; le cadre rouge n'est caché que s'il est affiché.
- **`Advice.lua`**
  - `BAG_UPDATE_DELAYED`, `UPDATE_INVENTORY_DURABILITY`, `QUEST_LOG_UPDATE` et `ZONE_CHANGED*` avancent l'examen régulier à `ns.ADVICE_SOON` (0,3 s) : une rafale donne un seul examen. La fin de combat et les élites vus examinent toujours tout de suite.
  - Les élites déjà vus sont bornés (`ns.ADVICE_ELITES_MAX` = 500).
- **`Gathering.lua`** : motifs de butin gardés (`ns.MemoGlobals`).
- **`Journal.lua`**
  - `JournalZone` garde la zone trouvée pour chaque carte et ne relit que son nom.
  - L'`OnUpdate` du bandeau est protégé : sur erreur, le bandeau fautif quitte la file et l'erreur est notée.
- **`Bestiary.lua`** : la même créature revue dans les `ns.BESTIARY_RESEE` (2 s) rend sa fiche sans relire nom, famille, classe et niveau.
- **`Shiny.lua`** : barre de vie ajoutée sans brillante en vie : rien à faire. `ShinyPlatesRefresh` relit toutes les barres quand une brillante apparaît.
- **`ZoneQuests.lua`**
  - Plus de tables neuves à chaque `QUEST_LOG_UPDATE` quand elles sont vides.
  - Les titres de quêtes reçus en rafale donnent un seul rafraîchissement du carnet, à l'image suivante (`ns.ZoneQuestsFlush`).
- **`TrainerCard.lua`**
  - Le préfixe d'un message d'addon est testé avant de déballer le reste.
  - `ShowModel` ne recharge pas un modèle déjà affiché depuis l'ouverture de la fiche (`ns.trainerOpened`) ; avant, chaque rafraîchissement relançait `SetCreature` et son animation sur chaque tuile.
- **`JournalAzeroth.lua`** : l'habillage de la fiche ne fait rien quand la fiche est fermée (un changement de titre l'appelait quand même).
- **`JournalWindow.lua`**
  - `ScrollJournal` pose `frame.scrollOnly` le temps du rafraîchissement, et l'efface même sur erreur.
  - Le sous-titre (total des hauts faits) n'est pas recalculé à la molette.
  - Ménagerie : liste, statistiques et filtres sont repris à la molette.
- **`JournalCompletion.lua`** : la liste des zones est reprise à la molette.
- **`JournalFeats.lua`** : totaux, catégories et lignes sont repris à la molette.
- **`JournalGuide.lua`** : blocs, hauteurs mesurées et dernière page sont repris à la molette, dans la même section.
- **`MenagerieCollection.lua`** : pas de contrôle du sceau à la molette.
- **`CompanionChest.lua`** : `ZoneLevelRange` lit les créatures par `ns.ZonePeek` (sans garder la zone construite).
- **`JournalTracker.lua`** : à l'entrée en combat, si le suivi se cache en combat, il se cache sans tout recalculer (coffre, friandises, missions, sceau).
- **`GuildFeats.lua`** : file de bandeaux vide, aucune table allouée.
- **`FeatsCosmetics.lua`**
  - Cadre prisme : `OnUpdate` partagé et quatre côtés lus sans table neuve.
  - Aucun `OnUpdate` en Azeroth sans halo du client.
- **`Bindings.lua`** : à l'entrée en combat, la fenêtre de saisie d'un raccourci se ferme et lâche le clavier.
- **`CaptureBatch.lua`, `CaptureQueue.lua`** : `OnUpdate` du choix au filet et du filet protégés.

### Tests

- **`tests/run_tests.lua`** : la maquette connaît `RegisterUnitEvent` et filtre par unité comme le client (`region.unitFilter`).
- **`tests/modules/performance.lua`** (`[PERF]`, regroupé avec `[OPT]`, `[MEM]` et les raccourcis 2.11.1 ; un contrôle par raccourci) :
  - filtre par unité et repli ;
  - abonnements de R2Q, du camp, des stats et des hauts faits ;
  - `AsciiLower` identique ;
  - `MapChain` gardée, ou relue si elle est incomplète ;
  - `MemoGlobals` reconstruit quand une globale change ;
  - `ParseCombatXP` ;
  - borne des erreurs ;
  - `scrollOnly` posé puis effacé (même sur erreur) ;
  - rafales des conseils.

Résultat : **5 803 réussis, 0 échoué** (5 779 avant, plus 24).

## 3. Mesures

### Mémoire au chargement

Mesure par `python3 tests/run_tests.py --memoire`, en Ko, Lua, client français.

| | avant | après |
|---|---|---|
| QuestCompanion, chargement | 1 827,5 | 1 829,1 |
| Ready2Quest, chargement | 818,5 | 824,7 |
| Après connexion (QC 133 régions + R2Q) | 292,2 | 292,3 |

La mémoire au chargement est stable, comme prévu : cette passe ne vise pas la mémoire résidente. Les quelques Ko en plus viennent du code ajouté et des petites tables faites une fois (jetons d'unité, table A-Z, caches vides) ; l'écart de R2Q porte aussi le bruit de la table des chaînes signalé en 2.8.1.

### Allocations et temps à l'exécution

Micro-mesures hors jeu (lupa, `collectgarbage("count")` avec le ramasse-miettes arrêté). Les ordres de grandeur valent pour la comparaison, pas comme mesures absolues du client.

| Chemin | avant | après |
|---|---|---|
| `AsciiLower`, 10 000 noms d'auras | 391 Ko, 20 ms | 0,3 Ko, 13 ms (0,6 ms par le cache du compagnon) |
| `ParseCombatXP`, 1 000 messages | 2 900 Ko, 20 ms | 0,1 Ko, 1,1 ms |
| `GroupFlags` (GUID hors groupe), 1 000 appels | 96 Ko, 27 ms | 1,8 Ko, 22 ms |

Non chiffrés hors jeu, mais retirés du Lua :
- les `UNIT_AURA` et `UNIT_STATS` des autres unités, filtrés par le client ;
- l'examen des conseils à chaque événement de la rafale ;
- le recalcul complet du carnet à chaque cran de molette ;
- la relecture d'une créature revue dans les 2 s.

## 4. Volontairement pas fait

- **Regrouper les événements de zone du suivi** (`Moved`, `JournalTracker.lua`) : essayé, puis retiré. Au même endroit, un rafraîchissement doit relire des données qui ont changé (montée de niveau, objectif masqué) ; trois tests `[TRK]` l'ont montré.
- **Garder `MapInfo`** : la maquette de test réutilise des numéros de carte avec d'autres noms. En jeu, les noms ne changent pas, mais le gain restant est faible depuis que `MapChain` et `JournalZone` sont gardées.
- **Enveloppes de l'habillage Azeroth** du carnet (`CaptureRun` recrée une dizaine de fermetures par rafraîchissement, `Recolor` parcourt toutes les pages) : risque moyen sur les contrastes mesurés (2.8.2), à reprendre avec une vérification visuelle.
- **Mémoriser `ZoneCompletion` le temps d'un passage du suivi** : il faudrait toucher à l'ordre des quatre enveloppes de `RefreshJournalTracker` (coffre, friandises, missions, sceau).
- **Statistiques des catégories de hauts faits en un seul passage** (`FeatCategoryStats` × catégories) et **liste des zones de la Ménagerie gardée** : gains faibles depuis que la molette ne les refait plus.
- **Clé de personnage gardée** (`CharKey`) : la maquette change de personnage en cours de test.
- **Pollers convertis en `C_Timer.NewTicker`** (Advice, Group, Daily, Journal) : quelques appels Lua par image au total, gain marginal pour un changement de mécanique.
- **`GLOBAL_MOUSE_DOWN` du choix au filet abonné seulement quand il est affiché** : la maquette ne joue pas `OnShow`, et le gestionnaire sort déjà au premier test.
- **Aggro du compagnon coupé hors combat** : un monstre peut te cibler avant que tu sois marqué en combat ; le clignotement pourrait changer.

## 5. Risques

- **`RegisterUnitEvent`** : si le client Forever refusait l'appel, le repli `RegisterEvent` prend le relais (`pcall`). Un futur gestionnaire de `UNIT_AURA` ou `UNIT_STATS` qui voudrait d'autres unités que le joueur devra s'abonner autrement (c'est écrit au-dessus de `ns.PLAYER_UNIT_EVENTS`).
- **Conseils** : une bulle due à un événement (sacs, durabilité, quête) peut arriver jusqu'à 0,3 s plus tard.
- **Bestiaire** : pendant 2 s après une lecture, le niveau ou la classe d'une même créature ne sont pas relus. C'est sans effet pour un monstre, qui ne change pas de niveau en 2 s.
- **Fiche de dresseur** : les modèles ne sont plus rechargés à chaque rafraîchissement, seulement à l'ouverture et quand la créature change. Si un modèle apparaissait vide après un changement de style à chaud, c'est ici qu'il faudrait regarder.
- **Molette** : la page reprend la liste de son dernier rafraîchissement complet. Tout événement de données refait un rafraîchissement complet, qui remplace cette liste.
- **Saisie d'un raccourci** : elle se ferme à l'entrée en combat. C'est le seul changement visible, voulu : avant, elle avalait les touches du combat.

## 6. À vérifier en jeu

1. `/r2q diag` et `/qc diag` : aucune erreur.
2. **Combat de groupe ou plusieurs monstres :**
   - repas et boisson reconnus par le compagnon (`UNIT_AURA` du joueur) ;
   - monture et hauts faits de monture ;
   - décompte du camp ;
   - buffs appris par R2Q ;
   - toast de changement d'équipement (`UNIT_STATS`).
3. **XP et butin :**
   - lignes « vous gagnez N points d'expérience » comptées (rythme R2Q, compagnon, bestiaire) ;
   - butin en solo et en groupe (récoltes, expédition R2Q).
4. **Carnet ouvert :**
   - molette sur Progression, Ménagerie, Hauts faits et Guide (fluide, bonnes lignes) ;
   - changement de filtre ou de zone puis molette ;
   - titres de quêtes qui arrivent sur la page Progression.
5. **Fiche de dresseur :**
   - ouverture, changement de vitrine et de titre ;
   - les modèles 3D restent affichés et ne relancent pas leur animation ;
   - `/qc style` à chaud.
6. **Conseils du compagnon :** sacs pleins, durabilité basse, quête à rendre (bulle à peine retardée).
7. **Brillante :** repère sur la barre de vie quand une brillante apparaît à l'écran.
8. **Raccourci :** saisie en cours puis entrée en combat ; la fenêtre se ferme et les touches répondent.

---

# Passe 2 (3.1.0) — QuestCompanion et socle (2026-11-13)

Partie de `main` (00e95ab, QC 3.0.2). Même règle qu'à la première passe : rien ne change à l'écran ni dans `QuestCompanionDB` (aucune clé ajoutée ni retirée). Fichiers de la capture laissés de côté (réécriture en cours ailleurs) : `Capture.lua`, `CaptureQueue.lua`, `CaptureStage.lua`, `CaptureBatch.lua`, `CaptureSkip.lua`, `CaptureSpecimens.lua`, `Bindings.lua`, le `.toc`. Ready2Quest n'est pas migré : il reçoit seulement le nouveau code du socle, sans s'en servir.

## 1. Diagnostic

- **Un cadre d'événements par module.** Après connexion, 20 cadres de QC étaient abonnés à des événements. Un même événement arrivait du client vers le Lua autant de fois qu'il avait de cadres abonnés :
  - `NAME_PLATE_UNIT_ADDED` : 5 fois (bestiaire, carnet, conseils, brillantes, effets) ;
  - `ZONE_CHANGED` : 5 fois ; `ZONE_CHANGED_NEW_AREA` : 6 ;
  - `PLAYER_TARGET_CHANGED` : 4 ; `UPDATE_MOUSEOVER_UNIT` : 3 ;
  - `PLAYER_REGEN_ENABLED` : 8 ; `PLAYER_ENTERING_WORLD` : 8 ; `QUEST_TURNED_IN` : 5.
- **Écoute permanente, même inutile :**
  - compagnon coupé dans les réglages : tous ses événements arrivaient encore, puis sortaient au premier test ;
  - menu du compagnon (Maj + clic droit) : `GLOBAL_MOUSE_DOWN` (chaque clic, partout) écouté dès sa première ouverture, et pour toute la session ;
  - conseils : cible, survol et barres de vie écoutés en combat, où `AdviceSeeUnit` sort aussitôt (après deux appels protégés au client).
- **Déchets sur les chemins fréquents :**
  - `UNIT_AURA` du joueur : jusqu'à 40 auras relues (une table neuve par aura sur le moteur récent) à chaque message, même quand rien n'a été ajouté ni retiré (durée ou charges rafraîchies, l'essentiel en combat) ;
  - effets du compagnon (`CompanionEffects`, lu à chaque infobulle d'unité et à chaque relevé des envies) : une table littérale et une clé de cache refaite par `table.concat` à chaque lecture ;
  - fermetures neuves à chaque appel : tirage de brillante (chaque barre de vie d'un monstre vu), première victime d'une espèce (`Notify.lua`), friandises et sceau à chaque rafraîchissement du suivi ;
  - petites tables à chaque passage : seuils et « déjà dit » des conseils (toutes les 3 s), dernier relevé du voyage (1 s), liste vide du suivi caché, file de messages du carnet à chaque fin de combat ;
  - aura scintillante (toutes les 1,5 s) : la liste de toutes les apparences, captures comprises, refaite avant même de regarder l'ornement.

## 2. Ce qui a été changé, fichier par fichier

### Socle (`Ready2Quest/Libs/Socle`, recopié par `tools/sync_socle.py`)

- **`Compat.lua` : un cadre d'événements par addon.** Il est créé au premier abonné et tient une liste d'abonnés par événement :
  - l'événement est enregistré auprès du client au premier abonné actif et retiré au dernier ; `UNIT_AURA` et `UNIT_STATS` passent toujours par `ns.RegisterGameEvent` (joueur seulement) ;
  - les abonnés sont appelés dans l'ordre d'abonnement, chacun sous `pcall`. Une erreur est notée sous « qui:ÉVÉNEMENT », ou sous le nom donné à l'abonnement (« shiny:plate », « daily:quest »…, comme avant) ;
  - se désabonner pendant un appel ne casse pas la boucle (entrée marquée, liste compactée à la fin) ;
  - API :
    - `ns.On(événement, qui, fn[, où])`, `ns.Off`, `ns.Unlisten(qui)` ;
    - `ns.Listen(qui, handlers[, porte[, nom]])` : comme `ns.RegisterHandlers`, journal de combat s'il est ouvert, sinon `PARTY_KILL` / `UNIT_DIED`, jamais les deux ;
    - `ns.EventGate(qui, porte)` et `ns.EventsResync()` : une porte fermée (module coupé) retire l'écoute de `qui`. Tant qu'une porte est fermée, une tâche d'horloge `events:gates` la relit chaque seconde (`ns.EVENT_GATE_POLL`) ; aucune tâche quand tout est ouvert ;
    - `ns.EventHold(qui, oui)` : écoute mise en attente puis reprise, sans perdre son rang dans l'ordre d'appel ;
    - `ns.EventDeliver(qui, événement, …)` (tests) et `ns.Listening(événement[, qui])` ;
    - `ns.eventHub` : le cadre lui-même.

### QuestCompanion

- **Cadre commun.** Ces modules passent au cadre commun, abonnés dans l'ordre de chargement comme leurs cadres l'étaient :
  - `Core`, `Companion`, `Advice`, `Group`, `Journal`, `JournalTracker`, `Bestiary`, `Gathering`, `ZoneQuests` ;
  - les barres de vie de `Shiny` et de `CompanionEffects` ;
  - `Daily`, `Notify`, `LiveRares`, `TrainerCard`, `FeatsData` (toutes les tables `ns.FeatListen`), `CaptureTrades`, `GuidedTour`.

  Les cadres qui ne servaient plus qu'à des événements sont supprimés. Restent ceux qui portent un `OnUpdate` : balancement du compagnon (`ns.companionEvents`), rafraîchissement regroupé des quêtes (`ns.zoneQuestsEventFrame`), relevé des visites guidées.
- **`Core.lua`** : les portes sont relues :
  - à la lecture de la sauvegarde (`OnAddonLoaded`) ;
  - à chaque interrupteur des réglages (`ApplyDisplayOptions`) ;
  - à « /qc module … » (`OnModuleToggled`, nouveau dans QC) ;
  - à « /qc reset ».
- **Portes (module coupé : plus d'écoute).** Elles ne sont posées que là où chaque gestionnaire ne fait déjà rien module coupé :
  - le compagnon, dont le gestionnaire testait déjà `ModuleOn` en tête ;
  - la récolte (`CHAT_MSG_LOOT`, `SKILL_LINES_CHANGED`) ;
  - le groupe (`GroupEvaluate` sort d'abord) ;
  - les rares en direct (alerte coupée).
- **`Advice.lua`** :
  - cible, survol et barres de vie sont mis en attente de `PLAYER_REGEN_DISABLED` à `PLAYER_REGEN_ENABLED` ;
  - seuils dans une table gardée ;
  - « déjà dit » remis à neuf seulement s'il contient quelque chose.
- **`Companion.lua`** :
  - `UNIT_AURA` : quand le client dit que seules des auras ont été rafraîchies (`isFullUpdate == false`, rien d'ajouté ni de retiré, au moins une mise à jour), rien n'est relu (`ns.CompanionAuraRefreshOnly`). Sans ces infos, ou si elles sont illisibles (secrètes), tout est relu comme avant ;
  - menu : `GLOBAL_MOUSE_DOWN` posé par `CompanionMenuShow`, retiré par `CompanionMenuHide`, par `OnHide`, et par le premier clic reçu menu caché.
- **`CompanionEffects.lua`** : liste des envies faite une fois ; clé du cache comparée champ par champ (mêmes champs qu'avant).
- **`Shiny.lua`** :
  - tirage de brillante : fonction faite une fois (`ShinySee`) ;
  - aura scintillante : l'ornement d'abord, l'apparence seulement s'il ne suffit pas.
- **`Notify.lua`** (`FirstKill`), **`Treats.lua`** (`TreatsCheck`), **`MenagerieCollection.lua`** (`SealCheck`) : fonctions faites une fois au lieu d'une fermeture par appel.
- **`JournalTracker.lua`** : suivi caché (combat, module coupé), une liste vide partagée.
- **`Journal.lua`** : la file des messages n'est remplacée que si elle a servi.
- **`CompanionTravel.lua`** : le dernier relevé est réécrit sur place.
- **`Group.lua`** : jetons `party1..4` faits une fois.
- **`Bestiary.lua`** : `ns.BESTIARY_HANDLERS` exposé (tests, comme `ns.ADVICE_HANDLERS`).

### Tests

- **`tests/modules/performance.lua`**, `[PERF2]` (6 contrôles) :
  - cadre commun : ordre, erreurs isolées, désabonnement pendant l'appel, attente avec rang gardé, événement refusé par le client, `UNIT_AURA` du joueur seulement ;
  - un seul cadre de QC reçoit chaque événement fréquent ;
  - compagnon coupé puis rallumé, par les réglages, par la commande, ou par la sauvegarde écrite directement (relecture d'une seconde) ;
  - conseils en attente en combat ;
  - `GLOBAL_MOUSE_DOWN` du menu ;
  - `UNIT_AURA` rafraîchie sans relecture.
- **Tests adaptés aux cadres retirés** :
  - `bestiary.lua` (gestionnaires appelés directement) ;
  - `shiny.lua`, `companion_effects.lua` (`ns.EventDeliver`) ;
  - `live_api.lua`, `menagerie_journal.lua` (`ns.Listening`) ;
  - `socle.lua` (le cadre commun n'a pas d'`OnUpdate`).

Résultat : **3 244 réussis, 0 échoué** (3 238 avant, plus 6). Aussi vert avec `TEST_SEED=7`.

## 3. Mesures

Hors jeu (maquette, lupa, ramasse-miettes arrêté, 1 000 appels), même méthode qu'à la première passe. Les cadres sont comptés après connexion.

| | avant | après |
|---|---|---|
| Cadres de QC abonnés à des événements | 20 | 4 (le cadre commun, deux `PLAYER_LOGIN` du socle, les raccourcis) |
| Appels client → Lua par `NAME_PLATE_UNIT_ADDED` / `ZONE_CHANGED` / `PLAYER_TARGET_CHANGED` | 5 / 5 / 4 | 1 / 1 / 1 |
| `CompanionEffects` ×1 000 | 416 Ko | 104 Ko |
| `AdviceThresholds` ×1 000 | 219 Ko | 0,2 Ko |
| `AdviceNewTrip` ×1 000 (en ville) | 63 Ko | 0,4 Ko |
| `RefreshJournalTracker` caché en combat ×1 000 | 2 454 Ko | 2 219 Ko (le reste : `ZoneCompletion`, voir 4) |
| `NAME_PLATE_UNIT_ADDED` ×1 000 (côté Lua seulement) | 1,7 Ko, 17,7 ms | 1,3 Ko, 16,2 ms |

Non chiffrés hors jeu :
- les appels du client vers le Lua épargnés : un par cadre retiré et par événement ;
- les auras relues : la maquette n'en pose pas ; le contrôle `[PERF2]` vérifie qu'aucune lecture n'a lieu ;
- les clics hors du menu ;
- les événements d'un compagnon coupé.

Mémoire au chargement (`--memoire`, Ko) :

| | avant | après |
|---|---|---|
| QuestCompanion | 5 569 | 5 489 |
| Ready2Quest | 1 944 | 1 958 |
| Après connexion | 306,0 | 306,2 |

Dans la maquette, un cadre est une table Lua : la baisse de QC vient surtout des 16 cadres en moins, ce qui n'est pas représentatif du client. Ready2Quest gagne le code du cadre commun (compilé dans son socle) et le bruit déjà signalé en 2.8.1.

## 4. Volontairement pas fait

- **`ZoneCompletion` gardé le temps d'un passage du suivi.** Mesuré : environ 1 Ko et 40 µs par appel, deux appels par rafraîchissement (coffre, friandises), même suivi caché. Le blocage de la première passe tient toujours :
  - un passage peut changer des données en route (coffre, friandise, tampon et son rappel `STAMP`) ;
  - la garde devrait envelopper la dernière enveloppe chargée (`Daily.lua`) ;
  - il faudrait prouver qu'aucune enveloppe ne change une part de zone.
- **Gestionnaires qui travaillent même module coupé : pas de porte.**
  - carnet : `JournalCombat` oublie les rares morts, `JournalFlush` vide la file ;
  - bestiaire : statistiques de `/qc diag` ;
  - suivi : drapeau de combat lu par les quêtes de zone ;
  - quêtes de zone : le cache est oublié à chaque `QUEST_LOG_UPDATE` ;
  - barres de vie des brillantes et des effets : leurs caches sont vidés.
- **Journal de combat, `PARTY_KILL` et `UNIT_DIED` du carnet écoutés seulement avec un rare repéré.** Les tests remplacent `ns.journalRares` directement, et le bestiaire écoute de toute façon les mêmes événements. Le gain se réduirait à un `next()`.
- **`CHAT_MSG_SYSTEM` des échanges seulement pendant un échange.** La machine des échanges est voisine de la capture en cours de réécriture ; l'événement est seulement passé au cadre commun.
- **Cadres de la capture et des raccourcis** (fichiers interdits pour cette passe). Leurs `PLAYER_REGEN_DISABLED` et le `GLOBAL_MOUSE_DOWN` du choix au filet restent sur leurs cadres.
- **Cadres du socle** (`PLAYER_LOGIN` des réglages et de la minicarte, `ADDON_LOADED` de la sauvegarde) : une fois par session, aucun gain.
- **Ready2Quest sur le cadre commun** : hors du périmètre ; l'API est prête dans son socle.
- **Aggro du compagnon sans `C_NamePlate.GetNamePlates`** (une table du client toutes les 0,5 s). Il faudrait tenir la liste des barres par `NAME_PLATE_UNIT_*`, ce qui change la façon de compter (les tests posent les barres sans événement). Raison de la première passe toujours valable pour le reste.
- **Tables rendues par `ActiveOf` (effets) et par `GroupMembers`** : les appelants peuvent les garder.
- **`QUEST_DATA_LOAD_RESULT` seulement quand une quête est demandée** : événement rare.

## 5. Risques

- **Ordre des gestionnaires :**
  - entre modules de QC, l'ordre d'abonnement reste l'ordre de chargement, donc le même qu'avant ;
  - un abonné qui se réabonne (`ns.Off` puis `ns.On`) passe en dernier, comme un cadre qui se réabonnait. La mise en attente (`EventHold`) et les portes gardent le rang ;
  - les cadres restés à part (socle, raccourcis, fenêtres de la capture) étaient déjà créés avant ou après tous les modules : leur place ne change pas.
- **Erreurs** : le cadre du cœur (minicarte à l'entrée en jeu) et celui des visites guidées n'étaient pas protégés. Une erreur y est désormais notée (`/qc diag`) au lieu de remonter au client.
- **Portes :**
  - un réglage changé par les réglages, la commande, `/qc reset` ou à la connexion rouvre l'écoute tout de suite ;
  - par un autre chemin, l'écoute rouvre au plus tard une seconde après. Aucun autre chemin connu en jeu.
- **`UNIT_AURA`** : on suppose que Forever range une aura nouvelle dans `addedAuras`, comme le client moderne. Si une aura de repas n'y était pas, le « Miam » arriverait au prochain message complet. C'est à vérifier en jeu.
- **Conseils en combat** : rien n'est écouté entre l'entrée et la sortie de combat ; avant, les gestionnaires sortaient au premier test. Après un `/reload` en combat, l'écoute reste ouverte et les gestionnaires testent toujours le combat.
- **Menu du compagnon** : seul `CompanionMenuShow` l'ouvre. Un autre chemin qui l'afficherait directement ne le refermerait pas au clic ailleurs (aucun dans le code).
- **Hauts faits** : avec le journal de combat ouvert (pas sur Forever), une table qui écoute le journal ne reçoit plus le `PARTY_KILL` enregistré pour une autre table. C'était un double compte possible sur l'ancien cadre partagé.

## 6. À vérifier en jeu

1. `/qc diag` : aucune erreur.
2. **Entrée en jeu :** le bouton de minicarte apparaît ; la visite guidée de connexion, si elle est due, démarre.
3. **Repas et boisson en combat prolongé :**
   - « Miam » / « Glou glou » à la première bouchée ;
   - « bien nourri » compté ;
   - camp reconnu (`UNIT_AURA` filtré).
4. **Compagnon coupé puis rallumé** (réglages, puis `/qc module companion off|on`) :
   - rien ne parle coupé ;
   - tout repart rallumé : butin, quête rendue, groupe.
5. **Menu du compagnon** (Maj + clic droit) : un clic ailleurs le ferme ; un clic dedans ou sur le compagnon le garde.
6. **Conseils :** un élite ou un rare survolé hors combat donne la bulle ; rien en combat ; de nouveau après le combat.
7. **Barres de vie :** brillante et patte de repérage toujours posées ; bestiaire et carnet qui retiennent les rares.
8. **Échanges et fiche de dresseur :** un échange complet ; une fiche reçue d'un joueur du groupe.
9. **Rares en direct :** alerte coupée puis remise dans les réglages ; l'alerte revient.
