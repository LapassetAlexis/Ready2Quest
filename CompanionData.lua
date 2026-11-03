-- CompanionData.lua -- catalogue du « Compagnon de route » (v1.25.0)
--
-- Données seules, sans logique : les créatures (apparences), les ornements
-- du cadre et les stades d'évolution. Companion.lua les lit.
--
-- Créatures : numéros CreatureDisplayInfo vérifiés dans les DEUX clients,
-- tables publiées par wago.tools (novembre 2026) :
--   * CreatureDisplayInfo  build 1.15.9.70576 (Era) et 1.60.1.70753 (Forever)
--   * CreatureModelData    mêmes builds (ModelID -> FileDataID du modèle)
--   * chemins des fichiers : wago.tools/api/files (FileDataID -> chemin)
-- Pour chaque numéro ci-dessous, les deux builds donnent le MÊME ModelID, le
-- même fichier .m2 et la même texture : la créature est identique sur Era et
-- sur Forever. Ce sont, pour la plupart, les affichages des petites mascottes
-- du jeu d'origine (échelle 0,25 à 0,5 dans la table) : des modèles prévus
-- pour être petits et mignons, qui existent déjà côté client.
-- Ce qu'on ne peut pas savoir hors jeu : que le modèle s'affiche bien dans
-- un PlayerModel d'addon. D'où le repli sur la boussole (Companion.lua).
local ADDON, ns = ...

-- unlock : nil = dès le départ ; { stamp = <type>, count = n } = tampons du
-- Carnet de voyage (ns:JournalCounts) ; { level = n } = niveau du joueur.
-- tier : palier de récompense (coffre de fin de zone). 0 = possédé d'office,
-- 1 = zones 1-19, 2 = zones 20-39, 3 = zones 40-60. Plus c'est rare, plus
-- c'est haut. Les cosmétiques ajoutés avec le coffre (v1.25.0) n'ont pas
-- d'`unlock` : seul leur palier compte, c'est le coffre qui les donne.
ns.COMPANION_APPEARANCES = {
	-- 6291 : creature/dragonwhelp/dragonwhelp.m2 + dragonwhelpskingreen.blp, échelle 0,5
	{ id = "whelp_green",  display = 6291, label = "COMP_APP_WHELP_GREEN",  tier = 0 },
	-- 6295 : creature/frog/frog.m2 + froggreen.blp, échelle 1 (une grenouille est déjà petite)
	{ id = "frog",         display = 6295, label = "COMP_APP_FROG",         unlock = { stamp = "subzone", count = 10 }, tier = 1 },
	-- 6290 : dragonwhelp.m2 + dragonwhelpskinred.blp, échelle 0,5
	{ id = "whelp_red",    display = 6290, label = "COMP_APP_WHELP_RED",    unlock = { stamp = "zone", count = 5 }, tier = 1 },
	-- 6300 : creature/owl/owl.m2 + owlgrey.blp, échelle 0,25
	{ id = "owl",          display = 6300, label = "COMP_APP_OWL",          unlock = { level = 20 }, tier = 2 },
	-- 6197 : creature/wisp/wisp.m2 + wisp.blp, échelle 0,5
	{ id = "wisp",         display = 6197, label = "COMP_APP_WISP",         unlock = { stamp = "dungeon", count = 2 }, tier = 2 },
	-- 6294 : creature/faeriedragon/faeriedragon.m2 (+ faeriewing.blp), échelle 0,3
	{ id = "sprite",       display = 6294, label = "COMP_APP_SPRITE",       unlock = { stamp = "rare", count = 1 }, tier = 3 },
	-- 6293 : dragonwhelp.m2 + dragonwhelpskinblue.blp, échelle 0,5
	{ id = "whelp_blue",   display = 6293, label = "COMP_APP_WHELP_BLUE",   unlock = { level = 40 }, tier = 2 },
	-- 6292 : dragonwhelp.m2 + dragonwhelpskinbronze.blp, échelle 0,5
	{ id = "whelp_bronze", display = 6292, label = "COMP_APP_WHELP_BRONZE", unlock = { stamp = "total", count = 100 }, tier = 3 },
	-- 6288 : dragonwhelp.m2 + dragonwhelpskinblack.blp, échelle 0,5
	{ id = "whelp_black",  display = 6288, label = "COMP_APP_WHELP_BLACK",  unlock = { level = 60 }, tier = 3 },
	-- Nouvelles créatures (v1.25.0). Source de chaque numéro : wago.tools,
	-- CreatureDisplayInfo + CreatureModelData des builds 1.15.9.70576 (Era) et
	-- 1.60.1.70753 (Forever), chemins par wago.tools/api/files : même ModelID,
	-- même .m2, mêmes textures dans les deux builds.
	-- 5554 : creature/cat/cat.m2 + orangetabby.blp, échelle 0,5 (chat tigré roux, mascotte)
	{ id = "cat_orange",   display = 5554, label = "COMP_APP_CAT_ORANGE",   tier = 1 },
	-- 1560 : creature/rabbit/rabbit.m2 + rabbitskinbrown.blp, échelle 0,75 (lapin)
	{ id = "rabbit",       display = 1560, label = "COMP_APP_RABBIT",       tier = 1 },
	-- 16259 : creature/turtle/turtle.m2 + turtleskingreen.blp, échelle 0,25 (petite tortue)
	{ id = "turtle",       display = 16259, label = "COMP_APP_TURTLE",      tier = 1 },
	-- 6192 : creature/parrot/parrot.m2 + parrotskinblue.blp, échelle 0,25 (ara hyacinthe, mascotte)
	{ id = "parrot",       display = 6192, label = "COMP_APP_PARROT",       tier = 2 },
	-- 6303 : creature/snake/snake.m2 + snakeskinred.blp, échelle 1 (serpent cramoisi, mascotte)
	{ id = "snake",        display = 6303, label = "COMP_APP_SNAKE",        tier = 2 },
	-- 9990 : creature/cat/cat.m2 + white.blp, échelle 0,5 (chaton blanc, mascotte rare)
	{ id = "cat_white",    display = 9990, label = "COMP_APP_CAT_WHITE",    tier = 3 },
}

-- Ornements : décorations du cadre, dessinées avec les textures du Theme
-- (aplats, losange, liseré). `key` = interrupteur dans les réglages.
ns.COMPANION_ORNAMENTS = {
	{ id = "ribbon",  key = "companionOrnRibbon",  label = "COMP_ORN_RIBBON",  unlock = { stamp = "zone", count = 10 }, tier = 1 },
	{ id = "lantern", key = "companionOrnLantern", label = "COMP_ORN_LANTERN", unlock = { stamp = "subzone", count = 25 }, tier = 2 },
	{ id = "medal",   key = "companionOrnMedal",   label = "COMP_ORN_MEDAL",   unlock = { stamp = "dungeon", count = 5 }, tier = 2 },
	{ id = "gold",    key = "companionOrnGold",    label = "COMP_ORN_GOLD",    unlock = { level = 60 }, tier = 3 },
	-- v1.25.0 : palier seul (le coffre les donne)
	{ id = "flower",  key = "companionOrnFlower",  label = "COMP_ORN_FLOWER",  tier = 1 },
	{ id = "pennant", key = "companionOrnPennant", label = "COMP_ORN_PENNANT", tier = 1 },
	{ id = "crystal", key = "companionOrnCrystal", label = "COMP_ORN_CRYSTAL", tier = 2 },
	{ id = "crown",   key = "companionOrnCrown",   label = "COMP_ORN_CROWN",   tier = 3 },
}

-- Cadres : la bordure du cadre du compagnon. Toujours un filet 1 px teinté
-- (`edge` = r, g, b, a), et en plus, si `backdrop`, une bordure du client
-- posée par BackdropTemplate. Si la bordure ne se pose pas, le filet reste.
-- `inner` : second filet intérieur. Textures présentes dans les DEUX builds
-- (ManifestInterfaceData de 1.15.9.70576 et 1.60.1.70753, wago.tools).
local TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local DIALOG_BORDER  = "Interface\\DialogFrame\\UI-DialogBox-Border"
ns.COMPANION_FRAMES = {
	-- défaut : le filet ambre discret de Theme.CreateDiscreet
	{ id = "slate",  label = "COMP_FRAME_SLATE",  tier = 0, edge = { 0.73, 0.47, 0.17, 0.45 } },
	{ id = "copper", label = "COMP_FRAME_COPPER", tier = 1, edge = { 0.80, 0.48, 0.25, 0.95 }, inner = { 0.45, 0.25, 0.12, 0.9 } },
	{ id = "oak",    label = "COMP_FRAME_OAK",    tier = 1, edge = { 0.42, 0.29, 0.17, 1 },
		backdrop = { file = "Interface\\ACHIEVEMENTFRAME\\UI-Achievement-WoodBorder", size = 16, color = { 1, 1, 1 } } },
	{ id = "silver", label = "COMP_FRAME_SILVER", tier = 2, edge = { 0.80, 0.82, 0.86, 0.9 },
		backdrop = { file = TOOLTIP_BORDER, size = 12, color = { 0.86, 0.88, 0.92 } } },
	{ id = "frost",  label = "COMP_FRAME_FROST",  tier = 2, edge = { 0.62, 0.86, 1, 0.9 },
		backdrop = { file = TOOLTIP_BORDER, size = 14, color = { 0.62, 0.88, 1 } }, inner = { 0.80, 0.95, 1, 0.5 } },
	{ id = "rune",   label = "COMP_FRAME_RUNE",   tier = 2, edge = { 0.36, 0.56, 0.84, 0.9 },
		backdrop = { file = DIALOG_BORDER, size = 16, color = { 0.50, 0.66, 1 } }, inner = { 0.36, 0.56, 0.84, 0.6 } },
	{ id = "fel",    label = "COMP_FRAME_FEL",    tier = 3, edge = { 0.45, 0.95, 0.25, 0.9 },
		backdrop = { file = DIALOG_BORDER, size = 16, color = { 0.50, 1, 0.30 } }, inner = { 0.30, 0.70, 0.15, 0.7 } },
	{ id = "gilded", label = "COMP_FRAME_GILDED", tier = 3, edge = { 0.91, 0.65, 0.29, 1 },
		backdrop = { file = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", size = 16, color = { 1, 1, 1 } },
		inner = { 0.91, 0.65, 0.29, 0.6 } },
}

-- Fonds : la texture de fond du cadre (`texture`, sinon aplat) teintée par
-- `color`, ou un dégradé vertical (`gradient` = { top, bottom }). `stars` :
-- quelques points de lumière. Repli : aplat teinté si la texture ou le
-- dégradé ne passe pas. Mêmes vérifications de textures que les cadres.
ns.COMPANION_BACKGROUNDS = {
	-- défaut : le noir translucide de Theme.CreateDiscreet
	{ id = "night",     label = "COMP_BG_NIGHT",     tier = 0, color = { 0, 0, 0, 0.66 } },
	{ id = "parchment", label = "COMP_BG_PARCHMENT", tier = 1, texture = "Interface\\Stationery\\StationeryTest1",
		color = { 0.50, 0.42, 0.32, 0.92 } },
	{ id = "forest",    label = "COMP_BG_FOREST",    tier = 1, color = { 0.04, 0.12, 0.06, 0.85 },
		gradient = { top = { 0.06, 0.18, 0.09, 0.85 }, bottom = { 0.02, 0.06, 0.03, 0.90 } } },
	{ id = "dusk",      label = "COMP_BG_DUSK",      tier = 1, color = { 0.30, 0.14, 0.20, 0.85 },
		gradient = { top = { 0.18, 0.10, 0.28, 0.85 }, bottom = { 0.42, 0.18, 0.10, 0.85 } } },
	{ id = "frost",     label = "COMP_BG_FROST",     tier = 2, color = { 0.10, 0.20, 0.30, 0.88 },
		gradient = { top = { 0.18, 0.32, 0.45, 0.88 }, bottom = { 0.04, 0.09, 0.15, 0.90 } } },
	{ id = "marble",    label = "COMP_BG_MARBLE",    tier = 2, texture = "Interface\\FrameGeneral\\UI-Background-Marble",
		color = { 0.45, 0.45, 0.50, 0.92 } },
	{ id = "ember",     label = "COMP_BG_EMBER",     tier = 3, color = { 0.30, 0.08, 0.03, 0.90 },
		gradient = { top = { 0.10, 0.03, 0.02, 0.90 }, bottom = { 0.50, 0.16, 0.04, 0.90 } } },
	{ id = "stars",     label = "COMP_BG_STARS",     tier = 3, color = { 0.04, 0.05, 0.16, 0.92 }, stars = true,
		gradient = { top = { 0.02, 0.03, 0.10, 0.92 }, bottom = { 0.08, 0.10, 0.25, 0.90 } } },
	{ id = "velvet",    label = "COMP_BG_VELVET",    tier = 3, texture = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
		color = { 0.70, 0.52, 0.30, 0.95 } },
}

-- Catalogue par type (clé = `kind` de ns:CompanionIsUnlocked)
ns.COMPANION_CATALOG = {
	{ kind = "app",   list = ns.COMPANION_APPEARANCES },
	{ kind = "orn",   list = ns.COMPANION_ORNAMENTS },
	{ kind = "frame", list = ns.COMPANION_FRAMES },
	{ kind = "bg",    list = ns.COMPANION_BACKGROUNDS },
}

-- Récompenses de coffre : liste plate de TOUS les cosmétiques de palier ≥ 1,
-- dans l'ordre du catalogue. { kind, id, label (clé L), tier }.
ns.COMPANION_REWARDS = {}
for _, group in ipairs(ns.COMPANION_CATALOG) do
	for _, def in ipairs(group.list) do
		if (tonumber(def.tier) or 0) >= 1 then
			ns.COMPANION_REWARDS[#ns.COMPANION_REWARDS + 1] = { kind = group.kind, id = def.id, label = def.label, tier = def.tier }
		end
	end
end

-- Stades : liés au niveau du JOUEUR, jamais de retour en arrière.
ns.COMPANION_STAGES = {
	{ level = 1,  label = "COMP_STAGE_1", scale = 0.70 },
	{ level = 10, label = "COMP_STAGE_2", scale = 0.82 },
	{ level = 20, label = "COMP_STAGE_3", scale = 0.94 },
	{ level = 40, label = "COMP_STAGE_4", scale = 1.06 },
	{ level = 60, label = "COMP_STAGE_5", scale = 1.18 },
}

-- Animations (AnimationData, mêmes numéros et mêmes replis dans les deux
-- builds) : 0 Stand, 68 EmoteCheer, 69 EmoteDance, 100 Sleep (71 EmoteSleep
-- se replie sur 100). Une créature sans l'animation retombe sur Stand.
ns.COMPANION_ANIMS = { idle = 0, cheer = 68, dance = 69, sleep = 100 }

if ns.Mark then ns.Mark("CompanionData") end
