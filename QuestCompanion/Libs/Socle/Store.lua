-- Store.lua -- sauvegarde, réglages par défaut, événements internes, modules
-- (socle commun)
--
--   ns:DB()                 la sauvegarde de l'addon (ns.APP.db), réglages par
--                           défaut appliqués ; reprise unique des anciens noms
--                           (ns.APP.legacyDB), puis ns:OnDBReady(db) si défini
--   ns.RegisterDefaults     réglages par défaut d'un module
--   ns:RegisterCallback / ns:FireCallback   événements internes
--   ns.RegisterModule / ns:FindModule       modules (commandes « module »)
--   ns:IsModuleEnabled / SetModuleEnabled   contrôles activables (db.modules)
--   ns:CharKey / ns:CharData                données par personnage
--   ns:RestorePoint                         position mémorisée d'un cadre
--   ns.Now                                  horloge
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
-- socle 2.11.0 : corps du fichier dans une fabrique, compilée une fois quand
-- les deux addons ont le même socle (Base.lua, ns.SocleFile). Rien de propre
-- à l'addon au niveau du fichier : tout passe par ADDON et ns, ci-dessous.
local SOCLE_ADDON, SOCLE_NS = ...
;(SOCLE_NS.SocleFile or function(_, factory) return factory end)("Store", function(...)
local ADDON, ns = ...
local APP = ns.APP

-- ---------------------------------------------------------------------------
-- Réglages par défaut (chaque addon et chaque module y ajoute les siens)
-- ---------------------------------------------------------------------------
local DEFAULTS = {}
ns.DEFAULTS = DEFAULTS

local function SavedTable()
	local value = rawget(_G, APP.db)
	if type(value) == "table" then return value end
	return nil
end

-- API d'extension : réglages par défaut d'un module (fusionnés avant la
-- première lecture de la sauvegarde, ou appliqués aussitôt si elle est lue)
function ns.RegisterDefaults(defaults)
	for k, v in pairs(defaults or {}) do
		if DEFAULTS[k] == nil then DEFAULTS[k] = v end
	end
	local db = SavedTable()
	if ns._dbReady and db then
		for k, v in pairs(defaults or {}) do
			if db[k] == nil then
				if type(v) == "table" then
					db[k] = {}
					for kk, vv in pairs(v) do db[k][kk] = vv end
				else
					db[k] = v
				end
			end
		end
	end
end

-- API d'extension : événements internes de l'addon.
ns.callbacks = {}
function ns:RegisterCallback(event, fn)
	self.callbacks[event] = self.callbacks[event] or {}
	table.insert(self.callbacks[event], fn)
end
function ns:FireCallback(event, ...)
	for _, fn in ipairs(self.callbacks[event] or {}) do
		local ok, err = pcall(fn, self, ...)
		if not ok and self.RecordError then self:RecordError("callback:" .. event, err) end
	end
end

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
	-- Migrations de nom (APP.legacyDB) : on reprend la plus récente des
	-- anciennes sauvegardes, une seule fois.
	-- Attention : WoW charge WTF/.../SavedVariables/<NomDuDossier>.lua. Après
	-- un renommage de dossier, l'ancienne variable n'est chargée que si le
	-- fichier a été renommé lui aussi (voir README, « Migration »).
	if not SavedTable() then
		local db = {}
		_G[APP.db] = db
		for _, name in ipairs(APP.legacyDB or {}) do
			local old = rawget(_G, name)
			if type(old) == "table" then
				for k, v in pairs(old) do db[k] = v end
				self.migratedFrom = name
				break
			end
		end
		for _, name in ipairs(APP.legacyDB or {}) do _G[name] = nil end
	end
	local db = SavedTable()
	if not self._dbReady then
		ApplyDefaults(DEFAULTS, db)
		if self.OnDBReady then self:OnDBReady(db) end
		self._dbReady = true
	end
	return db
end

-- Vide la sauvegarde puis la recrée avec les réglages par défaut
function ns:ResetDB()
	local db = SavedTable()
	for k in pairs(db or {}) do db[k] = nil end
	self._dbReady = false
	return self:DB()
end

local function Now()
	if GetTime then return GetTime() end
	if time then return time() end
	return 0
end
ns.Now = Now

-- ---------------------------------------------------------------------------
-- Données par personnage (la sauvegarde est partagée par tout le compte)
-- ---------------------------------------------------------------------------
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end

function ns:CharKey()
	local name = Call(rawget(_G, "UnitName"), "player") or "?"
	local realm = Call(rawget(_G, "GetRealmName")) or "?"
	return tostring(name) .. "-" .. tostring(realm)
end

function ns:CharData()
	local db = self:DB()
	if type(db.chars) ~= "table" then db.chars = {} end
	local key = self:CharKey()
	db.chars[key] = db.chars[key] or {}
	return db.chars[key]
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
-- Contrôles activables un par un (db.modules[id])
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

-- ---------------------------------------------------------------------------
-- Modules : `id` et `aliases` servent à la commande « module <id> »,
-- `key` est leur interrupteur dans la sauvegarde, `label` leur nom.
-- ---------------------------------------------------------------------------
ns.MODULES = ns.MODULES or {}

-- API d'extension : un module s'ajoute aux commandes « modules » et « module <id> »
function ns.RegisterModule(module)
	table.insert(ns.MODULES, module)
end

function ns:FindModule(id)
	for _, module in ipairs(self.MODULES) do
		if module.id == id then return module end
		for _, alias in ipairs(module.aliases or {}) do if alias == id then return module end end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- La sauvegarde n'est posée par le client qu'à ADDON_LOADED(<cet addon>) : lue
-- plus tôt, ns:DB() sert une table que le client remplace ensuite. À cet
-- instant, on repart donc de la vraie sauvegarde (réglages par défaut
-- réappliqués), puis l'addon peut y travailler : ns:OnAddonLoaded().
-- ---------------------------------------------------------------------------
local ok, loader = pcall(CreateFrame, "Frame")
if ok and loader then
	loader:RegisterEvent("ADDON_LOADED")
	loader:SetScript("OnEvent", function(self, event, name)
		if name ~= ADDON then return end
		if self.UnregisterEvent then self:UnregisterEvent("ADDON_LOADED") end
		ns._dbReady = false
		ns.savedVariablesLoaded = true
		if ns.OnAddonLoaded then
			local done, err = pcall(ns.OnAddonLoaded, ns)
			if not done then ns:RecordError("ADDON_LOADED", err) end
		end
	end)
	ns.loaderFrame = loader
end

if ns.Mark then ns.Mark("Store") end
end)(SOCLE_ADDON, SOCLE_NS)
