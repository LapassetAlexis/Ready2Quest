# Journal des modifications

## 1.26.0

- **Le compagnon devient un addon à part, autonome : QuestCompanion.** Le compagnon de route, le carnet de voyage, la complétion de zone et les coffres partent dans QuestCompanion, avec sa commande `/qc`, ses réglages et son bouton de minicarte. Il fonctionne seul ; installé à côté de Ready2Quest, il reprend ta progression (tous tes personnages) et réagit à tes départs et retours en ville.
- Ready2Quest garde la préparation : check avant le départ, retour d'expédition, avant le donjon, kit de camp *(Forever)*, résumé de stuff, stats du portrait, et le confort de jeu (bonne récompense, rythme de leveling, sac plein, après la mort, marchand). Ses réglages ne montrent plus le compagnon.
- `/r2q reset` ne touche plus au compagnon.
- **Les camps sont des zones sûres dès l'installation** : environ 140 lieux sur Era et 160 sur Forever, repérés par leurs PNJ de service (auberge, maître de vol, banque, ou marchand avec réparateur ou entraîneur), en plus des 80 villages et capitales déjà connus. Le check se déclenche donc aussi en quittant un petit camp, même sans changement de sous-zone.

*English:* the travel companion and its journal are now a separate, standalone addon, **QuestCompanion** (`/qc`, its own settings and minimap button). Installed next to Ready2Quest, it takes over your progress for all your characters and reacts to your departures and returns. `/r2q reset` no longer resets the companion. Camps are safe places out of the box: about 140 on Era and 160 on Forever, found from their service NPCs (innkeeper, flight master, banker, or vendor with repairer or trainer).

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
