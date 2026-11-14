-- Advice.lua -- conseils de route du compagnon (QuestCompanion)
--
-- Pendant une sortie (hors d'un lieu sûr), le compagnon prévient de ce qui
-- compte vraiment, dans cet ordre de priorité :
--   elite      élite ou rare hostile, au moins 2 niveaux au-dessus (hors donjon)
--   health     vie basse à la fin d'un combat
--   ammo       munitions basses, à sec, ou pas équipées (chasseur)
--   food       vivres bas loin d'un lieu sûr
--   durability équipement qui s'abîme (sous le seuil, puis sous 10 %)
--   bags       sacs presque pleins (seuil, puis 1 place)
--   quests     toutes les quêtes du journal prêtes à rendre
--   hearth     pierre de foyer de nouveau prête, alors qu'on est chargé
-- Une fois par sortie et par situation, sauf si elle empire (palier 2) ; jamais
-- en combat ; au plus un conseil par écart de la réglette « Bavardage »
-- (catégorie « advice » de CompanionSay). Les conseils importants (élite,
-- vie, munitions, vivres) passent aussi au cran « Discret ».
--
-- Fonctionne seul (lectures du socle commun, Libs/Socle/Gear.lua et
-- World.lua). Avec Ready2Quest, mêmes seuils que son check (place dans les
-- sacs, vivres, durabilité) et même idée de « lieu sûr ».
local ADDON, ns = ...
if ns.blocked then return end

ns.ADVICE_ORDER = { "elite", "health", "ammo", "food", "durability", "bags", "quests", "hearth" }
ns.ADVICE_IMPORTANT = { elite = true, health = true, ammo = true, food = true }
ns.ADVICE_POLL = 3            -- s entre deux examens
ns.ADVICE_HEALTH = 0.35       -- vie basse : sous 35 % à la fin d'un combat
ns.ADVICE_ELITE_LEVELS = 2    -- élite ou rare : au moins 2 niveaux au-dessus
local ELITE_CLASSES = { elite = true, rareelite = true, rare = true, worldboss = true }

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local function InCombat()
	return Call(rawget(_G, "InCombatLockdown")) == true or Call(rawget(_G, "UnitAffectingCombat"), "player") == true
end

-- Ready2Quest installé (lien de Core.lua) : sa sauvegarde, pour ses seuils
local function R2Q()
	local r2q = ns.r2qBridge
	if type(r2q) == "table" and type(r2q.DB) == "function" then return r2q end
	return nil
end

-- Seuils : ceux du check de Ready2Quest s'il est là, sinon les nôtres
function ns:AdviceThresholds()
	local r2q, db = R2Q(), nil
	if r2q then
		local ok, value = pcall(r2q.DB, r2q)
		if ok and type(value) == "table" then db = value end
	end
	db = db or {}
	return {
		bags = tonumber(db.bagFreeThreshold) or 3,
		food = math.max(4, tonumber(db.vivresThreshold) or 0),
		durability = tonumber(db.durabilityMinPct) or 25,
	}
end

-- Lieu sûr : celui de Ready2Quest s'il est là, sinon repos, lieux connus
-- (Hubs.lua), lieux repérés (Places.lua) ou sanctuaire
function ns:AdviceInSafePlace()
	local r2q = R2Q()
	if r2q and type(r2q.IsCurrentZoneSafe) == "function" then
		local ok, safe = pcall(r2q.IsCurrentZoneSafe, r2q)
		if ok then return safe == true end
	end
	if self:InInstance() then return false end
	if Call(rawget(_G, "IsResting")) then return true end
	if Call(rawget(_G, "UnitIsPVPSanctuary"), "player") then return true end
	if self.AtCamp and self:AtCamp() then return true end
	if self:KnownHub() then return true end
	return self.KnownPlace and self:KnownPlace() ~= nil or false
end

-- ---------------------------------------------------------------------------
-- État de la sortie : ce qui a déjà été dit (palier par situation)
-- ---------------------------------------------------------------------------
function ns:AdviceState()
	local state = self.adviceState
	if not state then
		state = { said = {}, elites = {}, pending = {} }
		self.adviceState = state
	end
	return state
end

function ns:AdviceNewTrip()
	local state = self:AdviceState()
	state.said, state.hearthWasCooling, state.health = {}, nil, nil
end

-- ---------------------------------------------------------------------------
-- Situations : chacune renvoie { stage, pool, args } ou nil
-- ---------------------------------------------------------------------------
local RULES = {}

function RULES.elite(self, state)
	local seen = state.elite
	if not seen then return nil end
	return { stage = 1, pool = seen.rare and "ADVICE_RARE" or "ADVICE_ELITE", args = { seen.name }, key = "elite:" .. seen.guid }
end

function RULES.health(self, state)
	if not state.health then return nil end
	return { stage = 1, pool = "ADVICE_HEALTH", key = "health:" .. state.health }
end

function RULES.ammo(self)
	if self.PlayerClassToken() ~= "HUNTER" then return nil end
	local have = self.AmmoCount()
	if have == nil then return nil end
	local minimum = self.ReagentMinimum(self.AMMO_MINIMUM, self.PlayerLevelNow())
	if have == 0 then
		local stored = self.AmmoInBags()
		if stored > 0 then return { stage = 3, pool = "ADVICE_AMMO_UNEQUIPPED", args = { stored } } end
	end
	if have < minimum / 2 then return { stage = 2, pool = "ADVICE_AMMO_EMPTY", args = { have } } end
	if have < minimum then return { stage = 1, pool = "ADVICE_AMMO", args = { have } } end
	return nil
end

function RULES.food(self, state, limits)
	local count = self.CountConsumables("food")
	if count == 0 then return { stage = 2, pool = "ADVICE_FOOD_EMPTY" } end
	if count < limits.food then return { stage = 1, pool = "ADVICE_FOOD", args = { count } } end
	return nil
end

function RULES.durability(self, state, limits)
	local worst = self:LowestDurability()
	if not worst then return nil end
	local percent = math.floor(worst)
	if percent < 10 then return { stage = 2, pool = "ADVICE_DURA_CRIT", args = { percent } } end
	if percent < limits.durability then return { stage = 1, pool = "ADVICE_DURA", args = { percent } } end
	return nil
end

function RULES.bags(self, state, limits)
	local free = self.FreeBagSlots()
	if free <= 1 then return { stage = 2, pool = free == 0 and "ADVICE_BAGS_FULL" or "ADVICE_BAGS_LAST" } end
	if free <= limits.bags then return { stage = 1, pool = "ADVICE_BAGS", args = { free } } end
	return nil
end

function RULES.quests(self)
	local total, ready = self:QuestCounts()
	if total and total > 0 and ready == total then return { stage = 1, pool = "ADVICE_QUESTS" } end
	return nil
end

-- foyer : seulement s'il vient de se recharger pendant la sortie, et qu'on est
-- « chargé » (sacs presque pleins ou équipement abîmé)
function RULES.hearth(self, state, limits)
	local cooling = (self.HearthCooldown() or 0) > 0
	local wasCooling = state.hearthWasCooling
	state.hearthWasCooling = cooling
	if cooling or not wasCooling then return nil end
	local worst = self:LowestDurability() or 100
	if self.FreeBagSlots() <= limits.bags + 2 or worst < 40 then return { stage = 1, pool = "ADVICE_HEARTH" } end
	return nil
end
ns.ADVICE_RULES = RULES

-- ---------------------------------------------------------------------------
-- Examen : la situation la plus importante qui n'a pas encore été dite
-- ---------------------------------------------------------------------------
-- Renvoie le nom de la situation dite, ou nil.
function ns:AdviceEvaluate()
	if not (self.CompanionOn and self.CompanionOn()) then return nil end
	if InCombat() then return nil end
	local state = self:AdviceState()
	if self:AdviceInSafePlace() then
		self:AdviceNewTrip()
		state.elite = nil
		return nil
	end
	local limits = self:AdviceThresholds()
	for _, name in ipairs(self.ADVICE_ORDER) do
		local ok, found = pcall(RULES[name], self, state, limits)
		if ok and found then
			local key = found.key or name
			if (state.said[key] or 0) < found.stage then
				local said, why = self:CompanionSay(found.pool, { category = "advice",
					important = self.ADVICE_IMPORTANT[name], args = found.args })
				if said then
					state.said[key] = found.stage
					if name == "elite" then state.elite = nil end
					if name == "health" then state.health = nil end
					return name
				end
				-- trop tôt (écart, autre bulle) : on réessaiera ; filtré par le
				-- cran de la réglette : on passe à la suivante
				if why == "busy" then return nil end
			end
		elseif not ok and self.RecordError then
			self:RecordError("advice:" .. name, found)
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Élites et rares : ce que le client voit déjà (cible, survol, barres de vie)
-- ---------------------------------------------------------------------------
function ns:AdviceSeeUnit(unit)
	if not unit or self:InInstance() then return false end
	-- en combat, le prévenir ne sert plus (et la bulle tomberait après, sur un cadavre)
	if InCombat() then return false end
	if not Call(rawget(_G, "UnitExists"), unit) or Call(rawget(_G, "UnitIsDead"), unit) then return false end
	if not Call(rawget(_G, "UnitCanAttack"), "player", unit) then return false end
	local class = ns.Plain(Call(rawget(_G, "UnitClassification"), unit))
	if not ELITE_CLASSES[class or ""] then return false end
	local level = tonumber(ns.Plain(Call(rawget(_G, "UnitLevel"), unit))) or 0
	local mine = self.PlayerLevelNow()
	-- -1 : « ?? », bien au-dessus
	if level ~= -1 and level < mine + self.ADVICE_ELITE_LEVELS then return false end
	local guid = ns.Plain(Call(rawget(_G, "UnitGUID"), unit)) or tostring(ns.Plain(Call(rawget(_G, "UnitName"), unit)))
	local state = self:AdviceState()
	if state.elites[guid] then return false end
	-- bornée : une longue session croise des milliers d'élites ; au-delà de
	-- ADVICE_ELITES_MAX, on repart d'une liste vide
	state.eliteCount = (state.eliteCount or 0) + 1
	if state.eliteCount > ns.ADVICE_ELITES_MAX then state.elites, state.eliteCount = {}, 1 end
	state.elites[guid] = true
	state.elite = { guid = guid, name = ns.Plain(Call(rawget(_G, "UnitName"), unit)) or "?",
		rare = class == "rare" or class == "rareelite" }
	self:AdviceEvaluate()
	return true
end

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
-- Événements en rafales (QUEST_LOG_UPDATE plusieurs fois par butin ou
-- objectif, sacs, zones) : ils avancent l'examen régulier à ADVICE_SOON au
-- lieu d'examiner tout à chaque fois. Une rafale = un seul examen.
ns.ADVICE_SOON = 0.3
ns.ADVICE_ELITES_MAX = 500
local function Soon()
	local at = ns.Now() + ns.ADVICE_SOON
	if (ns.adviceNextAt or 0) > at then ns.adviceNextAt = at end
end

local HANDLERS = {
	PLAYER_TARGET_CHANGED = function() ns:AdviceSeeUnit("target") end,
	UPDATE_MOUSEOVER_UNIT = function() ns:AdviceSeeUnit("mouseover") end,
	NAME_PLATE_UNIT_ADDED = function(unit) ns:AdviceSeeUnit(unit) end,
	PLAYER_REGEN_ENABLED = function()
		-- secrètes sur le moteur récent (Forever) : on ne sait pas, on ne dit rien
		local health = ns.Plain(Call(rawget(_G, "UnitHealth"), "player"))
		local maximum = ns.Plain(Call(rawget(_G, "UnitHealthMax"), "player"))
		if tonumber(health) and tonumber(maximum) and maximum > 0 and health / maximum < ns.ADVICE_HEALTH
			and not Call(rawget(_G, "UnitIsDeadOrGhost"), "player") then
			ns:AdviceState().health = math.floor(ns.Now())
		end
		ns:AdviceEvaluate()
	end,
	BAG_UPDATE_DELAYED = Soon,
	UPDATE_INVENTORY_DURABILITY = Soon,
	QUEST_LOG_UPDATE = Soon,
	ZONE_CHANGED = Soon,
	ZONE_CHANGED_NEW_AREA = Soon,
}
ns.ADVICE_HANDLERS = HANDLERS

local ok, frame = pcall(CreateFrame, "Frame")
if ok and frame then
	for event in pairs(HANDLERS) do pcall(frame.RegisterEvent, frame, event) end
	frame:SetScript("OnEvent", function(_, event, ...)
		local done, err = pcall(HANDLERS[event], ...)
		if not done then ns:RecordError("advice:" .. event, err) end
	end)
	-- examen régulier : ce qui change sans événement (foyer, munitions…).
	-- 2.11.2 (fiche 25) : regardé dix fois par seconde sur l'horloge de
	-- l'addon (l'échéance reste ns.adviceNextAt), plus d'OnUpdate permanent
	ns.Every("advice", ns.CLOCK_POLL, function()
		local now = ns.Now()
		if (ns.adviceNextAt or 0) > now then return end
		ns.adviceNextAt = now + ns.ADVICE_POLL
		local done, err = pcall(ns.AdviceEvaluate, ns)
		if not done then ns:RecordError("advice:poll", err) end
	end)
	ns.adviceEventFrame = frame
end

if ns.Mark then ns.Mark("Advice") end
