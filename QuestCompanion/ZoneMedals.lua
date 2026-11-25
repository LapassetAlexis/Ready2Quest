-- ZoneMedals.lua -- médailles de zone : bronze, argent, or avant le sceau (QuestCompanion 3.7.0)
--
-- Entre la première capture d'une zone et son sceau (toutes ses espèces), trois
-- étapes : bronze à 25 %, argent à 50 %, or à 75 % des espèces de la zone,
-- même décompte que le sceau (ns:MenagerieSealProgress : la table de la zone
-- filtrée par ta faction, hors boss du monde). Seuil = arrondi supérieur de la
-- part (179 espèces : 45, 90, 135). Une zone scellée a les trois.
--   * Honorifiques : 3, 5 et 10 paillettes, une fois par zone et par compte
--     (ns:PaillettesAdd(n, "medal")), rien d'autre. Le sceau garde tout ce
--     qu'il donne.
--   * En direct (une capture franchit un seuil) : une bulle (événement) et
--     une ligne de chat. Pas de bandeau.
--   * Rattrapage, une fois par compte : les médailles déjà méritées payées
--     d'un coup, une seule ligne de chat.
--   * Mode discret (ns:Quiet, s'il existe) : ni bulle ni ligne.
-- Sauvegarde (compte, avec les captures) : CaptureData().zoneMedals =
-- { [uiMapID] = médaille payée (1 à 3) }, CaptureData().zoneMedalsInit.
-- Affichage : l'encadré de la page Créatures (MenagerieCollection.lua) et la
-- ligne de zone du suivi (TrackerGoals.lua, ns:ZoneMedalGoal).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.ZONE_MEDAL = { parts = { 25, 50, 75 }, glitter = { 3, 5, 10 } }
-- teintes (jetons du thème) : losange éteint, bronze, argent, or, sceau.
-- Le socle n'a pas de jeton « argent » : MUTED_LIGHT (gris clair) en tient lieu.
ns.ZONE_MEDAL_TINTS = { off = "EDGE", "GOLD_SOFT", "MUTED_LIGHT", "GOLD_LIGHT", seal = "GOLD" }
-- le harnais de test l'endort (pas de paillettes ni de ligne dans les autres
-- scénarios) ; ses fonctions de lecture répondent toujours
ns.zoneMedalsDormant = rawget(_G, "ADDON_TESTING") and true or nil

local FR = {
	ZONE_MEDAL_1          = "bronze",
	ZONE_MEDAL_2          = "argent",
	ZONE_MEDAL_3          = "or",
	ZONE_MEDAL_SEAL       = "sceau",
	ZONE_MEDAL_NAME_1     = "Médaille de bronze",
	ZONE_MEDAL_NAME_2     = "Médaille d'argent",
	ZONE_MEDAL_NAME_3     = "Médaille d'or",
	ZONE_MEDAL_TITLE      = "%s : %d sur %d espèces",
	ZONE_MEDAL_LEFT_1     = "encore %d pour le bronze",
	ZONE_MEDAL_LEFT_2     = "encore %d pour l'argent",
	ZONE_MEDAL_LEFT_3     = "encore %d pour l'or",
	ZONE_MEDAL_LEFT_4     = "encore %d pour le sceau",
	ZONE_MEDAL_MARK       = "%s %d",
	ZONE_MEDAL_ALL        = "Médailles de zone : %d bronze · %d argent · %d or",
	ZONE_MEDAL_TIP        = "Médailles : bronze à %d %%, argent à %d %%, or à %d %% des espèces (+%d, +%d, +%d paillettes).",
	ZONE_MEDAL_MSG        = "%s : %s (%d sur %d espèces). +%d paillettes.",
	ZONE_MEDAL_SAY        = "%s pour %s !",
	ZONE_MEDAL_CATCHUP    = "Médailles de zone : %d de bronze, %d d'argent, %d d'or. +%d paillettes.",
	ZONE_MEDAL_HINT       = "%s : %d espèces sur %d, +%d paillettes.",
	JRN_GOAL_ZONE_MEDAL_1 = "%s : médaille de bronze",
	JRN_GOAL_ZONE_MEDAL_2 = "%s : médaille d'argent",
	JRN_GOAL_ZONE_MEDAL_3 = "%s : médaille d'or",
	JRN_GOAL_ZONE_MEDAL_4 = "%s : sceau",
	MEN_COLL_NEXT_SHORT   = "%d/%d pour « %s »",
}
local EN = {
	ZONE_MEDAL_1          = "bronze",
	ZONE_MEDAL_2          = "silver",
	ZONE_MEDAL_3          = "gold",
	ZONE_MEDAL_SEAL       = "seal",
	ZONE_MEDAL_NAME_1     = "Bronze medal",
	ZONE_MEDAL_NAME_2     = "Silver medal",
	ZONE_MEDAL_NAME_3     = "Gold medal",
	ZONE_MEDAL_TITLE      = "%s: %d of %d species",
	ZONE_MEDAL_LEFT_1     = "%d more for bronze",
	ZONE_MEDAL_LEFT_2     = "%d more for silver",
	ZONE_MEDAL_LEFT_3     = "%d more for gold",
	ZONE_MEDAL_LEFT_4     = "%d more for the seal",
	ZONE_MEDAL_MARK       = "%s %d",
	ZONE_MEDAL_ALL        = "Zone medals: %d bronze · %d silver · %d gold",
	ZONE_MEDAL_TIP        = "Medals: bronze at %d%%, silver at %d%%, gold at %d%% of the species (+%d, +%d, +%d glitter).",
	ZONE_MEDAL_MSG        = "%s: %s (%d of %d species). +%d glitter.",
	ZONE_MEDAL_SAY        = "%s for %s!",
	ZONE_MEDAL_CATCHUP    = "Zone medals: %d bronze, %d silver, %d gold. +%d glitter.",
	ZONE_MEDAL_HINT       = "%s: %d species of %d, +%d glitter.",
	JRN_GOAL_ZONE_MEDAL_1 = "%s: bronze medal",
	JRN_GOAL_ZONE_MEDAL_2 = "%s: silver medal",
	JRN_GOAL_ZONE_MEDAL_3 = "%s: gold medal",
	JRN_GOAL_ZONE_MEDAL_4 = "%s: seal",
	MEN_COLL_NEXT_SHORT   = "%d/%d for “%s”",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.ZONE_MEDAL_STRINGS = { fr = FR, en = EN } end

local M = ns.ZONE_MEDAL
-- un compte par médaille (bronze, argent, or), à zéro
local function Zeros() local t = {}; for index = 1, #M.parts do t[index] = 0 end; return t end
local function On(self)
	return (ns.CompanionOn and ns.CompanionOn() or false) and self.CaptureData ~= nil and self:DB().companionCapture ~= false
end
local function Quiet(self) return ns.Quiet ~= nil and self:Quiet() and true or false end
local function ZoneName(self, zoneID)
	local info = self.MapInfo and self:MapInfo(zoneID)
	return (info and info.name) or tostring(zoneID)
end

-- { [uiMapID] = médaille payée } (compte)
function ns:ZoneMedalRecord()
	local capture = self:CaptureData()
	if type(capture.zoneMedals) ~= "table" then capture.zoneMedals = {} end
	return capture.zoneMedals
end

-- Seuils du bronze, de l'argent et de l'or pour `need` espèces (arrondi supérieur)
function ns:ZoneMedalThresholds(need)
	need = math.max(0, math.floor(tonumber(need) or 0))
	local p = M.parts
	return math.floor((need * p[1] + 99) / 100), math.floor((need * p[2] + 99) / 100), math.floor((need * p[3] + 99) / 100)
end

-- Espèces capturées / à capturer, gardées jusqu'à la prochaine capture
local cache = { key = nil, zones = {} }
function ns.ZoneMedalReset() cache.key, cache.zones = nil, {} end
local function Progress(self, zoneID)
	local capture = self:CaptureData()
	local faction = self.PlayerFaction and self:PlayerFaction() or "?"
	local key = tostring(capture.serial) .. ":" .. tostring(capture.count) .. ":" .. tostring(faction)
	if cache.key ~= key then cache.key, cache.zones = key, {} end
	local hit = cache.zones[zoneID]
	if not hit then
		local have, need = 0, 0
		if self.MenagerieSealProgress then have, need = self:MenagerieSealProgress(zoneID) end
		hit = { have = have, need = need }
		cache.zones[zoneID] = hit
	end
	return hit.have, hit.need
end

-- Médaille méritée par les captures (0 à 3 ; scellée : 3), sans ce qui est payé
local function Earned(self, zoneID)
	local have, need = Progress(self, zoneID)
	if need <= 0 then return 0, have, need end
	local level = 0
	local t = { self:ZoneMedalThresholds(need) }
	for index = 1, 3 do if have >= t[index] then level = index end end
	if self.MenagerieSealed and self:MenagerieSealed(zoneID) then level = 3 end
	return level, have, need
end

-- ns:ZoneMedal(zone) -> niveau (0 à 3), espèces capturées, total, seuil suivant
-- (celui de la médaille suivante, puis celui du sceau après l'or ; nil une
-- fois la zone scellée ou sans liste). Une médaille payée reste gagnée.
function ns:ZoneMedal(zone)
	local zoneID = tonumber(zone)
	if not zoneID or not self.CaptureData then return 0, 0, 0, nil end
	local level, have, need = Earned(self, zoneID)
	if need <= 0 then return 0, have, need, nil end
	local paid = tonumber(self:ZoneMedalRecord()[zoneID]) or 0
	if paid > level then level = math.min(3, paid) end
	local sealed = self.MenagerieSealed and self:MenagerieSealed(zoneID)
	local nextNeed
	if level < 3 then
		nextNeed = (select(level + 1, self:ZoneMedalThresholds(need)))
	elseif not sealed and have < need then
		nextNeed = need
	end
	return level, have, need, nextNeed
end

-- { [1] = zones au bronze ou mieux, [2] = à l'argent ou mieux, [3] = à l'or ou mieux }
-- (médailles gagnées au compte, plus les zones scellées de ce personnage)
function ns:ZoneMedalCounts()
	local out, levels = Zeros(), {}
	if not self.CaptureData then return out end
	for zoneID, level in pairs(self:ZoneMedalRecord()) do
		levels[tonumber(zoneID) or zoneID] = math.min(3, tonumber(level) or 0)
	end
	for _, zoneID in ipairs(self.MenagerieSeals and self:MenagerieSeals() or {}) do levels[zoneID] = 3 end
	for _, level in pairs(levels) do
		for index = 1, level do out[index] = out[index] + 1 end
	end
	return out
end

function ns:ZoneMedalTipLine()
	local p, g = M.parts, M.glitter
	return self:F("ZONE_MEDAL_TIP", p[1], p[2], p[3], g[1], g[2], g[3])
end

local function Touch(self)
	if self.FeatTouch then pcall(self.FeatTouch, self, "zone") end
end

-- Une zone franchit un seuil : paillettes (une fois par zone et par compte),
-- ligne de chat et bulle. opts.quiet : rien ne parle ; opts.noBubble : la
-- ligne seule (le sceau vient de parler). Rend la médaille et les paillettes.
function ns:ZoneMedalCheck(zoneID, opts)
	opts = opts or {}
	zoneID = tonumber(zoneID)
	if not zoneID or ns.zoneMedalsDormant or not On(self) then return nil end
	local record = self:ZoneMedalRecord()
	local paid = tonumber(record[zoneID]) or 0
	if paid >= 3 then return nil end
	local level, have, need = Earned(self, zoneID)
	if level <= paid then return nil end
	local glitter = 0
	for index = paid + 1, level do glitter = glitter + M.glitter[index] end
	record[zoneID] = level
	if self.PaillettesAdd then self:PaillettesAdd(glitter, "medal") end
	Touch(self)
	if not opts.quiet and not Quiet(self) then
		local name = ZoneName(self, zoneID)
		local medal = L["ZONE_MEDAL_NAME_" .. level]
		self:Print(self:F("ZONE_MEDAL_MSG", medal, name, have, need, glitter))
		if not opts.noBubble and self.CompanionSay then
			self:CompanionSay("UNLOCK", { force = true, category = "event", line = "ZONE_MEDAL_SAY", args = { medal, name } })
		end
	end
	return level, glitter
end

-- Rattrapage, une fois par compte : les médailles déjà méritées (zones où
-- l'on a capturé, zones scellées), payées d'un coup, une seule ligne
function ns:ZoneMedalCatchUp()
	if ns.zoneMedalsDormant or not On(self) then return nil end
	local capture = self:CaptureData()
	if capture.zoneMedalsInit then return nil end
	capture.zoneMedalsInit = true
	local zones = {}
	for _, entry in pairs(capture.creatures or {}) do
		local zoneID = type(entry) == "table" and tonumber(entry.zoneID)
		if zoneID then zones[zoneID] = true end
	end
	for _, zoneID in ipairs(self.MenagerieSeals and self:MenagerieSeals() or {}) do zones[zoneID] = true end
	local per, glitter, record = Zeros(), 0, self:ZoneMedalRecord()
	local function Sweep()
		for zoneID in pairs(zones) do
			local paid = tonumber(record[zoneID]) or 0
			local level = Earned(self, zoneID)
			if level > paid then
				for index = paid + 1, level do
					per[index] = per[index] + 1
					glitter = glitter + M.glitter[index]
				end
				record[zoneID] = level
			end
		end
	end
	if self.MenagerieWithPeek then self:MenagerieWithPeek(Sweep) else Sweep() end
	if glitter > 0 then
		if self.PaillettesAdd then self:PaillettesAdd(glitter, "medal") end
		Touch(self)
		if not Quiet(self) then self:Print(self:F("ZONE_MEDAL_CATCHUP", per[1], per[2], per[3], glitter)) end
	end
	return per, glitter
end

-- Objectif du suivi (TrackerGoals.lua) : « <Zone> : médaille de bronze »,
-- n/seuil vers la prochaine médaille, puis le sceau. nil : zone sans liste,
-- scellée, ou sans aucune capture (la ligne « à capturer ici » reste).
function ns:ZoneMedalGoal(zoneID, zoneName)
	if not ns.JournalGoal then return nil end
	local level, have, need, nextNeed = self:ZoneMedal(zoneID)
	if need <= 0 or not nextNeed or have <= 0 then return nil end
	if self.MenagerieSealed and self:MenagerieSealed(zoneID) then return nil end
	local step = math.min(4, level + 1)
	local label = self:F("JRN_GOAL_ZONE_MEDAL_" .. step, tostring(zoneName or zoneID))
	local goal = ns.JournalGoal("medal:" .. zoneID .. ":" .. step, label, have, nextNeed, nil, "menagerie")
	if not goal then return nil end
	goal.brief = label
	local hint = {}
	if step <= 3 then
		hint[1] = self:F("ZONE_MEDAL_HINT", L["ZONE_MEDAL_NAME_" .. step], nextNeed, need, M.glitter[step])
		goal.reward = self:F("MIS_REWARD_PAILLETTES", M.glitter[step])
	else
		local mult = ns.MenagerieDecimal and ns.MenagerieDecimal(ns.SEAL_SHINY_MULT or 1) or tostring(ns.SEAL_SHINY_MULT or 1)
		hint[1] = self:F("JRN_HINT_ZONE_SEAL", mult)
	end
	local zone = self.TrackerZoneCreatures and self:TrackerZoneCreatures(zoneID)
	if zone and #zone.missing > 0 then
		hint[#hint + 1] = L.JRN_HINT_ZONE_CAP
		for index, name in ipairs(zone.missing) do
			if index > (ns.TRACKER_ZONE_NAMES or 6) then
				hint[#hint + 1] = self:F("JRN_HINT_MORE", #zone.missing - (ns.TRACKER_ZONE_NAMES or 6))
				break
			end
			hint[#hint + 1] = "  · " .. name
		end
	end
	goal.hint = hint
	return goal
end

-- ---------------------------------------------------------------------------
-- Quand vérifier : après chaque capture (zone de la créature et zone où l'on
-- est), à l'ouverture de la page Créatures (MenagerieCollectionRefresh), et le
-- rattrapage au premier rafraîchissement du suivi (après celui des sceaux)
-- ---------------------------------------------------------------------------
do
	local resolve = ns.CaptureResolve
	if resolve then
		function ns:CaptureResolve(rolling, ...)
			local target = type(rolling) == "table" and rolling.target or nil
			local zoneID = target and tonumber(target.zoneID)
			local wasSealed = zoneID and self.MenagerieSealed and self:MenagerieSealed(zoneID)
			local success = resolve(self, rolling, ...)
			ns.ZoneMedalReset()
			if success and type(rolling) == "table" and not ns.zoneMedalsDormant then
				local ok, err = pcall(function()
					local zones = {}
					if zoneID then zones[zoneID] = true end
					local here = self.JournalZone and tonumber((self:JournalZone()))
					if here then zones[here] = true end
					for zone in pairs(zones) do
						-- (le sceau vient de parler : la ligne de chat seule)
						local sealedNow = zone == zoneID and not wasSealed and self:MenagerieSealed(zone)
						self:ZoneMedalCheck(zone, { noBubble = sealedNow and true or nil })
					end
				end)
				if not ok and self.RecordError then self:RecordError("zone:medal", err) end
			end
			return success
		end
	end
	local refresh = ns.RefreshJournalTracker
	if refresh then
		function ns:RefreshJournalTracker(...)
			local a, b = refresh(self, ...)
			if not ns.zoneMedalsDormant and not ns.zoneMedalCaughtUp and On(self) then
				ns.zoneMedalCaughtUp = true
				local ok, err = pcall(self.ZoneMedalCatchUp, self)
				if not ok and self.RecordError then self:RecordError("zone:catchup", err) end
			end
			return a, b
		end
	end
end

if ns.Mark then ns.Mark("ZoneMedals") end
