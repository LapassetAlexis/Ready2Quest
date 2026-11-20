-- CombatDeath.lua -- Ready2Quest 2.1.0 : Mot de l'ombre : Mort sans retour
--
-- Prêtre : l'icône de Mot de l'ombre : Mort s'allume à gauche de la barre de
-- vie de la cible (sa barre de nom) quand le sort, au plus bas de sa
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
	backlash = 30, size = 28, length = 10000 }

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

-- En recharge (lisible) : l'icône pâlit ; illisible : pleine
function ns:ShadowDeathCooling(rank)
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
	widget = { window = window, bar = bar, icon = icon }
	return widget
end

local function Hide()
	if widget then widget.window:Hide() end
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
	local w = Build()
	if not w then return "hidden" end
	local dots = rawget(_G, "Ready2QuestCombat_DoTInfoDB")
	local size = type(dots) == "table" and tonumber(dots.nameplateIconSize) or ns.SHADOW_DEATH.size
	w.window:SetSize(size, size)
	w.bar:SetSize(ns.SHADOW_DEATH.length, size)
	w.icon:SetSize(size, size)
	if w.anchor ~= healthBar then
		w.anchor = healthBar
		w.window:ClearAllPoints()
		w.window:SetPoint("RIGHT", healthBar, "LEFT", -4, 0)
	end
	local strata = Ask(healthBar.GetFrameStrata, healthBar)
	w.window:SetFrameStrata(type(strata) == "string" and NEXT_STRATA[strata] or "MEDIUM")
	-- la vie (secrète) en maximum, les dégâts sûrs en valeur : le client compare
	local ok = pcall(function()
		w.bar:SetMinMaxValues(0, UnitHealth("target"))
		w.bar:SetValue(damage)
	end)
	if not ok then return Hide() end
	local cooling = self:ShadowDeathCooling(rank)
	w.icon:SetDesaturated(cooling)
	w.icon:SetAlpha(cooling and 0.45 or 1)
	w.window:Show()
	return cooling and "cooling" or "shown"
end

if ns.combat and ns.Every then
	ns.Every("combat:death", 0.1, function()
		local ok, err = pcall(ns.ShadowDeathTick, ns)
		if not ok and ns.RecordError then ns:RecordError("combat:death", err) end
	end)
end

if ns.Mark then ns.Mark("CombatDeath") end
