-- Banners.lua -- couloir des bandeaux du haut de l'écran (3.0.1)
--
-- Quatre bandeaux s'ouvraient au même endroit (haut-centre), chacun avec sa
-- file et son horloge, et se dessinaient l'un sur l'autre :
--   * carnet  (Journal.lua)    : tampons, sceaux, titres, hauts faits « Haut
--                                fait obtenu » — TOP, y = -190 ;
--   * guilde  (GuildFeats.lua) : exploits des membres « GUILDE » — y = -150 ;
--   * résultat (AzerothStyle.lua) : « Capturé ! » — y = -200 ;
--   * capture (CaptureQueue.lua) : « Capture possible », boutons Ignorer /
--                                  Sourdine — y = -240.
-- Choix :
--   * carnet, guilde, résultat partagent UNE place : un seul à la fois, les
--     autres attendent dans l'ordre d'arrivée, chacun garde toute sa durée.
--     Le résultat d'une capture passe devant la file (il suit le lancer),
--     mais n'interrompt jamais un bandeau déjà affiché.
--   * le bandeau de capture n'attend pas : c'est une occasion qui file (le
--     monstre disparaît) et il porte des boutons. Il s'empile SOUS le bandeau
--     du couloir quand les deux sont là, sans le chevaucher.
--   * un bandeau qui couvrirait une fenêtre centrale (couloir des fenêtres
--     du socle : Place au butin, Tout capturer, carte de capture) passe
--     au-dessus d'elle, sinon dessous.
--   * jamais déplacé s'il a été placé par le joueur (position enregistrée).
-- Chaque système garde sa file et ses cadres (réutilisés) ; il demande son
-- tour (ns:BannerTurn) avant d'afficher et rend la place (ns:BannerDone).
local ADDON, ns = ...
if ns.blocked then return end

ns.BANNER_GAP = 8            -- px entre deux bandeaux empilés, ou avec une fenêtre
ns.BANNER_STALE = 2          -- s : un système qui ne redemande plus perd sa place en file
ns.BANNER_PRIORITY = { result = 1 }

local lane = { waiting = {}, serial = 0 }
ns.bannerLane = lane

local function Now() return (ns.Now and ns.Now()) or 0 end

local function Get(object, name, ...)
	if type(object) ~= "table" or type(object[name]) ~= "function" then return nil end
	local ok, a, b, c, d, e = pcall(object[name], object, ...)
	if ok then return a, b, c, d, e end
	return nil
end

local function Shown(frame)
	return type(frame) == "table" and Get(frame, "IsShown") and true or false
end

-- Le bandeau affiché a disparu sans rendre la place (Échap, changement de style)
local function Showing()
	if lane.showing and lane.frame and not Shown(lane.frame) then
		lane.showing, lane.frame = nil, nil
	end
	return lane.showing
end

local function Before(kindA, a, kindB, b)
	local pa, pb = ns.BANNER_PRIORITY[kindA] or 0, ns.BANNER_PRIORITY[kindB] or 0
	if pa ~= pb then return pa > pb end
	return a.serial < b.serial
end

-- `kind` a un bandeau à montrer : il prend son rang (une fois) et le garde
-- tant qu'il redemande
function ns:BannerWait(kind)
	local entry = lane.waiting[kind]
	if not entry then
		lane.serial = lane.serial + 1
		entry = { serial = lane.serial }
		lane.waiting[kind] = entry
	end
	entry.seen = Now()
	return entry
end

-- À `kind` de s'afficher ? Oui si la place est libre et qu'il est le premier
-- en file (priorité, puis ordre d'arrivée). Oui aussi s'il l'occupe déjà.
function ns:BannerTurn(kind)
	local showing = Showing()
	if showing == kind then lane.waiting[kind] = nil; return true end
	self:BannerWait(kind)
	if showing then return false end
	local now = Now()
	local bestKind, best
	for other, entry in pairs(lane.waiting) do
		if other ~= kind and now - (entry.seen or now) > ns.BANNER_STALE then
			lane.waiting[other] = nil
		elseif not best or Before(other, entry, bestKind, best) then
			bestKind, best = other, entry
		end
	end
	if bestKind ~= kind then return false end
	lane.waiting[kind] = nil
	lane.showing = kind
	return true
end

-- `kind` n'a plus rien à montrer (file vidée sans affichage)
function ns:BannerCancel(kind)
	lane.waiting[kind] = nil
end

-- Le bandeau de `kind` est à l'écran : place gardée, placé, la capture dessous
function ns:BannerShown(kind, frame, key, default)
	lane.showing, lane.frame = kind, frame
	lane.key, lane.default = key, default
	self:BannerPlace(frame, key, default, self:BannerObstacles(frame))
	self:BannerStackCapture()
end

-- Le bandeau de `kind` est parti : la place se libère
function ns:BannerDone(kind)
	if lane.showing == kind then lane.showing, lane.frame = nil, nil end
	lane.waiting[kind] = nil
	self:BannerStackCapture()
end

function ns:BannerShowing() return Showing(), lane.frame end

-- ---------------------------------------------------------------------------
-- Placement : à sa place habituelle ; s'il chevauche un obstacle, dessous
-- (ou au-dessus, s'il n'y a pas la place). Jamais un bandeau placé par le
-- joueur (db[key] enregistré par RestorePoint).
-- ---------------------------------------------------------------------------
local function Rect(frame)
	local popups = ns.Popups
	if type(popups) == "table" and type(popups.Rect) == "function" then return popups.Rect(frame) end
	return nil
end

local function Overlap(a, b)
	return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t
end

-- Fenêtres centrales ouvertes (couloir des fenêtres du socle)
function ns:BannerObstacles(frame)
	local list = {}
	local popups = ns.Popups
	if type(popups) ~= "table" or type(popups.frames) ~= "table" then return list end
	for other in pairs(popups.frames) do
		if other ~= frame and Shown(other) then list[#list + 1] = other end
	end
	return list
end

function ns:BannerUserPlaced(key)
	return key ~= nil and type(self:DB()[key]) == "table"
end

local function Scale(frame)
	local own = tonumber(Get(frame, "GetEffectiveScale")) or 1
	local root = tonumber(Get(rawget(_G, "UIParent"), "GetEffectiveScale")) or 1
	if own <= 0 or root <= 0 then return 1 end
	return own / root
end

local function Move(frame, left, top)
	local s = Scale(frame)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", rawget(_G, "UIParent"), "BOTTOMLEFT", left / s, top / s)
end

-- Renvoie "user", "home", "below", "above" ou nil (géométrie illisible)
function ns:BannerPlace(frame, key, default, obstacles)
	if type(frame) ~= "table" then return nil end
	if self:BannerUserPlaced(key) then return "user" end
	if type(default) == "table" then
		frame:ClearAllPoints()
		frame:SetPoint(default.point, rawget(_G, "UIParent"), default.point, default.x or 0, default.y or 0)
	end
	local me = Rect(frame)
	if not me then return nil end
	local rects = {}
	for _, other in ipairs(obstacles or {}) do
		local r = Rect(other)
		if r then rects[#rects + 1] = r end
	end
	local height = me.t - me.b
	local screenH = tonumber(Get(rawget(_G, "UIParent"), "GetHeight")) or 0
	local gap = ns.BANNER_GAP
	local function Free(top)
		local rect = { l = me.l, r = me.r, t = top, b = top - height }
		if rect.b < 0 or (screenH > 0 and rect.t > screenH) then return false end
		for _, r in ipairs(rects) do if Overlap(rect, r) then return false end end
		return true
	end
	if Free(me.t) then return "home" end
	-- sous l'obstacle le plus bas qu'il touche, sinon au-dessus du plus haut
	table.sort(rects, function(a, b) return a.t > b.t end)
	for _, r in ipairs(rects) do
		if Free(r.b - gap) then Move(frame, me.l, r.b - gap); return "below" end
	end
	for _, r in ipairs(rects) do
		if Free(r.t + gap + height) then Move(frame, me.l, r.t + gap + height); return "above" end
	end
	return "home"
end

-- Le bandeau de capture : sous le bandeau du couloir s'il est là (et sous
-- les fenêtres qu'il toucherait), sinon à sa place
local CAPTURE_DEFAULT = { point = "TOP", x = 0, y = -240 }
function ns:BannerStackCapture()
	local frame = self.captureToast
	if not Shown(frame) then return nil end
	local obstacles = self:BannerObstacles(frame)
	local banner = lane.showing and lane.frame
	if Shown(banner) then table.insert(obstacles, 1, banner) end
	return self:BannerPlace(frame, "captureToastPoint", CAPTURE_DEFAULT, obstacles)
end

if ns.Mark then ns.Mark("Banners") end
