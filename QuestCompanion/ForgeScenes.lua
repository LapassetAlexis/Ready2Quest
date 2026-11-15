-- ForgeScenes.lua -- les scènes de capture au thème forgé (QuestCompanion 3.1.0)
--
-- L'ancien habillage des scènes (bois, parchemin, bandeau et bouclier des
-- hauts faits, cadres d'icône dorés : AzerothStyle.lua) est coupé dans le
-- produit. Ses FONCTIONS sont re-logées ici en matières forgées du socle
-- (Theme.ART : cadre, plaque, creux, lueurs) ; aucun art du client pour
-- l'habillage. Les icônes du jeu (portrait, aides, filet) restent : c'est du
-- contenu ; un effet qui venait d'un atlas des hauts faits (lueur, éclat,
-- reflet) le joue si le client l'a, sinon notre point lumineux (ART.dot).
--   * la carte d'un lancer seul : habit de carte du socle (DressWindow, coins
--     et bords assombris), plaque de titre « CAPTURE · <RANG> » et le nom, et
--     le verdict DANS la scène (ns:ForgeVerdict, même interface que
--     ns:AzerothVerdict : l'animation Verdict() de CaptureStage.lua le joue
--     telle quelle) : portrait en creux, « CAPTURÉ ! » ou « ÉCHAPPÉ… », le nom
--     ou la phrase, les étoiles, le niveau sur une plaque d'or (grise à
--     l'échec), lueur, éclat, reflet d'une brillante ; le bandeau « Capturé ! »
--     d'après ne s'ajoute pas, le bouton Partager va dans le coin ;
--   * la carte de préparation : les aides en petites plaques (choisie :
--     plaque de la sélection ; conseillée : lueur d'or) ;
--   * la volée « Tout capturer » : plaque du titre et du compteur, « Aide : »,
--     creux autour de la créature, badge d'étoiles au coin d'une prise ;
--   * le choix au filet : le compte, le temps en pause, « Capturer : X » en
--     principal doré avec sa ligne (brillante, chance), « Tout capturer (N) »
--     en second avec ce que coûte chaque essai, les raccourcis, posé à côté
--     du filet.
-- Tout est décidé à la création du cadre (ns.QCForged()) ; en Sobre, rien
-- d'ici n'est appelé.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

-- ---------------------------------------------------------------------------
-- Géométrie (px). stage : la carte d'un lancer seul (la disposition Sobre,
-- la plaque de titre en plus : la scène descend de 6) ; verdict : le bandeau
-- du verdict, posé sur la chance et les aides ; batch : la volée ; chooser :
-- le choix au filet.
-- ---------------------------------------------------------------------------
ns.FORGE_SCENE = {
	stage = { w = 340, h = 372, plateW = 252, plateH = 44, plateY = -10, titleY = -7, nameY = -21, sceneY = -58,
		footer = 11, dots = 10, dotsY = -2, infoY = -24, aidsY = -46, aid = 24, aidStep = 52, verdictBite = 8,
		nameMax = 15, nameMin = 10 },
	verdict = { w = 304, h = 84, frame = 12, portrait = 56, portraitX = 12, levelW = 36, levelH = 40, levelX = 12,
		titleY = -12, ruleY = -25, ruleW = 64, nameY = -31, lineY = -56, nameMax = 16, nameMin = 11, glow = 1.6,
		shineAlpha = 0.55 },
	-- la plaque d'une aide (carte et choix)
	aid = { margin = 5, pad = 3, glow = 2.8 },
	batch = { plateW = 252, plateH = 44, plateY = -10, titleY = -7, counterY = -20, aidY = -62, head = 82,
		inset = 2, badgeW = 22, badgeH = 20, badgeX = 4, badgeY = 4, cols = 3 },
	chooser = { w = 272, glyph = 32, glyphY = -12, textX = 56, titleY = -12, pausedY = -28, oneY = -64, allY = -112,
		buttonH = 28, subGap = 3, aidsY = -164, hintY = -198, h = 232, gap = 14 },
}
local K = ns.FORGE_SCENE

-- Les encres du verdict (rôles du socle, lus au moment de peindre) : titre
-- d'identité, rouge d'un échec, nom clair, or d'une brillante, phrase adoucie,
-- chiffre sombre sur l'or, clair sur l'ardoise
function ns.ForgeSceneInks()
	return {
		title = Theme.TITLE, fail = Theme.RED, name = Theme.PARCHMENT, shiny = Theme.GOLD_LIGHT,
		phrase = Theme.MUTED_LIGHT, levelGold = Theme.FORGE_INK.gold, levelGrey = Theme.LABEL,
		caption = Theme.IDENTITY_LIGHT, sub = Theme.MUTED_LIGHT, hint = Theme.MUTED_LIGHT, chosen = Theme.SELECT_LIGHT,
	}
end

local function Method(obj, name, ...)
	if obj and type(obj[name]) == "function" then return pcall(obj[name], obj, ...) end
	return false
end
local function Tint(region, c, alpha) if region and c then region:SetVertexColor(c[1], c[2], c[3], alpha or 1) end end
local function Paint(fs, c) if fs and c then fs:SetTextColor(c[1], c[2], c[3], 1) end end

-- Largeur du texte, sans la borne de la largeur posée
local function Measure(fs)
	local ok, w
	if fs.GetUnboundedStringWidth then ok, w = pcall(fs.GetUnboundedStringWidth, fs) end
	if not (ok and tonumber(w)) and fs.GetStringWidth then ok, w = pcall(fs.GetStringWidth, fs) end
	return (ok and tonumber(w)) or 0
end
-- Rapetisse la police (celle du texte, sinon celle des titres du thème)
-- jusqu'à ce qu'il tienne dans `width` ; au plus petit, la largeur fixe le
-- coupe. Rend la taille retenue.
function ns.ForgeSceneFit(fs, width, maxSize, minSize)
	if not fs then return nil end
	local file, _, flags
	if fs.GetFont then file, _, flags = fs:GetFont() end
	file = file or Theme.FONT_TITLE
	local size = maxSize
	if file and fs.SetFont then
		while true do
			pcall(fs.SetFont, fs, file, size, flags or "")
			if Measure(fs) <= width or size <= minSize then break end
			size = size - 1
		end
	end
	fs:SetWidth(width)
	if fs.SetWordWrap then fs:SetWordWrap(false) end
	fs.fitSize = size
	return size
end

-- Un effet lumineux : l'atlas des hauts faits s'il est dans le client, sinon
-- notre point lumineux (ART.dot), teint de `color`. Fusion additive.
local function Glow(parent, layer, sub, atlas, color, w, h)
	local tex = parent:CreateTexture(nil, layer, nil, sub)
	local done = false
	if atlas and tex.SetAtlas and ns.AzerothHasAtlas and ns.AzerothHasAtlas(atlas) then
		local ok, result = pcall(tex.SetAtlas, tex, atlas)
		done = ok and result ~= false
	end
	if not done then
		tex:SetTexture(Theme.ART.dot.file)
		Tint(tex, color, 1)
	end
	tex.clientArt = done or nil
	tex:SetSize(w, h or w)
	if tex.SetBlendMode then pcall(tex.SetBlendMode, tex, "ADD") end
	return tex
end
ns.ForgeSceneGlow = Glow

-- ---------------------------------------------------------------------------
-- La fenêtre d'une scène : bandeau du socle (fond, ombre, cadre d'orfèvre)
-- habillé en CARTE (coins, bords assombris : Theme.DressWindow refuse les
-- coins à un bandeau, d'où la taille posée après coup), sans la barre
-- d'accent du Sobre (le cadre la remplace). Jamais frame.azeroth.
-- ---------------------------------------------------------------------------
function ns.ForgeSceneWindow(width, height, opts)
	opts = opts or {}
	-- 1 × 1 : sous la taille minimale, l'habillage attend la vraie taille
	local frame = Theme.CreateToast(UIParent, 1, 1, { strata = opts.strata or "DIALOG", name = opts.name, accent = opts.accent })
	if not frame then return nil end
	frame.chrome = "card"
	frame:SetSize(width, height)
	pcall(Theme.DressWindow, frame)
	if frame.SetAccent then frame:SetAccent(false) end
	frame.uiStyle, frame.forged = "sobre", true
	return frame
end

-- La plaque d'un titre (une découpe de ART.plate posée sur la fenêtre même,
-- sous ses textes ; teinte froide de l'en-tête : FORGE_HEADER.warm, l'identité)
-- autour d'un cadre vide qui sert d'ancre. Rend l'ancre (.slice : la plaque).
function ns.ForgeTitlePlate(frame, width, height, y)
	local anchor = CreateFrame("Frame", nil, frame)
	anchor:SetSize(width, height)
	anchor:SetPoint("TOP", frame, "TOP", 0, y)
	if anchor.EnableMouse then anchor:EnableMouse(false) end
	anchor.slice = Theme.ForgeSlice(frame, "plate", Theme.FORGE_HEADER.warm, { layer = "BORDER", sub = 1,
		height = height, around = anchor })
	anchor.tint = Theme.FORGE_HEADER.warm
	return anchor
end

-- Un creux (ART.inset) autour de `around`, posé sur `frame` ; son filet du
-- bas prend `rim` (or patiné par défaut)
function ns.ForgeInset(frame, around, out, rim, layer, sub)
	local c = rim or (ns.QC_FORGE and ns.QC_FORGE.rim) or Theme.EDGE
	local slice = Theme.Slice(frame, "inset", { layer = layer or "BORDER", sub = sub or 0, out = out or 0,
		margin = Theme.FORGE_INSET.margin, around = around })
	if slice then slice:SetColor(c[1], c[2], c[3], 1) end
	return slice
end

-- ---------------------------------------------------------------------------
-- Le verdict d'un lancer seul, au thème forgé : la MÊME interface que
-- ns:AzerothVerdict (area, title, text, line, lineY, shield + SetShield,
-- glow, bling, shine, SetCreature, SetLevel, Fit, azScale), pour que
-- l'animation Verdict() de CaptureStage.lua le joue sans changement.
-- banner.verdict (et non .azeroth) le désigne ; banner:Paint(ok, shiny) pose
-- les encres du thème après les textes.
--   fond sombre (NAV) dans un cadre d'orfèvre (ART.frame) ;
--   à gauche : le portrait de la créature dans un creux ;
--   au centre : « CAPTURÉ ! » / « ÉCHAPPÉ… », un filet lumineux, le nom (ou
--   la phrase), les étoiles du spécimen (posées par la scène sur lineY) ;
--   à droite : le niveau, sur une plaque d'or (ardoise à l'échec) ;
--   derrière : la lueur ; sur la plaque : l'éclat ; d'un bord à l'autre :
--   le reflet d'une brillante (rogné au bandeau).
-- ---------------------------------------------------------------------------
function ns:ForgeVerdict(parent, width, height)
	local V = K.verdict
	width, height = width or V.w, height or V.h
	local area = CreateFrame("Frame", nil, parent)
	area:SetSize(width, height)
	local banner = CreateFrame("Frame", nil, area)
	banner:SetSize(width, height)
	banner:SetPoint("CENTER", area, "CENTER", 0, 0)
	banner.area, banner.verdict, banner.azScale = area, true, 1
	local A = ns.AZEROTH_ATLAS or {}
	local inks = ns.ForgeSceneInks()
	-- la lueur, derrière tout (identité)
	banner.glow = Glow(banner, "BACKGROUND", -1, A.glow, Theme.IDENTITY, width * 1.34, height * V.glow)
	banner.glow:SetPoint("CENTER", banner, "CENTER", 0, 0)
	banner.glow:SetAlpha(0)
	banner.bg = banner:CreateTexture(nil, "BACKGROUND", nil, 0)
	banner.bg:SetTexture(Theme.SOLID)
	Tint(banner.bg, Theme.NAV, 0.96)
	banner.bg:SetAllPoints(banner)
	banner.frameSlice = Theme.Slice(banner, "frame", { layer = "BORDER", sub = 0, fill = false, margin = V.frame })
	-- le portrait, en creux
	banner.portraitAnchor = CreateFrame("Frame", nil, banner)
	banner.portraitAnchor:SetSize(V.portrait, V.portrait)
	banner.portraitAnchor:SetPoint("LEFT", banner, "LEFT", V.portraitX, 0)
	banner.portraitInset = ns.ForgeInset(banner, banner.portraitAnchor, 0, nil, "BORDER", 1)
	banner.portraitIcon = banner:CreateTexture(nil, "ARTWORK", nil, 1)
	banner.portraitIcon:SetPoint("TOPLEFT", banner.portraitAnchor, "TOPLEFT", 4, -4)
	banner.portraitIcon:SetPoint("BOTTOMRIGHT", banner.portraitAnchor, "BOTTOMRIGHT", -4, 4)
	banner.portraitIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	banner.portraitIcon:Hide()
	-- le niveau, sur sa plaque (« bouclier » de l'interface d'AzerothVerdict)
	-- (la petite plaque d'or commune, ns.ForgeGoldBadge de ForgeBanners.lua)
	local shield = ns.ForgeGoldBadge(banner, V.levelW, V.levelH, Theme.F_TITLE, { ink = inks.levelGold })
	shield:SetPoint("RIGHT", banner, "RIGHT", -V.levelX, 0)
	banner.shield = shield
	banner.levelText = shield.text
	banner.levelText:SetText("")
	banner.levelText:Hide()
	-- l'éclat, sur la plaque d'or (au-dessus d'elle)
	banner.blingHost = CreateFrame("Frame", nil, banner)
	banner.blingHost:SetAllPoints(banner)
	banner.blingHost:SetFrameLevel((banner:GetFrameLevel() or 1) + 3)
	if banner.blingHost.EnableMouse then banner.blingHost:EnableMouse(false) end
	banner.bling = Glow(banner.blingHost, "OVERLAY", 2, A.bling, Theme.GOLD_LIGHT, 100)
	banner.bling:SetPoint("CENTER", shield, "CENTER", 0, 0)
	banner.bling:Hide()
	-- le reflet d'une brillante : rogné au bandeau
	banner.shineClip = CreateFrame("Frame", nil, banner)
	banner.shineClip:SetAllPoints(banner)
	banner.shineClip:SetFrameLevel((banner:GetFrameLevel() or 1) + 2)
	if banner.shineClip.EnableMouse then banner.shineClip:EnableMouse(false) end
	Method(banner.shineClip, "SetClipsChildren", true)
	banner.shine = Glow(banner.shineClip, "OVERLAY", 1, A.shine, Theme.WHITE, 60, height * 0.8)
	if not banner.shine.clientArt then Tint(banner.shine, Theme.WHITE, V.shineAlpha) end
	banner.shine:Hide()
	-- les textes, centrés entre le portrait et la plaque
	local left = V.portraitX + V.portrait + 8
	local right = V.levelX + V.levelW + 8
	local cx = math.floor((left - right) / 2)
	banner.nameW = width - left - right
	banner.title = banner:CreateFontString(nil, "OVERLAY", Theme.F_CAPS)
	banner.title:SetPoint("TOP", banner, "TOP", cx, V.titleY)
	banner.title:SetJustifyH("CENTER")
	banner.title:SetWidth(banner.nameW)
	if banner.title.SetWordWrap then banner.title:SetWordWrap(false) end
	Paint(banner.title, inks.title)
	-- le filet lumineux sous le titre, du centre vers les bords (identité)
	banner.ruleL = ns.QCForgeLine(banner, "ARTWORK", true)
	banner.ruleR = ns.QCForgeLine(banner, "ARTWORK", false)
	if banner.ruleL and banner.ruleR then
		banner.ruleL:SetWidth(V.ruleW); banner.ruleR:SetWidth(V.ruleW)
		banner.ruleL:SetPoint("RIGHT", banner, "TOP", cx, V.ruleY)
		banner.ruleR:SetPoint("LEFT", banner, "TOP", cx, V.ruleY)
	end
	banner.text = banner:CreateFontString(nil, "OVERLAY", Theme.F_TITLE)
	banner.text:SetPoint("TOP", banner, "TOP", cx, V.nameY)
	banner.text:SetJustifyH("CENTER")
	banner.text:SetWidth(banner.nameW)
	if banner.text.SetWordWrap then banner.text:SetWordWrap(false) end
	Paint(banner.text, inks.name)
	Theme.TextShadow(banner.text)
	banner.lineY = V.lineY
	banner.line = banner:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	banner.line:SetPoint("TOP", banner, "TOP", cx, banner.lineY)
	banner.line:SetJustifyH("CENTER")
	banner.line:SetWidth(banner.nameW)
	banner.line:Hide()
	function banner:SetShield(kind)
		local tint = kind == "gold" and Theme.FORGE_PLATE.gold or (kind == "grey" and Theme.FORGE_PLATE.neutral) or nil
		if not tint then
			self.shieldKind = nil
			self.shield:Hide()
			return nil
		end
		self.shield.slice:SetColor(tint[1], tint[2], tint[3], 1)
		local c = kind == "gold" and inks.levelGold or inks.levelGrey
		Paint(self.levelText, c)
		if kind == "gold" then Theme.NoShadow(self.levelText) else Theme.TextShadow(self.levelText) end
		self.shield:Show()
		self.shieldKind = kind
		return kind
	end
	function banner:SetCreature(target)
		local icon = self.portraitIcon
		self.portraitNpc = target and tonumber(target.npcID or target.npc) or nil
		if not target then icon:Hide(); return false end
		if ns.CreaturePortrait then
			ns:CreaturePortrait(icon, target)
		else
			local types = ns.MENAGERIE_TYPE_ICONS
			icon:SetTexture((types and types[target.type or ""]) or "Interface\\Icons\\Ability_Hunter_BeastTaming")
		end
		icon:Show()
		return true
	end
	function banner:SetLevel(value)
		local n = tonumber(value)
		local fs = self.levelText
		if n and n > 0 and self.shield:IsShown() then
			fs:SetText(tostring(math.floor(n)))
			fs:Show()
		else
			fs:SetText("")
			fs:Hide()
		end
		return fs:GetText()
	end
	-- les encres du thème, après les textes de Verdict() : titre d'identité
	-- (rouge à l'échec), nom clair (or d'une brillante), phrase adoucie
	function banner:Paint(ok, shiny)
		Paint(self.title, ok and inks.title or inks.fail)
		if ok then Paint(self.text, shiny and inks.shiny or inks.name) else Paint(self.text, inks.phrase) end
		local rule = ok and Theme.IDENTITY or Theme.RED
		if self.ruleL then Tint(self.ruleL, rule, ns.QC_FORGE.line.alpha); Tint(self.ruleR, rule, ns.QC_FORGE.line.alpha) end
	end
	function banner:Fit()
		ns.ForgeSceneFit(self.title, self.nameW, 10, 9)
		return ns.ForgeSceneFit(self.text, self.nameW, V.nameMax, V.nameMin)
	end
	banner:Hide()
	return banner
end

-- ---------------------------------------------------------------------------
-- Une case d'aide (carte d'un lancer seul et de préparation) en petite
-- plaque : neutre au repos, plaque de la sélection pour l'aide choisie,
-- éteinte quand il n'en reste pas ; l'aide conseillée a une lueur d'or
-- (cell.glow, la même que la case Sobre : montrée ou cachée par la carte).
-- cell.edge reste (les tests et la carte le teintent) mais invisible.
-- ---------------------------------------------------------------------------
function ns.ForgeAidCell(details, cell, size)
	local A = K.aid
	cell.edge:SetAlpha(0)
	cell.plate = Theme.Slice(details, "plate", { layer = "ARTWORK", sub = -1, margin = A.margin, out = A.pad,
		around = cell.icon })
	cell.forged = true
	function cell:forgeLook(state)
		local P = Theme.FORGE_PLATE
		local tint = P.neutral
		if state == "chosen" then tint = P.select
		elseif state == "off" then tint = P.disabled end
		self.forgeState = state
		if self.plate then self.plate:SetColor(tint[1], tint[2], tint[3], 1) end
	end
	cell:forgeLook("rest")
	return cell
end

-- La lueur de l'aide conseillée (préparation) : notre point lumineux, d'or
function ns.ForgeAidGlow(details, cell, size)
	local glow = Theme.ForgeGlow(details, cell.edge, Theme.GOLD_LIGHT, math.floor((size or 24) * K.aid.glow), "BACKGROUND", 1, 1)
	return glow
end

-- ---------------------------------------------------------------------------
-- La volée : le badge d'étoiles au coin d'une prise (petite plaque d'or, le
-- chiffre à l'encre sombre) et le creux autour de la créature
-- ---------------------------------------------------------------------------
function ns.ForgeTileDress(tile)
	local B = K.batch
	tile.forged = true
	tile.inset = ns.ForgeInset(tile, tile.scene, B.inset, nil, "BORDER", -1)
	local badge = ns.ForgeGoldBadge(tile.fx or tile, B.badgeW, B.badgeH, Theme.F_NUMBER or Theme.F_LABEL)
	badge:SetPoint("TOPRIGHT", tile, "TOPRIGHT", B.badgeX, B.badgeY)
	badge:SetFrameLevel(((tile.fx or tile):GetFrameLevel() or 1) + 2)
	tile.badge = badge
	return tile
end

-- Le badge au verdict : le nombre d'étoiles d'une prise ; caché sinon
function ns.ForgeTileBadge(tile, result)
	local badge = tile and tile.badge
	if not badge then return nil end
	if result and result.success then
		badge.text:SetText(tostring(math.max(1, math.floor(tonumber(result.stars) or 1))))
		badge:Show()
		return badge.text:GetText()
	end
	badge.text:SetText("")
	badge:Hide()
	return nil
end

if ns.Mark then ns.Mark("ForgeScenes") end
