-- Locales.lua -- textes communs de QuestCompanion (frFR, enUS)
--
-- Chaque module déclare les siens dans son fichier (ns.RegisterStrings).
-- Ceux du panneau de réglages et des commandes communes viennent du socle
-- (Libs/Socle/Strings.lua) ; ceux-ci les complètent ou les remplacent.
local ADDON, ns = ...
if ns.blocked then return end

local frFR = {
	ADDON_NAME           = "QuestCompanion",
	TAG                  = "|cffe8a54b[Quest|r|cff5b8fd6Companion|r|cffe8a54b]|r",
	HELP_TITLE           = "Commandes : /qc ou /questcompanion, au choix.",
	MSG_UNKNOWN_CMD      = "Commande inconnue. Tape /qc help pour l'aide.",
	MSG_MODULE_UNKNOWN   = "Module inconnu. Essaie /qc modules.",
	MSG_MODULES_HINT     = "|cff888888/qc module compagnon on|off|r",
	MINIMAP_LEFT         = "Clic gauche : ouvrir le carnet",
	OPT_PAGE_GENERAL_SUB = "L'addon et son bouton de minicarte.",
	QC_OPEN_JOURNAL      = "Ouvrir le carnet",
	HELP_H_OPEN          = "OUVRIR",
	HELP_H_QUICK         = "COMPAGNON",
	HELP_H_MISC          = "DIVERS",
	QC_HELP_RUN          = "/qc -- ouvre le carnet de voyage",
	QC_HELP_OPTIONS      = "/qc options -- les réglages",
	QC_HELP_MODULES      = "/qc modules · /qc module compagnon on|off -- active ou coupe le compagnon",
	QC_HELP_MINIMAP      = "/qc minimap [on|off] -- le bouton de la minicarte",
	QC_HELP_RESET        = "/qc reset -- remet les réglages à zéro (pas ton compagnon ni ton carnet)",
	QC_HELP_DIAG         = "/qc diag -- diagnostic, à joindre si tu signales un problème",
	QC_MSG_MIGRATED      = "Compagnon, carnet et coffres repris de Ready2Quest (%d personnage(s)).",
}

local enUS = {
	ADDON_NAME           = "QuestCompanion",
	TAG                  = "|cffe8a54b[Quest|r|cff5b8fd6Companion|r|cffe8a54b]|r",
	HELP_TITLE           = "Commands: /qc or /questcompanion, your pick.",
	MSG_UNKNOWN_CMD      = "Unknown command. Type /qc help for help.",
	MSG_MODULE_UNKNOWN   = "Unknown module. Try /qc modules.",
	MSG_MODULES_HINT     = "|cff888888/qc module compagnon on|off|r",
	MINIMAP_LEFT         = "Left click: open the journal",
	OPT_PAGE_GENERAL_SUB = "The addon and its minimap button.",
	QC_OPEN_JOURNAL      = "Open the journal",
	HELP_H_OPEN          = "OPEN",
	HELP_H_QUICK         = "COMPANION",
	HELP_H_MISC          = "MISC",
	QC_HELP_RUN          = "/qc -- opens the travel journal",
	QC_HELP_OPTIONS      = "/qc options -- the settings",
	QC_HELP_MODULES      = "/qc modules · /qc module compagnon on|off -- turns the companion on or off",
	QC_HELP_MINIMAP      = "/qc minimap [on|off] -- the minimap button",
	QC_HELP_RESET        = "/qc reset -- resets the settings (not your companion nor your journal)",
	QC_HELP_DIAG         = "/qc diag -- diagnostics, to attach to a bug report",
	QC_MSG_MIGRATED      = "Companion, journal and chests taken over from Ready2Quest (%d character(s)).",
}

ns.RegisterStrings(frFR, enUS)
ns.QC_STRINGS = { fr = frFR, en = enUS }   -- exposé aux tests (parité fr/en)

if ns.Mark then ns.Mark("Locales") end
