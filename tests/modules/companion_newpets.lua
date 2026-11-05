-- QuestCompanion 1.2.0 : neuf nouvelles créatures (six de coffre, une de la
-- carte d'auberge, une des missions, une des brillantes) et deux caractères
-- d'apparence (poulet Peureux, écureuil mécanique Bricoleur).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local NP = { saved = {} }
for _, name in ipairs({ "date", "UnitHealth", "UnitHealthMax", "UnitAffectingCombat" }) do NP.saved[name] = rawget(_G, name) end
function NP.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.personaState = nil, nil, nil
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:CompanionUpdateVisibility()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubbleKey = nil, nil, nil
end

-- 1. Catalogue --------------------------------------------------------------------------------
do
	Say("-- nouvelles créatures : catalogue")
	NP.Reset()
	local NEW = {
		cat_silver = { 5555, 1 }, toad = { 901, 1 }, cat_bombay = { 5556, 2 }, macaw_red = { 5207, 2 },
		panda = { 10990, 3 }, murloc = { 15369, 3 }, chicken = { 6193, 0 }, squirrel_mech = { 7937, 0 },
		hippogryph = { 16943, 0 },
	}
	local fr, en = NS.COMPANION_STRINGS.fr, NS.COMPANION_STRINGS.en
	for id, want in pairs(NEW) do
		local def = NS:CompanionAppearanceDef(id)
		Check("[PETS] " .. id .. " : modèle et palier vérifiés", def and def.display == want[1] and def.tier == want[2])
		Check("[PETS] " .. id .. " : nom fr et en", def and fr[def.label] and en[def.label])
	end
	Check("[PETS] 24 apparences", #NS.COMPANION_APPEARANCES == 24, #NS.COMPANION_APPEARANCES)
	-- dans les coffres : deux par palier
	local inChests = {}
	for _, reward in ipairs(NS:ChestRewards()) do inChests[reward.id] = reward.tier end
	Check("[PETS] six dans les coffres, deux par palier", inChests.cat_silver == 1 and inChests.toad == 1
		and inChests.cat_bombay == 2 and inChests.macaw_red == 2 and inChests.panda == 3 and inChests.murloc == 3)
	Check("[PETS] poulet, écureuil, hippogriffe : jamais au coffre", not inChests.chicken and not inChests.squirrel_mech
		and not inChests.hippogryph)
	Check("[PETS] verrouillés au départ", not NS:CompanionIsUnlocked("app", NS:CompanionAppearanceDef("chicken"))
		and not NS:CompanionIsUnlocked("app", NS:CompanionAppearanceDef("squirrel_mech")))
	Check("[PETS] conditions lisibles", NS:CompanionRequirement({ inn = 3 }) == "3 cartes d'auberge pleines"
		and NS:CompanionRequirement({ missions = 10 }) == "10 jours aux trois missions"
		and NS:CompanionRequirement({ shiny = 50 }) == "50 brillantes")
	local listed = {}
	for _, item in ipairs(NS:CompanionNextUnlocks()) do listed[item.id or ""] = true end
	Check("[PETS] pas d'objectif au compteur pour eux", not listed.chicken and not listed.squirrel_mech and not listed.hippogryph)
	-- dans la Collection : leur source
	local entry
	for _, e in ipairs(NS:JournalCollection("app")) do if e.def.id == "chicken" then entry = e end end
	Check("[PETS] Collection : le poulet et sa source", entry and not entry.owned
		and NS:JournalCosmeticSource(entry) == "3 cartes d'auberge pleines", entry and NS:JournalCosmeticSource(entry))
end

-- 2. Carte d'auberge : le poulet, missions : l'écureuil ------------------------------------------------
do
	Say("-- nouvelles créatures : auberge et missions")
	NP.Reset()
	local day = 0
	_G.date = function(format) if format == "%Y-%m-%d" then return "2026-12-" .. day end return "x" end
	local _, inn = NS:DailyData()
	for d = 1, 13 do day = d; NS:InnStamp() end
	Check("[PETS] 13 tampons : une carte pleine, pas encore le poulet", inn.full == 1
		and not NS:CompanionData().unlocked["app:chicken"])
	inn.full, inn.card = 2, 6
	day = 30
	NS:InnStamp()
	Check("[PETS] troisième carte pleine : le poulet", inn.full == 3 and NS:CompanionData().unlocked["app:chicken"] == true
		and Mock:Output():find("Poulet", 1, true), Mock:Output())
	Check("[PETS] une seule fois", NS:DailyGrantAppearance("chicken") == false)
	local daily = NS:DailyData()
	daily.day = NS:DailyToday()
	daily.perfect = 0
	daily.missions = { { kind = "pets", need = 1, have = 0, source = "trait" } }
	daily.allDone = nil
	NS:MissionEvent("pets", 1)
	Check("[PETS] premier jour aux trois missions : pas encore l'écureuil", daily.perfect == 1
		and not NS:CompanionData().unlocked["app:squirrel_mech"])
	daily.perfect = 9
	daily.missions = { { kind = "pets", need = 1, have = 0, source = "trait" } }
	daily.allDone = nil
	NS:MissionEvent("pets", 1)
	Check("[PETS] dixième jour aux trois missions : l'écureuil mécanique", daily.perfect == 10
		and NS:CompanionData().unlocked["app:squirrel_mech"] == true)
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	NS.journalFrame.sections.day:Click()
	local pane = NS.journalFrame.day
	Check("[PETS] onglet Jour : cartes pleines et le cadeau", pane.innTotal.text:find("cartes pleines : 3", 1, true)
		and pane.innGift.text:find("Poulet", 1, true), pane.innTotal.text)
	Check("[PETS] onglet Jour : jours aux trois missions", pane.perfect.text:find("10", 1, true)
		and pane.perfect.text:find("Écureuil mécanique", 1, true), pane.perfect.text)
	NS.journalFrame:Hide()
	_G.date = NP.saved.date
end

-- 3. Caractères : Peureux, Bricoleur -------------------------------------------------------------------
do
	Say("-- nouveaux caractères")
	NP.Reset()
	Check("[PETS] 14 caractères, les deux nouveaux d'apparence", #NS.PERSONALITY_ORDER == 14
		and NS.PERSONALITY_BY_APPEARANCE.chicken == "fearful" and NS.PERSONALITY_BY_APPEARANCE.squirrel_mech == "tinker")
	NS:CompanionData().appearance = "chicken"
	NS:DB().companionTraitSource = 1
	Check("[PETS] poulet : Peureux", NS:CompanionTrait() == "fearful" and NS:PersonaLabel("fearful") == "Peureux")
	NS:CompanionData().appearance = "squirrel_mech"
	Check("[PETS] écureuil mécanique : Bricoleur", NS:CompanionTrait() == "tinker" and NS:PersonaLabel("tinker") == "Bricoleur")
	-- leurs répliques : chaque réservoir des autres caractères, fr et en
	local lines, missing = NS.PERSONALITY_LINES, {}
	for _, trait in ipairs({ "fearful", "tinker" }) do
		for pool in pairs(lines.mischievous) do
			if not (lines[trait] and lines[trait][pool] and #lines[trait][pool] > 0) then missing[#missing + 1] = trait .. ":" .. pool end
		end
		Check("[PETS] " .. trait .. " : sa description", NS.L["TRAIT_DESC_" .. trait] ~= "TRAIT_DESC_" .. trait)
		Check("[PETS] " .. trait .. " : sa mission du jour", NS.DAILY_TRAIT_MISSIONS[trait] ~= nil)
	end
	Check("[PETS] répliques complètes", #missing == 0, table.concat(missing, ", "))
	-- leurs remarques
	local state = NS:PersonaState()
	NS:CompanionData().appearance = "chicken"
	local w = { health = 40, combat = true }
	_G.UnitHealth = function() return w.health end
	_G.UnitHealthMax = function() return 100 end
	_G.UnitAffectingCombat = function() return w.combat end
	NS.companionBubbleUntil, NS.companionLastBubble = nil, nil
	Check("[PETS] Peureux : un combat qui tape fort, il le dit", NS:PersonaTickNotice(Mock.now, state) == true
		and NS.companionBubbleKey == "NOTICE__fearful", NS.companionBubbleKey)
	NS.companionBubbleUntil, NS.companionLastBubble = nil, nil
	state.noticeAt = nil
	Check("[PETS] … une seule fois par combat", NS:PersonaTickNotice(Mock.now + 2000, state) == false)
	w.combat = false
	NS:PersonaTickNotice(Mock.now + 2001, state)
	Check("[PETS] … de nouveau au combat suivant", state.scared == nil)
	NS:CompanionData().appearance = "squirrel_mech"
	state.tinkerAt, state.noticeAt = Mock.now + 5000, nil
	Check("[PETS] Bricoleur : pas avant 20 min", NS:PersonaTickNotice(Mock.now + 5000 + 600, state) == false)
	state.tinkerAt = Mock.now - 1300
	NS.companionBubbleUntil, NS.companionLastBubble = nil, nil
	state.noticeAt = nil
	local said = NS:PersonaTickNotice(Mock.now + 5000, state)
	Check("[PETS] Bricoleur : une idée toutes les 20 min", said == true and NS.companionBubbleKey == "NOTICE__tinker",
		tostring(NS.companionBubbleKey))
	for _, name in ipairs({ "UnitHealth", "UnitHealthMax", "UnitAffectingCombat" }) do _G[name] = NP.saved[name] end
end

ResetWorld()
