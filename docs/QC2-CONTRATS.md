# QuestCompanion 2.0 — contrats entre lots

Cinq lots se codent **en parallèle**, chacun dans son worktree, depuis la même base (`qc2-base`). Ce document dit ce que chaque lot **fournit** aux autres et ce qu'il peut **utiliser** des autres. Un lot ne s'appuie jamais sur le code d'un autre lot comme s'il était là : il l'appelle **seulement s'il existe** (`if self.CaptureStars then … end`) et a un repli raisonnable sinon. À la fusion, tout s'emboîte.

Le cœur de QC 2.0 est la **ménagerie** (Pokémon-like). Décisions complètes : mémoire du projet `qc-2-0-menagerie-plan`, résumée ici par lot.

## Règles communes

- **Fichiers du lot** : chaque lot a son fichier, déjà créé (vide) et déjà déclaré dans `QuestCompanion.toc`. **Ne pas toucher au `.toc`.** Mettre le plus possible de son code dans son fichier ; ne modifier les fichiers existants que là où c'est nécessaire, de façon ciblée (pas de reformatage, pas de déplacement de code).
- **Ne pas toucher** : `Config.lua` (version), `QuestCompanion.toc`, `CHANGELOG.md`, les README, `docs/` (sauf ce fichier en lecture), le socle `Libs/Socle` (si un besoin de socle apparaît : le dire dans le rapport final, ne pas le faire).
- **Tests** : `python3 tests/run_tests.py` doit rester vert (paquet `lupa` déjà installé dans `/tmp/pylib`). Chaque lot ajoute **son propre module de tests** `tests/modules/qc2_<lot>.lua` (nom unique). Modifier un test existant seulement si le comportement voulu change, et le dire.
- **Textes** : français et anglais, `ns.RegisterStrings(FR, EN)` ; exposer les tables aux tests seulement en test : `if ns.KEEP_STRINGS then ns.X_STRINGS = { fr = FR, en = EN } end`.
- **Langue du code et des commentaires** : français, comme le reste du dépôt. Style : tabulations, fonctions `ns:Nom`, appels d'API du jeu protégés (`pcall`, `rawget(_G, …)`, `ns.Plain` pour les valeurs secrètes de Forever).
- **Contraintes du jeu** : un addon ne touche ni au combat, ni à l'XP, ni au butin ; il ne connaît la position d'aucun monstre (seulement les barres de nom affichées, la cible, le survol) ; pas d'interface dans le monde (rien sur un cadavre). Le moteur de Forever est récent (toc 16001, valeurs « secrètes »).
- **Commits** : sur la branche du lot, en local seulement (pas de push, pas de PR). Message en français, sans aucune mention d'IA (pas de `Co-Authored-By`). Auteur : `-c user.name="Alexis Lapasset" -c user.email="alexis.lapasset@gmail.com"`.

## Base commune déjà là

- `CreatureTypes.lua` : `ns.CREATURE_TYPES` (`beast`, `humanoid`, `undead`, `elemental`, `dragonkin`, `demon`, `giant`, `mechanical`), `ns:CreatureTypeKey(texte)` (texte du client, FR ou EN → clé), `ns:CreatureTypeLabel(clé)`.
- Fiche de capture existante (`Capture.lua`, `ns:CaptureData().creatures[npcID]`) : `name`, `class` (`normal`, `elite`, `rare`, `rareelite`, `worldboss`…), `level`, `type` (texte du client), `family`, `zoneID`, `normal` (bool), `at`, `shiny` (bool), `shinyAt`. `ns:CaptureHas(npc, shiny)`, `ns:CaptureChance(info, aidID, playerLevel)`, `ns:CaptureOffer`, `ns:CaptureThrow`, `ns:CaptureResolve(rolling)`. Apparences `cap:<npc>` et `cap:<npc>:s`.
- Brillants (`Shiny.lua`) : `ns:ShinyChance(class, killed)`, `ns:ShinyKnown(npc)`.
- Ménagerie (`Capture.lua`) : `ns:MenagerieList(opts)`, `ns:MenagerieCatalog()` ; tables de zone paresseuses (`ns.ZoneIds`, `ns.ZoneEach`).

## Lot 1 — Capture discrète (`CaptureQueue.lua`)

**Fait** : plus de fenêtre automatique. Un **bouton filet** sur le cadre du compagnon, visible seulement s'il y a quelque chose à capturer, avec un compteur, doré et scintillant si une brillante est dans la file. **File d'attente** des monstres abattus capturables (packs) : seulement ce qui vaut le coup (espèce manquante, brillante, ou spécimen qui pourrait battre le tien) ; 30 s chacun, à compter de la **fin du combat**. Clic = capture du meilleur candidat (brillante > espèce nouvelle > plus rare > amélioration d'étoiles), la scène de capture se joue ; clic droit = la liste. **Étoiles** : chaque capture tire une qualité 1 à 3 (3 plus rare) ; recapture possible pour tenter mieux, le meilleur est gardé ; le bouton ne propose pas une espèce déjà à 3 étoiles dans cette version.

**Fournit** :
- `entry.stars` (1-3, version normale) et `entry.shinyStars` (1-3, version brillante) dans la fiche de capture ; anciennes captures sans étoiles = 1.
- `ns:CaptureStars(npcID, shiny)` → 1-3, ou nil si cette version n'est pas capturée.
- `ns:CaptureQueue()` → la file (liste de candidats `{ guid, npcID, name, class, type, shiny, reason, expires }`).
- Garde `ns:CaptureResolve(rolling)` (et `rolling.target` avec `npcID`, `class`, `type`, `shiny`) : les autres lots s'y accrochent.

## Lot 2 — Compagnon actif (`CompanionEffects.lua`)

**Fait** : la créature capturée emmenée donne deux effets liés à son **type** : un de **chasse** et un de **confort** (table des 8 types à proposer et équilibrer ; exemples : Bête = repère les Bêtes pas encore capturées sur les barres de nom + faim qui baisse moins vite ; Humanoïde = +capture sur les Humanoïdes ; Mort-vivant = +brillant sur les Morts-vivants ; Élémentaire = aides parfois non consommées ; Draconien = abattus comptés double pour la chance de brillant ; Démon = +capture sur élites et rares ; Géant = une aide en plus au palier de zone ; Mécanique = une capture ratée rend parfois l'aide — PAS de « pistage » : impossible). **Force** : normal ×1, élite ×1,5, rare et rare élite ×2, boss ×2,5 ; brillante +0,5 ; +0,25 par étoile au-dessus de 1 ; + bonus de complétion par type (lot 3). **Mascottes** (apparences non capturées) : un bonus général modeste (envies qui baissent moins vite, un peu de capture sur tout) qui grandit avec l'étape d'évolution, comme le familier du chasseur. **Envies** : la force est pleine si le compagnon est heureux (toutes ≥ 50 %), jamais sous la moitié. **Changement de compagnon** : une **confirmation** avant (aujourd'hui un clic suffit, dans la Ménagerie, la page Compagnon, les réglages), qui compare les effets de l'ancien et du nouveau ; l'effet ne s'active qu'**au bout de 2 minutes**. **Affichage** : fiche Ménagerie (« Chasse : … / Confort : … » avec les vraies valeurs), page Compagnon (effets en cours, compte à rebours), marque (patte) sur les barres de nom pour le repérage, chance de l'infobulle qui inclut le bonus (« à capturer · 45 % (+15) »).

**Utilise si présent** : `ns:CaptureStars` (lot 1, sinon 1), `ns:MenagerieTypeBonus(typeKey)` (lot 3, sinon 0).

**Fournit** :
- `ns:CompanionEffects()` → `{ typeKey, strength, active (bool), activeAt, hunt = { id, value, label }, comfort = { id, value, label } }` pour le compagnon en cours (mascotte : `typeKey = nil`, effet général).
- `ns:CompanionEffectValue(id)` → la valeur active d'un effet (0 si inactif).
- Les bonus passent par des enveloppes de `ns:CaptureChance`, `ns:ShinyChance`, etc. posées dans `CompanionEffects.lua`, plutôt que par des modifications de ces fonctions.

## Lot 3 — Collection (`MenagerieCollection.lua`)

**Fait** : **séparer** Exploration et Ménagerie : le pourcentage d'exploration d'une zone ne compte plus que lieux, récolte et quêtes (les parts bestiaire et nommés en sortent ; paliers et coffres déjà gagnés restent acquis). **Sceau de zone** : 100 % des espèces de la zone capturées (version normale) → un cosmétique propre à la zone (cadre ou fond aux couleurs de son biome ; les biomes sont dans `MenagerieCollection.lua`, `ns.MENAGERIE_ZONE_BIOME` depuis la 2.6.0) et un bonus de chance de brillant dans la zone scellée. **Complétion par type** : paliers de captures par type (par ex. 10, 20, 40) qui renforcent l'effet de ce type. **Paliers globaux** : 10, 25, 50, 100, 250 espèces → récompense et **titre de dresseur**. Affichage dans la Ménagerie (sceau de la zone choisie, progression du sceau, titres) et dans Exploration (sceau de la zone).

**Fournit** :
- `ns:MenagerieSealProgress(zoneID)` → `have, need` ; `ns:MenagerieSealed(zoneID)` → bool ; `ns:MenagerieSeals()` → liste des zoneID scellées.
- `ns:MenagerieTypeBonus(typeKey)` → force en plus (0 au départ).
- `ns:TrainerTitle()` → titre actuel (texte) ou nil ; `ns:TrainerTitleKey()`.

## Lot 4 — Missions (`MissionsMenagerie.lua`, et `Daily.lua` / `Weekly.lua` au besoin)

**Fait** : **jour** = toujours une mission de ménagerie (capturer une espèce nouvelle dans la zone, capturer un type, capturer un élite…), une mission d'exploration (lieux, récolte, quêtes), et la mission du caractère. **Semaine** : garde la chasse au brillant, ajoute des missions **par type** (« emmène un Mort-vivant et capture 2 Morts-vivants »). Les missions restent faisables (seulement ce qui existe dans la zone).

**Utilise si présent** : `ns:CompanionEffects()` (lot 2) pour « emmène un X » (sinon : regarder l'apparence en cours), `ns:CreatureTypeKey`. S'accroche à `ns:CaptureResolve` pour compter les captures par type.

## Lot 5 — Fiche de dresseur (`TrainerCard.lua`)

**Fait** : une **fiche de dresseur** consultable par les autres détenteurs de l'addon. Échange par messages d'addon invisibles (`C_ChatInfo.SendAddonMessage` / `RegisterAddonMessagePrefix`, préfixe court propre à QC), hors combat, avec limite de débit et découpage si besoin. **Contenu** : nom, titre de dresseur, date de première capture ; compagnon en cours (modèle 3D par npcID ou displayID, nom, rareté, brillant, ses effets) ; **vitrine de 3 créatures** choisies par le joueur ; chiffres (espèces capturées / total, brillantes capturées et reconnues, sceaux) ; badges des sceaux par continent. Rien de privé. Partagée par défaut, réglage pour la couper. **Découverte** : annonce à l'entrée en groupe / raid / guilde, sonde silencieuse en chuchotement d'addon quand on cible un joueur hors combat (une fois par joueur et par session), cache gardé avec expiration. **Menu du clic droit** : « Voir sa fiche de dresseur » (`Menu.ModifyMenu`, menus de joueur) **seulement pour les joueurs connus comme détenteurs**. Ligne dans l'infobulle d'un joueur : « Dresseur QuestCompanion ». Sa propre fiche aussi consultable (page ou bouton dans le carnet) pour choisir la vitrine.

**Utilise si présent** : `ns:TrainerTitle()` et `ns:MenagerieSeals()` (lot 3), `ns:CompanionEffects()` (lot 2), `ns:CaptureStars` (lot 1). Sinon la fiche affiche ce qui existe.
