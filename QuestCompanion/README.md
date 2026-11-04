# QuestCompanion

**Un compagnon de route et son carnet de voyage.** Une petite créature voyage avec toi, te parle et grandit avec toi. Son carnet suit la complétion de chaque zone, ouvre des coffres d'objets cosmétiques et la fait évoluer.

Pour **World of Warcraft Forever** et **Classic Era**. Interface en français et en anglais.

> **Autonome.** QuestCompanion fonctionne seul : sa commande `/qc`, son panneau de réglages, son bouton de minicarte. Il va très bien avec [Ready2Quest](../Ready2Quest/README.md), sans en avoir besoin : si Ready2Quest est là, le compagnon réagit en plus à tes départs et retours en ville.

---

## Compagnon de route

Une petite créature du jeu (un dragonnet pour commencer) t'accompagne dans un coin de l'écran. Le compagnon et le **carnet de voyage** forment un seul module : le carnet fait évoluer la créature.

## Elle te parle

De courtes bulles, jamais en combat, avec plusieurs phrases pour chaque situation :
- quand tu **abats un monstre**, **manges**, **bois** ou te **reposes** ;
- quand tu **parles à quelqu'un** : elle donne son avis sur le marchand, l'aubergiste, le maître de vol, le banquier, l'entraîneur ou le donneur de quêtes, et commente les créatures que tu cibles ;
- quand tu quittes la ville sans vivres, meurs, découvres une zone ou t'assois au feu de camp ;
- de temps en temps, une **astuce** de jeu, ou une petite **conversation** de quelques bulles, comme si elle te parlait.

Elle dit aussi **ce dont elle a besoin** : « J'ai faim… », « On explore ? », « Encore 2 zones et j'aurai : Dragonnet cramoisi ! ».

## Elle veille sur toi en route

Hors d'un lieu sûr, elle te prévient de ce qui compte, une fois par sortie (et de nouveau si ça empire), jamais en combat :
- un **élite ou un rare** hostile, au moins 2 niveaux au-dessus de toi (ta cible, ce que tu survoles, les barres de vie), hors donjon ;
- ta **vie basse** à la fin d'un combat ;
- tes **munitions** basses, presque à sec, ou rangées dans le sac sans être équipées (chasseur) ;
- tes **vivres** bas ;
- ton **équipement** qui s'abîme (sous 25 %, puis sous 10 %) ;
- tes **sacs** presque pleins ;
- toutes tes **quêtes** prêtes à rendre ;
- ta **pierre de foyer** de nouveau prête alors que tu es chargé.

Avec Ready2Quest, elle suit les mêmes seuils que son check (place dans les sacs, vivres, durabilité) et la même idée de « lieu sûr ». Elle parle plus ou moins selon la réglette **Bavardage** : au cran Discret, seuls l'élite, la vie, les munitions et les vivres passent.

## Elle t'aide en groupe

Avec ce que ton jeu sait déjà de tes compagnons d'armes (niveau, classe, position, état) :
- quand le groupe est formé : **pas de soigneur** (prêtre, druide, chaman, paladin), ou un bel équipage au complet ;
- devant ou dans un **donjon** : le membre le plus bas par rapport au donjon, ou « tout le monde a le niveau » ;
- un membre **resté en arrière** (hors de vue plus d'1 min 30, hors combat et hors lieu sûr) ou **encore ailleurs** quand tu es au donjon (« Il manque Thrall, encore à Orgrimmar ») ;
- les **morts** (et celle du soigneur : prudence !) et les **déconnexions**.

Rien en raid, rien pendant un vol. Composition, donjon et retards sont des conseils (dès le cran Calme) ; morts et déconnexions, des réactions (cran Normal).

## Comment s'en occuper

Elle a quatre envies : **faim**, **énergie**, **moral** et **curiosité**. Elles se remplissent quand tu manges, te reposes, rends une quête ou explores. Clique dessus pour lui faire une caresse, **clic droit** pour ouvrir son carnet sur les objectifs. Au premier lancement, un **tutoriel** en quelques bulles explique tout ça (à revoir avec `/qc compagnon tuto`).

- **Elle grandit avec toi** : Nouveau-né, Jeune (niveau 10), Aguerri (20), Vaillant (40) et Légendaire (60). Ton niveau ouvre l'étape, mais elle n'évolue que si elle est **heureuse** : ses quatre envies au moins à 70 %. Sinon elle te dit qu'elle est prête et ce qui lui manque, et elle attend. Petite fête à chaque étape.
- **Elle ne t'en veut jamais** : elle ne meurt pas, ne régresse pas et ne tombe pas malade. Après une longue absence, elle est juste un peu ensommeillée : « Tu m'as manqué ! »
- **Elle se personnalise** avec des **apparences** (dragonnets, rainette, chatons, lapin, tortue, ara, serpent, chouette, feu follet, dragon féerique), des **ornements**, des **cadres** (cuivre, chêne, argent, givre, runique, gangrené, or ciselé) et des **fonds** (parchemin, sous-bois, crépuscule, givre, marbre, braise, voûte étoilée, velours doré).
- **Ils se gagnent dans les coffres de zone** : une zone terminée à 100 % ouvre un coffre, et tu **choisis** un objet de son palier (zones 1-19, 20-39 ou 40-60). Plus la zone est haute, plus l'objet est beau. Quand tu possèdes tout un palier, la zone devient dorée. `/qc coffre` ouvre un coffre en attente.

Tu peux la renommer avec `/qc compagnon nom Pépite`.

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

Chaque nouveau tampon est annoncé par un petit bandeau, jamais en combat. Tout se gagne en jouant, sans paquet aléatoire.

Le carnet (`/qc`, le bouton de minicarte, ou clic droit sur la créature) a deux parties :
- **Complétion** : choisis une zone dans la liste (celle où tu es, par défaut) et vois son pourcentage, son coffre et, par onglet, ce qui est fait et ce qui reste :
  - **Exploration** : les villages de la zone ;
  - **Combat** : le bestiaire et les nommés ;
  - **Métiers** : les ressources de ta compétence à récolter ;
  - **Quêtes** : les quêtes de la zone que ton personnage peut faire (faction, race, classe), faites et à faire. Elles comptent dans les 100 %. Aucun addon requis, sur Era comme sur Forever.
- **Suivre à l'écran** : une case par zone. Cochée, les objectifs de la zone s'affichent dans le bloc « Carnet » en jeu. La zone où tu es est suivie d'office (décoche-la pour la masquer) ; coche d'autres zones pour garder un œil sur elles.
- **Évolution** : l'étape de ta créature, la prochaine, ses envies, comment elle évolue, tes coffres à ouvrir, ta collection et ton parcours (zones, capitales, donjons, rares, paliers). Survole une envie (faim, énergie, moral, curiosité) pour savoir ce qui la remplit.

## Objectifs

Le carnet fixe des **objectifs** : prochaine étape de la créature, prochaine apparence ou ornement, villages de la zone, capitales, donjons de ton niveau, prochain palier. Les plus proches s'affichent à l'écran sous le suivi des quêtes, dans un bloc **Carnet** : l'objectif le plus proche mis en avant avec sa barre, puis trois autres plus discrets.

- **Complétion de zone** : chaque zone a son pourcentage, affiché dans la partie **Complétion** du carnet et, pour la zone où tu es, dans le bloc à l'écran. Il mélange à parts égales :
  - les **villages** visités ;
  - le **bestiaire** : les espèces que tu as croisées et abattues (on compte des espèces différentes, pas un nombre de victimes) ;
  - les **nommés** (élites, rares, boss) croisés et abattus ;
  - la **récolte**, si tu es herboriste, mineur ou dépeceur : les herbes, minerais et cuirs de ta compétence que tu as déjà récoltés dans la zone.

  Chaque zone arrive **préremplie**, sur Era comme sur Forever (îles et zones propres à Forever comprises) : ses créatures (nom, niveau, rang), les herbes et minerais qui y poussent et ses quêtes sont connus dès ta première visite. Ce qui manque à ces données (nouveautés récentes de Forever) se remplit en jouant.
- **Survole un objectif** pour savoir quoi faire : les villages de la zone qu'il te reste à visiter, les capitales manquantes, les donjons de ton niveau avec leur tranche, l'XP avant le prochain niveau.
- **Clic** : ouvre le carnet. **Clic droit** : masque l'objectif.
- Le bloc se replie d'un clic sur son titre, se déplace en le glissant et se cache en combat (réglable dans les options du compagnon, page Carnet).

---

## Installation

1. Copie le dossier `QuestCompanion` dans `World of Warcraft/<client>/Interface/AddOns/` : `…/Interface/AddOns/QuestCompanion/QuestCompanion.toc`.
2. Lance le jeu, ou tape `/reload`. La ligne « QuestCompanion — fichiers chargés » apparaît dans le chat.

**Tu avais le compagnon avec Ready2Quest 1.25 ou avant** ? Mets aussi Ready2Quest à jour (1.26.0 ou plus) et garde-le activé à la première connexion : ta créature, ton carnet, tes coffres et leurs réglages sont repris de sa sauvegarde, pour tous tes personnages, puis rangés dans celle de QuestCompanion (`QuestCompanion.lua` dans `SavedVariables`). Avec un Ready2Quest 1.25, qui contient encore le compagnon, QuestCompanion reste en retrait et te demande de le mettre à jour.

## Réglages

`/qc options`, ou un clic droit sur le bouton de minicarte au dragonnet.
- **Général** : activer l'addon, le bouton de minicarte et sa position.
- **Compagnon de route** : la réglette **Bavardage** (Muet, Discret, Calme, Normal, Bavard : la phrase sous la réglette dit ce que fait chaque cran, et il te le confirme lui-même), apparence, cadre, fond, ornements, et la sous-page **Carnet** (bandeau, chat, suivi à l'écran).

## Commandes

`/qc` ou `/questcompanion`, au choix. `/qc help` affiche l'aide complète.

| Commande | Effet |
|---|---|
| `/qc` | ouvre ton carnet de voyage (comme `/qc carnet`) |
| `/qc options` | ouvre les réglages |
| `/qc compagnon` | l'humeur de ton compagnon (`nom <nom>` pour le renommer, `tuto` pour revoir le tutoriel) |
| `/qc coffre` | ouvre un coffre de zone en attente |
| `/qc module compagnon off` | coupe le compagnon et son carnet |
| `/qc minimap [on\|off]` | le bouton de minicarte |
| `/qc reset` | remet les réglages à zéro, sans toucher à ta créature ni à ton carnet |
| `/qc diag` | diagnostic, à joindre si tu signales un problème |

## Données et licence

QuestCompanion est un logiciel libre sous licence **GPL-3.0** (voir `LICENSE`). Les données de zones (créatures, récolte, quêtes) sont générées depuis la base de [Questie](https://github.com/Questie/QuestieDB), elle aussi sous GPL-3.0, par `tools/gen_zone_data.py` : voir `NOTICE.md`.
