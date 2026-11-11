-- Personality.lua -- le caractère du compagnon (QuestCompanion)
--
-- Le compagnon naît sans caractère. Pendant ses PERSONALITY_FORM_AFTER
-- premières secondes de jeu, il observe ta façon de jouer :
--   explorer -> Curieux, manger -> Gourmand, combattre (élites) -> Téméraire,
--   te reposer -> Paresseux, mourir souvent -> Taquin, le caresser -> Câlin.
-- Puis il l'annonce. Certaines apparences apportent leur propre caractère,
-- qu'elles seules ont (chouette Sage, ara Perroquet, feu follet Mystique,
-- tortue Zen, serpent Rusé, dragon féerique Espiègle) : par défaut, il prend
-- celui de son apparence (réglage « Caractère : apparence / le sien ») ; une
-- fois porté, un caractère d'apparence reste au choix dans les réglages.
-- 3.1.0 : chaque créature capturée a son caractère (celui de son spécimen,
-- SpecimenTraits.lua), qu'elle apporte comme une apparence ; le caractère
-- formé reste celui des mascottes et des compagnons de saison.
-- Ce que ça change :
--   * ses phrases : ses propres versions des grands moments (et des conseils) ;
--   * ses goûts : l'envie qu'il préfère monte 50 % plus vite et baisse moins ;
--   * ce qu'il remarque de lui-même (NOTICE), une fois tous les quarts d'heure au plus ;
--   * sa façon de bouger : effets plus ou moins amples.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

local FR = {
	TRAIT_curious        = "Curieux",
	TRAIT_glutton        = "Gourmand",
	TRAIT_daring         = "Téméraire",
	TRAIT_lazy           = "Paresseux",
	TRAIT_teasing        = "Taquin",
	TRAIT_cuddly         = "Câlin",
	TRAIT_wise           = "Sage",
	TRAIT_parrot         = "Perroquet",
	TRAIT_mystic         = "Mystique",
	TRAIT_zen            = "Zen",
	TRAIT_sly            = "Rusé",
	TRAIT_mischievous    = "Espiègle",
	TRAIT_fearful        = "Peureux",
	TRAIT_tinker         = "Bricoleur",
	TRAIT_NONE           = "Pas encore formé",
	TRAIT_AUTO           = "Selon son jeu",
	TRAIT_DESC_curious     = "Il pose mille questions et remarque chaque coin nouveau. Aime explorer : curiosité +50 %%.",
	TRAIT_DESC_glutton     = "Il pense à manger et réclame des en-cas. Aime les repas : faim +50 %%.",
	TRAIT_DESC_daring      = "Il veut toujours se battre, et fête les élites vaincus. Aime l'action : moral +50 %%.",
	TRAIT_DESC_lazy        = "Il bâille, adore les feux de camp et les auberges. Aime se reposer : énergie +50 %%.",
	TRAIT_DESC_teasing     = "Il te taquine sans cesse, surtout quand tu meurs. Aime rire : moral +50 %%.",
	TRAIT_DESC_cuddly      = "Il est tendre et réclame des caresses. Aime l'affection : moral +50 %%.",
	TRAIT_DESC_wise        = "La chouette parle en proverbes et tire une leçon de chaque terre. Aime apprendre : curiosité +50 %%.",
	TRAIT_DESC_parrot      = "L'ara répète tout, deux fois, croâ ! Aime faire la fête : moral +50 %%.",
	TRAIT_DESC_mystic      = "Le feu follet sent les esprits et lit les étoiles la nuit. Aime les mystères : curiosité +50 %%.",
	TRAIT_DESC_zen         = "La tortue respire, ne se presse jamais, t'apaise après un combat. Aime le calme : énergie +50 %%.",
	TRAIT_DESC_sly         = "Le serpent calcule tout et flaire les bonnes affaires. Aime l'or : curiosité +50 %%.",
	TRAIT_DESC_mischievous = "Le dragon féerique fait des farces et met des paillettes partout. Aime jouer : moral +50 %%.",
	TRAIT_DESC_fearful     = "Le poulet sursaute de tout, surveille vos arrières et adore les auberges. Aime être à l'abri : énergie +50 %%.",
	TRAIT_DESC_tinker      = "L'écureuil mécanique démonte, répare et invente tout ce qu'il voit. Aime bricoler : curiosité +50 %%.",
	TRAIT_FORMING        = "Son caractère se dessine en te regardant jouer (%d %%).",
	TRAIT_MSG_FORMED     = "%s a trouvé son caractère : %s. (Réglages, page Caractère.)",
	OPT_PAGE_CHARACTER   = "Caractère",
	OPT_TRAIT_SOURCE     = "Caractère",
	OPT_TRAIT_SOURCE_1   = "Apparence",
	OPT_TRAIT_SOURCE_2   = "Le sien",
	OPT_TRAIT_SOURCE_DESC_1 = "Recommandé : chaque créature capturée a son caractère, et chouette, ara, feu follet, tortue, serpent, dragon féerique, poulet et écureuil mécanique apportent le leur. Les autres gardent le sien.",
	OPT_TRAIT_SOURCE_DESC_2 = "Il garde son caractère quelle que soit son apparence.",
	OPT_TRAIT_PICK       = "Son caractère",
	OPT_TRAIT_NOW        = "Aujourd'hui : %s. %s",
}
local EN = {
	TRAIT_curious        = "Curious",
	TRAIT_glutton        = "Glutton",
	TRAIT_daring         = "Daring",
	TRAIT_lazy           = "Lazy",
	TRAIT_teasing        = "Teasing",
	TRAIT_cuddly         = "Cuddly",
	TRAIT_wise           = "Wise",
	TRAIT_parrot         = "Parrot",
	TRAIT_mystic         = "Mystic",
	TRAIT_zen            = "Zen",
	TRAIT_sly            = "Sly",
	TRAIT_mischievous    = "Mischievous",
	TRAIT_fearful        = "Fearful",
	TRAIT_tinker         = "Tinker",
	TRAIT_NONE           = "Not formed yet",
	TRAIT_AUTO           = "From your play",
	TRAIT_DESC_curious     = "Asks a thousand questions and notices every new spot. Loves exploring: curiosity +50 %%.",
	TRAIT_DESC_glutton     = "Thinks about food and begs for snacks. Loves meals: hunger +50 %%.",
	TRAIT_DESC_daring      = "Always wants a fight, and cheers when elites fall. Loves action: mood +50 %%.",
	TRAIT_DESC_lazy        = "Yawns, adores campfires and inns. Loves resting: energy +50 %%.",
	TRAIT_DESC_teasing     = "Teases you constantly, especially when you die. Loves a laugh: mood +50 %%.",
	TRAIT_DESC_cuddly      = "Tender, and asks for pets. Loves affection: mood +50 %%.",
	TRAIT_DESC_wise        = "The owl speaks in proverbs and draws a lesson from every land. Loves learning: curiosity +50 %%.",
	TRAIT_DESC_parrot      = "The macaw repeats everything, twice, squawk! Loves a party: mood +50 %%.",
	TRAIT_DESC_mystic      = "The wisp senses spirits and reads the stars at night. Loves mysteries: curiosity +50 %%.",
	TRAIT_DESC_zen         = "The tortoise breathes, never hurries, calms you after a fight. Loves calm: energy +50 %%.",
	TRAIT_DESC_sly         = "The snake plans everything and sniffs out good deals. Loves gold: curiosity +50 %%.",
	TRAIT_DESC_mischievous = "The sprite plays pranks and puts sparkles everywhere. Loves to play: mood +50 %%.",
	TRAIT_DESC_fearful     = "The chicken jumps at everything, watches your back and loves inns. Loves being safe: energy +50 %%.",
	TRAIT_DESC_tinker      = "The mechanical squirrel takes apart, fixes and invents everything it sees. Loves tinkering: curiosity +50 %%.",
	TRAIT_FORMING        = "Its character is taking shape as it watches you play (%d %%).",
	TRAIT_MSG_FORMED     = "%s found its character: %s. (Settings, Character page.)",
	OPT_PAGE_CHARACTER   = "Character",
	OPT_TRAIT_SOURCE     = "Character",
	OPT_TRAIT_SOURCE_1   = "Appearance",
	OPT_TRAIT_SOURCE_2   = "Its own",
	OPT_TRAIT_SOURCE_DESC_1 = "Recommended: every captured creature has its own character, and owl, macaw, wisp, tortoise, snake, sprite, chicken and mechanical squirrel bring theirs. Others keep their own.",
	OPT_TRAIT_SOURCE_DESC_2 = "It keeps its own character whatever its appearance.",
	OPT_TRAIT_PICK       = "Its character",
	OPT_TRAIT_NOW        = "Today: %s. %s",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.PERSONALITY_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({
	companionTraitSource = 1,     -- 1 : celui de l'apparence (recommandé), 2 : le sien
	companionTraitPick   = 0,     -- 0 : formé par ton jeu ; sinon PERSONALITY_ORDER[n]
})

-- need : l'envie préférée ; fx : ampleur des mouvements ; exclusive : apparence
local TRAITS = {
	curious     = { need = "curiosity", fx = 1.2 },
	glutton     = { need = "hunger",    fx = 1.0 },
	daring      = { need = "mood",      fx = 1.4 },
	lazy        = { need = "energy",    fx = 0.6 },
	teasing     = { need = "mood",      fx = 1.2 },
	cuddly      = { need = "mood",      fx = 1.0 },
	wise        = { need = "curiosity", fx = 0.7, exclusive = "owl" },
	parrot      = { need = "mood",      fx = 1.3, exclusive = "parrot" },
	mystic      = { need = "curiosity", fx = 0.8, exclusive = "wisp" },
	zen         = { need = "energy",    fx = 0.5, exclusive = "turtle" },
	sly         = { need = "curiosity", fx = 0.9, exclusive = "snake" },
	mischievous = { need = "mood",      fx = 1.5, exclusive = "sprite" },
	fearful     = { need = "energy",    fx = 1.3, exclusive = "chicken" },
	tinker      = { need = "curiosity", fx = 0.9, exclusive = "squirrel_mech" },
}
ns.PERSONALITY_TRAITS = TRAITS
local ORDER = { "curious", "glutton", "daring", "lazy", "teasing", "cuddly", "wise", "parrot", "mystic", "zen", "sly", "mischievous",
	"fearful", "tinker" }
ns.PERSONALITY_ORDER = ORDER
local FORMED = { "curious", "glutton", "daring", "lazy", "teasing", "cuddly" }
ns.PERSONALITY_FORMED = FORMED
local BY_APPEARANCE = {}
for id, def in pairs(TRAITS) do if def.exclusive then BY_APPEARANCE[def.exclusive] = id end end
ns.PERSONALITY_BY_APPEARANCE = BY_APPEARANCE

ns.PERSONALITY_FORM_AFTER = 3 * 3600     -- s de jeu observées avant d'annoncer son caractère
ns.PERSONALITY_VARIANT_CHANCE = 0.75     -- part de ses propres répliques quand il en a
ns.PERSONALITY_GAIN = 1.5                -- envie préférée : gains
ns.PERSONALITY_DECAY = 0.7               -- envie préférée : baisse
ns.PERSONALITY_NOTICE_GAP = 900          -- s entre deux remarques de caractère
-- ce que chaque façon de jouer pèse
ns.PERSONALITY_SCORES = { curiosity = 0.1, meal = 3, kill = 0.15, elite = 2, restMinute = 0.25, death = 6, pet = 2 }

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end
local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end

-- ---------------------------------------------------------------------------
-- État : scores, temps observé, caractère formé, caractères d'apparence portés
-- ---------------------------------------------------------------------------
function ns:PersonaData()
	local data = self:CompanionData()
	local persona = data.persona
	if type(persona) ~= "table" then
		persona = {}
		data.persona = persona
	end
	if type(persona.scores) ~= "table" then persona.scores = {} end
	if type(persona.unlocked) ~= "table" then persona.unlocked = {} end
	persona.played = tonumber(persona.played) or 0
	if persona.formed and not TRAITS[persona.formed] then persona.formed = nil end
	return persona
end

function ns:PersonaScore(trait, amount)
	local persona = self:PersonaData()
	if persona.formed then return end
	persona.scores[trait] = (tonumber(persona.scores[trait]) or 0) + (tonumber(amount) or 0)
end

-- Le caractère qui parle : celui de l'apparence (si réglé et si elle en a
-- un), sinon celui choisi dans les réglages, sinon celui formé ; nil avant
function ns:CompanionTrait()
	local persona = self:PersonaData()
	local db = self:DB()
	local fromLook = BY_APPEARANCE[tostring(self:CompanionData().appearance)]
	if fromLook then persona.unlocked[fromLook] = true end
	if fromLook and (tonumber(db.companionTraitSource) or 1) == 1 then return fromLook end
	local pick = ORDER[tonumber(db.companionTraitPick) or 0]
	if pick and self:PersonaAvailable(pick) then return pick end
	return persona.formed
end

function ns:PersonaAvailable(trait)
	local def = TRAITS[trait]
	if not def then return false end
	return not def.exclusive or self:PersonaData().unlocked[trait] == true
end

function ns:PersonaLabel(trait)
	if not trait then return L.TRAIT_NONE end
	return L["TRAIT_" .. trait]
end

-- Le caractère se forme : le score le plus haut (à égalité, l'ordre de FORMED)
function ns:PersonaForm()
	local persona = self:PersonaData()
	if persona.formed then return persona.formed end
	local best, bestScore = FORMED[1], -1
	for _, trait in ipairs(FORMED) do
		local score = tonumber(persona.scores[trait]) or 0
		if score > bestScore then best, bestScore = trait, score end
	end
	persona.formed = best
	self:Print(self:F("TRAIT_MSG_FORMED", self:CompanionName(), self:PersonaLabel(best)))
	self:CompanionSay("FORMED__" .. best, { force = true, category = "event" })
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return best
end

-- ---------------------------------------------------------------------------
-- Effets : répliques, goûts, mouvements
-- ---------------------------------------------------------------------------
local function Wrap(name, fn)
	local original = ns[name]
	if type(original) ~= "function" then return end
	ns[name] = function(self, ...) return fn(original, self, ...) end
end

-- ses propres versions d'une réplique, le plus souvent
Wrap("CompanionPick", function(original, self, pool, args, list)
	if not list and type(pool) == "string" then
		local trait = self:CompanionTrait()
		local variant = trait and (pool .. "__" .. trait)
		if variant and ns.COMPANION_POOLS[variant] and math.random() < ns.PERSONALITY_VARIANT_CHANCE then
			local key = original(self, variant, args)
			if key then return key end
		end
	end
	return original(self, pool, args, list)
end)

-- l'envie préférée monte plus vite ; et ce qui remplit ses envies forme son caractère
Wrap("CompanionAdd", function(original, self, key, amount)
	amount = tonumber(amount) or 0
	if amount > 0 then
		local trait = self:CompanionTrait()
		if trait and TRAITS[trait].need == key then amount = amount * ns.PERSONALITY_GAIN end
		if key == "curiosity" then self:PersonaScore("curious", amount * ns.PERSONALITY_SCORES.curiosity) end
	end
	return original(self, key, amount)
end)

-- l'envie préférée baisse moins vite (CompanionTick)
function ns:CompanionDecayFactor(key)
	local trait = self:CompanionTrait()
	if trait and TRAITS[trait].need == key then return ns.PERSONALITY_DECAY end
	return 1
end

-- ampleur des mouvements (CompanionFx)
function ns:CompanionFxIntensity()
	local trait = self:CompanionTrait()
	return trait and TRAITS[trait].fx or 1
end

-- dans l'infobulle du compagnon : son caractère
Wrap("CompanionRefreshHover", function(original, self, ...)
	local result = original(self, ...)
	local hover = self.companionHover
	if hover and hover.sub and hover.sub.GetText then
		local trait = self:CompanionTrait()
		if trait then hover.sub:SetText(tostring(hover.sub:GetText() or "") .. " · " .. self:PersonaLabel(trait)) end
		-- la ligne a pu s'allonger : on replace la suite en dessous
		if self.CompanionLayoutHover then self:CompanionLayoutHover() end
	end
	return result
end)

-- ---------------------------------------------------------------------------
-- Observation (avant qu'il soit formé) et remarques (après)
-- ---------------------------------------------------------------------------
function ns:PersonaState()
	local state = self.personaState
	if not state then
		state = { lastRest = Clock(), started = Clock() }
		self.personaState = state
	end
	return state
end

-- Une remarque de caractère ; renvoie true si elle est partie. `reaction` :
-- elle répond au moment même (élite, mort, terre nouvelle) et prend la place
-- de la bulle ordinaire de ce moment
function ns:PersonaNotice(trait, args, reaction)
	if not trait or self:CompanionTrait() ~= trait then return false end
	local state = self:PersonaState()
	local now = Clock()
	if state.noticeAt and now - state.noticeAt < ns.PERSONALITY_NOTICE_GAP then return false end
	local said = self:CompanionSay("NOTICE__" .. trait,
		{ category = reaction and "reaction" or "chatter", force = true, args = args })
	if said then state.noticeAt = now end
	return said and true or false
end

Wrap("CompanionPet", function(original, self, ...)
	local petted = original(self, ...)
	if petted == true then self:PersonaScore("cuddly", ns.PERSONALITY_SCORES.pet) end
	self:PersonaState().lastPet = Clock()
	return petted
end)

Wrap("CompanionCheckAuras", function(original, self, ...)
	local wasEating = self.companionEating
	local a, b = original(self, ...)
	if self.companionEating and not wasEating then self:PersonaScore("glutton", ns.PERSONALITY_SCORES.meal) end
	return a, b
end)

Wrap("CompanionOnKill", function(original, self, ...)
	local rt = self.companionRT
	local before = rt and rt.lastKill
	local a = original(self, ...)
	rt = self.companionRT
	if rt and rt.lastKill ~= before then self:PersonaScore("daring", ns.PERSONALITY_SCORES.kill) end
	return a
end)

Wrap("CompanionEliteKilled", function(original, self, ...)
	local elite = original(self, ...)
	if elite then
		self:PersonaScore("daring", ns.PERSONALITY_SCORES.elite)
		self:PersonaNotice("daring", nil, true)
	end
	return elite
end)

Wrap("CompanionOnDead", function(original, self, ...)
	local a = original(self, ...)
	self:PersonaScore("teasing", ns.PERSONALITY_SCORES.death)
	local state, now = self:PersonaState(), Clock()
	if state.lastDeath and now - state.lastDeath <= 600 then self:PersonaNotice("teasing", nil, true) end
	state.lastDeath = now
	return a
end)

Wrap("CompanionOnZone", function(original, self, newArea, ...)
	local data = self:CompanionData()
	local mapID = self.CurrentMap and self:CurrentMap()
	local sub = self.CurrentSubZone and self:CurrentSubZone()
	local newZone = newArea and mapID and not data.seenZones[mapID]
	local subKey = (not newArea and mapID and sub) and (tostring(mapID) .. ":" .. sub) or nil
	local newSub = subKey and not data.seenSub[subKey]
	local a = original(self, newArea, ...)
	if newSub then self:PersonaNotice("curious") end
	if newZone then self:PersonaNotice("wise", nil, true) end
	if newArea and mapID then
		local info = self.MapInfo and self:MapInfo(mapID)
		if info and info.name then self:PersonaNotice("parrot", { info.name, info.name }) end
	end
	return a
end)

-- Au fil du temps : temps observé, repos, et remarques qui dépendent de l'heure
Wrap("CompanionTick", function(original, self, seconds, ...)
	local a = original(self, seconds, ...)
	if not (self.CompanionOn and self.CompanionOn()) then return a end
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then return a end
	local persona, state, now = self:PersonaData(), self:PersonaState(), Clock()
	local resting = self.CompanionResting and self:CompanionResting()
	if resting then state.lastRest = now end
	if not persona.formed then
		persona.played = persona.played + seconds
		if resting then self:PersonaScore("lazy", seconds / 60 * ns.PERSONALITY_SCORES.restMinute) end
		if persona.played >= ns.PERSONALITY_FORM_AFTER then self:PersonaForm() end
		return a
	end
	self:PersonaTickNotice(now, state)
	return a
end)

function ns:PersonaTickNotice(now, state)
	local trait = self:CompanionTrait()
	if not trait then return false end
	local data = self:CompanionData()
	if trait == "glutton" then
		if (tonumber(data.needs.hunger) or 100) < 60 then return self:PersonaNotice("glutton") end
	elseif trait == "lazy" then
		if now - (state.lastRest or now) >= 2400 then return self:PersonaNotice("lazy") end
	elseif trait == "cuddly" then
		if now - (state.lastPet or state.started or now) >= 1200 then return self:PersonaNotice("cuddly") end
	elseif trait == "mystic" then
		local hour = tonumber((Call(G("GetGameTime")))) or 12
		if hour >= 21 or hour < 5 then
			if not state.nightSeen then
				local said = self:PersonaNotice("mystic")
				if said then state.nightSeen = true end
				return said
			end
		else
			state.nightSeen = nil
		end
	elseif trait == "zen" then
		-- vie secrète (Forever) : 1/1, il ne remarque rien
		local health = tonumber(ns.Plain(Call(G("UnitHealth"), "player"))) or 1
		local max = tonumber(ns.Plain(Call(G("UnitHealthMax"), "player"))) or 1
		local fighting = Call(G("UnitAffectingCombat"), "player") == true
		if max > 0 and health / max < 0.5 and not fighting then return self:PersonaNotice("zen") end
	elseif trait == "sly" then
		local money = tonumber(Call(G("GetMoney"))) or 0
		state.money = state.money or money
		if money - state.money >= 10000 then
			local said = self:PersonaNotice("sly")
			if said then state.money = money end
			return said
		end
		if money < state.money then state.money = money end
	elseif trait == "fearful" then
		-- ça tape fort : il voudrait souffler (une fois par combat difficile)
		local health = tonumber(ns.Plain(Call(G("UnitHealth"), "player"))) or 1
		local max = tonumber(ns.Plain(Call(G("UnitHealthMax"), "player"))) or 1
		local fighting = Call(G("UnitAffectingCombat"), "player") == true
		if fighting and max > 0 and health / max < 0.6 then
			if not state.scared then
				local said = self:PersonaNotice("fearful")
				if said then state.scared = true end
				return said
			end
		elseif not fighting then
			state.scared = nil
		end
	elseif trait == "tinker" then
		if now - (state.tinkerAt or state.started or now) >= 1200 then
			local said = self:PersonaNotice("tinker")
			if said then state.tinkerAt = now end
			return said
		end
	elseif trait == "mischievous" then
		if now - (state.prankAt or state.started or now) >= 1200 then
			local said = self:PersonaNotice("mischievous")
			if said then state.prankAt = now end
			return said
		end
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Réglages : page « Caractère »
-- ---------------------------------------------------------------------------
function ns:PersonaDescribe()
	local trait = self:CompanionTrait()
	if not trait then
		local persona = self:PersonaData()
		return self:F("TRAIT_FORMING", math.floor(100 * persona.played / ns.PERSONALITY_FORM_AFTER))
	end
	return self:F("OPT_TRAIT_NOW", self:PersonaLabel(trait), self:F("TRAIT_DESC_" .. trait))
end

-- « + » ou « - » sur la réglette : saute les caractères d'apparence pas encore portés
function ns:PersonaPickChanged(value, before)
	local db = self:DB()
	local step = (tonumber(value) or 0) >= (tonumber(before) or 0) and 1 or -1
	local index = tonumber(value) or 0
	while index > 0 and index <= #ORDER and not self:PersonaAvailable(ORDER[index]) do index = index + step end
	if index > #ORDER then index = tonumber(before) or 0 end
	if index < 0 then index = 0 end
	db.companionTraitPick = index
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
end

if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "companionCharacter", title = "OPT_PAGE_CHARACTER", parent = "companion", group = "OPT_GROUP_MODULES",
		rows = {
			{ key = "companionTraitSource", label = "OPT_TRAIT_SOURCE", kind = "number", min = 1, max = 2, step = 1,
				display = function(value) return L["OPT_TRAIT_SOURCE_" .. value] end,
				describe = function(value) return L["OPT_TRAIT_SOURCE_DESC_" .. value] end,
				onChange = function() if ns.RefreshOptions then ns:RefreshOptions() end end },
			{ key = "companionTraitPick", label = "OPT_TRAIT_PICK", kind = "number", min = 0, max = #ORDER, step = 1,
				display = function(value)
					local trait = ORDER[value]
					return trait and ns:PersonaLabel(trait) or L.TRAIT_AUTO
				end,
				describe = function() return ns:PersonaDescribe() end,
				onChange = function(value, before) ns:PersonaPickChanged(value, before) end },
		},
	})
end

if ns.Mark then ns.Mark("Personality") end
