-- CombatDeath.lua -- Ready2Quest 2.1.0 : Mot de l'ombre : Mort sans retour
--
-- Prêtre : l'icône de Mot de l'ombre : Mort s'allume au-dessus de la cible
-- (sa barre de nom), à la place du crâne des DoT, quand le sort, au plus bas de sa
-- fourchette, la tue. S'il ne la tue pas, le prêtre prend 30 % de sa vie
-- maximale en retour : l'icône dit quand ce risque n'existe pas.
--
-- La vie de la cible est secrète sur Forever : comme le crâne des DoT
-- (Combat/Modules/DoTInfo), une barre de statut invisible très longue reçoit
-- max = vie, valeur = dégâts ; son remplissage n'atteint le bord droit de la
-- fenêtre (seul morceau visible, découpé) que si dégâts >= vie, et l'icône
-- monte avec lui. Le client compare, pas nous.
--
-- Les dégâts viennent des tables du client Forever (SpellEffect, build
-- 1.60.1.70753) : base + points par niveau, moins la variance (6,05 %), plus
-- 42,9 % de la puissance des sorts d'Ombre. Talents et Forme d'Ombre ne sont
-- pas comptés : l'icône arrive un peu tard plutôt que trop tôt. La marge des
-- DoT mortels (90 % par défaut) couvre les résistances partielles.
local ADDON, ns = ...

ns.RegisterDefaults({ combatDeath = true })

-- rangs de Forever : sort, niveau de base, niveau max, base, points par niveau
ns.SHADOW_DEATH_RANKS = {
	{ id = 1309636, base = 56, max = 61, points = 448, perLevel = 2.5 },
	{ id = 1309635, base = 48, max = 53, points = 403, perLevel = 2.2 },
	{ id = 1309633, base = 40, max = 45, points = 370, perLevel = 1.9 },
	{ id = 1309595, base = 32, max = 37, points = 295, perLevel = 1.5 },
}
ns.SHADOW_DEATH = { variance = 0.0605, coefficient = 0.429, icon = 136149, school = 6, cooldown = 18,
	backlash = 30, size = 28, cover = 4, curtain = 12, length = 10000 }

local function Plain(value)
	if ns.Plain then return ns.Plain(value) end
	return value
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return nil end
	return Plain(a), Plain(b), Plain(c)
end

-- Le rang connu le plus haut, ou nil (pas prêtre, pas encore appris)
function ns:ShadowDeathRank()
	local known = rawget(_G, "IsPlayerSpell") or rawget(_G, "IsSpellKnown")
	if type(known) ~= "function" then return nil end
	for _, rank in ipairs(ns.SHADOW_DEATH_RANKS) do
		if Ask(known, rank.id) == true then return rank end
	end
	return nil
end

-- Les dégâts au plus bas de la fourchette (sans critique), avant la marge
function ns:ShadowDeathDamage(rank, level, spellPower)
	if not rank then return 0 end
	level = tonumber(level) or rank.base
	local levels = math.max(0, math.min(level, rank.max) - rank.base)
	local points = rank.points + rank.perLevel * levels
	local power = math.max(0, tonumber(spellPower) or 0)
	return points * (1 - ns.SHADOW_DEATH.variance) + power * ns.SHADOW_DEATH.coefficient
end

-- La marge des DoT mortels (50 à 100 %, 90 par défaut)
function ns:ShadowDeathMargin()
	local dots = rawget(_G, "Ready2QuestCombat_DoTInfoDB")
	local margin = type(dots) == "table" and tonumber(dots.killMargin) or 90
	return math.max(0, math.min(margin, 100)) / 100
end

-- Ce que la barre reçoit : les dégâts sûrs, marge comprise ; nil = rien à montrer
function ns:ShadowDeathLethal()
	local rank = self:ShadowDeathRank()
	if not rank then return nil end
	local level = Ask(rawget(_G, "UnitLevel"), "player")
	local power = Ask(rawget(_G, "GetSpellBonusDamage"), ns.SHADOW_DEATH.school)
	return self:ShadowDeathDamage(rank, level, power) * self:ShadowDeathMargin(), rank
end

-- La recharge : le jeu la cache souvent (valeur secrète, bêta 4 : l'icône
-- restait). Ready2Quest note donc lui-même le dernier lancer réussi
-- (UNIT_SPELLCAST_SUCCEEDED) et compte les 18 s ; la recharge lisible du
-- jeu compte aussi quand elle existe.
ns.shadowDeathIds = {}
for _, rank in ipairs(ns.SHADOW_DEATH_RANKS) do ns.shadowDeathIds[rank.id] = true end

function ns:ShadowDeathCast(unit, _, spellID)
	if Plain(unit) ~= "player" or not ns.shadowDeathIds[Plain(spellID)] then return false end
	self.shadowDeathCastAt = Ask(rawget(_G, "GetTime"))
	return true
end

function ns:ShadowDeathCooling(rank)
	local now = Ask(rawget(_G, "GetTime"))
	local at = self.shadowDeathCastAt
	if type(now) == "number" and type(at) == "number" and now - at < ns.SHADOW_DEATH.cooldown then return true end
	local api = rawget(_G, "C_Spell")
	local start, duration
	if api and type(api.GetSpellCooldown) == "function" then
		local info = Ask(api.GetSpellCooldown, rank.id)
		if type(info) == "table" then start, duration = Plain(info.startTime), Plain(info.duration) end
	elseif type(rawget(_G, "GetSpellCooldown")) == "function" then
		start, duration = Ask(GetSpellCooldown, rank.id)
	end
	if type(start) ~= "number" or type(duration) ~= "number" then return false end
	-- le temps de recharge global (1,5 s) ne compte pas
	return start > 0 and duration > 2
end

-- ---------------------------------------------------------------------------
-- L'icône : fenêtre découpée + barre invisible, comme le crâne
-- ---------------------------------------------------------------------------
-- 2.1.0 bêta 5 : elle REMPLACE la coche de portée et le crâne des DoT. Les
-- deux passent dans un cadre découpé (« rideau ») qui va du bout du
-- remplissage de notre barre au bord droit de la fenêtre : tant que le sort
-- ne tue pas, ce bout est loin à gauche et le rideau couvre l'endroit (coche
-- et crâne visibles) ; quand il tue, le bout touche le bord droit, le rideau
-- n'a plus de largeur et eux disparaissent, au moment même où notre icône
-- entre. Le client fait la comparaison (vie secrète), pas nous.
local widget

local function Build()
	if widget then return widget end
	local window = CreateFrame("Frame", nil, UIParent)
	if type(window.SetClipsChildren) ~= "function" then return nil end
	window:SetClipsChildren(true)
	window:Hide()
	local bar = CreateFrame("StatusBar", nil, window)
	if type(bar.SetMinMaxValues) ~= "function" then return nil end
	bar:SetPoint("RIGHT", window, "RIGHT")
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetStatusBarColor(0, 0, 0, 0)
	local icon = bar:CreateTexture(nil, "OVERLAY")
	icon:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT")
	icon:SetTexture(ns.SHADOW_DEATH.icon)
	-- sans le liseré gris des icônes de sort : un carré plein
	if type(icon.SetTexCoord) == "function" then icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
	-- le rideau : du bout du remplissage au bord droit de la fenêtre (+ marge)
	local curtain = CreateFrame("Frame", nil, UIParent)
	curtain:SetClipsChildren(true)
	local margin = ns.SHADOW_DEATH.curtain
	curtain:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPRIGHT", 0, margin)
	curtain:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", margin, -margin)
	widget = { window = window, bar = bar, icon = icon, curtain = curtain, held = {} }
	return widget
end

-- Les cadres cachés par notre icône : la coche de portée (nom global donné à
-- l'import) et la fenêtre du crâne de la barre de nom de la cible
local function Covered(e, plate, healthBar)
	local list = {}
	local check = rawget(_G, "Ready2QuestCombat_RangeIcon")
	if type(check) == "table" then list[#list + 1] = check end
	local dots = e.modules and e.modules.DoTInfo
	local marker = dots and dots.barMarker
	if marker and type(marker.widgetsFor) == "function" then
		local ok, w = pcall(marker.widgetsFor, plate, healthBar)
		if ok and type(w) == "table" and type(w.iconWindow) == "table" then list[#list + 1] = w.iconWindow end
	end
	return list
end

-- Un cadre passe derrière le rideau ; s'il change de parent (le moteur le
-- replace sur sa barre de nom), il y revient aussitôt. Release le rend.
local function Hold(w, frame)
	local entry = w.held[frame]
	if not entry then
		local parent = type(frame.GetParent) == "function" and frame:GetParent() or nil
		entry = { parent = parent, on = true }
		w.held[frame] = entry
		if type(rawget(_G, "hooksecurefunc")) == "function" and type(frame.SetParent) == "function" then
			hooksecurefunc(frame, "SetParent", function(f, p)
				if p == w.curtain then return end
				entry.parent = p
				if entry.on then f:SetParent(w.curtain) end
			end)
		end
	end
	entry.on = true
	if frame:GetParent() ~= w.curtain then frame:SetParent(w.curtain) end
end

local function Release(w)
	for frame, entry in pairs(w.held) do
		if entry.on then
			entry.on = false
			if entry.parent then frame:SetParent(entry.parent) end
		end
	end
end

local function Hide()
	if widget then
		widget.window:Hide()
		Release(widget)
	end
	return "hidden"
end

local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local NEXT_STRATA = {}
for index, name in ipairs(STRATA) do NEXT_STRATA[name] = STRATA[index + 1] or name end

-- Un passage : "hidden", "shown" ou "cooling"
function ns:ShadowDeathTick()
	local e = self.combat
	if not e or self:DB().combatDeath == false or self:DB().combatDots == false then return Hide() end
	if Ask(rawget(_G, "UnitExists"), "target") ~= true or Ask(rawget(_G, "UnitIsDead"), "target") == true
		or Ask(rawget(_G, "UnitCanAttack"), "player", "target") ~= true then
		return Hide()
	end
	local damage, rank = self:ShadowDeathLethal()
	if not damage then return Hide() end
	local api = rawget(_G, "C_NamePlate")
	local plate = api and Ask(api.GetNamePlateForUnit, "target")
	local healthBar = type(plate) == "table" and e.Plate and type(e.Plate.HealthBar) == "function"
		and Ask(e.Plate.HealthBar, plate) or nil
	if not healthBar then return Hide() end
	-- hors de portée (lisible), le sort ne part pas : rien, la croix rouge reste
	local range = e.modules and e.modules.Range
	if range and type(range.Check) == "function" and Ask(range.Check) == "out" then return Hide() end
	-- en recharge : rien, la coche et le crâne reviennent
	if self:ShadowDeathCooling(rank) then Hide(); return "cooling" end
	local w = Build()
	if not w then return "hidden" end
	-- à la place du crâne des DoT (même endroit), un peu plus grande
	local dots = rawget(_G, "Ready2QuestCombat_DoTInfoDB")
	dots = type(dots) == "table" and dots or {}
	local size = (tonumber(dots.nameplateIconSize) or ns.SHADOW_DEATH.size) + ns.SHADOW_DEATH.cover
	w.window:SetSize(size, size)
	w.bar:SetSize(ns.SHADOW_DEATH.length, size)
	w.icon:SetSize(size, size)
	-- bêta 5 : rattachée à la barre de nom (son échelle : avant, elle était à
	-- celle de l'écran et la coche, à celle de la barre, dépassait)
	if w.plate ~= plate then
		w.plate = plate
		w.window:SetParent(plate)
		w.curtain:SetParent(plate)
		w.anchor = nil
	end
	local where, x, y = dots.nameplateIconPosition or "above", tonumber(dots.plateIconOffsetX) or 0,
		tonumber(dots.plateIconOffsetY) or 0
	local signature = tostring(healthBar) .. where .. x .. "," .. y
	if w.anchor ~= signature then
		w.anchor = signature
		w.window:ClearAllPoints()
		if where == "left" then
			w.window:SetPoint("RIGHT", healthBar, "LEFT", -4 + x, y)
		elseif where == "below" then
			w.window:SetPoint("TOP", healthBar, "BOTTOM", x, -4 + y)
		elseif where == "right" then
			w.window:SetPoint("LEFT", healthBar, "RIGHT", 4 + x, y)
		else
			w.window:SetPoint("BOTTOM", healthBar, "TOP", x, 4 + y)
		end
	end
	-- deux strates au-dessus de la barre (strate illisible : HIGH)
	local strata = Ask(healthBar.GetFrameStrata, healthBar)
	strata = type(strata) == "string" and NEXT_STRATA[NEXT_STRATA[strata]] or "HIGH"
	w.window:SetFrameStrata(strata)
	if type(w.window.SetFrameLevel) == "function" then
		w.window:SetFrameLevel(50)
		w.bar:SetFrameLevel(51)
	end
	-- la vie (secrète) en maximum, les dégâts sûrs en valeur : le client compare
	local ok = pcall(function()
		w.bar:SetMinMaxValues(0, UnitHealth("target"))
		w.bar:SetValue(damage)
	end)
	if not ok then return Hide() end
	w.window:Show()
	-- la coche et le crâne derrière le rideau : ils s'effacent quand l'icône entre
	for _, frame in ipairs(Covered(e, plate, healthBar)) do Hold(w, frame) end
	return "shown"
end

if ns.combat and ns.Every then
	ns.Every("combat:death", 0.1, function()
		local ok, err = pcall(ns.ShadowDeathTick, ns)
		if not ok and ns.RecordError then ns:RecordError("combat:death", err) end
	end)
end
if ns.combat and ns.On then
	ns.On("UNIT_SPELLCAST_SUCCEEDED", "combat", function(...) ns:ShadowDeathCast(...) end, "combat:death")
end

if ns.Mark then ns.Mark("CombatDeath") end
