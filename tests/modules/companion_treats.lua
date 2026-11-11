-- Compagnon : friandises et garde-manger (Treats.lua). Paliers de zone 25/50/75 %
-- (envie la plus basse, Festin à 75 %), garde-manger plafonné (le surplus est
-- mangé), donner (envie à 100, carte qui flaire, Gourmande), rattrapage une
-- fois avec une bulle de résumé, coffre doré, Maj + clic, répliques.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local TR = { savedRewards = rawget(NS, "COMPANION_REWARDS"), savedTrait = NS.CompanionTrait,
	savedKnown = NS.JournalKnownZones, shift = rawget(_G, "IsShiftKeyDown"), random = math.random }
TR.have = {}

local MAPS = {
	[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 },
	[947]  = { mapID = 947,  name = "Azeroth", parentMapID = 0, mapType = 1 },
	[9101] = { mapID = 9101, name = "Val des miettes", parentMapID = 1414, mapType = 3 },
	[9102] = { mapID = 9102, name = "Crête sucrée", parentMapID = 1414, mapType = 3 },
	[9103] = { mapID = 9103, name = "Plaine seule", parentMapID = 1414, mapType = 3 },
}
NS.ZONE_LEVELS[9101], NS.ZONE_LEVELS[9102], NS.ZONE_LEVELS[9103] = { 5, 12 }, { 5, 12 }, { 5, 12 }

-- deux parts de 4 : la zone vaut have × 25 % ; la 9103 n'a qu'une part
TR.parts = {
	{ id = "treat_a", label = "Partie A", Compute = function(_, zoneID)
		if not TR.have[zoneID] then return nil end
		return { have = TR.have[zoneID], need = 4 }
	end },
	{ id = "treat_b", label = "Partie B", Compute = function(_, zoneID)
		if not TR.have[zoneID] or zoneID == 9103 then return nil end
		return { have = TR.have[zoneID], need = 4 }
	end },
}
for _, part in ipairs(TR.parts) do NS.RegisterZonePart(part) end

function TR.Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.companionBubbleText = nil
	if NS.companionRT then NS.companionRT.cool = {} end
end
function TR.Reset(opts)
	opts = opts or {}
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "treatMenu" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.companionLastPet = nil, nil, nil, nil
	if NS.journalTracker then NS.journalTracker:Hide() end
	NS.journalTracker = nil
	for id, info in pairs(MAPS) do Mock.world.maps[id] = info end
	Mock.world.mapID, Mock.world.level, Mock.world.combat = 9101, 10, false
	TR.have = {}
	NS.CompanionTrait = TR.savedTrait
	NS.JournalKnownZones = TR.savedKnown
	_G.IsShiftKeyDown = function() return false end
	math.random = TR.random
	local data = NS:CompanionData()
	data.tutoDone = true
	if not opts.fresh then NS:TreatData().treatsInit = true end
	NS:CompanionUpdateVisibility()
	TR.Quiet()
end
function TR.SetNeeds(h, e, m, c)
	local needs = NS:CompanionData().needs
	needs.hunger, needs.energy, needs.mood, needs.curiosity = h, e, m, c
end
function TR.Done()
	for index = #NS.ZONE_PARTS, 1, -1 do
		local part = NS.ZONE_PARTS[index]
		if part == TR.parts[1] or part == TR.parts[2] then table.remove(NS.ZONE_PARTS, index) end
	end
	NS.COMPANION_REWARDS = TR.savedRewards
	NS.CompanionTrait = TR.savedTrait
	NS.JournalKnownZones = TR.savedKnown
	_G.IsShiftKeyDown = TR.shift
	math.random = TR.random
	ResetWorld()
end

-- 1. Garde-manger -------------------------------------------------------------------------
do
	Say("-- friandises : garde-manger")
	TR.Reset()
	local data = NS:TreatData()
	Check("[TREAT] garde-manger vide au départ, 5 sortes ; plafonds : 3 par sorte, 2 Festins", NS:TreatTotal() == 0
		and #NS.TREAT_KINDS == 5 and data.pantry.festin == 0 and NS:TreatCap("biscuit") == 3 and NS:TreatCap("carte") == 3
		and NS:TreatCap("festin") == 2)
	data.pantry.bonbon, data.pantry.festin = 9, -2
	NS:TreatData()
	Check("[TREAT] valeurs hors bornes ramenées", data.pantry.bonbon == 3 and data.pantry.festin == 0, data.pantry.bonbon)
	TR.SetNeeds(60, 40, 80, 90)
	local energy = NS:TreatForLowestNeed() == "infusion"
	TR.SetNeeds(50, 50, 50, 20)
	local curiosity = NS:TreatForLowestNeed() == "carte"
	TR.SetNeeds(30, 30, 30, 30)
	Check("[TREAT] envie la plus basse : énergie -> infusion, curiosité -> carte, égalité : la faim d'abord", energy
		and curiosity and NS:TreatForLowestNeed() == "biscuit")
	Check("[TREAT] libellés", NS:TreatLabel("festin") == "Festin" and NS:TreatLabel("bonbon") == "Bonbon pétillant")
end

-- 2. Gagner : rangé, ou mangé si plein ---------------------------------------------------------
do
	Say("-- friandises : gagner")
	TR.Reset()
	TR.SetNeeds(40, 40, 40, 40)
	Check("[TREAT] gagnée : rangée, annoncée, l'envie ne bouge pas", NS:TreatGrant("biscuit") == "stored"
		and NS:TreatCount("biscuit") == 1 and NS.companionBubbleKey == "TREAT_GOT"
		and NS.companionBubbleText:find("Biscuit de voyage", 1, true) and NS:CompanionData().needs.hunger == 40,
		NS.companionBubbleText)
	NS:TreatData().pantry.biscuit = 3
	TR.Quiet()
	Check("[TREAT] plein : mangée tout de suite, la faim à 100, « tant pis, je la mange »", NS:TreatGrant("biscuit") == "eaten"
		and NS:TreatCount("biscuit") == 3 and NS:CompanionData().needs.hunger == 100 and NS.companionBubbleKey == "TREAT_FULL",
		NS.companionBubbleKey)
	TR.Quiet()
	Check("[TREAT] sans bulle (quiet)", NS:TreatGrant("bonbon", { quiet = true }) == "stored" and NS.companionBubbleKey == nil)
	local unknown = NS:TreatGrant("gateau") == nil
	NS:DB().companionEnabled = false
	Check("[TREAT] sorte inconnue, compagnon coupé : rien", unknown and NS:TreatGrant("carte") == nil
		and NS:TreatCount("carte") == 0)
	NS:DB().companionEnabled = true
end

-- 3. Donner ----------------------------------------------------------------------------------
do
	Say("-- friandises : donner")
	TR.Reset()
	TR.SetNeeds(30, 30, 30, 30)
	local refused = NS:TreatGive("infusion") == false
	local pantry = NS:TreatData().pantry
	pantry.infusion, pantry.bonbon, pantry.festin, pantry.carte = 1, 1, 1, 1
	local needs = NS:CompanionData().needs
	Check("[TREAT] rien à donner : refusé ; infusion donnée : énergie à 100, le reste pareil, sa bulle", refused
		and NS:TreatGive("infusion") and pantry.infusion == 0 and needs.energy == 100 and needs.hunger == 30
		and needs.mood == 30 and NS.companionBubbleKey == "TREAT_EAT_infusion", NS.companionBubbleKey)
	TR.Quiet()
	NS:TreatGive("bonbon")
	local bonbon = needs.mood == 100 and NS.companionBubbleKey == "TREAT_EAT_bonbon"
	TR.SetNeeds(30, 30, 30, 30)
	TR.Quiet()
	NS:TreatGive("festin")
	Check("[TREAT] bonbon : moral à 100 ; Festin : les 4 envies à 100, sa bulle", bonbon and needs.hunger == 100
		and needs.energy == 100 and needs.mood == 100 and needs.curiosity == 100 and pantry.festin == 0
		and NS.companionBubbleKey == "TREAT_EAT_festin", NS.companionBubbleKey)
	-- carte : elle flaire la part la moins avancée de la zone
	TR.have[9101] = 1
	TR.Quiet()
	NS:TreatGive("carte")
	local alert = NS.companionFrame and NS.companionFrame.alert
	Check("[TREAT] carte : curiosité à 100, le « ! » du flair, elle flaire ce qui reste", needs.curiosity == 100
		and alert ~= nil and alert:IsShown() and NS.companionBubbleKey == "TREAT_SNIFF"
		and NS.companionBubbleText:find("Partie A", 1, true), NS.companionBubbleText)
	TR.have[9101] = 4
	pantry.carte = 1
	TR.Quiet()
	NS:TreatGive("carte")
	Check("[TREAT] zone finie : la bulle de la carte", NS.companionBubbleKey == "TREAT_EAT_carte", NS.companionBubbleKey)
	-- Gourmande : double plaisir
	NS.CompanionTrait = function() return "glutton" end
	TR.SetNeeds(30, 30, 30, 30)
	pantry.biscuit = 1
	NS:TreatGive("biscuit")
	local glutton = needs.hunger == 100 and needs.mood == 30 + NS.TREAT_RULES.gluttonMood
	NS.CompanionTrait = function() return "lazy" end
	TR.SetNeeds(30, 30, 30, 30)
	pantry.biscuit = 1
	NS:TreatGive("biscuit")
	Check("[TREAT] Gourmande : le moral monte aussi ; autre caractère : il ne bouge pas", glutton and needs.mood == 30, needs.mood)
end

-- 4. Paliers de zone --------------------------------------------------------------------------
do
	Say("-- friandises : paliers de zone")
	TR.Reset()
	TR.SetNeeds(80, 20, 80, 80)
	TR.have[9101] = 0
	NS:RefreshJournalTracker()
	local zero = NS:TreatTotal() == 0
	TR.have[9101] = 1
	NS:RefreshJournalTracker()
	Check("[TREAT] 0 % : rien ; 25 % : la friandise de l'envie la plus basse, palier noté", zero
		and NS:TreatCount("infusion") == 1 and NS:TreatTotal() == 1 and NS:TreatData().milestones[9101] == 25, NS:TreatTotal())
	NS:RefreshJournalTracker()
	Check("[TREAT] recalcul : pas deux fois", NS:TreatTotal() == 1)
	TR.SetNeeds(10, 80, 80, 80)
	TR.have[9101] = 3
	local gained = NS:TreatCheckZone(9101)
	Check("[TREAT] 25 -> 75 % : deux paliers d'un coup, 50 % : biscuit (faim basse), 75 % : Festin", #gained == 2
		and gained[1].mark == 50 and gained[2].mark == 75 and gained[1].kind == "biscuit" and gained[2].kind == "festin"
		and NS:TreatCount("festin") == 1)
	TR.have[9101] = 4
	TR.have[9103] = 4
	Check("[TREAT] pas de friandise à 100 % (c'est le coffre), pour une seule part, ni pour une zone inconnue",
		#NS:TreatCheckZone(9101) == 0 and #NS:TreatCheckZone(9103) == 0 and #NS:TreatCheckZone(nil) == 0
		and #NS:TreatCheckZone(424242) == 0)
end

-- 5. Rattrapage --------------------------------------------------------------------------------
do
	Say("-- friandises : rattrapage")
	TR.Reset({ fresh = true })
	TR.SetNeeds(60, 60, 60, 60)
	TR.have[9101], TR.have[9102] = 2, 4
	NS.JournalKnownZones = function() return { { id = 9101 }, { id = 9102 }, { id = 9103 } } end
	TR.have[9103] = 4
	NS:RefreshJournalTracker()
	local data = NS:TreatData()
	-- 9101 : 25 + 50 ; 9102 : 25 + 50 + 75 ; 9103 (une part) : rien
	Check("[TREAT] rattrapage : fait une fois, paliers notés", data.treatsInit == true and data.milestones[9101] == 50
		and data.milestones[9102] == 75 and data.milestones[9103] == nil)
	-- envies égales : 4 biscuits pour 25/50 %, le 4e ne rentre plus
	Check("[TREAT] … 5 friandises, la 4e mangée, une seule bulle de résumé", NS:TreatTotal() == 4
		and NS:TreatCount("biscuit") == 3 and NS:TreatCount("festin") == 1 and NS:CompanionData().needs.hunger == 100
		and NS.companionBubbleKey == "TREAT_RETRO" and NS.companionBubbleText:find("5 friandises", 1, true)
		and NS.companionBubbleText:find("mangé 1", 1, true), NS.companionBubbleText)
	TR.Quiet()
	NS:RefreshJournalTracker()
	Check("[TREAT] pas de second rattrapage", NS:TreatTotal() == 4 and NS.companionBubbleKey == nil,
		tostring(NS:TreatTotal()) .. " " .. tostring(NS.companionBubbleKey))

	-- envies différentes : chaque palier vise la plus basse du moment
	TR.Reset({ fresh = true })
	TR.SetNeeds(60, 50, 70, 80)
	NS.JournalKnownZones = function() return { { id = 9101 } } end
	TR.have[9101] = 2
	NS:TreatCatchUp()
	Check("[TREAT] rien de mangé : bulle « trouvé »", NS:TreatCount("infusion") == 2 and NS.companionBubbleKey == "TREAT_RETRO_KEPT"
		and NS.companionBubbleText:find("2", 1, true), NS.companionBubbleText)

	-- beaucoup de zones : le garde-manger déborde, le surplus est mangé
	TR.Reset({ fresh = true })
	TR.SetNeeds(60, 60, 60, 60)
	local list = {}
	for id = 9201, 9206 do
		MAPS[id] = { mapID = id, name = "Zone " .. id, parentMapID = 1414, mapType = 3 }
		Mock.world.maps[id] = MAPS[id]
		TR.have[id] = 4
		list[#list + 1] = { id = id }
	end
	NS.JournalKnownZones = function() return list end
	local found, eaten = NS:TreatCatchUp()
	Check("[TREAT] 6 zones finies : 18 friandises, Festins 2 gardés et 4 mangés, rien au-dessus des plafonds", found == 18
		and NS:TreatCount("festin") == 2 and eaten >= 4 and NS:TreatCount("biscuit") <= 3 and NS:TreatCount("infusion") <= 3
		and NS:TreatCount("bonbon") <= 3 and NS:TreatCount("carte") <= 3, tostring(found) .. " / " .. tostring(eaten))
	Check("[TREAT] … « et j'en ai mangé » ; déjà fait : nil", NS.companionBubbleKey == "TREAT_RETRO"
		and NS.companionBubbleText:find(tostring(eaten), 1, true) and NS:TreatCatchUp() == nil, NS.companionBubbleText)
	TR.Reset({ fresh = true })
	NS.JournalKnownZones = function() return {} end
	TR.Quiet()
	NS:TreatCatchUp()
	Check("[TREAT] rien à rattraper : pas de bulle", NS.companionBubbleKey == nil and NS:TreatData().treatsInit == true)
end

-- 6. Coffre doré ----------------------------------------------------------------------------------
do
	Say("-- friandises : coffre doré")
	TR.Reset()
	NS.COMPANION_REWARDS = {}
	local seq = { 1, 3 }
	math.random = function() return table.remove(seq, 1) or 1 end
	TR.have[9102] = 4
	NS:TreatData().milestones[9102] = 75
	local chest = NS:ChestCheck(9102)
	Check("[TREAT] coffre doré : un Festin et deux friandises, sa bulle", chest and chest.golden == true and chest.treats == true
		and NS:TreatCount("festin") == 1 and NS:TreatCount("biscuit") == 1 and NS:TreatCount("bonbon") == 1
		and NS:TreatTotal() == 3 and NS.companionBubbleKey == "TREAT_GOLDEN", NS:TreatTotal())
	Check("[TREAT] déjà posé : rien de plus", NS:ChestCheck(9102) == nil and NS:TreatTotal() == 3)
	NS.COMPANION_REWARDS = { { kind = "app", id = "frog", label = "COMP_APP_FROG", tier = 1 } }
	TR.have[9101] = 4
	NS:TreatData().milestones[9101] = 75
	local normal = NS:ChestCheck(9101)
	Check("[TREAT] coffre normal : pas de friandise", normal and not normal.golden and NS:TreatTotal() == 3)
	NS.COMPANION_REWARDS = TR.savedRewards
end

-- 7. Maj + clic : le garde-manger ----------------------------------------------------------------
do
	Say("-- friandises : menu Maj + clic")
	TR.Reset()
	NS:TreatData().pantry.bonbon = 2
	_G.IsShiftKeyDown = function() return true end
	local opened = NS:CompanionPet() == true and NS.treatMenu and NS.treatMenu:IsShown()
	local button = NS.treatMenu.buttons.bonbon
	Check("[TREAT] Maj + clic : le menu s'ouvre, pas de caresse, compteurs, sorte vide grisée", opened
		and NS.companionLastPet == nil and button.count:GetText() == "2" and (NS.treatMenu.buttons.festin.alpha or 1) < 1,
		button.count:GetText())
	button:Click()
	Check("[TREAT] clic sur une friandise : donnée", NS:TreatCount("bonbon") == 1 and button.count:GetText() == "1"
		and NS.companionBubbleKey == "TREAT_EAT_bonbon")
	NS:CompanionPet()
	local closed = not NS.treatMenu:IsShown()
	_G.IsShiftKeyDown = function() return false end
	NS:CompanionPet()
	Check("[TREAT] Maj + clic encore : fermé ; clic simple : la caresse, comme avant", closed and NS.companionLastPet ~= nil
		and not NS.treatMenu:IsShown())
	NS:TreatGrant("carte", { quiet = true })
	Check("[TREAT] menu à jour quand une friandise arrive", NS.treatMenu.buttons.carte.count:GetText() == "1")
end

-- 8. Répliques, icônes ----------------------------------------------------------------------------------
do
	Say("-- friandises : répliques")
	local strings = NS.COMPANION_LINE_STRINGS
	local missing = {}
	for name, keys in pairs(NS.TREAT_POOLS) do
		if NS.COMPANION_POOLS[name] ~= keys then missing[#missing + 1] = "réservoir " .. name end
		for _, key in ipairs(keys) do
			if not strings.fr[key] or not strings.en[key] then missing[#missing + 1] = key end
		end
	end
	Check("[TREAT] réservoirs enregistrés, répliques fr et en partout", #missing == 0, table.concat(missing, ", "))
	local bad = {}
	for _, kind in ipairs(NS.TREAT_KINDS) do
		if NS.COMPANION_POOLS["TREAT_EAT_" .. kind] == nil or NS.TREAT_ICONS[kind] == nil or NS.L["TREAT_DESC_" .. kind] == nil then
			bad[#bad + 1] = kind
		end
	end
	Check("[TREAT] chaque sorte : une bulle pour manger, une icône, une description", #bad == 0, table.concat(bad, ", "))
end

TR.Done()
