-- AggroLink.lua -- « +N » : les voisins qui risquent de suivre ta cible (1.37.1)
--
-- Hors combat, ta cible hostile : combien de monstres de la même sorte sont
-- assez près d'elle pour venir l'aider si tu l'attaques. Une ESTIMATION :
-- le client ne donne pas la position des monstres. On la reconstruit :
--   * distance joueur -> monstre : la fourchette de la portée d'aggro
--     (AggroDistance, objets et sorts de portée), prise en son milieu ;
--   * direction : la place de la barre de nom à l'écran, convertie en angle
--     avec le champ de vision de la caméra (CVar cameraFov, sinon 90°) ;
--   * puis la distance entre les deux points (loi des cosinus).
-- « Même sorte » : même type de créature, et même famille pour les bêtes
-- (un loup n'aide pas un sanglier) ; vivant, hors combat, hostile ou du même
-- nom que la cible. Rayon d'entraide : AGGRO_LINK_RADIUS (à régler en jeu).
-- Affichage : « +N » à droite de la barre de nom de la cible, ambre (rouge à
-- partir de AGGRO_LINK_RED). Réglage « Voisins qui suivent (+N) », page
-- Portée d'aggro (actif).
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

ns.AGGRO_LINK_RADIUS = 12     -- m : voisin qui vient aider (estimation à régler en jeu)
ns.AGGRO_LINK_RED = 3         -- à partir de ce nombre, le « +N » passe au rouge
ns.AGGRO_LINK_POLL = 0.5      -- s
ns.AGGRO_LINK_FOV = 90        -- degrés, si le client ne dit rien

ns.RegisterStrings({
	OPT_AGGRO_LINK = "Voisins qui suivent (+N)",
	MSG_DIAG_AGGRO_LINK = "  voisins (+N) : %s sur la cible (rayon %d m, champ %d°)",
}, {
	OPT_AGGRO_LINK = "Neighbours that follow (+N)",
	MSG_DIAG_AGGRO_LINK = "  neighbours (+N): %s on the target (radius %d yd, field %d°)",
})
ns.RegisterDefaults({ aggroLink = true })
for _, page in ipairs(ns.OPTION_PAGES or {}) do
	if page.id == "aggro" and type(page.rows) == "table" then
		local present
		for _, row in ipairs(page.rows) do if row.key == "aggroLink" then present = true end end
		if not present then table.insert(page.rows, { key = "aggroLink", label = "OPT_AGGRO_LINK", kind = "bool" }) end
	end
end

local function Plain(value) return ns.Plain and ns.Plain(value) or value end
local function Call(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if not ok then return nil end
	return Plain(a)
end

-- ---------------------------------------------------------------------------
-- Géométrie (fonctions pures, testées)
-- ---------------------------------------------------------------------------
-- Champ de vision horizontal de la caméra, en radians
function ns.AggroLinkFov()
	local fov = tonumber(Call("GetCVar", "cameraFov"))
	if not fov or fov < 30 or fov > 150 then fov = ns.AGGRO_LINK_FOV end
	return math.rad(fov)
end

-- Angle d'une barre de nom (x à l'écran) par rapport au centre
function ns.AggroLinkAngle(x, width, fov)
	if not (x and width and width > 0) then return nil end
	local focal = (width / 2) / math.tan((fov or math.rad(ns.AGGRO_LINK_FOV)) / 2)
	return math.atan((x - width / 2) / focal)
end

-- Distance entre deux monstres vus à r1 / r2 m, sous les angles a1 / a2
function ns.AggroLinkGap(r1, a1, r2, a2)
	if not (r1 and r2 and a1 and a2) then return nil end
	local d2 = r1 * r1 + r2 * r2 - 2 * r1 * r2 * math.cos(a1 - a2)
	return math.sqrt(math.max(0, d2))
end

-- Distance joueur -> unité : milieu de la fourchette (nil au-delà du dernier palier)
function ns:AggroLinkRange(unit)
	if not self.AggroDistance then return nil end
	local low, high = self:AggroDistance(unit)
	if not (low and high) then return nil end
	return (low + high) / 2
end

-- ---------------------------------------------------------------------------
-- Les voisins de la cible
-- ---------------------------------------------------------------------------
local function Sort(unit)
	return Call("UnitCreatureType", unit), Call("UnitCreatureFamily", unit), Call("UnitName", unit)
end

local function PlateX(plate)
	if type(plate) ~= "table" or type(plate.GetCenter) ~= "function" then return nil end
	local ok, x = pcall(plate.GetCenter, plate)
	return ok and tonumber(Plain(x)) or nil
end

-- Le nombre de voisins de `target` (0 si rien à dire), et la barre de la cible
function ns:AggroLinkCount(target)
	target = target or "target"
	if not (self.AggroUnitKind and self:AggroUnitKind(target)) then return 0 end
	if Call("UnitAffectingCombat", target) then return 0 end
	local plates = self.aggroPlates or {}
	local targetPlate
	for unit, plate in pairs(plates) do
		if Call("UnitIsUnit", unit, target) then targetPlate = plate end
	end
	if not targetPlate then return 0 end
	local width = UIParent and UIParent.GetWidth and tonumber(UIParent:GetWidth()) or nil
	local fov = ns.AggroLinkFov()
	local r0 = self:AggroLinkRange(target)
	local a0 = ns.AggroLinkAngle(PlateX(targetPlate), width, fov)
	if not (r0 and a0) then return 0, targetPlate end
	local ctype, family, name = Sort(target)
	local count = 0
	for unit, plate in pairs(plates) do
		if plate ~= targetPlate and not Call("UnitIsUnit", unit, target) then
			local kind = self:AggroUnitKind(unit)
			local utype, ufamily, uname = Sort(unit)
			local same = kind ~= nil and utype == ctype and (ctype ~= nil or uname == name)
				and (family == nil or ufamily == family)
				and (kind == "hostile" or uname == name)
			if same and not Call("UnitAffectingCombat", unit) then
				local gap = ns.AggroLinkGap(r0, a0, self:AggroLinkRange(unit), ns.AggroLinkAngle(PlateX(plate), width, fov))
				if gap and gap <= ns.AGGRO_LINK_RADIUS then count = count + 1 end
			end
		end
	end
	return count, targetPlate
end

-- ---------------------------------------------------------------------------
-- Le « +N » à droite de la barre de nom de la cible
-- ---------------------------------------------------------------------------
local function Badge(self)
	if self.aggroLinkBadge then return self.aggroLinkBadge end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
	if not ok or not frame then return nil end
	frame:SetSize(1, 1)
	frame.text = Theme.Text(frame, Theme.F_LABEL or Theme.F_BODY, Theme.GOLD)
	frame.text:SetPoint("LEFT", frame, "LEFT", 0, 0)
	if Theme.TextShadow then Theme.TextShadow(frame.text) end
	frame:Hide()
	self.aggroLinkBadge = frame
	return frame
end

function ns:AggroLinkHide()
	if self.aggroLinkBadge then self.aggroLinkBadge:Hide() end
	self.aggroLinkShown = nil
end

-- Un passage : rend le nombre affiché (0 : rien)
function ns:AggroLinkTick()
	local db = self:DB()
	if db.aggroLink == false or not (self.AggroOn and self:AggroOn()) or (self.AggroInCombat and self:AggroInCombat()) then
		self:AggroLinkHide()
		return 0
	end
	local count, plate = self:AggroLinkCount("target")
	if count <= 0 or not plate then
		self:AggroLinkHide()
		return 0
	end
	local badge = Badge(self)
	if not badge then return 0 end
	badge:SetParent(plate)
	badge:ClearAllPoints()
	badge:SetPoint("LEFT", plate, "RIGHT", 2, 0)
	if badge.SetFrameLevel and plate.GetFrameLevel then
		pcall(badge.SetFrameLevel, badge, (tonumber(plate:GetFrameLevel()) or 1) + 6)
	end
	local c = count >= ns.AGGRO_LINK_RED and Theme.RED or Theme.GOLD
	badge.text:SetText("+" .. count)
	badge.text:SetTextColor(c[1], c[2], c[3], 1)
	badge:Show()
	self.aggroLinkShown = count
	return count
end

-- /r2q diag : de quoi régler le rayon en jeu
function ns:AggroLinkDiagLine()
	local ok, count = pcall(self.AggroLinkCount, self, "target")
	return self:F("MSG_DIAG_AGGRO_LINK", ok and tostring(count) or "?", ns.AGGRO_LINK_RADIUS,
		math.floor(math.deg(ns.AggroLinkFov()) + 0.5))
end

ns.Every("aggro:link", ns.AGGRO_LINK_POLL, function()
	local ok, err = pcall(ns.AggroLinkTick, ns)
	if not ok and ns.RecordError then ns:RecordError("aggro:link", err) end
end)

if ns.Mark then ns.Mark("AggroLink") end
