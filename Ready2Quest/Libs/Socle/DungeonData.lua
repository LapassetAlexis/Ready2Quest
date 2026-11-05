-- DungeonData.lua -- GÉNÉRÉ par tools/gen_dungeons.py, ne pas éditer à la main
-- Donjons à 5 de Forever 1.60.1 (module « Avant le donjon »).
-- [clé] = { map = mapID d'instance (GetInstanceInfo, 8e retour) ou nil,
--           area = areaID du nom du donjon (C_Map.GetAreaInfo : nom traduit),
--           name = nom anglais (repli), fo = { min, max } (niveaux recommandés),
--           entrances = { areaID des sous-zones d'entrée } }
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
local ADDON, ns = ...

ns.DUNGEONS = {
	rfc = { map = 389, area = 2437, name = "Ragefire Chasm", fo = { 13, 18 } },
	wc = { map = 43, area = 718, name = "Wailing Caverns", fo = { 15, 24 } },
	dm = { map = 36, area = 1581, name = "Deadmines", fo = { 17, 26 } },
	sfk = { map = 33, area = 209, name = "Shadowfang Keep", fo = { 20, 30 }, entrances = { 236 } },
	bfd = { map = 48, area = 719, name = "Blackfathom Deeps", fo = { 24, 32 }, entrances = { 2797 } },
	stocks = { map = 34, area = 717, name = "Stormwind Stockade", fo = { 24, 32 } },
	gnomer = { map = 90, area = 721, name = "Gnomeregan", fo = { 29, 38 }, entrances = { 133 } },
	rfk = { map = 47, area = 491, name = "Razorfen Kraul", fo = { 29, 38 }, entrances = { 1717 } },
	sm = { map = 189, area = 796, name = "Scarlet Monastery", fo = { 30, 46 } },
	rfd = { map = 129, area = 722, name = "Razorfen Downs", fo = { 37, 46 }, entrances = { 1316 } },
	ulda = { map = 70, area = 1337, name = "Uldaman", fo = { 41, 51 }, entrances = { 1517 } },
	zf = { map = 209, area = 1176, name = "Zul'Farrak", fo = { 44, 54 }, entrances = { 978 } },
	mara = { map = 349, area = 2100, name = "Maraudon", fo = { 46, 55 } },
	st = { map = 109, area = 1477, name = "Sunken Temple", fo = { 50, 60 } },
	brd = { map = 230, area = 1584, name = "Blackrock Depths", fo = { 52, 60 } },
	brs = { map = 229, area = 1583, name = "Blackrock Spire", fo = { 55, 60 } },
	dmaul = { map = 429, area = 2557, name = "Dire Maul", fo = { 54, 60 }, entrances = { 2577 } },
	scholo = { map = 289, area = 2057, name = "Scholomance", fo = { 58, 60 }, entrances = { 2298 } },
	strat = { map = 329, area = 2017, name = "Stratholme", fo = { 58, 60 }, entrances = { 2279 } },
	thanes = { map = 3065, area = 16919, name = "The Hall of Thanes", fo = { 13, 18 } },
	lordaeron = { map = 2999, area = 16611, name = "Ruins of Lordaeron", fo = { 15, 22 }, entrances = { 153 } },
	excavation = { map = 2998, area = 16732, name = "Excavation Site: Wetlands", fo = { 24, 29 }, entrances = { 17732 } },
	dalaran = { map = 2959, area = 16544, name = "City of Dalaran", fo = { 28, 33 }, entrances = { 279 } },
	drowned = { name = "The Drowned City", fo = { 35, 40 } },
	kroldok = { name = "Krol'dok Stronghold", fo = { 40, 45 }, entrances = { 17780 } },
	alcaz = { name = "Alcaz Prison", fo = { 48, 53 } },
	blackmaw = { name = "Blackmaw Hold", fo = { 55, 60 }, entrances = { 1216 } },
	shaper = { name = "Shaper's Terrace", fo = { 58, 60 }, entrances = { 16985 } },
}

-- Plans avancés de Forever par donjon : aucune source fiable publiée au
-- 2026-11-03 (voir tools/gen_dungeons.py). Vide plutôt que faux.
ns.DUNGEON_BLUEPRINTS = {
}

if ns.Mark then ns.Mark("DungeonData") end
