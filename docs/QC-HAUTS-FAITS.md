# QuestCompanion — Hauts faits (conception)

Document de conception. Base : branche `qc-sans-souvenirs` (QC 2.6.0 non publiée). Version cible : QC 2.7.0. Les questions ouvertes sont tranchées (§5.1 « Décisions ») ; le **lot A** (moteur, migration, page, bandeau) est fait dans `Feats.lua`, `FeatsData.lua` et `JournalFeats.lua` (voir `docs/TECHNIQUE.md`).

WoW Forever n'a pas d'interface de hauts faits. QuestCompanion apporte la sienne : un **moteur de hauts faits** qui relie la ménagerie (captures, brillantes, sceaux) et le jeu lui-même (niveaux, or, donjons, raids, métiers, quêtes, réputations…), avec des **points**, des **titres** affichés sur la fiche de dresseur et des **récompenses** (cosmétiques, aides de capture). Les tampons actuels du carnet deviennent des hauts faits, sans rien perdre.

Légende de faisabilité sur Forever :
- ✅ **sûr** : donnée déjà lue par QC, ou API déjà employée dans le dépôt ;
- ⚠️ **à vérifier en jeu** : API présente sur le moteur récent mais pas encore éprouvée sur Forever. Pour `GetStatistic`, « valeur à confirmer en jeu » : seule la statistique 107 a été testée (elle rend `780`) ;
- ❌ **pas détectable** : exclu du catalogue (liste en §2.12).

Ce que le test en jeu (2026-11-07) a établi :
1. les atlas `ui-achievement-*` et `achievement-wood-nineslice-*` existent (le style Azeroth de la 2.5 sert de base visuelle) ;
2. `GetAchievementInfo(62053)` ne rend que l'identifiant, tout le reste vaut `nil` : **les infos natives des hauts faits sont une coquille vide, on ne s'en sert pas** ;
3. `GetStatistic(107)` rend `780` : **les statistiques natives fonctionnent**. Elles deviennent une source de premier rang pour les hauts faits de jeu, et permettent de les attribuer après coup à la connexion à partir des chiffres de toute la vie du personnage.

---

## 1. Principes

### 1.1 Moteur

Trois fichiers neufs, déclarés dans le `.toc` après `GuildFeats.lua` (les crochets se posent en dernier) :

| Fichier | Contenu |
|---|---|
| `Feats.lua` | moteur : état, critères, sources, évaluation, attribution, rattrapage, migration, bandeau, titres, réglages |
| `FeatsData.lua` | données seules : catalogue, titres, nouveaux cosmétiques, chaînes FR/EN |
| `JournalFeats.lua` | page « Hauts faits » du carnet (`ns.JOURNAL_PANES.feats`) et choix du titre |

**Définition** (une ligne compacte par haut fait, dans `FeatsData.lua`) :

```lua
-- { id, n (code numérique stable), cat, pts, crit = { type, ... }, reward = { ... }, topics = { ... } }
{ "men_species_25", 3, "men", 10, crit = { "count", "species", 25 },
  reward = { title = 2, cosmetic = { "frame", "trainer" } } },
```

- `id` : chaîne stable (`men_species_25`), clé de sauvegarde et de chaînes (`FEAT_men_species_25` pour le nom ; description générée).
- `n` : **code numérique stable** (1 à 999, jamais réutilisé). C'est lui qui voyage dans les messages d'addon (chiffres seulement, comme les autres champs d'exploits de guilde). Fixé : `n` = rang de la ligne dans le catalogue du §2 (1 à 173, dans l'ordre des tableaux), contrôlé par les tests ; une ligne ajoutée plus tard prend 174 et suivants.
- `scope` : `"account"` ou `"char"` (§1.3), écrit sur chaque ligne ; `pending = true` : détection pas encore vérifiée en jeu (§5.1, décision 4).
- `cat` : catégorie (§1.4). `pts` : 5, 10, 25 ou 50.
- `crit` : critère (types ci-dessous). `topics` : déduits du type de critère et de la source quand on peut ; sinon écrits.
- Nom FR et EN dans les tables de chaînes ; **description générée** par un gabarit par source (`FEATD_species = "Capturer %d espèces"`), une phrase écrite à la main seulement pour les critères particuliers. Ainsi on ne stocke pas 2 × 150 descriptions.

**Types de critères** :

| Type | Forme | Valeur de progression |
|---|---|---|
| `count` | `{ "count", source, n }` | `source()` ≥ n (barre x/n) |
| `stat` | `{ "stat", { statIDs }, n, alt = source }` | `max(somme des GetStatistic(id), alt())` ≥ n ; `alt` = notre propre suivi, qui prend le relais si la statistique est illisible |
| `flag` | `{ "flag", clé }` | posé une fois par un crochet (`ns:FeatFlag(clé)`) : faits ponctuels (« capturer 5 créatures en une volée ») |
| `list` | `{ "list", { sous-critères } }` | chaque sous-critère est une clé et un test (count/stat/flag/relevé) ; barre x/y, liste cochée dans la fiche du haut fait |
| `streak` | `{ "streak", clé, n }` | compteur qui repart à zéro (échecs de capture de suite) |
| `meta` | `{ "meta", { ids } }` ou `{ "meta", cat, n }` | hauts faits obtenus parmi une liste, ou N dans une catégorie |
| `points` | `{ "points", n }` | total de points ≥ n |
| `tally` / `tallymax` / `tallyset` | `{ "tally", clé, n, magasin }` | 3.7.0 : compteur de `Tally.lua` (`ns:TallyGet`, `ns:TallyBest`, `ns:TallySize`, magasin `"account"` par défaut ou `"char"`) ≥ n ; sujet `tally` ; **jamais rétroactif** ; « à vérifier » tant que `Tally.lua` n'est pas chargé ; description `FEATD_tally_<clé>` |

**Champs 3.7.0** (deuxième édition) :

- `hidden = true` : **secret**. Tant qu'il n'est pas obtenu : nom « Un secret du compagnon », description = son indice (`FEATH_<id>`) s'il a été révélé, sinon une phrase d'attente ; hors des totaux. `ns:FeatHintNext()` révèle l'indice d'un secret tiré au hasard parmi ceux qui restent (rend le texte et l'identifiant, rien s'il n'en reste pas) ; `ns:FeatHintKnown(id)`.
- `series = "<clé>"` : paliers d'une même échelle, repliés en une ligne à l'écran. Déclarés à part dans `ns.FEAT_SERIES` (`FeatsData.lua`, clé → identifiants), posés par le moteur à la construction de l'index ; une ligne peut aussi l'écrire elle-même. Une série reste dans une catégorie, un type de critère et une source. `ns:FeatSeriesList(cat, filtre)` rend, dans l'ordre de la page, des groupes `{ key, defs (seuil croissant), index (palier en cours), cur, max, def, done, got }` et les lignes sans série telles quelles (`{ def, cur, max, state, got, at }`).
- `pts = 0` : admis pour un **tour de force** (catégorie `fos`) seulement (`ns.FeatPointsOK(def)`).

**Lignes comptables** (`ns:FeatCountable(def)`) : ni en attente (`pending`), ni tour de force, ni secret pas encore obtenu. Les totaux, pourcentages, comptes par catégorie (`ns:FeatCategoryStats`) et le nombre obtenu de `ns:FeatPoints` n'utilisent qu'elles ; une ligne en attente n'est plus listée du tout.

**API de la page** (3.7.0, rien calculé tant que la page ne demande pas) : `ns:FeatNearest(n)` (les n plus proches du but, comptables, non obtenus, non secrets, pas encore atteints : `cur / max` décroissant, à égalité le moins de points ; chacun `{ def, cur, max }`) ; `ns:FeatChecklist(def)` (critère `list` ou `meta` d'identifiants : `{ label, done }` dans l'ordre ; rien pour les autres, un méta « n d'une catégorie » ou un secret caché ; une liste peut fournir `label(self, élément, i, total)`) ; `ns:FeatRank(points)` (rang de renommée, §1.4) ; `ns:FeatBits()` / `ns:FeatBitsDecode(texte)` (comparaison : un bit par code `n`, six par caractère `A-Z a-z 0-9 - _`, zéros de queue retirés) ; `ns:FeatFollow(id, on)` / `ns:FeatFollowed()` (3 suivis au plus par personnage, `CharData().feats.follow` ; ni obtenu, ni en attente, ni secret ; obtenus retirés à la lecture ; au premier suivi `ns:TallyAdd("follow")` si `Tally.lua` est là).

**Sources** : petites fonctions nommées (`species`, `shinyCap`, `seals`, `level`, `goldMax`…), enregistrées dans `ns.FEAT_SOURCES[nom] = { get = function(self) … end, topics = { … }, retro = true|false }`. `retro = true` : la valeur se recalcule à partir des données (captures, relevés, statistiques), donc le rattrapage peut l'attribuer après coup. `retro = false` : compteur d'événements tenu par nous depuis l'installation de la 2.7, sans rien avant.

**Événements → sujets** : chaque crochet existant signale un sujet (`ns:FeatTouch("capture")`) ; le moteur ne réévalue que les hauts faits non obtenus abonnés à ce sujet (index sujet → ids construit au premier besoin). Sujets : `capture`, `shiny`, `seal`, `zone`, `place`, `level`, `money`, `kill`, `mission`, `inn`, `companion`, `quest`, `prof`, `rep`, `instance`, `boss`, `taxi`, `death`, `emote`, `card`, `guild`, `stat`, `minute`, `feat`.

| Sujet | Déclencheurs (crochets ou événements) |
|---|---|
| `capture` | enveloppe de `ns:CaptureResolve` (après les autres lots) et de `ns:CaptureBatchFlush` |
| `shiny` | `ns:ShinyKill`, `ns:ShinySpot` (enveloppes) |
| `seal` | enveloppes de `ns:MenagerieSealCheck`, `ns:MenagerieTypeCheck`, `ns:MenagerieRankCheck` |
| `zone` / `place` | `ns:JournalEarn` (relevés de lieux), `ns:TreatCheckZone`, ouverture de coffre (`CompanionChest.lua`) |
| `level` | `PLAYER_LEVEL_UP`, `PLAYER_ENTERING_WORLD` |
| `money` | `PLAYER_MONEY` (plus haut solde vu : `stats.goldMax`) |
| `kill` | `ns:BestiaryOnKill` (abattus, bestioles, boss du monde, npcID) |
| `mission` / `inn` | `ns:MissionGrant`, `ns:WeeklyEvent` (semaine bouclée), `ns:InnStamp` |
| `companion` | `ns:CompanionPet`, changement d'apparence, effet devenu actif (`CompanionEffects().active`), `ns:PersonaForm` |
| `quest` | `QUEST_TURNED_IN` |
| `prof` | `SKILL_LINES_CHANGED`, `ns:GatheringRecord` |
| `rep` | `UPDATE_FACTION` |
| `instance` / `boss` | `ns:JournalDungeon`, `GetInstanceInfo` de type `raid`, `ENCOUNTER_END` (⚠️), `UNIT_DIED` / `PARTY_KILL` en instance (déjà employés par le carnet sur le moteur 12.0) |
| `taxi` | passage de `UnitOnTaxi("player")` de faux à vrai (horloge d'une seconde, seulement si `TAXIMAP_CLOSED` vient de passer) |
| `death` | `PLAYER_DEAD` (déjà écouté par `Companion.lua`) |
| `emote` | `hooksecurefunc("DoEmote", …)` (danse près du compagnon, etc.) |
| `card` / `guild` | `ns:TrainerOpen` (fiche d'un autre), envoi et réception d'exploits de guilde |
| `stat` | relecture des statistiques natives : à la connexion, puis au plus une fois toutes les 60 s quand un sujet lié (`kill`, `death`, `quest`, `money`, `taxi`, `boss`) a bougé |
| `minute` | horloge d'une minute existante (temps ensemble, km parcourus) |
| `feat` | un haut fait vient d'être obtenu (métas, points) |

**Évaluation** : on marque les sujets à revoir, puis une seule passe au plus toutes les 0,5 s (3.7.0 : la passe ne lit que les lignes abonnées aux sujets touchés, par l'index sujet → lignes construit avec le catalogue) (horloge `OnUpdate` du moteur, retirée quand rien n'attend). Le calcul se fait même en combat (lectures seulement) ; le bandeau et le chat attendent la sortie de combat (même file que le carnet, `JournalFlush`). Les sources coûteuses sont gardées en cache : `MenagerieTypeCounts` et les comptes d'étoiles par `capture.serial` et `capture.count`, les statistiques 60 s.

### 1.2 Statistiques natives (`GetStatistic`)

- **Lecture** : `ns:FeatStat(id)` sous `pcall`, puis `ns.Plain` (valeurs secrètes). Le retour est une chaîne :
  - `"--"`, `""` ou `nil` → 0 (rien) ;
  - nombre simple (`"780"`, `"1,234"`, `"1 234"`, espace insécable) → on retire tout sauf les chiffres ;
  - montant d'argent : texte avec icônes (`|TInterface\\MoneyFrame\\UI-GoldIcon…|t`) ou lettres (`12g 34s 5c`, `12po 34pa 5pc`) → on lit chaque groupe chiffres + marqueur (or/argent/cuivre, par l'icône ou la lettre, FR et EN) et on convertit en pièces de cuivre ; sans marqueur reconnu, le nombre est pris tel quel comme du cuivre ;
  - toute autre forme → `nil` (illisible, le suivi `alt` prend le relais).
- **Test au démarrage** : `ns:FeatStatsOK()` = `GetStatistic(107)` lisible et numérique ; gardé pour la session. Si non : tous les critères `stat` passent sur `alt`, et ceux qui n'ont pas d'`alt` restent « à vérifier » (grisés, sans progression).
- **Statistiques par personnage** sur le client ; cela colle à notre stockage par personnage (§1.3).
- **Coût** : une passe complète lit au plus ~70 statistiques ; à la connexion seulement, puis par sujets (au plus une fois par minute par sujet). Aucune lecture en combat.
- **Rattrapage** : les statistiques couvrent toute la vie du personnage. À la première connexion en 2.7, un joueur de niveau 60 obtient donc d'un coup, sans bruit, « 1000 quêtes », « Onyxia », « 100 morts »… (§1.5).

Toutes les statistiques employées sont listées en §2.13, chacune marquée ⚠️ « valeur à confirmer en jeu », sauf 107 ✅.

### 1.3 Stockage et portée

**Règle (décision 1) : « collection = compte, performance = personnage ».** Chaque définition porte `scope = "account" | "char"`.

- **Compte** (`QuestCompanionDB.feats`) : Ménagerie et Brillantes (agrégées sur tous les personnages : union des espèces capturées, des brillantes, des types et des paliers de chaque personnage), Grands hauts faits et paliers de points, Guilde et entraide, l'essentiel d'Insolite. Un titre gagné par un haut fait de compte sert sur tous les personnages ; ses cosmétiques sont débloqués sur chaque personnage à la connexion (les aides de capture, consommables, vont au seul personnage qui l'obtient).
- **Personnage** (`CharData().feats`) : Personnage (niveaux, or, montures, morts), Donjons et raids, Métiers, Quêtes, réputations et honneur (`GetStatistic` est par personnage), Zones et sceaux, exploration (relevés du carnet), Au jour le jour (missions, rares, auberge).
- Un palier de points (`points`) compte compte + personnage connecté ; un méta par catégorie compte les obtenus de la catégorie dans la portée de chacun.

Les deux tables ont la même forme :

```lua
feats = {
  v = 1,                      -- version du format (migration faite)
  got = { [id] = { at, lvl, r, g } },  -- at = time(), lvl = niveau, r = true si rattrapé ou migré (pas de bandeau),
                              -- g = paillettes versées (3.7.0 ; absent = pas encore payé)
  ctr = { [clé] = n },        -- compteurs d'événements tenus par nous (alt des stats, streaks)
  flag = { [clé] = at },      -- faits ponctuels
  -- compte seulement (3.7.0) :
  hints = { [id] = at },      -- indices de secrets révélés
  -- personnage seulement (3.7.0) :
  follow = { id, … },         -- hauts faits suivis (3 au plus)
  -- personnage seulement (lot D) :
  title = 12,                 -- code du titre affiché ; nil = automatique ; 0 = aucun titre
  form = "auto",              -- forme des titres : auto (UnitSex) | m | f
  seen = 1730947200,          -- dernier passage de la page (pastille « nouveau »)
}
```

| Catégorie | Portée |
|---|---|
| Ménagerie, Brillantes, Guilde et entraide, Insolite, Grands hauts faits | compte |
| Zones et sceaux, Au jour le jour, Personnage, Donjons et raids, Métiers, Quêtes, réputations et honneur | personnage |

Une ligne peut déroger à la règle de sa catégorie en l'écrivant (`scope`), mais les tests du lot A vérifient qu'aucune ligne ne le fait pour l'instant.

**Budget** : ~150 entrées obtenues au plus × ~60 octets ≈ 9 Ko dans la sauvegarde (réparties entre le compte et les personnages) ; compteurs et ensembles < 2 Ko. En mémoire : définitions compactes + chaînes ; l'index des sujets et les caches sont construits à la demande, la page du carnet seulement à son ouverture. Mesuré au lot A (36 lignes) : +75 Ko au chargement (`--memoire`), dont 51 Ko pour le moteur.

### 1.4 Catégories et points

3.7.0 : 16 catégories en trois familles (`family` : `dresseur`, `voyage`, `aventure`), dans l'ordre de la page ; chacune a son icône du client (par référence). Une catégorie sans ligne n'est pas listée.

| Code | Catégorie (FR / EN) | Famille | Portée |
|---|---|---|---|
| `init` | Initiation / Getting Started (3.7.0) | Dresseur | compte |
| `men` | Créatures / Creatures | Dresseur | compte |
| `spec` | Spécimens / Specimens (3.7.0) | Dresseur | compte |
| `shiny` | Brillantes / Shinies | Dresseur | compte |
| `shop` | Réserve et Échoppe / Reserve and Shop (3.7.0) | Dresseur | compte |
| `soc` | Entre dresseurs / Trainer to Trainer (« Guilde et entraide » avant la 3.7.0) | Dresseur | compte |
| `fun` | Insolite / Oddities | Dresseur | compte |
| `meta` | Grands hauts faits / Feats of Feats | Dresseur | compte |
| `fos` | Tours de force / Feats of Strength (3.7.0 ; 0 point, hors des totaux) | Dresseur | compte |
| `comp` | Compagnon / Companion (3.7.0) | Compagnon et voyage | personnage |
| `zone` | Zones et sceaux / Zones and Seals | Compagnon et voyage | personnage |
| `day` | Au jour le jour / Day by Day | Compagnon et voyage | personnage |
| `char` | Personnage / Character | Aventure | personnage |
| `dng` | Donjons et raids / Dungeons and Raids | Aventure | personnage |
| `prof` | Métiers / Professions | Aventure | personnage |
| `quest` | Quêtes, réputations et honneur / Quests, Reputation and Honor | Aventure | personnage |

**Changements de catégorie (3.7.0)** : 20 lignes changent de catégorie sans changer d'identifiant, de code ni de points ; elles restent à leur place dans le §2 (leur code est leur rang), ce qui est obtenu reste obtenu, et les grands hauts faits par catégorie gardent leurs seuils (`meta_menagerie` : 20 hauts faits « Créatures ») :

- vers `spec` (12) : `men_stars3_1`, `men_stars3_25`, `men_stars3_100`, `men_size_giant`, `men_size_tiny`, `men_sizes_all`, `men_traits_all`, `men_study_10`, `men_study_50`, `men_study_100`, `men_bond_familiar`, `men_bond_inseparable` ;
- vers `shop` (3) : `men_patron_10`, `men_patron_50`, `men_patron_100` ;
- vers `comp` (5) : `day_days_30`, `day_days_365`, `day_travel_100`, `day_travel_1000`, `day_pets_100`.

**Points**, sur l'échelle de retail : **5** (premier pas, fait amusant), **10** (étape normale), **25** (gros objectif), **50** (sommet, méta) ; **0** pour un tour de force. Total affiché sur la page, la fiche de dresseur et les bandeaux de guilde.

**Paillettes (3.7.0)** : tout haut fait en donne à l'obtention, selon ses points (`ns.FEAT_GLITTER`) : 2, 5, 15, 40 (0 pour un tour de force), par `ns:PaillettesAdd(n, "feat")` ; la marque `g` dans `got[id]` empêche tout second paiement.

**Rangs de renommée (3.7.0)** : `ns.FEAT_RANKS` = 100, 250, 500, 1 000, 1 500, 2 000, 3 000, 4 000 points (compte + personnage connecté), nommés « Connu au village », « Connu du comté », « Un nom qui circule », « Réputé », « De grande renommée », « Illustre », « Célèbre dans tout Azeroth », « Légende vivante ». `ns:FeatRank(points)` rend l'indice du rang (0 : aucun), son nom, le seuil suivant et son nom, le total.

### 1.5 Rattrapage à la connexion

- `PLAYER_ENTERING_WORLD` + 3 s (hors combat, sinon à la sortie), une fois par session : on évalue **tous** les hauts faits non obtenus dont la source est `retro = true` (captures, relevés, sceaux, niveau, métiers, statistiques natives, réputations lisibles).
- **Première passe** (`feats.v == nil`) : migration (§3) puis rattrapage, **en silence** (`r = true`, aucun bandeau, aucun exploit de guilde), puis **une seule ligne** de chat : « Hauts faits : 47 obtenus d'après ta progression (385 points). Ouvre le carnet pour les voir. »
- **Passes suivantes** : ce qui est trouvé à la connexion (réputation montée pendant que l'addon était coupé, statistique qui a bougé) est attribué de la même façon : en silence, une ligne de chat récapitulative et **au plus un bandeau** (groupé dès 2). Fait au lot A.
- Tant que le rattrapage de la connexion n'a pas eu lieu, les sujets touchés attendent (le carnet rattrape ses paliers de niveau à l'entrée dans le monde : ils ne doivent pas sortir en bandeaux un par un).
- **Paillettes (3.7.0)** : à chaque connexion, les hauts faits du compte et du personnage connecté obtenus sans marque `g` (avant la 3.7.0, sauvegarde ancienne comprise) sont payés en une fois, avec une seule ligne de chat ; ceux d'un autre personnage le sont à sa connexion. Chaque haut fait n'est payé qu'une fois.
- Les compteurs `retro = false` (danses, caresses depuis la 2.7…) démarrent à zéro, sauf quand une donnée existante sert d'amorce : `missionsDone`, `inn.total`, `daily.perfect`, `travel`, `ShinyData().count`, `CaptureData().count`, relevés du carnet, `GatheringData`.

### 1.6 Bandeau « Haut fait obtenu » et regroupement

- On reprend la file du carnet : `ns:JournalToastPush({ kind = "feat", id, name, pts })`, qui affiche le bandeau Azeroth (`AzerothCreateBanner`, 2.5) : titre « HAUT FAIT OBTENU », nom du haut fait, **points dans le bouclier** (`frame.shield` doré + un texte de points centré dessus), icône de la catégorie dans le cadre carré. En style Sobre : le bandeau losange actuel.
- Hors combat seulement, un à la fois, 4 s. **À partir de 3 en attente** : un seul bandeau « 3 hauts faits obtenus · +45 points » (même règle que `TOAST_COLLAPSE`).
- Un haut fait qui donne un titre : la sous-ligne dit « Nouveau titre : … » ; un clic sur le bandeau ouvre la page, sur ce haut fait.
- Son : `CAPTURE_SOUNDS` du client (un nouveau kit `feat`, à choisir : 12891 est la fanfare des hauts faits sur le moteur récent, ⚠️ à écouter en jeu ; repli 17316).
- **Taille de la fête (3.7.0)** : `ns:FeatSize(def)` = `small` (5 points), `medium` (10), `big` (25, 50, un titre ou un tour de force). Fanfare (`FEAT_SOUND`) pour `big` seulement, son court (`FEAT_SOUND_FALLBACK`) pour `medium`, aucun son pour `small`. La taille part avec le bandeau (`size`) ; un bandeau groupé prend la taille du plus gros. Le regroupement à partir de 3 ne change pas ; le dessin de la pastille vient avec la page.
- Le compagnon réagit (`CompanionSay("UNLOCK")`) pour les hauts faits à 25 points ou plus, et pour ceux qui donnent un titre.
- Le bandeau « Nouveau tampon » **disparaît** (§3).

### 1.7 Attribution des récompenses

Au moment de l'obtention (rattrapage compris), une seule fonction `ns:FeatGrant(def)` :
- **titre** : ajouté aux titres gagnés (rien à stocker : un titre est gagné si son haut fait l'est) ;
- **cosmétique** : `CompanionData().unlocked["kind:id"] = true` (même table que les coffres, sceaux, brillantes), puis `CompanionApplyOrnaments` ;
- **aide de capture** : `ns:CaptureGrant(id, { quiet = true, silent = true })` × N ; besace pleine : l'aide est perdue, comme aujourd'hui (le bandeau le dit : « besace pleine ») ;
- **apparence** : `ns:DailyGrantAppearance(id)` (déjà idempotente).

Un déblocage n'est jamais repris (règle du compagnon).

### 1.8 Ce qui existe déjà : pas de doublons

| Système existant | Devient |
|---|---|
| Paliers d'espèces 10/25/50/100/250 et titres de dresseur (`TRAINER_RANKS`, `MenagerieRankCheck`) | hauts faits `men_species_*` ; **titres, aides et cosmétiques déplacés tels quels** dans leurs récompenses. `MenagerieRankCheck` garde son rôle d'annonce de guilde (`r`) et laisse le moteur attribuer ; `collection.ranks` reste lu pour la migration. |
| Paliers de brillantes 5/15/30/50 (`SHINY_REWARDS`, `ShinyCheckRewards`) | `shiny_found_*`, mêmes récompenses (cadre, fond, ornement, bébé hippogriffe) |
| Sceaux par zone et cosmétiques de biome (1er sceau = cadre, 2e = paysage) | **restent à la mécanique des sceaux** (c'est le trophée de la zone, comme le coffre est celui de la zone finie) ; les hauts faits comptent les sceaux (`zone_seal_*`, `zone_all_biomes`, continents) |
| Complétion par type (force du compagnon) | inchangée ; hauts faits au palier 1 sur tous les types et au palier 3 par type |
| Coffres de zone, zones dorées, friandises de palier | inchangés ; hauts faits qui les comptent |
| Apparences gagnées au jour le jour (poulet, écureuil mécanique) | restent où elles sont ; `day_perfect_10` rappelle l'écureuil dans sa fiche (même condition, récompense non doublée) |
| Cosmétiques débloqués par nombre de tampons (`unlock = { stamp = … }` dans `CompanionData.lua`) | inchangés : `ns:JournalCounts()` continue de compter les relevés |
| Tampons du carnet | **relevés silencieux** + hauts faits (§3) |

### 1.9 Titres

Les titres sont une récompense de premier rang.

- **Catalogue** : 43 titres (§4.1), chacun avec un **code stable** (1 à 255), un modèle FR masculin, un modèle FR féminin (absent = épicène) et un modèle EN (genré seulement si l'anglais l'exige : « Lord / Lady »).
- **Préfixe ou suffixe** comme sur retail, porté par le modèle : `"Dresseur %s"` (préfixe), `"%s le Chasseur de brillantes"` (suffixe avec article), `"%s, Maître des brillantes"` (suffixe apposé). `ns:TitleRender(code, nom, genre, opts)` remplace `%s` ; `opts.inline = true` (titre au milieu d'une phrase) ajoute la virgule fermante après un suffixe apposé : « Dyokrion, Maître des brillantes, a capturé une brillante ! ». `opts.bare = true` rend le titre seul sans le nom (sous-titre de la fiche, liste du choix) : on retire `%s`, la virgule et l'espace de tête, et on met une capitale (« Maître des brillantes », « Le Chasseur de brillantes » devient « Chasseur de brillantes » : l'article est retiré en tête).
- **Genre** : formes masculine et féminine en français, choisies par `UnitSex("player")` (2 = masculin, 3 = féminin, 1 ou illisible = masculin) ; le réglage « Forme des titres » (`automatique`, `masculin`, `féminin`) l'emporte. Le genre voyage avec la fiche (champ `tg`) : le destinataire rend la bonne forme dans **sa** langue.
- **Choix du titre** : le joueur choisit quel titre gagné s'affiche. Par défaut (`title = nil`, « automatique ») : le titre du plus haut palier d'espèces, comme aujourd'hui (`ns:TrainerTitle()` ne change pas de comportement pour qui ne choisit rien), sinon aucun. `title = 0` : aucun titre.
- **Où choisir** : (1) sur sa propre fiche de dresseur, clic sur le sous-titre → liste déroulante des titres gagnés, regroupés par catégorie, avec « Automatique » et « Aucun titre » en tête ; (2) dans la page Hauts faits, onglet « Titres » (§1.11) ; (3) `/qc titre [nom|auto|aucun]`.
- **API** : `ns:TrainerTitle()` rend le texte affiché (sous-titre, nu) pour la compatibilité ; nouveaux `ns:TitleCode()` (titre affiché effectif), `ns:TitlesEarned()`, `ns:TitleSet(code)`, `ns:TitleRender(…)`, `ns:TitleGender()`.

### 1.10 Fiche de dresseur et exploits de guilde

**Fiche de dresseur** (`TrainerCard.lua`, `TrainerOwnCard` / `TrainerSerializeCard` / `TrainerParseCard`) : nouveaux champs, tous facultatifs, ignorés par les versions d'avant (champs inconnus ignorés, `TRAINER_PROTO` reste 1) :

| Champ | Valeur | Repli |
|---|---|---|
| `ti` | code du titre affiché (chiffres, 0 à 255) | le champ `t` (texte du titre déjà rendu dans la langue de l'expéditeur) reste envoyé pour les versions d'avant |
| `tg` | genre : `m` ou `f` | `m` |
| `ap` | points de hauts faits (0 à 99999) | absent = la ligne n'est pas affichée |
| `ac` | nombre de hauts faits obtenus | idem |
| `cb`, `cf` | fond et cadre de fiche choisis (§4.2, id en liste blanche) | fond et cadre par défaut |

Le destinataire rend `ti` dans sa langue avec `tg` ; code inconnu chez lui (version plus ancienne) → il affiche `t`. Affichage : en-tête = nom avec titre (« Dyokrion le Chasseur de brillantes ») ; nouvelle tuile de chiffres « Hauts faits : 64 · 615 points ».

**Exploits de guilde** (`GuildFeats.lua`) :
- Nouvelle sorte `h` (haut fait) : `E~1~h~<code du haut fait>~0~0~-~<autres>~<code du titre>~<genre>`. Les versions d'avant rejettent la sorte inconnue (`KINDS`), donc rien ne s'affiche de travers chez elles.
- **Champs 9 et 10 ajoutés à toutes les sortes** (titre et genre de l'expéditeur) : l'analyseur actuel lit les champs 1 à 8 et ignore la suite, les anciennes versions restent compatibles.
- Annoncé seulement pour les hauts faits de **25 points ou plus** et ceux qui donnent un titre (réglage `featGuildMin`, 25 par défaut) ; jamais en rattrapage silencieux.
- Score (`GuildFeatScore`) : `h` = 750 + points (entre le sceau 700 et le palier 800 ; une méta à 50 points passe devant un palier).
- Texte : « Dyokrion, Maître des brillantes, a obtenu « Trésor vivant » ! » ; sous-ligne « Haut fait · 50 points » ou « Nouveau titre : … ». Le nom de l'expéditeur avec son titre sert aussi pour les autres sortes : « Dyokrion le Globe-trotteur a capturé une brillante ! ».

### 1.11 Page « Hauts faits » du carnet

Nouvelle section `feats` (« Hauts faits »), placée après `menagerie` : `SECTIONS = { "evolution", "menagerie", "feats", "day", "progress", "guide" }`. Le sous-titre de la fenêtre (`JRN_TOTAL`, aujourd'hui « %d tampon(s) ») devient « %d points de hauts faits ».

Fenêtre 980 × 680 (contenu `INNER`), mise en page :

```
┌ Hauts faits ─────────────────────────────────────── 615 points · 64/173 ┐
│ ┌──────────────┐ ┌ [Tous] [En cours] [Obtenus] [À faire]     [Titres] ┐ │
│ │ Résumé       │ │ ┌──┐ Ménagerie bien garnie                  10    │ │
│ │ Ménagerie 12/29│ │ │🛡│ Capturer 25 espèces       ███████░░ 19/25    │ │
│ │ Brillantes 3/12│ │ └──┘ Récompense : titre « Dresseur », cadre…    │ │
│ │ Zones     8/23 │ │ ┌──┐ Premières profondeurs                  10    │ │
│ │ …            │ │ │🛡│ 5/8 boss · survol : la liste cochée          │ │
│ │ Grands HF 0/8│ │ └──┘                                               │ │
│ └──────────────┘ └───────────────────────────── ◀ 1/4 ▶ ──────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

- **Colonne de gauche** (180 px) : « Résumé » puis les 11 catégories, chacune avec obtenus/total et une fine barre ; pastille dorée sur une catégorie qui a du neuf depuis `feats.seen`.
- **Résumé** : total de points, grande barre globale, les 5 derniers obtenus (date), les 3 plus proches d'être finis (« presque »), le titre affiché et un bouton « Choisir mon titre ».
- **Liste** (lignes de 58 px, paginée par `Pager` et la molette comme le Guide) : bouclier avec les points (atlas Azeroth si dispo, sinon losange du thème), nom, description générée, barre x/n (ou « 5/8 » pour une liste, détail au survol), date et niveau si obtenu, ligne de récompense (titre / cosmétique / aides, avec icône). Une ligne ⚠️ « à vérifier en jeu » sans source lisible est grisée avec la mention « détection pas encore disponible sur ce client ». (3.7.0 : une ligne `pending` n'est plus listée du tout ; seule une ligne dont la source est illisible sur ce client reste grisée. La page sera refaite d'après une maquette validée.)
- **Filtres** : Tous / En cours (progression > 0) / Obtenus / À faire (0). Tri : non obtenus par progression décroissante, puis obtenus du plus récent au plus ancien. Filtre gardé dans `db.featsFilter`.
- **Onglet Titres** : les titres gagnés (boutons radio, rendus avec le nom du joueur et la forme choisie), puis les titres pas encore gagnés en gris avec leur haut fait source ; « Automatique » et « Aucun titre » en tête ; choix de la forme (auto / masculin / féminin).
- Ligne d'aperçu pour les tests : scène `qc-journal-feats` (et `qc-journal-feats-titles`).
- Le suivi à l'écran (`JournalTracker.lua`) n'est pas touché dans ce chantier ; plus tard : Maj+clic sur un haut fait pour le suivre.

### 1.12 Réglages

Fait au lot A : une section « Hauts faits » dans la page **Carnet de voyage** (pas de page à part), avec `featToast`, `featChat`, `featSound`, `featStats`. Le reste (seuil de guilde, forme des titres) vient avec le lot D. Prévu à l'origine : page « Hauts faits » sous le compagnon (`OPT_GROUP_MODULES`) :

| Clé | Défaut | Libellé |
|---|---|---|
| `featToast` | vrai | Bandeau « Haut fait obtenu » |
| `featChat` | faux | Ligne de chat à chaque haut fait |
| `featSound` | vrai | Fanfare |
| `featGuildMin` | 25 | Annoncer à la guilde à partir de (5 / 10 / 25 / 50 / jamais) — sous `guildFeatsSend` |
| `featStats` | vrai | Lire les statistiques du client (désactivable si un client les rend fausses) |
| `featTitleForm` | auto | Forme des titres : automatique / masculin / féminin (= `feats.form`, par personnage) |

L'ancien réglage `journalToast` reste (il gouverne la même file de bandeaux) ; `journalChat` est repris pour `featChat` à la migration. Commandes : `/qc hf` (ouvre la page), `/qc titre …`, `/qc hf diag` (état des sources : statistiques lisibles, `ENCOUNTER_END` vu, `C_Reputation`, `GetUnitSpeed`, nombre de hauts faits par faisabilité).

---

## 2. Catalogue

Colonnes : identifiant stable, nom FR, nom EN, condition, détection (source exacte), faisabilité, points, récompense. « relevés » = la table des anciens tampons (`journal.stamps`, §3). Les codes numériques `n` sont attribués dans l'ordre des tableaux à l'écriture de `FeatsData.lua`, puis figés.

### 2.1 Créatures (`men`) — 29 hauts faits

| id | FR | EN | Condition | Détection | F | Pts | Récompense |
|---|---|---|---|---|---|---|---|
| `men_first` | Premier filet | First Net | Capturer 1 espèce | `ns:MenagerieSpeciesCount()` | ✅ | 5 | Appât ×1 |
| `men_species_10` | Petite collection | A Little Collection | Capturer 10 espèces | idem | ✅ | 10 | titre T1 ; Appât ×1, Lasso ×1 (ex-`TRAINER_RANKS`) |
| `men_species_25` | Collection bien garnie | Well-Stocked Collection | 25 espèces | idem | ✅ | 10 | titre T2 ; cadre `trainer` |
| `men_species_50` | Enclos animés | Busy Pens | 50 espèces | idem | ✅ | 10 | titre T3 ; Sifflet ×1 ; fond `menagerie` |
| `men_species_100` | Cent pensionnaires | A Hundred Lodgers | 100 espèces | idem | ✅ | 25 | titre T4 ; Sifflet ×1 ; cadre `master` |
| `men_species_250` | L'arche d'Azeroth | Azeroth's Ark | 250 espèces | idem | ✅ | 50 | titre T5 ; Sifflet ×2 ; fond `grandmaster` |
| `men_species_500` | Le grand recensement | The Great Census | 500 espèces | idem | ✅ | 50 | titre T6 ; fond de fiche `card_census` |
| `men_elite_1` | Gros gibier | Big Game | Capturer une élite | fiche `class == "elite"` | ✅ | 5 | — |
| `men_rare_1` | Pièce rare | A Rare Find | Capturer un rare ou rare élite | `class` `rare`/`rareelite` | ✅ | 10 | Lasso ×1 |
| `men_rare_10` | Cabinet des raretés | Cabinet of Curiosities | 10 rares capturés | idem, compte | ✅ | 25 | titre T7 |
| `men_boss_1` | Le colosse en cage | The Caged Colossus | Capturer un boss du monde | `class == "worldboss"` | ✅ | 25 | ornement `feat_chain` |
| `men_types_t1` | Touche-à-tout | Jack of All Types | Palier 1 dans les 8 types | `ns:MenagerieTypeTier` | ✅ | 10 | Lasso ×1 |
| `men_type_beast` | Meneur de meute | Pack Leader | Bêtes : palier 3 (40) | `MenagerieTypeTier("beast") == 3` | ✅ | 10 | Lasso ×1 |
| `men_type_humanoid` | Recruteur de talents | Talent Scout | Humanoïdes : palier 3 (40) | idem | ✅ | 10 | Lasso ×1 |
| `men_type_undead` | Berger des tombes | Shepherd of Graves | Morts-vivants : palier 3 (40) | idem | ✅ | 10 | Lasso ×1 |
| `men_type_elemental` | Lieur d'éléments | Element Binder | Élémentaires : palier 3 (40) | idem | ✅ | 10 | Lasso ×1 |
| `men_type_dragonkin` | Écailles et griffes | Scales and Claws | Draconiens : palier 3 (20) | idem | ✅ | 10 | titre T8 |
| `men_type_demon` | Pacte scellé | Pact Sealed | Démons : palier 3 (20) | idem | ✅ | 10 | titre T9 |
| `men_type_giant` | Haut comme une montagne | Mountain High | Géants : palier 3 (20) | idem | ✅ | 10 | Lasso ×1 |
| `men_type_mechanical` | Boulons et rouages | Nuts and Bolts | Mécaniques : palier 3 (20) | idem | ✅ | 10 | Lasso ×1 |
| `men_types_master` | Les huit familles | The Eight Families | Palier 3 dans les 8 types | méta des 8 ci-dessus | ✅ | 25 | titre T10 ; cadre `feat_eight` |
| `men_stars3_1` | Spécimen parfait | Perfect Specimen | Une capture à 3 étoiles | `ns:CaptureStars(npc, false) == 3` | ✅ | 5 | — |
| `men_stars3_25` | Galerie trois étoiles | Three-Star Gallery | 25 espèces à 3 étoiles | idem, compte (cache par `capture.serial`) | ✅ | 10 | Appât ×2 |
| `men_stars3_100` | Constellation | Constellation | 100 espèces à 3 étoiles | idem | ✅ | 25 | titre T11 ; ornement `feat_goldstars` |
| `men_batch_5` | Coup de filet | Big Haul | 5 créatures prises en une volée « Tout capturer » | enveloppe de `CaptureBatchFlush` (réussites ≥ 5) | ✅ | 10 | — |
| `men_bad_luck` | Il s'est encore échappé | Got Away Again | 10 captures ratées de suite | `streak` dans l'enveloppe de `CaptureResolve` | ✅ | 5 | Appât ×3 (lot de consolation) |
| `men_level_gap` | David contre Goliath | David and Goliath | Capturer une créature d'au moins 5 niveaux de plus que toi | `rolling.target.level` − `UnitLevel` à la résolution | ✅ | 10 | — |
| `men_companion_types` | Tour de la collection | Collection Tour | Emmener un compagnon de chacun des 8 types (effet actif) | `ns:CompanionEffects()` (`active`, `typeKey`) → `set.ctypes` | ✅ | 10 | — |
| `men_companion_boss` | Garde du corps | Bodyguard | Emmener un boss du monde capturé (effet actif) | idem, `class == "worldboss"` | ✅ | 10 | — |

Hors numérotation (3.1.0, tailles des spécimens, `SpecimenTraits.lua`) : `men_size_giant` (code 176) — Un géant parmi les bêtes / A Giant Among Beasts — capturer un spécimen géant (2 % des captures) : `flag` `sizeGiant`, compte, 10 points ; `men_size_tiny` (code 177) — Petit mais costaud / Small but Mighty — capturer un spécimen minuscule (2 %) : `flag` `sizeTiny`, compte, 10 points. Le drapeau est posé à la capture (`ns:SpecimenSizeFeat`) ; pas de rattrapage (aucune taille rare avant la 3.1).

Hors numérotation (3.4.0, étude d'espèce et lien, `SpecimenStudy.lua`, `SpecimenBond.lua`), tous au compte : `men_study_10` (code 181) — Naturaliste / Naturalist — maîtriser l'étude de 10 espèces : `count` `studyMastered`, 10 points ; `men_study_50` (code 182) — Savant des bêtes / Beast Scholar — 50 espèces, 25 points ; `men_study_100` (code 183) — Encyclopédie vivante / Living Encyclopedia — 100 espèces, 50 points ; `men_bond_familiar` (code 184) — Premiers pas ensemble / First Steps Together — un spécimen au lien Familier : `flag` `bondFamiliar`, 10 points ; `men_bond_inseparable` (code 185) — À la vie, à la mort / Till Death Do Us Part — un spécimen au lien Inséparable : `flag` `bondInseparable`, 25 points ; `men_traits_all` (code 186) — Tous les caractères / Every Personality — les 8 caractères tirés capturés : `flag` `traitsAll`, 25 points ; `men_sizes_all` (code 187) — De toutes les tailles / All Shapes and Sizes — les 5 tailles capturées : `flag` `sizesAll`, 25 points. Seules les captures faites soi-même comptent ; l'étude ne paie rien pour ce qui était acquis avant la mise à jour.

Hors numérotation (3.6.0, mécénat de l'Échoppe du dresseur, `ShopWeek.lua`), au compte : `men_patron_10` (code 241) — Mécène / Patron — atteindre 10 points de mécène (100 paillettes le point) : `count` `patron`, 10 points, titre T61 ; `men_patron_50` (code 242) — Grand mécène / Great Patron — 50 points de mécène, 25 points, titre T62 ; `men_patron_100` (code 243) — Bienfaiteur des créatures / Benefactor of Creatures — 100 points de mécène, 50 points, titre T63.

3.6.0 (« Des buts longs ») : ces sept lignes reçoivent leurs récompenses : `men_study_10` un Sifflet du dompteur ×1, `men_study_50` le titre T48, `men_study_100` l'ornement `feat_scholar`, `men_bond_inseparable` le titre T49 (et la marque « Inséparable » sur la vignette du spécimen, un cœur du client), `men_traits_all` le cadre du compagnon `feat_traits`, `men_sizes_all` le fond du compagnon `feat_sizes`. Rangs de dresseur au-delà de 500 espèces, hors numérotation, au compte, 50 points chacun, un titre chacun : `men_species_750` (code 188) — Sur la piste des bêtes / On the Beasts' Trail — 750 espèces, titre T41 ; `men_species_1000` (code 189) — Mille espèces / A Thousand Species — titre T42 ; `men_species_1500` (code 190) — Le bestiaire s'épaissit / A Thickening Bestiary — titre T43 ; `men_species_2000` (code 191) — Deux mille espèces / Two Thousand Species — titre T44 ; `men_species_2500` (code 192) — Les archives d'Azeroth / The Archives of Azeroth — titre T45 ; `men_species_3000` (code 193) — Trois mille espèces / Three Thousand Species — titre T46 ; `men_species_all` (code 194) — Tout Azeroth / All of Azeroth — toutes les espèces de sa faction (table livrée, hors boss du monde et lignes de niveau 9999 jamais capturées) : `count` `azeroth` (pour cent) ≥ 100, titre T47. Ces paliers rejoignent `TRAINER_RANKS` (titre automatique, bandeau de la page Créatures, annonce de guilde `r` ; « tout Azeroth » part en `h`).

### 2.2 Brillantes (`shiny`) — 12

| id | FR | EN | Condition | Détection | F | Pts | Récompense |
|---|---|---|---|---|---|---|---|
| `shiny_seen_1` | Un éclat dans l'herbe | A Glint in the Grass | Repérer une brillante | `ShinyData().seen` non vide | ✅ | 5 | — |
| `shiny_found_5` | Œil de pie | Magpie Eye | 5 brillantes trouvées | `ShinyData().count` | ✅ | 10 | cadre `sparkle` (ex-`SHINY_REWARDS`) |
| `shiny_found_15` | Poussière d'étoiles | Stardust | 15 brillantes trouvées | idem | ✅ | 10 | fond `stardust` |
| `shiny_found_30` | Aura dorée | Golden Aura | 30 brillantes trouvées | idem | ✅ | 25 | ornement `aura` |
| `shiny_found_50` | Le petit hippogriffe | The Little Hippogryph | 50 brillantes trouvées | idem | ✅ | 25 | apparence `hippogryph` ; titre T12 |
| `shiny_cap_1` | Prise étincelante | Sparkling Catch | Capturer une brillante | `ns:CaptureShinyCount()` | ✅ | 10 | Lasso ×1 |
| `shiny_cap_10` | Vitrine scintillante | Glittering Showcase | 10 brillantes capturées | idem | ✅ | 25 | Sifflet ×1 |
| `shiny_cap_25` | Trésor vivant | Living Treasure | 25 brillantes capturées | idem | ✅ | 50 | titre T13 |
| `shiny_elite` | Éclat d'élite | Elite Gleam | Capturer une brillante élite, rare ou boss | fiche `shiny` + `class` | ✅ | 10 | — |
| `shiny_3stars` | Brillante parfaite | Flawless Shine | Une brillante à 3 étoiles | `CaptureStars(npc, true) == 3` | ✅ | 25 | ornement `feat_prism` |
| `shiny_sealed` | Terre bénie | Blessed Ground | Trouver une brillante dans une zone scellée | enveloppe de `ShinyKill` + `MenagerieSealed(JournalZone())` | ✅ | 10 | — |
| `shiny_zones_10` | Éclats d'Azeroth | Shards of Azeroth | Brillantes trouvées dans 10 zones différentes | `ShinyData().zones` (clés) | ✅ | 25 | — |

### 2.3 Zones et sceaux (`zone`) — 23

| id | FR | EN | Condition | Détection | F | Pts | Récompense |
|---|---|---|---|---|---|---|---|
| `zone_seal_1` | Premier sceau | First Seal | Sceller une zone | `#ns:MenagerieSeals()` | ✅ | 10 | Lasso ×1 |
| `zone_seal_5` | Apposeur de sceaux | Seal Bearer | 5 zones scellées | idem | ✅ | 10 | Sifflet ×1 |
| `zone_seal_15` | Gardien des sceaux | Keeper of Seals | 15 zones scellées | idem | ✅ | 25 | titre T14 |
| `zone_seal_ek` | Sceaux de l'Est | Seals of the East | Toutes les zones à sceau des Royaumes de l'Est | `JournalContinentOf == "ek"` et `MenagerieSealProgress` need > 0 | ✅ | 50 | cadre de fiche `card_crest_ek` |
| `zone_seal_ka` | Sceaux de Kalimdor | Seals of Kalimdor | Toutes les zones à sceau de Kalimdor | idem `"ka"` | ✅ | 50 | cadre de fiche `card_crest_ka` |
| `zone_all_biomes` | Tour des biomes | Biome Tour | Un sceau dans chacun des 10 biomes | `MenagerieBiomeSeals(b) ≥ 1` pour les 10 | ✅ | 25 | titre T15 |
| `zone_visit_10` | Bourlingueur | Wanderer | Découvrir 10 zones | relevés `zone` | ✅ | 5 | Appât ×1 |
| `zone_visit_25` | Grand voyageur | Far Traveller | Découvrir 25 zones | idem | ✅ | 10 | Lasso ×1 |
| `zone_visit_all` | Tous les chemins | Every Road | Découvrir les 41 zones extérieures (38 de `ZONE_LEVELS` + Riverglades, Mont Hyjal, Shen'dralas) | relevés `zone` ∩ liste | ✅ (Mont Hyjal 2482, Riverglades 2548, Shen'dralas 2652) | 50 | titre T16 |
| `zone_forever_new` | Terres nouvelles | New Lands | Visiter Riverglades, Mont Hyjal et Shen'dralas | relevés `zone` (liste) | ✅ | 10 | — |
| `zone_villages_10` | De village en village | Village to Village | 10 villages ou hubs amis | relevés `subzone` | ✅ | 5 | — |
| `zone_villages_25` | Toutes les auberges du pays | Every Inn in the Land | 25 villages ou hubs amis | idem | ✅ | 10 | — |
| `zone_capitals` | Tour des capitales | Grand Tour of Capitals | Les 6 capitales (liste cochée) | relevés `capital` (groupes de `Hubs.lua`) | ✅ | 10 | titre T17 |
| `zone_capital_enemy` | Touriste en terre hostile | Tourist in Hostile Land | Entrer dans une capitale de l'autre faction | relevé `capital` + `group.faction ≠ PlayerFaction()` | ✅ | 10 | — |
| `zone_100_1` | Zone accomplie | Zone Complete | Une zone à 100 % | `ns:ZoneCompletion(z).percent == 100` (≥ 2 parts), `TreatData().milestones[z] == 100` | ✅ | 10 | — |
| `zone_100_10` | Dix zones accomplies | Ten Zones Complete | 10 zones à 100 % | idem, compte | ✅ | 25 | fond `feat_atlas` |
| `zone_golden` | Or massif | Solid Gold | Une zone dorée | `ChestData()[z].golden` | ✅ | 10 | — |
| `zone_chests_10` | Chasseur de coffres | Chest Hunter | Ouvrir 10 coffres de zone | `ChestData()` (`opened` sans `golden`) | ✅ | 10 | Sifflet ×1 |
| `zone_milestones_25` | Petits pas, grand chemin | Small Steps, Long Road | 25 paliers de zone franchis (25/50/75/100 %) | somme des paliers de `TreatData().milestones` | ✅ | 10 | — |
| `zone_quests_zone` | Zone sans reste | Nothing Left Undone | Toutes les quêtes d'une zone | `ns:ZoneQuestsPart(z)` à 100 % | ✅ | 10 | — |
| `zone_ek_100` | L'Est sur le bout des doigts | The East by Heart | Toutes les zones des Royaumes de l'Est à 100 % | `ZoneCompletion` sur la liste `ek` | ✅ | 50 | — |
| `zone_ka_100` | Kalimdor sur le bout des doigts | Kalimdor by Heart | Toutes les zones de Kalimdor à 100 % | idem `ka` | ✅ | 50 | — |
| `zone_two_continents` | Deux continents en un jour | Two Continents in a Day | Découvrir ou revisiter une zone de chaque continent le même jour | `JournalContinentOf` de la zone courante, `set.contDay` (jour → continents vus) ; relevés `zone` datés pour la migration | ✅ | 5 | — |

### 2.4 Au jour le jour (`day`) — 14

| id | FR | EN | Condition | Détection | F | Pts | Récompense |
|---|---|---|---|---|---|---|---|
| `day_mission_1` | Au rapport | Reporting In | 1 mission accomplie | `CompanionData().missionsDone` | ✅ | 5 | — |
| `day_mission_25` | Bon élément | Reliable | 25 missions | idem | ✅ | 10 | Lasso ×1 |
| `day_mission_100` | Infatigable | Tireless | 100 missions | idem | ✅ | 25 | titre T18 |
| `day_perfect_10` | Journées parfaites | Perfect Days | 10 jours avec toutes les missions | `DailyData().perfect` | ✅ | 10 | (l'écureuil mécanique reste donné par `Daily.lua`, rappelé dans la fiche) |
| `day_weekly_all` | Semaine bouclée | Week Wrapped Up | Toutes les missions d'une semaine | enveloppe de `WeeklyEvent` (`allWeekly`) → flag | ✅ | 10 | — |
| `day_inn_30` | Pilier de comptoir | Regular at the Bar | 30 jours d'auberge | `inn.total` | ✅ | 10 | — |
| `day_rare_1` | Tête mise à prix | Wanted | Vaincre un rare | relevés `rare` | ✅ | 5 | — |
| `day_rare_10` | Chasseur de primes | Bounty Hunter | 10 rares | idem | ✅ | 10 | Lasso ×1 |
| `day_rare_50` | Le traqueur | The Tracker | 50 rares | idem | ✅ | 25 | titre T19 |
| `day_travel_100` | Cent kilomètres ensemble | A Hundred Kilometres Together | 100 km parcourus avec le compagnon | `CompanionData().travel` | ✅ | 10 | — |
| `day_travel_1000` | Mille kilomètres ensemble | A Thousand Kilometres Together | 1000 km | idem | ✅ | 25 | ornement `feat_compass` |
| `day_days_30` | Un mois ensemble | A Month Together | 30 jours ensemble | `ns:CompanionDaysTogether()` | ✅ | 10 | — |
| `day_days_365` | Un an ensemble | A Year Together | 365 jours ensemble | idem | ✅ | 25 | titre T20 ; ornement `feat_anniversary` |
| `day_pets_100` | Câlins à volonté | Endless Cuddles | 100 caresses | enveloppe de `ns:CompanionPet` → `ctr.pets` | ✅ | 10 | — |

### 2.5 Guilde et entraide (`soc`) — 7

| id | FR | EN | Condition | Détection | F | Pts | Récompense |
|---|---|---|---|---|---|---|---|
| `soc_card_1` | Enchanté ! | Pleased to Meet You | Consulter la fiche d'un autre dresseur | enveloppe de `ns:TrainerOpen` (pas soi) | ✅ | 5 | — |
| `soc_card_10` | Carnet d'adresses | Address Book | 10 fiches différentes consultées | `set.cards` (clés `TrainerKey`, 10 max) | ✅ | 10 | — |
| `soc_showcase` | Vitrine garnie | Full Showcase | Remplir les 3 places de la vitrine | `TrainerOwnCard().showcase` | ✅ | 5 | — |
| `soc_guild_feat` | Ça jase à la guilde | Talk of the Guild | Annoncer un exploit à sa guilde | envoi dans `GuildFeatNote` | ✅ | 5 | — |
| `soc_guild_cheer` | Supporter | Cheerleader | Voir 25 exploits de membres de ta guilde | réception (`ns:TrainerOnAddonMessage`, sorte `E`) | ✅ | 5 | — |
| `soc_group_capture` | Chasse en meute | Hunting Party | Capturer une créature en groupe | `IsInGroup()` à la résolution | ✅ | 5 | — |
| `soc_title` | Nom de scène | Stage Name | Choisir un titre pour sa fiche | `ns:TitleSet` (code > 0) | ✅ | 5 | — |

Hors numérotation (3.0.0, échanges de spécimens entre joueurs, `CaptureTrades.lua`) : `soc_trade_1` (code 178) — Premier échange / First Trade — conclure un échange de spécimens avec un autre joueur : `streak` `trades` ≥ 1, compte, 5 points ; `soc_trade_10` (code 179) — Marchand de créatures / Creature Merchant — conclure 10 échanges : `streak` `trades` ≥ 10, compte, 10 points ; `soc_trade_new` (code 180) — Venu d'ailleurs / From Far Away — recevoir par échange une espèce jamais capturée (aucune version de l'espèce dans la collection avant l'échange) : `flag` `tradeNew`, compte, 10 points. Compteur et drapeau posés quand l'échange est conclu (validation des deux côtés, puis engagement) ; pas de rattrapage (aucun échange avant la 3.0).

### 2.6 Personnage (`char`) — 21

Les numéros entre crochets sont les statistiques du client (§2.13).

| id | FR | EN | Condition | Détection | F | Pts | Récompense |
|---|---|---|---|---|---|---|---|
| `char_level_10` | Premiers pas | First Steps | Niveau 10 | `UnitLevel` ; relevé `level:10` | ✅ | 5 | — |
| `char_level_20` | Sur la route | On the Road | Niveau 20 | idem | ✅ | 5 | — |
| `char_level_30` | À mi-chemin | Halfway There | Niveau 30 | idem | ✅ | 10 | — |
| `char_level_40` | En selle | In the Saddle | Niveau 40 | idem | ✅ | 10 | — |
| `char_level_50` | Vétéran | Veteran | Niveau 50 | idem | ✅ | 10 | — |
| `char_level_60` | Au sommet | At the Summit | Niveau 60 | idem | ✅ | 25 | titre T21 |
| `char_gold_100` | Bourse ronde | A Round Purse | Avoir possédé 100 po | stat [334] ; alt : plus haut `GetMoney()` vu | ✅ | 10 | — |
| `char_gold_1000` | Fortune de prince | A Prince's Fortune | Avoir possédé 1000 po | idem | ✅ | 25 | titre T22 |
| `char_gold_looted` | Fouilleur de poches | Pocket Picker | 100 po ramassées sur les ennemis | stat [333] | ✅ | 10 | — |
| `char_mount` | Au galop | At a Gallop | Chevaucher sa propre monture | `IsMounted()` vu une fois sur ce personnage, hors taxi (`UnitOnTaxi`) et véhicule (`UnitInVehicle`) ; plus de stat [339] depuis la 3.0.0 bêta 6 (elle compte la collection du compte : un niveau 11 l'obtenait), obtenu avant = gardé | ✅ | 10 | — |
| `char_mount_epic` | Le vent dans la crinière | Wind in the Mane | Chevaucher une monture rapide | `IsMounted()` et `GetUnitSpeed("player")` ≥ 13,5 m/s au sol, hors vol en taxi | ⚠️ | 25 | — |
| `char_flight_25` | Passager du ciel | Sky Passenger | 25 trajets en griffon/wyverne | stat [349] ; alt : `UnitOnTaxi` faux → vrai | ✅ | 10 | — |
| `char_hearth_50` | Retour au bercail | Homeward Bound | 50 retours par pierre de foyer | stat [353] | ✅ | 10 | — |
| `char_kills_1000` | Mille adversaires | A Thousand Foes | 1000 créatures tuées | stat [107] ; alt : abattus du bestiaire | ✅ | 10 | — |
| `char_kills_10000` | Dix mille adversaires | Ten Thousand Foes | 10 000 créatures tuées | idem | ✅ | 25 | — |
| `char_epic` | Reflets violets | Purple Glow | Ramasser un objet épique | stat [341] ≥ 1 (ou [342]) | ✅ | 10 | — |
| `char_deaths_1` | Ça arrive à tout le monde | It Happens | Mourir une fois | stat [60] ; alt : `PLAYER_DEAD` | ✅ | 5 | — |
| `char_deaths_100` | Abonné du cimetière | Graveyard Regular | 100 morts | idem | ✅ | 10 | titre T23 |
| `char_camp_25` | Veillée | Fireside | 25 haltes au feu de camp (mécanique de Forever) | stat [64222] | ✅ | 10 | fond `feat_campfire` |
| `char_food_500` | Bon appétit | Bon Appétit | 500 repas et boissons | stat [347] + [346] | ⚠️ | 10 | — |
| `char_potions_100` | Pharmacie ambulante | Walking Apothecary | 100 potions, élixirs ou flacons | stat [345] + [922] + [923] + [811] | ⚠️ | 10 | — |

### 2.7 Donjons et raids (`dng`) — 21

Boss de référence : celui qui a une statistique de victoires dans le DB2 de Forever (souvent le boss final ; pour le Gouffre de Ragefeu, c'est Bazzalan). Chaque sous-critère de liste est vrai si **l'une** des sources le dit : statistique > 0, ou `ENCOUNTER_END` (succès) de la rencontre, ou `UNIT_DIED` / `PARTY_KILL` du npcID du boss en instance (même chemin que les rares du carnet). Les identifiants de rencontre et les npcID seront générés par `tools/gen_dungeons.py` depuis les tables `DungeonEncounter` et `Creature` de wago.tools (build 1.60.1.70753), pas écrits à la main.

| id | FR | EN | Condition | Détection | F | Pts | Récompense |
|---|---|---|---|---|---|---|---|
| `dng_visit_1` | Dans le noir | Into the Dark | Entrer dans un donjon | relevés `dungeon` | ✅ | 5 | Lasso ×1 |
| `dng_visit_10` | Habitué des profondeurs | Deep Regular | 10 donjons différents | idem | ✅ | 10 | Sifflet ×1 |
| `dng_visit_20` | Rien ne m'arrête | Nothing Stops Me | 20 donjons différents | idem | ✅ | 25 | — |
| `dng_visit_all` | Explorateur des abîmes | Deepdelver | Les 28 donjons de `DungeonData.lua` | idem ∩ `ns.DUNGEONS` | ✅ | 50 | titre T24 |
| `dng_runs_50` | Carte de fidélité | Loyalty Card | 50 entrées en donjon | stat [932] | ✅ | 10 | — |
| `dng_tier1` | Premières profondeurs | First Depths | Ragefeu (Bazzalan [15027]), Lamentations (Mutanus [15028]), Mortemines (VanCleef [63570]), Ombrecroc (Arugal [1092]), Prison (Bazil Thredd [15029]), Brassenoire (Aku'mai [6137]), Salle des Thanes (Durgen Dirgehammer [63573]), Ruines de Lordaeron (Rath'mael [63571]) | liste : stat / rencontre / npcID | ⚠️ | 10 | Lasso ×2 |
| `dng_tier2` | Galeries et cryptes | Halls and Crypts | Gnomeregan (Thermaplugg [6140]), Kraal (Charlga [6139]), Monastère (Whitemane [6786] ou Mograine [1093]), Souilles (Amnennar [6141]), Cité de Dalaran (Ombre de l'archimage [63572]), Site de fouilles des Paluns, Cité engloutie | liste ; les 2 derniers sans stat : boss à relever, repli sur l'entrée (relevé) tant qu'il manque | ⚠️ | 10 | Lasso ×2 |
| `dng_tier3` | Ruines oubliées | Forgotten Ruins | Uldaman (Archaedas [6142]), Zul'Farrak (Ukorz [1094]), Maraudon (Theradras [6143]), Temple englouti (Ombre d'Eranikus [6144]), Bastion de Krol'dok (repli entrée), Prison d'Alcaz (Blazeroar [63575]) | liste | ⚠️ | 25 | Sifflet ×1 |
| `dng_tier4` | Les grands bastions | The Great Strongholds | Profondeurs de Blackrock (Thaurissan [1095]), Bas-Spire (Wyrmthalak [6145]), Haut-Spire (Drakkisath [1096]), Hache-Tripes (Gordok [6146]), Scholomance (Gandling [15030]), Stratholme (Rivendare [1097] ou [15031]), Blackmaw Hold (repli entrée), Terrasse du Façonneur (Nanaya [63574]) | liste | ⚠️ | 25 | Sifflet ×1 |
| `dng_raid_enter` | Quarante en file | Forty Strong | Entrer dans un raid | `GetInstanceInfo()` de type `raid` ; stat [64184]/[934] | ✅ | 10 | — |
| `dng_raid_ony` | La reine noire tombe | The Black Queen Falls | Vaincre Onyxia | stat [1098] ; rencontre / npcID | ✅ | 25 | — |
| `dng_raid_mc` | Éteindre le Seigneur du feu | Put Out the Firelord | Vaincre Ragnaros (Cœur du Magma) | rencontre / npcID (pas de stat) | ⚠️ | 25 | — |
| `dng_raid_zg` | Le Dieu sanglant déchu | The Blood God Falls | Vaincre Hakkar (Zul'Gurub) | rencontre / npcID | ⚠️ | 25 | — |
| `dng_raid_bwl` | L'ombre dissipée | The Shadow Lifted | Vaincre Nefarian (Repaire de l'Aile noire) | rencontre / npcID | ⚠️ | 25 | — |
| `dng_raid_aq20` | Sables apaisés | Quiet Sands | Vaincre Ossirian (Ruines d'Ahn'Qiraj) | rencontre / npcID | ⚠️ | 25 | — |
| `dng_raid_aq40` | L'œil se ferme | The Eye Closes | Vaincre C'Thun (Temple d'Ahn'Qiraj) | rencontre / npcID | ⚠️ | 50 | ornement `feat_eye` |
| `dng_raid_naxx` | La nécropole se tait | The Necropolis Falls Silent | Vaincre Kel'Thuzad (Naxxramas) | rencontre / npcID | ⚠️ | 50 | titre T25 |
| `dng_raid_hyjal` | La couronne sauvage | The Wild Crown | Vaincre le Roi sauvage (Sommet d'Hyjal, raid de Forever) | stat [63580] ; rencontre / npcID | ⚠️ | 25 | ornement `feat_wildcrown` |
| `dng_raid_barrow` | Les tertres apaisés | The Barrows at Rest | Vaincre Sonya Darkhallow (Profondeurs des Tertres, raid de Forever) | stat [63581] ; rencontre / npcID | ⚠️ | 25 | — |
| `dng_world_boss` | Plus gros que moi | Bigger Than Me | Vaincre un boss du monde | `BestiaryOnKill`, `class == "worldboss"` | ✅ | 25 | — |
| `dng_capture_inside` | Souvenir de donjon | Dungeon Keepsake | Capturer une créature dans un donjon | `ns:InInstance()` à la résolution | ✅ | 10 | — |

### 2.8 Métiers (`prof`) — 12

| id | FR | EN | Condition | Détection | F | Pts | Récompense |
|---|---|---|---|---|---|---|---|
| `prof_first` | Un métier en main | A Trade in Hand | Apprendre un métier principal | `ns:ReadProfessions()` (clé hors cuisine, pêche, secourisme) ; stat [1199] | ✅ | 5 | — |
| `prof_150` | Compagnon d'atelier | Workshop Hand | Un métier principal à 150 | `rank` de `ReadProfessions` / `PlayerProfessions` | ✅ | 10 | — |
| `prof_225` | Main sûre | Steady Hand | Un métier principal à 225 | idem | ✅ | 10 | — |
| `prof_300` | Chef-d'œuvre | Masterwork | Un métier principal à 300 | idem ; stats [1527]…[1544] en rattrapage | ✅ | 25 | titre T26 |
| `prof_double_300` | Double casquette | Two Hats | Deux métiers principaux à 300 | idem ; stat [1201] ≥ 2 | ✅ | 25 | titre T27 |
| `prof_cook_300` | Toque étoilée | Starred Toque | Cuisine à 300 | idem ; stat [1524] | ✅ | 10 | titre T28 |
| `prof_fish_300` | Patience au bord de l'eau | Patience by the Water | Pêche à 300 | idem ; stat [1519] | ✅ | 10 | titre T29 |
| `prof_aid_300` | Mains qui soignent | Healing Hands | Secourisme à 300 | idem ; stat [281] | ✅ | 10 | — |
| `prof_secondary_all` | Bon à tout | Handy | Cuisine, pêche et secourisme à 300 | méta des 3 ; stat [1200] ≥ 3 | ✅ | 25 | — |
| `prof_fish_250` | Ça mord ! | They're Biting! | 250 poissons pêchés | stat [1518] (ou [1456]) | ⚠️ | 10 | — |
| `prof_gather_100` | Panier plein | Full Basket | 100 récoltes | `GatheringData()` (total) | ✅ | 5 | — |
| `prof_gather_1000` | Herbier d'Azeroth | Azeroth Herbarium | 1000 récoltes | idem | ✅ | 10 | — |

### 2.9 Quêtes, réputations et honneur (`quest`) — 11

| id | FR | EN | Condition | Détection | F | Pts | Récompense |
|---|---|---|---|---|---|---|---|
| `quest_10` | Petits services | Odd Jobs | 10 quêtes rendues | stat [98] ; alt : `QUEST_TURNED_IN` | ✅ | 5 | — |
| `quest_100` | Carnet de commandes | Order Book | 100 quêtes | idem | ✅ | 10 | — |
| `quest_500` | Toujours partant | Always Up for It | 500 quêtes | idem | ✅ | 25 | — |
| `quest_1000` | Mille et une quêtes | A Thousand and One Quests | 1000 quêtes | idem | ✅ | 50 | titre T30 |
| `quest_valthalak` | Repos pour Valthalak | Rest for Valthalak | Finir la chaîne de Lord Valthalak (de *An Earnest Proposition* à *Saving the Best for Last*) | `C_QuestLog.IsQuestFlaggedCompleted(id de la dernière quête)`, id à relever sur wago (`QuestV2`) | ⚠️ | 25 | — |
| `rep_honored_10` | Bonne réputation | Good Standing | 10 factions à Honoré ou plus | stat [529] ; alt : `C_Reputation` / `GetFactionInfo` | ✅ | 10 | — |
| `rep_exalted_1` | Ami pour la vie | Friend for Life | Une faction à Exalté | stat [377] ; alt : idem | ✅ | 10 | — |
| `rep_exalted_5` | Le bienvenu | Welcome Everywhere | 5 factions à Exalté | idem | ✅ | 25 | titre T31 |
| `pvp_hk_100` | Honneur rendu | Honor Due | 100 victoires honorables | stat [588] | ✅ | 10 | — |
| `pvp_bg_win` | Drapeau planté | Flag Planted | Gagner un champ de bataille | stat [840] | ⚠️ | 10 | — |
| `pvp_duel_10` | Pour l'honneur | For Honour's Sake | Gagner 10 duels | stat [319] | ⚠️ | 5 | — |

### 2.10 Insolite (`fun`) — 15

| id | FR | EN | Condition | Détection | F | Pts | Récompense |
|---|---|---|---|---|---|---|---|
| `fun_name` | Baptême | Christening | Donner un nom à sa mascotte | `CompanionData().name` posé | ✅ | 5 | — |
| `fun_dance` | Danse avec les bêtes | Dances with Beasts | Danser 10 fois avec le compagnon affiché | `hooksecurefunc("DoEmote")` (`DANCE`) + compagnon visible | ✅ | 5 | — |
| `fun_hogger_kill` | Pas peur de Lardeur | Not Afraid of Hogger | Vaincre Lardeur | `BestiaryOnKill`, npcID 448 | ✅ | 10 | — |
| `fun_hogger_capture` | Lardeur en laisse | Hogger on a Leash | Capturer Lardeur | fiche de capture npcID 448 | ✅ | 10 | titre T32 |
| `fun_hogger_death` | Lardeur a gagné | Hogger Wins | Être tué par Lardeur | stat [594] | ⚠️ | 5 | — |
| `fun_murlocs` | Mrgl mrgl ! | Mrgl Mrgl! | Capturer 5 murlocs différents | nom de la fiche (FR et EN) contient « murloc » | ✅ | 10 | titre T33 |
| `fun_critter` | Petite bête | Little Critter | Capturer une bestiole | fiche `class` `trivial`/`minus` ou type « Bestiole »/« Critter » | ✅ | 5 | — |
| `fun_critters_kill` | Pas les lapins ! | Not the Bunnies! | Tuer 50 bestioles | stat [108] | ⚠️ | 5 | — |
| `fun_drown` | Respirer, c'est surfait | Breathing Is Overrated | Mourir noyé | stat [112] | ⚠️ | 5 | — |
| `fun_fall` | La gravité gagne toujours | Gravity Always Wins | Mourir d'une chute | stat [114] | ⚠️ | 5 | — |
| `fun_lava` | Ça chauffe ! | Feeling the Heat | Mourir dans le feu ou la lave | stat [115] | ⚠️ | 5 | — |
| `fun_emotes` | Expressif | Expressive | 100 émotes (câlins, acclamations, saluts, rires, violon, paume au front) | stats [1042] + [1045] + [1047] + [1065] + [1066] + [1067] ; alt : `DoEmote` | ✅ (alt) / ⚠️ | 5 | — |
| `fun_night_owl` | Oiseau de nuit | Night Owl | Capturer entre 2 h et 5 h (heure locale) | `date("%H")` à la résolution | ✅ | 5 | titre T34 |
| `fun_birthday` | Joyeux anniversaire | Happy Birthday | Jouer le jour anniversaire de la rencontre avec le compagnon | `CompanionData().since` (jour et mois) | ✅ | 10 | — |
| `fun_respec` | Changement de cap | Change of Heart | Réinitialiser ses talents | stat [1149] ≥ 1 | ✅ | 5 | — |

Hors numérotation (après les 173) : `fun_unlucky` (code 174) — La poisse / Rotten Luck — mourir une fois, noyé, d'une chute et dans le feu ou la lave : `meta` (`char_deaths_1`, `fun_drown`, `fun_fall`, `fun_lava`), compte, 5 points, titre T39. ⚠️ tant que les stats [112], [114] et [115] ne sont pas confirmées (le moteur refuse une ligne sans points : elle en vaut 5).

Hors numérotation : `fun_winter_veil` (code 175) — Joyeux Voile d'hiver / Merry Winter Veil — une heure ou 10 captures avec un compagnon de saison, pendant le Voile d'hiver : `flag` `winterVeil`, compte, 10 points.

### 2.11 Grands hauts faits (`meta`) — 8

| id | FR | EN | Condition | Détection | F | Pts | Récompense |
|---|---|---|---|---|---|---|---|
| `meta_menagerie` | Maître des lieux | Master of the House | 20 hauts faits de Créatures | `meta` (cat `men`, 20) | ✅ | 50 | titre T35 |
| `meta_shiny` | Tout ce qui brille | All That Glitters | 10 hauts faits de Brillantes | `meta` (cat `shiny`, 10) | ✅ | 25 | cadre `feat_prism` |
| `meta_zones` | Sceaux et chemins | Seals and Roads | 15 hauts faits de Zones et sceaux | `meta` (cat `zone`, 15) | ✅ | 25 | fond de fiche `card_atlas` |
| `meta_dungeons` | Terreur des cachots | Dread of the Dungeons | Les 4 paliers de donjons | `meta` (`dng_tier1`…`dng_tier4`) | ⚠️ | 50 | titre T36 |
| `meta_hero` | Héros d'Azeroth | Hero of Azeroth | Niveau 60, 5 hauts faits de Donjons et raids, 3 de Métiers, 3 de Quêtes | `meta` composé | ✅ | 50 | titre T37 ; cadre de fiche `card_laurels` |
| `meta_points_500` | Un nom qui circule | Making a Name | 500 points | `points` | ✅ | 10 | — |
| `meta_points_1500` | Renommée | Renown | 1500 points | `points` | ✅ | 25 | fond de fiche `card_renown` |
| `meta_trainer` | Dresseur de légende | Legendary Trainer | `meta_menagerie`, `meta_shiny`, `meta_zones` et 1000 points | `meta` + `points` | ✅ | 50 | titre T38 ; fond de fiche `card_pantheon` |

**Total : 173 hauts faits.** (Comptes et points par catégorie en §2.14.)

> Note de taille : 173 dépasse un peu la fourchette visée (120–160). La catégorie la plus facile à alléger est Insolite (15) ; on peut aussi publier les hauts faits ⚠️ de statistiques en second temps, après le test en jeu (§5.2).

### 2.12 Exclus (❌)

| Idée | Pourquoi |
|---|---|
| Miroir des hauts faits natifs de Forever (Explorer Azeroth 62053, Spelunker, Novice/Experienced/Master par classe, métiers 150/225/300, rangs JcJ, Master of …) | `GetAchievementInfo` est une coquille vide sur Forever (test du 2026-11-07) |
| « Cartographe » (toute la carte révélée) | pas de total fiable des recouvrements de carte sans `GetAchievementInfo` ; `C_MapExplorationInfo` demanderait une table générée par zone : remplacé par `zone_visit_all` |
| Plus gros coup porté / soin, dégâts totaux, coups fatals | journal de combat fermé ; stats [193] [189] [197] existent mais n'ont rien à voir avec l'esprit de QC (on peut les ajouter plus tard) |
| Rangs JcJ (Sergent…) | `UnitPVPRank` non éprouvée et aucune stat de rang ; à revoir après test |
| Exalté auprès d'une faction précise (Grumegueule, champs de bataille) | demande `C_Reputation` par faction : ⚠️ ; mis de côté tant que l'API n'est pas vérifiée (les stats [377]/[529] ne disent pas laquelle) |
| Baron en 45 minutes, donjon sans mort | pas de minuterie fiable d'instance, morts de groupe non lisibles |
| Temps de jeu (`/played`) | `RequestTimePlayed` écrit dans le chat de tout le monde : bruit |
| Mascottes (vanity pets) possédées | stat [338] ⚠️ mais les mascottes de Forever sont des objets ; peu de sens à côté de la ménagerie |

### 2.13 Statistiques natives employées

Relevé en jeu du 2026-11-07 (client frFR de Forever, `GetStatistic` rend trois valeurs : la valeur, un booléen, l'id ; « -- » = 0, l'or s'écrit avec des icônes `|T…|t` entre les nombres) : ✅ = lisible ; les autres restent ⚠️ « valeur à confirmer en jeu ». 107 ✅ rend `780`. `/qc hf diag` les imprime toutes, avec leur valeur lue et sa forme brute.

| Stat | Libellé du client | Sert à |
|---|---|---|
| 60 ✅ | Total deaths | `char_deaths_*` |
| 98 ✅ | Quests completed | `quest_*` |
| 107 ✅ | Creatures killed | `char_kills_*` |
| 108 | Critters killed | `fun_critters_kill` |
| 112 / 114 / 115 | Deaths from drowning / falling / fire and lava | `fun_drown`, `fun_fall`, `fun_lava` |
| 281 | First Aid skill | `prof_aid_300` |
| 319 | Duels won | `pvp_duel_10` |
| 333 ✅ | Gold looted | `char_gold_looted` (montant d'argent) |
| 334 ✅ | Most gold ever owned | `char_gold_*` (montant d'argent) |
| 339 ✅ | Mounts owned | plus employée (3.0.0 bêta 6 : collection du compte, pas le personnage ; `char_mount` = `IsMounted()` hors taxi) |
| 341 ✅ / 342 | Epic items looted / acquired | `char_epic` |
| 345 / 922 / 923 / 811 | Health potions / Mana potions / Elixirs / Flasks | `char_potions_100` |
| 346 / 347 | Beverages consumed / Food eaten | `char_food_500` |
| 349 ✅ | Flight paths taken | `char_flight_25` |
| 353 ✅ | Number of times hearthed | `char_hearth_50` |
| 377 ✅ | Most factions at Exalted | `rep_exalted_*` |
| 529 ✅ | Most factions at Honored or higher | `rep_honored_10` |
| 588 ✅ | Total Honorable Kills | `pvp_hk_100` |
| 594 | Deaths from Hogger | `fun_hogger_death` |
| 840 | Battlegrounds won | `pvp_bg_win` |
| 932 ✅ | Total 5-player dungeons entered | `dng_runs_50` |
| 934 / 64184 | Total 20 / 40-player raids entered | `dng_raid_enter` (rattrapage) |
| 1042 / 1045 / 1047 / 1065 / 1066 / 1067 | Hugs / Cheers / Facepalms / Waves / LOL / World's smallest violin | `fun_emotes` |
| 1149 ✅ | Talent tree respecs | `fun_respec` |
| 1199 | Professions learned | `prof_first` |
| 1200 | Secondary skills at maximum skill | `prof_secondary_all` |
| 1201 | Professions at maximum skill | `prof_double_300` |
| 1518 / 1456 | Fish caught / Fish and other things caught | `prof_fish_250` |
| 1519 | Fishing skill | `prof_fish_300` |
| 1524 ✅ | Cooking skill | `prof_cook_300` |
| 1527 / 1532 / 1535 / 1536 / 1537 ✅ / 1538 / 1541 / 1542 / 1544 | Highest Alchemy / Blacksmithing / Enchanting / Leatherworking / Mining / Herbalism / Skinning / Tailoring / Engineering skill | `prof_150/225/300` (rattrapage) |
| 64222 ✅ | Times camped (« Times gathered around the campfire ») | `char_camp_25` |
| Boss : 15027 ✅, 15028, 63570 ✅, 1092, 15029, 6137, 63573 ✅, 63571 | Bazzalan, Mutanus, VanCleef, Arugal, Bazil Thredd, Aku'mai, Durgen Dirgehammer, Rath'mael | `dng_tier1` |
| Boss : 6140, 6139, 6786, 1093, 6141, 63572 | Thermaplugg, Charlga, Whitemane, Mograine, Amnennar, Shade of the Archmage | `dng_tier2` |
| Boss : 6142, 1094, 6143, 6144, 63575 | Archaedas, Ukorz, Theradras, Shade of Eranikus, Blazeroar | `dng_tier3` |
| Boss : 1095, 6145, 1096, 6146, 15030, 1097, 15031, 63574 | Thaurissan, Wyrmthalak, Drakkisath, Gordok, Gandling, Rivendare (×2), Nanaya | `dng_tier4` |
| Boss : 1098 ✅, 63580, 63581 | Onyxia, The Wild King, Sonya Darkhallow | raids |

Rien pour Ragnaros, Hakkar, Nefarian, Ossirian, C'Thun, Kel'Thuzad (pas de ligne de statistique de victoires dans le DB2) : rencontre et npcID seulement. Les statistiques « Survivor of … » (15330…) sont des lignes du mode Hardcore, pas des compteurs de victoires : non employées.

### 2.14 Récapitulatif

| Catégorie | Hauts faits | Points |
|---|---|---|
| Ménagerie | 29 | 425 |
| Brillantes | 12 | 230 |
| Zones et sceaux | 23 | 460 |
| Au jour le jour | 14 | 190 |
| Guilde et entraide | 7 | 40 |
| Personnage | 21 | 255 |
| Donjons et raids | 21 | 490 |
| Métiers | 12 | 155 |
| Quêtes, réputations et honneur | 11 | 185 |
| Insolite | 15 | 95 |
| Grands hauts faits | 8 | 285 |
| **Total** | **173** | **2810** |

Hors numérotation : `fun_unlucky` (Insolite, 5 points, §2.10), `fun_winter_veil` (Insolite, 10 points, saisonnier), `men_size_giant` et `men_size_tiny` (Créatures, 10 points chacun, 3.1.0), `soc_trade_1`, `soc_trade_10` et `soc_trade_new` (Guilde et entraide, 5, 10 et 10 points, 3.0.0), soit 180 lignes et 2870 points implémentés (état : §6).

Faisabilité : 126 ✅, 9 « ✅ (alt) / ⚠️ » (statistique d'abord, notre propre suivi sinon : sûrs dans tous les cas) et 38 ⚠️ (34 dépendent d'une statistique ou d'une rencontre de boss ; 4 d'une autre vérification : vitesse de monture, uiMapID des zones propres à Forever ×2, id de la dernière quête de Valthalak). Sans aucune statistique lisible, 135 hauts faits restent atteignables.

---

## 3. Conversion des tampons

**Règle** : rien n'est supprimé. `char.journal.stamps` reste la table des **relevés de lieux** (zones, villages, capitales, donjons, rares, paliers de niveau), toujours remplie par `ns:JournalEarn`, mais **sans bandeau ni ligne de chat** : `JournalNotify` n'est plus appelé, le chat « Nouveau tampon » disparaît. Le callback `STAMP` reste émis (les aides de capture tirées sur un relevé, `CaptureOnStamp`, et les réactions du compagnon continuent : on ne perd pas cette source d'aides). `ns:JournalCounts()` ne change pas (cosmétiques `unlock = { stamp = … }`, suivi à l'écran).

**Migration** (`feats.v == nil`, une fois par personnage, sous `pcall`, avant le rattrapage) :
1. Pour chaque haut fait qui se déduit des relevés, on calcule s'il est acquis et **à quelle date** :
   - haut fait lié à **un** relevé : sa date (`at`) et son niveau (`level`) ;
   - haut fait de **compte** (N relevés d'une sorte) : la date du N-ième relevé dans l'ordre chronologique (`at`) ;
   - **liste** (6 capitales, 28 donjons) : la date du dernier relevé qui la complète.
2. `collection.ranks[count]` (date du palier d'espèces) → date de `men_species_<count>`.
3. Les autres (brillantes, missions, sceaux…) : date = maintenant, `r = true`.
4. Un relevé marqué `retro` donne un haut fait `r = true`. Tout ce qui est migré est silencieux.
5. `journalChat` → `featChat`.

| Relevé (sorte : clé) | Haut(s) fait(s) | Date reprise |
|---|---|---|
| `level:10`, `level:20`, `level:30`, `level:40`, `level:50`, `level:60` | `char_level_10` … `char_level_60` | celle du relevé |
| `zone:<uiMapID>` (tous) | `zone_visit_10` (10e), `zone_visit_25` (25e) | du N-ième |
| `zone:<uiMapID>` ∈ 41 zones extérieures | `zone_visit_all` (liste) | du dernier qui complète |
| `zone:<uiMapID>` ∈ {Riverglades, Mont Hyjal, Shen'dralas} | `zone_forever_new` | du dernier des 3 |
| `zone:*` des deux continents le même jour | `zone_two_continents` | du premier jour où c'est vrai |
| `subzone:<areaID>` | `zone_villages_10` (10e), `zone_villages_25` (25e) | du N-ième |
| `capital:1519` (Hurlevent ; le groupe garde le plus petit areaID, 16509 s'y rattache), `capital:1537`, `capital:1657`, `capital:1637`, `capital:1638`, `capital:1497` | `zone_capitals` (sous-critère par capitale) | du dernier des 6 |
| `capital:<id>` de l'autre faction (`Hubs.lua` : `faction`) | `zone_capital_enemy` | du premier |
| `dungeon:<clé>` (clé de `ns.DUNGEONS`) | `dng_visit_1` (1er), `dng_visit_10` (10e), `dng_visit_20` (20e), `dng_visit_all` (les 28) ; repli d'entrée des sous-critères sans boss connu de `dng_tier2/3/4` | du N-ième / du dernier |
| `dungeon:i<instanceID>` ou `dungeon:<nom>` (donjon hors base) | comptent pour `dng_visit_1/10/20`, pas pour `dng_visit_all` | du N-ième |
| `rare:<npcID>` | `day_rare_1` (1er), `day_rare_10` (10e), `day_rare_50` (50e) | du N-ième |

Retour en 2.6 possible : la 2.6 relit `journal.stamps` intact et ignore `feats`.

---

## 4. Récompenses

### 4.1 Titres (43)

### 4.1 Titres (49)

« — » en colonne féminine : forme épicène (la même). P = préfixe, S = suffixe.

| Code | Haut fait source | FR masculin | FR féminin | EN | P/S |
|---|---|---|---|---|---|
| T1 | `men_species_10` | Apprenti dresseur %s | Apprentie dresseuse %s | Apprentice Trainer %s | P |
| T2 | `men_species_25` | Dresseur %s | Dresseuse %s | Trainer %s | P |
| T3 | `men_species_50` | Dresseur confirmé %s | Dresseuse confirmée %s | Seasoned Trainer %s | P |
| T4 | `men_species_100` | Maître dresseur %s | Maîtresse dresseuse %s | Master Trainer %s | P |
| T5 | `men_species_250` | Grand maître dresseur %s | Grande maîtresse dresseuse %s | Grand Master Trainer %s | P |
| T6 | `men_species_500` | %s l'Arpenteur des bêtes | %s l'Arpenteuse des bêtes | %s the Beastwalker | S |
| T7 | `men_rare_10` | %s le Collectionneur | %s la Collectionneuse | %s the Collector | S |
| T8 | `men_type_dragonkin` | %s le Dompteur de dragons | %s la Dompteuse de dragons | %s the Dragon Tamer | S |
| T9 | `men_type_demon` | %s le Lieur de démons | %s la Lieuse de démons | %s the Demonbinder | S |
| T10 | `men_types_master` | %s, Maître des huit familles | %s, Maîtresse des huit familles | %s, Master of the Eight Families | S |
| T11 | `men_stars3_100` | %s l'Esthète | — | %s the Connoisseur | S |
| T12 | `shiny_found_50` | %s le Chasseur de brillantes | %s la Chasseuse de brillantes | %s the Shiny Hunter | S |
| T13 | `shiny_cap_25` | %s, Maître des brillantes | %s, Maîtresse des brillantes | %s, Master of Shinies | S |
| T14 | `zone_seal_15` | %s le Gardien des sceaux | %s la Gardienne des sceaux | %s the Seal Keeper | S |
| T15 | `zone_all_biomes` | %s le Globe-trotteur | %s la Globe-trotteuse | %s the Globetrotter | S |
| T16 | `zone_visit_all` | %s l'Arpenteur | %s l'Arpenteuse | %s the Wayfarer | S |
| T17 | `zone_capitals` | Ambassadeur %s | Ambassadrice %s | Ambassador %s | P |
| T18 | `day_mission_100` | %s l'Infatigable | — | %s the Tireless | S |
| T19 | `day_rare_50` | %s le Traqueur | %s la Traqueuse | %s the Tracker | S |
| T20 | `day_days_365` | %s, Ami fidèle | %s, Amie fidèle | %s, Faithful Friend | S |
| T21 | `char_level_60` | %s l'Aventurier | %s l'Aventurière | %s the Adventurer | S |
| T22 | `char_gold_1000` | %s le Fortuné | %s la Fortunée | %s the Wealthy | S |
| T23 | `char_deaths_100` | %s le Revenant | %s la Revenante | %s the Revenant | S |
| T24 | `dng_visit_all` | %s l'Explorateur des abîmes | %s l'Exploratrice des abîmes | %s the Deepdelver | S |
| T25 | `dng_raid_naxx` | %s, Briseur de nécropole | %s, Briseuse de nécropole | %s the Necropolis Breaker | S |
| T26 | `prof_300` | %s aux mains d'or | — | %s the Goldhanded | S |
| T27 | `prof_double_300` | %s le Polyvalent | %s la Polyvalente | %s the Versatile | S |
| T28 | `prof_cook_300` | Chef %s | — | Chef %s | P |
| T29 | `prof_fish_300` | %s le Pêcheur | %s la Pêcheuse | %s the Fisher | S |
| T30 | `quest_1000` | %s, Mémoire des chemins | — | %s, Keeper of Paths | S |
| T31 | `rep_exalted_5` | %s le Bienvenu | %s la Bienvenue | %s the Welcome | S |
| T32 | `fun_hogger_capture` | %s, Dompteur de Lardeur | %s, Dompteuse de Lardeur | %s, Hogger's Handler | S |
| T33 | `fun_murlocs` | %s, Ami des murlocs | %s, Amie des murlocs | %s, Friend of Murlocs | S |
| T34 | `fun_night_owl` | %s le Noctambule | %s la Noctambule | %s the Night Owl | S |
| T35 | `meta_menagerie` | %s, Seigneur des créatures | %s, Dame des créatures | %s, Lord of the Creatures / %s, Lady of the Creatures | S |
| T36 | `meta_dungeons` | %s, Terreur des cachots | — | %s, Dread of the Dungeons | S |
| T37 | `meta_hero` | %s, Héros d'Azeroth | %s, Héroïne d'Azeroth | %s, Hero of Azeroth / %s, Heroine of Azeroth | S |
| T38 | `meta_trainer` | %s le Légendaire | %s la Légendaire | %s the Legendary | S |
| T39 | `char_deaths_1` + `fun_drown` + `fun_fall` + `fun_lava` (les 4) | %s le Malchanceux | %s la Malchanceuse | %s the Unlucky | S |
| T40 | `men_bad_luck` | %s, Bredouille | — | %s the Empty-Handed | S |
| T61 | `men_patron_10` | %s le Mécène | %s la Mécène | %s the Patron | S |
| T62 | `men_patron_50` | %s le Grand Mécène | %s la Grande Mécène | %s the Great Patron | S |
| T63 | `men_patron_100` | %s, Bienfaiteur des créatures | %s, Bienfaitrice des créatures | %s, Benefactor of Creatures | S |

| T41 | `men_species_750` | %s le Pisteur des terres sauvages | %s la Pisteuse des terres sauvages | %s the Wildtracker | S |
| T42 | `men_species_1000` | %s aux mille bêtes | — | %s of a Thousand Beasts | S |
| T43 | `men_species_1500` | %s le Gardien du bestiaire | %s la Gardienne du bestiaire | %s the Bestiary Warden | S |
| T44 | `men_species_2000` | %s le Sage des créatures | %s la Sage des créatures | %s the Creature Sage | S |
| T45 | `men_species_2500` | %s, Archiviste d'Azeroth | — | %s, Archivist of Azeroth | S |
| T46 | `men_species_3000` | %s le Grand Recenseur | %s la Grande Recenseuse | %s the Grand Census-Taker | S |
| T47 | `men_species_all` | %s, Dresseur de tout Azeroth | %s, Dresseuse de tout Azeroth | %s, Trainer of All Azeroth | S |
| T48 | `men_study_50` | %s le Savant | %s la Savante | %s the Scholar | S |
| T49 | `men_bond_inseparable` | %s l'Inséparable | — | %s the Inseparable | S |
| T59 | `zone_seal_all` | %s, Gardien d'Azeroth | %s, Gardienne d'Azeroth | %s, Guardian of Azeroth | S |
| T60 | `comp_radiant_3000` | %s le Rayonnant | %s la Rayonnante | %s the Radiant | S |
| T64 | `comp_wish_250` | %s l'Attentionné | %s l'Attentionnée | %s the Thoughtful | S |
| T65 | `comp_wardrobe_100` | %s l'Élégant | %s l'Élégante | %s the Elegant | S |
| T66 | `soc_trade_25` | %s le Marchand | %s la Marchande | %s the Merchant | S |
| T67 | `soc_mentor_10` | %s le Passeur | %s la Passeuse | %s the Torchbearer | S |
| T68 | `fos_pioneer` | %s le Pionnier | %s la Pionnière | %s the Pioneer | S |
| T69 | `meta_points_5000` | %s le Renommé | %s la Renommée | %s the Renowned | S |
| T70 | `meta_soc` | %s le Sociable | %s la Sociable | %s the Sociable | S |
| T71 | `meta_fun` | %s l'Original | %s l'Originale | %s the Eccentric | S |
| T72 | `meta_all` | Dresseur accompli %s | Dresseuse accomplie %s | Accomplished Trainer %s | P |

T41 à T49 : 3.6.0 (rangs de dresseur au-delà de 500 espèces, étude, lien). Les codes 61 à 63 sont pris par la 3.6 (mécénat).

T61 à T63 (3.6.0) viennent du mécénat ; les codes 41 à 60 restent libres pour les titres d'autres lots. T39 et T40 sont des titres pour rire : T39 se gagne par un petit `meta` de la catégorie Insolite (`fun_unlucky`, code 174, 5 points, hors des 173 numérotés : §2.10), T40 vient de `men_bad_luck`.

Choix retenu pour le genre : **formes masculine et féminine** quand le français les distingue (UnitSex, réglage manuel prioritaire), forme unique sinon. L'anglais n'a deux formes que pour T35 et T37.

### 4.2 Nouveaux cosmétiques

Les cosmétiques existants déplacés (cadres `trainer`, `master`, `sparkle` ; fonds `menagerie`, `grandmaster`, `stardust` ; ornement `aura` ; apparence `hippogryph`) gardent leurs ids et leurs dessins : seule leur condition passe au haut fait (`unlock = { feat = "<id>" }`, `tier = 0`, hors coffres).

**Compagnon** (catalogue `COMPANION_FRAMES` / `COMPANION_BACKGROUNDS` / `COMPANION_ORNAMENTS`) :

| id | Sorte | Nom FR / EN | Source | Fabrication |
|---|---|---|---|---|
| `feat_eight` | cadre | Cadre des huit familles / Frame of the Eight Families | `men_types_master` | sans texture : filet et filet intérieur (`edge`, `inner`) + bordure `UI-DialogBox-Gold-Border` ; huit petits losanges du thème aux couleurs des types posés sur le liseré (comme les ornements actuels) |
| `feat_prism` | cadre | Cadre prismatique / Prismatic Frame | `meta_shiny` | filet dégradé arc-en-ciel animé (teinte qui tourne dans `CompanionApplyOrnaments`, 0,1 Hz), bordure `UI-Tooltip-Border` blanche |
| `feat_atlas` | fond | Atlas / Atlas | `zone_100_10` | `Textures/feat_atlas.tga` 512×256 : parchemin, rose des vents, côtes stylisées, quadrillage ; `tools/gen_feat_assets.py` |
| `feat_campfire` | fond | Feu de camp / Campfire | `char_camp_25` | `Textures/feat_campfire.tga` 512×256 : nuit, braises (bruit lisse), halo orangé ; même outil |
| `feat_chain` | ornement | Chaîne du colosse / Colossus Chain | `men_boss_1` | `Textures/feat_ornaments.tga` 256×64, feuille de 4 cases de 64 px (chaîne, étoiles d'or, œil, couronne) découpées par `SetTexCoord` |
| `feat_goldstars` | ornement | Trois étoiles d'or / Three Gold Stars | `men_stars3_100` | feuille ci-dessus (ou la feuille `etoiles` de la 2.1 teintée or : rien de neuf à peindre) |
| `feat_prism_orn` | ornement | Prisme / Prism | `shiny_3stars` | particule « étincelle 6 » de `particules.tga` (2.1), teinte qui tourne |
| `feat_compass` | ornement | Boussole / Compass | `day_travel_1000` | réutilise la boussole de repli de `Companion.lua` (déjà là), en coin |
| `feat_anniversary` | ornement | Ruban d'anniversaire / Anniversary Ribbon | `day_days_365` | `ruban.tga` de la 2.1 teinté (rouge et or) |
| `feat_eye` | ornement | Œil clos / Closed Eye | `dng_raid_aq40` | feuille `feat_ornaments.tga` |
| `feat_wildcrown` | ornement | Couronne sauvage / Wild Crown | `dng_raid_hyjal` | feuille `feat_ornaments.tga` |

Note : l'id `feat_prism` existe en cadre et l'ornement s'appelle `feat_prism_orn` (les clés sont `kind:id`, mais on évite la confusion dans les chaînes).

**Fiche de dresseur** (sorte neuve, `TRAINER_CARD_BACKGROUNDS` / `TRAINER_CARD_FRAMES`, champs `cb` / `cf`, liste blanche à la réception, défaut = le fond actuel). **Livrés en 3.6.0** (`TrainerCardStyle.lua`) avec nos textures générées par `tools/gen_ui_assets.py` (`Libs/Socle/Media/fiche_*.tga` : fonds 256×128 opaques et sombres, cadres 64×64 en 9 tranches), et non les fabrications prévues ci-dessous :

| id | Sorte | Nom FR / EN | Source | Fabrication |
|---|---|---|---|---|
| `card_census` | fond de fiche | Registre des espèces / Species Ledger | `men_species_500` | `Textures/card_census.tga` 512×256 : page de registre, lignes, petites silhouettes de bêtes en filigrane |
| `card_atlas` | fond de fiche | Atlas des sceaux / Atlas of Seals | `meta_zones` | variante de `feat_atlas` avec sceaux de cire |
| `card_renown` | fond de fiche | Bannière de renom / Banner of Renown | `meta_points_1500` | atlas du client `achievement-wood-nineslice-*` (déjà vérifié) + dégradé ; aucune texture neuve |
| `card_pantheon` | fond de fiche | Panthéon / Pantheon | `meta_trainer` | `Textures/card_pantheon.tga` 512×256 : colonnade, rayons (`rayons.tga` de la 2.1 en `ADD`) |
| `card_crest_ek` | cadre de fiche | Blason de l'Est / Eastern Crest | `zone_seal_ek` | sans texture : liseré or + écusson losange du thème |
| `card_crest_ka` | cadre de fiche | Blason de Kalimdor / Kalimdor Crest | `zone_seal_ka` | idem, autre teinte |
| `card_laurels` | cadre de fiche | Lauriers / Laurels | `meta_hero` | `Textures/card_laurels.tga` 256×64 (deux branches en miroir) |

Fabrication : un seul outil neuf `tools/gen_feat_assets.py` (numpy + Pillow, **déterministe** : graine fixe, sortie identique octet pour octet, comme `gen_capture_assets.py` et `gen_seal_scenes.py`), TGA 32 bits non compressés en puissances de deux, `--apercu DIR` pour une planche PNG non versionnée. Budget : 5 TGA 512×256 (512 Ko chacun) + 2 de 256×64 ≈ 2,6 Mo ; à réduire si besoin en 256×128 pour les fonds de fiche (affichés petits). Aucune image de Blizzard embarquée : atlas et textures du client appelés par nom ou chemin.

### 4.3 Aides de capture

| Aide | Hauts faits (× quantité) | Total |
|---|---|---|
| Appât savoureux (`appat`, plafond 10) | `men_first` ×1, `men_species_10` ×1, `men_stars3_25` ×2, `men_bad_luck` ×3, `zone_visit_10` ×1 | 8 |
| Lasso tressé (`lasso`, plafond 5) | `men_species_10` ×1, `men_rare_1` ×1, `men_types_t1` ×1, 6 types au palier 3 ×1 (bête, humanoïde, mort-vivant, élémentaire, géant, mécanique), `shiny_cap_1` ×1, `zone_seal_1` ×1, `zone_visit_25` ×1, `day_mission_25` ×1, `day_rare_10` ×1, `dng_visit_1` ×1, `dng_tier1` ×2, `dng_tier2` ×2 | 19 |
| Sifflet du dompteur (`sifflet`, plafond 3) | `men_species_50` ×1, `men_species_100` ×1, `men_species_250` ×2, `shiny_cap_10` ×1, `zone_seal_5` ×1, `zone_chests_10` ×1, `dng_visit_10` ×1, `dng_tier3` ×1, `dng_tier4` ×1 | 10 |

Au rattrapage, les aides sont données comme le reste ; avec les plafonds, un joueur avancé en perd une partie (besace pleine). Les aides des paliers d'espèces sont les mêmes qu'aujourd'hui : pas de double don pour qui les a déjà reçues (`collection.ranks` marque le palier comme payé ; la migration ne redonne rien pour ces 5 hauts faits).

---

## 5. Questions ouvertes et plan

### 5.1 Décisions

Les recommandations par défaut sont toutes retenues (2026-11-07) :

1. **Portée mixte** : « collection = compte, performance = personnage » (§1.3). Compte : Ménagerie, Brillantes (agrégées sur tous les personnages), Grands hauts faits et paliers de points, Guilde et entraide, l'essentiel d'Insolite ; les titres gagnés ainsi servent sur tous les personnages. Personnage : Personnage, Donjons et raids, Métiers, Quêtes/réputations/honneur, Zones et sceaux, exploration, missions. La page marque la portée de chaque ligne ; la fiche de dresseur montrera les points de compte et ceux du personnage (`ns:AchievementPoints("account" | "char")`, câblage au lot D).
2. **Bandeau « Nouveau tampon » supprimé** : les tampons deviennent des relevés silencieux ; les aides de capture qu'ils donnent restent (`STAMP` toujours émis).
3. **Titres genrés** (masculin / féminin selon `UnitSex`) avec réglage manuel prioritaire : lot D ; le modèle de données est prêt (`feats.form`, formes `m` / `f` / `en` / `enf` du registre `ns.FEAT_TITLES`).
4. **Hauts faits ⚠️ affichés grisés** « détection bientôt disponible » (drapeau `pending` par ligne ; une statistique illisible sans repli est grisée de la même façon), jamais attribués tant que la détection n'est pas confirmée.
5. **Annonces de guilde** : à partir de 25 points, ou si le haut fait donne un titre ; jamais en rattrapage. Le moteur émet `FEAT_EARNED` avec `announce` ; l'envoi est au lot D.
6. **Cosmétiques de fiche de dresseur** (fonds et cadres, champs `cb` / `cf`) : reportés.

### 5.2 Plan d'implémentation (lots)

Même méthode que la 2.0 : un worktree par lot depuis une base commune, contrats écrits ; chaque lot appelle le code des autres **seulement s'il existe**.

| Lot | Contenu | Fichiers | Dépend de |
|---|---|---|---|
| **A. Moteur, migration, page** | `Feats.lua` (état, types de critères, sources de base, sujets, évaluation groupée, rattrapage, `FeatGrant`, bandeau via `JournalToastPush`, `/qc hf`, `/qc hf diag`), lecture et analyse de `GetStatistic`, migration des relevés et de `collection.ranks`, bandeau « Nouveau tampon » retiré, `JournalFeats.lua` (section, résumé, liste, filtres), réglages | `Feats.lua`, `JournalFeats.lua`, `Journal.lua` (ciblé), `JournalWindow.lua` (section), `.toc` | — (base) |
| **B. Catalogue ménagerie, brillantes, zones, quotidien** | lignes `men`, `shiny`, `zone`, `day`, `soc` de `FeatsData.lua` et leurs sources ; crochets sur `CaptureResolve`, `CaptureBatchFlush`, `ShinyKill`, sceaux, coffres, missions, auberge, caresses ; déplacement des récompenses `TRAINER_RANKS` et `SHINY_REWARDS` | `FeatsData.lua` (part B), petites enveloppes dans `Feats.lua` | A |
| **C. Catalogue jeu** | lignes `char`, `dng`, `prof`, `quest`, `fun`, `meta` ; sources statistiques (§2.13), `PLAYER_MONEY`, `UnitOnTaxi`, `PLAYER_DEAD`, `QUEST_TURNED_IN`, `ENCOUNTER_END`, `UNIT_DIED` en instance, `DoEmote`, `GetUnitSpeed` ; `tools/gen_dungeons.py` étendu (identifiants de rencontre, npcID des boss, ids d'instance des raids depuis wago) | `FeatsData.lua` (part C), `Libs/Socle/DungeonData.lua` (généré, via `sync_socle.py`) | A |
| **D. Titres, sélecteur et protocole** | table des titres (40), rendu préfixe/suffixe/inline/nu, genre (`UnitSex`, réglage), `ns:TrainerTitle` compatible, sélecteur sur la fiche de dresseur et dans l'onglet Titres, `/qc titre` ; champs `ti`, `tg`, `ap`, `ac` de la fiche ; sorte `h` et champs 9-10 des exploits de guilde, textes avec titre | `FeatsData.lua` (titres), `TrainerCard.lua`, `GuildFeats.lua`, `JournalFeats.lua` (onglet) | A (B/C pour les sources des titres) |
| **E. Cosmétiques** | `tools/gen_feat_assets.py` et ses TGA, nouveaux cadres, fonds et ornements du compagnon, fonds et cadres de fiche (`cb`, `cf`) si la question 6 dit oui | `tools/`, `Textures/`, `FeatsData.lua` (cosmétiques), `Companion.lua` (ornements), `TrainerCard.lua` | A, D |

Ordre : A seul d'abord (il fixe les contrats : `ns:FeatTouch`, `ns:FeatFlag`, `ns.FEAT_SOURCES`, format des lignes), puis B, C, D, E en parallèle. Publication possible en deux temps : 2.7.0 = A + B + D (sans les ⚠️), 2.7.x = C et E après le test en jeu des statistiques.

### 5.3 Stratégie de test

**Harnais** (`python3 tests/run_tests.py`, lupa), un module par lot :
- `tests/modules/qc27_feats_moteur.lua` (A) : intégrité du catalogue (ids et codes `n` uniques, points dans {5, 10, 25, 50}, chaque récompense existe, chaque titre a FR/EN, chaque source et chaque sujet existent, chaque chaîne existe dans les deux langues) ; évaluation par sujets (seuls les abonnés sont recalculés) ; regroupement des bandeaux (≥ 3 → un seul, points additionnés) ; rien en combat puis tout à la sortie ; rattrapage silencieux à la première passe et ligne de chat unique ; analyse de `GetStatistic` (`"780"`, `"1,234"`, `"1 234"`, `"--"`, `nil`, montants avec icônes `|T…GoldIcon…|t`, `12g 34s 5c`, `12po 34pa 5pc`, valeur secrète) ; `featStats` coupé → les `alt` prennent le relais.
- `tests/modules/qc27_feats_migration.lua` (A) : sauvegarde type 2.6 (relevés datés, `retro`, `collection.ranks`) → hauts faits aux bonnes dates (N-ième relevé, dernier d'une liste), aucun bandeau, aides de palier pas redonnées, `journal.stamps` intact, seconde connexion sans nouvelle migration.
- `tests/modules/qc27_feats_catalogue.lua` (B, C) : pour chaque source, un scénario qui la fait passer le seuil (captures simulées, sceaux, missions, statistiques simulées par `Mock.SetStatistic(id, valeur)`, événements `PLAYER_DEAD`, `QUEST_TURNED_IN`, `ENCOUNTER_END`, `UNIT_DIED` en instance).
- `tests/modules/qc27_titres.lua` (D) : rendu préfixe, suffixe, apposé en phrase (virgule fermante), nu ; formes masculine et féminine, réglage prioritaire ; défaut « automatique » = comportement actuel de `TrainerTitle` ; aller-retour de la fiche (`ti`, `tg`, `ap`, `ac`) ; fiche d'une version d'avant (sans `ti`) → `t` ; code inconnu → `t` ; exploit `h` analysé par la nouvelle version et **ignoré** par l'analyseur actuel ; champs 9-10 ignorés par l'analyseur actuel.
- `tests/modules/qc27_cosmetiques.lua` (E) : déblocage par haut fait, liste blanche `cb`/`cf` à la réception ; `gen_feat_assets.py` lancé deux fois → mêmes octets.
- Aperçus HTML (`tests/snapshot.lua`) : `qc-journal-feats`, `qc-journal-feats-titles`, `qc-feat-toast` (Azeroth et Sobre), `qc-feat-toast-many`, `qc-trainer-card-title`.

**En jeu** (liste à cocher, avec `/qc hf diag`) : chaque statistique de §2.13 lisible et cohérente (comparer avec ce que le joueur sait : morts, quêtes) ; forme exacte des montants d'or [333] [334] ; `ENCOUNTER_END` reçu en donjon et en raid ; `UNIT_DIED` d'un boss en instance ; `GetUnitSpeed` sur monture rapide ; `C_Reputation` ou `GetFactionInfo` ; uiMapID de Riverglades, Mont Hyjal, Shen'dralas ; id de la dernière quête de Valthalak ; fanfare 12891 ; bandeau à points dans le bouclier ; titre et genre vus par un autre joueur (fiche et bandeau de guilde) avec une version 2.6 en face.

## 6. État d'implémentation (2.7.0)

Relevé du 2026-11-07, branche d'intégration des lots A à D (le lot E, cosmétiques, arrive à part).

### 6.1 Implémentés

- **174 lignes** : les 173 du catalogue numéroté (§2.1 à §2.11, codes `n` 1 à 173, tous présents, contrôlés par les tests) et `fun_unlucky` (code 174, Insolite, 5 points, titre T39 : le moteur refuse une ligne sans points). Total : **2815 points** (2810 + 5).
- 3.1.0 : + `fun_winter_veil` (code 175, 2.14.0), `men_size_giant` (code 176) et `men_size_tiny` (code 177) : **177 lignes**, **2845 points**.
- 3.0.0 (échanges) : + `soc_trade_1` (code 178), `soc_trade_10` (code 179) et `soc_trade_new` (code 180) : **180 lignes**, **2870 points**.
- 3.6.0 : + 7 rangs de dresseur (codes 188 à 194, 50 points chacun) : **194 lignes** ; 49 titres.
- 3.6.0 : + mécénat (codes 241 à 243 : 10, 25 et 50 points) : **197 lignes** ; 52 titres (T1 à T49, T61 à T63).
- Comptes par catégorie conformes au §2.14 : Ménagerie 29, Brillantes 12, Zones et sceaux 23, Au jour le jour 14, Guilde et entraide 7, Personnage 21, Donjons et raids 21, Métiers 12, Quêtes, réputations et honneur 11, Insolite 15 (+ `fun_unlucky`), Grands hauts faits 8.
- **Titres** : les 40 (§4.1), dans un seul registre (`FeatsTitles.lua`), chacun donné par exactement une ligne (`src`).
- **Statistiques** lisibles sur Forever (§2.13, relevé en jeu) : les lignes qui n'attendaient que leur confirmation sont actives (`char_hearth_50`, `char_camp_25`, `char_gold_looted`, `char_epic`, `dng_runs_50`, `pvp_hk_100`, `fun_respec`) ; les zones propres à Forever sont connues (Mont Hyjal 2482, Riverglades 2548, Shen'dralas 2652) : `zone_visit_all` et `zone_forever_new` sont actifs.
- **Annonces de guilde** : sorte `h` pour les hauts faits de 25 points ou plus, ou à titre ; un palier d'espèces de `TRAINER_RANKS` ne part qu'en sorte `r` (pas de doublon). `/qc hf diag` liste toutes les statistiques employées (lignes, boss, replis).

### 6.2 En attente (grisés « détection bientôt disponible », 15)

| Ligne | Ce qui manque |
|---|---|
| `char_mount_epic` | vitesse d'une monture rapide (`GetUnitSpeed`) à vérifier en jeu |
| `char_food_500` | stats [346] / [347] |
| `char_potions_100` | stats [345] / [922] / [923] / [811] |
| `dng_raid_hyjal`, `dng_raid_barrow` | stats [63580], [63581] (raids propres à Forever, sans npcID ni rencontre connus) |
| `prof_fish_250` | stat [1518] |
| `quest_valthalak` | id de la dernière quête de la chaîne (`ns.FEAT_VALTHALAK_QUEST`) |
| `pvp_bg_win`, `pvp_duel_10` | stats [840], [319] |
| `fun_hogger_death`, `fun_critters_kill` | stats [594], [108] |
| `fun_drown`, `fun_fall`, `fun_lava` | stats [112], [114], [115] |
| `fun_unlucky` | les trois précédentes (méta des quatre morts) |

Une ligne se libère en retirant son `pending` quand sa statistique est confirmée (`/qc hf diag`).

### 6.3 Récompenses en attente

- **Cosmétiques de fiche de dresseur** (fonds `cb` et cadres `cf`, décision 6 : reportés ; **livrés en 3.6.0**, `TrainerCardStyle.lua`, plus rien en attente) : en `reward.soon` jusqu'à la 3.5 : `men_species_500` (`card_census`), `zone_seal_ek` / `zone_seal_ka` (`card_crest_ek` / `card_crest_ka`), `meta_zones` (`card_atlas`), `meta_trainer` (`card_pantheon`), `meta_points_1500` (`card_renown`), `meta_hero` (`card_laurels`).
- **Cosmétiques du compagnon** du lot E (`reward.soon`, résolus par `ns.FeatResolveSoon()` dès que le catalogue du compagnon les a) : cadres `feat_eight` (`men_types_master`), `feat_prism` (`meta_shiny`) ; fond `feat_atlas` (`zone_100_10`) ; ornements `feat_chain` (`men_boss_1`), `feat_goldstars` (`men_stars3_100`), `feat_prism_orn` (`shiny_3stars`), `feat_compass` (`day_travel_1000`), `feat_anniversary` (`day_days_365`). Déjà en `reward.cosmetic` (le lot E les dessine) : `feat_campfire` (`char_camp_25`), `feat_eye` (`dng_raid_aq40`), `feat_wildcrown` (`dng_raid_hyjal`).

### 6.4 Écarts avec la conception

- `fun_unlucky` n'est plus « caché, sans points » (§4.1) : ligne ordinaire de 5 points, hors numérotation.
- La statistique 15027 (Bazzalan, Gouffre de Ragefeu) est lisible ; la table des boss garde les correspondances du §2.13.
- Les paliers 2 à 4 de donjons comptent l'entrée (relevé) pour les donjons sans boss connu (Site de fouilles des Paluns, Cité engloutie, Bastion de Krol'dok, Blackmaw Hold), comme prévu au §2.7.

## 7. Deuxième édition (3.7.0)

### 7.2 Compagnon et voyage, Entre dresseurs, Insolite, Tours de force, Grands hauts faits

104 lignes (codes 324 à 447 ; le code 413, `soc_pack_25`, reste réservé), dans `FeatsCatCompagnon.lua`, avec 11 titres (T59, T60, T64 à T72, §4.1). Portée = celle de la catégorie. Calcul : `retro` (donnée déjà dans la sauvegarde, rattrapée à la connexion), `etat` (vrai en ce moment : rattrapé, et attribué en direct par une enveloppe sur la fonction qui change l'état), `compteur` (critère sur un compteur de `Tally.lua`, non rétroactif), `fonction` (clé réservée à une étape suivante : ligne en attente, invisible et hors total).

Choix faits au codage :

- `zone_seal_all` : « toutes les zones à sceau », soit les 44 zones qui ont une liste d'espèces (`ZONE_CREATURES` : 22 des Royaumes de l'Est, 18 de Kalimdor et 4 zones propres à Forever), pas 40 ; le seuil est compté à la construction du catalogue.
- `zone_lore_all` : liste « une zone racontée de plus » jusqu'au nombre de zones qui ont une histoire (`LORE_RAW`, 45) ; les zones racontées viennent de `CharData().lore.z`.
- `zone_medal_*` : `ns:ZoneMedalCounts()` (`ZoneMedals.lua`, autre chantier) ; sans elle, 0. Relu quand les captures bougent.
- `comp_pets_500`, `soc_trade_25`, `soc_guild_cheer_100`, `soc_card_25`, `fun_dance_100` : compteurs du moteur déjà tenus (`streak`), rattrapés à la connexion par l'enveloppe de `ns:FeatRetroScan`.
- `fos_pioneer` : `ns:CaptureEarliestAt()` (`capture.firstAt`, figée à la capture suivant la 3.0, sinon la plus ancienne date des fiches d'espèce) avant 2027.
- `fos_first_veil` : la date du drapeau `winterVeil` (posé une fois, en saison, par `WinterCompanions.lua`) entre le 15 décembre 2026 et le 2 janvier 2027.
- `comp_wardrobe_*` : les clés `app:`, `frame:`, `bg:`, `orn:` de `CompanionData().unlocked` (les fonds et cadres de fiche n'en sont pas).
- `meta_points_500` (ligne existante) reçoit le cadre de fiche `card_rank_bronze` (à venir) ; les paliers de points portent la série `points`.

**Zones et sceaux (`zone`, personnage)**

- `zone_medal_bronze_1` (code 324) — Premier bronze / First Bronze — Gagner la médaille de bronze d'une zone (25 % des espèces), 5 points, calcul `retro`.
- `zone_medal_silver_5` (code 325) — Cinq d'argent / Silver Five — Avoir 5 zones à la médaille d'argent (50 %), 10 points, calcul `retro`.
- `zone_medal_gold_5` (code 326) — Cinq d'or / Golden Five — Avoir 5 zones à la médaille d'or (75 %), 25 points, calcul `retro`.
- `zone_medal_gold_20` (code 327) — Vingt d'or / Twenty Golds — Avoir 20 zones à la médaille d'or, 50 points, calcul `retro` ; récompense : fond de fiche (à créer).
- `zone_seal_25` (code 328) — Grand sceau / Great Seal — Sceller 25 zones, 50 points, calcul `retro`.
- `zone_seal_all` (code 329) — Azeroth scellé / Azeroth Sealed — Sceller les 40 zones à sceau, 50 points, calcul `retro` ; récompense : titre « Gardien d'Azeroth ».
- `zone_chests_25` (code 330) — Coffres en série / Chest After Chest — Ouvrir 25 coffres de zone, 25 points, calcul `retro`.
- `zone_golden_5` (code 331) — Cinq zones d'or / Five Golden Zones — Rendre 5 zones dorées, 25 points, calcul `retro`.
- `zone_100_25` (code 332) — Vingt-cinq zones accomplies / Twenty-Five Zones Complete — Accomplir 25 zones à 100 %, 50 points, calcul `retro`.
- `zone_lore_10` (code 333) — Oreille attentive / All Ears — Écouter l'histoire de 10 zones, 5 points, calcul `retro`.
- `zone_lore_all` (code 334) — Mémoire des lieux / Memory of Places — Écouter l'histoire de toutes les zones racontées, 25 points, calcul `retro`.
- `zone_milestones_100` (code 335) — Cent paliers / A Hundred Milestones — Franchir 100 paliers de zone, 25 points, calcul `retro`.

**Au jour le jour (`day`, personnage)**

- `day_mission_250` (code 336) — Toujours volontaire / Always Volunteering — Accomplir 250 missions du compagnon, 25 points, calcul `retro`.
- `day_mission_500` (code 337) — Cinq cents missions / Five Hundred Missions — Accomplir 500 missions du compagnon, 50 points, calcul `retro` ; récompense : ornement (à créer).
- `day_perfect_30` (code 338) — Trente journées parfaites / Thirty Perfect Days — Boucler toutes les missions du jour 30 fois, 25 points, calcul `retro`.
- `day_perfect_100` (code 339) — Cent journées parfaites / A Hundred Perfect Days — Boucler toutes les missions du jour 100 fois, 50 points, calcul `retro` ; récompense : fond du compagnon (à créer).
- `day_weekly_10` (code 340) — Dix semaines bouclées / Ten Weeks Wrapped Up — Boucler toutes les missions de 10 semaines, 25 points, calcul `compteur`.
- `day_weekly_25` (code 341) — Vingt-cinq semaines bouclées / Twenty-Five Weeks Wrapped Up — Boucler toutes les missions de 25 semaines, 50 points, calcul `compteur`.
- `day_inn_100` (code 342) — Cent nuits à l'auberge / A Hundred Nights at the Inn — Passer 100 jours à l'auberge, 25 points, calcul `retro`.
- `day_inn_cards_10` (code 343) — Carte de fidélité / Loyalty Card — Remplir 10 cartes d'auberge, 10 points, calcul `retro`.
- `day_rare_100` (code 344) — Cent têtes mises à prix / A Hundred Bounties — Vaincre 100 ennemis rares, 25 points, calcul `retro`.
- `day_played_30` (code 345) — Trente jours de route / Thirty Days on the Road — Jouer 30 jours différents (pas forcément d'affilée), 10 points, calcul `compteur`.
- `day_played_100` (code 346) — Cent jours de route / A Hundred Days on the Road — Jouer 100 jours différents, 25 points, calcul `compteur`.
- `day_played_365` (code 347) — Une année de route / A Year on the Road — Jouer 365 jours différents, 50 points, calcul `compteur`.
- `day_week_1` (code 348) — Prise de la semaine / Catch of the Week — Capturer la créature de la semaine, 5 points, calcul `fonction` ; en attente (`pending`, étape suivante).
- `day_week_10` (code 349) — Dix prises de la semaine / Ten Catches of the Week — Capturer 10 créatures de la semaine, 10 points, calcul `fonction` ; en attente (`pending`, étape suivante).
- `day_week_52` (code 350) — Une année de prises / A Year of Catches — Capturer 52 créatures de la semaine, 50 points, calcul `fonction` ; en attente (`pending`, étape suivante).
- `day_swarm_10` (code 351) — Chasseur de pullulations / Swarm Chaser — Capturer l'espèce en pullulation dans 10 zones différentes, 10 points, calcul `fonction` ; en attente (`pending`, étape suivante).

**Compagnon (`comp`, personnage)**

- `comp_stage_2` (code 352) — Il grandit / Growing Up — Voir ton compagnon atteindre le deuxième stade, 5 points, calcul `retro`.
- `comp_stage_3` (code 353) — Aguerri / Seasoned — Voir ton compagnon atteindre le troisième stade, 5 points, calcul `retro`.
- `comp_stage_4` (code 354) — Vaillant / Valiant — Voir ton compagnon atteindre le quatrième stade, 10 points, calcul `retro`.
- `comp_stage_5` (code 355) — Légendaire / Legendary — Voir ton compagnon atteindre le dernier stade, 25 points, calcul `retro`.
- `comp_persona` (code 356) — Un sacré caractère / Quite a Character — Voir le caractère de ta mascotte se former, 10 points, calcul `retro`.
- `comp_radiant_60` (code 357) — Une heure de bonheur / An Hour of Bliss — Passer 60 minutes Rayonnant (au total), 10 points, calcul `compteur`.
- `comp_radiant_600` (code 358) — Dix heures de bonheur / Ten Hours of Bliss — Passer 10 heures Rayonnant, 25 points, calcul `compteur`.
- `comp_radiant_3000` (code 359) — Bonheur au long cours / Lasting Happiness — Passer 50 heures Rayonnant, 50 points, calcul `compteur` ; récompense : titre « le Rayonnant ».
- `comp_wish_10` (code 360) — Aux petits soins / Doting — Combler 10 envies, 5 points, calcul `compteur`.
- `comp_wish_50` (code 361) — Devin / Mind Reader — Combler 50 envies, 10 points, calcul `compteur`.
- `comp_wish_250` (code 362) — Ses désirs sont des ordres / At Its Beck and Call — Combler 250 envies, 25 points, calcul `compteur` ; récompense : titre « l'Attentionné ».
- `comp_treat_25` (code 363) — Bonne table / Fine Dining — Donner 25 friandises, 5 points, calcul `compteur`.
- `comp_treat_100` (code 364) — Cordon-bleu / Cordon Bleu — Donner 100 friandises, 10 points, calcul `compteur`.
- `comp_treat_500` (code 365) — Gourmandise / Sweet Tooth — Donner 500 friandises, 25 points, calcul `compteur`.
- `comp_treat_all` (code 366) — Menu dégustation / Tasting Menu — Donner les 5 sortes de friandises, 10 points, calcul `compteur`.
- `comp_pets_500` (code 367) — Mille caresses, ou presque / A Thousand Pats, Almost — Caresser le compagnon 500 fois, 25 points, calcul `retro`.
- `comp_partners_10` (code 368) — Chacun son tour / Taking Turns — Voyager avec 10 créatures différentes, 10 points, calcul `compteur`.
- `comp_partners_50` (code 369) — Toute la troupe / The Whole Troupe — Voyager avec 50 créatures différentes, 25 points, calcul `compteur`.
- `comp_wardrobe_10` (code 370) — Garde-robe / Wardrobe — Débloquer 10 cosmétiques du compagnon, 5 points, calcul `retro`.
- `comp_wardrobe_25` (code 371) — Belle garde-robe / Fine Wardrobe — Débloquer 25 cosmétiques, 10 points, calcul `retro`.
- `comp_wardrobe_50` (code 372) — Grande garde-robe / Grand Wardrobe — Débloquer 50 cosmétiques, 25 points, calcul `retro`.
- `comp_wardrobe_100` (code 373) — Dressing complet / Walk-In Closet — Débloquer 100 cosmétiques, 50 points, calcul `retro` ; récompense : titre « l'Élégant ».
- `comp_juke_fav_10` (code 374) — Mélomane / Music Lover — Avoir 10 morceaux favoris au juke-box, 5 points, calcul `etat`.
- `comp_juke_list` (code 375) — Ma sélection / My Mixtape — Créer une liste au juke-box, 5 points, calcul `etat`.
- `comp_juke_100` (code 376) — Tour de chant / Song Recital — Écouter 100 morceaux différents, 10 points, calcul `compteur`.
- `comp_jokes_25` (code 377) — Bon public / Easy Crowd — Écouter 25 blagues du compagnon, 5 points, calcul `compteur`.

**Entre dresseurs (`soc`, compte)**

- `soc_share_1` (code 397) — Fier de sa prise / Proud of the Catch — Partager un moment dans le chat, 5 points, calcul `compteur`.
- `soc_share_25` (code 398) — Grand bavard / Chatterbox — Partager 25 moments, 10 points, calcul `compteur`.
- `soc_trade_25` (code 399) — Grand négociant / Master Trader — Conclure 25 échanges, 25 points, calcul `retro` ; récompense : titre « le Marchand ».
- `soc_trade_partners_5` (code 400) — Réseau / Networking — Échanger avec 5 dresseurs différents, 10 points, calcul `compteur`.
- `soc_guild_feat_10` (code 401) — Porte-voix / Town Crier — Annoncer 10 exploits à ta guilde, 10 points, calcul `compteur`.
- `soc_guild_cheer_100` (code 402) — Premier rang / Front Row — Voir 100 exploits des membres de ta guilde, 10 points, calcul `retro`.
- `soc_group_50` (code 403) — Meute soudée / Tight-Knit Pack — Capturer 50 créatures en groupe, 10 points, calcul `compteur`.
- `soc_holders_10` (code 404) — Du beau monde / Good Company — Croiser 10 dresseurs, 5 points, calcul `compteur`.
- `soc_card_25` (code 405) — Annuaire / Who's Who — Consulter 25 fiches de dresseur différentes, 25 points, calcul `compteur` ; récompense : fond de fiche (à créer).
- `soc_photo_1` (code 406) — Souriez ! / Say Cheese! — Créer une carte souvenir, 5 points, calcul `fonction` ; en attente (`pending`, étape suivante).
- `soc_code_1` (code 407) — Carte de visite / Calling Card — Copier ton code de dresseur, 5 points, calcul `fonction` ; en attente (`pending`, étape suivante).
- `soc_code_5` (code 408) — Correspondants / Pen Pals — Ouvrir 5 fiches reçues par code, 10 points, calcul `fonction` ; en attente (`pending`, étape suivante).
- `soc_compare` (code 409) — Jeu des différences / Spot the Difference — Comparer tes hauts faits avec ceux d'un dresseur, 5 points, calcul `fonction` ; en attente (`pending`, étape suivante).
- `soc_mentor_1` (code 410) — Passeur / Word of Mouth — Faire découvrir Quest Companion à un joueur, 5 points, calcul `fonction` ; en attente (`pending`, étape suivante).
- `soc_mentor_5` (code 411) — Cinq filleuls / Five Protégés — Faire découvrir Quest Companion à 5 joueurs, 10 points, calcul `fonction` ; en attente (`pending`, étape suivante).
- `soc_mentor_10` (code 412) — Dix filleuls / Ten Protégés — Faire découvrir Quest Companion à 10 joueurs, 25 points, calcul `fonction` ; en attente (`pending`, étape suivante) ; récompense : titre « le Passeur ».
- `soc_discord` (code 414) — Porte ouverte / Open Door — Saisir le mot de la version trouvé sur le Discord (page Communauté), 10 points, calcul `fonction` ; en attente (`pending`, étape suivante) ; récompense : ornement « Explorateur des mondes » (à créer).
- `soc_feedback` (code 415) — Mon grain de sel / My Two Cents — Composer un avis sur la page Communauté, 5 points, calcul `fonction` ; en attente (`pending`, étape suivante).

**Insolite (`fun`, compte)**

- `fun_critters_10` (code 416) — Arche de poche / Pocket Ark — Capturer 10 bestioles différentes, 10 points, calcul `retro`.
- `fun_murlocs_10` (code 417) — Mrgl mrgl mrgl ! / Mrgl Mrgl Mrgl! — Capturer 10 murlocs différents, 10 points, calcul `retro`.
- `fun_dance_100` (code 418) — Roi de la piste / Lord of the Dance — Danser 100 fois avec le compagnon affiché, 5 points, calcul `retro`.
- `fun_winter_all` (code 419) — Trois de saison / Seasonal Trio — Voyager avec les 3 compagnons du Voile d'hiver, 10 points, calcul `compteur`.
- `fun_hogger_partner` (code 420) — Lardeur en promenade / Walkies with Hogger — Partir avec Lardeur, 10 points, calcul `etat` ; secret.
- `fun_hogger_shiny` (code 421) — Lardeur doré / Golden Hogger — Capturer Lardeur en version brillante, 25 points, calcul `retro` ; secret.
- `fun_namesake` (code 422) — Mon double / Mini-Me — Donner ton propre nom à un spécimen, 5 points, calcul `etat` ; secret.
- `fun_clones` (code 423) — Jumeaux / Double Trouble — Avoir deux spécimens identiques (espèce, étoiles, taille, caractère), 5 points, calcul `etat` ; secret.
- `fun_close_call` (code 424) — Du bout des doigts / By the Skin of Your Teeth — Capturer une créature juste après avoir survécu de justesse, 10 points, calcul `compteur` ; secret.
- `fun_boss_miss` (code 425) — Tout ça pour ça / All That for Nothing — Rater la capture d'un boss du monde, 5 points, calcul `compteur` ; secret.
- `fun_winter_song` (code 426) — Douce nuit / Silent Night — Écouter un morceau au juke-box, la nuit, pendant le Voile d'hiver, 5 points, calcul `compteur` ; secret.
- `fun_small_game` (code 427) — Petit gibier / Small Fry — Au niveau 60, capturer une créature de niveau 5 ou moins, 5 points, calcul `compteur` ; secret.
- `fun_wake` (code 428) — Debout là-dedans ! / Rise and Shine! — Réveiller le compagnon d'une caresse, 5 points, calcul `compteur` ; secret.
- `fun_full_bag` (code 429) — Besace pleine / Packed to the Brim — Avoir en même temps 10 appâts, 5 lassos et 3 sifflets, 5 points, calcul `etat` ; secret.

**Tours de force (`fos`, compte, 0 point, hors des totaux)**

- `fos_pioneer` (code 430) — Pionnier / Pioneer — Avoir fait ta première capture avant le 1er janvier 2027, 0 point, calcul `retro` ; récompense : titre « le Pionnier », marque sur la fiche.
- `fos_first_veil` (code 431) — Premier Voile d'hiver / First Winter Veil — Avoir fêté le Voile d'hiver 2026 avec un compagnon de saison, 0 point, calcul `retro`.
- `fos_unfindable` (code 432) — L'introuvable / The Unfindable — Capturer une brillante à 3 étoiles et de taille rare (1 sur 53 571), 0 point, calcul `compteur` ; récompense : ornement (à créer).
- `fos_golden_legend` (code 433) — Légende dorée / Golden Legend — Capturer un boss du monde en version brillante, 0 point, calcul `retro`.

**Grands hauts faits (`meta`, compte)**

- `meta_points_100` (code 434) — Premiers lauriers / First Laurels — Atteindre 100 points de hauts faits, 5 points, calcul `retro` ; récompense : rang « Connu au village ».
- `meta_points_250` (code 435) — On en parle / Talk of the Town — Atteindre 250 points, 5 points, calcul `retro` ; récompense : rang « Connu du comté ».
- `meta_points_1000` (code 436) — Réputation faite / Reputation Made — Atteindre 1 000 points, 10 points, calcul `retro` ; récompense : rang « Réputé », cadre de fiche argent.
- `meta_points_2000` (code 437) — Illustre / Illustrious — Atteindre 2 000 points, 25 points, calcul `retro` ; récompense : rang « Illustre », cadre de fiche or.
- `meta_points_3000` (code 438) — Célèbre dans tout Azeroth / Famous Across Azeroth — Atteindre 3 000 points, 25 points, calcul `retro` ; récompense : rang « Célèbre ».
- `meta_points_4000` (code 439) — Légende vivante / Living Legend — Atteindre 4 000 points, 50 points, calcul `retro` ; récompense : rang « Légende vivante », cadre de fiche à lueur.
- `meta_points_5000` (code 440) — Au sommet de la renommée / Height of Fame — Atteindre 5 000 points, 50 points, calcul `retro` ; récompense : titre « le Renommé ».
- `meta_spec` (code 441) — Maître des spécimens / Specimen Master — Obtenir 15 hauts faits « Spécimens », 25 points, calcul `retro`.
- `meta_comp` (code 442) — Meilleur ami / Best Friend — Obtenir 15 hauts faits « Compagnon », 25 points, calcul `retro`.
- `meta_shop` (code 443) — Pilier de l'Échoppe / Pillar of the Stall — Obtenir 10 hauts faits « Réserve et Échoppe », 25 points, calcul `retro`.
- `meta_soc` (code 444) — Figure connue / Familiar Face — Obtenir 10 hauts faits « Entre dresseurs », 25 points, calcul `retro` ; récompense : titre « le Sociable ».
- `meta_fun` (code 445) — Cabinet de curiosités / Curio Cabinet — Obtenir 15 hauts faits « Insolite », 25 points, calcul `retro` ; récompense : titre « l'Original ».
- `meta_secrets` (code 446) — Dans la confidence / In on the Secret — Découvrir 5 hauts faits secrets, 25 points, calcul `retro`.
- `meta_all` (code 447) — Dresseur accompli / Accomplished Trainer — Obtenir tous les grands hauts faits de dresseur, 50 points, calcul `retro` ; récompense : titre « Dresseur accompli ».
