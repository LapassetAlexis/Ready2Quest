-- QuestCompanion 2.6.0 : les Souvenirs sont retirés. Plus d'album dans le
-- carnet, plus de page de réglages, plus de photos ni d'anniversaires ; un
-- ménage unique et silencieux vide les données de l'album de la sauvegarde.
-- Les fonds des sceaux de zone restent (sols du client depuis la 2.7.0, MenagerieCollection.lua).
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

-- 1. Plus de module, plus de fonctions -------------------------------------------------------------
do
	Say("-- 2.6.0 sans souvenirs : module et fonctions")
	local toc = SS.Read("QuestCompanion/QuestCompanion.toc") or ""
	Check("[SANS] Memories.lua sorti du .toc et du dépôt", not toc:find("Memories.lua", 1, true)
		and SS.Read("QuestCompanion/Memories.lua") == nil)
	local left = {}
	for _, name in ipairs({ "MemoryData", "MemoryRecord", "MemoryText", "MemoryAnnivLabel", "MemoryWantPhoto",
		"MemoryAsk", "MemoryAnswer", "MemoryPhotoStep", "MemoryPhotoDone", "MemoryCheckAnniversary", "MemoryRecall",
		"MemoryPoll", "OpenMemories", "EnsurePhotoPrompt", "BuildMemoriesPane", "RefreshMemoriesPane", "MemoryArt",
		"MemoryScene", "MemoryPose", "MemoryCreature", "MemoryState", "MemoryPhotosToday" }) do
		if NS[name] ~= nil then left[#left + 1] = name end
	end
	for _, name in ipairs({ "MEMORY_STRINGS", "MEMORY_PHOTO_KINDS", "MEMORY_SCENE_TEXTURE", "MEMORY_ZONE_BIOME",
		"MEMORY_INSTANCE_ART", "MEMORY_FOREVER_ART", "MEMORY_FLIGHT_ART", "memoryEventFrame", "photoPrompt" }) do
		if NS[name] ~= nil then left[#left + 1] = name end
	end
	Check("[SANS] aucune fonction ni table des souvenirs dans le namespace", #left == 0, table.concat(left, ", "))
	Check("[SANS] pas de bouton « Ouvrir l'album »", type(NS.OPTION_ACTIONS) ~= "table" or NS.OPTION_ACTIONS.companionAlbum == nil)
	Check("[SANS] pas de réglages par défaut des photos ni du rappel", NS.DEFAULTS.companionPhotos == nil
		and NS.DEFAULTS.companionRecall == nil)
	Check("[SANS] chaînes retirées (carnet, réglages)", NS.L.JRN_SEC_memories == "JRN_SEC_memories"
		and NS.L.OPT_PAGE_MEMORIES == "OPT_PAGE_MEMORIES" and NS.L.MEM_TXT_capture == "MEM_TXT_capture")
	local pools = {}
	for key in pairs(NS.COMPANION_LINE_STRINGS.fr) do
		if key:find("^PHOTO") or key:find("^RECALL") or key:find("^ANNIV") then pools[#pools + 1] = key end
	end
	local persona = SS.Read("QuestCompanion/PersonalityLines.lua") or ""
	Check("[SANS] plus de répliques de photo, de rappel ni d'anniversaire", #pools == 0
		and not persona:find("\n\tPHOTO = {", 1, true), table.concat(pools, ", "))
	-- aucun appel restant vers l'album dans les fichiers chargés
	local calls = {}
	for _, file in ipairs(rawget(_G, "TOC_FILES") or {}) do
		if file:find("^QuestCompanion/") then
			local text = SS.Read(file) or ""
			if text:find(":Memory%u") or text:find("%.Memory%u") or text:find("MEMORY_STRINGS", 1, true)
				or text:find("OpenMemories", 1, true) then calls[#calls + 1] = file end
		end
	end
	Check("[SANS] aucun fichier n'appelle plus l'album", #calls == 0, table.concat(calls, ", "))
end

-- 2. Carnet et réglages -------------------------------------------------------------------------------
do
	Say("-- 2.6.0 sans souvenirs : carnet et réglages")
	SS.Reset()
	NS:DB().journalTab = "memories"
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	Check("[SANS] carnet : pas d'entrée Souvenirs, ni de page", f.sections.memories == nil and f.mem == nil
		and f.sections.evolution and f.sections.guide)
	NS:SelectJournalKind("memories")
	Check("[SANS] un ancien onglet « memories » rouvre la page Compagnon", f.kind == "evolution" and f.evo:IsShown())
	f:Hide()
	local ids = {}
	for _, page in ipairs(NS.OPTION_PAGES) do
		if page.id == "companionMemories" or page.title == "OPT_PAGE_MEMORIES" then ids[#ids + 1] = page.id end
	end
	Check("[SANS] réglages : plus de page Souvenirs", #ids == 0, table.concat(ids, ", "))
	Check("[SANS] effets : plus d'éclair de photo", NS.COMPANION_FX.flash == nil)
end

-- 3. Ménage de la sauvegarde ---------------------------------------------------------------------------
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
	Check("[SANS] … l'album et ses clés quittent la sauvegarde", one.memories == nil and one.memoryKeys == nil
		and one.metAt == nil and one.sillyScore == nil and one.photoDay == nil)
	Check("[SANS] … le reste du compagnon est gardé, « since » aussi", one.name == "Brindille" and one.since == 1700000000)
	Check("[SANS] … « jours ensemble » recalé sur le plus vieux souvenir",
		db.chars["Autre - Royaume"].companion.since == 1791000000, tostring(db.chars["Autre - Royaume"].companion.since))
	Check("[SANS] … ou sur la date de la rencontre", db.chars["Trois - Royaume"].companion.since == 1785000000)
	local bad = db.chars["Abime - Royaume"].companion
	Check("[SANS] … données abîmées retirées aussi", bad.memories == nil and bad.memoryKeys == nil and bad.since == nil)
	Check("[SANS] … réglages des photos et du rappel retirés", db.companionPhotos == nil and db.companionPhotosAsked == nil
		and db.companionRecall == nil and db.memoriesDropped == true)
	db.chars["Testeur - Royaume"].companion.memories = { {} }
	Check("[SANS] une seule fois : le second passage ne fait rien", NS:DropMemories() == 0
		and db.chars["Testeur - Royaume"].companion.memories ~= nil)
	-- /qc reset garde la marque : pas de second ménage
	NS.COMMANDS["reset"](NS)
	Check("[SANS] /qc reset garde la marque du ménage", NS:DB().memoriesDropped == true)
	NS:DB().chars = savedChars
end
