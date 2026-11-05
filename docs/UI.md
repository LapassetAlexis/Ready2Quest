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

## Fenêtres des modules

Toutes les autres fenêtres et cadres suivent le même langage, à leur taille
(400 à 520 de large, pas 980).

- `Theme.CreateDialog(parent, w, h, { name, title, subtitle, footer, logo })` :
  `CreateWindow` + en-tête compact (64 : logo 28, titre `F_TITLE`, sous-titre
  `F_BODY` MUTED clair, filet ambre lumineux) + pied NAV de 52 (`footer =
  false` : sans). `.title`, `.subtitle` (coupé avant le [×] et un
  bouton-icône), `.contentTop` (sous l'en-tête), `.pad` (20), `.innerWidth`.
  `:AddFooterButton(texte, clic, style, côté)` : `right` (de droite à gauche,
  action principale), `left` (secondaires), `center` ; hauteur 28, largeur au
  libellé.
- `Theme.CreatePageHeader(parent, w, { compact = true })` : l'en-tête compact
  seul (le grand reste celui des réglages).
- `Theme.CreateListRow(parent, w, h, { status, icon, detail, kind })` : carte
  ROW / ROW_ALT (`:SetIndex(rang)`), losange ou icône à gauche, `.text`,
  `.detail` aligné à droite, `.control` à droite. Pas de 24 (carte 22) pour
  une ligne simple, 38 (carte 36) pour deux lignes avec boutons.
- `Theme.SetStatus(losange, état)` : `ok` vert et `info` bleu au trait, `warn`
  ambre et `bad` rouge pleins, `off` gris au trait, `item` ambre au trait,
  `none` masqué.
- `Theme.CreateToast(parent, w, h, { strata, accent })` : bandeau, fond
  WINDOW 94 %, filet EDGE, liseré de 3 à gauche (`:SetAccent(couleur)`, ambre
  par défaut, couleur de statut pour une alerte, `false` sans) ; souris coupée
  hors du mode déplacement. `Theme.SkinToast(cadre, { outset })` habille un
  cadre existant, le fond débordant autour du contenu.
- `Theme.CreateIconButton(parent, taille, texture, clic, infobulle)` : carré
  au trait comme [×], icône estompée au repos.
- `Theme.CreateButton(parent, nil | "auto", …)` : largeur au libellé
  (`Theme.ButtonWidth`, 16 de chaque côté, 72 au moins).
- Infobulles du jeu : `Theme.TooltipTitle` (ambre), `TooltipLine` (texte),
  `TooltipHint` (MUTED clair), `TooltipPair` (libellé / valeur PARCHMENT).

| Fenêtre / cadre          | Brique         | En bref |
|--------------------------|----------------|---------|
| Avant le départ          | dialogue 480   | « Parti de … » en sous-titre, flèche à gauche du [×] ; bloc note (chiffre `F_DISPLAY`, tampon du verdict teinté, barre ambre) ; section Préparation, cartes à losange, détail à droite ; Conseils dans un bloc à liseré ambre ; pied : « Partir à l'aventure » bleu centré |
| Avant le donjon          | dialogue 420   | niveau en carte, sections (quêtes, plans, préparation), cartes à losange, « Fermer » en accent |
| Retour d'expédition      | dialogue 420   | durée `F_DISPLAY` dans un bloc, cartes nom / valeur, objets notables sous le compte du butin |
| Après la mort            | dialogue 400   | corps, guérisseur, verdict en cartes ; note et règle en texte pâle sur deux lignes |
| Place au butin           | dialogue 480   | butin bloqué dans une carte à liseré ambre ; cartes icône, nom, prix, « Jeter » (plein) / « Ignorer » ; aide dans le pied ; hauteur au nombre de lignes |
| Rangs de sorts           | dialogue 520   | cartes icône, sort, case ; « Mettre à jour » (accent) / « Ignorer » ; « Tout mettre à jour » plein dans le pied |
| Sac plein                | bandeau 380    | liseré orange, suggestion, « Jeter » plein, « Autre », « Garder toujours » |
| Kit de camp              | bandeau 230    | décompte centré |
| Résumé de stuff          | `SkinToast`    | même mise en page (titre espacé, filet, une ligne), fond autour, suit le libellé |
| Stats du portrait        | bandeau 206    | liseré à la couleur de la classe, classe et niveau d'objet, filet, valeurs à droite |
| Mode déplacement         | bandeau 460    | titre et aide à gauche, « Terminer le déplacement » plein à droite |
| Icône d'annonce          | tuile 40       | fond WINDOW, filet EDGE, barre basse à la couleur du rapport, halo inchangé |
| Bonne récompense         | —              | filet ambre 1 px et fond ambre à 12 %, étiquette `F_LABEL` ambre |
| Page Échap > AddOns      | grand en-tête  | nom en `F_DISPLAY`, version, filet ; bouton en accent |

Aperçus : `python3 tests/snapshot.py r2q-check|r2q-dungeon|… <sortie.html>`
(une scène par fenêtre, `list` les donne toutes). Les infobulles du jeu y
sont dessinées à l'approche (`Snap.Tooltip`, police du jeu).

## Règles

- Aucune couleur, police ou taille en dur dans un module : jetons et briques
  du socle.
- Les briques acceptent les clients sans `SetFont` réussi, sans
  `SetGradient`, etc. (repli silencieux).
- Une fenêtre se reconstruit avec les briques ; les modules déclarent toujours
  leurs pages avec `ns.AddOptionPage` (rien à réécrire côté module).
