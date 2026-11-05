# Interface : système de design (refonte 2026-11)

Référence de style commune à Ready2Quest et QuestCompanion. Tout passe par le
socle (`Ready2Quest/Libs/Socle/Theme.lua`, recopié dans QuestCompanion par
`tools/sync_socle.py`) : une fenêtre ne fabrique jamais ses propres couleurs,
polices ou contrôles.

Inspiration : les addons « premium » récents (fenêtre large, navigation à
gauche, en-tête à grand titre, réglages en cartes sur deux colonnes). On garde
notre identité : l'ambre (accent), le bleu de nuit (information, départ), la
boussole et le dragonnet.

## Police

**Inter** (licence OFL, `Libs/Socle/Media/Inter-*.ttf`, réduite aux caractères
latins). Trois graisses : Regular, SemiBold, Bold. Plus d'Alegreya.

Objets de police créés par le socle (un jeu par addon, noms préfixés par
`ns.APP.id`), avec repli sur les polices du jeu si le fichier est refusé :

| Rôle            | Graisse  | Taille | Usage                                   |
|-----------------|----------|--------|-----------------------------------------|
| `F_DISPLAY`     | Bold     | 26     | titre de page, grand chiffre            |
| `F_TITLE`       | Bold     | 16     | titre de fenêtre, nom de l'addon        |
| `F_HEADING`     | SemiBold | 13     | onglets, titres de bloc                 |
| `F_LABEL`       | SemiBold | 12     | libellé d'une carte de réglage, bouton  |
| `F_BODY`        | Regular  | 12     | texte courant                           |
| `F_SMALL`       | Regular  | 11     | détail, valeurs, aide                   |
| `F_CAPS`        | SemiBold | 10     | titres de section EN CAPITALES          |

Aucun texte sombre avec l'ombre noire de la police (illisible) ; texte clair
sur fond coloré plein.

## Palette

Les jetons existants restent (`GOLD` = ambre #e8a54b, `BLUE` #5b8fd6,
`PARCHMENT`, `TEXT`, `MUTED`, `GREEN`, `RED`, `ORANGE_DEEP`). Ajouts :

| Jeton          | Valeur   | Rôle                                      |
|----------------|----------|-------------------------------------------|
| `WINDOW`       | #13171b  | fond de fenêtre (= SURFACE)               |
| `NAV`          | #0d1013  | colonne de navigation, pied               |
| `ROW`          | #171c21  | carte de réglage                          |
| `ROW_ALT`      | #1b2127  | carte de réglage, rangée paire            |
| `FIELD`        | #101418  | champ, liste déroulante, recherche        |
| `EDGE`         | #3a424a  | bord de fenêtre, bouton en contour        |
| `EDGE_SOFT`    | #2a3138  | filets, séparations                       |
| `LABEL`        | #e6e1d5  | libellé de carte                          |

## Fenêtre type

```
┌──────────────┬──────────────────────────────────────────────┐
│ ◎ Ready2Quest│  Titre de la page (F_DISPLAY)            [✕] │
│ ──ambre──    │  Sous-titre (F_BODY, MUTED clair)            │
│ [Rechercher] │  ━━━━━━━━ filet ambre lumineux ━━━━━━━━      │
│ GROUPE       │  Onglet  Onglet  Onglet          [Rechercher]│
│  Page     ◔  ├──────────────────────────────────────────────┤
│ ▌Page sel ◔  │        aperçu (optionnel, fond plus sombre)  │
│  Page     ◔  ├──────────────────────────────────────────────┤
│ GROUPE       │ SECTION (détail)                             │
│  …           │ ┌ Libellé ──── ctl ┐┌ Libellé ──── ctl ┐     │
│              │ └──────────────────┘└──────────────────┘     │
│ v1.x  Forever├──────────────────────────────────────────────┤
│              │ [Secondaire] [Secondaire]        [ Terminé ] │
└──────────────┴──────────────────────────────────────────────┘
```

- Réglages : environ 980 × 680. Navigation 220 de large.
- En-tête : grand titre, sous-titre, filet ambre dégradé (transparent → ambre →
  ambre clair → transparent) avec un léger halo ; lueur ambre très discrète
  dans le coin haut de l'en-tête.
- Navigation : logo + nom en tête (filet ambre dessous), recherche, groupes en
  ambre SemiBold capitales, entrées avec interrupteur de module (rond ambre
  ouvert si actif, gris si coupé, libellé grisé si coupé), entrée choisie :
  barre ambre 2 px à gauche + dégradé ambre → transparent, libellé PARCHMENT.
  Badge bleu possible (ex. « 2/3 » missions).
- Onglets : sous-pages d'une page (définies par `parent`), soulignement ambre
  2 px sous l'onglet choisi.
- Contenu : sections (`F_CAPS`, MUTED clair, détail entre parenthèses plus
  pâle), cartes de réglage sur deux colonnes, hauteur 38, alternance
  ROW / ROW_ALT par rangée, libellé à gauche, contrôle aligné à droite.
- Contrôles :
  - interrupteur : piste 32 × 15 carrée, ambre + curseur blanc à droite si
    actif ; CONTROL + curseur MUTED à gauche sinon ;
  - curseur : piste fine 3 px, part remplie ambre, poignée ambre, valeur dans
    une petite case à droite ;
  - liste déroulante : case FIELD bordée EDGE, texte + chevron ;
  - nuancier : carré 15 bordé ;
  - roue crantée : ouvre des réglages fins ;
  - verrou : case en pointillés « 30 brillantes » pour ce qui n'est pas gagné.
- Pied : fond NAV, filet au-dessus ; boutons secondaires en contour (EDGE,
  texte clair) à gauche, bouton principal en contour ambre (texte ambre, fond
  ambre à 7 %) à droite.
- Bouton plein ambre (`primary`) : encre sombre SANS ombre. Bouton bleu
  (`adventure`) : texte blanc.

## Fenêtre de réglages (`Libs/Socle/Options.lua`)

Construite avec les briques ci-dessus ; les modules déclarent leurs pages avec
`ns.AddOptionPage`, comme avant.

- Navigation : une entrée par page. Une page de premier niveau qui a des
  sous-pages (`parent = <id>`) devient un titre de groupe (son titre, en
  capitales ambre, cliquable, avec l'interrupteur de son module) suivi d'une
  entrée par sous-page, et d'abord « Vue d'ensemble » si elle a ses propres
  réglages. Une page sans sous-page est une entrée sous le titre de son
  `group`. Interrupteur d'une entrée : `power`, sinon le module enregistré
  (`ns.RegisterModule`) qui porte le titre de la page, sinon `modules` pour
  une page de premier niveau. La liste défile à la molette quand elle dépasse
  la colonne ; la page choisie y reste en vue. Version et client en bas.
- En-tête : titre de la page choisie, sa phrase `<titre>_SUB` (sinon celle
  de son groupe).
- Onglets : seulement pour une page qui les déclare,
  `tabs = { { id, label, rows, … } }` (un conteneur par onglet, d'id
  `<page>:<onglet>`, dernier onglet retenu). Sans `tabs`, pas de barre et le
  contenu remonte sous l'en-tête.
- Aperçu : `preview = function(ns, conteneur)` sur une page (ou sa page
  parente, pour toutes ses sous-pages), bandeau de 88 px sous l'en-tête.
  `conteneur.Refresh(conteneur, ns)`, s'il est posé, suit `RefreshOptions`.
- Cartes : `bool` -> interrupteur ; `number` -> curseur + case de valeur
  (`min`, `max`, `step`, `suffix`, `display`) ; `action` -> bouton
  (`button` = clé du texte, « Lancer » par défaut), ou liste déroulante si la
  ligne a `choices()` -> `{ value, label, disabled, hint }`, `current()` et
  `choose(valeur)` (choix verrouillés grisés avec leur condition) ;
  `describe(valeur)` -> phrase sous le libellé, carte pleine largeur qui
  grandit avec la phrase ; `tooltip(valeur)` -> infobulle ; `note` -> bloc de
  texte pleine largeur (`text` = clé ou fonction relue à chaque
  rafraîchissement, `small`) ; `header` -> section. `modules` -> une carte
  interrupteur par contrôle. Une carte dont le libellé ne tient pas à gauche
  de son contrôle prend les deux colonnes ; au-delà, libellé tronqué et
  entier dans l'infobulle. `card:SetLocked(texte)` remplace le contrôle par un
  verrou (ornements pas encore gagnés).
- Listes (`ns.OPTION_LISTS`) : bloc pleine largeur, lignes alternées, molette
  et « ^ / v » ; `clear = { label, run }` et `hint` sous la liste.
- Défilement : la page s'arrête sur le haut d'un élément ; un élément qui ne
  tient pas entier est masqué (pas de rognage). Molette sur la zone de droite.
- Recherche : les cartes de toutes les pages dont le libellé contient tous les
  mots tapés (sans accents ni casse), regroupées par page ; la navigation
  compte les résultats. Choisir une page, vider le champ ou fermer rend la vue
  normale.
- Pied : `ns.OPTIONS_MAIN` et « Réinitialiser » en contour à gauche,
  « Terminé » en accent à droite. Échap et [×] ferment.

## Règles

- Aucune couleur, police ou taille en dur dans un module : jetons et briques
  du socle.
- Les briques acceptent les clients sans `SetFont` réussi, sans
  `SetGradient`, etc. (repli silencieux).
- Une fenêtre se reconstruit avec les briques ; les modules déclarent toujours
  leurs pages avec `ns.AddOptionPage` (rien à réécrire côté module).
