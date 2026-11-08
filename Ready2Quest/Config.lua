-- Config.lua -- identité de Ready2Quest pour le socle commun (Libs/Socle)
--
-- Chargé EN PREMIER : le socle (Base, Strings, Store, Commands, Options,
-- Minimap…) est le même code dans Ready2Quest et QuestCompanion ; il lit ici
-- le nom de l'addon, sa sauvegarde, ses commandes et son logo.
local ADDON, ns = ...

ns.APP = {
	id = "Ready2Quest",
	version = "1.29.6",
	-- nom dans l'en-tête des réglages, le « 2 » en bleu
	brand = "Ready|cff5b8fd62|rQuest",
	-- sauvegarde (## SavedVariables), et anciens noms repris une fois
	db = "Ready2QuestDB",
	legacyDB = { "ReadyToQuestDB", "SacEtDepartDB" },
	-- /r2q, et les anciens /sd et /sacdepart
	slashKey = "SACETDEPART",
	slash = { "/sd", "/sacdepart", "/r2q" },
	-- fichiers attendus, pour le diagnostic quand l'addon reste muet
	coreFiles = { "Bootstrap", "Locales", "Compat", "Hubs", "Theme", "Core", "Buffs",
		"Reagents", "Merchant", "Equip", "Stats", "Minimap", "Checks", "Options", "UI" },
}
