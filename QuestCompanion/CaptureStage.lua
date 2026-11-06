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
--      créature se débat dessous, le halo de rareté pulse de plus en plus
--      vite, trois losanges s'allument ;
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
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.CAPTURE_THROW_TIME = 0.7       -- s de vol du paquet
ns.CAPTURE_STAGE_HOLD = 3.5       -- s de résultat à l'écran (un clic ferme avant)
ns.CAPTURE_DRAPE_TIME = 0.3       -- s pour que le filet se pose (rebond)
ns.CAPTURE_STAGE_CAM = 1.2        -- distance de caméra : la créature tient sous le filet
local STAGE_W, STAGE_H = 340, 386
local SCENE, MODEL = 196, 180     -- la scène, et le modèle dedans
local NET = 210                   -- le filet posé déborde un peu de la scène
local RIBBON_W, RIBBON_H = 300, 75
local TRAIL, DUST, PUFFS, BURST, ROPES, MOTES = 6, 6, 4, 18, 8, 12

-- Les textures de la scène (tools/gen_capture_assets.py)
local TEX = Theme.MEDIA .. "Textures\\"
local ART = {
	net = TEX .. "filet",            -- 512x256 : entier (gauche), déchiré (droite)
	bundle = TEX .. "paquet",        -- le filet roulé en boule
	rope = TEX .. "corde",           -- un bout de corde (déchirure)
	halo = TEX .. "halo",            -- halo doux (ADD, teinté)
	rays = TEX .. "rayons",          -- gerbe de rayons (ADD, teintée, tournée)
	sparks = TEX .. "particules",    -- point doux, étoile 4, étincelle 6, anneau
	stars = TEX .. "etoiles",        -- étoile du spécimen : pleine, vide
	ribbon = TEX .. "ruban",         -- panneau (haut), liseré (bas)
	stage = TEX .. "vignette",       -- fond de scène : projecteur, sol
	icon = TEX .. "filet_icone",     -- glyphe du bouton filet (CaptureQueue.lua)
}
ns.CAPTURE_ART = ART
-- découpes des feuilles de sprites (SetTexCoord : gauche, droite, haut, bas)
local COORDS = {
	netWhole = { 0, 0.5, 0, 1 }, netTorn = { 0.5, 1, 0, 1 },
	starFull = { 0, 0.5, 0, 1 }, starEmpty = { 0.5, 1, 0, 1 },
	ribbonPanel = { 0, 1, 0, 0.5 }, ribbonTrim = { 0, 1, 0.5, 1 },
	dot = { 0, 0.25, 0, 1 }, star4 = { 0.25, 0.5, 0, 1 }, spark = { 0.5, 0.75, 0, 1 }, ring = { 0.75, 1, 0, 1 },
}
ns.CAPTURE_COORDS = COORDS
local WHITE = { 1, 1, 1 }
local STAR_GREY = { 0.47, 0.50, 0.52 }
local DUST_COLOR = { 0.62, 0.57, 0.48 }
local PANEL_SHINY = { 0.47, 0.31, 0.09 }
local PANEL_FAIL, TRIM_FAIL = { 0.20, 0.23, 0.26 }, { 0.47, 0.35, 0.34 }
local BURST_KINDS = { "star4", "spark", "dot" }
local BURST_SIZES = { 14, 18, 10 }

-- Rareté : couleur et nombre de losanges
local RARITY = {
	trivial   = { color = { 0.62, 0.62, 0.62 }, pips = 1 },
	minus     = { color = { 0.62, 0.62, 0.62 }, pips = 1 },
	normal    = { color = { 0.95, 0.95, 0.95 }, pips = 1 },
	elite     = { color = { 0.00, 0.44, 0.87 }, pips = 2 },
	rare      = { color = { 0.64, 0.21, 0.93 }, pips = 3 },
	rareelite = { color = { 0.64, 0.21, 0.93 }, pips = 4 },
	worldboss = { color = { 1.00, 0.50, 0.00 }, pips = 5 },
}
ns.CAPTURE_RARITY = RARITY

local FR = {
	CAPTURE_STAGE_TITLE = "Capture",
	CAPTURE_STAGE_NEW   = "Nouvelle apparence pour ton compagnon",
	CAPTURE_STAGE_SHINY = "Brillante ! Nouvelle apparence pour ton compagnon",
	CAPTURE_STAGE_FAIL  = "Il reviendra. Toi aussi.",
	CAPTURE_STAGE_CLOSE = "Clic pour fermer",
	OPT_DAILY_CAPTURE_ANIM = "Capture animée",
}
local EN = {
	CAPTURE_STAGE_TITLE = "Capture",
	CAPTURE_STAGE_NEW   = "New look for your companion",
	CAPTURE_STAGE_SHINY = "Shiny! New look for your companion",
	CAPTURE_STAGE_FAIL  = "It'll be back. So will you.",
	CAPTURE_STAGE_CLOSE = "Click to close",
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
local function Coord(tex, c) tex:SetTexCoord(c[1], c[2], c[3], c[4]) end
local function Tint(tex, c, alpha) tex:SetVertexColor(c[1], c[2], c[3], alpha or 1) end
local function Rotate(tex, radians) if tex.SetRotation then pcall(tex.SetRotation, tex, radians) end end
-- opacité et visibilité d'un coup : à 0, la région est cachée
local function Fade(region, alpha)
	if alpha <= 0 then region:Hide(); return end
	region:SetAlpha(math.min(1, alpha))
	region:Show()
end
-- une texture d'art de la scène : fichier, calque, découpe, taille, fusion
local function Art(parent, layer, sub, file, coords, w, h, blend)
	local tex = parent:CreateTexture(nil, layer, nil, sub)
	tex:SetTexture(file)
	if coords then Coord(tex, coords) end
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
		return { color = Theme.GOLD_LIGHT or { 0.96, 0.78, 0.49 }, pips = (RARITY[target.class] or RARITY.normal).pips }
	end
	return RARITY[(target and target.class) or "normal"] or RARITY.normal
end

local function PlayKit(name)
	local kit, play = G("SOUNDKIT"), G("PlaySound")
	if type(kit) == "table" and kit[name] and type(play) == "function" then pcall(play, kit[name]) end
end

-- ---------------------------------------------------------------------------
-- Construction : tout est créé une fois, caché, puis posé image par image
-- ---------------------------------------------------------------------------
function ns:EnsureCaptureStage()
	if self.captureStage then return self.captureStage end
	local frame = Theme.CreateToast(UIParent, STAGE_W, STAGE_H, { strata = "DIALOG" })
	if not frame then return nil end
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	frame:EnableMouse(true)
	-- un clic, une fois le verdict tombé : on ferme
	frame:SetScript("OnMouseUp", function()
		local rolling = ns.captureState and ns.captureState.rolling
		if rolling and rolling.result then rolling.closeAt = Clock() end
	end)
	local level = frame:GetFrameLevel() or 1

	-- filet haut à la couleur de la rareté, titre, l'aide choisie en badge
	frame.topBar = Theme.Solid(frame, "BORDER", WHITE, 1)
	frame.topBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	frame.topBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
	frame.topBar:SetHeight(3)
	frame.title = Theme.Text(frame, Theme.F_CAPS or Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.title:SetPoint("TOP", frame, "TOP", 0, -12)
	frame.title:SetText(Theme.Upper and Theme.Upper(L.CAPTURE_STAGE_TITLE) or L.CAPTURE_STAGE_TITLE)
	frame.aidIcon = frame:CreateTexture(nil, "OVERLAY")
	frame.aidIcon:SetSize(14, 14)
	frame.aidIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	frame.aidIcon:SetPoint("LEFT", frame.title, "RIGHT", 12, 0)
	frame.aidText = Theme.Text(frame, Theme.F_CAPS or Theme.F_SMALL, Theme.GOLD)
	frame.aidText:SetPoint("LEFT", frame.aidIcon, "RIGHT", 4, 0)

	-- la scène : un carré centré où vit le modèle. Derrière lui, sur le cadre
	-- lui-même (un cadre enfant passe toujours devant les textures de son
	-- parent) : le fond de scène, les rayons et le halo
	frame.scene = CreateFrame("Frame", nil, frame)
	frame.scene:SetSize(SCENE, SCENE)
	frame.scene:SetPoint("TOP", frame, "TOP", 0, -34)
	-- la créature qui s'enfuit ne sort pas de la scène
	Method(frame.scene, "SetClipsChildren", true)
	frame.stageBg = Art(frame, "BACKGROUND", 2, ART.stage, nil, SCENE)
	frame.stageBg:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)
	frame.stageBg:Show()
	frame.rays = Art(frame, "ARTWORK", 0, ART.rays, nil, 300, 300, "ADD")
	frame.rays2 = Art(frame, "ARTWORK", 1, ART.rays, nil, 240, 240, "ADD")
	frame.halo = Art(frame, "ARTWORK", 2, ART.halo, nil, 220, 220, "ADD")
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

	-- les effets, en trois calques au-dessus du modèle (cadres enfants :
	-- ils passent devant le 3D) : la poussière, le filet et son ombre (un
	-- cadre à eux : il grossit avec SetScale), puis ce qui vole au-dessus
	frame.fx = CreateFrame("Frame", nil, frame)
	frame.fx:SetAllPoints(frame.scene)
	frame.fx:SetFrameLevel(level + 10)
	frame.dust = Art(frame.fx, "ARTWORK", 0, ART.sparks, COORDS.ring, 60, 20, "ADD")
	frame.dusts = {}
	for index = 1, DUST do
		local p = Art(frame.fx, "ARTWORK", 1, ART.sparks, COORDS.dot, 10, 10, "ADD")
		p.angle = (index / DUST) * math.pi * 2 + 0.4
		p.reach = 60 + (index % 3) * 8
		frame.dusts[index] = p
	end
	frame.puffs = {}
	for index = 1, PUFFS do
		frame.puffs[index] = Art(frame.fx, "ARTWORK", 1, ART.sparks, COORDS.ring, 24, 24, "ADD")
	end
	frame.netFrame = CreateFrame("Frame", nil, frame.fx)
	frame.netFrame:SetSize(NET, NET)
	frame.netFrame:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)
	frame.netFrame:SetFrameLevel(level + 11)
	frame.netShadow = Art(frame.netFrame, "ARTWORK", 0, ART.net, COORDS.netWhole, NET)
	frame.netShadow:SetVertexColor(0, 0, 0, 0.45)
	frame.net = Art(frame.netFrame, "ARTWORK", 1, ART.net, COORDS.netWhole, NET)
	frame.net:SetPoint("CENTER", frame.netFrame, "CENTER", 0, 0)
	frame.fxTop = CreateFrame("Frame", nil, frame)
	frame.fxTop:SetAllPoints(frame.scene)
	frame.fxTop:SetFrameLevel(level + 12)
	frame.bundle = Art(frame.fxTop, "ARTWORK", 3, ART.bundle, nil, 52)
	frame.trail = {}
	for index = 1, TRAIL do
		local p = Art(frame.fxTop, "ARTWORK", 2, ART.sparks, COORDS.dot, 22 - 2 * index, 22 - 2 * index, "ADD")
		p.lag = 0.06 * index
		p.fade = 0.55 * (1 - index / TRAIL)
		frame.trail[index] = p
	end
	frame.ropes = {}
	for index = 1, ROPES do
		local p = Art(frame.fxTop, "ARTWORK", 2, ART.rope, nil, 36 + (index * 11) % 25, 7)
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
		local p = Art(frame.fxTop, "ARTWORK", 4, ART.sparks, COORDS[kind], size, size, "ADD")
		p.angle = (index / BURST) * math.pi * 2 + (index % 2) * 0.2
		p.reach = 95 + (index % 3) * 20
		p.spin = ((index * 7) % 5 - 2) * 1.5
		frame.burst[index] = p
	end
	frame.motes = {}
	for index = 1, MOTES do
		local size = 8 + (index % 3) * 3
		local p = Art(frame.fxTop, "ARTWORK", 1, ART.sparks, COORDS.dot, size, size, "ADD")
		p.x = ((index * 53) % 21 - 10) * 10
		p.phase = index * 0.7
		p.speed = 14 + (index % 4) * 5
		frame.motes[index] = p
	end
	frame.flash = Art(frame.fxTop, "ARTWORK", 5, ART.halo, nil, 320, 320, "ADD")
	frame.flash:SetPoint("CENTER", frame.scene, "CENTER", 0, 0)

	-- le ruban (cadre à part : il surgit avec SetScale), son liseré, son texte,
	-- et le reflet d'une brillante (dans un cadre qui rogne ses enfants)
	frame.banner = CreateFrame("Frame", nil, frame)
	frame.banner:SetSize(RIBBON_W, RIBBON_H)
	frame.banner:SetPoint("CENTER", frame.scene, "BOTTOM", 0, -34)
	frame.banner:SetFrameLevel(level + 13)
	frame.ribbonPanel = Art(frame.banner, "ARTWORK", 0, ART.ribbon, COORDS.ribbonPanel)
	frame.ribbonPanel:SetAllPoints(frame.banner)
	frame.ribbonPanel:Show()
	frame.ribbonTrim = Art(frame.banner, "ARTWORK", 1, ART.ribbon, COORDS.ribbonTrim)
	frame.ribbonTrim:SetAllPoints(frame.banner)
	frame.ribbonTrim:Show()
	frame.sheenClip = CreateFrame("Frame", nil, frame.banner)
	frame.sheenClip:SetSize(RIBBON_W * 0.6, 38)
	frame.sheenClip:SetPoint("CENTER", frame.banner, "CENTER", 0, 0)
	frame.sheenClip.clips = Method(frame.sheenClip, "SetClipsChildren", true) == true
	frame.sheen = Art(frame.sheenClip, "ARTWORK", 0, ART.halo, nil, 60, 90, "ADD")
	frame.sheen:SetVertexColor(1, 1, 1, 0.35)
	frame.bannerText = Theme.Text(frame.banner, Theme.F_DISPLAY or Theme.F_TITLE, Theme.PARCHMENT)
	frame.bannerText:SetPoint("CENTER", frame.banner, "CENTER", 0, 2)
	frame.banner:Hide()

	-- sous le ruban : nom, losanges de rareté, étoiles du spécimen ; en bas,
	-- les losanges des secousses et le pied
	frame.name = Theme.Text(frame, Theme.F_HEADING or Theme.F_BODY, Theme.PARCHMENT)
	frame.name:SetPoint("TOP", frame.banner, "BOTTOM", 0, -4)
	frame.name:SetWidth(STAGE_W - 24)
	frame.name:SetJustifyH("CENTER")
	frame.pips = {}
	for index = 1, 5 do
		frame.pips[index] = Theme.CreateDiamond and Theme.CreateDiamond(frame, 9) or frame:CreateTexture(nil, "OVERLAY")
	end
	frame.starSlots = {}
	for index = 1, 3 do
		local star = Art(frame, "OVERLAY", 1, ART.stars, COORDS.starEmpty, 18)
		star:SetPoint("TOP", frame.name, "BOTTOM", (index - 2) * 20, -18)
		frame.starSlots[index] = star
	end
	frame.starSpark = Art(frame, "OVERLAY", 2, ART.sparks, COORDS.spark, 22, 22, "ADD")
	frame.shakeDots = {}
	for index = 1, 3 do
		local dot = Theme.CreateDiamond and Theme.CreateDiamond(frame, 10) or frame:CreateTexture(nil, "OVERLAY")
		dot:SetPoint("BOTTOM", frame, "BOTTOM", (index - 2) * 14, 30)
		dot:Hide()
		frame.shakeDots[index] = dot
	end
	frame.footer = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.footer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 11)
	frame.footer:SetWidth(STAGE_W - 24)
	frame.footer:SetJustifyH("CENTER")

	frame:SetScript("OnUpdate", function()
		local done, err = pcall(ns.CaptureStageUpdate, ns, Clock())
		if not done and ns.RecordError then ns:RecordError("capture:stage", err) end
	end)
	frame:Hide()
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
	frame.sheen:Hide()
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

function ns:CaptureShowStage(rolling)
	local frame = self:EnsureCaptureStage()
	if not (frame and rolling) then return nil end
	local target = rolling.target
	local rarity = self:CaptureRarity(target)
	frame.rolling = rolling
	frame.rarity = rarity
	frame.shiny = target.shiny and true or false
	local c = rarity.color
	frame.topBar:SetVertexColor(c[1], c[2], c[3], 1)
	local shown = false
	if frame.model then
		frame.model:Show()
		shown = Method(frame.model, "SetCreature", target.npcID)
		Method(frame.model, "SetCamDistanceScale", ns.CAPTURE_STAGE_CAM)
		-- une brillante : sous sa lumière dorée (1.6.0)
		if ns.ModelShinyLight then ns.ModelShinyLight(frame.model, target.shiny) end
		if not shown then frame.model:Hide() end
	end
	Creature(frame, 0, 0, 1, 0)
	if shown then frame.fallback:Hide() else frame.fallback:Show() end
	frame.hasModel = shown
	-- l'aide choisie : son icône en badge près du titre
	local aid
	for _, def in ipairs(ns.CAPTURE_AIDS or {}) do if def.id == rolling.aid then aid = def end end
	if aid then
		frame.aidIcon:SetTexture(aid.icon)
		frame.aidText:SetText("· " .. tostring(self:CaptureAidLabel(aid.id)))
		frame.aidIcon:Show()
		frame.aidText:Show()
	else
		frame.aidIcon:Hide()
		frame.aidText:Hide()
	end
	Rest(frame)
	Tint(frame.halo, c, 0)
	frame.bannerText:SetText("")
	frame.name:SetText(target.shiny and self:F("CAPTURE_SHINY_TAG", target.name) or target.name)
	frame.name:SetTextColor(c[1], c[2], c[3])
	-- losanges de rareté, centrés sous le nom
	local gap = 13
	for index, pip in ipairs(frame.pips) do
		pip:ClearAllPoints()
		if index <= rarity.pips then
			pip:SetPoint("TOP", frame.name, "BOTTOM", (index - (rarity.pips + 1) / 2) * gap, -6)
			pip:SetVertexColor(c[1], c[2], c[3], 1)
			pip:Show()
		else
			pip:Hide()
		end
	end
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
	Tint(frame.halo, c, 0.2 + 0.08 * math.abs(math.sin(p * 6)))
	frame.halo:SetSize(200, 200)
	frame.halo:Show()
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
	frame.netShadow:SetVertexColor(0, 0, 0, 0.25 + 0.2 * drape)
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
	-- le halo pulse, de plus en plus vite
	Tint(frame.halo, c, 0.3 + 0.15 * math.abs(math.sin(t * (3 + rolling.done * 2))))
	frame.halo:SetSize(220, 220)
	frame.halo:Show()
	-- les secousses : un losange allumé par secousse commencée
	local lit = math.min(rolling.done + 1, 3)
	for index, dot in ipairs(frame.shakeDots) do
		local col = index <= lit and Theme.GOLD or Theme.EDGE
		dot:SetVertexColor(col[1], col[2], col[3], 1)
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

-- 4. Capturé : éclair, gerbe de rayons et d'étincelles, le filet se referme
-- sur elle, elle tourne sur elle-même, le ruban, puis les étoiles une à une
local function StageOk(frame, r, rolling, c)
	local shiny = frame.shiny
	local col = shiny and Theme.GOLD_LIGHT or c
	if not frame.played then frame.played = true; PlayKit("UI_EPICLOOT_TOAST") end
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
	frame.netShadow:SetVertexColor(0, 0, 0, 0.45)
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
	Banner(frame, r, shiny and PANEL_SHINY or { c[1] * 0.42, c[2] * 0.42, c[3] * 0.42 }, col, L.CAPTURE_GOT, Theme.PARCHMENT)
	-- le reflet balaie le ruban (si le client sait rogner ses enfants)
	if shiny and frame.sheenClip.clips then
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
			Coord(star, full and COORDS.starFull or COORDS.starEmpty)
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
local function StageFail(frame, r, c)
	if not frame.played then frame.played = true; PlayKit("IG_QUEST_LOG_ABANDON_QUEST") end
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
	frame.sheen:Hide()
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
	Banner(frame, r, PANEL_FAIL, TRIM_FAIL, L.CAPTURE_FLED, Theme.RED)
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
		if t < throw then
			StageThrow(frame, Clamp01(t / throw), c)
			return "throw"
		end
		StageShake(frame, t - throw, t, rolling, c)
		return "shake"
	end
	local r = now - (rolling.resultAt or now)
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
	StageFail(frame, r, c)
	return "fail"
end

if ns.Mark then ns.Mark("CaptureStage") end
