-- AzerothStyle.lua -- style de l'interface « Azeroth » (QuestCompanion 2.5.0)
--
-- Deux styles pour les bandeaux et le cadre du compagnon (réglage « Style de
-- l'interface », page Compagnon de route, /qc style azeroth|sobre) :
--   * Azeroth (par défaut) : le bandeau doré des hauts faits du jeu (« Haut
--     fait obtenu »), l'icône dans son cadre doré à gauche, le titre en
--     petites capitales sur la bande de parchemin, le nom en grand au centre,
--     un bouclier à droite (gris : pas encore à toi ; or : gagné), et une
--     apparition façon haut fait (éclosion, lueur, reflet, éclat) ; le
--     compagnon dans un cadre rond à volutes, son nom sur une plaque dorée ;
--   * Sobre : le style d'avant (aplats du thème, liseré ambre).
-- Les textures sont celles du client, désignées par leur nom d'atlas
-- (UiTextureAtlas « ui-achievement-* »), jamais embarquées. Leur présence
-- dans les données ne prouve pas qu'elles sont dans le client : on demande
-- au client (C_Texture.GetAtlasInfo) ; s'il en manque une, le style Sobre
-- s'affiche à la place, sans bruit (l'infobulle du réglage le dit).
-- Le changement de style s'applique tout de suite : chaque bandeau a un
-- cadre par style, créé à la demande et gardé (ns:StyleCached), le cadre du
-- compagnon est rhabillé sur place.
-- Aussi ici : le bandeau de résultat « Capturé ! » (les deux styles), et les
-- bandeaux des sceaux de zone et des titres de dresseur (file du carnet).
-- 2.5.1 : les fenêtres de capture (scène d'un lancer seul, choix au filet,
-- volée de « Tout capturer ») ont aussi leur habit Azeroth : cadre en bois
-- des hauts faits, plaque de titre, bandeau de verdict, boutons dorés
-- (dessinés). Il leur faut en plus le bois (ns:AzerothScenesOn) ; sans lui,
-- elles restent en Sobre. Construites par CaptureStage.lua et CaptureBatch.lua.
-- 2.7.0 (effets) : bulle façon « Talking Head », lueur ronde quand le
-- compagnon parle, éclats d'une brillante, évolution / niveau, ailes des
-- grandes récompenses (ns:AzerothRewardFX) : section « Effets Azeroth ».
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
	shieldGrey = "ui-achievement-shield-desaturated",
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
ns.AZEROTH_WOOD_SIZE, ns.AZEROTH_WOOD_OUT, ns.AZEROTH_WOOD_INSET, ns.AZEROTH_WOOD_PAD = 64, 8, 16, 26
-- police des hauts faits (Friz Quadrata, celle du client)
ns.AZEROTH_FONT = "Fonts\\FRIZQT__.TTF"
-- géométrie du bandeau (maquette validée : 310×101 à l'échelle 1,25) et de
-- la bande sombre du bandeau « Capture possible »
ns.AZEROTH_LAYOUT = {
	w = 388, h = 126, overlap = 10, stripW = 330, strip = 76,
	infoY = -16, hintY = -32, rowH = 18, rowBottom = 7,
	titleY = -28, titleW = 252, nameY = -50, nameW = 260, nameWide = 290, starsY = -82,
	nameMax = 20, nameMin = 11, titleMax = 12, titleMin = 9,
}
ns.CAPTURE_RESULT_SECONDS = 3.5   -- s d'affichage du bandeau « Capturé ! »
ns.CAPTURE_RESULT_STALE = 30      -- s d'attente au plus (combat) avant de l'oublier
local AZ = ns.AZEROTH_ATLAS
local LAY = ns.AZEROTH_LAYOUT
local INK = { 0.23, 0.14, 0.06 }          -- brun foncé du parchemin (#3a2410)
local SHINY_NAME = { 1, 0.886, 0.478 }    -- nom d'une brillante (#ffe27a)
local STAR_GOLD = { 1, 0.84, 0.29 }

local FR = {
	OPT_UI_STYLE           = "Style de l'interface",
	OPT_UI_STYLE_DESC      = "Bandeaux et cadre du compagnon. Azeroth : dorés, façon hauts faits. Sobre : le style d'avant.",
	OPT_UI_STYLE_MISSING   = "Les textures des hauts faits manquent sur ce client : le style Sobre s'affiche à la place.",
	UI_STYLE_azeroth       = "Azeroth (doré)",
	UI_STYLE_sobre         = "Sobre",
	UI_STYLE_MSG           = "Style de l'interface : %s.",
	UI_STYLE_MSG_MISSING   = "Style de l'interface : %s. Ses textures manquent sur ce client : le style Sobre reste affiché.",
	UI_STYLE_USAGE         = "/qc style azeroth|sobre (actuel : %s)",
	HELP_STYLE             = "/qc style azeroth|sobre — style des bandeaux et du cadre du compagnon",
	CAPTURE_RESULT         = "Capturé !",
	CAPTURE_RESULT_SHINY   = "Brillant capturé !",
	CAPTURE_RESULT_MORE    = "et %d de plus",
	JRN_KIND_seal          = "Sceau de zone",
	JRN_KIND_rank          = "Titre de dresseur",
}
local EN = {
	OPT_UI_STYLE           = "Interface style",
	OPT_UI_STYLE_DESC      = "Banners and companion frame. Azeroth: golden, achievement-style. Plain: the previous look.",
	OPT_UI_STYLE_MISSING   = "This client lacks the achievement textures: the Plain style is shown instead.",
	UI_STYLE_azeroth       = "Azeroth (golden)",
	UI_STYLE_sobre         = "Plain",
	UI_STYLE_MSG           = "Interface style: %s.",
	UI_STYLE_MSG_MISSING   = "Interface style: %s. Its textures are missing on this client: the Plain style stays on screen.",
	UI_STYLE_USAGE         = "/qc style azeroth|sobre (current: %s)",
	HELP_STYLE             = "/qc style azeroth|sobre — style of the banners and the companion frame",
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
	info = done and ns.Plain and ns.Plain(info) or (done and info or nil)
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

-- Le style affiché : Azeroth seulement si le client a ses textures
function ns:UIStyle()
	if self:UIStyleChoice() == "azeroth" and self:AzerothAtlasOK() then return "azeroth" end
	return "sobre"
end
function ns:AzerothOn() return self:UIStyle() == "azeroth" end
-- Style des fenêtres de capture : Azeroth si le style l'est et que le bois est là
function ns:AzerothScenesOn() return self:AzerothOn() and self:AzerothSceneAtlasOK() end

function ns:UIStyleChoices()
	local list = {}
	for _, id in ipairs(ns.UI_STYLES) do list[#list + 1] = { value = id, label = L["UI_STYLE_" .. id] } end
	return list
end

-- Les bandeaux mis de côté au changement de style : cache[clé][style]
ns.uiStyleCache = ns.uiStyleCache or {}
local STYLED_FRAMES = { "captureToast", "guildFeatToast", "journalToast", "captureResult" }

-- Un cadre déjà construit pour le style courant (et retiré du cache), ou nil
function ns:StyleCached(key)
	local slot = self.uiStyleCache[key]
	if not slot then return nil end
	local style = self:UIStyle()
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
	for _, key in ipairs(STYLED_FRAMES) do
		local frame = self[key]
		if frame and (frame.uiStyle or "sobre") ~= style then
			local shown = frame:IsShown()
			frame:Hide()
			self.uiStyleCache[key] = self.uiStyleCache[key] or {}
			self.uiStyleCache[key][frame.uiStyle or "sobre"] = frame
			self[key] = nil
			if shown then
				if key == "captureToast" then
					local hideAt = self.captureToastHideAt
					if self.CaptureToastShow then self:CaptureToastShow() end
					self.captureToastHideAt = hideAt or self.captureToastHideAt
				else
					local ensure = (key == "guildFeatToast" and self.EnsureGuildFeatToast)
						or (key == "journalToast" and self.EnsureJournalToast) or nil
					local fresh = ensure and ensure(self)
					if fresh then
						CopyTexts(frame, fresh)
						fresh:Show()
						self:StyleShown(fresh, { shield = key == "journalToast" and "gold" or nil })
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
local ANIM_TIME = 2.4
local function AnimStep(banner)
	local frame = banner.owner
	local t = Clock() - (frame.animAt or 0)
	local scale, alpha = 1, 1
	if t < 0.6 then
		local p = t / 0.6
		scale = p < 0.7 and (0.6 + 0.45 * p / 0.7) or (1.05 - 0.05 * (p - 0.7) / 0.3)
		alpha = Clamp01(t / 0.3)
	end
	banner:SetScale(scale)
	banner:SetAlpha(alpha)
	local g = t - 0.2
	local glow = g < 0 and 0 or (g < 0.36 and 0.8 * g / 0.36 or 0.8 * Clamp01(1 - (g - 0.36) / 1.08))
	frame.glow:SetAlpha(glow)
	if frame.animShine then
		local s = (t - 0.5) / 1.3
		if s >= 0 and s <= 1 then
			frame.shine:ClearAllPoints()
			frame.shine:SetPoint("CENTER", banner, "CENTER", -170 + 340 * s, 0)
			frame.shine:SetAlpha(s < 0.35 and 0.9 * s / 0.35 or 0.9 * Clamp01(1 - (s - 0.35) / 0.65))
			frame.shine:Show()
		else
			frame.shine:Hide()
		end
	end
	if frame.animBling then
		local b = (t - 0.8) / 1.4
		if b >= 0 and b <= 1 then
			local size = 44 + 88 * Clamp01(b / 0.6)
			frame.bling:SetSize(size, size)
			frame.bling:SetAlpha(b < 0.25 and b / 0.25 or Clamp01(1 - (b - 0.25) / 0.35))
			if frame.bling.SetRotation then pcall(frame.bling.SetRotation, frame.bling, 0.7 * b) end
			frame.bling:Show()
		else
			frame.bling:Hide()
		end
	end
	if t >= ANIM_TIME then
		banner:SetScale(1); banner:SetAlpha(1)
		frame.glow:SetAlpha(0); frame.shine:Hide(); frame.bling:Hide()
		banner:SetScript("OnUpdate", nil)
		frame.animating = nil
	end
end

local function Play(frame, opts)
	opts = opts or {}
	frame.animAt = Clock()
	frame.animShine, frame.animBling = opts.shine and true or nil, opts.bling and frame.shield:IsShown() or nil
	frame.animating = true
	frame.shine:Hide(); frame.bling:Hide()
	frame.banner:SetScript("OnUpdate", function(banner)
		if not frame:IsShown() then return end
		local ok, err = pcall(AnimStep, banner)
		if not ok then
			banner:SetScript("OnUpdate", nil)
			banner:SetScale(1); banner:SetAlpha(1)
			if ns.RecordError then ns:RecordError("azeroth:anim", err) end
		end
	end)
	AnimStep(frame.banner)
	return true
end

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

-- Un bouclier : "gold" (or), "grey" (gris ; pas de gris dans ce client : le
-- doré, désaturé), sinon caché. Rend le genre posé (ou nil).
function ns.AzerothShield(tex, kind)
	if not tex then return nil end
	if kind == "gold" or kind == "grey" then
		local done = false
		if kind == "gold" or ns.AzerothHasAtlas(AZ.shieldGrey) then
			done = Atlas(tex, kind == "gold" and AZ.shield or AZ.shieldGrey)
		end
		if not done and kind == "grey" then
			Atlas(tex, AZ.shield)
			if tex.SetDesaturated then pcall(tex.SetDesaturated, tex, true) end
		elseif tex.SetDesaturated then
			pcall(tex.SetDesaturated, tex, false)
		end
		tex:Show()
		return kind
	end
	tex:Hide()
	return nil
end

-- Crée un bandeau Azeroth. opts : name, strata, guild (fond de guilde),
-- round (cadre rond à volutes), strip (bande sombre dessous : infos et
-- boutons). Champs : .banner (les textures dorées), .icon, .title, .text
-- (le nom), .stars, .shield, .glow, .shine, .bling ; avec strip : .strip
-- (la bande, sert d'ancre), .info, .hint. Méthodes : SetAccent (gardée pour
-- les appelants du style Sobre), SetShield("grey" | "gold" | nil), Fit(), Play(opts).
function ns:AzerothCreateBanner(opts)
	opts = opts or {}
	local stripH = opts.strip and LAY.strip or 0
	local ok, frame = pcall(CreateFrame, "Frame", opts.name, UIParent)
	if not ok or not frame then return nil end
	frame:SetSize(LAY.w, LAY.h + (opts.strip and (stripH - LAY.overlap) or 0))
	frame:SetFrameStrata(opts.strata or "MEDIUM")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(false)
	frame:SetMovable(true)
	if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
	if frame.StartMoving then frame:SetScript("OnDragStart", frame.StartMoving) end
	if frame.StopMovingOrSizing then frame:SetScript("OnDragStop", frame.StopMovingOrSizing) end
	frame.uiStyle, frame.azeroth, frame.chrome = "azeroth", true, "azeroth"
	frame.contentLeft, frame.contentTop = 0, 0

	-- la zone du bandeau (fixe) et le bandeau lui-même (il éclot depuis son centre)
	local area = CreateFrame("Frame", nil, frame)
	area:SetSize(LAY.w, LAY.h)
	area:SetPoint("TOP", frame, "TOP", 0, 0)
	frame.bannerArea = area
	local banner = CreateFrame("Frame", nil, area)
	banner:SetSize(LAY.w, LAY.h)
	banner:SetPoint("CENTER", area, "CENTER", 0, 0)
	banner.owner = frame
	frame.banner = banner

	frame.bg = banner:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints(banner)
	Atlas(frame.bg, opts.guild and AZ.bgGuild or AZ.bg)
	frame.glow = banner:CreateTexture(nil, "BACKGROUND", nil, -1)
	frame.glow:SetSize(520, 200)
	frame.glow:SetPoint("CENTER", banner, "CENTER", 0, 0)
	Atlas(frame.glow, AZ.glow)
	if frame.glow.SetBlendMode then frame.glow:SetBlendMode("ADD") end
	frame.glow:SetAlpha(0)

	-- l'icône dans son cadre, à cheval sur le bout gauche
	frame.iconFrame = banner:CreateTexture(nil, "ARTWORK", nil, 2)
	if opts.round then
		frame.iconFrame:SetSize(92, 88)
		frame.iconFrame:SetPoint("TOPLEFT", banner, "TOPLEFT", -34, -18)
	else
		frame.iconFrame:SetSize(86, 86)
		frame.iconFrame:SetPoint("TOPLEFT", banner, "TOPLEFT", -30, -20)
	end
	Atlas(frame.iconFrame, opts.round and AZ.frameRound or AZ.frame)
	frame.icon = banner:CreateTexture(nil, "ARTWORK", nil, 1)
	frame.icon:SetSize(opts.round and 48 or 52, opts.round and 48 or 52)
	frame.icon:SetPoint("CENTER", frame.iconFrame, "CENTER", 0, 0)

	-- titre (petites capitales, brun sur le parchemin), nom (blanc, ombré), étoiles
	frame.title = banner:CreateFontString(nil, "OVERLAY", Theme.F_CAPS)
	frame.title:SetPoint("TOP", banner, "TOP", 2, LAY.titleY)
	frame.title:SetJustifyH("CENTER")
	AzFont(frame.title, LAY.titleMax)
	frame.title:SetTextColor(INK[1], INK[2], INK[3], 1)
	if Theme.NoShadow then Theme.NoShadow(frame.title) end
	frame.title:SetWidth(LAY.titleW)
	if frame.title.SetWordWrap then frame.title:SetWordWrap(false) end
	frame.nameWidth = opts.guild and LAY.nameWide or LAY.nameW
	frame.text = banner:CreateFontString(nil, "OVERLAY", Theme.F_TITLE)
	frame.text:SetPoint("TOP", banner, "TOP", opts.guild and 10 or 2, LAY.nameY)
	frame.text:SetJustifyH("CENTER")
	AzFont(frame.text, LAY.nameMax)
	frame.text:SetTextColor(1, 1, 1, 1)
	if frame.text.SetShadowColor then frame.text:SetShadowColor(0, 0, 0, 1) end
	if frame.text.SetShadowOffset then frame.text:SetShadowOffset(1, -2) end
	frame.text:SetWidth(frame.nameWidth)
	if frame.text.SetWordWrap then frame.text:SetWordWrap(false) end
	frame.stars = banner:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.stars:SetPoint("TOP", banner, "TOP", opts.guild and 10 or 0, LAY.starsY)
	frame.stars:SetJustifyH("CENTER")
	frame.stars:SetWidth(frame.nameWidth)
	if frame.stars.SetWordWrap then frame.stars:SetWordWrap(false) end
	frame.stars:SetTextColor(STAR_GOLD[1], STAR_GOLD[2], STAR_GOLD[3], 1)

	-- bouclier à droite, et l'éclat qui le traverse ; le reflet du bandeau
	frame.shield = banner:CreateTexture(nil, "ARTWORK", nil, 2)
	frame.shield:SetSize(70, 62)
	frame.shield:SetPoint("TOPRIGHT", banner, "TOPRIGHT", 12, -30)
	frame.shield:Hide()
	frame.bling = banner:CreateTexture(nil, "OVERLAY", nil, 2)
	frame.bling:SetSize(110, 110)
	frame.bling:SetPoint("CENTER", frame.shield, "CENTER", 0, 0)
	Atlas(frame.bling, AZ.bling)
	if frame.bling.SetBlendMode then frame.bling:SetBlendMode("ADD") end
	frame.bling:Hide()
	frame.shine = banner:CreateTexture(nil, "OVERLAY", nil, 1)
	frame.shine:SetSize(70, 96)
	frame.shine:SetPoint("CENTER", banner, "CENTER", 0, 0)
	Atlas(frame.shine, AZ.shine)
	if frame.shine.SetBlendMode then frame.shine:SetBlendMode("ADD") end
	frame.shine:Hide()

	-- la bande sombre (liseré doré), glissée sous le bas du bandeau
	if opts.strip then
		frame.strip = Theme.Solid(frame, "BACKGROUND", Theme.WINDOW or { 0.06, 0.05, 0.04 }, 0.94)
		frame.strip:SetSize(LAY.stripW, stripH)
		frame.strip:SetPoint("TOP", area, "BOTTOM", 0, LAY.overlap)
		frame.stripEdge = Theme.Border(frame, Theme.GOLD_SOFT, 0.9, "BORDER", frame.strip)
		local textW = LAY.stripW - 24
		frame.info = Theme.Text(frame, Theme.F_SMALL, Theme.GOLD)
		frame.info:SetPoint("TOPLEFT", frame.strip, "TOPLEFT", 12, LAY.infoY)
		frame.info:SetWidth(textW)
		frame.info:SetJustifyH("LEFT")
		if frame.info.SetWordWrap then frame.info:SetWordWrap(false) end
		frame.hint = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED)
		frame.hint:SetPoint("TOPLEFT", frame.strip, "TOPLEFT", 12, LAY.hintY)
		frame.hint:SetWidth(textW)
		frame.hint:SetJustifyH("LEFT")
		if frame.hint.SetWordWrap then frame.hint:SetWordWrap(false) end
	end

	function frame:SetAccent(color) self.accentColor = color end
	function frame:SetShield(kind) self.shieldKind = ns.AzerothShield(self.shield, kind) end
	function frame:Fit()
		ns.AzerothFit(self.title, LAY.titleW, LAY.titleMax, LAY.titleMin)
		return ns.AzerothFit(self.text, self.nameWidth, LAY.nameMax, LAY.nameMin)
	end
	function frame:Play(o) return Play(self, o) end
	frame:Hide()
	return frame
end

-- Après avoir rempli un bandeau : en Azeroth, couleur du nom (or pour une
-- brillante), nom ajusté, bouclier, apparition. En Sobre : rien.
-- opts : shiny, shield ("grey" | "gold"), play, bling, shine
function ns:StyleShown(frame, opts)
	if not (frame and frame.azeroth) then return false end
	opts = opts or {}
	local c = opts.shiny and SHINY_NAME or { 1, 1, 1 }
	frame.text:SetTextColor(c[1], c[2], c[3], 1)
	frame:SetShield(opts.shield)
	frame:Fit()
	if opts.play then
		frame:Play({ bling = opts.bling or opts.shield == "gold", shine = opts.shine or opts.shiny })
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Les fenêtres de capture (2.5.1) : cadre en bois, plaque de titre, bandeau
-- de verdict, boutons dorés. Utilisés par CaptureStage.lua (la scène d'un
-- lancer seul) et CaptureBatch.lua (le choix au filet, la volée) quand
-- ns:AzerothScenesOn() ; sinon ces fenêtres gardent leur style Sobre.
-- ---------------------------------------------------------------------------
local WOOD_BG = { 0.11, 0.086, 0.06 }      -- fond sombre et chaud (#1c160f)
local WOOD_DEEP = { 0.07, 0.055, 0.035 }   -- bas du fond (#120e09)
local WOOD_WARM = { 0.23, 0.18, 0.12 }     -- haut du fond (#3a2e1f)
ns.AZEROTH_COLORS = { ink = INK, shinyName = SHINY_NAME, star = STAR_GOLD, flavour = { 0.85, 0.82, 0.75 },
	fled = { 0.8, 0.75, 0.66 }, caption = { 0.91, 0.77, 0.42 }, hint = { 0.61, 0.56, 0.47 } }
ns.AzerothFont, ns.AzerothAtlas = AzFont, Atlas
-- Capitales sûres : seules les lettres a-z et les accents passent en
-- capitales (string.upper d'un client réglé autrement casserait « … »)
function ns.AzerothUpper(text)
	text = tostring(text or ""):gsub("[a-z]", string.upper)
	if Theme.Upper then text = text:gsub("[\195\197][\128-\191]", Theme.Upper) end
	return text
end

-- Le cadre en bois autour de `frame` : huit pièces (coins débordant de
-- AZEROTH_WOOD_OUT px, bords répétés entre eux) sur un fond sombre et chaud
-- (aplat, dégradé, halo doux au tiers haut). Rend la table des pièces.
function ns:AzerothWood(frame)
	local S, O = ns.AZEROTH_WOOD_SIZE, ns.AZEROTH_WOOD_OUT
	frame.woodBg = Theme.Solid(frame, "BACKGROUND", WOOD_BG, 0.97)
	frame.woodBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
	frame.woodBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
	frame.woodShade = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	frame.woodShade:SetTexture(Theme.SOLID)
	frame.woodShade:SetPoint("TOPLEFT", frame.woodBg, "TOPLEFT", 0, 0)
	frame.woodShade:SetPoint("BOTTOMRIGHT", frame.woodBg, "BOTTOMRIGHT", 0, 0)
	if Theme.Gradient then Theme.Gradient(frame.woodShade, "VERTICAL", WOOD_DEEP, 0.6, WOOD_WARM, 0.35) end
	local art = ns.CAPTURE_ART
	if art and art.halo then
		frame.woodGlow = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
		frame.woodGlow:SetTexture(art.halo)
		frame.woodGlow:SetVertexColor(0.55, 0.42, 0.24, 0.35)
		frame.woodGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
		frame.woodGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
	end
	local wood = {}
	local function Piece(key)
		local tex = frame:CreateTexture(nil, "BORDER", nil, 1)
		tex:SetSize(S, S)
		Atlas(tex, ns.AZEROTH_WOOD[key])
		wood[key] = tex
		return tex
	end
	Piece("tl"):SetPoint("TOPLEFT", frame, "TOPLEFT", -O, O)
	Piece("tr"):SetPoint("TOPRIGHT", frame, "TOPRIGHT", O, O)
	Piece("bl"):SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -O, -O)
	Piece("br"):SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", O, -O)
	local top, bottom, left, right = Piece("top"), Piece("bottom"), Piece("left"), Piece("right")
	top:SetPoint("TOPLEFT", wood.tl, "TOPRIGHT", 0, 0)
	top:SetPoint("TOPRIGHT", wood.tr, "TOPLEFT", 0, 0)
	bottom:SetPoint("BOTTOMLEFT", wood.bl, "BOTTOMRIGHT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", wood.br, "BOTTOMLEFT", 0, 0)
	left:SetPoint("TOPLEFT", wood.tl, "BOTTOMLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", wood.bl, "TOPLEFT", 0, 0)
	right:SetPoint("TOPRIGHT", wood.tr, "BOTTOMRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", wood.br, "TOPRIGHT", 0, 0)
	Method(top, "SetHorizTile", true)
	Method(bottom, "SetHorizTile", true)
	Method(left, "SetVertTile", true)
	Method(right, "SetVertTile", true)
	frame.wood = wood
	return wood
end

-- Une fenêtre en bois : mêmes réglages que Theme.CreateToast (strate,
-- gardée à l'écran bois compris, déplaçable). opts : name, strata.
function ns:AzerothCreateWindow(width, height, opts)
	opts = opts or {}
	local ok, frame = pcall(CreateFrame, "Frame", opts.name, UIParent)
	if not ok or not frame then return nil end
	frame:SetSize(width, height)
	frame:SetFrameStrata(opts.strata or "DIALOG")
	frame:SetClampedToScreen(true)
	local o = ns.AZEROTH_WOOD_OUT
	Method(frame, "SetClampRectInsets", -o, o, o, -o)
	frame.clampInset = o
	frame:EnableMouse(false)
	frame:SetMovable(true)
	if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
	if frame.StartMoving then frame:SetScript("OnDragStart", frame.StartMoving) end
	if frame.StopMovingOrSizing then frame:SetScript("OnDragStop", frame.StopMovingOrSizing) end
	frame.uiStyle, frame.azeroth, frame.chrome = "azeroth", true, "wood"
	frame.contentLeft, frame.contentTop = ns.AZEROTH_WOOD_PAD, 0
	self:AzerothWood(frame)
	return frame
end

-- La plaque de titre (fond « mini » des hauts faits) : .title en petites
-- capitales brunes, .text (le nom) en grand dessous ; plate:Fit() rapetisse
-- le nom pour qu'il tienne. Un cadre : il passe devant les effets du parent.
function ns:AzerothPlate(parent, width, height)
	local plate = CreateFrame("Frame", nil, parent)
	plate:SetSize(width, height)
	plate:SetFrameLevel((parent:GetFrameLevel() or 1) + 14)
	plate.bg = plate:CreateTexture(nil, "ARTWORK")
	plate.bg:SetAllPoints(plate)
	Atlas(plate.bg, AZ.plate)
	plate.nameW = width - 60
	plate.title = plate:CreateFontString(nil, "OVERLAY", Theme.F_CAPS)
	plate.title:SetPoint("TOP", plate, "TOP", 0, -math.floor(height * 0.2))
	plate.title:SetJustifyH("CENTER")
	AzFont(plate.title, 11)
	plate.title:SetTextColor(INK[1], INK[2], INK[3], 1)
	if Theme.NoShadow then Theme.NoShadow(plate.title) end
	plate.title:SetWidth(plate.nameW)
	if plate.title.SetWordWrap then plate.title:SetWordWrap(false) end
	plate.text = plate:CreateFontString(nil, "OVERLAY", Theme.F_TITLE)
	plate.text:SetPoint("TOP", plate, "TOP", 0, -math.floor(height * 0.39))
	plate.text:SetJustifyH("CENTER")
	AzFont(plate.text, 17)
	plate.text:SetTextColor(1, 1, 1, 1)
	if plate.text.SetShadowColor then plate.text:SetShadowColor(0, 0, 0, 1) end
	if plate.text.SetShadowOffset then plate.text:SetShadowOffset(1, -2) end
	plate.text:SetWidth(plate.nameW)
	if plate.text.SetWordWrap then plate.text:SetWordWrap(false) end
	function plate:SetName(text, shiny)
		self.text:SetText(text or "")
		local c = shiny and SHINY_NAME or { 1, 1, 1 }
		self.text:SetTextColor(c[1], c[2], c[3], 1)
		return ns.AzerothFit(self.text, self.nameW, 17, 10)
	end
	return plate
end

-- Le bandeau de verdict des scènes : fond des hauts faits sans icône, .title
-- (petites capitales), .text (le nom), .line (ligne de dessous), .shield
-- (banner:SetShield), .bling, .glow, .shine. Posé dans une zone fixe
-- (banner.area, c'est elle qu'on ancre) : il éclot depuis son centre.
function ns:AzerothVerdict(parent, width, height)
	local area = CreateFrame("Frame", nil, parent)
	area:SetSize(width, height)
	local banner = CreateFrame("Frame", nil, area)
	banner:SetSize(width, height)
	banner:SetPoint("CENTER", area, "CENTER", 0, 0)
	banner.area, banner.azeroth = area, true
	local k = height / LAY.h
	banner.glow = banner:CreateTexture(nil, "BACKGROUND", nil, -1)
	banner.glow:SetSize(width * 1.34, height * 1.6)
	banner.glow:SetPoint("CENTER", banner, "CENTER", 0, 0)
	Atlas(banner.glow, AZ.glow)
	if banner.glow.SetBlendMode then banner.glow:SetBlendMode("ADD") end
	banner.glow:SetAlpha(0)
	banner.bg = banner:CreateTexture(nil, "BACKGROUND")
	banner.bg:SetAllPoints(banner)
	Atlas(banner.bg, AZ.bg)
	banner.nameW = width - 100
	banner.title = banner:CreateFontString(nil, "OVERLAY", Theme.F_CAPS)
	banner.title:SetPoint("TOP", banner, "TOP", 2, math.floor(LAY.titleY * k))
	banner.title:SetJustifyH("CENTER")
	AzFont(banner.title, 11)
	banner.title:SetTextColor(INK[1], INK[2], INK[3], 1)
	if Theme.NoShadow then Theme.NoShadow(banner.title) end
	banner.title:SetWidth(width - 60)
	if banner.title.SetWordWrap then banner.title:SetWordWrap(false) end
	banner.text = banner:CreateFontString(nil, "OVERLAY", Theme.F_TITLE)
	banner.text:SetPoint("TOP", banner, "TOP", 2, math.floor(LAY.nameY * k))
	banner.text:SetJustifyH("CENTER")
	AzFont(banner.text, 20)
	banner.text:SetTextColor(1, 1, 1, 1)
	if banner.text.SetShadowColor then banner.text:SetShadowColor(0, 0, 0, 1) end
	if banner.text.SetShadowOffset then banner.text:SetShadowOffset(1, -2) end
	banner.text:SetWidth(banner.nameW)
	if banner.text.SetWordWrap then banner.text:SetWordWrap(false) end
	banner.lineY = math.floor(LAY.starsY * k) + 2
	banner.line = banner:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	banner.line:SetPoint("TOP", banner, "TOP", 0, banner.lineY)
	banner.line:SetJustifyH("CENTER")
	banner.line:SetWidth(banner.nameW)
	if banner.line.SetWordWrap then banner.line:SetWordWrap(false) end
	banner.shield = banner:CreateTexture(nil, "ARTWORK", nil, 2)
	banner.shield:SetSize(58, 52)
	banner.shield:SetPoint("TOPRIGHT", banner, "TOPRIGHT", 6, -26)
	banner.shield:Hide()
	banner.bling = banner:CreateTexture(nil, "OVERLAY", nil, 2)
	banner.bling:SetSize(100, 100)
	banner.bling:SetPoint("CENTER", banner.shield, "CENTER", 0, 0)
	Atlas(banner.bling, AZ.bling)
	if banner.bling.SetBlendMode then banner.bling:SetBlendMode("ADD") end
	banner.bling:Hide()
	banner.shine = banner:CreateTexture(nil, "OVERLAY", nil, 1)
	banner.shine:SetSize(60, height * 0.8)
	Atlas(banner.shine, AZ.shine)
	if banner.shine.SetBlendMode then banner.shine:SetBlendMode("ADD") end
	banner.shine:Hide()
	function banner:SetShield(kind) self.shieldKind = ns.AzerothShield(self.shield, kind) end
	function banner:Fit()
		ns.AzerothFit(self.title, width - 60, 11, 9)
		return ns.AzerothFit(self.text, self.nameW, 20, 11)
	end
	banner:Hide()
	return banner
end

-- Le bouton doré des fenêtres de capture (dessiné : dégradé brun-or, liseré
-- d'or de 2 px, reflet clair en haut ; aucune texture de bouton du jeu).
-- kind : "gold" (principal) ou "dark" (secondaire, plus sombre). Champs
-- .text, .sub (ligne de dessous, button:SetSub) ; SetText/GetText.
local BUTTON_SKINS = {
	gold = { top = { 0.48, 0.29, 0.07 }, bottom = { 0.29, 0.165, 0.03 }, edge = { 0.85, 0.66, 0.27 } },
	dark = { top = { 0.235, 0.19, 0.133 }, bottom = { 0.133, 0.10, 0.067 }, edge = { 0.54, 0.415, 0.17 } },
}
ns.AZEROTH_BUTTON_SKINS = BUTTON_SKINS
local BUTTON_TEXT, BUTTON_SUB = { 1, 0.95, 0.81 }, { 0.9, 0.83, 0.64 }

local function ButtonLayout(button)
	local sub = button.sub:IsShown()
	button.text:ClearAllPoints()
	button.text:SetPoint("CENTER", button, "CENTER", 0, sub and 6 or 0)
end

function ns:AzerothButton(parent, width, height, label, onClick, kind)
	local skin = BUTTON_SKINS[kind] or BUTTON_SKINS.gold
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, height)
	button.azeroth, button.style, button.skin = true, BUTTON_SKINS[kind] and kind or "gold", skin
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetTexture(Theme.SOLID)
	button.bg:SetAllPoints(button)
	if Theme.Gradient then Theme.Gradient(button.bg, "VERTICAL", skin.bottom, 1, skin.top, 1) end
	button.inner = button:CreateTexture(nil, "BACKGROUND", nil, 1)
	button.inner:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	button.inner:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	button.inner:SetAlpha(0)
	button.border = Theme.Border(button, skin.edge, 1, "BORDER")
	button.border2 = Theme.Border(button, skin.edge, 0.8, "BORDER", button.inner)
	button.gloss = Theme.Solid(button, "ARTWORK", { 1, 0.86, 0.59 }, 0.35)
	button.gloss:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	button.gloss:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
	button.gloss:SetHeight(1)
	button.hover = Theme.Solid(button, "ARTWORK", { 1, 0.85, 0.5 }, 0.12)
	button.hover:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	button.hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	if button.hover.SetBlendMode then button.hover:SetBlendMode("ADD") end
	button.hover:Hide()
	button.text = button:CreateFontString(nil, "OVERLAY", Theme.F_LABEL)
	AzFont(button.text, height >= 34 and 13 or 11)
	button.text:SetTextColor(BUTTON_TEXT[1], BUTTON_TEXT[2], BUTTON_TEXT[3], 1)
	if button.text.SetShadowColor then button.text:SetShadowColor(0, 0, 0, 1) end
	if button.text.SetShadowOffset then button.text:SetShadowOffset(1, -1) end
	button.text:SetWidth(width - 12)
	if button.text.SetWordWrap then button.text:SetWordWrap(false) end
	button.text:SetText(label or "")
	button.sub = button:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	button.sub:SetPoint("CENTER", button, "CENTER", 0, -8)
	button.sub:SetTextColor(BUTTON_SUB[1], BUTTON_SUB[2], BUTTON_SUB[3], 1)
	button.sub:SetWidth(width - 12)
	if button.sub.SetWordWrap then button.sub:SetWordWrap(false) end
	button.sub:Hide()
	ButtonLayout(button)
	function button:SetText(text) self.text:SetText(text) end
	function button:GetText() return self.text:GetText() end
	function button:SetSub(text)
		self.sub:SetText(text or "")
		if text and text ~= "" then self.sub:Show() else self.sub:Hide() end
		ButtonLayout(self)
	end
	button:SetScript("OnEnter", function(b)
		b.hover:Show()
		b.border:SetColor(1, 0.85, 0.5, 1)
	end)
	button:SetScript("OnLeave", function(b)
		b.hover:Hide()
		local e = b.skin.edge
		b.border:SetColor(e[1], e[2], e[3], 1)
	end)
	if onClick then button:SetScript("OnClick", onClick) end
	return button
end

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
	local art = ns.CAPTURE_ART
	local glyph = art and art.icon or Theme.LOGO_SMALL
	local frame
	if self:AzerothOn() then
		frame = self:AzerothCreateBanner({ strata = "HIGH", name = "QuestCompanionCaptureResultAzeroth" })
		if not frame then return nil end
		frame.icon:SetTexture(glyph)
		if art and art.icon then frame.icon:SetVertexColor(Theme.GOLD_LIGHT[1], Theme.GOLD_LIGHT[2], Theme.GOLD_LIGHT[3], 1) end
	else
		if not (Theme and Theme.CreateToast) then return nil end
		frame = Theme.CreateToast(UIParent, 300, 66, { strata = "HIGH", accent = Theme.GOLD, name = "QuestCompanionCaptureResult" })
		if not frame then return nil end
		frame.uiStyle = "sobre"
		local left = frame.contentLeft or 14
		frame.icon = frame:CreateTexture(nil, "ARTWORK")
		frame.icon:SetTexture(glyph)
		if art and art.icon then frame.icon:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1) end
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
	end
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
	if not frame.azeroth then
		local c = result.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or Theme.PARCHMENT
		frame.text:SetTextColor(c[1], c[2], c[3])
		if frame.SetAccent then frame:SetAccent(result.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or Theme.GOLD) end
	end
	frame.result = result
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame, 0.2) end
	self:StyleShown(frame, { shiny = result.shiny, shield = "gold", play = true, bling = true, shine = result.shiny })
	self.captureResultHideAt = Clock() + ns.CAPTURE_RESULT_SECONDS
	return frame
end

function ns:CaptureResultHide()
	self.captureResultHideAt = nil
	if self.captureResult then self.captureResult:Hide() end
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
ns.CaptureSceneShowsVerdict = SceneShowsVerdict
do
	local base = ns.CaptureResolve
	if base then
		function ns:CaptureResolve(rolling, ...)
			local result = base(self, rolling, ...)
			local target = rolling and rolling.target
			if target and rolling.success and not rolling.batch and not self.captureBatchResolving
				and not SceneShowsVerdict(self, rolling) then
				self:CaptureResultQueue({ name = target.name, shiny = target.shiny and true or false, stars = rolling.stars })
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
						stars = best.stars, more = got - 1 })
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
local PLATE_NAME_Y = 16   -- centre du nom, depuis le bas de la plaque
local PLATE_MOOD_Y = 35   -- centre de l'humeur, depuis le bas de la plaque
ns.AZEROTH_COMPANION_PLATE = { height = PLATE_H, nameY = PLATE_NAME_Y, moodY = PLATE_MOOD_Y }

local function BuildCompanionSkin(frame)
	local skin = CreateFrame("Frame", nil, frame)
	skin:SetAllPoints(frame)
	skin:SetFrameLevel((frame:GetFrameLevel() or 1) + 4)
	skin.ring = skin:CreateTexture(nil, "ARTWORK")
	skin.ring:SetSize(RING_W, RING_H)
	skin.ring:SetPoint("CENTER", frame, "TOP", 0, RING_Y)
	Atlas(skin.ring, AZ.frameRound)
	local w = (frame:GetWidth() or 104) + 8
	skin.plate = skin:CreateTexture(nil, "BACKGROUND")
	skin.plate:SetSize(w, PLATE_H)
	skin.plate:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
	Atlas(skin.plate, AZ.plate)
	-- le fond gagné, en disque sous l'anneau (masque du client, s'il existe)
	if frame.CreateMaskTexture then
		local ok, mask = pcall(frame.CreateMaskTexture, frame)
		if ok and mask then
			pcall(mask.SetTexture, mask, MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetSize(RING_W - 30, RING_W - 30)
			mask:SetPoint("CENTER", frame, "TOP", 0, RING_Y)
			skin.mask = mask
		end
	end
	skin:Hide()
	return skin
end

local function Masked(frame, on)
	local mask = frame.azSkin and frame.azSkin.mask
	if not mask then return false end
	local regions = { frame.bg }
	for _, star in ipairs(frame.stars or {}) do regions[#regions + 1] = star end
	for _, region in ipairs(regions) do
		if region then
			if on and not region.azMasked then
				if Method(region, "AddMaskTexture", mask) then region.azMasked = true end
			elseif not on and region.azMasked then
				Method(region, "RemoveMaskTexture", mask)
				region.azMasked = nil
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

function ns:CompanionApplyUIStyle()
	local frame = self.companionFrame
	if not frame then return nil end
	local az = self:AzerothOn()
	if az and not frame.azSkin then frame.azSkin = BuildCompanionSkin(frame) end
	local skin = frame.azSkin
	if az then
		skin:Show()
		EdgesShown(frame, false)
		Masked(frame, true)
		-- nom et humeur sur la plaque (au-dessus du modèle et de l'anneau)
		for _, fs in ipairs({ frame.name, frame.mood }) do
			if fs and fs.SetParent then fs:SetParent(skin) end
		end
		if frame.name then
			frame.name:ClearAllPoints()
			frame.name:SetPoint("CENTER", skin.plate, "BOTTOM", 0, PLATE_NAME_Y)
			frame.name:SetTextColor(1, 1, 1, 1)
			if frame.name.SetShadowColor then frame.name:SetShadowColor(0, 0, 0, 1) end
			if frame.name.SetShadowOffset then frame.name:SetShadowOffset(1, -1) end
		end
		if frame.mood then
			frame.mood:ClearAllPoints()
			frame.mood:SetPoint("CENTER", skin.plate, "BOTTOM", 0, PLATE_MOOD_Y)
			frame.mood:SetTextColor(INK[1], INK[2], INK[3], 1)
			if Theme.NoShadow then Theme.NoShadow(frame.mood) end
		end
	elseif frame.uiStyle == "azeroth" then
		if skin then skin:Hide() end
		Masked(frame, false)
		for _, fs in ipairs({ frame.name, frame.mood }) do
			if fs and fs.SetParent then fs:SetParent(frame) end
		end
		-- les places du style Sobre (Companion.lua)
		if frame.name then
			frame.name:ClearAllPoints(); frame.name:SetPoint("BOTTOM", frame, "BOTTOM", 0, 19)
			frame.name:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3], 1)
		end
		if frame.mood then frame.mood:ClearAllPoints(); frame.mood:SetPoint("BOTTOM", frame, "BOTTOM", 0, 6) end
		if frame.mood then frame.mood:SetTextColor(Theme.MUTED_LIGHT[1], Theme.MUTED_LIGHT[2], Theme.MUTED_LIGHT[3], 1) end
		if frame.mood and frame.mood.SetShadowColor then frame.mood:SetShadowColor(0, 0, 0, 0.6); frame.mood:SetShadowOffset(1, -1) end
		EdgesShown(frame, true)
	end
	frame.uiStyle = az and "azeroth" or "sobre"
	-- le cadre gagné (bordure du client) revient en Sobre
	if not az and self.CompanionApplyFrame then self:CompanionApplyFrame() end
	return frame.uiStyle
end

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
			if frame and frame.uiStyle == "azeroth" then EdgesShown(frame, false) end
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
local FX_GOLD = { 1, 0.80, 0.38 }          -- teinte des lueurs blanches
local FX_NAME = { 0.48, 0.29, 0.07 }       -- nom du compagnon sur le parchemin (#7a4a12)
local FX_TEXT = { 1, 0.86, 0.45 }          -- « Aguerri ! »
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
ns.AzerothAtlasMirrored = AtlasMirrored

-- Le compagnon est-il habillé en Azeroth, affiché, module allumé ?
local function AzCompanion(self)
	local frame = self.companionFrame
	if not (frame and frame.uiStyle == "azeroth" and frame:IsShown()) then return nil end
	if ns.CompanionOn and not ns.CompanionOn() then return nil end
	return frame
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
local function BubbleSkin(bubble)
	if bubble.azTalk then return bubble.azTalk end
	local skin = {}
	skin.bg = bubble:CreateTexture(nil, "BACKGROUND", nil, 1)
	skin.bg:SetAllPoints(bubble)
	Atlas(skin.bg, FXA.talk)
	skin.name = bubble:CreateFontString(nil, "OVERLAY", Theme.F_CAPS)
	skin.name:SetPoint("TOPLEFT", bubble, "TOPLEFT", FXC.bubbleLeft, FXC.bubbleNameY)
	AzFont(skin.name, 10)
	skin.name:SetTextColor(FX_NAME[1], FX_NAME[2], FX_NAME[3], 1)
	if Theme.NoShadow then Theme.NoShadow(skin.name) end
	skin.name:SetJustifyH("LEFT")
	skin.name:SetWidth(FXC.bubbleW - FXC.bubbleLeft - FXC.bubbleRight)
	if skin.name.SetWordWrap then skin.name:SetWordWrap(false) end
	skin.text = bubble:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	skin.text:SetPoint("TOPLEFT", bubble, "TOPLEFT", FXC.bubbleLeft, FXC.bubbleTextY)
	skin.text:SetWidth(FXC.bubbleW - FXC.bubbleLeft - FXC.bubbleRight)
	skin.text:SetJustifyH("LEFT")
	if skin.text.SetWordWrap then skin.text:SetWordWrap(true) end
	skin.text:SetTextColor(INK[1], INK[2], INK[3], 1)
	if Theme.NoShadow then Theme.NoShadow(skin.text) end
	if HasFx("talkSheen") then
		skin.sheen = bubble:CreateTexture(nil, "ARTWORK", nil, 2)
		Atlas(skin.sheen, FXA.talkSheen)
		Additive(skin.sheen)
		skin.sheen:Hide()
	end
	skin.regions = { skin.bg, skin.name, skin.text }
	bubble.azTalk = skin
	return skin
end

local function SobreChrome(bubble, shown)
	local list = { bubble.bg, bubble.rule, bubble.tail, bubble.tailEdge, bubble.text }
	local border = bubble.border
	if type(border) == "table" then
		for _, side in ipairs({ "top", "bottom", "left", "right" }) do list[#list + 1] = border[side] end
	end
	for _, region in pairs(list) do
		if region and region.Show then if shown then region:Show() else region:Hide() end end
	end
end

local function PlaceTutoButtons(bubble, az)
	local x, y = Theme.BUBBLE_PAD or 10, Theme.BUBBLE_PAD or 10
	if az then x, y = FXC.bubbleLeft, 14 end
	if bubble.nextButton then
		bubble.nextButton:ClearAllPoints()
		bubble.nextButton:SetPoint("BOTTOMRIGHT", bubble, "BOTTOMRIGHT", -x, y)
	end
	if bubble.skipButton then
		bubble.skipButton:ClearAllPoints()
		bubble.skipButton:SetPoint("BOTTOMLEFT", bubble, "BOTTOMLEFT", x, y)
	end
end

-- Hauteur de la bulle Azeroth : nom, texte, marge, boutons du tutoriel
local function AzBubbleLayout(self, bubble)
	local skin = bubble.azTalk
	skin.name:SetText(ns.AzerothUpper(self.CompanionName and self:CompanionName() or ""))
	skin.text:SetText(bubble.text and bubble.text:GetText() or "")
	local textW = FXC.bubbleW - FXC.bubbleLeft - FXC.bubbleRight
	local h = Theme.TextHeight and Theme.TextHeight(skin.text, textW, Theme.F_BODY) or 14
	local height = math.max(FXC.bubbleMin, math.ceil(-FXC.bubbleTextY + h + FXC.bubbleBottom + (tonumber(bubble.azExtra) or 0)))
	bubble:SetWidth(FXC.bubbleW)
	bubble:SetHeight(height)
	return height
end

-- Habille la bulle selon le style du compagnon (et la rhabille si affichée)
function ns:CompanionBubbleApplyStyle()
	local bubble = self.companionBubble
	if not bubble then return nil end
	local frame = self.companionFrame
	local az = frame ~= nil and frame.uiStyle == "azeroth" and HasFx("talk")
	if az then
		local skin = BubbleSkin(bubble)
		bubble.sobreW = bubble.sobreW or bubble:GetWidth()
		SobreChrome(bubble, false)
		for _, region in ipairs(skin.regions) do region:Show() end
		PlaceTutoButtons(bubble, true)
		bubble.azBubble = true
		AzBubbleLayout(self, bubble)
	elseif bubble.azBubble then
		local skin = bubble.azTalk
		for _, region in ipairs(skin.regions) do region:Hide() end
		if skin.sheen then skin.sheen:Hide() end
		SobreChrome(bubble, true)
		PlaceTutoButtons(bubble, false)
		bubble.azBubble = nil
		if bubble.sobreW then bubble:SetWidth(bubble.sobreW) end
		bubble:SetText(bubble.text and bubble.text:GetText() or "", bubble.azExtra)
	end
	return az and "azeroth" or "sobre"
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
		if self.azBubble then
			height = AzBubbleLayout(ns, self)
			local skin = self.azTalk
			if skin.sheen then
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
			if not (frame and frame.uiStyle == "azeroth") then
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
	for index = 1, #SPARKS do
		local tex = layer:CreateTexture(nil, "OVERLAY", nil, 3)
		Atlas(tex, FXA.star)
		Additive(tex)
		Gold(tex)
		tex:Hide()
		list[index] = tex
	end
	frame.azSparks = list
	return list
end

function ns:AzerothShinyFX()
	local frame = AzCompanion(self)
	if not frame then return false end
	local state = FxState(self)
	local now = Clock()
	state.shinyUntil = now + FXC.shinyTime
	if HasFx("star") then
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
			local size = math.max(1, math.floor(FXC.sparkSize * scale + 0.5))
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
local function LevelParts(frame)
	if frame.azLevel then return frame.azLevel end
	local layer = FxLayer(frame)
	local parts = {}
	if HasFx("iconGlow") then
		parts.iglow = layer:CreateTexture(nil, "OVERLAY", nil, 1)
		parts.iglow:SetPoint("CENTER", frame, "TOP", 0, RING_Y)
		Atlas(parts.iglow, FXA.iconGlow)
		Additive(parts.iglow)
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
	end
	group.text = group:CreateFontString(nil, "OVERLAY", Theme.F_TITLE)
	group.text:SetPoint("CENTER", group, "CENTER", 0, 0)
	AzFont(group.text, FXC.levelFont)
	group.text:SetTextColor(FX_TEXT[1], FX_TEXT[2], FX_TEXT[3], 1)
	if group.text.SetShadowColor then group.text:SetShadowColor(0, 0, 0, 1) end
	if group.text.SetShadowOffset then group.text:SetShadowOffset(1, -1) end
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
	end
	if HasFx("line") then
		group.line = group:CreateTexture(nil, "OVERLAY")
		group.line:SetPoint("TOP", group, "BOTTOM", 0, 4)
		Atlas(group.line, FXA.line)
		Additive(group.line)
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

-- Lance l'effet ; `text` : « Aguerri ! », « Niveau 12 ! »
function ns:AzerothLevelFX(text, kind)
	local frame = AzCompanion(self)
	if not frame then return false end
	local parts = LevelParts(frame)
	local group = parts.group
	group.text:SetText(text or "")
	local textW = math.ceil(Measure(group.text))
	local width = textW + (group.left and 2 * (FXC.filigreeW + FXC.filigreeGap) or 0)
	group:SetSize(math.max(40, width), FXC.groupH)
	if group.cloud then group.cloud:SetSize(width + 40, FXC.groupH + 14) end
	if group.line then group.line.base = width + 40; group.line:SetSize(width + 40, 12) end
	group:ClearAllPoints()
	group:SetPoint("BOTTOM", frame, "TOP", 0, FXC.groupY)
	group:SetAlpha(0)
	group:Show()
	local state = FxState(self)
	state.level = { at = Clock(), kind = kind or "level", text = text }
	FxStart(self)
	return true
end

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
	if group.cloud then group.cloud:SetAlpha(0.55) end
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
function ns:AzerothRewardFX(frame, opts)
	if not (frame and frame.CreateTexture) or not self:AzerothOn() then return false end
	opts = opts or {}
	local wings, burst = HasFx("wings"), HasFx("burst")
	if not (wings or burst) then return false end
	local anchor = opts.anchor or frame.banner or frame
	local fx = frame.azReward
	if not fx then
		fx = {}
		if wings then
			fx.left = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
			Atlas(fx.left, FXA.wings)
			fx.right = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
			AtlasMirrored(fx.right, FXA.wings)
		end
		if burst then
			fx.burst = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
			Atlas(fx.burst, FXA.burst)
			Additive(fx.burst)
		end
		frame.azReward = fx
	end
	local h = tonumber(anchor:GetHeight()) or 90
	fx.h = h
	if fx.left then
		fx.left:ClearAllPoints(); fx.left:SetPoint("CENTER", anchor, "LEFT", 0, math.floor(h * 0.2))
		fx.right:ClearAllPoints(); fx.right:SetPoint("CENTER", anchor, "RIGHT", 0, math.floor(h * 0.2))
	end
	if fx.burst then fx.burst:ClearAllPoints(); fx.burst:SetPoint("CENTER", anchor, "CENTER", 0, 0) end
	fx.at = Clock()
	FxState(self).rewards[frame] = true
	FxStart(self)
	return true
end

local function RewardStop(frame)
	local fx = frame.azReward
	if not fx then return end
	for _, key in ipairs({ "left", "right", "burst" }) do if fx[key] then fx[key]:Hide() end end
	fx.at = nil
end

local function RewardStep(frame, now)
	local fx = frame.azReward
	if not (fx and fx.at) or not frame:IsShown() then RewardStop(frame); return false end
	local p = (now - fx.at) / FXC.rewardTime
	if p >= 1 then RewardStop(frame); return false end
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
			if frame and frame.azeroth and head and (head.kind == "rank" or head.big)
				and frame.text and frame.text:GetText() == head.name then
				self:AzerothRewardFX(frame)
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
	local skin = bubble and bubble.azTalk
	local sheen = skin and skin.sheen
	if not (state.sheenAt and sheen) then return false end
	local p = (now - state.sheenAt) / FXC.sheenTime
	if p >= 1 or not bubble.azBubble or not bubble:IsShown() then
		sheen:Hide(); state.sheenAt = nil
		return false
	end
	local w, h = bubble:GetWidth() or FXC.bubbleW, bubble:GetHeight() or FXC.bubbleMin
	sheen:SetSize(70, h)
	sheen:ClearAllPoints()
	sheen:SetPoint("CENTER", bubble, "LEFT", math.floor(w * p), 0)
	sheen:SetAlpha(0.6 * (p < 0.3 and p / 0.3 or 1 - (p - 0.3) / 0.7))
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
	if bubble and bubble.azTalk and bubble.azTalk.sheen then bubble.azTalk.sheen:Hide() end
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
				local ok, err = pcall(self.AzerothShinyFX, self)
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
					self:AzerothLevelFX(self:F("AZ_FX_EVOLVE", self:CompanionStageLabel()), "evolve")
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
				local ok, err = pcall(self.AzerothLevelFX, self, self:F("AZ_FX_LEVEL", n), "level")
				if not ok and self.RecordError then self:RecordError("azeroth:level", err) end
			end
			return a, b
		end
	end
	local apply = ns.CompanionApplyUIStyle
	function ns:CompanionApplyUIStyle(...)
		local style = apply(self, ...)
		local frame = self.companionFrame
		if frame and frame.uiStyle ~= "azeroth" then self:AzerothFxStop() end
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
					tooltip = function() if not ns:AzerothAtlasOK() then return L.OPT_UI_STYLE_MISSING end end,
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
	local missing = id == "azeroth" and not self:AzerothAtlasOK()
	self:Print(self:F(missing and "UI_STYLE_MSG_MISSING" or "UI_STYLE_MSG", L["UI_STYLE_" .. id]))
	return id
end

if ns.EXTRA_COMMANDS then
	ns.EXTRA_COMMANDS["style"] = function(self, rest) self:UIStyleCommand(rest) end
end
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_QUICK" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_STYLE")
		end
	end
end

if ns.Mark then ns.Mark("AzerothStyle") end
