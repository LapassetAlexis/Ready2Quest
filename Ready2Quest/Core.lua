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
	buffRole            = "auto", -- 1.33.3 : auto, TANK, HEALER, DAMAGER (buffs de tank)
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
	diagFoldOk          = true,   -- 1.32.0 : lignes « en ordre » repliées dans « Avant le départ »
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
	-- 1.32.2 : buffs réclamés par défaut (Buffs.lua, schéma 2)
	if type(self.MigrateBuffs) == "function" then self:MigrateBuffs(db) end
	-- 1.34.0 : « toujours garder » de Sac plein -> favoris (Favorites.lua)
	if type(self.MigrateFavorites) == "function" then self:MigrateFavorites(db) end
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

-- Même lecture, le premier signal seulement (aucune table)
local function FirstLiveSignal()
	local fn = rawget(_G, "IsResting")
	if type(fn) == "function" then
		local ok, res = pcall(fn)
		if ok and (res == true or res == 1) then return "resting" end
	end
	if type(UnitIsPVPSanctuary) == "function" then
		local ok, res = pcall(UnitIsPVPSanctuary, "player")
		if ok and (res == true or res == 1) then return "sanctuary" end
	end
	return nil
end

-- ns:CurrentSubZone : socle commun, Libs/Socle/World.lua.

local function VillageKey(mapID, subzone) return "v:" .. tostring(mapID) .. ":" .. tostring(subzone) end
local function CityKey(mapID) return "c:" .. tostring(mapID) end
ns.VillageKey, ns.CityKey = VillageKey, CityKey

-- Renvoie : sûr ?, mapID, raison ("resting"/"sanctuary"/"city"/"village"), entrée apprise
-- Lieux connus (ns:HubIndex, PlayerFaction, KnownHub), ns:InInstance et
-- ns:AtCamp : socle commun, Libs/Socle/World.lua.

-- ignoreCamp : passe le feu de camp pour savoir si l'on est aussi en ville
-- (le bandeau du camp se tait en ville : Camp.lua)
function ns:IsCurrentZoneSafe(ignoreCamp)
	local db = self:DB()
	local mapID = self:CurrentMap()
	local subzone = self:CurrentSubZone()

	if self:InInstance() then return false, mapID, nil, nil end
	if not ignoreCamp and self:AtCamp() then
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

	-- le premier signal vivant, dans l'ordre de LiveSafeSignals, sans sa
	-- table (appelé toutes les PLACE_CHECK s sur une carte à lieux repérés,
	-- et quatre fois par seconde au camp par Camp.lua)
	local signal = FirstLiveSignal()
	if signal then return true, mapID, signal, nil end
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

-- Note plafonnée quand un contrôle bloquant échoue : sous le seuil de « Prêt
-- avec réserves » (60), donc « Pas prêt ».
ns.SCORE_CAP_BLOCKING = 59

-- Zone de départ : tant qu'on n'en est pas sorti, aucune alerte automatique.
-- Un départ est « silencieux » s'il part d'une vallée de départ (Hubs.lua,
-- kind = "start") ou si le personnage est sous QUIET_LEVEL (on quitte sa
-- vallée vers le niveau 5-6). Le check reste disponible à la main.
ns.QUIET_LEVEL = 6
function ns:IsQuietDeparture(from)
	if from and from.kind == "start" then return true end
	local fn = rawget(_G, "UnitLevel")
	if type(fn) ~= "function" then return false end
	local ok, level = pcall(fn, "player")
	level = ok and tonumber(level) or nil
	return level ~= nil and level > 0 and level < self.QUIET_LEVEL
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
		-- même lieu qu'au passage précédent (vérification toutes les
		-- PLACE_CHECK s sur une carte à lieux repérés) : on garde la table
		local name = (entry and entry.name) or self:CurrentSubZone()
			or ((self:MapInfo(self:CurrentMap()) or {}).name) or "?"
		local source = (entry and entry.source) or reason
		local kind = entry and entry.kind or nil
		local last = self.lastSafePlace
		if not (last and last.name == name and last.source == source and last.kind == kind) then
			self.lastSafePlace = { name = name, source = source, kind = kind }
		end
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

-- Appelé dix fois par seconde (OnUpdate, EXIT_TICK) : confirme la sortie une fois le délai écoulé
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
	local from = pending.from or {}
	from.quiet = self:IsQuietDeparture(from)
	self:FireCallback("DEPARTURE", from)
	-- zone de départ : rien d'automatique (le check reste à la main, /r2q)
	if from.quiet then return end
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
	local totalWeight, weighted, capped = 0, 0, false

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
			-- run -> ok, détail, points (0-100), bloquant : un échec bloquant
			-- plafonne la note à SCORE_CAP_BLOCKING (« Pas prêt ») ; 1.31.0 :
			-- tip, liste de lignes pour l'infobulle de la ligne (buffs manquants)
			local okRun, okState, detail, score, blocking, tip = pcall(def.run, db)
			if not okRun then
				self:RecordError("check:" .. tostring(def.id), okState)
			end
			if okRun then
				local points = tonumber(score) or (okState and 100 or 40)
				if points < 0 then points = 0 elseif points > 100 then points = 100 end
				-- poids et conseil peuvent dépendre de la situation (munitions du chasseur)
				local weight = def.weight or 1
				if type(weight) == "function" then weight = tonumber(weight(db)) or 1 end
				local adviceKey = def.advice
				if type(adviceKey) == "function" then adviceKey = adviceKey(db) end
				if okState ~= true and blocking then capped = true end

				results[#results + 1] = {
					id     = def.id,
					label  = labelText,
					icon   = def.icon,
					info   = def.info or nil,
					ok     = okState == true,
					detail = tostring(detail or ""),
					score  = points,
					weight = weight,
					advice = adviceKey,
					blocking = (okState ~= true and blocking) and true or nil,
					tip    = type(tip) == "table" and tip or nil,
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
	-- un manque bloquant (chasseur presque sans munitions…) : jamais « Prêt »
	if capped then self.score = math.min(self.score, self.SCORE_CAP_BLOCKING) end
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
function ns:ScoreLabel(score)
	score = tonumber(score) or self.score or 0
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
	self:Print(self:FP("MSG_BAG_PRESSURE", free))
end

-- ---------------------------------------------------------------------------
-- Abonnements à la demande (passe perf R2Q, docs/AUDIT-PERF-R2Q.md)
--
-- Un module coupé, ou un événement qui ne sert qu'à un moment (voyage en
-- cours, fenêtre ouverte, hors combat), ne reste pas abonné : le client ne
-- nous l'envoie plus du tout. Chaque module déclare ses « portes » :
--   ns.FrameGate(nom, { frame = cadre, events = { ... }, want = fn(ns),
--     clock = { key, period, fn } (facultatif : tâche de l'horloge),
--     onPause = fn(ns), onResume = fn(ns) })
-- want(ns) dit si les événements doivent arriver. Au chargement, tout est
-- abonné comme avant ; la première synchro a lieu à l'entrée en jeu.
-- ns:SyncEventGates() relit chaque porte et ne touche qu'à celles qui
-- changent. Elle est appelée à l'entrée en jeu, à l'entrée et à la sortie de
-- combat, au changement de zone, après chaque commande /r2q et chaque
-- changement de réglage (RefreshOptions, OptionPages.lua), et toutes les
-- GATE_SAFETY s en filet (un chemin oublié rattrape son retard).
-- Un want() en erreur garde l'abonnement (dans le doute, on écoute).
-- Socle candidat (ns.FrameGate) : propre à R2Q pour l'instant, le socle
-- étant en travaux de son côté.
-- ---------------------------------------------------------------------------
ns.eventGates, ns.eventGateOrder = {}, {}
ns.GATE_SAFETY = 10

-- Combat vu par les événements (PLAYER_REGEN_*) : sur PLAYER_REGEN_DISABLED,
-- InCombatLockdown() est encore faux. Un /reload en combat le relit à
-- l'entrée en jeu.
function ns:GateInCombat()
	return self.gateCombat == true
end

local function ClientInCombat()
	local fn = rawget(_G, "InCombatLockdown")
	if type(fn) == "function" then
		local ok, res = pcall(fn)
		if ok and res then return true end
	end
	return false
end

local function GateWant(gate)
	local ok, want = pcall(gate.want, ns)
	if not ok then
		ns:RecordError("gate:" .. tostring(gate.name), want)
		return true
	end
	return want and true or false
end

local function GateApply(gate, want)
	gate.on = want
	local frame = gate.frame
	if frame then
		for i = 1, #gate.events do
			local event = gate.events[i]
			if want then
				ns.RegisterGameEvent(frame, event)     -- UNIT_* : le joueur seulement
			elseif type(frame.UnregisterEvent) == "function" then
				pcall(frame.UnregisterEvent, frame, event)
			end
		end
	end
	local clock = gate.clock
	if clock then
		if want then ns.Every(clock[1], clock[2], clock[3]) else ns.Cancel(clock[1]) end
	end
end

function ns.FrameGate(name, gate)
	if type(gate) ~= "table" or type(gate.want) ~= "function" then return nil end
	gate.name = name
	gate.events = gate.events or {}
	gate.on = true      -- au chargement : abonné, comme avant cette passe
	if not ns.eventGates[name] then ns.eventGateOrder[#ns.eventGateOrder + 1] = name end
	ns.eventGates[name] = gate
	return gate
end

-- Relit une porte (nom ou table) ; rend son état
function ns:SyncEventGate(which)
	local gate = type(which) == "table" and which or self.eventGates[which]
	if not gate then return nil end
	local want = GateWant(gate)
	if gate.on == want then return want end
	GateApply(gate, want)
	local hook = want and gate.onResume or gate.onPause
	if hook then
		local ok, err = pcall(hook, self)
		if not ok then self:RecordError("gate:" .. tostring(gate.name), err) end
	end
	return want
end

function ns:SyncEventGates()
	local order = self.eventGateOrder
	for i = 1, #order do self:SyncEventGate(order[i]) end
end

-- Combat : posé par le premier des cadres qui reçoit PLAYER_REGEN_* (celui
-- du cœur ou celui d'un module), sans effet s'il ne change pas
function ns:SetGateCombat(inCombat)
	inCombat = inCombat and true or false
	if self.gateCombat == inCombat then return end
	self.gateCombat = inCombat
	self:SyncEventGates()
end

-- Retour à l'état du chargement : tout abonné, hors combat (banc de test,
-- ResetWorld ; en jeu, l'entrée en jeu relit tout de toute façon)
function ns:ResetEventGates()
	self.gateCombat = nil
	local order = self.eventGateOrder
	for i = 1, #order do
		local gate = self.eventGates[order[i]]
		if gate and not gate.on then GateApply(gate, true) end
	end
end

-- /r2q diag : les portes fermées (à vérifier en jeu : module coupé, hors
-- voyage, en combat…)
ns.RegisterStrings({
	MSG_DIAG_GATES      = "  abonnements en pause : %s%s",
	MSG_DIAG_GATES_NONE = "aucun",
	MSG_DIAG_GATES_COMBAT = " (en combat)",
}, {
	MSG_DIAG_GATES      = "  subscriptions paused: %s%s",
	MSG_DIAG_GATES_NONE = "none",
	MSG_DIAG_GATES_COMBAT = " (in combat)",
})
function ns:GateDiagLine()
	local closed = {}
	for _, name in ipairs(self.eventGateOrder) do
		local gate = self.eventGates[name]
		if gate and not gate.on then closed[#closed + 1] = name end
	end
	local list = #closed > 0 and table.concat(closed, ", ") or L.MSG_DIAG_GATES_NONE
	return self:F("MSG_DIAG_GATES", list, self:GateInCombat() and L.MSG_DIAG_GATES_COMBAT or "")
end

-- Filet : un PLAYER_REGEN_ENABLED manqué, un réglage changé par un chemin
-- inconnu. Le combat n'est relu ici qu'à froid (jamais pendant
-- PLAYER_REGEN_DISABLED, où le client dit encore « hors combat »).
local function GateSafety()
	if ns.gateCombat and not ClientInCombat() then
		local fn = rawget(_G, "UnitAffectingCombat")
		local ok, res = false, nil
		if type(fn) == "function" then ok, res = pcall(fn, "player") end
		if not (ok and res) then ns.gateCombat = false end
	end
	ns:SyncEventGates()
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

		-- abonnements à la demande : première synchro (un /reload en combat
		-- arrive ici en combat : PLAYER_REGEN_ENABLED rouvrira)
		self.gateCombat = ClientInCombat()
		self:SyncEventGates()
	end,

	ZONE_CHANGED_NEW_AREA = function(self)
		self:LearnFromSignals()
		self:Evaluate("zone")
		self:SyncEventGates()
	end,

	PLAYER_REGEN_DISABLED = function(self) self:SetGateCombat(true) end,
	PLAYER_REGEN_ENABLED = function(self) self:SetGateCombat(false) end,

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

	PLAYER_EQUIPMENT_CHANGED = function(self, slot)
		-- différé et regroupé : un événement par emplacement, et le client n'a
		-- pas toujours recalculé les stats à l'instant (Stats.lua, GEAR_RETRY)
		if self.QueueEquipmentChange then
			self:QueueEquipmentChange(slot)
		elseif self.OnEquipmentChanged then
			self:OnEquipmentChanged()
		end
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
	-- (abonnements relus après chaque commande : HandleCommand, plus bas)
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
		-- 1.32.2 : bascule la fiche enregistrée (pas la copie de la liste), choix retenu
		local entry = list[index]
		entry.enabled = self.BuffToggle and self:BuffToggle(entry.spellId) or false
		self:Print(self:F("MSG_BUFF_TOGGLED", index, entry.enabled and "ON" or "off"))
	end,
	["seuil"] = function(self, value)
		local db = self:DB()
		local n = tonumber(value)
		if not n then return self:Print(L.MSG_UNKNOWN_CMD) end
		db.bagFreeThreshold = math.floor(n)
		self:Print(self:FP("MSG_THRESHOLD", db.bagFreeThreshold))
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
			local state = on and (ns.Theme.T_GREEN .. L.MODULE_ON .. "|r") or (ns.Theme.T_RED .. L.MODULE_OFF .. "|r")
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
			local state = on and (ns.Theme.T_GREEN .. L.MODULE_ON .. "|r") or (ns.Theme.T_RED .. L.MODULE_OFF .. "|r")
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
		-- 1.32.0 : socle partagé avec QuestCompanion, ou propre
		if self.SocleDiagLine then self:Print(self:SocleDiagLine()) end

		-- État du chargement des fichiers
		local loaded, missing = {}, {}
		-- 1.32.0 (fiche 28) : la liste de Config.lua et les lignes traduites du socle
		for _, name in ipairs(ns.APP.coreFiles or {}) do
			if ns.Loaded and ns.Loaded[name] then loaded[#loaded + 1] = name else missing[#missing + 1] = name end
		end
		self:DiagModulesLines(loaded, missing)
		if self.unsupportedEvents and #self.unsupportedEvents > 0 then
			self:Print("  " .. ns.Theme.T_ORANGE_DEEP .. L.MSG_DIAG_UNSUPPORTED .. "|r " .. table.concat(self.unsupportedEvents, ", "))
		end
		self:DiagErrorLines()
		local mapID = self:CurrentMap()
		local info = self:MapInfo(mapID)
		self:Print(self:F("MSG_DIAG_MAP", tostring(mapID), tostring(info and info.parentMapID), tostring(info and info.name)))
		local safe, _, why = self:IsCurrentZoneSafe()
		self:Print(self:F("MSG_DIAG_SAFE", tostring(safe) .. " (" .. tostring(why) .. ", "
			.. tostring(self:CurrentSubZone()) .. ")"))
		if self.DiagAuras then self:DiagAuras() else self:Print(L.MSG_DIAG_NOAURA) end
		-- dernier changement d'équipement (résumé de stuff), portée d'aggro
		if self.GearDiagLine then self:Print(self:GearDiagLine()) end
		if self.AggroDiagLine then self:Print(self:AggroDiagLine()) end
		-- abonnements à la demande : ceux qui sont en pause
		if self.GateDiagLine then self:Print(self:GateDiagLine()) end
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

-- Après chaque commande (/r2q on|off, module, reset, portrait…), les
-- abonnements suivent les réglages. Le socle (Base.lua) relit
-- ns.HandleCommand à chaque appel : l'enveloppe est prise en compte.
do
	local handle = ns.HandleCommand
	if type(handle) == "function" then
		function ns:HandleCommand(...)
			local ok, err = pcall(handle, self, ...)
			local synced, syncErr = pcall(self.SyncEventGates, self)
			if not synced then self:RecordError("gate:commande", syncErr) end
			if not ok then error(err, 0) end
		end
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
			-- UNIT_AURA : le joueur seulement (ns.RegisterGameEvent, Compat.lua)
			local ok = ns.RegisterGameEvent(target, event)
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
-- 1.32.2 (fiche 25) : plus d'OnUpdate permanent, l'horloge de l'addon.
-- Sortie en attente : pas besoin de chaque image, dix fois par seconde.
-- Lieux repérés par leurs PNJ (Places.lua) : y entrer ou en sortir ne
-- change pas forcément de sous-zone, aucun événement ne le dit. On regarde
-- au même pas (CheckPlaceMove s'espace lui-même, toutes les PLACE_CHECK s).
ns.EXIT_TICK = 0.1
ns.Every("core:exit", ns.EXIT_TICK, function()
	if ns.pendingExit then ns:UpdatePendingExit(ns:Now()) end
	ns:CheckPlaceMove(ns:Now())
end)
-- fondu du résumé éphémère, image par image, seulement pendant qu'il est
-- affiché (la tâche se retire quand il n'y a plus rien à fondre)
local function ToastFade()
	if not ns.toastHideAt or not ns.UpdateToast then return false end
	ns:UpdateToast(ns:Now())
	return ns.toastHideAt ~= nil
end
function ns:ArmToastFade() ns.Every("core:toast", 0, ToastFade) end
-- filet des abonnements à la demande (voir ns.FrameGate)
ns.Every("core:gates", ns.GATE_SAFETY, GateSafety)
ns:RegisterEvents(frame)

ns.eventFrame = frame


-- ---------------------------------------------------------------------------
-- Thème forgé (Azeroth) : les matières des blocs propres aux fenêtres de
-- Ready2Quest (bloc note, conseils, cartes, creux, étiquettes, filets et
-- points lumineux), faites des textures du socle (Theme.ART, grises : elles
-- prennent la teinte). Tout est décidé à la construction : en Sobre, chaque
-- fonction rend nil sans rien créer, le module garde ses aplats d'avant ;
-- changer de thème demande /reload pour une fenêtre déjà construite.
-- Plaque (Theme.ART.plate) : la teinte × la luminance de la texture, 0,885 en
-- haut, 0,50 au pied (sous un texte : entre les deux, mesuré aux deux bouts).
-- Creux (Theme.ART.inset) : fond presque noir (0,14 × la teinte, 0 sous
-- l'ombre du haut) ; seul son filet prend la couleur.
-- ---------------------------------------------------------------------------
do
	local Theme = ns.Theme
	ns.FORGE = {
		card    = { 0.118, 0.145, 0.176 },        -- plaque d'un bloc en relief
		neutral = { 0.165, 0.196, 0.239 },        -- plaque d'un bouton neutre (tuile d'annonce)
		plate   = { top = 0.885, bottom = 0.50 },  -- luminance de la plaque (contrastes)
		inset   = { fill = 0.14 },                 -- fond du creux, × la teinte du filet
		well    = { out = 3, margin = 6 },         -- creux autour d'une barre fine
		tag     = { margin = 6, padX = 8, height = 18 },   -- étiquette en creux
		-- liseré lumineux d'un bloc : sa couleur assombrie en bas, éclaircie en haut, un halo
		bar     = { width = 3, halo = 14, haloAlpha = 0.18, shade = 0.35, light = 0.25 },
		glow    = { alpha = 0.45, size = 2.4 },    -- halo derrière un grand chiffre (× sa hauteur)
		dot     = { size = 18, alpha = 0.55 },     -- point lumineux sous une puce
		line    = { height = 6, gap = 6, alpha = 0.85 },  -- filet lumineux qui s'efface
		-- carte de liste (une texture : dégradé de la plaque, et un reflet d'1 px)
		sheen   = { highlight = 0.10 },
		-- rangées de couleur : le sens d'un état (vert : en ordre, rouge : à
		-- voir d'urgence, or : à voir, gris : sans objet)
		tone    = { ok = Theme.GREEN, bad = Theme.RED, warn = Theme.GOLD, none = Theme.EDGE },
	}

	function ns.ForgeOn()
		return Theme ~= nil and type(Theme.Forged) == "function" and Theme.Forged() and type(Theme.Slice) == "function"
	end

	-- cache les aplats de Sobre (textures, ou filets de Theme.Border)
	function ns.ForgeHideFlat(...)
		for index = 1, select("#", ...) do
			local part = select(index, ...)
			if type(part) == "table" then
				if part.Hide then
					part:Hide()
				elseif part.top then
					for _, side in ipairs({ "top", "bottom", "left", "right" }) do if part[side] then part[side]:Hide() end end
				end
			end
		end
	end

	-- Plaque en relief (carte) sous `frame` (ou autour de opts.around)
	function ns.ForgeCard(frame, opts)
		if not (frame and ns.ForgeOn()) then return nil end
		opts = opts or {}
		return Theme.Slice(frame, "plate", { layer = opts.layer or "BACKGROUND", sub = opts.sub or 1,
			color = opts.color or ns.FORGE.card, around = opts.around, out = opts.out, margin = opts.margin })
	end

	-- Creux : fond presque noir, filet à la teinte (or patiné au repos)
	function ns.ForgeWell(frame, opts)
		if not (frame and ns.ForgeOn()) then return nil end
		opts = opts or {}
		return Theme.Slice(frame, "inset", { layer = opts.layer or "BACKGROUND", sub = opts.sub or 1,
			color = opts.color or Theme.EDGE, around = opts.around, out = opts.out, margin = opts.margin })
	end

	-- Filet lumineux qui s'efface vers la droite (Theme.ART.line)
	function ns.ForgeLine(parent, color, alpha, layer)
		if not (parent and ns.ForgeOn() and Theme.ART and Theme.ART.line) then return nil end
		color = color or Theme.GOLD
		local tex = parent:CreateTexture(nil, layer or "ARTWORK")
		tex:SetTexture(Theme.ART.line.file)
		tex:SetVertexColor(color[1], color[2], color[3], alpha or ns.FORGE.line.alpha)
		tex:SetHeight(ns.FORGE.line.height)
		return tex
	end

	-- Point lumineux (Theme.ART.dot) : puce, braise, halo d'un chiffre
	function ns.ForgeDot(parent, size, color, alpha, layer)
		if not (parent and ns.ForgeOn() and Theme.ART and Theme.ART.dot) then return nil end
		color = color or Theme.GOLD
		local tex = parent:CreateTexture(nil, layer or "BORDER")
		tex:SetTexture(Theme.ART.dot.file)
		tex:SetVertexColor(color[1], color[2], color[3], alpha or ns.FORGE.dot.alpha)
		tex:SetSize(size or ns.FORGE.dot.size, size or ns.FORGE.dot.size)
		return tex
	end

	-- Liseré d'un bloc, en lumière : la barre d'accent de Sobre (texture
	-- `bar`, verticale, à gauche) passe en dégradé (sa couleur éclaircie en
	-- haut, assombrie en bas), plus large, avec un halo qui s'efface vers la
	-- droite. Rend le halo.
	function ns.ForgeAccentBar(block, bar, color)
		if not (block and bar and ns.ForgeOn()) then return nil end
		color = color or Theme.GOLD
		local B = ns.FORGE.bar
		bar:SetWidth(B.width)
		Theme.Gradient(bar, "VERTICAL", Theme.Over(color, Theme.SHADOW, B.shade), 1, Theme.Over(color, Theme.WHITE, B.light), 1)
		local halo = block:CreateTexture(nil, "BORDER")
		halo:SetTexture(Theme.SOLID)
		halo:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, 0)
		halo:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 0, 0)
		halo:SetWidth(B.halo)
		Theme.Gradient(halo, "HORIZONTAL", color, B.haloAlpha, color, 0)
		return halo
	end

	-- Carte de liste en une texture (Theme.ART.plate imitée par un dégradé :
	-- une plaque de 9 pièces par ligne serait trop lourde) et un reflet d'1 px
	-- en haut. Le fond plat de la ligne se cache. Rend la texture du dégradé.
	function ns.ForgeSheen(row)
		if not (row and ns.ForgeOn()) then return nil end
		local P, card = ns.FORGE.plate, ns.FORGE.card
		local sheen = row:CreateTexture(nil, "BACKGROUND", nil, 1)
		sheen:SetTexture(Theme.SOLID)
		sheen:SetAllPoints(row)
		Theme.Gradient(sheen, "VERTICAL", { card[1] * P.bottom, card[2] * P.bottom, card[3] * P.bottom }, 1,
			{ card[1] * P.top, card[2] * P.top, card[3] * P.top }, 1)
		local lit = row:CreateTexture(nil, "BACKGROUND", nil, 2)
		lit:SetTexture(Theme.SOLID)
		lit:SetVertexColor(Theme.WHITE[1], Theme.WHITE[2], Theme.WHITE[3], ns.FORGE.sheen.highlight)
		lit:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
		lit:SetPoint("TOPRIGHT", row, "TOPRIGHT", -1, -1)
		lit:SetHeight(1)
		sheen.highlight = lit
		if row.bg then row.bg:Hide() end
		row.forgeSheen = sheen
		return sheen
	end

	-- Style de bouton qui porte le sens en thème forgé (« danger », « add »,
	-- « arcane »…), si le socle le connaît ; sinon celui de Sobre
	function ns.ForgeStyle(sobre, ...)
		if not ns.ForgeOn() then return sobre end
		local styles = Theme.BUTTON_STYLES or {}
		for index = 1, select("#", ...) do
			local name = select(index, ...)
			if styles[name] then return name end
		end
		return sobre
	end
end

-- API publique : QuestCompanion s'y abonne aux départs et retours de zone
-- sûre (ns:RegisterCallback("DEPARTURE" | "RETURN"), Libs/Socle/Store.lua)
_G.Ready2Quest = ns
_G.ReadyToQuest = ns   -- ancien nom de l'API publique, gardé en alias

if ns.Mark then ns.Mark("Core") end
