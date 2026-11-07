-- Config.lua -- identité de QuestCompanion pour le socle commun (Libs/Socle)
--
-- Chargé EN PREMIER : le socle (Base, Strings, Store, Commands, Options,
-- Minimap…) est le même code dans QuestCompanion et Ready2Quest ; il lit ici
-- le nom de l'addon, sa sauvegarde, ses commandes et son logo.
-- QuestCompanion fonctionne seul : Ready2Quest n'est pas nécessaire.
local ADDON, ns = ...

ns.APP = {
	id = "QuestCompanion",
	version = "2.4.0",
	-- nom dans l'en-tête des réglages
	brand = "Quest|cff5b8fd6Companion|r",
	-- sauvegarde (## SavedVariables)
	db = "QuestCompanionDB",
	-- /qc et /questcompanion
	slashKey = "QUESTCOMPANION",
	slash = { "/questcompanion", "/qc" },
	-- fichiers attendus, pour le diagnostic quand l'addon reste muet
	coreFiles = { "Bootstrap", "Strings", "Locales", "Store", "World", "Commands", "Options", "Minimap",
		"Core", "Companion", "Journal", "JournalTracker", "Bestiary", "Treats", "Shiny", "Capture", "Daily", "Notify", "LiveRares", "Tooltips", "JournalWindow" },
}

-- Ready2Quest 1.25 ou avant embarque encore le compagnon : deux compagnons à
-- l'écran, deux carnets. QuestCompanion s'efface (ses fichiers sortent dès
-- leur première ligne) et dit quoi faire.
local r2q = rawget(_G, "Ready2Quest")
if type(r2q) == "table" and type(r2q.Loaded) == "table" and r2q.Loaded.Companion then
	ns.blocked = "old-ready2quest"
	if type(print) == "function" then
		print("|cffe8a54bQuestCompanion|r — ce Ready2Quest (" .. tostring(r2q.version)
			.. ") contient déjà le compagnon : mets Ready2Quest à jour (1.26.0 ou plus), puis /reload.")
	end
end
