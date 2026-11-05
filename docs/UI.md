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

## Règles

- Aucune couleur, police ou taille en dur dans un module : jetons et briques
  du socle.
- Les briques acceptent les clients sans `SetFont` réussi, sans
  `SetGradient`, etc. (repli silencieux).
- Une fenêtre se reconstruit avec les briques ; les modules déclarent toujours
  leurs pages avec `ns.AddOptionPage` (rien à réécrire côté module).
