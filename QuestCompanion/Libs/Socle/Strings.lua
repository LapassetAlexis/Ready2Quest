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
local ADDON, ns = ...

local frFR, enUS = {}, {}

-- API d'extension : chaque fichier déclare ses chaînes, sans toucher aux
-- autres. ns.RegisterStrings({ CLE = "fr" }, { CLE = "en" }) ; la dernière
-- déclaration d'une clé l'emporte (l'addon prime sur le socle).
function ns.RegisterStrings(fr, en)
	for k, v in pairs(fr or {}) do frFR[k] = v end
	for k, v in pairs(en or {}) do enUS[k] = v end
end

local base = frFR
local locale = (GetLocale and GetLocale()) or "frFR"
if locale ~= "frFR" and locale ~= "fr" then
	base = enUS
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
	return key
end })
ns.L = L

-- Minuscules ASCII seulement. string.lower et %s dépendent de la locale C :
-- en Latin-1, lower transforme l'octet 0xC3 (début de é, è, à…) en 0xE3 et
-- casse l'UTF-8 ; %s y reconnaît 0xA0 (fin de « à »). On ne touche donc
-- qu'aux lettres A-Z et aux espaces ASCII, et l'espace insécable devient une
-- espace normale.
function ns.AsciiLower(text)
	if type(text) ~= "string" then return text end
	text = text:gsub("[A-Z]", function(c) return string.char(c:byte() + 32) end)
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
	OPT_BTN_OPEN        = "Ouvrir",
	OPT_BTN_FORGET      = "Oublier",
	OPT_BTN_REPLAY      = "Rejouer",
	OPT_VERSION_LINE    = "v%s  ·  %s",
	OPT_NAV_POWER_TIP   = "Active ou coupe tous les modules de cette page.",
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
	OPT_BTN_OPEN        = "Open",
	OPT_BTN_FORGET      = "Forget",
	OPT_BTN_REPLAY      = "Replay",
	OPT_VERSION_LINE    = "v%s  ·  %s",
	OPT_NAV_POWER_TIP   = "Turns every module of this page on or off.",
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
