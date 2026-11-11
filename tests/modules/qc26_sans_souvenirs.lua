-- QuestCompanion 2.6.0 : les Souvenirs sont retirés. Une seule garde que
-- l'album est parti (module, fonctions, appels) et qu'un ancien onglet
-- sauvegardé rouvre la page Compagnon ; surtout, le ménage unique et
-- silencieux de la sauvegarde (ns:DropMemories) : clés de l'album retirées,
-- « since » recalé, données abîmées, réglages des photos, une seule fois.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local SS = {}
function SS.Read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end
function SS.Reset()
	ResetWorld()
	if NS.journalFrame then NS.journalFrame:Hide() end
	if NS.optionsFrame then NS.optionsFrame:Hide() end
end

-- 1. Plus d'album : une seule garde (module, fonctions, appels) ; un ancien onglet sauvegardé -----------
do
	Say("-- 2.6.0 sans souvenirs : plus d'album")
	local left = {}
	local toc = SS.Read("QuestCompanion/QuestCompanion.toc") or ""
	if toc:find("Memories.lua", 1, true) or SS.Read("QuestCompanion/Memories.lua") ~= nil then left[#left + 1] = "Memories.lua" end
	for _, name in ipairs({ "MemoryData", "MemoryRecord", "OpenMemories", "EnsurePhotoPrompt", "BuildMemoriesPane",
		"MEMORY_STRINGS", "memoryEventFrame", "photoPrompt" }) do
		if NS[name] ~= nil then left[#left + 1] = name end
	end
	for _, file in ipairs(rawget(_G, "TOC_FILES") or {}) do
		if file:find("^QuestCompanion/") then
			local text = SS.Read(file) or ""
			if text:find(":Memory%u") or text:find("%.Memory%u") or text:find("MEMORY_STRINGS", 1, true)
				or text:find("OpenMemories", 1, true) then left[#left + 1] = file end
		end
	end
	Check("[SANS] l'album est parti : ni module, ni fonctions, ni appels", #left == 0, table.concat(left, ", "))
	SS.Reset()
	NS:DB().journalTab = "memories"
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	NS:SelectJournalKind("memories")
	Check("[SANS] carnet : pas d'entrée Souvenirs ; un ancien onglet « memories » sauvegardé rouvre la page Compagnon",
		f.sections.memories == nil and f.mem == nil and f.kind == "evolution" and f.evo:IsShown())
	f:Hide()
end

-- 2. Ménage de la sauvegarde ---------------------------------------------------------------------------
do
	Say("-- 2.6.0 sans souvenirs : ménage unique de la sauvegarde")
	SS.Reset()
	local db = NS:DB()
	local savedChars = db.chars
	db.companionPhotos, db.companionPhotosAsked, db.companionRecall = true, "yes", false
	db.memoriesDropped = nil
	db.chars = {
		["Testeur - Royaume"] = { companion = { name = "Brindille", since = 1700000000,
			memories = { { at = 1790000000, kind = "level", args = { 10 } } }, memoryKeys = { ["level:10"] = true },
			metAt = 1780000000, sillyScore = 4, photoDay = { day = "2026-11-01", count = 2 } } },
		-- sans « since » : le plus vieux souvenir le recale
		["Autre - Royaume"] = { companion = { memories = { { at = 1795000000 }, { at = 1791000000 }, "abîmé", { at = "x" } },
			memoryKeys = {} } },
		-- seulement la date de rencontre
		["Trois - Royaume"] = { companion = { memories = {}, metAt = 1785000000 } },
		-- vieilles données abîmées : jamais d'erreur
		["Abime - Royaume"] = { companion = { memories = "pas une table", memoryKeys = 12 } },
		["Vide - Royaume"] = 5,
		["Nu - Royaume"] = { journal = {} },
	}
	local ok, cleaned = pcall(NS.DropMemories, NS)
	Check("[SANS] ménage : sans erreur, quatre personnages nettoyés", ok and cleaned == 4, tostring(cleaned))
	local one = db.chars["Testeur - Royaume"].companion
	Check("[SANS] … l'album et ses clés quittent la sauvegarde, le reste du compagnon est gardé (« since » aussi)",
		one.memories == nil and one.memoryKeys == nil and one.metAt == nil and one.sillyScore == nil and one.photoDay == nil
		and one.name == "Brindille" and one.since == 1700000000)
	Check("[SANS] … « jours ensemble » recalé sur le plus vieux souvenir, ou sur la date de la rencontre",
		db.chars["Autre - Royaume"].companion.since == 1791000000 and db.chars["Trois - Royaume"].companion.since == 1785000000,
		tostring(db.chars["Autre - Royaume"].companion.since))
	local bad = db.chars["Abime - Royaume"].companion
	Check("[SANS] … données abîmées retirées aussi ; réglages des photos et du rappel retirés", bad.memories == nil
		and bad.memoryKeys == nil and bad.since == nil and db.companionPhotos == nil and db.companionPhotosAsked == nil
		and db.companionRecall == nil and db.memoriesDropped == true)
	db.chars["Testeur - Royaume"].companion.memories = { {} }
	Check("[SANS] une seule fois : le second passage ne fait rien", NS:DropMemories() == 0
		and db.chars["Testeur - Royaume"].companion.memories ~= nil)
	-- /qc reset garde la marque : pas de second ménage
	NS.COMMANDS["reset"](NS)
	Check("[SANS] /qc reset garde la marque du ménage", NS:DB().memoriesDropped == true)
	NS:DB().chars = savedChars
end
