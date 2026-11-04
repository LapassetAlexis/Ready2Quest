-- Compagnon : chaque envie reste simple à remonter, même tout exploré.
-- Curiosité renouvelable (zone pas vue depuis 2 h, bouger, donjon, élite ou
-- rare vaincu, vol, coffre, récolte) ; plancher serein (50 %) une fois toutes
-- ses évolutions faites ; infobulle du carnet à jour.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local NE = { saved = {} }
for _, name in ipairs({ "UnitIsDead", "UnitClassification", "UnitOnTaxi", "IsInInstance" }) do NE.saved[name] = rawget(_G, name) end
function NE.Reset()
	ResetWorld()
	NS.companionRT, NS.companionSession = nil, nil
	NS:CompanionData().tutoDone = true
	Mock.world.level = 20
	Mock.world.maps[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 0 }
	Mock.world.mapID, Mock.world.subzone = 1429, "Clairière"
	Mock.world.target, Mock.world.taxi, Mock.world.instance = nil, false, false
	_G.UnitIsDead = function(unit) return unit == "target" and Mock.world.target and Mock.world.target.dead end
	_G.UnitClassification = function(unit) return unit == "target" and Mock.world.target and Mock.world.target.class or "normal" end
	_G.UnitOnTaxi = function() return Mock.world.taxi end
	_G.IsInInstance = function() return Mock.world.instance end
	NE.Set(30)
end
function NE.Set(value) NS:CompanionData().needs.curiosity = value end
function NE.Get() return NS:CompanionData().needs.curiosity end
function NE.Done()
	for name, fn in pairs(NE.saved) do _G[name] = fn end
	ResetWorld()
end
local CU = NS.COMPANION_CURIOSITY

do
	Say("-- envies : curiosité renouvelable")
	NE.Reset()
	local data = NS:CompanionData()
	data.seenZones[1429], data.zoneVisit = true, { [1429] = Mock.now - 3600 }
	NS:CompanionOnZone(true)
	Check("[NEED] zone déjà vue il y a 1 h : rien", NE.Get() == 30)
	data.zoneVisit[1429] = Mock.now - 3 * 3600
	NE.Set(30)
	NS:CompanionOnZone(true)
	Check("[NEED] zone pas vue depuis 3 h : curiosité (+8)", NE.Get() == 30 + CU.revisit and CU.revisit == 8, NE.Get())

	NE.Reset()
	local seen = NS:CompanionData().seenSub
	seen["1429:Clairière"], seen["1429:Bosquet"] = true, true
	NS:CompanionOnZone(false)
	Mock.world.subzone = "Bosquet"
	NS:CompanionOnZone(false)
	Check("[NEED] bouger d'une sous-zone connue à l'autre : un peu (+1)", NE.Get() == 30 + CU.subzone, NE.Get())
	Mock.world.subzone = "Clairière"
	NS:CompanionOnZone(false)
	Check("[NEED] pas plus d'une fois toutes les 30 s", NE.Get() == 30 + CU.subzone, NE.Get())
	Mock.now = Mock.now + 31
	Mock.world.subzone = "Bosquet"
	NS:CompanionOnZone(false)
	Check("[NEED] … puis de nouveau", NE.Get() == 30 + 2 * CU.subzone, NE.Get())

	NE.Reset()
	NS:CompanionData().seenZones[1429] = true
	NS:CompanionData().zoneVisit = { [1429] = Mock.now }
	Mock.world.instance = true
	NS:CompanionOnZone(true)
	Check("[NEED] entrée en donjon : +10, à chaque fois", NE.Get() == 30 + CU.dungeon, NE.Get())
	NS:CompanionOnZone(true)
	Check("[NEED] allers-retours de la porte : pas de doublon", NE.Get() == 30 + CU.dungeon, NE.Get())
	Mock.now = Mock.now + CU.dungeonGap + 1
	NS:CompanionOnZone(true)
	Check("[NEED] nouvelle entrée plus tard : de nouveau", NE.Get() == 30 + 2 * CU.dungeon, NE.Get())

	NE.Reset()
	Mock.world.target = { dead = true, class = "elite" }
	NS:CompanionOnKill()
	Check("[NEED] élite vaincu : +8, à chaque fois", NE.Get() == 30 + CU.elite, NE.Get())
	Mock.now = Mock.now + 5
	Mock.world.target = { dead = true, class = "normal" }
	NS:CompanionOnKill()
	Check("[NEED] ennemi ordinaire : la curiosité ne bouge pas", NE.Get() == 30 + CU.elite)

	NE.Reset()
	Mock.world.taxi = true
	NS:CompanionTick(10)
	local before = NE.Get()
	Mock.world.taxi = false
	NS:CompanionTick(10)
	Check("[NEED] arrivée en griffon : +5", NE.Get() > before + CU.flight - 1, NE.Get() - before)

	NE.Reset()
	local itemID = next(NS.GATHERING_ITEMS)
	NS:GatheringRecord(itemID, 1, 1429)
	Check("[NEED] chaque ressource récoltée : +1", NE.Get() == 30 + CU.gather, NE.Get())

	NE.Reset()
	NS:ChestData()[9001] = { tier = 1, name = "Vallon", at = 0 }
	local reward
	for _, r in ipairs(NS:ChestOptions(1)) do reward = reward or r end
	Check("[NEED] coffre ouvert : +20", reward and NS:ChestPick(9001, reward) == true and NE.Get() == 30 + CU.chest, NE.Get())
	NS:ChestData()[9001] = nil
end

do
	Say("-- envies : plancher serein")
	NE.Reset()
	local data = NS:CompanionData()
	data.stage = 1
	for key in pairs(data.needs) do data.needs[key] = 40 end
	NS:CompanionTick(3600 * 3)
	Check("[NEED] en route vers l'évolution : le plancher reste bas (15)", data.needs.curiosity == 15, data.needs.curiosity)
	data.stage = #NS.COMPANION_STAGES
	for key in pairs(data.needs) do data.needs[key] = 40 end
	NS:CompanionTick(3600 * 3)
	local serene = true
	for _, value in pairs(data.needs) do serene = serene and value >= 50 end
	Check("[NEED] toutes ses évolutions faites : rien sous 50 %", serene and NS.COMPANION_SERENE_FLOOR == 50)

	local lines = table.concat(NS:NeedTooltipLines("curiosity"), " | ")
	Check("[NEED] infobulle : même tout exploré, quoi faire", lines:find(NS.L.JRN_NEED_curiosity_3, 1, true)
		and lines:find("50 %", 1, true), lines)
	data.stage = 1
	local early = table.concat(NS:NeedTooltipLines("curiosity"), " | ")
	Check("[NEED] infobulle : pas de plancher serein avant la fin", not early:find("ne descend plus", 1, true))
	Check("[NEED] textes en français et en anglais", NS.JOURNAL_WINDOW_STRINGS.en.JRN_NEED_curiosity_3 ~= nil
		and NS.JOURNAL_WINDOW_STRINGS.en.JRN_NEED_TIP_SERENE ~= nil)
	NE.Done()
end
