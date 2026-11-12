-- Couloir des fenêtres centrales (socle 3.0.1, Libs/Socle/Base.lua) : Place
-- au butin et Sac plein (Ready2Quest), Tout capturer et la carte de capture
-- (QuestCompanion) ne se chevauchent plus, dans un ordre d'ouverture comme
-- dans l'autre ; une fenêtre déplacée par le joueur ne bouge pas ; le
-- registre est commun aux deux addons, et marche avec un seul ; la scène de
-- capture suit sa fenêtre.
local Check, ResetWorld, NS, QNS, Mock = T.Check, T.ResetWorld, T.NS, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local P = { W = 1920, H = 1080 }

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

-- Géométrie de la maquette : un cadre ancré à UIParent (ou à rien) donne
-- ses bords, comme le client. UIParent : 1920 × 1080.
local FRACTION = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
	RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
function P.Edges(frame)
	local p = frame.lastPoint or { point = "CENTER" }
	local own = FRACTION[p.point] or FRACTION.CENTER
	local rel = FRACTION[p.relPoint or p.point] or FRACTION.CENTER
	local x = rel[1] * P.W + (p.x or 0)
	local y = rel[2] * P.H + (p.y or 0)
	local left, bottom = x - own[1] * frame.width, y - own[2] * frame.height
	return left, left + frame.width, bottom + frame.height, bottom
end
function P.Geo(frame)
	frame.GetLeft = function(self) return (P.Edges(self)) end
	frame.GetRight = function(self) return (select(2, P.Edges(self))) end
	frame.GetTop = function(self) return (select(3, P.Edges(self))) end
	frame.GetBottom = function(self) return (select(4, P.Edges(self))) end
	frame.IsVisible = function(self) return self.shown == true end
	return frame
end
P.savedUI = { GetWidth = UIParent.GetWidth, GetHeight = UIParent.GetHeight, width = UIParent.width, height = UIParent.height }
UIParent.width, UIParent.height = P.W, P.H

function P.Rect(frame)
	local l, r, t, b = P.Edges(frame)
	return { l = l, r = r, t = t, b = b }
end
function P.Overlap(a, b)
	local x, y = P.Rect(a), P.Rect(b)
	return x.l < y.r and y.l < x.r and x.b < y.t and y.b < x.t
end
function P.OnScreen(frame)
	local r = P.Rect(frame)
	return r.l >= 0 and r.r <= P.W and r.b >= 0 and r.t <= P.H
end

-- Un cadre central quelconque (comme ceux des deux addons)
function P.Window(w, h, x, y)
	local frame = P.Geo(CreateFrame("Frame", nil, UIParent))
	frame:SetSize(w, h)
	frame:SetPoint("CENTER", UIParent, "CENTER", x or 0, y or 60)
	frame:Hide()
	return frame
end

-- toutes fermées ; les fenêtres restent inscrites (leur place habituelle aussi)
function P.Reset()
	for frame in pairs(NS.Popups.frames) do if frame.Hide then frame:Hide() end end
end

-- 1. Registre commun aux deux addons --------------------------------------------
do
	local s = Steps()
	local registry = rawget(_G, "ReadyToQuestSocle")
	s.ok("une seule table", NS.Popups == QNS.Popups and registry.popups == NS.Popups)
	s.ok("versionnée", tonumber(NS.Popups.version) == 1)
	s.ok("même fonction des deux côtés", NS.PopupPlace ~= nil and QNS.PopupPlace ~= nil)
	P.Reset()
	local a, b = P.Window(400, 300), P.Window(400, 300)
	a:Show(); NS.PopupPlace(a)
	b:Show(); QNS.PopupPlace(b)
	s.ok("une fenêtre de QC voit celle de R2Q", not P.Overlap(a, b))
	-- un addon seul (registre vide) : son propre registre, qui marche
	local saved = registry
	_G.ReadyToQuestSocle = nil
	local solo = { APP = { id = "Solo", version = "0", slash = {}, coreFiles = {} } }
	local savedPrint = _G.print
	_G.print = function() end
	local ok, err = pcall(function() assert(loadfile(ROOT .. "/QuestCompanion/Libs/Socle/Base.lua"))("Solo", solo) end)
	_G.print = savedPrint
	s.ok("seul : chargé", ok, err)
	local soloPopups = ok and solo.Popups
	s.ok("seul : son registre", type(soloPopups) == "table" and soloPopups ~= saved.popups
		and rawget(_G, "ReadyToQuestSocle").popups == soloPopups)
	if soloPopups then
		local c, d = P.Window(400, 300), P.Window(400, 300)
		c:Show(); local first = solo.PopupPlace(c)
		d:Show(); solo.PopupPlace(d)
		s.ok("seul : la première reste chez elle", first == "home")
		s.ok("seul : la seconde à côté", not P.Overlap(c, d))
	end
	-- un registre d'une version plus ancienne : fonctions remplacées, fenêtres gardées
	local old = P.Window(100, 100)
	_G.ReadyToQuestSocle = { popups = { version = 0, frames = { [old] = { order = 1 } } } }
	local solo2 = { APP = { id = "Solo2", version = "0", slash = {}, coreFiles = {} } }
	_G.print = function() end
	ok = pcall(function() assert(loadfile(ROOT .. "/QuestCompanion/Libs/Socle/Base.lua"))("Solo2", solo2) end)
	_G.print = savedPrint
	s.ok("ancienne version mise à jour, données gardées", ok and solo2.Popups.version == 1
		and solo2.Popups.frames[old] ~= nil and type(solo2.Popups.Place) == "function")
	_G.ReadyToQuestSocle = saved
	if _G.SlashCmdList then _G.SlashCmdList.SOLO = nil; _G.SlashCmdList.SOLO2 = nil end
	P.Reset()
	s.check("[POP] registre commun : une table pour les deux addons, et pour un seul")
end

-- 2. Jamais l'une sur l'autre, dans les deux ordres -------------------------------------
do
	local s = Steps()
	ResetWorld()
	-- les vraies fenêtres : Place au butin (R2Q), Tout capturer (QC)
	local loot = P.Geo(NS:EnsureLootRoom())
	local batch = P.Geo(QNS:EnsureCaptureBatchFrame())
	s.ok("fenêtres créées", loot and batch)
	for _, order in ipairs({ { "loot", "batch" }, { "batch", "loot" } }) do
		P.Reset()
		loot:Hide(); batch:Hide()
		for _, which in ipairs(order) do
			if which == "loot" then
				NS:LootRoomOpen(true)
			else
				batch:Show(); QNS.PopupPlace(batch)
			end
		end
		local label = order[1] .. " puis " .. order[2]
		s.ok(label .. " : ouvertes", loot:IsShown() and batch:IsShown())
		s.ok(label .. " : pas de chevauchement", not P.Overlap(loot, batch))
		s.ok(label .. " : à l'écran", P.OnScreen(loot) and P.OnScreen(batch))
		local first = order[1] == "loot" and loot or batch
		local rf, rs = P.Rect(first), P.Rect(order[1] == "loot" and batch or loot)
		s.ok(label .. " : à côté, 12 px d'écart", math.abs(rs.l - rf.r - 12) < 0.01 or math.abs(rf.l - rs.r - 12) < 0.01
			or math.abs(rf.b - rs.t - 12) < 0.01)
	end
	-- la première se ferme : l'autre ne bouge pas
	local before = P.Rect(batch)
	loot:Hide()
	s.ok("une fermée : l'autre reste où elle est", P.Rect(batch).l == before.l and P.Rect(batch).t == before.t)
	-- seule, elle revient à sa place habituelle
	batch:Hide()
	batch:Show(); QNS.PopupPlace(batch)
	local home = P.Rect(batch)
	s.ok("seule : à sa place", math.abs((home.l + home.r) / 2 - P.W / 2) < 0.01)
	-- trois fenêtres : aucune paire ne se chevauche
	P.Reset()
	local a, b, c = P.Window(500, 400), P.Window(500, 400), P.Window(500, 400)
	a:Show(); NS.PopupPlace(a); b:Show(); NS.PopupPlace(b); c:Show(); NS.PopupPlace(c)
	s.ok("trois : aucune paire", not P.Overlap(a, b) and not P.Overlap(a, c) and not P.Overlap(b, c))
	-- pas de place à côté : dessous
	P.Reset()
	local wide1, wide2 = P.Window(1200, 300, 0, 200), P.Window(1200, 300, 0, 200)
	wide1:Show(); NS.PopupPlace(wide1)
	wide2:Show()
	local where = NS.PopupPlace(wide2)
	s.ok("trop large pour les côtés : dessous", where == "below" and not P.Overlap(wide1, wide2) and P.OnScreen(wide2), where)
	-- pas de chevauchement à l'ouverture : elle ne bouge pas
	P.Reset()
	local left, right = P.Window(300, 200, -600, 0), P.Window(300, 200, 600, 0)
	left:Show(); NS.PopupPlace(left)
	right:Show()
	s.ok("déjà libre : laissée chez elle", NS.PopupPlace(right) == "home")
	P.Reset()
	loot:Hide(); batch:Hide()
	s.check("[POP] deux fenêtres ouvertes ensemble ne se chevauchent jamais, dans les deux ordres")
end

-- 3. Une fenêtre placée par le joueur ne bouge pas -------------------------------------
do
	local s = Steps()
	P.Reset()
	local a, b = P.Window(400, 300), P.Window(400, 300)
	a:Show(); NS.PopupPlace(a)
	NS.Popups.Register(b)
	-- glissée pendant la session (OnDragStop)
	b.hooks.OnDragStop(b)
	b:Show()
	s.ok("glissée : pas bougée", NS.PopupPlace(b) == "user" and P.Rect(b).l == P.Rect(a).l)
	-- position gardée d'une session à l'autre (IsUserPlaced du client)
	P.Reset()
	local c = P.Window(400, 300)
	c.IsUserPlaced = function() return true end
	a:Show(); NS.PopupPlace(a)
	c:Show()
	s.ok("IsUserPlaced : pas bougée", NS.PopupPlace(c) == "user")
	-- Sac plein : position enregistrée dans la sauvegarde
	P.Reset()
	ResetWorld()
	NS:DB().bagspacePoint = { point = "CENTER", x = 0, y = 60 }
	NS.bagspace = { list = { { bag = 0, slot = 1, itemID = 1, count = 1, quality = 0, link = "x", value = 0 } }, index = 1 }
	NS.bagspaceFrame = nil
	a:Show(); NS.PopupPlace(a)
	local frame = P.Geo(NS:EnsureBagSpaceFrame())
	frame:Hide()
	NS:ShowBagSpaceFrame()
	s.ok("Sac plein déplacé par le joueur : laissé", (frame.lastPoint.point == "CENTER") and frame.lastPoint.relPoint == "CENTER")
	frame:Hide()
	NS:DB().bagspacePoint = nil
	NS.bagspace, NS.bagspaceFrame = nil, nil
	P.Reset()
	s.check("[POP] une fenêtre placée par le joueur n'est jamais déplacée")
end

-- 4. La scène de capture suit sa fenêtre ---------------------------------------------------
do
	local s = Steps()
	ResetWorld()
	local stage = QNS:EnsureCaptureStage()
	local function Anchored(region, target)
		for _ = 1, 12 do
			if region == nil then return false end
			if region == target then return true end
			if region == UIParent then return false end
			local p = region.lastPoint
			region = (p and p.relTo) or (type(region.allPoints) == "table" and region.allPoints) or region.mockParent
		end
		return false
	end
	s.ok("carte créée", stage ~= nil)
	s.ok("filet ancré à la carte", stage and stage.net and Anchored(stage.net, stage))
	s.ok("cadre du filet ancré à la carte", stage and stage.netFrame and Anchored(stage.netFrame, stage))
	s.ok("aucune pièce de la scène ancrée à l'écran", stage and stage.scene and Anchored(stage.scene, stage))
	if stage then
		P.Geo(stage)
		P.Reset()
		local other = P.Window(500, 400)
		other:Show(); NS.PopupPlace(other)
		stage:Show(); QNS.PopupPlace(stage)
		s.ok("carte déplacée à côté", not P.Overlap(stage, other))
		s.ok("le filet la suit (même ancrage)", Anchored(stage.net, stage))
		stage:Hide()
	end
	P.Reset()
	s.check("[POP] la scène de capture suit sa fenêtre (ancrée à la carte, pas à l'écran)")
end

UIParent.width, UIParent.height = P.savedUI.width, P.savedUI.height
