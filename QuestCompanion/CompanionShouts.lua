-- CompanionShouts.lua -- le compagnon crie (3.2.0)
--
-- En MAJUSCULES (Theme.Upper, accents compris) et en couleur
-- (COMPANION_SHOUT_STYLE) : rouge pour le danger, or pour la joie ; le nom
-- (monstre, objet) ou le nombre en accent.
-- Danger (conseils importants : passent au cran Discret, jamais en muet) :
--   * aggro : la marque rouge de la portée d'aggro de Ready2Quest (son nom si
--     Ready2Quest le donne, AggroDangerUnit, 1.37.1), hors combat ;
--   * nuée : plusieurs monstres sur toi en combat (seul, hors instance) ;
--   * vie basse en combat ; munitions à sec en combat (chasseur) ;
--   * un monstre qui s'enfuit (il ramène ses amis) ;
--   * noyade (souffle bas) et fatigue (trop loin en mer) ;
--   * crâne (« ?? ») ciblé, durabilité critique : Advice.lua crie à la place
--     de ses conseils ordinaires (ns:CompanionShoutPool).
-- Joie (catégorie « event ») : survie de justesse, objet bleu ou violet,
-- niveau (Companion.lua appelle ns:CompanionShoutPool).
-- Pour rire (catégorie « reaction ») : une longue chute.
-- Réglage « Le compagnon crie » (db.companionShouts, page Paroles).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.COMPANION_SHOUT_POLL = 0.5     -- s entre deux regards
ns.COMPANION_SHOUT_SWARM = 3      -- monstres sur toi
ns.COMPANION_SHOUT_HP = 0.25      -- part de vie : vie basse
ns.COMPANION_SHOUT_CLOSE = 0.10   -- part de vie : survie de justesse
ns.COMPANION_SHOUT_BREATH = 0.4   -- part du souffle restant
ns.COMPANION_SHOUT_FALL = 2       -- s de chute
ns.COMPANION_SHOUT_SAME = 60      -- s avant de crier à nouveau sur le même monstre

local P = {}
-- Danger ----------------------------------------------------------------------
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
P.SHOUT_FLEE = {   -- %s = le monstre
	{ "%s s'enfuiiit ! Rattrape-le !", "%s is running awaaay! Catch it!" },
	{ "Il va chercher ses copains ! Arrête %s !", "It's fetching its friends! Stop %s!" },
	{ "%s se sauve ! Pas de renforts, pitié !", "%s is bolting! No reinforcements, please!" },
}
P.SHOUT_BREATH = {
	{ "De l'aiiir ! Remonte, remonte !", "Aiiir! Swim up, swim up!" },
	{ "Je fais des bulles ! Remonte viiite !", "I'm blowing bubbles! Surface, quiiick!" },
	{ "On se noie ! Vers le haut !", "We're drowning! Up, up!" },
}
P.SHOUT_FATIGUE = {
	{ "Demi-tour ! On va couler !", "Turn back! We're going to sink!" },
	{ "Trop loin ! Je ne sens plus mes pattes !", "Too far! I can't feel my paws!" },
	{ "Il n'y a rien par là ! Fais demi-touuur !", "There's nothing out there! Turn baaack!" },
}
P.SHOUT_AMMO = {
	{ "Plus de flèches ! Plus de flèches !", "Out of arrows! Out of arrows!" },
	{ "Le carquois est vide ! Au corps à corps, alors !", "The quiver's empty! Melee it is, then!" },
	{ "Plus rien à tirer ! Recharge !", "Nothing left to shoot! Reload!" },
}
P.SHOUT_SKULL = {   -- %s = le monstre
	{ "Un crâne ! %s est bien trop fort ! Demi-tour !", "A skull! %s is way too strong! Turn back!" },
	{ "%s ? Non non non ! On fait demi-tour !", "%s? No no no! We turn around!" },
	{ "Ne touche pas à %s ! Il va nous écraser !", "Don't touch %s! It'll flatten us!" },
}
P.SHOUT_DURA = {   -- %d = % de durabilité de la pièce la plus abîmée
	{ "Ton armure part en miettes ! %d %% !", "Your armour is falling apart! %d%%!" },
	{ "%d %% de durabilité ! Répare, viiite !", "%d%% durability! Repair, quiiick!" },
	{ "Ça craque de partout ! %d %%, au forgeron !", "Everything's creaking! %d%%, to the smith!" },
}
-- Joie ------------------------------------------------------------------------
P.SHOUT_SURVIVED = {
	{ "On est vivaaants !", "We're aliiive!" },
	{ "Ouf ! C'était moins une !", "Phew! That was close!" },
	{ "Encore debout ! Je n'ai pas eu peur. Pas du tout.", "Still standing! I wasn't scared. Not at all." },
	{ "Vivants ! Et on ne refait plus jamais ça !", "Alive! And we never do that again!" },
}
P.SHOUT_LOOT = {   -- %s = l'objet (bleu)
	{ "Un bleu ! %s !", "A blue! %s!" },
	{ "Ouaaah ! %s ! Il brille !", "Whoaaa! %s! It's shiny!" },
	{ "%s ! Ça, c'est du butin !", "%s! Now that's loot!" },
}
P.SHOUT_LOOT_EPIC = {   -- %s = l'objet (violet)
	{ "Un violet ! Un VIOLET ! %s !", "A purple! A PURPLE! %s!" },
	{ "%s ! Je vais m'évanouiiir !", "%s! I'm gonna faaaint!" },
	{ "Épique ! %s ! Montre-le à tout le monde !", "Epic! %s! Show it to everyone!" },
}
P.SHOUT_LEVEL = {   -- %d = le niveau
	{ "Niveau %d ! Youhouuu !", "Level %d! Woohoooo!" },
	{ "Niveau %d ! On est trop forts !", "Level %d! We're unstoppable!" },
	{ "Ding ! Niveau %d ! Je savais que tu y arriverais !", "Ding! Level %d! I knew you could do it!" },
}
-- Pour rire -------------------------------------------------------------------
P.SHOUT_FALL = {
	{ "Aaaaaaaaah !", "Aaaaaaaaah!" },
	{ "On tombe ! On tombe ! On toooombe !", "We're falling! Falling! Faaalling!" },
	{ "Je n'ai pas d'ailes, moi ! Aaaah !", "I don't have wings! Aaaah!" },
}
ns.RegisterCompanionLines(P, true)
P = nil

-- couleurs par cri (jetons du thème ; contraste mesuré sur la bulle, tests)
local DANGER = { ink = "T_RED", accent = "T_GOLD" }
local JOY = { ink = "T_GOLD", accent = "T_PARCHMENT" }
ns.COMPANION_SHOUT_STYLE = {
	SHOUT_AGGRO = DANGER, SHOUT_AGGRO_ANY = DANGER, SHOUT_SWARM = DANGER, SHOUT_LOW_HP = DANGER,
	SHOUT_FLEE = DANGER, SHOUT_BREATH = DANGER, SHOUT_FATIGUE = DANGER, SHOUT_AMMO = DANGER,
	SHOUT_SKULL = DANGER, SHOUT_DURA = DANGER,
	SHOUT_SURVIVED = JOY, SHOUT_LOOT = JOY, SHOUT_LOOT_EPIC = JOY, SHOUT_LEVEL = JOY, SHOUT_FALL = JOY,
}
-- catégorie de CompanionSay (danger : conseil important)
local CATEGORY = { SHOUT_SURVIVED = "event", SHOUT_LOOT = "event", SHOUT_LOOT_EPIC = "event", SHOUT_LEVEL = "event",
	SHOUT_FALL = "reaction" }

-- en combat, le cri passe (le reste est résumé après)
if type(ns.COMPANION_COMBAT_PASS) == "table" then
	for _, pool in ipairs({ "SHOUT_SWARM", "SHOUT_LOW_HP", "SHOUT_FLEE", "SHOUT_BREATH", "SHOUT_FATIGUE", "SHOUT_AMMO" }) do
		ns.COMPANION_COMBAT_PASS[pool] = true
	end
end
local rules = ns.COMPANION_RULES
if rules and type(rules.cooldowns) == "table" then
	rules.cooldowns.shout_aggro = 20
	rules.cooldowns.shout_fight = 0
	rules.cooldowns.shout_flee = 8
	rules.cooldowns.shout_fall = 30
end

ns.RegisterDefaults({ companionShouts = true })

local FR = {
	OPT_COMP_SHOUTS = "Le compagnon crie",
	OPT_COMP_SHOUTS_DESC = "En majuscules : le danger en rouge (aggro avec Ready2Quest, nuée, vie basse, fuyard, noyade, crâne…), les grandes joies en or (survie de justesse, objet bleu ou violet, niveau).",
}
local EN = {
	OPT_COMP_SHOUTS = "The companion shouts",
	OPT_COMP_SHOUTS_DESC = "In capitals: danger in red (aggro with Ready2Quest, swarm, low health, runner, drowning, skull…), big joys in gold (close call, blue or purple item, level).",
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
	local ok, a, b, c, d, e, f = pcall(fn, ...)
	if not ok then return nil end
	return ns.Plain(a), ns.Plain(b), ns.Plain(c), ns.Plain(d), ns.Plain(e), ns.Plain(f)
end
local function G(name) return rawget(_G, name) end

local function Fighting() return Call(G("UnitAffectingCombat"), "player") == true end

local function HealthShare()
	local health = tonumber((Call(G("UnitHealth"), "player")))
	local max = tonumber((Call(G("UnitHealthMax"), "player")))
	if not (health and max and max > 0) then return nil end
	return health / max
end

local function SoloOutside()
	if Call(G("IsInInstance")) == true then return false end
	return Call(G("IsInGroup")) ~= true
end

function ns:CompanionShoutsOn() return self:DB().companionShouts ~= false end

-- Le réservoir crié qui remplace `pool` (conseils, butin, niveau), ou nil
local REPLACES = { ADVICE_DURA_CRIT = "SHOUT_DURA", LEVEL = "SHOUT_LEVEL", ADVICE_SKULL = "SHOUT_SKULL" }
function ns:CompanionShoutPool(pool)
	if not self:CompanionShoutsOn() then return nil end
	return REPLACES[pool]
end

-- Crie `pool` (réservoir SHOUT_*) : true s'il a parlé
function ns:CompanionShout(pool, args, cd)
	if not self:CompanionShoutsOn() then return false end
	local category = CATEGORY[pool] or "advice"
	local ok, said = pcall(self.CompanionSay, self, pool, { shout = ns.COMPANION_SHOUT_STYLE[pool] or {},
		category = category, important = category == "advice" or nil, force = true, args = args, cd = cd })
	return ok and said == true
end

-- Ready2Quest : monstre sous la marque rouge -> true, nom (nil si inconnu)
function ns:CompanionShoutDanger()
	local other = G("Ready2Quest")
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

-- Jauges du jeu (souffle, fatigue) : { BREATH = part restante, … } si elles
-- se vident
local MIRRORS = {}
function ns:CompanionShoutMirrors()
	for key in pairs(MIRRORS) do MIRRORS[key] = nil end
	local info, progress = G("GetMirrorTimerInfo"), G("GetMirrorTimerProgress")
	for index = 1, (tonumber(rawget(_G, "MIRRORTIMER_NUMTIMERS")) or 3) do
		local timer, _, maxValue, scale = Call(info, index)
		if type(timer) == "string" and timer ~= "UNKNOWN" and (tonumber(scale) or 0) < 0 then
			local value = tonumber((Call(progress, timer)))
			local max = tonumber(maxValue)
			MIRRORS[timer] = (value and max and max > 0) and value / max or 1
		end
	end
	return MIRRORS
end

-- ---------------------------------------------------------------------------
-- Un regard (horloge companion:shout) : rend le réservoir crié, ou nil
-- ---------------------------------------------------------------------------
function ns:CompanionShoutTick(now)
	if not self:CompanionShoutsOn() then return nil end
	now = now or (ns.Now and ns.Now()) or 0
	local state = self.companionShoutState or {}
	self.companionShoutState = state

	-- noyade, fatigue : une fois par jauge (en combat aussi)
	local mirrors = self:CompanionShoutMirrors()
	if mirrors.BREATH and mirrors.BREATH < ns.COMPANION_SHOUT_BREATH then
		if not state.breathSaid and self:CompanionShout("SHOUT_BREATH") then state.breathSaid = true; return "SHOUT_BREATH" end
	elseif not mirrors.BREATH then
		state.breathSaid = nil
	end
	if mirrors.EXHAUSTION then
		if not state.fatigueSaid and self:CompanionShout("SHOUT_FATIGUE") then state.fatigueSaid = true; return "SHOUT_FATIGUE" end
	else
		state.fatigueSaid = nil
	end

	if Fighting() then
		state.aggroName, state.aggroAt, state.fallAt = nil, nil, nil
		state.fought = true
		local share = HealthShare()
		if share and share > 0 then state.lowest = math.min(state.lowest or 1, share) end
		if not state.hpSaid and share and share > 0 and share < ns.COMPANION_SHOUT_HP then
			if self:CompanionShout("SHOUT_LOW_HP", nil, "shout_fight") then state.hpSaid = true; return "SHOUT_LOW_HP" end
		end
		-- munitions : à sec pendant ce combat (il en avait au début)
		if self.PlayerClassToken and self.PlayerClassToken() == "HUNTER" and self.AmmoCount then
			local ammo = self.AmmoCount()
			if ammo and ammo > 0 then state.hadAmmo = true end
			if ammo == 0 and state.hadAmmo and not state.ammoSaid then
				if self:CompanionShout("SHOUT_AMMO", nil, "shout_fight") then state.ammoSaid = true; return "SHOUT_AMMO" end
			end
		end
		if not state.swarmSaid and SoloOutside() and self.CompanionAggroMode and self:CompanionAggroMode() ~= "off" then
			local count = self.CompanionAggroCount and self:CompanionAggroCount() or 0
			if count >= ns.COMPANION_SHOUT_SWARM then
				if self:CompanionShout("SHOUT_SWARM", { count }, "shout_fight") then state.swarmSaid = true; return "SHOUT_SWARM" end
			end
		end
		return nil
	end

	-- fin de combat : survie de justesse
	if state.fought then
		local close = state.lowest and state.lowest < ns.COMPANION_SHOUT_CLOSE
		state.fought, state.lowest, state.hpSaid, state.swarmSaid, state.ammoSaid, state.hadAmmo = nil, nil, nil, nil, nil, nil
		if close and Call(G("UnitIsDeadOrGhost"), "player") ~= true then
			if self:CompanionShout("SHOUT_SURVIVED") then return "SHOUT_SURVIVED" end
		end
	end

	-- longue chute (pas en taxi)
	if Call(G("IsFalling")) == true and Call(G("UnitOnTaxi"), "player") ~= true then
		state.fallAt = state.fallAt or now
		if not state.fallSaid and now - state.fallAt >= ns.COMPANION_SHOUT_FALL then
			state.fallSaid = true
			if self:CompanionShout("SHOUT_FALL", nil, "shout_fall") then return "SHOUT_FALL" end
		end
	else
		state.fallAt, state.fallSaid = nil, nil
	end

	local danger, name = self:CompanionShoutDanger()
	if not danger then return nil end
	local key = name or "?"
	if state.aggroName == key and state.aggroAt and now - state.aggroAt < ns.COMPANION_SHOUT_SAME then return nil end
	local pool = name and "SHOUT_AGGRO" or "SHOUT_AGGRO_ANY"
	if self:CompanionShout(pool, name and { name } or nil, "shout_aggro") then
		state.aggroName, state.aggroAt = key, now
		return pool
	end
	return nil
end

-- Un monstre qui s'enfuit (émote « … tente de s'enfuir », « … runs away… »)
local FLEE_WORDS = { "s'enfui", "fuir", "run away", "flee" }
function ns:CompanionShoutEmote(text, name)
	if not self:CompanionShoutsOn() or not Fighting() then return false end
	text = type(text) == "string" and text:lower() or ""
	local fleeing = false
	for _, word in ipairs(FLEE_WORDS) do if text:find(word, 1, true) then fleeing = true end end
	if not fleeing then return false end
	name = type(name) == "string" and name ~= "" and name or nil
	if not name then return false end
	return self:CompanionShout("SHOUT_FLEE", { name }, "shout_flee")
end

-- Un objet bleu (3) ou violet (4 et plus) ramassé : true s'il a crié
function ns:CompanionShoutLoot(link, quality)
	if not self:CompanionShoutsOn() or type(link) ~= "string" then return false end
	local item = link:match("%[(.-)%]")
	if not item or (tonumber(quality) or 0) < 3 then return false end
	return self:CompanionShout((tonumber(quality) or 0) >= 4 and "SHOUT_LOOT_EPIC" or "SHOUT_LOOT", { item }, "loot")
end

ns.On("CHAT_MSG_MONSTER_EMOTE", "companionShouts", function(text, name)
	ns:CompanionShoutEmote(ns.Plain(text), ns.Plain(name))
end, "companion:shout-emote")

ns.Every("companion:shout", ns.COMPANION_SHOUT_POLL, function()
	if not ns.companionFrame then return end
	local ok, err = pcall(ns.CompanionShoutTick, ns)
	if not ok and ns.RecordError then ns:RecordError("companion:shout", err) end
end)

if ns.Mark then ns.Mark("CompanionShouts") end
