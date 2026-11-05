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

-- Journalisation d'erreur, appelable depuis n'importe quel fichier
function ns:RecordError(where, message)
	message = tostring(message)
	for _, entry in ipairs(self.errors) do
		if entry.where == where and entry.message == message then return end
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
