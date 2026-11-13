-- tests/run_tests.lua -- harnais de test hors-jeu (Lua 5.1, comme le client WoW)
--
-- Simule le sous-ensemble d'API utilisé par l'addon, charge les fichiers de
-- l'addon comme le fait le client, puis joue des scénarios et vérifie les
-- résultats. Ne remplace pas un test en jeu : ça valide la LOGIQUE, pas les
-- contrats d'API réels (le /sd diag existe pour ça).

-- Mode test : les addons gardent les deux langues et leurs tables de textes
-- exposées (ns.KEEP_STRINGS, Strings.lua). Pas en mesure de mémoire
-- (--memoire) : on mesure alors l'addon tel que le client le charge.
if not rawget(_G, "MEMORY_ONLY") then _G.ADDON_TESTING = true end

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
	-- 2.11.1 / 1.32.1 : un événement = une nouvelle image pour les caches
	-- « par image » (ns:AtCamp), l'horloge de la maquette ne bougeant pas
	if self.OnNewFrame then self.OnNewFrame() end
	for _, frame in ipairs(self.frames) do
		local filter = frame.unitFilter and frame.unitFilter[event]
		if frame.events and frame.events[event] and frame.script
			and not (filter and not filter[(...)]) then
			frame.script(frame, event, ...)
		end
	end
end

Mock.world = {}

-- Chaque région garde aussi de quoi la dessiner hors-jeu (tests/snapshot.lua) :
-- parent (mockParent, mockChildren), ordre de création (mockId), couche
-- (drawLayer, subLevel), taille posée ou non (widthSet, heightSet), Hide
-- explicite (mockHidden : le client montre une région par défaut).
Mock.serial = 0
local function NewRegion(kind, name, parent)
	Mock.serial = Mock.serial + 1
	local region = {
		kind = kind, name = name, events = {}, text = "", shown = false,
		scripts = {}, width = 100, height = 100, vertex = { 1, 1, 1 },
		texture = nil, points = {}, level = 1, mockId = Mock.serial, mockChildren = {},
	}
	if parent then
		region.mockParent = parent
		if type(parent) == "table" and parent.mockChildren then table.insert(parent.mockChildren, region) end
	end
	function region:RegisterEvent(event)
		if Mock.world.unknownEvents and Mock.world.unknownEvents[event] then
			error("Attempt to register unknown event \"" .. tostring(event) .. "\"")
		end
		self.events[event] = true
	end
	-- comme le client : l'événement d'unité n'arrive que pour les unités dites
	function region:RegisterUnitEvent(event, ...)
		self:RegisterEvent(event)
		self.unitFilter = self.unitFilter or {}
		local units = {}
		for i = 1, select("#", ...) do units[(select(i, ...))] = true end
		self.unitFilter[event] = units
	end
	function region:UnregisterEvent(event)
		self.events[event] = nil
		if self.unitFilter then self.unitFilter[event] = nil end
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
	function region:CreateFontString(_, layer, fontObject)
		local fontString = NewRegion("FontString", nil, self)
		fontString.fontObject = fontObject
		fontString.drawLayer = layer
		-- approximation : 6.4 px par caractere pour F_SMALL. Suffisant pour
		-- verifier qu'un libelle tient dans son bouton, ce qui est le point.
		function fontString:GetStringWidth()
			return #(self.text or "") * 6.4
		end
		return fontString
	end
	function region:CreateTexture(_, layer, _, subLevel)
		local texture = NewRegion("Texture", nil, self)
		texture.drawLayer, texture.subLevel = layer, subLevel
		return texture
	end
	function region:SetDrawLayer(layer, subLevel) self.drawLayer, self.subLevel = layer, subLevel end
	function region:GetDrawLayer() return self.drawLayer, self.subLevel end
	function region:GetParent() return self.mockParent end
	function region:SetParent(parent)
		local old = self.mockParent
		if type(old) == "table" and old.mockChildren then
			for index, child in ipairs(old.mockChildren) do
				if child == self then table.remove(old.mockChildren, index); break end
			end
		end
		self.mockParent = parent
		if type(parent) == "table" and parent.mockChildren then table.insert(parent.mockChildren, self) end
	end
	function region:SetSize(w, h) self.width, self.height = w, h; self.widthSet, self.heightSet = true, true end
	function region:SetWidth(w) self.width = w; self.widthSet = true end
	function region:SetHeight(h) self.height = h; self.heightSet = true end
	function region:GetWidth() return self.width end
	function region:GetHeight() return self.height end
	-- rangé à part de points/lastPoint : GetPoint reste celui de SetPoint
	function region:SetAllPoints(relativeTo) self.allPoints = relativeTo or true end
	-- Mock.world.textureRefused[fichier] : le client refuse ce fichier (SetTexture rend false, rien n'est posé)
	function region:SetTexture(path)
		local refused = Mock.world.textureRefused
		if refused and path ~= nil and refused[path] then return false end
		self.texture = path; self.colorTexture = nil
	end
	function region:SetColorTexture(r, g, b, a)
		self.texture = "Interface\\Buttons\\WHITE8X8"
		self.colorTexture = { r, g, b, a or 1 }
		-- simplification : la couleur posée se lit aussi dans vertex
		self.vertex = { r, g, b, a or 1 }
	end
	function region:SetGradient(orientation, minColor, maxColor) self.gradient = { orientation, minColor, maxColor } end
	-- (pas de SetGradientAlpha : l'ancienne API, absente de Forever ; testée à part)
	function region:SetAtlas(path) self.atlas = path end
	function region:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
	-- lecture (2.8.2, /qc debug bulle) : type, fichier, alpha, découpe, couleur
	function region:GetObjectType() return self.kind end
	function region:GetTexture() return self.texture end
	function region:GetAlpha() return self.alpha or 1 end
	function region:GetTexCoord() local c = self.texCoord or { 0, 1, 0, 1 }; return c[1], c[2], c[3], c[4] end
	function region:GetVertexColor() local v = self.vertex or {}; return v[1], v[2], v[3], v[4] or 1 end
	function region:SetAlpha(value) self.alpha = value end
	-- échelle du cadre (SetScale) : rangée à part, « scale » est un champ libre
	-- des addons (le compagnon y garde la taille de son modèle)
	function region:SetScale(value) self.frameScale = value end
	function region:GetScale() return self.frameScale or 1 end
	function region:GetName() return self.name end
	function region:SetHighlightTexture(texture) self.highlightTexture = texture end
	-- BackdropTemplate
	function region:SetBackdrop(backdrop) self.backdrop = backdrop end
	function region:SetBackdropColor(r, g, b, a) self.backdropColor = { r, g, b, a } end
	function region:SetBackdropBorderColor(r, g, b, a) self.backdropBorderColor = { r, g, b, a } end
	function region:SetFixedFrameStrata() end
	function region:SetFixedFrameLevel() end
	-- coordonnées de texture : gardées pour l'aperçu (une icône retournée)
	function region:SetTexCoord(...) self.texCoord = { ... } end
	-- rotation (radians, sens trigonométrique), mode de fusion, rognage des
	-- enfants : gardés pour les tests et l'aperçu (tests/snapshot.lua)
	function region:SetRotation(radians) self.rotation = radians end
	function region:GetRotation() return self.rotation or 0 end
	function region:SetBlendMode(mode) self.blendMode = mode end
	function region:GetBlendMode() return self.blendMode or "BLEND" end
	function region:SetClipsChildren(value) self.clipsChildren = value end
	function region:SetWordWrap(wrap) self.wordWrap = wrap end
	function region:SetFrameLevel(level) self.level = level; self.levelSet = true end
	function region:GetFrameLevel() return self.level end
	function region:SetClampedToScreen() end
	function region:ClearAllPoints() self.points = {}; self.allPoints = nil end
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
	function region:SetJustifyH(value) self.justifyH = value end
	function region:SetJustifyV(value) self.justifyV = value end
	function region:EnableMouseWheel(value) self.mouseWheel = value end
	-- champ de saisie (EditBox)
	function region:SetAutoFocus(value) self.autoFocus = value end
	function region:SetTextInsets(l, r, t, b) self.textInsets = { l, r, t, b } end
	function region:SetMaxLetters(value) self.maxLetters = value end
	function region:SetFocus() self.focused = true end
	function region:ClearFocus() self.focused = false end
	function region:HasFocus() return self.focused == true end
	function region:Show() self.shown = true; self.mockHidden = false end
	function region:Hide() self.shown = false; self.mockHidden = true end
	function region:IsShown() return self.shown end
	-- QC 3.0.0 : boutons activables (Enable / Disable / SetEnabled / IsEnabled du client) ;
	-- le clic simulé (GetScript("OnClick")) n'est pas bloqué : les modules gardent leur garde
	function region:SetEnabled(on) self.enabled = (on and on ~= 0) and true or false end
	function region:Enable() self.enabled = true end
	function region:Disable() self.enabled = false end
	function region:IsEnabled() return self.enabled ~= false end
	function region:CreateAnimationGroup()
		local group = { plays = 0, animations = {} }
		function group:CreateAnimation(kind)
			local anim = { kind = kind }
			function anim:SetFromAlpha(v) self.from = v end
			function anim:SetToAlpha(v) self.to = v end
			function anim:SetDuration(v) self.duration = v end
			-- QC 2.14.0 (bêta 6) : neige du cadre (translation, attente, lissage)
			function anim:SetOffset(x, y) self.offset = { x, y } end
			function anim:SetStartDelay(v) self.startDelay = v end
			function anim:SetSmoothing(v) self.smoothing = v end
			self.animations[#self.animations + 1] = anim
			return anim
		end
		function group:Play() self.plays = self.plays + 1; self.playing = true end
		function group:Stop() self.playing = false end
		function group:IsPlaying() return self.playing == true end
		self.animGroups = (self.animGroups or 0) + 1
		return group
	end
	function region:SetFont(path, size, flags)
		if Mock.world.fontRefused then return false end
		-- client muet : SetFont ne rend rien, et un fichier refusé n'est pas posé
		if Mock.world.fontSilent then
			if Mock.world.fontSilent ~= "refuse" then self.font = { path = path, size = size, flags = flags } end
			return nil
		end
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
	function region:SetFontObject(font) self.fontObject = font end
	-- objet de police (CreateFont) : copie d'un autre objet
	function region:CopyFontObject(font)
		if font == nil then error("CopyFontObject: objet de police attendu") end
		self.copiedFrom = font
	end
	function region:GetFont()
		if self.font then return self.font.path, self.font.size, self.font.flags end
		return nil
	end
	function region:SetNormalFontObject() end
	function region:SetDisabledFontObject() end
	-- addon qui l'a créée (mesure de la mémoire après connexion, --memoire)
	region.mockAddon = Mock.currentAddon
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
	return NewRegion(kind, name, parent)
end
-- Objets de police : CreateFont(nom) les range en global, comme le client.
-- Mock.world.noCreateFont simule un client sans CreateFont.
_G.CreateFont = function(name)
	if Mock.world and Mock.world.noCreateFont then error("CreateFont indisponible") end
	local font = NewRegion("Font", name)
	if name then _G[name] = font end
	return font
end
-- polices du jeu (repli des objets du socle) : chemin et taille du client
for fontName, size in pairs({ GameFontNormalHuge = 20, GameFontNormalLarge = 16, GameFontHighlight = 12,
	GameFontHighlightSmall = 10, GameFontNormalSmall = 10, GameFontNormal = 12, NumberFontNormal = 14 }) do
	local font = _G.CreateFont(fontName)
	font.font = { path = "Fonts\\FRIZQT__.TTF", size = size, flags = "" }
end
-- CreateColor n'est PAS posé par défaut : des tests vérifient le repli d'un
-- client sans (companion_rewards). Mock.CreateColor sert à ceux qui le veulent
-- (tests/snapshot.lua, tests/modules/ui_bricks.lua).
function Mock.CreateColor(r, g, b, a)
	local color = { r = r, g = g, b = b, a = a or 1 }
	function color:GetRGBA() return self.r, self.g, self.b, self.a end
	return color
end
-- Atlas du client (C_Texture.GetAtlasInfo, QuestCompanion 2.5.0) : absent par
-- défaut, le style Azeroth retombe alors sur Sobre partout. Mock.InstallAtlas(true)
-- pose l'API avec tous les atlas ; Mock.InstallAtlas({ nom = true }) : ces atlas
-- manquent ; Mock.InstallAtlas(nil) l'ôte.
function Mock.InstallAtlas(mode)
	if mode == nil then _G.C_Texture = nil; return end
	local missing = type(mode) == "table" and mode or {}
	_G.C_Texture = {
		GetAtlasInfo = function(name)
			if missing[name] then return nil end
			return { width = 64, height = 64, file = 4035524 }
		end,
	}
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
-- journal de combat ouvert par défaut (les modules qui le testent remplacent
-- la fonction) ; le cas « fermé » (moteur 12.0) est testé à part
_G.CombatLogGetCurrentEventInfo = function() return nil end
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

-- Le client expose GetItemInfo en global ; le mock doit le
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
function GameTooltip:ClearLines() self.lines, self.styled = {}, {} end
-- .lines : le texte seul (ce que lisent les tests) ; .styled : texte et
-- couleurs, pour l'aperçu hors-jeu (tests/snapshot.lua, Snap.Tooltip)
function GameTooltip:AddLine(text, r, g, b, wrap)
	self.lines = self.lines or {}
	self.lines[#self.lines + 1] = tostring(text)
	self.styled = self.styled or {}
	self.styled[#self.styled + 1] = { text = tostring(text), color = r and { r, g, b }, wrap = wrap }
end
function GameTooltip:AddDoubleLine(a, b, lr, lg, lb, rr, rg, rb)
	self.lines = self.lines or {}
	self.lines[#self.lines + 1] = tostring(a) .. " " .. tostring(b)
	self.styled = self.styled or {}
	self.styled[#self.styled + 1] = { text = tostring(a), color = lr and { lr, lg, lb },
		right = tostring(b), rightColor = rr and { rr, rg, rb } }
end
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
		return { spellId = spellId, duration = aura.duration or 0, name = aura.name, sourceUnit = aura.sourceUnit,
			isFromPlayerOrPlayerPet = aura.isFromPlayerOrPlayerPet }
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
		return { questID = q.questID, title = q.title, isHeader = q.isHeader == true, isCollapsed = q.collapsed == true }
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
-- QuestCompanion : addon autonome, avec sa propre table privée (son namespace)
-- et sa copie du socle commun. Les tests de ses modules la reçoivent en T.QNS.
local QNS = {}
Mock.OnNewFrame = function() NS.atCampAt = nil; QNS.atCampAt = nil end
local function LoadAddonFile(name)
	local path = ROOT .. "/" .. name
	-- mesure de la mémoire (python3 tests/run_tests.py --memoire) : ce que
	-- chaque fichier laisse en mémoire Lua une fois chargé (code compilé
	-- compris, après ramassage). Socle 2.11.0 : relevée AVANT la lecture du
	-- texte source (sinon chaque ligne était diminuée de la taille du fichier)
	local report = rawget(_G, "MEMORY_REPORT")
	local before
	if report then collectgarbage("collect"); collectgarbage("collect"); before = collectgarbage("count") end
	local handle, err = io.open(path, "r")
	assert(handle, "ouverture impossible: " .. path .. " (" .. tostring(err) .. ")")
	local source = handle:read("*a")
	handle:close()
	Mock.currentAddon = name:match("^([^/]+)/")
	local chunk, compileError = loadstring(source, "@" .. path)
	assert(chunk, "erreur de compilation dans " .. path .. ":\n" .. tostring(compileError))
	-- comme le client : chaque addon reçoit son nom et sa propre table privée
	if name:find("^QuestCompanion/") then
		chunk("QuestCompanion", QNS)
	else
		chunk("Ready2Quest", NS)
	end
	if report then
		source, chunk = nil, nil
		collectgarbage("collect"); collectgarbage("collect")
		report[#report + 1] = { name = name, kb = collectgarbage("count") - before }
	end
	Mock.currentAddon = nil
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
			-- le client accepte « Libs\Socle\Base.lua » : chemin à barres obliques ici
			line = line:gsub("\\", "/")
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
	-- le cœur de Ready2Quest : sa configuration, le socle commun (Libs/Socle),
	-- ses textes, Core, ses pages de réglages et les contrôles du check
	local core = {}
	for _, file in ipairs({ "Config.lua", "Locales.lua", "Core.lua", "OptionPages.lua", "Buffs.lua",
		"Reagents.lua", "Merchant.lua", "Equip.lua", "Stats.lua", "Checks.lua", "UI.lua" }) do
		core[file] = true
	end
	for _, file in ipairs(tocFiles) do
		local name = file:gsub("^Ready2Quest/", "")
		if file:find("^Ready2Quest/") and (core[name] or name:find("^Libs/Socle/")) then
			LoadAddonFile(file)
		else
			table.insert(Mock.moduleFiles, file)
		end
	end
end
_G.TOC_FILES = tocFiles
-- mesure de la mémoire seule : tous les fichiers chargés ; la connexion est
-- jouée plus bas (après ResetWorld), puis on s'arrête
if rawget(_G, "MEMORY_ONLY") then
	for _, file in ipairs(Mock.moduleFiles) do LoadAddonFile(file) end
end

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
	}
	Mock.secretAuras = false
	Mock.now = 1000
	Mock:Reset()
	-- les deux : la nouvelle variable, et l ancienne que Core migre
	_G.Ready2QuestDB = nil
	_G.QuestCompanionDB = nil
	QNS._dbReady = false
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
-- 3 bis. Mesure de la mémoire après connexion (--memoire) : chaque addon
-- reçoit ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD, ses minuteries et
-- dix secondes d'OnUpdate (installation neuve, client français). Les régions
-- de la maquette sont de grosses tables (une fermeture par méthode) : leur
-- coût est retiré du total et leur nombre affiché à part (le vrai client les
-- garde hors de la mémoire Lua).
----------------------------------------------------------------------------
if rawget(_G, "MEMORY_ONLY") then
	local report = rawget(_G, "MEMORY_REPORT")
	local function Collect() collectgarbage("collect"); collectgarbage("collect"); return collectgarbage("count") end
	-- coût d'une région de la maquette
	local before = Collect()
	local probes = {}
	for i = 1, 200 do probes[i] = NewRegion("Frame") end
	local regionKb = (Collect() - before) / 200
	for _ = 1, 200 do table.remove(Mock.frames) end
	probes = nil
	ResetWorld()
	NS:DetectCapabilities()
	-- minuteries rangées par addon (celui qui les pose)
	local timers = {}
	_G.C_Timer.After = function(_, fn)
		local addon = Mock.currentAddon or "?"
		timers[addon] = timers[addon] or {}
		table.insert(timers[addon], fn)
	end
	local function ForAddon(addon, fn)
		local previous = Mock.currentAddon
		Mock.currentAddon = addon
		fn()
		Mock.currentAddon = previous
	end
	local function FireFor(addon, event, ...)
		local args = { ... }
		ForAddon(addon, function()
			for _, frame in ipairs(Mock.frames) do
				if frame.mockAddon == addon and frame.events and frame.events[event] and frame.script then
					frame.script(frame, event, unpack(args))
				end
			end
		end)
	end
	local function TimersFor(addon)
		ForAddon(addon, function()
			for _ = 1, 50 do
				local list = timers[addon]
				if not list or #list == 0 then break end
				timers[addon] = {}
				for _, fn in ipairs(list) do fn() end
			end
		end)
	end
	local function AdvanceFor(addon, seconds)
		Mock.now = Mock.now + seconds
		ForAddon(addon, function()
			for _, frame in ipairs(Mock.frames) do
				if frame.mockAddon == addon and frame.scripts and frame.scripts.OnUpdate then
					frame.scripts.OnUpdate(frame, seconds)
				end
			end
		end)
	end
	for _, addon in ipairs({ "Ready2Quest", "QuestCompanion" }) do
		local regions = #Mock.frames
		before = Collect()
		FireFor(addon, "ADDON_LOADED", addon)
		FireFor(addon, "PLAYER_LOGIN")
		FireFor(addon, "PLAYER_ENTERING_WORLD", true, false)
		for _ = 1, 20 do TimersFor(addon); AdvanceFor(addon, 0.5) end
		TimersFor(addon)
		local made = #Mock.frames - regions
		local kb = Collect() - before - made * regionKb
		if report then
			report[#report + 1] = { name = "Après connexion/" .. addon .. " (" .. made .. " régions créées)", kb = kb }
		end
	end
	-- les hauts faits construisent leur catalogue à la première lecture (index
	-- du moteur, quelques secondes après la connexion) : ce qu'il ajoute s'il
	-- n'est pas déjà construit
	if report and QNS.FeatDefs then
		before = Collect()
		QNS:FeatDefs()
		report[#report + 1] = { name = "Après connexion/QuestCompanion : catalogue des hauts faits (s'il manquait)",
			kb = Collect() - before }
	end
	return
end

----------------------------------------------------------------------------
-- 3 ter. Aperçu hors-jeu (tests/snapshot.py) : l'addon est chargé, on rend
-- une scène de tests/snapshot.lua en HTML et on s'arrête là, sans les tests.
----------------------------------------------------------------------------
if SNAPSHOT_SCENE then
	local function LoadModules()
		if Mock.modulesLoaded then return end
		Mock.modulesLoaded = true
		Mock.world.build = nil
		NS:DetectCapabilities()
		for _, file in ipairs(Mock.moduleFiles) do LoadAddonFile(file) end
		Mock:Fire("ADDON_LOADED", "Ready2Quest")
		Mock:Fire("ADDON_LOADED", "QuestCompanion")
	end
	ResetWorld()
	_G.T = { Check = Check, Say = Say, ResetWorld = ResetWorld, NS = NS, QNS = QNS, Mock = Mock, LoadModules = LoadModules }
	local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()
	_G.SNAPSHOT_RESULT = Snap.RunScene(SNAPSHOT_SCENE, SNAPSHOT_OUT, _G.T)
	_G.TEST_OUTPUT, _G.TEST_FAILED = _G.SNAPSHOT_RESULT, 0
	return
end

----------------------------------------------------------------------------
-- 4. Scénarios
----------------------------------------------------------------------------
-- Les scénarios du cœur forment une unité à part : le lanceur parallèle
-- (run_tests.py -j) les joue dans leur propre état Lua (RUN_CORE = false
-- pour les états qui ne jouent qu'un module).
if rawget(_G, "RUN_CORE") ~= false then
-- Scénarios du cœur de Ready2Quest. Couvrent : migrations des sauvegardes
-- (SacEtDepartDB -> ReadyToQuestDB -> Ready2QuestDB), apprentissage des zones
-- sûres (capitales, villages, indices, base livrée, camp, faction, instance),
-- alerte de sortie (délai, anti-spam, vol, mort, combat), les 13 checks et
-- leur score, commandes /sd /r2q, robustesse aux API absentes (templates,
-- quêtes, métiers, valeurs secrètes, événements non supportés), marchand
-- (vente et réparation auto), résumé de stuff, stats du portrait, mode
-- édition, réglages et fenêtre de diagnostic (un invariant par souci de mise
-- en page plutôt que des mesures), et les bugs signalés en jeu ([JEU]).
-- 4.1 Chargement
Say("== chargement ==")

-- Migration du renommage Sac & Départ -> Ready to Quest : une sauvegarde
-- existante sous l'ancien nom doit être reprise, sinon chaque joueur perdrait
-- ses zones sûres apprises et ses réglages au passage.
do
	ResetWorld()
	_G.SacEtDepartDB = { safe = { [1234] = true }, alertCooldown = 99, showWindow = false }
	NS._dbReady = false
	local migrated = NS:DB()
	-- v1.18.0 : les zones par mapID (schéma 1) sont purgées, pas reprises
	Check("migration : anciennes zones par mapID purgées, purge annoncée une fois",
		migrated.safe ~= nil and migrated.safe[1234] == nil and migrated.safeSchema == 2 and NS.safePurgeNotice == 1,
		migrated.safe and tostring(migrated.safe[1234]) .. " / " .. tostring(NS.safePurgeNotice))
	Check("migration : réglage conservé, nouveau nom, ancienne variable libérée", migrated.showWindow == false
		and _G.Ready2QuestDB == migrated and _G.SacEtDepartDB == nil, tostring(migrated.showWindow))

	-- v1.21.0 : Ready to Quest -> Ready2Quest (ReadyToQuestDB -> Ready2QuestDB)
	ResetWorld()
	_G.ReadyToQuestDB = { safeSchema = 2, safe = { ["v:30:Village"] = { kind = "village", name = "Village" } },
		popupScore = 70, optionsPage = "bags" }
	_G.SacEtDepartDB = { popupScore = 10 }
	NS._dbReady = false
	local migrated2 = NS:DB()
	Check("migration R2Q : la sauvegarde la plus récente gagne (réglages + villages)", migrated2.popupScore == 70
		and migrated2.safe["v:30:Village"] ~= nil and NS.migratedFrom == "ReadyToQuestDB",
		tostring(migrated2.popupScore) .. " / " .. tostring(NS.migratedFrom))
	Check("migration R2Q : anciennes variables libérées, nouvelle posée", _G.ReadyToQuestDB == nil
		and _G.SacEtDepartDB == nil and _G.Ready2QuestDB == migrated2)

	-- sans ancienne sauvegarde, une table neuve avec les défauts
	ResetWorld()
	NS._dbReady = false
	local fresh = NS:DB()
	Check("installation neuve : défauts posés, pas d'annonce de purge", fresh.showWindow == true
		and NS.safePurgeNotice == nil, tostring(fresh.showWindow))
end
Check("13 checks enregistrés", #(NS.checks or {}) == 13, NS.checks and #NS.checks)
Check("commande /sd enregistrée", type(SlashCmdList["SACETDEPART"]) == "function")
Check("événement PLAYER_UPDATE_RESTING écouté", NS.eventFrame and NS.eventFrame.events.PLAYER_UPDATE_RESTING == true)

-- 4.2 Entrée en capitale : repos dans deux quartiers -> carte entière apprise
Say("\n== capitale et repos ==")
ResetWorld()
Mock.world.resting = true
Mock.world.subzone = "Quartier commerçant"
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Check("entrée en capitale : zone sûre, un seul quartier ne l'apprend pas", NS.inSafe == true
	and NS:DB().safe["c:1"] == nil, tostring(NS.inSafe))
Mock.world.subzone = "Vieille ville"
Mock:Fire("ZONE_CHANGED")
do
	local city = NS:DB().safe["c:1"]
	Check("capitale apprise après deux quartiers en repos (source repos, kind city)", city ~= nil
		and city.source == "resting" and city.kind == "city", city and city.source)
end
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
do
	local waiting = NS.lastResults == nil and NS.pendingExit ~= nil
	Mock:Advance(3)
	Check("sortie : rien avant le délai (0 et 3 s), en attente de confirmation", waiting and NS.lastResults == nil)
end
Mock:Advance(3)
Check("alerte à la sortie (6 s), état non-sûr, départ = Capitale", NS.lastResults ~= nil and NS.inSafe == false
	and NS.lastDeparture and NS.lastDeparture.name == "Capitale", NS.lastDeparture and NS.lastDeparture.name)
do
	local restResult, questResult = Result("rest"), Result("quests")
	Check("repos en échec (0 repos), quête prête détectée", restResult and restResult.ok == false
		and questResult and questResult.ok == false and questResult.detail:find("1") ~= nil,
		questResult and questResult.detail)
end

-- 4.4 Sacs presque pleins + objets gris
Say("\n== sacs et butin ==")
ResetWorld()
for i = 1, 13 do
	Mock.world.bags[0].items[i] = { itemID = 2000 + i, stackCount = 1, quality = 1 }
end
Mock.world.bags[0].items[14] = { itemID = 3001, stackCount = 1, quality = 0 }
Mock.world.itemInfo[3001] = { name = "Croc cassé", quality = 0, classID = 15, subClassID = 0 }
NS:RunChecklist("manual")
do
	local bagsResult, grayResult = Result("bags"), Result("gray")
	Check("sacs presque pleins et objet gris signalés", bagsResult and bagsResult.ok == false
		and grayResult and grayResult.ok == false, bagsResult and bagsResult.detail)
end

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
do
	local vivresResult = Result("vivres")
	Check("vivres détectés (10 unités)", vivresResult and vivresResult.ok == true and vivresResult.detail:find("10") ~= nil,
		vivresResult and vivresResult.detail)
end
NS:DB().potionsThreshold = 3
NS:RunChecklist("manual")
do
	local potionsResult = Result("potions")
	Check("potions sous le seuil signalées", potionsResult and potionsResult.ok == false, potionsResult and potionsResult.detail)
end

-- 4.6 Durabilité
Say("\n== durabilité ==")
ResetWorld()
Mock.world.durability[5] = { 10, 100 }
NS:RunChecklist("manual")
do
	local duraResult = Result("durability")
	Check("durabilité basse signalée (10 %)", duraResult and duraResult.ok == false and duraResult.detail:find("10") ~= nil,
		duraResult and duraResult.detail)
end

-- 4.7 Apprentissage et contrôle des buffs
Say("\n== buffs ==")
ResetWorld()
Mock.world.classToken = "MAGE"   -- 1.30.1 : un buff de classe ne se réclame qu'à sa classe
Mock.world.auras = { [1459] = { name = "Intelligence des arcanes", duration = 3600, sourceUnit = "player" } }
Mock.world.auraOrder = { 1459 }
Mock:Fire("UNIT_AURA", "player")
Check("buff appris depuis l'aura, avec son nom", NS:DB().buffs[1459] ~= nil
	and NS:DB().buffs[1459].name == "Intelligence des arcanes")
Mock.world.auras = {}
Mock.world.auraOrder = {}
NS:RunChecklist("manual")
do
	local buffResult = Result("buffs")
	Check("buff manquant signalé et nommé", buffResult and buffResult.ok == false
		and buffResult.detail:find("Intelligence") ~= nil, buffResult and buffResult.detail)
end

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
do
	local secretResult = Result("buffs")
	Check("aura secrète -> pas d'alerte", secretResult and secretResult.ok == true, secretResult and secretResult.detail)
end
Mock.secretAuras = false

-- 4.10 Village sans repos : deux indices faibles de types différents
Say("\n== village sans repos (indices) ==")
ResetWorld()
Mock.world.mapID = 30
Mock.world.subzone = "Comté-de-l'Or"
Mock.world.resting = false
Mock:Fire("MERCHANT_SHOW")
do
	local key = "v:30:Comté-de-l'Or"
	local oneClue = NS:DB().safe[key] == nil and NS:DB().safeClues[key] and NS:DB().safeClues[key].types.merchant == true
	Mock:Fire("MERCHANT_SHOW")
	Check("un marchand (même deux fois) ne suffit pas, l'indice est mémorisé", oneClue and NS:DB().safe[key] == nil)
	Mock:Fire("QUEST_DETAIL")
	Check("village appris : marchand + quête, indices effacés, zone sûre", NS:DB().safe[key] ~= nil
		and NS:DB().safe[key].source == "merchant+quest" and NS:DB().safeClues[key] == nil and NS.inSafe == true,
		NS:DB().safe[key] and NS:DB().safe[key].source)
end
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
Check("alerte à la sortie du village (même carte), parti de Comté-de-l'Or (marchand + quête)", NS.lastResults ~= nil
	and NS:DepartedText() ~= nil and NS:DepartedText():find("Comté") ~= nil
	and NS:DepartedText():find("marchand %+ quête") ~= nil, NS:DepartedText())

-- les indices persistent d'une session à l'autre (dans la SavedVariable)
ResetWorld()
Mock.world.mapID = 30
Mock.world.subzone = "Long-guet"
Mock:Fire("TRAINER_SHOW")
do
	local saved = _G.Ready2QuestDB
	NS._dbReady = false
	_G.Ready2QuestDB = saved
end
Mock:Fire("MERCHANT_SHOW")
Check("indices persistés : entraîneur + marchand", NS:DB().safe["v:30:Long-guet"] ~= nil)

-- 4.11 Indices forts : un seul suffit
Say("\n== indices forts ==")
do
	local bad = {}
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
		if not (entry ~= nil and entry.source == case.source) then bad[#bad + 1] = case.event end
	end
	Check("indices forts (courrier, aubergiste, taxi, banque) : village appris", #bad == 0, table.concat(bad, ", "))
end
ResetWorld()
Mock.world.mapID = 30
Mock.world.subzone = "Village"
Mock.world.resting = true
Mock:Fire("PLAYER_UPDATE_RESTING")
-- v1.22.0 : le repos seul n'apprend plus (feux de camp de Forever)
do
	local restAlone = NS:DB().safe["v:30:Village"] == nil
	Mock:Fire("MERCHANT_SHOW"); Mock:Fire("MERCHANT_CLOSED")
	local entry = NS:DB().safe["v:30:Village"]
	Check("repos seul : rien appris ; repos + marchand : village appris", restAlone and entry ~= nil
		and entry.source == "merchant+resting", entry and entry.source)
end
ResetWorld()
Mock.world.mapID = 30
Mock.world.subzone = nil
Mock:Fire("MAIL_SHOW")
Check("sans sous-zone : rien n'est appris", next(NS:DB().safe) == nil)

-- GetRestState = XP de repos en réserve, PAS une zone de repos
ResetWorld()
Mock.world.mapID = 20
Mock.world.restStateRested = true
Check("bonus de repos en réserve : pas une zone sûre", NS:IsCurrentZoneSafe() == false)

-- 4.12 Anti-spam, retour avant le délai, vol, mort, délai réglable
Say("\n== sortie : anti-spam, retour, vol, mort ==")
do
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
	local first = NS.lastAlert ~= nil
	Mock.world.subzone = "Village"
	Mock:Fire("ZONE_CHANGED")
	Mock.now = Mock.now + 1
	NS.lastResults = nil
	LeaveVillage()
	Mock:Advance(6)
	Check("anti-spam : une alerte, pas de seconde dans la fenêtre de cooldown", first and NS.lastResults == nil)

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
	local restarted = NS.lastResults == nil
	Mock:Advance(6)
	Check("atterrissage hors zone sûre : le délai repart, puis alerte", restarted and NS.lastResults ~= nil)

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
	local immediate = NS.lastResults ~= nil
	EnterVillage()
	NS:DB().exitDelay = 99
	Check("délai 0 : alerte immédiate ; délai borné à 15 s", immediate and NS:ExitDelay() == 15, NS:ExitDelay())

	ResetWorld()
	NS:DB().safe["v:30:Village"] = { kind = "village", name = "Village", mapID = 30, subzone = "Village", source = "manual" }
	Mock.world.mapID = 30
	Mock.world.subzone = "Village"
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock.now = Mock.now + 5
	LeaveVillage()
	Mock:Advance(6)
	Check("silence après connexion conservé", NS.lastResults == nil)
end

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
Check("sous-carte d'une capitale = sûre", NS:IsCurrentZoneSafe() == true)

-- 4.15 Commandes
Say("\n== commandes ==")
ResetWorld()
Mock.world.mapID = 30
Mock.world.subzone = "Village"
NS:HandleCommand("safe")
do
	local marked = NS:DB().safe["v:30:Village"] ~= nil and NS:DB().safe["v:30:Village"].source == "manual"
	NS:HandleCommand("unsafe")
	Check("/sd safe marque le village, /sd unsafe le retire", marked and NS:DB().safe["v:30:Village"] == nil)
end
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
do
	NS:HandleCommand("seuil 8")
	local threshold = NS:DB().bagFreeThreshold == 8
	NS:HandleCommand("off")
	local off = NS:DB().enabled == false
	NS:HandleCommand("on")
	Check("/sd seuil, off, on", threshold and off and NS:DB().enabled == true)
end
NS:HandleCommand("list")
NS:HandleCommand("buffs")
NS:HandleCommand("diag")
Check("/sd list, buffs, diag s'exécutent", Mock:Output():find("Zones sûres connues") ~= nil
	and Mock:Output():find("Buffs suivis") ~= nil and Mock:Output():find("Diagnostic") ~= nil)
do
	-- sondes des points encore incertains sur Forever (affichées par /diag)
	local savedBook, savedAura = rawget(_G, "C_SpellBook"), rawget(_G, "UnitAura")
	local savedEnum = rawget(_G, "Enum")
	_G.C_SpellBook = { GetSpellBookItemInfo = function() end }
	_G.UnitAura = nil
	NS:DetectCapabilities()
	local incomplete = NS.Caps.spellbookModern == false
	_G.C_SpellBook.GetNumSpellBookSkillLines = function() return 0 end
	_G.Enum = { SpellBookSpellBank = { Player = 0 } }
	NS:DetectCapabilities()
	Check("/diag : spellbookModern faux sans GetNumSpellBookSkillLines, vrai avec", incomplete
		and NS.Caps.spellbookModern == true)
	_G.Enum = savedEnum
	Check("/diag : sondes unitAuraLegacy, itemInfoGlobal et specialization", NS.Caps.unitAuraLegacy == false
		and NS.Caps.itemInfoGlobal == true and NS.Caps.specialization == true)
	Mock:Reset()
	NS:PrintCapabilities()
	local out = Mock:Output()
	local unlisted = {}
	for _, key in ipairs({ "spellbookModern", "unitAuraLegacy", "itemInfoGlobal", "specialization" }) do
		if out:find(key, 1, true) == nil then unlisted[#unlisted + 1] = key end
	end
	for _, key in ipairs({ "vignettes", "tooltipData", "mapLevels", "lfgDungeons", "questsOnMap",
		"settingsPanel", "addonCompartment", "itemAsync", "modelAnimation" }) do
		if out:find(key, 1, true) == nil or type(NS.Caps[key]) ~= "boolean" then unlisted[#unlisted + 1] = key end
	end
	Check("/diag : chaque sonde listée (booléenne)", #unlisted == 0, table.concat(unlisted, ", "))
	do
		local savedVig = rawget(_G, "C_VignetteInfo")
		_G.C_VignetteInfo = { GetVignettes = function() return {} end, GetVignetteInfo = function() end }
		NS:DetectCapabilities()
		local present = NS.Caps.vignettes == true
		_G.C_VignetteInfo = nil
		NS:DetectCapabilities()
		Check("/diag : sonde vignettes suit C_VignetteInfo", present and NS.Caps.vignettes == false)
		_G.C_VignetteInfo = savedVig
	end
	Check("/diag : plus de sonde historique", out:find("craftLegacy", 1, true) == nil
		and out:find("questlogLegacy", 1, true) == nil and out:find("tradeskillLegacy", 1, true) == nil, out)
	_G.C_SpellBook, _G.UnitAura = savedBook, savedAura
	NS:DetectCapabilities()
end
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
do
	local reagentResult = Result("reagents")
	Check("recette bloquée : composant manquant nommé, déficit 10 - 4 = 6", reagentResult and reagentResult.ok == false
		and reagentResult.detail:find("Etoffe de lin") ~= nil and reagentResult.detail:find("6") ~= nil,
		reagentResult and reagentResult.detail)
end

-- 4.17 Toutes les recettes fabricables
Say("\n== recettes fabricables ==")
Mock.world.craftableCounts = { [1001] = 3, [1002] = 1 }
NS:InvalidateReagents()
NS:RunChecklist("manual")
Check("toutes fabricables -> OK", Result("reagents") and Result("reagents").ok == true, Result("reagents") and Result("reagents").detail)

-- 4.18 Aucune recette suivie
Say("\n== aucune recette suivie ==")
ResetWorld()
NS:RunChecklist("manual")
Check("aucune recette suivie -> OK", Result("reagents") and Result("reagents").ok == true, Result("reagents") and Result("reagents").detail)

-- 4.19 API métier indisponible : pas de plantage
Say("\n== API métier indisponible ==")
ResetWorld()
Mock.world.trackedUnavailable = true
NS:InvalidateReagents()
NS:RunChecklist("manual")
Check("API métier en erreur -> OK sans plantage", Result("reagents") and Result("reagents").ok == true,
	Result("reagents") and Result("reagents").detail)

-- 4.20 Invalidation du cache sur TRACKED_RECIPE_UPDATE
Say("\n== cache des composants ==")
ResetWorld()
Mock.world.trackedRecipes = { 1001 }
Mock.world.craftableCounts = { [1001] = 0 }
Mock.world.recipeSchematics = { [1001] = { name = "Potion de soin", reagentSlotSchematics = {} } }
NS:InvalidateReagents()
NS:RunChecklist("manual")
do
	local blocked = Result("reagents") and Result("reagents").ok == false
	Mock.world.craftableCounts = { [1001] = 5 }
	Mock.world.recipeSchematics = { [1001] = { name = "Potion de soin", reagentSlotSchematics = {} } }
	Mock:Fire("TRACKED_RECIPE_UPDATE")
	NS:RunChecklist("manual")
	Check("cache invalidé par TRACKED_RECIPE_UPDATE (bloquée puis OK)", blocked
		and Result("reagents") and Result("reagents").ok == true, Result("reagents") and Result("reagents").detail)
end

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
NS:RefreshOptions()   -- sans panneau : ne doit pas planter
NS:HandleCommand("options")
-- 1.34.0 : + la carte Quest Companion (page Général)
Check("panneau créé et affiché : 33 lignes (17 réglages + 3 actions + 13 contrôles)", NS.optionsFrame
	and NS.optionsFrame.shown == true and #NS.optionsFrame.rows == 33, NS.optionsFrame and #NS.optionsFrame.rows)
do
	-- on repère les lignes par leur clé : l'ordre du panneau peut évoluer
	local boolRow, numberRow
	for _, row in ipairs(NS.optionsFrame.rows) do
		if row.def and row.def.key == "showWindow" then boolRow = row end
		if row.def and row.def.key == "bagFreeThreshold" then numberRow = row end
	end
	local boolBefore = NS:DB().showWindow
	boolRow:Click()
	local flipped = NS:DB().showWindow ~= boolBefore
	boolRow:Click()
	Check("clic bascule un booléen, second clic rebascule", flipped and NS:DB().showWindow == boolBefore)
	local numberBefore = NS:DB().bagFreeThreshold
	numberRow:Step(1)
	local plus = NS:DB().bagFreeThreshold == numberBefore + 1
	numberRow:Step(-1)
	Check("seuil : + incrémente, - décrémente", plus and NS:DB().bagFreeThreshold == numberBefore, NS:DB().bagFreeThreshold)
	NS:RefreshOptions()
	Check("valeur affichée après rafraîchissement",
		numberRow.value and numberRow.value.text:find(tostring(numberBefore)) ~= nil, numberRow.value and numberRow.value.text)
end
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
Check("monde idéal -> score haut, bilan vert", NS.score >= 85 and select(2, NS:ScoreLabel()) == "green", NS.score)

ResetWorld()
NS:RunChecklist("manual")
Check("monde dégradé -> score moyen, conseils générés", NS.score < 85 and #(NS.lastAdvice or {}) > 0, NS.score)

ResetWorld()
Mock.world.bags[0].items = {}
for i = 1, 16 do Mock.world.bags[0].items[i] = { itemID = 900 + i, stackCount = 1, quality = 0 } end
Mock.world.bags[1] = { size = 16, items = {} }
for i = 1, 16 do Mock.world.bags[1].items[i] = { itemID = 950 + i, stackCount = 1, quality = 1 } end
Mock.world.durability[1] = { 10, 100 }
NS:RunChecklist("manual")
Check("monde catastrophique -> score bas, bilan rouge", NS.score < 60 and select(2, NS:ScoreLabel()) == "red", NS.score)

-- 4.26 Fenêtre de diagnostic en DA WoW
Say("\n== fenêtre de diagnostic ==")
ResetWorld()
NS:RunChecklist("manual")
-- 1.32.0 : 13 lignes de modules, plus celle du repli des points en ordre
Check("fenêtre créée et affichée : 13 lignes de modules (+ repli)", NS.window ~= nil and NS.window.shown == true
	and #NS.window.rows == 14, NS.window and #NS.window.rows)
Check("note, barre remplie et verdict affichés", NS.window.scoreValue.text:find(tostring(NS.score)) ~= nil
	and NS.window.scoreBar.fill.width > 0 and NS.window.verdict and NS.window.verdict.text ~= "",
	NS.window.scoreValue.text)
Check("ligne de module : détail et losange de statut", NS.window.rows[1].detail.text ~= ""
	and NS.window.rows[1].status and NS.window.rows[1].status.clientRole ~= nil, NS.window.rows[1].detail.text)

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
-- un bouton pointait encore vers L.OPT_STUFF_SHORT, supprimé avec le panneau :
-- il affichait la clé brute "OPT_STUFF_SHORT" et appelait une fonction absente
Check("panneau de stuff retiré : ni fonctions, ni cadre, ni bouton, ni réglage", NS.EnsureStuff == nil
	and NS.ShowStuff == nil and NS.ToggleStuff == nil and NS.stuffFrame == nil
	and (NS.window == nil or NS.window.stuffButton == nil) and NS:DB().showStuff == nil)

-- garde-fou général : toute clé utilisée par le code doit être traduite
-- (L renvoie la clé brute quand elle manque : c'est ce qui affichait
-- "OPT_STUFF_SHORT" à l'écran, on vérifie donc la résolution)
do
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
end
Check("niveau d'objet moyen toujours calculé", NS:AverageItemLevel() == 41, NS:AverageItemLevel())

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

Check("quitter la zone sûre lance le check et ouvre la fenêtre", NS.lastResults ~= nil
	and NS.window ~= nil and NS.window.shown == true, NS.window and tostring(NS.window.shown))

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
	local adv = win.adventureButton
	local probe = win:CreateFontString(nil, "OVERLAY")
	probe:SetText(NS.L.DIAG_ADVENTURE)
	Check("pied : seul « Partir à l'aventure », bleu de nuit, centré, texte qui tient", diag ~= nil
		and win.runButton == nil and win.optionsButton == nil
		and adv ~= nil and adv:GetText() == NS.L.DIAG_ADVENTURE and adv.style == "adventure"
		and adv.bg.vertex[3] > 0.8 and adv.bg.vertex[1] < 0.4 and adv:GetPoint() == "BOTTOM"
		and (adv:GetWidth() or 0) >= probe:GetStringWidth() and (adv:GetWidth() or 0) <= diag.width - 28,
		adv and adv:GetText())
	local c = adv.text.textColor or {}
	-- socle 2.11.0 : encre sombre (le blanc tombait à 3,31:1 sur le bleu)
	Check("pied : texte sombre, lisible sur le bleu (≥ 4,5:1)", NS.Theme.Contrast({ c[1] or 1, c[2] or 1, c[3] or 1 }, NS.Theme.BLUE) >= 4.5)
	-- boutons ambre pleins : encre sombre sans ombre noire. « Terminé » des
	-- réglages est en contour ambre (docs/UI.md, pied)
	local done = NS:EnsureOptions().closeButton
	local amber = done.text.textColor or {}
	local close = NS.Theme.CreateButton(win, 100, 28, "Fermer", nil, "primary")
	local ink, off, shadow = close.text.textColor or {}, close.text.shadowOffset or {}, close.text.shadow or {}
	Check("boutons ambre : encre sombre sans l'ombre noire (illisible) ; « Terminé » en contour ambre",
		close.style == "primary" and (ink[1] or 1) < 0.2 and (ink[3] or 1) < 0.2
		and off[1] == 0 and off[2] == 0 and (shadow[4] or 1) == 0
		and done.style == "accent" and (amber[1] or 0) > 0.85 and (amber[3] or 1) < 0.35)
	-- dernier conseil (bas de sa ligne, ~12) au-dessus du haut du bouton : au moins 8 d'écart
	local tight = {}
	for _, rows in ipairs({ 6, 13 }) do
		NS:LayoutWindow(win, rows, false)
		local _, _, _, _, y = win.adviceLines[#win.adviceLines]:GetPoint()
		local lineBottom = -y + 12
		local buttonTop = win:GetHeight() - 12 - adv:GetHeight()
		if buttonTop - lineBottom < 8 then tight[#tight + 1] = rows .. " lignes" end
	end
	Check("pied : le bouton ne colle pas au dernier conseil", #tight == 0, table.concat(tight, ", "))
	win:Show()
	adv:Click()
	Check("pied : « Partir à l'aventure » ferme la fenêtre", win:IsShown() == false)
	-- flèche de rafraîchissement
	local refresh = win.refreshButton
	local restAlpha = refresh.icon.alpha or 1
	refresh:GetScript("OnEnter")(refresh)
	Check("flèche : icône du jeu, discrète au repos, pleine au survol", refresh
		and tostring(refresh.icon.texture):find("UI%-RefreshButton") ~= nil and restAlpha < 1 and refresh.icon.alpha == 1,
		refresh and refresh.icon.texture)
	refresh:GetScript("OnLeave")(refresh)
	NS.lastResults, NS.score = nil, nil
	refresh:Click()
	Check("flèche : relance le check en tournant", NS.lastResults ~= nil and win:IsShown() == true
		and refresh.spin ~= nil and refresh.spin.plays >= 1)
	-- le sous-titre (« Parti de … ») s'arrête avant la flèche (à gauche du [×])
	-- et la roue crantée (à gauche de la flèche)
	local gear = win.settingsButton
	local refreshLeft = diag.width - 16 - win.close:GetWidth() - 8 - refresh:GetWidth()
	local gearLeft = refreshLeft - 6 - gear:GetWidth()
	local textRight = 1 + win.header.textLeft + win.subtitle:GetWidth()
	Check("en-tête : [×], flèche puis roue, sans toucher le « Parti de »",
		select(2, refresh:GetPoint()) == win.close and select(1, refresh:GetPoint()) == "RIGHT"
		and select(2, gear:GetPoint()) == refresh and select(1, gear:GetPoint()) == "RIGHT"
		and textRight <= gearLeft, textRight .. " <= " .. gearLeft)
	if NS.optionsFrame then NS.optionsFrame:Hide() end
	gear:Click()
	Check("roue : ouvre les réglages", NS.optionsFrame ~= nil and NS.optionsFrame:IsShown())
	NS.optionsFrame:Hide()
end

-- 4.31 Bouton sans template Blizzard
Say("\n== robustesse sans template ==")
ResetWorld()
Mock.world.noButtonTemplate = true
NS:RunChecklist("manual")
Check("panneau construit sans UIPanelButtonTemplate", NS.window ~= nil)
Mock.world.noButtonTemplate = false

-- 4.32 Commande /sd stuff : imprime le résumé en chat au lieu de piloter un panneau
Say("\n== commande stuff ==")
ResetWorld()
Mock:Reset()
NS:HandleCommand("stuff")
Check("/sd stuff répond en chat, sans panneau ni état à basculer", #Mock:Output() > 0
	and Mock:Output():find("Panneau") == nil and NS:DB().showStuff == nil, Mock:Output())

-- 4.33 API récentes manquantes (métiers, journal de quêtes, statistiques)
Say("\n== API récentes manquantes ==")
ResetWorld()
do
	local savedDelta = C_Item.GetItemStatDelta
	local savedStats = C_Item.GetItemStats
	local savedTrade = _G.C_TradeSkillUI
	local savedNumQuest = C_QuestLog.GetNumQuestLogEntries
	C_Item.GetItemStatDelta = nil
	C_Item.GetItemStats = nil
	_G.C_TradeSkillUI = nil
	C_QuestLog.GetNumQuestLogEntries = nil
	NS:DetectCapabilities()

	Check("sans API : capacités métiers et quêtes à false", NS.Caps.crafting == false and NS.Caps.quests == false)

	Mock.world.quests = { { questID = 11, title = "Un", ready = true }, { questID = 12, title = "Deux", ready = false } }
	Mock.world.rested = 3000
	Mock.world.bags[0].items[1] = { itemID = 4001, stackCount = 5, quality = 1 }
	Mock.world.itemInfo[4001] = { name = "Pain", classID = 0, subClassID = 5 }

	NS:RunChecklist("manual")
	local qClassic, rClassic = Result("quests"), Result("reagents")
	Check("checklist complète sans les API récentes (quêtes et composants OK)", NS.lastResults ~= nil
		and #NS.lastResults == 13 and qClassic and qClassic.ok == true and rClassic and rClassic.ok == true,
		NS.lastResults and #NS.lastResults)

	-- restauration
	C_Item.GetItemStatDelta = savedDelta
	C_Item.GetItemStats = savedStats
	_G.C_TradeSkillUI = savedTrade
	C_QuestLog.GetNumQuestLogEntries = savedNumQuest
	NS:DetectCapabilities()
	Check("API rétablies : capacités métiers et quêtes de retour", NS.Caps.crafting == true and NS.Caps.quests == true)
end

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
do
	local savedNum2 = C_QuestLog.GetNumQuestLogEntries
	C_QuestLog.GetNumQuestLogEntries = nil
	NS:RunChecklist("manual")
	local qNone = Result("quests")
	Check("quêtes sans API -> OK silencieux", qNone and qNone.ok == true, qNone and qNone.detail)
	C_QuestLog.GetNumQuestLogEntries = savedNum2
end

-- 4.36 Détection du client par numéro d'interface
Say("\n== détection du client ==")
ResetWorld()
do
	local wrong = {}
	if NS:ClientFlavour() ~= "Forever" then wrong[#wrong + 1] = "Forever:" .. tostring(NS:ClientFlavour()) end
	for _, case in ipairs({
		{ "Mists Classic", { version = "5.5.4", build = "69934", date = "Oct 2026", toc = 50504 } },
		{ "Classic Era", { version = "1.15.9", build = "69722", date = "Oct 2026", toc = 11509 } },
		{ "TBC Classic", { version = "2.5.6", build = "69795", date = "Oct 2026", toc = 20506 } },
		{ "Retail", { version = "12.1.5", build = "69900", date = "Oct 2026", toc = 120100 } },
	}) do
		Mock.world.build = case[2]
		if NS:ClientFlavour() ~= case[1] then wrong[#wrong + 1] = case[1] .. ":" .. tostring(NS:ClientFlavour()) end
	end
	Check("client détecté par l'interface (Forever, MoP, Era, TBC, Retail)", #wrong == 0, table.concat(wrong, ", "))
end
ResetWorld()

-- 4.37 Sans API métier : les événements optionnels ne sont pas tentés
Say("\n== événements optionnels ==")
ResetWorld()
do
	local sDelta, sTrade, sNum = C_Item.GetItemStatDelta, _G.C_TradeSkillUI, C_QuestLog.GetNumQuestLogEntries
	local sStats = C_Item.GetItemStats
	C_Item.GetItemStatDelta = nil
	C_Item.GetItemStats = nil
	_G.C_TradeSkillUI = nil
	C_QuestLog.GetNumQuestLogEntries = nil
	NS:DetectCapabilities()
	local probeOptional = NewRegion("Frame", "probeOptional")
	Mock.world.unknownEvents = { TRACKED_RECIPE_UPDATE = true }
	local skippedOptional = NS:RegisterEvents(probeOptional)
	Mock.world.unknownEvents = nil
	Check("sans API métier : TRACKED_RECIPE_UPDATE jamais tenté, événements de base enregistrés", #skippedOptional == 0
		and probeOptional.events.PLAYER_ENTERING_WORLD == true and probeOptional.events.MERCHANT_SHOW == true,
		table.concat(skippedOptional, ", "))
	C_Item.GetItemStatDelta = sDelta
	C_Item.GetItemStats = sStats
	_G.C_TradeSkillUI = sTrade
	C_QuestLog.GetNumQuestLogEntries = sNum
	NS:DetectCapabilities()
end
ResetWorld()

-- 4.38 Bootstrap : la commande survit à un échec de chargement
Say("\n== bootstrap et diagnostic ==")
ResetWorld()
Check("version exposée", NS.version == "1.34.0", NS.version)
do
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
	Check("/sd diag liste les modules et la version", Mock:Output():find("modules :") ~= nil
		and Mock:Output():find("1%.34%.0") ~= nil, Mock:Output())

	-- une erreur est enregistrée et affichée
	Mock:Reset()
	local before = #NS.errors
	NS:RecordError("test", "message de test")
	Check("erreur enregistrée et affichée dans le chat", #NS.errors == before + 1
		and Mock:Output():find("message de test") ~= nil, Mock:Output())

	-- une erreur de check ne fait pas tomber la checklist
	ResetWorld()
	local savedChecks = NS.checks
	NS.checks = {
		{ id = "boom", weight = 10, label = function() return "Boom" end, run = function() error("boum") end },
		{ id = "ok", weight = 90, label = function() return "Ok" end, run = function() return true, "bien", 100 end },
	}
	NS:RunChecklist("manual")
	Check("check en erreur isolé et enregistré", NS.lastResults and #NS.lastResults == 1 and #NS.errors > 0,
		NS.lastResults and #NS.lastResults)
	NS.checks = savedChecks
end

-- 4.39 Événement inconnu du client : l'addon doit survivre
Say("\n== événement non supporté ==")
ResetWorld()
Mock.world.unknownEvents = { TRACKED_RECIPE_UPDATE = true }
do
	local probe = NewRegion("Frame", "probe")
	local skipped = NS:RegisterEvents(probe)
	Check("événement inconnu ignoré, les autres enregistrés", #skipped == 1 and skipped[1] == "TRACKED_RECIPE_UPDATE"
		and probe.events.ZONE_CHANGED_NEW_AREA == true and probe.events.PLAYER_ENTERING_WORLD == true
		and probe.events.UNIT_AURA == true, table.concat(skipped, ", "))
	local lastError = (NS.errors[#NS.errors] or {}).message
	Check("erreur consignée et liste exposée pour /sd diag", lastError ~= nil
		and tostring(lastError):find("TRACKED_RECIPE_UPDATE") ~= nil
		and NS.unsupportedEvents and NS.unsupportedEvents[1] == "TRACKED_RECIPE_UPDATE", lastError)
end
-- la checklist fonctionne toujours sans cet événement
NS:RunChecklist("manual")
Check("checklist OK malgré l'événement manquant", NS.lastResults ~= nil and #NS.lastResults == 13)
Mock.world.unknownEvents = nil

-- 4.44 Lanceur sur la minicarte (référence LibDBIcon)
Say("\n== bouton de minicarte ==")
ResetWorld()
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
do
	local lancer = NS.minimapButton
	Check("bouton créé, affiché, posé sur l'anneau", lancer ~= nil and lancer.shown == true and #lancer.points > 0)
	Check("bouton 31x31, niveau 8, surbrillance native", lancer.width == 31 and lancer.height == 31
		and lancer.level == 8 and lancer.highlightTexture == 136477, lancer.width .. "x" .. lancer.height)
	-- Forever (interface 16001) : chrome mainline, textures du client
	Check("chrome mainline sur Forever : liseré et pastille du client, boussole de la marque",
		lancer.artStyle == "mainline" and lancer.bg.texture == 136430 and lancer.plate.texture == 136467
		and tostring(lancer.icon.texture):find("Textures\\logo") ~= nil, lancer.artStyle)

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
	Check("glissement : angle mis à jour, drapeau posé", math.abs(NS:DB().minimapAngle or 999) < 1
		and NS.minimapDragMoved == true, NS:DB().minimapAngle)

	NS.optionsFrame:Hide()
	lancer:Click("RightButton")
	Check("clic ignoré juste après un glissement", NS.optionsFrame.shown == false)

	-- infobulle
	if lancer.scripts and lancer.scripts.OnEnter then lancer.scripts.OnEnter(lancer) end
	local tipShown, tipLines = GameTooltip.shown == true, GameTooltip.lines and #GameTooltip.lines or 0
	if lancer.scripts and lancer.scripts.OnLeave then lancer.scripts.OnLeave(lancer) end
	Check("infobulle : liste les actions, masquée à la sortie", tipShown and tipLines >= 3
		and GameTooltip.shown == false, tipLines)

	-- commande
	Mock:Reset()
	NS:HandleCommand("minimap off")
	local hidden = lancer.shown == false and NS:DB().showMinimap == false and Mock:Output():find("masqué") ~= nil
	NS:HandleCommand("minimap on")
	Check("/sd minimap off masque (avec message), on réaffiche", hidden and lancer.shown == true
		and NS:DB().showMinimap == true, Mock:Output())

	-- réglage depuis le panneau d'options
	NS:ToggleOptions()
	local minimapRow
	for _, row in ipairs(NS.optionsFrame.rows) do
		if row.def and row.def.key == "showMinimap" then minimapRow = row end
	end
	minimapRow:Click()
	local unchecked = lancer.shown == false
	minimapRow:Click()
	Check("ligne des réglages : décocher masque, recocher réaffiche", unchecked and lancer.shown == true)

	-- Classic : chrome historique, même bouton
	ResetWorld()
	Mock.world.build = { version = "5.5.4", build = "69934", date = "Oct 2026", toc = 50504 }
	NS.minimapButton = nil
	local classic = NS:EnsureMinimapButton()
	Check("chrome Classic détecté, bouton toujours 31x31", classic.artStyle == "classic" and classic.width == 31, classic.artStyle)

	-- position : rayon = largeur/2 + 5 -> 75 px pour une minicarte de 140
	ResetWorld()
	NS.minimapButton = nil
	local placed = NS:EnsureMinimapButton()
	local point = placed.points[1]
	Check("rayon = 75 px (140/2 + 5)", point and math.abs(math.sqrt((point.x or 0) ^ 2 + (point.y or 0) ^ 2) - 75) < 1,
		point and math.sqrt((point.x or 0) ^ 2 + (point.y or 0) ^ 2))

	-- minicarte carrée : la formule diagonale s'applique sans erreur
	Mock.world.minimapShape = "SQUARE"
	NS:PositionMinimapButton()
	Check("forme carrée gérée", placed.points[1] ~= nil)
	Mock.world.minimapShape = "ROUND"
	ResetWorld()
end

-- 4.45 Activation / désactivation des modules
Say("\n== modules activables ==")
ResetWorld()
do
	local activeCount, totalCount = NS:EnabledModuleCount()
	Check("13 modules actifs au départ", NS:IsModuleEnabled("bags") == true and activeCount == 13 and totalCount == 13,
		activeCount .. "/" .. totalCount)

	-- score de référence, tous modules actifs
	Mock.world.rested = 0
	Mock.world.durability[1] = { 10, 100 }
	NS:RunChecklist("manual")
	local scoreAll = NS.score

	-- on désactive les sacs : la note doit monter, et le module sort du calcul
	NS:SetModuleEnabled("bags", false)
	NS:RunChecklist("manual")
	Check("module désactivé : marqué, poids nul, détail « désactivé »", Result("bags") and Result("bags").disabled == true
		and Result("bags").weight == 0 and Result("bags").detail == "désactivé", Result("bags") and Result("bags").detail)
	Check("note recalculée sans le module, compteur à 12", NS.score ~= scoreAll
		and select(1, NS:EnabledModuleCount()) == 12, scoreAll .. " -> " .. tostring(NS.score))

	-- tous désactivés : plus aucun poids -> score 0, pas de division par zéro
	for _, def in ipairs(NS.checks) do NS:SetModuleEnabled(def.id, false) end
	NS:RunChecklist("manual")
	Check("aucun module actif -> score 0, toujours 13 lignes", NS.score == 0 and #NS.lastResults == 13, NS.score)

	-- réactivation
	for _, def in ipairs(NS.checks) do NS:SetModuleEnabled(def.id, true) end
	NS:RunChecklist("manual")
	Check("réactivation rétablit la note", NS.score == scoreAll or NS.score ~= 0, NS.score)

	-- panneau : une ligne par module
	NS:ToggleOptions()
	local moduleRows, bagsRow = 0, nil
	for _, row in ipairs(NS.optionsFrame.rows) do
		if row.isModule then moduleRows = moduleRows + 1 end
		if row.isModule and row.moduleId == "bags" then bagsRow = row end
	end
	Check("13 interrupteurs de module dans le panneau", moduleRows == 13, moduleRows)
	bagsRow:Click()
	local offByClick = NS:IsModuleEnabled("bags") == false
	bagsRow:Click()
	Check("interrupteur : clic désactive, second clic réactive", offByClick and NS:IsModuleEnabled("bags") == true)

	-- commandes
	Mock:Reset()
	NS:HandleCommand("module vivres off")
	local moduleOff = NS:IsModuleEnabled("vivres") == false and Mock:Output():find("désactivé") ~= nil
	NS:HandleCommand("module vivres on")
	local moduleOn = NS:IsModuleEnabled("vivres") == true
	NS:HandleCommand("check vivres off")
	Check("/sd module vivres off (message) / on, /r2q check vivres off", moduleOff and moduleOn
		and NS:IsModuleEnabled("vivres") == false, Mock:Output())
	NS:HandleCommand("check vivres on")
	Mock:Reset()
	NS:HandleCommand("module inexistant off")
	NS:HandleCommand("check inexistant off")
	Check("module et contrôle inconnus signalés", Mock:Output():find("inconnu") ~= nil
		and Mock:Output():find("Contrôle inconnu") ~= nil, Mock:Output())
	Mock:Reset()
	NS:HandleCommand("modules")
	Check("/r2q modules : les 3 modules", Mock:Output():find("Check avant le départ") and Mock:Output():find("Résumé de stuff")
		and Mock:Output():find("Stats du portrait") and not Mock:Output():find("Vivres"), Mock:Output())
	Mock:Reset()
	NS:HandleCommand("checks")
	Check("/r2q checks : les 13 contrôles", Mock:Output():find("13") and Mock:Output():find("Vivres"), Mock:Output())
	NS:HandleCommand("module depart off")
	local departOff = NS:DB().departureEnabled == false
	NS:HandleCommand("module check on")
	local departOn = NS:DB().departureEnabled == true
	NS:HandleCommand("module stuff off")
	NS:HandleCommand("module portrait off")
	Check("/r2q module depart off, alias check on, stuff off, portrait off", departOff and departOn
		and NS:DB().showGearToast == false and NS:DB().showPortraitStats == false)
	NS:HandleCommand("module stuff on"); NS:HandleCommand("module portrait on")
	Mock:Reset()
	NS:HandleCommand("help")
	local helpOut = Mock:Output()
	Mock:Reset()
	NS:HandleCommand("aide")
	Check("/r2q help : aide classée (aide = help)", helpOut:find("Zones sûres") and helpOut:find("/r2q module <depart")
		and helpOut:find("/r2q diag") and Mock:Output() == helpOut, helpOut)
	Mock:Reset()
	NS:HandleCommand("nimportequoi")
	local _, unknownLines = Mock:Output():gsub("\n", "\n")
	Check("commande inconnue : une seule ligne vers l'aide", unknownLines == 0 and Mock:Output():find("/r2q help") ~= nil, Mock:Output())
end

-- un module désactivé ne génère pas de conseil
ResetWorld()
NS:SetModuleEnabled("vivres", false)
NS:RunChecklist("manual")
do
	local vivresAdvice = false
	for _, entry in ipairs(NS.lastAdvice or {}) do
		if entry.text == "Achète des vivres chez l'aubergiste." then vivresAdvice = true end
	end
	Check("module désactivé sans conseil", vivresAdvice == false)
end
NS:SetModuleEnabled("vivres", true)

-- 4.46 Une seule fenêtre à la fois + positions mémorisées
Say("\n== fenêtres exclusives ==")
ResetWorld()
NS:RunChecklist("manual")
Check("diagnostic affiché", NS.window and NS.window:IsShown() == true)
NS:ToggleOptions()
Check("ouvrir les réglages ferme le diagnostic", NS.window:IsShown() == false
	and NS.optionsFrame and NS.optionsFrame:IsShown() == true)
NS:RunChecklist("manual")
Check("relancer le check ferme les réglages et réaffiche le diagnostic", NS.optionsFrame:IsShown() == false
	and NS.window:IsShown() == true)

-- position du diagnostic mémorisée après déplacement : un ancrage valide
-- avec deux coordonnées numériques
ResetWorld()
NS:RunChecklist("manual")
NS.window:GetScript("OnDragStop")(NS.window)
do
	local diag = NS:DB().diagPoint
	Check("position du diagnostic enregistrée (point + coordonnées)", diag ~= nil and type(diag.point) == "string"
		and type(diag.x) == "number" and type(diag.y) == "number", diag and diag.point)
end

-- position des réglages mémorisée
NS:ToggleOptions()
NS.optionsFrame:GetScript("OnDragStop")(NS.optionsFrame)
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
do
	-- potions : seuil 0 par défaut -> inactif, poids nul
	NS:RunChecklist("manual")
	local potionsOff = Result("potions")
	Check("potions inactif par défaut : poids nul, « inactif (seuil à 0) »", potionsOff and potionsOff.disabled == true
		and potionsOff.weight == 0 and potionsOff.detail == "inactif (seuil à 0)", potionsOff and potionsOff.detail)
	local scoreZero = NS.score

	NS:DB().potionsThreshold = 5
	NS:RunChecklist("manual")
	Check("activer le seuil change la note", NS.score ~= scoreZero, scoreZero .. " -> " .. tostring(NS.score))

	-- seuil gris à 0 : plus d'alerte « 0 objet gris », ni de conseil
	ResetWorld()
	NS:DB().grayItemThreshold = 0
	NS:RunChecklist("manual")
	local grayOff = Result("gray")
	local grayAdvice = false
	for _, entry in ipairs(NS.lastAdvice or {}) do
		if entry.text == "Passe vendre ton butin gris." then grayAdvice = true end
	end
	Check("gris seuil 0 -> inactif, sans alerte ni conseil", grayOff and grayOff.disabled == true
		and grayOff.ok == true and grayAdvice == false, grayOff and grayOff.detail)

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
end
ResetWorld()

-- 4.49 Relevé de statistiques et formules
Say("\n== statistiques ==")
ResetWorld()
do
	local snap = NS:StatSnapshot()
	Check("statistiques lues (For, Agi, End, armure, dégâts, vitesse, ilvl)", snap.str == 25 and snap.agi == 14
		and snap.sta == 30 and snap.armor == 506 and snap.dmgMin == 20 and snap.dmgMax == 24
		and math.abs(snap.speed - 1.96) < 0.001 and snap.ilvl == 18,
		snap.str .. "/" .. snap.agi .. "/" .. snap.sta .. "/" .. snap.armor .. "/" .. snap.ilvl)
	-- formule de réduction : 506 / (506 + 85*11 + 400) = 27,5 %
	Check("réduction d'armure = 27,5 %", math.abs(snap.reduction - 27.48) < 0.1, snap.reduction)
	-- DPS = ((20+24)/2) / 1.96 = 11,2
	Check("DPS = 11,2", math.abs(snap.dps - 11.22) < 0.05, snap.dps)
end

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
-- l'emplacement est vide : seule l'icône du lien précédent peut le renseigner
Check("résumé affiché après retrait, avec l'icône de l'objet retiré", NS.toastFrame ~= nil
	and NS.toastFrame:IsShown() == true and NS.toastFrame.rows[1].icon.texture ~= nil
	and NS.toastFrame.rows[1].icon:IsShown() == true, NS.toastFrame and NS.toastFrame.rows[1].icon.texture)

-- 4.50 Résumé éphémère au changement de stuff
Say("\n== résumé de changement de stuff ==")
ResetWorld()
NS:CaptureStatBaseline()

-- le joueur équipe de meilleures mains : +40 armure, +2 dégâts, +0,04 s de vitesse
Mock.world.armor = 546
Mock.world.damage = { 22, 26 }
Mock.world.attackSpeed = 2.00
Mock.world.equipped[10] = "item:900"
Mock.world.links["item:900"] = { name = "Gantelets neufs", quality = 3, itemLevel = 24,
	equipLoc = "INVTYPE_HAND" }
NS:OnEquipmentChanged()

-- refonte 2026-11 : bandeau v2 (fond WINDOW, filet EDGE, liseré ambre), autour du
-- contenu : il déborde du cadre (hauteur 10) jusque sous la ligne ; aucune
-- bordure hors édition
do
	local toastScale = NS.toastFrame.rows[1].icon:GetWidth() / NS.TOAST_ICON
	Check("toast affiché : fond de bandeau sous le contenu, sans bordure hors édition", NS.toastFrame:IsShown() == true
		and NS.toastFrame.chrome == "toast" and NS.toastFrame.bg
		and NS.toastFrame.bg.vertex[1] == NS.Theme.WINDOW[1] and NS.toastFrame.border ~= nil
		and NS.toastFrame.bg.points[1].y > 0
		and NS.toastFrame.bg.points[2].y <= (NS.TOAST_ROW_TOP - 14) * toastScale
		and NS.toastFrame.moveGlow ~= nil and NS.toastFrame.moveGlow:IsShown() == false,
		tostring(NS.toastFrame.bg and NS.toastFrame.bg.points[2] and NS.toastFrame.bg.points[2].y))

	-- la vitesse qui diminue est une amélioration (polarité inversée)
	local beforeSnap = NS:StatSnapshot()
	Mock.world.attackSpeed = 1.60
	local afterSnap = NS:StatSnapshot()
	local speedRow
	for _, row in ipairs(NS:DiffSnapshots(beforeSnap, afterSnap)) do if row.key == "speed" then speedRow = row end end
	Check("vitesse : variation négative, polarité inversée", speedRow and speedRow.delta < 0
		and speedRow.polarity == false, speedRow and speedRow.delta)
	Mock.world.attackSpeed = 1.96
end

-- 4.51 Fondu et disparition
Say("\n== disparition du résumé ==")
NS.toastHideAt = 1000
NS:UpdateToast(1000.5)
do
	local before = NS.toastFrame:IsShown() == true
	NS:UpdateToast(1001.0)
	Check("visible avant le fondu, puis fondu en cours (alpha réduit)", before and NS.toastFrame:IsShown() == true
		and (NS.toastFrame.alpha or 1) < 1, NS.toastFrame.alpha)
end
NS:UpdateToast(1002.5)
Check("résumé masqué après le délai", NS.toastFrame:IsShown() == false)

-- 4.52 Panneau de stats au survol du portrait
Say("\n== stats du portrait ==")
ResetWorld()
NS:ShowPortraitStats()
Check("panneau de stats : classe, spé et niveau d'objet", NS.portraitFrame ~= nil and NS.portraitFrame:IsShown() == true
	and NS.portraitFrame.classLine.text:find("Guerrier") ~= nil and NS.portraitFrame.classLine.text:find("Armes") ~= nil
	and NS.portraitFrame.ilvlLine.text:find("18") ~= nil, NS.portraitFrame.classLine.text)

do
	local joined = {}
	for _, line in ipairs(NS.portraitFrame.lines) do
		joined[#joined + 1] = tostring(line.left.text) .. " " .. tostring(line.right.text)
	end
	local blob = table.concat(joined, " | ")
	-- Guerrier Armes : la priorité officielle s'arrête à Force et Agilité ;
	-- ni Endurance, ni Intelligence, ni Esprit (sans effet sur ses dégâts)
	Check("Guerrier Armes : Force, Agilité, Armure, DPS ; ni Endurance, ni Intelligence, ni Esprit",
		blob:find("Force") and blob:find("Agilité") and blob:find("Armure") and blob:find("DPS")
		and not blob:find("Endurance") and not blob:find("Intelligence") and not blob:find("Esprit"), blob)
	-- la mise en avant suit la classe et la spé, pas le maximum (l'ancienne
	-- règle soulignait l'Endurance, plus élevée)
	Check("Force mise en avant pour Guerrier/Armes, pas l'Endurance", blob:find("|cffe8a54bForce") ~= nil
		and blob:find("|cffe8a54bEndurance") == nil, blob)
end
NS:HidePortraitStats()

-- Intégrité de la table SPEC_STATS : les neuf classes, trois spécialisations
-- chacune, et uniquement des clés de statistiques connues. Une faute de
-- frappe dans une clé afficherait « nil » dans le panneau, en jeu.
do
	local validKeys = { STR = true, AGI = true, INT = true, SPI = true, STA = true }
	local classCount, specCount, badKeys = 0, 0, {}
	for classFile, bySpec in pairs(NS.SPEC_STATS) do
		classCount = classCount + 1
		if #bySpec ~= 3 then badKeys[#badKeys + 1] = classFile .. " : " .. #bySpec .. " spés" end
		for specIndex = 1, 3 do
			specCount = specCount + 1
			local list = bySpec[specIndex]
			if type(list) ~= "table" or #list == 0 then
				badKeys[#badKeys + 1] = classFile .. "/" .. specIndex .. " vide"
			else
				local seen = {}
				for _, key in ipairs(list) do
					if not validKeys[key] then
						badKeys[#badKeys + 1] = classFile .. "/" .. specIndex .. ":" .. tostring(key)
					end
					-- un doublon afficherait deux fois la même ligne
					if seen[key] then
						badKeys[#badKeys + 1] = classFile .. "/" .. specIndex .. " doublon " .. key
					end
					seen[key] = true
				end
				-- priorité officielle : jamais plus de cinq attributs
				if #list > 5 then
					badKeys[#badKeys + 1] = classFile .. "/" .. specIndex .. " trop long"
				end
			end
		end
	end
	Check("SPEC_STATS : 9 classes x 3 spés, sans clé inconnue, doublon ni liste trop longue",
		classCount == 9 and specCount == 27 and #badKeys == 0, classCount .. "/" .. specCount .. " " .. table.concat(badKeys, ", "))
end

-- La mise en avant suit la CLASSE et la SPÉCIALISATION, pas le maximum.
-- Voleur : l'Agilité ; Prêtre/Discipline : l'Intelligence ; Druide
-- Restauration : l'Esprit, sans Force ni Endurance soulignée.
do
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
	local priest = highlightFor("PRIEST", 1)
	local druid = highlightFor("DRUID", 3)
	Check("mise en avant par classe : Voleur Agilité, Prêtre Intelligence, Druide Resto pas l'Endurance",
		rogue:find("|cffe8a54bAgilité") ~= nil and priest:find("|cffe8a54bIntelligence") ~= nil
		and druid:find("|cffe8a54bEndurance") == nil, rogue .. " || " .. priest .. " || " .. druid)
	-- le panneau ne liste que le strict nécessaire
	Check("listes strictes : Voleur sans Esprit, Druide Resto avec Esprit sans Force, Prêtre avec Intelligence",
		rogue:find("Esprit") == nil and druid:find("Esprit") ~= nil and druid:find("Force") == nil
		and priest:find("Intelligence") ~= nil, rogue .. " || " .. druid)
end

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
Check("première stat : Vindicte Intelligence, Protection paladin Endurance, Démoniste Intelligence",
	firstStat("PALADIN", 3):find("Intelligence") ~= nil and firstStat("PALADIN", 2):find("Endurance") ~= nil
	and firstStat("WARLOCK", 1):find("Intelligence") ~= nil,
	firstStat("PALADIN", 3) .. " / " .. firstStat("PALADIN", 2) .. " / " .. firstStat("WARLOCK", 1))

-- Druide Farouche : ours et félin n'ont pas les mêmes priorités. L'ours
-- commence par l'Endurance, le félin par l'Agilité.
do
	local savedForm = _G.GetShapeshiftForm
	_G.GetShapeshiftForm = function() return 0 end
	local cat = firstStat("DRUID", 2)
	_G.GetShapeshiftForm = function() return 1 end
	local bear = firstStat("DRUID", 2)
	Check("Farouche : félin Agilité d'abord, ours Endurance d'abord", cat:find("Agilité") ~= nil
		and bear:find("Endurance") ~= nil, cat .. " / " .. bear)
	_G.GetShapeshiftForm = savedForm
end
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
NS:HandleCommand("portrait off")
Check("/sd toast off (message), /sd portrait off", NS:DB().showGearToast == false
	and Mock:Output():find("désactivé") ~= nil and NS:DB().showPortraitStats == false, Mock:Output())

-- 4.55 Verrouillage par défaut et mode édition
Say("\n== mode édition des cadres ==")
ResetWorld()
NS:ShowPortraitStats()
do
	local lockedPortrait = NS.portraitFrame.mouseEnabled == false and NS.editMode == nil
	NS:HidePortraitStats()
	Check("portrait verrouillé par défaut, hors édition, se masque normalement", lockedPortrait
		and NS.portraitFrame:IsShown() == false)
end

NS:CaptureStatBaseline()
Mock.world.armor = 700
Mock.world.equipped[10] = "item:910"
Mock.world.links["item:910"] = { name = "Gantelets", quality = 2, itemLevel = 22, equipLoc = "INVTYPE_HAND" }
NS:OnEquipmentChanged()
Check("résumé affiché après changement, verrouillé par défaut", NS.toastFrame ~= nil
	and NS.toastFrame:IsShown() == true and NS.toastFrame.mouseEnabled == false)

-- entrée en mode édition
Mock:Reset()
NS:ToggleEditMode()
Check("mode édition actif, annoncé", NS.editMode == true and Mock:Output():find("Mode édition") ~= nil, Mock:Output())
Check("édition : les deux cadres déverrouillés, visibles, avec leur lueur", NS.toastFrame.mouseEnabled == true
	and NS.portraitFrame.mouseEnabled == true and NS.toastFrame:IsShown() == true and NS.portraitFrame:IsShown() == true
	and NS.toastFrame.moveGlow:IsShown() == true and NS.portraitFrame.moveGlow:IsShown() == true)

-- le survol ne fait plus disparaître le cadre, le résumé ne s'efface pas
NS:HidePortraitStats()
NS.toastHideAt = 1000
NS:UpdateToast(3000)
Check("édition : ni masquage du portrait ni fondu du résumé", NS.portraitFrame:IsShown() == true
	and NS.toastFrame:IsShown() == true)

-- déplacement enregistré
do
	local toastDrag = NS.toastFrame:GetScript("OnDragStop")
	local portraitDrag = NS.portraitFrame:GetScript("OnDragStop")
	if toastDrag then toastDrag(NS.toastFrame) end
	if portraitDrag then portraitDrag(NS.portraitFrame) end
end
Check("déplacement enregistré : position du résumé, portrait en manuel", type(NS:DB().toastPoint.point) == "string"
	and NS:DB().portraitManual == true, NS:DB().toastPoint.point)

-- sortie du mode édition
Mock:Reset()
NS:StopEditMode()
Check("sortie d'édition : cadres reverrouillés, lueurs masquées, résumé masqué, message", NS.editMode == nil
	and NS.toastFrame.mouseEnabled == false and NS.portraitFrame.mouseEnabled == false
	and NS.toastFrame.moveGlow:IsShown() == false and NS.portraitFrame.moveGlow:IsShown() == false
	and NS.toastFrame:IsShown() == false and Mock:Output():find("terminé") ~= nil, Mock:Output())

-- édition possible même si les stats du portrait sont désactivées
ResetWorld()
NS:DB().showPortraitStats = false
NS:StartEditMode()
do
	local forced = NS.portraitFrame ~= nil and NS.portraitFrame:IsShown() == true
	NS:StopEditMode()
	Check("édition force l'affichage du portrait, qui redevient soumis au réglage ensuite", forced
		and NS.portraitFrame:IsShown() == false)
end

-- 4.56 Bouton « Déplacer les cadres »
Say("\n== bouton de déplacement ==")
ResetWorld()
NS:ToggleOptions()
do
	local editButton = NS.optionsFrame.editButton
	Check("bouton « Déplacer » présent", editButton ~= nil and tostring(editButton:GetText()):find("Déplacer") ~= nil,
		editButton and editButton:GetText())

	editButton:Click()
	Check("clic : mode édition, réglages refermés, bouton « Terminer »", NS.editMode == true
		and NS.optionsFrame:IsShown() == false and tostring(editButton:GetText()):find("Terminer") ~= nil,
		editButton:GetText())

	Mock:Reset()
	NS:HandleCommand("move stop")
	Check("/sd move stop termine, bouton redevenu normal", NS.editMode == nil
		and tostring(editButton:GetText()):find("Déplacer") ~= nil, editButton:GetText())
end

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
-- bandeau, on restait bloqué en édition. Il doit exister, porter le bouton
-- qui en sort, et survivre à toutes les actions possibles en édition.
NS:StartEditMode()
do
	local shownAtStart = NS.editBanner ~= nil and NS.editBanner:IsShown() == true and NS.editBanner.stopButton ~= nil
	NS:ShowPortraitStats()
	local afterPortrait = NS.editBanner ~= nil and NS.editBanner:IsShown() == true
	NS:OnEquipmentChanged()
	Check("bandeau d'édition : bouton de sortie, survit au portrait et au changement de stuff", shownAtStart
		and afterPortrait and NS.editBanner ~= nil and NS.editBanner:IsShown() == true)
end
NS:StopEditMode()
Check("sortie d'édition : bandeau masqué, cadres plus déplaçables", NS.editBanner ~= nil
	and NS.editBanner:IsShown() == false and (NS.toastFrame == nil or NS.toastFrame:IsShown() == false))

do -- portée locale (limite de 200 locales en Lua 5.1)
-- Géométrie de la fenêtre de réglages (refonte 2026-11, docs/UI.md) :
-- colonnes de cartes, pied, navigation, pages qu'on peut parcourir en entier.
-- Un invariant par souci (rien ne déborde, rien ne se chevauche) plutôt que
-- des mesures.
local lay = NS.OPT_LAYOUT
Check("géométrie des réglages cohérente : deux colonnes + écart = largeur utile, marges égales", lay ~= nil
	and lay.colWidth * 2 + lay.colGap <= lay.inner and lay.inner - (lay.colWidth * 2 + lay.colGap) <= 1
	and lay.margin * 2 + lay.inner == lay.contentWidth and lay.contentWidth + lay.navWidth + 2 == lay.width,
	lay and (lay.colWidth .. " x2 + " .. lay.colGap .. " / " .. lay.inner))

local frame = NS:EnsureOptions()
Check("panneau de réglages : taille fixe qui tient à l'écran, bouton de réinitialisation des cadres", frame ~= nil
	and frame.width == lay.width and frame.height == lay.height and frame.height <= lay.maxHeight
	and NS.optionsFrame.resetFramesButton ~= nil, frame and frame.height)
do
	-- une entrée par page ; une page à sous-pages devient un titre de groupe
	local navIds, heads = {}, {}
	for _, nav in ipairs(frame.navButtons) do navIds[#navIds + 1] = nav.pageId end
	for _, header in ipairs(frame.navHeaders) do heads[#heads + 1] = header.pageId end
	Check("navigation : une entrée par page, « départ » et « QoL » en titres de groupe", table.concat(navIds, ",")
		== "general,trigger,safe,bags,gear,buffs,toast,portrait,merchant" and table.concat(heads, ",") == "departure,qol",
		table.concat(navIds, ",") .. " / " .. table.concat(heads, ","))

	-- pied : action principale et remise à zéro à gauche, Terminé à droite,
	-- sans chevauchement, textes dans leurs boutons
	local run, reset, done = frame.runButton, frame.resetButton, frame.closeButton
	local rp, rx = select(1, run:GetPoint()), select(4, run:GetPoint())
	Check("pied : action et Réinitialiser à gauche en contour, Terminé à droite en ambre", rp == "LEFT"
		and rx == lay.margin and run.style == "outline" and reset.lastPoint.relTo == run and reset.lastPoint.x >= 8
		and reset.style == "outline" and done.lastPoint.point == "RIGHT" and done.lastPoint.x == -lay.margin
		and done.style == "accent" and done:GetText() == NS.L.OPT_DONE)
	local leftEnd = lay.margin + run:GetWidth() + reset.lastPoint.x + reset:GetWidth()
	local tooNarrow = {}
	for _, button in ipairs({ run, reset, done }) do
		if button.text:GetStringWidth() + 16 > button:GetWidth() then tooNarrow[#tooNarrow + 1] = button:GetText() end
	end
	if leftEnd + 16 > lay.contentWidth - lay.margin - done:GetWidth() then tooNarrow[#tooNarrow + 1] = "chevauchement" end
	Check("pied : boutons qui ne se touchent pas, textes qui tiennent", #tooNarrow == 0, table.concat(tooNarrow, ", "))

	-- tous les checks ont leur interrupteur, une seule fois, à leur page
	local seen, problems = {}, {}
	for _, row in ipairs(frame.rows) do
		if row.isModule then
			if seen[row.moduleId] then problems[#problems + 1] = row.moduleId .. " en double" end
			seen[row.moduleId] = true
		end
	end
	for _, def in ipairs(NS.checks) do
		if not seen[def.id] then problems[#problems + 1] = def.id .. " sans interrupteur" end
	end
	for _, id in ipairs(frame.unplaced) do problems[#problems + 1] = id .. " rangé dans Général" end
	Check("chaque module a son interrupteur, une fois, sur sa page", #problems == 0, table.concat(problems, ", "))

	-- contrôles alignés à droite des cartes ; libellés, valeurs + unités et
	-- entrées de navigation qui tiennent dans leur case
	local overflow = {}
	for _, row in ipairs(frame.rows) do
		local control = row.controlRegion
		local point, rel, _, x = control:GetPoint()
		if point ~= "RIGHT" or rel ~= row or x ~= -lay.cardPad then overflow[#overflow + 1] = "désaligné:" .. tostring(row.labelText) end
		if row.truncated or row.labelWidth > row.labelRoom then overflow[#overflow + 1] = tostring(row.labelText) end
		if row.slider then
			local def = row.def
			local text = tostring(def.max or 0) .. (def.suffix and (" " .. (NS.L[def.suffix] or "")) or "")
			row.slider.valueText:SetText(text)
			if row.slider.valueText:GetStringWidth() + 8 > row.slider.valueWidth then overflow[#overflow + 1] = def.key .. "=" .. text end
		end
	end
	NS:RefreshOptions()
	for _, nav in ipairs(frame.navButtons) do
		if nav.label:GetStringWidth() > nav.label.width then overflow[#overflow + 1] = "nav:" .. nav.label.text end
	end
	Check("réglages : contrôles alignés, aucun texte qui déborde", #overflow == 0, table.concat(overflow, ", "))

	-- chaque page : rien ne se chevauche, et tout se voit en défilant
	local overlaps, unreachable = {}, {}
	for id, page in pairs(frame.pages) do
		NS:SelectOptionsPage(id)
		local boxes = {}
		for _, item in ipairs(page.items) do
			local w = item.region:GetWidth()
			for _, other in ipairs(boxes) do
				if item.x < other.x + other.w and other.x < item.x + w and item.y < other.y + other.h and other.y < item.y + item.height then
					overlaps[#overlaps + 1] = id
				end
			end
			boxes[#boxes + 1] = { x = item.x, y = item.y, w = w, h = item.height }
			if item.x + w > lay.inner then overlaps[#overlaps + 1] = id .. ":débord" end
		end
		local reached = {}
		for _ = 1, #page.items + 2 do
			for index, item in ipairs(page.items) do if item.region:IsShown() then reached[index] = true end end
			NS:ScrollOptions(-1)
		end
		for index in ipairs(page.items) do
			if not reached[index] then unreachable[#unreachable + 1] = id .. "#" .. index end
		end
	end
	Check("options : aucun élément superposé ni hors des colonnes", #overlaps == 0, table.concat(overlaps, ", "))
	Check("options : chaque élément de chaque page se voit (défilement)", #unreachable == 0, table.concat(unreachable, ", "))
end

-- Navigation : une seule page visible, choix mémorisé, une entrée par sous-page
NS:SelectOptionsPage("bags")
local function NavFor(id)
	for _, nav in ipairs(frame.navButtons) do if nav.pageId == id then return nav end end
end
local function HeaderFor(id)
	for _, header in ipairs(frame.navHeaders) do if header.pageId == id then return header end end
end
do
	local visiblePages = 0
	for _, page in pairs(frame.pages) do if page:IsShown() then visiblePages = visiblePages + 1 end end
	Check("navigation : une seule page visible, mémorisée, sans onglets", visiblePages == 1 and frame.pages.bags:IsShown()
		and NS:DB().optionsPage == "bags" and not frame.tabs:IsShown(), visiblePages)
end
Check("navigation : en-tête de la page choisie, son entrée sélectionnée", frame.header.title.text == NS.L.OPT_PAGE_BAGS
	and frame.header.subtitle.text == NS.L.OPT_PAGE_BAGS_SUB and NavFor("bags").selected
	and not NavFor("general").selected and not NavFor("trigger").selected, frame.header.title.text)
NavFor("safe"):Click()
do
	local safeOk = frame.currentPage == "safe" and frame.pages.safe:IsShown()
	NavFor("general"):Click()
	Check("navigation : clics sur « Zones sûres » puis « Général »", safeOk and frame.currentPage == "general")
end
HeaderFor("departure"):Click()
do
	local headOk = frame.currentPage == "trigger" and frame.currentParent == "departure"
	NS:SelectOptionsPage("departure")
	local groupOk = frame.currentPage == "trigger"
	NS:SelectOptionsPage("nope")
	Check("navigation : un groupe ouvre sa première page, page inconnue -> Général", headOk and groupOk
		and frame.currentPage == "general", frame.currentPage)
end
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
Check("liste des zones : 13 entrées, 9 lignes visibles, défilement vers le bas seulement", #safeList.items == 13
	and safeList.lines[9]:IsShown() and safeList.lines[9].item ~= nil
	and safeList.down:IsShown() and not safeList.up:IsShown(), #safeList.items)
Check("liste des zones : source lisible", tostring(safeList.lines[1].detail.text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):find("capitale, repos") ~= nil,
	safeList.lines[1].detail.text)
safeList.down:Click()
do
	local oneDown = safeList.offset == 1 and safeList.up:IsShown()
	for _ = 1, 10 do safeList.down:Click() end
	Check("défilement : une ligne à la fois, borné en bas", oneDown and safeList.offset == 4, safeList.offset)
end
safeList.offset = 0
NS:RefreshOptions()
safeList.lines[1].action:Click()          -- « Capitale » : première par ordre alphabétique
Check("bouton Retirer : capitale oubliée, liste rafraîchie", NS:DB().safe["c:1"] == nil and NS:DB().cityRest[1] == nil
	and #safeList.items == 12, #safeList.items)
NS.optionsFrame.pages.safe.clearButton:Click()
Check("Tout effacer : liste vide, message affiché", next(NS:DB().safe) == nil and #safeList.items == 0
	and safeList.empty.text ~= "", safeList.empty.text)

-- Liste des buffs suivis : bascule et retrait
ResetWorld()
Mock.world.classToken = "MAGE"
NS:DB().buffs[1459] = { name = "Intelligence des arcanes", duration = 1800, enabled = true, self = true }
NS:DB().buffs[1126] = { name = "Marque du fauve", duration = 1800, enabled = true }
NS.optionsFrame = nil
NS:ToggleOptions()
NS:SelectOptionsPage("buffs")
local buffList = NS.optionsFrame.lists.buffs
Check("liste des buffs : 2 entrées", #buffList.items == 2, #buffList.items)
buffList.lines[1]:Click()
Check("clic sur un buff : coupé, affiché « non »", NS:DB().buffs[1459].enabled == false
	and tostring(buffList.lines[1].detail.text):find(NS.L.OPT_OFF) ~= nil, buffList.lines[1].detail.text)
buffList.lines[1]:Click()
Check("second clic : réactivé", NS:DB().buffs[1459].enabled == true)
buffList.lines[2].action:Click()
Check("bouton Retirer : buff oublié", NS:DB().buffs[1126] == nil and #buffList.items == 1)

end

-- Aucun caractère hors du répertoire de la police du client : "▶" (U+25B6)
-- s'affichait en losange de remplacement.
do
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
	Check("pas de glyphe triangle dans Options.lua ni Locales.lua", not HasHighGlyph("Ready2Quest/Options.lua")
		and not HasHighGlyph("Ready2Quest/Locales.lua"))

	-- la ligne « position du bouton » affiche l'angle courant
	local posRow
	for _, row in ipairs(NS.optionsFrame.rows) do
		if row.def and row.def.key == "minimapPos" then posRow = row end
	end
	Check("ligne de position du bouton : affiche l'angle (225)", posRow ~= nil
		and tostring(posRow.value.text):find("225") ~= nil, posRow and posRow.value.text)
end

-- 4.57 Repli des chaînes sans récursion (C stack overflow corrigé en 1.1.1)
Say("\n== repli des chaînes ==")
ResetWorld()
-- si __index se rappelait lui-même, ce test ferait exploser la pile
Check("clé existante résolue, clé absente renvoie son nom", NS.L.ADDON_NAME ~= nil and NS.L.ADDON_NAME ~= "ADDON_NAME"
	and NS.L["CLE_QUI_NEXISTE_PAS"] == "CLE_QUI_NEXISTE_PAS", tostring(NS.L.ADDON_NAME))
Check("aucune récursion sur 50 clés absentes", (function()
	local ok = pcall(function()
		for i = 1, 50 do
			local _ = NS.L["ABSENTE_" .. i]
		end
	end)
	return ok
end)() == true)
Check("ns:F formate une clé existante, tolère une clé absente", NS:F("MINIMAP_SCORE", 80, "PRÊT"):find("80") ~= nil
	and NS:F("CLE_ABSENTE") == "CLE_ABSENTE", NS:F("MINIMAP_SCORE", 80, "PRÊT"))

-- 4.58 Piège tonumber() avec des API à plusieurs retours
Say("\n== tonumber et retours multiples ==")
ResetWorld()
do
	local savedAP = _G.UnitAttackPower
	_G.UnitAttackPower = function() return 120, 0, 0, nil end
	local okAP, snapAP = pcall(function() return NS:StatSnapshot() end)
	Check("4e retour nil : pas de plantage, PA lue sur le 1er retour", okAP and snapAP.ap == 120, tostring(okAP and snapAP.ap or snapAP))

	local savedSpeed = _G.UnitAttackSpeed
	_G.UnitAttackSpeed = function() return 1.96, 1.50 end
	local okSpeed, snapSpeed = pcall(function() return NS:StatSnapshot() end)
	Check("2 retours de vitesse : pas de plantage, 1er retour lu", okSpeed and math.abs(snapSpeed.speed - 1.96) < 0.001,
		tostring(okSpeed and snapSpeed.speed or snapSpeed))

	local savedCrit = _G.GetCritChance
	_G.GetCritChance = function() return 12.5, 99 end
	local okCrit, snapCrit = pcall(function() return NS:StatSnapshot() end)
	Check("crit lue sans confusion de base", okCrit and snapCrit.crit == 12.5, okCrit and snapCrit.crit)

	_G.UnitAttackPower = savedAP
	_G.UnitAttackSpeed = savedSpeed
	_G.GetCritChance = savedCrit
end

-- 4.59 Rotation du bouton de minicarte
Say("\n== position du bouton de minicarte ==")
ResetWorld()
NS.minimapButton = nil
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Check("angle par défaut 225 degrés", math.abs((NS:DB().minimapAngle or 0) - 225) < 1, NS:DB().minimapAngle)
Mock:Reset()
NS:CycleMinimapAngle()
do
	local to270 = math.abs(NS:DB().minimapAngle - 270) < 1 and Mock:Output():find("270") ~= nil
	NS:CycleMinimapAngle()
	local to315 = math.abs(NS:DB().minimapAngle - 315) < 1
	NS:DB().minimapAngle = 180
	NS:CycleMinimapAngle()
	Check("rotation 225 -> 270 (annoncée) -> 315, bouclage vers 225", to270 and to315
		and math.abs(NS:DB().minimapAngle - 225) < 1, NS:DB().minimapAngle)
end

-- 4.61 Résumé éphémère sans cadre
Say("\n== résumé sans cadre ==")
ResetWorld()
NS:CaptureStatBaseline()
Mock.world.armor = 600
Mock.world.equipped[10] = "item:920"
Mock.world.links["item:920"] = { name = "Gantelets", quality = 2, itemLevel = 20, equipLoc = "INVTYPE_HEAD" }
NS:OnEquipmentChanged()

do
	local tframe = NS.toastFrame
	-- une seule ligne, par choix de conception : le bloc doit se lire d'un coup
	Check("bandeau : fond, liseré ambre, titre ombré, ni fermeture ni filet, une ligne", tframe.bg ~= nil
		and tframe.accent ~= nil and tframe.accent:IsShown() and tframe.title ~= nil and tframe.close == nil
		and tframe.top == nil and tframe.bottom == nil and tframe.leftEdge == nil and tframe.rightEdge == nil
		and #tframe.rows == 1 and tframe.title.shadow ~= nil and tframe.title.shadowOffset ~= nil, #tframe.rows)
end

-- deux écarts, mais une seule ligne affichée : le premier est retenu
NS:CaptureStatBaseline()
Mock.world.armor = 650
Mock.world.attackSpeed = 2.4
Mock.world.equipped[10] = "item:921"
Mock.world.links["item:921"] = { name = "Gantelets runiques", quality = 3, itemLevel = 24,
	equipLoc = "INVTYPE_HEAD" }
NS:OnEquipmentChanged()
do
	local frame = NS.toastFrame
	local usedRows = 0
	for index = 1, #frame.rows do
		if frame.rows[index].value.text ~= "" then usedRows = usedRows + 1 end
	end
	Check("deux écarts : une seule ligne, remplie, pas de deuxième", usedRows == 1 and frame.rows[1].value.text ~= ""
		and frame.rows[2] == nil, usedRows)
	Check("libellé en PascalCase, valeur non concaténée", frame.rows[1].label.text == NS.PascalCase(frame.rows[1].label.text)
		and frame.rows[1].label.text:sub(2):find("%u") == nil and frame.rows[1].value.text:find("·") == nil,
		frame.rows[1].label.text .. " / " .. frame.rows[1].value.text)
end

-- le panneau de stats du portrait garde son filet, lui
NS:StartEditMode()
Check("stats du portrait encadrées ; lueur de déplacement sur le résumé", NS.portraitFrame.border ~= nil
	and NS.portraitFrame.chrome == "toast" and NS.toastFrame.moveGlow:IsShown() == true)
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
do
	local panel = NS.toastFrame
	local row = panel.rows[1]
	Check("titre en majuscules interlettrées, même corps que les lignes", panel.title ~= nil
		and panel.title.text == string.upper(panel.title.text) and panel.title.text:find(" ") ~= nil
		and panel.title.fontObject == NS.Theme.F_BODY and panel.title.fontObject == row.label.fontObject, panel.title.text)
	Check("règle de séparation sur toute la largeur, au-dessus des lignes", panel.rule ~= nil
		and #panel.rule.points == 2 and panel.rule.lastPoint.y > row.value.lastPoint.y)
	Check("valeurs et libellés ombrés, valeur à gauche du libellé, libellé en parchemin", row.value.shadow ~= nil
		and row.value.shadowOffset ~= nil and row.label.shadow ~= nil
		and row.value.lastPoint.x < row.label.lastPoint.x
		and row.label.textColor[1] > 0.9 and row.label.textColor[3] < 0.85,
		tostring(row.value.lastPoint.x) .. " / " .. tostring(row.label.lastPoint.x))
	-- l'icône vient du LIEN (GetItemInfo, 10e retour) et non de l'API
	-- d'emplacement : c'est ce qui la rend disponible même après un retrait
	Check("icône d'objet du lien, affichée", row.icon.texture == "Interface\\Icons\\INV_Belt_01"
		and row.icon:IsShown() == true, row.icon.texture)
	-- gain = vert, perte = rouge
	Check("ligne colorée selon l'écart", row.value.text ~= "" and row.value.textColor[1] ~= row.value.textColor[2],
		row.value.text)

	-- casse : titre en majuscules, libellés en PascalCase
	local wrong = {}
	for input, want in pairs({ ["armure"] = "Armure", ["score crit"] = "Score Crit",
		["vitesse d'attaque"] = "Vitesse D'attaque", ["dégâts"] = "Dégâts",
		["Puissance d'attaque"] = "Puissance D'attaque", [""] = "" }) do
		if NS.PascalCase(input) ~= want then wrong[#wrong + 1] = input .. " -> " .. tostring(NS.PascalCase(input)) end
	end
	Check("PascalCase : mots, apostrophe, accents, déjà capitalisé, vide", #wrong == 0, table.concat(wrong, ", "))
	Check("libellé réel en PascalCase", row.label.text == "Armure", row.label.text)

	-- Les flèches sont des textures : aucun caractère exotique ne doit subsister
	-- dans la valeur affichée (les triangles sortaient en carrés vides)
	local shown = row.value.text
	Check("valeur sans glyphe de flèche, en ASCII pur", shown:match("^[%+%-]?[%d%s,%.]+$") ~= nil
		and shown:byte(#shown) < 128, shown)
	-- 1.33.1 : plus de fichier à nous ; sans atlas (banc), pas de flèche
	Check("flèche : texture teintée comme la valeur, sans image à nous", row.arrow ~= nil
		and row.arrow.texture == nil and not row.arrow.clientArrow
		and row.arrow.vertex ~= nil and row.arrow.vertex[2] > row.arrow.vertex[1], row.arrow and row.arrow.texture)

	-- colonnes : la flèche commence après la valeur la plus longue (44 px
	-- mesurés pour « -0,60 s ») et ne touche pas le libellé ; le contenu est
	-- centré dans le bloc (sinon le vide s'accumule à droite, constaté en jeu)
	-- et icône, flèche, libellé, titre sont décalés de la même marge
	local inset = (NS.TOAST_WIDTH - NS.TOAST_CONTENT_WIDTH) / 2
	local scale = row.icon:GetWidth() / NS.TOAST_ICON
	local function near(a, b) return math.abs(a - b) < 0.02 end
	local misplaced = {}
	if not (NS.TOAST_ARROW_LEFT >= NS.TOAST_VALUE_LEFT + 40) then misplaced[#misplaced + 1] = "flèche sur la valeur" end
	if not (NS.TOAST_ARROW_LEFT + NS.ARROW_SIZE <= NS.TOAST_LABEL_LEFT) then misplaced[#misplaced + 1] = "flèche sur le libellé" end
	if not (inset > 0) then misplaced[#misplaced + 1] = "inset " .. inset end
	if not near(row.icon.lastPoint.x, (inset + NS.TOAST_ICON / 2) * scale) then misplaced[#misplaced + 1] = "icône" end
	if not near(row.label.lastPoint.x, (inset + NS.TOAST_LABEL_LEFT) * scale) then misplaced[#misplaced + 1] = "libellé" end
	if not near(row.arrow.lastPoint.x, (inset + NS.TOAST_ARROW_LEFT + NS.ARROW_SIZE / 2) * scale) then misplaced[#misplaced + 1] = "flèche" end
	if not near(panel.title.lastPoint.x, inset * scale) then misplaced[#misplaced + 1] = "titre" end
	Check("colonnes : flèche entre valeur et libellé, contenu centré dans le bloc", #misplaced == 0, table.concat(misplaced, ", "))
	-- Centrage vertical. L'icône et la flèche sont ancrées en CENTER : le point
	-- enregistré EST leur milieu. Le milieu de référence est celui de la ligne,
	-- calculé depuis le haut de ligne et la hauteur des chiffres.
	local textMiddle = NS.TOAST_ROW_TOP + NS.TOAST_LINE_MIDDLE
	local iconMiddle = row.icon.lastPoint.y / scale
	local arrowMiddle = row.arrow.lastPoint.y / scale
	Check("icône et flèche centrées verticalement sur la ligne, flèche visible",
		math.abs(textMiddle - (NS.TOAST_ROW_TOP - NS.TOAST_TEXT_HEIGHT / 2)) < 0.01
		and math.abs(iconMiddle - textMiddle) < 0.01 and math.abs(arrowMiddle - textMiddle) < 0.01
		and row.arrow:IsShown() == true, iconMiddle .. " / " .. arrowMiddle .. " vs " .. textMiddle)

	-- cinq écarts et plus : une ligne au maximum
	local many = {}
	for index = 1, 8 do
		many[#many + 1] = { key = "armor", label = "ARMOR", kind = "integer", polarity = true,
			delta = index, old = 0, new = index }
	end
	local built = NS:ToastRows(many)
	Check("tronqué à une ligne, la première conservée", #built == 1 and built[1].value ~= nil, #built)

	-- ligne vide = aucun résidu d'écart précédent
	NS:ToastRows({})
	NS:ToastText(NS:ToastRows({}))
	local residue = 0
	for index = 1, #panel.rows do
		if panel.rows[index].value.text ~= "" then residue = residue + 1 end
	end
	Check("rien à afficher : aucun résidu, icône masquée", residue == 0 and row.icon:IsShown() == false, residue)

	-- mode édition : structure d'attente, cadre non vide
	NS:StartEditMode()
	local placeholderShown = false
	for index = 1, #panel.rows do
		if panel.rows[index].value.text ~= "" then placeholderShown = true end
	end
	Check("édition : structure et titre visibles", placeholderShown and panel.title.text:find("S T A T") ~= nil, panel.title.text)
	NS:StopEditMode()
end

-- 4.62 Chrome des fenêtres : fond et bord d'infobulle (style AtlasLoot)
Say("\n== chrome des fenêtres ==")
ResetWorld()
NS:ToggleOptions()
do
	local win = NS.optionsFrame
	-- refonte 2026-11 : fenêtre v2 (Theme.CreateWindow), plus de bandeau titré
	Check("fenêtre v2 : sans backdrop Blizzard, fond presque opaque, filet sur les quatre côtés", win.chrome == "window"
		and win.backdrop == nil and win.bg and win.bg.vertex and win.bg.vertex[4] > 0.9
		and win.border and win.border.top and win.border.left and win.border.bottom and win.border.right, win.chrome)
	Check("marque : logo boussole et nom en F_TITLE, pas de portrait", win.brandLogo
		and tostring(win.brandLogo.texture):find("logo") ~= nil and win.brandName
		and win.brandName.fontObject == NS.Theme.F_TITLE and tostring(win.brandName.text):find("Quest") ~= nil
		and win.portrait == nil, win.brandName and win.brandName.text)
	Check("titre de page en F_DISPLAY, sous-titre présent", win.header and win.header.title.fontObject == NS.Theme.F_DISPLAY
		and tostring(win.header.title.text) ~= "" and win.header.subtitle ~= nil, win.header and win.header.title.text)
	win.close:Click()
	local closedByX = win:IsShown() == false
	NS:ToggleOptions()
	win.closeButton:Click()
	Check("[×] et « Terminé » ferment les réglages", closedByX and win:IsShown() == false)
	NS:ToggleOptions()
end

-- le diagnostic aussi
NS:ToggleOptions()
NS:RunChecklist("manual")
Check("diagnostic : fenêtre de module v2 (en-tête compact, pied)", NS.window.chrome == "dialog"
	and NS.window.header and NS.window.header.compact and NS.window.footer ~= nil, NS.window.chrome)

-- aucun template Blizzard requis : sans BackdropTemplate ni UIPanelButtonTemplate,
-- le panneau est identique (c'est tout l'intérêt des contrôles dessinés)
ResetWorld()
Mock.world.noBackdropTemplate = true
Mock.world.noButtonTemplate = true
Mock.world.fontRefused = true
NS:ToggleOptions()
do
	local fallback = NS.optionsFrame
	Mock.world.noButtonTemplate = false
	Mock.world.fontRefused = false
	Check("sans templates ni police : même fenêtre, titrée, complète", fallback.chrome == "window"
		and fallback.header ~= nil and tostring(fallback.header.title.text) ~= ""
		and fallback.rows ~= nil and #fallback.rows == 33, fallback.rows and #fallback.rows)
end
Mock.world.noBackdropTemplate = false

-- les cadres discrets gardent leur chrome propre
ResetWorld()
NS:StartEditMode()
Check("résumé et stats portrait sans backdrop", NS.toastFrame.backdrop == nil and NS.portraitFrame.backdrop == nil)
NS:StopEditMode()

-- 4.63 Fermeture par Échap (UISpecialFrames)
Say("\n== fermeture par Échap ==")
ResetWorld()
_G.UISpecialFrames = {}
NS:ToggleOptions()
NS:ToggleOptions()
NS:RunChecklist("manual")
do
	local declared = {}
	for _, name in ipairs(UISpecialFrames) do declared[name] = true end
	Check("réglages et diagnostic déclarés pour Échap, sans doublon", declared.Ready2QuestOptionsFrame
		and declared.Ready2QuestDiagFrame and #UISpecialFrames == 2, #UISpecialFrames)
end
-- rouvrir ne réinscrit pas
NS:ToggleOptions()
NS:ToggleOptions()
Check("pas de doublon après réouverture", #UISpecialFrames == 2, #UISpecialFrames)

-- 4.64 Le déplacement effectif des cadres (OnDragStart)
Say("\n== déplacement effectif ==")
ResetWorld()
NS:StartEditMode()
do
	local bad = {}
	for _, pair in ipairs({ { "résumé", NS.toastFrame }, { "stats portrait", NS.portraitFrame } }) do
		local label, frame = pair[1], pair[2]
		local dragStart, dragStop = frame:GetScript("OnDragStart"), frame:GetScript("OnDragStop")
		if not (frame.mouseEnabled == true and frame.movable == true and type(dragStart) == "function"
			and type(dragStop) == "function") then
			bad[#bad + 1] = label .. " : pas déplaçable"
		else
			-- simuler le glissement : OnDragStart doit réellement démarrer le déplacement
			dragStart(frame)
			if frame.isMoving ~= true then bad[#bad + 1] = label .. " : ne démarre pas" end
			dragStop(frame)
			if frame.isMoving ~= false then bad[#bad + 1] = label .. " : ne s'arrête pas" end
		end
	end
	Check("en édition, résumé et stats portrait se déplacent vraiment", #bad == 0, table.concat(bad, ", "))
end
NS:StopEditMode()

do -- portée locale : Lua 5.1 limite le bloc principal à 200 locales
-- 4.40 v1.18.0 : nouveaux checks et marchand
Say("\n== v1.18.0 : checks et marchand ==")
-- Composants de classe
ResetWorld()
Mock.world.classToken = "WARRIOR"
NS:RunChecklist("manual")
Check("guerrier : composants inactifs (poids nul, « sans objet »)", Result("classreagents") and Result("classreagents").disabled == true
	and Result("classreagents").weight == 0 and Result("classreagents").detail == "sans objet", Result("classreagents").detail)

Mock.world.classToken = "WARLOCK"
Mock.world.level = 9
NS:RunChecklist("manual")
Check("démoniste niv. 9 : composants inactifs", Result("classreagents").disabled == true)
Mock.world.level = 20
Mock.world.bags[0].items[1] = { itemID = 6265, stackCount = 1, quality = 1 }
NS:RunChecklist("manual")
do
	local cr = Result("classreagents")
	local oneOfThree = cr and cr.ok == false and cr.detail:find("1 / 3") ~= nil and cr.weight == 15
	Mock.world.bags[0].items[1] = { itemID = 6265, stackCount = 5, quality = 1 }
	NS:RunChecklist("manual")
	Check("démoniste : 1 fragment sur 3 = échec (poids 15), 5 fragments = OK", oneOfThree
		and Result("classreagents").ok == true, cr and cr.detail)
end

Mock.world.classToken = "HUNTER"
Mock.world.ammo = 50
NS:RunChecklist("manual")
do
	local low = Result("classreagents").ok == false
	Mock.world.ammo = 800
	NS:RunChecklist("manual")
	Check("chasseur : 50 munitions = échec, 800 = OK", low and Result("classreagents").ok == true, Result("classreagents").detail)
end

Mock.world.classToken = "DRUID"
Mock.world.level = 40
Mock.world.bags[0].items[1] = { itemID = 17036, stackCount = 1, quality = 1 }
NS:RunChecklist("manual")
Check("druide : une graine d'un autre rang compte", Result("classreagents").ok == true, Result("classreagents").detail)

-- Pierre de foyer
ResetWorld()
NS:RunChecklist("manual")
local hs = Result("hearth")
Check("pas de pierre de foyer : échec (poids 10)", hs and hs.ok == false and hs.score == 0 and hs.weight == 10, hs and hs.detail)
Mock.world.bags[0].items[1] = { itemID = 6948, stackCount = 1, quality = 1 }
Mock.world.bind = "Long-guet"
NS:RunChecklist("manual")
hs = Result("hearth")
Check("foyer prêt : OK + lieu lié", hs.ok == true and hs.detail:find("Long%-guet") ~= nil, hs.detail)
Mock.world.cooldowns = { [6948] = { Mock.now - 60, 3600 } }
NS:RunChecklist("manual")
hs = Result("hearth")
local longCooldown = hs.ok == false and hs.detail:find("59 min") ~= nil
Mock.world.cooldowns = { [6948] = { Mock.now - 3300, 3600 } }
NS:RunChecklist("manual")
Check("foyer en recharge : 59 min = échec, 5 min = toléré", longCooldown and Result("hearth").ok == true, hs.detail)

-- Réparation : muet sans mesure, puis estimation depuis le coût mesuré
ResetWorld()
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
Check("réparation estimée : or insuffisant (poids 10)", rp and rp.ok == false and rp.detail:find("80 pa") ~= nil
	and rp.weight == 10, rp and rp.detail)
Mock.world.money = 10000
NS:RunChecklist("manual")
Check("réparation estimée : or suffisant", Result("repair").ok == true, Result("repair").detail)

-- Sorts à apprendre
ResetWorld()
Mock.world.level = 10
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
local trainerInit = NS:CharData().trainerLevel == 10
NS:RunChecklist("manual")
Check("premier login : niveau d'entraîneur initialisé, sorts inactifs", trainerInit and Result("spells").disabled == true)
Mock.world.level = 11
Check("niveau impair : rien à apprendre", NS:PendingSpellLevels() == 0)
Mock.world.level = 12
NS:RunChecklist("manual")
local sp = Result("spells")
Check("niveau 12 : sorts à apprendre (poids 5)", sp and sp.ok == false and sp.disabled ~= true and sp.weight == 5, sp and sp.detail)
Mock.world.tradeskillTrainer = true
Mock:Fire("TRAINER_SHOW")
local tradeIgnored = NS:CharData().trainerLevel == 10
Mock.world.tradeskillTrainer = false
Mock:Fire("TRAINER_SHOW")
Check("entraîneur de métier ignoré, entraîneur de classe mémorisé", tradeIgnored and NS:CharData().trainerLevel == 12)
NS:RunChecklist("manual")
Check("après l'entraîneur : sorts inactifs", Result("spells").disabled == true)

-- Vente automatique des gris, par tranches de 12
ResetWorld()
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
Check("première passe : 12 objets vendus, une suivante programmée", #(Mock.world.sold or {}) == 12
	and Mock.world.timers and #Mock.world.timers == 1, #(Mock.world.sold or {}))
Mock:Reset()
Mock:RunTimers()
Check("seconde passe : les 15 gris vendus, récap 7 pa 50 pc", #(Mock.world.sold or {}) == 15
	and Mock:Output():find("15 objets gris vendus : 7 pa 50 pc") ~= nil, Mock:Output())
Check("gardés : gris sans prix, objet blanc, gris « sans valeur »", Mock.world.bags[1].items[1] ~= nil
	and Mock.world.bags[1].items[2] ~= nil and Mock.world.bags[1].items[3] ~= nil)
Mock:Fire("MERCHANT_CLOSED")

Mock.world.sold = nil
Mock.world.bags[0].items[1] = { itemID = 5001, stackCount = 1, quality = 0, hyperlink = "gris1" }
NS:DB().autoSellGray = false
Mock:Fire("MERCHANT_SHOW")
Check("vente auto désactivée : rien vendu", Mock.world.sold == nil)
Mock:Fire("MERCHANT_CLOSED")
C_Item.GetItemInfo = savedGetItemInfo

-- Réparation automatique
ResetWorld()
Check("vente et réparation auto activées par défaut", NS:DB().autoSellGray == true and NS:DB().autoRepair == true)
Mock.world.canRepair = true
Mock.world.repairCost = 12345
Mock.world.money = 100000
Mock.world.durability = { [5] = { 10, 100 } }
Mock:Reset()
Mock:Fire("MERCHANT_SHOW")
Check("réparation auto effectuée, récap 1 po 23 pa 45 pc", Mock.world.repaired == 1
	and Mock:Output():find("réparé : 1 po 23 pa 45 pc") ~= nil, Mock:Output())
Mock:Fire("MERCHANT_CLOSED")
Mock.world.repaired = nil
Mock.world.repairCost = 50000
Mock.world.money = 100
Mock:Reset()
Mock:Fire("MERCHANT_SHOW")
Check("or insuffisant : pas de réparation, message", Mock.world.repaired == nil
	and Mock:Output():find("Pas assez d'or") ~= nil, Mock:Output())
Mock:Fire("MERCHANT_CLOSED")
Mock.world.canRepair = false
Mock.world.money = 100000
Mock:Fire("MERCHANT_SHOW")
local noRepairer = Mock.world.repaired == nil
Mock:Fire("MERCHANT_CLOSED")
Mock.world.canRepair = true
NS:DB().autoRepair = false
Mock:Fire("MERCHANT_SHOW")
Check("marchand qui ne répare pas, ou réparation auto désactivée : rien", noRepairer and Mock.world.repaired == nil)
Mock:Fire("MERCHANT_CLOSED")

-- Réglages exposés dans le panneau d'options
ResetWorld()
NS.optionsFrame = nil
NS:EnsureOptions()
local optKeys = {}
for _, row in ipairs(NS.optionsFrame and NS.optionsFrame.rows or {}) do
	if row.def and row.def.key then optKeys[row.def.key] = row.def end
end
Check("options : délai avant l'alerte (0–15 s), vente auto, réparation auto", optKeys.exitDelay
	and optKeys.exitDelay.min == 0 and optKeys.exitDelay.max == 15 and optKeys.autoSellGray ~= nil
	and optKeys.autoRepair ~= nil)

-- Ligne « Parti de » dans la fenêtre de diagnostic
ResetWorld()
NS:DB().safe["v:30:Comté-de-l'Or"] = { kind = "village", name = "Comté-de-l'Or", mapID = 30,
	subzone = "Comté-de-l'Or", source = "mail" }
Mock.world.mapID = 30
Mock.world.subzone = "Comté-de-l'Or"
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Mock.now = Mock.now + 60
Mock.world.subzone = "Bois de l'Est"
Mock:Fire("ZONE_CHANGED")
Mock:Advance(6)
Check("sortie de village : ligne « Parti de » avec lieu et source", NS.lastResults ~= nil and NS.window and NS.window.departed
	and NS.window.departed.text:find("Parti de Comté%-de%-l'Or") ~= nil
	and NS.window.departed.text:find("boîte aux lettres") ~= nil,
	NS.window and NS.window.departed and NS.window.departed.text)
NS:RunChecklist("manual")
Check("check manuel : pas de ligne « Parti de »", not tostring(NS.window.departed.text):find("Parti de", 1, true)
	and NS.window.departed.text == NS.L.PANEL_SUBTITLE, NS.window.departed.text)

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
local missingLoc = {}
for _, key in ipairs(newKeys) do
	if not frPart:find("\n\t" .. key .. " = ", 1, true) then missingLoc[#missingLoc + 1] = "frFR:" .. key end
	if not enPart:find("\n\t" .. key .. " = ", 1, true) then missingLoc[#missingLoc + 1] = "enUS:" .. key end
end
Check("nouvelles chaînes présentes en frFR et en enUS", #missingLoc == 0, table.concat(missingLoc, ", "))

do
-- ---------------------------------------------------------------------------
-- Correctifs de l'audit v1.18.0 (replis d'API conservés)
-- ---------------------------------------------------------------------------
Say("\n== audit v1.18.0 : correctifs ==")

-- [2] vivres et potions en sous-classe générique 0 (vanilla)
ResetWorld()
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
Check("[2] sous-classe 0 : nourriture + boisson comptées (10), potion comptée (3)", Result("vivres").detail:find("10") ~= nil
	and Result("potions").ok == true, Result("vivres").detail .. " / " .. Result("potions").detail)
_G.GetItemSpell = savedItemSpell

-- [4] GetItemInfoInstant global quand C_Item n'en a pas
ResetWorld()
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
ResetWorld()
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
ResetWorld()
NS:DB().buffs[1243] = { name = "Mot de pouvoir : Robustesse", duration = 1800, enabled = true, learned = true }
Mock.world.auras = { [21562] = { name = "Prière de robustesse", duration = 3600 } }
Mock.world.auraOrder = { 21562 }
NS:RunChecklist("manual")
local groupCovers = Result("buffs").ok == true
Mock.world.auras = { [10938] = { name = "Mot de pouvoir : Robustesse", duration = 1800 } }
Mock.world.auraOrder = { 10938 }
NS:RunChecklist("manual")
Check("[6] Prière de robustesse et autre rang couvrent Robustesse", groupCovers and Result("buffs").ok == true, Result("buffs").detail)
NS.lastBuffScan = nil
NS:ScanBuffs()
Check("[6] autre rang : pas appris une seconde fois", NS:DB().buffs[10938] == nil)
Check("[6] familles : Bénédiction supérieure = Bénédiction, Don du fauve = Marque du fauve",
	NS.BuffFamily("Bénédiction supérieure de puissance") == NS.BuffFamily("Bénédiction de puissance")
	and NS.BuffFamily("Don du fauve") == NS.BuffFamily("Marque du fauve"))

-- [6b] buffs exclusifs (toutes classes) : un seul réclamé, satisfait par n'importe lequel
ResetWorld()
Mock.world.classToken = "PALADIN"
NS:DB().buffs[19740] = { name = "Bénédiction de puissance", duration = 600, enabled = true, learned = true, lastSeen = 100, self = true }
NS:DB().buffs[19742] = { name = "Bénédiction de sagesse", duration = 600, enabled = true, learned = true, lastSeen = 200, self = true }
NS:DB().buffs[25898] = { name = "Bénédiction supérieure des rois", duration = 1800, enabled = true, learned = true, lastSeen = 50, self = true }
Mock.world.auras = { [19740] = { name = "Bénédiction de puissance", duration = 600 } }
Mock.world.auraOrder = { 19740 }
NS:RunChecklist("manual")
Check("[6b] paladin : une bénédiction active couvre les autres", Result("buffs").ok == true, Result("buffs").detail)
Mock.world.auras = {}
Mock.world.auraOrder = {}
NS:RunChecklist("manual")
local blessDetail = Result("buffs").detail or ""
Check("[6b] paladin : une seule bénédiction réclamée, la dernière vue", Result("buffs").ok == false
	and select(2, blessDetail:gsub("Bénédiction", "")) == 1 and blessDetail:find("sagesse") ~= nil, blessDetail)
do
	local G = NS.BuffExclusiveGroup
	local function same(a, b) return G(NS.BuffFamily(a)) ~= nil and G(NS.BuffFamily(a)) == G(NS.BuffFamily(b)) end
	local wrong = {}
	for _, pair in ipairs({
		{ "Armure de givre", "Armure du mage" }, { "Ice Armor", "Mage Armor" },
		{ "Amplification de la magie", "Atténuation de la magie" },
		{ "Peau de démon", "Armure démoniaque" },
		{ "Bouclier de foudre", "Bouclier d'eau" },
		{ "Cri de guerre", "Cri de commandement" },
		{ "Aspect du faucon", "Aspect du singe" }, { "Aspect of the Hawk", "Aspect of the Pack" },
		{ "Aura de dévotion", "Aura de résistance au feu" }, { "Fire Resistance Aura", "Devotion Aura" },
		{ "Sceau de piété", "Sceau du croisé" },
		{ "Feu intérieur", "Volonté intérieure" },
	}) do
		if not same(pair[1], pair[2]) then wrong[#wrong + 1] = pair[1] .. " / " .. pair[2] end
	end
	for _, name in ipairs({ "Intelligence des arcanes", "Marque du fauve", "Mot de pouvoir : Robustesse" }) do
		if G(NS.BuffFamily(name)) ~= nil then wrong[#wrong + 1] = name .. " groupé" end
	end
	if same("Bénédiction de sagesse", "Aura de dévotion") then wrong[#wrong + 1] = "bénédiction = aura" end
	Check("[6b] groupes exclusifs (armures, boucliers, cris, aspects, auras, sceaux…), indépendants hors groupe",
		#wrong == 0, table.concat(wrong, ", "))
end

-- [7] sans GetPlayerAuraBySpellID : lecture par index, pas « illisible »
ResetWorld()
local savedByID = C_UnitAuras.GetPlayerAuraBySpellID
C_UnitAuras.GetPlayerAuraBySpellID = nil
Mock.world.classToken = "MAGE"; NS:DB().buffs[1459] = { name = "Intelligence des arcanes", duration = 1800, enabled = true, self = true }
NS:RunChecklist("manual")
local absentMissing = Result("buffs").ok == false and Result("buffs").detail:find("Intelligence") ~= nil
Mock.world.auras = { [10157] = { name = "Intelligence des arcanes", duration = 1800 } }
Mock.world.auraOrder = { 10157 }
NS:RunChecklist("manual")
Check("[7] sans API par spellID : buff absent = manquant, présent = OK", absentMissing and Result("buffs").ok == true,
	Result("buffs").detail)
C_UnitAuras.GetPlayerAuraBySpellID = savedByID

-- [23] buffs de consommables non appris, buffs oubliés après 7 jours
ResetWorld()
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

-- [11] puissance d'attaque = base + bonus (3 retours)
ResetWorld()
local savedAP = _G.UnitAttackPower
_G.UnitAttackPower = function() return 100, 30, -5 end
Check("[11] PA = base + posBuff + negBuff", NS:StatSnapshot().ap == 125, NS:StatSnapshot().ap)
_G.UnitAttackPower = savedAP

-- [12] spé sans GetSpecialization : onglet de talents le plus fourni
ResetWorld()
local savedSpec, savedSpecInfo = _G.GetSpecialization, _G.GetSpecializationInfo
_G.GetSpecialization, _G.GetSpecializationInfo = nil, nil
_G.GetNumTalentTabs = function() return 3 end
_G.GetTalentTabInfo = function(tab)
	local tabs = { { "Sacré", 5 }, { "Protection", 0 }, { "Vindicte", 31 } }
	return tabs[tab][1], 135920, tabs[tab][2], "PaladinHoly"
end
Check("[12] sans GetSpecialization : spé = onglet le plus fourni (Vindicte : Intelligence d'abord)", NS.SpecIndex() == 3
	and firstStat("PALADIN", nil):find("Intelligence") ~= nil, NS.SpecIndex())
_G.GetTalentTabInfo = function(tab)
	local tabs = { { "Sacré", 0 }, { "Protection", 31 }, { "Vindicte", 5 } }
	return tabs[tab][1], 135920, tabs[tab][2], "PaladinHoly"
end
Check("[12] onglets de talents : paladin Protection affiche l'Endurance d'abord",
	firstStat("PALADIN", nil):find("Endurance") ~= nil, firstStat("PALADIN", nil))
_G.GetSpecialization, _G.GetSpecializationInfo = savedSpec, savedSpecInfo
_G.GetNumTalentTabs, _G.GetTalentTabInfo = nil, nil

-- [17] [18] [19] pourcentage, Esprit, ilvl de repli
ResetWorld()
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
Check("[21] troncature : aucun caractère coupé en deux", cutText:sub(-3) == "..."
	and #cutText - 3 <= 38 and (#cutText - 3) % 2 == 0, cutText)
ResetWorld()
NS:RunChecklist("manual")
local firstAdvice = NS.window and NS.window.adviceLines[1].text or ""
Check("[22] puce de conseil en ASCII", not firstAdvice:find("•", 1, true), firstAdvice)

-- [14] [15] plus de « Sac & Départ » à l'écran
Check("[14] préfixe du chat et titre de fenêtre : Ready2Quest", NS.L.TAG:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):find("[Ready2Quest]", 1, true) ~= nil
	and NS.L.WIN_TITLE == "Ready2Quest", NS.L.TAG .. " / " .. tostring(NS.L.WIN_TITLE))
Mock:Reset()
NS:RecordError("audit-15", "message unique de l'audit")
Check("[15] message d'erreur : Ready2Quest", Mock:Output():find("Ready2Quest — erreur") ~= nil, Mock:Output())

-- [16] /sd diag donne la raison, pas le mapID
ResetWorld()
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
	ResetWorld()
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
Check("[UX2] note >= 85 : check lancé, pas de fenêtre, une ligne dans le chat", NS.lastResults ~= nil
	and (NS.score or 0) >= 85 and (NS.window == nil or NS.window.shown ~= true)
	and Mock:Output():find("Sac bouclé, %d+/100%. Parti de Village%.") ~= nil, Mock:Output())
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
ResetWorld()
NS:SetModuleEnabled("quests", false)
Mock.world.durability = { [5] = { 5, 100 } }
NS:DB().diagFoldOk = false   -- 1.32.0 : liste dépliée (le repli a ses tests, r2q_132.lua)
NS.window = nil
NS:RunChecklist("manual")
local shown = {}
for i = 1, NS.window.visibleRows do shown[#shown + 1] = NS.window.rows[i].name.text end
local shownText = table.concat(shown, ", ")
Check("[UX5] sans objet masqués, échec le plus lourd en tête (vivres), coupé par le joueur en bas",
	not shownText:find("Réparation") and not shownText:find("Sorts") and not shownText:find("Réactifs")
	and shown[1] == "Vivres" and shown[#shown - 1] == "Quêtes" and shown[#shown] == NS.L.CHK_OK_UNFOLD, shownText)
Check("[UX5] fenêtre plus courte que 13 lignes", NS.window.height < NS:WindowHeight(13, false), NS.window.height)
-- v1.20.0 : la forme porte le statut (losange plein = à voir, au trait = OK)
local firstStatus = NS.window.rows[1].status
local okStatus
for i = 1, NS.window.visibleRows do
	if NS.window.rows[i].status.state == "ok" then okStatus = NS.window.rows[i].status end
end
Check("[UX10] statut par la forme : échec = losange plein, OK = losange au trait", (firstStatus.state == "bad"
	or firstStatus.state == "warn") and firstStatus.clientRole == "diamond"
	and okStatus and okStatus.clientRole == "diamondLine", firstStatus.state)
NS:SetModuleEnabled("quests", true)

-- [6] repos : information, sans poids ni conseil
ResetWorld()
Mock.world.rested = 0
NS:RunChecklist("manual")
local restAdvice = false
for _, a in ipairs(NS.lastAdvice or {}) do if a.text == NS.L.ADV_REST then restAdvice = true end end
Check("[UX6] repos : poids nul, pas de conseil", Result("rest").weight == 0 and restAdvice == false)

-- [7] détail des sorts : tient dans la colonne
ResetWorld()
Mock.world.level = 10
Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
Mock.world.level = 12
NS:RunChecklist("manual")
Check("[UX7] sorts : détail court (<= 38)", #Result("spells").detail <= 38 and Result("spells").detail:find("10 à 12", 1, true) ~= nil,
	Result("spells").detail)

-- [9] vente auto : prévenu une seule fois
ResetWorld()
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
ResetWorld()
NS.window = nil
Mock.world.durability = { [5] = { 5, 100 } }
NS:RunChecklist("manual")
local w = NS.window
-- grand chiffre : F_DISPLAY (Inter Bold 26, docs/UI.md), plus grand que le titre
local display = rawget(_G, NS.Theme.F_DISPLAY)
Check("[ID] note en police maison, grand corps", w.scoreValue.fontObject == NS.Theme.F_DISPLAY
	and tostring(display.font.path):find("Inter%-Bold") ~= nil
	and display.font.size > rawget(_G, w.title.fontObject).font.size, tostring(w.scoreValue.fontObject))
Check("[ID] verdict dans un tampon bordé à sa couleur", w.stamp and w.stamp.border and w.verdict.text ~= ""
	and w.stamp.border.top.vertex[1] == w.verdict.textColor[1], w.verdict.text)
Check("[ID] fenêtre « Avant le départ » : fondu à l'ouverture, puces en losanges ambre", w.fadeIn and w.fadeIn.plays >= 1
	and w.title.text == "Avant le départ" and w.adviceBullets[1] and w.adviceBullets[1].clientRole == "diamond", w.title.text)
local target = NS.score
local fromZero = w.animStart ~= nil and w.animFrom == 0
Mock:Advance(0.1)
local mid = tonumber(w.scoreValue.text)
Mock:Advance(1)
Check("[ID] animation de la note : part de 0, monte, termine sur la valeur exacte", fromZero and mid ~= nil
	and mid > 0 and mid < target and tonumber(w.scoreValue.text) == target and w.animStart == nil,
	tostring(mid) .. " -> " .. w.scoreValue.text .. " / " .. target)
Check("[ID] préfixe du chat ambre, « 2 » bleu", NS.L.TAG:find("|cffe8a54b", 1, true) ~= nil and NS.L.TAG:find("|cff5b8fd62", 1, true) ~= nil, NS.L.TAG)

NS.optionsFrame = nil
NS:ToggleOptions()
local o = NS.optionsFrame
Check("[ID] options : trois titres de groupe (départ, modules, QoL)", #o.navGroups == 3, #o.navGroups)
local toggles, sliders = 0, 0
for _, row in ipairs(o.rows) do
	if row.toggle then toggles = toggles + 1 end
	if row.slider then sliders = sliders + 1 end
end
Check("[ID] contrôles dessinés : 20 interrupteurs, 10 curseurs", toggles == 13 + 7 and sliders == 10, toggles .. "/" .. sliders)
local pageCount, subs = 0, 0
for id in pairs(o.pages) do
	pageCount = pageCount + 1
	NS:SelectOptionsPage(id)
	if o.header.subtitle.text ~= "" and not tostring(o.header.subtitle.text):find("_SUB") then subs = subs + 1 end
end
Check("[ID] chaque page a sa phrase d'explication", subs == pageCount and pageCount == 9, subs .. "/" .. pageCount)
local displayRows = {}
for _, row in ipairs(o.pages.general.rows) do if row.def then displayRows[row.def.key] = true end end
Check("[AFF] Général réunit l'affichage", displayRows.showMinimap and displayRows.minimapPos and displayRows.showWindow
	and displayRows.popupScore and o.pages.general.sectionHeaders and #o.pages.general.sectionHeaders == 2
	and displayRows.qcAction)
-- bug signalé en jeu : cliquer sur « Stats du portrait » ou « Résumé de stuff »
-- ouvrait Général. Chaque module a maintenant sa page, qui explique ce qu'il fait.
local pageBugs = {}
for _, id in ipairs({ "toast", "portrait" }) do
	local nav
	for _, n in ipairs(o.navButtons) do if n.pageId == id then nav = n end end
	nav:Click()
	if not (o.currentPage == id and o.pages[id] and o.pages[id]:IsShown()) then pageBugs[#pageBugs + 1] = id .. " ouvre " .. tostring(o.currentPage) end
	if not (o.pages[id].infoLines and #o.pages[id].infoLines == 3 and o.pages[id].infoLines[1].text ~= ""
		and o.pages[id].infoLines[1].text ~= "OPT_" .. id:upper() .. "_INFO_1") then pageBugs[#pageBugs + 1] = id .. " sans explication" end
	if not (o.pages[id].actionButtons and o.pages[id].actionButtons.editMode ~= nil) then pageBugs[#pageBugs + 1] = id .. " sans « Placer le cadre »" end
end
Check("[AFF] résumé et portrait : leur propre page, explication, bouton Placer le cadre", #pageBugs == 0, table.concat(pageBugs, ", "))
NS:DB().showPortraitStats = false
NS.portraitFrame = nil
o.pages.portrait.actionButtons.portraitShow:Click()
Check("[AFF] portrait : « Afficher maintenant » visible même module coupé", NS.portraitFrame and NS.portraitFrame:IsShown() == true)
NS:DB().showPortraitStats = true
local delayRow
for _, row in ipairs(o.rows) do if row.def and row.def.key == "exitDelay" then delayRow = row end end
NS:DB().exitDelay = 15
NS:RefreshOptions()
Check("[ID] curseur plein au maximum", delayRow.slider.value == delayRow.slider.max and math.abs(delayRow.slider.fill.width - delayRow.slider.trackWidth) <= 1,
	delayRow.slider.value)
local addonRow
for _, row in ipairs(o.rows) do if row.def and row.def.key == "enabled" then addonRow = row end end
local amberOn = addonRow.toggle.checked == true and addonRow.toggle.knob.vertex[1] > 0.9
addonRow:Click()
Check("[ID] interrupteur : actif = ambre, clic le coupe", amberOn and addonRow.toggle.checked == false and NS:DB().enabled == false)
addonRow:Click()
NS:SelectOptionsPage("bags")
local function OptNav(id) for _, nav in ipairs(o.navButtons) do if nav.pageId == id then return nav end end end
Check("[ID] navigation : seule la page choisie est teintée", OptNav("bags").tint:IsShown() and not OptNav("general").tint:IsShown()
	and not OptNav("trigger").tint:IsShown())
-- v1.21.0 : marque Ready2Quest, deuxième couleur
Check("[R2Q] navigation : logo complet, nom au « 2 » bleu, version en bas, groupes en ambre",
	tostring(o.brandLogo.texture):find("Textures\\logo$") ~= nil and o.brandName.text:find("|cff5b8fd62|r", 1, true) ~= nil
	and tostring(o.version.text):find(NS.APP.version, 1, true) ~= nil
	and o.navGroups[1].textColor[1] > 0.85 and o.navGroups[1].textColor[3] < 0.35, o.brandName.text)
Check("[R2Q] commande /r2q", SLASH_SACETDEPART3 == "/r2q")

-- v1.22.0 : trois modules, chacun avec son interrupteur dans la navigation
NS.optionsFrame = nil
NS:ToggleOptions()
local function NavOf(id) for _, nav in ipairs(NS.optionsFrame.navButtons) do if nav.pageId == id then return nav end end end
local function HeadOf(id) for _, h in ipairs(NS.optionsFrame.navHeaders) do if h.pageId == id then return h end end end
local powered = {}
for _, nav in ipairs(NS.optionsFrame.navButtons) do if nav.powerKey then powered[#powered + 1] = nav.pageId end end
for _, h in ipairs(NS.optionsFrame.navHeaders) do if h.powerKey then powered[#powered + 1] = h.pageId end end
table.sort(powered)
Check("[NAV] interrupteur sur les 3 modules seulement, visible là et absent ailleurs", table.concat(powered, ",") == "departure,portrait,toast"
	and HeadOf("departure").power:IsShown() and NavOf("toast").power:IsShown()
	and not NavOf("general").power:IsShown() and not HeadOf("qol").power:IsShown() and not NavOf("trigger").power:IsShown(),
	table.concat(powered, ","))
local withTabs = {}
for _, id in ipairs({ "general", "bags", "merchant" }) do
	NS:SelectOptionsPage(id)
	if NS.optionsFrame.tabs:IsShown() then withTabs[#withTabs + 1] = id end
end
Check("[NAV] sous-pages : une entrée chacune sous leur groupe, pas de barre d'onglets", NavOf("trigger").parentId == "departure"
	and NavOf("merchant").parentId == "qol" and HeadOf("departure").label.text == NS.Theme.Upper(NS.L.OPT_PAGE_DEPARTURE)
	and #withTabs == 0, table.concat(withTabs, ", "))
NS:SelectOptionsPage("general")
local dep = HeadOf("departure")
local depOn = dep.moduleOn == true
dep.power:Click()
Check("[NAV] clic : check avant le départ coupé, libellé grisé, on reste sur la page", depOn
	and NS:DB().departureEnabled == false and dep.moduleOn == false and dep.label.textColor[1] < 0.6
	and NS.optionsFrame.currentPage == "general")
dep.power:Click()
Check("[NAV] second clic : rallumé", NS:DB().departureEnabled == true)
NavOf("portrait").power:Click()
local portraitOff = NS:DB().showPortraitStats == false
NavOf("portrait").power:Click()
NavOf("toast").power:Click()
Check("[NAV] interrupteurs : stats du portrait et résumé de stuff coupés", portraitOff and NS:DB().showGearToast == false)
NavOf("toast").power:Click()
-- le QoL ne dépend pas du module de départ
NS:DB().departureEnabled = false
Check("[NAV] QoL indépendant : vente auto toujours active", NS:DB().autoSellGray ~= false)
NS:DB().departureEnabled = true

-- v1.22.0 : base livrée des zones sûres, faction, instances, camp de Forever
do
	ResetWorld()
	local count = 0
	for _ in pairs(NS.HUBS or {}) do count = count + 1 end
	Check("[HUB] base livrée chargée (au moins 75 lieux)", NS.HUBS and NS.HUBS[87] and NS.HUBS[87].name == "Goldshire"
		and NS.HUBS[1519].kind == "capital" and count >= 75, count)
	-- village connu, sans aucun apprentissage
	_G.UnitFactionGroup = function() return Mock.world.faction or "Alliance" end
	Mock.world.mapID, Mock.world.subzone = 30, "Goldshire"
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	local safe, _, why = NS:IsCurrentZoneSafe()
	Check("[HUB] Goldshire sûr dès l'installation, sans rien apprendre", safe == true and why == "known"
		and next(NS:DB().safe) == nil, tostring(why))
	Mock.now = Mock.now + 60
	Mock.world.subzone = "Fargodeep Mine"
	Mock:Fire("ZONE_CHANGED"); Mock:Advance(6)
	Check("[HUB] sortie de Goldshire : alerte, parti d'un lieu connu", NS.lastResults ~= nil and NS:DepartedText()
		and NS:DepartedText():find("Goldshire") and NS:DepartedText():find("lieu connu"), NS:DepartedText())
	Check("[HUB] une mine n'est pas sûre", NS:IsCurrentZoneSafe() == false)

	-- noms traduits par le jeu
	ResetWorld()
	-- le client traduit chaque identifiant (Goldshire a aussi l'ID 16524 sur Forever)
	_G.C_Map.GetAreaInfo = function(areaID)
		return ({ [87] = "Comté-de-l'Or", [16524] = "Comté-de-l'Or", [1637] = "Orgrimmar" })[areaID] or ("Zone " .. areaID)
	end
	Mock.world.mapID, Mock.world.subzone = 30, "Comté-de-l'Or"
	local translated = NS:IsCurrentZoneSafe() == true
	Mock.world.subzone = "Goldshire"
	NS.hubIndex = nil
	Check("[HUB] nom traduit par le client (frFR) reconnu, l'anglais ne compte plus", translated
		and NS:IsCurrentZoneSafe() == false)
	_G.C_Map.GetAreaInfo = nil

	-- faction : le village de l'autre faction n'est pas sûr, et n'est pas appris
	ResetWorld()
	Mock.world.faction = "Horde"
	Mock.world.mapID, Mock.world.subzone = 30, "Southshore"
	local hostileSafe, _, hostileWhy = NS:IsCurrentZoneSafe()
	Mock:Fire("MAIL_SHOW")
	Check("[HUB] Southshore pour un Horde : hostile, jamais appris", hostileSafe == false and hostileWhy == "hostile"
		and next(NS:DB().safe) == nil, tostring(hostileWhy))
	Mock.world.subzone = "Booty Bay"
	local neutral = NS:IsCurrentZoneSafe() == true
	Mock.world.subzone = "Tarren Mill"
	Check("[HUB] ville neutre sûre pour tous, Tarren Mill sûr pour un Horde", neutral and NS:IsCurrentZoneSafe() == true)

	-- capitale reconnue par le nom de la zone, dans n'importe quel quartier
	_G.GetRealZoneText = function() return Mock.world.zone or "" end
	Mock.world.zone, Mock.world.subzone = "Orgrimmar", "Valley of Strength"
	local anyQuarter = NS:IsCurrentZoneSafe() == true
	Mock.world.faction = "Alliance"
	Check("[HUB] capitale : sûre dans n'importe quel quartier, pas pour l'ennemi", anyQuarter
		and NS:IsCurrentZoneSafe() == false)
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
	Check("[CAMP] quitter le camp : alerte, parti du campement (feu de camp)", NS.lastResults ~= nil and NS:DepartedText()
		and NS:DepartedText():find("campement") and NS:DepartedText():find("feu de camp"), NS:DepartedText())

	-- buffs du camp : jamais appris
	ResetWorld()
	Mock.world.auras = { [1289378] = { name = "Warmth", duration = 3600 }, [1229741] = { name = "Camp Benefits", duration = 1800 },
		[1459] = { name = "Intelligence des arcanes", duration = 1800 } }
	Mock.world.auraOrder = { 1289378, 1229741, 1459 }
	NS.lastBuffScan = nil
	NS:ScanBuffs()
	Check("[CAMP] Warmth et Camp Benefits ignorés, les vrais buffs appris", NS:DB().buffs[1289378] == nil
		and NS:DB().buffs[1229741] == nil and NS:DB().buffs[1459] ~= nil)

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

-- retours de la première session en jeu (Vallée des épreuves)
NS.editBanner = nil
NS:StartEditMode()
local banner = NS.editBanner
-- refonte 2026-11 : bandeau, l'aide à gauche du bouton (côte à côte) ; elle
-- doit s'arrêter avant lui et tenir dans la hauteur du bandeau
local hintRight = banner.hint.lastPoint.x + banner.hint:GetWidth()
local buttonLeft = banner.width - 12 - banner.stopButton:GetWidth()
Check("[JEU] bandeau d'édition : l'aide ne passe plus sous le bouton ambre, dont le texte tient", hintRight + 8 <= buttonLeft
	and -banner.hint.lastPoint.y + 14 <= banner.height - 6
	and banner.stopButton:GetWidth() >= banner.stopButton.text:GetStringWidth() + 16
	and banner.stopButton.style == "primary", hintRight .. " + 8 <= " .. buttonLeft)
NS:StopEditMode()
ResetWorld()
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
Check("[JEU] gravité par poids : 2 gris en ambre (module léger), durabilité à 5 % en rouge (lourd)",
	grayRow and grayRow.status.state == "warn" and duraRow and duraRow.status.state == "bad",
	tostring(grayRow and grayRow.status.state) .. " / " .. tostring(duraRow and duraRow.status.state))
Check("[R2Q] API publique sous les deux noms", _G.Ready2Quest == NS and _G.ReadyToQuest == NS)

end
Mock.world.classToken = nil
end

end -- RUN_CORE

-- 4.99 Tests des modules (tests/modules/*.lua, listés par run_tests.py).
-- Chaque fichier reçoit la boîte à outils du harnais dans la table T.
do
	-- LoadModules : rien à faire, les modules sont chargés juste après (les
	-- scènes de tests/snapshot.lua l'appellent, tests/modules/ui_windows.lua les joue)
	_G.T = { Check = Check, Say = Say, ResetWorld = ResetWorld, Result = Result, NS = NS, QNS = QNS, Mock = Mock,
		LoadModules = function() end }
	-- créatures brillantes : jamais au hasard pendant les tests (shiny.lua règle sa chance)
	if QNS then QNS.SHINY_CHANCE = 0 end
	-- missions du jour : pas de tirage automatique (companion_daily.lua les tire lui-même)
	if QNS then QNS.DAILY_AUTO = false end
	-- 3.1.0 : capture express (CaptureExpress.lua) endormie : les scénarios du
	-- déroulé d'avant (carte, scène, bandeau) restent ceux du réglage coupé ;
	-- capture_express.lua la réveille
	if QNS then QNS.captureExpressDormant = true end
	-- 3.0.0 : visites guidées (GuidedTour.lua) : pas de départ automatique
	-- (leurs bulles couvriraient les scénarios ; guide_tours.lua les allume)
	if QNS then QNS.TOUR_AUTO = false end
	-- conseils du compagnon : pas d'examen automatique au premier pas de
	-- l'horloge (companion_advice.lua remet l'échéance à zéro lui-même) ;
	-- avant le lanceur parallèle, l'échéance laissée par les modules
	-- précédents le masquait
	if QNS then QNS.adviceNextAt = math.huge end
	-- module joué seul (sans les scénarios du cœur) : le même monde de départ
	if rawget(_G, "RUN_CORE") == false then ResetWorld() end
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
