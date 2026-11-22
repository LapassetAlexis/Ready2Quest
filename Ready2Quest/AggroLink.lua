-- AggroLink.lua -- alerte multi-aggro : d'autres monstres près de ta cible
-- (1.37.1 « +N » ; 1.38.0 : une simple alerte, sans chiffre)
--
-- Hors combat, ta cible hostile : y a-t-il d'autres monstres de la même sorte
-- assez près d'elle pour venir l'aider si tu l'attaques ? Une ESTIMATION :
-- le client ne donne pas la position des monstres.
--   * distance joueur -> monstre : la fourchette de la portée d'aggro
--     (AggroDistance, objets et sorts de portée), prise en son milieu ;
--   * direction : la place de la barre de nom à l'écran, convertie en angle
--     avec le champ de vision de la caméra, puis l'écart entre les deux
--     points (loi des cosinus, rayon AGGRO_LINK_RADIUS). Sur Forever, cette
--     place est cachée (celle de la barre comme celle d'un cadre accroché à
--     elle, constaté en jeu le 17/11/2026) : repli sur la seule distance, un
--     monstre dont la distance est à moins de AGGRO_LINK_BAND de celle de la
--     cible compte. D'où une alerte, pas un chiffre.
-- « Même sorte » : même type de créature, et même famille pour les bêtes
-- (un loup n'aide pas un sanglier) ; vivant, hors combat, hostile ou du même
-- nom que la cible.
-- Affichage : le triangle d'alerte du jeu au-dessus de la cible, juste à
-- droite de la coche / croix de portée. Réglage « Alerte multi-aggro », page Portée d'aggro (actif).
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

ns.AGGRO_LINK_RADIUS = 12     -- m : voisin qui vient aider (estimation à régler en jeu)
ns.AGGRO_LINK_BAND = 8        -- m : sans direction, écart de distance au joueur toléré
ns.AGGRO_LINK_ICON = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"   -- triangle d'alerte du jeu
ns.AGGRO_LINK_SIZE = 18
ns.AGGRO_LINK_OFFSET = 56       -- hauteur de la coche de portée au-dessus de la barre (réglage du moteur, sinon)
ns.AGGRO_LINK_RANGE_SIZE = 26   -- sa taille (idem)
ns.AGGRO_LINK_POLL = 0.5      -- s
ns.AGGRO_LINK_FOV = 90        -- degrés, si le client ne dit rien

ns.RegisterStrings({
	OPT_AGGRO_LINK = "Alerte multi-aggro",
	OPT_AGGRO_LINK_DESC = "Un triangle d'alerte à droite de ta cible quand d'autres monstres de la même sorte sont à une distance proche de la sienne : ils risquent de venir aussi.",
	MSG_DIAG_AGGRO_LINK = "  multi-aggro : %s monstre(s) près de la cible (rayon %d m, champ %d°)",
	MSG_DIAG_AGGRO_LINK_TARGET = "    cible : %s m, x %s (écran %s, source %s)",
	MSG_DIAG_AGGRO_LINK_ROW = "    %s : %s m, x %s -> écart %s m",
	MSG_DIAG_AGGRO_LINK_SKIP = "    %s : autre sorte ou en combat",
}, {
	OPT_AGGRO_LINK = "Multi-aggro warning",
	OPT_AGGRO_LINK_DESC = "A warning triangle right of your target when other monsters of the same kind are at a similar distance: they may come along too.",
	MSG_DIAG_AGGRO_LINK = "  multi-aggro: %s monster(s) near the target (radius %d yd, field %d°)",
	MSG_DIAG_AGGRO_LINK_TARGET = "    target: %s yd, x %s (screen %s, source %s)",
	MSG_DIAG_AGGRO_LINK_ROW = "    %s: %s yd, x %s -> gap %s yd",
	MSG_DIAG_AGGRO_LINK_SKIP = "    %s: other kind or in combat",
})
ns.RegisterDefaults({ aggroLink = true })
for _, page in ipairs(ns.OPTION_PAGES or {}) do
	if page.id == "aggro" and type(page.rows) == "table" then
		local present
		for _, row in ipairs(page.rows) do if row.key == "aggroLink" then present = true end end
		if not present then
			table.insert(page.rows, { key = "aggroLink", label = "OPT_AGGRO_LINK", kind = "bool",
				describe = function() return L.OPT_AGGRO_LINK_DESC end })
		end
	end
end

local function Plain(value)
	if ns.Plain then return ns.Plain(value) end
	return value
end
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

-- x du centre de la barre, en unités de UIParent : une barre de nom a sa
-- propre échelle (1.38.0 : sans la conversion, les écarts étaient gonflés et
-- aucun voisin ne passait sous le rayon)
local function Scale(frame)
	if type(frame) ~= "table" or type(frame.GetEffectiveScale) ~= "function" then return 1 end
	local ok, s = pcall(frame.GetEffectiveScale, frame)
	s = ok and tonumber(Plain(s)) or nil
	return (s and s > 0) and s or 1
end
local function CenterX(frame)
	if type(frame) ~= "table" or type(frame.GetCenter) ~= "function" then return nil end
	local ok, x = pcall(frame.GetCenter, frame)
	x = ok and tonumber(Plain(x)) or nil
	if not x then return nil end
	return x * Scale(frame) / Scale(UIParent)
end

-- 1.38.0 (bêta 2) : sur Forever, la position d'une barre de nom est cachée
-- (GetCenter rend une valeur secrète). Repli : un cadre à nous, d'un pixel,
-- accroché au centre de la barre ; sa position se lit peut-être. La source
-- retenue est notée pour /r2q diag (« plate », « probe » ou rien).
local probes = setmetatable({}, { __mode = "k" })
local function Probe(plate)
	local probe = probes[plate]
	if probe then return probe end
	local ok, frame = pcall(CreateFrame, "Frame", nil, plate)
	if not ok or not frame then return nil end
	frame:SetSize(1, 1)
	frame:SetPoint("CENTER", plate, "CENTER", 0, 0)
	probes[plate] = frame
	return frame
end
local lastSource
local function PlateX(plate)
	local x = CenterX(plate)
	if x then lastSource = "plate"; return x end
	local probe = type(plate) == "table" and Probe(plate)
	x = probe and CenterX(probe)
	lastSource = x and "probe" or nil
	return x
end
function ns.AggroLinkXSource() return lastSource end

-- Le nombre de voisins de `target` (0 si rien à dire), et la barre de la cible.
-- trace (table) : ce qui a été examiné, pour /r2q diag
function ns:AggroLinkCount(target, trace)
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
	if trace then trace.r0, trace.x0 = r0, PlateX(targetPlate) end
	if not r0 then return 0, targetPlate end
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
				local r, x = self:AggroLinkRange(unit), PlateX(plate)
				local gap
				if a0 then
					gap = ns.AggroLinkGap(r0, a0, r, ns.AggroLinkAngle(x, width, fov))
					if gap and gap <= ns.AGGRO_LINK_RADIUS then count = count + 1 end
				elseif r then
					-- direction cachée : la seule distance au joueur
					gap = math.abs(r - r0)
					if gap <= ns.AGGRO_LINK_BAND then count = count + 1 end
				end
				if trace then trace[#trace + 1] = { name = uname, r = r, x = x, gap = gap } end
			elseif trace and kind then
				trace[#trace + 1] = { name = uname, skip = true }
			end
		end
	end
	return count, targetPlate
end

-- ---------------------------------------------------------------------------
-- L'alerte à droite de la barre de nom de la cible
-- ---------------------------------------------------------------------------
local function Badge(self)
	if self.aggroLinkBadge then return self.aggroLinkBadge end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
	if not ok or not frame then return nil end
	frame:SetSize(ns.AGGRO_LINK_SIZE, ns.AGGRO_LINK_SIZE)
	frame.icon = frame:CreateTexture(nil, "OVERLAY")
	frame.icon:SetAllPoints()
	frame.icon:SetTexture(ns.AGGRO_LINK_ICON)
	frame:Hide()
	self.aggroLinkBadge = frame
	return frame
end

function ns:AggroLinkHide()
	if self.aggroLinkBadge then self.aggroLinkBadge:Hide() end
	self.aggroLinkShown = nil
end

-- Un passage : rend le nombre de monstres comptés (0 : pas d'alerte)
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
	-- 1.38.0 (bêta 4) : au-dessus du monstre, juste à droite de la coche /
	-- croix de portée (même hauteur, même décalage ; loin des décorations des
	-- barres de nom, comme les chevrons de cible). La barre de vie vient du
	-- moteur Combat (il la trouve quel que soit l'addon des barres de nom).
	local e = self.combat
	local bar = e and e.Plate and type(e.Plate.HealthBar) == "function" and select(2, pcall(e.Plate.HealthBar, plate)) or nil
	local anchor = type(bar) == "table" and bar or plate
	local range = e and type(e.Settings) == "function" and e.Settings("Range") or {}
	local offset, size = tonumber(range.offset) or ns.AGGRO_LINK_OFFSET, tonumber(range.size) or ns.AGGRO_LINK_RANGE_SIZE
	badge:SetParent(plate)
	badge:ClearAllPoints()
	badge:SetPoint("BOTTOMLEFT", anchor, "TOP", math.floor(size / 2 + 4), offset + math.floor((size - ns.AGGRO_LINK_SIZE) / 2))
	if badge.SetFrameLevel and plate.GetFrameLevel then
		pcall(badge.SetFrameLevel, badge, (tonumber(plate:GetFrameLevel()) or 1) + 6)
	end
	badge:Show()
	self.aggroLinkShown = count
	return count
end

-- /r2q diag : de quoi régler le rayon en jeu (1.38.0 : le détail des voisins
-- examinés, sur des lignes en plus)
local function Fmt(v) return v and string.format("%.1f", v) or "?" end
function ns:AggroLinkDiagLine()
	local trace = {}
	local ok, count = pcall(self.AggroLinkCount, self, "target", trace)
	local lines = { self:F("MSG_DIAG_AGGRO_LINK", ok and tostring(count) or "?", ns.AGGRO_LINK_RADIUS,
		math.floor(math.deg(ns.AggroLinkFov()) + 0.5)) }
	if ok and (trace.r0 or trace.x0) then
		local width = UIParent and UIParent.GetWidth and tonumber(UIParent:GetWidth()) or nil
		lines[#lines + 1] = self:F("MSG_DIAG_AGGRO_LINK_TARGET", Fmt(trace.r0), Fmt(trace.x0), Fmt(width),
			tostring(ns.AggroLinkXSource() or "-"))
	end
	for index, row in ipairs(ok and trace or {}) do
		if index > 8 then break end
		lines[#lines + 1] = row.skip and self:F("MSG_DIAG_AGGRO_LINK_SKIP", tostring(row.name or "?"))
			or self:F("MSG_DIAG_AGGRO_LINK_ROW", tostring(row.name or "?"), Fmt(row.r), Fmt(row.x), Fmt(row.gap))
	end
	return table.concat(lines, "\n")
end

ns.Every("aggro:link", ns.AGGRO_LINK_POLL, function()
	local ok, err = pcall(ns.AggroLinkTick, ns)
	if not ok and ns.RecordError then ns:RecordError("aggro:link", err) end
end)

if ns.Mark then ns.Mark("AggroLink") end
