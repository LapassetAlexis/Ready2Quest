-- Shiny.lua -- créatures brillantes et ouverture de coffre animée (QuestCompanion 1.1.0)
--
-- Une petite chasse : la première fois que tu cibles ou survoles un monstre
-- (une fois par monstre, par son GUID), il a SHINY_CHANCE d'être brillant
-- (×SHINY_RANK_MULT pour un élite ou un rare). La créature le voit : bulle,
-- « ! », étincelles, et une étoile au-dessus de sa tête (icône de cible, si tu
-- joues seul ou mènes le groupe, et s'il n'en a pas déjà une).
--   * abattu : fiche dorée au bestiaire, une friandise (parfois un Festin), un
--     souvenir (avec photo si elle est permise) ;
--   * 5, 15 et 30 brillantes : un cadre, un fond et une aura qu'on ne trouve
--     dans aucun coffre.
-- Ouverture de coffre : les objets se révèlent un par un, la créature
-- s'emballe (réglage « Ouverture animée des coffres »).
-- Réglages : page « Au jour le jour » (étoile, ouverture animée).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.SHINY_CHANCE = ns.SHINY_CHANCE or (1 / 150)
ns.SHINY_RANK_MULT = 3
ns.SHINY_FESTIN_CHANCE = 0.15
ns.SHINY_RANKS = { elite = true, rare = true, rareelite = true, worldboss = true }
ns.SHINY_MARK = 1                 -- icône de cible : l'étoile
ns.SHINY_AURA_EVERY = 1.5         -- s entre deux étincelles de l'aura
ns.CHEST_REVEAL_STEP = 0.3        -- s entre deux objets révélés
local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
ns.SHINY_STAR = STAR

-- Cosmétiques des brillantes (hors coffres : tier 0, débloqués ici)
local REWARDS = {
	{ count = 5,  kind = "frame", def = { id = "sparkle", label = "COMP_FRAME_SPARKLE", tier = 0, unlock = { shiny = 5 },
		edge = { 1.0, 0.89, 0.48, 1 }, inner = { 0.62, 0.50, 0.18, 0.9 } } },
	{ count = 15, kind = "bg", def = { id = "stardust", label = "COMP_BG_STARDUST", tier = 0, unlock = { shiny = 15 },
		color = { 0.07, 0.05, 0.14, 0.92 }, stars = true } },
	{ count = 30, kind = "orn", def = { id = "aura", key = "companionOrnAura", label = "COMP_ORN_AURA", tier = 0,
		unlock = { shiny = 30 } } },
	-- 1.2.0 : le bébé hippogriffe (catalogue des apparences, CompanionData.lua)
	{ count = 50, kind = "app", id = "hippogryph" },
}
for _, reward in ipairs(REWARDS) do
	if not reward.def and reward.kind == "app" then
		for _, def in ipairs(ns.COMPANION_APPEARANCES or {}) do if def.id == reward.id then reward.def = def end end
	end
end
ns.SHINY_REWARDS = REWARDS
local LISTS = { app = "COMPANION_APPEARANCES", frame = "COMPANION_FRAMES", bg = "COMPANION_BACKGROUNDS", orn = "COMPANION_ORNAMENTS" }
for _, reward in ipairs(REWARDS) do
	local list = ns[LISTS[reward.kind]]
	if type(list) == "table" and reward.def then
		local present = false
		for _, def in ipairs(list) do if def.id == reward.def.id then present = true end end
		if not present then list[#list + 1] = reward.def end
	end
end

local FR = {
	COMP_FRAME_SPARKLE     = "Étincelant",
	COMP_BG_STARDUST       = "Poussière d'étoiles",
	COMP_ORN_AURA          = "Aura scintillante",
	COMP_REQ_shiny         = "%d brillantes",
	JRN_STAT_shiny         = "brillantes",
	SHINY_MSG_UNLOCK       = "%d créatures brillantes ! Nouveau : %s.",
	MEM_TXT_shiny          = "Une créature brillante : %s !",
	SHINY_CARD             = "Brillante !",
	SHINY_PREV             = "Brillante, abattue le %s.",
	SHINY_EVO              = "Brillantes : %d  ·  prochain cadeau à %d",
	SHINY_EVO_DONE         = "Brillantes : %d  ·  tous leurs cadeaux sont à toi",
	OPT_PAGE_DAILY         = "Au jour le jour",
	OPT_DAILY_MARK         = "Étoile sur les brillantes",
	OPT_DAILY_MARK_DESC    = "Une étoile au-dessus d'une créature brillante, si tu joues seul ou mènes le groupe, et si elle n'a pas déjà d'icône.",
	OPT_DAILY_CHEST        = "Ouverture animée des coffres",
}
local EN = {
	COMP_FRAME_SPARKLE     = "Sparkling",
	COMP_BG_STARDUST       = "Stardust",
	COMP_ORN_AURA          = "Shimmering aura",
	COMP_REQ_shiny         = "%d shinies",
	JRN_STAT_shiny         = "shinies",
	SHINY_MSG_UNLOCK       = "%d shiny creatures! New: %s.",
	MEM_TXT_shiny          = "A shiny creature: %s!",
	SHINY_CARD             = "Shiny!",
	SHINY_PREV             = "Shiny, defeated on %s.",
	SHINY_EVO              = "Shinies: %d  ·  next gift at %d",
	SHINY_EVO_DONE         = "Shinies: %d  ·  all their gifts are yours",
	OPT_PAGE_DAILY         = "Day by day",
	OPT_DAILY_MARK         = "Star on shinies",
	OPT_DAILY_MARK_DESC    = "A star above a shiny creature, if you play solo or lead the group, and if it has no icon yet.",
	OPT_DAILY_CHEST        = "Animated chest opening",
}
ns.RegisterStrings(FR, EN)
ns.SHINY_STRINGS = { fr = FR, en = EN }
-- libellés du catalogue : même registre que les autres cosmétiques
if type(ns.COMPANION_STRINGS) == "table" then
	for _, key in ipairs({ "COMP_FRAME_SPARKLE", "COMP_BG_STARDUST", "COMP_ORN_AURA", "COMP_REQ_shiny" }) do
		ns.COMPANION_STRINGS.fr[key], ns.COMPANION_STRINGS.en[key] = FR[key], EN[key]
	end
end
if type(ns.MEMORY_STRINGS) == "table" then
	ns.MEMORY_STRINGS.fr.MEM_TXT_shiny, ns.MEMORY_STRINGS.en.MEM_TXT_shiny = FR.MEM_TXT_shiny, EN.MEM_TXT_shiny
end
if type(ns.MEMORY_PHOTO_KINDS) == "table" then ns.MEMORY_PHOTO_KINDS.shiny = true end

local P = {
	SHINY_SPOTTED = { -- %s = la créature
		{ "Regarde ! %s… il brille !", "Look! %s… it's shining!" },
		{ "Waouh, %s tout brillant ! On le chasse ?", "Wow, a shiny %s! Shall we hunt it?" },
		{ "%s scintille ! Vite, avant qu'il file !", "%s is sparkling! Quick, before it runs off!" },
	},
	SHINY_KILLED = {  -- %s = la créature
		{ "On l'a eu ! %s brillant, dans mon carnet !", "We got it! A shiny %s, in my journal!" },
		{ "%s brillant… je n'en reviens pas !", "A shiny %s… I can't believe it!" },
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
ns.SHINY_POOLS = POOLS

if type(ns.COMPANION_FX) == "table" then
	ns.COMPANION_FX.sparkle = { duration = 1.4, count = 6, color = { 1.0, 0.89, 0.48 } }
end

ns.RegisterDefaults({
	companionShinyMark = true,
	companionChestAnim = true,
	companionOrnAura = true,
})
-- l'aura a sa ligne dans la sous-page « Ornements », comme les autres
for _, page in ipairs(ns.OPTION_PAGES or {}) do
	if page.id == "companionOrnaments" and type(page.rows) == "table" then
		local present = false
		for _, row in ipairs(page.rows) do if row.key == "companionOrnAura" then present = true end end
		if not present then page.rows[#page.rows + 1] = { key = "companionOrnAura", label = "COMP_ORN_AURA", kind = "bool" } end
	end
end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function ModuleOn() return ns.CompanionOn and ns.CompanionOn() or false end

-- ---------------------------------------------------------------------------
-- Données
-- ---------------------------------------------------------------------------
function ns:ShinyData()
	local data = self:CompanionData()
	local shiny = type(data.shiny) == "table" and data.shiny or {}
	shiny.count = math.max(0, math.floor(tonumber(shiny.count) or 0))
	shiny.zones = type(shiny.zones) == "table" and shiny.zones or {}
	data.shiny = shiny
	return shiny
end

function ns:ShinyState()
	local state = self.shinyState
	if not state then
		state = { rolled = {}, rolledCount = 0, live = {}, auraAt = 0 }
		self.shinyState = state
	end
	return state
end

-- Date (temps réel) de la brillante abattue de cette espèce, ou nil
function ns:ShinyFound(zoneID, npcID)
	local zone = zoneID and self:ShinyData().zones[zoneID]
	return zone and zone[npcID] or nil
end

function ns:ShinyZoneCount(zoneID)
	local count = 0
	for _ in pairs(self:ShinyData().zones[zoneID] or {}) do count = count + 1 end
	return count
end

-- Prochain palier de cosmétique (nombre), nil si tout est gagné
function ns:ShinyNextReward()
	local count = self:ShinyData().count
	for _, reward in ipairs(REWARDS) do
		if count < reward.count then return reward end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Repérer, marquer, abattre
-- ---------------------------------------------------------------------------
function ns:ShinyRoll(unit)
	local class = Call(G("UnitClassification"), unit)
	local chance = (tonumber(ns.SHINY_CHANCE) or 0) * (ns.SHINY_RANKS[class or ""] and ns.SHINY_RANK_MULT or 1)
	return chance > 0 and math.random() < chance
end

-- Étoile au-dessus : seul ou chef du groupe, et pas d'icône déjà posée
function ns:ShinyMark(unit)
	if self:DB().companionShinyMark == false then return false end
	-- une icône déjà posée, ou une valeur secrète (Forever) : on n'y touche pas
	local icon = Call(G("GetRaidTargetIndex"), unit)
	if icon ~= nil and ns.Plain(icon) == nil then return false end
	if ns.Plain(icon) then return false end
	if Call(G("IsInGroup")) and not Call(G("UnitIsGroupLeader"), "player") then return false end
	if type(G("SetRaidTarget")) ~= "function" then return false end
	Call(G("SetRaidTarget"), unit, ns.SHINY_MARK)
	return true
end

function ns:ShinySpot(unit, guid, entry, species)
	local state = self:ShinyState()
	local name = (species and species.name) or Call(G("UnitName"), unit) or "?"
	state.live[guid] = { zoneID = entry.zoneID, npcID = entry.npcID, name = name, at = Clock() }
	self:CompanionSay("SHINY_SPOTTED", { force = true, args = { name } })
	if self.CompanionFx then self:CompanionFx("alert"); self:CompanionFx("sparkle") end
	state.live[guid].marked = self:ShinyMark(unit)
	return state.live[guid]
end

-- Un monstre repéré pour la première fois : le tirage, une fois par GUID
do
	local see = ns.BestiarySeeUnit
	if see then
		function ns:BestiarySeeUnit(unit, ...)
			local species = see(self, unit, ...)
			if species and ModuleOn() then
				local ok, err = pcall(function()
					local guid = Call(G("UnitGUID"), unit)
					local entry = guid and self.bestiaryUnits and self.bestiaryUnits[guid]
					local state = self:ShinyState()
					if not entry or state.rolled[guid] then return end
					-- une mémoire de session : vidée de temps en temps, sans perdre les brillantes vivantes
					if state.rolledCount > 5000 then state.rolled, state.rolledCount = {}, 0 end
					state.rolled[guid], state.rolledCount = true, state.rolledCount + 1
					if self:ShinyRoll(unit) then self:ShinySpot(unit, guid, entry, species) end
				end)
				if not ok and self.RecordError then self:RecordError("shiny:see", err) end
			end
			return species
		end
	end
end

function ns:ShinyKill(guid, info)
	local state = self:ShinyState()
	state.live[guid] = nil
	local shiny = self:ShinyData()
	shiny.count = shiny.count + 1
	shiny.zones[info.zoneID] = shiny.zones[info.zoneID] or {}
	if not shiny.zones[info.zoneID][info.npcID] then
		shiny.zones[info.zoneID][info.npcID] = Call(G("time")) or 0
	end
	local kind = math.random() < ns.SHINY_FESTIN_CHANCE and "festin" or (self.TreatRandom and self:TreatRandom())
	if kind and self.TreatGrant then self:TreatGrant(kind, { quiet = true }) end
	if self.MemoryRecord then
		self:MemoryRecord("shiny", "shiny:" .. shiny.count, { info.name }, { zone = info.zoneName, npc = info.npcID })
	end
	self:CompanionSay("SHINY_KILLED", { force = true, args = { info.name } })
	if self.CompanionFx then self:CompanionFx("bounce"); self:CompanionFx("sparkle") end
	self:ShinyCheckRewards()
	if self.RefreshJournalTracker then pcall(self.RefreshJournalTracker, self) end
	if self.journalFrame and self.journalFrame:IsShown() and self.RefreshJournal then pcall(self.RefreshJournal, self) end
	return kind
end

-- Paliers de brillantes : le cosmétique se débloque (une fois)
function ns:ShinyCheckRewards()
	local count = self:ShinyData().count
	local unlocked = self:CompanionData().unlocked
	local fresh = {}
	for _, reward in ipairs(REWARDS) do
		local key = reward.kind .. ":" .. reward.def.id
		if count >= reward.count and not unlocked[key] then
			unlocked[key] = true
			fresh[#fresh + 1] = reward
			local label = L[reward.def.label]
			self:Print(self:F("SHINY_MSG_UNLOCK", reward.count, label))
			self:CompanionSay("UNLOCK", { force = true, args = { label } })
		end
	end
	if #fresh > 0 and self.CompanionApplyOrnaments then pcall(self.CompanionApplyOrnaments, self) end
	return fresh
end

-- Une brillante vivante comptée abattue par le bestiaire (journal de combat
-- ou message d'XP : Bestiary.lua, BestiaryOnKill) est une brillante abattue
do
	local onKill = ns.BestiaryOnKill
	if onKill then
		function ns:BestiaryOnKill(guid, ...)
			local state = self.shinyState
			local info = state and guid and state.live[guid]
			if info then
				local ok, err = pcall(self.ShinyKill, self, guid, info)
				if not ok and self.RecordError then self:RecordError("shiny:kill", err) end
			end
			return onKill(self, guid, ...)
		end
	end
	-- morte sans être comptée (tuée par d'autres) : elle n'est plus à guetter
	local combat = ns.BestiaryCombat
	if combat then
		function ns:BestiaryCombat(subevent, sourceGUID, sourceFlags, destGUID, ...)
			local a, b = combat(self, subevent, sourceGUID, sourceFlags, destGUID, ...)
			local state = self.shinyState
			if state and destGUID and (subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED") then
				state.live[destGUID] = nil
			end
			return a, b
		end
	end
end

-- Les cosmétiques des brillantes : leur condition (« 5 brillantes »), et
-- leur objectif dans le suivi
do
	local requirement = ns.CompanionRequirement
	if requirement then
		function ns:CompanionRequirement(unlock, ...)
			if type(unlock) == "table" and unlock.shiny then return self:F("COMP_REQ_shiny", unlock.shiny) end
			return requirement(self, unlock, ...)
		end
	end
	local nextUnlocks = ns.CompanionNextUnlocks
	if nextUnlocks then
		function ns:CompanionNextUnlocks(...)
			-- pas d'objectif au compteur pour eux : la chasse reste une surprise
			-- (leur progression est dans le carnet, onglet Créature)
			local list, kept = nextUnlocks(self, ...), {}
			for _, item in ipairs(list) do
				local shinyItem = false
				for _, reward in ipairs(REWARDS) do
					if item.kind == reward.kind and item.id == reward.def.id then shinyItem = true end
				end
				if not shinyItem then kept[#kept + 1] = item end
			end
			return kept
		end
	end
end

-- ---------------------------------------------------------------------------
-- Aura scintillante : des étincelles de temps en temps
-- ---------------------------------------------------------------------------
function ns:ShinyAuraDef()
	return REWARDS[3].def
end

function ns:ShinyAuraTick(now)
	if not ModuleOn() or not self.companionFrame then return false end
	local state = self:ShinyState()
	if now < (state.auraAt or 0) then return false end
	state.auraAt = now + ns.SHINY_AURA_EVERY
	if not self:CompanionOrnamentShown(self:ShinyAuraDef()) then return false end
	return self:CompanionFx("sparkle")
end

-- ---------------------------------------------------------------------------
-- Ouverture de coffre animée : un objet après l'autre
-- ---------------------------------------------------------------------------
do
	local open = ns.OpenChest
	if open then
		function ns:OpenChest(...)
			local frame = open(self, ...)
			if frame and self:DB().companionChestAnim ~= false then
				local buttons = {}
				-- encore cliquables, mais invisibles jusqu'à leur tour
				for _, button in ipairs(frame.options or {}) do
					if button.reward and button:IsShown() then
						button:SetAlpha(0)
						buttons[#buttons + 1] = button
					end
				end
				self.chestReveal = { frame = frame, buttons = buttons, index = 0, nextAt = Clock() + ns.CHEST_REVEAL_STEP }
				if self.CompanionFx then self:CompanionFx("sparkle") end
			end
			return frame
		end
	end
end

function ns:ChestRevealStep(now)
	local reveal = self.chestReveal
	if not reveal then return false end
	if not reveal.frame:IsShown() then
		for _, button in ipairs(reveal.buttons) do button:SetAlpha(1) end
		self.chestReveal = nil
		return false
	end
	if now < reveal.nextAt then return false end
	reveal.index = reveal.index + 1
	local button = reveal.buttons[reveal.index]
	if button then button:SetAlpha(1) end
	reveal.nextAt = now + ns.CHEST_REVEAL_STEP
	if reveal.index >= #reveal.buttons then
		self.chestReveal = nil
		if self.CompanionFx then self:CompanionFx("bounce"); self:CompanionFx("sparkle") end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Réglages : page « Au jour le jour »
-- ---------------------------------------------------------------------------
ns.DAILY_OPTION_ROWS = {
	{ key = "companionShinyMark", label = "OPT_DAILY_MARK", kind = "bool",
		describe = function() return L.OPT_DAILY_MARK_DESC end },
	{ key = "companionChestAnim", label = "OPT_DAILY_CHEST", kind = "bool" },
}
if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "companionDaily", title = "OPT_PAGE_DAILY", parent = "companion", group = "OPT_GROUP_MODULES",
		rows = ns.DAILY_OPTION_ROWS,
	})
end

-- ---------------------------------------------------------------------------
-- Horloge : dix fois par seconde suffit (objets révélés toutes les 0,3 s,
-- étincelles toutes les 1,5 s)
-- ---------------------------------------------------------------------------
ns.SHINY_TICK = 0.1
local ok, frame = pcall(CreateFrame, "Frame")
if ok and frame then
	frame:SetScript("OnUpdate", ns.Throttle(ns.SHINY_TICK, function()
		local now = Clock()
		local done, err = pcall(ns.ChestRevealStep, ns, now)
		if not done and ns.RecordError then ns:RecordError("shiny:chest", err) end
		done, err = pcall(ns.ShinyAuraTick, ns, now)
		if not done and ns.RecordError then ns:RecordError("shiny:aura", err) end
	end))
	ns.shinyEventFrame = frame
end

if ns.Mark then ns.Mark("Shiny") end
