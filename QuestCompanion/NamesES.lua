-- NamesES.lua -- noms espagnols des créatures, quêtes et objets de nos tables
--
-- FICHIER GÉNÉRÉ par tools/gen_names_es.py depuis data/forever/names_es.json,
-- ne pas éditer à la main. Source : Questie/QuestieDB (GPL-3.0, voir
-- NOTICE.md), l10n/Forever esES et esMX. Seul un client espagnol garde ces
-- noms ; le Mexique prend son nom quand il diffère (deuxième colonne).
-- ns.SpanishName(kind, id) : "npc" | "quest" | "item" -> nom, ou nil.
local ADDON, ns = ...
if ns.blocked then return end
if not (ns.STRINGS_SPANISH or ns.KEEP_STRINGS) then return end

local MX = rawget(_G, "GetLocale") and GetLocale() == "esMX"
local RAW = {
	npc = [[
3	Comecarnes	
6	Alimaña kóbold	
30	Araña del bosque	
36	Gólem de la cosecha	
38	Matón Defias	
40	Minero klbold	Minero kóbold
43	Araña minera	
46	Batidor múrloc	
48	Guerrero esquelético	
60	Ruklar el Trampero	
61	Thuros Dedoluz	
69	Lobo maderero	Lobo gris
79	Narg el Capataz	
80	Obrero kóbold	
92	Elemental de piedra	Elemental de roca
94	Cortapurso Defias	
95	Contrabandista Defias	
97	Jabato Zarparrío	Cachorro Zarparrío
98	Capataz Zarparrío	
99	Morgaine el Astuto	
100	Bronco Mordeveloz	
103	Garrick Piesuaves	
113	Jabalí colmillopétreo	Jabalí Colmipétreo
114	Vigilante de la cosecha	Vigía de la cosecha
115	Segador de la cosecha	
116	Bandido Defias	
117	Gnoll Zarparrío	
118	Merodeador	
119	Morrolargo	
121	Acechacaminos Defias	
122	Bandolero Defias	
123	Bastardo Zarparrío	
124	Tosco Zarparrío	
125	Sobrestante Zarparrío	
126	Correcostas múrloc	
127	Cazamareas múrloc	
154	Desgarrador mayor	Desgarrador superior
157	Dentosangre	
171	Guerrero múrloc	
193	Dragauro azul	
199	Desgarrador joven	
202	Horror esquelético	
203	Mago esquelético	
205	Sombracechador Penumbría	
206	Colmillovil Penumbría	
210	Masticahuesos Oseral	
212	Guerrero Puñastilla	
213	Lobo feroz hambriento	
215	Noctámbulo Defias	
217	Telarácnida venenosa	
218	Asaltatumbas	
232	Granjero Ray	
257	Trabajador kóbold	
285	Múrloc	
299	Lobo joven	
314	Eliza	
315	Stalvan Mantoniebla	
325	Hogan Ference	
327	Dentdoro	Dientes de Oro
330	Princesa	
334	Gath'Ilzogg	
335	Brasillas	
345	Panzallena	
390	Séquito porcino	
391	Viejo Ojosombrío	
397	Morganth	
422	Comecarnes múrloc	
423	Bastardo de Crestagrana	
424	Furtivo de Crestagrana	
426	Tosco de Crestagrana	
428	Cóndor temible	
429	Tejeoscuro Pielsombra	
430	Místico de Crestagrana	
431	Destripador Pielsombra	
432	Tosco Pielsombra	
433	Gnol Pielsombra	
434	Gnoll Pielsombra rabioso	
435	Campeón Roca Negra	
436	Nigromante Roca Negra	
437	Renegado Roca Negra	
440	Bruto Roca Negra	
441	Cría de dragón Negro	
442	Tarantula	
445	Alfa de Crestagrana	
446	Partecaras de Crestagrana	
448	Hogger	
449	Sacudillo Defias	
450	Mago renegado Defias	
452	Bandido Zarparrío	
453	Místico Zarparrío	
454	Dentosangre joven	
456	Oráculo menor múrloc	
458	Cazador múrloc	
462	Vultros	
468	Pregonero del pueblo	
471	Madre Colmillo	
472	Fedfennel	
473	Morgan el Coleccionista	
474	Zahorí bribón Defias	Zahorí bribón de Defias
475	Tunelador kóbold	
476	Geomántico kóbold	
478	Avanzado Zarparrío	
480	Gólem oxidado de la cosecha	Gólem de la cosecha oxidado
481	Asaltante de caminos Defias	
485	Avanzado Roca Negra	
486	Tharil'zun	
500	Explorador Zarparrío	
501	Herborista Zarparrío	
502	Benny Blaanco	
503	Lord Malathrom	
504	Trampero Defias	
505	Tarántula superior	
506	Sargento Garravil	
507	Fenros	
511	Necrófago demente	
513	Redista múrloc	
515	Asaltante múrloc	
517	Oráculo múrloc	
518	Ululante	
519	Eslarc	
520	Brack	
521	Lupos	
522	Mor'Ladim	
524	Jabalí Ocultorroca	Jabalí Pielroca
525	Lobo sarnoso	
531	Mefisto esquelético	
533	Tejesombras Penumbría	
534	Nefaru	
539	Telarácnida venenosa pigmea	
544	Reptanoches múrloc	
545	Llamamareas múrloc	
547	Gran dentosangre	
548	Llamamareas menor múrloc	
550	Mensajero Defias	
565	Lobo temible rabioso	
568	Guerrero Pielsombra	
569	Ermitaña verde	
570	Comesesos	
572	Leprithus	
573	Siegaenemigos 4000	
574	Naraxis	
578	Explorador múrloc	
579	Asesino Pielsombra	
580	Esclavo de Crestagrana	
583	Emboscador Defias	
584	Kazon	
587	Guerrero Cabellesangre	Guerrero Sangrapellejo
588	Explorador Cabellesangre	Explorador Sangrapellejo
589	Saqueador Defias	
590	Despojador Defias	
594	Esbirro Defias	Secuaz Defias
595	Cazador Cabellesangre	Cazador Sangrapellejo
596	Noble aducido	
597	Rabioso Cabellesangre	Rabioso Sangrapellejo
599	Marisa du'Paige	
604	Propagador de la Peste	
615	Rastreador Roca Negra	
616	Castañeta	
619	Adjurador Defias	Conjurador Defias
623	Minero esquelético	
624	Excavador no-muerto	
625	Dinamitador no-muerto	
626	Supervisor Cardortiga	
628	Devastador negro	
660	Médico brujo Cabellesangre	Médico brujo Sangrapellejo
667	Guerrero Machacacráneos	
669	Cazador Machacacráneos	
670	Médico Brujo Machacacráneos	Médico brujo Machacacráneos
671	Rebanacabezas Cabellesangre	Rebanacabezas Sangrapellejo
672	Cazaespíritus Machacacráneos	
674	Minero exterior de Ventura y Cía.	Cantero de Ventura y Cía.
675	Supervisor de Ventura y Cía.	
676	Perito de Ventura y Cía.	
677	Manitas de Ventura y Cía.	
678	Destructor Mosh'Ogg	Aplastador Mosh'Ogg
679	Chamán Mosh'Ogg	
680	Señor Mosh'Ogg	
681	Tigre joven de Tuercespina	
682	Tigre de Tuercespina	
683	Pantera joven	
684	Pantera Faucesombría	
685	Raptor de Tuercespina	
686	Raptor colazote	
687	Acechador de la selva	
688	Basilisco Morropiedra	
689	Basilisco Espina de Cristal	
690	Basilisco Ojogélido	
691	Elemental de agua inferior	
694	Lanzahachas Cabellesangre	Lanzahachas Sangrapellejo
696	Lanzahachas Machacacráneos	
697	Chamán Cabellesangre	Chamán Sangrapellejo
699	Maestro de bestias Cabellesangre	Maestro de bestias Sangrapellejo
701	Místico Cabellesangre	Místico Sangrapellejo
702	Carroñero Cabellesangre	Carroñero Sangrapellejo
703	Teniente Fangore	
704	Lobo maderero andrajoso	Lobo gris pulgoso
705	Lobo joven andrajoso	Lobo joven pulgoso
706	Cría de trol Peloescarcha	
707	Trogg Mentueso	Trogg Comepiedras
708	Jabalí del risco pequeño	
709	Belicista Mosh'Ogg	
710	Creaconjuros Mosh'Ogg	
711	Ardo Patasoez	
712	Descarnador de Crestagrana	
723	Carnicero Mosh'Ogg	
724	Trogg Comepiedras fornido	
728	Bhag'thera	
729	Sin'Dall	
730	Tethis	
731	Rey Bangalash	
732	Rondador múrloc	
735	Correcorrientes múrloc	
736	Pantera	
740	Cría adolescente	
741	Cría soñadora	
742	Vermis verde	Verminte verde
743	Vermis Caminasueños	Verminte Caminasueños
744	Horrocrusto verde	
745	Capitán Horrocrusto	
746	Ancestro dragonante	
747	Múrloc del pantano	Múrloc de marisma
750	Vomitatintas del pantano	Vomitatintas de marisma
751	Comecarnes del pantano	Comecarnes de marisma
752	Oráculo del pantano	Oráculo de marisma
754	Velador rebelde	
755	Rondafango Perdido	
756	Pantera Machacacráneos	
757	Pescador Perdido	
759	Cazador Perdido	
760	Habitabosta Perdido	
761	Vidente Perdido	
762	Buscafallas Perdido	
763	Cabecilla Perdido	
764	Caminalodo	
765	Viejo caminalodo	
766	Horror enredado	
767	Jaguar del pantano	
768	Pantera sombría	
769	Tarántula Golpemortal	
771	Comandante Yelestrón	
772	Tigresa de Tuercespina	
780	Místico Machacacráneos	
781	Rebanacabezas Machacacráneos	
782	Explorador Machacacráneos	
783	Rabioso Machacacráneos	
784	Maestro de bestias Machacacráneos	
785	Guarda esquelético	
787	Sanador esquelético	
808	Grik'nir el Frío	
813	Coronel Kurzen	
814	Sargento Malthus	
815	Bookie Herod	
818	Mai'Zoth	
819	Vasallo de Ilgalar	
822	Oso del bosque joven	
824	Cavador Defias	
830	Reptador de la arena	
831	Reptador marino	
832	Demonio del polvo	
833	Coyote líder	
834	Coyote	
842	Leñador	
846	Necrófago	
850	Erin	
853	Montaraz Crestanevada	
854	Acechador joven de la selva	
855	Raptor joven de Tuercespina	
856	Raptor colazote joven	
858	Hilapenas	
861	Explorador de Rocal	
862	Expedicionario del Rocal	
863	Cazador del Rocal	
864	Orco de Rocal	
865	Buscacaminos del Rocal	
866	Bruto de Rocal	
867	Cartógrafo del Rocal	
868	Chamán del Rocal	
871	Guerrero Escama de Sal	
873	Oráculo Escama de Sal	
875	Señor de las Mareas Escama de Sal	
877	Batidor Escama de Sal	
879	Cazador Escama de Sal	
880	Erlan Yermestia	
881	Surena Caledon	
889	Ogro Puñastilla	
891	Tejefuego Puñastilla	
892	Capataz Puñastilla	
898	Huargen Penumbría	
905	Furia Dienteafilado	
909	Filonocturno Defias	
910	Encantador Defias	
920	Corrupto Nocturno	
921	Leñador de Ventura y Cía.	
922	Reptador de cieno	
923	Nicroyermo joven	
930	Prole de viuda negra	
932	Guardia Cierreniza	
933	Guardia Hiett	
934	Guardia Clarke	
935	Guardia Pearce	
936	Guardia Adams	
937	Jíbaro Kurzen	Jíbaro de Kurzen
938	Comando Kurzen	
939	Élite Kurzen	Élite de Kurzen
940	Auxiliador Kurzen	Auxiliador de Kurzen
941	Reductor de cabezas Kurzen	Reductor de cabezas de Kurzen
942	Médico brujo Kurzen	Médico brujo de Kurzen
943	Vaquero Kurzen	
946	Novicio Peloescarcha	
947	Rohh el Silencioso	
948	Podrido	
949	Ermitaño carroñero	
950	Hablador del pantano	Voz del pantano
976	Tigre de guerra Kurzen	
977	Pantera de guerra de Kurzen	
978	Subjefe de Kurzen	
979	Cazador de las Sombras Kurzen	
1007	Gnoll Pellejomusgo	
1008	Bastardo Pellejomusgo	
1009	Tejebruma Pellejomusgo	
1010	Correcubil Pellejomusgo	
1011	Trampero Pellejomusgo	
1012	Tosco Pellejomusgo	
1013	Místico Pellejomusgo	
1014	Alfa Pellejomusgo	
1015	Raptor de las Tierras Altas	
1016	Colazote de las Tierras Altas	
1017	Segador de la Tierras Altas	
1018	Tajobuche de las Tierras Altas	
1019	Ancestro Tajobuche	
1020	Raptor jaspeado	
1021	Estridador jaspeado	
1022	Segador jaspeado	
1023	Tajobuche jaspeado	
1024	Múrloc Branquiazul	
1025	Saltacharco Branquiazul	
1026	Batidor Branquiazul	
1027	Guerrero Branquiazul	
1028	Habitabosta Branquiazul	
1029	Oráculo Branquiazul	
1030	Babosa negra	
1031	Moco Carmesí	
1032	Moco negro	
1033	Moco monstruoso	
1034	Asaltante Faucedraco	
1035	Correpantanos Faucedraco	
1036	Centurión Faucedraco	
1037	Maestro de batalla Faucedraco	
1038	Pastor Faucedraco	
1039	Habitante del cubil	
1040	Trepador del cubil	
1041	Señor del pantano	
1042	Cría roja	
1043	Cría perdida	
1044	Cría escupefuego	
1045	Dragauro rojo	
1046	Vermis rojo	
1047	Horrocrusto rojo	
1048	Teniente Horrocrusto	
1049	Verminte Pirotigma	
1050	Guardia Real Horrocrusto	
1051	Enano Hierro Negro	
1052	Saboteador Hierro Negro	
1053	Tunelador Hierro Negro	
1054	Demoledor Hierro Negro	
1057	Guardahuesos Faucedraco	
1059	Ana'thek el Cruel	
1060	Mogh el Eterno	
1061	Gan'zulah	
1062	Nezzliok el Feroz	Nezzliok el Temible 
1064	Bruto de Grom'gol	
1065	Chamán Zarparrío	
1069	Cría carmesí	
1081	Señor del Lodo	
1082	Crocolisco Denteserra	
1083	Zancorillas múrloc	
1084	Crocolisco Denteserra joven	
1085	Tigre de Tuercespina mayor	
1087	Sacudidor Denteserra	
1088	Reptador monstruoso	
1094	Minero de Ventura y Cía.	
1095	Jefe de sector de Ventura y Cía.	
1096	Geólogo de Ventura y Cía.	
1097	Mecánico de Ventura y Cía.	
1106	Cocinero Perdido	
1108	Gorila Velo de Bruma	
1109	Desgarrador	
1110	Asaltante esquelético	
1111	Acechador sanguijuela	
1112	Viuda sanguijuela	
1114	Tronador de la selva	
1115	Aplastacráneos Mentueso	Aplastacráneos Comepiedras
1116	Emboscador Mentueso	Emboscador Comepiedras
1117	Quebrantahuesos Mentueso	Cascahuesos Comepiedras
1118	Partedorsales Mentueso	Partedorsales Comepiedras
1119	Martidorsal	
1120	Trol Peloescarcha	
1121	Zancanieve Peloescarcha	
1122	Desollador Peloescarcha	
1123	Rebanacabezas Peloescarcha	
1124	Nigromante Peloescarcha	
1125	Jabalí del risco	
1126	Grande jabalí del risco	Jabalí del risco grande
1127	Jabalí del risco mayor	Jabalí del risco anciano
1128	Oso negro joven	
1129	Oso negro	
1130	Bjarn	
1131	Lobo invernal	
1132	Maderero	
1133	Lobo invernal hambriento	
1134	Wendigo joven	
1135	Wendigo	
1137	Edan el Aullador	
1138	Lobo rastreador de la nieve	
1140	Matriarca Tajobuche	
1142	Tosco Mosh'Ogg	
1144	Médico brujo Mosh'Ogg	
1150	Crocolisco fluvial	
1151	Crocolisco Aguasalada	
1152	Crocolisco Quijaforte	
1155	Kelt Thomasin	
1157	Marinero maldito	
1158	Marino maldito	
1159	Contramaestre Snellig	
1160	Capitán Halyndor	
1161	Trogg Rompecantos	
1162	Explorador Rompecantos	
1163	Aplastacráneos Rompecantos	
1164	Partehuesos Rompecantos	Cascahuesos Rompecantos
1165	Geomántico Rompecantos	
1166	Profeta Rompecantos	Vidente Rompecantos
1167	Cavador Rompecantos	
1169	Insurgente Hierro Negro	
1172	Alimaña Ratatúnel	
1173	Explorador Ratatúnel	
1174	Geomántico Ratatúnel	
1175	Cavador Ratatúnel	
1176	Batidor Ratatúnel	
1177	Perito Ratatúnel	
1178	Ogro Mo'grosh	
1179	Déspota Mo'grosh	
1180	Tosco Mo'grosh	
1181	Chamán Mo'grosh	
1183	Místico Mo'grosh	
1184	Rondador del risco	
1185	Rondadora maderera	
1186	Oso negro viejo	Oso negro mayor
1188	Oso negro grizul	Oso negro grisáceo
1189	Patriarca oso negro	
1190	Jabalí montés	
1191	Jabalí montés sarnoso	
1192	Jabalí montés mayor	
1193	Demente del Loch	
1194	Águila ratonera montés	
1195	Rondador del bosque	Rondadora del bosque
1196	Oso zarpahelada	
1197	Chamán Rompecantos	
1199	Leopardo de la nieve joven	
1200	Morbent Vil	
1201	Leopardo de la nieve	Leopardo de las nieves
1202	Kóbold Ratatúnel	
1205	Gromug	
1206	Rechín	
1207	Camorrista	
1210	Chok'sul	
1211	Gnomo paria	
1216	Reptador de las costas	
1222	Zapador Hierro Negro	
1224	Joven trillanodonte	
1225	Viejo Sooty	
1236	Cavador kóbold	
1251	Temófogo Puñastilla	
1258	Masadura Nicroyermo	
1259	Engullidor	
1260	Gran patriarca Arctikus	
1270	Cadáver fétido	
1271	Viejo Barbahielo	
1353	Sarldente	
1354	Aprendiz Soren	
1364	Balgaras el Hediondo	
1380	Saean	
1388	Vagash	
1393	Trogg rabioso	
1397	Profeta Peloescarcha	Vidente Peloescarcha
1398	Jefe Vayachi	
1399	Magosh	
1400	Crocolisco de Los Humedales	
1417	Crocolisco joven de Los Humedales	
1418	Asaltante Branquiazul	
1424	Maestro excavador	
1425	Grizlak	
1426	Minero Zarparrío	
1434	Argos de Menethil	
1445	Jesse Halloran	
1446	Regina Halloran	
1447	Gimlok Rumdnul	
1487	Esclavista Puñastilla	
1488	Zombi Zanzil	
1489	Cazador Zanzil	
1490	Médico brujo Zanzil	
1491	Naga Zanzil	
1492	Gorlash	
1493	Mok'rash	
1494	Negolash	
1501	Zombi descerebrado	
1502	Zombi desdichado	Zombi espantoso
1504	Nocturácnida joven	
1505	Araña nocturácnida	
1506	Convertido Escarlata	Converso Escarlata
1507	Iniciado Escarlata	
1508	Carroñero joven	
1509	Carroñero andrajoso	Carroñero pulgoso
1511	Gorila Lomoplata enfurecido	
1512	Murciumbrío	
1513	Murciumbrío sarnoso	
1514	Mokk el Salvaje	
1516	Konda	
1520	Soldado armadóseo	
1522	Tirahuesos Ojosombra	
1523	Soldado testapartida	
1525	Muerto putrefacto	Muerto en podredumbre
1526	Cuerpo estragado	Cuerpo devastado
1527	Muerte hambrienta	
1528	Horror dergarbado	
1529	Horror sangrante	
1530	Anciano putrefacto	Ancestro en podredumbre
1531	Alma perdida	
1532	Espíritu deambulante	
1533	Espíritu atormentado	
1534	Ancestro de los Lamentos	Ancestro gemebundo
1535	Guerrero Escarlata	
1536	Misionero Escarlata	
1537	Zelote Escarlata	
1538	Fraile Escarlata	
1539	Neófito Escarlata	
1540	Soldado de Caballería Escarlata	Vanguardia Escarlata
1543	Saltacharco Anca Vil	
1544	Oráculo menor Anca Vil	
1545	Habitabosta Anca Vil	
1547	Can oscuro decrépito	
1548	Can oscuro maldito	
1549	Can oscuro voraz	
1550	Basilisco Colastador	
1551	Basilisco Quijahierro	
1552	Panzascama	
1553	Murciumbrío superior	
1554	Murciumbrío vampírico	
1555	Nocturácnida sañosa	
1557	Gorila Velo de Bruma anciano	
1558	Patriarca Lomoplata	
1559	Rey Mukla	
1561	Asaltante Velasangre	
1562	Mago Velasangre	
1563	Espadachín Velasangre	
1564	Brujo Velasangre	
1565	Perro de mar Velasangre	Lobo de mar Velasangre
1642	Guardia Norvera	
1653	Magus viejo Velasangre	
1654	Gregor Agamand	
1655	Nissa Agamand	
1656	Thurman Agamand	
1657	Devlin Agamand	
1658	Capitán Dargol	
1660	Guardaespaldas Escarlata	
1662	Capitán Perrine	
1664	Capitán Vachon	
1665	Capitán Melrache	
1667	Meven Korgal	
1674	Gnoll Putrepellejo	
1675	Bastardo Putrepellejo	
1688	Matriarca nocturácnida	
1689	Jabalí del risco cicatríceo	
1693	Crocolisco del lago	
1713	Pantera Faucesombría vieja	
1718	Asaltante Mentueso	Asaltante Comepiedras
1725	Vigilante Defias	Velador Defias
1726	Magiero Defias	
1727	Peón Defias	
1736	Guardia de la Muerte Randolph	
1737	Guardia de la Muerte Oliver	
1739	Guardia de la Muerte Phillip	
1741	Guardia de la Muerte Bartrand	
1753	Ojo de gusano	Ojo de cresa
1765	Lupo	
1766	Huargo jaspeado	
1767	Machacador Anca Vil	
1768	Cazamareas Anca Vil	
1769	Canoso Furia Lunar	
1770	Correoscuro Furia Lunar	
1772	Asaltaclaros Putrepellejo	
1773	Místico Putrepellejo	
1778	Grisoso feroz	Oso grisáceo feroz
1779	Glotón Furia Lunar	
1780	Acechamusgo	
1781	Trepanieblas	Trepador de la niebla
1782	Almanegra Furia Lunar	
1783	Despellejador esquelético	
1784	Hechicero esquelético	
1785	Terror esquelético	
1787	Verdugo esquelético	
1788	Señor de la guerra esquelético	
1789	Acólito esquelético	
1791	Necrófago esclavizante	
1793	Necrófago en podredumbre	
1794	Necrófago desalmado	
1795	Necrófago abrasador	
1796	Necrófago gélido	
1797	Grisoso gigante	Oso grisáceo gigante
1802	Ánima hambrienta	
1804	Muerte gemebunda	
1805	Gólem de carne	
1806	Babosa vil	
1808	Moco devorador	
1809	Buitre carroñero	
1812	Benemoth putrefacto	
1813	Horror en descomposición	
1815	Oso negro malsano	
1816	Oso pardo malsano	
1817	Lobo malsano	
1821	Rondador carroñero	
1822	Rondador Brumatósigo	
1824	Rondador de peste	
1826	Mago Escarlata	
1827	Centinela Escarlata	
1831	Cazador Escarlata	
1832	Magus Escarlata	
1833	Caballero Escarlata	
1834	Paladín Escarlata	
1835	Convocador Escarlata	
1836	Hidalgo Escarlata	
1837	Juez Escarlata	
1838	Interrogador Escarlata	
1839	Alto Clérigo Escarlata	
1841	Verdugo Escarlata	
1842	Alto señor Taelan Vadín	
1843	Supervisor Jerris	
1844	Supervisor Marcrid	
1845	Sumo Protector Tarsen	
1846	Sumo Protector Lorik	
1847	Crinatroz	
1848	Lord Maldazzar	
1850	Putridus	
1851	La Cáscara	
1852	Araj el Invocador	
1865	Asaltante Corvozarpa	
1866	Esclavo Corvozarpa	Bracero Corvozarpa
1867	Aprendiz Dalaran	Aprendiz de Dalaran
1868	Sirviente Corvozarpa	
1869	Campeón Corvozarpa	
1870	Mano de Corvozarpa	
1883	Trabajador Escarlata	
1884	Leñador Escarlata	
1885	Herrero Escarlata	
1888	Vigilante Dalaran	Vigía de Dalaran
1889	Zahorí Dalaran	Zahorí de Dalaran
1890	Esqueleto armadóseo	
1891	Vigilante Piroleño	Vigía Piroleña
1892	Vigilante Furia Lunar	Vigía Furia Lunar
1893	Argos Furia Lunar	Avizor Furia Lunar
1894	Argos Piroleño	Avizor Piroleña
1895	Viejo Piroleño	Viejo Piroleña
1896	Viejo Furia Lunar	
1907	Expedicionario naga	
1908	Oráculo Anca Vil	
1909	Acechalagos Anca Vil	
1910	Muad	
1911	Deeb	
1912	Protector Dalaran	Protector de Dalaran
1913	Pastor Dalaran	Depositario de Dalaran
1914	Mago Dalaran	Mago de Dalaran
1915	Conjurador Dalaran	Conjuradora de Dalaran
1916	Stephen Bhartec	
1917	Daniel Ulfman	
1918	Karrel Grayves	
1919	Samuel Fipps	
1920	Escribachizo de Dalaran	
1922	Lobo gris del bosque	
1923	Lupo Sangrocico	
1924	Aullasangre Furia Lunar	
1934	Granjero de Tirisfal	
1935	Mozo de labranza de Tirisfal	
1936	Granjero Solliden	
1939	Tosco Putrepellejo	
1940	Siembrapestes Putrepellejo	
1941	Asaltatumbas Putrepellejo	
1942	Salvaje Putrepellejo	
1943	Putrepellejo enfurecido	
1944	Truhán Putrepellejo	
1946	Lillith Nefara	
1947	Thule Corvozarpa	
1948	Melegruños	
1953	Vigilante del Lago	Vagador del Lago
1954	Vagador del Lago viejo	
1955	Trepador del Lago	
1956	Trepador del Lago viejo	
1957	Trepacostas Anca Vil	
1958	Llamamareas Anca Vil	Clamamareas Anca Vil
1961	Sarnagarra	
1971	Ivar el Hediondo	
1972	Grimson el Pálido	
1973	Guardián Corvozarpa	
1974	Esclavo Corvozarpa	
1975	Leñador de la Vega del Este	
1981	Emboscador Hierro Negro	
1983	Latipesadilla	
1984	Jabalí cardo joven	
1985	Jabalí Cardo	
1986	Araña Tejemadera	
1988	Grell	
1989	Grellín	
1993	Zarpaverde	
1994	Githyiss la Vil	
1995	Lechuza estrígida	
1996	Estridador estrígido	
1997	Cazador estrígido	
1998	Rondador Tejemadera	
1999	Venolmillo Tejemadera	
2000	Virasedal Tejemadera	
2001	Araña Tejemadera gigante	
2002	Duende granuja	
2003	Duende sombrío	
2004	Duende oscuro	
2005	Grell sañoso	
2006	Ursa Tuercepinos	
2007	Jardinero Tuercepinos	
2008	Guerrero Tuercepinos	
2009	Chamán Tuercepinos	
2010	Defensor Tuercepinos	
2011	Augurio Tuercepinos	
2012	Abrecaminos Tuercepinos	
2013	Vengador Tuercepinos	
2014	Totémico Tuercepinos	
2015	Arpía Sangrepluma	
2017	Pícaro Sangrepluma	
2018	Hechicera Sangrepluma	
2019	Furia Sangrepluma	
2020	Bruja del viento Sangrepluma	
2021	Matriarca Sangrepluma	
2022	Brezomadera	
2025	Desgarrador Brezomadera	
2027	Pisoteador Brezomadera	
2029	Bestia del lodo Brezomadera	Lodobestia Brezomadera
2030	Ancestro Cuaderna	Brezomadera anciano
2031	Sable de la noche joven	
2032	Sable de la noche sarnoso	
2033	Sable de la Noche mayor	Sable de la noche mayor
2034	Sable de la Noche salvaje	Sable de la noche salvaje
2038	Lord Melenas	
2039	Ursal el Violento	
2041	Protector anciano	
2042	Sable de la Noche	Sable de la noche
2043	Acechador sable de la noche	
2044	Espíritu abandonado	
2053	Refugiado Haggard	
2054	Refugiado enfermo	
2060	Consejero Herrera	
2061	Consejero Careso	
2062	Consejero Hendricks	
2063	Consejero Fijalontad	
2064	Consejero Hartin	
2065	Consejero Copre	
2066	Consejero Higarth	
2067	Consejero Mechanegra	
2068	Lord Mayor Morrison	
2069	Acechalunas	
2070	Jabato Acechalunas	Cachorro Acechalunas
2071	Matriarca Acechalunas	
2089	Crocolisco gigante de Los Humedales	
2090	Ma'ruk Vermiscala	
2091	Jefe Nek'rosh	Cabecilla Nek'rosh
2102	Bruto Faucedraco	
2103	Explorador Faucedraco	
2106	Boticario Berard	
2108	Garneg Hullacráneo	
2112	Farrin Daris	
2120	Archimago Ataeric	
2149	Asantante Hierro Negro	
2152	Emboscador Tuercepinos	
2156	Gólem partido	
2157	Behemoth de piedra	
2158	Explorador Gravacal	
2159	Partehuesos Gravacal	
2160	Geomántico Gravacal	
2162	Agal	
2163	Oso Cardo	
2164	Oso Cardo rabioso	Oso cardo rabioso
2165	Grisoso cardo	Oso cardo grisáceo
2166	Roblegüello	
2167	Abrecaminos Bosque Negro	
2168	Guerrero Bosque Negro	
2169	Totémico Bosque Negro	
2170	Ursa Bosque Negro	
2171	Chamán Bosque Negro	
2172	Zancador Madrezarpa	
2173	Demente de arrecife	
2174	Demente de la costa	
2175	Garrasombría	
2176	Altonato maldito	
2177	Altonato en pena	
2178	Altonato de los Lamentos	Altonato gemebunda
2179	Jinete de olas Escama Tormentosa	
2180	Sirena Escama Tormentosa	
2181	Myrmidón Escama Tormentosa	
2182	Hechicera Escama Tormentosa	
2183	Guerrero Escama Tormentosa	
2184	Lady Miraluna	
2185	Trillador de la Costa Oscura	Trillador de Costa Oscura
2186	Carnívoris el Rompedor	
2187	Trillador de la Costa Oscura	Trillador de Costa Oscura anciano
2189	Duende vil	
2190	Grel salvaje	Grell salvaje
2191	Licillin	
2192	Clamafuegos Radison	
2201	Asaltante Brumagris	
2202	Correcostas Brumagris	
2203	Profeta Brumagris	
2204	Redista Brumagris	
2205	Guerrero Brumagris	
2206	Cazador Brumagris	
2207	Oráculo Brumagris	
2208	Cazamareas Brumagris	
2212	Sátiro Deth'ryll	
2231	Corremareas Marepígmeo	Reptador de marea pigmeo
2232	Corremareas	Reptador de marea
2233	Corremareas escamado	Reptador de marea escamado
2234	Joven reptador Correarrecifes	Reptador de arrecife joven
2235	Correarrecifes	Reptador de arrecife
2236	Reptador Correarrecifes enfurecido	Reptador de arrecife enfurecido
2237	Señor Acechalunas	Patriarca Acechalunas
2240	Asaltante de caminos del Sindicato	Asaltante de caminos de la Hermandad
2241	Ladrón del Sindicato	Ladrón de la Hermandad
2242	Espía del Sindicato	Espía de la Hermandad
2243	Argos del Sindicato	Argos de la Hermandad
2244	Mago oscuro de la Hermandad	
2245	Saboteador de la Hermandad	
2246	Asesino de la Hermandad	
2247	Déspota del Sindicato	Déspota de la Hermandad
2248	Yeti de cuevas	Yeti de las cuevas
2249	Yeti feroz	
2250	Yeti montés	
2251	Yeti gigante	
2252	Ogro Aplastacresta	
2253	Tosco Aplastacresta	
2254	Destructor Aplastacresta	Aplastador Aplastacresta
2255	Mago Aplastacresta	
2256	Déspota Aplastacresta	
2257	Mug'thol	Jarra'thol
2258	Furia pétrea	
2260	Pícaro de la Hermandad	
2261	Velador de la Hermandad	
2266	Granjero de Trabalomas	
2267	Campesino de Trabalomas	
2268	Lacayo de Trabalomas	
2269	Minero de Trabalomas	
2270	Argos de Trabalomas	
2271	Guardia escudero Dalaran	Guardia escudero de Dalaran
2272	Teurgista Dalaran	Tuérgo de Dalaran
2275	Filoja enfurecido	
2283	Regente Corvozarpa	
2287	Belicista Aplastacresta	
2304	Capitán Ferrocolina	
2305	Supervisor Bonds	
2306	Barón Vardus	
2307	Custodio Caice	
2309	Thomas Arlento	
2310	Jamie Nore	
2311	Doreen Beltis	
2314	Sahvan Sombrasangre	
2315	Maquell Eboleño	
2318	Mago oscuro Artus	
2319	Zahorí del Sindicato	Zahorí de la Hermandad
2320	Nagaz	
2321	Fugalante zancudo del bosque	Volantón zancudo del bosque
2322	Zancudo del bosque	
2323	Zancudo del bosque gigante	
2324	Soplaviento Bosquenegro	Soplaviento Bosque Negro
2332	Valdred Moray	
2335	Magistrado Ladoquemao	
2336	Fanático de la Facción Oscura	
2337	Llamacío de la Facción Oscura	
2338	Discípulo Crepuscular	
2339	Matón Crepuscular	
2344	Montaraz de Dun Garok	
2345	Fusilero de Dun Garok	
2346	Sacerdote de Dun Garok	
2347	Grifo salvaje	
2348	Trepamusgo mayor	Trepamusgo anciano
2349	Trepamusgo gigante	
2350	Trepamusgo del bosque	
2351	Oso gris	
2354	Oso gris sañoso	
2356	Oso gris viejo	
2358	Invocador Dalaran	Invocador de Dalaran
2359	Esclavo elemental	
2360	Mozo de labranza de Trabalomas	
2368	Acechacostas Espinadaga	
2369	Cazacostas Espinadaga	
2370	Gritón Espinadaga	
2371	Sirena Espinadaga	
2372	Gnoll Fangorroca	
2373	Chamán Fangorroca	
2374	Habitabosta Rompeanca	
2375	Correcostas Rompeanca	
2376	Oráculo Rompeanca	
2377	Cazamareas Rompeanca	
2384	León montés hambriento	León de montaña famélico
2385	León montés feral	León de montaña feral
2386	Guardia de Costasur	
2387	Consejero de Trabalomas	
2392	Delia Verana	
2395	Vinna Wayne	
2396	Hans Zandin	
2398	Tara Mirafría	
2400	Craig Hewitt	
2403	Granjero Getz	
2406	León de montaña	
2407	León de montaña descomunal	
2408	Quijaforte	
2411	Ricter	
2412	Alina	
2413	Dermot	
2414	Kegan Darkmar	
2415	Alcaide Belamoore	Celadora Belamoore
2416	Asaltador Aplastacresta	
2417	Grel'borg el Avaro	
2420	Targ	
2421	Rastricacas	Rastrazo
2422	Glommus	
2423	Lord Aliden Perenolde	
2427	Carcelero Eston	
2428	Carcelero Marlgen	
2431	Jailor Borhuin	Carcelero Borhuin
2436	Granjero Kent	
2440	Asaltante de caminos borracho	
2447	Narillasanz	
2448	Dependiente Horracio Corzalbal	Funcionario Horracio Corzalbal
2449	Ciudadano Wilkes	
2450	Minero Hackett	
2451	Granjero Kalaba	Granjera Kalaba
2452	Skhowl	
2453	Lo'Grosh	
2462	Gusano comecarnes	
2473	Granistad	
2474	Kurdros	
2476	Crocolisco del lago grande	
2503	Supervisor de Trabalomas	
2505	Quijaforte Aguasalada	Quijaforte marino
2521	Gorila Cieloleno	
2522	Acechador Jaguero	
2529	Hijo de Arugal	
2530	Yenniku	
2534	Zanzil el Desarraigado	
2535	Maury "Patón" Wilkins	Maury "Patapalo" Wilkins
2536	Jon-Jon el Cuervo	
2537	Chucky "Diezdedos"	Chucky "Diez Pulgares"
2541	Lord Sakrasis	
2544	Reptador de las sudarenas	
2545	"El Guapo" Duncan	
2546	Maestro de Flota Firallon	Maestro de flota Firallon
2547	Parchierro	
2548	Capitán Sinquilla	
2549	Garr Fausal	
2550	Capitán Aguasmansas	
2551	Brutus	
2552	Trol Secacorteza	
2553	Taumaturgo umbrío Secacorteza	
2554	Lanzahachas Secacorteza	
2555	Médico brujo Secacorteza	
2556	Rebanacabezas Secacorteza	
2557	Cazador de las Sombras Secacorteza	
2558	Rabioso Secacorteza	
2559	Zancudo de las Tierras Altas	
2560	Descarnador de las Tierras Altas	
2561	Acechacarne de las Tierras Altas	
2562	Ogro Puño de Roca	
2563	Trepador de las llanuras	
2564	Déspota Puño de Roca	
2565	Trepador de las llanuras gigante	
2566	Tosco Puño de Roca	
2567	Magus Puño de Roca	
2569	Destructor Puño de Roca	
2570	Chamán Puño de Roca	
2571	Señor Puño de Roca	
2572	Kóbold Mostacho Seco	
2573	Perito Mostacho Seco	
2574	Cavador Mostacho Seco	
2575	Suministrador Hierro Negro	
2577	Taumaturgo umbrío Hierro Negro	
2578	Águila ratonera joven Mesa	
2579	Águila ratonera Mesa	
2580	Águila ratonera Mesa	
2581	Miliciano Dabyrie	
2582	Obrero Dabyrie	
2583	Cazatrols de Stromgarde	
2584	Defensor de Stromgarde	
2585	Vindicador de Stromgarde	
2586	Bandolero de la Hermandad	
2587	Acechacaminos del Sindicato	Acechacaminos de la Hermandad
2588	Merodeador del Sindicato	Merodeador de la Hermandad
2589	Mercenario de la Hermandad	
2590	Conjurador del Sindicato	Conjurador de la Hermandad
2591	Magus del Sindicato	Magus de la Hermandad
2592	Exiliado estruendoso	
2595	Asaltante Espinadaga	
2596	Hechicera Espinadaga	
2597	Lord Cresta de Halcón	
2598	Darbel Montrosa	
2599	Otto	
2600	Kantor	
2601	Panzatroz	
2602	Ruul Onapiedra	
2603	Kovork	
2604	Molok el Triturador	
2605	Zalas Secacorteza	
2606	Nimar el Destripador	
2609	Geomántico Dagasílex	
2611	Fozruk	
2618	Peón Sentencia	
2619	Bruto Sentencia	
2628	Trabajador Dalaran	Trabajador de Dalaran
2635	Crocolisco de agua salada viejo	Crocolisco marino mayor
2639	Lanzahachas Vilrama	
2640	Médico brujo Vilrama	
2641	Rebanacabezas Vilrama	
2642	Nigromante Vilrama	
2643	Rabioso Vilrama	
2644	Desollador Vilrama	
2645	Cazador de las Sombras Vilrama	
2646	Bebesangre Vilrama	
2647	Comealmas Vilrama	
2648	Guardia Aman'zasi Vilrama	
2649	Arrancacabelleras Secacorteza	
2650	Zelote Secacorteza	
2651	Desollador Secacorteza	
2652	Sangreveneno Secacorteza	
2653	Sádico Secacorteza	
2654	Clamador Secacorteza	
2655	Barroso verde	Lodo verde
2656	Moco de jade	
2657	Picovaja adiestrado	
2658	Grifo Picovaja	
2659	Señor del Cielo Picovaja	
2676	Segador de la cosecha compacto	
2680	Lobizón Vilrama	
2681	Lobo de montar Vilrama	
2686	Guardia de la prole Secacorteza	Guardia del linaje Secacorteza
2691	Avanzada Vallealto	
2692	Explorador Vallealto	
2693	Tirador Vallealto	
2694	Forestal Vallealto	
2701	Ogro Rotapolvo	
2714	Mensajero Renegado	
2715	Tosco Rotapolvo	
2716	Cazavermis Rotapolvo	
2717	Destructor Rotapolvo	Aplastador Rotapolvo
2718	Chamán Rotapolvo	
2719	Señor Rotapolvo	
2720	Mago ogro Rotapolvo	
2721	Guardaespaldas Renegado	
2723	Gólem de piedra	
2725	Cría hirviente	
2726	Guardián abrasado	Guardián agostado
2727	Coyote del risco	
2728	Coyote del risco feral	
2729	Coyote del risco mayor	
2730	Coyote del risco rabioso	
2731	Acechador de la cresta	
2732	Cazadora de la cresta	
2733	Boticario Jorell	
2734	Patriarca acechador de la cresta	
2735	Elemental de piedra inferior	Elemental de roca inferior
2736	Elemental de piedra mayor	Elemental de roca superior
2739	Tunelador Forjatiniebla	Tunelador de Forjatiniebla
2740	Tejeoscuro Forjatiniebla	Tejeoscuro de Forjatiniebla
2742	Corista Forjatiniebla	Corista de Forjatiniebla
2743	Guerrero Forjatiniebla	Guerrero de Forjatiniebla
2744	Comandante de Forjatiniebla	
2745	Embajador Infernus	
2749	Gólem de asedio	
2751	Gólem de guerra	
2752	Estruendor	
2753	Barnabus	
2754	Anathemus	
2755	Myzrael	
2757	Cinchoscura	Latigoscuro
2759	Hematus	
2760	Exiliado ardiente	
2761	Éxilu coronador	
2762	Exiliado tronador	
2763	Thenan	
2764	Durmilón	
2765	Znort	
2773	Or'Kalar	
2779	Príncipe Nazjak	
2783	Marez Cowl	Marez Cogulla
2791	Elemental de piedra enfurecido	Elemental de roca iracundo
2793	Kor'gresh Ira Helada	
2794	Guardián invocado	
2829	Águila ratonera hambriento	
2830	Águila ratonera	
2831	Águila ratonera gigante	
2850	Diente partido	
2892	Profeta Grutacanto	
2893	Partehuesos Grutacanto	Cascahuesos Grutacanto
2894	Chamán Grutacanto	
2906	Guerrero Rotapolvo	
2907	Místico Rotapolvo	
2919	Guardián Fam'retor	
2923	Melenargenta sarnoso	
2924	Lobo melenargenta	
2925	Aullador Melenargenta	Aullador melenargenta
2926	Acechador melenargenta	
2927	Lechubestia sañosa	
2928	Lechubestia primitiva	
2929	Lechubestia salvaje	
2931	Zaricotl	
2932	Magregan Sombraprofunda	
2937	Dagun el Voraz	
2944	Jefe Tho'grun	
2945	Murdaloc	
2949	Peletero Crines Pálidas	
2950	Desollador Crines Pálidas	
2951	Furtivo Crines Pálidos	
2952	Jabaespín Lomopelo	Jabaespín Erizapúas
2953	Chamán Lomopelo	Chamán Erizapúas
2954	Jabaguerrero Lomopelo	Jabaguerrero Erizapúas
2955	Zancudo de llanura	
2956	Zancudo de llanura adulto	
2957	Zancudo de llanura viejo	
2958	Lobo de pradera	
2959	Acechador de pradera	
2960	Lobo alfa de pradera	
2961	Puma montés	
2962	Arpía Viento Furioso	
2963	Ventobruja Viento Furioso	
2964	Hechicera Viento Furioso	
2965	Matriarca Viento Furioso	
2966	Jabaguerrero	
2967	Centauro Galak	
2968	Avanzado Galak	
2969	Aguilón nervudo	
2970	Aguilón	
2971	Aguilón garrudo	
2972	Cría de kodo	
2973	Kodo dominante	
2974	Matriarca Kodo	
2975	Contratista de Ventura y Cía.	
2976	Obrero de Ventura y Cía.	
2977	Capataz de Ventura y Cía.	
2978	Trabajador de Ventura y Cía.	
2979	Controlador de Ventura y Cía.	
2989	Cavador de Bael'dun	
2990	Tasador Bael'dun	Tasador de Bael'dun
3035	Puma de las estepas	
3051	Supervisor Fizsprocket	Supervisor Saltatuercas
3056	Aullido Fantasma	
3058	Arra'chea	
3068	Mazzranache	
3094	Oculto	
3098	Jabalí jaspeado	
3099	Jabalí jaspeado feroz	
3100	Jabalí jaspeado mayor	
3101	Familiar vil	
3102	Acechador vil	
3103	Pinzador makrura	
3104	Caparapiel makrura	
3105	Quebrador Makrura	
3106	Reptador de espuma pigmeo	
3107	Reptador de espuma	
3108	Reptador de espuma escamado	
3110	Crocolisco Fauzatroz	
3111	Jabaespín Crines de Acero	
3112	Explorador Crines de Acero	
3113	Correpolvo Crines de Acero	
3114	Guardia de batalla Crines de Acero	
3115	Arpía Viento Seco	
3116	Saqueadora Viento Seco	
3117	Salvaje Viento Seco	
3118	Bruja de la Tormenta Viento Seco	
3119	Esclavo Kolkar	
3120	Avanzado Kolkar	
3121	Tigre de Durotar	
3122	Colazote Garrasangre	
3123	Garrasangre Rojomorro	
3124	Trabajador escórpido	Escórpido obrero
3125	Escórpido castañeante	
3126	Escórpido acorazado	
3127	escórpido Venocola	Escórpido Venocola
3128	Navegante Kul Tiras	
3129	Marinero Kul Tiras	
3130	Truenagarto	
3131	Lomorrayo	
3141	Viejo Makrura	
3183	Yarrog Sombrarruina	
3192	Teniente Benedict	
3195	Matón Filo Ardiente	
3196	Neófito Filo Ardiente	
3197	Fanático Filo Ardiente	
3198	Aprendiz Filo Ardiente	
3199	Fiel Filo Ardiente	Cultor Filo Ardiente
3203	Fizzle Tormenta Oscura	
3204	Gazz'uz	
3205	Zalazane	
3206	Trol vudú	
3207	Trol embrujado	
3225	Jabalí jaspeado corrupto	
3226	Escórpido corrupto	
3227	Garrasangre corrupto Rojomorro	
3228	Reptador de espuma corrupto	
3229	"Chillón" Mantospina	
3231	Crocolisco Fauzatroz corrupto	
3232	Intruso Lomopelo	Intruso Erizapúas
3234	Kodo de los Baldíos Perdidos	
3235	Kodo mayor de Los Baldíos	
3236	Kodo de Los Baldíos	
3237	Kodo lanudo	
3238	Tormentero	
3239	Tronatesta	
3240	Morrotormenta	
3241	Patriarca de la sabana	
3242	Galopador astacebra	Galopador zhebra
3243	Crinalta de la savana	Crinalta de la sabana
3244	Zancudo de llanura mayor	Zancudo de llanura superior
3245	Zancudo de llanura Ornery	Zancudo de llanura ornario
3246	Zancudo de llanura flotador	Zancudo veloz de llanura
3247	Prole de Halcón Trueno	
3248	Girafa de los Baldíos	
3249	Halcón Trueno superior	
3250	Trepador silítido	
3251	Larva silítida	
3252	Enjambrista silítido	
3253	Cosechador silítido	
3254	Colazote Solescama	
3255	Estridador solescama	Estridador Solescama
3256	Segador Solescama	
3257	Ishamuhale	
3258	Cazador Erizapúas	
3260	Buscaqua Erizapúas	
3261	Tejespina Erizapúas	
3263	Geomántica Erizapúas	
3265	Cazador Crines de Acero	
3266	Defensor Crines de Acero	
3267	Buscaqua Crines de Acero	
3268	Tejespina Crines de Acero	
3269	Geomántico Crines de Acero	Geomántica Crines de Acero
3270	Anciano místico Filocico	
3271	Místico Crines de Acero	
3272	Vaquero Kolkar	Retador Kolkar
3273	Agitadora Kolkar	
3274	Corremanadas Kolkar	
3275	Maleante Kolkar	
3276	Arpía Alabruja	
3277	Malapluma Alabruja	
3278	Destripador Alabruja	Destripadora Alabruja
3279	Emboscador Alabruja	Emboscadora Alabruja
3280	Clamavientos Alabruja	
3281	Sarkoth	
3282	Mercenario de Ventura y Cía.	
3283	Déspota de Ventura y Cía.	
3284	Esclavo de Ventura y Cía.	
3285	Peón de Ventura y Cía.	
3286	Sobrestante de Ventura y Cía.	
3295	Bestia de lodo	
3297	Vigía de Sen'jin	
3374	Excavador de Bael'dun	
3375	Supervisor de Bael'dun	
3376	Soldado Bael'dun	Soldado de Bael'dun
3377	Fusilero Bael'dun	Fusilero de Bael'dun
3378	Oficial Bael'Dun	Oficial de Bael'dun
3379	Truhán Filo Ardiente	
3380	Acólito Filo Ardiente	
3381	Brigadier del Mar del Sur	Salteador de los Mares del Sur
3382	Cañonero del Mar del Sur	Cañonero de los Mares del Sur
3383	Degollador del Mar del Sur	Degollador de los Mares del Sur
3384	Corsario del Mar del Sur	Corsario de los Mares del Sur
3385	Marino de Theramore	
3386	Valedora de Theramore	
3393	Capitán Justamonta	Capitana Justamonta
3394	Barak Aterrakodos	
3395	Verog el Derviche	
3396	Hezrul Marcasangre	
3397	Destrero de sangre Kolkar	
3398	Gesharahan	
3414	General Trenzado	
3415	Cazadora de la savana	Cazadora de la sabana
3416	Matriarca de la sabana	
3424	Desechanube Halcón Trueno	
3425	Merodeador de la savana	Merodeador de la sabana
3426	Destrero zhebra	
3434	Nak	
3435	Lok Aterraorcos	
3436	Kuz	
3438	Kreenig Gruñucico	
3444	Rata de madriguera	
3445	Supervisor Lugwizzle	Supervisor Palarrastre
3452	Serena Sangrepluma	
3454	Cañonero Smythe	
3455	Cañonero Whessan	
3456	Abrecaminos Crines de Acero	
3457	Acechador Crines de Acero	
3458	Vidente Crines de Acero	
3459	Frenético bélico Crines de Acero	
3461	Quijaforte de oasis	
3463	Girafa de los Baldíos deambulante	
3466	Trotador zhebra	
3467	Barón Longavera	
3470	Rathorian	
3471	Manitas Sniggles	Manitas el Risitas
3472	Washte Pawne	
3473	Owatanka	
3474	Lakota'mani	
3475	Echeyakee	
3476	Isha Awak	
3501	Guardia de la Horda	
3503	Protector silítido	
3529	Blindado Furia Lunar	
3531	Sastre Furia Lunar	
3533	Peletero Furia Lunar	
3535	Musgonegro el Fétido	
3560	Tutor sanador	
3566	Merodeador de las estepas	
3617	Ciudadano de Lordaeron	
3619	Sable Fantasma	
3630	Volutador descarriado	
3631	Latigador con aguijón descarriado	
3632	Trepador descarriado	
3633	Destripador descarriado	
3634	Acechador descarriado	
3638	Ectoplasma devorador	
3641	Rondador descarriado	
3652	Tritesta el Azotador	
3655	Magglish el Loco	Loco Magglish
3660	Athrikus Narassin	
3662	Delmanis el Odiado	
3664	Ilkrud Magthrull	
3667	Anaia Correalba	
3672	Boahn	
3695	Zarpadura	
3696	Ran Dentesangre	Ran Sangradientes
3711	Myrmidón Colafuria	
3712	Filón Colafuria	
3713	Jinete de olas Colafuria	
3715	Bruja de mar Colafuria	
3717	Hechicera Colafuria	
3721	Hidra Brumazote	
3722	Despellejador Brumazote	
3725	Cultor de la Facción Oscura	
3727	Déspota de la Facción Oscura	
3728	Adepto de la Facción Oscura	
3730	Excavador de la Facción Oscura	
3732	Buscador Renegado	
3733	Herborista Renegado	
3734	Matón Renegado	
3735	Boticario Falthis	
3736	Destripador Oscuro Mordenthal	
3737	Saltacharco Gapo Salino	
3739	Guerrero Gapo Salino	
3740	Habitabosta Gapo Salino	
3742	Oráculo Gapo Salino	
3743	Guerrero Maderiza	
3745	Abrecaminos Maderiza	
3746	Vigilante del cubil Maderiza	
3748	Chamán Maderiza	
3749	Ursa Maderiza	
3750	Totémico Maderiza	
3752	Pícaro Xavian	
3754	Desertor Xavian	
3755	Jurapenas Xavian	
3757	Clamainferno Xavian	
3758	Sátiro Putredor	
3759	Pícaro Putredor	
3762	Jurapenas Putredor	
3763	Acechasombras Putredor	
3765	Sátiro Almaumbría	
3767	Timador Lobrecuore	Tramposo Almaumbría
3770	Acechasombras Lobrecuore	Acechasombras Almaumbría
3771	Clamainferno Almaumbría	
3772	Guardia maldito inferior	
3773	Akkrilus	
3774	Destripador vil	
3780	Comemusgo Sombramatorral	
3781	Formadera Sombramatorral	
3782	Muevepiedras Sombramatorral	
3783	Clamalluvias Sombramatorral	
3784	Desgarracortezas Sombramatorral	
3789	Desgarrador Luporror	
3791	Tejesombra Luporror	
3792	Señor de la manada Luporror	
3797	Protector Cenarion	
3799	Druida aislado	
3801	Durmiente aislado	
3802	Soñador aislado	
3803	Vigilante aislado	
3804	Intruso Renegado	
3806	Infiltrado Renegado	
3807	Asesino Renegado	
3808	Acechador oscuro Renegado	
3809	Oso de Vallefresno	
3810	Oso viejo de Vallefresno	
3811	Oso gigante de Vallefresno	
3812	Reptador castañeante	
3814	Reptador espinado	
3815	Dragón relampagueador	
3816	Ciervo salvaje	
3817	Venado Necraste	
3818	Venado Necraste viejo	
3819	Acechador Espinaferal	
3820	Escupeveneno Espinaferal	
3821	Rondador Espinaferal	
3823	Corredor Fangarra	
3824	Aullador Fangarra	
3825	Alfa Fangarra	
3833	Vindicador Cenarion	
3834	Anciano enloquecido	
3835	Sapo bílico	
3879	Asesino de la Facción Oscura	
3888	Korra	
3893	Explorador Renegado	
3897	Krolg	
3898	Aligar el Torturador	
3899	Balizar el Agraviado	
3900	Caedakar el Vicioso	
3917	Elemental de agua podrida	
3919	Anciano marchito	
3921	Ursa Piel de Cardo	
3922	Totémico Piel de Cardo	
3923	Vigía del cubil Piel de Cardo	
3924	Chamán Piel de Cardo	
3925	Vengador Piel de Cardo	
3926	Abrecaminos Piel de Cardo	
3928	Babosa putrefacta	
3931	Oráculo Sombramatorral	
3932	Guardia Dentesangre	Guardia Sangradientes
3939	Lobo Crines de Acero	
3940	Taneel Leñoscuro	
3941	Uthil Llamaluna	
3942	Mavoris Quiebranubes	
3943	Ruuzel	
3944	Sacerdotisa Colafuria	
3984	Nancy Vishas	
3985	Abuelo Vishas	
3986	Sarilus Fuenteviciosa	
3987	Dal Zarpasangrante	
3988	Operador de Ventura y Cía.	
3989	Leñero de Ventura y Cía.	Maderero de Ventura y Cía.
3991	Deforestador de Ventura y Cía.	
3992	Ingeniero de Ventura y Cía.	
3993	Maquinista de Ventura y Cía.	
3998	Alimaña Cortaviento	
3999	Cavador Cortaviento	
4001	Rata de túnel Cortaviento	
4002	Cortapiedras Cortaviento	
4003	Geomántico Cortaviento	
4004	Señor Supremo Cortaviento	
4005	Trepador Musgondo	
4006	Tejerred Musgondo	
4007	Escupeveneno Musgondo	Escupetósigo Musgondo
4008	Tormentabisal	
4009	Tormentabisal enfurecido	
4011	Alargullo joven	
4012	Dracoleón Alargullo	
4013	Cazacielos Alargullo	
4014	Consorte Alargullo	
4015	Patriarca Alaorgullo	
4016	Dragón clarividente	Dragón hada
4017	Dragón vidente Wily	Dragón hada avispado
4018	Antlered Maledictor	Trotador cornamentado
4019	Gran potro	Gran trotador
4020	Bestia de savia	
4021	Bestia de savia corrosiva	
4022	Arpía Furia Sangrienta	
4023	Malapluma Furia Sangrienta	
4024	Destripadora Furia Sangrienta	
4025	Emboscadora Furia Sangrienta	
4026	Clamavientos Furia Sangrienta	
4027	Bruja de la Tormenta Furia Sangrienta	
4028	Anciano carbonizado	
4029	Anciano ennegrecido	
4030	Anciano vengativo	
4031	Quimera volantona	
4032	Quimera joven	
4034	Espíritu de piedra iracundo	
4035	Espíritu de piedra furioso	
4036	Pícaro espíritu flameante	Espíritu flameante huido
4037	Devastador ardiente	
4038	Destructor ardiente	
4040	Acechador de cuevas	
4041	Basilisco agostado	
4042	Basilisco chamuscado	
4044	Basilisco ennegrecido	
4051	Botánico Cenarion	
4053	Hija de Cenario	
4054	Hermana sonriente	
4057	Hijo de Cenarius	
4062	Bombardero Hierro Negro	
4063	Feeboz	
4064	Explorador Roca Negra	
4065	Argos Roca Negra	
4066	Nal'taszar	
4067	Corredor Crepuscular	
4070	Constructor de Ventura y Cía.	
4072	Prisionero de Jin'Zil	
4073	XT:4	
4074	XT:9	
4093	Retador Galak	
4094	Explorador Galak	
4095	Destructor Galak	
4096	Cazavientos Galak	
4097	Tormento Galak	
4099	Maleante Galak	
4100	Arpía estridente	
4101	Malapluma estridente	
4104	Clamavientos estridente	
4107	Dracoleón Nido Alto	
4109	Consorte Nido Alto	
4110	Patriarca Nido Alto	
4111	Kóbold Gravamorro	
4112	Alimaña Gravamorro	
4113	Cavador Gravamorro	
4114	Batidor Gravamorro	
4116	Supervisor Gravamorro	
4117	Serpiente nubosa	
4118	Nubeserpiente Venenosa	
4119	Serpiente nubosa viejo	
4120	Rocoso tronador	
4124	Puma de las Agujas	
4126	Acechador del risco	
4127	Hiena Dentecenado	
4128	Acechador Dentecenado	
4129	Gruñidor Dentecenado	
4130	Buscador silítido	
4131	Invasor silítido	
4132	Devastador silítido	
4133	Zángano de la Colmena silítida	Zángano de colmena silítido
4139	Terror escórpido	
4140	Atracador escórpido	
4142	Tortuga brillavalva	
4143	Sacudidor caparallante	Mordedor brillavalva
4144	Cavapozos caparallante	Cazapozos brillavalva
4147	Basilisco Gapo Salino	Basilisco Piedra de sal
4150	Observador Gapo Salino	Observador Piedra de sal
4151	Vitropiel Gapo Salino	Vitropiel Piedra de sal
4154	Carroñero de los Llanos de Sal	Carroñero del Desierto de Sal
4158	Buitre del Desierto de Sal	
4202	Gerenzo Silbillave	
4248	Hiena Pestillejo	
4249	Gruñidor Pestillejo	
4250	Can de manada Galak	
4260	Machacador de Ventura y Cía.	
4263	Prole de Musgondo	
4264	Matriarca Musgondo	
4273	Vigilante Ordanus	
4280	Valedor Escarlata	
4281	Explorador Escarlata	
4282	Magiero Escarlata	
4283	Avizor Escarlata	
4284	Augur Escarlata	
4285	Discípulo Escarlata	
4311	Holgar Hachatormenta	
4316	Can de manada Kolkar	
4323	Trampedor abrasador	Prole abrasadora
4324	Cría abrasadora	
4328	Horrocrusto Pirocabello	
4329	Explorador Pirocabello	
4331	Ceniazote Pirocabello	
4334	Clamallamas Pirocabello	
4339	Brotasangre	
4341	Crocolisco secorrón	
4342	Mentovilo secorrón	
4343	Sacudidor secorrón	
4344	Crocolisco secorrón jaspeado	
4345	Faucedaga secorrón	
4346	Despellejador nocivo	
4347	Atracador nocivo	
4348	Machacador nocivo	
4351	Raptor Faucerroja	
4352	Estridador Faucerroja	
4355	Segador Faucerroja	
4356	Tajobuche Faucerroja	
4357	Colazote Faucerroja	
4358	Saltacharco Ancalodo	
4359	Múrloc Ancalodo	
4360	Guerrero Ancalodo	
4361	Habitabosta Ancalodo	
4362	Correcostas Mirefín	Correcostas Ancalodo
4363	Oráculo Ancalodo	
4364	Guerrero Strashaz	
4366	Guardia serpiente Strashaz	
4368	Mirmidón Strashaz	
4370	Hechicera Strashaz	
4371	Sirena Strashaz	
4374	Hidra Strashaz	
4376	Araña Niebla Negra	
4377	Rondadora Niebla Negra	Rondador Niebla Negra
4378	Ermitaña Niebla Negra	
4379	Virasedal Niebla Negra	
4380	Viuda Niebla Negra	
4382	Trepador Parramustia	
4385	Enfurecedor Parramustia	
4386	Desgarrador Parramustia	
4387	Lodobestia Parramustia	
4388	Trillador de la oscuridad joven	
4389	Trillador de la oscuridad	
4390	Trillador de la oscuridad mayor	
4391	Moco del pantano	
4392	Moco corrosivo del pantano	
4393	Moco ácido del pantano	
4394	Moco de pantano burbujeante	
4396	Tortuga Fangorroca	
4397	Caparapico Fangorroca	
4398	Hurgador Fangorroca	
4399	Cavapozos Fangorroca	
4400	Quijaforte Fangorroca	
4401	Pinzador Valvafango	
4402	Quebrador Valvafango	
4403	Tenazario Valvafango	
4404	Escarbador Valvafango	
4405	Zarpador Valvafango	
4412	Trepador Colmilloumbrío	Trepador Colmiumbrío
4413	Araña Colmiumbrío	
4414	Escupeveneno Colmilloumbrío	Escupetósigo Colmiumbrío
4415	Araña Colmiumbrío gigante	
4457	Batidor Ancaniebla	
4458	Cazador Ancaniebla	
4459	Oráculo Ancaniebla	
4460	Señor Ancaniebla	
4461	Guerrero Ancaniebla	
4462	Cazador Roca Negra	
4463	Invocador Roca Negra	
4464	Gladiador Roca Negra	
4465	Guerrero Vilrama	
4466	Arrancacabelleras Vilrama	
4467	Veritas Vilrama	
4468	Barroso de jade	
4469	Moco Esmeralda	
4472	Visión encantada	
4474	Cadáver en podredumbre	
4475	Zombi contagiado	
4479	Fardel Dabyrie	
4480	Kenata Dabyrie	
4481	Marcel Dabyrie	
4490	Grenka Aullasangre	
4493	Vengador Escarlata	
4494	Vinculador de hechizos escarlata	
4499	Rok'Alim el Aporreador	
4504	Faucehielo	
4505	Grumete Velasangre	
4506	Bisoño Velasangre	
4545	Nag'zehn	
4546	Bor'zehn	
4547	Acechasombras Tarkreu	
4548	Metaleador	
4619	Geltharis	
4632	Centauro Kolkar	
4633	Explorador Kolkar	
4634	Aplastador Kolkar	
4635	Cazavientos Kolkar	
4636	Señor de batalla Kolkar	
4637	Destructor Kolkar	
4638	Explorador Magram	
4639	Avanzado Magram	
4640	Retador Magram	
4641	Cazavientos Magram	
4642	Agitadora Magram	
4643	Corremanadas Magram	
4644	Maleante Magram	
4645	Aplastador Magram	
4646	Avanzado Gelkis	
4647	Explorador Gelkis	
4648	Coceador Gelkis	
4649	Cazavientos Gelkis	
4651	Clamatierras Gelkis	
4652	Aplastador Gelkis	
4653	Maleante Gelkis	
4654	Explorador Maraudine	
4655	Retador Maraudine	
4656	Aplastador Maraudine	
4657	Cazavientos Maraudine	
4658	Agitadora Maraudine	
4659	Maleante Maraudine	
4660	Zarpósea Maraudine	
4661	Estruendor Gelkis	
4662	Zarpósea Magram	
4663	Augur Filo Ardiente	
4664	Atracador Filo Ardiente	
4665	Adepto Filo Ardiente	
4666	Jurapenas Filo Ardiente	
4667	Mago oscuro Filo Ardiente	
4668	Invocador Filo Ardiente	
4670	Pícaro Odio Feroz	
4671	Tramposo Odio Feroz	
4672	Jurapenas Odio Feroz	
4673	Traidor Odio Feroz	
4674	Acechasombras Odio Feroz	
4675	Clamainferno Odio Feroz	
4676	Infernal inferior	
4677	Guardiavil	
4678	Devorador de maná	
4679	Doncella abisal	
4680	Capitán Guardiavil	
4681	Cazador de magos	
4682	Hermana abisal	
4684	Hechicera infernal	
4685	Cazador Ley	
4686	Gigante Zancaprofunda	
4687	Buscador Zancaprofunda	
4688	Hiena Zarpósea	
4689	Zarpósea famélica	
4690	Zarpósea rabiosa	
4692	Aguilón aterrador	
4693	Volador aterrador	
4694	Desgarrador aterrador	
4695	Horror carroñero	
4696	Sacudidor Scorpashi	
4697	Azotador Scorpashi	
4699	Lativenenoso Scorpashi	
4700	Kodo envejecido	
4701	Kodo moribundo	
4702	Kodo anciano	
4705	Evocador Filo Ardiente	
4711	Naga Filozante	
4712	Hechicera Filozante	
4713	Guerrero Filozante	
4714	Mirmidón Filozante	
4715	Filón Filozante	
4716	Cazamareas Filozante	
4718	Oráculo Filozante	
4719	Bruja de mar Filozante	
4723	Supervisor Cozzle	
4726	Truenagarto enfurecido	
4727	Truenagarto anciano	
4728	Basilisco Faucegrava	
4729	Basilisco Faucegrava descomunal	
4788	Sátiro Malarraíz	
4789	Pícaro Malarraíz	
4802	Sacerdote de las mareas Brazanegra	Sacerdotisa de las mareas Brazanegra
4803	Oráculo Brazanegra	
4834	Infiltrador de Theramore	Infiltrado de Theramore
4841	Lodomuerto	
4844	Perito Forjatiniebla	Perito de Forjatiniebla
4845	Rufián Forjatiniebla	Rufián de Forjatiniebla
4846	Cavador Forjatiniebla	Cavador de Forjatiniebla
4851	Masticapiedras Grutacanto	
4856	Cazador de las cuevas Grutacanto	
4872	Gólem Obsidiano	
4901	Sara Pierce	
4902	Mikal Pierce	
4922	Guardia Eduardo	
4923	Guardia Jarad	
4924	Maestro de combate Critón	
4950	Toby	
4951	Guardia en prácticas de Theramore	
4979	Guardia de Theramore	
5044	Tramador de Theramonte	
5045	Soldado Hallan	
5046	Teniente Caldwell	
5057	Desertor de Theramore	
5085	Guardia del Punto Argos	
5086	Capitán del Punto Argos	
5089	Balos Jacken	
5090	Maestro de combate Szigueti	
5092	Guardia Lana	
5093	Guardia Narrisha	
5094	Guardia Tark	
5184	Argos de Theramore	
5185	Tiburón Martillo	
5199	Médico Tamberlyn	
5200	Médico Helaina	
5229	Ogro Gordunni	
5232	Tosco Gordunni	
5234	Aplastador Gordunni	
5236	Chamán Gordunni	
5237	Mago ogro Gordunni	Ogro mago Gordunni
5238	Maestro de batalla Gordunni	
5239	Señor de la magia Gordunni	
5240	Brujo Gordunni	
5241	Señor de la guerra Gordunni	
5244	Aguijonero Zukk'ash	
5245	Avispa Zukk'ash	
5246	Trabajador Zukk'ash	
5247	Tunelador Zukk'ash	
5249	Bastardo Zarpaleña	
5251	Trampero Zarpaleña	
5253	Tosco Zarpaleña	
5254	Místico Zarpaleña	
5255	Atracador Zarpaleña	
5258	Alfa Zarpaleña	
5260	Simio Groddoc	
5261	Atal'ai sometido	
5262	Tronador Groddoc	
5268	Oso Cueracero	
5272	Oso Cueracero grisáceo	
5274	Patriarca Cueracero	
5276	Duende dragón	
5278	Duende dardo	
5286	Corredor Dientelargo	
5287	Aullador Dientelargo	
5288	Dientelargo rabioso	
5292	Yeti Cicatriz Feral	
5293	Fierescara descomunal	Cicatriz Feral descomunal
5295	Cicatriz Feral iracundo	
5296	Yeti Estigmodio	Yeti Cicatriz de Rabia
5297	Ancestro Estigmodio	Ancestro Cicatriz de Rabia
5299	Estigmodio feroz	Cicatriz de Rabia feroz
5300	Hipogrifo Plumavieja	
5304	Alacervo Plumavieja	
5305	Tormento Rozapluma	Asaltacielo Plumavieja
5306	Patriarca Rozapluma	Patriarca Plumavieja
5307	Estridador del valle	
5308	Pícaro estridador del valle	Estridador del valle huido
5312	Lethlas	
5314	Phantim	
5317	Oráculo Jademir	
5319	Depositario arbóreo Jademir	
5320	Guardarrama Fuego de Jade	
5327	Quebrador Resptacostas	
5328	Videnista Reptacostas	
5331	Guerrero Crestafuria	
5332	Jinete de olas Crestafuria	
5333	Guardia serpiente Crestafuria	
5334	Myrmidón Crestafuria	
5335	Gritón Crestafuria	
5336	Hechicera Crestafuria	
5337	Sirena Crestafuria	
5343	Lady Szallah	
5345	Cabeza Diamante	
5346	Rugesangre el Acechador	
5347	Antilus el Surcador	
5349	Arash-ethis	
5350	Qirot	
5352	Viejo Tripasgrises	
5354	Núdor Fraterfolio	
5356	Gruñidor	
5357	Caminante de la tierra	Caminatierras
5358	Gigante del risco	
5359	Zancacostas	Zancaorillas
5360	Zancaprofunda	
5361	Asaltaolas	
5362	Arpía Nortearroyo	
5363	Malapluma Nortearroyo	
5364	Destripadora Nortearroyo	
5366	Clamaviento Nortearroyo	
5402	Khan Hratha	
5419	Basilisco Cristaldermo	
5420	Observador Cristaldermo	
5421	Petrificador Cristaldermo	
5422	Cazador escórpido	
5423	Colazote escórpido	
5424	Acechadunas escórpido	
5425	Llagapata famélica	
5426	Hiena Llagapata	
5427	Llagapata rabiosa	
5428	Roc	
5429	Roc de fuego	
5430	Roc abrasador	
5431	Planoleador	
5432	Planoleador gigante	
5434	Tiburón coralino	
5435	Tiburón de arena	
5441	Avispa Hazzali	
5450	Aguijonero Hazzali	
5451	Enjambrista Hazali	
5452	Trabajador Hazzali	
5453	Tunelador Hazzali	
5454	Atracador Hazzali	
5455	Avispa Centipaar	
5456	Aguijonero Centipaar	
5457	Enjambrista Centipaar	
5458	Trabajador Centipaar	
5459	Tunelador Centipaar	
5460	Atracador Centipaar	
5461	Elemental marino	Elemental de mar
5462	Rocío marino	Rocío del mar
5465	Enfurecedor de la tierra	
5466	Zancacostas	
5467	Habitante de las profundidades	
5469	Quebrantador de las dunas	
5471	Ogro Machacaduna	
5472	Déspota Machacaduna	
5473	Magro ogro Machacaduna	
5474	Tosco Machacaduna	
5475	Brujo Machacaduna	
5477	Noboru el Garrote	
5481	Colector de rocío Cardizal	
5485	Enraizador Cardizal	
5490	Cardizal nudoso	
5523	Kodo grupal de guerra	
5546	Bruto Zuul	
5547	Bruto Tharlak	
5600	Khan Dez'hepah	
5601	Khan Jehn	
5602	Khan Shaka	
5615	Pícaro Deambulador	Pícaro Vagayermo
5616	Ladrón Deambulador	Ladrón Vagayermo
5617	Mago oscuro Deambulador	Mago oscuro Vagayermo
5618	Bandido Deambulador	Bandido Vagayermo
5622	Ongeku	
5623	Asesino Deambulador	Asesino Vagayermo
5643	Tyranis Malem	
5645	Desollador Furiarena	
5646	Lanzahachas Furiarena	
5647	Clamafuegos Furiarena	
5682	Dalin Forjador	
5718	Rothos	
5760	Lord Azrethoc	
5766	Cachorro de la sabana	
5771	Jugkar Grim'rod	Jugkar Lug'vara
5785	Hermana Azote de Odio	
5786	Jalalanza	
5787	Déspota Emilgund	
5806	Aliado Antárbol	
5807	El Rastrillo	
5808	Señor de la guerra Kolkanis	
5822	Tejeyel Scronn	
5823	Despellejador de la Muerte	
5824	Capitán Colmillo Plano	
5826	Geoseñor motas	
5827	Brontus	
5828	Humar el Señor Orgulloso	
5829	Bufo el Molesto	
5830	Hermana Rathtalon	
5831	Velocrín	
5832	Silenciatruenos	
5833	Margol la Furiosa	
5834	Azzere el Filo del Cielo	
5835	Supervisor Asas	
5836	Ingeniero Giralesín	
5837	Brazorroca	
5838	Lanzarrota	
5839	Geólogo Hierro Negro	
5840	Vapoherrero Hierro Negro	
5841	Lanzapiedras	
5842	Takk el Saltarín	
5844	Esclavista Hierro Negro	
5846	Capataz Hierro Negro	
5850	Elemental llameante	
5852	Elemental inferno	Elemental del infierno
5853	Golen de guerra templado	
5854	Gólem de guerra pesado	
5855	Elemental de magma	
5856	Araña Cristalderma	
5857	Lavaraña abrasadora	Araña de lava abrasadora
5858	Lavaraña superior	Araña de lava superior
5859	Hagg Taurruina	
5860	Chamán Oscuro Crepuscular	
5861	Guardia de Fuego Crepuscular	
5862	Geomántico Crepuscular	
5863	Geosacerdote Gukk'rok	
5864	Suingart Cuerolanza	
5865	Dishu	
5881	Sicomoro maldito	
5890	Espíritu de Tierra Piedrarroja	
5893	Manifestación de fuego menor	
5894	Manifestación menor de agua corrupta	
5897	Espíritu de agua corrupto	
5915	Hermano Roblecuervo	
5916	Centinela Amarassan	
5917	Clara Charles	
5928	Alapenas	
5930	Hermana Riven	
5931	Supervisor Rigger	
5932	Capataz Latimillo	
5933	Achellios el Desterrado	
5934	Cuorevaja	
5935	Ojohierro el Invencible	
5937	Aguijón vil	
5952	Bruto del cubil	
5974	Ogro Fauzatroz	
5975	Mago ogro Fauzatroz	
5976	Tosco Fauzatroz	
5977	Destructor Fauzatroz	
5978	Brujo Machacamiedo	
5979	Perdido desdichado	
5981	Buscador de portales	
5982	Destripador negro	
5983	Escarbueso	
5984	Hiena risitas hambrienta	Hiena risitas famélica
5985	Hiena risitas	
5988	Aguijonero Scorpok	
5990	Basilisco Rocarroja	
5991	Vitropiel Rocarroja	
5992	Jabalí Cenicrín	
5993	Jabinferno	
5996	Minero de Nethergarde	
5997	Ingeniero de Nethergarde	
5998	Supervisor de Nethergarde	
5999	Soldado de Nethergarde	
6000	Clérigo de Nethergarde	
6001	Analista de Nethergarde	
6002	Vigía de la falla de Nethergarde	
6003	Oficial de Nethergarde	
6004	Cultor Sombra Jurada	
6005	Matón Sombra Jurada	
6006	Adepto Sombra Jurada	
6007	Déspota Sombraída	
6008	Brujo Sombraída	
6009	Tejedor de Tinieblas Sombraída	
6010	Can manáfago	
6011	Avizor guardia vil	
6020	Valvababosa Makrura	
6033	Furia de lago	
6069	Guardia Khan Maraudine	
6070	Consejera Khan Maraudine	
6071	Can de la Legión	
6072	Diathorus el Buscador	
6073	Infernal abrasador	
6087	Centinela de Astranaar	
6093	Jack Dentomuerto	
6113	Vejrek	
6115	Guardia maldito	
6116	Aparecida Altonato	
6117	Exanimato Altonato	
6118	Fantasma de Varo'then	
6123	Espía Hierro Negro	
6124	Capitán Beld	
6125	Sátiro Haldarr	
6126	Tramposo Haldarr	
6127	Jurapenas Haldarr	
6128	Vorlus Pezuñavil	
6129	Señor de la magia dracónico	
6130	Horrocrusto azul	
6131	Tejemagia dracónico	
6132	Servidor de Rajacieno	
6133	Sombra de Elura	
6135	Pinzador Arkkoran	
6136	Habitabosta Arkkoran	
6137	Tenazario Arkkoran	
6138	Oráculo Arkkoran	
6139	Rasante Nido Alto	
6140	Hetaera	
6141	Rasante Alargullo	
6143	Vasallo de Arkkoroc	
6144	Hijo de Arkkoroc	
6146	Rompedor del risco	
6147	Tronarisco	
6148	Caminarrisco	
6167	Matriarca Quimera	
6170	Gutspill	
6180	Asaltante Defias	
6184	Abrecaminos Fauces de Madera	
6185	Guerrero Fauces de Madera	
6186	Totémico Fauces de Madera	
6187	Vigía del cubil Fauces de Madera	
6188	Chamán Fauces de Madera	
6189	Ursa Fauces de Madera	
6190	Guerrero Látigo de Ira	
6193	Vociferadora Látigo de Ira	
6194	Guardia serpiente Látigo de Ira	
6195	Sirena Látigo de Ira	
6196	Mirmidón Látigo de Ira	
6198	Perito elfo de sangre	
6199	Reivindicador elfo de sangre	
6200	Sátiro Legashi	
6201	Pícaro Legashi	
6202	Clamainferno Legashi	
6208	Invasor Cueva Honda	
6209	Despojador Cueva Honda	
6210	Saqueador Cueva Honda	
6213	Invasor irradiado	
6221	Paria loco	
6231	Tecnobot	
6238	Will el Grande	
6239	Ciclonio	
6347	Vándalo marino joven	
6348	Vándalo marino	
6349	Gran vándalo marino	
6350	Zarpador Makrinni	
6351	Oráculo de la Bahía Tormentosa	
6352	Rondador Corazacoral	
6369	Tortuga Corazacoral	
6370	Escarbador Makrinni	
6371	Guerrero de la Bahía Tormentosa	
6372	Quebrador Makrinni	
6375	Hipogrifo Tronatesta	
6377	Alacervo Tronatesta	
6378	Asaltacielo Tronatesta	
6379	Patriarca Tronatesta	
6380	Consorte Tronatesta	
6390	Ulag el Cuchillero	
6391	Guerrero Negador	
6494	Tazan	
6498	Demosaurio	
6499	Demosaurio Pielférrea	
6500	Demosaurio Tirano	
6501	Stegodon	
6502	Estegodón escamado	
6503	Estegodón de púas	
6504	Estegodón Tronavapuleus	
6505	Ravasaurio	
6506	Corredor Ravasaurio	
6507	Cazador ravasaurio	
6508	Ravasaurio Pellejo Venenoso	
6509	Azotador Sangrepétalo	
6510	Despellejador Sangrepétalo	
6511	Trillador Sangrepétalo	
6512	Trampero Sangrepétalo	
6513	Vapuleador de Un'Goro	
6514	Gorila de Un'Goro	
6516	Tronador de Un'Goro	
6517	Bestia Tar	Bestia de alquitrán
6518	Rondador Tar	Rondador de alquitrán
6519	Señor Tar	Señor de alquitrán
6520	Elemental agostador	
6521	Llamarada viviente	
6523	Fusilero Hierro Negro	
6527	Trepador Tar	Trepador de alquitrán
6547	Víctima sufrida	
6549	Demonio del orbe	
6550	Oleada de maná	
6551	Avispa Gorishi	
6552	Trabajador Gorishi	
6553	Atracador Gorishi	
6554	Aguijonero Gorishi	
6555	Tunelador Gorishi	
6556	Moco muculento	
6557	Moco primigenio	
6559	Moco glutinoso	
6560	Guardián de piedra	
6570	Fenwick Thatros	
6581	Matriarca ravasaurio	
6582	Madrezarpa Zavas	
6583	Gruff	
6584	Rey Mosh	
6585	Uhk'loc	
6606	Sobrestante Glibby	
6607	Harroc	
6646	Monnos el Viejo	
6647	Magistrix Yelmalcón	
6648	Antilos	
6649	Lady Sesspira	
6650	General Colmiterror	
6651	Guardián Gruñefuria	
6652	Maestro Pavoria	
6668	Lord Cyrik Forjanegra	
6670	Ebanista de los Páramos de Poniente	
6732	Amie Pierce	
6733	Partecaras Grutacanto	
6787	Yelnagi Brazonegro	
6788	Madre del cubil	
6789	Cachorro Cardo	
6846	Maestro de embarcadero Defias	
6866	Guardaespaldas Defias	
6909	Sethir el Ancestro	
6911	Esbirro de Sethir	
6927	Trabajador de embarcadero Defias	
7015	Flagglemurk el Cruel	
7016	Lady Vespira	
7017	Lord Sesgapecados	
7025	Soldado Roca Negra	
7026	Hechicero Roca Negra	
7027	Destripador Roca Negra	
7028	Brujo Roca Negra	
7029	Maestro de batalla Roca Negra	
7031	Elemental obsidiana	
7032	Elemental obsidiano superior	
7033	Ogro Pirontraña	
7034	Ogro mago Pirontraña	
7035	Tosco Pirontraña	
7036	Espía Thaurissan	
7037	Caminafuego Thaurissan	
7038	Agente Thaurissan	
7039	Atracador de guerra	
7040	Dragauro negro	
7041	Verminte negro	
7042	Dragauro Flamaescama	
7043	Verminte Flamaescama	
7044	Draco negro	
7045	Draco hirviente	
7046	Draco llamascama	
7047	Estirpe negra	
7048	Estirpe hirviente	
7049	Cachorrillo flamascala	Estirpe Flamaescama
7050	Zángano Defias	
7051	Zángano defias deformado	
7052	Guardia de torre Defias	
7053	Klaven Mortoalerta	
7055	Huargo Roca Negra	
7056	Torrero Defias	
7057	Maestro de excavación Palatiro	
7067	Zángano de Ventura y Cía.	
7068	Acólito condenado	
7069	Monje condenado	
7070	Clérigo condenado	
7071	Paladín maldito	
7072	Justicar maldito	
7075	Mago en pena	
7086	Moco maldito	
7092	Moco corrupto	
7093	Moco malvado	
7097	Lechuza Cortezaférrea	
7098	Estridador Cortezaférrea	
7099	Cazador Cortezaférrea	
7100	Arrancamusgo Alabeo	
7101	Machacador Alabeo	
7104	Dessecus	
7105	Sátiro Fuego de Jade	
7106	Pícaro Fuego de Jade	
7107	Timador Fuego de Jade	
7108	Traidor Fuego de Jade	
7109	Jurapenas Fuego de Jade	
7110	Acechasombras Fuego de Jade	
7111	Clamainferno Fuego de Jade	
7112	Cultor Jaedenar	
7113	Guardián Jaedenar	
7114	Déspota Jaedenar	
7115	Adepto Jaedenar	
7118	Tejeoscuro Jaedenar	
7120	Brujo Jaedenar	
7125	Can Jaedenar	
7126	Cazador Jaedenar	
7132	Horror tóxico	
7135	Guardaespaldas Infernal	
7136	Avizor infernal	
7137	Immolatus	
7138	Errante Troncoferro	
7139	Vapuleador Troncoferro	
7149	Protector marchito	
7153	Guerrero Muertobosque	
7154	Jardinero Muertobosque	
7155	Abrecaminos Muertobosque	
7156	Vigía del cubil Muertobosque	
7157	Vengador Muertobosque	
7158	Chamán Muertobosque	
7167	Polly	
7168	Polly	
7233	Capataz Burbujita	
7234	Ferocitas el Comesueños	
7235	Místico Tuercepinos	
7287	Supervisor Silixiz	
7288	Gran Supervisor Puzik Gallywix	
7307	Vigía de Ventura y Cía.	
7308	Patrulla de Ventura y Cía.	
7310	Zángano mutado de Ventura y Cía.	
7318	Garrafuria	
7319	Lady Sathrah	
7327	Guerrero marchito	
7332	Cuerolanza marchito	
7335	Geomántica Caramuerte	
7360	Soldado de Dun Garok	
7369	Tosco Vientomuerto	
7370	Sombra inquieta	
7371	Destructor Vientomuerto	
7372	Brujo Vientomuerto	
7376	Sombra de los cielos	
7379	Mago ogro Vientomuerto	
7404	Guardia Flama Galak	
7428	Gigante Machacahielo	
7429	Valedor Machacahielo	
7430	Cachorro sable de hielo	
7431	Sable de Hielo	
7432	Acechador Sable de Hielo	
7433	Cazadora Sable de Hielo	
7434	Vigilorgullo Sable de Hielo	
7435	Verminte de cobalto	
7436	Horrocrusto de cobalto	
7437	Tejemagia de cobalto	
7438	Ursa Nevada	
7439	Chamán Nevada	
7440	Vigilante del cubil Nevada	Vigía del cubil Nevada
7441	Totémico Nevada	
7442	Abrecaminos Nevada	
7443	Destructor dentoesquirla	
7444	Oso Dentoesquirla	
7445	Dentoesquirla anciano	
7446	Dentoesquirla rabioso	
7447	Volantón Viento Gélido	
7448	Quimera Viento Gélido	
7449	Devastador Viento Gélido	
7450	Lechubestia pulgosa	
7451	Lechubestia enfurecida	
7452	Lechubestia enloquecida	
7453	Lechubestia lunadón	
7454	Lechubestia rabiosa	
7455	Lechuza invernal	
7456	Estridador invernal	
7457	Cardo Nevado huido	
7458	Yeti Cardo Nevado	
7459	Matriarca Cardo Nevado	
7460	Patriarca Cardo Nevado	
7461	Iniciado Hederine	
7462	Acechamaná Hederine	
7463	Destripador Hederine	
7523	Altonato sufrido	
7524	Altonato angustiada	
7584	Caminabosques deambulante	
7664	Razelikh el Envilecido	Razelikh el Rapiñador
7665	Grol el Destructor	
7666	Archimago Allistarj	
7667	Lady Sevine	
7668	Sirviente de Razelikh	
7669	Vasallo de Grol	Sirviente de Grol
7670	Sirviente de Allistarj	
7671	Vasallo de Sevine	Sirviente de Sevine
7725	Asaltante Tótem Siniestro	
7726	Naturalista Tótem Siniestro	
7727	Chamán Tótem Siniestro	
7728	Kirith el Maldito	
7732	Chinche engañosa	
7734	Ilifar	
7735	Felcular	
7767	Manáfago Secacorteza	
7768	Sangrador Secacorteza	
7805	Revuelvebasura Deambulador	
7808	Lechubestia merodeadora	
7809	Emboscador Vilrama	
7843	Evacuado de Gnomeregan	
7846	Teremus el Devorador	
7847	Caliph Escorpijón	Califa Escorpijón
7848	Cicatriz Feral acechante	
7851	Élite de Nethergarde	
7855	Pirata del Mar del Sur	Pirata de los Mares del Sur
7856	Filibustero del Mar del Sur	Filibustero de los Mares del Sur
7857	Portuario del Mar del Sur	Portuario de los Mares del Sur
7858	Aventurero del Mar del Sur	Espadachín de los Mares del Sur
7864	Altonato persistente	
7872	Cultor Caramuerte	
7873	Guardia de batalla de Rajacieno	
7874	Tejespina de Rajacieno	
7883	Andre Barbafuego	
7885	Maestra de batalla Látigo de Ira	
7886	Encantadora Látigo de Ira	
7895	Embajador Sanguinarius	
7899	Pirata Cazatesoros	
7901	Aventurero Cazatesoros	
7902	Bucanero Cazatesoros	
7939	Centinela Plumaluna	
7975	Protector de Mulgore	
7977	Gammerita	
7980	Élite Guardia de la Muerte	
7995	Sacerdotisa Vil Hexx	Sacerdotisa vil Hexx
7996	Qiaga el Vigilante	Qiaga la Vigilante
7997	Duende lanzadardos capturado	
8016	Guarda de los Baldíos	
8023	Picoafilado	
8075	Edana Garraodio	Edana Garfaodio
8136	Lord Shalzaru	
8154	Valiente del Espíritu Errante	
8155	Bruto Kargath	
8199	Líder de guerra Krazzilak	
8200	Jin'Zallah el Arenero	
8201	Omgorn el Perdido	
8202	Cyclok el Loco	
8203	Kregg Volcayecto	
8204	Soriid el Devorador	
8205	Haarka el Voraz	
8207	Pájaro de fuego superior	
8208	Llagapata mortífera	
8210	Filogarra	
8211	Viejo Saltariscos	
8212	El Rik	
8213	Espaldacerada	
8215	Grimungus	
8216	Retherokk el Rabioso	
8217	Mith'rethis el Encantador	
8218	Blancorazón el Acechador	
8219	Matagallinas Zul'arek	
8236	Furia de fango	
8277	Rekk'tilac	
8278	Smoldar	
8279	Gólem de guerra defectuoso	
8280	Shleipnarr	
8281	Escaldar	
8282	Alto señor Mastrogonde	
8283	Maestro de esclavos Negrozón	
8296	Mojo el Retorcido	
8297	Magronos el Implacable	
8298	Akubar el Vidente	
8299	Escupetripas	
8300	Devastatia	
8301	Clack el Atracador	
8302	Ojo de la Muerte	
8303	Gruñón	
8304	Desdeñamiedos	
8337	Acerador Hierro Negro	
8391	Lathoric el Negro	
8400	Obsidion	
8408	Señor de la Guerra Krellian	
8409	Maestro de caravana Tset	
8419	Idólatra Crepuscular	
8442	Furtivo Sedaumbría	
8444	Maestro de comercio Kovic	
8447	Clonk	
8503	Gibblewilt	
8504	Avizor Hierro Negro	
8519	Marea contagiada	
8520	Devastador de peste	
8521	Horror contagiado	
8522	Monstruosidad de peste	
8523	Soldado de la Plaga	
8524	Mago maldito	
8525	Depositario de la Plaga	
8526	Taumaturgo oscuro	
8527	Guardia de la Plaga	
8528	Tejedor aterrador	
8529	Campeón de la Plaga	
8530	Necrófago caníbal	
8531	Necrófago balbuceante	
8532	Despellejador malsano	
8534	Gárgola pútrida	
8535	Chillón pútrido	
8538	Sirviente oculto	
8539	Vigilante Sinojos	Vigía sin ojos
8540	Gritona desgarrada	
8541	Chillona de odio	
8542	Trovamuerte	
8543	Horror cosido	
8544	Gólem Ganglioso	
8545	Abominación	
8546	Adepto oscuro	
8547	Fiel de la Muerte	
8548	Tutor vil	
8550	Mago oscuro	
8551	Invocador oscuro	
8553	Necromántico	
8554	Jefe Cornapunta Mantospina	
8555	Mefisto de la cripta	
8556	Caminante de la cripta	
8557	Horror de la cripta	
8558	Destripador de la cripta	
8560	Explorador Fustamusgo	
8561	Cazasombras Fustamusgo	
8562	Caníbal Fustamusgo	
8563	Trabajador forestal	
8564	Especialista	Forestal
8565	Zancamino	
8566	Vigía Hierro Negro	Oteador Hierro Negro
8578	Magus Rimtori	
8596	Cachorro de can de peste	
8597	Can de peste	
8598	Can de peste demenciado	
8600	Murcipeste	
8601	Murcipeste nocivo	
8602	Murcipeste monstruoso	
8603	Larva carroñera	
8605	Devorador carroñero	
8606	Pútrido viviente	
8607	Lodo en podredumbre	
8636	Morta'gya el Vigilante	
8637	Vigilante Hierro Negro	
8660	El Evalcharr	
8667	Vórtice ráfaga	
8675	Bestia vil	
8716	Señor del Terror	
8717	Élite guardia vil	
8718	Can de maná	
8759	Corredor Pezuñamusgo	
8760	Venado Pezuñamusgo	
8761	Trotador Pezuñamusgo	
8762	Ermitaña Telamadera	
8763	Pícaro Brumala	
8764	Devastador Brumala	
8766	Moco del bosque	
8837	Salpicadura de mugre	
8956	Oso Zarpira	
8957	Pardo Zarpira	
8958	Aplastador Zarpira	
8959	Lobo Zarpayel	
8960	Carroñero Zarpayel	
8961	Devastador Zarpayel	
8976	Hematos	
8977	Krom'Grul	
8978	Thauris Balgarr	
8979	Gruklash	
8981	Atracador estropeado	
8996	Esbirro abisario	
9157	Peste pétalo de sangre	
9162	Diemetradón joven	
9163	Diemetradón	
9164	Diemetradón viejo	
9165	Pterrordáctilo volantón	
9166	Pterrordáctilo	
9167	Pterrordáctilo demenciado	
9176	Gor'tesh	
9318	Incendosaurio	
9336	Jefe Encobre	
9376	Correfuego	
9377	Vórtice espiral	
9396	Aporreador de tierra	
9397	Tormenta viviente	
9447	Depositario Escarlata	
9448	Pretoriano Escarlata	
9449	Clérigo Escarlata	
9450	Curador Escarlata	
9451	Archimago Escarlata	
9452	Encantador Escarlata	
9453	Aquementas	
9454	Xavathras	
9456	Señor de la Guerra Krom'zar	
9461	Draco Negro demenciado	
9462	Cabecilla Sangrefauce	
9464	Señor supremo Ror	
9477	Moco clonado	
9516	Lord Pesadilla	
9517	Señor de las Sombras Fel'dan	
9518	Rakaiah	
9522	Emboscador Roca Negra	
9523	Videntormento Kolkar	
9524	Invasor Kolkar	
9525	Valiente Librevento	
9602	Hahk'Zor	
9604	Gorgon'och	
9622	U'cha	
9683	Amigo de Lar'korwi	Compañera de Lar'korwi
9684	Lar'korwi	
9690	Lupo Brasal	
9691	Escórpido Venopunta	
9694	Huargo brasal babeante	
9695	Escórpido Latimorte	
9697	Lupo Magnasaliza	
9698	Escórpido Colafuego	
9776	Escupidor flamante	
9777	Duente flamante	
9778	Incendiario flamante	
9779	Furibundo flamante	
9860	Salia	
9861	Moora	
9862	Legionario Jaedenar	
9877	Príncipe Xavalis	
9878	Bestia entrópica	
9879	Horror entrópico	
9916	Jarquia	
10036	Déspota Murelecho	
10077	Faucemuerte	
10078	Chispa terrorífica	
10119	Volchan	
10157	Oráculo lechúcico lunar	
10158	Lechúcico lunar	
10159	Lechúcico lunar joven	
10160	Lechúcico lunar enfurecido	
10196	General Colbatann	
10197	Mezzir el Aullador	
10198	Kashoch el Atracador	
10199	Pardo Patanieve	
10200	Rak'shiri	
10201	Lady Hederine	
10202	Azurous	
10321	Brasaliza	
10323	Viscoso	
10356	Bayne	
10357	Ressan el Agujas	
10358	Sombra de Felicent	
10359	Sri'skulk	
10373	Xabraxxis	
10556	Peón vago	
10559	Lady Vespia	
10580	Zombi fétido	
10605	Médico Escarlata	
10608	Sacerdote Escarlata	
10612	Guardia Wachabe	
10617	Mensajero Galak	
10636	Manada de kodos	
10639	Rorgish Jowl	
10640	Pataroble	
10641	Quebrarramas	
10642	Eck'alom	
10643	Aletereje	
10644	Aullanieblas	
10647	Príncipe Raze	
10648	Xavaric	
10659	Cría de cobalto	
10660	Estirpe de cobalto	
10661	Zampaconjuros	
10662	Hechifauces	
10663	Zarpamaná	
10664	Arúspice	
10676	Asaltante Jhash	
10682	Asaltante Kerr	
10696	Defensor de Refugio de la Zaga	
10698	Zombi invocado	
10717	Parásito temporal	
10720	Asesino Galak	
10721	Guerrero novicio	
10737	Shi-Rotam	
10738	Gran Jefe Nevada	
10741	Sian-Rotam	
10756	Elemental hirviente	
10757	Elemental de ebullición	
10758	Bandido Tótem Siniestro	
10759	Vapuleador Tótem Siniestro	
10760	Geomántico Tótem Siniestro	
10761	Atracador Tótem Siniestro	
10801	Necrófago farfullante	
10802	Hitah'ya la Guardiana	
10803	Fusilero Trapis	
10804	Fusilero de mediocampo	
10805	Avistador Klemmy	
10806	Ursius	
10807	Brumerán	
10816	Esqueleto deambulante	
10817	Duggan Martillo Salvaje	
10821	Hed'mush el Podrido	
10822	Señor de la guerra Thresh'jin	
10823	Ramurdimbre Zul'Brin	
10824	Señor forestal Lanzalcón	
10825	Gish el Inamovible	
10826	Lord Hoz Oscura	
10827	Portavoz de la muerte Selendre	
10828	Alta general Abbendis	
10836	Granjero Dalson	
10896	Arnak Tótem Siniestro	
10916	Corredor Nevada	
10919	Trol Rompelanzas	
10928	Esbirro súcubo	
10946	Horgus el Devastador	
10979	Can Escarlata	
10992	Pantera iracunda	
10996	Héroe caído	
11075	Señor de la caldera Garravil	
11076	Señor de la caldera Razarch	
11077	Señor de la caldera Molevolus	
11078	Señor de la caldera Iralma	
11196	Tamborillero Rompelanzas	
11198	Exiliado Draenei	
11276	Centinela de Azshara	
11284	Sombra oscura	
11288	Traidor espectral	
11290	Zombi Fustamusgo	
11291	Arrancamusgo sin vida	
11328	Campesino de de la Vega del Este	
11346	Oráculo Hakkari	
11355	Guerrero Gurubashi	
11383	Suma Sacerdotisa Hai'watna	
11440	Déspota Gordok	
11442	Aplastador Gordok	
11443	Ogro mago Gordok	
11498	Skarr el Inquebrantable	
11516	Depositario Fauces de Madera	
11552	Místico Fauces de Madera	
11553	Doblatroncos Fauces de Madera	
11555	Monóculo de Gorn	
11557	Meilosh	
11558	Kernda	
11559	Necromántico paria	
11560	Espectro Magrami	
11561	Devastador no-muerto	
11562	Reptador Golpeseco	
11563	Tenazario Golpeseco	
11576	Desgarrador espirálico	
11577	Caminatormentas espirálico	
11578	Machacador espirálico	
11611	Hidalgo Durgen	
11613	Cazador Radley	Montero Radley
11614	Tirosangre	
11620	Maleante espectral	
11621	Cadáver espectral	
11656	Peón de la Horda	
11680	Explorador de la Horda	
11681	Deforestador de la Horda	
11682	Bruto de la Horda	
11683	Chamán de la Horda	
11684	Machacador Grito de Guerra	
11685	Sacerdote Maraudine	
11686	Asaltante fantasmal	
11687	Maleante fantasmal	
11688	Centauro maldito	
11697	Mannoroc Latiguez	
11698	Aguijonero Colmen'Ashi	
11714	Marosh el Taimado	
11721	Trabajador Colmen'Ashi	
11722	Defensor Colmen'Ashi	
11723	Acecharenas Colmen'Ashi	
11724	Enjambrista Colmen'Ashi	
11725	Vigía de Colmen'Zora	Oteador de Colmen'Zora
11726	Tunelador Colmen'Zora	Tunelador de Colmen'Zora
11727	Avispa Colmen'Zora	Avispa de Colmen'Zora
11728	Atracador Colmen'Zora	Atracador de Colmen'Zora
11729	Hermana de colmena Colmen'Zora	Hermana de colmena de Colmen'Zora
11730	Emboscador Colmen'Regal	
11731	Perforador Colmen'Regal	
11732	Escupefuego Colmen'Regal	
11733	Esclavizador Colmen'Regal	
11734	Señor Colmen'Regal	
11735	Escórpido Latigosólido	Escórpido Latipiedra
11736	Tnazario Latigosólido	Tenazario Latipiedra
11737	Cazador Latigosólido	Despellejador Latipiedra
11738	Arácnido de arena	
11739	Acechador de piedra	Acecharrocas
11740	Artillero de arrastre	Asediador deslizante
11741	Triturador de arrastre	Triturador deslizante
11744	Sirocoso	Agitador sirocoso
11745	Guerrero ciclónico	
11746	Estruendor del desierto	
11747	Enfurecedor del desierto	
11777	Estruendor Fragmento Oscuro	
11778	Quebrantador Fragmento Oscuro	
11781	Triturador Ambarastilla	
11782	Destructor Ambarastilla	
11785	Basilisco Ambarojo	
11786	Atracador Ambarojo	
11787	Cavapiedras	
11788	Gusano de piedra	
11803	Guardián Crepuscular Exeter	
11804	Guardián Crepuscular Havunth	
11817	Krah'ranik	
11819	Jory Zaga	
11858	Grundig Nube Negra	
11873	Auxiliar espectral	
11876	Espíritu demoníaco	
11880	Vengador Crepuscular	
11881	Geoseñor Crepuscular	
11882	Clamapiedras Crepuscular	
11883	Maestro Crepuscular	
11885	Can de añublo	
11886	Mercutio Comerroña	
11887	Ladrón de la cripta	
11896	Borelgore	
11897	Alaocaso	
11898	Señor Cruzado Valdemar	
11910	Rufián Tótem Siniestro	
11911	Mercenario Tótem Siniestro	
11912	Tosco Tótem Siniestro	
11913	Hechicero Tótem Siniestro	
11914	Pezuñasangre el Negro	
11915	Vigilapedras Gogger	
11917	Geomántico Gogger	
11918	Machacapedras Gogger	
11920	Goggeroc	
11921	Besseleth	
11937	Guardia del portal demoníaco	Guardián del portal de demonios
11979	Kim Bridenbecker	
11994	Rob Bridenbecker	
12037	Ursol'lok	
12046	Gor'marok el Devastador	
12047	Montaraz de Pico Tormenta	
12123	Tiburón de arrecifes	
12124	Gran tiburón	
12125	Tiburón mamut	
12128	Élite Carmesí	
12160	Centinela de Cañada Umbría	
12178	Druida torturado	
12179	Centinela torturada	
12199	Sombra de Lunámbar	
12248	Infiltrado Hameya	
12250	Zaeldarr el Marginado	
12261	Arrancamusgo infectado	
12262	Protector Ziggurat	
12263	Protector del matadero	
12299	Ciervo curado	
12319	Toxicólogo Filo Ardiente	
12320	Triturador Filo Ardiente	
12321	Toxicólogo Escama Tormentosa	
12322	Protector Quel'Lithien	
12337	Mensajera Carmesí	
12339	Demetria	
12347	Reptador Correarrecifes iracundo	
12369	Lord Kragaru	
12377	Espectro de los Lamentos	
12378	Alma maldita	
12379	Custodio sin vida	
12380	Residente sin vida	
12387	Gran babosa vil	
12396	Comandante guardia apocalíptico	
12397	Lord Kazzak	
12418	Hiena Gordok	
12423	Guardia Roberts	
12427	Montaraz Dolf	
12428	Guardia de la Muerte Kel	
12429	Centinela Shaya	
12430	Bruto Kor'ja	
12431	Mandisangre	
12432	Viejo Malafauce	
12433	Krethis Tejeumbra	
12474	Guardarrama Emeraldón	
12475	Depositario de árbol Emeraldon	
12476	Oráculo Emeraldon	
12477	Guardarrama Verdantine	
12478	Oráculo Verdantine	
12479	Guardárbol Verdantine	
12496	Rastreasueños	
12497	Bramasueños	
12498	Acechasueños	
12579	Desgarrador Furia Sangrienta	Desgarradora Furia Sangrienta
12676	Garrafilada	Garfafilada
12759	Tideress	Marearess
12800	Quimerok	
12801	Quimerok Arcano	
12802	Devorador quimerok	
12803	Lord Lakmaeran	
12856	Avanzado de Vallefresno	Avanzada de Vallefresno
12859	Asaltante del Hachazo	
12860	Duriel Fuegolunar	
12865	Embajador Malcin	
12896	Centinela Ala de Plata	
12897	Guerrero Ala de Plata	
12899	Axtroz	
12900	Somnus	
12903	Guardia del Hachazo	
12918	Jefe Murgut	
12923	Soldado malherido	
12924	Soldado con graves heridas	
12925	Soldado gravemente herido	
12936	Soldado de la Alianza muy herido	
12937	Soldado de la Alianza gravemente herido	
12938	Soldado de la Alianza malherido	
12940	Vorsha la Azotadora	
12976	Abrecaminos Kolkar	
12977	Emboscador Kolkar	
12998	Granjero enano	
13019	Vidente Filo Ardiente	
13096	Expedicionario Minafría	
13118	Guardaespaldas Carmesí	
13136	Zángano Colmen'Ashi	
13157	Makasgar	
13158	Teniente Sanders	
13159	James Clark	
13277	Dahne Pierce	
13279	Invasor discordante	
13301	Emboscador Colmen'Ashi	
13602	Grinch el Abominable	
13718	El profeta sin nombre	
13740	Magra	
13741	Gelk	
13742	Kolk	
13836	Pesadilla Filo Ardiente	
13837	Semental capturado	
13896	Barbascamas	
14123	Sacudidor Mandiacero	
14221	Gravis Nudocorredizo	
14222	Araga	
14223	Cascarrabias Ben	
14225	Príncipe Kellen	
14226	Kaskk	
14227	Hissperak	
14228	Mueca	
14229	Filozante detestable	
14230	Ojo Ladrón	
14231	Drogoth el Vagabundo	
14232	Dardo	
14233	Rasgascama	
14234	Hayoc	
14236	Señor Pescador	
14237	Mocogusano	
14266	Shanda la Giratoria	
14267	Emogg el Triturador	
14268	Lord Condar	
14269	Buscador Aqualon	
14270	Squiddic	
14271	Rompecostillas	
14272	Llamagruños	
14273	Corapetra	
14275	Tamra Pico Tormenta	
14276	Rasgabranquia	
14277	Lady Zephris	
14278	Ro'Bark	
14279	Trepazoso	
14280	Gran Samras	
14281	Jimmy el Sangrador	
14284	Guardia de batalla de Pico Tormenta	
14285	Guardia de batalla Lobo Gélido	
14339	Aullador de la Muerte	
14340	Alshirr Respiramiedo	
14342	Patafuria	
14344	Mongress	
14345	El Ongar	
14356	Demente Sierraleta	
14357	Trillador del Lago	
14388	Pícaro Draco Negro	
14390	Montaraz expedicionario	
14393	Sacerdote expedicionario	
14424	Lodonante	
14425	Roehuesos	
14426	Harb Monte Fétido	
14427	Gibblesnik	
14428	Uruson	
14429	Faucenestra	
14430	Acechapolvo	
14431	Furia Shelda	
14432	Threggil	
14433	Barrosín	
14445	Lord capitán Wyrmak	
14446	Fingat	
14447	Gilmorian	
14448	Fundespino	
14454	El Atracavientos	
14455	Invasor giratorio	
14457	Princesa Tempestria	
14458	Invasor acuático	
14460	Invasor de fuego	
14461	Barón Charr	
14462	Invasor tronador	
14464	Avalanchion	
14467	Kroshius	
14471	Setis	
14472	Gretheer	
14473	Lapress	
14474	Zora	
14475	Rex Ashil	
14476	Krellack	
14477	Grubthor	
14478	Huricanian	
14479	Señor Crepuscular Everun	
14487	Gluggle	
14488	Roloch	
14490	Rippa	
14491	Kurmokk	
14522	Ur'dan	
14523	Ulathek	
14564	Espíritu del Valle del Terror	
14603	Zancacostas machacado	
14604	Caminatierras machacado	
14621	Sobrestante Maltorius	
14638	Asaltaolas machacado	
14639	Zancahonda machacado	Zancaprofunda machacado
14640	Gigante del Acantilado machacado	
14661	Aguijolatigador	Latigador con aguijón
14715	Élite Ala de Plata	
14718	Obrero de la Horda	
14730	Vigilante Sañadiente	
14734	Tamborillero Sañadiente	
14748	Secuestrador Vilrama	
14857	Erk	
14859	Guardia Taruc	
14862	Emisario Roman'khan	
14872	Trok	
14887	Ysondre	
14888	Lethon	
14889	Emeriss	
14890	Taerar	
14893	Guardia Kurall	
14901	Peón	
14909	Poká	
15128	Élite Rapiñador	
15130	Élite de la Liga de Arathor	
15162	Inquisidor Escarlata	
15196	Pinzamorten	
15200	Guardiana Crepuscular Mayna	
15201	Flamatracador Crepuscular	
15202	Vyral el Vil	
15203	Príncipe Skaldrenox	
15204	Alto mariscal Eje Torbellino	
15205	Barón Kazum	
15206	Duque de las Brasas	
15207	Duque de las Profundidades	
15208	Duque de las Esquirlas	
15209	Templario Carmesí	
15211	Templario azur	
15212	Templario vetusto	
15213	Señor supremo Crepuscular	
15220	Duque de los Céfiros	
15305	Lord Skwol	
15307	Templario de tierra	Templario terráneo
15308	Profeta Crepuscular	
15441	Fusilero de la Brigada de Forjaz	
15442	Lacayo de la Brigada de Forjaz	
15541	Maleante Crepuscular Morna	
15542	Maleante Crepuscular	
15552	Doctor Weavil	
15554	Número dos	
15591	Esbirro de Weavil	
15616	Bruto de la Legión de Orgrimmar	
15617	Lanzahachas de la Legión de Orgrimmar	
15625	Corrupto Crepuscular	
15685	Secuestrador de los Mares del Sur	
15692	Secuestrador Hierro Negro	
15712	Montón de barro	
16043	Señor del Magma Bokk	
16072	Señor de las Mareas Rrurgaz	
16096	Truhán	
16117	Cerdo infestado	
16184	Sobrestante Nerubiano	
16392	Capitán Armando Ossex	
16479	Clon polimórfico	
17068	Jefe de requisas de expedición Enkles	
17070	Boticario Quinard	
17765	Centinela de silitista de la Alianza	
17766	Centinela de silitista de la Horda	
]],
	quest = [[
2	La garra de Garrafilada	La garfa de Garrafilada
5	La hambruna de Gato	La hambruna de Alterio
6	La recompensa por Garrick Piesuaves	
7	La limpieza del campamento kóbold	
8	Un trato de pícaro	
9	Campos de la muerte	
10	La redención de Patagolpe	
11	Recompensas por los gnolls Zarparrío	
12	Las Milicias del Pueblo	La Milicia Popular
13	Las Milicias del Pueblo	La Milicia Popular
14	Las Milicias del Pueblo	La Milicia Popular
15	Investiga la Mina del Eco	
17	Componentes de Uldaman	
18	Hermandad de ladrones	
19	Tharil'zun	
20	La amenaza de los Roca Negra	
21	Escarmuza en la Mina del eco	Refriega en el Eco
22	Pastel de hígado de dentosangre	
23	La zarpa de Ursangous	La pata de Ursangous
24	La cabeza de Shadumbra	
25	Paso del Espolón bloqueado	Paralización en Espolón
28	La prueba del lago	
29	La prueba del lago	
30	La prueba del león marino	
31	Forma acuática	
32	La sublevación de los silítidos	
33	Los lobos cruzan la frontera	Lobos en la frontera
34	Una visita poco grata	
35	Más preocupaciones	
36	Estofado de los Páramos de Poniente	
37	Encuentra a los guardias perdidos	
38	Estofado de los Páramos de Poniente	
39	Entrega el informe de Thomas	
40	Un peligro con olor a pescado	
45	Descubre el destino de Rolf	
46	Recompensas por los murlocs	Recompensas por los múrlocs
47	Intercambio de polvo de oro	
48	Dulce ámbar	
49	Dulce ámbar	
50	Dulce ámbar	
51	Dulce ámbar	
52	Proteger la frontera	
53	Dulce ámbar	
54	Informa en Villadorada	
55	Morbent Vil	
56	Vigilancia nocturna	La Guardia Nocturna
57	Vigilancia nocturna	La Guardia Nocturna
58	Vigilancia nocturna	La Guardia Nocturna
59	Armadura de tela y cuero	Armadura de paño y cuero
60	Las velas de los kóbolds	
61	Un envío para Ventormenta	
62	La Mina Abisal	
63	La llamada del agua	
64	La reliquia olvidada	
65	La hermandad de los Defias	
66	La leyenda de Stalvan	
67	La leyenda de Stalvan	
68	La leyenda de Stalvan	
69	La leyenda de Stalvan	
70	La leyenda de Stalvan	
71	Informa a Thomas	
72	La leyenda de Stalvan	
74	La leyenda de Stalvan	
75	La leyenda de Stalvan	
76	La Cantera de Jaspe	
77	Una situación peliaguda	
78	La leyenda de Stalvan	
79	La leyenda de Stalvan	
80	La leyenda de Stalvan	
82	Investigación en la Guarida Ponzoñosa	
83	Artículos rojos de lino	
84	Vuelve con Billy	
85	El collar perdido	
86	Un pastel para Billy	
87	Dientes de oro	Dientes de Oro
88	¡Princesa debe morir!	
89	La reconstrucción del puente	El puente sempiterno
91	Ley de Salomón	Ley de Solomon
92	Estofado de Crestagrana	Estofado Crestagrana
93	Las croquetas de cangrejo	Los pasteles de cangrejo oscuro
94	Un ojo vigilante	
95	La venganza de Sven	
96	La llamada del agua	
97	La leyenda de Stalvan	
98	La leyenda de Stalvan	
99	La locura de Arugal	
100	La llamada del agua	
101	El Tótem de castigo	
102	En patrulla por Páramos de Poniente	En patrulla por los Páramos de Poniente
103	Guardián de la Llama	
104	La amenaza costera	
105	Ah, Andorhal	
106	Jóvenes enamorados	
107	Una nota para William	
109	Habla con Gryan Mantorrecio	
110	Análisis de trozos de insecto	
111	Habla con la abuelita	
112	La recolección de Kelp	La recolección de algas
113	Análisis de trozos de insecto	
114	La fuga	
115	Magia de las Sombras	
116	Tiempos de sequía	
118	El precio de unas herraduras	
119	Vuelve con Verner	Regresa junto a Verner
120	Mensajero a Páramos de Poniente	Mensajero a Ventormenta
121	Mensajero a Páramos de Poniente	Mensajero a Ventormenta
122	Escamas de barriga	
123	El Coleccionista	
124	El aullido de los gnolls	
125	Las herramientas perdidas	
126	El aullido de las colinas	
127	Pescado a la venta	
128	La recompensa de Roca Negra	
129	Una comida gratis	
130	Una visita al herborista	
131	Un ramo de narcisos	
132	La hermandad de los Defias	
133	Un espantapájaros para necrófagos	
134	Ladrones ogros	
135	La hermandad de los Defias	
136	El tesoro escondido del capitán Sanders	
138	El tesoro escondido del capitán Sanders	
139	El tesoro escondido del capitán Sanders	
140	El tesoro escondido del capitán Sanders	
141	La hermandad de los Defias	
142	La hermandad de los Defias	
143	Mensajero a Páramos de Poniente	Mensajero a los Páramos de Poniente
144	Mensajero a Villa Oscura	Mensajero a los Páramos de Poniente
145	Mensajero a Villa Oscura	
146	Mensajero a Villa Oscura	
147	La persecución	
148	Suministros de Villa Oscura	
149	Hilo de pelo de fantasma	Hilo de cabello de fantasma
150	Cazadores furtivos	
151	La pobre y vieja Blanchy	
152	Hay moros en la costa	
153	Pañuelos rojos de cuero	
154	Devuelve el peine	
155	La hermandad de los Defias	
156	Busca flores podridas	
157	Devolver el pelo	
158	Zumo de zombi	
159	Entrega de zumo	
160	Nota para el alcalde	
161	Se aproxima una oscura amenaza	
162	La sublevación de los silítidos	
163	Cerro del Cuervo	
164	Entrega a Sven	
165	El ermitaño	
169	Se busca: Gath'Ilzogg	
170	Una nueva amenaza	
173	Ferocanis en el bosque	Huargen en el bosque
174	Mira las estrellas	
175	Mira las estrellas	
176	Se busca: Hogger	
177	Mira las estrellas	
178	Theocritus recupera el colgante	
179	Los enanos modistos	
180	Se busca: teniente Fangore	Se busca: Teniente Fangore
181	Mira las estrellas	
182	La cueva de los trols	
183	Cazador de jabalíes	
184	La escritura de Furlbrow	Las escrituras de Cejade
185	Domina el tigre	
186	Maestría en tigres	
187	Domina el tigre	
188	Domina el tigre	
189	Orejas de Sangrapellejo	
190	Domina la pantera	
191	Domina la pantera	
192	Domina la pantera	Maestría en panteras
193	Domina la pantera	
194	Domina el raptor	
195	Domina el raptor	
196	Domina el raptor	
197	Domina el raptor	
198	Suministros para el soldado Thorsen	
199	Se aproxima una oscura amenaza	
200	Bookie Herod	Corredor Herod
201	Investiga el campamento	
202	Coronel Kurzen	
203	La segunda rebelión	
204	Mala medicina	
205	Brujería trol	
206	Mai'Zoth	
207	El misterio de Kurzen	
208	Caza mayor	
209	Colmillos de Machacacráneos	Colmillos Machacacráneos
210	La cocina de Krazek	
211	Ah, Andorhal	
213	OPA hostil	
215	Los secretos de la jungla	
216	Entre una roca y un Piel de Cardo	
217	En defensa de las tierras del rey	
218	El diario robado	
219	Desaparecido en combate	
220	La llamada del agua	
221	Ferocanis en el bosque	Huargen en el bosque
222	Ferocanis en el bosque	Huargen en el bosque
223	Ferocanis en el bosque	Huargen en el bosque
224	En defensa de las tierras del rey	
225	La lápida desgastada	
226	Con los lobos en los talones	
227	Morgan Ladimor	
228	Mor'Ladim	
229	La hija superviviente	
230	El campamento de Sven	
231	El amor de una hija	
233	Entrega de correo en el Valle de Crestanevada	
234	Entrega de correo en el Valle de Crestanevada	
237	En defensa de las tierras del rey	
239	El Cuartel de Arroyoeste necesita ayuda	
240	Entrega para Gato	Regresa junto a Alterio
243	In situ	
244	Gnolls invasores	
245	Las amenazas de ocho patas	
246	Evaluar la amenaza	
247	El fin de la Caza	
248	Ver más allá	
249	Morganth	
250	Se aproxima una oscura amenaza	
251	Traduce la nota de Abercrombie	
252	Una traducción para Ello	
253	La novia del embalsamador	
255	Mercenarios	
256	SE BUSCAN: Chok'sul	SE BUSCA: Chok'sul
257	La fanfarronada de un cazador	
258	El reto de un cazador	
261	El sendero Escarlata	
262	La figura en las sombras	
263	En defensa de las tierras del rey	
265	La búsqueda de la figura continúa	
266	Busqueda en la posada	Preguntas en la posada
267	La amenaza trogg	
268	Entrega para Sven	
269	En busca de sabiduría	
270	La flota maldita	
271	La venganza de Vyrin	
272	La prueba del león marino	
273	Aprovisionar la excavación	
274	Se aproxima una oscura amenaza	
275	Ampollas en la tierra	
276	Patas sucias	
277	No al fuego	
278	Se aproxima una oscura amenaza	
279	Zarpas de las profundidades	
280	Se aproxima una oscura amenaza	
281	Recuperación de bienes	
282	Las observaciones de Senir	
283	Se aproxima una oscura amenaza	
284	La búsqueda continúa	
285	Inspecciona más casuchas	
286	Devuelve la Estatuilla	
287	Poblado Peloescarcha	
288	La Tercera Flota	
289	La tripulación maldita	
290	Purga de la maldición	
291	Los informes	
292	El ojo de Paleth	
293	Limpieza del ojo	
294	La venganza de Ormer	
295	La venganza de Ormer	
296	La venganza de Ormer	
297	Recoger ídolos	
298	Un informe sobre el avance de la excavación	
299	Desvelando el pasado	
301	Informe a Forjaz	
302	Pólvora para Vetaferro	
303	La guerra contra los Hierro Negro	
304	Una misión hedionda	
305	La búsqueda del equipo de excavación	
306	La búsqueda del equipo de excavación	
307	Zarpas asquerosas	
309	Proteger el envío	
310	Cerveza rivales	Rivales acérrimos
311	Vuleve con Marleth	Regresa junto a Marleth
312	La reserva robada de Tundra MacGrann	
313	El Cubil Pardo	
314	La protección del rebaño	
315	La cerveza perfecta	
317	Los suministros del reactor a vapor	
318	La tajada	
319	Un favor a cambio de un barril de tajada	
320	Vuelve con Bramiz	Regresa junto a Bramiz
321	Hierro Forjaluz	
322	Brazo bendito	
323	Prueba de valor	Pon a prueba tu valor
324	Los lingotes perdidos	
325	Armado y listo	
328	La llave oculta	
329	¡Espía descubierto!	
330	Horarios de patrulla	
331	Informa a Doren	
337	Un libro de Historia viejo	Un libro viejo de Historia
338	Las verdes colinas de Tuercespina	
339	Capítulo I	
340	Capítulo II	
341	Capítulo III	
342	Capítulo IV	
348	La fiebre de Tuercespina	
351	¡Encontrar a OOX-17/TN!	
354	Muertes en la familia	
355	Habla con Sevren	
356	Patrulla de la retaguardia	
358	Profanadores	
359	Las obligaciones de los Renegados	
360	Regresa junto al magistrado	
361	Una carta sin entregar	
362	Los molinos fantasma	
363	Desvelo brutal	
364	Los autómatas	
365	Campos de pena	
366	Devuelve el libro	
367	Una nueva Peste	
368	Una nueva Peste	
369	Una nueva Peste	
370	En guerra con la Cruzada Escarlata	
371	En guerra con la Cruzada Escarlata	
372	En guerra con la Cruzada Escarlata	
374	Prueba de la muerte	Prueba de defunción
375	El frío de la muerte	
376	Los Malditos	
379	Aplacar esa sed	
380	Hoya Nocturácnidas	
381	La Cruzada Escarlata	
382	El mensajero rojo	
383	Información decisiva	
385	La caza de crocoliscos	
398	Se busca: Ojo de gusano	Se busca: Ojo de cresa
400	Herramientas para Brasacerada	
401	Espera a que Sirra acabe	
404	Una tarea pútrida	
405	El exánime pródigo	
407	Campos de pena	
408	La Cripta de la Familia	
409	Prueba de lealtad	
411	El regreso del exánime pródigo	
412	Operación Recombobulador	Operación Recombobulación
413	Cerveza negra Brillante	
414	Cerveza negra para Kadrell	
415	La nueva bebida de Rejold	
416	Mata ratas	
417	Vengar al piloto	
418	Morcillas de Thelsamar	
419	El piloto perdido	
420	Las observaciones de Senir	
421	Demuestra tu valía	
422	La locura de Arugal	
423	La locura de Arugal	
424	La locura de Arugal	
425	Ivar el Hediondo	
426	La invasión de los molinos	
427	En guerra con la Cruzada Escarlata	
428	Los Mortacechadores desaparecidos	
429	Corazones salvajes	
430	Vuelve con Quinn	Regresa junto a Quinn
432	¡Malditos troggs!	
433	El servidor público	
435	Escolta a Erland	
436	La excavación de Vetaferro	
437	El Campo Muerto	
438	El Viejo Embarcadero	
439	Pistas de Putrepellejos	
440	El anillo grabado	
441	Raleigh y Entrañas	
442	Asalto a la Isla de Fenris	
443	Icor de Putrepellejo	
444	El origen de los Putrepellejos	
445	Entrega a Bosque de Argénteos	
446	Thule Corvozarpa	
447	Una fórmula mortal	
448	Preséntate ante Hadrec	
449	El informe de los Mortacechadores	
450	Una fórmula mortal	
451	Una fórmula mortal	
452	La emboscada de Aldea Piroleña	
453	Encuentra a la figura	Encuentra la figura misteriosa
454	Tras la emboscada	
455	El asedio de Algaz	
456	El equilibrio de la naturaleza	
457	El equilibrio de la naturaleza	
458	La protectora de los bosques	
459	La protectora de los bosques	
460	Descansar en piezas	
461	El nicho oculto	
463	El Guardaverde	
464	Estandartes de batalla	
465	La estrategia de Nek'rosh	
466	Búsqueda de incendicita	
467	La búsqueda de los Roscapiedra	
468	Preséntate ante el montaraz Rockgar	Preséntate ante el montaraz Piedragar
469	Entrega cotidiana	
470	Abriéndose paso entre los mocos	
471	Deberes de aprendiz	
472	La caída de Dun Modr	
473	Preséntate ante el capitán Puñorrecio	
474	Derrota a Nek'rosh	
475	Una brisa problemática	
476	Corrupción en Tuercepinos	
477	Pasa la frontera	
478	Mapas y runas	
479	Las investigaciones de Molino Ámbar	
480	El Tejedor	
481	El análisis de Dalar	
482	Las intenciones de los Dalaran	
483	Las Reliquias del Despertar	
484	Piel de crocolisco joven	
485	¡Encuentra a OOX-09/HL!	¡Encuentra a OOX-09/TI!
486	Ursal el Violento	
487	El camino a Darnassus	
488	Las apuestas de Zenn	
489	¡Búsqueda de redención!	
490	<UNUSED>	
491	Una varita para Bethor	
492	Una nueva Peste	
493	Viaja a Laderas de Trabalomas	
494	El momento de atacar	
496	Elixir del sufrimiento	Elixir de sufrimiento
498	El rescate	
499	Elixir del sufrimiento	Elixir de sufrimiento
500	La recompensa Aplastacresta	Recompensa Aplastacresta
501	Elixir de dolor	
502	Elixir del dolor	Elixir de dolor
503	Gol'dir	
504	Belicistas Aplastacresta	
505	Hermandad de asesinos	Asesinos de la Hermandad
506	El legado de Lodonegro	
507	Lord Aliden Perenolde	
508	Un regalo de Taretha	El obsequio de Taretha
509	Elixir de agonía	
510	Documentos de planificación	
511	Una carta cifrada	
512	Nobles muertes	Muertes nobles
513	Elixir de agonía	
514	Una carta para Pico Tormenta	Carta a Pico Tormenta
515	Elixir de agonía	
516	El Desafío de Beren	
517	Elixir de agonía	
518	Corona de la Voluntad	Corona de Voluntad
519	Corona de la Voluntad	Corona de Voluntad
520	Corona de la Voluntad	Corona de Voluntad
521	Corona de la Voluntad	Corona de Voluntad
522	Contrato de asesino	
523	Muerte al Barón	La muerte del barón
524	Elixir de agonía	
525	Más misterios	
526	Lingotes Forjaluz	
527	La batalla de Trabalomas	
528	La batalla de Trabalomas	
529	La batalla de Trabalomas	
530	La venganza de un esposo	
531	La venganza de Vyrin	
532	La batalla de Trabalomas	
533	Infiltración	
535	Valik	
536	Al lo largo de la costa	En la costa
537	Consejo oscuro	
539	La batalla de Trabalomas	
541	La batalla de Trabalomas	
544	Colarse en la cárcel	
545	Las patrullas de Dalaran	
546	Recuerdos de muerte	
547	La espada de Humbert	
549	SE BUSCA: Personal de la Hermandad	
550	La batalla de Trabalomas	
551	El pergamino encantado	El papiro encantado
552	La venganza de Helcular	
553	La venganza de Helcular	
554	La descodificación de Pico Tormenta	
555	Sopa de tortuga calmante	Sopa de tortuga reconfortante
556	Muestras de piedra	
557	Brazales de vínculo	
559	La prueba de Farren	
560	La prueba de Farren	
561	La prueba de Farren	
562	Cambio de destino	
563	Nueva asignación	
564	Una amenaza costosa	
565	Capa de piel de yeti de Bartolo	
566	SE BUSCA: Barón Vardus	
567	¡Atención!	
568	La defensa de Grom'gol	
569	La defensa de Grom'gol	
570	El encantamiento de Mok'thardin	
571	El encantamiento de Mok'thardin	
572	El encantamiento de Mok'thardin	
573	El encantamiento de Mok'thardin	
574	Fuerzas especiales	
575	La oferta y la demanda	
576	¡Ojo!	
577	Hay que ensamblar	
578	La piedra de las mareas	
580	El grog de Whiskey Slim	El grog de Whiskey el Delgado
581	Caza para Yenniku	
582	Caza cabezas	
583	Bienvenido a la jungla	
584	Las cabezas de los Sangrapellejo	
585	Hablando con Nezzliok	
586	Hablando con Gan'zulah	
587	Tabaco rapé	
588	El destino de Yenniku	
589	Los cristales canto	
590	Un trato de pícaro	
591	El Ojo de la Mente	El Ojo de la mente
592	Salvar a Yenniku	
594	Mensaje en una botella	
595	Bucaneros Velasangre	
596	Collares de huesos sangrientos	
597	Bucaneros Velasangre	
598	Collares de huesos partidos	Collar de hueso partido
599	Bucaneros Velasangre	
600	La minería de Ventura y Cía.	
601	Elementales de agua	
602	Análisis mágico	
603	Llave de Ansirem	
604	Bucaneros Velasangre	
605	Fragmentos de cristales canto azules	
606	Asusta a Trémulo	Asusta al Trémulo
607	Vuelve con MacKinley	Regresa junto a MacKinley
608	Bucaneros Velasangre	
609	El vudú debido	
610	"El Guapo" Duncan"	El Guapo" Duncan
611	La maldición de las mareas	
613	El pie roto de Maury	Abrir la pata de Maury
616	La isla fantasma	
617	Tallos de juncos akiris	
621	El secreto de Zanzil	
622	Vuelve con el cabo Kaleb	Regresa junto al cabo Kaleb
623	Tallos de juncos akiris	
624	El enigma de Cortello	
625	El enigma de Cortello	
626	El enigma de Cortello	
627	Un favor a Krazek	
628	Borceguí	
629	El Arrecife Mortal	
630	Mensaje en una botella	
631	El puente Thandol	El Puente Thandol
632	El puente Thandol	El Puente Thandol
633	El puente Thandol	El Puente Thandol
634	Petición a la Alianza	
635	Cristal en las montañas	
638	Aterratrols	
639	El sigilo de Strom	
640	El sigilo roto	
641	El sigilo de Thoradin	
642	La princesa secuestrada	La princesa encerrada
643	El sigilo de Arathor	
644	El sigilo de Aterratrols	
645	Trol'kalar	
646	Trol'kalar	
647	Licor de Luna de Mackreel	Licor de luna de Mackreel
648	¡Rescatar a OOX-17/TN!	
651	Piedras de vínculo	Piedras de Vínculo
652	Desbloquear la piedra angular	
653	Aliados de Myzrael	
654	Recogida de muestras en Tanaris	
655	Sentencia	
656	Invocar a la princesa	
657	Sospechas de una nueva Peste	
658	Sospechas de una nueva Peste	
659	Sospechas de una nueva Peste	
660	Sospechas de una nueva Peste	
661	Sospechas de una nueva Peste	
662	Rescate en alta mar	
663	¡Tierra a vista!	
664	Ahogar las penas	
665	El tesoro sumergido	
666	El tesoro sumergido	
667	La muerte viene de las profundidades	Muerte desde abajo
668	El tesoro sumergido	
669	El tesoro sumergido	
670	El tesoro sumergido	
671	Magia demoníaca	
672	El despertar de los espíritus	
673	Magia demoníaca	
674	El despertar de los espíritus	
675	El despertar de los espíritus	
676	La Sentencia	
677	Un llamamiento a las armas	
678	Un llamamiento a las armas	
679	Un llamamiento a las armas	
680	Una auténtica amenaza	
681	Mansión Redilnorte	
682	Insignias de Stromgarde	Distintivos de Stromgarde
684	Se busca: Marez Cowl	Se busca: Marez Cogulla
685	Se busca: Otto y Lord Cresta de Halcón	Se busca: Otto y Lord Falconcrest
687	Theldurin, el perdido	Theldurin el Perdido
688	Aliados de Myzrael	
691	Valer su peso en oro	
692	Los fragmentos perdidos	Los trozos perdidos
693	Empuñar la varita	
694	Las defensas de Trelane	
695	Un encantamiento de aprendiz	
696	Ataque a la torre	
697	Una petición de Malin	
698	Falta de suministros	
699	Falta de suministros	
701	La astucia del raptor	
702	La astucia del raptor	
703	Alas de águila ratonera a la parrilla	
704	El sino de Agmond	
705	La pesca de perlas	
706	Encantamientos de fuego abrasador	Encantamientos Llamarada ígnea
709	La solución a la maldición	
710	Estudio de los elementos: roca	
711	Estudio de los elementos: roca	
712	Estudio de los elementos: roca	
713	Mantener la cabeza fría	
714	Un giro... ¿Qué?	
715	Piedra líquida	
716	Es mejor la piedra que la tela	
717	Terremotos	
718	Espejismos	
719	Un enanos y sus herramientas	Un enano y sus herramientas
720	Un signo de esperanza	
721	Un signo de esperanza	
722	El amuleto de los secretos	
723	Tener fe en el porvenir	
724	Tener fe en el porvenir	
725	Advertir de la amenaza	
726	Advertir de la amenaza	
727	Ir a Forjaz a buscar el "Compendio" de Yagyin	
728	Ir a Entrañas a buscar el "Compendio" de Yagyin	
729	El prospector despistado	
731	El prospector despistado	
732	Terremotos	
733	¡A gorronear!	
734	Lo tienes crudo	
735	La Estrella, la Mano y el Corazón	
737	El saber prohibido	
738	Encontrar a Agmond	
739	Murdaloc	
741	El prospector despistado	
743	Las Viento Furioso son un peligro	
745	Compartir la tierra	
746	Una excavación de los enanos	
747	Empieza la caza	
748	Pozos envenenados	
749	La caravana devastada	La Caravana Devastada
750	La caza sigue	
751	La caravana devastada	La Caravana Devastada
752	Una humilde contribución	
753	Una humilde contribución	
754	La purificación de Pezuña Invernal	
755	Ritos de la Madre Tierra	Los ritos de la Madre Tierra
756	El tótem de Tronacuerno	
757	Rito de la fuerza	
758	La purificación de Tronacuerno	
759	El tótem Ferocrín	
760	La purificación de Bravacrín	La purificación de Ferocrín
761	La caza de los aguilones	
762	Un embajador de mal	Un embajador del mal
763	Ritos de la Madre Tierra	Los ritos de la Madre Tierra
764	Los Ventura y Cía.	
765	Supervisor Fizsprocket	Supervisor Saltatuercas
766	Mazzranache	
767	Rito de la Visión	
770	La capa del demonio marcado	
771	Rito de la Visión	
772	Rito de la Visión	
773	Rito de la Sabiduría	
775	Viaje a Cima del Trueno	
776	Los ritos de la Madre Tierra	
777	Lo tienes crudo	
778	Lo tienes crudo	
780	Los jabaguerreros	
781	Ataque al Campamento Narache	
782	Alianzas rotas	
783	Una amenaza del interior	Una amenaza interna
784	Vencer a los traidores	
786	Frustrar la los planes kolkar	Frustrar los planes kolkar
788	Dientes afilados	
789	Aguijón de escórpido	
790	Sarkoth	
791	Asume tu responsabilidad	
792	Familiares viles	
793	Alianzas rotas	
794	El medallón del Filo Ardiente	
804	Sarkoth	
805	Preséntate en el poblado Sen'jin	Preséntate en el Poblado Sen'jin
806	Oscuras tormentas	
808	La calavera de Minshina	
809	Ak'Zeloth	
812	Se necesita un remedio	
815	Romper huevos	
816	Perdido, pero no olvidado	
817	Presa práctica	
818	Un espíritu responsable	
819	El barril vacío de Chen	
821	El barril vacío de Chen	
823	Informa a Orgnil	
824	Je'neu del Anillo de la Tierra	
825	Los restos del naufragio…	Los restos del naufragio...
826	Zalazane	
827	Roca del Cráneo	
828	Margoz	
829	Neeru Hojafuego	
830	Las órdenes del almirante	
831	Las órdenes del almirante	
832	Sombras Ardientes	
833	Cementerio sagrado	
834	Las arpías Viento Seco	
835	Asegurar las rutas	
836	¡Rescata a OOX-09/HL!	¡Rescata a OOX-09/TI!
837	Invasión	
838	Scholomance	
840	Nuevo recluta de la Horda	
842	Servicio militar en El Cruce	
843	La reclamación de Gann	
844	La amenaza de los zancudos de llanura	
845	El astacebra	La zhebra
846	La venganza de Gann	
847	La astucia del raptor	
848	Esporas de hongos	
849	La venganza de Gann	
850	Los jefes de Kolkar	Los jefes Kolkar
851	Verog el Derviche	
852	Hezrul Marcasangre	
853	Boticaria Zamah	
854	Viaja a El Cruce	
855	Los brazales de centauro	Los brazales centauro
857	La Lágrima de las Lunas	
858	La llave de contacto	
860	Sergra Espinoscura	
861	Los hábitos del cazador	
863	La fuga	
865	Los cuernos de raptor	Cuernos de raptor
867	Arpías saqueadoras	
868	¡A cazar huevos!	
869	Los raptores ladrones	Raptores ladrones
870	Las Charcas del Olvido	
871	Acabar con los ataques de los Crines de Acero	Interrupción de los ataques
872	El fin de las hostilidades	La perturbación termina
873	Isha Awak	
874	Mahren Visioceleste	Mahren Vidente del Cielo
875	Las tenientes arpías	
876	Serena Sangrepluma	
877	El Oasis Estancado	
878	Tribus en guerra	
879	Traidores	
880	Fuentes de vida	Seres alterados
881	Echeyakee	
882	Ishamuhale	
883	Lakota'mani	
884	Owatanka	
885	Washte Pawne	
886	El oasis de Los Baldíos	
887	Los filibusteros del Mar del Sur	Los filibusteros de los Mares del Sur
888	El botín robado	Botín robado
890	El envío perdido	
891	Las armas del Fuerte del Norte	
892	El envío perdido	
893	Una selección de armas	
894	El churumbele	
895	SE BUSCA: Barón Longavera	
896	La fortuna de un minero	
897	El Cosechador	
898	Escapar del fuerte	
899	Consumido por el odio	
900	El churumbele	
901	El churumbele	
902	El churumbele	
903	Merodeadores de los Baldíos	Merodeadores en Los Baldíos
905	La ira de los segadores	Los segadores furiosos
906	Traidores	
907	La rabia de los truenagartos	Los truenagartos iracundos
913	El chillido del halcón trueno	
916	Veneno de tejemadera	
917	Huevo de Tejemadera	
918	Semillas de Brezomadera	
919	Brotes de Brezomadera	
920	Las invocaciones de Tenaron	
921	La corona de la Tierra	
922	Rellian Verdeguja	
923	Los tumores	Tumores
924	La Semilla del Demonio	
927	El corazón musgoso	
928	La corona de la Tierra	
929	La corona de la Tierra	
930	El fruto resplandeciente	
931	Flora luminosa	Fronda fulgurante
932	Odio enraizado	
933	La corona de la Tierra	
935	La corona de la Tierra	
937	El claro encantado	
938	Niebla	
939	La Flauta de Xavaric	
940	Teldrassil	
941	Plantar el corazón	
942	El prospector despistado	
943	El prospector despistado	
944	El Glaive del Maestro	La Espada del Maestro
945	La fuga de Therylune	
947	La cueva de los champiñones	La cueva de las setas
948	Onus	
949	El campamento del Azote del Ocaso	El campamento del Martillo Crepuscular
950	Vuelve con Onus	Regresa junto a Onus
951	Las reliquias de Mathystra	
953	La caída de Ameth'Aran	
954	Bashal'Aran	
955	Bashal'Aran	
956	Bashal'Aran	
957	Bashal'Aran	
958	Las herramientas de los altonatos	Las herramientas de los Altonato
963	Un amor eterno	
964	Fragmentos esqueléticos	Trozos esqueléticos
965	La torre de Althalaxx	La Torre de Althalaxx
966	La torre de Althalaxx	La Torre de Althalaxx
967	La torre de Althalaxx	La Torre de Althalaxx
968	Los Poderes Subyacentes	
969	Que la suerte sea contigo	
970	La torre de Althalaxx	La Torre de Althalaxx
973	La torre de Althalaxx	La Torre de Althalaxx
974	Busca la fuente	
975	Alijo de Mau'ari	
976	Suministros a Auberdine	
977	Yeti... ¿ya hemos llegado?	
978	Lechúcico Lunadón	
979	Encuentra a Ranshalla	
980	Nuevos manantiales	
981	La torre de Althalaxx	La Torre de Althalaxx
982	Profundo océano, mar inmenso	
983	La caja mecánica 827	
984	La extensión de la amenaza	
985	La extensión de la amenaza	
986	El maestro perdido	
990	El camino de Vallefresno	
991	La limpieza de Raene	
992	Un estudio de agua de Gadgetzan	
993	El maestro perdido	
994	Escaparse por la fuerza	
995	Escaparse furtivamente	
997	Las tierras de Denalan	
1001	La caja mecánica 411	
1002	La caja mecánica 323	
1003	La caja mecánica 525	
1007	La antigua estatuilla	La estatuilla antigua
1008	La Ensenada de Zoram	
1009	Ruuzel	
1010	Cabello de Bathran	
1011	Los males de los Renegados	
1012	Druidas dementes	
1016	Brazales elementales	
1017	Mago invocador	
1020	El remedio de Orendil	Cura de Orendil
1021	¡Vil sátiro! ¡Dríade en peligro!	¡Vil sátiro! ¡Dríades en peligro!
1022	La Vega del Aullido	
1023	La limpieza de Raene	
1024	La limpieza de Raene	
1025	Una defensa agresiva	
1026	La limpieza de Raene	
1027	La limpieza de Raene	
1028	La limpieza de Raene	
1029	La limpieza de Raene	
1030	La limpieza de Raene	
1031	La Rama de Cenario	La Rama de Cenarius
1032	¡Muerte a los sátiros!	
1033	Lágrima de Elune	
1034	Las ruinas del Polvo Estelar	Las Ruinas del Polvo Estelar
1035	Lago Cielo Estrellado	
1036	¡Adelante, pillín!	
1037	Velinde Cantoestelar	
1038	Las pertenencias de Velinde	
1039	El puerto de Los Baldíos	
1040	Pasaje a Bahía del Botín	
1041	La ruta de la caravana	
1042	La familia Carevin	
1043	La Guadaña de Elune	
1044	La respuesta a las preguntas	
1045	La limpieza de Raene	
1046	La limpieza de Raene	
1052	El sendero Escarlata	
1054	Matanza selectiva	
1055	La limpieza de Raene	
1056	Viaje a Cima del Espolón	
1057	La reconquista de La Vega Carbonizada	
1058	Magia del bosque de Jin'Zil	
1059	La reconquista de La Vega Carbonizada	
1060	Una carta para Jin'Zil	Carta para Jin'Zil
1061	Los espíritus del Espolón	
1062	Los invasores goblin	
1063	La vieja bruja	La bruja anciana
1068	Las sierras XT:4 y XT:9	
1069	Huevos de arañas musgondo	Huevos de araña musgondo
1070	Estar de guardia en Espolón	
1071	Una tregua para el gnomo	
1072	Un viejo colega	
1073	Ineptitud + Productos químicos = Diversión	
1074	Ineptitud + Productos químicos = Diversión	
1075	Un pergamino de Mauren	
1076	Demonios en Páramos de Poniente	Demonios en los Páramos de Poniente
1077	Entrega especial para Gaxim	
1078	Escamas cristalizadas para Mauren	
1079	Operaciones secretas: plan A	
1080	Operaciones secretas: plan B	
1081	El recibimiento de Tyrande	
1082	Noticias para Centinela Thenysil	
1083	Los espíritus enfurecidos	Los espíritus iracundos
1084	Los antárboles corruptos	
1085	Estar de guardia en Espolón	
1087	El legado de Cenario	El legado de Cenarius
1088	Ordanus	
1089	El Cubil	
1090	Órdenes de Gerenzo	
1091	Noticias para Kaela	
1092	Órdenes de Gerenzo	
1093	Súper Leñadora 6000	Súper Segadora 6000
1094	Más instrucciones	
1095	Más instrucciones	Nuevas instrucciones
1096	Gerenzo Silbillave	
1100	El diario de Henrig Soliceja	El diario de Soliceja
1101	La bruja del Horado	
1102	Un destino vengador	
1104	Veneno de escórpidos salados	Veneno de El Desierto de Sal
1105	Caparazones endurecidos	
1106	Martek el Exiliado	
1107	Aletas dorsales escamadas	Aletas dorsales taraceadas
1108	Indurio	
1109	Guano del Horado	
1110	Piezas de coches cohete	Las piezas de coche cohete
1111	Maestro de los muelles Vertipeluca	Maestro de muelles Vertipeluca
1112	Las piezas de Kravel	
1114	Un envío para los gnomos	
1115	Rumores	
1116	Polvo de sueño en el pantano	Polvo onírico en el pantano
1117	Rumores para Kravel	
1118	De vuelta a Bahía del Botín	
1119	La mezcla y cerveza de tontos de Zanzil	La mezcla de Zanzil y la cerveza de tontos
1120	Emborrachar a los gnomos	
1121	Emborrachar a los goblin	Emborrachar a los goblins
1122	Volver a informar a Pinchabujas,	Volver a informar a Pinchabujas
1124	Páramo	
1125	Los espíritus de Viento del Sur	
1126	Una colmena en la torre	
1132	Fiora Orejona	
1133	Viaje a Astranaar	
1134	Alaorgullo del Esploón	Alaorgullo del Espolón
1135	Glándulas de veneno de Nido Alto	
1137	Noticias para Fizzle	
1138	Rico marisco	
1139	Las tablillas perdidas de Voluntad	
1140	La Torre de Althalaxx	
1141	La familia y la caña de pescar	
1142	Decaída mortal	
1143	La torre de Althalaxx	La Torre de Althalaxx
1144	Willix el Importador	
1145	El enjambre crece	
1147	El enjambre crece	
1148	Pedazos del enjambre	
1149	Prueba de fe	
1150	Prueba de resistencia	
1151	Prueba de fuerza	
1152	Prueba de conocimiento	
1153	Una nueva muestra de mineral	
1154	Prueba de conocimiento	
1159	Prueba de conocimiento	
1166	Las pertenencias del Señor Supremo Mok'Morokk	Las pertenencias del señor supremo Mok'Morokk
1167	La torre de Althalaxx	La Torre de Althalaxx
1168	El ejército de los dragones negros	
1169	Identifica a los cachorros	Identificación de linaje
1170	Los hijos de Onyxia	El linaje de Onyxia
1171	Los hijos de Onyxia	El linaje de Onyxia
1172	Los hijos de Onyxia	El linaje de Onyxia
1173	Desafiar al Señor Supremo Mok'Morokk	Desafía al señor supremo Mok'Morokk
1175	Un bache en la carretera	
1176	Menos peso	
1177	¡Qué hambre!	
1178	Patrocinio goblin	
1179	Los hermanos Pernolatón	
1180	Patrocinio goblin	
1181	Patrocinio goblin	
1182	Apoyo al goblin	Patrocinio goblin
1183	Apoyo al goblin	Patrocinio goblin
1184	Pedazos del enjambre	
1185	Debajo de la quitina había…	Debajo de la quitina había...
1186	El piloto nº18	
1187	Los ajustes de Razzeric'	Los ajustes de Razzeric
1188	La seguridad primero	
1189	La seguridad primero	
1190	Mantener la velocidad	
1194	Los esquemas de Rizzle	
1201	Los espías de Theramore	
1202	El puerto de Theramore	
1203	Jarl necesita una espada	Jarl necesita una hoja
1204	Sopa de fangorroca con tropezones	Sopa de Fangorroca con tropezones
1205	Lodomuerto	
1206	Jarl necesita ojos	
1218	Especias calmantes	
1219	El informe orco	
1220	Capitán Vimes	
1221	Los tubérculos hojazul	
1222	La fuga de Apestoso	
1238	El informe perdido	
1239	La cabeza decapitada	La cabeza cercenada
1240	El trol médico brujo	
1251	El escudo negro	
1252	Teniente Paval Reethe	
1253	El escudo negro	
1258	... con tropezones	...con tropezones
1259	Teniente Paval Reethe	
1260	Morgan Stern	
1261	Las declaraciones de Marg	
1262	Informa a Zor	
1268	Huellas pezuñales sospechosas	Huellas de pezuñas sospechosas
1269	Teniente Paval Reethe	
1270	La fuga de Apestoso	
1271	¡Una fiesta en tu honor!	
1273	El interrogatorio de Reethe	
1276	El escudo negro	
1282	Lo llaman Jim Sonrisas	Le llaman Jim Sonrisas
1284	Huellas pezuñales sospechosas	Huellas de pezuñas sospechosas
1285	Los hombres de Daelin	
1286	Los desertores	
1287	Los desertores	
1302	James Hyal	
1319	El escudo negro	
1320	El escudo negro	
1321	El escudo negro	
1322	El escudo negro	
1323	El escudo negro	
1338	Un pedido de Pico Tormenta	
1339	La tarea del montaraz Pico Tormenta	
1360	Los tesoros reclamados	
1361	Regthar Portamorta	
1362	Los Kolkar de Desolace	
1365	Khan Dez'hepah	
1366	Colección de orejas	
1367	La alianza con los Magram	
1368	La alianza con los Gelkis	
1369	Lágrimas rotas	
1370	¡A robar provisiones!	
1371	Un cacharro para Warug	
1372	El suero de la verdad	
1373	Ongeku	
1374	Khan Jehn	
1375	Khan Shaka	
1380	Khan Hratha	
1381	Khan Hratha	
1382	Extraña alianza	
1383	El suero de la verdad	
1384	Asalta a los Kolkar	
1385	Políticas brutales	
1386	Ataca a los Kolkar	
1387	Colección de orejas	
1388	El suero de la verdad	
1389	Cristales draenetistas	
1391	El suero de la verdad	
1392	Noboru el Garrote	
1393	La huida de Galen	
1394	La recta final	
1395	Suministros para Nethergarde	
1396	Contra la fauna feroz	Naturaleza invasora
1398	Madera a la deriva	
1418	Neeka Marca de Sangre	
1419	Ladrones coyote	
1420	Un informe para Helgrum	
1421	La caravana perdida	
1422	La amenaza marítima	
1424	Charca de Lágrimas	
1425	Envío de suministros	Entrega el cargamento
1426	La amenaza marítima	
1427	La amenaza marítima	
1428	La amenaza continua	Amenaza constante
1429	El exiliado Atal'ai	El exilio de los Atal'ai
1430	Carne fresca	
1437	Buscando a Vahlarriel	Buscando para Vahlarriel
1438	Buscando a Vahlarriel	Buscando para Vahlarriel
1439	Buscando a Tyranis	
1440	Vuelve con Vahlarriel	Regresa junto a Vahlarriel
1444	Vuelve con Fel'Zerul	Regresa junto a Fel'Zerul
1450	Maestro de grifos Garracha	
1451	Rapsodio Machacacanillas	
1452	El cubata de Kalimdor de Rapsodio	
1454	El naufragio de Karnitol	
1455	El naufragio de Karnitol	
1456	El naufragio de Karnitol	
1457	El naufragio de Karnitol	
1458	Componentes para Reivindicadores y Cía.	Componentes para Recuperadores S.A.
1459	Componentes para Reivindicadores y Cía.	Componentes para Recuperadores S.A.
1465	Buscando a Vahlarriel	Buscando para Vahlarriel
1466	Componentes para Reivindicadores y Cía.	Componentes para Recuperadores S.A.
1467	Componentes para Reivindicadores y Cía.	Componentes para Recuperadores S.A.
1469	El relato de Rapsodio	
1470	Descubrir el misterio	
1478	Las invocaciones de Halgar	
1480	El corruptor	
1481	El corruptor	
1482	El corruptor	
1483	Ziz Fizziks	
1484	El corruptor	
1485	Familiares viles	
1488	El corruptor	
1492	Vertipeluca, el maestro de muelles	Maestro de muelles Vertipeluca
1498	Camino de defensa	
1499	Familiares viles	
1502	Thun'grim Vistafuego	
1503	Acero fundido	
1506	Las invocaciones de Gan'rul	
1510	Noticias de Dogran	
1511	Poción de Ken'zigla	Jarabe de Ken'zigla
1512	Un regalo de amor	
1515	El cautiverio de Dogran	
1516	Clamor de Tierra	La llamada de la tierra
1517	Clamor de Tierra	La llamada de la tierra
1519	La llamada de la tierra	
1520	La llamada de la tierra	
1524	La llamada del Fuego	La llamada del fuego
1525	La llamada del Fuego	La llamada del fuego
1526	La llamada del Fuego	La llamada del fuego
1530	La llamada del agua	
1534	La llamada del agua	
1535	La llamada del agua	
1536	La llamada del agua	
1560	La misión de Tooga	
1598	El libro robado	
1599	Novato	
1651	Libro del valor	Escrito sobre valor
1652	Libro del valor	Escrito sobre valor
1654	La prueba de rectitud	
1656	Una tarea por terminar	
1667	Jack Dentomuerto	
1679	Muren Pico Tormenta	
1685	La invocación de Gakin	
1690	Justicia para bandidos	Justicia para los Vagayermos
1691	Más justicia para bandidos	Más justicia para los Vagayermos
1699	El guantelete de Rethban	
1702	El forjador de escudos	
1707	Cazador de bolsas de agua	Cazador de faltriqueras de agua
1712	Cicloniano	Ciclonio
1713	La invocación	
1719	La Reyerta	
1738	Duramen	
1740	El orbe de Soran'ruk	
1758	El Libro del Conciliábulo	Libro del conciliábulo
1784	El Libro de la Divinidad	Escrito sobre divinidad
1787	Libro de la Divinidad	Escrito sobre divinidad
1791	El Cazavientos	El Vigía del viento
1792	Arma torbellino	
1795	El vínculo	
1796	Los componentes para la toga de sangre dorada encantada	
1799	Los fragmentos del orbe de Orahil	Los trozos del orbe de Orahil
1801	El Libro del Conciliábulo	Libro del conciliábulo
1806	La prueba de rectitud	
1819	Ulag, el cuchillero	Ulag el Cuchilla
1820	Habla con Coleman	
1821	Reliquias Agamand	
1822	Arma reliquia	
1824	Prueba en Tierra de Gigantes	
1825	Habla con Thun'grim	
1838	Armadura brutal	
1839	Ula'elek y los guanteletes brutales	
1840	Orm Pezuñapétrea y el yelmo brutal	Orm Pezuña Pétrea y el yelmo brutal
1841	Velora Noctis y las musleras brutal	
1842	Pezuñas de sátiro	
1843	Guanteletes brutales	
1848	Camisote brutal	
1859	Therzok	
1860	Habla con Jennea	
1879	Habla con Bink	
1881	Habla con Anastasia	
1884	Montones de Ju-Ju	
1885	Mennet Carkad	
1918	El elemento podrido	El elemento contaminado
1946	Prendas de encaje abisal	Prendas de encaje Abisal
1948	Objetos de poder	
1949	Secretos escondidos	
1950	Santo y seña	
1951	Rituales de poder	
1952	Varitas de mago	
1954	El orbe infernal	
1955	El exorcismo	
1956	Poder en Uldaman	
1957	Oleadas de maná	
1958	Poder celestial	
2038	Suministros de Bingles	
2078	La venganza de Gyromast	
2098	La búsqueda de Gyromast	
2118	Tierras infestadas	Tierras apestadas
2138	La limpieza de la infección	
2139	La esperanza de Tharnariun	
2158	Descanso y relajación	
2159	Envío desde Dolanaar	Paquete de Dolanaar
2160	Suministros para Tannok	
2161	Un cargamento de peón	
2198	El collar hecho añicos	
2199	Esa información tiene un precio	
2200	El regreso a Uldaman	
2201	Encuentra las gemas	
2202	Componentes de Uldaman	
2204	Restaurar el collar	
2205	Busca el SI: 7	Busca el IV:7
2218	El camino hacia la salvación	
2239	El informe de Onin	
2240	La cámara oculta	
2241	Cuando cae la manzana	
2258	Componentes de Tierras Inhóspitas	
2259	Erion Sombrusurro	
2278	Los discos de platino	
2279	Los discos de platino	
2280	Los discos de platino	
2282	Molino de Alther	
2283	La recuperación del collar	
2284	La recuperación del collar, 2ª parte	
2299	¡Ve a hablar con Hulfdan!	
2300	SI:7	IV:7
2318	La traducción del diario	
2338	La traducción del diario	
2339	Encuentra las gemas y la fuente de poder	Encuentra las gemas y la fuente de alimentación
2340	Entregar las gemas	
2341	La recuperación del collar, 3ª parte	
2342	Los tesoros reclamados	
2359	La torre de Klaven	
2361	Restaurar el collar	
2380	Ve a Orgrimmar	
2381	Saquear a los saqueadores	
2383	Pergamino sencillo	Papiro simple
2398	Los enanos desaparecidos	
2399	Flora en brote	
2418	Las piedras de energía	
2438	El atrapasueños esmeralda	
2459	Ferocitas el Comesueños	
2478	Misión: posible, pero no probable	Misión: Posible, pero no probable
2480	La ayuda de Hinott	
2498	El regreso a Denalan	Regresa junto a Denalan
2499	Roblegüello	
2500	Componentes de Tierras Inhóspitas	
2521	Al servicio de Kum'isha	
2541	El druida durmiente	
2561	El druida de la garra	El druida de la Zarpa
2581	Papadas de hiena risita	Papadas de hiena risitas
2583	La vitalidad del jabalí	
2585	El golpe decisivo	
2601	El bocado de basilisco	
2603	El vigor del buitre	
2605	El goblin sediento	
2606	Un buen sabor	
2621	El deshonrado	
2622	Las órdenes perdidas	
2623	El Hablador del pantano	La voz del pantano
2641	El ingrediente secreto de Roxio	
2661	Un envío para Marin	
2662	El elixir de Tragonublo	
2681	Las piedras que nos vinculan	
2701	Los héroes de los antiguos	
2702	Los héroes de los antiguos	
2721	Kirith	
2741	El Superhuevomático	
2742	¡Capturaron a Rin'ji!	
2743	La cubierta de la Oscuridad	
2744	El cazademonios	
2766	¡Encuentra a OOX-22/FE!	
2767	¡Escolta a OOX-22/FE!	
2768	Cetro Divinomático	Vara divinomática
2769	Los hermanos Pernolatón	
2770	Gahz'rilla	
2781	SE BUSCA: Caliph Escorpijón	SE BUSCA: Califa Escorpijón
2782	El secreto de Rin'ji	
2783	Peleas mezquinas	
2784	Pérdida de honor	
2801	Una historia triste	
2821	La marca de la calidad	
2822	La marca de la calidad	
2841	Las guerras de la plataforma	
2842	Scooty, ingeniero jefe	
2843	¡Gnomer-yaaaaa!	
2844	El guardián gigante	
2845	Las andanzas de Shay	
2846	Tiara de la Profundidad	Tiara de las profundidades
2861	La tarea de Tabetha	
2862	En guerra con los Zarpaleña	
2863	Ataca a los Alfas	
2864	Tran'rek	
2865	Caparazones de escarabajo	
2866	Las Ruinas de Solarsal	
2867	Regresa al Bastión Plumaluna	
2869	En contra de los Crestafuria	
2870	En contra del Señor Shalzaru	En contra de Lord Shalzaru
2871	Entrega la reliquia	
2872	La deuda de Stoley	
2873	el Cargamento de Stoley	El envío de Stoley
2874	Un envío para MacKinley	
2875	SE BUSCA: Andre Barbafuego	
2876	El registro náutico	
2877	La limpieza de Roca Oculta	
2879	El Bastón de Equinex	El báculo de Equinex
2880	Los collares de trols	
2902	Investiga a los Zarpaleña	
2903	Los planes de batalla de los Zarpaleña	Los planes de batalla
2904	Un buen lío	
2922	¡Salva el cerebro de Techrobot!	¡Salva el cerebro de Tecnobot!
2923	Maestro manitas Sobrechispa	
2924	Esencias artificiales	
2925	Klockmort Palmalicate	
2926	Gnogaine	
2927	Al día siguiente	
2928	Gyrodrillmatic Excavationators	Excavadoras gyroagujereamáticas
2929	La gran traición	
2930	Rescatar los datos	
2931	Trabajar para Funditubo	
2932	Un macabro mensaje	Un mensaje siniestro
2933	Botellas de veneno	
2934	Glándula de veneno intacta	
2935	Consulta al maestro Gadrin	
2936	Diosa araña	
2937	Invocar a Shadra	
2938	Veneno para Entrañas	
2939	La búsqueda del conocimiento	
2940	Feralas: una historia	
2941	El préstamo	
2942	La Piedra del mañana	
2943	Vuelva con Troyas	Regresa junto a Troyas
2944	Superistánea FX	La Superinstantánea FX
2945	Un anillo sucio	
2947	La devolución del anillo	
2949	La devolución del anillo	
2951	¡El Destellamatic 5200!	
2952	¡El Destellamatic 5200!	
2954	El guardapiedras	El vigía de piedra
2962	Necesitamos más material verdoso	
2969	Libertad para todas las criaturas	
2970	La justicia del castigo	
2972	La justicia del castigo	
2973	Una capa nueva	El lustre de una nueva capa
2974	Un descubrimiento siniestro	
2975	Los ogros de Feralas	
2976	Un descubrimiento siniestro	
2978	El pergamino Gordunni	
2979	Una ceremonia oscura	
2980	Los ogros de Feralas	
2982	Las Altas Tierras Salvajes	
2983	La llamada del Fuego	La llamada del fuego
2984	La llamada del Fuego	La llamada del fuego
2985	La llamada del agua	
2986	La llamada del agua	
2987	El cobalto Gordunni	
2988	Las jaulas de Secacorteza	
2989	El Altar de Zul	
2990	Thadius Sombramacabra	
2991	Medallón de Nekrum	
2992	El ritual de adivinación	
2993	Vuelve a las Tierras del Interior	Regresa a las Tierras del Interior
2994	Salvar a Picoafilado	
2997	El Libro de la Divinidad	Escrito sobre divinidad
2998	Libro de la Divinidad	Escrito sobre divinidad
3002	El orbe Gordunni	
3022	Un envío frágil	
3042	Temple trol	
3062	Negro corazón	Corazón oscuro
3063	Vengarse de las Nortearroyo	Venganza contra Nortearroyo
3065	Tablilla sencilla	Tablilla simple
3082	Tablilla con grabados	
3083	Tablilla encriptada	
3084	Tablilla inscrita con runas	La tablilla con runas grabadas
3085	Tablilla Sagrada	Tablilla sacralizada
3086	Tablilla con glifos	Tablilla glífica
3087	Pergamino con grabados	Papiro con grabados
3088	Pergamino encriptado	Papiro encriptado
3089	Pergamino inscrito con runas	El papiro con runas grabadas
3090	Pergamino corrupto	Papiro corrupto
3091	La nota simple	
3092	La nota con grabados	
3093	La nota con runas	La nota con runas grabadas
3094	La nota verde	La nota verdeante
3095	Un pergamino simple	
3096	Un pergamino encriptado	Un pergamino codificado
3097	Un pergamino sagrado	Un pergamino sacralizado
3098	Un pergamino con glifos	Un pergamino glífico
3099	Un pergamino manchado	Un pergamino corrupto
3100	Una carta simple	
3101	Una carta consagrada	
3102	Una carta cifrada	
3103	Una carta sacralizada	
3104	Una carta con glifos	Una carta glífica
3105	Una carta manchada	
3106	Runa simple	
3107	Runa consagrada	
3108	Runa con grabados	
3109	Runa encriptada	Runa codificada
3110	Runa sagrada	Runa sacralizada
3112	Memorándum simple	
3113	Memorándum encriptado	
3114	Memorándum con inscripciones	Memorándum glífico
3115	Memorándum corrupto	
3116	El sigilo simple	
3117	El sigilo con grabados	
3118	El sigilo cifrado	
3119	El sigilo sagrado	Sigilo sacralizado
3120	El sigilo verdeante	
3121	Una extraña petición	
3122	Regresa junto al médico brujo Uzer'i	
3123	Probar la vasija	
3124	Hipogrifos muisek	Muisek de hipogrifo
3125	Dragones feéricos muisek	Muisek de dragón feérico
3126	Antárboles muisek	Muisek de antárbol
3127	Gigantes de montaña muisek	Muisek de gigante montés
3128	Materiales naturales	
3129	Armas del espíritu	
3130	En contra de los Crestafuria	
3141	Loramus	
3161	Gahz'rilo	
3181	El cuerno de la bestia	
3182	Certificado de autenticidad	
3221	Habla con Renferrel	
3261	Jorn Visioceleste	Jorn Vidente del Cielo
3281	La plata robada	Plata robada
3301	Mura Runatótem	Mura Tótem de Runa
3361	Las penurias de un refugiado	
3362	El Valle Cardizal	
3364	Entrega una infusión de albaza hirviendo	
3365	Devuelve la taza	
3367	Piedras de Suntara	
3368	Piedras de Suntara	
3369	En las pesadillas	
3370	En las pesadillas	
3372	Libéralos	
3374	La esencia de Eranikus	
3376	La cabeza de Cornapunta	
3377	Oración a Elune	El rezo a Elune
3378	Oración a Elune	El rezo a Elune
3441	Castigo divino	
3442	La llama pura	
3443	Forjar el mango	
3444	El Círculo de Piedras	El círculo de piedra
3445	El Templo Sumergido	
3452	El soporte para la llama	
3453	La Antorcha de Reprensión	La antorcha de reprensión
3454	La Antorcha de Reprensión	La antorcha de reprensión
3462	Escudero Maltrake	
3463	¡Préndelas fuego!	¡Préndeles fuego!
3481	Abalarios...	Abalorios...
3501	Todo cuenta en grandes cantidades	
3508	Romper el amuleto	
3509	El nombre de la bestia	
3510	El nombre de la bestia	
3511	El nombre de la bestia	
3512	Como diría  Eranikus…	Como diría Eranikus...
3513	El pergamino rúnico	
3514	La presencia de la Horda	
3517	El robo de conocimientos	
3518	Entrega a Magatha	
3519	Un amigo en apuros	
3520	Los espíritus de los estriadores	Los espíritus de los estridadores
3521	En antídoto de Iverron	El antídoto de Iverron
3522	En antídoto de Iverron	El antídoto de Iverron
3524	Varado	
3527	La profecía de Mosh'aru	
3541	Entrega a Jes'rimon	
3542	Entrega a Andron Gant	
3561	Entrega al archimago Xylem	
3562	El pago de Magatha a Jediga	
3563	El pago de Jes'rimon a Jediga	
3564	El pago de Andron a Jediga	
3565	El pago de Xylem a Jediga	
3566	¡Arriba, Obsidion!	
3601	¡Kim'jael, claro!	
3602	Azsharita	
3621	La formación de Felbane	La formación de Aterravil
3625	Armas Fel en Azsharita encantada	
3626	El regreso a Las Tierras Devastadas	Regresa a Las Tierras Devastadas
3627	Juntar pedazos del amuleto	
3628	Eres Rakh'likh, demonio	
3661	¿Creados por Elune?	
3721	Tu propio OOX	
3741	El collar de Hilary	
3783	Yeti... ¿ya hemos llegado?	
3788	La petición de Jonguja	
3791	El misterio de mañagrana	
3821	Roca Machacamiedo	
3822	Krom'Grul	
3823	El exterminio de los Ardentrañas	El exterminio de los Pirontraña
3824	Gor'tesh, el Señor bruto	Gor'tesh, el Señor de los toscos
3825	Una cabeza ogro empalada = FIESTA	
3841	Un huérfano que busca un hogar	
3842	Una corta incubación	
3843	Un nuevo miembro en la familia	
3844	Un secreto bien guardado	
3845	Un secreto bien guardado	
3881	Expedición Salvación	Salvar a la expedición
3882	Choca esos huesos	
3883	Ecología alienígena	
3884	Diario de Williden	
3901	Sacudir esqueletos	
3902	Hurgar en Camposanto	
3903	Milly Osworth	
3904	La cosecha de Milly	
3905	Informe de la vendimia	
3908	Un secreto bien guardado	
3909	El Elixir de Videre	
3912	Encuentro en la tumba	
3913	Una situación mortal	
3914	La Espada de Linken	
3921	Wenikee Tuercasmil	
3922	Engranajes	
3923	Rilli Gapegajoso	
3924	El manual de churumbele	El manual del churumbele
3941	La ayuda de una gnoma	
3942	Recuerdos de Linken	
3961	La aventura de Linken	
3962	Ir solo es peligroso	
4005	Aquementas	Aquamentas
4021	¡Contraataca!	
4022	Un sabor a llamarada	
4023	Un sabor a llamarada	
4061	La revuelta de las máquinas	
4062	La revuelta de las máquinas	
4084	Corazón de plata	
4101	Limpiar Frondavil	Purificación de Frondavil
4102	Limpiar Frondavil	Purificación de Frondavil
4120	La fuerza de la corrupción	
4124	El mensajero desaparecido	
4125	El mensajero desaparecido	
4127	Los restos del bote	
4129	La revelación del cuchillo	
4130	Lectura psicométrica	
4131	Los gnolls Zarpaleña	
4135	Las Entrañas Retorcidas	Las Galerías Retorcidas
4141	Muigin y Larion	
4142	Visita a Gregan	
4143	Bruma del mal	
4144	Brote pétalo de sangre	Brotes Sangrepétalo
4145	Larion y Muigin	
4146	Combustible de irradior	
4147	El taller de Marvon	
4148	Liquidador de pétalos de sangre	
4182	La amenaza de los dragonantes	
4183	Los verdaderos maestros	
4184	Los verdaderos maestros	
4185	Los verdaderos maestros	
4186	Los verdaderos maestros	
4223	Los verdaderos maestros	
4224	Los verdaderos maestros	
4243	Buscando a Memo 01	
4244	Buscando a Memo 01	
4245	Buscando a Memo 01	
4261	El espíritu de un Ancestro	
4265	Liberado de la colmena	
4266	La bienvenida de un héroe	
4267	El alzamiento de los silítidos	La sublevación de los silítidos
4281	Una entrega en Thalanaar	
4283	¡CINCUENTA! ¡SÍ!	
4284	Cristales de poder	
4285	La Torre del Norte	La Torre de cristal del Norte
4287	La Torre del Este	La Torre de cristal del Este
4288	La Torre del Oeste	La Torre de cristal del Oeste
4289	Los simios de Un'Goro	
4290	La comida de Lar'korwi	
4291	Una aroma irresistible para Lar'korwi	Un aroma irresistible para Lar'korwi
4292	El cebo para Lar'korwi	
4296	La tablilla de los Siete	
4297	Comida para el bebé	
4298	El amor parental	
4301	El poderoso U'cha	
4321	Entender el significado	
4402	Sorpresa de manzanas de cactus de Galgar	
4421	La corrupción de los Fuego de Jade	
4441	Los Ancestros corrompidos	
4442	¡Purificada!	
4449	Atrapado	
4450	El libro de contabilidad de Tanaris	
4451	La llave de la libertad	
4490	Invoca un malignoecus	Invoca un corcel vil
4491	Un poco de ayuda de mis amigos	
4492	¡Perdido!	
4495	Un buen amigo	
4496	Que jungla tan chunga	
4501	Cuidado con los pterrordáctilos	
4502	Actividad volcánica	
4503	El aparato volador de Shizzle	
4504	Superpegajoso	
4505	El pozo de la corrupción	Pozo de corrupción
4506	Dientes de sable corruptos	Sables corruptos
4507	El señuelo atrapa a la reina	
4508	La calma que precede a la tormenta	
4509	La calma que precede a la tormenta	
4521	Guardianes salvajes	
4542	Mensaje para el Poblado Viento Libre	
4581	Kayneth Ventoleve	
4621	¡Adelante, almirante!	
4641	Tu lugar en el mundo	
4681	Varado	
4721	Guardianes salvajes	
4722	Tortuga marina varada	
4723	Criatura marina varada	
4725	Tortuga marina varada	
4726	Esencia de cría	
4727	Tortuga marina varada	
4728	Criatura marina varada	
4730	Criatura marina varada	
4731	Tortuga marina varada	
4732	Tortuga marina varada	
4733	Criatura marina varada	
4740	SE BUSCA: ¡Viscoso!	
4741	Guardianes salvajes	
4761	Thundris Tejevientos	
4762	El Río Fonroca	
4763	La corrupción de los Bosque Negro	
4767	Jinete del viento	
4770	De vuelta casa	De vuelta a casa
4781	Los componentes para la toga de sangre dorada encantada	
4782	Los componentes para la toga de sangre dorada encantada	
4783	Los componentes para la toga de sangre dorada encantada	
4784	Los componentes para la toga de sangre dorada encantada	
4786	Toga terminada	
4787	El huevo antiguo	
4808	Felnok Acerovera	
4809	Cuernos de quimera venfresco	Cuernos de Orvallo
4810	Vuelve con Tinkee	Regresa junto a Tinkee
4811	El cristal rojo	
4812	Agua en cascada	
4813	Los fragmentos del interior	Los trozos del interior
4821	Un huevo extraño	
4841	Apaciguar al centauro	
4842	Fuentes extrañas	
4861	Lechúcico iracundo	Lechúcico salvaje iracundo
4863	Lechúcico salvaje iracundo	
4864	Lechúcico iracundo	Lechúcico salvaje iracundo
4865	Venganza	
4881	Complot de asesinato	
4882	Guardar un secreto	
4883	Guardar un secreto	
4901	Guardianes del altar	
4902	Lechúcico de Elune	Lechúcico salvaje de Elune
4904	Al fin libre	
4906	Más corrupción	
4921	Perdida en la batalla	
4961	La purificación del orbe de Orahil	
4962	Fragmento de can manáfago	
4963	Fragmento de infernal	
4964	El orbe completo de Dar'Orahil	
4966	Defensa de Kanati Nube Gris	
4971	Una cuestión de tiempo	
4972	Contar el tiempo	
4975	El orbe completo de Noh'Orahil	
4976	Devolver el orbe purificado	
4984	La naturaleza también sufre	
4985	La naturaleza también sufre	
4986	Rama de roble con inscripciones	
4987	Rama de roble con inscripciones	
5021	Más vale tarde que nunca	
5022	Más vale tarde que nunca	
5023	Más vale tarde que nunca	
5041	Suministros para El Cruce	
5050	Talismán de la buena suerte	Talismán de buena suerte
5051	Dos mitades hacen una	
5052	Fragmentos ensangrentados de Agamaggan	Esquirlas de sangre de Agamaggan
5054	Ursius de los dentoesquirla	Ursius de los Dentoesquirla
5055	Brumeran de los Venfresco	Brumerán de los Orvallo
5056	Shy-Rotam	Shi-Rotam
5057	Esfuerzos del pasado	
5058	El diario de la señorita Dalson	El diario de la señora Dalson
5060	Encierro	
5061	Forma acuática	
5062	El fuego Sagrado	
5064	Espiando a los Tótem Siniestro	
5065	Las tablillas perdidas de Mosh'aru	Las tablillas perdidas Mosh'aru
5082	La amenaza de los Nevada	
5083	Piroagua Nevada	Aguardiente Nevada
5084	Sucumbir a la corrupción	
5085	Baba misteriosa	
5086	Horrores tóxicos	
5087	Corredores Nevada	
5088	Arikara	
5092	Despejando el camino	Despejar el camino
5093	Un llamamiento a las armas: las Tierras de la Peste	
5094	Un llamamiento a las armas: las Tierras de la Peste	
5095	Un llamamiento a las armas: las Tierras de la Peste	
5096	Distracción Escarlata	
5097	Todas las torres	Todas las atalayas
5098	Todas las atalayas	
5121	Alto Jefe Nevada	Gran Jefe Nevada
5123	La pieza final	
5128	Palabras del Gran Jefe	
5142	La pequeña Pamela	
5147	Se busca: Arnak Tótem Siniestro	
5149	La muñeca de Pamela	
5151	Hipercondensador	
5152	Tía Marlene	
5153	Un extraño historiador	Una extraña historiadora
5154	Las Crónicas de Villa Darrow	
5155	Las fuerzas de Jaedenar	
5156	Investigación acerca de la corrupción	Verificación de la corrupción
5157	Una muestra de agua corrupta	Recolección de agua corrupta
5158	Buscando ayuda espiritual	En busca de ayuda espiritual
5159	El agua purificada vuelve a Frondavil	El agua purificada regresa a Frondavil
5161	La cólera del Vuelo Azul	
5162	La cólera del Vuelo Azul	
5163	Yeti... ¿ya hemos llegado?	
5164	Catálogo del Díscolo	
5165	Sofocar las llamas de protección	
5166	Coraza del Vuelo Cromático	
5167	Quijotes del Desafiante cromático	Quijotes del desafiante cromático
5168	Los héroes de Villa Darrow	
5181	Los villanos de Villa Darrow	
5202	Una extraña llave roja	
5203	El rescate en Jaedenar	Rescate de Jaedenar
5204	La reprensión de la Luz	Reprensión de la Luz
5206	Los merodeadores de Villa Dorrow	Los merodeadores de Villa Darrow
5210	Carlin, el hermano de Joseph	
5211	Los defensores de Villa Darrow	
5215	Las calderas de la Plaga	
5216	Objetivo: Campo de Piedra Mácula	Objetivo: Campo de Piedramácula
5217	El regreso al Campamento del Orvallo	Regresa al Campamento del Orvallo
5219	Objetivo: Llanto de Dalson	
5220	El regreso al Campamento del Orvallo	Regresa al Campamento del Orvallo
5222	Objetivo: El Tormento	
5223	El regreso al Campamento del Orvallo	Regresa al Campamento del Orvallo
5225	Objetivo: Gangrena de Gahrron	
5226	El regreso al Campamento del Orvallo	Regresa al Campamento del Orvallo
5228	Los calderos de la Plaga	Las calderas de la Plaga
5229	Objetivo: Campo de Piedra Mácula	Objetivo: Campo de Piedramácula
5230	El regreso a El Baluarte	Regresa a El Baluarte
5231	Objetivo: Lamento de Dalson	Objetivo: Llanto de Dalson
5232	El regreso a El Baluarte	Regresa a El Baluarte
5233	Objetivo: El Tormento	
5234	El regreso a El Baluarte	Regresa a El Baluarte
5235	Objetivo: Gangrena de Gahrron	
5236	El regreso a El Baluarte	Regresa a El Baluarte
5237	¡Misión cumplida!	
5238	¡Misión cumplida!	
5241	Tío Carlin	
5242	El golpe final	
5244	Las ruinas de Kel'Theril	Las Ruinas de Kel'Theril
5245	Espíritus condenados de Kel'Theril	
5246	Fragmentos del pasado	Trozos del pasado
5247	Fragmentos del pasado	Trozos del pasado
5248	Atormentados por el pasado	
5249	¡A la Cuna del Invierno!	
5250	Estrella Fugaz	
5252	Altonato arrepentido	
5253	El cristal de Zin-Malor	
5261	Eagan Desollapieles	Eagan Desollapelambres
5264	Lord Maxwell Neófitus	
5265	El Bastión Argenta	
5281	Espíritus inquietos	
5321	El despertar	
5342	El último de los Barov	
5344	El último de los Barov	
5361	Árbol genealógico	
5381	La Mano de Iruxos	
5385	Restos de Trey Forjaluz	Los restos de Trey Forjaluz
5386	La pesca del día	
5401	Comisión del Alba Argenta	Comisión de El Alba Argenta
5405	Comisión de El Alba Argenta	
5441	Peones vagos	
5461	El humano, Ras Levescarcha	El humano, Ras Murmuhielo
5462	El moribundo, Ras Levescarcha	El moribundo, Ras Murmuhielo
5464	El Obsequio de Menethil	
5465	Memorias del Vínculo del Alma	El Libro de Memorias del Alma
5481	La tarea de Gordo	
5482	Apocalíseas	
5501	Colección de kodos	Recolección de kodos
5503	Comisión del Alba Argenta	Comisión de El Alba Argenta
5504	Mantos del Alba	
5505	La llave de Scholomance	
5507	Mantos del Alba	
5511	La llave de Scholomance	
5513	Mantos del Alba	
5514	Molde rima con... ¿oro?	
5517	Manto del Alba cromático	
5521	Manto del Alba cromático	
5522	Leonid Barthalomew	
5524	Manto del Alba cromático	
5526	Fragmentos de gangrevid	
5527	Un relicario de pureza	Un relicario de Pureza
5533	Scholomance	
5534	El equipamiento "perdido" de Kim'jael	
5535	Agitación espiritual	
5536	Una tierra llena de odio	
5537	Fragmentos esqueléticos	Trozos esqueléticos
5538	Molde rima con... ¿oro?	
5541	Municiones para Estruendo	
5542	Perros demoníacos	
5543	Cielos sangrientos	
5544	Gusanos carroñeros	
5545	El cumplimiento del plazo	
5561	El rodeo kodo	
5581	Los portales de la Legión	
5601	Pamela, mi hermana	
5621	Prendas de la luna	
5622	Los caminos de Elune	
5623	Al servicio de la Luz	
5624	Las prendas de la Luz	
5625	Las prendas de la Luz	
5626	Al servicio de la Luz	
5628	La vuelta a casa	
5629	La vuelta a casa	
5630	La vuelta a casa	
5635	Oración desesperada	
5636	Oración desesperada	
5637	Oración desesperada	
5648	Prendas de espiritualidad	
5649	Al servicio de la espiritualidad	
5650	Las prendas de la Oscuridad	
5651	Al servicio de la Oscuridad	
5654	Maleficio de Debilidad	
5655	Maleficio de Debilidad	
5660	Toque de debilidad	
5661	Toque de debilidad	
5713	Un tiro. Un muerto.	Un tiro, un muerto
5721	La Batalla de Villa Darrow	
5741	El Cetro de la Luz	El Cetro de Luz
5742	Redención	
5762	Hemet Decautela	Hemet Nesingwary
5763	La caza en Tuercespina	
5781	De recuerdos olvidados	
5801	La forja del Penacho en Llamas	
5802	La forja del Penacho en Llamas	
5803	El escarabajo de Araj	El escarabeo de Araj
5804	El escarabeo de Araj	
5821	El guardaespaldas	Guardaespaldas de alquiler
5845	Del honor perdido	
5846	De amor y familia	Del amor y la familia
5861	Encuentra a Myranda	
5862	La Ilusión Escarlata	El subterfugio Escarlata
5863	El Territorio Machacaduna	La Base Machacaduna
5881	La sustitución	
5882	Bálsamo por caza	
5887	Bálsamo por caza	
5901	Una Peste en la Cruzada	
5902	Una Peste en la Cruzada	
5903	Una Peste en la Cruzada	
5904	Una Peste en la Cruzada	
5925	Atendiendo a la llamada	Escucha la llamada
5928	Escucha la llamada	
5929	Espíritu del gran oso	
5930	Espíritu del gran oso	
5931	El regreso a Darnassus	
5932	Vuelve a Cima del Trueno	
5941	Vuelve con Chromie	Regresa junto a Cromi
5942	Tesoros ocultos	
5943	La caravana Gizelton	
5944	En sueños	
6004	Negocios inconclusos	
6021	Zaeldarr el Marginado	
6022	Matar con un propósito	
6023	Negocios inconclusos	
6024	La súplica de Hameya	
6025	Negocios inconclusos	
6026	Eso pide mucho	
6027	El Libro de los Ancestros	
6028	El informe Vista Eterna	
6029	El informe Vista Eterna	
6030	El duque Nicolas Zverenhoff	
6031	Paño rúnico	
6041	Cuando Smokey canta, me pongo violento	
6042	Los pequeños problemas de la no-vida	
6061	Domesticar la bestia	
6062	Domesticar la bestia	
6063	Domesticar la bestia	
6064	Domesticar la bestia	
6067	El camino del cazador	
6069	El camino del cazador	
6075	El camino del cazador	
6081	Entrenar a la bestia	Domesticar la bestia
6082	Domesticar la bestia	
6083	Domesticar la bestia	
6084	Domesticar la bestia	
6085	Domesticar la bestia	
6086	Entrenar a la bestia	Domesticar la bestia
6087	Domesticar la bestia	
6088	Domesticar la bestia	
6089	Entrenar a la bestia	Domesticar la bestia
6101	Domesticar la bestia	
6102	Domesticar la bestia	
6103	Domesticar la bestia	
6122	La fuente del envenenamiento	
6123	Reunir los ingredientes del remedio	
6124	Curar la dolencia	
6125	Poder contra el veneno	
6127	La fuente del envenenamiento	
6128	Reunir los ingredientes del remedio	
6129	Curar la dolencia	
6130	Poder contra el veneno	
6132	¡Sácame de aquí!	
6133	La orden del Señor de exploradores	La orden del Señor forestal
6134	La caza de ectoplamas	La caza de ectoplasmas
6135	Alatardecer, cómo te odio…	Alaocaso, cómo te odio...
6136	El corpulento	
6141	Hermano Antón	Hermano Anton
6142	Almejas	
6143	Otros pescados para freír	
6144	La llamada del teniente	
6145	El mensajero carmesí	
6146	La estratagema de Nathanos	
6147	Regresa junto a Nathanos	
6148	El Oráculo Escarlata, Demetria	
6161	La búsqueda del tesoro de Masatormento	
6162	La última batalla de un esposo	
6164	Libro de entradas de Augustus	
6181	Mensajero a toda prisa	
6184	Flint Sombramás	
6185	Las pestes del este	
6187	Restaurar el orden	
6261	Dungar Tragolargo	
6281	Prosigue hasta Ventormenta	
6282	La ameneza de la arpías	La amenaza de las arpías
6283	El linaje Furia Sangrienta	
6284	Aracnofobia	
6285	Regresa con Lewis	Regresa junto a Lewis
6301	El ciclo del renacimiento	
6321	Suministros para El Sepulcro	
6322	Michael Garrett	
6323	Vuela a Entrañas	
6324	Vuelve con Podrig	Regresa con Podrig
6341	La prodigalidad de Teldrassil	Las presas de Teldrassil
6342	Vuela a Auberdine	Vuelo a Auberdine
6343	Vuelve con Nessa	Regreso a Nessa
6361	Un fardo de pieles	Un fardo de pellejos
6362	Un viaje a Cima del Trueno	
6363	Tal, maestro de jinetes del viento	
6364	Volver junto a Jahan	Regresa con Jahan
6365	Entrega de carne a Orgrimmar	
6381	Nueva vida	
6382	La Caza de Vallefresno	
6383	La Caza de Vallefresno	
6384	Un viaje a Orgrimmar	
6385	Doras, maestro de jinetes del viento	
6386	El regreso a El Cruce	Regreso a El Cruce
6387	Estudiantes de honor	
6388	Gryth Thurden	
6389	Una Peste en la Cruzada	
6390	Una Peste en la Cruzada	
6391	Vuela a Forjaz	
6392	Vuelve con Brock	Regresa con Brock
6393	Guerra elemental	
6394	Pico de Thazz'ril	
6395	El último deseo de Marla	
6401	Kaya está viva	
6421	Barranco del Alud	
6441	Los cuernos de sátiro	
6442	Naga en la Ensenada de Zoram	Nagas en la Ensenada de Zoram
6461	Chupasangres	
6462	Los talismanes trols	El talismán trol
6481	El despertar del terráneo	
6482	Liberar a Ruul	
6503	Avanzada de Vallefresno	
6504	Las páginas perdidas	
6523	Proteje a Kaya	Protege a Kaya
6541	Preséntate ante Kadrak	
6542	Preséntate ante Kadrak	
6543	Los informes Grito de Guerra	
6544	El asalto de Torek	
6548	Venga mi aldea	
6568	El testamento de Rexxar	El testimonio de Rexxar
6570	Brasaliza	
6571	Suministros Grito de Guerra	
6582	La prueba de las calaveras, Arúspice	La prueba de los cráneos, Arúspice
6583	La prueba de las calaveras, Somnus	La prueba de los cráneos, Somnus
6584	La prueba de los cráneos, Chronalis	
6585	La prueba de las calaveras, Axtroz	La prueba de los cráneos, Axtroz
6601	El ascenso	
6603	Problemas en Cuna del Invierno	
6604	Lechúcico iracundo	Lechúcico salvaje iracundo
6605	Algo extraño	
6621	El rey de los Corrupto	El rey de los Maderiza
6627	Prueba de conocimiento	
6628	Prueba de conocimiento	
6629	Mata a Grundig Nube Negra	
6641	Vorsha la Azotadora	
6722	El camino del cazador	
6804	Agua envenenada	
6805	Sirocosos y reptarenas	
6821	Ojo de brasadivino	Ojo del Brasadivino
6822	El Núcleo de Magma	
6823	Agente de Hydraxis	
6824	Las manos de los enemigos	
6844	Umber, el archivista	
6845	El descubrimiento de los secretos del pasado	Desvelar los secretos del pasado
7003	Gigantes reducidos	
7383	La corona de la Tierra	
7486	Una recompensa de héroe	
7541	Un servicio para la Horda	
7563	La ira de sangre	
7564	Ojosalvajes	Ojovago
7581	Las selladuras de la prisión	
7582	El revestimiento de la prisión	
7583	Supresión	
7601	La orden de Niby	
7602	Esencia de energía vil pura	
7603	El núcleo infernal de Kroshius	
7621	Un aviso	
7622	Equilibrio de Luz y Sombras	
7623	Lord Pesadilla	
7624	Ulathek el Traidor	
7625	Polvo estelar xorothiano	
7626	La Campana de Dethmoora	
7627	Rueda de la Marcha Negra	
7628	La Vela del Apocalipsis	
7629	Entrega de diablillo	
7630	La arcanita	
7631	Terrorecus de Xoroth	Corcel nefasto xorothiano
7633	Una presentación	
7634	Carcaj antiguo cosido con tendón	
7635	La cuerda adecuada	
7636	El báculo de los Ancestros	
7645	Alimento para caballos enriquecido con maná	
7701	SE BUSCA: vigía Maltorius	SE BUSCA: Sobrestante Maltorius
7721	Combustible para el Ultra-reductor	
7722	La receta del fluido ardiente	¿Qué pasa con el flujo?
7723	¡Malditos dedos gordos!	
7724	Amenaza abrasadora	
7727	¿Incendosaurio? Loqueseasaurio más bien	
7728	OBJETOS ROBADOS: Tobera y espejo espía	OBJETOS ROBADOS: Tobera y catalejo
7729	OPORTUNIDAD LABORAL: Acabar con la competencia	
7730	Infestación de Zukk'ash	
7731	Aguijolatigador	Latigador con aguijón
7732	El informe Zukk'ash	
7733	Calidad mejorada	
7734	Calidad mejorada	
7786	Thunderaan el Hijo del Viento	
7810	El maestro de la arena	
7815	Los quijafortes	¡Quijafortes, colega!
7816	Gammerita	¡Gammerita, colega!
7828	Acechar a los acechadores	
7829	Cazar a los salvajes	
7830	Vengar a los Caídos	
7839	Los vándalos de Vilrama	
7840	Lard perdió su comida	Lard perdió su almuerzo
7841	Un mensaje para los Martillo Salvaje	
7842	Un nuevo mensaje para los Martillo Salvaje	
7843	Un mensaje final para los Martillo Salvaje	
7844	Unos primos caníbales	
7845	El secuestro del anciano Cuernorroto	El secuestro del anciano Colmillopartido
7846	¡Recupera la llave!	
7847	Vuelve con Primigenia Cuernorroto	Regresa junto a Primigenia Colmillopartido
7849	Una separación angustiosa	
7850	Vasijas oscuras	
7861	Se busca: sacerdotisa vil Hexx y sus esbirros	
7862	Oferta de empleo: capitán de la guardia de Poblado Sañadiente	
8153	Cuernos de corcel	Cornamenta de trotador
8182	La mano de Rastakhan	
8231	Los vándalos marinos	
8232	El draco verde	
8234	Bolsa azur sellada	
8235	Los fragmentos codificados	Los trozos codificados
8236	La llave azur	
8251	El polvo mágico	
8252	El coral de las sirenas	
8253	Destruye a Morphaz	
8255	Los trotadores Pezuñamusgo	
8256	El icor de los no-muertos	
8257	La sangre de Morphaz	
8273	La gratitud Oran	
8277	Veneno mortal del desierto	
8278	La última esperanza de Noggle	
8279	El Lexicón del Crepúsculo	El Lexicón Crepuscular
8280	Asegurar las rutas de suministros	
8281	Intensificar la seguridad	
8282	La cartera perdida de Noggle	
8283	Se busca: Pinzamorten el Terror de las arenas	
8284	El misterio del Crepúsculo	El misterio Crepuscular
8285	El desertor	
8286	Lo que nos depara el futuro	
8287	Un propósito terrible	
8301	El buen camino	El camino del honrado
8303	Anacronos	
8304	Queridísima Natalia	
8305	Recuerdos olvidados	
8306	En las fauces de la locura	
8308	La carta perdida de Brann Barbabronce	
8309	Los grabados de los glifos	
8310	Descifrar el código	
8314	Desentrañar el misterio	
8315	La llamada	
8316	Armamentos de guerra	
8318	Mensajes secretos	
8320	Geoseñores Crepusculares	
8321	Vyral el Vil	
8323	El creyente verdadero	
8331	Aurel Hojaurea	
8332	Duques del Consejo	Los Duques del Consejo
8341	Señores del Consejo	
8343	El descubrimiento de Hojaurea	
8348	Sellos de los Duques	
8349	Bor Bravacrín	Bor Ferocrín
8351	Bor quiere hablar contigo	
8352	Cetro del Consejo	
8361	Contactos Abisales	
8365	¡Sombreros de pirata da babor!	¡Sombreros de pirata a babor!
8366	Mamporros en el Mar del Sur	Mamporros en los Mares del Sur
8376	Armamentos de guerra	
8377	Armamentos de guerra	
8378	Armamentos de guerra	
8379	Armamentos de guerra	
8380	Armamentos de guerra	
8381	Armamentos de guerra	
8382	Armamentos de guerra	
8411	ominar los elementos	Dominar los elementos
8412	ótem de espíritu	Tótem de espíritu
8413	Vudú	
8414	Expulsión de los demonios	
8416	Piedras inertes de la Plaga	Piedras de la Plaga inertes
8418	La forja de la piedra de poderío	
8420	Caliente y picante	
8421	La mercancía equivocada	
8422	Plumas de trol	
8423	Parentesco guerrero	
8424	La guerra contra los Sombra Jurada	
8425	Plumas Vudú	
8447	Leyendas veraces	
8460	Aliado a los Fauces de Madera	
8461	Los Muertobosque del Norte	
8462	Habla con Nafien	
8464	Actividad de los Nevada	
8465	Habla con Salfa	
8470	El tótem ritual de los Muertobosque	El tótem de ritual Muertobosque
8471	Tótem ritual Nevada	Tótem de ritual Nevada
8481	La raíz de todos los males	
8484	Negociar la paz	
8485	Negociar la paz	
8519	Un peón en el ajedrez de la vida	
8551	El cofre del capitán	El cofre del Capitán
8552	La banda con monograma	
8553	El aflanje del capitán	El alfanje del Capitán
8554	Enfréntate a Negolash	
8555	Encomienda a los Vuelos	
8575	El libro de contabilidad mágico de Azuregos	
8576	La traducción del libro de contabilidad	
8577	Stewvul, ex mejor amigo	Guisón, ex mejor amigo
8584	¡Nunca me preguntes por mi negocio!	
8585	La Isla del Terror	
8586	Pinchos quimerok potentes de Dirge	Fabulosas chuletillas de quimerok de Dirge
8587	Regresa junto a Narain	
8597	Dracónico para torpes	
8598	ReScaTe	
8599	Una canción de amor para Narain	
8606	¡Señuelo!	
8620	La única receta	
8728	Buenas y malas noticias	
8729	La cólera de Neptulon	
8734	Tyrande y Rémulos	Tyrande y Remulos
8735	Corrupción de Pesadilla	La corrupción de Pesadilla
8736	La Pesadilla se manifiesta	
8741	El regreso del Campeón	
8742	El poder de Kalimdor	
8743	Golpear el gong	
8745	El tesoro del Atemporal	
8747	El camino del protector	
8748	El camino del protector	
8749	El camino del protector	
8750	El camino del protector	
8751	El protector de Kalimdor	
8752	El camino del conquistador	
8753	El camino del conquistador	
8754	El camino del conquistador	
8755	El camino del conquistador	
8756	El conquistador qiraji	
8757	El camino del conjurador	El camino del convocador
8758	El camino del conjurador	El camino del convocador
8759	El camino del conjurador	El camino del convocador
8760	El camino del conjurador	El camino del convocador
8761	El gran convocador	
8800	Equipamiento de Cenarion	Equipamiento de Cenarius
8921	El destilador ectoplásmico	
8922	Un artefacto sobrenatural	
8923	Un artefacto sobrenatural	
8924	Caza de ectoplasmas	
8925	Fuente de energía portátil	
8928	Un mercader sospechoso	
8929	Buscando a Anthion	
8930	Buscando a Anthion	
8946	Prueba de vida	
8947	La extraña petición de Anthion	
8970	En tu destino veo la Isla de Alcaz...	
9023	El veneno perfecto	
9051	Prueba de toxicidad	
9052	Veneno de pétalo de sangre	Veneno de Sangrepétalo
9053	Un ingrediente mejor	
9121	La ciudadela del terror: Naxxramas	
9122	La ciudadela del terror: Naxxramas	
9123	La ciudadela del terror: Naxxramas	
9124	La armadura de acechacriptas no se hace sola...	
9126	Excavaciones para la armadura Segahuesos	
9128	La ecuación elemental	
9131	Armar la acorator	
9136	Flora salvaje	
9141	Me llaman "El Gallo"	
9248	Una humilde ofrenda	
9251	Atiesh, el gran báculo maligno	
9257	Atiesh, el gran báculo del guardián	
9269	Atiesh, el gran báculo del guardián	
9270	Atiesh, el gran báculo del guardián	
9271	Atiesh, el gran báculo del guardián	
9272	Vístete como tal	
9362	Señor de la Guerra Krellian	Señor de la guerra Krellian
9364	Magia fragmentada	
9415	Preséntate ante el alguacil Murazul	
9416	Preséntate ante el general Kirika	
9419	Peinando el desierto	
9422	Peinando el desierto	
9664	Nuevas avanzadas	
9665	Fortalecimiento de nuestras defensas	
65602	¿Qué es el amor?	
]],
	item = [[
765	Hojaplata	
783	Pellejo ligero	
785	Marregal	
2318	Cuero ligero	
2319	Cuero medio	
2447	Flor de paz	
2449	Raíz terrenal	Raíz de tierra
2450	Briarthorn	Brezospina
2453	Hierba cardenal	
2770	Mineral de cobre	Mena de cobre
2771	Mineral de estaño	Mena de estaño
2772	Hierro	Mena de hierro
2775	Mineral de plata	Mena de plata
2776	Mineral de oro	Mena de oro
2835	Piedra basta	Piedra férrea
2836	Piedra burda	
2838	Piedra pesada	
2934	Restos de cuero estropeado	
3355	Acérita salvaje	
3356	Sangrerregia	
3357	Vidarraíz	
3358	Mostacho de Khadgar	
3369	Moho de tumba	Musgo de tumba
3818	Pálida	
3819	Ivernalia	Invernalia
3820	Alga estranguladora	
3821	Espina de oro	
3858	Mineral de mitril	Mena de mitril
4232	Pellejo fino	Pellejo medio
4234	Cuero pesado	
4235	Pellejo pesado	
4304	Cuero grueso	
4625	Flor de Fuego	Flor de fuego
7911	Veraplata	Mena de veraplata
7912	Piedra sólida	
8169	Pellejo grueso	
8170	Cuero basto	
8171	Pellejo basto	
8831	Loto morado	Loto cárdeno
8836	Lágrimas de Arthas	
8838	Solea	
8839	Carolina	
8845	Champiñón fantasma	
8846	Gromsanguina	
10620	Torio	Mena de torio
11370	Hierro Negro	Mena de hierro negro
12365	Piedra densa	
13463	Hojasueño	
13464	Sansam dorado	
13465	Salviargenta de montaña	
13466	Flor de peste	Flor de plaga
13467	Setelo	
13468	Loto negro	
]],
}
if ns.KEEP_STRINGS then ns.NAMES_ES_RAW = RAW end
if not ns.STRINGS_SPANISH then return end

-- lu en table à la première demande de chaque sorte, puis la chaîne est libérée
local names = {}
function ns.SpanishName(kind, id)
	local list = names[kind]
	if not list then
		list = {}
		for nid, es, mx in (RAW[kind] or ""):gmatch("(%d+)\t([^\t\n]*)\t?([^\t\n]*)\n") do
			list[tonumber(nid)] = (MX and mx ~= "") and mx or es
		end
		names[kind], RAW[kind] = list, nil
	end
	return list[tonumber(id)]
end

if ns.Mark then ns.Mark("NamesES") end
