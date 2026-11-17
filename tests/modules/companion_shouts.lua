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
	for _, pool in ipairs({ "SHOUT_AGGRO", "SHOUT_AGGRO_ANY", "SHOUT_SWARM", "SHOUT_LOW_HP" }) do
		ok(pool .. " : au moins 3 répliques", #(NS.COMPANION_POOLS[pool] or {}) >= 3, #(NS.COMPANION_POOLS[pool] or {}))
	end
	ok("réglage par défaut actif, rangé dans Paroles", NS:DB().companionShouts == true
		and NS.COMPANION_OPTION_SPLIT.companionShouts == "companionTalk")
	local talk
	for _, page in ipairs(NS.OPTION_PAGES or {}) do if page.id == "companionTalk" then talk = page end end
	local row
	for _, r in ipairs(talk and talk.rows or {}) do if r.key == "companionShouts" then row = r end end
	ok("ligne « Crie dans le danger » sur la page Paroles", row ~= nil and NS.L[row.label] == "Crie dans le danger")

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
	for _, token in ipairs({ "RED", "GOLD" }) do
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

	for k, v in pairs(saved) do _G[k] = v end
	NS.CompanionAggroCount = savedCount
	Check("[SHOUT] cris du compagnon : aggro nommée (R2Q), nuée, vie basse ; une fois ; réglage, muet", #bad == 0,
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
