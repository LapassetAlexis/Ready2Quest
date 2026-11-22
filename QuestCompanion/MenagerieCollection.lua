-- MenagerieCollection.lua -- Lot 3 : sceaux de zone, complétion par type, paliers et titres de dresseur (QuestCompanion 2.0)
--
-- La Ménagerie devient une collection à finir, à part de l'Exploration (dont
-- le pourcentage ne compte plus que lieux, récolte et quêtes) :
--   * Sceau de zone : toutes les espèces d'une zone capturées (version
--     normale ; les boss du monde ne comptent pas) -> la zone est scellée pour
--     toujours. Dans une zone scellée, les brillantes sont plus fréquentes
--     (×SEAL_SHINY_MULT, enveloppe de ns:ShinyChance). Chaque biome a son
--     cadre (premier sceau du biome) et son fond (deuxième sceau : une
--     texture de sol du client, BIOME_GROUND, appelée par FileDataID).
--   * Complétion par type : des paliers d'espèces capturées par type de
--     créature renforcent l'effet du compagnon de ce type
--     (ns:MenagerieTypeBonus, lu par CompanionEffects.lua).
--   * Paliers globaux : 10, 25, 50, 100, 250 espèces -> une récompense et un
--     titre de dresseur (ns:TrainerTitle). 3.6.0 : puis 500, 750, 1 000,
--     1 500, 2 000, 2 500, 3 000 et « tout Azeroth » (toutes les espèces de
--     ta faction, ns:MenagerieAzeroth) ; leur titre vient du haut fait
--     men_species_<n> / men_species_all (FeatsCatMenagerie.lua).
--   * 3.6.0 : médailles de type (paliers 4 et 5 : 80 et 160 espèces d'un type
--     courant, 40 et 80 d'un type rare), cosmétiques seulement : elles ne
--     renforcent pas le compagnon (ns:MenagerieMedal, fiche de dresseur).
-- Données (par personnage, avec le compagnon) : CompanionData().collection =
--   { seals = { [zoneID] = date }, types = { [clé] = palier annoncé },
--     ranks = { [nombre] = date }, init = true }
-- Rien ne se perd : un sceau, un palier ou un titre gagné le reste.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.SEAL_SHINY_MULT = 1.5
-- 3.6.0 (plan 3.6, lot 1B) : passé le deuxième sceau d'un biome (son cadre,
-- puis son fond), chaque sceau de ce biome donne des paillettes
ns.SEAL_GLITTER = { from = 3, glitter = 15 }
-- paliers par type : les types courants en extérieur, puis les plus rares
ns.MENAGERIE_TYPE_TIERS = { common = { 10, 20, 40 }, rare = { 5, 10, 20 } }
ns.MENAGERIE_TYPE_RARE = { dragonkin = true, demon = true, giant = true, mechanical = true }
ns.MENAGERIE_TYPE_STEP = 0.25           -- force en plus par palier atteint
-- paliers globaux (espèces capturées, une version suffit)
ns.TRAINER_RANKS = {
	{ count = 10,  key = "apprentice",  aids = { "appat", "lasso" } },
	{ count = 25,  key = "trainer",     cosmetic = { kind = "frame", id = "trainer" } },
	{ count = 50,  key = "seasoned",    aids = { "sifflet" }, cosmetic = { kind = "bg", id = "menagerie" } },
	{ count = 100, key = "master",      aids = { "sifflet" }, cosmetic = { kind = "frame", id = "master" } },
	{ count = 250, key = "grandmaster", aids = { "sifflet", "sifflet" }, cosmetic = { kind = "bg", id = "grandmaster" } },
	-- 3.6.0 : des buts longs ; le haut fait du palier donne le titre (et le
	-- fond de fiche à 500), rien ici
	{ count = 500,  key = "beastwalker" },
	{ count = 750,  key = "wildtracker" },
	{ count = 1000, key = "thousand" },
	{ count = 1500, key = "warden" },
	{ count = 2000, key = "sage" },
	{ count = 2500, key = "archivist" },
	{ count = 3000, key = "census" },
}
-- « tout Azeroth » : toutes les espèces de ta faction ; son seuil (count) est
-- lu à la demande (ns:MenagerieAzeroth), jamais sous 3 001 pour rester le dernier
ns.TRAINER_RANKS[#ns.TRAINER_RANKS + 1] = setmetatable({ key = "azeroth", all = true, feat = "men_species_all" },
	{ __index = function(_, field)
		if field ~= "count" then return nil end
		local _, need = ns:MenagerieAzeroth()
		return math.max(tonumber(need) or 0, 3001)
	end })
-- 3.6.0 : médailles de type, paliers 4 et 5 (après MENAGERIE_TYPE_TIERS)
ns.MENAGERIE_MEDAL_TIERS = { common = { 80, 160 }, rare = { 40, 80 } }

-- biomes extérieurs ; une zone sans biome connu : forêt
local BIOMES = { "forest", "nightforest", "canyon", "savanna", "snow", "swamp", "desert", "blight", "jungle", "volcanic" }
ns.MENAGERIE_BIOMES = BIOMES
-- le biome de chaque zone extérieure (uiMapID) : son cadre et son paysage
-- (repris de l'ancien album des souvenirs, retiré en 2.6.0)
local ZONE_BIOME = {
	-- Kalimdor
	[1411] = "canyon", [1412] = "savanna", [1413] = "savanna", [1438] = "nightforest", [1439] = "nightforest",
	[1440] = "nightforest", [1441] = "canyon", [1442] = "canyon", [1443] = "desert", [1444] = "jungle",
	[1445] = "swamp", [1446] = "desert", [1447] = "nightforest", [1448] = "blight", [1449] = "jungle",
	[1450] = "nightforest", [1451] = "desert", [1452] = "snow",
	-- Royaumes de l'Est
	[1416] = "snow", [1417] = "forest", [1418] = "canyon", [1419] = "volcanic", [1420] = "blight",
	[1421] = "blight", [1422] = "blight", [1423] = "blight", [1424] = "forest", [1425] = "forest",
	[1426] = "snow", [1427] = "volcanic", [1428] = "volcanic", [1429] = "forest", [1430] = "blight",
	[1431] = "nightforest", [1432] = "forest", [1433] = "forest", [1434] = "jungle", [1435] = "swamp",
	[1436] = "savanna", [1437] = "swamp",
}
ns.MENAGERIE_ZONE_BIOME = ZONE_BIOME
-- fond de chaque biome (2.7.0) : une texture de sol du client (tileset des
-- zones d'origine), appelée par FileDataID, jamais embarquée (wago.tools,
-- listfile et casc). Assombrie par la teinte pour que le compagnon et son nom
-- restent lisibles ; refusée par le client : aplat sombre (Companion.lua).
local BIOME_GROUND = {
	forest      = { 187124, { 0.78, 0.78, 0.74, 1 } },  -- tileset/elwynn/elwynnflowerbase
	nightforest = { 188474, { 0.62, 0.66, 0.88, 1 } },  -- tileset/felwood/felwoodmoss
	canyon      = { 186915, { 0.74, 0.70, 0.66, 1 } },  -- tileset/barrens/barrensbaserock
	savanna     = { 186908, { 0.78, 0.74, 0.66, 1 } },  -- tileset/barrens/barrensbasegrassgold
	snow        = { 189051, { 0.62, 0.68, 0.78, 1 } },  -- tileset/winterspring grove/winterspringsnowripple
	swamp       = { 188851, { 0.66, 0.70, 0.60, 1 } },  -- tileset/swamp of sorrows/swampsorrowsroot01
	desert      = { 188872, { 0.70, 0.64, 0.52, 1 } },  -- tileset/tanaris/tanarissandbase02
	blight      = { 188688, { 0.72, 0.70, 0.66, 1 } },  -- tileset/plaguelands/plaguedearthcreep01
	jungle      = { 188829, { 0.74, 0.78, 0.70, 1 } },  -- tileset/stranglethorn/stranglethornplants01
	volcanic    = { 186959, { 0.78, 0.70, 0.66, 1 } },  -- tileset/burningstepps/burningsteppsrocklava
}
ns.MENAGERIE_BIOME_GROUND = BIOME_GROUND
-- liseré du cadre de chaque biome : { filet, filet intérieur }, aux teintes
-- du biome (sol, ciel)
local BIOME_EDGE = {
	forest      = { { 0.42, 0.70, 0.30, 1 }, { 0.20, 0.38, 0.14, 0.8 } },
	nightforest = { { 0.62, 0.45, 0.85, 1 }, { 0.28, 0.18, 0.42, 0.8 } },
	canyon      = { { 0.86, 0.50, 0.26, 1 }, { 0.46, 0.24, 0.10, 0.8 } },
	savanna     = { { 0.88, 0.74, 0.36, 1 }, { 0.50, 0.40, 0.16, 0.8 } },
	snow        = { { 0.78, 0.90, 1.00, 1 }, { 0.40, 0.55, 0.70, 0.8 } },
	swamp       = { { 0.45, 0.58, 0.40, 1 }, { 0.22, 0.30, 0.20, 0.8 } },
	desert      = { { 0.95, 0.80, 0.50, 1 }, { 0.58, 0.44, 0.22, 0.8 } },
	blight      = { { 0.60, 0.70, 0.40, 1 }, { 0.30, 0.26, 0.30, 0.8 } },
	jungle      = { { 0.30, 0.78, 0.45, 1 }, { 0.10, 0.36, 0.18, 0.8 } },
	volcanic    = { { 0.95, 0.38, 0.18, 1 }, { 0.42, 0.12, 0.06, 0.8 } },
}
local TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local DIALOG_BORDER  = "Interface\\DialogFrame\\UI-DialogBox-Border"

-- ---------------------------------------------------------------------------
-- Chaînes
-- ---------------------------------------------------------------------------
local FR = {
	TRAINER_apprentice     = "Apprenti dresseur",
	TRAINER_trainer        = "Dresseur",
	TRAINER_seasoned       = "Dresseur confirmé",
	TRAINER_master         = "Maître dresseur",
	TRAINER_grandmaster    = "Grand maître dresseur",
	TRAINER_beastwalker    = "Arpenteur des bêtes",
	TRAINER_wildtracker    = "Pisteur des terres sauvages",
	TRAINER_thousand       = "Dresseur aux mille bêtes",
	TRAINER_warden         = "Gardien du bestiaire",
	TRAINER_sage           = "Sage des créatures",
	TRAINER_archivist      = "Archiviste d'Azeroth",
	TRAINER_census         = "Grand recenseur",
	TRAINER_azeroth        = "Dresseur de tout Azeroth",
	MEN_MEDAL_MSG          = "%s : %d espèces capturées, médaille de palier %d ! Elle brille sur ta fiche de dresseur.",
	MEN_COLL_TIP_MEDAL     = "%s : médaille de palier %d (%d espèces)",
	BIOME_forest = "forêt", BIOME_nightforest = "forêt de nuit", BIOME_canyon = "canyon", BIOME_savanna = "savane",
	BIOME_snow = "neige", BIOME_swamp = "marais", BIOME_desert = "désert", BIOME_blight = "terres maudites",
	BIOME_jungle = "jungle", BIOME_volcanic = "volcan",
	COMP_FRAME_SEAL        = "Sceau : %s",
	COMP_BG_SEAL           = "Paysage : %s",
	COMP_FRAME_TRAINER     = "Insigne du dresseur",
	COMP_FRAME_MASTER      = "Insigne du maître",
	COMP_BG_MENAGERIE      = "Enclos des créatures",
	COMP_BG_GRANDMASTER    = "Grand enclos",
	COMP_REQ_seal          = "sceau d'une zone (%s)",
	COMP_REQ_seal2         = "sceau de deux zones (%s)",
	COMP_REQ_trainer       = "%d espèces capturées",
	MEN_SEAL_MSG           = "Sceau de %s ! Toutes ses espèces sont dans ton Codex : brillantes ×%s ici.",
	MEN_SEAL_NEW           = "Nouveau : %s.",
	MEN_SEAL_GLITTER       = "+%d paillettes : sceau n° %d du biome %s.",
	MEN_TYPE_MSG           = "%s : %d espèces capturées, palier %d ! Un compagnon de ce type gagne en force (%s).",
	MEN_RANK_MSG           = "%d espèces capturées : te voilà %s ! %s",
	MEN_RANK_GIFT          = "Gain : %s.",
	MEN_CATCHUP            = "Créatures : %d sceaux, titre « %s ».",
	MEN_CATCHUP_NOTITLE    = "Créatures : %d sceaux.",
	MEN_COLL_SEAL          = "Sceau de %s : %d/%d espèces",
	MEN_COLL_SEALED        = "%s scellée",
	MEN_COLL_SEAL_NA       = "Pas de sceau ici : zone sans liste d'espèces.",
	MEN_COLL_SEAL_TODO     = "Capture toutes ses espèces (hors boss du monde) : %s et brillantes ×%s ici.",
	MEN_COLL_SEAL_DONE     = "Brillantes ×%s dans cette zone.",
	MEN_COLL_SEALS         = "Sceaux : %d zones scellées",
	MEN_COLL_SEALS_TIP     = "Choisis une zone pour voir son sceau.",
	MEN_COLL_TITLE         = "%s · %d espèces",
	MEN_COLL_TITLE_NEXT    = "%s · %d espèces · %d pour « %s »",
	MEN_COLL_NOTITLE       = "Pas encore de titre · %d/%d espèces pour « %s »",
	MEN_COLL_TIP_TYPES     = "Par type (force du compagnon de ce type) :",
	MEN_COLL_TIP_TYPE      = "%s : %d · palier %d/%d (%s)",
	MEN_COLL_TIP_TYPE_NEXT = "%s : %d · palier %d/%d (%s) · prochain à %d",
	MEN_COLL_TIP_RANKS     = "Titres de dresseur :",
	MEN_COLL_TIP_RANK      = "%d espèces : %s — %s",
	MEN_COLL_FORCE         = "force +%s",
	JRN_PROG_SEAL          = "Sceau de la zone : %d/%d espèces capturées · détail dans la page Créatures",
	JRN_PROG_SEALED        = "Zone scellée : brillantes ×%s ici",
	MEN_DECIMAL_SEP        = ",",
}
local EN = {
	TRAINER_apprentice     = "Apprentice Trainer",
	TRAINER_trainer        = "Trainer",
	TRAINER_seasoned       = "Seasoned Trainer",
	TRAINER_master         = "Master Trainer",
	TRAINER_grandmaster    = "Grand Master Trainer",
	TRAINER_beastwalker    = "Beastwalker",
	TRAINER_wildtracker    = "Wildtracker",
	TRAINER_thousand       = "Trainer of a Thousand Beasts",
	TRAINER_warden         = "Bestiary Warden",
	TRAINER_sage           = "Creature Sage",
	TRAINER_archivist      = "Archivist of Azeroth",
	TRAINER_census         = "Grand Census-Taker",
	TRAINER_azeroth        = "Trainer of All Azeroth",
	MEN_MEDAL_MSG          = "%s: %d species captured, tier %d medal! It shines on your trainer card.",
	MEN_COLL_TIP_MEDAL     = "%s: tier %d medal (%d species)",
	BIOME_forest = "forest", BIOME_nightforest = "night forest", BIOME_canyon = "canyon", BIOME_savanna = "savanna",
	BIOME_snow = "snow", BIOME_swamp = "swamp", BIOME_desert = "desert", BIOME_blight = "blighted lands",
	BIOME_jungle = "jungle", BIOME_volcanic = "volcano",
	COMP_FRAME_SEAL        = "Seal: %s",
	COMP_BG_SEAL           = "Landscape: %s",
	COMP_FRAME_TRAINER     = "Trainer's badge",
	COMP_FRAME_MASTER      = "Master's badge",
	COMP_BG_MENAGERIE      = "Creature pen",
	COMP_BG_GRANDMASTER    = "Grand pen",
	COMP_REQ_seal          = "seal of one zone (%s)",
	COMP_REQ_seal2         = "seal of two zones (%s)",
	COMP_REQ_trainer       = "%d species captured",
	MEN_SEAL_MSG           = "%s sealed! Every species there is in your Codex: shinies ×%s here.",
	MEN_SEAL_NEW           = "New: %s.",
	MEN_SEAL_GLITTER       = "+%d glitter: seal no. %d of the %s biome.",
	MEN_TYPE_MSG           = "%s: %d species captured, tier %d! A companion of this type grows stronger (%s).",
	MEN_RANK_MSG           = "%d species captured: you are now a %s! %s",
	MEN_RANK_GIFT          = "Reward: %s.",
	MEN_CATCHUP            = "Creatures: %d seals, title “%s”.",
	MEN_CATCHUP_NOTITLE    = "Creatures: %d seals.",
	MEN_COLL_SEAL          = "%s seal: %d/%d species",
	MEN_COLL_SEALED        = "%s sealed",
	MEN_COLL_SEAL_NA       = "No seal here: this zone has no species list.",
	MEN_COLL_SEAL_TODO     = "Capture every species (world bosses aside): %s and shinies ×%s here.",
	MEN_COLL_SEAL_DONE     = "Shinies ×%s in this zone.",
	MEN_COLL_SEALS         = "Seals: %d zones sealed",
	MEN_COLL_SEALS_TIP     = "Pick a zone to see its seal.",
	MEN_COLL_TITLE         = "%s · %d species",
	MEN_COLL_TITLE_NEXT    = "%s · %d species · %d for “%s”",
	MEN_COLL_NOTITLE       = "No title yet · %d/%d species for “%s”",
	MEN_COLL_TIP_TYPES     = "By type (strength of a companion of that type):",
	MEN_COLL_TIP_TYPE      = "%s: %d · tier %d/%d (%s)",
	MEN_COLL_TIP_TYPE_NEXT = "%s: %d · tier %d/%d (%s) · next at %d",
	MEN_COLL_TIP_RANKS     = "Trainer titles:",
	MEN_COLL_TIP_RANK      = "%d species: %s — %s",
	MEN_COLL_FORCE         = "strength +%s",
	JRN_PROG_SEAL          = "Zone seal: %d/%d species captured · details on the Creatures page",
	JRN_PROG_SEALED        = "Zone sealed: shinies ×%s here",
	MEN_DECIMAL_SEP        = ".",
}

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function G(name) return rawget(_G, name) end
local function ModuleOn() return ns.CompanionOn and ns.CompanionOn() or false end
local function Now() return tonumber((Call(G("time")))) or 0 end

-- Nombre décimal dans la langue du client (« 1,5 » / « 1.5 »), sans zéros inutiles
local function Dec(value)
	local text = string.format("%.2f", tonumber(value) or 0):gsub("0+$", ""):gsub("%.$", "")
	if L.MEN_DECIMAL_SEP == "," then text = text:gsub("%.", ",") end
	return text
end
ns.MenagerieDecimal = Dec

-- ---------------------------------------------------------------------------
-- Cosmétiques : un cadre et un fond par biome, ceux des titres
-- (hors coffres : palier 0 et une condition que seul ce fichier remplit)
-- ---------------------------------------------------------------------------
local function BiomeLabel(biome) return L["BIOME_" .. tostring(biome)] or tostring(biome) end

local COSMETICS = {}
for _, biome in ipairs(BIOMES) do
	local edge = BIOME_EDGE[biome]
	COSMETICS[#COSMETICS + 1] = { kind = "frame", def = { id = "seal_" .. biome, label = "COMP_FRAME_SEAL_" .. biome,
		tier = 0, unlock = { seal = biome, count = 1 }, edge = edge[1], inner = edge[2],
		backdrop = { file = TOOLTIP_BORDER, size = 14, color = { edge[1][1], edge[1][2], edge[1][3] } } } }
	COSMETICS[#COSMETICS + 1] = { kind = "bg", def = { id = "seal_" .. biome, label = "COMP_BG_SEAL_" .. biome,
		tier = 0, unlock = { seal = biome, count = 2 },
		texture = BIOME_GROUND[biome][1], color = BIOME_GROUND[biome][2], coords = { 0, 0.88, 0, 1 } } }
	FR["COMP_FRAME_SEAL_" .. biome] = string.format(FR.COMP_FRAME_SEAL, FR["BIOME_" .. biome])
	EN["COMP_FRAME_SEAL_" .. biome] = string.format(EN.COMP_FRAME_SEAL, EN["BIOME_" .. biome])
	FR["COMP_BG_SEAL_" .. biome] = string.format(FR.COMP_BG_SEAL, FR["BIOME_" .. biome])
	EN["COMP_BG_SEAL_" .. biome] = string.format(EN.COMP_BG_SEAL, EN["BIOME_" .. biome])
end
COSMETICS[#COSMETICS + 1] = { kind = "frame", def = { id = "trainer", label = "COMP_FRAME_TRAINER", tier = 0,
	unlock = { trainer = 25 }, edge = { 0.85, 0.62, 0.30, 1 }, inner = { 0.45, 0.30, 0.12, 0.8 },
	backdrop = { file = DIALOG_BORDER, size = 16, color = { 0.95, 0.75, 0.45 } } } }
COSMETICS[#COSMETICS + 1] = { kind = "bg", def = { id = "menagerie", label = "COMP_BG_MENAGERIE", tier = 0,
	unlock = { trainer = 50 }, color = { 0.10, 0.16, 0.08, 0.90 },
	gradient = { top = { 0.16, 0.24, 0.10, 0.88 }, bottom = { 0.30, 0.22, 0.10, 0.90 } } } }
COSMETICS[#COSMETICS + 1] = { kind = "frame", def = { id = "master", label = "COMP_FRAME_MASTER", tier = 0,
	unlock = { trainer = 100 }, edge = { 1.0, 0.82, 0.40, 1 }, inner = { 0.62, 0.42, 0.14, 0.8 },
	backdrop = { file = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", size = 16, color = { 1, 1, 1 } } } }
COSMETICS[#COSMETICS + 1] = { kind = "bg", def = { id = "grandmaster", label = "COMP_BG_GRANDMASTER", tier = 0,
	unlock = { trainer = 250 }, color = { 0.18, 0.10, 0.04, 0.92 },
	gradient = { top = { 0.08, 0.05, 0.14, 0.92 }, bottom = { 0.42, 0.28, 0.08, 0.92 } } } }
ns.MENAGERIE_COSMETICS = COSMETICS
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.MENAGERIE_COLLECTION_STRINGS = { fr = FR, en = EN } end

local LISTS = { frame = "COMPANION_FRAMES", bg = "COMPANION_BACKGROUNDS" }
for _, item in ipairs(COSMETICS) do
	local list = ns[LISTS[item.kind]]
	if type(list) == "table" then
		local present = false
		for _, def in ipairs(list) do if def.id == item.def.id then present = true end end
		if not present then list[#list + 1] = item.def end
	end
end
-- libellés du catalogue : même registre que les autres cosmétiques
if type(ns.COMPANION_STRINGS) == "table" then
	for _, item in ipairs(COSMETICS) do
		ns.COMPANION_STRINGS.fr[item.def.label], ns.COMPANION_STRINGS.en[item.def.label] = FR[item.def.label], EN[item.def.label]
	end
	for _, key in ipairs({ "COMP_REQ_seal", "COMP_REQ_seal2", "COMP_REQ_trainer" }) do
		ns.COMPANION_STRINGS.fr[key], ns.COMPANION_STRINGS.en[key] = FR[key], EN[key]
	end
end

local function CosmeticDef(kind, id)
	for _, item in ipairs(COSMETICS) do
		if item.kind == kind and item.def.id == id then return item.def end
	end
	return nil
end

-- Condition lisible des cosmétiques de ce fichier (« sceau d'une zone (forêt) »)
do
	local previous = ns.CompanionRequirement
	function ns:CompanionRequirement(unlock, ...)
		if type(unlock) == "table" and unlock.seal then
			return self:F((tonumber(unlock.count) or 1) >= 2 and "COMP_REQ_seal2" or "COMP_REQ_seal", BiomeLabel(unlock.seal))
		end
		if type(unlock) == "table" and unlock.trainer then return self:F("COMP_REQ_trainer", unlock.trainer) end
		if previous then return previous(self, unlock, ...) end
		return ""
	end
end

-- ---------------------------------------------------------------------------
-- Données
-- ---------------------------------------------------------------------------
function ns:MenagerieCollectionData()
	local data = self:CompanionData()
	local coll = type(data.collection) == "table" and data.collection or {}
	coll.seals = type(coll.seals) == "table" and coll.seals or {}
	coll.types = type(coll.types) == "table" and coll.types or {}
	coll.ranks = type(coll.ranks) == "table" and coll.ranks or {}
	coll.medals = type(coll.medals) == "table" and coll.medals or {}
	data.collection = coll
	return coll
end

function ns:MenagerieZoneBiome(zoneID)
	local biome = ZONE_BIOME[tonumber(zoneID) or zoneID]
	if biome and BIOME_EDGE[biome] then return biome end
	return "forest"
end

local function ZoneName(self, zoneID)
	local info = self.MapInfo and self:MapInfo(zoneID)
	return (info and info.name) or tostring(zoneID)
end

-- Débloque un cosmétique de ce fichier ; renvoie son libellé s'il est nouveau
local function Unlock(self, kind, id)
	local def = CosmeticDef(kind, id)
	if not def then return nil end
	local unlocked = self:CompanionData().unlocked
	if type(unlocked) ~= "table" then return nil end
	local key = kind .. ":" .. id
	if unlocked[key] then return nil end
	unlocked[key] = true
	return L[def.label] or id
end

local function Refreshed(self)
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	if self.CompanionApplyOrnaments then pcall(self.CompanionApplyOrnaments, self) end
end

-- ---------------------------------------------------------------------------
-- Sceaux de zone
-- ---------------------------------------------------------------------------
-- Espèces capturées (version normale) / espèces de la zone : la table livrée
-- filtrée par ta faction, plus celles apprises en route ; les boss du monde
-- ne comptent pas. need = 0 : zone sans table (pas de sceau possible).
function ns:MenagerieSealProgress(zoneID)
	zoneID = tonumber(zoneID)
	if not zoneID or not self.BestiaryStaticZone or not self:BestiaryStaticZone(zoneID) then return 0, 0 end
	local have, need = 0, 0
	for npcID, species in pairs(self:BestiarySpecies(zoneID)) do
		local caught = self.CaptureHas and self:CaptureHas(npcID, false) or false
		-- 3.5.1 : les lignes de niveau 9999 de la table (créatures de script,
		-- qu'on n'abat pas) ne comptent que si tu en as capturé une
		local lvl = species.lvl
		local lo = type(lvl) == "table" and tonumber(lvl[1]) or tonumber(lvl)
		local unreachable = lo ~= nil and lo >= 9999 and not caught
		if species.class ~= "worldboss" and not unreachable then
			need = need + 1
			if caught then have = have + 1 end
		end
	end
	return have, need
end

function ns:MenagerieSealed(zoneID)
	zoneID = tonumber(zoneID)
	return zoneID ~= nil and self:MenagerieCollectionData().seals[zoneID] ~= nil
end

function ns:MenagerieSeals()
	local list = {}
	for zoneID in pairs(self:MenagerieCollectionData().seals) do list[#list + 1] = zoneID end
	table.sort(list)
	return list
end

-- Sceaux d'un biome
function ns:MenagerieBiomeSeals(biome)
	local count = 0
	for zoneID in pairs(self:MenagerieCollectionData().seals) do
		if self:MenagerieZoneBiome(zoneID) == biome then count = count + 1 end
	end
	return count
end

-- Cosmétiques gagnés par les sceaux d'un biome ; renvoie les libellés nouveaux
local function SealRewards(self, biome)
	local fresh, count = {}, self:MenagerieBiomeSeals(biome)
	if count >= 1 then fresh[#fresh + 1] = Unlock(self, "frame", "seal_" .. biome) end
	if count >= 2 then fresh[#fresh + 1] = Unlock(self, "bg", "seal_" .. biome) end
	return fresh
end

-- Zone complète : scellée pour toujours. opts.quiet : sans message (rattrapage).
-- Renvoie true si la zone vient d'être scellée.
function ns:MenagerieSealCheck(zoneID, opts)
	opts = opts or {}
	zoneID = tonumber(zoneID)
	if not zoneID or not ModuleOn() or self:MenagerieSealed(zoneID) then return false end
	local have, need = self:MenagerieSealProgress(zoneID)
	if need == 0 or have < need then return false end
	self:MenagerieCollectionData().seals[zoneID] = Now()
	local biome = self:MenagerieZoneBiome(zoneID)
	local fresh = SealRewards(self, biome)
	-- 3.6.0 : le troisième sceau d'un biome et les suivants : des paillettes
	local nth, glitter = self:MenagerieBiomeSeals(biome), 0
	if nth >= ns.SEAL_GLITTER.from and self.PaillettesAdd and self:DB().companionCapture ~= false then
		glitter = ns.SEAL_GLITTER.glitter
		self:PaillettesAdd(glitter, "seal")
	end
	if not opts.quiet then
		local name = ZoneName(self, zoneID)
		self:Print(self:F("MEN_SEAL_MSG", name, Dec(ns.SEAL_SHINY_MULT)))
		for _, label in ipairs(fresh) do self:Print(self:F("MEN_SEAL_NEW", label)) end
		if glitter > 0 then self:Print(self:F("MEN_SEAL_GLITTER", glitter, nth, BiomeLabel(biome))) end
		if self.CompanionSay then self:CompanionSay("UNLOCK", { force = true, args = { fresh[1] or self:F("MEN_COLL_SEALED", name) } }) end
		if self.CompanionFx then pcall(self.CompanionFx, self, "sparkle") end
	end
	Refreshed(self)
	return true
end

-- Brillantes plus fréquentes dans une zone scellée (la zone où tu es : c'est
-- là que se fait le tirage)
do
	local previous = ns.ShinyChance
	if previous then
		function ns:ShinyChance(class, killed, ...)
			local chance = previous(self, class, killed, ...)
			local zoneID = self.JournalZone and self:JournalZone()
			if zoneID and self:MenagerieSealed(zoneID) then chance = chance * ns.SEAL_SHINY_MULT end
			return chance
		end
	end
end

-- ---------------------------------------------------------------------------
-- Complétion par type
-- ---------------------------------------------------------------------------
-- Type d'une espèce capturée : sa fiche, sinon ce que le carnet en a appris
local function TypeIndex(self)
	local index = {}
	for _, zone in pairs(self.BestiaryData and self:BestiaryData() or {}) do
		if type(zone) == "table" then
			for npcID, species in pairs(zone) do
				if type(species) == "table" and species.type and not index[npcID] then index[npcID] = species.type end
			end
		end
	end
	return index
end

-- { [clé de type] = espèces capturées (une version suffit) }
function ns:MenagerieTypeCounts()
	local counts = {}
	for _, key in ipairs(ns.CREATURE_TYPES or {}) do counts[key] = 0 end
	local index
	for npcID, entry in pairs(self.CaptureData and self:CaptureData().creatures or {}) do
		if type(entry) == "table" then
			local text = entry.type
			if not text then
				index = index or TypeIndex(self)
				text = index[npcID] or index[tonumber(npcID)]
			end
			local key = self.CreatureTypeKey and self:CreatureTypeKey(text)
			if key then counts[key] = (counts[key] or 0) + 1 end
		end
	end
	return counts
end

function ns:MenagerieTypeTiers(typeKey)
	return ns.MENAGERIE_TYPE_RARE[typeKey or ""] and ns.MENAGERIE_TYPE_TIERS.rare or ns.MENAGERIE_TYPE_TIERS.common
end

-- palier atteint (0..3), espèces capturées de ce type, prochain seuil (nil au bout)
function ns:MenagerieTypeTier(typeKey, counts)
	local count = (counts or self:MenagerieTypeCounts())[typeKey] or 0
	local tier, nextNeed = 0, nil
	for index, need in ipairs(self:MenagerieTypeTiers(typeKey)) do
		if count >= need then tier = index elseif not nextNeed then nextNeed = need end
	end
	return tier, count, nextNeed
end

-- Force en plus d'un compagnon de ce type (CompanionEffects.lua)
function ns:MenagerieTypeBonus(typeKey)
	if not typeKey or not ModuleOn() then return 0 end
	local tier = self:MenagerieTypeTier(typeKey)
	return tier * ns.MENAGERIE_TYPE_STEP
end

-- 3.6.0 : médaille d'un type (0 à 5) : les paliers 1 à 3 (force du
-- compagnon), puis 4 et 5 (MENAGERIE_MEDAL_TIERS, cosmétiques seulement).
-- Rend la médaille, le nombre d'espèces et le prochain seuil (nil au bout).
function ns:MenagerieMedal(typeKey, counts)
	local tier, count, nextNeed = self:MenagerieTypeTier(typeKey, counts)
	local more = ns.MENAGERIE_TYPE_RARE[typeKey or ""] and ns.MENAGERIE_MEDAL_TIERS.rare or ns.MENAGERIE_MEDAL_TIERS.common
	if tier >= #self:MenagerieTypeTiers(typeKey) then
		nextNeed = nil
		for index, need in ipairs(more) do
			if count >= need then tier = #self:MenagerieTypeTiers(typeKey) + index elseif not nextNeed then nextNeed = need end
		end
	end
	return tier, count, nextNeed
end

-- { [clé de type] = médaille 0..5 } (fiche de dresseur)
function ns:MenagerieMedals()
	local medals, counts = {}, self:MenagerieTypeCounts()
	for _, key in ipairs(ns.CREATURE_TYPES or {}) do medals[key] = (self:MenagerieMedal(key, counts)) end
	return medals
end

-- Médailles 4 et 5 gagnées depuis la dernière fois : annoncées une fois
function ns:MenagerieMedalCheck(opts)
	opts = opts or {}
	if not ModuleOn() then return {} end
	local seen, counts, gained = self:MenagerieCollectionData().medals, self:MenagerieTypeCounts(), {}
	local base = #ns.MENAGERIE_TYPE_TIERS.common
	for _, key in ipairs(ns.CREATURE_TYPES or {}) do
		local tier, count = self:MenagerieMedal(key, counts)
		if tier > base and tier > (tonumber(seen[key]) or base) then
			seen[key] = tier
			gained[#gained + 1] = { key = key, tier = tier, count = count }
			if not opts.quiet then self:Print(self:F("MEN_MEDAL_MSG", self:CreatureTypeLabel(key), count, tier)) end
		end
	end
	return gained
end

-- Paliers de type franchis depuis la dernière fois : annoncés une fois
function ns:MenagerieTypeCheck(opts)
	opts = opts or {}
	if not ModuleOn() then return {} end
	local seen, counts, gained = self:MenagerieCollectionData().types, self:MenagerieTypeCounts(), {}
	for _, key in ipairs(ns.CREATURE_TYPES or {}) do
		local tier, count = self:MenagerieTypeTier(key, counts)
		if tier > (tonumber(seen[key]) or 0) then
			seen[key] = tier
			gained[#gained + 1] = { key = key, tier = tier, count = count }
			if not opts.quiet then
				self:Print(self:F("MEN_TYPE_MSG", self:CreatureTypeLabel(key), count, tier,
					self:F("MEN_COLL_FORCE", Dec(tier * ns.MENAGERIE_TYPE_STEP))))
			end
		end
	end
	return gained
end

-- ---------------------------------------------------------------------------
-- Paliers globaux et titres de dresseur
-- ---------------------------------------------------------------------------
function ns:MenagerieSpeciesCount()
	local count = 0
	for _, entry in pairs(self.CaptureData and self:CaptureData().creatures or {}) do
		if type(entry) == "table" then count = count + 1 end
	end
	return count
end

-- 3.6.0 : « tout Azeroth » : espèces de ta faction capturées / à capturer
-- (la table livrée, comme la page Créatures ; hors boss du monde et lignes de
-- niveau 9999 jamais capturées, comme les sceaux). Gardé tant que les
-- captures et la faction n'ont pas bougé.
local azeroth
function ns:MenagerieAzeroth()
	local catalog = self.MenagerieCatalog and self:MenagerieCatalog()
	if type(catalog) ~= "table" or type(catalog.list) ~= "table" then return 0, 0 end
	local capture = self.CaptureData and self:CaptureData() or { creatures = {} }
	local key = tostring(catalog.faction) .. ":" .. tostring(catalog.count) .. ":" .. tostring(capture.serial) .. ":" .. tostring(capture.count)
	if azeroth and azeroth.key == key and azeroth.catalog == catalog then return azeroth.have, azeroth.need end
	local have, need = 0, 0
	local creatures = capture.creatures or {}
	for _, item in ipairs(catalog.list) do
		local caught = type(creatures[item.npc]) == "table"
		local unreachable = (tonumber(item.lo) or 0) >= 9999 and not caught
		if item.class ~= "worldboss" and not unreachable then
			need = need + 1
			if caught then have = have + 1 end
		end
	end
	azeroth = { key = key, catalog = catalog, have = have, need = need }
	return have, need
end

-- Un palier est-il atteint ? (« tout Azeroth » : toutes les espèces de la faction)
function ns:TrainerRankReached(rank, count)
	if type(rank) ~= "table" then return false end
	if rank.all then
		local have, need = self:MenagerieAzeroth()
		return need > 0 and have >= need
	end
	return (count or self:MenagerieSpeciesCount()) >= rank.count
end

-- Palier atteint (définition, rang) et le suivant
function ns:TrainerRank(count)
	count = count or self:MenagerieSpeciesCount()
	local current, index, nextRank
	for i, rank in ipairs(ns.TRAINER_RANKS) do
		if self:TrainerRankReached(rank, count) then current, index = rank, i elseif not nextRank then nextRank = rank end
	end
	return current, index or 0, nextRank
end

function ns:TrainerTitleKey()
	local rank = self:TrainerRank()
	return rank and rank.key or nil
end

function ns:TrainerTitle()
	local key = self:TrainerTitleKey()
	return key and L["TRAINER_" .. key] or nil
end

-- Ce que rapporte un palier, en texte (« Appât savoureux, Lasso tressé »)
function ns:TrainerRankGift(rank)
	local parts = {}
	for _, id in ipairs(rank.aids or {}) do parts[#parts + 1] = self.CaptureAidLabel and self:CaptureAidLabel(id) or id end
	if rank.cosmetic then
		local def = CosmeticDef(rank.cosmetic.kind, rank.cosmetic.id)
		if def then parts[#parts + 1] = L[def.label] end
	end
	-- 3.6.0 : les paliers au-delà de 250 donnent ce que donne leur haut fait
	if #parts == 0 and self.FeatDef and self.FeatRewardText then
		local def = self:FeatDef(rank.feat or ("men_species_" .. tostring(rank.count)))
		if def then return self:FeatRewardText(def) end
	end
	return table.concat(parts, ", ")
end

-- Paliers franchis et pas encore récompensés : aides et cosmétique, une fois
function ns:MenagerieRankCheck(opts)
	opts = opts or {}
	if not ModuleOn() then return {} end
	local coll = self:MenagerieCollectionData()
	local ranks, count, gained = coll.ranks, self:MenagerieSpeciesCount(), {}
	for _, rank in ipairs(ns.TRAINER_RANKS) do
		-- (3.6.0 : « tout Azeroth » noté sous sa clé, son seuil bouge avec la table)
		local id = rank.all and rank.key or rank.count
		if not ranks[id] and self:TrainerRankReached(rank, count) then
			ranks[id] = Now()
			-- 2.7 : aides, cosmétique et bandeau passent par le haut fait
			-- men_species_<n> (FeatsCatMenagerie.lua) ; le palier reste noté
			-- (date, annonce de guilde), marqué « payé par le haut fait »
			local byFeat = self.FeatLegacyHandled and self:FeatLegacyHandled(rank.feat or ("men_species_" .. rank.count))
			if byFeat then
				coll.featRanks = type(coll.featRanks) == "table" and coll.featRanks or {}
				coll.featRanks[id] = true
			else
				for _, id in ipairs(rank.aids or {}) do
					if self.CaptureGrant then pcall(self.CaptureGrant, self, id, { quiet = true, silent = true }) end
				end
				if rank.cosmetic then Unlock(self, rank.cosmetic.kind, rank.cosmetic.id) end
			end
			gained[#gained + 1] = rank
			if not opts.quiet and not byFeat then
				local title = L["TRAINER_" .. rank.key]
				self:Print(self:F("MEN_RANK_MSG", rank.count, title, self:F("MEN_RANK_GIFT", self:TrainerRankGift(rank))))
				if self.CompanionSay then self:CompanionSay("UNLOCK", { force = true, args = { title } }) end
			end
		end
	end
	if #gained > 0 then Refreshed(self) end
	return gained
end

-- ---------------------------------------------------------------------------
-- Quand vérifier : après chaque capture, au changement de zone, et une fois
-- pour les captures d'avant la 2.0 (rattrapage silencieux, un seul message)
-- ---------------------------------------------------------------------------
-- target : { npcID, zoneID } (cible de ns:CaptureResolve), facultatif
function ns:MenagerieCollectionCheck(target, opts)
	if not ModuleOn() then return nil end
	local zones = {}
	if type(target) == "table" and target.zoneID then zones[tonumber(target.zoneID) or target.zoneID] = true end
	local here = self.JournalZone and self:JournalZone()
	if here then zones[here] = true end
	for zoneID in pairs(zones) do self:MenagerieSealCheck(zoneID, opts) end
	self:MenagerieTypeCheck(opts)
	self:MenagerieMedalCheck(opts)
	self:MenagerieRankCheck(opts)
	return true
end

-- Rattrapage : les tables de zone lues sans être gardées (ns.ZonePeek), le
-- rattrapage passe sur toutes les zones où l'on a capturé une fois
local peeking = false
do
	local static = ns.BestiaryStaticZone
	if static then
		function ns:BestiaryStaticZone(zoneID, ...)
			if peeking and ns.ZonePeek then
				local zone = zoneID and ns.ZonePeek(rawget(ns, "ZONE_CREATURES"), zoneID)
				return type(zone) == "table" and zone or nil
			end
			return static(self, zoneID, ...)
		end
	end
end

-- 3.7.0 : fn(self) avec les tables de zone lues sans être gardées (le
-- rattrapage des médailles de zone, ZoneMedals.lua) ; rend ce que fn rend
function ns:MenagerieWithPeek(fn)
	local was = peeking
	peeking = true
	local ok, a, b = pcall(fn, self)
	peeking = was
	if not ok then error(a, 0) end
	return a, b
end

function ns:MenagerieCollectionCatchUp()
	if not ModuleOn() then return nil end
	local coll = self:MenagerieCollectionData()
	if coll.init then return nil end
	coll.init = true
	local zones = {}
	for _, entry in pairs(self.CaptureData and self:CaptureData().creatures or {}) do
		local zoneID = type(entry) == "table" and tonumber(entry.zoneID)
		if zoneID then zones[zoneID] = true end
	end
	local sealed = 0
	peeking = true
	local ok, err = pcall(function()
		for zoneID in pairs(zones) do
			if self:MenagerieSealCheck(zoneID, { quiet = true }) then sealed = sealed + 1 end
		end
	end)
	peeking = false
	if not ok then error(err, 0) end
	local types = self:MenagerieTypeCheck({ quiet = true })
	self:MenagerieMedalCheck({ quiet = true })
	local ranks = self:MenagerieRankCheck({ quiet = true })
	if sealed > 0 or #ranks > 0 then
		local title = self:TrainerTitle()
		self:Print(title and self:F("MEN_CATCHUP", sealed, title) or self:F("MEN_CATCHUP_NOTITLE", sealed))
	end
	return sealed, #types, #ranks
end

-- (3.1.0 : fonction faite une fois, plus de fermeture à chaque rafraîchissement du suivi)
local function SealCheck(self)
	if not self:MenagerieCollectionData().init then
		self:MenagerieCollectionCatchUp()
	else
		local zoneID = self.JournalZone and self:JournalZone()
		local capture = self.CaptureData and self:CaptureData()
		local serial = capture and capture.serial
		local last = self.menagerieSealSeen
		if zoneID and not (last and last.zone == zoneID and last.serial == serial and last.count == (capture and capture.count)) then
			self.menagerieSealSeen = { zone = zoneID, serial = serial, count = capture and capture.count }
			self:MenagerieSealCheck(zoneID)
		end
	end
end
do
	local resolve = ns.CaptureResolve
	if resolve then
		function ns:CaptureResolve(rolling, ...)
			local success = resolve(self, rolling, ...)
			if success and type(rolling) == "table" then
				local ok, err = pcall(self.MenagerieCollectionCheck, self, rolling.target)
				if not ok and self.RecordError then self:RecordError("menagerie:collection", err) end
			end
			return success
		end
	end
	-- Le suivi se rafraîchit à chaque monstre abattu : le sceau de la zone ne
	-- se revérifie qu'au changement de zone ou de captures (capture.serial)
	local refresh = ns.RefreshJournalTracker
	if refresh then
		function ns:RefreshJournalTracker(...)
			local a, b = refresh(self, ...)
			if ModuleOn() then
				local ok, err = pcall(SealCheck, self)
				if not ok and self.RecordError then self:RecordError("menagerie:catchup", err) end
			end
			return a, b
		end
	end
end

-- ---------------------------------------------------------------------------
-- Affichage
-- ---------------------------------------------------------------------------
-- Ligne de la page Exploration (JournalCompletion.lua) : le sceau de la zone,
-- ou nil (zone sans liste d'espèces : la ligne du bestiaire reste)
function ns:MenagerieSealLine(zoneID)
	if self:MenagerieSealed(zoneID) then return self:F("JRN_PROG_SEALED", Dec(ns.SEAL_SHINY_MULT)), true end
	local have, need = self:MenagerieSealProgress(zoneID)
	if need == 0 then return nil end
	return self:F("JRN_PROG_SEAL", have, need), false
end

-- Lignes du survol : paliers par type, puis titres
function ns:MenagerieCollectionTip()
	local lines, counts = { L.MEN_COLL_TIP_TYPES }, self:MenagerieTypeCounts()
	for _, key in ipairs(ns.CREATURE_TYPES or {}) do
		local tier, count, nextNeed = self:MenagerieTypeTier(key, counts)
		local tiers = #self:MenagerieTypeTiers(key)
		local force = self:F("MEN_COLL_FORCE", Dec(tier * ns.MENAGERIE_TYPE_STEP))
		if nextNeed then
			lines[#lines + 1] = "  " .. self:F("MEN_COLL_TIP_TYPE_NEXT", self:CreatureTypeLabel(key), count, tier, tiers, force, nextNeed)
		else
			lines[#lines + 1] = "  " .. self:F("MEN_COLL_TIP_TYPE", self:CreatureTypeLabel(key), count, tier, tiers, force)
		end
	end
	lines[#lines + 1] = L.MEN_COLL_TIP_RANKS
	local species = self:MenagerieSpeciesCount()
	for _, rank in ipairs(ns.TRAINER_RANKS) do
		local text = self:F("MEN_COLL_TIP_RANK", rank.count, L["TRAINER_" .. rank.key], self:TrainerRankGift(rank))
		lines[#lines + 1] = "  " .. (self:TrainerRankReached(rank, species) and (Theme.T_GOLD .. text .. "|r") or text)
	end
	return lines
end

-- Bandeau sous la liste de la Ménagerie (JournalWindow.lua). 3.7.0 (maquette
-- 3.7, « Créatures : médailles de zone ») : quatre losanges (bronze, argent,
-- or, sceau : ZoneMedals.lua), « <Zone> : n sur total espèces », à droite ce
-- qui manque pour la suivante ; la barre et ses trois repères, les seuils
-- dessous ; en bas à droite, le titre de dresseur à viser. La ligne du bas à
-- gauche reste libre (pullulation du jour, chantier suivant). Survol : ce que
-- donne le sceau, les médailles, les paliers par type et les titres.
ns.MENAGERIE_COLLECTION_H = 70
-- cotes (px) : marge, haut de la première ligne et sa hauteur, losanges
-- (taille, centre du premier, pas), début du titre, barre, repères (débord),
-- seuils, ligne du bas, écart entre le titre et le texte de droite
ns.MENAGERIE_STRIP = { pad = 12, top = 8, line = 14, dia = 18, diaX = 19, diaStep = 23, titleX = 108,
	barY = 31, barH = 4, tick = 2, marksY = 37, bottomY = 52, gap = 8 }

local function Measure(fs)
	local ok, w = pcall(fs.GetStringWidth, fs)
	return ok and tonumber(w) or 0
end
local function NoWrap(fs)
	if fs.SetWordWrap then fs:SetWordWrap(false) end
	return fs
end

function ns:MenagerieCollectionBuild(pane, content, box)
	local ui = ns.JournalUI
	if not (ui and box) then return nil end
	local K = ns.MENAGERIE_STRIP
	local strip = Theme.CreateTile(pane, box.w, box.h, { kind = "Frame" })
	ui.At(strip, content, box.x, box.y)
	strip:SetFill(Theme.FIELD or Theme.ROW)
	strip.w = box.w
	if strip.EnableMouse then strip:EnableMouse(true) end
	-- quatre losanges : bronze, argent, or, sceau
	strip.medals = {}
	for index = 1, 4 do
		local dia = Theme.CreateDiamond(strip, K.dia)
		dia:SetPoint("CENTER", strip, "TOPLEFT", K.diaX + (index - 1) * K.diaStep, -(K.top + K.line / 2))
		strip.medals[index] = dia
	end
	strip.seal = strip.medals[4]
	strip.title = NoWrap(ui.Text(strip, Theme.F_LABEL, Theme.LABEL, box.w - K.titleX - K.pad))
	strip.title:SetPoint("TOPLEFT", strip, "TOPLEFT", K.titleX, -K.top)
	strip.next = NoWrap(ui.Text(strip, Theme.F_SMALL, Theme.MUTED_LIGHT))
	strip.next:SetJustifyH("RIGHT")
	strip.next:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -K.pad, -(K.top + 1))
	-- la barre, ses trois repères (25, 50, 75 %), les seuils dessous
	local barW = box.w - 2 * K.pad
	strip.bar = Theme.CreateBar(strip, barW, K.barH)
	strip.bar:SetPoint("TOPLEFT", strip, "TOPLEFT", K.pad, -K.barY)
	strip.ticks, strip.marks = {}, {}
	for index = 1, 3 do
		local x = math.floor(barW * index / 4 + 0.5)
		local tick = Theme.Solid(strip.bar, "OVERLAY", Theme.MUTED_LIGHT, 1)
		tick:SetSize(1, K.barH + 2 * K.tick)
		tick:SetPoint("TOPLEFT", strip.bar, "TOPLEFT", x, K.tick)
		strip.ticks[index] = tick
		local mark = NoWrap(ui.Text(strip, Theme.F_SMALL, Theme.MUTED, index == 3 and (barW - x) or math.floor(barW / 4)))
		mark:SetPoint("TOPLEFT", strip, "TOPLEFT", K.pad + x, -K.marksY)
		strip.marks[index] = mark
	end
	-- à la place de la barre : toutes zones (les médailles gagnées), zone sans liste
	strip.note = NoWrap(ui.Text(strip, Theme.F_SMALL, Theme.MUTED_LIGHT, barW))
	strip.note:SetPoint("TOPLEFT", strip, "TOPLEFT", K.pad, -(K.barY - 4))
	-- 3.7.0 : en bas à gauche, la pullulation du jour de la zone (WorldDaily.lua)
	strip.swarm = NoWrap(ui.Text(strip, Theme.F_SMALL, Theme.GOLD, math.floor(barW / 2)))
	strip.swarm:SetPoint("TOPLEFT", strip, "TOPLEFT", K.pad, -K.bottomY)
	strip.trainer = NoWrap(ui.Text(strip, Theme.F_SMALL, Theme.GOLD, math.floor(barW / 2)))
	strip.trainer:SetJustifyH("RIGHT")
	strip.trainer:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -K.pad, -K.bottomY)
	strip.onEnter = function(s)
		local lines = ns:MenagerieCollectionTip()
		if s.sealTip then
			table.insert(lines, 1, s.sealTip)
			if ns.ZoneMedalTipLine then table.insert(lines, 2, ns:ZoneMedalTipLine()) end
		end
		ui.Tip(s, s.tipTitle or "", lines, "row")
	end
	strip.onLeave = ui.HideTip
	pane.collection = strip
	return strip
end

-- zone : uiMapID ou "all"
function ns:MenagerieCollectionRefresh(pane, zone)
	local strip = pane and pane.collection
	if not strip then return end
	local K = ns.MENAGERIE_STRIP
	local zoneID = tonumber(zone)
	-- (molette : rien n'a changé depuis le dernier contrôle du sceau)
	local scrolling = self.journalFrame and self.journalFrame.scrollOnly
	if zoneID and not scrolling then
		self:MenagerieSealCheck(zoneID)
		if self.ZoneMedalCheck then self:ZoneMedalCheck(zoneID) end
	end
	local sealed = zoneID and self:MenagerieSealed(zoneID)
	local lit, need, thresholds, note = {}, 0, nil, nil
	strip.sealTip = nil
	strip.next:SetText("")
	if not zoneID then
		-- toutes zones : le compte des sceaux, et des médailles
		local counts = self.ZoneMedalCounts and self:ZoneMedalCounts() or {}
		local seals = #self:MenagerieSeals()
		strip.title:SetText(self:F("MEN_COLL_SEALS", seals))
		strip.next:SetText(L.MEN_COLL_SEALS_TIP)
		if L.ZONE_MEDAL_ALL then note = self:F("ZONE_MEDAL_ALL", counts[1] or 0, counts[2] or 0, counts[3] or 0) end
		lit = { (counts[1] or 0) > 0, (counts[2] or 0) > 0, (counts[3] or 0) > 0, seals > 0 }
		strip:SetAccent(nil)
	else
		local name = ZoneName(self, zoneID)
		local level, have, nextNeed = 0, 0, nil
		if self.ZoneMedal then
			level, have, need, nextNeed = self:ZoneMedal(zoneID)
		else
			have, need = self:MenagerieSealProgress(zoneID)
		end
		if sealed then
			strip.title:SetText(self:F("MEN_COLL_SEALED", name))
			strip.next:SetText(self:F("MEN_COLL_SEAL_DONE", Dec(ns.SEAL_SHINY_MULT)))
		elseif need == 0 then
			strip.title:SetText(name)
			note = L.MEN_COLL_SEAL_NA
		else
			strip.title:SetText(self:F("ZONE_MEDAL_TITLE", name, have, need))
			strip.next:SetText(self:F("ZONE_MEDAL_LEFT_" .. math.min(4, level + 1), math.max(0, (nextNeed or need) - have)))
			local biome = self:MenagerieZoneBiome(zoneID)
			local reward = L["COMP_FRAME_SEAL_" .. biome]
			if self:MenagerieBiomeSeals(biome) >= 1 then reward = L["COMP_BG_SEAL_" .. biome] end
			strip.sealTip = self:F("MEN_COLL_SEAL_TODO", reward, Dec(ns.SEAL_SHINY_MULT))
		end
		if need > 0 then
			strip.bar:SetValue(sealed and 1 or have / need)
			thresholds = self.ZoneMedalThresholds and { self:ZoneMedalThresholds(need) } or nil
		end
		lit = { level >= 1, level >= 2, level >= 3, sealed and true or false }
		strip:SetAccent(sealed and Theme.GOLD or nil)
	end
	-- la barre et ses seuils, ou la note à sa place
	local withBar = need > 0 and thresholds ~= nil
	if withBar then
		local c = Theme.GOLD
		strip.bar:SetColor(c[1], c[2], c[3], 1)
		strip.bar:Show()
		strip.marks[1]:SetText(self:F("ZONE_MEDAL_MARK", L.ZONE_MEDAL_1, thresholds[1]))
		strip.marks[2]:SetText(self:F("ZONE_MEDAL_MARK", L.ZONE_MEDAL_2, thresholds[2]))
		strip.marks[3]:SetText(self:F("ZONE_MEDAL_MARK", L.ZONE_MEDAL_3, thresholds[3]) .. " · "
			.. self:F("ZONE_MEDAL_MARK", L.ZONE_MEDAL_SEAL, need))
	else
		strip.bar:Hide()
	end
	for index = 1, 3 do
		if withBar then strip.ticks[index]:Show(); strip.marks[index]:Show()
		else strip.ticks[index]:Hide(); strip.marks[index]:Hide() end
	end
	strip.note:SetText(note or "")
	if note then strip.note:Show() else strip.note:Hide() end
	-- les losanges : allumés une fois gagnés, au métal de leur médaille
	local tints = ns.ZONE_MEDAL_TINTS or {}
	for index, dia in ipairs(strip.medals) do
		local key = tints.off
		if lit[index] then key = index == 4 and tints.seal or tints[index] end
		local c = Theme[key or "EDGE"] or Theme.EDGE
		Theme.SetDiamond(dia, false)
		dia:SetVertexColor(c[1], c[2], c[3], 1)
		dia.lit = lit[index] and true or false
	end
	-- le titre s'arrête avant le texte de droite
	local room = (strip.w or 484) - K.titleX - K.pad - K.gap - Measure(strip.next)
	strip.title:SetWidth(math.max(40, math.floor(room)))
	-- en bas à droite : le titre de dresseur à viser
	local species = self:MenagerieSpeciesCount()
	local rank, _, nextRank = self:TrainerRank(species)
	if nextRank then
		-- (3.6.0 : « tout Azeroth » : les espèces de la faction)
		local have, goal = species, nextRank.count
		if nextRank.all then have, goal = self:MenagerieAzeroth() end
		strip.trainer:SetText(self:F("MEN_COLL_NEXT_SHORT", have, goal, L["TRAINER_" .. nextRank.key]))
	elseif rank then
		strip.trainer:SetText(self:F("MEN_COLL_TITLE", L["TRAINER_" .. rank.key], species))
	end
	strip.tipTitle = rank and L["TRAINER_" .. rank.key] or L.JRN_SEC_menagerie
	strip.swarm:SetText(zoneID and self.WorldSwarmStripText and self:WorldSwarmStripText(zoneID) or "")
	strip:Show()
end

if ns.Mark then ns.Mark("MenagerieCollection") end
