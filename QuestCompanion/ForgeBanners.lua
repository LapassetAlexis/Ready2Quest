-- ForgeBanners.lua -- l'habillage forgé des bandeaux (3.1.0)
--
-- L'ancien habillage donnait aux bandeaux (« Capturé ! », haut fait, guilde,
-- capture possible) un médaillon, une apparition et un nom d'or pour une
-- brillante, en art du client. Le thème forgé les re-loge ici, en matières
-- du socle seulement (Theme.ART, Theme.Slice, Theme.ForgeSlice) :
--   * un MÉDAILLON rond à gauche, à cheval sur le bord du bandeau (comme la
--     maquette) : l'anneau d'or creux (Theme.ART.ring) sur un disque sombre,
--     et dedans le portrait de la créature, l'icône (arrondie par le masque
--     du client), le glyphe du filet ou le glyphe du logo ; une petite plaque
--     d'or sous l'anneau porte les points ou le niveau (le chiffre ne
--     chevauche plus jamais le texte, dont la largeur est réservée) ;
--   * l'apparition : éclosion (Scale) et éclat derrière le médaillon
--     (ART.dot), puis un trait lumineux (ART.line) qui traverse le bandeau,
--     le tout en AnimationGroup (aucun OnUpdate) ;
--   * une brillante : son nom dans sa couleur (Theme.SHINY) et un halo au
--     repos derrière le médaillon.
-- Tout est décidé à la construction du bandeau (ns.QCForged()) : un bandeau
-- né dans le Sobre n'en reçoit rien, et reste identique au pixel près.
-- Couleurs par rôle : petit titre et trait = identité (bleu arcane dans QC),
-- anneau et plaque des points = or (cadre et médaillon dorés), nom d'une
-- brillante = Theme.SHINY.
local ADDON, ns = ...
if ns.blocked then return end

local Theme = ns.Theme

-- Géométrie (px). medal : diamètre de l'anneau (Theme.ART.ring, centre
-- vide) ; out : débord hors du bord gauche ; gap : du médaillon au texte ;
-- content : diamètre du contenu rond (portrait, icône masquée en rond), sous
-- le bord intérieur de la bande d'or ; icon : icône carrée quand le client
-- n'a pas de masque rond (inscrite dans le centre de l'anneau) ; glyph :
-- glyphe du filet ; disc : disque sombre du fond, fait de trois aplats
-- (carré, deux bandes) qui tiennent sous la bande d'or ; badge : plaque des
-- points (hauteur, marge du chiffre, recouvrement de l'anneau) ; bloom :
-- éclat (× médaillon) ; halo : alpha du halo d'une brillante au repos ;
-- shine : trait qui traverse (largeur, hauteur, durée, attente) ; hatch :
-- éclosion (échelle de départ, durée).
ns.FORGE_BANNER = {
	medal = 64, out = 14, gap = 8, pad = 12, right = 12,
	content = 52, icon = 38, glyph = 32,
	disc = { square = 42, long = 52, short = 30 },
	mask = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
	badge = { h = 16, pad = 6, over = 7 },
	bloom = 2.3, bloomAlpha = 0.9, halo = 0.6,
	shine = { w = 120, h = 6, time = 1.1, delay = 0.3, alpha = 0.9 },
	hatch = { from = 0.9, time = 0.22 },
	lineGap = 2,
	-- la rangée du bouton Partager, sous les lignes (comme la maquette) :
	-- écart entre la dernière ligne et le haut du bouton
	buttonGap = 4,
}
local K = ns.FORGE_BANNER

local function Level(frame)
	return (frame and frame.GetFrameLevel and tonumber(frame:GetFrameLevel())) or 1
end

-- Le bord gauche du texte, depuis le bord gauche du bandeau
function ns.ForgeBannerTextLeft(frame)
	local size = (frame and frame.forgeMedalSize) or K.medal
	return -K.out + size + K.gap
end

-- Une animation d'alpha (0 -> to -> 0) sur une région au repos à `rest`
local function Flash(region, to, inTime, outTime, delay)
	if not (region and region.CreateAnimationGroup) then return nil end
	local ok, group = pcall(region.CreateAnimationGroup, region)
	if not ok or not group or not group.CreateAnimation then return nil end
	local up = group:CreateAnimation("Alpha")
	if not (up and up.SetFromAlpha) then return nil end
	up:SetFromAlpha(0); up:SetToAlpha(to); up:SetDuration(inTime)
	if up.SetStartDelay and delay then up:SetStartDelay(delay) end
	local down = group:CreateAnimation("Alpha")
	if down and down.SetFromAlpha then
		down:SetFromAlpha(to); down:SetToAlpha(0); down:SetDuration(outTime)
		if down.SetStartDelay then down:SetStartDelay((delay or 0) + inTime) end
		if down.SetSmoothing then down:SetSmoothing("OUT") end
	end
	group.up, group.down = up, down
	return group
end

-- L'habillage forgé d'un bandeau (Theme.CreateToast) : médaillon, éclat,
-- trait, éclosion. Seulement sous le thème forgé ; rend le bord gauche du
-- texte (ou nil, rien posé). opts.medal : diamètre de l'anneau.
function ns:ForgeBannerDress(frame, opts)
	if not (frame and ns.QCForged and ns.QCForged()) then return nil end
	if frame.forgeBanner then return ns.ForgeBannerTextLeft(frame) end
	opts = opts or {}
	local size = tonumber(opts.medal) or K.medal
	frame.forgeBanner, frame.forgeMedalSize = true, size
	-- la barre d'accent du toast passerait sous le médaillon : cachée, sa
	-- couleur reste lue (frame.accentColor) pour l'éclat
	if frame.accent then frame.accent:Hide() end
	function frame:SetAccent(color)
		if color ~= false then self.accentColor = color end
		if self.accent then self.accent:Hide() end
	end
	-- le médaillon : un cadre au-dessus de l'habillage du socle (cadre d'or
	-- du toast au niveau +30), sans souris (le clic passe au bandeau)
	local medal = CreateFrame("Frame", nil, frame)
	medal:SetSize(size, size)
	medal:SetPoint("LEFT", frame, "LEFT", -K.out, 0)
	if medal.SetFrameLevel then medal:SetFrameLevel(Level(frame) + 34) end
	if medal.EnableMouse then medal:EnableMouse(false) end
	frame.medal = medal
	-- l'éclat derrière le médaillon (au repos : éteint, ou halo d'une brillante)
	medal.bloom = medal:CreateTexture(nil, "BACKGROUND", nil, -2)
	medal.bloom:SetTexture(Theme.ART.dot.file)
	medal.bloom:SetSize(math.floor(size * K.bloom), math.floor(size * K.bloom))
	medal.bloom:SetPoint("CENTER", medal, "CENTER", 0, 0)
	if medal.bloom.SetBlendMode then medal.bloom:SetBlendMode("ADD") end
	medal.bloom:SetAlpha(0)
	medal.bloomFlash = Flash(medal.bloom, K.bloomAlpha, 0.3, 0.9, 0.05)
	-- le fond : un disque sombre (trois aplats en croix arrondie, tous sous
	-- la bande d'or ; pas besoin de masque)
	local scale = size / K.medal
	medal.disc = {}
	for index, dims in ipairs({ { K.disc.square, K.disc.square }, { K.disc.long, K.disc.short },
		{ K.disc.short, K.disc.long } }) do
		local part = medal:CreateTexture(nil, "BACKGROUND", nil, 0)
		local nav = Theme.NAV
		part:SetColorTexture(nav[1], nav[2], nav[3], 1)
		part:SetSize(math.floor(dims[1] * scale), math.floor(dims[2] * scale))
		part:SetPoint("CENTER", medal, "CENTER", 0, 0)
		medal.disc[index] = part
	end
	-- le masque rond du client (portrait et icône arrondis), s'il existe
	if medal.CreateMaskTexture then
		local ok, mask = pcall(medal.CreateMaskTexture, medal)
		if ok and mask then
			pcall(mask.SetTexture, mask, K.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetSize(math.floor(K.content * scale), math.floor(K.content * scale))
			mask:SetPoint("CENTER", medal, "CENTER", 0, 0)
			medal.mask = mask
		end
	end
	-- le portrait ou l'icône (masqués en rond ; sans masque, l'icône carrée
	-- est inscrite dans le centre de l'anneau)
	medal.icon = medal:CreateTexture(nil, "ARTWORK", nil, 1)
	medal.icon:SetSize(K.icon, K.icon)
	medal.icon:SetPoint("CENTER", medal, "CENTER", 0, 0)
	if medal.mask and medal.icon.AddMaskTexture and not pcall(medal.icon.AddMaskTexture, medal.icon, medal.mask) then
		medal.mask = nil
	end
	medal.icon:Hide()
	-- le glyphe du filet (une texture à lui : le Voile d'hiver repeint ses
	-- glyphes, jamais le portrait ni l'icône)
	medal.glyph = medal:CreateTexture(nil, "ARTWORK", nil, 1)
	medal.glyph:SetSize(math.floor(K.glyph * scale), math.floor(K.glyph * scale))
	medal.glyph:SetPoint("CENTER", medal, "CENTER", 0, 0)
	medal.glyph:Hide()
	-- le logo nu (une rafale) : le glyphe du logo, sans son anneau
	medal.logo = medal:CreateTexture(nil, "ARTWORK", nil, 1)
	medal.logo:SetTexture(Theme.LOGO_GLYPH or Theme.LOGO_SMALL)
	medal.logo:SetSize(math.floor(K.content * scale), math.floor(K.content * scale))
	medal.logo:SetPoint("CENTER", medal, "CENTER", 0, 0)
	medal.logo:Hide()
	-- l'anneau d'or creux, par-dessus le contenu (il en cache le bord)
	medal.ring = medal:CreateTexture(nil, "OVERLAY", nil, 0)
	medal.ring:SetTexture(Theme.ART.ring.file)
	medal.ring:SetAllPoints(medal)
	-- la plaque des points ou du niveau, à cheval sur le bas de l'anneau
	local badge = CreateFrame("Frame", nil, medal)
	badge:SetSize(K.badge.h * 2, K.badge.h)
	badge:SetPoint("TOP", medal, "BOTTOM", 0, K.badge.over)
	if badge.SetFrameLevel then badge:SetFrameLevel(Level(medal) + 2) end
	if badge.EnableMouse then badge:EnableMouse(false) end
	badge.plate = Theme.ForgeSlice(badge, "plate", Theme.FORGE_PLATE.gold, { layer = "BACKGROUND", sub = 0,
		margin = Theme.FORGE.marginSmall, height = K.badge.h })
	badge.text = badge:CreateFontString(nil, "OVERLAY", Theme.F_NUMBER)
	badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
	badge.text:SetJustifyH("CENTER")
	local ink = Theme.FORGE_INK.gold
	badge.text:SetTextColor(ink[1], ink[2], ink[3], 1)
	if Theme.NoShadow then Theme.NoShadow(badge.text) end
	badge:Hide()
	medal.badge = badge
	-- le trait qui traverse le bandeau, au bas de la zone du texte (tête
	-- lumineuse devant : la lueur s'efface vers la gauche)
	local textLeft = ns.ForgeBannerTextLeft(frame)
	local shine = frame:CreateTexture(nil, "ARTWORK", nil, 3)
	shine:SetTexture(Theme.ART.line.file)
	shine:SetTexCoord(1, 0, 0, 1)
	shine:SetSize(K.shine.w, K.shine.h)
	shine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", textLeft - K.shine.w, 2)
	if shine.SetBlendMode then shine:SetBlendMode("ADD") end
	shine:SetAlpha(0)
	local travel = Flash(shine, K.shine.alpha, 0.25, K.shine.time - 0.25, K.shine.delay)
	if travel then
		local move = travel:CreateAnimation("Translation")
		if move and move.SetOffset then
			local width = tonumber(frame.GetWidth and frame:GetWidth()) or 300
			move:SetOffset(width - textLeft + K.shine.w * 0.5, 0)
			move:SetDuration(K.shine.time)
			if move.SetStartDelay then move:SetStartDelay(K.shine.delay) end
			if move.SetSmoothing then move:SetSmoothing("IN_OUT") end
			travel.move = move
		end
	end
	frame.forgeShine, frame.forgeShineAnim = shine, travel
	-- l'éclosion du bandeau (si le client sait animer une échelle)
	if frame.CreateAnimationGroup then
		local ok, group = pcall(frame.CreateAnimationGroup, frame)
		local scale = ok and group and group.CreateAnimation and group:CreateAnimation("Scale")
		if scale and scale.SetScaleFrom and scale.SetScaleTo then
			scale:SetScaleFrom(K.hatch.from, K.hatch.from)
			scale:SetScaleTo(1, 1)
			scale:SetDuration(K.hatch.time)
			if scale.SetSmoothing then scale:SetSmoothing("OUT") end
			frame.forgeHatch = group
		end
	end
	-- le médaillon déborde à gauche : il reste à l'écran avec le bandeau
	if frame.SetClampRectInsets then pcall(frame.SetClampRectInsets, frame, -K.out, 0, 0, 0) end
	return textLeft
end

-- Le contenu du médaillon. what : "portrait" (target = { npcID, type,
-- shiny } : le portrait 2D de la créature, sinon l'icône de son type),
-- "icon" (texture = fichier ou id), "glyph" (paint = fonction qui peint la
-- texture medal.glyph : le glyphe du filet, la boule de neige du Voile
-- d'hiver), ou nil (le glyphe du logo). Le glyphe a sa propre texture : le
-- Voile d'hiver la repeint sans jamais toucher au portrait ni à l'icône.
-- Rend le genre posé.
function ns:ForgeMedalSet(frame, what, value)
	local medal = frame and frame.medal
	if not medal then return nil end
	local icon, glyph = medal.icon, medal.glyph
	local kind = nil
	if what == "portrait" and type(value) == "table" and ns.CreaturePortrait then
		kind = ns:CreaturePortrait(icon, value)
	elseif what == "icon" and value then
		icon:SetTexture(value)
		if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
		kind = "icon"
	elseif what == "glyph" and type(value) == "function" then
		value(glyph)
		kind = "glyph"
	end
	local scale = (frame.forgeMedalSize or K.medal) / K.medal
	if kind == "portrait" or kind == "icon" then
		if icon.SetVertexColor then icon:SetVertexColor(1, 1, 1, 1) end
		-- un portrait du client est déjà rond ; une icône l'est par le masque
		local side = (kind == "portrait" or medal.mask) and K.content or K.icon
		icon:SetSize(math.floor(side * scale), math.floor(side * scale))
		icon:Show()
	end
	if kind == "glyph" then glyph:Show() else glyph:Hide() end
	if kind ~= "portrait" and kind ~= "icon" then icon:Hide() end
	if medal.logo then
		if kind then medal.logo:Hide() else medal.logo:Show() end
	end
	medal.kind = kind
	return kind
end

-- La plaque des points ou du niveau (nil, 0 ou vide : cachée)
function ns:ForgeMedalBadge(frame, value)
	local badge = frame and frame.medal and frame.medal.badge
	if not badge then return nil end
	local n = tonumber(value)
	if not n or n <= 0 then
		badge.text:SetText("")
		badge:Hide()
		return nil
	end
	local text = tostring(math.floor(n))
	badge.text:SetText(text)
	local w = Theme.TextWidth and Theme.TextWidth(badge, text, Theme.F_NUMBER) or (#text * 7)
	badge:SetWidth(math.max(K.badge.h * 2, math.ceil(tonumber(w) or 14) + 2 * K.badge.pad))
	badge:Show()
	return text
end

-- Empile les lignes de texte du bandeau (champs `keys` de frame, cachées si
-- vides) de haut en bas, centrées dans la hauteur ; la hauteur du bandeau
-- suit (au moins `minH`). La largeur de chaque ligne ne change pas. Le
-- bouton Partager a sa propre rangée, en bas à droite, sous les lignes
-- (frame.forgeBottomReserve, posé par Share.lua) : il ne prend la largeur
-- d'aucune ligne. Les clés et la hauteur minimale sont retenues
-- (frame.forgeStack) pour réempiler quand le bouton paraît ou s'en va.
function ns:ForgeBannerStack(frame, keys, minH)
	if not (frame and frame.forgeBanner) then return nil end
	frame.forgeStack = { keys = keys, minH = minH }
	local textLeft = ns.ForgeBannerTextLeft(frame)
	local heights, total = {}, 0
	for index, key in ipairs(keys) do
		local fs = frame[key]
		local text = fs and fs.GetText and fs:GetText()
		if fs and text and text ~= "" then
			local font = fs.forgeFont or Theme.F_BODY
			local width = tonumber(fs.GetWidth and fs:GetWidth()) or 200
			local h = math.max(1, math.ceil(tonumber(Theme.TextHeight(fs, width, font)) or 12))
			-- (une ligne bornée en lignes : jamais plus haute que ses lignes)
			if fs.forgeMaxLines then
				local one = math.max(1, math.ceil(tonumber(Theme.TextHeight(fs, 100000, font)) or 12))
				h = math.min(h, one * fs.forgeMaxLines)
			end
			heights[index] = h
			total = total + h + (total > 0 and K.lineGap or 0)
			fs:Show()
		elseif fs then
			fs:Hide()
		end
	end
	local reserve = tonumber(frame.forgeBottomReserve) or 0
	local height, y
	if reserve > 0 then
		-- les lignes au-dessus de la rangée du bouton
		height = math.max(tonumber(minH) or 0, K.pad + total + K.buttonGap + reserve)
		y = math.max(K.pad, math.floor((height - reserve - K.buttonGap - total) / 2 + 0.5))
	else
		height = math.max(tonumber(minH) or 0, total + 2 * K.pad)
		y = math.floor((height - total) / 2 + 0.5)
	end
	for index, key in ipairs(keys) do
		local fs = frame[key]
		if fs and heights[index] then
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, -y)
			y = y + heights[index] + K.lineGap
		end
	end
	if frame.SetHeight and tonumber(frame:GetHeight()) ~= height then frame:SetHeight(height) end
	return height
end

-- Une ligne de texte d'un bandeau forgé (police retenue pour la mesure) ;
-- lines : 2 pour une ligne qui passe sur deux lignes au plus, coupée aux
-- mots (sinon une seule ligne, coupée par des points de suspension)
function ns.ForgeBannerLine(frame, font, color, width, lines)
	local fs = Theme.Text(frame, font, color)
	fs:SetJustifyH("LEFT")
	fs:SetWidth(width)
	fs.forgeFont = font
	if tonumber(lines) and lines > 1 then
		if fs.SetWordWrap then fs:SetWordWrap(true) end
		if fs.SetMaxLines then pcall(fs.SetMaxLines, fs, lines) end
		fs.forgeMaxLines = lines
	elseif fs.SetWordWrap then
		fs:SetWordWrap(false)
	end
	return fs
end

-- Après avoir rempli un bandeau forgé (ns:StyleShown) : petit titre en
-- couleur d'identité, nom (or des brillantes), halo, apparition.
-- opts : shiny, play
function ns:ForgeBannerShown(frame, opts)
	if not (frame and frame.forgeBanner) then return false end
	opts = opts or {}
	local title, text = frame.title, frame.text
	local id = Theme.IDENTITY_LIGHT
	if title then title:SetTextColor(id[1], id[2], id[3], 1) end
	local name = opts.shiny and Theme.SHINY or Theme.PARCHMENT
	if text then text:SetTextColor(name[1], name[2], name[3], 1) end
	local medal = frame.medal
	local glow = opts.shiny and Theme.SHINY or Theme.IDENTITY
	if medal and medal.bloom then
		medal.bloom:SetVertexColor(glow[1], glow[2], glow[3], 1)
		medal.bloom:SetAlpha(opts.shiny and K.halo or 0)
		if medal.bloomFlash and medal.bloomFlash.up then
			local rest = opts.shiny and K.halo or 0
			medal.bloomFlash.up:SetFromAlpha(rest)
			if medal.bloomFlash.down then medal.bloomFlash.down:SetToAlpha(rest) end
		end
	end
	local shine = frame.forgeShine
	if shine then
		local c = opts.shiny and Theme.SHINY or Theme.IDENTITY_LIGHT
		shine:SetVertexColor(c[1], c[2], c[3], 1)
	end
	if opts.play then
		-- (une pièce peut manquer : client sans Scale, par exemple)
		local groups = { frame.forgeHatch or false, medal and medal.bloomFlash or false, frame.forgeShineAnim or false }
		for index = 1, #groups do
			local group = groups[index]
			if group then group:Stop(); group:Play() end
		end
		frame.forgePlays = (frame.forgePlays or 0) + 1
	end
	return true
end

-- ---------------------------------------------------------------------------
-- « Capturé ! » / « Brillant capturé ! » (ns:EnsureCaptureResult) : le
-- portrait 2D de la créature dans le médaillon, son niveau sur la plaque,
-- les étoiles puis la taille et le caractère du spécimen. Même file, même
-- horloge, même bouton Partager que le bandeau du Sobre.
-- ---------------------------------------------------------------------------
ns.FORGE_RESULT = { w = 360, h = 78 }

-- glyph : la fonction qui peint le glyphe du filet (boule de neige comprise)
function ns:ForgeCaptureResult(glyph)
	if not (ns.QCForged and ns.QCForged() and Theme.CreateToast) then return nil end
	local R = ns.FORGE_RESULT
	local frame = Theme.CreateToast(UIParent, R.w, R.h, { strata = "HIGH", accent = Theme.GOLD,
		name = ns.StyleName and ns.StyleName("QuestCompanionCaptureResult", "forge") or nil })
	if not frame then return nil end
	frame.uiStyle = "sobre"
	local left = self:ForgeBannerDress(frame)
	if not left then return frame end
	local width = R.w - left - K.right
	frame.title = ns.ForgeBannerLine(frame, Theme.F_CAPS, Theme.IDENTITY_LIGHT, width)
	frame.text = ns.ForgeBannerLine(frame, Theme.F_TITLE, Theme.PARCHMENT, width)
	frame.stars = ns.ForgeBannerLine(frame, Theme.F_SMALL, Theme.GOLD, width, 2)
	frame.forgeGlyph = glyph
	frame.icon = frame.medal.glyph
	self:ForgeMedalSet(frame, "glyph", glyph)
	return frame
end

-- Remplit le médaillon et la ligne des étoiles (avant l'affichage)
function ns:ForgeCaptureResultFill(frame, result, line)
	if not (frame and frame.forgeBanner and type(result) == "table") then return nil end
	if result.npcID then
		self:ForgeMedalSet(frame, "portrait", { npcID = result.npcID, type = result.type, shiny = result.shiny })
	else
		self:ForgeMedalSet(frame, "glyph", frame.forgeGlyph)
	end
	self:ForgeMedalBadge(frame, result.level)
	-- les étoiles, la taille et le caractère, puis « et N de plus »
	local parts = {}
	local stars = (result.stars and self.CaptureStarsText) and self:CaptureStarsText(result.stars, 14) or ""
	if stars ~= "" then parts[#parts + 1] = stars end
	local tags = (result.specimen and self.SpecimenTagsShort) and self:SpecimenTagsShort(result.specimen) or ""
	if tags ~= "" then parts[#parts + 1] = tags end
	if (tonumber(result.more) or 0) > 0 then parts[#parts + 1] = self:F("CAPTURE_RESULT_MORE", result.more) end
	if #parts > 0 then frame.stars:SetText(table.concat(parts, "  ·  ")) else frame.stars:SetText(line or "") end
	self:ForgeBannerStack(frame, { "title", "text", "stars" }, ns.FORGE_RESULT.h)
	return frame.medal.kind
end

-- ---------------------------------------------------------------------------
-- Bandeau du carnet (ns:EnsureJournalToast) : tampons, rafale, sceaux de
-- zone, titres de dresseur, « Haut fait obtenu ». L'icône de la catégorie
-- dans le médaillon (le logo nu sinon), les points sur sa plaque, la
-- sous-ligne « Nouveau titre : X » ; la hauteur suit les lignes.
-- ---------------------------------------------------------------------------
ns.FORGE_JOURNAL = { w = 330, h = 70 }

function ns:ForgeJournalToast()
	if not (ns.QCForged and ns.QCForged() and Theme.CreateToast) then return nil end
	local J = ns.FORGE_JOURNAL
	local frame = Theme.CreateToast(UIParent, J.w, J.h)
	if not frame then return nil end
	frame.uiStyle = "sobre"
	local left = self:ForgeBannerDress(frame)
	if not left then return frame end
	local width = J.w - left - K.right
	frame.title = ns.ForgeBannerLine(frame, Theme.F_CAPS, Theme.IDENTITY_LIGHT, width)
	frame.text = ns.ForgeBannerLine(frame, Theme.F_TITLE, Theme.PARCHMENT, width)
	-- (« Nouveau titre : … » : deux lignes au plus, jamais coupée)
	frame.stars = ns.ForgeBannerLine(frame, Theme.F_SMALL, Theme.GOLD_LIGHT, width, 2)
	frame.icon = frame.medal.icon
	self:ForgeMedalSet(frame, nil)
	return frame
end

-- L'habillage d'une entrée (Journal.lua, ToastDecor) : icône, points,
-- sous-ligne, hauteur. entry nil : une rafale (le logo, rien d'autre).
function ns:ForgeJournalToastFill(frame, entry)
	if not (frame and frame.forgeBanner) then return nil end
	if entry and entry.icon then self:ForgeMedalSet(frame, "icon", entry.icon) else self:ForgeMedalSet(frame, nil) end
	self:ForgeMedalBadge(frame, entry and entry.points)
	-- (le Sobre et l'ancien habillage lisent frame.featPoints : ici, la plaque)
	frame.featPoints = nil
	frame.stars:SetText((entry and entry.sub) or "")
	self:ForgeBannerStack(frame, { "title", "text", "stars" }, ns.FORGE_JOURNAL.h)
	return true
end

-- ---------------------------------------------------------------------------
-- Bandeau de guilde (ns:EnsureGuildFeatToast) : « GUILDE », la ligne sur
-- deux lignes au besoin (coupée aux mots), la créature, « et N autres
-- exploits » ; le médaillon porte l'icône d'un haut fait et ses points (ils
-- ne chevauchent plus le texte), le glyphe du filet sinon.
-- ---------------------------------------------------------------------------
ns.FORGE_GUILD = { w = 380, h = 78 }

-- glyph : la fonction qui peint le glyphe du filet
function ns:ForgeGuildFeatToast(glyph)
	if not (ns.QCForged and ns.QCForged() and Theme.CreateToast) then return nil end
	local G = ns.FORGE_GUILD
	local frame = Theme.CreateToast(UIParent, G.w, G.h, { strata = "HIGH", accent = Theme.GOLD,
		name = ns.StyleName and ns.StyleName("QuestCompanionGuildFeat", "forge") or nil })
	if not frame then return nil end
	frame.uiStyle = "sobre"
	local left = self:ForgeBannerDress(frame)
	if not left then return frame end
	local width = G.w - left - K.right
	frame.title = ns.ForgeBannerLine(frame, Theme.F_CAPS, Theme.IDENTITY_LIGHT, width)
	-- la ligne « Xan a capturé… » : deux lignes au plus, coupées aux mots
	frame.text = ns.ForgeBannerLine(frame, Theme.F_TITLE, Theme.PARCHMENT, width, 2)
	frame.info = ns.ForgeBannerLine(frame, Theme.F_SMALL, Theme.TEXT, width)
	frame.hint = ns.ForgeBannerLine(frame, Theme.F_SMALL, Theme.MUTED_LIGHT, width)
	frame.forgeGlyph = glyph
	frame.icon = frame.medal.glyph
	self:ForgeMedalSet(frame, "glyph", glyph)
	return frame
end

-- L'habillage d'un exploit (GuildFeats.lua, GuildFeatDecor) : icône et
-- points d'un haut fait, glyphe sinon ; lignes empilées, hauteur
function ns:ForgeGuildFeatFill(frame, info, feat)
	if not (frame and frame.forgeBanner) then return nil end
	if feat and info and info.icon then self:ForgeMedalSet(frame, "icon", info.icon)
	else self:ForgeMedalSet(frame, "glyph", frame.forgeGlyph) end
	self:ForgeMedalBadge(frame, feat and info and info.points or nil)
	frame.featPoints = nil
	self:ForgeBannerStack(frame, { "title", "text", "info", "hint" }, ns.FORGE_GUILD.h)
	return true
end
