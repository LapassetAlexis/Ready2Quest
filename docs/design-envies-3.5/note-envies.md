# Faim, Énergie, Moral, Curiosité : note de design

Quest Companion 3.4.0 bêta (branche qc-3-4). Audit du code, benchmark, trois orientations, recommandation. Rien n'est codé.

## 1. Ce que dit le code

- **Quatre envies** de 15 à 100, départ à 80. Elles baissent par minute de connexion : faim 0,6, curiosité 0,5, énergie 0,4, moral 0,3. Rien ne baisse hors connexion, mais tout baisse quand on est absent du clavier, en vol ou mort.
- **Une seule conséquence de jeu** : la force des effets de type du compagnon vaut 50 % plus 12,5 % par envie à 50 ou plus. Les effets de caractère, de taille et le lien de la 3.4 n'en dépendent pas.
- **Une seule porte** : pour passer un stade (niveaux 10, 20, 40, 60), les quatre envies doivent être à 70.
- **Quatre seuils différents** : 30 (couleur orange), 35 (le compagnon réclame), 50 (effets), 70 (« heureux »). Le Guide dit « heureux » pour 50, la page Compagnon pour 70.

### Ce que la simulation montre (session de quête, 2 créatures par minute, 1 quête toutes les 10 minutes)

| Durée | Force des effets | Pourquoi |
|---|---|---|
| 0 à 50 min | 100 % | rien n'est sous 50 |
| 50 à 75 min | 87,5 % | la faim passe sous 50 |
| 75 min à 3 h | 75 % | l'énergie passe sous 50 |
| au dernier stade (niveau 60) | 100 % pour toujours | le plancher passe à 50, pile le seuil des effets |

- **Le moral reste à 100** du début à la fin : +2 par minute rien qu'en tuant, contre −0,3.
- **La pénalité ne se sent pas** : pour une créature normale à une étoile, le pire cas réaliste fait passer le bonus de capture de ×1,12 à ×1,09.
- **Le système s'éteint au niveau 60** : plus de pénalité, plus de stade à passer, plus de réplique. Les barres restent affichées et ne servent plus à rien.
- **Les friandises n'ont pas de valeur** : on en gagne 3 à 10 par jour, il en faudrait 1 par demi-heure sans rien faire d'autre, et un repas ou six minutes d'auberge font le même travail. Le garde-manger reste plein et les friandises en trop sont mangées d'office.
- **Les revers de la 3.4 ne pèsent rien** : un Géant Gourmand au lien 2 perd sa faim plus lentement (0,53 par minute) qu'un compagnon ordinaire (0,6), parce que son caractère protège déjà son envie préférée.

### Ce qui plaît quand même
- 36 répliques d'envie, 24 de repas et de boisson, 22 d'auberge et de camp, des variantes par caractère : c'est la voix du compagnon.
- Le lien avec le jeu normal : manger, dormir à l'auberge, explorer.
- Recevoir une friandise fait plaisir, même si elle ne sert à rien.

**Diagnostic.** Quatre jauges à surveiller pour une pénalité qu'on ne sent pas, qui disparaît au niveau 60. Ce qui a de la valeur, c'est la voix et le rituel, pas les jauges.

## 2. Ce qu'on retient des autres jeux

- **Familiers de chasseur de WoW** : le bonheur donnait 125 / 100 / 75 % de dégâts et demandait de nourrir. Blizzard l'a retiré en 4.1 (2011) en gardant le bonus comme valeur de base. On enlève la corvée, pas la récompense.
- **Repos de WoW** : en bêta, l'expérience tombait à 50 % après quelques heures ; présenté à l'envers (200 % quand on est reposé), le même système est devenu apprécié.
- **Bien nourri, repas de FFXIV** : un état à durée limitée. Ne pas manger, c'est juste ne pas avoir le bonus.
- **Pokémon GO** : le copain « enthousiaste » double les gains pendant un temps ; le lien, lui, ne redescend jamais.
- **Red Dead Redemption 2** : le lien avec le cheval ne fait que monter. La faim joue sur autre chose.
- **Spiritfarer, Animal Crossing** : le compagnon exprime une envie visible, une à la fois ; y répondre fait plaisir, l'ignorer ne coûte rien.
- **Stardew Valley** : l'affection du conjoint qui baisse chaque jour est la plainte classique. Ne pas reproduire.

## 3. Trois orientations

### A. Polir
On garde les quatre jauges. On aligne les seuils, on arrête la baisse quand on est absent, on affiche la pénalité, on règle le moral.
- Pour : peu de code. Contre : ça reste une corvée sans enjeu, toujours morte au niveau 60.

### B. Des états, pas des jauges (recommandée)
Les effets valent toujours 100 %. Trois envies comblées donnent chacune un état de 45 minutes ; le moral devient l'humeur qui en résulte, et les trois états ensemble rendent le compagnon Rayonnant, avec un vrai bonus. Le compagnon exprime une envie à la fois. Les friandises donnent l'état tout de suite.
- Pour : plus de punition, une lecture en un coup d'œil, un but au niveau 60, des friandises utiles, les répliques gardées.
- Contre : réécrire la page Compagnon, une centaine de textes et une centaine de tests.

### C. Le lien seul
Plus d'envies du tout. Les friandises et les caresses donnent des points de lien.
- Pour : le plus simple. Contre : le compagnon perd sa voix du quotidien, et les mascottes (qui n'ont pas de lien) n'ont plus rien.

| | A. Polir | B. États | C. Lien seul |
|---|---|---|---|
| Effets du compagnon | 50 à 100 % | toujours 100 %, plus le bonus Rayonnant | 100 % |
| À surveiller | 4 jauges | 3 états avec minuterie | rien |
| Sans rien faire | on perd | on garde tout | on garde tout |
| Au niveau 60 | éteint | vivant | sans objet |
| Friandises | inutiles | l'état tout de suite, sans passer par l'auberge | points de lien |
| Répliques d'envie | gardées | gardées (elles deviennent des demandes) | perdues |
| Coût | petit | moyen | moyen |

## 4. Recommandation : B

Ma première version donnait +5 % de force par état. La simulation l'a démontée : le gain (un bonus de capture de ×1,12 à ×1,144) était plus petit que la pénalité que je venais de juger insensible, et nul pour les meilleurs compagnons, déjà à leur plafond. La version ci-dessous en tient compte.

### 4.1 Trois états de 45 minutes

| État | Comment on l'obtient en jouant | Friandise (60 minutes) |
|---|---|---|
| Repu | manger (pas boire : sinon les lanceurs de sorts l'ont 98 % du temps), ou « Bien nourri » | biscuit |
| Reposé | 2 minutes dans une auberge ou une ville, arriver à un camp, le tampon d'auberge du jour | infusion |
| Éveillé | découvrir une zone ou un lieu, un tampon, un coffre, entrer dans un donjon, tuer une élite ou une rare ; en chasse : 15 créatures tuées ou capturées en 10 minutes, une brillante, une espèce nouvelle | carte |

- La minuterie compte le temps de jeu. Reprendre un état en cours le remet à sa durée pleine. Rien ne s'empile ni ne dépasse la durée pleine.
- Le festin donne les trois pour 60 minutes. Le bonbon remet à plein les états en cours.
- La caresse ne touche pas aux états : elle donne des cœurs et du lien, comme aujourd'hui. Pas de « caresse toutes les 15 minutes sinon je perds ».
- Avec Ready2Quest, partir de la ville avec de la nourriture donne aussi Repu.

### 4.2 Le moral devient l'humeur, et Rayonnant compte

| États actifs | Humeur | Effet |
|---|---|---|
| 0 | Tranquille | effets entiers |
| 1 | Content | effets entiers |
| 2 | Joyeux | effets entiers |
| 3 | Rayonnant | capture +10 %, brillantes +20 % (1 sur 150 devient 1 sur 125) |

- Le bonus de Rayonnant s'applique après les effets de type, donc même aux compagnons déjà au plafond. La limite de 95 % de capture reste.
- Une seule règle à retenir, et elle se voit.
- « Rayonnant » se prépare : manger et passer par l'auberge avant de partir, puis explorer ou chasser.

### 4.3 Qui sera Rayonnant (simulation, 3 000 sessions par cas, avec les règles de la première version)

| Session | Part du temps Rayonnant |
|---|---|
| 30 minutes en montant de niveau | 88 % |
| 2 heures en montant de niveau, corps à corps | 39 % |
| 2 heures en montant de niveau, lanceur de sorts | 78 % (avant le retrait de la boisson) |
| Donjon de 75 minutes | 60 % |
| 3 heures de chasse au niveau 60, au même endroit | 4 à 6 % (avant l'ajout des déclencheurs de chasse) |

Ces chiffres sont ceux d'avant correction : ils montrent pourquoi la boisson est retirée et pourquoi la chasse donne Éveillé. Les règles corrigées n'ont pas été resimulées ; la durée de 45 minutes est le premier réglage à surveiller en bêta.

### 4.4 Une envie à la fois
- Le compagnon exprime une envie : un état qu'il n'a pas, ou, s'il les a tous, celui qui se termine dans moins de 15 minutes. Son caractère pèse sur le choix.
- L'envie est une donnée affichée (page Compagnon, fiche au survol, tableau de bord), quel que soit le réglage de bavardage. La bulle n'en est que l'écho.
- Y répondre donne l'état et un point de lien, 3 par jour au plus, en plus des 10 points du jour. Une mascotte, qui n'a pas de lien, voit ses états en cours remis à plein.
- L'ignorer ne coûte rien. Une nouvelle envie arrive 20 minutes plus tard.
- Les 27 répliques de faim, d'énergie et de curiosité servent telles quelles. Les 9 répliques de moral deviennent ses réactions quand il rayonne.

### 4.5 Stades
Pour passer un stade, il faut le niveau et avoir comblé une envie. La condition des quatre envies à 70 disparaît.

### 4.6 Ce que deviennent les effets qui parlaient d'envies
Un écart de 10 % sur 45 minutes fait 4 minutes et demie : personne ne le verrait. Les règles passent donc en durées rondes.
- État préféré du caractère : 60 minutes au lieu de 45.
- Revers de la 3.4 qui touchaient une envie (Gourmand, Géant et Grand sur Repu ; Curieux et Taquin sur Reposé ; Paresseux sur Éveillé) : 30 minutes au lieu de 45. Le revers de Câlin, qui portait sur le moral, est à redéfinir.
- Atouts : Curieux, la cueillette donne aussi Éveillé ; Paresseux, tout camp donne Reposé aussitôt ; Zen, tous ses états durent 60 minutes.
- Effets de confort de type (« baisse 10 à 40 % moins vite ») : l'état dure plus longtemps du même pourcentage. Ils gardent leur sens sans réécriture.

### 4.7 Friandises et garde-manger
- Une friandise donne l'état tout de suite, pour 60 minutes, où qu'on soit.
- Garde-manger plein : la friandise en trop devient 1 paillette au lieu d'être mangée d'office.
- La friandise de récompense est celle de l'état manquant, sinon de celui qui finit le plus tôt.
- Les missions de caractère (3 repas, 15 minutes de repos, 3 caresses) ne changent pas.

### 4.8 Comment le coder sans tout casser
La relecture technique a compté 29 appels qui ajoutent à une envie et 32 lectures. Elle propose de garder les envies chiffrées sous le capot :
- trois envies au lieu de quatre, chacune perd 0,667 par minute, soit 45 minutes pour passer de 100 à 70 ;
- un déclencheur met l'envie à 100 ; « état actif » veut dire 70 ou plus ; le temps restant se lit dans la valeur ;
- la force ne descend plus sous 100 % ; le plancher spécial du dernier stade disparaît ;
- aucune migration de sauvegarde. Le jour de la mise à jour, personne ne démarre avec un état.

### 4.9 Calendrier
La bêta 2 de la 3.4 est publique et ce chantier touche 17 fichiers de tests. Je recommande une 3.5 à part, avec sa bêta, après la sortie de la 3.4.

## 5. Écrans

- **Page Compagnon**, colonne de gauche : à la place des quatre barres, trois plaques d'état (nom, temps restant, comment l'obtenir), la ligne d'humeur avec ce qu'il manque pour rayonner, et l'envie du moment. « Ses effets » dessous. Tout tient dans la place des quatre barres (mesuré dans la maquette).
- **Tableau de bord du carnet** : humeur, trois pastilles d'état, l'envie du moment sur une ligne.
- **Fiche au survol** : humeur, trois lignes d'état avec leur temps, l'envie.
- **Médaillon du compagnon** : l'étiquette d'humeur existe déjà ; ses quatre teintes servent aux quatre humeurs.

## 6. Coût

- Environ 100 clés de texte touchées, en trois langues ; les 36 répliques d'envie sont gardées telles quelles.
- Environ 106 vérifications de tests à réécrire, dont 41 dans `companion.lua`.
- Fichiers : Companion (moteur des envies), CompanionEffects (force, effets de confort), Personality, Treats, SpecimenBond, JournalWindow (page et tableau de bord), ForgeCompanion, JournalGuide, GuidedTour.

## 7. Décisions qui t'appartiennent

- L'orientation : A, B ou C.
- Le bonus de Rayonnant (capture +10 %, brillantes +20 %), plus petit, ou aucun.
- « Reposé » en passant simplement en ville, ou seulement à l'auberge.
- Une 3.5 après la sortie de la 3.4, ou dans la bêta 3.4 en cours.
