# Envies du compagnon : plan de passation

Phase de design terminée dans le workspace Orca `qc-reserve-design` (2026-11-18). Ce fichier passe la main au thread `main` pour le code.

## Décision de l'utilisateur (2026-11-18)

- Orientation **B, « des états, pas des jauges »**, validée sur la maquette : « dis à main d'implémenter B ».
- **Non tranché par l'utilisateur**, à lui demander avant de coder ou à régler en bêta :
  1. **Calendrier** : je recommande une 3.5 à part, après la sortie de la 3.4 (bêta 2 publique, 17 fichiers de tests touchés). L'utilisateur n'a pas dit dans quelle version. **À lui poser en premier.**
  2. Le bonus de Rayonnant (capture +10 %, brillantes +20 %) : ma valeur, pas la sienne.
  3. « Reposé » en passant simplement en ville (`IsResting`), ou seulement à l'auberge.
- Une bêta avant toute finale ; ni PR, ni tag, ni publication sans son « go ».

## Où sont les pièces

| Pièce | Chemin (dans ce dossier) |
|---|---|
| Maquette jouable validée (page Compagnon réelle de la 3.4, bloc « Ses envies » remplacé) | `maquette.html`, aussi https://claude.ai/artifact/Ag3AGHNgbDFEU9atH7hBqt |
| Note de design (audit, benchmark, 3 orientations, chiffres) | `note-envies.md` |
| Audits du code 3.4 avec fichier:ligne | `audit/audit-*.md` |
| Deux relectures critiques | `audit/crit-equilibre.md`, `audit/crit-faisabilite.md` |
| Simulations | `sim/*.py` |

Dossier non suivi par git, dans le worktree `~/orca/workspaces/ReadyToQuest/qc-reserve-design` : à copier dans le worktree du lot.

## Pourquoi (résumé de l'audit)

- Au dernier stade, `SERENE_FLOOR` 50 égale `EFFECT_NEED_OK` 50 : la force reste à 100 % pour toujours, le système est éteint au niveau 60 (`Companion.lua:64, 3407` ; `CompanionEffects.lua:34, 365`).
- En session de quête le pire cas réaliste est une force de 75 % ; le moral reste à 100 ; les friandises débordent du garde-manger.
- Quatre seuils (30, 35, 50, 70) et deux sens du mot « heureux ».

## Spécification

### 1. Moteur : garder les envies chiffrées, en dériver les états

C'est la voie recommandée par la relecture technique : pas de migration de sauvegarde, 29 appels à `CompanionAdd` et 32 lectures de `.needs` restent valides.

- `NEED_KEYS` passe à trois : `hunger`, `energy`, `curiosity`. `mood` sort des envies.
- Chaque envie perd **0,667 par minute** de jeu : 45 minutes pour passer de 100 à 70.
- **État actif = envie à 70 ou plus.** Temps restant = `(valeur − 70) / vitesse`.
- Un déclencheur **met l'envie à 100** (il n'ajoute plus). Une friandise la met à **110** (60 minutes) : le plafond interne passe à 110, l'affichage reste en minutes. Rien ne dépasse cette valeur, rien ne s'empile.
- Sous 70, la valeur n'a plus aucun effet : on peut l'arrêter à 70 (plancher) pour simplifier.
- `SERENE_FLOOR` disparaît. Le plancher 15 aussi.
- `CompanionEffectNeeds` ne descend plus sous 1 : la force des effets de type vaut toujours 100 %. La clé de cache `needsOk` reste, elle compte les états actifs.
- Le jour de la mise à jour, toutes les envies sont posées à 70 : personne ne démarre avec un état.

### 2. Les trois états

| État (envie) | Déclencheurs (45 minutes) | Friandise (60 minutes) |
|---|---|---|
| Repu (`hunger`) | début d'une aura de repas, gain de « Bien nourri » (`Companion.lua:3379-3383`). **Pas la boisson.** Avec Ready2Quest : `DEPARTURE` avec de la nourriture (`:3973`) | biscuit |
| Reposé (`energy`) | 120 s cumulées en repos (`IsResting` ou camp ; nouveau compteur `rt.restSec` dans le tick, `:3393`), arrivée à un camp (`:3386`), tampon d'auberge du jour (`Daily.lua:284`) | infusion |
| Éveillé (`curiosity`) | nouvelle zone (`:3711`), nouveau lieu (`:3735`), nouveau tampon (`:3775`), coffre de zone (`CompanionChest.lua:268`), entrée en donjon (`:3719`), élite ou rare tuée (`:3751`) ; en mode chasse : 15 créatures tuées ou capturées en 10 minutes, une brillante tuée, une espèce nouvelle capturée | carte |

- Festin : les trois à 110. Bonbon : remet chaque état actif à sa valeur pleine (100).
- Caresse : cœurs et lien comme aujourd'hui, aucun effet sur les états.
- Les anciens gains chiffrés (changement de lieu +1, cueillette +1, atterrissage +5, mission +10, quête +12, etc.) ne donnent plus rien aux envies. Les gains de moral disparaissent avec lui.

### 3. Humeur et Rayonnant

| États actifs | Humeur (`CompanionMood`) | Effet |
|---|---|---|
| 0 | Tranquille | effets entiers |
| 1 | Content | effets entiers |
| 2 | Joyeux | effets entiers |
| 3 | Rayonnant | chance de capture ×1,10, chance de brillante ×1,20 |

- Le bonus de Rayonnant s'applique **après** les effets de type et leurs plafonds, **avant** `CAPTURE_MAX` 0,95 ; pour les brillantes, sur la chance finale.
- L'état « endormi » au retour d'une longue absence reste tel quel et prime sur l'humeur.
- Les quatre teintes de l'étiquette d'humeur forgée (`ForgeCompanion.lua:88-96`) servent aux quatre humeurs.

### 4. Une envie à la fois

- Donnée, pas seulement une bulle : `rt.wish = { key, until }`, affichée sur la page Compagnon, la fiche au survol et le tableau de bord du carnet, **quel que soit le réglage de bavardage** (les niveaux 0 à 2 coupent aujourd'hui les bulles d'envie, `Companion.lua:97-103`).
- Choix : un état inactif (pondéré par l'envie préférée du caractère) ; si les trois sont actifs, celui qui a moins de 15 minutes.
- Y répondre (l'état demandé est obtenu) : +1 point de lien, 3 par jour au plus, **hors** du plafond de 10 points du jour. Mascottes et compagnons d'hiver (pas de lien) : leurs états actifs sont remis à plein.
- Ignorée : rien. Nouvelle envie 20 minutes après (délai par envie à 1 200 s).
- Bulles : les réserves `NEED_hunger`, `NEED_energy`, `NEED_curiosity` (27 répliques) servent telles quelles ; les 9 de `NEED_mood` deviennent des réactions à l'arrivée en Rayonnant.

### 5. Stades

Pour passer un stade : le niveau, plus une envie comblée depuis que le niveau est atteint. `CompanionIsHappy` (les 4 à 70) n'est plus la porte.

### 6. Effets qui parlaient d'envies

- État préféré du caractère (`PERSONALITY_DECAY` 0,7) : il dure 60 minutes au lieu de 45.
- Revers de la 3.4 sur une envie : l'état dure 30 minutes au lieu de 45. Gourmand, Grand, Géant → Repu ; Curieux, Taquin → Reposé ; Paresseux → Éveillé. Le revers de Câlin (moral) est à redéfinir : je propose « Reposé dure 30 minutes ».
- Atouts : Curieux, la cueillette donne aussi Éveillé ; Paresseux, tout camp donne Reposé aussitôt ; Zen, tous ses états durent 60 minutes ; Taquin, son second état obtenu dure 60 minutes ; Câlin, inchangé (caresse et lien).
- Effets de confort de type `decay_*` (10 à 40 %) et `mascot_decay`, `decay_all` : inchangés dans le code, ils ralentissent la baisse donc allongent l'état. `decay_mood` : à reporter sur les trois états à un tiers de sa valeur, ou à remplacer (à décider dans le lot).
- Froid et fonte du Voile d'hiver (`WinterCompanions.lua:731-743`) : le froid garde son sens ; la fonte, qui visait le moral, accélère la baisse des trois états en zone chaude.
- Priorité quand plusieurs règles de durée s'appliquent au même état : la plus courte l'emporte.

### 7. Friandises

- `TreatForLowestNeed` : la friandise de l'état inactif, sinon de celui qui finit le plus tôt.
- Garde-manger plein : la friandise en trop devient 1 paillette (plus de repas d'office).
- Missions de caractère (repas, repos, caresses) : inchangées.
- `PersonaTickNotice` du Gourmand : « pas Repu » au lieu de « faim sous 60 ».

### 8. Écrans (cotes de la maquette, repère de la fenêtre 980 × 680)

- **Page Compagnon, colonne gauche** (x 0 à 343 du contenu), à la place des 4 rangées :
  - titre de section « Ses envies (des bonus, jamais une perte) » à y −366 ;
  - 3 plaques de 109 × 62, pas de 117, à y −393 : nom, temps restant en `F_NUMBER` agrandi, une ligne courte (« Manger ou boire » devient « Manger »), barre de 3 px en bas ; le détail dans l'infobulle ;
  - ligne d'humeur 343 × 26 à y −461 : « Humeur », étiquette teintée, 3 losanges, à droite « Encore n pour rayonner » ou « Bonus actif » ;
  - ligne de l'envie 343 × 26 en pointillés à y −493 : « Son envie », l'objet court, « +1 lien » ;
  - « Ses effets » à y −535, puis la ligne d'état : « Rayonnant : capture +10 %, brillantes +20 % » ou « Force ×n · effets entiers ».
- **Bulle du héros** : l'envie du moment quand il y en a une.
- **Tableau de bord du carnet** (184 × 80) : « Nom · humeur », 3 lignes « État / temps », une ligne « Envie : … » de 30 caractères au plus.
- **Fiche au survol** (220) : sous-titre avec l'humeur, 3 lignes d'état, l'envie.
- Guide, visite guidée, bulles du tutoriel et astuces à réécrire (`JournalGuide.lua:62, 298`, `GuidedTour.lua:96`, `CompanionLines.lua:690, 698, 801`).

## Volume

- Environ 100 clés de texte touchées, en français, anglais et espagnol.
- Environ 106 vérifications dans 17 fichiers de tests ; `companion_needs.lua` à réécrire, `companion.lua` en porte 41.
- Fichiers : `Companion.lua`, `CompanionEffects.lua`, `Personality.lua`, `Treats.lua`, `SpecimenBond.lua`, `Daily.lua`, `Capture.lua` et `Shiny.lua` (bonus de Rayonnant), `WinterCompanions.lua`, `JournalWindow.lua`, `JournalTracker.lua`, `ForgeCompanion.lua`, `JournalGuide.lua`, `GuidedTour.lua`, `CompanionLines.lua`.
- Docs : `docs/UI.md`, `docs/TECHNIQUE.md`, changelog FR et EN.

## À surveiller en bêta

- **Les règles finales n'ont pas été resimulées.** Avec la première version : Rayonnant 88 % du temps sur 30 minutes en montant de niveau, 39 % sur 2 heures au corps à corps, 60 % en donjon, 4 à 6 % en chasse au niveau 60. Le retrait de la boisson et les déclencheurs de chasse visent à resserrer cet écart.
- Premier réglage si Rayonnant est trop fréquent : la durée de 45 minutes, puis le seuil de 15 créatures en 10 minutes.
- Friandises : 3 à 10 gagnées par jour, 60 minutes chacune ; vérifier qu'elles ne rendent pas Rayonnant permanent.
- « Reposé » est quasi automatique pour qui passe en ville : voulu (le rituel du départ), à confirmer.
