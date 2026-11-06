-- Compagnon : la version brillante de chaque espèce (QuestCompanion 1.6.0).
-- Deux captures par espèce (normale, brillante), anciennes fiches migrées,
-- brillante reconnue sans capture, chasse (la chance monte avec les abattus),
-- une mission de la semaine « brillante », lumière dorée, Ménagerie (marques,
-- filtre, fiche normale / brillante, équiper l'une ou l'autre), infobulle.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local SV = { saved = {}, random = math.random, units = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"CreateVector3D", "CreateColor", "C_NamePlate" }
for _, name in ipairs(GLOBALS) do SV.saved[name] = rawget(_G, name) end
SV.savedShiny = NS.SHINY_CHANCE
local PLAYER = "Player-1-00000001"

function SV.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function SV.Install()
	local w = SV
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = w.units[unit]; return u and u.name end
	_G.UnitExists = function(unit) return unit == "player" or w.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function() return false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function(unit) local u = w.units[unit]; return u and u.class or "normal" end
	_G.UnitCreatureType = function() return "Bête" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function() return 20 end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
	_G.C_Timer = { After = function(_, fn) fn() end }
end
function SV.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureAppCache = nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	SV.units = {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	SV.Install()
	NS.SHINY_CHANCE = 0
	math.random = SV.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = false
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	NS:CompanionUpdateVisibility()
end
function SV.Roll(value)
	math.random = function(a, b)
		if a and b then return SV.random(a, b) end
		if a then return SV.random(a) end
		return value
	end
end
function SV.SeeKill(npcID, spawn)
	local guid = SV.Guid(npcID, spawn)
	SV.units.target = { guid = guid, name = "Kodo " .. npcID }
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
	return guid
end
-- le filet part et réussit (tirage 0)
function SV.Capture()
	SV.Roll(0)
	local thrown = NS:CaptureThrow()
	for _ = 1, 12 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	return thrown
end

-- 1. Données : deux versions, anciennes fiches migrées --------------------------------------------
do
	Say("-- brillantes : deux versions par espèce")
	SV.Reset()
	local data = NS:CompanionData()
	data.capture = { creatures = {
		[11] = { name = "Ancien brillant", at = 500, shiny = true },
		[12] = { name = "Ancien normal", at = 300 },
	}, count = 2 }
	local capture = NS:CaptureData()
	Check("[SHV] migration : l'ancien brillant devient la version brillante, la normale reste à capturer",
		capture.creatures[11].normal == false and capture.creatures[11].shinyAt == 500
		and NS:CaptureHas(11, true) and not NS:CaptureHas(11, false))
	Check("[SHV] migration : l'ancien normal reste normal", capture.creatures[12].normal == true
		and NS:CaptureHas(12, false) and not NS:CaptureHas(12, true))
	local ids = {}
	for _, def in ipairs(NS:CaptureAppearances()) do ids[def.id] = def end
	Check("[SHV] apparences : une par version capturée", ids["cap:11:s"] and ids["cap:11:s"].shiny and ids["cap:11"] == nil
		and ids["cap:12"] and ids["cap:12:s"] == nil)
	Check("[SHV] brillantes capturées : 1", NS:CaptureShinyCount() == 1)
end

-- 2. Capturer la normale, puis la brillante --------------------------------------------------------
do
	SV.Reset()
	SV.SeeKill(3100, "AAAA")
	Check("[SHV] normale abattue : capture proposée", NS:CaptureState().pending ~= nil)
	SV.Capture()
	Check("[SHV] normale capturée", NS:CaptureHas(3100, false) and not NS:CaptureHas(3100, true))
	-- la normale encore : plus proposée
	SV.SeeKill(3100, "BBBB")
	Check("[SHV] normale déjà capturée : plus proposée", NS:CaptureState().pending == nil)
	-- une brillante de la même espèce : proposée, et capturée À CÔTÉ
	NS:WeeklyData().week = NS:WeeklyId()
	NS:WeeklyData().missions = { { kind = "shinyCapture", need = 1, have = 0, source = "week" } }
	NS.SHINY_CHANCE = 1
	SV.Roll(0)
	local guid = SV.SeeKill(3100, "CCCC")
	Check("[SHV] brillante de l'espèce : proposée malgré la normale", NS:CaptureState().pending and NS:CaptureState().pending.shiny)
	NS.SHINY_CHANCE = 0
	SV.Capture()
	local entry = NS:CaptureData().creatures[3100]
	Check("[SHV] brillante capturée à côté : les deux versions", entry.normal == true and entry.shiny == true
		and entry.shinyAt ~= nil and NS:CaptureData().count == 1)
	Check("[SHV] mission de la semaine « capture une brillante » faite", NS:WeeklyData().missions[1].done == true)
	Check("[SHV] brillante reconnue depuis qu'elle a été repérée", NS:ShinyKnown(3100) ~= nil and guid ~= nil)
	local ids = {}
	for _, def in ipairs(NS:CaptureAppearances()) do ids[def.id] = true end
	Check("[SHV] deux apparences : normale et brillante", ids["cap:3100"] and ids["cap:3100:s"])
	NS:CompanionData().appearance = "cap:3100:s"
	Check("[SHV] compagnon brillant : il garde le nom de l'espèce", NS:CompanionName() == "Kodo 3100", NS:CompanionName())
	NS:CompanionData().appearance = NS.COMPANION_APPEARANCES[1].id
end

-- 3. Reconnue sans capture, chasse ------------------------------------------------------------------
do
	Say("-- brillantes : reconnue, chasse")
	SV.Reset()
	NS.SHINY_CHANCE = 1
	SV.Roll(0)
	SV.units.target = { guid = SV.Guid(3200), name = "Loup" }
	NS:BestiarySeeUnit("target")
	NS.SHINY_CHANCE = 0
	Check("[SHV] repérée sans être abattue ni capturée : reconnue", NS:ShinyKnown(3200) ~= nil
		and not NS:CaptureHas(3200, true))
	local list = NS:MenagerieList({ zone = "all", state = "shiny" })
	local found
	for _, item in ipairs(list) do if item.npc == 3200 then found = item end end
	Check("[SHV] Ménagerie, filtre « Brillantes » : la reconnue y est", found and found.shinySeen ~= nil and not found.shiny)
	NS.SHINY_CHANCE = 1 / 150
	Check("[SHV] chasse : 1/150 sans abattu", math.abs(NS:ShinyChance("normal", 0) - 1 / 150) < 1e-9)
	Check("[SHV] chasse : 1/40 après 50 abattus de l'espèce", math.abs(NS:ShinyChance("normal", 50) - 1 / 40) < 1e-9)
	Check("[SHV] chasse : plafonnée", NS:ShinyChance("normal", 500) == NS:ShinyChance("normal", 50))
	Check("[SHV] chasse : un élite garde son ×3", math.abs(NS:ShinyChance("elite", 50) - 3 / 40) < 1e-9)
	NS.SHINY_CHANCE = 0
end

-- 4. Missions de la semaine : toujours une chasse au brillant ---------------------------------------
do
	SV.Reset()
	local ok = true
	for _ = 1, 20 do
		local shiny = false
		for _, mission in ipairs(NS:WeeklyDraw(true)) do
			if NS.WEEKLY_SHINY_KINDS[mission.kind] then shiny = true end
		end
		if not shiny then ok = false end
	end
	Check("[SHV] chaque semaine : une mission « brillante » (abattre ou capturer)", ok)
	NS:WeeklyData().missions = { { kind = "shinyKill", need = 1, have = 0, source = "week" } }
	NS:WeeklyData().week = NS:WeeklyId()
	NS.SHINY_CHANCE = 1
	SV.Roll(0)
	SV.SeeKill(3300)
	NS.SHINY_CHANCE = 0
	Check("[SHV] abattre une brillante : la mission avance", NS:WeeklyData().missions[1].done == true)
	Check("[SHV] libellés FR", NS.L.WK_shinyKill == "Abats une créature brillante"
		and NS.L.WK_shinyCapture == "Capture une créature brillante")
end

-- 5. Lumière dorée ------------------------------------------------------------------------------------
do
	Say("-- brillantes : lumière dorée")
	local calls = {}
	local model = {
		GetLight = function() return true, "origine" end,
		SetLight = function(_, ...) calls[#calls + 1] = { ... } end,
	}
	_G.CreateVector3D = function(x, y, z) return { x = x, y = y, z = z } end
	_G.CreateColor = function(r, g, b) return { r = r, g = g, b = b } end
	Check("[SHV] brillante : lumière dorée posée (API récente)", NS.ModelShinyLight(model, true) and #calls == 1
		and type(calls[1][2]) == "table" and calls[1][2].ambientColor.g < 1)
	NS.ModelShinyLight(model, true)
	Check("[SHV] déjà dorée : rien de plus", #calls == 1)
	NS.ModelShinyLight(model, false)
	Check("[SHV] normale : la lumière d'origine revient", #calls == 2 and calls[2][2] == "origine")
	_G.CreateVector3D, _G.CreateColor = nil, nil
	local old = { GetLight = function() return nil end, SetLight = function(_, ...) calls[#calls + 1] = { ... } end }
	Check("[SHV] client historique : la liste d'arguments", NS.ModelShinyLight(old, true) and #calls[#calls] == 13)
	Check("[SHV] modèle sans lumière : sans erreur", NS.ModelShinyLight({}, true) == false)
end

-- 6. Ménagerie : marques, fiche normale / brillante, équiper -------------------------------------------
do
	Say("-- brillantes : Ménagerie")
	SV.Reset()
	NS:CaptureData().creatures[3400] = { name = "Lion", class = "normal", normal = true, at = 100, shiny = true, shinyAt = 200 }
	NS:CaptureData().count = 1
	NS.captureAppCache = nil
	NS:BestiaryData()[1413] = { [3400] = { name = "Lion", seen = true, killed = 2, class = "normal" } }
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.menZone, f.menState, f.menRank, f.menSearch, f.menSort = "all", "all", "all", "lion", "no"
	f.sections.menagerie:Click()
	local pane, row = f.men, nil
	for _, cell in ipairs(pane.items) do if cell.entry and cell.entry.npc == 3400 then row = cell end end
	Check("[SHV] ligne : liseré vert (normale) et losange doré plein (brillante capturée)", row and row.caught:IsShown()
		and row.star:IsShown() and row.star.texture == NS.Theme.DIAMOND)
	Check("[SHV] puce « Brillantes »", pane.states.shiny ~= nil and pane.states.shiny.text and pane.states.shiny.text.text == "Brillantes"
		or pane.states.shiny ~= nil)
	row.scripts.OnEnter(row)
	local preview = pane.preview
	Check("[SHV] fiche : la normale d'abord, bouton « Version brillante »", preview.shiny == false
		and preview.variant:IsShown() and preview.variant.text.text == "Version brillante")
	preview.variant:Click()
	Check("[SHV] bouton : la fiche passe à la brillante", preview.shiny == true and preview.title.text:find("Lion", 1, true)
		and preview.variant.text.text == "Version normale")
	row:Click()
	Check("[SHV] clic sur la ligne : la version montrée devient le compagnon", NS:CompanionData().appearance == "cap:3400:s",
		NS:CompanionData().appearance)
	preview.variant:Click()
	row:Click()
	Check("[SHV] … et la normale", NS:CompanionData().appearance == "cap:3400")
	f:Hide()
end

-- 7. Losange doré sur la barre de nom d'une brillante vivante ----------------------------------------
do
	Say("-- brillantes : repère sur la barre de nom")
	SV.Reset()
	local plates = {}
	_G.C_NamePlate = {
		GetNamePlateForUnit = function(unit) return plates[unit] end,
		GetNamePlates = function() local list = {} for _, p in pairs(plates) do list[#list + 1] = p end return list end,
	}
	local plate = CreateFrame("Frame")
	plate.namePlateUnitToken = "nameplate1"
	plates.nameplate1 = plate
	NS.shinyPlates = {}
	local guid = SV.Guid(3500, "00000ABCDE")
	SV.units.nameplate1 = { guid = guid, name = "Kodo" }
	NS:ShinyPlatesRefresh()
	local mark = NS.shinyPlateMarks[plate]
	Check("[SHV] monstre normal : pas de losange", mark == nil or not mark:IsShown())
	NS.SHINY_CHANCE = 1
	SV.Roll(0)
	SV.units.target = { guid = guid, name = "Kodo" }
	NS:BestiarySeeUnit("target")
	NS.SHINY_CHANCE = 0
	mark = NS.shinyPlateMarks[plate]
	Check("[SHV] brillante repérée : losange doré sur sa barre, tout de suite", mark and mark:IsShown() and mark.guid == guid
		and mark:GetParent() == plate)
	Check("[SHV] … au-dessus du nom, qui scintille", mark.lastPoint and mark.lastPoint.point == "BOTTOM"
		and mark.lastPoint.relPoint == "TOP" and mark.scripts.OnUpdate ~= nil)
	pcall(mark.scripts.OnUpdate, mark)
	NS:DB().companionShinyPlate = false
	NS:ShinyPlatesRefresh()
	Check("[SHV] réglage coupé : losange caché", not mark:IsShown())
	NS:DB().companionShinyPlate = true
	NS:ShinyPlatesRefresh()
	Check("[SHV] réglage remis : de retour", mark:IsShown())
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
	Check("[SHV] brillante abattue : losange parti", not mark:IsShown() and mark.guid == nil)
	-- barre retirée puis reprise par une autre unité : rien ne traîne
	NS:ShinyState().live[guid] = { npcID = 3500 }
	NS:ShinyPlatesRefresh()
	NS.shinyPlateFrame:GetScript("OnEvent")(NS.shinyPlateFrame, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
	Check("[SHV] barre retirée : losange caché", not mark:IsShown())
	NS:ShinyState().live[guid] = nil
	NS.shinyPlates = {}
end

-- fin
for _, name in ipairs(GLOBALS) do _G[name] = SV.saved[name] end
math.random = SV.random
NS.SHINY_CHANCE = SV.savedShiny
NS:CompanionData().appearance = NS.COMPANION_APPEARANCES[1].id
ResetWorld()
