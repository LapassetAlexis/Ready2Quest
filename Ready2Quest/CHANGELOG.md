# Journal des modifications

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
