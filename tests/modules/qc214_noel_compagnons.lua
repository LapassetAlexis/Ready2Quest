-- QC 2.14.0 : compagnons de saison du Voile d'hiver (WinterCompanions.lua).
-- Choisis comme une apparence en saison seulement, sans perdre l'apparence
-- habituelle ; leurs effets et particularités (hotte, nez qui brille, froid
-- et chaleur) ; leurs voix ; la visite surprise de Grand-père Hiver ; le haut
-- fait souvenir ; le départ en fin de saison. La saison (WinterVeil.lua) est
-- remplacée par un interrupteur du test.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local W = { random = math.random, season = NS.WinterVeilSeason, share = NS.WINTER_VOICE_SHARE,
	inCombat = rawget(_G, "InCombatLockdown"), affecting = rawget(_G, "UnitAffectingCombat"),
	date = rawget(_G, "date"), gameTime = rawget(_G, "GetGameTime"), instance = rawget(_G, "IsInInstance") }
local seed = 2140
local function Random(a, b)
	seed = (seed * 1103515245 + 12345) % 2147483648
	local r = seed / 2147483648
	if not a then return r end
	if not b then return math.floor(r * a) + 1 end
	return a + math.floor(r * (b - a + 1))
end
local function Starts(key, prefix)
	if type(key) ~= "string" then return false end
	local tail = key:sub(#prefix + 1)
	return key:sub(1, #prefix) == prefix and (tail == "" or tail:match("^_%d+$") ~= nil)
end
local function Logged(text)
	for _, line in ipairs(Mock.output) do if line:find(text, 1, true) then return true end end
	return false
end

function W.Free()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.companionBubbleText, NS.companionBubbleLine = nil, nil
	if NS.companionRT then NS.companionRT.cool = {}; NS.companionRT.seq = nil end
end
function W.Season(on)
	W.on = on
	NS:WinterCompanionsForget()
end
function W.Reset(on)
	ResetWorld()
	NS.companionRT, NS.companionSession, NS.companionFighting = nil, nil, nil
	W.Free()
	W.combat, W.day, W.hour, W.inside = false, "2026-12-20", 12, false
	_G.InCombatLockdown = function() return W.combat end
	_G.UnitAffectingCombat = function() return W.combat end
	_G.date = function(fmt) if fmt == "%Y-%m-%d" then return W.day end return W.date and W.date(fmt) or "" end
	_G.GetGameTime = function() return W.hour, 0 end
	_G.IsInInstance = function() return W.inside, W.inside and "party" or "none" end
	NS.WinterVeilSeason = function() return W.on end
	W.Season(on)
	local data = NS:CompanionData()
	data.tutoDone = true
	data.winter = nil
	data.appearance = NS.COMPANION_APPEARANCES[1].id
	data.effects = nil
	NS:DB().companionChatter = 3
	NS:DB().companionWinterVisit = nil
	NS:DB().companionShow = nil
	NS.winterVisited, NS.winterVisitAt, NS.winterTemp = nil, nil, nil
	if NS.WinterVisitHide then NS:WinterVisitHide() end
	NS.WINTER_VOICE_SHARE = 1
	NS:CompanionUpdateVisibility()
	math.random = Random
end
function W.Done()
	math.random = W.random
	NS.WinterVeilSeason, NS.WINTER_VOICE_SHARE = W.season, W.share
	_G.InCombatLockdown, _G.UnitAffectingCombat = W.inCombat, W.affecting
	_G.date, _G.GetGameTime, _G.IsInInstance = W.date, W.gameTime, W.instance
	local data = NS:CompanionData()
	data.winter, data.effects = nil, nil
	NS:WinterCompanionsForget()
	NS.winterVisited, NS.winterVisitAt, NS.winterTemp = nil, nil, nil
	if NS.WinterVisitHide then NS:WinterVisitHide() end
	W.Free()
	ResetWorld()
end
-- effets actifs tout de suite (le délai de 2 minutes est passé)
function W.Active()
	NS:CompanionEffectsSync()
	NS:CompanionData().effects.since = 0
	NS.effectCache = nil
end
local function Ids(list)
	local ids = {}
	for _, def in ipairs(list) do ids[#ids + 1] = def.id end
	return ids
end
local function Has(list, id)
	for _, def in ipairs(list) do if def.id == id or def.value == id then return true end end
	return false
end

-- 1. Les textes ---------------------------------------------------------------------------------
do
	Say("-- 2.14.0 : compagnons du Voile d'hiver, les textes")
	local fr, en, POOLS = NS.COMPANION_LINE_STRINGS.fr, NS.COMPANION_LINE_STRINGS.en, NS.COMPANION_POOLS
	local function Specs(text)
		local list = {}
		for spec in tostring(text or ""):gsub("%%%%", ""):gmatch("%%[sd]") do list[#list + 1] = spec end
		return table.concat(list, ",")
	end
	local ARGS = { KILL = "%s", CAPTURE_OK = "%s", CAPTURE_FAIL = "%s", SHINY_SPOTTED = "%s", LEVEL = "%s",
		CITY = "%s", DUNGEON = "%s" }
	Check("[NOEL] trois compagnons, PNJ 13444, 15664, 15710", #NS.WINTER_COMPANIONS == 3
		and NS.WINTER_COMPANIONS[1].npc == 13444 and NS.WINTER_COMPANIONS[2].npc == 15664 and NS.WINTER_COMPANIONS[3].npc == 15710)
	Check("[NOEL] noms FR", NS.L.WINTER_COMP_gfw == "Grand-père Hiver" and NS.L.WINTER_COMP_metzen == "Metzen le renne"
		and NS.L.WINTER_COMP_snowman == "Petit bonhomme de neige")
	local short, bad, counts = {}, {}, {}
	for _, def in ipairs(NS.WINTER_COMPANIONS) do
		local total = 0
		for _, situ in ipairs(NS.WINTER_VOICE_SITUATIONS) do
			local keys = POOLS[situ .. "_V_" .. def.seasonal]
			if not keys or #keys < 2 then short[#short + 1] = situ .. "_V_" .. def.seasonal end
			for _, key in ipairs(keys or {}) do
				total = total + 1
				local f, e = fr[key], en[key]
				local spec = Specs(f)
				if type(f) ~= "string" or f == "" or type(e) ~= "string" or e == "" or spec ~= Specs(e)
					or (spec ~= "" and spec ~= ARGS[situ]) or #f > 110 or #e > 110 then bad[#bad + 1] = key end
			end
		end
		counts[#counts + 1] = def.seasonal .. "=" .. total
		if total < 40 then short[#short + 1] = def.seasonal .. " " .. total end
	end
	Check("[NOEL] chaque voix : ~40 répliques, toutes les situations", #short == 0, table.concat(short, ", "))
	Check("[NOEL] répliques FR/EN non vides, mêmes arguments, courtes (bulle)", #bad == 0, table.concat(bad, ", "))
	Say("   voix : " .. table.concat(counts, ", "))
	local special = {}
	for _, pool in ipairs({ "WINTER_SACK", "WINTER_HOT", "WINTER_COLD", "WINTER_BYE_gfw", "WINTER_BYE_metzen",
		"WINTER_BYE_snowman", "WINTER_VISIT" }) do
		local keys = POOLS[pool]
		if not keys or #keys == 0 then special[#special + 1] = pool end
		for _, key in ipairs(keys or {}) do
			if not (fr[key] and en[key]) or Specs(fr[key]) ~= Specs(en[key]) then special[#special + 1] = key end
		end
	end
	Check("[NOEL] hotte, chaud, froid, au revoir, visite : FR et EN", #special == 0, table.concat(special, ", "))
	Check("[NOEL] lignes validées, verbatim", fr[POOLS.HELLO_V_gfw[1]] == "Ho ho ho ! Tu as été sage cette année ? Les mobs que tu as tués, eux, ne diront rien."
		and fr[POOLS.CAPTURE_OK_V_gfw[1]] == "Encore un pour la hotte !" and fr[POOLS.WINTER_HOT[1]] == "Je… ruisselle.")
	local missing = {}
	for _, key in ipairs({ "EFF_winter_treat", "EFF_winter_sack", "EFF_winter_energy", "EFF_winter_nose", "EFF_winter_pet",
		"EFF_winter_cold", "EFF_SEASON", "EFF_QUIRK", "EFF_SECTION_WINTER" }) do
		if not (NS.EFFECT_STRINGS.fr[key] and NS.EFFECT_STRINGS.en[key]) then missing[#missing + 1] = key end
	end
	for _, key in ipairs({ "WINTER_MSG_BYE", "WINTER_MSG_SACK", "OPT_COMP_WINTER_VISIT", "OPT_COMP_WINTER_VISIT_DESC" }) do
		if NS.L[key] == key or NS.L[key] == nil then missing[#missing + 1] = key end
	end
	Check("[NOEL] chaînes des effets et des messages", #missing == 0, table.concat(missing, ", "))
end

-- 2. En saison seulement ; l'apparence habituelle reste --------------------------------------------
do
	Say("-- 2.14.0 : compagnons du Voile d'hiver, le choix")
	W.Reset(false)
	local regular = NS:CompanionData().appearance
	Check("[NOEL] hors saison : absents des apparences", not Has(NS:CompanionAllAppearances(), "winter:gfw")
		and not Has(NS:CompanionChoices("app"), "winter:metzen"))
	Check("[NOEL] hors saison : choix refusé", NS:CompanionSetAppearance("winter:gfw") == nil
		and NS:CompanionCurrentAppearance().id == regular)
	W.Season(true)
	local ids = Ids(NS:CompanionUnlockedAppearances())
	Check("[NOEL] en saison : les trois en tête de « Son allure »", ids[1] == "winter:gfw" and ids[2] == "winter:metzen"
		and ids[3] == "winter:snowman", table.concat(ids, ","))
	Check("[NOEL] en saison : dans la liste des réglages, sans verrou", Has(NS:CompanionChoices("app"), "winter:snowman"))
	local def = NS:CompanionSetAppearance("winter:metzen")
	local data = NS:CompanionData()
	Check("[NOEL] choisi : Metzen porté, apparence habituelle gardée", def and def.seasonal == "metzen"
		and NS:CompanionCurrentAppearance().id == "winter:metzen" and data.appearance == regular and data.winter.pick == "metzen")
	Check("[NOEL] son nom à la place du tien", NS:CompanionName() == "Metzen le renne")
	Check("[NOEL] il dit bonjour avec sa voix", Starts(NS.companionBubbleLine, "COMP_SAY_HELLO_V_metzen"), tostring(NS.companionBubbleLine))
	-- le cycle de /qc compagnon passe aussi par le choix
	NS:CompanionSetAppearance(regular)
	Check("[NOEL] apparence ordinaire choisie : le compagnon habituel revient", data.winter.pick == nil
		and NS:CompanionCurrentAppearance().id == regular and NS:CompanionName() ~= "Metzen le renne")
	NS:CompanionSetAppearance("winter:snowman")
	local nextDef = NS:CompanionCycleAppearance()
	Check("[NOEL] cycle : passe au suivant sans écraser l'apparence habituelle", nextDef and data.appearance == regular
		and NS:CompanionCurrentAppearance().id == nextDef.id, nextDef and nextDef.id)
	W.Done()
end

-- 3. Effets et particularités ---------------------------------------------------------------------
do
	Say("-- 2.14.0 : compagnons du Voile d'hiver, effets")
	W.Reset(true)
	NS:CompanionSetAppearance("winter:metzen")
	W.Active()
	local effects = NS:CompanionEffects()
	Check("[NOEL] Metzen : énergie et nez qui brille, force de l'étape", effects and effects.seasonal == "metzen"
		and effects.hunt.id == "winter_energy" and effects.comfort.id == "winter_nose" and effects.active
		and not effects.mascot)
	local lines = NS:CompanionEffectsText(effects)
	Check("[NOEL] « Ses effets » : Saison / Particularité", lines[1]:find("^Saison : ") and lines[2]:find("^Particularité : ")
		and lines[2]:find("nez qui brille", 1, true), table.concat(lines, " / "))
	Check("[NOEL] énergie : baisse moins vite", NS:CompanionDecayFactor("energy") < 1 and NS:CompanionDecayFactor("hunger") == 1)
	W.hour = 12
	local day = NS:CompanionCaptureBonus({ class = "normal", typeKey = "beast" })
	W.hour = 22
	local night = NS:CompanionCaptureBonus({ class = "normal", typeKey = "beast" })
	W.hour = 3
	local late = NS:CompanionCaptureBonus({ class = "normal", typeKey = "beast" })
	Check("[NOEL] nez qui brille : capture en plus la nuit (heure du jeu) seulement", day == 0 and night > 0 and late == night,
		day .. " / " .. night .. " / " .. late)
	local base = NS.CaptureChanceBase and NS:CaptureChanceBase({ class = "normal", level = 11 }) or nil
	local with = NS:CaptureChance({ class = "normal", level = 11 })
	Check("[NOEL] par l'enveloppe de la chance de capture", base and with > base, tostring(base) .. " -> " .. tostring(with))

	-- Grand-père Hiver : la hotte (une fois par jour)
	W.Reset(true)
	local items, pantry = NS:CaptureData().items, NS:TreatData().pantry
	local function Total()
		local n = 0
		for _, v in pairs(items) do n = n + (tonumber(v) or 0) end
		for _, v in pairs(pantry) do n = n + (tonumber(v) or 0) end
		return n
	end
	local before = Total()
	NS:CompanionSetAppearance("winter:gfw")
	local data = NS:CompanionData()
	Check("[NOEL] hotte : un cadeau au premier choix du jour", data.winter.sackDay == "2026-12-20" and Total() == before + 1
		and Logged("La hotte de Grand-père Hiver"), before .. " -> " .. Total())
	Check("[NOEL] hotte : une seule fois par jour", NS:WinterSackCheck() == nil and NS:WinterCompanionsLogin() == nil
		and Total() == before + 1)
	W.day = "2026-12-21"
	W.Free()
	local label = NS:WinterCompanionsLogin()
	Check("[NOEL] hotte : le lendemain, à la connexion, un autre cadeau et sa réplique", label and Total() == before + 2
		and Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_SACK"), tostring(NS.companionBubbleLine))
	W.Active()
	local gfw = NS:CompanionEffects()
	Check("[NOEL] Grand-père Hiver : friandise aux paliers de zone + hotte", gfw.hunt.id == "winter_treat"
		and gfw.comfort.id == "winter_sack" and NS.COMPANION_EFFECTS.winter_treat.kind == "treatZone")
	NS:CompanionSetAppearance("winter:metzen")
	W.day = "2026-12-22"
	Check("[NOEL] hotte : seulement avec Grand-père Hiver", NS:WinterSackCheck() == nil)

	-- Petit bonhomme de neige : caresse, froid, chaleur
	W.Reset(true)
	NS:CompanionSetAppearance("winter:snowman")
	W.Active()
	local snow = NS:CompanionEffects()
	Check("[NOEL] bonhomme de neige : caresse et froid", snow.hunt.id == "winter_pet" and snow.comfort.id == "winter_cold"
		and NS.COMPANION_EFFECTS.winter_pet.kind == "pet")
	Mock.world.mapID = 1426
	local cold = { NS:CompanionDecayFactor("hunger"), NS:CompanionDecayFactor("mood") }
	Mock.world.mapID = 1446
	local hot = { NS:CompanionDecayFactor("hunger"), NS:CompanionDecayFactor("mood") }
	Mock.world.mapID = 1429
	local mild = { NS:CompanionDecayFactor("hunger"), NS:CompanionDecayFactor("mood") }
	Check("[NOEL] Dun Morogh (1426) : toutes les envies baissent moins vite", cold[1] < 1 and cold[2] < 1)
	Check("[NOEL] Tanaris (1446) : il fond, le moral baisse plus vite", hot[1] == 1 and hot[2] == NS.WINTER_MELT)
	Check("[NOEL] zone tempérée : rien", mild[1] == 1 and mild[2] == 1)
	Check("[NOEL] zones par uiMapID", NS.WINTER_COLD_MAPS[1452] and NS.WINTER_COLD_MAPS[1416] and NS.WINTER_HOT_MAPS[1413]
		and NS.WINTER_HOT_MAPS[1451] and not NS.WINTER_HOT_MAPS[1426])
	W.Free()
	Mock.world.mapID = 1446
	NS:CompanionOnZone(true)
	Check("[NOEL] entrée en zone chaude : « Je… ruisselle. » et compagnie", Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_HOT"),
		tostring(NS.companionBubbleLine))
	W.Free()
	NS:CompanionOnZone(true)
	Check("[NOEL] même chaleur : pas redit", NS.companionBubbleLine == nil or not Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_HOT"))
	W.Free()
	Mock.world.mapID = 1452
	NS:CompanionOnZone(true)
	Check("[NOEL] entrée dans le froid : il se réjouit", Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_COLD"),
		tostring(NS.companionBubbleLine))
	local mood = NS:CompanionData().needs.mood
	NS:CompanionData().needs.mood = 50
	NS.companionLastPet = nil
	NS:CompanionPet()
	Check("[NOEL] caresse : le moral monte plus (effet pet)", NS:CompanionData().needs.mood > 58, NS:CompanionData().needs.mood)
	NS:CompanionData().needs.mood = mood
	W.Done()
end

-- 4. Voix -------------------------------------------------------------------------------------------
do
	Say("-- 2.14.0 : compagnons du Voile d'hiver, voix")
	W.Reset(true)
	NS:CompanionSetAppearance("winter:gfw")
	Check("[NOEL] combat : sa voix", Starts(NS:CompanionVoicePick("KILL", { "Gnoll" }), "COMP_SAY_KILL_V_gfw"))
	Check("[NOEL] capture : sa voix", Starts(NS:CompanionVoicePick("CAPTURE_OK", { "Loup" }), "COMP_SAY_CAPTURE_OK_V_gfw"))
	Check("[NOEL] donjon, envie, nouvelle zone, fin de combat : sa voix",
		Starts(NS:CompanionVoicePick("DUNGEON"), "COMP_SAY_DUNGEON_V_gfw") and Starts(NS:CompanionVoicePick("NEED_energy"), "COMP_SAY_NEED_V_gfw")
		and Starts(NS:CompanionVoicePick("VIEW"), "COMP_SAY_VIEW_V_gfw") and Starts(NS:CompanionVoicePick("COMBAT_SUM", { 3 }), "COMP_SAY_COMBAT_V_gfw"))
	Check("[NOEL] situation sans voix (butin) : la commune", Starts(NS:CompanionVoicePick("LOOT"), "COMP_SAY_LOOT"))
	W.Free()
	NS.companionLastPet = nil
	NS:CompanionPet()
	Check("[NOEL] caresse : une réplique à lui", Starts(NS.companionBubbleLine, "COMP_SAY_PET_V_gfw"), tostring(NS.companionBubbleLine))
	W.Season(false)
	Check("[NOEL] hors saison : plus sa voix", not tostring(NS:CompanionVoicePick("KILL", { "Gnoll" })):find("_V_gfw", 1, true))
	W.Done()
end

-- 5. Fin de saison ------------------------------------------------------------------------------------
do
	Say("-- 2.14.0 : compagnons du Voile d'hiver, fin de saison")
	W.Reset(true)
	local regular = NS:CompanionData().appearance
	NS:CompanionSetAppearance("winter:gfw")
	Check("[NOEL] en saison : il reste", NS:WinterCompanionsCheck() == false and NS:CompanionCurrentAppearance().id == "winter:gfw")
	W.Season(false)
	W.Free()
	Check("[NOEL] saison finie : il repart, l'habituel revient", NS:WinterCompanionsCheck() == true
		and NS:CompanionCurrentAppearance().id == regular and NS:CompanionData().winter.pick == nil)
	Check("[NOEL] au revoir : une bulle et le chat", Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_BYE_gfw")
		and Logged("repart vers le Nord"), tostring(NS.companionBubbleLine))
	W.Free()
	Check("[NOEL] au revoir : une seule fois", NS:WinterCompanionsCheck() == false and NS.companionBubbleLine == nil)
	-- connexion hors saison avec un choix resté
	W.Reset(true)
	NS:CompanionSetAppearance("winter:snowman")
	W.on = false
	W.Free()
	NS:WinterCompanionsLogin()
	Check("[NOEL] connexion hors saison : départ dit à la connexion", NS:CompanionData().winter.pick == nil
		and Starts(NS.companionBubbleLine, "COMP_SAY_WINTER_BYE_snowman"), tostring(NS.companionBubbleLine))
	W.Done()
end

-- 6. Visite surprise ------------------------------------------------------------------------------------
do
	Say("-- 2.14.0 : visite surprise de Grand-père Hiver")
	W.Reset(true)
	Check("[NOEL] réglage : activé par défaut, dans la page du compagnon", NS.DEFAULTS.companionWinterVisit == true
		and (function()
			for _, page in ipairs(NS.OPTION_PAGES or {}) do
				if page.id == "companionMain" then
					for _, row in ipairs(page.rows) do if row.key == "companionWinterVisit" and row.kind == "bool" then return true end end
				end
			end
			return false
		end)())
	NS.winterVisitAt = Mock.now + 100
	Check("[NOEL] visite : pas avant son heure", NS:WinterVisitTick() == false and not NS.winterVisited)
	NS.winterVisitAt = Mock.now - 1
	W.combat = true
	local ready, why = NS:WinterVisitReady()
	Check("[NOEL] visite : jamais en combat", NS:WinterVisitTick() == false and not ready and why == "combat")
	W.combat, W.inside = false, true
	ready, why = NS:WinterVisitReady()
	Check("[NOEL] visite : jamais en instance", not ready and why == "instance")
	W.inside = false
	NS:DB().companionWinterVisit = false
	ready, why = NS:WinterVisitReady()
	Check("[NOEL] visite : réglage coupé", not ready and why == "setting")
	NS:DB().companionWinterVisit = nil
	W.Season(false)
	ready, why = NS:WinterVisitReady()
	Check("[NOEL] visite : hors saison, rien", not ready and why == "season")
	W.Season(true)
	Check("[NOEL] visite : il apparaît", NS:WinterVisitTick() == true and NS.winterVisitFrame and NS.winterVisitFrame:IsShown()
		and NS.winterVisitFrame.bubble:IsShown())
	local text = NS.winterVisitFrame.bubble.text.text or (NS.winterVisitFrame.bubble.text.GetText and NS.winterVisitFrame.bubble.text:GetText())
	local found = false
	for _, key in ipairs(NS.COMPANION_POOLS.WINTER_VISIT) do if NS.L[key] == text then found = true end end
	Check("[NOEL] visite : une de ses répliques dans la bulle", found, tostring(text))
	local frame = NS.winterVisitFrame
	local update = frame:GetScript("OnUpdate")
	update(frame, 1)
	local midAlpha = frame.shownAlpha
	update(frame, 4.8)
	Check("[NOEL] visite : fondu d'entrée puis de sortie", midAlpha == 1 and frame.shownAlpha and frame.shownAlpha < 1
		and frame:IsShown(), tostring(midAlpha) .. " / " .. tostring(frame.shownAlpha))
	frame:GetScript("OnMouseUp")(frame, "LeftButton")
	Check("[NOEL] visite : un clic le renvoie", not frame:IsShown() and not frame.bubble:IsShown() and frame:GetScript("OnUpdate") == nil)
	NS:WinterVisitShow()
	NS.winterVisited = true
	frame:GetScript("OnUpdate")(frame, NS.WINTER_VISIT_TIME + 1)
	Check("[NOEL] visite : repart seule après ~6 s", not frame:IsShown())
	NS.winterVisitAt = Mock.now - 1
	ready, why = NS:WinterVisitReady()
	Check("[NOEL] visite : une fois par session", NS:WinterVisitTick() == false and why == "done")
	NS.winterVisited = nil
	NS:CompanionSetAppearance("winter:gfw")
	ready, why = NS:WinterVisitReady()
	Check("[NOEL] visite : pas s'il voyage déjà avec toi", not ready and why == "here")
	W.Done()
end

-- 7. Haut fait souvenir ----------------------------------------------------------------------------------
do
	Say("-- 2.14.0 : haut fait « Joyeux Voile d'hiver »")
	W.Reset(true)
	local def = NS:FeatDef("fun_winter_veil")
	Check("[NOEL] haut fait : Insolite, compte, drapeau winterVeil", def and def.cat == "fun" and def.scope == "account"
		and def.crit[1] == "flag" and def.crit[2] == "winterVeil" and def.n == 175)
	Check("[NOEL] haut fait : nom et description FR/EN", NS.L.FEAT_fun_winter_veil == "Joyeux Voile d'hiver"
		and NS.FEAT_MENAGERIE_STRINGS.en.FEAT_fun_winter_veil == "Merry Winter Veil"
		and NS.FEAT_MENAGERIE_STRINGS.en.FEATD_flag_winterVeil ~= nil)
	local store = NS:FeatStore("account")
	store.flag.winterVeil = nil
	NS:CompanionTick(3600)
	Check("[NOEL] sans compagnon de saison : rien", store.flag.winterVeil == nil)
	NS:CompanionSetAppearance("winter:snowman")
	NS:CompanionTick(1800)
	Check("[NOEL] une demi-heure : pas encore", store.flag.winterVeil == nil)
	NS:CompanionTick(1800)
	Check("[NOEL] une heure avec lui : le drapeau est posé", store.flag.winterVeil ~= nil)
	store.flag.winterVeil = nil
	local data = NS:CompanionData()
	data.winter.feat, data.winter.time, data.winter.caps = nil, 0, 9
	NS:CaptureResolve({ success = true, target = { npcID = 990214, name = "Loup d'essai", class = "normal", level = 10 } })
	Check("[NOEL] dix captures avec lui : le drapeau est posé", store.flag.winterVeil ~= nil and data.winter.caps == 10)
	NS:CaptureData().creatures[990214] = nil
	store.flag.winterVeil = nil
	data.winter.feat, data.winter.time, data.winter.caps = nil, 0, 0
	W.Season(false)
	NS:CompanionTick(7200)
	Check("[NOEL] hors saison : il ne se gagne plus", store.flag.winterVeil == nil)
	W.Done()
end
