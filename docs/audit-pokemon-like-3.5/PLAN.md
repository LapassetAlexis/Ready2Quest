# Pokémon-like de Quest Companion : plan d'ensemble après la 3.5

Audit refait le 2026-11-18 sur `main` (QC 3.5.0) dans le workspace Orca `qc-reserve-design`. Ce fichier passe la main au thread `main`.

## Ce que l'utilisateur a demandé

« Fais un plan avec tout et donne ça à main » : les correctifs et les six axes proposés, dans un seul plan. Il n'a tranché **aucun** des choix de détail ci-dessous et n'a vu **aucune maquette** pour ces lots. Donc :

- Les valeurs chiffrées sont mes propositions, à régler en bêta.
- Les points marqués **À décider** sont à lui poser avant de coder le lot concerné.
- Tout lot qui change un écran passe d'abord par une maquette HTML validée (règle du projet). Le thread de design peut les faire, lot par lot.
- Une bêta avant toute finale ; ni PR, ni tag, ni publication sans son « go » ; textes FR, EN et ES ; commits en français sans trace d'IA.

## Pièces

| Pièce | Fichier (dans ce dossier) |
|---|---|
| Boucle de capture, chances, rythme simulé | `audit-boucle-capture.md` |
| Spécimens : plan 3.4 contre ce qui est livré | `audit-specimens-livres.md` |
| Compagnon 3.5 et lien avec la collection | `audit-compagnon.md` |
| Objectifs, récompenses, économie simulée sur 60 jours | `audit-objectifs-economie.md` |
| Première heure et découverte des fonctions | `audit-premieres-heures.md` |
| Social | `audit-social.md` |
| Mécaniques de Pokémon-like absentes | `bench-mecaniques-absentes.md` |
| Simulations | `sim/` |

Dossier non suivi par git, dans le worktree `~/orca/workspaces/ReadyToQuest/qc-reserve-design` : à copier dans le worktree du premier lot.

**Fiabilité.** Les références fichier:ligne viennent de lecteurs automatiques. J'ai relu moi-même la caresse (`CompanionEffects.lua:803-822`, `CompanionStates.lua:107-122`), le tirage des brillantes sur les barres de nom (`Bestiary.lua:695-698`) et le nom du compagnon (`Companion.lua:733-740`). Le reste est à revérifier en ouvrant le fichier. Les chiffres de rythme et d'économie sont des simulations à hypothèses, pas des données de joueurs.

## Ordre proposé

| Lot | Version | Thème | Taille |
|---|---|---|---|
| 0 | 3.5.1 | Correctifs | petit |
| 1 | 3.6 | Toujours un but (première heure + objectifs longs) | moyen |
| 2 | 3.7 | Le compagnon, c'est lui | moyen |
| 3 | 3.8 | Le monde bouge | moyen |
| 4 | 3.9 | Entre dresseurs | moyen à gros |
| 5 | 4.0 | La Réserve travaille | gros |

Les lots 1 et 2 passent avant les autres parce qu'ils pèsent sur tous les joueurs, dès la première heure. Le lot 4 dépend du nombre de joueurs qui se croisent. Le lot 5 est le plus cher et ramène un jeu d'attente : à ne lancer que si les précédents ne suffisent pas.

---

## Lot 0 — 3.5.1, correctifs

1. **Caresse et Rayonnant permanent.** Avec un effet de caresse actif (caractère Câlin, type démon), chaque caresse rallonge l'état le plus court de 25 à 100 % de 45 minutes, toutes les 15 secondes. Règle proposée : un état ne peut être rallongé par la caresse **qu'une fois** ; le droit revient quand l'état est regagné par un vrai déclencheur ou une friandise. Test à ajouter.
2. **Brillante perdue.** Une brillante en file expire au bout de 30 secondes, y compris en capture automatique qui la met en attente (`CaptureQueue.lua`, `Prune`). Règle : une brillante en file n'expire pas avant 10 minutes, et jamais pendant un combat.
3. **Textes restés sur les jauges** : `Personality.lua:43-52` et `SpecimenTraits.lua:95-97` (« moral +50 % »), `Discovery.lua:108, 124` (« l'envie la plus basse », « faim, énergie, moral et curiosité »), fiche du store `docs/publication/questcompanion.md:79, 83`.
4. **Raccourcis à l'envers** : `GuidedTour.lua:88` et les astuces « direct » et « batch » (`Discovery.lua:147-153`) décrivent Maj+clic et Ctrl+clic comme avant la capture express, active par défaut.
5. **Deux lignes de chat par espèce nouvelle** : `CAPTURE_MSG_OK` et `CAPTURE_MSG_STARS`, avec deux vocabulaires. En garder une.
6. **Commandes de la semaine** (`ShopWeek.lua:244-342`, `JournalReserve.lua:1432, 1491`) :
   - bonus des trois : si les deux arrivages sont déjà possédés, donner 30 paillettes au lieu de rien ;
   - ne tirer une commande que parmi des profils que le joueur a en Réserve ou peut raisonnablement obtenir : pas de caractère rare (Zen, Espiègle) avec 2 étoiles ; la commande de zone ne compte pas l'exemplaire du Codex ;
   - une relance par semaine, gratuite.
7. **Arrivages qui se répètent** (`ShopWeek.lua:125-141`) : tirer par paquet mélangé, pour que les 8 passent une fois toutes les 4 semaines.
8. **Surnom jamais porté** : `CompanionName()` rend le nom de l'espèce ; rendre le surnom de l'exemplaire porté quand il en a un (plaque, fiche au survol, bulles).
9. **Annonce de guilde d'un record de taille** : `SpecimenStudy.lua:239` appelle `GuildFeatAnnounce`, qui n'existe pas. Soit l'écrire (nouvelle sorte dans `GuildFeats.lua`, `KINDS`), soit retirer l'appel. Proposé : l'écrire, limité aux tailles Minuscule et Géant.
10. **Tâche d'étude « brillante »** : stockée (`row.sh`), jamais montrée ni payée. L'afficher (sixième losange, doré) et la payer 5 paillettes.
11. **Sceaux peut-être impossibles** : vérifier puis exclure du sceau les gardes de la faction adverse et les 14 lignes de niveau 9999 (Orneval 4, Hinterlands 3, Bois de la Pénombre 2, Féralas 2, Zephras 3). **Non vérifié en jeu.**
12. **Note de l'échoppe périmée** (`JournalReserve.lua:159, 244`) : ajouter l'étude, les commandes et la friandise en trop.
13. **Restes** : `SPECIMEN_SCHEMA_V2` et `ORDER_SIZES` sans usage ; l'en-tête de `Shiny.lua` ne dit pas que les barres de nom tirent aussi.

---

## Lot 1 — 3.6, « Toujours un but »

### 1A. La première heure

Constat : sur 16 notions, 5 ne sont jamais expliquées en jeu (lien, étude, commandes, effets de taille, effets de caractère). La Réserve reste vide hors mode chasse et rien ne le dit. Les 34 astuces ordinaires n'en ont aucune sur la capture ; l'échoppe est l'astuce n° 19 (environ 6 heures de jeu).

- **Visite de la capture** refaite sur la capture express : un clic, Maj+clic pour toute la file.
- **Après la première capture** : le compagnon propose de partir avec elle (« Partir avec lui » / « Plus tard »). C'est là qu'on explique le lien, en une bulle.
- **Première ligne d'étude** : une bulle l'explique une fois (« chaque espèce a cinq choses à apprendre »).
- **Ordre des astuces** (`Discovery.lua`) : la capture d'abord. Six astuces nouvelles : mode chasse, Réserve, étude, lien, échoppe, commandes.
- **États vides** : Réserve (« Active le mode chasse pour garder aussi les doublons », avec le bouton), Échoppe (comment gagner des paillettes), Créatures (« Abats une créature : le filet apparaît »).
- **Guide** : cinq sections nouvelles (Réserve et paillettes, Échoppe et commandes, Lien, Étude, Échanges) ; liste des commandes complétée.
- **Un seul vocabulaire** : la page s'appelle « Créatures », la collection « Codex », le rangement « Réserve », l'individu « spécimen ». « Exemplaire » et « Ménagerie » disparaissent des textes affichés. Le réglage de taille d'affichage du compagnon devient « échelle ».
- **Suivi à l'écran** (`JournalTracker.lua`) : nouvelles sources d'objectif, une ligne au plus chacune :
  - « Créatures de <zone> : n à capturer ici » (espèces rencontrées, pas encore capturées) ;
  - le sceau de la zone quand il reste 10 espèces ou moins ;
  - la tâche d'étude la plus proche d'être finie ;
  - l'envie du compagnon ;
  - les commandes de la semaine livrables.
  **Maquette à faire** : le bloc a quatre objectifs au plus, il faut un ordre de priorité.

### 1B. Des buts longs

Constat : les rangs s'arrêtent à 250 espèces sur 3 265 capturables ; 107 hauts faits sur 187 ne donnent rien, dont tous ceux de la 3.4 ; 7 récompenses de haut niveau sont « à venir » parce que les cosmétiques de fiche de dresseur n'existent pas.

- **Rangs de dresseur** au-delà de 250 : 500, 750, 1 000, 1 500, 2 000, 2 500, 3 000, puis « tout Azeroth » (toutes les espèces de sa faction). Un titre chacun.
- **Cosmétiques de fiche de dresseur** : créer les sortes `cardbg` et `cardframe` (elles n'existent pas, `FeatsCatMenagerie.lua:600`) et livrer les 7 promises. Fonds et cadres générés par script (`tools/gen_ui_assets.py`), jamais d'image du jeu embarquée. **Maquette à faire.**
- **Médailles de type** : paliers 4 et 5 (80 et 160 captures pour un type courant, 40 et 80 pour un type rare). Cosmétiques seulement, sans force en plus : une médaille par type sur la fiche de dresseur.
- **Récompenses des hauts faits de la 3.4 et 3.5** :
  - Inséparable : titre « l'Inséparable » et une marque sur la vignette (un glyphe, pas une couleur dorée déjà prise par les brillantes) ;
  - 10 / 50 / 100 espèces maîtrisées : aide, titre, ornement ;
  - les 8 caractères, les 5 tailles : un cadre et un fond.
- **Espèce maîtrisée, visible** : liseré dans la liste des Créatures, compte sur la fiche de dresseur. **À décider** : une espèce maîtrisée se méfie moins en chasse (plancher +0,10). C'est un petit avantage de jeu ; sans lui la maîtrise reste purement honorifique.
- **Sceaux** : après le deuxième sceau d'un biome, chaque sceau donne 15 paillettes ; les sceaux de continent reçoivent leurs cosmétiques de fiche.
- **Missions qui utilisent les nouveaux systèmes** (`Daily.lua`, `Weekly.lua`, `MissionsMenagerie.lua`) : capturer une créature qui n'est pas de taille Normale, gagner 5 points de lien, finir une tâche d'étude, être Rayonnant 10 minutes, livrer une commande. La mission de caractère tourne entre trois sortes au lieu d'être la même chaque jour pour un compagnon donné (`Daily.lua:400`).

### 1C. Les paillettes d'un gros joueur

Constat simulé : environ 21 400 paillettes gagnées en 60 jours par un joueur de 3 heures en mode chasse, dont 14 800 du relâcher ; places finies au jour 5 ; environ 19 400 en caisse au jour 60. Pour un joueur de 30 minutes (environ 1 500 en 60 jours), l'économie tient.

- **Arrivages** : un cosmétique hors de sa semaine s'achète quand même, une fois et demie plus cher.
- **Mécénat** : 100 paillettes pour 1 point de mécène, sans limite ; titres à 10, 50 et 100 points. Un puits pur, qui donne du prestige et rien d'autre.
- **Relance de commande** en plus de la gratuite : 10 paillettes.
- **À décider** : au-delà de 100 paillettes de relâcher par jour, le relâcher paie moitié. L'utilisateur a réglé lui-même les valeurs du relâcher en 3.3.1 : ne pas y toucher sans lui.

---

## Lot 2 — 3.7, « Le compagnon, c'est lui »

Constat : changer de spécimen demande deux écrans (Réserve, puis Créatures) et ne compare rien ; le lien reste à l'ancien, donc un meilleur spécimen coûte des jours de lien et on garde le moins bon ; Inséparable est atteint en deux à trois semaines et ne mène à rien ; un spécimen n'a aucune histoire ; une mascotte au dernier stade (+10 % sur toute capture) bat toute créature capturée hors de son type.

- **Un seul geste** : « Partir avec lui » sur la fiche d'un spécimen de la Réserve et sur la fiche d'une espèce. Il le met au Codex et en fait le compagnon.
- **Comparaison côte à côte** avant de confirmer : actuel et candidat, avec étoiles, taille et indice, caractère (atout et revers), lien, effets. **Maquette à faire.**
- **Le lien se transmet en partie** : quand on remplace un spécimen par un autre de la même espèce, le nouveau reçoit la moitié des points de l'ancien, une seule fois, dans la limite de son potentiel. **À décider** (la moitié, tout, ou rien).
- **Surnom partout** : plaque, bulles, fiche de dresseur, partage dans le chat.
- **Après Inséparable, les souvenirs** : par spécimen, des compteurs (captures faites ensemble, kilomètres, jours passés à tes côtés, brillantes vues ensemble) et quelques dates (capture, chaque niveau de lien). Une section « Son histoire » sur sa fiche. Au-delà de 180 points, chaque tranche de 100 points ajoute une étoile de souvenir, sans effet de jeu.
- **Sélecteur d'allure** (`CompanionAllure.lua:444-473`) : l'infobulle montre les effets, la force et le lien.
- **Montée de lien et souvenir du jour** : une bulle et un effet visuel, plus seulement une ligne de chat.
- **Envies** (`CompanionStates.lua:126-215`) :
  - trois envies de plus, liées à la collection : capturer une espèce nouvelle, capturer un spécimen qui n'est pas de taille Normale, retourner dans sa zone de capture ;
  - une envie non comblée se renouvelle au bout de 60 minutes ;
  - une envie comblée se voit : bulle, cœurs.
- **Stades d'une créature capturée** : son modèle ne grandit pas ; lui donner une aura par stade (trois niveaux de lueur), pour qu'un compagnon « Légendaire » se distingue d'un « Jeune pousse ».
- **À décider** : donner à toute créature capturée un petit bonus de capture sur tout (1 % par point de force, 5 % au plus), pour qu'une mascotte ne soit plus le meilleur choix hors type. Cela touche l'équilibre.

---

## Lot 3 — 3.8, « Le monde bouge »

Constat : aucune espèce ne dépend de l'heure, de la saison ou d'un événement ; aucune capture en instance ; la première brillante arrive le premier jour en simulation, parce que les barres de nom tirent aussi.

- **Pullulation du jour** : par zone, une espèce normale tirée de la date (la même pour tous les joueurs, sans réseau). Ce jour-là : chance de brillante ×2 et tailles rares ×2 pour cette espèce. Affichée sur la page Créatures, dans le suivi, et dite par le compagnon à l'entrée de la zone. Rien ne se rate : une autre espèce demain.
- **Habitat de la semaine** : un type de créature par semaine, capture +5 % pour ce type, et les missions de capture de la semaine s'y accordent.
- **Variantes « alpha »** : sur une élite ou une rare, 5 % de chance à la mise à mort. Spécimen marqué, indice de taille de 126 à 130, relâcher à 15 paillettes, hauts faits dédiés. Trophée, sans effet de compagnon en plus.
- **Faune des donjons** : la capture est refusée en instance parce que `JournalZone` rend `nil` (`Journal.lua:264`, `Bestiary.lua:446`), et les données n'ont pas de créatures d'instance. Il faut donc une génération de données (`tools/gen_zone_data.py`) avant tout. **Faisabilité à étudier d'abord** : volume des données, capture en groupe, capture en combat.
- **Légendaires** : les 12 boss du monde et les 70 rares élites deviennent des recherches en trois étapes (la voir, l'abattre, être Rayonnant à la mise à mort) ; la recherche finie garantit une capture. Aujourd'hui une rare ratée est perdue pour des heures, avec 12 % de chance par essai.
- **Calendrier** : une page ou un encart « Aujourd'hui en Azeroth » (pullulations des zones de ton niveau, habitat de la semaine). **Maquette à faire.**
- **À décider** : la rareté des brillantes. Soit on laisse (elles restent un plaisir fréquent), soit les barres de nom ne tirent plus. Aucune donnée de joueur ne tranche.
- **À ne pas faire** : variantes liées à la météo (aucune lecture fiable, le code le dit déjà en `Companion.lua:3603`), évolution qui change le modèle.

---

## Lot 4 — 3.9, « Entre dresseurs »

Constat : la fiche de dresseur ignore taille, caractère, lien, surnom, étude et humeur ; aucune liste « je cherche » ; un spécimen reçu ne compte ni pour l'étude ni pour les records, donc l'échange s'éteint une fois le Codex rempli ; on ne sait pas qui joue dans la guilde ; les exploits de guilde restent 60 secondes à l'écran et ne sont pas gardés ; grouper n'apporte rien à la capture.

- **Fiche de dresseur** (`TrainerCard.lua`, protocole QCTrainer) : un spécimen vedette (surnom, étoiles, taille, caractère, lien), le nombre d'espèces maîtrisées, les médailles de type, l'humeur du compagnon. Nouvelles clés seulement, pour rester lisible par les versions d'avant. Message de 255 octets au plus : mesurer. **Maquette à faire.**
- **Liste « Je cherche »** : cinq espèces ou profils, partagés avec la fiche ; la fenêtre d'échange signale ce que l'autre cherche et que tu as.
- **Dresseurs de la guilde** : un signal de présence avec la version, une page qui garde les 50 dernières fiches reçues.
- **Nouvelles de guilde gardées** : les 30 derniers exploits (dont records de taille, alpha, Inséparable), consultables après coup.
- **En groupe** : prévenir les coéquipiers qui ont l'addon quand une créature est brillante pour toi ; ouvrir les fiches et les échanges depuis un donjon (`TrainerCard.lua:1262`, `CaptureTrades.lua:1267`).
- **Concours de taille de la semaine** : une espèce tirée de la date ; le plus grand indice de la guilde gagne un titre pour la semaine. Limité à la guilde et purement honorifique, parce que rien ne prouve qu'un spécimen est honnête.
- **Un spécimen reçu vaut quelque chose** : son lien monte une fois et demie plus vite. **À décider.**
- **Partager un spécimen depuis la Réserve** (`Share.lua:9-11`, laissé « plus tard »).
- **À ne pas faire** : échange ouvert à tout le royaume, classement général (pas de serveur, messages falsifiables).

---

## Lot 5 — 4.0, « La Réserve travaille »

Constat : les spécimens rangés ne font rien ; en mode chasse, 95 % des captures finissent en doublons à long terme.

- **Expéditions** : trois par jour au plus. On envoie jusqu'à 3 spécimens de la Réserve pour 2, 4 ou 8 heures réelles, calculées à partir de l'heure de départ (donc hors connexion aussi).
- **Un thème par expédition**, tiré de la date : il demande un type, une taille ou un caractère. Plus l'équipe y répond, meilleur est le retour.
- **Retour** : 5 à 20 paillettes, une aide ou une friandise, ou une « piste » (l'emplacement d'une espèce pas encore capturée de la zone).
- **Règles** : un spécimen en expédition ne peut être ni relâché ni échangé ; son lien ne bouge pas ; aucune récompense ne donne de puissance au-delà des aides déjà plafonnées.
- **Risque** : c'est un jeu d'attente, écarté lors du premier design de la 3.4. À ne lancer qu'après avoir vu si les lots 1 à 3 suffisent à donner un rôle à la Réserve.
- **Maquette à faire.**

---

## Récapitulatif des points à décider par l'utilisateur

1. Lot 1 : une espèce maîtrisée se méfie moins, ou maîtrise purement honorifique.
2. Lot 1 : relâcher à moitié prix au-delà de 100 paillettes par jour.
3. Lot 2 : part du lien transmise au remplaçant.
4. Lot 2 : petit bonus de capture sur tout pour les créatures capturées.
5. Lot 3 : rareté des brillantes.
6. Lot 3 : capture en donjon (après étude de faisabilité).
7. Lot 4 : lien plus rapide pour un spécimen reçu.
8. Lot 5 : le faire ou non.
