-- Core.lua -- cœur de QuestCompanion : réglages généraux, commande /qc,
-- bouton de minicarte, reprise des données de Ready2Quest
--
-- QuestCompanion est autonome : son socle (Libs/Socle) est embarqué, sa
-- sauvegarde est QuestCompanionDB, sa commande /qc, son panneau de réglages
-- et son bouton de minicarte sont les siens. Ready2Quest n'est pas requis.
-- S'il est là, deux liens facultatifs :
--   * ses départs et retours de zone sûre (callbacks DEPARTURE / RETURN)
--     font réagir le compagnon ;
--   * jusqu'à Ready2Quest 1.25, compagnon et carnet vivaient dans
--     Ready2QuestDB : ils sont repris une fois (## OptionalDeps: Ready2Quest
--     fait charger Ready2Quest, et sa sauvegarde, avant QuestCompanion).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.RegisterDefaults({
	enabled     = true,
	showMinimap = true,
	chars       = {},   -- [Nom-Royaume] = { companion, journal }
})

-- ---------------------------------------------------------------------------
-- Réglages : la page Général, le bouton principal, l'aide
-- ---------------------------------------------------------------------------
ns.AddOptionPage({
	id = "general", title = "OPT_PAGE_GENERAL",
	rows = {
		{ key = "enabled",     label = "OPT_ENABLED",     kind = "bool" },
		{ header = "OPT_SECTION_DISPLAY" },
		{ key = "showMinimap", label = "OPT_MINIMAP",     kind = "bool" },
		{ key = "minimapPos",  label = "OPT_MINIMAP_POS", kind = "action", button = "OPT_BTN_CHANGE" },
	},
})

ns.OPTIONS_MAIN = { label = "QC_OPEN_JOURNAL", run = function(self) self:ToggleJournal() end }

ns.HELP = {
	{ "HELP_H_OPEN",  { "QC_HELP_RUN", "QC_HELP_OPTIONS" } },
	{ "HELP_H_QUICK", { "QC_HELP_MODULES" } },
	{ "HELP_H_MISC",  { "QC_HELP_MINIMAP", "QC_HELP_RESET", "QC_HELP_DIAG" } },
}

-- /qc sans argument, et clic gauche sur le bouton de minicarte : le carnet
function ns:DefaultCommand()
	if self.ToggleJournal then self:ToggleJournal() else self:PrintHelp() end
end

-- /qc reset : les réglages seulement. La progression (compagnon, carnet,
-- coffres : db.chars) et la reprise depuis Ready2Quest restent.
ns.COMMANDS["reset"] = function(self)
	local db = self:DB()
	local chars, migrated, dropped = db.chars, db.migratedFromR2Q, db.memoriesDropped
	db = self:ResetDB()
	db.chars, db.migratedFromR2Q, db.memoriesDropped = chars or {}, migrated, dropped
	self:Print(L.MSG_RESET)
	if self.RefreshOptions then self:RefreshOptions() end
end

-- ---------------------------------------------------------------------------
-- Reprise depuis Ready2Quest (1.25 et avant)
-- ---------------------------------------------------------------------------
-- Réglages du compagnon et du carnet : companion*, journal* (bulles, suivi à
-- l'écran, positions des cadres…). Progression : chars[clé].companion et
-- chars[clé].journal (bestiaire, récolte, coffres et zones suivies compris).
local function OwnedKey(key)
	return type(key) == "string" and (key:find("^companion") or key:find("^journal")) and true or false
end

-- Renvoie le nombre de personnages repris. Sans sauvegarde de Ready2Quest
-- (addon absent ou désactivé), rien n'est marqué : on réessaiera.
function ns:MigrateFromReady2Quest()
	local db = self:DB()
	if db.migratedFromR2Q then return 0 end
	local old = rawget(_G, "Ready2QuestDB")
	if type(old) ~= "table" then return 0 end

	local keys = {}
	for key in pairs(old) do if OwnedKey(key) then keys[#keys + 1] = key end end
	for _, key in ipairs(keys) do
		db[key] = old[key]
		old[key] = nil
	end

	local moved = 0
	if type(old.chars) == "table" then
		if type(db.chars) ~= "table" then db.chars = {} end
		for charKey, char in pairs(old.chars) do
			if type(char) == "table" and (type(char.companion) == "table" or type(char.journal) == "table") then
				local mine = db.chars[charKey]
				if type(mine) ~= "table" then mine = {}; db.chars[charKey] = mine end
				for _, field in ipairs({ "companion", "journal" }) do
					if type(char[field]) == "table" then
						-- une progression déjà commencée dans QuestCompanion l'emporte
						if mine[field] == nil then mine[field] = char[field] end
						char[field] = nil
					end
				end
				moved = moved + 1
			end
		end
	end
	db.migratedFromR2Q = true
	-- ce qui vient d'arriver de Ready2Quest passe aussi par le ménage des souvenirs
	db.memoriesDropped = nil
	if moved > 0 then self:Print(self:F("QC_MSG_MIGRATED", moved)) end
	return moved
end

-- ---------------------------------------------------------------------------
-- Ménage de la 2.6.0 : l'album des souvenirs est retiré
-- ---------------------------------------------------------------------------
-- Une fois, en silence : les données de l'album quittent la sauvegarde (elle
-- maigrit d'autant). Le plus vieux souvenir recale d'abord « jours passés
-- ensemble » (data.since) s'il n'était pas encore posé. Jamais d'erreur sur
-- une vieille sauvegarde : tout est vérifié avant d'être lu.
ns.MEMORY_DROPPED_KEYS = { "memories", "memoryKeys", "metAt", "sillyScore", "photoDay" }
ns.MEMORY_DROPPED_SETTINGS = { "companionPhotos", "companionPhotosAsked", "companionRecall" }

-- Renvoie le nombre de personnages nettoyés
function ns:DropMemories()
	local db = self:DB()
	if db.memoriesDropped then return 0 end
	for _, key in ipairs(ns.MEMORY_DROPPED_SETTINGS) do db[key] = nil end
	local cleaned = 0
	if type(db.chars) == "table" then
		for _, char in pairs(db.chars) do
			local data = type(char) == "table" and char.companion
			if type(data) == "table" then
				local found = false
				if not tonumber(data.since) and type(data.memories) == "table" then
					local oldest
					for _, memory in ipairs(data.memories) do
						local at = type(memory) == "table" and tonumber(memory.at)
						if at and at > 0 and (not oldest or at < oldest) then oldest = at end
					end
					if not oldest and tonumber(data.metAt) and tonumber(data.metAt) > 0 then oldest = tonumber(data.metAt) end
					data.since = oldest
				end
				for _, key in ipairs(ns.MEMORY_DROPPED_KEYS) do
					if data[key] ~= nil then data[key], found = nil, true end
				end
				if found then cleaned = cleaned + 1 end
			end
		end
	end
	db.memoriesDropped = true
	return cleaned
end

function ns:OnAddonLoaded()
	self:MigrateFromReady2Quest()
	local ok, err = pcall(self.DropMemories, self)
	if not ok and self.RecordError then self:RecordError("memories:drop", err) end
	-- réglette « Bavardage » : cran déduit des anciens réglages, une fois
	if self.CompanionChatterLevel then self:CompanionChatterLevel() end
end

-- ---------------------------------------------------------------------------
-- Lien facultatif avec Ready2Quest : départs et retours de zone sûre
-- ---------------------------------------------------------------------------
function ns:BridgeReady2Quest(r2q)
	if r2q == nil then r2q = rawget(_G, "Ready2Quest") end
	if type(r2q) ~= "table" or r2q == ns or type(r2q.RegisterCallback) ~= "function" then return false end
	for _, event in ipairs({ "DEPARTURE", "RETURN" }) do
		r2q:RegisterCallback(event, function(_, ...) ns:FireCallback(event, ...) end)
	end
	self.r2qBridge = r2q
	return true
end
ns:BridgeReady2Quest()

-- ---------------------------------------------------------------------------
-- Événements du cœur : le bouton de minicarte à l'entrée en jeu
-- ---------------------------------------------------------------------------
local ok, frame = pcall(CreateFrame, "Frame")
if ok and frame then
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:SetScript("OnEvent", function()
		if ns:DB().showMinimap ~= false and ns.ShowMinimapButton then ns:ShowMinimapButton() end
	end)
	ns.coreEventFrame = frame
end

-- ---------------------------------------------------------------------------
-- Tables de zones paresseuses (1.6.1) : les données livrées par zone
-- (ZoneCreatures_<client>.lua, ZoneQuests_<client>.lua) restent dans le
-- fichier sous forme d'une fonction par zone ; la zone n'est construite en
-- tables qu'à sa première lecture (t[zoneID]) et gardée ensuite. On ne paie
-- donc en mémoire que les zones vraiment visitées.
-- `pairs` ne voit pas les zones pas encore lues : on passe par
-- ns.ZoneIds(t) (les identifiants) et ns.ZoneEach(t, fn) (chaque zone, sans
-- garder celles qui n'étaient pas encore lues : le Pokédex parcourt tout le
-- jeu sans tout retenir).
-- ---------------------------------------------------------------------------
local lazyZones = setmetatable({}, { __mode = "k" })   -- table -> { makers, ids }
function ns.LazyZones(makers)
	local ids = {}
	for zoneID in pairs(makers) do ids[#ids + 1] = zoneID end
	table.sort(ids)
	local proxy = setmetatable({}, { __index = function(self, zoneID)
		local make = makers[zoneID]
		if type(make) ~= "function" then return nil end
		local zone = make()
		rawset(self, zoneID, zone)
		return zone
	end })
	lazyZones[proxy] = { makers = makers, ids = ids }
	return proxy
end

-- Identifiants des zones d'une table (paresseuse ou ordinaire)
function ns.ZoneIds(t)
	local lazy = type(t) == "table" and lazyZones[t]
	if lazy then return lazy.ids end
	local ids = {}
	for zoneID in pairs(type(t) == "table" and t or {}) do ids[#ids + 1] = zoneID end
	return ids
end

-- Chaque zone : fn(zoneID, zone). Une zone pas encore lue est construite pour
-- l'occasion et n'est pas gardée.
function ns.ZoneEach(t, fn)
	local lazy = type(t) == "table" and lazyZones[t]
	if not lazy then
		for zoneID, zone in pairs(type(t) == "table" and t or {}) do fn(zoneID, zone) end
		return
	end
	for _, zoneID in ipairs(lazy.ids) do
		local zone = rawget(t, zoneID) or lazy.makers[zoneID]()
		fn(zoneID, zone)
	end
end

-- Une zone, sans la garder si elle n'était pas encore lue (rattrapages qui
-- passent sur beaucoup de zones une seule fois)
function ns.ZonePeek(t, zoneID)
	if type(t) ~= "table" or zoneID == nil then return nil end
	local lazy = lazyZones[t]
	if not lazy then return t[zoneID] end
	local zone = rawget(t, zoneID)
	if zone ~= nil then return zone end
	local make = lazy.makers[zoneID]
	return type(make) == "function" and make() or nil
end

-- API publique
_G.QuestCompanion = ns

if ns.Mark then ns.Mark("Core") end
