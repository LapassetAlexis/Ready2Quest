-- AzerothStyle.lua -- le style de l'interface (QuestCompanion 2.5.0 ; 3.1.2 :
-- l'ancien habillage d'art du client retiré)
--
-- Le réglage « Style de l'interface » (page Compagnon, /qc style
-- azeroth|sobre) choisit le thème du socle : « azeroth » pose le thème
-- forgé, « sobre » le Sobre. Le changement s'applique tout de suite : chaque
-- bandeau a un cadre par clé de style (ns:StyleKey, ns:StyleCached), le cadre
-- du compagnon est rhabillé sur place.
-- Aussi ici : le bandeau de résultat « Capturé ! », les bandeaux des sceaux
-- de zone et des titres de dresseur (file du carnet), les teintes de
-- l'anneau par cadre, et les effets du compagnon (bulle, lueur ronde, éclats
-- d'une brillante, niveau, grandes récompenses) que le médaillon forgé
-- reprend (ns:CompanionShinyFX, ns:CompanionLevelFX, ns:BannerRewardFX).
-- Les noms AZEROTH_* (encres, géométrie de l'anneau, atlas des effets)
-- restent ceux d'origine : ces tables servent aux briques forgées.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.UI_STYLES = { "azeroth", "sobre" }
ns.UI_STYLE_DEFAULT = "azeroth"
-- atlas du client (UiTextureAtlas 1771, fichier 4035524)
ns.AZEROTH_ATLAS = {
	bg         = "ui-achievement-alert-background",
	bgGuild    = "ui-achievement-guild-background",
	plate      = "ui-achievement-alert-background-mini",
	glow       = "ui-achievement-alert-glow-glow",
	shine      = "ui-achievement-alert-glow-shine",
	bling      = "ui-achievement-bling",
	frame      = "ui-achievement-iconframe",
	frameRound = "ui-achievement-guild-iconframe",
	shield     = "ui-achievement-shield-1",
	-- 2.9.0 : le gris de même gabarit que le doré (62×56, mesuré sur l'atlas
	-- 4035524) ; « ui-achievement-shield-desaturated » est une pièce de
	-- 128×128 où l'écu n'occupe que le milieu : posé à la taille du doré, il
	-- sortait minuscule (lignes pas encore obtenues, scène « Échappé… »)
	shieldGrey = "ui-achievement-shield-1-desaturated",
}
-- celles sans lesquelles le style ne tient pas (le reste est décoratif)
ns.AZEROTH_REQUIRED = { "bg", "bgGuild", "plate", "frame", "frameRound", "shield" }
-- le cadre en bois des hauts faits (fenêtres de capture, 2.5.1) : coins
-- 64×64, bords 64×64 répétés (« _ » : en largeur, « ! » : en hauteur)
ns.AZEROTH_WOOD = {
	tl     = "achievement-wood-nineslice-cornertopleft",
	tr     = "achievement-wood-nineslice-cornertopright",
	bl     = "achievement-wood-nineslice-cornerbottomleft",
	br     = "achievement-wood-nineslice-cornerbottomright",
	top    = "_achievement-wood-nineslice-edgetop",
	bottom = "_achievement-wood-nineslice-edgebottom",
	left   = "!achievement-wood-nineslice-edgeleft",
	right  = "!achievement-wood-nineslice-edgeright",
}
ns.AZEROTH_WOOD_KEYS = { "tl", "tr", "bl", "br", "top", "bottom", "left", "right" }
-- les fenêtres de capture demandent aussi ceux-là (bandeau, plaque, cadre d'icône, bouclier)
ns.AZEROTH_SCENE_REQUIRED = { "bg", "plate", "frame", "shield" }
-- géométrie du bois : pièce de 64 px, qui déborde de 8 px du cadre ; le bois
-- visible mord 16 px dans le cadre ; le contenu commence à 26 px du bord
-- police des hauts faits (Friz Quadrata, celle du client)
ns.AZEROTH_FONT = "Fonts\\FRIZQT__.TTF"
-- géométrie du bandeau (maquette validée : 310×101 à l'échelle 1,25) et de
-- la bande sombre du bandeau « Capture possible »
ns.AZEROTH_LAYOUT = {
	w = 388, h = 126, overlap = 10, stripW = 330, strip = 76,
	infoY = -16, hintY = -32, rowH = 18, rowBottom = 7,
	titleY = -28, titleW = 252, nameY = -50, nameW = 260, nameWide = 290, starsY = -82,
	nameMax = 20, nameMin = 11, titleMax = 12, titleMin = 9,
	-- 2.11.1 : bandeau de guilde, nom sur deux lignes au besoin (en dessous
	-- de nameWrap px sur une ligne) ; nom et sous-ligne remontés/descendus
	nameWrap = 15, nameY2 = -43, starsY2 = -84, subMax = 12, subMin = 9,
}
-- 2.9.0 : tailles des boucliers (même rapport que l'atlas, 63×56) : bandeau
-- de verdict des scènes, lignes du carnet des hauts faits
ns.AZEROTH_SHIELD_SIZE = { verdict = { 63, 56 }, row = { 52, 46 } }
ns.CAPTURE_RESULT_SECONDS = 3.5   -- s d'affichage du bandeau « Capturé ! »
ns.CAPTURE_RESULT_STALE = 30      -- s d'attente au plus (combat) avant de l'oublier
local AZ = ns.AZEROTH_ATLAS
-- 2.11.2 : #ffe27a exact, gardé (Theme.SHINY l'arrondit à 0,89 / 0,48)
local SHINY_NAME = { 1, 0.886, 0.478 }    -- nom d'une brillante (#ffe27a)

-- ---------------------------------------------------------------------------
-- Encres et voiles (2.8.2) : lisibilité mesurée
-- ---------------------------------------------------------------------------
-- Les fonds des hauts faits (parchemins 130661/130662, fond des lignes
-- 235397, page des statistiques 235412, bandeaux de l'atlas 4035524) sont
-- des tons moyens (luminance relative 0,15 à 0,30) : même un texte noir n'y
-- atteint pas 4,5:1 sur leurs parties les plus sombres. Sous les textes
-- sombres, un voile crème (aplat du thème) éclaircit donc le fond ; les
-- encres sont choisies pour tenir le seuil WCAG 2.x (4,5:1 texte courant,
-- 3:1 grand titre de 16 px et plus) contre le PIRE fond : les 10 % les plus
-- sombres de la zone du texte (les 10 % les plus clairs pour un texte
-- clair). Mesures : textures du client (wago.tools), même découpe, même
-- couleur, même voile, composées comme en jeu (docs/TECHNIQUE.md, 2.8.2).
-- L'ombre de la police n'est pas comptée.
ns.AZEROTH_INK = {
	veil = { 0.98, 0.94, 0.82 },             -- crème du voile
	alpha = { bubble = 0.40, page = 0.35, nav = 0.45, light = 0.40, guide = 0.50, strip = 0.50 },
	ink = { 0.10, 0.06, 0.02 },              -- texte courant (#1a0f05)
	inkSoft = { 0.17, 0.10, 0.03 },          -- texte du thème sur parchemin (#2b1a08)
	inkMuted = { 0.24, 0.15, 0.06 },         -- secondaire, dates (#3d260f)
	title = { 0.36, 0.14, 0.00 },            -- titres sur parchemin, nom de la bulle (#5c2400)
	head = { 0.30, 0.11, 0.00 },             -- intertitres (12 px) du guide (#4d1c00)
	reward = { 0.00, 0.22, 0.02 },           -- « Récompense : … » (vert sombre)
	amber = { 0.32, 0.12, 0.00 },            -- l'ambre du thème sur parchemin
	green = { 0.00, 0.22, 0.00 }, blue = { 0.04, 0.16, 0.42 }, red = { 0.38, 0.04, 0.02 },
	orange = { 0.34, 0.11, 0.00 }, grey = { 0.20, 0.17, 0.14 },
	light = { 0.93, 0.89, 0.80 },            -- texte clair sur fond sombre (lignes pas encore obtenues)
	rewardLight = { 0.62, 0.92, 0.52 },
	white = { 1, 1, 1 }, barGrey = { 0.91, 0.89, 0.83 }, goldHead = { 0.97, 0.85, 0.47 },
	star = { 1, 0.84, 0.29 }, tagBlue = Theme.BLUE, tagGrey = Theme.MUTED_LIGHT,   -- 2.11.0 : jetons du socle (mêmes valeurs)
	navText = Theme.TEXT, navSel = Theme.PARCHMENT,
	zoneDim = { 0.74, 0.71, 0.66 },          -- 2.9.1 : zone pas encore vue (Exploration), sur le fond des catégories
	stripLabel = { 0.95, 0.84, 0.54 }, stripDetail = { 0.84, 0.77, 0.60 },
	markGold = { 0.97, 0.85, 0.47 }, markGrey = { 0.86, 0.82, 0.74 },
	-- rareté du nom dans la Ménagerie, sur la ligne claire
	rTrivial = { 0.24, 0.22, 0.20 }, rElite = { 0.00, 0.18, 0.45 }, rRare = { 0.32, 0.06, 0.48 },
	rBoss = { 0.40, 0.15, 0.00 }, rShiny = { 0.28, 0.15, 0.00 },
	tagShade = { 0.10, 0.06, 0.02, 0.92 },   -- sous la bande de l'étiquette (Compte / Perso)
	-- 2.11.0 : encres jusque-là écrites en dur (fiche 08), et le texte des champs
	statLabel = { 0.89, 0.82, 0.66 },        -- libellé des plaques de chiffres (page Compagnon)
	plateCount = { 0.95, 0.87, 0.66 },       -- nombre de la case des points (plaque d'en-tête)
	giftGold = { 1, 0.95, 0.78 }, giftGrey = { 0.80, 0.76, 0.68 },   -- cadeau des paliers d'Exploration
	fieldText = Theme.LABEL,                 -- texte d'une liste déroulante / recherche
	-- 2.11.0 : ombre posée sous un texte clair sur un fond variable (icône, bande dorée)
	shade = { 0.10, 0.06, 0.02 },
	-- 2.11.2 (fiche 28) : teintes jusque-là locales (AzerothStyle, carnet
	-- Azeroth), valeurs inchangées. Le bois du carnet (woodNight) n'est pas
	-- celui des fenêtres de capture (woodBg) : deux fonds différents, gardés.
	woodBg = { 0.11, 0.086, 0.06 },          -- fond sombre et chaud (#1c160f)
	woodDeep = { 0.07, 0.055, 0.035 },       -- bas du fond (#120e09)
	woodWarm = { 0.23, 0.18, 0.12 },         -- haut du fond (#3a2e1f)
	woodGlow = { 0.55, 0.42, 0.24 },         -- halo du bois (alpha 0,35)
	woodNight = { 0.10, 0.07, 0.04 },        -- fond du carnet Azeroth
	fx = { 1, 0.80, 0.38 },                  -- teinte des lueurs blanches (« Aguerri ! »)
	fxText = { 1, 0.86, 0.45 },              -- texte « Aguerri ! »
	bubbleEdge = { 0.24, 0.14, 0.05 },       -- liseré de la bulle
	goldText = { 1, 0.84, 0.42 },            -- texte des boutons, de la plaque (carnet)
	buttonOff = { 0.80, 0.77, 0.71 },        -- 3.0.0 : libellé d'un bouton désactivé (bois délavé)
	lightSoft = { 0.89, 0.82, 0.66 },        -- (même valeur que statLabel)
	catGold = { 1, 0.76, 0.25 },             -- surbrillance des catégories
	barGreen = { 0.10, 0.62, 0.10 }, barOrange = { 0.80, 0.33, 0.08 }, barGold = { 0.78, 0.56, 0.12 },
	edgeDark = { 0.106, 0.063, 0.024 },      -- liseré sombre des lignes du carnet
	catVeil = { 0.23, 0.13, 0.03 },          -- voile brun d'une catégorie (alpha 0,14)
	barBg = { 0.07, 0.04, 0.01 },            -- fond d'une barre du carnet
	fieldBg = { 0.12, 0.07, 0.03 },          -- fond d'un champ du carnet
	dim = { 0.5, 0.5, 0.5 },                 -- texture estompée (carnet)
	ptsGrey = { 0.85, 0.85, 0.85 },          -- points d'un haut fait pas obtenu (carnet)
	bandLift = 1.25,                         -- éclaircissement d'une bande sur deux (pas une encre)
}
-- 2.11.2 (fiche 28) : toutes les palettes de boutons Azeroth en une table.
-- gold / dark : boutons dessinés des fenêtres de capture ; red / brown :
-- boutons du carnet. Le bord brun du carnet (0,42) et celui de « dark »
-- (0,415) diffèrent d'un cheveu : gardés tels quels (aucune teinte ne change).
ns.AZEROTH_BUTTONS = {
	gold = { top = { 0.48, 0.29, 0.07 }, bottom = { 0.29, 0.165, 0.03 }, edge = { 0.85, 0.66, 0.27 } },
	dark = { top = { 0.235, 0.19, 0.133 }, bottom = { 0.133, 0.10, 0.067 }, edge = { 0.54, 0.415, 0.17 } },
	red = { top = { 0.56, 0.12, 0.05 }, bottom = { 0.30, 0.05, 0.01 }, edge = { 0.77, 0.60, 0.27 } },
	brown = { top = { 0.20, 0.12, 0.05 }, bottom = { 0.09, 0.05, 0.02 }, edge = { 0.54, 0.42, 0.17 } },
	text = { 1, 0.95, 0.81 }, sub = { 0.9, 0.83, 0.64 },     -- texte et sous-ligne (capture)
	gloss = { 1, 0.86, 0.59 }, hover = { 1, 0.85, 0.5 },     -- reflet (alpha 0,35), survol (0,12, ADD)
	outer = { 0.08, 0.03, 0 },                               -- liseré extérieur (carnet)
	-- 3.0.0 : bouton désactivé (carnet et capture) : bois délavé, gris-brun
	-- désaturé, libellé clair atténué (4,84:1 sur le haut du dégradé, le plus
	-- clair : rôle « button.off » ; avant : encre sombre ou gris estompé sur
	-- le rouge, sous 2:1)
	off = { top = { 0.33, 0.30, 0.27 }, bottom = { 0.20, 0.18, 0.16 }, edge = { 0.46, 0.42, 0.36 } },
	offText = ns.AZEROTH_INK.buttonOff,
	pressAlpha = 0.22,                                       -- voile sombre d'un bouton enfoncé
}
-- 2.9.1 : page Missions, habit Azeroth : voile vert d'une carte faite, aplat
-- et pointillés de l'encart des 3, tampon « Faite », étiquettes, pastilles
ns.AZEROTH_MISSION = {
	tint = { 0.62, 0.85, 0.45, 0.22 }, callout = { 0.97, 0.90, 0.72, 0.5 }, dash = { 0.65, 0.52, 0.25, 1 },
	-- 2.11.0 : étiquette du caractère plus sombre (#5a3a14), filet des intertitres
	stamp = { 0.12, 0.37, 0.12 }, chipZone = { 0.165, 0.31, 0.54 }, chipTrait = { 0.353, 0.227, 0.078 },
	rule = { 0.54, 0.35, 0.16 },
	pipOn = { 0.97, 0.85, 0.47 }, pipOff = { 0.35, 0.27, 0.16 },
}
-- rôle -> { encre, luminance du pire fond mesurée, seuil, taille (px) } ;
-- commentaire : texte sombre/clair, pire fond, fond moyen, contraste obtenu
ns.AZEROTH_CONTRAST = {
	["bubble.name"] = { "title", 0.3918, 4.5, 10 },   -- sombre, fond 0.392 (moy. 0.431) : 5.19:1
	["bubble.text"] = { "ink", 0.3838, 4.5, 12 },   -- sombre, fond 0.384 (moy. 0.429) : 7.78:1
	["feat.name"] = { "white", 0.0725, 4.5, 12 },   -- clair, fond 0.072 (moy. 0.035) : 8.57:1
	["feat.desc"] = { "ink", 0.3678, 4.5, 11 },   -- sombre, fond 0.368 (moy. 0.419) : 7.50:1
	["feat.reward"] = { "reward", 0.3326, 4.5, 11 },   -- sombre, fond 0.333 (moy. 0.413) : 4.87:1
	["mission.done"] = { "green", 0.3326, 4.5, 11 },   -- sombre, « faite » des missions, fond des lignes 0.333 : 4.88:1 (2.9.0)
	["feat.date"] = { "inkMuted", 0.4149, 4.5, 11 },   -- sombre, fond 0.415 (moy. 0.449) : 6.25:1
	["feat.count"] = { "inkMuted", 0.4137, 4.5, 11 },   -- sombre, fond 0.414 (moy. 0.443) : 6.24:1
	["feat.scopeAccount"] = { "tagBlue", 0.0140, 4.5, 10 },   -- clair, fond 0.014 (moy. 0.008) : 4.96:1
	["feat.scopeChar"] = { "tagGrey", 0.0140, 4.5, 10 },   -- clair, fond 0.014 (moy. 0.008) : 6.86:1
	["featOpen.name"] = { "barGrey", 0.0517, 4.5, 12 },   -- clair, fond 0.052 (moy. 0.028) : 8.04:1
	["featOpen.desc"] = { "light", 0.1013, 4.5, 11 },   -- clair, fond 0.101 (moy. 0.084) : 5.44:1
	["featOpen.reward"] = { "rewardLight", 0.0967, 4.5, 11 },   -- clair, fond 0.097 (moy. 0.081) : 4.99:1
	["featOpen.count"] = { "light", 0.0920, 4.5, 11 },   -- clair, fond 0.092 (moy. 0.081) : 5.80:1
	["nav.label"] = { "navText", 0.0128, 4.5, 12 },   -- clair, fond 0.013 (moy. 0.006) : 11.27:1
	["nav.selected"] = { "navSel", 0.1060, 4.5, 12 },   -- clair, fond 0.106 (moy. 0.068) : 5.54:1
	["nav.badge"] = { "tagBlue", 0.0107, 4.5, 11 },   -- clair, fond 0.011 (moy. 0.005) : 5.23:1
	["nav.group"] = { "ink", 0.2300, 4.5, 10 },   -- sombre, fond 0.230 (moy. 0.246) : 5.02:1
	["nav.pantry"] = { "inkSoft", 0.3843, 4.5, 11 },   -- sombre, fond 0.384 (moy. 0.422) : 6.94:1
	["men.no"] = { "inkSoft", 0.2744, 4.5, 11 },   -- sombre, fond 0.274 (moy. 0.304) : 5.19:1
	["men.name"] = { "ink", 0.3861, 4.5, 12 },   -- sombre, fond 0.386 (moy. 0.443) : 7.82:1
	["men.trivial"] = { "rTrivial", 0.3861, 4.5, 12 },   -- sombre, fond 0.386 (moy. 0.443) : 4.81:1
	["men.elite"] = { "rElite", 0.3861, 4.5, 12 },   -- sombre, fond 0.386 (moy. 0.443) : 5.33:1
	["men.rare"] = { "rRare", 0.3861, 4.5, 12 },   -- sombre, fond 0.386 (moy. 0.443) : 5.11:1
	["men.boss"] = { "rBoss", 0.3861, 4.5, 12 },   -- sombre, fond 0.386 (moy. 0.443) : 4.73:1
	["men.shiny"] = { "rShiny", 0.3861, 4.5, 12 },   -- sombre, fond 0.386 (moy. 0.443) : 5.62:1
	["men.detail"] = { "inkSoft", 0.4179, 4.5, 11 },   -- sombre, fond 0.418 (moy. 0.450) : 7.48:1
	["menUnknown.no"] = { "light", 0.0363, 4.5, 11 },   -- clair, fond 0.036 (moy. 0.027) : 9.54:1
	["menUnknown.name"] = { "light", 0.1013, 4.5, 12 },   -- clair, fond 0.101 (moy. 0.089) : 5.44:1
	["seal.title"] = { "ink", 0.3375, 4.5, 12 },   -- sombre, fond 0.338 (moy. 0.430) : 6.95:1
	["seal.detail"] = { "inkSoft", 0.3472, 4.5, 11 },   -- sombre, fond 0.347 (moy. 0.432) : 6.35:1
	["seal.trainer"] = { "amber", 0.3406, 4.5, 11 },   -- sombre, fond 0.341 (moy. 0.426) : 5.05:1
	["page.ink"] = { "ink", 0.3172, 4.5, 12 },   -- sombre, fond 0.317 (moy. 0.390) : 6.59:1
	["page.inkSoft"] = { "inkSoft", 0.3172, 4.5, 12 },   -- sombre, fond 0.317 (moy. 0.390) : 5.87:1
	["page.inkMuted"] = { "inkMuted", 0.3172, 4.5, 11 },   -- sombre, fond 0.317 (moy. 0.390) : 4.94:1
	["page.amber"] = { "amber", 0.3172, 4.5, 11 },   -- sombre, fond 0.317 (moy. 0.390) : 4.75:1
	["page.green"] = { "green", 0.3172, 4.5, 11 },   -- sombre, fond 0.317 (moy. 0.390) : 4.69:1
	["page.blue"] = { "blue", 0.3172, 4.5, 11 },   -- sombre, fond 0.317 (moy. 0.390) : 4.77:1
	["page.red"] = { "red", 0.3172, 4.5, 11 },   -- sombre, fond 0.317 (moy. 0.390) : 4.73:1
	["page.orange"] = { "orange", 0.3172, 4.5, 11 },   -- sombre, fond 0.317 (moy. 0.390) : 4.68:1
	["page.grey"] = { "grey", 0.3172, 4.5, 11 },   -- sombre, fond 0.317 (moy. 0.390) : 4.84:1
	["page.title"] = { "title", 0.2924, 3.0, 22 },   -- sombre, fond 0.292 (moy. 0.321) : 4.02:1
	["guide.title"] = { "goldHead", 0.0078, 3.0, 18 },   -- clair, fond 0.008 (moy. 0.005) : 13.09:1
	["guide.head"] = { "head", 0.3300, 4.5, 12 },   -- sombre, fond 0.330 (moy. 0.453) : 5.14:1
	["guide.text"] = { "inkSoft", 0.3300, 4.5, 12 },   -- sombre, fond 0.330 (moy. 0.453) : 6.08:1
	["tile.text"] = { "ink", 0.3252, 4.5, 12 },   -- sombre, fond 0.325 (moy. 0.425) : 6.73:1
	["tile.title"] = { "title", 0.3252, 3.0, 16 },   -- sombre, fond 0.325 (moy. 0.425) : 4.41:1
	["strip.label"] = { "stripLabel", 0.0145, 4.5, 11 },   -- clair, fond 0.015 (moy. 0.009) : 11.47:1
	["strip.detail"] = { "stripDetail", 0.0158, 4.5, 11 },   -- clair, fond 0.016 (moy. 0.012) : 9.31:1
	["mark.gold"] = { "markGold", 0.0557, 4.5, 11 },   -- clair, fond 0.056 (moy. 0.042) : 7.16:1
	["mark.grey"] = { "markGrey", 0.0200, 4.5, 11 },   -- clair, fond 0.020 (moy. 0.015) : 9.91:1
	["trainer.band"] = { "light", 0.0585, 4.5, 12 },   -- clair, fond 0.059 (moy. 0.046) : 7.58:1
	["banner.title"] = { "ink", 0.3048, 4.5, 12 },   -- sombre, fond 0.305 (moy. 0.397) : 6.37:1
	["banner.name"] = { "white", 0.0549, 3.0, 20 },   -- clair, fond 0.055 (moy. 0.033) : 10.01:1
	["banner.stars"] = { "star", 0.0969, 4.5, 11 },   -- clair, fond 0.097 (moy. 0.063) : 5.10:1
	["verdict.title"] = { "ink", 0.2798, 4.5, 11 },   -- sombre, fond 0.280 (moy. 0.380) : 5.92:1
	["verdict.name"] = { "white", 0.0252, 3.0, 20 },   -- clair, fond 0.025 (moy. 0.019) : 13.96:1
	["cplate.name"] = { "white", 0.0293, 4.5, 12 },   -- clair, fond 0.029 (moy. 0.022) : 13.24:1
	["cplate.mood"] = { "ink", 0.2763, 4.5, 10 },   -- sombre, fond 0.276 (moy. 0.373) : 5.85:1
	["splate.title"] = { "ink", 0.3363, 4.5, 11 },   -- sombre, fond 0.336 (moy. 0.405) : 6.93:1
	["splate.name"] = { "white", 0.0252, 3.0, 17 },   -- clair, fond 0.025 (moy. 0.021) : 13.97:1
	["section.label"] = { "head", 0.2935, 4.5, 10 },   -- sombre, fond 0.293 (moy. 0.376) : 4.65:1 (2.9.0, intertitres (Theme.CreateSection) sur parchemin voilé, pire décile de toute la page (journal 758×678, fiche 778×578, ombre de gauche comprise) ; fiche : 0.336 au pire sous ses intertitres)
	["section.detail"] = { "inkSoft", 0.2935, 4.5, 10 },   -- sombre, fond 0.293 (moy. 0.376) : 5.49:1 (2.9.0, leur détail entre parenthèses, même fond)
	["effects.line"] = { "ink", 0.3217, 4.5, 11 },   -- sombre, fond 0.322 (moy. 0.355) : 6.67:1 (2.9.0, « Ses effets » (page Compagnon), lignes chasse/confort, effets actifs)
	["effects.linePending"] = { "inkSoft", 0.3217, 4.5, 11 },   -- sombre, fond 0.322 (moy. 0.355) : 5.94:1 (2.9.0, les mêmes, effets en attente)
	["effects.state"] = { "ink", 0.3036, 4.5, 11 },   -- sombre, fond 0.304 (moy. 0.336) : 6.34:1 (2.9.0, ligne force/envies/état (bas du bloc, le plus sombre), actifs)
	["effects.statePending"] = { "inkSoft", 0.3036, 4.5, 11 },   -- sombre, fond 0.304 (moy. 0.336) : 5.65:1 (2.9.0, la même, en attente / module coupé)
	-- 2.9.1 : Exploration, liste des quêtes d'une zone (lignes « light » : fond 235397 en Cover sur 504×24,
	-- voile crème 0,40 ; nom de x 28 à 342, détail sur les 154 px de droite) et liste des zones (fond des
	-- catégories 130652, découpe 167×29 étirée sur 190×26, rangée opaque)
	["quest.name"] = { "ink", 0.3250, 4.5, 12 },   -- sombre, fond 0.325 (moy. 0.423) : 6.73:1 (quête à faire)
	["quest.nameDone"] = { "inkMuted", 0.3250, 4.5, 12 },   -- sombre, fond 0.325 (moy. 0.423) : 5.04:1 (faite, ou verrouillée)
	["quest.detail"] = { "inkMuted", 0.4213, 4.5, 11 },   -- sombre, fond 0.421 (moy. 0.452) : 6.34:1 (« niveau n »)
	["quest.detailDone"] = { "green", 0.4213, 4.5, 11 },   -- sombre, fond 0.421 (moy. 0.452) : 6.01:1 (« faite »)
	-- 2.12.0 : Juke-box. Pistes : même ligne claire que les quêtes (504×24, nom de x 28 à 350, durée dans les
	-- 154 px de droite) ; « en cours », aide et page vide : parchemin des statistiques au voile du guide
	["juke.name"] = { "ink", 0.3250, 4.5, 12 },   -- sombre, fond 0.325 (moy. 0.423) : 6.73:1 (comme quest.name)
	["juke.playing"] = { "amber", 0.3250, 4.5, 12 },   -- sombre, même fond : 4.85:1 (la piste qui joue)
	["juke.missing"] = { "inkMuted", 0.3250, 4.5, 12 },   -- sombre, même fond : 5.04:1 (absente du client)
	["juke.detail"] = { "inkMuted", 0.4213, 4.5, 11 },   -- sombre, fond 0.421 (moy. 0.452) : 6.34:1 (durée, « + »)
	["juke.now"] = { "inkSoft", 0.3300, 4.5, 12 },   -- sombre, fond 0.330 (moy. 0.453) : 6.08:1 (comme guide.text)
	["juke.hint"] = { "red", 0.3300, 4.5, 11 },   -- sombre, même fond : 4.89:1 (musique coupée)
	-- 3.0.1 : Addons liés, carte claire et parchemin voilé du guide (fond 0.325)
	["addons.name"] = { "ink", 0.3250, 4.5, 16 },   -- sombre, comme juke.name : 6.73:1
	["addons.text"] = { "inkSoft", 0.3250, 4.5, 12 },   -- sombre, même fond : ~6:1 (comme guide.text)
	["addons.muted"] = { "inkMuted", 0.3250, 4.5, 11 },   -- sombre, même fond : 5.04:1 (comme juke.missing)
	["addons.ok"] = { "green", 0.3250, 4.5, 11 },   -- sombre, même fond : ~4.8:1 (comme page.green)
	["addons.head"] = { "head", 0.3300, 4.5, 12 },   -- sombre, comme guide.head : 5.14:1
	["zone.label"] = { "navText", 0.0455, 4.5, 12 },   -- clair, fond 0.046 (moy. 0.016) : 7.41:1 (zone vue)
	["zone.unseen"] = { "zoneDim", 0.0455, 4.5, 12 },   -- clair, fond 0.046 (moy. 0.016) : 5.41:1 (zone pas encore vue, rangée opaque)
	-- 2.9.1 : page Missions en cartes. Cartes : fond 235397 en Cover sur 206×68 (demie) ou 420×68 (large),
	-- voile crème 0,40 ; pire des deux tailles par zone de texte (titre x 52, y 6-21 ; zone y 21-35 ; compte,
	-- 44 px de droite, y 37-52 ; gain en clair y 52-66). Faite : voile vert (ns.AZEROTH_MISSION.tint) en plus.
	["mcard.title"] = { "ink", 0.3929, 4.5, 12 },   -- sombre, fond 0.393 (moy. 0.445) : 7.94:1 (titre, et message d'un groupe vide)
	["mcard.zone"] = { "inkMuted", 0.3853, 4.5, 11 },   -- sombre, fond 0.385 (moy. 0.442) : 5.85:1
	["mcard.count"] = { "ink", 0.4146, 4.5, 12 },   -- sombre, fond 0.415 (moy. 0.441) : 8.33:1
	["mcard.reward"] = { "inkSoft", 0.4113, 4.5, 11 },   -- sombre, fond 0.411 (moy. 0.446) : 7.37:1 (gain en clair, carte large)
	["mcardDone.title"] = { "ink", 0.4200, 4.5, 12 },   -- sombre, fond 0.420 (moy. 0.466) : 8.43:1 (carte faite, voile vert ; titre sur deux lignes, y 6-35)
	["mcardDone.zone"] = { "inkMuted", 0.4200, 4.5, 11 },   -- sombre, fond 0.420 (moy. 0.466) : 6.32:1
	["mcardDone.count"] = { "ink", 0.4438, 4.5, 12 },   -- sombre, fond 0.444 (moy. 0.465) : 8.86:1
	["mcardDone.reward"] = { "inkSoft", 0.4411, 4.5, 11 },   -- sombre, fond 0.441 (moy. 0.469) : 7.85:1
	-- aplats unis (luminance exacte de la couleur du fond) : tampon « Faite », étiquettes des intertitres
	["mission.stamp"] = { "white", 0.0845, 4.5, 10 },   -- clair, fond uni #1f5e1f (ns.AZEROTH_MISSION.stamp) : 7.81:1
	["chip.zone"] = { "white", 0.0792, 4.5, 10 },   -- clair, fond uni #2a4f8a (chipZone : zone du jour, décompte) : 8.13:1
	["chip.trait"] = { "white", 0.0524, 4.5, 10 },   -- clair, fond uni #5a3a14 (chipTrait : caractère, 2.11.0) : 10.25:1
	-- bande résumé (2.11.0 : 230×56) : fond des catégories 130652 (découpe 167×29) étiré, opaque ; ligne 1
	-- x 44-222 y 5-20 (titre et compte), détail y 21-45 (deux lignes) ; pire = les 10 % les plus clairs
	["summary.label"] = { "goldHead", 0.0801, 4.5, 12 },   -- clair, fond 0.080 (moy. 0.033) : 5.82:1
	["summary.count"] = { "white", 0.0801, 4.5, 12 },   -- clair, fond 0.080 (moy. 0.033) : 8.07:1
	["summary.detail"] = { "light", 0.0288, 4.5, 11 },   -- clair, fond 0.029 (moy. 0.012) : 10.44:1
	-- encart des 3 : page 130661 (758×678, voile 0,35, ombre de gauche) sous un aplat crème
	-- (ns.AZEROTH_MISSION.callout, alpha 0,5), texte de x 74 à 436, y 350 à 620 (les deux encarts)
	["bonus.text"] = { "ink", 0.5371, 4.5, 11 },   -- sombre, fond 0.537 (moy. 0.573) : 10.53:1
	-- colonne de droite : tuiles « light » de 274 px de large (carte des auberges 140-176 de haut,
	-- garde-manger 114, besace 60-74) ; pire des tailles, marges de 6 px exclues
	["panel.text"] = { "ink", 0.3220, 4.5, 12 },   -- sombre, fond 0.322 (moy. 0.424) : 6.67:1 (comptes, tampons en tout)
	["panel.soft"] = { "inkSoft", 0.3220, 4.5, 11 },   -- sombre, fond 0.322 (moy. 0.424) : 5.95:1 (règle de la carte, nom des aides)
	["panel.muted"] = { "inkMuted", 0.3220, 4.5, 11 },   -- sombre, fond 0.322 (moy. 0.424) : 5.00:1 (cadeaux, jours aux trois missions, aide)
	-- compteur des pagers (« 1-9 / 60 ») sur la page : bas droit de la page (x 324-734, y 560-600), le plus sombre
	["pager.position"] = { "inkSoft", 0.3105, 4.5, 11 },   -- sombre, fond 0.311 (moy. 0.342) : 5.76:1
	-- 2.11.0 : mesures (scratchpad meas/b211.py : textures du client, mêmes découpes et voiles)
	-- B1 : plaques des chiffres de la page Compagnon, fond des catégories 167×29 étiré sur 135×58, opaque ;
	-- chiffre y 12-30, libellé y 33-46 (centrés ensemble)
	["stat.value"] = { "goldHead", 0.0193, 3.0, 16 },   -- clair, fond 0.019 (moy. 0.009) : 10.92:1
	["stat.label"] = { "statLabel", 0.0561, 4.5, 11 },   -- clair, fond 0.056 (moy. 0.015) : 6.58:1
	-- B4 : intertitres de la page Missions à l'encre sur le parchemin (plus de bande sombre) : mêmes encres
	-- et même fond que section.* (pire décile de toute la page)
	["mheader.label"] = { "head", 0.2935, 4.5, 10 },   -- sombre, fond 0.293 (moy. 0.376) : 4.65:1
	["mheader.detail"] = { "inkSoft", 0.2935, 4.5, 10 },   -- sombre, fond 0.293 (moy. 0.376) : 5.49:1
	-- fiche 08 : textes peints à la main, désormais rôles déclarés
	["plate.count"] = { "plateCount", 0.1053, 4.5, 12 },   -- clair, case des points 235402 (129×34), x 40-120 y 8-26 : 5.08:1
	["preview.title"] = { "white", 0.0517, 4.5, 12 },   -- clair, bande titleGrey 130667 (194×20) : 10.32:1
	["shield.count"] = { "white", 0.1405, 4.5, 12 },   -- clair, écu 130665 (60×44), centre 30×14 : 5.51:1
	["pantry.count"] = { "white", 0.0731, 4.5, 11 },   -- clair, ombre shade 0,75 sous le chiffre, pire icône blanche : 8.53:1
	["mark.giftGold"] = { "giftGold", 0.0710, 4.5, 11 },   -- clair, bande dorée 452109 + ombre shade 0,45 (x 10-102, y 24-50) : 7.77:1
	["mark.giftGrey"] = { "giftGrey", 0.0135, 4.5, 11 },   -- clair, bande grise 452109 + ombre shade 0,45 : 9.35:1
	-- fiche 13 : liste déroulante et recherche (Field : aplat uni 0.12/0.07/0.03)
	["field.text"] = { "fieldText", 0.0073, 4.5, 12 },   -- clair, fond uni : 14.04:1
	-- fiche 14 : colonne de gauche, blocs résumé : parchV 130662 (Cover 196×678, voile nav 0,45), bande
	-- y 230-450, x 12-184 ; pire = les 10 % les plus sombres
	["navSum.name"] = { "ink", 0.4479, 4.5, 12 },   -- sombre, fond 0.448 (moy. 0.478) : 8.93:1
	["navSum.label"] = { "inkSoft", 0.4479, 4.5, 11 },   -- sombre, fond 0.448 (moy. 0.478) : 7.96:1
	["navSum.value"] = { "inkSoft", 0.4479, 4.5, 11 },   -- sombre, fond 0.448 (moy. 0.478) : 7.96:1
	-- B8 : dialogue de confirmation au parchemin (130661 en Cover 420×260, voile page 0,35, ombre de gauche)
	["dialog.title"] = { "title", 0.2682, 3.0, 19 },   -- sombre, fond 0.268 (moy. 0.366) : 3.74:1
	["dialog.sub"] = { "inkSoft", 0.2682, 4.5, 11 },   -- sombre, fond 0.268 (moy. 0.366) : 5.09:1
	["dialog.text"] = { "ink", 0.2682, 4.5, 12 },   -- sombre, fond 0.268 (moy. 0.366) : 5.71:1
	-- 2.14.0 : panneau « Choisir son allure » (CompanionAllure.lua), habillé comme la confirmation
	-- (même parchemin 130661 en Cover, même voile page 0,35) : textes posés sur le parchemin au fond
	-- de dialog.* ; vignettes au fond des tuiles claires (235397 + voile light 0,40), celui de tile.*
	["allure.section"] = { "inkSoft", 0.2682, 4.5, 10 },   -- sombre, fond 0.268 (moy. 0.366) : 5.09:1 (intertitres)
	["allure.hint"] = { "inkSoft", 0.2682, 4.5, 10 },   -- sombre, même fond : 5.09:1 (« 12 sur 76 », position)
	["allure.text"] = { "ink", 0.2682, 4.5, 12 },   -- sombre, même fond : 5.71:1 (« Aucune apparence… »)
	["allure.name"] = { "ink", 0.3252, 4.5, 11 },   -- sombre, fond 0.325 (moy. 0.425) : 6.73:1 (nom d'une vignette)
	["allure.locked"] = { "inkMuted", 0.3252, 4.5, 11 },   -- sombre, même fond : 5.05:1 (mascotte pas encore gagnée)
	["allure.shiny"] = { "rShiny", 0.3252, 4.5, 11 },   -- sombre, même fond : 4.84:1 (version brillante)
	-- 2.14.0 (bêta 3) : carte de la scène de capture (ns:AzerothCreateCard, 340×418) : parchemin 130661 en
	-- Cover, voile page 0,35, sans ombre de gauche (scratchpad meas/card214.py). Ligne de chance x 80-260,
	-- y 320-334 ; nombres des aides x 125-250, y 349-363 ; pied x 16-324, y 393-406 (le bas, le plus sombre :
	-- inkSoft n'y tient que 4,47:1, d'où l'encre courante). Plaque : splate.* ; verdict : verdict.*
	["stage.chance"] = { "ink", 0.3665, 4.5, 12 },   -- sombre, fond 0.367 (moy. 0.399) : 7.47:1
	["stage.aidCount"] = { "inkSoft", 0.3210, 4.5, 11 },   -- sombre, fond 0.321 (moy. 0.359) : 5.93:1
	["stage.status"] = { "ink", 0.2297, 4.5, 11 },   -- sombre, fond 0.230 (moy. 0.254) : 5.02:1
	-- 2.15.0 : Réserve et Échoppe du dresseur (JournalReserve.lua). Mêmes surfaces que des rôles déjà
	-- mesurés : textes posés sur la page (parchemin 130661, voile page 0,35) au fond de page.* ; aide de
	-- la pagination au fond de pager.position (bas de page, le plus sombre) ; vignettes, fiche et lignes
	-- de l'échoppe : tuiles claires (235397 + voile light 0,40), au fond de tile.* (comme allure.*)
	["reserve.balance"] = { "amber", 0.3172, 4.5, 12 },   -- sombre, fond 0.317 (moy. 0.390) : 4.75:1 (solde de paillettes)
	["reserve.full"] = { "red", 0.3172, 4.5, 11 },   -- sombre, même fond : 4.73:1 (Réserve pleine)
	["reserve.text"] = { "inkSoft", 0.3172, 4.5, 12 },   -- sombre, même fond : 5.87:1 (page vide, note de l'échoppe)
	["reserve.hint"] = { "inkSoft", 0.3105, 4.5, 11 },   -- sombre, fond 0.311 (moy. 0.342) : 5.76:1 (aide sous la grille)
	["reserve.name"] = { "ink", 0.3252, 4.5, 11 },   -- sombre, fond 0.325 (moy. 0.425) : 6.73:1 (nom d'une vignette)
	["reserve.shiny"] = { "rShiny", 0.3252, 4.5, 11 },   -- sombre, même fond : 4.84:1 (spécimen brillant)
	["reserve.detail"] = { "inkSoft", 0.3252, 4.5, 11 },   -- sombre, même fond : 5.95:1 (lignes de la fiche)
	["reserve.better"] = { "green", 0.3252, 4.5, 11 },   -- sombre, même fond : 4.78:1 (« Meilleur que ton spécimen du Codex »)
	["reserve.reason"] = { "red", 0.3252, 4.5, 11 },   -- sombre, même fond : 4.83:1 (pourquoi on ne peut pas le relâcher)
	["reserve.confirm"] = { "ink", 0.3252, 4.5, 11 },   -- sombre, même fond : 6.73:1 (confirmation dans la fiche)
	["shop.name"] = { "ink", 0.3252, 4.5, 12 },   -- sombre, même fond : 6.73:1 (article)
	["shop.desc"] = { "inkMuted", 0.3252, 4.5, 11 },   -- sombre, même fond : 5.05:1 (effet, besace)
	["shop.price"] = { "amber", 0.3252, 4.5, 12 },   -- sombre, même fond : 4.85:1 (prix)
	["shop.short"] = { "red", 0.3252, 4.5, 12 },   -- sombre, même fond : 4.83:1 (prix hors de portée)
	-- 3.0.0 : vue « Échanges » de la Réserve (CaptureTrades.lua). Textes posés sur la page (parchemin
	-- 130661, voile page 0,35) au fond de page.* / reserve.text (0.3172) ; le « + » d'une place vide sur
	-- une tuile claire, au fond de tile.* (0.3252) ; vignettes : reserve.name / reserve.shiny
	["trade.status"] = { "ink", 0.3172, 4.5, 12 },   -- sombre, fond 0.317 : 6.57:1 (état de l'échange, titre de la grille)
	["trade.head"] = { "amber", 0.3172, 4.5, 12 },   -- sombre, même fond : 4.75:1 (« Toi » / nom, historique)
	["trade.state"] = { "inkSoft", 0.3172, 4.5, 11 },   -- sombre, même fond : 5.87:1 (« Pas encore validé »)
	["trade.ok"] = { "green", 0.3172, 4.5, 11 },   -- sombre, même fond : 4.68:1 (« Validé »)
	["trade.histName"] = { "ink", 0.3172, 4.5, 12 },   -- sombre, même fond : 6.57:1 (date, joueur)
	["trade.histText"] = { "inkSoft", 0.3172, 4.5, 11 },   -- sombre, même fond : 5.87:1 (donné, reçu)
	["trade.slot"] = { "inkMuted", 0.3252, 3.0, 16 },   -- sombre, tuile claire : 5.05:1 (« + » d'une place vide)
	-- 2.15.0 : tag « n à compléter » de la page Exploration (tuile claire, au fond de tile.*)
	["codex.todo"] = { "ink", 0.3252, 4.5, 11 },   -- sombre, même fond : 6.73:1
	["codex.done"] = { "green", 0.3252, 4.5, 11 },   -- sombre, même fond : 4.78:1 (« complète ★★★ »)
	-- 3.0.0 : composants harmonisés (docs/UI.md, « Composants 3.0 »)
	["button.off"] = { "buttonOff", 0.0756, 4.5, 12 },   -- clair, haut du dégradé « off » (le plus clair) : 4.84:1
	["currency.value"] = { "goldText", 0.0073, 4.5, 12 },   -- clair, aplat fieldBg de la pastille : 13.18:1 (solde)
	["currency.label"] = { "lightSoft", 0.0073, 4.5, 11 },   -- clair, même aplat : 12.18:1 (« paillettes »)
}
-- Luminance relative WCAG 2.x d'une couleur (0..1)
local function Lin(c) if c <= 0.03928 then return c / 12.92 end return ((c + 0.055) / 1.055) ^ 2.4 end
function ns.AzerothLuminance(c) return 0.2126 * Lin(c[1]) + 0.7152 * Lin(c[2]) + 0.0722 * Lin(c[3]) end
-- Contraste d'une encre sur un fond de luminance `bg`
function ns.AzerothContrast(c, bg)
	local a, b = ns.AzerothLuminance(c), tonumber(bg) or 0
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end
local INKS = ns.AZEROTH_INK
-- la bande claire des bandeaux (fond « alert ») et de la plaque « mini »
local INK = INKS.ink                      -- encre des bandes claires (2.8.2 : #1a0f05)

local FR = {
	OPT_UI_STYLE           = "Style de l'interface",
	OPT_UI_STYLE_DESC      = "Azeroth : cadre doré, boutons en relief et titres dans la police du jeu. Sobre : l'aspect d'avant, à plat. Les fenêtres déjà ouvertes prennent le nouveau style au prochain /reload.",
	UI_STYLE_azeroth       = "Azeroth (doré)",
	UI_STYLE_sobre         = "Sobre",
	UI_STYLE_MSG           = "Style de l'interface : %s. Tape /reload pour l'appliquer aux fenêtres déjà ouvertes.",
	UI_STYLE_USAGE         = "/qc style azeroth|sobre (actuel : %s)",
	HELP_STYLE             = "/qc style azeroth|sobre — style de toute l'interface (Azeroth : cadre doré ; Sobre : à plat)",
	CAPTURE_RESULT         = "Capturé !",
	CAPTURE_RESULT_SHINY   = "Brillant capturé !",
	CAPTURE_RESULT_MORE    = "et %d de plus",
	JRN_KIND_seal          = "Sceau de zone",
	JRN_KIND_rank          = "Titre de dresseur",
}
local EN = {
	OPT_UI_STYLE           = "Interface style",
	OPT_UI_STYLE_DESC      = "Azeroth: golden frame, bevelled buttons and titles in the game font. Plain: the previous flat look. Windows already open take the new style after the next /reload.",
	UI_STYLE_azeroth       = "Azeroth (golden)",
	UI_STYLE_sobre         = "Plain",
	UI_STYLE_MSG           = "Interface style: %s. Type /reload to apply it to windows already open.",
	UI_STYLE_USAGE         = "/qc style azeroth|sobre (current: %s)",
	HELP_STYLE             = "/qc style azeroth|sobre — style of the whole interface (Azeroth: golden frame; Plain: flat)",
	CAPTURE_RESULT         = "Captured!",
	CAPTURE_RESULT_SHINY   = "Shiny captured!",
	CAPTURE_RESULT_MORE    = "and %d more",
	JRN_KIND_seal          = "Zone seal",
	JRN_KIND_rank          = "Trainer title",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.AZEROTH_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({ companionStyle = ns.UI_STYLE_DEFAULT })

local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end
local function Method(obj, name, ...)
	local fn = obj and obj[name]
	if type(fn) ~= "function" then return false end
	return pcall(fn, obj, ...)
end
local function InCombat()
	if Call(G("InCombatLockdown")) then return true end
	return Call(G("UnitAffectingCombat"), "player") and true or false
end
local function Upper(text) return Theme.Upper and Theme.Upper(text) or text end
local function Clamp01(x) if x < 0 then return 0 elseif x > 1 then return 1 end return x end

-- ---------------------------------------------------------------------------
-- Le style : choix, textures du client, style effectif
-- ---------------------------------------------------------------------------
-- Les atlas sont-ils dans ce client ? Gardé tant que l'API ne change pas
-- (refresh : redemander)
local atlasCache, sceneCache = {}, {}
local function AtlasMissing(api, name)
	local done, info = pcall(api.GetAtlasInfo, name)
	if not done then return true end
	-- une fiche secrète : l'atlas existe (2.1.0 : écrit en clair, sans le
	-- repli « Plain(v) or v »)
	local isSecret = rawget(_G, "issecretvalue")
	if type(isSecret) == "function" then
		local ok, secret = pcall(isSecret, info)
		if ok and secret then return false end
	end
	return info == nil or info == false
end
function ns:AzerothAtlasOK(refresh)
	local api = G("C_Texture")
	if refresh then sceneCache.checked = nil end
	if not refresh and atlasCache.checked and atlasCache.api == api then return atlasCache.ok end
	local ok = type(api) == "table" and type(api.GetAtlasInfo) == "function"
	if ok then
		for _, key in ipairs(ns.AZEROTH_REQUIRED) do
			if AtlasMissing(api, AZ[key]) then ok = false; break end
		end
	end
	atlasCache.checked, atlasCache.api, atlasCache.ok = true, api, ok and true or false
	return atlasCache.ok
end

-- Les fenêtres de capture (2.5.1) demandent en plus le cadre en bois : s'il
-- manque, elles restent en Sobre (les bandeaux, eux, gardent Azeroth)
function ns:AzerothSceneAtlasOK(refresh)
	local api = G("C_Texture")
	if not refresh and sceneCache.checked and sceneCache.api == api then return sceneCache.ok end
	local ok = type(api) == "table" and type(api.GetAtlasInfo) == "function"
	if ok then
		for _, key in ipairs(ns.AZEROTH_SCENE_REQUIRED) do
			if AtlasMissing(api, AZ[key]) then ok = false; break end
		end
	end
	if ok then
		for _, key in ipairs(ns.AZEROTH_WOOD_KEYS) do
			if AtlasMissing(api, ns.AZEROTH_WOOD[key]) then ok = false; break end
		end
	end
	sceneCache.checked, sceneCache.api, sceneCache.ok = true, api, ok and true or false
	return sceneCache.ok
end

-- Le choix du joueur (réglage), valide
function ns:UIStyleChoice()
	local choice = self:DB().companionStyle
	for _, id in ipairs(ns.UI_STYLES) do if id == choice then return id end end
	return ns.UI_STYLE_DEFAULT
end

-- 3.1.0 (bascule vers le thème forgé) : le thème du socle est le choix du
-- joueur, rien d'autre : « azeroth » pose le thème forgé (nos textures,
-- toujours là), « sobre » le Sobre. ns:UISkinChoice (le socle le lit à
-- ADDON_LOADED) est redéfini ici. 3.1.2 : l'ancien habillage d'art du client
-- (carnet en parchemin, scènes en bois, bandeaux dorés, anneau) est retiré.
-- Pour décider d'une brique forgée : ns.QCForged() / Theme.Forged().
function ns:UISkinChoice() return self:UIStyleChoice() end

-- Le style des cadres construits (frame.uiStyle) : toujours « sobre » (les
-- briques forgées se décident par ns.QCForged)
function ns:UIStyle() return "sobre" end

-- La clé de cache d'un cadre construit (frame.styleKey) : « forge » s'il est
-- né sous le thème forgé, « sobre » sinon. Une brique forgée est décidée à
-- la création : un cadre né forgé n'est jamais resservi en Sobre, ni
-- l'inverse.
function ns:StyleKey()
	local Theme_ = ns.Theme
	if Theme_ and type(Theme_.Forged) == "function" and Theme_.Forged() then return "forge" end
	return "sobre"
end
-- La clé d'un cadre déjà construit
function ns.FrameStyleKey(frame)
	if not frame then return nil end
	return frame.styleKey or "sobre"
end
-- Marque un cadre qui vient d'être construit avec la clé du moment ; rend le cadre
function ns:MarkStyle(frame)
	if frame then frame.styleKey = self:StyleKey() end
	return frame
end
-- Le nom global d'une fenêtre par clé (Échap vise la bonne, celle de
-- l'autre clé restant en cache) : base + « Forge » / rien
function ns.StyleName(base, key)
	if key == "forge" then return base .. "Forge" end
	return base
end

function ns:UIStyleChoices()
	local list = {}
	for _, id in ipairs(ns.UI_STYLES) do list[#list + 1] = { value = id, label = L["UI_STYLE_" .. id] } end
	return list
end

-- Les bandeaux mis de côté au changement de style : cache[clé][style]
ns.uiStyleCache = ns.uiStyleCache or {}
local STYLED_FRAMES = { "captureToast", "guildFeatToast", "journalToast", "captureResult" }

-- Un cadre déjà construit pour la clé courante (ns:StyleKey, et retiré du
-- cache), ou nil
function ns:StyleCached(key)
	local slot = self.uiStyleCache[key]
	if not slot then return nil end
	local style = self:StyleKey()
	local frame = slot[style]
	slot[style] = nil
	return frame
end

-- Copie les textes d'un bandeau à l'autre (rhabillage d'un bandeau affiché)
local function CopyTexts(from, to)
	for _, field in ipairs({ "title", "text", "info", "hint", "stars" }) do
		local a, b = from[field], to[field]
		if a and b and a ~= b and a.GetText and b.SetText then b:SetText(a:GetText() or "") end
	end
end

-- Applique le style tout de suite : les bandeaux du mauvais style sont mis de
-- côté (et remplacés s'ils étaient affichés), le compagnon est rhabillé
function ns:ApplyUIStyle()
	local style = self:UIStyle()
	-- socle 3.2 : le thème des fenêtres d'abord (jetons, police des titres,
	-- habillage) : un bandeau reconstruit ci-dessous naît dans le bon thème.
	-- 3.1.0 : le thème suit le choix du joueur (ns:UISkinChoice), et les
	-- bandeaux sont comparés par clé (ns:StyleKey : ancien habillage, forgé,
	-- Sobre) : deux appels de suite gardent les mêmes cadres
	if Theme.ApplySkin then pcall(Theme.ApplySkin, self:UISkinChoice()) end
	local want = self:StyleKey()
	for _, key in ipairs(STYLED_FRAMES) do
		local frame = self[key]
		local have = ns.FrameStyleKey(frame)
		if frame and have ~= want then
			local shown = frame:IsShown()
			frame:Hide()
			self.uiStyleCache[key] = self.uiStyleCache[key] or {}
			self.uiStyleCache[key][have] = frame
			self[key] = nil
			if shown then
				if key == "captureToast" then
					local hideAt = self.captureToastHideAt
					if self.CaptureToastShow then self:CaptureToastShow() end
					self.captureToastHideAt = hideAt or self.captureToastHideAt
				elseif key == "captureResult" then
					-- « Capturé ! » remontré tel quel dans le nouveau thème
					-- (portrait, niveau, traits, Partager), sans allonger son temps
					local result = frame.result
					if result and self.CaptureResultShow then
						local hideAt = self.captureResultHideAt
						local ok, err = pcall(self.CaptureResultShow, self, result)
						if not ok and self.RecordError then self:RecordError("style:captureResult", err) end
						self.captureResultHideAt = hideAt or self.captureResultHideAt
					end
				else
					local ensure = (key == "guildFeatToast" and self.EnsureGuildFeatToast)
						or (key == "journalToast" and self.EnsureJournalToast) or nil
					local fresh = ensure and ensure(self)
					if fresh then
						CopyTexts(frame, fresh)
						-- 3.1.0 : un bandeau du carnet, dans les deux sens : icône,
						-- points, sous-ligne « Nouveau titre » (habillage de l'entrée),
						-- puis le bouton Partager, sans allonger son temps
						if key == "journalToast" then
							fresh.entry = frame.entry
							if ns.JournalToastDecor then pcall(ns.JournalToastDecor, fresh, frame.entry) end
							if self.ShareSync and self.ShareItemFromEntry then
								local hideAt = self.journalToastHideAt
								pcall(self.ShareSync, self, fresh, self:ShareItemFromEntry(frame.entry), "journal")
								self.journalToastHideAt = hideAt
							end
						end
						-- un exploit de guilde : le bandeau du nouveau thème reprend
						-- l'exploit affiché (lignes ancrées, médaillon, points)
						local shiny, gold = nil, key == "journalToast"
						if key == "guildFeatToast" and self.GuildFeatsRestyle then
							local ok, filled, info, feat = pcall(self.GuildFeatsRestyle, self, fresh)
							if ok and filled then shiny, gold = info.shiny, feat
							elseif not ok and self.RecordError then self:RecordError("style:guildFeatToast", filled) end
						end
						fresh:Show()
						self:StyleShown(fresh, { shiny = shiny, shield = gold and "gold" or nil })
					end
				end
			end
		end
	end
	if self.CompanionApplyUIStyle then self:CompanionApplyUIStyle() end
	return style
end

-- Choix du style (réglage, commande) ; nil si inconnu
function ns:SetUIStyle(id)
	id = type(id) == "string" and id:lower() or nil
	if id == "plain" then id = "sobre" end
	local valid = false
	for _, known in ipairs(ns.UI_STYLES) do if known == id then valid = true end end
	if not valid then return nil end
	self:DB().companionStyle = id
	self:ApplyUIStyle()
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return id
end

-- ---------------------------------------------------------------------------
-- Le bandeau Azeroth
-- ---------------------------------------------------------------------------
local function Atlas(tex, name)
	if not (tex and name) then return false end
	local ok, result = pcall(tex.SetAtlas, tex, name)
	return ok and result ~= false
end

-- Police des hauts faits ; refusée : la police du thème reste
local function AzFont(fs, size, flags)
	local ok, result = pcall(fs.SetFont, fs, ns.AZEROTH_FONT, size, flags or "")
	return ok and result ~= false
end

-- Largeur réelle du texte, sans la borne de la largeur posée
local function Measure(fs)
	local ok, w
	if fs.GetUnboundedStringWidth then ok, w = pcall(fs.GetUnboundedStringWidth, fs) end
	if not (ok and tonumber(w)) and fs.GetStringWidth then ok, w = pcall(fs.GetStringWidth, fs) end
	return (ok and tonumber(w)) or 0
end

-- Rapetisse la police jusqu'à ce que le texte tienne dans `width` ; au plus
-- petit, trop long quand même : la largeur fixe le coupe (points de
-- suspension du client). Rend la taille retenue et si le texte tient.
function ns.AzerothFit(fs, width, maxSize, minSize)
	if not fs then return nil end
	local size = maxSize
	while true do
		AzFont(fs, size)
		if Measure(fs) <= width or size <= minSize then break end
		size = size - 1
	end
	fs:SetWidth(width)
	if fs.SetWordWrap then fs:SetWordWrap(false) end
	fs.fitSize = size
	return size, Measure(fs) <= width
end

-- L'apparition : éclosion (0,6 → 1,05 → 1), lueur, reflet qui traverse le
-- bandeau, éclat sur le bouclier. Une horloge OnUpdate le temps de
-- l'animation (2,4 s), retirée ensuite ; rien d'alloué à chaque image.

-- Un atlas précis est-il dans ce client ? (gardé tant que l'API ne change pas)
local oneCache = {}
function ns.AzerothHasAtlas(name)
	local api = G("C_Texture")
	if oneCache.api ~= api then oneCache = { api = api } end
	if oneCache[name] == nil then
		oneCache[name] = type(api) == "table" and type(api.GetAtlasInfo) == "function" and not AtlasMissing(api, name)
	end
	return oneCache[name]
end

-- Après avoir rempli un bandeau : en Azeroth, couleur du nom (or pour une
-- brillante), nom ajusté, bouclier, apparition. En Sobre : rien.
-- opts : shiny, shield ("grey" | "gold"), play, bling, shine
-- 3.1.0 : un bandeau né sous le thème forgé (frame.forgeBanner,
-- ForgeBanners.lua) a son équivalent : nom, halo, apparition.
function ns:StyleShown(frame, opts)
	if frame and frame.forgeBanner and self.ForgeBannerShown then return self:ForgeBannerShown(frame, opts) end
	return false
end

ns.AZEROTH_COLORS = { ink = INK, shinyName = SHINY_NAME, star = INKS.star, flavour = { 0.85, 0.82, 0.75 },
	fled = { 0.8, 0.75, 0.66 }, caption = { 0.91, 0.77, 0.42 }, hint = { 0.61, 0.56, 0.47 } }
ns.AzerothAtlas = Atlas
-- Capitales sûres : seules les lettres a-z et les accents passent en
-- capitales (string.upper d'un client réglé autrement casserait « … »)
function ns.AzerothUpper(text)
	text = tostring(text or ""):gsub("[a-z]", string.upper)
	if Theme.Upper then text = text:gsub("[\195\197][\128-\191]", Theme.Upper) end
	return text
end


-- Le cadre d'icône des hauts faits avec, dedans, le portrait fixe d'une
-- créature : l'icône de son type (ns.MENAGERIE_TYPE_ICONS, Interface\Icons).
-- host:SetCreature(target) (nil : vide), host:SetLevel(n) écrit le niveau
-- dans le bouclier (host.shield). Le cadre d'icône passe au-dessus, dans un
-- cadre à lui. size : côté du cadre d'icône.
-- 2.9.0 : plus de modèle 3D. Le zoom « portrait » (SetPortraitZoom) vise le
-- point d'attache de la tête du modèle ; sur bien des créatures il manque ou
-- est mal placé, et le cadre montrait une patte. Le vrai portrait 2D du jeu
-- (SetPortraitTexture) demande une unité, qui n'existe plus après la mort.
-- L'icône du type, elle, s'affiche toujours, sans chargement ni caméra.
ns.AZEROTH_PORTRAIT_ICON = "Interface\\Icons\\Ability_Hunter_BeastTaming"
-- 2.8.2 : l'ouverture du cadre d'icône (ui-achievement-iconframe, 74×74 :
-- trou transparent de 17 à 57, mesuré sur la texture) et le centre visuel
-- de l'écu du bouclier (ui-achievement-shield-1, 63×56 : écu de 19 à 47 en
-- largeur, de 11 à 46 en hauteur, partie large en haut) : fractions du
-- bouclier, x vers la droite, y vers le haut ; les chiffres d'une police
-- sont hauts dans leur boîte (pas de jambage) : 1 px de moins

-- Le bouton doré des fenêtres de capture (dessiné : dégradé brun-or, liseré
-- d'or de 2 px, reflet clair en haut ; aucune texture de bouton du jeu).
-- kind : "gold" (principal) ou "dark" (secondaire, plus sombre). Champs
-- .text, .sub (ligne de dessous, button:SetSub) ; SetText/GetText.


-- ---------------------------------------------------------------------------
-- Le bandeau de résultat : « Capturé ! » / « Brillant capturé ! »
-- Montré quand la scène de capture se referme (lancer seul, sauf scène
-- Azeroth : elle a déjà son bandeau de verdict) ou quand la volée de « Tout
-- capturer » est fermée (la plus belle prise du lot) ; jamais
-- en combat (il attend la fin, CAPTURE_RESULT_STALE s au plus), rien en
-- sourdine ; CAPTURE_RESULT_SECONDS s d'affichage.
-- ---------------------------------------------------------------------------
function ns:EnsureCaptureResult()
	if self.captureResult then return self.captureResult end
	local cached = self:StyleCached("captureResult")
	if cached then self.captureResult = cached; return cached end
	-- 2.12.1 : le glyphe du filet est l'icône du jeu (ns.CapturePaintNetGlyph)
	local function Glyph(tex)
		if ns.CapturePaintNetGlyph then ns.CapturePaintNetGlyph(tex) else tex:SetTexture(Theme.LOGO_SMALL) end
	end
	local frame
	if not (Theme and Theme.CreateToast) then return nil end
	-- 3.1.0 : sous le thème forgé, le bandeau à médaillon (ForgeBanners.lua)
	if ns.QCForged and ns.QCForged() and self.ForgeCaptureResult then
		frame = self:ForgeCaptureResult(Glyph)
		if frame then
			self:MarkStyle(frame)
			if self.RestorePoint then self:RestorePoint(frame, "captureResultPoint", { point = "TOP", x = 0, y = -200 }) end
			frame:Hide()
			self.captureResult = frame
			return frame
		end
	end
	frame = Theme.CreateToast(UIParent, 300, 66, { strata = "HIGH", accent = Theme.GOLD, name = "QuestCompanionCaptureResult" })
	if not frame then return nil end
	frame.uiStyle = "sobre"
	local left = frame.contentLeft or 14
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	Glyph(frame.icon)
	frame.icon:SetSize(34, 34)
	frame.icon:SetPoint("LEFT", frame, "LEFT", left, 0)
	local textLeft, textW = left + 44, 300 - left - 44 - 12
	local function Line(font, color, y)
		local fs = Theme.Text(frame, font, color)
		fs:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, y)
		fs:SetWidth(textW)
		fs:SetJustifyH("LEFT")
		if fs.SetWordWrap then fs:SetWordWrap(false) end
		return fs
	end
	frame.title = Line(Theme.F_CAPS, Theme.MUTED_LIGHT, -9)
	frame.text = Line(Theme.F_TITLE, Theme.PARCHMENT, -23)
	frame.stars = Line(Theme.F_SMALL, Theme.GOLD, -44)
	self:MarkStyle(frame)
	if self.RestorePoint then self:RestorePoint(frame, "captureResultPoint", { point = "TOP", x = 0, y = -200 }) end
	frame:Hide()
	self.captureResult = frame
	return frame
end

-- Retient le résultat à montrer : { name, shiny, stars, more }
function ns:CaptureResultQueue(result)
	if type(result) ~= "table" or not result.name then return nil end
	result.at = Clock()
	self.captureResultPending = result
	return result
end

-- La scène (lancer seul ou volée) est-elle encore à l'écran ?
function ns:CaptureSceneBusy()
	local state = self.captureState
	if state and state.rolling then return true end
	local batch = self.captureBatchFrame
	if batch and batch:IsShown() then return true end
	local stage = self.captureStage
	return stage ~= nil and stage:IsShown() and stage.rolling ~= nil
end

function ns:CaptureResultShow(result)
	local frame = self:EnsureCaptureResult()
	if not frame then return nil end
	frame.title:SetText(Upper(result.shiny and L.CAPTURE_RESULT_SHINY or L.CAPTURE_RESULT))
	frame.text:SetText(result.name)
	local line = (result.stars and self.CaptureStarsText) and self:CaptureStarsText(result.stars, 14) or ""
	if (tonumber(result.more) or 0) > 0 then
		local more = self:F("CAPTURE_RESULT_MORE", result.more)
		line = line ~= "" and (line .. "  ·  " .. more) or more
	end
	frame.stars:SetText(line)
	-- 3.1.0 (thème forgé) : portrait et niveau dans le médaillon, taille et
	-- caractère du spécimen sur la ligne des étoiles (ForgeBanners.lua)
	if frame.forgeBanner and self.ForgeCaptureResultFill then self:ForgeCaptureResultFill(frame, result, line) end
	if not frame.forgeBanner then
		local c = result.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or Theme.PARCHMENT
		frame.text:SetTextColor(c[1], c[2], c[3])
		if frame.SetAccent then frame:SetAccent(result.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or Theme.GOLD) end
	end
	frame.result = result
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame, 0.2) end
	self:StyleShown(frame, { shiny = result.shiny, shield = "gold", play = true, bling = true, shine = result.shiny })
	-- 2.8.0 (Azeroth) : la tête de la créature dans le cadre d'icône, son niveau dans le bouclier
	self.captureResultHideAt = Clock() + ns.CAPTURE_RESULT_SECONDS
	if self.BannerShown then self:BannerShown("result", frame, "captureResultPoint", { point = "TOP", x = 0, y = -200 }) end
	return frame
end

function ns:CaptureResultHide()
	self.captureResultHideAt = nil
	if self.captureResult then self.captureResult:Hide() end
	if self.BannerDone then self:BannerDone("result") end
end

-- Horloge (celle de la capture, 10 fois par seconde)
function ns:CaptureResultTick(now)
	now = now or Clock()
	if self.captureResultHideAt and (now >= self.captureResultHideAt or InCombat()) then self:CaptureResultHide() end
	local pending = self.captureResultPending
	if not pending then return false end
	if self.CaptureMuted and self:CaptureMuted() then self.captureResultPending = nil; return false end
	-- la scène est encore là : l'attente ne compte pas
	if self:CaptureSceneBusy() then pending.at = now; return false end
	if now - (pending.at or now) > ns.CAPTURE_RESULT_STALE then self.captureResultPending = nil; return false end
	if InCombat() then return false end
	-- 3.0.1 : passe devant la file des bandeaux, sans couvrir celui affiché
	if self.BannerTurn and not self:BannerTurn("result") then return false end
	self.captureResultPending = nil
	return self:CaptureResultShow(pending) ~= nil
end

-- Lancer seul : le verdict retenu, montré quand la scène se referme. Sauf
-- si la scène elle-même l'affiche déjà (2.5.1 : la scène Azeroth a son
-- bandeau « Capturé ! », bouclier et éclat compris) : pas de doublon. La
-- scène refermée avant le verdict (Échap) : le bandeau, pour ne rien rater.
local function SceneShowsVerdict(self, rolling)
	if not rolling.sceneVerdict then return false end
	local stage = self.captureStage
	return stage ~= nil and stage:IsShown() and stage.rolling == rolling
end
do
	local base = ns.CaptureResolve
	if base then
		function ns:CaptureResolve(rolling, ...)
			local target = rolling and rolling.target
			-- 3.1.0 : espèce nouvelle ? (avant que la capture ne l'inscrive ; Share.lua)
			local fresh = target and target.npcID ~= nil and not self:CaptureIsCaptured(target.npcID) or nil
			local result = base(self, rolling, ...)
			if target and rolling.success and not rolling.batch and not self.captureBatchResolving then
				-- 3.1.0 : de quoi partager ce verdict (Share.lua : rang, espèce nouvelle, spécimen)
				local shown = { name = target.name, shiny = target.shiny and true or false, stars = rolling.stars,
					npcID = target.npcID, level = target.level, type = target.type, class = target.class,
					fresh = fresh, specimen = rolling.specimen,
					-- l'apparence lue sur la créature vivante : le portrait du bandeau est le sien
					liveDisplay = target.liveDisplay }
				rolling.shareResult = shown
				if SceneShowsVerdict(self, rolling) then
					if self.ShareStageVerdict then pcall(self.ShareStageVerdict, self, rolling, shown) end
				-- (3.1.0 : une prise express ordinaire a sa pastille, pas de bandeau : rolling.quiet)
				elseif not rolling.quiet then
					self:CaptureResultQueue(shown)
				end
			end
			return result
		end
	end
end

-- Tout capturer : la plus belle prise du lot, montrée quand la volée est fermée
do
	local base = ns.CaptureBatchFlush
	if base then
		function ns:CaptureBatchFlush(batch, ...)
			if batch and not batch.flushed then
				local strength = ns.CaptureBatchStrength
				local best, got = nil, 0
				for _, result in ipairs(batch.results or {}) do
					if result.success then
						got = got + 1
						if not best or (strength and strength(result) > strength(best)) then best = result end
					end
				end
				if best then
					self:CaptureResultQueue({ name = best.target.name, shiny = best.target.shiny and true or false,
						stars = best.stars, more = got - 1, npcID = best.target.npcID, level = best.target.level,
						type = best.target.type, class = best.target.class, fresh = best.fresh, specimen = best.specimen,
						liveDisplay = best.target.liveDisplay })
				end
			end
			return base(self, batch, ...)
		end
	end
end

do
	local base = ns.CaptureTick
	if base then
		function ns:CaptureTick(now, ...)
			local a, b = base(self, now, ...)
			local ok, err = pcall(self.CaptureResultTick, self, now)
			if not ok and self.RecordError then self:RecordError("capture:result", err) end
			return a, b
		end
	end
end

-- ---------------------------------------------------------------------------
-- Sceaux de zone et titres de dresseur : un bandeau aussi (file du carnet)
-- ---------------------------------------------------------------------------
do
	local label = ns.JournalKindLabel
	if label then
		function ns:JournalKindLabel(kind)
			if kind == "seal" or kind == "rank" then return L["JRN_KIND_" .. kind] end
			return label(self, kind)
		end
	end
	local seal = ns.MenagerieSealCheck
	if seal then
		function ns:MenagerieSealCheck(zoneID, opts, ...)
			local sealed = seal(self, zoneID, opts, ...)
			if sealed and not (type(opts) == "table" and opts.quiet) and self.JournalToastPush then
				local info = self.MapInfo and self:MapInfo(tonumber(zoneID) or zoneID)
				self:JournalToastPush({ kind = "seal", name = (info and info.name) or tostring(zoneID) })
			end
			return sealed
		end
	end
	local rank = ns.MenagerieRankCheck
	if rank then
		function ns:MenagerieRankCheck(opts, ...)
			local gained = rank(self, opts, ...)
			if type(gained) == "table" and #gained > 0 and not (type(opts) == "table" and opts.quiet) and self.JournalToastPush then
				local best = gained[#gained]
				-- 2.7 : le bandeau du haut fait men_species_<n> le remplace
				if self.FeatLegacyHandled and self:FeatLegacyHandled("men_species_" .. tostring(best.count)) then return gained end
				self:JournalToastPush({ kind = "rank", name = L["TRAINER_" .. tostring(best.key)] or tostring(best.count) })
			end
			return gained
		end
	end
end

-- ---------------------------------------------------------------------------
-- Le cadre du compagnon : cadre rond à volutes autour du portrait, plaque
-- dorée sous le nom. Même taille de cadre (taille, cadrage, filet, survol
-- inchangés) ; le fond gagné est arrondi par un masque si le client en a.
-- ---------------------------------------------------------------------------
local RING_W, RING_H, RING_Y = 108, 104, -45   -- centre du portrait (modèle de 82 px sous 4 px)
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
ns.AZEROTH_RING = { w = RING_W, h = RING_H, y = RING_Y }

-- La plaque « mini » : bande claire en haut (~30 %), bande sombre dessous.
-- Le nom (blanc) au milieu de la bande sombre, l'humeur (brune) dans la claire.
local PLATE_H = 42
-- 2.8.2 : l'ouverture du cadre (ui-achievement-guild-iconframe, 78×75 dans
-- l'atlas : le trou transparent va de 16 à 58 en largeur, de 17 à 57 en
-- hauteur, mesuré sur la texture du client). Le modèle 3D y est posé, à 1 px
-- du bord : avant, il gardait le rectangle Sobre (96×82), plus large que
-- l'ouverture, et la créature débordait sous les volutes et à côté.
ns.AZEROTH_RING_HOLE = { l = 16 / 78, r = 58 / 78, t = 17 / 75, b = 57 / 75 }
-- 2.13.1 : l'ouverture n'est pas au milieu de la texture (16 px à gauche,
-- 20 à droite) : centré sur sa texture, le cadre paraissait décalé de ~3 px
-- vers la gauche par rapport à la plaque du nom. On centre l'ouverture.
local RING_X = math.floor(RING_W * (0.5 - (ns.AZEROTH_RING_HOLE.l + ns.AZEROTH_RING_HOLE.r) / 2) + 0.5)
ns.AZEROTH_RING.x = RING_X

-- ---------------------------------------------------------------------------
-- 3.1.0 : le médaillon forgé. Sous le thème forgé (l'ancien habillage coupé),
-- le compagnon garde la géométrie de la maquette validée : anneau rond
-- centré sur le portrait, plaque du nom dessous, étiquette d'humeur glissée
-- sous la plaque ; en NOS matières (Theme.ART.ring, Theme.Slice "plate").
-- Même centre (RING_Y) et même emprise que l'anneau du client : le filet et
-- les pastilles ne bougent pas. Un seul prédicat décide de la branche
-- « anneau » : ns:CompanionRingOn() ; frame.ring dit celle qui est posée
-- ("azeroth" : l'ancien habillage, "forge" : le médaillon forgé, nil : le
-- cadre carré du Sobre). Habillage dans ForgeCompanion.lua.
-- ---------------------------------------------------------------------------
-- w, h : l'anneau ; model : côté du portrait 3D (ses coins sous la bande
-- d'or) ; disc : le fond gagné, en disque sous la bande (masque) ; square :
-- son repli sans masque (carré dont les coins restent sous la bande)
ns.FORGE_RING = { w = 104, h = 104, x = 0, y = RING_Y, model = 64, disc = 88, square = 64 }
-- Effets du médaillon forgé quand l'atlas du client manque (repli en
-- matières forgées) : halo du cadre gagné (× w), éclats (px), poussière
-- (trois points par grappe : x, y, taille), filets du titre (hauteur),
-- ligne de lumière (hauteur), reflet de la bulle (épaisseur)
-- (le point lumineux n'a qu'un halo court : sa taille est celle où le bord
-- de l'anneau tombe dans le halo, son cœur restant sous le portrait)
ns.FORGE_FX = {
	haloSize = 2.4, glowSize = 3.2, sparkSize = 22, rule = 6, lineH = 8, sheenW = 34, sheenAlpha = 0.65,
	dust = { { -14, 4, 7 }, { 4, -6, 9 }, { 16, 8, 6 } }, cloudAlpha = 0.55,
	-- la lueur de « Niveau N ! » : niveau au-dessus du cadre (sous l'habit, + 4)
	glowBelow = 3,
}

-- La branche « anneau » : le thème forgé (le médaillon)
function ns:CompanionRingOn()
	return ns.QCForged() and true or false
end
-- Le cadre porte-t-il un anneau (le médaillon forgé) ?
function ns.CompanionRinged(frame) return frame ~= nil and frame.ring ~= nil end
-- L'habit de l'anneau posé (nil : le cadre carré)
function ns.CompanionRingSkin(frame)
	if not frame then return nil end
	if frame.ring == "forge" then return frame.forgeSkin end
	return nil
end
-- La géométrie de l'anneau posé (celle du client par défaut)
function ns.CompanionRingGeometry(frame)
	if frame and frame.ring == "forge" then return ns.FORGE_RING end
	return ns.AZEROTH_RING
end

-- Place du portrait dans le médaillon forgé (depuis le coin haut gauche)
function ns.ForgeCompanionModelBase(frameW)
	local F = ns.FORGE_RING
	local side = F.model
	local x0 = math.floor((frameW or 104) / 2 + F.x - side / 2 + 0.5)
	local y0 = math.floor(F.y + side / 2 + 0.5)
	return { x = x0, y = y0, w = side, h = side }
end

-- skin : l'habit dont le masque arrondit le fond
local function Masked(frame, on, skin)
	local mask = skin and skin.mask
	if not mask then return false end
	local regions = { frame.bg }
	for _, star in ipairs(frame.stars or {}) do regions[#regions + 1] = star end
	for _, region in ipairs(regions) do
		if region then
			-- 3.1.0 : le masque de l'autre habit (bascule à chaud) est d'abord ôté
			if on and region.azMasked and region.azMask and region.azMask ~= mask then
				Method(region, "RemoveMaskTexture", region.azMask)
				region.azMasked, region.azMask = nil, nil
			end
			if on and not region.azMasked then
				if Method(region, "AddMaskTexture", mask) then region.azMasked, region.azMask = true, mask end
			elseif not on and region.azMasked then
				Method(region, "RemoveMaskTexture", region.azMask or mask)
				region.azMasked, region.azMask = nil, nil
			end
		end
	end
	return on
end

local function EdgesShown(frame, shown)
	for _, edge in ipairs({ frame.top, frame.bottom, frame.leftEdge, frame.rightEdge }) do
		if edge then if shown then edge:Show() else edge:Hide() end end
	end
	if not shown then
		if frame.styleBorder then frame.styleBorder:Hide() end
		if frame.styleInnerHolder then frame.styleInnerHolder:Hide() end
	end
end

-- 2.13.1 : teinte du rabat et encre du mot selon l'humeur ; largeur au mot
function ns:CompanionApplyMoodTab()
	local frame = self.companionFrame
	-- 3.1.0 : le médaillon forgé a son étiquette (ForgeCompanion.lua)
	if frame and frame.ring == "forge" then
		return self.CompanionForgeMoodTab and self:CompanionForgeMoodTab() or nil
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- 2.14.0 (bêta 7) : le cadre gagné colore l'anneau. En Azeroth, la bordure
-- du cadre choisi (Sobre) est cachée sous l'anneau doré
-- (ui-achievement-guild-iconframe) : choisir « Ardoise », « Cuivre » ou
-- « Givre » ne changeait rien à l'écran (35 à 38.png). Chaque cadre donne
-- désormais sa teinte à l'anneau (couleur de sommet sur l'or ; désaturé
-- d'abord pour l'argent, l'ardoise, le bleu, le vert), dans la palette de
-- sa bordure Sobre ; `glow` : un halo du client en fusion additive autour
-- de l'anneau, teinté (Givre : glacé ; Étincelant : doré). Absent de la
-- table : l'or d'origine (Ardoise, le cadre par défaut de tous ; Insigne du
-- dresseur, déjà doré). Sceaux de biome : désaturés, à la couleur de leur
-- filet. La même teinte pour le grand portrait de la page Créature.
-- ---------------------------------------------------------------------------
ns.AZEROTH_RING_TINTS = {
	-- 2.14.1 : Ardoise (le cadre de départ) en gris ardoise, Étincelant plus
	-- clair : hors Givre, les trois premiers cadres se ressemblaient (tous or)
	slate      = { 0.66, 0.70, 0.78, desat = true },           -- Ardoise : gris ardoise
	sparkle    = { 1.0, 0.95, 0.72, glow = { 1.0, 0.84, 0.40 } }, -- Étincelant : or clair, halo doré
	-- 3.0.0 : le cadre de l'Échoppe du dresseur (paillettes)
	shop_glitter = { 1.0, 0.86, 0.94, glow = { 1.0, 0.80, 0.95 } }, -- Cadre pailleté : or rosé, halo pailleté
	master     = { 1.0, 0.84, 0.52 },                          -- Insigne du maître : or soutenu
	copper     = { 1.0, 0.60, 0.40 },                          -- Cuivre
	oak        = { 0.76, 0.54, 0.32, desat = true },           -- Chêne : brun chaud
	silver     = { 0.90, 0.92, 0.96, desat = true },           -- Argent
	frost      = { 0.78, 0.88, 1.0, desat = true, glow = { 0.75, 0.90, 1.0 } }, -- Givre : argent-bleu, halo glacé
	rune       = { 0.62, 0.58, 1.0, desat = true },            -- Runique : bleu-violet
	fel        = { 0.52, 1.0, 0.32, desat = true },            -- Gangrené : vert gangrène
	gilded     = { 1.0, 0.80, 0.45 },                          -- Or ciselé : or riche
	stone      = { 0.70, 0.70, 0.74, desat = true },           -- Pierre
	toast      = { 0.60, 0.76, 1.0, desat = true },            -- Messager : bleu
	glue       = { 0.96, 0.86, 0.68 },                         -- Portail : or pâle
	carved     = { 0.88, 0.70, 0.50 },                         -- Sculpté : bois doré
	feat_eight = { 1.0, 0.80, 0.45 },                          -- Huit familles : or riche (icônes autour)
	feat_prism = { 1.0, 1.0, 1.0, desat = true },              -- Prismatique : nacre (halo arc-en-ciel)
}
-- 3.1.0 : la même palette, recalibrée pour NOTRE anneau (anneau.tga :
-- bande d'or moyenne ≈ (207, 164, 98), mesurée sur la texture). Calibrées
-- sur l'or plus sombre du client, les teintes chaudes multipliées sur notre
-- or tournaient à l'orange vif (Cuivre : teinte 20°, saturation 0,81 ; Or
-- ciselé et Insigne du maître pareils, sans différence avec le Cuivre). Ici :
-- le Cuivre désaturé puis teinté (saturation ≈ 0,6), les ors
-- à peine teintés (plus soutenus que l'or d'origine, sans virer à l'orange),
-- bois et portail adoucis. Absent de cette table : la teinte ci-dessus.
-- Saturation ≤ 0,7 et écart à l'or contrôlés (tests/modules/companion_forge.lua).
ns.FORGE_RING_GOLD = { 207 / 255, 164 / 255, 98 / 255 }
ns.AZEROTH_RING_TINTS_FORGE = {
	copper     = { 1.0, 0.64, 0.42, desat = true },            -- Cuivre : cuivre (teinte 23°, saturation 0,58)
	master     = { 1.0, 0.92, 0.78 },                          -- Insigne du maître : or soutenu
	gilded     = { 1.0, 0.88, 0.70 },                          -- Or ciselé : or riche
	feat_eight = { 1.0, 0.88, 0.70 },                          -- Huit familles : or riche
	carved     = { 0.92, 0.72, 0.50, desat = true },           -- Sculpté : bois doré
	glue       = { 1.0, 0.95, 0.85 },                          -- Portail : or pâle
}
-- le halo (fond noir : fusion ADD) ; le premier atlas présent du client
-- (vérifié en jeu le 10/11 : l'anneau de glace des reliques)
ns.AZEROTH_RING_GLOW = { atlases = { "Relic-Frost-TraitGlowRing" }, size = 138, alpha = 0.8 }

-- L'allure de l'anneau pour un cadre (`def`, sinon le cadre porté) :
-- { r, g, b, desat, glow } ou nil (l'or d'origine), et l'id du cadre
-- forge : l'allure sur notre anneau (ns.AZEROTH_RING_TINTS_FORGE d'abord)
function ns:AzerothRingLook(def, forge)
	def = def or (self.CompanionCurrentStyle and self:CompanionCurrentStyle("frame"))
	local id = def and def.id
	if not id then return nil, nil end
	local look = (forge and ns.AZEROTH_RING_TINTS_FORGE[id]) or ns.AZEROTH_RING_TINTS[id]
	if not look and type(id) == "string" and id:find("^seal_") and type(def.edge) == "table" then
		look = { def.edge[1], def.edge[2], def.edge[3], desat = true }
	end
	return look, id
end

-- Teinte (et désaturation) d'une texture de l'anneau ; sans allure : l'or
function ns.AzerothPaintRing(tex, look)
	if not tex then return nil end
	local desat = (look and look.desat) and true or false
	if tex.SetDesaturated then pcall(tex.SetDesaturated, tex, desat) end
	tex.azDesat = desat
	local r, g, b = 1, 1, 1
	if look and look[1] then r, g, b = look[1], look[2], look[3] end
	tex:SetVertexColor(r, g, b, 1)
	return desat
end

-- Le halo autour de l'anneau : sur un cadre enfant de l'habit (caché avec
-- lui, mode voyage compris), au niveau du cadre, sous le modèle (+ 1)
-- 3.1.0 : un halo par habit (skin.ringGlow ; frame.azRingGlow : celui de
-- l'anneau du client, lu par les tests). Médaillon forgé sans l'atlas du
-- client : notre point lumineux (Theme.ART.dot), sous le cadre (le fond du
-- portrait le couvre au centre), jamais « pas de halo ».
local function RingGlow(frame, skin)
	local forge = skin == frame.forgeSkin and skin ~= nil
	local cached
	if forge then cached = skin.ringGlow else cached = frame.azRingGlow end
	if cached ~= nil then return cached or nil end
	local G = ns.AZEROTH_RING_GLOW
	local holder = CreateFrame("Frame", nil, skin)
	holder:SetAllPoints(frame)
	holder:SetFrameLevel(frame:GetFrameLevel() or 1)
	holder:EnableMouse(false)
	local tex = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
	local placed
	for _, name in ipairs(G.atlases) do
		if ns.AzerothHasAtlas(name) and Atlas(tex, name) then placed = name; break end
	end
	local size = G.size
	if not placed and forge and Theme.ART and Theme.ART.dot then
		tex:SetTexture(Theme.ART.dot.file)
		holder:SetFrameLevel(math.max(0, (frame:GetFrameLevel() or 1) - 1))
		placed, size = "forge", math.floor(ns.FORGE_RING.w * ns.FORGE_FX.haloSize + 0.5)
	end
	if not placed then
		tex:Hide()
		holder:Hide()
		frame.azRingGlow = false
		return nil
	end
	if tex.SetBlendMode then pcall(tex.SetBlendMode, tex, "ADD") end
	tex:SetSize(size, size)
	tex:SetPoint("CENTER", frame, "TOP", 0, RING_Y)
	tex:SetAlpha(G.alpha)
	tex.azAtlas = placed
	tex.holder = holder
	tex:Hide()
	if forge then skin.ringGlow = tex else frame.azRingGlow = tex end
	return tex
end

-- L'anneau du compagnon à l'allure du cadre porté (Azeroth, médaillon
-- forgé) ; rend l'id du cadre dont l'allure est posée (nil : l'or d'origine)
function ns:CompanionPaintRing()
	local frame = self.companionFrame
	local skin = ns.CompanionRingSkin(frame)
	if not (skin and skin.ring) then return nil end
	local look, id
	if frame.ring ~= nil then look, id = self:AzerothRingLook(nil, frame.ring == "forge") end
	ns.AzerothPaintRing(skin.ring, look)
	skin.ring.azLook = look and id or nil
	-- le halo de l'autre habit (bascule à chaud) s'éteint
	local other = (skin == frame.forgeSkin) and frame.azRingGlow or (frame.forgeSkin and frame.forgeSkin.ringGlow)
	if other then other:Hide() end
	local glow = look and look.glow
	local tex = glow and RingGlow(frame, skin) or ((skin == frame.forgeSkin) and skin.ringGlow or frame.azRingGlow) or nil
	if tex then
		if glow then
			tex:SetVertexColor(glow[1], glow[2], glow[3], 1)
			tex.holder:Show()
			tex:Show()
		else
			tex:Hide()
		end
	end
	return skin.ring.azLook
end

-- Le grand portrait de la page Créature (même anneau, étiré au carré)
-- 3.1.0 : ou l'anneau forgé du carnet forgé (frame.evo.forgeRing, notre
-- anneau.tga : la palette recalibrée pour lui)
function ns:CarnetPaintRing(frame)
	frame = frame or self.journalFrame
	local evo = frame and frame.evo
	local vine = evo and (evo.azVine or evo.forgeRing)
	if not vine then return nil end
	local look, id = self:AzerothRingLook(nil, vine == evo.forgeRing)
	ns.AzerothPaintRing(vine, look)
	vine.azLook = look and id or nil
	return vine.azLook
end

function ns:CompanionApplyUIStyle()
	local frame = self.companionFrame
	if not frame then return nil end
	-- 3.1.0 : le thème forgé : le médaillon forgé
	local forge = self:CompanionRingOn() and self.CompanionApplyForgeSkin ~= nil
	if not forge and frame.ring == "forge" and self.CompanionLeaveForgeSkin then
		-- (quitte le médaillon forgé : son habit caché, son fond libéré)
		self:CompanionLeaveForgeSkin(frame)
	end
	if forge then
		self:CompanionApplyForgeSkin(frame)
	elseif frame.ring ~= nil then
		frame.modelBase = ns.COMPANION_MODEL_BASE
		if frame.model and self.CompanionPlaceModel then self:CompanionPlaceModel(frame.fxOffset and frame.fxOffset[1], frame.fxOffset and frame.fxOffset[2]) end
		for _, fs in ipairs({ frame.name, frame.mood }) do
			if fs and fs.SetParent then fs:SetParent(frame) end
		end
		-- les places du style Sobre (Companion.lua)
		if frame.name then
			frame.name:ClearAllPoints(); frame.name:SetPoint("BOTTOM", frame, "BOTTOM", 0, 19)
			frame.name:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3], 1)
		end
		if frame.mood then
			if frame.mood.SetParent then frame.mood:SetParent(frame) end
			frame.mood:ClearAllPoints(); frame.mood:SetPoint("BOTTOM", frame, "BOTTOM", 0, 6)
		end
		-- 2.11.0 : humeur au gris clair du texte (≥ 4,5:1 sur la plaque 80 % mesurée par l'agent du compagnon)
		if frame.mood then frame.mood:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3], 1) end
		if frame.mood then Theme.TextShadow(frame.mood, 0.6) end
		EdgesShown(frame, true)
	end
	frame.uiStyle = "sobre"
	-- 3.1.0 : l'anneau posé (ns.CompanionRinged : les effets, le décor, les
	-- cosmétiques du cadre le lisent)
	frame.ring = forge and "forge" or nil
	-- 3.1.0 : rhabillé sur place (pas de cache) ; sa clé dit sous quel thème
	-- il a été habillé la dernière fois
	frame.styleKey = self:StyleKey()
	-- le cadre gagné (bordure du client) revient en Sobre
	if not forge and self.CompanionApplyFrame then self:CompanionApplyFrame() end
	-- 2.14.0 (bêta 7) : la teinte du cadre sur l'anneau
	self:CompanionPaintRing()
	return frame.uiStyle
end

-- 3.1.0 : les pièces du cadre partagées avec le médaillon forgé
-- (ForgeCompanion.lua) ; pas une API
ns.AzerothCompanionKit = { Masked = Masked, EdgesShown = EdgesShown, Measure = Measure, PLATE_H = PLATE_H,
	MOOD_TAB_H = MOOD_TAB_H, MOOD_TAB_TUCK = MOOD_TAB_TUCK, MASK = MASK }

do
	local ensure = ns.EnsureCompanionFrame
	if ensure then
		function ns:EnsureCompanionFrame(...)
			local fresh = not self.companionFrame
			local frame = ensure(self, ...)
			if frame and fresh then self:CompanionApplyUIStyle() end
			return frame
		end
	end
	-- le cadre gagné ne réapparaît pas par-dessus l'anneau
	local apply = ns.CompanionApplyFrame
	if apply then
		function ns:CompanionApplyFrame(...)
			local a, b = apply(self, ...)
			local frame = self.companionFrame
			if frame and frame.ring ~= nil then EdgesShown(frame, false) end
			-- 2.14.0 (bêta 7) : le cadre choisi colore l'anneau (cadre et carnet)
			pcall(self.CompanionPaintRing, self)
			pcall(self.CarnetPaintRing, self)
			return a, b
		end
	end
end

-- ===========================================================================
-- Effets Azeroth (2.7.0) : bulle façon « Talking Head », lueur ronde quand
-- le compagnon parle, éclats d'étoile pour une brillante, montée de niveau
-- et évolution (volutes, ligne de lumière, poussière dorée), ailes et éclat
-- des grandes récompenses (ns:AzerothRewardFX). Style Azeroth seulement :
-- le style Sobre ne change pas. Chaque effet demande ses atlas au client
-- (ns.AzerothHasAtlas) ; s'il en manque un, l'effet (ou sa pièce) est sauté
-- sans bruit. Rien ne prend la souris ; tout est créé à la demande et
-- réutilisé ; une seule horloge (OnUpdate posée le temps des effets,
-- retirée ensuite), la lueur suit celle du liseré (Notify.lua).
-- ===========================================================================
ns.AZEROTH_FX_ATLAS = {
	talk      = "TalkingHeads-TextBackground",   -- parchemin des « Talking Heads » (570×155)
	talkSheen = "TalkingHeads-Glow-TextSheen",
	circle    = "BonusChest-CircleGlow",         -- lueur ronde blanche (teintée d'or)
	circleAlt = "garrlanding-circleglow",
	star      = "OBJFX_StarBurst",
	iconGlow  = "AftLevelup-IconGlow",
	line      = "AftLevelup-GlowLine",
	dots1     = "AftLevelup-Dots1",
	dots2     = "AftLevelup-Dots2",
	filigree  = "AftLevelup-FiligreeLeft",       -- la droite : la même, retournée
	cloud     = "AftLevelup-SoftCloud",
	wings     = "titleprestige-wings",           -- l'aile gauche ; la droite, retournée
	burst     = "BonusChest-Burst-Uncommon",
}
local FXA = ns.AZEROTH_FX_ATLAS
-- durées (s) et géométrie (maquette validée, docs/TECHNIQUE.md)
ns.AZEROTH_FX = {
	glowPeriod = 2.2, glowShinyPeriod = 1.2, glowSize = 1.45, glowFade = 0.4,
	shinyTime = 4, sparkPeriod = 1.8, sparkSize = 30,
	levelTime = 3.2, levelPulse = 1.6, levelCycle = 2.4,
	groupH = 30, groupY = 10, groupLift = 36, filigreeW = 84, filigreeH = 21, filigreeGap = 6, levelFont = 18,
	rewardTime = 2.4,
	bubbleW = 290, bubbleLeft = 24, bubbleRight = 40, bubbleNameY = -13, bubbleTextY = -30,
	bubbleBottom = 18, bubbleMin = 64, sheenTime = 0.9,
}
local FXC = ns.AZEROTH_FX
local FX_GOLD = INKS.fx                    -- teinte des lueurs blanches (2.11.2 : encre)
local FX_TEXT = INKS.fxText                -- « Aguerri ! »
-- éclats autour du cadre : position (fraction du cadre depuis son coin
-- haut gauche) et décalage dans le cycle
local SPARKS = { { 0.0, 0.13, 0 }, { 1.06, 0.2, 0.5 }, { 0.58, -0.03, 1.0 }, { 1.15, 0.67, 1.3 } }
local DOTS = { { 0.27, 0.36, 0, "dots1" }, { 0.85, 0.19, 0.8, "dots2" } }

local FXFR = {
	AZ_FX_EVOLVE = "%s !",
	AZ_FX_LEVEL  = "Niveau %d !",
}
local FXEN = {
	AZ_FX_EVOLVE = "%s!",
	AZ_FX_LEVEL  = "Level %d!",
}
ns.RegisterStrings(FXFR, FXEN)
if ns.KEEP_STRINGS then ns.AZEROTH_FX_STRINGS = { fr = FXFR, en = FXEN } end

local function HasFx(key) return ns.AzerothHasAtlas(FXA[key]) and true or false end
local function Additive(tex) if tex.SetBlendMode then tex:SetBlendMode("ADD") end end
local function Gold(tex) tex:SetVertexColor(FX_GOLD[1], FX_GOLD[2], FX_GOLD[3], 1) end
local function Rotate(tex, radians) Method(tex, "SetRotation", radians) end
local function Pulse(t, period)            -- 0 → 1 → 0, en douceur
	return 0.5 - 0.5 * math.cos(2 * math.pi * t / period)
end

-- L'atlas retourné de gauche à droite : coordonnées de l'atlas inversées
-- (C_Texture.GetAtlasInfo) ; sans elles, l'atlas tel quel
local function AtlasMirrored(tex, name)
	local api = G("C_Texture")
	if type(api) == "table" and type(api.GetAtlasInfo) == "function" then
		local ok, info = pcall(api.GetAtlasInfo, name)
		if ok and ns.Plain then info = ns.Plain(info) end
		local file = ok and type(info) == "table" and (info.file or info.filename)
		if file and tonumber(info.leftTexCoord) and tonumber(info.rightTexCoord) then
			tex:SetTexture(file)
			tex:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.topTexCoord or 0, info.bottomTexCoord or 1)
			tex.mirrored = true
			return true
		end
	end
	return Atlas(tex, name)
end

-- Le compagnon porte-t-il un anneau (ancien habillage ou, 3.1.0, médaillon
-- forgé), affiché, module allumé ?
local function AzCompanion(self)
	local frame = self.companionFrame
	if not (frame and frame.ring ~= nil and frame:IsShown()) then return nil end
	if ns.CompanionOn and not ns.CompanionOn() then return nil end
	return frame
end
-- 3.1.0 : l'atlas d'un effet est-il là, ou son repli forgé (médaillon forgé) ?
local function Forged(frame) return frame ~= nil and frame.ring == "forge" and Theme.ART ~= nil end
-- Une texture en matière forgée (Theme.ART), teinte, en lumière additive
local function ForgeTex(parent, layer, sub, art, color, alpha)
	local tex = parent:CreateTexture(nil, layer or "OVERLAY", nil, sub or 0)
	tex:SetTexture(Theme.ART[art].file)
	tex:SetVertexColor(color[1], color[2], color[3], alpha or 1)
	if tex.SetBlendMode then tex:SetBlendMode("ADD") end
	tex.forgeArt = art
	return tex
end

-- Le calque des effets sur le cadre : au-dessus du modèle et de l'anneau,
-- sans souris (la caresse, le survol et le filet passent au travers)
local function FxLayer(frame)
	if frame.azFxLayer then return frame.azFxLayer end
	local layer = CreateFrame("Frame", nil, frame)
	layer:SetAllPoints(frame)
	layer:SetFrameLevel((frame:GetFrameLevel() or 1) + 8)
	layer:EnableMouse(false)
	frame.azFxLayer = layer
	return layer
end

-- ---------------------------------------------------------------------------
-- L'horloge des effets : posée tant qu'un effet joue, retirée ensuite
-- ---------------------------------------------------------------------------
local FxStep
local function FxState(self)
	local state = self.azFx
	if not state then state = { rewards = {} }; self.azFx = state end
	return state
end
local function FxStart(self)
	local driver = self.azFxDriver
	if not driver then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or not frame then return false end
		driver = frame
		self.azFxDriver = driver
	end
	if not driver.running then
		driver.running = true
		driver:SetScript("OnUpdate", function(f)
			local done, busy = pcall(FxStep, ns, Clock())
			if not done and ns.RecordError then ns:RecordError("azeroth:fx", busy) end
			if not done or not busy then f:SetScript("OnUpdate", nil); f.running = nil end
		end)
	end
	return true
end

-- ---------------------------------------------------------------------------
-- 1. La bulle : parchemin des « Talking Heads », nom en petites capitales,
-- texte brun foncé. Même ancre, même fondu, ne prend pas la souris ; la
-- bulle Sobre (Theme.CreateBubble) n'est que masquée, et revient telle quelle.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 3.1.0 : la bulle du médaillon forgé. La brique du socle (Theme.CreateBubble,
-- fond sombre, filet lumineux de l'identité, pointe) ; on y re-loge ce que la
-- bulle de parchemin avait en propre : le nom de qui parle, en capitales
-- (titre : identité), au-dessus de la réplique, et un reflet qui traverse
-- la bulle à chaque nouvelle réplique (Theme.ART.line, sur l'horloge des
-- effets). Une bulle née en Sobre reçoit le filet lumineux à la bascule ;
-- née forgée, elle retrouve l'aplat d'or du Sobre au retour (créés une fois).
-- ---------------------------------------------------------------------------
ns.FORGE_BUBBLE = { nameH = 13, nameY = -8 }
local function ForgeBubbleParts(bubble)
	if bubble.forgeTalk then return bubble.forgeTalk end
	local parts = {}
	local pad = Theme.BUBBLE_PAD or 10
	if not bubble.forged and Theme.ArtTexture and Theme.ART and Theme.ART.line and Theme.FORGE_RULE then
		parts.rule = Theme.ArtTexture(bubble, "line", "ARTWORK", 0, Theme.IDENTITY_LIGHT or Theme.GOLD_LIGHT, Theme.FORGE_RULE.alpha)
		parts.rule:SetHeight(Theme.FORGE_RULE.height)
		parts.rule:SetPoint("TOPLEFT", bubble, "TOPLEFT", 1, -1)
		parts.rule:SetPoint("TOPRIGHT", bubble, "TOPRIGHT", -1, -1)
	end
	parts.name = bubble:CreateFontString(nil, "OVERLAY", Theme.F_CAPS)
	parts.name:SetPoint("TOPLEFT", bubble, "TOPLEFT", pad, ns.FORGE_BUBBLE.nameY)
	parts.name:SetPoint("TOPRIGHT", bubble, "TOPRIGHT", -pad, ns.FORGE_BUBBLE.nameY)
	parts.name:SetJustifyH("CENTER")
	if parts.name.SetWordWrap then parts.name:SetWordWrap(false) end
	Theme.TextShadow(parts.name, 0.8)
	-- le reflet : une traînée de lumière debout (point lumineux étiré)
	if Theme.ART and Theme.ART.dot then
		parts.sheen = ForgeTex(bubble, "ARTWORK", 2, "dot", Theme.WHITE, 1)
		parts.sheen:Hide()
	end
	parts.regions = { parts.name }
	if parts.rule then parts.regions[#parts.regions + 1] = parts.rule end
	bubble.forgeTalk = parts
	return parts
end

-- La bulle d'un thème : le filet du Sobre (aplat d'or) ou le forgé
local function BubbleRule(bubble, forged)
	local parts = bubble.forgeTalk
	if forged then
		if parts and parts.rule then bubble.rule:Hide(); parts.rule:Show() end
		if bubble.sobreRule then bubble.sobreRule:Hide() end
		if bubble.forged then bubble.rule:Show() end
		return
	end
	if parts and parts.rule then parts.rule:Hide(); bubble.rule:Show() end
	if bubble.forged then
		-- née forgée : l'aplat d'or du Sobre (Theme.CreateBubble), créé une fois
		if not bubble.sobreRule then
			bubble.sobreRule = Theme.Solid(bubble, "ARTWORK", Theme.GOLD, 1)
			bubble.sobreRule:SetHeight(2)
			bubble.sobreRule:SetPoint("TOPLEFT", bubble, "TOPLEFT", 1, -1)
			bubble.sobreRule:SetPoint("TOPRIGHT", bubble, "TOPRIGHT", -1, -1)
		end
		bubble.rule:Hide()
		bubble.sobreRule:Show()
	end
end

-- Mise en page forgée : le nom au-dessus, la réplique décalée d'autant
local function ForgeBubbleLayout(self, bubble, height)
	local parts = ForgeBubbleParts(bubble)
	local pad = Theme.BUBBLE_PAD or 10
	local c = Theme.TITLE
	parts.name:SetTextColor(c[1], c[2], c[3], 1)
	parts.name:SetText(Upper(self.CompanionName and self:CompanionName() or ""))
	if bubble.text then
		bubble.text:ClearAllPoints()
		bubble.text:SetPoint("TOPLEFT", bubble, "TOPLEFT", pad, -pad - 1 - ns.FORGE_BUBBLE.nameH)
	end
	height = math.ceil((tonumber(height) or bubble:GetHeight() or Theme.BUBBLE_MIN or 34) + ns.FORGE_BUBBLE.nameH)
	bubble:SetHeight(height)
	return height
end

-- Habille la bulle selon le style du compagnon (et la rhabille si affichée)
function ns:CompanionBubbleApplyStyle()
	local bubble = self.companionBubble
	if not bubble then return nil end
	local frame = self.companionFrame
	-- 2.8.2 : plus d'atlas des Talking Heads exigé (le parchemin vient de son fichier)
	-- 3.1.0 : le médaillon forgé, sa bulle forgée
	local forge = frame ~= nil and frame.ring == "forge"
	if bubble.forgeBubble and not forge then
		local parts = bubble.forgeTalk
		for _, region in ipairs(parts.regions) do region:Hide() end
		if parts.sheen then parts.sheen:Hide() end
		bubble.forgeBubble = nil
		BubbleRule(bubble, false)
		if bubble.text then
			local pad = Theme.BUBBLE_PAD or 10
			bubble.text:ClearAllPoints()
			bubble.text:SetPoint("TOPLEFT", bubble, "TOPLEFT", pad, -pad - 1)
		end
		bubble:SetText(bubble.text and bubble.text:GetText() or "", bubble.azExtra)
	end
	if forge then
		local parts = ForgeBubbleParts(bubble)
		for _, region in ipairs(parts.regions) do region:Show() end
		BubbleRule(bubble, true)
		bubble.forgeBubble = true
		bubble:SetText(bubble.text and bubble.text:GetText() or "", bubble.azExtra)
		return "forge"
	end
	return "sobre"
end

-- la bulle : SetText garde la mesure Sobre, puis la mise en page Azeroth ;
-- un reflet traverse le parchemin à chaque nouvelle réplique
local function SkinBubble(self, bubble)
	if bubble.azWrapped then return end
	bubble.azWrapped = true
	local base = bubble.SetText
	function bubble:SetText(value, extra)
		self.azExtra = extra
		local height = base(self, value, extra)
		if self.forgeBubble then
			-- 3.1.0 : le nom au-dessus ; le reflet passe à chaque réplique
			height = ForgeBubbleLayout(ns, self, height)
			if self.forgeTalk.sheen and value and value ~= "" then
				FxState(ns).sheenAt = Clock()
				FxStart(ns)
			end
		end
		return height
	end
end

do
	local ensure = ns.EnsureCompanionBubble
	if ensure then
		function ns:EnsureCompanionBubble(...)
			local fresh = not self.companionBubble
			local bubble = ensure(self, ...)
			if bubble and fresh then
				SkinBubble(self, bubble)
				self:CompanionBubbleApplyStyle()
			end
			return bubble
		end
	end
end

-- ---------------------------------------------------------------------------
-- 2. La lueur ronde : derrière l'anneau (sous le fond du portrait : elle
-- déborde en halo), dorée, elle respire tant que la bulle est là, plus vite
-- quand une brillante est repérée. Remplace le liseré rectangulaire.
-- ---------------------------------------------------------------------------
local function RoundGlow(frame)
	if frame.azGlow ~= nil then return frame.azGlow or nil end
	local key = HasFx("circle") and "circle" or (HasFx("circleAlt") and "circleAlt") or nil
	-- 3.1.0 : médaillon forgé sans l'atlas : notre point lumineux, doré
	if not key and Forged(frame) then
		local glow = ForgeTex(frame, "BACKGROUND", -8, "dot", Theme.GOLD_LIGHT, 1)
		glow:SetPoint("CENTER", frame, "TOP", 0, RING_Y)
		glow:SetAlpha(0)
		glow:Hide()
		glow.base = math.floor(RING_W * ns.FORGE_FX.glowSize)
		glow:SetSize(glow.base, glow.base)
		frame.azGlow = glow
		return glow
	end
	if not key then return nil end   -- pas d'atlas : pas de lueur (et pas de liseré)
	local glow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	glow:SetPoint("CENTER", frame, "TOP", 0, RING_Y)
	Atlas(glow, FXA[key])
	Additive(glow)
	Gold(glow)
	glow:SetAlpha(0)
	glow:Hide()
	glow.base = math.floor(RING_W * FXC.glowSize)
	glow:SetSize(glow.base, glow.base)
	frame.azGlow = glow
	return glow
end

-- Force de la lueur (0..1) : la bulle, puis son extinction ; la brillante
function ns:AzerothGlowEnvelope(now)
	local e = 0
	local untilAt = self.companionBubbleUntil
	if untilAt then
		if now < untilAt then e = 1
		elseif now - untilAt < FXC.glowFade then e = 1 - (now - untilAt) / FXC.glowFade end
	end
	local state = self.azFx
	local shiny = state and state.shinyUntil
	if shiny and now < shiny + FXC.glowFade then
		e = math.max(e, now < shiny and 1 or 1 - (now - shiny) / FXC.glowFade)
	end
	return e, shiny ~= nil and now < shiny
end

local function AzGlowStep(self, frame, now)
	local env, shiny = 0, false
	if ns.CompanionOn and ns.CompanionOn() then env, shiny = self:AzerothGlowEnvelope(now) end
	local glow = frame.azGlow
	if env <= 0 then
		if glow and frame.azGlowAlpha ~= 0 then glow:Hide(); frame.azGlowAlpha = 0 end
		return 0
	end
	glow = RoundGlow(frame)
	if not glow then return 0 end
	local p = Pulse(now, shiny and FXC.glowShinyPeriod or FXC.glowPeriod)
	local alpha = env * (0.15 + 0.6 * p)
	local size = math.floor(glow.base * (0.92 + 0.12 * p) + 0.5)
	if glow.size ~= size then glow:SetSize(size, size); glow.size = size end
	glow:SetAlpha(alpha)
	glow:Show()
	frame.azGlowAlpha = alpha
	return alpha
end

do
	local glowUpdate = ns.GlowUpdate
	if glowUpdate then
		function ns:GlowUpdate(now, ...)
			local frame = self.companionFrame
			if not (frame and frame.ring ~= nil) then
				if frame and frame.azGlow and frame.azGlowAlpha ~= 0 then frame.azGlow:Hide(); frame.azGlowAlpha = 0 end
				return glowUpdate(self, now, ...)
			end
			-- Azeroth : le liseré rectangulaire s'éteint, la lueur ronde le remplace
			if type(frame.glow) == "table" and frame.glowAlpha ~= 0 then
				for _, tex in ipairs(frame.glow) do tex:Hide() end
				frame.glowAlpha = 0
			end
			return AzGlowStep(self, frame, now or Clock())
		end
	end
end

-- ---------------------------------------------------------------------------
-- 3. Brillante repérée : éclats d'étoile dorés qui scintillent autour du
-- cadre (décalés), lueur plus rapide, FXC.shinyTime s
-- ---------------------------------------------------------------------------
local function Sparks(frame)
	if frame.azSparks then return frame.azSparks end
	local layer = FxLayer(frame)
	local list = {}
	-- 3.1.0 : sans l'atlas du client (médaillon forgé), notre point lumineux doré
	local star = HasFx("star")
	for index = 1, #SPARKS do
		local tex
		if star then
			tex = layer:CreateTexture(nil, "OVERLAY", nil, 3)
			Atlas(tex, FXA.star)
			Additive(tex)
			Gold(tex)
		else
			tex = ForgeTex(layer, "OVERLAY", 3, "dot", Theme.GOLD_LIGHT, 1)
		end
		tex:Hide()
		list[index] = tex
	end
	frame.azSparks = list
	return list
end

-- Lance les éclats ; 3.1.0 : pour tout anneau (ancien habillage ou
-- médaillon forgé : ns:CompanionShinyFX). ns:AzerothShinyFX reste l'effet
-- de l'ancien habillage seul (rien hors drapeau).
local function ShinyFX(self)
	local frame = AzCompanion(self)
	if not frame then return false end
	local state = FxState(self)
	local now = Clock()
	state.shinyUntil = now + FXC.shinyTime
	if HasFx("star") or Forged(frame) then
		state.sparkAt = now
		local w, h = frame:GetWidth() or 104, frame:GetHeight() or 118
		for index, tex in ipairs(Sparks(frame)) do
			local s = SPARKS[index]
			tex:ClearAllPoints()
			tex:SetPoint("CENTER", frame, "TOPLEFT", math.floor(s[1] * w), -math.floor(s[2] * h))
			tex:SetAlpha(0)
		end
	end
	FxStart(self)
	return true
end
function ns:CompanionShinyFX() return ShinyFX(self) end

local function SparkStep(frame, state, now)
	local list = frame.azSparks
	if not (list and state.sparkAt) then return false end
	local t = now - state.sparkAt
	local fade = Clamp01((state.shinyUntil - now) / FXC.glowFade)
	if t >= FXC.shinyTime then
		for _, tex in ipairs(list) do tex:Hide() end
		state.sparkAt = nil
		return false
	end
	for index, tex in ipairs(list) do
		local lt = t - SPARKS[index][3]
		if lt < 0 then
			tex:Hide()
		else
			-- 0 → 40 % : apparaît et grandit en tournant ; 70 % : éteint
			local p = (lt % FXC.sparkPeriod) / FXC.sparkPeriod
			local alpha, scale = 0, 0.3
			if p < 0.4 then alpha, scale = p / 0.4, 0.3 + 0.7 * p / 0.4
			elseif p < 0.7 then alpha, scale = 1 - (p - 0.4) / 0.3, 1 end
			local base = tex.forgeArt and ns.FORGE_FX.sparkSize or FXC.sparkSize
			local size = math.max(1, math.floor(base * scale + 0.5))
			tex:SetSize(size, size)
			Rotate(tex, math.rad(30) * math.min(1, p / 0.4))
			tex:SetAlpha(alpha * fade)
			tex:Show()
		end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- 4. Évolution / niveau : lueur autour du portrait, poussière dorée qui
-- monte, et une ligne au-dessus du cadre : volute, « Aguerri ! », volute
-- retournée, collées au texte (le groupe suit sa largeur, FXC.groupH px de
-- haut), un nuage doux derrière, la ligne de lumière qui passe dessous. La
-- bulle, si elle est là, monte d'un cran le temps de l'effet : rien ne se
-- chevauche.
-- ---------------------------------------------------------------------------
-- 3.1.0 : chaque pièce dont l'atlas du client manque a son repli en
-- matières forgées sur le médaillon forgé (lueur et poussière : points
-- lumineux dorés ; volutes : deux filets lumineux de l'identité qui
-- s'éteignent vers l'extérieur ; nuage : un point lumineux sombre ; ligne de
-- lumière : un point lumineux étiré). Construites une fois par cadre.
local function LevelParts(frame)
	if frame.azLevel then return frame.azLevel end
	local layer = FxLayer(frame)
	local parts = {}
	local forge = Forged(frame)
	local FF = ns.FORGE_FX
	-- médaillon forgé : la lueur sous l'habit (niveau du cadre + 3 < habit
	-- + 4) : elle déborde de l'anneau, la plaque du nom la recouvre en bas
	local glowParent = layer
	if forge then
		glowParent = CreateFrame("Frame", nil, layer)
		glowParent:SetAllPoints(frame)
		glowParent:SetFrameLevel((frame:GetFrameLevel() or 1) + FF.glowBelow)
		glowParent:EnableMouse(false)
		parts.iglowHost = glowParent
	end
	if HasFx("iconGlow") then
		parts.iglow = glowParent:CreateTexture(nil, "OVERLAY", nil, 1)
		Atlas(parts.iglow, FXA.iconGlow)
		Additive(parts.iglow)
	elseif forge then
		-- (notre anneau en lumière : il cerne le portrait sans le voiler)
		parts.iglow = ForgeTex(glowParent, "OVERLAY", 1, "ring", Theme.GOLD_LIGHT, 1)
	end
	if parts.iglow then
		parts.iglow:SetPoint("CENTER", frame, "TOP", 0, RING_Y)
		parts.iglow.base = math.floor(RING_W * 1.1)
		parts.iglow:Hide()
	end
	parts.dots = {}
	for index, d in ipairs(DOTS) do
		if HasFx(d[4]) then
			local tex = layer:CreateTexture(nil, "OVERLAY", nil, 2)
			tex:SetSize(58, 34)
			Atlas(tex, FXA[d[4]])
			Additive(tex)
			tex:Hide()
			parts.dots[index] = tex
		elseif forge then
			-- une grappe de trois points lumineux (même emprise que l'atlas)
			local cluster = CreateFrame("Frame", nil, layer)
			cluster:SetSize(58, 34)
			cluster:EnableMouse(false)
			cluster.points = {}
			for k, p in ipairs(FF.dust) do
				local dot = ForgeTex(cluster, "OVERLAY", 2, "dot", Theme.GOLD_LIGHT, 1)
				dot:SetSize(p[3], p[3])
				dot:SetPoint("CENTER", cluster, "CENTER", p[1], p[2])
				cluster.points[k] = dot
			end
			cluster:Hide()
			parts.dots[index] = cluster
		end
	end
	-- le groupe du titre : hors du cadre (pas à son échelle), même strate que la bulle
	local group = CreateFrame("Frame", nil, UIParent)
	group:SetFrameStrata("HIGH")
	group:SetSize(200, FXC.groupH)
	group:EnableMouse(false)
	if HasFx("cloud") then
		group.cloud = group:CreateTexture(nil, "BACKGROUND")
		group.cloud:SetPoint("CENTER", group, "CENTER", 0, 0)
		Atlas(group.cloud, FXA.cloud)
	elseif forge then
		group.cloud = group:CreateTexture(nil, "BACKGROUND")
		group.cloud:SetTexture(Theme.ART.dot.file)
		group.cloud:SetVertexColor(Theme.SHADOW[1], Theme.SHADOW[2], Theme.SHADOW[3], 1)
		group.cloud:SetPoint("CENTER", group, "CENTER", 0, 0)
		group.cloud.forgeArt = "dot"
	end
	group.text = group:CreateFontString(nil, "OVERLAY", Theme.F_TITLE)
	group.text:SetPoint("CENTER", group, "CENTER", 0, 0)
	AzFont(group.text, FXC.levelFont)
	group.text:SetTextColor(FX_TEXT[1], FX_TEXT[2], FX_TEXT[3], 1)
	Theme.TextShadow(group.text)
	if group.text.SetWordWrap then group.text:SetWordWrap(false) end
	if HasFx("filigree") then
		group.left = group:CreateTexture(nil, "ARTWORK")
		group.left:SetSize(FXC.filigreeW, FXC.filigreeH)
		group.left:SetPoint("RIGHT", group.text, "LEFT", -FXC.filigreeGap, 0)
		Atlas(group.left, FXA.filigree)
		group.right = group:CreateTexture(nil, "ARTWORK")
		group.right:SetSize(FXC.filigreeW, FXC.filigreeH)
		group.right:SetPoint("LEFT", group.text, "RIGHT", FXC.filigreeGap, 0)
		AtlasMirrored(group.right, FXA.filigree)
	elseif forge then
		local c = Theme.IDENTITY_LIGHT or Theme.GOLD_LIGHT
		group.left = ForgeTex(group, "ARTWORK", 0, "line", c, 1)
		group.left:SetTexCoord(1, 0, 0, 1)   -- s'éteint vers la gauche
		group.left:SetSize(FXC.filigreeW, FF.rule)
		group.left:SetPoint("RIGHT", group.text, "LEFT", -FXC.filigreeGap, 0)
		group.right = ForgeTex(group, "ARTWORK", 0, "line", c, 1)
		group.right:SetSize(FXC.filigreeW, FF.rule)
		group.right:SetPoint("LEFT", group.text, "RIGHT", FXC.filigreeGap, 0)
	end
	if HasFx("line") then
		group.line = group:CreateTexture(nil, "OVERLAY")
		group.line:SetPoint("TOP", group, "BOTTOM", 0, 4)
		Atlas(group.line, FXA.line)
		Additive(group.line)
	elseif forge then
		group.line = ForgeTex(group, "OVERLAY", 0, "dot", Theme.IDENTITY_LIGHT or Theme.GOLD_LIGHT, 1)
		group.line:SetPoint("TOP", group, "BOTTOM", 0, 4)
	end
	group:Hide()
	parts.group = group
	frame.azLevel = parts
	return parts
end

-- La bulle monte au-dessus du groupe (ou revient à sa place)
local function LiftBubble(self, lift)
	local bubble, frame = self.companionBubble, self.companionFrame
	if not (bubble and frame) then return end
	if lift and not bubble.azLift then
		local point, rel, relPoint, x, y = bubble:GetPoint(1)
		bubble.azLift = { point or "BOTTOM", rel or frame, relPoint or "TOP", x or 0, y or 12 }
		bubble:ClearAllPoints()
		bubble:SetPoint(bubble.azLift[1], bubble.azLift[2], bubble.azLift[3], bubble.azLift[4], bubble.azLift[5] + FXC.groupLift)
	elseif not lift and bubble.azLift then
		local p = bubble.azLift
		bubble.azLift = nil
		bubble:ClearAllPoints()
		bubble:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
end

-- Lance l'effet ; `text` : « Aguerri ! », « Niveau 12 ! ». 3.1.0 : pour tout
-- anneau (ns:CompanionLevelFX) ; ns:AzerothLevelFX : l'ancien habillage seul.
local function LevelFX(self, text, kind)
	local frame = AzCompanion(self)
	if not frame then return false end
	local parts = LevelParts(frame)
	local group = parts.group
	group.text:SetText(text or "")
	-- 3.1.0 : médaillon forgé : le titre à l'encre de l'identité ; l'ancien
	-- habillage garde la sienne
	local ink = Forged(frame) and Theme.TITLE or FX_TEXT
	group.text:SetTextColor(ink[1], ink[2], ink[3], 1)
	local textW = math.ceil(Measure(group.text))
	local width = textW + (group.left and 2 * (FXC.filigreeW + FXC.filigreeGap) or 0)
	group:SetSize(math.max(40, width), FXC.groupH)
	if group.cloud then group.cloud:SetSize(width + 40, FXC.groupH + 14) end
	if group.line then
		group.line.base = width + 40
		group.line:SetSize(width + 40, group.line.forgeArt and ns.FORGE_FX.lineH or 12)
	end
	group:ClearAllPoints()
	group:SetPoint("BOTTOM", frame, "TOP", 0, FXC.groupY)
	group:SetAlpha(0)
	group:Show()
	local state = FxState(self)
	state.level = { at = Clock(), kind = kind or "level", text = text }
	FxStart(self)
	return true
end
function ns:CompanionLevelFX(text, kind) return LevelFX(self, text, kind) end

local function LevelStop(self, frame)
	local parts = frame and frame.azLevel
	if parts then
		parts.group:Hide()
		if parts.iglow then parts.iglow:Hide() end
		for _, tex in pairs(parts.dots) do tex:Hide() end
	end
	LiftBubble(self, false)
	if self.azFx then self.azFx.level = nil end
end

local function LevelStep(self, frame, state, now)
	local fx = state.level
	if not fx then return false end
	local parts = LevelParts(frame)
	local t = now - fx.at
	if t >= FXC.levelTime then LevelStop(self, frame); return false end
	local env = math.min(Clamp01(t / 0.3), Clamp01((FXC.levelTime - t) / 0.5))
	-- la bulle affichée : elle passe au-dessus du groupe
	local bubble = self.companionBubble
	LiftBubble(self, bubble ~= nil and bubble:IsShown())
	if parts.iglow then
		local p = Pulse(t, FXC.levelPulse)
		local size = math.floor(parts.iglow.base * (0.92 + 0.12 * p) + 0.5)
		parts.iglow:SetSize(size, size)
		parts.iglow:SetAlpha(env * (0.15 + 0.6 * p))
		parts.iglow:Show()
	end
	local w, h = frame:GetWidth() or 104, frame:GetHeight() or 118
	for index, tex in pairs(parts.dots) do
		local d = DOTS[index]
		local lt = t - d[3]
		if lt < 0 then
			tex:Hide()
		else
			local p = (lt % FXC.levelCycle) / FXC.levelCycle
			local alpha = p < 0.4 and p / 0.4 or 1 - (p - 0.4) / 0.6
			tex:ClearAllPoints()
			tex:SetPoint("CENTER", frame, "TOPLEFT", math.floor(d[1] * w), -math.floor(d[2] * h) - 20 + math.floor(60 * p))
			tex:SetAlpha(alpha * env)
			tex:Show()
		end
	end
	local group = parts.group
	group:SetAlpha(env)
	if group.cloud then group.cloud:SetAlpha(ns.FORGE_FX.cloudAlpha) end
	if group.line then
		local p = (t % FXC.levelCycle) / FXC.levelCycle
		local alpha, scale = 0, 1
		if p < 0.3 then alpha, scale = p / 0.3, 0.2 + 0.8 * p / 0.3
		elseif p < 0.8 then alpha = 1 - (p - 0.3) / 0.5 end
		group.line:SetWidth(math.max(1, math.floor(group.line.base * scale)))
		group.line:SetAlpha(alpha)
	end
	return true
end

-- ---------------------------------------------------------------------------
-- 5. Les grandes récompenses : ailes dorées de part et d'autre et un éclat
-- derrière un bandeau (« Nouveau titre », gros haut fait). API pour les
-- hauts faits : ns:AzerothRewardFX(frame[, opts]) ; opts.anchor : la région
-- à encadrer (défaut : frame.banner, sinon frame). Rend true si un effet part.
-- ---------------------------------------------------------------------------

-- 3.1.0 : les grandes récompenses sous le thème forgé, sur un bandeau né
-- forgé (ForgeBanners.lua). Les ailes et l'éclat du client s'il les a
-- (un effet, pas un habillage) ; sinon, en matières du socle : un éclat
-- (Theme.ART.dot, or des brillantes) derrière le bandeau et deux paires de
-- filets lumineux (Theme.ART.line, ns.QCForgeLine : couleur d'identité) en
-- miroir de part et d'autre, qui s'ouvrent en ailes. Même horloge (FxStep),
-- mêmes durées ; textures créées une fois par bandeau.
ns.FORGE_REWARD = { spread = 1.9, lineH = 6, lift = 0.22, glowW = 1.6, glowH = 2.6, glowAlpha = 0.8 }
local FORGE_WINGS = { "wingUL", "wingUR", "wingLL", "wingLR" }
local function ForgeReward(self, frame, opts)
	opts = opts or {}
	local anchor = opts.anchor or frame
	local wings, burst = HasFx("wings"), HasFx("burst")
	local fx = frame.azReward
	if not fx then
		fx = { forge = true }
		if wings then
			fx.left = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
			Atlas(fx.left, FXA.wings)
			fx.right = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
			AtlasMirrored(fx.right, FXA.wings)
		elseif ns.QCForgeLine then
			-- les filets : à gauche, la lueur s'efface vers l'extérieur (miroir)
			for index, key in ipairs(FORGE_WINGS) do
				local leftSide = index % 2 == 1
				local tex = ns.QCForgeLine(frame, "BACKGROUND", leftSide)
				if tex then
					if tex.SetDrawLayer then tex:SetDrawLayer("BACKGROUND", -8) end
					if tex.SetBlendMode then tex:SetBlendMode("ADD") end
					tex:SetHeight(ns.FORGE_REWARD.lineH)
					tex:Hide()
					fx[key] = tex
				end
			end
		end
		if burst then
			fx.burst = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
			Atlas(fx.burst, FXA.burst)
			Additive(fx.burst)
		elseif Theme.ART and Theme.ART.dot then
			fx.glow = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
			fx.glow:SetTexture(Theme.ART.dot.file)
			Additive(fx.glow)
			local c = Theme.SHINY or Theme.GOLD_LIGHT
			fx.glow:SetVertexColor(c[1], c[2], c[3], 1)
			fx.glow:Hide()
		end
		frame.azReward = fx
	end
	local h = tonumber(anchor:GetHeight()) or 66
	fx.h, fx.w = h, tonumber(anchor:GetWidth()) or 300
	local lift = math.floor(h * ns.FORGE_REWARD.lift)
	if fx.left then
		fx.left:ClearAllPoints(); fx.left:SetPoint("CENTER", anchor, "LEFT", 0, math.floor(h * 0.2))
		fx.right:ClearAllPoints(); fx.right:SetPoint("CENTER", anchor, "RIGHT", 0, math.floor(h * 0.2))
	end
	if fx.wingUL then
		fx.wingUL:ClearAllPoints(); fx.wingUL:SetPoint("RIGHT", anchor, "LEFT", 0, lift)
		fx.wingUR:ClearAllPoints(); fx.wingUR:SetPoint("LEFT", anchor, "RIGHT", 0, lift)
		fx.wingLL:ClearAllPoints(); fx.wingLL:SetPoint("RIGHT", anchor, "LEFT", 0, -lift)
		fx.wingLR:ClearAllPoints(); fx.wingLR:SetPoint("LEFT", anchor, "RIGHT", 0, -lift)
	end
	if fx.burst then fx.burst:ClearAllPoints(); fx.burst:SetPoint("CENTER", anchor, "CENTER", 0, 0) end
	if fx.glow then fx.glow:ClearAllPoints(); fx.glow:SetPoint("CENTER", anchor, "CENTER", 0, 0) end
	fx.at = Clock()
	FxState(self).rewards[frame] = true
	FxStart(self)
	return true
end

-- Les grandes récompenses d'un bandeau : le thème forgé (bandeau né forgé),
-- rien en Sobre. Rend true si un effet part.
function ns:BannerRewardFX(frame, opts)
	if not (frame and frame.CreateTexture) then return false end
	if frame.forgeBanner and ns.QCForged and ns.QCForged() then return ForgeReward(self, frame, opts) end
	return false
end

local function RewardStop(frame)
	local fx = frame.azReward
	if not fx then return end
	for _, key in ipairs({ "left", "right", "burst", "glow", "wingUL", "wingUR", "wingLL", "wingLR" }) do
		if fx[key] then fx[key]:Hide() end
	end
	fx.at = nil
end

-- Les ailes et l'éclat forgés (repli sans atlas) : les filets s'allongent
-- vers l'extérieur, les hauts plus longs, puis s'effacent ; l'éclat s'ouvre
local function ForgeRewardStep(fx, p)
	local R = ns.FORGE_REWARD
	if fx.wingUL then
		local alpha = p < 0.25 and p / 0.25 or (p > 0.8 and Clamp01(1 - (p - 0.8) / 0.2) or 1)
		local open = math.min(1, p / 0.35)
		local long = math.max(1, math.floor(fx.h * R.spread * (0.3 + 0.7 * open)))
		local short = math.max(1, math.floor(long * 0.7))
		fx.wingUL:SetWidth(long); fx.wingUR:SetWidth(long)
		fx.wingLL:SetWidth(short); fx.wingLR:SetWidth(short)
		for _, key in ipairs(FORGE_WINGS) do
			fx[key]:SetAlpha(alpha)
			fx[key]:Show()
		end
	end
	if fx.glow then
		local alpha = (p < 0.25 and p / 0.25 or Clamp01(1 - (p - 0.25) / 0.6)) * R.glowAlpha
		local scale = 0.4 + 0.6 * math.min(1, p / 0.5)
		fx.glow:SetSize(math.max(1, math.floor(fx.w * R.glowW * scale)), math.max(1, math.floor(fx.h * R.glowH * scale)))
		fx.glow:SetAlpha(alpha)
		fx.glow:Show()
	end
end

local function RewardStep(frame, now)
	local fx = frame.azReward
	if not (fx and fx.at) or not frame:IsShown() then RewardStop(frame); return false end
	local p = (now - fx.at) / FXC.rewardTime
	if p >= 1 then RewardStop(frame); return false end
	if fx.forge then ForgeRewardStep(fx, p) end
	local h = fx.h
	if fx.left then
		-- les ailes s'ouvrent (0,4 → 1, en se redressant), restent, s'effacent
		local alpha, scale = 1, 1
		if p < 0.25 then alpha, scale = p / 0.25, 0.4 + 0.6 * p / 0.25
		elseif p > 0.85 then alpha = 1 - (p - 0.85) / 0.15 end
		local wh = math.max(1, math.floor(h * 1.56 * scale))
		local ww = math.max(1, math.floor(h * 1.32 * scale))
		local turn = math.rad(10) * (1 - math.min(1, p / 0.25))
		fx.left:SetSize(ww, wh); fx.right:SetSize(ww, wh)
		Rotate(fx.left, -turn); Rotate(fx.right, turn)
		fx.left:SetAlpha(alpha); fx.right:SetAlpha(alpha)
		fx.left:Show(); fx.right:Show()
	end
	if fx.burst then
		local alpha = p < 0.25 and p / 0.25 or Clamp01(1 - (p - 0.25) / 0.45)
		local scale = 0.3 + 1.0 * math.min(1, p / 0.7)
		fx.burst:SetSize(math.max(1, math.floor(h * 1.7 * scale)), math.max(1, math.floor(h * 1.46 * scale)))
		Rotate(fx.burst, math.rad(45) * math.min(1, p / 0.7))
		fx.burst:SetAlpha(alpha)
		fx.burst:Show()
	end
	return true
end

-- Démonstration : un titre de dresseur gagné (file du carnet) a ses ailes
do
	local showNext = ns.ShowNextJournalToast
	if showNext then
		function ns:ShowNextJournalToast(...)
			local head = self.journalToasts and self.journalToasts[1]
			local frame = showNext(self, ...)
			-- 3.1.0 : l'ancien habillage ou le thème forgé (ns:BannerRewardFX)
			if frame and frame.forgeBanner and head and (head.kind == "rank" or head.big)
				and frame.text and frame.text:GetText() == head.name then
				self:BannerRewardFX(frame)
			end
			return frame
		end
	end
end

-- ---------------------------------------------------------------------------
-- L'horloge (une image) : reflet de la bulle, éclats, niveau, récompenses
-- ---------------------------------------------------------------------------
local function SheenStep(self, state, now)
	local bubble = self.companionBubble
	-- 3.1.0 : la bulle forgée a son reflet (le filet lumineux debout)
	local forge = bubble ~= nil and bubble.forgeBubble and bubble.forgeTalk ~= nil
	local skin = forge and bubble.forgeTalk or nil
	local sheen = skin and skin.sheen
	if not (state.sheenAt and sheen) then return false end
	local p = (now - state.sheenAt) / FXC.sheenTime
	if p >= 1 or not forge or not bubble:IsShown() then
		sheen:Hide(); state.sheenAt = nil
		return false
	end
	local w, h = bubble:GetWidth() or FXC.bubbleW, bubble:GetHeight() or FXC.bubbleMin
	local peak = 0.6
	if forge then
		sheen:SetSize(ns.FORGE_FX.sheenW, math.max(1, h - 2))
		peak = ns.FORGE_FX.sheenAlpha
	else
		sheen:SetSize(70, h)
	end
	sheen:ClearAllPoints()
	sheen:SetPoint("CENTER", bubble, "LEFT", math.floor(w * p), 0)
	sheen:SetAlpha(peak * (p < 0.3 and p / 0.3 or 1 - (p - 0.3) / 0.7))
	sheen:Show()
	return true
end

-- Tout éteindre (changement de style, cadre caché)
function ns:AzerothFxStop()
	local state = self.azFx
	local frame = self.companionFrame
	if frame then
		for _, tex in ipairs(frame.azSparks or {}) do tex:Hide() end
		LevelStop(self, frame)
	end
	if state then
		state.sparkAt, state.shinyUntil, state.level, state.sheenAt = nil, nil, nil, nil
		for f in pairs(state.rewards) do RewardStop(f) end
		state.rewards = {}
	end
	local bubble = self.companionBubble
	if bubble and bubble.forgeTalk and bubble.forgeTalk.sheen then bubble.forgeTalk.sheen:Hide() end
end

FxStep = function(self, now)
	local state = FxState(self)
	local busy = false
	local frame = self.companionFrame
	local companionAz = AzCompanion(self) ~= nil
	if frame and not companionAz and (state.sparkAt or state.level) then
		-- style changé, cadre caché : les effets du compagnon s'arrêtent
		for _, tex in ipairs(frame.azSparks or {}) do tex:Hide() end
		state.sparkAt = nil
		LevelStop(self, frame)
	end
	if companionAz then
		if SparkStep(frame, state, now) then busy = true end
		if LevelStep(self, frame, state, now) then busy = true end
	end
	if SheenStep(self, state, now) then busy = true end
	for f in pairs(state.rewards) do
		if RewardStep(f, now) then busy = true else state.rewards[f] = nil end
	end
	return busy
end
ns.AzerothFxStep = function(now) return FxStep(ns, now or Clock()) end

-- ---------------------------------------------------------------------------
-- Déclencheurs : sur les moments qui existent déjà (brillante repérée,
-- évolution, niveau) ; changement de style
-- ---------------------------------------------------------------------------
do
	local spot = ns.ShinySpot
	if spot then
		function ns:ShinySpot(...)
			local result = spot(self, ...)
			if result then
				local ok, err = pcall(self.CompanionShinyFX, self)
				if not ok and self.RecordError then self:RecordError("azeroth:shiny", err) end
			end
			return result
		end
	end
	local stage = ns.CompanionCheckStage
	if stage then
		function ns:CompanionCheckStage(level, celebrate, ...)
			local evolved = stage(self, level, celebrate, ...)
			if evolved == true and celebrate ~= false then
				local ok, err = pcall(function()
					self:CompanionLevelFX(self:F("AZ_FX_EVOLVE", self:CompanionStageLabel()), "evolve")
				end)
				if not ok and self.RecordError then self:RecordError("azeroth:evolve", err) end
			end
			return evolved
		end
	end
	local onLevel = ns.CompanionOnLevel
	if onLevel then
		function ns:CompanionOnLevel(level, ...)
			local a, b = onLevel(self, level, ...)
			local fx = self.azFx and self.azFx.level
			-- l'évolution du même niveau a déjà son effet
			if not (fx and fx.kind == "evolve" and Clock() - fx.at < 0.5) then
				local n = tonumber(level) or Call(G("UnitLevel"), "player") or 0
				local ok, err = pcall(self.CompanionLevelFX, self, self:F("AZ_FX_LEVEL", n), "level")
				if not ok and self.RecordError then self:RecordError("azeroth:level", err) end
			end
			return a, b
		end
	end
	local apply = ns.CompanionApplyUIStyle
	function ns:CompanionApplyUIStyle(...)
		local style = apply(self, ...)
		local frame = self.companionFrame
		-- 3.1.0 : l'anneau change (ou disparaît) : les effets s'arrêtent net
		if frame and (frame.ring == nil or frame.ring ~= frame.fxRing) then self:AzerothFxStop() end
		if frame then frame.fxRing = frame.ring end
		self:CompanionBubbleApplyStyle()
		return style
	end
end

-- ---------------------------------------------------------------------------
-- Réglage (page Compagnon de route, après le cadrage) et commande
-- ---------------------------------------------------------------------------
do
	for _, page in ipairs(ns.OPTION_PAGES or {}) do
		if page.id == "companionMain" and type(page.rows) == "table" then
			local present, at = false, #page.rows + 1
			for index, row in ipairs(page.rows) do
				if row.key == "companionStyle" then present = true end
				if row.key == "companionFraming" then at = index + 1 end
			end
			if not present then
				table.insert(page.rows, at, { key = "companionStyle", label = "OPT_UI_STYLE", kind = "action",
					choices = function() return ns:UIStyleChoices() end,
					current = function() return ns:UIStyleChoice() end,
					describe = function() return L.OPT_UI_STYLE_DESC end,
					choose = function(id) ns:SetUIStyle(id) end })
			end
		end
	end
end

function ns:UIStyleCommand(rest)
	local word = tostring(rest or ""):match("^%s*(%S*)")
	word = (word or ""):lower()
	if word == "" then
		self:Print(self:F("UI_STYLE_USAGE", L["UI_STYLE_" .. self:UIStyleChoice()]))
		return nil
	end
	local id = self:SetUIStyle(word)
	if not id then
		self:Print(self:F("UI_STYLE_USAGE", L["UI_STYLE_" .. self:UIStyleChoice()]))
		return nil
	end
	self:Print(self:F("UI_STYLE_MSG", L["UI_STYLE_" .. id]))
	return id
end

-- ---------------------------------------------------------------------------
-- /qc debug bulle (2.8.2) : l'état réel de la bulle, à copier dans un retour
-- (cadre affiché, strate, niveau, alpha ; chaque texture : affichée, couche,
-- alpha, couleur, fichier, découpe). Bulle cachée : une réplique d'essai
-- s'affiche 8 s pour la capture d'écran.
-- ---------------------------------------------------------------------------
local DBGFR = {
	AZ_DEBUG_USAGE  = "/qc debug bulle — état de la bulle du compagnon (pour un retour)",
	AZ_DEBUG_HEAD   = "Bulle : style %s, %s, alpha %s (effectif %s), strate %s, niveau %s, %s×%s",
	AZ_DEBUG_NONE   = "Bulle : pas de compagnon affiché.",
	AZ_DEBUG_SAMPLE = "Essai de lecture : ce texte doit se lire sans effort, sur un fond net.",
	AZ_DEBUG_MODEL  = "Modèle : %s, %s×%s à (%s, %s), niveau %s (habit %s), cadrage %s",
	AZ_DEBUG_SHOWN  = "affichée",
	AZ_DEBUG_HIDDEN = "cachée",
}
local DBGEN = {
	AZ_DEBUG_USAGE  = "/qc debug bulle — companion bubble state (for a report)",
	AZ_DEBUG_HEAD   = "Bubble: style %s, %s, alpha %s (effective %s), strata %s, level %s, %s×%s",
	AZ_DEBUG_NONE   = "Bubble: no companion on screen.",
	AZ_DEBUG_SAMPLE = "Reading test: this text should read easily, on a clean background.",
	AZ_DEBUG_MODEL  = "Model: %s, %s×%s at (%s, %s), level %s (skin %s), framing %s",
	AZ_DEBUG_SHOWN  = "shown",
	AZ_DEBUG_HIDDEN = "hidden",
}
ns.RegisterStrings(DBGFR, DBGEN)
if ns.KEEP_STRINGS then ns.AZEROTH_DEBUG_STRINGS = { fr = DBGFR, en = DBGEN } end

local function Num(v) v = tonumber(v); return v and string.format("%.2f", v) or "?" end
local function Get(obj, name, ...)
	local fn = obj and obj[name]
	if type(fn) ~= "function" then return nil end
	local r = { pcall(fn, obj, ...) }
	if not r[1] then return nil end
	return unpack(r, 2)
end

-- Une ligne par texture (ou texte) de la bulle
function ns.AzerothRegionLine(name, region)
	if not region then return name .. ": -" end
	local layer, sub = Get(region, "GetDrawLayer")
	local isText = Get(region, "GetObjectType") == "FontString"
	local r, g, b, a
	if isText then r, g, b, a = Get(region, "GetTextColor") else r, g, b, a = Get(region, "GetVertexColor") end
	local parts = { name .. ":", Get(region, "IsShown") and "shown" or "hidden",
		"visible=" .. tostring(Get(region, "IsVisible") and true or false),
		tostring(layer or "?") .. "/" .. tostring(sub or 0), "alpha=" .. Num(Get(region, "GetAlpha")),
		"rgba=" .. Num(r) .. "," .. Num(g) .. "," .. Num(b) .. "," .. Num(a) }
	if not isText then
		parts[#parts + 1] = "tex=" .. tostring((Get(region, "GetTexture")))
		local c = { Get(region, "GetTexCoord") }
		if #c >= 4 then parts[#parts + 1] = "coord=" .. Num(c[1]) .. "," .. Num(c[2]) .. "," .. Num(c[3]) .. "," .. Num(c[4]) end
	elseif region.GetText then
		parts[#parts + 1] = "text=" .. tostring(Get(region, "GetText") or ""):sub(1, 24)
	end
	return table.concat(parts, " ")
end

function ns:AzerothDebugBubble()
	local lines = {}
	local frame = self.companionFrame
	if not frame and self.EnsureCompanionFrame and self.CompanionUpdateVisibility and self:CompanionUpdateVisibility() then
		frame = self:EnsureCompanionFrame()
	end
	local bubble = frame and self.EnsureCompanionBubble and self:EnsureCompanionBubble()
	if not bubble then
		lines[1] = L.AZ_DEBUG_NONE
		for _, line in ipairs(lines) do self:Print(line) end
		return lines
	end
	if not bubble:IsShown() then
		bubble:SetText(L.AZ_DEBUG_SAMPLE)
		bubble:Show()
		self.companionBubbleUntil = Clock() + 8
		if self.NotifyGlowArm then self:NotifyGlowArm() end
	end
	lines[#lines + 1] = self:F("AZ_DEBUG_HEAD", (bubble.forgeBubble and "forge") or "sobre",
		bubble:IsShown() and L.AZ_DEBUG_SHOWN or L.AZ_DEBUG_HIDDEN, Num(Get(bubble, "GetAlpha")),
		Num(Get(bubble, "GetEffectiveAlpha")), tostring(Get(bubble, "GetFrameStrata")), tostring(Get(bubble, "GetFrameLevel")),
		Num(Get(bubble, "GetWidth")), Num(Get(bubble, "GetHeight")))
	local list = {
		{ "sobre.bg", bubble.bg }, { "sobre.rule", bubble.rule }, { "sobre.tail", bubble.tail },
		{ "sobre.text", bubble.text },
	}
	if type(bubble.border) == "table" then list[#list + 1] = { "sobre.border.top", bubble.border.top } end
	-- 3.1.0 : la bulle forgée (nom de qui parle, filet, reflet)
	local forge = bubble.forgeTalk
	if forge then
		for _, pair in ipairs({ { "forge.name", forge.name }, { "forge.rule", forge.rule or bubble.rule },
			{ "forge.sheen", forge.sheen } }) do list[#list + 1] = pair end
	end
	for _, pair in ipairs(list) do lines[#lines + 1] = ns.AzerothRegionLine(pair[1], pair[2]) end
	local model = frame.model
	if model then
		local base = frame.modelBase or {}
		local ringSkin = ns.CompanionRingSkin(frame)
		lines[#lines + 1] = self:F("AZ_DEBUG_MODEL", model:IsShown() and L.AZ_DEBUG_SHOWN or L.AZ_DEBUG_HIDDEN,
			Num(Get(model, "GetWidth")), Num(Get(model, "GetHeight")), tostring(base.x), tostring(base.y),
			tostring(Get(model, "GetFrameLevel")), tostring(ringSkin and Get(ringSkin, "GetFrameLevel") or "-"),
			tostring(model.framingZoom))
	end
	for _, line in ipairs(lines) do self:Print(line) end
	return lines
end

function ns:AzerothDebugCommand(rest)
	local word = tostring(rest or ""):match("^%s*(%S*)")
	word = (word or ""):lower()
	if word == "bulle" or word == "bubble" then return self:AzerothDebugBubble() end
	self:Print(L.AZ_DEBUG_USAGE)
	return nil
end

if ns.EXTRA_COMMANDS then
	ns.EXTRA_COMMANDS["style"] = function(self, rest) self:UIStyleCommand(rest) end
	-- /qc debug bulle (une autre commande « debug » existante garde le reste)
	local debugBase = ns.EXTRA_COMMANDS["debug"]
	ns.EXTRA_COMMANDS["debug"] = function(self, rest, ...)
		local word = (tostring(rest or ""):match("^%s*(%S*)") or ""):lower()
		if debugBase and word ~= "bulle" and word ~= "bubble" then return debugBase(self, rest, ...) end
		return self:AzerothDebugCommand(rest)
	end
end
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_QUICK" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_STYLE")
		end
	end
end

if ns.Mark then ns.Mark("AzerothStyle") end
