-- Module « Avant le donjon » (v1.23.0) : détection, une fiche par visite,
-- verdict de niveau, quêtes sous l'en-tête du donjon, préparation, réglages.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

-- Mocks propres à ce fichier, restaurés à la fin
local saved = {
	IsInInstance = rawget(_G, "IsInInstance"), GetInstanceInfo = rawget(_G, "GetInstanceInfo"),
	GetRealZoneText = rawget(_G, "GetRealZoneText"), GetAreaInfo = C_Map.GetAreaInfo,
	QLGetInfo = C_QuestLog.GetInfo,
	GetNumSkillLines = rawget(_G, "GetNumSkillLines"), GetSkillLineInfo = rawget(_G, "GetSkillLineInfo"),
}
-- noms traduits renvoyés par le « jeu » (client français)
local AREAS = {
	[209] = "Donjon d'Ombrecroc", [236] = "Donjon d'Ombrecroc", [1581] = "Les Mortemines",
	[16544] = "Cité de Dalaran", [279] = "Dalaran",
}
local W = {}
_G.IsInInstance = function() return W.inInstance == true, W.instType end
_G.GetInstanceInfo = function()
	if not W.inInstance then return "Royaumes de l'Est", "none", 0, "", 0, 0, false, 0 end
	return W.instName, W.instType, 1, "Normal", 5, 0, false, W.instID
end
_G.GetRealZoneText = function() return W.zone or "" end
C_Map.GetAreaInfo = function(areaID) return AREAS[areaID] end

local function Reset(level)
	ResetWorld()
	-- ces tests visent la fenêtre ; l'icône qui l'annonce : tests/modules/notice.lua
	NS:DB().reportIcon = false
	W = {}
	NS.dungeonVisit, NS.lastDungeonSheet, NS.dungeonIndex = nil, nil, nil
	if NS.dungeonFrame then NS.dungeonFrame:Hide() end
	Mock.world.level = level or 22
	Mock.world.subzone = "Bois"
end
local function Inside(name, id, kind)
	W.inInstance, W.instName, W.instID, W.instType = true, name, id, kind or "party"
	Mock:Fire("PLAYER_ENTERING_WORLD", false, false)
end
local function Outside(subzone)
	W.inInstance, W.instType = false, nil
	Mock.world.subzone = subzone
	Mock:Fire("ZONE_CHANGED_NEW_AREA")
end
local function Sub(subzone)
	Mock.world.subzone = subzone
	Mock:Fire("ZONE_CHANGED")
end

do
	Say("-- données")
	local count = 0
	for _ in pairs(NS.DUNGEONS or {}) do count = count + 1 end
	Check("[DGN] chargés, 28 donjons dans la base", NS.Loaded.DungeonData and NS.Loaded.Dungeon and count == 28, count)
	local forever = { "thanes", "lordaeron", "excavation", "dalaran", "drowned", "kroldok", "alcaz", "blackmaw", "shaper" }
	local missing = {}
	for _, key in ipairs(forever) do
		local d = NS.DUNGEONS[key]
		if not (d and d.fo) then missing[#missing + 1] = key end
	end
	Check("[DGN] les 9 donjons de Forever présents", #missing == 0, table.concat(missing, ","))
	local dal = NS.DUNGEONS.dalaran
	Check("[DGN] Dalaran : carte 2959, 28-33 ; Mortemines : niveaux de Forever seuls (17-26)", dal.map == 2959
		and dal.fo[1] == 28 and dal.fo[2] == 33 and NS.DUNGEONS.dm.era == nil
		and NS.DUNGEONS.dm.fo[1] == 17 and NS.DUNGEONS.dm.fo[2] == 26)
end

do
	Say("-- entrée dans l'instance")
	Reset(22)
	Inside("Donjon d'Ombrecroc", 33)
	local sheet = NS.lastDungeonSheet
	Check("[DGN] fiche à l'entrée dans l'instance : fenêtre, nom traduit en sous-titre", sheet and sheet.key == "sfk"
		and sheet.how == "instance" and NS.dungeonFrame and NS.dungeonFrame:IsShown()
		and tostring(NS.dungeonFrame.subtitle.text):find("Donjon d'Ombrecroc", 1, true) ~= nil, sheet and sheet.key)
	Check("[DGN] la fenêtre du Check avant le départ reste fermée", NS.window == nil)
	NS.lastDungeonSheet = nil
	Mock:Fire("ZONE_CHANGED_INDOORS"); Mock:Fire("ZONE_CHANGED"); Mock:RunTimers()
	Check("[DGN] pas de seconde fiche dans la même instance", NS.lastDungeonSheet == nil)
	Reset(22)
	Inside("Donjon d'Ombrecroc", 33, "raid")
	local raid = NS.lastDungeonSheet
	Reset(22)
	Inside("Instance inconnue", 4242)
	Check("[DGN] raid ou instance hors base : pas de fiche", raid == nil and NS.lastDungeonSheet == nil)
	Reset(36)
	Inside("The Drowned City", 99999)
	Check("[DGN] donjon sans mapID : reconnu au nom", NS.lastDungeonSheet and NS.lastDungeonSheet.key == "drowned")
	Reset(22)
	Mock.world.dead = true
	Inside("Donjon d'Ombrecroc", 33)
	local ghost = NS.lastDungeonSheet
	Mock.world.dead = false
	Mock:Fire("ZONE_CHANGED")
	Check("[DGN] fantôme : pas de fiche ; ressuscité dans l'instance : fiche", ghost == nil and NS.lastDungeonSheet ~= nil)
end

do
	Say("-- une fiche par visite")
	Reset(22)
	Sub("Donjon d'Ombrecroc")
	Check("[DGN] fiche à la sous-zone d'entrée", NS.lastDungeonSheet and NS.lastDungeonSheet.how == "entrance")
	NS.lastDungeonSheet = nil
	Mock.now = Mock.now + 30; Sub("Forêt des Pins-Argentés")
	Mock.now = Mock.now + 30; Sub("Donjon d'Ombrecroc")
	Inside("Donjon d'Ombrecroc", 33)
	Mock.now = Mock.now + 3600; Mock:Fire("ZONE_CHANGED")
	Outside("Donjon d'Ombrecroc")
	Check("[DGN] aller-retour à l'entrée, instance, longtemps dedans puis sortie : une seule fiche", NS.lastDungeonSheet == nil)
	Mock.now = Mock.now + 60; Sub("Pyrewood")
	Mock.now = Mock.now + 1000; Sub("Donjon d'Ombrecroc")
	Check("[DGN] retour après 15 min loin : nouvelle visite", NS.lastDungeonSheet ~= nil)
	NS.lastDungeonSheet = nil
	Inside("Les Mortemines", 36)
	Check("[DGN] autre donjon : nouvelle fiche", NS.lastDungeonSheet and NS.lastDungeonSheet.key == "dm")
end

do
	Say("-- niveaux")
	Reset(22)
	local sfk = NS.DUNGEONS.sfk
	Check("[DGN] Forever : 19 trop bas, 20 et 30 ok, 31 gris", NS:DungeonVerdict(sfk, 19) == "low"
		and NS:DungeonVerdict(sfk, 20) == "ok" and NS:DungeonVerdict(sfk, 30) == "ok" and NS:DungeonVerdict(sfk, 31) == "grey")
	Reset(10); Sub("Donjon d'Ombrecroc")
	local low = NS.lastDungeonSheet
	Reset(60); Sub("Donjon d'Ombrecroc")
	Check("[DGN] entrée au niveau 10 (passage) ou 60 (gris) : rien", low == nil and NS.lastDungeonSheet == nil)
	Reset(18); Sub("Donjon d'Ombrecroc")
	local sheet = NS.lastDungeonSheet
	Check("[DGN] entrée, 2 niveaux sous le mini : fiche « trop bas de 2 »", sheet and sheet.verdict == "low"
		and NS:LevelText(sheet):find("trop bas de 2", 1, true) ~= nil, sheet and sheet.verdict)
	Reset(60); Inside("Donjon d'Ombrecroc", 33)
	sheet = NS.lastDungeonSheet
	Check("[DGN] instance au niveau 60 : fiche « gris »", sheet and sheet.verdict == "grey", sheet and sheet.verdict)
	Reset(22); NS:DB().dungeonAtEntrance = false; Sub("Donjon d'Ombrecroc")
	local atEntrance = NS.lastDungeonSheet
	Inside("Donjon d'Ombrecroc", 33)
	Check("[DGN] réglage « aussi à l'entrée » coupé : rien à l'entrée, fiche dans l'instance", atEntrance == nil
		and NS.lastDungeonSheet ~= nil)
end

do
	Say("-- quêtes du journal")
	local log = {
		{ title = "Forêt des Pins-Argentés", isHeader = true },
		{ title = "Le Rouvre", questID = 1 },
		{ title = "Donjon d'Ombrecroc", isHeader = true },
		{ title = "Le livre d'Ur", questID = 2 },
		{ title = "Arugal doit mourir", questID = 3, ready = true },
		{ title = "Les Mortemines", isHeader = true },
		{ title = "Edwin VanCleef", questID = 4 },
	}
	-- API C_QuestLog (Forever) avec en-têtes : celle du harnais
	Reset(22); Mock.world.quests = log
	Inside("Donjon d'Ombrecroc", 33)
	local q = NS.lastDungeonSheet and NS.lastDungeonSheet.quests or {}
	Check("[DGN] 2 quêtes sous l'en-tête du donjon, « à rendre » via ReadyForTurnIn", #q == 2 and q[1].title == "Le livre d'Ur"
		and q[2].ready == true and q[1].ready == false, #q)
	Reset(22); Mock.world.quests = log
	Inside("Les Mortemines", 36)
	q = NS.lastDungeonSheet and NS.lastDungeonSheet.quests or {}
	Check("[DGN] quête sous « Les Mortemines »", #q == 1 and q[1].title == "Edwin VanCleef", #q)
	Reset(22)
	Mock.world.quests = { { title = "Donjon d'Ombrecroc", isHeader = true, collapsed = true } }
	Inside("Donjon d'Ombrecroc", 33)
	Check("[DGN] en-tête replié signalé", NS.lastDungeonSheet and NS.lastDungeonSheet.collapsed == true)
	Reset(22)
	Inside("Donjon d'Ombrecroc", 33)
	Check("[DGN] journal vide : liste vide, ligne « aucune quête » dans la fenêtre", NS.lastDungeonSheet
		and #NS.lastDungeonSheet.quests == 0
		and NS.dungeonFrame.lines[3] and tostring(NS.dungeonFrame.lines[3].text.text):find("Aucune quête", 1, true) ~= nil)
	Check("[DGN] Normalize : article et casse", NS.DungeonNormalize("The Deadmines") == NS.DungeonNormalize("deadmines")
		and NS.DungeonNormalize("Les Mortemines") == "mortemines")
end

do
	Say("-- préparation")
	Reset(22)
	Mock.world.durability = { [1] = { 10, 100 } }
	Inside("Donjon d'Ombrecroc", 33)
	local byId = {}
	for _, line in ipairs(NS.lastDungeonSheet.readiness) do byId[line.id] = line end
	Check("[DGN] durabilité 10 %, sans vivres, sans pierre de foyer : en échec", byId.durability and byId.durability.ok == false
		and byId.vivres and byId.vivres.ok == false and byId.hearth and byId.hearth.ok == false)
	Check("[DGN] absents : potions à seuil 0, réparation jamais mesurée, contrôles hors donjon", byId.potions == nil
		and byId.repair == nil and byId.bags == nil and byId.buffs == nil)
	local bad = 0
	for _, line in ipairs(NS.dungeonFrame.lines) do
		if line:IsShown() and line.status.state == "bad" then bad = bad + 1 end
	end
	Check("[DGN] fenêtre : losanges rouges pour les échecs", bad == 3, bad)
	Reset(22)
	NS:SetModuleEnabled("vivres", false)
	Mock.world.durability = { [1] = { 100, 100 } }
	Inside("Donjon d'Ombrecroc", 33)
	byId = {}
	for _, line in ipairs(NS.lastDungeonSheet.readiness) do byId[line.id] = line end
	Check("[DGN] contrôle coupé par le joueur : absent ; durabilité pleine : OK", byId.vivres == nil
		and byId.durability and byId.durability.ok == true)
end

do
	Say("-- réglages, chat, module coupé")
	Reset(22)
	NS:DB().dungeonShowWindow = false
	Mock.world.quests = { { title = "Donjon d'Ombrecroc", isHeader = true }, { title = "Arugal doit mourir", questID = 3, ready = true } }
	Inside("Donjon d'Ombrecroc", 33)
	local out = Mock:Output()
	Check("[DGN] chat : en-tête, quête « à rendre », préparation résumée, pas de fenêtre", out:find("Avant le donjon :", 1, true) ~= nil
		and out:find("Arugal doit mourir (à rendre)", 1, true) ~= nil and out:find("À voir :", 1, true) ~= nil
		and not (NS.dungeonFrame and NS.dungeonFrame:IsShown()), out)
	Reset(22)
	NS:DB().dungeonEnabled = false
	Inside("Donjon d'Ombrecroc", 33); Sub("Donjon d'Ombrecroc")
	local moduleOff = NS.lastDungeonSheet == nil and Mock:Output() == ""
	Reset(22)
	NS:DB().enabled = false
	Inside("Donjon d'Ombrecroc", 33)
	Check("[DGN] module ou addon coupé : rien", moduleOff and NS.lastDungeonSheet == nil)
	Reset(22)
	NS:HandleCommand("module donjon off")
	Check("[DGN] /r2q module donjon off ; module enregistré (alias dungeon)", NS:DB().dungeonEnabled == false
		and NS:FindModule("dungeon") and NS:FindModule("dungeon").key == "dungeonEnabled")
	local page
	for _, def in ipairs(NS.OPTION_PAGES) do if def.id == "dungeon" then page = def end end
	NS.optionsFrame = nil
	local okOpen = pcall(NS.ToggleOptions, NS)
	local okPage = okOpen and pcall(NS.SelectOptionsPage, NS, "dungeon")
	Check("[DGN] page avec interrupteur, construite et sélectionnable", page and page.power == "dungeonEnabled"
		and page.group == "OPT_GROUP_MODULES" and #page.rows == 2
		and okPage and NS.optionsFrame and NS.optionsFrame.currentPage == "dungeon")
	if NS.optionsFrame then NS.optionsFrame:Hide() end
end

do
	Say("-- textes fr / en")
	local S = NS.DUNGEON_STRINGS
	local gaps = {}
	for k, v in pairs(S.fr) do if type(S.en[k]) ~= "string" or S.en[k] == "" or v == "" then gaps[#gaps + 1] = k end end
	for k in pairs(S.en) do if S.fr[k] == nil then gaps[#gaps + 1] = k end end
	local okFmt = pcall(string.format, S.en.DGN_LEVEL_LOW, 20, 30, 18, 2) and pcall(string.format, S.fr.DGN_LEVEL_LOW, 20, 30, 18, 2)
	Check("[DGN] chaque texte en fr et en en, client fr traduit, formats de niveau valides", #gaps == 0
		and NS.L.OPT_PAGE_DUNGEON == "Avant le donjon" and S.en.DGN_TITLE == "Before the dungeon" and okFmt, table.concat(gaps, ","))
end

do
	Say("-- plans avancés")
	NS.DUNGEON_BLUEPRINTS.sfk = { { prof = "BS", item = 1, name = "Plan avancé : test" } }
	_G.GetNumSkillLines = function() return 1 end
	_G.GetSkillLineInfo = function() return W.prof end
	Reset(22); W.prof = "Forge"
	Inside("Donjon d'Ombrecroc", 33)
	local mine = NS.lastDungeonSheet and #NS.lastDungeonSheet.blueprints == 1
	Reset(22); W.prof = "Couture"
	Inside("Donjon d'Ombrecroc", 33)
	Check("[DGN] plan du métier du joueur listé, d'un autre métier absent", mine and NS.lastDungeonSheet
		and #NS.lastDungeonSheet.blueprints == 0)
	NS.DUNGEON_BLUEPRINTS.sfk = nil
end

-- restauration
_G.IsInInstance, _G.GetInstanceInfo, _G.GetRealZoneText = saved.IsInInstance, saved.GetInstanceInfo, saved.GetRealZoneText
C_Map.GetAreaInfo = saved.GetAreaInfo
C_QuestLog.GetInfo = saved.QLGetInfo
_G.GetNumSkillLines, _G.GetSkillLineInfo = saved.GetNumSkillLines, saved.GetSkillLineInfo
Reset(22)
