-- GatheringData.lua -- ressources de récolte classiques, par métier (v1.25.0)
--
-- Table posée à la main, lue par Gathering.lua. Clé = itemID de Classic
-- (identiques sur Era 1.15 et Forever 1.60 : même base d'objets).
--   prof : "herbalism" | "mining" | "skinning"
--   req  : compétence requise pour récolter (nœud / gisement) ;
--   gray : compétence à laquelle la ressource devient grise (plus de points).
-- Herbes et gisements : orange jusqu'à req + 25, jaune jusqu'à req + 50,
-- vert jusqu'à req + 100, gris ensuite -> gray = req + 100 partout.
-- Dépeçage : la compétence dépend du NIVEAU de la bête (niveau × 5 au-delà
-- du niveau 20), pas du cuir ; req = niveau de compétence des bêtes qui
-- donnent surtout ce cuir, gray = req + 100 (approximation assumée).
-- fr / en : noms de repli quand le client n'a pas encore l'objet en cache
-- (le nom affiché vient de GetItemInfo dès qu'il le connaît).
-- Pas de zones ici : aucune donnée fiable, on retient en jouant (Gathering.lua).
local ns = rawget(_G, "Ready2Quest")
if type(ns) ~= "table" or not ns.QC then return end

local function R(prof, req, fr, en, gray)
	return { prof = prof, req = req, gray = gray or (req + 100), fr = fr, en = en }
end

ns.GATHERING_ITEMS = {
	-- -----------------------------------------------------------------------
	-- Herboristerie
	-- -----------------------------------------------------------------------
	[2447]  = R("herbalism", 1,   "Pacifique",                  "Peacebloom"),
	[765]   = R("herbalism", 1,   "Feuillargent",               "Silverleaf"),
	[2449]  = R("herbalism", 15,  "Terrestrine",                "Earthroot"),
	[785]   = R("herbalism", 50,  "Mage royal",                 "Mageroyal"),
	[2450]  = R("herbalism", 70,  "Églantine",                  "Briarthorn"),
	[3820]  = R("herbalism", 85,  "Algue étrangleuse",          "Stranglekelp"),
	[2453]  = R("herbalism", 100, "Doulourante",                "Bruiseweed"),
	[3355]  = R("herbalism", 115, "Aciérite sauvage",           "Wild Steelbloom"),
	[3369]  = R("herbalism", 120, "Tombeline",                  "Grave Moss"),
	[3356]  = R("herbalism", 125, "Sang-royal",                 "Kingsblood"),
	[3357]  = R("herbalism", 150, "Vietérule",                  "Liferoot"),
	[3818]  = R("herbalism", 160, "Pâlerette",                  "Fadeleaf"),
	[3821]  = R("herbalism", 170, "Dorépine",                   "Goldthorn"),
	[3358]  = R("herbalism", 185, "Moustache de Khadgar",       "Khadgar's Whisker"),
	[3819]  = R("herbalism", 195, "Hivernale",                  "Wintersbite"),
	[4625]  = R("herbalism", 205, "Fleur de feu",               "Firebloom"),
	[8831]  = R("herbalism", 210, "Lotus pourpre",              "Purple Lotus"),
	[8836]  = R("herbalism", 220, "Larmes d'Arthas",            "Arthas' Tears"),
	[8838]  = R("herbalism", 230, "Soleillette",                "Sungrass"),
	[8839]  = R("herbalism", 235, "Aveuglette",                 "Blindweed"),
	[8845]  = R("herbalism", 245, "Champignon fantôme",         "Ghost Mushroom"),
	[8846]  = R("herbalism", 250, "Gromsang",                   "Gromsblood"),
	[13464] = R("herbalism", 260, "Sansam doré",                "Golden Sansam"),
	[13463] = R("herbalism", 270, "Feuillerêve",                "Dreamfoil"),
	[13465] = R("herbalism", 280, "Sauge-argent des montagnes", "Mountain Silversage"),
	[13466] = R("herbalism", 285, "Fleur de peste",             "Plaguebloom"),
	[13467] = R("herbalism", 290, "Calot de glace",             "Icecap"),
	[13468] = R("herbalism", 300, "Lotus noir",                 "Black Lotus"),
	-- (le Lys tigré n'existe pas en Classic : arrivé avec Wrath, absent ici)

	-- -----------------------------------------------------------------------
	-- Minage : minerais, puis les pierres tirées des mêmes gisements
	-- -----------------------------------------------------------------------
	[2770]  = R("mining", 1,   "Minerai de cuivre",       "Copper Ore"),
	[2771]  = R("mining", 65,  "Minerai d'étain",         "Tin Ore"),
	[2775]  = R("mining", 75,  "Minerai d'argent",        "Silver Ore"),
	[2772]  = R("mining", 125, "Minerai de fer",          "Iron Ore"),
	[2776]  = R("mining", 155, "Minerai d'or",            "Gold Ore"),
	[3858]  = R("mining", 175, "Minerai de mithril",      "Mithril Ore"),
	[7911]  = R("mining", 230, "Minerai de vrai-argent",  "Truesilver Ore"),
	-- gisement de sombrefer : Gorge des Vents brûlants et Profondeurs de Rochenoire
	[11370] = R("mining", 230, "Minerai de sombrefer",    "Dark Iron Ore"),
	-- petit filon de thorium (245) ; le riche filon (275) donne le MÊME
	-- minerai : un seul itemID, donc une seule ressource à la borne la plus basse
	[10620] = R("mining", 245, "Minerai de thorium",      "Thorium Ore"),
	[2835]  = R("mining", 1,   "Pierre brute",            "Rough Stone"),     -- cuivre
	[2836]  = R("mining", 65,  "Pierre grossière",        "Coarse Stone"),    -- étain
	[2838]  = R("mining", 125, "Pierre lourde",           "Heavy Stone"),     -- fer
	[7912]  = R("mining", 175, "Pierre solide",           "Solid Stone"),     -- mithril
	[12365] = R("mining", 245, "Pierre dense",            "Dense Stone"),     -- thorium

	-- -----------------------------------------------------------------------
	-- Dépeçage : cuirs et peaux (req = compétence des bêtes qui les donnent)
	-- -----------------------------------------------------------------------
	[2934]  = R("skinning", 1,   "Restes de cuir abîmés",  "Ruined Leather Scraps"),
	[2318]  = R("skinning", 1,   "Cuir léger",             "Light Leather"),
	[783]   = R("skinning", 1,   "Peau légère",            "Light Hide"),
	[2319]  = R("skinning", 100, "Cuir moyen",             "Medium Leather"),
	[4232]  = R("skinning", 100, "Peau moyenne",           "Medium Hide"),
	[4234]  = R("skinning", 150, "Cuir lourd",             "Heavy Leather"),
	[4235]  = R("skinning", 150, "Peau lourde",            "Heavy Hide"),
	[4304]  = R("skinning", 200, "Cuir épais",             "Thick Leather"),
	[8169]  = R("skinning", 200, "Peau épaisse",           "Thick Hide"),
	[8170]  = R("skinning", 250, "Cuir robuste",           "Rugged Leather"),
	[8171]  = R("skinning", 250, "Peau robuste",           "Rugged Hide"),
}

-- Métiers de récolte : noms tels que la fenêtre de compétences les donne
-- (minuscules ASCII via ns.AsciiLower, accents conservés), fr et en.
ns.GATHERING_PROFESSIONS = {
	herbalism = { skill = 182, names = { "herbalism", "herboristerie" } },
	mining    = { skill = 186, names = { "mining", "minage" } },
	skinning  = { skill = 393, names = { "skinning", "dépeçage", "depecage" } },
}
ns.GATHERING_PROFESSION_ORDER = { "herbalism", "mining", "skinning" }

if ns.Mark then ns.Mark("GatheringData") end
