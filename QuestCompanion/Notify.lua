-- Notify.lua -- la créature annonce ce qui entre au carnet, et son cadre brille
-- quand elle parle (QuestCompanion 1.1.0)
--
-- Une nouvelle entrée de la complétion d'une zone (une espèce abattue pour la
-- première fois, un nommé, une ressource récoltée pour la première fois dans
-- la zone, une quête de la zone rendue) : une courte bulle avec le nom et où
-- en est la part (« Bestiaire 13/24 »). Au plus une toutes les NOTIFY_GAP s :
-- ce qui arrive entre-temps est regroupé (« Et 3 de plus au carnet ! »).
-- Le reste (villages, capitales…) a déjà son tampon et sa bulle.
--
-- Pendant qu'elle parle, un liseré doré pulse doucement autour de son cadre :
-- ça attire l'œil sans clignoter.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.NOTIFY_GAP = 6            -- s entre deux annonces du carnet
ns.NOTIFY_TICK = 0.2         -- s entre deux regards sur les annonces en attente
ns.GLOW_ALPHA = 0.55         -- éclat maximal du liseré
ns.GLOW_SPEED = 3            -- pulsations par seconde (en radians × 2π)
ns.GLOW_FADE = 0.4           -- s pour s'éteindre après la bulle

local FR = {
	NOTIFY_PART_bestiary  = "bestiaire",
	NOTIFY_PART_named     = "nommés",
	NOTIFY_PART_gathering = "récolte",
	NOTIFY_PART_quests    = "quêtes",
}
local EN = {
	NOTIFY_PART_bestiary  = "bestiary",
	NOTIFY_PART_named     = "named",
	NOTIFY_PART_gathering = "gathering",
	NOTIFY_PART_quests    = "quests",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.NOTIFY_STRINGS = { fr = FR, en = EN } end

local P = {
	FOUND = {   -- %s = l'entrée, %s = la part (« bestiaire 13/24 »)
		{ "Au carnet : %s ! (%s)", "In the journal: %s! (%s)" },
		{ "Nouveau : %s. (%s)", "New: %s. (%s)" },
		{ "Je note : %s. (%s)", "Noting it down: %s. (%s)" },
	},
	FOUND_MANY = { -- %d = entrées regroupées
		{ "Et %d de plus au carnet !", "And %d more in the journal!" },
		{ "Mon carnet se remplit : %d de plus !", "My journal is filling up: %d more!" },
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
ns.NOTIFY_POOLS = POOLS

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function ModuleOn() return ns.CompanionOn and ns.CompanionOn() or false end

function ns:NotifyState()
	local state = self.notifyState
	if not state then
		state = { at = -math.huge, pending = 0 }
		self.notifyState = state
	end
	return state
end

-- « bestiaire 13/24 » : la part de la zone, après l'ajout
function ns:NotifyPartText(zoneID, partID)
	local done = zoneID and self.ZoneCompletion and self:ZoneCompletion(zoneID)
	for _, part in ipairs(done and done.parts or {}) do
		if part.id == partID then
			return string.format("%s %d/%d", L["NOTIFY_PART_" .. partID] or partID, part.have, part.need)
		end
	end
	-- part hors du pourcentage de la zone (bestiaire, QC 2.0) : comptée à part
	for _, def in ipairs(zoneID and ns.ZONE_PARTS or {}) do
		if def.id == partID and def.exploration == false then
			local ok, part = pcall(def.Compute, self, zoneID)
			if ok and type(part) == "table" and tonumber(part.need) and part.need > 0 then
				return string.format("%s %d/%d", L["NOTIFY_PART_" .. partID] or partID, math.min(tonumber(part.have) or 0, part.need), part.need)
			end
		end
	end
	return L["NOTIFY_PART_" .. partID] or partID
end

-- Une entrée de plus au carnet : dite tout de suite, ou regroupée
function ns:NotifyFound(name, zoneID, partID)
	if not ModuleOn() then return false end
	local state, now = self:NotifyState(), Clock()
	if now - state.at < ns.NOTIFY_GAP then
		state.pending = state.pending + 1
		return false
	end
	-- forcée : elle remplace la bulle générique du même moment (« abattu ! », « quête rendue ! »)
	local said = self:CompanionSay("FOUND", { force = true,
		args = { tostring(name or "?"), self:NotifyPartText(zoneID, partID) } })
	if said then
		-- ce qui attendait reste à annoncer, au prochain écart
		state.at = now
	else
		state.pending = state.pending + 1
	end
	return said and true or false
end

-- Ce qui attendait : une bulle de regroupement, dès que l'écart le permet
function ns:NotifyFlush(now)
	local state = self.notifyState
	if not state or state.pending <= 0 or now - state.at < ns.NOTIFY_GAP then return false end
	local count = state.pending
	local said = self:CompanionSay("FOUND_MANY", { args = { count } })
	-- pas la place (combat, autre bulle) : on réessaie au prochain écart
	state.at = now
	if said then state.pending = 0 end
	return said and true or false
end

-- ---------------------------------------------------------------------------
-- Ce qui entre au carnet
-- ---------------------------------------------------------------------------
-- Espèce (ou nommé) abattue pour la première fois dans la zone
do
	local combat = ns.BestiaryCombat
	if combat then
		function ns:BestiaryCombat(subevent, sourceGUID, sourceFlags, destGUID, ...)
			local entry = destGUID and self.bestiaryUnits and self.bestiaryUnits[destGUID]
			-- une brillante a sa propre bulle (Shiny.lua) : on ne la recouvre pas
			if entry and self.shinyState and self.shinyState.live[destGUID] then entry = nil end
			local before
			if entry then
				local zone = self:BestiaryData()[entry.zoneID]
				local species = zone and zone[entry.npcID]
				before = species and tonumber(species.killed) or 0
			end
			local a, b = combat(self, subevent, sourceGUID, sourceFlags, destGUID, ...)
			if entry and before == 0 then
				local ok, err = pcall(function()
					local zone = self:BestiaryData()[entry.zoneID]
					local species = zone and zone[entry.npcID]
					if species and (tonumber(species.killed) or 0) > 0 then
						local part = (self.BestiaryIsNamed and self:BestiaryIsNamed(species)) and "named" or "bestiary"
						self:NotifyFound(species.name, entry.zoneID, part)
					end
				end)
				if not ok and self.RecordError then self:RecordError("notify:bestiary", err) end
			end
			return a, b
		end
	end
end

-- Ressource récoltée pour la première fois dans la zone
do
	local record = ns.GatheringRecord
	if record then
		function ns:GatheringRecord(itemID, count, zoneID, ...)
			local data = self.GatheringData and self:GatheringData()
			local old = data and data[itemID]
			local before = zoneID and type(old) == "table" and type(old.zones) == "table" and tonumber(old.zones[zoneID]) or 0
			local a, b = record(self, itemID, count, zoneID, ...)
			if zoneID and (before or 0) == 0 and data and type(data[itemID]) == "table" then
				local ok, err = pcall(function()
					local name = ns.ItemInfo(itemID)
					if not name then
						for _, entry in ipairs((self.GatheringZoneBand and self:GatheringZoneBand(zoneID)) or {}) do
							if entry.itemID == itemID then name = entry.name end
						end
					end
					self:NotifyFound(name or tostring(itemID), zoneID, "gathering")
				end)
				if not ok and self.RecordError then self:RecordError("notify:gather", err) end
			end
			return a, b
		end
	end
end

-- Quête de la zone rendue
function ns:NotifyQuest(questID)
	questID = tonumber(questID)
	local zoneID = self.JournalZone and self:JournalZone()
	if not (questID and zoneID and self.ZoneQuestList) then return false end
	for _, quest in ipairs(self:ZoneQuestList(zoneID) or {}) do
		if tonumber(quest.id) == questID then return self:NotifyFound(quest.name, zoneID, "quests") end
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Le cadre brille quand elle parle
-- ---------------------------------------------------------------------------
local function GlowEdges(frame)
	if frame.glow then return frame.glow end
	local glow = {}
	for _, side in ipairs({ "top", "bottom", "left", "right" }) do
		local tex = frame:CreateTexture(nil, "OVERLAY")
		tex:SetTexture(Theme.SOLID)
		if tex.SetBlendMode then tex:SetBlendMode("ADD") end
		tex:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		if side == "top" or side == "bottom" then
			tex:SetPoint(side == "top" and "TOPLEFT" or "BOTTOMLEFT", frame, side == "top" and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
			tex:SetPoint(side == "top" and "TOPRIGHT" or "BOTTOMRIGHT", frame, side == "top" and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
			tex:SetHeight(2)
		else
			tex:SetPoint(side == "left" and "TOPLEFT" or "TOPRIGHT", frame, side == "left" and "TOPLEFT" or "TOPRIGHT", 0, 0)
			tex:SetPoint(side == "left" and "BOTTOMLEFT" or "BOTTOMRIGHT", frame, side == "left" and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, 0)
			tex:SetWidth(2)
		end
		tex:SetAlpha(0)
		tex:Hide()
		glow[#glow + 1] = tex
	end
	frame.glow = glow
	return glow
end

-- Éclat du liseré à l'instant `now` : pulse pendant la bulle, puis s'éteint
function ns:GlowAlpha(now)
	local untilAt = self.companionBubbleUntil
	if not untilAt then return 0 end
	if now < untilAt then
		return ns.GLOW_ALPHA * (0.6 + 0.4 * math.sin(now * ns.GLOW_SPEED * math.pi))
	end
	local after = now - untilAt
	if after >= ns.GLOW_FADE then return 0 end
	return ns.GLOW_ALPHA * 0.6 * (1 - after / ns.GLOW_FADE)
end

function ns:GlowUpdate(now)
	local frame = self.companionFrame
	if not frame then return 0 end
	local alpha = ModuleOn() and self:GlowAlpha(now) or 0
	-- éteint et déjà caché : rien à toucher (appelé à chaque image)
	if alpha <= 0 and (not frame.glow or frame.glowAlpha == 0) then return 0 end
	for _, tex in ipairs(GlowEdges(frame)) do
		if alpha > 0 then tex:SetAlpha(alpha); tex:Show() else tex:Hide() end
	end
	frame.glowAlpha = alpha
	return alpha
end

-- ---------------------------------------------------------------------------
-- Horloge et événements
-- ---------------------------------------------------------------------------
local ok, frame = pcall(CreateFrame, "Frame")
if ok and frame then
	pcall(frame.RegisterEvent, frame, "QUEST_TURNED_IN")
	frame:SetScript("OnEvent", function(_, _, questID)
		local done, err = pcall(ns.NotifyQuest, ns, questID)
		if not done and ns.RecordError then ns:RecordError("notify:quest", err) end
	end)
	-- l'éclat pulse image par image ; les annonces en attente (écart de
	-- NOTIFY_GAP s) se regardent cinq fois par seconde
	local flush = ns.Throttle(ns.NOTIFY_TICK, function()
		local done, err = pcall(ns.NotifyFlush, ns, Clock())
		if not done and ns.RecordError then ns:RecordError("notify:flush", err) end
	end)
	frame:SetScript("OnUpdate", function(f, elapsed)
		local done, err = pcall(ns.GlowUpdate, ns, Clock())
		if not done and ns.RecordError then ns:RecordError("notify:glow", err) end
		flush(f, elapsed)
	end)
	ns.notifyEventFrame = frame
end

if ns.Mark then ns.Mark("Notify") end
