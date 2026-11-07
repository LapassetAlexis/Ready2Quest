-- CompanionChest.lua -- coffres de zone : finir une zone à 100 % rapporte un objet
--
-- Règle voulue par le joueur :
--   * une zone finie à 100 % (complétion du carnet, au moins deux parts :
--     villages, bestiaire, nommés, récolte, quêtes) ouvre un coffre ;
--   * le coffre propose les cosmétiques du PALIER de la zone (1 = zones 1-19,
--     2 = 20-39, 3 = 40-60) encore verrouillés : le joueur en CHOISIT un ;
--   * palier épuisé : la zone devient « dorée » (un tampon d'honneur ; depuis la
--     1.1.0, un Festin et deux friandises, Treats.lua).
-- Plus la zone est haute, plus l'objet est beau : c'est le palier qui le dit
-- (champ `tier` des cosmétiques, CompanionData.lua).
--
-- Le niveau d'une zone vient d'une table posée à la main (zones classiques,
-- uiMapID identiques sur Era et Forever). Zone inconnue (ajout de Forever) :
-- on prend le niveau du joueur au moment où il la finit.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

-- uiMapID -> { niveau bas, niveau haut }
local ZONE_LEVELS = {
	[1429] = { 1, 10 },  [1426] = { 1, 10 },  [1438] = { 1, 10 },  [1411] = { 1, 10 },  [1412] = { 1, 10 },
	[1420] = { 1, 10 },  [1436] = { 10, 20 }, [1432] = { 10, 20 }, [1439] = { 10, 20 }, [1413] = { 10, 25 },
	[1421] = { 10, 20 }, [1433] = { 15, 25 }, [1442] = { 15, 27 }, [1440] = { 18, 30 }, [1431] = { 18, 30 },
	[1437] = { 20, 30 }, [1424] = { 20, 30 }, [1441] = { 25, 35 }, [1416] = { 30, 40 }, [1417] = { 30, 40 },
	[1443] = { 30, 40 }, [1434] = { 30, 45 }, [1445] = { 35, 45 }, [1418] = { 35, 45 }, [1435] = { 35, 45 },
	[1444] = { 40, 50 }, [1425] = { 40, 50 }, [1446] = { 40, 50 }, [1427] = { 43, 50 }, [1447] = { 45, 55 },
	[1419] = { 45, 55 }, [1449] = { 48, 55 }, [1448] = { 48, 55 }, [1428] = { 50, 58 }, [1422] = { 51, 58 },
	[1423] = { 53, 60 }, [1452] = { 55, 60 }, [1430] = { 55, 60 }, [1451] = { 55, 60 },
}
ns.ZONE_LEVELS = ZONE_LEVELS

local CHEST_W, OPTION_H, OPTION_GAP, COLUMNS = 480, 50, 10, 2

local FR = {
	CHEST_TITLE         = "Coffre de %s",
	CHEST_INTRO         = "Zone terminée à 100 %% ! Choisis ta récompense (palier %d) :",
	CHEST_KIND_app      = "Apparence",
	CHEST_KIND_orn      = "Ornement",
	CHEST_KIND_frame    = "Cadre",
	CHEST_KIND_bg       = "Fond",
	CHEST_SUB           = "Palier %d · un seul objet, gardé pour toujours",
	CHEST_LATER         = "Plus tard",
	CHEST_MSG_NEW       = "Coffre : %s terminée à 100 %% ! Ouvre-le pour choisir ta récompense (/qc coffre).",
	CHEST_MSG_PICKED    = "Coffre de %s : %s obtenu !",
	CHEST_MSG_GOLDEN    = "%s terminée à 100 %% : tout le palier %d est déjà à toi, la zone devient dorée.",
	CHEST_MSG_NONE      = "Aucun coffre à ouvrir. Termine une zone à 100 % pour en gagner un.",
	CHEST_GOAL          = "Ouvre le coffre de %s",
	CHEST_REWARD_TIER   = "un objet au choix (palier %d)",
	CHEST_HINT          = "Clique pour choisir ta récompense parmi les objets du palier %d.",
	CHEST_EQUIP_HINT    = "À équiper dans les options du compagnon.",
	HELP_CHEST          = "/qc coffre -- ouvre le coffre d'une zone terminée à 100 %",
}
local EN = {
	CHEST_TITLE         = "%s chest",
	CHEST_INTRO         = "Zone 100%% complete! Pick your reward (tier %d):",
	CHEST_KIND_app      = "Look",
	CHEST_KIND_orn      = "Ornament",
	CHEST_KIND_frame    = "Frame",
	CHEST_KIND_bg       = "Background",
	CHEST_SUB           = "Tier %d · one item, yours to keep",
	CHEST_LATER         = "Later",
	CHEST_MSG_NEW       = "Chest: %s is 100%% complete! Open it to pick your reward (/qc coffre).",
	CHEST_MSG_PICKED    = "%s chest: you got %s!",
	CHEST_MSG_GOLDEN    = "%s is 100%% complete: you already own all of tier %d, the zone turns golden.",
	CHEST_MSG_NONE      = "No chest to open. Complete a zone to 100% to earn one.",
	CHEST_GOAL          = "Open the %s chest",
	CHEST_REWARD_TIER   = "an item of your choice (tier %d)",
	CHEST_HINT          = "Click to pick your reward among tier %d items.",
	CHEST_EQUIP_HINT    = "Equip it in the companion options.",
	HELP_CHEST          = "/qc coffre -- open the chest of a zone completed to 100%",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CHEST_STRINGS = { fr = FR, en = EN } end

if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_CHEST")
		end
	end
end

local function Call(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end

local function ModuleOn()
	local db = ns:DB()
	return db.enabled ~= false and db.companionEnabled ~= false
end

local function PlayerLevel() return tonumber((Call("UnitLevel", "player"))) or 1 end

local function TierOfLevel(level)
	level = tonumber(level) or 1
	if level < 20 then return 1 end
	if level < 40 then return 2 end
	return 3
end

-- Tranche de niveaux d'une zone (zoneID = uiMapID, ns:JournalZone) : celle
-- du jeu (C_Map.GetMapLevels, socle ns:MapLevelRange) quand il la donne, sinon
-- la table ci-dessus, sinon calculée à partir de ses créatures préremplies
-- (ZoneCreatures_<client>.lua : zones propres à Forever, Reflet-de-Lune…) :
-- les normales seulement, sans les extrêmes (un dixième de chaque côté). nil
-- si la zone n'a rien de tout cela.
local computedLevels = {}
function ns:ZoneLevelRange(zoneID)
	zoneID = tonumber(zoneID)
	if not zoneID then return nil end
	-- la table établie l'emporte (tranches Classic sûres) ; le jeu complète
	-- les zones qu'elle ne connaît pas, avant l'estimation par les créatures
	if ZONE_LEVELS[zoneID] then return ZONE_LEVELS[zoneID] end
	local live = self.MapLevelRange and self:MapLevelRange(zoneID)
	if live then return live end
	if computedLevels[zoneID] ~= nil then return computedLevels[zoneID] or nil end
	local creatures = type(ns.ZONE_CREATURES) == "table" and ns.ZONE_CREATURES[zoneID]
	local lows, highs = {}, {}
	for _, entry in pairs(type(creatures) == "table" and creatures or {}) do
		local lvl = type(entry) == "table" and entry.lvl
		if type(lvl) == "table" and tonumber(lvl[1]) and (tonumber(entry.rank) or 0) == 0 then
			lows[#lows + 1] = tonumber(lvl[1])
			highs[#highs + 1] = tonumber(lvl[2]) or tonumber(lvl[1])
		end
	end
	local range = false
	if #lows > 0 then
		table.sort(lows); table.sort(highs)
		local cut = math.floor(#lows * 0.1)
		local lo, hi = lows[cut + 1], highs[#highs - cut]
		range = { math.max(1, lo), math.max(lo, hi) }
	end
	computedLevels[zoneID] = range
	return range or nil
end
ns.ZoneLevelCache = computedLevels

-- Palier d'une zone : son niveau d'entrée, sinon le niveau du joueur
function ns:ZoneTier(zoneID)
	local range = self:ZoneLevelRange(zoneID)
	if range then return TierOfLevel(range[1]), range end
	return TierOfLevel(PlayerLevel()), nil
end

function ns:ChestData()
	local data = self:CompanionData()
	if type(data.chests) ~= "table" then data.chests = {} end
	return data.chests
end

local function ZoneName(self, zoneID)
	local info = self.MapInfo and self:MapInfo(zoneID)
	return (info and info.name) or tostring(zoneID)
end

-- ---------------------------------------------------------------------------
-- Catalogue des récompenses
-- ---------------------------------------------------------------------------
-- ns.COMPANION_REWARDS (CompanionData.lua) si présent ; sinon reconstruit à
-- partir des tables qui portent un `tier`.
local CATALOGS = {
	{ kind = "app",   field = "COMPANION_APPEARANCES" },
	{ kind = "orn",   field = "COMPANION_ORNAMENTS" },
	{ kind = "frame", field = "COMPANION_FRAMES" },
	{ kind = "bg",    field = "COMPANION_BACKGROUNDS" },
}

function ns:ChestRewards()
	if type(ns.COMPANION_REWARDS) == "table" then return ns.COMPANION_REWARDS end
	local list = {}
	for _, catalog in ipairs(CATALOGS) do
		for _, def in ipairs(ns[catalog.field] or {}) do
			if (tonumber(def.tier) or 0) >= 1 then
				list[#list + 1] = { kind = catalog.kind, id = def.id, label = def.label, tier = def.tier }
			end
		end
	end
	return list
end

local function DefOf(kind, id)
	for _, catalog in ipairs(CATALOGS) do
		if catalog.kind == kind then
			for _, def in ipairs(ns[catalog.field] or {}) do
				if def.id == id then return def end
			end
		end
	end
	return nil
end

local function Owned(self, reward)
	return self:CompanionData().unlocked[reward.kind .. ":" .. reward.id] == true
end

function ns:ChestRewardLabel(reward)
	if self.CompanionRewardLabel then
		local ok, text = pcall(self.CompanionRewardLabel, self, reward)
		if ok and type(text) == "string" and text ~= "" then return text end
	end
	return L[reward.label] or tostring(reward.label or reward.id)
end

-- Ce que propose le coffre d'un palier : ce qui n'est pas encore à toi
function ns:ChestOptions(tier)
	local options = {}
	for _, reward in ipairs(self:ChestRewards()) do
		if tonumber(reward.tier) == tier and not Owned(self, reward) then options[#options + 1] = reward end
	end
	table.sort(options, function(a, b)
		if a.kind ~= b.kind then return a.kind < b.kind end
		return self:ChestRewardLabel(a) < self:ChestRewardLabel(b)
	end)
	return options
end

-- ---------------------------------------------------------------------------
-- Gagner, ouvrir, choisir
-- ---------------------------------------------------------------------------
-- Zone à 100 % : coffre posé une fois pour toutes (de nouvelles espèces vues
-- ensuite ne le reprennent pas)
function ns:ChestCheck(zoneID)
	if not ModuleOn() or not zoneID or not self.ZoneCompletion then return nil end
	local chests = self:ChestData()
	if chests[zoneID] then return nil end
	local done = self:ZoneCompletion(zoneID)
	if not done or #done.parts < 2 or done.percent < 100 then return nil end
	local tier = self:ZoneTier(zoneID)
	local name = ZoneName(self, zoneID)
	local chest = { tier = tier, name = name, at = Call("time") or 0 }
	chests[zoneID] = chest
	if #self:ChestOptions(tier) == 0 then
		chest.golden, chest.opened = true, true
		self:Print(self:F("CHEST_MSG_GOLDEN", name, tier))
	else
		self:Print(self:F("CHEST_MSG_NEW", name))
		if self.CompanionSay then self:CompanionSay("CHEST", { force = true, args = { name } }) end
	end
	return chest
end

function ns:ChestPending()
	local list = {}
	for zoneID, chest in pairs(self:ChestData()) do
		if not chest.opened then list[#list + 1] = { zoneID = zoneID, chest = chest } end
	end
	table.sort(list, function(a, b) return (a.chest.at or 0) < (b.chest.at or 0) end)
	return list
end

function ns:ChestPick(zoneID, reward)
	local chest = self:ChestData()[zoneID]
	if not chest or chest.opened or type(reward) ~= "table" then return false end
	if tonumber(reward.tier) ~= chest.tier or Owned(self, reward) then return false end
	local key = reward.kind .. ":" .. reward.id
	self:CompanionData().unlocked[key] = true
	chest.opened, chest.reward = true, key
	-- un coffre ouvert, c'est une découverte
	if self.CompanionAdd and ns.COMPANION_CURIOSITY then self:CompanionAdd("curiosity", ns.COMPANION_CURIOSITY.chest) end
	-- une nouvelle apparence se porte tout de suite : c'est le plaisir du coffre
	if reward.kind == "app" then
		self:CompanionData().appearance = reward.id
		if self.CompanionApplyModel then self:CompanionApplyModel() end
	end
	if self.CompanionApplyOrnaments then self:CompanionApplyOrnaments() end
	for _, fn in ipairs({ "CompanionApplyFrame", "CompanionApplyBackground" }) do
		if type(self[fn]) == "function" then pcall(self[fn], self) end
	end
	local label = self:ChestRewardLabel(reward)
	self:Print(self:F("CHEST_MSG_PICKED", chest.name or ZoneName(self, zoneID), label))
	if reward.kind ~= "app" then self:Print(L.CHEST_EQUIP_HINT) end
	if self.CompanionSay then self:CompanionSay("UNLOCK", { force = true, args = { label } }) end
	if self.chestFrame then self.chestFrame:Hide() end
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	if self.RefreshJournalTracker then pcall(self.RefreshJournalTracker, self) end
	return true
end

-- Fenêtre (docs/UI.md, « Carnet et compagnon ») : fenêtre de module, une
-- tuile par objet proposé sur deux colonnes (sorte en étiquette, nom), pied
-- « Plus tard ». La hauteur suit le nombre d'objets.
local INTRO_H = 34
local function ChestHeight(count)
	local rows = math.max(1, math.ceil((count or 1) / COLUMNS))
	return Theme.HEADER_COMPACT_HEIGHT + 1 + 16 + INTRO_H + 10 + rows * (OPTION_H + OPTION_GAP) - OPTION_GAP + 20
		+ Theme.DIALOG_FOOTER
end
ns.ChestHeight = ChestHeight

function ns:EnsureChestWindow(count)
	local height = ChestHeight(count)
	local frame = self.chestFrame
	if not frame then
		frame = Theme.CreateDialog(UIParent, CHEST_W, height, { name = "QuestCompanionChestFrame" })
		if not frame then return nil end
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
		frame.intro = Theme.Text(frame, Theme.F_BODY, Theme.LABEL)
		frame.intro:SetPoint("TOPLEFT", frame, "TOPLEFT", frame.pad, frame.contentTop - 16)
		frame.intro:SetWidth(frame.innerWidth)
		frame.intro:SetJustifyH("LEFT")
		if frame.intro.SetWordWrap then frame.intro:SetWordWrap(true) end
		frame.later = frame:AddFooterButton(L.CHEST_LATER, function() frame:Hide() end, "outline")
		frame.options = {}
		frame:Hide()
		self.chestFrame = frame
	end
	frame:SetHeight(height)
	return frame
end

-- Une tuile d'objet : sorte en étiquette, nom dessous ; clic = le choisir
local function OptionTile(frame, width)
	local tile = Theme.CreateTile(frame, width, OPTION_H)
	tile:SetAccent(Theme.GOLD)
	tile.kindTag = Theme.CreateTag(tile, "", Theme.GOLD)
	tile.kindTag:SetPoint("TOPLEFT", tile, "TOPLEFT", 14, -9)
	tile.text = Theme.Text(tile, Theme.F_LABEL, Theme.LABEL)
	tile.text:SetPoint("TOPLEFT", tile, "TOPLEFT", 14, -28)
	tile.text:SetWidth(width - 28)
	tile.text:SetJustifyH("LEFT")
	if tile.text.SetWordWrap then tile.text:SetWordWrap(false) end
	tile:SetScript("OnClick", function(self) ns:ChestPick(frame.zoneID, self.reward) end)
	return tile
end

function ns:OpenChest(zoneID)
	if not zoneID then
		local first = self:ChestPending()[1]
		if not first then self:Print(L.CHEST_MSG_NONE); return nil end
		zoneID = first.zoneID
	end
	local chest = self:ChestData()[zoneID]
	if not chest or chest.opened then return nil end
	local options = self:ChestOptions(chest.tier)
	if #options == 0 then
		chest.golden, chest.opened = true, true
		self:Print(self:F("CHEST_MSG_GOLDEN", chest.name or ZoneName(self, zoneID), chest.tier))
		return nil
	end
	local frame = self:EnsureChestWindow(#options)
	if not frame then return nil end
	frame.title:SetText(self:F("CHEST_TITLE", chest.name or ZoneName(self, zoneID)))
	frame.subtitle:SetText(self:F("CHEST_SUB", chest.tier))
	frame.zoneID = zoneID
	frame.intro:SetText(self:F("CHEST_INTRO", chest.tier))
	local width = math.floor((frame.innerWidth - OPTION_GAP * (COLUMNS - 1)) / COLUMNS)
	local top = frame.contentTop - 16 - INTRO_H - 10
	for index, reward in ipairs(options) do
		local button = frame.options[index]
		if not button then
			button = OptionTile(frame, width)
			frame.options[index] = button
		end
		local col, row = (index - 1) % COLUMNS, math.floor((index - 1) / COLUMNS)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", frame.pad + col * (width + OPTION_GAP), top - row * (OPTION_H + OPTION_GAP))
		button.reward = reward
		button.kindTag:SetTag(L["CHEST_KIND_" .. reward.kind] or reward.kind, Theme.GOLD)
		button.text:SetText(self:ChestRewardLabel(reward))
		button:SetAlpha(1)
		button:Show()
	end
	for index = #options + 1, #frame.options do frame.options[index]:Hide(); frame.options[index].reward = nil end
	if self.CloseOtherWindows then self:CloseOtherWindows(frame) end
	frame:Show()
	if Theme.FadeIn then Theme.FadeIn(frame, 0.15) end
	return frame
end

if type(ns.EXCLUSIVE_WINDOWS) == "table" then
	table.insert(ns.EXCLUSIVE_WINDOWS, "chestFrame")
end
if type(ns.EXTRA_COMMANDS) == "table" then
	ns.EXTRA_COMMANDS["coffre"] = function(self) self:OpenChest() end
	ns.EXTRA_COMMANDS["chest"] = ns.EXTRA_COMMANDS["coffre"]
end

-- ---------------------------------------------------------------------------
-- Objectifs : coffres à ouvrir, et la récompense de la complétion de zone
-- ---------------------------------------------------------------------------
if ns.RegisterGoalSource then
	ns.RegisterGoalSource(function(self, list)
		for _, entry in ipairs(self:ChestPending()) do
			local zoneID, chest = entry.zoneID, entry.chest
			-- 0/1 mais trié en tête : un coffre qui attend passe avant tout
			local goal = ns.JournalGoal("chest:" .. zoneID, self:F("CHEST_GOAL", chest.name or ZoneName(self, zoneID)),
				0, 1, 2, "companion")
			if goal then
				goal.progress = ""
				goal.hint = { self:F("CHEST_HINT", chest.tier) }
				goal.onClick = function() ns:OpenChest(zoneID) end
				list[#list + 1] = goal
			end
		end
	end)
end

-- La complétion de la zone dit ce qu'elle rapporte ; le coffre se pose dès
-- que le suivi se recalcule (tampon, kill, récolte, changement de zone)
do
	local previous = ns.RefreshJournalTracker
	if previous then
		function ns:RefreshJournalTracker(...)
			if ModuleOn() and self.JournalZone then
				local zoneID = self:JournalZone()
				if zoneID then pcall(self.ChestCheck, self, zoneID) end
			end
			return previous(self, ...)
		end
	end
	local objectives = ns.JournalObjectives
	if objectives then
		function ns:JournalObjectives(...)
			local list = objectives(self, ...)
			for _, goal in ipairs(list) do
				local zoneID = goal.zoneCompletion and tonumber(goal.id:match("^zone:(%d+)$"))
				if zoneID and not self:ChestData()[zoneID] then
					local tier = self:ZoneTier(zoneID)
					goal.reward = self:F("CHEST_REWARD_TIER", tier)
				end
			end
			return list
		end
	end
end

if ns.Mark then ns.Mark("CompanionChest") end
