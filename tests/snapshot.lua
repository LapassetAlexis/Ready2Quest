-- tests/snapshot.lua -- aperçu hors-jeu d'une fenêtre, en HTML
--
-- Personne ne lance le client ici : on dessine l'arbre de régions du Mock
-- (tests/run_tests.lua) en divs positionnées, pour juger une fenêtre à l'œil.
-- Ce n'est pas une capture du jeu : polices approchées, textures du jeu en
-- vignettes grises. Les textures de l'addon (.tga) sont converties en images
-- par tests/snapshot.py (découpées et retournées par SetTexCoord, teintées
-- par multiplication, fusion additive).
--
-- Bibliothèque (retournée par ce fichier) :
--   Snap.Rect(region, ctx)          rectangle absolu { left, top, width, height } (y vers le bas)
--   Snap.TexCoord(texture)          découpe remise dans l'ordre + miroirs (flipX, flipY)
--   Snap.LiveLevel(frame)           niveau du cadre comme en jeu (posé, sinon parent + 1)
--   Snap.Render(frame, opts)        HTML autonome (chaîne)
--   Snap.Snapshot(frame, path, opts) écrit le HTML
--   Snap.SplitSkin(name)            « sobre:<scène> » -> "sobre", "<scène>" (Azeroth sans préfixe)
--   Snap.ForceSkin(skin, T)         pose et tient un thème dans les deux addons ; rend l'annulation
--   Snap.RunScene(name, path)       joue une scène nommée (Snap.scenes), dans son thème, et l'écrit
-- Lancement : python3 tests/snapshot.py <scène> <sortie.html> (voir ce fichier).
local Snap = {}

local ROOT = rawget(_G, "ADDON_ROOT") or "."
Snap.SCREEN = { width = 1600, height = 1000 }
-- fond de la scène : ciel, horizon et herbe estompés (la maquette du thème forgé)
Snap.BACKDROP = "linear-gradient(180deg,#56697a 0%,#7f8f8c 34%,#9aa184 44%,#56603f 50%,#323b28 78%,#20261b 100%)"
-- marge autour de ce qui est dessiné (ombre portée et médaillon compris)
Snap.MARGIN = 40

-- ---------------------------------------------------------------------------
-- 1. Géométrie : ancres -> rectangle absolu
-- ---------------------------------------------------------------------------
-- fraction horizontale / verticale (depuis la gauche / depuis le haut) de
-- chacun des 9 points d'ancrage
local ANCHOR = {
	TOPLEFT = { 0, 0 },    TOP = { 0.5, 0 },    TOPRIGHT = { 1, 0 },
	LEFT = { 0, 0.5 },     CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 1 }, BOTTOM = { 0.5, 1 }, BOTTOMRIGHT = { 1, 1 },
}
Snap.ANCHOR = ANCHOR

local function IsScreen(region, ctx)
	return region == nil or region == rawget(_G, "UIParent") or region == ctx.screenRegion
end

-- taille propre d'une région quand une seule ancre la place
local function OwnSize(region, ctx)
	local w = region.widthSet and tonumber(region.width) or nil
	local h = region.heightSet and tonumber(region.height) or nil
	if region.kind == "FontString" and (not w or not h) then
		local fw, fh = Snap.MeasureText(region, w)
		w, h = w or fw, h or fh
	end
	if not w and region.kind ~= "Texture" and region.kind ~= "FontString" then w = tonumber(region.width) end
	if not h and region.kind ~= "Texture" and region.kind ~= "FontString" then h = tonumber(region.height) end
	return w or 0, h or 0
end

-- Rectangle absolu d'une région. ctx = { memo, screen } (créé au besoin).
function Snap.Rect(region, ctx)
	ctx = ctx or {}
	ctx.memo = ctx.memo or {}
	local screen = ctx.screen or Snap.SCREEN
	if IsScreen(region, ctx) then
		return { left = 0, top = 0, width = screen.width, height = screen.height }
	end
	local cached = ctx.memo[region]
	if cached == false then return nil end           -- cycle d'ancres
	if cached then return cached end
	ctx.memo[region] = false

	local parent = region.mockParent
	local rect
	if region.allPoints then
		local rel = region.allPoints == true and parent or region.allPoints
		local r = Snap.Rect(rel, ctx)
		if r then rect = { left = r.left, top = r.top, width = r.width, height = r.height } end
	elseif region.points and #region.points > 0 then
		local hs, vs = {}, {}   -- contraintes { fraction, coordonnée absolue }
		for _, p in ipairs(region.points) do
			local own = ANCHOR[p.point or "CENTER"] or ANCHOR.CENTER
			local relRegion = p.relTo or parent
			local relPoint = ANCHOR[p.relPoint or p.point or "CENTER"] or ANCHOR.CENTER
			local r = Snap.Rect(relRegion, ctx)
			if r then
				local x = r.left + relPoint[1] * r.width + (p.x or 0)
				local y = r.top + relPoint[2] * r.height - (p.y or 0)   -- y du jeu vers le haut
				hs[#hs + 1] = { own[1], x }
				vs[#vs + 1] = { own[2], y }
			end
		end
		local w, h = OwnSize(region, ctx)
		local function Solve(constraints, size)
			-- deux ancres de fractions différentes : elles fixent la taille
			for i = 1, #constraints do
				for j = i + 1, #constraints do
					local a, b = constraints[i], constraints[j]
					if a[1] ~= b[1] then
						local span = (b[2] - a[2]) / (b[1] - a[1])
						return a[2] - a[1] * span, span
					end
				end
			end
			local c = constraints[#constraints]
			if not c then return nil end
			return c[2] - c[1] * size, size
		end
		local left, width = Solve(hs, w)
		local top, height = Solve(vs, h)
		if left and top then rect = { left = left, top = top, width = width, height = height } end
	elseif region.kind ~= "Texture" and region.kind ~= "FontString" and ctx.root == region then
		-- la racine sans ancre : centrée à l'écran
		local w, h = OwnSize(region, ctx)
		rect = { left = (screen.width - w) / 2, top = (screen.height - h) / 2, width = w, height = h }
	end
	ctx.memo[region] = rect or false
	return rect
end

-- ---------------------------------------------------------------------------
-- 2. Polices et texte
-- ---------------------------------------------------------------------------
-- objet de police -> { path, size } (objet, nom global, police posée sur la région)
function Snap.FontOf(region)
	if region.font and region.font.size then return region.font end
	local object = region.fontObject
	if type(object) == "string" then object = rawget(_G, object) end
	local guard = 0
	while type(object) == "table" and guard < 5 do
		if object.font and object.font.size then return object.font end
		object = object.copiedFrom or object.fontObject
		if type(object) == "string" then object = rawget(_G, object) end
		guard = guard + 1
	end
	return { path = "Fonts\\FRIZQT__.TTF", size = 12 }
end

local function Weight(path)
	path = tostring(path or "")
	if path:find("Bold") and not path:find("SemiBold") then return 700 end
	if path:find("SemiBold") then return 600 end
	if path:find("FRIZ") then return 500 end
	return 400
end
Snap.Weight = Weight

-- texte sans codes de couleur (|cffRRGGBB … |r), retours |n, textures |T…|t
function Snap.PlainText(text)
	text = tostring(text or "")
	text = text:gsub("|H.-|h", ""):gsub("|h", "")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", "\n"):gsub("|T.-|t", "#")
	return text
end

-- largeur approchée d'un texte UTF-8, en em (Inter : capitales larges,
-- minuscules étroites, espaces et ponctuation fines)
local function Ems(text)
	local ems = 0
	for char in tostring(text):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		if char:find("^%u$") then ems = ems + 0.68
		elseif char:find("^%d$") then ems = ems + 0.6
		elseif char == " " then ems = ems + 0.27
		elseif char:find("^[%.,:;'!|il]$") then ems = ems + 0.27
		elseif #char > 1 and char:byte(1) == 195 and char:byte(2) < 160 then ems = ems + 0.68   -- À..ß
		else ems = ems + 0.53 end
	end
	return ems
end
Snap.Ems = Ems
function Snap.MeasureText(region, width)
	local font = Snap.FontOf(region)
	local size = font.size or 12
	local text = Snap.PlainText(region.text)
	local factor = Weight(font.path) >= 600 and 1.05 or 1
	local longest, lines = 0, 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		lines = lines + 1
		local w = Ems(line) * size * factor
		-- SetWordWrap(false) : une seule ligne, coupée (« ... »)
		if width and width > 0 and w > width and region.wordWrap == false then
			w = width
		elseif width and width > 0 and w > width then
			lines = lines + math.floor(w / width)
			w = width
		end
		if w > longest then longest = w end
	end
	return math.ceil(longest), math.ceil(math.max(1, lines) * size * 1.25)
end

local function Escape(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function Css(r, g, b, a)
	return string.format("rgba(%d,%d,%d,%.3f)", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5),
		math.floor((b or 1) * 255 + 0.5), a or 1)
end
Snap.Css = Css

-- texte WoW -> HTML : |cffRRGGBB … |r en spans colorés
function Snap.TextHtml(text)
	-- liens (|Hitem:…|h[Nom]|h) : le nom seul, comme en jeu
	text = tostring(text or ""):gsub("|H.-|h", ""):gsub("|h", ""):gsub("|T.-|t", "\1")
	local out, open = {}, false
	local i = 1
	while i <= #text do
		local color = text:match("^|c%x%x(%x%x%x%x%x%x)", i)
		if color then
			if open then out[#out + 1] = "</span>" end
			out[#out + 1] = '<span style="color:#' .. color .. '">'
			open = true
			i = i + 10
		elseif text:sub(i, i + 1) == "|r" then
			if open then out[#out + 1] = "</span>"; open = false end
			i = i + 2
		elseif text:sub(i, i + 1) == "|n" or text:sub(i, i) == "\n" then
			out[#out + 1] = "<br>"
			i = i + (text:sub(i, i) == "\n" and 1 or 2)
		elseif text:sub(i, i) == "\1" then
			out[#out + 1] = '<span class="icon"></span>'
			i = i + 1
		else
			local j = text:find("[|\n\1]", i + 1) or (#text + 1)
			out[#out + 1] = Escape(text:sub(i, j - 1))
			i = j
		end
	end
	if open then out[#out + 1] = "</span>" end
	return table.concat(out)
end

-- ---------------------------------------------------------------------------
-- 3. Ordre de dessin et visibilité
-- ---------------------------------------------------------------------------
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
	FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local LAYER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }

local function IsRegion(region) return region.kind == "Texture" or region.kind == "FontString" end

-- visible : ni la région ni un parent n'a été caché (le client montre par défaut)
function Snap.Visible(region, root)
	local node, guard = region, 0
	while node and guard < 60 do
		if node.mockHidden then return false end
		if node == root then return true end
		node = node.mockParent
		guard = guard + 1
	end
	return true
end

local function EffectiveAlpha(region)
	local alpha, node, guard = 1, region, 0
	while node and guard < 60 do
		alpha = alpha * (tonumber(node.alpha) or 1)
		node = node.mockParent
		guard = guard + 1
	end
	return alpha
end

-- strate et niveau d'un cadre : hérités du parent s'ils ne sont pas posés
local function FrameOrder(frame, memo)
	if not frame then return 5, 0 end
	if memo[frame] then return memo[frame][1], memo[frame][2] end
	local parentStrata, parentLevel = 5, 0
	if frame.mockParent and frame.mockParent ~= rawget(_G, "UIParent") then
		parentStrata, parentLevel = FrameOrder(frame.mockParent, memo)
	end
	local strata = frame.strata and STRATA[frame.strata] or parentStrata
	local level = frame.levelSet and tonumber(frame.level) or (parentLevel + 1)
	memo[frame] = { strata, level }
	return strata, level
end

local function Collect(root, list)
	list[#list + 1] = root
	for _, child in ipairs(root.mockChildren or {}) do Collect(child, list) end
	return list
end

-- ---------------------------------------------------------------------------
-- 4. Rendu
-- ---------------------------------------------------------------------------
local function Basename(path)
	path = tostring(path or ""):gsub("\\", "/")
	return path:match("([^/]+)$") or path
end

local function TextureStyle(region, alpha)
	local tex = region.texture
	local v = region.colorTexture or region.vertex or { 1, 1, 1, 1 }
	local va = (v[4] or 1) * alpha
	if region.gradient and region.gradient[2] and region.gradient[3] then
		local g = region.gradient
		local a, b = g[2], g[3]
		local dir = g[1] == "VERTICAL" and "to top" or "to right"
		return "background:linear-gradient(" .. dir .. "," .. Css(a.r, a.g, a.b, (a.a or 1) * alpha) .. ","
			.. Css(b.r, b.g, b.b, (b.a or 1) * alpha) .. ")", nil
	end
	if region.colorTexture or (tex and tostring(tex):upper():find("WHITE8X8")) then
		return "background:" .. Css(v[1], v[2], v[3], va), nil
	end
	if tex then
		return "background:" .. Css(v[1], v[2], v[3], 0.18 * alpha), tex
	end
	return nil
end

-- Découpe d'une texture (SetTexCoord) remise dans l'ordre : { gauche, droite,
-- haut, bas, flipX, flipY } (gauche < droite, haut < bas ; flipX / flipY :
-- la texture est retournée dans ce sens). Les deux formes du client : 4
-- nombres (gauche, droite, haut, bas) ou 8 (les coins HG, BG, HD, BD ; sans
-- rotation). nil : texture entière.
function Snap.TexCoord(region)
	local tc = region.texCoord
	if type(tc) ~= "table" then return nil end
	local l, r, t, b
	if #tc >= 8 then
		l, t, r, b = tc[1], tc[2], tc[5], tc[4]
	elseif #tc == 4 then
		l, r, t, b = tc[1], tc[2], tc[3], tc[4]
	else
		return nil
	end
	l, r, t, b = tonumber(l), tonumber(r), tonumber(t), tonumber(b)
	if not (l and r and t and b) then return nil end
	return { math.min(l, r), math.max(l, r), math.min(t, b), math.max(t, b), flipX = l > r, flipY = t > b }
end

-- Niveau d'un cadre tel que le client le donne (GetFrameLevel) : posé
-- (SetFrameLevel), sinon celui du parent + 1. Le Mock rend 1 pour tout cadre
-- non posé ; l'aperçu branche celui-ci sur les cadres créés pendant une
-- scène (Snap.RunScene), pour que « niveau de la fenêtre + 30 » (le cadre
-- du dessus de l'habillage forgé) passe bien au-dessus de ses enfants.
function Snap.LiveLevel(frame)
	local level, node, guard = 0, frame, 0
	while node and guard < 60 do
		if node.levelSet then return level + (tonumber(node.level) or 1) end
		local parent = node.mockParent
		if not parent or parent == rawget(_G, "UIParent") then return level + 1 end
		level = level + 1
		node = parent
		guard = guard + 1
	end
	return level + 1
end

-- 3.7.0 : la coupe d'un cadre (SetClipsChildren, la page Missions qui
-- défile) : le rectangle commun à tous les ancêtres qui coupent (le cadre
-- propriétaire d'une texture ou d'un texte compris), ou nil
local function ClipRect(region, ctx)
	local node = region.mockParent
	local clip, guard = nil, 0
	while node and guard < 60 do
		if node.clipsChildren then
			local r = Snap.Rect(node, ctx)
			if r then
				if not clip then
					clip = { left = r.left, top = r.top, right = r.left + r.width, bottom = r.top + r.height }
				else
					clip.left, clip.top = math.max(clip.left, r.left), math.max(clip.top, r.top)
					clip.right, clip.bottom = math.min(clip.right, r.left + r.width), math.min(clip.bottom, r.top + r.height)
				end
			end
		end
		node = node.mockParent
		guard = guard + 1
	end
	return clip
end

function Snap.Render(root, opts)
	opts = opts or {}
	local ctx = { memo = {}, screen = opts.screen or Snap.SCREEN, root = root }
	local orderMemo = {}
	local all = Collect(root, {})
	local items = {}
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, region in ipairs(all) do
		if Snap.Visible(region, root) then
			local rect = Snap.Rect(region, ctx)
			local drawable = IsRegion(region) or (region.kind == "EditBox" and region.text ~= "")
			local clip = rect and ClipRect(region, ctx)
			-- tout entier hors de la coupe : pas dessiné
			if clip and (rect.left >= clip.right or rect.left + rect.width <= clip.left
				or rect.top >= clip.bottom or rect.top + rect.height <= clip.top) then
				drawable = false
			end
			if rect and drawable and region.drawLayer ~= "HIGHLIGHT" and rect.width >= 0 and rect.height >= 0 then
				local frame = IsRegion(region) and region.mockParent or region
				local strata, level = FrameOrder(frame, orderMemo)
				items[#items + 1] = {
					region = region, rect = rect, clip = clip,
					key = { strata, level, frame and frame.mockId or 0,
						IsRegion(region) and (LAYER[region.drawLayer or "ARTWORK"] or 3) or 6,
						tonumber(region.subLevel) or 0, region.mockId or 0 },
				}
				minX, minY = math.min(minX, rect.left), math.min(minY, rect.top)
				maxX, maxY = math.max(maxX, rect.left + rect.width), math.max(maxY, rect.top + rect.height)
			end
		end
	end
	table.sort(items, function(a, b)
		for i = 1, 6 do
			if a.key[i] ~= b.key[i] then return a.key[i] < b.key[i] end
		end
		return false
	end)
	local rootRect = Snap.Rect(root, ctx) or { left = minX, top = minY, width = 0, height = 0 }
	minX = math.min(minX, rootRect.left); minY = math.min(minY, rootRect.top)
	maxX = math.max(maxX, rootRect.left + rootRect.width); maxY = math.max(maxY, rootRect.top + rootRect.height)
	if minX == math.huge then minX, minY, maxX, maxY = 0, 0, 100, 100 end
	local margin = Snap.MARGIN
	local ox, oy = margin - minX, margin - minY

	local out = {}
	for _, item in ipairs(items) do
		local region, r = item.region, item.rect
		local alpha = EffectiveAlpha(region)
		local pos = string.format("left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx", r.left + ox, r.top + oy,
			math.max(0, r.width), math.max(0, r.height))
		local cut = item.clip
		if cut then
			local top, left = math.max(0, cut.top - r.top), math.max(0, cut.left - r.left)
			local bottom, right = math.max(0, r.top + r.height - cut.bottom), math.max(0, r.left + r.width - cut.right)
			if top > 0 or left > 0 or bottom > 0 or right > 0 then
				pos = pos .. string.format(";clip-path:inset(%.1fpx %.1fpx %.1fpx %.1fpx)", top, right, bottom, left)
			end
		end
		if region.kind == "Texture" then
			local style, file = TextureStyle(region, alpha)
			-- texture retournée par SetTexCoord (haut et bas échangés), tournée
			-- (SetRotation, sens trigonométrique), en fusion additive ; une
			-- découpe de feuille de sprites part en data-crop (tests/snapshot.py)
			-- (gauche > droite : miroir horizontal, coins de droite du cadre forgé ;
			-- haut > bas : miroir vertical, coins du bas). La découpe part
			-- remise dans l'ordre, le miroir passe par transform.
			local tc = Snap.TexCoord(region)
			local transform, crop = "", ""
			if tc then
				if tc.flipX then transform = transform .. " scaleX(-1)" end
				if tc.flipY then transform = transform .. " scaleY(-1)" end
				crop = string.format(' data-crop="%.4f,%.4f,%.4f,%.4f"', tc[1], tc[2], tc[3], tc[4])
			end
			if region.rotation and region.rotation ~= 0 then
				transform = transform .. string.format(" rotate(%.1fdeg)", -math.deg(region.rotation))
			end
			if style and transform ~= "" then style = style .. ";transform:" .. transform:sub(2) end
			if style and region.blendMode == "ADD" then style = style .. ";mix-blend-mode:plus-lighter" end
			if style then
				if file then
					local v = region.vertex or { 1, 1, 1, 1 }
					out[#out + 1] = string.format('<div class="tex file" data-src="%s" data-tint="%s"%s style="%s;%s" title="%s">%s</div>',
						Escape(tostring(file)), Css(v[1], v[2], v[3], (v[4] or 1) * alpha), crop, pos, style, Escape(tostring(file)),
						(r.width >= 24 and r.height >= 10) and Escape(Basename(file)) or "")
				else
					out[#out + 1] = string.format('<div class="tex" style="%s;%s"></div>', pos, style)
				end
			end
		else
			local text = region.text
			if text ~= nil and tostring(text) ~= "" then
				local font = Snap.FontOf(region)
				local c = region.textColor
				if not c then
					local object = region.fontObject
					if type(object) == "string" then object = rawget(_G, object) end
					c = type(object) == "table" and object.textColor or { 1, 0.82, 0 }
				end
				local justify = region.justifyH or (region.kind == "EditBox" and "LEFT") or "CENTER"
				local align = ({ LEFT = "flex-start", CENTER = "center", RIGHT = "flex-end" })[justify] or "center"
				-- hauteur non posée : la boîte suit le texte, il part du haut
				local defaultV = region.heightSet and "MIDDLE" or "TOP"
				local valign = ({ TOP = "flex-start", MIDDLE = "center", BOTTOM = "flex-end" })[region.justifyV or defaultV] or "center"
				local shadow = ""
				local so, sc = region.shadowOffset, region.shadow
				if not so then
					local object = region.fontObject
					if type(object) == "string" then object = rawget(_G, object) end
					if type(object) == "table" then so, sc = object.shadowOffset, object.shadow end
				end
				if so and sc and (so[1] ~= 0 or so[2] ~= 0) and (sc[4] or 1) > 0 then
					shadow = string.format(";text-shadow:%dpx %dpx 0 %s", so[1], -so[2], Css(sc[1], sc[2], sc[3], sc[4] or 1))
				end
				local inset = ""
				if region.kind == "EditBox" and region.textInsets then
					inset = string.format(";padding:0 %dpx 0 %dpx;box-sizing:border-box", region.textInsets[2] or 0, region.textInsets[1] or 0)
				end
				local wrap = (region.widthSet and region.kind == "FontString" and region.wordWrap ~= false) and "normal" or "nowrap"
				-- 3.7.0 : champ sur plusieurs lignes (SetMultiLine, posé par la scène) : le texte revient à la ligne
				if region.kind == "EditBox" and region.multiLine then wrap = "pre-wrap" end
				-- 3.7.0 (S2) : un champ d'une ligne coupe son texte à sa largeur, comme en jeu
				if region.kind == "EditBox" and not region.multiLine then inset = inset .. ";overflow:hidden" end
				local clip = region.widthSet and region.kind == "FontString" and region.wordWrap == false
				out[#out + 1] = string.format('<div class="txt" style="%s;font-size:%dpx;font-weight:%d;color:%s;justify-content:%s;'
					.. 'align-items:%s;text-align:%s;white-space:%s%s%s"><span%s>%s</span></div>',
					pos, font.size or 12, Weight(font.path), Css(c[1], c[2], c[3], (c[4] or 1) * alpha), align, valign,
					justify:lower(), wrap, shadow, inset, clip and ' class="t"' or "", Snap.TextHtml(text))
			end
		end
	end

	local fontDir = ROOT .. "/Ready2Quest/Libs/Socle/Media/"
	local html = {
		"<!doctype html>",
		'<html lang="fr"><head><meta charset="utf-8">',
		"<title>" .. Escape(opts.title or "Aperçu") .. "</title>",
		"<style>",
		string.format("@font-face{font-family:InterSnap;font-weight:400;src:url('file://%sInter-Regular.ttf')}", fontDir),
		string.format("@font-face{font-family:InterSnap;font-weight:600;src:url('file://%sInter-SemiBold.ttf')}", fontDir),
		string.format("@font-face{font-family:InterSnap;font-weight:700;src:url('file://%sInter-Bold.ttf')}", fontDir),
		"body{margin:0;background:#06080a;color:#ddd;font-family:InterSnap,Inter,system-ui,sans-serif}",
		".bar{padding:8px 16px;font-size:12px;color:#7d8389;border-bottom:1px solid #1d2227}",
		-- un paysage flou (ciel, horizon, herbe) comme derrière une fenêtre en
		-- jeu : l'ombre portée et les débords (médaillon, coins) s'y voient
		string.format(".stage{position:relative;width:%dpx;height:%dpx;background:%s}",
			math.ceil(maxX - minX + 2 * margin), math.ceil(maxY - minY + 2 * margin), Snap.BACKDROP),
		".stage>div{position:absolute;box-sizing:border-box}",
		".txt{display:flex;overflow:visible;line-height:1.2;font-family:InterSnap,Inter,system-ui,sans-serif}",
		".tex.file{font-size:9px;color:#9aa;display:flex;align-items:center;justify-content:center;overflow:hidden;"
			.. "outline:1px dashed rgba(160,170,180,.35);outline-offset:-1px}",
		".tex.img{outline:none;background:none!important}",
		-- largeur posée sans retour à la ligne : coupé avec « … », comme en jeu
		".t{overflow:hidden;text-overflow:ellipsis;max-width:100%}",
		".icon{display:inline-block;width:1em;height:1em;background:#556;vertical-align:middle}",
		"</style></head><body>",
		'<div class="bar">' .. Escape(opts.title or "Aperçu") .. (opts.skin and (" · thème " .. Escape(opts.skin)) or "")
			.. " · aperçu hors-jeu (tests/snapshot.lua), pas une capture du client</div>",
		'<div class="stage">',
		table.concat(out, "\n"),
		"</div></body></html>",
	}
	return table.concat(html, "\n"), #items
end

-- Infobulle du jeu (GameTooltip du Mock) dessinée à l'approche : fond et
-- bord du jeu, police du jeu, les couleurs passées à AddLine. `owner` : un
-- cadre sous lequel la poser (facultatif). Retourne le cadre de l'aperçu.
function Snap.Tooltip(tooltip, owner, width)
	local tip = CreateFrame("Frame", nil, UIParent)
	tip:SetFrameStrata("TOOLTIP")
	width = width or 260
	local lines = tooltip.styled or {}
	local y = -10
	tip.bg = tip:CreateTexture(nil, "BACKGROUND")
	tip.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	tip.bg:SetVertexColor(0.03, 0.03, 0.06, 0.92)
	tip.bg:SetAllPoints()
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
		{ "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
		local edge = tip:CreateTexture(nil, "BORDER")
		edge:SetTexture("Interface\\Buttons\\WHITE8X8")
		edge:SetVertexColor(0.55, 0.55, 0.6, 1)
		edge:SetPoint(side[1], tip, side[1], 0, 0)
		edge:SetPoint(side[2], tip, side[2], 0, 0)
		if side[3] == 1 then edge:SetWidth(1) else edge:SetHeight(1) end
	end
	for index, line in ipairs(lines) do
		local fs = tip:CreateFontString(nil, "OVERLAY")
		local c = line.color or { 1, 0.82, 0 }
		fs:SetTextColor(c[1], c[2], c[3])
		fs:SetFont("Fonts\\FRIZQT__.TTF", index == 1 and 14 or 12)
		fs:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, y)
		fs:SetJustifyH("LEFT")
		if line.wrap then fs:SetWidth(width - 20) end
		fs:SetText(line.text)
		local _, h = Snap.MeasureText(fs, line.wrap and (width - 20) or nil)
		if line.right then
			local r = tip:CreateFontString(nil, "OVERLAY")
			local rc = line.rightColor or { 1, 1, 1 }
			r:SetTextColor(rc[1], rc[2], rc[3])
			r:SetFont("Fonts\\FRIZQT__.TTF", 12)
			r:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -10, y)
			r:SetJustifyH("RIGHT")
			r:SetText(line.right)
		end
		y = y - h - 2
	end
	tip:SetSize(width, -y + 8)
	if owner then tip:SetPoint("TOP", owner, "BOTTOM", 0, -6) end
	return tip
end

-- Plusieurs cadres sur une même scène : un cadre racine sans fond qui les
-- englobe (le rendu dessine la racine et ses enfants)
function Snap.Group(...)
	local root = CreateFrame("Frame", nil, UIParent)
	root:SetSize(1, 1)
	root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	for _, frame in ipairs({ ... }) do
		if frame then frame:SetParent(root) end
	end
	return root
end

-- ---------------------------------------------------------------------------
-- Contrôles de mise en page (tests/modules/ui_windows.lua, ui_bricks.lua)
-- ---------------------------------------------------------------------------
-- blocs lisibles : textes (hors boutons) et boutons dessinés, visibles
function Snap.Blocks(root)
	local list = {}
	local function InButton(region)
		local node = region.mockParent
		while node and node ~= root do
			if node.kind == "Button" then return true end
			node = node.mockParent
		end
		return false
	end
	local function Walk(region)
		if region.mockHidden then return end
		if region.kind == "FontString" and tostring(region.text or "") ~= "" and not InButton(region) then
			list[#list + 1] = region
		elseif region.kind == "Button" and ((type(region.text) == "table" and region.text.text ~= "")
			or type(region.label) == "table" or type(region.icon) == "table") then
			list[#list + 1] = region
		end
		for _, child in ipairs(region.mockChildren or {}) do Walk(child) end
	end
	Walk(root)
	return list
end

function Snap.Label(region)
	return tostring(region.text and (type(region.text) == "table" and region.text.text or region.text)
		or (region.label and region.label.text) or region.kind)
end

-- chevauchements (plus d'un pixel dans les deux sens) et sorties du cadre ;
-- `blocks` : les blocs à comparer (Snap.Blocks(root) par défaut), `box` : le
-- cadre qui les contient (le fond de root par défaut)
function Snap.Layout(root, blocks, box)
	local ctx = { memo = {}, root = root }
	box = box or Snap.Rect(root.bg or root, ctx)
	local overlaps, outside = {}, {}
	blocks = blocks or Snap.Blocks(root)
	local rects = {}
	for index, region in ipairs(blocks) do rects[index] = Snap.Rect(region, ctx) end
	for i = 1, #blocks do
		local a = rects[i]
		if a and box and (a.left < box.left - 1 or a.top < box.top - 1 or a.left + a.width > box.left + box.width + 1
			or a.top + a.height > box.top + box.height + 1) then
			outside[#outside + 1] = Snap.Label(blocks[i])
		end
		for j = i + 1, #blocks do
			local b = rects[j]
			if a and b then
				local w = math.min(a.left + a.width, b.left + b.width) - math.max(a.left, b.left)
				local h = math.min(a.top + a.height, b.top + b.height) - math.max(a.top, b.top)
				if w > 1 and h > 1 then overlaps[#overlaps + 1] = Snap.Label(blocks[i]) .. " / " .. Snap.Label(blocks[j]) end
			end
		end
	end
	return overlaps, outside, #blocks
end

-- Textes visibles d'une carte (tuile, ligne) : ses FontStrings, même dans
-- un bouton ; avec Snap.Layout(tuile, Snap.Texts(tuile)), rien ne se
-- chevauche ni ne déborde de la carte
function Snap.Texts(root)
	local list = {}
	local function Walk(region)
		if region.mockHidden then return end
		if region.kind == "FontString" and tostring(region.text or "") ~= "" then list[#list + 1] = region end
		for _, child in ipairs(region.mockChildren or {}) do Walk(child) end
	end
	Walk(root)
	return list
end

function Snap.Snapshot(frame, path, opts)
	local html, count = Snap.Render(frame, opts)
	local handle = assert(io.open(path, "w"))
	handle:write(html)
	handle:close()
	return count
end

-- ---------------------------------------------------------------------------
-- 5. Scènes (python3 tests/snapshot.py <scène> <sortie.html>)
-- ---------------------------------------------------------------------------
Snap.scenes = {}

-- toutes les briques de la v2 dans une fenêtre de démonstration
Snap.scenes.bricks = function(T)
	local NS = T.NS
	local Theme = NS.Theme
	-- emblem : le médaillon du thème forgé, comme la vraie fenêtre des réglages
	local win = Theme.CreateWindow(UIParent, 980, 680, { name = "SnapBricks", nav = 220, footer = 56, emblem = true })
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

	local nav = win.nav
	local brand = Theme.CreateNavBrand(nav, Theme.LOGO, "Ready2Quest")
	brand:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -8)
	brand:SetWidth(220)
	local navSearch = Theme.CreateSearchBox(nav, 188, "Rechercher", nil)
	navSearch:SetPoint("TOPLEFT", nav, "TOPLEFT", 16, -86)
	local y = -126
	local function Group(text)
		local g = Theme.CreateNavGroup(nav, text)
		g:SetPoint("TOPLEFT", nav, "TOPLEFT", 18, y)
		y = y - 20
	end
	local function Item(text, state, selected, badge)
		local item = Theme.CreateNavItem(nav, 219)
		item:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, y)
		item:SetText(text)
		item:SetModuleState(state)
		item:SetSelected(selected)
		if badge then item:SetBadge(badge) end
		y = y - Theme.NAV_ITEM_HEIGHT
		return item
	end
	Group("Général")
	Item("Accueil", nil, false)
	Item("Apparence", nil, false)
	y = y - 8
	Group("Préparation")
	Item("Check avant le départ", true, true)
	Item("Vivres", true, false)
	Item("Butin à vendre", false, false)
	Item("Missions du jour", true, false, "2/3")
	local version = Theme.Text(nav, Theme.F_SMALL, Theme.MUTED)
	version:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 18, 18)
	version:SetText("v1.29.0  ·  Forever")

	local content = win.content
	local header = Theme.CreatePageHeader(content, 758)
	header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	header:SetTitle("Check avant le départ")
	header:SetSubtitle("Ce qui est vérifié en quittant une ville, et quand l'alerte se montre.")

	local tabs = Theme.CreateTabs(content, nil)
	tabs:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -Theme.HEADER_HEIGHT)
	tabs:SetWidth(710)
	tabs:SetTabs({ { id = "checks", label = "Vérifications" }, { id = "alert", label = "Alerte" }, { id = "window", label = "Fenêtre" } })
	tabs:Select("alert", true)
	local search = Theme.CreateSearchBox(content, 180, "Rechercher un réglage", nil)
	search:SetPoint("BOTTOMRIGHT", tabs, "BOTTOMRIGHT", 0, 4)

	local section = Theme.CreateSection(content, "Déclenchement", "quand l'alerte apparaît")
	section:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -146)
	local cardW = 351
	local cards = {}
	local function Card(index, label)
		local col = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local card = Theme.CreateSettingCard(content, cardW, Theme.CARD_HEIGHT)
		card:SetPoint("TOPLEFT", content, "TOPLEFT", 24 + col * (cardW + 8), -172 - row * (Theme.CARD_HEIGHT + 4))
		card:SetLabel(label)
		card:SetAlt(row % 2 == 1)
		cards[index] = card
		return card
	end
	local t1 = Theme.CreateToggle(Card(1, "Alerte en quittant la ville").control)
	t1:SetPoint("RIGHT", cards[1].control, "RIGHT", 0, 0)
	t1:SetChecked(true)
	local t2 = Theme.CreateToggle(Card(2, "Son de l'alerte").control)
	t2:SetPoint("RIGHT", cards[2].control, "RIGHT", 0, 0)
	t2:SetChecked(false)
	local s1 = Theme.CreateSlider(Card(3, "Délai avant l'alerte").control, 170, 0, 30, 1, nil)
	s1:SetPoint("RIGHT", cards[3].control, "RIGHT", 0, 0)
	s1:SetValue(12)
	s1:SetValueText("12 s")
	local s2 = Theme.CreateSlider(Card(4, "Note minimale").control, 170, 0, 100, 5, nil)
	s2:SetPoint("RIGHT", cards[4].control, "RIGHT", 0, 0)
	s2:SetValue(70)
	local dd = Theme.CreateDropdown(Card(5, "Position de l'alerte").control, 150, nil)
	dd:SetPoint("RIGHT", cards[5].control, "RIGHT", 0, 0)
	dd:SetOptions({ { value = "top", label = "En haut" }, { value = "center", label = "Au centre" },
		{ value = "gold", label = "Cadre doré", disabled = true, hint = "30 brillantes" } })
	dd:SetValue("top")
	local sw = Theme.CreateSwatch(Card(6, "Couleur du liseré").control, 15)
	sw:SetPoint("RIGHT", cards[6].control, "RIGHT", 0, 0)
	sw:SetColor(Theme.BLUE[1], Theme.BLUE[2], Theme.BLUE[3])
	local lock = Theme.CreateLockTag(Card(7, "Cadre givré").control, "30 brillantes")
	lock:SetPoint("RIGHT", cards[7].control, "RIGHT", 0, 0)
	local dd2 = Theme.CreateDropdown(Card(8, "Liste ouverte").control, 150, nil)
	dd2:SetPoint("RIGHT", cards[8].control, "RIGHT", 0, 0)
	dd2:SetOptions({ { value = "a", label = "Choix actif" }, { value = "b", label = "Autre choix" },
		{ value = "c", label = "Verrouillé", disabled = true, hint = "niv. 20" } })
	dd2:SetValue("a")
	dd2:Open()

	local section2 = Theme.CreateSection(content, "Boutons", nil)
	section2:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -400)
	local x = 24
	for _, spec in ipairs({ { nil, "Par défaut" }, { "outline", "Contour" }, { "accent", "Accent" },
		{ "primary", "Principal" }, { "adventure", "Partir à l'aventure" } }) do
		local w = spec[1] == "adventure" and 170 or 110
		local b = Theme.CreateButton(content, w, 28, spec[2], nil, spec[1])
		b:SetPoint("TOPLEFT", content, "TOPLEFT", x, -426)
		x = x + w + 10
	end

	local foot = win.footer
	local reset = Theme.CreateButton(foot, 120, 28, "Réinitialiser", nil, "outline")
	reset:SetPoint("LEFT", foot, "LEFT", 24, 0)
	local edit = Theme.CreateButton(foot, 140, 28, "Déplacer les cadres", nil, "outline")
	edit:SetPoint("LEFT", reset, "RIGHT", 10, 0)
	local done = Theme.CreateButton(foot, 110, 28, "Terminé", nil, "accent")
	done:SetPoint("RIGHT", foot, "RIGHT", -24, 0)
	win:Show()
	return win, "Briques du socle (Theme v2)"
end

-- ---------------------------------------------------------------------------
-- Thème forgé (socle 3.2) : les matières (Theme.ART) et l'habillage des
-- fenêtres, vus seuls. À rendre aussi en « sobre:forge-… » : le tableau
-- garde ses matières, la fenêtre perd son cadre d'orfèvre.
-- ---------------------------------------------------------------------------
-- teintes d'essai de la plaque et du creux (le guide de teinte du thème
-- forgé : bouton neutre, principal or, ajout vert, retrait rouge, action
-- arcane, carte) ; libellé, teinte, encre du texte posé dessus
local FORGE_PLATES = {
	{ "neutre", { 0.165, 0.196, 0.239 }, { 0.90, 0.92, 0.94 } },
	{ "principal", { 1.0, 0.84, 0.56 }, { 0.11, 0.075, 0.02 } },
	{ "ajout", { 0.18, 0.37, 0.23 }, { 0.77, 0.95, 0.79 } },
	{ "retrait", { 0.40, 0.17, 0.15 }, { 0.96, 0.73, 0.69 } },
	{ "arcane", { 0.21, 0.35, 0.56 }, { 0.86, 0.91, 1.0 } },
	{ "carte", { 0.118, 0.145, 0.176 }, { 0.90, 0.92, 0.94 } },
}

-- Le tableau des matières : chaque texture de Theme.ART à sa taille (agrandie
-- si elle est petite), la plaque et le creux découpés en 9 tranches à
-- plusieurs tailles et teintes, filets et points lumineux teintés, et les
-- boutons du socle tels qu'ils sont.
Snap.scenes["forge-bricks"] = function(T)
	local Theme = T.NS.Theme
	local ART = Theme.ART
	local win = Theme.CreateWindow(UIParent, 1120, 760, { name = "SnapForge", emblem = true })
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	local host = win.content
	local function Label(text, x, y, color)
		local fs = Theme.Text(host, Theme.F_SMALL, color or Theme.MUTED_LIGHT)
		fs:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
		fs:SetJustifyH("LEFT")
		fs:SetText(text)
		return fs
	end
	local function Heading(text, y)
		local fs = Theme.Text(host, Theme.F_CAPS, Theme.TITLE)
		fs:SetPoint("TOPLEFT", host, "TOPLEFT", 24, y)
		fs:SetJustifyH("LEFT")
		fs:SetText(text)
		return fs
	end
	local title = Theme.Text(host, Theme.F_DISPLAY, Theme.TITLE)
	title:SetPoint("TOPLEFT", host, "TOPLEFT", 96, -22)
	title:SetJustifyH("LEFT")
	title:SetText("Matières du thème forgé")
	Label("Theme.ART (tools/gen_ui_assets.py) · Theme.Slice · thème posé : " .. tostring(Theme.skin), 96, -52)

	-- 1. chaque matière, brute (blanc : sans teinte) ; écart de 8 px : les neuf
	-- cases tiennent dans la largeur de la fenêtre (1092 sur 1120)
	Heading("Textures", -84)
	local x = 24
	win.brickCells = {}
	for _, key in ipairs({ "frame", "shadow", "corner", "plate", "inset", "dot", "line", "vignette", "ring" }) do
		local spec = ART[key]
		local w, h = 96, 96
		if key == "line" then w, h = 192, 12 end
		if key == "vignette" then w, h = 140, 96 end
		local back = host:CreateTexture(nil, "BACKGROUND", nil, 1)
		back:SetColorTexture(0.30, 0.31, 0.33, 1)   -- gris moyen : l'ombre et les gris se voient
		back:SetPoint("TOPLEFT", host, "TOPLEFT", x, -110)
		back:SetSize(w, 96)
		local tex = host:CreateTexture(nil, "ARTWORK")
		tex:SetTexture(spec.file)
		tex:SetSize(w, h)
		tex:SetPoint("CENTER", back, "CENTER", 0, 0)
		Label(key .. (spec.size and (" " .. spec.size) or ""), x, -210)
		win.brickCells[#win.brickCells + 1] = { key = key, left = x, right = x + w }
		x = x + w + 8
	end

	-- 2. la plaque en 9 tranches, teintée (multiplie le gris), avec son texte
	Heading("Plaque (plate) : teintes et tailles", -240)
	x = 24
	for index, spec in ipairs(FORGE_PLATES) do
		local w = index == 1 and 150 or 140
		local b = CreateFrame("Frame", nil, host)
		b:SetSize(w, 30)
		b:SetPoint("TOPLEFT", host, "TOPLEFT", x, -266)
		Theme.Slice(b, "plate", { layer = "BACKGROUND", color = spec[2] })
		local fs = Theme.Text(b, Theme.F_LABEL, spec[3])
		fs:SetPoint("CENTER", b, "CENTER", 0, 0)
		fs:SetText(spec[1])
		x = x + w + 12
	end
	-- tailles : petite pastille, grande carte, bloc carré
	x = 24
	for _, size in ipairs({ { 24, 24 }, { 60, 60 }, { 200, 44 }, { 320, 70 } }) do
		local b = CreateFrame("Frame", nil, host)
		b:SetSize(size[1], size[2])
		b:SetPoint("TOPLEFT", host, "TOPLEFT", x, -310)
		Theme.Slice(b, "plate", { layer = "BACKGROUND", color = FORGE_PLATES[size[1] >= 200 and 6 or 1][2] })
		Label(size[1] .. "×" .. size[2], x, -310 - size[2] - 4)
		x = x + size[1] + 16
	end

	-- 3. le creux : filet au repos (EDGE), au survol (GOLD_SOFT), actif (ACTIVE)
	Heading("Creux (inset) : repos, survol, actif", -420)
	x = 24
	for _, spec in ipairs({ { "repos · EDGE", Theme.EDGE }, { "survol · GOLD_SOFT", Theme.GOLD_SOFT },
		{ "actif · ACTIVE", Theme.ACTIVE } }) do
		local f = CreateFrame("Frame", nil, host)
		f:SetSize(210, 30)
		f:SetPoint("TOPLEFT", host, "TOPLEFT", x, -446)
		Theme.Slice(f, "inset", { layer = "BACKGROUND", color = spec[2] })
		local fs = Theme.Text(f, Theme.F_BODY, Theme.TEXT)
		fs:SetPoint("LEFT", f, "LEFT", 10, 0)
		fs:SetText(spec[1])
		x = x + 222
	end
	local tall = CreateFrame("Frame", nil, host)
	tall:SetSize(120, 70)
	tall:SetPoint("TOPLEFT", host, "TOPLEFT", x, -446)
	Theme.Slice(tall, "inset", { layer = "BACKGROUND", color = Theme.EDGE })
	Label("120×70", x, -520)

	-- 4. lumière : filets qui s'éteignent vers la droite, points lumineux
	Heading("Lumière : filets (line) et points (dot), teintés", -548)
	local y = -576
	for _, color in ipairs({ Theme.GOLD, Theme.ACTIVE, Theme.GREEN }) do
		local dot = host:CreateTexture(nil, "ARTWORK")
		dot:SetTexture(ART.dot.file)
		dot:SetVertexColor(color[1], color[2], color[3], 1)
		dot:SetSize(14, 14)
		dot:SetPoint("TOPLEFT", host, "TOPLEFT", 24, y + 3)
		local line = host:CreateTexture(nil, "ARTWORK")
		line:SetTexture(ART.line.file)
		line:SetVertexColor(color[1], color[2], color[3], 1)
		line:SetSize(320, 6)
		line:SetPoint("TOPLEFT", host, "TOPLEFT", 44, y)
		local glow = host:CreateTexture(nil, "ARTWORK")
		glow:SetTexture(ART.dot.file)
		glow:SetVertexColor(color[1], color[2], color[3], 1)
		glow:SetBlendMode("ADD")
		glow:SetSize(28, 28)
		glow:SetPoint("TOPLEFT", host, "TOPLEFT", 380, y + 10)
		y = y - 24
	end
	Label("additif (ADD)", 414, -578)

	-- 5. les boutons du socle, tels quels (les autres lots les forgent)
	Heading("Boutons du socle", -660)
	x = 24
	for _, spec in ipairs({ { nil, "Par défaut" }, { "outline", "Contour" }, { "accent", "Accent" },
		{ "primary", "Principal" }, { "adventure", "Aventure" } }) do
		local b = Theme.CreateButton(host, 120, 28, spec[2], nil, spec[1])
		b:SetPoint("TOPLEFT", host, "TOPLEFT", x, -684)
		x = x + 132
	end
	local off = Theme.CreateButton(host, 120, 28, "Inactif", nil, "primary")
	off:SetPoint("TOPLEFT", host, "TOPLEFT", x, -684)
	if off.Disable then off:Disable() end
	win:Show()
	return win, "Thème forgé : matières (Theme.ART), plaque et creux en 9 tranches, lueurs, boutons"
end

-- Une fenêtre de dialogue (médaillon, cadre d'orfèvre, quatre coins, ombre)
-- et un bandeau (cadre sans coins ni médaillon), côte à côte
Snap.scenes["forge-dialog-toast"] = function(T)
	local Theme = T.NS.Theme
	local dialog = Theme.CreateDialog(UIParent, 480, 280, { name = "SnapForgeDialog", title = "Avant le donjon",
		subtitle = "Le groupe est prêt : vivres, réparations, sacs.", logo = Theme.LOGO })
	dialog:SetPoint("TOPLEFT", UIParent, "CENTER", -520, 150)
	local body = Theme.Text(dialog.content, Theme.F_BODY, Theme.TEXT)
	body:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", dialog.pad, dialog.contentTop - 16)
	body:SetWidth(dialog.innerWidth)
	body:SetJustifyH("LEFT")
	body:SetText("Trois points restent à voir avant d'entrer. La fenêtre se ferme d'elle-même quand tout est prêt.")
	dialog:AddFooterButton("Fermer", nil, "primary", "right")
	dialog:AddFooterButton("Diagnostic", nil, "outline", "left")
	dialog:Show()

	local toast = Theme.CreateToast(UIParent, 380, 72, { name = "SnapForgeToast" })
	toast:SetPoint("TOPLEFT", UIParent, "CENTER", 40, 150)
	local head = Theme.Text(toast, Theme.F_TITLE, Theme.TITLE)
	head:SetPoint("TOPLEFT", toast, "TOPLEFT", toast.contentLeft, -14)
	head:SetJustifyH("LEFT")
	head:SetText("Capture possible")
	local line = Theme.Text(toast, Theme.F_BODY, Theme.TEXT)
	line:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
	line:SetJustifyH("LEFT")
	line:SetText("Ours gris (rare) · et 1 de plus")
	toast:Show()
	return Snap.Group(dialog, toast), "Thème forgé : une fenêtre de dialogue et un bandeau, côte à côte"
end

-- fenêtre de module centrée (la position sauvegardée n'a pas de sens ici)
local function Centered(frame)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return frame
end

-- Avant le départ : sortie de Comté-de-l'Or, sans vivres ni foyer, deux gris
Snap.scenes["r2q-check"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	Mock.world.durability = { [5] = { 18, 100 } }
	Mock.world.bags[0].items[1] = { itemID = 3001, stackCount = 1, quality = 0 }
	Mock.world.bags[0].items[2] = { itemID = 3002, stackCount = 1, quality = 0 }
	NS.window = nil
	NS:RunChecklist("manual")
	NS.lastDeparture = { name = "Comté-de-l'Or", source = "mail" }
	NS:ShowWindow(NS.lastResults)
	Mock:Advance(1)   -- fin de l'animation de la note
	return Centered(NS.window), "Ready2Quest : avant le départ"
end

-- Avant le donjon : fiche complète (quêtes, plans, préparation incomplète)
Snap.scenes["r2q-dungeon"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	NS.dungeonFrame = nil
	NS:ShowDungeonWindow({
		name = "Les Mortemines", verdict = "ok", min = 17, max = 26, level = 21,
		quests = { { title = "Edwin VanCleef", ready = false }, { title = "Les brigands du Défias", ready = true },
			{ title = "Le Collier de Rouge", ready = false } },
		blueprints = { { name = "Plan : bouclier de fer renforcé" } },
		readiness = {
			{ label = "Durabilité", detail = "92 %", ok = true },
			{ label = "Vivres", detail = "0 nourriture", ok = false },
			{ label = "Foyer", detail = "prête", ok = true },
			{ label = "Sacs", detail = "3 places libres", ok = false },
		},
	})
	return Centered(NS.dungeonFrame), "Ready2Quest : avant le donjon"
end

-- Retour d'expédition : XP, argent, butin (objets notables), morts, usure
Snap.scenes["r2q-expedition"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	NS.expeditionFrame = nil
	NS:ShowExpeditionReport({
		duration = 754, xp = 950, levels = 1, earned = 50000, spent = 20000, net = 30000,
		loot = { { link = "|cff1eff00[Épée verte]|r", count = 1 }, { link = "|cff0070dd[Anneau bleu]|r", count = 2 } },
		deaths = 2, duraLost = 35, durability = 55, quests = 1, newQuests = 1,
		restock = { "Vivres" }, place = { name = "Comté-de-l'Or" },
	})
	return Centered(NS.expeditionFrame), "Ready2Quest : retour d'expédition"
end

-- Après la mort : fantôme à 175 m de son corps, niveau 22
Snap.scenes["r2q-death"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	NS.deathFrame, NS.deathDismissed = nil, nil
	NS:ShowDeathPanel({ ghost = true, level = 22, distance = 175, runTime = 20, sickness = 600,
		points = 50, cost = 25000, verdict = "run" })
	return Centered(NS.deathFrame), "Ready2Quest : après la mort"
end

-- liens d'objet colorés comme en jeu
local function Link(name, quality)
	local colors = { [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd" }
	return "|cff" .. (colors[quality] or "ffffff") .. "|Hitem:1::::::::|h[" .. name .. "]|h|r"
end

-- Place au butin : sacs pleins devant un butin vert ; le plus cher en dernier
-- (estompé : il vaut plus que le butin). Données posées à la place du scan.
Snap.scenes["r2q-lootroom"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	NS.lootRoomFrame = nil
	NS.LootRoomLoot = function()
		return { { link = Link("Cuir moyen renforcé", 2), count = 1, value = 1250, texture = "Interface\\Icons\\INV_Misc_LeatherScrap_08" } }
	end
	NS.LootRoomRows = function()
		return {
			{ itemID = 1, link = Link("Os brisé", 0), count = 1, vendor = 5 },
			{ itemID = 2, link = Link("Patte de loup", 0), count = 3, vendor = 42 },
			{ itemID = 3, link = Link("Caillou rugueux", 1), count = 4, vendor = 80 },
			{ itemID = 4, link = Link("Étoffe de lin", 1), count = 12, vendor = 156, auction = 900 },
			{ itemID = 5, link = Link("Anneau de la vigie", 2), count = 1, vendor = 2400, dearer = true },
		}
	end
	local frame = NS:LootRoomOpen(true)
	return Centered(frame), "Ready2Quest : place au butin"
end

-- Rangs de sorts : trois cases à mettre à jour, une de trop pour la liste
Snap.scenes["r2q-spellranks"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	NS.spellRanksFrame = nil
	local list = {
		{ name = "Lumière sacrée", rank = 3, bestRank = 5, bar = 1, case = 4, bestID = 1 },
		{ name = "Éclair lumineux", rank = 2, bestRank = 4, bar = 1, case = 7, bestID = 2 },
		{ name = "Marteau de la justice", rank = 1, bestRank = 2, bar = 2, case = 3, bestID = 3 },
	}
	NS.SpellRankScan = function() return list end
	local saved = NS.SPELLRANKS_ROWS
	NS.SPELLRANKS_ROWS = 8
	local frame = NS:SpellRanksOpen()
	NS.SPELLRANKS_ROWS = saved
	return Centered(frame), "Ready2Quest : rangs de sorts"
end

-- Sac plein : le bandeau près des sacs, sur le gris le moins cher
Snap.scenes["r2q-bagspace"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	NS.bagspaceFrame = nil
	NS.bagspace = { index = 1, list = { { link = Link("Os brisé", 0), count = 1, value = 5, bag = 0, slot = 4, itemID = 1 } } }
	return Centered(NS:ShowBagSpaceFrame()), "Ready2Quest : sac plein"
end

-- Kit de camp : le décompte jusqu'aux buffs
Snap.scenes["r2q-camp"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	NS.campFrame = nil
	local frame = NS:EnsureCampFrame()
	frame.text:SetText(NS:F("CAMP_TIMER", "0:42"))
	frame:Show()
	return Centered(frame), "Ready2Quest : au camp"
end

-- les quatre icônes d'annonce, côte à côte (une seule à la fois en jeu)
Snap.scenes["r2q-notice"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	local tiles = {}
	local notices = {
		NS:NoticeDepart(92, "PRÊT"),
		NS:NoticeReturn({ deaths = 1, durability = 40, restock = {} }),
		NS:NoticeDungeon({ name = "Les Mortemines", verdict = "ok", readiness = { { ok = false } } }),
		{ kind = "spells", color = NS.Theme.ORANGE, lines = { NS:F("SR_NOTICE", 2) } },
	}
	for index, notice in ipairs(notices) do
		NS.noticeFrame = nil
		NS:ShowNotice(notice)
		local frame = NS.noticeFrame
		NS:UpdateNotice(notice.pulseUntil + 1)   -- après la pulsation
		frame:SetAlpha(1)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", (index - 2.5) * 72, 0)
		tiles[index] = frame
	end
	return Snap.Group(tiles[1], tiles[2], tiles[3], tiles[4]),
		"Ready2Quest : icônes d'annonce (départ, retour, donjon, sorts)"
end

-- Sortie de ville : l'icône « départ » et sa bulle au survol
Snap.scenes["r2q-exit-alert"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	NS.noticeFrame = nil
	Mock.world.durability = { [5] = { 18, 100 } }
	NS:RunChecklist("manual")
	local notice = NS:NoticeDepart(NS.score, (NS:ScoreLabel()))
	NS:ShowNotice(notice)
	local frame = Centered(NS.noticeFrame)
	GameTooltip:ClearLines()
	frame:GetScript("OnEnter")(frame)
	return Snap.Group(frame, Snap.Tooltip(GameTooltip, frame, 250)), "Ready2Quest : alerte de sortie (icône et bulle)"
end

-- Rythme de leveling : l'infobulle de la barre d'XP
Snap.scenes["r2q-pace"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	NS.PaceTooltipLines = function(self)
		return self:PaceLines({ session = 14200, recent = 16800, window = 15, remaining = 9350, seconds = 2350,
			kills = 41, quests = 6, rest = { pct = 12.5, gain = 5, gainInn = 15, resting = false } })
	end
	local bar = CreateFrame("Frame", nil, UIParent)
	bar:SetSize(1, 1)
	bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	GameTooltip:ClearLines()
	NS:PaceOnBarEnter(bar)
	return Snap.Tooltip(GameTooltip, bar, 330), "Ready2Quest : rythme de leveling (infobulle de la barre d'XP, police du jeu)"
end

-- Infobulle du bouton de minicarte, après un check
Snap.scenes["r2q-minimap-tooltip"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	NS:RunChecklist("manual")
	if NS.window then NS.window:Hide() end
	local owner = CreateFrame("Frame", nil, UIParent)
	owner:SetSize(1, 1)
	owner:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	GameTooltip:ClearLines()
	NS:ShowMinimapTooltip(owner, true)
	return Snap.Tooltip(GameTooltip, owner, 280), "Ready2Quest : infobulle du bouton de minicarte (police du jeu)"
end

-- Mode déplacement : le bandeau, avec l'icône d'alerte à placer
Snap.scenes["r2q-edit-banner"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	UIParent:SetSize(1920, 1080)
	NS.editBanner, NS.noticeFrame = nil, nil
	NS:StartEditMode()
	local banner = NS.editBanner
	banner:ClearAllPoints()
	banner:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	NS.noticeFrame:ClearAllPoints()
	NS.noticeFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return Snap.Group(banner, NS.noticeFrame), "Ready2Quest : mode déplacement des cadres"
end

-- Page de l'addon dans Échap > Options > AddOns
Snap.scenes["r2q-settings-canvas"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	local savedSettings = rawget(_G, "Settings")
	_G.Settings = { RegisterCanvasLayoutCategory = function(frame) return { frame = frame } end,
		RegisterAddOnCategory = function() end }
	NS.settingsTried, NS.settingsCanvas = nil, nil
	NS:RegisterSettingsCategory()
	_G.Settings = savedSettings
	local canvas = NS.settingsCanvas
	canvas:SetSize(640, 220)
	return Centered(canvas), "Ready2Quest : page Échap > Options > AddOns"
end

-- La bonne récompense : la récompense conseillée, cernée d'ambre
Snap.scenes["r2q-reward"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	local holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(310, 96)
	holder:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	holder.bg = holder:CreateTexture(nil, "BACKGROUND")
	holder.bg:SetTexture("Interface\\QuestFrame\\QuestBG")
	holder.bg:SetAllPoints()
	local names = { "Bottes du sentier", "Gants de l'éclaireur", "Bâton de chêne" }
	for index = 1, 3 do
		local button = CreateFrame("Button", "QuestInfoRewardsFrameQuestInfoItem" .. index, holder)
		button:SetSize(147, 41)
		button:SetPoint("TOPLEFT", holder, "TOPLEFT", 4 + ((index - 1) % 2) * 153, -4 - math.floor((index - 1) / 2) * 46)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetTexture("Interface\\Icons\\INV_Boots_01")
		button.icon:SetSize(37, 37)
		button.icon:SetPoint("LEFT", button, "LEFT", 2, 0)
		button.name = button:CreateFontString(nil, "OVERLAY")
		button.name:SetFont("Fonts\\FRIZQT__.TTF", 11)
		button.name:SetTextColor(0.1, 0.06, 0.02)
		button.name:SetPoint("TOPLEFT", button, "TOPLEFT", 44, -6)
		button.name:SetText(names[index])
		_G["QuestInfoRewardsFrameQuestInfoItem" .. index] = button
	end
	NS.rewardState = { active = true }
	NS.RewardEnabled = function() return true end
	NS.RewardAnalyze = function()
		return { mode = "upgrade", choices = { {}, {}, {} }, best = { index = 2, link = Link(names[2], 2) } }
	end
	NS:RewardApply(true)
	return holder, "Ready2Quest : la bonne récompense (cadre de quête du jeu en vignette)"
end

-- Réglages (refonte) : tous les modules chargés, fenêtre centrée, une page
local function Options(T, ns, page, prepare)
	T.ResetWorld()
	T.LoadModules()
	ns.optionsFrame = nil
	if prepare then prepare(ns) end
	ns:ToggleOptions()
	local win = ns.optionsFrame
	win:ClearAllPoints()
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	if page then ns:SelectOptionsPage(page) end
	return win
end

-- 2.0.0 : navigation par familles (maquette validée le 2026-11-17)
Snap.scenes["r2q-options"] = function(T)
	return Options(T, T.NS, nil), "Ready2Quest : réglages, Accueil > Vue d'ensemble (première ouverture)"
end

Snap.scenes["r2q-options-general"] = function(T)
	return Options(T, T.NS, "general"), "Ready2Quest : réglages, Accueil > Général"
end

Snap.scenes["r2q-options-bags"] = function(T)
	return Options(T, T.NS, "bags"), "Ready2Quest : réglages, Check avant le départ > Sacs & vivres"
end

Snap.scenes["r2q-options-plein"] = function(T)
	return Options(T, T.NS, "plein", function(ns) ns:DB().lootroomEnabled = false end),
		"Ready2Quest : réglages, Sacs & butin > Sac plein & butin (Place au butin coupée : grisée)"
end

Snap.scenes["r2q-options-nav"] = function(T)
	return Options(T, T.NS, "portees"), "Ready2Quest : réglages, Combat > Portées"
end

Snap.scenes["r2q-options-spellranks"] = function(T)
	return Options(T, T.NS, "spellranks"), "Ready2Quest : réglages, Quêtes & sorts > Sorts (lien direct, tête éclairée)"
end

Snap.scenes["qc-options-companion"] = function(T)
	local win = Options(T, T.QNS, "companionMain", function(ns)
		local data = ns:CompanionData()
		data.unlocked["frame:copper"] = true
		data.unlocked["app:frog"] = true
	end)
	-- la liste des fonds ouverte : ce qui est gagné, puis le reste grisé avec sa condition
	for _, row in ipairs(T.QNS.optionsFrame.rows) do
		if row.def and row.def.key == "companionBackground" then row.dropdown:Open(true) end
	end
	return win, "QuestCompanion : réglages, Compagnon de route > Compagnon (liste des fonds ouverte)"
end

Snap.scenes["qc-options-ornaments"] = function(T)
	return Options(T, T.QNS, "companionOrnaments"), "QuestCompanion : réglages, Compagnon de route > Ornements"
end

Snap.scenes["options-search"] = function(T)
	local win = Options(T, T.NS, "general")
	win.search:SetText("alerte")
	win.search.scripts.OnTextChanged(win.search, true)
	return win, "Ready2Quest : réglages, recherche « alerte »"
end

-- ---------------------------------------------------------------------------
-- QuestCompanion (refonte, lot 4) : un personnage niveau 24 aux Tarides, son
-- compagnon « Brindille », un carnet entamé. Données d'exemple posées à la
-- place des scans ; le modèle 3D est remplacé par le logo (pas de 3D ici).
-- ---------------------------------------------------------------------------
local QC_MAPS = {
	[947]  = { mapID = 947,  name = "Azeroth", parentMapID = 0, mapType = 1 },
	[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 },
	[1415] = { mapID = 1415, name = "Royaumes de l'Est", parentMapID = 947, mapType = 2 },
	[1411] = { mapID = 1411, name = "Durotar", parentMapID = 1414, mapType = 3 },
	[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 },
	[1412] = { mapID = 1412, name = "Mulgore", parentMapID = 1414, mapType = 3 },
	[1440] = { mapID = 1440, name = "Orneval", parentMapID = 1414, mapType = 3 },
	[1442] = { mapID = 1442, name = "Les Serres-Rocheuses", parentMapID = 1414, mapType = 3 },
	[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 1415, mapType = 3 },
	[1436] = { mapID = 1436, name = "Marche de l'Ouest", parentMapID = 1415, mapType = 3 },
	[1421] = { mapID = 1421, name = "Forêt des Pins-Argentés", parentMapID = 1415, mapType = 3 },
	[1420] = { mapID = 1420, name = "Clairières de Tirisfal", parentMapID = 1415, mapType = 3 },
	[1438] = { mapID = 1438, name = "Teldrassil", parentMapID = 1414, mapType = 3 },
	[1426] = { mapID = 1426, name = "Dun Morogh", parentMapID = 1415, mapType = 3 },
	[1439] = { mapID = 1439, name = "Sombrivage", parentMapID = 1414, mapType = 3 },
	[1432] = { mapID = 1432, name = "Loch Modan", parentMapID = 1415, mapType = 3 },
	[1433] = { mapID = 1433, name = "Les Carmines", parentMapID = 1415, mapType = 3 },
	[1431] = { mapID = 1431, name = "Bois de la Pénombre", parentMapID = 1415, mapType = 3 },
	[1424] = { mapID = 1424, name = "Contreforts de Hautebrande", parentMapID = 1415, mapType = 3 },
	[1450] = { mapID = 1450, name = "Reflet-de-Lune", parentMapID = 1414, mapType = 3 },
	[1416] = { mapID = 1416, name = "Montagnes d'Alterac", parentMapID = 1415, mapType = 3 },
	[1417] = { mapID = 1417, name = "Hautes-terres d'Arathi", parentMapID = 1415, mapType = 3 },
	[1443] = { mapID = 1443, name = "Désolace", parentMapID = 1414, mapType = 3 },
	[1434] = { mapID = 1434, name = "Vallée de Strangleronce", parentMapID = 1415, mapType = 3 },
	[1441] = { mapID = 1441, name = "Mille pointes", parentMapID = 1414, mapType = 3 },
	[1437] = { mapID = 1437, name = "Les Paluns", parentMapID = 1415, mapType = 3 },
	[2521] = { mapID = 2521, name = "Île de Kezan", parentMapID = 1414, mapType = 3 },
}

local QC_FRAMES = { "journalFrame", "companionFrame", "companionBubble", "companionHover", "chestFrame", "treatMenu",
	"journalToast", "journalTracker" }

local function QCWorld(T)
	local ns = T.QNS
	T.ResetWorld()
	T.LoadModules()
	for id, info in pairs(QC_MAPS) do Mock.world.maps[id] = info end
	Mock.world.mapID = 1413
	Mock.world.subzone = "La Croisée"
	Mock.world.level = 24
	UIParent.width, UIParent.height = Snap.SCREEN.width, Snap.SCREEN.height
	for _, field in ipairs(QC_FRAMES) do
		if ns[field] then ns[field]:Hide() end
		ns[field] = nil
	end
	ns.companionRT, ns.companionBubbleUntil, ns.companionLastBubble = nil, nil, nil
	ns.journalToasts, ns.journalChats, ns.journalToastHideAt = {}, {}, nil
	local db = ns:DB()
	db.journalTracker, db.companionShow = false, true
	-- 3.1.0 : le Voile d'hiver suit le thème forgé, et l'horloge du faux
	-- client (1970-01-01) tombe en saison : décor coupé (les scènes montrent
	-- le filet, pas la boule de neige)
	db.winterVeil = "off"
	local data = ns:CompanionData()
	data.name, data.tutoDone, data.appearance = "Brindille", true, "whelp_green"
	data.frameStyle, data.background = "copper", "forest"
	data.needs = { hunger = 82, energy = 64, mood = 91, curiosity = 46 }
	for _, key in ipairs({ "app:frog", "frame:copper", "orn:ribbon", "bg:forest", "app:whelp_green" }) do data.unlocked[key] = true end
	local journal = ns:JournalData()
	local function Stamp(kind, key, name) journal.stamps[kind .. ":" .. key] = { id = kind .. ":" .. key, kind = kind, name = name, at = 0 } end
	Stamp("zone", 1411, "Durotar"); Stamp("zone", 1413, "Les Tarides"); Stamp("zone", 1412, "Mulgore")
	Stamp("subzone", 380, "La Croisée"); Stamp("subzone", 362, "Razor Hill"); Stamp("capital", 1637, "Orgrimmar")
	Stamp("dungeon", "wc", "Cavernes des lamentations"); Stamp("level", 10, "Niveau 10"); Stamp("level", 20, "Niveau 20")
	-- bestiaire des Tarides : abattus, vus, nommés (élite, rare, rare élite)
	journal.bestiary = { [1413] = {
		[3110] = { name = "Crocilisque Gueule-d'effroi", seen = true, killed = 6 },
		[3236] = { name = "Kodo des Tarides", seen = true, killed = 3 },
		[3242] = { name = "Messager zhévra", seen = true, killed = 0 },
		[3243] = { name = "Grande crinière des savanes", seen = true, killed = 2 },
		[3248] = { name = "Girafe des Tarides", seen = true, killed = 0 },
		[3253] = { name = "Moissonneur silithide", seen = true, killed = 1 },
		[3270] = { name = "Ancienne mystique Tranchegroin", seen = true, killed = 0 },
		[3398] = { name = "Gesharahan", seen = true, killed = 1 },
		[3630] = { name = "Embobineur déviant", seen = true, killed = 0 },
		[3631] = { name = "Aiguillonneur déviant", seen = true, killed = 4 },
	} }
	local treats = ns.TreatData and ns:TreatData()
	if treats then
		treats.treatsInit = true
		treats.pantry.biscuit, treats.pantry.bonbon, treats.pantry.infusion, treats.pantry.carte = 2, 1, 3, 0
		treats.milestones[1413] = 25
	end
	return ns
end

local function QCJournal(T, kind, prepare)
	local ns = QCWorld(T)
	if prepare then prepare(ns) end
	ns:ToggleJournal(true)
	ns:SelectJournalKind(kind)
	return Centered(ns.journalFrame), ns
end

Snap.scenes["qc-journal-creature"] = function(T)
	local frame = QCJournal(T, "evolution", function(ns)
		ns:ChestData()[1411] = { tier = 1, name = "Durotar", at = 0 }
		-- 3.5.0 : deux états actifs, une envie
		ns:CompanionGrant("hunger"); ns:CompanionGrant("energy", ns.COMPANION_STATE.max)
		ns:CompanionData().wish = { key = "curiosity" }
	end)
	return frame, "QuestCompanion : carnet, page Créature"
end

-- page Complétion sur Les Tarides : liste des zones, carte (%, paliers), parts,
-- liste des villages et ligne du bestiaire (remplace les pages Zones et Zone)
Snap.scenes["qc-journal-progress"] = function(T)
	local frame = QCJournal(T, "progress", function(ns)
		-- deux villages des Tarides sur trois (La Croisée déjà tamponnée, Cabestan)
		ns:JournalData().stamps["subzone:392"] = { id = "subzone:392", kind = "subzone", name = "Cabestan", at = 0 }
	end)
	return frame, "QuestCompanion : carnet, page Complétion (Les Tarides)"
end

Snap.scenes["qc-journal-day"] = function(T)
	local frame = QCJournal(T, "day", function(ns)
		ns:DailyPoll()
		local daily, inn = ns:DailyData()
		if daily.missions[1] then daily.missions[1].have = math.max(1, math.floor(daily.missions[1].need / 2)) end
		if daily.missions[2] then daily.missions[2].have, daily.missions[2].done = daily.missions[2].need, true end
		inn.card, inn.total, inn.full = 4, 11, 1
		daily.perfect = 3
		local weekly = ns.WeeklyCurrent and ns:WeeklyCurrent()
		if weekly and weekly.missions[1] then weekly.missions[1].have = 2 end
		if weekly and weekly.missions[2] then weekly.missions[2].have, weekly.missions[2].done = weekly.missions[2].need, true end
		local items = ns:CaptureData().items
		items.appat, items.lasso, items.sifflet = 4, 1, 0
	end)
	return frame, "QuestCompanion : carnet, page Missions"
end

Snap.scenes["qc-journal-menagerie"] = function(T)
	local frame = QCJournal(T, "menagerie", function(ns)
		-- les Tarides de la table livrée : quelques espèces croisées, abattues,
		-- capturées (une brillante), le reste en « ??? »
		local all = rawget(ns, "ZONE_CREATURES") or {}
		local zone = all[1413] or {}
		local ids = {}
		for npc in pairs(zone) do ids[#ids + 1] = npc end
		table.sort(ids)
		local book = ns:BestiaryData()
		book[1413] = {}
		local data = ns:CaptureData()
		for index, npc in ipairs(ids) do
			if index % 3 ~= 0 and index <= 30 then
				local entry = zone[npc]
				local lvl = type(entry.lvl) == "table" and entry.lvl[1] or 15
				book[1413][npc] = { name = entry.fr, seen = true, killed = index % 2, level = lvl,
					type = ({ "Bête", "Humanoïde", "Élémentaire", "Bête" })[index % 4 + 1] }
				if index % 4 == 1 then
					data.creatures[npc] = { name = entry.fr, zoneID = 1413, at = 1793500000 + index,
						class = (ns.BESTIARY_RANK_CLASS or {})[tonumber(entry.rank) or 0] or "normal", shiny = index == 5 or nil }
				end
			end
		end
		data.count = 0
		for _ in pairs(data.creatures) do data.count = data.count + 1 end
		ns.menagerieStatic = nil
	end)
	return frame, "QuestCompanion : carnet, page Ménagerie (Les Tarides, filtres et recherche)"
end

-- page Guide (2.3.0) : le sommaire à gauche, la section « Ton compagnon
-- chasse avec toi » à droite, avec la table des huit types
Snap.scenes["qc-journal-guide"] = function(T)
	local frame, ns = QCJournal(T, "guide")
	ns:JournalGuidePick("effects")
	return frame, "QuestCompanion : carnet, page Guide (la table des types)"
end

-- 3.1.0 : les scènes du carnet forgé tirent leurs nombres au hasard d'un
-- générateur à elles : « all » rend les scènes à la suite dans le même
-- état, et les tirages des suivantes (capture, chances) restent les mêmes
local function OwnDraws(T, scene)
	local saved, seed = math.random, 7
	math.random = function(a, b)
		seed = (seed * 1103515245 + 12345) % 2147483648
		local r = seed / 2147483648
		if not a then return r end
		if not b then return 1 + math.floor(r * a) end
		return a + math.floor(r * (b - a + 1))
	end
	local ok, frame, title = pcall(scene, T)
	math.random = saved
	if not ok then error(frame, 0) end
	return frame, title
end

-- 3.7.0 : page Hauts faits refaite (maquette carnet-j1 à j3) : une collection
-- en cours, des hauts faits obtenus et datés, un rattrapage, un suivi ; deux
-- secrets (un indice connu), un découvert, un tour de force
local function FeatsWorld(ns)
	ns:DB().featsFilter = "all"
	if rawget(_G, "date") == nil then _G.date = os.date end
	local data = ns:CaptureData()
	for index = 1, 37 do
		data.creatures[90000 + index] = { name = "Créature " .. index, normal = true, class = "normal", type = "Bête",
			shiny = index <= 3 or nil, at = 1793000000 + index }
	end
	data.count = 37
	ns.menagerieStatic = nil
	-- secrets et tour de force du catalogue (deuxième édition) : un secret découvert,
	-- un indice lâché, « Pionnier » obtenu
	ns:FeatStore("account").hints = { fun_hogger_partner = 1793000000 }
	local at = 1793500000
	for index, id in ipairs({ "men_first", "men_species_10", "men_species_25", "char_level_10", "char_level_20", "zone_visit_10",
		"day_mission_1", "shiny_found_5", "men_rare_1", "fun_namesake", "fos_pioneer" }) do
		ns:FeatAward(id, { silent = true, at = at + index * 86400 })
	end
	ns:FeatStore("account").catchup = { v = 1, ids = { "men_first", "men_species_10", "men_species_25", "char_level_10",
		"char_level_20", "zone_visit_10" }, pts = 40, glitter = 22 }
	ns:FeatFollow("men_species_50", true)
end

Snap.scenes["qc-journal-feats"] = function(T) return OwnDraws(T, function(T)
	local frame = QCJournal(T, "feats", FeatsWorld)
	return frame, "QuestCompanion : carnet, page Hauts faits (Aperçu)"
end) end

-- une catégorie avec des séries et une ligne dépliée (Dresseur › Créatures)
Snap.scenes["qc-journal-feats-list"] = function(T) return OwnDraws(T, function(T)
	local frame, ns = QCJournal(T, "feats", FeatsWorld)
	ns:OpenJournalFeatsAt("men_types_master")
	return frame, "QuestCompanion : carnet, Hauts faits › Créatures (séries, ligne dépliée)"
end) end

-- Insolite : secrets (indice connu ou non), secret découvert, la note
Snap.scenes["qc-journal-feats-secrets"] = function(T) return OwnDraws(T, function(T)
	local frame, ns = QCJournal(T, "feats", FeatsWorld)
	ns:JournalFeatsPick("fun")
	ns.journalFrame.featsOffset = 99      -- la fin de la liste : secrets, découvert, la note
	ns:RefreshJournal()
	return frame, "QuestCompanion : carnet, Hauts faits › Insolite (secrets)"
end) end

-- tours de force : leur catégorie à eux
Snap.scenes["qc-journal-feats-fos"] = function(T) return OwnDraws(T, function(T)
	local frame, ns = QCJournal(T, "feats", FeatsWorld)
	ns:JournalFeatsPick("fos")
	return frame, "QuestCompanion : carnet, Hauts faits › Tours de force"
end) end

-- 3.7.0 (C1b) : onglet Titres (maquette carnet-j4) : des titres gagnés (un
-- tour de force), un titre choisi, la liste à gagner
Snap.scenes["qc-journal-feats-titles"] = function(T) return OwnDraws(T, function(T)
	local frame, ns = QCJournal(T, "feats", function(ns)
		FeatsWorld(ns)
		local at = 1794500000
		for index, id in ipairs({ "men_rare_10", "shiny_found_50", "shiny_cap_25", "zone_all_biomes", "char_level_60",
			"men_bad_luck", "men_species_50", "men_species_100", "men_species_250" }) do
			ns:FeatAward(id, { silent = true, at = at + index * 3600 })
		end
		ns:FeatSetTitle(13)
	end)
	ns:JournalFeatsTab("titles")
	return frame, "QuestCompanion : carnet, Hauts faits › Titres"
end) end

-- 3.7.0 (C1b) : onglet Statistiques (maquette carnet-j5) : la sauvegarde
-- d'une collection en cours et des compteurs depuis la 3.7
local function StatsWorld(ns)
	FeatsWorld(ns)
	local data = ns:CaptureData()
	data.caught, data.tries, data.paillettesEarned = 1412, 2655, 6240
	data.study = data.study or {}
	data.studyV = ns.STUDY_SCHEMA
	data.study[90001] = { n = 37, z = 0, t = 0, paid = 0, lo = 88, hi = 124 }
	data.study[90002] = { n = 12, z = 0, t = 0, paid = 0, lo = 76, hi = 101 }
	data.creatures[90001].name, data.creatures[90002].name = "Raptor de Strangleronce", "Lapin"
	ns:CompanionData().travel = 412000
	for key, value in pairs({ captureHunt = 640, glitterSpent = 1180, release = 212, orderDone = 8 }) do ns:TallyAdd(key, value) end
	ns:TallyMax("captureStreak", 17)
	ns:TallyMax("shinyChain", 50)
	for key, value in pairs({ radiantMin = 560, wish = 23, treat = 61 }) do ns:TallyAdd(key, value, "char") end
	ns:FeatStore("account").ctr.trades = 3
end

Snap.scenes["qc-journal-feats-stats"] = function(T) return OwnDraws(T, function(T)
	local frame, ns = QCJournal(T, "feats", StatsWorld)
	ns:JournalFeatsTab("stats")
	return frame, "QuestCompanion : carnet, Hauts faits › Statistiques"
end) end

-- le suivi à l'écran avec un haut fait suivi
Snap.scenes["qc-tracker-feat"] = function(T)
	local ns = QCWorld(T)
	ns:DB().journalTracker = true
	FeatsWorld(ns)
	ns:RefreshJournalTracker()
	local tracker = ns.journalTracker
	tracker:ClearAllPoints()
	tracker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return tracker, "QuestCompanion : suivi à l'écran, un haut fait suivi"
end

-- 3.7.0 : page Communauté (JournalCommunity.lua). Le banc n'a pas de champ
-- sur plusieurs lignes : le temps de la scène, CreateFrame donne aux champs
-- SetMultiLine (l'aperçu fait alors revenir leur texte à la ligne).
local function WithMultiLine(scene)
	local create = _G.CreateFrame
	_G.CreateFrame = function(kind, ...)
		local frame = create(kind, ...)
		if kind == "EditBox" and frame.SetMultiLine == nil then
			function frame:SetMultiLine(on) self.multiLine = on and true or nil end
		end
		return frame
	end
	local ok, frame, title = pcall(scene)
	_G.CreateFrame = create
	if not ok then error(frame, 0) end
	return frame, title
end

local function QCCommunity(T, tab, prepare)
	local frame, ns = QCJournal(T, "community", function(ns)
		ns:DB().community = nil
		ns:CommunityResetAnswers()
		ns:CaptureData().count = 312
		if prepare then prepare(ns) end
	end)
	ns:CommunitySelectTab(tab)
	return frame, ns
end

-- onglet Discord : l'invitation à copier, les cinq salons, le mot, cette semaine
Snap.scenes["qc-journal-community-discord"] = function(T) return OwnDraws(T, function(T)
	return WithMultiLine(function()
		local frame = QCCommunity(T, "discord")
		return frame, "QuestCompanion : carnet, page Communauté (onglet Discord)"
	end)
end) end

-- onglet Ton avis : trois réponses, un texte libre, l'avis composé dans la zone à copier
Snap.scenes["qc-journal-community-avis"] = function(T) return OwnDraws(T, function(T)
	return WithMultiLine(function()
		local saved = _G.UnitLevel
		_G.UnitLevel = function() return 38 end
		local frame, ns = QCCommunity(T, "avis", function(ns)
			ns:CommunityAnswer("love", 1)
			ns:CommunityAnswer("talk", 2)
			ns:CommunityAnswer("fav", 1)
			ns:CommunitySetFree("Pouvoir trier la Réserve par zone de capture. Et une créature de la semaine pour les niveaux 60.")
		end)
		ns:CommunityAvisPaint()
		_G.UnitLevel = saved
		return frame, "QuestCompanion : carnet, page Communauté (onglet Ton avis)"
	end)
end) end

-- 3.7.0 (étape 3, S2) : onglet Dresseurs (TrainerKnown.lua), comme la
-- maquette carnet-c1 : quatre dresseurs connus (un croisé en guilde, trois
-- reçus par code dont un d'un autre royaume et un de l'autre faction),
-- l'encadré du parrainage ouvert. « -empty » : aucun dresseur connu.
local function TrainersWorld(ns, filled)
	ns:DB().trainerKnown, ns:DB().trainerMentor = nil, nil
	ns:CaptureData().firstAt = time()
	if rawget(_G, "UnitFactionGroup") == nil then _G.UnitFactionGroup = function() return "Alliance" end end
	if not filled then return end
	local day = 1795219200 + 12 * 3600   -- 21/11/2026, midi
	local specs = {
		{ "Xan-Royaume", "Maîtresse des brillantes", 1000, 105, 287, 9, "guild", nil, day, "AB" },
		{ "Deklatis-Royaume", "Dresseur confirmé", 600, 20, 96, 2, "code", "A", day - 86400, "A" },
		{ "Brakmar-Hyjal", nil, 2000, 40, 512, 31, "code", "A", day - 3 * 86400, nil },
		{ "Zugzug-Royaume", "le Traqueur", 1300, 80, 301, 12, "code", "H", day - 6 * 86400, "AB" },
	}
	for _, spec in ipairs(specs) do
		local card = { name = spec[1], title = spec[2], feats = { account = spec[3], char = spec[4], count = 100 },
			species = spec[5], shinies = spec[6], showcase = {}, badges = {}, featBits = spec[10] }
		ns:TrainerKnownAdd(card, spec[7], { faction = spec[8] })
		local list = ns:TrainerKnownData().list
		list[#list].at = spec[9]
	end
	ns:TrainerKnownResetSession()
end

Snap.scenes["qc-journal-community-dresseurs"] = function(T) return OwnDraws(T, function(T)
	return WithMultiLine(function()
		local frame = QCCommunity(T, "dresseurs", function(ns) TrainersWorld(ns, true) end)
		return frame, "QuestCompanion : carnet, page Communauté (onglet Dresseurs)"
	end)
end) end

Snap.scenes["qc-journal-community-dresseurs-empty"] = function(T) return OwnDraws(T, function(T)
	return WithMultiLine(function()
		local frame = QCCommunity(T, "dresseurs", function(ns) TrainersWorld(ns, false) end)
		return frame, "QuestCompanion : carnet, page Communauté (onglet Dresseurs, aucun dresseur connu)"
	end)
end) end

-- 3.1.0 : page Réserve (quelques spécimens, une brillante)
Snap.scenes["qc-journal-reserve"] = function(T) return OwnDraws(T, function(T)
	local frame = QCJournal(T, "reserve", function(ns)
		local Z = 1413
		ns:SpecimenAdd({ npc = 3236, stars = 1, name = "Kodo des Tarides", origin = "capture", by = "Testeur", zone = Z, at = 1793500000 })
		ns:SpecimenAdd({ npc = 3236, stars = 2, name = "Kodo des Tarides", origin = "capture", by = "Testeur", zone = Z, at = 1793600000 })
		ns:SpecimenAdd({ npc = 3236, stars = 3, name = "Kodo des Tarides", origin = "capture", by = "Testeur", zone = Z, at = 1793650000 })
		ns:SpecimenAdd({ npc = 3110, stars = 1, name = "Crocilisque Gueule-d'effroi", origin = "capture", by = "Testeur", zone = Z, at = 1793400000 })
		ns:SpecimenAdd({ npc = 3110, stars = 2, name = "Crocilisque Gueule-d'effroi", origin = "capture", by = "Testeur", zone = Z, at = 1793450000 })
		ns:SpecimenAdd({ npc = 3242, stars = 1, shiny = true, name = "Messager zhévra", zone = Z, at = 1793300000 })
		ns:SpecimenAdd({ npc = 3242, stars = 1, shiny = true, name = "Messager zhévra", zone = Z, at = 1793700000 })
	end)
	return frame, "QuestCompanion : carnet, page Réserve"
end) end

-- 3.2.1 : Réserve presque pleine, « Faire de la place » sur sa rangée
Snap.scenes["qc-journal-reserve-full"] = function(T) return OwnDraws(T, function(T)
	local frame = QCJournal(T, "reserve", function(ns)
		local npcs = { 3236, 3110, 3242, 3415, 3255 }
		for index = 1, (ns.RESERVE_MAX or 30) - 1 do
			ns:SpecimenAdd({ npc = npcs[index % #npcs + 1], stars = index % 3 + 1, name = "Spécimen " .. index,
				origin = "capture", by = "Testeur", zone = 1413, at = 1793000000 + index })
		end
	end)
	return frame, "QuestCompanion : carnet, Réserve presque pleine (Faire de la place)"
end) end

-- 3.3.1 : la liste « Filtre » ouverte (tous, brillants, tailles, caractères)
Snap.scenes["qc-journal-reserve-filter"] = function(T) return OwnDraws(T, function(T)
	local frame = QCJournal(T, "reserve", function(ns)
		for index = 1, 8 do
			ns:SpecimenAdd({ npc = 3236, stars = index % 3 + 1, name = "Kodo des Tarides", origin = "capture", by = "Testeur",
				zone = 1413, at = 1793000000 + index })
		end
	end)
	-- 3.4.0 : le panneau de filtres, une taille cochée
	T.QNS:ReserveToggleFilter("stars", 2)
	T.QNS:ReservePanelOpen(true)
	return frame, "QuestCompanion : carnet, Réserve, panneau de filtres ouvert"
end) end

-- 3.4.0 : la sélection par lot (barre de lot, fiche de la sélection)
Snap.scenes["qc-journal-reserve-select"] = function(T) return OwnDraws(T, function(T)
	local frame = QCJournal(T, "reserve", function(ns)
		local npcs = { 3236, 3110, 3242, 3415, 3255 }
		for index = 1, 46 do
			ns:SpecimenAdd({ npc = npcs[index % #npcs + 1], stars = index % 3 + 1, name = "Spécimen " .. index,
				origin = "capture", by = "Testeur", zone = 1413, at = 1793000000 + index })
		end
	end)
	T.QNS:ReserveTidyStart()
	local first = T.QNS:ReserveBrowseList("res")[8]
	if first then T.QNS:SpecimenProtect(first.id, true); T.QNS:ReserveTidyToggle(first.id) end
	return frame, "QuestCompanion : carnet, Réserve, Faire de la place (sélection par lot)"
end) end

-- 3.4.0 : l'Échoppe de la semaine (aides en stock, places, surnom, arrivage, commandes)
Snap.scenes["qc-journal-shop"] = function(T) return OwnDraws(T, function(T)
	local frame = QCJournal(T, "shop", function(ns)
		ns:PaillettesAdd(64, "snap")
		for index = 1, 6 do
			ns:SpecimenAdd({ npc = 3236, stars = index % 3 + 1, name = "Kodo des Tarides", origin = "capture", by = "Testeur",
				zone = 1413, at = 1793000000 + index })
		end
	end)
	return frame, "QuestCompanion : carnet, Échoppe du dresseur (3.4)"
end) end

-- 3.6.0 : l'Échoppe d'un gros joueur (hors de leur semaine, mécénat, relance payante)
Snap.scenes["qc-journal-shop-36"] = function(T) return OwnDraws(T, function(T)
	local frame = QCJournal(T, "shop", function(ns)
		ns:PaillettesAdd(640, "snap")
		ns:CaptureData().patron = 7
		for index = 1, 6 do
			ns:SpecimenAdd({ npc = 3236, stars = index % 3 + 1, name = "Kodo des Tarides", origin = "capture", by = "Testeur",
				zone = 1413, at = 1793000000 + index })
		end
		ns:ShopOrdersReroll()
	end)
	return frame, "QuestCompanion : carnet, Échoppe du dresseur (3.6 : hors de leur semaine, mécénat, relance à 10)"
end) end

-- 3.6.0 : la fiche d'un spécimen au demi-tarif du jour
Snap.scenes["qc-journal-reserve-half"] = function(T) return OwnDraws(T, function(T)
	local frame = QCJournal(T, "reserve", function(ns)
		ns:SpecimenAdd({ npc = 3236, stars = 1, name = "Kodo des Tarides", origin = "capture", by = "Testeur", zone = 1413, at = 1793500000 })
		ns:SpecimenAdd({ npc = 3236, stars = 3, name = "Kodo des Tarides", origin = "capture", by = "Testeur", zone = 1413, at = 1793650000 })
		ns:SpecimenAdd({ npc = 3236, stars = 2, name = "Kodo des Tarides", origin = "capture", by = "Testeur", zone = 1413, at = 1793600000 })
		ns:CaptureData().releaseDay = { day = ns.CaptureDayKey(), n = 120 }
	end)
	local list = T.QNS:SpecimenList({ where = "reserve", sort = "id" })
	if list[1] then T.QNS:ReservePick(list[1].id) end
	return frame, "QuestCompanion : carnet, Réserve, fiche au demi-tarif du jour (3.6)"
end) end

-- 3.6.0 : une espèce maîtrisée sur la page Créatures (sa ligne d'étude)
Snap.scenes["qc-journal-menagerie-mastered"] = function(T)
	local frame, ns = Snap.scenes["qc-journal-menagerie"](T)
	ns = T.QNS
	local study = ns:CaptureData().study or {}
	ns:CaptureData().study, ns:CaptureData().studyV = study, ns.STUDY_SCHEMA
	for npc in pairs(ns:CaptureData().creatures) do
		study[npc] = { n = 6, z = 7, t = 7, s3 = true, paid = 63, lo = 88, hi = 121 }
	end
	ns:RefreshJournal()
	-- la fiche d'une espèce capturée (la ligne d'étude)
	for _, row in ipairs(frame.men and frame.men.items or {}) do
		if row.entry and row.entry.captured then ns:JournalPreviewMenagerie(row.entry, true); break end
	end
	return frame, "QuestCompanion : carnet, Créatures, espèce maîtrisée (3.6)"
end

-- 3.1.0 : page Juke-box
Snap.scenes["qc-journal-juke"] = function(T) return OwnDraws(T, function(T)
	local frame = QCJournal(T, "juke")
	return frame, "QuestCompanion : carnet, page Juke-box"
end) end

-- 3.1.0 : la fiche de dresseur (médaillon, portrait encadré, vitrine en creux)
Snap.scenes["qc-trainer"] = function(T) return OwnDraws(T, function(T)
	local ns = QCWorld(T)
	ns:FeatAward("men_first", { silent = true, at = 1700000000 })
	ns:FeatAward("char_level_10", { silent = true, at = 1700100000 })
	ns:FeatAward("char_level_20", { silent = true, at = 1700200000 })
	if ns.journalFrame then ns.journalFrame:Hide() end
	ns.trainerFrame = nil
	local frame = ns:TrainerOpen()
	if frame and frame.model then frame.model:Hide() end
	return Centered(frame), "QuestCompanion : fiche de dresseur"
end) end

-- 3.6.0 : la fiche de dresseur avec un fond et un cadre gagnés, des médailles de type
Snap.scenes["qc-trainer-style"] = function(T) return OwnDraws(T, function(T)
	local ns = QCWorld(T)
	ns:FeatAward("men_first", { silent = true, at = 1700000000 })
	local data = ns:CompanionData()
	data.unlocked["cardbg:" .. (rawget(_G, "SNAP_CARD_BG") or "card_pantheon")] = true
	data.unlocked["cardframe:" .. (rawget(_G, "SNAP_CARD_FRAME") or "card_laurels")] = true
	data.cardStyle = { bg = rawget(_G, "SNAP_CARD_BG") or "card_pantheon", frame = rawget(_G, "SNAP_CARD_FRAME") or "card_laurels" }
	local creatures = ns:CaptureData().creatures
	for index = 1, 170 do creatures[90000 + index] = { name = "Bête " .. index, normal = true, stars = 2, class = "normal", type = "Bête" } end
	for index = 1, 85 do creatures[91000 + index] = { name = "Humanoïde " .. index, normal = true, stars = 2, class = "normal", type = "Humanoïde" } end
	for index = 1, 22 do creatures[92000 + index] = { name = "Démon " .. index, normal = true, stars = 2, class = "normal", type = "Démon" } end
	if ns.journalFrame then ns.journalFrame:Hide() end
	ns.trainerFrame = nil
	local frame = ns:TrainerOpen()
	if frame and frame.model then frame.model:Hide() end
	return Centered(frame), "QuestCompanion : fiche de dresseur, fond et cadre (3.6)"
end) end

-- 3.7.0 : la fiche de dresseur, rang sous le nom, signature, Pionnier, boutons
-- de l'étape 3 (fonctions simulées), habillage `bg` / `frame` (ids du catalogue)
local function TrainerStyled(T, bg, frame)
	local ns = QCWorld(T)
	ns:FeatAward("men_first", { silent = true, at = 1700000000 })
	ns:CaptureData().creatures[3098] = ns:CaptureData().creatures[3098]
		or { name = "Sanglier", class = "normal", normal = true, stars = 2, type = "Bête", at = 1793700000, firstAt = 1793700000 }
	local pioneer = ns:FeatDef("fos_pioneer")
	if not pioneer then
		local n = 980
		while ns:FeatDefByCode(n) do n = n + 1 end
		pioneer = ns.FeatAdd({ "fos_pioneer", n, "fos", 0, "account", crit = { "flag", "snap_pioneer" } })
	end
	ns:FeatAward(pioneer, { silent = true, at = 1700000000 })
	-- assez de hauts faits pour un rang (1 000 points et plus)
	for _, def in ipairs(ns:FeatDefs()) do
		if (ns:FeatPoints(nil)) >= 1240 then break end
		if ns:FeatCountable(def) and not def.hidden and not ns:FeatGot(def) then ns:FeatAward(def, { silent = true, at = 1700300000 }) end
	end
	local data = ns:CompanionData()
	data.cardStyle = {}
	if bg then data.unlocked["cardbg:" .. bg] = true; data.cardStyle.bg = bg end
	if frame then data.unlocked["cardframe:" .. frame] = true; data.cardStyle.frame = frame end
	ns.TrainerCodeShow = ns.TrainerCodeShow or function() end
	ns.SouvenirShow = ns.SouvenirShow or function() end
	if ns.journalFrame then ns.journalFrame:Hide() end
	ns.trainerFrame = nil
	local f = ns:TrainerOpen()
	if f and f.model then f.model:Hide() end
	return Centered(f)
end

Snap.scenes["qc-trainer-rank"] = function(T) return OwnDraws(T, function(T)
	return TrainerStyled(T, nil, "card_rank_silver"), "QuestCompanion : fiche de dresseur, rang, signature, Pionnier (3.7)"
end) end

-- 3.7.0 : chacun des neuf habillages neufs, sur la fiche
Snap.scenes["qc-trainer-card_rank_bronze"] = function(T) return OwnDraws(T, function(T)
	return TrainerStyled(T, nil, "card_rank_bronze"), "QuestCompanion : cadre de fiche « Rang de bronze » (3.7)" end) end
Snap.scenes["qc-trainer-card_rank_silver"] = function(T) return OwnDraws(T, function(T)
	return TrainerStyled(T, nil, "card_rank_silver"), "QuestCompanion : cadre de fiche « Rang d'argent » (3.7)" end) end
Snap.scenes["qc-trainer-card_rank_gold"] = function(T) return OwnDraws(T, function(T)
	return TrainerStyled(T, nil, "card_rank_gold"), "QuestCompanion : cadre de fiche « Rang d'or » (3.7)" end) end
Snap.scenes["qc-trainer-card_rank_glow"] = function(T) return OwnDraws(T, function(T)
	return TrainerStyled(T, nil, "card_rank_glow"), "QuestCompanion : cadre de fiche « Rang de lumière » (3.7)" end) end
Snap.scenes["qc-trainer-card_eight"] = function(T) return OwnDraws(T, function(T)
	return TrainerStyled(T, nil, "card_eight"), "QuestCompanion : cadre de fiche « Huit spécialités » (3.7)" end) end
Snap.scenes["qc-trainer-card_prism"] = function(T) return OwnDraws(T, function(T)
	return TrainerStyled(T, nil, "card_prism"), "QuestCompanion : cadre de fiche « Prisme » (3.7)" end) end
Snap.scenes["qc-trainer-card_zoology"] = function(T) return OwnDraws(T, function(T)
	return TrainerStyled(T, "card_zoology", nil), "QuestCompanion : fond de fiche « Planche de naturaliste » (3.7)" end) end
Snap.scenes["qc-trainer-card_gold_zones"] = function(T) return OwnDraws(T, function(T)
	return TrainerStyled(T, "card_gold_zones", nil), "QuestCompanion : fond de fiche « Carte dorée » (3.7)" end) end
Snap.scenes["qc-trainer-card_directory"] = function(T) return OwnDraws(T, function(T)
	return TrainerStyled(T, "card_directory", nil), "QuestCompanion : fond de fiche « Carnet d'adresses » (3.7)" end) end

-- 3.7.0 : comparer les hauts faits avec la fiche reçue d'un autre dresseur
Snap.scenes["qc-trainer-compare"] = function(T) return OwnDraws(T, function(T)
	local ns = QCWorld(T)
	-- mes hauts faits : un sur deux des premiers ; les siens : un sur trois
	local mine, theirs, count = {}, {}, 0
	for _, def in ipairs(ns:FeatDefs()) do
		if ns:FeatCountable(def) and not def.hidden and def.cat ~= "fos" then
			count = count + 1
			if count % 2 == 0 and count < 60 then mine[#mine + 1] = def end
			if count % 3 == 0 and count < 60 then theirs[tonumber(def.n)] = true end
		end
	end
	for _, def in ipairs(mine) do ns:FeatAward(def, { silent = true, at = 1700000000 }) end
	local text = "p=1;n=Xan;ti=19;tg=f;ap=1310;aq=0;ac=131;fb=" .. ns:FeatBits(theirs)
	for _, chunk in ipairs(ns:TrainerChunks(text, 3)) do ns:TrainerOnAddonMessage("QCTrainer", chunk, "WHISPER", "Xan-Royaume") end
	if ns.journalFrame then ns.journalFrame:Hide() end
	_G.time = function() return 1795219200 end   -- la fiche « reçue » le 21/11 (date du sous-titre)
	local w = ns:TrainerCompareOpen("Xan-Royaume")
	return Centered(w), "QuestCompanion : comparer les hauts faits (3.7)"
end) end

-- 3.1.0 : le panneau « Choisir son allure » au-dessus du carnet
Snap.scenes["qc-allure"] = function(T) return OwnDraws(T, function(T)
	local _, ns = QCJournal(T, "evolution")
	local panel = ns:AllureOpen()
	return panel, "QuestCompanion : carnet, Choisir son allure"
end) end

-- 3.1.0 : la confirmation du carnet (changer de compagnon)
Snap.scenes["qc-journal-confirm"] = function(T) return OwnDraws(T, function(T)
	local _, ns = QCJournal(T, "evolution")
	local dialog = ns:EnsureEffectsConfirm()
	dialog.text:SetText(ns.L.EFF_CONFIRM_SUB or "")
	ns:EffectsConfirmPlace(dialog)
	dialog:Show()
	return dialog, "QuestCompanion : carnet, Changer de compagnon ?"
end) end

-- 3.1.0 : le carnet forgé en saison du Voile d'hiver (guirlande, cadeau et
-- renne autour du titre de la marque, flocons)
Snap.scenes["qc-journal-winter"] = function(T) return OwnDraws(T, function(T)
	local frame = QCJournal(T, "evolution", function(ns)
		ns:DB().winterVeil = "on"
	end)
	return frame, "QuestCompanion : carnet, Voile d'hiver"
end) end

-- le compagnon à l'écran : cadre (cadre cuivre, fond sous-bois), nom, bulle
local function QCCompanion(T, prepare)
	local ns = QCWorld(T)
	local data = ns:CompanionData()
	data.frameStyle, data.background = "copper", "forest"
	if prepare then prepare(ns) end
	ns:CompanionUpdateVisibility()
	local frame = ns.companionFrame
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 120, -60)
	-- pas de 3D hors du jeu : la boussole de repli tient la place du modèle
	if frame.model then frame.model:Hide() end
	frame.fallback:Show()
	return ns, frame
end

Snap.scenes["qc-companion"] = function(T)
	local ns, frame = QCCompanion(T)
	ns:CompanionSay("HELLO", { force = true, line = "COMP_SAY_HELLO", args = { ns:CompanionName() } })
	return Snap.Group(frame, ns.companionBubble), "QuestCompanion : le compagnon à l'écran et sa bulle"
end

Snap.scenes["qc-companion-hover"] = function(T)
	local ns, frame = QCCompanion(T)
	ns:CompanionShowHover()
	return Snap.Group(frame, ns.companionHover), "QuestCompanion : la fiche au survol du compagnon"
end

-- 3.1.0 : le médaillon forgé. Cadre gagné « Givre » : l'anneau prend sa
-- teinte (argent-bleu) et son halo glacé (point lumineux sans l'atlas)
Snap.scenes["qc-companion-frame-tint"] = function(T)
	local ns, frame = QCCompanion(T, function(n)
		local data = n:CompanionData()
		data.unlocked["frame:frost"] = true
		data.frameStyle = "frost"
	end)
	ns:CompanionApplyFrame()
	return frame, "QuestCompanion : médaillon forgé, cadre gagné Givre (teinte et halo de l'anneau)"
end

-- il parle : bulle forgée (nom de qui parle en capitales), lueur ronde qui
-- respire, reflet de la réplique saisi en pleine traversée
Snap.scenes["qc-companion-talk"] = function(T)
	local ns, frame = QCCompanion(T)
	ns:CompanionSay("HELLO", { force = true, line = "COMP_SAY_HELLO", args = { ns:CompanionName() } })
	local now = ns.Now()
	ns:GlowUpdate(now + 0.55)
	if ns.AzerothFxStep then ns.AzerothFxStep(now + 0.35) end
	return Snap.Group(frame, ns.companionBubble), "QuestCompanion : il parle (bulle forgée, lueur ronde, reflet)"
end

-- 3.7.0, étape 3, S3 : la bulle de bonjour dit où l'on en était (TripRecap.lua),
-- par la vraie connexion (somnolent après une absence) : 98 espèces sur 100
Snap.scenes["qc-companion-hello"] = function(T)
	local ns, frame = QCCompanion(T)
	local dormant, rested = ns.featsDormant, ns.companionRestedDormant
	ns.featsDormant, ns.companionRestedDormant = false, true
	local capture = ns:CaptureData()
	capture.creatures, capture.caught = {}, 0
	for index = 1, 98 do capture.creatures[80000 + index] = { name = "Bête", normal = true, stars = 1 } end
	ns:CompanionData().lastSeen = (time() or 0) - 10 * 3600
	ns:CompanionLogin()
	ns.featsDormant, ns.companionRestedDormant = dormant, rested
	return Snap.Group(frame, ns.companionBubble), "QuestCompanion : bulle de bonjour, le haut fait le plus proche (3.7)"
end

-- 3.1.0 (bêta 9) : les pastilles de la capture express sous le compagnon,
-- sous l'étiquette d'humeur, la plus récente contre lui ; la bulle au-dessus
-- et le filet à côté restent libres
Snap.scenes["qc-capture-express-feed"] = function(T)
	local ns, frame = QCCompanion(T)
	ns.captureExpressDormant = nil
	ns:CompanionSay("HELLO", { force = true, line = "COMP_SAY_HELLO", args = { ns:CompanionName() } })
	-- (les étoiles sont des icônes du client, |A…|a : l'aperçu ne les dessine pas)
	ns:CaptureExpressPush("ok", "Raptor des Tarides", "")
	ns:CaptureExpressPush("fail", "Sanglier", ns.L.CAPTURE_X_FLED)
	ns:CaptureExpressPush("notable", "Golem lézardé", ns.L.CAPTURE_X_NEW)
	ns:CaptureExpressUpdate(ns.Now() + 0.5)
	local net = ns:EnsureCaptureNet()
	net:Show()
	return Snap.Group(frame, ns.companionBubble, net, ns.captureExpressFeed),
		"QuestCompanion : pastilles de capture sous le compagnon (la plus récente contre lui)"
end

-- humeur au plus bas (« rêveur ») : l'étiquette change de teinte ; et l'effet
-- « Niveau 24 ! » (filets lumineux, lueur et poussière en points lumineux)
Snap.scenes["qc-companion-sad"] = function(T)
	local ns, frame = QCCompanion(T, function(n)
		n:CompanionData().needs = { hunger = 20, energy = 30, mood = 25, curiosity = 15 }
	end)
	ns:CompanionRefreshLabels()
	ns:CompanionLevelFX(ns:F("AZ_FX_LEVEL", 24), "level")
	if ns.AzerothFxStep then ns.AzerothFxStep(ns.Now() + 0.9) end
	local group = frame.azLevel and frame.azLevel.group
	return Snap.Group(frame, group), "QuestCompanion : humeur « rêveur » et effet « Niveau 24 ! » (médaillon forgé)"
end

-- Voile d'hiver : flocons aux coins, guirlande posée sur la bande d'or (le
-- modèle 3D de la guirlande ne se dessine pas hors du jeu), anneau Givre
Snap.scenes["qc-companion-winter"] = function(T)
	local ns, frame = QCCompanion(T, function(n) n:DB().winterVeil = "on" end)
	ns:WinterVeilApply()
	return frame, "QuestCompanion : médaillon forgé au Voile d'hiver (flocons, anneau Givre)"
end

-- 3.7.0 : les dix cosmétiques neufs des hauts faits, un par scène
-- (qc-feat37-<id>), et tous les ornements des hauts faits à la fois
-- (qc-feat37-ornaments) : les icônes du client restent des vignettes
local function QCFeat37(T, kind, id)
	local ns, frame = QCCompanion(T, function(n)
		local data = n:CompanionData()
		data.unlocked[kind .. ":" .. id] = true
		if kind == "frame" then data.frameStyle = id elseif kind == "bg" then data.background = id end
	end)
	ns:CompanionApplyFrame()
	ns:CompanionApplyBackground()
	ns:CompanionApplyOrnaments()
	return frame, "QuestCompanion : cosmétique des hauts faits 3.7, " .. kind .. ":" .. id
end
Snap.scenes["qc-feat37-feat_rarities"] = function(T) return QCFeat37(T, "orn", "feat_rarities") end
Snap.scenes["qc-feat37-feat_contest"] = function(T) return QCFeat37(T, "orn", "feat_contest") end
Snap.scenes["qc-feat37-feat_rare_size"] = function(T) return QCFeat37(T, "orn", "feat_rare_size") end
Snap.scenes["qc-feat37-feat_glitter"] = function(T) return QCFeat37(T, "orn", "feat_glitter") end
Snap.scenes["qc-feat37-feat_volunteer"] = function(T) return QCFeat37(T, "orn", "feat_volunteer") end
Snap.scenes["qc-feat37-feat_worlds"] = function(T) return QCFeat37(T, "orn", "feat_worlds") end
Snap.scenes["qc-feat37-feat_unfindable"] = function(T) return QCFeat37(T, "orn", "feat_unfindable") end
Snap.scenes["qc-feat37-feat_starry"] = function(T) return QCFeat37(T, "frame", "feat_starry") end
Snap.scenes["qc-feat37-feat_sparkle"] = function(T) return QCFeat37(T, "bg", "feat_sparkle") end
Snap.scenes["qc-feat37-feat_perfect"] = function(T) return QCFeat37(T, "bg", "feat_perfect") end
Snap.scenes["qc-feat37-ornaments"] = function(T)
	local ns, frame = QCCompanion(T, function(n)
		local data = n:CompanionData()
		for _, def in ipairs(n.FEAT_COSMETICS.orn) do data.unlocked["orn:" .. def.id] = true end
	end)
	ns:CompanionApplyOrnaments()
	return frame, "QuestCompanion : tous les ornements des hauts faits (3.7)"
end

Snap.scenes["qc-tutorial"] = function(T)
	local ns, frame = QCCompanion(T, function(n) n:CompanionData().tutoDone = nil end)
	ns:CompanionStartTutorial(true)
	return Snap.Group(frame, ns.companionBubble), "QuestCompanion : bulle du tutoriel (Passer / Suivant)"
end

Snap.scenes["qc-pantry"] = function(T)
	local ns, frame = QCCompanion(T)
	ns:TreatMenuToggle()
	return Snap.Group(frame, ns.treatMenu), "QuestCompanion : garde-manger (Maj + clic sur la créature)"
end

Snap.scenes["qc-capture"] = function(T)
	local ns = QCWorld(T)
	local data = ns:CaptureData()
	data.items.appat, data.items.lasso, data.items.sifflet = 3, 1, 0
	ns:BestiaryData()[1413] = { [3100] = { name = "Loup des plaines", class = "elite", level = 21, killed = 1 } }
	ns:BestiaryData()[1413][3101] = { name = "Sanglier", class = "normal", level = 20, killed = 1 }
	ns:CaptureOffer("Creature-0-1-1-1-3100-0001", { zoneID = 1413, npcID = 3100 })
	ns:CaptureOffer("Creature-0-1-1-1-3101-0001", { zoneID = 1413, npcID = 3101 })
	ns:CaptureToggleAid("appat")
	-- 2.0 : plus de fenêtre automatique, la liste du filet (clic droit)
	return Centered(ns:CaptureShowQueueList()), "QuestCompanion : liste du filet (élite en tête, appât choisi)"
end

local function QCCaptureStage(T, success, at)
	local ns = QCWorld(T)
	ns:DB().companionCaptureAnim = true
	ns:BestiaryData()[1413] = { [3100] = { name = "Ours gris", class = "rare", level = 21, killed = 1 } }
	ns:CaptureOffer("Creature-0-1-1-1-3100-0001", { zoneID = 1413, npcID = 3100 })
	local saved = math.random
	math.random = function(a, b) if a then return a end return success and 0 or 0.99 end
	ns:CaptureThrow()
	math.random = saved
	local rolling = ns:CaptureState().rolling
	if at == "shake" then
		rolling.done = 1
		ns:CaptureStageUpdate(rolling.start + ns.CAPTURE_THROW_TIME + 0.7)
	else
		rolling.done = rolling.shakes
		rolling.result = success and "ok" or "fail"
		rolling.resultAt = rolling.start + 3
		-- deux étoiles sur trois (CaptureQueue.lua les tire à la résolution)
		rolling.stars = success and 2 or nil
		ns:CaptureStageUpdate(rolling.resultAt + (success and 0.85 or 0.3))
	end
	return Centered(ns.captureStage)
end
Snap.scenes["qc-capture-shake"] = function(T)
	return QCCaptureStage(T, true, "shake"), "QuestCompanion : capture animée, le filet secoue (rare)"
end
Snap.scenes["qc-capture-ok"] = function(T)
	return QCCaptureStage(T, true, "ok"), "QuestCompanion : capture animée, capturé ! (rayons, gerbe, ruban, étoiles)"
end
Snap.scenes["qc-capture-fail"] = function(T)
	return QCCaptureStage(T, false, "fail"), "QuestCompanion : capture animée, échappé"
end
-- le bandeau « Capture possible » (2.1.0), deux candidats dans le filet
Snap.scenes["qc-capture-toast"] = function(T)
	local ns = QCWorld(T)
	ns:BestiaryData()[1413] = { [3100] = { name = "Ours gris", class = "rare", level = 21, killed = 1 },
		[3101] = { name = "Sanglier", class = "normal", level = 20, killed = 1 } }
	ns:CaptureOffer("Creature-0-1-1-1-3100-0001", { zoneID = 1413, npcID = 3100 })
	ns:CaptureOffer("Creature-0-1-1-1-3101-0001", { zoneID = 1413, npcID = 3101 })
	return Centered(ns:CaptureToastShow()), "QuestCompanion : bandeau « Capture possible » (rare, et 1 de plus)"
end
-- 3.1.0 : les scènes de capture au thème forgé (ForgeScenes.lua). Le verdict
-- d'une brillante dans la scène (lueur, éclat, reflet, niveau sur la plaque d'or)
Snap.scenes["qc-capture-shiny"] = function(T)
	local ns = QCWorld(T)
	ns:DB().companionCaptureAnim = true
	ns:BestiaryData()[1413] = { [3100] = { name = "Ours gris", class = "rare", level = 21, killed = 1 } }
	ns:CaptureOffer("Creature-0-1-1-1-3100-0001", { zoneID = 1413, npcID = 3100 }, true)
	local saved = math.random
	math.random = function(a) if a then return a end return 0 end
	ns:CaptureThrow()
	math.random = saved
	local rolling = ns:CaptureState().rolling
	rolling.done, rolling.result, rolling.resultAt, rolling.stars = rolling.shakes, "ok", rolling.start + 3, 3
	ns:CaptureStageUpdate(rolling.resultAt + 0.9)
	-- le bouton Partager, dans le coin (Share.lua, comme au verdict d'un lancer)
	local stage = Centered(ns.captureStage)
	if ns.ShareStageVerdict then
		ns:ShareStageVerdict(rolling, { name = "Ours gris", shiny = true, stars = 3, npcID = 3100, level = 21, class = "rare" })
	end
	return stage, "QuestCompanion : capture animée, une brillante capturée (verdict dans la scène, Partager au coin)"
end
-- la carte de préparation : 3 étoiles (l'aide conseillée luit), Appât choisi
Snap.scenes["qc-capture-prep"] = function(T)
	local ns = QCWorld(T)
	ns:DB().companionCaptureAnim = true
	local data = ns:CaptureData()
	data.items.appat, data.items.lasso, data.items.sifflet = 3, 1, 0
	ns:BestiaryData()[1413] = { [3100] = { name = "Ours gris", class = "rare", level = 21, killed = 1 } }
	ns:CaptureOffer("Creature-0-1-1-1-3100-0001", { zoneID = 1413, npcID = 3100 })
	ns:CaptureQueueState()[1].stars = 3
	ns:CaptureToggleAid("appat")
	return Centered(ns:CapturePrepOpen()), "QuestCompanion : carte de préparation (3 étoiles, Appât choisi, Lasso conseillé)"
end
-- la volée « Tout capturer », figée sur ses verdicts (une échappée, une brillante à 6)
local QC_BATCH = { { 3100, "Ours gris", "rare", 21 }, { 3101, "Sanglier", "normal", 20 }, { 3102, "Loup des plaines", "elite", 21 },
	{ 3103, "Kodo des Tarides", "normal", 22 }, { 3104, "Raptor des Tarides", "normal", 21 }, { 3105, "Messager zhévra", "normal", 20 } }
local function QCCaptureBatch(T, count)
	local ns = QCWorld(T)
	ns:DB().companionCaptureAnim = true
	ns:CaptureData().items.lasso = 9
	local book = {}
	for index = 1, count do
		local c = QC_BATCH[index]
		book[c[1]] = { name = c[2], class = c[3], level = c[4], killed = 1 }
	end
	ns:BestiaryData()[1413] = book
	for index = 1, count do
		ns:CaptureOffer("Creature-0-1-1-1-" .. QC_BATCH[index][1] .. "-0001", { zoneID = 1413, npcID = QC_BATCH[index][1] },
			count > 3 and index == count)
	end
	ns:CaptureToggleAid("lasso")
	local saved, chance = math.random, ns.CaptureChance
	math.random = function(a) if a then return a end return 0.5 end
	ns.CaptureChance = function(self, info, ...)
		if info and info.npcID == 3102 then return 0, false end
		return 0.95, false
	end
	ns:CaptureBatch()
	math.random, ns.CaptureChance = saved, chance
	ns:CaptureBatchStop(true)
	return Centered(ns.captureBatchFrame)
end
Snap.scenes["qc-capture-batch3"] = function(T)
	return QCCaptureBatch(T, 3), "QuestCompanion : « Tout capturer », 3 cases (une échappée)"
end
Snap.scenes["qc-capture-batch6"] = function(T)
	return QCCaptureBatch(T, 6), "QuestCompanion : « Tout capturer », 6 cases en 2 × 3 (une brillante)"
end
-- le choix au filet : une brillante en tête, deux autres ; posé à côté du filet
Snap.scenes["qc-capture-chooser"] = function(T)
	local ns = QCWorld(T)
	ns:BestiaryData()[1413] = { [3100] = { name = "Ours gris", class = "rare", level = 21, killed = 1 },
		[3101] = { name = "Sanglier", class = "normal", level = 20, killed = 1 },
		[3102] = { name = "Loup des plaines", class = "elite", level = 21, killed = 1 } }
	ns:CaptureData().items.appat, ns:CaptureData().items.lasso = 3, 1
	ns:CaptureOffer("Creature-0-1-1-1-3100-0001", { zoneID = 1413, npcID = 3100 }, true)
	ns:CaptureOffer("Creature-0-1-1-1-3101-0001", { zoneID = 1413, npcID = 3101 })
	ns:CaptureOffer("Creature-0-1-1-1-3102-0001", { zoneID = 1413, npcID = 3102 })
	ns:CaptureToggleAid("appat")
	if ns.CaptureToastHide then ns:CaptureToastHide() end
	local net = ns.captureNetButton
	if net then
		net:ClearAllPoints()
		net:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
		net:Show()
	end
	local chooser = ns:CaptureChooserShow()
	return Snap.Group(net, chooser), "QuestCompanion : choix au filet (brillante en tête, Appât pour le lot), à côté du filet"
end

Snap.scenes["qc-chest"] = function(T)
	local ns = QCWorld(T)
	ns:ChestData()[1411] = { tier = 1, name = "Durotar", at = 0 }
	ns:DB().companionChestAnim = false
	local frame = ns:OpenChest(1411)
	return Centered(frame), "QuestCompanion : coffre de zone (ouverture, objets du palier 1)"
end

Snap.scenes["qc-notify"] = function(T)
	local ns = QCWorld(T)
	ns:JournalNotify({ kind = "subzone", name = "Camp Taurajo" })
	local toast = ns.journalToast
	toast:ClearAllPoints()
	toast:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return toast, "QuestCompanion : bandeau « Nouveau tampon » du carnet"
end

-- 3.1.0 : les bandeaux au thème forgé (ForgeBanners.lua) : médaillon,
-- plaque des points ou du niveau, bouton Partager écrit, grand effet
local function QCBannerWorld(T)
	local ns = QCWorld(T)
	for _, field in ipairs({ "captureResult", "guildFeatToast", "journalToast", "captureToast" }) do
		if ns[field] then ns[field]:Hide() end
		ns[field] = nil
	end
	ns.uiStyleCache = {}
	ns.captureResultHideAt, ns.captureResultPending = nil, nil
	return ns
end

local function QCResultScene(T, shiny)
	local ns = QCBannerWorld(T)
	local frame = ns:CaptureResultShow({ name = shiny and "Gesharahan" or "Raptor des Tarides", shiny = shiny, stars = 3,
		npcID = shiny and 3398 or 3255, level = shiny and 20 or 18, type = "Beast", class = shiny and "rare" or "normal",
		fresh = true, specimen = { size = shiny and "giant" or "large", trait = "curious", stars = 3 } })
	return Centered(frame)
end

Snap.scenes["qc-result-forge"] = function(T)
	return QCResultScene(T, false), "QuestCompanion : bandeau « Capturé ! » (portrait, niveau, étoiles et traits, Partager)"
end

Snap.scenes["qc-result-shiny-forge"] = function(T)
	return QCResultScene(T, true), "QuestCompanion : bandeau « Brillant capturé ! » (nom d'or, halo du médaillon)"
end

Snap.scenes["qc-feat-forge"] = function(T)
	local ns = QCBannerWorld(T)
	ns:JournalToastPush({ kind = "feat", id = "zone_visit_10", title = ns.L.FEAT_TOAST_TITLE, name = "Bourlingueur",
		icon = "Interface\\Icons\\INV_Misc_Map_01", points = 10 })
	return Centered(ns.journalToast), "QuestCompanion : bandeau « Haut fait obtenu » (icône et points au médaillon)"
end

Snap.scenes["qc-feat-big-forge"] = function(T)
	local ns = QCBannerWorld(T)
	ns:JournalToastPush({ kind = "feat", id = "day_rare_50", title = ns.L.FEAT_TOAST_TITLE, name = "Le traqueur",
		icon = "Interface\\Icons\\Ability_Hunter_BeastTaming", points = 25, sub = ns:F("FEAT_TOAST_NEW_TITLE", "Traqueuse") })
	local toast = Centered(ns.journalToast)
	-- le grand effet à mi-course (ailes ouvertes, éclat)
	local fx = toast.azReward
	if fx and fx.at and ns.AzerothFxStep then ns.AzerothFxStep(fx.at + 0.9) end
	return toast, "QuestCompanion : gros haut fait (« Nouveau titre », 25 points, ailes et éclat forgés)"
end

-- 3.7.0 : fêtes à la taille de l'exploit, signature, cote d'une prise rare (Quiet.lua)
Snap.scenes["qc-feat-pill"] = function(T)
	local ns = QCBannerWorld(T)
	ns.featPills, ns.featPillHideAt = {}, nil
	if ns.featPill then ns.featPill:Hide() end
	ns.featPill = nil
	ns:FeatPillPush({ kind = "feat", name = "Petite douceur", points = 5, size = "small" })
	return Centered(ns.featPill), "QuestCompanion : pastille muette d'un petit haut fait (5 points, 3.7)"
end

Snap.scenes["qc-feat-medium"] = function(T)
	local ns = QCBannerWorld(T)
	ns:JournalToastPush({ kind = "feat", title = ns.L.FEAT_TOAST_TITLE, name = "Cinq cents prises", size = "medium",
		icon = "Interface\\Icons\\INV_Misc_Map_01", points = 10, sub = ns:F("FEAT_GLITTER_N", 5) .. " · Lasso ×1" })
	return Centered(ns.journalToast), "QuestCompanion : bandeau moyen (10 points, ligne de récompense, 3.7)"
end

-- 3.7.0, étape 3, S3 : bilan de sortie (TripRecap.lua) : le bandeau moyen, d'autres textes, « Détail »
local QC_TRIP_RECAP = { at = 1000, ended = 1000 + 5040, dur = 5040, captures = 14, species = 3, shinies = 1, glitter = 31,
	study = 4, bond = 7, by = { study = 12, milestone = 10, feat = 5, capture = 4 },
	best = { name = "Raptor de Strangleronce (brillant)", stars = 3, shiny = true, size = "giant" }, feats = { "men_caught_100" } }
Snap.scenes["qc-trip-recap"] = function(T)
	local ns = QCBannerWorld(T)
	ns:TripBanner(QC_TRIP_RECAP)
	return Centered(ns.journalToast), "QuestCompanion : bilan de sortie (bandeau moyen, « Détail », 3.7)"
end

Snap.scenes["qc-journal-trip"] = function(T)
	local frame = QCJournal(T, "evolution", function(ns)
		ns:CharData().tripLast = QC_TRIP_RECAP
	end)
	T.QNS:TripDetailOpen()
	return frame, "QuestCompanion : carnet, page « Dernière sortie » (3.7)"
end

Snap.scenes["qc-feat-big-sig"] = function(T)
	local ns = QCBannerWorld(T)
	ns:JournalToastPush({ kind = "feat", id = "day_rare_50", title = ns.L.FEAT_TOAST_TITLE, name = "Bibliothèque vivante",
		icon = "Interface\\Icons\\Ability_Hunter_BeastTaming", points = 50, size = "big" })
	local toast = Centered(ns.journalToast)
	local fx = toast.azReward
	if fx and fx.at and ns.AzerothFxStep then ns.AzerothFxStep(fx.at + 0.9) end
	return toast, "QuestCompanion : grand bandeau signé (titre et paillettes, grand effet, 3.7)"
end

Snap.scenes["qc-result-rare-odds"] = function(T)
	local ns = QCBannerWorld(T)
	ns.SHINY_CHANCE = 1 / 150
	local id = ns:SpecimenAdd({ npc = 3398, stars = 3, name = "Raptor de Strangleronce", origin = "capture", zone = 1413,
		size = "giant", shiny = true, trait = "curious" })
	local frame = ns:CaptureResultShow({ name = "Raptor de Strangleronce", shiny = true, stars = 3, npcID = 3398, level = 38,
		type = "Beast", class = "normal", specimen = id })
	return Centered(frame), "QuestCompanion : « Brillant capturé ! », cote de base et signature (3.7)"
end

Snap.scenes["qc-options-quiet"] = function(T)
	return Options(T, T.QNS, "companionQuiet"), "QuestCompanion : réglages, Compagnon de route > Discrétion (mode discret, 3.7)"
end

-- 3.7.0, étape 3 : la carte souvenir (maquette autres-c1). L'écran est
-- ramené à la taille de la scène de la maquette (760 x 470) : le voile le
-- couvre, la carte et ses boutons au centre. Le modèle 3D est une zone vide.
local function SouvenirWorld(T)
	local ns = QCBannerWorld(T)
	if rawget(_G, "date") == nil then _G.date = os.date end
	-- (chaque aperçu est un processus à lui : l'écran réduit n'y survit pas)
	Snap.SCREEN = { width = 760, height = 470 }
	UIParent.width, UIParent.height = 760, 470
	_G.Screenshot = rawget(_G, "Screenshot") or function() end
	if ns.souvenirFrame then ns.souvenirFrame:Hide() end
	ns.souvenirFrame = nil
	ns.SHINY_CHANCE = 1 / 150
	local creatures = ns:CaptureData().creatures
	for index = 1, 312 do creatures[93000 + index] = { name = "Bête " .. index, normal = true, stars = 2, class = "normal", type = "Bête" } end
	return ns
end
local function SouvenirFrame(veil)
	local model = veil and veil.card and veil.card.panel and veil.card.panel.model
	if model then model:Hide() end
	return veil
end

Snap.scenes["qc-souvenir-specimen"] = function(T) return OwnDraws(T, function(T)
	local ns = SouvenirWorld(T)
	local id = ns:SpecimenAdd({ npc = 3398, stars = 3, name = "Raptor de Strangleronce", origin = "capture", zone = 1413, by = "Testeur",
		size = "giant", shiny = true, trait = "curious", at = os.time({ year = 2026, month = 11, day = 22, hour = 12 }) })
	ns:SpecimenGet(id).nick = "Croc"
	local veil = ns:SouvenirShow({ kind = "capture", result = { specimen = id, shiny = true, level = 38 } })
	return SouvenirFrame(veil), "QuestCompanion : carte souvenir d'une prise brillante (3.7)"
end) end

Snap.scenes["qc-souvenir-feat"] = function(T) return OwnDraws(T, function(T)
	local ns = SouvenirWorld(T)
	ns:FeatAward("char_level_60", { silent = true, at = os.time({ year = 2026, month = 11, day = 21, hour = 12 }) })
	local veil = ns:SouvenirShow({ kind = "feat", id = "char_level_60" })
	return SouvenirFrame(veil), "QuestCompanion : carte souvenir d'un haut fait obtenu (3.7)"
end) end

Snap.scenes["qc-souvenir-trainer"] = function(T) return OwnDraws(T, function(T)
	local ns = SouvenirWorld(T)
	ns:FeatAward("char_level_60", { silent = true, at = 1700000000 })
	local veil = ns:SouvenirShow({ kind = "trainer" })
	return SouvenirFrame(veil), "QuestCompanion : carte souvenir de la fiche de dresseur (3.7)"
end) end

Snap.scenes["qc-souvenir-noshot"] = function(T) return OwnDraws(T, function(T)
	local ns = SouvenirWorld(T)
	local saved = rawget(_G, "Screenshot")
	_G.Screenshot = nil
	local id = ns:SpecimenAdd({ npc = 3236, stars = 2, name = "Kodo des Tarides", origin = "capture", zone = 1413, by = "Testeur",
		size = "large", trait = "lazy", at = os.time({ year = 2026, month = 11, day = 20, hour = 12 }) })
	local veil = ns:SouvenirShow({ kind = "specimen", id = id })
	_G.Screenshot = saved
	return SouvenirFrame(veil), "QuestCompanion : carte souvenir, client sans Screenshot (3.7)"
end) end

-- la fenêtre « Copier pour Discord », avec le texte d'une prise
Snap.scenes["qc-discord-copy"] = function(T) return OwnDraws(T, function(T)
	return WithMultiLine(function()
		local ns = SouvenirWorld(T)
		Snap.SCREEN = { width = 1600, height = 1000 }
		UIParent.width, UIParent.height = Snap.SCREEN.width, Snap.SCREEN.height
		if ns.discordCopy then ns.discordCopy:Hide() end
		ns.discordCopy = nil
		local id = ns:SpecimenAdd({ npc = 3398, stars = 3, name = "Raptor de Strangleronce", origin = "capture", zone = 1413, by = "Testeur",
			size = "giant", shiny = true, trait = "curious", at = os.time({ year = 2026, month = 11, day = 22, hour = 12 }) })
		local frame = ns.DiscordCopyShow(ns:DiscordText("capture", id))
		return Centered(frame), "QuestCompanion : fenêtre « Copier pour Discord » (3.7)"
	end)
end) end

Snap.scenes["qc-guild-forge"] = function(T)
	local ns = QCBannerWorld(T)
	ns:GuildFeatsShowToast({ key = "x", sender = "Xan-Royaume", feat = { kind = "h" }, score = 1000, at = Mock.now,
		info = { kind = "h", line = "Xan, Maîtresse des brillantes, a gagné le titre « Traqueuse » !",
			icon = "Interface\\Icons\\Ability_Hunter_BeastTaming", points = 25, more = 2, sub = "Nouveau titre : Traqueuse" } })
	return Centered(ns.guildFeatToast), "QuestCompanion : bandeau de guilde (deux lignes, médaillon, « et 2 autres exploits »)"
end

Snap.scenes["qc-tour-forge"] = function(T)
	local ns = QCBannerWorld(T)
	local anchor = CreateFrame("Frame", nil, UIParent)
	anchor:SetSize(150, 34)
	anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -90)
	local back = ns.Theme.Solid(anchor, "BACKGROUND", ns.Theme.NAV, 1)
	back:SetAllPoints(anchor)
	local label = ns.Theme.Text(anchor, ns.Theme.F_LABEL, ns.Theme.LABEL)
	label:SetPoint("CENTER", anchor, "CENTER", 0, 0)
	label:SetText(ns.L.TOUR_A1_T or "Le filet")
	anchor:Show()
	ns.TOUR_DEFS.snapForge = { steps = {
		{ id = "a", anchor = anchor, title = "TOUR_A1_T", text = "TOUR_A1", placement = "top" },
		{ id = "b", anchor = anchor, title = "TOUR_A2_T", text = "TOUR_A2", placement = "top" } } }
	ns:TourStart("snapForge")
	local ui = ns.tourUI and (ns.tourUI.forge or ns.tourUI.sobre)
	return Snap.Group(ui.callout, ui.ring, anchor), "QuestCompanion : bulle d'une visite guidée et liseré de la cible"
end

Snap.scenes["qc-tracker"] = function(T)
	local ns = QCWorld(T)
	ns:DB().journalTracker = true
	ns:RefreshJournalTracker()
	local tracker = ns.journalTracker
	tracker:ClearAllPoints()
	tracker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return tracker, "QuestCompanion : bloc « Carnet » à l'écran (objectifs suivis)"
end

-- 3.6.0 : le suivi avec ses nouvelles sources (envie, commande, étude, zone)
Snap.scenes["qc-tracker-36"] = function(T)
	local ns = QCWorld(T)
	ns:DB().journalTracker = true
	ns.studyDormant = false
	local capture = ns:CaptureData()
	for _ = 1, 4 do
		capture.creatures[3236] = { name = "Kodo des Tarides", normal = true, stars = 1, class = "normal", type = "Bête" }
		ns:SpecimenAdd({ npc = 3236, stars = 1, name = "Kodo des Tarides", origin = "capture", zone = 1413, size = "large" })
	end
	ns:CompanionData().wish = { key = "hunger" }
	ns:ShopOrders().list = { { kind = "zone", zone = 1413, reward = 12 } }
	ns:RefreshJournalTracker()
	local tracker = ns.journalTracker
	tracker:ClearAllPoints()
	tracker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return tracker, "QuestCompanion : bloc « Carnet », envie, commande, étude et Créatures de la zone (3.6)"
end

-- 3.6.0 : Réserve vide (le pourquoi, le mode chasse d'un clic)
Snap.scenes["qc-journal-reserve-empty"] = function(T) return OwnDraws(T, function(T)
	local frame = QCJournal(T, "reserve", function() end)
	return frame, "QuestCompanion : carnet, Réserve vide (3.6)"
end) end

-- 3.6.0 : la bulle « Partir avec lui » après la toute première capture
Snap.scenes["qc-tour-mate"] = function(T)
	local ns = QCBannerWorld(T)
	local anchor = CreateFrame("Frame", nil, UIParent)
	anchor:SetSize(104, 118)
	anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
	anchor:Show()
	ns.tourMate = { npc = 3236, name = "Kodo des Tarides" }
	local def = ns.TOUR_DEFS.mate
	local saved = def.steps[1].anchor
	def.steps[1].anchor = anchor
	ns:TourStart("mate")
	def.steps[1].anchor = saved
	local ui = ns.tourUI and (ns.tourUI.forge or ns.tourUI.sobre)
	return Snap.Group(ui.callout, anchor), "QuestCompanion : « Partir avec lui » après la première capture (3.6)"
end

Snap.scenes["qc-tooltip"] = function(T)
	local ns = QCWorld(T)
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Gesharahan", 1, 1, 1)
	GameTooltip:AddLine("Niveau 20 Bête (rare élite)", 1, 1, 1)
	local text, color
	if ns.BestiaryTooltipLine then text, color = ns:BestiaryTooltipLine("Creature-0-0-0-0-3398-0000") end
	if not text then text, color = ns:F("BST_TOOLTIP", ns:F("JRN_ITEM_KILLED", 1)), ns.Theme.GOLD end
	GameTooltip:AddLine(text, color[1], color[2], color[3])
	local tip = Snap.Tooltip(GameTooltip, nil, 260)
	tip:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return tip, "QuestCompanion : infobulle d'une créature (ligne du bestiaire)"
end

-- 3.7.0 : médailles de zone sur la page Créatures (0, 1 et 3 médailles) : la
-- scène de l'espèce maîtrisée, avec assez d'espèces des Tarides capturées
local function MedalScene(T, want)
	local frame = Snap.scenes["qc-journal-menagerie-mastered"](T)
	local ns = T.QNS
	local capture = ns:CaptureData()
	local ids = {}
	for npc, species in pairs(ns:BestiarySpecies(1413)) do
		if type(species) == "table" and species.class ~= "worldboss" then ids[#ids + 1] = tonumber(npc) or npc end
	end
	table.sort(ids)
	for _, npc in ipairs(ids) do
		if select(1, ns:MenagerieSealProgress(1413)) >= want then break end
		if capture.creatures[npc] == nil then
			capture.creatures[npc] = { name = "Créature " .. npc, normal = true, zoneID = 1413, at = 1, stars = 1 }
			capture.count = capture.count + 1
		end
	end
	capture.serial = (tonumber(capture.serial) or 0) + 1
	if ns.ZoneMedalReset then ns.ZoneMedalReset() end
	ns:RefreshJournal()
	return frame, "QuestCompanion : carnet, Créatures, médailles de zone (3.7)"
end
Snap.scenes["qc-journal-menagerie-medals0"] = function(T) return MedalScene(T, 0) end
Snap.scenes["qc-journal-menagerie-medals1"] = function(T) return MedalScene(T, 50) end
Snap.scenes["qc-journal-menagerie-medals3"] = function(T) return MedalScene(T, 140) end

-- 3.7.0 : le suivi avec la ligne de zone devenue médaille
Snap.scenes["qc-tracker-37"] = function(T)
	local ns = QCWorld(T)
	ns:DB().journalTracker = true
	local capture, count = ns:CaptureData(), 0
	local ids = {}
	for npc, species in pairs(ns:BestiarySpecies(1413)) do
		if type(species) == "table" and species.class ~= "worldboss" then ids[#ids + 1] = tonumber(npc) or npc end
	end
	table.sort(ids)
	for _, npc in ipairs(ids) do
		if count >= 5 then break end
		if capture.creatures[npc] == nil then
			capture.creatures[npc] = { name = "Créature " .. npc, normal = true, zoneID = 1413, at = 1, stars = 1 }
			capture.count = capture.count + 1
		end
		count = count + 1
	end
	capture.serial = (tonumber(capture.serial) or 0) + 1
	if ns.ZoneMedalReset then ns.ZoneMedalReset() end
	-- (deux objectifs de rang 3 masqués : la ligne de zone, au dernier rang, se voit)
	local kept = 0
	for _, goal in ipairs(ns:JournalObjectives()) do
		if not goal.id:find("^medal:") then
			kept = kept + 1
			if kept > 2 then ns:JournalDismiss(goal.id, true) end
		end
	end
	ns:RefreshJournalTracker()
	local tracker = ns.journalTracker
	tracker:ClearAllPoints()
	tracker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return tracker, "QuestCompanion : bloc « Carnet », la médaille de la zone (3.7)"
end

-- 3.7.0 : l'infobulle avec la série de chasse (23 abattus)
Snap.scenes["qc-tooltip-37"] = function(T)
	local ns = QCWorld(T)
	ns.SHINY_CHANCE = 1 / 150
	local guid = "Creature-0-0-0-0-3398-0000"
	local zoneID = ns:JournalZone()
	local data = ns:JournalData()
	data.bestiary = data.bestiary or {}
	data.bestiary[zoneID] = data.bestiary[zoneID] or {}
	data.bestiary[zoneID][3398] = { name = "Gesharahan", seen = true, killed = 23 }
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Gesharahan", 1, 1, 1)
	GameTooltip:AddLine("Niveau 20 Bête (rare élite)", 1, 1, 1)
	local text, color = ns:BestiaryTooltipLine(guid)
	if not text then text, color = ns:F("BST_TOOLTIP", ns:F("JRN_ITEM_KILLED", 23)), ns.Theme.GOLD end
	GameTooltip:AddLine(text, color[1], color[2], color[3])
	local chain = ns:BestiaryTooltipChain(guid) or ns:F("MEN_TIP_CHAIN", 23, 50, "2,3")
	local c = ns.Theme.GOLD
	GameTooltip:AddLine(chain, c[1], c[2], c[3])
	local tip = Snap.Tooltip(GameTooltip, nil, 260)
	tip:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return tip, "QuestCompanion : infobulle, série de chasse (3.7)"
end

-- 3.7.0 : une pastille de la capture express en suspens, puis le verdict d'une autre
Snap.scenes["qc-capture-express-suspense"] = function(T)
	local ns, frame = QCCompanion(T)
	ns.captureExpressDormant = nil
	ns:CaptureExpressPush("notable", "Raptor des Tarides", ns.L.CAPTURE_X_NEW)
	local item = ns:CaptureExpressPush("suspense", "Raptor des Tarides", ns.L.CAPTURE_X_SHAKE, 5)
	item.verdict, item.revealAt, item.shakes = { "notable", "Raptor des Tarides", ns.L.CAPTURE_X_NEW }, ns.Now() + 1, 2
	ns:CaptureExpressUpdate(ns.Now() + 0.3)
	return Snap.Group(frame, ns.captureExpressFeed), "QuestCompanion : capture express, le filet tremble (3.7)"
end

-- 3.7.0, chantier E2 : le monde bouge (WorldDaily.lua). Le module est réveillé
-- (le banc l'endort) ; le jour et la semaine sont choisis pour retrouver la
-- maquette : une semaine des Bêtes dont la créature des niveaux 20 à 40 est le
-- Raptor de Strangleronce, un jour où la pullulation des Tarides est le Kodo
-- des Tarides (la maquette invente un « Raptor des Tarides » que la table n'a
-- pas). Remise à zéro de la semaine un mardi.
local function WorldAwake(ns, opts)
	opts = opts or {}
	ns.worldDailyDormant = nil
	local week, day, fallback = nil, "2026-11-22", nil
	for k = 2900, 9900 do
		local id = "r" .. k
		if ns:WorldWeekType(id) == "beast" then
			fallback = fallback or id
			if ns:WorldWeekCreature(2, id) == 685 then week = id; break end
		end
	end
	week = week or fallback
	local base = os.time({ year = 2026, month = 11, day = 22, hour = 12 })
	for n = 0, 900 do
		day = os.date("%Y-%m-%d", base + n * 86400)
		ns.WorldDailyReset()
		if ns:WorldSwarm(1413, day) == 3236 then break end
	end
	ns.WorldDay = function() return day end
	ns.WorldWeek = function() return week end
	ns.WorldDailyReset()
	-- le jour de la remise à zéro (le faux client n'en a pas) : un mardi
	ns.WorldWeekEndText = function(self) return self:F("WORLD_TYPE_UNTIL", ns.L.WORLD_WD_3) end
	if opts.best then
		local npc = ns:WorldWeekCreature(2)
		local id = ns:SpecimenAdd({ npc = npc, zone = 1434, stars = 2, size = "large", origin = "trade" })
		local spec = ns:SpecimenGet(id)
		spec.zi = 112
		ns:WorldWeekRecord().best[npc] = { stars = 2, size = "large", zi = 112, id = id }
	end
	-- le bouton « Carte souvenir » ne vient qu'avec ns.SouvenirShow (autre chantier)
	if opts.souvenir then ns.SouvenirShow = function() end end
	return ns
end

-- page Missions : « Aujourd'hui en Azeroth » en tête, le reste descend
Snap.scenes["qc-journal-day-37"] = function(T)
	local frame = Snap.scenes["qc-journal-day"](T)
	local ns = T.QNS
	WorldAwake(ns, { best = true, souvenir = true })
	ns:RefreshJournal()
	return frame, "QuestCompanion : carnet, Missions, « Aujourd'hui en Azeroth » (3.7)"
end
-- la même, défilée jusqu'en bas (molette)
Snap.scenes["qc-journal-day-37-scrolled"] = function(T)
	local frame = Snap.scenes["qc-journal-day-37"](T)
	local ns = T.QNS
	for _ = 1, 20 do ns:ScrollJournal(-1) end
	return frame, "QuestCompanion : carnet, Missions défilées jusqu'en bas (3.7)"
end

-- page Créatures : la ligne « Pullulation » de l'encadré
Snap.scenes["qc-journal-menagerie-swarm"] = function(T)
	local frame = MedalScene(T, 5)
	local ns = T.QNS
	WorldAwake(ns)
	ns:RefreshJournal()
	return frame, "QuestCompanion : carnet, Créatures, pullulation du jour (3.7)"
end

-- suivi : un haut fait suivi, la médaille de la zone, la pullulation, la créature de la semaine
Snap.scenes["qc-tracker-world"] = function(T)
	local ns = QCWorld(T)
	ns:DB().journalTracker = true
	FeatsWorld(ns)
	WorldAwake(ns)
	local capture, count = ns:CaptureData(), 0
	local ids = {}
	for npc, species in pairs(ns:BestiarySpecies(1413)) do
		if type(species) == "table" and species.class ~= "worldboss" then ids[#ids + 1] = tonumber(npc) or npc end
	end
	table.sort(ids)
	for _, npc in ipairs(ids) do
		if count >= 5 then break end
		if capture.creatures[npc] == nil then
			capture.creatures[npc] = { name = "Créature " .. npc, normal = true, zoneID = 1413, at = 1, stars = 1 }
			capture.count = capture.count + 1
		end
		count = count + 1
	end
	capture.serial = (tonumber(capture.serial) or 0) + 1
	if ns.ZoneMedalReset then ns.ZoneMedalReset() end
	for _, goal in ipairs(ns:JournalObjectives()) do
		local id = goal.id
		if not (id:find("^feat:") or id:find("^medal:") or id:find("^swarm:") or id:find("^week:")) then ns:JournalDismiss(id, true) end
	end
	ns:RefreshJournalTracker()
	local tracker = ns.journalTracker
	tracker:ClearAllPoints()
	tracker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return tracker, "QuestCompanion : suivi, la zone, le jour, la semaine (3.7)"
end

-- infobulle : la série de chasse, puis la pullulation du jour
Snap.scenes["qc-tooltip-world"] = function(T)
	local ns = QCWorld(T)
	WorldAwake(ns)
	ns.SHINY_CHANCE = 1 / 150
	local npc, name = ns:WorldSwarm(1413)
	local guid = "Creature-0-0-0-0-" .. npc .. "-0000"
	local data = ns:JournalData()
	data.bestiary[1413][npc] = { name = name, seen = true, killed = 23 }
	GameTooltip:ClearLines()
	GameTooltip:AddLine(name, 1, 1, 1)
	GameTooltip:AddLine("Niveau 19 Bête", 1, 1, 1)
	local text, color = ns:BestiaryTooltipLine(guid)
	if text then GameTooltip:AddLine(text, color[1], color[2], color[3]) end
	local c = ns.Theme.GOLD
	local chain = ns:BestiaryTooltipChain(guid)
	if chain then GameTooltip:AddLine(chain, c[1], c[2], c[3]) end
	local swarm = ns:WorldSwarmTooltip(guid)
	if swarm then GameTooltip:AddLine(swarm, c[1], c[2], c[3]) end
	local tip = Snap.Tooltip(GameTooltip, nil, 260)
	tip:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	return tip, "QuestCompanion : infobulle, pullulation du jour (3.7)"
end

-- Communauté, onglet Discord : la tuile « Cette semaine »
Snap.scenes["qc-journal-community-week"] = function(T) return OwnDraws(T, function(T)
	return WithMultiLine(function()
		local frame, ns = QCCommunity(T, "discord", function(ns) WorldAwake(ns, { best = true, souvenir = true }) end)
		ns:CommunityWeekPaint()
		return frame, "QuestCompanion : carnet, Communauté, prise de la semaine (3.7)"
	end)
end) end

-- Thème d'une scène : « sobre:<scène> » ou « azeroth:<scène> » ; sans
-- préfixe, Azeroth (le thème par défaut des deux addons). Rend le thème et
-- le nom de la scène.
function Snap.SplitSkin(name)
	local skin, rest = tostring(name or ""):match("^(%a+):(.+)$")
	if skin == "sobre" or skin == "azeroth" then return skin, rest end
	return "azeroth", name
end

-- Pose le thème pour toute la scène, dans les deux addons (chacun a sa copie
-- du socle), avant que la moindre fenêtre ne soit construite. Le thème du
-- socle (Theme.ApplySkin) et le choix du joueur (NS:UISkinChoice,
-- QNS:UIStyleChoice) sont tenus le temps de la scène : un ResetWorld ou un
-- ADDON_LOADED rejoué reposerait la sauvegarde. Les modules chargés pendant
-- la scène (T.LoadModules : le socle de QuestCompanion arrive alors) sont
-- pris au vol, juste avant leur ADDON_LOADED. Le style propre du carnet de
-- QuestCompanion (atlas du client) reste décidé par la scène. Rend une
-- fonction qui remet tout comme avant.
function Snap.ForceSkin(skin, T)
	local undo, held = {}, {}
	local function Swap(owner, key, value)
		if type(owner) ~= "table" then return end
		local before = rawget(owner, key)
		owner[key] = value
		undo[#undo + 1] = function() owner[key] = before end
	end
	local function Hold()
		for _, ns in ipairs({ T and T.NS, T and T.QNS }) do
			local Theme = type(ns) == "table" and rawget(ns, "Theme")
			if Theme and Theme.ApplySkin and not held[Theme] then
				held[Theme] = true
				local apply = Theme.ApplySkin
				Swap(Theme, "ApplySkin", function() return apply(skin) end)
				Swap(ns, "UISkinChoice", function() return skin end)
				if ns.UIStyleChoice then Swap(ns, "UIStyleChoice", function() return skin end) end
				apply(skin)
			end
		end
	end
	Hold()
	local mock = T and T.Mock
	if type(mock) == "table" and type(mock.Fire) == "function" then
		local fire = mock.Fire
		Swap(mock, "Fire", function(self, event, ...)
			if event == "ADDON_LOADED" then Hold() end
			return fire(self, event, ...)
		end)
	end
	return function() for i = #undo, 1, -1 do undo[i]() end end
end

function Snap.RunScene(name, path, T)
	T = T or rawget(_G, "T")
	local skin
	skin, name = Snap.SplitSkin(name)
	local scene = Snap.scenes[name]
	if not scene then
		local names = {}
		for key in pairs(Snap.scenes) do names[#names + 1] = key end
		table.sort(names)
		error("scène inconnue : " .. tostring(name) .. " (scènes : " .. table.concat(names, ", ") .. ")")
	end
	-- dégradés : l'API récente, comme Forever
	local savedColor = rawget(_G, "CreateColor")
	_G.CreateColor = savedColor or Mock.CreateColor
	-- les cadres créés pendant la scène lisent leur niveau comme en jeu
	local savedCreate = rawget(_G, "CreateFrame")
	_G.CreateFrame = function(...)
		local frame = savedCreate(...)
		if type(frame) == "table" then frame.GetFrameLevel = Snap.LiveLevel end
		return frame
	end
	local restoreSkin = Snap.ForceSkin(skin, T)
	local ok, frame, title = pcall(scene, T)
	_G.CreateColor = savedColor
	_G.CreateFrame = savedCreate
	restoreSkin()
	if not ok then error(frame, 0) end
	local count = Snap.Snapshot(frame, path, { title = title or name, skin = skin })
	return string.format("%s : %d éléments -> %s", name, count, path)
end

return Snap
