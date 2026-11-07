-- MenagerieCollection.lua -- Lot 3 : sceaux de zone, complétion par type, paliers et titres de dresseur (QuestCompanion 2.0)
--
-- La Ménagerie devient une collection à finir, à part de l'Exploration (dont
-- le pourcentage ne compte plus que lieux, récolte et quêtes) :
--   * Sceau de zone : toutes les espèces d'une zone capturées (version
--     normale ; les boss du monde ne comptent pas) -> la zone est scellée pour
--     toujours. Dans une zone scellée, les brillantes sont plus fréquentes
--     (×SEAL_SHINY_MULT, enveloppe de ns:ShinyChance). Chaque biome a son
--     cadre (premier sceau du biome) et son paysage peint en fond (deuxième
--     sceau : Textures/scene_<biome>.tga, tools/gen_seal_scenes.py).
--   * Complétion par type : des paliers d'espèces capturées par type de
--     créature renforcent l'effet du compagnon de ce type
--     (ns:MenagerieTypeBonus, lu par CompanionEffects.lua).
--   * Paliers globaux : 10, 25, 50, 100, 250 espèces -> une récompense et un
--     titre de dresseur (ns:TrainerTitle).
-- Données (par personnage, avec le compagnon) : CompanionData().collection =
--   { seals = { [zoneID] = date }, types = { [clé] = palier annoncé },
--     ranks = { [nombre] = date }, init = true }
-- Rien ne se perd : un sceau, un palier ou un titre gagné le reste.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.SEAL_SHINY_MULT = 1.5
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
}

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
-- paysages peints, un par biome (512 x 256, tools/gen_seal_scenes.py)
local SCENE_TEXTURE = "Interface\\AddOns\\" .. tostring(ADDON or "QuestCompanion") .. "\\Textures\\scene_"
ns.MENAGERIE_SCENE_TEXTURE = SCENE_TEXTURE
-- liseré du cadre de chaque biome : { filet, filet intérieur }, tirés des
-- teintes des décors peints (sol, ciel)
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
	BIOME_forest = "forêt", BIOME_nightforest = "forêt de nuit", BIOME_canyon = "canyon", BIOME_savanna = "savane",
	BIOME_snow = "neige", BIOME_swamp = "marais", BIOME_desert = "désert", BIOME_blight = "terres maudites",
	BIOME_jungle = "jungle", BIOME_volcanic = "volcan",
	COMP_FRAME_SEAL        = "Sceau : %s",
	COMP_BG_SEAL           = "Paysage : %s",
	COMP_FRAME_TRAINER     = "Insigne du dresseur",
	COMP_FRAME_MASTER      = "Insigne du maître",
	COMP_BG_MENAGERIE      = "Enclos de la ménagerie",
	COMP_BG_GRANDMASTER    = "Grand enclos",
	COMP_REQ_seal          = "sceau d'une zone (%s)",
	COMP_REQ_seal2         = "sceau de deux zones (%s)",
	COMP_REQ_trainer       = "%d espèces capturées",
	MEN_SEAL_MSG           = "Sceau de %s ! Toutes ses espèces sont dans ta ménagerie : brillantes ×%s ici.",
	MEN_SEAL_NEW           = "Nouveau : %s.",
	MEN_TYPE_MSG           = "%s : %d espèces capturées, palier %d ! Un compagnon de ce type gagne en force (%s).",
	MEN_RANK_MSG           = "%d espèces capturées : te voilà %s ! %s",
	MEN_RANK_GIFT          = "Gain : %s.",
	MEN_CATCHUP            = "Ménagerie : %d sceaux, titre « %s ».",
	MEN_CATCHUP_NOTITLE    = "Ménagerie : %d sceaux.",
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
	JRN_PROG_SEAL          = "Sceau de la zone : %d/%d espèces capturées · détail dans la Ménagerie",
	JRN_PROG_SEALED        = "Zone scellée : brillantes ×%s ici",
	MEN_DECIMAL_SEP        = ",",
}
local EN = {
	TRAINER_apprentice     = "Apprentice Trainer",
	TRAINER_trainer        = "Trainer",
	TRAINER_seasoned       = "Seasoned Trainer",
	TRAINER_master         = "Master Trainer",
	TRAINER_grandmaster    = "Grand Master Trainer",
	BIOME_forest = "forest", BIOME_nightforest = "night forest", BIOME_canyon = "canyon", BIOME_savanna = "savanna",
	BIOME_snow = "snow", BIOME_swamp = "swamp", BIOME_desert = "desert", BIOME_blight = "blighted lands",
	BIOME_jungle = "jungle", BIOME_volcanic = "volcano",
	COMP_FRAME_SEAL        = "Seal: %s",
	COMP_BG_SEAL           = "Landscape: %s",
	COMP_FRAME_TRAINER     = "Trainer's badge",
	COMP_FRAME_MASTER      = "Master's badge",
	COMP_BG_MENAGERIE      = "Menagerie pen",
	COMP_BG_GRANDMASTER    = "Grand pen",
	COMP_REQ_seal          = "seal of one zone (%s)",
	COMP_REQ_seal2         = "seal of two zones (%s)",
	COMP_REQ_trainer       = "%d species captured",
	MEN_SEAL_MSG           = "%s sealed! Every species there is in your menagerie: shinies ×%s here.",
	MEN_SEAL_NEW           = "New: %s.",
	MEN_TYPE_MSG           = "%s: %d species captured, tier %d! A companion of this type grows stronger (%s).",
	MEN_RANK_MSG           = "%d species captured: you are now a %s! %s",
	MEN_RANK_GIFT          = "Reward: %s.",
	MEN_CATCHUP            = "Menagerie: %d seals, title “%s”.",
	MEN_CATCHUP_NOTITLE    = "Menagerie: %d seals.",
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
	JRN_PROG_SEAL          = "Zone seal: %d/%d species captured · details in the Menagerie",
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
		texture = SCENE_TEXTURE .. biome,
		color = { 1, 1, 1, 1 }, coords = { 0.2, 0.8, 0.05, 0.95 } } }
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
		if species.class ~= "worldboss" then
			need = need + 1
			if self.CaptureHas and self:CaptureHas(npcID, false) then have = have + 1 end
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
	local fresh = SealRewards(self, self:MenagerieZoneBiome(zoneID))
	if not opts.quiet then
		local name = ZoneName(self, zoneID)
		self:Print(self:F("MEN_SEAL_MSG", name, Dec(ns.SEAL_SHINY_MULT)))
		for _, label in ipairs(fresh) do self:Print(self:F("MEN_SEAL_NEW", label)) end
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

-- Palier atteint (définition, rang) et le suivant
function ns:TrainerRank(count)
	count = count or self:MenagerieSpeciesCount()
	local current, index, nextRank
	for i, rank in ipairs(ns.TRAINER_RANKS) do
		if count >= rank.count then current, index = rank, i elseif not nextRank then nextRank = rank end
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
	return table.concat(parts, ", ")
end

-- Paliers franchis et pas encore récompensés : aides et cosmétique, une fois
function ns:MenagerieRankCheck(opts)
	opts = opts or {}
	if not ModuleOn() then return {} end
	local ranks, count, gained = self:MenagerieCollectionData().ranks, self:MenagerieSpeciesCount(), {}
	for _, rank in ipairs(ns.TRAINER_RANKS) do
		if count >= rank.count and not ranks[rank.count] then
			ranks[rank.count] = Now()
			for _, id in ipairs(rank.aids or {}) do
				if self.CaptureGrant then pcall(self.CaptureGrant, self, id, { quiet = true, silent = true }) end
			end
			if rank.cosmetic then Unlock(self, rank.cosmetic.kind, rank.cosmetic.id) end
			gained[#gained + 1] = rank
			if not opts.quiet then
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
	local ranks = self:MenagerieRankCheck({ quiet = true })
	if sealed > 0 or #ranks > 0 then
		local title = self:TrainerTitle()
		self:Print(title and self:F("MEN_CATCHUP", sealed, title) or self:F("MEN_CATCHUP_NOTITLE", sealed))
	end
	return sealed, #types, #ranks
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
				local ok, err = pcall(function()
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
				end)
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
		lines[#lines + 1] = "  " .. ((species >= rank.count) and (Theme.T_GOLD .. text .. "|r") or text)
	end
	return lines
end

-- Bandeau sous la liste de la Ménagerie (JournalWindow.lua) : sceau de la
-- zone choisie et sa progression, titre de dresseur et prochain palier ;
-- survol : paliers par type et titres
ns.MENAGERIE_COLLECTION_H = 70

function ns:MenagerieCollectionBuild(pane, content, box)
	local ui = ns.JournalUI
	if not (ui and box) then return nil end
	local strip = Theme.CreateTile(pane, box.w, box.h, { kind = "Frame" })
	ui.At(strip, content, box.x, box.y)
	strip:SetFill(Theme.FIELD or Theme.ROW)
	if strip.EnableMouse then strip:EnableMouse(true) end
	strip.seal = Theme.CreateDiamond(strip, 12)
	strip.seal:SetPoint("TOPLEFT", strip, "TOPLEFT", 12, -10)
	strip.title = ui.Text(strip, Theme.F_LABEL, Theme.LABEL, box.w - 36 - 110)
	strip.title:SetPoint("TOPLEFT", strip, "TOPLEFT", 32, -8)
	if strip.title.SetWordWrap then strip.title:SetWordWrap(false) end
	strip.bar = Theme.CreateBar(strip, 96, 4)
	strip.bar:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -12, -14)
	strip.detail = ui.Text(strip, Theme.F_SMALL, Theme.MUTED_LIGHT, box.w - 44)
	strip.detail:SetPoint("TOPLEFT", strip, "TOPLEFT", 32, -28)
	if strip.detail.SetWordWrap then strip.detail:SetWordWrap(false) end
	strip.trainer = ui.Text(strip, Theme.F_SMALL, Theme.GOLD, box.w - 44)
	strip.trainer:SetPoint("TOPLEFT", strip, "TOPLEFT", 32, -46)
	if strip.trainer.SetWordWrap then strip.trainer:SetWordWrap(false) end
	strip.onEnter = function(s) ui.Tip(s, s.tipTitle or "", ns:MenagerieCollectionTip()) end
	strip.onLeave = ui.HideTip
	pane.collection = strip
	return strip
end

-- zone : uiMapID ou "all"
function ns:MenagerieCollectionRefresh(pane, zone)
	local strip = pane and pane.collection
	if not strip then return end
	local zoneID = tonumber(zone)
	if zoneID then self:MenagerieSealCheck(zoneID) end
	local edge = BIOME_EDGE[zoneID and self:MenagerieZoneBiome(zoneID) or "forest"][1]
	local sealed = zoneID and self:MenagerieSealed(zoneID)
	if not zoneID then
		strip.title:SetText(self:F("MEN_COLL_SEALS", #self:MenagerieSeals()))
		strip.detail:SetText(L.MEN_COLL_SEALS_TIP)
		strip.bar:Hide()
		strip.seal:SetTexture(Theme.DIAMOND_LINE)
		strip.seal:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		strip:SetAccent(nil)
	else
		local name = ZoneName(self, zoneID)
		local have, need = self:MenagerieSealProgress(zoneID)
		local biome = self:MenagerieZoneBiome(zoneID)
		if sealed then
			strip.title:SetText(self:F("MEN_COLL_SEALED", name))
			strip.detail:SetText(self:F("MEN_COLL_SEAL_DONE", Dec(ns.SEAL_SHINY_MULT)))
		elseif need == 0 then
			strip.title:SetText(name)
			strip.detail:SetText(L.MEN_COLL_SEAL_NA)
		else
			strip.title:SetText(self:F("MEN_COLL_SEAL", name, have, need))
			local reward = L["COMP_FRAME_SEAL_" .. biome]
			if self:MenagerieBiomeSeals(biome) >= 1 then reward = L["COMP_BG_SEAL_" .. biome] end
			strip.detail:SetText(self:F("MEN_COLL_SEAL_TODO", reward, Dec(ns.SEAL_SHINY_MULT)))
		end
		if need > 0 then
			strip.bar:SetValue(sealed and 1 or have / need)
			local c = sealed and Theme.GOLD or edge
			strip.bar:SetColor(c[1], c[2], c[3], 1)
			strip.bar:Show()
		else
			strip.bar:Hide()
		end
		strip.seal:SetTexture(sealed and Theme.DIAMOND or Theme.DIAMOND_LINE)
		local c = sealed and Theme.GOLD or edge
		strip.seal:SetVertexColor(c[1], c[2], c[3], 1)
		strip:SetAccent(sealed and Theme.GOLD or nil)
	end
	local species = self:MenagerieSpeciesCount()
	local rank, _, nextRank = self:TrainerRank(species)
	if rank and nextRank then
		strip.trainer:SetText(self:F("MEN_COLL_TITLE_NEXT", L["TRAINER_" .. rank.key], species, nextRank.count - species,
			L["TRAINER_" .. nextRank.key]))
	elseif rank then
		strip.trainer:SetText(self:F("MEN_COLL_TITLE", L["TRAINER_" .. rank.key], species))
	else
		local first = ns.TRAINER_RANKS[1]
		strip.trainer:SetText(self:F("MEN_COLL_NOTITLE", species, first.count, L["TRAINER_" .. first.key]))
	end
	strip.tipTitle = rank and L["TRAINER_" .. rank.key] or L.JRN_SEC_menagerie
	strip:Show()
end

if ns.Mark then ns.Mark("MenagerieCollection") end
