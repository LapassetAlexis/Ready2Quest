-- tests/snapshot.lua -- aperçu hors-jeu d'une fenêtre, en HTML
--
-- Personne ne lance le client ici : on dessine l'arbre de régions du Mock
-- (tests/run_tests.lua) en divs positionnées, pour juger une fenêtre à l'œil.
-- Ce n'est pas une capture du jeu : polices approchées, pas de TexCoord,
-- textures du jeu en vignettes grises. Les textures de l'addon (.tga) sont
-- converties en images par tests/snapshot.py.
--
-- Bibliothèque (retournée par ce fichier) :
--   Snap.Rect(region, ctx)          rectangle absolu { left, top, width, height } (y vers le bas)
--   Snap.Render(frame, opts)        HTML autonome (chaîne)
--   Snap.Snapshot(frame, path, opts) écrit le HTML
--   Snap.RunScene(name, path)       joue une scène nommée (Snap.scenes) et l'écrit
-- Lancement : python3 tests/snapshot.py <scène> <sortie.html> (voir ce fichier).
local Snap = {}

local ROOT = rawget(_G, "ADDON_ROOT") or "."
Snap.SCREEN = { width = 1600, height = 1000 }

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
		if width and width > 0 and w > width then
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
			if rect and drawable and region.drawLayer ~= "HIGHLIGHT" and rect.width >= 0 and rect.height >= 0 then
				local frame = IsRegion(region) and region.mockParent or region
				local strata, level = FrameOrder(frame, orderMemo)
				items[#items + 1] = {
					region = region, rect = rect,
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
	local margin = 32
	local ox, oy = margin - minX, margin - minY

	local out = {}
	for _, item in ipairs(items) do
		local region, r = item.region, item.rect
		local alpha = EffectiveAlpha(region)
		local pos = string.format("left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx", r.left + ox, r.top + oy,
			math.max(0, r.width), math.max(0, r.height))
		if region.kind == "Texture" then
			local style, file = TextureStyle(region, alpha)
			if style then
				if file then
					local v = region.vertex or { 1, 1, 1, 1 }
					out[#out + 1] = string.format('<div class="tex file" data-src="%s" data-tint="%s" style="%s;%s" title="%s">%s</div>',
						Escape(tostring(file)), Css(v[1], v[2], v[3], (v[4] or 1) * alpha), pos, style, Escape(tostring(file)),
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
		string.format(".stage{position:relative;width:%dpx;height:%dpx;background:#0b0e11;"
			.. "background-image:radial-gradient(#151a1f 1px,transparent 1px);background-size:16px 16px}",
			math.ceil(maxX - minX + 2 * margin), math.ceil(maxY - minY + 2 * margin)),
		".stage>div{position:absolute;box-sizing:border-box}",
		".txt{display:flex;overflow:visible;line-height:1.2;font-family:InterSnap,Inter,system-ui,sans-serif}",
		".tex.file{font-size:9px;color:#9aa;display:flex;align-items:center;justify-content:center;overflow:hidden;"
			.. "outline:1px dashed rgba(160,170,180,.35);outline-offset:-1px}",
		".tex.img{outline:none;background:none!important}",
		-- largeur posée sans retour à la ligne : coupé avec « … », comme en jeu
		".t{overflow:hidden;text-overflow:ellipsis;max-width:100%}",
		".icon{display:inline-block;width:1em;height:1em;background:#556;vertical-align:middle}",
		"</style></head><body>",
		'<div class="bar">' .. Escape(opts.title or "Aperçu") .. " · aperçu hors-jeu (tests/snapshot.lua), pas une capture du client</div>",
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
	local win = Theme.CreateWindow(UIParent, 980, 680, { name = "SnapBricks", nav = 220, footer = 56 })
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
	version:SetText("v1.28.0  ·  Forever")

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

-- Résumé de stuff : un gain sur la stat principale
Snap.scenes["r2q-gear-toast"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	UIParent:SetSize(1920, 1080)   -- le résumé se mesure en unités 1920 (échelle 1)
	NS.toastFrame = nil
	NS:SimulateGearToast()
	return Centered(NS.toastFrame), "Ready2Quest : résumé de stuff"
end

-- Stats du portrait
Snap.scenes["r2q-portrait"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	NS.portraitFrame = nil
	NS.forceStats = true
	NS:ShowPortraitStats()
	NS.forceStats = nil
	return Centered(NS.portraitFrame), "Ready2Quest : stats du portrait"
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

-- Mode déplacement : le bandeau, avec le résumé et les stats à placer
Snap.scenes["r2q-edit-banner"] = function(T)
	local NS = T.NS
	T.ResetWorld()
	T.LoadModules()
	UIParent:SetSize(1920, 1080)   -- le résumé se mesure en unités 1920 (échelle 1)
	NS.editBanner, NS.toastFrame, NS.portraitFrame = nil, nil, nil
	NS:StartEditMode()
	local banner = NS.editBanner
	banner:ClearAllPoints()
	banner:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	NS.toastFrame:ClearAllPoints()
	NS.toastFrame:SetPoint("CENTER", UIParent, "CENTER", -130, 0)
	NS.portraitFrame:ClearAllPoints()
	NS.portraitFrame:SetPoint("TOPLEFT", UIParent, "CENTER", 60, 40)
	return Snap.Group(banner, NS.toastFrame, NS.portraitFrame), "Ready2Quest : mode déplacement des cadres"
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

Snap.scenes["r2q-options"] = function(T)
	return Options(T, T.NS, "general"), "Ready2Quest : réglages, page Général"
end

Snap.scenes["r2q-options-bags"] = function(T)
	return Options(T, T.NS, "bags"), "Ready2Quest : réglages, Check avant le départ > Sacs & vivres"
end

-- navigation plus haute que sa colonne : défilée jusqu'en bas (Après la mort)
Snap.scenes["r2q-options-nav"] = function(T)
	return Options(T, T.NS, "death"), "Ready2Quest : réglages, navigation défilée (Confort de jeu > Après la mort)"
end

Snap.scenes["r2q-options-spellranks"] = function(T)
	return Options(T, T.NS, "spellranks"), "Ready2Quest : réglages, Confort de jeu > Rangs de sorts"
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

function Snap.RunScene(name, path, T)
	T = T or rawget(_G, "T")
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
	local ok, frame, title = pcall(scene, T)
	_G.CreateColor = savedColor
	if not ok then error(frame, 0) end
	local count = Snap.Snapshot(frame, path, { title = title or name })
	return string.format("%s : %d éléments -> %s", name, count, path)
end

return Snap
