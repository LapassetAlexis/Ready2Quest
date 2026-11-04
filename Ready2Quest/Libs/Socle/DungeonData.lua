-- DungeonData.lua -- GÉNÉRÉ par tools/gen_dungeons.py, ne pas éditer à la main
-- Donjons à 5 de Classic Era 1.15.9 et de Forever 1.60.1 (module « Avant le donjon »).
-- [clé] = { map = mapID d'instance (GetInstanceInfo, 8e retour) ou nil,
--           area = areaID du nom du donjon (C_Map.GetAreaInfo : nom traduit),
--           name = nom anglais (repli), era / fo = { min, max } (Era / Forever),
--           entrances = { areaID des sous-zones d'entrée }, forever = seulement Forever }
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
local ADDON, ns = ...

ns.DUNGEONS = {
	rfc = { map = 389, area = 2437, name = "Ragefire Chasm", era = { 13, 22 }, fo = { 13, 18 } },
	wc = { map = 43, area = 718, name = "Wailing Caverns", era = { 15, 28 }, fo = { 15, 24 } },
	dm = { map = 36, area = 1581, name = "Deadmines", era = { 15, 28 }, fo = { 17, 26 } },
	sfk = { map = 33, area = 209, name = "Shadowfang Keep", era = { 18, 32 }, fo = { 20, 30 }, entrances = { 236 } },
	bfd = { map = 48, area = 719, name = "Blackfathom Deeps", era = { 20, 34 }, fo = { 24, 32 }, entrances = { 2797 } },
	stocks = { map = 34, area = 717, name = "Stormwind Stockade", era = { 22, 34 }, fo = { 24, 32 } },
	gnomer = { map = 90, area = 721, name = "Gnomeregan", era = { 24, 40 }, fo = { 29, 38 }, entrances = { 133 } },
	rfk = { map = 47, area = 491, name = "Razorfen Kraul", era = { 24, 40 }, fo = { 29, 38 }, entrances = { 1717 } },
	sm = { map = 189, area = 796, name = "Scarlet Monastery", era = { 29, 48 }, fo = { 30, 46 } },
	rfd = { map = 129, area = 722, name = "Razorfen Downs", era = { 33, 47 }, fo = { 37, 46 }, entrances = { 1316 } },
	ulda = { map = 70, area = 1337, name = "Uldaman", era = { 38, 53 }, fo = { 41, 51 }, entrances = { 1517 } },
	zf = { map = 209, area = 1176, name = "Zul'Farrak", era = { 43, 54 }, fo = { 44, 54 }, entrances = { 978 } },
	mara = { map = 349, area = 2100, name = "Maraudon", era = { 40, 58 }, fo = { 46, 55 } },
	st = { map = 109, area = 1477, name = "Sunken Temple", era = { 44, 60 }, fo = { 50, 60 } },
	brd = { map = 230, area = 1584, name = "Blackrock Depths", era = { 48, 60 }, fo = { 52, 60 } },
	brs = { map = 229, area = 1583, name = "Blackrock Spire", era = { 52, 60 }, fo = { 55, 60 } },
	dmaul = { map = 429, area = 2557, name = "Dire Maul", era = { 54, 60 }, fo = { 54, 60 }, entrances = { 2577 } },
	scholo = { map = 289, area = 2057, name = "Scholomance", era = { 56, 60 }, fo = { 58, 60 }, entrances = { 2298 } },
	strat = { map = 329, area = 2017, name = "Stratholme", era = { 56, 60 }, fo = { 58, 60 }, entrances = { 2279 } },
	thanes = { map = 3065, area = 16919, name = "The Hall of Thanes", fo = { 13, 18 }, forever = true },
	lordaeron = { map = 2999, area = 16611, name = "Ruins of Lordaeron", fo = { 15, 22 }, entrances = { 153 }, forever = true },
	excavation = { map = 2998, area = 16732, name = "Excavation Site: Wetlands", fo = { 24, 29 }, entrances = { 17732 }, forever = true },
	dalaran = { map = 2959, area = 16544, name = "City of Dalaran", fo = { 28, 33 }, entrances = { 279 }, forever = true },
	drowned = { name = "The Drowned City", fo = { 35, 40 }, forever = true },
	kroldok = { name = "Krol'dok Stronghold", fo = { 40, 45 }, entrances = { 17780 }, forever = true },
	alcaz = { name = "Alcaz Prison", fo = { 48, 53 }, forever = true },
	blackmaw = { name = "Blackmaw Hold", fo = { 55, 60 }, entrances = { 1216 }, forever = true },
	shaper = { name = "Shaper's Terrace", fo = { 58, 60 }, entrances = { 16985 }, forever = true },
}

-- Plans avancés de Forever par donjon : aucune source fiable publiée au
-- 2026-11-03 (voir tools/gen_dungeons.py). Vide plutôt que faux.
ns.DUNGEON_BLUEPRINTS = {
}

if ns.Mark then ns.Mark("DungeonData") end
