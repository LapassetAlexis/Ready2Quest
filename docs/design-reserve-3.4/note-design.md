# Réserve, Créatures, Échoppe : note de design

Quest Companion 3.3.1 (branche qc-tidy-bottom) vers 3.4. Phase 1 : audit, benchmark, orientations, recommandation. Rien n'est codé.

## 1. Ce que dit le code aujourd'hui

- **Un spécimen** porte : espèce, étoiles (1 à 3), brillant, zone, date, dresseur d'origine, origine (capture, échange, cadeau, migration), caractère, taille. Le type, la famille, le rang et le niveau sont sur l'espèce. Il n'a ni cadenas, ni surnom, ni lien, ni âge.
- **Le compagnon n'est pas un spécimen choisi** : c'est toujours l'exemplaire du Codex de l'espèce portée. Un spécimen qui arrive avec plus d'étoiles prend d'office la place au Codex.
- **Caractère** : 8 tirés (6 à 15 %, Zen et Espiègle à 5 %). Effet fixe et petit, seulement porté : Téméraire +5 % de capture sur élites et rares, Espiègle +3 % sur tout, Curieux −10 % de baisse de curiosité, etc. Ni les étoiles ni le brillant ne le changent.
- **Taille** : 5 crans (2 / 18 / 60 / 18 / 2 %), échelle du modèle de 0,75 à 1,25. Aucun effet de jeu, 2 hauts faits.
- **Étoiles** : tirées à la mise à mort (créature normale : 65 / 28 / 7 %), capture ×1 / ×0,8 / ×0,6, force des effets +0,25 par étoile, relâcher 2 / 4 / 10. **Brillant** : force +0,5, relâcher 25.
- **Filtrer** : un tri (3 choix), une espèce, et une seule valeur parmi 15 (tous, brillants, 5 tailles, 8 caractères). Grille de 7 × 4 = 28 vignettes de 58 × 84 dans 484 px, fiche de 210 × 440 à droite. Le sélecteur d'échange n'a aucun filtre. Seule action en lot : « Faire de la place » (5 spécimens).
- **Paillettes**, gains : missions du jour 14, missions de la semaine 25 par semaine, paliers de zone 2, relâcher. Estimation : 30 par jour pour 30 minutes de jeu ; 260 par jour pour 3 heures en mode chasse (environ 84 captures, 92 % du gain vient du relâcher).
- **Paillettes**, dépenses : aides 4 / 12 / 35, limitées seulement par le sac ; 2 cosmétiques (140 en tout) ; 10 places pour 40, sans limite. Après deux jours, un gros joueur n'a plus que des places et des sifflets à acheter : la Réserve devient sans fond, et les paillettes achètent environ 7 captures sûres par jour.
- **Objectifs de collection** : sceaux de zone, paliers par type, rangs de dresseur, 3 étoiles, brillants. Rien sur la taille (hors 2 hauts faits), le caractère, la Réserve ou l'échoppe.

**Diagnostic.** Un spécimen ne se distingue d'un autre que par ses étoiles. La Réserve est une salle d'attente avant le relâcher. Trier 50 à 150 spécimens avec un critère et un clic par spécimen est une corvée. Les paillettes n'ont pas de but durable, sauf acheter des captures sûres.

## 2. Ce qu'on retient des autres jeux

- **Pokémon GO** : filtres combinés, « tout sélectionner » sur le résultat, transfert en lot, favoris protégés. Le copain gagne des cœurs plafonnés par jour : cela récompense la régularité, pas le farm.
- **Natures de Pokémon** : un plus de 10 %, un moins de 10 %. Lisible, jamais « nul ». Les tailles et les marques n'apportent que du prestige et des records.
- **Légendes Pokémon : Arceus** : des tâches de recherche par espèce, plusieurs chemins pour finir une fiche. Les doublons servent.
- **Familiers de chasseur de WoW Classic** : la loyauté monte avec le temps passé ensemble. L'individualité vient du lien, pas des chiffres.
- **Palworld et les gachas** : quand les doublons donnent de la puissance, on farme ou on paie. À éviter.
- **Stardew Valley** : les lots du centre communautaire donnent une destination aux doublons.
- **Journal des mascottes de WoW et Rematch** : puces de filtre à compteurs, vues gardées, favoris exclus des actions en lot.
- **Plaintes à ne pas reproduire** : syntaxe de recherche obscure, valeurs cachées, « parfait ou poubelle », tri manuel interminable.

## 3. Trois orientations

### A. La vitrine
Aucun nouveau bonus. Taille et caractère restent du prestige : records par espèce, étude d'espèce, titres. Filtres complets.
- Pour : aucun risque d'équilibre, peu de code de jeu.
- Contre : choisir son compagnon ne change toujours rien. La demande sur les bonus et malus reste sans réponse.

### B. Compagnon de route (recommandée)
Chaque spécimen a un profil lisible : un caractère et une taille qui ont chacun un atout et un revers, des étoiles qui fixent son potentiel, et un lien qui grandit en jouant avec lui, plafonné par jour. Les doublons nourrissent l'étude de l'espèce. Les paillettes n'achètent que du confort et de l'allure.
- Pour : garder, échanger et choisir ont un sens. La puissance vient du temps passé, pas des paillettes, et reste sous les plafonds actuels.
- Contre : équilibre à surveiller, moteur d'effets à étendre, migration du compagnon actuel.

### C. L'élevage
Équipe de 3, expéditions chronométrées des spécimens de la Réserve, fusion de doublons pour gagner des étoiles.
- Pour : la Réserve « travaille ».
- Contre : jeu d'attente, gros chantier d'interface, et la fusion fait du farm une source de puissance.

| | A. Vitrine | B. Compagnon | C. Élevage |
|---|---|---|---|
| Sens d'un spécimen | record, étude | profil, lien, étude | profil, rôle d'équipe |
| Gain de capture sur une élite 1 étoile (meilleur profil) | 0 | de 0,328 à 0,364 par essai (+11 %) | idem, plus la fusion |
| Rythme | objectifs longs | lien : 2, 6, 14, 30 jours (30 min par jour) | minuteries |
| Risque de « payer pour gagner » | nul | nul si les aides ont un stock par jour | réel |
| Coût | 2 lots | 3 lots | 5 lots ou plus |

## 4. Recommandation : B, avec l'étude d'espèce de A, et les commandes en lot 3

> Règle d'or : au lien 1, un spécimen vaut exactement ce qu'il vaut aujourd'hui. Personne ne perd rien le jour de la mise à jour. Les atouts de taille et tous les revers n'arrivent qu'au lien 2.

### 4.1 Caractère
L'atout part de la valeur d'aujourd'hui et grandit avec le lien : ×1, ×1,25, ×1,5, ×1,75, ×2 du lien 1 au lien 5. Le revers est fixe et commence au lien 2.

| Caractère | Tirage | Atout (lien 1 vers lien 5) | Revers (dès le lien 2) |
|---|---|---|---|
| Curieux | 15 % | curiosité : baisse 10 vers 20 % moins vite ; +1 paillette par palier de zone | énergie : baisse 10 % plus vite |
| Gourmand | 15 % | friandise en plus par palier : 10 vers 20 % | faim : baisse 15 % plus vite |
| Téméraire | 15 % | capture d'élites et de rares : +5 vers +10 % | en chasse, la méfiance descend jusqu'à −65 % (au lieu de −60 %) |
| Paresseux | 15 % | énergie au repos : +10 vers +20 % | curiosité : baisse 10 % plus vite |
| Taquin | 15 % | moral : baisse 8 vers 16 % moins vite ; en chasse, méfiance au pire −55 % | énergie : baisse 10 % plus vite |
| Câlin | 15 % | caresse : +25 vers +50 % de moral | moral : baisse 10 % plus vite |
| Zen (rare) | 5 % | tous les besoins : baisse 5 vers 10 % moins vite | aucun |
| Espiègle (rare) | 5 % | toute capture : +3 vers +6 % | aucun |

Les 6 caractères des mascottes ne changent pas.

### 4.2 Taille : discret ou imposant
La simulation a montré que jouer sur la vitesse de la méfiance ne change rien (elle touche son plancher en 3 à 7 captures). La taille joue donc sur le plancher lui-même.

| Taille | Tirage | Atout | Revers |
|---|---|---|---|
| Minuscule | 2 % | en chasse, méfiance au pire −45 % | élites et rares : −5 % |
| Petit | 18 % | en chasse, méfiance au pire −55 % | élites et rares : −2 % |
| Normal | 60 % | aucun | aucun |
| Grand | 18 % | élites et rares : +3 % | méfiance jusqu'à −65 % ; faim 5 % plus vite |
| Géant | 2 % | élites et rares : +8 % | méfiance jusqu'à −70 % ; faim 10 % plus vite |

- Chiffres simulés sur 2 heures de chasse d'une seule espèce : un Minuscule ramène environ 12 % de captures en plus qu'un Normal, un Géant 12 % en moins. En échange, le Géant prend environ 4,5 % d'élites en plus par essai. Aucun cran n'écrase les autres.
- **Indice de taille** de 75 à 125, tiré dans le cran. Record du plus petit et du plus grand par espèce, affiché sur la fiche de l'espèce et annoncé à la guilde. Seules tes propres captures comptent.
- Caractère et taille ajoutent ensemble au plus +0,20 à la somme des bonus de capture ; le total reste sous 95 %.

### 4.3 Étoiles et brillant
- Les étoiles fixent le lien le plus haut : 1 étoile, lien 3 ; 2 étoiles, lien 4 ; 3 étoiles, lien 5.
- La force des effets lit les étoiles de l'exemplaire porté, plus celles du meilleur exemplaire possédé.
- Brillant : rien de plus qu'aujourd'hui. Il reste un trophée.

### 4.4 Lien
- Par spécimen, pour tout le compte. Les points se gagnent seulement quand il t'accompagne, 10 par jour au plus : route parcourue (1 point par 1,5 km, 3 par jour), friandise donnée (2), caresse (1), quête rendue (2), capture réussie (2).
- Niveaux : Inconnu (0), Familier (10), Complice (35), Fidèle (80), Inséparable (180).
- Rythme mesuré : 1, 4, 8, 18 jours en faisant le plein chaque jour ; 2, 6, 14, 30 jours pour 30 minutes par jour (environ 6 points).
- Lien 3 : un souvenir par jour au plus (un appât ou une friandise simple, 30 % de chance). Lien 5 : marque « Inséparable », titre, surnom offert.
- Échange : caractère, taille, indice et étoiles sont gardés ; le lien repart à 1. Un spécimen reçu n'a donc ni atout de taille ni revers avant d'avoir été joué.
- Le compagnon reste l'exemplaire du Codex. Changer d'exemplaire relance l'attente de 2 minutes des effets et n'est pas possible en combat : on ne change pas de profil au moment de lancer le filet.
- Un exemplaire du Codex au lien 2 ou plus, ou protégé, n'est plus remplacé d'office. Le nouveau va en Réserve avec la marque « Plus d'étoiles que ton exemplaire » ; il peut alors être relâché ou échangé, après confirmation.
- Migration : le compagnon actuel de chaque personnage reçoit 10 points par jour passé sous cette apparence, 35 au plus (lien 3).

### 4.5 Filtres, tri, sélection
Mesuré dans la maquette, aux cotes du carnet : rien ne dépasse, la grille garde ses 28 vignettes.
- **Rangée 1** (484 px) : recherche par nom, surnom ou zone (166), « Filtres (n) » (86), tri (124), sens du tri (24), « Vues » (64). La liste des espèces disparaît : la recherche la remplace.
- **Rangée 2** : une pastille par groupe de filtres actif (2 au plus, puis « +n »), « Effacer », le compte (« 37 sur 62 », en rouge quand la Réserve est presque pleine), « Sélection », « Tout (37) ».
- **Panneau de filtres** posé sur la grille, 8 rangées : étoiles et version ; taille ; caractère ; type ; rang et zone (liste) ; date de capture ; lien ; état (meilleur que le Codex, doublon, protégé, relâchable ou échangeable, reçu en échange). L'un ou l'autre dans un groupe, tous entre groupes, les états se cumulent. Chaque puce porte le nombre de spécimens qu'elle laisserait.
- **Vues** : Tout, Doublons, Relâchables, Meilleurs que le Codex, Récents, Protégés, et une vue à soi (« Ma vue »).
- **Tri** : étoiles, date, nom, taille, lien, nombre de doublons, valeur au relâcher ; croissant ou décroissant.
- **Protéger** (cadenas) : jamais relâché, jamais pris dans un lot, jamais proposé par « Faire de la place ».
- **Sélection** : bouton « Sélection » puis clics simples ; Ctrl+clic et Maj+clic en raccourcis. La rangée du bas devient la barre de lot : Relâcher (+n), Protéger, Échanger (3 au plus), Annuler. La fiche liste la sélection et ce qui sera laissé de côté.
- Le sélecteur d'échange reprend la même barre et la même grille.

### 4.6 Étude d'espèce
Cinq tâches par espèce : capturée, trois étoiles, 5 captures, 3 tailles, 3 caractères ; plus une pastille dorée pour la brillante. Chaque tâche finie après la mise à jour rapporte 2 paillettes, une espèce maîtrisée 5. Ce qui est déjà fait est coché sans paiement (sinon 300 espèces rapporteraient près de 800 paillettes d'un coup). Hauts faits à 10, 50 et 100 espèces maîtrisées. Aucune puissance.

### 4.7 Échoppe
- Aides, mêmes prix (4 / 12 / 35), avec un **stock par jour** pour le compte : 5 appâts, 2 lassos, 1 sifflet. Sans cela, 260 paillettes par jour achètent 7 captures sûres.
- Dix places : 40, puis 20 de plus à chaque achat, 150 places au plus (10 achats, 1 300 en tout). Qui a déjà plus de 150 places les garde.
- Surnom d'un spécimen : 15.
- Arrivage de la semaine : 2 cosmétiques tournants, 60 à 120.
- Ni lien ni changement de caractère à vendre.
- Rythme : à 30 par jour, les places durent environ 6 semaines ; à 260 par jour, 5 jours, puis surnoms et arrivages. Le surplus ne donne aucun avantage.

### 4.8 Commandes de la semaine (lot 3)
Trois commandes par semaine, par exemple « un humanoïde Grand ou Géant », « un Téméraire de 2 étoiles ou plus », « une créature d'Orneval ». On livre un spécimen de la Réserve, qui part : 12 à 16 paillettes. Les trois livrées : un cosmétique d'arrivage au choix. « Livrer » ouvre la Réserve déjà filtrée.

## 5. Points durs relevés par la relecture technique

- Le moteur d'effets ignore aujourd'hui toute valeur négative et n'a qu'une case « caractère » : il faut des cases pour le revers et la taille, et des valeurs signées. C'est le cœur du lot 2.
- Le plancher de méfiance et les paillettes de palier n'ont pas de point d'accroche : deux nouvelles sortes d'effet.
- Le cache des effets ne suit pas le lien : on le rafraîchit au changement de niveau, pas à chaque point.
- Échanges : l'indice de taille voyage dans une nouvelle clé, sans changer la version du protocole, pour rester compatible avec la 3.3.1. Le cadenas, le surnom et le lien ne voyagent pas.
- Rien ne prouve qu'un spécimen reçu est honnête : étude, records et hauts faits de taille ne comptent que les captures faites soi-même.
- Textes : environ 140 clés, en français, anglais et espagnol.
- Tests à réécrire : ceux qui figent les valeurs de caractère, la méfiance (pas 0,15, plancher 0,4), les tris et les choix de filtre.

## 6. Trois lots

| Lot | Contenu | Fichiers principaux |
|---|---|---|
| 1. Trier | filtres, tri, recherche, vues, cadenas, sélection, barre de lot, filtres dans l'échange | CaptureSpecimens, ReserveTidy, JournalReserve, CaptureTrades, JournalWindow |
| 2. Profil et lien | atouts et revers, indice de taille, lien, potentiel, fiche, Codex non remplacé, migration | nouveau SpecimenBond, SpecimenTraits, CompanionEffects, CaptureSpecimens, CaptureTrades, Share, TrainerCard |
| 3. Collection et échoppe | étude d'espèce, records, stock et prix de l'échoppe, surnoms, arrivage, commandes, hauts faits | nouveau SpecimenStudy, JournalReserve (échoppe), MenagerieView, Weekly, FeatsData |

Le cœur du lot 2 (effets et lien) peut avancer en même temps que le lot 1 ; ses écrans attendent la fusion du lot 1. Une bêta par lot.

## 7. Décisions qui t'appartiennent

- L'orientation : A, B ou C.
- Des revers, ou seulement des atouts.
- Le stock par jour des aides à l'échoppe (sinon les paillettes continuent d'acheter des captures sûres).
- Le plafond de 150 places et le prix qui monte.
- Le lien qui repart à 1 après un échange.
- Les commandes de la semaine : dans ce chantier ou plus tard.
