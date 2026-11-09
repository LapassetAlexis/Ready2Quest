-- MusicData.lua -- catalogue du Juke-box (QuestCompanion 2.12.0)
--
-- FICHIER GÉNÉRÉ par tools/gen_music.py depuis data/forever/music.json, ne
-- pas éditer à la main. Source : wago.tools (tables du client, fichiers CASC), client 1.60.1.70753,
-- relevé le 2026-11-09. Aucun son livré : des FileDataID du client, joués par PlayMusic.
local ADDON, ns = ...
if ns.blocked then return end

-- Lus en tables à la première ouverture du Juke-box (ns:MusicCatalog, Jukebox.lua),
-- puis libérés. Champs séparés par une tabulation.
-- ns.MUSIC_GROUPS : une ligne par groupe (n° = rang de la ligne) : nom français,
--   nom anglais (vide = le français), zones qui le jouent (AreaID, « , »).
-- ns.MUSIC_RAW[catégorie] : une ligne par piste : FileDataID, durée en s (0 =
--   inconnue), n° du groupe, suffixe du nom (rang ou lieu), titre d'origine (ID3).
ns.MUSIC_CATEGORIES = { "zones", "cities", "dungeons", "raids", "taverns", "forever", "moments", "themes" }
ns.MUSIC_GROUPS = [[
Forêt, jour	Forest, day	12,36,38,44,47,267,293,308
Forêt maudite, jour	Evil forest, day	10,22,41,85,130,170,209,16114
Forêt maudite, nuit	Evil forest, night	10,22,41,85,130,170,209,16114
Jungle, jour	Jungle, day	33,330,357,1477,1977,16018,16117
Jungle, nuit	Jungle, night	33,330,357,1477,1977,16018,16117
Terres arides, nuit	Barrens, night	3,4,17,406,1637,2100,16017,16115
Terres arides	Barrens	3,4,17,406,1637,2100,2159,15531
Montagne, jour	Mountain, day	1,21,45,618
Montagne, nuit	Mountain, night	1,21,45,618
Plaines, nuit	Plains, night	14,40,206,207,214,215,332,377
Plaines, jour	Plains, day	14,40,206,207,214,215,332,377
Volcans, jour	Volcanic, day	25,46,51,16508
Volcans, nuit	Volcanic, night	25,46,51,16508
Forêt enchantée	Enchanted forest	141,331,495,2557,16169
Hanté	Haunted	2057,15828
Monde des esprits	Spirit world	
Désert, jour	Desert, day	405,440,719,1176,1377,3478,16532
Désert, nuit	Desert, night	405,440,719,1176,1377,3478,16532
Forêt, nuit	Forest, night	148,493
Terres maudites	Cursed land	16,28,139,361,796,2597,15475,15809
Magie	Magic	
Marais	Swamp	8,11,15,490,16116
Hurlevent, ouverture	Stormwind, intro	
Hurlevent	Stormwind	1519,16509
Orgrimmar		
Orgrimmar, ouverture	Orgrimmar, intro	
Darnassus, ouverture	Darnassus, intro	
Darnassus		1657,15938
Fossoyeuse	Undercity	16611
Fossoyeuse, ouverture	Undercity, intro	
Les Pitons-du-Tonnerre, ouverture	Thunder Bluff, intro	
Les Pitons-du-Tonnerre	Thunder Bluff	151,1638
Brikabrok, ouverture	Tinker Town, intro	
Forgefer, ouverture	Ironforge, intro	
Forgefer	Ironforge	
Gnomeregan		
Mystère	Mystery	1581,16919
Hyjal (passé)	Hyjal (past)	
Cryptes de Karazhan	Karazhan Crypts	
Dalaran		16544,16560
Terrasse du Façonneur	The Shaper's Terrace	
Cité engloutie	Drowned City	
Donjon : forêt	Dungeon: forest	
Donjon : paluns	Dungeon: wetlands	16732
Donjon : araignées	Dungeon: spiders	
Donjon : alpin	Dungeon: alpine	
Donjon : combat de boss	Dungeon: boss battle	
Donjon : horreur	Dungeon: horror	
Donjon : souterrain, percussions	Dungeon: underground, percussion	
Donjon : ruines	Dungeon: ruins	
Zul'Gurub		
Ahn'Qiraj		3428,3429
Naxxramas		
Enclave Écarlate	Scarlet Enclave	16236
Taverne de l'Alliance	Alliance tavern	
Taverne de la Horde	Horde tavern	
Taverne naine	Dwarven tavern	
Taverne humaine	Human tavern	
Taverne pirate	Pirate tavern	
Taverne mort-vivante	Undead tavern	
Mont Hyjal	Mount Hyjal	616,16004,16611
Riverglades		16591
Île de Zephras	Zephras Isle	16593
Sacré	Sacred	
Marais	Swamp	
Angélique	Angelic	
Sinistre	Spooky	
Hanté	Haunted	
Magie	Magic	457
Morose	Gloomy	
Bataille	Battle	3358
Champs de bataille	Battlegrounds	3277,16603,16606
Foire de Sombrelune	Darkmoon Faire	
Thème principal de World of Warcraft	World of Warcraft main theme	
]]
ns.MUSIC_RAW = {
zones = [[
8180778	57	1	1	Day Forest 01
8180780	73	1	2	Day Forest 02
8180782	66	1	3	Day Forest 03
8180772	72	2	1	Day Evil Forest 01
8180774	74	2	2	Day Evil Forest 02
8180776	72	2	3	Day Evil Forest 03
8180758	59	3	1	Night Evil Forest 01
8180760	76	3	2	Night Evil Forest 02
8180762	72	3	3	Night Evil Forest 03
8181259	46	4	1	Day Jungle 01
8181261	100	4	2	Day Jungle 02
8181263	48	4	3	Day Jungle 03
8181265	54	5	1	Night Jungle 01
8181267	53	5	2	Night Jungle 02
8181269	88	5	3	Night Jungle 03
8181055	67	6	1	Night Barren Dry 01
8181057	42	6	2	Night Barren Dry 02
8181059	47	6	3	Night Barren Dry 03
8181049	65	7	1	Dry Barren Dry 01
8181051	62	7	2	Dry Barren Dry 02
8181053	55	7	3	Dry Barren Dry 03
8181287	120	8	1	Day Mountain 01
8181289	67	8	2	Day Mountain 02
8181291	79	8	3	Day Mountain 03
8181293	63	9	1	Night Mountain 01
8181295	64	9	2	Night Mountain 02
8181297	71	9	3	Night Mountain 03
8181299	63	9	4	Night Mountain 04
8181309	59	10	1	Night Plains 01
8181311	70	10	2	Night Plains 02
8181305	54	11	1	Day Plains 01
8181307	77	11	2	Day Plains 02
8181275	73	12	1	Day Volcanic 01
8181277	87	12	2	Day Volcanic 02
8181279	76	13	1	Night Volcanic 01
8181281	64	13	2	Night Volcanic 02
8180784	50	14	1	Enchanted Forest 01
8180786	66	14	2	Enchanted Forest 02
8180788	235	14	3	Enchanted Forest 03
8180790	61	14	4	Enchanted Forest 04
8180792	72	14	5	Enchanted Forest 05
8181313	63	15		Haunted 01
8181321	62	16		Ghost Music 03
8181127	65	17	1	Day Desert 01
8181129	82	17	2	Day Desert 02
8181131	54	17	3	Day Desert 03
8181133	77	18	1	Night Desert 01
8181135	62	18	2	Night Desert 02
8181137	55	18	3	Night Desert 03
8180764	52	19	1	Night Forest 01
8180766	44	19	2	Night Forest 02
8180768	62	19	3	Night Forest 03
8180770	54	19	4	Night Forest 04
8180738	56	20	1	Cursed Land 01
8180740	57	20	2	Cursed Land 02
8180742	65	20	3	Cursed Land 03
8180744	80	20	4	Cursed Land 04
8180746	83	20	5	Cursed Land 05
8180748	74	20	6	Cursed Land 06
8286132	65	20	7	Terrokar Bone Wastes Walking 1
8286134	63	20	8	Terrokar Bone Wastes Walking 2
8286136	56	20	9	Terrokar Bone Wastes Walking 3
8286138	190	20	10	Terrokar Bone Wastes Walking 4
8180993	27	20	11	Undead Dance
8180955	34	21	1	Magic 01 Zone 1
8180957	40	21	2	Magic 01 Zone 2
8181011	100	22	1	Soggy Place Zone 01
8181013	98	22	2	Soggy Place Zone 02
8181015	90	22	3	Soggy Place Zone 03
8181017	89	22	4	Soggy Place Zone 04
8181019	71	22	5	Soggy Place Zone 05
]],
cities = [[
8180884	68	23		Stormwind Intro Moment
8180866	56	24	1	Stormwind 01 Moment
8180868	37	24	2	Stormwind 02 Moment
8180870	70	24	3	Stormwind 03 Moment
8180872	64	24	4	Stormwind 04 Zone
8180874	61	24	5	Stormwind 05 Zone
8180876	54	24	6	Stormwind 06 Zone
8180878	88	24	7	Stormwind 07 Zone
8180880	77	24	8	Stormwind 08 Zone
8180882	135	24	9	Stormwind High Seas Moment
53200	62	25	1	
8181031	69	25	2	Orgrimmar 01 Moment
8181033	70	25	3	Orgrimmar 01 Zone
8181035	62	25	4	Orgrimmar 02 Moment
8181037	62	25	5	Orgrimmar 02 Zone
8181039	41	26		Orgrimmar Intro Moment
8180750	42	27		Darnassus Intro
8180752	86	28	1	Darnassus Walking 1
8180754	70	28	2	Darnassus Walking 2
8180756	68	28	3	Darnassus Walking 3
8181323	46	28	4	Druid Grove
8181337	55	28	5	Warrior Terrace
8181003	68	29	1	Undercity 01 Zone
8181005	87	29	2	Undercity 02 Zone
8181007	75	29	3	Undercity 03 Zone
8181009	29	30		Undercity Intro Moment
8180995	46	31		Thunderbluff Intro
8180997	113	32	1	Thunderbluff Walking 01
8180999	115	32	2	Thunderbluff Walking 02
8181001	120	32	3	Thunderbluff Walking 03
8181317	53	33		Tinkertown Intro Moment
8180963	86	34		Iron Forge Intro
53194	81	35	1	
8180965	119	35	2	Iron Forge Walking 01
8180967	50	35	3	Iron Forge Walking 02
8180971	71	35	4	Iron Forge Walking 04
8181329	66	36	1	Gnomeragon 01 Zone
8181331	66	36	2	Gnomeragon 02 Zone
]],
dungeons = [[
8180933	62	37	1	Mystery 01 Zone
8180935	54	37	2	Mystery 02 Zone
8180937	61	37	3	Mystery 03 Zone
8180939	65	37	4	Mystery 04 Zone
8180941	82	37	5	Mystery 05 Zone
8180943	66	37	6	Mystery 06 Zone
8180945	84	37	7	Mystery 07 Zone
8180947	84	37	8	Mystery 08 Zone
8180949	82	37	9	Mystery 09 Zone
8180951	63	37	10	Mystery 10 Zone
8285931	50	38	1	HyjalExtWalk11Uni
8285933	68	38	2	HyjalExtWalk12Uni
8285919	70	38	3	HyjalExtWalk1Uni
8285921	48	38	4	HyjalExtWalk2Uni
8285923	45	38	5	HyjalExtWalk3Uni
8285925	85	38	6	HyjalExtWalk4Uni
8285927	47	38	7	HyjalExtWalk5Uni
8285929	46	38	8	HyjalExtWalk6Uni
6653571	186	39	1	Karzhan Crypts
6653573	182	39	2	Karzhan Crypts
6653575	162	39	3	Karzhan Crypts
8285938	68	40	1	Dalaran 1
8285940	43	40	2	Dalaran 2
8285942	70	40	3	Dalaran 3
8285944	89	40	4	Dalaran 4
8285946	69	40	5	Dalaran Intro
8451330	67	40	6	Dalaran Sewer 1
8451332	102	40	7	Dalaran Sewer 2
8451334	72	40	8	Dalaran Sewer 3
8451336	65	40	9	Dalaran Sewer 4
8451379	92	40	10	Dalaran Spire
8286116	112	41	1	Sholazar Walk Day 04
8286118	123	41	2	Sholazar Walk Day 05
8286120	142	41	3	Sholazar Walk Day 06
8286122	115	41	4	Sholazar Walk Night 01
8286124	138	41	5	Sholazar Walk Night 02
8286126	132	41	6	Sholazar Walk Night 03
8286128	92	41	7	Sholazar Walk Night 04
8286130	100	41	8	Sholazar Walk Night 05
8200642	136	42	1	
8200644	41	42	2	
8200646	92	42	3	
8200648	80	42	4	
8200650	117	42	5	
8200652	103	42	6	
8200654	74	42	7	
8200656	150	42	8	
8200658	73	42	9	
8200660	99	42	10	
8200674	78	42	11	
8200676	93	42	12	
8200678	91	42	13	
8200680	102	42	14	
8200682	18	42	15	
8200684	79	42	16	
8200686	87	42	17	
8200688	53	42	18	
8200690	114	42	19	
8200692	74	42	20	
8200694	109	42	21	
8200696	70	42	22	
8200662	154	42	23	Stereo Out
8200666	69	42	24	Stereo Out
8200668	108	42	25	Stereo Out
8200670	125	42	26	Stereo Out
8270371	66	43	1	Dungeons Forest A
8270373	64	43	2	Dungeons Forest B
8270375	54	43	3	Dungeons Forest C
8270377	60	43	4	Dungeons Forest D
8270379	66	44	1	Dungeons Wetlands A
8270381	62	44	2	Dungeons Wetlands B
8270383	63	44	3	Dungeons Wetlands C
8270385	62	44	4	Dungeons Wetlands D
8270576	126	45	1	Nerubian Nest C
8270578	129	45	2	Nerubian Nest E
8270580	194	45	3	Silken Path A
8270582	180	45	4	Silken Path E
8270584	136	45	5	Weaver's Lair C
8280452	77	46	1	Dungeons Alpine A
8280454	58	46	2	Dungeons Alpine B
8280456	64	46	3	Dungeons Alpine C
8280458	60	46	4	Dungeons Alpine D
8280857	66	47	1	Dungeons Battle Boss A
8284574	65	47	2	Dungeons Battle Boss B
8280873	65	47	3	Dungeons Battle Boss C
8284576	59	47	4	Dungeons Battle Boss D
8280849	69	48	1	Dungeons Horror A
8280851	62	48	2	Dungeons Horror B
8280853	84	48	3	Dungeons Horror C
8280855	62	48	4	Dungeons Horror D
8281552	63	49	1	Dungeons Underground Percussive A
8281554	54	49	2	Dungeons Underground Percussive B
8281556	65	49	3	Dungeons Underground Percussive C
8281558	84	49	4	Dungeons Underground Percussive D
8284598	66	50	1	Dungeons Ruins A
8284600	72	50	2	Dungeons Ruins B
8284602	64	50	3	Dungeons Ruins C
8284604	59	50	4	Dungeons Ruins D
]],
raids = [[
8181341	85	51		Zul'Gurub Voodoo
53239	144	52	1	Ahn Qiraj Theme
8176626	68	52	2	Ahn'Qiraj Exterior Walking 1
8176628	85	52	3	Ahn'Qiraj Exterior Walking 2
8176630	59	52	4	Ahn'Qiraj Exterior Walking 3
8176632	60	52	5	Ahn'Qiraj Exterior Walking 4
8176671	53	52	6	Ahn'Qiraj Interior 1
8176673	83	52	7	Ahn'Qiraj Interior 2
8176675	68	52	8	Ahn'Qiraj Interior 3
8176681	70	52	9	Ahn'Qiraj Interior Center Room 1
8176683	70	52	10	Ahn'Qiraj Interior Intro Main
8176685	74	52	11	Ahn'Qiraj King Room
8176689	24	52	12	Ahn'Qiraj Triangle Room 1
8176691	18	52	13	Ahn'Qiraj Triangle Room 2
8176693	16	52	14	Ahn'Qiraj Triangle Room 3
8176695	20	52	15	Ahn'Qiraj Triangle Room 4
8176697	32	52	16	Ahn'Qiraj Triangle Room 5
8176699	21	52	17	Ahn'Qiraj Triangle Room 6
8176701	19	52	18	Ahn'Qiraj Triangle Room 7
53591	61	53	1	AbominationBoss1
53592	67	53	2	AbominationBoss2
53593	61	53	3	AbominationWing1
53594	67	53	4	AbominationWing2
53595	61	53	5	AbominationWing3
53596	58	53	6	Frostwyrm1
53597	82	53	7	Frostwyrm2
53598	62	53	8	Frostwyrm3
53599	60	53	9	Frostwyrm4
53602	95	53	10	KelThuzad1A
53603	97	53	11	KelThuzad2A
53604	76	53	12	KelThuzad3A
8180911	102	53	13	Naxxramas Walking 01
8180913	72	53	14	Naxxramas Walking 02
8180915	89	53	15	Naxxramas Walking 03
8180917	83	53	16	Naxxramas Walking 04
8180919	100	53	17	Naxxramas Walking 05
8180921	100	53	18	Naxxramas Walking 06
53605	87	53	19	PlagueBoss1
53606	88	53	20	PlagueWing1
53607	72	53	21	PlagueWing2
53608	77	53	22	PlagueWing3
53609	60	53	23	SpiderBoss1
53610	64	53	24	SpiderBoss2
53611	89	53	25	SpiderWing1
53612	68	53	26	SpiderWing2
53613	47	53	27	SpiderWing3
53240	61	54	1	
53241	54	54	2	
6865468	214	54	3	
6865470	134	54	4	
6865472	134	54	5	
6865474	76	54	6	
6865476	76	54	7	
6865478	76	54	8	
6865480	76	54	9	
6865482	76	54	10	
6865484	140	54	11	
6865486	140	54	12	
6865488	67	54	13	Assault 4
6865490	118	54	14	Assault 5
6865492	94	54	15	Assault 6
6865494	96	54	16	Assault 7
6865498	79	54	17	Ebon Hold 2
6865500	82	54	18	Ebon Hold 3
6861009	83	54	19	Scarlet Monastery 1H
6861011	54	54	20	Scarlet Monastery 2H
6861013	118	54	21	Scarlet Monastery 3H
53242	61	54	22	mystery03-zone
53243	64	54	23	mystery04-zone
53244	82	54	24	mystery05-zone
53245	65	54	25	mystery06-zone
53246	83	54	26	mystery07-zone
53247	83	54	27	mystery08-zone
53249	62	54	28	mystery10-zone
]],
taverns = [[
8180983	48	55	1	Tavern Alliance 01
8180985	52	55	2	Tavern Alliance 02
8195273	99	56	1	Orc Rest Area 1A
8195275	91	56	2	Orc Rest Area 1B
8195277	87	56	3	Orc Rest Area 2A
8195279	86	56	4	Orc Rest Area 2B
8195281	85	56	5	Orc Rest Area 3A
8195283	81	56	6	Orc Rest Area 3B
8180987	49	56	7	Tavern Horde 01
8180989	40	56	8	Tavern Horde 02
8180991	48	56	9	Tavern Horde 03
8195263	80	57	1	Dwarves Tavern 1A
8195265	82	57	2	Dwarves Tavern 1B
8195267	86	57	3	Dwarves Tavern 2A
8195269	91	57	4	Dwarves Tavern 2B
8195271	103	57	5	Dwarves Tavern 3
8180975	93	58	1	Human Tavern 1A
8180977	79	58	2	Human Tavern 1B
8180979	86	58	3	Human Tavern 2A
8180981	81	58	4	Human Tavern 2B
8195285	83	59	1	Pirate Tavern 1A
8195287	81	59	2	Pirate Tavern 1B
8195289	83	59	3	Pirate Tavern 2A
8195291	80	59	4	Pirate Tavern 2B
8195293	88	59	5	Pirate Tavern 3A
8195295	84	59	6	Pirate Tavern 3B
8180923	92	60	1	Undead Tavern 1A
8180925	88	60	2	Undead Tavern 1B
8180927	124	60	3	Undead Tavern 2
8180929	82	60	4	Undead Tavern 3A
8180931	94	60	5	Undead Tavern 3B
]],
forever = [[
8173701	47	61	Cradle of Tranquility A	
8173703	72	61	Cradle of Tranquility B	
8175594	68	61	Cradle of Tranquility C	
8198465	66	61	Dae'gun A	
8198467	66	61	Dae'gun B	
8269348	54	61	Daegun C	
8269350	64	61	Daegun D	
8197333	72	61	Elderwild A	
8197335	72	61	Elderwild B	
8197337	72	61	Elderwild C	
8173707	54	61	Felblood Scar A	
8269356	53	61	Felblood Scar B	
8269358	63	61	Felblood Scar C	
8158670	49	61	Hyjal General A	
8158672	51	61	Hyjal General B	
8158674	62	61	Hyjal General C	
8173713	54	61	Hyjal General D	
8190628	64	61	Marlorne's Retreat A	
8190630	64	61	Marlorne's Retreat B	
8190632	57	61	Marlorne's Retreat C	
8190634	43	61	Marlorne's Retreat D	
8190636	52	61	Marlorne's Retreat E	
8190638	52	61	Marlorne's Retreat F	
8158676	52	61	Mourning's Rest A	
8158678	51	61	Mourning's Rest B	
8158680	67	61	Mourning's Rest C	
8282397	91	61	Shrine of Aviana A	
8282399	71	61	Shrine of Aviana B	
8281865	76	61	Shrine of Aviana C	
8281867	51	61	Shrine of Aviana D	
8158682	50	61	Summit of Eternity A	
8158684	39	61	Summit of Eternity B	
8282581	51	61	Summit of Eternity C	
8158686	56	61	Summit of Eternity Intro	
8269360	76	61	Tainted Foothills A	
8269362	56	61	Tainted Foothills B	
8269364	59	61	Tainted Foothills C	
8158694	64	62	Bolder'ok A	
8158696	50	62	Bolder'ok B	
8158698	63	62	Bolder'ok C	
8158700	42	62	Bolder'ok D	
8158702	86	62	Eastwind Shore A	
8158704	84	62	Eastwind Shore B	
8158706	100	62	Eastwind Shore C	
8158708	75	62	Farholde Keep A	
8158710	83	62	Farholde Keep B	
8269352	58	62	Farholde Keep C	
8269354	74	62	Farholde Keep D	
8173705	61	62	Farholde Keep Intro	
8158714	57	62	General A	Riverglades General A
8158716	47	62	General B	Riverglades General B
8158718	63	62	General C	Riverglades General C
8173715	62	62	General D	Riverglades General D
8173717	68	62	General E	Riverglades General E
8204579	46	62	Goblin 11	
8204581	48	62	Goblin 13	
8204583	47	62	Goblin 15	
8204585	85	62	Goblin 18	
8204587	18	62	Goblin 30	
8204589	16	62	Goblin 33	
8158720	65	62	Rog'mar Outpost A	
8158722	66	62	Rog'mar Outpost B	
8158724	48	62	Rog'mar Outpost C	
8158726	40	62	Rog'mar Outpost D	
8173719	79	62	Sunnyglade A	
8173721	65	62	Sunnyglade B	
8173723	55	62	Sunnyglade C	
8158728	68	62	Twilight's Shroud A	
8158730	66	62	Twilight's Shroud B	
8269366	70	62	Twilight's Shroud C	
8269368	53	62	Twilight's Shroud D	
8158732	80	62	Wheeler's Grange A	
8158734	64	62	Wheeler's Grange B	
8158736	78	62	Wheeler's Grange C	
8158738	74	63	Gustberry Lowlands A	
8158740	77	63	Gustberry Lowlands B	
8246678	58	63	Gustberry Lowlands C	
8246680	72	63	Gustberry Lowlands D	
8158742	68	63	Shadowgale Forest A	
8158744	67	63	Shadowgale Forest B	
8246682	74	63	Shadowgale Forest C	
8158746	73	63	Shendar Hub A	
8158748	68	63	Shendar Hub B	
8246684	68	63	Shendar Hub C	
8246686	54	63	Shendar Hub D	
8158750	64	63	Shrine of A'kir A	
8158752	64	63	Shrine of A'kir B	
8246688	53	63	Shrine of Akir C	
8246690	64	63	Shrine of Akir D	
441744	159	63	Skywall01	MUS_Skywall01
441753	110	63	Skywall10	MUS_Skywall10
8158754	72	63	Thendal Village A	
8158756	77	63	Thendal Village B	
8246692	47	63	Thendal Village C	
8246694	77	63	Thendal Village D	
575699	55	63	Twilight Hammer Intro V2	Twilight_Hammer_Intro_V2
8175596	54	63	Valanaar A	
8175598	53	63	Valanaar B	
8175600	32	63	Valanaar C	
8175602	53	63	Valanaar Intro	
]],
moments = [[
8181301	16	64	1	Sacred 01
8181303	20	64	2	Sacred 02
8181335	29	65		Swamp 01
8181319	48	66		Angelic 01
8181333	26	67		Spooky 01 Moment
8181315	60	68		Haunted 02
8180953	66	69		Magic 01 Moment
8181325	38	70	1	Gloomy 01
8181327	41	70	2	Gloomy 02
8180899	49	71	1	Battle 01
8180901	63	71	2	Battle 02
8180903	28	71	3	Battle 03
8180905	37	71	4	Battle 04
8180907	45	71	5	Battle 05
8180909	63	71	6	Battle 06
8181021	47	72	1	PvP 1
8181023	53	72	2	PvP 2
8181025	37	72	3	PvP 3
8181027	62	72	4	PvP 4
8181029	62	72	5	PvP 5
]],
themes = [[
53257	74	73		DMFaire_2
53223	161	74		
]],
}

if ns.Mark then ns.Mark("MusicData") end
