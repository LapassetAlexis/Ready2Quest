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
local SOCLE_ID = "b82d9b2a"
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
		print("|cffff2020" .. tostring(APP.id) .. " — erreur|r (" .. tostring(where) .. ") " .. message)
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
	print("|cffe8a54b" .. tostring(APP.id) .. "|r " .. tostring(ns.version) .. " — modules non chargés.")
	local missing = {}
	for _, name in ipairs(APP.coreFiles or {}) do
		if not ns.Loaded[name] then missing[#missing + 1] = name end
	end
	if #missing > 0 then
		print("  fichiers non exécutés : " .. table.concat(missing, ", "))
	else
		print("  tous les fichiers sont chargés, mais la commande n'a pas pu être exécutée.")
	end
	if #ns.errors > 0 then
		print("  dernière erreur : " .. ns.errors[#ns.errors].message)
	end
	print("  active les erreurs Lua : /console scriptErrors 1 puis /reload")
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
print("|cffe8a54b" .. tostring(APP.id) .. "|r " .. tostring(ns.version) .. " — fichiers chargés")
