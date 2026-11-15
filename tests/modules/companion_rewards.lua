-- Compagnon : ce qu'il gagne.
-- 1. Évolution par le bonheur (le niveau ouvre, quatre envies à 70 % font
--    franchir), objectifs « action + récompense », coffres de zone (palier,
--    choix d'un objet, zone dorée, /r2q coffre).
-- 2. QC 1.2.0 : neuf créatures (coffres, carte d'auberge, missions) et deux
--    caractères d'apparence (Peureux, Bricoleur).
-- 3. Cosmétiques du coffre : catalogue, récompenses par palier, cadres et fonds
--    posés (et leurs replis), ornements, choix dans les réglages.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- Un scénario = une assertion ; chaque étape en défaut est nommée dans le message.
local function Scenario(name)
	local bad = {}
	return {
		ok = function(label, cond, extra)
			if not cond then bad[#bad + 1] = label .. (extra ~= nil and (" [" .. tostring(extra) .. "]") or "") end
			return cond
		end,
		done = function() Check(name, #bad == 0, table.concat(bad, " ; ")) end,
	}
end

-- 1. Évolution, objectifs, coffres de zone ========================================================
local H = { savedRewards = rawget(NS, "COMPANION_REWARDS"), savedCounts = rawget(NS, "JournalCounts") }

local MAPS = {
	[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 },
	[947]  = { mapID = 947,  name = "Azeroth", parentMapID = 0, mapType = 1 },
	[1411] = { mapID = 1411, name = "Durotar", parentMapID = 1414, mapType = 3 },
	[1446] = { mapID = 1446, name = "Tanaris", parentMapID = 1414, mapType = 3 },
	[8888] = { mapID = 8888, name = "Terre inconnue", parentMapID = 1414, mapType = 3 },
	[9001] = { mapID = 9001, name = "Vallon bas", parentMapID = 1414, mapType = 3 },
	[9003] = { mapID = 9003, name = "Cime haute", parentMapID = 1414, mapType = 3 },
	[9004] = { mapID = 9004, name = "Plaine coupée", parentMapID = 1414, mapType = 3 },
}

NS.ZONE_LEVELS[9001], NS.ZONE_LEVELS[9003], NS.ZONE_LEVELS[9004] = { 5, 12 }, { 45, 55 }, { 5, 12 }

function H.Reset(level)
	ResetWorld()
	NS.companionSession = nil
	for id, info in pairs(MAPS) do Mock.world.maps[id] = info end
	Mock.world.mapID = 8888
	Mock.world.level = level or 15
	NS.JournalCounts = H.savedCounts
	if NS.chestFrame then NS.chestFrame:Hide() end
	if NS.journalTracker then NS.journalTracker:Hide() end
	NS.journalTracker = nil
	NS.journalGroups, NS.journalGroupsFor = nil, nil
	Mock:Reset()
end

function H.SetNeeds(value)
	local needs = NS:CompanionData().needs
	for key in pairs(needs) do needs[key] = value end
end

-- Parts factices : deux parts, pleines ou non, pour la zone voulue
H.full = {}
H.parts = {
	{ id = "test_a", label = "Partie A", Compute = function(_, zoneID)
		if not H.full[zoneID] then return nil end
		return { have = H.full[zoneID], need = 4, hint = { "  · reste A" } }
	end },
	{ id = "test_b", label = "Partie B", Compute = function(_, zoneID)
		if not H.full[zoneID] then return nil end
		return { have = 2, need = 2 }
	end },
}
function H.Install()
	for _, part in ipairs(H.parts) do NS.RegisterZonePart(part) end
	NS.COMPANION_REWARDS = {
		{ kind = "app", id = "frog",   label = "COMP_APP_FROG",   tier = 1 },
		{ kind = "orn", id = "ribbon", label = "COMP_ORN_RIBBON", tier = 1 },
		{ kind = "app", id = "owl",    label = "COMP_APP_OWL",    tier = 3 },
	}
end
function H.Uninstall()
	for index = #NS.ZONE_PARTS, 1, -1 do
		local part = NS.ZONE_PARTS[index]
		if part == H.parts[1] or part == H.parts[2] then table.remove(NS.ZONE_PARTS, index) end
	end
	NS.COMPANION_REWARDS = H.savedRewards
end
function H.Find(prefix)
	for _, goal in ipairs(NS:JournalObjectives()) do
		if goal.id:sub(1, #prefix) == prefix then return goal end
	end
end

-- 1. Évolution : le niveau ouvre, le bonheur franchit -------------------------------
do
	Say("-- compagnon : évolution par le bonheur")
	local S = Scenario("[EVO] évolution par le bonheur")
	H.Reset(9)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	local data = NS:CompanionData()
	S.ok("premier relevé : stade posé sans attente", data.stage == 1 and data.stageReady == nil, tostring(data.stage) .. "/" .. tostring(data.stageReady) .. " lvl " .. tostring(Mock.world.level))
	H.SetNeeds(40)
	Mock.world.level = 10
	Mock:Fire("PLAYER_LEVEL_UP", 10)
	S.ok("niveau 10 atteint, envies basses : prêt, pas encore évolué", data.stage == 1 and data.stageReady == 2,
		tostring(data.stage) .. "/" .. tostring(data.stageReady))
	S.ok("annoncé : prêt à devenir…, et comment", Mock:Output():find("est prêt à devenir", 1, true) ~= nil, Mock:Output())
	S.ok("heureux = 4 envies à 70 %", NS.COMPANION_HAPPY_MIN == 70 and not NS:CompanionIsHappy())
	local unlocks = NS:CompanionNextUnlocks()
	local ready
	for _, item in ipairs(unlocks) do if item.kind == "stage" then ready = item end end
	S.ok("contrat : stade prêt, stat « happy »", ready and ready.stat == "happy" and ready.ready == true
		and ready.need == 4 and ready.have < 4, ready and ready.stat)
	local hints = table.concat(NS:CompanionHappyHints(), " | ")
	S.ok("survol : chaque envie et comment la remplir", hints:find("Faim : 40 %", 1, true)
		and hints:find("mange ou bois", 1, true) and hints:find("Curiosité", 1, true), hints)
	-- objectif : l'action, le stade en récompense
	local goal = H.Find("comp:stage")
	S.ok("objectif « Rends … heureux pour évoluer » en tête", goal and goal.label:find("heureux pour évoluer", 1, true)
		and goal.ratio > 1 and goal.rewards and goal.rewards[1]:find("devient", 1, true), goal and goal.label)
	-- trois envies comblées : toujours prêt
	local needs = data.needs
	needs.hunger, needs.energy, needs.mood = 90, 90, 90
	NS:CompanionAdd("mood", 1)
	S.done()
	S = Scenario("[EVO] évolue quand les quatre envies sont comblées ; jamais en arrière ; somnolent pas heureux")
	S.ok("trois envies sur quatre : attend encore", data.stage == 1 and data.stageReady == 2)
	-- la dernière : évolution
	NS:CompanionAdd("curiosity", 40)
	S.ok("quatrième envie comblée : évolution", data.stage == 2 and data.stageReady == nil)
	S.ok("évolution annoncée", Mock:Output():find("devient", 1, true) ~= nil)
	-- une envie qui baisse ne fait jamais régresser
	NS:CompanionAdd("hunger", -80)
	S.ok("jamais de retour en arrière", data.stage == 2)
	-- heureux au moment du niveau : évolution directe
	H.SetNeeds(85)
	Mock.world.level = 20
	Mock:Fire("PLAYER_LEVEL_UP", 20)
	S.ok("heureux au palier : évolue tout de suite", data.stage == 3 and data.stageReady == nil, data.stage)
	-- somnolent (longue absence) : pas heureux
	H.SetNeeds(85)
	data.sleepy = true
	S.ok("somnolent : pas heureux", not NS:CompanionIsHappy())
	data.sleepy = nil
	S.done()
end

-- 2. Objectifs : une action, ses récompenses ----------------------------------------
do
	Say("-- objectifs : action et récompenses")
	local S = Scenario("[RWD] objectifs : action et récompenses")
	H.Reset(15)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	local level = H.Find("level:20")
	S.ok("palier : « Atteins le niveau 20 »", level and level.label == "Atteins le niveau 20", level and level.label)
	S.ok("stade fusionné dans le palier (une seule ligne)", H.Find("comp:stage") == nil)
	local rewards = level and table.concat(level.rewards or {}, " | ") or ""
	S.ok("récompenses : le stade puis le tampon", rewards:find("devient Aguerri", 1, true)
		and rewards:find("Palier 20", 1, true) and rewards:find("devient", 1, true) < rewards:find("Palier", 1, true), rewards)
	NS:RefreshJournalTracker()
	local tracker = NS.journalTracker
	local line
	for _, l in ipairs(tracker and tracker.lines or {}) do if l.goal and l.goal.id == "level:20" then line = l end end
	if line then
		line:GetScript("OnEnter")(line)
		local text = table.concat(_G.GameTooltip.lines or {}, " | ")
		S.ok("survol : ligne « Récompense : … »", text:find("Récompense : ", 1, true) ~= nil, text)
		line:GetScript("OnLeave")(line)
	else
		S.ok("palier affiché dans le suivi", false)
	end
	S.done()
end

-- 3. Coffres de zone -----------------------------------------------------------------
do
	Say("-- coffres de zone")
	local S = Scenario("[CHEST] coffres de zone")
	S.ok("fichier chargé", NS.Loaded and NS.Loaded.CompanionChest == true)
	S.ok("palier des zones : Durotar 1, Tanaris 3, inconnue = niveau du joueur", NS:ZoneTier(1411) == 1
		and NS:ZoneTier(1446) == 3)
	H.Reset(25)
	S.ok("zone inconnue au niveau 25 : palier 2", NS:ZoneTier(8888) == 2)
	H.Reset(12)
	H.Install()
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	H.full[8888] = 3
	NS:RefreshJournalTracker()
	S.ok("zone à 87 % : pas de coffre", NS:ChestData()[8888] == nil)
	local zone = H.Find("zone:8888")
	S.ok("complétion : la récompense est annoncée", zone and zone.reward == "un objet au choix (palier 1)",
		zone and zone.reward)
	H.full[8888] = 4
	NS:RefreshJournalTracker()
	local chest = NS:ChestData()[8888]
	S.ok("zone à 100 % : coffre posé, palier de la zone", chest and chest.tier == 1 and not chest.opened)
	S.ok("annoncé dans le chat", Mock:Output():find("Terre inconnue terminée à 100 %", 1, true) ~= nil, Mock:Output())
	local goal = H.Find("chest:8888")
	S.ok("objectif « Ouvre le coffre de … » en tête", goal and goal.label == "Ouvre le coffre de Terre inconnue"
		and NS:JournalObjectives()[1].id == "chest:8888", goal and goal.label)
	S.ok("la complétion finie disparaît des objectifs", H.Find("zone:8888") == nil)
	-- un deuxième passage ne repose pas de coffre
	Mock:Reset()
	NS:RefreshJournalTracker()
	S.ok("un seul coffre par zone", not Mock:Output():find("terminée", 1, true))
	-- options : le palier, sans ce qui est déjà à toi
	local options = NS:ChestOptions(1)
	S.done()
	S = Scenario("[CHEST] ouverture : options du palier, clic sur l'objectif, choix unique")
	S.ok("options : les objets du palier 1", #options == 2)
	NS:CompanionData().unlocked["orn:ribbon"] = true
	options = NS:ChestOptions(1)
	S.ok("options : un objet possédé n'est plus proposé", #options == 1 and options[1].id == "frog")
	NS:CompanionData().unlocked["orn:ribbon"] = nil
	-- ouverture : clic sur l'objectif du suivi
	NS:RefreshJournalTracker()
	local tracker = NS.journalTracker
	tracker.lines[1]:Click("LeftButton")
	local frame = NS.chestFrame
	S.ok("clic sur l'objectif : coffre ouvert", frame and frame:IsShown() and frame.zoneID == 8888)
	S.ok("fenêtre exclusive", (function()
		for _, field in ipairs(NS.EXCLUSIVE_WINDOWS) do if field == "chestFrame" then return true end end
	end)() == true)
	local buttons = {}
	for _, button in ipairs(frame.options) do
		if button:IsShown() then buttons[#buttons + 1] = button.kindTag.label.text .. " " .. button.text.text end
	end
	S.ok("un bouton par objet, avec sa catégorie", #buttons == 2 and table.concat(buttons, "|"):find("APPARENCE Rainette", 1, true)
		and table.concat(buttons, "|"):find("ORNEMENT", 1, true), table.concat(buttons, "|"))
	-- refuser un objet d'un autre palier
	S.ok("objet d'un autre palier refusé", NS:ChestPick(8888, NS.COMPANION_REWARDS[3]) == false)
	-- choisir la rainette
	local frogButton
	for _, button in ipairs(frame.options) do if button.reward and button.reward.id == "frog" then frogButton = button end end
	frogButton:Click()
	S.ok("choix : objet débloqué, coffre ouvert", NS:CompanionData().unlocked["app:frog"] == true
		and NS:ChestData()[8888].opened == true and NS:ChestData()[8888].reward == "app:frog")
	S.ok("apparence choisie : portée tout de suite", NS:CompanionData().appearance == "frog")
	S.ok("fenêtre refermée, objectif disparu", not frame:IsShown() and H.Find("chest:") == nil)
	S.ok("second choix impossible", NS:ChestPick(8888, NS.COMPANION_REWARDS[2]) == false)
	-- /r2q coffre sans coffre
	Mock:Reset()
	NS:HandleCommand("coffre")
	S.done()
	S = Scenario("[CHEST] /r2q coffre, zone dorée, module coupé, hors compteur, textes")
	S.ok("/r2q coffre sans coffre : message", Mock:Output():find("Aucun coffre", 1, true) ~= nil, Mock:Output())
	-- palier épuisé : zone dorée
	NS:CompanionData().unlocked["orn:ribbon"] = true
	H.full[9001] = 4
	Mock.world.mapID = 9001
	Mock:Reset()
	NS:RefreshJournalTracker()
	local golden = NS:ChestData()[9001]
	S.ok("palier épuisé : zone dorée, rien à ouvrir", golden and golden.golden == true and golden.opened == true
		and Mock:Output():find("dorée", 1, true) ~= nil, Mock:Output())
	-- palier 3 par /r2q coffre
	H.full[9003] = 4
	Mock.world.mapID = 9003
	NS:RefreshJournalTracker()
	NS:HandleCommand("coffre")
	S.ok("/r2q coffre : ouvre le coffre en attente", NS.chestFrame:IsShown() and NS.chestFrame.zoneID == 9003)
	NS.chestFrame:Hide()
	-- module coupé : pas de coffre
	H.full[9004] = 4
	Mock.world.mapID = 9004
	NS:DB().companionEnabled = false
	NS:ChestCheck(9004)
	S.ok("module coupé : pas de coffre", NS:ChestData()[9004] == nil)
	NS:DB().companionEnabled = true
	-- une seule part : pas de coffre (le bestiaire ou la récolte doivent compter)
	H.full = {}
	S.ok("cosmétique à palier : hors des déblocages par compteur", (function()
		local def = NS.COMPANION_APPEARANCES[2]
		local saved = def.tier
		def.tier = 1
		local found = false
		for _, item in ipairs(NS:CompanionNextUnlocks()) do if item.id == def.id then found = true end end
		def.tier = saved
		return not found
	end)())
	H.Uninstall()
	S.ok("chaînes fr/en", (function()
		for key in pairs(NS.CHEST_STRINGS.fr) do if not NS.CHEST_STRINGS.en[key] then return false end end
		return true
	end)())
	S.done()
end

-- 2. Nouvelles créatures et caractères (1.2.0) ====================================================
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
	local S = Scenario("[PETS] catalogue")
	NP.Reset()
	local NEW = {
		cat_silver = { 5555, 1 }, toad = { 901, 1 }, cat_bombay = { 5556, 2 }, macaw_red = { 5207, 2 },
		panda = { 10990, 3 }, murloc = { 15369, 3 }, chicken = { 6193, 0 }, squirrel_mech = { 7937, 0 },
		hippogryph = { 16943, 0 },
	}
	for id, want in pairs(NEW) do
		local def = NS:CompanionAppearanceDef(id)
		S.ok(id .. " : modèle et palier vérifiés", def and def.display == want[1] and def.tier == want[2])
	end
	S.ok("24 apparences", #NS.COMPANION_APPEARANCES == 24, #NS.COMPANION_APPEARANCES)
	-- dans les coffres : deux par palier
	local inChests = {}
	for _, reward in ipairs(NS:ChestRewards()) do inChests[reward.id] = reward.tier end
	S.ok("six dans les coffres, deux par palier", inChests.cat_silver == 1 and inChests.toad == 1
		and inChests.cat_bombay == 2 and inChests.macaw_red == 2 and inChests.panda == 3 and inChests.murloc == 3)
	S.ok("poulet, écureuil, hippogriffe : jamais au coffre", not inChests.chicken and not inChests.squirrel_mech
		and not inChests.hippogryph)
	S.ok("verrouillés au départ", not NS:CompanionIsUnlocked("app", NS:CompanionAppearanceDef("chicken"))
		and not NS:CompanionIsUnlocked("app", NS:CompanionAppearanceDef("squirrel_mech")))
	S.ok("conditions lisibles", NS:CompanionRequirement({ inn = 3 }) == "3 cartes d'auberge pleines"
		and NS:CompanionRequirement({ missions = 10 }) == "10 jours aux trois missions"
		and NS:CompanionRequirement({ shiny = 50 }) == "50 brillantes")
	local listed = {}
	for _, item in ipairs(NS:CompanionNextUnlocks()) do listed[item.id or ""] = true end
	S.ok("pas d'objectif au compteur pour eux", not listed.chicken and not listed.squirrel_mech and not listed.hippogryph)
	S.done()
end

-- 2. Carte d'auberge : le poulet, missions : l'écureuil ------------------------------------------------
do
	Say("-- nouvelles créatures : auberge et missions")
	local S = Scenario("[PETS] auberge et missions")
	NP.Reset()
	local day = 0
	_G.date = function(format) if format == "%Y-%m-%d" then return "2026-12-" .. day end return "x" end
	local _, inn = NS:DailyData()
	for d = 1, 13 do day = d; NS:InnStamp() end
	S.ok("13 tampons : une carte pleine, pas encore le poulet", inn.full == 1
		and not NS:CompanionData().unlocked["app:chicken"])
	inn.full, inn.card = 2, 6
	day = 30
	NS:InnStamp()
	S.ok("troisième carte pleine : le poulet", inn.full == 3 and NS:CompanionData().unlocked["app:chicken"] == true
		and Mock:Output():find("Poulet", 1, true), Mock:Output())
	S.ok("une seule fois", NS:DailyGrantAppearance("chicken") == false)
	local daily = NS:DailyData()
	daily.day = NS:DailyToday()
	daily.perfect = 0
	daily.missions = { { kind = "pets", need = 1, have = 0, source = "trait" } }
	daily.allDone = nil
	NS:MissionEvent("pets", 1)
	S.ok("premier jour aux trois missions : pas encore l'écureuil", daily.perfect == 1
		and not NS:CompanionData().unlocked["app:squirrel_mech"])
	daily.perfect = 9
	daily.missions = { { kind = "pets", need = 1, have = 0, source = "trait" } }
	daily.allDone = nil
	NS:MissionEvent("pets", 1)
	S.ok("dixième jour aux trois missions : l'écureuil mécanique", daily.perfect == 10
		and NS:CompanionData().unlocked["app:squirrel_mech"] == true)
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	NS.journalFrame.sections.day:Click()
	local pane = NS.journalFrame.day
	S.ok("onglet Jour : cartes pleines et le cadeau", pane.innTotal.text:find("cartes pleines : 3", 1, true)
		and pane.innGift.text:find("Poulet", 1, true), pane.innTotal.text)
	S.ok("onglet Jour : jours aux trois missions", pane.perfect.text:find("10", 1, true)
		and pane.perfect.text:find("Écureuil mécanique", 1, true), pane.perfect.text)
	NS.journalFrame:Hide()
	_G.date = NP.saved.date
	S.done()
end

-- 3. Caractères : Peureux, Bricoleur -------------------------------------------------------------------
do
	Say("-- nouveaux caractères")
	local S = Scenario("[PETS] nouveaux caractères")
	NP.Reset()
	S.ok("14 caractères, les deux nouveaux d'apparence", #NS.PERSONALITY_ORDER == 14
		and NS.PERSONALITY_BY_APPEARANCE.chicken == "fearful" and NS.PERSONALITY_BY_APPEARANCE.squirrel_mech == "tinker")
	NS:CompanionData().appearance = "chicken"
	NS:DB().companionTraitSource = 1
	S.ok("poulet : Peureux", NS:CompanionTrait() == "fearful" and NS:PersonaLabel("fearful") == "Peureux")
	NS:CompanionData().appearance = "squirrel_mech"
	S.ok("écureuil mécanique : Bricoleur", NS:CompanionTrait() == "tinker" and NS:PersonaLabel("tinker") == "Bricoleur")
	-- leurs répliques : chaque réservoir des autres caractères, fr et en
	local lines, missing = NS.PERSONALITY_LINES, {}
	for _, trait in ipairs({ "fearful", "tinker" }) do
		for pool in pairs(lines.mischievous) do
			if not (lines[trait] and lines[trait][pool] and #lines[trait][pool] > 0) then missing[#missing + 1] = trait .. ":" .. pool end
		end
		S.ok("" .. trait .. " : sa description", NS.L["TRAIT_DESC_" .. trait] ~= "TRAIT_DESC_" .. trait)
		S.ok("" .. trait .. " : sa mission du jour", NS.DAILY_TRAIT_MISSIONS[trait] ~= nil)
	end
	S.ok("répliques complètes", #missing == 0, table.concat(missing, ", "))
	-- leurs remarques
	local state = NS:PersonaState()
	NS:CompanionData().appearance = "chicken"
	local w = { health = 40, combat = true }
	_G.UnitHealth = function() return w.health end
	_G.UnitHealthMax = function() return 100 end
	_G.UnitAffectingCombat = function() return w.combat end
	NS.companionBubbleUntil, NS.companionLastBubble = nil, nil
	S.done()
	S = Scenario("[PETS] remarques : Peureux une fois par combat, Bricoleur toutes les 20 min")
	S.ok("Peureux : un combat qui tape fort, il le dit", NS:PersonaTickNotice(Mock.now, state) == true
		and NS.companionBubbleKey == "NOTICE__fearful", NS.companionBubbleKey)
	NS.companionBubbleUntil, NS.companionLastBubble = nil, nil
	state.noticeAt = nil
	S.ok("… une seule fois par combat", NS:PersonaTickNotice(Mock.now + 2000, state) == false)
	w.combat = false
	NS:PersonaTickNotice(Mock.now + 2001, state)
	S.ok("… de nouveau au combat suivant", state.scared == nil)
	NS:CompanionData().appearance = "squirrel_mech"
	state.tinkerAt, state.noticeAt = Mock.now + 5000, nil
	S.ok("Bricoleur : pas avant 20 min", NS:PersonaTickNotice(Mock.now + 5000 + 600, state) == false)
	state.tinkerAt = Mock.now - 1300
	NS.companionBubbleUntil, NS.companionLastBubble = nil, nil
	state.noticeAt = nil
	local said = NS:PersonaTickNotice(Mock.now + 5000, state)
	S.ok("Bricoleur : une idée toutes les 20 min", said == true and NS.companionBubbleKey == "NOTICE__tinker",
		tostring(NS.companionBubbleKey))
	for _, name in ipairs({ "UnitHealth", "UnitHealthMax", "UnitAffectingCombat" }) do _G[name] = NP.saved[name] end
	S.done()
end

ResetWorld()

-- 3. Cosmétiques du coffre ========================================================================
local K = { savedIsUnlocked = NS.CompanionIsUnlocked, savedCreateColor = rawget(_G, "CreateColor"), savedJournal = rawget(NS, "JournalCounts") }

-- Règle du coffre, simulée (elle appartient au module du coffre) : un
-- cosmétique de palier sans `unlock` n'est possédé que s'il a été donné.
function NS:CompanionIsUnlocked(kind, def)
	if type(def) == "table" and not def.unlock and (tonumber(def.tier) or 0) >= 1 then
		return self:CompanionData().unlocked[kind .. ":" .. tostring(def.id)] == true
	end
	return K.savedIsUnlocked(self, kind, def)
end

function K.Reset()
	ResetWorld()
	for _, frame in ipairs({ NS.companionFrame, NS.companionBubble, NS.companionHover }) do
		if frame then frame:Hide() end
	end
	NS.companionFrame, NS.companionBubble, NS.companionHover = nil, nil, nil
	NS.companionRT, NS.companionSession = nil, nil
	NS.JournalCounts = nil
	Mock.world.level = 11
	NS:CompanionData().tutoDone = true
	return NS:EnsureCompanionFrame()
end
function K.Give(kind, id) NS:CompanionData().unlocked[kind .. ":" .. id] = true end
function K.Def(list, id) for _, def in ipairs(list) do if def.id == id then return def end end end
function K.Row(key)
	for _, row in ipairs(NS.optionsFrame.rows) do if row.def and row.def.key == key then return row end end
end

do
	Say("-- cosmétiques : catalogue")
	local S = Scenario("[COSM] catalogue")
	local fr, en = NS.COMPANION_STRINGS.fr, NS.COMPANION_STRINGS.en
	local problems = {}
	local kinds = {}
	for _, group in ipairs(NS.COMPANION_CATALOG) do
		kinds[group.kind] = true
		local seen = {}
		for index, def in ipairs(group.list) do
			local where = group.kind .. ":" .. tostring(def.id)
			if type(def.id) ~= "string" or seen[def.id] then problems[#problems + 1] = "id " .. where end
			seen[def.id or index] = true
			if not (fr[def.label] and en[def.label] and fr[def.label] ~= "" and en[def.label] ~= "") then
				problems[#problems + 1] = "libellé " .. where
			end
			local tier = def.tier
			if type(tier) ~= "number" or tier < 0 or tier > 3 or tier % 1 ~= 0 then problems[#problems + 1] = "palier " .. where end
		end
		-- le premier de chaque liste est possédé d'office (les ornements sont tous à gagner)
		if group.kind ~= "orn" and not (group.list[1] and group.list[1].tier == 0 and not group.list[1].unlock) then
			problems[#problems + 1] = "départ " .. group.kind
		end
	end
	S.ok("id unique, libellé fr+en, palier 0-3, départ au palier 0", #problems == 0, table.concat(problems, ", "))
	S.ok("quatre types : apparences, ornements, cadres, fonds", kinds.app and kinds.orn and kinds.frame and kinds.bg)
	-- v1.1.0 : plus un cadre et un fond des brillantes (Shiny.lua)
	-- v1.2.0 : plus 4 cadres et 11 fonds tirés des images du jeu
	-- QC 2.0 : plus un cadre et un fond par biome (sceaux) et ceux des titres (MenagerieCollection.lua)
	-- QC 2.7 : plus 2 cadres et 2 fonds des hauts faits (FeatsCosmetics.lua)
	-- QC 2.15 : plus un cadre et un fond de l'Échoppe du dresseur (FeatsCosmetics.lua)
	S.ok("28 cadres, 36 fonds", #NS.COMPANION_FRAMES == 28 and #NS.COMPANION_BACKGROUNDS == 36, #NS.COMPANION_FRAMES .. "/" .. #NS.COMPANION_BACKGROUNDS)
	local displays, okDisplay = {}, true
	for _, def in ipairs(NS.COMPANION_APPEARANCES) do
		if type(def.display) ~= "number" or def.display <= 0 or displays[def.display] then okDisplay = false end
		displays[def.display or 0] = true
	end
	S.ok("numéros d'affichage numériques et uniques", okDisplay)
	S.ok("au moins 13 apparences, 8 ornements", #NS.COMPANION_APPEARANCES >= 13 and #NS.COMPANION_ORNAMENTS >= 8)
	-- les nouveaux ornements ont leur interrupteur (réglage par défaut + ligne)
	local page
	-- sous-page « Ornements » (la page principale déborderait sinon)
	for _, p in ipairs(NS.OPTION_PAGES) do if p.id == "companionOrnaments" then page = p end end
	local rowKeys = {}
	for _, row in ipairs(page.rows) do if row.key then rowKeys[row.key] = true end end
	local orphans = {}
	for _, def in ipairs(NS.COMPANION_ORNAMENTS) do
		if not rowKeys[def.key] or NS:DB()[def.key] == nil then orphans[#orphans + 1] = def.id end
	end
	S.ok("chaque ornement a sa ligne de réglage", #orphans == 0, table.concat(orphans, ","))
	local mainKeys = {}
	for _, p in ipairs(NS.OPTION_PAGES) do
		if p.id == "companionMain" then for _, row in ipairs(p.rows) do if row.key then mainKeys[row.key] = true end end end
	end
	S.ok("lignes Cadre et Fond dans la page principale", mainKeys.companionFrameStyle and mainKeys.companionBackground)
	S.done()
end

do
	Say("-- cosmétiques : récompenses du coffre")
	local S = Scenario("[COSM] récompenses du coffre")
	local rewards = NS.COMPANION_REWARDS
	local perTier, expected, bad = { 0, 0, 0 }, 0, {}
	for _, group in ipairs(NS.COMPANION_CATALOG) do
		for _, def in ipairs(group.list) do if def.tier >= 1 then expected = expected + 1 end end
	end
	local keys = {}
	for _, r in ipairs(rewards) do
		local valid = (r.kind == "app" or r.kind == "orn" or r.kind == "frame" or r.kind == "bg")
			and type(r.id) == "string" and type(r.label) == "string" and (r.tier == 1 or r.tier == 2 or r.tier == 3)
			and not keys[r.kind .. ":" .. r.id]
		if not valid then bad[#bad + 1] = tostring(r.kind) .. ":" .. tostring(r.id) end
		keys[tostring(r.kind) .. ":" .. tostring(r.id)] = true
		if perTier[r.tier] then perTier[r.tier] = perTier[r.tier] + 1 end
	end
	S.ok("récompenses : tous les cosmétiques de palier ≥ 1, bien formés", #rewards == expected and #bad == 0,
		#rewards .. "/" .. expected .. " " .. table.concat(bad, ","))
	S.ok("au moins 7 récompenses par palier", perTier[1] >= 7 and perTier[2] >= 7 and perTier[3] >= 7,
		table.concat(perTier, "/"))
	local kindsPerTier = {}
	for _, r in ipairs(rewards) do kindsPerTier[r.tier .. r.kind] = true end
	local mixed = true
	for tier = 1, 3 do
		for _, kind in ipairs({ "app", "orn", "frame", "bg" }) do mixed = mixed and kindsPerTier[tier .. kind] == true end
	end
	S.ok("chaque palier offre des quatre types", mixed)
	local frost
	for _, r in ipairs(rewards) do if r.kind == "frame" and r.id == "frost" then frost = r end end
	S.ok("libellé d'une récompense", frost and NS:CompanionRewardLabel(frost) == "Givre", frost and NS:CompanionRewardLabel(frost))
	S.ok("libellé avec son type", frost and NS:CompanionRewardLabel(frost, true) == "Cadre : Givre",
		frost and NS:CompanionRewardLabel(frost, true))
	S.ok("libellé d'une récompense invalide : vide", NS:CompanionRewardLabel(nil) == "")
	S.done()
end

do
	Say("-- cosmétiques : cadre et fond posés")
	local S = Scenario("[COSM] cadre et fond posés")
	local frame = K.Reset()
	-- 3.1.0 : bordures et filets du client : le cadre carré (Sobre) ; au thème
	-- forgé, le cadre gagné teinte l'anneau (tests/modules/companion_forge.lua)
	NS:DB().companionStyle = "sobre"
	NS:ApplyUIStyle()
	S.ok("cadre par défaut : ardoise, sans bordure du client", frame.frameStyle == "slate" and not frame.frameBackdrop)
	S.ok("fond par défaut : nuit, aplat", frame.bgStyle == "night" and frame.bg.texture == NS.Theme.SOLID
		and frame.bg.vertex[4] == 0.66)
	S.ok("cadre verrouillé refusé", NS:CompanionSetStyle("frame", "gilded") == nil and frame.frameStyle == "slate")
	K.Give("frame", "gilded")
	NS:CompanionSetStyle("frame", "gilded")
	local border = frame.styleBorder
	S.ok("or ciselé : bordure dorée du client posée", border and border:IsShown() and border.backdrop
		and border.backdrop.edgeFile == "Interface\\DialogFrame\\UI-DialogBox-Gold-Border" and frame.frameBackdrop == true)
	S.ok("or ciselé : filet ambre et second filet", frame.top.vertex[1] == 0.91 and frame.styleInnerHolder:IsShown())
	S.ok("choix persisté par personnage", NS:CharData().companion.frameStyle == "gilded")
	K.Give("frame", "frost")
	NS:CompanionSetStyle("frame", "frost")
	K.Give("frame", "copper")
	NS:CompanionSetStyle("frame", "copper")
	S.ok("cuivre : filets seuls, bordure du client masquée", not border:IsShown() and frame.frameStyle == "copper")
	-- fonds : texture, dégradé (deux API), étoiles
	K.Give("bg", "velvet")
	NS:CompanionSetStyle("bg", "velvet")
	S.done()
	S = Scenario("[COSM] fonds : texture, dégradé et ses replis, étoiles")
	S.ok("velours : texture du client teintée", frame.bg.texture == "Interface\\DialogFrame\\UI-DialogBox-Gold-Background"
		and frame.bg.vertex[1] == 0.70 and not frame.bgFallback)
	_G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
	function frame.bg:SetGradient(orientation, minColor, maxColor) self.gradient = { orientation, minColor, maxColor } end
	K.Give("bg", "ember")
	NS:CompanionSetStyle("bg", "ember")
	S.ok("braise : dégradé vertical (API récente), braise en bas", frame.bgGradient == "color"
		and frame.bg.gradient[1] == "VERTICAL" and frame.bg.gradient[2].r == 0.50 and frame.bg.gradient[3].r == 0.10)
	frame.bg.SetGradient = function() error("ancienne signature") end
	function frame.bg:SetGradientAlpha(orientation, r1) self.gradientAlpha = { orientation, r1 } end
	NS:CompanionApplyBackground()
	S.ok("dégradé : repli sur SetGradientAlpha", frame.bgGradient == "alpha" and frame.bg.gradientAlpha[2] == 0.50)
	frame.bg.SetGradient, frame.bg.SetGradientAlpha = nil, nil
	NS:CompanionApplyBackground()
	S.ok("sans API de dégradé : aplat teinté", frame.bgGradient == nil and frame.bg.vertex[1] == 0.30)
	_G.CreateColor = K.savedCreateColor
	K.Give("bg", "stars")
	NS:CompanionSetStyle("bg", "stars")
	local lit = frame.stars and #frame.stars > 0
	for _, star in ipairs(frame.stars or {}) do lit = lit and star:IsShown() end
	S.ok("voûte étoilée : étoiles allumées", lit)
	K.Give("bg", "marble")
	NS:CompanionSetStyle("bg", "marble")
	S.ok("autre fond : étoiles éteintes", not frame.stars[1]:IsShown() and frame.bg.texture:find("Marble", 1, true))
	-- repli : texture refusée par le client
	local baseSet = frame.bg.SetTexture
	frame.bg.SetTexture = function(self, path)
		if path ~= NS.Theme.SOLID then return false end
		return baseSet(self, path)
	end
	NS:CompanionApplyBackground()
	S.done()
	S = Scenario("[COSM] replis : texture refusée, bordure en erreur, choix non possédé, rechargement")
	S.ok("texture refusée : aplat teinté à la place", frame.bgFallback == true and frame.bg.texture == NS.Theme.SOLID
		and frame.bg.vertex[1] == 0.45)
	frame.bg.SetTexture = baseSet
	-- repli : SetBackdrop qui échoue
	NS:CompanionSetStyle("frame", "gilded")
	frame.styleBorder.SetBackdrop = function() error("no backdrop") end
	NS:CompanionApplyFrame()
	S.ok("bordure du client en erreur : masquée, filets gardés", not frame.styleBorder:IsShown()
		and frame.frameBackdrop == false and frame.top.vertex[1] == 0.91)
	-- choix verrouillé dans la sauvegarde : retour au défaut
	NS:CompanionData().background = "frost"
	S.ok("fond non possédé refusé", NS:CompanionCurrentStyle("bg").id == "night")
	-- cadre recréé (rechargement) : le choix revient
	NS:CompanionData().background = "marble"
	NS.companionFrame:Hide()
	NS.companionFrame = nil
	frame = NS:EnsureCompanionFrame()
	S.ok("après rechargement : cadre et fond retrouvés", frame.frameStyle == "gilded" and frame.bgStyle == "marble")
	S.done()
end

do
	Say("-- cosmétiques : client sans BackdropTemplate ni CreateColor")
	local S = Scenario("[COSM] client sans BackdropTemplate ni CreateColor")
	K.Reset()
	Mock.world.noBackdropTemplate = true
	NS.companionFrame:Hide()
	NS.companionFrame = nil
	local frame = NS:EnsureCompanionFrame()
	K.Give("frame", "silver")
	local ok = pcall(NS.CompanionSetStyle, NS, "frame", "silver")
	S.ok("sans BackdropTemplate : rien ne casse, cadre posé", ok and frame.frameStyle == "silver" and frame.styleBorder ~= nil)
	Mock.world.noBackdropTemplate = nil
	K.Give("bg", "dusk")
	ok = pcall(NS.CompanionSetStyle, NS, "bg", "dusk")
	S.ok("sans CreateColor : fond en aplat", ok and frame.bgStyle == "dusk" and frame.bgGradient == nil)
	S.done()
end

do
	Say("-- cosmétiques : nouveaux ornements")
	local S = Scenario("[COSM] nouveaux ornements")
	local frame = K.Reset()
	local orn = frame.ornaments
	S.ok("ornements construits", orn.flower and orn.pennant and orn.crystal and orn.crown)
	NS:CompanionApplyOrnaments()
	S.ok("ornements du coffre masqués tant qu'ils ne sont pas gagnés", not orn.crown:IsShown() and not orn.flower:IsShown())
	K.Give("orn", "crown")
	NS:CompanionApplyOrnaments()
	S.ok("couronne gagnée : affichée", orn.crown:IsShown())
	NS:DB().companionOrnCrown = false
	NS:CompanionApplyOrnaments()
	S.ok("couronne coupée dans les réglages : masquée", not orn.crown:IsShown())
	NS:DB().companionOrnCrown = true
	S.done()
end

do
	Say("-- cosmétiques : réglages")
	local S = Scenario("[COSM] réglages")
	K.Reset()
	K.Give("frame", "copper")
	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companion")
	local row = K.Row("companionFrameStyle")
	local bgRow = K.Row("companionBackground")
	local function Entry(r, id) for _, e in ipairs(r.dropdown.options) do if e.value == id then return e end end end
	S.ok("un choix par cadre et par fond", row and row.dropdown and #row.dropdown.options == #NS.COMPANION_FRAMES
		and bgRow and bgRow.dropdown and #bgRow.dropdown.options == #NS.COMPANION_BACKGROUNDS)
	S.ok("carte du cadre : libellé, choix courant dans la liste", row.label.text == "Cadre" and row.dropdown.text.text == "Ardoise",
		row.dropdown.text.text)
	local fel, copper = Entry(row, "fel"), Entry(row, "copper")
	S.ok("cadre verrouillé : grisé, palier affiché", fel.disabled and fel.hint == "Palier 3", fel.hint)
	S.ok("cadre possédé : choisissable, sans palier", not copper.disabled and copper.hint == nil)
	row.dropdown:Open()
	local felRow
	for _, r in ipairs(row.dropdown.list.rows) do if r:IsShown() and r.entry and r.entry.value == "fel" then felRow = r end end
	S.ok("liste ouverte : « Palier 3 » en face du cadre verrouillé", felRow and felRow.hint.text == "Palier 3")
	S.ok("clic sur un verrouillé : rien ne change", row.dropdown:Choose("fel") == false and NS:CompanionData().frameStyle == "slate")
	row.dropdown:Choose("copper")
	S.ok("choix dans la liste : appliqué et persisté", NS:CompanionData().frameStyle == "copper"
		and NS.companionFrame.frameStyle == "copper" and row.dropdown.text.text == "Cuivre" and row.dropdown.value == "copper")
	local preview = NS.optionsFrame.previews.companionMain
	local edge = preview and preview.box.edge.top.vertex
	S.ok("aperçu des réglages : le filet du cadre choisi", edge and math.abs(edge[1] - 0.80) < 0.01 and math.abs(edge[2] - 0.48) < 0.01,
		edge and table.concat(edge, ","))
	NS:RunOptionAction("companionFrameStyle")
	S.ok("action : style possédé suivant", NS:CompanionData().frameStyle == "slate")
	NS:RunOptionAction("companionBackground")
	S.ok("fond : un seul possédé, le cycle y reste", NS:CompanionData().background == "night")
	-- ornement du coffre verrouillé : son palier, pas de condition de tampons
	local crown = K.Row("companionOrnCrown")
	S.ok("ornement du coffre verrouillé : verrou « Palier 3 »", crown and crown.locked and crown.lock.label.text == "Palier 3",
		crown and crown.lock and crown.lock.label.text)
	NS.optionsFrame:Hide()
	S.done()
end

NS.CompanionIsUnlocked = K.savedIsUnlocked
_G.CreateColor = K.savedCreateColor
NS.JournalCounts = K.savedJournal
if NS.companionFrame then NS.companionFrame:Hide() end
