-- WinterVeil.lua -- thème du Voile d'hiver (QuestCompanion 2.14.0) : décor, saison, boule de neige
--
-- Pas un nouveau style : le style Azeroth, plus un décor de saison posé
-- par-dessus (maquettes validées le 10/11/2026) :
--   * le carnet : une guirlande lumineuse sous la plaque d'en-tête, trois
--     flocons discrets sur le parchemin (sous les textes), un cadeau et le
--     renne des hauts faits de part et d'autre du titre « Carnet de voyage » ;
--   * le cadre du compagnon : une guirlande en 3D (modèle du client, sans
--     fond) le long du haut de l'anneau, des flocons aux coins et une neige
--     qui tombe doucement (bêta 6), l'anneau givré (réglage « Cadre givré ») ;
--   * la capture : le filet devient une boule de neige (icône du bouton,
--     bandeaux), et la scène lance une boule de neige qui éclate en flocons
--     sur la créature au lieu du filet, « Tout capturer » aussi (une boule
--     par case). La logique de capture ne change pas.
-- Écartés à la maquette : sapin en vitrine, cadeaux ou chaussettes près du
-- garde-manger ou du compagnon.
-- Quand : réglage « Décor du Voile d'hiver » (page Compagnon de route, sous
-- le style) et /qc noel auto|on|off. Automatique : du 15 décembre au
-- 2 janvier inclus (à cheval sur le nouvel an) ; Toujours ; Jamais. Le décor
-- ne se montre qu'en style Azeroth (en Sobre, rien). Le changement
-- s'applique tout de suite, sans /reload.
-- Images : celles du client, par leur FileDataID (jamais livrées) :
--   235484 (calendrier, Voile d'hiver « en cours », 128×128 : la guirlande
--   occupe les 104×36 px du haut, avec son ciel enneigé), 236121 (flocon
--   blanc, 512×512), 133202 (cadeau), 236707 (renne, haut fait), 132387
--   (INV_Ammo_Snowball), modèle 199600 (guirlande lumineuse).
-- Les autres modules (compagnons de saison) lisent ns:WinterVeilSeason(now)
-- et ns:WinterVeilActive() : noms et signatures à garder.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

-- 2.14.0 : la fenêtre de la saison, bornes comprises (passe le nouvel an)
ns.WINTER_VEIL = { from = { month = 12, day = 15 }, to = { month = 1, day = 2 } }
ns.WINTER_VEIL_MODES = { "auto", "on", "off" }
ns.WINTER_VEIL_DEFAULT = "auto"
-- les images du client (FileDataID) et leurs découpes
ns.WINTER_VEIL_ART = {
	lights   = { file = 235484, c = { 0, 104 / 128, 0, 36 / 128 }, w = 104, h = 36 },
	flake    = { file = 236121 },
	present  = { file = 133202, c = { 0.08, 0.92, 0.08, 0.92 } },
	reindeer = { file = 236707, c = { 0.08, 0.92, 0.08, 0.92 } },
	snowball = { file = 132387, c = { 0.08, 0.92, 0.08, 0.92 } },
	-- 2.14.0 (bêta 3) : la boule seule (mesurée sur l'icône 64×64 : centre à
	-- 44 % × 41 %, rayon 28 %), pour celle qu'on lance : découpée au carré
	-- autour d'elle et arrondie par le masque rond du client, plus de coins
	-- sombres
	ball     = { file = 132387, c = { 0.16, 0.72, 0.13, 0.69 } },
}
-- le masque rond du client (déjà utilisé par AzerothStyle.lua, FeatsCosmetics.lua)
ns.WINTER_VEIL_ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- le carnet : hauteur de la guirlande (sous le métal de la plaque), icônes
-- du titre, flocons (ancre, décalage, côté, opacité), sur la page ou la colonne
-- 2.14.0 (bêta 3) : la guirlande était trop fine (14 px, bulbes de 4 px) et
-- passait sous le joint de métal entre la colonne et la page. Deux bandes
-- de 28 px (bulbes ≈ 13 px), chacune pendue au bas de la barre de métal,
-- l'une sur la colonne, l'autre sur la page : elles s'arrêtent avant le
-- joint (lightsJoint) et avant les volutes des coins de la page
-- (lightsCurl), à lightsInset du bois ; sur la colonne, après son intitulé
-- (lightsGap), qui garde son parchemin nu. Posées sur la colonne et la page
-- (couche BORDER, comme les flocons) : sous leurs textes, sans souris.
-- 2.14.0 (bêta 4) : la bande de la colonne commençait après son intitulé
-- (« CARNET ») : un trou à gauche, une guirlande qui paraissait décentrée
-- (25.png). Elle court désormais sur toute la colonne. L'intitulé de la
-- colonne, qu'elle couvrirait, est caché tant que la guirlande est là (rendu
-- sans elle) : le titre de la fenêtre dit déjà « Carnet de voyage ».
-- 2.14.0 (bêta 5) : deux bandes coupées au joint et sous les volutes
-- laissaient un trou d'une cinquantaine de px autour du poteau de métal
-- entre la colonne et la page, et la fin de la page nue (29.png). Une seule
-- bande désormais, d'un bord intérieur du bois à l'autre (début de la
-- colonne → fin de la page), à lightsEdge px de chaque bout, pendue au bas
-- de la barre de métal : elle passe par-dessus le poteau du joint et les
-- volutes (posée sur le décor, au-dessus du calque du bois et du métal ;
-- rien d'autre dans ses 28 px que l'intitulé caché).
ns.WINTER_VEIL_JOURNAL = {
	lightsH = 28, lightsEdge = 8,
	iconSize = 18, iconGap = 6,
	-- 2.14.0 (bêta 5) : les flocons sous la bande (haut de la page, haut de
	-- la colonne) seraient recouverts : descendus sous elle, sur la page
	flakes = {
		{ on = "content", point = "TOPRIGHT", x = -34, y = -46, size = 30, alpha = 0.42 },
		{ on = "content", point = "TOPRIGHT", x = -76, y = -62, size = 16, alpha = 0.36 },
		{ on = "content", point = "TOPRIGHT", x = -118, y = -44, size = 14, alpha = 0.38 },
	},
}
-- le cadre du compagnon : la guirlande 3D (bande au ras du haut de l'anneau ;
-- caméra à régler en jeu : cam, position, cap) et ses deux flocons.
-- 2.14.0 (bêta 3) : en bêta 2 (118×34, cam 1, centre 6 px au-dessus du
-- cadre), elle faisait ~130 px de large, des bulbes de ~16 px qui pendaient
-- hors de l'anneau à gauche et à droite, le fil ~20 px au-dessus du cadre.
-- 2.14.0 (bêta 4) : en bêta 3 (108×40, cam 1,6, sur le centre de l'anneau),
-- capture 21.png (échelle 1,1 mesurée sur la plaque du nom, 112 px) : la
-- guirlande était 3 px à droite (l'anneau est décalé de RING_X pour centrer
-- son ouverture, mais l'or visible, lui, est centré sur le cadre), son fil en
-- V (bouts 20 px au-dessus du centre du modèle, milieu au centre), des
-- bulbes de ~18 px qui pendaient dans l'ouverture, le jaune fondu dans l'or.
-- Mesures en unités du modèle (unité = h / cam, en px) : un brin fait
-- span = 3,75 de large, ses bouts sont wireTop = 0,8 au-dessus du centre, le
-- milieu du fil sag = 0,07, le bas des bulbes drop = 0,65 en dessous, un
-- bulbe bulbH = 0,73 de haut. Désormais deux brins côte à côte (swags), en
-- festons accrochés aux coins et au milieu du cadre, des bulbes de ~8,5 px
-- (bulb, en px) : un brin de ~44 px, les deux de ~87 px (l'or visible fait
-- ~91 px) ; centrés sur le cadre (x depuis son centre, plus sur l'anneau),
-- le milieu des fils sur le bord doré du haut (y : centre des modèles,
-- depuis le haut du cadre). 199603 (trois guirlandes) écartée : la même
-- taille de bulbe, mais trois fois plus large que le cadre.
-- 2.14.0 (bêta 5) : en bêta 4, des bulbes de ~4 px (27.png), deux fois plus
-- petits que prévu. Chaque brin avait un cadre de modèle à peine plus large
-- que lui (52×30) : la caméra du client cadre alors la guirlande sur la
-- largeur du cadre, plus sur sa hauteur, et l'unité h / cam ne tient plus
-- (bêta 2, 118×34, et bêta 3, 108×40, mesurées sur la hauteur : 3,8 h / cam
-- px par brin). Le cadre de chaque brin garde donc au moins fit × h de large
-- (les cadres se chevauchent, sans fond : rien ne se voit) et la hauteur
-- règle la taille. Bulbes de 11,5 px (≈ 12,5 px à l'écran à l'échelle 1,1
-- du joueur), entre les ~4 px de la bêta 4 et les ~18 px de la bêta 3 ; les
-- deux brins (~118 px) couvrent la plaque du nom (112 px), centrés, le
-- milieu des fils sur le bord doré du haut (y = 0).
-- Réglage en jeu : /qc noel cadre <bulbe> <x> <y> <brins> <cap> (session).
-- 2.14.0 (bêta 6) : « une seule guirlande de cette taille, centrée » (31.png) :
-- un seul brin (~59 px), mêmes bulbes de 11,5 px, au milieu du cadre (x = 0),
-- le milieu du fil sur le bord doré du haut (y = 0).
-- 2.14.0 (bêta 7) : en bêta 6 (34.png, échelle 1,1), le milieu du fil
-- flottait ~4 px au-dessus du bord doré du haut, les bulbes pendaient
-- surtout au-dessus de lui. 2.14.1 : y = -20, réglé en jeu par l'utilisateur
-- (/qc noel cadre - - -20, 10/11 ; -9 ne suffisait pas). Avant : le milieu du fil
-- sur le milieu du bord doré, les bulbes qui pendent sur son bord et juste
-- dans l'ouverture.
-- Les flocons : en bêta 5, deux flocons de 11 et 14 px à 0,65-0,75 posés sur
-- l'or de l'anneau ne se voyaient pas (« Tu devais pas mettre des flocons
-- aussi ? »). Quatre flocons fixes aux coins du cadre, hors de l'anneau
-- (x, y depuis le haut du cadre, centre), plus grands et presque opaques ;
-- et une neige qui tombe doucement autour (snow) : quelques petits flocons
-- qui descendent du haut de l'anneau jusqu'à la plaque, chacun en boucle
-- (groupe d'animations du client : translation + fondus, sans OnUpdate),
-- décalés dans le temps. x : départ depuis le centre du cadre, dx : dérive,
-- fall : chute (px), time : durée d'une chute (s), delay : attente avant.
ns.WINTER_VEIL_COMPANION = {
	model = 199600, swags = 1, bulb = 11.5, x = 0, y = -20, h = 30, facing = 0, fit = 3.5,
	span = 3.75, wireTop = 0.8, sag = 0.07, drop = 0.65, bulbH = 0.73,
	flakes = {
		{ x = -60, y = -14, size = 20, alpha = 0.95 },
		{ x = 60, y = -20, size = 16, alpha = 0.9 },
		{ x = -60, y = -66, size = 15, alpha = 0.9 },
		{ x = 60, y = -60, size = 19, alpha = 0.95 },
	},
	snow = {
		top = 4, fall = 78, alpha = 0.85, fadeIn = 0.2, fadeOut = 0.3,
		{ x = -58, dx = 5, size = 9, time = 6.0, delay = 0 },
		{ x = -34, dx = -4, size = 7, time = 7.2, delay = 2.4 },
		{ x = 6, dx = 6, size = 8, time = 6.6, delay = 1.2 },
		{ x = 36, dx = -5, size = 7, time = 7.8, delay = 3.6 },
		{ x = 60, dx = 4, size = 9, time = 5.6, delay = 4.8 },
	},
}
ns.WINTER_VEIL_COMPANION_DEFAULT = {}
for key, value in pairs(ns.WINTER_VEIL_COMPANION) do ns.WINTER_VEIL_COMPANION_DEFAULT[key] = value end
-- 2.14.0 (bêta 6) : le cadre givré (pas de cadre de Noël dans le client).
-- 2.14.0 (bêta 7) : c'est désormais l'allure Azeroth du cadre « Givre »
-- (AZEROTH_RING_TINTS.frost dans AzerothStyle.lua : anneau désaturé teinté
-- argent-bleu, halo Relic-Frost-TraitGlowRing en ADD). Pendant la saison
-- (ou /qc noel on), le cadre Givre est offert à tous (WINTER_VEIL_GIFT) ;
-- réglage « Cadre givré » coché : l'allure Givre l'emporte sur le cadre
-- choisi tant que le décor est là ; décoché : le cadre choisi garde sa teinte.
ns.WINTER_VEIL_GIFT = "frost"
-- l'or visible du cadre Azeroth (21.png, en px du cadre) : haut du bord doré,
-- haut de l'ouverture (depuis le haut du cadre), largeur
-- 2.14.0 (bêta 7) : remesuré sur 34.png (échelle 1,1, le bas du bord doré
-- = haut de l'ouverture, 16,6 px sous le haut du cadre) : le bord doré du
-- haut va de -5 à -17 (l'atlas a une marge transparente au-dessus), pas de
-- +2 à -6 comme estimé en bêta 4.
-- 2.14.1 : recalé sur le réglage en jeu (y = -20 posé sur l'or, 10/11) :
-- les mesures faites sur captures (-5..-17) plaçaient l'or trop haut
ns.WINTER_VEIL_RING_GOLD = { top = -14, inner = -26, w = 91 }
-- la scène de capture : la boule de neige (taille, tours en vol), son
-- éclatement en flocons (nombre, durée, portée, taille)
-- 2.14.0 (bêta 3) : un peu plus soigné, mêmes durées. La boule ralentit un
-- peu en fin de course (ease), rapetisse en s'éloignant (scaleFrom →
-- scaleTo), tourne d'un demi-tour (spin, en demi-tours) ; une traîne de
-- petits flocons la suit (trail, trailGap : écart en part du vol) ; à
-- l'arrivée, une bouffée de neige (la boule, en lumière additive, qui
-- grandit et s'efface : puffScale, puffTime en part de burst) et les
-- flocons qui s'écartent en retombant un peu (fall px).
ns.WINTER_VEIL_SNOWBALL = { size = 30, spin = 1, flakes = 10, burst = 0.6, reach = 70, flakeSize = 15,
	ease = 0.25, scaleFrom = 1.25, scaleTo = 0.9, trail = 4, trailGap = 0.07, trailSize = 9,
	puffScale = 2.4, puffTime = 0.6, fall = 14,
	-- « Tout capturer » : la boule d'une case, ses flocons
	tileSize = 20, tileFlakes = 6, tileReach = 30, tileFlakeSize = 11 }

local FR = {
	OPT_WINTER_VEIL         = "Décor du Voile d'hiver",
	OPT_WINTER_VEIL_DESC    = "Guirlandes et flocons sur le carnet et le cadre du compagnon, boule de neige à la place du filet. Avec le style Azeroth seulement.",
	OPT_WINTER_VEIL_SOBRE   = "Le décor ne se voit qu'avec le style Azeroth.",
	WINTER_VEIL_auto        = "Automatique",
	WINTER_VEIL_auto_HINT   = "du 15 décembre au 2 janvier",
	WINTER_VEIL_on          = "Toujours",
	WINTER_VEIL_off         = "Jamais",
	WINTER_VEIL_USAGE       = "/qc noel auto|on|off (actuel : %s). Réglages en jeu : /qc noel cadre, /qc noel metzen",
	WINTER_VEIL_MSG         = "Décor du Voile d'hiver : %s.",
	WINTER_VEIL_MSG_SOBRE   = "Décor du Voile d'hiver : %s. Il ne se voit qu'avec le style Azeroth (/qc style azeroth).",
	HELP_NOEL               = "/qc noel auto|on|off — décor du Voile d'hiver (guirlandes, flocons, boule de neige)",
	-- 2.14.0 (bêta 3) : le pied de la scène de capture (au lieu de « Le filet bouge… »)
	WINTER_VEIL_STAGE_FLY   = "La boule de neige vole…",
	WINTER_VEIL_STAGE_SHAKE = "Sous la neige, ça remue…",
	-- 2.14.0 (bêta 4) : réglage en jeu de la guirlande du cadre
	-- 2.14.0 (bêta 6) : le cadre givré
	OPT_WINTER_VEIL_FROST      = "Cadre givré (Voile d'hiver)",
	-- 2.14.0 (bêta 7) : l'allure du cadre Givre, offert pendant la saison
	OPT_WINTER_VEIL_FROST_DESC = "Pendant le décor du Voile d'hiver, l'anneau du portrait prend l'allure du cadre Givre (argent givré, halo glacé), tant que tu ne choisis pas un autre cadre. Décoché : le cadre choisi garde sa couleur. Le cadre Givre est offert à tous pendant le Voile d'hiver.",
	WINTER_VEIL_FROST_GIFT     = "Voile d'hiver",
	WINTER_VEIL_TUNE_LIGHTS = "Guirlande du cadre : bulbe %s px, x %s, y %s, %s brin(s), cap %s (largeur %.0f px, caméra %.2f). Régler : /qc noel cadre <bulbe> <x> <y> <brins> <cap> (- garde une valeur, defaut remet tout).",
}
local EN = {
	OPT_WINTER_VEIL         = "Winter Veil decorations",
	OPT_WINTER_VEIL_DESC    = "Lights and snowflakes on the journal and the companion frame, a snowball instead of the net. Azeroth style only.",
	OPT_WINTER_VEIL_SOBRE   = "The decorations only show with the Azeroth style.",
	WINTER_VEIL_auto        = "Automatic",
	WINTER_VEIL_auto_HINT   = "December 15 to January 2",
	WINTER_VEIL_on          = "Always",
	WINTER_VEIL_off         = "Never",
	WINTER_VEIL_USAGE       = "/qc noel auto|on|off (current: %s). Live tuning: /qc noel frame, /qc noel metzen",
	WINTER_VEIL_MSG         = "Winter Veil decorations: %s.",
	WINTER_VEIL_MSG_SOBRE   = "Winter Veil decorations: %s. They only show with the Azeroth style (/qc style azeroth).",
	HELP_NOEL               = "/qc noel auto|on|off — Winter Veil decorations (lights, snowflakes, snowball)",
	WINTER_VEIL_STAGE_FLY   = "The snowball is flying…",
	WINTER_VEIL_STAGE_SHAKE = "Something stirs under the snow…",
	OPT_WINTER_VEIL_FROST      = "Frosted frame (Winter Veil)",
	OPT_WINTER_VEIL_FROST_DESC = "While the Winter Veil decorations show, the portrait ring takes the Frost frame's look (frosty silver, icy glow) until you pick another frame. Unchecked: your chosen frame keeps its colour. The Frost frame is free for everyone during Winter Veil.",
	WINTER_VEIL_FROST_GIFT     = "Winter Veil",
	WINTER_VEIL_TUNE_LIGHTS = "Frame lights: bulb %s px, x %s, y %s, %s strand(s), facing %s (width %.0f px, camera %.2f). Tune: /qc noel frame <bulb> <x> <y> <strands> <facing> (- keeps a value, default resets all).",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.WINTER_VEIL_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Method(obj, name, ...)
	if obj and type(obj[name]) == "function" then return pcall(obj[name], obj, ...) end
	return false
end
local function Clamp01(x) if x < 0 then return 0 elseif x > 1 then return 1 end return x end
local function EaseOut(x) x = Clamp01(x); return 1 - (1 - x) * (1 - x) end

-- Pose une image du client (FileDataID) et sa découpe ; false si refusée
local function SetFile(tex, spec)
	if not (tex and spec) then return false end
	local ok, result = pcall(tex.SetTexture, tex, spec.file)
	if not ok or result == false then return false end
	if type(tex.GetTexture) == "function" then
		local done, current = pcall(tex.GetTexture, tex)
		if done and current == nil then return false end
	end
	local c = spec.c
	if c then tex:SetTexCoord(c[1], c[2], c[3], c[4]) else tex:SetTexCoord(0, 1, 0, 1) end
	return true
end
local function NewFile(parent, layer, sub, spec)
	local tex = parent:CreateTexture(nil, layer, nil, sub)
	if not SetFile(tex, spec) then tex:Hide(); return nil end
	return tex
end

-- Largeur réelle d'un texte
local function Measure(fs)
	local ok, w
	if fs.GetUnboundedStringWidth then ok, w = pcall(fs.GetUnboundedStringWidth, fs) end
	if not (ok and tonumber(w)) and fs.GetStringWidth then ok, w = pcall(fs.GetStringWidth, fs) end
	return (ok and tonumber(w)) or 0
end

-- ---------------------------------------------------------------------------
-- La saison et le réglage
-- ---------------------------------------------------------------------------
local function DayKey(t) return (tonumber(t.month) or 0) * 100 + (tonumber(t.day) or 0) end

-- Dans la fenêtre du Voile d'hiver ? `now` : un horodatage (time()), par
-- défaut maintenant. Sans date() ni time() : hors saison.
function ns:WinterVeilSeason(now)
	local dateFn = G("date") or (os and os.date)
	local timeFn = G("time") or (os and os.time)
	if type(dateFn) ~= "function" then return false end
	now = tonumber(now)
	if not now and type(timeFn) == "function" then
		local ok, value = pcall(timeFn)
		now = ok and tonumber(value) or nil
	end
	if not now then return false end
	local ok, t = pcall(dateFn, "*t", now)
	if not (ok and type(t) == "table" and t.month and t.day) then return false end
	local w = ns.WINTER_VEIL
	local k, a, b = DayKey(t), DayKey(w.from), DayKey(w.to)
	if a <= b then return k >= a and k <= b end
	return k >= a or k <= b
end

-- Le choix du joueur (réglage), valide
function ns:WinterVeilChoice()
	local choice = self:DB().winterVeil
	for _, id in ipairs(ns.WINTER_VEIL_MODES) do if id == choice then return id end end
	return ns.WINTER_VEIL_DEFAULT
end

-- La saison, relue au plus une fois par minute (le compagnon la demande souvent)
local seasonCache = {}
local function SeasonNow()
	local timeFn = G("time") or (os and os.time)
	local ok, now = false, nil
	if type(timeFn) == "function" then ok, now = pcall(timeFn) end
	now = ok and tonumber(now) or nil
	local key = now and math.floor(now / 60) or false
	if seasonCache.key ~= key then
		seasonCache.key, seasonCache.value = key, ns:WinterVeilSeason(now) and true or false
	end
	return seasonCache.value
end

-- Le décor est-il là ? Style Azeroth affiché ET réglage (auto : la saison)
function ns:WinterVeilActive()
	if not (self.AzerothOn and self:AzerothOn()) then return false end
	local choice = self:WinterVeilChoice()
	if choice == "on" then return true end
	if choice == "off" then return false end
	return SeasonNow()
end

function ns:WinterVeilChoices()
	local list = {}
	for _, id in ipairs(ns.WINTER_VEIL_MODES) do
		list[#list + 1] = { value = id, label = L["WINTER_VEIL_" .. id], hint = L["WINTER_VEIL_" .. id .. "_HINT"] }
	end
	return list
end

-- Choix du décor (réglage, commande) ; nil si inconnu
local ALIASES = { toujours = "on", oui = "on", always = "on", jamais = "off", non = "off", never = "off",
	automatique = "auto", automatic = "auto" }
function ns:SetWinterVeil(mode)
	mode = type(mode) == "string" and mode:lower() or nil
	mode = mode and (ALIASES[mode] or mode)
	local valid = false
	for _, id in ipairs(ns.WINTER_VEIL_MODES) do if id == mode then valid = true end end
	if not valid then return nil end
	self:DB().winterVeil = mode
	self:WinterVeilApply()
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return mode
end

-- ---------------------------------------------------------------------------
-- Le carnet : guirlande sous la plaque, icônes du titre, flocons
-- ---------------------------------------------------------------------------
local function BuildJournalDecor(frame)
	local J, A = ns.WINTER_VEIL_JOURNAL, ns.WINTER_VEIL_ART
	local over = frame.azOver
	local d = CreateFrame("Frame", nil, over)
	d:SetAllPoints(frame)
	d:SetFrameLevel((over:GetFrameLevel() or 1) + 2)
	d:EnableMouse(false)
	-- la guirlande : posée (et reposée) par LayJournalLights
	d.lights = {}
	-- le cadeau et le renne, de part et d'autre du titre (placés à chaque rafraîchissement)
	d.present = NewFile(d, "OVERLAY", 1, A.present)
	d.reindeer = NewFile(d, "OVERLAY", 1, A.reindeer)
	for _, icon in ipairs({ d.present, d.reindeer }) do icon:SetSize(J.iconSize, J.iconSize) end
	-- les flocons : sur la page ou la colonne, sous leurs textes (couche
	-- BORDER du parchemin : les cadres enfants, textes compris, passent devant)
	d.flakes = {}
	for _, spec in ipairs(J.flakes) do
		local host = frame[spec.on]
		local tex = host and NewFile(host, "BORDER", 7, A.flake)
		if tex then
			tex:SetSize(spec.size, spec.size)
			tex:SetPoint("CENTER", host, spec.point, spec.x, spec.y)
			tex:SetAlpha(spec.alpha)
			tex.wvSpec = spec
			d.flakes[#d.flakes + 1] = tex
		end
	end
	frame.wvDecor = d
	return d
end

-- 2.14.0 (bêta 5) : la guirlande, une seule bande de tuiles de 104×36
-- ramenées à la hauteur de la bande, la dernière recoupée ; sur le décor
-- (au-dessus du bois, du métal, du poteau du joint et des volutes), ancrée
-- au cadre. Reposée à chaque rafraîchissement (la fenêtre peut changer de
-- largeur) : les tuiles sont réutilisées, celles en trop cachées.
local function LayJournalLights(frame, d)
	local J, A = ns.WINTER_VEIL_JOURNAL, ns.WINTER_VEIL_ART
	local band = ns.WinterVeilJournalBand(frame)
	local h = J.lightsH
	local tileW = math.floor(A.lights.w * h / A.lights.h + 0.5)
	local c = A.lights.c
	local x, count = band.x0, 0
	while x < band.x1 do
		local w = math.min(tileW, band.x1 - x)
		count = count + 1
		local tex = d.lights[count]
		if not tex then
			tex = NewFile(d, "ARTWORK", 1, A.lights)
			if not tex then count = count - 1; break end
			d.lights[count] = tex
		end
		tex:SetSize(w, h)
		tex:ClearAllPoints()
		tex:SetPoint("TOPLEFT", frame, "TOPLEFT", x, band.y)
		tex:SetTexCoord(c[1], c[1] + (c[2] - c[1]) * w / tileW, c[3], c[4])
		tex:Show()
		x = x + w
	end
	for index = count + 1, #d.lights do d.lights[index]:Hide() end
	d.band, d.lightsCount = band, count
	return count
end

-- Le cadeau à gauche du titre, le renne à droite, sans toucher au texte
local function PlaceTitleIcons(frame, d)
	local title = frame.azPlate and frame.azPlate.title
	local J = ns.WINTER_VEIL_JOURNAL
	if not title then
		for _, icon in ipairs({ d.present, d.reindeer }) do if icon then icon:Hide() end end
		return nil
	end
	local half = math.floor(Measure(title) / 2 + 0.5)
	local off = half + J.iconGap + J.iconSize / 2
	if d.present then d.present:ClearAllPoints(); d.present:SetPoint("CENTER", title, "CENTER", -off, 0); d.present:Show() end
	if d.reindeer then d.reindeer:ClearAllPoints(); d.reindeer:SetPoint("CENTER", title, "CENTER", off, 0); d.reindeer:Show() end
	return off
end

-- 2.14.0 (bêta 5) : la bande de la guirlande, en coordonnées du cadre :
-- { x0, x1, y }. D'un bord intérieur du bois à l'autre (début de la colonne,
-- ou de la page sans colonne, → fin de la page), à lightsEdge px de chaque
-- bout ; y : le bas de la barre de métal (le haut de la colonne et de la page).
function ns.WinterVeilJournalBand(frame)
	local lay, J = ns.CARNET_LAYOUT, ns.WINTER_VEIL_JOURNAL
	local W = frame.azSize and tonumber(frame.azSize[1]) or tonumber(frame:GetWidth()) or 0
	return { x0 = lay.wood + J.lightsEdge, x1 = W - lay.wood - J.lightsEdge, y = -lay.band }
end

-- Montre ou cache le décor d'un carnet Azeroth ; rend s'il est montré
function ns:WinterVeilJournal(frame)
	frame = frame or self.journalFrame
	if not (frame and frame.azeroth and frame.azOver) then return nil end
	local on = self:WinterVeilActive()
	local d = frame.wvDecor
	if not on then
		if d then
			d:Hide()
			for _, tex in ipairs(d.flakes) do tex:Hide() end
			for _, tex in ipairs(d.lights) do tex:Hide() end
			if d.navLabelHidden and frame.navGroup then frame.navGroup:Show() end
			d.navLabelHidden = nil
		end
		return false
	end
	d = d or BuildJournalDecor(frame)
	d:Show()
	-- l'intitulé de la colonne, sous la guirlande : caché (rendu sans elle)
	if frame.navGroup then frame.navGroup:Hide(); d.navLabelHidden = true end
	for _, tex in ipairs(d.flakes) do tex:Show() end
	LayJournalLights(frame, d)
	PlaceTitleIcons(frame, d)
	return true
end

-- ---------------------------------------------------------------------------
-- Le cadre du compagnon : guirlande 3D au ras du haut de l'anneau, flocons
-- ---------------------------------------------------------------------------
-- 2.14.0 (bêta 4) : l'emprise de la guirlande (mesures de
-- WINTER_VEIL_COMPANION), y depuis le haut du cadre, x depuis son centre :
-- { unit, cam, swag (largeur d'un brin), w, left, right, wire (bouts du
-- fil), mid (milieu d'un fil), bottom (bas des bulbes), bulb, centers }
function ns.WinterVeilLightsBox()
	local C = ns.WINTER_VEIL_COMPANION
	local unit = (tonumber(C.bulb) or 8) / C.bulbH
	local n = math.max(1, math.min(3, math.floor(tonumber(C.swags) or 1)))
	local swag = C.span * unit
	local centers = {}
	for index = 1, n do centers[index] = C.x + (index - (n + 1) / 2) * swag end
	-- 2.14.0 (bêta 5) : largeur du cadre d'un brin (frameW), assez large pour
	-- que la caméra du client le cadre sur la hauteur (fit × h)
	local frameW = math.max(math.floor(swag + C.bulb + 0.5), math.floor((tonumber(C.fit) or 0) * C.h + 0.5))
	return { unit = unit, cam = C.h / unit, swag = swag, w = n * swag, left = C.x - n * swag / 2, right = C.x + n * swag / 2,
		wire = C.y + C.wireTop * unit, mid = C.y + C.sag * unit, bottom = C.y - C.drop * unit,
		bulb = C.bulbH * unit, centers = centers, count = n, frameW = frameW }
end

local function LightsFraming(m)
	local C = ns.WINTER_VEIL_COMPANION
	Method(m, "SetCamDistanceScale", ns.WinterVeilLightsBox().cam)
	Method(m, "SetPosition", 0, 0, 0)
	Method(m, "SetFacing", tonumber(C.facing) or 0)
end

-- Un brin : un modèle du client, sans fond, sans souris, par-dessus l'anneau
local function NewSwag(d)
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, d)
	if not (ok and model) then return nil end
	model:SetFrameLevel((d:GetFrameLevel() or 1) + 1)
	model:EnableMouse(false)
	Method(model, "SetKeepModelOnHide", true)
	model.framing = LightsFraming
	if ns.ModelKeepFraming then ns.ModelKeepFraming(model) end
	return model
end

-- Les brins à leur place (créés au besoin, les autres cachés)
local function PlaceSwags(frame, d)
	local C, box = ns.WINTER_VEIL_COMPANION, ns.WinterVeilLightsBox()
	d.swags = d.swags or {}
	for index = 1, math.max(box.count, #d.swags) do
		local model = d.swags[index]
		if index <= box.count then
			model = model or NewSwag(d)
			d.swags[index] = model
		end
		if model then
			if index <= box.count then
				model:SetSize(box.frameW, C.h)
				model:ClearAllPoints()
				model:SetPoint("CENTER", frame, "TOP", box.centers[index], C.y)
				if model.wvModel ~= C.model then
					if Method(model, "SetModel", C.model) then model.wvModel = C.model end
				end
				model:Show()
				LightsFraming(model)
			else
				model:Hide()
			end
		end
	end
	d.lights = d.swags[1]
	return box
end

-- 2.14.0 (bêta 6) : la neige qui tombe. Un flocon par groupe d'animations
-- du client (pas d'OnUpdate) : une translation (chute + dérive) et deux
-- fondus (apparition, disparition), en boucle ; l'attente (delay) décale les
-- flocons. Au repos le flocon est transparent (alpha 0) : seule l'animation
-- le montre. Sans animations dans le client : pas de neige qui tombe.
local function SnowAnim(tex, spec, S)
	if type(tex.CreateAnimationGroup) ~= "function" then return nil end
	local ok, group = pcall(tex.CreateAnimationGroup, tex)
	if not (ok and group) then return nil end
	Method(group, "SetLooping", "REPEAT")
	local delay = tonumber(spec.delay) or 0
	local fall = group:CreateAnimation("Translation")
	Method(fall, "SetOffset", spec.dx or 0, -S.fall)
	Method(fall, "SetDuration", spec.time)
	Method(fall, "SetStartDelay", delay)
	Method(fall, "SetSmoothing", "NONE")
	local fadeIn = group:CreateAnimation("Alpha")
	Method(fadeIn, "SetFromAlpha", 0)
	Method(fadeIn, "SetToAlpha", S.alpha)
	Method(fadeIn, "SetDuration", spec.time * S.fadeIn)
	Method(fadeIn, "SetStartDelay", delay)
	local fadeOut = group:CreateAnimation("Alpha")
	Method(fadeOut, "SetFromAlpha", S.alpha)
	Method(fadeOut, "SetToAlpha", 0)
	Method(fadeOut, "SetDuration", spec.time * S.fadeOut)
	Method(fadeOut, "SetStartDelay", delay + spec.time * (1 - S.fadeOut))
	group.fall, group.fadeIn, group.fadeOut = fall, fadeIn, fadeOut
	return group
end

local function BuildSnow(frame, d)
	local S, A = ns.WINTER_VEIL_COMPANION.snow, ns.WINTER_VEIL_ART
	d.snow = {}
	for index, spec in ipairs(S) do
		local tex = NewFile(d, "OVERLAY", 3, A.flake)
		if tex then
			tex:SetSize(spec.size, spec.size)
			tex:SetPoint("CENTER", frame, "TOP", spec.x, S.top)
			tex:SetAlpha(0)
			tex.wvAnim = SnowAnim(tex, spec, S)
			tex:Hide()
			d.snow[index] = tex
		end
	end
end

-- La neige tombe (true) ou s'arrête (false) ; rend l'état posé
local function SnowFalling(d, on)
	on = on and true or false
	for _, tex in ipairs(d.snow or {}) do
		local group = tex.wvAnim
		if on and group then
			tex:Show()
			local playing = false
			if type(group.IsPlaying) == "function" then
				local ok, value = pcall(group.IsPlaying, group)
				playing = ok and value and true or false
			end
			if not playing then Method(group, "Play") end
		else
			if group then Method(group, "Stop") end
			tex:Hide()
		end
	end
	d.snowing = on
	return on
end

local function BuildCompanionDecor(frame, skin)
	local C, A = ns.WINTER_VEIL_COMPANION, ns.WINTER_VEIL_ART
	local d = CreateFrame("Frame", nil, skin)
	d:SetAllPoints(frame)
	d:SetFrameLevel((skin:GetFrameLevel() or 1) + 2)
	d:EnableMouse(false)
	d.swags = {}
	d.flakes = {}
	-- 2.14.0 (bêta 6) : aux coins du cadre, depuis son centre (plus sur l'anneau)
	for index, spec in ipairs(C.flakes) do
		local tex = NewFile(d, "OVERLAY", 2, A.flake)
		if tex then
			tex:SetSize(spec.size, spec.size)
			tex:SetPoint("CENTER", frame, "TOP", spec.x, spec.y)
			tex:SetAlpha(spec.alpha)
			d.flakes[index] = tex
		end
	end
	BuildSnow(frame, d)
	frame.wvDecor = d
	return d
end

-- ---------------------------------------------------------------------------
-- 2.14.0 (bêta 6) : le cadre givré ; bêta 7 : le cadre Givre offert (WINTER_VEIL_GIFT)
-- ---------------------------------------------------------------------------
ns.RegisterDefaults({ winterVeilFrost = true })
function ns:WinterVeilFrostOn() return self:DB().winterVeilFrost ~= false end

-- 2.14.0 (bêta 7) : le cadre Givre offert pendant la saison (date du
-- Voile d'hiver, ou /qc noel on), à tous, en Sobre comme en Azeroth ; hors
-- saison il redevient verrouillé, sauf s'il a été gagné au coffre.
function ns:WinterVeilGiftOn()
	return self:WinterVeilChoice() == "on" or SeasonNow()
end

local function GiftDef()
	for _, def in ipairs(ns.COMPANION_FRAMES or {}) do
		if def.id == ns.WINTER_VEIL_GIFT then return def end
	end
	return nil
end

do
	local isUnlocked = ns.CompanionIsUnlocked
	-- Givre gagné pour de bon (coffre), saison mise à part
	function ns:WinterVeilGiftEarned()
		local def = GiftDef()
		return def ~= nil and isUnlocked(self, "frame", def) == true
	end
	function ns:CompanionIsUnlocked(kind, def, ...)
		if kind == "frame" and def and def.id == ns.WINTER_VEIL_GIFT and self:WinterVeilGiftOn() then return true end
		return isUnlocked(self, kind, def, ...)
	end

	-- Givre choisi grâce à la saison : le cadre d'avant est gardé, pour y
	-- revenir quand la saison finit (Givre pas gagné)
	local setStyle = ns.CompanionSetStyle
	function ns:CompanionSetStyle(kind, id, ...)
		local data = self:CompanionData()
		local before = data.frameStyle
		local def = setStyle(self, kind, id, ...)
		-- 2.14.1 : choisi pendant le décor : ce cadre-là s'affiche (plus Givre imposé)
		if def and kind == "frame" and self:WinterVeilActive() then data.winterFrameChoice = true end
		if def and kind == "frame" then
			if def.id ~= ns.WINTER_VEIL_GIFT then
				data.frameBeforeGift = nil
			elseif before ~= def.id and not self:WinterVeilGiftEarned() then
				data.frameBeforeGift = before
			end
		end
		return def
	end

	-- La saison finie, Givre pas gagné : retour au cadre d'avant (s'il est
	-- toujours là), sinon au premier (comme tout cadre verrouillé)
	local currentStyle = ns.CompanionCurrentStyle
	function ns:CompanionCurrentStyle(kind, ...)
		if kind == "frame" then
			local data = self:CompanionData()
			-- 2.14.1 : décor parti (fin de saison, réglage) : la prochaine saison
			-- repart avec Givre par défaut
			if data.winterFrameChoice and not self:WinterVeilActive() then data.winterFrameChoice = nil end
			if data.frameStyle == ns.WINTER_VEIL_GIFT then
				local gift = GiftDef()
				if gift and not self:CompanionIsUnlocked("frame", gift) then
					local back = data.frameBeforeGift and self:CompanionStyleDef("frame", data.frameBeforeGift)
					data.frameStyle = (back and self:CompanionIsUnlocked("frame", back)) and back.id or nil
					data.frameBeforeGift = nil
				elseif data.frameBeforeGift and self:WinterVeilGiftEarned() then
					data.frameBeforeGift = nil
				end
			end
		end
		return currentStyle(self, kind, ...)
	end

	-- la liste des cadres : Givre offert, marqué « Voile d'hiver »
	local choices = ns.CompanionChoices
	if choices then
		function ns:CompanionChoices(kind, ...)
			local list = choices(self, kind, ...)
			if kind == "frame" and type(list) == "table" and self:WinterVeilGiftOn() and not self:WinterVeilGiftEarned() then
				for _, entry in ipairs(list) do
					if entry.value == ns.WINTER_VEIL_GIFT and not entry.disabled then entry.hint = L.WINTER_VEIL_FROST_GIFT end
				end
			end
			return list
		end
	end

	-- l'allure de l'anneau : pendant le décor, réglage « Cadre givré »
	-- coché, celle de Givre, quel que soit le cadre choisi (le cadre passé
	-- en paramètre, lui, garde la sienne)
	local ringLook = ns.AzerothRingLook
	if ringLook then
		function ns:AzerothRingLook(def, ...)
			-- 2.14.1 : un cadre choisi pendant la saison l'emporte sur Givre
			if def == nil and self:WinterVeilActive() and self:WinterVeilFrostOn()
				and not self:CompanionData().winterFrameChoice then
				local gift = GiftDef()
				if gift then return ringLook(self, gift, ...) end
			end
			return ringLook(self, def, ...)
		end
	end
end

-- L'anneau repeint (cadre du compagnon et carnet) : la saison, le décor ou
-- le réglage ont changé
local function PaintRings(self)
	if self.CompanionPaintRing then self:CompanionPaintRing() end
	if self.CarnetPaintRing then self:CarnetPaintRing() end
end

-- 2.14.0 (bêta 5) : le cadre « nu ». En mode voyage, interface cachée
-- (26.png), l'habit du cadre (anneau, plaque) ne se voit plus, mais un
-- modèle 3D ne suit pas l'opacité de ses parents (B7, 2.11.0) : la guirlande
-- flottait au-dessus du compagnon. Elle se cache dès que l'habit ne se voit
-- plus (caché, ou opacité effective sous WINTER_VEIL_BARE_ALPHA), et revient
-- avec lui ; relu toutes les WINTER_VEIL_BARE_STEP s (ns:WinterVeilWatch).
ns.WINTER_VEIL_BARE_ALPHA = 0.1
ns.WINTER_VEIL_BARE_STEP = 0.25

-- Opacité effective d'une région (celle du client, sinon le produit des
-- opacités de ses parents)
local function EffectiveAlpha(region)
	if type(region.GetEffectiveAlpha) == "function" then
		local ok, alpha = pcall(region.GetEffectiveAlpha, region)
		if ok and tonumber(alpha) then return tonumber(alpha) end
	end
	local alpha, node, depth = 1, region, 0
	while node and depth < 20 do
		if type(node.GetAlpha) == "function" then
			local ok, a = pcall(node.GetAlpha, node)
			if ok and tonumber(a) then alpha = alpha * tonumber(a) end
		end
		node = type(node.GetParent) == "function" and node:GetParent() or nil
		depth = depth + 1
	end
	return alpha
end

local function Hidden(region)
	if not region then return false end
	if type(region.IsShown) == "function" and not region:IsShown() then return true end
	if type(region.IsVisible) == "function" then
		local ok, visible = pcall(region.IsVisible, region)
		if ok and visible == false then return true end
	end
	return false
end

-- L'habit du cadre (anneau, plaque) ne se voit pas ?
function ns:WinterVeilCompanionBare(frame)
	frame = frame or self.companionFrame
	local skin = frame and frame.azSkin
	if not skin or Hidden(frame) or Hidden(skin) then return true end
	return EffectiveAlpha(skin) < ns.WINTER_VEIL_BARE_ALPHA
end

local function ShowParts(d, shown)
	for _, tex in pairs(d.flakes or {}) do if shown then tex:Show() else tex:Hide() end end
	if not shown then for _, model in ipairs(d.swags or {}) do model:Hide() end end
end

-- 2.14.0 (bêta 6) : le compagnon estompé en combat (opacité de contexte < 1) :
-- la neige s'arrête (rien ne bouge autour du cadre pendant le combat)
local function Calm(self)
	if not self.CompanionContextAlpha then return true end
	local ok, alpha = pcall(self.CompanionContextAlpha, self)
	return not (ok and tonumber(alpha) and tonumber(alpha) < 1)
end

-- Montre ou cache le décor du compagnon ; rend s'il est montré
function ns:WinterVeilCompanion()
	local frame = self.companionFrame
	if not frame then return nil end
	local skin = frame.azSkin
	local on = skin and frame.uiStyle == "azeroth" and self:WinterVeilActive()
	local d = frame.wvDecor
	if not on then
		if d then
			d:Hide()
			for _, model in ipairs(d.swags or {}) do model:Hide() end
			SnowFalling(d, false)
			d.bare, d.calm = nil, nil
		end
		PaintRings(self)
		return false
	end
	d = d or BuildCompanionDecor(frame, skin)
	d:Show()
	-- 2.14.0 (bêta 5) : habit invisible (mode voyage) : ni guirlande ni flocons
	local bare = self:WinterVeilCompanionBare(frame)
	d.bare = bare
	-- 2.14.0 (bêta 6) : le givre suit le réglage ; le halo, l'habit
	-- 2.14.0 (bêta 7) : l'allure du cadre Givre (AzerothRingLook), le halo
	-- sur l'habit (caché avec lui)
	PaintRings(self)
	if bare then
		if not d.swags[1] then PlaceSwags(frame, d) end
		ShowParts(d, false)
		SnowFalling(d, false)
		d.calm = nil
		return false
	end
	ShowParts(d, true)
	PlaceSwags(frame, d)
	d.calm = Calm(self)
	SnowFalling(d, d.calm)
	return true
end

-- 2.14.0 (bêta 5) : l'habit a disparu (ou est revenu) depuis le dernier
-- passage : le décor suit. Rien n'est refait tant que rien ne change. Rend
-- true quand le décor a été repris.
-- 2.14.0 (bêta 6) : le combat aussi (la neige s'arrête, puis reprend).
function ns:WinterVeilWatch()
	local frame = self.companionFrame
	local d = frame and frame.wvDecor
	if not (d and d:IsShown()) then return false end
	local bare = self:WinterVeilCompanionBare(frame)
	if (d.bare and true or false) == bare then
		if bare then return false end
		local calm = Calm(self)
		if (d.calm and true or false) == calm then return false end
		d.calm = calm
		SnowFalling(d, calm)
		return true
	end
	self:WinterVeilCompanion()
	return true
end

-- 2.14.0 (bêta 7) : la saison commence ou finit en jeu : Givre offert ou
-- repris (relu chaque minute, comme la saison)
ns.Every("noel:givre", 60, function()
	if ns.winterVeilGift == nil or (ns:WinterVeilGiftOn() and true or false) == ns.winterVeilGift then return end
	local ok, err = pcall(ns.WinterVeilApply, ns)
	if not ok and ns.RecordError then ns:RecordError("noel:givre", err) end
end)

ns.Every("noel:cadre", ns.WINTER_VEIL_BARE_STEP, function()
	local ok, err = pcall(ns.WinterVeilWatch, ns)
	if not ok and ns.RecordError then ns:RecordError("noel:cadre", err) end
end)

-- 2.14.0 (bêta 4) : réglage en jeu de la guirlande du cadre (pour la
-- session) : /qc noel cadre <bulbe px> <x> <y> <brins> <cap> ; un « - »
-- garde la valeur ; « defaut » remet les valeurs livrées ; sans rien : les
-- valeurs actuelles. Rend la table réglée (nil si rien n'a changé).
local TUNE_KEYS = { "bulb", "x", "y", "swags", "facing" }
local RESET_WORDS = { defaut = true, ["défaut"] = true, default = true, reset = true }
function ns:WinterVeilTuneLights(rest)
	local C = ns.WINTER_VEIL_COMPANION
	local words = {}
	for word in tostring(rest or ""):gmatch("%S+") do words[#words + 1] = (word:gsub(",", ".")) end
	local changed = false
	if RESET_WORDS[(words[1] or ""):lower()] then
		for key, value in pairs(ns.WINTER_VEIL_COMPANION_DEFAULT) do C[key] = value end
		changed = true
	else
		for index, key in ipairs(TUNE_KEYS) do
			local value = tonumber(words[index])
			if value then C[key] = value; changed = true end
		end
	end
	if C.swags then C.swags = math.max(1, math.min(3, math.floor(C.swags))) end
	if changed then pcall(self.WinterVeilCompanion, self) end
	local box = ns.WinterVeilLightsBox()
	if self.Print then
		self:Print(self:F("WINTER_VEIL_TUNE_LIGHTS", C.bulb, C.x, C.y, C.swags, C.facing, box.w, box.cam))
	end
	return changed and C or nil
end

-- ---------------------------------------------------------------------------
-- La capture : la boule de neige à la place du filet
-- ---------------------------------------------------------------------------
-- Le glyphe du filet (bouton, bandeaux) : la boule de neige pendant le décor.
-- Les textures peintes sont retenues (clés faibles) pour être repeintes au
-- changement de réglage, de style ou de saison.
local glyphs = setmetatable({}, { __mode = "k" })
do
	local paint = ns.CaptureArtPaint
	if paint then
		function ns.CaptureArtPaint(tex, role, coords)
			if role == "icon" and tex then
				glyphs[tex] = true
				if ns:WinterVeilActive() and SetFile(tex, ns.WINTER_VEIL_ART.snowball) then
					tex.clientArt, tex.wvSnowball = true, true
					if tex.SetDesaturated then tex:SetDesaturated(false) end
					return "client"
				end
				tex.wvSnowball = nil
			end
			return paint(tex, role, coords)
		end
	end
end

-- Repeint les glyphes qui ne sont plus du bon côté
function ns:WinterVeilRepaintGlyphs()
	local on = self:WinterVeilActive() and true or false
	local count = 0
	for tex in pairs(glyphs) do
		if (tex.wvSnowball and true or false) ~= on then
			if self.CapturePaintNetGlyph then self.CapturePaintNetGlyph(tex) else ns.CaptureArtPaint(tex, "icon") end
			count = count + 1
		end
	end
	if count > 0 and self.CaptureStyleNet and self.captureNetButton then pcall(self.CaptureStyleNet, self) end
	return count
end

-- La trajectoire du paquet (CaptureStage.lua) : du bas à gauche au centre
local function Arc(p)
	return -120 + 120 * p, -150 + 150 * p + 70 * math.sin(math.pi * p)
end

-- 2.14.0 (bêta 3) : la boule ronde. Avant, l'icône entière volait, coins
-- sombres compris. Découpée autour de la boule (ART.ball) et arrondie par le
-- masque rond du client (sur un client sans masque : la découpe seule, déjà
-- presque toute blanche). Le masque suit la boule (ancré sur elle).
local function RoundBall(host, sub, size, spec)
	local tex = host:CreateTexture(nil, "ARTWORK", nil, sub)
	SetFile(tex, spec or ns.WINTER_VEIL_ART.ball)
	tex:SetSize(size, size)
	if host.CreateMaskTexture then
		local ok, mask = pcall(host.CreateMaskTexture, host)
		if ok and mask then
			pcall(mask.SetTexture, mask, ns.WINTER_VEIL_ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints(tex)
			if Method(tex, "AddMaskTexture", mask) then tex.wvMask = mask end
		end
	end
	tex:Hide()
	return tex
end

local function Flake(host, sub, size)
	local tex = host:CreateTexture(nil, "ARTWORK", nil, sub)
	SetFile(tex, ns.WINTER_VEIL_ART.flake)
	tex:SetSize(size, size)
	tex:Hide()
	return tex
end

local function StageSnow(frame)
	if frame.wvBall then return frame end
	local S = ns.WINTER_VEIL_SNOWBALL
	local host = frame.fxTop or frame
	frame.wvBall = RoundBall(host, 5, S.size)
	-- la bouffée de l'impact : la même boule, en lumière additive
	frame.wvPuff = RoundBall(host, 4, S.size)
	Method(frame.wvPuff, "SetBlendMode", "ADD")
	-- la traîne : quelques petits flocons derrière la boule
	frame.wvTrail = {}
	for index = 1, S.trail do
		local tex = Flake(host, 4, S.trailSize)
		tex.lag = index * S.trailGap
		tex.size = S.trailSize * (1 - 0.15 * (index - 1))
		tex.alpha = 0.75 * (1 - (index - 1) / (S.trail + 1))
		frame.wvTrail[index] = tex
	end
	frame.wvFlakes = {}
	for index = 1, S.flakes do
		local tex = Flake(host, 6, S.flakeSize - (index % 3) * 3)
		tex.angle = (index / S.flakes) * math.pi * 2 + (index % 2) * 0.3
		tex.reach = S.reach * (0.7 + 0.15 * (index % 3))
		tex.spin = ((index * 5) % 7 - 3) * 0.8
		frame.wvFlakes[index] = tex
	end
	return frame
end

local function Put(region, anchor, x, y)
	region:ClearAllPoints()
	region:SetPoint("CENTER", anchor, "CENTER", x, y)
end

-- Le vol, adouci : un peu plus lent à l'arrivée
local function Glide(p)
	local S = ns.WINTER_VEIL_SNOWBALL
	p = Clamp01(p)
	return p * (1 + S.ease - S.ease * p)
end

local function HideAll(list) for _, tex in ipairs(list or {}) do tex:Hide() end end

-- Une image de la scène : par-dessus celle de CaptureStage.lua (rien de sa
-- logique ne change). Le paquet, le filet, son ombre et ses cordes cachés ;
-- la boule de neige suit l'arc du paquet (adouci), rapetisse et tourne un
-- peu, suivie de sa traîne de flocons ; à l'arrivée, une bouffée de neige
-- et des flocons qui s'écartent en tournant, retombent un peu et s'effacent.
function ns:WinterVeilStage(frame, now)
	frame = frame or self.captureStage
	if not frame then return nil end
	local rolling = frame.rolling
	if not (rolling and self:WinterVeilActive()) then
		if frame.wvBall then
			frame.wvBall:Hide()
			frame.wvPuff:Hide()
			HideAll(frame.wvTrail)
			HideAll(frame.wvFlakes)
		end
		return false
	end
	StageSnow(frame)
	local S = ns.WINTER_VEIL_SNOWBALL
	for _, region in ipairs({ frame.bundle, frame.net, frame.netShadow }) do if region then region:Hide() end end
	for _, rope in ipairs(frame.ropes or {}) do rope:Hide() end
	local scene = frame.scene or frame
	local t = (now or Clock()) - (rolling.start or now or 0)
	local throw = ns.CAPTURE_THROW_TIME or 0.7
	local p = t / throw
	-- 2.14.0 (bêta 3) : le pied parle de la boule de neige, pas du filet
	if frame.footer and not rolling.result then
		frame.footer:SetText(t < throw and L.WINTER_VEIL_STAGE_FLY or L.WINTER_VEIL_STAGE_SHAKE)
	end
	if t < throw then
		local g = Glide(p)
		local x, y = Arc(g)
		local size = S.size * (S.scaleFrom + (S.scaleTo - S.scaleFrom) * g)
		Put(frame.wvBall, scene, x, y)
		frame.wvBall:SetSize(size, size)
		Method(frame.wvBall, "SetRotation", g * math.pi * S.spin)
		frame.wvBall:SetAlpha(1)
		frame.wvBall:Show()
		for _, spark in ipairs(frame.trail or {}) do
			if spark:IsShown() then spark:SetVertexColor(1, 1, 1, 1) end
		end
	else
		frame.wvBall:Hide()
	end
	-- la traîne : là où était la boule un peu plus tôt (jusqu'à l'impact)
	for _, tex in ipairs(frame.wvTrail) do
		local back = p - tex.lag
		if back > 0 and p < 1 then
			local x, y = Arc(Glide(back))
			Put(tex, scene, x, y)
			tex:SetSize(tex.size, tex.size)
			Method(tex, "SetRotation", back * 4)
			tex:SetAlpha(tex.alpha)
			tex:Show()
		else
			tex:Hide()
		end
	end
	local q = (t - throw) / S.burst
	-- la bouffée de neige, au point d'impact
	local f = q / S.puffTime
	if f >= 0 and f < 1 then
		local size = S.size * S.scaleTo * (1 + (S.puffScale - 1) * EaseOut(f))
		Put(frame.wvPuff, scene, 0, 0)
		frame.wvPuff:SetSize(size, size)
		frame.wvPuff:SetAlpha(0.7 * (1 - f))
		frame.wvPuff:Show()
	else
		frame.wvPuff:Hide()
	end
	for _, tex in ipairs(frame.wvFlakes) do
		if q >= 0 and q < 1 then
			local r = tex.reach * EaseOut(q)
			Put(tex, scene, math.cos(tex.angle) * r, math.sin(tex.angle) * r + 10 - S.fall * q * q)
			Method(tex, "SetRotation", tex.spin * q)
			tex:SetAlpha(0.9 * (1 - q))
			tex:Show()
		else
			tex:Hide()
		end
	end
	return true
end

do
	local update = ns.CaptureStageUpdate
	if update then
		function ns:CaptureStageUpdate(now, ...)
			local phase = update(self, now, ...)
			if self.captureStage then
				local ok, err = pcall(self.WinterVeilStage, self, self.captureStage, now)
				if not ok and self.RecordError then self:RecordError("noel:scene", err) end
			end
			return phase
		end
	end
end

-- ---------------------------------------------------------------------------
-- « Tout capturer » (CaptureBatch.lua) : même chose, case par case. Au lieu
-- du filet qui tombe, une boule de neige tombe en biais sur la créature
-- pendant la pose (CAPTURE_BATCH_DRAPE), puis éclate en flocons. Le filet,
-- son ombre et ses cordes restent cachés, jusqu'au filet déchiré posé sur
-- une échappée (la case garde son portrait grisé). Le déroulé (secousses,
-- verdicts, sons) ne change pas.
-- ---------------------------------------------------------------------------
local function TileSnow(tile)
	if tile.wvBall then return tile end
	local S = ns.WINTER_VEIL_SNOWBALL
	local host = tile.fx or tile
	tile.wvBall = RoundBall(host, 5, S.tileSize)
	tile.wvFlakes = {}
	for index = 1, S.tileFlakes do
		local tex = Flake(host, 6, S.tileFlakeSize - (index % 2) * 3)
		tex.angle = (index / S.tileFlakes) * math.pi * 2 + 0.4
		tex.reach = S.tileReach * (0.75 + 0.25 * (index % 2))
		tex.spin = ((index * 5) % 7 - 3) * 0.8
		tile.wvFlakes[index] = tex
	end
	return tile
end

local function TileSnowHide(tile)
	if not tile.wvBall then return end
	tile.wvBall:Hide()
	HideAll(tile.wvFlakes)
end

-- Une case à l'instant `t` (depuis le début de la volée)
local function TileSnowDraw(tile, card, t)
	TileSnow(tile)
	local S = ns.WINTER_VEIL_SNOWBALL
	for _, region in ipairs({ tile.net, tile.shadow }) do if region then region:Hide() end end
	for _, rope in ipairs(tile.ropes or {}) do rope:Hide() end
	local scene = tile.scene or tile
	local drape = ns.CAPTURE_BATCH_DRAPE or 0.3
	local since = t - (tonumber(card.dropAt) or 0)
	if since >= 0 and since < drape and not card.settled then
		local p = Glide(since / drape)
		local size = S.tileSize * (S.scaleFrom + (S.scaleTo - S.scaleFrom) * p)
		Put(tile.wvBall, scene, -S.tileReach * (1 - p), S.tileReach * 1.4 * (1 - p) * (1 - p))
		tile.wvBall:SetSize(size, size)
		Method(tile.wvBall, "SetRotation", p * math.pi * S.spin)
		tile.wvBall:SetAlpha(1)
		tile.wvBall:Show()
	else
		tile.wvBall:Hide()
	end
	local q = (since - drape) / S.burst
	for _, tex in ipairs(tile.wvFlakes) do
		if q >= 0 and q < 1 and not card.settled then
			local r = tex.reach * EaseOut(q)
			Put(tex, scene, math.cos(tex.angle) * r, math.sin(tex.angle) * r + 4 - S.fall * 0.5 * q * q)
			Method(tex, "SetRotation", tex.spin * q)
			tex:SetAlpha(0.9 * (1 - q))
			tex:Show()
		else
			tex:Hide()
		end
	end
end

-- Toutes les cases de la volée en cours ; rend s'il y a de la neige
function ns:WinterVeilBatch(now)
	local batch = self.captureBatch
	if not (batch and batch.cards) then return nil end
	local on = self:WinterVeilActive()
	local t = (now or Clock()) - (batch.startedAt or now or 0)
	for _, card in ipairs(batch.cards) do
		local tile = card.tile
		if tile then
			if on then TileSnowDraw(tile, card, t) else TileSnowHide(tile) end
		end
	end
	return on and true or false
end

do
	local function Snow(self, now)
		local ok, err = pcall(self.WinterVeilBatch, self, now)
		if not ok and self.RecordError then self:RecordError("noel:volee", err) end
	end
	local update = ns.CaptureBatchUpdate
	if update then
		function ns:CaptureBatchUpdate(now, ...)
			local a = update(self, now, ...)
			Snow(self, now)
			return a
		end
	end
	-- « Arrêter » (et capture animée coupée) : les cases se figent d'un coup
	local stop = ns.CaptureBatchStop
	if stop then
		function ns:CaptureBatchStop(...)
			local a = stop(self, ...)
			Snow(self, Clock())
			return a
		end
	end
end

-- ---------------------------------------------------------------------------
-- Tout appliquer (réglage, commande, style, saison)
-- ---------------------------------------------------------------------------
function ns:WinterVeilApply()
	-- 2.14.0 (bêta 2) : la saison des compagnons (WinterCompanions.lua) suit le réglage
	if self.WinterCompanionsForget then self:WinterCompanionsForget() end
	local active = self:WinterVeilActive() and true or false
	self.winterVeilShown = active
	-- 2.14.0 (bêta 7) : Givre offert ou repris : le cadre porté est revu
	-- (retour au cadre d'avant la saison), anneau compris
	self.winterVeilGift = self:WinterVeilGiftOn() and true or false
	if self.companionFrame and self.CompanionApplyFrame then
		local ok, err = pcall(self.CompanionApplyFrame, self)
		if not ok and self.RecordError then self:RecordError("noel:givre", err) end
	end
	for _, step in ipairs({ "WinterVeilCompanion", "WinterVeilJournal", "WinterVeilRepaintGlyphs" }) do
		local ok, err = pcall(self[step], self)
		if not ok and self.RecordError then self:RecordError("noel:" .. step, err) end
	end
	return active
end

do
	-- le compagnon rhabillé (style) : son décor suit
	local apply = ns.CompanionApplyUIStyle
	if apply then
		function ns:CompanionApplyUIStyle(...)
			local style = apply(self, ...)
			local ok, err = pcall(self.WinterVeilCompanion, self)
			if not ok and self.RecordError then self:RecordError("noel:compagnon", err) end
			return style
		end
	end
	-- changement de style : carnet, compagnon, glyphes
	local restyle = ns.ApplyUIStyle
	if restyle then
		function ns:ApplyUIStyle(...)
			local style = restyle(self, ...)
			self:WinterVeilApply()
			return style
		end
	end
	-- chaque rafraîchissement du carnet (ouverture comprise) : son décor suit
	local refresh = ns.RefreshJournal
	if refresh then
		function ns:RefreshJournal(...)
			local a, b = refresh(self, ...)
			local ok, err = pcall(self.WinterVeilJournal, self)
			if not ok and self.RecordError then self:RecordError("noel:carnet", err) end
			return a, b
		end
	end
	-- le compagnon affiché : la saison a pu commencer (ou finir) entre-temps.
	-- Rien n'est refait tant que l'état ne change pas.
	local visible = ns.CompanionUpdateVisibility
	if visible then
		function ns:CompanionUpdateVisibility(...)
			local shown = visible(self, ...)
			local active = self:WinterVeilActive() and true or false
			if self.winterVeilShown ~= active then self:WinterVeilApply() end
			return shown
		end
	end
end

-- ---------------------------------------------------------------------------
-- Réglage (page Compagnon de route, sous le style) et commande
-- ---------------------------------------------------------------------------
do
	for _, page in ipairs(ns.OPTION_PAGES or {}) do
		if page.id == "companionMain" and type(page.rows) == "table" then
			local present, at = false, #page.rows + 1
			for index, row in ipairs(page.rows) do
				if row.key == "winterVeil" then present = true end
				if row.key == "companionStyle" then at = index + 1 end
			end
			if not present then
				table.insert(page.rows, at, { key = "winterVeil", label = "OPT_WINTER_VEIL", kind = "action",
					choices = function() return ns:WinterVeilChoices() end,
					current = function() return ns:WinterVeilChoice() end,
					describe = function() return L.OPT_WINTER_VEIL_DESC end,
					tooltip = function() if not (ns.AzerothOn and ns:AzerothOn()) then return L.OPT_WINTER_VEIL_SOBRE end end,
					choose = function(id) ns:SetWinterVeil(id) end })
			end
			-- 2.14.0 (bêta 6) : le cadre givré, juste sous le décor
			local frost, after = false, nil
			for index, row in ipairs(page.rows) do
				if row.key == "winterVeilFrost" then frost = true end
				if row.key == "winterVeil" then after = index end
			end
			if not frost and after then
				table.insert(page.rows, after + 1, { key = "winterVeilFrost", label = "OPT_WINTER_VEIL_FROST", kind = "bool",
					describe = function() return L.OPT_WINTER_VEIL_FROST_DESC end,
					tooltip = function() if not (ns.AzerothOn and ns:AzerothOn()) then return L.OPT_WINTER_VEIL_SOBRE end end,
					onChange = function()
						local ok, err = pcall(ns.WinterVeilCompanion, ns)
						if not ok and ns.RecordError then ns:RecordError("noel:givre", err) end
					end })
			end
		end
	end
end

function ns:WinterVeilCommand(rest)
	local word, more = tostring(rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
	word = (word or ""):lower()
	-- 2.14.0 (bêta 4) : réglages en jeu (guirlande du cadre, Metzen)
	if word == "cadre" or word == "frame" then return self:WinterVeilTuneLights(more) end
	if word == "metzen" and self.WinterMetzenTune then return self:WinterMetzenTune(more) end
	local mode = word ~= "" and self:SetWinterVeil(word) or nil
	if not mode then
		self:Print(self:F("WINTER_VEIL_USAGE", L["WINTER_VEIL_" .. self:WinterVeilChoice()]))
		return nil
	end
	local sobre = mode ~= "off" and not (self.AzerothOn and self:AzerothOn())
	self:Print(self:F(sobre and "WINTER_VEIL_MSG_SOBRE" or "WINTER_VEIL_MSG", L["WINTER_VEIL_" .. mode]))
	return mode
end

if ns.EXTRA_COMMANDS then
	ns.EXTRA_COMMANDS["noel"] = function(self, rest) self:WinterVeilCommand(rest) end
	ns.EXTRA_COMMANDS["winterveil"] = ns.EXTRA_COMMANDS["noel"]
end
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_QUICK" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_NOEL")
		end
	end
end

if ns.Mark then ns.Mark("WinterVeil") end
