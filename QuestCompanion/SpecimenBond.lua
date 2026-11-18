-- SpecimenBond.lua -- le lien avec un spécimen porté (QuestCompanion 3.4.0)
--
-- 3.4.0 (docs/design-reserve-3.4, orientation « Compagnon de route ») :
--   * chaque spécimen a un LIEN, au compte : spec.bond = { p = points, day =
--     clé du jour, c = { route, treat, pet, quest, cap } } (écrit seulement
--     quand il a des points) ;
--   * les points ne viennent que si le spécimen est l'exemplaire porté
--     (apparence « cap:<npc>[:s] » du personnage, référence du Codex ; ni
--     mascotte ni compagnon de saison), 10 par jour au plus : route (1 point
--     par 1,5 km parcourus, 3 par jour), friandise donnée (2), caresse (1),
--     quête rendue (2), capture réussie (2) ;
--   * niveaux : Inconnu (0), Familier (10), Complice (35), Fidèle (80),
--     Inséparable (180) ; le plus haut atteignable dépend des étoiles
--     (1 étoile : 3, 2 étoiles : 4, 3 étoiles : 5) ;
--   * au lien 2 : le revers du caractère et les effets de la taille
--     (CompanionEffects.lua) ; l'atout du caractère grandit (×1,25 … ×2) ;
--     lien 3 : un souvenir par jour au plus (30 %, un appât ou une
--     friandise) ; lien 5 : marque « Inséparable », surnom offert ;
--   * un exemplaire du Codex au lien 2 ou plus (ou protégé) n'est plus
--     remplacé d'office par un meilleur (CaptureSpecimens.lua) ;
--   * changer d'exemplaire au Codex pour la version portée relance l'attente
--     des effets et n'est pas possible en combat ;
--   * le cache des effets n'est touché qu'au passage d'un niveau.
--   * migration (capture.bondV) : le compagnon actuel de chaque personnage
--     reçoit 10 points par jour passé sous cette apparence, 35 au plus.
--
-- API
--   ns.BOND_LEVELS = { 0, 10, 35, 80, 180 } ; ns.BOND_DAILY = 10
--   ns:SpecimenBondPoints(spec|id) -> points ; ns:SpecimenBondLevel(spec|id) -> 1..5
--   ns:SpecimenBondPotential(spec|id) -> 3..5 ; ns:SpecimenBondName(level)
--   ns:SpecimenBondNext(spec|id) -> points du niveau suivant | nil
--   ns:SpecimenWornHere() -> le spécimen porté par ce personnage | nil
--   ns:SpecimenBondAdd(source, n) -> points ajoutés (au spécimen porté)
--   ns:SpecimenKeepReference(spec) -> bool (lien 2 ou plus, ou protégé)
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.BOND_LEVELS = { 0, 10, 35, 80, 180 }
ns.BOND_DAILY = 10
-- points par événement, plafond du jour par source
ns.BOND_SOURCES = {
	route = { gain = 1, cap = 3 }, treat = { gain = 2, cap = 4 }, pet = { gain = 1, cap = 2 },
	quest = { gain = 2, cap = 4 }, cap = { gain = 2, cap = 4 },
	-- 3.5.0 : une envie comblée (CompanionStates.lua), hors du plafond du jour
	wish = { gain = 1, cap = 3, outside = true },
}
ns.BOND_ROUTE_METERS = 1500
ns.BOND_KEEPSAKE = { level = 3, chance = 0.30 }
ns.BOND_MIGRATION = { perDay = 10, max = 35 }
ns.BOND_SCHEMA = 1

local FR = {
	BOND_1 = "Inconnu", BOND_2 = "Familier", BOND_3 = "Complice", BOND_4 = "Fidèle", BOND_5 = "Inséparable",
	BOND_LINE      = "Lien : %s (%d / %d)",
	BOND_LINE_MAX  = "Lien : %s",
	BOND_POTENTIAL = "jusqu'à %s (%d étoile(s))",
	BOND_UP        = "%s et toi : %s !",
	BOND_KEEPSAKE  = "%s t'a rapporté un souvenir : %s.",
	BOND_COMBAT    = "Pas en plein combat : change de spécimen après.",
	BOND_KEPT      = "Ton spécimen est lié : le nouveau va en Réserve (plus d'étoiles que le tien).",
}
local EN = {
	BOND_1 = "Stranger", BOND_2 = "Familiar", BOND_3 = "Partner", BOND_4 = "Loyal", BOND_5 = "Inseparable",
	BOND_LINE      = "Bond: %s (%d / %d)",
	BOND_LINE_MAX  = "Bond: %s",
	BOND_POTENTIAL = "up to %s (%d star(s))",
	BOND_UP        = "%s and you: %s!",
	BOND_KEEPSAKE  = "%s brought you a keepsake: %s.",
	BOND_COMBAT    = "Not in the middle of a fight: swap specimens afterwards.",
	BOND_KEPT      = "Your specimen is bonded: the new one goes to the Reserve (more stars than yours).",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.BOND_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function Wall() return tonumber(Call(G("time"))) or 0 end
local function InCombat() return Call(G("InCombatLockdown")) == true end
local function DayKey() return ns.CaptureDayKey and ns.CaptureDayKey() or tostring(math.floor(Wall() / 86400)) end
local function Spec(self, spec)
	if type(spec) == "table" then return spec end
	return self.SpecimenGet and self:SpecimenGet(spec) or nil
end
local function Touch(self)
	if ns.SpecimenTouch and self.CaptureData then ns.SpecimenTouch(self:CaptureData()) end
end

-- ---------------------------------------------------------------------------
-- Points et niveaux
-- ---------------------------------------------------------------------------
function ns:SpecimenBondPoints(spec)
	spec = Spec(self, spec)
	local bond = type(spec) == "table" and spec.bond
	return type(bond) == "table" and math.max(0, math.floor(tonumber(bond.p) or 0)) or 0
end

function ns:SpecimenBondPotential(spec)
	spec = Spec(self, spec)
	local stars = type(spec) == "table" and math.floor(tonumber(spec.stars) or 1) or 1
	return math.max(3, math.min(5, stars + 2))
end

local function LevelOf(points, potential)
	local level = 1
	for index, need in ipairs(ns.BOND_LEVELS) do
		if points >= need then level = index end
	end
	return math.min(level, potential or 5)
end

function ns:SpecimenBondLevel(spec)
	spec = Spec(self, spec)
	if type(spec) ~= "table" then return 1 end
	return LevelOf(self:SpecimenBondPoints(spec), self:SpecimenBondPotential(spec))
end

function ns:SpecimenBondName(level)
	return L["BOND_" .. math.max(1, math.min(5, math.floor(tonumber(level) or 1)))]
end

function ns:SpecimenBondNext(spec)
	spec = Spec(self, spec)
	local level = self:SpecimenBondLevel(spec)
	if level >= self:SpecimenBondPotential(spec) then return nil end
	return ns.BOND_LEVELS[level + 1]
end

function ns:SpecimenKeepReference(spec)
	spec = Spec(self, spec)
	if type(spec) ~= "table" then return false end
	return spec.lock == true or self:SpecimenBondLevel(spec) >= 2
end

-- ---------------------------------------------------------------------------
-- Le spécimen porté par ce personnage
-- ---------------------------------------------------------------------------
function ns:SpecimenWornHere()
	if self.CompanionWinterSpec and self:CompanionWinterSpec() then return nil end
	if not self.CompanionData then return nil end
	local look = tostring(self:CompanionData().appearance or "")
	local npc, suffix = look:match("^cap:(%d+)(.*)$")
	npc = tonumber(npc)
	if not npc or not self.SpecimenReference then return nil end
	return self:SpecimenReference(npc, suffix == ":s")
end

-- un souvenir par jour (lien 3) : un appât ou une friandise simple
local function Keepsake(self, spec)
	local rule = ns.BOND_KEEPSAKE
	if self:SpecimenBondLevel(spec) < rule.level or math.random() >= rule.chance then return end
	local label
	if math.random() < 0.5 and self.CaptureGrant then
		local result = self:CaptureGrant("appat", { quiet = true, silent = true })
		if result == "ok" and self.CaptureAidLabel then label = self:CaptureAidLabel("appat") end
	end
	if not label and self.TreatGrant and self.TreatRandom then
		local kind = self:TreatRandom()
		if kind and self:TreatGrant(kind, { quiet = true }) then label = self:TreatLabel(kind) end
	end
	if label then self:Print(self:F("BOND_KEEPSAKE", self:SpecimenDisplayName(spec), label)) end
end

-- Des points pour le spécimen porté (plafonds par source et par jour)
function ns:SpecimenBondAdd(source, n)
	local rule = ns.BOND_SOURCES[source]
	if not rule then return 0 end
	local spec = self:SpecimenWornHere()
	if not spec then return 0 end
	local day = DayKey()
	local bond = type(spec.bond) == "table" and spec.bond or { p = 0 }
	local newDay = bond.day ~= day
	if newDay then bond.day, bond.c = day, {} end
	bond.c = type(bond.c) == "table" and bond.c or {}
	local today = 0
	for key, value in pairs(bond.c) do
		local other = ns.BOND_SOURCES[key]
		if not (other and other.outside) then today = today + (tonumber(value) or 0) end
	end
	local want = (tonumber(n) or 1) * rule.gain
	local room = rule.cap - (tonumber(bond.c[source]) or 0)
	if not rule.outside then room = math.min(room, ns.BOND_DAILY - today) end
	local gain = math.max(0, math.min(want, room))
	if gain <= 0 then
		if newDay then spec.bond = bond end
		return 0
	end
	local before = self:SpecimenBondLevel(spec)
	bond.c[source] = (tonumber(bond.c[source]) or 0) + gain
	bond.p = (tonumber(bond.p) or 0) + gain
	spec.bond = bond
	local after = self:SpecimenBondLevel(spec)
	if after > before then
		-- le cache des effets suit le niveau (pas chaque point)
		Touch(self)
		self:Print(self:F("BOND_UP", self:SpecimenDisplayName(spec), self:SpecimenBondName(after)))
		if ns.FireCallback then ns:FireCallback("BOND", "level", spec.id, after) end
	end
	if newDay then Keepsake(self, spec) end
	return gain
end

-- ---------------------------------------------------------------------------
-- Sources de points
-- ---------------------------------------------------------------------------
do
	local sample = ns.TravelSample
	if sample then
		function ns:TravelSample(now, ...)
			local meters = sample(self, now, ...)
			if (tonumber(meters) or 0) > 0 then
				self.bondRoute = (self.bondRoute or 0) + meters
				if self.bondRoute >= ns.BOND_ROUTE_METERS then
					local steps = math.floor(self.bondRoute / ns.BOND_ROUTE_METERS)
					self.bondRoute = self.bondRoute - steps * ns.BOND_ROUTE_METERS
					pcall(self.SpecimenBondAdd, self, "route", steps)
				end
			end
			return meters
		end
	end
	local give = ns.TreatGive
	if give then
		function ns:TreatGive(kind, ...)
			local ok = give(self, kind, ...)
			if ok then pcall(self.SpecimenBondAdd, self, "treat", 1) end
			return ok
		end
	end
	local pet = ns.CompanionPet
	if pet then
		function ns:CompanionPet(...)
			local ok = pet(self, ...)
			if ok then pcall(self.SpecimenBondAdd, self, "pet", 1) end
			return ok
		end
	end
	local resolve = ns.CaptureResolve
	if resolve then
		function ns:CaptureResolve(rolling, ...)
			local result = resolve(self, rolling, ...)
			if type(rolling) == "table" and rolling.success then pcall(self.SpecimenBondAdd, self, "cap", 1) end
			return result
		end
	end
	if ns.On then
		ns.On("QUEST_TURNED_IN", "bond", function() pcall(ns.SpecimenBondAdd, ns, "quest", 1) end, "bond:quest")
	end
end

-- ---------------------------------------------------------------------------
-- Codex : l'exemplaire porté
-- ---------------------------------------------------------------------------
do
	local setRef = ns.SpecimenSetReference
	if setRef then
		function ns:SpecimenSetReference(id, ...)
			local spec = self:SpecimenGet(id)
			local worn = spec and self:SpecimenWornHere()
			local swapsWorn = worn ~= nil and worn.npc == spec.npc and (worn.shiny == true) == (spec.shiny == true)
			if swapsWorn and InCombat() then
				self:Print(L.BOND_COMBAT)
				return false, "combat"
			end
			local ok, why = setRef(self, id, ...)
			if ok and swapsWorn and self.CompanionData then
				-- un autre exemplaire : l'attente des effets repart
				local record = self:CompanionData().effects
				if type(record) == "table" then record.since = Wall() end
				self.effectCache, self.effectWasActive = nil, false
			end
			return ok, why
		end
	end
end

-- ---------------------------------------------------------------------------
-- Migration : le compagnon actuel de chaque personnage, d'après le temps passé
-- ---------------------------------------------------------------------------
function ns:SpecimenBondMigrate()
	local capture = self:CaptureData()
	if capture.bondV == ns.BOND_SCHEMA then return 0 end
	capture.bondV = ns.BOND_SCHEMA
	local now, given = Wall(), 0
	local rule = ns.BOND_MIGRATION
	local db = self:DB()
	for _, char in pairs(type(db.chars) == "table" and db.chars or {}) do
		local companion = type(char) == "table" and char.companion
		local look = type(companion) == "table" and tostring(companion.appearance or "") or ""
		local npc, suffix = look:match("^cap:(%d+)(.*)$")
		local record = type(companion) == "table" and companion.effects
		local since = type(record) == "table" and tonumber(record.since)
		if npc and since and since > 0 and self.SpecimenReference then
			local spec = self:SpecimenReference(tonumber(npc), suffix == ":s")
			if spec then
				local days = math.floor(math.max(0, now - since) / 86400)
				local points = math.min(rule.max, rule.perDay * days)
				if points > self:SpecimenBondPoints(spec) then
					spec.bond = type(spec.bond) == "table" and spec.bond or {}
					spec.bond.p = points
					given = given + 1
				end
			end
		end
	end
	if given > 0 then Touch(self) end
	return given
end

if ns.On then
	ns.On("PLAYER_LOGIN", "bond", function() pcall(ns.SpecimenBondMigrate, ns) end, "bond:migrate")
end

if ns.Mark then ns.Mark("SpecimenBond") end
