-- Ready2Quest 1.37.1 : « +N », les voisins qui risquent de suivre la cible
-- (AggroLink.lua) : géométrie, voisins de la même sorte, affichage.
local Check, Say, ResetWorld, NS = T.Check, T.Say, T.ResetWorld, T.NS

local NAMES = { "UnitIsUnit", "UnitCreatureType", "UnitCreatureFamily", "UnitName", "UnitAffectingCombat", "UnitExists",
	"UnitIsPlayer", "UnitIsDead", "UnitCanAttack", "UnitReaction", "GetCVar" }
local saved = {}
for _, name in ipairs(NAMES) do saved[name] = rawget(_G, name) end
local savedDistance, savedPlates, savedOn, savedCombat = NS.AggroDistance, NS.aggroPlates, NS.AggroOn, NS.AggroInCombat

Say("-- aggro : voisins qui suivent (+N)")
local bad = {}
local function ok(label, cond, extra) if not cond then bad[#bad + 1] = label .. (extra ~= nil and (" [" .. tostring(extra) .. "]") or "") end end

-- géométrie
local fov = math.rad(90)
ok("centre de l'écran : angle nul", math.abs(NS.AggroLinkAngle(960, 1920, fov)) < 1e-6)
ok("bord droit : 45°", math.abs(NS.AggroLinkAngle(1920, 1920, fov) - math.rad(45)) < 1e-6)
ok("même direction : écart des distances", math.abs(NS.AggroLinkGap(20, 0.1, 26, 0.1) - 6) < 1e-6)
ok("côte à côte à 20 m, 90° d'écart : ~28 m", math.abs(NS.AggroLinkGap(20, 0, 20, math.rad(90)) - math.sqrt(800)) < 1e-6)
ok("fourchette sans borne haute : rien", NS.AggroLinkGap(nil, 0, 20, 0) == nil)

-- un monde : la cible (nameplate1), des voisins
ResetWorld()
UIParent:SetSize(1920, 1080)
local W = {}
-- une barre de nom a sa propre échelle : GetCenter est en unités de la barre
local function Plate(unit) return { GetCenter = function() return W.units[unit].x / (W.plateScale or 1), 500 end,
	GetEffectiveScale = function() return W.plateScale or 1 end, GetFrameLevel = function() return 1 end } end
local function Install()
	W = {
		units = {
			nameplate1 = { name = "Sanglier", ctype = "Bête", family = "Sanglier", range = { 20, 25 }, x = 960, target = true },
			nameplate2 = { name = "Sanglier", ctype = "Bête", family = "Sanglier", range = { 20, 25 }, x = 1000 },   -- collé
			nameplate3 = { name = "Sanglier", ctype = "Bête", family = "Sanglier", range = { 25, 30 }, x = 940 },    -- ~5 m
			nameplate4 = { name = "Loup", ctype = "Bête", family = "Loup", range = { 20, 25 }, x = 970 },            -- autre famille
			nameplate5 = { name = "Sanglier", ctype = "Bête", family = "Sanglier", range = { 20, 25 }, x = 1900 },   -- loin à droite
			nameplate6 = { name = "Sanglier", ctype = "Bête", family = "Sanglier", range = { 20, 25 }, x = 950, combat = true },
		},
	}
	NS.aggroPlates = {}
	for unit in pairs(W.units) do NS.aggroPlates[unit] = Plate(unit) end
	local function U(unit)
		if unit == "target" then for _, u in pairs(W.units) do if u.target then return u end end end
		return W.units[unit]
	end
	_G.UnitIsUnit = function(a, b)
		local ua, ub = U(a), U(b)
		return ua ~= nil and ua == ub
	end
	_G.UnitExists = function(unit) return U(unit) ~= nil end
	_G.UnitIsPlayer = function() return false end
	_G.UnitIsDead = function() return false end
	_G.UnitCanAttack = function() return true end
	_G.UnitReaction = function() return 2 end
	_G.UnitCreatureType = function(unit) local u = U(unit); return u and u.ctype end
	_G.UnitCreatureFamily = function(unit) local u = U(unit); return u and u.family end
	_G.UnitName = function(unit) local u = U(unit); return u and u.name end
	_G.UnitAffectingCombat = function(unit) local u = U(unit); return u and u.combat or false end
	_G.GetCVar = function(name) if name == "cameraFov" then return "90" end end
	NS.AggroDistance = function(_, unit) local u = U(unit); if u then return u.range[1], u.range[2] end end
	NS.AggroOn = function() return true end
	NS.AggroInCombat = function() return false end
	NS:DB().aggroLink = nil
	NS:AggroLinkHide()
end

Install()
local count = NS:AggroLinkCount("target")
ok("2 voisins : même famille, proches, hors combat (pas le loup, pas le lointain, pas celui en combat)", count == 2, count)
local shown = NS:AggroLinkTick()
local badge = NS.aggroLinkBadge
ok("2 voisins : le triangle d'alerte du jeu à droite de la barre, sans chiffre", shown == 2 and badge:IsShown()
	and badge.icon.texture == NS.AGGRO_LINK_ICON, badge and badge.icon and badge.icon.texture)
W.units.nameplate5.x = 980
ok("3 voisins : la même alerte", NS:AggroLinkTick() == 3 and badge:IsShown())
W.units.nameplate1.combat = true
ok("cible déjà en combat : rien", NS:AggroLinkTick() == 0 and not badge:IsShown())
W.units.nameplate1.combat = nil
NS.AggroInCombat = function() return true end
ok("joueur en combat : rien", NS:AggroLinkTick() == 0 and not badge:IsShown())
NS.AggroInCombat = function() return false end
NS:DB().aggroLink = false
ok("réglage coupé : rien", NS:AggroLinkTick() == 0 and not badge:IsShown())
NS:DB().aggroLink = nil
W.units.nameplate1.target = nil
ok("pas de cible : rien", NS:AggroLinkTick() == 0)
-- 1.38.0 : barres de nom à l'échelle 0,5 (GetCenter double) : le même compte
W.units.nameplate1.target = true
W.plateScale = 0.5
ok("échelle des barres de nom convertie : toujours 3", NS:AggroLinkCount("target") == 3, NS:AggroLinkCount("target"))
local diag = NS:AggroLinkDiagLine()
ok("/r2q diag : la cible et chaque voisin examiné (distance, x, écart), les autres sortes signalées",
	diag:find("cible", 1, true) and select(2, diag:gsub("écart", "")) >= 3 and diag:find("autre sorte", 1, true), diag)
W.plateScale = nil
W.units.nameplate1.target = nil
-- réglage sur la page Portée d'aggro
local row
for _, page in ipairs(NS.OPTION_PAGES or {}) do
	if page.id == "aggro" then for _, r in ipairs(page.rows) do if r.key == "aggroLink" then row = r end end end
end
ok("réglage « Alerte multi-aggro » (expliqué) sur la page Portée d'aggro", row ~= nil and NS.L[row.label] == "Alerte multi-aggro"
	and row.describe ~= nil)

for _, name in ipairs(NAMES) do _G[name] = saved[name] end
NS.AggroDistance, NS.aggroPlates, NS.AggroOn, NS.AggroInCombat = savedDistance, savedPlates, savedOn, savedCombat
NS:AggroLinkHide()
Check("[LINK] alerte multi-aggro : géométrie, voisins de la même sorte hors combat, triangle d'alerte, combat, réglage", #bad == 0,
	table.concat(bad, " ; "))

-- 1.38.0 (bêta 2) : la position d'une barre de nom est cachée sur Forever :
-- repli sur un cadre d'un pixel accroché à son centre
do
	ResetWorld()
	UIParent:SetSize(1920, 1080)
	local plate = CreateFrame("Frame", nil, UIParent)
	plate.GetCenter = function() error("valeur secrète") end
	local created = {}
	local savedCreate = _G.CreateFrame
	_G.CreateFrame = function(kind, name, parent, ...)
		local f = savedCreate(kind, name, parent, ...)
		if parent == plate then f.GetCenter = function() return 700, 300 end; created[#created + 1] = f end
		return f
	end
	local angle = NS.AggroLinkAngle(700, 1920, math.rad(90))
	local probeX
	do
		-- PlateX est locale : on passe par AggroLinkCount avec une cible simulée minimale
		local savedPlates, savedDistance, savedKind = NS.aggroPlates, NS.AggroDistance, NS.AggroUnitKind
		local savedIsUnit, savedCombat = rawget(_G, "UnitIsUnit"), rawget(_G, "UnitAffectingCombat")
		NS.aggroPlates = { nameplate1 = plate }
		NS.AggroDistance = function() return 20, 25 end
		NS.AggroUnitKind = function() return "hostile" end
		_G.UnitIsUnit = function(a, b) return a == "nameplate1" and b == "target" end
		_G.UnitAffectingCombat = function() return false end
		local trace = {}
		NS:AggroLinkCount("target", trace)
		probeX = trace.x0
		NS.aggroPlates, NS.AggroDistance, NS.AggroUnitKind = savedPlates, savedDistance, savedKind
		_G.UnitIsUnit, _G.UnitAffectingCombat = savedIsUnit, savedCombat
	end
	_G.CreateFrame = savedCreate
	Check("[LINK] position cachée de la barre : repli sur un cadre accroché à son centre (source « probe »)",
		#created == 1 and probeX == 700 and NS.AggroLinkXSource() == "probe" and angle ~= nil, tostring(probeX))
end

-- 1.38.0 : direction cachée (Forever) : la seule distance au joueur compte
do
	local savedPlates, savedDistance, savedKind = NS.aggroPlates, NS.AggroDistance, NS.AggroUnitKind
	local NAMES = { "UnitIsUnit", "UnitAffectingCombat", "UnitCreatureType", "UnitCreatureFamily", "UnitName" }
	local keep = {}
	for _, n in ipairs(NAMES) do keep[n] = rawget(_G, n) end
	-- en jeu : la position de la barre ET celle d'un cadre accroché à elle sont cachées
	local hidden = {}
	local function Hidden()
		local f = CreateFrame("Frame", nil, UIParent)
		f.GetCenter = function() error("secret") end
		hidden[f] = true
		return f
	end
	local savedCreate = _G.CreateFrame
	_G.CreateFrame = function(kind, name, parent, ...)
		local f = savedCreate(kind, name, parent, ...)
		if hidden[parent] then f.GetCenter = function() error("secret") end end
		return f
	end
	local ranges = { nameplate1 = { 22, 26 }, nameplate2 = { 25, 30 }, nameplate3 = { 40, 45 } }
	NS.aggroPlates = { nameplate1 = Hidden(), nameplate2 = Hidden(), nameplate3 = Hidden() }
	NS.AggroDistance = function(_, unit)
		local key = unit == "target" and "nameplate1" or unit
		local r = ranges[key]
		if r then return r[1], r[2] end
	end
	NS.AggroUnitKind = function() return "hostile" end
	_G.UnitIsUnit = function(a, b) return (a == "nameplate1" and b == "target") or a == b end
	_G.UnitAffectingCombat = function() return false end
	_G.UnitCreatureType = function() return "Humanoïde" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitName = function() return "Brute" end
	local trace = {}
	local count = NS:AggroLinkCount("target", trace)
	NS.aggroPlates, NS.AggroDistance, NS.AggroUnitKind = savedPlates, savedDistance, savedKind
	for n, v in pairs(keep) do _G[n] = v end
	_G.CreateFrame = savedCreate
	Check("[LINK] direction cachée : compte les monstres à ±8 m de la distance de la cible (24 vs 27,5 oui, 42,5 non)",
		count == 1 and trace.x0 == nil, tostring(count))
end

-- 1.38.0 (bêta 4) : le triangle se pose à droite de la coche de portée, à sa hauteur
do
	local savedCombat = NS.combat
	local bar = CreateFrame("Frame", nil, UIParent)
	NS.combat = { Plate = { HealthBar = function() return bar end },
		Settings = function(name) if name == "Range" then return { offset = 56, size = 26 } end return {} end }
	local savedCount = NS.AggroLinkCount
	NS.AggroLinkCount = function() return 2, CreateFrame("Frame", nil, UIParent) end
	local savedOn, savedCombatState = NS.AggroOn, NS.AggroInCombat
	NS.AggroOn, NS.AggroInCombat = function() return true end, function() return false end
	NS:DB().aggroLink = nil
	NS:AggroLinkTick()
	local p = NS.aggroLinkBadge.lastPoint or {}
	NS.AggroLinkCount, NS.combat, NS.AggroOn, NS.AggroInCombat = savedCount, savedCombat, savedOn, savedCombatState
	NS:AggroLinkHide()
	Check("[LINK] alerte : au-dessus du monstre, à droite de la coche (BOTTOMLEFT du TOP de la barre, x 17, y 60)",
		p.point == "BOTTOMLEFT" and p.relPoint == "TOP" and p.x == 17 and p.y == 60,
		tostring(p.point) .. " " .. tostring(p.relPoint) .. " " .. tostring(p.x) .. " " .. tostring(p.y))
end

-- 2.1.0 : « ns.Plain and ns.Plain(v) or v » rendait la valeur secrète quand
-- Plain répond nil (une valeur secrète) : le type de créature secret arrivait
-- dans une comparaison (AggroLink.lua:176, « attempt to compare local 'utype'
-- (a secret string value) »). Plus aucun repli de ce genre dans nos fichiers.
do
	local ROOT = rawget(_G, "ADDON_ROOT") or "."
	local found, files = {}, 0
	for _, pair in ipairs({ { "Ready2Quest", "Ready2Quest/Ready2Quest.toc" }, { "QuestCompanion", "QuestCompanion/QuestCompanion.toc" } }) do
		local toc = io.open(ROOT .. "/" .. pair[2], "r")
		for line in toc:lines() do
			line = line:gsub("\r", ""):gsub("\\", "/")
			if line:find("%.lua$") and not line:find("^#") and not line:find("^Combat/") then
				local h = io.open(ROOT .. "/" .. pair[1] .. "/" .. line, "r")
				if h then
					files = files + 1
					local n = 0
					for text in h:lines() do
						n = n + 1
						if text:find("Plain and [%w_%.]*Plain%b()%s*or%s") and not text:find("Plain%b()%s*or%s+nil") then
							found[#found + 1] = pair[1] .. "/" .. line .. ":" .. n
						end
					end
					h:close()
				end
			end
		end
		toc:close()
	end
	Check("[SECRET] aucun « Plain and Plain(v) or v » (il rend la valeur secrète) dans les deux addons", files > 100 and #found == 0,
		files .. " fichiers ; " .. table.concat(found, ", "))
end
