# Journal des modifications

## 1.38.0 — Aide au combat

- **Une section Combat** dans les réglages : la portée d'aggro y passe, avec quatre aides, chacune avec son interrupteur (effet au prochain /reload) :
  - **Portée des sorts** : une coche verte ou une croix rouge au-dessus de ta cible (aussi en combat) ; les icônes des barres d'action se grisent hors de portée.
  - **DoT mortels** : sur la barre de vie de la cible, ce que tes DoT vont encore infliger ; un crâne quand ils suffisent.
  - **Prédiction des sorts** : pendant l'incantation, les dégâts attendus et une icône si le sort tue.
  - **Chiffres des barres** : les dégâts ou soins de chaque sort sur son bouton, avec ta puissance des sorts et tes talents.
- Le moteur vient de **DoesItDiePlus** (Ironship) et **Does It Die** (Joe Greive), sous licence libre, avec leur crédit. Si l'un des deux est installé, Ready2Quest s'efface (rien en double ; la portée d'aggro reste). Tous les réglages sont dans la fenêtre de Ready2Quest (Réglages › Combat) ; `/r2q combat` y mène.
- **« +N » devient une alerte multi-aggro** : le jeu cache la position des monstres à l'écran (celle des barres de nom comme celle d'un cadre accroché à elles), donc leur direction. Plus de chiffre : le triangle d'alerte du jeu à droite de ta cible quand d'autres monstres de la même sorte sont à une distance proche de la sienne. Réglage « Alerte multi-aggro ».
- **Un seul bouton « Recharger l'interface »**, en bas des réglages, à gauche de Terminé : il apparaît quand un interrupteur du Combat l'attend.
- **Une seule icône au-dessus du monstre** : le crâne (tes DoT suffisent) ou l'arme (DoT + un coup) prend la place de la coche de portée ; hors de portée, la croix rouge revient. Réglage sur la page DoT mortels (actif), qui explique aussi les deux icônes.
- **Diagnostic** : `/r2q diag` ne signale plus à tort un module « Stats » manquant (retiré en 1.37.0).
- **`/r2q diag` explique les paliers manquants** : une ligne par barre de nom (sorte, niveaux, portée, distance mesurée, verdict) et pourquoi rien ne s'affiche (niveau illisible, aucune mesure, pas hostile).
- **Portée d'aggro plus juste pour guerriers, chasseurs et druides** : les sorts « au prochain coup » (Frappe héroïque, Enchaînement, Attaque du raptor, Mutiler) ne servent plus de règle ; ils répondaient « à portée » à 30 m.

*English:* a Combat section in the settings: the aggro range moves there, with four helpers, each with its own switch (takes effect at the next /reload): spell range (a green check or a red cross above your target, in combat too; action bar icons grey out when out of range), lethal DoTs (what your DoTs will still deal, on the target's health bar; a skull when it is enough), spell prediction (the expected damage while you cast, an icon if it kills), action bar numbers (each spell's damage or healing on its button, with your spell power and talents). The engine comes from DoesItDiePlus (Ironship) and Does It Die (Joe Greive), free software, credited; if one of them is installed, Ready2Quest steps aside (nothing twice; the aggro range stays). Every setting lives in Ready2Quest's window (Settings › Combat); `/r2q combat` takes you there. "+N" becomes a multi-aggro warning: the game hides where monsters are on screen (nameplates and frames pinned to them), so their direction; no number any more, the game's warning triangle right of your target when other monsters of the same kind are at a similar distance ("Multi-aggro warning" setting). Sharper aggro range for warriors, hunters and druids: "next swing" spells (Heroic Strike, Cleave, Raptor Strike, Maul) are no longer used as a range check; they answered "in range" at 30 yd.

## 1.37.1

- **Voisins qui suivent (+N)** : hors combat, à droite de la barre de nom de ta cible, « +2 » (ambre ; rouge à partir de 3) dit combien de monstres de la même sorte sont assez près pour venir l'aider si tu l'attaques. C'est une estimation (le jeu ne donne pas la position des monstres : on la déduit de la distance mesurée et de la place des barres de nom à l'écran), à affiner avec vos retours ; `/r2q diag` montre le compte et le rayon utilisé. Réglage « Voisins qui suivent (+N) », page Portée d'aggro (actif).
- **« Tout apprendre » apprend tout d'un clic** : il s'arrêtait souvent après 2 ou 3 sorts (le jeu met à jour ton or avant la liste du maître, et la série croyait à un refus). Elle avance maintenant au rythme de la liste.
- **Le nom du monstre pour QuestCompanion** : quand la portée d'aggro montre sa marque rouge, le compagnon de QuestCompanion (3.2.0) peut crier le nom du monstre qui va t'aggro.

*English:* "Learn all" now learns everything in one click: it often stopped after 2 or 3 spells (the game updates your gold before the trainer's list, and the series took it for a refusal); it now follows the list. Neighbours that follow (+N): out of combat, to the right of your target's nameplate, "+2" (amber; red from 3) tells how many monsters of the same kind are close enough to come and help it if you attack. It is an estimate (the game does not give monster positions: we infer them from the measured distance and where the nameplates sit on screen), to be tuned with your feedback; `/r2q diag` shows the count and the radius used. Setting "Neighbours that follow (+N)", Aggro range page (on). The monster's name for QuestCompanion: when the aggro range shows its red mark, the QuestCompanion companion (3.2.0) can shout the name of the monster about to aggro you.

## 1.37.0 — Deux modules retirés

- **Résumé de stuff et Stats du portrait retirés** : le petit cadre qui montrait les stats gagnées ou perdues en changeant d'objet, et le panneau de stats au survol du portrait, disparaissent, avec leurs pages de réglages et leurs commandes (`/r2q stuff`, `/r2q stats`, `/r2q toast`, `/r2q portrait`). Ils servaient peu ; Ready2Quest n'écoute plus les changements d'équipement ni les stats du joueur. Leurs anciens réglages sont effacés de la sauvegarde.
- **Ce qui reste** : la bonne récompense de quête garde ses priorités par classe et par spé. « Déplacer les cadres » place désormais l'icône d'annonce, et `/r2q resetpos` la remet à sa place.

*English:* Gear summary and Portrait stats are removed: the small frame showing stats gained or lost when you swap an item, and the stats panel on portrait hover, are gone, along with their settings pages and commands (`/r2q stuff`, `/r2q stats`, `/r2q toast`, `/r2q portrait`). They were little used; Ready2Quest no longer listens to gear changes or player stats. Their old settings are cleared from your saved data. What stays: the best quest reward keeps its per-class and per-spec priorities. "Move the frames" now places the notice icon, and `/r2q resetpos` puts it back in place.

## 1.36.0 — Portée d'aggro plus juste, en paliers

- **Portée d'aggro : des paliers sous la barre de nom**, à la place du trait. Six rectangles fins, deux rouges, trois ambre, un vert, d'autant plus allumés que tu es loin de la portée du monstre, avec la distance dessous (« ~17 m », ou la fourchette « 15-20 m »). C'est le nouveau style par défaut, pour tout le monde ; la pastille reste au choix (Options › Portée d'aggro › Marque).
- **Portée de base plus juste** : 15 m à niveau égal au lieu de 20 (mesurée autour de 14,6 m sur Forever). Les alertes ne s'allument plus 10 m trop tôt.
- **Des mesures plus fines** : tes sorts offensifs servent aussi de règle (une portée par sort, de 5 à 60 m), en plus des objets ; entre deux paliers, la distance est estimée d'après ta course (« ~17 m »).
- **La portée apprise en jouant** : quand un monstre t'attaque alors que tu n'as rien fait, seul, la distance à laquelle il t'a repéré est retenue (par monstre, par type, en tout ; 20 valeurs au plus). Elle remplace l'estimation, avec une étoile dans l'infobulle (« Aggro ~13* m »). Réglage « Apprendre la portée en jouant » (activé) ; le nombre d'échantillons dans /r2q diag.

*English:* aggro range: steps under the nameplate replace the line — six thin rectangles (two red, three amber, one green) that light up the further you are, with the distance below ("~17 yd" or "15-20 yd"); this is the new default for everyone; the dot stays available. Base range is now 15 yd at equal level instead of 20 (measured around 14.6 on Forever), so warnings no longer fire 10 yd early. Finer measurement: your offensive spells act as extra range checks (one per range, 5 to 60 yd), and between two steps the distance is estimated from your movement. Range learned as you play: when a monster attacks you while you did nothing, solo, the distance it noticed you from is kept (per monster, per type, overall; up to 20 values) and replaces the estimate, marked with a star in the tooltip. Setting "Learn the range as you play" (on); sample count in /r2q diag.

## 1.35.0 — Thème forgé, Groupe prêt, Tout apprendre

- **Thème forgé** : toutes les fenêtres de Ready2Quest changent d'allure. Cadre d'orfèvre doré, médaillon du logo au coin, boutons en relief dont la couleur dit le geste (or : action principale ; vert : ajouter ; rouge : jeter ou retirer ; bleu arcane : action neutre), champs et barres en creux, titres dans la police du jeu ; ce que tu choisis s'éclaire en bleu. Actif par défaut ; « Style de l'interface » (page Général) ou /r2q style azeroth|sobre pour garder l'aspect d'avant.
- **Nouveau logo** : un écu coché surmonté du point d'exclamation doré des quêtes, dans un médaillon d'or.
- **Groupe prêt** : devant un donjon, en groupe, la fiche « Avant le donjon » montre qui est sur place (dans le donjon, à l'entrée, en route) et qui est prêt (durabilité, réparation, vivres, potions, foyer), pour les membres qui ont aussi Ready2Quest. Rien dans le chat du groupe ; /r2q groupe te donne le bilan. Réglage page Avant le donjon (actif).
- **Tout apprendre** : chez un maître de classe ou de métier, un bouton avec le total à payer apprend tout ce qui est disponible ; s'il te manque de l'or, il est grisé et son infobulle dit combien. Réglage page Rangs de sorts (actif).
- **Nouveaux sorts** : les Rangs de sorts proposent aussi les sorts actifs appris à partir de maintenant qui ne sont sur aucune de tes barres. **Placer** le pose dans la première case vide (ou sur ton curseur) ; **Ignorer** ne le propose plus (liste des ignorés page Rangs de sorts). Ni passifs, ni métiers, ni montures, jamais en combat.
- **Butin rapide** (coupé par défaut, page Place au butin) : avec le butin automatique du jeu, tout est ramassé d'un coup. Ce qui ne rentre pas reste dans la fenêtre ; si SpeedyAutoLoot ou le butin rapide de Leatrix Plus est actif, Ready2Quest lui laisse la main.
- **Check et combat** : dans le check, un clic sur Sacs, Quêtes ou Rangs de sorts ouvre ce qui va avec. En combat, l'icône d'annonce, les rapports et le bandeau Sac plein se rangent, puis reviennent. Une mise à jour des Rangs de sorts cliquée en combat n'est plus perdue : elle se fait à la fin du combat.
- **Si le jeu refuse une action** : une ligne le dit dans le chat (une fois par session) et `/r2q diag` en donne le détail.

*English:* Forged theme: every Ready2Quest window gets a new look, with a golden filigree frame, the logo medallion in the corner, bevelled buttons whose colour tells the action (gold: main action; green: add; red: discard or remove; arcane blue: neutral action), inset fields and bars, titles in the game font; what you select lights up in blue. On by default; "Interface style" (General page) or /r2q style azeroth|sobre keeps the previous look. New logo: a checked shield crowned with the golden quest exclamation mark, in a gold medallion. Group ready: at a dungeon, in a group, the "Before the dungeon" sheet shows who is there (inside, at the entrance, on the way) and who is ready (durability, repairs, food, potions, hearthstone), for members who also run Ready2Quest. Nothing in group chat; /r2q groupe gives you the summary. Setting on the Before the dungeon page (on). Learn all: at a class or profession trainer, a button showing the total cost learns everything available; if you are short on gold, it is greyed out and its tooltip says how much is missing. Setting on the Spell ranks page (on). New spells: Spell ranks also offers active spells learned from now on that are on none of your bars. **Place** puts one in the first empty slot (or on your cursor); **Ignore** stops offering it (ignored list on the Spell ranks page). No passives, professions or mounts, never in combat. Fast loot (off by default, Loot room page): with the game's auto loot, everything is picked up at once. What does not fit stays in the loot window; when SpeedyAutoLoot or Leatrix Plus fast loot is active, Ready2Quest stands aside. Check and combat: in the check, clicking Bags, Quests or Spell ranks opens the matching window. In combat, the notice icon, the reports and the Full bags banner step aside, then come back. A Spell ranks update clicked in combat is no longer lost: it happens when the fight ends. If the game refuses an action, one chat line says so (once per session) and `/r2q diag` gives the details.

## 1.34.0

- **Objets favoris** : Alt+clic sur un objet de tes sacs le met en favori (toutes ses copies), ou l'en retire, aussi dans les sacs d'un autre addon (Baganator…) ; l'infobulle d'un objet de tes sacs rappelle le raccourci (« Alt+clic : ajouter aux favoris » / « retirer des favoris ») ; le raccourci se choisit dans Sac plein (Alt+clic, Ctrl+Alt+clic, Maj+Alt+clic, Alt+clic droit, Ctrl+Alt+clic droit, ou désactivé), et `/r2q favori [lien]` fait de même. Un favori porte un petit cadenas dans les sacs du jeu (et dans Baganator) et une ligne « Favori : protégé de la vente » dans son infobulle.
- **Protégés de la vente** : jamais vendus avec les gris, jamais proposés par Sac plein ni Place au butin. Chez un marchand, le clic droit sur un favori demande « Vendre ce favori ? » avant de vendre, dans les sacs du jeu comme dans ceux d'un addon (Baganator…) ; s'il part quand même (glissé sur le marchand), il est racheté tout seul (réglage « Rachat automatique d'un favori vendu », actif par défaut), sinon on te propose de le racheter.
- **La liste « Toujours garder » devient « Favoris »** : tout ce qu'elle contenait est repris, rien n'est perdu. « Ignorer » dans Place au butin et le bouton « Favori » de Sac plein y ajoutent l'objet.
- **Plus de fenêtres l'une sur l'autre** : Place au butin et Sac plein se mettent à côté de « Tout capturer » ou de la carte de capture de QuestCompanion si elles sont déjà ouvertes (et inversement). Une fenêtre que tu as déplacée n'est jamais bougée.
- **Infobulles** : survoler l'objet proposé par Sac plein, ou le butin bloqué de Place au butin, montre l'infobulle du jeu (Maj+clic pour le lier).

- **Quest Companion dans les réglages** (page Général) : ce qu'il fait, et s'il est installé : sa version et « Ouvrir le carnet » ; désactivé, comment l'activer (ou « Activer » pour ce personnage) ; absent, ses liens CurseForge et Wago à copier.

*English:* favorite items — Alt+click an item in your bags to mark it (every copy) as a favorite, or unmark it, in a bag addon's window too (Baganator…), and the tooltip of an item in your bags reminds you of the shortcut ("Alt+click: add to favorites" / "remove from favorites"); the shortcut is set on the Full bags page (Alt+click, Ctrl+Alt+click, Shift+Alt+click, Alt+right-click, Ctrl+Alt+right-click, or disabled), and `/r2q favori [link]` does the same. Favorites show a small padlock in the game's bags and a "Favorite: protected from selling" tooltip line; they are never sold with the grays nor suggested by Full bags or Loot room; at a merchant, right-clicking a favorite asks "Sell this favorite?" first, in the game's bags and in a bag addon's (Baganator…), and if one gets sold anyway (dragged onto the merchant) it is bought back automatically ("Buy back a sold favorite automatically" setting, on by default), otherwise you are offered to buy it back. The "Always keep" list becomes "Favorites", with all its items kept; Loot room's "Ignore" and Full bags' "Favorite" button add to it. Loot room and Full bags now open beside QuestCompanion's "Capture all" window or capture card instead of on top of them (and the other way round); a window you moved is never moved. Hovering the item suggested by Full bags, or the blocked loot in Loot room, shows the game tooltip (Shift+click to link it). Quest Companion on the General settings page: what it does and, if installed, its version and "Open the journal"; disabled, how to enable it (or "Enable" for this character); missing, its CurseForge and Wago links to copy.

## 1.33.3

- **Buffs avant le départ, avec du discernement** : les buffs de situation (Respiration aquatique, Marche sur l'eau, résistances, Gardien de peur…) ne sont plus réclamés ; Fureur vertueuse seulement si ton rôle est tank ; Intelligence des arcanes et Esprit divin plus réclamés au guerrier ni au voleur. Nouveau réglage « Ton rôle » (Automatique, tank, soigneur, dégâts) dans les réglages des buffs ; tu peux toujours activer ou couper chaque buff à la main.
- **Camp** : plus de décompte « Au camp : buffs dans… » à un feu de camp de ville ou de village.

*English:* smarter pre-departure buffs — situational buffs (Water Breathing, Water Walking, resistances, Fear Ward…) are no longer asked; Righteous Fury only when your role is tank; Arcane Intellect and Divine Spirit no longer asked of warriors and rogues; new "Your role" setting (Automatic, tank, healer, damage) on the buffs page, and every buff can still be turned on or off by hand; no more camp countdown at a town or village campfire.

## 1.33.2

- **Sac plein** : les objets mis de côté avec « Ignorer » dans Place au butin s'affichaient « true » dans la liste « Toujours garder » ; ils s'affichent maintenant par leur nom.

*English:* items set aside with "Ignore" in Loot room showed as "true" in the Full bags "Always keep" list; they now show their name.

## 1.33.1

- **Aggro** : le style « anneau » est retiré ; il reste la pastille (par défaut) et le trait. Si tu avais choisi l'anneau, la pastille le remplace.
- **Plus léger** : flèches du bilan et losanges viennent du jeu (environ 195 Ko de moins à télécharger).

*English:* the "ring" aggro mark style is gone — diamond (default) and line remain, ring users switch to the diamond; stats arrows and diamonds now use the game's art (≈ 195 KB smaller download).

## 1.33.0

- **Place au butin** ne propose plus les outils de métier, les objets et kits de camp, les composants de tes métiers, les recettes, les caisses à ouvrir ni les bandages ; la liste défile à la molette.
- **Buffs** : seuls les buffs de classe (toi ou ton groupe) sont réclamés par défaut ; parchemins, élixirs et postures (Fureur vertueuse, formes, aspects…) sont à activer dans la liste des buffs, qui dit pourquoi chacun est réclamé ou non.
- **Lisibilité** : « niv. 18 à 20 » au lieu d'une flèche illisible (plus de carré vide).
- **Plus léger** : camp, aggro, portrait, sortie de zone sûre et sorts sur une seule horloge.

*English:* "Room for loot" no longer offers profession tools, camp objects and kits, reagents for your professions, recipes, openable crates or bandages, and the list scrolls; only class buffs (yours or your group's) are asked by default — scrolls, elixirs and stances (Righteous Fury, forms, aspects…) can be turned on in the buff list; "lvl 18 to 20" instead of an unreadable arrow; periodic checks on a single clock.

## 1.32.1

- **Plus léger** : la présence d'un feu de camp n'est plus lue qu'une fois par image au lieu de trois.

*English:* campfire presence is read once per frame instead of three times.

## 1.32.0

- **Avant le départ** met les manques en avant : les points en ordre sont repliés en une ligne (« Afficher » pour les voir), pluriels accordés, vraie flèche, durabilité et réparation fusionnées, « aucun repos d'avance » au lieu de « sans objet ». Le bouton « Partir à l'aventure » est lisible.
- **Réglages** : survol, appui et état désactivé visibles ; un module coupé estompe ses réglages et propose « Rallumer ».
- **Aux couleurs du jeu** : cases à cocher, losanges, chevrons, roue des réglages, anneau d'aggro et flèches du bilan viennent du client (nos images restent en secours).
- **Avec QuestCompanion** : le socle commun n'est chargé qu'une fois (environ 300 Ko de moins), et une seule alerte rouge d'aggro à la fois.

*English:* "Before you go" puts missing items first (checks in order folded, proper plurals, real arrow, merged durability/repair, "no rested XP"); readable "Set out" button; visible hover/press/disabled states, a disabled module dims its settings and offers "Turn on"; checkboxes, diamonds, chevrons, gear, aggro ring and stats arrows use the game's own art (our images as fallback); with QuestCompanion the shared core loads once (≈ 300 KB saved) and only one red aggro alert shows at a time.

## 1.31.0

- **Aggro : nouveau mode « Danger seul », par défaut.** Sans toucher au clavier, seule la marque rouge s'affiche quand un monstre est sur le point de t'aggro ; Maj montre tout. Si tu étais réglé sur Maj, tu passes une fois à « Danger seul » (Maj reste disponible dans les réglages). Les barres de nom ennemies doivent être affichées (touche V).
- **Le rouge s'allume plus tôt** : on prévient dès que tu peux être à moins de 5 m de la portée, d'après les distances que le jeu sait mesurer sur Forever. `/r2q diag` liste les paliers de distance qui répondent.
- **Buffs** : un buff personnel d'une autre classe (Feu intérieur, armures, boucliers…) ou un sort non appris n'est plus réclamé ; les réglages disent pourquoi un buff n'est pas réclamé ici.
- **Avant le départ** : plus de texte coupé, le survol montre le texte entier et la liste complète des buffs manquants ; « Rangs de sorts » remplace « Sorts des barres à jour ».
- **Plus léger** : auras et statistiques du joueur seul écoutées, lieu sûr gardé sans recalcul.

*English:* aggro: new default "Danger only" mode — without any key only the red mark shows when a monster is about to aggro you, Shift shows everything (Shift users are moved once; enemy nameplates must be on, V); red lights up earlier, based on the distances the game can measure on Forever, and `/r2q diag` lists the answering range steps; another class's self-buffs and unlearned spells are no longer asked, the settings say why; before leaving: no more cut text, hover shows full text and every missing buff; lighter event handling.

## 1.30.1

- **Buffs selon la classe qui les donne** : une table des buffs de chaque classe (paladin, prêtre, mage, druide, guerrier, démoniste, chaman, chasseur) ; un buff de classe n'est réclamé que si ta classe ou une classe de ton groupe le pose. Les autres (élixirs, parchemins, objets) seulement sur le personnage qui les a eus : un autre personnage ne se voit plus réclamer la bénédiction de ton paladin.

*English:* buffs are requested by the class that casts them (per-class table; class buffs only if your class or a group member's class can cast them; other buffs only on the character that had them).

## 1.30.0

- **Buffs réclamés seulement si on peut te les donner** : un buff appris d'un autre joueur (un cri de guerrier reçu en groupe) n'est réclamé que si sa classe est dans ton groupe ; ceux que tu poses toi-même le sont toujours.
- **Aggro en avertissement** : la marque passe au rouge 5 m avant la portée estimée (« danger, trop près »), à l'ambre jusqu'à 12 m au-delà.
- **Métiers au plafond** : nouveau contrôle du Check avant le départ quand un métier est bloqué à 75, 150 ou 225 (passe voir ton entraîneur). Merci Lex !
- **Quêtes de voyage** (« va voir untel », sans objectif) : elles ne comptent plus comme « prêtes à rendre » dans le Check. Merci Lex !

*English:* buffs are only requested when you or your group can cast them; the aggro marker turns red 5 yards before the estimated range ("danger, too close"); new pre-departure check for professions stuck at their rank cap; travel quests (no objectives) no longer count as "ready to turn in".

## 1.29.6

- **Bandeau du camp plus clair** : une fois le délai passé sans buff, il dit « Buffs du feu de camp : assieds-toi ou fabrique ici » au lieu d'un « Au camp : assieds-toi ou fabrique » peu parlant, avec l'icône du feu de camp. Bandeau un peu plus large.

## 1.29.5

- **Ménage** : des textes jamais affichés (anciennes sections de réglages, emplacements d'équipement) et deux aides inutilisées sont retirés. Socle commun : les textes peuvent venir d'une source calculée (utilisé par Quest Companion pour alléger ses répliques). Rien ne change à l'écran ni dans ta sauvegarde.

*English:* cleanup: unused texts (old settings sections, equipment slot names) and two unused helpers are removed. Shared core: texts can come from a computed source (used by Quest Companion to lighten its companion lines). Nothing changes on screen or in your saved data.

## 1.29.4

- **Roue crantée** dans l'en-tête de la fenêtre « Avant le départ », à côté de la flèche : elle ouvre les réglages de Ready2Quest.

## 1.29.3

- **Plus léger** : seule la langue de ton client reste en mémoire (0,77 Mo au lieu de 0,89 Mo).
- **Buffs qui se remplacent** : une seule bénédiction de paladin, une armure de mage, une peau de démoniste, un bouclier de chaman, un cri de guerrier, un aspect de chasseur, un feu intérieur, une forme de druide… Si l'un est actif, les autres ne sont plus « manquants » ; sinon seul le dernier que tu avais est réclamé.

## 1.29.2

- **Portée d'aggro** : la pastille est plus grosse (16 px) et rentrée vers le nom, pour la voir d'un coup d'œil.

## 1.29.1

- **Portée d'aggro, marque plus discrète** : le grand anneau autour des barres de nom laisse la place, par défaut, à une **pastille** (un petit losange à gauche de la barre, rouge / ambre / vert, qui bat quand tu es dans le rayon). Réglage **Marque** : pastille, **trait** sous la barre, ou l'**anneau** d'avant.
- **Listes déroulantes** : une seule ouverte à la fois, ouvrir une liste referme la voisine (elles se recouvraient).

## 1.29.0

- **Nouveau module : portée d'aggro.** Maintiens Maj (réglable : Ctrl, Alt ou toujours) hors combat : un anneau entoure la barre de nom de chaque monstre hostile (rouge : dans son rayon d'aggro estimé, ambre : tout près, vert : tranquille), et son infobulle donne le rayon estimé, ta distance et le verdict. Rayon : 20 m à niveau égal, ±1 m par niveau d'écart (5 à 45 m). Les monstres neutres sont signalés sans anneau. Marche aussi avec les barres de nom d'EllesmereUI.
- **Stats du portrait avec les interfaces de remplacement** : le survol marchait seulement sur le portrait de Blizzard. Il marche maintenant avec EllesmereUI, ElvUI, Shadowed Unit Frames, oUF et consorts, et le cadre se pose au-dessus du portrait survolé.
- **Résumé de stuff plus fiable** : sur le moteur moderne, les stats ne sont pas toujours recalculées tout de suite après un changement d'équipement, et le résumé pouvait ne jamais s'afficher. Les changements d'emplacement sont regroupés et l'écart est relu jusqu'à 1,5 s. `/r2q diag` dit ce qui s'est passé au dernier changement.

*English:* new aggro range module: hold Shift (or Ctrl, Alt, or always) out of combat and each hostile nameplate gets a ring (red inside its estimated aggro radius, amber close, green safe), with radius, distance and verdict in its tooltip. Portrait stats now work with replacement unit frames (EllesmereUI, ElvUI, SUF, oUF…). The gear summary is more reliable on the modern engine (changes grouped, stats re-read up to 1.5 s), and `/r2q diag` reports the last gear change.

## 1.28.0

- **Nouvelle interface**, plus moderne et plus lisible :
  - **police Inter** partout (titres, libellés, chiffres) ;
  - **réglages** dans une grande fenêtre (980 × 680) : une entrée par page dans la colonne de gauche, rangées par groupe avec l'interrupteur de chaque module, une recherche qui trouve un réglage sur toutes les pages, un grand titre et sa phrase d'explication, les réglages en cartes sur deux colonnes (interrupteurs, curseurs avec leur valeur, listes déroulantes) et des aperçus en tête de page (score du check, liseré des Rangs de sorts) ;
  - **toutes les fenêtres** reprennent ce style : Avant le départ (grand score, sceau du verdict, lignes en cartes, conseils encadrés), Avant le donjon, Retour d'expédition, Après la mort, Place au butin, Rangs de sorts, Sac plein, Kit de camp, stats du portrait, résumé de stuff, icône et bulle de Ready2Quest, infobulles ;
  - la page de Ready2Quest dans Échap > Options > AddOns suit aussi.
- Rien ne change dans ce que fait l'addon : mêmes réglages, mêmes boutons, mêmes alertes.

*English:* a new, modern interface: the Inter font everywhere; a large settings window with one navigation entry per page, module switches, a search across every page, card-style settings on two columns and live previews; every window (departure check, dungeon, expedition, death, room for loot, spell ranks, full bags, camp kit, portrait stats, gear summary, notice icon, tooltips) restyled to match. Behaviour is unchanged.

## 1.27.1

- **Rangs de sorts : un fin liseré rouge** entoure, sur tes barres d'action, chaque sort qui a un meilleur rang dans ton livre. Il part tout seul une fois la case mise à jour ou ignorée. Barres de Blizzard, Bartender4 et Dominos ; il suit les pages et les postures. Réglable (page « Rangs de sorts »). Le liseré est un cadre à part posé sur le bouton : le bouton lui-même n'est jamais touché, et rien n'est créé en combat.
- **Fenêtre « Avant le départ »** : le bouton « Partir à l'aventure » ne colle plus aux conseils (il les chevauchait de quelques points), il est un peu plus haut, et son texte passe en blanc : en sombre sur le bleu, il ne se lisait pas.
- **Boutons ambre lisibles** (Fermer des réglages, des donjons et de l'expédition, Mettre à jour, Jeter, Détruire) : l'ombre noire de la police du jeu bavait sous le texte sombre. Elle est retirée sur ces boutons.
- `/r2q diag` montre la nouvelle sonde `combatLog` : WoW Forever ferme son journal de combat aux addons, comme le moteur 12.0 (Ready2Quest ne s'en sert pas).

*English:* Spell ranks: a thin red outline around each spell on your action bars that has a higher rank in your spellbook (Blizzard bars, Bartender4, Dominos; follows pages and stances; can be turned off). It goes away once the slot is updated or ignored. Before-you-go window: the "Off to adventure" button no longer overlaps the advice lines and its label is now white, readable on the blue. Amber buttons (Close, Update, Drop, Destroy) are readable again: the game font's black shadow no longer smears their dark label. /r2q diag shows a new combatLog probe (WoW Forever closes the combat log to addons; Ready2Quest does not use it).

## 1.27.0

- **Nouveau module « Place au butin »**, inspiré de Delete Cheapest Item : sacs pleins devant un butin qui ne rentre pas, une fenêtre s'ouvre (ou `/r2q place`). En haut, l'objet du butin (une quête d'abord, sinon le plus cher) ; dessous, les objets les moins chers de tes sacs, prix du marchand et de l'hôtel des ventes (Auctionator ou TSM s'ils sont là), en gris s'ils valent plus que le butin. [Jeter] détruit l'objet puis ramasse le butin ; confirmation pour un objet vert ou mieux (réglable). [Ignorer] l'ajoute à la liste « toujours garder ». Devant un butin, il prend le relais de « Sac plein ».
- **Nouveau module « Rangs de sorts »** : un sort de tes barres a un meilleur rang dans ton livre ? L'icône de Ready2Quest le signale (à la connexion, après un sort appris, quand une barre change ; jamais en combat), le check avant le départ aussi. `/r2q sorts` liste les sorts avec leur barre et leur case : [Mettre à jour] pose le meilleur rang dans la même case, [Tout mettre à jour] fait tout. [Ignorer] ignore la case (un rang 1 gardé exprès), à oublier dans les réglages.
- **Moteur récent de Forever mieux exploité** (chaque nouveauté reste sans effet si le client ne la propose pas) :
  - **infobulle des objets** : « Ready2Quest : amélioration (+4 Force) » au survol d'une pièce qui fait mieux que celle que tu portes ;
  - **niveaux des donjons lus dans le jeu** quand il les donne (recherche de groupe), les données livrées restant en secours ;
  - **réglages dans Échap > Options > AddOns** (un bouton ouvre la fenêtre de Ready2Quest) et entrée dans le **bouton des addons de la minicarte** ;
  - fiches d'objets demandées au serveur quand elles manquent (noms des composants justes dès la connexion) ;
  - moins de calculs à chaque image (alerte de sortie de zone sûre, camp, mort) ;
  - `/r2q diag` liste les nouvelles sondes : `vignettes`, `tooltipData`, `mapLevels`, `lfgDungeons`, `questsOnMap`, `settingsPanel`, `addonCompartment`, `itemAsync`, `modelAnimation`.

*English:* two new modules. Room for loot (inspired by Delete Cheapest Item): with full bags in front of loot, the cheapest items in your bags with vendor and auction prices; Drop destroys one and picks the loot up, Ignore keeps it forever. Spell ranks: tells you when a spell on your bars has a higher rank in your spellbook, updates it in one click, and lets you ignore a slot. Better use of Forever's modern engine (each part only when the client offers it): an upgrade line in item tooltips, dungeon levels read from the game, an entry in Esc > Options > AddOns and in the minimap addon button, item data requested when missing, fewer per-frame computations, and new /diag probes.

## 1.26.1

- **WoW Forever seulement** : Classic Era n'est plus pris en charge (le `.toc` ne déclare plus que Forever ; Era, TBC et Mists disparaissent des versions annoncées sur CurseForge et Wago). Les versions déjà publiées pour Era restent téléchargeables.

*English:* WoW Forever only: Classic Era is no longer supported (the `.toc` only declares Forever).

## 1.26.0

- **Le compagnon devient un addon à part, autonome : QuestCompanion.** Le compagnon de route, le carnet de voyage, la complétion de zone et les coffres partent dans QuestCompanion, avec sa commande `/qc`, ses réglages et son bouton de minicarte. Il fonctionne seul ; installé à côté de Ready2Quest, il reprend ta progression (tous tes personnages) et réagit à tes départs et retours en ville.
- Ready2Quest garde la préparation : check avant le départ, retour d'expédition, avant le donjon, kit de camp *(Forever)*, résumé de stuff, stats du portrait, et le confort de jeu (bonne récompense, rythme de leveling, sac plein, après la mort, marchand). Ses réglages ne montrent plus le compagnon.
- `/r2q reset` ne touche plus au compagnon.
- **Plus de fenêtre qui s'ouvre toute seule** : au départ, au retour et devant un donjon, une icône du jeu annonce le rapport (« ! » au départ et au donjon, « ? » au retour). Elle pulse quelques secondes dans la couleur du résultat (rouge, orange, ambre, vert ou bleu), reste une minute atténuée, puis s'en va ; un clic ouvre le rapport, un clic droit l'ignore, et elle attend la fin d'un combat. La ligne du chat reste. L'ancienne fenêtre automatique se rallume dans **Général**. L'icône se place avec « Déplacer les cadres ».
- **Zones de départ silencieuses** : les vallées de départ (Vallée des épreuves, Northshire, Coldridge, Sombrevallon, Camp Narache, Deathknell, sous-zones comprises) forment une seule zone sûre. En partir, ou partir de n'importe où sous le niveau 6, ne déclenche ni icône, ni fenêtre, ni bilan : le check reste disponible avec `/r2q`.
- **Munitions du chasseur** : sans elles, pas de tir automatique, donc presque pas de dégâts. Le minimum suit le niveau (200, puis 600 dès le niveau 10, 1000 dès le niveau 30) ; elles pèsent 40 dans la note (les vivres, 20) ; sous la moitié du minimum, la note est plafonnée à 59 (« Pas prêt »), et le conseil le dit. Des flèches ou balles rangées dans le sac mais pas équipées sont signalées comme telles, au lieu d'un « 0 / 200 » trompeur.
- **Un seul barème pour la note** : rouge de 0 à 24, orange de 25 à 59, ambre de 60 à 84, vert à partir de 85, partout (fenêtre, verdict, minicarte, icône). La couleur et le verdict ne se contredisent plus entre 55 et 59.
- **Les camps sont des zones sûres dès l'installation** : environ 140 lieux sur Era et 160 sur Forever, repérés par leurs PNJ de service (auberge, maître de vol, banque, ou marchand avec réparateur ou entraîneur), en plus des 80 villages et capitales déjà connus. Le check se déclenche donc aussi en quittant un petit camp, même sans changement de sous-zone.

*English:* the travel companion and its journal are now a separate, standalone addon, **QuestCompanion** (`/qc`, its own settings and minimap button). Installed next to Ready2Quest, it takes over your progress for all your characters and reacts to your departures and returns. `/r2q reset` no longer resets the companion. No window opens by itself any more: a game icon ("!" when leaving and at a dungeon, "?" when coming back) pulses in the color of the result; click it to open the report (the automatic window can be turned back on in General). Starting valleys are one safe place and stay silent (nothing automatic when leaving them, or below level 6). Hunter ammo: the minimum follows your level (200, 600 from level 10, 1000 from level 30), it weighs 40 in the score, and below half the minimum the score is capped at 59 ("Not ready"); ammo in your bags but not equipped is reported as such. One color scale for the score: red 0-24, orange 25-59, amber 60-84, green 85+. Camps are safe places out of the box: about 140 on Era and 160 on Forever, found from their service NPCs (innkeeper, flight master, banker, or vendor with repairer or trainer).

## 1.25.0

Première version publique.

### Checklist de départ
- Rappel automatique en quittant une zone sûre : sacs, gris à vendre, vivres, buffs, repos, durabilité, quêtes à rendre.
- Zones sûres apprises au fil du jeu, réglages par seuil.

### Carnet de voyage
- Tampons de zones, villages, capitales, donjons, rares et paliers.
- Complétion par zone (parts à poids égal), onglet Zones, suivi à l'écran case par case.
- Bestiaire et nommés de zone ; récolte selon le métier.
- Quêtes de chaque zone pour Classic Era et WoW Forever, préremplies — aucun addon tiers requis.

### Compagnon de route
- Créature 3D qui voyage avec toi, dialogues, astuces et tutoriel.
- Évolution par le bonheur, coffres de zone à choix, cosmétiques de palier (cadres, fonds, apparences, ornements).

### Modules de confort
- **Sac plein** : propose l'objet le moins coûteux à jeter, avec confirmation avant destruction.
- **La bonne récompense** : conseil au rendu de quête.
- **Rythme de leveling** : XP/h, temps avant le prochain niveau, repos.
- **Après la mort** : courir au corps ou guérisseur des esprits.

### Fenêtre de départ
- « Partir à l'aventure » et flèche de relance.
- Page unique pour le résumé de stuff et les stats du portrait, avec « Simuler un changement ».

### Licence
- GPL-3.0, les données de zones étant dérivées de Questie (voir `NOTICE.md`).
