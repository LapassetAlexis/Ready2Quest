-- AggroPlus.lua -- « Portée d'aggro » : plus précis (1.36.0)
--
-- Trois ajouts au module Aggro.lua, sans changer son affichage :
--   * paliers de distance tirés des sorts du joueur : un sort offensif de
--     portée connue (5 à 60 m, sans portée minimale) répond « à portée ou
--     non » sur une unité hostile, hors combat, comme les objets de mesure ;
--     un sort par portée, relus quand le grimoire change ;
--   * distance estimée entre deux paliers : quand la fourchette change, le
--     joueur vient de franchir un palier (on sait où il est) ; ensuite, tant
--     qu'il avance sans tourner, l'estimation suit sa vitesse de course
--     (prudente : la moitié, le monstre peut bouger), bornée à la fourchette.
--     « sûre » une fois un palier franchi, sinon Aggro.lua garde la borne basse ;
--   * portée apprise en jouant : quand un monstre t'attaque alors que tu n'as
--     rien fait depuis 3 s (ni sort, ni attaque, seul, sans familier en
--     combat), la distance estimée juste avant est un échantillon de sa vraie
--     portée, ramené au même niveau (+1 m par niveau d'écart). 20 échantillons
--     au plus par nom de monstre, par type et rang, par type, et en tout. La
--     portée apprise (le 65e centile : on prévient un peu tôt plutôt que tard)
--     remplace l'estimation : 2 échantillons pour un nom, 3 sinon. Réglage
--     « Apprendre la portée en jouant » (activé), données dans la sauvegarde
--     du compte (db.aggroLearnData).
-- Tout est sous pcall et valeurs « secrètes » ignorées (ns.Plain) : le client
-- de Forever peut refuser une mesure, surtout en combat.
local ADDON, ns = ...
if not ns.AggroDistance then return end

ns.AGGRO_APPROACH = 0.5       -- part de la vitesse de course comptée vers le monstre
ns.AGGRO_TURN = 0.6           -- radians : au-delà, le joueur a tourné, on ne compte plus
ns.AGGRO_TRACK_TTL = 3        -- s : piste oubliée sans mesure depuis
ns.AGGRO_LEARN_MAX = 20       -- échantillons gardés par clé
ns.AGGRO_LEARN_CAUTIOUS = 0.65
ns.AGGRO_LEARN_QUIET = 3      -- s sans action du joueur avant l'attaque
ns.AGGRO_LEARN_FRESH = 1      -- s : âge maximal de l'estimation retenue
ns.AGGRO_SPELL_MIN, ns.AGGRO_SPELL_MAX = 5, 60

local function Num(value) return tonumber(ns.Plain(value)) end
local function Global(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f = pcall(fn, ...)
	if not ok then return nil end
	return ns.Plain(a), ns.Plain(b), ns.Plain(c), ns.Plain(d), ns.Plain(e), ns.Plain(f)
end
local function Now() return (ns.Now and ns.Now()) or 0 end
local function Spell(name)
	local api = Global("C_Spell")
	if type(api) == "table" and type(api[name]) == "function" then return api[name] end
	return nil
end

-- ---------------------------------------------------------------------------
-- Paliers des sorts
-- ---------------------------------------------------------------------------
-- portées min et max d'un sort (C_Spell.GetSpellInfo, sinon GetSpellInfo)
function ns.AggroSpellRange(spellID)
	local info = Call(Spell("GetSpellInfo"), spellID)
	if type(info) == "table" then return Num(info.minRange) or 0, Num(info.maxRange) end
	local _, _, _, _, minRange, maxRange = Call(Global("GetSpellInfo"), spellID)
	return Num(minRange) or 0, Num(maxRange)
end

-- à portée (true / false) ou nil (le client ne répond pas : sort d'aide…)
local function SpellInRange(spellID, name, unit)
	local fn = Spell("IsSpellInRange")
	local result
	if fn then
		result = Call(fn, spellID, unit)
	elseif name and Global("IsSpellInRange") then
		result = Call(Global("IsSpellInRange"), name, unit)
	end
	if result == nil then return nil end
	return result == true or result == 1
end

-- 1.38.0 : les sorts « au prochain coup » (Frappe héroïque, Enchaînement,
-- Attaque du raptor, Mutiler) répondent « à portée » à 30 m : jamais une règle.
-- Constat de DoesItDiePlus (Ironship, GPL-3.0, Modules/Range/Range.lua).
ns.AGGRO_NEXT_SWING = { 78, 845, 2973, 6807 }
local function SpellName(id)
	local info = Call(Spell("GetSpellInfo"), id)
	if type(info) == "table" then return info.name end
	return (Call(Global("GetSpellInfo"), id))
end
function ns.AggroNextSwingNames()
	local names = {}
	for _, id in ipairs(ns.AGGRO_NEXT_SWING) do
		local name = SpellName(id)
		if type(name) == "string" and name ~= "" then names[name] = true end
	end
	return names
end

function ns:AggroSpellSteps()
	if self.aggroSpellSteps then return self.aggroSpellSteps end
	local skip = ns.AggroNextSwingNames()
	local book = {}
	if self.NewSpellsBook then
		local ok, value = pcall(self.NewSpellsBook, self)
		if ok and type(value) == "table" then book = value end
	end
	local steps, seen = {}, {}
	for name, info in pairs(book) do
		local id = type(info) == "table" and info.id
		if id and not skip[name] then
			local minRange, maxRange = ns.AggroSpellRange(id)
			if maxRange and (minRange or 0) == 0 and maxRange >= ns.AGGRO_SPELL_MIN and maxRange <= ns.AGGRO_SPELL_MAX
				and not seen[maxRange] then
				seen[maxRange] = true
				steps[#steps + 1] = { range = maxRange, spell = id,
					test = function(unit) return SpellInRange(id, name, unit) end }
			end
		end
	end
	table.sort(steps, function(a, b) return a.range < b.range end)
	self.aggroSpellSteps = steps
	return steps
end

-- le grimoire a changé : paliers relus, mesures oubliées
function ns:AggroSpellsChanged()
	self.aggroSpellSteps, self.aggroLadder, self.aggroDistCache = nil, nil, nil
end

-- ---------------------------------------------------------------------------
-- Distance estimée entre deux paliers
-- ---------------------------------------------------------------------------
local function Facing() return Num((Call(Global("GetPlayerFacing")))) end
local function Turned(a, b)
	if not (a and b) then return false end
	local diff = math.abs(a - b) % (2 * math.pi)
	if diff > math.pi then diff = 2 * math.pi - diff end
	return diff > ns.AGGRO_TURN
end
local function Guid(unit) return ns.Plain((Call(Global("UnitGUID"), unit))) end

-- est (yards) et sure (un palier a été franchi), ou nil
function ns:AggroTrack(unit, low, high, playerLevel, mobLevel)
	low, high = Num(low), Num(high)
	self.aggroTracks = self.aggroTracks or {}
	local tracks = self.aggroTracks
	if not high then tracks[unit] = nil; return nil end   -- au-delà du dernier palier, ou rien
	low = low or 0
	local now, guid = Now(), Guid(unit)
	-- sans GUID lisible, on ne sait pas si c'est le même monstre (« mouseover »
	-- change de cible) : pas de piste
	if not guid then tracks[unit] = nil; return nil end
	local tr = tracks[unit]
	if not tr or tr.guid ~= guid or now - tr.t > ns.AGGRO_TRACK_TTL then
		tr = { guid = guid, low = low, high = high, est = (low + high) / 2, t = now, face = Facing() }
		tracks[unit] = tr
	else
		local dt = now - tr.t
		tr.t = now
		if low ~= tr.low or high ~= tr.high then
			-- un palier franchi : vers le monstre, on est sur la nouvelle borne
			-- haute ; en s'éloignant, sur la nouvelle borne basse
			if high < tr.high or low < tr.low then tr.est, tr.dir = high, -1
			else tr.est, tr.dir = low, 1 end
			tr.sure, tr.low, tr.high, tr.face = true, low, high, Facing()
		elseif tr.dir and dt > 0 then
			local speed = Num((Call(Global("GetUnitSpeed"), "player"))) or 0
			local face = Facing()
			if speed > 0 and not Turned(face, tr.face) then
				tr.est = tr.est + tr.dir * speed * ns.AGGRO_APPROACH * dt
			elseif speed > 0 then
				tr.dir = nil   -- il a tourné : on tient l'estimation jusqu'au palier suivant
			end
		end
	end
	if high - low > 1 then tr.est = math.max(low + 0.5, math.min(high - 0.5, tr.est)) end
	-- pour l'apprentissage : qui, à quel niveau
	tr.pl, tr.ml = Num(playerLevel), Num(mobLevel)
	if not tr.name then
		tr.name = ns.Plain((Call(Global("UnitName"), unit)))
		tr.ctype = ns.Plain((Call(Global("UnitCreatureType"), unit)))
		tr.class = ns.Plain((Call(Global("UnitClassification"), unit)))
	end
	return tr.est, tr.sure == true
end

-- ---------------------------------------------------------------------------
-- Portée apprise
-- ---------------------------------------------------------------------------
local function LearnData(self, create)
	local db = self:DB()
	if type(db.aggroLearnData) ~= "table" then
		if not create then return nil end
		db.aggroLearnData = { byName = {}, byType = {}, global = {} }
	end
	local data = db.aggroLearnData
	data.byName, data.byType, data.global = data.byName or {}, data.byType or {}, data.global or {}
	return data
end

local function Quantile(list, q)
	local sorted = {}
	for i, v in ipairs(list) do sorted[i] = v end
	table.sort(sorted)
	local n = #sorted
	if n == 0 then return nil end
	local pos = 1 + (n - 1) * q
	local lo = math.floor(pos)
	local hi = math.min(n, lo + 1)
	return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo)
end
ns.AggroQuantile = Quantile

local function ClassOf(classification)
	if classification == "elite" or classification == "rareelite" or classification == "worldboss" then return "elite" end
	if classification == "rare" then return "rare" end
	if classification == "trivial" or classification == "minus" then return "minor" end
	return "normal"
end

local function Push(list, value)
	list[#list + 1] = value
	while #list > ns.AGGRO_LEARN_MAX do table.remove(list, 1) end
end

-- La liste qui fait foi pour un monstre : son nom (2+), son type et rang (3+),
-- son type (3+), tout (3+) ; nil sinon
function ns:AggroLearnedList(name, ctype, class)
	local data = LearnData(self)
	if not data then return nil end
	local list = name and data.byName[name]
	if list and #list >= 2 then return list, "name" end
	local rank = ClassOf(class)
	list = ctype and data.byType[ctype .. "|" .. rank]
	if list and #list >= 3 then return list, "type+class" end
	list = ctype and data.byType[ctype]
	if list and #list >= 3 then return list, "type" end
	if #data.global >= 3 then return data.global, "global" end
	return nil
end

-- Portée apprise d'une unité (yards, bornée comme l'estimation), ou nil
function ns:AggroLearnedRadius(unit, playerLevel, mobLevel)
	if self:DB().aggroLearn == false then return nil end
	playerLevel, mobLevel = Num(playerLevel), Num(mobLevel)
	if not playerLevel or not mobLevel then return nil end
	local name = ns.Plain((Call(Global("UnitName"), unit)))
	local ctype = ns.Plain((Call(Global("UnitCreatureType"), unit)))
	local class = ns.Plain((Call(Global("UnitClassification"), unit)))
	local list = self:AggroLearnedList(name, ctype, class)
	if not list then return nil end
	local base = Quantile(list, ns.AGGRO_LEARN_CAUTIOUS)
	if not base then return nil end
	if mobLevel <= 0 then mobLevel = playerLevel + 10 end
	local radius = base + (mobLevel - playerLevel)
	return math.max(5, math.min(45, radius))
end

-- Le joueur a agi (sort, attaque, tir) : pas d'apprentissage dans la foulée
function ns:AggroMarkAction() self.aggroLastAction = Now() end

local function AttacksPlayer(unit)
	local target = ns.Plain((Call(Global("UnitIsUnit"), unit .. "target", "player")))
	if target == true or target == 1 then return true end
	local threat = ns.Plain((Call(Global("UnitThreatSituation"), "player", unit)))
	return threat ~= nil
end

-- Début de combat : un échantillon si un monstre t'a pris tout seul
function ns:AggroLearnOnCombat()
	if self:DB().aggroLearn == false or not self:AggroOn() then return nil end
	local now = Now()
	if now - (self.aggroLastAction or -1000) < ns.AGGRO_LEARN_QUIET then return nil end
	local grouped = Call(Global("IsInGroup"))
	if grouped == true or grouped == 1 then return nil end
	local pet = Call(Global("UnitAffectingCombat"), "pet")
	if pet == true or pet == 1 then return nil end
	local best
	for unit, tr in pairs(self.aggroTracks or {}) do
		if tr.sure and tr.est and now - tr.t <= ns.AGGRO_LEARN_FRESH and AttacksPlayer(unit) then
			if not best or tr.est < best.est then best = tr end
		end
	end
	if not best or not best.pl or not best.ml then return nil end
	local expected = ns.AggroRadius(best.pl, best.ml)
	if best.est > 45 or best.est < 2 or (expected and best.est > expected * 1.8) then return nil end
	local mobLevel = best.ml <= 0 and best.pl + 10 or best.ml
	local base = best.est - (mobLevel - best.pl)
	local data = LearnData(self, true)
	if best.name then
		data.byName[best.name] = data.byName[best.name] or {}
		Push(data.byName[best.name], base)
	end
	if best.ctype then
		local key = best.ctype .. "|" .. ClassOf(best.class)
		data.byType[key] = data.byType[key] or {}
		Push(data.byType[key], base)
		data.byType[best.ctype] = data.byType[best.ctype] or {}
		Push(data.byType[best.ctype], base)
	end
	Push(data.global, base)
	data.count = (tonumber(data.count) or 0) + 1
	return base
end

function ns:AggroLearnReset()
	self:DB().aggroLearnData = nil
end

function ns:AggroLearnCount()
	local data = LearnData(self)
	return data and tonumber(data.count) or 0
end

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
local HANDLERS = {
	SPELLS_CHANGED               = function() ns:AggroSpellsChanged() end,
	LEARNED_SPELL_IN_SKILL_LINE  = function() ns:AggroSpellsChanged() end,
	PLAYER_REGEN_DISABLED        = function() ns:AggroLearnOnCombat() end,
	UNIT_SPELLCAST_SENT          = function(unit) if ns.Plain(unit) == "player" then ns:AggroMarkAction() end end,
	PLAYER_ENTER_COMBAT          = function() ns:AggroMarkAction() end,
	START_AUTOREPEAT_SPELL       = function() ns:AggroMarkAction() end,
	PLAYER_ENTERING_WORLD        = function() ns.aggroTracks = nil end,
}
local frame = CreateFrame("Frame")
for event in pairs(HANDLERS) do pcall(frame.RegisterEvent, frame, event) end
frame:SetScript("OnEvent", function(_, event, ...)
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("aggroplus:" .. tostring(event), err) end
end)
ns.aggroPlusFrame = frame

if ns.Mark then ns.Mark("AggroPlus") end
