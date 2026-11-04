# Publier sur CurseForge et Wago

Deux addons, deux projets sur chaque site :

| Addon | Dossier | `.toc` | Paquet | Tag |
|---|---|---|---|---|
| Ready2Quest | `Ready2Quest/` | `Ready2Quest/Ready2Quest.toc` | `.pkgmeta` | `v1.26.0` |
| QuestCompanion | `QuestCompanion/` | `QuestCompanion/QuestCompanion.toc` | `.pkgmeta-questcompanion` | `qc-v1.0.0` |

Les deux addons sont autonomes : aucun ne dépend de l'autre. Chacun embarque sa copie du socle commun (`Libs/Socle`).

La publication est automatique : pousser un tag lance `.github/workflows/release.yml`. Les tests passent d'abord. Le workflow vérifie ensuite que le tag correspond au `## Version:` du `.toc`, construit le zip avec [BigWigsMods/packager](https://github.com/BigWigsMods/packager) et l'envoie sur CurseForge, Wago et dans une release GitHub.

## Une seule fois : créer les projets

À faire à la main, avec ton compte : les sites ne permettent pas de créer un projet par API.

### 1. CurseForge (deux projets)

1. Sur [authors.curseforge.com](https://authors.curseforge.com), crée un projet **World of Warcraft › Addon** pour chacun des deux addons.
2. Remplis les champs :
   - **Nom** : `Ready2Quest`, puis `QuestCompanion`.
   - **Résumé** : la ligne `Summary` de `docs/publication/ready2quest.md` ou de `questcompanion.md`.
   - **Description** : le reste de ce fichier, en markdown.
   - **Logo** : `docs/publication/logo_ready2quest.png` ou `logo_questcompanion.png` (400×400).
   - **Licence** : GNU General Public License version 3 (GPLv3).
   - **Catégories** : voir le fichier de description.
3. Le projet passe en modération. Une fois accepté, note son **Project ID** (nombre, colonne de droite de la page du projet).
4. Pour QuestCompanion, tu peux ajouter la relation **Optional Dependency** vers Ready2Quest (onglet *Relations*), ou passer par `.pkgmeta-questcompanion`, voir plus bas.
5. Crée un **jeton d'API** dans les réglages de ton compte d'auteur (*API Tokens*). Il sert pour les deux projets.

### 2. Wago Addons (deux projets)

1. Sur [addons.wago.io](https://addons.wago.io), espace développeur, crée deux projets avec les mêmes textes et logos.
2. Note l'**ID Wago** de chacun : 8 caractères, par exemple `j6jAR1NR`.
3. Crée une **clé d'API** dans les réglages de ton compte.

### 3. Les identifiants dans les `.toc`

Ajoute dans chaque `.toc`, sous `## X-Website:` :

```
## X-Curse-Project-ID: 123456
## X-Wago-ID: AbCdEfGh
```

Chaque `.toc` reçoit les identifiants de **son** projet. Sans ces lignes, le packager saute le site concerné sans erreur.

### 4. Les jetons dans GitHub

Dans le dépôt GitHub : *Settings › Secrets and variables › Actions › New repository secret*.

| Secret | Contenu |
|---|---|
| `CF_API_KEY` | jeton d'API CurseForge |
| `WAGO_API_TOKEN` | clé d'API Wago |

La release GitHub utilise le jeton fourni par Actions : rien à créer.

### 5. Lien entre les deux projets sur CurseForge (facultatif)

QuestCompanion n'a pas besoin de Ready2Quest, mais il en reprend les données de la 1.25 et réagit à ses départs. Une fois le projet Ready2Quest accepté, son *slug* est le dernier morceau de son adresse (`curseforge.com/wow/addons/<slug>`). Ajoute-le dans `.pkgmeta-questcompanion` : chaque envoi le déclarera comme dépendance facultative.

```yaml
optional-dependencies:
  - <slug-de-ready2quest>
```

Un slug faux fait échouer l'envoi : ne l'ajoute qu'une fois le projet visible.

## Essai à blanc (avant la première vraie publication)

Onglet **Actions › Release › Run workflow**, puis choisis l'addon. Le workflow construit le zip **sans rien envoyer** et le met en téléchargement (artefact en bas de la page du run). Ouvre-le et vérifie :

- **Ready2Quest** : un seul dossier `Ready2Quest/`, avec ses `.lua`, `Libs/Socle/`, `Textures/`, `LICENSE`, `NOTICE.md`, `Ready2Quest.toc`. Rien de `QuestCompanion/`, `tests/`, `tools/` ni `docs/`.
- **QuestCompanion** : un seul dossier `QuestCompanion/`, avec ses `.lua`, `Libs/Socle/`, `Textures/`, `QuestCompanion.toc`, `LICENSE` et `NOTICE.md`. Rien de Ready2Quest.

Puis copie les dossiers dans `Interface/AddOns/` et lance le jeu : chacun seul, puis les deux ensemble.

## Publier une version

1. Monte `## Version:` dans le `.toc` de l'addon et `version` dans son `Config.lua` (et, pour Ready2Quest, le test « version exposée »).
2. Ajoute une section en haut de son `CHANGELOG.md` : `Ready2Quest/CHANGELOG.md` ou `QuestCompanion/CHANGELOG.md`. C'est le texte affiché sur les sites.
3. Si tu as touché au socle (`Ready2Quest/Libs/Socle`), recopie-le : `python3 -I tools/sync_socle.py`. Les tests le vérifient.
4. Commite sur `main`, puis tague et pousse :

```sh
git tag v1.26.0      # Ready2Quest
git tag qc-v1.0.0    # QuestCompanion
git push origin v1.26.0 qc-v1.0.0
```

Un tag qui contient `beta` ou `alpha` (`v1.27.0-beta1`) part comme fichier bêta ou alpha.

**Ordre la première fois** : publie Ready2Quest 1.26.0 **avant** QuestCompanion 1.0.0. Un QuestCompanion installé avec un Ready2Quest 1.25, qui contient encore le compagnon, s'efface avec un message pour éviter deux compagnons ; il faut donc que la 1.26.0 soit disponible.

## Versions du jeu

Le packager déduit les versions du jeu de la ligne `## Interface:` : `16001` pour Forever, `11509` pour Classic Era, `20506` pour TBC Anniversary, `50504` pour Mists. Les fichiers seront donc proposés pour ces quatre clients, alors que l'addon n'est testé que sur Forever et Era. Pour ne publier que ces deux-là, ajoute `-g 1.60.1,1.15.9` aux `args` du packager dans `release.yml`. Il faudra alors mettre ces numéros à jour à chaque patch.

## Garde-fous

- `tests/run_tests.py` refuse de lancer les tests si une entrée de la racine du dépôt n'est pas exclue des deux `.pkgmeta` (elle partirait dans un zip), ou si les deux copies du socle diffèrent.
- Le workflow `Tests` tourne à chaque push et pull request.
- Logos : `python3 -I tools/gen_store_logos.py` les régénère : la boussole de Ready2Quest (même dessin et même police que le logo en jeu) et le monogramme QC devant l'ombre d'un dragonnet pour QuestCompanion, ainsi que son icône en jeu `QuestCompanion/Textures/logo_petit.tga`.
