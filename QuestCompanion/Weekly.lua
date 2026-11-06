-- Weekly.lua -- missions de la semaine (QuestCompanion 1.4.0)
--
-- En plus des missions du jour (Daily.lua) : trois missions plus longues,
-- tirées à la première zone de la semaine, qui tiennent jusqu'à la remise à
-- zéro hebdomadaire du serveur (à défaut, la semaine du calendrier).
-- Elles nourrissent la ménagerie : capturer, capturer un élite ou un rare,
-- enchaîner les missions du jour, abattre, tamponner le carnet, récolter,
-- rendre des quêtes. Une capture au moins dans le lot si la capture est
-- allumée, et (1.6.0) toujours une chasse au brillant : en abattre un, ou en
-- capturer un.
-- Chaque mission faite : un Lasso tressé et une friandise ; les trois : un
-- Sifflet du dompteur et un Festin (ns.MISSION_REWARDS, Daily.lua).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.WEEKLY_COUNT = 3
local WEEKLY = {
	{ kind = "captures",     need = 6 },
	{ kind = "captureNamed", need = 1 },
	{ kind = "dailies",      need = 8 },
	{ kind = "kills",        need = 150 },
	{ kind = "stamps",       need = 6 },
	{ kind = "gather",       need = 20 },
	{ kind = "turnins",      need = 15 },
	{ kind = "shinyKill",    need = 1 },
	{ kind = "shinyCapture", need = 1 },
}
local CAPTURE_KINDS = { captures = true, captureNamed = true, shinyCapture = true }
-- une chasse au brillant par semaine (1.6.0)
local SHINY_KINDS = { shinyKill = true, shinyCapture = true }
ns.WEEKLY_SHINY_KINDS = SHINY_KINDS
ns.WEEKLY_MISSIONS = WEEKLY

local FR = {
	WK_captures     = "Capture %d créatures",
	WK_captureNamed = "Capture un élite ou un rare",
	WK_dailies      = "Fais %d missions du jour",
	WK_kills        = "Abats %d ennemis",
	WK_stamps       = "Gagne %d tampons du carnet",
	WK_gather       = "Récolte %d fois",
	WK_turnins      = "Rends %d quêtes",
	WK_shinyKill    = "Abats une créature brillante",
	WK_shinyCapture = "Capture une créature brillante",
	WK_SOURCE       = "mission de la semaine",
	WK_ENDS         = "Nouvelles missions dans %s.",
	WK_ALL_BONUS    = "Les 3 missions de la semaine : un Sifflet du dompteur et un Festin en plus.",
	WK_ALL_DONE     = "Semaine bouclée ! Nouvelles missions à la remise à zéro.",
	WK_DAYS         = "%d j",
	WK_HOURS        = "%d h",
}
local EN = {
	WK_captures     = "Capture %d creatures",
	WK_captureNamed = "Capture an elite or a rare",
	WK_dailies      = "Complete %d daily missions",
	WK_kills        = "Defeat %d enemies",
	WK_stamps       = "Earn %d journal stamps",
	WK_gather       = "Gather %d times",
	WK_turnins      = "Turn in %d quests",
	WK_shinyKill    = "Defeat a shiny creature",
	WK_shinyCapture = "Capture a shiny creature",
	WK_SOURCE       = "mission of the week",
	WK_ENDS         = "New missions in %s.",
	WK_ALL_BONUS    = "All 3 weekly missions: a Tamer's whistle and a Feast on top.",
	WK_ALL_DONE     = "Week wrapped up! New missions at the reset.",
	WK_DAYS         = "%d d",
	WK_HOURS        = "%d h",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.WEEKLY_STRINGS = { fr = FR, en = EN } end

local P = {
	WEEKLY_NEW = {
		{ "Nouvelle semaine, nouvelles missions ! Elles sont dans le carnet.", "New week, new missions! They're in the journal." },
		{ "Trois grosses missions cette semaine. Tu tiendras le rythme ? J'en doute.", "Three big missions this week. Can you keep up? I doubt it." },
	},
	WEEKLY_DONE = {
		{ "Mission de la semaine bouclée ! Tiens, un lasso.", "Weekly mission done! Here, a lasso." },
		{ "Et une de la semaine ! Je commence à être fier de toi. Un peu.", "One weekly down! I'm starting to be proud of you. A bit." },
	},
	WEEKLY_ALL = {
		{ "Les trois de la semaine ! Un sifflet de dompteur, rien que ça !", "All three weekly missions! A tamer's whistle, no less!" },
	},
}
local LINES_FR, LINES_EN, POOLS = {}, {}, {}
for name, lines in pairs(P) do
	local keys = {}
	for index, pair in ipairs(lines) do
		local key = "COMP_SAY_" .. name .. (index > 1 and ("_" .. index) or "")
		LINES_FR[key], LINES_EN[key] = pair[1], pair[2]
		keys[index] = key
	end
	POOLS[name] = keys
end
ns.RegisterStrings(LINES_FR, LINES_EN)
if type(ns.COMPANION_POOLS) == "table" then
	for name, keys in pairs(POOLS) do ns.COMPANION_POOLS[name] = keys end
end
local shared = ns.COMPANION_LINE_STRINGS
if type(shared) == "table" then
	for key, text in pairs(LINES_FR) do shared.fr[key], shared.en[key] = text, LINES_EN[key] end
end
ns.WEEKLY_POOLS = POOLS

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function G(name) return rawget(_G, name) end

-- ---------------------------------------------------------------------------
-- La semaine : celle du serveur (remise à zéro hebdomadaire), sinon celle du
-- calendrier
-- ---------------------------------------------------------------------------
local WEEK = 7 * 24 * 3600
function ns:WeeklyResetIn()
	local api = G("C_DateAndTime")
	local left = type(api) == "table" and ns.Plain(Call(api.GetSecondsUntilWeeklyReset)) or nil
	return tonumber(left)
end

function ns:WeeklyId()
	local now = tonumber(Call(G("time")))
	local left = self:WeeklyResetIn()
	if now and left and left > 0 then
		return "r" .. tostring(math.floor((now + left) / WEEK + 0.5))
	end
	local date = G("date") or (os and os.date)
	return "w" .. tostring(Call(date, "%Y-%W") or "?")
end

function ns:WeeklyData()
	local data = self:CompanionData()
	local weekly = type(data.weekly) == "table" and data.weekly or {}
	weekly.missions = type(weekly.missions) == "table" and weekly.missions or {}
	data.weekly = weekly
	return weekly
end

local function CaptureOn(self)
	return self.CaptureData ~= nil and self:DB().companionCapture ~= false
end

-- Tire les trois missions de la semaine (une capture au moins si allumée)
-- `later` : la bulle attend (celle des missions du jour vient de partir)
function ns:WeeklyDraw(later)
	local weekly = self:WeeklyData()
	local pool, captures, shinies = {}, {}, {}
	for _, def in ipairs(WEEKLY) do
		if SHINY_KINDS[def.kind] then
			if not CAPTURE_KINDS[def.kind] or CaptureOn(self) then shinies[#shinies + 1] = def end
		elseif CAPTURE_KINDS[def.kind] then
			if CaptureOn(self) then captures[#captures + 1] = def end
		else
			pool[#pool + 1] = def
		end
	end
	local picked = {}
	if #captures > 0 then picked[#picked + 1] = table.remove(captures, math.random(#captures)) end
	if #shinies > 0 then picked[#picked + 1] = table.remove(shinies, math.random(#shinies)) end
	for _, def in ipairs(captures) do pool[#pool + 1] = def end
	while #picked < ns.WEEKLY_COUNT and #pool > 0 do
		picked[#picked + 1] = table.remove(pool, math.random(#pool))
	end
	local missions = {}
	for index, def in ipairs(picked) do
		missions[index] = { kind = def.kind, need = def.need, have = 0, source = "week" }
	end
	weekly.week, weekly.missions, weekly.allDone = self:WeeklyId(), missions, nil
	local timer = G("C_Timer")
	if later and type(timer) == "table" and type(timer.After) == "function" then
		pcall(timer.After, 8, function() ns:CompanionSay("WEEKLY_NEW", { category = "event" }) end)
	elseif not later then
		self:CompanionSay("WEEKLY_NEW", { category = "event" })
	end
	if self.DailyChanged then self:DailyChanged() end
	return missions
end

function ns:WeeklyCurrent()
	local weekly = self:WeeklyData()
	return weekly.week == self:WeeklyId() and weekly or nil
end

-- La semaine a tourné : nouveau tirage (missions coupées : rien)
function ns:WeeklyPoll(later)
	if not (self.DailyMissionsOn and self:DailyMissionsOn()) then return false end
	if self:WeeklyCurrent() then return false end
	if not (self.JournalZone and self:JournalZone()) then return false end
	self:WeeklyDraw(later)
	return true
end

-- Un événement : chaque mission de la semaine concernée avance
function ns:WeeklyEvent(kind, amount)
	if not (self.DailyMissionsOn and self:DailyMissionsOn()) then return false end
	local weekly = self:WeeklyCurrent()
	if not weekly then return false end
	local moved = false
	for _, mission in ipairs(weekly.missions) do
		if not mission.done and mission.kind == kind then
			mission.have = math.min(mission.need, (mission.have or 0) + (tonumber(amount) or 1))
			moved = true
			if mission.have >= mission.need then
				mission.done = true
				local companion = self:CompanionData()
				companion.missionsDone = (tonumber(companion.missionsDone) or 0) + 1
				self:MissionGrant("weekly")
				if self.CompanionFx then self:CompanionFx("bounce") end
				local all = true
				for _, other in ipairs(weekly.missions) do if not other.done then all = false end end
				if all then
					weekly.allDone = true
					self:MissionGrant("allWeekly")
					self:CompanionSay("WEEKLY_ALL", { force = true, category = "event" })
					if self.CompanionFx then self:CompanionFx("hearts") end
				else
					self:CompanionSay("WEEKLY_DONE", { force = true, category = "event" })
				end
			end
		end
	end
	if moved and self.DailyChanged then self:DailyChanged() end
	return moved
end

function ns:WeeklyLabel(mission)
	if mission.kind == "captureNamed" then return L.WK_captureNamed end
	return self:F("WK_" .. tostring(mission.kind), mission.need)
end

-- « 3 j » ou « 7 h » avant la remise à zéro (nil sans la date du serveur)
function ns:WeeklyEndsText()
	local left = self:WeeklyResetIn()
	if not left or left <= 0 then return nil end
	if left >= 86400 then return self:F("WK_DAYS", math.floor(left / 86400)) end
	return self:F("WK_HOURS", math.max(1, math.floor(left / 3600)))
end

-- ---------------------------------------------------------------------------
-- Ce qui fait avancer la semaine
-- ---------------------------------------------------------------------------
-- les événements des missions du jour servent aussi à la semaine
do
	local event = ns.MissionEvent
	if event then
		function ns:MissionEvent(kind, amount, zoneID, ...)
			local moved = event(self, kind, amount, zoneID, ...)
			if kind == "kills" or kind == "turnins" or kind == "gather" then
				local ok, err = pcall(self.WeeklyEvent, self, kind, amount)
				if not ok and self.RecordError then self:RecordError("weekly:event", err) end
			end
			return moved
		end
	end
	local poll = ns.DailyPoll
	if poll then
		function ns:DailyPoll(...)
			local drawn = poll(self, ...)
			local ok, err = pcall(self.WeeklyPoll, self, drawn)
			if not ok and self.RecordError then self:RecordError("weekly:poll", err) end
			return drawn
		end
	end
end

ns:RegisterCallback("STAMP", function(self, stamp)
	if type(stamp) ~= "table" or stamp.new == false then return end
	local ok, err = pcall(self.WeeklyEvent, self, "stamps", 1)
	if not ok and self.RecordError then self:RecordError("weekly:stamp", err) end
end)

if ns.Mark then ns.Mark("Weekly") end
