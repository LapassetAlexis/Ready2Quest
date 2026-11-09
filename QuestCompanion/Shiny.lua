-- Shiny.lua -- créatures brillantes et ouverture de coffre animée (QuestCompanion 1.1.0)
--
-- Une petite chasse : la première fois que tu cibles ou survoles un monstre
-- (une fois par monstre, par son GUID), il a SHINY_CHANCE d'être brillant
-- (×SHINY_RANK_MULT pour un élite ou un rare). Toutes les espèces peuvent
-- l'être. Chasse (1.6.0) : plus tu as abattu de cette espèce, plus la chance
-- monte (jusqu'à ×SHINY_CHAIN_MAX après SHINY_CHAIN_KILLS abattus). Une
-- brillante repérée est reconnue pour toujours (ns:ShinyKnown) : la
-- Ménagerie la montre, capturée ou non. La créature le voit : bulle,
-- « ! », étincelles, et une étoile au-dessus de sa tête (icône de cible, si tu
-- joues seul ou mènes le groupe, et s'il n'en a pas déjà une).
--   * abattu : fiche dorée au bestiaire, une friandise (parfois un Festin) ;
--   * 5, 15 et 30 brillantes : un cadre, un fond et une aura qu'on ne trouve
--     dans aucun coffre.
-- Ouverture de coffre : les objets se révèlent un par un, la créature
-- s'emballe (réglage « Ouverture animée des coffres »).
-- Repère (1.6.0) : un losange doré qui scintille sur la barre de nom de
-- chaque brillante repérée, seul ou en groupe.
-- Réglages : page « Au jour le jour » (étoile, losange, ouverture animée).
local ADDON, ns = ...
if ns.blocked then return end
local Theme = ns.Theme
local L = ns.L

ns.SHINY_CHANCE = ns.SHINY_CHANCE or (1 / 150)
ns.SHINY_RANK_MULT = 3
ns.SHINY_CHAIN_KILLS = 50         -- abattus de l'espèce pour la chance maximale
ns.SHINY_CHAIN_MAX = 3.75         -- ×3,75 : 1/150 -> 1/40
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
	OPT_PAGE_DAILY         = "Au jour le jour",
	OPT_DAILY_PLATE        = "Losange doré sur la barre de nom des brillantes",
	OPT_DAILY_PLATE_DESC   = "Au-dessus du nom d'une créature brillante repérée : il scintille tant qu'elle est en vie. Seul ou en groupe.",
	OPT_DAILY_CHEST        = "Ouverture animée des coffres",
}
local EN = {
	COMP_FRAME_SPARKLE     = "Sparkling",
	COMP_BG_STARDUST       = "Stardust",
	COMP_ORN_AURA          = "Shimmering aura",
	COMP_REQ_shiny         = "%d shinies",
	JRN_STAT_shiny         = "shinies",
	SHINY_MSG_UNLOCK       = "%d shiny creatures! New: %s.",
	OPT_PAGE_DAILY         = "Day by day",
	OPT_DAILY_PLATE        = "Gold diamond on shiny nameplates",
	OPT_DAILY_PLATE_DESC   = "Above the name of a spotted shiny creature: it sparkles while it lives. Solo or in a group.",
	OPT_DAILY_CHEST        = "Animated chest opening",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.SHINY_STRINGS = { fr = FR, en = EN } end
-- libellés du catalogue : même registre que les autres cosmétiques
if type(ns.COMPANION_STRINGS) == "table" then
	for _, key in ipairs({ "COMP_FRAME_SPARKLE", "COMP_BG_STARDUST", "COMP_ORN_AURA", "COMP_REQ_shiny" }) do
		ns.COMPANION_STRINGS.fr[key], ns.COMPANION_STRINGS.en[key] = FR[key], EN[key]
	end
end

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
-- enregistrement commun (CompanionLines.lua) ; listes de clés en test seulement
local POOLS = ns.RegisterCompanionLines(P)
ns.SHINY_POOLS = POOLS

if type(ns.COMPANION_FX) == "table" then
	ns.COMPANION_FX.sparkle = { duration = 1.4, count = 6, color = { 1.0, 0.89, 0.48 } }
end

ns.RegisterDefaults({
	companionShinyMark = true,
	companionShinyPlate = true,
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
	-- espèces dont une brillante a été repérée : [npcID] = date (1.6.0)
	shiny.seen = type(shiny.seen) == "table" and shiny.seen or {}
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

-- Brillante de cette espèce reconnue (repérée ou abattue, n'importe où) :
-- sa date, ou nil
function ns:ShinyKnown(npcID)
	local data = self:ShinyData()
	local npc = tonumber(npcID) or npcID
	if data.seen[npc] then return data.seen[npc] end
	for _, zone in pairs(data.zones) do
		if type(zone) == "table" and zone[npc] then return zone[npc] end
	end
	return nil
end

-- Chance qu'un monstre soit brillant : base, rang, et la chasse (abattus de
-- son espèce)
function ns:ShinyChance(class, killed)
	local chance = (tonumber(ns.SHINY_CHANCE) or 0) * (ns.SHINY_RANKS[class or ""] and ns.SHINY_RANK_MULT or 1)
	local chain = math.min(tonumber(killed) or 0, ns.SHINY_CHAIN_KILLS) / ns.SHINY_CHAIN_KILLS
	return chance * (1 + (ns.SHINY_CHAIN_MAX - 1) * chain)
end

-- Abattus de l'espèce, toutes zones (bestiaire)
local function SpeciesKills(self, npcID)
	local total = 0
	for _, zone in pairs(self.BestiaryData and self:BestiaryData() or {}) do
		local species = type(zone) == "table" and zone[npcID]
		if type(species) == "table" then total = total + (tonumber(species.killed) or 0) end
	end
	return total
end
ns.ShinySpeciesKills = SpeciesKills

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
function ns:ShinyRoll(unit, entry)
	local class = Call(G("UnitClassification"), unit)
	local killed = entry and entry.npcID and SpeciesKills(self, entry.npcID) or 0
	local chance = self:ShinyChance(class, killed)
	return chance > 0 and math.random() < chance
end

-- Étoile au-dessus : plus jamais posée d'office. SetRaidTarget est protégé
-- sur Forever : appelé hors d'un clic du joueur, le jeu bloque l'addon
-- (fenêtre « QuestCompanion a été bloqué », 2.8.3). L'alerte du compagnon,
-- le chat et l'éclat suffisent ; la touche reste aux marques du joueur.
function ns:ShinyMark(unit)
	return false
end

function ns:ShinySpot(unit, guid, entry, species)
	local state = self:ShinyState()
	local name = (species and species.name) or Call(G("UnitName"), unit) or "?"
	state.live[guid] = { zoneID = entry.zoneID, npcID = entry.npcID, name = name, at = Clock() }
	-- reconnue : la Ménagerie la garde, même sans capture
	local data = self:ShinyData()
	local npc = tonumber(entry.npcID) or entry.npcID
	if npc and not data.seen[npc] then data.seen[npc] = Call(G("time")) or 0 end
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
					if self:ShinyRoll(unit, entry) then self:ShinySpot(unit, guid, entry, species) end
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
	if self.WeeklyEvent then pcall(self.WeeklyEvent, self, "shinyKill", 1) end
	local kind = math.random() < ns.SHINY_FESTIN_CHANCE and "festin" or (self.TreatRandom and self:TreatRandom())
	if kind and self.TreatGrant then self:TreatGrant(kind, { quiet = true }) end
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
		-- 2.7 : le haut fait shiny_found_<n> donne la récompense (FeatsCatMenagerie.lua)
		local byFeat = self.FeatLegacyHandled and self:FeatLegacyHandled("shiny_found_" .. reward.count)
		if count >= reward.count and not unlocked[key] and not byFeat then
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
			if state and destGUID and (subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED") and state.live[destGUID] then
				state.live[destGUID] = nil
				if self.ShinyPlatesRefresh then pcall(self.ShinyPlatesRefresh, self) end
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
	-- l'aura gagnée, ou un compagnon brillant (1.6.0) : il scintille
	local app = self.CompanionCurrentAppearance and self:CompanionCurrentAppearance()
	if not (self:CompanionOrnamentShown(self:ShinyAuraDef()) or (app and app.shiny)) then return false end
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
	{ key = "companionShinyPlate", label = "OPT_DAILY_PLATE", kind = "bool",
		describe = function() return L.OPT_DAILY_PLATE_DESC end,
		onChange = function() ns:ShinyPlatesRefresh() end },
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
-- 2.11.2 (fiche 25) : sur l'horloge de l'addon (plus d'OnUpdate permanent)
ns.Every("shiny", ns.SHINY_TICK, function()
	local now = Clock()
	local done, err = pcall(ns.ChestRevealStep, ns, now)
	if not done and ns.RecordError then ns:RecordError("shiny:chest", err) end
	done, err = pcall(ns.ShinyAuraTick, ns, now)
	if not done and ns.RecordError then ns:RecordError("shiny:aura", err) end
end)

-- ---------------------------------------------------------------------------
-- Repère sur la barre de nom (1.6.0) : un losange doré qui scintille au-dessus
-- du nom de chaque brillante repérée encore en vie, seul ou en groupe, sans
-- toucher aux icônes de cible. Accroché au cadre de base de la barre
-- (C_NamePlate) : il suit aussi les barres d'un addon.
-- ---------------------------------------------------------------------------
ns.SHINY_PLATE_SIZE = 18
ns.SHINY_PLATE_Y = 8              -- au-dessus du haut de la barre
ns.shinyPlates = ns.shinyPlates or {}   -- unité -> cadre de base de la barre
ns.shinyPlateMarks = ns.shinyPlateMarks or {}  -- cadre de base -> repère

local function PlateFor(unit)
	local api = G("C_NamePlate")
	if type(api) ~= "table" or type(api.GetNamePlateForUnit) ~= "function" then return nil end
	local ok, plate = pcall(api.GetNamePlateForUnit, unit)
	if not ok or type(plate) ~= "table" then return nil end
	if type(plate.IsForbidden) == "function" then
		local okF, forbidden = pcall(plate.IsForbidden, plate)
		if okF and forbidden then return nil end
	end
	return plate
end

local function MarkFor(plate)
	local mark = ns.shinyPlateMarks[plate]
	if mark then return mark end
	local ok, frame = pcall(CreateFrame, "Frame", nil, plate)
	if not ok or not frame then return nil end
	local size = ns.SHINY_PLATE_SIZE
	frame:SetSize(size * 2, size * 2)
	frame:SetPoint("BOTTOM", plate, "TOP", 0, ns.SHINY_PLATE_Y - size / 2)
	if frame.SetFrameLevel and plate.GetFrameLevel then
		pcall(frame.SetFrameLevel, frame, (tonumber(plate:GetFrameLevel()) or 1) + 6)
	end
	local gold, light = Theme.GOLD, Theme.GOLD_LIGHT or Theme.GOLD
	-- halo doux, losange sombre (liseré), losange doré
	frame.glow = frame:CreateTexture(nil, "BACKGROUND")
	frame.glow:SetTexture(Theme.DIAMOND)
	frame.glow:SetSize(size * 1.9, size * 1.9)
	frame.glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame.glow:SetVertexColor(light[1], light[2], light[3], 0.35)
	if frame.glow.SetBlendMode then pcall(frame.glow.SetBlendMode, frame.glow, "ADD") end
	frame.back = frame:CreateTexture(nil, "ARTWORK")
	frame.back:SetTexture(Theme.DIAMOND)
	frame.back:SetSize(size + 4, size + 4)
	frame.back:SetPoint("CENTER", frame, "CENTER", 0, 0)
	Theme.Shade(frame.back, Theme.SHADE.strong)
	frame.gem = frame:CreateTexture(nil, "OVERLAY")
	frame.gem:SetTexture(Theme.DIAMOND)
	frame.gem:SetSize(size, size)
	frame.gem:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame.gem:SetVertexColor(gold[1], gold[2], gold[3], 1)
	-- scintillement : le halo respire, le losange s'éclaire
	frame:SetScript("OnUpdate", function(self)
		local t = Clock()
		local pulse = 0.5 + 0.5 * math.sin(t * math.pi * 1.6)
		self.glow:SetAlpha(0.25 + 0.5 * pulse)
		self.glow:SetSize(size * (1.6 + 0.5 * pulse), size * (1.6 + 0.5 * pulse))
		-- trois nombres, pas de table neuve à chaque image (2.8.1)
		self.gem:SetVertexColor(gold[1] + (light[1] - gold[1]) * pulse, gold[2] + (light[2] - gold[2]) * pulse,
			gold[3] + (light[3] - gold[3]) * pulse, 1)
	end)
	frame:Hide()
	ns.shinyPlateMarks[plate] = frame
	return frame
end

-- Pose ou retire le repère d'une unité ; rend true s'il est montré
function ns:ShinyPlateUpdate(unit)
	local plate = self.shinyPlates[unit] or PlateFor(unit)
	if not plate then return false end
	self.shinyPlates[unit] = plate
	local guid = ns.Plain(Call(G("UnitGUID"), unit))
	local live = type(guid) == "string" and self:ShinyState().live[guid]
	local show = live and ModuleOn() and self:DB().companionShinyPlate ~= false
	local mark = show and MarkFor(plate) or self.shinyPlateMarks[plate]
	if not mark then return false end
	if show then
		mark.guid = guid
		mark:Show()
	else
		mark.guid = nil
		mark:Hide()
	end
	return show and true or false
end

-- Toutes les barres visibles (une brillante repérée, abattue, réglage changé)
function ns:ShinyPlatesRefresh()
	local api = G("C_NamePlate")
	if type(api) == "table" and type(api.GetNamePlates) == "function" then
		local ok, plates = pcall(api.GetNamePlates)
		for _, plate in ipairs(ok and type(plates) == "table" and plates or {}) do
			local unit = ns.Plain(plate.namePlateUnitToken)
			if type(unit) == "string" then self.shinyPlates[unit] = plate end
		end
	end
	local shown = 0
	for unit in pairs(self.shinyPlates) do
		local ok, on = pcall(self.ShinyPlateUpdate, self, unit)
		if ok and on then shown = shown + 1 end
	end
	return shown
end

do
	local plateFrame = CreateFrame("Frame")
	local PLATE_EVENTS = {
		NAME_PLATE_UNIT_ADDED = function(unit)
			if type(unit) ~= "string" then return end
			ns.shinyPlates[unit] = nil
			-- aucune brillante en vie (le cas courant) : rien à marquer ;
			-- ShinyPlatesRefresh relit toutes les barres quand une apparaît
			if not next(ns:ShinyState().live) then return end
			ns:ShinyPlateUpdate(unit)
		end,
		NAME_PLATE_UNIT_REMOVED = function(unit)
			local plate = type(unit) == "string" and ns.shinyPlates[unit]
			local mark = plate and ns.shinyPlateMarks[plate]
			if mark then mark:Hide(); mark.guid = nil end
			if type(unit) == "string" then ns.shinyPlates[unit] = nil end
		end,
	}
	for event in pairs(PLATE_EVENTS) do pcall(plateFrame.RegisterEvent, plateFrame, event) end
	plateFrame:SetScript("OnEvent", function(_, event, ...)
		local ok, err = pcall(PLATE_EVENTS[event], ...)
		if not ok and ns.RecordError then ns:RecordError("shiny:plate", err) end
	end)
	ns.shinyPlateFrame = plateFrame
end

-- repérée : son repère tout de suite ; abattue ou morte : il s'en va
do
	local spot, kill = ns.ShinySpot, ns.ShinyKill
	function ns:ShinySpot(...)
		local result = spot(self, ...)
		pcall(self.ShinyPlatesRefresh, self)
		return result
	end
	function ns:ShinyKill(...)
		local result = kill(self, ...)
		pcall(self.ShinyPlatesRefresh, self)
		return result
	end
end

if ns.Mark then ns.Mark("Shiny") end
