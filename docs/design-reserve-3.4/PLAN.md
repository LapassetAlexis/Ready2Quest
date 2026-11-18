# QC 3.4 : Réserve, Créatures, Échoppe — plan de passation

Phase 1 terminée dans le workspace Orca `qc-reserve-design` (2026-11-18). Ce fichier passe la main au thread `main` pour le code.

## Décision de l'utilisateur (2026-11-18)

- Orientation **B, « Compagnon de route »**, validée sur la maquette.
- **Un seul lot**, testé en bêta (pas trois lots). Une bêta avant toute finale.
- Les choix restés ouverts dans la note (§ 7) n'ont pas été discutés un par un : l'utilisateur a dit « fais ta recommandation ». Les valeurs ci-dessous sont donc **mes recommandations**, à régler pendant la bêta : revers actifs, stock par jour des aides, plafond de 150 places, lien remis à 1 à l'échange, commandes de la semaine incluses.

## Où sont les pièces

| Pièce | Chemin (dans ce dossier) |
|---|---|
| Maquette interactive validée (980 × 680, thème forgé, cadre tiré du vrai code) | `maquette.html`, aussi publiée : https://claude.ai/artifact/AQcjuZ4RfdfeLgS6MHbNns |
| Note de design (audit, benchmark, 3 orientations, chiffres) | `note-design.md` |
| Audits du code, avec fichier:ligne | `audit/audit-*.md` |
| Trois relectures critiques (équilibre, UX, technique) | `audit/critique-*.md` |
| Simulations (capture, méfiance, lien, économie) | `sim/*.py` |

Ce dossier n'est pas suivi par git (rien n'a été commité) : il vit dans le worktree `~/orca/workspaces/ReadyToQuest/qc-reserve-design`. À copier dans le worktree du lot, sans `maquette.html` si on ne veut pas de fichier de 180 Ko dans le dépôt (elle ne contient aucune image du jeu : seulement nos textures du socle et notre logo).

## Règles de travail (rappel)

- Branche du lot à partir de `qc-tidy-bottom` (QC 3.3.1, non publiée), dans un worktree à part.
- Ni PR, ni tag, ni publication sans le « go » de l'utilisateur. Commits en français, sans trace d'IA, avec `git -c user.name="Alexis Lapasset" -c user.email="alexis.lapasset@gmail.com"`.
- Textes en français, anglais et espagnol (`tools/i18n.py`, `docs/TRADUCTION.md`) : environ 140 clés.
- Tests : `tests/run_tests.py` sous plusieurs `TEST_SEED`. Docs à jour : `docs/UI.md`, `docs/TECHNIQUE.md`, `docs/QC-HAUTS-FAITS.md`, changelog.
- Aucune couleur en dur, contraste mesuré, art du client par référence seulement, rien ne se chevauche (`tests/modules/ui_windows.lua`), cadres construits une fois.

## Spécification

Règle d'or : **au lien 1, un spécimen vaut exactement ce qu'il vaut en 3.3.1.** Les effets de taille et tous les revers ne s'activent qu'au lien 2.

### 1. Données (schéma `specV` 1 → 2, réparation paresseuse dans `Store`)

Par spécimen, écrits seulement s'ils ne valent pas le défaut :
- `lock` (booléen) : protégé.
- `nick` (24 octets au plus) : surnom.
- `zi` : indice de taille, entier de 75 à 125. Bornes par cran : Minuscule 75-81, Petit 82-93, Normal 94-106, Grand 107-118, Géant 119-125. Tiré à la capture ; pour l'existant, dérivé de l'`id` de façon déterministe dans le cran.
- `bond = { p = points, day = jour, c = { route, treat, pet, quest, cap } }` : compteurs du jour par spécimen, pour tout le compte, sur la clé de jour locale.

Sur `capture` :
- `study[npc] = { n = captures, z = bits de tailles, t = bits de caractères, paid = bits }`.
- `slotBuys` (migration : `floor(reserveBonus / 10)`), `shopDay = { day, appat, lasso, sifflet }`, `bondV = 1`.
- `orders` (commandes de la semaine), vue gardée dans `journalState` (`resFilter`, `resSort`, `resDesc`, `resMyView`, validés par `STATE_VALID`).

### 2. Caractère (atout ×1 / 1,25 / 1,5 / 1,75 / 2 du lien 1 au lien 5 ; revers fixe dès le lien 2)

| Caractère | Atout au lien 1 (valeur d'aujourd'hui) | Ajout | Revers |
|---|---|---|---|
| Curieux | baisse de curiosité −10 % | +1 paillette par palier de zone (fixe) | baisse d'énergie +10 % |
| Gourmand | friandise en plus par palier 10 % | | baisse de faim +15 % |
| Téméraire | capture élites et rares +5 % | | plancher de méfiance −0,05 |
| Paresseux | énergie au repos +10 % | | baisse de curiosité +10 % |
| Taquin | baisse de moral −8 % | plancher de méfiance +0,05 (fixe) | baisse d'énergie +10 % |
| Câlin | caresse +25 % | | baisse de moral +10 % |
| Zen | baisse de tous les besoins −5 % | | aucun |
| Espiègle | toute capture +3 % | | aucun |

Les 6 caractères des mascottes ne changent pas. Le changelog doit dire que Curieux et Taquin gagnent un second effet.

### 3. Taille (dès le lien 2)

Plancher de méfiance d'aujourd'hui : 0,40 (soit −60 % au pire). Le pas (0,15 par capture) ne change pas.

| Taille | Plancher de méfiance | Capture élites et rares | Autre |
|---|---|---|---|
| Minuscule | 0,55 | −5 % | |
| Petit | 0,45 | −2 % | |
| Normal | 0,40 | 0 | |
| Grand | 0,35 | +3 % | baisse de faim +5 % |
| Géant | 0,30 | +8 % | baisse de faim +10 % |

- Plancher final = celui de la taille + caractère, borné à [0,25 ; 0,60].
- Caractère + taille : au plus +0,20 (et au moins −0,10) dans la somme des bonus de capture ; `CAPTURE_MAX` 0,95 inchangé.
- Records par espèce (plus petit, plus grand indice) : captures faites soi-même seulement (`origin == "capture"`), annonce de guilde à un nouveau record.

### 4. Étoiles

- Lien le plus haut : 1 étoile → 3 ; 2 étoiles → 4 ; 3 étoiles → 5.
- La force des effets lit les étoiles de **l'exemplaire du Codex porté** (`SpecimenReference(npc, shiny).stars`), plus `CaptureStars` de l'espèce (sinon un 1 étoile lié garderait la force d'un 3 étoiles resté en Réserve).
- Brillant : inchangé.

### 5. Lien

- Points seulement quand le spécimen est l'exemplaire porté, 10 par jour au plus : route (1 point par 1,5 km de `data.travel`, 3 par jour), friandise donnée (2), caresse (1), quête rendue (2), capture réussie (2).
- Seuils : Familier 10, Complice 35, Fidèle 80, Inséparable 180.
- Lien 3 : un souvenir par jour au plus, 30 % de chance, un appât ou une friandise simple (jamais lasso ni sifflet). Lien 5 : marque « Inséparable », titre, surnom offert.
- Échange : caractère, taille, indice (`x`, nouvelle clé, `TRADE_PROTO` inchangé ; absent = milieu du cran) et étoiles voyagent ; `lock`, `nick`, `bond` ne voyagent pas. Vérifier `#encodé ≤ 250` avec des noms de 48 octets.
- Changer d'exemplaire du Codex pour la version portée : remet `record.since` (attente de 120 s des effets), refusé en combat.
- Un exemplaire du Codex au lien 2 ou plus, ou protégé, n'est plus remplacé d'office. Le nouveau va en Réserve, marqué « Plus d'étoiles que ton exemplaire ». Dans ce cas précis, `SpecimenCanRelease` et `SpecimenCanTrade` ne refusent plus pour la raison `better` : ils demandent confirmation.
- Migration : pour l'apparence `cap:` courante de chaque personnage, `min(35, 10 × jours depuis record.since)`, le plus grand entre personnages.
- Cache des effets : `Touch(capture)` seulement au changement de niveau de lien, jamais à chaque point.

### 6. Moteur d'effets (`CompanionEffects.lua`) : le point dur

- Aujourd'hui `ActiveOf` ne garde que `value > 0`, `CaptureChance` sort si `bonus <= 0`, et il n'y a qu'une case `trait`. Il faut des cases `traitMinus`, `size`, `sizeMinus` (seulement si un spécimen est porté ; ni mascotte ni compagnon d'hiver), des valeurs signées, et le retrait de la sortie anticipée (bonus borné à −0,5).
- Deux nouvelles sortes d'effet : `wary` (plancher de `CaptureWariness`) et `milestone` (lu dans `PaillettesOnMilestones`, ignoré pour les rattrapages `opts.quiet`).
- `base` reste la valeur du lien 1 ; multiplicateur du lien dans `CompanionTraitEffect(trait, bond)`.

### 7. Réserve : filtres, tri, sélection (cotes de la maquette, contenu de 710 px)

- Rangée des vues (y −106) : « Réserve | Échanges », pastille des paillettes. Bouton du cadeau déplacé ici.
- Rangée 1 (y −140, 484 px) : recherche nom, surnom ou zone (166) ; « Filtres (n) » (86, à x 172) ; tri (124, à x 264) ; sens (24, à x 390) ; « Vues » (64, à x 420). La liste des espèces disparaît.
- Rangée 2 (y −172) : une pastille par groupe actif (2 au plus, 128 px au plus, puis « +n »), « Effacer », compte « 37 sur 62 » (rouge et « presque pleine » à 5 places de la limite), « Sélection », « Tout (n) ». L'ancienne ligne d'alerte rouge vit dans ce compte.
- Grille : 7 × 4 vignettes inchangées (y −204). Vignette : cran de taille en haut à gauche, cadenas en haut à droite, « ▲ » vert si plus d'étoiles que l'exemplaire du Codex, pips verts du lien, coche de sélection.
- Panneau de filtres posé sur la grille (modal : les vignettes dessous ne reçoivent pas la souris), construit une fois, 8 rangées : étoiles + version ; taille ; caractère (les 14, les 6 exclusifs n'apparaissant que si un spécimen les porte) ; type ; rang + zone (liste déroulante) ; date de capture ; lien ; état (meilleur que le Codex, doublon, protégé, relâchable ou échangeable, reçu en échange). OU dans un groupe, ET entre groupes, les états se cumulent. Compteur sur chaque puce, mis en cache sur `specSerial` et le filtre. Pied : compte, « Garder comme Ma vue », « Effacer », « Voir ».
- Vues : Tout, Doublons, Relâchables, Meilleurs que le Codex, Récents (7 jours), Protégés, « Ma vue » (une seule).
- Tris : étoiles, date, nom, taille (indice), lien, nombre de doublons, valeur au relâcher ; deux sens.
- Sélection : mode « Sélection » (clic = cocher, réutilise le mode de « Faire de la place ») ; Ctrl+clic et Maj+clic en raccourcis. Barre de lot à la place de la rangée du bas : compte, « Relâcher +n », « Protéger », « Échanger » (3 au plus), « Annuler ». La fiche liste la sélection (12 lignes, puis « et n autres »), le gain, ce qui est laissé de côté, puis demande confirmation.
- « Faire de la place » : applique la vue Relâchables triée par valeur croissante et coche 5 spécimens non brillants, non protégés.
- Fiche (210 × 440, modèle réduit à 126 de haut) : nom ou surnom, étoiles, type et rang ; caractère avec atout (vert) et revers (orange) ; taille et indice avec atout et revers ; lien (4 segments, ceux hors potentiel en pointillés) ; origine ; boutons « Mettre au Codex », « Protéger », « Relâcher +n » ; « Localiser » devient un bouton-icône sur le modèle. Au lien 1, revers et effets de taille sont affichés estompés.
- Sélecteur d'échange : même barre, même panneau, grille de 3 rangées sous les deux offres ; non échangeables estompés avec leur raison.
- Recherche : `ClearFocus` au clic sur la grille, à `OnHide`, à `PLAYER_REGEN_DISABLED`.

### 8. Créatures

- Nouvelle puce d'état « Étude à finir ».
- Liste : 5 losanges d'étude + 1 doré (brillante) par espèce capturée.
- Fiche d'espèce : les 5 tâches, les records de taille, « Tes exemplaires » (3 lignes : étoiles, taille, caractère, lien ; clic = le mettre au Codex), « Prendre comme compagnon ».

### 9. Étude d'espèce

Tâches : capturée ; trois étoiles ; 5 captures ; 3 tailles ; 3 caractères ; en plus, brillante. 2 paillettes par tâche finie **après** la mise à jour, 5 pour l'espèce maîtrisée ; ce qui est déjà acquis est coché sans paiement. Seules les captures faites soi-même comptent. Hauts faits à 10, 50, 100 espèces maîtrisées ; hauts faits de lien (premier Familier, premier Inséparable), des 8 caractères, des 5 tailles.

### 10. Échoppe

- Aides : prix inchangés (4 / 12 / 35), stock par jour pour le compte : 5 appâts, 2 lassos, 1 sifflet.
- Dix places : `40 + 20 × slotBuys`, 150 places au plus ; au-dessus de 150, on garde et on affiche « au plus grand ».
- Surnom : 15.
- Arrivage de la semaine : 2 cosmétiques tournants (60 à 120), à piocher dans les cosmétiques marqués `soon` et des variantes de teinte.
- Commandes de la semaine : 3 demandes (type + taille, caractère + étoiles, zone), livraison d'un spécimen de la Réserve (il part), 12 à 16 paillettes, les trois : un cosmétique d'arrivage au choix. « Livrer » ouvre la Réserve filtrée.
- Mise en page de la maquette : rangées de 44 (pas de 48), sections « Arrivage » à y −282 et « Commandes » à y −362 du contenu.

## Ordre conseillé dans le lot unique

1. Données et filtres : `CaptureSpecimens.lua` (prédicats, tris, `lock`, `specV 2`), `ReserveTidy.lua`, `JournalWindow.lua` (`STATE_VALID`).
2. Moteur : `CompanionEffects.lua` (cases, valeurs signées, `wary`, `milestone`), nouveau `SpecimenBond.lua` (enveloppe `CompanionTick`, `TreatGive`, `CompanionPet`, `CaptureResolve`, `QUEST_TURNED_IN`), `SpecimenTraits.lua` (`zi`, atouts et revers), `CaptureTrades.lua` (clé `x`, `CanTrade`).
3. Écrans : `JournalReserve.lua` (Réserve, panneau, barre de lot, fiche, échoppe), sélecteur d'échange, `MenagerieView.lua` et la fiche d'espèce, `Share.lua`, `TrainerCard.lua`.
4. Collection : nouveau `SpecimenStudy.lua`, `Weekly.lua` (commandes), `FeatsData.lua`, `FeatsCatMenagerie.lua`.
5. Textes (FR, EN, ES), aperçus `tests/snapshot.py`, docs.

Les étapes 1 et 2 touchent des fichiers différents et peuvent avancer en parallèle ; l'étape 3 les attend.

## Tests à réécrire ou ajouter

- `specimen_traits.lua` : `base == cap` (l. 200), valeurs figées de Curieux 0,10 et Espiègle 0,03 (l. 358, 374).
- `specimens.lua` : méfiance pas 0,15 et plancher 0,4 (l. 377-400), non-remplacement du Codex (près de l. 454).
- `trades.lua` (près de l. 322) : raison `better`, clé `x`, taille du message.
- `menagerie_journal.lua`, `ui_windows.lua` (panneau, barre de lot, deux styles), contrastes des nouvelles encres.
- Nouveaux : lien (plafonds par jour, niveaux, potentiel, migration, échange), étude (pas de paiement rétroactif, captures seulement), échoppe (stock, prix, plafond), filtres (OU / ET, compteurs).

## À surveiller pendant la bêta

- Le gain de capture reste discret : une élite 1 étoile passe de 0,328 à 0,364 par essai avec le meilleur profil.
- Rythme du lien pour un joueur de 30 minutes : 2, 6, 14, 30 jours.
- Le stock d'un sifflet par jour, et le prix des places.
- Lisibilité de la fiche (elle est dense) et du panneau de filtres en jeu.
