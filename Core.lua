-- Core.lua -- détection de zone sûre, événements, commandes, orchestration
local ADDON, ns = ...
local L = ns.L

-- ---------------------------------------------------------------------------
-- Réglages par défaut
-- ---------------------------------------------------------------------------
local DEFAULTS = {
	enabled             = true,
	showWindow          = true,   -- false = résumé dans le chat
	learnBuffs          = true,   -- apprend les buffs depuis tes propres auras
	continuousBagAlert  = true,   -- alerte en continu quand les sacs sont pleins
	showMinimap         = true,   -- lanceur autour de la minicarte
	minimapAngle        = 225,    -- position sur l'anneau (degrés)
	modules             = {},     -- [id de module] = false pour désactiver
	showGearToast       = true,   -- résumé éphémère au changement de stuff
	showPortraitStats   = true,   -- stats au survol du portrait
	toastPoint          = { point = "CENTER", x = 260, y = 20 },
	portraitPoint       = { point = "CENTER", x = -260, y = 20 },
	portraitManual      = false,  -- true dès que le joueur a placé le cadre lui-même
	diagPoint           = { point = "CENTER", x = 0, y = 120 },
	optionsPoint        = { point = "CENTER", x = 0, y = 20 },
	bagFreeThreshold    = 4,      -- alerte si <= N emplacements libres
	grayItemThreshold   = 1,      -- alerte si >= N objets gris
	vivresThreshold     = 1,      -- alerte si < N vivres
	potionsThreshold    = 0,      -- alerte si < N (0 = désactivé)
	restMinPercent      = 10,     -- alerte si < N% d'un niveau de repos
	durabilityMinPct    = 25,     -- alerte si < N%
	alertCooldown       = 20,     -- secondes anti-spam
	quietAfterLogin     = 15,     -- pas d'alerte dans les N s après connexion
	safe                = {},     -- [mapID] = { name, source, at }
	buffs               = {},     -- [spellId] = { name, duration, enabled }
	seen                = {},     -- [mapID] = true (zones déjà visitées)
}

local function ApplyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			ApplyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function ns:DB()
	-- Migration : l'addon s'appelait Sac & Départ (SavedVariable SacEtDepartDB).
	-- On reprend la sauvegarde existante une seule fois, sinon chaque joueur
	-- perdrait ses zones sûres apprises et ses réglages au renommage.
	if type(ReadyToQuestDB) ~= "table" then
		ReadyToQuestDB = {}
		if type(SacEtDepartDB) == "table" then
			for k, v in pairs(SacEtDepartDB) do ReadyToQuestDB[k] = v end
			SacEtDepartDB = nil
		end
	end
	if not self._dbReady then
		ApplyDefaults(DEFAULTS, ReadyToQuestDB)
		self._dbReady = true
	end
	return ReadyToQuestDB
end

local function Now()
	if GetTime then return GetTime() end
	if time then return time() end
	return 0
end
ns.Now = Now

-- Accesseur défensif : Buffs.lua peut ne pas être chargé (ordre de TOC modifié).
local function TrackedList(addon)
	if type(addon.TrackedBuffs) == "function" then
		return addon:TrackedBuffs()
	end
	return {}
end

-- ---------------------------------------------------------------------------
-- Lecture de la carte (API non restreinte)
-- ---------------------------------------------------------------------------
function ns:CurrentMap()
	if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
	local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
	if ok and type(mapID) == "number" then return mapID end
	return nil
end

function ns:MapInfo(mapID)
	if not mapID or not (C_Map and C_Map.GetMapInfo) then return nil end
	local ok, info = pcall(C_Map.GetMapInfo, mapID)
	if ok then return info end
	return nil
end

-- Chaîne carte courante -> parents (une zone est "sûre" si elle ou un parent l'est)
function ns:MapChain(mapID)
	local chain, guard = {}, 0
	while mapID and guard < 12 do
		chain[#chain + 1] = mapID
		local info = self:MapInfo(mapID)
		local parent = info and info.parentMapID
		if not parent or parent == 0 or parent == mapID then break end
		mapID = parent
		guard = guard + 1
	end
	return chain
end

-- Signaux "vivants" (pas de la base de données)
function ns:LiveSafeSignals()
	local signals = {}

	local fn = rawget(_G, "IsResting")
	if type(fn) == "function" then
		local ok, res = pcall(fn)
		if ok and res == true then signals[#signals + 1] = "resting" end
	end

	if GetRestState and Enum and Enum.RestState then
		local ok, res = pcall(GetRestState)
		if ok and res == Enum.RestState.RESTED then signals[#signals + 1] = "reststate" end
	end

	if type(UnitIsPVPSanctuary) == "function" then
		local ok, res = pcall(UnitIsPVPSanctuary, "player")
		if ok and res == true then signals[#signals + 1] = "sanctuary" end
	end

	return signals
end

function ns:IsCurrentZoneSafe()
	local db = self:DB()
	local mapID = self:CurrentMap()

	if mapID then
		for _, id in ipairs(self:MapChain(mapID)) do
			if db.safe[id] then return true, mapID, "saved" end
		end
	end

	if #self:LiveSafeSignals() > 0 then return true, mapID, "signal" end
	return false, mapID, nil
end

-- ---------------------------------------------------------------------------
-- Apprentissage des zones sûres
--   * repos / sanctuaire  -> zone apprise automatiquement
--   * ouverture d'un vendeur ou d'une boîte aux lettres -> village appris
--   * /sd safe -> apprentissage manuel
-- ---------------------------------------------------------------------------
function ns:LearnZone(source)
	local db = self:DB()
	local mapID = self:CurrentMap()
	if not mapID or db.safe[mapID] then return false end

	local info = self:MapInfo(mapID)
	db.safe[mapID] = {
		name   = (info and info.name) or tostring(mapID),
		source = source or "auto",
		at     = Now(),
	}
	local verbose = db.verboseLearn
	if verbose then
		self:Print(self:F("MSG_LEARNED", db.safe[mapID].name, tostring(source)))
	end
	return true
end

function ns:LearnFromSignals()
	local signals = self:LiveSafeSignals()
	if #signals > 0 then
		self:LearnZone(signals[1])
	end
end

-- ---------------------------------------------------------------------------
-- Machine à états : on alerte uniquement sur la transition sûre -> non sûre
-- ---------------------------------------------------------------------------
function ns:Evaluate(trigger)
	local db = self:DB()
	if not db.enabled then return end

	local safe = self:IsCurrentZoneSafe()
	local previous = self.inSafe
	self.inSafe = safe

	if previous == nil then return end          -- première évaluation : on pose la référence
	if not previous or safe then return end     -- on n'alerte que sûre -> non sûre

	local now = Now()
	if self.quietUntil and now < self.quietUntil then return end
	if self.lastAlert and (now - self.lastAlert) < (db.alertCooldown or 20) then return end
	self.lastAlert = now

	self:RunChecklist(trigger or "zone")
end

-- ---------------------------------------------------------------------------
-- Exécution de la checklist
-- ---------------------------------------------------------------------------
function ns:RunChecklist(trigger)
	local db = self:DB()
	local results = {}
	local totalWeight, weighted = 0, 0

	for _, def in ipairs(self.checks or {}) do
		local labelText = def.label
		if type(labelText) == "function" then labelText = labelText() end
		labelText = tostring(labelText or def.id)

		local active = true
		if def.active then
			local okActive, res = pcall(def.active, db)
			active = okActive and res == true
		end

		if not self:IsModuleEnabled(def.id) or not active then
			-- Exclu du calcul : poids nul, donc aucune influence sur la note
			results[#results + 1] = {
				id       = def.id,
				label    = labelText,
				ok       = true,
				disabled = true,
				detail   = self:IsModuleEnabled(def.id) and L.MODULE_OFF_ZERO or L.MODULE_OFF,
				score    = 0,
				weight   = 0,
				advice   = def.advice,
			}
		else
			local okRun, okState, detail, score = pcall(def.run, db)
			if not okRun then
				self:RecordError("check:" .. tostring(def.id), okState)
			end
			if okRun then
				local points = tonumber(score) or (okState and 100 or 40)
				if points < 0 then points = 0 elseif points > 100 then points = 100 end
				local weight = def.weight or 1

				results[#results + 1] = {
					id     = def.id,
					label  = labelText,
					ok     = okState == true,
					detail = tostring(detail or ""),
					score  = points,
					weight = weight,
					advice = def.advice,
				}

				totalWeight = totalWeight + weight
				weighted = weighted + (points * weight)
			end
		end
	end

	self.score = 0
	if totalWeight > 0 then
		self.score = math.floor((weighted / totalWeight) + 0.5)
	end
	self.lastResults = results

	-- Conseils : un par module en échec, les plus lourds d'abord
	local advice = {}
	for _, result in ipairs(results) do
		if not result.ok and result.advice then
			local text = L[result.advice]
			if text then advice[#advice + 1] = { text = text, weight = result.weight } end
		end
	end
	table.sort(advice, function(a, b) return a.weight > b.weight end)
	self.lastAdvice = advice

	if db.showWindow and self.ShowWindow then
		self:ShowWindow(results)
	else
		self:PrintSummary(results)
	end
end

-- ---------------------------------------------------------------------------
-- Position des fenêtres : mémorisée, et déplaçable à la souris
-- ---------------------------------------------------------------------------
function ns:RestorePoint(frame, key, defaults)
	if not frame then return end
	defaults = defaults or { point = "CENTER", x = 0, y = 0 }

	local saved = self:DB()[key] or defaults
	local point = saved.point or defaults.point
	local x = saved.x or defaults.x
	local y = saved.y or defaults.y

	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, point, x, y)

	if frame.SetScript then
		frame:SetScript("OnDragStop", function(f)
			f:StopMovingOrSizing()
			local p, _, _, px, py = f:GetPoint(1)
			ns:DB()[key] = {
				point = p or defaults.point,
				x = px or defaults.x,
				y = py or defaults.y,
			}
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Activation / désactivation des modules
-- ---------------------------------------------------------------------------
function ns:IsModuleEnabled(id)
	local db = self:DB()
	if type(db.modules) ~= "table" then db.modules = {} end
	return db.modules[id] ~= false
end

function ns:SetModuleEnabled(id, enabled)
	local db = self:DB()
	if type(db.modules) ~= "table" then db.modules = {} end
	db.modules[id] = enabled and true or false
end

function ns:EnabledModuleCount()
	local total, active = 0, 0
	for _, def in ipairs(self.checks or {}) do
		total = total + 1
		if self:IsModuleEnabled(def.id) then active = active + 1 end
	end
	return active, total
end

-- ---------------------------------------------------------------------------
-- Bilan textuel du score
-- ---------------------------------------------------------------------------
function ns:ScoreLabel()
	local score = self.score or 0
	if score >= 85 then return L.SCORE_READY, "green" end
	if score >= 60 then return L.SCORE_RESERVES, "orange" end
	return L.SCORE_NOT, "red"
end

-- ---------------------------------------------------------------------------
-- Alerte continue "sacs pleins" (indépendante des départs de zone)
--   Hystérésis : alerte au franchissement du seuil vers le bas, réarmement
--   seulement quand on repasse au-dessus du seuil + 2.
-- ---------------------------------------------------------------------------
function ns:CheckBagPressure()
	local db = self:DB()
	if db.enabled == false then return end
	if db.continuousBagAlert == false then return end
	if type(self.FreeBagSlots) ~= "function" then return end

	local free = self.FreeBagSlots()
	local threshold = db.bagFreeThreshold or 4

	if free > threshold then
		if free > threshold + 2 then self.bagAlerted = false end
		return
	end
	if self.bagAlerted then return end

	self.bagAlerted = true
	self:Print(self:F("MSG_BAG_PRESSURE", free))
end

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
ns.handlers = {
	PLAYER_ENTERING_WORLD = function(self, isInitialLogin, isReloadingUi)
		local db = self:DB()
		self:LearnFromSignals()
		self.inSafe = self:IsCurrentZoneSafe()
		self.quietUntil = Now() + (db.quietAfterLogin or 15)
		if db.showMinimap ~= false and self.ShowMinimapButton then self:ShowMinimapButton() end

		-- Relevé de référence pour le résumé de changement de stuff
		if self.CaptureStatBaseline then pcall(function() self:CaptureStatBaseline() end) end
		if self.InitPlayerFrameHooks then pcall(function() self:InitPlayerFrameHooks() end) end
	end,

	ZONE_CHANGED_NEW_AREA = function(self)
		self:LearnFromSignals()
		self:Evaluate("zone")
	end,

	ZONE_CHANGED = function(self)
		self:Evaluate("zone")
	end,

	PLAYER_UPDATE_RESTING = function(self)
		self:LearnFromSignals()
		self:Evaluate("rest")
	end,

	-- Un vendeur ou une boîte aux lettres = village. On apprend, et on considère
	-- qu'on est dans une zone sûre même si elle ne donne pas de repos.
	MERCHANT_SHOW = function(self)
		self:LearnZone("merchant")
		self.inSafe = self:IsCurrentZoneSafe()
	end,

	MAIL_SHOW = function(self)
		self:LearnZone("mail")
		self.inSafe = self:IsCurrentZoneSafe()
	end,

	UNIT_AURA = function(self, unit)
		if unit ~= "player" then return end
		if self.ScanBuffs then self:ScanBuffs() end
	end,

	BAG_UPDATE_DELAYED = function(self)
		self:CheckBagPressure()
		if self.InvalidateReagents then self:InvalidateReagents() end
	end,

	TRACKED_RECIPE_UPDATE = function(self)
		if self.InvalidateReagents then self:InvalidateReagents() end
	end,

	PLAYER_EQUIPMENT_CHANGED = function(self)
		-- différé : le client n'a pas toujours recalculé à l'instant de l'event
		if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
			C_Timer.After(0.2, function() self:OnEquipmentChanged() end)
		elseif self.OnEquipmentChanged then
			self:OnEquipmentChanged()
		end
	end,

	TRADE_SKILL_UPDATE = function(self)
		if self.ScanLegacyTradeSkill then self:ScanLegacyTradeSkill() end
		if self.InvalidateReagents then self:InvalidateReagents() end
	end,
}

function ns:OnEvent(event, ...)
	local handler = self.handlers[event]
	if handler then
		local ok, err = pcall(handler, self, ...)
		if not ok then
			self.lastError = tostring(err)
			self:RecordError(event, err)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Commandes
-- ---------------------------------------------------------------------------
local COMMANDS = {
	["on"] = function(self) self:DB().enabled = true; self:Print(L.MSG_ON) end,
	["off"] = function(self) self:DB().enabled = false; self:Print(L.MSG_OFF) end,
	["safe"] = function(self)
		local mapID = self:CurrentMap()
		if not mapID then return self:Print(L.MSG_NO_ZONE) end
		if self:DB().safe[mapID] then
			return self:Print(self:F("MSG_SAFE_EXISTS", self:DB().safe[mapID].name))
		end
		self:LearnZone("manual")
		self.inSafe = true
		self:Print(self:F("MSG_SAFE_ADDED", self:DB().safe[mapID].name))
	end,
	["unsafe"] = function(self)
		local db = self:DB()
		local mapID = self:CurrentMap()
		if not mapID or not db.safe[mapID] then return self:Print(L.MSG_SAFE_UNKNOWN) end
		local name = db.safe[mapID].name
		db.safe[mapID] = nil
		self.inSafe = false
		self:Print(self:F("MSG_SAFE_REMOVED", name))
	end,
	["list"] = function(self)
		local db = self:DB()
		local rows = {}
		for mapID, entry in pairs(db.safe) do
			rows[#rows + 1] = { mapID = mapID, name = entry.name or tostring(mapID), source = entry.source or "?" }
		end
		table.sort(rows, function(a, b) return tostring(a.name) < tostring(b.name) end)
		self:Print(self:F("MSG_LIST_HEADER", #rows))
		for _, row in ipairs(rows) do
			self:Print(self:F("MSG_LIST_ROW", row.name, row.source))
		end
	end,
	["buffs"] = function(self)
		local db = self:DB()
		local list = TrackedList(self)
		self:Print(self:F("MSG_BUFFS_HEADER", #list))
		for i, entry in ipairs(list) do
			local state = entry.enabled and "ON" or "off"
			self:Print(self:F("MSG_BUFFS_ROW", i, entry.name or tostring(entry.spellId), state))
		end
	end,
	["buff"] = function(self, indexText)
		local db = self:DB()
		local list = TrackedList(self)
		local index = tonumber(indexText)
		if not index or not list[index] then return self:Print(L.MSG_UNKNOWN_CMD) end
		local entry = list[index]
		entry.enabled = not entry.enabled
		self:Print(self:F("MSG_BUFF_TOGGLED", index, entry.enabled and "ON" or "off"))
	end,
	["seuil"] = function(self, value)
		local db = self:DB()
		local n = tonumber(value)
		if not n then return self:Print(L.MSG_UNKNOWN_CMD) end
		db.bagFreeThreshold = math.floor(n)
		self:Print(self:F("MSG_THRESHOLD", db.bagFreeThreshold))
	end,
	["popup"] = function(self, value)
		local db = self:DB()
		if value == "off" then
			db.showWindow = false
			self:Print(L.MSG_POPUP_OFF)
		else
			db.showWindow = true
			self:Print(L.MSG_POPUP_ON)
		end
	end,
	["reset"] = function(self)
		for k in pairs(ReadyToQuestDB or {}) do ReadyToQuestDB[k] = nil end
		self._dbReady = false
		self:DB()
		self.inSafe = nil
		self:Print(L.MSG_RESET)
	end,
	["options"] = function(self)
		if self.ToggleOptions then
			self:ToggleOptions()
		else
			self:Print(L.MSG_UNKNOWN_CMD)
		end
	end,
	["config"] = function(self)
		if self.ToggleOptions then
			self:ToggleOptions()
		else
			self:Print(L.MSG_UNKNOWN_CMD)
		end
	end,
	-- le panneau a été supprimé : la commande affiche désormais le résumé en
	-- chat, pour ne pas casser l'habitude ni renvoyer une erreur
	["stuff"] = function(self)
		if self.ShowGearSummary then
			self:ShowGearSummary()
		else
			self:Print(L.MSG_UNKNOWN_CMD)
		end
	end,
	["toast"] = function(self, value)
		local db = self:DB()
		if value == "on" then
			db.showGearToast = true
			return self:Print(L.MSG_TOAST_ON)
		end
		if value == "off" then
			db.showGearToast = false
			return self:Print(L.MSG_TOAST_OFF)
		end
		db.showGearToast = not (db.showGearToast ~= false)
		self:Print(db.showGearToast and L.MSG_TOAST_ON or L.MSG_TOAST_OFF)
	end,
	["move"] = function(self, value)
		if not self.ToggleEditMode then return self:Print(L.MSG_UNKNOWN_CMD) end
		if value == "stop" then
			self:StopEditMode()
		else
			self:ToggleEditMode()
		end
	end,
	["resetpos"] = function(self)
		local db = self:DB()
		db.toastPoint = { point = "CENTER", x = 260, y = 20 }
		db.portraitPoint = { point = "CENTER", x = -260, y = 20 }
		db.portraitManual = false
		if self.toastFrame then
			self.toastFrame:ClearAllPoints()
			self.toastFrame:SetPoint("CENTER", UIParent, "CENTER", 260, 20)
		end
		if self.portraitFrame then
			self.portraitFrame:Hide()
			self.portraitFrame:ClearAllPoints()
			self.portraitFrame:SetPoint("CENTER", UIParent, "CENTER", -260, 20)
		end
		self:Print(L.MSG_POS_RESET)
	end,
	["stats"] = function(self)
		if not self.ShowPortraitStats then return self:Print(L.MSG_UNKNOWN_CMD) end
		self:ShowPortraitStats()
	end,
	["portrait"] = function(self, value)
		local db = self:DB()
		if value == "on" then
			db.showPortraitStats = true
			return self:Print(L.MSG_PORTRAIT_ON)
		end
		if value == "off" then
			db.showPortraitStats = false
			if self.HidePortraitStats then self:HidePortraitStats() end
			return self:Print(L.MSG_PORTRAIT_OFF)
		end
		db.showPortraitStats = not (db.showPortraitStats ~= false)
		self:Print(db.showPortraitStats and L.MSG_PORTRAIT_ON or L.MSG_PORTRAIT_OFF)
	end,
	["modules"] = function(self)
		local active, total = self:EnabledModuleCount()
		self:Print(self:F("MSG_MODULE_LIST", active, total))
		for _, def in ipairs(self.checks or {}) do
			local label = def.label
			if type(label) == "function" then label = label() end
			local on = self:IsModuleEnabled(def.id)
			local state = on and ("|cff1eff00" .. L.MODULE_ON .. "|r")
				or ("|cffff2020" .. L.MODULE_OFF .. "|r")
			self:Print(self:F("MSG_MODULE_ROW", tostring(def.id), state .. "  " .. tostring(label)))
		end
	end,
	["module"] = function(self, rest)
		local id, value = tostring(rest or ""):match("^(%S*)%s*(%S*)$")
		if not id or id == "" then return self:Print(L.MSG_MODULE_UNKNOWN) end

		local found = nil
		for _, def in ipairs(self.checks or {}) do
			if def.id == id then found = def end
		end
		if not found then return self:Print(L.MSG_MODULE_UNKNOWN) end

		local enabled
		if value == "on" then
			enabled = true
		elseif value == "off" then
			enabled = false
		else
			enabled = not self:IsModuleEnabled(id)
		end
		self:SetModuleEnabled(id, enabled)

		local label = found.label
		if type(label) == "function" then label = label() end
		self:Print(self:F("MSG_MODULE_SET", tostring(label or id),
			enabled and L.MODULE_ON or L.MODULE_OFF))
		if self.RefreshOptions then self:RefreshOptions() end
	end,
	["minimap"] = function(self, value)
		if not self.ToggleMinimapButton then return self:Print(L.MSG_UNKNOWN_CMD) end
		local db = self:DB()
		if value == "on" then
			db.showMinimap = true
			self:ShowMinimapButton()
			return self:Print(L.MSG_MINIMAP_ON)
		end
		if value == "off" then
			db.showMinimap = false
			self:HideMinimapButton()
			return self:Print(L.MSG_MINIMAP_OFF)
		end
		local shown = self:ToggleMinimapButton()
		self:Print(shown and L.MSG_MINIMAP_ON or L.MSG_MINIMAP_OFF)
	end,
	["panneau"] = function(self)
		self:RunChecklist("manual")
	end,
	["compo"] = function(self)
		if self.PrintReagents then
			self:PrintReagents()
		else
			self:Print(L.CHK_REAGENTS_NONE)
		end
	end,
	["diag"] = function(self)
		self:Print(L.MSG_DIAG_HEADER .. " v" .. tostring(ns.version or "?"))
		if self.PrintCapabilities then self:PrintCapabilities() end

		-- État du chargement des fichiers
		local loaded, missing = {}, {}
		for _, name in ipairs({ "Bootstrap", "Locales", "Compat", "Theme", "Core", "Buffs",
			"Reagents", "Equip", "Stats", "Minimap", "Checks", "Options", "UI" }) do
			if ns.Loaded and ns.Loaded[name] then loaded[#loaded + 1] = name else missing[#missing + 1] = name end
		end
		self:Print(string.format("  modules : |cff1eff00%d/%d|r chargés",
			#loaded, #loaded + #missing))
		if #missing > 0 then
			self:Print("  |cffff2020non chargés :|r " .. table.concat(missing, ", "))
		end
		if self.unsupportedEvents and #self.unsupportedEvents > 0 then
			self:Print("  |cffff8c1aévénements non supportés :|r " .. table.concat(self.unsupportedEvents, ", "))
		end
		if ns.errors and #ns.errors > 0 then
			for _, entry in ipairs(ns.errors) do
				self:Print("  |cffff2020erreur|r " .. tostring(entry.where) .. " : " .. tostring(entry.message))
			end
		end
		local mapID = self:CurrentMap()
		local info = self:MapInfo(mapID)
		self:Print(self:F("MSG_DIAG_MAP", tostring(mapID), tostring(info and info.parentMapID), tostring(info and info.name)))
		local safe, why = self:IsCurrentZoneSafe()
		self:Print(self:F("MSG_DIAG_SAFE", tostring(safe) .. " (" .. tostring(why) .. ")"))
		if self.DiagAuras then self:DiagAuras() else self:Print(L.MSG_DIAG_NOAURA) end
	end,
}

function ns:HandleCommand(input)
	local db = self:DB()
	local command, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
	command = (command or ""):lower()

	if command == "" then
		self:RunChecklist("manual")
		return
	end

	local fn = COMMANDS[command]
	if fn then
		fn(self, rest)
		return
	end

	self:Print(L.MSG_UNKNOWN_CMD)
	for i = 1, 20 do
		local line = L["CMD_HELP_" .. i]
		if line then self:Print(line) end
	end
end

-- ---------------------------------------------------------------------------
-- Amorçage
-- ---------------------------------------------------------------------------
-- Enregistrement défensif : un événement inconnu du client (ex. TRACKED_RECIPE_UPDATE,
-- apparu en retail 10.x) ne doit pas empêcher l'addon de fonctionner.
-- Événements optionnels : présents seulement si la capacité correspondante existe.
-- Cela évite même d'appeler RegisterEvent sur un client qui ne connaît pas
-- l'événement (cas de TRACKED_RECIPE_UPDATE, retail 10.x uniquement).
local OPTIONAL_EVENTS = {
	TRACKED_RECIPE_UPDATE = "crafting",
	TRADE_SKILL_UPDATE = "tradeskillLegacy",
}

function ns:RegisterEvents(target)
	target = target or self.eventFrame
	if not target then return {} end

	local skipped = {}
	for event in pairs(self.handlers) do
		local requirement = OPTIONAL_EVENTS[event]
		local available = true
		if requirement then
			available = (ns.Caps and ns.Caps[requirement]) and true or false
		end

		if available then
			local ok = pcall(target.RegisterEvent, target, event)
			if not ok then skipped[#skipped + 1] = event end
		end
	end
	if #skipped > 0 then
		self.unsupportedEvents = skipped
		if self.RecordError then
			self:RecordError("événements", "non supportés par ce client : " .. table.concat(skipped, ", "))
		end
	end
	return skipped
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
	ns:OnEvent(event, ...)
end)
frame:SetScript("OnUpdate", function()
	-- fondu du résumé éphémère
	if ns.toastHideAt and ns.UpdateToast then
		ns:UpdateToast(ns:Now())
	end
end)
ns:RegisterEvents(frame)

ns.eventFrame = frame


-- API publique minimale, pour un futur addon compagnon
_G.ReadyToQuest = ns

if ns.Mark then ns.Mark("Core") end
