-- Compagnon : caractère (Personality.lua, PersonalityLines.lua). Formé par la
-- façon de jouer en 3 h, annoncé ; caractères d'apparence (option « Caractère :
-- apparence / le sien »), qui restent au choix une fois portés ; répliques
-- propres, envie préférée, remarques, ampleur des effets ; page de réglages.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local PE = { saved = {}, random = math.random }
local GLOBALS = { "IsResting", "GetGameTime", "UnitHealth", "UnitHealthMax", "UnitAffectingCombat", "GetMoney",
	"UnitIsDead", "UnitClassification", "IsInInstance" }
for _, name in ipairs(GLOBALS) do PE.saved[name] = rawget(_G, name) end

function PE.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.personaState, NS.companionFx = nil, nil, nil, nil
	NS.companionLastPet, NS.companionEating = nil, nil
	PE.Quiet()
	NS:CompanionData().tutoDone = true
	local w = Mock.world
	w.level, w.mapID, w.subzone = 20, 20, "Clairière"
	w.resting, w.hour, w.health, w.money, w.target, w.combat = false, 12, 100, 0, nil, false
	_G.IsResting = function() return w.resting end
	_G.GetGameTime = function() return w.hour, 0 end
	_G.UnitHealth = function() return w.health end
	_G.UnitHealthMax = function() return 100 end
	_G.UnitAffectingCombat = function() return w.combat end
	_G.GetMoney = function() return w.money end
	_G.UnitIsDead = function(unit) return unit == "target" and w.target and w.target.dead end
	_G.UnitClassification = function(unit) return unit == "target" and w.target and w.target.class or "normal" end
	_G.IsInInstance = function() return false end
	math.random = PE.random
	NS:CompanionUpdateVisibility()
end
function PE.Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	if NS.companionRT then NS.companionRT.cool = {} end
end
function PE.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = PE.saved[name] end
	math.random = PE.random
	ResetWorld()
end
function PE.Form(trait)
	local persona = NS:PersonaData()
	persona.formed = trait
	return persona
end

-- 1. Formation -----------------------------------------------------------------------------
do
	Say("-- caractère : formation")
	PE.Reset()
	Check("[PERS] au début : pas de caractère", NS:CompanionTrait() == nil and NS:PersonaLabel(nil) == "Pas encore formé")
	NS:CompanionPet()
	local persona = NS:PersonaData()
	Check("[PERS] caresse : Câlin +2", persona.scores.cuddly == 2, persona.scores.cuddly)
	Mock:Advance(20)
	NS:CompanionPet()
	Check("[PERS] caresse refusée (trop tôt) : rien", persona.scores.cuddly == 4)
	NS:CompanionPet()
	Check("[PERS] … pas compté deux fois", persona.scores.cuddly == 4, persona.scores.cuddly)

	local savedState = NS.CompanionAuraState
	NS.CompanionAuraState = function() return true, false, false end
	NS:CompanionCheckAuras()
	NS:CompanionCheckAuras()
	Check("[PERS] repas : Gourmand +3, une fois par repas", persona.scores.glutton == 3, persona.scores.glutton)
	NS.CompanionAuraState = savedState
	NS.companionEating = nil

	NS:CompanionOnKill()
	NS:CompanionOnKill()
	Check("[PERS] ennemi vaincu : Téméraire, une fois par mort", math.abs(persona.scores.daring - 0.15) < 1e-6, persona.scores.daring)
	Mock.world.target = { dead = true, class = "elite" }
	Mock:Advance(3)
	NS:CompanionOnKill()
	Check("[PERS] élite vaincu : Téméraire +2 de plus", math.abs(persona.scores.daring - 2.3) < 1e-6, persona.scores.daring)
	Mock.world.target = nil
	local curious = persona.scores.curious or 0
	NS:CompanionAdd("curiosity", 20)
	Check("[PERS] curiosité nourrie : Curieux", math.abs(persona.scores.curious - curious - 2) < 1e-6, persona.scores.curious)
	NS:CompanionAdd("curiosity", -5)
	Check("[PERS] une baisse ne compte pas", math.abs(persona.scores.curious - curious - 2) < 1e-6)
	NS:CompanionOnDead()
	Check("[PERS] mort : Taquin +6", persona.scores.teasing == 6)
	Mock.world.resting = true
	NS:CompanionTick(600)
	Check("[PERS] repos : Paresseux (10 min : +2,5)", math.abs(persona.scores.lazy - 2.5) < 1e-6, persona.scores.lazy)
	Mock.world.resting = false
	Check("[PERS] temps observé", persona.played >= 600 and persona.played < 700 and not persona.formed, persona.played)

	NS:ToggleOptions()
	NS:SelectOptionsPage("companionCharacter")
	local pick
	for _, r in ipairs(NS.optionsFrame.rows) do if r.def and r.def.key == "companionTraitPick" then pick = r end end
	Check("[PERS] réglages : il se forme (5 %)", pick and pick.note.text:find("5 %", 1, true), pick and pick.note.text)
	NS.optionsFrame:Hide()

	Mock.output = {}
	PE.Quiet()
	NS:CompanionTick(NS.PERSONALITY_FORM_AFTER)
	Check("[PERS] 3 h de jeu : il annonce son caractère (le plus fort : Taquin)", persona.formed == "teasing"
		and NS.companionBubbleKey == "FORMED__teasing" and Mock:Output():find("Taquin", 1, true), Mock:Output())
	NS:CompanionPet()
	Check("[PERS] formé : il ne change plus", persona.scores.cuddly == 4 and NS:CompanionTrait() == "teasing")
	local before = persona.played
	NS:CompanionTick(60)
	Check("[PERS] formé : on ne compte plus le temps", persona.played == before)

	PE.Reset()
	NS:CompanionTick(NS.PERSONALITY_FORM_AFTER)
	Check("[PERS] rien observé : Curieux par défaut", NS:PersonaData().formed == "curious")
	PE.Done()
end

-- 2. Ce qu'il change -----------------------------------------------------------------------
do
	Say("-- caractère : répliques, goûts, mouvements")
	PE.Reset()
	PE.Form("glutton")
	math.random = function(a) if a then return 1 end return 0 end     -- toujours sa version
	Check("[PERS] sa version d'une réplique", NS:CompanionPick("EAT", nil):find("__glutton", 1, true) ~= nil)
	Check("[PERS] avec ses arguments", NS:CompanionPick("LEVEL", { 12 }):find("LEVEL__glutton", 1, true) ~= nil)
	math.random = function(a) if a then return 1 end return 0.99 end
	Check("[PERS] parfois la réplique commune", NS:CompanionPick("EAT", nil):find("__", 1, true) == nil)
	math.random = function(a) if a then return 1 end return 0 end
	Check("[PERS] réservoir sans version propre : la commune", NS:CompanionPick("NPC_banker", nil):find("__", 1, true) == nil)
	PE.Quiet()
	NS:CompanionSay("LEVEL", { args = { 12 } })
	Check("[PERS] la bulle dit sa version, nombre compris", NS.companionBubbleText:find("12", 1, true)
		and NS.companionBubbleLine:find("LEVEL__glutton", 1, true), NS.companionBubbleText)
	math.random = PE.random

	local needs = NS:CompanionData().needs
	needs.hunger, needs.curiosity = 40, 40
	NS:CompanionAdd("hunger", 10)
	NS:CompanionAdd("curiosity", 10)
	Check("[PERS] Gourmand : la faim monte 50 % plus vite, pas le reste", needs.hunger == 55 and needs.curiosity == 50,
		needs.hunger .. "/" .. needs.curiosity)
	needs.hunger, needs.curiosity = 80, 80
	NS:CompanionTick(600)
	local hungerDrop, curiosityDrop = 80 - needs.hunger, 80 - needs.curiosity
	Check("[PERS] … et baisse moins vite (×0,7)", math.abs(hungerDrop - 0.6 * 10 * 0.7) < 1e-6
		and math.abs(curiosityDrop - 0.5 * 10) < 1e-6, hungerDrop .. "/" .. curiosityDrop)

	local hover = NS:EnsureCompanionHover()
	NS:CompanionRefreshHover()
	Check("[PERS] infobulle : son caractère", hover.sub.text:find("Gourmand", 1, true), hover.sub.text)

	-- ampleur des effets
	local frame = NS:EnsureCompanionFrame()
	local function Peak()
		NS:CompanionFx("bounce")
		Mock:Advance(0.15)
		local y = frame.model and frame.model.lastPoint and frame.model.lastPoint.y or frame.fallback.lastPoint.y
		Mock:Advance(1)
		return y
	end
	PE.Form("daring")
	local daring = Peak()
	PE.Form("lazy")
	local lazy = Peak()
	Check("[PERS] Téméraire bondit plus haut que Paresseux", daring > lazy + 3, daring .. " / " .. lazy)
	PE.Done()
end

-- 3. Caractères d'apparence et réglages -----------------------------------------------------
do
	Say("-- caractère : apparences et réglages")
	PE.Reset()
	PE.Form("curious")
	local data = NS:CompanionData()
	data.appearance = "owl"
	Check("[PERS] chouette : Sage", NS:CompanionTrait() == "wise" and NS:PersonaData().unlocked.wise == true)
	NS:DB().companionTraitSource = 2
	Check("[PERS] « le sien » : Curieux, même en chouette", NS:CompanionTrait() == "curious")
	NS:DB().companionTraitSource = 1
	data.appearance = "frog"
	Check("[PERS] apparence sans caractère : le sien", NS:CompanionTrait() == "curious")

	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companionCharacter")
	local source, pick
	for _, r in ipairs(NS.optionsFrame.rows) do
		if r.def and r.def.key == "companionTraitSource" then source = r end
		if r.def and r.def.key == "companionTraitPick" then pick = r end
	end
	Check("[PERS] réglage « Caractère : Apparence » (recommandé)", source and source.value.text:find("Apparence", 1, true)
		and source.note.text:find("Recommandé", 1, true), source and source.value.text)
	Check("[PERS] réglage « Son caractère : Selon son jeu »", pick and pick.value.text:find("Selon son jeu", 1, true)
		and pick.note.text:find("Curieux", 1, true), pick and pick.note.text)
	pick:Step(1)
	Check("[PERS] + : Curieux choisi", NS:DB().companionTraitPick == 1 and pick.value.text:find("Curieux", 1, true))
	pick:Step(1); pick:Step(1)
	Check("[PERS] + + : Téméraire, et il l'est", NS:DB().companionTraitPick == 3 and NS:CompanionTrait() == "daring")
	for _ = 1, 4 do pick:Step(1) end
	Check("[PERS] après Câlin : Sage (déjà porté)", NS:DB().companionTraitPick == 7 and NS:CompanionTrait() == "wise",
		NS:DB().companionTraitPick)
	pick:Step(1)
	Check("[PERS] les caractères d'apparence pas encore portés sont sautés : on reste sur Sage",
		NS:DB().companionTraitPick == 7, NS:DB().companionTraitPick)
	NS:PersonaData().unlocked.zen = true
	pick:Step(1)
	Check("[PERS] tortue portée un jour : Zen au choix", NS:DB().companionTraitPick == 10 and NS:CompanionTrait() == "zen",
		NS:DB().companionTraitPick)
	pick:Step(-1)
	Check("[PERS] - : retour à Sage, en sautant les autres", NS:DB().companionTraitPick == 7, NS:DB().companionTraitPick)
	data.appearance = "turtle"
	Check("[PERS] l'apparence l'emporte (réglage Apparence)", NS:CompanionTrait() == "zen")
	source:Step(1)
	Check("[PERS] réglage « Le sien » : le choix revient", NS:CompanionTrait() == "wise" and source.note.text:find("quelle que soit", 1, true))
	NS.optionsFrame:Hide()
	PE.Done()
end

-- 4. Ce qu'il remarque ---------------------------------------------------------------------
do
	Say("-- caractère : remarques")
	local function Noticed(trait) return NS.companionBubbleKey == "NOTICE__" .. trait end

	PE.Reset()
	PE.Form("curious")
	NS:CompanionData().seenSub["20:Clairière"] = true
	NS:CompanionOnZone(false)
	Check("[PERS] Curieux : coin connu, rien", not Noticed("curious"))
	Mock.world.subzone = "Bosquet secret"
	PE.Quiet()
	NS:CompanionOnZone(false)
	Check("[PERS] Curieux : un coin jamais vu", Noticed("curious"))
	PE.Quiet()
	Mock.world.subzone = "Autre coin"
	NS:CompanionOnZone(false)
	Check("[PERS] une remarque par quart d'heure au plus", not Noticed("curious"))
	Mock:Advance(NS.PERSONALITY_NOTICE_GAP + 1)
	PE.Quiet()
	Mock.world.subzone = "Encore un coin"
	NS:CompanionOnZone(false)
	Check("[PERS] … puis de nouveau", Noticed("curious"))

	PE.Reset()
	PE.Form("daring")
	Mock.world.target = { dead = true, class = "elite" }
	PE.Quiet()
	NS:CompanionEliteKilled()
	Check("[PERS] Téméraire : un élite à terre", Noticed("daring"))

	PE.Reset()
	PE.Form("teasing")
	NS:CompanionOnDead()
	PE.Quiet()
	Mock:Advance(300)
	NS:CompanionOnDead()
	Check("[PERS] Taquin : deux morts en 10 min", Noticed("teasing"))

	PE.Reset()
	PE.Form("curious")
	NS:CompanionOnDead()
	PE.Quiet()
	Mock:Advance(300)
	NS:CompanionOnDead()
	Check("[PERS] un autre caractère ne fait pas la remarque du Taquin", not Noticed("teasing") and not Noticed("curious"))

	PE.Reset()
	PE.Form("wise")
	NS:DB().companionTraitSource = 2
	PE.Quiet()
	NS:CompanionOnZone(true)
	Check("[PERS] Sage : une terre nouvelle", Noticed("wise"))

	PE.Reset()
	PE.Form("parrot")
	NS:DB().companionTraitSource = 2
	NS:PersonaData().unlocked.parrot = true
	NS:CompanionData().seenZones[20] = true
	PE.Quiet()
	NS:CompanionOnZone(true)
	Check("[PERS] Perroquet : il répète le nom de la zone", Noticed("parrot")
		and NS.companionBubbleText:find("Plaine sauvage", 1, true), NS.companionBubbleText)

	local function TickNotice(trait, setup, label, negative)
		PE.Reset()
		PE.Form(trait)
		NS:DB().companionTraitSource = 2
		NS:PersonaData().unlocked[trait] = true
		if negative then negative() end
		PE.Quiet()
		NS:CompanionTick(5)
		Check("[PERS] " .. label .. " : pas encore", not Noticed(trait), NS.companionBubbleKey)
		setup()
		PE.Quiet()
		NS:CompanionTick(5)
		Check("[PERS] " .. label, Noticed(trait), NS.companionBubbleKey)
	end
	TickNotice("glutton", function() NS:CompanionData().needs.hunger = 50 end, "Gourmand : un petit creux",
		function() NS:CompanionData().needs.hunger = 90 end)
	TickNotice("lazy", function() Mock:Advance(2401) end, "Paresseux : pas de repos depuis 40 min")
	TickNotice("cuddly", function() Mock:Advance(1201) end, "Câlin : pas de caresse depuis 20 min")
	TickNotice("mystic", function() Mock.world.hour = 22 end, "Mystique : la nuit tombe")
	TickNotice("zen", function() Mock.world.health = 30 end, "Zen : souffle court après le combat")
	TickNotice("sly", function() Mock.world.money = 15000 end, "Rusé : une pièce d'or de plus")
	TickNotice("mischievous", function() Mock:Advance(1201) end, "Espiègle : une farce de temps en temps")

	PE.Reset()
	PE.Form("zen")
	NS:DB().companionTraitSource = 2
	NS:PersonaData().unlocked.zen = true
	Mock.world.health, Mock.world.combat = 30, true
	PE.Quiet()
	NS:CompanionTick(5)
	Check("[PERS] Zen : pas pendant le combat", not Noticed("zen"))

	PE.Reset()
	PE.Form("mystic")
	NS:DB().companionTraitSource = 2
	NS:PersonaData().unlocked.mystic = true
	Mock.world.hour = 23
	PE.Quiet()
	NS:CompanionTick(5)
	Mock:Advance(NS.PERSONALITY_NOTICE_GAP + 1)
	PE.Quiet()
	NS:CompanionTick(5)
	Check("[PERS] Mystique : une fois par nuit", not Noticed("mystic"))
	PE.Done()
end

-- 5. Les répliques ------------------------------------------------------------------------
do
	Say("-- caractère : répliques")
	local function Specs(text)
		local list = {}
		for spec in tostring(text):gsub("%%%%", ""):gmatch("%%[sd]") do list[#list + 1] = spec end
		return table.concat(list, ",")
	end
	local fr, en = NS.COMPANION_LINE_STRINGS.fr, NS.COMPANION_LINE_STRINGS.en
	local bad, total, missing = {}, 0, {}
	for trait in pairs(NS.PERSONALITY_TRAITS) do
		for _, pool in ipairs({ "FORMED", "NOTICE", "HELLO", "LEVEL", "KILL", "DEAD", "EAT", "VIEW", "IDLE", "ADVICE_ELITE", "ADVICE_HEALTH" }) do
			if not NS.COMPANION_POOLS[pool .. "__" .. trait] then missing[#missing + 1] = pool .. "__" .. trait end
		end
	end
	for name, keys in pairs(NS.PERSONALITY_POOLS) do
		local base = name:match("^(.-)__")
		for _, key in ipairs(keys) do
			total = total + 1
			if Specs(fr[key]) ~= Specs(en[key]) then bad[#bad + 1] = key .. " (fr/en)" end
			local shared = NS.COMPANION_POOLS[base]
			-- sans argument, ou les mêmes que la réplique commune
			if shared and Specs(fr[key]) ~= "" and Specs(fr[key]) ~= Specs(fr[shared[1]]) then bad[#bad + 1] = key end
		end
	end
	Check("[PERS] chaque caractère a ses grands moments", #missing == 0, table.concat(missing, ", "))
	Check("[PERS] mêmes arguments que la réplique commune", #bad == 0, table.concat(bad, ", "))
	Check("[PERS] beaucoup de répliques (300 et plus)", total >= 300, total)
	local S, gaps = NS.PERSONALITY_STRINGS, {}
	for key in pairs(S.fr) do if not S.en[key] then gaps[#gaps + 1] = key end end
	for key in pairs(S.en) do if not S.fr[key] then gaps[#gaps + 1] = key end end
	for trait in pairs(NS.PERSONALITY_TRAITS) do
		if not (S.fr["TRAIT_" .. trait] and S.fr["TRAIT_DESC_" .. trait]) then gaps[#gaps + 1] = trait end
	end
	Check("[PERS] textes en français et en anglais", #gaps == 0, table.concat(gaps, ", "))
end
