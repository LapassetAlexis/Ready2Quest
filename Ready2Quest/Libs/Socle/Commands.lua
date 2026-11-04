-- Commands.lua -- commande de l'addon (/r2q, /qc…) : registre et commandes
-- communes (socle commun)
--
--   ns.COMMANDS[nom] = function(self, reste)   une sous-commande ;
--                      ns.EXTRA_COMMANDS est le même registre (ancien nom)
--   ns.HELP            aide classée par rubrique : { titre, { lignes } }
--   ns:DefaultCommand() commande sans argument (sinon : l'aide)
--   ns:OnModuleToggled(key, enabled)   après « module <id> on|off »
--   ns:DiagExtra()     lignes propres à l'addon dans « diag »
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
local ADDON, ns = ...
local L = ns.L

ns.COMMANDS = ns.COMMANDS or {}
ns.EXTRA_COMMANDS = ns.COMMANDS
ns.HELP = ns.HELP or {}
local COMMANDS = ns.COMMANDS

-- Aide classée par rubrique (titre en ambre, puis les commandes)
function ns:PrintHelp()
	-- le préfixe de l'addon seulement en tête : répété sur 30 lignes, il noie l'aide
	self:Print(L.HELP_TITLE)
	for _, section in ipairs(self.HELP) do
		print(ns.Theme.T_GOLD .. tostring(L[section[1]]) .. "|r")
		for _, key in ipairs(section[2]) do print("   " .. tostring(L[key])) end
	end
end

local function Toggle(self)
	if self.ToggleOptions then self:ToggleOptions() else self:Print(L.MSG_UNKNOWN_CMD) end
end

COMMANDS["help"] = function(self) self:PrintHelp() end
COMMANDS["aide"] = COMMANDS["help"]
COMMANDS["?"] = COMMANDS["help"]
COMMANDS["options"] = Toggle
COMMANDS["config"] = Toggle

COMMANDS["minimap"] = function(self, value)
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
end

COMMANDS["reset"] = function(self)
	self:ResetDB()
	self:Print(L.MSG_RESET)
end

COMMANDS["modules"] = function(self)
	local db = self:DB()
	self:Print(L.MSG_MODULES_HEADER)
	for _, module in ipairs(self.MODULES) do
		local on = db[module.key] ~= false
		local state = on and (ns.Theme.T_GREEN .. L.MODULE_ON .. "|r") or ("|cffff2020" .. L.MODULE_OFF .. "|r")
		self:Print(self:F("MSG_MODULE_ROW", module.id, state .. "  " .. tostring(L[module.label] or module.id)))
	end
	self:Print(L.MSG_MODULES_HINT)
end

COMMANDS["module"] = function(self, rest)
	local id, value = tostring(rest or ""):match("^(%S*)%s*(%S*)$")
	local module = self:FindModule((id or ""):lower())
	if not module then return self:Print(L.MSG_MODULE_UNKNOWN) end
	local db = self:DB()
	local enabled
	if value == "on" then enabled = true elseif value == "off" then enabled = false
	else enabled = not (db[module.key] ~= false) end
	db[module.key] = enabled
	if self.OnModuleToggled then self:OnModuleToggled(module.key, enabled) end
	self:Print(self:F("MSG_MODULE_SET", tostring(L[module.label] or module.id), enabled and L.MODULE_ON or L.MODULE_OFF))
	if self.RefreshOptions then self:RefreshOptions() end
end

COMMANDS["diag"] = function(self)
	self:Print(L.MSG_DIAG_HEADER .. " v" .. tostring(ns.version or "?"))
	if self.PrintCapabilities then self:PrintCapabilities() end
	local loaded, missing = {}, {}
	for _, name in ipairs(ns.APP.coreFiles or {}) do
		if ns.Loaded and ns.Loaded[name] then loaded[#loaded + 1] = name else missing[#missing + 1] = name end
	end
	self:Print(string.format("  modules : " .. ns.Theme.T_GREEN .. "%d/%d|r chargés", #loaded, #loaded + #missing))
	if #missing > 0 then self:Print("  |cffff2020non chargés :|r " .. table.concat(missing, ", ")) end
	for _, entry in ipairs(ns.errors or {}) do
		self:Print("  |cffff2020erreur|r " .. tostring(entry.where) .. " : " .. tostring(entry.message))
	end
	if self.DiagExtra then self:DiagExtra() end
end

function ns:HandleCommand(input)
	local command, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
	command = (command or ""):lower()

	if command == "" then
		if self.DefaultCommand then return self:DefaultCommand() end
		return self:PrintHelp()
	end

	local fn = COMMANDS[command]
	if fn then
		fn(self, rest)
		return
	end

	-- une ligne qui renvoie vers l'aide, plutôt que 25 lignes déversées
	self:Print(L.MSG_UNKNOWN_CMD)
end

if ns.Mark then ns.Mark("Commands") end
