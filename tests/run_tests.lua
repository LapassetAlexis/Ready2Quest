-- tests/run_tests.lua -- harnais de test hors-jeu (Lua 5.1, comme le client WoW)
--
-- Simule le sous-ensemble d'API utilisé par l'addon, charge les fichiers de
-- l'addon comme le fait le client, puis joue des scénarios et vérifie les
-- résultats. Ne remplace pas un test en jeu : ça valide la LOGIQUE, pas les
-- contrats d'API réels (le /sd diag existe pour ça).

local ROOT = ADDON_ROOT or "."

----------------------------------------------------------------------------
-- 1. Mock du client
----------------------------------------------------------------------------
local Mock = { frames = {}, output = {}, now = 1000 }
_G.Mock = Mock

function Mock:Log(text) self.output[#self.output + 1] = tostring(text) end
function Mock:Output() return table.concat(self.output, "\n") end
function Mock:Reset() self.output = {} end
function Mock:Fire(event, ...)
	for _, frame in ipairs(self.frames) do
		if frame.events and frame.events[event] and frame.script then
			frame.script(frame, event, ...)
		end
	end
end

Mock.world = {}

local function NewRegion(kind, name)
	local region = {
		kind = kind, name = name, events = {}, text = "", shown = false,
		scripts = {}, width = 100, height = 100, vertex = { 1, 1, 1 },
		texture = nil, points = {}, level = 1,
	}
	function region:RegisterEvent(event)
		if Mock.world.unknownEvents and Mock.world.unknownEvents[event] then
			error("Attempt to register unknown event \"" .. tostring(event) .. "\"")
		end
		self.events[event] = true
	end
	function region:UnregisterEvent(event)
		self.events[event] = nil
	end
	function region:SetScript(script, fn)
		self.scripts[script] = fn
		if script == "OnEvent" then self.script = fn end
	end
	function region:Click(mouseButton)
		if self.scripts.OnClick then self.scripts.OnClick(self, mouseButton or "LeftButton") end
	end
	function region:GetScript(kind) return self.scripts[kind] end
	function region:HookScript(kind, fn)
		self.hooks = self.hooks or {}
		self.hooks[kind] = fn
	end
	function region:CreateFontString(_, _, fontObject)
		local fontString = NewRegion("FontString")
		fontString.fontObject = fontObject
		-- approximation : 6.4 px par caractere pour F_SMALL. Suffisant pour
		-- verifier qu'un libelle tient dans son bouton, ce qui est le point.
		function fontString:GetStringWidth()
			return #(self.text or "") * 6.4
		end
		return fontString
	end
	function region:CreateTexture() return NewRegion("Texture") end
	function region:SetSize(w, h) self.width, self.height = w, h end
	function region:SetWidth(w) self.width = w end
	function region:SetHeight(h) self.height = h end
	function region:GetWidth() return self.width end
	function region:GetHeight() return self.height end
	function region:SetAllPoints() end
	function region:SetTexture(path) self.texture = path end
	function region:SetAtlas(path) self.atlas = path end
	function region:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
	function region:SetAlpha(value) self.alpha = value end
	function region:GetName() return self.name end
	function region:SetHighlightTexture(texture) self.highlightTexture = texture end
	-- BackdropTemplate
	function region:SetBackdrop(backdrop) self.backdrop = backdrop end
	function region:SetBackdropColor(r, g, b, a) self.backdropColor = { r, g, b, a } end
	function region:SetBackdropBorderColor(r, g, b, a) self.backdropBorderColor = { r, g, b, a } end
	function region:SetFixedFrameStrata() end
	function region:SetFixedFrameLevel() end
	function region:SetTexCoord() end
	function region:SetWordWrap() end
	function region:SetFrameLevel(level) self.level = level end
	function region:GetFrameLevel() return self.level end
	function region:SetClampedToScreen() end
	function region:ClearAllPoints() self.points = {} end
	function region:GetPoint()
		local last = self.lastPoint
		if last then return last.point, last.relTo, last.relPoint, last.x, last.y end
		return "TOPLEFT", nil, "TOPLEFT", 10, -10
	end
	function region:SetPoint(point, ...)
		local args = { ... }
		local entry = { point = point }
		-- SetPoint("LEFT", other, "RIGHT", x, y) -> args = {other, "RIGHT", x, y}
		-- on conserve relTo et relPoint : sans eux, une ancre chainee est
		-- indiscernable d'une ancre absolue et les tests d'alignement mentent
		if type(args[1]) == "table" or (type(args[1]) == "userdata") then
			entry.relTo = args[1]
			if type(args[2]) == "string" then entry.relPoint = args[2] end
		end
		for index = #args, 1, -1 do
			if type(args[index]) == "number" then
				entry.y = entry.x or args[index]
				entry.x = args[index]
			end
		end
		self.points[#self.points + 1] = entry
		self.lastPoint = entry
		return entry
	end
	function region:SetFrameStrata(value) self.strata = value end
	function region:SetMovable(value) self.movable = value end
	function region:StartMoving() self.isMoving = true end
	function region:StopMovingOrSizing() self.isMoving = false end
	function region:EnableMouse(value) self.mouseEnabled = value end
	function region:RegisterForDrag() end
	function region:RegisterForClicks() end
	function region:GetCenter() return 500, 500 end
	function region:GetEffectiveScale() return 1 end
	function region:SetHitRectInsets() end
	function region:SetJustifyH() end
	function region:Show() self.shown = true end
	function region:Hide() self.shown = false end
	function region:IsShown() return self.shown end
	function region:CreateAnimationGroup()
		local group = { plays = 0, animations = {} }
		function group:CreateAnimation(kind)
			local anim = { kind = kind }
			function anim:SetFromAlpha(v) self.from = v end
			function anim:SetToAlpha(v) self.to = v end
			function anim:SetDuration(v) self.duration = v end
			self.animations[#self.animations + 1] = anim
			return anim
		end
		function group:Play() self.plays = self.plays + 1 end
		function group:Stop() end
		self.animGroups = (self.animGroups or 0) + 1
		return group
	end
	function region:SetFont(path, size, flags)
		if Mock.world.fontRefused then return false end
		self.font = { path = path, size = size, flags = flags }
		return true
	end
	function region:SetText(value) self.text = value end
	function region:GetText() return self.text end
	function region:SetShadowColor(r, g, b, a) self.shadow = { r, g, b, a } end
	function region:SetShadowOffset(x, y) self.shadowOffset = { x, y } end
	function region:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
	function region:GetTextColor()
		local c = self.textColor or { 1, 1, 1, 1 }
		return c[1], c[2], c[3], c[4]
	end
	function region:SetFontObject() end
	function region:SetNormalFontObject() end
	function region:SetDisabledFontObject() end
	Mock.frames[#Mock.frames + 1] = region
	return region
end

_G.CreateFrame = function(kind, name, parent, template)
	if template == "UIPanelButtonTemplate" and Mock.world.noButtonTemplate then
		error("Unknown frame template: " .. tostring(template))
	end
	if template == "BackdropTemplate" and Mock.world.noBackdropTemplate then
		error("Unknown frame template: " .. tostring(template))
	end
	return NewRegion(kind, name)
end
_G.UIParent = NewRegion("Frame", "UIParent")
_G.Minimap = NewRegion("Frame", "Minimap")
_G.Minimap.width, _G.Minimap.height = 140, 140
_G.GetMinimapShape = function() return Mock.world.minimapShape or "ROUND" end
_G.UISpecialFrames = {}
_G.GetCursorPosition = function()
	return Mock.world.cursorX or 500, Mock.world.cursorY or 500
end
_G.SlashCmdList = {}

_G.GetLocale = function() return "frFR" end
_G.GetBuildInfo = function()
	local b = Mock.world.build or { version = "1.60.1", build = "69893", date = "Oct 1 2026", toc = 16001 }
	return b.version, b.build, b.date, b.toc
end
_G.GetTime = function() return Mock.now end
_G.time = function() return math.floor(Mock.now) end
_G.print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	Mock:Log(table.concat(parts, " "))
end

_G.Enum = {
	RestState     = { RESTED = 1, NORMAL = 2 },
	ItemClass     = { Consumable = 0 },
	ItemConsumableSubclass = { Fooddrink = 5, Potion = 1, Flasksphials = 3 },
	TooltipDataType = { Item = 0 },
}

_G.C_Map = {
	GetBestMapForUnit = function() return Mock.world.mapID end,
	GetMapInfo = function(mapID) return Mock.world.maps[mapID] end,
}

_G.IsResting = function() return Mock.world.resting == true end
_G.GetRestState = function() return (Mock.world.resting or Mock.world.restStateRested) and 1 or 2 end
_G.UnitIsPVPSanctuary = function() return Mock.world.sanctuary == true end

_G.C_Container = {
	GetContainerNumSlots = function(bag)
		local b = Mock.world.bags[bag]
		return b and b.size or 0
	end,
	GetContainerNumFreeSlots = function(bag)
		local b = Mock.world.bags[bag]
		if not b then return 0 end
		local used = 0
		for _ in pairs(b.items or {}) do used = used + 1 end
		return b.size - used
	end,
	GetContainerItemInfo = function(bag, slot)
		local b = Mock.world.bags[bag]
		if not b then return nil end
		return (b.items or {})[slot]
	end,
}

_G.C_Item = {
	GetItemInfoInstant = function(itemID)
		local d = Mock.world.itemInfo[itemID] or {}
		return itemID, d.itemType, d.itemSubType, nil, nil, d.classID, d.subClassID
	end,
	GetItemInfo = function(itemLinkOrID)
		local d = Mock.world.itemInfo[itemLinkOrID]
			or (Mock.world.links and Mock.world.links[itemLinkOrID])
		if not d then return nil end
		-- name, link, quality, itemLevel, minLevel, type, subType, stack, equipLoc, texture
		-- 10e retour = texture : indispensable pour vérifier que l'icône
		-- provient bien du lien (et pas uniquement de l'API d'emplacement)
		return d.name, d.link or itemLinkOrID, d.quality, d.itemLevel, 1,
			d.itemType or "Armure", d.itemSubType or "", 1, d.equipLoc, d.texture
	end,
	GetItemStats = function(itemLink)
		local d = (Mock.world.links and Mock.world.links[itemLink]) or {}
		return d.stats
	end,
	GetItemStatDelta = function(newLink, oldLink)
		local newStats = ((Mock.world.links or {})[newLink] or {}).stats or {}
		local oldStats = ((Mock.world.links or {})[oldLink] or {}).stats or {}
		local delta = {}
		for key, value in pairs(newStats) do
			delta[key] = value - (oldStats[key] or 0)
		end
		for key, value in pairs(oldStats) do
			if delta[key] == nil then delta[key] = -value end
		end
		return delta
	end,
}

_G.ITEM_QUALITY_COLORS = {
	[0] = { r = 0.62, g = 0.62, b = 0.62 },
	[1] = { r = 1.00, g = 1.00, b = 1.00 },
	[2] = { r = 0.12, g = 1.00, b = 0.00 },
	[3] = { r = 0.00, g = 0.44, b = 0.87 },
	[4] = { r = 0.64, g = 0.21, b = 0.93 },
}

-- Le client expose GetItemInfo en global (classique et Era) ; le mock doit le
-- faire aussi, sinon tout chemin qui interroge l'API globale échoue en silence.
_G.GetItemInfo = function(itemLinkOrID)
	return _G.C_Item.GetItemInfo(itemLinkOrID)
end
_G.GetInventoryItemLink = function(_, slot)
	return (Mock.world.equipped or {})[slot]
end
_G.GetInventoryItemTexture = function(_, slot)
	if (Mock.world.equipped or {})[slot] then
		return "Interface\\Icons\\INV_Mock" .. tostring(slot)
	end
	return nil
end

_G.GameTooltip = NewRegion("GameTooltip", "GameTooltip")
function GameTooltip:GetItem() return nil, Mock.world.hoveredLink end
function GameTooltip:GetRight() return 0 end
function GameTooltip:SetOwner() end
function GameTooltip:ClearLines() self.lines = {} end
function GameTooltip:AddLine(text) self.lines = self.lines or {}; self.lines[#self.lines + 1] = tostring(text) end
function GameTooltip:AddDoubleLine(a, b) self:AddLine(tostring(a) .. " " .. tostring(b)) end
function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false end

Mock.tooltipCallback = nil
_G.TooltipDataProcessor = {
	AddTooltipPostCall = function(_, callback) Mock.tooltipCallback = callback end,
}

_G.C_UnitAuras = {
	GetAuraDataByIndex = function(_, index)
		local spellId = Mock.world.auraOrder[index]
		if not spellId then return nil end
		local aura = Mock.world.auras[spellId]
		if not aura then return nil end
		return { spellId = spellId, duration = aura.duration or 0, name = aura.name }
	end,
	GetPlayerAuraBySpellID = function(spellId)
		if Mock.secretAuras then error("attempt to read a secret value") end
		return Mock.world.auras[spellId] or nil
	end,
}

_G.GetXPExhaustion = function() return Mock.world.rested end
_G.UnitXPMax = function() return Mock.world.xpMax end
_G.GetInventoryItemDurability = function(slot)
	local d = Mock.world.durability[slot]
	if not d then return nil end
	return d[1], d[2]
end

_G.PlayerFrame = NewRegion("Frame", "PlayerFrame")
_G.SetPortraitTexture = function(texture, unit)
	texture:SetTexture("Interface\\CharacterFrame\\TempPortrait" .. tostring(unit))
end
_G.RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
_G.C_Timer = { After = function(delay, fn) Mock.world.timers = Mock.world.timers or {}; Mock.world.timers[#Mock.world.timers + 1] = fn end }

_G.UnitLevel = function() return Mock.world.level or 11 end
_G.UnitStat = function(_, index) return (Mock.world.stats or {})[index] or 0 end
_G.UnitArmor = function() return 0, Mock.world.armor or 0 end
_G.UnitDamage = function() local d = Mock.world.damage or { 0, 0 }; return d[1], d[2] end
_G.UnitAttackSpeed = function()
	local speed = Mock.world.attackSpeed or 0
	return speed, speed          -- main, off : comme le vrai client
end
_G.UnitAttackPower = function()
	local ap = Mock.world.attackPower or 0
	return ap, 0, 0, ap          -- base, posBuff, negBuff, effective
end
_G.GetCritChance = function() return Mock.world.crit or 0 end
_G.GetHaste = function() return Mock.world.haste or 0 end
_G.GetAverageItemLevel = function() return Mock.world.ilvl or 0, Mock.world.ilvl or 0 end
_G.UnitClass = function() return "Guerrier", Mock.world.classToken or "WARRIOR", 1 end
_G.GetSpecialization = function() return Mock.world.specIndex or 1 end
_G.GetSpecializationInfo = function() return 71, Mock.world.specName or "Armes" end

_G.GetTradeSkillLine = function() return "Alchimie", "Alchemy", 1 end
_G.GetTradeSkillSelectionIndex = function() return Mock.world.tradeSkillSelection or 0 end
_G.GetTradeSkillInfo = function(index)
	local recipe = (Mock.world.tradeSkillRecipes or {})[index]
	if not recipe then return nil end
	return recipe.name, recipe.header and "header" or "normal", 1
end
_G.GetTradeSkillNumReagents = function(index)
	local recipe = (Mock.world.tradeSkillRecipes or {})[index]
	return recipe and #(recipe.reagents or {}) or 0
end
_G.GetTradeSkillReagentInfo = function(index, slot)
	local recipe = (Mock.world.tradeSkillRecipes or {})[index]
	local reagent = recipe and (recipe.reagents or {})[slot]
	if not reagent then return nil end
	return reagent.name, nil, reagent.need, reagent.have
end

_G.GetNumQuestLogEntries = function() return #(Mock.world.quests or {}) end
_G.GetQuestLogTitle = function(index)
	local q = (Mock.world.quests or {})[index]
	if not q then return nil end
	-- title, level, tag, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID
	return q.title, 1, nil, nil, q.isHeader == true, false, q.ready == true, 1, q.questID
end

_G.C_TradeSkillUI = {
	GetRecipesTracked = function()
		if Mock.world.trackedUnavailable then error("trade skill API unavailable") end
		return Mock.world.trackedRecipes or {}
	end,
	GetRecipeSchematic = function(recipeID)
		local schematics = Mock.world.recipeSchematics or {}
		return schematics[recipeID]
	end,
	GetCraftableCount = function(recipeID)
		local counts = Mock.world.craftableCounts or {}
		return counts[recipeID] or 0
	end,
}

_G.C_QuestLog = {
	GetNumQuestLogEntries = function() return #Mock.world.quests end,
	GetInfo = function(index)
		local q = Mock.world.quests[index]
		if not q then return nil end
		return { questID = q.questID, title = q.title }
	end,
	ReadyForTurnIn = function(questID)
		for _, q in ipairs(Mock.world.quests) do
			if q.questID == questID then return q.ready == true end
		end
		return false
	end,
}

-- v1.18.0 : sous-zones, vol, mort, marchand, entraîneur, foyer
_G.GetSubZoneText = function() return Mock.world.subzone or "" end
_G.UnitOnTaxi = function() return Mock.world.onTaxi == true end
_G.UnitIsDeadOrGhost = function() return Mock.world.dead == true end
_G.UnitName = function() return "Testeur" end
_G.GetRealmName = function() return "Royaume" end
_G.GetItemCount = function(itemID)
	local count = 0
	for _, bag in pairs(Mock.world.bags or {}) do
		for _, item in pairs(bag.items or {}) do
			if item.itemID == itemID then count = count + (item.stackCount or 1) end
		end
	end
	return count
end
_G.GetInventoryItemCount = function(_, slot)
	if slot == 0 then return Mock.world.ammo or 0 end
	return 0
end
_G.GetBindLocation = function() return Mock.world.bind or "Comté-de-l'Or" end
_G.GetItemCooldown = function(itemID)
	local cd = (Mock.world.cooldowns or {})[itemID]
	if not cd then return 0, 0, 1 end
	return cd[1], cd[2], 1
end
_G.GetMoney = function() return Mock.world.money or 0 end
_G.CanMerchantRepair = function() return Mock.world.canRepair == true end
_G.GetRepairAllCost = function()
	local cost = Mock.world.repairCost or 0
	return cost, cost > 0
end
_G.RepairAllItems = function()
	Mock.world.money = (Mock.world.money or 0) - (Mock.world.repairCost or 0)
	Mock.world.repaired = (Mock.world.repaired or 0) + 1
	Mock.world.repairCost = 0
	for _, d in pairs(Mock.world.durability or {}) do d[1] = d[2] end
end
_G.IsTradeskillTrainer = function() return Mock.world.tradeskillTrainer == true end
_G.C_Container.UseContainerItem = function(bag, slot)
	local b = Mock.world.bags[bag]
	local item = b and b.items and b.items[slot]
	if not item then return end
	Mock.world.sold = Mock.world.sold or {}
	Mock.world.sold[#Mock.world.sold + 1] = item.itemID
	b.items[slot] = nil
end

-- Fait avancer l'horloge et la machine à états (l'OnUpdate du client)
function Mock:Advance(seconds)
	Mock.now = Mock.now + (seconds or 0)
	for _, frame in ipairs(Mock.frames) do
		if frame.scripts and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, seconds or 0) end
	end
end
-- Joue les C_Timer.After en attente (vente par tranches)
function Mock:RunTimers()
	local guard = 0
	while Mock.world.timers and #Mock.world.timers > 0 and guard < 50 do
		local list = Mock.world.timers
		Mock.world.timers = {}
		for _, fn in ipairs(list) do fn() end
		guard = guard + 1
	end
end

----------------------------------------------------------------------------
-- 2. Chargement de l'addon (comme le client : chunk(nom, tablePrivée))
----------------------------------------------------------------------------
local NS = {}
-- QuestCompanion (sous-dossier) : addon séparé, qui dépend de Ready2Quest et
-- reprend son namespace via _G.Ready2Quest ; sa table privée reste à part.
local QC_PRIVATE = {}
local function LoadAddonFile(name)
	local path = ROOT .. "/" .. name
	local handle, err = io.open(path, "r")
	assert(handle, "ouverture impossible: " .. path .. " (" .. tostring(err) .. ")")
	local source = handle:read("*a")
	handle:close()
	local chunk, compileError = loadstring(source, "@" .. path)
	assert(chunk, "erreur de compilation dans " .. path .. ":\n" .. tostring(compileError))
	-- comme le client : chaque addon reçoit son nom et sa propre table privée
	if name:find("^QuestCompanion/") then
		chunk("QuestCompanion", QC_PRIVATE)
	else
		chunk("Ready2Quest", NS)
	end
end

-- La liste des fichiers vient du .toc, comme pour le client : un module
-- ajouté au .toc est chargé ici sans autre modification.
-- Ready2Quest d'abord, puis QuestCompanion. Chaque fichier est listé avec le
-- dossier de son addon : « Ready2Quest/Core.lua », « QuestCompanion/Companion.lua ».
local tocFiles = {}
do
	local function ReadToc(toc, prefix)
		local handle = assert(io.open(ROOT .. "/" .. toc, "r"), toc .. " introuvable")
		for line in handle:lines() do
			line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
			if line ~= "" and not line:find("^#") and line:find("%.lua$") then tocFiles[#tocFiles + 1] = prefix .. line end
		end
		handle:close()
	end
	ReadToc("Ready2Quest/Ready2Quest.toc", "Ready2Quest/")
	ReadToc("QuestCompanion/QuestCompanion.toc", "QuestCompanion/")
end
-- Les scénarios historiques comptent les contrôles et pages du cœur (13
-- contrôles, 10 entrées de navigation…) : les fichiers de module du .toc ne
-- sont chargés qu'avant leurs propres tests (4.99), pour ne pas fausser ces
-- comptes à chaque nouveau module.
-- (dans un bloc : le corps principal frôle la limite de 200 locales)
Mock.moduleFiles = {}
do
	local core = {}
	for _, file in ipairs({ "Bootstrap.lua", "Locales.lua", "Compat.lua", "Hubs.lua", "Theme.lua", "Core.lua", "Buffs.lua",
		"Reagents.lua", "Merchant.lua", "Equip.lua", "Stats.lua", "Minimap.lua", "Checks.lua", "Options.lua", "UI.lua" }) do
		core[file] = true
	end
	for _, file in ipairs(tocFiles) do
		if core[file:gsub("^Ready2Quest/", "")] then LoadAddonFile(file) else table.insert(Mock.moduleFiles, file) end
	end
end
_G.TOC_FILES = tocFiles

----------------------------------------------------------------------------
-- 3. Assertions
----------------------------------------------------------------------------
local lines, passed, failed = {}, 0, 0
local function Say(text)
	lines[#lines + 1] = tostring(text)
	-- permet au lanceur d'afficher ce qui a été fait jusqu'au plantage éventuel
	_G.TEST_PARTIAL = table.concat(lines, "\n")
end

local function Check(name, condition, extra)
	if condition then
		passed = passed + 1
		Say("PASS  " .. name)
	else
		failed = failed + 1
		Say("FAIL  " .. name .. (extra ~= nil and ("  -> " .. tostring(extra)) or ""))
	end
end

local function Result(id)
	for _, result in ipairs(NS.lastResults or {}) do
		if result.id == id then return result end
	end
	return nil
end

local function ResetWorld()
	Mock.world = {
		mapID = 1,
		maps = {
			[1]  = { mapID = 1,  name = "Capitale",       parentMapID = 0 },
			[20] = { mapID = 20, name = "Plaine sauvage", parentMapID = 0 },
			[30] = { mapID = 30, name = "Village",        parentMapID = 0 },
		},
		resting = false,
		sanctuary = false,
		bags = { [0] = { size = 16, items = {} } },
		auras = {},
		auraOrder = {},
		rested = 0,
		xpMax = 10000,
		durability = {},
		quests = {},
		itemInfo = {},
		trackedRecipes = {},
		recipeSchematics = {},
		craftableCounts = {},
		trackedUnavailable = false,
		equipped = {},
		links = {},
		hoveredLink = nil,
		noButtonTemplate = false,
		minimapShape = "ROUND",
		build = { version = "1.60.1", build = "69893", date = "Oct 1 2026", toc = 16001 },
		level = 11,
		stats = { 25, 14, 30, 12 },
		armor = 506,
		damage = { 20, 24 },
		attackSpeed = 1.96,
		attackPower = 120,
		crit = 4.5,
		haste = 0,
		ilvl = 18,
		specName = "Armes",
		specIndex = 1,
		tradeSkillSelection = 0,
		tradeSkillRecipes = {},
	}
	Mock.secretAuras = false
	Mock.now = 1000
	Mock:Reset()
	-- les deux : la nouvelle variable, et l ancienne que Core migre
	_G.Ready2QuestDB = nil
	_G.QuestCompanionDB = nil
	_G.ReadyToQuestDB = nil
	_G.SacEtDepartDB = nil
	NS._dbReady = false
	NS.inSafe = nil
	NS.lastAlert = nil
	NS.quietUntil = nil
	NS.lastResults = nil
	NS.window = nil
	NS.lastBuffScan = nil
	NS.bagAlerted = nil
	NS.optionsFrame = nil
	NS.stuffFrame = nil
	NS.toastFrame = nil
	NS.portraitFrame = nil
	NS.statBefore = nil
	NS.toastHideAt = nil
	NS.score = nil
	NS.lastAdvice = nil
	NS.pendingExit = nil
	NS.lastSafePlace = nil
	NS.lastDeparture = nil
	NS.merchantOpen = nil
	NS.sellRun = nil
	NS.safePurgeNotice = nil
	NS.hubIndex = nil
	NS.wasAtCamp = nil
	NS.departed = nil
	if NS.InvalidateReagents then NS:InvalidateReagents() end
end

----------------------------------------------------------------------------
-- 4. Scénarios
----------------------------------------------------------------------------
-- 4.1 Chargement
Say("== chargement ==")
Check("table de locale chargée", type(NS.L) == "table")

-- Migration du renommage Sac & Départ -> Ready to Quest : une sauvegarde
-- existante sous l'ancien nom doit être reprise, sinon chaque joueur perdrait
-- ses zones sûres apprises et ses réglages au passage.
ResetWorld()
_G.SacEtDepartDB = { safe = { [1234] = true }, alertCooldown = 99, showWindow = false }
NS._dbReady = false
local migrated = NS:DB()
-- v1.18.0 : les zones par mapID (schéma 1) sont purgées, pas reprises
Check("migration : anciennes zones par mapID purgées",
	migrated.safe ~= nil and migrated.safe[1234] == nil and migrated.safeSchema == 2,
	migrated.safe and tostring(migrated.safe[1234]))
Check("migration : purge annoncée une fois", NS.safePurgeNotice == 1, tostring(NS.safePurgeNotice))
Check("migration : le réglage personnalisé est conservé", migrated.showWindow == false,
	tostring(migrated.showWindow))
Check("migration : la variable porte le nouveau nom",
	_G.Ready2QuestDB == migrated)
Check("migration : l'ancienne variable est libérée",
	_G.SacEtDepartDB == nil)

-- v1.21.0 : Ready to Quest -> Ready2Quest (ReadyToQuestDB -> Ready2QuestDB)
ResetWorld()
_G.ReadyToQuestDB = { safeSchema = 2, safe = { ["v:30:Village"] = { kind = "village", name = "Village" } },
	popupScore = 70, optionsPage = "bags" }
_G.SacEtDepartDB = { popupScore = 10 }
NS._dbReady = false
local migrated2 = NS:DB()
Check("migration R2Q : réglages repris de ReadyToQuestDB", migrated2.popupScore == 70, migrated2.popupScore)
Check("migration R2Q : villages appris conservés", migrated2.safe["v:30:Village"] ~= nil)
Check("migration R2Q : la sauvegarde la plus récente gagne", NS.migratedFrom == "ReadyToQuestDB", NS.migratedFrom)
Check("migration R2Q : anciennes variables libérées", _G.ReadyToQuestDB == nil and _G.SacEtDepartDB == nil)
Check("migration R2Q : nouvelle variable", _G.Ready2QuestDB == migrated2)

-- sans ancienne sauvegarde, une table neuve avec les défauts
ResetWorld()
NS._dbReady = false
local fresh = NS:DB()
Check("sans migration : les défauts sont posés", fresh.showWindow == true,
	tostring(fresh.showWindow))
Check("13 checks enregistrés", #(NS.checks or {}) == 13, NS.checks and #NS.checks)
Check("installation neuve : pas d'annonce de purge", NS.safePurgeNotice == nil)
Check("commande /sd enregistrée", type(SlashCmdList["SACETDEPART"]) == "function")
Check("événement PLAYER_UPDATE_RESTING écouté", NS.eventFrame and NS.eventFrame.events.PLAYER_UPDATE_RESTING == true)

-- 4.2 Entrée en capitale : repos dans deux quartiers -> carte entière apprise
Say("\n== capitale et repos ==")
ResetWorld()
Mock.world.resting = true
Mock.world.subzone = "Quartier commerçant"
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Check("entrée en capitale -> zone sûre", NS.inSafe == true, tostring(NS.inSafe))
Check("un seul quartier : capitale pas encore apprise", NS:DB().safe["c:1"] == nil)
Mock.world.subzone = "Vieille ville"
Mock:Fire("ZONE_CHANGED")
Check("capitale apprise après deux quartiers en repos", NS:DB().safe["c:1"] ~= nil)
local citySource = NS:DB().safe["c:1"] and NS:DB().safe["c:1"].source
Check("source de l'apprentissage = repos", citySource == "resting", citySource)
Check("capitale : kind = city", NS:DB().safe["c:1"] and NS:DB().safe["c:1"].kind == "city")
-- hors de la zone de repos mais dans un quartier jamais visité : toujours sûr
Mock.world.resting = false
Mock.world.subzone = "Port"
Check("capitale apprise : sûre même sans repos", NS:IsCurrentZoneSafe() == true)

-- 4.3 Sortie vers une zone sauvage : alerte après le délai de confirmation
Say("\n== sortie de zone sûre ==")
Mock.now = Mock.now + 60
Mock.world.mapID = 20
Mock.world.subzone = nil
Mock.world.quests = { { questID = 11, ready = true }, { questID = 12, ready = false } }
Mock:Fire("ZONE_CHANGED_NEW_AREA")
Check("sortie : pas d'alerte immédiate", NS.lastResults == nil)
Check("sortie : en attente de confirmation", NS.pendingExit ~= nil)
Mock:Advance(3)
Check("sortie : toujours rien à 3 s", NS.lastResults == nil)
Mock:Advance(3)
Check("alerte déclenchée à la sortie (6 s)", NS.lastResults ~= nil)
Check("état basculé à non-sûr", NS.inSafe == false)
Check("départ mémorisé : capitale", NS.lastDeparture and NS.lastDeparture.name == "Capitale",
	NS.lastDeparture and NS.lastDeparture.name)
local restResult = Result("rest")
Check("check repos en échec (0 repos)", restResult and restResult.ok == false, restResult and restResult.detail)
local questResult = Result("quests")
Check("quête prête détectée", questResult and questResult.ok == false and questResult.detail:find("1") ~= nil,
	questResult and questResult.detail)

-- 4.4 Sacs presque pleins + objets gris
Say("\n== sacs et butin ==")
ResetWorld()
for i = 1, 13 do
	Mock.world.bags[0].items[i] = { itemID = 2000 + i, stackCount = 1, quality = 1 }
end
Mock.world.bags[0].items[14] = { itemID = 3001, stackCount = 1, quality = 0 }
Mock.world.itemInfo[3001] = { name = "Croc cassé", quality = 0, classID = 15, subClassID = 0 }
NS:RunChecklist("manual")
local bagsResult = Result("bags")
Check("sacs presque pleins signalés", bagsResult and bagsResult.ok == false, bagsResult and bagsResult.detail)
local grayResult = Result("gray")
Check("objet gris signalé", grayResult and grayResult.ok == false, grayResult and grayResult.detail)

-- 4.5 Vivres et potions selon les sous-classes d'objet
Say("\n== vivres et potions ==")
ResetWorld()
Mock.world.itemInfo[4001] = { name = "Pain noir", classID = 0, subClassID = 5 }
Mock.world.itemInfo[4002] = { name = "Eau claire", classID = 0, subClassID = 5 }
Mock.world.itemInfo[4003] = { name = "Potion de soin", classID = 0, subClassID = 1 }
Mock.world.bags[0].items[1] = { itemID = 4001, stackCount = 5, quality = 1 }
Mock.world.bags[0].items[2] = { itemID = 4002, stackCount = 5, quality = 1 }
Mock.world.bags[0].items[3] = { itemID = 4003, stackCount = 2, quality = 1 }
NS:RunChecklist("manual")
local vivresResult = Result("vivres")
Check("vivres détectés (10 unités)", vivresResult and vivresResult.ok == true, vivresResult and vivresResult.detail)
Check("détail vivres contient 10", vivresResult and vivresResult.detail:find("10") ~= nil, vivresResult and vivresResult.detail)
NS:DB().potionsThreshold = 3
NS:RunChecklist("manual")
local potionsResult = Result("potions")
Check("potions sous le seuil signalées", potionsResult and potionsResult.ok == false, potionsResult and potionsResult.detail)

-- 4.6 Durabilité
Say("\n== durabilité ==")
ResetWorld()
Mock.world.durability[5] = { 10, 100 }
NS:RunChecklist("manual")
local duraResult = Result("durability")
Check("durabilité basse signalée", duraResult and duraResult.ok == false, duraResult and duraResult.detail)
Check("détail durabilité = 10%", duraResult and duraResult.detail:find("10") ~= nil, duraResult and duraResult.detail)

-- 4.7 Apprentissage et contrôle des buffs
Say("\n== buffs ==")
ResetWorld()
Mock.world.auras = { [1459] = { name = "Intelligence des arcanes", duration = 3600 } }
Mock.world.auraOrder = { 1459 }
Mock:Fire("UNIT_AURA", "player")
Check("buff appris depuis l'aura", NS:DB().buffs[1459] ~= nil)
Check("nom du buff conservé", NS:DB().buffs[1459] and NS:DB().buffs[1459].name == "Intelligence des arcanes")
Mock.world.auras = {}
Mock.world.auraOrder = {}
NS:RunChecklist("manual")
local buffResult = Result("buffs")
Check("buff manquant signalé", buffResult and buffResult.ok == false, buffResult and buffResult.detail)
Check("nom du buff dans le détail", buffResult and buffResult.detail:find("Intelligence") ~= nil, buffResult and buffResult.detail)

-- 4.8 Proc court ignoré par l'apprentissage
Say("\n== filtrage des procs ==")
ResetWorld()
Mock.world.auras = { [9999] = { name = "Proc court", duration = 12 } }
Mock.world.auraOrder = { 9999 }
Mock:Fire("UNIT_AURA", "player")
Check("proc de 12 s non appris", NS:DB().buffs[9999] == nil)

-- 4.9 Valeurs secrètes : inconnu, pas d'alerte
Say("\n== valeurs secrètes (restriction d'API) ==")
ResetWorld()
NS:DB().buffs[1459] = { name = "Intelligence des arcanes", duration = 3600, enabled = true }
Mock.secretAuras = true
NS:RunChecklist("manual")
local secretResult = Result("buffs")
Check("aura secrète -> pas d'alerte", secretResult and secretResult.ok == true, secretResult and secretResult.detail)
Mock.secretAuras = false

-- 4.10 Village sans repos : deux indices faibles de types différents
Say("\n== village sans repos (indices) ==")
ResetWorld()
Mock.world.mapID = 30
Mock.world.subzone = "Comté-de-l'Or"
Mock.world.resting = false
Mock:Fire("MERCHANT_SHOW")
Check("un marchand seul ne suffit pas", NS:DB().safe["v:30:Comté-de-l'Or"] == nil)
Check("indice marchand mémorisé", NS:DB().safeClues["v:30:Comté-de-l'Or"]
	and NS:DB().safeClues["v:30:Comté-de-l'Or"].types.merchant == true)
Mock:Fire("MERCHANT_SHOW")
Check("deux fois le même type ne suffit pas", NS:DB().safe["v:30:Comté-de-l'Or"] == nil)
Mock:Fire("QUEST_DETAIL")
Check("village appris : marchand + quête", NS:DB().safe["v:30:Comté-de-l'Or"] ~= nil)
Check("source = merchant+quest", NS:DB().safe["v:30:Comté-de-l'Or"]
	and NS:DB().safe["v:30:Comté-de-l'Or"].source == "merchant+quest")
Check("indices effacés après apprentissage", NS:DB().safeClues["v:30:Comté-de-l'Or"] == nil)
Check("village considéré comme sûr", NS.inSafe == true)
Check("le reste de la zone n'est PAS sûr", (function()
	Mock.world.subzone = "Ferme des Brookshire"
	local safe = NS:IsCurrentZoneSafe()
	Mock.world.subzone = "Comté-de-l'Or"
	return safe == false
end)())
-- sortir du village sans changer de carte : c'est le bug corrigé en v1.18.0
Mock.now = Mock.now + 60
Mock.world.subzone = "Ferme des Brookshire"
Mock:Fire("ZONE_CHANGED")
Mock:Advance(6)
Check("alerte à la sortie du village (même carte)", NS.lastResults ~= nil)
Check("parti de : Comté-de-l'Or", NS:DepartedText() ~= nil and NS:DepartedText():find("Comté") ~= nil,
	NS:DepartedText())
Check("parti de : source lisible", NS:DepartedText():find("marchand %+ quête") ~= nil, NS:DepartedText())

-- les indices persistent d'une session à l'autre (dans la SavedVariable)
ResetWorld()
Mock.world.mapID = 30
Mock.world.subzone = "Long-guet"
Mock:Fire("TRAINER_SHOW")
local saved = _G.Ready2QuestDB
NS._dbReady = false
_G.Ready2QuestDB = saved
Mock:Fire("MERCHANT_SHOW")
Check("indices persistés : entraîneur + marchand", NS:DB().safe["v:30:Long-guet"] ~= nil)

-- 4.11 Indices forts : un seul suffit
Say("\n== indices forts ==")
for _, case in ipairs({
	{ event = "MAIL_SHOW", source = "mail" },
	{ event = "CONFIRM_BINDER", source = "binder" },
	{ event = "TAXIMAP_OPENED", source = "taxi" },
	{ event = "BANKFRAME_OPENED", source = "bank" },
}) do
	ResetWorld()
	Mock.world.mapID = 30
	Mock.world.subzone = "Village"
	Mock:Fire(case.event)
	local entry = NS:DB().safe["v:30:Village"]
	Check(case.event .. " : village appris", entry ~= nil and entry.source == case.source,
		entry and entry.source)
end
ResetWorld()
Mock.world.mapID = 30
Mock.world.subzone = "Village"
Mock.world.resting = true
Mock:Fire("PLAYER_UPDATE_RESTING")
-- v1.22.0 : le repos seul n'apprend plus (feux de camp de Forever)
Check("repos seul : rien n'est appris", NS:DB().safe["v:30:Village"] == nil)
Mock:Fire("MERCHANT_SHOW"); Mock:Fire("MERCHANT_CLOSED")
Check("repos + marchand : village appris", NS:DB().safe["v:30:Village"] ~= nil
	and NS:DB().safe["v:30:Village"].source == "merchant+resting", NS:DB().safe["v:30:Village"] and NS:DB().safe["v:30:Village"].source)
ResetWorld()
Mock.world.mapID = 30
Mock.world.subzone = nil
Mock:Fire("MAIL_SHOW")
local anyLearned = next(NS:DB().safe) ~= nil
Check("sans sous-zone : rien n'est appris", anyLearned == false)

-- GetRestState = XP de repos en réserve, PAS une zone de repos
ResetWorld()
Mock.world.mapID = 20
Mock.world.restStateRested = true
Check("bonus de repos en réserve : pas une zone sûre", NS:IsCurrentZoneSafe() == false)

-- 4.12 Anti-spam, retour avant le délai, vol, mort, délai réglable
Say("\n== sortie : anti-spam, retour, vol, mort ==")
local function EnterVillage()
	ResetWorld()
	NS:DB().safe["v:30:Village"] = { kind = "village", name = "Village", mapID = 30, subzone = "Village", source = "manual" }
	Mock.world.mapID = 30
	Mock.world.subzone = "Village"
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock.now = Mock.now + 60
end
local function LeaveVillage()
	Mock.world.subzone = "Bois"
	Mock:Fire("ZONE_CHANGED")
end

EnterVillage()
LeaveVillage()
Mock:Advance(6)
Check("première alerte passée", NS.lastAlert ~= nil)
Mock.world.subzone = "Village"
Mock:Fire("ZONE_CHANGED")
Mock.now = Mock.now + 1
NS.lastResults = nil
LeaveVillage()
Mock:Advance(6)
Check("pas de seconde alerte dans la fenêtre de cooldown", NS.lastResults == nil)

EnterVillage()
LeaveVillage()
Mock:Advance(3)
Mock.world.subzone = "Village"
Mock:Fire("ZONE_CHANGED")
Mock:Advance(10)
Check("retour au village avant 6 s : alerte annulée", NS.lastResults == nil and NS.pendingExit == nil)

EnterVillage()
Mock.world.onTaxi = true
LeaveVillage()
Mock:Advance(30)
Check("en vol : pas d'alerte", NS.lastResults == nil and NS.pendingExit ~= nil)
Mock.world.onTaxi = false
Mock:Advance(1)
Check("atterrissage : le délai repart", NS.lastResults == nil)
Mock:Advance(6)
Check("atterrissage hors zone sûre : alerte", NS.lastResults ~= nil)

EnterVillage()
Mock.world.onTaxi = true
LeaveVillage()
Mock:Advance(30)
Mock.world.subzone = "Village"
Mock:Fire("ZONE_CHANGED")
Mock.world.onTaxi = false
Mock:Advance(10)
Check("atterrissage en zone sûre : rien", NS.lastResults == nil)

EnterVillage()
Mock.world.dead = true
LeaveVillage()
Mock:Advance(10)
Check("mort ou fantôme : pas d'alerte", NS.lastResults == nil and NS.pendingExit == nil)

EnterVillage()
NS:DB().exitDelay = 0
LeaveVillage()
Check("délai 0 : alerte immédiate", NS.lastResults ~= nil)
EnterVillage()
NS:DB().exitDelay = 99
Check("délai borné à 15 s", NS:ExitDelay() == 15)

ResetWorld()
NS:DB().safe["v:30:Village"] = { kind = "village", name = "Village", mapID = 30, subzone = "Village", source = "manual" }
Mock.world.mapID = 30
Mock.world.subzone = "Village"
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Mock.now = Mock.now + 5
LeaveVillage()
Mock:Advance(6)
Check("silence après connexion conservé", NS.lastResults == nil)

-- 4.13 Pas d'alerte entre deux zones sûres
Say("\n== deux zones sûres ==")
ResetWorld()
NS:DB().safe["c:1"] = { kind = "city", name = "Capitale", mapID = 1, source = "manual" }
NS:DB().safe["v:30:Village"] = { kind = "village", name = "Village", mapID = 30, subzone = "Village", source = "manual" }
Mock.world.mapID = 1
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Mock.now = Mock.now + 20
Mock.world.mapID = 30
Mock.world.subzone = "Village"
Mock:Fire("ZONE_CHANGED_NEW_AREA")
Mock:Advance(10)
Check("aucune alerte entre deux zones sûres", NS.lastResults == nil)

-- 4.14 Chaîne de cartes parentes
Say("\n== cartes parentes ==")
ResetWorld()
Mock.world.maps[5] = { mapID = 5, name = "Quartier", parentMapID = 1 }
NS:DB().safe["c:1"] = { kind = "city", name = "Capitale", mapID = 1, source = "manual" }
Mock.world.mapID = 5
local safeInSubmap = NS:IsCurrentZoneSafe()
Check("sous-carte d'une capitale = sûre", safeInSubmap == true)

-- 4.15 Commandes
Say("\n== commandes ==")
ResetWorld()
Mock.world.mapID = 30
Mock.world.subzone = "Village"
NS:HandleCommand("safe")
Check("/sd safe marque le village", NS:DB().safe["v:30:Village"] ~= nil
	and NS:DB().safe["v:30:Village"].source == "manual")
NS:HandleCommand("unsafe")
Check("/sd unsafe retire le village", NS:DB().safe["v:30:Village"] == nil)
Mock.world.subzone = nil
Mock:Reset()
NS:HandleCommand("safe")
Check("/sd safe sans sous-zone : refus expliqué", Mock:Output():find("Pas de village") ~= nil, Mock:Output())
NS:DB().safe["c:30"] = { kind = "city", name = "Ville", mapID = 30, source = "resting" }
NS:DB().cityRest[30] = { A = true, B = true }
NS:HandleCommand("unsafe")
Check("/sd unsafe retire la capitale", NS:DB().safe["c:30"] == nil and NS:DB().cityRest[30] == nil)
Mock.world.subzone = "Village"
NS:HandleCommand("safe")
Mock:Reset()
NS:HandleCommand("safe list")
Check("/sd safe list affiche le village", Mock:Output():find("Village") ~= nil
	and Mock:Output():find("manuel") ~= nil, Mock:Output())
NS:DB().safeClues["v:30:X"] = { types = { merchant = true } }
NS:HandleCommand("safe reset")
Check("/sd safe reset efface tout", next(NS:DB().safe) == nil and next(NS:DB().safeClues) == nil)
NS:HandleCommand("seuil 8")
Check("/sd seuil change le seuil", NS:DB().bagFreeThreshold == 8)
NS:HandleCommand("off")
Check("/sd off désactive", NS:DB().enabled == false)
NS:HandleCommand("on")
Check("/sd on réactive", NS:DB().enabled == true)
NS:HandleCommand("list")
Check("/sd list s'exécute", Mock:Output():find("Zones sûres connues") ~= nil)
NS:HandleCommand("buffs")
Check("/sd buffs s'exécute", Mock:Output():find("Buffs suivis") ~= nil)
NS:HandleCommand("diag")
Check("/sd diag s'exécute", Mock:Output():find("Diagnostic") ~= nil)
NS:HandleCommand("nimportequoi")
Check("commande inconnue gérée", Mock:Output():find("Commande inconnue") ~= nil)

-- 4.16 Composants de métier : composant manquant nommé
Say("\n== composants de métier ==")
ResetWorld()
Mock.world.trackedRecipes = { 1001, 1002 }
Mock.world.craftableCounts = { [1001] = 3, [1002] = 0 }
Mock.world.recipeSchematics = {
	[1001] = { name = "Potion de soin", reagentSlotSchematics = {
		{ quantityRequired = 2, reagents = { { itemID = 7001 } } },
	} },
	[1002] = { name = "Elixir de mana", reagentSlotSchematics = {
		{ quantityRequired = 10, reagents = { { itemID = 7002 } } },
		{ quantityRequired = 1, reagents = { { itemID = 7003 } } },
	} },
}
Mock.world.itemInfo[7001] = { name = "Herbe", classID = 7, subClassID = 2 }
Mock.world.itemInfo[7002] = { name = "Etoffe de lin", classID = 7, subClassID = 5 }
Mock.world.itemInfo[7003] = { name = "Fiole vide", classID = 7, subClassID = 0 }
Mock.world.bags[0].items[1] = { itemID = 7002, stackCount = 4, quality = 1 }
Mock.world.bags[0].items[2] = { itemID = 7003, stackCount = 1, quality = 1 }
NS:RunChecklist("manual")
local reagentResult = Result("reagents")
Check("recette bloquée signalée", reagentResult and reagentResult.ok == false, reagentResult and reagentResult.detail)
Check("composant manquant nommé", reagentResult and reagentResult.detail:find("Etoffe de lin") ~= nil,
	reagentResult and reagentResult.detail)
Check("déficit calculé (10 - 4 = 6)", reagentResult and reagentResult.detail:find("6") ~= nil,
	reagentResult and reagentResult.detail)

-- 4.17 Toutes les recettes fabricables
Say("\n== recettes fabricables ==")
Mock.world.craftableCounts = { [1001] = 3, [1002] = 1 }
NS:InvalidateReagents()
NS:RunChecklist("manual")
local okReagents = Result("reagents")
Check("toutes fabricables -> OK", okReagents and okReagents.ok == true, okReagents and okReagents.detail)

-- 4.18 Aucune recette suivie
Say("\n== aucune recette suivie ==")
ResetWorld()
NS:RunChecklist("manual")
local noneReagents = Result("reagents")
Check("aucune recette suivie -> OK", noneReagents and noneReagents.ok == true, noneReagents and noneReagents.detail)

-- 4.19 API métier indisponible : pas de plantage
Say("\n== API métier indisponible ==")
ResetWorld()
Mock.world.trackedUnavailable = true
NS:InvalidateReagents()
NS:RunChecklist("manual")
local unavailable = Result("reagents")
Check("API métier en erreur -> OK sans plantage", unavailable and unavailable.ok == true,
	unavailable and unavailable.detail)

-- 4.20 Invalidation du cache sur TRACKED_RECIPE_UPDATE
Say("\n== cache des composants ==")
ResetWorld()
Mock.world.trackedRecipes = { 1001 }
Mock.world.craftableCounts = { [1001] = 0 }
Mock.world.recipeSchematics = { [1001] = { name = "Potion de soin", reagentSlotSchematics = {} } }
NS:InvalidateReagents()
NS:RunChecklist("manual")
Check("recette bloquée avant mise à jour", Result("reagents") and Result("reagents").ok == false)
Mock.world.craftableCounts = { [1001] = 5 }
Mock.world.recipeSchematics = { [1001] = { name = "Potion de soin", reagentSlotSchematics = {} } }
Mock:Fire("TRACKED_RECIPE_UPDATE")
NS:RunChecklist("manual")
Check("cache invalidé par l'événement", Result("reagents") and Result("reagents").ok == true,
	Result("reagents") and Result("reagents").detail)

-- 4.21 Alerte sac plein en continu
Say("\n== alerte sac plein continue ==")
ResetWorld()
for i = 1, 14 do
	Mock.world.bags[0].items[i] = { itemID = 5000 + i, stackCount = 1, quality = 1 }
end
Mock:Reset()
Mock:Fire("BAG_UPDATE_DELAYED")
Check("alerte sac plein émise", Mock:Output():find("Sacs presque pleins") ~= nil, Mock:Output())
Mock:Reset()
Mock:Fire("BAG_UPDATE_DELAYED")
Check("pas de doublon tant que les sacs restent pleins", Mock:Output():find("Sacs presque pleins") == nil)
Mock.world.bags[0] = { size = 16, items = {} }
Mock:Fire("BAG_UPDATE_DELAYED")
for i = 1, 14 do
	Mock.world.bags[0].items[i] = { itemID = 6000 + i, stackCount = 1, quality = 1 }
end
Mock:Reset()
Mock:Fire("BAG_UPDATE_DELAYED")
Check("alerte réarmée après désengorgement", Mock:Output():find("Sacs presque pleins") ~= nil)

-- 4.22 Alerte sac désactivable
Say("\n== alerte sac désactivable ==")
ResetWorld()
NS:DB().continuousBagAlert = false
for i = 1, 14 do
	Mock.world.bags[0].items[i] = { itemID = 7000 + i, stackCount = 1, quality = 1 }
end
Mock:Reset()
Mock:Fire("BAG_UPDATE_DELAYED")
Check("alerte désactivée silencieuse", Mock:Output():find("Sacs presque pleins") == nil)

-- 4.23 Panneau de réglages
Say("\n== panneau de réglages ==")
ResetWorld()
NS:RefreshOptions()
Check("RefreshOptions sans panneau ne plante pas", true)
NS:HandleCommand("options")
Check("panneau créé", NS.optionsFrame ~= nil)
Check("panneau affiché", NS.optionsFrame and NS.optionsFrame.shown == true)
Check("31 lignes (17 réglages + 1 action + 13 contrôles)", NS.optionsFrame and #NS.optionsFrame.rows == 31, NS.optionsFrame and #NS.optionsFrame.rows)

local boolRow
for _, row in ipairs(NS.optionsFrame.rows) do
	if row.def and row.def.key == "showWindow" then boolRow = row end
end
local boolBefore = NS:DB().showWindow
boolRow:Click()
Check("clic bascule un booléen", NS:DB().showWindow ~= boolBefore)
boolRow:Click()
Check("second clic rebascule", NS:DB().showWindow == boolBefore)

-- on repère la ligne par sa clé : l'ordre du panneau peut évoluer
local numberRow
for _, row in ipairs(NS.optionsFrame.rows) do
	if row.def and row.def.key == "bagFreeThreshold" then numberRow = row end
end
Check("ligne de seuil trouvée", numberRow ~= nil)
local numberBefore = NS:DB().bagFreeThreshold
numberRow.plus:Click()
Check("bouton + incrémente", NS:DB().bagFreeThreshold == numberBefore + 1, NS:DB().bagFreeThreshold)
numberRow.minus:Click()
Check("bouton - décrémente", NS:DB().bagFreeThreshold == numberBefore, NS:DB().bagFreeThreshold)

NS:RefreshOptions()
Check("valeur affichée après rafraîchissement",
	numberRow.value and numberRow.value.text:find(tostring(numberBefore)) ~= nil, numberRow.value and numberRow.value.text)

NS:HandleCommand("options")
Check("seconde commande referme le panneau", NS.optionsFrame.shown == false)

-- 4.24 Commande /sd compo
Say("\n== commande compo ==")
ResetWorld()
Mock.world.trackedRecipes = { 1001 }
Mock.world.craftableCounts = { [1001] = 2 }
Mock.world.recipeSchematics = { [1001] = { name = "Potion de soin", reagentSlotSchematics = {} } }
NS:InvalidateReagents()
Mock:Reset()
NS:HandleCommand("compo")
Check("/sd compo liste la recette", Mock:Output():find("Potion de soin") ~= nil, Mock:Output())

-- 4.25 Score pondéré et bilan
Say("\n== score pondéré ==")
ResetWorld()
NS:RunChecklist("manual")
Check("score calculé dans 0..100", type(NS.score) == "number" and NS.score >= 0 and NS.score <= 100, NS.score)

ResetWorld()
Mock.world.rested = 6000
Mock.world.durability[1] = { 100, 100 }
Mock.world.itemInfo[4001] = { name = "Pain", classID = 0, subClassID = 5 }
Mock.world.bags[0].items[1] = { itemID = 4001, stackCount = 20, quality = 1 }
NS:RunChecklist("manual")
Check("monde idéal -> score haut", NS.score >= 85, NS.score)
local readyLabel, readyColor = NS:ScoreLabel()
Check("bilan vert", readyColor == "green", readyColor)

ResetWorld()
NS:RunChecklist("manual")
Check("monde dégradé -> score moyen", NS.score < 85, NS.score)
Check("conseils générés", #(NS.lastAdvice or {}) > 0, #(NS.lastAdvice or {}))

ResetWorld()
Mock.world.bags[0].items = {}
for i = 1, 16 do Mock.world.bags[0].items[i] = { itemID = 900 + i, stackCount = 1, quality = 0 } end
Mock.world.bags[1] = { size = 16, items = {} }
for i = 1, 16 do Mock.world.bags[1].items[i] = { itemID = 950 + i, stackCount = 1, quality = 1 } end
Mock.world.durability[1] = { 10, 100 }
NS:RunChecklist("manual")
Check("monde catastrophique -> score bas", NS.score < 60, NS.score)
local badLabel, badColor = NS:ScoreLabel()
Check("bilan rouge", badColor == "red", badColor)

-- 4.26 Fenêtre de diagnostic en DA WoW
Say("\n== fenêtre de diagnostic ==")
ResetWorld()
NS:RunChecklist("manual")
Check("fenêtre créée", NS.window ~= nil)
Check("fenêtre affichée", NS.window and NS.window.shown == true)
Check("13 lignes de modules", NS.window and #NS.window.rows == 13)
Check("score affiché", NS.window and NS.window.scoreValue.text:find(tostring(NS.score)) ~= nil,
	NS.window and NS.window.scoreValue.text)
Check("barre de score remplie", NS.window and NS.window.scoreBar.fill.width > 0,
	NS.window and NS.window.scoreBar.fill.width)
Check("détail du premier module", NS.window.rows[1].detail.text ~= "", NS.window.rows[1].detail.text)
Check("losange de statut posé", NS.window.rows[1].status and tostring(NS.window.rows[1].status.texture):find("losange") ~= nil,
	NS.window.rows[1].status and NS.window.rows[1].status.texture)
Check("verdict affiché à côté de la note", NS.window.verdict and NS.window.verdict.text ~= "",
	NS.window.verdict and NS.window.verdict.text)

-- pièces faibles : le sous-titre du panneau doit les compter
ResetWorld()
Mock.world.equipped[1] = "item:100"
Mock.world.links["item:100"] = { name = "Heaume", quality = 3, itemLevel = 50, equipLoc = "INVTYPE_HEAD" }
Mock.world.equipped[5] = "item:101"
Mock.world.links["item:101"] = { name = "Plastron", quality = 2, itemLevel = 48, equipLoc = "INVTYPE_CHEST" }
Mock.world.equipped[8] = "item:102"
Mock.world.links["item:102"] = { name = "Bottes", quality = 1, itemLevel = 20, equipLoc = "INVTYPE_FEET" }
Check("pièce faible détectée", NS:WeakSlotCount() == 1, NS:WeakSlotCount())

-- 4.27 Panneau d'équipement : supprimé en v1.16.0
Say("\n== panneau supprimé ==")
ResetWorld()
Mock.world.equipped[1] = "item:100"
Mock.world.links["item:100"] = { name = "Heaume de test", quality = 3, itemLevel = 42, equipLoc = "INVTYPE_HEAD" }
Mock.world.equipped[5] = "item:101"
Mock.world.links["item:101"] = { name = "Plastron de test", quality = 2, itemLevel = 40, equipLoc = "INVTYPE_CHEST" }
Check("le panneau flottant n'existe plus", NS.EnsureStuff == nil and NS.ShowStuff == nil and NS.ToggleStuff == nil)
-- un bouton pointait encore vers L.OPT_STUFF_SHORT, supprimé avec le panneau :
-- il affichait la clé brute "OPT_STUFF_SHORT" et appelait une fonction absente
Check("plus de bouton de stuff dans la fenêtre de diagnostic",
	NS.window == nil or NS.window.stuffButton == nil)
-- L renvoie la cle brute quand elle manque (repli de la metatable) : c'est
-- exactement ce qui affichait "OPT_STUFF_SHORT" a l'ecran. On verifie donc la
-- resolution, pas l'absence.
Check("le libellé OPT_STUFF_SHORT n'est plus traduit",
	NS.L.OPT_STUFF_SHORT == "OPT_STUFF_SHORT", tostring(NS.L.OPT_STUFF_SHORT))

-- garde-fou général : toute clé utilisée par le code doit être traduite
local missing = {}
local function ScanFile(file)
	local f = io.open(ROOT .. "/" .. file, "rb")
	if not f then return end
	local data = f:read("*a")
	f:close()
	for key in data:gmatch("L%.([A-Z][A-Z0-9_]+)") do
		local value = NS.L[key]
		if (value == nil or value == key) and not missing[key] then
			missing[#missing + 1] = key
		end
	end
end
for _, file in ipairs({ "UI.lua", "Options.lua", "Core.lua", "Stats.lua", "Equip.lua",
                        "Checks.lua", "Minimap.lua", "Buffs.lua", "Reagents.lua" }) do
	ScanFile(file)
end
Check("aucune clé de traduction non résolue", #missing == 0, table.concat(missing, ", "))
Check("aucun cadre de stuff construit", NS.stuffFrame == nil)
Check("niveau d'objet moyen toujours calculé", NS:AverageItemLevel() == 41, NS:AverageItemLevel())
Check("le réglage d'affichage du panneau a disparu",
	NS.OPT_LAYOUT ~= nil and NS:DB().showStuff == nil)

-- 4.30 Sortie de zone sûre : la fenêtre doit s'ouvrir toute seule
Say("\n== ouverture automatique en quittant une zone sûre ==")
ResetWorld()
NS:DB().safe = { ["c:1"] = { kind = "city", name = "Capitale", mapID = 1, source = "manual" } }
NS:DB().alertCooldown = 0
NS:DB().showWindow = true
NS.inSafe = true                        -- on part d'une zone sûre
NS.quietUntil = nil
NS.lastAlert = nil
NS.lastResults = nil
if NS.window then NS.window:Hide() end

-- on passe sur une map inconnue : sortie de zone sûre, confirmée après le délai
Mock.world.mapID = 20
NS:Evaluate("zone")
Mock:Advance(6)

Check("quitter la zone sûre lance le check", NS.lastResults ~= nil,
	NS.lastResults and #NS.lastResults)
Check("et ouvre la fenêtre", NS.window ~= nil and NS.window.shown == true,
	NS.window and tostring(NS.window.shown))

-- on reste en zone non sûre : pas de nouvelle alerte
NS.lastResults = nil
NS:Evaluate("zone")
Mock:Advance(6)
Check("rester dehors ne relance pas le check", NS.lastResults == nil)

-- et en zone sûre, rien ne s'ouvre
if NS.window then NS.window:Hide() end
Mock.world.mapID = 1
NS:Evaluate("zone")
Mock:Advance(6)
Check("en zone sûre la fenêtre reste fermée",
	NS.window ~= nil and NS.window.shown ~= true, NS.window and tostring(NS.window.shown))

-- à nouveau dehors : ça repart
Mock.world.mapID = 20
NS:Evaluate("zone")
Mock:Advance(6)
Check("une seconde sortie relance l'alerte", NS.lastResults ~= nil)

-- Pied de la fenêtre de diagnostic (v1.25.0) : un seul appel « Partir à
-- l'aventure » en bleu, plus de « Lancer le check » ni de « Réglages » (déjà
-- sur l'icône de la minicarte) ; une flèche discrète relance le check.
do
	local win, diag = NS.window, NS.DIAG_LAYOUT
	Check("pied : géométrie exposée", diag ~= nil and diag.adventureWidth ~= nil)
	Check("pied : plus de bouton « Lancer » ni « Réglages »", win.runButton == nil and win.optionsButton == nil)
	local adv = win.adventureButton
	Check("pied : « Partir à l'aventure » présent", adv ~= nil and adv:GetText() == NS.L.DIAG_ADVENTURE, adv and adv:GetText())
	Check("pied : bouton en bleu de nuit", adv.style == "adventure" and adv.bg.vertex[3] > 0.8 and adv.bg.vertex[1] < 0.4)
	local probe = win:CreateFontString(nil, "OVERLAY")
	probe:SetText(NS.L.DIAG_ADVENTURE)
	Check("pied : le texte tient dans le bouton", (adv:GetWidth() or 0) >= probe:GetStringWidth(),
		(adv:GetWidth() or 0) .. " >= " .. probe:GetStringWidth())
	local point = adv:GetPoint()
	Check("pied : bouton centré", point == "BOTTOM", point)
	Check("pied : tient dans la fenêtre", (adv:GetWidth() or 0) <= diag.width - 28, adv:GetWidth())
	win:Show()
	adv:Click()
	Check("pied : « Partir à l'aventure » ferme la fenêtre", win:IsShown() == false)
	-- flèche de rafraîchissement
	local refresh = win.refreshButton
	Check("flèche : icône du jeu (UI-RefreshButton)", refresh and tostring(refresh.icon.texture):find("UI%-RefreshButton") ~= nil,
		refresh and refresh.icon.texture)
	Check("flèche : discrète au repos", (refresh.icon.alpha or 1) < 1)
	refresh:GetScript("OnEnter")(refresh)
	Check("flèche : pleine au survol", refresh.icon.alpha == 1)
	refresh:GetScript("OnLeave")(refresh)
	NS.lastResults, NS.score = nil, nil
	refresh:Click()
	Check("flèche : relance le check", NS.lastResults ~= nil and win:IsShown() == true)
	Check("flèche : un tour sur elle-même", refresh.spin ~= nil and refresh.spin.plays >= 1)
	Check("flèche : ne touche pas le « Parti de »", select(4, win.subtitle:GetPoint()) <= -58)
end

-- 4.31 Bouton sans template Blizzard
Say("\n== robustesse sans template ==")
ResetWorld()
Mock.world.noButtonTemplate = true
NS:RunChecklist("manual")
Check("panneau construit sans UIPanelButtonTemplate", NS.window ~= nil)
Mock.world.noButtonTemplate = false

-- 4.32 Commande /sd stuff
Say("\n== commande stuff ==")
ResetWorld()
Mock:Reset()
-- la commande imprime le résumé en chat au lieu de piloter un panneau
Mock:Reset()
NS:HandleCommand("stuff")
Check("/sd stuff répond sans erreur", Mock:Output() ~= nil and #Mock:Output() > 0)
Check("/sd stuff ne parle plus de panneau", Mock:Output():find("Panneau") == nil, Mock:Output())
Check("/sd stuff n'a plus d'état à basculer", NS:DB().showStuff == nil)

-- 4.33 Mode Classic Era : API manquantes
Say("\n== mode Classic Era ==")
ResetWorld()
local savedDelta = C_Item.GetItemStatDelta
local savedStats = C_Item.GetItemStats
local savedTrade = _G.C_TradeSkillUI
local savedNumQuest = C_QuestLog.GetNumQuestLogEntries
C_Item.GetItemStatDelta = nil
C_Item.GetItemStats = nil
_G.C_TradeSkillUI = nil
C_QuestLog.GetNumQuestLogEntries = nil
Mock.world.build = { version = "1.15.9", build = "69722", date = "Oct 2026", toc = 11509 }
NS:DetectCapabilities()

Check("client identifié comme Classic Era", NS:ClientFlavour() == "Classic Era", NS:ClientFlavour())
Check("capacité crafting à false", NS.Caps.crafting == false)
Check("capacité quêtes via globales", NS.Caps.quests == true)

Mock.world.quests = { { questID = 11, title = "Un", ready = true }, { questID = 12, title = "Deux", ready = false } }
Mock.world.rested = 3000
Mock.world.bags[0].items[1] = { itemID = 4001, stackCount = 5, quality = 1 }
Mock.world.itemInfo[4001] = { name = "Pain", classID = 0, subClassID = 5 }

NS:RunChecklist("manual")
Check("checklist tourne sans les API récentes", NS.lastResults ~= nil and #NS.lastResults == 13, NS.lastResults and #NS.lastResults)
local qClassic = Result("quests")
Check("quêtes via GetNumQuestLogEntries", qClassic and qClassic.ok == false and qClassic.detail:find("1") ~= nil,
	qClassic and qClassic.detail)
local rClassic = Result("reagents")
Check("composants sans API métier -> OK", rClassic and rClassic.ok == true, rClassic and rClassic.detail)

Mock.world.equipped[1] = "item:100"
Mock.world.links["item:100"] = { name = "Vieux heaume", quality = 2, itemLevel = 30, equipLoc = "INVTYPE_HEAD", stats = { ITEM_MOD_STAMINA_SHORT = 5 } }
Mock.world.links["item:200"] = { name = "Heaume neuf", quality = 3, itemLevel = 40, equipLoc = "INVTYPE_HEAD", stats = {} }

-- restauration
C_Item.GetItemStatDelta = savedDelta
C_Item.GetItemStats = savedStats
_G.C_TradeSkillUI = savedTrade
C_QuestLog.GetNumQuestLogEntries = savedNumQuest
Mock.world.build = { version = "1.60.1", build = "69893", date = "Oct 1 2026", toc = 16001 }
NS:DetectCapabilities()
Check("retour au client moderne", NS:ClientFlavour() == "Forever", NS:ClientFlavour())

-- 4.34 Absence du template BackdropTemplate
Say("\n== client sans BackdropTemplate ==")
ResetWorld()
Mock.world.noBackdropTemplate = true
NS:RunChecklist("manual")
Check("panneau construit sans BackdropTemplate", NS.window ~= nil)
Mock.world.noBackdropTemplate = false

-- 4.35 Aucune API de quêtes du tout
Say("\n== aucune API de quêtes ==")
ResetWorld()
local savedLegacyNum = _G.GetNumQuestLogEntries
local savedLegacyTitle = _G.GetQuestLogTitle
_G.GetNumQuestLogEntries = nil
_G.GetQuestLogTitle = nil
local savedNum2 = C_QuestLog.GetNumQuestLogEntries
C_QuestLog.GetNumQuestLogEntries = nil
NS:RunChecklist("manual")
local qNone = Result("quests")
Check("quêtes sans API -> OK silencieux", qNone and qNone.ok == true, qNone and qNone.detail)
_G.GetNumQuestLogEntries = savedLegacyNum
_G.GetQuestLogTitle = savedLegacyTitle
C_QuestLog.GetNumQuestLogEntries = savedNum2

-- 4.36 Détection du client par numéro d'interface
Say("\n== détection du client ==")
ResetWorld()
Check("Forever détecté", NS:ClientFlavour() == "Forever", NS:ClientFlavour())

Mock.world.build = { version = "5.5.4", build = "69934", date = "Oct 2026", toc = 50504 }
Check("MoP Classic détecté", NS:ClientFlavour() == "Mists Classic", NS:ClientFlavour())

Mock.world.build = { version = "1.15.9", build = "69722", date = "Oct 2026", toc = 11509 }
Check("Classic Era détecté", NS:ClientFlavour() == "Classic Era", NS:ClientFlavour())

Mock.world.build = { version = "2.5.6", build = "69795", date = "Oct 2026", toc = 20506 }
Check("TBC Classic détecté", NS:ClientFlavour() == "TBC Classic", NS:ClientFlavour())

Mock.world.build = { version = "12.1.5", build = "69900", date = "Oct 2026", toc = 120100 }
Check("Retail détecté", NS:ClientFlavour() == "Retail", NS:ClientFlavour())

ResetWorld()

-- 4.37 MoP Classic : les modules dégradés se comportent bien
Say("\n== MoP Classic ==")
ResetWorld()
Mock.world.build = { version = "5.5.4", build = "69934", date = "Oct 2026", toc = 50504 }
local sDelta, sTrade, sNum = C_Item.GetItemStatDelta, _G.C_TradeSkillUI, C_QuestLog.GetNumQuestLogEntries
local sStats = C_Item.GetItemStats
C_Item.GetItemStatDelta = nil
C_Item.GetItemStats = nil
_G.C_TradeSkillUI = nil
C_QuestLog.GetNumQuestLogEntries = nil
NS:DetectCapabilities()
local probeMoP = NewRegion("Frame", "probeMoP")
Mock.world.unknownEvents = { TRACKED_RECIPE_UPDATE = true }
local skippedMoP = NS:RegisterEvents(probeMoP)
Mock.world.unknownEvents = nil
Check("MoP : événement retail jamais tenté", #skippedMoP == 0, table.concat(skippedMoP, ", "))
Check("MoP : événements de base enregistrés", probeMoP.events.PLAYER_ENTERING_WORLD == true
	and probeMoP.events.MERCHANT_SHOW == true)
Check("MoP : client identifié", NS:ClientFlavour() == "Mists Classic", NS:ClientFlavour())
Check("MoP : quêtes via globales disponibles", NS.Caps.quests == true)
Mock.world.quests = { { questID = 21, title = "Quête", ready = true } }
NS:RunChecklist("manual")
local qMop = Result("quests")
Check("MoP : quête prête détectée", qMop and qMop.ok == false, qMop and qMop.detail)
C_Item.GetItemStatDelta = sDelta
C_Item.GetItemStats = sStats
_G.C_TradeSkillUI = sTrade
C_QuestLog.GetNumQuestLogEntries = sNum
NS:DetectCapabilities()
ResetWorld()

-- 4.38 Bootstrap : la commande survit à un échec de chargement
Say("\n== bootstrap et diagnostic ==")
ResetWorld()
Check("commande enregistrée par le bootstrap", type(SlashCmdList["SACETDEPART"]) == "function")
Check("version exposée", NS.version == "1.26.0", NS.version)

local missingMods = {}
for _, name in ipairs({ "Bootstrap", "Locales", "Compat", "Theme", "Core", "Buffs", "Reagents",
	"Equip", "Stats", "Minimap", "Checks", "Options", "UI" }) do
	if not (NS.Loaded and NS.Loaded[name]) then missingMods[#missingMods + 1] = name end
end
Check("13 modules marqués chargés", #missingMods == 0, table.concat(missingMods, ", "))

-- repli quand Core.lua n'a pas abouti
local savedHandle = NS.HandleCommand
NS.HandleCommand = nil
Mock:Reset()
SlashCmdList["SACETDEPART"]("diag")
Check("repli explicite si Core absent", Mock:Output():find("modules non charg") ~= nil, Mock:Output())
NS.HandleCommand = savedHandle

-- /sd diag liste l'état des modules
Mock:Reset()
NS:HandleCommand("diag")
Check("/sd diag liste les modules", Mock:Output():find("modules :") ~= nil, Mock:Output())
Check("/sd diag affiche la version", Mock:Output():find("1%.26%.0") ~= nil, Mock:Output())

-- une erreur est enregistrée et affichée
Mock:Reset()
local before = #NS.errors
NS:RecordError("test", "message de test")
Check("erreur enregistrée", #NS.errors == before + 1)
Check("erreur affichée dans le chat", Mock:Output():find("message de test") ~= nil, Mock:Output())

-- une erreur de check ne fait pas tomber la checklist
ResetWorld()
local savedChecks = NS.checks
NS.checks = {
	{ id = "boom", weight = 10, label = function() return "Boom" end, run = function() error("boum") end },
	{ id = "ok", weight = 90, label = function() return "Ok" end, run = function() return true, "bien", 100 end },
}
NS:RunChecklist("manual")
Check("check en erreur isolé", NS.lastResults and #NS.lastResults == 1, NS.lastResults and #NS.lastResults)
Check("erreur de check enregistrée", #NS.errors > 0)
NS.checks = savedChecks

-- 4.39 Événement inconnu du client : l'addon doit survivre
Say("\n== événement non supporté ==")
ResetWorld()
Mock.world.unknownEvents = { TRACKED_RECIPE_UPDATE = true }
local probe = NewRegion("Frame", "probe")
local skipped = NS:RegisterEvents(probe)
Check("événement inconnu ignoré", #skipped == 1 and skipped[1] == "TRACKED_RECIPE_UPDATE",
	table.concat(skipped, ", "))
Check("les autres événements sont enregistrés", probe.events.ZONE_CHANGED_NEW_AREA == true
	and probe.events.PLAYER_ENTERING_WORLD == true and probe.events.UNIT_AURA == true)
Check("erreur consignée", (NS.errors[#NS.errors] or {}).message ~= nil
	and tostring((NS.errors[#NS.errors] or {}).message):find("TRACKED_RECIPE_UPDATE") ~= nil,
	(NS.errors[#NS.errors] or {}).message)
Check("liste exposée pour /sd diag", NS.unsupportedEvents and NS.unsupportedEvents[1] == "TRACKED_RECIPE_UPDATE")

-- la checklist fonctionne toujours sans cet événement
NS:RunChecklist("manual")
Check("checklist OK malgré l'événement manquant", NS.lastResults ~= nil and #NS.lastResults == 13)
Mock.world.unknownEvents = nil

-- 4.40 Composants de métier en mode Classic (API legacy)
Say("\n== métiers Classic (legacy) ==")
ResetWorld()
local sDelta2, sCraft2 = C_Item.GetItemStatDelta, _G.C_TradeSkillUI
C_Item.GetItemStatDelta = nil
_G.C_TradeSkillUI = nil
Mock.world.build = { version = "1.15.9", build = "69722", date = "Oct 2026", toc = 11509 }
NS:DetectCapabilities()
Check("capacité tradeskillLegacy détectée", NS.Caps.tradeskillLegacy == true)

Mock.world.tradeSkillRecipes = {
	{ name = "Elixir de mana", reagents = {
		{ name = "Etoffe de lin", need = 10, have = 4 },
		{ name = "Fiole vide", need = 1, have = 3 },
	} },
}
Mock.world.tradeSkillSelection = 1
Mock.world.itemInfo[7002] = { name = "Etoffe de lin", classID = 7 }
Mock.world.itemInfo[7003] = { name = "Fiole vide", classID = 7 }
Mock.world.bags[0].items[1] = { itemID = 7002, stackCount = 4, quality = 1 }
Mock.world.bags[0].items[2] = { itemID = 7003, stackCount = 3, quality = 1 }

NS:ScanLegacyTradeSkill()
NS:InvalidateReagents()
NS:RunChecklist("manual")
local legacyResult = Result("reagents")
Check("recette sélectionnée lue", legacyResult ~= nil)
Check("composant manquant nommé (legacy)", legacyResult and legacyResult.ok == false
	and legacyResult.detail:find("Etoffe de lin") ~= nil, legacyResult and legacyResult.detail)
Check("déficit legacy = 6", legacyResult and legacyResult.detail:find("6") ~= nil,
	legacyResult and legacyResult.detail)

-- en-tête de métier ignoré
Mock.world.tradeSkillRecipes[1].header = true
NS:ScanLegacyTradeSkill()
Mock.world.tradeSkillRecipes[1].header = nil

C_Item.GetItemStatDelta = sDelta2
_G.C_TradeSkillUI = sCraft2
NS:DetectCapabilities()
ResetWorld()

-- 4.44 Lanceur sur la minicarte
Say("\n== bouton de minicarte ==")
ResetWorld()
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
local lancer = NS.minimapButton
Check("bouton créé", lancer ~= nil)
Check("bouton affiché", lancer and lancer.shown == true)
Check("positionné sur l'anneau", lancer and #lancer.points > 0)

-- v1.18.0 : clic gauche = action principale (le check), clic droit = réglages
NS.lastResults = nil
lancer:Click("LeftButton")
Check("clic gauche lance le check", NS.lastResults ~= nil)

lancer:Click("RightButton")
Check("clic droit ouvre les réglages", NS.optionsFrame and NS.optionsFrame.shown == true)

-- glissement autour de la minicarte
Mock.world.cursorX, Mock.world.cursorY = 580, 500
NS.minimapDragMoved = nil
NS:UpdateMinimapDrag()
Check("glissement met à jour l'angle", math.abs(NS:DB().minimapAngle or 999) < 1, NS:DB().minimapAngle)
Check("drapeau de glissement posé", NS.minimapDragMoved == true)

NS.optionsFrame:Hide()
lancer:Click("RightButton")
Check("clic ignoré juste après un glissement", NS.optionsFrame.shown == false)

-- infobulle
if lancer.scripts and lancer.scripts.OnEnter then lancer.scripts.OnEnter(lancer) end
Check("infobulle affichée", GameTooltip.shown == true)
Check("infobulle liste les actions", GameTooltip.lines and #GameTooltip.lines >= 3, GameTooltip.lines and #GameTooltip.lines)
if lancer.scripts and lancer.scripts.OnLeave then lancer.scripts.OnLeave(lancer) end
Check("infobulle masquée à la sortie", GameTooltip.shown == false)

-- commande
Mock:Reset()
NS:HandleCommand("minimap off")
Check("/sd minimap off masque", lancer.shown == false and NS:DB().showMinimap == false)
Check("message affiché", Mock:Output():find("masqué") ~= nil, Mock:Output())
NS:HandleCommand("minimap on")
Check("/sd minimap on réaffiche", lancer.shown == true and NS:DB().showMinimap == true)

-- réglage depuis le panneau d'options
NS:ToggleOptions()
local minimapRow
for _, row in ipairs(NS.optionsFrame.rows) do
	if row.def and row.def.key == "showMinimap" then minimapRow = row end
end
Check("ligne dédiée dans les réglages", minimapRow ~= nil)
Check("31 lignes au total", NS.optionsFrame and #NS.optionsFrame.rows == 31, #NS.optionsFrame.rows)
if minimapRow then minimapRow:Click() end
Check("décocher masque le bouton", lancer.shown == false)
if minimapRow then minimapRow:Click() end
Check("recocher réaffiche le bouton", lancer.shown == true)

-- 4.45 Activation / désactivation des modules
Say("\n== modules activables ==")
ResetWorld()
Check("tous les modules actifs par défaut", NS:IsModuleEnabled("bags") == true)
local activeCount, totalCount = NS:EnabledModuleCount()
Check("13 modules actifs au départ", activeCount == 13 and totalCount == 13, activeCount .. "/" .. totalCount)

-- score de référence, tous modules actifs
Mock.world.rested = 0
Mock.world.durability[1] = { 10, 100 }
NS:RunChecklist("manual")
local scoreAll = NS.score
local bagsAll = Result("bags")

-- on désactive les sacs : la note doit monter, et le module sort du calcul
NS:SetModuleEnabled("bags", false)
NS:RunChecklist("manual")
Check("module désactivé marqué", Result("bags") and Result("bags").disabled == true)
Check("poids nul pour un module désactivé", Result("bags") and Result("bags").weight == 0)
Check("note recalculée sans le module", NS.score ~= scoreAll, scoreAll .. " -> " .. tostring(NS.score))
Check("détail = désactivé", Result("bags") and Result("bags").detail == "désactivé",
	Result("bags") and Result("bags").detail)
Check("compteur mis à jour", select(1, NS:EnabledModuleCount()) == 12, select(1, NS:EnabledModuleCount()))

-- tous désactivés : plus aucun poids -> score 0, pas de division par zéro
for _, def in ipairs(NS.checks) do NS:SetModuleEnabled(def.id, false) end
NS:RunChecklist("manual")
Check("aucun module actif -> score 0", NS.score == 0, NS.score)
Check("toujours 13 lignes affichées", #NS.lastResults == 13, #NS.lastResults)

-- réactivation
for _, def in ipairs(NS.checks) do NS:SetModuleEnabled(def.id, true) end
NS:RunChecklist("manual")
Check("réactivation rétablit la note", NS.score == scoreAll or NS.score ~= 0, NS.score)

-- panneau : une ligne par module
NS:ToggleOptions()
local moduleRows = 0
for _, row in ipairs(NS.optionsFrame.rows) do
	if row.isModule then moduleRows = moduleRows + 1 end
end
Check("13 interrupteurs de module dans le panneau", moduleRows == 13, moduleRows)

local bagsRow
for _, row in ipairs(NS.optionsFrame.rows) do
	if row.isModule and row.moduleId == "bags" then bagsRow = row end
end
Check("ligne du module sacs trouvée", bagsRow ~= nil)
bagsRow:Click()
Check("clic désactive le module", NS:IsModuleEnabled("bags") == false)
bagsRow:Click()
Check("second clic réactive", NS:IsModuleEnabled("bags") == true)

-- commandes
Mock:Reset()
NS:HandleCommand("module vivres off")
Check("/sd module off", NS:IsModuleEnabled("vivres") == false)
Check("message de confirmation", Mock:Output():find("désactivé") ~= nil, Mock:Output())
NS:HandleCommand("module vivres on")
Check("/sd module on", NS:IsModuleEnabled("vivres") == true)
Mock:Reset()
NS:HandleCommand("module inexistant off")
Check("module inconnu signalé", Mock:Output():find("inconnu") ~= nil, Mock:Output())
Mock:Reset()
NS:HandleCommand("modules")
Check("/r2q modules : les 3 modules", Mock:Output():find("Check avant le départ") and Mock:Output():find("Résumé de stuff")
	and Mock:Output():find("Stats du portrait") and not Mock:Output():find("Vivres"), Mock:Output())
Mock:Reset()
NS:HandleCommand("checks")
Check("/r2q checks : les 13 contrôles", Mock:Output():find("13") and Mock:Output():find("Vivres"), Mock:Output())
NS:HandleCommand("check vivres off")
Check("/r2q check vivres off", NS:IsModuleEnabled("vivres") == false)
NS:HandleCommand("check vivres on")
Mock:Reset()
NS:HandleCommand("check inexistant off")
Check("contrôle inconnu signalé", Mock:Output():find("Contrôle inconnu") ~= nil, Mock:Output())
NS:HandleCommand("module depart off")
Check("/r2q module depart off", NS:DB().departureEnabled == false)
NS:HandleCommand("module check on")
Check("alias : module check on", NS:DB().departureEnabled == true)
NS:HandleCommand("module stuff off")
Check("/r2q module stuff off", NS:DB().showGearToast == false)
NS:HandleCommand("module portrait off")
Check("/r2q module portrait off", NS:DB().showPortraitStats == false)
NS:HandleCommand("module stuff on"); NS:HandleCommand("module portrait on")
Mock:Reset()
NS:HandleCommand("help")
local helpOut = Mock:Output()
Check("/r2q help : aide classée", helpOut:find("Zones sûres") and helpOut:find("/r2q module <depart") and helpOut:find("/r2q diag"), helpOut)
Mock:Reset()
NS:HandleCommand("aide")
Check("/r2q aide = help", Mock:Output() == helpOut)
Mock:Reset()
NS:HandleCommand("nimportequoi")
local _, unknownLines = Mock:Output():gsub("\n", "\n")
Check("commande inconnue : une seule ligne vers l'aide", unknownLines == 0 and Mock:Output():find("/r2q help") ~= nil, Mock:Output())

-- un module désactivé ne génère pas de conseil
ResetWorld()
NS:SetModuleEnabled("vivres", false)
NS:RunChecklist("manual")
local vivresAdvice = false
for _, entry in ipairs(NS.lastAdvice or {}) do
	if entry.text == "Achète des vivres chez l'aubergiste." then vivresAdvice = true end
end
Check("module désactivé sans conseil", vivresAdvice == false)
NS:SetModuleEnabled("vivres", true)

-- 4.46 Une seule fenêtre à la fois + positions mémorisées
Say("\n== fenêtres exclusives ==")
ResetWorld()
NS:RunChecklist("manual")
Check("diagnostic affiché", NS.window and NS.window:IsShown() == true)

NS:ToggleOptions()
Check("ouvrir les réglages ferme le diagnostic", NS.window:IsShown() == false)
Check("réglages affichés", NS.optionsFrame and NS.optionsFrame:IsShown() == true)

NS:RunChecklist("manual")
Check("relancer le check ferme les réglages", NS.optionsFrame:IsShown() == false)
Check("diagnostic réaffiché", NS.window:IsShown() == true)

-- position du diagnostic mémorisée après déplacement
ResetWorld()
NS:RunChecklist("manual")
local dragScript = NS.window:GetScript("OnDragStop")
Check("script de déplacement présent", type(dragScript) == "function")
if dragScript then dragScript(NS.window) end
-- on n'impose plus une valeur précise : le point mémorisé doit simplement
-- être un ancrage valide avec deux coordonnées numériques. Les anciennes
-- assertions se contentaient de comparer au mock avec lui-même.
local diag = NS:DB().diagPoint
Check("position du diagnostic enregistrée", diag ~= nil and type(diag.point) == "string",
	diag and diag.point)
Check("coordonnées enregistrées", diag ~= nil and type(diag.x) == "number"
	and type(diag.y) == "number", diag and (tostring(diag.x) .. "," .. tostring(diag.y)))

-- position des réglages mémorisée
NS:ToggleOptions()
local optDrag = NS.optionsFrame:GetScript("OnDragStop")
Check("script de déplacement des réglages présent", type(optDrag) == "function")
if optDrag then optDrag(NS.optionsFrame) end
Check("position des réglages enregistrée", NS:DB().optionsPoint ~= nil
	and type(NS:DB().optionsPoint.point) == "string")

-- restauration : une position enregistrée est réappliquée
ResetWorld()
NS:DB().diagPoint = { point = "TOPLEFT", x = 42, y = -84 }
NS.window = nil
NS:RunChecklist("manual")
Check("position restaurée au démarrage", NS.window ~= nil and #NS.window.points > 0)

-- 4.47 Seuil à 0 = module inactif (pas de points gratuits)
Say("\n== seuils à zéro ==")
ResetWorld()
-- potions : seuil 0 par défaut -> inactif, poids nul
NS:RunChecklist("manual")
local potionsOff = Result("potions")
Check("potions inactif par défaut", potionsOff and potionsOff.disabled == true, potionsOff and potionsOff.detail)
Check("poids nul pour seuil 0", potionsOff and potionsOff.weight == 0, potionsOff and potionsOff.weight)
Check("mention « inactif »", potionsOff and potionsOff.detail == "inactif (seuil à 0)",
	potionsOff and potionsOff.detail)
local scoreZero = NS.score

-- même score que si le module était désactivé manuellement
NS:DB().potionsThreshold = 5
NS:RunChecklist("manual")
local withPotions = NS.score
Check("activer le seuil change la note", withPotions ~= scoreZero, scoreZero .. " -> " .. tostring(withPotions))

-- seuil gris à 0 : plus d'alerte « 0 objet gris »
ResetWorld()
NS:DB().grayItemThreshold = 0
NS:RunChecklist("manual")
local grayOff = Result("gray")
Check("gris seuil 0 -> inactif", grayOff and grayOff.disabled == true, grayOff and grayOff.detail)
Check("gris seuil 0 ne déclenche pas d'alerte", grayOff and grayOff.ok == true)

-- un module inactif ne produit pas de conseil
local grayAdvice = false
for _, entry in ipairs(NS.lastAdvice or {}) do
	if entry.text == "Passe vendre ton butin gris." then grayAdvice = true end
end
Check("module inactif sans conseil", grayAdvice == false)

-- score inchangé si on désactive un module déjà inactif
ResetWorld()
NS:DB().potionsThreshold = 0
NS:RunChecklist("manual")
local scoreInactive = NS.score
NS:SetModuleEnabled("potions", false)
NS:RunChecklist("manual")
Check("désactiver un module déjà inactif ne change rien", NS.score == scoreInactive,
	scoreInactive .. " -> " .. tostring(NS.score))
NS:SetModuleEnabled("potions", true)

-- 4.48 Bouton de minicarte (référence LibDBIcon)
Say("\n== bouton de minicarte ==")
ResetWorld()
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
local lancer = NS.minimapButton
Check("bouton créé", lancer ~= nil)
Check("bouton 31x31", lancer.width == 31 and lancer.height == 31, lancer.width .. "x" .. lancer.height)
Check("niveau de cadre 8", lancer.level == 8, lancer.level)
Check("surbrillance native", lancer.highlightTexture == 136477, lancer.highlightTexture)

-- Forever (interface 16001) : chrome mainline
Check("chrome mainline sur Forever", lancer.artStyle == "mainline", lancer.artStyle)
Check("liseré = fileID 136430", lancer.bg.texture == 136430, lancer.bg.texture)
Check("liseré 50x50", lancer.bg.width == 50, lancer.bg.width)
Check("pastille = fileID 136467", lancer.plate.texture == 136467, lancer.plate.texture)
Check("pastille 24x24", lancer.plate.width == 24, lancer.plate.width)
Check("icône 18x18", lancer.icon.width == 18 and lancer.icon.height == 18, lancer.icon.width)
Check("icône = boussole de la marque", tostring(lancer.icon.texture):find("Textures\\logo") ~= nil, lancer.icon.texture)

-- Classic : chrome historique
ResetWorld()
Mock.world.build = { version = "5.5.4", build = "69934", date = "Oct 2026", toc = 50504 }
NS.minimapButton = nil
local classic = NS:EnsureMinimapButton()
Check("chrome Classic détecté", classic.artStyle == "classic", classic.artStyle)
Check("liseré 53x53", classic.bg.width == 53, classic.bg.width)
Check("pastille 20x20", classic.plate.width == 20, classic.plate.width)
Check("icône 17x17 en Classic", classic.icon.width == 17, classic.icon.width)
Check("bouton toujours 31x31", classic.width == 31)

-- position : rayon = largeur/2 + 5 -> 75 px pour une minicarte de 140
ResetWorld()
NS.minimapButton = nil
local placed = NS:EnsureMinimapButton()
local point = placed.points[1]
Check("position calculée", point ~= nil)
Check("rayon = 75 px (140/2 + 5)", point and math.abs(math.sqrt((point.x or 0) ^ 2 + (point.y or 0) ^ 2) - 75) < 1,
	point and math.sqrt((point.x or 0) ^ 2 + (point.y or 0) ^ 2))

-- minicarte carrée : la formule diagonale s'applique sans erreur
Mock.world.minimapShape = "SQUARE"
NS:PositionMinimapButton()
Check("forme carrée gérée", placed.points[1] ~= nil)
Mock.world.minimapShape = "ROUND"

ResetWorld()

-- 4.49 Relevé de statistiques et formules
Say("\n== statistiques ==")
ResetWorld()
local snap = NS:StatSnapshot()
Check("Force lue", snap.str == 25, snap.str)
Check("Agilité lue", snap.agi == 14, snap.agi)
Check("Endurance lue", snap.sta == 30, snap.sta)
Check("armure lue", snap.armor == 506, snap.armor)
Check("dégâts min/max", snap.dmgMin == 20 and snap.dmgMax == 24, snap.dmgMin .. "-" .. snap.dmgMax)
Check("vitesse d'attaque", math.abs(snap.speed - 1.96) < 0.001, snap.speed)

-- formule de réduction : 506 / (506 + 85*11 + 400) = 27,5 %
Check("réduction d'armure = 27,5 %", math.abs(snap.reduction - 27.48) < 0.1, snap.reduction)
-- DPS = ((20+24)/2) / 1.96 = 11,2
Check("DPS = 11,2", math.abs(snap.dps - 11.22) < 0.05, snap.dps)
Check("niveau d'objet", snap.ilvl == 18, snap.ilvl)

-- 4.49a Changer d'item sans changer aucune statistique : pas de cadre vide
Say("\n== changement de stuff sans ecart de stats ==")
ResetWorld()
NS.toastFrame = nil
NS:CaptureStatBaseline()
-- on remplace un objet par un autre de mêmes caractéristiques : l'emplacement
-- change, donc le code détecte le changement, mais aucune stat ne bouge
Mock.world.equipped[10] = "item:850"
Mock.world.links["item:850"] = { name = "Gantelets identiques", quality = 2,
	itemLevel = 20, equipLoc = "INVTYPE_HAND", texture = "Interface\\Icons\\INV_Gants2" }
NS:OnEquipmentChanged()

Check("aucun cadre affiché sans écart", NS.toastFrame == nil
	or NS.toastFrame:IsShown() == false,
	NS.toastFrame and "affiché" or "absent")

-- 4.49b Retirer un item doit quand même montrer son icône
Say("\n== icone au retrait d'un item ==")
ResetWorld()
Mock.world.equipped[10] = "item:800"
Mock.world.links["item:800"] = { name = "Gantelets", quality = 2, itemLevel = 20,
	equipLoc = "INVTYPE_HAND", texture = "Interface\\Icons\\INV_Gants" }
NS.toastFrame = nil
-- le relevé doit être pris APRES avoir équipé, sinon la comparaison est vide
NS:CaptureStatBaseline()
Check("relevé contient l'item équipé",
	NS.statBefore and (NS.statBefore.slots or {})[10] == "item:800",
	NS.statBefore and (NS.statBefore.slots or {})[10])

-- on retire l'item de l'emplacement 10 : l'armure baisse
Mock.world.equipped[10] = nil
Mock.world.armor = 500
NS:OnEquipmentChanged()

Check("résumé affiché après retrait", NS.toastFrame ~= nil and NS.toastFrame:IsShown() == true)
-- l'emplacement est vide : seule l'icône du lien précédent peut le renseigner
Check("icône présente après retrait", NS.toastFrame.rows[1].icon.texture ~= nil,
	NS.toastFrame.rows[1].icon.texture)
Check("icône affichée après retrait", NS.toastFrame.rows[1].icon:IsShown() == true)

-- 4.50 Résumé éphémère au changement de stuff
Say("\n== résumé de changement de stuff ==")
ResetWorld()
NS:CaptureStatBaseline()
Check("relevé de référence posé", NS.statBefore ~= nil)

-- le joueur équipe de meilleures mains : +40 armure, +2 dégâts, +0,04 s de vitesse
Mock.world.armor = 546
Mock.world.damage = { 22, 26 }
Mock.world.attackSpeed = 2.00
Mock.world.equipped[10] = "item:900"
Mock.world.links["item:900"] = { name = "Gantelets neufs", quality = 3, itemLevel = 24,
	equipLoc = "INVTYPE_HAND" }
NS:OnEquipmentChanged()

Check("toast affiché", NS.toastFrame ~= nil and NS.toastFrame:IsShown() == true)

-- structure de la référence : titre espacé, règle, lignes valeur + libellé
Check("aucun fond", NS.toastFrame.bg == nil)
Check("aucune bordure hors édition", NS.toastFrame.moveGlow ~= nil
	and NS.toastFrame.moveGlow:IsShown() == false)

-- la vitesse qui diminue est une amélioration (polarité inversée)
local beforeSnap = NS:StatSnapshot()
Mock.world.attackSpeed = 1.60
local afterSnap = NS:StatSnapshot()
local rows = NS:DiffSnapshots(beforeSnap, afterSnap)
local speedRow
for _, row in ipairs(rows) do if row.key == "speed" then speedRow = row end end
Check("vitesse détectée", speedRow ~= nil)
Check("variation de vitesse négative", speedRow and speedRow.delta < 0, speedRow and speedRow.delta)
Check("vitesse : polarité inversée", speedRow and speedRow.polarity == false)
Mock.world.attackSpeed = 1.96

-- 4.51 Fondu et disparition
Say("\n== disparition du résumé ==")
NS.toastHideAt = 1000
NS:UpdateToast(1000.5)
Check("encore visible avant le fondu", NS.toastFrame:IsShown() == true)
NS:UpdateToast(1001.0)
Check("fondu en cours", NS.toastFrame:IsShown() == true)
Check("alpha réduit pendant le fondu", (NS.toastFrame.alpha or 1) < 1, NS.toastFrame.alpha)
NS:UpdateToast(1002.5)
Check("résumé masqué après le délai", NS.toastFrame:IsShown() == false)

-- 4.52 Panneau de stats au survol du portrait
Say("\n== stats du portrait ==")
ResetWorld()
NS:ShowPortraitStats()
Check("panneau de stats affiché", NS.portraitFrame ~= nil and NS.portraitFrame:IsShown() == true)
Check("classe et spé affichées", NS.portraitFrame.classLine.text:find("Guerrier") ~= nil,
	NS.portraitFrame.classLine.text)
Check("spécialisation affichée", NS.portraitFrame.classLine.text:find("Armes") ~= nil,
	NS.portraitFrame.classLine.text)
Check("niveau d'objet affiché", NS.portraitFrame.ilvlLine.text:find("18") ~= nil,
	NS.portraitFrame.ilvlLine.text)

local joined = {}
for _, line in ipairs(NS.portraitFrame.lines) do
	joined[#joined + 1] = tostring(line.left.text) .. " " .. tostring(line.right.text)
end
local blob = table.concat(joined, " | ")
Check("Force listée", blob:find("Force") ~= nil, blob)
Check("Agilité listée pour un Guerrier Armes", blob:find("Agilité") ~= nil, blob)
-- Guerrier Armes : la priorité officielle s'arrête à Force et Agilité,
-- l'Endurance n'y figure pas.
Check("Endurance absente pour un Guerrier Armes", blob:find("Endurance") == nil, blob)
Check("Armure listée", blob:find("Armure") ~= nil)
-- Guerrier : ni Intelligence ni Esprit. Ce sont des statistiques sans effet
-- sur ses dégâts, elles n'ont pas à occuper une ligne du panneau.
Check("Intelligence absente pour un Guerrier", blob:find("Intelligence") == nil, blob)
Check("Esprit absent pour un Guerrier", blob:find("Esprit") == nil, blob)
Check("DPS listé", blob:find("DPS") ~= nil)
-- Guerrier/Armes : c'est la Force qui est mise en avant, même si l'Endurance
-- affiche une valeur plus élevée. La mise en avant suit la classe et la spé,
-- pas le maximum (l'ancienne règle soulignait l'Endurance).
Check("Force mise en avant pour Guerrier/Armes",
	blob:find("|cffe8a54bForce") ~= nil, blob)
Check("Endurance non mise en avant malgré sa valeur supérieure",
	blob:find("|cffe8a54bEndurance") == nil, blob)

NS:HidePortraitStats()

-- Intégrité de la table SPEC_STATS : les neuf classes, trois spécialisations
-- chacune, et uniquement des clés de statistiques connues. Une faute de
-- frappe dans une clé afficherait « nil » dans le panneau, en jeu.
local validKeys = { STR = true, AGI = true, INT = true, SPI = true, STA = true }
local classCount, specCount, badKeys = 0, 0, {}
for classFile, bySpec in pairs(NS.SPEC_STATS) do
	classCount = classCount + 1
	Check("classe " .. classFile .. " : trois spécialisations", #bySpec == 3, #bySpec)
	for specIndex = 1, 3 do
		specCount = specCount + 1
		local list = bySpec[specIndex]
		if type(list) ~= "table" or #list == 0 then
			badKeys[#badKeys + 1] = classFile .. "/" .. specIndex .. " vide"
		else
			for _, key in ipairs(list) do
				if not validKeys[key] then
					badKeys[#badKeys + 1] = classFile .. "/" .. specIndex .. ":" .. tostring(key)
				end
			end
			-- au moins une statistique utile, et aucune répétition : un
			-- doublon afficherait deux fois la même ligne
			local seen = {}
			for _, key in ipairs(list) do
				if seen[key] then
					badKeys[#badKeys + 1] = classFile .. "/" .. specIndex .. " doublon " .. key
				end
				seen[key] = true
			end
			-- les listes suivent la priorité officielle : jamais plus de
			-- cinq attributs, et au moins un
			if #list > 5 then
				badKeys[#badKeys + 1] = classFile .. "/" .. specIndex .. " trop long"
			end
		end
	end
end
Check("neuf classes déclarées", classCount == 9, classCount)
Check("vingt-sept spécialisations", specCount == 27, specCount)
Check("aucune clé inconnue, doublon ni liste trop longue", #badKeys == 0,
	table.concat(badKeys, ", "))

-- La mise en avant suit la CLASSE et la SPÉCIALISATION, pas le maximum.
-- Voleur : l'Agilité ; Prêtre/Discipline : l'Intelligence ; Druide
-- Équilibre : l'Intelligence + l'Esprit (les deux soulignés).
local function highlightFor(classFile, specIndex)
	local saved = _G.UnitClass
	_G.UnitClass = function() return classFile, classFile, 1 end
	Mock.world.specIndex = specIndex
	NS.portraitFrame = nil
	NS:ShowPortraitStats()
	local blob = {}
	for _, line in ipairs(NS.portraitFrame.lines) do
		blob[#blob + 1] = tostring(line.left.text) .. " " .. tostring(line.right.text)
	end
	local text = table.concat(blob, " | ")
	NS:HidePortraitStats()
	_G.UnitClass = saved
	return text
end

local rogue = highlightFor("ROGUE", 1)
Check("Voleur : Agilité mise en avant", rogue:find("|cffe8a54bAgilité") ~= nil, rogue)
local priest = highlightFor("PRIEST", 1)
Check("Prêtre : Intelligence mise en avant",
	priest:find("|cffe8a54bIntelligence") ~= nil, priest)
local druid = highlightFor("DRUID", 3)
Check("Druide Restauration : Endurance non mise en avant",
	druid:find("|cffe8a54bEndurance") == nil, druid)
-- le panneau ne liste que le strict nécessaire : un Voleur n'a pas d'Esprit,
-- un Druide Restauration n'a pas de Force à lire en premier
Check("Voleur : pas d'Esprit", rogue:find("Esprit") == nil, rogue)
Check("Druide Restauration : Esprit présent", druid:find("Esprit") ~= nil, druid)
Check("Druide Restauration : Force absente", druid:find("Force") == nil, druid)
-- et l'Intelligence, elle, doit bien apparaître chez un Prêtre
Check("Prêtre : Intelligence listée", priest:find("Intelligence") ~= nil, priest)

-- Les listes suivent la priorité officielle de Wowhead Forever. Ces cas
-- verrouillent les points où l'on pouvait se tromper de sens.
local function firstStat(classFile, specIndex)
	local saved = _G.UnitClass
	_G.UnitClass = function() return classFile, classFile, 1 end
	Mock.world.specIndex = specIndex
	NS.portraitFrame = nil
	NS:ShowPortraitStats()
	local text = tostring(NS.portraitFrame.lines[1].left.text)
	NS:HidePortraitStats()
	_G.UnitClass = saved
	return text
end

-- ordre des spés (et des onglets de talents) : Sacré 1, Protection 2, Vindicte 3
Check("Vindicte (spé 3) : l'Intelligence passe avant la Force",
	firstStat("PALADIN", 3):find("Intelligence") ~= nil, firstStat("PALADIN", 3))
Check("Protection paladin (spé 2) : l'Endurance d'abord",
	firstStat("PALADIN", 2):find("Endurance") ~= nil, firstStat("PALADIN", 2))
Check("Démoniste : ni Force ni Agilité",
	firstStat("WARLOCK", 1):find("Intelligence") ~= nil, firstStat("WARLOCK", 1))

-- Druide Farouche : ours et félin n'ont pas les mêmes priorités. L'ours
-- commence par l'Endurance, le félin par l'Agilité.
local savedForm = _G.GetShapeshiftForm
_G.GetShapeshiftForm = function() return 0 end
Check("Farouche félin : Agilité d'abord",
	firstStat("DRUID", 2):find("Agilité") ~= nil, firstStat("DRUID", 2))
_G.GetShapeshiftForm = function() return 1 end
Check("Farouche ours : Endurance d'abord",
	firstStat("DRUID", 2):find("Endurance") ~= nil, firstStat("DRUID", 2))
_G.GetShapeshiftForm = savedForm
Mock.world.specIndex = 1
Mock.world.specIndex = 1

NS:HidePortraitStats()
Check("panneau masqué à la sortie", NS.portraitFrame:IsShown() == false)

-- 4.53 Désactivation
Say("\n== désactivation des nouveaux panneaux ==")
ResetWorld()
NS:DB().showPortraitStats = false
NS:ShowPortraitStats()
Check("stats portrait désactivées", NS.portraitFrame == nil or NS.portraitFrame:IsShown() == false)

ResetWorld()
NS:DB().showGearToast = false
NS:CaptureStatBaseline()
Mock.world.armor = 900
Mock.world.equipped[10] = "item:901"
Mock.world.links["item:901"] = { name = "Gantelets", quality = 2, itemLevel = 25, equipLoc = "INVTYPE_HAND" }
NS:OnEquipmentChanged()
Check("toast désactivé", NS.toastFrame == nil or NS.toastFrame:IsShown() == false)

-- 4.54 Commande /sd stats
Say("\n== commandes stats ==")
ResetWorld()
Mock:Reset()
NS:HandleCommand("stats")
Check("/sd stats affiche le panneau", NS.portraitFrame ~= nil and NS.portraitFrame:IsShown() == true)
Mock:Reset()
NS:HandleCommand("toast off")
Check("/sd toast off", NS:DB().showGearToast == false)
Check("message toast", Mock:Output():find("désactivé") ~= nil, Mock:Output())
NS:HandleCommand("portrait off")
Check("/sd portrait off", NS:DB().showPortraitStats == false)

-- 4.55 Verrouillage par défaut et mode édition
Say("\n== mode édition des cadres ==")
ResetWorld()
NS:ShowPortraitStats()
Check("portrait verrouillé par défaut", NS.portraitFrame.mouseEnabled == false)
Check("pas de mode édition au départ", NS.editMode == nil)
NS:HidePortraitStats()
Check("le portrait se masque normalement", NS.portraitFrame:IsShown() == false)

NS:CaptureStatBaseline()
Mock.world.armor = 700
Mock.world.equipped[10] = "item:910"
Mock.world.links["item:910"] = { name = "Gantelets", quality = 2, itemLevel = 22, equipLoc = "INVTYPE_HAND" }
NS:OnEquipmentChanged()
Check("résumé affiché après changement", NS.toastFrame ~= nil and NS.toastFrame:IsShown() == true)
Check("résumé verrouillé par défaut", NS.toastFrame.mouseEnabled == false)

-- entrée en mode édition
Mock:Reset()
NS:ToggleEditMode()
Check("mode édition actif", NS.editMode == true)
Check("message d'édition", Mock:Output():find("Mode édition") ~= nil, Mock:Output())
Check("résumé déverrouillé", NS.toastFrame.mouseEnabled == true)
Check("portrait déverrouillé", NS.portraitFrame.mouseEnabled == true)
Check("les deux cadres visibles", NS.toastFrame:IsShown() == true and NS.portraitFrame:IsShown() == true)
Check("lueur sur le résumé", NS.toastFrame.moveGlow:IsShown() == true)
Check("lueur sur le portrait", NS.portraitFrame.moveGlow:IsShown() == true)

-- le survol ne fait plus disparaître le cadre en édition
NS:HidePortraitStats()
Check("le portrait reste affiché en édition", NS.portraitFrame:IsShown() == true)

-- le résumé ne se fige pas / ne s'efface pas pendant l'édition
NS.toastHideAt = 1000
NS:UpdateToast(3000)
Check("pas de fondu en édition", NS.toastFrame:IsShown() == true)

-- déplacement enregistré
local toastDrag = NS.toastFrame:GetScript("OnDragStop")
local portraitDrag = NS.portraitFrame:GetScript("OnDragStop")
if toastDrag then toastDrag(NS.toastFrame) end
if portraitDrag then portraitDrag(NS.portraitFrame) end
Check("position du résumé enregistrée", type(NS:DB().toastPoint.point) == "string",
	NS:DB().toastPoint.point)
Check("portrait passé en manuel", NS:DB().portraitManual == true)

-- sortie du mode édition
Mock:Reset()
NS:StopEditMode()
Check("mode édition terminé", NS.editMode == nil)
Check("résumé reverrouillé", NS.toastFrame.mouseEnabled == false)
Check("portrait reverrouillé", NS.portraitFrame.mouseEnabled == false)
Check("lueurs masquées", NS.toastFrame.moveGlow:IsShown() == false
	and NS.portraitFrame.moveGlow:IsShown() == false)
Check("résumé masqué à la sortie", NS.toastFrame:IsShown() == false)
Check("message de fin", Mock:Output():find("terminé") ~= nil, Mock:Output())

-- édition possible même si les stats du portrait sont désactivées
ResetWorld()
NS:DB().showPortraitStats = false
NS:StartEditMode()
Check("édition force l'affichage du portrait", NS.portraitFrame ~= nil
	and NS.portraitFrame:IsShown() == true)
NS:StopEditMode()
Check("portrait redevient soumis au réglage", NS.portraitFrame:IsShown() == false)

-- 4.56 Bouton « Déplacer les cadres »
Say("\n== bouton de déplacement ==")
ResetWorld()
NS:ToggleOptions()
local editButton = NS.optionsFrame.editButton
Check("bouton de déplacement présent", editButton ~= nil)
Check("libellé du bouton", tostring(editButton:GetText()):find("Déplacer") ~= nil,
	editButton and editButton:GetText())

editButton:Click()
Check("clic active le mode édition", NS.editMode == true)
Check("réglages refermés", NS.optionsFrame:IsShown() == false)
Check("bouton renommé pendant l'édition", tostring(editButton:GetText()):find("Terminer") ~= nil,
	editButton:GetText())

Mock:Reset()
NS:HandleCommand("move stop")
Check("/sd move stop termine", NS.editMode == nil)
Check("bouton redevenu normal", tostring(editButton:GetText()):find("Déplacer") ~= nil, editButton:GetText())

Mock:Reset()
NS:HandleCommand("move")
Check("/sd move active", NS.editMode == true)
NS:StopEditMode()

-- rouvrir les réglages arrête l'édition
NS:StartEditMode()
NS:ToggleOptions()
Check("rouvrir les réglages arrête l'édition", NS.editMode == nil)

-- Le bandeau d'édition : le vrai bug. En entrant en édition, le panneau de
-- réglages se ferme et le bouton « Terminer » disparaissait avec lui. Sans
-- bandeau, on restait bloqué en édition. On vérifie qu'il existe, qu'il est
-- visible, et qu'il porte bien le bouton qui en sort.
NS:StartEditMode()
Check("bandeau d'édition affiché", NS.editBanner ~= nil and NS.editBanner:IsShown() == true)
-- le bandeau doit survivre à toutes les actions possibles en édition :
-- réafficher les stats du portrait, changer d'équipement, masquer un cadre.
NS:ShowPortraitStats()
Check("le bandeau survit à un rafraîchissement du portrait",
	NS.editBanner ~= nil and NS.editBanner:IsShown() == true)
NS:OnEquipmentChanged()
Check("le bandeau survit à un changement de stuff",
	NS.editBanner ~= nil and NS.editBanner:IsShown() == true)
Check("bandeau d'édition porte un bouton de sortie", NS.editBanner ~= nil and NS.editBanner.stopButton ~= nil)
NS:StopEditMode()
Check("bandeau masqué en sortie d'édition",
	NS.editBanner ~= nil and NS.editBanner:IsShown() == false)
Check("les cadres ne sont plus déplaçables en sortie",
	NS.toastFrame == nil or NS.toastFrame:IsShown() == false)

do -- portée locale (limite de 200 locales en Lua 5.1)
-- Géométrie du panneau par pages (v1.19.0) : colonne de droite d'une ligne,
-- pied en trois tiers, pages qui tiennent dans le cadre.
local lay = NS.OPT_LAYOUT
Check("colonne de valeurs exposée", lay ~= nil)
if lay then
	local rowRight = lay.rowWidth
	local valueEnd = rowRight + lay.valueRight
	local plusStart = rowRight + lay.plusRight - lay.buttonWidth
	local minusStart = rowRight + lay.minusRight - lay.buttonWidth
	Check("les boutons tiennent dans la ligne", -plusStart <= lay.rowWidth, plusStart)
	Check("la valeur ne touche pas le bouton -", valueEnd < minusStart, valueEnd .. " < " .. minusStart)
	Check("les boutons - et + ne se chevauchent pas", minusStart + lay.buttonWidth <= plusStart,
		(minusStart + lay.buttonWidth) .. " <= " .. plusStart)
	Check("la page tient à droite de la navigation", lay.paneLeft + lay.paneWidth <= lay.width - 8,
		lay.paneLeft + lay.paneWidth)
end

local foot = NS.OPT_LAYOUT and NS.OPT_LAYOUT.footer
Check("grille du pied exposée", foot ~= nil)
if foot then
	local total = foot.widths[1] + foot.widths[2] + foot.widths[3] + (foot.gap * 2)
	Check("les trois boutons remplissent la largeur utile", total == foot.inner, total .. " vs " .. foot.inner)
	Check("marge droite égale à la marge gauche", (lay.width - (foot.margin + total)) == foot.margin,
		(lay.width - (foot.margin + total)) .. " vs " .. foot.margin)
end
Check("bouton de réinitialisation des cadres présent",
	NS.optionsFrame ~= nil and NS.optionsFrame.resetFramesButton ~= nil)

local frame = NS:EnsureOptions()
Check("panneau de réglages construit", frame ~= nil)
if frame then
	Check("panneau d'options : hauteur fixe qui tient à l'écran", frame.height == lay.height
		and frame.height <= lay.maxHeight, frame.height)
	Check("11 entrées de navigation (3 modules, 5 sous-pages, Général, QoL, Marchand)", #frame.navButtons == 11, #frame.navButtons)

	-- chaque page tient dans le cadre, au-dessus du pied
	local overflow = {}
	for id, page in pairs(frame.pages) do
		if page.contentBottom < lay.contentLimit then overflow[#overflow + 1] = id .. "=" .. page.contentBottom end
	end
	Check("aucune page ne déborde sur le pied", #overflow == 0, table.concat(overflow, ", ") .. " limite " .. lay.contentLimit)

	-- tous les checks ont leur interrupteur, une seule fois
	local seen, missingModule, twice = {}, {}, 0
	for _, row in ipairs(frame.rows) do
		if row.isModule then
			if seen[row.moduleId] then twice = twice + 1 end
			seen[row.moduleId] = true
		end
	end
	for _, def in ipairs(NS.checks) do
		if not seen[def.id] then missingModule[#missingModule + 1] = def.id end
	end
	Check("chaque module a son interrupteur", #missingModule == 0, table.concat(missingModule, ", "))
	Check("aucun interrupteur en double", twice == 0, twice)
	Check("aucun module rangé par défaut dans Général", #frame.unplaced == 0, table.concat(frame.unplaced, ", "))

	-- colonne de valeurs commune, libellés qui tiennent
	local misaligned, tooLong = 0, {}
	for _, row in ipairs(frame.rows) do
		local point, _, _, x = row.value:GetPoint()
		if point == "RIGHT" and x ~= lay.valueRight then misaligned = misaligned + 1 end
		-- place du libellé : jusqu'à la piste (seuils), la valeur (actions) ou l'interrupteur
		local room
		if row.track then room = lay.rowWidth - 2 + lay.trackRight - lay.trackWidth - 6
		elseif row.toggle then room = lay.rowWidth - 2 + lay.toggleRight - 30 - 6
		else room = lay.rowWidth - 2 + lay.valueRight - lay.valueWidth end
		if #(row.label.text or "") * 6.4 > room then tooLong[#tooLong + 1] = tostring(row.label.text) end
	end
	Check("les modules partagent la colonne de valeurs", misaligned == 0, misaligned)
	Check("libellés d'options : aucun débordement", #tooLong == 0, table.concat(tooLong, ", "))
	-- valeur maximale + unité : tient dans la colonne de valeur (sinon elle
	-- mord la piste, vu sur un rendu avec « 25 pourcent »)
	local valueOverflow = {}
	for _, row in ipairs(frame.rows) do
		local def = row.def
		if def and def.kind == "number" then
			local text = tostring(def.max or 0) .. (def.suffix and (" " .. (NS.L[def.suffix] or "")) or "")
			if #text * 6.2 > lay.valueWidth then valueOverflow[#valueOverflow + 1] = def.key .. "=" .. text end
		end
	end
	Check("valeurs + unités : tiennent dans leur colonne", #valueOverflow == 0, table.concat(valueOverflow, ", "))
	local navTooLong = {}
	for _, nav in ipairs(frame.navButtons) do
		-- libellé à 26 px, interrupteur de 22 px à 8 px du bord droit
		local room = (nav.width or lay.navWidth) - 26 - (nav.power and (22 + 8 + 4) or 4)
		-- 5.3 px par caractère : mesuré sur une capture en jeu (« Vivres & potions » = 84 px)
		-- en caractères, pas en octets (« é » = 2 octets, 1 glyphe)
		local chars = select(2, tostring(nav.label.text or ""):gsub("[^\128-\191]", ""))
		if chars * 5.3 > room then navTooLong[#navTooLong + 1] = nav.label.text end
	end
	Check("libellés de navigation : aucun débordement", #navTooLong == 0, table.concat(navTooLong, ", "))

	-- aucune ligne superposée dans une même page
	local overlap = 0
	for _, page in pairs(frame.pages) do
		local spots = {}
		for _, row in ipairs(page.rows) do
			local _, _, _, x, y = row:GetPoint()
			local key = tostring(x) .. ":" .. tostring(y)
			if spots[key] then overlap = overlap + 1 end
			spots[key] = true
		end
	end
	Check("options : aucune ligne superposée", overlap == 0, overlap)
end

-- Navigation : une seule page visible, choix mémorisé
NS:SelectOptionsPage("bags")
local visiblePages = 0
for _, page in pairs(frame.pages) do if page:IsShown() then visiblePages = visiblePages + 1 end end
Check("navigation : une seule page visible", visiblePages == 1 and frame.pages.bags:IsShown())
Check("navigation : page mémorisée", NS:DB().optionsPage == "bags")
local function NavFor(id)
	for _, nav in ipairs(frame.navButtons) do if nav.pageId == id then return nav end end
end
NavFor("safe"):Click()
Check("navigation : clic sur « Zones sûres »", frame.currentPage == "safe" and frame.pages.safe:IsShown())
NavFor("departure"):Click()
Check("navigation : le module ouvre sa première sous-page", frame.currentPage == "trigger" and frame.currentParent == "departure")
Check("navigation : page inconnue -> Général", (function() NS:SelectOptionsPage("nope"); return frame.currentPage == "general" end)())
Check("page Sacs : interrupteur + seuil réunis", (function()
	local hasModule, hasThreshold = false, false
	for _, row in ipairs(frame.pages.bags.rows) do
		if row.isModule and row.moduleId == "bags" then hasModule = true end
		if row.def and row.def.key == "bagFreeThreshold" then hasThreshold = true end
	end
	return hasModule and hasThreshold
end)())

-- Liste des zones sûres : retrait à la souris, défilement
ResetWorld()
for i = 1, 12 do
	NS:DB().safe["v:30:Village " .. string.format("%02d", i)] = { kind = "village", name = "Village " .. string.format("%02d", i),
		mapID = 30, subzone = "Village " .. i, source = "mail" }
end
NS:DB().safe["c:1"] = { kind = "city", name = "Capitale", mapID = 1, source = "resting" }
NS:DB().cityRest[1] = { A = true, B = true }
NS.optionsFrame = nil
NS:ToggleOptions()
NS:SelectOptionsPage("safe")
local safeList = NS.optionsFrame.lists.safe
Check("liste des zones : 13 entrées", #safeList.items == 13, #safeList.items)
Check("liste des zones : 9 lignes visibles", safeList.lines[9]:IsShown() and safeList.lines[9].item ~= nil)
Check("liste des zones : défilement possible", safeList.down:IsShown() and not safeList.up:IsShown())
Check("liste des zones : source lisible", tostring(safeList.lines[1].detail.text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):find("capitale, repos") ~= nil,
	safeList.lines[1].detail.text)
safeList.down:Click()
Check("défilement : une ligne plus bas", safeList.offset == 1 and safeList.up:IsShown())
for _ = 1, 10 do safeList.down:Click() end
Check("défilement borné en bas", safeList.offset == 4, safeList.offset)
safeList.offset = 0
NS:RefreshOptions()
safeList.lines[1].action:Click()          -- « Capitale » : première par ordre alphabétique
Check("bouton Retirer : capitale oubliée", NS:DB().safe["c:1"] == nil and NS:DB().cityRest[1] == nil)
Check("liste rafraîchie après retrait", #safeList.items == 12, #safeList.items)
NS.optionsFrame.pages.safe.clearButton:Click()
Check("Tout effacer : liste vide", next(NS:DB().safe) == nil and #safeList.items == 0)
Check("liste vide : message affiché", safeList.empty.text ~= "", safeList.empty.text)

-- Liste des buffs suivis : bascule et retrait
ResetWorld()
NS:DB().buffs[1459] = { name = "Intelligence des arcanes", duration = 1800, enabled = true }
NS:DB().buffs[1126] = { name = "Marque du fauve", duration = 1800, enabled = true }
NS.optionsFrame = nil
NS:ToggleOptions()
NS:SelectOptionsPage("buffs")
local buffList = NS.optionsFrame.lists.buffs
Check("liste des buffs : 2 entrées", #buffList.items == 2, #buffList.items)
buffList.lines[1]:Click()
Check("clic sur un buff : coupé", NS:DB().buffs[1459].enabled == false)
Check("buff coupé affiché « non »", tostring(buffList.lines[1].detail.text):find(NS.L.OPT_OFF) ~= nil,
	buffList.lines[1].detail.text)
buffList.lines[1]:Click()
Check("second clic : réactivé", NS:DB().buffs[1459].enabled == true)
buffList.lines[2].action:Click()
Check("bouton Retirer : buff oublié", NS:DB().buffs[1126] == nil and #buffList.items == 1)

end

-- Aucun caractère hors du répertoire de la police du client : "▶" (U+25B6)
-- s'affichait en losange de remplacement.
local function HasHighGlyph(file)
	local f = io.open(ROOT .. "/" .. file, "rb")
	if not f then return false end
	local data = f:read("*a")
	f:close()
	-- E2 96 B6 = U+25B6 (triangle), E2 96 B8 = U+25B8 : hors de la police
	for _, seq in ipairs({ string.char(0xE2,0x96,0xB6), string.char(0xE2,0x96,0xB8) }) do
		if data:find(seq, 1, true) then return true end
	end
	return false
end
Check("pas de glyphe triangle dans Options.lua", not HasHighGlyph("Ready2Quest/Options.lua"))
Check("pas de glyphe triangle dans Locales.lua", not HasHighGlyph("Ready2Quest/Locales.lua"))

-- la ligne « position du bouton » affiche l'angle courant
local posRow
for _, row in ipairs(NS.optionsFrame.rows) do
	if row.def and row.def.key == "minimapPos" then posRow = row end
end
Check("ligne de position présente", posRow ~= nil)
Check("angle affiché dans la ligne", tostring(posRow.value.text):find("225") ~= nil, posRow.value.text)

-- 4.57 Repli des chaînes sans récursion (C stack overflow corrigé en 1.1.1)
Say("\n== repli des chaînes ==")
ResetWorld()
Check("clé existante résolue", NS.L.ADDON_NAME ~= nil and NS.L.ADDON_NAME ~= "ADDON_NAME",
	tostring(NS.L.ADDON_NAME))
-- si __index se rappelait lui-même, ce test ferait exploser la pile
local missing = NS.L["CLE_QUI_NEXISTE_PAS"]
Check("clé absente renvoie son nom", missing == "CLE_QUI_NEXISTE_PAS", tostring(missing))
Check("aucune récursion sur 50 clés absentes", (function()
	local ok = pcall(function()
		for i = 1, 50 do
			local _ = NS.L["ABSENTE_" .. i]
		end
	end)
	return ok
end)() == true)
Check("ns:F formate une clé existante", NS:F("MINIMAP_SCORE", 80, "PRÊT"):find("80") ~= nil,
	NS:F("MINIMAP_SCORE", 80, "PRÊT"))
Check("ns:F tolère une clé absente", NS:F("CLE_ABSENTE") == "CLE_ABSENTE", NS:F("CLE_ABSENTE"))

-- 4.58 Piège tonumber() avec des API à plusieurs retours
Say("\n== tonumber et retours multiples ==")
ResetWorld()
local savedAP = _G.UnitAttackPower
_G.UnitAttackPower = function() return 120, 0, 0, nil end
local okAP, snapAP = pcall(function() return NS:StatSnapshot() end)
Check("pas de plantage quand le 4e retour est nil", okAP, tostring(snapAP))
Check("puissance d'attaque lue sur le 1er retour", okAP and snapAP.ap == 120, okAP and snapAP.ap)

local savedSpeed = _G.UnitAttackSpeed
_G.UnitAttackSpeed = function() return 1.96, 1.50 end
local okSpeed, snapSpeed = pcall(function() return NS:StatSnapshot() end)
Check("pas de plantage avec 2 retours de vitesse", okSpeed, tostring(snapSpeed))
Check("vitesse lue sur le 1er retour", okSpeed and math.abs(snapSpeed.speed - 1.96) < 0.001,
	okSpeed and snapSpeed.speed)

local savedCrit = _G.GetCritChance
_G.GetCritChance = function() return 12.5, 99 end
local okCrit, snapCrit = pcall(function() return NS:StatSnapshot() end)
Check("crit lue sans confusion de base", okCrit and snapCrit.crit == 12.5, okCrit and snapCrit.crit)

_G.UnitAttackPower = savedAP
_G.UnitAttackSpeed = savedSpeed
_G.GetCritChance = savedCrit

-- 4.59 Rotation du bouton de minicarte
Say("\n== position du bouton de minicarte ==")
ResetWorld()
NS.minimapButton = nil
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Check("angle par défaut 225 degres", math.abs((NS:DB().minimapAngle or 0) - 225) < 1, NS:DB().minimapAngle)
Mock:Reset()
NS:CycleMinimapAngle()
Check("angle suivant 270 degres", math.abs(NS:DB().minimapAngle - 270) < 1, NS:DB().minimapAngle)
Check("message d'angle", Mock:Output():find("270") ~= nil, Mock:Output())
NS:CycleMinimapAngle()
Check("angle suivant 315 degres", math.abs(NS:DB().minimapAngle - 315) < 1, NS:DB().minimapAngle)
NS:DB().minimapAngle = 180
NS:CycleMinimapAngle()
Check("bouclage vers 225 degres", math.abs(NS:DB().minimapAngle - 225) < 1, NS:DB().minimapAngle)

-- 4.61 Résumé éphémère sans cadre
Say("\n== résumé sans cadre ==")
ResetWorld()
NS:CaptureStatBaseline()
Mock.world.armor = 600
Mock.world.equipped[10] = "item:920"
Mock.world.links["item:920"] = { name = "Gantelets", quality = 2, itemLevel = 20, equipLoc = "INVTYPE_HEAD" }
NS:OnEquipmentChanged()

local tframe = NS.toastFrame
Check("aucun fond", tframe.bg == nil)
Check("titre de section présent", tframe.title ~= nil)
Check("aucun bouton de fermeture", tframe.close == nil)
Check("aucun filet permanent", tframe.top == nil and tframe.bottom == nil
	and tframe.leftEdge == nil and tframe.rightEdge == nil)
-- une seule ligne, par choix de conception : le bloc doit se lire d'un coup
Check("un seul emplacement de ligne", #tframe.rows == 1, #tframe.rows)
Check("ligne lisible sur le décor (ombre)", tframe.title.shadow ~= nil, tframe.title.shadow)
Check("ombre décalée", tframe.title.shadowOffset ~= nil)

-- deux écarts, mais une seule ligne affichée : le premier est retenu
NS:CaptureStatBaseline()
Mock.world.armor = 650
Mock.world.attackSpeed = 2.4
Mock.world.equipped[10] = "item:921"
Mock.world.links["item:921"] = { name = "Gantelets runiques", quality = 3, itemLevel = 24,
	equipLoc = "INVTYPE_HEAD" }
NS:OnEquipmentChanged()
local frame = NS.toastFrame
local usedRows = 0
for index = 1, #frame.rows do
	if frame.rows[index].value.text ~= "" then usedRows = usedRows + 1 end
end
Check("une seule ligne utilisée, même pour deux écarts", usedRows == 1, usedRows)
Check("ligne 1 remplie", frame.rows[1].value.text ~= "", frame.rows[1].value.text)
-- il n'y a plus de deuxième ligne : c'est le contrat du bloc à une ligne
Check("pas de deuxième ligne", frame.rows[2] == nil, frame.rows[2] and "présente" or "absente")
Check("libellé en PascalCase",
	frame.rows[1].label.text == NS.PascalCase(frame.rows[1].label.text)
		and frame.rows[1].label.text:sub(2):find("%u") == nil,
	frame.rows[1].label.text)
Check("aucune ligne concaténée", frame.rows[1].value.text:find("·") == nil,
	frame.rows[1].value.text)

-- le panneau de stats du portrait garde son filet, lui
NS:StartEditMode()
Check("stats du portrait toujours encadrées", NS.portraitFrame.top ~= nil)
Check("lueur de déplacement sur le résumé", NS.toastFrame.moveGlow:IsShown() == true)
NS:StopEditMode()
Check("lueur masquée à la sortie", NS.toastFrame.moveGlow:IsShown() == false)

-- 4.64 Mise en page du résumé : titre espacé, règle, colonnes
Say("\n== mise en page du résumé ==")
ResetWorld()
NS:CaptureStatBaseline()
Mock.world.armor = 600
Mock.world.equipped[10] = "item:930"
Mock.world.links["item:930"] = { name = "Ceinture", quality = 2, itemLevel = 20,
	equipLoc = "INVTYPE_WAIST", texture = "Interface\\Icons\\INV_Belt_01" }
NS:OnEquipmentChanged()
local panel = NS.toastFrame
Check("titre présent", panel.title ~= nil)
Check("titre en majuscules", panel.title.text == string.upper(panel.title.text), panel.title.text)
Check("titre : même corps que les lignes", panel.title.fontObject == NS.Theme.F_BODY,
	panel.title.fontObject)
Check("titre : même corps que le libellé",
	panel.title.fontObject == panel.rows[1].label.fontObject)
Check("titre interlettré", panel.title.text:find(" ") ~= nil, panel.title.text)
Check("règle de séparation", panel.rule ~= nil)
Check("règle sur toute la largeur",
	#panel.rule.points == 2, panel.rule.points and #panel.rule.points)
Check("un seul emplacement de ligne", #panel.rows == 1, #panel.rows)
Check("ombre sur les valeurs", panel.rows[1].value.shadow ~= nil)
Check("ombre décalée", panel.rows[1].value.shadowOffset ~= nil)
Check("ombre sur les libellés", panel.rows[1].label.shadow ~= nil)
Check("valeur à gauche du libellé",
	panel.rows[1].value.lastPoint.x < panel.rows[1].label.lastPoint.x,
	tostring(panel.rows[1].value.lastPoint.x) .. " / " .. tostring(panel.rows[1].label.lastPoint.x))
-- l'icône vient du LIEN (GetItemInfo, 10e retour) et non de l'API
-- d'emplacement : c'est ce qui la rend disponible même après un retrait
Check("icône d'objet renseignée",
	panel.rows[1].icon.texture == "Interface\\Icons\\INV_Belt_01", panel.rows[1].icon.texture)
Check("icône affichée", panel.rows[1].icon:IsShown() == true)
-- la ligne pleine doit montrer son icône, et il n'y a pas de ligne vide
Check("icône visible sur la ligne", panel.rows[1].icon:IsShown() == true)

-- la règle reste au-dessus de la première ligne
local ruleY = panel.rule.lastPoint.y
local firstRowY = panel.rows[1].value.lastPoint.y
Check("règle au-dessus des lignes", ruleY > firstRowY,
	tostring(ruleY) .. " vs " .. tostring(firstRowY))

-- gain = vert avec chevron haut ; perte = rouge avec chevron bas
local gainRow = nil
local lossRow = nil
for _, row in ipairs(panel.rows) do
	if row.value.text ~= "" then
		if row.value.textColor[1] > row.value.textColor[2] then lossRow = row end
		if row.value.textColor[2] > row.value.textColor[1] then gainRow = row end
	end
end
Check("au moins une ligne colorée", gainRow ~= nil or lossRow ~= nil)
-- les flèches doivent être des lettres grecques : les triangles de
-- « Geometric Shapes » sortent en rectangle vide sur certaines polices
local arrowText = nil
for _, row in ipairs(panel.rows) do
	if row.value.text ~= "" then arrowText = row.value.text break end
end
Check("flèche affichée", arrowText ~= nil and #arrowText > 0, arrowText)
-- casse : titre en majuscules, libellés en PascalCase
Check("PascalCase : mot simple", NS.PascalCase("armure") == "Armure", NS.PascalCase("armure"))
Check("PascalCase : deux mots",
	NS.PascalCase("score crit") == "Score Crit", NS.PascalCase("score crit"))
Check("PascalCase : apostrophe = pas de mot",
	NS.PascalCase("vitesse d'attaque") == "Vitesse D'attaque",
	NS.PascalCase("vitesse d'attaque"))
Check("PascalCase : accents préservés",
	NS.PascalCase("dégâts") == "Dégâts", NS.PascalCase("dégâts"))
Check("PascalCase : déjà capitalisé",
	NS.PascalCase("Puissance d'attaque") == "Puissance D'attaque",
	NS.PascalCase("Puissance d'attaque"))
Check("PascalCase : chaîne vide", NS.PascalCase("") == "")
Check("libellé réel en PascalCase", panel.rows[1].label.text == "Armure", panel.rows[1].label.text)
-- Les flèches sont des textures : aucun caractère exotique ne doit subsister
-- dans la valeur affichée (pastille obligatoire depuis les 3 carrés vides).
local shown = nil
for _, row in ipairs(panel.rows) do
	if row.value.text ~= "" then shown = row.value.text break end
end
Check("valeur sans glyphe de flèche", shown ~= nil and shown:match("^[%+%-]?[%d%s,%.]+$") ~= nil, shown)
Check("valeur en ASCII pur",
	shown ~= nil and shown:byte(#shown) < 128, shown and shown:byte(#shown))
Check("flèche : texture créée", panel.rows[1].arrow ~= nil)
Check("flèche : texture de hausse",
	panel.rows[1].arrow.texture ~= nil
		and panel.rows[1].arrow.texture:find("fleche_hausse") ~= nil,
	panel.rows[1].arrow.texture)
Check("flèche : teintée comme la valeur",
	panel.rows[1].arrow.vertex ~= nil
		and panel.rows[1].arrow.vertex[2] > panel.rows[1].arrow.vertex[1],
	panel.rows[1].arrow.vertex and panel.rows[1].arrow.vertex[2])
-- mise en page resserrée : la colonne des libellés colle à la valeur
Check("colonne des libellés resserrée", NS.TOAST_LABEL_LEFT == 76, NS.TOAST_LABEL_LEFT)
-- la flèche commence apres la valeur la plus longue (44 px mesuree pour
-- « -0,60 s »), sinon elle chevaucherait le chiffre
Check("flèche après la valeur la plus longue",
	NS.TOAST_ARROW_LEFT >= NS.TOAST_VALUE_LEFT + 40, NS.TOAST_ARROW_LEFT)
Check("flèche ne touche pas le libellé",
	NS.TOAST_ARROW_LEFT + NS.ARROW_SIZE <= NS.TOAST_LABEL_LEFT,
	NS.TOAST_ARROW_LEFT + NS.ARROW_SIZE)
-- centrage : le contenu doit être centré dans la largeur du bloc, sinon le
-- vide s'accumule à droite (constaté 40 unités sur la capture en jeu)
local inset = ((NS.TOAST_WIDTH - NS.TOAST_CONTENT_WIDTH) / 2)
Check("contenu centré : marge gauche = marge droite",
	math.abs(inset - (NS.TOAST_WIDTH - NS.TOAST_CONTENT_WIDTH - inset)) < 0.01, inset)
Check("inset positif (contenu plus étroit que le bloc)", inset > 0, inset)
-- l'échelle (factor) s'applique à ces décalages : on compare les rapports
-- factor = largeur du mock / 1920 ; on reconstruit le décalage attendu
local scale = panel.rows[1].icon:GetWidth() / NS.TOAST_ICON
local function expected(value) return value * scale end
local function near(a, b) return math.abs(a - b) < 0.02 end
-- l'icône et la flèche sont ancrées en CENTER : leur abscisse donne le milieu
Check("icône décalée de l'inset",
	near(panel.rows[1].icon.lastPoint.x, expected(inset + NS.TOAST_ICON / 2)),
	panel.rows[1].icon.lastPoint.x)
Check("libellé décalé de l'inset",
	near(panel.rows[1].label.lastPoint.x, expected(inset + NS.TOAST_LABEL_LEFT)),
	panel.rows[1].label.lastPoint.x)
Check("flèche décalée de l'inset",
	near(panel.rows[1].arrow.lastPoint.x,
		expected(inset + NS.TOAST_ARROW_LEFT + NS.ARROW_SIZE / 2)),
	panel.rows[1].arrow.lastPoint.x)
Check("titre décalé de l'inset", near(panel.title.lastPoint.x, expected(inset)),
	panel.title.lastPoint.x)
Check("largeur du bloc resserrée", NS.TOAST_WIDTH <= 200, NS.TOAST_WIDTH)
-- Centrage vertical. L'icône et la flèche sont ancrées en CENTER : le point
-- enregistré EST donc leur milieu, il n'y a rien à ajouter. Le milieu de
-- référence est celui de la ligne, calculé depuis le haut de ligne et la
-- hauteur des chiffres (une fontstring pend sous son ancrage).
local testScale = panel.rows[1].icon:GetWidth() / NS.TOAST_ICON
local rowTop = NS.TOAST_ROW_TOP
local textMiddle = rowTop + NS.TOAST_LINE_MIDDLE
Check("milieu de ligne cohérent",
	math.abs(textMiddle - (rowTop - NS.TOAST_TEXT_HEIGHT / 2)) < 0.01, textMiddle)
local iconMiddle = panel.rows[1].icon.lastPoint.y / testScale
local arrowMiddle = panel.rows[1].arrow.lastPoint.y / testScale
Check("icône centrée verticalement sur la ligne",
	math.abs(iconMiddle - textMiddle) < 0.01, iconMiddle .. " vs " .. textMiddle)
Check("flèche centrée verticalement sur la ligne",
	math.abs(arrowMiddle - textMiddle) < 0.01, arrowMiddle .. " vs " .. textMiddle)
Check("icône et flèche au même milieu",
	math.abs(iconMiddle - arrowMiddle) < 0.01, iconMiddle .. " / " .. arrowMiddle)
Check("flèche visible quand la ligne l'est", panel.rows[1].arrow:IsShown() == true)
-- aucune ligne vide avec TOAST_ROWS = 1 : la flèche est toujours celle de la ligne

Check("libellé en parchemin (pas en couleur d'écart)",
	panel.rows[1].label.textColor[1] > 0.9 and panel.rows[1].label.textColor[3] < 0.85,
	panel.rows[1].label.textColor[1] .. "/" .. panel.rows[1].label.textColor[3])

-- cinq écarts et plus : quatre lignes au maximum
local many = {}
for index = 1, 8 do
	many[#many + 1] = { key = "armor", label = "ARMOR", kind = "integer", polarity = true,
		delta = index, old = 0, new = index }
end
local built = NS:ToastRows(many)
Check("tronqué à une ligne", #built == 1, #built)
Check("première ligne conservée", built[1] and built[1].value ~= nil)

-- ligne vide = aucun résidu d'écart précédent
NS:ToastRows({})
NS:ToastText(NS:ToastRows({}))
local residue = 0
for index = 1, #panel.rows do
	if panel.rows[index].value.text ~= "" then residue = residue + 1 end
end
Check("aucun résidu quand il n'y a rien à afficher", residue == 0, residue)
Check("icônes masquées sans écart", panel.rows[1].icon:IsShown() == false)

-- mode édition : structure d'attente, cadre non vide
NS:StartEditMode()
local placeholderShown = false
for index = 1, #panel.rows do
	if panel.rows[index].value.text ~= "" then placeholderShown = true end
end
Check("structure visible en édition", placeholderShown)
Check("titre visible en édition", panel.title.text:find("S T A T") ~= nil, panel.title.text)
NS:StopEditMode()

-- 4.62 Chrome des fenêtres : fond et bord d'infobulle (style AtlasLoot)
Say("\n== chrome des fenêtres ==")
ResetWorld()
NS:ToggleOptions()
local win = NS.optionsFrame
-- v1.20.0 : surface plate maison, plus de fond ni de bord d'infobulle
Check("surface plate appliquée", win.chrome == "flat", win.chrome)
Check("aucun backdrop Blizzard", win.backdrop == nil)
Check("fond presque opaque", win.bg and win.bg.vertex and win.bg.vertex[4] > 0.9, win.bg and win.bg.vertex and win.bg.vertex[4])
Check("filet 1 px sur les quatre côtés", win.border and win.border.top and win.border.left and win.border.bottom and win.border.right)
Check("coin d'accent ambre", win.accentH and win.accentH.vertex[1] > 0.9 and win.accentH.vertex[3] < 0.35,
	win.accentH and table.concat(win.accentH.vertex, ","))
Check("marque : logo boussole dans le bandeau", win.logo and tostring(win.logo.texture):find("logo") ~= nil,
	win.logo and win.logo.texture)
Check("titre en police maison", win.title and win.title.font and tostring(win.title.font.path):find("Alegreya") ~= nil,
	win.title and win.title.font and win.title.font.path)
Check("pas de portrait", win.portrait == nil)
Check("titre présent", win.title ~= nil and tostring(win.title.text):find("Réglages") ~= nil,
	win.title and win.title.text)
Check("bouton de fermeture Blizzard", win.close ~= nil)
Check("sous-titre présent", win.subtitle ~= nil)
Check("contenu sous le bandeau", win.contentTop == -36, win.contentTop)

-- le diagnostic aussi
NS:ToggleOptions()
NS:RunChecklist("manual")
Check("diagnostic : même surface plate", NS.window.chrome == "flat", NS.window.chrome)

-- aucun template Blizzard requis : sans BackdropTemplate ni UIPanelButtonTemplate,
-- le panneau est identique (c'est tout l'intérêt des contrôles dessinés)
ResetWorld()
Mock.world.noBackdropTemplate = true
Mock.world.noButtonTemplate = true
Mock.world.fontRefused = true
NS:ToggleOptions()
local fallback = NS.optionsFrame
Check("sans templates : même chrome", fallback.chrome == "flat", fallback.chrome)
Check("police refusée : repli GameFont sans erreur", fallback.title.titleFont == false)
Mock.world.noButtonTemplate = false
Mock.world.fontRefused = false
Check("repli toujours titré", fallback.title ~= nil and tostring(fallback.title.text) ~= "")
Check("repli toujours complet", fallback.rows ~= nil and #fallback.rows == 31,
	fallback.rows and #fallback.rows)
Mock.world.noBackdropTemplate = false

-- les cadres discrets gardent leur chrome propre
ResetWorld()
NS:StartEditMode()
Check("résumé sans backdrop", NS.toastFrame.backdrop == nil)
Check("stats portrait sans backdrop", NS.portraitFrame.backdrop == nil)
NS:StopEditMode()

-- 4.63 Fermeture par Échap (UISpecialFrames)
Say("\n== fermeture par Échap ==")
ResetWorld()
_G.UISpecialFrames = {}
NS:ToggleOptions()
local inEscape, countAfterOptions = false, #UISpecialFrames
for _, name in ipairs(UISpecialFrames) do
	if name == "Ready2QuestOptionsFrame" then inEscape = true end
end
Check("réglages déclarés pour Échap", inEscape, countAfterOptions)
NS:ToggleOptions()
NS:RunChecklist("manual")
local diagInEscape = false
for _, name in ipairs(UISpecialFrames) do
	if name == "Ready2QuestDiagFrame" then diagInEscape = true end
end
Check("diagnostic déclaré pour Échap", diagInEscape)
Check("aucun doublon dans UISpecialFrames", #UISpecialFrames == 2, #UISpecialFrames)

-- rouvrir ne réinscrit pas
NS:ToggleOptions()
NS:ToggleOptions()
Check("pas de doublon après réouverture", #UISpecialFrames == 2, #UISpecialFrames)

-- 4.64 Le déplacement effectif des cadres (OnDragStart)
Say("\n== déplacement effectif ==")
ResetWorld()
NS:StartEditMode()
for _, pair in ipairs({ { "résumé", NS.toastFrame }, { "stats portrait", NS.portraitFrame } }) do
	local label, frame = pair[1], pair[2]
	Check(label .. " : verrouillé -> souris active", frame.mouseEnabled == true)
	Check(label .. " : déplaçable", frame.movable == true)
	Check(label .. " : OnDragStart posé", type(frame:GetScript("OnDragStart")) == "function")
	Check(label .. " : OnDragStop posé", type(frame:GetScript("OnDragStop")) == "function")

	-- simuler le glissement : OnDragStart doit réellement démarrer le déplacement
	local dragStart = frame:GetScript("OnDragStart")
	if dragStart then dragStart(frame) end
	Check(label .. " : déplacement démarré", frame.isMoving == true)

	local dragStop = frame:GetScript("OnDragStop")
	if dragStop then dragStop(frame) end
	Check(label .. " : déplacement terminé", frame.isMoving == false)
end
NS:StopEditMode()

do -- portée locale : Lua 5.1 limite le bloc principal à 200 locales
-- 4.40 v1.18.0 en mode Classic Era : nouveaux checks et marchand
Say("\n== v1.18.0 : mode Era ==")
local EraSaved = {}
local function EnterEra()
	ResetWorld()
	EraSaved.delta, EraSaved.stats = C_Item.GetItemStatDelta, C_Item.GetItemStats
	EraSaved.trade, EraSaved.numQuest = _G.C_TradeSkillUI, C_QuestLog.GetNumQuestLogEntries
	C_Item.GetItemStatDelta, C_Item.GetItemStats = nil, nil
	_G.C_TradeSkillUI = nil
	C_QuestLog.GetNumQuestLogEntries = nil
	Mock.world.build = { version = "1.15.9", build = "69722", date = "Oct 2026", toc = 11509 }
	NS:DetectCapabilities()
end
local function LeaveEra()
	C_Item.GetItemStatDelta, C_Item.GetItemStats = EraSaved.delta, EraSaved.stats
	_G.C_TradeSkillUI, C_QuestLog.GetNumQuestLogEntries = EraSaved.trade, EraSaved.numQuest
	Mock.world.build = nil
	NS:DetectCapabilities()
end

-- Composants de classe
EnterEra()
Check("Era : client identifié", NS:ClientFlavour() == "Classic Era", NS:ClientFlavour())
Mock.world.classToken = "WARRIOR"
NS:RunChecklist("manual")
Check("guerrier : composants inactifs", Result("classreagents") and Result("classreagents").disabled == true
	and Result("classreagents").weight == 0)
Check("module inactif : libellé « sans objet »", Result("classreagents").detail == "sans objet",
	Result("classreagents").detail)

Mock.world.classToken = "WARLOCK"
Mock.world.level = 9
NS:RunChecklist("manual")
Check("démoniste niv. 9 : composants inactifs", Result("classreagents").disabled == true)
Mock.world.level = 20
Mock.world.bags[0].items[1] = { itemID = 6265, stackCount = 1, quality = 1 }
NS:RunChecklist("manual")
local cr = Result("classreagents")
Check("démoniste : 1 fragment sur 3 = échec", cr and cr.ok == false and cr.detail:find("1 / 3") ~= nil, cr and cr.detail)
Check("composants : poids fort (15)", cr and cr.weight == 15, cr and cr.weight)
Mock.world.bags[0].items[1] = { itemID = 6265, stackCount = 5, quality = 1 }
NS:RunChecklist("manual")
Check("démoniste : 5 fragments = OK", Result("classreagents").ok == true, Result("classreagents").detail)

Mock.world.classToken = "HUNTER"
Mock.world.ammo = 50
NS:RunChecklist("manual")
Check("chasseur : 50 munitions = échec", Result("classreagents").ok == false, Result("classreagents").detail)
Mock.world.ammo = 800
NS:RunChecklist("manual")
Check("chasseur : 800 munitions = OK", Result("classreagents").ok == true)

Mock.world.classToken = "DRUID"
Mock.world.level = 40
Mock.world.bags[0].items[1] = { itemID = 17036, stackCount = 1, quality = 1 }
NS:RunChecklist("manual")
Check("druide : une graine d'un autre rang compte", Result("classreagents").ok == true, Result("classreagents").detail)

-- Pierre de foyer
EnterEra()
NS:RunChecklist("manual")
local hs = Result("hearth")
Check("pas de pierre de foyer : échec", hs and hs.ok == false and hs.score == 0, hs and hs.detail)
Check("foyer : poids moyen (10)", hs and hs.weight == 10)
Mock.world.bags[0].items[1] = { itemID = 6948, stackCount = 1, quality = 1 }
Mock.world.bind = "Long-guet"
NS:RunChecklist("manual")
hs = Result("hearth")
Check("foyer prêt : OK + lieu lié", hs.ok == true and hs.detail:find("Long%-guet") ~= nil, hs.detail)
Mock.world.cooldowns = { [6948] = { Mock.now - 60, 3600 } }
NS:RunChecklist("manual")
hs = Result("hearth")
Check("foyer en recharge 59 min : échec", hs.ok == false and hs.detail:find("59 min") ~= nil, hs.detail)
Mock.world.cooldowns = { [6948] = { Mock.now - 3300, 3600 } }
NS:RunChecklist("manual")
Check("foyer en recharge 5 min : toléré", Result("hearth").ok == true, Result("hearth").detail)

-- Réparation : muet sans mesure, puis estimation depuis le coût mesuré
EnterEra()
Mock.world.durability = { [5] = { 50, 100 } }
Mock.world.money = 100
NS:RunChecklist("manual")
Check("réparation : muette sans mesure", Result("repair").disabled == true)
NS:DB().autoRepair = false
NS:DB().autoSellGray = false
Mock.world.canRepair = true
Mock.world.repairCost = 5000          -- 50 points manquants -> 100 pc par point
Mock:Fire("MERCHANT_SHOW")
Mock:Fire("MERCHANT_CLOSED")
Check("coût mesuré par point de durabilité", NS:CharData().repairRate == 100, NS:CharData().repairRate)
Mock.world.durability = { [5] = { 20, 100 } }   -- 80 points -> ~8000 pc
NS:RunChecklist("manual")
local rp = Result("repair")
Check("réparation estimée : or insuffisant", rp and rp.ok == false and rp.detail:find("80 pa") ~= nil, rp and rp.detail)
Check("réparation : poids moyen (10)", rp and rp.weight == 10)
Mock.world.money = 10000
NS:RunChecklist("manual")
Check("réparation estimée : or suffisant", Result("repair").ok == true, Result("repair").detail)

-- Sorts à apprendre
EnterEra()
Mock.world.level = 10
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Check("premier login : niveau d'entraîneur initialisé", NS:CharData().trainerLevel == 10)
NS:RunChecklist("manual")
Check("sorts : inactif tant qu'aucun niveau pair n'est passé", Result("spells").disabled == true)
Mock.world.level = 11
Check("niveau impair : rien à apprendre", NS:PendingSpellLevels() == 0)
Mock.world.level = 12
NS:RunChecklist("manual")
local sp = Result("spells")
Check("niveau 12 : sorts à apprendre", sp and sp.ok == false and sp.disabled ~= true, sp and sp.detail)
Check("sorts : poids faible (5)", sp and sp.weight == 5)
Mock.world.tradeskillTrainer = true
Mock:Fire("TRAINER_SHOW")
Check("entraîneur de métier : ne compte pas", NS:CharData().trainerLevel == 10)
Mock.world.tradeskillTrainer = false
Mock:Fire("TRAINER_SHOW")
Check("entraîneur de classe : niveau mémorisé", NS:CharData().trainerLevel == 12)
NS:RunChecklist("manual")
Check("après l'entraîneur : sorts inactifs", Result("spells").disabled == true)

-- Vente automatique des gris, par tranches de 12
EnterEra()
Mock.world.bags[0] = { size = 16, items = {} }
Mock.world.bags[1] = { size = 16, items = {} }
for i = 1, 15 do
	Mock.world.bags[0].items[i] = { itemID = 5000 + i, stackCount = 2, quality = 0, hyperlink = "gris" .. i }
	Mock.world.itemInfo["gris" .. i] = { name = "Gris " .. i, quality = 0 }
end
Mock.world.bags[1].items[1] = { itemID = 5100, stackCount = 1, quality = 0, hyperlink = "sansprix" }
Mock.world.bags[1].items[2] = { itemID = 5101, stackCount = 1, quality = 1, hyperlink = "blanc" }
Mock.world.bags[1].items[3] = { itemID = 5102, stackCount = 1, quality = 0, hyperlink = "gris16", hasNoValue = true }
local savedGetItemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(link)
	local price = ({ sansprix = 0, blanc = 500 })[link] or 25
	if link == "gris16" then price = 99 end
	return "Objet", link, (link == "blanc") and 1 or 0, 1, 1, "Divers", "", 1, "", nil, price
end
Mock:Fire("MERCHANT_SHOW")
Check("première passe : 12 objets vendus", #(Mock.world.sold or {}) == 12, #(Mock.world.sold or {}))
Check("une passe suivante est programmée", Mock.world.timers and #Mock.world.timers == 1)
Mock:Reset()
Mock:RunTimers()
Check("seconde passe : les 15 gris vendus", #(Mock.world.sold or {}) == 15, #(Mock.world.sold or {}))
Check("gris sans prix gardé", Mock.world.bags[1].items[1] ~= nil)
Check("objet blanc gardé", Mock.world.bags[1].items[2] ~= nil)
Check("gris « sans valeur » gardé", Mock.world.bags[1].items[3] ~= nil)
Check("récap chat : 15 objets, 7 pa 50 pc", Mock:Output():find("15 objet%(s%) gris vendu%(s%) : 7 pa 50 pc") ~= nil, Mock:Output())
Mock:Fire("MERCHANT_CLOSED")

Mock.world.sold = nil
Mock.world.bags[0].items[1] = { itemID = 5001, stackCount = 1, quality = 0, hyperlink = "gris1" }
NS:DB().autoSellGray = false
Mock:Fire("MERCHANT_SHOW")
Check("vente auto désactivée : rien vendu", Mock.world.sold == nil)
Mock:Fire("MERCHANT_CLOSED")
C_Item.GetItemInfo = savedGetItemInfo

-- Réparation automatique
EnterEra()
Check("vente auto activée par défaut", NS:DB().autoSellGray == true)
Check("réparation auto activée par défaut", NS:DB().autoRepair == true)
Mock.world.canRepair = true
Mock.world.repairCost = 12345
Mock.world.money = 100000
Mock.world.durability = { [5] = { 10, 100 } }
Mock:Reset()
Mock:Fire("MERCHANT_SHOW")
Check("réparation auto effectuée", Mock.world.repaired == 1)
Check("récap chat : 1 po 23 pa 45 pc", Mock:Output():find("réparé : 1 po 23 pa 45 pc") ~= nil, Mock:Output())
Mock:Fire("MERCHANT_CLOSED")
Mock.world.repaired = nil
Mock.world.repairCost = 50000
Mock.world.money = 100
Mock:Reset()
Mock:Fire("MERCHANT_SHOW")
Check("or insuffisant : pas de réparation", Mock.world.repaired == nil)
Check("or insuffisant : message", Mock:Output():find("Pas assez d'or") ~= nil, Mock:Output())
Mock:Fire("MERCHANT_CLOSED")
Mock.world.canRepair = false
Mock.world.money = 100000
Mock:Fire("MERCHANT_SHOW")
Check("marchand qui ne répare pas : rien", Mock.world.repaired == nil)
Mock:Fire("MERCHANT_CLOSED")
Mock.world.canRepair = true
NS:DB().autoRepair = false
Mock:Fire("MERCHANT_SHOW")
Check("réparation auto désactivée : rien", Mock.world.repaired == nil)
Mock:Fire("MERCHANT_CLOSED")

-- Réglages exposés dans le panneau d'options
EnterEra()
NS.optionsFrame = nil
NS:EnsureOptions()
local optKeys = {}
for _, row in ipairs(NS.optionsFrame and NS.optionsFrame.rows or {}) do
	if row.def and row.def.key then optKeys[row.def.key] = row.def end
end
Check("option : délai avant l'alerte (0–15 s)", optKeys.exitDelay and optKeys.exitDelay.min == 0 and optKeys.exitDelay.max == 15)
Check("option : vente auto des gris", optKeys.autoSellGray ~= nil)
Check("option : réparation auto", optKeys.autoRepair ~= nil)

-- Ligne « Parti de » dans la fenêtre de diagnostic
EnterEra()
NS:DB().safe["v:30:Comté-de-l'Or"] = { kind = "village", name = "Comté-de-l'Or", mapID = 30,
	subzone = "Comté-de-l'Or", source = "mail" }
Mock.world.mapID = 30
Mock.world.subzone = "Comté-de-l'Or"
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Mock.now = Mock.now + 60
Mock.world.subzone = "Bois de l'Est"
Mock:Fire("ZONE_CHANGED")
Mock:Advance(6)
Check("Era : sortie de village détectée", NS.lastResults ~= nil)
Check("fenêtre : ligne « Parti de » affichée", NS.window and NS.window.departed
	and NS.window.departed.text:find("Parti de Comté%-de%-l'Or") ~= nil
	and NS.window.departed.text:find("boîte aux lettres") ~= nil,
	NS.window and NS.window.departed and NS.window.departed.text)
NS:RunChecklist("manual")
Check("check manuel : pas de ligne « Parti de »", NS.window.departed.text == "", NS.window.departed.text)

-- Chaînes : chaque nouvelle clé existe en frFR ET en enUS
local newKeys = { "MSG_SAFE_PURGED", "MSG_SAFE_RESET", "SAFE_KIND_CITY", "SAFE_KIND_VILLAGE", "SRC_RESTING",
	"SRC_SANCTUARY", "SRC_BINDER", "SRC_TAXI", "SRC_MAIL", "SRC_BANK", "SRC_TRAINER", "SRC_MERCHANT", "SRC_QUEST",
	"SRC_MANUAL", "PANEL_DEPARTED", "HELP_TITLE", "HELP_RUN", "HELP_MODULE", "HELP_CHECK", "MSG_CHECK_LIST", "MSG_CHECK_SET", "MSG_CHECK_UNKNOWN", "MSG_MODULES_HEADER", "OPT_EXITDELAY", "OPT_SEC_UNIT", "OPT_SECTION_AUTO", "OPT_POPUPSCORE", "OPT_SCORE_UNIT", "MSG_BRIEF", "MSG_BRIEF_FROM", "MSG_AUTOSELL_NOTICE",
	"OPT_AUTOSELL", "OPT_AUTOREPAIR", "MONEY_GOLD", "MONEY_SILVER", "MONEY_COPPER", "MSG_SOLD", "MSG_REPAIRED",
	"MSG_REPAIR_POOR", "CHK_CLASSREAGENTS", "CHK_CLASSREAGENTS_LOW", "CHK_CLASSREAGENTS_GOOD", "ADV_CLASSREAGENTS",
	"REAGENT_AMMO", "REAGENT_SHARD", "REAGENT_FLASH", "REAGENT_TELEPORT", "REAGENT_ARCANE", "REAGENT_CANDLE",
	"REAGENT_SEED", "REAGENT_ANKH", "REAGENT_SYMBOL", "CHK_HEARTH", "CHK_HEARTH_MISSING", "CHK_HEARTH_READY",
	"CHK_HEARTH_CD", "ADV_HEARTH", "CHK_REPAIR", "CHK_REPAIR_NONE", "CHK_REPAIR_OK", "CHK_REPAIR_POOR",
	"ADV_REPAIR", "CHK_SPELLS", "CHK_SPELLS_DETAIL", "ADV_SPELLS", "MODULE_INACTIVE", "MSG_NO_SUBZONE" }
local localeSource = io.open(ROOT .. "/Ready2Quest/Locales.lua", "r"):read("*a")
local enStart = localeSource:find("local enUS = {", 1, true)
local frPart, enPart = localeSource:sub(1, enStart), localeSource:sub(enStart)
local missingFr, missingEn = {}, {}
for _, key in ipairs(newKeys) do
	if not frPart:find("\n\t" .. key .. " = ", 1, true) then missingFr[#missingFr + 1] = key end
	if not enPart:find("\n\t" .. key .. " = ", 1, true) then missingEn[#missingEn + 1] = key end
end
Check("nouvelles chaînes présentes en frFR", #missingFr == 0, table.concat(missingFr, ", "))
Check("nouvelles chaînes présentes en enUS", #missingEn == 0, table.concat(missingEn, ", "))

do
-- ---------------------------------------------------------------------------
-- Correctifs de l'audit Era (v1.18.0)
-- ---------------------------------------------------------------------------
Say("\n== audit Era : correctifs ==")

-- [2] vivres et potions en sous-classe générique 0 (vanilla)
EnterEra()
local savedItemSpell = _G.GetItemSpell
_G.GetItemSpell = function(itemID)
	return ({ [117] = "Nourriture", [159] = "Boisson", [9999] = "Invocation" })[itemID]
end
Mock.world.itemInfo[117] = { name = "Viande coriace", classID = 0, subClassID = 0 }
Mock.world.itemInfo[159] = { name = "Eau fraîche", classID = 0, subClassID = 0 }
Mock.world.itemInfo[118] = { name = "Potion de soins mineure", classID = 0, subClassID = 0 }
Mock.world.itemInfo[9999] = { name = "Babiole", classID = 0, subClassID = 0 }
Mock.world.bags[0].items[1] = { itemID = 117, stackCount = 4, quality = 1 }
Mock.world.bags[0].items[2] = { itemID = 159, stackCount = 6, quality = 1 }
Mock.world.bags[0].items[3] = { itemID = 118, stackCount = 3, quality = 1 }
Mock.world.bags[0].items[4] = { itemID = 9999, stackCount = 1, quality = 1 }
NS:DB().potionsThreshold = 3
NS:RunChecklist("manual")
Check("[2] Era : nourriture + boisson de sous-classe 0 comptées (10)", Result("vivres").detail:find("10") ~= nil,
	Result("vivres").detail)
Check("[2] Era : potion de sous-classe 0 comptée (3)", Result("potions").ok == true, Result("potions").detail)
_G.GetItemSpell = savedItemSpell

-- [3] journal de quêtes Era : forme moderne, isComplete = 1
EnterEra()
local savedTitle = _G.GetQuestLogTitle
_G.GetQuestLogTitle = function(index)
	local rows = {
		{ "Elwynn", 0, 0, true, false, nil },          -- en-tête
		{ "Les loups", 5, 0, false, false, 1 },       -- terminée
		{ "Le kobold", 6, 0, false, false, nil },      -- en cours
		{ "Échouée", 6, 0, false, false, -1 },         -- échouée
	}
	local r = rows[index]
	if not r then return nil end
	return r[1], r[2], r[3], r[4], r[5], r[6], 0, 100 + index
end
Mock.world.quests = { {}, {}, {}, {} }
NS:RunChecklist("manual")
Check("[3] Era : quête terminée (isComplete = 1) détectée", Result("quests").ok == false
	and Result("quests").detail:find("1") ~= nil, Result("quests").detail)
Check("[3] en-tête et quête échouée ignorés", NS.QuestLogReady(1) == false and NS.QuestLogReady(4) == false)
_G.GetQuestLogTitle = savedTitle

-- [4] GetItemInfoInstant global quand C_Item n'en a pas
EnterEra()
local savedInstant = C_Item.GetItemInfoInstant
_G.GetItemInfoInstant = savedInstant
C_Item.GetItemInfoInstant = nil
Mock.world.itemInfo[4101] = { name = "Pain", classID = 0, subClassID = 5 }
Mock.world.bags[0].items[1] = { itemID = 4101, stackCount = 7, quality = 1 }
NS:RunChecklist("manual")
Check("[4] repli GetItemInfoInstant global", Result("vivres").detail:find("7") ~= nil, Result("vivres").detail)
C_Item.GetItemInfoInstant = savedInstant
_G.GetItemInfoInstant = nil

-- [5] repli UnitAura : le spellId est le 10e retour
EnterEra()
local savedByIndex = C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = nil
_G.UnitAura = function(_, index)
	if index ~= 1 then return nil end
	return "Marque du fauve", 136078, 1, nil, 1800, 2800, "player", false, false, 1126
end
NS.lastBuffScan = nil
NS:ScanBuffs()
Check("[5] UnitAura : buff appris avec le bon spellId (10e retour)", NS:DB().buffs[1126] ~= nil
	and NS:DB().buffs[false] == nil)
_G.UnitAura = nil
C_UnitAuras.GetAuraDataByIndex = savedByIndex

-- [6] comparaison par famille : autre rang, version de groupe
EnterEra()
NS:DB().buffs[1243] = { name = "Mot de pouvoir : Robustesse", duration = 1800, enabled = true, learned = true }
Mock.world.auras = { [21562] = { name = "Prière de robustesse", duration = 3600 } }
Mock.world.auraOrder = { 21562 }
NS:RunChecklist("manual")
Check("[6] Prière de robustesse couvre Robustesse", Result("buffs").ok == true, Result("buffs").detail)
Mock.world.auras = { [10938] = { name = "Mot de pouvoir : Robustesse", duration = 1800 } }
Mock.world.auraOrder = { 10938 }
NS:RunChecklist("manual")
Check("[6] autre rang du même buff : pas manquant", Result("buffs").ok == true, Result("buffs").detail)
NS.lastBuffScan = nil
NS:ScanBuffs()
Check("[6] autre rang : pas appris une seconde fois", NS:DB().buffs[10938] == nil)
Check("[6] Bénédiction supérieure = Bénédiction", NS.BuffFamily("Bénédiction supérieure de puissance")
	== NS.BuffFamily("Bénédiction de puissance"))
Check("[6] Don du fauve = Marque du fauve", NS.BuffFamily("Don du fauve") == NS.BuffFamily("Marque du fauve"))

-- [7] sans GetPlayerAuraBySpellID : lecture par index, pas « illisible »
EnterEra()
local savedByID = C_UnitAuras.GetPlayerAuraBySpellID
C_UnitAuras.GetPlayerAuraBySpellID = nil
NS:DB().buffs[1459] = { name = "Intelligence des arcanes", duration = 1800, enabled = true }
NS:RunChecklist("manual")
Check("[7] sans API par spellID : buff absent = manquant", Result("buffs").ok == false
	and Result("buffs").detail:find("Intelligence") ~= nil, Result("buffs").detail)
Mock.world.auras = { [10157] = { name = "Intelligence des arcanes", duration = 1800 } }
Mock.world.auraOrder = { 10157 }
NS:RunChecklist("manual")
Check("[7] sans API par spellID : buff présent = OK", Result("buffs").ok == true, Result("buffs").detail)
C_UnitAuras.GetPlayerAuraBySpellID = savedByID

-- [23] buffs de consommables non appris, buffs oubliés après 7 jours
EnterEra()
Mock.world.auras = { [19705] = { name = "Bien nourri", duration = 900 } }
Mock.world.auraOrder = { 19705 }
NS.lastBuffScan = nil
NS:ScanBuffs()
Check("[23] « Bien nourri » n'est pas appris", NS:DB().buffs[19705] == nil)
Mock.world.auras, Mock.world.auraOrder = {}, {}
NS:DB().buffs[2000] = { name = "Buff mondial", duration = 7200, enabled = true, learned = true,
	lastSeen = time() - 8 * 24 * 3600 }
NS:RunChecklist("manual")
Check("[23] buff jamais revu depuis 8 jours : plus réclamé", Result("buffs").ok == true, Result("buffs").detail)

-- [8] [9] composants de métier : nombre possédé à jour, accroche de la sélection
EnterEra()
NS:ResetLegacyReagents()
local hooks = {}
_G.hooksecurefunc = function(name, fn) hooks[name] = fn end
_G.TradeSkillFrame_SetSelection = function() end
_G.GetTradeSkillReagentItemLink = function(index, slot)
	local recipe = (Mock.world.tradeSkillRecipes or {})[index]
	local reagent = recipe and (recipe.reagents or {})[slot]
	return reagent and ("|Hitem:" .. reagent.itemID .. "::|h[x]|h") or nil
end
Mock.world.tradeSkillRecipes = {
	{ name = "Bandage en lin", reagents = { { name = "Étoffe de lin", need = 2, have = 0, itemID = 2589 } } },
	{ name = "Bandage épais", reagents = { { name = "Étoffe de laine", need = 2, have = 0, itemID = 2592 } } },
}
Mock.world.tradeSkillSelection = 1
Mock:Fire("TRADE_SKILL_SHOW")
Check("[9] sélection de recette accrochée", type(hooks.TradeSkillFrame_SetSelection) == "function")
NS:InvalidateReagents()
NS:RunChecklist("manual")
Check("[8] composant manquant au départ", Result("reagents").ok == false, Result("reagents").detail)
Mock.world.bags[0].items[5] = { itemID = 2589, stackCount = 4, quality = 1 }
NS:InvalidateReagents()
NS:RunChecklist("manual")
Check("[8] sacs remplis ensuite : composant compté sans rescan", Result("reagents").ok == true, Result("reagents").detail)
Mock.world.tradeSkillSelection = 2
hooks.TradeSkillFrame_SetSelection(2)
NS:RunChecklist("manual")
Check("[9] changement de recette pris en compte", Result("reagents").detail:find("laine") ~= nil
	or Result("reagents").detail:find("épais") ~= nil, Result("reagents").detail)

-- [10] fenêtre Craft (Enchantement) sur Era
EnterEra()
NS:ResetLegacyReagents()
_G.GetCraftSelectionIndex = function() return 1 end
_G.GetCraftInfo = function() return "Enchantement de bracelets", nil, "optimal" end
_G.GetCraftNumReagents = function() return 1 end
_G.GetCraftReagentInfo = function() return "Poussière étrange", nil, 3, 1 end
_G.GetCraftReagentItemLink = function() return "|Hitem:10940::|h[Poussière étrange]|h" end
NS:DetectCapabilities()
Check("[10] capacité craftLegacy détectée", NS.Caps.craftLegacy == true)
-- le cadre d'événements a été enregistré au chargement, sans capacité Craft
-- dans le mock : on rejoue l'enregistrement comme le ferait le client Era
NS:RegisterEvents(NS.eventFrame)
Check("[10] CRAFT_SHOW écouté quand la capacité existe", NS.eventFrame.events.CRAFT_SHOW == true)
Mock:Fire("CRAFT_SHOW")
NS:InvalidateReagents()
NS:RunChecklist("manual")
Check("[10] composant d'enchantement manquant signalé", Result("reagents").ok == false
	and Result("reagents").detail:find("Poussière") ~= nil, Result("reagents").detail)
_G.GetCraftSelectionIndex, _G.GetCraftInfo, _G.GetCraftNumReagents = nil, nil, nil
_G.GetCraftReagentInfo, _G.GetCraftReagentItemLink = nil, nil
_G.hooksecurefunc, _G.TradeSkillFrame_SetSelection, _G.GetTradeSkillReagentItemLink = nil, nil, nil
NS:ResetLegacyReagents()

-- [11] puissance d'attaque = base + bonus (3 retours)
EnterEra()
local savedAP = _G.UnitAttackPower
_G.UnitAttackPower = function() return 100, 30, -5 end
Check("[11] PA = base + posBuff + negBuff", NS:StatSnapshot().ap == 125, NS:StatSnapshot().ap)
_G.UnitAttackPower = savedAP

-- [12] spé sur Era : onglet de talents le plus fourni
EnterEra()
local savedSpec, savedSpecInfo = _G.GetSpecialization, _G.GetSpecializationInfo
_G.GetSpecialization, _G.GetSpecializationInfo = nil, nil
_G.GetNumTalentTabs = function() return 3 end
_G.GetTalentTabInfo = function(tab)
	local tabs = { { "Sacré", 5 }, { "Protection", 0 }, { "Vindicte", 31 } }
	return tabs[tab][1], 135920, tabs[tab][2], "PaladinHoly"
end
Check("[12] Era : spé = onglet le plus fourni", NS.SpecIndex() == 3, NS.SpecIndex())
Check("[12] Era : paladin Vindicte affiche l'Intelligence d'abord",
	firstStat("PALADIN", nil):find("Intelligence") ~= nil, firstStat("PALADIN", nil))
_G.GetTalentTabInfo = function(tab)
	local tabs = { { "Sacré", 0 }, { "Protection", 31 }, { "Vindicte", 5 } }
	return tabs[tab][1], 135920, tabs[tab][2], "PaladinHoly"
end
Check("[12] Era : paladin Protection affiche l'Endurance d'abord",
	firstStat("PALADIN", nil):find("Endurance") ~= nil, firstStat("PALADIN", nil))
_G.GetSpecialization, _G.GetSpecializationInfo = savedSpec, savedSpecInfo
_G.GetNumTalentTabs, _G.GetTalentTabInfo = nil, nil

-- [17] [18] [19] pourcentage, Esprit, ilvl de repli
EnterEra()
local before = NS:StatSnapshot()
Mock.world.stats = { 25, 14, 30, 12, 40 }
local after = NS:StatSnapshot()
local spiRow = false
for _, row in ipairs(NS:DiffSnapshots(before, after)) do
	if row.key == "spi" or row.label == "SPI" or tostring(row.label):find("Esprit") then spiRow = true end
end
Check("[18] un changement d'Esprit apparaît dans le résumé", spiRow)
local savedAvg = _G.GetAverageItemLevel
_G.GetAverageItemLevel = nil
Mock.world.equipped = { [1] = "casque" }
Mock.world.links = { casque = { name = "Casque", quality = 2, itemLevel = 33, equipLoc = "INVTYPE_HEAD" } }
Check("[19] sans GetAverageItemLevel : ilvl calculé", NS:StatSnapshot().ilvl == 33, NS:StatSnapshot().ilvl)
-- [20] Equip sans C_Item.GetItemInfo : repli global
local savedCInfo = C_Item.GetItemInfo
_G.GetItemInfo = function(link) return savedCInfo(link) end
C_Item.GetItemInfo = nil
Check("[20] Equip : repli GetItemInfo global", NS.ItemData("casque") ~= nil and NS.ItemData("casque").itemLevel == 33)
C_Item.GetItemInfo = savedCInfo
_G.GetItemInfo = function(link) return _G.C_Item.GetItemInfo(link) end
_G.GetAverageItemLevel = savedAvg
NS:ShowPortraitStats()
local percentOK = true
for _, line in ipairs(NS.portraitFrame and NS.portraitFrame.lines or {}) do
	if tostring(line.right and line.right.text):find("%%%%") then percentOK = false end
end
Check("[17] armure : « % » affiché une seule fois", percentOK)
NS:HidePortraitStats()

-- [21] [22] troncature UTF-8 et glyphes ASCII
local cutText = NS.Truncate(string.rep("é", 30), 38)
local lastByte = cutText:byte(#cutText - 3)
Check("[21] troncature : aucun caractère coupé en deux", cutText:sub(-3) == "..."
	and #cutText - 3 <= 38 and (#cutText - 3) % 2 == 0, cutText)
EnterEra()
NS:RunChecklist("manual")
local firstAdvice = NS.window and NS.window.adviceLines[1].text or ""
Check("[22] puce de conseil en ASCII", not firstAdvice:find("•", 1, true), firstAdvice)

-- [14] [15] plus de « Sac & Départ » à l'écran
Check("[14] préfixe du chat : Ready2Quest", NS.L.TAG:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):find("[Ready2Quest]", 1, true) ~= nil, NS.L.TAG)
Check("[14] titre de fenêtre : Ready2Quest", NS.L.WIN_TITLE == "Ready2Quest", NS.L.WIN_TITLE)
Mock:Reset()
NS:RecordError("audit-15", "message unique de l'audit")
Check("[15] message d'erreur : Ready to Quest", Mock:Output():find("Ready2Quest — erreur") ~= nil, Mock:Output())

-- [16] /sd diag donne la raison, pas le mapID
EnterEra()
Mock.world.resting = true
Mock:Reset()
NS:HandleCommand("diag")
Check("[16] diag : raison de la zone sûre", Mock:Output():find("true %(resting") ~= nil, Mock:Output())

end
do
-- ---------------------------------------------------------------------------
-- Critique UX (v1.18.0)
-- ---------------------------------------------------------------------------
Say("\n== UX : alerte, combat, lignes, libellés ==")
local function ReadyWorld()
	EnterEra()
	Mock.world.itemInfo[4001] = { name = "Pain", classID = 0, subClassID = 5 }
	Mock.world.bags[0].items[1] = { itemID = 4001, stackCount = 10, quality = 1 }
	Mock.world.bags[0].items[2] = { itemID = 6948, stackCount = 1, quality = 1 }
	NS:DB().safe["v:30:Village"] = { kind = "village", name = "Village", mapID = 30, subzone = "Village", source = "mail" }
	Mock.world.mapID, Mock.world.subzone = 30, "Village"
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock.now = Mock.now + 60
	NS.window = nil
end

-- [2] bonne note : une ligne dans le chat, pas de fenêtre
ReadyWorld()
Mock:Reset()
Mock.world.subzone = "Bois"
Mock:Fire("ZONE_CHANGED")
Mock:Advance(6)
Check("[UX2] note >= 85 : check lancé", NS.lastResults ~= nil and (NS.score or 0) >= 85, NS.score)
Check("[UX2] note >= 85 : pas de fenêtre", NS.window == nil or NS.window.shown ~= true)
Check("[UX2] note >= 85 : une ligne dans le chat", Mock:Output():find("Sac bouclé, %d+/100%. Parti de Village%.") ~= nil, Mock:Output())
NS:RunChecklist("manual")
Check("[UX2] check manuel : fenêtre toujours ouverte", NS.window and NS.window.shown == true)
ReadyWorld()
NS:DB().popupScore = 100
Mock.world.subzone = "Bois"
Mock:Fire("ZONE_CHANGED")
Mock:Advance(6)
Check("[UX2] seuil 100 : toujours la fenêtre", NS.window and NS.window.shown == true)

-- [3] combat : la fenêtre attend la fin du combat
ReadyWorld()
NS:DB().popupScore = 100
_G.UnitAffectingCombat = function() return Mock.world.combat == true end
Mock.world.combat = true
Mock.world.subzone = "Bois"
Mock:Fire("ZONE_CHANGED")
Mock:Advance(30)
Check("[UX3] en combat : rien ne s'ouvre", NS.lastResults == nil and NS.pendingExit ~= nil)
Mock.world.combat = false
Mock:Advance(0.1)
Check("[UX3] fin du combat : l'alerte part", NS.lastResults ~= nil)
_G.UnitAffectingCombat = nil

-- [4] plus de doublon « Composants »
local labels = {}
for _, def in ipairs(NS.checks) do
	local label = type(def.label) == "function" and def.label() or def.label
	labels[label] = (labels[label] or 0) + 1
end
local dup = {}
for label, count in pairs(labels) do if count > 1 then dup[#dup + 1] = label end end
Check("[UX4] aucun libellé de module en double", #dup == 0, table.concat(dup, ", "))

-- [5] lignes sans objet masquées, échecs en tête, modules coupés en bas
EnterEra()
NS:SetModuleEnabled("quests", false)
Mock.world.durability = { [5] = { 5, 100 } }
NS.window = nil
NS:RunChecklist("manual")
local shown = {}
for i = 1, NS.window.visibleRows do shown[#shown + 1] = NS.window.rows[i].name.text end
local shownText = table.concat(shown, ", ")
Check("[UX5] modules sans objet masqués", not shownText:find("Réparation") and not shownText:find("Sorts")
	and not shownText:find("Réactifs"), shownText)
Check("[UX5] échec le plus lourd en tête (vivres, 20)", shown[1] == "Vivres", shownText)
Check("[UX5] module coupé par le joueur : en bas, grisé", shown[#shown] == "Quêtes", shownText)
Check("[UX5] fenêtre plus courte que 13 lignes", NS.window.height < NS:WindowHeight(13, false), NS.window.height)
-- v1.20.0 : la forme porte le statut (losange plein = à voir, au trait = OK)
local firstStatus = NS.window.rows[1].status
Check("[UX10] échec : losange plein", firstStatus.state == "bad" or firstStatus.state == "warn", firstStatus.state)
Check("[UX10] échec : texture pleine, pas au trait", tostring(firstStatus.texture):find("losange_trait") == nil,
	firstStatus.texture)
local okStatus
for i = 1, NS.window.visibleRows do
	if NS.window.rows[i].status.state == "ok" then okStatus = NS.window.rows[i].status end
end
Check("[UX10] OK : losange au trait", okStatus and tostring(okStatus.texture):find("losange_trait") ~= nil)
NS:SetModuleEnabled("quests", true)

-- [6] repos : information, sans poids ni conseil
EnterEra()
Mock.world.rested = 0
NS:RunChecklist("manual")
Check("[UX6] repos : poids nul", Result("rest").weight == 0)
local restAdvice = false
for _, a in ipairs(NS.lastAdvice or {}) do if a.text == NS.L.ADV_REST then restAdvice = true end end
Check("[UX6] repos : pas de conseil", restAdvice == false)

-- [7] détail des sorts : tient dans la colonne
EnterEra()
Mock.world.level = 10
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Mock.world.level = 12
NS:RunChecklist("manual")
Check("[UX7] sorts : détail court (<= 38)", #Result("spells").detail <= 38 and Result("spells").detail:find("10 %-> 12") ~= nil,
	Result("spells").detail)

-- [9] vente auto : prévenu une seule fois
EnterEra()
Mock:Reset()
Mock:Fire("MERCHANT_SHOW")
Mock:Fire("MERCHANT_CLOSED")
Mock:Fire("MERCHANT_SHOW")
Mock:Fire("MERCHANT_CLOSED")
local _, notices = Mock:Output():gsub("vend tes objets gris", "")
Check("[UX9] message de vente auto : une seule fois", notices == 1, notices)

-- [10] vert de statut distinct du vert de rareté
Check("[UX10] vert de statut ≠ vert « Inhabituel »", NS.Theme.T_GREEN ~= "|cff1eff00")

end
do
-- ---------------------------------------------------------------------------
-- Identité visuelle (v1.20.0)
-- ---------------------------------------------------------------------------
Say("\n== identité visuelle ==")
EnterEra()
NS.window = nil
Mock.world.durability = { [5] = { 5, 100 } }
NS:RunChecklist("manual")
local w = NS.window
Check("[ID] note en police maison, grand corps", w.scoreValue.font and w.scoreValue.font.size >= 30
	and tostring(w.scoreValue.font.path):find("Alegreya") ~= nil, w.scoreValue.font and w.scoreValue.font.size)
Check("[ID] verdict dans un tampon bordé", w.stamp and w.stamp.border and w.verdict.text ~= "", w.verdict.text)
Check("[ID] tampon à la couleur du verdict", w.stamp.border.top.vertex[1] == w.verdict.textColor[1])
Check("[ID] fenêtre : fondu à l'ouverture", w.fadeIn and w.fadeIn.plays >= 1)
Check("[ID] titre de la fenêtre : « Avant le départ »", w.title.text == "Avant le départ", w.title.text)
local target = NS.score
Check("[ID] animation : départ de 0", w.animStart ~= nil and w.animFrom == 0)
Mock:Advance(0.1)
local mid = tonumber(w.scoreValue.text)
Check("[ID] animation : la note monte", mid ~= nil and mid > 0 and mid < target, tostring(mid) .. " / " .. target)
Mock:Advance(1)
Check("[ID] animation : termine sur la valeur exacte", tonumber(w.scoreValue.text) == target and w.animStart == nil,
	w.scoreValue.text)
Check("[ID] puces de conseil : losanges ambre", w.adviceBullets[1] and tostring(w.adviceBullets[1].texture):find("losange") ~= nil)
Check("[ID] préfixe du chat ambre, « 2 » bleu", NS.L.TAG:find("|cffe8a54b", 1, true) ~= nil and NS.L.TAG:find("|cff5b8fd62", 1, true) ~= nil, NS.L.TAG)

NS.optionsFrame = nil
NS:ToggleOptions()
local o = NS.optionsFrame
Check("[ID] options : deux groupes dans la navigation", #o.navGroups == 2, #o.navGroups)
Check("[ID] options : bouton Fermer en ambre (principal)", o.closeButton.style == "primary")
local toggles, tracks, subs = 0, 0, 0
for _, row in ipairs(o.rows) do
	if row.toggle then toggles = toggles + 1 end
	if row.track then tracks = tracks + 1 end
end
for _, page in pairs(o.pages) do if page.sub.text ~= "" then subs = subs + 1 end end
Check("[ID] interrupteurs dessinés pour les booléens et contrôles", toggles == 13 + 7, toggles)
Check("[ID] pistes pour les seuils", tracks == 10, tracks)
local pageCount = 0
for _ in pairs(o.pages) do pageCount = pageCount + 1 end
Check("[ID] chaque page a sa phrase d'explication", subs == pageCount and pageCount == 9, subs .. "/" .. pageCount)
local displayRows = {}
for _, row in ipairs(o.pages.general.rows) do if row.def then displayRows[row.def.key] = true end end
Check("[AFF] Général réunit l'affichage", displayRows.showMinimap and displayRows.minimapPos and displayRows.showWindow
	and displayRows.popupScore and o.pages.general.sectionHeaders and #o.pages.general.sectionHeaders == 1)
-- bug signalé en jeu : cliquer sur « Stats du portrait » ou « Résumé de stuff »
-- ouvrait Général. Chaque module a maintenant sa page, qui explique ce qu'il fait.
for _, id in ipairs({ "toast", "portrait" }) do
	local nav
	for _, n in ipairs(o.navButtons) do if n.pageId == id then nav = n end end
	nav:Click()
	Check("[AFF] clic sur " .. id .. " : sa propre page", o.currentPage == id and o.pages[id] and o.pages[id]:IsShown(), o.currentPage)
	Check("[AFF] " .. id .. " : texte d'explication", o.pages[id].infoLines and #o.pages[id].infoLines == 3
		and o.pages[id].infoLines[1].text ~= "" and o.pages[id].infoLines[1].text ~= "OPT_" .. id:upper() .. "_INFO_1")
	Check("[AFF] " .. id .. " : bouton Placer le cadre", o.pages[id].actionButtons and o.pages[id].actionButtons.editMode ~= nil)
end
Check("[AFF] portrait : bouton Afficher maintenant", o.pages.portrait.actionButtons.portraitShow ~= nil)
NS:DB().showPortraitStats = false
NS.portraitFrame = nil
o.pages.portrait.actionButtons.portraitShow:Click()
Check("[AFF] Afficher maintenant : visible même module coupé", NS.portraitFrame and NS.portraitFrame:IsShown() == true)
NS:DB().showPortraitStats = true
local delayRow
for _, row in ipairs(o.rows) do if row.def and row.def.key == "exitDelay" then delayRow = row end end
NS:DB().exitDelay = 15
NS:RefreshOptions()
Check("[ID] piste pleine au maximum", delayRow.track.ratio == 1, delayRow.track.ratio)
local addonRow
for _, row in ipairs(o.rows) do if row.def and row.def.key == "enabled" then addonRow = row end end
Check("[ID] interrupteur actif = ambre", addonRow.toggle.checked == true and addonRow.toggle.knob.vertex[1] > 0.9)
addonRow:Click()
Check("[ID] clic : interrupteur coupé", addonRow.toggle.checked == false and NS:DB().enabled == false)
addonRow:Click()
NS:SelectOptionsPage("bags")
local function OptNav(id) for _, nav in ipairs(o.navButtons) do if nav.pageId == id then return nav end end end
Check("[ID] navigation : page active teintée", OptNav("bags").tint:IsShown() and not OptNav("general").tint:IsShown())
Check("[ID] navigation : le module parent reste actif", OptNav("departure").tint:IsShown())
Check("[ID] titre de page en police maison", o.pages.bags.title.font ~= nil)
-- v1.21.0 : marque Ready2Quest, deuxième couleur
Check("[R2Q] navigation : logo complet en tête", tostring(o.brandLogo.texture):find("Textures\\logo$") ~= nil, o.brandLogo.texture)
Check("[R2Q] navigation : nom avec le « 2 » bleu", o.brandName.text:find("|cff5b8fd62|r", 1, true) ~= nil, o.brandName.text)
Check("[R2Q] bandeau : logo simplifié", tostring(o.logo.texture):find("logo_petit") ~= nil, o.logo.texture)
Check("[R2Q] groupes de navigation en bleu", o.navGroups[1].textColor[3] > 0.8 and o.navGroups[1].textColor[1] < 0.4)
Check("[R2Q] commande /r2q", SLASH_SACETDEPART3 == "/r2q")

-- v1.22.0 : trois modules, chacun avec son interrupteur dans la navigation
NS.optionsFrame = nil
NS:ToggleOptions()
local function NavOf(id) for _, nav in ipairs(NS.optionsFrame.navButtons) do if nav.pageId == id then return nav end end end
local powered = {}
for _, nav in ipairs(NS.optionsFrame.navButtons) do if nav.power then powered[#powered + 1] = nav.pageId end end
table.sort(powered)
Check("[NAV] interrupteur sur les 3 modules seulement", table.concat(powered, ",") == "departure,portrait,toast", table.concat(powered, ","))
Check("[NAV] sous-pages en retrait, sans interrupteur", NavOf("trigger").parentId == "departure" and NavOf("trigger").power == nil)
Check("[NAV] QoL : Marchand, sous-page du QoL", NavOf("merchant").power == nil and NavOf("merchant").parentId == "qol")
NS:SelectOptionsPage("general")
Check("[NAV] sous-pages repliées hors de leur module", not NavOf("trigger"):IsShown() and not NavOf("merchant"):IsShown())
NS:SelectOptionsPage("bags")
Check("[NAV] sous-pages du départ dépliées", NavOf("trigger"):IsShown() and not NavOf("merchant"):IsShown())
NS:SelectOptionsPage("merchant")
Check("[NAV] sous-pages du QoL dépliées", NavOf("merchant"):IsShown() and not NavOf("trigger"):IsShown())
NS:SelectOptionsPage("general")
local dep = NavOf("departure")
Check("[NAV] check avant le départ : allumé", dep.power.checked == true)
dep.power:Click()
Check("[NAV] clic : module coupé", NS:DB().departureEnabled == false and dep.power.checked == false)
Check("[NAV] clic : on reste sur la page courante", NS.optionsFrame.currentPage == "general")
dep.power:Click()
Check("[NAV] second clic : rallumé", NS:DB().departureEnabled == true)
NavOf("portrait").power:Click()
Check("[NAV] stats du portrait coupées", NS:DB().showPortraitStats == false)
NavOf("portrait").power:Click()
NavOf("toast").power:Click()
Check("[NAV] résumé de stuff coupé", NS:DB().showGearToast == false)
NavOf("toast").power:Click()
-- le QoL ne dépend pas du module de départ
NS:DB().departureEnabled = false
Check("[NAV] QoL indépendant : vente auto toujours active", NS:DB().autoSellGray ~= false)
NS:DB().departureEnabled = true

-- v1.22.0 : base livrée des zones sûres, faction, instances, camp de Forever
do
	ResetWorld()
	Check("[HUB] base livrée chargée", NS.HUBS and NS.HUBS[87] and NS.HUBS[87].name == "Goldshire" and NS.HUBS[1519].kind == "capital")
	local count = 0
	for _ in pairs(NS.HUBS) do count = count + 1 end
	Check("[HUB] au moins 75 lieux", count >= 75, count)
	-- village connu, sans aucun apprentissage
	_G.UnitFactionGroup = function() return Mock.world.faction or "Alliance" end
	Mock.world.mapID, Mock.world.subzone = 30, "Goldshire"
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	local safe, _, why, entry = NS:IsCurrentZoneSafe()
	Check("[HUB] Goldshire sûr dès l'installation", safe == true and why == "known", tostring(why))
	Check("[HUB] rien n'a été appris pour ça", next(NS:DB().safe) == nil)
	Mock.now = Mock.now + 60
	Mock.world.subzone = "Fargodeep Mine"
	Mock:Fire("ZONE_CHANGED"); Mock:Advance(6)
	Check("[HUB] sortie de Goldshire : alerte", NS.lastResults ~= nil)
	Check("[HUB] parti de : lieu connu", NS:DepartedText() and NS:DepartedText():find("Goldshire") and NS:DepartedText():find("lieu connu"),
		NS:DepartedText())
	Check("[HUB] une mine n'est pas sûre", NS:IsCurrentZoneSafe() == false)

	-- noms traduits par le jeu
	ResetWorld()
	-- le client traduit chaque identifiant (Goldshire a aussi l'ID 16524 sur Forever)
	_G.C_Map.GetAreaInfo = function(areaID)
		return ({ [87] = "Comté-de-l'Or", [16524] = "Comté-de-l'Or", [1637] = "Orgrimmar" })[areaID] or ("Zone " .. areaID)
	end
	Mock.world.mapID, Mock.world.subzone = 30, "Comté-de-l'Or"
	Check("[HUB] nom traduit par le client (frFR)", NS:IsCurrentZoneSafe() == true)
	Mock.world.subzone = "Goldshire"
	NS.hubIndex = nil
	Check("[HUB] le nom anglais ne compte plus une fois traduit", NS:IsCurrentZoneSafe() == false)
	_G.C_Map.GetAreaInfo = nil

	-- faction : le village de l'autre faction n'est pas sûr, et n'est pas appris
	ResetWorld()
	Mock.world.faction = "Horde"
	Mock.world.mapID, Mock.world.subzone = 30, "Southshore"
	local hostileSafe, _, hostileWhy = NS:IsCurrentZoneSafe()
	Check("[HUB] Southshore pour un Horde : pas sûr", hostileSafe == false and hostileWhy == "hostile", tostring(hostileWhy))
	Mock:Fire("MAIL_SHOW")
	Check("[HUB] ville hostile : jamais apprise", next(NS:DB().safe) == nil)
	Mock.world.subzone = "Booty Bay"
	Check("[HUB] ville neutre : sûre pour tous", NS:IsCurrentZoneSafe() == true)
	Mock.world.subzone = "Tarren Mill"
	Check("[HUB] Tarren Mill pour un Horde : sûr", NS:IsCurrentZoneSafe() == true)

	-- capitale reconnue par le nom de la zone, dans n'importe quel quartier
	_G.GetRealZoneText = function() return Mock.world.zone or "" end
	Mock.world.zone, Mock.world.subzone = "Orgrimmar", "Valley of Strength"
	Check("[HUB] capitale : sûre dans n'importe quel quartier", NS:IsCurrentZoneSafe() == true)
	Mock.world.faction = "Alliance"
	Check("[HUB] capitale ennemie : pas sûre", NS:IsCurrentZoneSafe() == false)
	Mock.world.zone = nil

	-- instance : jamais une zone de départ
	Mock.world.faction = "Alliance"
	Mock.world.subzone = "Goldshire"
	_G.IsInInstance = function() return Mock.world.instance == true end
	Mock.world.instance = true
	Check("[HUB] en instance : jamais sûr", NS:IsCurrentZoneSafe() == false)
	Mock.world.instance = false

	-- camp de Forever : aura « Campfire Nearby » (1283391)
	ResetWorld()
	Mock.world.mapID, Mock.world.subzone = 20, "Plaine"
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock.now = Mock.now + 60
	Mock.world.auras = { [1283391] = { name = "Campfire Nearby", duration = 0 } }
	Mock.world.auraOrder = { 1283391 }
	Mock:Fire("UNIT_AURA", "player")
	local campSafe, _, campWhy = NS:IsCurrentZoneSafe()
	Check("[CAMP] près du feu : zone de départ", campSafe == true and campWhy == "camp", tostring(campWhy))
	Mock.world.resting = true
	Mock:Fire("PLAYER_UPDATE_RESTING"); Mock:Fire("MAIL_SHOW"); Mock:Fire("MERCHANT_SHOW"); Mock:Fire("MERCHANT_CLOSED")
	Check("[CAMP] le camp n'est jamais appris", next(NS:DB().safe) == nil and next(NS:DB().safeClues) == nil)
	Mock.world.resting = false
	Mock.world.auras, Mock.world.auraOrder = {}, {}
	Mock:Fire("UNIT_AURA", "player")
	Mock:Advance(6)
	Check("[CAMP] quitter le camp : alerte", NS.lastResults ~= nil)
	Check("[CAMP] parti du campement", NS:DepartedText() and NS:DepartedText():find("campement") and NS:DepartedText():find("feu de camp"),
		NS:DepartedText())

	-- buffs du camp : jamais appris
	ResetWorld()
	Mock.world.auras = { [1289378] = { name = "Warmth", duration = 3600 }, [1229741] = { name = "Camp Benefits", duration = 1800 },
		[1459] = { name = "Intelligence des arcanes", duration = 1800 } }
	Mock.world.auraOrder = { 1289378, 1229741, 1459 }
	NS.lastBuffScan = nil
	NS:ScanBuffs()
	Check("[CAMP] Warmth et Camp Benefits ignorés", NS:DB().buffs[1289378] == nil and NS:DB().buffs[1229741] == nil)
	Check("[CAMP] les vrais buffs restent appris", NS:DB().buffs[1459] ~= nil)

	-- module coupé : aucune alerte
	ResetWorld()
	NS:DB().departureEnabled = false
	Mock.world.mapID, Mock.world.subzone = 30, "Goldshire"
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock.now = Mock.now + 60
	Mock.world.subzone = "Bois"
	Mock:Fire("ZONE_CHANGED"); Mock:Advance(6)
	Check("[MOD] check avant le départ coupé : pas d'alerte", NS.lastResults == nil)
	_G.UnitFactionGroup, _G.GetRealZoneText, _G.IsInInstance = nil, nil, nil
end

-- retours de la première session en jeu (Era, Vallée des épreuves)
NS.editBanner = nil
NS:StartEditMode()
local banner = NS.editBanner
local hintTop = banner.contentTop - 4
local buttonTop = -(banner.height - 10 - 20)
Check("[JEU] bandeau d'édition : l'aide ne passe plus sous le bouton", hintTop - 26 >= buttonTop,
	(hintTop - 26) .. " >= " .. buttonTop)
Check("[JEU] bandeau d'édition : bouton Terminer en ambre", banner.stopButton.style == "primary")
NS:StopEditMode()
EnterEra()
Mock.world.bags[0].items[1] = { itemID = 3001, stackCount = 1, quality = 0 }
Mock.world.bags[0].items[2] = { itemID = 3002, stackCount = 1, quality = 0 }
Mock.world.durability = { [5] = { 5, 100 } }
NS.window = nil
NS:RunChecklist("manual")
local grayRow, duraRow
for i = 1, NS.window.visibleRows do
	local row = NS.window.rows[i]
	if row.name.text == "Butin à vendre" then grayRow = row end
	if row.name.text == "Durabilité" then duraRow = row end
end
Check("[JEU] 2 gris : ambre, pas rouge (module léger)", grayRow and grayRow.status.state == "warn", grayRow and grayRow.status.state)
Check("[JEU] durabilité à 5 % : rouge (module lourd)", duraRow and duraRow.status.state == "bad", duraRow and duraRow.status.state)
Check("[R2Q] API publique sous les deux noms", _G.Ready2Quest == NS and _G.ReadyToQuest == NS)

end
LeaveEra()
Mock.world.classToken = nil
end

-- 4.99 Tests des modules (tests/modules/*.lua, listés par run_tests.py).
-- Chaque fichier reçoit la boîte à outils du harnais dans la table T.
do
	_G.T = { Check = Check, Say = Say, ResetWorld = ResetWorld, Result = Result, NS = NS, Mock = Mock }
	-- build Forever par défaut au chargement des modules, comme en jeu
	Mock.world.build = nil
	NS:DetectCapabilities()
	for _, file in ipairs(Mock.moduleFiles) do LoadAddonFile(file) end
	-- le client pose QuestCompanionDB puis envoie ADDON_LOADED("QuestCompanion")
	Mock:Fire("ADDON_LOADED", "Ready2Quest")
	Mock:Fire("ADDON_LOADED", "QuestCompanion")
	for _, path in ipairs(MODULE_TEST_FILES or {}) do
		Say("\n== module : " .. path .. " ==")
		local handle = assert(io.open(ROOT .. "/" .. path, "r"))
		local source = handle:read("*a")
		handle:close()
		local chunk, compileError = loadstring(source, "@" .. path)
		assert(chunk, "erreur de compilation dans " .. path .. ":\n" .. tostring(compileError))
		chunk()
	end
end

-- 5. Bilan
----------------------------------------------------------------------------
Say("")
Say(string.format("RESULTAT: %d réussis, %d échoués, %d assertions", passed, failed, passed + failed))
_G.TEST_PASSED = passed
_G.TEST_FAILED = failed
_G.TEST_OUTPUT = table.concat(lines, "\n")
