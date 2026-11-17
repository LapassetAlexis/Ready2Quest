-- Compagnon : il crie dans le danger (CompanionShouts.lua, QC 3.2.0) et le nom
-- du monstre sous la marque rouge de Ready2Quest (AggroDangerUnit, 1.37.1).
local Check, Say, ResetWorld, NS, RNS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.NS, T.Mock

local function Fresh()
	ResetWorld()
	for _, frame in ipairs({ NS.companionFrame, NS.companionBubble }) do if frame then frame:Hide() end end
	NS.companionFrame, NS.companionBubble, NS.companionShoutState = nil, nil, nil
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	NS.companionBubbleKey, NS.companionBubbleText, NS.companionRT = nil, nil, nil
	NS:CompanionData().tutoDone = true
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	if NS.companionRT then NS.companionRT.cool, NS.companionRT.seq = {}, nil end
end

-- Ready2Quest simulé : une marque rouge sur `name` (nil : aucune)
local function FakeR2Q(name, withUnit)
	local fake = {}
	if withUnit ~= false then
		fake.AggroDangerUnit = function() if name then return "nameplate1", name end return nil end
	else
		fake.AggroDangerShown = function() return name ~= nil end
	end
	return fake
end

do
	Say("-- compagnon : cris")
	local bad = {}
	local function ok(label, cond, extra) if not cond then bad[#bad + 1] = label .. (extra and (" [" .. tostring(extra) .. "]") or "") end end
	local saved = { Ready2Quest = rawget(_G, "Ready2Quest"), UnitAffectingCombat = rawget(_G, "UnitAffectingCombat"),
		UnitHealth = rawget(_G, "UnitHealth"), UnitHealthMax = rawget(_G, "UnitHealthMax") }
	local savedCount = NS.CompanionAggroCount

	-- réservoirs : fr/en, mêmes « %s » / « %d »
	for pool in pairs(NS.COMPANION_SHOUT_STYLE) do
		ok(pool .. " : au moins 3 répliques", #(NS.COMPANION_POOLS[pool] or {}) >= 3, #(NS.COMPANION_POOLS[pool] or {}))
	end
	ok("réglage par défaut actif, rangé dans Paroles", NS:DB().companionShouts == true
		and NS.COMPANION_OPTION_SPLIT.companionShouts == "companionTalk")
	local talk
	for _, page in ipairs(NS.OPTION_PAGES or {}) do if page.id == "companionTalk" then talk = page end end
	local row
	for _, r in ipairs(talk and talk.rows or {}) do if r.key == "companionShouts" then row = r end end
	ok("ligne « Le compagnon crie » sur la page Paroles", row ~= nil and NS.L[row.label] == "Le compagnon crie")
	-- chaque réplique criée se forme (arguments colorés : « %d » devient « %s »), sans « % » perdu
	local dummy = { SHOUT_AGGRO = { "Loup" }, SHOUT_SWARM = { 4 }, SHOUT_FLEE = { "Kobold" }, SHOUT_SKULL = { "Ogre" },
		SHOUT_DURA = { 7 }, SHOUT_LOOT = { "Épée" }, SHOUT_LOOT_EPIC = { "Épée" }, SHOUT_LEVEL = { 20 } }
	for pool, style in pairs(NS.COMPANION_SHOUT_STYLE) do
		for _, key in ipairs(NS.COMPANION_POOLS[pool] or {}) do
			local text = NS:CompanionShoutText(key, dummy[pool], style)
			local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			if plain:find("%%[sdSD]") or (dummy[pool] and not plain:find(NS.Theme.Upper(tostring(dummy[pool][1])), 1, true)) then
				bad[#bad + 1] = key .. " -> " .. plain
			end
		end
	end

	-- aggro : nom du monstre, en majuscules, accents compris
	Fresh()
	_G.Ready2Quest = FakeR2Q("Sanglier étêté")
	_G.UnitAffectingCombat = function() return false end
	local pool = NS:CompanionShoutTick(100)
	local text = tostring(NS.companionBubbleText)
	local Theme = NS.Theme
	ok("marque rouge : il crie le nom, en accent doré dans une ligne rouge", pool == "SHOUT_AGGRO"
		and text:find(Theme.T_GOLD .. "SANGLIER ÉTÊTÉ|r" .. Theme.T_RED, 1, true) ~= nil and text:sub(1, #Theme.T_RED) == Theme.T_RED
		and text:sub(-2) == "|r", text)
	local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	ok("tout en majuscules, codes couleur intacts (|c minuscule)", plain == Theme.Upper(plain) and not text:find("|C", 1, true), text)
	-- contraste des encres sur la bulle (fond WINDOW à 0,96 sur un monde blanc : le pire cas)
	local bubbleBg = Theme.Over(Theme.WHITE, Theme.WINDOW, 0.96)
	for _, token in ipairs({ "RED", "GOLD", "PARCHMENT" }) do
		local c = Theme.Contrast(Theme[token], bubbleBg)
		ok(token .. " sur la bulle ≥ 4,5", c >= 4.5, string.format("%.2f", c))
	end
	for pool, style in pairs(NS.COMPANION_SHOUT_STYLE) do
		for _, key in ipairs({ "ink", "accent" }) do
			if style[key] and type(Theme[style[key]]) ~= "string" then bad[#bad + 1] = pool .. " " .. key .. " inconnu" end
		end
	end
	NS.companionLastBubble, NS.companionBubbleUntil = nil, nil
	ok("même monstre : pas de second cri tout de suite", NS:CompanionShoutTick(110) == nil)
	-- sans AggroDangerUnit (Ready2Quest plus ancien) : le cri sans nom
	Fresh()
	_G.Ready2Quest = FakeR2Q("Loup", false)
	ok("Ready2Quest sans nom : cri générique", NS:CompanionShoutTick(200) == "SHOUT_AGGRO_ANY")
	Fresh()
	_G.Ready2Quest = nil
	ok("sans Ready2Quest : pas de cri d'aggro", NS:CompanionShoutTick(300) == nil)

	-- combat : plusieurs monstres, une fois par combat
	Fresh()
	_G.UnitAffectingCombat = function() return true end
	NS.CompanionAggroCount = function() return 3 end
	pool = NS:CompanionShoutTick(400)
	ok("3 monstres en combat : il crie leur nombre, en or dans une ligne rouge", pool == "SHOUT_SWARM"
		and tostring(NS.companionBubbleText):find(NS.Theme.T_GOLD .. "3|r" .. NS.Theme.T_RED, 1, true) ~= nil,
		NS.companionBubbleText)
	NS.companionLastBubble, NS.companionBubbleUntil = nil, nil
	ok("une fois par combat", NS:CompanionShoutTick(401) == nil)
	NS.CompanionAggroCount = function() return 2 end
	_G.UnitAffectingCombat = function() return false end
	NS:CompanionShoutTick(402)
	_G.UnitAffectingCombat = function() return true end
	ok("deux monstres : rien", NS:CompanionShoutTick(403) == nil)

	-- vie au plus bas
	Fresh()
	_G.UnitAffectingCombat = function() return true end
	NS.CompanionAggroCount = function() return 0 end
	_G.UnitHealth, _G.UnitHealthMax = function() return 20 end, function() return 100 end
	ok("vie sous 25 % : il crie", NS:CompanionShoutTick(500) == "SHOUT_LOW_HP")
	_G.UnitHealth = function() return 30 end
	Fresh()
	_G.UnitAffectingCombat = function() return true end
	ok("vie à 30 % : rien", NS:CompanionShoutTick(510) == nil)

	-- réglage coupé, muet
	Fresh()
	_G.Ready2Quest = FakeR2Q("Sanglier")
	_G.UnitAffectingCombat = function() return false end
	NS:DB().companionShouts = false
	ok("réglage coupé : rien", NS:CompanionShoutTick(600) == nil)
	NS:DB().companionShouts = true
	NS:DB().companionChatter = 0
	ok("muet : rien", NS:CompanionShoutTick(601) == nil)
	NS:DB().companionChatter = 1
	ok("cran Discret : le cri passe", NS:CompanionShoutTick(602) == "SHOUT_AGGRO")
	NS:DB().companionChatter = 3

	-- fuyard (émote de monstre, en combat seulement)
	Fresh()
	_G.UnitAffectingCombat = function() return true end
	ok("fuyard : il crie son nom", NS:CompanionShoutEmote("%s tente de s'enfuir, terrorisé !", "Kobold") == true
		and tostring(NS.companionBubbleText):find("KOBOLD", 1, true) ~= nil, NS.companionBubbleText)
	Fresh()
	_G.UnitAffectingCombat = function() return false end
	ok("fuyard hors combat, ou autre émote : rien", NS:CompanionShoutEmote("%s runs away in fear!", "Kobold") == false)
	_G.UnitAffectingCombat = function() return true end
	ok("autre émote : rien", NS:CompanionShoutEmote("%s devient enragé !", "Kobold") == false)

	-- noyade et fatigue : jauges du jeu qui se vident
	local savedMirror = { GetMirrorTimerInfo = rawget(_G, "GetMirrorTimerInfo"), GetMirrorTimerProgress = rawget(_G, "GetMirrorTimerProgress") }
	local mirror = {}
	_G.GetMirrorTimerInfo = function(i) local m = mirror[i]; if m then return m[1], m[2], m[2], -1, false, m[1] end return "UNKNOWN", 0, 0, 0 end
	_G.GetMirrorTimerProgress = function(timer) for _, m in pairs(mirror) do if m[1] == timer then return m[3] end end return 0 end
	Fresh()
	_G.UnitAffectingCombat = function() return false end
	_G.Ready2Quest = nil
	mirror[1] = { "BREATH", 60000, 40000 }
	ok("souffle aux 2/3 : rien", NS:CompanionShoutTick(700) == nil)
	mirror[1][3] = 15000
	ok("souffle bas : il crie", NS:CompanionShoutTick(701) == "SHOUT_BREATH")
	NS.companionLastBubble, NS.companionBubbleUntil = nil, nil
	ok("une fois par jauge", NS:CompanionShoutTick(702) == nil)
	mirror[1] = { "EXHAUSTION", 60000, 50000 }
	ok("fatigue : il crie", NS:CompanionShoutTick(703) == "SHOUT_FATIGUE")
	mirror[1] = nil
	for k, v in pairs(savedMirror) do _G[k] = v end

	-- munitions à sec en combat (chasseur qui en avait)
	Fresh()
	local savedClass, savedAmmo = NS.PlayerClassToken, NS.AmmoCount
	local ammo = 12
	NS.PlayerClassToken, NS.AmmoCount = function() return "HUNTER" end, function() return ammo end
	_G.UnitAffectingCombat = function() return true end
	_G.UnitHealth = function() return 80 end
	NS.CompanionAggroCount = function() return 1 end
	NS:CompanionShoutTick(800)
	ammo = 0
	ok("à sec en combat : il crie", NS:CompanionShoutTick(801) == "SHOUT_AMMO")
	NS.PlayerClassToken, NS.AmmoCount = savedClass, savedAmmo

	-- survie de justesse : vie sous 10 % pendant le combat, vivant à la fin
	Fresh()
	_G.UnitAffectingCombat = function() return true end
	_G.UnitHealth = function() return 6 end
	NS:CompanionShoutTick(900)
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	_G.UnitAffectingCombat = function() return false end
	_G.UnitHealth = function() return 6 end
	local close = NS:CompanionShoutTick(901)
	ok("survie de justesse : cri doré", close == "SHOUT_SURVIVED"
		and tostring(NS.companionBubbleText):sub(1, #NS.Theme.T_GOLD) == NS.Theme.T_GOLD, tostring(close))
	_G.UnitHealth = function() return 80 end

	-- longue chute
	Fresh()
	local savedFalling = rawget(_G, "IsFalling")
	_G.IsFalling = function() return true end
	_G.UnitAffectingCombat = function() return false end
	ok("chute courte : rien", NS:CompanionShoutTick(1000) == nil and NS:CompanionShoutTick(1001) == nil)
	ok("chute de 2 s : « AAAAH »", NS:CompanionShoutTick(1002) == "SHOUT_FALL")
	_G.IsFalling = savedFalling

	-- butin : bleu, violet, vert
	Fresh()
	ok("objet bleu : cri avec son nom", NS:CompanionShoutLoot("|cff0070dd|Hitem:1|h[Épée runique]|h|r", 3) == true
		and tostring(NS.companionBubbleText):find("ÉPÉE RUNIQUE", 1, true) ~= nil and NS.companionBubbleKey == "SHOUT_LOOT")
	Fresh()
	ok("objet violet : cri épique", NS:CompanionShoutLoot("|cffa335ee|Hitem:2|h[Hache]|h|r", 4) == true
		and NS.companionBubbleKey == "SHOUT_LOOT_EPIC")
	ok("objet vert : rien", NS:CompanionShoutLoot("|cff1eff00|Hitem:3|h[Bâton]|h|r", 2) == false)

	-- conseils remplacés par un cri (crâne, durabilité critique, niveau), sauf réglage coupé
	ok("remplacements : crâne, durabilité critique, niveau", NS:CompanionShoutPool("ADVICE_SKULL") == "SHOUT_SKULL"
		and NS:CompanionShoutPool("ADVICE_DURA_CRIT") == "SHOUT_DURA" and NS:CompanionShoutPool("LEVEL") == "SHOUT_LEVEL"
		and NS:CompanionShoutPool("ADVICE_BAGS") == nil)
	NS:DB().companionShouts = false
	ok("réglage coupé : plus de remplacement", NS:CompanionShoutPool("LEVEL") == nil)
	NS:DB().companionShouts = true

	for k, v in pairs(saved) do _G[k] = v end
	NS.CompanionAggroCount = savedCount
	Check("[SHOUT] cris du compagnon : aggro (R2Q), nuée, vie basse, fuyard, noyade, fatigue, munitions, survie, chute, butin, remplacements ; réglage, muet", #bad == 0,
		table.concat(bad, " ; "))
end

do
	Say("-- Ready2Quest : monstre sous la marque rouge")
	ResetWorld()
	local savedName, savedOn = rawget(_G, "UnitName"), RNS.AggroOn
	_G.UnitName = function(unit) return unit == "nameplate4" and "Kobold" or nil end
	RNS.AggroOn = function() return true end
	local plate = { namePlateUnitToken = "nameplate4" }
	local ring = { verdict = "red", IsShown = function() return true end }
	local savedRings = RNS.aggroRings
	RNS.aggroRings = { [plate] = ring }
	local unit, name = RNS:AggroDangerUnit()
	ring.verdict = "amber"
	local none = RNS:AggroDangerUnit()
	RNS.aggroRings, RNS.AggroOn, _G.UnitName = savedRings, savedOn, savedName
	Check("[SHOUT] R2Q AggroDangerUnit : jeton et nom sous la marque rouge, rien sinon",
		unit == "nameplate4" and name == "Kobold" and none == nil, tostring(unit) .. " " .. tostring(name))
end
