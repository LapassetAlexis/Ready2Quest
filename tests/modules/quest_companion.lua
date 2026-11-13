-- Ready2Quest et QuestCompanion : deux addons autonomes, rangés côte à côte
-- (Ready2Quest/, QuestCompanion/). Garde : .toc (dépendance facultative,
-- sauvegarde, versions cohérentes avec les namespaces, fichiers présents),
-- deux copies identiques du socle qui ne visent aucun des deux, namespaces,
-- sauvegardes, commandes (/qc, /r2q) et modules séparés, panneau de réglages
-- et bouton de minicarte propres, reprise des données de Ready2Quest 1.25
-- (migration), liens facultatifs (départ / retour), QuestCompanion seul et
-- face à un Ready2Quest 1.25.
local Check, Say, ResetWorld, NS, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local failed = {}
local function Want(label, ok) if not ok then failed[#failed + 1] = label end return ok end
local function Verdict(name) Check(name, #failed == 0, table.concat(failed, " | ")); failed = {} end

local QCT = {}
function QCT.Read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end
function QCT.TocFiles(text)
	local files = {}
	for line in text:gmatch("[^\n]+") do
		line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" and not line:find("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
	end
	return files
end
function QCT.Reset()
	ResetWorld()
	QNS.companionSession = nil
	if QNS.optionsFrame then QNS.optionsFrame:Hide() end
	if QNS.journalFrame then QNS.journalFrame:Hide() end
end
-- Charge des fichiers de QuestCompanion dans une table neuve (un client où
-- QuestCompanion serait seul), sans laisser leurs cadres réagir à la suite.
function QCT.LoadFresh(files, r2q)
	local saved = rawget(_G, "Ready2Quest")
	_G.Ready2Quest = r2q
	local fresh, before, errors = {}, #Mock.frames, {}
	for _, file in ipairs(files) do
		local chunk = assert(loadfile(ROOT .. "/QuestCompanion/" .. file))
		local ok, err = pcall(chunk, "QuestCompanion", fresh)
		if not ok then errors[#errors + 1] = file .. " : " .. tostring(err) end
	end
	_G.Ready2Quest = saved
	for index = before + 1, #Mock.frames do Mock.frames[index].events = {} end
	return fresh, errors
end

local QC_TOC = QCT.Read("QuestCompanion/QuestCompanion.toc")
local R2Q_TOC = QCT.Read("Ready2Quest/Ready2Quest.toc")

-- 1. Dépôt et .toc ----------------------------------------------------------------------
do
	Say("-- deux addons : .toc")
	Check("[QC] .toc : sans dépendance obligatoire, Ready2Quest facultatif, sa sauvegarde QuestCompanionDB",
		not QC_TOC:find("## Dependencies", 1, true) and not QC_TOC:find("## RequiredDeps", 1, true)
		and QC_TOC:find("\n## OptionalDeps: Ready2Quest\n", 1, true) ~= nil
		and QC_TOC:find("\n## SavedVariables: QuestCompanionDB\n", 1, true) ~= nil)
	Check("[QC] versions : QC 3.1.0, R2Q 1.35.0, comme leurs namespaces", QC_TOC:find("\n## Version: 3.1.0\n", 1, true)
		and R2Q_TOC:find("\n## Version: 1.35.0\n", 1, true) and QNS.version == "3.1.0" and NS.version == "1.35.0")
	for _, addon in ipairs({ { "Ready2Quest", R2Q_TOC }, { "QuestCompanion", QC_TOC } }) do
		local files = QCT.TocFiles(addon[2])
		Want(addon[1] .. " : Config.lua puis le socle en tête", files[1] == "Config.lua"
			and files[2] == "Libs/Socle/Base.lua" and files[3] == "Libs/Socle/Strings.lua")
		for _, file in ipairs(files) do
			if not QCT.Read(addon[1] .. "/" .. file) then Want(addon[1] .. " : absent " .. file, false) end
		end
	end
	Verdict("[QC] chaque .toc : Config.lua puis le socle en tête, chaque fichier existe dans son dossier")
	local r2qFiles, leak = {}, {}
	for _, file in ipairs(QCT.TocFiles(R2Q_TOC)) do r2qFiles[file] = true end
	for _, file in ipairs(QCT.TocFiles(QC_TOC)) do
		if r2qFiles[file] and not file:find("^Libs/Socle/") and file ~= "Config.lua" and file ~= "Locales.lua"
			and file ~= "Core.lua" then leak[#leak + 1] = file end
	end
	Check("[QC] aucun module partagé entre les deux .toc (hors socle), plus de fichiers d'addon à la racine du dépôt",
		#leak == 0 and QCT.Read("Core.lua") == nil and QCT.Read("Ready2Quest.toc") == nil and QCT.Read("Companion.lua") == nil,
		table.concat(leak, ", "))
end

-- 2. Socle commun : deux copies identiques ------------------------------------------------
do
	Say("-- deux addons : socle")
	local files = { "Base.lua", "Strings.lua", "Compat.lua", "Hubs.lua", "DungeonData.lua", "Theme.lua", "Store.lua",
		"World.lua", "Commands.lua", "Options.lua", "Minimap.lua",
		"Media/Inter-Regular.ttf", "Media/Inter-SemiBold.ttf", "Media/Inter-Bold.ttf", "Media/Inter-OFL.txt" }
	local diff = {}
	for _, file in ipairs(files) do
		local a, b = QCT.Read("Ready2Quest/Libs/Socle/" .. file), QCT.Read("QuestCompanion/Libs/Socle/" .. file)
		if not a or a ~= b then diff[#diff + 1] = file end
	end
	Check("[QC] socle identique dans les deux addons (tools/sync_socle.py)", #diff == 0, table.concat(diff, ", "))
	local named = {}
	for _, file in ipairs(files) do
		local text = QCT.Read("Ready2Quest/Libs/Socle/" .. file) or ""
		if file:find("%.lua$") and (text:find("Ready2QuestDB", 1, true) or text:find("QuestCompanionDB", 1, true)
			or text:find("RunChecklist", 1, true) or text:find("ToggleJournal", 1, true)) then
			named[#named + 1] = file
		end
	end
	Check("[QC] le socle ne vise aucun des deux addons (tout passe par ns.APP et des crochets)", #named == 0,
		table.concat(named, ", "))
end

-- 3. Namespaces, sauvegardes, commandes ---------------------------------------------------
do
	Say("-- deux addons : séparés")
	QCT.Reset()
	Check("[QC] deux namespaces, deux sauvegardes", QNS ~= NS and QNS.L ~= NS.L and QNS.Theme ~= NS.Theme
		and QNS.APP.id == "QuestCompanion" and NS.APP.id == "Ready2Quest" and QNS:DB() == _G.QuestCompanionDB
		and NS:DB() == _G.Ready2QuestDB and _G.QuestCompanionDB ~= _G.Ready2QuestDB)
	Check("[QC] commandes enregistrées : /qc et /questcompanion, /r2q reste à Ready2Quest", type(SlashCmdList.QUESTCOMPANION) == "function"
		and SLASH_QUESTCOMPANION2 == "/qc" and SLASH_QUESTCOMPANION1 == "/questcompanion"
		and type(SlashCmdList.SACETDEPART) == "function" and SLASH_SACETDEPART3 == "/r2q")
	Want("compagnon sous /qc seulement", QNS.COMMANDS.carnet and QNS.COMMANDS.compagnon and QNS.COMMANDS.coffre
		and not NS.COMMANDS.carnet and not NS.COMMANDS.compagnon and not NS.COMMANDS.coffre)
	Want("check sous /r2q seulement", NS.COMMANDS.safe and NS.COMMANDS.checks and not QNS.COMMANDS.safe and not QNS.COMMANDS.checks)
	Want("modules", QNS:FindModule("compagnon") and not NS:FindModule("compagnon") and NS:FindModule("depart")
		and not QNS:FindModule("depart"))
	Want("textes de QC : /qc", QNS.L.HELP_COMPANION:find("/qc compagnon", 1, true) and QNS.L.HELP_JOURNAL:find("/qc carnet", 1, true)
		and QNS.L.HELP_CHEST:find("/qc coffre", 1, true))
	Verdict("[QC] chaque addon ses commandes, ses modules, ses textes d'aide")

	Mock:Reset()
	SlashCmdList.QUESTCOMPANION("")
	Want("sans argument : le carnet", QNS.journalFrame and QNS.journalFrame:IsShown())
	QNS.journalFrame:Hide()
	SlashCmdList.QUESTCOMPANION("help")
	Want("help : l'aide de QC", Mock:Output():find("/qc carnet", 1, true) and not Mock:Output():find("/r2q", 1, true))
	Mock:Reset()
	SlashCmdList.QUESTCOMPANION("module compagnon off")
	Want("module compagnon off : réglage de QC", QNS:DB().companionEnabled == false and NS:DB().companionEnabled == nil)
	SlashCmdList.QUESTCOMPANION("module compagnon on")
	Verdict("[QC] /qc : le carnet, son aide, ses modules")
end

-- 4. Panneau de réglages et bouton de minicarte ------------------------------------------
do
	Say("-- deux addons : réglages et minicarte")
	QCT.Reset()
	local frame = QNS:EnsureOptions()
	Want("son propre panneau", frame and frame ~= NS:EnsureOptions() and frame.name == "QuestCompanionOptionsFrame"
		and frame.brandName.text == QNS.APP.brand)
	local pages = {}
	for _, def in ipairs(QNS.OPTION_PAGES) do pages[def.id] = true end
	local r2qPages = {}
	for _, def in ipairs(NS.OPTION_PAGES) do r2qPages[def.id] = true end
	Want("pages de QC", pages.general and pages.companion and pages.journal and not pages.departure and not pages.merchant)
	Want("plus de compagnon chez R2Q", not r2qPages.companion and not r2qPages.journal and r2qPages.departure and r2qPages.merchant)
	Want("bouton « Ouvrir le carnet »", frame.runButton.text.text == "Ouvrir le carnet")
	frame.runButton:Click()
	Want("… qui l'ouvre", QNS.journalFrame and QNS.journalFrame:IsShown())
	QNS.journalFrame:Hide()
	Want("médias du socle dans chaque addon",
		QNS.Theme.FONT_REGULAR == "Interface\\AddOns\\QuestCompanion\\Libs\\Socle\\Media\\Inter-Regular.ttf"
		and NS.Theme.FONT_REGULAR == "Interface\\AddOns\\Ready2Quest\\Libs\\Socle\\Media\\Inter-Regular.ttf")
	Verdict("[QC] son panneau (ses pages, son bouton principal), ses médias")

	local button = QNS:EnsureMinimapButton()
	Want("son bouton, au dragonnet", button and button.name == "QuestCompanionMinimapButton"
		and button ~= NS:EnsureMinimapButton() and button.icon.texture == "Interface\\AddOns\\QuestCompanion\\Textures\\logo_petit")
	button:GetScript("OnClick")(button, "LeftButton")
	Want("clic gauche : le carnet", QNS.journalFrame:IsShown())
	QNS.journalFrame:Hide()
	button:GetScript("OnClick")(button, "RightButton")
	Want("clic droit : les réglages de QC", QNS.optionsFrame:IsShown() and not (NS.optionsFrame and NS.optionsFrame:IsShown()))
	QNS.optionsFrame:Hide()
	Verdict("[QC] son bouton de minicarte : clic gauche le carnet, clic droit ses réglages")
end

-- 5. Reprise depuis Ready2Quest 1.25 -----------------------------------------------------
do
	Say("-- deux addons : reprise de Ready2Quest 1.25")
	QCT.Reset()
	local key = QNS:CharKey()
	_G.Ready2QuestDB = { enabled = true, showWindow = false, companionBubbles = false, journalTracker = false,
		journalTrackerPoint = { point = "TOP", x = 1, y = 2 },
		chars = { [key] = { trainerLevel = 10, companion = { name = "Pipo", stage = 2 },
			journal = { stamps = { ["zone:1411"] = { kind = "zone" } } } },
			["Autre-Royaume"] = { companion = { name = "Autre" } },
			["Sans-Compagnon"] = { trainerLevel = 4 } } }
	NS._dbReady = false
	local moved = QNS:MigrateFromReady2Quest()
	local db, old = QNS:DB(), _G.Ready2QuestDB
	Check("[QC] reprise : tous les personnages qui avaient un compagnon, compagnon, carnet et leurs réglages", moved == 2
		and db.chars[key].companion.name == "Pipo" and db.chars[key].journal.stamps["zone:1411"]
		and db.chars["Autre-Royaume"].companion.name == "Autre" and db.companionBubbles == false and db.journalTracker == false
		and db.journalTrackerPoint.point == "TOP", moved)
	Check("[QC] reprise : retirés de Ready2QuestDB, le reste y reste", old.chars[key].companion == nil and old.chars[key].journal == nil
		and old.chars[key].trainerLevel == 10 and old.companionBubbles == nil and old.journalTrackerPoint == nil
		and old.showWindow == false and old.chars["Sans-Compagnon"].trainerLevel == 4)
	Check("[QC] reprise : lue par le compagnon et le carnet, une seule fois", QNS:CompanionData().name == "Pipo"
		and QNS:JournalData().stamps["zone:1411"] and db.migratedFromR2Q == true and QNS:MigrateFromReady2Quest() == 0)

	QCT.Reset()
	QNS:CompanionData().name = "Neuf"
	_G.Ready2QuestDB = { chars = { [key] = { companion = { name = "Ancien" } } } }
	QNS:MigrateFromReady2Quest()
	Check("[QC] reprise : une progression déjà commencée dans QC l'emporte", QNS:CompanionData().name == "Neuf"
		and _G.Ready2QuestDB.chars[key].companion == nil)

	QCT.Reset()
	_G.Ready2QuestDB = nil
	Check("[QC] sans Ready2Quest : rien à reprendre, on réessaiera", QNS:MigrateFromReady2Quest() == 0
		and QNS:DB().migratedFromR2Q == nil)

	QCT.Reset()
	_G.Ready2QuestDB = { chars = { [key] = { companion = { name = "Au chargement" } } } }
	QNS:OnAddonLoaded()
	Check("[QC] reprise lancée à ADDON_LOADED", QNS:CompanionData().name == "Au chargement")

	-- lue avant ADDON_LOADED, la sauvegarde est un brouillon : le client la
	-- remplace par la vraie, que le socle doit reprendre (réglages par défaut)
	QCT.Reset()
	local draft = QNS:DB()
	local saved = { chars = { [key] = { companion = { name = "Sauvé" } } }, migratedFromR2Q = true }
	_G.QuestCompanionDB = saved
	QNS.loaderFrame:GetScript("OnEvent")(QNS.loaderFrame, "ADDON_LOADED", "QuestCompanion")
	local real = QNS:DB() == saved and saved ~= draft and saved.showMinimap == true and QNS:CompanionData().name == "Sauvé"
	QNS.loaderFrame:GetScript("OnEvent")(QNS.loaderFrame, "ADDON_LOADED", "Ready2Quest")
	Check("[QC] ADDON_LOADED : la vraie sauvegarde reprise (réglages par défaut compris) ; celui d'un autre addon ignoré",
		real and QNS._dbReady == true)

	QCT.Reset()
	QNS:CompanionData().name = "Gardé"
	QNS:DB().companionBubbles = false
	Mock:Reset()
	SlashCmdList.QUESTCOMPANION("reset")
	local kept = QNS:DB().companionBubbles ~= false and QNS:CompanionData().name == "Gardé"
	SlashCmdList.SACETDEPART("reset")
	Check("[QC] /qc reset : réglages remis, compagnon gardé ; /r2q reset ne touche pas QC", kept
		and QNS:CompanionData().name == "Gardé")
end

-- 6. Liens facultatifs avec Ready2Quest ---------------------------------------------------
do
	Say("-- deux addons : liens facultatifs")
	QCT.Reset()
	local seen = {}
	QNS:RegisterCallback("DEPARTURE", function() seen.departure = true end)
	QNS:RegisterCallback("RETURN", function() seen["return"] = true end)
	NS:FireCallback("DEPARTURE", "Village")
	NS:FireCallback("RETURN", "Village")
	Check("[QC] départ et retour de Ready2Quest relayés au compagnon ; pas de lien sans Ready2Quest", seen.departure
		and seen["return"] and QNS.r2qBridge == NS and QNS:BridgeReady2Quest(false) == false and QNS:BridgeReady2Quest(QNS) == false)
end

-- 7. QuestCompanion seul, et face à un Ready2Quest 1.25 ----------------------------------
do
	Say("-- deux addons : QuestCompanion seul")
	local files = QCT.TocFiles(QC_TOC)
	Mock:Reset()
	local alone, errors = QCT.LoadFresh(files, nil)
	Check("[QC] seul : tous ses fichiers se chargent, compagnon, carnet et réglages présents, pas de lien vers Ready2Quest",
		#errors == 0 and alone.Loaded and alone.Loaded.Core and alone.Loaded.Companion and alone.Loaded.JournalWindow
		and type(alone.ToggleJournal) == "function" and type(alone.EnsureOptions) == "function" and alone.r2qBridge == nil,
		table.concat(errors, " | "))

	Mock:Reset()
	local old = { version = "1.25.0", Loaded = { Companion = true } }
	local blocked, blockedErrors = QCT.LoadFresh(files, old)
	Check("[QC] avec Ready2Quest 1.25 : rien ne plante, QC s'efface (pas de second compagnon), message pour le mettre à jour",
		#blockedErrors == 0 and blocked.blocked == "old-ready2quest" and blocked.CompanionData == nil
		and blocked.ToggleJournal == nil and not blocked.Loaded.Core and Mock:Output():find("mets Ready2Quest à jour", 1, true) ~= nil,
		table.concat(blockedErrors, " | ") .. " " .. Mock:Output())
end

QCT.Reset()
