-- QuestCompanion 2.9.1 : retours en jeu du 2026-11-09. « Tout capturer » en
-- Azeroth : l'écu des prises porte le nombre d'étoiles, la créature est
-- l'icône fixe de son type (plus de modèle 3D mal cadré). Exploration : titre
-- des quêtes dans la langue du client (C_QuestLog, chargement demandé, repli
-- sur nos noms), lignes de quêtes et zones pas encore vues à l'encre mesurée.
-- Roue crantée du carnet : la roue grise du journal de quêtes du client.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local R = { saved = {}, random = math.random, units = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitFullName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"InCombatLockdown", "UnitAffectingCombat", "PlaySound", "C_Texture", "GetLocale", "time" }
for _, name in ipairs(GLOBALS) do R.saved[name] = rawget(_G, name) end
R.saved.GetTitle, R.saved.RequestLoad = C_QuestLog.GetTitleForQuestID, C_QuestLog.RequestLoadQuestByID
R.saved.ZONE_QUESTS = rawget(NS, "ZONE_QUESTS")
R.savedShiny = NS.SHINY_CHANCE
R.savedAnim, R.savedStyle = NS:DB().companionCaptureAnim, NS:DB().companionStyle
local PLAYER = "Player-1-00000001"
local INK, CONTRAST = NS.AZEROTH_INK, NS.AZEROTH_CONTRAST
local FIELDS = { "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt",
	"captureQueueList", "captureNetButton", "captureToast", "captureResult", "guildFeatToast", "journalToast", "trainerFrame" }
local SCENES = { "captureStage", "captureBatchFrame", "captureChooser" }
local CACHES = { "captureStages", "captureBatchFrames", "captureChoosers" }

local function Lin(c) if c <= 0.03928 then return c / 12.92 end return ((c + 0.055) / 1.055) ^ 2.4 end
local function Lum(c) return 0.2126 * Lin(c[1]) + 0.7152 * Lin(c[2]) + 0.0722 * Lin(c[3]) end
local function Ratio(c, bg)
	local a, b = Lum(c), bg
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end
local function Same(c, ref)
	return c and ref and math.abs(c[1] - ref[1]) < 0.001 and math.abs(c[2] - ref[2]) < 0.001 and math.abs(c[3] - ref[3]) < 0.001
end
local function NoErrors()
	local list = {}
	for _, e in ipairs(NS.errors or {}) do list[#list + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
	return #list == 0, table.concat(list, " | ")
end

local function HideScenes()
	for _, field in ipairs(SCENES) do
		local frame = NS[field]
		if frame then frame:Hide(); frame.rolling = nil end
	end
	for _, field in ipairs(CACHES) do
		for _, frame in pairs(NS[field] or {}) do frame:Hide(); frame.rolling = nil end
	end
end
function R.Guid(npcID) return string.format("Creature-0-4378-1-12-%d-00001A2B3C", npcID) end
function R.Reset(atlas)
	ResetWorld()
	HideScenes()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache, NS.errors, NS.carnetMissing = {}, {}, {}
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureToastHideAt, NS.captureAppCache, NS.captureBatch = nil, nil, nil
	NS.captureResultPending, NS.captureResultHideAt = nil, nil
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	R.units = {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	local w = R
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = w.units[unit]; return u and u.name end
	_G.UnitFullName = function(unit) if unit == "player" then return "Testeur", "Aeternalis" end end
	_G.UnitExists = function(unit) return unit == "player" or w.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function() return false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function() return "normal" end
	_G.UnitCreatureType = function() return "Bête" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function() return 20 end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.PlaySound = function() return true end
	_G.GetLocale = function() return "frFR" end
	_G.time = function() return 1800000000 end
	if atlas == false then Mock.InstallAtlas(nil) else Mock.InstallAtlas(atlas or true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = "azeroth"
	NS.SHINY_CHANCE = 0
	math.random = R.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = true
	NS:DB().captureMuteUntil = nil
	NS:CompanionUpdateVisibility()
end
function R.Roll(value)
	math.random = function(a, b)
		if a and b then return R.random(a, b) end
		if a then return R.random(a) end
		return value
	end
end
function R.SeeKill(npcID, name)
	local fields = { guid = R.Guid(npcID), name = name or ("Bête " .. npcID) }
	R.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, fields.guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, fields.guid, 0)
end
local function ZQReset(zones)
	NS.ZONE_QUESTS = zones
	local s = NS.zoneQuests
	s.done, s.lists, s.builds, s.dirty, s.live, s.requested, s.titles, s.asked = {}, {}, 0, false, {}, {}, {}, {}
end

-- 1. « Tout capturer » : icône du type dans le cadre, étoiles dans l'écu -------------------------------
do
	Say("-- 2.9.1 : Tout capturer, icône du type et étoiles dans l'écu")
	R.Reset()
	for index = 1, 3 do R.SeeKill(9100 + index, "Bête " .. index) end
	local base = NS.CaptureChance
	NS.CaptureChance = function(self, info, ...)
		if info and info.npcID == 9102 then return 0, false end
		return 0.95, false
	end
	R.Roll(0.5)
	local batch = NS:CaptureBatch()
	NS.CaptureChance = base
	local frame = NS.captureBatchFrame
	local tile = frame and frame.tiles[1]
	local icons = NS.MENAGERIE_TYPE_ICONS or {}
	Check("[R291] volée Azeroth : pas de modèle 3D dans les cases", batch and frame.azeroth and tile and tile.model == nil
		and not tile.hasModel and frame.tiles[2].model == nil)
	local hole = NS.AZEROTH_ICON_HOLE
	local size = math.floor(NS.CAPTURE_BATCH_AZEROTH.ring * (hole.r - hole.l) + 0.5)
	Check("[R291] case : l'icône du type (Bête), à la taille du trou du cadre, centrée", tile
		and tile.fallback.texture == icons["Bête"] and tile.fallback.width == size and tile.fallback.height == size
		and tile.fallback:IsShown() and tile.fallback:GetParent() == tile.scene
		and tile.fallback.texCoord and tile.fallback.texCoord[1] == 0.08, tile and tostring(tile.fallback.texture))
	Check("[R291] avant le verdict : écu et nombre cachés", tile and not tile.shield:IsShown() and not tile.shieldText:IsShown())
	NS:CaptureBatchStop(true)
	local ok, fled, okCard
	for _, card in ipairs(batch.cards) do
		if card.result.success then ok = ok or card.tile; okCard = okCard or card else fled = fled or card.tile end
	end
	local point = ok and ok.shieldText.lastPoint
	local face = NS.AZEROTH_SHIELD_FACE
	Check("[R291] prise : l'écu d'or porte le nombre d'étoiles, centré sur l'écu", ok and ok.shield:IsShown()
		and ok.shieldText:IsShown() and ok.shieldText:GetText() == tostring(okCard.result.stars or 1)
		and point and point.point == "CENTER" and point.relTo == ok.shield
		and point.x == math.floor(NS.CAPTURE_BATCH_AZEROTH.shieldW * face.x + 0.5), ok and tostring(ok.shieldText:GetText()))
	Check("[R291] échappée : ni écu ni nombre", fled and not fled.shield:IsShown() and not fled.shieldText:IsShown())
	Check("[R291] prise : la créature (icône) reste visible", ok and ok.fallback:IsShown())
	frame.stop:Click()
	local okErr, errs = NoErrors()
	Check("[R291] volée : sans erreur", okErr, errs)
end

-- 2. Titres des quêtes dans la langue du client ----------------------------------------------------------
do
	Say("-- 2.9.1 : titres des quêtes traduits par le client")
	R.Reset()
	local asked, titles = {}, {}
	C_QuestLog.GetTitleForQuestID = function(id) return titles[id] end
	C_QuestLog.RequestLoadQuestByID = function(id) asked[#asked + 1] = id end
	ZQReset({ [1413] = { [9201] = { en = "Wayward Weapons", lvl = 2 }, [9202] = { en = "Admiral's Orders", fr = "Les ordres de l'amiral", lvl = 7 } } })
	local list = NS:ZoneQuestList(1413) or {}
	local names = {}
	for _, q in ipairs(list) do names[q.id] = q.name end
	Check("[R291] titre pas encore en cache : notre nom, sans attendre", names[9201] == "Wayward Weapons"
		and names[9202] == "Les ordres de l'amiral")
	Check("[R291] chargement demandé seulement pour la quête sans nom français", #asked == 1 and asked[1] == 9201,
		table.concat(asked, ","))
	NS.zoneQuests.lists = {}
	NS:ZoneQuestList(1413)
	Check("[R291] une seule demande par quête", #asked == 1)
	titles[9201] = "Armes égarées"
	NS.ZoneQuestDataLoaded(9201, true)
	names = {}
	for _, q in ipairs(NS:ZoneQuestList(1413) or {}) do names[q.id] = q.name end
	Check("[R291] QUEST_DATA_LOAD_RESULT : le titre traduit remplace l'anglais", names[9201] == "Armes égarées")
	Check("[R291] titre gardé en cache", NS.zoneQuests.titles[9201] == "Armes égarées")
	titles[9201] = nil
	NS.zoneQuests.lists = {}
	names = {}
	for _, q in ipairs(NS:ZoneQuestList(1413) or {}) do names[q.id] = q.name end
	Check("[R291] cache : le titre reste même si le client l'oublie", names[9201] == "Armes égarées")
	Check("[R291] l'événement QUEST_DATA_LOAD_RESULT est écouté", NS.zoneQuestsEventFrame.events.QUEST_DATA_LOAD_RESULT == true)
	-- sans l'API : repli sur nos noms, sans erreur
	C_QuestLog.GetTitleForQuestID, C_QuestLog.RequestLoadQuestByID = nil, nil
	ZQReset({ [1413] = { [9201] = { en = "Wayward Weapons", lvl = 2 } } })
	local plain = NS:ZoneQuestList(1413)
	Check("[R291] sans API du client : notre nom anglais", plain and plain[1].name == "Wayward Weapons")
	-- client anglais : pas de demande pour une quête qui a son nom anglais
	asked = {}
	C_QuestLog.GetTitleForQuestID = function() return nil end
	C_QuestLog.RequestLoadQuestByID = function(id) asked[#asked + 1] = id end
	_G.GetLocale = function() return "enUS" end
	ZQReset({ [1413] = { [9201] = { en = "Wayward Weapons", lvl = 2 } } })
	NS:ZoneQuestList(1413)
	Check("[R291] client anglais : aucune demande inutile", #asked == 0)
	local okErr, errs = NoErrors()
	Check("[R291] titres : sans erreur", okErr, errs)
	C_QuestLog.GetTitleForQuestID, C_QuestLog.RequestLoadQuestByID = R.saved.GetTitle, R.saved.RequestLoad
	ZQReset(R.saved.ZONE_QUESTS)
end

-- 3. Exploration : encres mesurées des quêtes et des zones -----------------------------------------------
do
	Say("-- 2.9.1 : Exploration, encres mesurées")
	local roles = { "quest.name", "quest.nameDone", "quest.detail", "quest.detailDone", "zone.label", "zone.unseen" }
	local bad = {}
	for _, key in ipairs(roles) do
		local role = CONTRAST[key]
		local color = role and INK[role[1]]
		if not (color and Ratio(color, role[2]) >= 4.5 and role[3] >= 4.5) then bad[#bad + 1] = key end
	end
	Check("[R291] rôles quest.* et zone.* : 4,5:1 au moins sur le pire fond", #bad == 0, table.concat(bad, ", "))
	Check("[R291] encre « zoneDim » : 5,41:1 sur le fond des catégories (0,0455)",
		math.abs(Ratio(INK.zoneDim, 0.0455) - 5.41) < 0.01)
	R.Reset()
	ZQReset({ [1413] = { [9301] = { en = "Wayward Weapons", lvl = 2 }, [9302] = { en = "Legging It", lvl = 6 } } })
	local f = NS:ToggleJournal(true)
	NS:SelectJournalKind("progress")
	f.progPart = "quests"
	NS:RefreshJournal()
	NS:RefreshJournal()
	local pane = f.prog
	local line
	for _, l in ipairs(pane and pane.items or {}) do
		if l.item and not l.item.header and l:IsShown() then line = line or l end
	end
	Check("[R291] ligne de quête : fond clair, nom à l'encre « ink »", line and line.azStyle == "light"
		and Same(line.text.textColor, INK[CONTRAST["quest.name"][1]]), line and tostring(line.azStyle))
	Check("[R291] ligne de quête : détail sans code couleur, encre « inkMuted »", line
		and not (line.detail:GetText() or ""):find("|c", 1, true)
		and Same(line.detail.textColor, INK[CONTRAST["quest.detail"][1]]), line and tostring(line.detail:GetText()))
	-- une ligne faite : nom adouci, « faite » en vert sombre
	if line then
		NS.CarnetQuestLineInk(line, { done = true, detail = NS.L.ZQ_DONE })
		Check("[R291] quête faite : nom « inkMuted », détail vert sombre", Same(line.text.textColor, INK.inkMuted)
			and Same(line.detail.textColor, INK.green))
	end
	-- les zones pas encore vues : rangée opaque, gris mesuré
	local unseen
	for _, row in ipairs(pane and pane.zones or {}) do
		if row.zone and not row.zone.seen and not row.selected and row:IsShown() then unseen = unseen or row end
	end
	if not unseen and pane and pane.zones[2] then
		unseen = pane.zones[2]
		unseen.zone, unseen.selected = { id = 1, name = "Zone test", seen = false }, false
		NS.CarnetZoneRowInk(unseen)
	end
	Check("[R291] zone pas encore vue : rangée opaque, nom « zoneDim »", unseen and (unseen.alpha or 1) == 1
		and Same(unseen.name.textColor, INK.zoneDim), unseen and tostring(unseen.alpha))
	local okErr, errs = NoErrors()
	Check("[R291] Exploration : sans erreur", okErr, errs)
	f:Hide()
	ZQReset(R.saved.ZONE_QUESTS)
end

-- 4. La roue crantée du carnet ---------------------------------------------------------------------------
do
	Say("-- 2.9.1 : roue crantée grise")
	R.Reset()
	local f = NS:ToggleJournal(true)
	local button = f.settingsButton
	local cog = NS.JOURNAL_COG
	Check("[R291] roue : atlas « questlog-icon-setting », 16 px, centrée", button and button.icon.atlas == "questlog-icon-setting"
		and button.cogTexture == "questlog-icon-setting" and button.icon.width == 16 and button.icon.height == 16
		and button.icon.lastPoint.point == "CENTER", button and tostring(button.icon.atlas))
	Check("[R291] roue : pas de carré au trait", button and not button.border.top:IsShown() and not button.border.left:IsShown()
		and not button.border.bottom:IsShown() and not button.border.right:IsShown())
	Check("[R291] roue au repos : grise estompée", button and Same(button.icon.vertex, cog.rest) and button.icon.alpha == cog.rest[4]
		and button.cogHot == false)
	button:GetScript("OnEnter")(button)
	Check("[R291] roue au survol : plus claire", Same(button.icon.vertex, cog.hover) and button.icon.alpha == 1 and button.cogHot == true
		and not button.border.top:IsShown())
	button:GetScript("OnLeave")(button)
	Check("[R291] roue : revient au repos", Same(button.icon.vertex, cog.rest) and button.cogHot == false)
	f:Hide()
	-- atlas absent : le second, puis le fichier
	R.Reset({ ["questlog-icon-setting"] = true })
	f = NS:ToggleJournal(true)
	Check("[R291] roue : repli sur « gm-icon-settings »", f.settingsButton.icon.atlas == "gm-icon-settings"
		and f.settingsButton.cogTexture == "gm-icon-settings")
	f:Hide()
	R.Reset(false)
	f = NS:ToggleJournal(true)
	Check("[R291] roue sans atlas : le fichier UI-OptionsButton", f.settingsButton.icon.texture == cog.file
		and f.settingsButton.cogTexture == cog.file and f.settingsButton.icon.width == 16)
	local okErr, errs = NoErrors()
	Check("[R291] roue : sans erreur", okErr, errs)
	f:Hide()
end

-- Remise en état ------------------------------------------------------------------------------------------
do
	HideScenes()
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:ApplyUIStyle()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	for _, field in ipairs(SCENES) do NS[field] = nil end
	for _, field in ipairs(CACHES) do NS[field] = nil end
	NS.uiStyleCache = {}
	NS.captureResultPending, NS.captureResultHideAt, NS.captureBatch = nil, nil, nil
	for _, name in ipairs(GLOBALS) do _G[name] = R.saved[name] end
	C_QuestLog.GetTitleForQuestID, C_QuestLog.RequestLoadQuestByID = R.saved.GetTitle, R.saved.RequestLoad
	math.random = R.random
	NS.SHINY_CHANCE = R.savedShiny
	NS:DB().companionCaptureAnim, NS:DB().companionStyle = R.savedAnim, R.savedStyle
	ResetWorld()
end
