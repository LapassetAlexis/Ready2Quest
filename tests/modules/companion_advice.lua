-- Compagnon : conseils de route (Advice.lua). Pendant une sortie, hors d'un
-- lieu sûr : élite, vie basse, munitions, vivres, durabilité, sacs, quêtes
-- finies, foyer prêt ; une fois par sortie sauf si ça empire ; jamais en
-- combat ; seuils de Ready2Quest quand il est là ; réglette « Bavardage ».
local Check, Say, ResetWorld, NS, R2Q, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.NS, T.Mock

local A = { saved = {} }
for _, name in ipairs({ "UnitExists", "UnitCanAttack", "UnitClassification", "UnitGUID", "UnitIsDead", "UnitHealth",
	"UnitHealthMax", "UnitAffectingCombat", "UnitLevel", "UnitName" }) do A.saved[name] = rawget(_G, name) end

function A.Reset(level)
	ResetWorld()
	NS.companionRT, NS.companionSession, NS.adviceState, NS.adviceNextAt = nil, nil, nil, nil
	NS.companionLastBubble, NS.companionBubbleKey, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil, nil
	NS:CompanionData().tutoDone = true
	NS:DB().companionChatter = level or 3
	Mock.world.level = 20
	Mock.world.mapID, Mock.world.subzone = 20, "Clairière"   -- en pleine nature
	Mock.world.resting = false
	Mock.world.combat = nil
	Mock.world.units = {}
	Mock.world.health = { 100, 100 }
	Mock.world.durability = { [1] = { 100, 100 } }
	Mock.world.bags = { [0] = { size = 16, items = {} } }
	Mock.world.quests = {}
	Mock.world.cooldowns = {}
	Mock.world.classToken = nil
	Mock.world.ammo = nil
	-- de quoi manger : pas de conseil de vivres sauf si le test les retire
	Mock.world.itemInfo[4001] = { name = "Pain", classID = 0, subClassID = 5 }
	Mock.world.bags[0].items[16] = { itemID = 4001, stackCount = 20, quality = 1 }
	_G.UnitAffectingCombat = function() return Mock.world.combat == true end
	_G.UnitExists = function(unit) return Mock.world.units[unit] ~= nil or unit == "player" end
	_G.UnitCanAttack = function(_, unit) return Mock.world.units[unit] and Mock.world.units[unit].hostile end
	_G.UnitClassification = function(unit) return Mock.world.units[unit] and Mock.world.units[unit].class or "normal" end
	_G.UnitGUID = function(unit) return Mock.world.units[unit] and Mock.world.units[unit].guid end
	_G.UnitIsDead = function() return false end
	_G.UnitHealth = function() return Mock.world.health[1] end
	_G.UnitHealthMax = function() return Mock.world.health[2] end
	_G.UnitLevel = function(unit)
		if Mock.world.units[unit] then return Mock.world.units[unit].level end
		return Mock.world.level
	end
	_G.UnitName = function(unit) return Mock.world.units[unit] and Mock.world.units[unit].name or "Testeur" end
end
function A.Done()
	for name, fn in pairs(A.saved) do _G[name] = fn end
	ResetWorld()
end
-- nouvel examen, l'écart entre deux conseils écoulé
function A.Next()
	if NS.companionRT then NS.companionRT.lastAdvice = nil end
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	return NS:AdviceEvaluate()
end
function A.Fill(free)
	local items = Mock.world.bags[0].items
	for slot = 1, 15 do items[slot] = (slot <= 15 - free) and { itemID = 9000 + slot, stackCount = 1, quality = 1 } or nil end
end

-- 1. Chaque situation --------------------------------------------------------------------
do
	Say("-- conseils de route : situations")
	A.Reset()
	Check("[ADV] rien à signaler : silence", A.Next() == nil and NS.companionBubbleKey == nil)

	A.Fill(4)
	Check("[ADV] sacs au seuil de Ready2Quest (4) : conseil", A.Next() == "bags" and NS.companionBubbleKey == "ADVICE_BAGS")
	Check("[ADV] une fois par sortie", A.Next() == nil)
	A.Fill(1)
	Check("[ADV] qui empire (1 place) : de nouveau", A.Next() == "bags" and NS.companionBubbleKey == "ADVICE_BAGS_LAST")
	A.Fill(6)

	Mock.world.durability = { [1] = { 20, 100 } }
	Check("[ADV] équipement sous 25 % : conseil", A.Next() == "durability" and NS.companionBubbleKey == "ADVICE_DURA")
	Mock.world.durability = { [1] = { 5, 100 } }
	Check("[ADV] sous 10 % : de nouveau", A.Next() == "durability" and NS.companionBubbleKey == "ADVICE_DURA_CRIT")
	Mock.world.durability = { [1] = { 100, 100 } }

	Mock.world.bags[0].items[16] = { itemID = 4001, stackCount = 2, quality = 1 }
	Check("[ADV] vivres bas loin d'un lieu sûr", A.Next() == "food" and NS.companionBubbleKey == "ADVICE_FOOD")
	Mock.world.bags[0].items[16] = nil
	Check("[ADV] plus de vivres : de nouveau", A.Next() == "food" and NS.companionBubbleKey == "ADVICE_FOOD_EMPTY")
	Mock.world.bags[0].items[16] = { itemID = 4001, stackCount = 20, quality = 1 }

	Mock.world.quests = { { questID = 1, title = "Les loups", ready = true },
		{ questID = 2, title = "Les gnolls", ready = true } }
	local qr = A.Next(); local qt, qy = NS:QuestCounts()
	Check("[ADV] toutes les quêtes prêtes à rendre", qr == "quests" and NS.companionBubbleKey == "ADVICE_QUESTS", tostring(qr) .. " " .. tostring(qt) .. "/" .. tostring(qy))
	A.Reset()
	Mock.world.quests = { { questID = 1, title = "Les loups", ready = true }, { questID = 2, title = "Les gnolls" } }
	Check("[ADV] une quête pas finie : rien", A.Next() == nil)
	Mock.world.quests = {}

	A.Reset()
	Mock.world.classToken, Mock.world.ammo = "HUNTER", 400
	Check("[ADV] chasseur : munitions sous le minimum (600)", A.Next() == "ammo" and NS.companionBubbleKey == "ADVICE_AMMO")
	Mock.world.ammo = 100
	Check("[ADV] à sec : de nouveau", A.Next() == "ammo" and NS.companionBubbleKey == "ADVICE_AMMO_EMPTY")
	Mock.world.ammo = 0
	Mock.world.itemInfo[2512] = { name = "Flèche", classID = 6, subClassID = 2 }
	Mock.world.bags[0].items[1] = { itemID = 2512, stackCount = 200, quality = 1 }
	Check("[ADV] munitions dans le sac, pas équipées", A.Next() == "ammo" and NS.companionBubbleKey == "ADVICE_AMMO_UNEQUIPPED")

	A.Reset()
	Mock.world.health = { 20, 100 }
	A.Fill(1)
	Mock.world.combat = true
	Check("[ADV] en combat : rien, même sacs pleins", A.Next() == nil and NS.companionBubbleKey == nil)
	Mock.world.combat = nil
	A.Fill(6)
	NS.ADVICE_HANDLERS.PLAYER_REGEN_ENABLED()
	Check("[ADV] fin de combat, vie basse : on se pose", NS.companionBubbleKey == "ADVICE_HEALTH")

	A.Reset()
	Mock.world.units.target = { hostile = true, class = "elite", level = 23, guid = "G1", name = "Gnoll costaud" }
	Check("[ADV] élite 3 niveaux au-dessus : prévenu", NS:AdviceSeeUnit("target") == true
		and NS.companionBubbleKey == "ADVICE_ELITE" and NS.companionBubbleText:find("Gnoll costaud", 1, true))
	Check("[ADV] le même élite : pas deux fois", NS:AdviceSeeUnit("target") == false)
	Mock.world.units.target = { hostile = true, class = "elite", level = 21, guid = "G2", name = "Gnoll" }
	Check("[ADV] élite d'1 niveau au-dessus : rien", NS:AdviceSeeUnit("target") == false)
	Mock.world.units.target = { hostile = true, class = "normal", level = 30, guid = "G3", name = "Loup" }
	Check("[ADV] ennemi normal : rien", NS:AdviceSeeUnit("target") == false)
	Mock.world.units.target = { hostile = false, class = "elite", level = 30, guid = "G4", name = "Garde" }
	Check("[ADV] élite amical : rien", NS:AdviceSeeUnit("target") == false)
	Mock.world.units.mouseover = { hostile = true, class = "rare", level = -1, guid = "G5", name = "Mor'Ladim" }
	NS.companionRT.lastAdvice = nil
	NS.companionBubbleUntil = nil
	Check("[ADV] rare « ?? » au survol : prévenu", NS:AdviceSeeUnit("mouseover") == true and NS.companionBubbleKey == "ADVICE_RARE")
	Mock.world.instance = true
	Mock.world.units.target = { hostile = true, class = "elite", level = 40, guid = "G6", name = "Boss" }
	_G.IsInInstance = function() return Mock.world.instance == true end
	Check("[ADV] en donjon : rien (tout y est élite)", NS:AdviceSeeUnit("target") == false)
	_G.IsInInstance = nil
	Mock.world.instance = nil

	A.Reset()
	Mock.world.cooldowns[6948] = { Mock.now - 10, 60 }
	NS:AdviceEvaluate()
	Mock.world.cooldowns[6948] = nil
	A.Fill(2)
	NS.adviceState.said.bags = 2     -- les sacs déjà signalés : seul le foyer reste
	Check("[ADV] foyer rechargé en route, sacs pleins : on rentre ?", A.Next() == "hearth" and NS.companionBubbleKey == "ADVICE_HEARTH")
end

-- 2. Priorité, lieu sûr, réglette ----------------------------------------------------------
do
	Say("-- conseils de route : règles")
	A.Reset()
	A.Fill(1)
	Mock.world.durability = { [1] = { 5, 100 } }
	Mock.world.bags[0].items[16] = nil
	Check("[ADV] plusieurs soucis : les vivres d'abord", A.Next() == "food")
	Check("[ADV] … puis la durabilité, puis les sacs", A.Next() == "durability" and A.Next() == "bags")
	A.Fill(1)
	NS.adviceState.said = {}
	NS.companionRT.lastAdvice = Mock.now
	NS.companionLastBubble, NS.companionBubbleUntil = nil, nil
	Check("[ADV] écart entre deux conseils respecté", NS:AdviceEvaluate() == nil)

	A.Reset()
	A.Fill(1)
	Check("[ADV] sacs pleins dehors : dit", A.Next() == "bags")
	Mock.world.subzone = "Goldshire"
	Check("[ADV] en lieu sûr (celui de Ready2Quest) : rien", A.Next() == nil)
	Mock.world.subzone = "Clairière"
	Check("[ADV] de retour dehors : nouvelle sortie, il le redit", A.Next() == "bags")

	A.Reset(1)
	A.Fill(1)
	Mock.world.bags[0].items[16] = { itemID = 4001, stackCount = 2, quality = 1 }
	Check("[ADV] cran Discret : les sacs se taisent, les vivres non", A.Next() == "food"
		and NS.companionBubbleKey == "ADVICE_FOOD")
	Check("[ADV] cran Discret : rien d'autre ensuite", A.Next() == nil)
	A.Reset(0)
	A.Fill(1)
	Check("[ADV] cran Muet : rien", A.Next() == nil and NS.companionBubbleKey == nil)

	A.Reset()
	R2Q:DB().bagFreeThreshold = 6
	A.Fill(6)
	Check("[ADV] seuils de Ready2Quest suivis (sacs à 6)", NS:AdviceThresholds().bags == 6 and A.Next() == "bags")
	R2Q:DB().bagFreeThreshold = 4
	local saved = NS.r2qBridge
	NS.r2qBridge = nil
	Check("[ADV] sans Ready2Quest : seuils à lui (3 places, 4 vivres, 25 %)", NS:AdviceThresholds().bags == 3
		and NS:AdviceThresholds().food == 4 and NS:AdviceThresholds().durability == 25)
	Mock.world.subzone = "Goldshire"
	Mock.world.faction = "Alliance"
	_G.UnitFactionGroup = function() return "Alliance" end
	Check("[ADV] sans Ready2Quest : lieu sûr reconnu tout seul", NS:AdviceInSafePlace() == true)
	_G.UnitFactionGroup = nil
	NS.r2qBridge = saved
	local missing = {}
	for name, lines in pairs(NS.COMPANION_POOLS) do
		if name:find("^ADVICE_") then
			for _, key in ipairs(lines) do
				if not (NS.COMPANION_LINE_STRINGS.fr[key] and NS.COMPANION_LINE_STRINGS.en[key]) then missing[#missing + 1] = key end
			end
		end
	end
	Check("[ADV] répliques en français et en anglais", #missing == 0, table.concat(missing, ", "))
	A.Done()
end
