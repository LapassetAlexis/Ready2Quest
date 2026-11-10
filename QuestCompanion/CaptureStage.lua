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
ns.CAPTURE_STAGE_AZEROTH = AZS
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
	local entry = ns.AZEROTH_CONTRAST and ns.AZEROTH_CONTRAST[role]
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
	frame.flash = Art(frame.fxTop, "ARTWORK", 5, "halo", nil, 320, 320, "ADD")
	frame.flash:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)

	if az then
		-- le verdict : le bandeau des hauts faits (il éclot depuis sa zone
		-- fixe, posée sur la chance et les aides), « CAPTURÉ ! » ou
		-- « ÉCHAPPÉ… », le nom ou la phrase, les étoiles du spécimen dedans,
		-- le bouclier d'or ou gris et son éclat
		frame.banner = self:AzerothVerdict(frame, AZS.verdictW, AZS.verdictH)
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
	frame.banner:SetScale(1)
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

function ns:CaptureShowStage(rolling)
	local frame = self:EnsureCaptureStage()
	if not (frame and rolling) then return nil end
	local target = rolling.target
	local rarity = self:CaptureRarity(target)
	frame.rolling = rolling
	frame.rarity = rarity
	frame.shiny = target.shiny and true or false
	-- la scène Azeroth montre le verdict : pas de bandeau « Capturé ! » en double (AzerothStyle.lua)
	rolling.sceneVerdict = frame.azeroth or nil
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
	self:CaptureStageDetails(frame, rolling)
	frame.footer:SetText(L.CAPTURE_SHAKING)
	frame.played = nil
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame) end
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
	Fade(frame.flash, 0.7 - since * 3)
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
	banner:SetScale(math.max(0.05, EaseBack(pop)))
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
	Fade(frame.flash, 1 - r / 0.4)
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

if ns.Mark then ns.Mark("CaptureStage") end
