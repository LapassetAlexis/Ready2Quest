-- QuestCompanion 2.13.0 : le compagnon raconte l'histoire des lieux
-- (LoreData.lua généré depuis Spoken_Places / Warcraft Wiki, CompanionLore.lua).
-- La concordance LoreData.lua <-> data/forever/lore/lore.json est vérifiée par
-- tests/run_tests.py (check_generated) ; ici : forme des données, une fois
-- par zone / sous-zone, silence en combat, réglage coupé, Spoken chargé,
-- coupe des phrases trop longues.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local X = { saved = {}, timers = {}, combat = false, spoken = false }
for _, name in ipairs({ "InCombatLockdown", "UnitAffectingCombat", "C_Timer", "C_AddOns" }) do X.saved[name] = rawget(_G, name) end
local savedRandom = math.random

function X.Free()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.companionBubbleText = nil
	if NS.companionRT then NS.companionRT.cool = {}; NS.companionRT.seq = nil end
end
function X.Reset()
	ResetWorld()
	NS.companionRT, NS.companionSession, NS.companionFighting = nil, nil, nil
	X.Free()
	X.timers, X.combat, X.spoken = {}, false, false
	_G.InCombatLockdown = function() return X.combat end
	_G.UnitAffectingCombat = function() return X.combat end
	_G.C_Timer = { After = function(delay, fn) X.timers[#X.timers + 1] = { delay = delay, fn = fn } end }
	_G.C_AddOns = { IsAddOnLoaded = function(name) return X.spoken and name == "Spoken_Places" end }
	Mock.world.level = 20
	NS:CompanionData().tutoDone = true
	NS:DB().companionChatter = 3
	NS:DB().companionLore = nil
	NS:CharData().lore = nil
	NS.loreLang = "fr"
	NS:LoreReset()
	NS:CompanionUpdateVisibility()
end
-- les minuteries en attente, la place libérée avant chacune
function X.Run()
	local list = X.timers
	X.timers = {}
	for _, t in ipairs(list) do X.Free(); Mock:Advance(NS.LORE_LIMITS.gap + 1); t.fn() end
	return #list
end
function X.Enter(mapID, sub, newArea)
	Mock.world.mapID, Mock.world.subzone = mapID, sub
	NS:CompanionOnZone(newArea)
end
function X.Done()
	for name, value in pairs(X.saved) do _G[name] = value end
	math.random = savedRandom
	NS.loreLang = nil
	NS:LoreReset()
	X.Free()
end

-- 1. Données générées -------------------------------------------------------------------
do
	Say("-- histoire des lieux : données")
	local raw = NS.LORE_RAW
	Check("[LORE] deux langues gardées en test", type(raw) == "table" and type(raw.fr) == "string" and type(raw.en) == "string")
	local function Count(text, tag)
		local n = 0
		for _ in text:gmatch("\n" .. tag .. "\t") do n = n + 1 end
		return n
	end
	local zf, ze, sf, se = Count(raw.fr, "Z"), Count(raw.en, "Z"), Count(raw.fr, "S"), Count(raw.en, "S")
	Check("[LORE] autant de zones et sous-zones en fr qu'en en", zf == ze and sf == se and zf >= 40 and sf >= 200,
		string.format("Z %d/%d S %d/%d", zf, ze, sf, se))
	local bad
	for lang, text in pairs(raw) do
		for line in text:gmatch("[^\n]+") do
			local fields = {}
			for field in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = field end
			local body = fields[1] == "Z" and fields[3] or fields[4]
			local page = fields[#fields]
			if not (body and body ~= "" and page and page:find("^[%w%(%)_'%%%-%.,:!]+$")
				and NS.LoreFit(body) == body and (#fields == (fields[1] == "Z" and 4 or 5))) then
				bad = bad or (lang .. ": " .. line)
			end
		end
	end
	Check("[LORE] chaque ligne : texte qui tient dans la bulle et page du wiki", bad == nil, bad)
	NS.loreLang = "fr"
	Check("[LORE] zone : Durotar (fr)", (NS:LoreZone(1411) or ""):find("Durotar") ~= nil)
	local text, page = NS:LoreSubzone(1411, "Tranchecolline")
	Check("[LORE] sous-zone par son nom français", text ~= nil and page == "Razor_Hill", tostring(page))
	NS.loreLang = "en"
	NS:LoreForgetCache()
	Check("[LORE] sous-zone par son nom anglais", select(2, NS:LoreSubzone(1411, "Razor Hill")) == "Razor_Hill")
	Check("[LORE] « The » de tête ignoré (The Den -> den)", select(2, NS:LoreSubzone(1411, "The Den")) == "The_Den")
	Check("[LORE] lieu inconnu : rien", NS:LoreSubzone(1411, "Nulle part") == nil and NS:LoreZone(999999) == nil)
	NS.loreLang = nil
	NS:LoreForgetCache()
	Check("[LORE] normalisation", NS.LoreNormalise("The Crossroads") == "crossroads"
		and NS.LoreNormalise("Zul'Farrak") == "zulfarrak" and NS.LoreNormalise("Lion’s Pride Inn") == "lions pride inn")
end

-- 2. Coupe sûre -------------------------------------------------------------------------
do
	Say("-- histoire des lieux : coupe")
	local short = "Une phrase courte."
	Check("[LORE] texte court gardé tel quel", NS.LoreFit(short, 100) == short)
	local two = string.rep("Mot ", 20) .. "fin. " .. string.rep("Autre ", 30) .. "fin."
	local cut = NS.LoreFit(two, 120)
	Check("[LORE] coupe à la fin d'une phrase", #cut <= 120 and cut:sub(-4) == "fin.", cut)
	local long = string.rep("élan ", 80)
	local word = NS.LoreFit(long, 100)
	Check("[LORE] sinon coupe au mot, avec « … »", #word <= 100 and word:sub(-3) == "…" and not word:find(" …$")
		and word:sub(-6, -4) ~= "\195", word)
end

-- 3. Une fois par zone, une fois par sous-zone ------------------------------------------
do
	Say("-- histoire des lieux : déclencheurs")
	X.Reset()
	X.Enter(1411, nil, true)
	Check("[LORE] arrivée : récit en attente (après la bulle d'arrivée)", NS:LorePending() ~= nil and #X.timers == 1
		and X.timers[1].delay == NS.LORE_LIMITS.delay)
	X.Run()
	Check("[LORE] zone racontée (réservoir LORE)", NS.companionBubbleKey == "LORE"
		and (NS.companionBubbleText or ""):find("Durotar") ~= nil, NS.companionBubbleText)
	Check("[LORE] notée pour ce personnage", tonumber(NS:CharData().lore.z[1411]) ~= nil)
	X.Free()
	X.Enter(1411, nil, true)
	Check("[LORE] retour aussitôt : rien", NS:LorePending() == nil and #X.timers == 0)
	-- bien plus tard, la chance de reparler (forcée)
	NS:CharData().lore.z[1411] = NS:CharData().lore.z[1411] - NS.LORE_LIMITS.revisit - 1
	math.random = function(a) if a then return 1 end return 0 end
	X.Enter(1411, nil, true)
	Check("[LORE] visite bien plus tard : parfois redit", NS:LorePending() ~= nil)
	math.random = function(a) if a then return 1 end return 0.99 end
	NS:LoreReset(); X.timers = {}
	NS:CharData().lore.z[1411] = NS:CharData().lore.z[1411] - NS.LORE_LIMITS.revisit - 1
	X.Enter(1411, nil, true)
	Check("[LORE] … mais rarement", NS:LorePending() == nil)
	math.random = savedRandom
	NS:LoreReset(); X.timers = {}
	-- sous-zone notable
	X.Enter(1411, "Tranchecolline", false)
	Check("[LORE] sous-zone notable : en attente", NS:LorePending() ~= nil)
	X.Run()
	Check("[LORE] sous-zone racontée, nommée (LORE_PLACE)", NS.companionBubbleKey == "LORE_PLACE"
		and (NS.companionBubbleText or ""):find("Tranchecolline") ~= nil, NS.companionBubbleText)
	Check("[LORE] sous-zone notée", NS:CharData().lore.s.Razor_Hill == true)
	X.Enter(1411, "Tranchecolline", false)
	Check("[LORE] sous-zone : une seule fois", NS:LorePending() == nil and #X.timers == 0)
	X.Enter(1411, "Clairière sans nom", false)
	Check("[LORE] sous-zone sans histoire : rien", NS:LorePending() == nil)
	-- parti avant le récit : abandonné, redit à la prochaine entrée
	X.Enter(1411, "L'Antre", false)
	Mock.world.subzone = "Ailleurs"
	X.Run()
	Check("[LORE] parti avant le récit : rien de dit ni de noté", NS.companionBubbleKey ~= "LORE_PLACE"
		and not NS:CharData().lore.s.The_Den and NS:LorePending() == nil)
	X.Done()
end

-- 4. Silences : combat, réglage, cran, Spoken ------------------------------------------
do
	Say("-- histoire des lieux : silences")
	X.Reset()
	X.combat = true
	X.Enter(1412, nil, true)
	X.Run()
	Check("[LORE] en combat : rien de dit, on attend", NS.companionBubbleKey ~= "LORE" and NS:LorePending() ~= nil
		and #X.timers == 1 and not NS:CharData().lore.z[1412])
	X.combat = false
	NS.companionFighting = nil
	X.Run()
	Check("[LORE] après le combat : raconté", NS.companionBubbleKey == "LORE" and NS:CharData().lore.z[1412] ~= nil)

	X.Reset()
	NS:DB().companionLore = false
	X.Enter(1411, "Tranchecolline", true)
	Check("[LORE] réglage coupé : rien", NS:LorePending() == nil and #X.timers == 0)
	NS:DB().companionLore = nil

	X.Reset()
	NS:DB().companionChatter = 2
	X.Enter(1411, nil, true)
	X.Run()
	Check("[LORE] cran Calme : rien de dit ni de noté", NS.companionBubbleKey ~= "LORE" and not NS:CharData().lore.z[1411])

	X.Reset()
	X.spoken = true
	Check("[LORE] Spoken Places détecté", NS.LoreSpokenLoaded() == true)
	X.Enter(1411, "Tranchecolline", true)
	Check("[LORE] Spoken Places chargé : silence (il raconte déjà)", NS:LorePending() == nil and #X.timers == 0)

	-- réglage dans la page du compagnon, sous la réglette Bavardage
	local row, after
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if page.id == "companionMain" then
			for index, r in ipairs(page.rows) do
				if r.key == "companionLore" then row, after = r, page.rows[index - 1] end
			end
		end
	end
	Check("[LORE] réglage présent, activé par défaut", row ~= nil and row.kind == "bool" and after and after.key == "companionChatter"
		and NS:DB().companionLore ~= false)
	Check("[LORE] textes fr/en du réglage", NS.L.OPT_COMP_LORE ~= nil and NS.L.OPT_COMP_LORE_DESC:find("CC BY%-SA") ~= nil)
	X.Done()
end

-- 5. Au repos ---------------------------------------------------------------------------
do
	Say("-- histoire des lieux : bavardage")
	X.Reset()
	Mock.world.mapID, Mock.world.subzone = 1411, "Tranchecolline"
	math.random = function(a) if a then return 1 end return 0 end
	Check("[LORE] avant le délai : rien", NS:CompanionLoreIdle(NS.LORE_LIMITS.idle - 1) == false)
	X.Free()
	Check("[LORE] passé le délai : le lieu raconté", NS:CompanionLoreIdle(1) == true and NS.companionBubbleKey == "LORE_PLACE")
	X.Free()
	X.combat = true
	Check("[LORE] en combat : jamais", NS:CompanionLoreIdle(NS.LORE_LIMITS.idle) == false)
	X.Done()
end
