-- Ready2Quest (1.26.0) et QuestCompanion (1.0.0) : deux addons autonomes,
-- rangés côte à côte (Ready2Quest/, QuestCompanion/), chacun avec sa copie du
-- socle commun (Libs/Socle), son namespace, sa sauvegarde, sa commande, son
-- panneau de réglages et son bouton de minicarte. Liens facultatifs : reprise
-- des données de Ready2Quest 1.25, départs et retours de zone sûre.
local Check, Say, ResetWorld, NS, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

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
	Check("[QC] .toc : sans dépendance obligatoire, Ready2Quest facultatif",
		not QC_TOC:find("## Dependencies", 1, true) and not QC_TOC:find("## RequiredDeps", 1, true)
		and QC_TOC:find("\n## OptionalDeps: Ready2Quest\n", 1, true) ~= nil)
	Check("[QC] .toc : sa sauvegarde QuestCompanionDB", QC_TOC:find("\n## SavedVariables: QuestCompanionDB\n", 1, true) ~= nil)
	Check("[QC] versions : QC 1.5.2, R2Q 1.29.0, comme leurs namespaces", QC_TOC:find("\n## Version: 1.5.2\n", 1, true)
		and R2Q_TOC:find("\n## Version: 1.29.0\n", 1, true) and QNS.version == "1.5.2" and NS.version == "1.29.0")
	for _, addon in ipairs({ { "Ready2Quest", R2Q_TOC }, { "QuestCompanion", QC_TOC } }) do
		local files = QCT.TocFiles(addon[2])
		Check("[QC] " .. addon[1] .. " : Config.lua puis le socle en tête", files[1] == "Config.lua"
			and files[2] == "Libs/Socle/Base.lua" and files[3] == "Libs/Socle/Strings.lua", files[1])
		local missing = {}
		for _, file in ipairs(files) do
			if not QCT.Read(addon[1] .. "/" .. file) then missing[#missing + 1] = file end
		end
		Check("[QC] " .. addon[1] .. " : chaque fichier du .toc existe dans son dossier", #missing == 0, table.concat(missing, ", "))
	end
	local r2qFiles, leak = {}, {}
	for _, file in ipairs(QCT.TocFiles(R2Q_TOC)) do r2qFiles[file] = true end
	for _, file in ipairs(QCT.TocFiles(QC_TOC)) do
		if r2qFiles[file] and not file:find("^Libs/Socle/") and file ~= "Config.lua" and file ~= "Locales.lua"
			and file ~= "Core.lua" then leak[#leak + 1] = file end
	end
	Check("[QC] aucun module partagé entre les deux .toc (hors socle)", #leak == 0, table.concat(leak, ", "))
	Check("[QC] plus de fichiers d'addon à la racine du dépôt", QCT.Read("Core.lua") == nil and QCT.Read("Ready2Quest.toc") == nil
		and QCT.Read("Companion.lua") == nil)
end

-- 2. Socle commun : deux copies identiques ------------------------------------------------
do
	Say("-- deux addons : socle")
	local files = { "Base.lua", "Strings.lua", "Compat.lua", "Hubs.lua", "DungeonData.lua", "Theme.lua", "Store.lua",
		"World.lua", "Commands.lua", "Options.lua", "Minimap.lua", "Media/losange.tga", "Media/losange_trait.tga",
		"Media/Inter-Regular.ttf", "Media/Inter-SemiBold.ttf", "Media/Inter-Bold.ttf", "Media/interrupteur.tga", "Media/chevron.tga" }
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
	Check("[QC] deux namespaces", QNS ~= NS and QNS.L ~= NS.L and QNS.Theme ~= NS.Theme and QNS.APP.id == "QuestCompanion"
		and NS.APP.id == "Ready2Quest")
	Check("[QC] deux sauvegardes", QNS:DB() == _G.QuestCompanionDB and NS:DB() == _G.Ready2QuestDB
		and _G.QuestCompanionDB ~= _G.Ready2QuestDB)
	Check("[QC] /qc et /questcompanion", type(SlashCmdList.QUESTCOMPANION) == "function" and SLASH_QUESTCOMPANION2 == "/qc"
		and SLASH_QUESTCOMPANION1 == "/questcompanion")
	Check("[QC] /r2q reste à Ready2Quest", type(SlashCmdList.SACETDEPART) == "function" and SLASH_SACETDEPART3 == "/r2q")
	Check("[QC] commandes du compagnon sous /qc seulement", QNS.COMMANDS.carnet and QNS.COMMANDS.compagnon and QNS.COMMANDS.coffre
		and not NS.COMMANDS.carnet and not NS.COMMANDS.compagnon and not NS.COMMANDS.coffre)
	Check("[QC] commandes du check sous /r2q seulement", NS.COMMANDS.safe and NS.COMMANDS.checks
		and not QNS.COMMANDS.safe and not QNS.COMMANDS.checks)
	Check("[QC] chaque addon a ses modules", QNS:FindModule("compagnon") and not NS:FindModule("compagnon")
		and NS:FindModule("depart") and not QNS:FindModule("depart"))
	Check("[QC] les textes de QC parlent de /qc", QNS.L.HELP_COMPANION:find("/qc compagnon", 1, true)
		and QNS.L.HELP_JOURNAL:find("/qc carnet", 1, true) and QNS.L.HELP_CHEST:find("/qc coffre", 1, true))

	Mock:Reset()
	SlashCmdList.QUESTCOMPANION("")
	Check("[QC] /qc sans argument : le carnet", QNS.journalFrame and QNS.journalFrame:IsShown())
	QNS.journalFrame:Hide()
	SlashCmdList.QUESTCOMPANION("help")
	Check("[QC] /qc help : l'aide de QC", Mock:Output():find("/qc carnet", 1, true) and not Mock:Output():find("/r2q", 1, true),
		Mock:Output())
	Mock:Reset()
	SlashCmdList.QUESTCOMPANION("module compagnon off")
	Check("[QC] /qc module compagnon off : réglage de QC", QNS:DB().companionEnabled == false and NS:DB().companionEnabled == nil)
	SlashCmdList.QUESTCOMPANION("module compagnon on")
end

-- 4. Panneau de réglages et bouton de minicarte ------------------------------------------
do
	Say("-- deux addons : réglages et minicarte")
	QCT.Reset()
	local frame = QNS:EnsureOptions()
	Check("[QC] son propre panneau", frame and frame ~= NS:EnsureOptions() and frame.name == "QuestCompanionOptionsFrame"
		and frame.brandName.text == QNS.APP.brand)
	local pages = {}
	for _, def in ipairs(QNS.OPTION_PAGES) do pages[def.id] = true end
	local r2qPages = {}
	for _, def in ipairs(NS.OPTION_PAGES) do r2qPages[def.id] = true end
	Check("[QC] pages de QC : Général et Compagnon de route", pages.general and pages.companion and pages.journal
		and not pages.departure and not pages.merchant)
	Check("[QC] plus de compagnon dans les réglages de Ready2Quest", not r2qPages.companion and not r2qPages.journal
		and r2qPages.departure and r2qPages.merchant)
	Check("[QC] bouton principal : ouvrir le carnet", frame.runButton.text.text == "Ouvrir le carnet")
	frame.runButton:Click()
	Check("[QC] … qui ouvre le carnet", QNS.journalFrame and QNS.journalFrame:IsShown())
	QNS.journalFrame:Hide()

	local button = QNS:EnsureMinimapButton()
	Check("[QC] son propre bouton de minicarte, au dragonnet", button and button.name == "QuestCompanionMinimapButton"
		and button ~= NS:EnsureMinimapButton() and button.icon.texture == "Interface\\AddOns\\QuestCompanion\\Textures\\logo_petit")
	button:GetScript("OnClick")(button, "LeftButton")
	Check("[QC] clic gauche : le carnet", QNS.journalFrame:IsShown())
	QNS.journalFrame:Hide()
	button:GetScript("OnClick")(button, "RightButton")
	Check("[QC] clic droit : les réglages de QC", QNS.optionsFrame:IsShown() and not (NS.optionsFrame and NS.optionsFrame:IsShown()))
	QNS.optionsFrame:Hide()
	Check("[QC] le socle trouve ses médias dans chaque addon",
		QNS.Theme.DIAMOND == "Interface\\AddOns\\QuestCompanion\\Libs\\Socle\\Media\\losange"
		and NS.Theme.DIAMOND == "Interface\\AddOns\\Ready2Quest\\Libs\\Socle\\Media\\losange")
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
	Check("[QC] reprise : tous les personnages qui avaient un compagnon", moved == 2, moved)
	Check("[QC] reprise : compagnon et carnet", db.chars[key].companion.name == "Pipo" and db.chars[key].journal.stamps["zone:1411"]
		and db.chars["Autre-Royaume"].companion.name == "Autre")
	Check("[QC] reprise : réglages du compagnon et du carnet", db.companionBubbles == false and db.journalTracker == false
		and db.journalTrackerPoint.point == "TOP")
	Check("[QC] reprise : retirés de Ready2QuestDB, le reste y reste", old.chars[key].companion == nil and old.chars[key].journal == nil
		and old.chars[key].trainerLevel == 10 and old.companionBubbles == nil and old.journalTrackerPoint == nil
		and old.showWindow == false and old.chars["Sans-Compagnon"].trainerLevel == 4)
	Check("[QC] reprise : lue par le compagnon et le carnet", QNS:CompanionData().name == "Pipo" and QNS:JournalData().stamps["zone:1411"])
	Check("[QC] reprise : une seule fois", db.migratedFromR2Q == true and QNS:MigrateFromReady2Quest() == 0)

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
	Check("[QC] ADDON_LOADED : la vraie sauvegarde est reprise, réglages par défaut compris", QNS:DB() == saved
		and saved ~= draft and saved.showMinimap == true and QNS:CompanionData().name == "Sauvé")
	QNS.loaderFrame:GetScript("OnEvent")(QNS.loaderFrame, "ADDON_LOADED", "Ready2Quest")
	Check("[QC] ADDON_LOADED d'un autre addon : ignoré", QNS._dbReady == true)

	QCT.Reset()
	QNS:CompanionData().name = "Gardé"
	QNS:DB().companionBubbles = false
	Mock:Reset()
	SlashCmdList.QUESTCOMPANION("reset")
	Check("[QC] /qc reset : réglages remis, compagnon gardé", QNS:DB().companionBubbles ~= false and QNS:CompanionData().name == "Gardé")
	SlashCmdList.SACETDEPART("reset")
	Check("[QC] /r2q reset ne touche pas QC", QNS:CompanionData().name == "Gardé")
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
	Check("[QC] départ et retour de Ready2Quest relayés au compagnon", seen.departure and seen["return"] and QNS.r2qBridge == NS)
	Check("[QC] pas de lien sans Ready2Quest", QNS:BridgeReady2Quest(false) == false and QNS:BridgeReady2Quest(QNS) == false)
end

-- 7. QuestCompanion seul, et face à un Ready2Quest 1.25 ----------------------------------
do
	Say("-- deux addons : QuestCompanion seul")
	local files = QCT.TocFiles(QC_TOC)
	Mock:Reset()
	local alone, errors = QCT.LoadFresh(files, nil)
	Check("[QC] seul : tous ses fichiers se chargent", #errors == 0, table.concat(errors, " | "))
	Check("[QC] seul : compagnon, carnet et réglages présents", alone.Loaded and alone.Loaded.Core and alone.Loaded.Companion
		and alone.Loaded.JournalWindow and type(alone.ToggleJournal) == "function" and type(alone.EnsureOptions) == "function")
	Check("[QC] seul : pas de lien vers Ready2Quest", alone.r2qBridge == nil)

	Mock:Reset()
	local old = { version = "1.25.0", Loaded = { Companion = true } }
	local blocked, blockedErrors = QCT.LoadFresh(files, old)
	Check("[QC] avec Ready2Quest 1.25 : rien ne plante", #blockedErrors == 0, table.concat(blockedErrors, " | "))
	Check("[QC] avec Ready2Quest 1.25 : QC s'efface (pas de second compagnon)", blocked.blocked == "old-ready2quest"
		and blocked.CompanionData == nil and blocked.ToggleJournal == nil and not blocked.Loaded.Core)
	Check("[QC] avec Ready2Quest 1.25 : message pour le mettre à jour", Mock:Output():find("mets Ready2Quest à jour", 1, true) ~= nil,
		Mock:Output())
end

QCT.Reset()
