# Moteur Combat de Ready2Quest

Ce dossier contient le moteur de combat de **DoesItDiePlus** (UsefulPlatesAndTooltips),
d'**Ironship** — https://github.com/Ironship/UsefulPlatesAndTooltips — sous licence
GPL-3.0-or-later (voir `LICENSE`). Le suivi des DoT vient de **Does It Die** de
**Joe Greive** (MIT, voir `Modules/DoTInfo/LICENSE-DoesItDie.txt`) ; SpellDamageInfo
est sous MIT.

Parties reprises : le cœur (cadres, barres de vie, réglages), SpellDamageInfo
(lecture des sorts, chiffres des barres d'action), CastPrediction, DoTInfo et Range.

Les fichiers sont importés tels quels par `tools/sync_combat.py` (commit dans
`UPSTREAM.txt`), qui les isole dans l'espace de noms de Ready2Quest et renomme
leurs noms globaux et commandes (`/r2qc`, `/r2qdot`, `/r2qsdi`) pour ne jamais
entrer en conflit avec DoesItDiePlus. Ne pas les modifier ici : corriger l'import.

L'intégration de Ready2Quest (réglages, interrupteurs, retrait quand DoesItDiePlus
ou Does It Die est installé) est dans `Ready2Quest/CombatBoot.lua` et
`Ready2Quest/Combat.lua`.

Merci à Ironship et à Joe Greive.
