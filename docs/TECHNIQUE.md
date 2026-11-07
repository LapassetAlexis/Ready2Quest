# Ready2Quest — notes techniques et historique

## QuestCompanion 2.7.0 — hauts faits (`FeatsData.lua`, `FeatsCatMenagerie.lua`, `FeatsCatJeu.lua`, `Feats.lua`, `JournalFeats.lua`, `FeatsTitles.lua`) et effets Azeroth

Conception, catalogue et état d'implémentation : `docs/QC-HAUTS-FAITS.md`. Ordre du `.toc`, en fin de liste (après `AzerothStyle.lua`, donc enveloppes les plus extérieures) : `FeatsData.lua` (données, encodage, cadre partagé), `FeatsCatMenagerie.lua` (lot B), `FeatsCatJeu.lua` (lot C), `Feats.lua` (moteur), `JournalFeats.lua` (page), `FeatsTitles.lua` (titres, lot D). 174 lignes : les 173 numérotées du document et `fun_unlucky` (code 174).

### Catalogue et mémoire

- **Lignes** : `{ id, n, cat, pts, scope, crit = …, reward = …, desc = "FEATD_…", pending = true, paid = fn }`. `n` = rang dans le catalogue du document (1–173, au-delà : lignes hors numérotation citées dans le document), jamais réutilisé : c'est lui qui voyage dans les messages de guilde. `ns.FEAT_CATEGORIES` (ordre, portée par défaut, icône), `ns.FEAT_CAPITALS`. Chaînes : `FEAT_<id>` (nom), `FEATC_<cat>`, gabarits `FEATD_<source>` / `FEATD_list_<nom>` / `FEATD_points` / `FEATD_meta_cat` / `FEATD_meta_ids` / `FEATD_flag_<clé>` / `FEATD_streak_<clé>` ; `def.desc` force une clé.
- **Construction à la première lecture** : chaque fichier confie ses lignes, sources et listes à `ns.FeatCatalog(function() … end)` ; `ns.FeatLoadCatalog()` (appelé par l'index du moteur, par `ns.FeatAdd` et par la métatable de `ns.FEAT_SOURCES` / `ns.FEAT_LISTS` quand un nom manque) les exécute dans l'ordre de chargement puis les lâche. Une ligne ajoutée hors catalogue (`ns.FeatAdd`, tests) vient après tout le catalogue. Même principe que les tables de zones paresseuses (`ns.LazyZones`, 1.6.1).
- **Définitions compactes** (`ns.FeatCompact(row)`) : un tableau de 12 cases (`id, n, cat, pts, scope, crit, reward, desc, pending, paid, topicList, icon`, champ absent = `false`), lu et écrit par ses noms grâce à une métatable partagée (`ns.FEAT_DEF_MT`, `ns.FEAT_DEF_FIELDS`) ; un champ hors de la liste reste une clé ordinaire. Mêmes valeurs qu'une table à clés (empreinte du catalogue dans les tests). Index (`ns:FeatIndex()`) : `byId`, `list`, `cats`, `catList` ; `def.topicList` partagées entre lignes de mêmes sujets ; sujets des sources partagés (`ns.FeatTopics(...)`). Boss (`ns.FEAT_BOSSES`) : une chaîne « npcIDs/rencontres/statistiques[/donjon] » lue par `ns.FeatBossField(clé, champ)` ; index npcID/rencontre construit à la première mort vue ; sources `boss_<clé>` créées à la première lecture. Titres : tableaux de 6 cases, formes de la langue du client seulement (toutes en mode test, `ns.KEEP_STRINGS`).
- **Un seul cadre** pour tous les hauts faits (`ns.featEventFrame`, `FeatsData.lua`) : `ns.FeatListen(handlers)` / `ns.FeatUnlisten(handlers)` (plusieurs tables par événement, dans l'ordre d'abonnement, chacune sous `pcall`), `ns.FeatClock(clé, fn)` (horloges `engine`, `minute`, `jeu` ; plus d'horloge, plus d'`OnUpdate`).
- **Mémoire** (`python3 tests/run_tests.py --memoire`, client français) : 293 Ko au chargement pour les six fichiers avant cette passe, 147 Ko après ; le catalogue construit (quelques secondes après la connexion) ajoute 100 Ko (79 Ko avant, avec l'ancien index par sujet). Le rapport `--memoire` affiche cette part à part (« Après connexion »).

### Moteur (`Feats.lua`, lot A)

- **Critères** (`ns:FeatProgress(def)` → `cur, max, état` = `open | done | pending`) : `count` (source ≥ n), `stat` (`max(Σ GetStatistic, alt)`), `flag`, `streak`, `list` (`ns.FEAT_LISTS[nom].items` : relevés `"kind:clé"` ou `{ source, n }`), `meta` (liste d'ids ou catégorie + n), `points` (compte + personnage). `pending = true` ou statistique illisible sans repli → `pending` (grisé, jamais évalué).
- **Sources** (`ns.FEAT_SOURCES[nom] = { get(self, scope), topics, retro = false (pas de rattrapage ; absent = oui), dateOf(self, n) → ok, at, lvl }`) du moteur : `species` / `shinyCap` (union sur `db.chars[*].companion.capture.creatures` pour le compte ; `dateOf` = plus ancien `collection.ranks[n]` du compte), `seals`, `level` (`UnitLevel`, repli relevés), `placeZone` / `placeSubzone` / `placeDungeon` / `placeRare` / `capitalEnemy` (relevés du carnet, `dateOf` = n-ième par `at`), `missions`, `bestiaryKills` (repli de la stat 107). Valeurs gardées le temps d'une passe (`ns:FeatCacheReset`).
- **Sauvegarde** : `ns:FeatStore("account")` = `db.feats`, `ns:FeatStore("char")` = `CharData().feats` ; `{ v, got = { [id] = { at, lvl, r } }, ctr, flag }` (+ `title`, `form` au personnage, lot D). `FixStore` répare une table abîmée une fois par session (table faible). `ns:FeatGot(id)`, `ns:FeatPoints(scope)` = `ns:AchievementPoints(scope)`.
- **Évaluation** : les crochets appellent `ns:FeatTouch(sujet)` ; une passe `ns:FeatEvaluate(sujets)` 0,5 s plus tard (horloge `engine` du cadre partagé, retirée quand rien n'attend), sur les seuls non obtenus abonnés (`def.topicList`) ; jusqu'à 6 tours pour les métas (`feat`). Statistiques jamais lues en combat. Enveloppes : `CaptureResolve` (réussite) et `CaptureBatchFlush` → `capture` ; `ShinyKill`, `ShinySpot` → `shiny` ; `MenagerieSealCheck` (scellée), `MenagerieTypeCheck`, `MenagerieRankCheck` → `seal` ; `JournalEarn` (relevé gagné) → `place` ; `MissionGrant`, `WeeklyEvent`, `InnStamp` → `mission` ; `TreatCheckZone`, `ChestPick` → `zone` ; `BestiaryOnKill` → `kill`. Événements : `PLAYER_LEVEL_UP`, `PLAYER_DEAD`, `QUEST_TURNED_IN`, `PLAYER_MONEY`.
- **Obtention** : `ns:FeatAward(def, { silent, retro, at, lvl })` → `got`, `ns:FeatGrant(def)` (aides `CaptureGrant(id, { quiet, silent })` × n, cosmétique `CompanionData().unlocked["kind:id"]` + `CompanionApplyOrnaments`, apparence `DailyGrantAppearance` ; titre : rien à stocker), réplique `UNLOCK` du compagnon (≥ 25 points ou titre), `FireCallback("FEAT_EARNED", { id, n, pts, scope, cat, title, retro, announce })` (`announce` : ≥ `ns.FEAT_GUILD_MIN` ou titre, hors rattrapage : crochet du lot D pour la guilde). Cosmétiques de compte recopiés sur chaque personnage à la connexion (`ns:FeatSyncAccountRewards`).
- **Bandeau** : file propre `ns.featPending` (`ns:FeatQueue`), vidée par `ns:FeatFlush()` 1 s après la dernière obtention, hors combat et hors sourdine de capture (`CaptureMuted`) ; ≥ 3 (ou un lot de rattrapage) → un seul bandeau « N hauts faits · +P points ». Les entrées passent par la file du carnet `ns:JournalToastPush({ kind = "feat", title, name, icon, points, sub, onShow })` (réglage `featToast`) ; `Journal.lua` les montre sans les regrouper avec les bandeaux simples (`ToastDecor` : icône de catégorie dans le cadre, `frame.featPoints` sur le bouclier d'or en Azeroth ou à droite en Sobre, sous-ligne « Nouveau titre » dans `.stars`). Fanfare `ns.FEAT_SOUND` 12891 (repli 17316, réglage `featSound`). Chat : `featChat` (repris de `journalChat` à la migration).
- **Connexion** (`PLAYER_ENTERING_WORLD` + 3 s, une fois par session, attend la sortie de combat) : `ns:FeatMigrate()` (compte puis personnage, `v = 1`, sous `pcall` : chaque ligne qui a un `dateOf` et qui est acquise reçoit sa date et son niveau, `r = true` ; `journal.stamps` n'est jamais modifié), `FeatSyncAccountRewards`, `ns:FeatRetroScan()` (sources `retro`, en silence) ; une ligne `FEAT_RETRO` et au plus un bandeau pour le tout. Les sujets touchés avant attendent ce passage.
- **Statistiques** : `ns.FeatParseStat(v)` (`nil`/`""`/`"--"` → 0 ; chiffres avec espaces, virgules, espace insécable ; argent `g s c`, `po pa pc`, icônes `|T…GoldIcon…|t` entre les nombres → cuivre, unités absentes comprises ; secret ou autre forme → nil), `ns:FeatStatsOK()` (sonde 107, réglage `featStats`), `ns:FeatStat(id)` (60 s de cache), `ns:FeatStatSum(ids)`. Relevé en jeu du 2026-11-07 (Forever, frFR) : 60, 98, 333, 334, 339, 341, 349, 353, 377, 529, 588, 932, 1098, 1149, 1524, 1537, 15027, 63570, 63573, 64222 lisibles (`GetStatistic` rend valeur, booléen, id ; « -- » = 0). `/qc hf diag` (`ns:FeatDiag()`) imprime la sonde, chaque statistique employée (lignes `stat`, boss, replis des sources : `ns:FeatStatIDs`, complété par `FeatsCatJeu.lua`) et les comptes.
- **Tampons** (`Journal.lua`) : `JournalEarn` n'appelle plus `JournalNotify` (pas de bandeau ni de chat « Nouveau tampon ») ; `STAMP` toujours émis. La file des bandeaux du carnet reste (sceaux, titres, hauts faits). Réglages : section « Hauts faits » de la page `journal`.
- **Page** (`JournalFeats.lua`, `ns.JOURNAL_PANES.feats`, section `feats` entre Ménagerie et Missions) : points (compte, personnage) et filtres `ns.FEAT_FILTERS` (`db.featsFilter`), colonne des catégories (180 px : obtenus/total · points), liste de 7 lignes de 58 px (icône, nom, marque Compte/Perso, description, barre x/n, points sur bouclier Azeroth ou losange Sobre, récompense, date), molette et chevrons (`frame.featsOffset`). `ns:FeatRows(cat, filtre)`, `ns:FeatCategoryStats(cat)`, `ns:OpenJournalFeats(cat)`, `/qc hf`. Le sous-titre du carnet devient « N points de hauts faits ».

### Catalogue de la ménagerie (`FeatsCatMenagerie.lua`, lot B)

- 83 lignes : Ménagerie, Brillantes, Zones et sceaux, Au jour le jour, Guilde et entraide, Insolite (ménagerie et compagnon), grands hauts faits qui en dépendent. Portée : compte, sauf Zones et Au jour le jour (personnage).
- `ns:FeatMenagerieScan()` : relevé groupé des captures et brillantes de tous les personnages (élites, rares, boss, 3 étoiles, murlocs, bestioles, Lardeur, types), refait seulement quand la signature (série, comptes, brillantes) change. Sources `elite`, `rare`, `boss`, `stars3`, `type_<type>`, `typesTier1`, `shiny*`, `companionTypes`, `sealsEk/Ka`, `zones100Ek/Ka` (listes « échelle » `{ source, i }`), `biomesSealed`, `zones100`, `milestones`, `golden`, `chests`, `twoContinents`, `perfect`, `innDays`, `travelKm`, `daysTogether`, `showcase`, `titleSet`, `companionName`, `hoggerKilled`, `birthday` (sans rattrapage), `featPoints`, `got_meta_*` ; listes `foreverZones` (`ns.FEAT_FOREVER_ZONES` = Mont Hyjal 2482, Riverglades 2548, Shen'dralas 2652), `outdoorZones` (`ZONE_LEVELS` + Forever, sans doublon), `trainerMeta`.
- Faits et compteurs (`ns:FeatFlag`, `ns:FeatCount`) posés par des enveloppes muettes tant que le moteur dort : `CaptureResolve` (série d'échecs, écart de niveau, groupe, heure), `CaptureBatchFlush` (5 prises), `ShinyKill` (zone scellée), `CompanionEffectsTick` (types emmenés, boss du monde), `CompanionPet` (hors tutoriel), `MissionGrant`, `TreatCheckZone`, `TrainerOpen` (10 fiches au plus), `TrainerSetShowcase`, `GuildFeatsFlush` / `GuildFeatsEnqueue`, `DoEmote` (danse), `ZONE_CHANGED_NEW_AREA` (continents du jour), horloge `minute`.
- Récompenses déplacées (une seule source) : paliers d'espèces (ex-`TRAINER_RANKS`) donnés par `men_species_<n>` (`ns:FeatLegacyHandled(id)` ; `def.paid` = palier déjà payé avant la 2.7 : `collection.ranks` sans `collection.featRanks`) ; paliers de brillantes (ex-`SHINY_REWARDS`) par `shiny_found_<n>`. Cosmétiques pas encore fabriqués : `reward.soon = { sorte, id }`, passés en `reward.cosmetic` par `ns.FeatResolveSoon()` dès que le catalogue du compagnon les a (lot E).

### Catalogue du jeu (`FeatsCatJeu.lua`, lot C)

- Personnage, Donjons et raids, Métiers, Quêtes, réputations et honneur (personnage), Insolite des statistiques (compte), `meta_dungeons`, `meta_hero`, `fun_unlucky` (méta des quatre morts, titre T39, grisé tant que 112/114/115 ne sont pas lues).
- Notre suivi d'abord (`feats.ctr` : `goldMax`, `deaths`, `quests`, `taxi`, `mounted`, `boss_*`, `worldBoss`, `captureInside`, `rep_*` ; `emotes` au compte ; drapeaux `raidEnter`, `mountEpic`), les statistiques ensuite (rattrapage silencieux de toute la vie du personnage). Boss : `ns:FeatBossKill(npcID, encounterID)` (UNIT_DIED / PARTY_KILL / journal de combat en instance seulement, `ENCOUNTER_END` réussi ; même boss compté une fois par 5 min), repli sur l'entrée du donjon quand rien d'autre ne le dit ; listes `dngTier1`–`4`, `hero`. `ns:FeatJeuZone` abonne les morts en instance (`ns.FeatListen(COMBAT_HANDLERS)`) et les désabonne dehors ; horloge `jeu` (1 s) seulement à cheval ou après la carte des vols. `ns:FeatJeuInit` (ADDON_LOADED / entrée en jeu) : statistiques des replis et des boss ajoutées au diagnostic, crochet `DoEmote`.
- 15 lignes grisées (statistiques ou id pas encore relevés : 346/347, 345…, 63580, 63581, 1518, 840, 319, 594, 108, 112, 114, 115, monture rapide, Valthalak, `fun_unlucky`).

### Titres, fiche et guilde (`FeatsTitles.lua`, lot D)

- Registre unique `ns.FEAT_TITLES[code] = { pos, src, m, f, en, enf }` (40 titres, codes 1–255 jamais réutilisés ; les catalogues n'en déclarent plus) ; `ns:FeatTitleText(code, nom, genre, opts.inline)`, `ns:FeatTitleWho`, `ns:FeatTitleGender` / `FeatTitleForm` / `FeatSetTitleForm` (`feats.form`), `ns:FeatTitlesEarned` (palier d'espèces compris), `ns:FeatTitleChoice` / `FeatTitleCode` / `FeatSetTitle` (`feats.title` : nil auto, 0 aucun, code), `ns:FeatDefByCode`, `ns:FeatIsBig`. Enveloppes : `TrainerTitle` (inchangé en automatique), `JournalToastPush` (`entry.big` → ailes et éclat Azeroth). `/qc titre`, réglage « Forme des titres ».
- `GuildFeats.lua` écoute `FEAT_EARNED` (`ns:GuildFeatsOnFeat`) : sorte `h`, `E~1~h~<n>~0~0~-~<autres>[~<code du titre>~<m|f>]` ; les paliers d'espèces de `TRAINER_RANKS` ne partent qu'en sorte `r` (pas de doublon). `TrainerCard.lua` : champs `ti`, `tg`, `ap` (points de compte), `aq` (points du personnage), `ac` (nombre) ; `TrainerCardHeading`, `TrainerCardFeatsText`.

### Effets du style Azeroth (`AzerothStyle.lua`, section « Effets Azeroth »)

- **Atlas** : `ns.AZEROTH_FX_ATLAS` (Talking Heads, `BonusChest-CircleGlow` / `garrlanding-circleglow`, `OBJFX_StarBurst`, `AftLevelup-*`, `titleprestige-wings`, `BonusChest-Burst-Uncommon`), désignés par leur nom, rien d'embarqué. Chaque effet (ou pièce) demande `ns.AzerothHasAtlas` : absent, il est sauté sans erreur ; ils ne comptent pas dans `AZEROTH_REQUIRED` (le style tient sans eux). Retournement (volute et aile droites) : `ns.AzerothAtlasMirrored(tex, name)` pose le fichier et les coordonnées inversées de `C_Texture.GetAtlasInfo` (pas de `SetTexCoord` sur un atlas posé) ; sans coordonnées, l'atlas tel quel. Durées et géométrie : `ns.AZEROTH_FX`.
- **Bulle** : enveloppe de `ns:EnsureCompanionBubble` ; `bubble.SetText` enveloppé (mesure Sobre, puis mise en page Azeroth : 290 px, nom `ns.AzerothUpper(CompanionName())` en Friz 10 brun-or, texte `F_BODY` brun `INK` sans ombre, hauteur = texte + 30 + 18 + rangée du tutoriel, 64 au moins). L'habit Sobre (`bg`, `border`, `rule`, `tail`, `tailEdge`, `text`) est masqué, jamais détruit ; `ns:CompanionBubbleApplyStyle()` (appelé par l'enveloppe de `CompanionApplyUIStyle`) rhabille à chaud. Reflet `TalkingHeads-Glow-TextSheen` à chaque réplique (0,9 s). Même ancre, pas de souris.
- **Lueur ronde** : enveloppe de `ns:GlowUpdate` (Notify.lua, appelée à chaque image) : en Azeroth, le liseré (`frame.glow`) est caché et `frame.azGlow` (cercle doré `ADD`, `BACKGROUND -8` sous le fond du portrait : un halo autour de l'anneau) respire (2,2 s ; 1,2 s pendant une brillante). Enveloppe : `ns:AzerothGlowEnvelope(now)` (bulle + extinction de `GLOW_FADE`, et `azFx.shinyUntil`). En Sobre, `GlowUpdate` d'origine.
- **Brillante** : enveloppe de `ns:ShinySpot` → `ns:AzerothShinyFX()` : 4 éclats sur `frame.azFxLayer` (enfant du cadre, niveau +8, sans souris), cycle 1,8 s décalé, 4 s.
- **Évolution / niveau** : enveloppes de `CompanionCheckStage` (évolué et `celebrate` : `AZ_FX_EVOLVE`, « Aguerri ! ») et `CompanionOnLevel` (« Niveau N ! », sauf évolution du même instant) → `ns:AzerothLevelFX(text, kind)` : lueur `AftLevelup-IconGlow` sur l'anneau, poussière `Dots1/2` qui monte, et un groupe (enfant d'UIParent, strate HIGH, 30 px de haut, ancré au-dessus du cadre) : volute 84×21, texte Friz 18 or ombré, volute retournée, collées au texte à 6 px (le groupe prend la largeur du texte), `SoftCloud` derrière, `GlowLine` qui balaie dessous. Bulle affichée : elle monte de `groupLift` (36 px) le temps de l'effet (`bubble.azLift`, ancre d'origine rendue ensuite). 3,2 s.
- **Grandes récompenses** : `ns:AzerothRewardFX(frame, opts)` (Azeroth seulement ; `opts.anchor`, défaut `frame.banner` ou `frame`) : ailes (`BACKGROUND -8` du cadre, derrière le bandeau) à gauche et à droite, éclat `ADD` au centre, 2,4 s ; rend false sans atlas. Démonstration : enveloppe de `ShowNextJournalToast`, pour une entrée `kind = "rank"` (titre de dresseur) ou `big = true` (à poser par les hauts faits).
- **Horloge** : une seule (`ns.azFxDriver`), OnUpdate posée par `FxStart` et retirée quand plus rien ne joue ; style changé ou cadre caché : les effets du compagnon s'arrêtent (`ns:AzerothFxStop()`). Pas de réglage « effets » dans l'addon : ils suivent le style et l'interrupteur du compagnon. Chaînes : `ns.AZEROTH_FX_STRINGS`.


### Cosmétiques des hauts faits (`FeatsCosmetics.lua`, lot E) et fonds des sceaux

- Chargé juste après `Feats.lua` : 2 cadres, 2 fonds, 7 ornements ajoutés aux listes du compagnon avec `unlock = { feat = id }`, `tier = 0` (ni coffre ni compteur ; seul `ns:FeatGrant` les débloque) ; `ns:CompanionRequirement` enveloppé (« Haut fait : … ») ; `ns:FeatRewardText` enveloppé : `reward.soon` ou id absent du catalogue → « fond / cadre de fiche (à venir) » (cosmétiques de fiche reportés, dont `card_laurels`), jamais l'id brut. `reward.soon` → `reward.cosmetic` par `ns.FeatResolveSoon` à la construction du catalogue.
- **Images du client uniquement** (aucune texture livrée) : icônes `Interface\Icons\…` (familles, `Spell_Frost_ChainsOfIce`, `INV_Enchant_PrismaticSphere`, `INV_Misc_Ribbon_01`, `Achievement_Boss_CThun`, `INV_Crown_14`, `Spell_Fire_Fire`), case `Interface\WorldMap\Azeroth\Azeroth6`, minicarte (`MiniMap-TrackingBorder`, `UI-Minimap-Background`, `MinimapArrow`, `CompassNorthTag`), étoile des marqueurs de raid, atlas `BonusChest-CircleGlow` / `garrlanding-circleglow`. Contrôles : `ns.FeatClientFile(path)` (`GetFileIDFromPath`, repli sur l'icône suivante de `def.icons`, aucune → ornement caché) et `ns.AzerothHasAtlas` (halo sauté). Décor créé à la demande dans `frame.featDeco` (niveau + 6, au-dessus de l'habillage Azeroth), ornements `frame.featOrn`, feu `frame.featFire` (sur le cadre, masqué en disque en Azeroth) ; horloge (0,05 s) seulement pour le prisme porté.
- **Fonds des sceaux** : `ns.MENAGERIE_BIOME_GROUND[biome] = { FileDataID, teinte }`, une texture de sol des zones d'origine (tileset Elwynn, Gangrebois, Tarides, Berceau-de-l'Hiver, marais des Chagrins, Tanaris, Maleterres, Strangleronce, steppes Ardentes), assombrie ; fichier refusé → aplat (repli de `CompanionApplyBackground`). Retirés : `tools/gen_seal_scenes.py`, les 10 `Textures/scene_<biome>.tga` (3,75 Mo), et l'éphémère `tools/gen_feat_cosmetics.py` et ses TGA. Tests : `qc27_hf_cosmetiques.lua` (`[HF-E]`).

### Tests

- `qc27_hf_integration.lua` (`[HF-I]` : empreinte du catalogue d'avant l'encodage et actuelle, définitions compactes, titres, guilde, diagnostic, formes de statistiques de Forever), `qc27_hf_moteur.lua` (`[HF]`), `qc27_hf_menagerie.lua` (`[HF-B]`), `qc27_hf_jeu.lua` (`[HFJ]`), `qc27_hf_titres.lua` (`[TIT]`), `qc27_effets.lua` (`[FX]`). Dans le harnais, le moteur est endormi (`ns.featsDormant`, posé si `ADDON_TESTING`) : aucun crochet ni rattrapage ne tourne tout seul dans les autres modules ; chaque module de test le réveille et le rendort.

## QuestCompanion 2.6.0 — sans Souvenirs

- **Retiré** : `Memories.lua` (album, photos par `Screenshot()`, question d'accord, anniversaires, rappels à voix haute, photos recréées), la section `memories` du carnet (`frame.mem`, `BuildMemoriesPane` / `RefreshMemoriesPane`), la page de réglages `companionMemories` et l'action `companionAlbum`, les réglages `companionPhotos` / `companionRecall`, l'effet `flash` de `CompanionFx.lua`, les réservoirs `PHOTO` (commun et 14 caractères), `RECALL`, `ANNIV`, les appels `MemoryRecord` de `Shiny.lua` et `Capture.lua`, les chaînes `MEM_*`. Un ancien `db.journalTab = "memories"` retombe sur la page Compagnon (`KindOf`).
- **Gardé** : les paysages `Textures/scene_<biome>.tga` des 10 biomes (fond du deuxième sceau d'un biome) ; `ZONE_BIOME` et le chemin des textures vivent maintenant dans `MenagerieCollection.lua` (`ns.MENAGERIE_ZONE_BIOME`, `ns.MENAGERIE_SCENE_TEXTURE`), le générateur devient `tools/gen_seal_scenes.py` (sortie identique octet pour octet). `scene_cave`, `scene_city`, `scene_sky` (souvenirs seulement) sont supprimés.
- **Ménage de la sauvegarde** (`Core.lua`, `ns:DropMemories()`, appelé par `OnAddonLoaded` sous `pcall` après la reprise Ready2Quest) : une fois (`db.memoriesDropped`, gardé par `/qc reset`, remis à nil par une reprise Ready2Quest), retire `db.companionPhotos`, `db.companionPhotosAsked`, `db.companionRecall` et, pour chaque `chars[*].companion`, `memories`, `memoryKeys`, `metAt`, `sillyScore`, `photoDay` (`ns.MEMORY_DROPPED_KEYS`). Avant, si `since` n'est pas posé, il prend la date du plus vieux souvenir (sinon `metAt`) : « jours ensemble » ne repart pas de zéro. `ns:CompanionSince()` ne lit plus l'album.
- **Tests** : `tests/modules/qc26_sans_souvenirs.lua` (`[SANS]`) ; `companion_memories.lua` et `memories_photo.lua` supprimés, scènes `qc-journal-memories` et `qc-photo` retirées de `tests/snapshot.lua`.

## QuestCompanion 2.5.0 — style de l'interface « Azeroth » (`AzerothStyle.lua`)

- **Style** : `db.companionStyle` (`azeroth` par défaut, `sobre`) ; `ns:UIStyleChoice()` (le réglage), `ns:UIStyle()` / `ns:AzerothOn()` (effectif : Azeroth seulement si `ns:AzerothAtlasOK()`, c.-à-d. `C_Texture.GetAtlasInfo` non nil sous `pcall` + `ns.Plain` pour chaque atlas de `ns.AZEROTH_REQUIRED` ; gardé tant que `C_Texture` est le même, `refresh` pour redemander). Atlas du client par nom (`ns.AZEROTH_ATLAS`, `ui-achievement-*`), rien d'embarqué. Réglage : rangée `companionStyle` de la page `companionMain` (après le cadrage, infobulle si les atlas manquent) ; `/qc style azeroth|sobre`.
- **Changement en direct** : `ns:SetUIStyle(id)` → `ns:ApplyUIStyle()` : `captureToast`, `guildFeatToast`, `journalToast`, `captureResult` du mauvais style vont dans `ns.uiStyleCache[clé][style]` (un cadre par style, créé à la demande), remplacés s'ils étaient affichés ; les `Ensure*` reprennent un cadre gardé par `ns:StyleCached(clé)`. Le compagnon est rhabillé sur place (`ns:CompanionApplyUIStyle`).
- **Bandeau** : `ns:AzerothCreateBanner(opts)` (`guild`, `round`, `strip`, `name`, `strata`) : 388×126 (`ns.AZEROTH_LAYOUT`), `.banner` (enfant centré qui éclot), `.icon` dans `.iconFrame`, `.title` (Friz, brun), `.text` (nom), `.stars`, `.shield` (`SetShield("grey"|"gold")`), `.glow/.shine/.bling` ; `strip` : bande `Theme.WINDOW` + liseré `GOLD_SOFT` (`.strip`, ancre des infos, de l'aide et des boutons). `frame:Fit()` (`ns.AzerothFit` : police 20 → 11 jusqu'à tenir, `GetUnboundedStringWidth` si présent, puis largeur fixe = points de suspension), `frame:Play(opts)` (OnUpdate 2,4 s, retiré après). `ns:StyleShown(frame, opts)` après chaque remplissage (no-op en Sobre).
- **Branchements** : `EnsureCaptureToast` (Sobre : `ns:CaptureToastSobre`, commun : `ns:CaptureToastControls(frame)`, boutons ancrés sur `frame.strip or frame`), `EnsureGuildFeatToast` (`ns:GuildFeatToastSobre`), `EnsureJournalToast`. Sceaux et titres : enveloppes de `MenagerieSealCheck` / `MenagerieRankCheck` → `ns:JournalToastPush({ kind = "seal"|"rank" })` (`journalToast`, sans ligne de chat).
- **Résultat** : `ns:CaptureResultQueue({ name, shiny, stars, more })` depuis l'enveloppe de `CaptureResolve` (lancer seul) et de `CaptureBatchFlush` (meilleur selon `ns.CaptureBatchStrength`) ; `ns:CaptureResultTick` (enveloppe de `CaptureTick`) l'affiche quand `ns:CaptureSceneBusy()` est faux, hors combat (`CAPTURE_RESULT_STALE` = 30 s d'attente hors scène), jamais en sourdine ; `CAPTURE_RESULT_SECONDS` = 3,5 s.
- **Compagnon** : `frame.azSkin` (enfant, niveau + 4, sans souris) : anneau `ui-achievement-guild-iconframe` 108×104 centré sur le portrait, plaque `…-alert-background-mini` sous le nom ; nom et humeur reparentés sur l'habillage, liserés et bordure gagnée cachés (enveloppe de `CompanionApplyFrame`), fond arrondi par `CreateMaskTexture` (`TempPortraitAlphaMask`) si le client l'a. Taille du cadre inchangée : `CapturePlaceNet` et le survol ne bougent pas.
- **Tests** : `tests/modules/qc25_azeroth.lua` ; le harnais n'a pas `C_Texture` par défaut (tous les autres modules restent en Sobre), `Mock.InstallAtlas(true | { nom = true } | nil)` le pose.
- **2.5.1, fenêtres de capture** : `ns:AzerothScenesOn()` = `AzerothOn()` + `ns:AzerothSceneAtlasOK()` (le bois `ns.AZEROTH_WOOD`, 8 atlas `achievement-wood-nineslice-*`, + `AZEROTH_SCENE_REQUIRED`) ; bois absent : ces fenêtres en Sobre, les bandeaux restent Azeroth. Briques (`AzerothStyle.lua`) : `ns:AzerothCreateWindow(w, h, opts)` (comme `CreateToast`, `SetClampRectInsets` de 8 px pour le bois qui déborde ; `.wood`, `.woodBg`), `ns:AzerothPlate(parent, w, h)` (`.title`, `.text`, `:SetName(text, shiny)`), `ns:AzerothVerdict(parent, w, h)` (zone fixe `.area` + bandeau qui éclot), `ns:AzerothButton(parent, w, h, label, onClick, "gold"|"dark")` (dessiné : dégradé, liseré 2 px, `:SetSub`), `ns.AzerothShield(tex, kind)` (le gris seulement si `ns.AzerothHasAtlas`, sinon l'or désaturé), `ns.AzerothUpper` (capitales sans `string.upper` sur les octets UTF-8). Une fenêtre par style, gardée : `ns.captureStages`, `ns.captureBatchFrames`, `ns.captureChoosers` [style] ; `ns.captureStage` / `captureBatchFrame` / `captureChooser` = celle du style courant, échangée à l'`Ensure*` suivant si elle n'est pas affichée (changement de style pendant une scène : appliqué à la prochaine). Noms globaux `…Azeroth` (Échap). Scène : `ns.CAPTURE_STAGE_AZEROTH` (360×504), étoiles dans le bandeau, losanges d'or sous la scène, pied à 24 px du bas (bois visible : `AZEROTH_WOOD_INSET` = 16). Volée : `ns.CAPTURE_BATCH_AZEROTH` (cases 132×148, cadre d'icône devant le modèle, bouclier au coin ; 5 ou 6 cases → 3 colonnes). Choix : `ns.CAPTURE_CHOOSER_AZEROTH`, posé à gauche du filet s'il est dans la moitié droite de l'écran, à droite sinon (`ns.CaptureChooserSide`). Doublon « Capturé ! » : `rolling.sceneVerdict` (posé par `CaptureShowStage` en Azeroth) ; l'enveloppe de `CaptureResolve` ne met rien en file si la scène affiche encore ce lancer. Tests : `tests/modules/qc251_scenes_azeroth.lua`.

## QuestCompanion — le choix au filet, la volée de « Tout capturer », la pause du compte

- **Clic** (`CaptureQueue.lua`) : le filet et le bandeau passent par `ns:CaptureNetClick(mouse)` (clic droit : la liste ; sinon `CaptureThrow`). `CaptureBatch.lua` l'enveloppe : `CaptureBatchOffered()` (≥ 2), hors combat et sans filet en l'air → `ns:CaptureChooserShow()` ; Maj+clic → le meilleur ; Ctrl+clic → `CaptureBatch()` ; clic avec le choix ouvert → le referme. `ns:CaptureThrow()` et `/qc filet` restent un lancer seul.
- **Choix** (`QuestCompanionCaptureChooser`, `Theme.CreateToast`, liseré `GOLD_SOFT`, ancré `BOTTOM` sur `TOP` du filet) : `.single` (« Capturer : … ») et `.all` (« Tout capturer (N) »). Refermé par Échap (`UISpecialFrames`), `GLOBAL_MOUSE_DOWN` hors du choix et du filet (`IsMouseOver`), `PLAYER_REGEN_DISABLED`, et `ns:CaptureChooserRefresh()` (OnUpdate à 10 Hz, enveloppe de `CaptureQueueRefresh`) : combat, filet en l'air, file < 2, filet caché. Infobulle du filet : `ns:CaptureNetClickLines`.
- **Pause du compte** : prises `ns:CaptureQueueHold(raison)` / `ns:CaptureQueueRelease(raison)` (`chooser`, `throw`, `batch`) ; la première fige `state.queuePausedAt`, `ns:CaptureQueueClock(now)` rend cette heure figée (expiration dans `CaptureQueuePrune`, `CaptureTick`, temps de `CaptureQueueLine`, `expires` d'un nouveau venu, `CaptureQueueStartTimers`) ; la dernière lâchée décale chaque `expires` de la durée de la pause. `ns.CAPTURE_HOLD_CHECKS[raison]` : `CaptureTick` lâche une prise dont la raison a disparu (`ns:CaptureQueueCheckHolds`).
- **Volée** (`CaptureBatch.lua`, remplace les cartes) : cases de 104×136 créées à la demande et réutilisées ; modèle 3D (`ns:CaptureModelSetup`, partagé avec `CaptureStage.lua`) pour les `CAPTURE_BATCH_MODELS` (8) premières, icône au-delà, `ClearModel` à la fermeture. `ns:CaptureBatchSchedule` : `dropAt = LEAD + (i-1)·STAGGER` (0,1 s), `resultAt = dropAt + DRAPE + shakes·CAPTURE_SHAKE_STEP` (`result.shakes` = `rolling.shakes`) ; les brillantes (prises ou non) après la dernière ordinaire + `PAUSE`, écart `SPECIAL_GAP` resserré ; `card.cap` = secousses montrées. Une horloge OnUpdate pour toutes (`ns:CaptureBatchUpdate`) : `DrawShake`, `Resolved` (compteur, sons), `DrawVerdict`, puis `ApplyFinal` (case figée) au bout de `CAPTURE_BATCH_SETTLE`. Sons : `net` (836) ≤ 1 / 0,06 s, `ok` groupés (≥ 0,4 s), `shiny` par brillante prise.

## QuestCompanion — Ménagerie façon bestiaire (paliers, boutons de type)

- **Trois paliers** (`JournalWindow.lua`, `ns:JournalPreviewMenagerie`) : `entry.known == false` (jamais vue ni abattue) = verrouillée : ligne « ??? » (couleur de rareté gardée), icône point d'interrogation, fond `Theme.FIELD`, zone en détail dans la vue « toutes zones » ; fiche sans nom, niveau ni modèle (`MENV_LOCKED`, zone, `JRN_MEN_NEVER`). Croisée : nom, niveaux, modèle, abattues, chance, brillante. Capturée : tout, et les lignes « Chasse / Confort » (`CompanionEffectsLines`) n'apparaissent plus qu'ici.
- **Filtre par type** (`Capture.lua`, `ns:MenagerieList`) : `opts.ctype` (clé de `ns.CREATURE_TYPES`, `"all"` ou nil = sans filtre), `item.typeKey` posé seulement pour une espèce croisée, `stats.types[clé] = { known, captured }` sur la portée (zone). Une inconnue n'a ni type ni nom cherchable : aucun filtre ne la révèle. Tri `"kills"` (abattues, décroissant).
- **Rangée de boutons** (`MenagerieView.lua`, après `JournalGuide.lua`) : `ns:MenagerieViewBuild(pane, content, x, y, frame)` rend sa hauteur (la liste descend d'autant), `ns:MenagerieViewRefresh(pane, frame, stats)` peint sélection, comptes (infobulle) et résumé ; `ns:MenagerieSetType(clé)` (re-clic ou « Tous » = nil) ; état `frame.menType`, remis à nil par `ns:OpenMenagerieZone`. Icônes `Interface\Icons\Icon_PetFamily_*` du jeu (celles du Forever Bestiary ; Démon = Magical, Géant = Water), repli sur `ns.MENAGERIE_TYPE_ICONS` si `SetTexture` rend false. Le modèle de la fiche tourne au glisser (`ns:MenagerieViewRotate`, `OnUpdate` posé seulement pendant le geste).
- Tests : `tests/modules/qc2_menagerie_vue.lua` ; `companion_missions.lua` : la fiche d'une inconnue ne montre plus son niveau.

## QuestCompanion — exploits de guilde (`GuildFeats.lua`)

- **Protocole** : type `E` sur le préfixe `QCTrainer` (file, débit et blocages de `TrainerCard.lua`), canal `GUILD` seulement : `E~1~<sorte>~<id>~<zone>~<étoiles>~<rang>~<autres>`, sortes `s` (brillante : npcID + zone), `n` (espèce nouvelle élite / rare / rare élite / boss), `z` (sceau : zoneID), `r` (palier : 10/25/50/100/250). Aucun nom ne voyage : le destinataire refait créature (`ZonePeek` des tables livrées, carnet, ménagerie), zone (`MapInfo`, zone à sceau seulement) et titre (`TRAINER_RANKS`) ; un identifiant inconnu chez lui, un champ hors format (chiffres seulement, longueurs bornées, rang en liste blanche) : ignoré. Les versions d'avant ignorent `E` (type inconnu, détenteur noté).
- **Crochets** : enveloppes posées en dernier (`.toc`) de `ns:CaptureResolve` (relevé avant : espèce nouvelle, brillante déjà là ; brillante annoncée si nouvelle ou `rolling.starsBetter`), `ns:MenagerieSealCheck` et `ns:MenagerieRankCheck` (pas avec `opts.quiet`), `ns:TrainerOnAddonMessage` (après la base : plafond par joueur, soi ignoré, détenteur noté) et `ns:TrainerPump` (horloge : pas de cadre à soi).
- **Envoi** : `ns:GuildFeatNote` garde le meilleur et compte les autres (`GuildFeatScore` : brillante > palier > sceau > espèce selon le rang, puis étoiles) ; départ après `GFEAT_GATHER` (4 s), au plus un toutes les `GFEAT_GAP` (30 s), hors combat et verrou ; muet si `guildFeatsSend` ou `trainerShare` coupé, ou hors guilde.
- **Réception** : `guildFeatsShow` (`all` / `shiny` / `off`), ligne de chat `guildFeatsChat` ; file `state.toasts` (3, un par membre, le meilleur gardé, périmé à 60 s), un bandeau à la fois hors combat (`QuestCompanionGuildFeat`, `guildFeatToastPoint`), son `GFEAT_SOUNDS` (≥ 1 s d'écart, coupé avec les sons de capture ou la sourdine), clic → `ns:TrainerOpen(expéditeur)`.
- **Débit refusé** (`TrainerCard.lua`) : `SendAddonMessage` qui rend 3 ou 8 → message remis en tête, réessai 1 s plus tard (`TRAINER_RETRY_DELAY`), 5 fois au plus (`TRAINER_RETRY_MAX`).
- **Découverte au survol** : `ns:GuildFeatsTooltipProbe` (dans `ns.UNIT_TOOLTIP_LINES`) passe par `ns:TrainerOnTarget` (une sonde par joueur et par session, pas en combat, même faction), au plus une par seconde, pas pour un détenteur vu depuis moins de 10 min.

## QuestCompanion 2.3.0 — tutoriel de la ménagerie, page Guide, Échap

- **Séquences qui attendent un geste** (`Companion.lua`) : `ns:CompanionStartSequence(kind, pool, steps, stepTime, args, opts)` accepte des étapes détaillées `{ key, pool, args, waitFor }` et `{ result = { ok = étape, fail = étape } }` ; `opts.stepArgs` (arguments par étape), `opts.manual` (rejeu). Une étape `waitFor = { "net", "stage" }` pose `seq.waiting` : le temps ne la passe pas (sa bulle dure `TUTO_WAIT` = 90 s et revient si elle s'efface, « Suivant » la redit), `ns:CompanionSequenceAdvance(tag, info)` la fait avancer, `ns:CompanionSequenceAbort(tag)` l'arrête (bulle `TUTO_MENAGERIE_LATE`, rien de marqué), `ns:CompanionSequenceWaits(tag)` la lit. La pause de combat garde le rang d'une étape qui attend.
- **Accroches** (`CaptureQueue.lua`) : `ns:CompanionMenagerieOpportunity()` quand le bandeau se montre (`CaptureOffer` hors combat, fin de combat dans `CaptureTick` quand `CaptureQueueStartTimers` démarre les comptes) ; `Advance("net")` dans l'enveloppe de `CaptureThrow` (avant `CaptureQueueRemove`, pour que la file vide ne compte pas comme « trop tard ») et après un lancer depuis la petite fenêtre ; `Advance("stage", { ok })` quand `rolling` à verdict disparaît dans `CaptureTick` ; `Abort("net")` quand `CaptureQueueRefresh` compte 0 (temps écoulé, Ignorer). Le bouton filet prolonge `pulseUntil` tant que `CompanionSequenceWaits("net")`.
- **Tutoriel** : réservoirs `P.TUTO_MENAGERIE_START/OK/FAIL/LATE/INTRO` et `P.TUTO_MENAGERIE` (11 bulles, `%d` remplis par `ns:CompanionMenagerieTutorialSteps(guided)` depuis `CAPTURE_QUEUE_TIME`, `CAPTURE_STAR_ODDS`, `SHINY_CHANCE`/`SHINY_CHAIN_MAX`/`SHINY_CHAIN_KILLS`, `EFFECT_DELAY`, `EFFECT_NEED_OK`, `SEAL_SHINY_MULT`, `TRAINER_RANKS`). Drapeau `CompanionData().tutoMenagerieDone` ; exige `tutoDone` (le tutoriel de base d'abord, sans enchaîner), la capture et les bulles allumées. Fin guidée : `ns:OpenJournalGuide()` ; rejeu (`/qc compagnon tuto menagerie`, bouton du Guide) : INTRO puis la suite au temps, `rt.tutoMenageriePending` en combat. `ns.TUTO_MENAGERIE_AUTO = false` dans le harnais (sa priorité retiendrait les bulles des autres scénarios) ; `tests/modules/qc2_guide.lua` le rallume.
- **Page Guide** (`JournalGuide.lua`, après `JournalCompletion.lua`) : `ns.JOURNAL_PANES.guide`, sections `ns.GUIDE_SECTIONS`, blocs (paragraphes, sous-titres, rangées de table) paginés par `Pager` et la molette ; table des types depuis `CompanionEffects.lua`, chiffres depuis les constantes ; `ns:JournalGuidePick(id)`, `ns:OpenJournalGuide(id)`, `ns:JournalGuideReplay()`. Scène d'aperçu `qc-journal-guide`.
- **Échap** : la scène (`QuestCompanionCaptureStage`) et la liste du filet (`QuestCompanionCaptureList`) ont un nom global et passent par `Theme.RegisterEscapeClose` (`UISpecialFrames`, sous `pcall`). `OnHide` de la scène : `frame.rolling = nil`, et `rolling.closeAt = now` si le verdict est tombé (sinon la capture se résout quand même, résultat dans le chat). La liste se ferme au clic sur une ligne, au lancer, file vide, par son « × » (`Theme.CreateCloseButton`) ou le clic droit. Un lancer pendant le verdict précédent referme la scène et part aussitôt.

## QuestCompanion 2.2.0 — bandeau complet, sons, cadrage

- **Bandeau** (`CaptureQueue.lua`) : 340×86 ; ligne d'infos `ns:CaptureToastInfo(candidate)` (étoiles possédées par version via `ns:CaptureStars`, « peut faire mieux », chance via `ns:CaptureChance`) ; boutons Ignorer (`ns:CaptureToastIgnore`) et Sourdine (rangée `frame.muteRow`, `ns.CAPTURE_MUTE_CHOICES`) posés au-dessus du bouton invisible du bandeau (niveau de cadre +2). Sourdine : `DB().captureMuteUntil` (temps réel), `ns:CaptureMuted()` / `CaptureMute(min)` / `CaptureUnmute()`, `/qc filet sourdine [min|off]`.
- **Sons** : `ns.CAPTURE_SOUNDS` = kits du client par numéro (`SoundKitConstants.lua` de l'interface de Blizzard, mêmes numéros sur tous les clients : 28814 piège prêt, 32047 caméra des combats de mascottes, 17316 récompense LFG, 63971 butin légendaire, 43501 échec de mission) ; `ns:CapturePlaySound(clé)` (réglage `companionCaptureSound`, sourdine, `PlaySound(id)` sous `pcall`). Joués par les enveloppes de `CaptureThrow` / `CaptureResolve` et à la première apparition d'un candidat dans le bandeau (`frame.chimedFor`) ; la scène (`CaptureStage.lua`) ne joue plus ses propres kits.
- **Cadrage** (`Companion.lua`) : `DB().companionFraming` ∈ `ns.COMPANION_FRAMINGS` (portrait par défaut), `ns.COMPANION_FRAMING_ZOOM` → `SetPortraitZoom` (1 / 0,55 / 0) dans `CompanionApplyModel`, distance de caméra 1 en portrait et buste (l'échelle du stade reste) ; réglage « Cadrage » (ligne `companionFraming`, page du compagnon).

## QuestCompanion 2.1.0 — la capture en scène

- **Textures dédiées** (`QuestCompanion/Textures/`, 1,07 Mo, TGA 32 bits non compressés, puissances de deux) peintes par `tools/gen_capture_assets.py` (numpy + Pillow, déterministe ; `--apercu DIR` écrit une planche des assets et une maquette des images clés en PNG, jamais versionnées ; `--sortie DIR` pour essayer ailleurs) : `filet` (512×256, entier | déchiré : réseau de nœuds dérangé par un bruit lisse, cordes qui pendent entre les nœuds, projeté sur une calotte (`DOME`) et éclairé d'en haut à gauche, lest suspendu au bord, poils de chanvre, ombre portée), `paquet` (le filet roulé en boule), `corde` (morceau qui vole), `halo`, `rayons` (irréguliers, striés), `particules` (point, étoile 4, étincelle 6, anneau), `etoiles` (pleine | vide, facettes), `ruban` (panneau | liseré, tissu plissé), `vignette` (projecteur, sol, ombre), `filet_icone` (glyphe blanc). Les textures blanches se teintent par `SetVertexColor`, les lumières se fusionnent en `ADD`, les feuilles se découpent par `SetTexCoord` (`ns.CAPTURE_COORDS`) ; chemins dans `ns.CAPTURE_ART`.
- **Scène** (`CaptureStage.lua`, 340×386, scène de 196, filet de 210) : tout est créé une fois dans `EnsureCaptureStage` (une soixantaine de textures : traînée, poussière, cordes, gerbe, motes, étoiles…), rien n'est alloué par image ; `CaptureStageUpdate(now)` délègue à `StageThrow`, `StageShake`, `StageOk`, `StageFail` et rend la phase. Calques, de l'arrière vers l'avant : fond de scène, rayons et halo sur le cadre lui-même (derrière le `PlayerModel`, enfant de `scene`, qui rogne ses enfants pour la fuite) ; `fx` (poussière) → `netFrame` (ombre puis filet : `SetScale` pour l'ouverture, la pose avec rebond, le resserrement et la fermeture, `SetRotation` pour l'oscillation ; l'ombre reste au sol pendant la chute) → `fxTop` (paquet, traînée, cordes, gerbe, motes, éclair) → `banner` (ruban, liseré, texte, reflet d'une brillante dans un cadre qui rogne, si `SetClipsChildren` existe). Les étoiles du spécimen (`rolling.stars`, CaptureQueue.lua) sont dessinées par la scène, une à une avec une étincelle ; l'enveloppe de CaptureQueue ne garde que le pied « meilleur spécimen ».
- **Bouton filet** : glyphe `filet_icone` teinté (ambre, or clair au survol ou pour une brillante, avec le halo) ; `CaptureStarsText` découpe `etoiles` en texture en ligne (`|T…:128:64:x1:x2:0:64|t`), repli sur l'icône de cible du jeu si `ns.CAPTURE_ART` manque.
- **Harnais** : le mock garde `SetRotation`, `SetBlendMode` et `SetClipsChildren` ; l'aperçu HTML (`tests/snapshot.lua`, `tests/snapshot.py`) découpe les feuilles de sprites (`data-crop` → position et taille du fond), tourne (`transform:rotate`) et fusionne en `mix-blend-mode:plus-lighter`. Scènes `qc-capture-shake`, `qc-capture-ok` (ruban posé, deux étoiles sur trois), `qc-capture-fail`.
- À vérifier en jeu (rien ne peut l'être ici) : les TGA chargent (sinon un carré vert, ou rien) ; le `PlayerModel` passe bien derrière le filet et devant les rayons ; `SetRotation` tourne autour du centre de la texture ; `ADD` sur un fond sombre ; la fuite rognée par `SetClipsChildren` sur un `PlayerModel` ; le reflet du ruban ; la lisibilité du ruban et des étoiles à l'échelle d'interface du joueur ; le glyphe du bouton à 14 px.

## QuestCompanion 2.0.0 — la ménagerie au cœur

Cinq lots codés en parallèle depuis une base commune (`CreatureTypes.lua`, un fichier réservé par lot), selon des contrats écrits : [docs/QC2-CONTRATS.md](QC2-CONTRATS.md). Chaque lot s'accroche aux autres par enveloppes de fonctions, dans l'ordre du `.toc` (`Capture.lua` → `CaptureQueue.lua` → `CompanionEffects.lua` → `MenagerieCollection.lua` → `MissionsMenagerie.lua` → `TrainerCard.lua`) ; `ns:CaptureResolve` est enveloppé par les cinq.

- **`CaptureQueue.lua`** : file `ns:CaptureQueue()` (12 au plus, 30 s après le combat, tri : brillante > nouvelle > rang > étoiles), bouton filet indépendant (`ns.captureNetButton`, `ns:CapturePlaceNet` : 44 px à côté du compagnon, côté selon le bord de l'écran, à son échelle ; battement `pulseUntil`), bandeau « Capture possible » (`ns:CaptureToastShow` / `CaptureToastHide`, hors combat, montré à la fin du combat par `CaptureTick`, réglage `companionCaptureToast`), étoiles `entry.stars` / `entry.shinyStars` (`ns:CaptureStars`), `entry.firstAt`, `/qc filet`.
- **`CompanionEffects.lua`** : `ns:CompanionEffects()`, `ns:CompanionEffectValue(id)` ; effets par type (chasse, confort) via enveloppes de `CaptureChance`, `ShinyChance`, `ShinyRoll`, `CaptureSpend`, `TreatCheckZone`, `CompanionDecayFactor`… ; force = rang + brillant + étoiles + `ns:MenagerieTypeBonus`, réglée par les envies ; confirmation (`ns:CompanionAskAppearance`) et délai de 2 min (`CompanionData().effects`).
- **`MenagerieCollection.lua`** : parts de zone `exploration = false` (bestiaire, nommés) ignorées par `ns:ZoneCompletion` ; sceaux (`ns:MenagerieSealProgress`, `ns:MenagerieSealed`, `ns:MenagerieSeals`, boss du monde exclus), cosmétiques par biome, brillant ×1,5 en zone scellée ; `ns:MenagerieTypeBonus` ; titres (`ns:TrainerTitle`) ; données `CompanionData().collection` ; rattrapage sans garder les tables de zone (`ns.ZonePeek`).
- **`MissionsMenagerie.lua`** (+ `Daily.lua`, `Weekly.lua`) : missions du jour par catégorie (ménagerie, exploration, caractère), `typeCapture` à la semaine ; `MissionEvent` / `WeeklyEvent` reçoivent `info` (`ctype`).
- **`TrainerCard.lua`** : préfixe `QCTrainer` ; messages `H` (annonce), `A` (accusé), `P` (sonde), `R` (demande), `N` (refus), `C` (fiche en morceaux de 200 octets) ; sérialisation `clé=valeur;…` échappée, champs inconnus ignorés, textes reçus neutralisés (`|`) et bornés ; débit limité, rien en combat ; clés de joueur normalisées (`ns:TrainerKey`) ; cache des détenteurs 14 j ; `Menu.ModifyMenu` sur les menus de joueur ; ligne d'infobulle via `ns.UNIT_TOOLTIP_LINES` (`Tooltips.lua`).
- Relecture indépendante après fusion : 11 défauts corrigés (coût quadratique de `CaptureData`, fiche construite seulement à l'envoi, casse des noms, sondes et morceaux non fiables, usurpation du nom, valeurs secrètes…).

## QuestCompanion 1.6.1 / Ready2Quest 1.29.3 — mémoire

Mesure : `python3 tests/run_tests.py --memoire` charge les deux addons comme un client français (sans le mode test, sans jouer les tests) et donne la mémoire Lua laissée par chaque fichier, code compilé compris, après ramassage.

| | avant | après |
|---|---|---|
| QuestCompanion | 5,8 Mo | 2,1 Mo |
| Ready2Quest | 0,89 Mo | 0,77 Mo |

- **Tables de zones paresseuses** (`ns.LazyZones`, `QuestCompanion/Core.lua`) : `ZoneCreatures_<client>.lua` et `ZoneQuests_<client>.lua` (générés) gardent une fonction par zone ; la zone n'est construite en tables qu'à sa première lecture, puis gardée. Créatures 2,1 → 0,45 Mo, quêtes 1,27 → 0,33 Mo. `pairs` ne voit pas les zones pas encore lues : parcourir avec `ns.ZoneIds(t)` et `ns.ZoneEach(t, fn)` (le Pokédex parcourt tout le jeu sans rien retenir).
- **Une seule langue** (`Libs/Socle/Strings.lua`) : le client ne garde que sa langue ; sur un client anglais, une clé sans traduction prend le français dès sa déclaration (même repli qu'avant). Les tables sources exposées aux tests de parité (`ns.*_STRINGS`, `ns.PERSONALITY_LINES`) ne sont gardées qu'en test (`ns.KEEP_STRINGS`, global `ADDON_TESTING` posé par le harnais). Répliques de caractère 0,98 → 0,18 Mo.
- **Animation du compagnon** (`CompanionFx.lua`) : au repos, plus de repositionnement ni de table neuve à chaque image ; particules tassées sur place.

## QuestCompanion 1.5.1 → 1.6.0 / Ready2Quest 1.29.1 → 1.29.2

- **Listes déroulantes du socle** (`Theme.CreateDropdown`) : une seule ouverte à la fois (`Theme.openDropdown`), ouvrir une liste referme l'autre.
- **Métiers** (`Gathering.lua`) : `ns:ReadProfessions` lit `GetProfessions` / `GetProfessionInfo` (moteur récent de Forever, sans `GetSkillLineInfo`), reconnus par leur ligne de compétence (`ns.PROFESSION_LIST`, `GatheringData.lua`), puis l'ancienne fenêtre de compétences si elle existe ; dernière liste complète gardée (`journal.professions`). `/qc metiers` : diagnostic. `ns:GatheringZoneList(zoneID, withLocked)` : ce que la zone offre à ta compétence, même gris (compté), et ce qui demande plus de compétence (`locked`, montré en fin de liste, jamais compté).
- **Page Exploration** (ex-Complétion) ; carte « Lieux ». Infobulle des monstres (`Tooltips.lua`) tournée vers la capture.
- **Souvenirs** (`Memories.lua`, retiré en 2.6.0) : `ns:MemoryPose(memory, duo, position)` — huit plans (`ns.MEMORY_SHOTS`, pas de 3 sur 8 : deux voisins jamais pareils), gestes que les créatures savent faire (`ns.MEMORY_ANIMS`), `SetPortraitZoom` pour les gros plans. Décor : `ns:MemoryArt` pose l'écran de chargement du client par identifiant de fichier (donjons et raids classiques recadrés sans logo, lieux propres à Forever, continent vu du ciel pour le premier vol), sinon `ns:MemoryBiome` choisit un des paysages peints par `tools/gen_memory_scenes.py` selon la zone (`ns.MEMORY_ZONE_BIOME`) ; les souvenirs retiennent `map` (uiMapID) et `instance` (8e retour de `GetInstanceInfo`), les anciens sont retrouvés par leur nom.
- **Capture** (`CaptureStage.lua`) : filet maillé en cordes (textures fines tournées), `ns.CaptureDrawNet` (pose, resserrement, fermeture, déchirure corde par corde).
- **Compagnon capturé** : `ns:CompanionName()` rend le nom de l'espèce ; `ns:CompanionOwnName()` celui donné à la mascotte.
- **Brillants** (QC 1.6.0) : fiche de capture à deux versions (`normal`/`at`, `shiny`/`shinyAt` ; migration des anciennes fiches), `ns:CaptureHas(npc, shiny)`, apparences `cap:<npc>` et `cap:<npc>:s`, lumière dorée `ns.ModelShinyLight` (`SetLight`, forme récente en table puis liste historique, lumière d'origine relue par `GetLight`). `ns:ShinyKnown` (repérée, abattue), `ns:ShinyChance(class, killed)` (×3,75 au plus après 50 abattus de l'espèce), missions de la semaine `shinyKill` / `shinyCapture` (une par semaine), losange doré sur la barre de nom (`ns:ShinyPlatesRefresh`).
- **Portée d'aggro** (R2Q) : `aggroStyle` = `dot` (défaut), `bar` ou `ring`.

## Ready2Quest 1.27.0 — Place au butin, Rangs de sorts

- **Place au butin** (`LootRoom.lua`, après `BagSpace.lua`) : `LootRoomLoot()` (objets du butin sans place ni pile à compléter, quêtes d'abord puis valeur), `LootRoomRows(cible)` (les `LOOTROOM_ROWS` premiers de `BagSpaceCandidates()`, mêmes protections, prix HV par `LootRoomAuction` : Auctionator `API.v1.GetAuctionPriceByItemLink`, sinon TSM `DBMarket`), `dearer` si la valeur dépasse celle du butin. `LootRoomDelete` : confirmation (`StaticPopup`) pour qualité ≥ 2 si `lootroomConfirm`, sinon `LootRoomDestroy` (vérifie la case, `PickupContainerItem`, `DeleteCursorItem`, puis `lootRoomPending` = case du butin, ramassée par `LootSlot` au `BAG_UPDATE_DELAYED`). `LootRoomIgnore` → `bagspaceKeep`. Déclencheurs : `LOOT_OPENED`, `UI_ERROR_MESSAGE` (sacs pleins) pendant un butin ; `LOOT_CLOSED` ferme. `/r2q place`. `BagSpaceAlert` s'efface si `LootRoomActive()`.
- **Rangs de sorts** (`SpellRanks.lua`) : `SpellRankOf` (nom, rang lu dans le sous-texte), `SpellRankBook` (meilleur rang par nom : `C_SpellBook` + `Enum.SpellBookSpellBank.Player`, sinon onglets et `GetSpellBookItemInfo`), `SpellRankScan` (cases 1-120, `GetActionInfo`), ignorés par case dans `db.spellranksIgnore["case:sort"]`. `SpellRankUpdate` : hors combat, case inchangée, `PickupSpell` + `PlaceAction` + `ClearCursor`. `SpellRanksCheck` : icône `ShowNotice{ kind = "spells" }` et chat quand le nombre augmente, remis à la fin du combat. Check `barranks` (pas « spellranks » : id du module). `/r2q sorts`.
- Tests `[LOOT]`, `[RANK]` (`tests/modules/lootroom.lua`).


## QuestCompanion 1.2.0 — neuf créatures, deux caractères

- **WoW Forever seulement** (QuestCompanion 1.2.0, Ready2Quest 1.26.1) : `## Interface: 16001` et `## Interface-Camelot: 16001` ; tables `*_Era.lua` retirées du `.toc` et du dépôt ; `tools/gen_zone_data.py` ne génère plus que Forever (`--flavor` par défaut) ; `data/era/` reste comme source des outils (Places, Hubs). Le code de compatibilité Era (Compat, gardes de client) est gardé, sans test de données Era. Les contenus nouveaux ne sont plus vérifiés que dans le build de Forever.
- **Fin du support d'Era (nettoyage)** : WoW Forever tourne sur un moteur récent (`/diag` : `auramodern`, `container`, `crafting`, `questlogNamespaced` à `true` ; `craftLegacy`, `questlogLegacy`, `tradeskillLegacy` à `false`). Retirés : le chemin « recette sélectionnée » de `Reagents.lua` (`TRADE_SKILL_*`, `CRAFT_*`), la lecture du journal par `GetNumQuestLogEntries` / `GetQuestLogTitle` (`QuestLogReady`, repli de `Dungeon.lua` et d'`Expedition.lua`), les sondes `tradeskillLegacy`, `craftLegacy`, `questlogLegacy`, les gardes « Forever seulement » (donjons de Forever, module « Kit de camp » toujours chargé), les fourchettes Era de `DungeonData.lua`, le bloc `era` de `Places.lua`, `data/era/` et la gestion d'Era dans les outils (`gen_hubs.py`, `gen_places.py`, `gen_dungeons.py`, `import_client.py`, `import_questie.py`, `gen_zone_data.py`). `ns:IsForeverClient()` reste : les tables de zone générées s'en servent comme garde. Gardés : les replis d'une ligne (`C_Container`, `C_Item`, `UnitAura`, livre de sorts, onglets de talents), la détection des vivres par sous-classe et les noms de cadres d'Era dans les listes, encore incertains sur Forever. Nouvelles sondes `/diag` pour les trancher : `spellbookModern`, `unitAuraLegacy`, `itemInfoGlobal`, `specialization`. Tests : les scénarios « mode Era » tournent dans le monde Forever du harnais.
- **Vérification des modèles** : `CreatureDisplayInfo` et `CreatureModelData` (CSV wago.tools, builds 1.15.9.70576 et 1.60.1.70753), chemins des fichiers par la liste communautaire `wowdev/wow-listfile` (l'API de recherche de wago.tools ne répondait plus). Gardés : même `.m2` et mêmes textures dans les deux builds. Nos 15 apparences d'avant repassent le même contrôle. En réserve, vérifiés aussi : chats sacré de Birmanie 5585, maine coon 5448, cornish rex 5586, grand-duc brun 4566, crapauds 1924 et 6297, serpents 1206, 1986, 1987, 2954 à 2958, bébés murlocs 15394 à 15398, cafard 2177, rat blanc 2176, bonhomme de neige 13610, petit renne 15901, mini Diablo 10992, zergling 10993.
- **Catalogue** (`CompanionData.lua`) : six apparences de coffre (`tier` 1 à 3, deux par palier) et trois hors coffres (`tier` 0) dont l'`unlock` n'est pas un compteur : `{ inn = 3 }` (poulet, `Daily.lua` : `inn.full`, `INN_APPEARANCE_CARDS`), `{ missions = 10 }` (écureuil, `daily.perfect`, `MISSION_APPEARANCE_DAYS`), `{ shiny = 50 }` (hippogriffe, quatrième palier de `SHINY_REWARDS`). `DailyGrantAppearance` débloque une fois (chat et bulle `UNLOCK`). `CompanionNextUnlocks` ignore tout `unlock` sans `level` ni `stamp` ; `CompanionRequirement` dit `inn`, `missions`, `shiny`.
- **Caractères** (`Personality.lua`, `PersonalityLines.lua`) : `fearful` (énergie, effets ×1,3, exclusif `chicken` ; remarque en combat sous 60 % de vie, une fois par combat) et `tinker` (curiosité, ×0,9, exclusif `squirrel_mech` ; remarque toutes les 20 min). `PERSONALITY_ORDER` passe à 14 (la réglette suit). Missions du jour : `rest` ×10 et `talks` ×4.
- **Fiche au survol** (`Companion.lua`) : `CompanionLayoutHover` place tout de haut en bas (largeur 200, hauteur selon le contenu), rappelée par l'enveloppe du caractère.
- **Cadres et fonds des images du jeu** (`CompanionData.lua`) : chemins vérifiés dans `ManifestInterfaceData` des deux builds (35 651 fichiers communs). Cadres `stone`, `toast`, `glue`, `carved` (`backdrop` non teinté) ; fonds `mail_*` (`Stationery_*1`), `deeds`, et quatre écrans de chargement recadrés par `coords` (`CompanionApplyBackground` appelle `SetTexCoord`, remis à 0-1 pour les autres, `frame.bgCoords`). Écartés : fonds de race et de talents (découpés en quatre).
- **Valeurs secrètes (Forever, moteur récent)** : `ns.Plain(v)` (Socle, `Compat.lua`) rend `nil` si `issecretvalue(v)`. Utilisé pour `UnitHealth`/`UnitHealthMax` (Advice, remarques Zen et Peureux) et `GetRaidTargetIndex` (Shiny). Toute nouvelle lecture de vie, de puissance ou d'icône doit passer par lui.
- **Morts au bestiaire sans journal de combat** : `BestiaryOnXP` (événement `CHAT_MSG_COMBAT_XP_GAIN`, `ParseCombatXP` nommé) compte la cible morte (`units[guid]` ou `Adopt`). `bestiaryKilled[guid] = { at, source }` empêche la double prise entre « xp » et « log » pendant 120 s. `ns.bestiaryStats` (événements, coups, PARTY_KILL, UNIT_DIED, victimes, dont par l'XP) dans `/qc diag` (`DiagExtra`). `coreFiles` compte aussi Bestiary, Treats, Shiny, Daily, Notify.
- Tests `[PETS]`, `[HOVER]`, `[FIX]`, `[BSTXP]`, `[SECRET]`.

## QuestCompanion 1.1.0 — complétion gamifiée

### Friandises (`QuestCompanion/Treats.lua`)

Chargé après `Personality.lua` (lit `CompanionTrait`), avant `JournalWindow.lua`. Données par personnage dans la créature : `data.pantry` (biscuit, infusion, bonbon, carte, festin ; ramené dans `[0, TreatCap]` à chaque lecture), `data.milestones[zoneID]` (plus haut palier réclamé), `data.treatsInit` (rattrapage fait). Plafonds `TREAT_RULES.cap` (3) et `festinCap` (2). Paliers `TREAT_RULES.milestones` (25, 50, 75) d'une zone à au moins deux parts (comme le coffre) : 25 et 50 donnent `TreatForLowestNeed()` (égalité : faim, énergie, moral, curiosité), 75 un Festin. `TreatGrant` range, ou fait manger si la case est pleine (bulle `TREAT_FULL`) ; `TreatGive` (joueur) et `TreatEat` (envie(s) à 100 par `CompanionAdd`, effet `crumbs`/`hearts`/`alert`/`bounce`, Gourmand +`gluttonMood` de moral, bulle forcée `TREAT_EAT_<sorte>` ou `TREAT_SNIFF` pour la carte avec la part la moins avancée de la zone). Vérification par enveloppe de `RefreshJournalTracker`, après le coffre (sa bulle passe d'abord) ; la première fois, `TreatCatchUp` parcourt `JournalKnownZones` en silence puis dit `TREAT_RETRO` (mangées > 0) ou `TREAT_RETRO_KEPT`. Enveloppe de `ChestCheck` : coffre doré → Festin + deux `TreatRandom()` (`chest.treats`), bulle `TREAT_GOLDEN`. Enveloppe de `CompanionPet` : Maj (`IsShiftKeyDown`) ouvre ou ferme `treatMenu` (5 boutons, icônes `TREAT_ICONS`, compteur, grisé à 0) au lieu de la caresse. Répliques dans le registre commun (`COMPANION_POOLS`, `COMPANION_LINE_STRINGS`), variantes `__glutton`. Tests `[TREAT]`.

### Créatures brillantes et coffre animé (`QuestCompanion/Shiny.lua`)

Chargé après `Treats.lua`, avant `JournalWindow.lua`. Enveloppe de `BestiarySeeUnit` : une espèce retenue → tirage une fois par GUID (`shinyState.rolled`, vidé au-delà de 5000), `ShinyRoll` = `SHINY_CHANCE` (1/150 ; **0 dans le banc de test**, `run_tests.lua`, que `companion_shiny.lua` règle) × `SHINY_RANK_MULT` pour `SHINY_RANKS`. `ShinySpot` : `shinyState.live[guid]` (zone, PNJ, nom), bulle forcée `SHINY_SPOTTED`, effets `alert` et `sparkle` (ajouté à `COMPANION_FX`), `ShinyMark` → `SetRaidTarget(unit, SHINY_MARK)` si `companionShinyMark`, pas de `GetRaidTargetIndex`, seul ou `UnitIsGroupLeader`. Enveloppe de `BestiaryCombat` : le compteur `killed` de l'espèce d'une brillante vivante a monté → `ShinyKill` (`data.shiny.count`, `data.shiny.zones[zone][PNJ]` = date, `TreatGrant` Festin à `SHINY_FESTIN_CHANCE` sinon `TreatRandom`, `MemoryRecord("shiny")` avec photo, bulle `SHINY_KILLED`, `ShinyCheckRewards`) ; `UNIT_DIED` sans compte → oubliée. Cosmétiques `SHINY_REWARDS` (tier 0, `unlock = { shiny = n }`, ajoutés à `COMPANION_FRAMES`/`BACKGROUNDS`/`ORNAMENTS`, débloqués ici seulement) : `sparkle` (5), `stardust` (15), `aura` (30, `companionOrnAura`, ligne ajoutée à la sous-page Ornements, étincelles toutes les `SHINY_AURA_EVERY` s). `CompanionRequirement` les dit (« 15 brillantes ») ; `CompanionNextUnlocks` les retire (pas d'objectif au compteur). Carnet : étoile et liseré doré sur la fiche (`ShinyFound`), ligne `SHINY_PREV` dans l'aperçu, nombre sur la tuile (`ShinyZoneCount`), ligne `evo.shiny`. Coffre : enveloppe d'`OpenChest`, boutons à alpha 0 puis révélés un par `CHEST_REVEAL_STEP` s (`ChestRevealStep`), tout remis visible si la fenêtre se ferme ; réglage `companionChestAnim`. Page `companionDaily` (`DAILY_OPTION_ROWS`). Tests `[SHINY]`, `[CHESTFX]`.

À vérifier en jeu : `SetRaidTarget` sur la cible et le survol, l'étoile en groupe, l'aura, le cadre et le fond.

### Au jour le jour (`QuestCompanion/Daily.lua`)

Chargé après `Shiny.lua` (sa page de réglages `companionDaily` reçoit `companionMissions` en tête). Jour = `date("%Y-%m-%d")` (`DailyToday`). Fidélité : `data.inn` (`card`, `total`, `day`), enveloppe de `CompanionOnNpc` (« innkeeper » : `InnStamp`, une fois par jour, +`INN_ENERGY`, Festin et carte remise à zéro à `INN_CARD` ; sinon l'avis habituel). Missions : `data.daily` (`day`, `zoneID`, `missions`, `rerolled`, `allDone`) ; tirage par `DailyPoll` toutes les `MISSION_POLL` s (**coupé dans le banc de test** : `DAILY_AUTO = false`), dans la zone de `JournalZone` : deux de `DAILY_ZONE_MISSIONS` faisables (`MissionFeasible` : `BestiaryCounts`, `GatheringZoneBand`, parts `quests`/`villages` de `ZoneCompletion`, pourcentage), repli `kills` puis `talks`, et celle du caractère (`DAILY_TRAIT_MISSIONS`, `pets` ×3 avant formation). `MissionReroll` une fois par jour (missions de zone non faites). Avancée : `MissionEvent(sorte, n, zone)` par enveloppes (`CompanionPet` hors Maj, `CompanionOnKill` dédoublonné par `companionRT.lastKill`, nuit par `GetGameTime`, `CompanionEliteKilled`, `CompanionCheckAuras`, `CompanionOnStamp`, `GatheringRecord`, `CompanionOnDead` remet `calm` à zéro, `CompanionTick` pour `rest`/`calm`/`gold`, `QUEST_TURNED_IN`) ; les missions d'une zone ne comptent que dans leur zone ; `species` et `percent` mesurées par `MissionRemeasure` à chaque `RefreshJournalTracker`. Faite : `TreatForLowestNeed`, +`MISSION_CURIOSITY`, bulle `MISSION_DONE` ; les trois : Festin, `MISSION_ALL` (bulles en catégorie « event »). Objectifs `mission:<n>` (source `RegisterGoalSource`, clic : onglet Jour). Carnet : section `day` (`BuildDay`, `RefreshDay`, compteur dans l'onglet par `DayNavLabel`). Tests `[DAY]`, `[MIS]`, `[DAYW]`.

### Annonces du carnet et cadre qui brille (`QuestCompanion/Notify.lua`)

Chargé après `Daily.lua`. Enveloppes : `BestiaryCombat` (le compteur `killed` de l'espèce d'un mob repéré passe de 0 à plus : part `named` si `BestiaryIsNamed`, sinon `bestiary` ; une brillante vivante est laissée à `Shiny.lua`), `GatheringRecord` (première récolte de la ressource dans la zone, nom par `GetItemInfo` ou `GatheringZoneBand`), et l'événement `QUEST_TURNED_IN` (`questID` dans `ZoneQuestList` de la zone). `NotifyFound` dit `FOUND` (forcée, nom + `NotifyPartText` : « bestiaire 13/24 ») au plus toutes les `NOTIFY_GAP` s ; sinon `notifyState.pending` augmente, et `NotifyFlush` dit `FOUND_MANY` dès l'écart suivant. Liseré : 4 textures `ADD` dorées de 2 px (`frame.glow`), alpha `GlowAlpha` = `GLOW_ALPHA` × (0,6 + 0,4 sin) tant que `companionBubbleUntil` court, puis extinction en `GLOW_FADE` s ; mis à jour à chaque image (`GlowUpdate`). Tests `[NOTIFY]`, `[GLOW]`.

À vérifier en jeu : la fréquence des annonces en début de zone, l'éclat du liseré sur les différents cadres et fonds.

### Nouveau carnet (`QuestCompanion/JournalWindow.lua`)

Fenêtre 820 × 560 (`JOURNAL_LAYOUT`), colonne de navigation à droite (`frame.sections` : `zones`, `completion`, `evolution`, `collection`, `memories` ; libellés Zones, Zone, Créature, Collection, Souvenirs). `frame.kind` est retenu dans `db.journalTab` et rétabli à l'ouverture (`ToggleJournal`) ; `CompanionOpenJournal` (clic droit) ne force plus d'onglet ; `OpenJournalFor` ouvre la zone d'un objectif (`goal.zoneID`). Zones : `JournalAllZones(filtre, tri)` réunit `ZONE_LEVELS`, les clés de `ZONE_CREATURES` et `ZONE_QUESTS` du client (zones propres à Forever 2482, 2521, 2548, 2652 et Reflet-de-Lune 1450 comprises) et `JournalKnownZones` ; tranche par `ZoneLevelRange` (CompanionChest.lua : `ZONE_LEVELS`, sinon calculée sur les créatures normales préremplies, un dixième écarté de chaque côté, mise en cache dans `ZoneLevelCache` ; utilisée aussi par `ZoneTier`) (`seen`, `percent` si deux parts, `chest`, `continent` par `parentMapID` 1415/1414), tuiles 6 × 4 (`frame.zones.tiles`, défilement par rangée). Zone : `StepJournalZone` (ordre par niveau, en boucle), `marks` 25/50/75/100 (or si réclamé, `TreatData().milestones`), en-têtes des parts dans `comp.heads`, puis selon l'onglet `comp.lines` (2 colonnes × 15, Exploration et Quêtes, filtre `frame.questFilter`), `comp.cards` (4 × 7, Combat, liseré `RANK_COLOR`, « ??? » si ni vue ni abattue) ou `comp.icons` (8 × 5, Métiers, `GetItemIcon`) ; `frame.step` = colonnes, la molette avance d'une rangée. Aperçu `comp.preview` (`PlayerModel`, `SetCreature(npcID)`) par `JournalPreviewCreature`. Collection : `JournalCollection(sorte)` (`owned` par `CompanionIsUnlocked`, `equipped`), `JournalEquip` (apparence, `CompanionSetStyle`, ornement basculé dans `db[def.key]`), `JournalPreviewCosmetic` (`SetDisplayInfo`, aplat ou texture), source par `JournalCosmeticSource`. En-tête : `frame.pantry` (Treats.lua), suivi par une enveloppe de `TreatMenuRefresh`. Souvenirs : `BuildMemoriesPane(frame, top + 30, largeur)`. Bouton 4 de la souris : retour à la grille. Tests `[WIN]`, `[ZONES]`, `[COLL]`, `[JPAN]`, `[JRNW]`.

À vérifier en jeu : l'aperçu 3D (`SetCreature` sur une créature jamais chargée par le client peut rester vide), les icônes de ressources, la lisibilité des tuiles et des fiches, `Button4`. À vérifier aussi : les icônes `INV_ValentinesCandy`, `INV_Misc_Map_01`, `INV_Misc_Food_11`, `INV_Drink_07` sur Era et Forever ; le menu au-dessus de la créature, à toutes les tailles.


> Document destiné au développement : historique version par version, choix d'API, compatibilité des clients, tests. Pour la présentation de l'addon, voir le [README](../README.md).


## v1.26.0 — deux addons autonomes : Ready2Quest 1.26.0 et QuestCompanion 1.0.0

Ready2Quest faisait deux métiers : préparer la sortie (check, retour, donjon, camp, stuff, QoL) et accompagner la progression (compagnon, carnet, complétion de zone, coffres). Le second pesait deux tiers du code, dont ~12 000 lignes de données de zones. Il devient un addon à part, **QuestCompanion**, qui fonctionne seul. Une première version le faisait dépendre de Ready2Quest (namespace partagé, réglages dans le panneau de Ready2Quest) ; testée en jeu, elle ne séparait pas assez : tout restait dans le même panneau.

### Dépôt

Rangé comme `Interface/AddOns` : `Ready2Quest/` et `QuestCompanion/` côte à côte, chacun avec son `.toc`, son `LICENSE`, son `CHANGELOG.md` et son `README.md`. `docs/`, `tests/` et `tools/` restent à la racine.

### Socle commun (`Libs/Socle`)

Ce dont les deux addons ont besoin est sorti du cœur de Ready2Quest vers `Libs/Socle`, embarqué dans chaque addon comme une lib WoW :

| Fichier | Contenu |
|---|---|
| `Base.lua` | commande toujours disponible (même si un fichier plante), `ns.Mark`, `ns:RecordError` (ex-`Bootstrap.lua`) |
| `Strings.lua` | `ns.L`, `ns.RegisterStrings`, `ns:F`, `ns:Print`, `ns.AsciiLower`, textes communs (réglages, commandes) |
| `Compat.lua`, `Hubs.lua`, `DungeonData.lua`, `Theme.lua` | inchangés ; le thème prend ses médias dans `Libs/Socle/Media` (losanges, police Alegreya) et le logo dans `Textures/` de l'addon |
| `Store.lua` | `ns:DB()` (nom de la sauvegarde et anciens noms dans `ns.APP`), `ns:ResetDB()`, `RegisterDefaults`, callbacks, modules, `CharKey` / `CharData`, `RestorePoint`, `Now` ; à `ADDON_LOADED`, repart de la sauvegarde posée par le client puis appelle `ns:OnAddonLoaded()` |
| `World.lua` | carte et lieux (`CurrentMap`, `MapChain`, `CurrentSubZone`, `KnownHub`, `InInstance`, `AtCamp`), donjons (`DetectDungeon`, `DungeonName`, `DungeonRange`, `IsForeverClient`), `AuraByIndex`, `ConsumableKind`, `ParseCombatXP`, `ParseSelfLoot` (sortis de `Core`, `Buffs`, `Checks`, `LevelPace`, `Expedition`, `Dungeon`) |
| `Commands.lua` | registre `ns.COMMANDS` (`EXTRA_COMMANDS` = même table), aide, commandes communes (`help`, `options`, `minimap`, `modules`, `module`, `reset`, `diag`), crochets `DefaultCommand`, `OnModuleToggled`, `DiagExtra` |
| `Options.lua` | panneau de réglages générique : pages (`ns.AddOptionPage`), listes (`ns.OPTION_LISTS`), actions (`ns.OPTION_ACTIONS`), bouton principal du pied (`ns.OPTIONS_MAIN`), fenêtres exclusives (`ns.EXCLUSIVE_WINDOWS`) |
| `Minimap.lua` | bouton de minicarte : clic gauche `ns:DefaultCommand()`, clic droit les réglages, infobulle complétée par `ns:MinimapTooltip()` |

Chaque addon décrit son identité dans `Config.lua`, chargé en premier (`ns.APP` : nom, version, nom en tête du panneau, sauvegarde, anciens noms, commandes, fichiers attendus). Le socle ne nomme aucun des deux (test `[QC]`). Source unique : `Ready2Quest/Libs/Socle` ; `tools/sync_socle.py` la recopie dans `QuestCompanion/Libs/Socle`, et `tests/run_tests.py` refuse de tourner si les copies diffèrent. Ready2Quest garde ses pages de réglages dans `OptionPages.lua`.

### QuestCompanion autonome

- Namespace propre (`local ADDON, ns = ...`), sauvegarde `QuestCompanionDB` (réglages et progression : `chars[clé].companion`, `.journal`), commande `/qc` (`/questcompanion`), panneau de réglages (Général, Compagnon de route et sa sous-page Carnet), bouton de minicarte au dragonnet. `/qc` seul et le clic gauche ouvrent le carnet. `/qc reset` garde la progression.
- `## OptionalDeps: Ready2Quest` : s'il est là, Ready2Quest charge d'abord, avec sa sauvegarde. Deux liens facultatifs :
  - **reprise** : à `ADDON_LOADED("QuestCompanion")`, ce que Ready2Quest 1.25 rangeait dans `Ready2QuestDB` passe dans `QuestCompanionDB` : réglages `companion*` et `journal*` (positions des cadres comprises), compagnon et carnet de **tous** les personnages. Une fois (`migratedFromR2Q`) ; une progression déjà commencée dans QuestCompanion l'emporte ; sans `Ready2QuestDB`, rien n'est marqué et on réessaiera ;
  - **départs et retours** : les callbacks `DEPARTURE` / `RETURN` de Ready2Quest (`_G.Ready2Quest`) sont relayés au compagnon.
- Face à un **Ready2Quest 1.25**, qui embarque encore le compagnon (`_G.Ready2Quest.Loaded.Companion`), `Config.lua` pose `ns.blocked` : chaque fichier de QuestCompanion sort dès sa première ligne, avec un message qui demande de mettre Ready2Quest à jour. Sinon, deux compagnons à l'écran.
- Les textes qui citaient `/r2q compagnon`, `/r2q carnet`, `/r2q coffre` disent `/qc …` ; les astuces du compagnon ne parlent plus des fonctions de Ready2Quest.

### Ready2Quest

Comportement inchangé, sans le compagnon : ses réglages, ses commandes et ses modules ne le montrent plus. `/r2q reset` ne touche plus à la progression du compagnon, qui n'est plus chez lui.

### Rapports annoncés par une icône (`Notice.lua`)

- Les trois rapports automatiques ne s'ouvrent plus seuls : `RunChecklist` (hors check manuel), `ExpeditionFinish` et `ShowDungeonSheet` posent une icône (`ns:ShowNotice`) quand `db.reportIcon` est vrai (défaut). Coupé, l'ancien comportement revient.
- Icônes du jeu, présentes sur Era et Forever : `Interface\GossipFrame\AvailableQuestIcon` (« ! ») et `ActiveQuestIcon` (« ? »), désaturées puis teintées ; halo `Interface\Buttons\UI-ActionButton-Border` en mode additif, de la même couleur.
- Couleurs : départ, barème de la note (`Theme.ScoreColor`) ; retour, rouge si mort, orange s'il faut réparer (durabilité sous le seuil du check) ou racheter, bleu sinon ; donjon, rouge si trop bas niveau, orange si une ligne de préparation échoue, bleu sinon.
- Vie de l'icône : pulsation `NOTICE_PULSE` (8 s), puis atténuée (alpha 0,6) `NOTICE_LINGER` (60 s), puis cachée. Une seule à la fois, la plus récente. En combat, elle attend `PLAYER_REGEN_ENABLED`. Clic : `onClick` du rapport ; clic droit : ignorée. Position mémorisée (`noticePoint`), placée avec le mode édition (`StartEditMode` / `StopEditMode` enveloppés).
- **Barème unique** (`Theme.ScoreColor`, `Theme.ScoreTextColor`, socle) : 0-24 rouge, 25-59 orange (`ORANGE_DEEP`, nouveau), 60-84 ambre, 85+ vert. Avant, la couleur de la note basculait à 55 et le verdict à 60.
- Tests `[NTC]` (`tests/modules/notice.lua`) ; les tests qui visent les fenêtres (expédition, donjon) coupent l'icône. Vérifiés par mutation.

### Compagnon utile : réglette « Bavardage » et conseils de route

- **Réglette** (`companionChatter`, 0 à 4, `COMPANION_CHATTER`) : catégories permises, écart entre bulles et entre conseils, facteur des pauses. Nouvelle catégorie de bulle `advice` (priorité entre réaction et tutoriel) ; `opts.important` pour ce qui passe au cran Discret. Reprise des anciens interrupteurs. Socle (Options) : une ligne numérique peut afficher un nom (`display`), une phrase dessous (`describe`), une infobulle (`tooltip`) et prévenir l'addon (`onChange`).
- **Socle `Gear.lua`** : lecture de l'inventaire, sortie de `Checks.lua` de Ready2Quest : `EachBagItem`, `FreeBagSlots`, `CountConsumables`, `QuestLogReady`, `QuestCounts` (nouveau), `LowestDurability` (nouveau, utilisé aussi par le contrôle de durabilité), `HearthCooldown`, `AmmoCount`, `AmmoInBags`, `ReagentMinimum`, `AMMO_MINIMUM`, `PlayerLevelNow`, `PlayerClassToken`.
- **Conseils de route** (`QuestCompanion/Advice.lua`) : règles dans l'ordre `ADVICE_ORDER` (élite, vie, munitions, vivres, durabilité, sacs, quêtes, foyer), chacune avec un palier (1, puis 2 si ça empire) ; `state.said` par sortie, remis à zéro dans un lieu sûr. Lieu sûr et seuils : ceux de Ready2Quest via le lien `r2qBridge` (`IsCurrentZoneSafe`, `bagFreeThreshold`, `vivresThreshold`, `durabilityMinPct`), sinon repos, `KnownHub`, `KnownPlace`, sanctuaire, camp, et 3 places / 4 vivres / 25 %. Élites : `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `NAME_PLATE_UNIT_ADDED`, une fois par GUID, hors instance. Vie : à `PLAYER_REGEN_ENABLED`, sous 35 %. Examen toutes les 3 s et sur les événements d'inventaire, de quêtes et de zone.
- **Groupe** (`QuestCompanion/Group.lua`), lecture locale seulement (party1 à 4, rien en raid) : composition une fois le groupe stable 10 s (`GROUP_HEALERS` : prêtre, druide, chaman, paladin ; « bel équipage » à 4 membres et plus avec soigneur) ; niveaux face à la tranche (`DetectDungeon`, `DungeonRange`) une fois par donjon ; hors de vue (`UnitIsVisible`) plus de 90 s sur la même carte, hors combat, hors lieu sûr, ni en vol ; autre carte (`C_Map.GetBestMapForUnit`) plus de 120 s quand on est au donjon ; morts (`UnitIsDeadOrGhost`) et déconnexions (`UnitIsConnected`). Composition, donjon et retards en catégorie `advice`, morts et déconnexions en réactions. Examen toutes les 2 s et à `GROUP_ROSTER_UPDATE`. L'échange entre addons (vivres, durabilité, quêtes des autres) viendra ensuite.
- **Envies renouvelables** : `COMPANION_CURIOSITY` (premières fois : zone +15, sous-zone +4 ; puis zone pas vue depuis 2 h de temps réel +8, `data.zoneVisit` ; sous-zone connue +1 au plus toutes les 30 s ; entrée en donjon +10, pas deux fois en 10 min ; élite ou rare vaincu +8 dans `CompanionOnKill` ; fin de vol +5, vue au tick ; coffre ouvert +20 dans `ChestPick` ; récolte +1 dans `GatheringRecord`). Faim, énergie et moral l'étaient déjà (repas, repos, caresse sans limite toutes les 15 s, quêtes, ennemis). Plancher `SERENE_FLOOR` (50) au dernier stade. Tests `[NEED]`.
- **Effets** (`QuestCompanion/CompanionFx.lua`, chargé après `Companion.lua`) : `ns:CompanionFx(kind)` pour `bounce`, `shake`, `hearts`, `crumbs`, `alert`, `flash`, `zzz` (table `COMPANION_FX` : durée, particules, couleur), plus le flottement continu quand `CompanionIsHappy`. Mouvements par décalage des ancres du modèle (`TOPLEFT` 4,-4) ou de la boussole (`TOP` 0,-14) ; particules (losanges `Theme.CreateDiamond`, texte pour « Zzz ») réemployées depuis une réserve ; un `OnUpdate` à part. Déclencheurs par enveloppe des méthodes existantes : `CompanionPet` (cœurs), `CompanionOnLevel` (rebond), `CompanionSay` si la bulle est partie (`ADVICE_ELITE`/`ADVICE_RARE` : tremblement et « ! » ; catégorie `advice` : « ! » ; `EVOLVE` : rebond), `CompanionCheckAuras` pendant un repas (miettes toutes les 4 s), animation `sleep` (« Zzz » toutes les 3 s). Animations de créature : `walk`, `run`, `attack` ajoutées à `COMPANION_ANIMS` ; celles qu'une apparence ne joue pas sont rangées dans `data.animOff[apparence]` et remplacées par `idle` (la durée compte toujours). `/qc compagnon anim` : défilé `COMPANION_ANIM_ORDER`, `COMPANION_ANIM_STEP` s chacune, y compris les coupées. Tests `[FX]`.
- **Souvenirs** (retirés en 2.6.0 ; `QuestCompanion/Memories.lua`, chargé avant `JournalWindow.lua`, après `CompanionChest.lua` dont il enveloppe `ChestCheck`) : `data.memories` (liste chronologique `{ at, kind, key, args, zone, photo }`), `data.memoryKeys` (une fois par clé ; `replace` pour la mort « la plus bête », notée `data.sillyScore` : chute 100, sinon écart de niveau avec une cible normale d'au moins 3), `data.metAt` (rencontre, temps réel). Déclencheurs par enveloppe : `CompanionOnLevel` (`MEMORY_LEVELS`), `CompanionCelebrate`, `CompanionOnZone` (capitales `MEMORY_CAPITALS`, donjons par `GetInstanceInfo`, en groupe), `CompanionOnKill` (rare, rareelite), `ChestCheck`, `CompanionOnDead` ; coup d'œil toutes les 2 s (`UnitOnTaxi`, `IsMounted`, groupe de 5, anniversaires `MEMORY_ANNIVERSARIES` puis chaque année, sans rattraper les paliers sautés ; rappel `RECALL` au plus toutes les `MEMORY_RECALL_GAP` s de jeu, souvenir d'au moins 1 h). Photos (`MEMORY_PHOTO_KINDS`) : réglage `companionPhotos` (faux par défaut) et `companionPhotosAsked` (nil, asking, later, yes, no) ; question par `StaticPopup` à trois boutons au premier moment, « Plus tard » redemandé après `MEMORY_ASK_AGAIN` ; une photo à la fois, `MEMORY_PHOTO_DELAY` s après (repoussée tant qu'on est en combat, abandonnée après `MEMORY_PHOTO_WAIT`), bulle `PHOTO` puis `Screenshot()` `MEMORY_PHOTO_CLICK` s plus tard ; `SCREENSHOT_SUCCEEDED` donne le nom (`WoWScrnShot_MMJJAA_HHMMSS.jpg`, heure locale) et l'éclair, `SCREENSHOT_FAILED` rend le quota (`MEMORY_PHOTO_PER_DAY`, `data.photoDay`). Album : section `memories` du carnet (`BuildMemoriesPane`, `RefreshMemoriesPane`, 8 lignes, défilement commun). Page de réglages `companionMemories`. Socle (Options) : une ligne oui/non accepte `describe(actif)` et `onChange(valeur, avant)`. Tests `[MEM]`.
- **Caractère** (`QuestCompanion/Personality.lua`, répliques dans `PersonalityLines.lua`, chargés après `Memories.lua`) : `data.persona` (`scores`, `played`, `formed`, `unlocked`). Observation tant qu'il n'est pas formé : curiosité gagnée (×0,1, Curieux), début de repas (+3, Gourmand), ennemi vaincu (+0,15) et élite (+2, Téméraire), minute de repos (+0,25, Paresseux), mort (+6, Taquin), caresse acceptée (+2, Câlin) ; à `PERSONALITY_FORM_AFTER` s de jeu, le plus haut score (égalité : ordre de `PERSONALITY_FORMED`), annoncé (chat et bulle `FORMED__<caractère>`). `ns:CompanionTrait()` : celui de l'apparence (`PERSONALITY_BY_APPEARANCE`) si `companionTraitSource` vaut 1, sinon `companionTraitPick` (0 : formé ; caractères d'apparence seulement une fois portés, sautés par la réglette), sinon le formé. Effets par enveloppe : `CompanionPick` (réservoir `<RÉSERVOIR>__<caractère>` dans `PERSONALITY_VARIANT_CHANCE` des cas, mêmes arguments que le commun ou aucun), `CompanionAdd` (envie préférée ×`PERSONALITY_GAIN`), `CompanionDecayFactor` lu par `CompanionTick` (×`PERSONALITY_DECAY`), `CompanionFxIntensity` lu par `CompanionFxUpdate`, `CompanionRefreshHover`. Remarques `NOTICE__<caractère>` (forcées, une par `PERSONALITY_NOTICE_GAP` s ; en réaction pour l'élite du Téméraire, la deuxième mort en 10 min du Taquin, la terre nouvelle du Sage). Page de réglages `companionCharacter`. Tests `[PERS]`.
- Tests `[CHAT]`, `[ADV]`, `[GRP]`, `[FX]`, `[MEM]` et `[PERS]`, vérifiés par mutation.

### Zones de départ et munitions

- **Vallées de départ** : `gen_hubs.py` ajoute à `Hubs.lua` six vallées et leurs sous-zones internes, de type `start` (22 entrées sur les deux clients). Les sous-zones (la Tanière, Anvilmar…) dépendent de la zone dans AreaTable, pas de leur vallée : elles sont listées à la main ; les passages de sortie (col de Coldridge) n'en font pas partie.
- **Départ silencieux** (`ns:IsQuietDeparture`) : départ d'un lieu `start`, ou personnage sous `QUIET_LEVEL` (6). `UpdatePendingExit` signale quand même le départ (`DEPARTURE`, avec `from.quiet`), mais ne lance ni check, ni icône, ni chat ; l'Expédition ne démarre pas de voyage, donc pas de bilan au retour. `lastSafePlace` garde le type du lieu (`kind`). Le compagnon de QuestCompanion ne salue pas en passant d'une sous-zone de vallée à l'autre.
- **Poids et plafond** : `weight` et `advice` d'un contrôle peuvent être des fonctions. Celui des réactifs de classe pèse `AMMO_WEIGHT` (40) pour un chasseur, `REAGENT_WEIGHT` (15) sinon, avec le conseil `ADV_AMMO`. Un `run` peut renvoyer un 4e résultat, « bloquant » : en échec, il plafonne la note à `SCORE_CAP_BLOCKING` (59, « Pas prêt »). Les munitions sous la moitié du minimum (non équipées comprises, elles valent 0) sont bloquantes.
- **Munitions** : minimum par paliers de niveau (`CLASS_REAGENTS.HUNTER.min = { { 1, 200 }, { 10, 600 }, { 30, 1000 } }`, `ns.ReagentMinimum`). Emplacement de munitions vide mais projectiles (classe d'objet 6) dans les sacs : « aucune équipée (N dans tes sacs) ». Les munitions existent bien sur Forever (carquois, gibecières).
- Tests `[START]` et `[AMMO]` (`tests/modules/start_ammo.lua`), vérifiés par mutation.

### Notre base de données (`data/`) et les lieux sûrs

- **Base** : `data/era/`, `data/forever/`. PNJ, objets et quêtes importés une fois de QuestieDB par `tools/import_questie.py` (corrections statiques, liste noire et événements de Questie appliqués) ; zones, sous-zones et dimensions des cartes importées des tables du client (wago.tools) par `tools/import_client.py`. Nos corrections : `data/<client>/fixes.json`, jamais écrasées. Voir `docs/DONNEES.md`.
- **Générateurs** : `gen_zone_data.py` (tables de zone de QuestCompanion), `gen_hubs.py` (`Hubs.lua`) et `gen_places.py` (`Places.lua`) ne lisent que `data/`, via `tools/zonedb.py`. Les tables de zone régénérées depuis `data/` sont identiques à celles produites depuis Questie ; `Hubs.lua` aussi.
- **Lieux repérés** (`Libs/Socle/Places.lua`) : groupes de PNJ de service amicaux à moins de 60 m l'un de l'autre. Un aubergiste, un maître de vol ou un banquier suffit ; sinon au moins 3 PNJ avec un marchand et un réparateur ou un entraîneur. PNJ techniques et saisonniers écartés. Chaque lieu : centre (x, y en % de la carte de zone), rayon en mètres (PNJ le plus éloigné + 25 m, entre 35 et 160), faction, services. L'échelle de chaque carte (mètres pour 1 %) vient de `UiMapAssignment`. 142 lieux sur Era, 160 sur Forever.
- **Pourquoi des coordonnées** : `UiMapAssignment` ne découpe pas les sous-zones sur ces clients, et la base de Questie range les PNJ par zone (l'aubergiste de Comté-de-l'Or est « Forêt d'Elwynn »). Un camp ne peut donc pas être rattaché à un nom de sous-zone hors du jeu.
- **En jeu** : `ns:KnownPlace()` (socle, `World.lua`) compare la position du joueur (`C_Map.GetPlayerMapPosition`) aux lieux de la carte ; un lieu de l'autre faction est « hostile ». `IsCurrentZoneSafe` le consulte après les lieux connus par leur sous-zone. Entrer dans un camp ou en sortir ne déclenche aucun événement : `ns:CheckPlaceMove` réévalue toutes les 1,5 s, seulement sur une carte qui a des lieux repérés.
- **Garde-fou** : `tests/run_tests.py` régénère les tables de zone, `Places.lua` et `Hubs.lua` à part et refuse de tourner si l'un d'eux ne suit plus `data/`. Tests `[PLC]` : données, position, faction, instance, API absente, départ et retour sans événement de zone ; vérifiés par mutation.

### Publication

`.pkgmeta` et `.pkgmeta-questcompanion` sont symétriques : chacun ignore tout ce qui n'est pas le dossier de son addon, que `move-folders` remonte d'un niveau ; le zip ne contient qu'un dossier. Le garde-fou de `tests/run_tests.py` vérifie que chaque entrée de la racine est ignorée par les deux. Voir `docs/PUBLIER.md`.

### Tests

- Harnais : il lit les deux `.toc` (chemins `Libs\Socle\…` convertis), charge Ready2Quest dans `NS` et QuestCompanion dans sa propre table, `T.QNS`, que reçoivent les tests de ses modules. `ResetWorld` remet aussi `QuestCompanionDB` à zéro. Le mock gagne `UnregisterEvent`.
- Tests `[QC]` : `.toc` (pas de dépendance obligatoire), socle identique et neutre, namespaces, sauvegardes, commandes et modules séparés, panneau et bouton de minicarte propres, reprise depuis Ready2Quest 1.25 (une fois, tous les personnages, rien perdu), `ADDON_LOADED` qui reprend la vraie sauvegarde, `/qc reset` et `/r2q reset`, relais des départs et retours, QuestCompanion chargé **seul** (sans Ready2Quest), et face à un Ready2Quest 1.25.
- Vérifiés par mutation : sans retrait des données de Ready2QuestDB, sans drapeau de reprise, sans reprise au chargement, sans garde de l'ancien Ready2Quest, sans relais, avec un `/qc reset` qui efface la progression, ou sans relecture de la sauvegarde à `ADDON_LOADED`, la suite échoue.
- 2204 assertions.

### À vérifier en jeu

- QuestCompanion **seul** : compagnon, carnet, `/qc`, réglages, bouton de minicarte, pas d'erreur.
- Ready2Quest **seul** : check, réglages sans compagnon, `/r2q carnet` répond « commande inconnue ».
- Les **deux**, sur un personnage qui avait le compagnon avec Ready2Quest 1.25 : créature, carnet et coffres repris après `/reload` ; deux boutons de minicarte, deux panneaux ; le compagnon réagit en quittant la ville.
- QuestCompanion avec un **Ready2Quest 1.25** : message, un seul compagnon.

## v1.25.0 — compagnon de route et carnet de voyage

Deux modules qui rendent le leveling plus ludique. Choix de l'utilisateur :
- **Aspect** : une créature 3D du jeu.
- **Ton** : bienveillant, jamais punitif.
- **Périmètre** : tout dans cette version, y compris la collection.

Comme avant, un agent par module, puis fusion. Le contrat entre les deux tient en trois points :
- le Carnet émet `STAMP` (une copie du tampon) et expose `ns:JournalCounts()` ;
- le Compagnon écoute ces tampons ;
- le Carnet ne dépend pas du Compagnon.

**Compagnon de route** (`Companion.lua`, `CompanionData.lua`)
- **Modèle** : `PlayerModel` + `SetDisplayInfo`. Les numéros sont vérifiés dans `CreatureDisplayInfo` et `CreatureModelData` d'Era 1.15.9 et de Forever 1.60.1 : même modèle et même texture dans les deux clients.
  - Dragonnets : émeraude 6291, cramoisi 6290, azur 6293, bronze 6292, sombre 6288.
  - Autres : rainette 6295, chouette 6300, feu follet 6197, dragon féerique 6294.
  - Animations 0, 68, 69 et 100, vérifiées dans `AnimationData`.
  - Pas de renard : aucun modèle de renard n'existe dans Era.
  - Si l'API de modèle manque, la boussole le remplace.
- **Besoins** : de 0 à 100, avec un plancher à 15. Ils ne baissent qu'en jeu. Une absence de plus de 2 h donne seulement un état « somnolent ».
- **Stades** : à 10, 20, 40 et 60, sans jamais revenir en arrière. Le premier relevé est posé sans fête.
- **Accessoires** : ils deviennent des **apparences** et des **ornements de cadre**, parce que Classic n'a pas d'API pour accrocher un objet sur un modèle de créature.

**Carnet de voyage** (`Journal.lua`)
- **Tampons** : zone (première carte de type Zone en remontant les parents), village (lieux de `Hubs.lua`, de sa faction ou neutres, hors auberges), capitale (toutes factions), donjon (`ns:DetectDungeon`, sinon `GetInstanceInfo` de type party), palier (tous les 10 niveaux).
- **Rare** : il doit avoir été **vu** (classification rare ou rareelite) puis **engagé** par toi, ton familier ou ton groupe (bits d'affiliation du journal de combat). Le tampon tombe à sa mort (`UNIT_DIED` ou `PARTY_KILL`). Un rare tué par un inconnu ne compte pas.
- **Paliers rattrapés** : ceux déjà atteints à l'installation sont ajoutés en silence, sans bandeau ni `STAMP`.
- **Bandeau** : jamais en combat. Il est mis en file et regroupé à partir de 3 tampons.

**Ce que la fusion a corrigé**
- **Panneau** : 480 → 520 px, la navigation débordait avec les deux nouvelles entrées.
- **Premier relevé du compagnon** : il est maintenant toujours silencieux. Avant, quand les données naissaient hors connexion (module activé en cours de partie, ou premier tampon), il annonçait d'un coup tous les déblocages dus au niveau. Les tests d'autres modules l'ont révélé, et un test d'intégration le couvre.
- **Ornements verrouillés** : leur interrupteur s'affichait allumé. Il est maintenant éteint et estompé (vu sur un rendu, test ajouté).

**Retours après essai** (même version)
- **Un seul module** : le carnet fait évoluer le compagnon, il devient donc sa sous-page. Interrupteur unique `companionEnabled` (`journalEnabled` disparaît), entrée de navigation parente `companion` qui pointe vers `companionMain` ; `ns:SelectOptionsPage` suit le `target` des entrées sans contenu. Alias `/r2q carnet` et `/r2q journal` conservés.
- **Fenêtres exclusives** : le carnet se superposait aux réglages. `ns.EXCLUSIVE_WINDOWS` liste les grandes fenêtres (récap, réglages, carnet, expédition, donjon) et `ns:CloseOtherWindows(keep)` ferme les autres à l'ouverture.
- **Dialogues** (`CompanionLines.lua`) : réserves de phrases fr/en par situation (monstre abattu, manger, boire, PNJ par type — marchand, aubergiste, maître, maître de vol, banquier, donneur de quêtes —, type de créature ciblée, nuit, inactivité…), 26 astuces (toutes les 10 à 15 min de jeu), 10 conversations de quelques bulles (une toutes les 3,5 s). Priorités `chatter < tip < need < reaction < tuto < event` et délais par catégorie pour ne jamais bavarder en boucle ; jamais en combat. Les lignes à `%s` sont écartées si le nom manque.
- **Besoins exprimés** : envies basses → phrase `NEED_*`, pas dans les 2 min après la connexion. `ns:CompanionNextUnlocks()` liste les prochains déblocages (`label`, `kind` app/orn/stage, `stat`, `have`, `need`, `source` player/journal) ; la créature en annonce un de temps en temps (`GOAL`, `GOAL_STAGE`).
- **Tutoriel** : 6 bulles au premier lancement, « Suivant » accélère, `/r2q compagnon tuto` pour le revoir.
- **Objectifs** (`JournalTracker.lua`) : `ns:JournalObjectives()` assemble les déblocages du compagnon, les villages de la zone, les capitales, les donjons du niveau et le prochain palier, triés par proximité. Onglet « Objectifs » dans le carnet (fenêtre 520 px) et bloc « Carnet » à l'écran, ancré sous `QuestWatchFrame` / `ObjectiveTrackerFrame` / `QuestObjectiveTracker`, sinon en haut à droite ; repliable, déplaçable, masqué en combat (réglable). Un test d'intégration branche le vrai compagnon sur le vrai suivi.
- **Résumé de stuff** : bouton « Simuler un changement » (`ns:SimulateGearToast`), qui alterne gain et perte sur la stat principale ; l'aperçu passe en strate `FULLSCREEN_DIALOG` pour rester au-dessus des réglages.

**Suivi « Carnet » refait** (après essai)
- **Mise en page** : 4 objectifs au lieu de 5. Le premier est une « carte » (fond, filet ambre, libellé court `goal.short`, barre de 5 px, progression avec unité `goal.unit`), les trois suivants une ligne avec une mini-barre. Hauteur 18 + 40 + 4 + n × 16.
- **Survol** : chaque objectif porte `goal.hint` (liste de lignes), affiché dans `GameTooltip` par `ns:ShowJournalGoalTooltip`. Les pistes viennent des mêmes données que le calcul : villages manquants de la zone, capitales manquantes, donjons de la tranche avec leur plage, XP restante (`UnitXPMax - UnitXP`). Listes coupées à 6 noms. Les objectifs du compagnon reprennent la piste de leur stat.
- **Donjons** : le libellé redevient court (« Donjons de ton niveau ») ; les noms passent au survol.
- **Clics** : clic sur un objectif → carnet sur l'onglet Objectifs ; clic droit → masquer (inchangé). Clic droit sur la créature → `ns:CompanionOpenJournal()` (même onglet ; déjà ouvert → fermé).

**Complétion de zone** (trois fichiers, deux faits par des agents en parallèle)
- **Points d'extension** (`JournalTracker.lua`) : `ns.RegisterGoalSource(fn(self, list))` et `ns.RegisterZonePart({ id, label, Compute(self, zoneID) → { have, need, hint } | nil })`.
- **`ns:ZoneCompletion(zoneID)`** : les parts qui s'appliquent pèsent autant les unes que les autres (moyenne des ratios). L'objectif « Complétion de <zone> » n'apparaît qu'à partir de deux parts et disparaît à 100 %. Au survol : chaque part, puis la liste de la part la plus proche d'être finie. Dans le suivi, il absorbe les objectifs `villages:`, `bestiary:` et `named:` de la même zone ; s'il est masqué, ils reviennent. Les zones tamponnées affichent leur pourcentage dans l'onglet Zones.
- **Bestiaire** (`Bestiary.lua`) : une espèce est « vue » quand on la cible, la survole ou voit sa barre de nom (hostile ou neutre ; ni joueur, ni familier, ni bestiole). Elle est « abattue » selon la même règle d'engagement que les rares. Données par personnage dans `JournalData().bestiary[zoneID][npcID]`, rattachées à la zone où l'espèce a été vue la première fois ; les instances sont ignorées. Nommés = elite, rare, rareelite, worldboss. Les bestioles sont reconnues par le type traduit (liste multilingue).
- **Récolte** (`GatheringData.lua`, `Gathering.lua`) : table faite à la main de 28 herbes, 9 minerais, 5 pierres, 11 cuirs et peaux (itemID de Classic), avec compétence requise et compétence grise (requise + 100 pour herbes et gisements, approximation pour le dépeçage). Seul le butin (`LOOT_ITEM_SELF*`) compte, et seulement avec le métier. La zone de récolte est retenue. Objectif « ressources de ta tranche » par métier ; si la catégorie des métiers est repliée dans la fenêtre de compétences, on reprend le dernier rang lu.
- Pas de liste de quêtes par zone : le client ne la fournit pas (voir plus bas : tables générées depuis la base de Questie).

**Objectifs et récompenses séparés** (retour du joueur : le carnet mélangeait les deux)
- **Évolution** : le niveau ouvre le stade, le bonheur le franchit. Palier atteint et envies insuffisantes → `data.stageReady`, annonce, objectif « Rends <nom> heureux pour évoluer » (survol : chaque envie et comment la remplir). Évolution dès que les 4 envies sont ≥ 70 % (`CompanionAdd` revérifie) ; somnolent = pas heureux ; jamais de régression.
- **Coffres** (`CompanionChest.lua`) : zone à 100 % (au moins deux parts) → coffre, une seule fois par zone, par personnage. Palier selon le niveau d'entrée de la zone (`ns.ZONE_LEVELS`, 39 zones classiques), sinon le niveau du joueur. Le joueur choisit parmi les objets du palier qu'il n'a pas ; palier épuisé → zone dorée. Objectif « Ouvre le coffre de … » en tête du suivi (clic = coffre), `/r2q coffre`, fenêtre exclusive.
- **Cosmétiques** : champ `tier` (0 = possédé d'office). Un objet à palier ne se gagne plus au compteur (`CompanionCheckUnlocks` l'ignore, `CompanionIsUnlocked` exige le coffre) ; ce qui a déjà été gagné reste acquis. Nouveaux : 6 créatures (display IDs vérifiés dans les CSV wago.tools des builds 1.15.9 et 1.60.1, même modèle et même texture), 4 ornements, 8 cadres, 9 fonds (textures présentes dans les deux manifestes). 37 objets à palier : 13 / 13 / 11.
- **Objectifs = actions** : « Atteins le niveau 20 » au lieu de « Aguerri — niveau » ; les récompenses passent en `goal.rewards` (survol « Récompense : … »). Une même action n'a qu'une ligne : le stade est fusionné dans le palier du même niveau (`goal.merge`). La complétion de zone annonce son coffre.

**Fenêtre du carnet refaite** (retour : « pas clair du tout »)
- **`JournalWindow.lua`** remplace l'ancienne fenêtre à 7 onglets (Objectifs + un par sorte de tampon). Deux sections : `completion` et `evolution` (`ns:SelectJournalKind` ; « goals » mène à l'Évolution).
- **Complétion** : liste déroulante maison (pas d'`UIDropDownMenu`, source de taint) des zones connues (`ns:JournalKnownZones` : ici, tampons de zone, bestiaire, récolte, coffres), la zone d'ici par défaut ; un choix tient tant que la fenêtre reste ouverte. Pourcentage, barre, état du coffre (à gagner, à ouvrir avec bouton, ouvert, doré). Quatre onglets d'activité : chaque part de `ns.ZONE_PARTS` porte un `tab` (ou `PART_TAB` par défaut) et, au besoin, `Items(self, zoneID)` ; `ns:JournalActivityRows` empile un titre par part puis ses éléments (à faire d'abord).
- **Évolution** : étape, prochain objectif (niveau ou bonheur), 4 barres d'envies, « Comment ça marche », coffres, collection par palier, parcours.
- **Clic sur un objectif du suivi** : objectif du compagnon → Évolution, le reste → Complétion (`ns:OpenJournalFor`).
- **Questie** (`QuestieZone.lua`, agent) : part `quests` lue dans la base de Questie 12.x (`QuestieDB.QuestPointers`, `QueryQuestSingle`, `QuestiePlayer.HasRequiredRace/Class`, `ZoneDB:GetUiMapIdByAreaId`), quêtes faites via `C_QuestLog.IsQuestFlaggedCompleted`. Index zone → quêtes construit une fois par session, jamais en combat. Exclues : cachées, événements, répétables, journalières, hebdomadaires, métier. Questie absent ou pas initialisé : pas de part. `## OptionalDeps: Questie`.

- **Suivre à l'écran** : `JournalData().watch[zoneID]` (par personnage). Zone d'ici suivie sauf `false` ; autre zone seulement si `true` (`ns:JournalIsWatched` / `ns:JournalSetWatched`). Le suivi filtre `zone:`, `villages:`, `bestiary:`, `named:` d'une zone décochée ; une zone cochée exprès a son objectif « Complétion » même avec une seule part, classé avant les objectifs automatiques (ratio 1,2 : après un coffre ou une évolution).
- **Onglet Quêtes** : libellé « Quêtes (Questie) » grisé sans Questie, survol explicatif.

**Zones préremplies** (demande : « fait en amont, pas de façon dynamique »)
- **Source** : base de Questie (dépôt Questie/QuestieDB, commit `c5de61a`), PAS Wowhead (CGU). Licence : voir `NOTICE.md`.
- **Générateur** : `tools/gen_zone_data.py <QuestieDB> --commit <sha> --date AAAA-MM-JJ`, sortie déterministe. Produit `ZoneCreatures.lua` (166 Ko, 40 zones, 2 769 espèces : niveaux, rang, noms fr/en, faction amicale) et `ZoneGathering.lua` (5 Ko, 38 zones, herbes et filons → itemID de `GatheringData.lua`).
- **Filtres** : bestioles (gabarits 31/188/190), PNJ techniques et d'événement, PNJ de service amicaux (gardes) ; `friendlyToFaction = "AH"` gardé seulement pour les gabarits neutres combattables. Rangs cmangos : 1 élite, 2 rare élite, 3 boss, 4 rare.
- **Bestiaire** : espèces de la zone (moins celles amicales envers ta faction) ∪ apprises en jeu ; un kill d'une espèce de la table compte sans l'avoir vue (engagement requis). **Récolte** : ta tranche ∩ ce qui pousse dans la zone. Dépeçage et zones hors tables : dynamiques comme avant.
- **Limites connues** : quelques PNJ de quête/d'événement comptés (100 % strict) ; factions telles que Questie les note.

**Quêtes et zones Forever générées** (Questie n'est plus requis en jeu ; `QuestieZone.lua` supprimé)
- `tools/gen_zone_data.py` produit, par client, `ZoneCreatures_*`, `ZoneGathering_*`, `ZoneQuests_*` (Era / Forever). Chaque fichier se garde (`ns:IsForeverClient()`) : un client ne construit que ses tables. Forever : couches raw → corrections héritées → delta-base → traces → corrections Forever ; zones de `support/Forever/Zones`.
- Quêtes gardées : Era 2 188 (39 zones), Forever 2 741 (43 zones, dont Zephras Isle, Riverglades, Shen'dralas, Darkspear Islands, Mount Hyjal). Exclues : répétables, cachées, métier, JcJ, événements ; catégories rattachées seulement si tous les donneurs sont dans une seule zone. Exclusives (`ex`) : exclusiveTo + chaînes d'approche.
- `ZoneQuests.lua` : filtre race/classe (masques jusqu'aux bits 32-33 des races Skyborne, en arithmétique), faites via `C_QuestLog.IsQuestFlaggedCompleted`, cache invalidé à QUEST_TURNED_IN / QUEST_LOG_UPDATE (après le combat). Tailles : quêtes 156 / 197 Ko, créatures 167 / 215 Ko.
- Limites : PNJ Forever de la delta-base sans niveau exclus ; quêtes Forever sans masque de race proposées à tous ; noms Forever sans traduction en anglais ; corrections dynamiques (faction) non appliquées.
- **Licence** : l'addon passe en GPL-3.0 (`LICENSE`), la base de Questie l'étant.

**À vérifier en jeu**
- Le modèle s'affiche dans un `PlayerModel` d'addon. Un modèle invisible sans erreur ne se détecte pas hors jeu.
- Cadrage, échelle et animations des créatures.
- `mapType` des cartes, format des GUID, et bits d'affiliation du familier dans le journal de combat.

## v1.24.0 — confort de jeu : quatre modules QoL

Les modules ont été faits comme en v1.23.0 : un agent par module dans son worktree, sur l'API d'extension, puis fusionnés.

**Préparation (`a6b9fe2`).**
- **Navigation repliable** (`ns:LayoutNav`) : les sous-pages ne s'affichent que sous leur module ouvert. Sans ça, la navigation aurait débordé.
- **QoL** devient une entrée parente. `ns.AddOptionPage` range un module à la fin des MODULES et une page QoL à la fin du QoL. Les modules de la v1.23.0 étaient rangés par erreur sous le titre QOL.

**Point d'entrée des commandes.** `ns.EXTRA_COMMANDS`, consulté par `HandleCommand` : la table `COMMANDS` est locale. Les commandes du cœur restent prioritaires. Deux agents ont ajouté la même ligne, une seule a été gardée.

**La bonne récompense** (`QuestReward.lua`)
- **Pondération** : les stats prioritaires de la spé (`ns.SPEC_STATS`) pèsent 1 / 0,6 / 0,4 / 0,25 / 0,15. Pour une spé physique, le DPS d'arme et la puissance d'attaque comptent ; sinon, la puissance des sorts.
- **Maîtrises** (`PROFICIENCY`) : types d'armure, maille et plaques à partir du niveau 40, boucliers, reliques, armes, ambidextrie.
- **Comparaison** : avec la pièce portée. Pour un emplacement double (anneaux, bijoux), avec la plus faible des deux.
- **Sans `GetItemStats`** (Era) : le niveau d'objet, filtré par les maîtrises.
- **Repli** : le prix de vente.
- **Boutons** : `QuestInfoRewardsFrame.RewardButtons`, puis `QuestInfoRewardsFrameQuestInfoItem<i>`, `QuestInfoItem<i>` et `QuestRewardItem<i>`. Sinon, une ligne de chat.

**Rythme de leveling** (`LevelPace.lua`)
- **XP par heure** : sur la session et sur une fenêtre glissante (15 à 60 min). Le passage de niveau est pris en compte.
- **Estimations** : par ennemi, d'après les messages `CHAT_MSG_COMBAT_XP_GAIN` lus avec les chaînes du client ; par quête, d'après `QUEST_TURNED_IN`.
- **Repos** (warcraft.wiki.gg « Rest ») : 5 % d'un niveau par 8 h en auberge ou en ville, un quart de ce rythme ailleurs, plafonné à 150 %.
- **Barre d'XP** : `MainMenuExpBar` sur Era ; sur Forever, `MainStatusTrackingBarContainer` et les barres qui s'en rapprochent.
- **Pour l'Expédition** : `ns:PaceXPPerHour()` est exposé.

**Sac plein** (`BagSpace.lua`)
- **Déclenchement** : l'erreur « inventaire plein », sous les deux signatures de `UI_ERROR_MESSAGE`, ou un butin qui ne rentre pas.
- **Classement** : prix de vente × pile, du moins cher au plus cher. Un prix inconnu n'est jamais proposé.
- **Exclusions** : objets de quête, clés, pierre de foyer, réactifs de classe, composants des recettes suivies, derniers vivres, liste « garder ».
- **Destruction** : uniquement dans le `OnAccept` d'une StaticPopup dédiée. La case est revérifiée (même objet, même pile, pas de combat) et le curseur aussi, avant `DeleteCursorItem`. La confirmation n'est pas réglable.
- **Alias** : `bags` retiré à l'intégration. C'est l'identifiant du contrôle Sacs, et `/r2q module bags off` doit toujours viser ce contrôle (testé).

**Après la mort** (`Death.lua`)
- **Distance** : `C_DeathInfo.GetCorpseMapPosition` et `C_Map.GetPlayerMapPosition`, converties en coordonnées monde par `C_Map.GetWorldPosFromMapPos`. Repli sur `C_Map.GetMapWorldSize`, sinon « distance inconnue ».
- **Fantôme** : 125 % de la vitesse de course, soit 8,75 yd/s (warcraft.wiki.gg « Death (gameplay) »).
- **Guérisseur** : il coûte 25 % de durabilité en plus des 10 % de la mort, converti en or avec le coût de réparation mesuré.
- **Mal de résurrection** : aucun jusqu'au niveau 10, puis (niveau − 10) minutes, plafonné à 10 min. `GetResSicknessDuration` est prioritaire s'il est lisible.
- **Verdict** : courir si le temps de course est inférieur à la faiblesse.
- **Rien en instance ni en champ de bataille.**

**À vérifier en jeu**
- **Récompense** : les noms des boutons de récompense, et `GameTooltip:SetQuestItem`.
- **Rythme** : la barre d'XP de Forever, et l'ordre des événements quand on rend une quête.
- **Sac plein** : `DeleteCursorItem` depuis le bouton d'une StaticPopup d'addon (point principal), et `ERR_INV_FULL` en français.
- **Mort** : les positions renvoyées par `GetCorpseMapPosition`, et le format de `GetResSicknessDuration`.

## v1.23.0 — trois nouveaux modules et une API d'extension

### API d'extension (`32daa4d`)

Un module vit dans son propre fichier, chargé après `UI.lua` dans le `.toc`, sans toucher aux fichiers communs.

| Fonction | Rôle |
|---|---|
| `ns.RegisterStrings(fr, en)` | ses chaînes, en français et en anglais |
| `ns.RegisterDefaults(t)` | ses réglages par défaut, appliqués même si la sauvegarde est déjà lue |
| `ns.AddCheck(def)` | ajoute un contrôle au Check avant le départ |
| `ns.AddOptionPage(def, beforeId)` | ajoute une page de réglages, par défaut avant la section QoL |
| `ns.RegisterModule(m)` | inscrit le module dans `/r2q modules` et `module <id>` |
| `ns:RegisterCallback(ev, fn)` | s'abonne à `DEPARTURE` (sortie confirmée), `RETURN` (retour après un départ) ou `CHECKLIST` (résultats d'un check) |

Le suivi des départs et retours tourne **même si le Check avant le départ est coupé**. Le silence après connexion et l'écart entre alertes ne filtrent plus que l'alerte, plus le départ lui-même.

**Tests.**
- Le harnais lit la liste des fichiers dans le `.toc`.
- Les fichiers de module ne sont chargés qu'**après** les scénarios du cœur. Ceux-ci comptent les contrôles et les pages de base, et ne bougent donc plus quand un module s'ajoute.
- Chaque `tests/modules/*.lua` reçoit ensuite la boîte à outils `T`.
- `tests/modules/zz_integration.lua` passe en dernier, avec **tous** les modules chargés.

### Les trois modules

Ils ont été développés en parallèle par trois agents, chacun dans son worktree, puis fusionnés.

**Retour d'expédition** (`Expedition.lua`)
- **Argent** : les écarts de `PLAYER_MONEY`, gains et dépenses cumulés à part. Le net seul cacherait « gagné puis dépensé en réparation ».
- **Butin** : `CHAT_MSG_LOOT`, reconnu grâce aux chaînes du client (`LOOT_ITEM_SELF`…, dans la langue du joueur), avec un repli fr/en. Ce n'est pas une comparaison des sacs, qui se tromperait sur les ventes, la nourriture mangée ou les piles fusionnées.
- **XP** : `UnitXP` relevé à chaque `PLAYER_XP_UPDATE` et `PLAYER_LEVEL_UP`, pour gérer le passage de niveau.
- **Morts** : un compteur sur `PLAYER_DEAD`. **Usure** : durabilité totale de l'équipement, au départ et au retour.
- **Limite** : un `/reload` en cours de sortie efface le suivi, qui n'est gardé qu'en mémoire.

**Avant le donjon** (`Dungeon.lua`, `DungeonData.lua` généré par `tools/gen_dungeons.py`)
- **Sources** : 28 donjons. `Map`, `AreaTable` et `LFGDungeons` pour Era 1.15.9 et Forever 1.60.1 (wago.tools) ; niveaux Forever d'après warcraft.wiki.gg (Patch 1.60) et method.gg.
- **Cartes d'instance Forever** : 4 des 9 nouveaux donjons en ont une dans le client 1.60.1 (Dalaran 2959, Ruins of Lordaeron 2999, Excavation Site 2998, Hall of Thanes 3065). Les 5 autres sont reconnus par leur nom anglais en attendant le client de lancement.
- **Bandarion Keep n'est pas un donjon** : c'est une sous-zone de Tirisfal, donc exclue.
- **Quêtes** : celles qui sont rangées sous l'en-tête du donjon dans le journal. Les plans de métier par boss ne sont pas encore publiés : la table est vide, mais le filtrage par métier est prêt.
- **Affichage** : une fiche par visite, et une nouvelle visite après 15 minutes loin du donjon. À l'entrée, la fiche n'apparaît que si le joueur est à 3 niveaux ou moins sous le minimum. Les entrées partagées ou situées dans une capitale ne déclenchent la fiche qu'à l'intérieur de l'instance.

**Kit de camp** (`Camp.lua`, Forever seulement)
- **Kits de feu de camp** : objets 279981 (Basique), 279961 (Compagnon) et 279974 (Expert).
- **Objets de camp** : 36 objets sur 12 métiers, avec une recharge partagée d'une heure (catégorie de sort 97).
- **Seuil de la minute** : l'aura « Welcoming Campfire » (1229739/1289723) dure 60 s et déclenche « Camp Benefits » (1229741).
- **Buffs du camp** : les « Boosted … » d'une heure sont ajoutés à `ns.IGNORED_BUFF_SPELLS`, pour qu'ils ne soient jamais réclamés.
- Toutes ces données viennent des tables ItemSparse, ItemXItemEffect, ItemEffect, SpellEffect, SpellMisc et SpellDuration de Forever 1.60.1. Elles sont commentées en tête de `Camp.lua`.

### À vérifier en jeu

- **Retour d'expédition** : la forme exacte des messages de butin.
- **Avant le donjon** :
  - les informations d'instance renvoyées par `GetInstanceInfo` ;
  - les noms français des en-têtes de quêtes de donjon ;
  - les noms des 5 nouveaux donjons dans le client de lancement.
- **Kit de camp** :
  - l'API de compétences ;
  - la recharge des objets de camp ;
  - l'aura d'accueil ;
  - la correspondance entre chaque objet et son buff.

### Intégration

Chaque module tenait seul dans le panneau de réglages, mais leur somme faisait déborder la navigation sur le pied : « Marchand » passait sous les boutons. Le panneau passe de 440 à 480 px, et le test d'intégration vérifie maintenant ce cas.

## v1.22.0 — zones sûres connues dès l'installation, 3 modules, camps de Forever

### Ce qu'est une zone sûre

Un endroit où l'on se **prépare** (manger, réparer, vendre, se lier) **sans risque**. Dans l'ordre :

1. **jamais en instance** (donjon, raid, champ de bataille) : `IsInInstance()` ;
2. **un camp de Forever** : aura « Campfire Nearby » (sort 1283391), lue par numéro. C'est une zone de départ **temporaire** : quitter le feu déclenche le check, mais le camp n'est jamais appris ;
3. **un lieu de la base livrée** (`Hubs.lua`, 80 lieux), **de ta faction ou neutre**. Un village de l'autre faction n'est jamais sûr, ni appris ;
4. **un lieu appris** (indices) ou ajouté à la main ;
5. **le repos ou un sanctuaire en cours**.

### La base livrée (`Hubs.lua`)

Elle est générée par `tools/gen_hubs.py` à partir des données du client publiées par wago.tools : `AreaTable` d'Era 1.15.9.70576 et de Forever 1.60.1.70753. Elle regroupe :
- les **6 capitales**, repérées par le drapeau `CAPITAL` du client et reconnues dans tous leurs quartiers ;
- les **villages et hubs** avec auberge ou maître de vol ;
- les **auberges qui sont leur propre sous-zone** (Gallows' End Tavern, Deepwater Tavern, Stoutlager Inn, Thunderbrew Distillery) ;
- les hubs neutres sans auberge (Thorium Point, Marshal's Refuge, Nighthaven…) ;
- et, pour Forever, Zephras Isle (Valanaar et ses villages), Powderfuse Port et The Eventide.

Le jeu traduit lui-même chaque nom (`C_Map.GetAreaInfo`) : la base vaut dans toutes les langues.

Pourquoi une liste éditée à la main : **aucun client Classic n'a de drapeau « village »**. Le `0x00200000` des émulateurs n'apparaît ni sur Era, ni sur Forever, ni sur TBC Anniversary. Le `0x00100000` de TBC est `AREA_FLAG_LOWLEVEL` (zones de départ). Seules les capitales sont marquées.

### Le repos ne suffit plus à apprendre un lieu

Sur Forever, on est « au repos » à un feu de camp en pleine nature. Le repos devient donc un indice moyen : il ne fait apprendre un lieu qu'avec un autre indice (marchand, quête…). Les indices forts restent l'aubergiste, le maître de vol, le courrier et la banque.

### Buffs du camp ignorés

« Campfire Nearby », « Warmth », « Camp Benefits » et « Well Rested » disparaissent en quittant le camp. Ils ne sont plus appris, sinon ils seraient réclamés à chaque départ.

### Réglages : 3 modules et une section QoL

| Navigation | Contenu |
|---|---|
| **Général** | addon actif, puis une section **AFFICHAGE** : bouton de minicarte et sa position, fenêtre ou chat, note sous laquelle la fenêtre s'ouvre, placement des cadres |
| **MODULES** | |
| Check avant le départ `[on/off]` | sous-pages **Déclenchement** · **Zones sûres** · **Sacs & vivres** · **Équipement & perso** · **Buffs & métier**. Les 13 contrôles sont la configuration du module |
| Résumé de stuff `[on/off]` | résumé éphémère au changement d'objet : un interrupteur, pas de page (son placement est dans Général) |
| Stats du portrait `[on/off]` | stats au survol du portrait : un interrupteur, pas de page |
| **QOL** | |
| Marchand | vente des gris, réparation : indépendants du module de départ |

Au passage :
- les unités « pourcent » deviennent « % », qui chevauchaient la jauge ;
- l'aide de `/sd safe list` écrasait celle de `/sd resetpos` (deux clés `CMD_HELP_20`) ;
- `/r2q` est ajoutée à l'aide.

À vérifier en jeu sur Forever : le numéro de la pierre de foyer (6948 sur Era) et la présence de l'aura de camp.

---

## v1.21.0 — Ready to Quest devient Ready2Quest

Un nom plus court, une vraie marque, et le sigle **R2Q**.

**Le logo** est une boussole de poche : anneau de suspension, lunette pointillée, repères cardinaux, **aiguille bleu de nuit** à 38°, pivot ambre et monogramme « R2Q » (le « 2 » en ambre) en Alegreya.
- `Textures/logo.tga` (128 px) : version complète, en tête de la navigation des réglages, à côté du nom « Ready**2**Quest ».
- `Textures/logo_petit.tga` (64 px) : la même boussole sans les lettres, illisibles sous 24 px. Elle sert pour les bandeaux, le bouton de minicarte et l'icône de la liste des addons.

**Une deuxième couleur, le bleu de nuit `#5b8fd6`.** Elle reprend l'aiguille du logo et n'a qu'un rôle : **information et navigation**. Ça couvre les groupes de la navigation, le losange des modules « info » (le repos) et la source d'une zone apprise (« boîte aux lettres »). Elle ne sert jamais pour un statut ni pour l'action principale : l'ambre garde l'action et la valeur, et vert, ambre et rouge restent les statuts.

**Le renommage est complet.**
- Dossier et `.toc` : `Ready2Quest/Ready2Quest.toc`.
- Sauvegarde : `Ready2QuestDB`.
- Fenêtres : `Ready2QuestDiagFrame`, `Ready2QuestOptionsFrame`, `Ready2QuestMinimapButton`.
- API publique : `_G.Ready2Quest` (`_G.ReadyToQuest` reste en alias).
- Commandes : nouvelle commande `/r2q`. `/sd` et `/sacdepart` marchent toujours.
- Les chemins de textures sont maintenant construits depuis le nom réel du dossier. Les flèches de `Stats.lua` l'avaient encore en dur.

### Interrupteurs de page dans la navigation

Comme le bouton d'alimentation des modules dans la barre latérale d'EllesmereUI : chaque page qui contient des modules a son mini-interrupteur à droite de son nom.

- Un clic coupe ou rallume **tous les modules de la page**, sans quitter la page courante.
- Trois états : allumé (ambre), éteint (gris, nom de page grisé), **partiel** (contour ambre, curseur au centre) quand une partie seulement des modules est active.
- Un clic sur une page partielle rallume tout. Le réglage module par module reste dans la page, et les deux restent synchronisés.
- La navigation passe de 150 à 164 px pour faire la place, d'après la largeur des libellés mesurée sur une capture en jeu.

### Migration : ce qu'il faut faire

1. Supprimer l'ancien dossier `Interface/AddOns/ReadyToQuest`. Sinon les deux versions se chargent.
2. Copier `Ready2Quest` à sa place.
3. **Pour garder ses réglages et ses villages appris** : dans `WTF/Account/<compte>/SavedVariables/`, renommer `ReadyToQuest.lua` en `Ready2Quest.lua` (et `ReadyToQuest.lua.bak` s'il existe). C'est nécessaire parce que WoW charge la sauvegarde d'un addon depuis un fichier **qui porte le nom du dossier** : après un renommage, l'ancienne n'est plus lue. Une fois le fichier renommé, l'addon reprend `ReadyToQuestDB` dans `Ready2QuestDB` au premier chargement. Sans cette étape, l'addon repart des réglages par défaut, sans erreur.

Remarque honnête : la migration de la v1.17.0 (`SacEtDepartDB` → `ReadyToQuestDB`) avait la même limite. Elle ne servait que si le fichier de sauvegarde avait été renommé à la main. Elle est conservée dans la chaîne (`SacEtDepartDB` → `ReadyToQuestDB` → `Ready2QuestDB`) : c'est la sauvegarde la plus récente qui l'emporte.

---


## v1.20.0 — une identité à soi

L'addon ressemblait à un morceau de l'interface Blizzard. Il a maintenant sa personnalité, sur un principe repris de suites comme EllesmereUI : **un seul système visuel, appliqué partout**. L'apparence, elle, reste propre à Ready to Quest : un « carnet de route », ambre et ardoise, avec une boussole pour marque (détail dans *Direction artistique*).

- **Diagnostic** : titre « Avant le départ », note en grand dans la police maison, qui compte jusqu'à sa valeur, et verdict en tampon bordé à la couleur du statut. « Parti de Comté-de-l'Or · boîte aux lettres » est dans le bandeau. Chaque ligne a un losange de statut, et les conseils ont des puces en losange.
- **Réglages** : navigation en deux groupes (Préparation, Interface), page active teintée et soulignée d'ambre, titre de page dans la police maison avec une phrase d'explication. Les booléens ont des interrupteurs, les seuils une piste de valeur. « Fermer » est en ambre plein.
- **Minicarte** : la boussole remplace l'icône de sac.
- **Chat** : préfixe ambre `[Ready to Quest]`, alerte discrète en « Sac bouclé / Presque prêt / Pas prêt ».
- **Plus aucun template Blizzard** pour les fenêtres et contrôles : l'apparence ne dépend plus de l'art du client (« Camelot » sur Forever, encore inconnu).

---


## v1.19.0 — réglages par pages

Le panneau de réglages était une longue colonne : 910 px en 1.18.0 avant refonte (hors de l'écran), et les réglages d'un même module y étaient éparpillés. L'interrupteur des vivres était dans « Modules », leur seuil dans « Alertes ». Il devient une fenêtre de **600 × 440** avec une navigation à gauche, à la manière d'ElvUI, sous l'habillage de l'addon (fond sombre, liseré or, `GameFont`).

| Page | Contenu |
|---|---|
| **Général** | addon actif, fenêtre ou chat, fenêtre sous la note, délai avant l'alerte, silence après connexion, écart entre deux alertes |
| **Zones sûres** | villages et capitales appris, avec leur source et un bouton **Retirer** par ligne ; **Tout effacer** |
| **Sacs & butin** | modules Sacs et Butin à vendre ; emplacements libres min., alerte continue, gris avant l'alerte, vente auto |
| **Vivres & potions** | les deux modules et leurs minimums |
| **Buffs** | module, apprentissage auto, **liste des buffs suivis** : clic pour activer ou couper, bouton Retirer |
| **Équipement** | Durabilité et Réparation ; durabilité min., réparation auto |
| **Personnage** | Réactifs, Sorts, Foyer, Repos ; repos min. |
| **Métier & quêtes** | composants de métier, quêtes à rendre |
| **Affichage** | minicarte (bouton, position), résumé de stuff, stats du portrait, déplacer / réinitialiser les cadres |

- La page ouverte est mémorisée.
- Les listes défilent à la molette ou avec `^` / `v`. C'est fait sans `FauxScrollFrame`, dont la présence n'est pas assurée sur Forever.
- Un module ajouté plus tard sans page tombe dans « Général » : il reste toujours possible de le couper.
- Les tests vérifient que chaque module a un seul interrupteur, qu'aucune page ne déborde sur le pied, que les libellés tiennent, et que les listes se mettent à jour après un retrait.

---

## v1.18.0 — l'alerte part enfin à la sortie du village

**Le bug.** La fenêtre ne s'ouvrait pas toute seule en quittant une zone sûre, seulement au clic sur l'icône. Deux causes :

1. **Les zones sûres étaient apprises par `mapID`.** Sur Era, un `mapID` est une zone entière : un repos ou un vendeur à Comté-de-l'Or rendait **toute la forêt d'Elwynn** sûre, pour toujours. Sortir du village ne changeait rien, donc pas de transition, donc pas d'alerte. Chaque marchand croisé sur la route ajoutait une zone de plus.
2. **`GetRestState()` était lu comme « dans une auberge ».** Il indique en fait un bonus d'XP de repos en réserve : avec du repos d'avance, tu étais « en zone sûre » partout.

**La refonte.**

| | Avant | v1.18.0 |
|---|---|---|
| Clé d'un village | `mapID` (zone entière) | `mapID` + sous-zone (`GetSubZoneText`) |
| Capitale | idem | carte entière, déduite d'un repos vu dans **≥ 2 quartiers** |
| Apprentissage | repos, vendeur ou courrier : un seul suffit | **indices** (voir ci-dessous) |
| Sortie | immédiate | confirmée après **6 s** hors zone sûre (réglable 0–15 s) |
| En vol | alerte en plein ciel | reportée à l'atterrissage, annulée si tu te poses en zone sûre |
| Mort / fantôme | alerte | ignorée |

Indices, par sous-zone :

| Force | Signal | Événement |
|---|---|---|
| **fort** : un seul suffit | repos, aubergiste, maître de vol, boîte aux lettres, banque | `PLAYER_UPDATE_RESTING`, `CONFIRM_BINDER`, `TAXIMAP_OPENED`, `MAIL_SHOW`, `BANKFRAME_OPENED` |
| moyen | entraîneur | `TRAINER_SHOW` |
| faible | marchand, donneur de quêtes | `MERCHANT_SHOW`, `QUEST_DETAIL`, `QUEST_GREETING`, `QUEST_COMPLETE` |

Un village est appris avec **un indice fort, ou deux indices moyens/faibles de types différents** (marchand + quête). Deux quêtes prises au même PNJ isolé ne suffisent pas. Les indices partiels sont gardés d'une session à l'autre.

**Migration.** Les anciennes zones (par `mapID`) ne peuvent pas être converties : elles sont **purgées une fois**, avec un message dans le chat. Les villages se réapprennent en quelques minutes de jeu.

**Commandes.** `/sd safe` (village courant), `/sd unsafe` (village ou capitale courants), `/sd safe list`, `/sd safe reset`. La fenêtre de diagnostic affiche « Parti de : Comté-de-l'Or (appris : boîte aux lettres) » pour repérer d'un coup d'œil un village appris à tort.

**Limite connue.** Dans un village où l'auberge porte son propre nom de sous-zone, sortir de l'auberge vers la rue ressemble à une sortie si la rue n'est pas encore apprise. Le délai de 6 s absorbe les allers-retours, et la rue s'apprend vite (marchand + quête, boîte aux lettres).

### Nouveaux checks

| Check | Poids | Actif quand | Échec si |
|---|---|---|---|
| **Réactifs** (de classe) | 15 (fort) | la classe en consomme, au niveau du sort | munitions < 200, fragments d'âme < 3, poudre éclipsante < 5, runes de téléportation < 2, poudre des arcanes < 5, chandelles < 5, graine de Renaissance < 1, ankh < 1, symbole de divinité < 1 |
| **Pierre de foyer** | 10 (moyen) | toujours | absente, ou recharge > 10 min. Affiche le lieu lié (`GetBindLocation`) |
| **Réparation** | 10 (moyen) | un coût a été mesuré chez un marchand | l'or ne couvre pas le coût estimé |
| **Sorts à apprendre** | 5 (faible) | un niveau pair est passé depuis la dernière visite chez l'entraîneur de classe | toujours un conseil |

La réparation n'invente rien : chez un marchand qui répare, l'addon relève `GetRepairAllCost()` et le ramène à un prix par point de durabilité manquant. Le check est muet tant qu'aucune mesure n'existe. Le niveau d'entraîneur et le prix de réparation sont gardés **par personnage**.

### Chez le marchand (activé par défaut)

- **Vente des gris** : uniquement qualité grise avec un prix de vente, par tranches de 12 (limite du serveur), récapitulatif « 7 objet(s) gris vendu(s) : 1 po 23 pa ».
- **Réparation** : si le marchand répare et que l'or suffit, sinon un message.

Les deux se coupent dans `/sd options` → **Chez le marchand**.

### Audit Era : ce qui était faux sans rien dire

Aucun de ces bugs ne levait d'erreur : la note mentait, simplement.

| Module | Sur Era | Correctif |
|---|---|---|
| Vivres, potions | les consommables gardent la sous-classe générique 0 de vanilla : **compteur toujours à 0** | reconnus au sort lancé (« Nourriture », « Boisson ») ou au mot « Potion » |
| Quêtes | `isComplete` vaut `1`, pas `true`, et la forme des retours de `GetQuestLogTitle` varie : **« rien à rendre » en permanence** | forme détectée par la position du booléen `isHeader`, `1` accepté |
| Consommables | seul `C_Item.GetItemInfoInstant` était appelé | repli sur la fonction globale |
| Buffs | repli `UnitAura` : le spellId est le 10e retour, pas le 8e | corrigé |
| Buffs | un rang ou la version de groupe (Prière de robustesse, Don du fauve, Bénédiction supérieure) était signalé « manquant » | comparaison **par famille de nom** |
| Buffs | sans `GetPlayerAuraBySpellID`, tout devenait « illisible » | lecture des auras par index |
| Buffs | « Bien nourri » et les buffs mondiaux ponctuels étaient appris puis réclamés | consommables ignorés, buff non revu depuis 7 jours oublié |
| Composants | sacs recomptés par nom via `GetItemInfo` (nil hors cache) | itemID du composant + `GetItemCount` |
| Composants | changer de recette ne rafraîchissait pas toujours | accroche de `TradeSkillFrame_SetSelection` |
| Composants | Enchantement et dressage (fenêtre Craft) non couverts | chemin `GetCraft*`, `CRAFT_SHOW` / `CRAFT_UPDATE` |
| Stats | `UnitAttackPower` a 3 retours : la PA de l'équipement était ignorée | base + bonus + malus |
| Stats | pas de `GetSpecialization` : toujours la 1re spé | onglet de talents le plus fourni |
| Stats (tous clients) | paladin : Protection et Vindicte inversées | ordre Sacré / Protection / Vindicte |
| Stats | « 12.3 %% », Esprit absent du résumé, ilvl 0 sans `GetAverageItemLevel` | corrigés |
| Affichage | troncature au milieu d'un caractère accentué ; « … », « • », « — » peut-être absents de la police des cadres | coupe UTF-8 propre, glyphes ASCII |
| Textes | préfixe du chat, titre et message d'erreur encore en « Sac & Départ » | « Ready to Quest » |

Au passage : `string.lower` dépend de la locale C, et en Latin-1 il casse l'UTF-8 (`0xC3` → `0xE3`). Les comparaisons de noms passent par `ns.AsciiLower`, qui ne touche qu'à A-Z.

Restent à confirmer en jeu : la sous-classe 0 des consommables Era, et la présence des glyphes dans la police.

### UX : moins de bruit, rien hors de l'écran

| Problème | Correctif |
|---|---|
| Panneau d'options de **910 px**, boutons du bas hors de l'écran (768 unités à l'échelle 1) | interrupteurs (affichage, automatismes, modules) sur **deux colonnes** : 702 px ; un test borne la hauteur à 740 px |
| Fenêtre ouverte à chaque sortie, même à 95/100 | note ≥ 85 : **une ligne dans le chat** (« PRÊT, 92/100 (parti de Comté-de-l'Or) ») ; réglage « Fenêtre sous la note », 100 = toujours la fenêtre ; un check manuel l'ouvre toujours |
| Fenêtre en plein combat | l'alerte attend la fin du combat |
| Deux lignes « Composants » | « Métier » (recettes) et « Réactifs » (de classe) |
| 13 lignes dont des « sans objet » | modules sans objet **masqués**, échecs en tête (les plus lourds d'abord), modules coupés en bas ; la fenêtre se redimensionne |
| Repos : 10 points perdus sur un critère qu'on ne corrige pas en partant | information seulement : poids nul, pas de conseil |
| « à apprendre (dernier entraîneur : niv. 10) » tronqué | « niv. 10 -> 12 : à apprendre » |
| Minicarte : clic gauche = réglages | clic gauche = **check** (l'action principale), clic droit = réglages |
| Vente auto silencieuse la première fois | message unique au premier marchand |
| Vert de statut = vert de rareté « Inhabituel » | vert adouci ; « ! » devant chaque échec (la couleur seule ne suffit pas aux daltoniens) |
| Verdict en petit dans le bandeau, « Parti de » en bas | verdict en grand à côté de la note, « Parti de » juste dessous |
| Seuils « Vivres : 5 » ambigus | « Vivres min. », « Gris avant l'alerte »… ; libellés raccourcis pour tenir en demi-colonne (testé) |

---


## v1.17.0 — le projet s'appelle Ready to Quest

Le dépôt GitHub s'appelle **ReadyToQuest** ; le dossier WoW s'y aligne. Ce n'est pas cosmétique : WoW exige que le nom du dossier corresponde exactement au nom du `.toc`, sinon l'addon ne se charge pas.

Renommé : dossier, `ReadyToQuest.toc`, SavedVariable `ReadyToQuestDB`, noms des frames (`ReadyToQuestDiagFrame`, `ReadyToQuestOptionsFrame`, `ReadyToQuestMinimapButton`), table publique `_G.ReadyToQuest`, et le chemin des textures TGA — qui référence le nom du dossier.

**La sauvegarde est migrée.** `SacEtDepartDB` → `ReadyToQuestDB`, au premier appel de `:DB()` : zones sûres apprises et réglages personnalisés survivent au renommage. Sans ça, chaque joueur repartait de zéro sans s'en apercevoir. Quatre assertions verrouillent la migration ; la neutraliser en fait échouer trois.

Inchangé : la commande reste `/sd` (`/sacdepart` fonctionne encore). Le titre affiché devient « Ready to Quest ».

---

Addon QoL pour **WoW Forever**, avec sa propre identité « carnet de route » : surfaces ardoise, accent ambre, titres en Alegreya, boussole en guise de marque (voir *Direction artistique*).

| Module | Ce qu'il fait |
|---|---|
| **Diagnostic de départ** | Note de préparation sur 100, détail par module, conseils — déclenché à la sortie d'une zone sûre |
| **Marchand** | Vente des gris et réparation automatiques |
| **Améliorations flottantes** | Carte ancrée à l'infobulle : verdict, écart d'ilvl et écarts de stats |

> Client : Forever — `## Interface: 16001` (flavour interne `Camelot`).

---

## Installation

1. Copier le dossier `Ready2Quest` dans `.../Interface/AddOns/`
2. Vérifier le chemin final : `.../Interface/AddOns/Ready2Quest/Ready2Quest.toc`
3. `/reload`, puis `/sd`

Erreur Lua invisible ? `/console scriptErrors 1`.

---

## Tester sur Classic Era

> **Historique.** Depuis Ready2Quest 1.26.1 et QuestCompanion 1.2.0, seul WoW Forever est pris en charge, et le code propre à Era et aux API historiques (métiers « recette sélectionnée », journal de quêtes par `GetQuestLogTitle`) a été retiré : voir « Fin du support d'Era » dans la section QuestCompanion 1.2.0. Cette section décrit l'état d'avant.

**C'est le terrain d'essai principal tant que Forever n'est pas sorti.** Era (interface `11509`) est le client le plus pauvre en API : tout ce qui marche sur Era devrait marcher sur Forever. L'inverse n'est pas vrai : les chemins propres à Forever (recettes suivies, `GetItemStatDelta`) ne tournent jamais sur Era. La suite de tests rejoue les scénarios v1.18.0 en mode Era (API récentes retirées).

| Point | Era |
|---|---|
| Zones sûres : sous-zones (`GetSubZoneText`, `ZONE_CHANGED`) | ✅ |
| Repos dans les villages | seulement dans l'auberge : d'où l'apprentissage par indices |
| Composants de métier | recette sélectionnée dans la fenêtre de métier |
| Comparaison au survol | ilvl, stats si `GetItemStats` est exposé |

## Tester aussi sur Classic MoP

> **Historique.** Depuis Ready2Quest 1.26.1 et QuestCompanion 1.2.0, seul WoW Forever est pris en charge, et le code propre à Era et aux API historiques (métiers « recette sélectionnée », journal de quêtes par `GetQuestLogTitle`) a été retiré : voir « Fin du support d'Era » dans la section QuestCompanion 1.2.0. Cette section décrit l'état d'avant.

**Oui — et c'est même le meilleur terrain d'essai avant Forever.** Le client MoP Classic (interface `50504`, snapshot `5.5.4.69934`) est plus proche de Forever que Classic Era sur un point : il a aussi `C_Container`, `C_Map` et `C_UnitAuras`.

### Vérifié dans la source du client MoP

| API utilisée | MoP Classic |
|---|---|
| `C_Item.GetItemInfo` / `GetItemInfoInstant` | ✅ |
| `C_UnitAuras.GetPlayerAuraBySpellID` / `GetAuraDataByIndex` | ✅ |
| `C_Container.*` (sacs) | ✅ |
| `C_Map.GetBestMapForUnit` / `GetMapInfo` | ✅ |
| `GetNumQuestLogEntries` / `GetQuestLogTitle` (globales) | ✅ — c'est ce qu'utilise `QuestLogFrame` Classic |
| `UnitIsPVPSanctuary`, `GetRestState`, `GetXPExhaustion` | ✅ |
| `GetInventoryItemLink` / `GetInventoryItemTexture` | ✅ (API historique) |
| **`C_Item.GetItemStats` / `GetItemStatDelta`** | ❌ |
| **`C_TradeSkillUI` (craft moderne)** | ❌ |
| **énumération `C_QuestLog`** | ❌ |
| **`C_TooltipInfo`** | ❌ (non utilisé) |

### Ce que chaque module donne

| Module | Forever | MoP Classic |
|---|---|---|
| Diagnostic : sacs, vivres, potions, buffs, repos, durabilité, quêtes | ✅ | ✅ |
| Zones sûres (repos, sanctuaire, vendeur, boîte aux lettres) | ✅ | ✅ |
| Panneau d'équipement (ilvl, rareté, pièces faibles) | ✅ | ✅ |
| Comparaison au survol | verdict + **stats** | verdict + stats **si** le client expose `GetItemStats` (écart calculé localement), sinon ilvl seul |
| Composants de métier | ✅ recettes suivies | ✅ recette **sélectionnée** dans la fenêtre de métier (API legacy) |

Ce qui est dégradé est **affiché explicitement** : la carte écrit « Stats indisponibles sur ce client (ilvl seul) », et le module composants affiche « aucune recette suivie ».


### Replis « Classic » ajoutés en v0.6.0

Deux API retail n'existent dans aucun client Classic. Plutôt que de laisser deux modules morts, l'addon bascule sur les équivalents historiques :

| Fonction absente | Repli Classic | Vérifié |
|---|---|---|
| `C_TradeSkillUI.GetRecipesTracked` / `GetCraftableCount` / `GetRecipeSchematic` | `GetTradeSkillSelectionIndex` + `GetTradeSkillInfo` + `GetTradeSkillNumReagents` + **`GetTradeSkillReagentInfo`** (qui renvoie déjà le nombre possédé) | ✅ dans `Blizzard_TradeSkillUI/Vanilla`, événement `TRADE_SKILL_UPDATE` |
| `C_Item.GetItemStatDelta` | si le client expose `GetItemStats` (global pré-10.0 ou `C_Item`), l'écart est **calculé par soustraction** des deux tables de stats | ⚠️ non confirmé par client : sonde au démarrage |

Conséquence : sur Classic, le module composants fonctionne avec **la recette sélectionnée dans la fenêtre de métier** (au lieu des « recettes suivies »), et la carte de comparaison affiche les écarts de stats si la sonde trouve une source.

`/sd diag` liste les capacités détectées ; la carte de comparaison indique d'elle-même « Stats indisponibles sur ce client » quand aucune source n'existe.

### Marche à suivre

1. Copier `Ready2Quest` dans `.../Interface/AddOns/` du client MoP.
2. Si le client le signale comme obsolète : cocher **« Charger les addons obsolètes »** dans la liste des addons.
3. `/reload`, puis **`/sd diag`**.

La première ligne du diagnostic doit afficher :

```
client = Mists Classic (build 5.5.4, interface 50504)
```

Le nom du client est déduit de `GetBuildInfo()` (numéro d'interface), pas deviné : `16001` → Forever, `50504` → MoP, `11509` → Era, `20506` → TBC, `12xxxx` → Retail.

Classic Era (`11509`), TBC (`20506`) et Retail sont également déclarés dans le TOC mais **non testés**.

---

## Dépannage — « l'addon est chargé mais rien ne se passe »

Depuis la v0.5.2, l'addon **parle** au lieu d'être muet.

### Étape 1 — le témoin de chargement

Au `/reload`, tu dois voir dans le chat :

```
Ready2Quest 1.21.0 — fichiers chargés
```

| Ce que tu vois | Diagnostic |
|---|---|
| **Rien du tout** | Les fichiers ne s'exécutent pas : mauvais dossier (`AddOns/Ready2Quest/Ready2Quest/`), TOC refusé, ou addon décoché |
| **Le témoin, mais pas de panneau** | Un fichier a planté après le bootstrap → `/sd` te dira lequel |
| **Le témoin + le panneau** | Tout va bien |

### Étape 2 — `/sd diag`

La commande est enregistrée **dans `Bootstrap.lua`, premier fichier du TOC**, donc elle répond même si le reste a échoué. Elle affiche :

```
client = Mists Classic (build 5.5.4, interface 50504)
  ...capacités...
  modules : 11/11 chargés
```

Si un fichier n'a pas abouti : `non chargés : Core, UI` + la dernière erreur en rouge.

### Cause racine confirmée (erreur client du 2 nov.)

`TRACKED_RECIPE_UPDATE` est un événement **apparu en retail 10.x** : il n'existe pas dans les clients Classic. `frame:RegisterEvent("TRACKED_RECIPE_UPDATE")` levait donc une erreur **à la dernière ligne de `Core.lua`**, avant l'enregistrement de la commande — d'où un addon « chargé » mais totalement muet, sans panneau et sans `/sd`.

Erreur exacte relevée en jeu :

```
Frame:RegisterEvent(): Attempt to register unknown event "TRACKED_RECIPE_UPDATE"
```

Double correction depuis la v0.5.3 :

1. `TRACKED_RECIPE_UPDATE` est **conditionné à la capacité `crafting`** : sur un client sans API de craft (MoP, Era), l'événement n'est **même pas tenté** — donc plus aucune erreur rouge.
2. L'enregistrement reste sous `pcall` : tout autre événement inconnu est ignoré, consigné et affiché par `/sd diag` (`événements non supportés : …`).

### Étape 3 — si le témoin n'apparaît pas

```
/console scriptErrors 1
/reload
```

Puis vérifier l'arborescence exacte :

```
World of Warcraft/_classic_era_/Interface/AddOns/Ready2Quest/Ready2Quest.toc
```

Un seul niveau `Ready2Quest`, et le `.toc` directement dedans.

---

## Direction artistique : « carnet de route »

Depuis la v1.20.0, l'addon a sa propre identité. Il ne cherche plus à ressembler à l'interface Blizzard. Tout est centralisé dans `Theme.lua`.

| Élément | Choix |
|---|---|
| Accent | **ambre** `#e8a54b`, réservé à ce qui compte : page active, valeur, action principale, marque |
| Statut | vert `#6fcf7a` (distinct du vert de rareté), ambre, rouge `#e2604f` |
| Surfaces | ardoise plate `#13171b`, navigation `#0f1215`, filets `#2a3138` |
| Signature | équerre ambre dans le coin supérieur gauche de chaque fenêtre |
| Police des titres | **Alegreya Bold**, embarquée (`Fonts/`, licence OFL, sans nom réservé), pour les titres et la note ; texte courant en `GameFont` |
| Marque | boussole ambre (`Textures/logo.tga`) : bandeau des fenêtres, bouton de minicarte |
| Statut des lignes | losange plein = à voir ou en échec, losange au trait = OK : la forme dit l'état autant que la couleur |
| Contrôles | boutons, interrupteurs, pistes, croix de fermeture **dessinés par l'addon** : aucun `UIPanelButtonTemplate`, `BackdropTemplate` ni `UIPanelCloseButton` |
| Mouvement | fondu de 0,15 s à l'ouverture (`AnimationGroup`), note qui compte jusqu'à sa valeur en 0,45 s |
| Voix | « Sac bouclé, 92/100. Parti de Long-guet. », « Presque prêt », « Pas prêt » |

Textures propres : `logo.tga` (boussole 64×64), `losange.tga` et `losange_trait.tga` (16×16, blancs, teintés en jeu). Elles sont générées en code, et tout le reste est `Interface\Buttons\WHITE8X8` teinté. Si le client refuse la police, l'addon garde `GameFont` sans erreur.

---

## 1. Diagnostic de départ

### Zones sûres — villages, capitales, signaux du moment

Forever n'a pas d'enum `City` dans `UIMapType`. Depuis la v1.18.0, une zone est sûre si :

| Cas | Clé | Comment |
|---|---|---|
| Capitale apprise | `c:<mapID>` (et ses sous-cartes) | repos vu dans ≥ 2 quartiers de la carte |
| Village appris | `v:<mapID>:<sous-zone>` | 1 indice fort, ou 2 indices faibles de types différents |
| Repos en cours | `IsResting()` | auberges, capitales |
| Sanctuaire | `UnitIsPVPSanctuary("player")` | hubs neutres |
| Manuel | `/sd safe` | le village (sous-zone) courant |

Détail des indices et du délai de sortie : section v1.18.0 en tête de ce document.

### Note pondérée

| Module | Poids | Score |
|---|---|---|
| Sacs | 15 | emplacements libres / seuil |
| Butin gris | 5 | −25 par objet |
| Vivres | 20 | quantités / seuil |
| Potions & flacons | 10 | quantités / seuil |
| Buffs | 15 | −25 par buff manquant |
| Repos | 0 (information) | % d'un niveau × 2 |
| Durabilité | 15 | % d'usure |
| Composants | 5 | bloqué = 40 |
| Quêtes | 5 | prêtes = 70 |
| Composants de classe | 15 | quantités / minimum |
| Pierre de foyer | 10 | absente = 0, recharge > 10 min = 50 |
| Réparation | 10 | or / coût estimé |
| Sorts à apprendre | 5 | à apprendre = 50 |

Un module inactif (composants pour un guerrier, réparation jamais mesurée, aucun sort en attente) a un poids nul et n'influence pas la note.

Bilan : **≥ 85 PRÊT** · **≥ 60 PRÊT, AVEC RÉSERVES** · **< 60 INSUFFISANT**. Il s'affiche à droite du bandeau de titre.

### Buffs appris, pas codés en dur

Aucun `spellID` dans le code : l'addon retient les auras bénéfiques de **≥ 120 s** vues sur toi (donc pas les procs). Toutes les classes, y compris futures, « Bien nourri » inclus.

### Composants de métier

Source : **les recettes marquées comme suivies** dans ta fenêtre de métier (l'étoile Blizzard).

`GetRecipesTracked` → `GetCraftableCount` → `GetRecipeSchematic`. Sortie : `Élixir de mana : manque 6 Étoffe de lin`.

### Alerte sac plein

Sur `BAG_UPDATE_DELAYED`, une fois, réarmée au-dessus de `seuil + 2`.

---

## 4. Bouton de minicarte

Un bouton **rond et discret**, calqué sur le bouton de courrier de Blizzard : cadre cliquable 33×33, icône 18×18, liseré circulaire.

Deux chromes selon le client, chacun vérifié dans les sources du jeu :

| Client | Art utilisé | Source |
|---|---|---|
| Forever | atlas `ui-hud-minimap-button` (20×20) | `Blizzard_Minimap/Mainline/Minimap.xml` |
| Classic (Era/MoP) | `Interface\Minimap\MiniMap-TrackingBorder` (52×52) | `Blizzard_Minimap/Classic/Minimap.xml` |

Le choix se fait sur `GetBuildInfo()` (interface `16xxx` = Forever, sinon Classic). Les deux références sont celles qu'utilise Blizzard lui-même : le bouton de courrier Classic est un cadre 33×33 avec une icône 18×18 et un liseré 52×52.

| Action | Effet |
|---|---|
| **Clic gauche** | lance le check immédiatement |
| **Clic droit** | ouvre les réglages |
| **Glisser** | déplace autour de la minicarte (angle mémorisé) |
| **Survol** | infobulle : nom, dernier score, rappel des actions |

Réglages : `/sd minimap on|off`, ou la page **Affichage** de `/sd options`.

Un glissement n'ouvre pas les réglages : le clic qui suit un déplacement est ignoré.


---

## 5. Activer / désactiver les modules

Chacun des 13 modules a son interrupteur, en tête de sa page dans `/sd options` (ex. Sacs & butin pour les sacs).

**Un module désactivé est exclu du calcul de la note** : son poids devient 0, il n'entre ni au numérateur ni au dénominateur. Désactiver « Sacs » ne fait donc pas monter artificiellement le score par un 100/100 offert — le module disparaît simplement de l'équation.

| Élément | Comportement |
|---|---|
| Ligne du panneau de diagnostic | grisée, en bas de la liste, mention « désactivé » |
| Score global | recalculé sur les seuls modules actifs |
| Conseils | aucun conseil généré pour un module désactivé |
| Panneau de réglages | libellé grisé + valeur `non` |
| Persistance | `SavedVariables`, par profil |

En ligne de commande :

```
/sd modules              liste les 13 modules et leur état
/sd module vivres off    désactive un module
/sd module vivres on     le réactive
/sd module vivres        bascule
```

Cas limite traité : si **tous** les modules sont désactivés, le score vaut 0 au lieu de provoquer une division par zéro, et les 13 lignes restent affichées.

---

## 6. Fenêtres : une seule à la fois

Le diagnostic et les réglages ne s'empilent plus.

| Action | Effet |
|---|---|
| Ouvrir les réglages | ferme le diagnostic |
| Lancer un check | ferme les réglages |
| Glisser une fenêtre | la position est mémorisée (`SavedVariables`) |

Chaque fenêtre est indépendamment déplaçable, mais elles ne peuvent pas être visibles en même temps — c'était la cause du chevauchement illisible sur la capture d'écran (deux cadres centrés l'un sur l'autre).

Le panneau d'équipement reste indépendant : il vit sur le côté, à sa propre position mémorisée.

### Seuil à 0 = module inactif

Un seuil à `0` signifie désormais **module inactif**, et non « tout est bon » :

| Réglage | Avant | Maintenant |
|---|---|---|
| Potions minimum = 0 | comptait **100/100**, offrait 10 points gratuits | **exclu du calcul** |
| Objets gris avant alerte = 0 | **alertait en permanence** (0 ≥ 0) | module inactif, aucune alerte |
| Vivres minimum = 0 | comptait 100/100 | exclu du calcul |

La ligne s'affiche alors « inactif (seuil à 0) », grisée, poids nul.

---

## 7. Résumé éphémère au changement de stuff

Quand tu équipes une pièce, un bloc **Statistiques** apparaît avec l'icône de l'objet et les écarts réels, puis **disparaît en fondu après 6 secondes**.

```
S T A T I S T I Q U E S
──────────────────────────────────────────
[icône] ▼ -12        DÉGÂTS                 (rouge)
[icône] ▼ -0,60 s    VITESSE D'ATTAQUE      (vert)
```

La mise en page tient en trois éléments, sans cadre ni fond :

| Élément | Réglage |
|---|---|
| Titre | `GameFontHighlightSmall` — **même corps que les lignes** — interlettré, **en majuscules**, parchemin à 70 % |
| Règle | un trait `WHITE8X8` de 1 px, parchemin à 45 %, sur toute la largeur |
| Lignes | `GameFontHighlightSmall`, 4 emplacements, pas de 14 px, ombre portée |

Chaque ligne place la **valeur colorée à gauche** (icône de l'objet, puis une flèche et le chiffre) et le **libellé en PascalCase à droite** (« Armure », « Vitesse D'attaque »), en parchemin — le libellé ne prend jamais la couleur de l'écart.

La couleur dépend d'une **polarité par statistique** : sur la vitesse d'attaque, une valeur qui baisse est une amélioration — c'est donc vert et `▲`, comme dans la capture de référence. Quatre écarts au maximum ; les lignes inutilisées sont vidées.

L'icône vient de l'objet équipé dans l'emplacement modifié : dernier retour de `GetItemInfo`, avec repli sur `GetInventoryItemTexture` si le client ne le fournit pas. Si aucune ne répond, l'icône reste vide et le texte s'affiche seul.

Les valeurs ne sont pas devinées, elles sont mesurées avant/après via les API du client :

| Mesure | Source | Formule |
|---|---|---|
| Dégâts | `UnitDamage("player")` | min / max main droite |
| Vitesse | `UnitAttackSpeed("player")` | secondes par coup |
| DPS | calculé | `((min + max) / 2) / vitesse` |
| Armure | `UnitArmor("player")` | 2ᵉ retour (effectif) |
| Réduction | calculée | `armure / (armure + 85 × niveau + 400)` |
| Force/Agi/Int/Endu | `UnitStat` | 1 à 4 |
| Puissance d'attaque | `UnitAttackPower` | 4ᵉ retour |

Ces deux formules sont **validées** par la capture de référence : 506 d'armure au niveau 11 donnent bien **27,5 %** de réduction, et 20-24 à 1,96 s donnent bien **11,2 DPS**.

Seules les lignes qui changent sont affichées. Le relevé de référence est repris à la connexion et après chaque changement.

---

## 8. Stats au survol du portrait

Survoler le cadre du joueur ouvre un panneau **au-dessus du portrait** :

```
Statistiques
Guerrier · Armes            ilvl 18
Force                     25
Agilité                   14
Intelligence              12
Endurance                 30     ← caractéristique principale en or
Armure            506   27,5 %
DPS                     11,2
```

- **Classe et spécialisation** dans la couleur de classe (`RAID_CLASS_COLORS`), via `UnitClass` et `GetSpecializationInfo`
- la **caractéristique principale** (la plus élevée) est mise en avant en or
- se referme à la sortie du curseur

`/sd stats` affiche le panneau immédiatement, sans survol.

---

## 9. Positionner les cadres — mode édition

Les deux affichages sont **verrouillés par défaut** : ils ne réagissent pas à la souris, on ne peut pas les déplacer par accident.

Pour les placer, on entre en **mode édition** depuis les réglages :

| Ligne des réglages | Effet |
|---|---|
| **Mode édition des cadres** | ferme les réglages, affiche le résumé de stuff **et** les stats du portrait, tous deux déverrouillés avec une lueur dorée |
| **Réinitialiser les positions** | remet les deux cadres à leur emplacement d'origine |
| **Position du bouton de minicarte** | fait tourner le bouton de 45° à chaque clic |

Pendant l'édition :
- les deux blocs restent affichés — le résumé ne s'efface pas, et le panneau de stats **ne disparaît plus** quand le curseur quitte le portrait
- chaque cadre est saisi à la souris
- la position est enregistrée dès que tu relâches
- **rouvrir les réglages termine l'édition** (ce qui évite d'y rester coincé)

Le panneau s'affiche en édition même si tu avais désactivé les stats du portrait, sinon tu ne pourrais pas le placer.

En ligne de commande :

```
/sd move          entre ou sort du mode édition
/sd move stop     termine l'édition
/sd resetpos      réinitialise les positions
```

Hors édition, le panneau de stats du portrait revient à son déclenchement par survol, et le résumé de stuff à son fondu de 6 s.


---

## v1.16.1 — « Lancer le check maintenant » débordait

Capture à l'appui : le libellé sortait de son bouton et passait par-dessus « Réglages ». Cause simple — les trois boutons du pied étaient dimensionnés en dur (128, 100, 90 px) sans aucun rapport avec le texte qu'ils portent. « Lancer le check maintenant » demande environ 166 px : il manquait 40 px.

Les largeurs sont maintenant mesurées sur le libellé rendu, plus une marge de 22 px, avec un plancher pour garder une apparence homogène entre les trois. Le calcul est refait à chaque construction, donc une traduction plus longue ne débordera pas : si tu passes en anglais, les boutons s'adaptent.

Cinq assertions verrouillent le pied : chaque libellé tient dans son bouton, « Réglages » ne recouvre pas « Lancer », et l'ensemble tient dans la fenêtre sans mordre sur « Fermer ». Remis `runWidth = 128` en dur, l'assertion échoue avec `128 >= 166.4` — précisément le défaut de la capture.

---

## Ouverture automatique en quittant une zone sûre

C'est le but premier de l'addon, et il faut le dire clairement : **la fenêtre de diagnostic ne s'ouvre pas sur commande, elle s'ouvre au bon moment.** Quand tu quittes une zone apprise comme sûre (capitale, village, auberge, sanctuaire), `Evaluate` détecte la transition *sûre → non sûre* et lance le check. Tu vois ton score et tes conseils à l'instant où ça devient utile : au départ à l'aventure.

Le mécanisme ne se déclenche **que** sur cette transition. Rester en zone non sûre ne relance rien ; rentrer en ville ne l'ouvre pas. Une seconde sortie relance l'alerte normalement. Un temps de silence après connexion (`quietAfterLogin`) et un délai minimal entre deux alertes (`alertCooldown`) évitent les ouvertures parasites.

Si tu préfères un résumé dans le chat, décoche la fenêtre dans les réglages ou `/sd popup off`. `/sd check` restera toujours disponible pour un contrôle manuel.

Cinq assertions couvrent ce comportement : la sortie de zone lance le check et ouvre la fenêtre, rester dehors ne relance rien, une zone sûre n'ouvre rien, et une seconde sortie repart. Neutraliser le déclencheur en fait échouer quatre.

---

## v1.16.0 — suppression du panneau d'équipement

Le panneau flottant affichait 17 emplacements dont neuf restaient « Vide » pendant la majeure partie du leveling, des niveaux d'objet sans unité, et un `ilvl 2` qui ne veut rien dire au niveau 2. Ce qu'il apprenait tenait en une ligne, déjà fournie par le résumé de changement de stuff. Il est supprimé.

`Equip.lua` ne garde que la lecture d'inventaire dont `Stats.lua` dépend. `/sd stuff` imprime désormais le résumé en chat ; sans écart, il le dit au lieu de rester muet.

### Le bouton fantôme

La capture suivante montrait un bouton **« OPT_STUFF_SHORT »** dans la fenêtre de diagnostic. Deux fautes superposées :

1. J'avais retiré la clé de traduction avec le panneau, **sans chercher les autres usages**. `UI.lua` s'en servait encore pour un bouton.
2. Ce bouton appelait `ToggleStuff`, lui aussi supprimé : même traduit, il n'aurait rien fait.

La raison pour laquelle c'est *visible* mérite d'être notée : la métatable de `L` **renvoie la clé brute** quand elle manque, par prudence. Une chaîne vide aurait été discrète ; un identifiant en majuscules au milieu d'une interface saute aux yeux. C'est un bon choix, mais il signifie qu'aucun test ne signalait le problème.

Un garde-fou général le fait maintenant : il scanne les fichiers pour toute référence `L.XXX` et échoue si la clé n'est pas résolue. Injecté `L.OPT_FANTASME`, il signale bien `OPT_FANTASME`.

### Pied du panneau de réglages

- La ligne « Réinitialiser les positions » est retirée de la section AFFICHAGE ; un bouton **« Réinitialiser les cadres »** la remplace, à côté de « Déplacer les cadres », sur la même rangée et de même largeur.
- Les trois boutons du bas occupent trois colonnes égales ; le reste de la division (1 px) va aux premiers plutôt que de laisser un vide à droite. « Réinitialiser » est chaîné entre « Lancer » et « Fermer ».

Les tests du pied lisaient d'abord les constantes de la grille — donc ne voyaient pas un bouton mal ancré. Ils résolvent maintenant les ancres réelles. Le mock y gagnait au passage `relTo` et `relPoint`, qu'il ignorait : sans eux, une ancre chaînée était indiscernable d'une ancre absolue, et deux assertions annonçaient des écarts négatifs.

448 assertions.

---

## v1.15.1 — ce que la capture a révélé

La 1.15.0 corrigeait le blocage, mais la capture d'écran montrait trois défauts que mes tests ne voyaient pas. Ils sont tous de la même famille : **des tests qui comparent le mock à lui-même**.

**Le losange dans la colonne de droite.** Le caractère `▶` (U+25B6) n'existe pas dans `GameFontNormal` : la ligne « Réinitialiser les positions » affichait un losange de remplacement. C'est exactement la cause du rectangle blanc corrigé en 1.12.0 — et le test que j'avais écrit pour l'empêcher ne fonctionnait pas. Il cherchait les octets `E2 96 B6` mais avait été enregistré avec des séquences corrompues (`h82`), donc il passait toujours, y compris avec le caractère fautif en place. Réécrit avec `string.char(0xE2,0x96,0xB6)`, il échoue maintenant dès qu'on remet le triangle.

**Les OUI des modules 70 px trop à droite.** La section « Modules » utilisait encore `-6` au lieu de la colonne commune. Mon test d'alignement passait au vert parce que le mock de `GetPoint` renvoyait `TOPLEFT, 10, -10` en dur, quelle que soit la valeur réelle : il ne pouvait structurellement rien détecter. Le mock enregistre désormais le point posé, et le test compte les lignes mal alignées (9 détectées à l'injection).

Quatre tests existants furent du coup invalidés : ils comparaient `diagPoint.point == "TOPLEFT"` à la constante figée du mock. Ils vérifient maintenant qu'un ancrage valide et deux coordonnées numériques sont mémorisés — ce qui a un sens — au lieu de se citer eux-mêmes.

**Le trou avant les boutons.** La hauteur était additionnée à l'avance et comptait une section de trop. Elle est maintenant calculée **après** avoir posé la dernière ligne, à partir de sa position réelle. Le test vérifie que l'espace entre le dernier module et les boutons reste entre 10 et 30 px ; à l'injection de 60 px, il signale 78.

Un mot sur la méthode : la première fois, j'avais mesuré ce trou à 40 px par le calcul alors que la capture en montrait davantage. Le calcul était juste pour la partie sections mais faux pour le flux des modules ; c'est l'image qui avait raison. J'ai cessé d'additionner des marges à la main.

442 assertions.

---

## v1.15.0 — réglages refondus, et fin du piège du mode édition

Deux retours de Tristabeau : « je trouve cet écran pas du tout joli » et « quand je rentre en mode édition, il disparaît et je ne peux plus en sortir ».

### Le blocage du mode édition

C'était un **cul-de-sac**, pas un gêne visuelle. `RunOptionAction` fermait le panneau de réglages pour dégager la vue — mais le bouton **« Terminer le déplacement »** vivait dans ce panneau. Il disparaissait donc avec lui. La seule issue restante était la commande `/sd move stop`, que rien n'indiquait à l'écran.

Un **bandeau d'édition** permanent prend le relais : il s'affiche en haut de l'écran dès l'entrée en édition, rappelle qu'on fait glisser les cadres, et porte son propre bouton de sortie. Il vit dans une fenêtre séparée, survit au rafraîchissement du portrait et aux changements d'équipement, et se masque à la sortie.

### Le panneau de réglages

L'ancienne version alignait quinze lignes de même poids : impossible de voir où commençaient les réglages d'alerte, ni où finissaient les options d'affichage. Trois changements :

**Des sections.** `AFFICHAGE` (7 lignes), `SEUILS D'ALERTE` (7 lignes, avec la précision « sous ces valeurs, l'alerte se déclenche »), `DIVERS` (1 ligne), puis `Modules`. Chacune est séparée par un filet.

**Une colonne de valeurs unique.** Les `OUI`, les nombres et les boutons `-`/`+` s'alignent enfin, quelle que soit la ligne. La géométrie est exposée dans `ns.OPT_LAYOUT` et vérifiée par tests : la valeur ne touche pas le bouton `-`, et les deux boutons ne se chevauchent pas.

**Des libellés raccourcis.** « Emplacements libres minimum » devient « Emplacements libres », « Repos minimum (pourcent d'un niveau) » devient « Repos » avec l'unité portée près du nombre. La colonne de gauche se lit d'un coup d'œil au lieu d'être déchiffrée ligne par ligne.

Le bouton « Lancer le check maintenant » débordait de sa boîte ; sa largeur suit maintenant son texte.

### Vérification

437 assertions. Cinq tests couvrent le bandeau : affiché à l'entrée, porteur d'un bouton, survivant au rafraîchissement du portrait et au changement de stuff, masqué à la sortie. J'ai neutralisé `ShowEditBanner` pour vérifier qu'ils mordent — cinq échecs, puis retour au vert. Trois autres tests verrouillent la géométrie de la colonne de droite.

---

## v1.14.0 — priorités officielles Forever, relevées sur les guides

Jusqu'ici, la table `SPEC_STATS` reposait sur ma mémoire des conventions Classic. Tristabeau m'a indiqué l'URL des guides Forever sur Wowhead : `wowhead.com/forever/fr/guide/classes/druid/balance/overview-pve-dps`. C'était la bonne piste, et elle change plusieurs réponses.

### Comment les données ont été obtenues

Les pages `stat-priority-*` sont **26 sur 27** spécialisations (Mage Givre renvoyait une redirection publicitaire en cache, réessayée sans succès). Pour chacune, j'ai lu la liste numérotée officielle et conservé **l'ordre relatif des cinq attributs primaires** ; les secondaires (toucher, expertise, hâte, puissance des sorts) ne concernent pas ce panneau.

### Ce que la table disait faux

| Cas | v1.13.1 (ma mémoire) | Guide Forever |
|---|---|---|
| Mage (toutes spés) | Esprit jugé inutile | Esprit **listé**, rang 7 |
| Démoniste | Esprit écarté | Esprit **listé** |
| Chasseur | Esprit écarté | Esprit **listé** |
| Paladin Vindicte | Force d'abord | **Intelligence d'abord** |
| Guerrier Armes/Fureur | Guerrier sans Endurance | Endurance non listée en Armes, **présente en Fureur** |
| Chaman Amélioration | Force dominante | **Force et Intellect à égalité** |
| Druide Restauration | Intellect d'abord | **Esprit d'abord** |
| Démoniste | 3 attributs | **2 seulement** (Intellect, Esprit) |

Le cas le plus net : j'avais écrit que l'Esprit ne servait à rien à un mage en Classic. Le guide Forever dit l'inverse — Armure de givre fait régénérer l'Esprit même en lançant des sorts.

### Druide Farouche : deux métiers, deux ordres

L'ours et le félin n'ont pas la même priorité. Le panneau lit la forme courante (`GetShapeshiftForm`) et bascule :

- **félin** : Agilité, Force, Intellect, Esprit, Endurance ;
- **ours** : Endurance, Agilité, Force.

### Vérification

427 assertions. Quatre tests de contenu verrouillent les points où je m'étais trompé : Vindicte commence par l'Intelligence, Protection paladin par l'Endurance, Démoniste n'affiche ni Force ni Agilité, et le Farouche change d'ordre selon la forme. J'ai vérifié leur mordant : en inversant Protection paladin, puis en neutralisant la détection d'ours, les tests échouent bien avant que je rétablisse le code.

La vérification d'intégrité de la table ne réclame plus l'Endurance partout (elle n'est pas dans toutes les listes officielles) mais contrôle l'absence de doublons, de clés inconnues et de listes de plus de cinq entrées.

### Réserve

Une seule spé n'a pas pu être relevée : **Mage Givre**, alignée sur les deux autres spés de mage. À corriger si le guide publié s'en écarte.

---

## v1.13.1 — seulement les statistiques qui servent

Retour de Tristabeau : « pour le guerrier par exemple intelligence et esprit on s'en fiche ». Il a raison, et c'est une correction de fond, pas un réglage.

La v1.13.0 affichait **toujours les cinq statistiques primaires** et se contentait de souligner la bonne. Un guerrier lisait donc l'Intelligence et l'Esprit à chaque survol — deux lignes pour deux nombres qui ne changent rien à ses dégâts.

### Ce qui change

`SPEC_PRIMARY` (une clé par spé) devient `SPEC_STATS` (une **liste ordonnée** par spé). La liste sert deux choses à la fois :

- **quelles statistiques afficher** : plus rien d'autre n'apparaît ;
- **dans quel ordre** : la première est mise en or, les suivantes en parchemin.

| Classe | Spé 1 | Spé 2 | Spé 3 |
|---|---|---|---|
| Guerrier | Force, Endurance | Force, Endurance | Endurance, Force |
| Paladin | Intelligence, Endurance | Force, Endurance | Intelligence, Force, Endurance |
| Chasseur | Agilité, Endurance, Intelligence | idem | Agilité, Endurance |
| Voleur | Agilité, Force, Endurance | idem | Agilité, Endurance |
| Prêtre | Intelligence, Esprit, Endurance | idem | idem |
| Chaman | Intelligence, Endurance | Force, Agilité, Endurance | Intelligence, Esprit, Endurance |
| Mage | Intelligence, Endurance | idem | idem |
| Démoniste | Intelligence, Endurance | idem | idem |
| Druide | Intelligence, Esprit, Endurance | Force, Agilité, Endurance | Intelligence, Esprit, Endurance |

L'**Endurance** reste partout : elle ne donne pas de dégâts, mais c'est la statistique que tout joueur surveille en changeant d'équipement.

### Vérification

Neuf tests balaient la table : neuf classes, trois spécialisations chacune, aucune clé inconnue, aucun « nil » possible, Endurance présente partout. J'ai faussé volontairement `AGI` en `AG1` pour vérifier que la vérification de clés réagit — elle signale `ROGUE/3:AG1` et échoue ; rétabli ensuite.

Les tests de rendu ont été réécrits en conséquence : un Guerrier ne doit afficher **ni** Intelligence **ni** Esprit, un Voleur n'a pas d'Esprit, un Druide Restauration n'a pas de Force.

### Même réserve qu'en v1.13.0

La table vient des conventions Classic Era (Wowhead, Icy Veins), pas d'une extraction des données du client. Les cas ouverts :

- **Paladin Sacré** : l'Intelligence pour le mana, oui, mais la Force reste utile au nivellement.
- **Druide Farouche** : Force en ours, Agilité en félin — les deux sont affichées, à toi de dire si c'est trop.
- **Chaman Élémentaire** : l'Esprit n'est pas listé, alors qu'il aide la régénération. Ajoutable en une ligne.

---

## v1.13.0 — statistiques principales selon la classe et la spécialisation

Le panneau au survol du portrait soulignait **la statistique la plus élevée**. C'était simple, et faux : un guerrier Protection a presque toujours plus d'Endurance que de Force, mais c'est la Force qu'il cherche à lire. Un prêtre Sacré, lui, veut voir son Intelligence et son Esprit.

### Ce qui a changé

**L'Esprit manquait purement et simplement.** Le relevé lisait `UnitStat` 1 à 4 (Force, Agilité, Intelligence, Endurance) et ignorait la cinquième statistique primaire. Elle est maintenant relevée et affichée, avec ses traductions (`Esprit` / `Spirit`).

**La mise en avant suit la classe et l'arbre de talents**, via une table `SPEC_PRIMARY` indexée par classe puis par numéro de spécialisation :

| Classe | Spé 1 | Spé 2 | Spé 3 |
|---|---|---|---|
| Guerrier | Force | Force | Endurance |
| Paladin | Intelligence | Force | Endurance |
| Chasseur | Agilité | Agilité | Agilité |
| Voleur | Agilité | Agilité | Agilité |
| Prêtre | Intelligence | Intelligence | Intelligence |
| Chaman | Intelligence | Force | Intelligence |
| Mage | Intelligence | Intelligence | Intelligence |
| Démoniste | Intelligence | Intelligence | Intelligence |
| Druide | Intelligence | Force | Intelligence |

L'index de spécialisation est utilisé plutôt que son nom : les noms sont localisés et diffèrent selon le client, l'index est stable.

**Le DPS était tronqué.** La boucle qui crée les lignes s'arrêtait à 6 alors qu'il en faut 7 depuis l'ajout de l'Esprit — le DPS disparaissait sans que rien ne le signale. Le test existant l'a attrapé immédiatement.

### Vérification

Quatre tests balaient le panneau classe par classe : un Voleur doit souligner l'Agilité, un Prêtre l'Intelligence, un Druide Restauration ne doit pas souligner l'Endurance, et l'Esprit doit rester listé partout. J'ai vérifié qu'ils attrapent une régression en faussant volontairement la ligne du Voleur dans la table : le test échoue, puis repasse une fois la table rétablie.

### Réserve

Les correspondances de la table viennent des guides Classic Era (Wowhead, Icy Veins), pas d'une extraction des données du client. Deux cas sont discutables et je les signale plutôt que de les masquer :

- **Paladin Sacré** : le guide recommande l'Intelligence pour le mana, mais le nivellement se fait souvent à la Force. J'ai retenu l'Intelligence.
- **Druide Farouche** : l'Agilité et la Force se disputent la place selon le rôle (ours ou félin). J'ai retenu la Force.

Si l'un de ces choix diverge de ton expérience en jeu, c'est une ligne à changer dans `SPEC_PRIMARY`.

---

## v1.12.1 — plus de cadre vide quand les stats ne bougent pas

Signe d'attention de Tristabeau : un item remplacé par un autre **sans différence de statistiques** faisait apparaître le bloc titre + règle, sans aucune ligne dessous.

La cause est une conséquence directe du passage à une ligne unique. `ShowGearToast` affichait le cadre sans se demander si `ToastRows` avait produit quelque chose. Avec quatre emplacements, le cas ne se voyait pas : il restait trois lignes vides sous une première ligne. Avec un seul, un équipement sans écart donne **zéro ligne et un cadre nu**.

```lua
local built = self:ToastRows(rows, texture)
if #built == 0 then
    if self.toastFrame then self.toastFrame:Hide() end
    self.toastHideAt = nil
    return
end
```

Le cadre existant est masqué et le minuteur d'effacement remis à zéro, pour qu'un résumé précédent encore visible ne reste pas figé à l'écran.

Un test couvre ce cas : il équipe un objet de mêmes caractéristiques, vérifie qu'aucun cadre n'apparaît, et **échoue bien** si l'on retire le garde-fou (vérifié en le neutralisant).

---

## v1.12.0 — une seule ligne par item, centrage par ancrage CENTER

Demande de Tristabeau : **une seule ligne par changement d'équipement**, et son contenu centré verticalement.

### Une ligne, pas quatre

`TOAST_ROWS` passe de 4 à 1. Les écarts sont toujours calculés tous les quatre, mais seul le premier est affiché. C'est un choix de lisibilité : le bloc se lit d'un coup d'oeil, sans tableau à déchiffrer sous le feu de l'action.

Les tests qui décrivaient l'ancien format (« une ligne par écart », « tronqué à quatre lignes », `rows[4]`) ont été réécrits pour verrouiller le nouveau contrat : un seul emplacement, pas de deuxième ligne, la ligne pleine montre son icône et sa flèche.

### Le vrai motif du décalage, enfin

Trois versions ont échoué à centrer l'icône et la flèche. La comparaison des captures a donné la clé : le décalage est passé de 14 px à 19 px entre la v1.11.2 et la v1.11.4. **Le code agissait donc bel et bien — mais dans le sens inverse de celui attendu.**

La raison : une **fontstring** ancrée en `TOPLEFT` pend sous son point d'ancrage, tandis qu'une **texture** ancrée en `TOPLEFT` ne se comporte pas de la même façon vis-à-vis du décalage. Jusque-là je calculais le centre des textures avec la formule du texte, ce qui revenait à doubler l'erreur de sens.

La solution ne consiste pas à inverser un signe de plus, mais à **changer d'ancrage** : icône et flèche sont maintenant ancrées en `CENTER`, sur le milieu de la ligne. Le décalage n'a plus qu'un seul rôle — dire où est le milieu — et la question du sens disparaît.

```lua
local lineMiddle = y + TOAST_LINE_MIDDLE * factor
icon:SetPoint("CENTER", frame, "TOPLEFT", (inset + TOAST_ICON / 2) * factor, lineMiddle)
arrow:SetPoint("CENTER", frame, "TOPLEFT",
    (inset + TOAST_ARROW_LEFT + ARROW_SIZE / 2) * factor, lineMiddle)
```

Les tests comparent désormais le point enregistré (qui **est** le milieu, grâce à `CENTER`) au milieu de référence calculé depuis le haut de ligne. Ils vérifient aussi que l'icône et la flèche ont le même milieu.

### Ce que je dois à la v1.11.4

La v1.11.4 corrigeait réellement l'icône manquante au retrait d'un item, et ce correctif reste en place. En revanche elle annonçait un centrage vertical qui n'a jamais fonctionné. Son diagnostic — « il faut inverser le signe » — était partiel : le problème n'était pas le signe, mais le fait de vouloir centrer une texture avec la géométrie d'un texte.

---

## v1.11.4 — centrage vertical corrigé, icône au retrait d'un item

Deux défauts signalés en jeu, tous deux de ma faute.

### L'icône descendait au lieu de monter

La v1.11.3 prétendait centrer l'icône sur la ligne. En réalité je m'étais trompé de signe : l'icône et la flèche descendaient de 7 px sous le texte au lieu de remonter de 7 px au-dessus. La capture de Tristabeau est sans ambiguïté, la flèche flotte sous les chiffres.

Le raisonnement correct, et il m'a fallu m'y reprendre à deux fois :

- une fontstring ancrée en `TOPLEFT` **pend sous son point d'ancrage**, donc le milieu des chiffres est à `TOAST_TEXT_HEIGHT / 2` **en dessous** du haut de ligne, en coordonnées négatives ;
- le haut d'un élément dont on veut centrer le milieu se place à `milieu du texte - hauteur / 2`.

```lua
local TOAST_LINE_MIDDLE = -TOAST_TEXT_HEIGHT / 2
local iconY  = y + (TOAST_LINE_MIDDLE - TOAST_ICON / 2) * factor
local arrowY = y + (TOAST_LINE_MIDDLE - ARROW_SIZE / 2) * factor
```

Pour une ligne à `-30` : milieu des chiffres `-34`, haut de l'icône `-41`, haut de la flèche `-39`. Les trois milieux coïncident.

Les tests de la v1.11.3 ne pouvaient pas attraper cette erreur : l'un comparait `TOAST_ROW_TOP` à lui-même, une assertion tautologique qui passait toujours. Les nouveaux tests comparent des **milieux à milieux** et vérifient explicitement que l'icône remonte par rapport au haut de ligne.

### Pas d'icône quand on retirait un item

Retirer un objet laisse `after.slots[slot]` vide : il n'y a plus de lien à interroger, donc plus d'icône. La ligne s'affichait sans repère visuel.

`SlotTexture` accepte maintenant un troisième argument, le lien précédent, et essaie dans l'ordre : lien actuel, puis lien de l'item qui vient d'être retiré, puis API d'emplacement. C'est sémantiquement juste — retirer un item doit montrer *son* icône.

### Une leçon sur les mocks

Le correctif ci-dessus était bon du premier coup, mais mon test échouait : le mock ne fournissait `GetItemInfo` qu'en `C_Item.GetItemInfo`, alors que le client l'expose aussi en global. L'addon retombait silencieusement sur l'API d'emplacement, vide. Le mock est désormais fidèle au client, et un test existant qui attendait `INV_Mock10` (repli par emplacement) vérifie maintenant la vraie icône du lien.

400 assertions, aucune en échec.

## v1.11.2 — contenu centré dans le bloc

La capture montrait un déséquilibre : la règle allait jusqu'à 193 unités, le contenu s'arrêtait à 113. **40 unités de vide d'un seul côté**, le contenu collé à gauche.

Le bloc avait une largeur fixe, mais ses lignes étaient toutes ancrées à `x = 0`. Rien ne les centrait. J'ai introduit un `inset` calculé une fois pour toutes :

```lua
local inset = ((TOAST_WIDTH - TOAST_CONTENT_WIDTH) / 2) - TOAST_CONTENT_LEFT
```

Le titre, l'icône, la valeur, la flèche et le libellé sont tous décalés de cette valeur. Le contenu le plus large occupe 181 unités pour un bloc de 190 : la marge est donc de **4,5 unités de chaque côté**. C'est peu — mais c'est le bon chiffre, et il s'ajustera automatiquement si la largeur du bloc ou celle du contenu change.

Quatre tests verrouillent l'équilibre : marge gauche égale à la marge droite, inset positif, et chaque région décalée du bon montant (à l'échelle du client près).

---

## v1.11.1 — bloc resserré horizontalement

La capture en jeu montrait un bloc étiré : 64 px de vide entre le chiffre et la flèche. Deux causes, deux corrections.

**La colonne des libellés était calée sur la largeur de référence (84),** héritée d'une maquette où les valeurs étaient plus longues. Mesure faite sur les valeurs réelles : `+8` finit à 30, `-0,60 s` à environ 60. La flèche démarre donc à 62 et les libellés à 76.

| Élément | v1.11.0 | v1.11.1 |
|---|---|---|
| Colonne des libellés | 84 | 76 |
| Début de la flèche | 70 | 62 |
| Largeur du bloc | 264 | 190 |

**La flèche était positionnée relativement au libellé** (`TOAST_LABEL_LEFT - taille - écart`), ce qui la décalait à chaque changement de colonne. Elle a maintenant sa propre constante, `TOAST_ARROW_LEFT`, et trois tests vérifient qu'elle démarre après la valeur la plus longue et ne touche jamais le libellé.

Le gain final est modeste à l'œil — 8 px sur la colonne, 74 px sur la largeur du bloc — mais la mise en page ne dépend plus d'une largeur héritée : elle découle des valeurs mesurées.

---

## v1.11.0 — les flèches deviennent des textures

Les trois tentatives précédentes avaient toutes échoué pour la même raison : je cherchais un **caractère** qui s'affiche. Or la police du client s'arrête à `0xCA`, et aucune flèche — ni `▼`, ni `λ`, ni `v` — n'avait la forme voulue. `v` et `^` s'affichaient, mais ce sont des lettres, pas des flèches.

La solution est de ne plus passer par du texte. Deux textures sont livrées avec l'addon :

| Fichier | Sens | Taille |
|---|---|---|
| `Textures/fleche_hausse.tga` | gain | 128 × 128, 64 KB |
| `Textures/fleche_baisse.tga` | perte | 128 × 128, 64 KB |

Elles sont dessinées **en blanc pur** : la couleur est appliquée en jeu par `SetVertexColor`, avec le même vert et le même rouge que la valeur affichée à côté. Une seule paire de textures sert donc aux deux sens comme à toute teinte future.

La valeur ne contient plus que le nombre (`+8`, `-0,60 s`), la flèche occupe une texture de 10 px calée à gauche de la colonne des libellés. Elle est masquée sur les lignes vides et en mode édition.

Sept tests couvrent l'ensemble : valeur sans glyphe, valeur en ASCII pur, présence des textures, sens de la flèche, teinte alignée sur la valeur, visibilité, masquage sur ligne vide.

**Note sur le format.** Les `.tga` sont lus par toutes les versions du client sans plugin, et c'est le seul format d'image que le jeu accepte sans dépendance. Les fichiers sont en 128 × 128 (puissance de deux), l'empreinte réelle des flèches occupant 64 × 84 au centre du canevas.

---

## Correction v1.10.3 — les flèches en ASCII, enfin vérifiées

Troisième tentative sur le même défaut, et cette fois la cause est établie par mesure, plus par supposition.

**Le rectangle, c'est un glyphe manquant.** Sur la capture zoomée, il mesure 14 × 16 px, ratio d'une case de substitution, et se dessine en contour de 1 px **sans ombre portée** — alors que tout le texte en porte une. Une texture n'aurait pas ce comportement.

**Pourquoi `λ` et `α` ne marchaient pas non plus.** Le client range ses polices dans `Fonts/615960.slug` (police « Friz Quadrata TT »). En lisant la table de glyphes de ce fichier, on trouve les 822 codepoints enregistrés : ils s'arrêtent à **0xCA**. Ni `U+25BC`, ni `U+03BB`, ni `U+03B1` n'y figurent. J'avais supposé que « toutes les polices ont les lettres grecques » — c'est faux pour celle du client.

| Sens | v1.10.1 | v1.10.2 | v1.10.3 |
|---|---|---|---|
| Baisse | `▼` U+25BC | `λ` U+03BB | `v` ASCII |
| Hausse | `▲` U+25B2 | `α` U+03B1 | `^` ASCII |

**La règle est désormais simple : rien au-dessus de l'ASCII.** Le `v` et le `^` existent dans toutes les polices sans exception, et deux tests vérifient que le dernier octet de la flèche est bien inférieur à 128.

Les emoji de flèche verte et rouge ne sont pas une option : ils vivent à `U+2B06` / `U+2B07`, très au-delà de ce que la police contient — ils produiraient exactement le même rectangle. La couleur est déjà portée par la valeur elle-même (vert pour un gain, rouge pour une perte), le symbole n'a donc qu'à indiquer la direction.

---

## Correction v1.10.2 — casse du titre et des libellés

| Élément | v1.10.1 | v1.10.2 |
|---|---|---|
| Titre | `statistiques` en minuscules | `S T A T I S T I Q U E S` |
| Libellés | `ARMURE` en capitales | `Armure`, `Vitesse D'attaque` (PascalCase) |

Le titre repasse en majuscules — son interlettrage le distingue déjà des lignes, et c'est la casse de la référence. Les libellés passent en PascalCase, plus lisibles que des capitales sur un texte français.

Deux pièges rencontrés en écrivant la conversion, tous deux **corrigés et couverts par des tests** :

- **`string.upper` corrompt les accents.** `string.upper("é")` applique la conversion octet par octet : `é` (deux octets UTF-8) devient `Ã©`. La fonction `PascalCase` recopie donc les séquences multi-octets telles quelles et ne touche qu'aux lettres ASCII.
- **La variable d'un `for` ne s'avance pas en Lua 5.1.** Pour sauter les octets de continuation, il faut réassigner l'index de boucle — impossible avec `for`, où la valeur est réinitialisée à chaque tour. La boucle est donc en `while`.

---

## Correction v1.10.1 — le carré vert, et l'harmonisation du bloc

Deux défauts constatés à l'essai de la 1.10.0.

**Le rectangle vert à côté du chiffre** n'était pas une texture : c'était un **glyphe manquant**. Les triangles `▼` `▲` appartiennent au bloc Unicode *Geometric Shapes* (U+25BC / U+25B2) et manquent à la police utilisée par le client, qui les remplace par une case vide. C'était la deuxième fois que ce piège se présentait, après `NumberFontNormal` — la conclusion est qu'aucun caractère hors alphabet latin n'est sûr sans vérification.

| Avant | Après |
|---|---|
| `▼` U+25BC | `v` (ASCII) |
| `▲` U+25B2 | `^` (ASCII) |

Les lettres grecques minuscules font partie des jeux de caractères de base des polices, elles s'affichent partout. Elles gardent le sens — vers le bas pour une perte, vers le haut pour un gain — et prennent la couleur de la valeur.

**L'écriture** n'était pas homogène : le titre sortait dans un corps plus petit que les lignes, alors que les deux mesurent 14 px dans la référence. Le titre reprend donc le **même corps de police** que les lignes ; seule l'interlettrage et la teinte (parchemin à 70 %) le distinguent. Le bloc a désormais un rythme vertical constant.

Trois autres ajustements tirés du même essai :

- le titre abandonne les majuscules, `statistiques` dans les locales s'affiche tel quel
- l'interlettrage passe par `SetNonSpaceGlyphSpacing` quand le client l'expose, avec repli sur les espaces littérales
- le harnais de test survit désormais à une console Windows en `cp1252` : il remplace les caractères non représentables au lieu de planter au moment d'afficher le résultat

---

## Changement v1.10.0 — le résumé reprend la mise en page de la référence

La ligne unique de la 1.9.0 était trop pauvre : on ne distinguait plus la valeur du libellé, et une infinité de segments séparés par `·` se lisait mal. Le bloc reprend la composition relevée sur la maquette de référence.

| Élément | v1.9.0 | v1.10.0 |
|---|---|---|
| Titre | aucun | `S T A T I S T I Q U E S`, petit, parchemin à 70 % |
| Règle | aucune | trait continu 1 px, parchemin à 45 % |
| Structure | une ligne, segments `·` | 4 emplacements, valeur à gauche / libellé à droite |
| Libellé | dans la même phrase que la valeur | **majuscules, parchemin**, jamais coloré |
| Flèche | aucune | `▲` gain, `▼` perte, dans la couleur de la valeur |
| Icône | aucune | icône de l'objet équipé (14 × 14) |
| Fond, bordure | aucun | **aucun** (inchangé) |

Le cadre n'a pas de fond : deux colonnes de texte et un trait suffisent, l'ombre portée détache l'ensemble du décor.

Trois détails qui évitent les régressions :

- **Les flèches sont sûres.** `GameFontHighlightSmall` contient `▲` et `▼`, contrairement à `NumberFontNormal` qui les rend en points de suspension (piège déjà rencontré).
- **Les lignes inutilisées sont vidées** de leur texte *et* de leur icône. Sinon l'écart précédent resterait visible sous le nouveau.
- **En mode édition, le bloc montre sa structure** (titre, règle, quatre lignes d'attente grises). Un cadre vide n'aurait ni la bonne taille ni la bonne forme au moment du placement.

Le texte de libellé est en français dans `Locales.lua`, sous les clés `STAT_*` existantes ; seul le titre court a été ajouté (`STATS_TITLE_SHORT`).

---

## Changement v1.9.0 — le résumé éphémère n'a plus de cadre

Plus de boîte, plus de fond, plus de bordure : **une seule ligne de texte**.

```
+3 Armure   ·   -0,60 s Vitesse d'attaque
```

| Élément | Avant | Maintenant |
|---|---|---|
| Fond | noir à 66 % | **aucun** |
| Bordure | filet 1 px | **aucune** |
| Icône | 14 × 14 | **aucune** |
| Pastille par ligne | barre de 3 px | **aucune** |
| Structure | 4 lignes empilées | **une ligne**, segments séparés par `·` |
| Lisibilité | fond opaque | **ombre portée** (`SetShadowColor` + offset 1, −1) |

Chaque écart garde sa couleur : vert si c'est un gain, rouge si c'est une perte — la polarité est conservée (sur la vitesse d'attaque, une baisse est verte).

Au-delà de **trois** écarts, seuls les trois premiers sont affichés. Une ligne qui s'étire sur toute la largeur de l'écran serait pire que le problème qu'elle signale.

### Ce qui reste

- le **fondu de 6 s**
- la **position mémorisée**, déplaçable via le bouton « Déplacer les cadres »
- en mode édition, une **bordure dorée apparaît** autour de la ligne — sinon un cadre invisible serait impossible à saisir

Le panneau de stats au survol du portrait, lui, garde son filet : il reste affiché à l'écran, il a besoin d'un contour pour se détacher du décor.

## Correction v1.8.1 — les cadres ne bougeaient pas

`Theme.CreateDiscreet` préparait le déplacement sans jamais le brancher :

```lua
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
-- il manquait ceci
frame:SetScript("OnDragStart", frame.StartMoving)
```

`SetMovable` autorise, `RegisterForDrag` déclare le bouton, mais **sans `OnDragStart` rien ne se passe** : WoW n'appelle jamais `StartMoving`. Le mode édition activait bien la souris et la lueur, mais glisser ne faisait strictement rien.

Ajouté sur les deux cadres (résumé de stuff et stats du portrait), avec `OnDragStop` par défaut ; le panneau de stats garde son propre `OnDragStop` qui enregistre la position manuelle.

### Le harnais masquait le bug

Le mock définissait `StartMoving` **deux fois** — une version utile, puis un no-op qui l'écrasait. Les tests appelaient `OnDragStop` directement, donc ils passaient sans jamais vérifier que le glissement démarre.

Corrigé, et un **garde-fou** a été ajouté au lanceur : il refuse de démarrer si une méthode du mock est définie deux fois. C'est la deuxième fois que ce piège me coûtait un bug (après `SetBackdrop`) :

```
ERREUR: méthodes dupliquées dans le mock (la seconde écrase la première) :
  region:StartMoving
```

## Changement v1.8.0 — un bouton pour le mode édition

La ligne « Mode édition des cadres » avec sa flèche `▶` était tout sauf instinctive : rien n'indiquait qu'elle déclenchait un mode.

Remplacée par un **bouton pleine largeur** au-dessus du pied du panneau :

```
[        Déplacer les cadres        ]
[ Lancer le check ] [ Réinitialiser ] [ Fermer ]
```

Pendant l'édition, son libellé devient **« Terminer le déplacement »** — on sait toujours dans quel état on est, et on peut en sortir d'un clic.

Il reste utilisable en ligne de commande (`/sd move`, `/sd move stop`).

### La ligne de position devient informative

« Position du bouton de minicarte » affichait aussi un `▶`. Elle affiche maintenant **l'angle courant** :

```
Position du bouton de minicarte        225°
```

Chaque clic fait tourner de 45° et la valeur suit.

Le panneau passe de 25 à 24 lignes (13 réglages + 2 actions + 9 modules), plus le bouton.

## Chrome des fenêtres — fond et bord d'infobulle

Les deux fenêtres utilisent le chrome d'AtlasLootClassic :

```lua
{
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
```

| Élément | Source |
|---|---|
| Fond | `UI-Tooltip-Background`, noir à 92 % |
| Bord | `UI-Tooltip-Border` (neuf tranches, teinte d'origine) |
| Bandeau | bande noire à 72 % + filet doré, titre en or |
| Croix | `UIPanelCloseButton` |
| Fermeture | **Échap** via `UISpecialFrames` |
| Portrait | aucun |

Pas de template Blizzard : c'est ce que fait AtlasLoot, et c'est plus sobre qu'une fenêtre à fond de pierre.

Les deux fenêtres sont nommées (`Ready2QuestDiagFrame`, `Ready2QuestOptionsFrame`) — nécessaire pour que Échap fonctionne.

Si `BackdropTemplate` manque, le panneau retombe sur un chrome dessiné à la main (filets `WHITE8X8`) : il reste complet, simplement moins joli.

## Changement v1.6.0 — aligné sur LibDBIcon (référence AtlasLootClassic)

Le bouton de minicarte reprend **exactement** l'implémentation de `LibDBIcon-1.0`, la bibliothèque qu'utilise AtlasLootClassic.

| Paramètre | Valeur reprise |
|---|---|
| Bouton | **31 × 31**, niveau de cadre **8** |
| Liseré | `MiniMap-TrackingBorder` — **fileID 136430** |
| Pastille | `UI-Minimap-Background` — **fileID 136467** |
| Surbrillance | `UI-Minimap-ZoomButton-Highlight` — **fileID 136477** |
| Ordre des couches | liseré en `OVERLAY`, pastille en `BACKGROUND`, icône en `ARTWORK` |
| Rayon | `Minimap:GetWidth() / 2 + 5` — **calculé**, plus codé en dur |
| Angle par défaut | **225°** (valeur par défaut de LibDBIcon) |

### FileID plutôt que chemin

`SetTexture(136430)` au lieu de `"Interface\\Minimap\\MiniMap-TrackingBorder"`. C'est ce que fait LibDBIcon : le client résout le fichier par son identifiant, ce qui survit aux déplacements de fichiers et fonctionne identiquement en Classic et en Forever.

### Deux chromes, comme LibDBIcon

| Client | Liseré | Pastille | Icône |
|---|---|---|---|
| Mainline / Forever | 50 × 50 | 24 × 24 centrée (0, 1) | 18 × 18 |
| Classic (Era, MoP) | 53 × 53 | 20 × 20 à (7, −5) | 17 × 17 à (7, −6) |

Le choix se fait sur `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` quand la constante existe, sinon sur le numéro d'interface.

### Minicartes non rondes

La formule de LibDBIcon est reprise intégralement, y compris `GetMinimapShape()` et le calcul diagonal pour les minicartes carrées (ElvUI et compagnie). Plus de bouton qui flotte à côté sur une minicarte custom.

## Ce qu'AtlasLoot fait pour les fenêtres

Contrairement à ce qu'on pourrait croire, ils **n'utilisent aucun template Blizzard**. Leur cadre principal :

```lua
local frame = CreateFrame("Frame", name, nil, _G.BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetBackdrop(ALPrivate.BOX_BORDER_BACKDROP)
frame.CloseButton = CreateFrame("Button", name.."-CloseButton", frame, "UIPanelCloseButton")
tinsert(UISpecialFrames, name)
```

avec

```lua
BOX_BORDER_BACKDROP = {
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
```

Donc : fond d'infobulle + bord d'infobulle, bouton `UIPanelCloseButton`, et **Échap**. C'est plus sobre qu'une fenêtre natale à fond de pierre.

### Ce que j'ai repris d'eux

- **`UISpecialFrames`** : Échap ferme le diagnostic et les réglages (comme toutes les fenêtres du jeu)
- les deux fenêtres sont désormais **nommées** (`ReadyToQuestDiagFrame`, `ReadyToQuestOptionsFrame`), condition nécessaire pour Échap
- `UIPanelCloseButton` était déjà utilisé (le template natif le fournit)

### Ce que je n'ai pas repris

Le chrome à base de `UI-Tooltip-Background` / `UI-Tooltip-Border`. Voir la question posée en fin de message.

## Changement v1.4.0 — cadres flottants discrets

### Les « … » venaient des flèches

Les lignes du résumé utilisaient `▲` et `▼`. Ces glyphes **n'existent pas dans `NumberFontNormal`** sur Classic : le client les rendait comme des points de suspension tronqués.

Remplacés par une **barre de couleur de 3 × 9 px** — vert si c'est un gain, rouge si c'est une perte. Pas de caractère exotique, donc plus aucun risque selon la police ou la locale.

### Plus de cadre « lourd »

Les deux affichages flottants n'utilisent plus le panneau à titre (`CreatePanel`) mais un nouveau chrome minimal : `Theme.CreateDiscreet`.

| Élément | Avant | Maintenant |
|---|---|---|
| Bandeau de titre | oui | **non** |
| Croix de fermeture | oui | **non** |
| Bordure | double liseré or | **filet 1 px** or atténué (55 %) |
| Fond | `UI-DialogBox-Background-Dark` opaque | **noir à 66 %**, on voit le jeu derrière |
| Reflet de bandeau | oui | **non** |
| Hauteur | fixe | **suit le nombre de lignes** |

Le résumé de stuff fait 172 px de large pour 29 px de haut sur une seule ligne ; le panneau de stats 176 px, avec la ligne « classe · spé » et l'ilvl en en-tête à la place d'un titre.

L'idée est de se rapprocher des petits encadrés de la capture de référence : une boîte, un filet, du texte, rien d'autre.

## Changement v1.3.0 — carte de comparaison supprimée

La carte flottante de comparaison au survol a été **retirée**. Blizzard fournit déjà la comparaison native (infobulles côte à côte) et la carte faisait doublon.

| Élément | État |
|---|---|
| Carte de comparaison au survol | **supprimé** |
| Hook `TooltipDataProcessor` / `OnTooltipSetItem` | **supprimé** |
| Réglage « Comparaison au survol » | **supprimé** |
| `/sd stuff diag` | **supprimé** |
| Panneau d'équipement `/sd stuff` | conservé |
| Résumé éphémère au changement de stuff | conservé |
| Stats au survol du portrait | conservé |

283 lignes de code mort en moins. Le panneau d'équipement reste, avec son ilvl moyen et le repérage des pièces faibles.

## Corrections v1.1.1

### `Locales.lua: C stack overflow` au survol

Le repli de traduction posait sa métatable **sur la table française elle-même** :

```lua
-- cassé : sur un client frFR, base == frFR
ns.L = setmetatable(base, { __index = function(_, key)
	if frFR[key] ~= nil then return frFR[key] end   -- se rappelle à l'infini
	return key
end })
```

Sur un client français, `base` **est** `frFR`, donc la lecture de `frFR[key]` dans `__index` réentrait dans `__index` — récursion infinie dès qu'une clé manquait.

```lua
-- corrigé : métatable sur une table proxy, jamais sur base
local L = {}
setmetatable(L, { __index = function(_, key)
	local value = base[key]
	if value ~= nil then return value end
	value = frFR[key]
	if value ~= nil then return value end
	return key
end })
```

Un test de non-régression vérifie désormais qu'une clé absente renvoie son propre nom, et 50 clés absentes d'affilée.

### Bouton de minicarte mal centré et trop gros

Le liseré était ancré en `TOPLEFT` du bouton, en 52×52, pour une zone cliquable de 33×33 : le centre du chrome se retrouvait décalé d'environ 10 px vers le bas-droite, et le bouton paraissait plus gros qu'il n'était.

| Élément | Avant | v1.1.1 |
|---|---|---|
| Zone cliquable | 33×33 | **28×28** |
| Icône | 18×18 | **15×15** |
| Liseré Classic | 52×52 en `TOPLEFT` | **38×38 centré** |
| Atlas Forever | 20×20 | 32×32 centré |

---

## Corrections v1.1.2

### `Stats.lua:66: bad argument #2 (base out of range)`

En Lua, **une fonction en dernier argument déploie tous ses retours**. Donc :

```lua
-- cassé : Call() renvoie 4 valeurs, tonumber() reçoit la 2e comme « base »
snapshot.ap = tonumber(apEffective) or tonumber(Call(UnitAttackPower, "player"))
```

`UnitAttackPower` renvoie `base, posBuff, negBuff, effective` — le `posBuff` (souvent `0`) devenait l'argument `base` de `tonumber`, qui exige **2 à 36**.

- Ça ne se déclenchait que si le 4ᵉ retour était nil (mon mock le fournissait, ton client non) : les tests passaient, le jeu plantait.
- Même piège sur `UnitAttackSpeed`, qui renvoie `main, off`.

```lua
-- corrigé : on passe par des variables locales
local speedMain = Call(UnitAttackSpeed, "player")
snapshot.speed = tonumber(speedMain) or 0

local apBase, _, _, apEffective = Call(UnitAttackPower, "player")
snapshot.ap = tonumber(apEffective) or tonumber(apBase) or 0
```

Le mock reproduit maintenant les **vrais** nombres de retours, avec un test dédié où le 4ᵉ retour est nil — c'est ce cas qui plantait.

### Bouton de minicarte

| Élément | v1.1.1 | v1.1.2 |
|---|---|---|
| Rayon sur l'anneau | 80 | **76** |
| Zone cliquable | 28×28 | **26×26** |
| Icône | 15×15 | **14×14** |
| Liseré | 38×38 | **32×32** |
| Angle par défaut | 200° | **225°** (bas-gauche, zone libre) |

Nouvelle ligne dans les réglages : **« Position du bouton de minicarte »** — chaque clic fait tourner le bouton de 45° (225 → 270 → 315 → 0 → 45…). Plus besoin de le glisser pour trouver la bonne place.

---

## Commandes

Trois préfixes équivalents : **`/r2q`**, `/sd`, `/sacdepart`. `/r2q help` (ou `aide`, `?`) affiche l'aide classée ; une commande inconnue renvoie vers elle en une ligne.

```
Ouvrir
   /r2q                 lance le check maintenant
   /r2q options         les réglages (aussi : config)
   /r2q stats           tes stats principales
   /r2q stuff           écarts de stats dans le chat
   /r2q move [stop]     placer les cadres
Zones sûres
   /r2q safe            marque le village actuel comme sûr
   /r2q unsafe          retire le village ou la capitale actuels
   /r2q safe list       lieux appris
   /r2q safe reset      efface les lieux appris
Modules et contrôles
   /r2q on|off          active ou coupe l'addon
   /r2q modules         état des 3 modules
   /r2q module <depart|stuff|portrait> on|off
   /r2q checks          les 13 contrôles du check avant le départ
   /r2q check <id> on|off
Réglages rapides
   /r2q popup on|off    fenêtre ou résumé dans le chat
   /r2q toast on|off    résumé de stuff
   /r2q portrait on|off stats du portrait
   /r2q minimap on|off  bouton de minicarte
   /r2q seuil <n>       emplacements libres minimum
   /r2q buffs · buff <n> buffs suivis
Divers
   /r2q compo           composants de métier manquants
   /r2q resetpos        positions des cadres par défaut
   /r2q reset           remet tous les réglages à zéro
   /r2q diag            diagnostic (à joindre à un rapport de bug)
```

Compatibilité : `/r2q module vivres off` (ancienne forme, qui visait un contrôle) fonctionne toujours.



---

## Fichiers

| Fichier | Lignes | Rôle |
|---|---|---|
| `Bootstrap.lua` | 65 |  |
| `Locales.lua` | 431 | frFR + enUS |
| `Compat.lua` | 92 | détection des capacités du client |
| `Theme.lua` | 326 | direction artistique Blizzard |
| `Core.lua` | 790 | détection de zone, score pondéré, modules, positions, commandes |
| `Buffs.lua` | 137 | buffs appris depuis les auras |
| `Reagents.lua` | 273 | recettes suivies / recette sélectionnée (Classic) |
| `Equip.lua` | 268 | panneau d'équipement |
| `Stats.lua` | 559 | résumé de changement de stuff + stats du portrait |
| `Minimap.lua` | 195 | bouton rond autour de la minicarte |
| `Checks.lua` | 306 | les 9 modules |
| `Options.lua` | 244 | réglages + interrupteurs de modules |
| `UI.lua` | 241 | fenêtre de diagnostic |
| **Total Lua** | **3927** | |

---

## Tests

```
python3 tests/run_tests.py     →  720 réussis, 0 échoués
```

Lua 5.1 (version du client), client WoW simulé. Couvre notamment : apprentissage par indices (sous-zone, capitale par deux quartiers, purge de l'ancien schéma), délai de sortie / vol / mort, nouveaux checks et automatismes du marchand, chaîne de cartes parentes, anti-spam, filtrage des procs, **valeurs secrètes**, comptages sacs/vivres/potions/durabilité/quêtes, score pondéré et bilans, fenêtre de diagnostic (icônes, barres, bandeau), panneau d'équipement (17 lignes, moyenne, rareté, pièces faibles), comparaison au survol (amélioration, régressif, vide, anneaux), **les deux voies de hook tooltip**, bouton sans template Blizzard, et toutes les commandes.

---

## Ce qui n'est pas vérifié en jeu

| Point | Risque | Mitigation |
|---|---|---|
| Forme de retour de `C_Item.GetItemStatDelta` | **moyen** | `pcall` + test de type, repli « Pas de comparaison possible », `/sd diag` |
| `itemEquipLoc` → emplacement | moyen | table de correspondance, emplacement vide si inconnu |
| Voie de hook tooltip | moyen | deux voies + repli, testées |
| Chemins d'icônes de module | faible (cosmétique) | icône « ? » si absente, aucune erreur |
| Contrat des champs d'aura | moyen | repli `UnitAura`, valeurs secrètes = « inconnu » |
| `GetCraftableCount` hors fenêtre de métier | moyen | dégrade en « aucune recette suivie » |
| Granularité des `mapID` | moyen | `/sd diag` l'affiche |

**Au lancement :** `/sd diag`, puis `/sd safe list` après quelques minutes de jeu pour voir les villages appris.

---

## Limites connues

- Un addon **ne peut pas agir** (manger, réparer, vendre) : il signale.
- Composants comptés **dans les sacs uniquement**.
- Le nom d'un objet très long peut être coupé dans le bandeau de la carte.
- TOC `16001` = build `1.60.1`.
