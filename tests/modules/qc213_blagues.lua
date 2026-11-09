-- QC 2.13.0 : le compagnon raconte des blagues (CompanionJokes.lua).
-- Réservoirs JOKE et JOKE_V_<type>, une part des bavardages au repos, la
-- commande /qc blague (même au cran Discret, jamais en combat), le réglage.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

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
	local fr, en, POOLS = NS.COMPANION_LINE_STRINGS.fr, NS.COMPANION_LINE_STRINGS.en, NS.COMPANION_POOLS
	Check("[BLAGUE] réservoir commun : au moins 30 blagues", #(POOLS.JOKE or {}) >= 30, tostring(#(POOLS.JOKE or {})))
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
	Check("[BLAGUE] 9 voix, au moins 6 blagues chacune", #short == 0, table.concat(short, ", "))
	Check("[BLAGUE] aucune blague vide, identique fr/en ou à balise", #odd == 0, table.concat(odd, ", "))
	Check("[BLAGUE] assez courtes pour la bulle (200 octets)", #long == 0, table.concat(long, ", "))
	Check("[BLAGUE] la voix des blagues est branchée", NS.COMPANION_VOICE_OF.JOKE == "JOKE")
	Check("[BLAGUE] réglage activé par défaut", NS:DB().companionJokes ~= false)
	local row = false
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		for index, r in ipairs(page.rows or {}) do
			if r.key == "companionJokes" then row = page.rows[index - 1] and page.rows[index - 1].key or true end
		end
	end
	Check("[BLAGUE] réglage sous l'histoire des lieux", row == "companionLore", tostring(row))
	local help = false
	for _, section in ipairs(NS.HELP) do for _, key in ipairs(section[2]) do if key == "HELP_JOKE" then help = true end end end
	Check("[BLAGUE] /qc blague dans l'aide", help and NS.L.HELP_JOKE:find("/qc blague", 1, true) ~= nil)
	Check("[BLAGUE] /qc blague et /qc joke enregistrées", type(NS.EXTRA_COMMANDS.blague) == "function"
		and NS.EXTRA_COMMANDS.joke == NS.EXTRA_COMMANDS.blague)
end

-- 2. Les voix -----------------------------------------------------------------------------------
do
	Say("-- 2.13.0 : blagues, les voix")
	local bad = {}
	for _, pair in ipairs({ { "Mort-vivant", "undead" }, { "Mechanical", "mechanical" }, { "Bestiole", "critter" },
		{ "Démon", "demon" }, { "Dragonkin", "dragonkin" } }) do
		B.Reset(pair[1])
		NS.COMPANION_VOICE_SHARE = 1
		if not Is(NS:CompanionVoicePick("JOKE"), "COMP_SAY_JOKE_V_" .. pair[2]) then bad[#bad + 1] = pair[2] end
	end
	Check("[BLAGUE] chaque type a sa voix de blagues", #bad == 0, table.concat(bad, ", "))
	B.Reset(nil)
	NS.COMPANION_VOICE_SHARE = 1
	Check("[BLAGUE] mascotte : blague commune", Is(NS:CompanionVoicePick("JOKE"), "COMP_SAY_JOKE"))
	B.Done()
end

-- 3. Au repos : une part des bavardages ---------------------------------------------------------
do
	Say("-- 2.13.0 : blagues, au repos")
	B.Reset(nil)
	local jokes, idles = 0, 0
	for _ = 1, 400 do
		B.Free()
		if NS:CompanionTryIdle(100000) then
			if NS.companionBubbleKey == "JOKE" then jokes = jokes + 1 elseif NS.companionBubbleKey == "IDLE" then idles = idles + 1 end
		end
	end
	local share = jokes / math.max(1, jokes + idles)
	Check("[BLAGUE] au repos : environ un bavardage sur quatre", jokes + idles >= 390 and share > 0.17 and share < 0.33,
		jokes .. " / " .. idles)
	NS:DB().companionJokes = false
	jokes = 0
	for _ = 1, 100 do
		B.Free()
		if NS:CompanionTryIdle(100000) and NS.companionBubbleKey == "JOKE" then jokes = jokes + 1 end
	end
	Check("[BLAGUE] réglage coupé : plus de blague spontanée", jokes == 0, tostring(jokes))
	NS:DB().companionJokes = nil
	NS.COMPANION_JOKE_SHARE = 1
	NS:DB().companionChatter = 2
	B.Free()
	Check("[BLAGUE] cran Calme : pas de blague spontanée", not NS:CompanionTryIdle(100000) and NS.companionBubbleKey == nil)
	NS:DB().companionChatter = 3
	B.Free()
	B.combat = true
	Check("[BLAGUE] jamais en combat (bavardages)", not NS:CompanionSay("JOKE", { cd = "idle" }) and NS.companionBubbleKey == nil)
	B.Done()
end

-- 4. /qc blague ---------------------------------------------------------------------------------
do
	Say("-- 2.13.0 : /qc blague")
	B.Reset(nil)
	NS:DB().companionChatter = 0
	NS:DB().companionJokes = false
	Mock.output = {}
	Check("[BLAGUE] /qc blague : une blague, même muet et réglage coupé",
		NS.EXTRA_COMMANDS.blague(NS, "") == true and NS.companionBubbleKey == "JOKE" and #Mock.output == 0)
	-- une autre bulle affichée : la demande passe quand même (écart forcé)
	B.Free()
	NS:DB().companionChatter = 3
	NS:CompanionSay("IDLE", {})
	Check("[BLAGUE] /qc joke passe après un bavardage", NS.EXTRA_COMMANDS.joke(NS, "") == true and NS.companionBubbleKey == "JOKE")
	B.Free()
	B.combat = true
	Mock.output = {}
	local note = NS.companionRT and NS.companionRT.combat
	Check("[BLAGUE] en combat : refusée, et on le dit",
		NS.EXTRA_COMMANDS.blague(NS, "") == false and NS.companionBubbleKey == nil and Logged(NS.L.JOKE_MSG_COMBAT))
	Check("[BLAGUE] en combat : rien de noté pour le résumé", (NS.companionRT and NS.companionRT.combat) == note)
	B.combat = false
	NS:DB().companionShow = false
	Mock.output = {}
	Check("[BLAGUE] compagnon caché : on le dit", NS.EXTRA_COMMANDS.blague(NS, "") == false and Logged(NS.L.JOKE_MSG_OFF))
	B.Done()
end
