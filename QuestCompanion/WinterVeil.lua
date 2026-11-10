-- WinterVeil.lua -- thème du Voile d'hiver (QuestCompanion 2.14.0) : décor, saison, boule de neige
--
-- Pas un nouveau style : le style Azeroth, plus un décor de saison posé
-- par-dessus (maquettes validées le 10/11/2026) :
--   * le carnet : une guirlande lumineuse sous la plaque d'en-tête, trois
--     flocons discrets sur le parchemin (sous les textes), un cadeau et le
--     renne des hauts faits de part et d'autre du titre « Carnet de voyage » ;
--   * le cadre du compagnon : une guirlande en 3D (modèle du client, sans
--     fond) le long du haut de l'anneau, deux petits flocons ;
--   * la capture : le filet devient une boule de neige (icône du bouton,
--     bandeaux), et la scène lance une boule de neige qui éclate en flocons
--     sur la créature au lieu du filet. La logique de capture ne change pas.
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
}
-- le carnet : hauteur de la guirlande (sous le métal de la plaque), icônes
-- du titre, flocons (ancre, décalage, côté, opacité), sur la page ou la colonne
ns.WINTER_VEIL_JOURNAL = {
	lightsH = 14, iconSize = 18, iconGap = 6,
	flakes = {
		{ on = "content", point = "TOPRIGHT", x = -34, y = -16, size = 30, alpha = 0.42 },
		{ on = "content", point = "TOPRIGHT", x = -76, y = -34, size = 16, alpha = 0.36 },
		{ on = "nav", point = "TOPRIGHT", x = -10, y = -15, size = 14, alpha = 0.38 },
	},
}
-- le cadre du compagnon : la guirlande 3D (bande au ras du haut de l'anneau ;
-- caméra à régler en jeu : cam, position, cap) et ses deux flocons
ns.WINTER_VEIL_COMPANION = {
	model = 199600, w = 118, h = 34, y = 6,
	cam = 1, pos = { 0, 0, 0 }, facing = 0,
	flakes = {
		{ x = -44, y = -6, size = 14, alpha = 0.75 },
		{ x = 46, y = -26, size = 11, alpha = 0.65 },
	},
}
-- la scène de capture : la boule de neige (taille, tours en vol), son
-- éclatement en flocons (nombre, durée, portée, taille)
ns.WINTER_VEIL_SNOWBALL = { size = 34, spin = 3, flakes = 10, burst = 0.6, reach = 70, flakeSize = 15 }

local FR = {
	OPT_WINTER_VEIL         = "Décor du Voile d'hiver",
	OPT_WINTER_VEIL_DESC    = "Guirlandes et flocons sur le carnet et le cadre du compagnon, boule de neige à la place du filet. Avec le style Azeroth seulement.",
	OPT_WINTER_VEIL_SOBRE   = "Le décor ne se voit qu'avec le style Azeroth.",
	WINTER_VEIL_auto        = "Automatique",
	WINTER_VEIL_auto_HINT   = "du 15 décembre au 2 janvier",
	WINTER_VEIL_on          = "Toujours",
	WINTER_VEIL_off         = "Jamais",
	WINTER_VEIL_USAGE       = "/qc noel auto|on|off (actuel : %s)",
	WINTER_VEIL_MSG         = "Décor du Voile d'hiver : %s.",
	WINTER_VEIL_MSG_SOBRE   = "Décor du Voile d'hiver : %s. Il ne se voit qu'avec le style Azeroth (/qc style azeroth).",
	HELP_NOEL               = "/qc noel auto|on|off — décor du Voile d'hiver (guirlandes, flocons, boule de neige)",
}
local EN = {
	OPT_WINTER_VEIL         = "Winter Veil decorations",
	OPT_WINTER_VEIL_DESC    = "Lights and snowflakes on the journal and the companion frame, a snowball instead of the net. Azeroth style only.",
	OPT_WINTER_VEIL_SOBRE   = "The decorations only show with the Azeroth style.",
	WINTER_VEIL_auto        = "Automatic",
	WINTER_VEIL_auto_HINT   = "December 15 to January 2",
	WINTER_VEIL_on          = "Always",
	WINTER_VEIL_off         = "Never",
	WINTER_VEIL_USAGE       = "/qc noel auto|on|off (current: %s)",
	WINTER_VEIL_MSG         = "Winter Veil decorations: %s.",
	WINTER_VEIL_MSG_SOBRE   = "Winter Veil decorations: %s. They only show with the Azeroth style (/qc style azeroth).",
	HELP_NOEL               = "/qc noel auto|on|off — Winter Veil decorations (lights, snowflakes, snowball)",
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
	local lay, J, A = ns.CARNET_LAYOUT, ns.WINTER_VEIL_JOURNAL, ns.WINTER_VEIL_ART
	local over = frame.azOver
	local d = CreateFrame("Frame", nil, over)
	d:SetAllPoints(frame)
	d:SetFrameLevel((over:GetFrameLevel() or 1) + 2)
	d:EnableMouse(false)
	-- la guirlande : des tuiles de 104×36 ramenées à la hauteur de la bande,
	-- la dernière recoupée, d'un bord du bois à l'autre, sous le métal
	local width = (tonumber(frame:GetWidth()) or 0) - 2 * lay.wood
	local h = J.lightsH
	local tileW = math.floor(A.lights.w * h / A.lights.h + 0.5)
	d.lights = {}
	local x = 0
	while x < width do
		local w = math.min(tileW, width - x)
		local tex = NewFile(d, "ARTWORK", 3, A.lights)
		if not tex then break end
		tex:SetSize(w, h)
		tex:SetPoint("TOPLEFT", frame, "TOPLEFT", lay.wood + x, -lay.band)
		local c = A.lights.c
		tex:SetTexCoord(c[1], c[1] + (c[2] - c[1]) * w / tileW, c[3], c[4])
		d.lights[#d.lights + 1] = tex
		x = x + w
	end
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
		end
		return false
	end
	d = d or BuildJournalDecor(frame)
	d:Show()
	for _, tex in ipairs(d.flakes) do tex:Show() end
	PlaceTitleIcons(frame, d)
	return true
end

-- ---------------------------------------------------------------------------
-- Le cadre du compagnon : guirlande 3D au ras du haut de l'anneau, flocons
-- ---------------------------------------------------------------------------
local function LightsFraming(m)
	local C = ns.WINTER_VEIL_COMPANION
	Method(m, "SetCamDistanceScale", C.cam)
	Method(m, "SetPosition", C.pos[1], C.pos[2], C.pos[3])
	Method(m, "SetFacing", C.facing)
end

local function BuildCompanionDecor(frame, skin)
	local C, A = ns.WINTER_VEIL_COMPANION, ns.WINTER_VEIL_ART
	local ringX = (ns.AZEROTH_RING and ns.AZEROTH_RING.x) or 0
	local d = CreateFrame("Frame", nil, skin)
	d:SetAllPoints(frame)
	d:SetFrameLevel((skin:GetFrameLevel() or 1) + 2)
	d:EnableMouse(false)
	-- la guirlande : un modèle du client, sans fond, sans souris, par-dessus l'anneau
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, d)
	if ok and model then
		model:SetSize(C.w, C.h)
		model:SetPoint("CENTER", frame, "TOP", ringX, C.y)
		model:SetFrameLevel((d:GetFrameLevel() or 1) + 1)
		model:EnableMouse(false)
		Method(model, "SetKeepModelOnHide", true)
		model.framing = LightsFraming
		if ns.ModelKeepFraming then ns.ModelKeepFraming(model) end
		d.lights = model
	end
	d.flakes = {}
	for index, spec in ipairs(C.flakes) do
		local tex = NewFile(d, "OVERLAY", 2, A.flake)
		if tex then
			tex:SetSize(spec.size, spec.size)
			tex:SetPoint("CENTER", frame, "TOP", ringX + spec.x, spec.y)
			tex:SetAlpha(spec.alpha)
			d.flakes[index] = tex
		end
	end
	frame.wvDecor = d
	return d
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
			if d.lights then d.lights:Hide() end
		end
		return false
	end
	d = d or BuildCompanionDecor(frame, skin)
	d:Show()
	local model = d.lights
	if model then
		if not model.wvModel then
			if Method(model, "SetModel", ns.WINTER_VEIL_COMPANION.model) then model.wvModel = ns.WINTER_VEIL_COMPANION.model end
		end
		model:Show()
		LightsFraming(model)
	end
	return true
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

local function StageSnow(frame)
	if frame.wvBall then return frame end
	local S, A = ns.WINTER_VEIL_SNOWBALL, ns.WINTER_VEIL_ART
	local host = frame.fxTop or frame
	frame.wvBall = host:CreateTexture(nil, "ARTWORK", nil, 5)
	SetFile(frame.wvBall, A.snowball)
	frame.wvBall:SetSize(S.size, S.size)
	frame.wvBall:Hide()
	frame.wvFlakes = {}
	for index = 1, S.flakes do
		local tex = host:CreateTexture(nil, "ARTWORK", nil, 6)
		SetFile(tex, A.flake)
		local size = S.flakeSize - (index % 3) * 3
		tex:SetSize(size, size)
		tex.angle = (index / S.flakes) * math.pi * 2 + (index % 2) * 0.3
		tex.reach = S.reach * (0.7 + 0.15 * (index % 3))
		tex.spin = ((index * 5) % 7 - 3) * 0.8
		tex:Hide()
		frame.wvFlakes[index] = tex
	end
	return frame
end

local function Put(region, anchor, x, y)
	region:ClearAllPoints()
	region:SetPoint("CENTER", anchor, "CENTER", x, y)
end

-- Une image de la scène : par-dessus celle de CaptureStage.lua (rien de sa
-- logique ne change). Le paquet, le filet, son ombre et ses cordes cachés ;
-- la boule de neige suit l'arc du paquet, éclate à l'arrivée en flocons qui
-- s'écartent en tournant et s'effacent.
function ns:WinterVeilStage(frame, now)
	frame = frame or self.captureStage
	if not frame then return nil end
	local rolling = frame.rolling
	if not (rolling and self:WinterVeilActive()) then
		if frame.wvBall then
			frame.wvBall:Hide()
			for _, tex in ipairs(frame.wvFlakes) do tex:Hide() end
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
	if t < throw then
		local p = Clamp01(t / throw)
		local x, y = Arc(p)
		Put(frame.wvBall, scene, x, y)
		Method(frame.wvBall, "SetRotation", p * math.pi * S.spin)
		frame.wvBall:SetAlpha(1)
		frame.wvBall:Show()
		for _, spark in ipairs(frame.trail or {}) do
			if spark:IsShown() then spark:SetVertexColor(1, 1, 1, 1) end
		end
	else
		frame.wvBall:Hide()
	end
	local q = (t - throw) / S.burst
	for _, tex in ipairs(frame.wvFlakes) do
		if q >= 0 and q < 1 then
			local r = tex.reach * EaseOut(q)
			Put(tex, scene, math.cos(tex.angle) * r, math.sin(tex.angle) * r + 10)
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
-- Tout appliquer (réglage, commande, style, saison)
-- ---------------------------------------------------------------------------
function ns:WinterVeilApply()
	local active = self:WinterVeilActive() and true or false
	self.winterVeilShown = active
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
		end
	end
end

function ns:WinterVeilCommand(rest)
	local word = (tostring(rest or ""):match("^%s*(%S*)") or ""):lower()
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
