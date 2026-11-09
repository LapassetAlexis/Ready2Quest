-- Strings.lua -- chaînes : frFR par défaut, enUS en secours (socle commun)
--
-- ns.L (lecture tolérante), ns.RegisterStrings, ns:F (formatage sans erreur),
-- ns:Print (préfixé par la marque de l'addon, L.TAG), ns.AsciiLower.
-- Les textes génériques du socle (réglages, commandes communes) sont déclarés
-- en bas ; chaque addon déclare les siens par-dessus.
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
-- socle 2.11.0 : corps du fichier dans une fabrique, compilée une fois quand
-- les deux addons ont le même socle (Base.lua, ns.SocleFile). Rien de propre
-- à l'addon au niveau du fichier : tout passe par ADDON et ns, ci-dessous.
local SOCLE_ADDON, SOCLE_NS = ...
;(SOCLE_NS.SocleFile or function(_, factory) return factory end)("Strings", function(...)
local ADDON, ns = ...

local frFR, enUS = {}, {}

local base = frFR
local locale = (GetLocale and GetLocale()) or "frFR"
local french = locale == "frFR" or locale == "fr"
if not french then
	base = enUS
end

-- Mémoire (1.6.1 / 1.29.3) : seule la langue du client est gardée. Sur un
-- client anglais, une clé sans traduction prend le texte français dès sa
-- déclaration (même repli qu'avant, sans garder tout le français). Les tests
-- (ADDON_TESTING) gardent les deux langues et les tables sources exposées
-- (ns.KEEP_STRINGS) pour contrôler la parité fr/en.
ns.KEEP_STRINGS = rawget(_G, "ADDON_TESTING") and true or false
-- langue gardée : le français (client frFR), sinon l'anglais
ns.STRINGS_FRENCH = french

-- Sources de textes calculés (QC 2.8.1 / R2Q 1.29.5) : fn(clé) -> texte ou
-- nil, consultées quand la clé n'est déclarée dans aucune langue. Sert aux
-- données gardées sous une forme plus légère qu'une clé par texte (répliques
-- du compagnon de QuestCompanion).
local sources = {}
function ns.RegisterStringSource(fn)
	if type(fn) == "function" then sources[#sources + 1] = fn end
end

-- API d'extension : chaque fichier déclare ses chaînes, sans toucher aux
-- autres. ns.RegisterStrings({ CLE = "fr" }, { CLE = "en" }) ; la dernière
-- déclaration d'une clé l'emporte (l'addon prime sur le socle).
function ns.RegisterStrings(fr, en)
	if french or ns.KEEP_STRINGS then
		for k, v in pairs(fr or {}) do frFR[k] = v end
	end
	if not french or ns.KEEP_STRINGS then
		for k, v in pairs(en or {}) do enUS[k] = v end
		if not french and not ns.KEEP_STRINGS then
			-- repli français pour les clés que l'anglais n'a pas (encore)
			for k, v in pairs(fr or {}) do
				if enUS[k] == nil then enUS[k] = v end
			end
		end
	end
end

-- Repli : toute clé absente de la langue active retombe sur le français.
-- IMPORTANT : la métatable est posée sur une table PROXY, jamais sur `base`.
-- Sinon, sur un client français, `base` vaut `frFR` et la lecture de `frFR[key]`
-- dans `__index` se rappelle elle-même -> « C stack overflow ».
local L = {}
setmetatable(L, { __index = function(_, key)
	local value = base[key]
	if value ~= nil then return value end
	value = frFR[key]
	if value ~= nil then return value end
	for i = 1, #sources do
		value = sources[i](key)
		if value ~= nil then return value end
	end
	return key
end })
ns.L = L

-- Minuscules ASCII seulement. string.lower et %s dépendent de la locale C :
-- en Latin-1, lower transforme l'octet 0xC3 (début de é, è, à…) en 0xE3 et
-- casse l'UTF-8 ; %s y reconnaît 0xA0 (fin de « à »). On ne touche donc
-- qu'aux lettres A-Z et aux espaces ASCII, et l'espace insécable devient une
-- espace normale.
-- Table de correspondance A-Z -> a-z faite une fois : gsub avec une table
-- n'alloue pas de fermeture à chaque appel (chemins fréquents : buffs, noms).
local ASCII_LOWER = {}
for byte = 65, 90 do ASCII_LOWER[string.char(byte)] = string.char(byte + 32) end
function ns.AsciiLower(text)
	if type(text) ~= "string" then return text end
	text = text:gsub("[A-Z]", ASCII_LOWER)
	text = text:gsub("\194\160", " "):gsub("[ \t\r\n]+", " "):gsub("^ ", ""):gsub(" $", "")
	return text
end

-- Formatage défensif : jamais d'erreur si un placeholder manque.
function ns:F(key, ...)
	local fmt = ns.L[key]
	if type(fmt) ~= "string" then return tostring(key) end
	local ok, out = pcall(string.format, fmt, ...)
	if ok then return out end
	return fmt
end

-- socle 2.11.0 : pluriel accordé. CLE_ZERO (facultatif), CLE_ONE, CLE_MANY ;
-- repli sur CLE si les variantes manquent (migration progressive).
-- Français : 0 et 1 au singulier ; anglais : 1 seulement.
function ns:FP(key, n, ...)
	n = tonumber(n) or 0
	local L = ns.L
	local function Has(k) local text = L[k]; return type(text) == "string" and text ~= k end
	local pick = key
	if n == 0 and Has(key .. "_ZERO") then
		pick = key .. "_ZERO"
	elseif Has(key .. "_ONE") and Has(key .. "_MANY") then
		local one
		if ns.STRINGS_FRENCH then one = n <= 1 and n >= -1 else one = n == 1 end
		pick = key .. (one and "_ONE" or "_MANY")
	end
	return self:F(pick, n, ...)
end

function ns:Print(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring((select(i, ...)))
	end
	print(ns.L.TAG .. " " .. table.concat(parts, " "))
end

-- ---------------------------------------------------------------------------
-- Textes du socle : panneau de réglages, commandes communes, minicarte.
-- Ceux qui nomment l'addon ou sa commande sont tirés de ns.APP ; chaque addon
-- peut tous les redéclarer (sa déclaration l'emporte).
-- ---------------------------------------------------------------------------
local APP = ns.APP or {}
local SLASH = (APP.slash and APP.slash[#APP.slash]) or "/?"
ns.RegisterStrings({
	OPT_TITLE           = "Réglages",
	OPT_HINT            = "Clique une ligne pour changer la valeur.",
	OPT_PAGE_GENERAL    = "Général",
	OPT_GROUP_MODULES   = "MODULES",
	OPT_ENABLED         = "Addon actif",
	OPT_SECTION_DISPLAY = "AFFICHAGE",
	OPT_MINIMAP         = "Bouton sur la minicarte",
	OPT_MINIMAP_POS     = "Position du bouton",
	OPT_MODULES         = "MODULES",
	OPT_CHECKS          = "CONTRÔLES",
	OPT_SETTINGS        = "RÉGLAGES",
	OPT_ON              = "OUI",
	OPT_OFF             = "non",
	OPT_REMOVE          = "Retirer",
	OPT_RESET           = "Réinitialiser",
	OPT_CLOSE           = "Fermer",
	OPT_DONE            = "Terminé",
	OPT_SEARCH          = "Rechercher",
	OPT_NAV_OVERVIEW    = "Vue d'ensemble",
	OPT_SEARCH_TITLE    = "Recherche",
	OPT_SEARCH_COUNT    = "%d réglage(s) pour « %s »",
	OPT_SEARCH_NONE     = "Aucun réglage ne correspond à « %s ».",
	OPT_SECTION_ACTIONS = "ACTIONS",
	OPT_SECTION_FRAMES  = "CADRES",
	OPT_FRAMES_LABEL    = "Position des cadres à l'écran",
	OPT_BTN_RUN         = "Lancer",
	OPT_BTN_CHANGE      = "Changer",
	OPT_BTN_FORGET      = "Oublier",
	OPT_BTN_REPLAY      = "Rejouer",
	OPT_VERSION_LINE    = "v%s  ·  %s",
	OPT_NAV_POWER_TIP   = "Active ou coupe tous les modules de cette page.",
	-- socle 2.11.0 : page d'un module coupé
	OPT_PAGE_OFF        = "Module coupé : ces réglages s'appliqueront quand tu le rallumeras.",
	OPT_PAGE_OFF_ON     = "Rallumer",
	DIAG_SOCLE          = "Socle : %s (%s)",
	DIAG_SOCLE_SHARED   = "partagé",
	DIAG_SOCLE_OWN      = "propre",
	OPT_EDIT_BUTTON     = "Déplacer les cadres",
	OPT_EDIT_MODE       = "Mode édition des cadres",
	OPT_EDIT_HINT       = "Fais glisser les cadres pour les placer.",
	OPT_EDIT_STOP       = "Terminer le déplacement",
	OPT_RESET_FRAMES    = "Réinitialiser les cadres",
	MODULE_ON           = "activé",
	MODULE_OFF          = "désactivé",
	MSG_MODULES_HEADER  = "Modules :",
	MSG_MODULE_ROW      = "  %-12s %s",
	MSG_MODULE_SET      = "Module %s : %s",
	MSG_RESET           = "Réglages réinitialisés.",
	MSG_DIAG_HEADER     = "Diagnostic :",
	MSG_MINIMAP_ON      = "Bouton de minicarte affiché.",
	MSG_MINIMAP_OFF     = "Bouton de minicarte masqué.",
	MSG_MINIMAP_POS     = "Bouton de minicarte : angle %d°.",
	MINIMAP_RIGHT       = "Clic droit : réglages",
	MINIMAP_DRAG        = "Glisse pour déplacer autour de la minicarte",
	ADDON_NAME         = tostring(APP.id),
	TAG                = "|cffe8a54b[" .. tostring(APP.id) .. "]|r",
	HELP_TITLE         = "Commandes : " .. SLASH .. ".",
	MSG_UNKNOWN_CMD    = "Commande inconnue. Tape " .. SLASH .. " help pour l'aide.",
	MSG_MODULE_UNKNOWN = "Module inconnu. Essaie " .. SLASH .. " modules.",
	MSG_MODULES_HINT   = "|cff888888" .. SLASH .. " module <id> on|off|r",
	MINIMAP_LEFT       = "Clic gauche : ouvrir",
	SETTINGS_VERSION   = "Version %s",
	SETTINGS_HINT      = "Les réglages de l'addon ont leur propre fenêtre.",
	SETTINGS_OPEN      = "Ouvrir les réglages",
}, {
	OPT_TITLE           = "Settings",
	OPT_HINT            = "Click a row to change the value.",
	OPT_PAGE_GENERAL    = "General",
	OPT_GROUP_MODULES   = "MODULES",
	OPT_ENABLED         = "Addon enabled",
	OPT_SECTION_DISPLAY = "DISPLAY",
	OPT_MINIMAP         = "Minimap button",
	OPT_MINIMAP_POS     = "Button position",
	OPT_MODULES         = "MODULES",
	OPT_CHECKS          = "CHECKS",
	OPT_SETTINGS        = "SETTINGS",
	OPT_ON              = "YES",
	OPT_OFF             = "no",
	OPT_REMOVE          = "Remove",
	OPT_RESET           = "Reset",
	OPT_CLOSE           = "Close",
	OPT_DONE            = "Done",
	OPT_SEARCH          = "Search",
	OPT_NAV_OVERVIEW    = "Overview",
	OPT_SEARCH_TITLE    = "Search",
	OPT_SEARCH_COUNT    = "%d setting(s) for “%s”",
	OPT_SEARCH_NONE     = "No setting matches “%s”.",
	OPT_SECTION_ACTIONS = "ACTIONS",
	OPT_SECTION_FRAMES  = "FRAMES",
	OPT_FRAMES_LABEL    = "Position of the on-screen frames",
	OPT_BTN_RUN         = "Run",
	OPT_BTN_CHANGE      = "Change",
	OPT_BTN_FORGET      = "Forget",
	OPT_BTN_REPLAY      = "Replay",
	OPT_VERSION_LINE    = "v%s  ·  %s",
	OPT_NAV_POWER_TIP   = "Turns every module of this page on or off.",
	OPT_PAGE_OFF        = "Module off: these settings will apply once you turn it back on.",
	OPT_PAGE_OFF_ON     = "Turn on",
	DIAG_SOCLE          = "Shared core: %s (%s)",
	DIAG_SOCLE_SHARED   = "shared",
	DIAG_SOCLE_OWN      = "own copy",
	OPT_EDIT_BUTTON     = "Move the frames",
	OPT_EDIT_MODE       = "Frame edit mode",
	OPT_EDIT_HINT       = "Drag the frames to place them.",
	OPT_EDIT_STOP       = "Finish moving",
	OPT_RESET_FRAMES    = "Reset frames",
	MODULE_ON           = "enabled",
	MODULE_OFF          = "disabled",
	MSG_MODULES_HEADER  = "Modules:",
	MSG_MODULE_ROW      = "  %-12s %s",
	MSG_MODULE_SET      = "Module %s: %s",
	MSG_RESET           = "Settings reset.",
	MSG_DIAG_HEADER     = "Diagnostics:",
	MSG_MINIMAP_ON      = "Minimap button shown.",
	MSG_MINIMAP_OFF     = "Minimap button hidden.",
	MSG_MINIMAP_POS     = "Minimap button: angle %d°.",
	MINIMAP_RIGHT       = "Right click: settings",
	MINIMAP_DRAG        = "Drag to move around the minimap",
	ADDON_NAME         = tostring(APP.id),
	TAG                = "|cffe8a54b[" .. tostring(APP.id) .. "]|r",
	HELP_TITLE         = "Commands: " .. SLASH .. ".",
	MSG_UNKNOWN_CMD    = "Unknown command. Type " .. SLASH .. " help for help.",
	MSG_MODULE_UNKNOWN = "Unknown module. Try " .. SLASH .. " modules.",
	MSG_MODULES_HINT   = "|cff888888" .. SLASH .. " module <id> on|off|r",
	MINIMAP_LEFT       = "Left click: open",
	SETTINGS_VERSION   = "Version %s",
	SETTINGS_HINT      = "The addon's settings have their own window.",
	SETTINGS_OPEN      = "Open the settings",
})

if ns.Mark then ns.Mark("Strings") end
end)(SOCLE_ADDON, SOCLE_NS)
