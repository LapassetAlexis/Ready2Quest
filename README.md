# Ready2Quest — v1.21.0

## v1.21.0 — Ready to Quest devient Ready2Quest

Un nom plus court, une vraie marque, et le sigle **R2Q**.

**Le logo** est une boussole de poche : anneau de suspension, lunette pointillée, repères cardinaux, **aiguille bleu de nuit** à 38°, pivot ambre et monogramme « R2Q » (le « 2 » en ambre) en Alegreya.
- `Textures/logo.tga` (128 px) : version complète, en tête de la navigation des réglages, à côté du nom « Ready**2**Quest ».
- `Textures/logo_petit.tga` (64 px) : la même boussole sans les lettres, illisibles sous 24 px. Elle sert pour les bandeaux, le bouton de minicarte et l'icône de la liste des addons.

**Une deuxième couleur, le bleu de nuit `#5b8fd6`.** Elle reprend l'aiguille du logo et n'a qu'un rôle : **information et navigation**. Ça couvre les groupes de la navigation, le losange des modules « info » (le repos) et la source d'une zone apprise (« boîte aux lettres »). Elle ne sert jamais pour un statut ni pour l'action principale : l'ambre garde l'action et la valeur, et vert, ambre et rouge restent les statuts.

**Le renommage est complet.**
- Dossier et `.toc` : `Ready2Quest/Ready2Quest.toc`.
- Sauvegarde : `Ready2QuestDB`.
- Fenêtres : `Ready2QuestDiagFrame`, `Ready2QuestOptionsFrame`, `Ready2QuestMinimapButton`.
- API publique : `_G.Ready2Quest` (`_G.ReadyToQuest` reste en alias).
- Commandes : nouvelle commande `/r2q`. `/sd` et `/sacdepart` marchent toujours.
- Les chemins de textures sont maintenant construits depuis le nom réel du dossier. Les flèches de `Stats.lua` l'avaient encore en dur.

### Interrupteurs de page dans la navigation

Comme le bouton d'alimentation des modules dans la barre latérale d'EllesmereUI : chaque page qui contient des modules a son mini-interrupteur à droite de son nom.

- Un clic coupe ou rallume **tous les modules de la page**, sans quitter la page courante.
- Trois états : allumé (ambre), éteint (gris, nom de page grisé), **partiel** (contour ambre, curseur au centre) quand une partie seulement des modules est active.
- Un clic sur une page partielle rallume tout. Le réglage module par module reste dans la page, et les deux restent synchronisés.
- La navigation passe de 150 à 164 px pour faire la place, d'après la largeur des libellés mesurée sur une capture en jeu.

### Migration : ce qu'il faut faire

1. Supprimer l'ancien dossier `Interface/AddOns/ReadyToQuest`. Sinon les deux versions se chargent.
2. Copier `Ready2Quest` à sa place.
3. **Pour garder ses réglages et ses villages appris** : dans `WTF/Account/<compte>/SavedVariables/`, renommer `ReadyToQuest.lua` en `Ready2Quest.lua` (et `ReadyToQuest.lua.bak` s'il existe). C'est nécessaire parce que WoW charge la sauvegarde d'un addon depuis un fichier **qui porte le nom du dossier** : après un renommage, l'ancienne n'est plus lue. Une fois le fichier renommé, l'addon reprend `ReadyToQuestDB` dans `Ready2QuestDB` au premier chargement. Sans cette étape, l'addon repart des réglages par défaut, sans erreur.

Remarque honnête : la migration de la v1.17.0 (`SacEtDepartDB` → `ReadyToQuestDB`) avait la même limite. Elle ne servait que si le fichier de sauvegarde avait été renommé à la main. Elle est conservée dans la chaîne (`SacEtDepartDB` → `ReadyToQuestDB` → `Ready2QuestDB`) : c'est la sauvegarde la plus récente qui l'emporte.

---


## v1.20.0 — une identité à soi

L'addon ressemblait à un morceau de l'interface Blizzard. Il a maintenant sa personnalité, sur un principe repris de suites comme EllesmereUI : **un seul système visuel, appliqué partout**. L'apparence, elle, reste propre à Ready to Quest : un « carnet de route », ambre et ardoise, avec une boussole pour marque (détail dans *Direction artistique*).

- **Diagnostic** : titre « Avant le départ », note en grand dans la police maison, qui compte jusqu'à sa valeur, et verdict en tampon bordé à la couleur du statut. « Parti de Comté-de-l'Or · boîte aux lettres » est dans le bandeau. Chaque ligne a un losange de statut, et les conseils ont des puces en losange.
- **Réglages** : navigation en deux groupes (Préparation, Interface), page active teintée et soulignée d'ambre, titre de page dans la police maison avec une phrase d'explication. Les booléens ont des interrupteurs, les seuils une piste de valeur. « Fermer » est en ambre plein.
- **Minicarte** : la boussole remplace l'icône de sac.
- **Chat** : préfixe ambre `[Ready to Quest]`, alerte discrète en « Sac bouclé / Presque prêt / Pas prêt ».
- **Plus aucun template Blizzard** pour les fenêtres et contrôles : l'apparence ne dépend plus de l'art du client (« Camelot » sur Forever, encore inconnu).

---


## v1.19.0 — réglages par pages

Le panneau de réglages était une longue colonne : 910 px en 1.18.0 avant refonte (hors de l'écran), et les réglages d'un même module y étaient éparpillés. L'interrupteur des vivres était dans « Modules », leur seuil dans « Alertes ». Il devient une fenêtre de **600 × 440** avec une navigation à gauche, à la manière d'ElvUI, sous l'habillage de l'addon (fond sombre, liseré or, `GameFont`).

| Page | Contenu |
|---|---|
| **Général** | addon actif, fenêtre ou chat, fenêtre sous la note, délai avant l'alerte, silence après connexion, écart entre deux alertes |
| **Zones sûres** | villages et capitales appris, avec leur source et un bouton **Retirer** par ligne ; **Tout effacer** |
| **Sacs & butin** | modules Sacs et Butin à vendre ; emplacements libres min., alerte continue, gris avant l'alerte, vente auto |
| **Vivres & potions** | les deux modules et leurs minimums |
| **Buffs** | module, apprentissage auto, **liste des buffs suivis** : clic pour activer ou couper, bouton Retirer |
| **Équipement** | Durabilité et Réparation ; durabilité min., réparation auto |
| **Personnage** | Réactifs, Sorts, Foyer, Repos ; repos min. |
| **Métier & quêtes** | composants de métier, quêtes à rendre |
| **Affichage** | minicarte (bouton, position), résumé de stuff, stats du portrait, déplacer / réinitialiser les cadres |

- La page ouverte est mémorisée.
- Les listes défilent à la molette ou avec `^` / `v`. C'est fait sans `FauxScrollFrame`, dont la présence n'est pas assurée sur Forever.
- Un module ajouté plus tard sans page tombe dans « Général » : il reste toujours possible de le couper.
- Les tests vérifient que chaque module a un seul interrupteur, qu'aucune page ne déborde sur le pied, que les libellés tiennent, et que les listes se mettent à jour après un retrait.

---

## v1.18.0 — l'alerte part enfin à la sortie du village

**Le bug.** La fenêtre ne s'ouvrait pas toute seule en quittant une zone sûre, seulement au clic sur l'icône. Deux causes :

1. **Les zones sûres étaient apprises par `mapID`.** Sur Era, un `mapID` est une zone entière : un repos ou un vendeur à Comté-de-l'Or rendait **toute la forêt d'Elwynn** sûre, pour toujours. Sortir du village ne changeait rien, donc pas de transition, donc pas d'alerte. Chaque marchand croisé sur la route ajoutait une zone de plus.
2. **`GetRestState()` était lu comme « dans une auberge ».** Il indique en fait un bonus d'XP de repos en réserve : avec du repos d'avance, tu étais « en zone sûre » partout.

**La refonte.**

| | Avant | v1.18.0 |
|---|---|---|
| Clé d'un village | `mapID` (zone entière) | `mapID` + sous-zone (`GetSubZoneText`) |
| Capitale | idem | carte entière, déduite d'un repos vu dans **≥ 2 quartiers** |
| Apprentissage | repos, vendeur ou courrier : un seul suffit | **indices** (voir ci-dessous) |
| Sortie | immédiate | confirmée après **6 s** hors zone sûre (réglable 0–15 s) |
| En vol | alerte en plein ciel | reportée à l'atterrissage, annulée si tu te poses en zone sûre |
| Mort / fantôme | alerte | ignorée |

Indices, par sous-zone :

| Force | Signal | Événement |
|---|---|---|
| **fort** : un seul suffit | repos, aubergiste, maître de vol, boîte aux lettres, banque | `PLAYER_UPDATE_RESTING`, `CONFIRM_BINDER`, `TAXIMAP_OPENED`, `MAIL_SHOW`, `BANKFRAME_OPENED` |
| moyen | entraîneur | `TRAINER_SHOW` |
| faible | marchand, donneur de quêtes | `MERCHANT_SHOW`, `QUEST_DETAIL`, `QUEST_GREETING`, `QUEST_COMPLETE` |

Un village est appris avec **un indice fort, ou deux indices moyens/faibles de types différents** (marchand + quête). Deux quêtes prises au même PNJ isolé ne suffisent pas. Les indices partiels sont gardés d'une session à l'autre.

**Migration.** Les anciennes zones (par `mapID`) ne peuvent pas être converties : elles sont **purgées une fois**, avec un message dans le chat. Les villages se réapprennent en quelques minutes de jeu.

**Commandes.** `/sd safe` (village courant), `/sd unsafe` (village ou capitale courants), `/sd safe list`, `/sd safe reset`. La fenêtre de diagnostic affiche « Parti de : Comté-de-l'Or (appris : boîte aux lettres) » pour repérer d'un coup d'œil un village appris à tort.

**Limite connue.** Dans un village où l'auberge porte son propre nom de sous-zone, sortir de l'auberge vers la rue ressemble à une sortie si la rue n'est pas encore apprise. Le délai de 6 s absorbe les allers-retours, et la rue s'apprend vite (marchand + quête, boîte aux lettres).

### Nouveaux checks

| Check | Poids | Actif quand | Échec si |
|---|---|---|---|
| **Réactifs** (de classe) | 15 (fort) | la classe en consomme, au niveau du sort | munitions < 200, fragments d'âme < 3, poudre éclipsante < 5, runes de téléportation < 2, poudre des arcanes < 5, chandelles < 5, graine de Renaissance < 1, ankh < 1, symbole de divinité < 1 |
| **Pierre de foyer** | 10 (moyen) | toujours | absente, ou recharge > 10 min. Affiche le lieu lié (`GetBindLocation`) |
| **Réparation** | 10 (moyen) | un coût a été mesuré chez un marchand | l'or ne couvre pas le coût estimé |
| **Sorts à apprendre** | 5 (faible) | un niveau pair est passé depuis la dernière visite chez l'entraîneur de classe | toujours un conseil |

La réparation n'invente rien : chez un marchand qui répare, l'addon relève `GetRepairAllCost()` et le ramène à un prix par point de durabilité manquant. Le check est muet tant qu'aucune mesure n'existe. Le niveau d'entraîneur et le prix de réparation sont gardés **par personnage**.

### Chez le marchand (activé par défaut)

- **Vente des gris** : uniquement qualité grise avec un prix de vente, par tranches de 12 (limite du serveur), récapitulatif « 7 objet(s) gris vendu(s) : 1 po 23 pa ».
- **Réparation** : si le marchand répare et que l'or suffit, sinon un message.

Les deux se coupent dans `/sd options` → **Chez le marchand**.

### Audit Era : ce qui était faux sans rien dire

Aucun de ces bugs ne levait d'erreur : la note mentait, simplement.

| Module | Sur Era | Correctif |
|---|---|---|
| Vivres, potions | les consommables gardent la sous-classe générique 0 de vanilla : **compteur toujours à 0** | reconnus au sort lancé (« Nourriture », « Boisson ») ou au mot « Potion » |
| Quêtes | `isComplete` vaut `1`, pas `true`, et la forme des retours de `GetQuestLogTitle` varie : **« rien à rendre » en permanence** | forme détectée par la position du booléen `isHeader`, `1` accepté |
| Consommables | seul `C_Item.GetItemInfoInstant` était appelé | repli sur la fonction globale |
| Buffs | repli `UnitAura` : le spellId est le 10e retour, pas le 8e | corrigé |
| Buffs | un rang ou la version de groupe (Prière de robustesse, Don du fauve, Bénédiction supérieure) était signalé « manquant » | comparaison **par famille de nom** |
| Buffs | sans `GetPlayerAuraBySpellID`, tout devenait « illisible » | lecture des auras par index |
| Buffs | « Bien nourri » et les buffs mondiaux ponctuels étaient appris puis réclamés | consommables ignorés, buff non revu depuis 7 jours oublié |
| Composants | sacs recomptés par nom via `GetItemInfo` (nil hors cache) | itemID du composant + `GetItemCount` |
| Composants | changer de recette ne rafraîchissait pas toujours | accroche de `TradeSkillFrame_SetSelection` |
| Composants | Enchantement et dressage (fenêtre Craft) non couverts | chemin `GetCraft*`, `CRAFT_SHOW` / `CRAFT_UPDATE` |
| Stats | `UnitAttackPower` a 3 retours : la PA de l'équipement était ignorée | base + bonus + malus |
| Stats | pas de `GetSpecialization` : toujours la 1re spé | onglet de talents le plus fourni |
| Stats (tous clients) | paladin : Protection et Vindicte inversées | ordre Sacré / Protection / Vindicte |
| Stats | « 12.3 %% », Esprit absent du résumé, ilvl 0 sans `GetAverageItemLevel` | corrigés |
| Affichage | troncature au milieu d'un caractère accentué ; « … », « • », « — » peut-être absents de la police des cadres | coupe UTF-8 propre, glyphes ASCII |
| Textes | préfixe du chat, titre et message d'erreur encore en « Sac & Départ » | « Ready to Quest » |

Au passage : `string.lower` dépend de la locale C, et en Latin-1 il casse l'UTF-8 (`0xC3` → `0xE3`). Les comparaisons de noms passent par `ns.AsciiLower`, qui ne touche qu'à A-Z.

Restent à confirmer en jeu : la sous-classe 0 des consommables Era, et la présence des glyphes dans la police.

### UX : moins de bruit, rien hors de l'écran

| Problème | Correctif |
|---|---|
| Panneau d'options de **910 px**, boutons du bas hors de l'écran (768 unités à l'échelle 1) | interrupteurs (affichage, automatismes, modules) sur **deux colonnes** : 702 px ; un test borne la hauteur à 740 px |
| Fenêtre ouverte à chaque sortie, même à 95/100 | note ≥ 85 : **une ligne dans le chat** (« PRÊT, 92/100 (parti de Comté-de-l'Or) ») ; réglage « Fenêtre sous la note », 100 = toujours la fenêtre ; un check manuel l'ouvre toujours |
| Fenêtre en plein combat | l'alerte attend la fin du combat |
| Deux lignes « Composants » | « Métier » (recettes) et « Réactifs » (de classe) |
| 13 lignes dont des « sans objet » | modules sans objet **masqués**, échecs en tête (les plus lourds d'abord), modules coupés en bas ; la fenêtre se redimensionne |
| Repos : 10 points perdus sur un critère qu'on ne corrige pas en partant | information seulement : poids nul, pas de conseil |
| « à apprendre (dernier entraîneur : niv. 10) » tronqué | « niv. 10 -> 12 : à apprendre » |
| Minicarte : clic gauche = réglages | clic gauche = **check** (l'action principale), clic droit = réglages |
| Vente auto silencieuse la première fois | message unique au premier marchand |
| Vert de statut = vert de rareté « Inhabituel » | vert adouci ; « ! » devant chaque échec (la couleur seule ne suffit pas aux daltoniens) |
| Verdict en petit dans le bandeau, « Parti de » en bas | verdict en grand à côté de la note, « Parti de » juste dessous |
| Seuils « Vivres : 5 » ambigus | « Vivres min. », « Gris avant l'alerte »… ; libellés raccourcis pour tenir en demi-colonne (testé) |

---


## v1.17.0 — le projet s'appelle Ready to Quest

Le dépôt GitHub s'appelle **ReadyToQuest** ; le dossier WoW s'y aligne. Ce n'est pas cosmétique : WoW exige que le nom du dossier corresponde exactement au nom du `.toc`, sinon l'addon ne se charge pas.

Renommé : dossier, `ReadyToQuest.toc`, SavedVariable `ReadyToQuestDB`, noms des frames (`ReadyToQuestDiagFrame`, `ReadyToQuestOptionsFrame`, `ReadyToQuestMinimapButton`), table publique `_G.ReadyToQuest`, et le chemin des textures TGA — qui référence le nom du dossier.

**La sauvegarde est migrée.** `SacEtDepartDB` → `ReadyToQuestDB`, au premier appel de `:DB()` : zones sûres apprises et réglages personnalisés survivent au renommage. Sans ça, chaque joueur repartait de zéro sans s'en apercevoir. Quatre assertions verrouillent la migration ; la neutraliser en fait échouer trois.

Inchangé : la commande reste `/sd` (`/sacdepart` fonctionne encore). Le titre affiché devient « Ready to Quest ».

---

Addon QoL pour **WoW Forever**, avec sa propre identité « carnet de route » : surfaces ardoise, accent ambre, titres en Alegreya, boussole en guise de marque (voir *Direction artistique*).

| Module | Ce qu'il fait |
|---|---|
| **Diagnostic de départ** | Note de préparation sur 100, détail par module, conseils — déclenché à la sortie d'une zone sûre |
| **Marchand** | Vente des gris et réparation automatiques |
| **Améliorations flottantes** | Carte ancrée à l'infobulle : verdict, écart d'ilvl et écarts de stats |

> Client : Forever — `## Interface: 16001` (flavour interne `Camelot`).

---

## Installation

1. Copier le dossier `Ready2Quest` dans `.../Interface/AddOns/`
2. Vérifier le chemin final : `.../Interface/AddOns/Ready2Quest/Ready2Quest.toc`
3. `/reload`, puis `/sd`

Erreur Lua invisible ? `/console scriptErrors 1`.

---

## Tester sur Classic Era

**C'est le terrain d'essai principal tant que Forever n'est pas sorti.** Era (interface `11509`) est le client le plus pauvre en API : tout ce qui marche sur Era devrait marcher sur Forever. L'inverse n'est pas vrai : les chemins propres à Forever (recettes suivies, `GetItemStatDelta`) ne tournent jamais sur Era. La suite de tests rejoue les scénarios v1.18.0 en mode Era (API récentes retirées).

| Point | Era |
|---|---|
| Zones sûres : sous-zones (`GetSubZoneText`, `ZONE_CHANGED`) | ✅ |
| Repos dans les villages | seulement dans l'auberge : d'où l'apprentissage par indices |
| Composants de métier | recette sélectionnée dans la fenêtre de métier |
| Comparaison au survol | ilvl, stats si `GetItemStats` est exposé |

## Tester aussi sur Classic MoP

**Oui — et c'est même le meilleur terrain d'essai avant Forever.** Le client MoP Classic (interface `50504`, snapshot `5.5.4.69934`) est plus proche de Forever que Classic Era sur un point : il a aussi `C_Container`, `C_Map` et `C_UnitAuras`.

### Vérifié dans la source du client MoP

| API utilisée | MoP Classic |
|---|---|
| `C_Item.GetItemInfo` / `GetItemInfoInstant` | ✅ |
| `C_UnitAuras.GetPlayerAuraBySpellID` / `GetAuraDataByIndex` | ✅ |
| `C_Container.*` (sacs) | ✅ |
| `C_Map.GetBestMapForUnit` / `GetMapInfo` | ✅ |
| `GetNumQuestLogEntries` / `GetQuestLogTitle` (globales) | ✅ — c'est ce qu'utilise `QuestLogFrame` Classic |
| `UnitIsPVPSanctuary`, `GetRestState`, `GetXPExhaustion` | ✅ |
| `GetInventoryItemLink` / `GetInventoryItemTexture` | ✅ (API historique) |
| **`C_Item.GetItemStats` / `GetItemStatDelta`** | ❌ |
| **`C_TradeSkillUI` (craft moderne)** | ❌ |
| **énumération `C_QuestLog`** | ❌ |
| **`C_TooltipInfo`** | ❌ (non utilisé) |

### Ce que chaque module donne

| Module | Forever | MoP Classic |
|---|---|---|
| Diagnostic : sacs, vivres, potions, buffs, repos, durabilité, quêtes | ✅ | ✅ |
| Zones sûres (repos, sanctuaire, vendeur, boîte aux lettres) | ✅ | ✅ |
| Panneau d'équipement (ilvl, rareté, pièces faibles) | ✅ | ✅ |
| Comparaison au survol | verdict + **stats** | verdict + stats **si** le client expose `GetItemStats` (écart calculé localement), sinon ilvl seul |
| Composants de métier | ✅ recettes suivies | ✅ recette **sélectionnée** dans la fenêtre de métier (API legacy) |

Ce qui est dégradé est **affiché explicitement** : la carte écrit « Stats indisponibles sur ce client (ilvl seul) », et le module composants affiche « aucune recette suivie ».


### Replis « Classic » ajoutés en v0.6.0

Deux API retail n'existent dans aucun client Classic. Plutôt que de laisser deux modules morts, l'addon bascule sur les équivalents historiques :

| Fonction absente | Repli Classic | Vérifié |
|---|---|---|
| `C_TradeSkillUI.GetRecipesTracked` / `GetCraftableCount` / `GetRecipeSchematic` | `GetTradeSkillSelectionIndex` + `GetTradeSkillInfo` + `GetTradeSkillNumReagents` + **`GetTradeSkillReagentInfo`** (qui renvoie déjà le nombre possédé) | ✅ dans `Blizzard_TradeSkillUI/Vanilla`, événement `TRADE_SKILL_UPDATE` |
| `C_Item.GetItemStatDelta` | si le client expose `GetItemStats` (global pré-10.0 ou `C_Item`), l'écart est **calculé par soustraction** des deux tables de stats | ⚠️ non confirmé par client : sonde au démarrage |

Conséquence : sur Classic, le module composants fonctionne avec **la recette sélectionnée dans la fenêtre de métier** (au lieu des « recettes suivies »), et la carte de comparaison affiche les écarts de stats si la sonde trouve une source.

`/sd diag` liste les capacités détectées ; la carte de comparaison indique d'elle-même « Stats indisponibles sur ce client » quand aucune source n'existe.

### Marche à suivre

1. Copier `Ready2Quest` dans `.../Interface/AddOns/` du client MoP.
2. Si le client le signale comme obsolète : cocher **« Charger les addons obsolètes »** dans la liste des addons.
3. `/reload`, puis **`/sd diag`**.

La première ligne du diagnostic doit afficher :

```
client = Mists Classic (build 5.5.4, interface 50504)
```

Le nom du client est déduit de `GetBuildInfo()` (numéro d'interface), pas deviné : `16001` → Forever, `50504` → MoP, `11509` → Era, `20506` → TBC, `12xxxx` → Retail.

Classic Era (`11509`), TBC (`20506`) et Retail sont également déclarés dans le TOC mais **non testés**.

---

## Dépannage — « l'addon est chargé mais rien ne se passe »

Depuis la v0.5.2, l'addon **parle** au lieu d'être muet.

### Étape 1 — le témoin de chargement

Au `/reload`, tu dois voir dans le chat :

```
Ready2Quest 1.21.0 — fichiers chargés
```

| Ce que tu vois | Diagnostic |
|---|---|
| **Rien du tout** | Les fichiers ne s'exécutent pas : mauvais dossier (`AddOns/Ready2Quest/Ready2Quest/`), TOC refusé, ou addon décoché |
| **Le témoin, mais pas de panneau** | Un fichier a planté après le bootstrap → `/sd` te dira lequel |
| **Le témoin + le panneau** | Tout va bien |

### Étape 2 — `/sd diag`

La commande est enregistrée **dans `Bootstrap.lua`, premier fichier du TOC**, donc elle répond même si le reste a échoué. Elle affiche :

```
client = Mists Classic (build 5.5.4, interface 50504)
  ...capacités...
  modules : 11/11 chargés
```

Si un fichier n'a pas abouti : `non chargés : Core, UI` + la dernière erreur en rouge.

### Cause racine confirmée (erreur client du 2 nov.)

`TRACKED_RECIPE_UPDATE` est un événement **apparu en retail 10.x** : il n'existe pas dans les clients Classic. `frame:RegisterEvent("TRACKED_RECIPE_UPDATE")` levait donc une erreur **à la dernière ligne de `Core.lua`**, avant l'enregistrement de la commande — d'où un addon « chargé » mais totalement muet, sans panneau et sans `/sd`.

Erreur exacte relevée en jeu :

```
Frame:RegisterEvent(): Attempt to register unknown event "TRACKED_RECIPE_UPDATE"
```

Double correction depuis la v0.5.3 :

1. `TRACKED_RECIPE_UPDATE` est **conditionné à la capacité `crafting`** : sur un client sans API de craft (MoP, Era), l'événement n'est **même pas tenté** — donc plus aucune erreur rouge.
2. L'enregistrement reste sous `pcall` : tout autre événement inconnu est ignoré, consigné et affiché par `/sd diag` (`événements non supportés : …`).

### Étape 3 — si le témoin n'apparaît pas

```
/console scriptErrors 1
/reload
```

Puis vérifier l'arborescence exacte :

```
World of Warcraft/_classic_era_/Interface/AddOns/Ready2Quest/Ready2Quest.toc
```

Un seul niveau `Ready2Quest`, et le `.toc` directement dedans.

---

## Direction artistique : « carnet de route »

Depuis la v1.20.0, l'addon a sa propre identité. Il ne cherche plus à ressembler à l'interface Blizzard. Tout est centralisé dans `Theme.lua`.

| Élément | Choix |
|---|---|
| Accent | **ambre** `#e8a54b`, réservé à ce qui compte : page active, valeur, action principale, marque |
| Statut | vert `#6fcf7a` (distinct du vert de rareté), ambre, rouge `#e2604f` |
| Surfaces | ardoise plate `#13171b`, navigation `#0f1215`, filets `#2a3138` |
| Signature | équerre ambre dans le coin supérieur gauche de chaque fenêtre |
| Police des titres | **Alegreya Bold**, embarquée (`Fonts/`, licence OFL, sans nom réservé), pour les titres et la note ; texte courant en `GameFont` |
| Marque | boussole ambre (`Textures/logo.tga`) : bandeau des fenêtres, bouton de minicarte |
| Statut des lignes | losange plein = à voir ou en échec, losange au trait = OK : la forme dit l'état autant que la couleur |
| Contrôles | boutons, interrupteurs, pistes, croix de fermeture **dessinés par l'addon** : aucun `UIPanelButtonTemplate`, `BackdropTemplate` ni `UIPanelCloseButton` |
| Mouvement | fondu de 0,15 s à l'ouverture (`AnimationGroup`), note qui compte jusqu'à sa valeur en 0,45 s |
| Voix | « Sac bouclé, 92/100. Parti de Long-guet. », « Presque prêt », « Pas prêt » |

Textures propres : `logo.tga` (boussole 64×64), `losange.tga` et `losange_trait.tga` (16×16, blancs, teintés en jeu). Elles sont générées en code, et tout le reste est `Interface\Buttons\WHITE8X8` teinté. Si le client refuse la police, l'addon garde `GameFont` sans erreur.

---

## 1. Diagnostic de départ

### Zones sûres — villages, capitales, signaux du moment

Forever n'a pas d'enum `City` dans `UIMapType`. Depuis la v1.18.0, une zone est sûre si :

| Cas | Clé | Comment |
|---|---|---|
| Capitale apprise | `c:<mapID>` (et ses sous-cartes) | repos vu dans ≥ 2 quartiers de la carte |
| Village appris | `v:<mapID>:<sous-zone>` | 1 indice fort, ou 2 indices faibles de types différents |
| Repos en cours | `IsResting()` | auberges, capitales |
| Sanctuaire | `UnitIsPVPSanctuary("player")` | hubs neutres |
| Manuel | `/sd safe` | le village (sous-zone) courant |

Détail des indices et du délai de sortie : section v1.18.0 en tête de ce document.

### Note pondérée

| Module | Poids | Score |
|---|---|---|
| Sacs | 15 | emplacements libres / seuil |
| Butin gris | 5 | −25 par objet |
| Vivres | 20 | quantités / seuil |
| Potions & flacons | 10 | quantités / seuil |
| Buffs | 15 | −25 par buff manquant |
| Repos | 0 (information) | % d'un niveau × 2 |
| Durabilité | 15 | % d'usure |
| Composants | 5 | bloqué = 40 |
| Quêtes | 5 | prêtes = 70 |
| Composants de classe | 15 | quantités / minimum |
| Pierre de foyer | 10 | absente = 0, recharge > 10 min = 50 |
| Réparation | 10 | or / coût estimé |
| Sorts à apprendre | 5 | à apprendre = 50 |

Un module inactif (composants pour un guerrier, réparation jamais mesurée, aucun sort en attente) a un poids nul et n'influence pas la note.

Bilan : **≥ 85 PRÊT** · **≥ 60 PRÊT, AVEC RÉSERVES** · **< 60 INSUFFISANT**. Il s'affiche à droite du bandeau de titre.

### Buffs appris, pas codés en dur

Aucun `spellID` dans le code : l'addon retient les auras bénéfiques de **≥ 120 s** vues sur toi (donc pas les procs). Toutes les classes, y compris futures, « Bien nourri » inclus.

### Composants de métier

Source : **les recettes marquées comme suivies** dans ta fenêtre de métier (l'étoile Blizzard).

`GetRecipesTracked` → `GetCraftableCount` → `GetRecipeSchematic`. Sortie : `Élixir de mana : manque 6 Étoffe de lin`.

### Alerte sac plein

Sur `BAG_UPDATE_DELAYED`, une fois, réarmée au-dessus de `seuil + 2`.

---

## 4. Bouton de minicarte

Un bouton **rond et discret**, calqué sur le bouton de courrier de Blizzard : cadre cliquable 33×33, icône 18×18, liseré circulaire.

Deux chromes selon le client, chacun vérifié dans les sources du jeu :

| Client | Art utilisé | Source |
|---|---|---|
| Forever | atlas `ui-hud-minimap-button` (20×20) | `Blizzard_Minimap/Mainline/Minimap.xml` |
| Classic (Era/MoP) | `Interface\Minimap\MiniMap-TrackingBorder` (52×52) | `Blizzard_Minimap/Classic/Minimap.xml` |

Le choix se fait sur `GetBuildInfo()` (interface `16xxx` = Forever, sinon Classic). Les deux références sont celles qu'utilise Blizzard lui-même : le bouton de courrier Classic est un cadre 33×33 avec une icône 18×18 et un liseré 52×52.

| Action | Effet |
|---|---|
| **Clic gauche** | lance le check immédiatement |
| **Clic droit** | ouvre les réglages |
| **Glisser** | déplace autour de la minicarte (angle mémorisé) |
| **Survol** | infobulle : nom, dernier score, rappel des actions |

Réglages : `/sd minimap on|off`, ou la page **Affichage** de `/sd options`.

Un glissement n'ouvre pas les réglages : le clic qui suit un déplacement est ignoré.


---

## 5. Activer / désactiver les modules

Chacun des 13 modules a son interrupteur, en tête de sa page dans `/sd options` (ex. Sacs & butin pour les sacs).

**Un module désactivé est exclu du calcul de la note** : son poids devient 0, il n'entre ni au numérateur ni au dénominateur. Désactiver « Sacs » ne fait donc pas monter artificiellement le score par un 100/100 offert — le module disparaît simplement de l'équation.

| Élément | Comportement |
|---|---|
| Ligne du panneau de diagnostic | grisée, en bas de la liste, mention « désactivé » |
| Score global | recalculé sur les seuls modules actifs |
| Conseils | aucun conseil généré pour un module désactivé |
| Panneau de réglages | libellé grisé + valeur `non` |
| Persistance | `SavedVariables`, par profil |

En ligne de commande :

```
/sd modules              liste les 13 modules et leur état
/sd module vivres off    désactive un module
/sd module vivres on     le réactive
/sd module vivres        bascule
```

Cas limite traité : si **tous** les modules sont désactivés, le score vaut 0 au lieu de provoquer une division par zéro, et les 13 lignes restent affichées.

---

## 6. Fenêtres : une seule à la fois

Le diagnostic et les réglages ne s'empilent plus.

| Action | Effet |
|---|---|
| Ouvrir les réglages | ferme le diagnostic |
| Lancer un check | ferme les réglages |
| Glisser une fenêtre | la position est mémorisée (`SavedVariables`) |

Chaque fenêtre est indépendamment déplaçable, mais elles ne peuvent pas être visibles en même temps — c'était la cause du chevauchement illisible sur la capture d'écran (deux cadres centrés l'un sur l'autre).

Le panneau d'équipement reste indépendant : il vit sur le côté, à sa propre position mémorisée.

### Seuil à 0 = module inactif

Un seuil à `0` signifie désormais **module inactif**, et non « tout est bon » :

| Réglage | Avant | Maintenant |
|---|---|---|
| Potions minimum = 0 | comptait **100/100**, offrait 10 points gratuits | **exclu du calcul** |
| Objets gris avant alerte = 0 | **alertait en permanence** (0 ≥ 0) | module inactif, aucune alerte |
| Vivres minimum = 0 | comptait 100/100 | exclu du calcul |

La ligne s'affiche alors « inactif (seuil à 0) », grisée, poids nul.

---

## 7. Résumé éphémère au changement de stuff

Quand tu équipes une pièce, un bloc **Statistiques** apparaît avec l'icône de l'objet et les écarts réels, puis **disparaît en fondu après 6 secondes**.

```
S T A T I S T I Q U E S
──────────────────────────────────────────
[icône] ▼ -12        DÉGÂTS                 (rouge)
[icône] ▼ -0,60 s    VITESSE D'ATTAQUE      (vert)
```

La mise en page tient en trois éléments, sans cadre ni fond :

| Élément | Réglage |
|---|---|
| Titre | `GameFontHighlightSmall` — **même corps que les lignes** — interlettré, **en majuscules**, parchemin à 70 % |
| Règle | un trait `WHITE8X8` de 1 px, parchemin à 45 %, sur toute la largeur |
| Lignes | `GameFontHighlightSmall`, 4 emplacements, pas de 14 px, ombre portée |

Chaque ligne place la **valeur colorée à gauche** (icône de l'objet, puis une flèche et le chiffre) et le **libellé en PascalCase à droite** (« Armure », « Vitesse D'attaque »), en parchemin — le libellé ne prend jamais la couleur de l'écart.

La couleur dépend d'une **polarité par statistique** : sur la vitesse d'attaque, une valeur qui baisse est une amélioration — c'est donc vert et `▲`, comme dans la capture de référence. Quatre écarts au maximum ; les lignes inutilisées sont vidées.

L'icône vient de l'objet équipé dans l'emplacement modifié : dernier retour de `GetItemInfo`, avec repli sur `GetInventoryItemTexture` si le client ne le fournit pas. Si aucune ne répond, l'icône reste vide et le texte s'affiche seul.

Les valeurs ne sont pas devinées, elles sont mesurées avant/après via les API du client :

| Mesure | Source | Formule |
|---|---|---|
| Dégâts | `UnitDamage("player")` | min / max main droite |
| Vitesse | `UnitAttackSpeed("player")` | secondes par coup |
| DPS | calculé | `((min + max) / 2) / vitesse` |
| Armure | `UnitArmor("player")` | 2ᵉ retour (effectif) |
| Réduction | calculée | `armure / (armure + 85 × niveau + 400)` |
| Force/Agi/Int/Endu | `UnitStat` | 1 à 4 |
| Puissance d'attaque | `UnitAttackPower` | 4ᵉ retour |

Ces deux formules sont **validées** par la capture de référence : 506 d'armure au niveau 11 donnent bien **27,5 %** de réduction, et 20-24 à 1,96 s donnent bien **11,2 DPS**.

Seules les lignes qui changent sont affichées. Le relevé de référence est repris à la connexion et après chaque changement.

---

## 8. Stats au survol du portrait

Survoler le cadre du joueur ouvre un panneau **au-dessus du portrait** :

```
Statistiques
Guerrier · Armes            ilvl 18
Force                     25
Agilité                   14
Intelligence              12
Endurance                 30     ← caractéristique principale en or
Armure            506   27,5 %
DPS                     11,2
```

- **Classe et spécialisation** dans la couleur de classe (`RAID_CLASS_COLORS`), via `UnitClass` et `GetSpecializationInfo`
- la **caractéristique principale** (la plus élevée) est mise en avant en or
- se referme à la sortie du curseur

`/sd stats` affiche le panneau immédiatement, sans survol.

---

## 9. Positionner les cadres — mode édition

Les deux affichages sont **verrouillés par défaut** : ils ne réagissent pas à la souris, on ne peut pas les déplacer par accident.

Pour les placer, on entre en **mode édition** depuis les réglages :

| Ligne des réglages | Effet |
|---|---|
| **Mode édition des cadres** | ferme les réglages, affiche le résumé de stuff **et** les stats du portrait, tous deux déverrouillés avec une lueur dorée |
| **Réinitialiser les positions** | remet les deux cadres à leur emplacement d'origine |
| **Position du bouton de minicarte** | fait tourner le bouton de 45° à chaque clic |

Pendant l'édition :
- les deux blocs restent affichés — le résumé ne s'efface pas, et le panneau de stats **ne disparaît plus** quand le curseur quitte le portrait
- chaque cadre est saisi à la souris
- la position est enregistrée dès que tu relâches
- **rouvrir les réglages termine l'édition** (ce qui évite d'y rester coincé)

Le panneau s'affiche en édition même si tu avais désactivé les stats du portrait, sinon tu ne pourrais pas le placer.

En ligne de commande :

```
/sd move          entre ou sort du mode édition
/sd move stop     termine l'édition
/sd resetpos      réinitialise les positions
```

Hors édition, le panneau de stats du portrait revient à son déclenchement par survol, et le résumé de stuff à son fondu de 6 s.


---

## v1.16.1 — « Lancer le check maintenant » débordait

Capture à l'appui : le libellé sortait de son bouton et passait par-dessus « Réglages ». Cause simple — les trois boutons du pied étaient dimensionnés en dur (128, 100, 90 px) sans aucun rapport avec le texte qu'ils portent. « Lancer le check maintenant » demande environ 166 px : il manquait 40 px.

Les largeurs sont maintenant mesurées sur le libellé rendu, plus une marge de 22 px, avec un plancher pour garder une apparence homogène entre les trois. Le calcul est refait à chaque construction, donc une traduction plus longue ne débordera pas : si tu passes en anglais, les boutons s'adaptent.

Cinq assertions verrouillent le pied : chaque libellé tient dans son bouton, « Réglages » ne recouvre pas « Lancer », et l'ensemble tient dans la fenêtre sans mordre sur « Fermer ». Remis `runWidth = 128` en dur, l'assertion échoue avec `128 >= 166.4` — précisément le défaut de la capture.

---

## Ouverture automatique en quittant une zone sûre

C'est le but premier de l'addon, et il faut le dire clairement : **la fenêtre de diagnostic ne s'ouvre pas sur commande, elle s'ouvre au bon moment.** Quand tu quittes une zone apprise comme sûre (capitale, village, auberge, sanctuaire), `Evaluate` détecte la transition *sûre → non sûre* et lance le check. Tu vois ton score et tes conseils à l'instant où ça devient utile : au départ à l'aventure.

Le mécanisme ne se déclenche **que** sur cette transition. Rester en zone non sûre ne relance rien ; rentrer en ville ne l'ouvre pas. Une seconde sortie relance l'alerte normalement. Un temps de silence après connexion (`quietAfterLogin`) et un délai minimal entre deux alertes (`alertCooldown`) évitent les ouvertures parasites.

Si tu préfères un résumé dans le chat, décoche la fenêtre dans les réglages ou `/sd popup off`. `/sd check` restera toujours disponible pour un contrôle manuel.

Cinq assertions couvrent ce comportement : la sortie de zone lance le check et ouvre la fenêtre, rester dehors ne relance rien, une zone sûre n'ouvre rien, et une seconde sortie repart. Neutraliser le déclencheur en fait échouer quatre.

---

## v1.16.0 — suppression du panneau d'équipement

Le panneau flottant affichait 17 emplacements dont neuf restaient « Vide » pendant la majeure partie du leveling, des niveaux d'objet sans unité, et un `ilvl 2` qui ne veut rien dire au niveau 2. Ce qu'il apprenait tenait en une ligne, déjà fournie par le résumé de changement de stuff. Il est supprimé.

`Equip.lua` ne garde que la lecture d'inventaire dont `Stats.lua` dépend. `/sd stuff` imprime désormais le résumé en chat ; sans écart, il le dit au lieu de rester muet.

### Le bouton fantôme

La capture suivante montrait un bouton **« OPT_STUFF_SHORT »** dans la fenêtre de diagnostic. Deux fautes superposées :

1. J'avais retiré la clé de traduction avec le panneau, **sans chercher les autres usages**. `UI.lua` s'en servait encore pour un bouton.
2. Ce bouton appelait `ToggleStuff`, lui aussi supprimé : même traduit, il n'aurait rien fait.

La raison pour laquelle c'est *visible* mérite d'être notée : la métatable de `L` **renvoie la clé brute** quand elle manque, par prudence. Une chaîne vide aurait été discrète ; un identifiant en majuscules au milieu d'une interface saute aux yeux. C'est un bon choix, mais il signifie qu'aucun test ne signalait le problème.

Un garde-fou général le fait maintenant : il scanne les fichiers pour toute référence `L.XXX` et échoue si la clé n'est pas résolue. Injecté `L.OPT_FANTASME`, il signale bien `OPT_FANTASME`.

### Pied du panneau de réglages

- La ligne « Réinitialiser les positions » est retirée de la section AFFICHAGE ; un bouton **« Réinitialiser les cadres »** la remplace, à côté de « Déplacer les cadres », sur la même rangée et de même largeur.
- Les trois boutons du bas occupent trois colonnes égales ; le reste de la division (1 px) va aux premiers plutôt que de laisser un vide à droite. « Réinitialiser » est chaîné entre « Lancer » et « Fermer ».

Les tests du pied lisaient d'abord les constantes de la grille — donc ne voyaient pas un bouton mal ancré. Ils résolvent maintenant les ancres réelles. Le mock y gagnait au passage `relTo` et `relPoint`, qu'il ignorait : sans eux, une ancre chaînée était indiscernable d'une ancre absolue, et deux assertions annonçaient des écarts négatifs.

448 assertions.

---

## v1.15.1 — ce que la capture a révélé

La 1.15.0 corrigeait le blocage, mais la capture d'écran montrait trois défauts que mes tests ne voyaient pas. Ils sont tous de la même famille : **des tests qui comparent le mock à lui-même**.

**Le losange dans la colonne de droite.** Le caractère `▶` (U+25B6) n'existe pas dans `GameFontNormal` : la ligne « Réinitialiser les positions » affichait un losange de remplacement. C'est exactement la cause du rectangle blanc corrigé en 1.12.0 — et le test que j'avais écrit pour l'empêcher ne fonctionnait pas. Il cherchait les octets `E2 96 B6` mais avait été enregistré avec des séquences corrompues (`h82`), donc il passait toujours, y compris avec le caractère fautif en place. Réécrit avec `string.char(0xE2,0x96,0xB6)`, il échoue maintenant dès qu'on remet le triangle.

**Les OUI des modules 70 px trop à droite.** La section « Modules » utilisait encore `-6` au lieu de la colonne commune. Mon test d'alignement passait au vert parce que le mock de `GetPoint` renvoyait `TOPLEFT, 10, -10` en dur, quelle que soit la valeur réelle : il ne pouvait structurellement rien détecter. Le mock enregistre désormais le point posé, et le test compte les lignes mal alignées (9 détectées à l'injection).

Quatre tests existants furent du coup invalidés : ils comparaient `diagPoint.point == "TOPLEFT"` à la constante figée du mock. Ils vérifient maintenant qu'un ancrage valide et deux coordonnées numériques sont mémorisés — ce qui a un sens — au lieu de se citer eux-mêmes.

**Le trou avant les boutons.** La hauteur était additionnée à l'avance et comptait une section de trop. Elle est maintenant calculée **après** avoir posé la dernière ligne, à partir de sa position réelle. Le test vérifie que l'espace entre le dernier module et les boutons reste entre 10 et 30 px ; à l'injection de 60 px, il signale 78.

Un mot sur la méthode : la première fois, j'avais mesuré ce trou à 40 px par le calcul alors que la capture en montrait davantage. Le calcul était juste pour la partie sections mais faux pour le flux des modules ; c'est l'image qui avait raison. J'ai cessé d'additionner des marges à la main.

442 assertions.

---

## v1.15.0 — réglages refondus, et fin du piège du mode édition

Deux retours de Tristabeau : « je trouve cet écran pas du tout joli » et « quand je rentre en mode édition, il disparaît et je ne peux plus en sortir ».

### Le blocage du mode édition

C'était un **cul-de-sac**, pas un gêne visuelle. `RunOptionAction` fermait le panneau de réglages pour dégager la vue — mais le bouton **« Terminer le déplacement »** vivait dans ce panneau. Il disparaissait donc avec lui. La seule issue restante était la commande `/sd move stop`, que rien n'indiquait à l'écran.

Un **bandeau d'édition** permanent prend le relais : il s'affiche en haut de l'écran dès l'entrée en édition, rappelle qu'on fait glisser les cadres, et porte son propre bouton de sortie. Il vit dans une fenêtre séparée, survit au rafraîchissement du portrait et aux changements d'équipement, et se masque à la sortie.

### Le panneau de réglages

L'ancienne version alignait quinze lignes de même poids : impossible de voir où commençaient les réglages d'alerte, ni où finissaient les options d'affichage. Trois changements :

**Des sections.** `AFFICHAGE` (7 lignes), `SEUILS D'ALERTE` (7 lignes, avec la précision « sous ces valeurs, l'alerte se déclenche »), `DIVERS` (1 ligne), puis `Modules`. Chacune est séparée par un filet.

**Une colonne de valeurs unique.** Les `OUI`, les nombres et les boutons `-`/`+` s'alignent enfin, quelle que soit la ligne. La géométrie est exposée dans `ns.OPT_LAYOUT` et vérifiée par tests : la valeur ne touche pas le bouton `-`, et les deux boutons ne se chevauchent pas.

**Des libellés raccourcis.** « Emplacements libres minimum » devient « Emplacements libres », « Repos minimum (pourcent d'un niveau) » devient « Repos » avec l'unité portée près du nombre. La colonne de gauche se lit d'un coup d'œil au lieu d'être déchiffrée ligne par ligne.

Le bouton « Lancer le check maintenant » débordait de sa boîte ; sa largeur suit maintenant son texte.

### Vérification

437 assertions. Cinq tests couvrent le bandeau : affiché à l'entrée, porteur d'un bouton, survivant au rafraîchissement du portrait et au changement de stuff, masqué à la sortie. J'ai neutralisé `ShowEditBanner` pour vérifier qu'ils mordent — cinq échecs, puis retour au vert. Trois autres tests verrouillent la géométrie de la colonne de droite.

---

## v1.14.0 — priorités officielles Forever, relevées sur les guides

Jusqu'ici, la table `SPEC_STATS` reposait sur ma mémoire des conventions Classic. Tristabeau m'a indiqué l'URL des guides Forever sur Wowhead : `wowhead.com/forever/fr/guide/classes/druid/balance/overview-pve-dps`. C'était la bonne piste, et elle change plusieurs réponses.

### Comment les données ont été obtenues

Les pages `stat-priority-*` sont **26 sur 27** spécialisations (Mage Givre renvoyait une redirection publicitaire en cache, réessayée sans succès). Pour chacune, j'ai lu la liste numérotée officielle et conservé **l'ordre relatif des cinq attributs primaires** ; les secondaires (toucher, expertise, hâte, puissance des sorts) ne concernent pas ce panneau.

### Ce que la table disait faux

| Cas | v1.13.1 (ma mémoire) | Guide Forever |
|---|---|---|
| Mage (toutes spés) | Esprit jugé inutile | Esprit **listé**, rang 7 |
| Démoniste | Esprit écarté | Esprit **listé** |
| Chasseur | Esprit écarté | Esprit **listé** |
| Paladin Vindicte | Force d'abord | **Intelligence d'abord** |
| Guerrier Armes/Fureur | Guerrier sans Endurance | Endurance non listée en Armes, **présente en Fureur** |
| Chaman Amélioration | Force dominante | **Force et Intellect à égalité** |
| Druide Restauration | Intellect d'abord | **Esprit d'abord** |
| Démoniste | 3 attributs | **2 seulement** (Intellect, Esprit) |

Le cas le plus net : j'avais écrit que l'Esprit ne servait à rien à un mage en Classic. Le guide Forever dit l'inverse — Armure de givre fait régénérer l'Esprit même en lançant des sorts.

### Druide Farouche : deux métiers, deux ordres

L'ours et le félin n'ont pas la même priorité. Le panneau lit la forme courante (`GetShapeshiftForm`) et bascule :

- **félin** : Agilité, Force, Intellect, Esprit, Endurance ;
- **ours** : Endurance, Agilité, Force.

### Vérification

427 assertions. Quatre tests de contenu verrouillent les points où je m'étais trompé : Vindicte commence par l'Intelligence, Protection paladin par l'Endurance, Démoniste n'affiche ni Force ni Agilité, et le Farouche change d'ordre selon la forme. J'ai vérifié leur mordant : en inversant Protection paladin, puis en neutralisant la détection d'ours, les tests échouent bien avant que je rétablisse le code.

La vérification d'intégrité de la table ne réclame plus l'Endurance partout (elle n'est pas dans toutes les listes officielles) mais contrôle l'absence de doublons, de clés inconnues et de listes de plus de cinq entrées.

### Réserve

Une seule spé n'a pas pu être relevée : **Mage Givre**, alignée sur les deux autres spés de mage. À corriger si le guide publié s'en écarte.

---

## v1.13.1 — seulement les statistiques qui servent

Retour de Tristabeau : « pour le guerrier par exemple intelligence et esprit on s'en fiche ». Il a raison, et c'est une correction de fond, pas un réglage.

La v1.13.0 affichait **toujours les cinq statistiques primaires** et se contentait de souligner la bonne. Un guerrier lisait donc l'Intelligence et l'Esprit à chaque survol — deux lignes pour deux nombres qui ne changent rien à ses dégâts.

### Ce qui change

`SPEC_PRIMARY` (une clé par spé) devient `SPEC_STATS` (une **liste ordonnée** par spé). La liste sert deux choses à la fois :

- **quelles statistiques afficher** : plus rien d'autre n'apparaît ;
- **dans quel ordre** : la première est mise en or, les suivantes en parchemin.

| Classe | Spé 1 | Spé 2 | Spé 3 |
|---|---|---|---|
| Guerrier | Force, Endurance | Force, Endurance | Endurance, Force |
| Paladin | Intelligence, Endurance | Force, Endurance | Intelligence, Force, Endurance |
| Chasseur | Agilité, Endurance, Intelligence | idem | Agilité, Endurance |
| Voleur | Agilité, Force, Endurance | idem | Agilité, Endurance |
| Prêtre | Intelligence, Esprit, Endurance | idem | idem |
| Chaman | Intelligence, Endurance | Force, Agilité, Endurance | Intelligence, Esprit, Endurance |
| Mage | Intelligence, Endurance | idem | idem |
| Démoniste | Intelligence, Endurance | idem | idem |
| Druide | Intelligence, Esprit, Endurance | Force, Agilité, Endurance | Intelligence, Esprit, Endurance |

L'**Endurance** reste partout : elle ne donne pas de dégâts, mais c'est la statistique que tout joueur surveille en changeant d'équipement.

### Vérification

Neuf tests balaient la table : neuf classes, trois spécialisations chacune, aucune clé inconnue, aucun « nil » possible, Endurance présente partout. J'ai faussé volontairement `AGI` en `AG1` pour vérifier que la vérification de clés réagit — elle signale `ROGUE/3:AG1` et échoue ; rétabli ensuite.

Les tests de rendu ont été réécrits en conséquence : un Guerrier ne doit afficher **ni** Intelligence **ni** Esprit, un Voleur n'a pas d'Esprit, un Druide Restauration n'a pas de Force.

### Même réserve qu'en v1.13.0

La table vient des conventions Classic Era (Wowhead, Icy Veins), pas d'une extraction des données du client. Les cas ouverts :

- **Paladin Sacré** : l'Intelligence pour le mana, oui, mais la Force reste utile au nivellement.
- **Druide Farouche** : Force en ours, Agilité en félin — les deux sont affichées, à toi de dire si c'est trop.
- **Chaman Élémentaire** : l'Esprit n'est pas listé, alors qu'il aide la régénération. Ajoutable en une ligne.

---

## v1.13.0 — statistiques principales selon la classe et la spécialisation

Le panneau au survol du portrait soulignait **la statistique la plus élevée**. C'était simple, et faux : un guerrier Protection a presque toujours plus d'Endurance que de Force, mais c'est la Force qu'il cherche à lire. Un prêtre Sacré, lui, veut voir son Intelligence et son Esprit.

### Ce qui a changé

**L'Esprit manquait purement et simplement.** Le relevé lisait `UnitStat` 1 à 4 (Force, Agilité, Intelligence, Endurance) et ignorait la cinquième statistique primaire. Elle est maintenant relevée et affichée, avec ses traductions (`Esprit` / `Spirit`).

**La mise en avant suit la classe et l'arbre de talents**, via une table `SPEC_PRIMARY` indexée par classe puis par numéro de spécialisation :

| Classe | Spé 1 | Spé 2 | Spé 3 |
|---|---|---|---|
| Guerrier | Force | Force | Endurance |
| Paladin | Intelligence | Force | Endurance |
| Chasseur | Agilité | Agilité | Agilité |
| Voleur | Agilité | Agilité | Agilité |
| Prêtre | Intelligence | Intelligence | Intelligence |
| Chaman | Intelligence | Force | Intelligence |
| Mage | Intelligence | Intelligence | Intelligence |
| Démoniste | Intelligence | Intelligence | Intelligence |
| Druide | Intelligence | Force | Intelligence |

L'index de spécialisation est utilisé plutôt que son nom : les noms sont localisés et diffèrent selon le client, l'index est stable.

**Le DPS était tronqué.** La boucle qui crée les lignes s'arrêtait à 6 alors qu'il en faut 7 depuis l'ajout de l'Esprit — le DPS disparaissait sans que rien ne le signale. Le test existant l'a attrapé immédiatement.

### Vérification

Quatre tests balaient le panneau classe par classe : un Voleur doit souligner l'Agilité, un Prêtre l'Intelligence, un Druide Restauration ne doit pas souligner l'Endurance, et l'Esprit doit rester listé partout. J'ai vérifié qu'ils attrapent une régression en faussant volontairement la ligne du Voleur dans la table : le test échoue, puis repasse une fois la table rétablie.

### Réserve

Les correspondances de la table viennent des guides Classic Era (Wowhead, Icy Veins), pas d'une extraction des données du client. Deux cas sont discutables et je les signale plutôt que de les masquer :

- **Paladin Sacré** : le guide recommande l'Intelligence pour le mana, mais le nivellement se fait souvent à la Force. J'ai retenu l'Intelligence.
- **Druide Farouche** : l'Agilité et la Force se disputent la place selon le rôle (ours ou félin). J'ai retenu la Force.

Si l'un de ces choix diverge de ton expérience en jeu, c'est une ligne à changer dans `SPEC_PRIMARY`.

---

## v1.12.1 — plus de cadre vide quand les stats ne bougent pas

Signe d'attention de Tristabeau : un item remplacé par un autre **sans différence de statistiques** faisait apparaître le bloc titre + règle, sans aucune ligne dessous.

La cause est une conséquence directe du passage à une ligne unique. `ShowGearToast` affichait le cadre sans se demander si `ToastRows` avait produit quelque chose. Avec quatre emplacements, le cas ne se voyait pas : il restait trois lignes vides sous une première ligne. Avec un seul, un équipement sans écart donne **zéro ligne et un cadre nu**.

```lua
local built = self:ToastRows(rows, texture)
if #built == 0 then
    if self.toastFrame then self.toastFrame:Hide() end
    self.toastHideAt = nil
    return
end
```

Le cadre existant est masqué et le minuteur d'effacement remis à zéro, pour qu'un résumé précédent encore visible ne reste pas figé à l'écran.

Un test couvre ce cas : il équipe un objet de mêmes caractéristiques, vérifie qu'aucun cadre n'apparaît, et **échoue bien** si l'on retire le garde-fou (vérifié en le neutralisant).

---

## v1.12.0 — une seule ligne par item, centrage par ancrage CENTER

Demande de Tristabeau : **une seule ligne par changement d'équipement**, et son contenu centré verticalement.

### Une ligne, pas quatre

`TOAST_ROWS` passe de 4 à 1. Les écarts sont toujours calculés tous les quatre, mais seul le premier est affiché. C'est un choix de lisibilité : le bloc se lit d'un coup d'oeil, sans tableau à déchiffrer sous le feu de l'action.

Les tests qui décrivaient l'ancien format (« une ligne par écart », « tronqué à quatre lignes », `rows[4]`) ont été réécrits pour verrouiller le nouveau contrat : un seul emplacement, pas de deuxième ligne, la ligne pleine montre son icône et sa flèche.

### Le vrai motif du décalage, enfin

Trois versions ont échoué à centrer l'icône et la flèche. La comparaison des captures a donné la clé : le décalage est passé de 14 px à 19 px entre la v1.11.2 et la v1.11.4. **Le code agissait donc bel et bien — mais dans le sens inverse de celui attendu.**

La raison : une **fontstring** ancrée en `TOPLEFT` pend sous son point d'ancrage, tandis qu'une **texture** ancrée en `TOPLEFT` ne se comporte pas de la même façon vis-à-vis du décalage. Jusque-là je calculais le centre des textures avec la formule du texte, ce qui revenait à doubler l'erreur de sens.

La solution ne consiste pas à inverser un signe de plus, mais à **changer d'ancrage** : icône et flèche sont maintenant ancrées en `CENTER`, sur le milieu de la ligne. Le décalage n'a plus qu'un seul rôle — dire où est le milieu — et la question du sens disparaît.

```lua
local lineMiddle = y + TOAST_LINE_MIDDLE * factor
icon:SetPoint("CENTER", frame, "TOPLEFT", (inset + TOAST_ICON / 2) * factor, lineMiddle)
arrow:SetPoint("CENTER", frame, "TOPLEFT",
    (inset + TOAST_ARROW_LEFT + ARROW_SIZE / 2) * factor, lineMiddle)
```

Les tests comparent désormais le point enregistré (qui **est** le milieu, grâce à `CENTER`) au milieu de référence calculé depuis le haut de ligne. Ils vérifient aussi que l'icône et la flèche ont le même milieu.

### Ce que je dois à la v1.11.4

La v1.11.4 corrigeait réellement l'icône manquante au retrait d'un item, et ce correctif reste en place. En revanche elle annonçait un centrage vertical qui n'a jamais fonctionné. Son diagnostic — « il faut inverser le signe » — était partiel : le problème n'était pas le signe, mais le fait de vouloir centrer une texture avec la géométrie d'un texte.

---

## v1.11.4 — centrage vertical corrigé, icône au retrait d'un item

Deux défauts signalés en jeu, tous deux de ma faute.

### L'icône descendait au lieu de monter

La v1.11.3 prétendait centrer l'icône sur la ligne. En réalité je m'étais trompé de signe : l'icône et la flèche descendaient de 7 px sous le texte au lieu de remonter de 7 px au-dessus. La capture de Tristabeau est sans ambiguïté, la flèche flotte sous les chiffres.

Le raisonnement correct, et il m'a fallu m'y reprendre à deux fois :

- une fontstring ancrée en `TOPLEFT` **pend sous son point d'ancrage**, donc le milieu des chiffres est à `TOAST_TEXT_HEIGHT / 2` **en dessous** du haut de ligne, en coordonnées négatives ;
- le haut d'un élément dont on veut centrer le milieu se place à `milieu du texte - hauteur / 2`.

```lua
local TOAST_LINE_MIDDLE = -TOAST_TEXT_HEIGHT / 2
local iconY  = y + (TOAST_LINE_MIDDLE - TOAST_ICON / 2) * factor
local arrowY = y + (TOAST_LINE_MIDDLE - ARROW_SIZE / 2) * factor
```

Pour une ligne à `-30` : milieu des chiffres `-34`, haut de l'icône `-41`, haut de la flèche `-39`. Les trois milieux coïncident.

Les tests de la v1.11.3 ne pouvaient pas attraper cette erreur : l'un comparait `TOAST_ROW_TOP` à lui-même, une assertion tautologique qui passait toujours. Les nouveaux tests comparent des **milieux à milieux** et vérifient explicitement que l'icône remonte par rapport au haut de ligne.

### Pas d'icône quand on retirait un item

Retirer un objet laisse `after.slots[slot]` vide : il n'y a plus de lien à interroger, donc plus d'icône. La ligne s'affichait sans repère visuel.

`SlotTexture` accepte maintenant un troisième argument, le lien précédent, et essaie dans l'ordre : lien actuel, puis lien de l'item qui vient d'être retiré, puis API d'emplacement. C'est sémantiquement juste — retirer un item doit montrer *son* icône.

### Une leçon sur les mocks

Le correctif ci-dessus était bon du premier coup, mais mon test échouait : le mock ne fournissait `GetItemInfo` qu'en `C_Item.GetItemInfo`, alors que le client l'expose aussi en global. L'addon retombait silencieusement sur l'API d'emplacement, vide. Le mock est désormais fidèle au client, et un test existant qui attendait `INV_Mock10` (repli par emplacement) vérifie maintenant la vraie icône du lien.

400 assertions, aucune en échec.

## v1.11.2 — contenu centré dans le bloc

La capture montrait un déséquilibre : la règle allait jusqu'à 193 unités, le contenu s'arrêtait à 113. **40 unités de vide d'un seul côté**, le contenu collé à gauche.

Le bloc avait une largeur fixe, mais ses lignes étaient toutes ancrées à `x = 0`. Rien ne les centrait. J'ai introduit un `inset` calculé une fois pour toutes :

```lua
local inset = ((TOAST_WIDTH - TOAST_CONTENT_WIDTH) / 2) - TOAST_CONTENT_LEFT
```

Le titre, l'icône, la valeur, la flèche et le libellé sont tous décalés de cette valeur. Le contenu le plus large occupe 181 unités pour un bloc de 190 : la marge est donc de **4,5 unités de chaque côté**. C'est peu — mais c'est le bon chiffre, et il s'ajustera automatiquement si la largeur du bloc ou celle du contenu change.

Quatre tests verrouillent l'équilibre : marge gauche égale à la marge droite, inset positif, et chaque région décalée du bon montant (à l'échelle du client près).

---

## v1.11.1 — bloc resserré horizontalement

La capture en jeu montrait un bloc étiré : 64 px de vide entre le chiffre et la flèche. Deux causes, deux corrections.

**La colonne des libellés était calée sur la largeur de référence (84),** héritée d'une maquette où les valeurs étaient plus longues. Mesure faite sur les valeurs réelles : `+8` finit à 30, `-0,60 s` à environ 60. La flèche démarre donc à 62 et les libellés à 76.

| Élément | v1.11.0 | v1.11.1 |
|---|---|---|
| Colonne des libellés | 84 | 76 |
| Début de la flèche | 70 | 62 |
| Largeur du bloc | 264 | 190 |

**La flèche était positionnée relativement au libellé** (`TOAST_LABEL_LEFT - taille - écart`), ce qui la décalait à chaque changement de colonne. Elle a maintenant sa propre constante, `TOAST_ARROW_LEFT`, et trois tests vérifient qu'elle démarre après la valeur la plus longue et ne touche jamais le libellé.

Le gain final est modeste à l'œil — 8 px sur la colonne, 74 px sur la largeur du bloc — mais la mise en page ne dépend plus d'une largeur héritée : elle découle des valeurs mesurées.

---

## v1.11.0 — les flèches deviennent des textures

Les trois tentatives précédentes avaient toutes échoué pour la même raison : je cherchais un **caractère** qui s'affiche. Or la police du client s'arrête à `0xCA`, et aucune flèche — ni `▼`, ni `λ`, ni `v` — n'avait la forme voulue. `v` et `^` s'affichaient, mais ce sont des lettres, pas des flèches.

La solution est de ne plus passer par du texte. Deux textures sont livrées avec l'addon :

| Fichier | Sens | Taille |
|---|---|---|
| `Textures/fleche_hausse.tga` | gain | 128 × 128, 64 KB |
| `Textures/fleche_baisse.tga` | perte | 128 × 128, 64 KB |

Elles sont dessinées **en blanc pur** : la couleur est appliquée en jeu par `SetVertexColor`, avec le même vert et le même rouge que la valeur affichée à côté. Une seule paire de textures sert donc aux deux sens comme à toute teinte future.

La valeur ne contient plus que le nombre (`+8`, `-0,60 s`), la flèche occupe une texture de 10 px calée à gauche de la colonne des libellés. Elle est masquée sur les lignes vides et en mode édition.

Sept tests couvrent l'ensemble : valeur sans glyphe, valeur en ASCII pur, présence des textures, sens de la flèche, teinte alignée sur la valeur, visibilité, masquage sur ligne vide.

**Note sur le format.** Les `.tga` sont lus par toutes les versions du client sans plugin, et c'est le seul format d'image que le jeu accepte sans dépendance. Les fichiers sont en 128 × 128 (puissance de deux), l'empreinte réelle des flèches occupant 64 × 84 au centre du canevas.

---

## Correction v1.10.3 — les flèches en ASCII, enfin vérifiées

Troisième tentative sur le même défaut, et cette fois la cause est établie par mesure, plus par supposition.

**Le rectangle, c'est un glyphe manquant.** Sur la capture zoomée, il mesure 14 × 16 px, ratio d'une case de substitution, et se dessine en contour de 1 px **sans ombre portée** — alors que tout le texte en porte une. Une texture n'aurait pas ce comportement.

**Pourquoi `λ` et `α` ne marchaient pas non plus.** Le client range ses polices dans `Fonts/615960.slug` (police « Friz Quadrata TT »). En lisant la table de glyphes de ce fichier, on trouve les 822 codepoints enregistrés : ils s'arrêtent à **0xCA**. Ni `U+25BC`, ni `U+03BB`, ni `U+03B1` n'y figurent. J'avais supposé que « toutes les polices ont les lettres grecques » — c'est faux pour celle du client.

| Sens | v1.10.1 | v1.10.2 | v1.10.3 |
|---|---|---|---|
| Baisse | `▼` U+25BC | `λ` U+03BB | `v` ASCII |
| Hausse | `▲` U+25B2 | `α` U+03B1 | `^` ASCII |

**La règle est désormais simple : rien au-dessus de l'ASCII.** Le `v` et le `^` existent dans toutes les polices sans exception, et deux tests vérifient que le dernier octet de la flèche est bien inférieur à 128.

Les emoji de flèche verte et rouge ne sont pas une option : ils vivent à `U+2B06` / `U+2B07`, très au-delà de ce que la police contient — ils produiraient exactement le même rectangle. La couleur est déjà portée par la valeur elle-même (vert pour un gain, rouge pour une perte), le symbole n'a donc qu'à indiquer la direction.

---

## Correction v1.10.2 — casse du titre et des libellés

| Élément | v1.10.1 | v1.10.2 |
|---|---|---|
| Titre | `statistiques` en minuscules | `S T A T I S T I Q U E S` |
| Libellés | `ARMURE` en capitales | `Armure`, `Vitesse D'attaque` (PascalCase) |

Le titre repasse en majuscules — son interlettrage le distingue déjà des lignes, et c'est la casse de la référence. Les libellés passent en PascalCase, plus lisibles que des capitales sur un texte français.

Deux pièges rencontrés en écrivant la conversion, tous deux **corrigés et couverts par des tests** :

- **`string.upper` corrompt les accents.** `string.upper("é")` applique la conversion octet par octet : `é` (deux octets UTF-8) devient `Ã©`. La fonction `PascalCase` recopie donc les séquences multi-octets telles quelles et ne touche qu'aux lettres ASCII.
- **La variable d'un `for` ne s'avance pas en Lua 5.1.** Pour sauter les octets de continuation, il faut réassigner l'index de boucle — impossible avec `for`, où la valeur est réinitialisée à chaque tour. La boucle est donc en `while`.

---

## Correction v1.10.1 — le carré vert, et l'harmonisation du bloc

Deux défauts constatés à l'essai de la 1.10.0.

**Le rectangle vert à côté du chiffre** n'était pas une texture : c'était un **glyphe manquant**. Les triangles `▼` `▲` appartiennent au bloc Unicode *Geometric Shapes* (U+25BC / U+25B2) et manquent à la police utilisée par le client, qui les remplace par une case vide. C'était la deuxième fois que ce piège se présentait, après `NumberFontNormal` — la conclusion est qu'aucun caractère hors alphabet latin n'est sûr sans vérification.

| Avant | Après |
|---|---|
| `▼` U+25BC | `v` (ASCII) |
| `▲` U+25B2 | `^` (ASCII) |

Les lettres grecques minuscules font partie des jeux de caractères de base des polices, elles s'affichent partout. Elles gardent le sens — vers le bas pour une perte, vers le haut pour un gain — et prennent la couleur de la valeur.

**L'écriture** n'était pas homogène : le titre sortait dans un corps plus petit que les lignes, alors que les deux mesurent 14 px dans la référence. Le titre reprend donc le **même corps de police** que les lignes ; seule l'interlettrage et la teinte (parchemin à 70 %) le distinguent. Le bloc a désormais un rythme vertical constant.

Trois autres ajustements tirés du même essai :

- le titre abandonne les majuscules, `statistiques` dans les locales s'affiche tel quel
- l'interlettrage passe par `SetNonSpaceGlyphSpacing` quand le client l'expose, avec repli sur les espaces littérales
- le harnais de test survit désormais à une console Windows en `cp1252` : il remplace les caractères non représentables au lieu de planter au moment d'afficher le résultat

---

## Changement v1.10.0 — le résumé reprend la mise en page de la référence

La ligne unique de la 1.9.0 était trop pauvre : on ne distinguait plus la valeur du libellé, et une infinité de segments séparés par `·` se lisait mal. Le bloc reprend la composition relevée sur la maquette de référence.

| Élément | v1.9.0 | v1.10.0 |
|---|---|---|
| Titre | aucun | `S T A T I S T I Q U E S`, petit, parchemin à 70 % |
| Règle | aucune | trait continu 1 px, parchemin à 45 % |
| Structure | une ligne, segments `·` | 4 emplacements, valeur à gauche / libellé à droite |
| Libellé | dans la même phrase que la valeur | **majuscules, parchemin**, jamais coloré |
| Flèche | aucune | `▲` gain, `▼` perte, dans la couleur de la valeur |
| Icône | aucune | icône de l'objet équipé (14 × 14) |
| Fond, bordure | aucun | **aucun** (inchangé) |

Le cadre n'a pas de fond : deux colonnes de texte et un trait suffisent, l'ombre portée détache l'ensemble du décor.

Trois détails qui évitent les régressions :

- **Les flèches sont sûres.** `GameFontHighlightSmall` contient `▲` et `▼`, contrairement à `NumberFontNormal` qui les rend en points de suspension (piège déjà rencontré).
- **Les lignes inutilisées sont vidées** de leur texte *et* de leur icône. Sinon l'écart précédent resterait visible sous le nouveau.
- **En mode édition, le bloc montre sa structure** (titre, règle, quatre lignes d'attente grises). Un cadre vide n'aurait ni la bonne taille ni la bonne forme au moment du placement.

Le texte de libellé est en français dans `Locales.lua`, sous les clés `STAT_*` existantes ; seul le titre court a été ajouté (`STATS_TITLE_SHORT`).

---

## Changement v1.9.0 — le résumé éphémère n'a plus de cadre

Plus de boîte, plus de fond, plus de bordure : **une seule ligne de texte**.

```
+3 Armure   ·   -0,60 s Vitesse d'attaque
```

| Élément | Avant | Maintenant |
|---|---|---|
| Fond | noir à 66 % | **aucun** |
| Bordure | filet 1 px | **aucune** |
| Icône | 14 × 14 | **aucune** |
| Pastille par ligne | barre de 3 px | **aucune** |
| Structure | 4 lignes empilées | **une ligne**, segments séparés par `·` |
| Lisibilité | fond opaque | **ombre portée** (`SetShadowColor` + offset 1, −1) |

Chaque écart garde sa couleur : vert si c'est un gain, rouge si c'est une perte — la polarité est conservée (sur la vitesse d'attaque, une baisse est verte).

Au-delà de **trois** écarts, seuls les trois premiers sont affichés. Une ligne qui s'étire sur toute la largeur de l'écran serait pire que le problème qu'elle signale.

### Ce qui reste

- le **fondu de 6 s**
- la **position mémorisée**, déplaçable via le bouton « Déplacer les cadres »
- en mode édition, une **bordure dorée apparaît** autour de la ligne — sinon un cadre invisible serait impossible à saisir

Le panneau de stats au survol du portrait, lui, garde son filet : il reste affiché à l'écran, il a besoin d'un contour pour se détacher du décor.

## Correction v1.8.1 — les cadres ne bougeaient pas

`Theme.CreateDiscreet` préparait le déplacement sans jamais le brancher :

```lua
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
-- il manquait ceci
frame:SetScript("OnDragStart", frame.StartMoving)
```

`SetMovable` autorise, `RegisterForDrag` déclare le bouton, mais **sans `OnDragStart` rien ne se passe** : WoW n'appelle jamais `StartMoving`. Le mode édition activait bien la souris et la lueur, mais glisser ne faisait strictement rien.

Ajouté sur les deux cadres (résumé de stuff et stats du portrait), avec `OnDragStop` par défaut ; le panneau de stats garde son propre `OnDragStop` qui enregistre la position manuelle.

### Le harnais masquait le bug

Le mock définissait `StartMoving` **deux fois** — une version utile, puis un no-op qui l'écrasait. Les tests appelaient `OnDragStop` directement, donc ils passaient sans jamais vérifier que le glissement démarre.

Corrigé, et un **garde-fou** a été ajouté au lanceur : il refuse de démarrer si une méthode du mock est définie deux fois. C'est la deuxième fois que ce piège me coûtait un bug (après `SetBackdrop`) :

```
ERREUR: méthodes dupliquées dans le mock (la seconde écrase la première) :
  region:StartMoving
```

## Changement v1.8.0 — un bouton pour le mode édition

La ligne « Mode édition des cadres » avec sa flèche `▶` était tout sauf instinctive : rien n'indiquait qu'elle déclenchait un mode.

Remplacée par un **bouton pleine largeur** au-dessus du pied du panneau :

```
[        Déplacer les cadres        ]
[ Lancer le check ] [ Réinitialiser ] [ Fermer ]
```

Pendant l'édition, son libellé devient **« Terminer le déplacement »** — on sait toujours dans quel état on est, et on peut en sortir d'un clic.

Il reste utilisable en ligne de commande (`/sd move`, `/sd move stop`).

### La ligne de position devient informative

« Position du bouton de minicarte » affichait aussi un `▶`. Elle affiche maintenant **l'angle courant** :

```
Position du bouton de minicarte        225°
```

Chaque clic fait tourner de 45° et la valeur suit.

Le panneau passe de 25 à 24 lignes (13 réglages + 2 actions + 9 modules), plus le bouton.

## Chrome des fenêtres — fond et bord d'infobulle

Les deux fenêtres utilisent le chrome d'AtlasLootClassic :

```lua
{
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
```

| Élément | Source |
|---|---|
| Fond | `UI-Tooltip-Background`, noir à 92 % |
| Bord | `UI-Tooltip-Border` (neuf tranches, teinte d'origine) |
| Bandeau | bande noire à 72 % + filet doré, titre en or |
| Croix | `UIPanelCloseButton` |
| Fermeture | **Échap** via `UISpecialFrames` |
| Portrait | aucun |

Pas de template Blizzard : c'est ce que fait AtlasLoot, et c'est plus sobre qu'une fenêtre à fond de pierre.

Les deux fenêtres sont nommées (`Ready2QuestDiagFrame`, `Ready2QuestOptionsFrame`) — nécessaire pour que Échap fonctionne.

Si `BackdropTemplate` manque, le panneau retombe sur un chrome dessiné à la main (filets `WHITE8X8`) : il reste complet, simplement moins joli.

## Changement v1.6.0 — aligné sur LibDBIcon (référence AtlasLootClassic)

Le bouton de minicarte reprend **exactement** l'implémentation de `LibDBIcon-1.0`, la bibliothèque qu'utilise AtlasLootClassic.

| Paramètre | Valeur reprise |
|---|---|
| Bouton | **31 × 31**, niveau de cadre **8** |
| Liseré | `MiniMap-TrackingBorder` — **fileID 136430** |
| Pastille | `UI-Minimap-Background` — **fileID 136467** |
| Surbrillance | `UI-Minimap-ZoomButton-Highlight` — **fileID 136477** |
| Ordre des couches | liseré en `OVERLAY`, pastille en `BACKGROUND`, icône en `ARTWORK` |
| Rayon | `Minimap:GetWidth() / 2 + 5` — **calculé**, plus codé en dur |
| Angle par défaut | **225°** (valeur par défaut de LibDBIcon) |

### FileID plutôt que chemin

`SetTexture(136430)` au lieu de `"Interface\\Minimap\\MiniMap-TrackingBorder"`. C'est ce que fait LibDBIcon : le client résout le fichier par son identifiant, ce qui survit aux déplacements de fichiers et fonctionne identiquement en Classic et en Forever.

### Deux chromes, comme LibDBIcon

| Client | Liseré | Pastille | Icône |
|---|---|---|---|
| Mainline / Forever | 50 × 50 | 24 × 24 centrée (0, 1) | 18 × 18 |
| Classic (Era, MoP) | 53 × 53 | 20 × 20 à (7, −5) | 17 × 17 à (7, −6) |

Le choix se fait sur `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` quand la constante existe, sinon sur le numéro d'interface.

### Minicartes non rondes

La formule de LibDBIcon est reprise intégralement, y compris `GetMinimapShape()` et le calcul diagonal pour les minicartes carrées (ElvUI et compagnie). Plus de bouton qui flotte à côté sur une minicarte custom.

## Ce qu'AtlasLoot fait pour les fenêtres

Contrairement à ce qu'on pourrait croire, ils **n'utilisent aucun template Blizzard**. Leur cadre principal :

```lua
local frame = CreateFrame("Frame", name, nil, _G.BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetBackdrop(ALPrivate.BOX_BORDER_BACKDROP)
frame.CloseButton = CreateFrame("Button", name.."-CloseButton", frame, "UIPanelCloseButton")
tinsert(UISpecialFrames, name)
```

avec

```lua
BOX_BORDER_BACKDROP = {
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
```

Donc : fond d'infobulle + bord d'infobulle, bouton `UIPanelCloseButton`, et **Échap**. C'est plus sobre qu'une fenêtre natale à fond de pierre.

### Ce que j'ai repris d'eux

- **`UISpecialFrames`** : Échap ferme le diagnostic et les réglages (comme toutes les fenêtres du jeu)
- les deux fenêtres sont désormais **nommées** (`ReadyToQuestDiagFrame`, `ReadyToQuestOptionsFrame`), condition nécessaire pour Échap
- `UIPanelCloseButton` était déjà utilisé (le template natif le fournit)

### Ce que je n'ai pas repris

Le chrome à base de `UI-Tooltip-Background` / `UI-Tooltip-Border`. Voir la question posée en fin de message.

## Changement v1.4.0 — cadres flottants discrets

### Les « … » venaient des flèches

Les lignes du résumé utilisaient `▲` et `▼`. Ces glyphes **n'existent pas dans `NumberFontNormal`** sur Classic : le client les rendait comme des points de suspension tronqués.

Remplacés par une **barre de couleur de 3 × 9 px** — vert si c'est un gain, rouge si c'est une perte. Pas de caractère exotique, donc plus aucun risque selon la police ou la locale.

### Plus de cadre « lourd »

Les deux affichages flottants n'utilisent plus le panneau à titre (`CreatePanel`) mais un nouveau chrome minimal : `Theme.CreateDiscreet`.

| Élément | Avant | Maintenant |
|---|---|---|
| Bandeau de titre | oui | **non** |
| Croix de fermeture | oui | **non** |
| Bordure | double liseré or | **filet 1 px** or atténué (55 %) |
| Fond | `UI-DialogBox-Background-Dark` opaque | **noir à 66 %**, on voit le jeu derrière |
| Reflet de bandeau | oui | **non** |
| Hauteur | fixe | **suit le nombre de lignes** |

Le résumé de stuff fait 172 px de large pour 29 px de haut sur une seule ligne ; le panneau de stats 176 px, avec la ligne « classe · spé » et l'ilvl en en-tête à la place d'un titre.

L'idée est de se rapprocher des petits encadrés de la capture de référence : une boîte, un filet, du texte, rien d'autre.

## Changement v1.3.0 — carte de comparaison supprimée

La carte flottante de comparaison au survol a été **retirée**. Blizzard fournit déjà la comparaison native (infobulles côte à côte) et la carte faisait doublon.

| Élément | État |
|---|---|
| Carte de comparaison au survol | **supprimé** |
| Hook `TooltipDataProcessor` / `OnTooltipSetItem` | **supprimé** |
| Réglage « Comparaison au survol » | **supprimé** |
| `/sd stuff diag` | **supprimé** |
| Panneau d'équipement `/sd stuff` | conservé |
| Résumé éphémère au changement de stuff | conservé |
| Stats au survol du portrait | conservé |

283 lignes de code mort en moins. Le panneau d'équipement reste, avec son ilvl moyen et le repérage des pièces faibles.

## Corrections v1.1.1

### `Locales.lua: C stack overflow` au survol

Le repli de traduction posait sa métatable **sur la table française elle-même** :

```lua
-- cassé : sur un client frFR, base == frFR
ns.L = setmetatable(base, { __index = function(_, key)
	if frFR[key] ~= nil then return frFR[key] end   -- se rappelle à l'infini
	return key
end })
```

Sur un client français, `base` **est** `frFR`, donc la lecture de `frFR[key]` dans `__index` réentrait dans `__index` — récursion infinie dès qu'une clé manquait.

```lua
-- corrigé : métatable sur une table proxy, jamais sur base
local L = {}
setmetatable(L, { __index = function(_, key)
	local value = base[key]
	if value ~= nil then return value end
	value = frFR[key]
	if value ~= nil then return value end
	return key
end })
```

Un test de non-régression vérifie désormais qu'une clé absente renvoie son propre nom, et 50 clés absentes d'affilée.

### Bouton de minicarte mal centré et trop gros

Le liseré était ancré en `TOPLEFT` du bouton, en 52×52, pour une zone cliquable de 33×33 : le centre du chrome se retrouvait décalé d'environ 10 px vers le bas-droite, et le bouton paraissait plus gros qu'il n'était.

| Élément | Avant | v1.1.1 |
|---|---|---|
| Zone cliquable | 33×33 | **28×28** |
| Icône | 18×18 | **15×15** |
| Liseré Classic | 52×52 en `TOPLEFT` | **38×38 centré** |
| Atlas Forever | 20×20 | 32×32 centré |

---

## Corrections v1.1.2

### `Stats.lua:66: bad argument #2 (base out of range)`

En Lua, **une fonction en dernier argument déploie tous ses retours**. Donc :

```lua
-- cassé : Call() renvoie 4 valeurs, tonumber() reçoit la 2e comme « base »
snapshot.ap = tonumber(apEffective) or tonumber(Call(UnitAttackPower, "player"))
```

`UnitAttackPower` renvoie `base, posBuff, negBuff, effective` — le `posBuff` (souvent `0`) devenait l'argument `base` de `tonumber`, qui exige **2 à 36**.

- Ça ne se déclenchait que si le 4ᵉ retour était nil (mon mock le fournissait, ton client non) : les tests passaient, le jeu plantait.
- Même piège sur `UnitAttackSpeed`, qui renvoie `main, off`.

```lua
-- corrigé : on passe par des variables locales
local speedMain = Call(UnitAttackSpeed, "player")
snapshot.speed = tonumber(speedMain) or 0

local apBase, _, _, apEffective = Call(UnitAttackPower, "player")
snapshot.ap = tonumber(apEffective) or tonumber(apBase) or 0
```

Le mock reproduit maintenant les **vrais** nombres de retours, avec un test dédié où le 4ᵉ retour est nil — c'est ce cas qui plantait.

### Bouton de minicarte

| Élément | v1.1.1 | v1.1.2 |
|---|---|---|
| Rayon sur l'anneau | 80 | **76** |
| Zone cliquable | 28×28 | **26×26** |
| Icône | 15×15 | **14×14** |
| Liseré | 38×38 | **32×32** |
| Angle par défaut | 200° | **225°** (bas-gauche, zone libre) |

Nouvelle ligne dans les réglages : **« Position du bouton de minicarte »** — chaque clic fait tourner le bouton de 45° (225 → 270 → 315 → 0 → 45…). Plus besoin de le glisser pour trouver la bonne place.

---

## Commandes

```
/sd                 lance le check
/sd options         réglages par pages (9 pages, 13 modules)
/sd minimap         bouton de minicarte on/off
/sd modules         état des 13 modules
/sd module <id> on|off  active/désactive un module
/sd toast on|off    résumé éphémère au changement de stuff
/sd portrait on|off stats au survol du portrait
/sd stats           affiche les stats principales tout de suite
/sd move <cadre>    déplace le résumé de stuff ou les stats du portrait
/sd resetpos        réinitialise les positions
/sd compo           recettes suivies et composants manquants
/sd safe | unsafe   marque/retire le village (ou la capitale) actuel
/sd safe list       villages et capitales appris, avec leur source
/sd safe reset      efface toutes les zones apprises
/sd buffs | buff n  buffs suivis / bascule
/sd seuil <n>       emplacements libres minimum
/sd popup on|off    fenêtre ou résumé chat
/sd on | off        active/désactive
/sd reset           réinitialise
/sd diag            diagnostic API
```

Alias : `/sacdepart`.

---

## Fichiers

| Fichier | Lignes | Rôle |
|---|---|---|
| `Bootstrap.lua` | 65 |  |
| `Locales.lua` | 431 | frFR + enUS |
| `Compat.lua` | 92 | détection des capacités du client |
| `Theme.lua` | 326 | direction artistique Blizzard |
| `Core.lua` | 790 | détection de zone, score pondéré, modules, positions, commandes |
| `Buffs.lua` | 137 | buffs appris depuis les auras |
| `Reagents.lua` | 273 | recettes suivies / recette sélectionnée (Classic) |
| `Equip.lua` | 268 | panneau d'équipement |
| `Stats.lua` | 559 | résumé de changement de stuff + stats du portrait |
| `Minimap.lua` | 195 | bouton rond autour de la minicarte |
| `Checks.lua` | 306 | les 9 modules |
| `Options.lua` | 244 | réglages + interrupteurs de modules |
| `UI.lua` | 241 | fenêtre de diagnostic |
| **Total Lua** | **3927** | |

---

## Tests

```
python3 tests/run_tests.py     →  681 réussis, 0 échoués
```

Lua 5.1 (version du client), client WoW simulé. Couvre notamment : apprentissage par indices (sous-zone, capitale par deux quartiers, purge de l'ancien schéma), délai de sortie / vol / mort, nouveaux checks et automatismes du marchand en mode Era, chaîne de cartes parentes, anti-spam, filtrage des procs, **valeurs secrètes**, comptages sacs/vivres/potions/durabilité/quêtes, score pondéré et bilans, fenêtre de diagnostic (icônes, barres, bandeau), panneau d'équipement (17 lignes, moyenne, rareté, pièces faibles), comparaison au survol (amélioration, régressif, vide, anneaux), **les deux voies de hook tooltip**, bouton sans template Blizzard, et toutes les commandes.

---

## Ce qui n'est pas vérifié en jeu

| Point | Risque | Mitigation |
|---|---|---|
| Forme de retour de `C_Item.GetItemStatDelta` | **moyen** | `pcall` + test de type, repli « Pas de comparaison possible », `/sd diag` |
| `itemEquipLoc` → emplacement | moyen | table de correspondance, emplacement vide si inconnu |
| Voie de hook tooltip | moyen | deux voies + repli, testées |
| Chemins d'icônes de module | faible (cosmétique) | icône « ? » si absente, aucune erreur |
| Contrat des champs d'aura | moyen | repli `UnitAura`, valeurs secrètes = « inconnu » |
| `GetCraftableCount` hors fenêtre de métier | moyen | dégrade en « aucune recette suivie » |
| Granularité des `mapID` | moyen | `/sd diag` l'affiche |

**Au lancement :** `/sd diag`, puis `/sd safe list` après quelques minutes de jeu pour voir les villages appris.

---

## Limites connues

- Un addon **ne peut pas agir** (manger, réparer, vendre) : il signale.
- Composants comptés **dans les sacs uniquement**.
- Le nom d'un objet très long peut être coupé dans le bandeau de la carte.
- TOC `16001` = build `1.60.1`.
