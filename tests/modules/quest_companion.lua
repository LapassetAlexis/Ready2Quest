-- QuestCompanion : addon séparé (v1.0.0), qui dépend de Ready2Quest (v1.26.0).
-- .toc des deux addons, namespace partagé via _G.Ready2Quest, progression
-- rangée dans QuestCompanionDB et reprise de Ready2QuestDB, garde sans R2Q.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local QCT = {}
function QCT.ReadToc(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "r"))
	local text = handle:read("*a")
	handle:close()
	local files = {}
	for line in text:gmatch("[^\n]+") do
		line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" and not line:find("^#") then files[#files + 1] = line end
	end
	return text, files
end
function QCT.Reset()
	ResetWorld()
	NS.companionSession = nil
	NS.QC.loaded = true
end

-- 1. Les deux .toc ----------------------------------------------------------------------
do
	Say("-- QuestCompanion : .toc")
	local qcText, qcFiles = QCT.ReadToc("QuestCompanion/QuestCompanion.toc")
	local r2qText, r2qFiles = QCT.ReadToc("Ready2Quest/Ready2Quest.toc")
	Check("[QC] .toc : dépend de Ready2Quest", qcText:find("\n## Dependencies: Ready2Quest\n", 1, true) ~= nil)
	Check("[QC] .toc : sa propre sauvegarde QuestCompanionDB", qcText:find("\n## SavedVariables: QuestCompanionDB\n", 1, true) ~= nil)
	Check("[QC] .toc : version 1.0.0, comme NS.QC.version", qcText:find("\n## Version: 1.0.0\n", 1, true) ~= nil
		and NS.QC.version == "1.0.0")
	Check("[QC] .toc : Bootstrap.lua en premier", qcFiles[1] == "Bootstrap.lua", qcFiles[1])
	Check("[QC] Ready2Quest.toc : version 1.26.0, comme NS.version", r2qText:find("\n## Version: 1.26.0\n", 1, true) ~= nil
		and NS.version == "1.26.0")

	local listed, missing = {}, {}
	for _, file in ipairs(qcFiles) do
		listed[file] = true
		local handle = io.open(ROOT .. "/QuestCompanion/" .. file, "r")
		if handle then handle:close() else missing[#missing + 1] = file end
	end
	Check("[QC] .toc : chaque fichier listé existe dans QuestCompanion/", #missing == 0, table.concat(missing, ", "))

	local leftovers = {}
	for _, file in ipairs(r2qFiles) do
		local handle = file ~= "Bootstrap.lua" and io.open(ROOT .. "/QuestCompanion/" .. file, "r")
		if handle then handle:close(); leftovers[#leftovers + 1] = file end
	end
	Check("[QC] Ready2Quest.toc ne charge aucun fichier de QuestCompanion", #leftovers == 0, table.concat(leftovers, ", "))
	for _, file in ipairs({ "Companion.lua", "Journal.lua", "JournalTracker.lua", "JournalWindow.lua", "Bestiary.lua",
		"Gathering.lua", "CompanionChest.lua", "ZoneQuests.lua", "ZoneCreatures_Era.lua" }) do
		local handle = io.open(ROOT .. "/Ready2Quest/" .. file, "r")
		if handle then handle:close() end
		Check("[QC] " .. file .. " n'est pas dans Ready2Quest/", handle == nil and listed[file] == true)
	end

	local bad = {}
	for _, file in ipairs(qcFiles) do
		local handle = assert(io.open(ROOT .. "/QuestCompanion/" .. file, "r"))
		local source = handle:read("*a")
		handle:close()
		if file ~= "Bootstrap.lua" and (source:find("local ADDON, ns = ...", 1, true)
			or not source:find('local ns = rawget(_G, "Ready2Quest")\nif type(ns) ~= "table" or not ns.QC then return end', 1, true)) then
			bad[#bad + 1] = file
		end
	end
	Check("[QC] chaque fichier reprend le namespace de Ready2Quest, avec la garde", #bad == 0, table.concat(bad, ", "))
	Check("[QC] API publique : _G.QuestCompanion = NS.QC, _G.Ready2Quest = NS", rawget(_G, "QuestCompanion") == NS.QC
		and rawget(_G, "Ready2Quest") == NS)
	Check("[QC] modules marqués chargés", NS.Loaded["QC.Bootstrap"] and NS.Loaded.Companion and NS.Loaded.JournalWindow)
end

-- 2. Garde : QuestCompanion sans Ready2Quest -------------------------------------------
do
	Say("-- QuestCompanion : sans Ready2Quest")
	local saved = rawget(_G, "Ready2Quest")
	_G.Ready2Quest = nil
	Mock:Reset()
	local results = {}
	for _, file in ipairs({ "Bootstrap.lua", "Companion.lua", "JournalTracker.lua", "ZoneQuests_Forever.lua" }) do
		local chunk = assert(loadfile(ROOT .. "/QuestCompanion/" .. file))
		results[file] = { pcall(chunk, "QuestCompanion", {}) }
	end
	_G.Ready2Quest = saved
	local allOk = true
	for _, result in pairs(results) do allOk = allOk and result[1] end
	Check("[QC] sans Ready2Quest : aucun fichier ne plante", allOk)
	Check("[QC] sans Ready2Quest : un message explique quoi faire", Mock:Output():find("Ready2Quest est requis", 1, true) ~= nil,
		Mock:Output())
	Check("[QC] le namespace de Ready2Quest n'a pas été touché", rawget(_G, "Ready2Quest") == NS and NS.QC.version == "1.0.0")
end

do
	Say("-- QuestCompanion : avec un Ready2Quest 1.25 qui embarque le compagnon")
	local old = { version = "1.25.0", Loaded = { Companion = true }, Mark = function() end }
	local saved = rawget(_G, "Ready2Quest")
	_G.Ready2Quest = old
	Mock:Reset()
	local results = {}
	for _, file in ipairs({ "Bootstrap.lua", "Companion.lua", "Journal.lua" }) do
		local chunk = assert(loadfile(ROOT .. "/QuestCompanion/" .. file))
		results[#results + 1] = pcall(chunk, "QuestCompanion", {})
	end
	_G.Ready2Quest = saved
	Check("[QC] ancien Ready2Quest : rien ne plante", results[1] and results[2] and results[3])
	Check("[QC] ancien Ready2Quest : QuestCompanion s'efface (pas de ns.QC, rien de redéfini)", old.QC == nil
		and old.CompanionData == nil and old.JournalData == nil)
	Check("[QC] ancien Ready2Quest : message pour mettre Ready2Quest à jour",
		Mock:Output():find("mets Ready2Quest à jour", 1, true) ~= nil, Mock:Output())
end

-- 3. Sauvegarde propre et reprise de Ready2QuestDB --------------------------------------
do
	Say("-- QuestCompanion : sauvegarde")
	QCT.Reset()
	local key = NS:CharKey()
	NS:DB().chars[key] = { trainerLevel = 10, companion = { name = "Pipo", stage = 2 },
		journal = { stamps = { ["zone:1411"] = { kind = "zone" } } } }
	local otherKey = "Autre-Royaume"
	NS:DB().chars[otherKey] = { companion = { name = "Autre" } }

	local char = NS:QCCharData()
	local old = NS:DB().chars[key]
	Check("[QC] migration : compagnon repris de Ready2QuestDB", char.companion and char.companion.name == "Pipo"
		and char.companion.stage == 2)
	Check("[QC] migration : carnet repris", char.journal and char.journal.stamps["zone:1411"] ~= nil)
	Check("[QC] migration : retiré de Ready2QuestDB, le reste du personnage y reste", old.companion == nil
		and old.journal == nil and old.trainerLevel == 10)
	Check("[QC] migration : rangé dans QuestCompanionDB, par personnage", type(_G.QuestCompanionDB) == "table"
		and _G.QuestCompanionDB.chars[key] == char and char.migrated == true)
	Check("[QC] migration : les autres personnages attendent leur connexion",
		NS:DB().chars[otherKey].companion ~= nil and _G.QuestCompanionDB.chars[otherKey] == nil)
	Check("[QC] CompanionData lit QuestCompanionDB", NS:CompanionData() == char.companion
		and NS:CompanionData().name == "Pipo")
	Check("[QC] JournalData lit QuestCompanionDB", NS:JournalData() == char.journal)

	old.companion = { name = "Fantôme" }
	Check("[QC] migration une seule fois", NS:QCCharData().companion.name == "Pipo" and old.companion.name == "Fantôme")
end

do
	Say("-- QuestCompanion : nouveau personnage, puis reset de Ready2Quest")
	QCT.Reset()
	local data = NS:CompanionData()
	data.name = "Neuf"
	Check("[QC] nouveau personnage : progression créée dans QuestCompanionDB",
		_G.QuestCompanionDB.chars[NS:CharKey()].companion == data
		and (NS:DB().chars[NS:CharKey()] or {}).companion == nil)
	NS:HandleCommand("reset")
	Check("[QC] /r2q reset ne touche pas la progression de QuestCompanion", NS:CompanionData().name == "Neuf")
	Check("[QC] et ne la reprend pas de Ready2QuestDB vidé", (NS:DB().chars[NS:CharKey()] or {}).companion == nil)
end

do
	Say("-- QuestCompanion : avant ADDON_LOADED")
	QCT.Reset()
	local key = NS:CharKey()
	NS:DB().chars[key] = { companion = { name = "Attente" } }
	NS.QC.loaded = false
	local early = NS:QCCharData()
	early.companion = { name = "Brouillon" }
	Check("[QC] avant ADDON_LOADED : rien n'est écrit dans QuestCompanionDB", _G.QuestCompanionDB == nil)
	Check("[QC] avant ADDON_LOADED : rien n'est retiré de Ready2QuestDB", NS:DB().chars[key].companion.name == "Attente")

	-- le client pose la sauvegarde puis annonce l'addon
	_G.QuestCompanionDB = { chars = {} }
	NS:QCOnAddonLoaded()
	local char = NS:QCCharData()
	Check("[QC] après ADDON_LOADED : la sauvegarde posée par le client est utilisée", _G.QuestCompanionDB.chars[key] == char)
	Check("[QC] après ADDON_LOADED : migration faite, brouillon oublié", char.companion.name == "Attente"
		and NS:DB().chars[key].companion == nil)
	Check("[QC] ADDON_LOADED d'un autre addon : ignoré", (function()
		NS.QC.loaded = false
		Mock:Fire("ADDON_LOADED", "Ready2Quest")
		local still = NS.QC.loaded == false
		NS.QC.loaded = true
		return still
	end)())
end

QCT.Reset()
