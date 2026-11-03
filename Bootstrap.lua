-- Bootstrap.lua -- chargé EN PREMIER, ne dépend de rien
--
-- Objectif : que /sd réponde TOUJOURS, même si un fichier suivant plante au
-- chargement. C'est ce qui permet de diagnostiquer à distance un addon muet.
local ADDON, ns = ...

ns.version = "1.23.0"
ns.Loaded = {}
ns.loadOrder = {}
ns.errors = {}

local function Mark(name)
	ns.Loaded[name] = true
	ns.loadOrder[#ns.loadOrder + 1] = name
end
ns.Mark = Mark

-- Journalisation d'erreur, appelable depuis n'importe quel fichier
function ns:RecordError(where, message)
	message = tostring(message)
	for _, entry in ipairs(self.errors) do
		if entry.where == where and entry.message == message then return end
	end
	self.errors[#self.errors + 1] = { where = where, message = message }
	if type(print) == "function" then
		print("|cffff2020Ready2Quest — erreur|r (" .. tostring(where) .. ") " .. message)
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

	-- Core.lua n'a pas été jusqu'au bout : on explique et on liste l'état
	print("|cffe8a54bReady2Quest|r " .. tostring(ns.version) .. " — modules non chargés.")
	local missing = {}
	for _, name in ipairs({ "Locales", "Compat", "Hubs", "Theme", "Core", "Buffs", "Reagents",
		"Merchant", "Equip", "Stats", "Minimap", "Checks", "Options", "UI" }) do
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

SLASH_SACETDEPART1 = "/sd"
SLASH_SACETDEPART2 = "/sacdepart"
SLASH_SACETDEPART3 = "/r2q"
SlashCmdList["SACETDEPART"] = Dispatch

Mark("Bootstrap")

-- Témoin de chargement : une ligne au /reload. Si tu ne la vois pas, le TOC
-- n'a pas exécuté les fichiers (mauvais dossier, ou TOC refusé par le client).
print("|cffe8a54bReady2Quest|r " .. ns.version .. " — fichiers chargés")
