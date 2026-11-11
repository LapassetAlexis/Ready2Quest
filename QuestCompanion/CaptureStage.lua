-- CaptureStage.lua -- la capture en scène (QuestCompanion 1.4.0, refaite en 2.1.0)
--
-- Comme l'ouverture d'un paquet de cartes : le moment compte autant que le
-- résultat. Au clic sur le filet, une scène s'ouvre au centre de l'écran, avec
-- ses propres textures (Textures/, peintes par tools/gen_capture_assets.py) :
--   1. le lancer : le filet roulé en boule (paquet) part du bas, en arc, en
--      tournant, avec une traînée d'étincelles, et s'ouvre à l'apogée ;
--   2. la pose : le filet (cordes, nœuds, lest) tombe sur la créature, son
--      ombre le rejoint à l'impact ; un éclair bref, un anneau de poussière ;
--   3. les secousses : il oscille et se resserre à chaque secousse, la
--      créature se débat dessous, trois losanges s'allument (2.14.0
--      bêta 3 : plus de halo qui pulse derrière elle) ;
--   4. capturé : éclair blanc, gerbe de rayons qui tourne, étincelles, le
--      filet se referme sur elle et s'efface, la créature tourne sur
--      elle-même, le ruban « Capturé ! » surgit, puis les étoiles du spécimen
--      une à une ;
--      échappé : le filet bascule sur sa version déchirée, tombe, ses cordes
--      volent, le monstre file sur le côté dans la poussière, ruban ardoise.
--   Une brillante : tout en or, deuxième gerbe à contresens, motes dorées qui
--   montent, reflet qui balaie le ruban.
-- Le déroulé (secousses, verdict) reste celui de Capture.lua (CaptureTick) ;
-- ici, on ne fait que le montrer, image par image (OnUpdate de la scène) :
-- tout est créé une fois, rien n'est alloué à chaque image.
-- Réglage : « Capture animée » (page « Au jour le jour »). Coupé, la petite
-- fenêtre fait comme avant.
-- Style Azeroth (2.5.1, AzerothStyle.lua) : la même scène dans le cadre en
-- bois des hauts faits, la plaque « CAPTURE » et le nom en haut, et le
-- verdict en bandeau de haut fait (bouclier d'or et éclat, ou gris) à la
-- place du ruban ; le bandeau « Capturé ! » d'après n'est alors pas rejoué.
-- 2.14.0 (bêta 3) : carte compacte (maquette A validée le 10/11/2026 ; avant,
-- un grand panneau sombre, la créature dans une boîte noire au halo blanc,
-- beaucoup de vide). Azeroth : une carte de parchemin (encadré fin en bois,
-- filet d'or, ns:AzerothCreateCard), la plaque « CAPTURE · <rang> » et le nom,
-- la créature posée sur le parchemin avec une ombre au sol, puis la ligne
-- « Chance 50 % » et les étoiles à gagner, les aides du joueur, le pied.
-- Sobre : la même disposition sur le fond sombre du socle. Le verdict (bandeau
-- des hauts faits ou ruban) se pose sur la chance et les aides.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.CAPTURE_THROW_TIME = 0.7       -- s de vol du paquet
ns.CAPTURE_STAGE_HOLD = 3.5       -- s de résultat à l'écran (un clic ferme avant)
ns.CAPTURE_DRAPE_TIME = 0.3       -- s pour que le filet se pose (rebond)
ns.CAPTURE_STAGE_CAM = 1.2        -- distance de caméra : la créature tient sous le filet
-- 2.14.0 (bêta 3) : les deux cartes compactes. Sobre : titre « CAPTURE ·
-- <rang> », le nom, la scène, sous elle la ligne de chance (infoY) et les
-- aides (aidsY, depuis le bas de la scène), le ruban du verdict par-dessus
-- (ribbonY, son centre depuis le bas de la scène), les étoiles sous le ruban.
local SBS = { w = 340, h = 366, titleY = -12, nameY = -28, sceneY = -52, ribbonY = -30, footer = 11,
	dots = 10, dotsY = -2, infoY = -24, aidsY = -46, aid = 24, aidStep = 52 }
ns.CAPTURE_STAGE_SOBRE = SBS
local STAGE_W, STAGE_H = SBS.w, SBS.h
local SCENE, MODEL = 196, 180     -- la scène, et le modèle dedans
local NET = 210                   -- le filet posé déborde un peu de la scène
local RIBBON_W, RIBBON_H = 300, 75
-- style Azeroth : carte de parchemin 340×418 (avant : bois sombre 360×504),
-- plaque de titre en haut, la scène, les losanges des secousses, la chance
-- et les étoiles (infoY), les aides (aidsY), le bandeau de verdict (posé
-- sur elles, il mord 8 px le bas de la scène, sous l'ombre), le pied.
-- L'ombre au sol : ns.CAPTURE_STAGE_SHADOW (y depuis le centre de la scène), à régler en jeu.
local AZS = { w = 340, h = 418, plateW = 280, plateH = 92, plateY = -10, sceneY = -98,
	verdictW = 324, verdictH = 105, verdictY = -286, footer = 12, dots = 12, dotsY = -2,
	infoY = -26, aidsY = -50, aid = 24, aidStep = 52 }
-- 2.14.0 (bêta 4) : le bandeau de verdict, trop grand sur la carte de 340 px
-- (24.png : il couvrait tout le bas, bord à bord). Même dessin, réduit
-- (verdictScale, appliqué par SetScale : textes, bouclier, éclat compris) :
-- ≈ 266×86, 37 px de marge de chaque côté, centré dans sa zone.
AZS.verdictScale = 0.82
ns.CAPTURE_STAGE_AZEROTH = AZS
-- 2.14.0 (bêta 4) : l'éclair blanc (impact, capture), moins grand et moins
-- fort : 320 px et opacité 1 avant
ns.CAPTURE_FLASH = { size = 220, ok = 0.7, impact = 0.55 }
-- l'ombre au sol, sous les pattes : ovale doux du client, teinté sombre
ns.CAPTURE_STAGE_SHADOW = { y = -72, w = 132, h = 30, alpha = { azeroth = 0.55, sobre = 0.7 } }
local SHADOW = ns.CAPTURE_STAGE_SHADOW
local TRAIL, DUST, PUFFS, BURST, ROPES, MOTES = 6, 6, 4, 18, 8, 12

-- Les textures de la scène (tools/gen_capture_assets.py)
local TEX = Theme.MEDIA .. "Textures\\"
local ART = {
	net = TEX .. "filet",            -- 512x256 : entier (gauche), déchiré (droite)
	bundle = TEX .. "paquet",        -- le filet roulé en boule
	rope = TEX .. "corde",           -- un bout de corde (déchirure)
	-- 2.12.1 : les autres images (halo, rayons, particules, étoiles, ruban,
	-- vignette, glyphe du filet) sont celles du client (ns.CAPTURE_CLIENT_ART)
}
ns.CAPTURE_ART = ART
-- découpes des feuilles de sprites (SetTexCoord : gauche, droite, haut, bas)
local COORDS = {
	netWhole = { 0, 0.5, 0, 1 }, netTorn = { 0.5, 1, 0, 1 },
}
ns.CAPTURE_COORDS = COORDS

-- 2.11.0 : les images de la scène viennent du client, par référence (atlas
-- vérifiés en jeu sur Forever le 9/11/2026). Le filet, ses cordes et le
-- paquet restent les nôtres (décision du 7/11 et du 9/11 : pas d'équivalent).
-- 2.12.1 : plus de fichier de repli à nous ; un atlas absent laisse la
-- texture vide. files : icônes du client essayées dans l'ordre.
-- desaturate : l'atlas est grisé pour prendre la teinte posée (rareté, or).
ns.CAPTURE_CLIENT_ART = {
	rays   = { atlas = "ArtifactsFX-StarBurst", desaturate = true },
	halo   = { atlas = "ChallengeMode-SoftYellowGlow", desaturate = true },
	sparks = { atlas = "Artifacts-Anim-Sparks", desaturate = true },
	-- l'anneau de poussière : une lueur douce aplatie
	dust   = { atlas = "ChallengeMode-SoftYellowGlow", desaturate = true },
	stars  = { atlas = "auctionhouse-icon-favorite" },
	-- pas « Bonus-ToastBanner » : il peint un écusson bleu sur Forever
	ribbon = { atlas = "BossBanner-BgBanner-Mid", desaturate = true },
	-- 2.14.0 (bêta 3) : plus de vignette (la boîte noire) ; l'ombre au sol,
	-- la même lueur douce grisée puis teintée sombre
	ground = { atlas = "ChallengeMode-SoftYellowGlow", desaturate = true },
	-- glyphe du filet : l'icône du jeu ; 2.12.1 : repli sur une autre icône du jeu
	icon   = { files = { "Interface\\Icons\\INV_Misc_Net_01", "Interface\\Icons\\Spell_Nature_Web" } },
}

-- Un atlas est-il connu du client ? (C_Texture.GetAtlasInfo ; lu une fois)
local atlasKnown = { api = false }
function ns.CaptureAtlasKnown(name)
	local api = rawget(_G, "C_Texture")
	if atlasKnown.api ~= api then atlasKnown = { api = api } end
	if atlasKnown[name] == nil then
		local ok, info = false, nil
		if type(api) == "table" and type(api.GetAtlasInfo) == "function" then ok, info = pcall(api.GetAtlasInfo, name) end
		if ok and ns.Plain then info = ns.Plain(info) end
		atlasKnown[name] = (ok and info ~= nil and info ~= false) and true or false
	end
	return atlasKnown[name]
end

-- Peint le rôle `role` sur `tex`. Le filet, ses cordes et le paquet : nos
-- fichiers (découpe `coords`), rend "own". Le reste : l'image du client,
-- rend "client" (tex.clientArt : Coord ne touche pas à la découpe d'un
-- atlas) ; 2.12.1 : sans repli à nous, rend nil si le client ne l'a pas.
function ns.CaptureArtPaint(tex, role, coords)
	if not tex then return nil end
	local spec = ns.CAPTURE_CLIENT_ART[role]
	if not spec then
		tex.clientArt = nil
		local own = ART[role]
		if not own then return nil end
		tex:SetTexture(own)
		if coords and tex.SetTexCoord then tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
		return "own"
	end
	local done = false
	if spec.atlas and tex.SetAtlas and ns.CaptureAtlasKnown(spec.atlas) then
		local ok, result = pcall(tex.SetAtlas, tex, spec.atlas)
		done = ok and result ~= false
	end
	for _, file in ipairs(spec.files or {}) do
		if done then break end
		local ok, result = pcall(tex.SetTexture, tex, file)
		done = ok and result ~= false and (not tex.GetTexture or tex:GetTexture() ~= nil)
		if done and tex.SetTexCoord then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	end
	if not done then
		tex.clientArt = nil
		if tex.SetTexture then tex:SetTexture(nil) end
		return nil
	end
	tex.clientArt = true
	if tex.SetDesaturated then tex:SetDesaturated(spec.desaturate and true or false) end
	return "client"
end
-- 2.12.1 : le glyphe du filet des bandeaux et du bouton (icône du jeu, en
-- couleurs) ; le petit logo de l'addon si aucune icône ne se peint
function ns.CapturePaintNetGlyph(tex)
	if not tex then return end
	if not ns.CaptureArtPaint(tex, "icon") then tex:SetTexture(Theme.LOGO_SMALL) end
	if tex.SetVertexColor then tex:SetVertexColor(1, 1, 1, 1) end
end
-- 2.11.2 : teintes des scènes de capture, partagées avec « Tout capturer »
-- (CaptureBatch.lua, chargé après) ; noms et fond de case de la scène groupée
-- gardés tels quels (idle diffère d'AZEROTH_COLORS.flavour, fledName de .fled,
-- tileBg d'AZEROTH_INK.woodDeep : aucune teinte ne change)
ns.CAPTURE_FX_COLORS = {
	white = Theme.WHITE, starGrey = { 0.47, 0.50, 0.52 }, dust = { 0.62, 0.57, 0.48 },
	panelShiny = { 0.47, 0.31, 0.09 },
	idle = { 0.9, 0.86, 0.78 }, fledName = { 0.7, 0.66, 0.6 }, tileBg = { 0.05, 0.04, 0.03 },
}
local FXC = ns.CAPTURE_FX_COLORS
local WHITE, STAR_GREY, DUST_COLOR, PANEL_SHINY = FXC.white, FXC.starGrey, FXC.dust, FXC.panelShiny
local PANEL_FAIL, TRIM_FAIL = { 0.20, 0.23, 0.26 }, { 0.47, 0.35, 0.34 }
local BURST_KINDS = { "star4", "spark", "dot" }
local BURST_SIZES = { 14, 18, 10 }

-- Rareté : couleur et nombre de losanges. 2.11.0 (fiche 09) : deux couleurs
-- par rang, lues dans le jeton du socle Theme.RANK s'il existe : `color`
-- (= mark, couleur de qualité du jeu : losanges, filets, halo ; ≥ 3:1) et
-- `text` (variante claire pour le nom sur fond sombre ; ≥ 4,5:1 sur ROW,
-- ROW_ALT, FIELD, WINDOW, mesuré dans le socle). Repli : valeurs de la fiche 09.
local RANK_FALLBACK = {
	trivial   = { text = { 0.62, 0.62, 0.62 }, mark = { 0.62, 0.62, 0.62 } },
	normal    = { text = { 0.95, 0.95, 0.95 }, mark = { 0.95, 0.95, 0.95 } },
	elite     = { text = { 0.30, 0.62, 0.98 }, mark = { 0.00, 0.44, 0.87 } },
	rare      = { text = { 0.78, 0.50, 1.00 }, mark = { 0.64, 0.21, 0.93 } },
	worldboss = { text = { 1.00, 0.50, 0.00 }, mark = { 1.00, 0.50, 0.00 } },
}
RANK_FALLBACK.minus, RANK_FALLBACK.rareelite = RANK_FALLBACK.trivial, RANK_FALLBACK.rare
ns.CAPTURE_RANK_FALLBACK = RANK_FALLBACK
-- Le jeton du socle (fiche 21) est une couleur de texte par rang
-- (Theme.RANK[Theme.RankKey(classe)]) : elle donne `text` ; la marque reste
-- la couleur de qualité du jeu
local function Rank(id, pips)
	local r = RANK_FALLBACK[id]
	local text = r.text
	if type(Theme.RANK) == "table" and type(Theme.RankKey) == "function" then
		local token = Theme.RANK[Theme.RankKey(id)]
		if type(token) == "table" and tonumber(token[1]) then text = token end
	end
	return { color = r.mark, text = text, pips = pips }
end
local RARITY = {
	trivial = Rank("trivial", 1), minus = Rank("minus", 1), normal = Rank("normal", 1), elite = Rank("elite", 2),
	rare = Rank("rare", 3), rareelite = Rank("rareelite", 4), worldboss = Rank("worldboss", 5),
}
ns.CAPTURE_RARITY = RARITY

local FR = {
	CAPTURE_STAGE_TITLE = "Capture",
	CAPTURE_STAGE_NEW   = "Nouvelle apparence pour ton compagnon",
	CAPTURE_STAGE_SHINY = "Brillante ! Nouvelle apparence pour ton compagnon",
	CAPTURE_STAGE_FAIL  = "Il reviendra. Toi aussi.",
	CAPTURE_STAGE_CLOSE = "Clic ou Échap pour fermer",
	CAPTURE_STAGE_CHANCE = "Chance %d %%",
	CAPTURE_STAGE_SURE  = "Capture assurée",
	OPT_DAILY_CAPTURE_ANIM = "Capture animée",
}
local EN = {
	CAPTURE_STAGE_TITLE = "Capture",
	CAPTURE_STAGE_NEW   = "New look for your companion",
	CAPTURE_STAGE_SHINY = "Shiny! New look for your companion",
	CAPTURE_STAGE_FAIL  = "It'll be back. So will you.",
	CAPTURE_STAGE_CLOSE = "Click or Escape to close",
	CAPTURE_STAGE_CHANCE = "Chance %d%%",
	CAPTURE_STAGE_SURE  = "Guaranteed capture",
	OPT_DAILY_CAPTURE_ANIM = "Animated capture",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_STAGE_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({ companionCaptureAnim = true })
if type(ns.DAILY_OPTION_ROWS) == "table" then
	local present, at = false, 1
	for index, row in ipairs(ns.DAILY_OPTION_ROWS) do
		if row.key == "companionCaptureAnim" then present = true end
		if row.key == "companionCapture" then at = index + 1 end
	end
	if not present then
		table.insert(ns.DAILY_OPTION_ROWS, at, { key = "companionCaptureAnim", label = "OPT_DAILY_CAPTURE_ANIM", kind = "bool" })
	end
end

local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Method(obj, name, ...)
	if obj and type(obj[name]) == "function" then return pcall(obj[name], obj, ...) end
	return false
end
local function Place(region, anchor, x, y)
	region:ClearAllPoints()
	region:SetPoint("CENTER", anchor, "CENTER", x, y)
end
local function Clamp01(x) return math.max(0, math.min(1, x)) end
local function EaseOut(x) x = Clamp01(x); return 1 - (1 - x) * (1 - x) end
-- dépasse un peu puis revient (le filet qui retombe, le ruban qui surgit)
local function EaseBack(x)
	x = Clamp01(x)
	local k = 1.7
	return 1 + (k + 1) * (x - 1) ^ 3 + k * (x - 1) ^ 2
end
-- une image du client (atlas) garde sa découpe : seules les nôtres en ont une
local function Coord(tex, c) if c and not tex.clientArt then tex:SetTexCoord(c[1], c[2], c[3], c[4]) end end
local function Tint(tex, c, alpha) tex:SetVertexColor(c[1], c[2], c[3], alpha or 1) end
local function Rotate(tex, radians) if tex.SetRotation then pcall(tex.SetRotation, tex, radians) end end
-- opacité et visibilité d'un coup : à 0, la région est cachée
local function Fade(region, alpha)
	if alpha <= 0 then region:Hide(); return end
	region:SetAlpha(math.min(1, alpha))
	region:Show()
end
-- une texture d'art de la scène : rôle (ns.CaptureArtPaint), calque, découpe
-- de notre fichier (filet seulement), taille, fusion
local function Art(parent, layer, sub, role, coords, w, h, blend)
	local tex = parent:CreateTexture(nil, layer, nil, sub)
	ns.CaptureArtPaint(tex, role, coords)
	if w then tex:SetSize(w, h or w) end
	if blend and tex.SetBlendMode then pcall(tex.SetBlendMode, tex, blend) end
	tex:Hide()
	return tex
end
local function HideAll(list) for _, region in ipairs(list) do region:Hide() end end

function ns:CaptureStageOn()
	return self:DB().companionCaptureAnim ~= false and Theme ~= nil and Theme.CreateToast ~= nil
end

function ns:CaptureRarity(target)
	if target and target.shiny then
		local gold = Theme.GOLD_LIGHT
		return { color = gold, text = gold, pips = (RARITY[target.class] or RARITY.normal).pips }
	end
	return RARITY[(target and target.class) or "normal"] or RARITY.normal
end

-- Le modèle 3D d'une créature capturable, cadré comme sur la scène : rend
-- true s'il s'affiche (sinon il est caché, l'appelant montre son icône de
-- repli). Partagé avec les scènes de « Tout capturer » (CaptureBatch.lua).
function ns:CaptureModelSetup(model, target)
	if not (model and target) then return false end
	-- 2.11.0 : un seul cadrage (ns.ShowModel, profil « stage ») : la caméra
	-- est reposée après le chargement ; une brillante, sous sa lumière dorée
	ns.MODEL_PROFILES.stage.cam = ns.CAPTURE_STAGE_CAM
	return ns.ShowModel(model, { npc = target.npcID, display = target.display, shiny = target.shiny }, "stage")
end

local function PlayKit(name)
	local kit, play = G("SOUNDKIT"), G("PlaySound")
	if type(kit) == "table" and kit[name] and type(play) == "function" then pcall(play, kit[name]) end
end

-- ---------------------------------------------------------------------------
-- Construction : tout est créé une fois, caché, puis posé image par image.
-- Une scène par style (2.5.1) : Sobre (le cadre du thème, le ruban) ou
-- Azeroth (le cadre en bois, la plaque, le bandeau des hauts faits), créée à
-- la demande et gardée (ns.captureStages[style]) ; ns.captureStage est celle
-- du style courant. Le style change pendant la scène : elle finit telle
-- quelle, le nouveau style vient à la suivante.
-- ---------------------------------------------------------------------------
local function StageStyle(self)
	return (self.AzerothScenesOn and self:AzerothScenesOn()) and "azeroth" or "sobre"
end

-- Le cadre lui-même : Azeroth (carte de parchemin, plaque, bandeau de
-- verdict ; 2.14.0 bêta 3, avant le grand cadre en bois sombre) ou Sobre
local function StageWindow(self, az)
	if az and self.AzerothCreateCard then
		local frame = self:AzerothCreateCard(AZS.w, AZS.h, { strata = "DIALOG", name = "QuestCompanionCaptureStageAzeroth" })
		if frame then return frame end
	end
	local frame = Theme.CreateToast(UIParent, STAGE_W, STAGE_H, { strata = "DIALOG", name = "QuestCompanionCaptureStage" })
	if frame then frame.uiStyle = "sobre" end
	return frame
end

-- 2.14.0 (bêta 3) : l'encre d'un rôle mesuré (ns.AZEROTH_CONTRAST,
-- AzerothStyle.lua) sur un texte posé sur le parchemin, sans ombre
local function RoleInk(fs, role)
	local entry = (ns.AZEROTH_CONTRAST and ns.AZEROTH_CONTRAST[role]) or (ns.CAPTURE_PREP_CONTRAST and ns.CAPTURE_PREP_CONTRAST[role])
	local ink = entry and ns.AZEROTH_INK and ns.AZEROTH_INK[entry[1]]
	if not ink then return false end
	fs:SetTextColor(ink[1], ink[2], ink[3], 1)
	if Theme.NoShadow then Theme.NoShadow(fs) end
	fs.azRole = role
	return true
end

-- 2.14.0 (bêta 3) : sous la scène, dans un cadre à eux (caché d'un coup
-- quand le verdict se pose dessus) : la ligne « Chance 50 % » suivie des
-- étoiles à gagner, puis les aides du joueur, une case par aide (icône,
-- liseré, nombre en poche). Montrées seulement : l'aide du lancer est déjà
-- choisie (en couleurs, liseré d'or), les autres grisées.
local function StageDetails(frame, lay, az)
	local details = CreateFrame("Frame", nil, frame)
	details:SetSize(lay.w, lay.aid - lay.aidsY)
	details:SetPoint("TOP", frame.scene, "BOTTOM", 0, 0)
	details:SetFrameLevel((frame:GetFrameLevel() or 1) + 2)
	frame.details = details
	frame.info = Theme.Text(details, Theme.F_BODY or Theme.F_SMALL, Theme.LABEL)
	frame.info:SetPoint("TOP", details, "TOP", 0, lay.infoY)
	frame.info:SetJustifyH("CENTER")
	if frame.info.SetWordWrap then frame.info:SetWordWrap(false) end
	if az then
		if ns.AzerothFont then ns.AzerothFont(frame.info, 12) end
		RoleInk(frame.info, "stage.chance")
	end
	frame.aidCells = {}
	local aids = ns.CAPTURE_AIDS or {}
	for index, def in ipairs(aids) do
		local cell = { id = def.id }
		cell.edge = Theme.Solid(details, "ARTWORK", Theme.EDGE, 1)
		cell.edge:SetSize(lay.aid + 2, lay.aid + 2)
		-- le nombre à droite de l'icône : la case est décalée de sa moitié
		cell.edge:SetPoint("TOP", details, "TOP", (index - (#aids + 1) / 2) * lay.aidStep - 6, lay.aidsY + 1)
		cell.icon = details:CreateTexture(nil, "ARTWORK", nil, 1)
		cell.icon:SetSize(lay.aid, lay.aid)
		cell.icon:SetPoint("CENTER", cell.edge, "CENTER", 0, 0)
		cell.icon:SetTexture(def.icon)
		cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		cell.count = Theme.Text(details, Theme.F_SMALL, Theme.MUTED_LIGHT)
		cell.count:SetPoint("LEFT", cell.edge, "RIGHT", 4, 0)
		if az then RoleInk(cell.count, "stage.aidCount") end
		frame.aidCells[index] = cell
	end
	return details
end

-- L'ombre au sol, sous la créature (sur le cadre : sous le modèle) : la
-- lueur douce du client, grisée, teinte sombre, peu opaque
local function GroundShadow(frame, az)
	local tex = frame:CreateTexture(nil, "BORDER", nil, 2)
	ns.CaptureArtPaint(tex, "ground")
	tex:SetSize(SHADOW.w, SHADOW.h)
	local c = az and ns.AZEROTH_INK and ns.AZEROTH_INK.woodDeep or Theme.SHADOW
	tex.tint = c
	tex.alphaMax = az and SHADOW.alpha.azeroth or SHADOW.alpha.sobre
	tex:SetVertexColor(c[1], c[2], c[3], tex.alphaMax)
	tex:SetPoint("CENTER", frame.scene, "CENTER", 0, SHADOW.y)
	tex:Show()
	frame.ground = tex
	return tex
end

function ns:EnsureCaptureStage()
	local want = StageStyle(self)
	local current = self.captureStage
	if current and ((current.uiStyle or "sobre") == want or current:IsShown()) then return current end
	self.captureStages = self.captureStages or {}
	if current then self.captureStages[current.uiStyle or "sobre"] = current end
	local kept = self.captureStages[want]
	if kept then self.captureStage = kept; return kept end
	-- un nom global : Échap la referme (UISpecialFrames), comme les fenêtres du thème (2.3.0)
	local frame = StageWindow(self, want == "azeroth")
	if not frame then return nil end
	local az = frame.azeroth and true or false
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	frame:EnableMouse(true)
	if Theme.RegisterEscapeClose then pcall(Theme.RegisterEscapeClose, frame) end
	-- un clic, une fois le verdict tombé : on ferme
	frame:SetScript("OnMouseUp", function()
		local rolling = ns.captureState and ns.captureState.rolling
		if rolling and rolling.result then rolling.closeAt = Clock() end
	end)
	-- cachée (Échap, ou la fin du lancer) : le verdict tombé, le lancer se
	-- termine au prochain relevé ; sans verdict encore, la capture se résout
	-- quand même et son résultat reste annoncé dans le chat
	frame:SetScript("OnHide", function(f)
		local rolling = ns.captureState and ns.captureState.rolling
		f.rolling = nil
		if rolling and rolling.result then rolling.closeAt = Clock() end
		-- 2.15.0 : la carte de préparation refermée (Échap, combat) : le
		-- candidat reste au filet, son compte à rebours reprend
		if f.prep or f.prepOn then ns.CapturePrepClear(f) end
	end)
	-- 2.10.0 : le combat commence, la scène se ferme (OnHide ci-dessus) ; le
	-- lancer a déjà tiré son issue et se résout en arrière-plan, son verdict
	-- arrive dans le chat (Capture.lua, CaptureQueue.lua)
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	frame:SetScript("OnEvent", function(f, event)
		if event ~= "PLAYER_REGEN_DISABLED" or not f:IsShown() then return end
		local rolling = ns.captureState and ns.captureState.rolling
		f:Hide()
		if ns.CaptureHidePrompt then ns:CaptureHidePrompt() end
		-- verdict pas encore tombé : il viendra dans le chat
		if rolling and not rolling.result then ns:Print(ns.L.CAPTURE_STAGE_COMBAT) end
	end)
	local level = frame:GetFrameLevel() or 1
	local lay = az and AZS or SBS
	local width = lay.w

	if az then
		-- la plaque de titre : « CAPTURE · <RANG> » et le nom (or pour une
		-- brillante) ; 2.14.0 (bêta 3) : le rang dans le titre, plus de
		-- losanges de rareté ni de badge d'aide (les aides sont sous la chance)
		frame.plate = self:AzerothPlate(frame, AZS.plateW, AZS.plateH)
		frame.plate:SetPoint("TOP", frame, "TOP", 0, AZS.plateY)
		frame.title = frame.plate.title
	else
		-- filet haut à la couleur de la rareté, titre, puis le nom
		frame.topBar = Theme.Solid(frame, "BORDER", WHITE, 1)
		frame.topBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
		frame.topBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
		frame.topBar:SetHeight(3)
		frame.title = Theme.Text(frame, Theme.F_CAPS or Theme.F_SMALL, Theme.MUTED_LIGHT)
		frame.title:SetPoint("TOP", frame, "TOP", 0, SBS.titleY)
		frame.title:SetWidth(STAGE_W - 24)
		frame.title:SetJustifyH("CENTER")
		frame.name = Theme.Text(frame, Theme.F_HEADING or Theme.F_BODY, Theme.PARCHMENT)
		frame.name:SetPoint("TOP", frame, "TOP", 0, SBS.nameY)
		frame.name:SetWidth(STAGE_W - 24)
		frame.name:SetJustifyH("CENTER")
	end
	frame.title:SetText(Theme.Upper and Theme.Upper(L.CAPTURE_STAGE_TITLE) or L.CAPTURE_STAGE_TITLE)

	-- la scène : un carré centré où vit le modèle, posé à même la carte
	-- (2.14.0 bêta 3 : plus de vignette noire ni de halo derrière lui), son
	-- ombre au sol. Derrière lui, sur le cadre lui-même (un cadre enfant passe
	-- toujours devant les textures de son parent) : rayons et halo du verdict
	frame.scene = CreateFrame("Frame", nil, frame)
	frame.scene:SetSize(SCENE, SCENE)
	frame.scene:SetPoint("TOP", frame, "TOP", 0, lay.sceneY)
	-- la créature qui s'enfuit ne sort pas de la scène
	Method(frame.scene, "SetClipsChildren", true)
	GroundShadow(frame, az)
	frame.rays = Art(frame, "ARTWORK", 0, "rays", nil, 300, 300, "ADD")
	frame.rays2 = Art(frame, "ARTWORK", 1, "rays", nil, 240, 240, "ADD")
	frame.halo = Art(frame, "ARTWORK", 2, "halo", nil, 220, 220, "ADD")
	for _, tex in ipairs({ frame.rays, frame.rays2, frame.halo }) do
		tex:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)
	end
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, frame.scene)
	if ok and model then
		model:SetSize(MODEL, MODEL)
		model:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)
		frame.model = model
	end
	frame.fallback = frame.scene:CreateTexture(nil, "ARTWORK")
	frame.fallback:SetSize(72, 72)
	frame.fallback:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)
	frame.fallback:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
	frame.fallback:Hide()
	StageDetails(frame, lay, az)

	-- les effets, en trois calques au-dessus du modèle (cadres enfants :
	-- ils passent devant le 3D) : la poussière, le filet et son ombre (un
	-- cadre à eux : il grossit avec SetScale), puis ce qui vole au-dessus
	frame.fx = CreateFrame("Frame", nil, frame)
	frame.fx:SetAllPoints(frame.scene)
	frame.fx:SetFrameLevel(level + 10)
	frame.dust = Art(frame.fx, "ARTWORK", 0, "dust", nil, 60, 20, "ADD")
	frame.dusts = {}
	for index = 1, DUST do
		local p = Art(frame.fx, "ARTWORK", 1, "sparks", nil, 10, 10, "ADD")
		p.angle = (index / DUST) * math.pi * 2 + 0.4
		p.reach = 60 + (index % 3) * 8
		frame.dusts[index] = p
	end
	frame.puffs = {}
	for index = 1, PUFFS do
		frame.puffs[index] = Art(frame.fx, "ARTWORK", 1, "dust", nil, 24, 24, "ADD")
	end
	frame.netFrame = CreateFrame("Frame", nil, frame.fx)
	frame.netFrame:SetSize(NET, NET)
	frame.netFrame:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)
	frame.netFrame:SetFrameLevel(level + 11)
	frame.netShadow = Art(frame.netFrame, "ARTWORK", 0, "net", COORDS.netWhole, NET)
	Theme.Shade(frame.netShadow, Theme.SHADE.mid)
	frame.net = Art(frame.netFrame, "ARTWORK", 1, "net", COORDS.netWhole, NET)
	frame.net:SetPoint("CENTER", frame.netFrame, "CENTER", 0, 0)
	frame.fxTop = CreateFrame("Frame", nil, frame)
	frame.fxTop:SetAllPoints(frame.scene)
	frame.fxTop:SetFrameLevel(level + 12)
	frame.bundle = Art(frame.fxTop, "ARTWORK", 3, "bundle", nil, 52)
	frame.trail = {}
	for index = 1, TRAIL do
		local p = Art(frame.fxTop, "ARTWORK", 2, "sparks", nil, 22 - 2 * index, 22 - 2 * index, "ADD")
		p.lag = 0.06 * index
		p.fade = 0.55 * (1 - index / TRAIL)
		frame.trail[index] = p
	end
	frame.ropes = {}
	for index = 1, ROPES do
		local p = Art(frame.fxTop, "ARTWORK", 2, "rope", nil, 36 + (index * 11) % 25, 7)
		p.vx = ((index * 37) % 11 - 5) * 30
		p.vy = 80 + (index * 17) % 5 * 35
		p.spin = ((index * 13) % 7 - 3) * 1.6
		p.rot0 = index * 0.8
		frame.ropes[index] = p
	end
	frame.burst = {}
	for index = 1, BURST do
		local kind = BURST_KINDS[index % 3 + 1]
		local size = BURST_SIZES[index % 3 + 1]
		local p = Art(frame.fxTop, "ARTWORK", 4, "sparks", COORDS[kind], size, size, "ADD")
		p.angle = (index / BURST) * math.pi * 2 + (index % 2) * 0.2
		p.reach = 95 + (index % 3) * 20
		p.spin = ((index * 7) % 5 - 2) * 1.5
		frame.burst[index] = p
	end
	frame.motes = {}
	for index = 1, MOTES do
		local size = 8 + (index % 3) * 3
		local p = Art(frame.fxTop, "ARTWORK", 1, "sparks", nil, size, size, "ADD")
		p.x = ((index * 53) % 21 - 10) * 10
		p.phase = index * 0.7
		p.speed = 14 + (index % 4) * 5
		frame.motes[index] = p
	end
	frame.flash = Art(frame.fxTop, "ARTWORK", 5, "halo", nil, ns.CAPTURE_FLASH.size, ns.CAPTURE_FLASH.size, "ADD")
	frame.flash:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)

	if az then
		-- le verdict : le bandeau des hauts faits (il éclot depuis sa zone
		-- fixe, posée sur la chance et les aides), « CAPTURÉ ! » ou
		-- « ÉCHAPPÉ… », le nom ou la phrase, les étoiles du spécimen dedans,
		-- le bouclier d'or ou gris et son éclat
		frame.banner = self:AzerothVerdict(frame, AZS.verdictW, AZS.verdictH)
		frame.banner.azScale = AZS.verdictScale
		frame.banner.area:SetPoint("TOP", frame, "TOP", 0, AZS.verdictY)
		frame.banner.area:SetFrameLevel(level + 13)
		frame.banner:SetFrameLevel(level + 13)
		-- le nom, sur la plaque
		frame.name = frame.plate.text
	else
		-- le ruban (cadre à part : il surgit avec SetScale), son liseré, son texte,
		-- et le reflet d'une brillante (dans un cadre qui rogne ses enfants) ;
		-- posé sur la chance et les aides
		frame.banner = CreateFrame("Frame", nil, frame)
		frame.banner:SetSize(RIBBON_W, RIBBON_H)
		frame.banner:SetPoint("CENTER", frame.scene, "BOTTOM", 0, SBS.ribbonY)
		frame.banner:SetFrameLevel(level + 13)
		frame.ribbonPanel = Art(frame.banner, "ARTWORK", 0, "ribbon", nil)
		frame.ribbonPanel:SetAllPoints(frame.banner)
		frame.ribbonPanel:Show()
		frame.ribbonTrim = Art(frame.banner, "ARTWORK", 1, "ribbon", nil)
		frame.ribbonTrim:SetAllPoints(frame.banner)
		-- 2.11.0 : la bannière du client a son propre bord : pas de liseré à nous
		if frame.ribbonPanel.clientArt then frame.ribbonTrim:Hide() else frame.ribbonTrim:Show() end
		frame.sheenClip = CreateFrame("Frame", nil, frame.banner)
		frame.sheenClip:SetSize(RIBBON_W * 0.6, 38)
		frame.sheenClip:SetPoint("CENTER", frame.banner, "CENTER", 0, 0)
		frame.sheenClip.clips = Method(frame.sheenClip, "SetClipsChildren", true) == true
		frame.sheen = Art(frame.sheenClip, "ARTWORK", 0, "halo", nil, 60, 90, "ADD")
		frame.sheen:SetVertexColor(WHITE[1], WHITE[2], WHITE[3], 0.35)
		frame.bannerText = Theme.Text(frame.banner, Theme.F_DISPLAY or Theme.F_TITLE, Theme.PARCHMENT)
		frame.bannerText:SetPoint("CENTER", frame.banner, "CENTER", 0, 2)
		frame.banner:Hide()
	end
	-- les étoiles du spécimen : sous le ruban (Sobre), dans le bandeau (Azeroth)
	local starHost = az and frame.banner or frame
	frame.starSlots = {}
	for index = 1, 3 do
		local star = Art(starHost, "OVERLAY", 1, "stars", nil, 18)
		if az then
			star:SetPoint("TOP", frame.banner, "TOP", (index - 2) * 20, frame.banner.lineY)
		else
			star:SetPoint("TOP", frame.banner, "BOTTOM", (index - 2) * 20, -2)
		end
		frame.starSlots[index] = star
	end
	frame.starSpark = Art(starHost, "OVERLAY", 2, "sparks", nil, 22, 22, "ADD")
	-- les losanges des secousses : sous la scène (or en Azeroth)
	frame.shakeDots = {}
	for index = 1, 3 do
		local size = lay.dots
		local dot = Theme.CreateDiamond and Theme.CreateDiamond(frame, size) or frame:CreateTexture(nil, "OVERLAY")
		dot:SetPoint("TOP", frame.scene, "BOTTOM", (index - 2) * (size + 6), lay.dotsY)
		dot:Hide()
		frame.shakeDots[index] = dot
	end
	if az then frame.dotOff, frame.dotOffAlpha = Theme.GOLD, 0.25 end
	-- le pied : dans la carte, au-dessus de l'encadré (Azeroth : à l'encre)
	frame.footer = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.footer:SetPoint("BOTTOM", frame, "BOTTOM", 0, lay.footer)
	frame.footer:SetWidth(width - (az and 2 * (ns.AZEROTH_CARD and ns.AZEROTH_CARD.pad or 16) or 24))
	frame.footer:SetJustifyH("CENTER")
	if az then
		if frame.footer.SetWordWrap then frame.footer:SetWordWrap(false) end
		RoleInk(frame.footer, "stage.status")
	end
	-- 3.1.0 : taille et caractère du spécimen pris (« Grand · Curieux »),
	-- juste au-dessus du pied, écrits par SpecimenTraits.lua au verdict
	frame.specTags = Theme.Text(frame, Theme.F_SMALL, Theme.GOLD_LIGHT)
	frame.specTags:SetPoint("BOTTOM", frame.footer, "TOP", 0, 2)
	frame.specTags:SetWidth(width - (az and 2 * (ns.AZEROTH_CARD and ns.AZEROTH_CARD.pad or 16) or 24))
	frame.specTags:SetJustifyH("CENTER")
	if frame.specTags.SetWordWrap then frame.specTags:SetWordWrap(false) end
	if az then RoleInk(frame.specTags, "stage.status") end
	frame.specTags:Hide()
	frame:SetScript("OnUpdate", function()
		local done, err = pcall(ns.CaptureStageUpdate, ns, Clock())
		if not done and ns.RecordError then ns:RecordError("capture:stage", err) end
	end)
	frame:Hide()
	self.captureStages[frame.uiStyle or "sobre"] = frame
	self.captureStage = frame
	return frame
end

-- ---------------------------------------------------------------------------
-- Ouvrir, fermer
-- ---------------------------------------------------------------------------
-- La créature (le modèle, ou l'icône de repli) : position, opacité, cap
local function Creature(frame, x, y, alpha, facing)
	if frame.model then
		Place(frame.model, frame.scene, x, y)
		Method(frame.model, "SetAlpha", alpha)
		if facing then Method(frame.model, "SetFacing", facing) end
	end
	Place(frame.fallback, frame.scene, x, y)
	frame.fallback:SetAlpha(alpha)
	-- 2.14.0 (bêta 3) : son ombre au sol la suit (la fuite) et s'efface avec elle
	local ground = frame.ground
	if ground then
		Place(ground, frame.scene, x, SHADOW.y)
		Tint(ground, ground.tint, ground.alphaMax * alpha)
	end
end

-- Tout au repos : rien ne vole, rien ne brille
local function Rest(frame)
	frame.bundle:Hide()
	HideAll(frame.trail)
	HideAll(frame.dusts)
	HideAll(frame.puffs)
	HideAll(frame.ropes)
	HideAll(frame.burst)
	HideAll(frame.motes)
	HideAll(frame.starSlots)
	HideAll(frame.shakeDots)
	frame.dust:Hide()
	frame.flash:Hide()
	frame.rays:Hide()
	frame.rays2:Hide()
	frame.halo:Hide()
	frame.net:Hide()
	frame.netShadow:Hide()
	frame.starSpark:Hide()
	if frame.sheen then frame.sheen:Hide() end
	if frame.banner.azeroth then
		frame.banner.bling:Hide()
		frame.banner.shine:Hide()
		frame.banner.glow:SetAlpha(0)
		frame.banner:SetShield(nil)
		if frame.banner.SetLevel then frame.banner:SetLevel(nil) end
		frame.banner.filled = nil
	end
	frame.banner:Hide()
	frame.banner:SetScale(frame.banner.azScale or 1)
	frame.netFrame:SetScale(1)
	Place(frame.netFrame, frame.scene, 0, 0)
	Coord(frame.net, COORDS.netWhole)
	Coord(frame.netShadow, COORDS.netWhole)
	Rotate(frame.net, 0)
	Rotate(frame.netShadow, 0)
	frame.torn = nil
end

-- 2.14.0 (bêta 3) : la chance du lancer (aide et malchance comprises,
-- rolling.chance) suivie des étoiles à gagner (celles du spécimen déjà
-- pris pleines, les autres vides : ns:CaptureStarsText), puis les aides
-- (celle du lancer allumée, les autres grisées, le nombre en poche)
ns.CAPTURE_STAGE_STAR_SIZE = 14
function ns:CaptureStageDetails(frame, rolling)
	frame = frame or self.captureStage
	if not (frame and frame.info and rolling) then return nil end
	local target = rolling.target or {}
	local sure = rolling.aid == "sifflet"
	local chance = tonumber(rolling.chance)
	local text
	if sure or (chance and chance >= 1) then
		text = L.CAPTURE_STAGE_SURE
	else
		text = self:F("CAPTURE_STAGE_CHANCE", math.floor((chance or 0) * 100 + 0.5 + 1e-9))
	end
	if self.CaptureStarsText and target.npcID then
		local owned = self.CaptureStars and self:CaptureStars(target.npcID, target.shiny and true or false)
		text = text .. "   " .. self:CaptureStarsText(owned or 0, ns.CAPTURE_STAGE_STAR_SIZE)
	end
	frame.info:SetText(text)
	for _, cell in ipairs(frame.aidCells or {}) do
		local chosen = cell.id == rolling.aid
		local count = self.CaptureAidCount and self:CaptureAidCount(cell.id) or 0
		cell.count:SetText(count > 0 and tostring(count) or "")
		if cell.icon.SetDesaturated then cell.icon:SetDesaturated(not chosen) end
		cell.icon:SetAlpha(chosen and 1 or 0.45)
		local edge = chosen and Theme.GOLD or Theme.EDGE
		cell.edge:SetVertexColor(edge[1], edge[2], edge[3], 1)
		cell.chosen = chosen
	end
	frame.details:Show()
	return text
end

-- L'en-tête de la carte (lancer comme préparation) : rareté, modèle ou
-- portrait, « CAPTURE · <RANG> » (2.15.0 : « · NIV. n » en préparation), le nom
local function StageHeader(self, frame, target, withLevel)
	local rarity = self:CaptureRarity(target)
	frame.rarity = rarity
	frame.shiny = target.shiny and true or false
	local c = rarity.color
	if frame.topBar then frame.topBar:SetVertexColor(c[1], c[2], c[3], 1) end
	local shown = self:CaptureModelSetup(frame.model, target)
	-- 2.11.0 : sans modèle, le portrait 2D de la créature (ou l'icône de son type)
	if not shown then self:CreaturePortrait(frame.fallback, target) end
	Creature(frame, 0, 0, 1, 0)
	if shown then frame.fallback:Hide() else frame.fallback:Show() end
	frame.hasModel = shown
	Rest(frame)
	Tint(frame.halo, c, 0)
	local label = target.shiny and self:F("CAPTURE_SHINY_TAG", target.name) or target.name
	-- 2.14.0 (bêta 3) : « CAPTURE · <RANG> » (le rang remplace les losanges)
	local rank = L["CAPTURE_RANK_" .. tostring(target.class or "normal")] or L.CAPTURE_RANK_normal
	local title = L.CAPTURE_STAGE_TITLE .. " · " .. tostring(rank or "")
	if withLevel and tonumber(target.level) then title = title .. " · " .. self:F("CAPTURE_PREP_LEVEL", tonumber(target.level)) end
	frame.title:SetText(ns.AzerothUpper and ns.AzerothUpper(title) or (Theme.Upper and Theme.Upper(title)) or title)
	if frame.plate then
		-- sur la plaque : blanc, or pour une brillante, la police rapetisse
		if ns.AzerothFit then ns.AzerothFit(frame.plate.title, frame.plate.nameW, 11, 9) end
		frame.plate:SetName(label, target.shiny)
	else
		frame.bannerText:SetText("")
		frame.name:SetText(label)
		-- 2.11.0 : le nom prend la variante claire du rang (lisible en Sobre)
		local ink = rarity.text or c
		frame.name:SetTextColor(ink[1], ink[2], ink[3])
	end
	return rarity
end

function ns:CaptureShowStage(rolling)
	local frame = self:EnsureCaptureStage()
	if not (frame and rolling) then return nil end
	-- 2.15.0 : la carte quitte sa préparation (même carte, le lancer y prend place)
	if frame.prep or frame.prepOn then ns.CapturePrepClear(frame) end
	local target = rolling.target
	frame.rolling = rolling
	-- la scène Azeroth montre le verdict : pas de bandeau « Capturé ! » en double (AzerothStyle.lua)
	rolling.sceneVerdict = frame.azeroth or nil
	StageHeader(self, frame, target)
	self:CaptureStageDetails(frame, rolling)
	frame.footer:SetText(L.CAPTURE_SHAKING)
	frame.played = nil
	-- (venue de la préparation : déjà à l'écran, pas de nouveau fondu)
	local fresh = not frame:IsShown()
	frame:Show()
	if fresh and Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	self:CaptureStageUpdate(Clock())
	return frame
end

function ns:CaptureHideStage()
	local frame = self.captureStage
	if frame then
		frame.rolling = nil
		frame:Hide()
	end
end

-- ---------------------------------------------------------------------------
-- Une image : tout se déduit de l'horloge et de l'état du lancer
-- ---------------------------------------------------------------------------
-- La trajectoire du paquet : du bas à gauche au centre, en arc
local function Arc(p)
	return -120 + 120 * p, -150 + 150 * p + 70 * math.sin(math.pi * p)
end

-- 1. Le lancer : le paquet vole en tournant, sa traînée derrière lui ; à
-- l'apogée il s'ouvre en filet, un peu au-dessus de la créature
local function StageThrow(frame, p, c)
	local x, y = Arc(p)
	Place(frame.bundle, frame.scene, x, y)
	Rotate(frame.bundle, p * math.pi * 4)
	Fade(frame.bundle, 1 - Clamp01((p - 0.82) / 0.18))
	for _, spark in ipairs(frame.trail) do
		local q = p - spark.lag
		if q > 0 then
			local tx, ty = Arc(q)
			Place(spark, frame.scene, tx, ty)
			Tint(spark, frame.shiny and Theme.GOLD or Theme.GOLD_LIGHT, 1)
			Fade(spark, spark.fade)
		else
			spark:Hide()
		end
	end
	local open = Clamp01((p - 0.8) / 0.2)
	if open > 0 then
		Place(frame.netFrame, frame.scene, x * (1 - open), y * (1 - open) + 40 * open)
		frame.netFrame:SetScale(0.3 + 0.3 * open)
		Fade(frame.net, open)
	else
		frame.net:Hide()
	end
	frame.netShadow:Hide()
	frame.dust:Hide()
	HideAll(frame.dusts)
	frame.flash:Hide()
	Creature(frame, 0, 0, 1, 0)
	-- 2.14.0 (bêta 3) : plus de halo derrière la créature pendant le lancer
	frame.halo:Hide()
end

-- 2-3. La pose, puis les secousses : le filet tombe d'un peu plus haut et
-- rebondit, son ombre le rejoint ; à chaque secousse il oscille et se
-- resserre, la créature se débat, le halo pulse de plus en plus vite
local function StageShake(frame, since, t, rolling, c)
	local step = ns.CAPTURE_SHAKE_STEP
	local inStep = (since % step) / step
	-- une secousse au début de chaque pas, amortie
	local wobble = inStep < 0.5 and math.sin(inStep * math.pi * 6) * 9 * (1 - inStep * 2) or 0
	local drape = Clamp01(since / ns.CAPTURE_DRAPE_TIME)
	local squeeze = inStep < 0.5 and 0.05 * math.sin(inStep * math.pi * 2) or 0
	local scale = 0.6 + 0.4 * EaseBack(drape) - squeeze - 0.01 * rolling.done
	local lift = 40 * (1 - EaseOut(drape))
	frame.bundle:Hide()
	HideAll(frame.trail)
	Place(frame.netFrame, frame.scene, wobble * 0.4, lift)
	frame.netFrame:SetScale(math.max(0.05, scale))
	Rotate(frame.net, wobble * 0.012)
	Rotate(frame.netShadow, wobble * 0.012)
	Fade(frame.net, 1)
	-- l'ombre reste au sol pendant que le filet tombe, puis se recolle à lui
	Place(frame.netShadow, frame.netFrame, 4, -8 - lift)
	frame.netShadow:SetSize(NET * (1 + 0.003 * lift), NET * (1 + 0.003 * lift))
	Theme.Shade(frame.netShadow, Theme.SHADE.soft + 0.2 * drape)
	frame.netShadow:Show()
	-- la créature se débat dessous
	Creature(frame, wobble, 0, 0.85, wobble * 0.06)
	-- éclair bref et poussière à l'impact
	Tint(frame.flash, WHITE, 1)
	Fade(frame.flash, ns.CAPTURE_FLASH.impact - since * 3)
	local u = since / 0.6
	if u < 1 then
		local w = 60 + 110 * EaseOut(u)
		frame.dust:SetSize(w, w * 0.3)
		Place(frame.dust, frame.scene, 0, -56)
		Tint(frame.dust, DUST_COLOR, 1)
		Fade(frame.dust, 0.45 * (1 - u))
	else
		frame.dust:Hide()
	end
	local v = since / 0.7
	for _, grain in ipairs(frame.dusts) do
		if v < 1 then
			local d = grain.reach * EaseOut(v)
			Place(grain, frame.scene, math.cos(grain.angle) * d, -52 + math.sin(grain.angle) * 10 + 22 * v)
			Tint(grain, DUST_COLOR, 1)
			Fade(grain, 0.5 * (1 - v))
		else
			grain:Hide()
		end
	end
	-- 2.14.0 (bêta 3) : plus de halo qui pulse derrière elle (la créature
	-- est posée sur la carte) ; les losanges disent les secousses
	frame.halo:Hide()
	-- les secousses : un losange allumé par secousse commencée
	local lit = math.min(rolling.done + 1, 3)
	for index, dot in ipairs(frame.shakeDots) do
		local on = index <= lit
		local col = on and Theme.GOLD or (frame.dotOff or Theme.EDGE)
		dot:SetVertexColor(col[1], col[2], col[3], on and 1 or (frame.dotOffAlpha or 1))
		dot:Show()
	end
	frame.footer:SetText(L.CAPTURE_SHAKING)
end

-- Le ruban surgit (dépasse un peu, puis se pose), à ses couleurs
local function Banner(frame, r, panel, trim, text, color)
	local pop = Clamp01(r / 0.3)
	frame.banner:SetScale(math.max(0.05, EaseBack(pop)))
	Tint(frame.ribbonPanel, panel, 1)
	Tint(frame.ribbonTrim, trim, 1)
	frame.bannerText:SetText(text)
	frame.bannerText:SetTextColor(color[1], color[2], color[3])
	frame.banner:Show()
end

-- Azeroth : le bandeau des hauts faits surgit (même rebond), sa lueur, le
-- bouclier (or ou gris) et son éclat ; une brillante : le reflet le traverse
local function Verdict(frame, r, ok, rolling)
	local banner = frame.banner
	local colors = ns.AZEROTH_COLORS or {}
	local pop = Clamp01(r / 0.3)
	banner:SetScale(math.max(0.05, EaseBack(pop)) * (banner.azScale or 1))
	if not banner.filled or banner.filled ~= (ok and "ok" or "fail") then
		banner.filled = ok and "ok" or "fail"
		local target = rolling.target
		local title = ok and L.CAPTURE_GOT or L.CAPTURE_FLED
		banner.title:SetText(ns.AzerothUpper and ns.AzerothUpper(title) or title)
		if ok then
			banner.text:SetText(target.name)
			local c = target.shiny and (colors.shinyName or Theme.GOLD_LIGHT) or WHITE
			banner.text:SetTextColor(c[1], c[2], c[3], 1)
			banner.line:SetText("")
			banner.line:Hide()
		else
			-- la phrase, en grand ; le nom est déjà sur la plaque
			banner.text:SetText(L.CAPTURE_STAGE_FAIL)
			local c = colors.fled or Theme.MUTED_LIGHT
			banner.text:SetTextColor(c[1], c[2], c[3], 1)
			banner.line:Hide()
		end
		banner:SetShield(ok and "gold" or "grey")
		-- 2.8.0 : la tête de la créature dans le cadre d'icône, son niveau dans le bouclier
		if banner.SetCreature then banner:SetCreature(target) end
		if banner.SetLevel then banner:SetLevel(target.level) end
		banner:Fit()
	end
	banner:Show()
	-- la lueur derrière, à l'éclosion
	local g = r - 0.1
	banner.glow:SetAlpha(g < 0 and 0 or (g < 0.3 and 0.8 * g / 0.3 or 0.8 * Clamp01(1 - (g - 0.3) / 0.9)))
	-- l'éclat sur le bouclier d'or
	local b = (r - 0.35) / 1.2
	if ok and b >= 0 and b <= 1 then
		local size = 44 + 88 * Clamp01(b / 0.6)
		banner.bling:SetSize(size, size)
		banner.bling:SetAlpha(b < 0.25 and b / 0.25 or Clamp01(1 - (b - 0.25) / 0.6))
		Rotate(banner.bling, 0.7 * b)
		banner.bling:Show()
	else
		banner.bling:Hide()
	end
	-- le reflet d'une brillante, de gauche à droite, en boucle
	if ok and frame.shiny then
		local s = ((r - 0.4) % 2.2) / 1.3
		if r >= 0.4 and s <= 1 then
			Place(banner.shine, banner, -150 + 300 * s, 0)
			banner.shine:SetAlpha(s < 0.35 and 0.9 * s / 0.35 or 0.9 * Clamp01(1 - (s - 0.35) / 0.65))
			banner.shine:Show()
		else
			banner.shine:Hide()
		end
	else
		banner.shine:Hide()
	end
end

-- 4. Capturé : éclair, gerbe de rayons et d'étincelles, le filet se referme
-- sur elle, elle tourne sur elle-même, le ruban, puis les étoiles une à une
local function StageOk(frame, r, rolling, c)
	local shiny = frame.shiny
	local col = shiny and Theme.GOLD_LIGHT or c
	if not frame.played then frame.played = true; if not ns.CapturePlaySound then PlayKit("UI_EPICLOOT_TOAST") end end
	Tint(frame.flash, WHITE, 1)
	Fade(frame.flash, ns.CAPTURE_FLASH.ok * (1 - r / 0.4))
	-- les rayons grandissent, tournent, puis s'effacent
	local grow = 0.4 + 0.7 * EaseOut(r / 0.5)
	local life = math.min(1, r / 0.15) * (1 - Clamp01((r - 1.3) / 1.6))
	frame.rays:SetSize(300 * grow, 300 * grow)
	Rotate(frame.rays, r * 0.5)
	Tint(frame.rays, col, 1)
	Fade(frame.rays, 0.85 * life)
	if shiny then
		frame.rays2:SetSize(240 * grow, 240 * grow)
		Rotate(frame.rays2, -r * 0.8)
		Tint(frame.rays2, Theme.GOLD, 1)
		Fade(frame.rays2, 0.5 * life)
	else
		frame.rays2:Hide()
	end
	Tint(frame.halo, col, 0.35 + 0.55 * math.max(0, 1 - r / 1.2))
	frame.halo:SetSize(230, 230)
	frame.halo:Show()
	-- le filet se referme sur elle et s'efface dans l'éclair
	local close = Clamp01(r / 0.5)
	Place(frame.netFrame, frame.scene, 0, 0)
	frame.netFrame:SetScale(1 - 0.45 * EaseOut(close))
	Rotate(frame.net, 0)
	Rotate(frame.netShadow, 0)
	local netAlpha = 1 - Clamp01((r - 0.3) / 0.4)
	Fade(frame.net, netAlpha)
	Place(frame.netShadow, frame.netFrame, 4, -8)
	frame.netShadow:SetSize(NET, NET)
	Theme.Shade(frame.netShadow, Theme.SHADE.mid)
	Fade(frame.netShadow, netAlpha)
	-- un tour sur elle-même, qui ralentit
	Creature(frame, 0, 0, 1, EaseOut(r / 1.2) * math.pi * 2)
	-- la gerbe : étoiles, étincelles et points filent du centre, retombent un
	-- peu et s'éteignent
	local burst = Clamp01(r / 0.9)
	for _, p in ipairs(frame.burst) do
		if burst < 1 then
			local d = p.reach * EaseOut(burst)
			Place(p, frame.scene, math.cos(p.angle) * d, math.sin(p.angle) * d - 40 * burst * burst)
			Rotate(p, p.angle + r * p.spin)
			Tint(p, col, 1)
			Fade(p, 1 - burst)
		else
			p:Hide()
		end
	end
	-- une brillante : des motes dorées montent tout du long
	for _, p in ipairs(frame.motes) do
		if shiny then
			local y = ((r * p.speed + p.phase * 30) % 160) - 80
			Place(p, frame.scene, p.x + 6 * math.sin(r * 2 + p.phase), y)
			Tint(p, Theme.GOLD_LIGHT, 1)
			Fade(p, 0.3 + 0.5 * math.abs(math.sin(r * 3 + p.phase)))
		else
			p:Hide()
		end
	end
	if frame.banner.azeroth then
		Verdict(frame, r, true, rolling)
	else
		Banner(frame, r, shiny and PANEL_SHINY or { c[1] * 0.42, c[2] * 0.42, c[3] * 0.42 }, col, L.CAPTURE_GOT, Theme.PARCHMENT)
	end
	-- le reflet balaie le ruban (si le client sait rogner ses enfants)
	if not frame.sheen then
		-- (Azeroth : le reflet du bandeau, ci-dessus)
	elseif shiny and frame.sheenClip.clips then
		Place(frame.sheen, frame.sheenClip, -170 + ((r * 200) % 400), 0)
		frame.sheen:Show()
	else
		frame.sheen:Hide()
	end
	-- les étoiles du spécimen (CaptureQueue.lua), une à une, avec une étincelle
	local stars = tonumber(rolling.stars)
	frame.starSpark:Hide()
	for index, star in ipairs(frame.starSlots) do
		local q = stars and (r - (0.45 + 0.18 * (index - 1))) / 0.2 or -1
		if q >= 0 then
			local size = 18 * (1 + 0.6 * (1 - EaseOut(q)))
			star:SetSize(size, size)
			local full = index <= stars
			-- 2.11.0 : l'étoile du client, grisée quand elle est vide
			if star.clientArt and star.SetDesaturated then star:SetDesaturated(not full) end
			Tint(star, full and Theme.GOLD_LIGHT or STAR_GREY, 1)
			star:Show()
			if full and index == stars and q < 1.2 then
				local spark = frame.starSpark
				spark:ClearAllPoints()
				spark:SetPoint("CENTER", star, "CENTER", 7, 6)
				spark:SetSize(22 - 8 * Clamp01(q / 1.2), 22 - 8 * Clamp01(q / 1.2))
				Tint(spark, WHITE, 1)
				Fade(spark, 1 - q / 1.2)
			end
		else
			star:Hide()
		end
	end
	HideAll(frame.shakeDots)
	frame.footer:SetText(r > 1.2 and L.CAPTURE_STAGE_CLOSE or (shiny and L.CAPTURE_STAGE_SHINY or L.CAPTURE_STAGE_NEW))
end

-- Échappé : le filet bascule sur sa version déchirée et tombe, ses cordes
-- volent, le monstre file sur le côté dans la poussière et s'efface
local function StageFail(frame, r, c, rolling)
	if not frame.played then frame.played = true; if not ns.CapturePlaySound then PlayKit("IG_QUEST_LOG_ABANDON_QUEST") end end
	if not frame.torn then
		frame.torn = true
		Coord(frame.net, COORDS.netTorn)
	end
	frame.flash:Hide()
	frame.rays:Hide()
	frame.rays2:Hide()
	HideAll(frame.burst)
	HideAll(frame.motes)
	HideAll(frame.starSlots)
	frame.starSpark:Hide()
	if frame.sheen then frame.sheen:Hide() end
	frame.netShadow:Hide()
	-- un sursaut, puis la chute
	local snap = r < 0.25 and 1 + 0.08 * math.sin(r / 0.25 * math.pi) or 1
	Place(frame.netFrame, frame.scene, -6 * Clamp01(r / 0.5), -220 * r * r)
	frame.netFrame:SetScale(snap)
	Rotate(frame.net, -0.12 * r)
	Fade(frame.net, 1 - Clamp01((r - 0.5) / 0.6))
	-- les cordes volent en tous sens et retombent
	local ropeAlpha = 1 - Clamp01((r - 0.6) / 0.5)
	for _, p in ipairs(frame.ropes) do
		Place(p, frame.scene, p.vx * r, 20 + p.vy * r - 520 * r * r)
		Rotate(p, p.rot0 + p.spin * r)
		Fade(p, ropeAlpha)
	end
	-- la fuite, de profil, dans la poussière
	local run = EaseOut(r / 0.8)
	Creature(frame, run * 100, 0, 1 - Clamp01(run * 1.3), -math.pi / 2)
	local v = Clamp01(r / 0.6)
	for index, puff in ipairs(frame.puffs) do
		local size = 24 + 14 * v + index * 4
		puff:SetSize(size, size)
		Place(puff, frame.scene, 20 + index * 18 + 30 * v, -46 + (index % 2) * 6)
		Tint(puff, DUST_COLOR, 1)
		Fade(puff, 0.35 * (1 - v))
	end
	Tint(frame.halo, Theme.RED, 0.35 * (1 - Clamp01(r / 1.5)))
	frame.halo:SetSize(200, 200)
	frame.halo:Show()
	if frame.banner.azeroth then
		Verdict(frame, r, false, rolling)
	else
		Banner(frame, r, PANEL_FAIL, TRIM_FAIL, L.CAPTURE_FLED, Theme.RED)
	end
	HideAll(frame.shakeDots)
	frame.footer:SetText(r > 1.2 and L.CAPTURE_STAGE_CLOSE or L.CAPTURE_STAGE_FAIL)
end

function ns:CaptureStageUpdate(now)
	local frame = self.captureStage
	local rolling = frame and frame.rolling
	if not rolling then return nil end
	local c = frame.rarity.color
	local t = now - (rolling.start or now)
	local throw = ns.CAPTURE_THROW_TIME

	if not rolling.result then
		frame.banner:Hide()
		if frame.details then frame.details:Show() end
		if t < throw then
			StageThrow(frame, Clamp01(t / throw), c)
			return "throw"
		end
		StageShake(frame, t - throw, t, rolling, c)
		return "shake"
	end
	local r = now - (rolling.resultAt or now)
	-- le verdict se pose sur la chance et les aides
	if frame.details then frame.details:Hide() end
	frame.bundle:Hide()
	HideAll(frame.trail)
	frame.dust:Hide()
	HideAll(frame.dusts)
	if rolling.result == "ok" then
		HideAll(frame.puffs)
		HideAll(frame.ropes)
		StageOk(frame, r, rolling, c)
		return "ok"
	end
	StageFail(frame, r, c, rolling)
	return "fail"
end

-- ---------------------------------------------------------------------------
-- 2.15.0 : la carte de PRÉPARATION (maquette capture215, écran 2). Le clic
-- sur le filet (ou le bandeau) n'envoie plus le filet : la carte compacte
-- s'ouvre sur le candidat, en préparation :
--   * en haut : « CAPTURE · <RANG> · NIV. n » et le nom (plaque ou titre) ;
--   * la créature et son ombre, puis sa qualité (tirée au coup fatal) :
--     « ★★★ Spécimen exceptionnel » (« · brillant » pour une brillante) ;
--   * « Chance 30 % » et, une aide choisie, l'écart en vert : « → 45 % avec
--     l'Appât » (malchance comprise, comme au lancer) ;
--   * les trois aides, cliquables (choisie : en couleurs, liseré d'or ; à 0 :
--     grisée, inactive ; infobulle : effet et nombre) ; sur un 3 étoiles ou
--     une brillante, la meilleure aide en poche est mise en avant
--     (« Conseillé : Sifflet (capture assurée) ») ;
--   * Lancer (la scène d'avant, avec l'aide choisie) et Passer (le candidat
--     sort du filet, la carte passe au suivant ou se ferme ; clic droit :
--     « Ne plus proposer cette espèce », CaptureSkip.lua) ;
--   * Échap ferme sans rien retirer : le compte à rebours, en pause tant que
--     la carte est ouverte (prise « prep »), reprend.
-- Réserve pleine (ns:CaptureBlockedReason) : le message sur la carte, Lancer
-- grisé, Passer reste. L'aide choisie est celle de la file (state.aid) :
-- Maj+clic et le raccourci lancent tout de suite avec elle. Bêta 6 : elle ne
-- sert qu'à un lancer (remise à zéro après, Capture.lua / CaptureBatch.lua) ;
-- l'aide conseillée n'est qu'une lueur, jamais choisie d'office.
-- Réglage « Lancer directement au clic » (CaptureQueue.lua) : comme avant.
-- La carte grandit de CAPTURE_PREP.extra pendant la préparation (le
-- parchemin est recadré à sa nouvelle hauteur) ; encres mesurées sur le
-- parchemin à 340×456 (scratchpad meas/card215.py), rôles stage.prep*.
-- ---------------------------------------------------------------------------
ns.CAPTURE_PREP = { qualityY = -3, legendY = -80, buttonsY = -98, buttonH = 28, buttonW = 128, gap = 14,
	extra = { azeroth = 38, sobre = 40 }, starSize = 13 }
local PREP = ns.CAPTURE_PREP
-- l'aide conseillée sur un 3 étoiles ou une brillante : la plus forte en poche
ns.CAPTURE_PREP_ADVICE_ORDER = { "sifflet", "lasso", "appat" }
-- rôle -> { encre, luminance du pire fond mesurée, seuil, taille (px) } ;
-- versés dans ns.AZEROTH_CONTRAST (défini plus tard, AzerothStyle.lua) par
-- ns.CapturePrepContrastMerge. Carte 340×456 (parchemin 130661 en Cover,
-- voile page 0,35) : qualité x 60-280 y 296-312, chance x 40-300 y 320-334,
-- légende x 20-320 y 372-386, pied x 16-324 y 430-444.
ns.CAPTURE_PREP_CONTRAST = {
	["stage.prepQuality"] = { "title", 0.3918, 4.5, 12 },        -- 3 étoiles, fond 0.392 (moy. 0.416) : 5.19:1
	["stage.prepQualityShiny"] = { "rShiny", 0.3918, 4.5, 12 },  -- brillante, même fond : 5.70:1
	["stage.prepQualityPlain"] = { "inkSoft", 0.3918, 4.5, 12 }, -- 1 ou 2 étoiles, même fond : 6.47:1
	["stage.prepChance"] = { "ink", 0.3700, 4.5, 12 },           -- fond 0.370 (moy. 0.407) : 7.53:1
	["stage.prepDelta"] = { "green", 0.3700, 4.5, 12 },          -- « → 45 % avec l'Appât », même fond : 5.36:1
	["stage.prepLegend"] = { "inkMuted", 0.3270, 4.5, 11 },      -- fond 0.327 (moy. 0.368) : 5.07:1
	["stage.prepBlocked"] = { "red", 0.3270, 4.5, 11 },          -- Réserve pleine, même fond : 4.85:1
	["stage.prepHint"] = { "ink", 0.2283, 4.5, 11 },             -- pied, fond 0.228 (moy. 0.251) : 4.99:1
}
function ns.CapturePrepContrastMerge()
	local table_ = ns.AZEROTH_CONTRAST
	if type(table_) ~= "table" then return false end
	for role, entry in pairs(ns.CAPTURE_PREP_CONTRAST) do
		if table_[role] == nil then table_[role] = entry end
	end
	return true
end
-- Sobre : sur le fond du socle (Theme.WINDOW), contrastes mesurés dans le test
ns.CAPTURE_PREP_SOBRE = { quality = Theme.GOLD, qualityShiny = Theme.GOLD_LIGHT, qualityPlain = Theme.LABEL,
	chance = Theme.LABEL, delta = Theme.GREEN, legend = Theme.MUTED_LIGHT, blocked = Theme.RED, hint = Theme.MUTED_LIGHT }

local PREP_FR = {
	CAPTURE_PREP_Q1        = "Spécimen commun",
	CAPTURE_PREP_Q2        = "Beau spécimen",
	CAPTURE_PREP_Q3        = "Spécimen exceptionnel",
	CAPTURE_PREP_SHINY     = "%s · brillant",
	CAPTURE_PREP_LEVEL     = "Niv. %d",
	CAPTURE_PREP_DELTA     = "→ %d %% %s",
	CAPTURE_PREP_DELTA_SURE = "→ capture assurée %s",
	CAPTURE_PREP_WITH_appat   = "avec l'Appât",
	CAPTURE_PREP_WITH_lasso   = "avec le Lasso",
	CAPTURE_PREP_WITH_sifflet = "avec le Sifflet",
	CAPTURE_PREP_SHORT_appat   = "Appât ×1,5",
	CAPTURE_PREP_SHORT_lasso   = "Lasso ×2,5",
	CAPTURE_PREP_SHORT_sifflet = "Sifflet : capture assurée",
	CAPTURE_PREP_ADVICE    = "Conseillé : %s",
	CAPTURE_PREP_ADVICE_appat   = "Appât (×1,5)",
	CAPTURE_PREP_ADVICE_lasso   = "Lasso (×2,5)",
	CAPTURE_PREP_ADVICE_sifflet = "Sifflet (capture assurée)",
	CAPTURE_PREP_LAUNCH    = "Lancer",
	CAPTURE_PREP_PASS      = "Passer",
	CAPTURE_PREP_LAUNCH_TIP = "Lance le filet, avec l'aide choisie s'il y en a une.",
	CAPTURE_PREP_PASS_TIP  = "Retire ce monstre du filet et passe au suivant.",
	CAPTURE_PREP_PASS_RIGHT = "Clic droit : ne plus proposer cette espèce",
	CAPTURE_PREP_AID_TOGGLE = "Clic : choisir pour ce lancer (re-clic : aucune aide)",
	CAPTURE_PREP_HINT      = "Échap : plus tard (il reste %d s)",
	CAPTURE_PREP_HINT_LATER = "Échap : plus tard",
	CAPTURE_PREP_BLOCKED   = "Réserve pleine (%d/%d) : relâche un spécimen pour capturer.",
}
local PREP_EN = {
	CAPTURE_PREP_Q1        = "Common specimen",
	CAPTURE_PREP_Q2        = "Fine specimen",
	CAPTURE_PREP_Q3        = "Exceptional specimen",
	CAPTURE_PREP_SHINY     = "%s · shiny",
	CAPTURE_PREP_LEVEL     = "Lvl %d",
	CAPTURE_PREP_DELTA     = "→ %d%% %s",
	CAPTURE_PREP_DELTA_SURE = "→ guaranteed %s",
	CAPTURE_PREP_WITH_appat   = "with the Bait",
	CAPTURE_PREP_WITH_lasso   = "with the Lasso",
	CAPTURE_PREP_WITH_sifflet = "with the Whistle",
	CAPTURE_PREP_SHORT_appat   = "Bait ×1.5",
	CAPTURE_PREP_SHORT_lasso   = "Lasso ×2.5",
	CAPTURE_PREP_SHORT_sifflet = "Whistle: guaranteed",
	CAPTURE_PREP_ADVICE    = "Advised: %s",
	CAPTURE_PREP_ADVICE_appat   = "Bait (×1.5)",
	CAPTURE_PREP_ADVICE_lasso   = "Lasso (×2.5)",
	CAPTURE_PREP_ADVICE_sifflet = "Whistle (guaranteed capture)",
	CAPTURE_PREP_LAUNCH    = "Throw",
	CAPTURE_PREP_PASS      = "Skip",
	CAPTURE_PREP_LAUNCH_TIP = "Throws the net, with the chosen aid if there is one.",
	CAPTURE_PREP_PASS_TIP  = "Removes this monster from the net and moves to the next one.",
	CAPTURE_PREP_PASS_RIGHT = "Right-click: stop offering this species",
	CAPTURE_PREP_AID_TOGGLE = "Click: use it for this throw (click again: no aid)",
	CAPTURE_PREP_HINT      = "Escape: later (%ds left)",
	CAPTURE_PREP_HINT_LATER = "Escape: later",
	CAPTURE_PREP_BLOCKED   = "Reserve full (%d/%d): release a specimen to capture.",
}
ns.RegisterStrings(PREP_FR, PREP_EN)
if ns.KEEP_STRINGS then ns.CAPTURE_PREP_STRINGS = { fr = PREP_FR, en = PREP_EN } end

-- la prise « prep » de la pause du compte à rebours (CaptureQueue.lua) :
-- tenue tant que la carte est ouverte en préparation
ns.CAPTURE_HOLD_CHECKS = ns.CAPTURE_HOLD_CHECKS or {}
ns.CAPTURE_HOLD_CHECKS.prep = function(self)
	local frame = self.captureStage
	return frame ~= nil and frame.prep ~= nil and frame:IsShown() and true or false
end

local function InCombat()
	local lockdown, affecting = G("InCombatLockdown"), G("UnitAffectingCombat")
	if type(lockdown) == "function" then
		local ok, value = pcall(lockdown)
		if ok and value then return true end
	end
	if type(affecting) == "function" then
		local ok, value = pcall(affecting, "player")
		if ok and value then return true end
	end
	return false
end
-- actif ou non (le client a Enable/Disable ; .off le dit partout)
local function SetOn(button, on)
	button.off = not on or nil
	if on then
		if button.Enable then button:Enable() end
	elseif button.Disable then
		button:Disable()
	end
end
local function Pct(chance) return math.floor((chance or 0) * 100 + 0.5 + 1e-9) end
local function Tooltip() local t = G("GameTooltip"); if type(t) == "table" and t.SetOwner then return t end end
local function HideTip() local t = Tooltip(); if t and t.Hide then t:Hide() end end
local function Ink(fs, az, role, sobre)
	if az and RoleInk(fs, role) then return end
	fs:SetTextColor(sobre[1], sobre[2], sobre[3], 1)
end

-- « ★★★ Spécimen exceptionnel » (« · brillant »)
function ns:CaptureQualityText(stars, shiny, size)
	stars = math.max(1, math.min(3, math.floor(tonumber(stars) or 1)))
	local text = (self.CaptureStarsText and self:CaptureStarsText(stars, size or PREP.starSize) or "") .. " " .. L["CAPTURE_PREP_Q" .. stars]
	if shiny then text = self:F("CAPTURE_PREP_SHINY", text) end
	return text
end

-- La chance du lancer, comme ns:CaptureRoll la calculera (malchance comprise)
function ns:CapturePrepChance(candidate, aid)
	local chance, sure = self:CaptureChance(candidate, aid)
	if sure then return 1, true end
	local pity = ns.CAPTURE_PITY
	local streak = pity and math.min(pity.max, tonumber(self:CaptureData().missStreak) or 0) or 0
	if streak > 0 then chance = math.min(ns.CAPTURE_MAX or 1, chance + pity.step * streak) end
	return chance, chance >= 1
end

-- L'aide conseillée (un 3 étoiles ou une brillante) : la plus forte en poche, ou nil
function ns:CapturePrepAdvice(candidate)
	if type(candidate) ~= "table" or not (candidate.shiny or tonumber(candidate.stars) == 3) then return nil end
	for _, id in ipairs(ns.CAPTURE_PREP_ADVICE_ORDER) do
		if self:CaptureAidCount(id) > 0 then return id end
	end
	return nil
end

-- La carte est-elle ouverte en préparation ? Rend son candidat.
function ns:CapturePrepShown()
	local frame = self.captureStage
	if frame and frame.prep and frame:IsShown() then return frame.prep end
	return nil
end

local function AidTip(button)
	local tooltip = Tooltip()
	if not tooltip then return end
	local id = button.aid
	local count = ns:CaptureAidCount(id)
	tooltip:SetOwner(button, "ANCHOR_TOP")
	Theme.TooltipLine(tooltip, ns:CaptureAidLabel(id), Theme.PARCHMENT)
	Theme.TooltipLine(tooltip, L["CAPTURE_AID_DESC_" .. id], Theme.TEXT)
	Theme.TooltipLine(tooltip, count > 0 and ns:F("CAPTURE_AID_HINT", count) or L.CAPTURE_AID_NONE, Theme.MUTED_LIGHT)
	if count > 0 then Theme.TooltipLine(tooltip, L.CAPTURE_PREP_AID_TOGGLE, Theme.MUTED_LIGHT) end
	tooltip:Show()
end

local function ButtonTip(button)
	local tooltip = Tooltip()
	if not (tooltip and button.tip) then return end
	tooltip:SetOwner(button, "ANCHOR_TOP")
	Theme.TooltipLine(tooltip, button.tip, Theme.PARCHMENT)
	if button.tip2 then Theme.TooltipLine(tooltip, button.tip2, Theme.MUTED_LIGHT) end
	tooltip:Show()
end

-- Ce qui n'existe qu'en préparation : la qualité, les aides cliquables (et
-- la lueur de l'aide conseillée), la légende, Lancer et Passer. Créé une
-- fois par carte, à la première préparation.
local function BuildPrep(self, frame)
	if frame.prepBuilt then return frame end
	frame.prepBuilt = true
	local az = frame.azeroth and true or false
	local details = frame.details
	frame.quality = Theme.Text(details, Theme.F_BODY or Theme.F_SMALL, Theme.LABEL)
	frame.quality:SetPoint("TOP", details, "TOP", 0, PREP.qualityY)
	frame.quality:SetJustifyH("CENTER")
	if frame.quality.SetWordWrap then frame.quality:SetWordWrap(false) end
	if az and ns.AzerothFont then ns.AzerothFont(frame.quality, 12) end
	frame.quality:Hide()
	frame.legend = Theme.Text(details, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.legend:SetPoint("TOP", details, "TOP", 0, PREP.legendY)
	frame.legend:SetWidth((az and AZS.w or SBS.w) - 32)
	frame.legend:SetJustifyH("CENTER")
	if frame.legend.SetWordWrap then frame.legend:SetWordWrap(false) end
	frame.legend:Hide()
	local lay = az and AZS or SBS
	for _, cell in ipairs(frame.aidCells or {}) do
		cell.glow = Theme.Solid(details, "BACKGROUND", Theme.GOLD_LIGHT, 0.55)
		cell.glow:SetSize(lay.aid + 8, lay.aid + 8)
		cell.glow:SetPoint("CENTER", cell.edge, "CENTER", 0, 0)
		cell.glow:Hide()
		local button = CreateFrame("Button", nil, details)
		button:SetSize(lay.aid + 4, lay.aid + 4)
		button:SetPoint("CENTER", cell.edge, "CENTER", 0, 0)
		button:SetFrameLevel((details:GetFrameLevel() or 1) + 2)
		button.aid = cell.id
		button:SetScript("OnClick", function(b) ns:CapturePrepToggleAid(b.aid) end)
		button:SetScript("OnEnter", AidTip)
		button:SetScript("OnLeave", HideTip)
		button:Hide()
		cell.button = button
	end
	local w, h = PREP.buttonW, PREP.buttonH
	local function Launch() ns:CapturePrepLaunch() end
	local function Pass(_, mouse) ns:CapturePrepPass(mouse == "RightButton") end
	if az and self.AzerothButton then
		frame.launch = self:AzerothButton(frame, w, h, L.CAPTURE_PREP_LAUNCH, Launch, "gold")
		frame.pass = self:AzerothButton(frame, w, h, L.CAPTURE_PREP_PASS, Pass, "dark")
	else
		frame.launch = Theme.CreateButton(frame, w, h, L.CAPTURE_PREP_LAUNCH, Launch, "primary")
		frame.pass = Theme.CreateButton(frame, w, h, L.CAPTURE_PREP_PASS, Pass, "normal")
	end
	frame.launch:SetPoint("TOPRIGHT", details, "TOP", -PREP.gap / 2, PREP.buttonsY)
	frame.pass:SetPoint("TOPLEFT", details, "TOP", PREP.gap / 2, PREP.buttonsY)
	if frame.pass.RegisterForClicks then frame.pass:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
	frame.launch.tip, frame.pass.tip, frame.pass.tip2 = L.CAPTURE_PREP_LAUNCH_TIP, L.CAPTURE_PREP_PASS_TIP, L.CAPTURE_PREP_PASS_RIGHT
	for _, button in ipairs({ frame.launch, frame.pass }) do
		button:SetFrameLevel((frame:GetFrameLevel() or 1) + 14)
		button:HookScript("OnEnter", ButtonTip)
		button:HookScript("OnLeave", HideTip)
		button:Hide()
	end
	return frame
end

-- Hauteur de la carte (et parchemin recadré à sa mesure, en Azeroth)
local function CardHeight(frame, height)
	frame:SetHeight(height)
	if frame.cardParch and ns.AzerothCover and ns.AZEROTH_CARD then
		pcall(ns.AzerothCover, frame.cardParch, ns.AZEROTH_CARD.parch, frame.azeroth and AZS.w or STAGE_W, height)
	end
end

-- La carte quitte la préparation (lancer, Échap, Passer sans suivant) :
-- ses éléments cachés, sa taille rendue, la prise « prep » lâchée
function ns.CapturePrepClear(frame)
	if not frame then return end
	local was = frame.prep ~= nil
	frame.prep, frame.prepOn = nil, nil
	if frame.prepBuilt then
		frame.quality:Hide()
		frame.legend:Hide()
		frame.launch:Hide()
		frame.pass:Hide()
		for _, cell in ipairs(frame.aidCells or {}) do
			cell.glow:Hide()
			cell.button:Hide()
		end
	end
	local az = frame.azeroth and true or false
	CardHeight(frame, az and AZS.h or STAGE_H)
	if az then RoleInk(frame.footer, "stage.status") end
	if az then RoleInk(frame.info, "stage.chance") end
	if was and ns.CaptureQueueRelease then ns:CaptureQueueRelease("prep") end
end

-- Textes, aides et boutons à jour (choix d'une aide, file qui bouge)
function ns:CapturePrepRefresh()
	local frame = self.captureStage
	local candidate = frame and frame.prep
	if not (candidate and frame:IsShown()) then return nil end
	local az = frame.azeroth and true or false
	local sobre = ns.CAPTURE_PREP_SOBRE
	local state = self:CaptureState()
	if state.aid and self:CaptureAidCount(state.aid) <= 0 then state.aid = nil end
	local aid = state.aid
	local stars = math.max(1, math.min(3, math.floor(tonumber(candidate.stars) or 1)))
	frame.quality:SetText(self:CaptureQualityText(stars, candidate.shiny))
	if candidate.shiny then Ink(frame.quality, az, "stage.prepQualityShiny", sobre.qualityShiny)
	elseif stars == 3 then Ink(frame.quality, az, "stage.prepQuality", sobre.quality)
	else Ink(frame.quality, az, "stage.prepQualityPlain", sobre.qualityPlain) end
	frame.quality:Show()
	-- la chance, et l'écart avec l'aide choisie
	local chance, sure = self:CapturePrepChance(candidate, nil)
	local text = sure and L.CAPTURE_STAGE_SURE or self:F("CAPTURE_STAGE_CHANCE", Pct(chance))
	if aid then
		local withAid, aidSure = self:CapturePrepChance(candidate, aid)
		local with = L["CAPTURE_PREP_WITH_" .. aid]
		local delta = aidSure and self:F("CAPTURE_PREP_DELTA_SURE", with) or self:F("CAPTURE_PREP_DELTA", Pct(withAid), with)
		local deltaInk = az and ns.AZEROTH_INK and ns.AZEROTH_INK[ns.CAPTURE_PREP_CONTRAST["stage.prepDelta"][1]] or sobre.delta
		text = text .. "  " .. Theme.Hex(deltaInk) .. delta .. "|r"
	end
	frame.info:SetText(text)
	Ink(frame.info, az, "stage.prepChance", sobre.chance)
	-- les aides : choisie en couleurs (liseré d'or), conseillée en lueur, à 0 grisée
	local advice = self:CapturePrepAdvice(candidate)
	for _, cell in ipairs(frame.aidCells or {}) do
		local count = self:CaptureAidCount(cell.id)
		local chosen = cell.id == aid
		cell.count:SetText(count > 0 and tostring(count) or "")
		if cell.icon.SetDesaturated then cell.icon:SetDesaturated(not chosen) end
		cell.icon:SetAlpha(chosen and 1 or (count > 0 and 0.7 or 0.3))
		local edge = chosen and Theme.GOLD or (advice == cell.id and Theme.GOLD_LIGHT or Theme.EDGE)
		cell.edge:SetVertexColor(edge[1], edge[2], edge[3], 1)
		cell.chosen, cell.advised = chosen, advice == cell.id
		if advice == cell.id and not chosen then cell.glow:Show() else cell.glow:Hide() end
		SetOn(cell.button, count > 0 or chosen)
		cell.button:Show()
	end
	-- la légende : Réserve pleine, l'aide conseillée, ou ce que fait chaque aide
	local blocked = self.CaptureBlockedReason and self:CaptureBlockedReason(candidate)
	if blocked == "reserveFull" then
		frame.legend:SetText(self:F("CAPTURE_PREP_BLOCKED", self:SpecimenReserveCount(), self:ReserveCapacity()))
		Ink(frame.legend, az, "stage.prepBlocked", sobre.blocked)
	elseif advice then
		frame.legend:SetText(self:F("CAPTURE_PREP_ADVICE", L["CAPTURE_PREP_ADVICE_" .. advice]))
		Ink(frame.legend, az, "stage.prepQuality", sobre.quality)
	else
		frame.legend:SetText(L.CAPTURE_PREP_SHORT_appat .. " · " .. L.CAPTURE_PREP_SHORT_lasso .. " · " .. L.CAPTURE_PREP_SHORT_sifflet)
		Ink(frame.legend, az, "stage.prepLegend", sobre.legend)
	end
	frame.legend:Show()
	frame.prepBlocked = blocked
	SetOn(frame.launch, not blocked)
	frame.launch:SetAlpha(blocked and 0.5 or 1)
	frame.launch:Show()
	frame.pass:Show()
	-- le pied : Échap, et le temps qui lui restera (en pause tant qu'on prépare)
	local left = candidate.expires and self.CaptureQueueClock
		and math.max(0, math.ceil(candidate.expires - self:CaptureQueueClock()))
	frame.footer:SetText(left and self:F("CAPTURE_PREP_HINT", left) or L.CAPTURE_PREP_HINT_LATER)
	Ink(frame.footer, az, "stage.prepHint", sobre.hint)
	return text
end

-- Ouvre la carte en préparation sur `candidate` (table de la file ou guid ;
-- nil : le meilleur). Rend la carte, ou nil (rien à préparer, combat, filet
-- déjà en l'air).
function ns:CapturePrepOpen(candidate)
	if InCombat() then
		if self.CaptureRefuseCombat then self:CaptureRefuseCombat() end
		return nil
	end
	local state = self:CaptureState()
	-- le verdict du lancer précédent est encore à l'écran : on le referme
	if state.rolling and state.rolling.result then
		state.rolling.closeAt = Clock()
		self:CaptureTick(Clock())
	end
	if state.rolling then return nil end
	local queue = self:CaptureQueuePrune()
	local picked
	if candidate ~= nil then
		for _, c in ipairs(queue) do
			if c == candidate or c.guid == candidate then picked = c end
		end
	end
	picked = picked or queue[1]
	if not picked then return nil end
	if ns.CapturePrepContrastMerge then ns.CapturePrepContrastMerge() end
	local frame = self:EnsureCaptureStage()
	if not frame then return nil end
	self:CaptureHideQueueList()
	if self.CaptureChooserHide then self:CaptureChooserHide() end
	if self.CaptureToastHide then self:CaptureToastHide() end
	BuildPrep(self, frame)
	local fresh = not frame:IsShown()
	frame.rolling = nil
	frame.prep, frame.prepOn = picked, true
	local az = frame.azeroth and true or false
	CardHeight(frame, (az and AZS.h or STAGE_H) + (az and PREP.extra.azeroth or PREP.extra.sobre))
	StageHeader(self, frame, picked, true)
	frame.details:Show()
	frame:Show()
	if fresh and Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	-- dès l'ouverture, le temps de la file s'arrête (Échap : il reprend)
	if self.CaptureQueueHold then self:CaptureQueueHold("prep") end
	self:CapturePrepRefresh()
	return frame
end

-- Une aide choisie (ou reposée) depuis la carte : la chance suit
function ns:CapturePrepToggleAid(id)
	if not self:CapturePrepShown() then return nil end
	local aid = self:CaptureToggleAid(id)
	self:CapturePrepRefresh()
	return aid
end

-- Lancer : la scène d'avant, sur ce candidat, avec l'aide choisie. Rend true
-- si le filet est parti.
function ns:CapturePrepLaunch()
	local frame = self.captureStage
	local candidate = self:CapturePrepShown()
	if not candidate then return false end
	if self.CaptureRefuseBlocked and self:CaptureRefuseBlocked(candidate) then
		self:CapturePrepRefresh()
		return false
	end
	frame.prepBusy = true
	local ok, thrown = pcall(self.CaptureThrow, self, candidate)
	frame.prepBusy = nil
	if not ok then
		if self.RecordError then self:RecordError("capture:prep", thrown) end
		thrown = false
	end
	if not thrown then
		self:CapturePrepCheck()
		return false
	end
	-- sans la scène animée (réglage) : la petite fenêtre prend le relais
	if frame.prep then
		ns.CapturePrepClear(frame)
		frame:Hide()
	end
	return true
end

-- Passer : le candidat sort du filet (clic droit : l'espèce n'est plus
-- proposée) ; la carte passe au suivant, ou se ferme. Rend le suivant.
function ns:CapturePrepPass(skipSpecies)
	local frame = self.captureStage
	local candidate = self:CapturePrepShown()
	if not candidate then return nil end
	frame.prepBusy = true
	if skipSpecies and self.CaptureSkipSpecies then self:CaptureSkipSpecies(candidate.npcID, candidate.name) end
	self:CaptureQueueRemove(candidate)
	frame.prepBusy = nil
	local nextOne = self:CaptureQueuePrune()[1]
	if nextOne then
		self:CapturePrepOpen(nextOne)
		return nextOne
	end
	self:CapturePrepClose()
	return nil
end

-- Fermer sans rien retirer (comme Échap)
function ns:CapturePrepClose()
	local frame = self.captureStage
	if not (frame and frame.prep) then return false end
	ns.CapturePrepClear(frame)
	frame:Hide()
	return true
end

-- La file a bougé (CaptureQueue.lua, CaptureQueueRefresh) : le candidat parti
-- (capturé ailleurs, plus d'intérêt), la carte passe au suivant ou se ferme ;
-- un filet en l'air (Maj+clic, raccourci) : elle se ferme ; sinon, à jour.
function ns:CapturePrepCheck()
	local frame = self.captureStage
	local candidate = frame and frame.prep
	if not candidate or frame.prepBusy then return nil end
	if not frame:IsShown() then ns.CapturePrepClear(frame); return nil end
	local state = self.captureState
	if state and state.rolling then
		if frame.rolling == nil then ns.CapturePrepClear(frame); frame:Hide() end
		return nil
	end
	local queue = self:CaptureQueueState()
	for _, c in ipairs(queue) do
		if c == candidate then return self:CapturePrepRefresh() end
	end
	if queue[1] then
		self:CapturePrepOpen(queue[1])
		return "next"
	end
	self:CapturePrepClose()
	return nil
end

if ns.Mark then ns.Mark("CaptureStage") end
