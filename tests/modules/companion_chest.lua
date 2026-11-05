-- Tests : évolution par le bonheur, coffres de zone, objectifs « action + récompense »
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

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
	H.Reset(9)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	local data = NS:CompanionData()
	Check("[EVO] premier relevé : stade posé sans attente", data.stage == 1 and data.stageReady == nil, tostring(data.stage) .. "/" .. tostring(data.stageReady) .. " lvl " .. tostring(Mock.world.level))
	H.SetNeeds(40)
	Mock.world.level = 10
	Mock:Fire("PLAYER_LEVEL_UP", 10)
	Check("[EVO] niveau 10 atteint, envies basses : prêt, pas encore évolué", data.stage == 1 and data.stageReady == 2,
		tostring(data.stage) .. "/" .. tostring(data.stageReady))
	Check("[EVO] annoncé : prêt à devenir…, et comment", Mock:Output():find("est prêt à devenir", 1, true) ~= nil, Mock:Output())
	Check("[EVO] heureux = 4 envies à 70 %", NS.COMPANION_HAPPY_MIN == 70 and not NS:CompanionIsHappy())
	local unlocks = NS:CompanionNextUnlocks()
	local ready
	for _, item in ipairs(unlocks) do if item.kind == "stage" then ready = item end end
	Check("[EVO] contrat : stade prêt, stat « happy »", ready and ready.stat == "happy" and ready.ready == true
		and ready.need == 4 and ready.have < 4, ready and ready.stat)
	local hints = table.concat(NS:CompanionHappyHints(), " | ")
	Check("[EVO] survol : chaque envie et comment la remplir", hints:find("Faim : 40 %", 1, true)
		and hints:find("mange ou bois", 1, true) and hints:find("Curiosité", 1, true), hints)
	-- objectif : l'action, le stade en récompense
	local goal = H.Find("comp:stage")
	Check("[EVO] objectif « Rends … heureux pour évoluer » en tête", goal and goal.label:find("heureux pour évoluer", 1, true)
		and goal.ratio > 1 and goal.rewards and goal.rewards[1]:find("devient", 1, true), goal and goal.label)
	-- trois envies comblées : toujours prêt
	local needs = data.needs
	needs.hunger, needs.energy, needs.mood = 90, 90, 90
	NS:CompanionAdd("mood", 1)
	Check("[EVO] trois envies sur quatre : attend encore", data.stage == 1 and data.stageReady == 2)
	-- la dernière : évolution
	NS:CompanionAdd("curiosity", 40)
	Check("[EVO] quatrième envie comblée : évolution", data.stage == 2 and data.stageReady == nil)
	Check("[EVO] évolution annoncée", Mock:Output():find("devient", 1, true) ~= nil)
	-- une envie qui baisse ne fait jamais régresser
	NS:CompanionAdd("hunger", -80)
	Check("[EVO] jamais de retour en arrière", data.stage == 2)
	-- heureux au moment du niveau : évolution directe
	H.SetNeeds(85)
	Mock.world.level = 20
	Mock:Fire("PLAYER_LEVEL_UP", 20)
	Check("[EVO] heureux au palier : évolue tout de suite", data.stage == 3 and data.stageReady == nil, data.stage)
	-- somnolent (longue absence) : pas heureux
	H.SetNeeds(85)
	data.sleepy = true
	Check("[EVO] somnolent : pas heureux", not NS:CompanionIsHappy())
	data.sleepy = nil
end

-- 2. Objectifs : une action, ses récompenses ----------------------------------------
do
	Say("-- objectifs : action et récompenses")
	H.Reset(15)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	local level = H.Find("level:20")
	Check("[RWD] palier : « Atteins le niveau 20 »", level and level.label == "Atteins le niveau 20", level and level.label)
	Check("[RWD] stade fusionné dans le palier (une seule ligne)", H.Find("comp:stage") == nil)
	local rewards = level and table.concat(level.rewards or {}, " | ") or ""
	Check("[RWD] récompenses : le stade puis le tampon", rewards:find("devient Aguerri", 1, true)
		and rewards:find("Palier 20", 1, true) and rewards:find("devient", 1, true) < rewards:find("Palier", 1, true), rewards)
	NS:RefreshJournalTracker()
	local tracker = NS.journalTracker
	local line
	for _, l in ipairs(tracker and tracker.lines or {}) do if l.goal and l.goal.id == "level:20" then line = l end end
	if line then
		line:GetScript("OnEnter")(line)
		local text = table.concat(_G.GameTooltip.lines or {}, " | ")
		Check("[RWD] survol : ligne « Récompense : … »", text:find("Récompense : ", 1, true) ~= nil, text)
		line:GetScript("OnLeave")(line)
	else
		Check("[RWD] palier affiché dans le suivi", false)
	end
end

-- 3. Coffres de zone -----------------------------------------------------------------
do
	Say("-- coffres de zone")
	Check("[CHEST] fichier chargé", NS.Loaded and NS.Loaded.CompanionChest == true)
	Check("[CHEST] palier des zones : Durotar 1, Tanaris 3, inconnue = niveau du joueur", NS:ZoneTier(1411) == 1
		and NS:ZoneTier(1446) == 3)
	H.Reset(25)
	Check("[CHEST] zone inconnue au niveau 25 : palier 2", NS:ZoneTier(8888) == 2)
	H.Reset(12)
	H.Install()
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	H.full[8888] = 3
	NS:RefreshJournalTracker()
	Check("[CHEST] zone à 87 % : pas de coffre", NS:ChestData()[8888] == nil)
	local zone = H.Find("zone:8888")
	Check("[CHEST] complétion : la récompense est annoncée", zone and zone.reward == "un objet au choix (palier 1)",
		zone and zone.reward)
	H.full[8888] = 4
	NS:RefreshJournalTracker()
	local chest = NS:ChestData()[8888]
	Check("[CHEST] zone à 100 % : coffre posé, palier de la zone", chest and chest.tier == 1 and not chest.opened)
	Check("[CHEST] annoncé dans le chat", Mock:Output():find("Terre inconnue terminée à 100 %", 1, true) ~= nil, Mock:Output())
	local goal = H.Find("chest:8888")
	Check("[CHEST] objectif « Ouvre le coffre de … » en tête", goal and goal.label == "Ouvre le coffre de Terre inconnue"
		and NS:JournalObjectives()[1].id == "chest:8888", goal and goal.label)
	Check("[CHEST] la complétion finie disparaît des objectifs", H.Find("zone:8888") == nil)
	-- un deuxième passage ne repose pas de coffre
	Mock:Reset()
	NS:RefreshJournalTracker()
	Check("[CHEST] un seul coffre par zone", not Mock:Output():find("terminée", 1, true))
	-- options : le palier, sans ce qui est déjà à toi
	local options = NS:ChestOptions(1)
	Check("[CHEST] options : les objets du palier 1", #options == 2)
	NS:CompanionData().unlocked["orn:ribbon"] = true
	options = NS:ChestOptions(1)
	Check("[CHEST] options : un objet possédé n'est plus proposé", #options == 1 and options[1].id == "frog")
	NS:CompanionData().unlocked["orn:ribbon"] = nil
	-- ouverture : clic sur l'objectif du suivi
	NS:RefreshJournalTracker()
	local tracker = NS.journalTracker
	tracker.lines[1]:Click("LeftButton")
	local frame = NS.chestFrame
	Check("[CHEST] clic sur l'objectif : coffre ouvert", frame and frame:IsShown() and frame.zoneID == 8888)
	Check("[CHEST] fenêtre exclusive", (function()
		for _, field in ipairs(NS.EXCLUSIVE_WINDOWS) do if field == "chestFrame" then return true end end
	end)() == true)
	local buttons = {}
	for _, button in ipairs(frame.options) do
		if button:IsShown() then buttons[#buttons + 1] = button.kindTag.label.text .. " " .. button.text.text end
	end
	Check("[CHEST] un bouton par objet, avec sa catégorie", #buttons == 2 and table.concat(buttons, "|"):find("APPARENCE Rainette", 1, true)
		and table.concat(buttons, "|"):find("ORNEMENT", 1, true), table.concat(buttons, "|"))
	-- refuser un objet d'un autre palier
	Check("[CHEST] objet d'un autre palier refusé", NS:ChestPick(8888, NS.COMPANION_REWARDS[3]) == false)
	-- choisir la rainette
	local frogButton
	for _, button in ipairs(frame.options) do if button.reward and button.reward.id == "frog" then frogButton = button end end
	frogButton:Click()
	Check("[CHEST] choix : objet débloqué, coffre ouvert", NS:CompanionData().unlocked["app:frog"] == true
		and NS:ChestData()[8888].opened == true and NS:ChestData()[8888].reward == "app:frog")
	Check("[CHEST] apparence choisie : portée tout de suite", NS:CompanionData().appearance == "frog")
	Check("[CHEST] fenêtre refermée, objectif disparu", not frame:IsShown() and H.Find("chest:") == nil)
	Check("[CHEST] second choix impossible", NS:ChestPick(8888, NS.COMPANION_REWARDS[2]) == false)
	-- /r2q coffre sans coffre
	Mock:Reset()
	NS:HandleCommand("coffre")
	Check("[CHEST] /r2q coffre sans coffre : message", Mock:Output():find("Aucun coffre", 1, true) ~= nil, Mock:Output())
	-- palier épuisé : zone dorée
	NS:CompanionData().unlocked["orn:ribbon"] = true
	H.full[9001] = 4
	Mock.world.mapID = 9001
	Mock:Reset()
	NS:RefreshJournalTracker()
	local golden = NS:ChestData()[9001]
	Check("[CHEST] palier épuisé : zone dorée, rien à ouvrir", golden and golden.golden == true and golden.opened == true
		and Mock:Output():find("dorée", 1, true) ~= nil, Mock:Output())
	-- palier 3 par /r2q coffre
	H.full[9003] = 4
	Mock.world.mapID = 9003
	NS:RefreshJournalTracker()
	NS:HandleCommand("coffre")
	Check("[CHEST] /r2q coffre : ouvre le coffre en attente", NS.chestFrame:IsShown() and NS.chestFrame.zoneID == 9003)
	NS.chestFrame:Hide()
	-- module coupé : pas de coffre
	H.full[9004] = 4
	Mock.world.mapID = 9004
	NS:DB().companionEnabled = false
	NS:ChestCheck(9004)
	Check("[CHEST] module coupé : pas de coffre", NS:ChestData()[9004] == nil)
	NS:DB().companionEnabled = true
	-- une seule part : pas de coffre (le bestiaire ou la récolte doivent compter)
	H.full = {}
	Check("[CHEST] cosmétique à palier : hors des déblocages par compteur", (function()
		local def = NS.COMPANION_APPEARANCES[2]
		local saved = def.tier
		def.tier = 1
		local found = false
		for _, item in ipairs(NS:CompanionNextUnlocks()) do if item.id == def.id then found = true end end
		def.tier = saved
		return not found
	end)())
	H.Uninstall()
	Check("[CHEST] chaînes fr/en", (function()
		for key in pairs(NS.CHEST_STRINGS.fr) do if not NS.CHEST_STRINGS.en[key] then return false end end
		return true
	end)())
end
