-- TrackerGoals.lua -- toujours un but en vue : les objectifs de la 3.6 dans le suivi à l'écran (QuestCompanion 3.6.0)
--
-- 3.6.0 (docs/audit-pokemon-like-3.5/PLAN.md, lot 1A ; maquette 3.6,
-- planche 1) : le bloc « Carnet » (JournalTracker.lua) reçoit quatre sources
-- de plus, une ligne au plus chacune, dans l'ordre décidé (goal.rank) :
--   1. l'envie du compagnon (CompanionStates.lua) : « Brindille veut
--      manger », « +1 lien » s'il porte un spécimen ; clic : page Compagnon ;
--   2. une commande de la semaine que la Réserve peut livrer (ShopWeek.lua) ;
--      clic : l'Échoppe ;
--   (3. les objectifs d'avant : niveau, capitales, donjons, zone, missions…)
--   4. la tâche d'étude la plus proche d'être finie (SpecimenStudy.lua) ;
--      clic : l'espèce, page Créatures ;
--   5. « Créatures de <zone> : n à capturer ici » (espèces rencontrées pas
--      encore capturées) ; à 10 espèces ou moins du sceau de la zone, le
--      sceau ; clic : les Créatures de la zone.
-- Le bloc garde 4 lignes au plus. Chaque objectif se masque d'un clic droit
-- comme les autres (clé du jour pour l'envie, de la semaine pour la commande).
-- Chargé après ShopWeek.lua, SpecimenBond.lua et CompanionStates.lua, il
-- relie aussi ce qui s'y passe aux missions (MissionsMenagerie.lua) : une
-- commande livrée (mission de la semaine), des points de lien (mission du
-- jour), et le suivi qui se recalcule.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.TRACKER_GOAL_RANKS = { wish = 1, order = 2, study = 4, zone = 5 }
ns.TRACKER_SEAL_NEAR = 10       -- espèces qui manquent : le sceau devient l'objectif
ns.TRACKER_ZONE_NAMES = 6       -- noms listés au survol

local FR = {
	JRN_GOAL_WISH_hunger    = "%s veut manger",
	JRN_GOAL_WISH_energy    = "%s veut se reposer",
	JRN_GOAL_WISH_curiosity = "%s veut découvrir",
	JRN_GOAL_WISH_TAG       = "envie",
	JRN_HINT_WISH           = "Comble-la : %s.",
	JRN_HINT_WISH_BOND      = "Comblée : +1 point de lien avec %s.",
	JRN_GOAL_ORDER          = "Commande : %s",
	JRN_GOAL_ORDER_TAG      = "à livrer",
	JRN_HINT_ORDER          = "Ta Réserve peut la livrer (%d spécimen(s) conviennent) : Échoppe du dresseur, Commandes de la semaine.",
	JRN_GOAL_STUDY          = "Étude %s : %s",
	JRN_HINT_STUDY          = "Clic : l'espèce, page Créatures.",
	JRN_GOAL_ZONE_CAP       = "Créatures de %s : %d à capturer ici",
	JRN_GOAL_ZONE_CAP_BRIEF = "%s : %d à capturer",
	JRN_GOAL_ZONE_SEAL      = "Sceau de %s : encore %d espèce(s)",
	JRN_GOAL_ZONE_SEAL_BRIEF = "%s : %d pour le sceau",
	JRN_UNIT_SEAL           = "sceau",
	JRN_HINT_ZONE_CAP       = "Rencontrées ici, pas encore capturées :",
	JRN_HINT_ZONE_SEAL      = "Toutes les espèces de la zone capturées : son sceau, et brillantes ×%s ici.",
}
local EN = {
	JRN_GOAL_WISH_hunger    = "%s wants to eat",
	JRN_GOAL_WISH_energy    = "%s wants to rest",
	JRN_GOAL_WISH_curiosity = "%s wants to explore",
	JRN_GOAL_WISH_TAG       = "wish",
	JRN_HINT_WISH           = "Grant it: %s.",
	JRN_HINT_WISH_BOND      = "Granted: +1 bond point with %s.",
	JRN_GOAL_ORDER          = "Order: %s",
	JRN_GOAL_ORDER_TAG      = "to deliver",
	JRN_HINT_ORDER          = "Your Reserve can deliver it (%d matching specimen(s)): Trainer's Stall, This week's orders.",
	JRN_GOAL_STUDY          = "%s study: %s",
	JRN_HINT_STUDY          = "Click: the species, Creatures page.",
	JRN_GOAL_ZONE_CAP       = "Creatures of %s: %d to capture here",
	JRN_GOAL_ZONE_CAP_BRIEF = "%s: %d to capture",
	JRN_GOAL_ZONE_SEAL      = "%s seal: %d species to go",
	JRN_GOAL_ZONE_SEAL_BRIEF = "%s: %d for the seal",
	JRN_UNIT_SEAL           = "seal",
	JRN_HINT_ZONE_CAP       = "Met here, not captured yet:",
	JRN_HINT_ZONE_SEAL      = "Capture every species of the zone: its seal, and shinies ×%s here.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TRACKER_GOAL_STRINGS = { fr = FR, en = EN } end

local RANK = ns.TRACKER_GOAL_RANKS
local function DayKey() return ns.CaptureDayKey and ns.CaptureDayKey() or "?" end
local function CaptureOn(self)
	return self.CaptureData ~= nil and self:DB().companionCapture ~= false
end

-- ---------------------------------------------------------------------------
-- Ouvrir la bonne page
-- ---------------------------------------------------------------------------
-- Une espèce dans la page Créatures (recherche sur son nom, toutes zones)
function ns:OpenMenagerieSpecies(npc)
	local frame = self.EnsureJournalWindow and self:EnsureJournalWindow()
	if not frame then return nil end
	local name = self.CreatureName and self:CreatureName(npc) or tostring(npc)
	frame.menZone, frame.menState, frame.menRank, frame.menOffset = "all", "all", "all", 0
	frame.menType, frame.menSearch = nil, tostring(name or "")
	if frame.men and frame.men.search then frame.men.search:SetText(frame.menSearch) end
	if not frame:IsShown() and self.ToggleJournal then self:ToggleJournal(true) end
	self:SelectJournalKind("menagerie")
	return frame
end

-- ---------------------------------------------------------------------------
-- 1. L'envie du compagnon
-- ---------------------------------------------------------------------------
local function WishGoal(self, list)
	if not (self.CompanionWish and ns.JournalGoal) then return end
	if not (ns.CompanionOn and ns.CompanionOn()) then return end
	local key = self:CompanionWish()
	if not key then return end
	local name = self.CompanionName and self:CompanionName() or "?"
	local goal = ns.JournalGoal("wish:" .. tostring(key) .. ":" .. DayKey(),
		self:F("JRN_GOAL_WISH_" .. tostring(key), name), 0, 1, nil, "companion")
	if not goal then return end
	goal.rank, goal.short = RANK.wish, goal.label
	local worn = self.SpecimenWornHere and self:SpecimenWornHere()
	goal.progress = worn and L.COMP_WISH_BOND or L.JRN_GOAL_WISH_TAG
	goal.hint = { self:F("JRN_HINT_WISH", L["COMP_HOW_" .. tostring(key)] or "") }
	if worn and self.SpecimenDisplayName then
		goal.hint[2] = self:F("JRN_HINT_WISH_BOND", self:SpecimenDisplayName(worn))
	end
	-- le stade qui attend une envie comblée : une seule ligne, sa récompense ici
	for index = #list, 1, -1 do
		local other = list[index]
		if other.happy then
			goal.reward = other.reward
			table.remove(list, index)
		end
	end
	list[#list + 1] = goal
end

-- ---------------------------------------------------------------------------
-- 2. Une commande de la semaine que la Réserve peut livrer
-- ---------------------------------------------------------------------------
function ns:TrackerOrderMatches(order)
	local n = 0
	if not (self.SpecimenList and self.ShopOrderMatches) then return 0 end
	for _, spec in ipairs(self:SpecimenList({ where = "reserve" })) do
		if self:ShopOrderMatches(order, spec) and (not self.SpecimenCanRelease or self:SpecimenCanRelease(spec.id)) then
			n = n + 1
		end
	end
	return n
end

local function OrderGoal(self, list)
	if not (CaptureOn(self) and self.ShopOrders and ns.JournalGoal) then return end
	local orders = self:ShopOrders()
	for index, order in ipairs(type(orders) == "table" and orders.list or {}) do
		if not order.done then
			local n = self:TrackerOrderMatches(order)
			if n > 0 then
				local goal = ns.JournalGoal("order:" .. tostring(orders.week) .. ":" .. index,
					self:F("JRN_GOAL_ORDER", self:ShopOrderLabel(order)), 0, 1, nil, "shop")
				if goal then
					goal.rank, goal.page = RANK.order, "shop"
					goal.progress = L.JRN_GOAL_ORDER_TAG
					goal.reward = self:F("ORDER_REWARD", order.reward or 0)
					goal.hint = { self:F("JRN_HINT_ORDER", n) }
					goal.onClick = function() return ns:OpenJournalFor(goal) end
					list[#list + 1] = goal
				end
				return
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- 4. La tâche d'étude la plus proche d'être finie
-- ---------------------------------------------------------------------------
local function StudyGoal(self, list)
	if not (CaptureOn(self) and self.SpecimenStudyClosest and ns.JournalGoal) then return end
	local best = self:SpecimenStudyClosest()
	if not best then return end
	local name = self.CreatureName and self:CreatureName(best.npc) or tostring(best.npc)
	local task = L["STUDY_" .. tostring(best.task)] or tostring(best.task)
	local goal = ns.JournalGoal("study:" .. tostring(best.npc) .. ":" .. tostring(best.task),
		self:F("JRN_GOAL_STUDY", name, task), best.have, best.need, nil, "study")
	if not goal then return end
	goal.rank, goal.short = RANK.study, goal.label
	goal.reward = self:F("MIS_REWARD_PAILLETTES", (ns.STUDY_REWARD and ns.STUDY_REWARD.task) or 2)
	goal.hint = { self.SpecimenStudyLine and self:SpecimenStudyLine(best.npc) or task, L.JRN_HINT_STUDY }
	local npc = best.npc
	goal.onClick = function() return ns:OpenMenagerieSpecies(npc) end
	list[#list + 1] = goal
end

-- ---------------------------------------------------------------------------
-- 5. Les Créatures de la zone : à capturer ici, puis le sceau
-- ---------------------------------------------------------------------------
-- { met, caught, missing = { noms } } : espèces rencontrées ici (vues ou
-- abattues ; ni boss du monde), capturées ou non (une version suffit)
function ns:TrackerZoneCreatures(zoneID)
	local out = { met = 0, caught = 0, missing = {} }
	if not (zoneID and self.BestiarySpecies) then return out end
	local creatures = self:CaptureData().creatures
	for npcID, species in pairs(self:BestiarySpecies(zoneID)) do
		local npc = tonumber(npcID) or npcID
		if type(species) == "table" and species.class ~= "worldboss"
			and (species.seen == true or (tonumber(species.killed) or 0) > 0) then
			out.met = out.met + 1
			if creatures[npc] ~= nil then out.caught = out.caught + 1
			else out.missing[#out.missing + 1] = tostring(species.name or npc) end
		end
	end
	table.sort(out.missing)
	return out
end

local function ZoneGoal(self, list)
	if not (CaptureOn(self) and self.JournalZone and ns.JournalGoal) then return end
	local zoneID, zoneName = self:JournalZone()
	if not zoneID then return end
	zoneName = tostring(zoneName or zoneID)
	local goal
	-- le sceau d'abord, quand il est proche
	local have, need = 0, 0
	if self.MenagerieSealProgress then have, need = self:MenagerieSealProgress(zoneID) end
	local left = need - have
	local sealed = self.MenagerieSealed and self:MenagerieSealed(zoneID)
	if need > 0 and not sealed and left > 0 and left <= ns.TRACKER_SEAL_NEAR then
		goal = ns.JournalGoal("seal:" .. zoneID, self:F("JRN_GOAL_ZONE_SEAL", zoneName, left), have, need, nil, "menagerie")
		if goal then
			goal.brief = self:F("JRN_GOAL_ZONE_SEAL_BRIEF", zoneName, left)
			goal.unit = L.JRN_UNIT_SEAL
			local mult = ns.MenagerieDecimal and ns.MenagerieDecimal(ns.SEAL_SHINY_MULT or 1) or tostring(ns.SEAL_SHINY_MULT or 1)
			goal.hint = { self:F("JRN_HINT_ZONE_SEAL", mult) }
		end
	else
		local zone = self:TrackerZoneCreatures(zoneID)
		local missing = zone.met - zone.caught
		if missing <= 0 then return end
		goal = ns.JournalGoal("captures:" .. zoneID, self:F("JRN_GOAL_ZONE_CAP", zoneName, missing), zone.caught, zone.met,
			nil, "menagerie")
		if goal then
			goal.brief = self:F("JRN_GOAL_ZONE_CAP_BRIEF", zoneName, missing)
			local hint = { L.JRN_HINT_ZONE_CAP }
			for index, name in ipairs(zone.missing) do
				if index > ns.TRACKER_ZONE_NAMES then
					hint[#hint + 1] = self:F("JRN_HINT_MORE", #zone.missing - ns.TRACKER_ZONE_NAMES)
					break
				end
				hint[#hint + 1] = "  · " .. name
			end
			goal.hint = hint
		end
	end
	if not goal then return end
	goal.rank, goal.short, goal.zoneID = RANK.zone, goal.label, zoneID
	local id = zoneID
	goal.onClick = function() return ns:OpenMenagerieZone(id) end
	list[#list + 1] = goal
end

if ns.RegisterGoalSource then
	ns.RegisterGoalSource(WishGoal)
	ns.RegisterGoalSource(OrderGoal)
	ns.RegisterGoalSource(StudyGoal)
	ns.RegisterGoalSource(ZoneGoal)
end

-- ---------------------------------------------------------------------------
-- Ce qui fait bouger ces objectifs, et les missions de la 3.6
-- ---------------------------------------------------------------------------
local function Refresh(self)
	if self.RefreshJournalTracker then pcall(self.RefreshJournalTracker, self) end
end

-- une capture, un spécimen relâché ou livré : étude, commandes, zone
if ns.RegisterCallback then
	ns:RegisterCallback("SPECIMENS", function(self) Refresh(self) end)
end

-- une commande livrée : la mission de la semaine, l'astuce apprise, le suivi
do
	local deliver = ns.ShopOrderDeliver
	if deliver then
		function ns:ShopOrderDeliver(...)
			local ok, why = deliver(self, ...)
			if ok then
				if self.WeeklyEvent then pcall(self.WeeklyEvent, self, "orders", 1) end
				if self.DiscoveryUse then pcall(self.DiscoveryUse, self, "order") end
				Refresh(self)
			end
			return ok, why
		end
	end
end

-- des points de lien : la mission du jour « gagne 5 points de lien »
do
	local add = ns.SpecimenBondAdd
	if add then
		function ns:SpecimenBondAdd(...)
			local gain = add(self, ...)
			if (tonumber(gain) or 0) > 0 and self.MissionEvent then pcall(self.MissionEvent, self, "bond", gain) end
			return gain
		end
	end
end

if ns.Mark then ns.Mark("TrackerGoals") end
