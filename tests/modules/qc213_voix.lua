-- QC 2.13.0 : les voix du compagnon (CompanionVoices.lua). Le type de la
-- créature capturée choisit la voix, le caractère la colore, la voix commune
-- reste le repli (mascotte, type inconnu, argument manquant) ; même
-- anti-répétition ; chaque voix couvre les 12 situations de la planche.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local V = { share = NS.COMPANION_VOICE_SHARE, trait = NS.COMPANION_VOICE_TRAIT_SHARE, traitFn = NS.CompanionTrait,
	inCombat = rawget(_G, "InCombatLockdown"), affecting = rawget(_G, "UnitAffectingCombat"), random = math.random }
-- hasard à nous (un module précédent a pu laisser le sien) : reproductible
local seed = 2013
local function Random(a, b)
	seed = (seed * 1103515245 + 12345) % 2147483648
	local r = seed / 2147483648
	if not a then return r end
	if not b then return math.floor(r * a) + 1 end
	return a + math.floor(r * (b - a + 1))
end
local NPC = 990213

local function Specs(text)
	local list = {}
	for spec in tostring(text or ""):gsub("%%%%", ""):gmatch("%%[sd]") do list[#list + 1] = spec end
	return table.concat(list, ",")
end
local function Starts(key, prefix)
	if type(key) ~= "string" then return false end
	local tail = key:sub(#prefix + 1)
	return key:sub(1, #prefix) == prefix and (tail == "" or tail:match("^_%d+$") ~= nil)
end

function V.Reset(typeText)
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession = nil, nil
	NS.companionLastBubble, NS.companionBubbleKey, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil, nil
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	NS:CompanionData().tutoDone = true
	NS:DB().companionChatter = 3
	NS.CompanionTrait = function() return V.traitNow end
	V.traitNow = nil
	local data = NS:CaptureData()
	data.creatures[NPC] = typeText and { name = "Goule d'essai", type = typeText } or nil
	NS:CompanionData().appearance = typeText and ("cap:" .. NPC) or NS.COMPANION_APPEARANCES[1].id
	NS:CompanionVoiceForget()
	NS.COMPANION_VOICE_SHARE, NS.COMPANION_VOICE_TRAIT_SHARE = 1, 0
	math.random = Random
end
function V.Done()
	NS.COMPANION_VOICE_SHARE, NS.COMPANION_VOICE_TRAIT_SHARE, NS.CompanionTrait = V.share, V.trait, V.traitFn
	_G.InCombatLockdown, _G.UnitAffectingCombat = V.inCombat, V.affecting
	math.random = V.random
	NS:CaptureData().creatures[NPC] = nil
	NS:CompanionVoiceForget()
	ResetWorld()
end

-- 1. Les textes : 9 voix × 12 situations × au moins 3 répliques -----------------------------------
do
	Say("-- 2.13.0 : voix du compagnon, les textes")
	local fr, en = NS.COMPANION_LINE_STRINGS.fr, NS.COMPANION_LINE_STRINGS.en
	local POOLS = NS.COMPANION_POOLS
	-- arguments permis : ceux du réservoir commun (facultatifs)
	local ARGS = { KILL = "%s", CAPTURE_OK = "%s", CAPTURE_FAIL = "%s", SHINY_SPOTTED = "%s", LEVEL = "%s",
		CITY = "%s", DUNGEON = "%s" }
	local short, empty, specs, total = {}, {}, {}, 0
	Check("[VOIX] 9 voix", #NS.COMPANION_VOICE_TYPES == 9)
	Check("[VOIX] 12 situations", #NS.COMPANION_VOICE_SITUATIONS == 12)
	for _, kind in ipairs(NS.COMPANION_VOICE_TYPES) do
		for _, group in ipairs(NS.COMPANION_VOICE_SITUATIONS) do
			local count = 0
			for _, base in ipairs(group) do
				local keys = POOLS[base .. "_V_" .. kind]
				-- situation partagée (ville / donjon, mort / retour) : chaque moitié parle
				if not keys or #keys < (#group > 1 and 2 or 3) then short[#short + 1] = base .. "_V_" .. kind end
				count = count + (keys and #keys or 0)
			end
			if count < 3 then short[#short + 1] = kind .. ":" .. group[1] end
		end
	end
	-- toutes les lignes de voix (et de caractère) : fr + en, mêmes arguments, permis
	for name, keys in pairs(POOLS) do
		local base = name:match("^(.-)_V_")
		if base then
			for _, key in ipairs(keys) do
				total = total + 1
				local f, e = fr[key], en[key]
				if type(f) ~= "string" or f == "" or type(e) ~= "string" or e == "" then empty[#empty + 1] = key end
				local spec = Specs(f)
				if spec ~= Specs(e) or (spec ~= "" and spec ~= ARGS[base]) then specs[#specs + 1] = key end
			end
		end
	end
	table.sort(short); table.sort(empty); table.sort(specs)
	Check("[VOIX] chaque voix couvre les 12 situations (au moins 3 répliques)", #short == 0, table.concat(short, ", "))
	Check("[VOIX] aucune réplique vide, français et anglais", #empty == 0, table.concat(empty, ", "))
	Check("[VOIX] arguments : les mêmes en fr/en, ceux du réservoir commun", #specs == 0, table.concat(specs, ", "))
	Check("[VOIX] plus de 300 répliques de voix", total >= 300, tostring(total))
	local overlays = 0
	for name in pairs(POOLS) do if name:match("_V_%l+_%l+$") then overlays = overlays + 1 end end
	Check("[VOIX] des touches de caractère (au moins 9)", overlays >= 9, tostring(overlays))
	Check("[VOIX] planche : la ligne validée est là, verbatim",
		fr[POOLS.KILL_V_mechanical[2]] == "Bip bip. %s : hors service. Garantie non applicable."
		and en[POOLS.HELLO_V_undead[1]] == "I'm back! Well… what's left of me.")
	Check("[VOIX] donjon : un réservoir commun pour toutes les créatures", #(POOLS.DUNGEON or {}) >= 3)
end

-- 2. Le type de la créature compagnon ------------------------------------------------------------
do
	Say("-- 2.13.0 : voix du compagnon, le type")
	V.Reset("Mort-vivant")
	Check("[VOIX] capturée « Mort-vivant » : voix undead", NS:CompanionVoiceType() == "undead")
	V.Reset("Mechanical")
	Check("[VOIX] nom anglais du client : mechanical", NS:CompanionVoiceType() == "mechanical")
	V.Reset("Bestiole")
	Check("[VOIX] bestiole : voix critter", NS:CompanionVoiceType() == "critter")
	V.Reset("Inconnu")
	Check("[VOIX] type inconnu : pas de voix", NS:CompanionVoiceType() == nil)
	V.Reset(nil)
	Check("[VOIX] mascotte : pas de voix", NS:CompanionVoiceType() == nil)
	-- capture ancienne sans type : le carnet le connaît
	V.Reset("Démon")
	NS:CaptureData().creatures[NPC].type = nil
	local book = NS:BestiaryData()
	book[1413] = book[1413] or {}
	book[1413][NPC] = { name = "Goule d'essai", type = "Demon" }
	NS:CompanionVoiceForget()
	Check("[VOIX] type appris par le carnet", NS:CompanionVoiceType() == "demon")
	book[1413][NPC] = nil
	V.Done()
end

-- 3. Le choix d'une ligne : voix, caractère, repli -------------------------------------------------
do
	Say("-- 2.13.0 : voix du compagnon, le choix")
	V.Reset("Mort-vivant")
	Check("[VOIX] voix : la ligne vient de KILL_V_undead", Starts(NS:CompanionVoicePick("KILL", { "Gnoll" }), "COMP_SAY_KILL_V_undead"))
	Check("[VOIX] réservoir voisin : MISSED parle avec la voix d'accueil", Starts(NS:CompanionVoicePick("MISSED"), "COMP_SAY_HELLO_V_undead"))
	Check("[VOIX] DRINK prend la voix du repas", Starts(NS:CompanionVoicePick("DRINK"), "COMP_SAY_EAT_V_undead"))
	Check("[VOIX] brillante capturée : voix de capture", Starts(NS:CompanionVoicePick("CAPTURE_SHINY", { "X" }), "COMP_SAY_CAPTURE_OK_V_undead"))
	Check("[VOIX] situation sans voix (butin) : la commune", Starts(NS:CompanionVoicePick("LOOT"), "COMP_SAY_LOOT"))
	-- sans nom : jamais la ligne à « %s »
	local fr = NS.COMPANION_LINE_STRINGS.fr
	local clean = true
	for _ = 1, 12 do
		local key = NS:CompanionVoicePick("KILL")
		if not key or fr[key]:find("%%s") then clean = false end
	end
	Check("[VOIX] sans argument, les lignes à %s sont écartées", clean)
	-- caractère : la touche par-dessus la voix
	V.traitNow, NS.COMPANION_VOICE_TRAIT_SHARE = "teasing", 1
	Check("[VOIX] taquin : KILL_V_undead_teasing", Starts(NS:CompanionVoicePick("KILL"), "COMP_SAY_KILL_V_undead_teasing"))
	V.traitNow = "lazy"
	Check("[VOIX] caractère sans touche : la voix seule", Starts(NS:CompanionVoicePick("KILL"), "COMP_SAY_KILL_V_undead"))
	-- la part de voix à 0 : la ligne commune
	NS.COMPANION_VOICE_SHARE = 0
	local generic = NS:CompanionVoicePick("KILL")
	-- (le caractère commun, Personality.lua, peut glisser sa version « KILL__<caractère> »)
	Check("[VOIX] part 0 : réservoir commun", Starts(generic, "COMP_SAY_KILL") or tostring(generic):find("^COMP_SAY_KILL__") ~= nil, tostring(generic))
	NS.COMPANION_VOICE_SHARE = 1
	-- mascotte : la voix commune
	V.Reset(nil)
	Check("[VOIX] mascotte : réservoir commun", Starts(NS:CompanionVoicePick("NIGHT"), "COMP_SAY_NIGHT"))
	-- voix dont aucune ligne n'est utilisable (toutes à %s, sans nom) : repli
	V.Reset("Mort-vivant")
	NS.RegisterCompanionLines({ ZZVOIX = { { "Commun.", "Common." } }, ZZVOIX_V_undead = { { "%s voix.", "%s voice." } } })
	NS.COMPANION_VOICE_OF.ZZVOIX = "ZZVOIX"
	Check("[VOIX] argument manquant : repli sur la commune", NS:CompanionVoicePick("ZZVOIX") == "COMP_SAY_ZZVOIX")
	Check("[VOIX] argument présent : la voix", NS:CompanionVoicePick("ZZVOIX", { "Nom" }) == "COMP_SAY_ZZVOIX_V_undead")
	NS.COMPANION_VOICE_OF.ZZVOIX = nil
	for _, key in ipairs({ "COMP_SAY_ZZVOIX", "COMP_SAY_ZZVOIX_V_undead" }) do
		NS.COMPANION_LINE_STRINGS.fr[key], NS.COMPANION_LINE_STRINGS.en[key] = nil, nil
	end
	rawset(NS.COMPANION_POOLS, "ZZVOIX", nil); rawset(NS.COMPANION_POOLS, "ZZVOIX_V_undead", nil)
	V.Done()
end

-- 4. Anti-répétition, bulle, nom de la victime ----------------------------------------------------
do
	Say("-- 2.13.0 : voix du compagnon, répétition et bulle")
	V.Reset("Mécanique")
	NS:CompanionData().appearance = "cap:" .. NPC
	NS:CaptureData().creatures[NPC].type = "Mechanical"
	NS:CompanionVoiceForget()
	local seen, distinct = {}, 0
	for _ = 1, 3 do
		local key = NS:CompanionVoicePick("KILL", { "Gnoll" })
		if key and not seen[key] then distinct = distinct + 1 end
		if key then seen[key] = true end
	end
	Check("[VOIX] trois tirages de suite : trois lignes différentes", distinct == 3)
	Check("[VOIX] mémoire des lignes récentes : par réservoir de voix", #(NS.companionRT.recent.KILL_V_mechanical or {}) == 2)
	local a = NS:CompanionVoicePick("NIGHT")
	local b = NS:CompanionVoicePick("NIGHT")
	Check("[VOIX] jamais deux fois de suite la même", a ~= nil and a ~= b)
	-- la bulle : la voix passe par CompanionSay (portes inchangées)
	NS.companionRT.cool = {}
	local said = NS:CompanionSay("LEVEL", { args = { 12 } })
	Check("[VOIX] bulle : réservoir commun gardé, ligne de la voix", said == true and NS.companionBubbleKey == "LEVEL"
		and Starts(NS.companionBubbleLine, "COMP_SAY_LEVEL_V_mechanical"), tostring(NS.companionBubbleLine))
	_G.InCombatLockdown = function() return true end
	_G.UnitAffectingCombat = function() return true end
	NS.companionLastBubble, NS.companionBubbleUntil = nil, nil
	local ok, why = NS:CompanionSay("KILL", { args = { "Gnoll" } })
	Check("[VOIX] en combat : toujours retenu (barrière inchangée)", ok == false and why == "combat")
	Check("[VOIX] le nom de la victime est gardé pour après le combat", NS.companionRT.combat and NS.companionRT.combat.killName == "Gnoll")
	NS.companionRT.combat = nil
	V.Done()
end
