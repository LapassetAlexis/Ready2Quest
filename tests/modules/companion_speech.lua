-- Compagnon : ce qu'il dit.
-- 1. Répliques (CompanionLines.lua, PersonalityLines.lua) : mêmes « %s » /
--    « %d » par réservoir et en fr/en, bulles courtes, pas de doublon, volume.
-- 2. Réglette « Bavardage » (0 Muet … 4 Bavard) : reprise des anciens
--    interrupteurs, ce que chaque cran laisse dire et à quel rythme, ligne du
--    panneau, sourdine qui retient le cran.
-- 3. Voix (QC 2.13.0, CompanionVoices.lua) : le type de la créature choisit la
--    voix, le caractère la colore, repli sur la commune ; 12 situations par voix.
-- 4. Blagues (QC 2.13.0, CompanionJokes.lua) : réservoirs, part au repos,
--    /qc blague (même muet, jamais en combat), réglage.
-- 5. Histoire des lieux (QC 2.13.0, LoreData.lua / CompanionLore.lua) : forme
--    des données, coupe, une fois par zone / sous-zone, silences, noms fr.
--    (concordance LoreData.lua <-> lore.json : tests/run_tests.py)
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


-- 1. Répliques ================================================================================

local function Specs(text)
	local list = {}
	for spec in tostring(text or ""):gsub("%%%%", ""):gmatch("%%[sd]") do list[#list + 1] = spec end
	return table.concat(list, ",")
end

-- longueur en caractères (UTF-8), pas en octets
local function Chars(text)
	return select(2, tostring(text or ""):gsub("[^\128-\191]", ""))
end

-- réservoirs dont l'argument EST le message (niveau, stade, tampon…) : toutes
-- les lignes le reprennent, comme la première
local STRICT = { HELLO = true, LEVEL = true, READY = true, CHEST = true, EVOLVE = true, UNLOCK = true,
	STAMP = true, GOAL = true, GOAL_STAGE = true }
local function Strict(pool)
	return STRICT[pool] or pool:find("^ADVICE_") ~= nil or pool:find("^GROUP_") ~= nil
end

do
	Say("-- répliques : arguments, doublons, longueur, volume")
	local fr, en = NS.COMPANION_LINE_STRINGS.fr, NS.COMPANION_LINE_STRINGS.en
	local bad, long, dupes, seen = {}, {}, {}, {}
	for pool, keys in pairs(NS.COMPANION_POOLS) do
		local base, trait = pool:match("^(.-)__(.+)$")
		local ref = Specs(fr[keys[1]])
		local widest = ref
		for _, key in ipairs(keys) do
			if #Specs(fr[key]) > #widest then widest = Specs(fr[key]) end
		end
		for _, key in ipairs(keys) do
			local spec = Specs(fr[key])
			local ok
			if base == "NOTICE" then
				-- remarque de caractère : au plus les arguments de la première
				ok = ref:sub(1, #spec) == spec
			elseif base then
				-- version d'un caractère : sans argument, ou ceux du réservoir commun
				local shared = NS.COMPANION_POOLS[base]
				ok = spec == "" or (shared ~= nil and spec == Specs(fr[shared[1]]))
			elseif Strict(pool) then
				ok = spec == ref
			else
				-- argument facultatif (nom du PNJ, de la ville, 1re bulle du
				-- tutoriel…) : jamais plus, ni d'autres, que la ligne la plus fournie
				ok = widest:sub(1, #spec) == spec
			end
			if not ok then bad[#bad + 1] = key end
			if Specs(en[key]) ~= spec then bad[#bad + 1] = key .. " (fr/en)" end
			-- astuces et tutoriel de base (TUTO) : 130
			local limit = (pool == "TIP" or pool:find("^TUTO") ~= nil) and 130 or 100
			if Chars(fr[key]) > limit or Chars(en[key]) > limit then long[#long + 1] = key end
			local text = fr[key]
			if text and seen[text] and seen[text] ~= key then dupes[#dupes + 1] = key .. "=" .. seen[text] end
			if text then seen[text] = seen[text] or key end
		end
	end
	table.sort(bad)
	table.sort(long)
	table.sort(dupes)
	Check("[LINES] chaque ligne garde les arguments de son réservoir", #bad == 0, table.concat(bad, ", "))
	Check("[LINES] bulles courtes (100 caractères, 130 pour astuces et tutoriel)", #long == 0, table.concat(long, ", "))
	Check("[LINES] aucune réplique en double", #dupes == 0, table.concat(dupes, ", "))

	-- volume : les situations fréquentes ont de quoi varier toute une soirée
	local frequent = { KILL = 20, DEAD = 12, REZ = 12, IDLE = 15, LOOT = 12, QUEST = 12, LEVEL = 10, EAT = 10, VIEW = 10 }
	local short = {}
	for pool, n in pairs(frequent) do
		if #(NS.COMPANION_POOLS[pool] or {}) < n then short[#short + 1] = pool .. "=" .. #(NS.COMPANION_POOLS[pool] or {}) end
	end
	-- chaque caractère : au moins 4 versions par situation (sauf l'annonce)
	for name, keys in pairs(NS.PERSONALITY_POOLS) do
		if not name:find("^FORMED__") and #keys < 4 then short[#short + 1] = name .. "=" .. #keys end
	end
	table.sort(short)
	Check("[LINES] assez de répliques par situation et par caractère", #short == 0, table.concat(short, ", "))
	local total = 0
	for _, keys in pairs(NS.PERSONALITY_POOLS) do total = total + #keys end
	Check("[LINES] répliques de caractère : 1000 et plus", total >= 1000, total)

	-- tirage : sur 40 bulles d'affilée, beaucoup de lignes différentes
	NS.companionRT = nil
	local distinct, n = {}, 0
	for _ = 1, 40 do
		local key = NS:CompanionPick("KILL")
		if key and not distinct[key] then distinct[key] = true; n = n + 1 end
	end
	Check("[LINES] 40 victoires : au moins 12 répliques différentes", n >= 12, n)
	NS.companionRT = nil
end

-- 2. Bavardage ================================================================================

local B = {}
function B.Reset(level)
	ResetWorld()
	NS.companionRT, NS.companionSession = nil, nil
	NS.companionLastBubble, NS.companionBubbleKey, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil, nil
	Mock.world.level = 11
	NS:CompanionData().tutoDone = true
	NS:DB().companionChatter = level
end
-- chaque essai : on oublie la bulle précédente (seul le cran compte ici)
function B.Say(pool, opts)
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	if NS.companionRT then NS.companionRT.lastAdvice = nil; NS.companionRT.cool = {} end
	return NS:CompanionSay(pool, opts) == true
end

-- 1. Reprise des anciens interrupteurs ------------------------------------------------------
do
	Say("-- bavardage : reprise")
	local S = Scenario("[CHAT] reprise")
	B.Reset(nil)
	S.ok("par défaut : Normal (3)", NS:CompanionChatterLevel() == 3 and NS:DB().companionChatter == 3)
	B.Reset(nil)
	NS:DB().companionBubbles = false
	S.ok("bulles coupées avant : Muet (0)", NS:CompanionChatterLevel() == 0)
	B.Reset(nil)
	NS:DB().companionTips = false
	S.ok("astuces coupées avant : Calme (2)", NS:CompanionChatterLevel() == 2)
	B.Reset(9)
	S.ok("valeur hors bornes ramenée à 4", NS:CompanionChatterLevel() == 4)
	S.done()
end

-- 2. Ce que chaque cran laisse dire --------------------------------------------------------
do
	Say("-- bavardage : crans")
	local S = Scenario("[CHAT] crans")
	B.Reset(0)
	S.ok("Muet : rien, même un événement", not B.Say("QUEST") and not B.Say("EVOLVE", { force = true, args = { "X" } })
		and not B.Say("QUEST", { category = "advice", important = true }))

	B.Reset(1)
	S.ok("Discret : conseil important, oui", B.Say("QUEST", { category = "advice", important = true }))
	S.ok("Discret : conseil ordinaire, non", not B.Say("QUEST", { category = "advice" }))
	S.ok("Discret : ni réaction ni événement", not B.Say("QUEST") and not B.Say("EVOLVE", { args = { "X" } }))

	B.Reset(2)
	S.ok("Calme : tous les conseils et les grands moments", B.Say("QUEST", { category = "advice" })
		and B.Say("EVOLVE", { args = { "X" } }))
	S.ok("Calme : pas de réaction, pas d'astuce", not B.Say("QUEST") and NS:CompanionTryTip(true) == false)

	B.Reset(3)
	S.ok("Normal : réactions et conseils", B.Say("QUEST") and B.Say("QUEST", { category = "advice" }))

	-- rythme : écart entre deux bulles ordinaires, et entre deux conseils
	local gaps = {}
	for level = 3, 4 do
		B.Reset(level)
		NS:CompanionSay("QUEST")
		local start = NS.companionLastBubble
		Mock.now = start + NS.COMPANION_CHATTER[level].bubble - 1
		NS.companionBubbleUntil = nil
		local early = NS:CompanionSay("QUEST") == true
		Mock.now = start + NS.COMPANION_CHATTER[level].bubble + 1
		NS.companionBubbleUntil = nil
		local late = NS:CompanionSay("QUEST") == true
		gaps[level] = (not early) and late
	end
	S.done()
	S = Scenario("[CHAT] rythme : écart des bulles, des conseils, pauses par famille")
	S.ok("écart entre deux réactions : 20 s (Normal), 10 s (Bavard)", gaps[3] and gaps[4]
		and NS.COMPANION_CHATTER[3].bubble == 20 and NS.COMPANION_CHATTER[4].bubble == 10)

	B.Reset(3)
	NS:CompanionSay("QUEST", { category = "advice" })
	local first = NS.companionRT.lastAdvice
	NS.companionBubbleUntil, NS.companionLastBubble = nil, nil
	Mock.now = first + 60
	S.ok("deux conseils : pas avant 2 min (Normal)", NS:CompanionSay("QUEST", { category = "advice" }) == false)
	Mock.now = first + 121
	S.ok("… puis oui", NS:CompanionSay("QUEST", { category = "advice" }) == true)
	B.Reset(4)
	NS:CompanionSay("QUEST", { category = "advice" })
	first = NS.companionRT.lastAdvice
	NS.companionBubbleUntil, NS.companionLastBubble = nil, nil
	Mock.now = first + 61
	S.ok("Bavard : un conseil par minute", NS:CompanionSay("QUEST", { category = "advice" }) == true)
	B.Reset(4)
	NS:CompanionSay("QUEST", { cd = "kill" })
	S.ok("Bavard : pauses par famille divisées par deux",
		math.abs((NS.companionRT.cool.kill - Mock.now) - NS.COMPANION_RULES.cooldowns.kill / 2) < 0.01)
	S.done()
end

-- 3. Ligne du panneau ----------------------------------------------------------------------
do
	Say("-- bavardage : réglage")
	local S = Scenario("[CHAT] réglage")
	B.Reset(3)
	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companionMain")
	local row
	for _, r in ipairs(NS.optionsFrame.rows) do if r.def and r.def.key == "companionChatter" then row = r end end
	S.ok("réglette dans la page Compagnon", row and row.def.kind == "number" and row.def.min == 0 and row.def.max == 4)
	S.ok("le cran s'affiche par son nom", row and row.value.text:find("Normal", 1, true) ~= nil, row and row.value.text)
	S.ok("une phrase dit ce qu'il fait", row and row.note and row.note.text == NS.L.COMP_CHATTER_DESC_3)
	_G.GameTooltip.lines = {}
	row.scripts.OnEnter(row)
	local tip = table.concat(_G.GameTooltip.lines, " | ")
	S.ok("infobulle : les cinq crans, le choisi en avant", #_G.GameTooltip.lines >= 7
		and tip:find(NS.L.COMP_CHATTER_DESC_0, 1, true) and tip:find("> " .. NS.L.COMP_CHATTER_DESC_3, 1, true), tip)
	row.scripts.OnLeave(row)

	NS.companionBubbleKey = nil
	row:Step(-1)
	S.done()
	S = Scenario("[CHAT] réglette : pas à pas, bulle de confirmation, bornes")
	S.ok("« - » : Calme, il le confirme", NS:DB().companionChatter == 2 and NS.companionBubbleKey == "CHATTER_2"
		and row.value.text:find("Calme", 1, true) and row.note.text == NS.L.COMP_CHATTER_DESC_2)
	row:Step(-1); row:Step(-1)
	S.ok("jusqu'à Muet : la bulle s'en va", NS:DB().companionChatter == 0
		and not (NS.companionBubble and NS.companionBubble:IsShown()))
	row:Step(-1)
	S.ok("pas en dessous de 0", NS:DB().companionChatter == 0)
	NS.optionsFrame:Hide()
	S.done()
end

-- 4. Sourdine et tutoriel ------------------------------------------------------------------
do
	Say("-- bavardage : sourdine")
	local S = Scenario("[CHAT] sourdine")
	B.Reset(2)
	NS:HandleCommand("compagnon muet")
	S.ok("muet : réglette à 0, le cran d'avant retenu", NS:DB().companionChatter == 0
		and NS:DB().companionChatterBefore == 2)
	NS:HandleCommand("compagnon muet")
	S.ok("muet à nouveau : retour au cran d'avant (Calme)", NS:DB().companionChatter == 2)
	local tuto = {}
	for _, key in ipairs(NS.COMPANION_POOLS.TUTO) do tuto[#tuto + 1] = NS.L[key] end
	S.ok("le tutoriel présente les conseils de route et la réglette",
		table.concat(tuto, " "):find("Bavardage", 1, true) and table.concat(tuto, " "):find("munitions", 1, true))
	B.Reset(3)
	S.done()
end

-- 3. Voix =====================================================================================

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
	local S = Scenario("[VOIX] 9 voix × 12 situations, arguments permis")
	local fr, en = NS.COMPANION_LINE_STRINGS.fr, NS.COMPANION_LINE_STRINGS.en
	local POOLS = NS.COMPANION_POOLS
	-- arguments permis : ceux du réservoir commun (facultatifs)
	local ARGS = { KILL = "%s", CAPTURE_OK = "%s", CAPTURE_FAIL = "%s", SHINY_SPOTTED = "%s", LEVEL = "%s",
		CITY = "%s", DUNGEON = "%s" }
	local short, empty, specs, total = {}, {}, {}, 0
	S.ok("9 voix", #NS.COMPANION_VOICE_TYPES == 9)
	S.ok("12 situations", #NS.COMPANION_VOICE_SITUATIONS == 12)
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
	S.ok("chaque voix couvre les 12 situations (au moins 3 répliques)", #short == 0, table.concat(short, ", "))
	S.ok("arguments : les mêmes en fr/en, ceux du réservoir commun", #specs == 0, table.concat(specs, ", "))
	S.ok("plus de 300 répliques de voix", total >= 300, tostring(total))
	local overlays = 0
	for name in pairs(POOLS) do if name:match("_V_%l+_%l+$") then overlays = overlays + 1 end end
	S.done()
	S = Scenario("[VOIX] textes : volume, caractère, planche, donjon")
	S.ok("des touches de caractère (au moins 9)", overlays >= 9, tostring(overlays))
	S.ok("planche : la ligne validée est là, verbatim",
		fr[POOLS.KILL_V_mechanical[2]] == "Bip bip. %s : hors service. Garantie non applicable."
		and en[POOLS.HELLO_V_undead[1]] == "I'm back! Well… what's left of me.")
	S.ok("donjon : un réservoir commun pour toutes les créatures", #(POOLS.DUNGEON or {}) >= 3)
	S.done()
end

-- 2. Le type de la créature compagnon ------------------------------------------------------------
do
	Say("-- 2.13.0 : voix du compagnon, le type")
	local S = Scenario("[VOIX] le type")
	V.Reset("Mort-vivant")
	S.ok("capturée « Mort-vivant » : voix undead", NS:CompanionVoiceType() == "undead")
	V.Reset("Mechanical")
	S.ok("nom anglais du client : mechanical", NS:CompanionVoiceType() == "mechanical")
	V.Reset("Bestiole")
	S.ok("bestiole : voix critter", NS:CompanionVoiceType() == "critter")
	V.Reset("Inconnu")
	S.ok("type inconnu : pas de voix", NS:CompanionVoiceType() == nil)
	V.Reset(nil)
	S.ok("mascotte : pas de voix", NS:CompanionVoiceType() == nil)
	-- capture ancienne sans type : le carnet le connaît
	V.Reset("Démon")
	NS:CaptureData().creatures[NPC].type = nil
	local book = NS:BestiaryData()
	book[1413] = book[1413] or {}
	book[1413][NPC] = { name = "Goule d'essai", type = "Demon" }
	NS:CompanionVoiceForget()
	S.ok("type appris par le carnet", NS:CompanionVoiceType() == "demon")
	book[1413][NPC] = nil
	V.Done()
	S.done()
end

-- 3. Le choix d'une ligne : voix, caractère, repli -------------------------------------------------
do
	Say("-- 2.13.0 : voix du compagnon, le choix")
	local S = Scenario("[VOIX] le choix")
	V.Reset("Mort-vivant")
	S.ok("voix : la ligne vient de KILL_V_undead", Starts(NS:CompanionVoicePick("KILL", { "Gnoll" }), "COMP_SAY_KILL_V_undead"))
	S.ok("réservoir voisin : MISSED parle avec la voix d'accueil", Starts(NS:CompanionVoicePick("MISSED"), "COMP_SAY_HELLO_V_undead"))
	S.ok("DRINK prend la voix du repas", Starts(NS:CompanionVoicePick("DRINK"), "COMP_SAY_EAT_V_undead"))
	S.ok("brillante capturée : voix de capture", Starts(NS:CompanionVoicePick("CAPTURE_SHINY", { "X" }), "COMP_SAY_CAPTURE_OK_V_undead"))
	S.ok("situation sans voix (butin) : la commune", Starts(NS:CompanionVoicePick("LOOT"), "COMP_SAY_LOOT"))
	-- sans nom : jamais la ligne à « %s »
	local fr = NS.COMPANION_LINE_STRINGS.fr
	local clean = true
	for _ = 1, 12 do
		local key = NS:CompanionVoicePick("KILL")
		if not key or fr[key]:find("%%s") then clean = false end
	end
	S.ok("sans argument, les lignes à %s sont écartées", clean)
	-- caractère : la touche par-dessus la voix
	V.traitNow, NS.COMPANION_VOICE_TRAIT_SHARE = "teasing", 1
	S.done()
	S = Scenario("[VOIX] caractère par-dessus la voix, repli sur la commune")
	S.ok("taquin : KILL_V_undead_teasing", Starts(NS:CompanionVoicePick("KILL"), "COMP_SAY_KILL_V_undead_teasing"))
	V.traitNow = "lazy"
	S.ok("caractère sans touche : la voix seule", Starts(NS:CompanionVoicePick("KILL"), "COMP_SAY_KILL_V_undead"))
	-- la part de voix à 0 : la ligne commune
	NS.COMPANION_VOICE_SHARE = 0
	local generic = NS:CompanionVoicePick("KILL")
	-- (le caractère commun, Personality.lua, peut glisser sa version « KILL__<caractère> »)
	S.ok("part 0 : réservoir commun", Starts(generic, "COMP_SAY_KILL") or tostring(generic):find("^COMP_SAY_KILL__") ~= nil, tostring(generic))
	NS.COMPANION_VOICE_SHARE = 1
	-- mascotte : la voix commune
	V.Reset(nil)
	S.ok("mascotte : réservoir commun", Starts(NS:CompanionVoicePick("NIGHT"), "COMP_SAY_NIGHT"))
	-- voix dont aucune ligne n'est utilisable (toutes à %s, sans nom) : repli
	V.Reset("Mort-vivant")
	NS.RegisterCompanionLines({ ZZVOIX = { { "Commun.", "Common." } }, ZZVOIX_V_undead = { { "%s voix.", "%s voice." } } })
	NS.COMPANION_VOICE_OF.ZZVOIX = "ZZVOIX"
	S.ok("argument manquant : repli sur la commune", NS:CompanionVoicePick("ZZVOIX") == "COMP_SAY_ZZVOIX")
	S.ok("argument présent : la voix", NS:CompanionVoicePick("ZZVOIX", { "Nom" }) == "COMP_SAY_ZZVOIX_V_undead")
	NS.COMPANION_VOICE_OF.ZZVOIX = nil
	for _, key in ipairs({ "COMP_SAY_ZZVOIX", "COMP_SAY_ZZVOIX_V_undead" }) do
		NS.COMPANION_LINE_STRINGS.fr[key], NS.COMPANION_LINE_STRINGS.en[key] = nil, nil
	end
	rawset(NS.COMPANION_POOLS, "ZZVOIX", nil); rawset(NS.COMPANION_POOLS, "ZZVOIX_V_undead", nil)
	V.Done()
	S.done()
end

-- 4. Anti-répétition, bulle, nom de la victime ----------------------------------------------------
do
	Say("-- 2.13.0 : voix du compagnon, répétition et bulle")
	local S = Scenario("[VOIX] répétition et bulle")
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
	S.ok("trois tirages de suite : trois lignes différentes", distinct == 3)
	S.ok("mémoire des lignes récentes : par réservoir de voix", #(NS.companionRT.recent.KILL_V_mechanical or {}) == 2)
	local a = NS:CompanionVoicePick("NIGHT")
	local b = NS:CompanionVoicePick("NIGHT")
	S.ok("jamais deux fois de suite la même", a ~= nil and a ~= b)
	-- la bulle : la voix passe par CompanionSay (portes inchangées)
	NS.companionRT.cool = {}
	local said = NS:CompanionSay("LEVEL", { args = { 12 } })
	S.ok("bulle : réservoir commun gardé, ligne de la voix", said == true and NS.companionBubbleKey == "LEVEL"
		and Starts(NS.companionBubbleLine, "COMP_SAY_LEVEL_V_mechanical"), tostring(NS.companionBubbleLine))
	_G.InCombatLockdown = function() return true end
	_G.UnitAffectingCombat = function() return true end
	NS.companionLastBubble, NS.companionBubbleUntil = nil, nil
	local ok, why = NS:CompanionSay("KILL", { args = { "Gnoll" } })
	S.ok("en combat : toujours retenu (barrière inchangée)", ok == false and why == "combat")
	S.ok("le nom de la victime est gardé pour après le combat", NS.companionRT.combat and NS.companionRT.combat.killName == "Gnoll")
	NS.companionRT.combat = nil
	V.Done()
	S.done()
end

-- 4. Blagues ==================================================================================

local B = { random = math.random, share = NS.COMPANION_JOKE_SHARE, voiceShare = NS.COMPANION_VOICE_SHARE,
	resting = rawget(_G, "IsResting"), inCombat = rawget(_G, "InCombatLockdown"), affecting = rawget(_G, "UnitAffectingCombat") }
local seed = 2132
local function Random(a, b)
	seed = (seed * 1103515245 + 12345) % 2147483648
	local r = seed / 2147483648
	if not a then return r end
	if not b then return math.floor(r * a) + 1 end
	return a + math.floor(r * (b - a + 1))
end
local NPC = 990214

function B.Free()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.companionBubbleText, NS.companionBubbleLine = nil, nil
	if NS.companionRT then NS.companionRT.cool = {}; NS.companionRT.seq = nil; NS.companionRT.restIdle = 0 end
end
function B.Reset(typeText)
	ResetWorld()
	NS.companionRT, NS.companionSession, NS.companionFighting = nil, nil, nil
	B.Free()
	B.combat = false
	_G.InCombatLockdown = function() return B.combat end
	_G.UnitAffectingCombat = function() return B.combat end
	_G.IsResting = function() return true end
	NS:CompanionData().tutoDone = true
	NS:DB().companionChatter = 3
	NS:DB().companionJokes = nil
	NS:DB().companionShow = nil
	local data = NS:CaptureData()
	data.creatures[NPC] = typeText and { name = "Bestiole d'essai", type = typeText } or nil
	NS:CompanionData().appearance = typeText and ("cap:" .. NPC) or NS.COMPANION_APPEARANCES[1].id
	NS:CompanionVoiceForget()
	NS:CompanionUpdateVisibility()
	math.random = Random
end
function B.Done()
	math.random = B.random
	NS.COMPANION_JOKE_SHARE, NS.COMPANION_VOICE_SHARE = B.share, B.voiceShare
	_G.IsResting, _G.InCombatLockdown, _G.UnitAffectingCombat = B.resting, B.inCombat, B.affecting
	NS:CaptureData().creatures[NPC] = nil
	NS:DB().companionJokes, NS:DB().companionChatter = nil, 3
	NS:CompanionVoiceForget()
	B.Free()
	ResetWorld()
end
local function Logged(text)
	for _, line in ipairs(Mock.output) do if line:find(text, 1, true) then return true end end
	return false
end
local function Is(key, prefix)
	return type(key) == "string" and key:sub(1, #prefix) == prefix and (key == prefix or key:sub(#prefix + 1):match("^_%d+$") ~= nil)
end

-- 1. Les textes ---------------------------------------------------------------------------------
do
	Say("-- 2.13.0 : blagues, les textes")
	local S = Scenario("[BLAGUE] volume : 30 communes, 6 par voix")
	local fr, en, POOLS = NS.COMPANION_LINE_STRINGS.fr, NS.COMPANION_LINE_STRINGS.en, NS.COMPANION_POOLS
	S.ok("réservoir commun : au moins 30 blagues", #(POOLS.JOKE or {}) >= 30, tostring(#(POOLS.JOKE or {})))
	local short, odd, long = {}, {}, {}
	local names = { "JOKE" }
	for _, kind in ipairs(NS.COMPANION_VOICE_TYPES) do
		names[#names + 1] = "JOKE_V_" .. kind
		if #(POOLS["JOKE_V_" .. kind] or {}) < 6 then short[#short + 1] = kind end
	end
	for _, name in ipairs(names) do
		for _, key in ipairs(POOLS[name] or {}) do
			local f, e = fr[key], en[key]
			if type(f) ~= "string" or f == "" or type(e) ~= "string" or e == "" or f == e
				or f:find("%%") or e:find("%%") or f:find("[{}<>|]") or e:find("[{}<>|]") or e:find("\"", 1, true) then
				odd[#odd + 1] = key
			elseif #f > 200 or #e > 200 then long[#long + 1] = key end
		end
	end
	S.ok("9 voix, au moins 6 blagues chacune", #short == 0, table.concat(short, ", "))
	S.done()
	S = Scenario("[BLAGUE] textes : formes et longueur")
	S.ok("aucune blague vide, identique fr/en ou à balise", #odd == 0, table.concat(odd, ", "))
	S.ok("assez courtes pour la bulle (200 octets)", #long == 0, table.concat(long, ", "))
	S.done()
	S = Scenario("[BLAGUE] branchement : voix, réglage, aide, commandes")
	S.ok("la voix des blagues est branchée", NS.COMPANION_VOICE_OF.JOKE == "JOKE")
	S.ok("réglage activé par défaut", NS:DB().companionJokes ~= false)
	local row = false
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		for index, r in ipairs(page.rows or {}) do
			if r.key == "companionJokes" then row = page.rows[index - 1] and page.rows[index - 1].key or true end
		end
	end
	S.ok("réglage sous l'histoire des lieux", row == "companionLore", tostring(row))
	local help = false
	for _, section in ipairs(NS.HELP) do for _, key in ipairs(section[2]) do if key == "HELP_JOKE" then help = true end end end
	S.ok("/qc blague dans l'aide", help and NS.L.HELP_JOKE:find("/qc blague", 1, true) ~= nil)
	S.ok("/qc blague et /qc joke enregistrées", type(NS.EXTRA_COMMANDS.blague) == "function"
		and NS.EXTRA_COMMANDS.joke == NS.EXTRA_COMMANDS.blague)
	S.done()
end

-- 2. Les voix -----------------------------------------------------------------------------------
do
	Say("-- 2.13.0 : blagues, les voix")
	local S = Scenario("[BLAGUE] les voix")
	local bad = {}
	for _, pair in ipairs({ { "Mort-vivant", "undead" }, { "Mechanical", "mechanical" }, { "Bestiole", "critter" },
		{ "Démon", "demon" }, { "Dragonkin", "dragonkin" } }) do
		B.Reset(pair[1])
		NS.COMPANION_VOICE_SHARE = 1
		if not Is(NS:CompanionVoicePick("JOKE"), "COMP_SAY_JOKE_V_" .. pair[2]) then bad[#bad + 1] = pair[2] end
	end
	S.ok("chaque type a sa voix de blagues", #bad == 0, table.concat(bad, ", "))
	B.Reset(nil)
	NS.COMPANION_VOICE_SHARE = 1
	S.ok("mascotte : blague commune", Is(NS:CompanionVoicePick("JOKE"), "COMP_SAY_JOKE"))
	B.Done()
	S.done()
end

-- 3. Au repos : une part des bavardages ---------------------------------------------------------
do
	Say("-- 2.13.0 : blagues, au repos")
	local S = Scenario("[BLAGUE] au repos")
	B.Reset(nil)
	local jokes, idles = 0, 0
	for _ = 1, 400 do
		B.Free()
		if NS:CompanionTryIdle(100000) then
			if NS.companionBubbleKey == "JOKE" then jokes = jokes + 1 elseif NS.companionBubbleKey == "IDLE" then idles = idles + 1 end
		end
	end
	local share = jokes / math.max(1, jokes + idles)
	S.ok("au repos : environ un bavardage sur quatre", jokes + idles >= 390 and share > 0.17 and share < 0.33,
		jokes .. " / " .. idles)
	NS:DB().companionJokes = false
	jokes = 0
	for _ = 1, 100 do
		B.Free()
		if NS:CompanionTryIdle(100000) and NS.companionBubbleKey == "JOKE" then jokes = jokes + 1 end
	end
	S.ok("réglage coupé : plus de blague spontanée", jokes == 0, tostring(jokes))
	NS:DB().companionJokes = nil
	NS.COMPANION_JOKE_SHARE = 1
	NS:DB().companionChatter = 2
	B.Free()
	S.ok("cran Calme : pas de blague spontanée", not NS:CompanionTryIdle(100000) and NS.companionBubbleKey == nil)
	NS:DB().companionChatter = 3
	B.Free()
	B.combat = true
	S.ok("jamais en combat (bavardages)", not NS:CompanionSay("JOKE", { cd = "idle" }) and NS.companionBubbleKey == nil)
	B.Done()
	S.done()
end

-- 4. /qc blague ---------------------------------------------------------------------------------
do
	Say("-- 2.13.0 : /qc blague")
	local S = Scenario("[BLAGUE] /qc blague")
	B.Reset(nil)
	NS:DB().companionChatter = 0
	NS:DB().companionJokes = false
	Mock.output = {}
	S.ok("/qc blague : une blague, même muet et réglage coupé",
		NS.EXTRA_COMMANDS.blague(NS, "") == true and NS.companionBubbleKey == "JOKE" and #Mock.output == 0)
	-- une autre bulle affichée : la demande passe quand même (écart forcé)
	B.Free()
	NS:DB().companionChatter = 3
	NS:CompanionSay("IDLE", {})
	S.ok("/qc joke passe après un bavardage", NS.EXTRA_COMMANDS.joke(NS, "") == true and NS.companionBubbleKey == "JOKE")
	B.Free()
	B.combat = true
	Mock.output = {}
	local note = NS.companionRT and NS.companionRT.combat
	S.done()
	S = Scenario("[BLAGUE] /qc blague en combat ou compagnon caché : refusée, on le dit")
	S.ok("en combat : refusée, et on le dit",
		NS.EXTRA_COMMANDS.blague(NS, "") == false and NS.companionBubbleKey == nil and Logged(NS.L.JOKE_MSG_COMBAT))
	S.ok("en combat : rien de noté pour le résumé", (NS.companionRT and NS.companionRT.combat) == note)
	B.combat = false
	NS:DB().companionShow = false
	Mock.output = {}
	S.ok("compagnon caché : on le dit", NS.EXTRA_COMMANDS.blague(NS, "") == false and Logged(NS.L.JOKE_MSG_OFF))
	B.Done()
	S.done()
end

-- 5. Histoire des lieux =======================================================================

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
	local S = Scenario("[LORE] données : deux langues, chaque ligne bien formée")
	local raw = NS.LORE_RAW
	S.ok("deux langues gardées en test", type(raw) == "table" and type(raw.fr) == "string" and type(raw.en) == "string")
	local function Count(text, tag)
		local n = 0
		for _ in text:gmatch("\n" .. tag .. "\t") do n = n + 1 end
		return n
	end
	local zf, ze, sf, se = Count(raw.fr, "Z"), Count(raw.en, "Z"), Count(raw.fr, "S"), Count(raw.en, "S")
	S.ok("autant de zones et sous-zones en fr qu'en en", zf == ze and sf == se and zf >= 40 and sf >= 200,
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
	S.ok("chaque ligne : texte qui tient dans la bulle et page du wiki", bad == nil, bad)
	NS.loreLang = "fr"
	S.done()
	S = Scenario("[LORE] recherche : zone, sous-zone fr/en, normalisation")
	S.ok("zone : Durotar (fr)", (NS:LoreZone(1411) or ""):find("Durotar") ~= nil)
	local text, page = NS:LoreSubzone(1411, "Tranchecolline")
	S.ok("sous-zone par son nom français", text ~= nil and page == "Razor_Hill", tostring(page))
	NS.loreLang = "en"
	NS:LoreForgetCache()
	S.ok("sous-zone par son nom anglais", select(2, NS:LoreSubzone(1411, "Razor Hill")) == "Razor_Hill")
	S.ok("« The » de tête ignoré (The Den -> den)", select(2, NS:LoreSubzone(1411, "The Den")) == "The_Den")
	S.ok("lieu inconnu : rien", NS:LoreSubzone(1411, "Nulle part") == nil and NS:LoreZone(999999) == nil)
	NS.loreLang = nil
	NS:LoreForgetCache()
	S.ok("normalisation", NS.LoreNormalise("The Crossroads") == "crossroads"
		and NS.LoreNormalise("Zul'Farrak") == "zulfarrak" and NS.LoreNormalise("Lion’s Pride Inn") == "lions pride inn")
	S.done()
end

-- 2. Coupe sûre -------------------------------------------------------------------------
do
	Say("-- histoire des lieux : coupe")
	local S = Scenario("[LORE] coupe")
	local short = "Une phrase courte."
	S.ok("texte court gardé tel quel", NS.LoreFit(short, 100) == short)
	local two = string.rep("Mot ", 20) .. "fin. " .. string.rep("Autre ", 30) .. "fin."
	local cut = NS.LoreFit(two, 120)
	S.ok("coupe à la fin d'une phrase", #cut <= 120 and cut:sub(-4) == "fin.", cut)
	local long = string.rep("élan ", 80)
	local word = NS.LoreFit(long, 100)
	S.ok("sinon coupe au mot, avec « … »", #word <= 100 and word:sub(-3) == "…" and not word:find(" …$")
		and word:sub(-6, -4) ~= "\195", word)
	S.done()
end

-- 3. Une fois par zone, une fois par sous-zone ------------------------------------------
do
	Say("-- histoire des lieux : déclencheurs")
	local S = Scenario("[LORE] arrivée dans une zone : récit différé, noté")
	X.Reset()
	X.Enter(1411, nil, true)
	S.ok("arrivée : récit en attente (après la bulle d'arrivée)", NS:LorePending() ~= nil and #X.timers == 1
		and X.timers[1].delay == NS.LORE_LIMITS.delay)
	X.Run()
	S.ok("zone racontée (réservoir LORE)", NS.companionBubbleKey == "LORE"
		and (NS.companionBubbleText or ""):find("Durotar") ~= nil, NS.companionBubbleText)
	S.ok("notée pour ce personnage", tonumber(NS:CharData().lore.z[1411]) ~= nil)
	X.Free()
	X.Enter(1411, nil, true)
	S.done()
	S = Scenario("[LORE] zone : pas de redite aussitôt, parfois bien plus tard")
	S.ok("retour aussitôt : rien", NS:LorePending() == nil and #X.timers == 0)
	-- bien plus tard, la chance de reparler (forcée)
	NS:CharData().lore.z[1411] = NS:CharData().lore.z[1411] - NS.LORE_LIMITS.revisit - 1
	math.random = function(a) if a then return 1 end return 0 end
	X.Enter(1411, nil, true)
	S.ok("visite bien plus tard : parfois redit", NS:LorePending() ~= nil)
	math.random = function(a) if a then return 1 end return 0.99 end
	NS:LoreReset(); X.timers = {}
	NS:CharData().lore.z[1411] = NS:CharData().lore.z[1411] - NS.LORE_LIMITS.revisit - 1
	X.Enter(1411, nil, true)
	S.ok("… mais rarement", NS:LorePending() == nil)
	math.random = savedRandom
	NS:LoreReset(); X.timers = {}
	-- sous-zone notable
	X.Enter(1411, "Tranchecolline", false)
	S.done()
	S = Scenario("[LORE] sous-zone : une seule fois, abandon si parti")
	S.ok("sous-zone notable : en attente", NS:LorePending() ~= nil)
	X.Run()
	S.ok("sous-zone racontée, nommée (LORE_PLACE)", NS.companionBubbleKey == "LORE_PLACE"
		and (NS.companionBubbleText or ""):find("Tranchecolline") ~= nil, NS.companionBubbleText)
	S.ok("sous-zone notée", NS:CharData().lore.s.Razor_Hill == true)
	X.Enter(1411, "Tranchecolline", false)
	S.ok("sous-zone : une seule fois", NS:LorePending() == nil and #X.timers == 0)
	X.Enter(1411, "Clairière sans nom", false)
	S.ok("sous-zone sans histoire : rien", NS:LorePending() == nil)
	-- parti avant le récit : abandonné, redit à la prochaine entrée
	X.Enter(1411, "L'Antre", false)
	Mock.world.subzone = "Ailleurs"
	X.Run()
	S.ok("parti avant le récit : rien de dit ni de noté", NS.companionBubbleKey ~= "LORE_PLACE"
		and not NS:CharData().lore.s.The_Den and NS:LorePending() == nil)
	X.Done()
	S.done()
end

-- 4. Silences : combat, réglage, cran, Spoken ------------------------------------------
do
	Say("-- histoire des lieux : silences")
	local S = Scenario("[LORE] silences")
	X.Reset()
	X.combat = true
	X.Enter(1412, nil, true)
	X.Run()
	S.ok("en combat : rien de dit, on attend", NS.companionBubbleKey ~= "LORE" and NS:LorePending() ~= nil
		and #X.timers == 1 and not NS:CharData().lore.z[1412])
	X.combat = false
	NS.companionFighting = nil
	X.Run()
	S.ok("après le combat : raconté", NS.companionBubbleKey == "LORE" and NS:CharData().lore.z[1412] ~= nil)

	X.Reset()
	NS:DB().companionLore = false
	X.Enter(1411, "Tranchecolline", true)
	S.ok("réglage coupé : rien", NS:LorePending() == nil and #X.timers == 0)
	NS:DB().companionLore = nil

	X.Reset()
	NS:DB().companionChatter = 2
	X.Enter(1411, nil, true)
	X.Run()
	S.ok("cran Calme : rien de dit ni de noté", NS.companionBubbleKey ~= "LORE" and not NS:CharData().lore.z[1411])

	X.Reset()
	X.spoken = true
	S.ok("Spoken Places détecté", NS.LoreSpokenLoaded() == true)
	X.Enter(1411, "Tranchecolline", true)
	S.ok("Spoken Places chargé : silence (il raconte déjà)", NS:LorePending() == nil and #X.timers == 0)

	-- réglage dans la page du compagnon, sous la réglette Bavardage
	local row, after
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if page.id == "companionMain" then
			for index, r in ipairs(page.rows) do
				if r.key == "companionLore" then row, after = r, page.rows[index - 1] end
			end
		end
	end
	S.done()
	S = Scenario("[LORE] réglage : sous Bavardage, activé, textes")
	S.ok("réglage présent, activé par défaut", row ~= nil and row.kind == "bool" and after and after.key == "companionChatter"
		and NS:DB().companionLore ~= false)
	S.ok("textes fr/en du réglage", NS.L.OPT_COMP_LORE ~= nil and NS.L.OPT_COMP_LORE_DESC:find("CC BY%-SA") ~= nil)
	X.Done()
	S.done()
end

-- 5. Au repos ---------------------------------------------------------------------------
do
	Say("-- histoire des lieux : bavardage")
	local S = Scenario("[LORE] bavardage")
	X.Reset()
	Mock.world.mapID, Mock.world.subzone = 1411, "Tranchecolline"
	math.random = function(a) if a then return 1 end return 0 end
	S.ok("avant le délai : rien", NS:CompanionLoreIdle(NS.LORE_LIMITS.idle - 1) == false)
	X.Free()
	S.ok("passé le délai : le lieu raconté", NS:CompanionLoreIdle(1) == true and NS.companionBubbleKey == "LORE_PLACE")
	X.Free()
	X.combat = true
	S.ok("en combat : jamais", NS:CompanionLoreIdle(NS.LORE_LIMITS.idle) == false)
	X.Done()
	S.done()
end

-- 2.13.0 : noms des lieux du client français dans les textes français
do
	local src = io.open((ADDON_ROOT or ".") .. "/QuestCompanion/LoreData.lua"):read("*a")
	local block = src:match("local FR = %[%[(.-)%]%]") or ""
	-- texte seul : la dernière colonne est la page source du wiki (en anglais)
	local parts = {}
	for line in block:gmatch("[^\n]+") do
		-- Z : zone, texte, source ; S : zone, noms du client (gardés pour la recherche), texte, source
		local text = (line:sub(1, 1) == "S" and line:match("^S\t[^\t]+\t[^\t]*\t(.*)\t[^\t]*$"))
			or line:match("^Z\t[^\t]+\t(.*)\t[^\t]*$") or ""
		parts[#parts + 1] = text
	end
	local fr = table.concat(parts, "\n")
	local en_left = {}
	for _, name in ipairs({ "Goldshire", "Northshire", "Stormwind", "Ironforge", "Undercity", "Westfall", "Hillsbrad", "Darkshire" }) do
		if fr:find(name, 1, true) then en_left[#en_left + 1] = name end
	end
	Check("[LORE] texte français : plus de noms anglais des lieux (Comté-de-l'Or, Hurlevent…)", #en_left == 0
		and fr:find("Hurlevent", 1, true) ~= nil and fr:find("de Hautebrande", 1, true) ~= nil, table.concat(en_left, ","))
end
