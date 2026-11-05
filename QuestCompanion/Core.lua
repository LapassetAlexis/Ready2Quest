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
	local chars, migrated = db.chars, db.migratedFromR2Q
	db = self:ResetDB()
	db.chars, db.migratedFromR2Q = chars or {}, migrated
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
	if moved > 0 then self:Print(self:F("QC_MSG_MIGRATED", moved)) end
	return moved
end

function ns:OnAddonLoaded()
	self:MigrateFromReady2Quest()
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

-- API publique
_G.QuestCompanion = ns

if ns.Mark then ns.Mark("Core") end
