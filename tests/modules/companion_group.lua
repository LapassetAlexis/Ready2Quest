-- Compagnon en groupe (Group.lua), lecture locale : composition (soigneur),
-- niveaux face au donjon, membre resté en arrière ou encore ailleurs, morts
-- et déconnexions ; rien en raid ; réglette « Bavardage ».
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local GR = { saved = {}, savedDetect = NS.DetectDungeon, savedMap = C_Map.GetBestMapForUnit }
for _, name in ipairs({ "IsInGroup", "IsInRaid", "UnitExists", "UnitClass", "UnitName", "UnitLevel", "UnitIsVisible",
	"UnitIsConnected", "UnitIsDeadOrGhost", "UnitOnTaxi", "UnitAffectingCombat" }) do GR.saved[name] = rawget(_G, name) end

function GR.Reset(members, level)
	ResetWorld()
	NS.companionRT, NS.companionSession, NS.groupState, NS.groupNextAt = nil, nil, nil, nil
	NS.companionLastBubble, NS.companionBubbleKey, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil, nil
	NS:CompanionData().tutoDone = true
	NS:DB().companionChatter = level or 3
	Mock.world.level = 20
	Mock.world.mapID, Mock.world.subzone = 20, "Clairière"
	Mock.world.party = members or {}
	Mock.world.raid = false
	Mock.world.combat = nil
	Mock.world.playerClass = "WARRIOR"
	_G.IsInRaid = function() return Mock.world.raid end
	_G.IsInGroup = function() return #Mock.world.party > 0 end
	local function Member(unit)
		local index = tonumber(tostring(unit):match("^party(%d)$") or "")
		return index and Mock.world.party[index]
	end
	GR.Member = Member
	_G.UnitExists = function(unit) return unit == "player" or Member(unit) ~= nil end
	_G.UnitClass = function(unit)
		if unit == "player" then return "Guerrier", Mock.world.playerClass end
		local m = Member(unit); return m and m.class, m and m.class
	end
	_G.UnitName = function(unit) local m = Member(unit); return m and m.name or "Testeur" end
	_G.UnitLevel = function(unit) local m = Member(unit); return m and m.level or Mock.world.level end
	_G.UnitIsVisible = function(unit) local m = Member(unit); return m == nil or m.visible ~= false end
	_G.UnitIsConnected = function(unit) local m = Member(unit); return m == nil or m.online ~= false end
	_G.UnitIsDeadOrGhost = function(unit) local m = Member(unit); return m ~= nil and m.dead == true end
	_G.UnitOnTaxi = function() return false end
	_G.UnitAffectingCombat = function() return Mock.world.combat == true end
	C_Map.GetBestMapForUnit = function(unit)
		local m = Member(unit)
		return (m and m.map) or Mock.world.mapID
	end
	NS.DetectDungeon = GR.savedDetect
end
function GR.Done()
	for name, fn in pairs(GR.saved) do _G[name] = fn end
	C_Map.GetBestMapForUnit = GR.savedMap
	NS.DetectDungeon = GR.savedDetect
	ResetWorld()
end
-- examen, l'écart entre deux bulles écoulé
function GR.Next()
	if NS.companionRT then NS.companionRT.lastAdvice = nil; NS.companionRT.cool = {} end
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	return NS:GroupEvaluate(Mock.now)
end
function GR.Party(...)
	local list = {}
	for index, spec in ipairs({ ... }) do
		list[index] = { name = spec[1], class = spec[2], level = spec[3] or 20 }
	end
	return list
end

-- 1. Composition -------------------------------------------------------------------------
do
	Say("-- groupe : composition")
	GR.Reset(GR.Party({ "Thrall", "WARRIOR" }, { "Jaina", "MAGE" }, { "Rexxar", "HUNTER" }))
	GR.Next()
	Mock.now = Mock.now + 5
	GR.Next()
	Check("[GRP] groupe qui se forme : on attend 10 s qu'il se stabilise", NS.companionBubbleKey == nil)
	Mock.now = Mock.now - 5
	Mock.now = Mock.now + NS.GROUP_STABLE + 1
	Check("[GRP] pas de soigneur : il le dit", GR.Next() and NS.companionBubbleKey == "GROUP_NO_HEALER")
	Check("[GRP] une seule fois pour ce groupe", not GR.Next())

	GR.Reset(GR.Party({ "Thrall", "WARRIOR" }, { "Anduin", "PRIEST" }, { "Rexxar", "HUNTER" }, { "Jaina", "MAGE" }))
	GR.Next()
	Mock.now = Mock.now + NS.GROUP_STABLE + 1
	Check("[GRP] groupe complet avec soigneur : bel équipage", GR.Next() and NS.companionBubbleKey == "GROUP_BALANCED")

	GR.Reset(GR.Party({ "Thrall", "WARRIOR" }))
	Mock.world.playerClass = "DRUID"
	GR.Next()
	Mock.now = Mock.now + NS.GROUP_STABLE + 1
	Check("[GRP] le soigneur, c'est toi (druide) : rien à redire", not GR.Next() and NS.companionBubbleKey == nil)

	GR.Reset(GR.Party({ "Thrall", "WARRIOR" }, { "Jaina", "MAGE" }))
	Mock.world.raid = true
	GR.Next()
	Mock.now = Mock.now + NS.GROUP_STABLE + 1
	Check("[GRP] en raid : rien", not GR.Next() and NS:GroupMembers() == nil)
end

-- 2. Donjon --------------------------------------------------------------------------------
do
	Say("-- groupe : donjon")
	local entry = NS.DUNGEONS.ragefire or select(2, next(NS.DUNGEONS))
	local low = NS:DungeonRange(entry)
	GR.Reset(GR.Party({ "Thrall", "WARRIOR", low + 2 }, { "Garrosh", "WARRIOR", low - 3 }, { "Anduin", "PRIEST", low }))
	NS:GroupState().said["roster:Anduin,Garrosh,Thrall"] = true
	NS.DetectDungeon = function() return entry, "entrance" end
	Check("[GRP] devant le donjon : le plus bas niveau signalé", GR.Next() and NS.companionBubbleKey == "GROUP_LOW_LEVEL"
		and NS.companionBubbleText:find("Garrosh", 1, true) and NS.companionBubbleText:find("3", 1, true), NS.companionBubbleText)
	Check("[GRP] une fois par donjon", not GR.Next())

	GR.Reset(GR.Party({ "Thrall", "WARRIOR", low + 2 }, { "Anduin", "PRIEST", low + 1 }))
	NS:GroupState().said["roster:Anduin,Thrall"] = true
	NS.DetectDungeon = function() return entry, "instance" end
	Check("[GRP] tout le monde dans la tranche : en route", GR.Next() and NS.companionBubbleKey == "GROUP_IN_RANGE")
end

-- 3. Resté en arrière, encore ailleurs ------------------------------------------------------
do
	Say("-- groupe : positions")
	GR.Reset(GR.Party({ "Thrall", "WARRIOR" }, { "Anduin", "PRIEST" }))
	NS:GroupState().said["roster:Anduin,Thrall"] = true
	Mock.world.party[1].visible = false
	GR.Next()
	Mock.now = Mock.now + 60
	Check("[GRP] hors de vue depuis 60 s : rien encore", not GR.Next())
	Mock.now = Mock.now + 40
	Check("[GRP] hors de vue depuis plus de 90 s : resté en arrière", GR.Next() and NS.companionBubbleKey == "GROUP_BEHIND"
		and NS.companionBubbleText:find("Thrall", 1, true))
	Check("[GRP] une fois par sortie", not GR.Next())

	GR.Reset(GR.Party({ "Thrall", "WARRIOR" }, { "Anduin", "PRIEST" }))
	NS:GroupState().said["roster:Anduin,Thrall"] = true
	Mock.world.party[1].visible = false
	Mock.world.combat = true
	GR.Next()
	Mock.now = Mock.now + 200
	Check("[GRP] en combat : rien", not GR.Next())

	GR.Reset(GR.Party({ "Thrall", "WARRIOR" }, { "Anduin", "PRIEST" }))
	NS:GroupState().said["roster:Anduin,Thrall"] = true
	Mock.world.subzone = "Goldshire"
	Mock.world.party[1].visible = false
	GR.Next()
	Mock.now = Mock.now + 200
	Check("[GRP] en lieu sûr : rien", not GR.Next())

	local entry = select(2, next(NS.DUNGEONS))
	GR.Reset(GR.Party({ "Thrall", "WARRIOR", 60 }, { "Anduin", "PRIEST", 60 }))
	NS:GroupState().said["roster:Anduin,Thrall"] = true
	NS:GroupState().said["dungeon:" .. tostring(entry.key)] = true
	NS.DetectDungeon = function() return entry, "entrance" end
	Mock.world.maps[1454] = { mapID = 1454, name = "Orgrimmar", parentMapID = 0 }
	Mock.world.party[1].map = 1454
	GR.Next()
	Mock.now = Mock.now + 130
	Check("[GRP] au donjon, un membre encore en ville : il le dit", GR.Next() and NS.companionBubbleKey == "GROUP_ELSEWHERE"
		and NS.companionBubbleText:find("Thrall", 1, true) and NS.companionBubbleText:find("Orgrimmar", 1, true),
		NS.companionBubbleText)
end

-- 4. Morts et déconnexions -----------------------------------------------------------------
do
	Say("-- groupe : morts")
	GR.Reset(GR.Party({ "Thrall", "WARRIOR" }, { "Anduin", "PRIEST" }))
	NS:GroupState().said["roster:Anduin,Thrall"] = true
	Mock.world.party[1].dead = true
	Check("[GRP] mort d'un membre", GR.Next() and NS.companionBubbleKey == "GROUP_DEAD"
		and NS.companionBubbleText:find("Thrall", 1, true))
	Check("[GRP] pas deux fois", not GR.Next())
	Mock.world.party[2].dead = true
	Check("[GRP] mort du soigneur : prudence", GR.Next() and NS.companionBubbleKey == "GROUP_HEALER_DEAD")
	Mock.world.party[1].dead, Mock.world.party[2].dead = false, false
	Mock.world.party[1].online = false
	Check("[GRP] déconnexion", GR.Next() and NS.companionBubbleKey == "GROUP_OFFLINE")

	GR.Reset(GR.Party({ "Thrall", "WARRIOR" }, { "Jaina", "MAGE" }), 2)
	NS:GroupState().said["roster:Jaina,Thrall"] = true
	Mock.world.party[1].dead = true
	GR.Next()
	Check("[GRP] cran Calme : les morts se taisent (réaction)", NS.companionBubbleKey == nil)
	GR.Reset(GR.Party({ "Thrall", "WARRIOR" }, { "Jaina", "MAGE" }), 2)
	GR.Next()
	Mock.now = Mock.now + NS.GROUP_STABLE + 1
	Check("[GRP] cran Calme : le conseil de composition passe", GR.Next() and NS.companionBubbleKey == "GROUP_NO_HEALER")

	local missing = {}
	for name, lines in pairs(NS.COMPANION_POOLS) do
		if name:find("^GROUP_") then
			for _, key in ipairs(lines) do
				if not (NS.COMPANION_LINE_STRINGS.fr[key] and NS.COMPANION_LINE_STRINGS.en[key]) then missing[#missing + 1] = key end
			end
		end
	end
	Check("[GRP] répliques en français et en anglais", #missing == 0, table.concat(missing, ", "))
	GR.Done()
end
