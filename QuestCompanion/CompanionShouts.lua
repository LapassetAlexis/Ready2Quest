-- CompanionShouts.lua -- le compagnon crie quand ça devient dangereux (3.2.0)
--
-- Trois situations, en MAJUSCULES (Theme.Upper, accents compris) et en
-- rouge (COMPANION_SHOUT_STYLE ; le nom du monstre, le nombre en or) :
--   * un monstre sur le point de t'aggro : la marque rouge de la portée
--     d'aggro de Ready2Quest est affichée (son nom si Ready2Quest le donne,
--     AggroDangerUnit, 1.37.1) ; hors combat seulement ;
--   * plusieurs monstres sur toi en plein combat (COMPANION_SHOUT_SWARM), seul
--     et hors instance, comme le battement rouge du cadre ; une fois par combat ;
--   * ta vie sous COMPANION_SHOUT_HP en combat ; une fois par combat.
-- Réglage « Le compagnon crie dans le danger » (db.companionShouts, page
-- Paroles). Muet au cran 0 de la réglette ; comme un conseil important, il
-- passe au cran Discret. Sans Ready2Quest, le cri d'aggro n'existe pas.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.COMPANION_SHOUT_POLL = 0.5     -- s entre deux regards
ns.COMPANION_SHOUT_SWARM = 3      -- monstres sur toi
ns.COMPANION_SHOUT_HP = 0.25      -- part de vie
ns.COMPANION_SHOUT_SAME = 60      -- s avant de crier à nouveau sur le même monstre

local P = {}
P.SHOUT_AGGRO = {   -- %s = le monstre
	{ "Attentioooon ! %s va t'aggro !", "Heads uuuup! %s is about to aggro!" },
	{ "Recule, recule ! %s t'a presque vu !", "Back off, back off! %s has almost spotted you!" },
	{ "Stoooop ! Encore un pas et %s te saute dessus !", "Stoooop! One more step and %s jumps you!" },
	{ "Aggro en vue ! %s, juste là !", "Aggro incoming! %s, right there!" },
	{ "Pas par là ! %s n'attend que ça !", "Not that way! %s is just waiting for it!" },
}
P.SHOUT_AGGRO_ANY = {
	{ "Attentioooon à l'aggrooo !", "Watch the aggrooo!" },
	{ "Recule ! Il va te voir !", "Back off! It's going to see you!" },
	{ "Stoooop ! Un pas de plus et c'est la bagarre !", "Stoooop! One more step and it's a brawl!" },
}
P.SHOUT_SWARM = {   -- %d = nombre de monstres
	{ "Ils sont %d ! Cooouuurs !", "There are %d of them! Ruuuun!" },
	{ "%d sur toi ! C'est pas une fête, c'est une embuscade !", "%d on you! This isn't a party, it's an ambush!" },
	{ "Au secouuurs ! %d d'un coup !", "Heeelp! %d at once!" },
	{ "%d monstres ! Je savais qu'il fallait pas toucher à celui-là !", "%d monsters! I knew you shouldn't have poked that one!" },
}
P.SHOUT_LOW_HP = {
	{ "Ta viiie ! Soigne-toi, viiite !", "Your heeealth! Heal up, quiiick!" },
	{ "Potion ! POTION ! Maintenant !", "Potion! POTION! Now!" },
	{ "On va mourir ! Enfin, toi. Fais quelque chose !", "We're gonna die! Well, you are. Do something!" },
	{ "Sauve-toi ! Je garde tes affaires !", "Run for it! I'll mind your stuff!" },
}
ns.RegisterCompanionLines(P, true)
P = nil

-- en combat, le cri passe (le reste est résumé après) ; pause propre au cri d'aggro
if type(ns.COMPANION_COMBAT_PASS) == "table" then
	ns.COMPANION_COMBAT_PASS.SHOUT_SWARM = true
	ns.COMPANION_COMBAT_PASS.SHOUT_LOW_HP = true
end
local rules = ns.COMPANION_RULES
if rules and type(rules.cooldowns) == "table" then
	rules.cooldowns.shout_aggro = 20
	rules.cooldowns.shout_fight = 0
end

ns.RegisterDefaults({ companionShouts = true })

local FR = {
	OPT_COMP_SHOUTS = "Crie dans le danger",
	OPT_COMP_SHOUTS_DESC = "En majuscules : un monstre sur le point de t'aggro (avec la portée d'aggro de Ready2Quest), plusieurs monstres sur toi, ta vie au plus bas.",
}
local EN = {
	OPT_COMP_SHOUTS = "Shouts in danger",
	OPT_COMP_SHOUTS_DESC = "In capitals: a monster about to aggro you (with Ready2Quest's aggro range), several monsters on you, your health running low.",
}
ns.RegisterStrings(FR, EN)

-- la ligne dans la page du compagnon (rangée ensuite dans « Paroles » :
-- COMPANION_OPTION_SPLIT, OptionsCompanionSplit.lua)
for _, page in ipairs(ns.OPTION_PAGES or {}) do
	if page.id == "companionMain" and type(page.rows) == "table" then
		local after, present
		for index, row in ipairs(page.rows) do
			if row.key == "companionShouts" then present = true end
			if row.key == "companionJokes" or row.key == "companionChatter" then after = index end
		end
		if not present then
			table.insert(page.rows, (after or #page.rows) + 1, { key = "companionShouts", label = "OPT_COMP_SHOUTS", kind = "bool",
				describe = function() return L.OPT_COMP_SHOUTS_DESC end })
		end
	end
end

-- ---------------------------------------------------------------------------
-- Lectures protégées (valeurs secrètes : rien)
-- ---------------------------------------------------------------------------
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then return nil end
	return ns.Plain(a), ns.Plain(b)
end

local function Fighting()
	return Call(rawget(_G, "UnitAffectingCombat"), "player") == true
end

-- Ready2Quest : monstre sous la marque rouge -> true, nom (nil si inconnu)
function ns:CompanionShoutDanger()
	local other = rawget(_G, "Ready2Quest")
	if type(other) ~= "table" or other == ns then return false end
	if type(other.AggroDangerUnit) == "function" then
		local ok, unit, name = pcall(other.AggroDangerUnit, other)
		if ok and unit then return true, type(name) == "string" and name ~= "" and name or nil end
		return false
	end
	if type(other.AggroDangerShown) == "function" then
		local ok, shown = pcall(other.AggroDangerShown, other)
		return ok and shown == true, nil
	end
	return false
end

local function LowHealth()
	local health = tonumber((Call(rawget(_G, "UnitHealth"), "player")))
	local max = tonumber((Call(rawget(_G, "UnitHealthMax"), "player")))
	return health and max and max > 0 and health > 0 and health / max < ns.COMPANION_SHOUT_HP
end

local function SoloOutside()
	if Call(rawget(_G, "IsInInstance")) == true then return false end
	return Call(rawget(_G, "IsInGroup")) ~= true
end

-- couleurs par cri (jetons du thème ; contraste mesuré sur la bulle, tests)
ns.COMPANION_SHOUT_STYLE = {
	SHOUT_AGGRO = { ink = "T_RED", accent = "T_GOLD" },
	SHOUT_AGGRO_ANY = { ink = "T_RED" },
	SHOUT_SWARM = { ink = "T_RED", accent = "T_GOLD" },
	SHOUT_LOW_HP = { ink = "T_RED" },
}

local function Shout(self, pool, args, cd)
	local ok, said = pcall(self.CompanionSay, self, pool, { shout = ns.COMPANION_SHOUT_STYLE[pool] or {},
		category = "advice", important = true, force = true, args = args, cd = cd })
	return ok and said == true
end

-- Un regard : rend le réservoir crié (ou nil). `now` : horloge de l'addon.
function ns:CompanionShoutTick(now)
	if self:DB().companionShouts == false then return nil end
	now = now or (ns.Now and ns.Now()) or 0
	local state = self.companionShoutState or {}
	self.companionShoutState = state
	if Fighting() then
		state.aggroName, state.aggroAt = nil, nil
		if not state.hpSaid and LowHealth() then
			if Shout(self, "SHOUT_LOW_HP", nil, "shout_fight") then state.hpSaid = true; return "SHOUT_LOW_HP" end
		end
		if not state.swarmSaid and SoloOutside() and self.CompanionAggroMode and self:CompanionAggroMode() ~= "off" then
			local count = self.CompanionAggroCount and self:CompanionAggroCount() or 0
			if count >= ns.COMPANION_SHOUT_SWARM then
				if Shout(self, "SHOUT_SWARM", { count }, "shout_fight") then state.swarmSaid = true; return "SHOUT_SWARM" end
			end
		end
		return nil
	end
	state.hpSaid, state.swarmSaid = nil, nil
	local danger, name = self:CompanionShoutDanger()
	if not danger then return nil end
	local key = name or "?"
	if state.aggroName == key and state.aggroAt and now - state.aggroAt < ns.COMPANION_SHOUT_SAME then return nil end
	local pool = name and "SHOUT_AGGRO" or "SHOUT_AGGRO_ANY"
	if Shout(self, pool, name and { name } or nil, "shout_aggro") then
		state.aggroName, state.aggroAt = key, now
		return pool
	end
	return nil
end

ns.Every("companion:shout", ns.COMPANION_SHOUT_POLL, function()
	if not ns.companionFrame then return end
	local ok, err = pcall(ns.CompanionShoutTick, ns)
	if not ok and ns.RecordError then ns:RecordError("companion:shout", err) end
end)

if ns.Mark then ns.Mark("CompanionShouts") end
