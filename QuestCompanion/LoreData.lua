-- LoreData.lua -- histoire des lieux racontée par le compagnon (QuestCompanion 2.13.0)
--
-- FICHIER GÉNÉRÉ par tools/gen_lore.py depuis data/forever/lore/lore.json, ne
-- pas éditer à la main.
-- Textes : Warcraft Wiki (https://warcraft.wiki.gg), sous licence CC BY-SA 4.0
--   (https://creativecommons.org/licenses/by-sa/4.0/). Choisis et traduits en
--   français par le projet Spoken de Rusty Key (https://github.com/rusty-key/spoken-wow,
--   addons/Spoken_Places/Data, commit 4ccae964bb4e04f40e82417efc2925cf6e147b90) ; ici réduits à une phrase
--   (coupée au besoin). Ces textes restent sous CC BY-SA 4.0 (pas sous la
--   GPL-3.0 du reste de l'addon) : voir NOTICE.md. Source de chaque ligne : la
--   page du wiki en dernier champ (https://warcraft.wiki.gg/wiki/<page>).
-- Lore text from Warcraft Wiki, CC BY-SA 4.0, via Spoken by Rusty Key (MIT code).
local ADDON, ns = ...
if ns.blocked then return end

-- Une ligne par lieu, champs séparés par une tabulation :
--   Z  uiMapID  texte  page
--   S  uiMapID  noms du client (« | » ; anglais : clé normalisée)  texte  page
-- Seule la langue du client est gardée (l'autre chaîne est libérée) ;
-- CompanionLore.lua y cherche la ligne voulue (zone : à l'arrivée ; sous-zones :
-- une petite liste par zone, refaite au changement de zone).
local FR = [[

Z	1411	Durotar est une terre rouge et crevassée, faite d'escarpements et de canyons, sèche et brûlante, pauvre en eau comme en verdure.	Durotar_(Classic)
Z	1412	Pendant des centaines d'années, les taurens n'eurent aucune terre à eux, pourchassés à travers Kalimdor par des pillards centaures qui dispersèrent leurs tribus en campements errants.	Mulgore_(Classic)
Z	1413	La poussière d'ici n'a pas toujours été poussière.	Barrens_(Classic)
Z	1416	La pluie ne cesse jamais tout à fait de tomber sur ces sommets, et le ciel au-dessus d'eux est toujours gris.	Alterac_Mountains_(Classic)
Z	1417	Le roi Thoradin vint dans cette contrée aride parce qu'un rêve lui avait annoncé que son peuple y prospérerait, et il y éleva Strom, la première capitale d'un Arathor unifié.	Arathi_Highlands_(Classic)
Z	1418	Les Terres ingrates sont un désert crevassé de terre sèche, de rochers épars et de canyons sinueux, enserré de montagnes de toutes parts.	Badlands_(Classic)
Z	1419	Les Terres foudroyées portent bien leur nom. L'argile rouge qu'on y foule était jadis une terre fauve, qui faisait partie d'un sombre marécage nommé le Noir marécage, avant que la Horde…	Blasted_Lands_(Classic)
Z	1420	Le ciel des clairières de Tirisfal est d'un vert maladif depuis des années, et les arbres s'accrochent au peu de vie que la peste leur a laissé.	Tirisfal_Glades_(Classic)
Z	1421	La forêt des Pins argentés, ou simplement les Pins argentés, est un bois vaste et ancien qui longe la côte ouest escarpée de Lordaeron.	Silverpine_Forest_(Classic)
Z	1422	C'étaient autrefois les plus belles terres agricoles du nord de Lordaeron, boisées et verdoyantes, qui remplissaient les greniers du royaume depuis Andorhal et étaient gouvernées depuis le…	Western_Plaguelands_(Classic)
Z	1423	Cette terre était autrefois cultivée : les villages de la Sylve de l'Est s'y dispersaient autour de Stratholme, deuxième cité de Lordaeron. Il n'en reste rien.	Eastern_Plaguelands_(Classic)
Z	1424	Le sol d'Hillsbrad est riche et ses collines sont vertes, et les voyageurs disent que c'est à cela que ressemblait tout Lordaeron avant l'arrivée de la peste.	Hillsbrad_Foothills_(Classic)
Z	1425	Après la guerre des Trois clans, les nains Marteau-hardi abandonnèrent leurs tunnels de Grim Batol et vinrent vers le nord, bâtissant leurs demeures à l'air libre, au Nid-de-l'Aigle.	Hinterlands_(Classic)
Z	1426	La neige recouvre profondément Dun Morogh, enclavé de toutes parts par les montagnes de Khaz Modan, et ses cols sont sans cesse surveillés par les troupes naines.	Dun_Morogh_(Classic)
Z	1427	C'était autrefois une terre verdoyante, qui faisait partie des Carmines, jusqu'à ce que le sol lui-même soit éventré il y a plus de deux cent trente ans.	Searing_Gorge_(Classic)
Z	1428	Le ciel des Steppes ardentes ne perd jamais sa teinte rouge, éclairé par les éruptions sporadiques du mont Blackrock, et le sol ne refroidit jamais.	Burning_Steppes_(Classic)
Z	1429	Lorsque les orcs vinrent pendant la première guerre, des milliers d'entre eux traversèrent Elwynn pour encercler Stormwind, la coupant de tout sauf de la mer.	Elwynn_Forest_(Classic)
Z	1431	Un manteau de nuit surnaturelle recouvre le bois de la Pénombre, et il ne s'est jamais levé.	Duskwood_(Classic)
Z	1432	Les eaux du Loch Modan reposent dans un écrin de pierre grise, retenues par le barrage de Formepierre, un ouvrage d'ingénierie naine qu'aucune autre construction d'Azeroth n'a jamais égalé.	Loch_Modan_(Classic)
Z	1433	Les Carmines s'étendent à l'est de la forêt d'Elwynn, au nord-est du bois de la Pénombre et au sud des Steppes ardentes.	Redridge_Mountains_(Classic)
Z	1434	La vallée de Strangleronce est une vaste jungle au sud du bois de la Pénombre.	Stranglethorn_Vale_(Classic)
Z	1435	Sous l'eau noire du marais repose un temple plus ancien que le chagrin qui a donné son nom à ce lieu.	Swamp_of_Sorrows_(Classic)
Z	1436	Le vent souffle désormais sans obstacle sur les champs de la Marche de l'Ouest, car plus rien de haut ne s'y dresse pour l'arrêter.	Westfall_(Classic)
Z	1437	Un marécage gris et froid s'étend en contrebas du barrage, la brume couvrant ses rivières et ses étangs, cerné de montagnes sur trois côtés et ouvert sur la mer à l'ouest.	Wetlands_(Classic)
Z	1438	Lorsque Malfurion Hurlorage disparut dans le Rêve d'émeraude, l'archidruide Fandral Staghelm prit sa place à la tête du Cercle cénarien et convainquit le Cercle des Anciens que le temps…	Teldrassil_(Classic)
Z	1439	Une brume grise s'étend le plus souvent le long de cette côte, et les elfes de la nuit y voient depuis longtemps un avertissement.	Darkshore_(Classic)
Z	1440	Orneval est une forêt antique, pleine de vieux arbres et de vieille magie, que l'on n'a jamais cessé de se disputer.	Ashenvale_(Classic)
Z	1441	Le canyon s'enfonce, profond et aride, son fond perdu parmi d'immenses plateaux, jusqu'à ce qu'il s'ouvre à l'est sur les Salines, une grande étendue de sel sous un vaste ciel.	Thousand_Needles_(Classic)
Z	1442	Le pic des Serres-Rocheuses a toujours appartenu aux esprits avant d'appartenir à aucun peuple.	Stonetalon_Mountains_(Classic)
Z	1443	Theradras, fille de Therazane la Mère-pierre, sommeillait jadis sous une prairie fertile.	Desolace_(Classic)
Z	1444	Féralas surgit, étrange, au milieu de ses voisines, une forêt tropicale d'arbres antiques là où les déserts alentour ne promettent que la poussière.	Feralas_(Classic)
Z	1445	Ici, les moustiques ne s'arrêtent jamais, et la boue non plus.	Dustwallow_Marsh_(Classic)
Z	1446	Le sable emplit le lieu où se dressait autrefois une jungle. Avant que le monde ne soit brisé, Tanaris était verdoyante, revendiquée comme territoire par l'empire Gurubashi.	Tanaris_(Classic)
Z	1447	L'automne règne sur Azshara depuis dix mille ans, ses arbres flamboyant d'orange et de rouge au-dessus de falaises qui plongent dans le corail où repose encore une cité.	Azshara_(Classic)
Z	1448	Les arbres de Gangrebois ne poussent pas tant qu'ils ne pourrissent.	Felwood_(Classic)
Z	1449	Le cratère d'Un'Goro s'étend, enclavé entre trois déserts, telle une plaie verdoyante creusée dans le sud de Kalimdor, là où le monde oublie d'être stérile.	Un'Goro_Crater_(Classic)
Z	1450	Reflet-de-Lune repose dans un cercle de montagnes, vallée cachée où la forêt n'a jamais connu la corruption.	Moonglade
Z	1451	Le désert s'étend à l'extrémité sud-ouest de Kalimdor, étendue de roches brisées et de sable que l'on atteint par la large piste venant d'Un'Goro.	Silithus_(Classic)
Z	1452	La neige s'étend, intacte, sur Berceau-de-l'Hiver, dont la beauté demeure inaltérée même là où les démons ont envahi les confins du sud.	Winterspring_(Classic)
Z	1453	Stormwind se releva en pierre blanche après que la Horde orque l'eut incendiée, rebâtie par la guilde des Maçons sous le règne du jeune roi Varian.	Stormwind_City
Z	1454	Orgrimmar s'éleva dans les années qui suivirent le mont Hyjal, lorsque le chef de guerre Thrall mena son peuple jusqu'à une côte désolée de Kalimdor.	Orgrimmar
Z	1455	Ironforge est la capitale des nains, creusée dans les profondeurs de la montagne d'Ironforge, au nord de Dun Morogh, terre ancestrale des nains et l'une des plus anciennes cités d'Azeroth.	Ironforge
Z	1456	Thunder Bluff se dresse sur quatre plateaux balayés par les vents au-dessus des prairies de Mulgore, accessible seulement par des ascenseurs de corde et de bois de facture taurène, ou par…	Thunder_Bluff
Z	1457	Les elfes de la nuit bâtirent Darnassus après la troisième guerre, lorsque leur longue immortalité les eut abandonnés.	Darnassus
Z	1458	Bien avant que les Réprouvés ne se l'approprient, l'Undercity avait un nom et une fonction.	Undercity
S	1411	Baie de Bladefist	Les eaux à l'est de Durotar portent le nom de Kargath Bladefist, en hommage à l'ancien chef du clan de la Main brisée.	Bladefist_Bay
S	1411	Convent de la Lame ardente	Les montagnes qui ferment le nord de la vallée des Épreuves ne recelaient autrefois rien de pire que la pierre et l'ombre.	Burning_Blade_Coven
S	1411	L'Antre	Dans la vallée des Épreuves, les jeunes orcs établissent leur premier camp dans une grotte appelée l'Antre.	The_Den
S	1411	Combe des Kolkar	La combe des Kolkar est une gorge escarpée du sud de Durotar, qui doit son nom aux centaures Kolkar qui la tiennent.	Kolkar_Crag
S	1411	Tranchecolline	Tranchecolline se dresse là où se rejoignent les routes de Durotar.	Razor_Hill
S	1411	Vallée des épreuves	La vallée des Épreuves s'étend, enclavée, au sud de Durotar, une cuvette de terre brûlée où chaque jeune orc commence la vie que la Horde a tracée pour lui.	Valley_of_Trials
S	1412	Site de fouilles de Bael'Dun	L'expédition de Bael'dun creusa sa carrière dans la lisière ouest de Mulgore, enfonçant ses pioches dans le flanc de la montagne.	Bael'dun_Digsite
S	1412	Sabot-de-Sang|Village Bloodhoof	Le village Bloodhoof se trouve au bord des eaux du lac Taureau-de-pierre, dans les plaines de Mulgore, et porte le nom de la tribu qui y vit.	Bloodhoof_Village
S	1412	Ravin de Roncelame	Le ravin de Roncelame entaille la lisière nord-est de la mesa de Nuage rouge ; c'est le repaire des hurans Dos-hirsute.	Brambleblade_Ravine
S	1412	camp narache	Le camp Narache se trouve à la lisière nord de la mesa de Nuage rouge, un petit cercle de tentes appartenant à la tribu Hawkwind, au sud de Mulgore.	Camp_Narache
S	1412	Mine de la KapitalRisk	La mine s'enfonce profondément dans les falaises de l'est de Mulgore, avec trois accès : l'entrée principale à pied, une paroi rocheuse et un petit camp de bûcherons au-delà.	Venture_Co._Mine
S	1412	Puits Sabot-d’Hiver|Puits Winterhoof	Le puits Winterhoof se trouve en bordure des plaines vallonnées, au sud de Mulgore.	Winterhoof_Water_Well
S	1413	camp taurajo	Le camp Taurajo se trouve dans les Tarides, près du col de montagne qui mène à Mulgore.	Camp_Taurajo
S	1413	La Croisée	La Croisée se trouve là où les routes se rejoignent : la piste nord-sud qui descend de la route de l'or, et la longue voie est-ouest qui va de Ratchet jusqu'aux Serres-Rocheuses.	Crossroads
S	1413	Oasis luxuriante	L'eau s'accumule là où la Grande Fissure s'abaisse, et les bêtes sauvages descendent à travers les arbres pour s'y abreuver.	Lushwater_Oasis
S	1413	ratchet	Ratchet se trouve sur la côte est des Tarides, une ville portuaire gobeline qui commerce activement avec Baie-du-Butin et le baron Revilgaz, de l'autre côté de la mer.	Ratchet
S	1413	L'oasis stagnante	L'oasis stagnante est une étendue d'eau verte et immobile entre la Côte des marchands et la route de l'or.	Stagnant_Oasis
S	1413	Cavernes des lamentations	Les cavernes des Lamentations tiennent leur nom du son même des lieux : la vapeur qui jaillit des fissures de la roche, portée à travers les ténèbres en longs cris lugubres.	Wailing_Caverns
S	1416	dalaran	Dalaran s'éleva comme une cité de mages, fondée après les guerres des Trolls par les sorciers de l'empire d'Arathor, et devint une nation à part entière.	Dalaran
S	1416	Promontoire de Gavin	Le promontoire de Gavin est la dernière des quatre collines d'Hillsbrad, et la mieux gardée.	Gavin's_Naze
S	1416	Caverne stérile	Dans les montagnes d'Alterac, une caverne abrite des yétis des montagnes, et l'on trouve souvent Skhowl juste devant son entrée.	Growless_Cave
S	1416	L'Avancée	L'Avancée est l'un des doigts de terre qui s'étendent à travers Hillsbrad.	Headland
S	1416	Lac Lordamere	Le lac Lordamere s'étend à l'ombre des royaumes qui peuplaient jadis ses rives.	Lordamere_Lake
S	1416	Manoir de Ravenholdt	Le manoir de Ravenholdt se tient à l'écart du monde, et c'est voulu.	Ravenholdt_Manor
S	1417	Roche’gor	Au nord du donjon de Stromgarde, la colline de Boulder'gor s'élève, accidentée et rugueuse.	Boulder'gor
S	1417	Ferme de Go'Shek	La ferme de Go'Shek se trouve à l'est des Hautes-terres d'Arathi, près du village Witherbark.	Go'Shek_Farm
S	1417	Trépas-d'Orgrim	Le sol de Trépas-d'Orgrim se souvient de ce qu'il fut jadis.	Hammerfall
S	1417	Manoir de Nordclos	Après la chute de Stromgarde, le manoir de Nordclos passa aux mains du Syndicat, qui en fit un avant-poste dans les Hautes-terres d'Arathi.	Northfold_Manor
S	1417	Refuge de l'Ornière	Lorsque la capitale de Stromgarde tomba en ruine pendant la troisième guerre, la plupart de ses habitants s'enfuirent vers le sud, dans les Hautes-terres d'Arathi.	Refuge_Pointe
S	1417	Donjon de Stromgarde	Stromgarde était jadis Strom, berceau du premier royaume humain, capitale de l'empire d'Arathor.	Stromgarde_Keep
S	1418	camp boff	Le camp Boff est le camp sud-est des ogres Dustbelcher, l'un des quatre avec les camps Cagg, Kosh et Wurg. Peu d'ogres le gardent.	Camp_Boff
S	1418	camp wurg	Le camp Wurg est l'un des foyers des ogres Dustbelcher, parents des ogres des camps Cagg, Boff et Kosh.	Camp_Wurg
S	1418	Goulet de la Bourrasque	Les vents récurent le goulet de la Bourrasque jusqu'à ce que rien de tendre n'y reste debout, seulement la pierre et les os secs du ravin.	Dustwind_Gulch
S	1418	kargath	Kargath se dresse seule en Khaz Modan, l'unique avant-poste que la Horde tienne dans cette contrée, et porte le nom de Kargath Bladefist, chef du clan de la Main brisée.	Kargath
S	1418	Vallée des mirages	La vallée des Mirages s'étend à l'est de la grotte de Crache-poussière, dans les Terres ingrates.	Mirage_Flats
S	1418	uldaman	Au plus profond des montagnes de Khaz Modan se trouve Uldaman, une vaste et antique chambre forte élevée par les gardiens titans en des âges depuis longtemps révolus.	Uldaman
S	1419	La Porte des ténèbres	La création de la Porte fut une trahison dès le premier coup. Gul'dan et le mage humain Medivh, ce dernier possédé par le titan noir Sargeras, ouvrirent ensemble la faille.	Dark_Portal
S	1419	Armurerie de la garnison	Dans le sol meurtri des Terres foudroyées, des mineurs de l'Alliance exploitent l'armurerie de la garnison, arrachant des minerais à la terre pour le Rempart-du-Néant.	Garrison_Armory
S	1419	Rempart-du-Néant	Le Rempart-du-Néant se dresse sur un haut promontoire au-dessus de la seule route qui mène aux Terres foudroyées, ses murs élevés pour surveiller une cicatrice du monde que nul ne voulait…	Nethergarde_Keep
S	1419	Cime du Souilleur	La cime du Souilleur se dresse au milieu des Terres foudroyées, une étendue escarpée de montagne brisée.	Rise_of_the_Defiler
S	1419	Anneaux du serpent	Les Anneaux du serpent sont un réseau de grottes sinueuses à l'est des Terres foudroyées, dont l'entrée est marquée par des structures orques calcinées, vestiges de la deuxième guerre.	Serpent's_Coil
S	1419	La Balafre impure	La Balafre impure faisait jadis partie du Noir Marécage, avant que la corruption de la Porte des ténèbres ne s'y répande et ne laisse le sol sec, sans arbres et rouge comme le sang.	Tainted_Scar
S	1420	brill	Brill était jadis une ville ordinaire du royaume de Lordaeron, tenue par la famille Barov, où les Agamand possédaient aussi leur propre manoir.	Brill
S	1420	Le Glas	Le Glas se niche dans une vallée étroite et bien gardée, et c'est ici que les Réprouvés fraîchement relevés ouvrent pour la première fois les yeux sur le monde qui leur a été donné.	Deathknell
S	1420	Taverne des Pendus	La taverne des Pendus se trouve à Brill, et son nom est l'écho sinistre de la ville qu'elle sert.	Gallows'_End_Tavern
S	1420	Grottes des Tisse-nuit	Les grottes des Tisse-nuit forment une petite vallée traversée par une vieille mine d'or, l'une et l'autre revendiquées par les araignées.	Night_Web's_Hollow
S	1420	Ruines de Lordaeron	Au-dessus de la cité enfouie, le palais de Lordaeron se dresse toujours, ses salles ouvertes au ciel, ses jardins en ruine.	Ruins_of_Lordaeron
S	1420	Monastère écarlate	Sous la Croisade, le vieux monastère devint caserne et prison.	Scarlet_Monastery
S	1421	Moulin-de-l'Ambre	Moulin-de-l'Ambre n'était jadis qu'un bourg sans importance, où l'on débitait du bois au sud-ouest du lac Lordamere, dans la forêt des Pins argentés.	Ambermill
S	1421	Mine du gouffre d'Elem	La mine du gouffre d'Elem se trouve dans la forêt des Pins argentés.	Deep_Elem_Mine
S	1421	Lac Lordamere	Le lac Lordamere s'étend à l'ombre des royaumes qui peuplaient jadis ses rives.	Lordamere_Lake
S	1421	Le Sépulcre	Le Sépulcre domine la côte de Lordaeron, dans les collines de l'ouest de la forêt des Pins argentés, là où une route traversait jadis un simple cimetière, dont les cryptes ne marquaient…	Sepulcher
S	1421	Donjon d'Ombrecroc	Le donjon d'Ombrecroc se dresse sur un haut promontoire au-dessus de Bois-du-Bûcher.	Shadowfang_Keep
S	1421	La côte sud	La Côte sud longe le littoral sud-ouest de la forêt des Pins argentés, là où la terre rencontre la Grande mer.	South_Tide's_Run
S	1422	caer darrow	Sur l'île du lac Darrowmere se dressait une forteresse élevée jadis par des mains humaines, qui abritait une antique pierre runique des hauts-elfes.	Caer_Darrow
S	1422	Camp du Noroît	Le camp du Noroît se trouve à la porte sud des Maleterres de l'ouest, là où les montagnes d'Alterac cèdent la place à une terre empoisonnée.	Chillwind_Camp
S	1422	Larmes de Dalson	Le verger des Dalson portait jadis des fruits pour la famille qui lui avait donné son nom.	Dalson's_Tears
S	1422	scholomance	Sur une hauteur dominant la cité abandonnée de Caer Darrow se dresse le manoir qui fut jadis le siège de la maison Barov, une famille dont l'influence s'étendait de Caer Darrow à Brill, à…	Scholomance
S	1422	La Thondroril	La Thondroril sépare les Maleterres de l'ouest et de l'est.	Thondroril_River
S	1422	Le Repaire putride	Le Repaire putride était jadis une terre agricole, cultivée pour nourrir les vivants. Cette vocation a disparu.	Writhing_Haunt
S	1423	Scierie de Browman	Stephen Browman débitait jadis du bois à la scierie au nord de la chapelle de l'Espoir de Lumière.	Browman_Mill
S	1423	Chapelle de l'Espoir de Lumière	Au pied des montagnes à l'est des Maleterres se dresse une chapelle bien plus ancienne que la ruine qui l'entoure, l'un des lieux saints les plus anciens et les plus vénérés que l'Église…	Light's_Hope_Chapel
S	1423	stratholme	La ruine de Stratholme commença par du grain. Des cargaisons venues d'Andorhal, secrètement contaminées par le culte des Damnés, furent transformées en pain et mangées par une population…	Stratholme
S	1423	Val-Terreur	Val-Terreur se trouve à la lisière de Pestebois, ses rues vidées et livrées au Fléau et aux animaux pestiférés.	Terrordale
S	1423	La Thondroril	La Thondroril sépare les Maleterres de l'ouest et de l'est.	Thondroril_River
S	1423	zulmashar	Zul'Mashar était jadis la capitale de la tribu Mossflayer, des trolls des forêts du nord-est des Maleterres de l'est.	Zul'Mashar
S	1424	Colline de Darrow	La colline de Darrow se trouve au nord des contreforts d'Hillsbrad, au pied de l'Avancée.	Darrow_Hill
S	1424	dun garok	Dun Garok se dresse dans les collines des contreforts d'Hillsbrad, un fort nain sous le commandement du capitaine Ironhill.	Dun_Garok
S	1424	Rivage oriental	Le Rivage oriental longe la côte sud-est des contreforts d'Hillsbrad, et son pendant s'étend plus à l'ouest sur ce même littoral.	Eastern_Strand
S	1424	Ile de la purification	Une spirale de pierre s'élève au sud du rivage d'Hillsbrad, couronnée d'un cimetière et des restes brisés d'une tour d'observation.	Purgation_Isle
S	1424	Moulin-de-Tarren	Moulin-de-Tarren était jadis une simple ville de Lordaeron, au milieu des prairies au pied des montagnes d'Alterac.	Tarren_Mill
S	1424	Rivage occidental	Le Rivage occidental se trouve sur la côte sud-ouest des contreforts d'Hillsbrad.	Western_Strand
S	1425	Nid-de-l'Aigle	Les nains Marteau-hardi n'ont pas choisi les Hinterlands en premier.	Aerie_Peak
S	1425	Escarpement de Bogen	L'escarpement de Bogen est une grotte au sud-ouest des Hinterlands.	Bogen's_Ledge
S	1425	Taudis de Featherbeard	Près du Nid-de-l'Aigle se dresse une petite maison qui appartenait jadis à un certain Featherbeard. Elle n'abrite ni garnison ni trésor.	Featherbeard's_Hovel
S	1425	Village des Revantusk	Le village des Revantusk se dresse sur la côte des Hinterlands, dernier foyer d'une tribu de trolls des forêts qui choisit la loyauté plutôt que la survie.	Revantusk_Village
S	1425	Lac Valorwind|Lac Vent-vaillant	Le lac Vent-vaillant s'étend, paisible, au nord-est de Shadra'Alor, ses eaux en apparence sans rien de remarquable.	Valorwind_Lake
S	1425	Donjon des Wildhammer	Le donjon des Wildhammer s'élève au cœur du Nid-de-l'Aigle ; c'est le siège des nains Marteau-hardi qui le tiennent. Ses salles sont ouvertes aux voyageurs qui atteignent le sommet.	Wildhammer_Keep
S	1426	Courbenclume	Dans la vallée des Frigères se dresse Anvilmar, une salle bâtie autour d'une grande forge.	Anvilmar
S	1426	Vallée des Frigères	La neige recouvre épaisse la vallée des Frigères, enclavée de toutes parts, dont la seule issue est l'étroit tunnel de la passe des Frigères, au nord-est.	Coldridge_Valley
S	1426	Repaire des Frostmane	Le repaire des Frostmane se dresse à la lisière ouest des montagnes glacées de Dun Morogh, au sud de Gnomeregan, un ensemble de bâtiments épars reliés à un réseau de grottes creusé dans le…	Frostmane_Hold
S	1426	gnomeregan	Gnomeregan est la capitale souterraine du royaume gnome du même nom, témoignage de fer forgé du génie, de l'ambition et de l'ingéniosité des gnomes.	Gnomeregan
S	1426	kharanos	Kharanos se niche parmi les sommets de Dun Morogh, ses rues cernées de terres sauvages et hivernales qui ne laissent jamais ses habitants s'amollir.	Kharanos
S	1426	Distillerie Thunderbrew	La distillerie Thunderbrew se dresse à Kharanos, son nom connu bien au-delà de la ville naine pour la qualité de sa bière.	Thunderbrew_Distillery
S	1427	Caverne de Noircharbon	La caverne de Noircharbon est scellée près du mont Blackrock, sa pierre sombre silencieuse et coupée du monde extérieur.	Blackchar_Cave
S	1427	Mont Blackrock|Mont Rochenoire	Le mont Blackrock n'est pas né d'un feu ordinaire.	Blackrock_Mountain
S	1427	Crête de Guet-du-feu	La crête de Guet-du-feu est le principal camp des nains Sombrefer dans la gorge des Vents brûlants, dominant la grande excavation du Chaudron.	Firewatch_Ridge
S	1427	Site de fouilles de Crasseboue|Site de fouilles de Grimesilt	Des nains d'Ironforge creusaient jadis ici, jusqu'à ce que les nains Sombrefer viennent s'emparer du site. Il reste aux mains des Sombrefer.	Grimesilt_Dig_Site
S	1427	La Mer de braises	La Mer de braises s'étend, plate et dégagée, dans le sud de la gorge des Vents brûlants, juste au nord du mont Blackrock. Rien n'y pousse.	Sea_of_Cinders
S	1427	Halte du Thorium	Dans le nord calciné de la gorge des Vents brûlants se dresse la Halte du Thorium, une petite ville neutre tenue par la Confrérie du Thorium, peuplée surtout de nains Sombrefer fidèles à…	Thorium_Point
S	1428	Mont Blackrock|Mont Rochenoire	Le mont Blackrock n'est pas né d'un feu ordinaire.	Blackrock_Mountain
S	1428	Défilé des Blackrock|Défilé des Rochenoires	Le défilé des Blackrock est le seuil entre deux mondes. D'un côté s'étendent les Carmines, vertes et paisibles.	Blackrock_Pass
S	1428	Draco’dar	Les collines de Draco'dar sont noircies et calcinées, livrées entièrement au vol draconique noir.	Draco'dar
S	1428	Corniche des flammes	La Corniche des flammes se dresse sur un affleurement dénudé des Steppes ardentes, accessible seulement par un pont grossier.	Flame_Crest
S	1428	Veille de Morgan	La Veille de Morgan gît en ruine dans le sud-est des Steppes ardentes, ses maisons réduites en cendres et sa tour de mage effondrée en décombres.	Morgan's_Vigil
S	1428	Ruines de Thaurissan	Jadis, ces étendues de cendres des Steppes ardentes étaient verdoyantes, et la cité qui s'y dressait portait le nom de son fondateur : la cité de Thaurissan, capitale du clan Sombrefer…	Ruins_of_Thaurissan
S	1429	Mine de la Crête aux échos|Mine de la crête aux échos	Les tunnels de la Mine de la crête aux échos s'étendent dans le nord-ouest de la vallée de Northshire.	Echo_Ridge_Mine
S	1429	Comté-de-l’Or	Goldshire se trouve au cœur de la forêt d'Elwynn, ses champs en vue de Northshire, ses routes menant vers Stormwind, la Marche de l'Ouest et les Carmines.	Goldshire
S	1429	Le Débarcadère de Jerod|Le débarcadère de Jerod	Le Débarcadère de Jerod est un ponton sur la rive de la forêt d'Elwynn, au bord de la rivière Nazfériti.	Jerod's_Landing
S	1429	Abbaye de Comté-du-Nord|Abbaye de Northshire	L'abbaye de Northshire repose dans la vallée qui porte son nom, sur les contreforts de la forêt d'Elwynn, son grand hall, sa salle d'armes et son aile de bibliothèque se dressant là où les…	Northshire_Abbey
S	1429	Vallée de Comté-du-Nord|Vallée de Northshire	La vallée de Northshire est fermée de tous côtés sauf un, ses montagnes infranchissables, son unique passage vers le sud barré par d'épais murs de pierre et une porte gardée.	Northshire_Valley
S	1429	Vignes de Northshire|Vignoble de Comté-du-Nord	Les vignes s'étendent à l'est de l'abbaye, jadis entretenues pour leur récolte avant que la Confrérie défias ne s'empare de la terre.	Northshire_Vineyards
S	1431	Bosquet de Clairbois	Le Bosquet de Clairbois se trouve juste à l'ouest de Darkshire, ses quelques bâtiments depuis longtemps tombés en ruine.	Brightwood_Grove
S	1431	Sombre-Comté	Darkshire n'a pas toujours porté ce nom. Il s'éleva il y a longtemps sous le nom de Grand Hamlet, un petit bourg forestier qui grandit à mesure que les habitants de Stormwind se…	Darkshire
S	1431	Colline-aux-Corbeaux	Les maisons de Colline-aux-Corbeaux sont vides, dans l'ouest du Bois de la Pénombre, livrées à la pourriture et à l'obscurité.	Raven_Hill
S	1431	Cimetière de Colline-aux-Corbeaux	Le Cimetière de Colline-aux-Corbeaux s'étend au nord du bourg dont il tire son nom, ayant largement dépassé ses anciennes limites depuis que la corruption s'est emparée du Bois de la…	Raven_Hill_Cemetery
S	1431	Destin de Roland	Le Destin de Roland est une mine du sud-est du Bois de la Pénombre, à l'est du Verger pourri.	Roland's_Doom
S	1431	La ferme des Yorgen	La ferme des Yorgen gît abandonnée dans le sud du Bois de la Pénombre, ses champs livrés à la pourriture.	Yorgen_Farmstead
S	1432	dun algaz	Le tunnel de Dun Algaz est plus ancien que la querelle qui divisa les nains.	Dun_Algaz
S	1432	Passage de la porte Nord	Le col traverse les hautes montagnes, descendant de Dun Morogh vers le Loch Modan.	North_Gate_Pass
S	1432	Vallée des Brisepierre	La Vallée des Brisepierre s'enfonce parmi les montagnes du sud-ouest du Loch Modan.	Stonesplinter_Valley
S	1432	Barrage de Formepierre	Le Barrage de Formepierre s'élève à l'est du col de Dun Algaz, le long de la lisière nord du Loch Modan.	Stonewrought_Dam
S	1432	Auberge de la Fortebière	L'Auberge de la Fortebière se trouve à Thelsamar, son âtre rarement froid.	Stoutlager_Inn
S	1432	thelsamar	Thelsamar se trouve sur la rive ouest du Loch Modan, au nord de la Falaise de Vieillegriffe et au nord-est de la Vallée des Brisepierre.	Thelsamar
S	1433	Scierie d'Alther	La scierie au nord-est de Lakeshire est vide, sa roue arrêtée depuis longtemps.	Alther's_Mill
S	1433	Comté-du-Lac	Le Lac placide s'étend, immobile et froid, sous les pics des Carmines, et le bourg sur sa rive a plus d'une fois versé son sang pour cette terre.	Lakeshire
S	1433	Camp des Etripeurs	Les orcs Blackrock tiennent un camp dans le nord-ouest des Carmines, tout près du chemin qui mène aux Steppes ardentes.	Render's_Camp
S	1433	Cavernes de Rethban	Les Cavernes de Rethban s'enfoncent profondément dans le nord-ouest des Carmines.	Rethban_Caverns
S	1433	Donjon de Guet-de-pierre	Le Donjon de Guet-de-pierre appartenait jadis aux humains de Lakeshire, chargé de veiller sur les Carmines.	Stonewatch_Keep
S	1433	Tour d'Ilgalar	La Tour d'Ilgalar s'élève dans l'est des Carmines.	Tower_of_Ilgalar
S	1434	Baie-du-Butin	Baie-du-Butin se niche dans un lagon bleu à la pointe sud de la vallée de Strangleronce, et l'on y entre à pied par les mâchoires blanchies d'un requin géant.	Booty_Bay
S	1434	Campement Grom'gol	Le Campement Grom'gol se dresse, fortifié, sur la côte sud-ouest de Strangleronce, ses palissades élevées contre les trolls de la jungle de la côte, contre les nagas surgissant du ressac…	Grom'gol_Base_Camp
S	1434	Ruines de Zul'Mamwe	Les Ruines de Zul'Mamwe sont cernées de montagnes de tous côtés sauf au nord, au sud du Tertre des ogres Mosh'Ogg.	Ruins_of_Zul'Mamwe
S	1434	La réserve	Dans une grotte au fond de la Base de Kurzen, le colonel Kurzen garde l'équipement de sa guerre.	Stockpile
S	1434	Centre d'opérations de la KapitalRisk	La plate-forme pétrolière de la KapitalRisk s'élève d'un lac de la jungle, centre d'opérations de sa poussée dans les terres sauvages.	Venture_Co._Operations_Center
S	1434	Le Récif infâme	Au large de la côte ouest de la vallée de Strangleronce, près de Grom'gol, la mer se brise, étincelante, sur le corail.	Vile_Reef
S	1435	Caverne d'Itharius|Caverne d’Itharius	Dans le sud-ouest du Marais des Chagrins, une caverne abrite le haut-elfe Itharius.	Itharius's_Cave
S	1435	Bassin des larmes	Le Bassin des larmes s'étend, large et immobile, à la lisière orientale du Marais des Chagrins.	Pool_of_Tears
S	1435	Noirchagrin	Noirchagrin s'étend à l'est du Bassin des larmes, près du Temple englouti.	Sorrowmurk
S	1435	Caverne de Stagalbog	Dans l'est du Stagalbog, au Marais des Chagrins, une grotte s'ouvre dans la fange.	Stagalbog_Cave
S	1435	Pierrêche	Stonard surgit de la fange du Marais des Chagrins, sa grande salle toujours debout là où tant d'autres salles orques sont depuis longtemps tombées.	Stonard
S	1435	Le temple d'Atal'Hakkar	Il y a plus de mille ans, l'empire Gurubashi se déchira dans une guerre civile.	Temple_of_Atal'Hakkar
S	1436	Ferme des Alexston	Les champs de la Ferme des Alexston nourrissaient jadis des familles, avant que la Confrérie défias ne s'empare de la terre.	Alexston_Farmstead
S	1436	Les Mortemines	Sous Ruisselune, les tunnels s'enfoncent profondément, et jadis l'or y coulait à flots.	Deadmines
S	1436	Maison de Demont	Il ne reste guère de la Maison de Demont que des poutres brisées et des champs envahis par les herbes, à l'ouest de Ruisselune.	Demont's_Place
S	1436	La ferme des Jansen	La ferme des Jansen se trouve à la lisière nord de la Marche de l'Ouest, tout près du pont qui mène à la forêt d'Elwynn.	Jansen_Stead
S	1436	Longrivage	La côte de la Marche de l'Ouest s'étend, longue et déserte, l'une des plus vastes plages d'Azeroth.	Longshore
S	1436	Colline des sentinelles	La Colline des sentinelles se dresse sur les hauteurs dominant les terres agricoles de la Marche de l'Ouest, sa tour veillant sur les chaumières, la forge et le moulin bâtis sur la pente…	Sentinel_Hill
S	1437	Taverne de l'Eau-profonde	La Taverne de l'Eau-profonde se trouve au Port de Menethil, sa salle commune bruissant des conversations des marins de passage.	Deepwater_Tavern
S	1437	dun algaz	Le tunnel de Dun Algaz est plus ancien que la querelle qui divisa les nains.	Dun_Algaz
S	1437	grim batol	Grim Batol est une forteresse de montagne située dans l'est des Paluns.	Grim_Batol
S	1437	Baie de Menethil	La baie de Menethil s'étend entre le port et les falaises de Dun Morogh, nichée dans l'anse de la baie de Baradin.	Menethil_Bay
S	1437	Port de Menethil	Le mur est la première chose que l'on remarque, une épaisse muraille de pierre dressée autour d'une ville portuaire assise pour moitié sur la roche, pour moitié sur la mer.	Menethil_Harbor
S	1437	Marais des Poils-moussus	Le Marais des Poils-moussus est une étendue détrempée de l'est des Paluns, dont le sol est parsemé des camps des gnolls Poils-moussus.	Mosshide_Fen
S	1438	aldrassil	Aldrassil s'élève au cœur de Sombrevallon, un arbre devenu assez vaste pour abriter un village dans ses ramures.	Aldrassil
S	1438	La Faille	La Faille se trouve au nord-ouest de Dolanaar, repaire de furbolgs Pins-tordus corrompus menés par Ursal le Mutileur.	Cleft
S	1438	dolanaar	Dolanaar se trouve dans le centre-est de Teldrassil, au sud-ouest de Sombrevallon, ses racines et ses ponts de corde tissés dans le grand arbre lui-même.	Dolanaar
S	1438	Rut'theran	Rut'theran se trouve au pied de Teldrassil, là où l'Arbre-Monde rencontre l'eau, sous Darnassus qui le domine de très haut.	Rut'theran_Village
S	1438	Sombrevallon	Sous les ramures de Teldrassil, niché dans la partie nord-est de l'île, s'étend un vallon qui ne voit jamais tout à fait la pleine lumière du jour.	Shadowglen
S	1438	Grotte de Sombrefil	La Grotte de Sombrefil se trouve dans l'angle nord-ouest de Sombrevallon, dans les racines de Teldrassil.	Shadowthread_Cave
S	1439	Ameth’Aran	Les ruines d'Ameth'Aran s'étendent au sud-est d'Auberdine, en Sombrivage, et quelque chose de la ville y erre encore.	Ameth'Aran
S	1439	auberdine	Auberdine se dresse là où la Fracture brisa la terre, sur une côte qui engloutit les grandes cités de l'ancien empire kaldorei.	Auberdine
S	1439	Le Glaive du Maître	Dans le sud-ouest de Sombrivage gît un crâne colossal, à demi englouti par la terre, dans lequel est encore planté un glaive d'adamantite.	Master's_Glaive
S	1439	La lisière des brumes	La côte appelée la lisière des brumes longe tout Sombrivage, le plus long littoral de la région.	Mist's_Edge
S	1439	Excavations de Remtravel	Le prospecteur Remtravel a donné son nom à ce site de fouilles de Sombrivage.	Remtravel's_Excavation
S	1439	Vallée du Crépuscule|Vallée du crépuscule	Les forêts au sud d'Ameth'Aran, qui s'étendent jusqu'à la frontière d'Orneval, sont appelées la Vallée du Crépuscule.	Twilight_Vale
S	1440	astranaar	Astranaar s'élève sur une île au cœur d'Orneval, la plus grande des colonies d'elfes de la nuit de la région, accessible uniquement par deux ponts qui font franchir l'eau à la route.	Astranaar
S	1440	Profondeurs de Brassenoire	Sous la grève de Zoram, là où l'antique cité de Zoram sombra dans la mer, s'étendent les salles englouties de Lathar'Lazal, jadis un temple d'Elune.	Blackfathom_Deeps
S	1440	Lac Tombeciel	Un petit lac s'étend au sud de l'Avant-poste d'Aile-argent, en Orneval, ses eaux rassemblées autour d'une île solitaire.	Fallen_Sky_Lake
S	1440	Poste de Bois-brisé	Les madriers du Poste de Bois-brisé portent encore les marques des haches qui l'ont bâti, car ce furent Grommash Hurlenfer et son clan Warsong qui élevèrent cet avant-poste lorsque les…	Splintertree_Post
S	1440	xavian	Xavian s'élève là où se dressait jadis un temple des elfes de la nuit, ses pierres aujourd'hui livrées aux satyres.	Xavian
S	1440	Avant-poste de Zoram'gar	L'Avant-poste de Zoram'gar est un port de la Horde sur la grève de Zoram, en Orneval, dont les quais s'avancent dans les eaux en contrebas.	Zoram'gar_Outpost
S	1441	Poste de Librevent	Le Poste de Librevent se dresse au sommet d'une mesa des Mille pointes, hors de portée des centaures qui errent en contrebas.	Freewind_Post
S	1441	Haut-perchoir	Haut-perchoir s'élève au-dessus des Mille pointes, domaine des wyvernes et de leurs nids.	Highperch
S	1441	Camp Rochefer	Le Camp Rochefer se trouve à la lisière des Salines.	Ironstone_Camp
S	1441	Piste des mirages	Un gobelin nommé Pozzik et un gnome nommé Fizzle Brassbolts croyaient chacun que leur peuple comptait les ingénieurs les plus ingénieux, et aucun ne voulait en démordre.	Mirage_Raceway
S	1441	Souilles de Tranchebauge	Au plus profond des ronces des Mille pointes s'étend un dédale d'épines et d'ossements, dont l'entrée aurait été façonnée dans la gueule même d'Agamaggan, une ouverture en arche dans le…	Razorfen_Downs
S	1441	Tanière des Volplumes	Dans une petite caverne du centre-sud des Mille pointes, les harpies de la Tanière des Volplumes ont établi leur nid.	Roguefeather_Den
S	1442	Fleuve Loup-noir	Le fleuve Loup-noir s'écoule du lac de la Combe à travers la Combe des Cisailles, dans les Serres-Rocheuses.	Blackwolf_River
S	1442	Caverne des Eboulis	Au bout du Ravin des Éboulis, la Caverne des Éboulis abrite le nid des kobolds des Éboulis.	Boulderslide_Cavern
S	1442	malakajin	Malaka'jin se trouve dans les Serres-Rocheuses, au sud du Poste Totem sinistre.	Malaka'jin
S	1442	Pic des Serres-Rocheuses	Le Pic des Serres-Rocheuses se trouve dans une vallée verdoyante, à l'extrême nord-ouest des montagnes qui partagent son nom, veillé par les druides de la Tanière des Serres, toute proche.	Stonetalon_Peak
S	1442	Retraite de Roche-Soleil	La Retraite de Roche-Soleil se cache parmi les pics au sud du lac Mirkfallon, dans les Serres-Rocheuses, un lieu où le monde des esprits touche de près celui des vivants.	Sun_Rock_Retreat
S	1442	Sentier des Tisseuses	Le Sentier des Tisseuses relie Malaka'jin au lac Mirkfallon, à travers une terre qui s'est affaissée de part et d'autre.	Webwinder_Path
S	1443	Village des Gelkis	Le Village des Gelkis s'étend en cercle autour d'un large ravin dans le sud-ouest de Désolace, siège du clan Gelkis.	Gelkis_Village
S	1443	Hutte de Kormek	La hutte se dresse, usée par les intempéries, dans le centre-nord de Désolace.	Kormek's_Hut
S	1443	Combe de Nijel	La Combe de Nijel monte la garde dans les montagnes du nord de Désolace, un avant-poste tenu par l'Alliance et le Cercle cénarien.	Nijel's_Point
S	1443	Grève de Sar'theris	La côte où Désolace rejoint la mer ne ressemble en rien à la terre qui s'étend derrière elle.	Sar'theris_Strand
S	1443	Camp de Scrabblescrew	Près du Cimetière des kodos, en Désolace, se trouve un petit camp gobelin.	Scrabblescrew's_Camp
S	1443	Proie-de-l'Ombre	Proie-de-l'Ombre se trouve là où la Grève de Sar'theris rejoint la côte sud de Désolace, un village de pêcheurs trolls.	Shadowprey_Village
S	1444	camp mojache	Le Camp Mojache se trouve là où un ruisseau rapide se jette dans le lac des rafales.	Camp_Mojache
S	1444	Hache-tripes	Il y a douze mille ans, une secte secrète de sorciers elfes de la nuit éleva Eldre'Thalas pour garder les secrets arcaniques les plus précieux de la reine Azshara.	Dire_Maul
S	1444	Bastion de Feathermoon	Au large de la côte ouest de Féralas, sur l'île de Sardor, se dresse une forteresse élevée dans la mer par le général Shandris Feathermoon, qui depuis dix mille ans se tient aux côtés de…	Feathermoon_Stronghold_(Classic)
S	1444	Ruines d'Isildien	Les Ruines d'Isildien sont ce qui reste d'une grande cité des elfes de la nuit, brisée il y a dix mille ans.	Ruins_of_Isildien
S	1444	thalanaar	Thalanaar est un lieu paisible, un petit avant-poste qui n'a guère d'attrait pour les voyageurs au-delà de sa fonction.	Thalanaar
S	1444	Gouffre grouillant	Le Gouffre grouillant, dans le sud-est de Féralas, est livré à la ruche Zukk'ash.	Writhing_Deep
S	1445	Marais bleu	Le Marais bleu s'étend dans le nord du marécage d'Âprefange, ses terres basses couvertes de roseaux et d'eaux stagnantes.	Bluefen
S	1445	Mur-de-Fougères	Mur-de-Fougères se dresse parmi les huttes et les tertres ogres dans le nord-ouest du marécage d'Âprefange, foyer des ogres Cognepierres, fidèles à la Horde.	Brackenwall_Village
S	1445	Tanière de Brandeguerre	Une vaste grotte s'ouvre sur la Tourbière du Ver et sa puanteur, repaire du drake noir Brandeguerre.	Emberstrife's_Den
S	1445	Citadelle de Theramore	La Citadelle de Theramore se dresse au cœur de l'île de Theramore, quartier général de la garde de Theramore.	Foothold_Citadel
S	1445	Ile de Theramore	Après la troisième guerre, Jaina Proudmoore conduisit les survivants de Lordaeron par-delà la mer jusqu'à Kalimdor.	Theramore_Isle
S	1445	Crique du Mascaret	La crique du Mascaret se trouve au bout de la baie d'Âprefange, au sud de l'île de Theramore, ses eaux parsemées d'îlots et de récifs cachés. Ce sont des eaux traîtresses pour la navigation.	Tidefury_Cove
S	1446	Désert Abysséen	Ces sables s'étendent en Tanaris, un désert qui se déploie dans toutes les directions.	Abyssal_Sands
S	1446	Pilier brisé	Au sud de Gadgetzan, près du Désert Abysséen, se dresse un petit amas de ruines trolls connu sous le nom de Pilier brisé.	Broken_Pillar
S	1446	gadgetzan	Gadgetzan s'élève dans le désert du nord de Tanaris sous un voile permanent de fumées noires, capitale du Cartel Gentepression, le plus grand des cartels gobelins.	Gadgetzan
S	1446	Port Gentepression	Port Gentepression se trouve sur la côte orientale de Tanaris, avec une route filant vers l'ouest jusqu'à sa ville mère, Gadgetzan, et un quai tendu vers Kezan.	Steamwheedle_Port
S	1446	uldum	Uldum se trouve sur la côte sud de Kalimdor, enclavée par le cratère d'Un'Goro au nord, Tanaris à l'est et Silithus au nord-ouest.	Uldum
S	1446	zulfarrak	Zul'Farrak fut jadis une cité de la jungle, lorsque Tanaris était encore une forêt sous l'empire Gurubashi.	Zul'Farrak
S	1447	Confins amers	Les Confins amers s'étendent au nord-est d'Azshara, peuplés d'hippogriffes, de limons et de chimères.	Bitter_Reaches
S	1447	Lac Mennar	Les eaux du lac Mennar reposent, immobiles, en leur centre, bien que la terre de tous côtés appartienne aux draconides.	Lake_Mennar
S	1447	Campement Legashi	Les satyres Legashi tiennent leur campement dans le nord d'Azshara, à l'est d'Ursolan.	Legash_Encampment
S	1447	Sanctuaire de Shadowsong	Colline couverte de ruines dans l'ouest d'Azshara, le Sanctuaire de Shadowsong ne garde aucune trace claire de la raison pour laquelle il porte ce nom.	Shadowsong_Shrine
S	1447	Halte de Talrendis	La Halte de Talrendis se dresse dans le sud-ouest d'Azshara, ses deux tours de garde surveillant la frontière d'Orneval, tandis qu'un puits de lune arrose encore la terre au sud.	Talrendis_Point
S	1447	valormok	Valormok est un avant-poste de la Horde en Azshara, situé au nord-ouest, au nord du Campement des Haldarr.	Valormok
S	1448	Poste de la Vénéneuse	Le Poste de la Vénéneuse se dresse sur les hautes falaises dominant Sombrivage, là où la Vénéneuse traverse Gangrebois.	Bloodvenom_Post
S	1448	Sanctuaire d'émeraude	Le Sanctuaire d'émeraude se trouve dans le sud-est de Gangrebois, un camp des druides du Cercle d'émeraude.	Emerald_Sanctuary
S	1448	Village de Gangrepatte	Le Village de Gangrepatte se trouve à la lisière nord de Gangrebois, près de l'entrée du Repaire des Grumegueules.	Felpaw_Village
S	1448	Défilé des Jadefeu	Dans le nord de Gangrebois se trouve le Défilé des Jadefeu, repaire des satyres les plus puissants de la région. La prudence s'impose à quiconque s'en approche.	Jadefire_Run
S	1448	morlosaran	Morlos'Aran fut jadis une grande cité des elfes de la nuit, élevée avant que la Grande fracture ne déchire le monde.	Morlos'Aran
S	1448	Fort des ombres	Sous Jaedenar, dans l'ouest de Gangrebois, s'étend un labyrinthe qui fut jadis un refuge des saisons des elfes de la nuit.	Shadow_Hold
S	1449	Rocher fongique	Le Rocher fongique s'ouvre dans la paroi nord-est du cratère d'Un'Goro, une caverne où vivent des gorilles parmi les champignons fantômes qui poussent dans son obscurité.	Fungal_Rock
S	1449	Sources de Golakka	La vapeur s'élève sans cesse des Sources de Golakka, où le cœur volcanique du cratère d'Un'Goro déverse sa chaleur dans des bassins et des geysers, à l'ouest du cratère.	Golakka_Hot_Springs
S	1449	Plateau de Rochefer	La roche nue perce la verdure d'Un'Goro le long de sa paroi nord-est. Le Plateau de Rochefer est paisible comparé au reste du cratère, presque dépourvu de prédateurs.	Ironstone_Plateau
S	1449	Fosses de goudron de Lakkari	Les lacs noirs au nord du Refuge des Marshal s'étendent, épais et nauséabonds, au milieu de la verdure d'Un'Goro.	Lakkari_Tar_Pits
S	1449	Refuge des Marshal	Le Refuge des Marshal se trouve à la lisière nord du cratère d'Un'Goro, établi par les Expéditions Marshal sous la conduite de Williden et Hol'anyee Marshal.	Marshal's_Refuge
S	1449	La Balafre sinueuse	La Balafre sinueuse s'étend sur la partie sud du cratère d'Un'Goro, une ruche de la secte Gorishi.	Slithering_Scar
S	1450	Lac Elune'ara	Une eau cristalline emplit le cœur de Reflet-de-Lune, immobile comme du verre sous les arbres.	Lake_Elune'ara
S	1450	Havrenuit	Sur les rives du lac Elune'ara se dresse Havrenuit, un village de pierre ouvragée par les elfes de la nuit et de puits de lune, où vivent les druides du Cercle cénarien.	Nighthaven
S	1450	Sanctuaire de Remulos	Dans l'ouest de Reflet-de-Lune se dresse le Sanctuaire de Remulos, élevé en l'honneur du gardien qui veille sur ce lieu.	Shrine_of_Remulos
S	1450	Refuge des saisons de Malfurion	Sous le gazon paisible de Reflet-de-Lune s'étendent les refuges des saisons, creusés dans une terre que de nombreux druides elfes de la nuit ne quittent jamais vraiment, leur corps…	Stormrage_Barrow_Dens
S	1450	Repaire des Grumegueules	Le Repaire des Grumegueules se trouve au nord-est de Gangrebois, là où un tunnel perce jusqu'à Reflet-de-Lune et au Berceau-de-l'Hiver.	Timbermaw_Hold
S	1451	Fort cénarien	Le Fort cénarien fut érigé à Silithus après la guerre des Sables changeants, bâti par le Cercle cénarien sur une ancienne cité des elfes de la nuit.	Cenarion_Hold
S	1451	Ruche'Ashi	Ruche'Ashi se trouve dans le nord de Silithus, et sa couvée silithide se répand pour infester le pilier grouillant, au-delà de ses limites.	Hive'Ashi
S	1451	Ruche'Zora	Ruche'Zora est un nid silithide creusé dans les sables de l'ouest de Silithus.	Hive'Zora
S	1451	La planque d'Ortell	Dans le sud-est de Silithus, une petite grotte s'ouvre sur les pentes, demeure d'un ermite du nom d'Ortell.	Ortell's_Hideout
S	1451	Village de Sudevent	Le Village de Sudevent fut jadis un avant-poste des elfes de la nuit à Silithus. Il ne survécut pas à la guerre des Sables changeants.	Southwind_Village
S	1451	Défilé du Crépuscule	Le Défilé du Crépuscule se cache dans la roche au pied de la Halte de Staghelm, dans le nord de Silithus.	Twilight's_Run
S	1452	Gorge du Sombre murmure	La Gorge du Sombre murmure se trouve dans le sud du Berceau-de-l'Hiver.	Darkwhisper_Gorge
S	1452	dun mandarr	Dun Mandarr se trouve près d'une caverne glacée, dans le sud-est du Berceau-de-l'Hiver, et son nom trahit des mains naines.	Dun_Mandarr
S	1452	Long-guet	Long-guet se dresse au croisement des routes commerciales du Berceau-de-l'Hiver, un comptoir gobelin du Cartel Gentepression, dont le laboratoire se niche parmi les bâtiments.	Everlook
S	1452	Gorge du Blanc murmure	La Gorge du Blanc murmure entaille le sud du Berceau-de-l'Hiver, son fond et ses crêtes jonchés de ruines des elfes de la nuit.	Frostwhisper_Gorge
S	1452	Lac Kel'Theril	Les eaux gelées du lac Kel'Theril reposent, immobiles, au cœur du Berceau-de-l'Hiver, entourées des ruines qui partagent son nom.	Lake_Kel'Theril
S	1452	Poste des Grumegueules	Le Poste des Grumegueules porte un nom qui ne lui convient plus.	Timbermaw_Post
S	1453	Hall des Champions	Dans le sud de la Vieille ville, à la Cité de Stormwind, se dresse le Hall des Champions, où logent les officiers de l'Alliance, à l'écart au sein de la vieille cité, comme il sied à leur…	Champions'_Hall
S	1453	Tram des profondeurs	Ce n'est pas par goût du confort que le roi Magni Bronzebeard fit construire le Tram des profondeurs.	Deeprun_Tram
S	1453	Vallée des Héros|Vallée des héros	Un pont de pierre pâle mène chaque voyageur par-dessus les douves, devant la porte sud de Stormwind, jusqu'à une vallée verdoyante bordée de statues élevées autant par chagrin que par…	Valley_of_Heroes
S	1454	Hall des Légendes	Le Hall des Légendes se dresse dans la vallée de la Force, à Orgrimmar : ce sont les casernes où les officiers de la Horde tiennent conseil.	Hall_of_Legends
S	1454	Gouffre de Ragefeu	Sous Orgrimmar, la terre s'ouvre sur un gouffre ardent, aux tunnels encombrés de lave et de fumée.	Ragefire_Chasm
S	1455	Tram des profondeurs	Ce n'est pas par goût du confort que le roi Magni Bronzebeard fit construire le Tram des profondeurs.	Deeprun_Tram
S	1455	Portes d'Ironforge|Portes de Forgefer	Les Portes d'Ironforge s'élèvent là où la grande rampe de Dun Morogh monte à la rencontre de la montagne, visibles à des lieues à travers les neiges bien avant qu'un voyageur ne les…	Gates_of_Ironforge
S	1456	Cime des Anciens	La Cime des Anciens se dresse à l'est du plateau central, et l'on y accède par des ponts de corde depuis la cime haute et la cime du milieu.	Elder_Rise
S	1456	Cime des chasseurs	La cime sud de Thunder Bluff appartient à ceux qui combattent et à ceux qui chassent.	Hunter_Rise
S	1456	Les Bassins de la Vision	Sous le sommet de la Cime des Esprits, un tunnel débouche sur une eau sombre et immobile, connue sous le nom de Bassins de la vision.	Pools_of_Vision
S	1456	spirit rise	La Cime des Esprits se dresse au nord-ouest du plateau central, vouée à l'étude chamanique chez les taurens. La tribu Skychaser y fait autorité.	Spirit_Rise
S	1457	Enclave cénarienne	L'Enclave cénarienne s'étend au nord-ouest de Darnassus, un bosquet circulaire où chênes et frênes s'élèvent plus haut que les salles de pierre du reste de la cité.	Cenarion_Enclave
S	1457	Terrasse des Artisans	La Terrasse des Artisans s'étend au nord de Darnassus, vouée au commerce plutôt qu'à la guerre ou au culte.	Craftsmen's_Terrace
S	1457	Les Jardins du temple	Au cœur de Darnassus s'étendent les Jardins du temple, une vaste étendue d'eau, de passerelles et de petites îles, qui tirent leur nom du grand temple de la Lune qui s'élève juste au sud.	Temple_Gardens
S	1457	Terrasse des Marchands	La Terrasse des Marchands se trouve dans la partie sud de Darnassus, où les boutiquiers tiennent leurs étals et où les négociants se retrouvent pour marchander, ce qui en fait le cœur…	Tradesmen's_Terrace
S	1457	Terrasse des Guerriers	La Terrasse des Guerriers abrite la porte orientale de Darnassus, là où la cité s'ouvre sur les terres sauvages de Teldrassil.	Warrior's_Terrace
S	1458	Ruines de Lordaeron	Au-dessus de la cité ensevelie, le palais de Lordaeron se dresse toujours, ses salles ouvertes au ciel, ses jardins retournés à l'abandon.	Ruins_of_Lordaeron
S	2652	Vallée des Ossements	La Vallée des Ossements est un escarpement à la lisière sud de Désolace, hanté par des squelettes, des nécromanciens centaures et les fantômes du clan Magram massacré.	Valley_of_Bones
]]
local EN = [[

Z	1411	Cracked and red, Durotar is a land of crags and canyons, dry and hot, sparse in water and green things. It lies on the eastern coast of Kalimdor.	Durotar_(Classic)
Z	1412	The tauren wandered for hundreds of years with no land of their own.	Mulgore_(Classic)
Z	1413	The dust here was not always dust. This land was forest once, tended by the night elves, and several of their large cities stood here.	Barrens_(Classic)
Z	1416	Rain falls on these peaks more often than not, and the sky stays gray under heavy cloud. Forest covers the slopes below snow on the highest ground.	Alterac_Mountains_(Classic)
Z	1417	King Thoradin built Strom, the capital of Arathor, in this dry and craggy country. Near it he raised a great wall to shield his people from the Amani trolls.	Arathi_Highlands_(Classic)
Z	1418	The Badlands are cracked dry earth, strewn with boulders and cut by winding canyons, shut in by mountains on every side.	Badlands_(Classic)
Z	1419	The rocks of the Blasted Lands were once tan. Searing heat and wild energies turned them crimson when the Dark Portal was destroyed, and the land has stayed a desert ever since.	Blasted_Lands_(Classic)
Z	1420	The sky over Tirisfal Glades hangs gloomy and green.	Tirisfal_Glades_(Classic)
Z	1421	The pines here are tall and silver-barked, and they stand over grassy knolls. Before the Third War the Alliance kept this wood green and whole.	Silverpine_Forest_(Classic)
Z	1422	Before the plague, this was forested farmland east of Lordaeron's capital.	Western_Plaguelands_(Classic)
Z	1423	Before the plague, these lands were farms and small villages, all of them looking to Stratholme, the largest city in Lordaeron.	Eastern_Plaguelands_(Classic)
Z	1424	Most of Lordaeron has been twisted by the Scourge, but the Hillsbrad Foothills still look as the kingdom once did. The hills are green, the meadows fertile and the soil rich.	Hillsbrad_Foothills_(Classic)
Z	1425	The Wildhammer dwarves hold the west of the Hinterlands, where they tame wild gryphons.	Hinterlands_(Classic)
Z	1426	Snow lies deep across Dun Morogh, and its mountains are the highest in the Eastern Kingdoms.	Dun_Morogh_(Classic)
Z	1427	More than two hundred years ago the ground here was torn open. Before that the land was part of the Redridge Mountains.	Searing_Gorge_(Classic)
Z	1428	The sky over the Burning Steppes glows red, lit by eruptions from Blackrock Mountain. Rivers of lava cross the craggy foothills, the earth is charred, and the air stays hot and dry.	Burning_Steppes_(Classic)
Z	1429	In the First War, thousands of orcs marched through Elwynn Forest and closed around Stormwind, leaving the sea as the only way out.	Elwynn_Forest_(Classic)
Z	1431	Duskwood was once the southern part of Elwynn Forest, a fiefdom of Stormwind called Brightwood. Two sizable towns stood among its farms.	Duskwood_(Classic)
Z	1432	Gray mountains rise on every side of Loch Modan, their hills lightly wooded with pine and birch.	Loch_Modan_(Classic)
Z	1433	Elms rise over fast rivers in the Redridge Mountains, and the land climbs steadily toward the peaks. The range lies east of Elwynn Forest and south of the Burning Steppes.	Redridge_Mountains_(Classic)
Z	1434	For ages the jungle trolls of the Gurubashi ruled this land, and their stone cities lay scattered across it. The empire turned cruel.	Stranglethorn_Vale_(Classic)
Z	1435	Once the northern half of a vast marshland called the Black Morass, the Swamp of Sorrows saw the Dark Portal open in the southern half.	Swamp_of_Sorrows_(Classic)
Z	1436	The wind crosses Westfall's fields with nothing to stop it.	Westfall_(Classic)
Z	1437	Mist hangs low over the Wetlands, and the sky is a flat gray from one end of the country to the other.	Wetlands_(Classic)
Z	1438	After the Third War, Malfurion Stormrage vanished into the Emerald Dream, and the archdruid Fandral Staghelm took over the leadership of the night elf druids.	Teldrassil_(Classic)
Z	1439	The name comes from the mist. A gray haze lies over this coast most days, and rain and wind scour its rocky beaches.	Darkshore_(Classic)
Z	1440	Rain falls almost without pause in Ashenvale, but the trees are so old and thick that only trickles reach the ground.	Ashenvale_(Classic)
Z	1441	It is thought that a river once cut this canyon, leaving tall columns of sandstone standing in it, with green forest along its banks.	Thousand_Needles_(Classic)
Z	1442	The Stonetalon Mountains keep their holiest ground on the largest peak in the range. Night elves tend a barrow and a glade at the top and commune there with the spirits of nature.	Stonetalon_Mountains_(Classic)
Z	1443	Desolace is a gray, rocky waste littered with bones, under black skies and constant wind.	Desolace_(Classic)
Z	1444	Where the land around it is barren, Feralas is a jungle of huge, ancient trees.	Feralas_(Classic)
Z	1445	Dustwallow Marsh was once a high plain of tall grass, grazed by great herds. The Sundering smashed it down into a valley, and water bled up from underground and has kept it wet ever since.	Dustwallow_Marsh_(Classic)
Z	1446	Nozdormu, the dragon of time, is said to have made this land his home since before anyone counted years. The heat and the miles of empty sand suited him.	Tanaris_(Classic)
Z	1447	Autumn never leaves Azshara. The trees along the coast burn orange and red, and past them great cliffs drop to ivory beaches and a shallow sea broken by spires of jagged rock.	Azshara_(Classic)
Z	1448	Felwood was once the northern woods of Ashenvale, tended by the night elves and watched over by Cenarius. Then the Burning Legion pressed toward Mount Hyjal.	Felwood_(Classic)
Z	1449	Three deserts press in around Un'Goro Crater and cut it off almost entirely from the rest of the world. Even so, a thick jungle of exotic plants and stranger beasts fills it.	Un'Goro_Crater_(Classic)
Z	1450	Moonglade lies cradled in a ring of mountains, a hidden vale of hills and old forest that corruption has never touched.	Moonglade
Z	1451	Sand and broken rock cover the southwestern corner of Kalimdor, and the only things that rise from the waste are the huge hives of the silithid.	Silithus_(Classic)
Z	1452	Above Moonglade the mountain climbs through a thick bank of white cloud, and beyond it lies Winterspring. The air is crisp and clean up here.	Winterspring_(Classic)
Z	1453	Orcs of the Horde burned Stormwind in the First War. After the Second War its people came home to the ruins, and the Stonemasons' Guild rebuilt the city in white stone.	Stormwind_City
Z	1454	Soon after the Battle of Mount Hyjal, Warchief Thrall led his people to a bare stretch of Kalimdor's coast.	Orgrimmar
Z	1455	The first dwarves walked out of Uldaman and went west to the mountains of Dun Morogh.	Ironforge
Z	1456	For countless generations the tauren wandered, and the centaur hunted them across the plains. Then Warchief Thrall and the Horde came to Kalimdor.	Thunder_Bluff
Z	1457	Immortality ended for the night elves after the Third War, and many could not bear aging, disease and frailty.	Darnassus
Z	1458	The Undercity was old before the Forsaken claimed it.	Undercity
S	1411	bladefist bay	Rubble from the sea washes in on every tide, and the water has been called the Great Sea's midden heap.	Bladefist_Bay
S	1411	burning blade coven	Dusty red mountains form the northern border of the Valley of Trials, and a cave there leads into abandoned caverns.	Burning_Blade_Coven
S	1411	den	Zureetha Fargaze sends promising young orcs and trolls out into the world from this cave in the cliff, near the middle of the Valley of Trials.	The_Den
S	1411	kolkar crag	Warlord Kolkanis leads the Kolkar centaurs who hold this craggy gorge in southern Durotar.	Kolkar_Crag
S	1411	razor hill	The forces of Kul Tiras arranged a summit with Thrall on this hill, shortly after the Third War. It was an ambush.	Razor_Hill
S	1411	valley of trials	Young orcs and trolls of the Horde begin here, in a walled bowl of scorched earth in southern Durotar.	Valley_of_Trials
S	1412	baeldun digsite	A dwarven expedition from Bael Modan has cut a large quarry into the mountainside at the western edge of Mulgore.	Bael'dun_Digsite
S	1412	bloodhoof village	Drums made in Bloodhoof Village are unlike any others, and the village is known for the craft.	Bloodhoof_Village
S	1412	brambleblade ravine	The Bristleback quilboar hold Brambleblade Ravine, on the northeastern edge of Red Cloud Mesa. Their raids on the tauren come from here.	Brambleblade_Ravine
S	1412	camp narache	Camp Narache is the chief village of the Hawkwind tribe, on the northern edge of Red Cloud Mesa in southern Mulgore.	Camp_Narache
S	1412	venture co mine	Mining rights in Mulgore were refused to the Venture Company, and the company dug anyway.	Venture_Co._Mine
S	1412	winterhoof water well	The Winterhoof Water Well lies at the edge of the Rolling Plains in southern Mulgore.	Winterhoof_Water_Well
S	1413	camp taurajo	Tauren keep an outpost here in the Barrens, near the mountain pass that leads into Mulgore. It has an inn for travelers coming out of the tauren homeland.	Camp_Taurajo
S	1413	crossroads	Two roads cross here, the Gold Road running north and south and the road that runs from Ratchet to the Stonetalon Mountains.	Crossroads
S	1413	lushwater oasis	Lushwater Oasis lies just south of the Crossroads, one of the three major oases of the Barrens.	Lushwater_Oasis
S	1413	ratchet	Gazlowe was paid well by Warchief Thrall for the help he and his workers gave in raising Orgrimmar after the Third War.	Ratchet
S	1413	stagnant oasis	Kolkar centaurs camp on the fringes of the Stagnant Oasis, which lies between the Merchant Coast and the Gold Road.	Stagnant_Oasis
S	1413	wailing caverns	The night elf druid Naralex found these caverns and named them for the mournful howls of wind and steam in the rock.	Wailing_Caverns
S	1416	dalaran	Magi of the Arathorian Empire founded Dalaran after the Troll Wars, and it grew into a nation ruled by the Kirin Tor under the Council of Six.	Dalaran
S	1416	gavins naze	Mountain lions roam this hill, and the rare Araga is sometimes among them.	Gavin's_Naze
S	1416	growless cave	Deep in this cave in the Alterac Mountains stands the Flame of Uzel, an old ceremonial pyre.	Growless_Cave
S	1416	headland	A mountain lion with a slight mane and a striped tail rests on the cliffside of the Headland. She is Araga, and no other cat in the hills looks like her.	Headland
S	1416	lordamere lake	Many human kingdoms prospered around Lordamere Lake in the days of the Alliance of Lordaeron.	Lordamere_Lake
S	1416	ravenholdt manor	Lord Jorach Ravenholdt leads his Assassin's League from this hidden manor in the Alterac Mountains.	Ravenholdt_Manor
S	1417	bouldergor	A rough, broken hill rises north of Stromgarde Keep. Boulderfist ogres hold a mound on it, and Witherbark forest trolls loiter on its slopes beside them.	Boulder'gor
S	1417	goshek farm	Primwell Skye, a veteran of the Second War, once held this farmstead. After the Third War, Forsaken and orcs from Hammerfall took it.	Go'Shek_Farm
S	1417	hammerfall	Orgrim Doomhammer fell here. After the Second War the Alliance of Lordaeron kept captive orcs in one of its largest internment camps on this ground.	Hammerfall
S	1417	northfold manor	A farm on the northwestern edge of the Arathi Highlands became a Syndicate outpost after the fall of Stromgarde.	Northfold_Manor
S	1417	refuge pointe	When Stromgarde's capital fell in ruins after the Third War, most of its people fled south.	Refuge_Pointe
S	1417	stromgarde keep	Legend says King Thoradin saw a black wolf roaming this dry land and chose the spot for his capital.	Stromgarde_Keep
S	1418	camp boff	Only three ogres guard Camp Boff, the southeastern of the four camps the Dustbelcher ogres keep in the Badlands.	Camp_Boff
S	1418	camp wurg	Some of the Dustbelcher ogres live at Camp Wurg in the northwest of the Badlands, and Boss Tho'grun's mercenary band stops here on its rounds.	Camp_Wurg
S	1418	dustwind gulch	Dustwind Gulch cuts through the dry, cracked ground of the Badlands, west of Lethlor Ravine.	Dustwind_Gulch
S	1418	kargath	Kargath is the only outpost the Horde holds in Khaz Modan. It is named for Kargath Bladefist, chieftain of the Shattered Hand clan.	Kargath
S	1418	mirage flats	Giant buzzards, ridge stalker patriarchs and rabid crag coyotes live on the Mirage Flats, east of Dustbelch Grotto.	Mirage_Flats
S	1418	uldaman	Legends say the titans made the troggs from stone, judged them a failure and locked them away in a vault under the earth. Then they tried again, and the dwarves were the result.	Uldaman
S	1419	dark portal	Medivh, a human mage in the grip of Sargeras, and the orc warlock Gul'dan tore a rift between Draenor and Azeroth in the Black Morass.	Dark_Portal
S	1419	garrison armory	In the scarred ground of the Blasted Lands, Alliance miners work the Garrison Armory, wresting minerals from the earth for Nethergarde Keep.	Garrison_Armory
S	1419	nethergarde keep	Nethergarde Keep stands on a high bluff above the only road into the Blasted Lands, its walls raised to watch the ruin of a gateway that no one wanted opened again.	Nethergarde_Keep
S	1419	rise of the defiler	Craggy mountains rise near the middle of the Blasted Lands, and a great demon lives among them.	Rise_of_the_Defiler
S	1419	serpents coil	Burnt-out orcish buildings left from the Second War stand at the mouth of this winding cave system in the east.	Serpent's_Coil
S	1419	tainted scar	This stretch of the western Blasted Lands was once part of the Black Morass.	Tainted_Scar
S	1420	brill	Brill was an ordinary town of Lordaeron, held by the Barov family, with the Agamands keeping a manor of their own within its bounds.	Brill
S	1420	deathknell	Every other Forsaken settlement kept the name it had as a human town. Deathknell was renamed, and no one knows why.	Deathknell
S	1420	gallows end tavern	In Brill, the Forsaken run the only fully working tavern their people are known to keep. In its cellar a captured Scarlet Zealot and a dwarven mountaineer are held prisoner.	Gallows'_End_Tavern
S	1420	night webs hollow	Spiders hold this small valley and the gold mine cut into it. Young Night Web Spiders wander the open hollow, and grown ones skitter through the mine and lurk in its webbed corners.	Night_Web's_Hollow
S	1420	ruins of lordaeron	Prince Arthas Menethil turned on his own people. He came home to Lordaeron at the head of an army and found his father, King Terenas, waiting in the throne room, and he killed him there.	Ruins_of_Lordaeron
S	1420	scarlet monastery	The monastery in the northeast corner of Tirisfal Glades was once a cathedral of the Church of the Holy Light. It held great libraries and served as a seminary where paladins trained.	Scarlet_Monastery
S	1421	ambermill	Ambermill was a lumber town of little account until the Third War.	Ambermill
S	1421	deep elem mine	Arugal's magic has reached Deep Elem Mine, in the hills of central Silverpine Forest, and worgen of the Moonrage pack have made it their home.	Deep_Elem_Mine
S	1421	lordamere lake	Many human kingdoms prospered around Lordamere Lake in the days of the Alliance of Lordaeron.	Lordamere_Lake
S	1421	sepulcher	The Sepulcher sits in the western hills above the Lordaeron coast. Once it was only a large graveyard beside the road that crosses Silverpine Forest, its crypts a resting place for the dead.	Sepulcher
S	1421	shadowfang keep	Baron Silverlaine once held this keep on a high bluff above Pyrewood Village. When the Scourge swept over Lordaeron, Archmage Arugal summoned the worgen against the counsel of the Kirin Tor.	Shadowfang_Keep
S	1421	south tides run	The southwestern coast of Silverpine Forest, where the land meets the Great Sea, is called South Tide's Run.	South_Tide's_Run
S	1422	caer darrow	Humans built the fortress of Caer Darrow long ago, and an ancient high elven runestone was set within it.	Caer_Darrow
S	1422	chillwind camp	Chillwind Camp stands at the southern entrance to the Western Plaguelands, where the road comes down from the Alterac Mountains, and it is the last safe ground for Alliance travelers.	Chillwind_Camp
S	1422	dalsons tears	Dalson's Orchard once bore fruit for the family that gave it its name. Now the Scourge hold the farm.	Dalson's_Tears
S	1422	scholomance	The House of Barov kept its manor on this rise above Caer Darrow.	Scholomance
S	1422	thondroril river	The Thondroril River marks the line between the Western and Eastern Plaguelands. It runs south into Darrowmere Lake and goes on below it as the Darrowmere River.	Thondroril_River
S	1422	writhing haunt	Crops once grew in the furrows of the Writhing Haunt, tended for the sustenance of the living.	Writhing_Haunt
S	1423	browman mill	Skeletons, banshees and abominations crowd Browman Mill, a haunted lumber mill just north of Light's Hope Chapel.	Browman_Mill
S	1423	lights hope chapel	Among the oldest and most revered holy sites of the Church of the Holy Light, Light's Hope Chapel stands on the slopes of the mountains in the east of the region.	Light's_Hope_Chapel
S	1423	stratholme	Stratholme's ruin began with grain. Shipments from Andorhal, infected by the Cult of the Damned, were baked into bread and eaten by a populace who never knew they were dying.	Stratholme
S	1423	terrordale	Terrordale is a small town in the northwest corner of the Eastern Plaguelands.	Terrordale
S	1423	thondroril river	Tirion Fordring, one of the first paladins of the Silver Hand, keeps to the eastern side of the Thondroril River, near a ruined farmhouse.	Thondroril_River
S	1423	zulmashar	The Mossflayers, a small tribe of forest trolls, once ruled from Zul'Mashar.	Zul'Mashar
S	1424	darrow hill	Darrow Hill lies in the northern Hillsbrad Foothills, beneath the Headland.	Darrow_Hill
S	1424	dun garok	Dwarves hold this keep in the southeastern hills, under Captain Ironhill. They guard the humans of Hillsbrad and watch over the Azurelode Mine.	Dun_Garok
S	1424	eastern strand	The Eastern Strand runs along the southeastern coast of the Hillsbrad Foothills, its counterpart lying further west along the same shore.	Eastern_Strand
S	1424	purgation isle	A towering spiral of rock rises from the water south of the Hillsbrad shore, with a cemetery on its top and the ruins of a scout tower.	Purgation_Isle
S	1424	tarren mill	Early in the Second War, high elven archers from Silvermoon came south to see the orc threat. They were ambushed in the grasslands near Tarren Mill and taken to a nearby prison camp.	Tarren_Mill
S	1424	western strand	The Western Strand lies on the southwest coast of Hillsbrad Foothills. Torn Fin murlocs have raised small camps along its shore, and Andy Murgole patrols the area.	Western_Strand
S	1425	aerie peak	The Wildhammers went home to Grim Batol after the War of the Three Hammers and found the fortress tainted by the death of Modgud. They could not live there.	Aerie_Peak
S	1425	bogens ledge	Bogen's Ledge is a cave in the southwestern Hinterlands. Vicious owlbeasts prowl around it.	Bogen's_Ledge
S	1425	featherbeards hovel	A small house stands next to Aerie Peak, the home of Featherbeard.	Featherbeard's_Hovel
S	1425	revantusk village	When the Second War broke the Old Horde, many forest trolls deserted their orc allies without a moment's hesitation. The Revantusk kept some loyalty to the Horde.	Revantusk_Village
S	1425	valorwind lake	Northeast of Shadra'Alor lies Valorwind Lake, a small and quiet body of water.	Valorwind_Lake
S	1425	wildhammer keep	At one end of Aerie Peak, opposite the great gryphon aviary, stands the keep of the Wildhammer dwarves. Falstad Wildhammer, their High Thane, rules from the top of the peak.	Wildhammer_Keep
S	1426	anvilmar	In Coldridge Valley stands Anvilmar, the first town of any size in the north of the valley. A hall built around a great forge is at its center.	Anvilmar
S	1426	coldridge valley	Cut off in the southwestern corner of Dun Morogh, Coldridge Valley lies under thick snow. Its only way out is the tunnel of Coldridge Pass to the northeast.	Coldridge_Valley
S	1426	frostmane hold	Frostmane Hold stands on the western edge of Dun Morogh's cold mountains, south of Gnomeregan, a scatter of buildings knit to a cave system driven into the mountainside.	Frostmane_Hold
S	1426	gnomeregan	The gnomes built Gnomeregan underground, in the foothills of Dun Morogh, and filled it with iron and invention. During the Third War, mutant troggs infested the city.	Gnomeregan
S	1426	kharanos	Kharanos sits among the mountain peaks of Dun Morogh, a bustling little town ringed by wintry wilds.	Kharanos
S	1426	thunderbrew distillery	The ale of the Thunderbrew Distillery is known far and wide. The dwarven tavern in Kharanos was founded, so Ragnar Thunderbrew says, by his father, Arkilus Thunderbrew.	Thunderbrew_Distillery
S	1427	blackchar cave	Blackchar Cave, in the southwest of the gorge near Blackrock Mountain, is sealed off. What it holds is a mystery.	Blackchar_Cave
S	1427	blackrock mountain	The Bronzebeard and Wildhammer armies were marching to purge the Dark Iron clan when the ridge burst upward into Blackrock Mountain.	Blackrock_Mountain
S	1427	firewatch ridge	Firewatch Ridge is the main camp of the Dark Iron dwarves in Searing Gorge, overlooking the great excavation of the Cauldron.	Firewatch_Ridge
S	1427	grimesilt dig site	Dwarves from Ironforge once dug at the Grimesilt Dig Site. The Dark Iron dwarves took it over and hold it still.	Grimesilt_Dig_Site
S	1427	sea of cinders	The Sea of Cinders lies flat and open in the southern reaches of Searing Gorge, just north of Blackrock Mountain. Nothing grows there.	Sea_of_Cinders
S	1427	thorium point	Overseer Oilfist leads the Thorium Brotherhood, Dark Iron dwarves who left their clan.	Thorium_Point
S	1428	blackrock mountain	Blackrock Mountain bore its name centuries before the Blackrock orcs came to it. It rose out of the ruined Dark Iron kingdom when Ragnaros broke into the world.	Blackrock_Mountain
S	1428	blackrock pass	Blackrock Pass is the threshold between two worlds. On one side lie the quiet green hills of the Redridge Mountains.	Blackrock_Pass
S	1428	dracodar	Scorched hills fill the southwest of the Burning Steppes, blackened and given over to the black dragonflight. Its minions crawl across the ground in numbers.	Draco'dar
S	1428	flame crest	Only a crude bridge leads onto the bare outcropping of rock where Flame Crest stands. The outpost belongs to neither the Horde nor the Alliance.	Flame_Crest
S	1428	morgans vigil	Fire has been through Morgan's Vigil, in the southeastern corner of the Burning Steppes. Its houses are burned to the ground and its one mage tower has crumbled.	Morgan's_Vigil
S	1428	ruins of thaurissan	These ashen flats in the Burning Steppes were green once, when the city of Thaurissan stood here.	Ruins_of_Thaurissan
S	1429	echo ridge mine	Marshal McBride keeps sending men into Echo Ridge Mine, in the northwest of Northshire Valley, to thin the kobolds that have taken over its tunnels.	Echo_Ridge_Mine
S	1429	goldshire	Goldshire stands at the center of Elwynn Forest, one of the small towns that grew up around Stormwind.	Goldshire
S	1429	jerods landing	The Defias Brotherhood holds Jerod's Landing, a boat landing on the Elwynn Forest bank of the Nazferiti river.	Jerod's_Landing
S	1429	northshire abbey	Centuries ago, clerics of the Church of the Holy Light came south from Lordaeron and founded the Holy Order of Northshire Clerics at this abbey.	Northshire_Abbey
S	1429	northshire valley	Impenetrable mountains close in Northshire Valley on every side but one. A pass leads out to the south, protected by thick stone walls and a guarded gate.	Northshire_Valley
S	1429	northshire vineyards	Defias bandits drove the farmers out of the Northshire Vineyards, which lie east of the abbey across the bridge. The Brotherhood's agents hold the rows now and keep a tent among the vines.	Northshire_Vineyards
S	1431	brightwood grove	The few buildings that stood at the edge of Brightwood Grove lie in ruins, and Nightbane worgen prowl its dark fields.	Brightwood_Grove
S	1431	darkshire	Darkshire was once a quaint little woodland village called Grand Hamlet, in the forest of Brightwood. Then the darkness came, and the woods turned into a dangerous, thorny blight.	Darkshire
S	1431	raven hill	The houses of Raven Hill stand empty in western Duskwood, given up to rot and dark. Almost nobody is left.	Raven_Hill
S	1431	raven hill cemetery	The cemetery grew far past its old bounds only after the darkness came to Duskwood.	Raven_Hill_Cemetery
S	1431	rolands doom	Roland's Doom is a mine in southeastern Duskwood, due east of the Rotting Orchard.	Roland's_Doom
S	1431	yorgen farmstead	Sven Yorgen once farmed this land in southern Duskwood, until Dark Riders from Deadwind Pass came and killed his family.	Yorgen_Farmstead
S	1432	dun algaz	The tunnel through Dun Algaz is older than the War of the Three Hammers. When that war drove the Wildhammer dwarves out of Ironforge, they passed through here.	Dun_Algaz
S	1432	north gate pass	The pass runs between the high mountains of Dun Morogh to the west and the lower mountains of Loch Modan to the east.	North_Gate_Pass
S	1432	stonesplinter valley	Stonesplinter Valley was a pristine place once, carved among the mountains of southwestern Loch Modan. Now it crawls with hostile Stonesplinter troggs.	Stonesplinter_Valley
S	1432	stonewrought dam	Few who cross the Stonewrought Dam know that a Dark Iron dwarf built it.	Stonewrought_Dam
S	1432	stoutlager inn	The Stoutlager Inn stands in Thelsamar. Dwarves and travelers gather here to drink and talk. Innkeeper Hearthstove keeps it, and Lina Hearthstove tends the stable.	Stoutlager_Inn
S	1432	thelsamar	A dwarven town stands on the west shore of Loch Modan, north of Grizzlepaw Ridge and northeast of Stonesplinter Valley.	Thelsamar
S	1433	althers mill	The lumber mill northeast of Lakeshire is abandoned.	Alther's_Mill
S	1433	lakeshire	Lakeshire sits on the northern bank of Lake Everstill, and the town has bled for that ground more than once.	Lakeshire
S	1433	renders camp	Blackrock orcs hold an outpost in the northwestern Redridge Mountains, near the entrance to the Burning Steppes.	Render's_Camp
S	1433	rethban caverns	Gnolls hold the deep tunnels of the Rethban Caverns, in the northwestern Redridge Mountains. Their leader, Ardo Dirtpaw, is a cunning one.	Rethban_Caverns
S	1433	stonewatch keep	Gath'Ilzogg, a warlord of the Blackrock clan, holds Stonewatch Keep with his trusted lieutenant Tharil'zun.	Stonewatch_Keep
S	1433	tower of ilgalar	Morganth once studied in the mage tower of Stormwind with two other mages, until he fell to the dark arts.	Tower_of_Ilgalar
S	1434	booty bay	Visitors on foot enter Booty Bay through the bleached jaws of a giant shark. Beyond them a port city climbs the cliffs around a blue lagoon at the southern tip of Stranglethorn Vale.	Booty_Bay
S	1434	gromgol base camp	Commander Aggro'gosh holds Grom'gol Base Camp, an orc fort on the western coast.	Grom'gol_Base_Camp
S	1434	ruins of zulmamwe	Mountains close in the ruins of Zul'Mamwe on every side except the north.	Ruins_of_Zul'Mamwe
S	1434	stockpile	A cave at the back of Kurzen's Compound serves as the arsenal of Colonel Conrad Kurzen's jungle fighters, who keep their arms and equipment here.	Stockpile
S	1434	venture co operations center	An oil platform stands on a lake in the northern jungle, built by goblins of the Venture Company.	Venture_Co._Operations_Center
S	1434	vile reef	Off the western coast of Stranglethorn Vale, near Grom'gol Base Camp, the sea breaks bright over coral.	Vile_Reef
S	1435	ithariuss cave	A mysterious high elf named Itharius lives in this cave, in the far southwestern corner of the swamp.	Itharius's_Cave
S	1435	pool of tears	The Pool of Tears lies broad and still on the eastern edge of the Swamp of Sorrows.	Pool_of_Tears
S	1435	sorrowmurk	Green dragonspawn crawl through the mire here, just east of the Pool of Tears and the Temple of Atal'Hakkar. A large green drake patrols the region.	Sorrowmurk
S	1435	stagalbog cave	Many murlocs of the Marsh tribe live in this large cave in the eastern marsh, under their leader, the Swamp Talker.	Stagalbog_Cave
S	1435	stonard	Orcs of the Old Horde raised Stonard in the Black Morass soon after the Dark Portal first opened.	Stonard
S	1435	temple of atalhakkar	More than a thousand years ago, the Gurubashi Empire was torn apart by civil war.	Temple_of_Atal'Hakkar
S	1436	alexston farmstead	The fields at Alexston Farmstead once fed families, before the Defias Brotherhood took the land.	Alexston_Farmstead
S	1436	deadmines	Before the First War, the tunnels beneath Moonbrook were the greatest gold mine in human lands. The First War emptied them of miners, and afterward they were left alone and thought haunted.	Deadmines
S	1436	demonts place	Little remains of the old farmstead at Demont's Place, west of Moonbrook. Defias agents occupy it now and hold it as their own.	Demont's_Place
S	1436	jansen stead	The northernmost farm in Westfall, the Jansen Stead, stands close to the bridge into Elwynn Forest.	Jansen_Stead
S	1436	longshore	Westfall's coast runs long and wide, one of the biggest beaches in Azeroth. Murlocs roam it in swarms, and Old Murk-Eye roams among them.	Longshore
S	1436	sentinel hill	Sentinel Hill stands on high ground in eastern Westfall. A tower watches from the top, and below it on the slope are cottages, a forge, an inn and a lumber mill.	Sentinel_Hill
S	1437	deepwater tavern	Fights break out often in the Deepwater Tavern, and Tapoke "Slim" Jahn starts many of them. It is a busy gathering place in Menethil Harbor.	Deepwater_Tavern
S	1437	dun algaz	The tunnel through Dun Algaz is older than the War of the Three Hammers. When that war drove the Wildhammer dwarves out of Ironforge, they passed through here.	Dun_Algaz
S	1437	grim batol	The walls and spires of Grim Batol rise in the eastern Wetlands toward a steel-gray sky, but most of the fortress lies underground.	Grim_Batol
S	1437	menethil bay	Crocolisks of every age and size crowd Menethil Bay, and hunters take them for their fine leather.	Menethil_Bay
S	1437	menethil harbor	The wall is the first thing anyone notices, thick stone thrown up around a harbor town on a small island off the western shore.	Menethil_Harbor
S	1437	mosshide fen	The Mosshide gnolls hold this waterlogged fen in the eastern Wetlands, and their camps dot the ground.	Mosshide_Fen
S	1438	aldrassil	Aldrassil rises at the heart of Shadowglen, a giant tree with a village in its boughs.	Aldrassil
S	1438	cleft	The Cleft lies northwest of Dolanaar, close to the corrupted cave of Fel Rock, and nothing makes its home there.	Cleft
S	1438	dolanaar	Young night elves leaving Shadowglen come to Dolanaar first.	Dolanaar
S	1438	ruttheran village	Rut'theran Village sits at the very foot of the World Tree, the port for the night elf city of Darnassus far above.	Rut'theran_Village
S	1438	shadowglen	A perpetual dusk lies over Shadowglen, a small glade in the northeast of Teldrassil that never quite sees full daylight. Mountains ring it on every side.	Shadowglen
S	1438	shadowthread cave	Great spiders have always lived in Shadowthread Cave, in the northwest corner of Shadowglen. Lately they have grown more hostile, and the cave is far more dangerous.	Shadowthread_Cave
S	1439	ametharan	The ruins of Ameth'Aran lie southeast of Auberdine.	Ameth'Aran
S	1439	auberdine	Auberdine stands on a coast the Sundering made, where the sea ruined the great cities of the old night elf empire.	Auberdine
S	1439	masters glaive	A colossal skull lies in the southwest of Darkshore with an adamantine glaive driven through the bone.	Master's_Glaive
S	1439	mists edge	Gray beaches and gloomy bays make up Mist's Edge, the longest shoreline in Darkshore, running from near Auberdine to the region's northern tip.	Mist's_Edge
S	1439	remtravels excavation	Prospector Remtravel of the Explorers' League, a famed archaeologist, gave this dig its name.	Remtravel's_Excavation
S	1439	twilight vale	Twilight Vale takes in the forests south of Ameth'Aran, running to the border of Ashenvale.	Twilight_Vale
S	1440	astranaar	Astranaar stands on an island in the middle of a lake, joined to the shore by two bridges, with the main road running through it.	Astranaar
S	1440	blackfathom deeps	A temple to Elune, the night elves' moon goddess, once stood on the Zoram Strand.	Blackfathom_Deeps
S	1440	fallen sky lake	A small lake lies south of Silverwing Outpost, with a single island at its center.	Fallen_Sky_Lake
S	1440	splintertree post	Grommash Hellscream and his Warsong clan raised Splintertree Post during the Third War, when the orcs first ventured into Ashenvale.	Splintertree_Post
S	1440	xavian	Satyrs have made their home in the ruins of an ancient night elf temple in northeastern Ashenvale.	Xavian
S	1440	zoramgar outpost	Docks reach out over the water at Zoram'gar Outpost, a Horde port on the Zoram Strand. The Horde set it up here and fights the Wrathtail naga from it.	Zoram'gar_Outpost
S	1441	freewind post	Freewind Post stands on top of a mesa, out of reach of the Galak centaur war bands that camp below.	Freewind_Post
S	1441	highperch	On this elevated ground in the west, the proud Highperch wyverns keep their nests.	Highperch
S	1441	ironstone camp	A small band of the Horde camps at the border of the Shimmering Flats.	Ironstone_Camp
S	1441	mirage raceway	A goblin named Pozzik and a gnome named Fizzle Brassbolts each held that their own people were the better engineers.	Mirage_Raceway
S	1441	razorfen downs	Legend says that where the demigod Agamaggan fell, his blood raised great masses of thorny vines.	Razorfen_Downs
S	1441	roguefeather den	Harpies crowd this small cavern in south central Thousand Needles.	Roguefeather_Den
S	1442	blackwolf river	The Blackwolf River runs out of Cragpool Lake and through the valley of Windshear Crag. It is a small river, and a foul one.	Blackwolf_River
S	1442	boulderslide cavern	Boulderslide kobolds nest in this cave at the end of the ravine.	Boulderslide_Cavern
S	1442	malakajin	Darkspear trolls live in Malaka'jin, a small Horde village just south of Grimtotem Post. The hunters make a modest living selling their catches to Horde travelers who pass through.	Malaka'jin
S	1442	stonetalon peak	At the far northwestern end of the range, in a green mountain valley, stands Stonetalon Peak. The mountain is held sacred, and magic runs through its stone.	Stonetalon_Peak
S	1442	sun rock retreat	In ages past, tauren made pilgrimages to Sun Rock Retreat to perform the rites that cross into the spirit world, for the place has a strong bond with that realm.	Sun_Rock_Retreat
S	1442	webwinder path	Spiders, rams and thunder lizards live along the Webwinder Path, the main road between Malaka'jin and Mirkfallon Lake.	Webwinder_Path
S	1443	gelkis village	The Gelkis clan keeps its principal village in a ring around a wide ravine in southwestern Desolace.	Gelkis_Village
S	1443	kormeks hut	A small hovel stands on the barren flats of north-central Desolace. Inside lives Willow, a friendly member of the Twilight's Hammer.	Kormek's_Hut
S	1443	nijels point	The Alliance and the Cenarion Circle hold an outpost among night elf ruins in the northern mountains. No one there can say who Nijel was.	Nijel's_Point
S	1443	sartheris strand	The coast is the one part of Desolace with color. The interior is gray and gloomy, but here the grass is green and the sun comes out.	Sar'theris_Strand
S	1443	scrabblescrews camp	Smeed Scrabblescrew lives in a small goblin camp not far from the Kodo Graveyard. He is an enterprising goblin who keeps a caravan of kodo.	Scrabblescrew's_Camp
S	1443	shadowprey village	Darkspear trolls built this fishing village at the southern end of Desolace's coast, and they live by what the sea gives them.	Shadowprey_Village
S	1444	camp mojache	The tauren of Camp Mojache have built their village above Wildwind Lake, straddling a swift stream that runs down into it.	Camp_Mojache
S	1444	dire maul	Twelve thousand years ago a covert sect of night elf sorcerers raised Eldre'Thalas to guard Queen Azshara's most prized arcane secrets.	Dire_Maul
S	1444	feathermoon stronghold	General Shandris Feathermoon raised this fortress on Sardor Isle, off the western coast of Feralas, and it carries her name.	Feathermoon_Stronghold_(Classic)
S	1444	ruins of isildien	Ten thousand years ago a great night elf city in southwestern Feralas was destroyed.	Ruins_of_Isildien
S	1444	thalanaar	Where Feralas meets Thousand Needles stands Thalanaar, a tiny night elf camp held by the Alliance. Falfindel Waywarder is here, and he fights the Death's Head cult.	Thalanaar
S	1444	writhing deep	Hive Zukk'ash lies in the southeastern corner of Feralas, where silithid swarm up out of the ground.	Writhing_Deep
S	1445	bluefen	Bluefen is low marshland in the north of Dustwallow Marsh, near Brackenwall Village.	Bluefen
S	1445	brackenwall village	The Stonemaul ogres came to Brackenwall as refugees.	Brackenwall_Village
S	1445	emberstrifes den	A wide cave opens into the reeking Wyrmbog, home to the black drake Emberstrife.	Emberstrife's_Den
S	1445	foothold citadel	At the doors of Foothold Citadel, the guards of Theramore drill against practice dummies and young recruits spar with each other.	Foothold_Citadel
S	1445	theramore isle	During the Third War, Lady Jaina Proudmoore led the survivors of Lordaeron across the sea to Kalimdor.	Theramore_Isle
S	1445	tidefury cove	Treacherous water lies at the end of Dustwallow Bay, south of Theramore Isle.	Tidefury_Cove
S	1446	abyssal sands	The sands here lie within Tanaris, a desert reaching in every direction.	Abyssal_Sands
S	1446	broken pillar	The goblin scientist Marvon Rivetseeker has made his camp among a small group of troll ruins south of Gadgetzan.	Broken_Pillar
S	1446	gadgetzan	Profit above loyalty is the creed of Gadgetzan, capital of the Steamwheedle Cartel, the largest of the goblin cartels.	Gadgetzan
S	1446	steamwheedle port	Steamwheedle Port sits on the eastern coast of Tanaris, with a road running west to Gadgetzan, its mother city.	Steamwheedle_Port
S	1446	uldum	The titans left a holding in the southern part of the desert, the ancient city of Uldum, rich in their lore.	Uldum
S	1446	zulfarrak	Chief Ukorz Sandscalp rules Zul'Farrak, the Sandfury city in northwestern Tanaris. The Sandfury are known for their particular ruthlessness and dark mysticism.	Zul'Farrak
S	1447	bitter reaches	The northeast of Azshara is called the Bitter Reaches. Hippogryphs, oozes and chimaerae fill the land.	Bitter_Reaches
S	1447	lake mennar	The waters of Lake Mennar lie still at their center, though dragonspawn hold the ground on every side.	Lake_Mennar
S	1447	legash encampment|legashi encampment	Legashi satyrs hold this camp in northern Azshara, east of Ursolan and north of the Thalassian Base Camp.	Legash_Encampment
S	1447	shadowsong shrine	A hill covered in ruins in western Azshara bears the name Shadowsong.	Shadowsong_Shrine
S	1447	talrendis point	Night elves keep a small encampment at Talrendis Point, in southwestern Azshara on the border with Ashenvale. It began as a watch kept at the edge of the forest.	Talrendis_Point
S	1447	valormok	Valormok, a Horde outpost of orc warriors in northwestern Azshara, stands bare and lightly guarded. The Horde took little interest in this hostile land at first.	Valormok
S	1448	bloodvenom post	A small Horde outpost stands on the high cliffs above Darkshore, near the Bloodvenom River where it cuts through Felwood.	Bloodvenom_Post
S	1448	emerald sanctuary	Druids of the Emerald Circle keep a camp in southeastern Felwood. They work to snuff out the demonic corruption that spreads from Jaedenar.	Emerald_Sanctuary
S	1448	felpaw village	Felpaw Village stands at the far north of Felwood, near the entrance to Timbermaw Hold.	Felpaw_Village
S	1448	jadefire run	The most powerful satyrs in Felwood make their home in this encampment in the north of the forest.	Jadefire_Run
S	1448	morlosaran	Morlos'Aran was once a great night elf settlement, raised long before the Great Sundering. Now it lies in ruin at the southern edge of Felwood.	Morlos'Aran
S	1448	shadow hold	A gigantic labyrinth that was once a night elf barrow den lies within Jaedenar, in western Felwood.	Shadow_Hold
S	1449	fungal rock	A large cavern opens in the northeastern wall of Un'Goro Crater. Gorillas have made their home inside, among the ghost mushrooms.	Fungal_Rock
S	1449	golakka hot springs	Steam rises constantly from Golakka Hot Springs, a stretch of the western crater filled with pools and geysers heated by the nearby volcano.	Golakka_Hot_Springs
S	1449	ironstone plateau	Bare rock breaks through the green of Un'Goro in several stretches along the northeastern edge of the crater, tucked against the crater wall.	Ironstone_Plateau
S	1449	lakkari tar pits	Lakes of thick, foul-smelling black tar lie in the northern part of Un'Goro Crater. The tar traps creatures in its grip, and the bones of hundreds of beasts jut from its surface.	Lakkari_Tar_Pits
S	1449	marshals refuge	Marshal's Refuge sits at the northern edge of Un'Goro Crater, raised by the Marshal Expeditions under Williden Marshal and Hol'anyee Marshal.	Marshal's_Refuge
S	1449	slithering scar	The Gorishi, a sect of the silithid, hold most of the southern part of Un'Goro Crater with their hive. Wasps and workers swarm through it, guarded by reavers, stingers and tunnelers.	Slithering_Scar
S	1450	lake eluneara	Crystal water fills the heart of Moonglade, still as glass beneath the trees. The lake is named for Elune herself.	Lake_Elune'ara
S	1450	nighthaven	On the shore of Lake Elune'ara stands Nighthaven, a village of night elf stonework and a pair of moonwells, home to the druids of the Cenarion Circle.	Nighthaven
S	1450	shrine of remulos	Western Moonglade holds a shrine dedicated to Keeper Remulos, son of the demigod Cenarius and guardian of the valley.	Shrine_of_Remulos
S	1450	stormrage barrow dens	Beneath the quiet turf of Moonglade lie the barrow dens, sunk into earth that many night elf druids never truly leave, their bodies resting while their spirits wander the Emerald Dream.	Stormrage_Barrow_Dens
S	1450	timbermaw hold	The Timbermaw tribe of furbolgs keeps its capital in northeastern Felwood, and a tunnel through the hold leads out to Moonglade and Winterspring.	Timbermaw_Hold
S	1451	cenarion hold	Cenarion Hold stands in Silithus on the ground of an ancient night elf settlement. It is one of the biggest druid strongholds in Kalimdor, almost as large as Moonglade itself.	Cenarion_Hold
S	1451	hiveashi	A silithid hive lies in northern Silithus, and its brood has spread out to infest the Swarming Pillar.	Hive'Ashi
S	1451	hivezora	Out in western Silithus, a silithid nest lies burrowed into the sand, swarming with wasps, reavers, hive sisters, tunnelers and waywatchers.	Hive'Zora
S	1451	ortells hideout	Ortell, a hermit, makes his home in a small cave in southeastern Silithus.	Ortell's_Hideout
S	1451	southwind village	Southwind Village was a night elf base until the Qiraji swarmed over it in the War of the Shifting Sands.	Southwind_Village
S	1451	twilights run	Twilight's Run lies hidden in the rock at the base of Staghelm Point, in northern Silithus.	Twilight's_Run
S	1452	darkwhisper gorge	When Archimonde fell at the Battle of Mount Hyjal, the demons of the Burning Legion who survived did not vanish.	Darkwhisper_Gorge
S	1452	dun mandarr	Dun Mandarr is a small camp beside an icy cavern in southeastern Winterspring.	Dun_Mandarr
S	1452	everlook	Goblins of the Steamwheedle Cartel run Everlook, a trading post where Winterspring's main trade routes cross.	Everlook
S	1452	frostwhisper gorge	Night elf ruins lie scattered across the floor and ridges of Frostwhisper Gorge, a canyon in southern Winterspring.	Frostwhisper_Gorge
S	1452	lake keltheril	The frozen waters of Lake Kel'Theril lie still in the middle of Winterspring, ringed by old Highborne ruins that carry its name.	Lake_Kel'Theril
S	1452	timbermaw post	The name says Timbermaw, but the small furbolg camp at Timbermaw Post belongs to the corrupted Winterfall tribe, who hold it completely.	Timbermaw_Post
S	1453	champions hall	In the south of Old Town, the officers of the Alliance keep their barracks in the Champions' Hall.	Champions'_Hall
S	1453	deeprun tram	After the Second War the dwarves of Ironforge hurried to help their human allies rebuild Stormwind, but King Magni Bronzebeard thought the aid came too slowly.	Deeprun_Tram
S	1453	valley of heroes	A stone bridge crosses the moat before Stormwind's gate and leads into a lush green valley. Five great statues stand along the road.	Valley_of_Heroes
S	1454	hall of legends	The Horde's officers keep their barracks in the Hall of Legends.	Hall_of_Legends
S	1454	ragefire chasm	Beneath Orgrimmar the earth opens into a chasm of lava and smoke. Troggs have begun to climb out of the deep tunnels, a clan the Horde calls the Ragefire troggs.	Ragefire_Chasm
S	1455	deeprun tram	Two sets of three wagons run on double tracks between Ironforge and Stormwind, passing partly under the water of a subterranean lake.	Deeprun_Tram
S	1455	gates of ironforge	The Gates of Ironforge rise where the great ramp of central Dun Morogh climbs to meet the mountain, a grand sight visible for miles across the snow.	Gates_of_Ironforge
S	1456	elder rise	The Council of Elders governs from Elder Rise, which lies directly east of the central bluff, and the Cenarion Circle makes its home here among the tauren druids and priests.	Elder_Rise
S	1456	hunter rise	The southern rise of Thunder Bluff belongs to those who hunt and fight.	Hunter_Rise
S	1456	pools of vision	In a tunnel system just below the cap of Spirit Rise, the Forsaken keep a foothold deep in tauren country.	Pools_of_Vision
S	1456	spirit rise	Shamans study on Spirit Rise, northwest of the central bluff, and the Skychaser tribe holds great influence here. The steamy Pools of Vision lie below the surface of the mesa.	Spirit_Rise
S	1457	cenarion enclave	In the northwest of Darnassus, the Cenarion Enclave rings a grove where oaks and ashes stand taller than the halls of stone elsewhere in the city.	Cenarion_Enclave
S	1457	craftsmens terrace	The Craftsmen's Terrace lies in the north of Darnassus.	Craftsmen's_Terrace
S	1457	temple gardens	At the heart of Darnassus lie the Temple Gardens, an expanse of water, walkways and small islands named for the Temple of the Moon that rises just to the south.	Temple_Gardens
S	1457	tradesmens terrace	Most of the shopkeepers and merchants of Darnassus keep to the Tradesmen's Terrace in the south of the city.	Tradesmen's_Terrace
S	1457	warriors terrace	The eastern gate of Darnassus, where the city opens onto the wilds of Teldrassil, stands on the Warrior's Terrace, also called the Hall of Justice.	Warrior's_Terrace
S	1458	ruins of lordaeron	Above the buried city the palace of Lordaeron still stands, its halls open to the sky and its gardens gone to ruin.	Ruins_of_Lordaeron
S	2652	valley of bones	Skeletons crowd this crag on the southern border of Desolace, the way on foot into Shen'dralas, and centaur necromancers walk among them.	Valley_of_Bones
]]
if ns.KEEP_STRINGS then
	ns.LORE_RAW = { fr = FR, en = EN }
else
	ns.LORE_RAW = { [ns.STRINGS_FRENCH ~= false and "fr" or "en"] = ns.STRINGS_FRENCH ~= false and FR or EN }
end
