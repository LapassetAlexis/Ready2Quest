-- JournalAzeroth.lua -- habit « Azeroth » du carnet et de la fiche de dresseur (QuestCompanion 2.8.0)
--
-- Le carnet de voyage (toutes ses pages) et la fiche de dresseur s'habillent
-- comme le cadre des hauts faits de Wrath quand le style de l'interface est
-- Azeroth (ns:AzerothScenesOn : les atlas des bandeaux et le bois sont là) :
--   * cadre en bois (atlas achievement-wood-nineslice), plaque d'en-tête qui
--     déborde au-dessus de la fenêtre (titre, case des points), parchemins
--     (colonne de gauche, pages), séparateurs de métal, volutes ;
--   * catégories de gauche (fond des catégories, surbrillance du jeu teintée
--     d'or), garde-manger en bas de la colonne ;
--   * lignes et cartes sur le fond des hauts faits, barres de progression
--     vertes à bordure du jeu (orange pour une envie basse), barres de nom
--     or/gris, cadres d'icône, boucliers, bandeaux de section, paliers de
--     zone en bandes or/grises, page du guide sur le parchemin des
--     statistiques avec filigranes ;
--   * texte brun foncé sur le parchemin, titres dorés ombrés.
-- Les textures sont celles du client, désignées par leur FileDataID
-- (interface/achievementframe/*), jamais livrées. Une texture refusée par le
-- client (SetTexture rend false, GetTexture reste vide) : l'élément garde son
-- habit Sobre (et sa couleur de texte), le reste du carnet reste Azeroth.
--
-- Comment : la mise en page ne change pas (JournalWindow.lua et les pages
-- gardent leurs mesures). Pendant la construction et chaque rafraîchissement
-- d'un carnet Azeroth, les briques du thème créées (Theme.Text, CreateTile,
-- CreateBar…) sont relevées (Capture) puis rhabillées une fois ; après chaque
-- rafraîchissement, les textes posés sur du parchemin passent des couleurs
-- claires du thème à l'encre (Recolor), puis chaque page reçoit ses détails.
-- La fenêtre grandit du bois, de la bande de la plaque et du séparateur :
-- la zone des pages garde sa taille.
-- Style changé à chaud (/qc style) : un carnet (ou une fiche) affiché est
-- remplacé tout de suite par celui du nouveau style, son état recopié ; un
-- carnet fermé l'est à sa prochaine ouverture. Chaque style garde le sien
-- (ns.uiStyleCache) : deux carnets au plus, jamais reconstruits ensuite.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	CARNET_AZ_POINTS = "%d points",
	CARNET_AZ_STAMPS = "%d tampons",
}
local EN = {
	CARNET_AZ_POINTS = "%d points",
	CARNET_AZ_STAMPS = "%d stamps",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CARNET_AZ_STRINGS = { fr = FR, en = EN } end

-- ---------------------------------------------------------------------------
-- Les textures (interface/achievementframe, FileDataID) et leurs découpes
-- ---------------------------------------------------------------------------
local function C(l, r, t, b, w, h) return { l / w, r / w, t / h, b / h } end
local T = {
	parchV    = { file = 130662, w = 256, h = 512 },                  -- colonne de gauche
	parchH    = { file = 130661, w = 512, h = 256 },                  -- pages
	parchHD   = { file = 130660, w = 512, h = 256 },                  -- lignes non obtenues, inconnues
	achBg     = { file = 235397, w = 512, h = 512 },                  -- lignes, cartes
	headA     = { file = 235402, c = C(0, 504, 9, 103, 512, 256) },   -- plaque d'en-tête (504×94)
	headB     = { file = 235402, c = C(0, 214, 114, 197, 512, 256) }, -- son bout droit (214×83)
	ptBox     = { file = 235402, c = C(217, 346, 109, 143, 512, 256) }, -- case des points (129×34)
	catBg     = { file = 130652, c = C(0, 167, 0, 29, 256, 32) },     -- catégorie
	catHl     = { file = 235400, c = C(0, 167, 0, 29, 256, 32) },     -- sa surbrillance (teintée d'or)
	titleGold = { file = 130667, c = C(0, 487, 0, 20, 512, 64) },     -- barre de nom, obtenu
	titleGrey = { file = 130667, c = C(0, 487, 22, 42, 512, 64) },    -- barre de nom, pas encore
	metalL    = { file = 130658, c = C(0, 10, 0, 454, 16, 512) },
	metalT    = { file = 130659, c = C(0, 454, 0, 10, 512, 16) },
	metalJ    = { file = 130657, c = C(0, 26, 0, 26, 32, 32) },
	curl      = { file = 130671, c = C(0, 40, 0, 40, 64, 64) },       -- volute des coins
	curlR     = { file = 130671, c = C(40, 0, 0, 40, 64, 64) },
	pbarL     = { file = 235405, c = C(1, 9, 1, 24, 256, 32) },       -- bordure de barre, 3 morceaux
	pbarM     = { file = 235405, c = C(9, 215, 1, 24, 256, 32) },
	pbarR     = { file = 235405, c = C(215, 223, 1, 24, 256, 32) },
	iconFrame = { file = 130656, c = { 0, 0.5625, 0, 0.5625 } },
	-- 2.9.0 : recadrés sur le dessin (mesuré : 130665, 128×128, bouclier de
	-- 29 à 99 en largeur, de 39 à 90 en hauteur, écu de 49 à 79 et de 46 à
	-- 82 ; 235415, 32×32, petit bouclier de 0 à 20 et de 0 à 18) : posés en
	-- entier, ils sortaient trop petits et décentrés de leur nombre
	shieldBig = { file = 130665, c = C(29, 99, 39, 90, 128, 128) },     -- 70×51
	tiny      = { file = 235415, c = C(0, 20, 0, 18, 32, 32) },         -- 20×18
	shadow    = { file = 130654, c = C(0, 92, 0, 128, 128, 128) },
	tsuL      = { file = 130668, c = C(6, 32, 0, 26, 64, 32) },       -- filigrane : coins
	tsuR      = { file = 130668, c = C(32, 58, 0, 26, 64, 32) },
	tsuV      = { file = 130670, c = C(2, 14, 0, 16, 16, 16) },       -- bouts du filigrane
	tsuH      = 130669,                                               -- filigrane, répété
	stats     = { file = 235412, w = 512, h = 512 },                  -- page du guide
	statHead  = { file = 235411, c = C(0, 256, 0, 23, 256, 128) },
	statRow   = { file = 235411, c = C(0, 256, 48, 69, 256, 128) },
	recent    = { file = 235408, c = C(11, 246, 0, 23, 256, 32) },    -- bandeau de section
	reward    = { file = 130663, c = C(5, 347, 0, 18, 512, 32) },     -- bande de récompense
	stripGrey = { file = 452109, c = C(0, 488, 190, 210, 512, 256) }, -- palier pas encore atteint
	stripGold = { file = 452109, c = C(0, 488, 211, 234, 512, 256) }, -- palier atteint
	wood      = 130672,                                               -- encadré fin, 8 morceaux de 64
}
ns.CARNET_TEX = T
-- géométrie : bande de la plaque, bois, colonne de gauche, séparateur de
-- métal ; plaque de 706×100 qui déborde de 46 px au-dessus de la fenêtre
ns.CARNET_LAYOUT = { band = 56, wood = 16, nav = 196, gap = 10, plateW = 706, plateH = 100, plateUp = 46,
	navItemH = 29, navStep = 31, navTop = -30, navPad = 12, navBadgePad = 10 }
local LAY = ns.CARNET_LAYOUT
ns.carnetMissing = ns.carnetMissing or {}

-- 2.8.2 : encres mesurées (ns.AZEROTH_INK, AzerothStyle.lua) : chacune
-- tient 4,5:1 sur le pire fond voilé (page, lignes, tuiles)
local INKS = ns.AZEROTH_INK
local INK = INKS.inkSoft                  -- texte du thème sur parchemin (#2b1a08)
local INK_SOFT = INKS.inkSoft
local INK_MUTED = INKS.inkMuted           -- #3d260f
local AMBER = INKS.amber                  -- l'ambre du thème sur parchemin (#521f00)
local GOLD_HEAD = INKS.goldHead           -- titres dorés ombrés (#f8d877)
-- 2.9.0 : le grand bouclier des points (en-tête des hauts faits) : taille,
-- décalage du nombre, taille de police selon le nombre de chiffres
local SHIELD_BIG = { w = 60, h = 44, y = 2, font = { 14, 14, 12, 10 } }
ns.CARNET_SHIELD_BIG = SHIELD_BIG
local PLATE_COUNT = { x = 12, y = 1 }     -- 2.9.0 : nombre de la case des points
-- 2.9.0 : Exploration, textes centrés : marge haute des cartes de part, du
-- liseré de leur barre (le cadre de la barre déborde de 3 px), des rangées
ns.CARNET_PROGRESS_LAYOUT = { partTop = 4, barEdge = 3, rowPad = 2 }
ns.CARNET_PLATE_COUNT = PLATE_COUNT
-- 2.11.2 (fiche 28) : encres lues dans ns.AZEROTH_INK (mêmes valeurs)
local GOLD_TEXT = INKS.goldText           -- texte des boutons, de la plaque
local LIGHT = INKS.light                  -- texte clair sur fond sombre
local LIGHT_SOFT = INKS.lightSoft
local WOOD_BG = INKS.woodNight
local CAT_GOLD = INKS.catGold             -- teinte de la surbrillance des catégories
local BAR_GREEN, BAR_ORANGE, BAR_GOLD = INKS.barGreen, INKS.barOrange, INKS.barGold
local EDGE_DARK = INKS.edgeDark
ns.CARNET_COLORS = { ink = INK, inkSoft = INK_SOFT, amber = AMBER, gold = GOLD_HEAD, light = LIGHT,
	catGold = CAT_GOLD, green = BAR_GREEN, orange = BAR_ORANGE, barGold = BAR_GOLD }
local STATUS_BAR = "Interface\\TargetingFrame\\UI-StatusBar"
local CLOSE_TEX = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up"
local SIDES = { "top", "bottom", "left", "right" }

local function Method(obj, name, ...)
	local fn = obj and obj[name]
	if type(fn) ~= "function" then return false end
	return pcall(fn, obj, ...)
end
local SetTex = ns.AzerothFileTexture
local function AzFont(fs, size, flags) if ns.AzerothFont then return ns.AzerothFont(fs, size, flags) end end
local function Shadow(fs) Theme.TextShadow(fs) end
local function NoShadow(fs) if Theme.NoShadow then Theme.NoShadow(fs) end end
local function Paint(fs, c, a) fs:SetTextColor(c[1], c[2], c[3], a or 1) end
-- 2.9.0 : l'encre d'un rôle mesuré (ns.AZEROTH_CONTRAST), le code et la table d'accord
local function RoleInk(role)
	local entry = ns.AZEROTH_CONTRAST and ns.AZEROTH_CONTRAST[role]
	return entry and ns.AZEROTH_INK[entry[1]] or nil
end
-- 2.9.1 : une encre de rôle, sans ombre (texte sombre) ou avec (texte clair) ;
-- 2.11.0 (fiche 08) : le texte garde son rôle (fs.azRole) et n'est jamais estompé
local function RolePaint(fs, role, shadow)
	if not fs then return end
	local ink = RoleInk(role)
	if not ink then
		ns.carnetInkMisses = ns.carnetInkMisses or {}
		ns.carnetInkMisses[#ns.carnetInkMisses + 1] = "role:" .. tostring(role)
		return
	end
	fs:SetTextColor(ink[1], ink[2], ink[3], 1)
	if shadow then
		Theme.TextShadow(fs)
	elseif Theme.NoShadow then
		Theme.NoShadow(fs)
	end
	if fs.SetAlpha then fs:SetAlpha(1) end
	fs.azRole, fs.azKeep = role, true
end
ns.CarnetRolePaint = RolePaint
-- 2.11.0 : une ombre unie sous un texte clair posé sur un fond variable
local function ShadeUnder(host, fs, alpha, pad)
	local shade = host.azShade
	if not shade then
		shade = host:CreateTexture(nil, "ARTWORK", nil, 6)
		shade:SetTexture(Theme.SOLID)
		host.azShade = shade
	end
	local c = INKS.shade
	shade:SetVertexColor(c[1], c[2], c[3], alpha)
	shade:ClearAllPoints()
	shade:SetPoint("TOPLEFT", fs, "TOPLEFT", -(pad or 2), pad or 1)
	shade:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", pad or 2, -(pad or 1))
	shade:Show()
	return shade
end
-- 2.9.0 : un texte posé sur toute la hauteur de sa zone (haut ET bas),
-- centré verticalement : side "LEFT" ou "RIGHT", x depuis ce bord, de topY
-- (depuis le haut de `top`) à bottomY (depuis le point `bottomPoint` de `bottom`)
local function SpanV(fs, side, top, x, topY, bottom, bottomPoint, bottomY)
	if not fs then return end
	fs:ClearAllPoints()
	fs:SetPoint("TOP" .. side, top, "TOP" .. side, x, topY)
	fs:SetPoint("BOTTOM" .. side, bottom, bottomPoint, x, bottomY)
	if fs.SetJustifyV then fs:SetJustifyV("MIDDLE") end
end
local function HideAll(list) for _, side in ipairs(SIDES) do if list and list[side] then list[side]:Hide() end end end
local function Has(list, pred) for _, v in ipairs(list or {}) do if pred(v) then return true end end return false end
local function Level(frame) return (frame and frame.GetFrameLevel and frame:GetFrameLevel()) or 1 end

-- Une texture du client sur `parent`, ou nil (refusée : rien de visible)
local function NewTex(parent, layer, sub, spec)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
	if SetTex(tex, spec) then
		tex:Show()
		return tex
	end
	if spec and spec.file then ns.carnetMissing[spec.file] = true end
	tex:Hide()
	return nil
end

-- Recadre `tex` (spec.w × spec.h) pour couvrir w × h sans déformer
local function Cover(tex, spec, w, h)
	w, h = tonumber(w) or 0, tonumber(h) or 0
	if not (tex and spec and spec.w and w > 0 and h > 0) then return end
	local ratio, base = w / h, spec.w / spec.h
	if ratio > base then
		local f = base / ratio
		tex:SetTexCoord(0, 1, 0.5 - f / 2, 0.5 + f / 2)
	else
		local f = ratio / base
		tex:SetTexCoord(0.5 - f / 2, 0.5 + f / 2, 0, 1)
	end
end

local function Desaturate(tex, on)
	if tex.SetDesaturated then pcall(tex.SetDesaturated, tex, on and true or false) end
	tex.azGrey = on and true or nil
end

-- Le cadre d'icône des hauts faits autour d'une icône (size : côté du cadre)
local function Ring(host, icon, size)
	local ring = NewTex(host, "ARTWORK", 3, T.iconFrame)
	if not ring then return nil end
	ring:SetSize(size, size)
	ring:SetPoint("CENTER", icon, "CENTER", 0, 0)
	return ring
end

-- Le filigrane « tsunami » : deux bouts et la frise répétée (x, y depuis le
-- haut gauche de `parent`). corners : les coins à volute au lieu des bouts.
local function Filigree(parent, x, y, width, corners)
	local capW = corners and 26 or 12
	local l = NewTex(parent, "ARTWORK", 1, corners and T.tsuL or T.tsuV)
	local r = NewTex(parent, "ARTWORK", 1, corners and T.tsuR or T.tsuV)
	local mid = parent:CreateTexture(nil, "ARTWORK", nil, 0)
	local midW = math.max(1, width - 2 * capW + 4)
	local ok = SetTex(mid, { file = T.tsuH, wrap = true, c = { 0, midW / 512, 2 / 16, 14 / 16 } })
	if not (l and r and ok) then
		for _, tex in ipairs({ l, r, mid }) do if tex then tex:Hide() end end
		ns.carnetMissing[T.tsuH] = not ok or nil
		return nil
	end
	local capH = corners and 26 or 14
	l:SetSize(capW, capH); l:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	r:SetSize(capW, capH); r:SetPoint("TOPLEFT", parent, "TOPLEFT", x + width - capW, y)
	if not corners then r:SetTexCoord(T.tsuV.c[2], T.tsuV.c[1], T.tsuV.c[3], T.tsuV.c[4]) end
	mid:SetHeight(12)
	mid:SetPoint("LEFT", l, "RIGHT", -2, 0)
	mid:SetPoint("RIGHT", r, "LEFT", 2, 0)
	mid:SetAlpha(0.9)
	mid:Show()
	return { l = l, m = mid, r = r }
end

-- L'encadré fin en bois des hauts faits (ui-achievement-woodborder) : 8
-- morceaux de 32 px qui débordent de `out` px ; les bords haut et bas sont
-- les morceaux verticaux tournés d'un quart de tour
local WOOD_SEG = { l = 0, r = 1, t = 2, b = 3, tl = 4, tr = 5, bl = 6, br = 7 }
local function WoodBorder(target, out)
	if target.azWoodBorder then return target.azWoodBorder end
	local host = CreateFrame("Frame", nil, target)
	host:SetAllPoints(target)
	host:SetFrameLevel(Level(target) + 4)
	host:EnableMouse(false)
	local S, O = 32, out or 6
	local p = {}
	for key, i in pairs(WOOD_SEG) do
		local u0, u1 = i * 64 / 512, (i * 64 + 64) / 512
		local c = (key == "t" or key == "b") and { u0, 1, u1, 1, u0, 0, u1, 0 } or { u0, u1, 0, 1 }
		p[key] = NewTex(host, "OVERLAY", 0, { file = T.wood, c = c })
		if not p[key] then host:Hide(); return nil end
	end
	for _, key in ipairs({ "tl", "tr", "bl", "br" }) do p[key]:SetSize(S, S) end
	p.tl:SetPoint("TOPLEFT", target, "TOPLEFT", -O, O)
	p.tr:SetPoint("TOPRIGHT", target, "TOPRIGHT", O, O)
	p.bl:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -O, -O)
	p.br:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", O, -O)
	p.t:SetPoint("TOPLEFT", p.tl, "TOPRIGHT", 0, 0); p.t:SetPoint("TOPRIGHT", p.tr, "TOPLEFT", 0, 0); p.t:SetHeight(S)
	p.b:SetPoint("BOTTOMLEFT", p.bl, "BOTTOMRIGHT", 0, 0); p.b:SetPoint("BOTTOMRIGHT", p.br, "BOTTOMLEFT", 0, 0); p.b:SetHeight(S)
	p.l:SetPoint("TOPLEFT", p.tl, "BOTTOMLEFT", 0, 0); p.l:SetPoint("BOTTOMLEFT", p.bl, "TOPLEFT", 0, 0); p.l:SetWidth(S)
	p.r:SetPoint("TOPRIGHT", p.tr, "BOTTOMRIGHT", 0, 0); p.r:SetPoint("BOTTOMRIGHT", p.br, "TOPRIGHT", 0, 0); p.r:SetWidth(S)
	host.pieces = p
	host:Show()
	target.azWoodBorder = host
	return host
end

-- ---------------------------------------------------------------------------
-- Les fonds des tuiles et des lignes
-- ---------------------------------------------------------------------------
local STYLE_SPEC = { light = T.achBg, parchd = T.parchHD, dark = T.catBg, gold = T.stripGold, grey = T.stripGrey,
	statrow = T.statRow, stathead = T.statHead, talk = ns.AZEROTH_TALK_FILE, portrait = ns.AZEROTH_PORTRAIT_BG }
-- 2.8.2 : le parchemin désaturé (parchd) est sombre (luminance 0,09) :
-- texte clair dessus ; les fonds clairs (light, talk) ont leur voile crème
local DARK_STYLES = { dark = true, gold = true, grey = true, statrow = true, stathead = true, portrait = true, parchd = true }
local VEILED = { light = "light", talk = "bubble" }
ns.carnetCtxSerial = ns.carnetCtxSerial or 0

-- Habille une tuile (ou une ligne, une carte) : light (fond des hauts faits),
-- parchd (parchemin désaturé), dark (fond des catégories), gold / grey
-- (bandes des paliers), statrow / stathead, talk (parchemin des Talking
-- Heads), band (voile brun). Refusée : le fond Sobre revient (et le texte
-- garde ses couleurs claires, la tuile devenant « sombre »).
local function TileStyle(tile, style)
	if not tile then return false end
	if tile.azStyle == style then return true end
	local bg = tile.azBg
	if not bg then
		bg = tile:CreateTexture(nil, "BACKGROUND", nil, 1)
		bg:SetAllPoints(tile)
		tile.azBg = bg
	end
	local ok
	if style == "band" then
		bg:SetTexture(Theme.SOLID)
		bg:SetTexCoord(0, 1, 0, 1)
		bg:SetVertexColor(INKS.catVeil[1], INKS.catVeil[2], INKS.catVeil[3], 0.14)
		ok = true
	else
		local spec = STYLE_SPEC[style]
		ok = SetTex(bg, spec)
		if ok then
			bg:SetVertexColor(1, 1, 1, 1)
			if spec.w then Cover(bg, spec, tile:GetWidth(), tile:GetHeight()) end
		elseif spec and spec.file then
			ns.carnetMissing[spec.file] = true
		end
	end
	local before = tile.azSurface
	local veilKey = ok and VEILED[style]
	if veilKey then
		if not tile.azVeil then tile.azVeil = ns.AzerothVeil(tile, tile, veilKey, 2) end
		local a = INKS.alpha[veilKey]
		tile.azVeil:SetVertexColor(INKS.veil[1], INKS.veil[2], INKS.veil[3], a)
		tile.azVeil.azVeilKey = veilKey
		tile.azVeil:Show()
	elseif tile.azVeil then
		tile.azVeil:Hide()
	end
	if ok then
		bg:Show()
		if tile.bg then tile.bg:Hide() end
		tile.azSurface = DARK_STYLES[style] and "dark" or "light"
		tile.azStyle = style
	else
		bg:Hide()
		if tile.bg then tile.bg:Show() end
		tile.azSurface = "dark"
		tile.azStyle = nil
	end
	if before ~= tile.azSurface then ns.carnetCtxSerial = ns.carnetCtxSerial + 1 end
	return ok
end
ns.CarnetTileStyle = TileStyle

-- Une tuile sombre choisie : la surbrillance du jeu, teintée d'or
local function Selectable(tile)
	if tile.azHl or tile.azStyle ~= "dark" then return end
	local hl = NewTex(tile, "BORDER", 2, T.catHl)
	if not hl then return end
	hl:SetAllPoints(tile)
	if hl.SetBlendMode then hl:SetBlendMode("ADD") end
	hl:SetVertexColor(CAT_GOLD[1], CAT_GOLD[2], CAT_GOLD[3], 1)
	hl:Hide()
	tile.azHl = hl
	HideAll(tile.border)
	local set = tile.SetSelected
	function tile:SetSelected(on)
		set(self, on)
		if self.azHl then if on then self.azHl:Show() else self.azHl:Hide() end end
	end
	tile:SetSelected(tile.selected)
end

-- ---------------------------------------------------------------------------
-- Les briques du thème, rhabillées à leur création
-- ---------------------------------------------------------------------------
local SKIN = {}

function SKIN.Text(fs, frame, reg) reg.texts[#reg.texts + 1] = fs end

-- 2.9.0 : les intertitres (Theme.CreateSection) n'étaient pas relevés (leurs
-- textes naissent hors de Theme.Text) : gris clair du thème sur le
-- parchemin (fiche de dresseur, page Compagnon). Relevés ici, peints à
-- chaque passage (Recolor) selon leur fond ; Strip (bande sombre) garde la main.
function SKIN.CreateSection(section, frame, reg)
	reg.sections = reg.sections or {}
	reg.sections[#reg.sections + 1] = section
end
function SKIN.CreateTile(tile) TileStyle(tile, "light") end

function SKIN.CreateListRow(row)
	TileStyle(row, "light")
	if row.azStyle and not row.azEdge then row.azEdge = Theme.Border(row, EDGE_DARK, 0.8, "BORDER") end
end

-- Une barre : piste sombre, remplissage vert du jeu (UI-StatusBar), bordure
-- des hauts faits (3 morceaux) dès 8 px ; bar.azPaint(bar) choisit la couleur
local function BarPaint(bar)
	local c = (bar.azPaint and bar.azPaint(bar)) or BAR_GREEN
	bar.fill:SetVertexColor(c[1], c[2], c[3], 1)
	bar.azColor = c
end
function SKIN.CreateBar(bar)
	local h = tonumber(bar:GetHeight()) or 4
	local newH = h >= 6 and 14 or (h >= 4 and 10 or (h >= 3 and 8 or 4))
	bar:SetHeight(newH)
	bar.bg:SetVertexColor(INKS.barBg[1], INKS.barBg[2], INKS.barBg[3], 1)
	SetTex(bar.fill, { file = STATUS_BAR })
	function bar:SetColor() BarPaint(self) end
	BarPaint(bar)
	if newH >= 8 then
		local edge = CreateFrame("Frame", nil, bar)
		edge:SetPoint("TOPLEFT", bar, "TOPLEFT", -3, 3)
		edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 3, -3)
		edge:SetFrameLevel(Level(bar) + 1)
		edge:EnableMouse(false)
		local l, m, r = NewTex(edge, "OVERLAY", 0, T.pbarL), NewTex(edge, "OVERLAY", 0, T.pbarM), NewTex(edge, "OVERLAY", 0, T.pbarR)
		if l and m and r then
			l:SetWidth(8); l:SetPoint("TOPLEFT", edge, "TOPLEFT", 0, 0); l:SetPoint("BOTTOMLEFT", edge, "BOTTOMLEFT", 0, 0)
			r:SetWidth(8); r:SetPoint("TOPRIGHT", edge, "TOPRIGHT", 0, 0); r:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", 0, 0)
			m:SetPoint("TOPLEFT", l, "TOPRIGHT", 0, 0); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT", 0, 0)
			bar.azEdge = edge
		else
			edge:Hide()
		end
	end
	bar.azSurface = "dark"
end

function SKIN.CreateChips(row)
	for _, chip in ipairs(row.chips or {}) do
		local bg = NewTex(chip, "BACKGROUND", 1, T.catBg)
		if bg then
			bg:SetAllPoints(chip)
			chip.azBg = bg
			if chip.bg then chip.bg:Hide() end
			HideAll(chip.border)
			local hl = NewTex(chip, "BORDER", 1, T.catHl)
			if hl then
				hl:SetAllPoints(chip)
				if hl.SetBlendMode then hl:SetBlendMode("ADD") end
				hl:SetVertexColor(CAT_GOLD[1], CAT_GOLD[2], CAT_GOLD[3], 1)
				hl:Hide()
				chip.azHl = hl
			end
			chip.azSurface = "dark"
		end
	end
	local function Lit(self)
		for _, chip in ipairs(self.chips or {}) do
			if chip.azHl then if chip.selected then chip.azHl:Show() else chip.azHl:Hide() end end
		end
	end
	local select = row.Select
	function row:Select(id, silent)
		local result = select(self, id, silent)
		Lit(self)
		return result
	end
	Lit(row)
end

-- Boutons : rouge des fenêtres du jeu (principal), brun (secondaire),
-- liseré d'or dedans, texte doré ombré (dessinés : pas de texture de bouton)
local AZB = ns.AZEROTH_BUTTONS            -- 2.11.2 : palette unique (AzerothStyle.lua)
local BUTTONS = { red = AZB.red, brown = AZB.brown }
ns.CARNET_BUTTONS = BUTTONS
function SKIN.CreateButton(button)
	local skin = (button.style == "primary" or button.style == "accent") and BUTTONS.red or BUTTONS.brown
	local fill = button:CreateTexture(nil, "BACKGROUND", nil, 1)
	fill:SetTexture(Theme.SOLID)
	fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	if Theme.Gradient then Theme.Gradient(fill, "VERTICAL", skin.bottom, 1, skin.top, 1) end
	fill:Show()
	button.azFill = fill
	button.azOuter = Theme.Border(button, AZB.outer, 1, "BORDER")
	button.azInner = Theme.Border(button, skin.edge, 0.85, "BORDER", fill)
	if button.bg then button.bg:Hide() end
	HideAll(button.border)
	if button.text then
		Paint(button.text, GOLD_TEXT)
		Shadow(button.text)
	end
	button.azSkin = skin == BUTTONS.red and "red" or "brown"
	button.azSurface = "dark"
end

local function Field(box)
	if box.bg then box.bg:SetVertexColor(INKS.fieldBg[1], INKS.fieldBg[2], INKS.fieldBg[3], 1) end
	-- 2.11.0 : le texte du champ, rôle mesuré sur l'aplat
	for _, key in ipairs({ "text", "label", "value" }) do
		local fs = box[key]
		if type(fs) == "table" and fs.SetTextColor then RolePaint(fs, "field.text") end
	end
	if box.SetTextColor and box.GetObjectType and box:GetObjectType() == "EditBox" then
		local c = RoleInk("field.text")
		box:SetTextColor(c[1], c[2], c[3], 1)
	end
	if box.border and box.border.SetColor then box.border:SetColor(AZB.brown.edge[1], AZB.brown.edge[2], AZB.brown.edge[3], 1) end
	if box.chevron then box.chevron:SetVertexColor(GOLD_TEXT[1], GOLD_TEXT[2], GOLD_TEXT[3], 1) end
	box.azSurface = "dark"
end
SKIN.CreateDropdown, SKIN.CreateSearchBox = Field, Field

-- 2.8.2 : la bande de récompense est translucide par endroits : sur une
-- ligne voilée, le clair passait au travers (bleu à 2,1:1). Un fond brun
-- opaque dessous, la bande assombrie : bleu 5,0:1, gris 6,9:1.
function SKIN.CreateTag(tag)
	local bg = NewTex(tag, "BACKGROUND", 1, T.reward)
	if not bg then return end
	bg:SetAllPoints(tag)
	bg:SetVertexColor(INKS.dim[1], INKS.dim[2], INKS.dim[3], 1)
	if tag.bg then
		local c = INKS.tagShade
		tag.bg:SetTexture(Theme.SOLID)
		tag.bg:SetVertexColor(c[1], c[2], c[3], c[4])
		tag.bg:SetDrawLayer("BACKGROUND", 0)
		tag.bg:Show()
		local set = tag.SetTag
		function tag:SetTag(...)
			local result = set(self, ...)
			self.bg:SetVertexColor(c[1], c[2], c[3], c[4])
			return result
		end
	end
	tag.azBg = bg
	tag.azSurface = "dark"
end

-- Entrée de la colonne : fond des catégories ; le survol et le choix du
-- thème deviennent la surbrillance du jeu teintée d'or (le thème les
-- montre et les cache toujours), la barre d'accent disparaît
function SKIN.CreateNavItem(item)
	local bg = NewTex(item, "BACKGROUND", -2, T.catBg)
	if not bg then return end
	local inset = 8
	bg:SetPoint("TOPLEFT", item, "TOPLEFT", inset, -1)
	bg:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -inset, 1)
	item.azBg = bg
	for _, key in ipairs({ "hover", "tint" }) do
		local tex = item[key]
		if tex and SetTex(tex, T.catHl) then
			tex:ClearAllPoints()
			tex:SetPoint("TOPLEFT", item, "TOPLEFT", inset, -1)
			tex:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -inset, 1)
			if tex.SetBlendMode then tex:SetBlendMode("ADD") end
			local a = key == "hover" and 0.5 or 1
			if Theme.Gradient then Theme.Gradient(tex, "HORIZONTAL", CAT_GOLD, a, CAT_GOLD, a)
			else tex:SetVertexColor(CAT_GOLD[1], CAT_GOLD[2], CAT_GOLD[3], a) end
		end
	end
	if item.bar then item.bar:SetAlpha(0) end
	-- 2.8.2 : le texte collait au bord gauche du fond : posé depuis le fond
	-- lui-même, 12 px dedans ; le compteur 10 px avant son bord droit
	if item.label then
		item.label:ClearAllPoints()
		item.label:SetPoint("LEFT", bg, "LEFT", LAY.navPad, 0)
		item.label:SetPoint("RIGHT", bg, "RIGHT", -LAY.navPad - 22, 0)
		item.label:SetJustifyH("LEFT")
		if item.label.SetWordWrap then item.label:SetWordWrap(false) end
	end
	if item.badge then
		local place = item.SetBadge
		local function Badge(self)
			self.badge:ClearAllPoints()
			self.badge:SetPoint("RIGHT", self.azBg, "RIGHT", -LAY.navBadgePad, 0)
		end
		function item:SetBadge(...)
			local result = place(self, ...)
			Badge(self)
			return result
		end
		local state = item.SetModuleState
		function item:SetModuleState(...)
			local result = state(self, ...)
			if not (self.power and self.power:IsShown()) then Badge(self) end
			return result
		end
		Badge(item)
	end
	item.azSurface = "dark"
end

-- En-tête de page : titre doré ombré (police des hauts faits), sous-titre
-- brun, filigrane à la place du filet ambre
function SKIN.CreatePageHeader(header, frame)
	local content = frame and frame.content
	if not (content and content.azSurface == "light") then return end
	for _, key in ipairs({ "topGlow", "cornerGlow", "logo" }) do if header[key] then header[key]:Hide() end end
	if header.rule then
		for _, seg in ipairs(header.rule.segments or {}) do seg:Hide() end
		for _, glow in ipairs(header.rule.glow or {}) do glow:Hide() end
	end
	AzFont(header.title, header.compact and 19 or 22)
	-- 2.8.2 : l'or ombré tombait à 1,7:1 sur le parchemin : titre à l'encre
	-- brun-rouge, sans ombre (4,0:1 pour un grand titre, seuil 3)
	Paint(header.title, INKS.title)
	NoShadow(header.title)
	header.title.azKeep = true
	Paint(header.subtitle, INK_SOFT)
	NoShadow(header.subtitle)
	header.subtitle.azKeep = true
	local pad = header.compact and 20 or 24
	local width = (tonumber(header:GetWidth()) or 600) - 2 * pad
	header.azFiligree = Filigree(header, pad, header.compact and -52 or -80, width)
	header.azSurface = "light"
end

local WRAP = { "Text", "CreateTile", "CreateListRow", "CreateBar", "CreateChips", "CreateButton", "CreateDropdown",
	"CreateSearchBox", "CreateTag", "CreateNavItem", "CreatePageHeader", "CreateSection" }
ns.CARNET_WRAPPED = WRAP

-- Relève les briques créées pendant fn(...) dans reg.new (puis SkinNew)
local capturing = false
local function CaptureRun(reg, fn, ...)
	if capturing then return fn(...) end
	capturing = true
	local saved = {}
	for _, name in ipairs(WRAP) do
		local orig = Theme[name]
		if type(orig) == "function" then
			saved[name] = orig
			Theme[name] = function(...)
				local widget = orig(...)
				if type(widget) == "table" then
					reg.new[#reg.new + 1] = { widget, name }
					-- 2.11.0 (fiche 08) : un texte note le jeton qui l'a peint
					if name == "Text" then widget.themeInk = select(3, ...) end
				end
				return widget
			end
		end
	end
	local results = { pcall(fn, ...) }
	for name, orig in pairs(saved) do Theme[name] = orig end
	capturing = false
	if not results[1] then error(results[2], 0) end
	return results[2], results[3]
end
ns.CarnetCaptureRun = CaptureRun

local function NewReg() return { new = {}, texts = {} } end

local function SkinNew(frame, reg)
	local list = reg.new
	reg.new = {}
	for _, item in ipairs(list) do
		local widget, kind = item[1], item[2]
		if not widget.azSkinned then
			widget.azSkinned = true
			local fn = SKIN[kind]
			if fn then
				local ok, err = pcall(fn, widget, frame, reg)
				if not ok and ns.RecordError then ns:RecordError("carnet:skin:" .. kind, err) end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Les textes : sur parchemin, les couleurs claires du thème deviennent
-- l'encre ; sur fond sombre (catégories, boutons, bandes) elles restent
-- ---------------------------------------------------------------------------
local REMAP
local function Remaps()
	if REMAP then return REMAP end
	REMAP = {}
	local function Add(from, to) if from then REMAP[#REMAP + 1] = { from, to } end end
	-- 2.8.2 : toutes à 4,5:1 au moins sur le pire fond voilé (0,317)
	Add(Theme.PARCHMENT, INKS.ink); Add(Theme.LABEL, INKS.ink); Add(Theme.TEXT, INKS.inkSoft)
	Add(Theme.MUTED_LIGHT, INKS.inkSoft); Add(Theme.MUTED, INKS.inkMuted); Add(Theme.GREY, INKS.grey)
	Add(Theme.GOLD, INKS.amber); Add(Theme.GOLD_LIGHT, INKS.amber); Add(Theme.GOLD_SOFT, INKS.amber)
	Add(Theme.GREEN, INKS.green); Add(Theme.BLUE, INKS.blue); Add(Theme.RED, INKS.red)
	Add(Theme.ORANGE_DEEP, INKS.orange)
	return REMAP
end
local function Near(r, g, b, c) return math.abs(r - c[1]) < 0.02 and math.abs(g - c[2]) < 0.02 and math.abs(b - c[3]) < 0.02 end

-- La surface sous un texte : le premier parent qui en dit une ; aucune :
-- l'habit Sobre (sombre)
local function Dark(fs, stop)
	if fs.azCtxSerial == ns.carnetCtxSerial and fs.azCtx then return fs.azCtx == "dark" end
	local parent, depth, surface = fs.GetParent and fs:GetParent(), 0, nil
	while parent and depth < 16 and not surface do
		surface = parent.azSurface
		if parent == stop then break end
		parent = parent.GetParent and parent:GetParent()
		depth = depth + 1
	end
	fs.azCtx, fs.azCtxSerial = surface or "dark", ns.carnetCtxSerial
	return fs.azCtx == "dark"
end

-- 2.11.0 (fiche 08) : chaque jeton du thème -> son rôle mesuré sur le
-- parchemin (page.*), par identité de table
local TOKEN_ROLE
local function TokenRoles()
	if TOKEN_ROLE then return TOKEN_ROLE end
	TOKEN_ROLE = {}
	local function Add(token, role) if token then TOKEN_ROLE[token] = role end end
	Add(Theme.PARCHMENT, "page.ink"); Add(Theme.LABEL, "page.ink"); Add(Theme.TEXT, "page.inkSoft")
	Add(Theme.MUTED_LIGHT, "page.inkSoft"); Add(Theme.MUTED, "page.inkMuted"); Add(Theme.GREY, "page.grey")
	Add(Theme.GOLD, "page.amber"); Add(Theme.GOLD_LIGHT, "page.amber"); Add(Theme.GOLD_SOFT, "page.amber")
	Add(Theme.GREEN, "page.green"); Add(Theme.BLUE, "page.blue"); Add(Theme.RED, "page.red")
	Add(Theme.ORANGE_DEEP, "page.orange")
	return TOKEN_ROLE
end
ns.CarnetTokenRoles = TokenRoles

-- Le rôle d'un texte : le jeton noté à sa création s'il le porte encore,
-- sinon le jeton reconnu à sa couleur (un module l'a repeint)
local function InkRole(fs, r, g, b)
	local roles = TokenRoles()
	local token = fs.themeInk
	if token and roles[token] and Near(r, g, b, token) then return roles[token] end
	for _, pair in ipairs(Remaps()) do
		if Near(r, g, b, pair[1]) then return roles[pair[1]] end
	end
	return nil
end

function ns.CarnetInk(fs)
	local r, g, b = fs:GetTextColor()
	r, g, b = tonumber(r), tonumber(g), tonumber(b)
	if not (r and g and b) then return false end
	local role = InkRole(fs, r, g, b)
	if role then
		RolePaint(fs, role, false)
		return true
	end
	if 0.3 * r + 0.59 * g + 0.11 * b > 0.5 then
		-- une couleur claire inconnue : plus de repli silencieux, l'encre du
		-- texte courant (mesurée) ; notée dans ns.carnetInkMisses (testée)
		ns.carnetInkMisses = ns.carnetInkMisses or {}
		if #ns.carnetInkMisses < 50 then
			ns.carnetInkMisses[#ns.carnetInkMisses + 1] = "fallback:" .. tostring(fs.GetText and fs:GetText())
		end
		RolePaint(fs, "page.ink", false)
		return true
	end
	return false
end

-- 2.9.0 : un intertitre sur parchemin : encres « section.label » / « section.detail »
local function InkSection(section, frame)
	local label, detail = section.label, section.detail
	if not label or label.azKeep or Dark(label, frame) then return false end
	Paint(label, RoleInk("section.label")); NoShadow(label)
	if detail then Paint(detail, RoleInk("section.detail")); NoShadow(detail) end
	return true
end

local function Recolor(frame)
	local reg = frame.azReg
	if not reg then return 0 end
	local count = 0
	for _, fs in ipairs(reg.texts) do
		if not fs.azKeep and not Dark(fs, frame) and ns.CarnetInk(fs) then count = count + 1 end
	end
	for _, section in ipairs(reg.sections or {}) do
		if InkSection(section, frame) then count = count + 1 end
	end
	return count
end
ns.CarnetRecolor = Recolor

-- ---------------------------------------------------------------------------
-- La fenêtre : bois, plaque, parchemins, métal, bouton de fermeture
-- ---------------------------------------------------------------------------
local function WindowWood(over, frame)
	local S, O = ns.AZEROTH_WOOD_SIZE or 64, ns.AZEROTH_WOOD_OUT or 8
	local wood = {}
	local function Piece(key)
		local tex = over:CreateTexture(nil, "BORDER", nil, 1)
		tex:SetSize(S, S)
		if ns.AzerothAtlas then ns.AzerothAtlas(tex, ns.AZEROTH_WOOD[key]) end
		tex:Show()
		wood[key] = tex
		return tex
	end
	Piece("tl"):SetPoint("TOPLEFT", frame, "TOPLEFT", -O, O)
	Piece("tr"):SetPoint("TOPRIGHT", frame, "TOPRIGHT", O, O)
	Piece("bl"):SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -O, -O)
	Piece("br"):SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", O, -O)
	local top, bottom, left, right = Piece("top"), Piece("bottom"), Piece("left"), Piece("right")
	top:SetPoint("TOPLEFT", wood.tl, "TOPRIGHT", 0, 0); top:SetPoint("TOPRIGHT", wood.tr, "TOPLEFT", 0, 0)
	bottom:SetPoint("BOTTOMLEFT", wood.bl, "BOTTOMRIGHT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", wood.br, "BOTTOMLEFT", 0, 0)
	left:SetPoint("TOPLEFT", wood.tl, "BOTTOMLEFT", 0, 0); left:SetPoint("BOTTOMLEFT", wood.bl, "TOPLEFT", 0, 0)
	right:SetPoint("TOPRIGHT", wood.tr, "BOTTOMRIGHT", 0, 0); right:SetPoint("BOTTOMRIGHT", wood.br, "TOPRIGHT", 0, 0)
	Method(top, "SetHorizTile", true); Method(bottom, "SetHorizTile", true)
	Method(left, "SetVertTile", true); Method(right, "SetVertTile", true)
	return wood
end

-- La plaque d'en-tête (deux morceaux de ui-achievement-header), son titre et
-- la case des points ; nil si le client refuse la texture
local function Plate(frame, over, title)
	local plate = CreateFrame("Frame", nil, over)
	plate:SetSize(LAY.plateW, LAY.plateH)
	plate:SetPoint("TOP", frame, "TOP", 0, LAY.plateUp)
	plate:SetFrameLevel(Level(over) + 1)
	plate:EnableMouse(false)
	local b, a = NewTex(plate, "ARTWORK", 0, T.headB), NewTex(plate, "ARTWORK", 1, T.headA)
	if not (a and b) then
		if a then a:Hide() end
		if b then b:Hide() end
		plate:Hide()
		return nil
	end
	a:SetSize(504, 94); a:SetPoint("TOPLEFT", plate, "TOPLEFT", 0, 0)
	b:SetSize(214, 83); b:SetPoint("TOPLEFT", plate, "TOPLEFT", 492, -6)
	plate.left, plate.right = a, b
	plate.title = plate:CreateFontString(nil, "OVERLAY", Theme.F_TITLE)
	plate.title:SetPoint("TOPLEFT", plate, "TOPLEFT", 258, -50)
	plate.title:SetSize(232, 20)
	plate.title:SetJustifyH("CENTER")
	if plate.title.SetJustifyV then plate.title:SetJustifyV("MIDDLE") end   -- 2.9.0
	AzFont(plate.title, 15)
	Paint(plate.title, GOLD_TEXT)
	Shadow(plate.title)
	if plate.title.SetWordWrap then plate.title:SetWordWrap(false) end
	plate.title:SetText(title or "")
	plate.box = NewTex(plate, "ARTWORK", 2, T.ptBox)
	if plate.box then
		plate.box:SetSize(129, 34)
		plate.box:SetPoint("TOPLEFT", plate, "TOPLEFT", 60, -44)
		-- 2.9.0 : le groupe « bouclier + nombre » centré dans la case (le
		-- nombre décalé de la moitié du bouclier et de son écart, 20 + 4) et
		-- sur le creux sombre de la case (lignes 11 à 21 sur 34 : 1 px plus
		-- haut que le milieu, mesuré sur 235402)
		plate.count = plate:CreateFontString(nil, "OVERLAY", Theme.F_LABEL)
		plate.count:SetPoint("CENTER", plate.box, "CENTER", PLATE_COUNT.x, PLATE_COUNT.y)
		plate.count:SetJustifyH("CENTER")
		if plate.count.SetJustifyV then plate.count:SetJustifyV("MIDDLE") end
		RolePaint(plate.count, "plate.count", true)   -- 2.11.0 : rôle déclaré (fiche 08)
		plate.count:SetText("")
		plate.icon = NewTex(plate, "OVERLAY", 0, T.tiny)
		if plate.icon then
			plate.icon:SetSize(20, 18)
			plate.icon:SetPoint("RIGHT", plate.count, "LEFT", -4, 0)
		end
	end
	function plate:SetCount(text)
		if not self.count then return end
		self.count:SetText(text or "")
		if self.icon then if text and text ~= "" then self.icon:Show() else self.icon:Hide() end end
	end
	plate:Show()
	return plate
end

-- Le cadre Azeroth autour d'une fenêtre du thème (Theme.CreateWindow) ; la
-- zone de droite (frame.content) garde sa taille, la fenêtre grandit
local function Chrome(self, frame, title)
	local content, nav = frame.content, frame.nav
	local cw, ch = tonumber(content:GetWidth()) or 0, tonumber(content:GetHeight()) or 0
	local navW = nav and LAY.nav or 0
	local W = LAY.wood + (nav and (navW + LAY.gap) or 0) + cw + LAY.wood
	local H = LAY.band + ch + LAY.wood
	frame:SetSize(W, H)
	frame.azSize = { W, H }
	Method(frame, "SetClampRectInsets", -8, 8, LAY.plateUp, -8)
	frame.azeroth, frame.uiStyle = true, "azeroth"
	if frame.bg then frame.bg:SetVertexColor(WOOD_BG[1], WOOD_BG[2], WOOD_BG[3], 0.98) end
	HideAll(frame.border)
	local over = CreateFrame("Frame", nil, frame)
	over:SetAllPoints(frame)
	over:SetFrameLevel(Level(frame) + 30)
	over:EnableMouse(false)
	frame.azOver = over
	frame.azWood = WindowWood(over, frame)
	if nav then
		nav:ClearAllPoints()
		nav:SetPoint("TOPLEFT", frame, "TOPLEFT", LAY.wood, -LAY.band)
		nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", LAY.wood, LAY.wood)
		nav:SetWidth(navW)
		local parch = NewTex(nav, "BACKGROUND", 1, T.parchV)
		if parch then
			parch:SetAllPoints(nav)
			Cover(parch, T.parchV, navW, ch)
			if nav.bg then nav.bg:Hide() end
			nav.azBg, nav.azSurface = parch, "light"
			nav.azVeil = ns.AzerothVeil(nav, nav, "nav", 2)
		end
		if nav.separator then nav.separator:Hide() end
		frame.azMetalL = NewTex(over, "ARTWORK", 0, T.metalL)
		if frame.azMetalL then
			frame.azMetalL:SetWidth(LAY.gap)
			frame.azMetalL:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
			frame.azMetalL:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 0, 0)
		end
		content:ClearAllPoints()
		content:SetPoint("TOPLEFT", nav, "TOPRIGHT", LAY.gap, 0)
	else
		content:ClearAllPoints()
		content:SetPoint("TOPLEFT", frame, "TOPLEFT", LAY.wood, -LAY.band)
	end
	content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -LAY.wood, LAY.wood)
	content:SetSize(cw, ch)
	local page = NewTex(content, "BACKGROUND", -2, T.parchH)
	if page then
		page:SetAllPoints(content)
		Cover(page, T.parchH, cw, ch)
		content.azBg, content.azSurface = page, "light"
		if frame.footer then
			if frame.footer.bg then frame.footer.bg:Hide() end
			if frame.footer.line then frame.footer.line:Hide() end
		end
		local shade = NewTex(content, "BACKGROUND", -1, T.shadow)
		if shade then
			shade:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
			shade:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
			shade:SetWidth(34)
			shade:SetAlpha(0.4)
		end
		-- 2.8.2 : le voile crème des pages (texte du thème à 4,7:1 au moins)
		content.azVeil = ns.AzerothVeil(content, content, "page", 0)
	end
	frame.azMetalT = NewTex(over, "ARTWORK", 0, T.metalT)
	if frame.azMetalT then
		frame.azMetalT:SetHeight(10)
		frame.azMetalT:SetPoint("TOPLEFT", frame, "TOPLEFT", LAY.wood, -(LAY.band - 10))
		frame.azMetalT:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -LAY.wood, -(LAY.band - 10))
	end
	if nav then
		local joint = NewTex(over, "ARTWORK", 1, T.metalJ)
		if joint then
			joint:SetSize(26, 26)
			joint:SetPoint("CENTER", frame, "TOPLEFT", LAY.wood + navW + LAY.gap / 2, -(LAY.band - 5))
		end
	end
	for index, spec in ipairs({ T.curl, T.curlR }) do
		local curl = NewTex(over, "ARTWORK", 2, spec)
		if curl then
			curl:SetSize(40, 40)
			if index == 1 then curl:SetPoint("TOPLEFT", content, "TOPLEFT", -2, 2)
			else curl:SetPoint("TOPRIGHT", content, "TOPRIGHT", 2, 2) end
		end
	end
	frame.azPlate = Plate(frame, over, title)
	-- le bouton de fermeture du jeu, dans le bois
	local close = frame.close
	if close then
		local icon = close:CreateTexture(nil, "ARTWORK")
		if SetTex(icon, { file = CLOSE_TEX }) then
			icon:SetSize(32, 32)
			icon:SetPoint("CENTER", close, "CENTER", 0, 0)
			icon:Show()
			close.azIcon = icon
			if close.label then close.label:Hide() end
			HideAll(close.border)
		else
			icon:Hide()
		end
		close:ClearAllPoints()
		close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
		close:SetFrameLevel(Level(over) + 6)
	end
	if frame.settingsButton then frame.settingsButton:SetFrameLevel(Level(over) + 6) end
	return over
end
ns.CarnetChrome = Chrome

-- ---------------------------------------------------------------------------
-- Le carnet : colonne de gauche, pages
-- ---------------------------------------------------------------------------
local function ModuleOn()
	local db = ns:DB()
	return db.enabled ~= false and db.companionEnabled ~= false
end

local function JournalNav(self, frame)
	local nav = frame.nav
	if not nav then return end
	if frame.azPlate and frame.brand then frame.brand:Hide() end
	if frame.navGroup then
		frame.navGroup:ClearAllPoints()
		frame.navGroup:SetPoint("TOPLEFT", nav, "TOPLEFT", 14, -12)
		if nav.azSurface == "light" then
			Paint(frame.navGroup, INKS.ink)
			NoShadow(frame.navGroup)
			frame.navGroup.azKeep = true
		end
	end
	local items = {}
	for _, item in pairs(frame.sections or {}) do items[#items + 1] = item end
	table.sort(items, function(a, b) return (select(5, a:GetPoint()) or 0) > (select(5, b:GetPoint()) or 0) end)
	for index, item in ipairs(items) do
		item:ClearAllPoints()
		item:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, LAY.navTop - (index - 1) * LAY.navStep)
		item:SetSize(LAY.nav, LAY.navItemH)
	end
	frame.azNavItems = items
	-- une entrée restée Sobre (fond refusé) : la colonne aussi, sinon son
	-- texte clair tomberait sur le parchemin
	if nav.azBg and Has(items, function(item) return not item.azBg end) then
		nav.azBg:Hide()
		if nav.bg then nav.bg:Show() end
		nav.azSurface = nil
		if frame.navGroup then frame.navGroup.azKeep = nil; Paint(frame.navGroup, Theme.GOLD) end
	end
	-- le garde-manger, en bas de la colonne
	if frame.pantry then
		if frame.pantryLabel then
			frame.pantryLabel:SetParent(nav)
			frame.pantryLabel:ClearAllPoints()
			frame.pantryLabel:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 12, 50)
		end
		local index = 0
		for _, kind in ipairs(ns.TREAT_KINDS or {}) do
			local button = frame.pantry[kind]
			if button then
				button:SetParent(nav)
				button:ClearAllPoints()
				button:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 10 + index * 36, 12)
				button:SetSize(32, 32)
				HideAll(button.border)
				button.icon:ClearAllPoints()
				button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
				button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
				button.azRing = NewTex(button, "OVERLAY", 0, T.iconFrame)
				if button.azRing then button.azRing:SetAllPoints(button) end
				if button.count then
					-- 2.11.0 : une ombre sous le chiffre, le fond (l'icône) ne décide plus
					RolePaint(button.count, "pantry.count", true)
					ShadeUnder(button, button.count, 0.75, 1)
				end
				index = index + 1
			end
		end
		frame.azPantry = true
	end
	if frame.subtitle then
		frame.subtitle:ClearAllPoints()
		frame.subtitle:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 12, 72)
		frame.subtitle:SetWidth(LAY.nav - 24)
	end
	-- 2.11.0 (fiche 14) : les blocs résumé sous les entrées, encres mesurées
	-- sur le parchemin de la colonne (navSum.*)
	local box = frame.navSummary
	if box then
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", nav, "TOPLEFT", LAY.navPad, LAY.navTop - #items * LAY.navStep - 14)
		-- 2.11.1 : largeur intérieure de la colonne (marge égale des deux côtés)
		if ns.JournalNavSummaryFit then ns.JournalNavSummaryFit(box, LAY.nav - 2 * LAY.navPad) end
		if nav.azSurface == "light" then
			RolePaint(box.pet.name, "navSum.name")
			for _, row in ipairs(box.pet.needs or {}) do
				RolePaint(row.label, "navSum.label")
				if row.bar then row.bar.azPaint = ns.CarnetNeedPaint end
			end
			RolePaint(box.zone.name, "navSum.name")
			RolePaint(box.zone.percent, "navSum.value")
			for _, row in ipairs(box.missions.rows or {}) do
				RolePaint(row.label, "navSum.label")
				RolePaint(row.left, "navSum.value")
			end
			for _, block in ipairs({ box.pet, box.zone, box.missions }) do
				local c = ns.AZEROTH_MISSION.rule
				if block.rule then block.rule:SetVertexColor(c[1], c[2], c[3], 0.6) end
			end
		end
	end
end

local PAGE, POST = {}, {}
ns.CARNET_PAGE_SKINS, ns.CARNET_PAGE_POSTS = PAGE, POST

-- 2.9.1 : le compteur d'un pager (« 1-9 / 60 ») : créé par la brique du
-- thème hors de la relève (texte local), il restait gris clair sur le
-- parchemin ; encre mesurée « pager.position »
local function InkPager(pager)
	local fs = pager and pager.position
	if not fs then return end
	Paint(fs, RoleInk("pager.position")); NoShadow(fs)
	fs.azKeep = true
end
ns.CarnetInkPager = InkPager

-- 2.9.1 : un anneau rond des hauts faits (atlas du client) autour de `region`
local function RoundRing(host, region, size, layer)
	local ring = host:CreateTexture(nil, layer or "OVERLAY")
	if not (ns.AzerothAtlas and ns.AzerothAtlas(ring, ns.AZEROTH_ATLAS.frameRound)) then ring:Hide(); return nil end
	ring:SetSize(size, size)
	ring:SetPoint("CENTER", region, "CENTER", 1, 0)
	ring:Show()
	return ring
end



-- 2.11.0 (B4) : intertitre de la page Missions à l'encre sombre sur le
-- parchemin, un filet brun dessous (avant : bande dégradée sombre, texte
-- clair peu lisible) ; l'étiquette (caractère, zone) reste un aplat sombre
local function Strip(section)
	local rule = section.azRule
	if not rule then
		rule = section:CreateTexture(nil, "ARTWORK", nil, 1)
		rule:SetTexture(Theme.SOLID)
		section.azRule = rule
	end
	local c = ns.AZEROTH_MISSION.rule
	rule:SetVertexColor(c[1], c[2], c[3], 1)
	rule:ClearAllPoints()
	rule:SetPoint("BOTTOMLEFT", section, "BOTTOMLEFT", 0, 1)
	rule:SetSize(tonumber(section:GetWidth()) or 300, 2)
	rule:Show()
	if section.rule then for _, seg in ipairs(section.rule.segments or { section.rule }) do if seg.Hide then seg:Hide() end end end
	section.azStrip, section.azSurface = rule, "light"
	if section.label then
		section.label:ClearAllPoints()
		section.label:SetPoint("LEFT", section, "LEFT", 2, 0)
		RolePaint(section.label, "mheader.label")
	end
	if section.detail then RolePaint(section.detail, "mheader.detail") end
	return rule
end

-- Titre doré ombré sur fond sombre ; sur parchemin (light) : encre
-- brun-rouge sans ombre (l'or n'y tient pas 3:1)
local function GoldTitle(fs, size, light)
	AzFont(fs, size)
	if light then
		Paint(fs, INKS.title)
		NoShadow(fs)
	else
		Paint(fs, GOLD_HEAD)
		Shadow(fs)
	end
	fs.azKeep = true
end

-- Envie : verte comblée, orange basse, or entre les deux
local function NeedPaint(bar)
	local value = (tonumber(bar.ratio) or 0) * 100
	if value >= (ns.COMPANION_HAPPY_MIN or 70) then return BAR_GREEN end
	if value < 30 then return BAR_ORANGE end
	return BAR_GOLD
end
ns.CarnetNeedPaint = NeedPaint

function PAGE.evolution(self, frame)
	local pane = frame.evo
	if not pane then return end
	local hero = pane.hero
	if hero then
		TileStyle(hero, "light")
		WoodBorder(hero)
		local portrait = hero.portrait
		if portrait and ns.AZEROTH_ATLAS then
			local ring = CreateFrame("Frame", nil, hero)
			ring:SetPoint("CENTER", portrait, "CENTER", 0, 0)
			ring:SetSize((tonumber(portrait:GetWidth()) or 148) + 34, (tonumber(portrait:GetHeight()) or 148) + 34)
			ring:SetFrameLevel(Level(portrait) + 6)
			ring:EnableMouse(false)
			local vine = ring:CreateTexture(nil, "OVERLAY")
			vine:SetAllPoints(ring)
			if ns.AzerothAtlas and ns.AzerothAtlas(vine, ns.AZEROTH_ATLAS.frameRound) then vine:Show() else ring:Hide() end
			pane.azVine = vine
		end
	end
	if pane.name then GoldTitle(pane.name, 19, true) end
	if pane.bubble then TileStyle(pane.bubble, "talk") end
	for _, tile in pairs(pane.stats or {}) do
		if TileStyle(tile, "dark") then
			HideAll(tile.border)
			-- 2.11.0 (B1) : chiffre et libellé centrés ensemble, encres mesurées
			GoldTitle(tile.value, 16)
			RolePaint(tile.value, "stat.value", true)
			RolePaint(tile.label, "stat.label", true)
			-- 2.11.1 : groupe recentré avec la police du style
			if ns.JournalStatCenter then ns.JournalStatCenter(tile) end
		end
	end
	for _, row in ipairs(pane.needs or {}) do
		TileStyle(row, "band")
		if row.bar then
			row.bar:SetHeight(14)
			row.bar.azPaint = NeedPaint
			BarPaint(row.bar)
		end
	end
end

function PAGE.menagerie(self, frame)
	local pane = frame.men
	if pane then InkPager(pane.pager) end
	if not (pane and pane.preview) then return end
	local p = pane.preview
	TileStyle(p, "light")
	HideAll(p.border)
	if p.stage and SetTex(p.stage, ns.AZEROTH_PORTRAIT_BG) then p.stage:SetVertexColor(1, 1, 1, 1) end
	if p.rule then p.rule:Hide() end
	local y = select(5, p.title:GetPoint()) or -182
	p.azTitle = NewTex(p, "ARTWORK", 1, T.titleGrey)
	if p.azTitle then
		p.azTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y + 4)
		p.azTitle:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, y + 4)
		p.azTitle:SetHeight(20)
		p.title:ClearAllPoints()
		p.title:SetPoint("CENTER", p.azTitle, "CENTER", 0, 0)
		p.title:SetJustifyH("CENTER")
		RolePaint(p.title, "preview.title", true)
	end
	WoodBorder(p)
end

-- 2.8.2 : la couleur de rareté du nom, en version sombre pour la ligne
-- claire (la couleur claire du jeu y tombait sous 2:1)
local RARITY_INK = { trivial = "rTrivial", minus = "rTrivial", normal = "ink", elite = "rElite", rare = "rRare",
	rareelite = "rRare", worldboss = "rBoss" }
ns.CARNET_RARITY_INK = RARITY_INK
function ns.CarnetRarityInk(entry)
	if entry and entry.shiny then return INKS.rShiny end
	return INKS[RARITY_INK[entry and entry.class or "normal"] or "ink"] or INKS.ink
end

function POST.menagerie(self, frame)
	local pane = frame.men
	if not pane then return end
	for _, row in ipairs(pane.items or {}) do
		local entry = row.entry
		if entry then
			if entry.known then
				-- ligne claire voilée : n° et type 5,2:1 et plus, nom à sa rareté (4,7:1 et plus)
				TileStyle(row, "light")
				if row.no then Paint(row.no, INKS.inkSoft); NoShadow(row.no) end
				if row.label then Paint(row.label, ns.CarnetRarityInk(entry)); NoShadow(row.label) end
				if row.detail then Paint(row.detail, INKS.inkSoft); NoShadow(row.detail) end
			else
				-- jamais croisée : parchemin désaturé, texte clair ombré (5,4:1)
				TileStyle(row, "parchd")
				for _, fs in ipairs({ row.label, row.no, row.detail }) do
					if fs then Paint(fs, LIGHT); Shadow(fs); fs:SetAlpha(1) end
				end
			end
			for _, fs in ipairs({ row.label, row.no, row.detail }) do if fs then fs.azKeep = true end end
		end
	end
end

function PAGE.feats(self, frame)
	local pane = frame.feats
	if not pane then return end
	for _, row in ipairs(pane.cats or {}) do
		if TileStyle(row, "dark") then Selectable(row) end
	end
	local w = tonumber(pane.RW) or 500
	for _, row in ipairs(pane.rows or {}) do
		row.azTitle = NewTex(row, "ARTWORK", -1, T.titleGold)
		if row.azTitle then
			row.azTitle:SetPoint("TOPLEFT", row, "TOPLEFT", 58, -4)
			row.azTitle:SetPoint("TOPRIGHT", row, "TOPRIGHT", -62, -4)
			row.azTitle:SetHeight(18)
			row.name:ClearAllPoints()
			row.name:SetPoint("CENTER", row.azTitle, "CENTER", 0, 0)
			row.name:SetWidth(w - 140)
			row.name:SetJustifyH("CENTER")
			Shadow(row.name)
			row.name.azKeep = true
			row.desc:ClearAllPoints()
			row.desc:SetPoint("TOP", row.azTitle, "BOTTOM", 0, -3)
			row.desc:SetWidth(w - 200)
			row.desc:SetJustifyH("CENTER")
			if row.scope then
				row.scope:ClearAllPoints()
				row.scope:SetPoint("TOPRIGHT", row, "TOPRIGHT", -64, -24)
			end
		end
		row.azRing = Ring(row, row.icon, 52)
		if row.pts then
			AzFont(row.pts, 13)
			Shadow(row.pts)
			row.pts.azKeep = true
		end
	end
	local ui, content = ns.JournalUI, frame.content
	local shield = NewTex(pane, "ARTWORK", 0, T.shieldBig)
	if shield and ui then
		-- 2.9.0 : au rapport du dessin recadré (70×51), écu de 26×31 ; le
		-- nombre au centre visuel de l'écu (partie large en haut : 3 px plus
		-- haut que le milieu, moins 1 px pour des chiffres sans jambage),
		-- en plus petit à 3 ou 4 chiffres (l'écu fait 26 px de large)
		shield:SetSize(SHIELD_BIG.w, SHIELD_BIG.h)
		ui.At(shield, content, 0, ui.TOP + 4)
		ui.At(pane.totals, content, SHIELD_BIG.w + 6, ui.TOP - 2)
		ui.At(pane.count, content, SHIELD_BIG.w + 6, ui.TOP - 19)
		pane.azShieldText = pane:CreateFontString(nil, "OVERLAY", Theme.F_NUMBER)
		pane.azShieldText:SetPoint("CENTER", shield, "CENTER", 0, SHIELD_BIG.y)
		pane.azShieldText:SetJustifyH("CENTER")
		if pane.azShieldText.SetJustifyV then pane.azShieldText:SetJustifyV("MIDDLE") end
		AzFont(pane.azShieldText, 14, "OUTLINE")
		RolePaint(pane.azShieldText, "shield.count", true)
		pane.azShield = shield
	end
end

function POST.feats(self, frame)
	local pane = frame.feats
	if not pane then return end
	for _, row in ipairs(pane.rows or {}) do
		local entry = row.entry
		if entry then
			TileStyle(row, entry.got and "light" or "parchd")
			if row.azTitle then SetTex(row.azTitle, entry.got and T.titleGold or T.titleGrey) end
			if row.pts then Paint(row.pts, entry.got and INKS.white or INKS.ptsGrey) end
			if row.name and row.azTitle then Paint(row.name, entry.got and INKS.white or INKS.barGrey) end
			-- 2.8.2 : une encre par rôle (AZEROTH_CONTRAST feat.* / featOpen.*) :
			-- obtenu, ligne claire voilée ; pas encore, parchemin sombre
			local got = entry.got and true or false
			local roles = got and { desc = "ink", reward = "reward", date = "inkMuted", count = "inkMuted" }
				or { desc = "light", reward = "rewardLight", date = "light", count = "light" }
			for field, key in pairs(roles) do
				local fs = row[field]
				if fs then
					Paint(fs, INKS[key])
					if got then NoShadow(fs) else Shadow(fs) end
					fs.azKeep = true
				end
			end
		end
	end
	if pane.azShieldText and self.FeatPoints then
		pane.azShieldText:SetText(tostring((self:FeatPoints())))
		AzFont(pane.azShieldText, SHIELD_BIG.font[math.min(4, #(pane.azShieldText:GetText() or ""))] or 14, "OUTLINE")
	end
end

function PAGE.day(self, frame)
	local pane = frame.day
	if not pane then return end
	local M = ns.AZEROTH_MISSION
	local sections = { pane.innTitle, pane.pantryTitle, pane.aidTitle }
	for _, group in pairs(pane.groups or {}) do sections[#sections + 1] = group end
	for _, section in ipairs(sections) do Strip(section) end
	for _, slot in ipairs(pane.slots or {}) do slot.azRing = Ring(slot, slot.icon, 40) end
	for _, tile in ipairs(pane.aids or {}) do tile.azRing = Ring(tile, tile.icon, 34) end
	-- cartes : icône dans le cadre des hauts faits, voile vert pour une faite,
	-- bouton ↻ dans l'anneau rond
	for _, card in ipairs(pane.missions or {}) do
		card.azRing = Ring(card, card.icon, 42)
		if card.azRing then
			HideAll(card.iconEdge)
			card.azNoEdge = true
		end
		if card.tint then card.tint:SetVertexColor(M.tint[1], M.tint[2], M.tint[3], M.tint[4]) end
		if card.stamp and card.stamp.bg then card.stamp.bg:SetVertexColor(M.stamp[1], M.stamp[2], M.stamp[3], 1) end
		local button = card.reroll
		if button then
			button.azRing = RoundRing(button, button, 30)
			if button.azRing then HideAll(button.border) end
		end
	end
	-- bande résumé : plaques sombres (fond des catégories), icône cerclée
	for _, plaque in ipairs(pane.summary or {}) do
		if TileStyle(plaque, "dark") then HideAll(plaque.border) end
		plaque.azRing = Ring(plaque, plaque.icon, 36)
	end
	for id, chip in pairs(pane.chips or {}) do
		local c = id == "trait" and M.chipTrait or M.chipZone
		chip.bg:SetVertexColor(c[1], c[2], c[3], 1)
	end
	-- encarts des 3 : aplat crème, pointillés bruns
	for _, box in pairs(pane.callouts or {}) do
		box.bg:SetVertexColor(M.callout[1], M.callout[2], M.callout[3], M.callout[4])
		box.dashColor = M.dash
		for _, dash in ipairs(box.dashes) do dash:SetVertexColor(M.dash[1], M.dash[2], M.dash[3], M.dash[4]) end
		box.azSurface = "light"
	end
	-- carte des auberges : chaque tampon dans un anneau rond
	for _, stamp in ipairs(pane.stamps or {}) do
		stamp.azRing = RoundRing(pane.innPanel, stamp, 36)
	end
end

function POST.day(self, frame)
	local pane = frame.day
	if not pane then return end
	local M = ns.AZEROTH_MISSION
	for _, card in ipairs(pane.missions or {}) do
		-- la taille a pu changer (demie / large) : le fond recadré
		if card.azBg and card.azStyle == "light" and card.azCoverW ~= card.cardW then
			Cover(card.azBg, T.achBg, card:GetWidth(), card:GetHeight())
			card.azCoverW = card.cardW
		end
		local p = card.mission and card.mission.done and "mcardDone." or "mcard."
		RolePaint(card.label, p .. "title")
		RolePaint(card.zone, p .. "zone")
		RolePaint(card.count, p .. "count")
		RolePaint(card.source, p .. "reward")
		if card.stamp then RolePaint(card.stamp.text, "mission.stamp") end
		if card.azRing and card.icon then
			if card.icon:IsShown() then card.azRing:Show() else card.azRing:Hide() end
		end
	end
	for _, plaque in ipairs(pane.summary or {}) do
		RolePaint(plaque.label, "summary.label", true)
		RolePaint(plaque.count, "summary.count", true)
		RolePaint(plaque.detail, "summary.detail", true)
		for _, pip in ipairs(plaque.pips or {}) do
			local c = pip.on and M.pipOn or M.pipOff
			pip:SetVertexColor(c[1], c[2], c[3], 1)
		end
	end
	for id, chip in pairs(pane.chips or {}) do RolePaint(chip.text, id == "trait" and "chip.trait" or "chip.zone") end
	for _, box in pairs(pane.callouts or {}) do RolePaint(box.text, "bonus.text") end
	RolePaint(pane.innTotal, "panel.text")
	RolePaint(pane.innHint, "panel.soft")
	RolePaint(pane.innGift, "panel.muted")
	RolePaint(pane.perfect, "panel.muted")
	RolePaint(pane.pantryHint, "panel.muted")
	for _, slot in ipairs(pane.slots or {}) do RolePaint(slot.count, "panel.text") end
	for _, tile in ipairs(pane.aids or {}) do
		RolePaint(tile.count, "panel.text")
		RolePaint(tile.name, "panel.soft")
	end
end

function PAGE.progress(self, frame)
	local pane = frame.prog
	if not pane then return end
	InkPager(pane.zonePager)
	InkPager(pane.listPager)
	for _, row in ipairs(pane.zones or {}) do
		if TileStyle(row, "dark") then Selectable(row) end
	end
	if pane.card then
		TileStyle(pane.card, "light")
		WoodBorder(pane.card)
	end
	if pane.name then GoldTitle(pane.name, 15, true) end
	for _, tile in ipairs(pane.parts or {}) do
		if TileStyle(tile, "dark") then Selectable(tile) end
		-- 2.9.0 : libellé et compte centrés entre le haut de la carte et le
		-- liseré de la barre (3 px au-dessus d'elle), plus collés au bord
		if tile.bar then
			local barY = select(5, tile.bar:GetPoint()) or -32
			local G = ns.CARNET_PROGRESS_LAYOUT
			SpanV(tile.label, "LEFT", tile, 12, -G.partTop, tile, "TOPLEFT", barY + G.barEdge)
			SpanV(tile.count, "RIGHT", tile, -12, -G.partTop, tile, "TOPRIGHT", barY + G.barEdge)
		end
	end
	for _, tile in ipairs(pane.marks or {}) do
		TileStyle(tile, "grey")
		HideAll(tile.border)
	end
end

-- 2.9.0 : une rangée de zone : nom, « ici » et pourcentage centrés sur la
-- bande au-dessus de la barre ; sans barre (zone pas encore vue), sur toute
-- la rangée. Avant : posés à 4-5 px du haut, ils touchaient le liseré.
local function ZoneRowText(row)
	local G = ns.CARNET_PROGRESS_LAYOUT
	local barShown = row.bar and row.bar:IsShown()
	local barY = row.bar and select(5, row.bar:GetPoint()) or -20
	local bottom, bottomY = row, G.rowPad
	local leftPoint, rightPoint = "BOTTOMLEFT", "BOTTOMRIGHT"
	if barShown then leftPoint, rightPoint, bottomY = "TOPLEFT", "TOPRIGHT", barY end
	row.azBarShown = barShown and true or false
	SpanV(row.name, "LEFT", row, 10, -G.rowPad, bottom, leftPoint, bottomY)
	SpanV(row.percent, "RIGHT", row, -8, -G.rowPad, bottom, rightPoint, bottomY)
	SpanV(row.here, "RIGHT", row, -8 - 36 - 4, -G.rowPad, bottom, rightPoint, bottomY)
end
ns.CarnetZoneRowText = ZoneRowText

-- 2.9.1 : les textes d'une rangée de zone, à l'encre mesurée (rôles zone.*).
-- Avant : une zone pas encore vue était estompée (alpha 0,55) : fond sombre
-- et texte clair à moitié transparents sur le parchemin, illisibles. La rangée
-- reste opaque, le gris « zoneDim » dit qu'elle n'est pas encore vue.
local function ZoneRowInk(row)
	local zone = row.zone
	if not zone or row.azStyle ~= "dark" then return false end
	row:SetAlpha(1)
	if row.selected then return true end
	local ink = RoleInk(zone.seen and "zone.label" or "zone.unseen")
	Paint(row.name, ink); Shadow(row.name)
	if row.percent and not (zone.seen and zone.percent == 100) then Paint(row.percent, ink); Shadow(row.percent) end
	return true
end
ns.CarnetZoneRowInk = ZoneRowInk

-- 2.9.1 : une ligne de quête (fond clair voilé), à l'encre mesurée (rôles
-- quest.*). Le carnet repasse les encres (Recolor) AVANT de poser le fond des
-- lignes : à la première ouverture, la ligne passait pour sombre et gardait
-- le texte clair du thème. Le détail perd son code couleur gris (|cff…).
local function QuestLineInk(line, item)
	if line.azStyle ~= "light" then return false end
	local done = item.done or item.locked
	Paint(line.text, RoleInk(done and "quest.nameDone" or "quest.name")); NoShadow(line.text)
	line.detail:SetText(tostring(item.detail or ""))
	Paint(line.detail, RoleInk(item.done and "quest.detailDone" or "quest.detail")); NoShadow(line.detail)
	return true
end
ns.CarnetQuestLineInk = QuestLineInk

function POST.progress(self, frame)
	local pane = frame.prog
	if not pane then return end
	for _, row in ipairs(pane.zones or {}) do ZoneRowText(row); ZoneRowInk(row) end
	for _, tile in ipairs(pane.marks or {}) do
		if TileStyle(tile, tile.reached and "gold" or "grey") then
			-- 2.11.0 (fiche 08) : encres lues dans la table ; le cadeau sur une
			-- ombre (la bande dorée est trop claire sous lui : 3,7:1 sans)
			RolePaint(tile.label, tile.reached and "mark.gold" or "mark.grey", true)
			RolePaint(tile.gift, tile.reached and "mark.giftGold" or "mark.giftGrey", true)
			ShadeUnder(tile, tile.gift, 0.45, 2)
		end
	end
	for _, line in ipairs(pane.items or {}) do
		local item = line.item
		if item then
			if item.header then
				if TileStyle(line, "stathead") then Paint(line.text, GOLD_HEAD); Shadow(line.text) end
			else
				TileStyle(line, "light")
				QuestLineInk(line, item)
			end
		end
	end
end

function PAGE.guide(self, frame)
	local pane = frame.guide
	if not pane then return end
	for _, row in ipairs(pane.rows or {}) do
		if TileStyle(row, "dark") then Selectable(row) end
	end
	local ui, content = ns.JournalUI, frame.content
	if not ui then return end
	local page = NewTex(pane, "BACKGROUND", 1, T.stats)
	if page then
		local x0, x1 = ui.PAD + pane.RX - 12, ui.PAD + ui.INNER + 8
		local y0, y1 = ui.TOP + 10, ui.PAGER_Y - 28
		page:SetPoint("TOPLEFT", content, "TOPLEFT", x0, y0)
		page:SetPoint("BOTTOMRIGHT", content, "TOPLEFT", x1, y1)
		Cover(page, T.stats, x1 - x0, y0 - y1)
		-- voile crème (50 %) : texte 6,1:1, intertitres 5,1:1 sur le pire fond
		local veil = ns.AzerothVeil(pane, page, "guide", 2)
		pane.azPage, pane.azVeil = page, veil
	end
	-- 2.8.2 : le titre chevauchait le filigrane et la première ligne. De haut
	-- en bas : le titre doré sur la bande sombre des statistiques (13:1),
	-- le filigrane, puis le texte (pane.bodyTop descend d'autant)
	local G = ns.CARNET_GUIDE_LAYOUT
	local x = ui.PAD + pane.RX
	pane.azBand = NewTex(pane, "ARTWORK", 0, T.statHead)
	if pane.azBand then
		pane.azBand:SetPoint("TOPLEFT", content, "TOPLEFT", x - 6, ui.TOP + G.bandUp)
		pane.azBand:SetSize(pane.RW + 12, G.bandH)
	end
	if pane.title then
		GoldTitle(pane.title, 18, not pane.azBand)
		if pane.azBand then
			pane.title:ClearAllPoints()
			pane.title:SetPoint("LEFT", pane.azBand, "LEFT", 10, 0)
		end
	end
	pane.azFiligree = Filigree(pane, x, ui.TOP - G.filigreeY, pane.RW)
	local shift = G.bodyY - (ui.TOP - (pane.bodyTop or ui.TOP))
	if shift > 0 and pane.bodyTop then
		pane.bodyTop = pane.bodyTop - shift
		if pane.areaH then pane.areaH = pane.areaH - shift end
	end
end
-- y depuis le haut des pages (ui.TOP) : bande du titre (dépasse de 4 px,
-- 26 de haut), filigrane (14 de haut), début du texte
ns.CARNET_GUIDE_LAYOUT = { bandUp = 4, bandH = 26, filigreeY = 28, filigreeH = 14, bodyY = 48 }

function POST.guide(self, frame)
	local pane = frame.guide
	if not pane then return end
	-- intertitres : encre brun-rouge sans ombre (l'or ombré tombait à 1,6:1)
	for _, head in ipairs(pane.heads or {}) do
		AzFont(head, 13)
		Paint(head, INKS.head)
		NoShadow(head)
		head.azKeep = true
	end
end

-- 2.12.0 : Juke-box. Pistes sur le parchemin des statistiques voilé comme le
-- guide ; chaque piste est une ligne claire de 504×24 (fond des hauts faits,
-- voile 0,40), la mesure des quêtes d'Exploration (juke.* = quest.*) ; les
-- vues à gauche en tuiles sombres sélectionnables, le titre sur la bande.
function PAGE.juke(self, frame)
	local pane = frame.juke
	if not pane then return end
	for _, tile in ipairs(pane.cats or {}) do
		if TileStyle(tile, "dark") then Selectable(tile) end
	end
	for _, row in ipairs(pane.rows or {}) do TileStyle(row, "light") end
	local ui, content = ns.JournalUI, frame.content
	if not ui then return end
	local page = NewTex(pane, "BACKGROUND", 1, T.stats)
	if page then
		local x0, x1 = ui.PAD + pane.RX - 12, ui.PAD + ui.INNER + 8
		local y0, y1 = ui.TOP + 10, ui.PAGER_Y - 28
		page:SetPoint("TOPLEFT", content, "TOPLEFT", x0, y0)
		page:SetPoint("BOTTOMRIGHT", content, "TOPLEFT", x1, y1)
		Cover(page, T.stats, x1 - x0, y0 - y1)
		pane.azPage, pane.azVeil = page, ns.AzerothVeil(pane, page, "guide", 2)
	end
	local G = ns.CARNET_GUIDE_LAYOUT
	pane.azBand = NewTex(pane, "ARTWORK", 0, T.statHead)
	if pane.azBand then
		pane.azBand:SetPoint("TOPLEFT", content, "TOPLEFT", ui.PAD + pane.RX - 6, ui.TOP + G.bandUp)
		pane.azBand:SetSize(pane.RW + 12, G.bandH)
	end
	if pane.title then
		GoldTitle(pane.title, 18, not pane.azBand)
		if pane.azBand then
			pane.title:ClearAllPoints()
			pane.title:SetPoint("LEFT", pane.azBand, "LEFT", 10, 0)
		end
	end
end

function POST.juke(self, frame)
	local pane = frame.juke
	if not pane then return end
	for _, row in ipairs(pane.rows or {}) do
		if row.azStyle == "light" and row.track then
			RolePaint(row.text, row.missing and "juke.missing" or (row.playing and "juke.playing" or "juke.name"))
			RolePaint(row.detail, "juke.detail")
			RolePaint(row.add.label, "juke.detail")
		end
	end
	RolePaint(pane.now, "juke.now")
	RolePaint(pane.hintLine, "juke.hint")
	RolePaint(pane.empty, "juke.now")
	InkPager(pane.pager)
end

-- ---------------------------------------------------------------------------
-- Construction et rafraîchissement du carnet Azeroth
-- ---------------------------------------------------------------------------
function ns:JournalStyle() return (self.AzerothScenesOn and self:AzerothScenesOn()) and "azeroth" or "sobre" end

local function JournalCounter(self)
	if self.FeatPoints then return self:F("CARNET_AZ_POINTS", (self:FeatPoints())) end
	local counts = self.JournalCounts and self:JournalCounts()
	return self:F("CARNET_AZ_STAMPS", counts and counts.total or 0)
end

local function SkinJournal(self, frame, reg)
	frame.azReg = reg
	Chrome(self, frame, L.JRN_TITLE)
	SkinNew(frame, reg)
	JournalNav(self, frame)
	for section, fn in pairs(PAGE) do
		local ok, err = pcall(fn, self, frame)
		if not ok and self.RecordError then self:RecordError("carnet:" .. section, err) end
	end
end

local function PostJournal(self, frame)
	Recolor(frame)
	local post = POST[frame.kind]
	if post then post(self, frame) end
	if frame.azPlate then frame.azPlate:SetCount(JournalCounter(self)) end
	-- la case de la plaque porte les points ; la colonne ne dit plus que « module coupé »
	if frame.subtitle and frame.azPlate then
		frame.subtitle:SetText(ModuleOn() and "" or (L.MODULE_OFF or ""))
	end
end

local function Stash(self, field, frame, style)
	self.uiStyleCache[field] = self.uiStyleCache[field] or {}
	self.uiStyleCache[field][style] = frame
end
-- ---------------------------------------------------------------------------
-- 2.11.0 (B8) : les confirmations du carnet au style Azeroth : parchemin,
-- encadré en bois, encres mesurées (dialog.*), bouton principal rouge. La
-- fenêtre (CompanionEffects.lua) est construite une fois par style, comme le
-- carnet : la Sobre reste telle quelle, l'Azeroth naît sous la relève.
-- ---------------------------------------------------------------------------
local function SkinDialog(self, frame, reg)
	if frame.content then frame.content.azSurface = "light" end
	SkinNew(frame, reg)
	local page = NewTex(frame, "BACKGROUND", 1, T.parchH)
	if not page then return false end
	page:SetAllPoints(frame)
	local function Fit() Cover(page, T.parchH, frame:GetWidth(), frame:GetHeight()) end
	Fit()
	if frame.HookScript then frame:HookScript("OnShow", Fit) end
	frame.azBg, frame.azSurface = page, "light"
	frame.azVeil = ns.AzerothVeil(frame, frame, "page", 2)
	if frame.bg then frame.bg:Hide() end
	HideAll(frame.border)
	if frame.footer then
		if frame.footer.bg then frame.footer.bg:Hide() end
		if frame.footer.line then
			local c = ns.AZEROTH_MISSION.rule
			frame.footer.line:SetVertexColor(c[1], c[2], c[3], 0.8)
		end
		frame.footer.azSurface = "light"
	end
	WoodBorder(frame, 6)
	local header = frame.header
	if header then
		RolePaint(header.title, "dialog.title")
		RolePaint(header.subtitle, "dialog.sub")
	end
	RolePaint(frame.text, "dialog.text")
	frame.azDialog = true
	return true
end
ns.CarnetSkinDialog = SkinDialog

do
	local ensure = ns.EnsureEffectsConfirm
	if ensure then
		function ns:EnsureEffectsConfirm(...)
			local style = self:JournalStyle()
			self.effectsConfirmByStyle = self.effectsConfirmByStyle or {}
			local cache = self.effectsConfirmByStyle
			local current = self.effectsConfirm
			if current and not current.uiStyle then current.uiStyle = "sobre"; cache.sobre = current end
			-- une question en cours garde sa fenêtre
			if current and (current.uiStyle == style or (current.IsShown and current:IsShown())) then return current end
			if cache[style] then self.effectsConfirm = cache[style]; return cache[style] end
			self.effectsConfirm = nil
			local frame
			if style == "azeroth" then
				local reg = NewReg()
				frame = CaptureRun(reg, ensure, self, ...)
				if frame then
					local ok, err = pcall(SkinDialog, self, frame, reg)
					if not ok and self.RecordError then self:RecordError("carnet:dialog", err) end
				end
			else
				frame = ensure(self, ...)
			end
			if frame then frame.uiStyle = style; cache[style] = frame end
			self.effectsConfirm = frame
			return frame
		end
	end
end

local function Cached(self, field, style)
	local slot = self.uiStyleCache and self.uiStyleCache[field]
	local frame = slot and slot[style]
	if frame then slot[style] = nil end
	return frame
end

do
	local ensure = ns.EnsureJournalWindow
	if ensure then
		function ns:EnsureJournalWindow(...)
			if self.journalFrame then return self.journalFrame end
			local style = self:JournalStyle()
			local cached = Cached(self, "journalFrame", style)
			if cached then
				self.journalFrame = cached
				-- 2.11.0 (fiche 27) : suit les choix faits dans l'autre style
				if self.JournalRestoreState then self:JournalRestoreState(cached) end
				return cached
			end
			if style ~= "azeroth" then
				local frame = ensure(self, ...)
				if frame then frame.uiStyle = "sobre" end
				return frame
			end
			local reg = NewReg()
			local frame = CaptureRun(reg, ensure, self, ...)
			if frame then
				local ok, err = pcall(SkinJournal, self, frame, reg)
				if not ok and self.RecordError then self:RecordError("carnet:azeroth", err) end
			end
			return frame
		end
	end
	local refresh = ns.RefreshJournal
	if refresh then
		function ns:RefreshJournal(...)
			local frame = self.journalFrame
			if not (frame and frame.azeroth and frame.azReg) then return refresh(self, ...) end
			local a, b = CaptureRun(frame.azReg, refresh, self, ...)
			SkinNew(frame, frame.azReg)
			local ok, err = pcall(PostJournal, self, frame)
			if not ok and self.RecordError then self:RecordError("carnet:post", err) end
			return a, b
		end
	end
end

-- 2.9.0 : le bloc « Ses effets » de la page Compagnon. Son horloge
-- (CompanionEffects.lua, chaque seconde) repeint les lignes aux couleurs
-- claires du thème, hors du passage du carnet : sur parchemin, ça restait
-- gris clair et orange pâle. Repeintes ici après elle, aux encres mesurées
-- (« effects.* ») : actifs, l'encre ; en attente, l'encre douce.
do
	local refreshPane = ns.CompanionEffectsRefreshPane
	if refreshPane then
		function ns:CompanionEffectsRefreshPane(pane, ...)
			local a, b = refreshPane(self, pane, ...)
			local frame = self.journalFrame
			if pane and frame and frame.azeroth and frame.evo == pane and pane.effHunt then
				local effects = self.CompanionEffects and self:CompanionEffects()
				local active = effects and effects.active and true or false
				local roles = active and { effHunt = "effects.line", effComfort = "effects.line", effState = "effects.state" }
					or { effHunt = "effects.linePending", effComfort = "effects.linePending", effState = "effects.statePending" }
				for field, role in pairs(roles) do
					local fs = pane[field]
					local ink = RoleInk(role)
					if fs and ink then
						Paint(fs, ink)
						NoShadow(fs)
						fs.azKeep = true
					end
				end
			end
			return a, b
		end
	end
end

-- ---------------------------------------------------------------------------
-- La fiche de dresseur Azeroth : même cadre, portrait dans le cadre à
-- volutes sur le fond des Talking Heads, chiffres sur les bandes des
-- statistiques, vitrine des hauts faits (cadres d'icône, petits boucliers)
-- ---------------------------------------------------------------------------
local function SkinTrainer(self, frame, reg)
	frame.azReg = reg
	Chrome(self, frame, L.TRAINER_TITLE)
	SkinNew(frame, reg)
	local stage = frame.stage
	if stage then
		local bg = NewTex(stage, "BACKGROUND", 1, ns.AZEROTH_PORTRAIT_BG)
		if bg then
			bg:SetPoint("TOPLEFT", stage, "TOPLEFT", 18, -18)
			bg:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -18, 18)
			if stage.bg then stage.bg:Hide() end
			HideAll(stage.border)
			stage.azBg = bg
		end
		local ring = CreateFrame("Frame", nil, stage)
		ring:SetAllPoints(stage)
		ring:SetFrameLevel(Level(stage) + 6)
		ring:EnableMouse(false)
		local vine = ring:CreateTexture(nil, "OVERLAY")
		vine:SetAllPoints(ring)
		if ns.AzerothAtlas and ns.AzerothAtlas(vine, ns.AZEROTH_ATLAS.frameRound) then
			vine:Show()
			if frame.model then
				frame.model:ClearAllPoints()
				frame.model:SetPoint("TOPLEFT", stage, "TOPLEFT", 18, -16)
				frame.model:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -18, 18)
			end
		else
			ring:Hide()
		end
		frame.azVine = vine
		stage.azSurface = "dark"
	end
	if frame.compName then AzFont(frame.compName, 15) end
	-- les cinq chiffres sur les bandes des statistiques
	frame.azBands = {}
	for index = 1, 5 do
		local line = frame.lines and frame.lines[index]
		if line and frame.body then
			local band = NewTex(frame.body, "BACKGROUND", 2, T.statRow)
			if band then
				band:SetPoint("TOPLEFT", line, "TOPLEFT", -8, 3)
				band:SetSize((ns.TRAINER_LAYOUT and 304 or 300) + 14, 17)
				if index % 2 == 1 then band:SetVertexColor(INKS.bandLift, INKS.bandLift, INKS.bandLift, 1) end
				Paint(line, LIGHT)
				Shadow(line)
				line.azKeep = true
				frame.azBands[index] = band
			end
		end
	end
	for _, card in ipairs(frame.featCards or {}) do
		card.azRing = Ring(card, card.icon, 44)
		if card.mark and SetTex(card.mark, T.tiny) then
			card.mark:SetSize(20, 18)   -- 2.9.0 : le dessin recadré, à sa taille
			card.mark:SetVertexColor(1, 1, 1, 1)
			card.azShield = true
		end
	end
end

local function PostTrainer(self, frame)
	Recolor(frame)
	local card = frame.shownCard
	local feats = card and type(card.feats) == "table" and card.feats
	local points = feats and ((tonumber(feats.account) or 0) + (tonumber(feats.char) or 0)) or 0
	if frame.azPlate then frame.azPlate:SetCount(points > 0 and self:F("CARNET_AZ_POINTS", points) or "") end
end

do
	local ensure = ns.EnsureTrainerWindow
	if ensure then
		function ns:EnsureTrainerWindow(...)
			if self.trainerFrame then return self.trainerFrame end
			local style = self:JournalStyle()
			local cached = Cached(self, "trainerFrame", style)
			if cached then
				self.trainerFrame = cached
				return cached
			end
			if style ~= "azeroth" then
				local frame = ensure(self, ...)
				if frame then frame.uiStyle = "sobre" end
				return frame
			end
			local reg = NewReg()
			local frame = CaptureRun(reg, ensure, self, ...)
			if frame then
				local ok, err = pcall(SkinTrainer, self, frame, reg)
				if not ok and self.RecordError then self:RecordError("carnet:trainer", err) end
			end
			return frame
		end
	end
	local refresh = ns.TrainerRefreshWindow
	if refresh then
		function ns:TrainerRefreshWindow(...)
			local frame = self.trainerFrame
			-- fiche fermée : le vrai rafraîchissement ne fait rien, l'habillage
			-- non plus (un changement de titre ou de vitrine l'appelle quand même)
			if not (frame and frame.azeroth and frame.azReg) or not frame:IsShown() then
				return refresh(self, ...)
			end
			local a, b = CaptureRun(frame.azReg, refresh, self, ...)
			SkinNew(frame, frame.azReg)
			local ok, err = pcall(PostTrainer, self, frame)
			if not ok and self.RecordError then self:RecordError("carnet:trainerpost", err) end
			return a, b
		end
	end
end

-- ---------------------------------------------------------------------------
-- Changement de style à chaud : la fenêtre affichée est remplacée par celle
-- du nouveau style (état recopié) ; fermée, elle le sera à l'ouverture
-- ---------------------------------------------------------------------------
local JOURNAL_STATE = { "kind", "activity", "offset", "zoneFilter", "zoneSort", "zoneOffset", "questFilter", "collKind",
	"menZone", "menState", "menRank", "menSort", "menSearch", "menType", "menOffset", "featsCat", "featsOffset",
	"zoneID", "zonePicked", "progPart", "progOffset", "progItemOffset", "guideSection", "guideOffset",
	"jukeView", "jukeOffset", "jukeSearch" }   -- 2.12.0 : Juke-box

function ns:CarnetRestyle()
	local want = self:JournalStyle()
	local swapped = {}
	local journal = self.journalFrame
	if journal and (journal.azeroth and "azeroth" or "sobre") ~= want then
		local shown = journal:IsShown()
		journal:Hide()
		Stash(self, "journalFrame", journal, journal.azeroth and "azeroth" or "sobre")
		self.journalFrame = nil
		if shown then
			local fresh = self:EnsureJournalWindow()
			if fresh then
				for _, key in ipairs(JOURNAL_STATE) do fresh[key] = journal[key] end
				if self.RefreshJournal then self:RefreshJournal() end
				if self.CloseOtherWindows then pcall(self.CloseOtherWindows, self, fresh) end
				fresh:Show()
			end
		end
		swapped.journal = true
	end
	local trainer = self.trainerFrame
	if trainer and (trainer.azeroth and "azeroth" or "sobre") ~= want then
		local shown = trainer:IsShown()
		trainer:Hide()
		Stash(self, "trainerFrame", trainer, trainer.azeroth and "azeroth" or "sobre")
		self.trainerFrame = nil
		if shown then
			local fresh = self:EnsureTrainerWindow()
			if fresh then
				fresh.viewing = trainer.viewing
				fresh:Show()
				self:TrainerRefreshWindow()
			end
		end
		swapped.trainer = true
	end
	return swapped
end

do
	local apply = ns.ApplyUIStyle
	if apply then
		function ns:ApplyUIStyle(...)
			local style = apply(self, ...)
			local ok, err = pcall(self.CarnetRestyle, self)
			if not ok and self.RecordError then self:RecordError("carnet:restyle", err) end
			return style
		end
	end
end

if ns.Mark then ns.Mark("JournalAzeroth") end
