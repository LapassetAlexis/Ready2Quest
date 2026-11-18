-- CompanionStates.lua -- les états du compagnon : humeur, Rayonnant, son envie (QuestCompanion 3.5.0)
--
-- 3.5.0 (docs/design-envies-3.5) : des états, pas des jauges.
--   * Trois états de 45 minutes (Companion.lua : Repu, Reposé, Éveillé) ;
--     l'humeur se lit à leur nombre : Tranquille, Content, Joyeux, Rayonnant.
--   * Rayonnant (les trois) : chance de capture ×1,10 (après les effets de
--     type et leurs plafonds, avant CAPTURE_MAX), chance de brillante ×1,20.
--   * UNE envie à la fois (data.wish = { key, at }) : un état inactif (celui
--     qu'aime son caractère compte double) ; les trois actifs : celui qui a
--     moins de 15 minutes. Comblée : +1 point de lien (3 par jour, hors du
--     plafond du jour ; une mascotte, sans lien : ses états actifs repartent
--     à plein), et le stade qui attendait peut passer. Ignorée : rien ; la
--     suivante 20 minutes après. Affichée sur la page Compagnon, la fiche au
--     survol et le tableau de bord, quel que soit le bavardage.
--   * Éveillé en chasse : 15 créatures tuées ou capturées en 10 minutes, une
--     brillante tentée, une espèce nouvelle capturée.
--   * Une caresse renforcée (effet « pet ») allonge l'état qui finit le premier.
--   * Curieux : la cueillette donne aussi Éveillé.
--   * Rayonnant atteint : une réplique (réserve NEED_mood).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.COMPANION_RADIANT = { capture = 1.10, shiny = 1.20 }
ns.COMPANION_STATE_LABELS = { hunger = "COMP_STATE_hunger", energy = "COMP_STATE_energy", curiosity = "COMP_STATE_curiosity" }

local FR = {
	COMP_STATE_hunger    = "Repu",
	COMP_STATE_energy    = "Reposé",
	COMP_STATE_curiosity = "Éveillé",
	COMP_STATE_MIN       = "%d min",
	COMP_STATE_OFF       = "—",
	COMP_STATE_HINT_ON   = "%s : encore %d min",
	COMP_STATE_HINT_OFF  = "%s : %s",
	COMP_WISH_hunger     = "Manger",
	COMP_WISH_energy     = "Se reposer",
	COMP_WISH_curiosity  = "Découvrir",
	COMP_WISH_LINE       = "Envie : %s",
	COMP_WISH_BOND       = "+1 lien",
	COMP_WISH_MET        = "%s : envie comblée (%s) !",
	COMP_MOOD_calm       = "tranquille",
	COMP_MOOD_joyful     = "joyeux",
	COMP_RADIANT_ON      = "Rayonnant : capture +%d %%, brillantes +%d %%",
	COMP_RADIANT_LEFT    = "Encore %d pour rayonner",
	COMP_RADIANT_ACTIVE  = "Bonus actif",
}
local EN = {
	COMP_STATE_hunger    = "Fed",
	COMP_STATE_energy    = "Rested",
	COMP_STATE_curiosity = "Alert",
	COMP_STATE_MIN       = "%d min",
	COMP_STATE_OFF       = "—",
	COMP_STATE_HINT_ON   = "%s: %d min left",
	COMP_STATE_HINT_OFF  = "%s: %s",
	COMP_WISH_hunger     = "Eat",
	COMP_WISH_energy     = "Rest",
	COMP_WISH_curiosity  = "Explore",
	COMP_WISH_LINE       = "Wish: %s",
	COMP_WISH_BOND       = "+1 bond",
	COMP_WISH_MET        = "%s: wish granted (%s)!",
	COMP_MOOD_calm       = "calm",
	COMP_MOOD_joyful     = "joyful",
	COMP_RADIANT_ON      = "Radiant: capture +%d%%, shinies +%d%%",
	COMP_RADIANT_LEFT    = "%d more to be radiant",
	COMP_RADIANT_ACTIVE  = "Bonus on",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.COMPANION_STATE_STRINGS = { fr = FR, en = EN } end

local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end
local function InCombat()
	if Call(rawget(_G, "InCombatLockdown")) then return true end
	return Call(rawget(_G, "UnitAffectingCombat"), "player") and true or false
end
local function On() return ns.CompanionOn and ns.CompanionOn() or false end
local function S() return ns.COMPANION_STATE end
local function Keys() return ns.COMPANION_NEED_KEYS or {} end

-- ---------------------------------------------------------------------------
-- Rayonnant
-- ---------------------------------------------------------------------------
do
	local chance = ns.CaptureChance
	if chance then
		function ns:CaptureChance(info, aidID, playerLevel, ...)
			local value, sure = chance(self, info, aidID, playerLevel, ...)
			if sure or not value or value <= 0 or not On() or not self:CompanionRadiant() then return value, sure end
			return math.min(ns.CAPTURE_MAX or 0.95, value * ns.COMPANION_RADIANT.capture), sure
		end
	end
	local shiny = ns.ShinyChance
	if shiny then
		function ns:ShinyChance(...)
			local value = shiny(self, ...)
			if type(value) ~= "number" or not On() or not self:CompanionRadiant() then return value end
			return value * ns.COMPANION_RADIANT.shiny
		end
	end
end

-- ---------------------------------------------------------------------------
-- Allonger l'état qui finit le premier (caresse renforcée), d'une part de 45 min
-- ---------------------------------------------------------------------------
-- 3.5.1 : une seule fois par état (data.extended[key]) ; le droit revient
-- quand l'état est regagné (déclencheur ou friandise). Avant : une caresse
-- toutes les 15 s gardait Rayonnant pour toujours.
function ns:CompanionStateExtend(fraction)
	local data = self:CompanionData()
	if type(data.extended) ~= "table" then data.extended = {} end
	local best, bestMin
	for _, key in ipairs(Keys()) do
		local m = self:CompanionStateMinutes(key)
		if m > 0 and not data.extended[key] and (not bestMin or m < bestMin) then best, bestMin = key, m end
	end
	if not best then return nil end
	data.extended[best] = true
	local needs = data.needs
	local add = (S().full - S().on) * math.max(0, tonumber(fraction) or 0)
	needs[best] = math.min(S().max, needs[best] + add)
	self:CompanionRefreshHover()
	return best
end

-- ---------------------------------------------------------------------------
-- L'envie du moment
-- ---------------------------------------------------------------------------
local function Preferred(self)
	local trait = self.CompanionTrait and self:CompanionTrait()
	local def = trait and ns.PERSONALITY_TRAITS and ns.PERSONALITY_TRAITS[trait]
	return def and def.need or nil
end

-- le choix : un état inactif (le préféré compte double), sinon celui qui a
-- moins de wishSoon minutes ; rien sinon
function ns:CompanionWishPick()
	local pool, weights, total = {}, {}, 0
	local preferred = Preferred(self)
	for _, key in ipairs(Keys()) do
		if not self:CompanionStateOn(key) then
			pool[#pool + 1] = key
			weights[#pool] = key == preferred and 2 or 1
			total = total + weights[#pool]
		end
	end
	if #pool == 0 then
		local soon, soonMin
		for _, key in ipairs(Keys()) do
			local m = self:CompanionStateMinutes(key)
			if m < S().wishSoon and (not soonMin or m < soonMin) then soon, soonMin = key, m end
		end
		return soon
	end
	local roll = math.random() * total
	for index, key in ipairs(pool) do
		roll = roll - weights[index]
		if roll <= 0 then return key end
	end
	return pool[#pool]
end

function ns:CompanionWish()
	local wish = self:CompanionData().wish
	return type(wish) == "table" and wish.key or nil
end

-- « Envie : Manger » ; nil sans envie
function ns:CompanionWishLine()
	local key = self:CompanionWish()
	if not key then return nil end
	return self:F("COMP_WISH_LINE", L["COMP_WISH_" .. key] or key)
end

function ns:CompanionWishTick(force)
	if not On() then return nil end
	local data = self:CompanionData()
	if data.sleepy then return nil end
	if self:CompanionWish() then return nil end
	local now = Clock()
	-- pas d'envie dans les 2 minutes après la connexion
	if self.companionWishNext == nil and not force then self.companionWishNext = now + S().wishGrace end
	if not force and (now < (tonumber(self.companionWishNext) or 0) or InCombat()) then return nil end
	local key = self:CompanionWishPick()
	if not key then self.companionWishNext = now + 60; return nil end
	data.wish = { key = key }
	self.companionWishNext = nil
	if self.CompanionSay then self:CompanionSay("NEED_" .. key, { cd = { "need", "need_" .. key } }) end
	self:CompanionRefreshHover()
	if self.RefreshJournalTracker then pcall(self.RefreshJournalTracker, self) end
	return key
end

-- Comblée : lien (ou, sans lien, ses états actifs à plein), stade, bulle
function ns:CompanionWishMet(key)
	local data = self:CompanionData()
	data.wish = nil
	self.companionWishNext = Clock() + S().wishGap
	local bond = self.SpecimenWornHere and self:SpecimenWornHere()
	if bond and self.SpecimenBondAdd then
		pcall(self.SpecimenBondAdd, self, "wish", 1)
	else
		local needs = data.needs
		for _, k in ipairs(Keys()) do
			if needs[k] and needs[k] > S().on and needs[k] < S().full then needs[k] = S().full end
		end
	end
	if self.Print and self:DB().journalChat == true then
		self:Print(self:F("COMP_WISH_MET", self:CompanionName(), L["COMP_STATE_" .. key] or key))
	end
	if data.stageReady then
		data.stageWish = true
		if self.CompanionCheckStage then self:CompanionCheckStage(nil, true) end
	end
	if self.FireCallback then self:FireCallback("COMPANION_WISH", key) end
	if self.RefreshJournalTracker then pcall(self.RefreshJournalTracker, self) end
	return true
end

-- un état obtenu : l'envie qu'il comble, et Rayonnant atteint
if ns.RegisterCallback then
	ns:RegisterCallback("COMPANION_STATE", function(self, key, was)
		local extended = self:CompanionData().extended
		if type(extended) == "table" then extended[key] = nil end   -- regagné : la caresse peut de nouveau l'allonger
		if self:CompanionWish() == key then self:CompanionWishMet(key) end
		if not was and self:CompanionRadiant() and self.CompanionSay then
			self:CompanionSay("NEED_mood", { cd = "need" })
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Éveillé en chasse ; Curieux à la cueillette
-- ---------------------------------------------------------------------------
local hunt = {}
function ns:CompanionHuntCount()
	if not (self.HuntActive and self:HuntActive()) then return false end
	local now = Clock()
	hunt[#hunt + 1] = now
	while hunt[1] and hunt[1] <= now - S().huntWindow do table.remove(hunt, 1) end
	if #hunt >= S().huntKills then
		for i = #hunt, 1, -1 do hunt[i] = nil end
		return self:CompanionGrant("curiosity")
	end
	return false
end
ns.CompanionHuntReset = function() for i = #hunt, 1, -1 do hunt[i] = nil end end

do
	local resolve = ns.CaptureResolve
	if resolve then
		function ns:CaptureResolve(rolling, ...)
			local target = type(rolling) == "table" and rolling.target or nil
			local fresh = target and target.npcID and self:CaptureData().creatures[target.npcID] == nil
			local result = resolve(self, rolling, ...)
			if On() and type(rolling) == "table" and self.CompanionGrant then
				local hunting = self.HuntActive and self:HuntActive()
				if hunting and target and target.shiny then self:CompanionGrant("curiosity")
				elseif hunting and rolling.success and fresh then self:CompanionGrant("curiosity")
				elseif rolling.success then self:CompanionHuntCount() end
			end
			return result
		end
	end
end

function ns:CompanionGatherGrant()
	if not On() then return false end
	local trait = self.CompanionTrait and self:CompanionTrait()
	if trait ~= "curious" then return false end
	return self:CompanionGrant("curiosity")
end

if ns.Mark then ns.Mark("CompanionStates") end
