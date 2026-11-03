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
ns.COMPANION_APPEARANCES = {
	-- 6291 : creature/dragonwhelp/dragonwhelp.m2 + dragonwhelpskingreen.blp, échelle 0,5
	{ id = "whelp_green",  display = 6291, label = "COMP_APP_WHELP_GREEN" },
	-- 6295 : creature/frog/frog.m2 + froggreen.blp, échelle 1 (une grenouille est déjà petite)
	{ id = "frog",         display = 6295, label = "COMP_APP_FROG",         unlock = { stamp = "subzone", count = 10 } },
	-- 6290 : dragonwhelp.m2 + dragonwhelpskinred.blp, échelle 0,5
	{ id = "whelp_red",    display = 6290, label = "COMP_APP_WHELP_RED",    unlock = { stamp = "zone", count = 5 } },
	-- 6300 : creature/owl/owl.m2 + owlgrey.blp, échelle 0,25
	{ id = "owl",          display = 6300, label = "COMP_APP_OWL",          unlock = { level = 20 } },
	-- 6197 : creature/wisp/wisp.m2 + wisp.blp, échelle 0,5
	{ id = "wisp",         display = 6197, label = "COMP_APP_WISP",         unlock = { stamp = "dungeon", count = 2 } },
	-- 6294 : creature/faeriedragon/faeriedragon.m2 (+ faeriewing.blp), échelle 0,3
	{ id = "sprite",       display = 6294, label = "COMP_APP_SPRITE",       unlock = { stamp = "rare", count = 1 } },
	-- 6293 : dragonwhelp.m2 + dragonwhelpskinblue.blp, échelle 0,5
	{ id = "whelp_blue",   display = 6293, label = "COMP_APP_WHELP_BLUE",   unlock = { level = 40 } },
	-- 6292 : dragonwhelp.m2 + dragonwhelpskinbronze.blp, échelle 0,5
	{ id = "whelp_bronze", display = 6292, label = "COMP_APP_WHELP_BRONZE", unlock = { stamp = "total", count = 100 } },
	-- 6288 : dragonwhelp.m2 + dragonwhelpskinblack.blp, échelle 0,5
	{ id = "whelp_black",  display = 6288, label = "COMP_APP_WHELP_BLACK",  unlock = { level = 60 } },
}

-- Ornements : décorations du cadre, dessinées avec les textures du Theme
-- (aplats, losange, liseré). `key` = interrupteur dans les réglages.
ns.COMPANION_ORNAMENTS = {
	{ id = "ribbon",  key = "companionOrnRibbon",  label = "COMP_ORN_RIBBON",  unlock = { stamp = "zone", count = 10 } },
	{ id = "lantern", key = "companionOrnLantern", label = "COMP_ORN_LANTERN", unlock = { stamp = "subzone", count = 25 } },
	{ id = "medal",   key = "companionOrnMedal",   label = "COMP_ORN_MEDAL",   unlock = { stamp = "dungeon", count = 5 } },
	{ id = "gold",    key = "companionOrnGold",    label = "COMP_ORN_GOLD",    unlock = { level = 60 } },
}

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
