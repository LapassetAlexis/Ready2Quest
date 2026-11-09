-- Ready2Quest 1.30.0 : un buff n'est réclamé que si toi ou ton groupe pouvez
-- le donner (paladin seul à qui l'on réclamait « Cri de guerre »).
local Check, ResetWorld, NS, Mock = T.Check, T.ResetWorld, T.NS, T.Mock

local saved = { UnitClass = rawget(_G, "UnitClass"), GetNumGroupMembers = rawget(_G, "GetNumGroupMembers"),
	IsInRaid = rawget(_G, "IsInRaid"), IsPlayerSpell = rawget(_G, "IsPlayerSpell"), IsSpellKnown = rawget(_G, "IsSpellKnown") }
local group = {}
_G.UnitClass = function(unit)
	if unit == "player" then return "Paladin", "PALADIN", 2 end
	local c = group[unit]
	if c then return c, c, 1 end
end
_G.GetNumGroupMembers = function() local n = 0; for _ in pairs(group) do n = n + 1 end; return n > 0 and n + 1 or 0 end
_G.IsInRaid = function() return false end
_G.IsPlayerSpell = function() return false end
_G.IsSpellKnown = function() return false end

do
	T.Say("-- R2Q : buffs que l'on peut te donner")
	ResetWorld()
	-- appris d'un guerrier en groupe : sa classe est notée
	local shout = { name = "Cri de guerre", duration = 120 }
	NS.BuffNoteCaster(shout, { sourceUnit = "party1" })
	group.party1 = "WARRIOR"
	NS.BuffNoteCaster(shout, { sourceUnit = "party1" })
	Check("[BUFFC] lanceur noté : sa classe", shout.casterClass == "WARRIOR" and not shout.self)
	local mine = { name = "Bénédiction de puissance", duration = 600 }
	NS.BuffNoteCaster(mine, { sourceUnit = "player" })
	Check("[BUFFC] posé par toi : toujours réclamable", mine.self == true)
	group = {}
	local classes, grouped = NS:BuffGroupClasses()
	Check("[BUFFC] seul (paladin) : pas de cri de guerre réclamé", not NS:BuffAvailable(6673, shout, classes, grouped)
		and NS:BuffAvailable(19740, mine, classes, grouped))
	group.party1 = "WARRIOR"
	classes, grouped = NS:BuffGroupClasses()
	Check("[BUFFC] un guerrier dans le groupe : réclamé", NS:BuffAvailable(6673, shout, classes, grouped) and grouped == true)
	group = {}
	classes, grouped = NS:BuffGroupClasses()
	Check("[BUFFC] appris avant 1.30.0 (lanceur inconnu) : seul, pas réclamé", not NS:BuffAvailable(1, { name = "X" }, classes, grouped))
	_G.IsPlayerSpell = function(id) return id == 1 end
	Check("[BUFFC] … sauf si tu connais le sort", NS:BuffAvailable(1, { name = "X" }, classes, grouped))
	_G.IsPlayerSpell = function() return false end
	-- 1.30.1 : table des buffs de classe, et buffs hors classe propres au personnage
	Check("[BUFFC] table : classe de chaque buff", NS.BuffClass("bénédiction de puissance") == "PALADIN"
		and NS.BuffClass(NS.BuffFamily("Mot de pouvoir : Robustesse")) == "PRIEST"
		and NS.BuffClass(NS.BuffFamily("Gift of the Wild")) == "DRUID" and NS.BuffClass("cri de guerre") == "WARRIOR"
		and NS.BuffClass("aspect du faucon") == "HUNTER" and NS.BuffClass("élixir de la mangouste") == nil)
	local blessing = { name = "Bénédiction de puissance", self = true }   -- appris sur le paladin
	local realClass = _G.UnitClass
	_G.UnitClass = function(unit) if unit == "player" then return "Guerrier", "WARRIOR", 1 end return realClass(unit) end
	classes, grouped = NS:BuffGroupClasses()
	Check("[BUFFC] autre personnage (guerrier seul) : pas de bénédiction réclamée", not NS:BuffAvailable(19740, blessing, classes, grouped))
	group.party1 = "PALADIN"
	classes, grouped = NS:BuffGroupClasses()
	Check("[BUFFC] … un paladin dans le groupe : réclamée", NS:BuffAvailable(19740, blessing, classes, grouped))
	group = {}
	classes, grouped = NS:BuffGroupClasses()
	local elixir = { name = "Élixir de la mangouste", chars = { ["Autre-Royaume"] = true } }
	Check("[BUFFC] élixir eu sur un autre personnage : pas réclamé ici", not NS:BuffAvailable(17538, elixir, classes, grouped))
	NS.BuffNoteCaster(elixir, { sourceUnit = "player" })
	Check("[BUFFC] … eu sur ce personnage : réclamé", NS:BuffAvailable(17538, elixir, classes, grouped))
	_G.UnitClass = realClass
end

-- 1.31.0 : buffs personnels de classe et sorts non appris
do
	T.Say("-- R2Q : buffs personnels et sorts non appris")
	ResetWorld()
	local savedSpell, savedCSpell, realClass = rawget(_G, "GetSpellInfo"), rawget(_G, "C_Spell"), _G.UnitClass
	local playerClass, book = "WARRIOR", {}
	_G.C_Spell = nil
	_G.GetSpellInfo = function(name) if book[name] then return name, nil, 1 end return nil end
	_G.UnitClass = function(unit)
		if unit == "player" then return playerClass, playerClass, 1 end
		local c = group[unit]
		if c then return c, c, 1 end
	end
	local function Avail(id, entry)
		local classes, grouped, others = NS:BuffGroupClasses()
		return NS:BuffAvailability(id, entry, classes, grouped, others)
	end
	local innerFire = { name = "Feu intérieur", self = true }
	local fortitude = { name = "Mot de pouvoir : Robustesse" }
	group = { party1 = "PRIEST", party2 = "PALADIN" }
	local ok, why = Avail(588, innerFire)
	Check("[BUFFC] guerrier groupé avec un prêtre : pas de Feu intérieur (buff personnel)", ok == false and why == "self", why)
	Check("[BUFFC] … mais Robustesse réclamée", (Avail(1243, fortitude)) == true)
	local _, _, others = NS:BuffGroupClasses()
	Check("[BUFFC] classes des autres membres, sans toi", others.PRIEST and others.PALADIN and not others.WARRIOR)

	group, playerClass = {}, "MAGE"
	local frost = { name = "Armure de givre", self = true }
	ok, why = Avail(168, frost)
	Check("[BUFFC] mage seul, sort absent du grimoire : non appris", ok == false and why == "unknown", why)
	book["Armure de givre"] = true
	Check("[BUFFC] mage seul, sort connu : réclamé", (Avail(168, frost)) == true)

	playerClass = "DRUID"
	local omen = { name = "Augure de clarté", self = true }
	ok, why = Avail(16864, omen)
	Check("[BUFFC] druide sans le talent : Augure de clarté pas réclamé", ok == false and why == "unknown", why)
	book["Augure de clarté"] = true
	Check("[BUFFC] druide avec le talent : réclamé", (Avail(16864, omen)) == true)
	Check("[BUFFC] buff personnel, clé avec accent", NS.BuffSelfOnly("augure de clarté") == true
		and NS.BuffSelfOnly(NS.BuffFamily("Feu intérieur")) == true and NS.BuffSelfOnly("aspect du faucon") == true
		and NS.BuffSelfOnly("mot de pouvoir : robustesse") == false)

	playerClass = "PRIEST"
	local spirit = { name = "Esprit divin" }
	group = { party1 = "PRIEST" }
	Check("[BUFFC] prêtre sans Esprit divin, un autre prêtre là : réclamé", (Avail(14752, spirit)) == true)
	group = {}
	ok, why = Avail(14752, spirit)
	Check("[BUFFC] … seul : non appris", ok == false and why == "unknown", why)
	-- version de groupe apprise, version simple connue : cherchée par la famille
	book["mot de pouvoir : robustesse"] = true
	Check("[BUFFC] Prière de robustesse apprise, Robustesse connue : réclamé",
		(Avail(21562, { name = "Prière de robustesse" })) == true)

	playerClass = "PALADIN"
	ok, why = Avail(6673, { name = "Cri de guerre", casterClass = "WARRIOR" })
	Check("[BUFFC] paladin seul : Cri de guerre toujours refusé", ok == false and why == "class", why)
	ok, why = Avail(17538, { name = "Élixir de la mangouste", chars = { ["Autre-Royaume"] = true } })
	Check("[BUFFC] élixir d'un autre personnage : raison « autre personnage »", ok == false and why == "other", why)

	-- liste des réglages : chaque buff dit pourquoi
	playerClass, group = "WARRIOR", { party1 = "PRIEST" }
	NS:DB().buffs = { [588] = { name = "Feu intérieur", self = true, enabled = true },
		[1243] = { name = "Mot de pouvoir : Robustesse", enabled = true },
		[6673] = { name = "Cri de guerre", enabled = true } }
	book["Cri de guerre"] = true
	local values = {}
	for _, item in ipairs(NS.OPTION_LISTS.buffs.items()) do values[item.text] = item.value end
	Check("[BUFFC] réglages : Feu intérieur « buff personnel de prêtre »",
		tostring(values["Feu intérieur"]):find("pas ici : buff personnel de prêtre", 1, true) ~= nil, values["Feu intérieur"])
	Check("[BUFFC] réglages : Robustesse « réclamé ici »", tostring(values["Mot de pouvoir : Robustesse"]):find("OUI", 1, true) ~= nil
		and tostring(values["Mot de pouvoir : Robustesse"]):find("réclamé ici", 1, true) ~= nil, values["Mot de pouvoir : Robustesse"])
	Check("[BUFFC] réglages : Cri de guerre connu du guerrier, réclamé", tostring(values["Cri de guerre"]):find("réclamé ici", 1, true) ~= nil)
	group = {}
	playerClass = "PALADIN"
	values = {}
	for _, item in ipairs(NS.OPTION_LISTS.buffs.items()) do values[item.text] = item.value end
	Check("[BUFFC] réglages : aucun guerrier dans le groupe", tostring(values["Cri de guerre"]):find("aucun guerrier dans le groupe", 1, true) ~= nil,
		values["Cri de guerre"])
	-- nom de classe : celui du client s'il existe, en minuscule en français
	_G.LOCALIZED_CLASS_NAMES_MALE = { PRIEST = "Prêtre" }
	Check("[BUFFC] nom de classe du client", NS:ClassName("PRIEST") == "prêtre" and NS:ClassName("MAGE") == "mage")
	_G.LOCALIZED_CLASS_NAMES_MALE = nil
	-- couleur de la raison : contraste mesuré sur la carte la plus claire
	local function Lum(c)
		local t = {}
		for i = 1, 3 do local v = c[i]; t[i] = v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
		return 0.2126 * t[1] + 0.7152 * t[2] + 0.0722 * t[3]
	end
	local ratio = (Lum(NS.BUFF_WHY_COLOR) + 0.05) / (Lum(NS.Theme.ROW_ALT) + 0.05)
	Check("[BUFFC] raison lisible (≥ 4,5:1 sur ROW_ALT)", ratio >= 4.5, ratio)
	-- chaînes FR / EN
	local missing = {}
	for _, key in ipairs({ "BUFF_WHY_HERE", "BUFF_WHY_SELF", "BUFF_WHY_CLASS", "BUFF_WHY_UNKNOWN", "BUFF_WHY_OTHER",
		"DIAG_TIP_MISSING", "CLASS_PRIEST", "CLASS_WARLOCK" }) do
		if type(NS.L[key]) ~= "string" then missing[#missing + 1] = key end
	end
	Check("[BUFFC] chaînes des raisons", #missing == 0, table.concat(missing, ","))
	_G.GetSpellInfo, _G.C_Spell, _G.UnitClass = savedSpell, savedCSpell, realClass
	group = {}
end

for k, v in pairs(saved) do _G[k] = v end
