# Ready2Quest

**Le compagnon de départ de l'aventurier.** Avant que tu quittes la ville, Ready2Quest vérifie que ton sac est prêt : de quoi manger, de la place pour le butin, un équipement en état, tes buffs, ta pierre de foyer… et te le dit au bon moment, pas quand il est trop tard.

Pour **World of Warcraft Forever** et **Classic Era**. Interface en français et en anglais.

---

## Ce que fait l'addon

Ready2Quest réunit **huit modules** et un peu de **confort** (QoL). Chacun s'active ou se coupe d'un clic.

| | Module | En une phrase |
|---|---|---|
| ◆ | **Check avant le départ** | Quand tu quittes un village, une capitale ou un camp, une note de préparation sur 100 et des conseils |
| ◆ | **Retour d'expédition** | Quand tu rentres, le bilan de ta sortie : XP, or, butin, morts, usure, quêtes à rendre |
| ◆ | **Avant le donjon** | À l'entrée d'un donjon, sa fiche : niveau conseillé, tes quêtes pour ce donjon, ta préparation |
| ◆ | **Compagnon de route** | Une petite créature qui voyage avec toi, réagit à ton aventure et grandit avec toi |
| ◆ | **Carnet de voyage** | Un tampon par zone, village, capitale, donjon, ennemi rare et palier : ta collection de voyage |
| ◆ | **Kit de camp** *(Forever)* | Ton kit de feu de camp et ton objet de camp prêts, le compte à rebours des buffs au camp |
| ◆ | **Résumé de stuff** | Quand tu changes d'objet, un petit résumé éphémère des stats gagnées ou perdues |
| ◆ | **Stats du portrait** | Au survol de ton portrait, tes stats principales, choisies selon ta classe et ta spécialisation |
| ✦ | **La bonne récompense** | Au rendu d'une quête, la récompense qui te sert le plus est mise en avant |
| ✦ | **Rythme de leveling** | XP par heure, temps avant le prochain niveau, repos à gagner en te déconnectant |
| ✦ | **Sac plein** | Sac plein en pleine nature : l'objet que tu perds le moins à jeter, en un clic |
| ✦ | **Après la mort** | Courir jusqu'au corps ou le guérisseur des esprits ? Les deux options chiffrées |
| ✦ | **Marchand** | Vente automatique des objets gris et réparation automatique chez les marchands |

---

## Check avant le départ

### Quand il se déclenche

Tout seul, **au moment où tu quittes une zone sûre** : ville, village, hub ou campement. Si tu y reviens dans les 6 secondes, rien ne se passe, pour ne pas t'alerter à chaque coin de rue. En vol, il attend que tu aies atterri. En combat, il attend la fin du combat. Mort ou fantôme, il ne dit rien.

- **Note de 85 ou plus** : une simple ligne dans le chat, du genre « Sac bouclé, 92/100. Parti de Long-guet. »
- **Note plus basse** : la fenêtre **Avant le départ** s'ouvre, avec la note, le verdict (*Prêt*, *Prêt avec réserves*, *Pas prêt*) et les conseils pour y remédier.

Tu peux aussi le lancer quand tu veux : `/r2q`, ou un clic gauche sur le bouton de la minicarte. Dans la fenêtre, la petite flèche du bandeau relance le check, et **Partir à l'aventure** la referme. Les réglages, eux, sont au clic droit sur le bouton de la minicarte.

### Ce qu'il contrôle

| Contrôle | Ce qui est vérifié |
|---|---|
| Sacs | assez d'emplacements libres pour le butin |
| Butin à vendre | des objets gris qui encombrent encore les sacs |
| Vivres | de quoi manger et boire |
| Potions | une réserve de potions (désactivé par défaut) |
| Buffs | les buffs que tu portes d'habitude (Robustesse, Marque du fauve…) |
| Durabilité | une pièce d'équipement trop usée |
| Réparation | assez d'or pour tout réparer |
| Réactifs | les réactifs de ta classe : munitions, fragments d'âme, poudres, chandelles, graines, ankh… |
| Sorts | de nouveaux sorts à apprendre chez ton entraîneur |
| Foyer | ta pierre de foyer, disponible ou en recharge, et l'endroit où elle te ramène |
| Métier | les composants qui manquent pour la recette choisie |
| Quêtes | des quêtes prêtes à rendre avant de repartir |
| Repos | ton bonus d'expérience de repos (pour information) |

Les contrôles sans objet ne s'affichent pas : un guerrier ne verra jamais « Réactifs », et la réparation reste muette tant qu'aucun marchand n'a mesuré son coût. Chaque contrôle se règle ou se coupe dans les options.

Les buffs n'ont rien à configurer : l'addon retient ceux qui durent plusieurs minutes sur toi. Il reconnaît les différents rangs et les versions de groupe (Prière de robustesse couvre Robustesse) et ignore les buffs de nourriture et de campement.

### Les zones sûres

Une zone sûre est un endroit où l'on peut **se préparer sans risque** : manger, réparer, vendre, se lier à l'auberge.

- **Connues dès l'installation** : les capitales, les villages et les hubs de ta faction, ainsi que les villes neutres (Booty Bay, Gadgetzan, Everlook…). Sur Forever, c'est aussi le cas des nouvelles zones comme Zephras Isle. Cela fait 80 lieux, en français comme en anglais.
- **Ce qui ne compte pas** : un village de l'autre faction, un donjon, un champ de bataille, une mine ou une ferme.
- **Les camps de Forever** : près d'un feu de camp, tu es au campement. Quand tu t'en éloignes, le check part, comme en quittant un village.
- **Le reste s'apprend** en jouant : un petit camp absent de la liste devient sûr dès que tu y trouves un aubergiste, un maître de vol, une boîte aux lettres ou une banque, ou à la fois un marchand et un donneur de quêtes. Tu peux aussi en ajouter un toi-même avec `/r2q safe`.

La fenêtre indique toujours **d'où tu es parti** (« Parti de Comté-de-l'Or · boîte aux lettres »). Si un endroit a été appris à tort, tu le retires dans les réglages, page **Zones sûres**.

---

## Retour d'expédition

La suite naturelle du check avant le départ : **départ → expédition → retour**. Quand tu reviens dans une zone sûre (village, capitale ou camp), une carte au même style résume ta sortie :

- la durée, l'XP gagnée et les niveaux pris ;
- l'or gagné et dépensé, et le net ;
- les objets notables ramassés (verts et mieux) ;
- les morts et l'usure de ton équipement ;
- les quêtes prêtes à rendre ;
- ce qu'il faut racheter avant de repartir.

Pas de bilan pour un aller-retour sans intérêt : moins d'une minute, sans rien gagné ni perdu (réglable). Tu peux préférer une ligne dans le chat à la fenêtre.

## Avant le donjon

En arrivant à l'entrée d'un donjon, ou en y entrant, une fiche pour **ce** donjon. Elle ne s'affiche qu'une fois par visite :

- le niveau conseillé, comparé au tien ;
- les quêtes de ce donjon que tu as dans ton journal ;
- une préparation courte : durabilité, réparation, vivres, potions, pierre de foyer.

Elle couvre les 19 donjons classiques et les 9 nouveaux donjons de Forever : City of Dalaran, Ruins of Lordaeron, Hall of Thanes, Excavation Site, Krol'dok… Sur Forever, elle listera aussi les plans de métier qui tombent dans le donjon, dès que ces données seront connues.

## Compagnon de route

Une petite créature du jeu (un dragonnet pour commencer) t'accompagne dans un coin de l'écran. Elle **réagit à ton aventure** par de courtes bulles :
- « On repart ? J'ai faim… » si tu quittes la ville sans vivres ;
- « Aïe… » à ta mort ;
- « Quelle vue ! » quand tu découvres une zone ;
- « On se réchauffe ? » au feu de camp.

Elle a quatre envies : **faim**, **énergie**, **moral** et **curiosité**. Elles se remplissent quand tu manges, te reposes, rends une quête ou explores. Clique dessus pour lui faire une caresse.

- **Elle grandit avec toi** : Nouveau-né, Jeune (niveau 10), Aguerri (20), Vaillant (40) et Légendaire (60), avec une petite fête à chaque étape.
- **Elle ne t'en veut jamais** : elle ne meurt pas, ne régresse pas et ne tombe pas malade. Après une longue absence, elle est juste un peu ensommeillée : « Tu m'as manqué ! »
- **Elle se personnalise** : de nouvelles **apparences** (dragonnets de couleur, chouette, feu follet, dragon féerique…) et des **ornements** (ruban, lanterne, médaille, cadre doré) se débloquent avec ton carnet de voyage et ton niveau.

Tu peux la renommer avec `/r2q compagnon nom Pépite`.

## Carnet de voyage

Ta collection de voyage : un **tampon** pour chaque première fois.

| Tampon | Quand |
|---|---|
| Zone | tu découvres une zone |
| Village | tu entres dans un village ou un hub, de ta faction ou neutre |
| Capitale | tu visites une capitale, même celle de l'autre faction |
| Donjon | tu entres dans un donjon |
| Rare | tu abats un ennemi rare que tu as toi-même engagé, avec ton familier ou ton groupe |
| Palier | tu passes les niveaux 10, 20, 30, 40, 50 et 60 |

Chaque nouveau tampon est annoncé par un petit bandeau, jamais en combat. Le carnet (`/r2q carnet`) range tes tampons par onglet, avec la date et ton niveau, et montre ce qu'il te reste à découvrir : villages, capitales, donjons. Tout se gagne en jouant, sans paquet aléatoire.

## Kit de camp *(Forever)*

Le camping de Forever en fait un vrai lieu de préparation. Ready2Quest t'aide à en profiter :

- **avant de partir**, deux contrôles s'ajoutent au check : as-tu un **kit de feu de camp** ? ton **objet de camp** (meule, tente, chaise…) est-il prêt, ou encore en recharge (une heure, partagée) ?
- **au camp**, un petit compte à rebours jusqu'à la minute qui donne les buffs, puis « Buffs du camp actifs » ;
- **en quittant le camp**, un rappel du temps restant : « Buffs du camp : encore 42 min ».

Sur Classic Era, le module reste invisible : il n'y a pas de camping.

## Résumé de stuff

Quand tu équipes une nouvelle pièce, un petit cadre apparaît quelques secondes et montre ce qui change : Force, Agilité, Endurance, Intelligence, Esprit, armure, dégâts, DPS, vitesse, puissance d'attaque, critique. Une flèche indique le sens, la couleur dit si c'est mieux ou moins bien. Puis il s'efface tout seul.

## Stats du portrait

Survole ton portrait : un cadre affiche tes stats principales, **seulement celles qui comptent pour ta classe et ta spécialisation** (pas d'Esprit pour un guerrier). Un druide farouche voit d'autres stats en forme d'ours.

## Confort de jeu (QoL)

### La bonne récompense

À la fin d'une quête, quand tu dois choisir entre plusieurs objets :
- un liseré ambre et l'étiquette **« Pour toi »** désignent celui qui améliore le plus ton équipement. Le calcul suit les stats qui comptent pour ta classe et ta spé, et compare avec ce que tu portes ;
- un objet que ta classe porte mal (plaques pour un mage, bouclier pour un voleur…) n'est jamais conseillé ;
- si rien n'est une amélioration, l'étiquette **« À vendre »** va à la récompense qui se vend le plus cher ;
- l'infobulle de chaque choix indique l'écart avec ta pièce actuelle.

### Rythme de leveling

Survole ta barre d'expérience, ou tape `/r2q xp` :
- ton **XP par heure**, sur la session et sur la dernière demi-heure ;
- le **temps estimé** avant le niveau suivant, en ennemis tués ou en quêtes rendues ;
- ton **repos d'avance**, et combien tu en gagnerais en te déconnectant ici : « Déconnecte-toi à l'auberge : +15 % d'un niveau d'ici demain ».

Il se tait au niveau maximum.

### Sac plein

Ton sac est plein en pleine nature et un butin ne rentre pas ? Un petit cadre te propose **l'objet que tu perds le moins à jeter**, c'est-à-dire celui qui vaut le moins cher par case.
- Il ne propose jamais un objet de quête, ta pierre de foyer, tes réactifs de classe ou tes derniers vivres.
- **[Jeter]** le détruit **après confirmation**, toujours, puisque c'est irréversible. **[Autre]** passe au suivant. **[Garder toujours]** l'écarte pour de bon.
- `/r2q jeter` donne la proposition dans le chat. `/r2q garder` et `/r2q jeter-toujours` gèrent tes listes.

### Après la mort

À ta mort, puis une fois ton esprit libéré :
- **Courir** : la distance jusqu'à ton corps et le temps estimé à la vitesse du fantôme ;
- **Guérisseur des esprits** : les 25 % de durabilité perdus en plus, convertis en or, et la durée du mal de résurrection selon ton niveau ;
- et un conseil : « Cours : 180 m, ~21 s » ou « Guérisseur : moins long que la faiblesse ».

Il ne s'affiche pas en donjon ni en champ de bataille, où les règles sont différentes.

### Marchand

À l'ouverture d'un marchand :
- **vente des gris** : uniquement les objets de qualité grise qui ont une valeur, avec un récapitulatif (« 7 objet(s) gris vendu(s) : 1 po 23 pa ») ;
- **réparation** : si le marchand répare et que tu as l'or nécessaire.

Les deux sont actifs par défaut et se coupent dans les réglages. Ils fonctionnent même si le Check avant le départ est coupé.

---

## Réglages

`/r2q options`, ou un clic droit sur le bouton de la minicarte.

- **Général** : activer l'addon, et tout ce qui touche à l'affichage (bouton de minicarte, fenêtre ou chat, note sous laquelle la fenêtre s'ouvre, placement des cadres).
- **Modules** : chaque module a son interrupteur directement dans la liste de gauche, et sa page qui explique ce qu'il fait. Le Check avant le départ a ses sous-pages : Déclenchement, Zones sûres, Sacs & vivres, Équipement & perso, Buffs & métier. Résumé de stuff et Stats du portrait n'ont pas de réglage, mais leur page propose « Placer le cadre » (et « Afficher maintenant » pour le portrait).
- **QoL** : Confort de jeu, avec ses sous-pages Marchand, La bonne récompense, Rythme de leveling, Sac plein et Après la mort. Les sous-pages d'un module ne s'affichent que quand il est ouvert.

## Commandes

`/r2q`, `/sd` ou `/sacdepart`, au choix. `/r2q help` affiche l'aide complète.

| Commande | Effet |
|---|---|
| `/r2q` | lance le check maintenant |
| `/r2q options` | ouvre les réglages |
| `/r2q stats` | affiche tes stats principales |
| `/r2q move` | place les cadres à la souris |
| `/r2q safe` · `unsafe` | ajoute ou retire le village actuel |
| `/r2q safe list` | liste les lieux appris |
| `/r2q modules` | état des modules |
| `/r2q module depart off` | coupe un module (`depart`, `expedition`, `dungeon`, `camp`, `companion`, `journal`, `stuff`, `portrait`…) |
| `/r2q checks` · `check vivres off` | les contrôles du check avant le départ |
| `/r2q carnet` | ouvre ton carnet de voyage |
| `/r2q compagnon` | l'humeur de ton compagnon (`nom <nom>` pour le renommer) |
| `/r2q xp` | ton rythme de leveling |
| `/r2q jeter` | quoi jeter quand le sac est plein |
| `/r2q diag` | diagnostic, à joindre si tu signales un problème |

---

## Installation

1. Copie le dossier `Ready2Quest` dans `World of Warcraft/<client>/Interface/AddOns/`.
2. Vérifie le chemin : `…/Interface/AddOns/Ready2Quest/Ready2Quest.toc`, avec un seul niveau de dossier `Ready2Quest`.
3. Lance le jeu, ou tape `/reload`. La ligne « Ready2Quest — fichiers chargés » apparaît dans le chat.

**Tu avais l'ancienne version « Ready to Quest »** ?
- Supprime le dossier `AddOns/ReadyToQuest`.
- Pour garder tes réglages, renomme `WTF/Account/<compte>/SavedVariables/ReadyToQuest.lua` en `Ready2Quest.lua`.

**Clients** : Forever (1.60) et Classic Era (1.15). Le fichier `.toc` déclare aussi TBC et MoP Classic, sans garantie.

---

## Questions fréquentes

**La fenêtre ne s'ouvre pas quand je quitte le village.**
Si ta note est de 85 ou plus, c'est normal : c'est une ligne dans le chat. Pour avoir toujours la fenêtre, mets « Fenêtre sous la note » à 100 dans Général. Sinon, tape `/r2q diag` dans le village : la ligne « zone sûre » doit indiquer `true`.

**Un village n'est pas reconnu.**
Tape `/r2q safe` dans le village, ou laisse l'addon l'apprendre : un aubergiste, une boîte aux lettres ou un maître de vol suffisent.

**Un endroit est considéré comme sûr à tort.**
Réglages, page **Zones sûres**, bouton **Retirer**. Ou `/r2q unsafe` sur place.

**Un buff m'est réclamé alors que je ne le veux plus.**
Réglages, page **Buffs & métier** : clic sur le buff pour le couper, ou **Retirer**.

**Je ne veux pas que l'addon vende mes gris.**
Réglages, **QoL** › **Marchand** › « Vendre les gris ».

---

## Pour les développeurs

- [Notes techniques et historique des versions](docs/TECHNIQUE.md) : choix d'API, compatibilité Era et Forever, détail de chaque version.
- Tests hors jeu, sur un client WoW simulé : `python3 tests/run_tests.py` (nécessite le paquet `lupa`).
- Base des zones sûres : `tools/gen_hubs.py` régénère `Hubs.lua` à partir des données du client publiées sur [wago.tools](https://wago.tools).
- Police des titres : Alegreya (licence OFL, voir `Fonts/Alegreya-OFL.txt`).
