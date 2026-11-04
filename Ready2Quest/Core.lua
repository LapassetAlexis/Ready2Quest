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
	exitDelay           = 6,      -- secondes hors zone sûre avant l'alerte (0..15)
	popupScore          = 85,     -- fenêtre seulement sous cette note (100 = toujours)
	departureEnabled    = true,   -- module « Check avant le départ »
	autoSellGray        = true,   -- vend les objets gris à l'ouverture d'un marchand
	autoRepair          = true,   -- répare tout chez un marchand qui répare
	-- Zones sûres (schéma 2, v1.18.0) :
	--   ["v:<mapID>:<sous-zone>"] = { kind = "village", name, mapID, subzone, source, at }
	--   ["c:<mapID>"]             = { kind = "city",    name, mapID, source, at }
	safe                = {},
	safeClues           = {},     -- [clé village] = { types = { merchant = true, … } }
	cityRest            = {},     -- [mapID] = { [sous-zone] = true } : repos vu dans ces quartiers
	chars               = {},     -- [Nom-Royaume] = { trainerLevel, repairRate }
	buffs               = {},     -- [spellId] = { name, duration, enabled }
	seen                = {},     -- [mapID] = true (zones déjà visitées)
}

ns.RegisterDefaults(DEFAULTS)

-- Sauvegarde (ns:DB, socle commun Libs/Socle/Store.lua) : à sa première
-- lecture, purge des zones sûres de l'ancien schéma.
function ns:OnDBReady(db)
	self:MigrateSafeZones(db)
end

-- Schéma 1 (jusqu'à v1.17) : db.safe[mapID]. Sur Era, un mapID est une zone
-- entière : un repos à Comté-de-l'Or rendait toute la forêt d'Elwynn « sûre »,
-- et la sortie du village n'était plus jamais détectée. Ces entrées ne peuvent
-- pas être converties (on ne sait pas dans quelle sous-zone elles ont été
-- apprises) : on purge une fois, et on prévient.
local SAFE_SCHEMA = 2
function ns:MigrateSafeZones(db)
	if (tonumber(db.safeSchema) or 1) >= SAFE_SCHEMA then return end
	local had = 0
	for _ in pairs(db.safe or {}) do had = had + 1 end
	db.safe, db.safeClues, db.cityRest = {}, {}, {}
	db.safeSchema = SAFE_SCHEMA
	if had > 0 then self.safePurgeNotice = had end
end

local Now = ns.Now

-- Accesseur défensif : Buffs.lua peut ne pas être chargé (ordre de TOC modifié).
local function TrackedList(addon)
	if type(addon.TrackedBuffs) == "function" then
		return addon:TrackedBuffs()
	end
	return {}
end

-- Lecture de la carte (ns:CurrentMap, MapInfo, MapChain) : socle commun,
-- Libs/Socle/World.lua.

-- Signaux "vivants" (pas de la base de données).
-- GetRestState() n'en fait plus partie : il indique un bonus d'XP de repos en
-- réserve, pas la présence dans une auberge. Avec du repos d'avance, le joueur
-- était « en zone sûre » partout, et l'alerte de sortie ne partait jamais.
function ns:LiveSafeSignals()
	local signals = {}

	local fn = rawget(_G, "IsResting")
	if type(fn) == "function" then
		local ok, res = pcall(fn)
		if ok and (res == true or res == 1) then signals[#signals + 1] = "resting" end
	end

	if type(UnitIsPVPSanctuary) == "function" then
		local ok, res = pcall(UnitIsPVPSanctuary, "player")
		if ok and (res == true or res == 1) then signals[#signals + 1] = "sanctuary" end
	end

	return signals
end

-- ns:CurrentSubZone : socle commun, Libs/Socle/World.lua.

local function VillageKey(mapID, subzone) return "v:" .. tostring(mapID) .. ":" .. tostring(subzone) end
local function CityKey(mapID) return "c:" .. tostring(mapID) end
ns.VillageKey, ns.CityKey = VillageKey, CityKey

-- Renvoie : sûr ?, mapID, raison ("resting"/"sanctuary"/"city"/"village"), entrée apprise
-- Lieux connus (ns:HubIndex, PlayerFaction, KnownHub), ns:InInstance et
-- ns:AtCamp : socle commun, Libs/Socle/World.lua.

function ns:IsCurrentZoneSafe()
	local db = self:DB()
	local mapID = self:CurrentMap()
	local subzone = self:CurrentSubZone()

	if self:InInstance() then return false, mapID, nil, nil end
	if self:AtCamp() then
		return true, mapID, "camp", { name = L.CAMP_PLACE, source = "camp" }
	end
	local hub, hubName, hostile = self:KnownHub()
	if hub then
		return true, mapID, "known", { name = hubName, source = "known", kind = hub.kind }
	end
	if hostile then return false, mapID, "hostile", nil end

	-- camp sans sous-zone à lui, repéré par ses PNJ de service (Places.lua)
	local place, _, hostilePlace = self:KnownPlace()
	if place then
		local zone = (self:MapInfo(mapID) or {}).name
		return true, mapID, "place", { name = subzone or zone or "?", source = "known", kind = "place" }
	end
	if hostilePlace then return false, mapID, "hostile", nil end

	if mapID then
		for _, id in ipairs(self:MapChain(mapID)) do
			local city = db.safe[CityKey(id)]
			if city then return true, mapID, "city", city end
		end
		if subzone then
			local village = db.safe[VillageKey(mapID, subzone)]
			if village then return true, mapID, "village", village end
		end
	end

	local signals = self:LiveSafeSignals()
	if #signals > 0 then return true, mapID, signals[1], nil end
	return false, mapID, nil, nil
end

-- ---------------------------------------------------------------------------
-- Apprentissage des zones sûres, par indices
--   fort  : un seul suffit (repos, aubergiste, maître de vol, courrier, banque)
--   moyen / faible : il en faut deux de types différents dans la même sous-zone
--   capitale : repos vu dans au moins deux sous-zones d'une même carte
-- ---------------------------------------------------------------------------
-- Le repos n'est plus un indice fort : sur Forever, on est « au repos » à un
-- feu de camp en pleine nature. Il compte comme un indice parmi d'autres.
ns.CLUE_STRENGTH = {
	binder = "strong", taxi = "strong", mail = "strong", bank = "strong",
	resting = "medium", trainer = "medium",
	merchant = "weak", quest = "weak",
}
ns.CLUES_NEEDED = 2

local function Learn(self, key, entry)
	local db = self:DB()
	if db.safe[key] then return false end
	entry.at = Now()
	db.safe[key] = entry
	db.safeClues[key] = nil
	if db.verboseLearn then
		self:Print(self:F("MSG_LEARNED", entry.name, self:SourceLabel(entry.source)))
	end
	return true
end

function ns:LearnVillage(source)
	local mapID, subzone = self:CurrentMap(), self:CurrentSubZone()
	if not mapID or not subzone then return false end
	return Learn(self, VillageKey(mapID, subzone), {
		kind = "village", name = subzone, mapID = mapID, subzone = subzone, source = source or "manual",
	})
end

function ns:LearnCity(mapID, source)
	if not mapID then return false end
	local info = self:MapInfo(mapID)
	return Learn(self, CityKey(mapID), {
		kind = "city", name = (info and info.name) or tostring(mapID), mapID = mapID, source = source or "resting",
	})
end

-- Un indice observé dans la sous-zone courante. Renvoie true si une zone a été apprise.
function ns:AddClue(clue)
	local db = self:DB()
	local mapID, subzone = self:CurrentMap(), self:CurrentSubZone()
	if not mapID then return false end
	-- rien à apprendre : instance, camp, lieu déjà connu de la base (ou hostile)
	if self:InInstance() or self:AtCamp() then return false end
	local _, knownName = self:KnownHub()
	if knownName then return false end
	local learned = false

	-- Capitale : le repos couvre toute la ville, quartier après quartier
	if clue == "resting" and subzone then
		db.cityRest[mapID] = db.cityRest[mapID] or {}
		db.cityRest[mapID][subzone] = true
		local count = 0
		for _ in pairs(db.cityRest[mapID]) do count = count + 1 end
		if count >= 2 then learned = self:LearnCity(mapID, "resting") or learned end
	end

	if not subzone then return learned end
	local key = VillageKey(mapID, subzone)
	if db.safe[key] then return learned end

	local strength = self.CLUE_STRENGTH[clue]
	if strength == "strong" then
		return self:LearnVillage(clue) or learned
	end
	if not strength then return learned end

	local entry = db.safeClues[key] or { types = {} }
	db.safeClues[key] = entry
	entry.types[clue] = true
	local types = {}
	for name in pairs(entry.types) do types[#types + 1] = name end
	if #types >= self.CLUES_NEEDED then
		table.sort(types)
		return self:LearnVillage(table.concat(types, "+")) or learned
	end
	return learned
end

function ns:LearnFromSignals()
	for _, signal in ipairs(self:LiveSafeSignals()) do
		if signal == "resting" then self:AddClue("resting") end
	end
end

-- Libellé lisible d'une source ("merchant+quest" -> "marchand + quête")
function ns:SourceLabel(source)
	local parts = {}
	for name in tostring(source or "?"):gmatch("[^+]+") do
		parts[#parts + 1] = L["SRC_" .. name:upper()] or name
	end
	return table.concat(parts, " + ")
end

-- ---------------------------------------------------------------------------
-- Machine à états : sûre -> non sûre, confirmée après un délai
--   * retour en zone sûre avant la fin du délai : annulé
--   * en vol (taxi) : reporté à l'atterrissage
--   * mort ou fantôme : ignoré
-- ---------------------------------------------------------------------------
local function UnitFlag(fnName)
	local fn = rawget(_G, fnName)
	if type(fn) ~= "function" then return false end
	local ok, res = pcall(fn, "player")
	return ok and (res == true or res == 1)
end

function ns:ExitDelay()
	local value = tonumber(self:DB().exitDelay) or 6
	if value < 0 then value = 0 elseif value > 15 then value = 15 end
	return value
end

-- Vérification périodique (toutes les PLACE_CHECK secondes) sur une carte qui
-- a des lieux repérés : seulement après la première évaluation (connexion).
ns.PLACE_CHECK = 1.5
function ns:CheckPlaceMove(now)
	if self.inSafe == nil or (self.nextPlaceCheck or 0) > now then return end
	self.nextPlaceCheck = now + self.PLACE_CHECK
	if self.MapHasPlaces and self:MapHasPlaces() then self:Evaluate("move") end
end

function ns:Evaluate(trigger)
	local db = self:DB()
	if not db.enabled then self.pendingExit = nil; return end

	local safe, _, reason, entry = self:IsCurrentZoneSafe()
	local previous = self.inSafe
	self.inSafe = safe
	self.safeReason = safe and reason or nil

	if safe then
		self.pendingExit = nil
		self.lastSafePlace = {
			name = (entry and entry.name) or self:CurrentSubZone()
				or ((self:MapInfo(self:CurrentMap()) or {}).name) or "?",
			source = (entry and entry.source) or reason,
		}
		-- retour en zone sûre après un départ confirmé (Retour d'expédition)
		if self.departed then
			self.departed = nil
			self:FireCallback("RETURN", self.lastSafePlace)
		end
		return
	end

	if previous == nil then return end          -- première évaluation : on pose la référence
	if not previous then return end             -- déjà dehors : rien de neuf

	self.pendingExit = { at = Now(), from = self.lastSafePlace, trigger = trigger or "zone" }
	if self:ExitDelay() <= 0 then self:UpdatePendingExit(Now()) end
end

-- Appelé à chaque image (OnUpdate) : confirme la sortie une fois le délai écoulé
function ns:UpdatePendingExit(now)
	local pending = self.pendingExit
	if not pending then return end
	now = now or Now()

	if UnitFlag("UnitIsDeadOrGhost") then self.pendingExit = nil; return end
	if UnitFlag("UnitOnTaxi") then
		pending.taxi = true
		pending.at = now                            -- le délai repart à l'atterrissage
		return
	end
	if now - pending.at < self:ExitDelay() then return end
	-- en combat : la fenêtre attendra la fin du combat (elle partirait au
	-- pire moment, et la note serait faussée par le combat lui-même)
	if UnitFlag("UnitAffectingCombat") then pending.combat = true; return end

	self.pendingExit = nil
	if self:IsCurrentZoneSafe() then self.inSafe = true; return end

	local db = self:DB()
	-- le départ est réel dès ici : les filtres qui suivent ne coupent que
	-- l'alerte (les autres modules, eux, suivent toujours le départ)
	self.departed = true
	self:FireCallback("DEPARTURE", pending.from)
	if db.departureEnabled == false then return end
	if self.quietUntil and now < self.quietUntil then return end
	if self.lastAlert and (now - self.lastAlert) < (db.alertCooldown or 20) then return end
	self.lastAlert = now
	self.lastDeparture = pending.from
	self:RunChecklist(pending.trigger)
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
				icon     = def.icon,
				ok       = true,
				disabled = true,
				-- inactif = sans objet (pas un choix du joueur) : masqué à l'écran
				inactive = self:IsModuleEnabled(def.id) or nil,
				detail   = self:IsModuleEnabled(def.id) and (def.inactiveText and L[def.inactiveText] or L.MODULE_OFF_ZERO) or L.MODULE_OFF,
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
					icon   = def.icon,
					info   = def.info or nil,
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
		if not result.ok and result.advice and not result.info then
			local text = L[result.advice]
			if text then advice[#advice + 1] = { text = text, weight = result.weight } end
		end
	end
	table.sort(advice, function(a, b) return a.weight > b.weight end)
	self.lastAdvice = advice
	self.lastTrigger = trigger
	self:FireCallback("CHECKLIST", results)
	if trigger == "manual" then self.lastDeparture = nil end

	if db.showWindow and self.ShowWindow and not self:IsDiscreetAlert(trigger) then
		-- départ (pas un check manuel) : une icône annonce le rapport (Notice.lua)
		if trigger ~= "manual" and self.WantsNotice and self:WantsNotice() then
			self:PrintBrief()
			local notice = self:NoticeDepart(self.score, (self:ScoreLabel()))
			notice.onClick = function() ns:ShowWindow(results) end
			self:ShowNotice(notice)
		else
			self:ShowWindow(results)
		end
	elseif db.showWindow and self.ShowWindow then
		self:PrintBrief()
	else
		self:PrintSummary(results)
	end
end

-- Alerte de sortie avec une bonne note : une ligne dans le chat plutôt
-- qu'une fenêtre au milieu de l'écran. Au bout de dix sorties « tout va
-- bien », une fenêtre systématique se ferme sans être lue.
-- popupScore = 100 : toujours la fenêtre. Un check manuel l'ouvre toujours.
function ns:IsDiscreetAlert(trigger)
	if trigger == "manual" then return false end
	local threshold = tonumber(self:DB().popupScore) or 85
	if threshold >= 100 then return false end
	return (self.score or 0) >= threshold
end

function ns:PrintBrief()
	local from = self.lastDeparture
	local suffix = ""
	if from and from.name then suffix = self:F("MSG_BRIEF_FROM", tostring(from.name)) end
	local _, color = self:ScoreLabel()
	local key = (color == "green" and "MSG_BRIEF_READY") or (color == "orange" and "MSG_BRIEF_RESERVES") or "MSG_BRIEF_NOT"
	self:Print(self:F(key, self.score or 0, suffix))
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
	if db.departureEnabled == false then return end
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
		if self.safePurgeNotice then
			self:Print(self:F("MSG_SAFE_PURGED", self.safePurgeNotice))
			self.safePurgeNotice = nil
		end
		self:LearnFromSignals()
		self.inSafe = nil
		self:Evaluate("login")
		self.quietUntil = Now() + (db.quietAfterLogin or 15)
		if db.showMinimap ~= false and self.ShowMinimapButton then self:ShowMinimapButton() end
		if self.InitCharacterTracking then pcall(function() self:InitCharacterTracking() end) end

		-- Relevé de référence pour le résumé de changement de stuff
		if self.CaptureStatBaseline then pcall(function() self:CaptureStatBaseline() end) end
		if self.InitPlayerFrameHooks then pcall(function() self:InitPlayerFrameHooks() end) end
	end,

	ZONE_CHANGED_NEW_AREA = function(self)
		self:LearnFromSignals()
		self:Evaluate("zone")
	end,

	-- Changement de sous-zone : c'est l'événement qui marque la sortie d'un village
	ZONE_CHANGED = function(self)
		self:LearnFromSignals()
		self:Evaluate("zone")
	end,

	ZONE_CHANGED_INDOORS = function(self)
		self:LearnFromSignals()
		self:Evaluate("zone")
	end,

	PLAYER_UPDATE_RESTING = function(self)
		self:LearnFromSignals()
		self:Evaluate("rest")
	end,

	-- Indices de village : chaque PNJ de service apporte un indice dans la
	-- sous-zone courante (voir ns.CLUE_STRENGTH).
	MERCHANT_SHOW = function(self)
		self:AddClue("merchant")
		self:Evaluate("learn")
		if self.OnMerchantShow then self:OnMerchantShow() end
	end,

	MERCHANT_CLOSED = function(self)
		if self.OnMerchantClosed then self:OnMerchantClosed() end
	end,

	MAIL_SHOW = function(self) self:AddClue("mail"); self:Evaluate("learn") end,
	CONFIRM_BINDER = function(self) self:AddClue("binder"); self:Evaluate("learn") end,
	TAXIMAP_OPENED = function(self) self:AddClue("taxi"); self:Evaluate("learn") end,
	BANKFRAME_OPENED = function(self) self:AddClue("bank"); self:Evaluate("learn") end,
	QUEST_DETAIL = function(self) self:AddClue("quest"); self:Evaluate("learn") end,
	QUEST_GREETING = function(self) self:AddClue("quest"); self:Evaluate("learn") end,
	QUEST_COMPLETE = function(self) self:AddClue("quest"); self:Evaluate("learn") end,

	TRAINER_SHOW = function(self)
		self:AddClue("trainer")
		self:Evaluate("learn")
		if self.OnTrainerShow then self:OnTrainerShow() end
	end,

	UNIT_AURA = function(self, unit)
		if unit ~= "player" then return end
		-- arrivée au camp / départ du camp (Forever) : l'aura change, pas la zone
		local atCamp = self:AtCamp()
		if atCamp ~= self.wasAtCamp then
			self.wasAtCamp = atCamp
			self:Evaluate("camp")
		end
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

	TRADE_SKILL_SHOW = function(self)
		if self.ScanLegacyTradeSkill then self:ScanLegacyTradeSkill() end
		if self.InvalidateReagents then self:InvalidateReagents() end
	end,

	CRAFT_SHOW = function(self)
		if self.ScanLegacyCraft then self:ScanLegacyCraft() end
		if self.InvalidateReagents then self:InvalidateReagents() end
	end,

	CRAFT_UPDATE = function(self)
		if self.ScanLegacyCraft then self:ScanLegacyCraft() end
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
function ns:ListSafeZones()
	local db = self:DB()
	local rows = {}
	for _, entry in pairs(db.safe) do
		local kind = entry.kind == "city" and L.SAFE_KIND_CITY or L.SAFE_KIND_VILLAGE
		rows[#rows + 1] = { name = tostring(entry.name or "?"), kind = kind, source = self:SourceLabel(entry.source) }
	end
	table.sort(rows, function(a, b) return a.name < b.name end)
	self:Print(self:F("MSG_LIST_HEADER", #rows))
	for _, row in ipairs(rows) do
		self:Print(self:F("MSG_LIST_ROW", row.name, row.kind .. ", " .. row.source))
	end
end

-- Les trois modules du cœur. `id` et `aliases` servent à /r2q module <id>
-- (registre : socle commun, Libs/Socle/Store.lua).
for _, module in ipairs({
	{ id = "depart",   key = "departureEnabled",  label = "OPT_PAGE_DEPARTURE", aliases = { "departure", "check", "depart" } },
	{ id = "stuff",    key = "showGearToast",     label = "OPT_PAGE_TOAST",     aliases = { "toast", "resume", "stuff" } },
	{ id = "portrait", key = "showPortraitStats", label = "OPT_PAGE_PORTRAIT",  aliases = { "stats", "portrait" } },
}) do ns.RegisterModule(module) end


function ns:FindCheck(id)
	for _, def in ipairs(self.checks or {}) do if def.id == id then return def end end
	return nil
end

function ns:SetCheckFromCommand(id, value)
	local found = self:FindCheck(id)
	local enabled
	if value == "on" then enabled = true elseif value == "off" then enabled = false
	else enabled = not self:IsModuleEnabled(id) end
	self:SetModuleEnabled(id, enabled)
	local label = found.label
	if type(label) == "function" then label = label() end
	self:Print(self:F("MSG_CHECK_SET", tostring(label or id), enabled and L.MODULE_ON or L.MODULE_OFF))
	if self.RefreshOptions then self:RefreshOptions() end
end

-- Aide classée par rubrique (titre en ambre, puis les commandes)
ns.HELP = {
	{ "HELP_H_OPEN",   { "HELP_RUN", "HELP_OPTIONS", "HELP_STATS", "HELP_STUFF", "HELP_MOVE" } },
	{ "HELP_H_SAFE",   { "HELP_SAFE", "HELP_UNSAFE", "HELP_SAFELIST", "HELP_SAFERESET" } },
	{ "HELP_H_MODULE", { "HELP_ON", "HELP_MODULES", "HELP_MODULE", "HELP_CHECKS", "HELP_CHECK" } },
	{ "HELP_H_QUICK",  { "HELP_POPUP", "HELP_TOAST", "HELP_PORTRAIT", "HELP_MINIMAP", "HELP_SEUIL", "HELP_BUFFS" } },
	{ "HELP_H_MISC",   { "HELP_COMPO", "HELP_RESETPOS", "HELP_RESET", "HELP_DIAG" } },
}

-- ns:PrintHelp : socle commun (Libs/Socle/Commands.lua)

local COMMANDS = {
	["on"] = function(self) self:DB().enabled = true; self:Print(L.MSG_ON) end,
	["off"] = function(self) self:DB().enabled = false; self:Print(L.MSG_OFF) end,
	["safe"] = function(self, rest)
		local sub = tostring(rest or ""):lower()
		if sub == "list" then return self:ListSafeZones() end
		if sub == "reset" then
			local db = self:DB()
			db.safe, db.safeClues, db.cityRest = {}, {}, {}
			self.inSafe, self.pendingExit = nil, nil
			return self:Print(L.MSG_SAFE_RESET)
		end
		local mapID, subzone = self:CurrentMap(), self:CurrentSubZone()
		if not mapID then return self:Print(L.MSG_NO_ZONE) end
		if not subzone then return self:Print(L.MSG_NO_SUBZONE) end
		local key = VillageKey(mapID, subzone)
		if self:DB().safe[key] then
			return self:Print(self:F("MSG_SAFE_EXISTS", subzone))
		end
		self:LearnVillage("manual")
		self:Evaluate("learn")
		self:Print(self:F("MSG_SAFE_ADDED", subzone))
	end,
	["unsafe"] = function(self)
		local db = self:DB()
		local mapID, subzone = self:CurrentMap(), self:CurrentSubZone()
		local removed
		if mapID and subzone and db.safe[VillageKey(mapID, subzone)] then
			removed = VillageKey(mapID, subzone)
		elseif mapID then
			for _, id in ipairs(self:MapChain(mapID)) do
				if db.safe[CityKey(id)] then removed = CityKey(id); break end
			end
		end
		if not removed then return self:Print(L.MSG_SAFE_UNKNOWN) end
		local entry = db.safe[removed]
		db.safe[removed] = nil
		db.safeClues[removed] = nil
		if entry.kind == "city" and entry.mapID then db.cityRest[entry.mapID] = nil end
		local name = entry.name
		self.inSafe, self.pendingExit = nil, nil
		self:Evaluate("learn")
		self:Print(self:F("MSG_SAFE_REMOVED", name))
	end,
	["list"] = function(self) self:ListSafeZones() end,
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
		self:ResetDB()
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
	-- v1.22.0 : les 3 vrais modules (et leurs alias), puis les 13 contrôles
	["modules"] = function(self)
		local db = self:DB()
		self:Print(L.MSG_MODULES_HEADER)
		for _, module in ipairs(self.MODULES) do
			local on = db[module.key] ~= false
			local state = on and (ns.Theme.T_GREEN .. L.MODULE_ON .. "|r") or ("|cffff2020" .. L.MODULE_OFF .. "|r")
			self:Print(self:F("MSG_MODULE_ROW", module.id, state .. "  " .. tostring(L[module.label] or module.id)))
		end
		self:Print(L.MSG_MODULES_HINT)
	end,
	["module"] = function(self, rest)
		local id, value = tostring(rest or ""):match("^(%S*)%s*(%S*)$")
		id = (id or ""):lower()
		local module = self:FindModule(id)
		if not module then
			-- compatibilité : « module vivres off » visait un contrôle avant la v1.22.0
			if self:FindCheck(id) then return self:SetCheckFromCommand(id, value) end
			return self:Print(L.MSG_MODULE_UNKNOWN)
		end
		local db = self:DB()
		local enabled
		if value == "on" then enabled = true elseif value == "off" then enabled = false
		else enabled = not (db[module.key] ~= false) end
		db[module.key] = enabled
		if module.key == "showPortraitStats" and not enabled and self.HidePortraitStats then self:HidePortraitStats() end
		if module.key == "departureEnabled" and not enabled then self.pendingExit = nil end
		self:Print(self:F("MSG_MODULE_SET", tostring(L[module.label] or module.id), enabled and L.MODULE_ON or L.MODULE_OFF))
		if self.RefreshOptions then self:RefreshOptions() end
	end,
	["checks"] = function(self)
		local active, total = self:EnabledModuleCount()
		self:Print(self:F("MSG_CHECK_LIST", active, total))
		for _, def in ipairs(self.checks or {}) do
			local label = def.label
			if type(label) == "function" then label = label() end
			local on = self:IsModuleEnabled(def.id)
			local state = on and (ns.Theme.T_GREEN .. L.MODULE_ON .. "|r") or ("|cffff2020" .. L.MODULE_OFF .. "|r")
			self:Print(self:F("MSG_MODULE_ROW", tostring(def.id), state .. "  " .. tostring(label)))
		end
	end,
	["check"] = function(self, rest)
		local id, value = tostring(rest or ""):match("^(%S*)%s*(%S*)$")
		if not id or id == "" or not self:FindCheck(id) then return self:Print(L.MSG_CHECK_UNKNOWN) end
		self:SetCheckFromCommand(id, value)
	end,
	["help"] = function(self) self:PrintHelp() end,
	["aide"] = function(self) self:PrintHelp() end,
	["?"] = function(self) self:PrintHelp() end,
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
		for _, name in ipairs({ "Bootstrap", "Locales", "Compat", "Hubs", "Theme", "Core", "Buffs",
			"Reagents", "Merchant", "Equip", "Stats", "Minimap", "Checks", "Options", "UI" }) do
			if ns.Loaded and ns.Loaded[name] then loaded[#loaded + 1] = name else missing[#missing + 1] = name end
		end
		self:Print(string.format("  modules : " .. ns.Theme.T_GREEN .. "%d/%d|r chargés",
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
		local safe, _, why = self:IsCurrentZoneSafe()
		self:Print(self:F("MSG_DIAG_SAFE", tostring(safe) .. " (" .. tostring(why) .. ", "
			.. tostring(self:CurrentSubZone()) .. ")"))
		if self.DiagAuras then self:DiagAuras() else self:Print(L.MSG_DIAG_NOAURA) end
	end,
}

-- Commande sans argument : le check. Le reste (ns:HandleCommand, registre
-- ns.COMMANDS, aide, options, minimap…) est dans le socle commun
-- (Libs/Socle/Commands.lua) ; les commandes du cœur s'y ajoutent ici et
-- priment sur les versions communes.
function ns:DefaultCommand()
	self:RunChecklist("manual")
end
for name, fn in pairs(COMMANDS) do ns.COMMANDS[name] = fn end

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
	TRADE_SKILL_SHOW = "tradeskillLegacy",
	CRAFT_SHOW = "craftLegacy",
	CRAFT_UPDATE = "craftLegacy",
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
	-- sortie de zone sûre en attente de confirmation
	if ns.pendingExit then ns:UpdatePendingExit(ns:Now()) end
	-- lieux repérés par leurs PNJ (Places.lua) : y entrer ou en sortir ne
	-- change pas forcément de sous-zone, aucun événement ne le dit. On regarde.
	ns:CheckPlaceMove(ns:Now())
end)
ns:RegisterEvents(frame)

ns.eventFrame = frame


-- API publique : QuestCompanion s'y abonne aux départs et retours de zone
-- sûre (ns:RegisterCallback("DEPARTURE" | "RETURN"), Libs/Socle/Store.lua)
_G.Ready2Quest = ns
_G.ReadyToQuest = ns   -- ancien nom de l'API publique, gardé en alias

if ns.Mark then ns.Mark("Core") end
