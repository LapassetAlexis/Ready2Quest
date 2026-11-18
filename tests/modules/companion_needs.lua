-- Compagnon 3.5.0 : des états, pas des jauges (fichier de référence des envies).
-- Trois états (Repu, Reposé, Éveillé) : plancher 70, un déclencheur les met à
-- 100 (45 min), une friandise à 110 (60 min), rien ne s'empile ; baisse au fil
-- du jeu ; migration (tout à 70, le moral s'en va) ; déclencheurs de chaque
-- état et ceux supprimés ; humeur au nombre d'états, Rayonnant (capture ×1,10,
-- brillantes ×1,20) ; une envie à la fois (+1 lien) ; le stade passe sur une
-- envie comblée ; infobulle d'un état, textes fr/en.
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

local ST = NS.COMPANION_STATE
local KEYS = { "hunger", "energy", "curiosity" }
local NE = { saved = {}, savedNS = {} }
for _, name in ipairs({ "UnitIsDead", "UnitClassification", "UnitOnTaxi", "IsInInstance" }) do NE.saved[name] = rawget(_G, name) end
for _, name in ipairs({ "AtCamp", "CompanionTrait", "SpecimenWornHere", "SpecimenBondAdd" }) do NE.savedNS[name] = rawget(NS, name) end
local savedRandom = math.random

function NE.Reset()
	ResetWorld()
	for name, fn in pairs(NE.savedNS) do NS[name] = fn end
	math.random = savedRandom
	NS.companionRT, NS.companionSession, NS.companionWishNext = nil, nil, nil
	NS.companionEating, NS.companionFed, NS.companionAtCamp = nil, nil, nil
	if NS.CompanionHuntReset then NS.CompanionHuntReset() end
	NS:CompanionData().tutoDone = true
	Mock.world.level = 20
	Mock.world.maps[1429] = { mapID = 1429, name = "Forêt d'Elwynn", parentMapID = 0 }
	Mock.world.mapID, Mock.world.subzone = 1429, "Clairière"
	Mock.world.target, Mock.world.taxi, Mock.world.instance = nil, false, false
	Mock.world.resting, Mock.world.auras, Mock.world.auraOrder = false, {}, {}
	_G.UnitIsDead = function(unit) return unit == "target" and Mock.world.target and Mock.world.target.dead end
	_G.UnitClassification = function(unit) return unit == "target" and Mock.world.target and Mock.world.target.class or "normal" end
	_G.UnitOnTaxi = function() return Mock.world.taxi end
	_G.IsInInstance = function() return Mock.world.instance end
	-- pas de caractère : la baisse de chaque état est la même
	NS.CompanionTrait = function() return nil end
	NE.All(ST.on)
end
function NE.Needs() return NS:CompanionData().needs end
function NE.All(value) for _, key in ipairs(KEYS) do NE.Needs()[key] = value end end
function NE.Get(key) return NE.Needs()[key or "curiosity"] end
function NE.Set(value) NE.Needs().curiosity = value end
function NE.Done()
	for name, fn in pairs(NE.saved) do _G[name] = fn end
	for name, fn in pairs(NE.savedNS) do NS[name] = fn end
	math.random = savedRandom
	ResetWorld()
end
local function Near(a, b) return math.abs((tonumber(a) or -1e9) - b) < 1e-6 end

do
	Say("-- états : constantes, migration, bornes")
	local S = Scenario("[NEED] états : constantes, migration, bornes")
	NE.Reset()
	S.ok("trois envies, le moral n'en est plus une", #NS.COMPANION_NEED_KEYS == 3 and NS.COMPANION_NEED_KEYS[1] == "hunger"
		and NS.COMPANION_NEED_KEYS[2] == "energy" and NS.COMPANION_NEED_KEYS[3] == "curiosity")
	S.ok("cotes : plancher 70, déclencheur 100, friandise 110, 45 min",
		ST.on == 70 and ST.full == 100 and ST.max == 110 and ST.minutes == 45 and Near(ST.rate, 30 / 45))
	S.ok("cotes : repos 120 s, chasse 15 en 10 min, envie toutes les 20 min, 2 min de grâce",
		ST.restSeconds == 120 and ST.huntKills == 15 and ST.huntWindow == 600 and ST.wishGap == 1200
		and ST.wishGrace == 120 and ST.wishSoon == 15 and ST.wishBond == 1 and ST.wishBondDaily == 3 and ST.schema == 2)
	S.ok("plus de plancher serein", NS.COMPANION_SERENE_FLOOR == nil)
	-- sauvegarde de la 3.4 : tout à 70, le moral s'en va, une seule fois
	local data = NS:CompanionData()
	data.needsV, data.needs = nil, { hunger = 95, energy = 90, mood = 80, curiosity = 100 }
	data = NS:CompanionData()
	S.ok("migration : aucun état d'office (tout à 70)", data.needs.hunger == 70 and data.needs.energy == 70
		and data.needs.curiosity == 70, data.needs.hunger)
	S.ok("migration : le moral retiré, version notée", data.needs.mood == nil and data.needsV == ST.schema)
	data.needs.hunger = 95
	S.ok("migration : une seule fois", NS:CompanionData().needs.hunger == 95)
	-- compagnon neuf : départ à 70
	ResetWorld()
	data = NS:CompanionData()
	S.ok("compagnon neuf : départ à 70, aucun état", data.needs.hunger == 70 and data.needs.energy == 70
		and data.needs.curiosity == 70 and data.needsV == ST.schema and NS:CompanionStatesOn() == 0)
	-- bornes : une valeur corrompue revient entre 70 et 110
	data.needs.hunger, data.needs.energy = -40, 500
	data = NS:CompanionData()
	S.ok("sauvegarde corrompue ramenée entre 70 et 110", data.needs.hunger == 70 and data.needs.energy == 110,
		data.needs.hunger .. "/" .. data.needs.energy)
	-- le moral : plus rien
	NE.Reset()
	NS:CompanionAdd("mood", 50)
	S.ok("CompanionAdd(« mood ») : rien", NE.Needs().mood == nil and NS:CompanionStatesOn() == 0)
	S.ok("CompanionGrant(« mood ») : rien", NS:CompanionGrant("mood") == false and NE.Needs().mood == nil)
	S.done()
end

do
	Say("-- états : durées, rien ne s'empile, baisse")
	local S = Scenario("[NEED] états : durées, rien ne s'empile, baisse")
	NE.Reset()
	local fired = {}
	NS:RegisterCallback("COMPANION_STATE", function(_, key, was) fired[#fired + 1] = key .. ":" .. tostring(was) end)
	S.ok("éteint : 0 min", not NS:CompanionStateOn("hunger") and NS:CompanionStateMinutes("hunger") == 0)
	S.ok("déclencheur : l'état s'allume (100)", NS:CompanionGrant("hunger") == true and NE.Get("hunger") == 100
		and NS:CompanionStateOn("hunger"))
	S.ok("… pour 45 minutes", Near(NS:CompanionStateMinutes("hunger"), 45), NS:CompanionStateMinutes("hunger"))
	S.ok("… et le signale (COMPANION_STATE, était éteint)", fired[1] == "hunger:false", fired[1])
	S.ok("un second déclencheur à plein : rien ne s'empile", NS:CompanionGrant("hunger") == false and NE.Get("hunger") == 100)
	S.ok("une friandise : 110, 60 minutes", NS:CompanionGrant("hunger", ST.max) == true and NE.Get("hunger") == 110
		and Near(NS:CompanionStateMinutes("hunger"), 60))
	S.ok("… signalée (était actif)", fired[2] == "hunger:true", fired[2])
	S.ok("jamais au-dessus de 110", NS:CompanionGrant("hunger", 500) == false and NE.Get("hunger") == 110)
	S.ok("un déclencheur ne raccourcit pas une friandise", NS:CompanionGrant("hunger") == false and NE.Get("hunger") == 110)
	-- l'ancien appel chiffré : un gain obtient l'état, une perte le raccourcit
	NS:CompanionAdd("energy", 3)
	S.ok("CompanionAdd(+3) : l'état entier (100), pas +3", NE.Get("energy") == 100, NE.Get("energy"))
	NS:CompanionAdd("energy", -10)
	S.ok("CompanionAdd(-10) : 10 de moins", NE.Get("energy") == 90, NE.Get("energy"))
	NS:CompanionAdd("energy", -500)
	S.ok("… jamais sous 70", NE.Get("energy") == 70)
	-- baisse : 30 / 45 par minute de jeu
	NE.All(ST.full)
	NS:CompanionTick(60)
	S.ok("une minute de jeu : 0,667 de moins", Near(NE.Get("hunger"), 100 - 30 / 45), NE.Get("hunger"))
	NS:CompanionTick(44 * 60)
	S.ok("45 minutes : l'état s'éteint (70)", Near(NE.Get("hunger"), 70) and not NS:CompanionStateOn("hunger"), NE.Get("hunger"))
	NS:CompanionTick(3 * 3600)
	S.ok("3 h de plus : rien sous 70", NE.Get("hunger") == 70 and NE.Get("energy") == 70 and NE.Get("curiosity") == 70)
	NS:CompanionGrant("curiosity", ST.max)
	NS:CompanionTick(59 * 60)
	S.ok("friandise : encore allumé après 59 min", NS:CompanionStateOn("curiosity"), NE.Get("curiosity"))
	NS:CompanionTick(61)
	S.ok("… éteint après 60", not NS:CompanionStateOn("curiosity"), NE.Get("curiosity"))
	-- état préféré du caractère (×0,7) : il dure plus longtemps
	NS.CompanionTrait = function() return "glutton" end
	NS:CompanionGrant("hunger")
	S.ok("état préféré : ~64 minutes au lieu de 45", Near(NS:CompanionStateMinutes("hunger"), 45 / NS.PERSONALITY_DECAY)
		and NS.PERSONALITY_DECAY == 0.7, NS:CompanionStateMinutes("hunger"))
	NE.Reset()
	S.done()
end

do
	Say("-- Repu : repas, Bien nourri, départ")
	local S = Scenario("[NEED] Repu : repas, Bien nourri, départ ; pas la boisson")
	NE.Reset()
	Mock.world.auraOrder, Mock.world.auras = { 430 }, { [430] = { name = "Boisson", duration = 30 } }
	NS:CompanionCheckAuras()
	S.ok("boisson seule : rien", NE.Get("hunger") == 70, NE.Get("hunger"))
	Mock.world.auraOrder, Mock.world.auras = {}, {}
	NS:CompanionCheckAuras()
	Mock.world.auraOrder, Mock.world.auras = { 433 }, { [433] = { name = "Nourriture", duration = 30 } }
	NS:CompanionCheckAuras()
	S.ok("début d'un repas : Repu", NE.Get("hunger") == 100, NE.Get("hunger"))
	NE.Needs().hunger = 80
	NS:CompanionCheckAuras()
	S.ok("même repas : compté une fois", NE.Get("hunger") == 80)
	NS:CompanionTick(5 * 60)
	S.ok("pendant le repas : rien de plus (pas de remontée au fil du repas)", NE.Get("hunger") < 80, NE.Get("hunger"))
	Mock.world.auraOrder, Mock.world.auras = {}, {}
	NS:CompanionCheckAuras()
	NE.Needs().hunger = 70
	Mock.world.auraOrder, Mock.world.auras = { 19705 }, { [19705] = { name = "Bien nourri", duration = 900 } }
	NS:CompanionCheckAuras()
	S.ok("gain de « Bien nourri » : Repu", NE.Get("hunger") == 100, NE.Get("hunger"))
	Mock.world.auraOrder, Mock.world.auras = {}, {}
	NS:CompanionCheckAuras()
	-- départ (Ready2Quest) : avec de la nourriture
	NE.Needs().hunger = 70
	NS:FireCallback("DEPARTURE", { name = "Comté-de-l'Or" })
	S.ok("départ sans vivres : rien", NE.Get("hunger") == 70)
	Mock.world.itemInfo[117] = { classID = 0, subClassID = 5 }
	Mock.world.bags[0].items[1] = { itemID = 117, stackCount = 5 }
	NS:FireCallback("DEPARTURE", { name = "Comté-de-l'Or" })
	S.ok("départ avec vivres : Repu", NE.Get("hunger") == 100, NE.Get("hunger"))
	NE.All(70)
	NS:FireCallback("RETURN", { name = "Comté-de-l'Or" })
	S.ok("retour en ville : aucun état", NS:CompanionStatesOn() == 0)
	S.done()
end

do
	Say("-- Reposé : 120 s cumulées, camp, auberge")
	local S = Scenario("[NEED] Reposé : 120 s cumulées au repos, camp, tampon d'auberge")
	NE.Reset()
	local need = ST.restSeconds / NS:CompanionRestSpeed()
	S.ok("sans effet : 120 s", need == 120, need)
	Mock.world.resting = true
	NS:CompanionTick(60)
	S.ok("60 s au repos : pas encore", NE.Get("energy") == 70)
	Mock.world.resting = false
	NS:CompanionTick(600)
	S.ok("hors repos : rien", NE.Get("energy") == 70)
	Mock.world.resting = true
	NS:CompanionTick(60)
	S.ok("120 s cumulées (60 + 60) : Reposé", NE.Get("energy") == 100, NE.Get("energy"))
	S.ok("… le compteur repart", (NS.companionRT.restSec or 0) == 0, NS.companionRT.restSec)
	NS:CompanionTick(60); NS:CompanionTick(60)
	S.ok("encore au repos : pas plus de 100 (rien ne s'empile)", NE.Get("energy") <= 100, NE.Get("energy"))
	NE.Needs().energy = 80
	NS:CompanionTick(60); NS:CompanionTick(60)
	S.ok("deux minutes de plus au repos : de nouveau 45 minutes", NE.Get("energy") == 100, NE.Get("energy"))
	-- somnolent : le repos ne compte pas
	NE.Reset()
	Mock.world.resting = true
	NS:CompanionData().sleepy = true
	NS:CompanionTick(60); NS:CompanionTick(60)
	S.ok("somnolent : le repos ne compte pas", NE.Get("energy") == 70)
	NS:CompanionData().sleepy = nil
	-- effet « rest » : les 120 s se divisent
	NE.Reset()
	NS.CompanionRestSpeed = function() return 2 end
	Mock.world.resting = true
	NS:CompanionTick(60)
	NS.CompanionRestSpeed = nil
	S.ok("effet « rest » (×2) : 60 s suffisent", NE.Get("energy") == 100, NE.Get("energy"))
	-- arrivée à un camp
	NE.Reset()
	local camp = false
	NS.AtCamp = function() return camp end
	NS:CompanionCheckAuras()
	camp = true
	NS:CompanionCheckAuras()
	S.ok("arrivée à un camp : Reposé", NE.Get("energy") == 100, NE.Get("energy"))
	NE.Needs().energy = 80
	NS:CompanionCheckAuras()
	S.ok("rester au camp : une fois", NE.Get("energy") == 80)
	S.ok("au camp : CompanionResting", NS:CompanionResting() == true)
	-- tampon d'auberge du jour
	NE.Reset()
	S.ok("tampon d'auberge du jour : Reposé", NS:InnStamp() ~= nil and NE.Get("energy") == 100, NE.Get("energy"))
	NE.Needs().energy = 70
	NS:InnStamp()
	S.ok("… une fois par jour", NE.Get("energy") == 70)
	S.done()
end

do
	Say("-- Éveillé : nouveauté, donjon, élite, coffre")
	local S = Scenario("[NEED] Éveillé : zone, lieu, tampon nouveaux, donjon, élite, coffre")
	NE.Reset()
	local data = NS:CompanionData()
	NS:CompanionOnZone(true)
	S.ok("zone nouvelle : Éveillé", NE.Get() == 100 and data.seenZones[1429], NE.Get())
	NE.Set(70)
	data.zoneVisit = { [1429] = Mock.now - 3 * 3600 }
	NS:CompanionOnZone(true)
	S.ok("zone déjà vue, même pas depuis 3 h : rien", NE.Get() == 70, NE.Get())
	data.seenSub["1429:Clairière"] = nil
	NS:CompanionOnZone(false)
	S.ok("sous-zone nouvelle : Éveillé", NE.Get() == 100, NE.Get())
	NE.Set(70)
	data.seenSub["1429:Bosquet"] = true
	Mock.world.subzone = "Bosquet"
	NS:CompanionOnZone(false)
	Mock.now = Mock.now + 60
	Mock.world.subzone = "Clairière"
	NS:CompanionOnZone(false)
	S.ok("bouger d'une sous-zone connue à l'autre : rien", NE.Get() == 70, NE.Get())
	-- tampon nouveau
	NS:FireCallback("STAMP", { id = "zone:1519", kind = "zone", name = "Hurlevent", new = true })
	S.ok("tampon nouveau : Éveillé", NE.Get() == 100, NE.Get())
	-- donjon : pas deux fois en 10 minutes
	NE.Reset()
	data = NS:CompanionData()
	data.seenZones[1429] = true
	Mock.world.instance = true
	NS:CompanionOnZone(true)
	S.ok("entrée en donjon : Éveillé", NE.Get() == 100, NE.Get())
	NE.Set(70)
	NS:CompanionOnZone(true)
	S.ok("allers-retours de la porte : rien", NE.Get() == 70, NE.Get())
	Mock.now = Mock.now + NS.COMPANION_CURIOSITY.dungeonGap + 1
	NS:CompanionOnZone(true)
	S.ok("nouvelle entrée 10 min plus tard : de nouveau", NE.Get() == 100 and NS.COMPANION_CURIOSITY.dungeonGap == 600, NE.Get())
	-- élite ou rare
	NE.Reset()
	Mock.world.target = { dead = true, class = "elite" }
	NS:CompanionOnKill()
	S.ok("élite vaincu : Éveillé", NE.Get() == 100, NE.Get())
	NE.Set(70)
	Mock.now = Mock.now + 5
	Mock.world.target = { dead = true, class = "rare" }
	NS:CompanionOnKill()
	S.ok("rare vaincu : Éveillé", NE.Get() == 100, NE.Get())
	NE.Set(70)
	Mock.now = Mock.now + 5
	Mock.world.target = { dead = true, class = "normal" }
	NS:CompanionOnKill()
	S.ok("ennemi ordinaire : rien", NE.Get() == 70)
	-- coffre de zone
	NE.Reset()
	NS:ChestData()[9001] = { tier = 1, name = "Vallon", at = 0 }
	local reward
	for _, r in ipairs(NS:ChestOptions(1)) do reward = reward or r end
	S.ok("coffre ouvert : Éveillé", reward and NS:ChestPick(9001, reward) == true and NE.Get() == 100, NE.Get())
	NS:ChestData()[9001] = nil
	S.done()
end

do
	Say("-- Éveillé : chasse, cueillette (Curieux), ce qui ne donne plus rien")
	local S = Scenario("[NEED] Éveillé : chasse, Curieux à la cueillette ; vol et récolte ordinaires : rien")
	NE.Reset()
	S.ok("hors mode chasse : les tués ne comptent pas", NS:CompanionHuntCount() == false)
	NS:DB().captureHuntOn, NS:DB().captureHuntUntil = true, nil
	local got = false
	for _ = 1, 14 do got = got or NS:CompanionHuntCount() end
	S.ok("chasse : 14 créatures, pas encore", not got and NE.Get() == 70)
	S.ok("… la 15e : Éveillé", NS:CompanionHuntCount() == true and NE.Get() == 100, NE.Get())
	NE.Set(70)
	for _ = 1, 14 do NS:CompanionHuntCount() end
	S.ok("le compte repart après l'état", NE.Get() == 70)
	Mock.now = Mock.now + ST.huntWindow + 1
	NS:CompanionHuntCount()
	S.ok("au-delà de 10 minutes : les anciennes ne comptent plus", NE.Get() == 70, NE.Get())
	NE.Reset()
	NS:DB().captureHuntOn = true
	Mock.world.target = { dead = true, class = "normal" }
	for _ = 1, 15 do Mock.now = Mock.now + 5; NS:CompanionOnKill() end
	S.ok("chasse : 15 tués (CompanionOnKill) en 10 minutes : Éveillé", NE.Get() == 100, NE.Get())
	NS:DB().captureHuntOn = nil
	-- vol en griffon : plus rien
	NE.Reset()
	Mock.world.taxi = true
	NS:CompanionTick(10)
	Mock.world.taxi = false
	NS:CompanionTick(10)
	S.ok("arrivée en griffon : rien", NE.Get() == 70, NE.Get())
	-- récolte : seulement pour un Curieux
	local itemID = next(NS.GATHERING_ITEMS)
	NS:GatheringRecord(itemID, 1, 1429)
	S.ok("ressource récoltée : rien", NE.Get() == 70, NE.Get())
	NS.CompanionTrait = function() return "curious" end
	NS:GatheringRecord(itemID, 1, 1429)
	S.ok("Curieux : la cueillette l'éveille", NE.Get() == 100, NE.Get())
	S.done()
end

do
	Say("-- ce qui ne donne plus rien")
	local S = Scenario("[NEED] gains supprimés : caresse, quête, niveau, butin, mission")
	NE.Reset()
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	NE.All(70)
	NS.companionLastPet = nil
	NS:CompanionPet()
	S.ok("caresse : aucun état", NS:CompanionStatesOn() == 0)
	Mock:Fire("QUEST_TURNED_IN", 123, 500, 0)
	S.ok("quête rendue : aucun état", NS:CompanionStatesOn() == 0)
	Mock:Fire("CHAT_MSG_LOOT", "Vous recevez le butin : |cff0070dd|Hitem:4444::::::::|h[Épée bleue]|h|r.")
	S.ok("butin rare : aucun état", NS:CompanionStatesOn() == 0)
	NS:CompanionOnLevel(21)
	S.ok("niveau : aucun état", NS:CompanionStatesOn() == 0)
	S.ok("moral : aucune trace", NE.Needs().mood == nil)
	S.ok("plus de remontée continue au repos", NS.COMPANION_RULES.restGain == 0)
	S.done()
end

do
	Say("-- humeur, Rayonnant")
	local S = Scenario("[NEED] humeur au nombre d'états ; Rayonnant ×1,10 / ×1,20")
	NE.Reset()
	local moods = {}
	for n = 0, 3 do
		NE.All(70)
		for i = 1, n do NE.Needs()[KEYS[i]] = 100 end
		moods[#moods + 1] = NS:CompanionMood()
		local _, ok = NS:CompanionEffectNeeds()
		S.ok("effets entiers (" .. n .. " état(s))", (NS:CompanionEffectNeeds()) == 1 and ok == n)
	end
	S.ok("0 calme, 1 content, 2 joyeux, 3 rayonnant", table.concat(moods, ",") == "calm,happy,joyful,radiant", table.concat(moods, ","))
	S.ok("Rayonnant : les trois", NS:CompanionRadiant() == true and NS:CompanionStatesOn() == 3)
	NS:CompanionData().sleepy = true
	S.ok("somnolent : l'humeur dit somnolent, pas Rayonnant", NS:CompanionMood() == "sleepy" and not NS:CompanionRadiant())
	NS:CompanionData().sleepy = nil
	S.ok("bonus : ×1,10 et ×1,20", NS.COMPANION_RADIANT.capture == 1.10 and NS.COMPANION_RADIANT.shiny == 1.20)
	local info = { class = "normal", level = 20 }
	NE.All(70)
	local plain, plainShiny = NS:CaptureChance(info, nil, 20), NS:ShinyChance("normal", 0)
	NE.All(100)
	local radiant, radiantShiny = NS:CaptureChance(info, nil, 20), NS:ShinyChance("normal", 0)
	S.ok("Rayonnant : capture ×1,10", Near(radiant, math.min(NS.CAPTURE_MAX, plain * 1.10)), plain .. " -> " .. radiant)
	S.ok("Rayonnant : brillantes ×1,20", Near(radiantShiny, plainShiny * 1.20), plainShiny .. " -> " .. radiantShiny)
	local boss = { class = "normal", level = 1 }
	S.ok("Rayonnant : jamais au-dessus du plafond de capture", NS:CaptureChance(boss, "lasso", 60) <= NS.CAPTURE_MAX + 1e-9)
	local sure, isSure = NS:CaptureChance({ class = "worldboss", level = 63 }, "sifflet", 20)
	NE.All(70)
	local sure0 = NS:CaptureChance({ class = "worldboss", level = 63 }, "sifflet", 20)
	S.ok("capture sûre : inchangée", sure == sure0, tostring(sure) .. "/" .. tostring(isSure))
	S.done()
end

do
	Say("-- son envie : une à la fois")
	local S = Scenario("[NEED] envie unique : choix, délais, comblée (+1 lien)")
	NE.Reset()
	S.ok("pas d'envie dans les 2 minutes après la connexion", NS:CompanionWishTick() == nil and NS:CompanionWish() == nil)
	Mock.now = Mock.now + ST.wishGrace + 1
	local key = NS:CompanionWishTick()
	S.ok("après 2 minutes : une envie", key ~= nil and NS:CompanionWish() == key and NS:CompanionData().wish.key == key, key)
	S.ok("la ligne « Envie : … »", NS:CompanionWishLine() == NS:F("COMP_WISH_LINE", NS.L["COMP_WISH_" .. tostring(key)]),
		NS:CompanionWishLine())
	S.ok("une seule à la fois", NS:CompanionWishTick(true) == nil and NS:CompanionWish() == key)
	-- le choix : un état éteint
	NE.Needs().hunger, NE.Needs().energy = 100, 100
	S.ok("deux actifs : l'envie vise le troisième", NS:CompanionWishPick() == "curiosity")
	NE.All(100)
	S.ok("les trois actifs, plus de 15 min : rien", NS:CompanionWishPick() == nil)
	NE.Needs().energy = 70 + 10 * ST.rate
	S.ok("les trois actifs : celui qui a moins de 15 min", NS:CompanionWishPick() == "energy")
	-- préféré du caractère : compte double
	NE.All(70)
	math.random = function() return 0.45 end
	local plain = NS:CompanionWishPick()
	NS.CompanionTrait = function() return "glutton" end
	local glutton = NS:CompanionWishPick()
	math.random = savedRandom
	NS.CompanionTrait = function() return nil end
	S.ok("l'état préféré du caractère compte double", plain == "energy" and glutton == "hunger", tostring(plain) .. "/" .. tostring(glutton))
	-- comblée sans spécimen : ses états actifs repartent à plein
	NE.Reset()
	NS:CompanionWishTick(true)
	local wish = NS:CompanionWish()
	local other = wish == "hunger" and "energy" or "hunger"
	NE.Needs()[other] = 80
	NS:CompanionGrant(wish)
	S.ok("l'état obtenu comble l'envie", NS:CompanionWish() == nil, wish)
	S.ok("sans lien (mascotte) : ses états actifs repartent à plein", NE.Get(other) == 100, NE.Get(other))
	S.ok("la suivante dans 20 minutes", NS.companionWishNext == Mock.now + ST.wishGap, NS.companionWishNext)
	S.ok("pas avant", NS:CompanionWishTick() == nil)
	NE.All(70)
	Mock.now = Mock.now + ST.wishGap + 1
	S.ok("… puis une nouvelle", NS:CompanionWishTick() ~= nil)
	-- ignorée : rien ne se perd
	local before = NS:CompanionStatesOn()
	NS:CompanionTick(3600)
	S.ok("ignorée : rien de perdu, elle reste", NS:CompanionWish() ~= nil and NS:CompanionStatesOn() == before)
	-- comblée avec un spécimen porté : +1 lien, 3 par jour hors du plafond du jour
	NE.Reset()
	local bonds = {}
	NS.SpecimenWornHere = function() return { id = 1 } end
	NS.SpecimenBondAdd = function(_, source, n) bonds[#bonds + 1] = source .. ":" .. tostring(n); return n end
	NS:CompanionWishTick(true)
	wish = NS:CompanionWish()
	NE.Needs()[wish == "hunger" and "energy" or "hunger"] = 80
	NS:CompanionGrant(wish)
	S.ok("spécimen porté : +1 lien (source « wish »)", bonds[1] == "wish:1", bonds[1])
	S.ok("… ses états ne bougent pas", NE.Get(wish == "hunger" and "energy" or "hunger") == 80)
	local rule = NS.BOND_SOURCES.wish
	S.ok("règle du lien : 1 point, 3 par jour, hors plafond du jour", rule and rule.gain == 1 and rule.cap == 3 and rule.outside == true)
	-- somnolent : pas d'envie
	NE.Reset()
	NS:CompanionData().sleepy = true
	S.ok("somnolent : pas d'envie", NS:CompanionWishTick(true) == nil)
	NS:CompanionData().sleepy = nil
	S.done()
end

do
	Say("-- stade : le niveau ouvre, une envie comblée le franchit")
	local S = Scenario("[NEED] stade : le niveau, puis une envie comblée")
	NE.Reset()
	local data = NS:CompanionData()
	Mock.world.level = 15
	data.stage, data.stageReady, data.stageWish = 1, nil, nil
	NE.All(100)
	NS:CompanionCheckStage(15, false)
	S.ok("niveau atteint, trois états : le stade attend quand même", data.stage == 1 and data.stageReady == 2, data.stageReady)
	S.ok("pas « heureux » sans envie comblée", not NS:CompanionIsHappy() and NS:CompanionHappyCount() == 3)
	local goal
	for _, item in ipairs(NS:CompanionNextUnlocks()) do if item.kind == "stage" then goal = item end end
	S.ok("objectif : une envie comblée (0 / 1)", goal and goal.stat == "wish" and goal.have == 0 and goal.need == 1, goal and goal.stat)
	S.ok("message : plus de pourcentage", not NS.L.COMP_MSG_READY:find("%d", 1, true))
	NE.All(70)
	NS:CompanionWishTick(true)
	NS:CompanionGrant(NS:CompanionWish())
	S.ok("envie comblée : le stade passe", data.stage == 2 and data.stageReady == nil and data.stageWish == nil, data.stage)
	-- une envie comblée AVANT le niveau ne compte pas
	NE.Reset()
	data = NS:CompanionData()
	Mock.world.level = 5
	data.stage, data.stageReady, data.stageWish = 1, nil, nil
	NS:CompanionWishTick(true)
	NS:CompanionGrant(NS:CompanionWish())
	S.ok("envie comblée avant le niveau : rien de gardé", data.stageWish == nil)
	Mock.world.level = 15
	NS:CompanionCheckStage(15, false)
	S.ok("… le niveau ouvre, il attend une envie", data.stage == 1 and data.stageReady == 2)
	data.stageWish = true
	data.sleepy = true
	S.ok("somnolent : pas encore", not NS:CompanionIsHappy())
	data.sleepy = nil
	S.ok("réveillé : prêt", NS:CompanionIsHappy())
	S.done()
end

do
	Say("-- infobulle d'un état, teintes, textes")
	local S = Scenario("[NEED] infobulle d'un état, teintes, textes fr/en")
	NE.Reset()
	local L = NS.L
	local lines = NS:NeedTooltipLines("curiosity")
	S.ok("éteint : « Éveillé : éteint »", lines[1] == NS:F("JRN_STATE_TIP_OFF", L.COMP_STATE_curiosity), lines[1])
	S.ok("ce qui l'allume (45 minutes), 3 lignes", lines[2] == L.JRN_STATE_TIP_HOW
		and lines[3] == "- " .. L.JRN_STATE_curiosity_1 and lines[5] == "- " .. L.JRN_STATE_curiosity_3)
	S.ok("sa friandise (60 minutes)", lines[6] == NS:F("JRN_STATE_TIP_TREAT", NS:TreatLabel("carte")), lines[6])
	S.ok("le temps ne passe qu'en jeu", lines[#lines] == L.JRN_STATE_TIP_DECAY)
	NS:CompanionGrant("curiosity")
	local on, active = NS:NeedTooltipLines("curiosity")
	S.ok("allumé : « encore 45 min »", active == true and on[1] == NS:F("JRN_STATE_TIP_ON", L.COMP_STATE_curiosity, 45), on[1])
	S.ok("Repu : 2 lignes, Reposé : 3", #NS:NeedTooltipLines("hunger") == #lines - 1 and #NS:NeedTooltipLines("energy") == #lines)
	local _, _, tierOn = NS.NeedTier(71)
	local _, _, tierOff = NS.NeedTier(70)
	S.ok("teinte : actif vert, éteint gris", tierOn == "happy" and tierOff == "mid")
	local fr, en = NS.JOURNAL_WINDOW_STRINGS.fr, NS.JOURNAL_WINDOW_STRINGS.en
	local states = NS.COMPANION_STATE_STRINGS
	local missing = {}
	for _, k in ipairs({ "JRN_STATE_TIP_ON", "JRN_STATE_TIP_OFF", "JRN_STATE_TIP_HOW", "JRN_STATE_TIP_TREAT", "JRN_STATE_TIP_DECAY",
		"JRN_STATE_hunger_1", "JRN_STATE_hunger_2", "JRN_STATE_energy_1", "JRN_STATE_energy_2", "JRN_STATE_energy_3",
		"JRN_STATE_curiosity_1", "JRN_STATE_curiosity_2", "JRN_STATE_curiosity_3", "JRN_WISH_NONE" }) do
		if not (fr[k] and en[k]) then missing[#missing + 1] = k end
	end
	for k in pairs(states.fr) do if not states.en[k] then missing[#missing + 1] = k end end
	S.ok("textes en français et en anglais", #missing == 0, table.concat(missing, ","))
	S.ok("noms des états", states.fr.COMP_STATE_hunger == "Repu" and states.fr.COMP_STATE_energy == "Reposé"
		and states.fr.COMP_STATE_curiosity == "Éveillé")
	NE.Done()
	S.done()
end
