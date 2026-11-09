-- Group.lua -- le compagnon en groupe (QuestCompanion), lecture locale
--
-- Ce que le client sait déjà des membres du groupe (niveau, classe, carte,
-- portée de vue, mort, connexion), sans échange entre addons :
--   * composition : pas de soigneur (prêtre, druide, chaman, paladin), ou
--     groupe bien équilibré, quand le groupe se stabilise (10 s sans changer) ;
--   * donjon : niveaux des membres face à la tranche du donjon (devant ou dedans) ;
--   * resté en arrière : hors de vue depuis GROUP_BEHIND secondes, sur la même
--     carte, hors combat et hors lieu sûr, ni en vol ;
--   * encore ailleurs : sur une autre carte depuis GROUP_ELSEWHERE secondes,
--     alors qu'on est devant ou dans un donjon ;
--   * morts (et le soigneur), déconnexions.
-- Rien en raid. Composition, donjon, retard : conseils (catégorie « advice »,
-- dès le cran Calme) ; morts et déconnexions : réactions (cran Normal).
local ADDON, ns = ...
if ns.blocked then return end

ns.GROUP_HEALERS = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }
ns.GROUP_STABLE = 10        -- s sans changement avant de commenter la composition
ns.GROUP_BEHIND = 90        -- s hors de vue avant « resté en arrière »
ns.GROUP_ELSEWHERE = 120    -- s sur une autre carte avant « encore ailleurs »
ns.GROUP_POLL = 2

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end
local function G(name) return rawget(_G, name) end

local function InCombat()
	return Call(G("InCombatLockdown")) == true or Call(G("UnitAffectingCombat"), "player") == true
end

-- Membres du groupe (party1..4), hors raid. nil si pas en groupe.
function ns:GroupMembers()
	if Call(G("IsInRaid")) then return nil end
	if not Call(G("IsInGroup")) then return nil end
	local members = {}
	for index = 1, 4 do
		local unit = "party" .. index
		if Call(G("UnitExists"), unit) then
			local _, class = Call(G("UnitClass"), unit)
			members[#members + 1] = {
				unit = unit,
				name = Call(G("UnitName"), unit) or unit,
				class = class,
				level = tonumber(Call(G("UnitLevel"), unit)) or 0,
			}
		end
	end
	return #members > 0 and members or nil
end

function ns:GroupState()
	local state = self.groupState
	if not state then
		state = { said = {}, unseen = {}, away = {}, dead = {}, offline = {} }
		self.groupState = state
	end
	return state
end

local function Say(self, pool, args, advice)
	return (self:CompanionSay(pool, { category = advice and "advice" or nil, args = args }))
end

-- ---------------------------------------------------------------------------
-- Composition
-- ---------------------------------------------------------------------------
function ns:GroupCheckComposition(now, members)
	local state = self:GroupState()
	local names = {}
	for _, member in ipairs(members) do names[#names + 1] = member.name end
	table.sort(names)
	local signature = table.concat(names, ",")
	if signature ~= state.signature then
		state.signature, state.changedAt = signature, now
		return false
	end
	if state.said["roster:" .. signature] or now - (state.changedAt or now) < self.GROUP_STABLE then return false end
	local _, mine = Call(G("UnitClass"), "player")
	local healer = self.GROUP_HEALERS[mine or ""] or false
	for _, member in ipairs(members) do healer = healer or self.GROUP_HEALERS[member.class or ""] or false end
	-- petit groupe avec soigneur : rien à dire, mais c'est réglé
	if healer and #members < 4 then
		state.said["roster:" .. signature] = true
		return false
	end
	local said = Say(self, healer and "GROUP_BALANCED" or "GROUP_NO_HEALER", nil, true)
	if said then state.said["roster:" .. signature] = true end
	return said and true or false
end

-- ---------------------------------------------------------------------------
-- Donjon : niveaux face à la tranche
-- ---------------------------------------------------------------------------
function ns:GroupCheckDungeon(members)
	if not self.DetectDungeon then return false end
	local entry = self:DetectDungeon()
	local state = self:GroupState()
	if not entry then state.dungeon = nil; return false end
	state.dungeon = entry.key
	if state.said["dungeon:" .. tostring(entry.key)] then return false end
	local low = self:DungeonRange(entry)
	if not low then return false end
	local lowest
	for _, member in ipairs(members) do
		if member.level > 0 and member.level < low and (not lowest or member.level < lowest.level) then lowest = member end
	end
	local said
	if lowest then
		said = Say(self, "GROUP_LOW_LEVEL", { lowest.name, low - lowest.level }, true)
	else
		said = Say(self, "GROUP_IN_RANGE", nil, true)
	end
	if said then state.said["dungeon:" .. tostring(entry.key)] = true end
	return said and true or false
end

-- ---------------------------------------------------------------------------
-- Resté en arrière, encore ailleurs
-- ---------------------------------------------------------------------------
local function MapOf(unit)
	if not (C_Map and type(C_Map.GetBestMapForUnit) == "function") then return nil end
	return Call(C_Map.GetBestMapForUnit, unit)
end

function ns:GroupCheckPositions(now, members)
	local state = self:GroupState()
	-- en vol : personne n'est « en arrière » (le combat est écarté par GroupEvaluate)
	if Call(G("UnitOnTaxi"), "player") then return false end
	local myMap = MapOf("player")
	local safe = self.AdviceInSafePlace and self:AdviceInSafePlace() or false
	for _, member in ipairs(members) do
		local unit, name = member.unit, member.name
		local online = Call(G("UnitIsConnected"), unit) ~= false
		local theirMap = MapOf(unit)
		if online and not Call(G("UnitOnTaxi"), unit) then
			-- sur une autre carte, alors qu'on est au donjon
			if myMap and theirMap and theirMap ~= myMap then
				state.away[name] = state.away[name] or now
				if state.dungeon and now - state.away[name] >= self.GROUP_ELSEWHERE
					and not state.said["away:" .. name .. ":" .. tostring(state.dungeon)] then
					local info = self:MapInfo(theirMap)
					if Say(self, "GROUP_ELSEWHERE", { name, (info and info.name) or "?" }, true) then
						state.said["away:" .. name .. ":" .. tostring(state.dungeon)] = true
						return true
					end
				end
			else
				state.away[name] = nil
			end
			-- même carte, hors de vue
			if myMap and theirMap == myMap and not safe and not Call(G("UnitIsVisible"), unit) then
				state.unseen[name] = state.unseen[name] or now
				if now - state.unseen[name] >= self.GROUP_BEHIND and not state.said["behind:" .. name] then
					if Say(self, "GROUP_BEHIND", { name }, true) then
						state.said["behind:" .. name] = true
						return true
					end
				end
			else
				state.unseen[name] = nil
				-- revenu en vue : il pourra de nouveau être signalé à la prochaine sortie
				if safe then state.said["behind:" .. name] = nil end
			end
		end
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Morts et déconnexions
-- ---------------------------------------------------------------------------
function ns:GroupCheckStatus(members)
	local state = self:GroupState()
	for _, member in ipairs(members) do
		local unit, name = member.unit, member.name
		local dead = Call(G("UnitIsDeadOrGhost"), unit) == true
		if dead and not state.dead[name] then
			state.dead[name] = true
			local pool = self.GROUP_HEALERS[member.class or ""] and "GROUP_HEALER_DEAD" or "GROUP_DEAD"
			Say(self, pool, { name })
			return true
		elseif not dead then
			state.dead[name] = nil
		end
		local offline = Call(G("UnitIsConnected"), unit) == false
		if offline and not state.offline[name] then
			state.offline[name] = true
			Say(self, "GROUP_OFFLINE", { name })
			return true
		elseif not offline then
			state.offline[name] = nil
		end
	end
	return false
end

-- Un examen complet ; renvoie true si le compagnon a parlé
function ns:GroupEvaluate(now)
	if not (self.CompanionOn and self.CompanionOn()) then return false end
	now = now or self.Now()
	local members = self:GroupMembers()
	if not members then
		self.groupState = nil
		return false
	end
	if self:GroupCheckStatus(members) then return true end
	if InCombat() then return false end
	if self:GroupCheckComposition(now, members) then return true end
	if self:GroupCheckDungeon(members) then return true end
	return self:GroupCheckPositions(now, members)
end

local ok, frame = pcall(CreateFrame, "Frame")
if ok and frame then
	for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED" }) do
		pcall(frame.RegisterEvent, frame, event)
	end
	frame:SetScript("OnEvent", function()
		local done, err = pcall(ns.GroupEvaluate, ns)
		if not done then ns:RecordError("group:event", err) end
	end)
	-- 2.11.2 (fiche 25) : regardé dix fois par seconde sur l'horloge de
	-- l'addon (l'échéance reste ns.groupNextAt), plus d'OnUpdate permanent
	ns.Every("group", ns.CLOCK_POLL, function()
		local now = ns.Now()
		if (ns.groupNextAt or 0) > now then return end
		ns.groupNextAt = now + ns.GROUP_POLL
		local done, err = pcall(ns.GroupEvaluate, ns, now)
		if not done then ns:RecordError("group:poll", err) end
	end)
	ns.groupEventFrame = frame
end

if ns.Mark then ns.Mark("Group") end
