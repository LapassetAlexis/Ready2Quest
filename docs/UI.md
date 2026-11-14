# Interface : système de design (refonte 2026-11)

État décrit : socle 2.11.0, Ready2Quest 1.32.0, QuestCompanion 2.11.0 (et,
pour la section « Composants 3.0 », socle 3.0 et QuestCompanion 3.0.0). Cette
page dit ce que fait le code aujourd'hui ; l'historique des versions est dans
`docs/TECHNIQUE.md` et les CHANGELOG.

Référence de style commune à Ready2Quest et QuestCompanion. Tout passe par le
socle (`Ready2Quest/Libs/Socle/Theme.lua`, recopié dans QuestCompanion par
`tools/sync_socle.py`, jamais modifié dans la copie) : une fenêtre ne fabrique
jamais ses propres couleurs, polices ou contrôles.

Socle chargé une fois : quand les deux addons sont installés avec un socle de
même empreinte (`SOCLE_ID`, écrite par `sync_socle.py`), le second réutilise
les fabriques compilées du premier (`ns.SocleFile`) avec son propre `ns` :
`Theme`, chaînes, polices et cadres restent propres à chaque addon ; seules
les données en lecture seule (lieux, donjons) sont partagées (`ns.SocleData`).
`ns.Shared` coordonne les deux addons (ex. le sujet « aggro » : quand la marque
d'aggro de Ready2Quest est active, l'alerte du compagnon se tait). `/r2q diag`
et `/qc diag` disent « Socle : partagé » ou « propre ».

Inspiration : les addons « premium » récents (fenêtre large, navigation à
gauche, en-tête à grand titre, réglages en cartes sur deux colonnes). On garde
notre identité : l'ambre (accent), le bleu de nuit (information, départ), et
les médaillons des deux logos (l'écu coché au « ! » des quêtes, l'empreinte).

## Police

**Inter** (licence OFL, `Libs/Socle/Media/Inter-*.ttf`, réduite aux caractères
latins). Trois graisses : Regular, SemiBold, Bold. Le style Azeroth de
QuestCompanion pose en plus Friz Quadrata, la police du client
(`ns.AZEROTH_FONT`), sur ses bandeaux, plaques et titres.

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
| `F_NUMBER`      | Bold     | 12     | chiffres posés sur une icône, compteurs |

`Theme.ARROW` : vraie flèche « → » si Inter est chargée, « -> » avec la police
de repli du jeu (elle n'a pas le glyphe).

Aucun texte sombre avec l'ombre noire de la police (illisible) ; texte clair
sur fond coloré plein.

## Palette

Les jetons existants restent (`GOLD` = ambre #e8a54b, `BLUE` #5b8fd6,
`PARCHMENT`, `TEXT`, `MUTED` #91969e, `GREEN`, `RED`, `ORANGE_DEEP`). Ajouts :

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
| `MUTED_LIGHT`  | #a3a8ad  | « MUTED clair » : sous-titres, sections, détails |
| `GOLD_LIGHT`   | #f6c77d  | ambre clair : cœur du filet lumineux, brillantes |
| `CONTROL`      | #2a3036  | piste, bouton au repos                    |
| `WHITE`        | #ffffff  | texte sur bandeau, remise à blanc         |

Codes de texte pour les chaînes colorées (chat, infobulles) : `ns.TC.GOLD`,
`PARCHMENT`, `GREY`, `GREEN`, `RED`, `ORANGE`, `ORANGE_DEEP`, `WHITE`, `BLUE`,
déclarés une seule fois dans `Libs/Socle/Base.lua` (premier fichier du socle :
`Strings.lua`, `Locales.lua` et les messages de démarrage s'en servent) ;
`Theme.T_*` en sont des alias. `Theme.Hex(couleur)` donne le code d'un jeton.
Plus aucun `|cff…` écrit à la main dans les fichiers nettoyés
(`tests/modules/socle.lua` le vérifie).

**Rareté** : un seul jeton, `Theme.RANK` (trivial gris, normal PARCHMENT,
élite #669ef2, rare #bf80ff, boss #ff8000, brillante GOLD_LIGHT : la
convention des qualités d'objet du jeu, éclaircie pour du texte, ≥ 4,5:1 sur
tous les fonds sombres). `Theme.RankKey(classification)` et
`Theme.RankColor(classification, brillante)` ; sur parchemin, le style Azeroth
choisit par la même clé ses encres sombres (`rElite`, `rRare`…).

**Contraste** : `Theme.Luminance`, `Theme.Contrast(a, b)` (WCAG 2.x) et
`Theme.Over(fond, couleur, alpha)` (couleur vue sous un voile) sont dans le
socle ; les tests s'en servent pour mesurer chaque couple texte / fond.

**États** : survol = voile blanc à `Theme.HOVER_ALPHA` (6 %) ; inactif =
`DIM_ALPHA` (45 % : carte ou page d'un module coupé, avec « Rallumer » en tête
de page ; plus les boutons depuis la 3.0, voir « Composants 3.0 ») ; bouton plein enfoncé = encre mêlée au fond à
`PRESS_SHADE` (10 %), libellé décalé de 1, -1.

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

- Réglages : environ 980 × 680. Navigation 220 de large. (Le carnet de
  QuestCompanion a la même taille en Sobre ; en Azeroth, voir plus bas.)
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
  - liste déroulante : case FIELD bordée EDGE, texte + chevron ; une seule liste
    ouverte à la fois (en ouvrir une referme l'autre, `Theme.openDropdown`) ;
  - case à cocher : celle du client (atlas `checkbox-minimal`, coche
    `checkmark-minimal`, repli sur le fichier du client
    `Interface\Buttons\UI-CheckBox-Check`, partiel `common-checkbox-partial`,
    18 px) si le client les connaît, sinon l'interrupteur dessiné ;
  - nuancier : carré 15 bordé ;
  - roue crantée (`Theme.CreateGearButton`) : la roue grise du journal de
    quêtes du client (atlas `questlog-icon-setting`, puis `gm-icon-settings`,
    sinon `UI-OptionsButton` désaturé), sans cadre, grise au repos
    (`Theme.GEAR.rest`), plus claire au survol ; ouvre les réglages ;
  - recherche (`Theme.CreateSearchBox`) : champ FIELD, texte indicatif MUTED,
    Échap et Entrée rendent le clavier ;
  - verrou : case en pointillés « 30 brillantes » pour ce qui n'est pas gagné.
- Pictos du client, par référence : `Theme.CLIENT_ART` donne pour chaque rôle
  (`diamond`, `diamondLine`, `chevron`, `gear`, `checkbox`, `checkmark`,
  `partial`) une liste d'atlas vérifiés en jeu et un fichier de repli ;
  `Theme.PaintClient(texture, rôle)` pose le premier atlas que le client
  connaît (`C_Texture.GetAtlasInfo`, réponse gardée), sinon le repli
  (`tex.clientSource` dit lequel). `Theme.SetDiamond` passe par là.
- Pied : fond NAV, filet au-dessus ; boutons secondaires en contour (EDGE,
  texte clair) à gauche, bouton principal en contour ambre (texte ambre, fond
  ambre à 7 %) à droite.
- Boutons (`Theme.BUTTON_STYLES`) : `outline` (= `normal`, au trait EDGE,
  ambre au survol), `accent` (contour ambre, fond ambre à 7 %), `primary`
  (plein ambre, encre sombre), `adventure` (plein bleu, encre sombre : le blanc
  ne tenait que 3,31:1 ; l'encre tient 5,67 au repos, 6,69 au survol). Les
  boutons pleins n'ont PAS l'ombre de la police. Désactivé (socle 3.0) :
  `Theme.DISABLED` opaque (fond CONTROL pour un bouton plein, filet EDGE_SOFT,
  texte MUTED, 4,50:1), sans survol ; plus d'estompe `DIM_ALPHA`.
- Fenêtres : `Theme.CreateWindow` inscrit le nom de la fenêtre dans
  `UISpecialFrames` (`Theme.RegisterEscapeClose`) : une fenêtre sans nom ne se
  ferme pas à Échap.
- Animations sans `OnUpdate` Lua (AnimationGroup du client) :
  `Theme.FadeIn` / `Theme.FadeOut` (une disparition en cours est
  interrompue par une apparition), `Theme.Pulse` / `Theme.PulseOn` (aller-retour
  d'alpha et d'échelle) ; demi-périodes nommées dans `Theme.PULSE` (`alert`,
  `shiny`, `net`, `arrival`, `talk`, `notice`). Sans l'API, l'effet reste
  statique.

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
- Autres briques : `Theme.CreateDropdown(parent, w, onSelect, { listWidth,
  maxRows })` (10 lignes visibles par défaut, le reste à la molette),
  `CreateNavItem` (`:SetBadge(texte)`), `CreateIcon(parent, taille, texture,
  qualité)`, `CreateDiamond`, `CreateBar`, `CreateSection`.

| Fenêtre / cadre          | Brique         | En bref |
|--------------------------|----------------|---------|
| Avant le départ          | dialogue 480   | « Parti de … » en sous-titre, flèche à gauche du [×] ; bloc note (chiffre `F_DISPLAY`, tampon du verdict teinté, barre ambre) ; section Préparation, cartes à losange, détail à droite : les manques d'abord, puis, dès 4 points en ordre, une ligne « N points en ordre · Afficher » qui les déplie (en retrait, MUTED clair) ; durabilité et réparation en une ligne si toutes deux OK ; Conseils dans un bloc à liseré ambre ; pied : « Partir à l'aventure » bleu centré |
| Avant le donjon          | dialogue 420   | niveau en carte, sections (quêtes, plans, préparation), cartes à losange, « Fermer » en accent |
| Retour d'expédition      | dialogue 420   | durée `F_DISPLAY` dans un bloc, cartes nom / valeur, objets notables sous le compte du butin |
| Après la mort            | dialogue 400   | corps, guérisseur, verdict en cartes ; note et règle en texte pâle sur deux lignes |
| Place au butin           | dialogue 480   | butin bloqué dans une carte à liseré ambre ; cartes icône, nom, prix, « Jeter » (plein) / « Ignorer » ; aide dans le pied ; hauteur au nombre de lignes |
| Rangs de sorts           | dialogue 520   | cartes icône, sort, case ; « Mettre à jour » (accent) / « Ignorer » ; « Tout mettre à jour » plein dans le pied |
| Sac plein                | bandeau 380    | liseré orange, suggestion, « Jeter » plein, « Autre », « Garder toujours » |
| Kit de camp              | bandeau 300 × 28 | décompte centré ; s'élargit au texte jusqu'à 440 (1.35.0) |
| Résumé de stuff          | `SkinToast`    | même mise en page (titre espacé, filet, une ligne), fond autour, suit le libellé |
| Stats du portrait        | bandeau 206    | liseré à la couleur de la classe, classe et niveau d'objet, filet, valeurs à droite |
| Mode déplacement         | bandeau 460    | titre et aide à gauche, « Terminer le déplacement » plein à droite |
| Icône d'annonce          | tuile 40       | fond WINDOW, filet EDGE, barre basse à la couleur du rapport, halo inchangé |
| Bonne récompense         | —              | filet ambre 1 px et fond ambre à 12 %, étiquette `F_LABEL` ambre |
| Page Échap > AddOns      | grand en-tête  | nom en `F_DISPLAY`, version, filet ; bouton en accent |

Aperçus : `python3 tests/snapshot.py <scène> <sortie.html>` (`list` les donne
toutes) : `r2q-check`, `r2q-dungeon`, `r2q-expedition`, `r2q-death`,
`r2q-lootroom`, `r2q-spellranks`, `r2q-bagspace`, `r2q-camp`, `r2q-gear-toast`,
`r2q-portrait`, `r2q-pace`, `r2q-reward`, `r2q-notice`, `r2q-exit-alert`,
`r2q-edit-banner`, `r2q-minimap-tooltip`, `r2q-options`, `r2q-options-nav`,
`r2q-options-bags`, `r2q-options-spellranks`, `r2q-settings-canvas`. Les infobulles du jeu y
sont dessinées à l'approche (`Snap.Tooltip`, police du jeu).

## Carnet et compagnon (QuestCompanion)

Même langage, briques du lot 4 dans le socle :

- `Theme.CreateChips(parent, { { id, label } }, onSelect)` : puces de filtre
  au trait (F_BODY), la choisie en ambre (filet, texte, fond à 12 %).
  `:Select(id, silent)`, `.byId[id]` (`.text`, `.selected`), `.used`.
- `Theme.CreateTile(parent, w, h, { accent = "left" | "top" | false })` :
  carte de grille, fond ROW, filet EDGE_SOFT (EDGE au survol, ambre si
  `:SetSelected(true)`), liseré de 3 `:SetAccent(couleur)`, `:SetFill(c)` ;
  survol du module par `tile.onEnter` / `tile.onLeave`.
- `Theme.CreateTag(parent, texte, couleur)` : étiquette F_CAPS en capitales,
  fond teinté à 16 % (rang d'une créature, sorte d'objet).
- `Theme.CreatePager(parent, onStep)` : « 1-12 / 40 » et deux chevrons au
  trait ; `:Update(décalage, page, total, max)`.
- `Theme.CreateBubble(parent, w)` : bulle de parole, fond WINDOW, filet
  EDGE, filet ambre en haut, pointe en losange ; `:SetText(texte, extra)`
  lui donne la hauteur du texte (+ `extra` pour des boutons).
- `Theme.TextHeight(texte, largeur, rôle)` : hauteur mesurée par le client,
  sinon estimée ; sert à empiler des blocs de texte sans recouvrement.
- `CreateTabs` : `:SetDim(id, on)` estompe un onglet ; onglets et entrées de
  navigation ont `.text` comme les boutons. `CreateLockTag:SetText(t, max)`
  coupe un verrou trop long.
- Retirés : `CreatePanel`, `CreateDivider`. `CreateDiscreet` reste le support
  du cadre du compagnon (ses cadres et fonds gagnés en repeignent le filet et
  le fond).

| Fenêtre / cadre          | Brique              | En bref |
|--------------------------|---------------------|---------|
| Carnet de voyage         | fenêtre 980 × 680   | navigation 220 : marque, groupe « Carnet », neuf entrées (Compagnon, Créatures, Réserve, Échoppe du dresseur, Hauts faits, Missions, Exploration, Juke-box, Guide), pastille bleue sur Missions (missions ouvertes du jour et de la semaine) ; dessous, le **tableau de bord** : compagnon (nom, humeur, quatre envies en barres fines), zone où l'on est (%), missions du jour et de la semaine en losanges (pleins = faites), chaque bloc mène à sa page ; points de hauts faits en bas. Grand en-tête (titre et phrase fixe `JRN_SUB_<page>`), roue crantée à gauche du [×]. Pied : garde-manger à gauche, « Ma fiche de dresseur » et « Fermer » (accent) à droite. Filtres de Créatures et d'Exploration gardés au /reload (`QuestCompanionDB.journalState`, la recherche tapée exceptée) |
| › Compagnon              | cartes              | héros (portrait dans son cadre et son fond gagnés, nom, caractère, étapes en losanges, dernière bulle) ; cinq chiffres en plaques (chiffre et libellé centrés) ; envies en barres fines ; « Ses effets » ; allure : apparences, cadres, fonds, ornements (verrou en pointillés tant que pas gagné) ; changer de compagnon demande confirmation (dialogue 420) |
| › Créatures              | liste + fiche       | rangée 1 : zone, rareté, tri (listes déroulantes), compte ; rangée 2 : puces d'état (Toutes, Capturées, À capturer, À abattre, Brillantes) et recherche (appliquée à la fin de la frappe) ; rangée 3 : boutons de type et « Tous » ; liste façon Pokédex (numéro, icône, nom à la couleur de sa rareté, type, étoiles dorées du client cernées de brun, liseré vert si capturée) ; fiche à droite (modèle 3D, « Localiser ») ; bandeau des sceaux sous la liste ; pagination |
| › Hauts faits            | liste paginée       | en haut : points (compte et personnage), nombre obtenu, filtres Tous / Obtenus / En cours ; à gauche « Toutes » puis les catégories ; à droite : icône, nom, marque Compte / Perso, description, barre, points, récompense, date |
| › Missions               | bande + cartes      | bande résumé de trois plaques (compagnon, jour, semaine) ; missions en cartes sur deux colonnes (icône de la sorte prise au client, titre, zone, barre, compte, gains) ; faite : voile vert et tampon « Faite » ; ↻ « Changer » une fois par jour ; bonus des 3 en encart pointillé ; à droite : auberges (7 tampons), garde-manger, besace de capture. Teintes Sobre : `ns.MISSION_COLORS` (jetons du thème) ; Azeroth : `ns.AZEROTH_MISSION` |
| › Exploration            | colonne + carte     | à gauche, filtre des zones (Pour moi, Commencées, Toutes) et recherche « Zone… », puis les zones (nom, « ici », %, filet doré à 100 %, jamais visitées estompées), pagination ; à droite, carte de la zone (grand %, niveaux, « Suivre à l'écran », barre, paliers et leurs gains, « Ouvrir le coffre »), trois cartes de part (Lieux, Métiers, Quêtes) qui choisissent la liste du dessous ; une quête choisie a son bouton « Localiser » ; ligne du sceau et bouton « Créatures » |
| › Guide                  | sommaire + texte    | sommaire en tuiles à gauche, « Revoir le tutoriel » en bas ; texte de la section par blocs, paginé ; chiffres lus dans les constantes des modules |
| Fiche de dresseur        | fenêtre 780 × 580   | au-dessus du carnet ; compagnon en 3D, vitrine de trois créatures, chiffres, sceaux, barres de hauts faits par catégorie |
| Coffre de zone           | dialogue 480        | tuiles sur deux colonnes (sorte en étiquette, nom), hauteur au nombre d'objets, « Plus tard » dans le pied |
| Scène de capture         | bandeau 340 × 386 (Azeroth 360 × 504) | modèle de la créature, étoiles, filet lancé, verdict ; créature échappée grisée sous le filet déchiré ; Échap la ferme |
| Capture possible         | bandeau 384 × 102 (Azeroth 388 × 126) | icône, nom, étoiles, aide ; reste affiché tant que la souris est dessus |
| Liste de capture         | bandeau 300         | six lignes de 24 |
| Tout capturer            | bandeau (340 au moins) | tuiles des créatures (modèle 3D, nom, étoiles) ; choix du filet : bandeau 248 |
| Résultat de capture      | bandeau 300 × 66    | verdict |
| Haut fait obtenu         | bandeau 280 × 50    | losange ambre, titre, nom ; regroupe plusieurs hauts faits |
| Haut fait de guilde      | bandeau 340 × 84    | icône, membre, haut fait, créature à la couleur `Theme.RANK` |
| Compagnon à l'écran      | cadre discret       | cadre et fond gagnés ; plaque du nom (F_LABEL) et de l'humeur (MUTED clair, sur bande sombre) ; modèle estompé en combat |
| Bulle, tutoriel          | bulle 220           | « Passer » au trait, « Suivant » plein, sous le texte |
| Fiche au survol          | bandeau 220         | nom F_TITLE, stade et humeur, envies en barres fines avec valeur, filet, aide pâle ; hauteur au contenu |
| Garde-manger (Maj+clic)  | bandeau             | titre en capitales, cases 34 au filet EDGE (ambre au survol), infobulle du thème |
| Bloc « Carnet »          | 280 de large        | quatre objectifs au plus : le premier en carte (liseré ambre, barre), les suivants en lignes fines sur voile sombre ; titre : clic = replier, glisser = déplacer ; clic sur une ligne : sa page ; clic droit : masquer ; caché en combat par défaut |

**Modèles 3D** : un seul cadrage, `ns.ShowModel` (charge le `display`
d'abord, sinon le `npc` ; ne recharge pas un modèle déjà affiché ; repose la
caméra à chaque `OnModelLoaded` / `OnShow` ; 3.0.0 bêta 6 : un modèle resté
vide, sans `OnModelLoaded` et `GetDisplayInfo` à 0, comme une créature pas
encore dans le cache du client, est rechargé une fois, après
`ns.MODEL_RETRY_DELAY` ou au rafraîchissement suivant, `ns.ModelEmpty`) avec des profils nommés
(`ns.MODEL_PROFILES` : `companion`, `portrait`, `stage`, `prompt`, `preview`,
`cell`, `card`, `cardTile`). Le zoom « portrait » est réservé aux mascottes
vérifiées. Faute de modèle : portrait 2D par displayID appris, sinon l'icône
du type de créature.

**Images de la capture** : rayons, halo, étincelles, étoiles, bannière,
vignette et icône du filet viennent du client (`ns.CAPTURE_CLIENT_ART`,
atlas vérifiés en jeu), sans repli à nous depuis la 2.12.1 (atlas absent :
texture vide ; icône du filet : `INV_Misc_Net_01`, puis `Spell_Nature_Web`) ;
le filet, ses cordes et le paquet restent les nôtres (pas d'équivalent dans le
client). Étoiles du chat : balises `|A:auctionhouse-icon-favorite:…|a` (pleine)
et `|A:auctionhouse-icon-favorite-off:…|a` (vide). Images embarquées : le filet
(`filet`, `corde`, `paquet`) et les logos seulement, un test le garde. Une seule
alerte rouge à l'écran : avec Ready2Quest, sa marque d'aggro ; le compagnon
ne clignote pas en même temps.

Aperçus : `qc-journal-creature|menagerie|day|day-azeroth|progress|guide`,
`qc-capture`, `qc-capture-shake|ok|fail`, `qc-capture-toast`, `qc-companion`,
`qc-companion-hover`, `qc-tutorial`, `qc-pantry`, `qc-chest`, `qc-notify`,
`qc-tracker`, `qc-tooltip`, `qc-options-companion`, `qc-options-ornaments`.
Pas encore d'aperçu des Hauts faits, d'Exploration en Azeroth ni de la fiche
de dresseur.

## Composants 3.0 (QuestCompanion 3.0.0, socle 3.0)

Passe d'harmonisation après la bêta 4 de la 3.0 (retours : rangée du haut de
la Réserve dépareillée, « Mettre au Codex » et « Échanger avec ma cible »
illisibles, solde de paillettes peu visible, « Acheter » muet au clic).

### Inventaire (avant)

| Brique | Variantes trouvées | Décision |
|---|---|---|
| `Theme.CreateButton` (60 appels dans QC) | hauteurs 18, 20, 22, 24, 26, 28, `PAGER_HEIGHT` (22), `PAGER_HEIGHT + 2`, `DIALOG_BUTTON_HEIGHT` (28), `ITEM_H - 4`, `M.row` (22), `actionH` (22) | trois tailles nommées `xs` 18, `sm` 24, `md` 28 (`Theme.BUTTON_SIZES`, `height` accepte le nom) ; reste en nombre : le bouton posé sur une ligne d'Exploration (hauteur de la ligne − 4) et les boutons des bandeaux de capture (géométrie `ns.CAPTURE_PREP`) |
| Désactivé (Sobre) | bouton entier à `DIM_ALPHA` 45 %, texte MUTED : libellé vu à 2,18:1 | `Theme.DISABLED` opaque : fond CONTROL (plein) ou transparent (au trait), filet EDGE_SOFT, texte MUTED |
| Désactivé (Azeroth, carnet) | aucun : `Theme.ButtonRest` repeignait l'encre sombre du bouton plein sur le rouge (`Mettre au Codex`, 1,22 à 2,11:1), ou du gris estompé sur rouge estompé (`Acheter`, environ 1:1) | peintre unique `ns.AzerothButtonState` (`button.skinPaint`) : bois délavé `AZEROTH_BUTTONS.off`, libellé `buttonOff` |
| `ns:AzerothButton` (capture, visite) | `Disable()` sans effet visible | mêmes états que le carnet (survol, appui, désactivé) |
| `Theme.CreateChips` | 24 de haut, F_BODY ; décalé de 1 px à côté des listes | inchangé, hauteur = `Theme.CONTROL_HEIGHT` |
| `Theme.CreateDropdown` | 22 de haut | `Theme.CONTROL_HEIGHT` (24) par défaut, `opts.height` sinon |
| `Theme.CreateSearchBox` | 24 | `Theme.CONTROL_HEIGHT` |
| Solde de paillettes | texte F_LABEL ambre « ◆ 40 paillettes » | pastille `Theme.CreateCurrency` |
| Intertitres | `Theme.CreateSection` (pages, fiche) ; texte F_LABEL ambre (historique des Échanges) | `Theme.CreateSection` partout (l'historique y passe) ; les en-têtes de colonne de la fenêtre d'échange restent des libellés (« Toi » / nom) |
| Étiquettes | `Theme.CreateTag` (caractère, taille, rang) ; pavé de taille sur vignette (fond NAV, F_SMALL) | inchangées : le pavé sur portrait garde son fond opaque (lisible sur n'importe quel portrait) |
| Texte vide | F_BODY MUTED clair, retour à la ligne | règle commune (Réserve, cadeau, Échanges, Créatures) |
| Onglets (colonne) | `Theme.CreateNavItem` | inchangé ; l'Échoppe y gagne son entrée |

### Composants canoniques

| Composant | Brique | Taille | États |
|---|---|---|---|
| Bouton principal | `CreateButton(…, "primary")` ; Azeroth : rouge | `sm` dans une page, `md` au pied et dans un dialogue, `xs` dans un bandeau compact | repos, survol (ambre clair / voile doré ADD), appui (libellé 1, −1 ; fond assombri / voile sombre `pressAlpha`), désactivé |
| Bouton secondaire | `"outline"` (= `"normal"`) ; Azeroth : brun | idem | idem |
| Bouton d'accent | `"accent"` ; Azeroth : rouge | idem | idem |
| Bouton « aventure » | `"adventure"` (Ready2Quest) | idem | idem |
| Inactif | `button:SetInactive(on, raison)` | — | aspect désactivé, infobulle de la raison, **clic gardé** : le module explique (plus employé par l'Échoppe depuis la bêta 6 : `SetEnabled(false)` + `disabledTip`) |
| Bouton-icône | `Theme.CreateIconButton` | 24 | gris désaturé au repos, ambre au survol ; appui (icône 1, −1, filet ambre sombre) et désactivé (filet EDGE_SOFT, icône à 30 %, sans survol) depuis le socle 3.1 |
| Fermer, roue crantée | `Theme.CreateCloseButton`, `CreateGearButton` | 22-24 | survol ; appui (contenu 1, −1 ; filet ambre sombre pour [×]) depuis le socle 3.1 (`Theme.PressFeedback`) |
| Onglet | `Theme.CreateNavItem` | 28 (Sobre), 29 au pas de 31 (Azeroth) | survol, choisi, pastille |
| Puces (vue, filtre) | `Theme.CreateChips` | `CONTROL_HEIGHT` 24, F_BODY | au repos, survol, choisie (ambre ; Azeroth : surbrillance des catégories) |
| Liste déroulante | `Theme.CreateDropdown` | `CONTROL_HEIGHT` 24 | — |
| Recherche | `Theme.CreateSearchBox` | `CONTROL_HEIGHT` 24 | — |
| Pastille de monnaie | `Theme.CreateCurrency(parent, { icon, label, tip })` | `CONTROL_HEIGHT` 24, largeur au contenu | `:SetValue(n)`, `:Flash()` (secousse de 4 translations de 0,05 s et voile rouge en fondu 0,45 s, AnimationGroup créés une fois) ; Azeroth : aplat `fieldBg`, liseré brun, rôles `currency.value` / `currency.label` |
| Intertitre | `Theme.CreateSection` | 20 | Azeroth : rôle `section.label` |
| Étiquette | `Theme.CreateTag` | 15 | — |
| Texte vide | `Text(F_BODY, MUTED_LIGHT)` | — | Azeroth : rôle de la page (`reserve.text`…) |

Une rangée d'outils (puces, listes, recherche, bouton `sm`, pastille) a une
seule hauteur, `Theme.CONTROL_HEIGHT`, et les éléments s'y calent par le haut.

### Écrans

- Réserve : rangée du haut « Réserve | Échanges », pastille du solde à
  droite ; deuxième rangée : tri et espèce (24) alignés sur « Tous |
  Brillants » ; les boutons de la fiche en `sm`. « Échanger avec ma cible »
  (`sm`, au trait) en bas à gauche, sur la ligne de la pagination (centré
  sur elle), sous la grille ; l'aide de la page à sa droite (deux lignes au
  plus, jusqu'au bord de la grille). Rien ne se chevauche (grille,
  pagination, fiche, aide : `tests/modules/ui_windows.lua`, deux styles).
- **Échoppe du dresseur** : onglet à part (`ns.JOURNAL_PANES.shop`,
  `frame.shopPane`), juste après la Réserve, avec son étape dans la visite du
  carnet (`TOUR_B_shop`). Un article hors de portée (prix au-dessus du
  solde, besace pleine, déjà obtenu, capture coupée) a « Acheter » désactivé
  (état désactivé du socle, `button:SetEnabled(false)`), la raison en
  infobulle : « Il te manque 10 paillettes », « Ta besace est pleine »,
  « Déjà obtenu » (`ns:ShopDisabledTip`). Les boutons suivent le solde page
  ouverte (achat, relâche, tout gain : rappel `PAILLETTES`,
  `MenagerieView.lua`). (Bêta 5 : cliquable à l'aspect désactivé, la raison
  dans le chat ; jugé trop discret.)
  `ns:OpenReserve("shop")` mène à l'onglet (`ns:OpenShop`).
- Échanges : même pastille (celle de la page Réserve) ; intertitre de
  l'historique en `Theme.CreateSection` ; boutons en `sm`.
- Ailleurs : boutons du carnet (Compagnon, Créatures, Missions, Exploration,
  Guide, Juke-box), de la fiche de dresseur, du menu du compagnon, de la
  capture (carte, liste, bandeau, choix), des raccourcis et de la visite
  guidée passés aux tailles nommées.

### Contrastes mesurés

| Couple | Rapport |
|---|---|
| Sobre, désactivé : MUTED sur CONTROL (bouton plein) | 4,50:1 |
| Sobre, désactivé : MUTED sur la fenêtre (bouton au trait) | 6,09:1 |
| Azeroth, désactivé : `buttonOff` sur le haut du dégradé `off` (le plus clair) | 4,84:1 (`button.off`) |
| Azeroth, actif : `goldText` sur le haut du rouge / du brun | 6,39:1 / 11,29:1 |
| Pastille Sobre : chiffre GOLD / libellé MUTED clair sur FIELD | 8,79:1 / 7,75:1 |
| Pastille Azeroth : `goldText` / `lightSoft` sur `fieldBg` | 13,18:1 / 12,18:1 |

### Performances

Tout est construit une fois : les lignes de l'Échoppe, les deux pastilles et
leurs animations (secousse, fondu) naissent avec le carnet ; un
rafraîchissement ne crée aucun cadre (`tests/modules/ui_windows.lua`) ;
le peintre d'états ne crée rien (voiles de survol et d'appui créés à
l'habillage) ; pas d'`OnUpdate`.

## Passe de cohérence 3.1.0 (QuestCompanion, socle 3.1)

Relecture de toutes les fenêtres, bandeaux et infobulles du compagnon
(hors capture, en réécriture à part) : états des contrôles, Échap, combat,
textes bornés. Tests : `ui_bricks.lua` (« [UI31] »), `banners.lua` (§ 7),
`qc2_guilde.lua`.

### Corrigé

| Écart | Avant | Après |
|---|---|---|
| Appui des petits boutons du socle | [×], bouton-icône et roue crantée sans état « enfoncé » (seuls les `CreateButton` l'avaient) | `Theme.PressFeedback` : contenu décalé de 1, −1, filet ambre sombre ; relâché : survol ou repos ; ancres d'origine remises telles quelles |
| Bouton-icône désactivé | `Disable()` sans effet visible, survol ambre quand même | filet `DISABLED.edge`, icône à 30 %, pas de survol ni d'appui, infobulle gardée |
| Infobulles écrites à la main | `AddLine` avec couleurs recopiées (progression en blanc pur, aide du clic en MUTED) dans le suivi « Carnet », la ligne « fiche de dresseur » et la ligne du bestiaire | `Theme.TooltipTitle` / `TooltipLine` / `TooltipHint` (progression PARCHMENT, aide MUTED clair) ; un test interdit `:AddLine(` dans ces fichiers |
| Commandes cliquables muettes au survol | étoile et « + » du Juke-box, blocs du tableau de bord du carnet, lignes du bloc « Carnet » : seule l'infobulle disait qu'on pouvait cliquer | voile et filet de survol du thème (`Theme.CreateHover`) ; sur le parchemin Azeroth, les blocs du tableau de bord prennent l'encre du filet |
| Garde-manger (Maj+clic) | nommé mais pas à Échap, restait ouvert en combat | Échap le ferme ; fermé à l'entrée en combat (comme le menu du compagnon) |
| Fiche au survol du compagnon | s'ouvrait en combat (strate TOOLTIP, 220 px) dès que la souris passait sur le cadre estompé | ne s'ouvre pas en combat, fermée à `PLAYER_REGEN_DISABLED` ; revient au survol suivant |
| Bandeaux du carnet et de guilde | mis en file pendant le combat, mais un bandeau déjà affiché restait au haut de l'écran avec son bouton invisible qui prend la souris | effacé dès le combat ; s'il n'avait pas tenu la moitié de son temps, il revient en tête de file après (le résultat de capture s'effaçait déjà) |
| Bandeau de guilde : 4e ligne | « Clic : sa fiche de dresseur » sur chaque bandeau Sobre (et nulle part en Azeroth) | la ligne ne garde que « et N autres exploits » ; l'aide passe dans l'infobulle du bandeau, dans les deux styles |
| Textes sans largeur | libellés des envies de la fiche au survol (pouvaient passer sur la barre), titre du garde-manger, titre « Chasse » du menu, trois lignes de l'aperçu des réglages du compagnon | largeur posée, sans retour à la ligne |
| Blanc en dur | points des hauts faits sur l'écu (`SetTextColor(1, 1, 1)`) | `Theme.WHITE` |

Contraste ajouté : PARCHMENT, TEXT, MUTED clair et GOLD sur le fond
d'infobulle du jeu (≥ 4,5:1, mesuré dans `ui_bricks.lua`). Aucune autre
couleur n'a changé.

### Laissé tel quel

| Élément | Pourquoi |
|---|---|
| Panneau d'allure et confirmation « changer de compagnon » sans nom global | Échap est géré par la fenêtre (`OnKeyDown`) pour ne fermer qu'elle et pas le carnet dessous ; en combat (clavier non pris), Échap ferme le carnet, qui les ferme avec lui |
| Carnet, fiche de dresseur, coffre de zone ouverts en combat | ouverts par le joueur : ils restent (rien ne se ferme tout seul) |
| Échanges | la session se termine déjà au combat ; la page Échanges ne s'ouvre seule qu'à l'acceptation d'une invitation, impossible à lancer en combat |
| Bulles du compagnon, conseils, visite guidée, visite de Grand-père Hiver, annonces du carnet (Notify) | déjà retenues ou suspendues en combat (seules les alertes `COMBAT_PASS` : brillante, rare vivant, peur) |
| Cases du garde-manger (pied du carnet, menu) et ↻ des Missions | survol par le filet ambre, déjà documenté ; pas d'appui (cases d'icône, comme les emplacements du jeu) |
| Boutons de type des Créatures (`MenagerieView.lua`) | bascules dessinées avec repos, survol, choisi : un état « enfoncé » n'y ajouterait rien |
| Cases du garde-manger vides à 40 % | case d'icône (pas un libellé à lire), même convention que les emplacements vides du jeu |
| Fenêtres et bandeaux de la capture | hors de cette passe (réécriture en cours) ; ils profitent quand même de l'appui du [×] et des boutons-icônes du socle |

### À regarder en jeu

- Appui du [×], des boutons-icônes (rang des aides de capture, filet à
  l'écran) et de la roue : le décalage d'un pixel, et surtout que le filet
  de capture déplacé à la souris garde son icône à sa place.
- Voile de survol des lignes du bloc « Carnet » sur le monde, et des blocs
  du tableau de bord sur le parchemin (encre du filet à 10 %).
- Bandeau du carnet effacé au premier coup reçu, et revenu après le combat.

## Partager (QuestCompanion 3.1.0, `Share.lua`)

- Bouton 24 px (taille `sm`, `ns:ShareButton`) : l'icône de chat du client
  (`ns.SHARE_ICON` : atlas `communities-icon-chat`, repli
  `Interface\ChatFrame\UI-ChatIcon-Chat-Up`, par `Theme.PaintClient`),
  plaque NAV opaque, filet EDGE (Azeroth : le liseré doré des boutons), au
  survol filet ambre et voile `HOVER_ALPHA`, infobulle « Partager dans le
  chat ». Sur les bandeaux Azeroth, le libellé « Partager » à côté de
  l'icône (rôle `share.label`, `lightSoft` sur la plaque : ≥ 4,5:1), le
  bouton s'élargit à son texte. Bêta 2 : un bandeau qui porte le bouton
  reste 3 s de plus (`ns.SHARE_EXTRA`) ; sous la souris (bandeau, bouton) ou
  tant que son menu est ouvert, il ne part pas, puis garde au moins 3 s
  (`ns.SHARE_RESUME`). Créé une fois par cadre
  réutilisé (bandeau du carnet, « Capturé ! », scène de capture Azeroth,
  fiche de la Réserve) : la file des bandeaux (`Banners.lua`) ne change pas.
- Placement (`ns.SHARE_BUTTON`) : Azeroth, en bas à droite du bandeau, sous
  le bouclier ; Sobre, à droite et centré, avant les points d'un haut fait,
  les textes du bandeau raccourcis d'autant ; scène Azeroth, coin haut droit
  (hors de la plaque de titre) ; Réserve, coin haut droit du modèle de la
  fiche. Hauts faits : clic droit sur une ligne obtenue (infobulle : « Clic
  droit : partager dans le chat »).
- Menu des canaux (`ns:ShareMenu`, un cadre, `ns.SHARE_MENU` 160 de large,
  rangées de 22) : seuls les canaux disponibles (Guilde, Raid ou Groupe,
  Dire, Copier). Sobre : fond NAV, titre F_CAPS MUTED clair (7,96:1), entrées
  F_LABEL LABEL (12,77:1 au survol), voile `HOVER_ALPHA`. Azeroth : aplat `woodBg`,
  liseré doré, Friz Quadrata, rôles `share.title` (`goldHead`) et
  `share.entry` (`lightSoft`) mesurés sur le bois sous le voile de survol
  (11,08:1 et 10,22:1).
  Échap ou un clic ailleurs le referme.
- Envoi : `SendChatMessage` seulement depuis le clic d'une entrée ; « Copier »
  (`ChatEdit_InsertLink` si la saisie est ouverte, sinon
  `ChatFrame_OpenChat`, repli `ChatFrameUtil.OpenChat`) n'envoie rien.
- Annonce automatique (`ns:AnnounceCaptures`) : brillante ou 3 étoiles, une
  ligne au groupe (INSTANCE_CHAT, RAID ou PARTY ; guilde avec le second
  réglage), jamais en combat (file vidée à PLAYER_REGEN_ENABLED), une par
  canal toutes les 30 s, un lot en une ligne, pas de doublon avec le partage
  manuel ; envoi refusé : noté une fois, sans message.

## Passe de cohérence Ready2Quest 1.35.0

Même relecture sur les fenêtres, bandeaux et infobulles de Ready2Quest, avec
les briques du socle 3.1 (aucune modification du socle). Tests :
`tests/modules/r2q_ui.lua` (« [R2QUI] ») ; `death.lua`, `favorites.lua`,
`lootroom.lua` mis à jour.

Combat : une seule accroche, `ns.COMBAT_UI` (`Notice.lua`, sur son cadre
d'événements : `PLAYER_REGEN_DISABLED` en plus). Chaque bandeau s'y inscrit
(`{ id, hide, restore }`) ; `hide` le range au premier coup, `restore` le
rend à `PLAYER_REGEN_ENABLED` s'il a lieu d'être.

### Corrigé

| Écart | Avant | Après |
|---|---|---|
| Icône d'annonce (« ! », « ? ») en combat | retenue si le combat avait déjà commencé, mais déjà affichée elle restait (bouton de 40 px en haut de l'écran) | effacée au premier coup ; revient après si elle n'avait pas tenu la moitié de ses 68 s, sinon oubliée (règle du carnet) |
| Rapports ouverts seuls (icône coupée : Avant le départ, Retour d'expédition, Avant le donjon) | restaient au milieu de l'écran pendant le combat | rangés au premier coup, rendus après ; ouverts par le joueur (/r2q, flèche, clic sur l'icône) ils restent (`ns:ReportOpenedAlone`) |
| Bandeau « Sac plein » | restait en combat avec ses boutons (« Jeter » refusé en combat) ; sans nom, pas fermé par Échap | rangé au premier coup, revient si les sacs sont toujours pleins ; nommé `Ready2QuestBagSpace`, fermé par Échap (comme les sacs du jeu) |
| Résumé de stuff | apparaissait au centre à chaque changement d'arme en combat | effacé au premier coup, pas de nouveau en combat (la référence des stats suit) ; aperçu des réglages et mode déplacement inchangés |
| Lignes du check | toutes éclairées au survol, aucune cliquable (sauf le repli) | le clic fait le geste du conseil : Sacs et Objets gris ouvrent les sacs, Quêtes le journal, Rangs de sorts sa fenêtre ; l'aide du clic en dernière ligne de l'infobulle ; voile de survol seulement sur une ligne qui répond (infobulle ou clic) |
| Rangs de sorts en combat | « la mise à jour attendra la fin du combat » dans le chat, mais le clic était perdu | le clic (et « Tout mettre à jour ») est retenu et joué à la fin du combat ; message une fois |
| Après la mort : [×] et Échap | fermaient sans retenir le refus : la fenêtre revenait au changement de zone suivant | valent « Fermer » (`OnHide`) ; le rangement par l'addon (résurrection) et l'interface masquée (Alt+Z) n'en sont pas |
| Après la mort : ordre | verdict en 4e, après la note pâle des 10 % | verdict juste après les deux options, puis les deux notes pâles |
| Place au butin : objet plus cher que le butin | ligne entière à 55 % : prix à 2,68:1, « Jeter » d'aspect désactivé alors qu'il marche | ligne opaque, icône estompée, prix MUTED (5,79 sur ROW, 5,49 sur ROW_ALT) |
| Infobulles écrites à la main | `AddLine` avec couleurs recopiées : aggro (verdict, réserve en MUTED), favoris (statut, aide en MUTED), allure (ligne vide), récompense (deux lignes) | `Theme.TooltipLine` / `TooltipHint` (aides en MUTED clair) ; un test interdit `:AddLine(` dans les modules |
| Textes sans borne | « barre N, case N » (pouvait passer à la ligne sur la carte suivante), « et N autre(s) » du pied des Rangs de sorts, étiquette « Pour toi » / prix de vente sur le bouton de récompense, texte du kit de camp (« assieds-toi ou fabrique ici » dépassait les 300 px) | une ligne, largeur posée ; le bandeau du camp s'élargit au texte (300 à 440), l'icône reste collée |

Contrastes : seuls changent le prix de la ligne de butin (opaque) et les
aides d'infobulle (MUTED → MUTED clair) ; mesurés dans `r2q_ui.lua` avec les
couleurs de verdict (GREEN, RED, ORANGE_DEEP, BLUE, GOLD) sur le fond
d'infobulle (≥ 4,5:1).

### Laissé tel quel

| Élément | Pourquoi |
|---|---|
| Fenêtres ouvertes par le joueur (check à la main, Rangs de sorts, réglages, fiche ou bilan ouverts d'un clic) | elles restent en combat (règle commune) |
| Place au butin en combat | liée à la fenêtre de butin, ouverte par le joueur ; se ferme avec elle |
| Après la mort | pas de combat quand on est mort |
| Bandeau du kit de camp en combat | en haut de l'écran, souris coupée, une ligne ; son décompte tourne sur l'horloge de l'addon (passe de performance en cours, pas touché) |
| Stats au survol du portrait en combat | ne vient qu'au survol, comme une infobulle du jeu |
| Choix de la récompense de quête | la bonne est cernée d'ambre et étiquetée ; la sélectionner d'office ferait gagner un clic mais risque une récompense non voulue, et le gestionnaire du client 1.12 (`QuestRewardItem_OnClick`) lit `this` : pas vérifiable hors jeu |
| Autres lignes du check (vivres, potions, buffs, repos, durabilité, réparation, réactifs, pierre de foyer, sorts, camp, métiers) | pas de geste en un clic hors d'un marchand ou d'un entraîneur : pas de clic promis |
| « Fermer » du pied et [×] dans les dialogues | convention de la fenêtre type, gardée |
| `Dungeon.lua` | hors de cette passe (fichier tenu ailleurs) ; sa fenêtre profite quand même du rangement en combat par `ns.COMBAT_UI` |
| Couleur de repli de la classe (`1, 0.82, 0`, `Stats.lua`) | seulement quand `RAID_CLASS_COLORS` manque ; c'est l'or du jeu |
| Icône d'annonce et bandeau du camp au même point par défaut (`TOP`, −150) | ne se montrent presque jamais ensemble (départ d'une ville / feu de camp hors ville) et se déplacent ; à placer par `ns.PopupPlace` si un retour le signale |

### À regarder en jeu

- Clic sur Sacs (`OpenAllBags`, sinon `ToggleBackpack`) et Quêtes
  (`ToggleQuestLog`) sur Forever : les fonctions sont cherchées au moment du
  clic ; sans elles, la ligne n'a ni clic ni aide.
- Bandeau « Sac plein » et icône d'annonce effacés au premier coup, et revenus
  à la fin du combat ; rapport (icône coupée) rangé puis rendu.
- Rangs de sorts : « Mettre à jour » cliqué en combat, appliqué à la sortie.
- Étiquette de la récompense conseillée : une ligne calée à droite, bornée au
  bouton (largeur du bouton lue à la première marque).
- Bandeau du camp élargi pour « Buffs du feu de camp : assieds-toi ou fabrique
  ici », toujours centré.

## Thèmes du socle (socle 3.2 : QuestCompanion 3.1.0, Ready2Quest 1.35.0)

Deux thèmes, pour les deux addons : **Sobre** (ardoise et ambre, à plat : le
langage décrit plus haut, inchangé) et **Azeroth**, dit « forgé » (le défaut).
Le thème vit dans le socle (`Theme.lua`, section « Thèmes ») : aucune fenêtre
n'est habillée une à une.

Maquette validée le 2026-11-14 (référence visuelle) : profondeur (ombre
portée, bords assombris, champs en creux, boutons en relief), lumière (filets
qui s'éteignent, points lumineux, sélection en dégradé), identité (médaillon
du logo qui déborde du coin, police du jeu pour les titres), et une couleur
qui porte le sens.

### Jetons et police

| | Sobre | Azeroth |
|---|---|---|
| `EDGE` (bord, bouton en contour) | `#3a424a` | or patiné `#996b2e` |
| `EDGE_SOFT` (filets, séparations) | `#2a3138` | or sombre `#4d381f` |
| `NAV` (colonne, pied, plaque de titre) | `#0d1013` | bois sombre `#16100c` |
| `TITLE` (titres de fenêtre) | parchemin | or clair `#f6c77d` |
| `ACTIVE` (onglet, entrée, ligne choisis) | ambre | bleu arcane `#5b8fd6` |
| Police des rôles DISPLAY, TITLE, CAPS | Inter | Friz Quadrata (`Fonts\FRIZQT__.TTF`) |

`Theme.ApplySkin(id)` modifie ces jetons **sur place** (les tables gardent
leur identité) et repose la police des rôles de titre. Posé par le socle dès
`ADDON_LOADED` (`Store.lua`), avant toute fenêtre. Les encres du texte
courant ne changent pas. Une brique décide son habit à sa création
(`Theme.Forged()`) : changer de thème demande un `/reload` pour une fenêtre
déjà construite ; l'habillage de la fenêtre elle-même (`Theme.DressWindow`)
suit à l'affichage suivant.

### Matières (nos textures, `tools/gen_ui_assets.py`)

Formes, reliefs et lueurs calculés par script, écrits dans
`Libs/Socle/Media/` (TGA 32 bits, 86 Ko en tout) ; aucune illustration, rien
du jeu. `Theme.ART` :

| Clé | Fichier | Rôle |
|---|---|---|
| `frame` | `cadre.tga` 64, marge 16 | cadre d'orfèvre (en couleurs), centre vide |
| `shadow` | `ombre.tga` 64, marge 28 | ombre portée |
| `corner` | `coin.tga` 64 | coin haut gauche, retourné pour les trois autres |
| `plate` | `plaque.tga` 32, marge 8 | plaque en relief, **grise** : la teinte la multiplie |
| `inset` | `creux.tga` 32, marge 8 | creux, gris : le filet prend la teinte, le fond reste presque noir |
| `line` | `lueur_ligne.tga` 256 × 8 | filet lumineux qui s'éteint à droite (blanc, se teinte) |
| `dot` | `lueur_point.tga` 32 | point lumineux (blanc, se teinte) |
| `vignette` | `vignette.tga` 64 | bords assombris d'une fenêtre |

`Theme.Slice(frame, art, opts)` découpe une matière en 9 tranches (9
textures) : coins à leur taille, bords et centre étirés. `opts` : `layer`,
`sub`, `out` (débord), `margin`, `fill = false` (sans centre), `color`,
`alpha`, `around`. Une découpe coûte 9 textures : bien pour un bouton, un
champ, un bloc ; jamais sur chaque ligne d'une liste (un dégradé suffit).

### Fenêtres et bandeaux (`Theme.DressWindow`)

Ombre portée (débord 20), bords assombris, cadre d'orfèvre, quatre coins, et
le **médaillon du logo** (`Theme.LOGO`, 84 px) qui déborde du coin haut
gauche quand la fenêtre le demande (`opts.emblem` de `CreateWindow`,
`frame.wantsEmblem` ; `CreateDialog` le demande, la fenêtre de réglages
aussi : l'en-tête et la marque lui laissent la place). Le cadre, les coins et
le médaillon vivent sur un cadre à part, au-dessus des enfants de la fenêtre
(`Theme.CHROME.level`), sans souris. Le filet d'un pixel de Sobre s'efface.
Posé à la création et à chaque `OnShow` (et `OnSizeChanged` pour un
bandeau). Un bandeau (`Theme.SkinToast`) a l'ombre et le cadre, ni coins ni
médaillon ; si son fond déborde (`opts.outset`), l'habillage suit le fond.
Pas d'habillage : fenêtre déjà habillée par son module (`frame.azeroth`,
`frame.uiStyle == "azeroth"` : le carnet en parchemin de QuestCompanion),
`opts.chrome = false`, ou plus petite que `Theme.CHROME.min`.

### Contrôles

- **Boutons** : plaque en relief teintée (`Theme.FORGE_PLATE`), encre
  mesurée (`Theme.FORGE_INK`), par style (`Theme.FORGE_BUTTONS`). La couleur
  dit le geste : `primary` or (l'action principale du pied, encre sombre sans
  ombre), `accent` bronze, `outline` ardoise, et trois styles de sens,
  `add` (vert), `danger` (rouge), `arcane` (bleu : ouvrir, changer). En Sobre
  ces trois-là valent `outline`. Survol : la teinte s'éclaire ; appui : elle
  s'assombrit et le libellé s'enfonce d'un pixel ; désactivé : plaque sombre,
  texte lisible.
- **Petits boutons** ([×], icône, engrenage) : petite plaque, bronze au survol.
- **Case** : creux, coche or avec une lueur. **Interrupteur** : piste en
  creux, curseur en relief, bleu arcane et lumineux quand il est actif.
  **Voyant de module** : point vert lumineux ou point sombre.
- **Curseur** : piste en creux, part remplie en dégradé d'or, poignée claire.
  **Champ**, **case de valeur**, **liste** : creux ou plaque, filet bleu
  arcane au focus, chevron or.
- **Barre** : piste presque noire, remplissage en dégradé avec un reflet d'un
  pixel (pas de découpe : une barre se répète sur chaque ligne).

### Navigation, sections, cartes, listes

- Colonne : titres de groupe en « pilule » (dégradé de leur ton, or ou
  arcane), entrée choisie en dégradé arcane avec une barre claire à gauche.
- Titre de section : point lumineux, titre, filet qui s'éteint
  (`Theme.FORGE_SECTION`, tons de `Theme.FORGE_TONES`).
- Carte de réglage : relief posé sur le fond (voile clair en haut, sombre en
  bas, reflet et ombre d'un pixel : `Theme.FORGE_CARD`), sans découpe.
- Onglet choisi : dégradé arcane, souligné clair. Ligne choisie : dégradé
  arcane et barre ; losange de statut avec un halo de sa couleur.
- En-tête : plaque de bois au haut plus chaud, filet lumineux sous le titre.
  Pied : bande sombre, reflet d'un pixel (`Theme.ForgeFooter`).

### Dans les modules

Les blocs faits à la main reprennent ces matières par des jetons du module,
lus dans le thème : `ns.FORGE` et `ns.ForgeOn()` côté Ready2Quest
(`Core.lua` : bloc de la note du check, verdict en creux, conseils, cartes de
liste, étiquettes), `ns.QC_FORGE` côté QuestCompanion (filet en plaque d'or,
pastilles de capture en petites cartes, garde-manger, suivi). Un bouton prend
un style de sens par `ns.ForgeStyle(sobre, forgé…)`.

Le carnet en parchemin, les scènes de capture et les bandeaux dorés de
QuestCompanion (textures du client, section suivante) ne sont pas convertis.

### Logos (`tools/gen_logos.py`)

Une famille : le même médaillon d'or, un glyphe et une couleur par addon.
Ready2Quest : l'écu coché, échancré au sommet, qui porte en cimier le « ! »
doré des quêtes. QuestCompanion : l'empreinte, en bleu arcane. Trois fichiers
par addon : `logo.tga` (128 : marque, médaillon des fenêtres),
`logo_petit.tga` (64, glyphe simplifié : liste des addons, bandeaux),
`logo_glyphe.tga` (64, sans anneau : bouton de la mini-carte, qui a le sien).
L'outil demande `rsvg-convert` et Pillow.

### Voir sans le jeu

`python3 tests/snapshot.py <scène> sortie.html` rend une fenêtre avec le vrai
code (Azeroth par défaut, `sobre:<scène>` pour Sobre) : teintes multipliées,
textures retournées, débords et ordre des cadres comme en jeu. Reste
approché : la police des titres, les textures du client, le rendu exact des
reliefs et des lueurs.

### Contrastes et tests

Chaque texte posé sur une matière forgée est mesuré au point le plus clair et
au plus sombre de son fond (≥ 4,5 corps, ≥ 3 titres) :
`tests/modules/ui_skin.lua`, `ui_forge_controles.lua`,
`ui_forge_navigation.lua`, `ui_forge_r2q.lua`, `ui_forge_qc.lua`.
`ui_bricks.lua` et deux blocs de `socle.lua` sont épinglés en Sobre : ils
décrivent le thème d'avant, qui ne doit pas bouger.

### À regarder en jeu

Le relief des plaques et la profondeur des creux (teinte × texture), les
dégradés (`SetGradient`), les lueurs additives, Friz Quadrata en capitales
de 10 px, le médaillon et les quatre coins sur chaque fenêtre, le bouton de
la mini-carte et l'icône de la liste des addons.

## Style Azeroth (QuestCompanion)

Réglage « Style de l'interface » : Sobre (le langage ci-dessus) ou Azeroth
(doré). Azeroth habille le même contenu, il ne le reconstruit pas
(`AzerothStyle.lua` pour les bandeaux et la capture, `JournalAzeroth.lua`
pour le carnet).

- Matières : bois `achievement-wood-nineslice-*`, parchemin, bandeaux et
  boucliers du client, par atlas ou FileDataID ; aucune image embarquée.
  Police Friz Quadrata (`ns.AZEROTH_FONT`).
- Repli : un élément dont l'atlas ou le fichier est refusé reste en Sobre ;
  si le bois manque, les fenêtres passent en Sobre (les bandeaux gardent
  Azeroth) ; une colonne qui n'a pas pu être habillée entière repasse en
  Sobre (jamais de texte clair sur parchemin).
- Encres : texte sombre sur parchemin, texte clair sur bois et bandes ;
  couleurs prises dans `ns.AZEROTH_INK` (certaines sont les jetons du socle :
  `tagBlue` = `BLUE`, `navText` = `TEXT`…), jamais en dur. Le carnet repasse
  les encres (`Recolor`) avant de poser le fond des lignes ; un texte qui
  porterait un code `|c…` passerait devant l'encre : les couleurs se posent
  sur la ligne (`SetTextColor`), pas dans le texte.
- Contraste mesuré : chaque texte posé sur une matière du client a un rôle
  dans `ns.AZEROTH_CONTRAST` (encre, luminance du pire fond mesurée, seuil,
  taille) ; `RolePaint` / `RoleInk` posent l'encre d'un rôle, et
  `tests/modules/azeroth_style.lua` recalcule chaque ratio.
- Changement de style à chaud : la fenêtre affichée est remplacée par celle de
  l'autre style (état recopié) ; l'ancienne est mise de côté
  (`ns.uiStyleCache`) et resservira au retour. Une fenêtre qui existe dans
  les deux styles a un nom global par style (sinon Échap vise la mauvaise).
- Carnet en Azeroth (`ns.CARNET_LAYOUT`) : colonne de 196 sur parchemin,
  entrées sur bandes sombres, plaque de titre de 706 × 100 qui déborde de 46
  au-dessus, bois de 16 de chaque côté autour d'un contenu de même taille ;
  le garde-manger descend en bas de la colonne. Confirmations (changer de
  compagnon) au même habit.
- Bandeaux (`ns:AzerothCreateBanner`, `ns.AZEROTH_LAYOUT` 388 × 126) :
  bande claire du titre (encre sombre), nom en blanc ombré, étoiles dorées ;
  avec `strip`, une bande sombre dessous pour les infos et les boutons.

## Règles

- Aucune couleur, police ou taille en dur dans un module : jetons et briques
  du socle (`Theme.*`, `ns.TC`), `ns.AZEROTH_INK` pour le style Azeroth. Les
  données (cosmétiques, effets) portent leurs propres teintes.
- Contraste mesuré, pas estimé : ≥ 4,5:1 pour le corps de texte, ≥ 3:1 pour
  les titres, sur le vrai fond (texture comprise). Un texte sur une matière du
  client a son rôle dans `ns.AZEROTH_CONTRAST`.
- Illustrations : celles du client uniquement, par référence (atlas,
  FileDataID, `Interface\\…`), avec un repli quand l'atlas manque ; jamais
  d'illustration générée, ni d'image reprise du jeu ou d'internet. Sont à
  nous, générés par script : l'habillage du thème forgé (formes, reliefs et
  lueurs : `tools/gen_ui_assets.py`), les logos (`tools/gen_logos.py`) et le
  filet de capture. Un test tient la liste des images embarquées.
- Tout texte affiché existe en français et en anglais (`ns.RegisterStrings`,
  `Locales.lua` ; table bilingue de `Base.lua` pour les messages d'avant
  `Strings.lua`). Pluriels : `ns:FP(clé, n, …)`.
- Une fenêtre a un nom global unique (un par style si elle en a deux), pour
  qu'Échap la ferme.
- Les briques acceptent les clients sans `SetFont` réussi, sans
  `SetGradient`, sans AnimationGroup, etc. (repli silencieux).
- Une fenêtre se reconstruit avec les briques ; les modules déclarent toujours
  leurs pages avec `ns.AddOptionPage` (rien à réécrire côté module).
