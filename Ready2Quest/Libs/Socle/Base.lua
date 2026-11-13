-- Base.lua -- socle commun, chargé juste après Config.lua, ne dépend de rien
--
-- Objectif : que la commande de l'addon réponde TOUJOURS, même si un fichier
-- suivant plante au chargement. C'est ce qui permet de diagnostiquer à
-- distance un addon muet.
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py. Ce qui change d'un addon à l'autre est dans
-- son Config.lua (ns.APP).
local ADDON, ns = ...

local APP = ns.APP or { id = ADDON or "?", version = "?", slash = {}, coreFiles = {} }
ns.APP = APP

-- 2.11.0 / 1.32.0 (fiche 28) : codes couleur du texte, déclarés ici une seule
-- fois (premier fichier du socle : utilisables par Strings.lua, Locales.lua et
-- les messages de démarrage). Theme.T_* en sont des alias (Theme.lua).
ns.TC = {
	GOLD = "|cffe8a54b", PARCHMENT = "|cfff1e8d4", GREY = "|cff91969e", GREEN = "|cff6fcf7a",
	RED = "|cffe2604f", ORANGE = "|cffe8a54b", ORANGE_DEEP = "|cffed7833", WHITE = "|cffffffff",
	BLUE = "|cff5b8fd6",
}
local TC = ns.TC

-- Messages affichés avant Strings.lua (démarrage, socle incomplet) : une
-- petite table bilingue choisie par la langue du client
local BOOT_FR = {
	ERROR = "%s — erreur|r (%s) %s",
	NOT_LOADED = "%s — modules non chargés.",
	MISSING = "  fichiers non exécutés : %s",
	CMD_FAILED = "  tous les fichiers sont chargés, mais la commande n'a pas pu être exécutée.",
	LAST_ERROR = "  dernière erreur : %s",
	SCRIPT_ERRORS = "  active les erreurs Lua : /console scriptErrors 1 puis /reload",
	LOADED = "%s — fichiers chargés",
}
local BOOT_EN = {
	ERROR = "%s — error|r (%s) %s",
	NOT_LOADED = "%s — modules not loaded.",
	MISSING = "  files not run: %s",
	CMD_FAILED = "  all files loaded, but the command could not run.",
	LAST_ERROR = "  last error: %s",
	SCRIPT_ERRORS = "  turn Lua errors on: /console scriptErrors 1 then /reload",
	LOADED = "%s — files loaded",
}
local BOOT = (type(GetLocale) == "function" and GetLocale() == "frFR") and BOOT_FR or BOOT_EN
ns.BOOT_STRINGS = BOOT
-- « QuestCompanion 2.11.0 » : l'identifiant en or, puis la version
local function BootName()
	return TC.GOLD .. tostring(APP.id) .. "|r " .. tostring(ns.version)
end

-- ===========================================================================
-- socle 2.11.0 : socle chargé une fois quand les deux addons sont installés
-- ===========================================================================
-- Chaque fichier du socle (hors Base.lua) enveloppe son corps dans une
-- fabrique : ns.SocleFile(nom, fabrique)(ADDON, ns). Le premier addon
-- l'enregistre ; le second, si son socle a EXACTEMENT la même empreinte,
-- exécute la fabrique déjà compilée avec SON nom et SON ns (sa copie compilée
-- est libérée). Tout ce que la fabrique crée (Theme, L, sauvegarde, polices,
-- cadres) reste propre à chaque addon. Les données en lecture seule (HUBS,
-- PLACE_DATA, DUNGEONS…) sont partagées telles quelles (ns.SocleData).
-- Empreinte différente : chacun sa copie, comme avant.
-- socle:empreinte (écrit par tools/sync_socle.py, ne pas éditer)
local SOCLE_ID = "e93edfbc"
-- /socle:empreinte
local REGISTRY = rawget(_G, "ReadyToQuestSocle")
if type(REGISTRY) ~= "table" then
	REGISTRY = {}
	_G.ReadyToQuestSocle = REGISTRY
end
ns.SOCLE_ID = SOCLE_ID

function ns.SocleFile(name, factory)
	local key = name .. "@" .. SOCLE_ID
	local known = REGISTRY[key]
	if type(known) == "function" then
		ns.socleShared = true
		return known
	end
	REGISTRY[key] = factory
	return factory
end

function ns.SocleData(name, build)
	local key = "data:" .. name .. "@" .. SOCLE_ID
	local known = REGISTRY[key]
	if known == nil then
		known = build()
		REGISTRY[key] = known
	else
		ns.socleShared = true
	end
	return known
end

-- ---------------------------------------------------------------------------
-- socle 2.11.0 : coordination légère entre Ready2Quest et QuestCompanion.
-- ns.Shared est la MÊME table pour les deux addons (_G.ReadyToQuestSocle.shared) :
--   Shared.addons[id] = { id, version, socle }   (chaque addon s'y inscrit)
--   Shared.Has(id)              -> l'entrée de cet addon s'il est chargé, sinon nil
--   Shared.Claim(sujet, id, on) -> id prend (on ~= false) ou rend un sujet
--   Shared.Owner(sujet)         -> id de l'addon qui tient le sujet, ou nil
--   Shared.Defers(sujet, id)    -> vrai si un AUTRE addon tient le sujet : id se tait
--   Shared.Set(sujet, valeur) / Shared.Get(sujet) : état publié sur un sujet
-- Sujet utilisé : "aggro" (Ready2Quest le tient quand son module d'aggro est
-- actif ; l'alerte « plusieurs monstres sur toi » du compagnon de
-- QuestCompanion se tait alors : Shared.Defers("aggro", "QuestCompanion")).
-- Les fonctions sont posées une fois (version 1) ; une version plus récente
-- les remplace sans toucher aux données.
-- ---------------------------------------------------------------------------
local SHARED_VERSION = 1
local Shared = REGISTRY.shared
if type(Shared) ~= "table" then
	Shared = { addons = {}, owners = {}, state = {} }
	REGISTRY.shared = Shared
end
if (tonumber(Shared.version) or 0) < SHARED_VERSION then
	Shared.version = SHARED_VERSION
	function Shared.Has(id)
		return Shared.addons[id]
	end
	function Shared.Claim(topic, id, on)
		if on == false then
			if Shared.owners[topic] == id then Shared.owners[topic] = nil end
		else
			Shared.owners[topic] = id
		end
	end
	function Shared.Owner(topic)
		return Shared.owners[topic]
	end
	function Shared.Defers(topic, id)
		local owner = Shared.owners[topic]
		return owner ~= nil and owner ~= id and Shared.addons[owner] ~= nil
	end
	function Shared.Set(topic, value) Shared.state[topic] = value end
	function Shared.Get(topic) return Shared.state[topic] end
end
Shared.addons[APP.id] = { id = APP.id, version = APP.version, socle = SOCLE_ID }
ns.Shared = Shared
-- l'autre addon du projet, s'il est chargé (son entrée), sinon nil
function ns.OtherAddon()
	for id, entry in pairs(Shared.addons) do
		if id ~= APP.id then return entry end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- socle 3.0.1 : « couloir » des fenêtres centrales, commun aux deux addons.
-- Place au butin (R2Q), Tout capturer et la carte de capture (QC) s'ouvraient
-- ensemble au centre de l'écran, l'une sur l'autre. Chaque fenêtre de ce
-- genre s'annonce à l'ouverture : ns.PopupPlace(cadre, opts). Si elle en
-- chevauche une autre déjà ouverte, elle se met à côté (du côté où il y a la
-- place, 12 px d'écart), sinon dessous. Rien ne bouge quand une fenêtre se
-- ferme ; seule une fenêtre qui s'ouvre se place. Seule, elle revient à sa
-- place habituelle. Une fenêtre déplacée par le joueur (glissée pendant la
-- session, IsUserPlaced, ou opts.userPlaced() vrai) n'est jamais déplacée.
-- Le registre est REGISTRY.popups (_G.ReadyToQuestSocle), la même table pour
-- les deux addons, comme ns.Shared ; les fonctions sont posées par la
-- version la plus récente (POPUPS_VERSION).
-- ---------------------------------------------------------------------------
local POPUPS_VERSION = 1
local Popups = REGISTRY.popups
if type(Popups) ~= "table" then
	Popups = { frames = {}, serial = 0 }
	REGISTRY.popups = Popups
end
if (tonumber(Popups.version) or 0) < POPUPS_VERSION then
	Popups.version = POPUPS_VERSION
	Popups.GAP = 12
	local function Get(object, name, ...)
		if type(object) ~= "table" or type(object[name]) ~= "function" then return nil end
		local ok, a, b, c, d, e = pcall(object[name], object, ...)
		if ok then return a, b, c, d, e end
		return nil
	end
	local function Root() return rawget(_G, "UIParent") end
	local function Scale(frame)
		local own = tonumber(Get(frame, "GetEffectiveScale")) or 1
		local root = tonumber(Get(Root(), "GetEffectiveScale")) or 1
		if own <= 0 or root <= 0 then return 1 end
		return own / root
	end
	-- rectangle en unités d'UIParent, ou nil si le client ne le donne pas
	function Popups.Rect(frame)
		local l, r = tonumber(Get(frame, "GetLeft")), tonumber(Get(frame, "GetRight"))
		local t, b = tonumber(Get(frame, "GetTop")), tonumber(Get(frame, "GetBottom"))
		if not (l and r and t and b) then return nil end
		local s = Scale(frame)
		return { l = l * s, r = r * s, t = t * s, b = b * s }
	end
	function Popups.Overlap(a, b)
		return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t
	end
	local function Visible(frame)
		if type(frame.IsVisible) == "function" then return Get(frame, "IsVisible") and true or false end
		return Get(frame, "IsShown") and true or false
	end
	function Popups.Register(frame, opts)
		local entry = Popups.frames[frame]
		if not entry then
			entry = {}
			Popups.frames[frame] = entry
			local point, rel, relPoint, x, y = Get(frame, "GetPoint", 1)
			if point then entry.home = { point, rel, relPoint or point, x or 0, y or 0 } end
			-- glissée par le joueur : plus jamais déplacée (cette session)
			if type(frame.HookScript) == "function" then
				pcall(frame.HookScript, frame, "OnDragStop", function() entry.user = true end)
			end
		end
		if type(opts) == "table" and type(opts.userPlaced) == "function" then entry.userPlaced = opts.userPlaced end
		return entry
	end
	function Popups.UserPlaced(frame)
		local entry = Popups.frames[frame]
		if entry and entry.user then return true end
		if entry and entry.userPlaced then
			local ok, placed = pcall(entry.userPlaced, frame)
			if ok and placed then return true end
		end
		return Get(frame, "IsUserPlaced") and true or false
	end
	local function Move(frame, left, top)
		local s = Scale(frame)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", Root(), "BOTTOMLEFT", left / s, top / s)
	end
	-- Place `frame` (qui vient de s'ouvrir). Renvoie "user", "home",
	-- "right", "left", "below", ou "unknown" (géométrie illisible).
	function Popups.Place(frame, opts)
		if type(frame) ~= "table" then return nil end
		local entry = Popups.Register(frame, opts)
		if Popups.UserPlaced(frame) then return "user" end
		Popups.serial = (Popups.serial or 0) + 1
		entry.order = Popups.serial
		local home = entry.home
		if home and type(frame.ClearAllPoints) == "function" then
			frame:ClearAllPoints()
			frame:SetPoint(home[1], home[2], home[3], home[4], home[5])
		end
		local others = {}
		for other, data in pairs(Popups.frames) do
			if other ~= frame and Visible(other) then
				local rect = Popups.Rect(other)
				if rect then rect.order = data.order or 0; others[#others + 1] = rect end
			end
		end
		if #others == 0 then return "home" end
		local me = Popups.Rect(frame)
		if not me then return "unknown" end
		local width, height = me.r - me.l, me.t - me.b
		local screenW = tonumber(Get(Root(), "GetWidth")) or 0
		local screenH = tonumber(Get(Root(), "GetHeight")) or 0
		local function Fits(l, t)
			local rect = { l = l, r = l + width, t = t, b = t - height }
			if screenW > 0 and (rect.l < 0 or rect.r > screenW) then return false end
			if screenH > 0 and (rect.b < 0 or rect.t > screenH) then return false end
			for _, o in ipairs(others) do if Popups.Overlap(rect, o) then return false end end
			return true
		end
		if Fits(me.l, me.t) then return "home" end
		table.sort(others, function(a, b) return a.order < b.order end)
		local gap = Popups.GAP
		for _, o in ipairs(others) do
			local tries = {
				{ "right", o.r + gap, o.t, screenW - o.r },
				{ "left", o.l - gap - width, o.t, o.l },
			}
			-- d'abord le côté qui a le plus de place
			if tries[2][4] > tries[1][4] then tries[1], tries[2] = tries[2], tries[1] end
			tries[3] = { "below", o.l, o.b - gap }
			for _, try in ipairs(tries) do
				if Fits(try[2], try[3]) then Move(frame, try[2], try[3]); return try[1] end
			end
		end
		-- nulle part : sous la première, gardée à l'écran
		local first = others[1]
		Move(frame, math.max(0, first.l), math.max(height, first.b - gap))
		return "below"
	end
end
ns.Popups = Popups
function ns.PopupPlace(frame, opts) return Popups.Place(frame, opts) end

ns.version = APP.version
ns.Loaded = {}
ns.loadOrder = {}
ns.errors = {}

local function Mark(name)
	ns.Loaded[name] = true
	ns.loadOrder[#ns.loadOrder + 1] = name
end
ns.Mark = Mark

-- Boucle OnUpdate espacée : ns.Throttle(intervalle, fn) rend un gestionnaire
-- OnUpdate qui cumule le temps écoulé et n'appelle fn(cadre, cumul, ...)
-- qu'une fois l'intervalle atteint (le cumul remis à zéro). fn reçoit le
-- temps réellement écoulé depuis son dernier passage, pas celui d'une image.
-- Pour les vérifications qui n'ont pas besoin de chaque image ; les
-- animations, elles, restent image par image.
function ns.Throttle(interval, fn)
	interval = tonumber(interval) or 0
	local pending = 0
	return function(frame, elapsed, ...)
		pending = pending + (tonumber(elapsed) or 0)
		if pending < interval then return end
		local step = pending
		pending = 0
		return fn(frame, step, ...)
	end
end

-- socle 2.11.2 / 1.32.2 (fiche 25) : l'horloge de l'addon. Un seul cadre,
-- caché quand rien n'est posé, une seule fonction OnUpdate qui cumule le
-- temps des images (aucun appel au client) et sort aussitôt tant que la
-- prochaine échéance n'est pas atteinte. Elle remplace les OnUpdate
-- permanents des vérifications espacées ; les animations gardent le leur,
-- posé le temps qu'elles jouent. Une horloge par addon (ce fichier n'est
-- pas partagé entre les deux socles).
--   ns.Every(clé, période, fn) : fn(écoulé) toutes les `période` s (0 : à
--     chaque image) ; écoulé = temps depuis son dernier passage, comme
--     ns.Throttle. fn rend false : la tâche se retire d'elle-même ; fn rend
--     un nombre : prochain passage dans ce nombre de secondes (cadence
--     variable : chaque image pendant une animation, espacée au repos).
--   ns.Soon(clé, délai, fn) : une fois, dans `délai` s (avancée si elle était
--     déjà posée plus tard).
--   ns.Cancel(clé) ; ns.ClockJobs() : nombre de tâches et leurs clés.
-- Chaque passage est protégé (pcall) : une erreur est notée une fois
-- (« clock:clé »), les autres tâches tournent.
ns.CLOCK_POLL = 0.1   -- pas des vérifications à échéance (l'échéance reste la leur)
local clockJobs, clockOrder = {}, {}
local clockNow, clockNext, clockTicking, clockDirty = 0, math.huge, false, false
local clockFrame

local function ClockCompact()
	for i = #clockOrder, 1, -1 do
		if not clockJobs[clockOrder[i]] then table.remove(clockOrder, i) end
	end
	clockDirty = false
end

local function ClockReschedule()
	local soonest = math.huge
	for i = 1, #clockOrder do
		local job = clockJobs[clockOrder[i]]
		if job and job.at < soonest then soonest = job.at end
	end
	clockNext = soonest
	if clockFrame then
		if soonest < math.huge then clockFrame:Show() else clockFrame:Hide() end
	end
end

local function ClockTick(_, elapsed)
	clockNow = clockNow + (elapsed or 0)   -- le client donne toujours un nombre
	if clockNow < clockNext then return end
	clockTicking = true
	local now = clockNow
	for i = 1, #clockOrder do
		local key = clockOrder[i]
		local job = clockJobs[key]
		if job and now >= job.at then
			local step = now - job.last
			job.last = now
			if job.period then job.at = now + job.period else clockJobs[key] = nil; clockDirty = true end
			local ok, keep = pcall(job.fn, step)
			if not ok then
				ns:RecordError("clock:" .. tostring(key), keep)
			elseif keep == false and clockJobs[key] == job then
				clockJobs[key] = nil
				clockDirty = true
			elseif type(keep) == "number" and job.period and clockJobs[key] == job and job.last == now then
				job.at = now + math.max(0, keep)
			end
		end
	end
	clockTicking = false
	if clockDirty then ClockCompact() end
	ClockReschedule()
end

local function Clock()
	if clockFrame == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		clockFrame = (ok and frame) or false
		if clockFrame then
			clockFrame:SetScript("OnUpdate", ClockTick)
			clockFrame:Hide()
			ns.clockFrame = clockFrame
		end
	end
	return clockFrame
end

local function ClockPut(key, period, delay, fn)
	if not Clock() or type(fn) ~= "function" then return false end
	local job = clockJobs[key]
	if not job then
		local listed = false
		for i = 1, #clockOrder do if clockOrder[i] == key then listed = true; break end end
		if not listed then clockOrder[#clockOrder + 1] = key end
		job = {}
		clockJobs[key] = job
	end
	job.fn, job.period, job.last = fn, period, clockNow
	job.at = clockNow + delay
	if not clockTicking then ClockReschedule() elseif job.at < clockNext then clockNext = job.at end
	return true
end

function ns.Every(key, period, fn)
	period = math.max(0, tonumber(period) or 0)
	return ClockPut(key, period, period, fn)
end

function ns.Soon(key, delay, fn)
	delay = math.max(0, tonumber(delay) or 0)
	local job = clockJobs[key]
	if job and not job.period and job.at <= clockNow + delay then
		job.fn = fn or job.fn
		return true
	end
	return ClockPut(key, nil, delay, fn or (job and job.fn))
end

function ns.Cancel(key)
	if not clockJobs[key] then return end
	clockJobs[key] = nil
	clockDirty = true
	if not clockTicking then ClockCompact(); ClockReschedule() end
end

function ns.ClockJobs()
	if clockDirty and not clockTicking then ClockCompact() end
	return #clockOrder, clockOrder
end

-- Résultat de build() gardé tant que les globales du client nommées dans
-- names gardent leur valeur (motifs de messages : lus à chaque ligne de
-- butin ou d'XP, reconstruits seulement si une chaîne du client change).
function ns.MemoGlobals(names, build)
	local values, result = {}, nil
	return function()
		local fresh = result ~= nil
		for i = 1, #names do
			local value = rawget(_G, names[i])
			if values[i] ~= value then values[i] = value; fresh = false end
		end
		if not fresh then result = build() end
		return result
	end
end

-- Journalisation d'erreur, appelable depuis n'importe quel fichier
-- Bornée à ERRORS_MAX erreurs distinctes : une erreur au texte variable (GUID,
-- nombre) répétée à chaque image ne fait pas grossir la liste ni défiler le
-- chat sans fin ; les suivantes sont seulement comptées (ns.errorsDropped).
ns.ERRORS_MAX = 50
function ns:RecordError(where, message)
	message = tostring(message)
	for _, entry in ipairs(self.errors) do
		if entry.where == where and entry.message == message then return end
	end
	if #self.errors >= ns.ERRORS_MAX then
		self.errorsDropped = (self.errorsDropped or 0) + 1
		return
	end
	self.errors[#self.errors + 1] = { where = where, message = message }
	if type(print) == "function" then
		print(TC.RED .. string.format(BOOT.ERROR, tostring(APP.id), tostring(where), message))
	end
end

-- Commande enregistrée immédiatement, avant tout le reste
local function Dispatch(input)
	if type(ns.HandleCommand) == "function" then
		local ok, err = pcall(ns.HandleCommand, ns, input or "")
		if ok then return end
		ns:RecordError("commande", err)
		return
	end

	-- le socle n'a pas été jusqu'au bout : on explique et on liste l'état
	print(string.format(BOOT.NOT_LOADED, BootName()))
	local missing = {}
	for _, name in ipairs(APP.coreFiles or {}) do
		if not ns.Loaded[name] then missing[#missing + 1] = name end
	end
	if #missing > 0 then
		print(string.format(BOOT.MISSING, table.concat(missing, ", ")))
	else
		print(BOOT.CMD_FAILED)
	end
	if #ns.errors > 0 then
		print(string.format(BOOT.LAST_ERROR, tostring(ns.errors[#ns.errors].message)))
	end
	print(BOOT.SCRIPT_ERRORS)
end

if APP.slashKey then
	for index, command in ipairs(APP.slash or {}) do
		_G["SLASH_" .. APP.slashKey .. index] = command
	end
	SlashCmdList[APP.slashKey] = Dispatch
end

Mark("Bootstrap")

-- Témoin de chargement : une ligne au /reload. Si tu ne la vois pas, le TOC
-- n'a pas exécuté les fichiers (mauvais dossier, ou TOC refusé par le client).
print(string.format(BOOT.LOADED, BootName()))
