-- Buffs réclamés avant le départ (Buffs.lua) : genre de chaque buff et défaut
-- (1.32.2 : classe seulement, migration une fois), qui peut te le donner
-- (1.30.0 : lanceur noté, classes du groupe ; 1.31.0 : buffs personnels, sorts
-- non appris), effet, rôle et mana (1.33.3 : de situation, Fureur vertueuse au
-- tank, Intelligence des arcanes aux classes à mana), raisons dans les réglages.
local Check, Say, ResetWorld, NS = T.Check, T.Say, T.ResetWorld, T.NS

local B = { names = { "UnitClass", "IsPlayerSpell", "IsSpellKnown", "GetSpellInfo", "C_Spell", "C_SpecializationInfo",
	"GetTalentTabInfo", "UnitGroupRolesAssigned", "GetNumGroupMembers", "IsInRaid", "LOCALIZED_CLASS_NAMES_MALE" } }
B.saved = {}
for _, name in ipairs(B.names) do B.saved[name] = rawget(_G, name) end
function B.Restore()
	-- pairs saute les nil : une fonction absente au départ doit le redevenir
	for _, name in ipairs(B.names) do _G[name] = B.saved[name] end
end
-- groupe : unité -> classe ; joueur : B.class
B.group, B.class, B.book = {}, "PALADIN", {}
function B.Install()
	_G.UnitClass = function(unit)
		if unit == "player" then return B.class, B.class, 2 end
		local c = B.group[unit]
		if c then return c, c, 1 end
	end
	_G.GetNumGroupMembers = function() local n = 0; for _ in pairs(B.group) do n = n + 1 end; return n > 0 and n + 1 or 0 end
	_G.IsInRaid = function() return false end
	_G.IsPlayerSpell = function() return false end
	_G.IsSpellKnown = function() return false end
	_G.C_Spell = nil
	_G.GetSpellInfo = function(name) if B.book[name] then return name, nil, 1 end return nil end
	_G.C_SpecializationInfo, _G.GetTalentTabInfo, _G.UnitGroupRolesAssigned = nil, nil, nil
end
function B.Missing(keys)
	local missing = {}
	for _, key in ipairs(keys) do
		if type(NS.L[key]) ~= "string" or NS.L[key] == key then missing[#missing + 1] = key end
	end
	return missing
end

-- 1. Genre de buff, défaut, migration (1.32.2) --------------------------------------------
do
	Say("-- buffs : genre, défaut, migration")
	ResetWorld()
	B.group, B.class, B.book = {}, "PALADIN", {}
	B.Install()
	local Kind, E = NS.BuffKind, NS.BuffEnabled
	local bad = {}
	for _, c in ipairs({
		{ "Force", "consumable" }, { "Agility", "consumable" }, { "Esprit", "consumable" }, { "Élixir de la mangouste", "consumable" },
		{ "Fureur vertueuse", "role" }, { "Aura de dévotion", "toggle" }, { "Sceau de piété", "toggle" },
		{ "Aspect du faucon", "toggle" }, { "Forme d'ours", "toggle" }, { "Stealth", "toggle" },
		{ "Bénédiction de puissance", "class" }, { "Mot de pouvoir : Robustesse", "class" }, { "Esprit divin", "class" },
		{ "Feu intérieur", "class" },
		-- 1.33.3 : de situation
		{ "Respiration aquatique", "situational" }, { "Unending Breath", "situational" }, { "Marche sur l'eau", "situational" },
		{ "Prière de protection contre l'ombre", "situational" }, { "Gardien de peur", "situational" },
	}) do
		if Kind(1, { name = c[1] }) ~= c[2] then bad[#bad + 1] = c[1] .. "=" .. tostring(Kind(1, { name = c[1] })) end
	end
	Check("[BUFF] genres : consommables, postures, rôle, classe, de situation", #bad == 0, table.concat(bad, ", "))
	Check("[BUFF] posé par soi sans connaître le sort : objet", Kind(7, { name = "Peau de pierre", self = true }) == "consumable"
		and Kind(7, { name = "Peau de pierre" }) == "other")
	Check("[BUFF] de situation : pas réclamé par défaut, sauf si le joueur l'active", not E({ name = "Respiration aquatique" }, 1)
		and E({ name = "Respiration aquatique", userSet = true, enabled = true }, 1))

	local db = NS:DB()
	db.buffsSchema = nil
	db.buffs = {
		[101] = { name = "Force", enabled = true, learned = true, chars = { [NS:CharKey()] = true } },
		[102] = { name = "Fureur vertueuse", enabled = true, learned = true },
		[103] = { name = "Bénédiction de puissance", enabled = true, learned = true, self = true },
		[104] = { name = "Mot de pouvoir : Robustesse", enabled = false, learned = true },
		[105] = { name = "Agilité", enabled = false, learned = true },
	}
	Check("[BUFF] migration : faite une fois", NS:MigrateBuffs(db) == true and db.buffsSchema == 2 and NS:MigrateBuffs(db) == false)
	Check("[BUFF] migration : « coupé » reste un choix du joueur", db.buffs[104].userSet == true and db.buffs[105].userSet == true
		and db.buffs[101].userSet == nil and db.buffs[101].enabled == nil)
	Check("[BUFF] par défaut : seule la bénédiction est réclamée", not E(db.buffs[101], 101) and not E(db.buffs[102], 102)
		and E(db.buffs[103], 103) and not E(db.buffs[104], 104))
	_G.IsPlayerSpell = function(id) return id == 103 end
	local missing = NS:EvaluateBuffs()
	Check("[BUFF] avant le départ : ni « Force » ni « Fureur vertueuse »", #missing == 1 and missing[1] == "Bénédiction de puissance",
		table.concat(missing, ","))
	local on = NS:BuffToggle(101) == true and db.buffs[101].userSet == true
	missing = NS:EvaluateBuffs()
	Check("[BUFF] activer un consommable à la main : alors il est réclamé", on and #missing == 2, table.concat(missing, ","))
	Check("[BUFF] couper un buff de classe : retenu", NS:BuffToggle(103) == false and not E(db.buffs[103], 103))
	local fury
	for _, item in ipairs(NS.OPTION_LISTS.buffs.items()) do if item.text == "Fureur vertueuse" then fury = item end end
	Check("[BUFF] réglages : raison « buff de tank » (1.33.3)", fury and fury.value:find(NS:F("BUFF_WHY_ROLE", NS.L.BUFF_ROLE_DAMAGER), 1, true) ~= nil,
		fury and fury.value)
	fury.onToggle()
	Check("[BUFF] réglages : bascule retenue", db.buffs[102].userSet == true and E(db.buffs[102], 102))
	-- /r2q buff <n> bascule la fiche enregistrée
	local index
	for i, entry in ipairs(NS:TrackedBuffs()) do if entry.spellId == 104 then index = i end end
	NS:HandleCommand("buff " .. index)
	Check("[BUFF] /r2q buff : fiche enregistrée basculée", db.buffs[104].enabled == true and E(db.buffs[104], 104))
	db.buffs = {}
end

-- 2. Rôle et mana (1.33.3) -----------------------------------------------------------------
do
	Say("-- buffs : rôle et mana")
	ResetWorld()
	B.group, B.class, B.book = {}, "PALADIN", {}
	B.Install()
	_G.IsPlayerSpell = function() return true end
	_G.IsSpellKnown = function() return true end
	local points, groupRole = { 0, 0, 0 }, nil
	-- format classique : nom, icône, points, fichier
	_G.GetTalentTabInfo = function(tab) return "Onglet " .. tab, 1, points[tab], "Tab" .. tab end
	_G.UnitGroupRolesAssigned = function() return groupRole or "NONE" end
	local E = NS.BuffEnabled
	local function Role(p) points = p; NS.buffRoleAt = nil; return (NS:BuffRoleAuto()) end
	NS:DB().buffRole = "auto"
	Check("[BUFF] rôle : sans talents ou Vindicte : dégâts ; Fureur vertueuse pas réclamée hors tank",
		Role({ 0, 0, 0 }) == "DAMAGER" and Role({ 5, 0, 21 }) == "DAMAGER" and not E({ name = "Fureur vertueuse" }, 2))
	Check("[BUFF] rôle : Protection : tank, Fureur vertueuse réclamée ; Sacré : soigneur", Role({ 0, 25, 5 }) == "TANK"
		and E({ name = "Fureur vertueuse" }, 2) and Role({ 30, 0, 0 }) == "HEALER")
	groupRole = "TANK"
	Check("[BUFF] le rôle de groupe passe avant les talents", (NS:BuffRoleAuto()) == "TANK")
	groupRole = nil
	-- format récent : id, nom, description, icône, points
	_G.GetTalentTabInfo = function(tab) return 100 + tab, "Onglet", "", 1, ({ 0, 31, 0 })[tab] end
	Check("[BUFF] talents au format récent", (NS:BuffRoleAuto()) == "TANK")
	-- Forever : une seule spé par classe (« Paladin », DAMAGER) : ignorée
	_G.GetTalentTabInfo = nil
	_G.C_SpecializationInfo = { GetSpecialization = function() return 1 end,
		GetSpecializationInfo = function() return 1486, "Paladin", "", 626003, "DAMAGER", 4 end,
		GetNumSpecializationsForClassID = function() return 1 end }
	NS:BuffSetRole("auto")
	local single = (NS:BuffRoleAuto()) == "DAMAGER"
	-- client à plusieurs spés : le rôle de la spé active
	_G.C_SpecializationInfo.GetNumSpecializationsForClassID = function() return 3 end
	_G.C_SpecializationInfo.GetSpecializationInfo = function() return 66, "Protection", "", 1, "TANK", 2 end
	Check("[BUFF] Forever : spé unique ignorée ; client à plusieurs spés : rôle de la spé", single
		and (NS:BuffRoleAuto()) == "TANK")
	_G.C_SpecializationInfo = nil
	_G.GetTalentTabInfo = function() error("pas de talents") end
	Check("[BUFF] talents illisibles : dégâts, sans erreur", (NS:BuffRoleAuto()) == "DAMAGER")
	NS:BuffSetRole("TANK")
	local forced = NS:DB().buffRole == "TANK" and (NS:BuffRole()) == "TANK" and E({ name = "Fureur vertueuse" }, 2)
	NS:BuffSetRole("n'importe quoi")
	Check("[BUFF] rôle forcé dans les réglages ; valeur inconnue : automatique", forced and NS:DB().buffRole == "auto")
	local choices = NS:BuffRoleChoices()
	Check("[BUFF] choix : automatique (déduit), tank, soigneur, dégâts", #choices == 4
		and choices[1].label == NS:F("BUFF_ROLE_AUTO_IS", NS.L.BUFF_ROLE_DAMAGER), choices[1] and choices[1].label)

	-- mana : Intelligence des arcanes pas réclamée à un guerrier
	local arcane = { name = "Intelligence des arcanes", self = false }
	B.class = "WARRIOR"
	local ok, why = NS:BuffAvailability(3, arcane, { MAGE = true, WARRIOR = true }, true, { MAGE = true })
	local fortitude = NS:BuffAvailability(4, { name = "Mot de pouvoir : Robustesse" }, { PRIEST = true, WARRIOR = true }, true, { PRIEST = true })
	Check("[BUFF] guerrier : pas d'Intelligence des arcanes (mana), Robustesse toujours", ok == false and why == "mana"
		and fortitude == true, why)
	B.class = "PALADIN"
	ok, why = NS:BuffAvailability(3, arcane, { MAGE = true, PALADIN = true }, true, { MAGE = true })
	Check("[BUFF] paladin avec un mage : Intelligence des arcanes réclamée", ok == true, why)

	-- de bout en bout : un chaman solo avec Respiration aquatique apprise
	B.class = "SHAMAN"
	local db = NS:DB()
	db.buffsSchema, db.buffs = 2, { [131] = { name = "Respiration aquatique", learned = true, self = true } }
	local missing = NS:EvaluateBuffs()
	local items = NS.OPTION_LISTS.buffs.items()
	Check("[BUFF] chaman solo : pas de Respiration aquatique, raison « de situation »", #missing == 0 and items[1]
		and items[1].value:find(NS.L.BUFF_WHY_OPTIN_SITUATIONAL, 1, true) ~= nil, table.concat(missing, ","))
	local found = false
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if page.id == "buffs" then
			for _, row in ipairs(page.rows or {}) do if row.key == "buffRole" then found = true end end
		end
	end
	Check("[BUFF] page des buffs : réglage « Ton rôle »", found)
	db.buffs, db.buffRole = {}, "auto"
	NS.buffRoleAt = nil
end

-- 3. Qui peut te le donner (1.30.0, 1.31.0) -------------------------------------------------
do
	Say("-- buffs : lanceur, groupe, buffs personnels")
	ResetWorld()
	B.group, B.class, B.book = {}, "PALADIN", {}
	B.Install()
	-- grimoire du harnais d'abord (sort connu par son nom) ; le nôtre en 1.31.0
	_G.C_Spell, _G.GetSpellInfo = B.saved.C_Spell, B.saved.GetSpellInfo
	-- appris d'un guerrier en groupe : sa classe est notée
	local shout = { name = "Cri de guerre", duration = 120 }
	NS.BuffNoteCaster(shout, { sourceUnit = "party1" })
	B.group.party1 = "WARRIOR"
	NS.BuffNoteCaster(shout, { sourceUnit = "party1" })
	local mine = { name = "Bénédiction de puissance", duration = 600 }
	NS.BuffNoteCaster(mine, { sourceUnit = "player" })
	Check("[BUFF] lanceur noté : sa classe ; posé par toi : à toi", shout.casterClass == "WARRIOR" and not shout.self
		and mine.self == true)
	B.group = {}
	local classes, grouped = NS:BuffGroupClasses()
	Check("[BUFF] seul (paladin) : pas de cri de guerre, sa bénédiction oui", not NS:BuffAvailable(6673, shout, classes, grouped)
		and NS:BuffAvailable(19740, mine, classes, grouped))
	B.group.party1 = "WARRIOR"
	classes, grouped = NS:BuffGroupClasses()
	Check("[BUFF] un guerrier dans le groupe : cri de guerre réclamé", NS:BuffAvailable(6673, shout, classes, grouped) and grouped == true)
	B.group = {}
	classes, grouped = NS:BuffGroupClasses()
	local unknown = not NS:BuffAvailable(1, { name = "X" }, classes, grouped)
	_G.IsPlayerSpell = function(id) return id == 1 end
	Check("[BUFF] appris avant 1.30.0 (lanceur inconnu) : pas réclamé, sauf si tu connais le sort", unknown
		and NS:BuffAvailable(1, { name = "X" }, classes, grouped))
	_G.IsPlayerSpell = function() return false end
	-- 1.30.1 : table des buffs de classe, et buffs hors classe propres au personnage
	Check("[BUFF] table : classe de chaque buff", NS.BuffClass("bénédiction de puissance") == "PALADIN"
		and NS.BuffClass(NS.BuffFamily("Mot de pouvoir : Robustesse")) == "PRIEST"
		and NS.BuffClass(NS.BuffFamily("Gift of the Wild")) == "DRUID" and NS.BuffClass("cri de guerre") == "WARRIOR"
		and NS.BuffClass("aspect du faucon") == "HUNTER" and NS.BuffClass("élixir de la mangouste") == nil)
	local blessing = { name = "Bénédiction de puissance", self = true }   -- appris sur le paladin
	B.class = "WARRIOR"
	classes, grouped = NS:BuffGroupClasses()
	local alone = not NS:BuffAvailable(19740, blessing, classes, grouped)
	B.group.party1 = "PALADIN"
	classes, grouped = NS:BuffGroupClasses()
	Check("[BUFF] autre personnage (guerrier) : bénédiction réclamée seulement avec un paladin", alone
		and NS:BuffAvailable(19740, blessing, classes, grouped))
	B.group = {}
	classes, grouped = NS:BuffGroupClasses()
	local elixir = { name = "Élixir de la mangouste", chars = { ["Autre-Royaume"] = true } }
	local other = not NS:BuffAvailable(17538, elixir, classes, grouped)
	NS.BuffNoteCaster(elixir, { sourceUnit = "player" })
	Check("[BUFF] élixir eu sur un autre personnage : pas réclamé ici ; eu ici : réclamé", other
		and NS:BuffAvailable(17538, elixir, classes, grouped))

	-- 1.31.0 : buffs personnels de classe et sorts non appris
	_G.C_Spell = nil
	_G.GetSpellInfo = function(name) if B.book[name] then return name, nil, 1 end return nil end
	local function Avail(id, entry)
		local c, g, o = NS:BuffGroupClasses()
		return NS:BuffAvailability(id, entry, c, g, o)
	end
	B.class, B.group = "WARRIOR", { party1 = "PRIEST", party2 = "PALADIN" }
	local ok, why = Avail(588, { name = "Feu intérieur", self = true })
	local _, _, others = NS:BuffGroupClasses()
	Check("[BUFF] guerrier groupé avec un prêtre : pas de Feu intérieur (personnel), Robustesse oui", ok == false and why == "self"
		and (Avail(1243, { name = "Mot de pouvoir : Robustesse" })) == true, why)
	Check("[BUFF] classes des autres membres, sans toi", others.PRIEST and others.PALADIN and not others.WARRIOR)

	local unlearned = {}
	local function Learn(class, id, name)
		B.class, B.group = class, {}
		local okBefore, whyBefore = Avail(id, { name = name, self = true })
		B.book[name] = true
		if okBefore ~= false or whyBefore ~= "unknown" or (Avail(id, { name = name, self = true })) ~= true then
			unlearned[#unlearned + 1] = name .. ":" .. tostring(whyBefore)
		end
	end
	Learn("MAGE", 168, "Armure de givre")
	Learn("DRUID", 16864, "Augure de clarté")
	Check("[BUFF] sort absent du grimoire (Armure de givre, talent Augure de clarté) : non appris, puis réclamé une fois connu",
		#unlearned == 0, table.concat(unlearned, ", "))
	Check("[BUFF] buff personnel, clé avec accent", NS.BuffSelfOnly("augure de clarté") == true
		and NS.BuffSelfOnly(NS.BuffFamily("Feu intérieur")) == true and NS.BuffSelfOnly("aspect du faucon") == true
		and NS.BuffSelfOnly("mot de pouvoir : robustesse") == false)

	B.class = "PRIEST"
	local spirit = { name = "Esprit divin" }
	B.group = { party1 = "PRIEST" }
	local fromOther = (Avail(14752, spirit)) == true
	B.group = {}
	ok, why = Avail(14752, spirit)
	Check("[BUFF] prêtre sans Esprit divin : réclamé si un autre prêtre est là, sinon non appris", fromOther and ok == false
		and why == "unknown", why)
	-- version de groupe apprise, version simple connue : cherchée par la famille
	B.book["mot de pouvoir : robustesse"] = true
	Check("[BUFF] Prière de robustesse apprise, Robustesse connue : réclamé",
		(Avail(21562, { name = "Prière de robustesse" })) == true)

	B.class = "PALADIN"
	ok, why = Avail(6673, { name = "Cri de guerre", casterClass = "WARRIOR" })
	local ok2, why2 = Avail(17538, { name = "Élixir de la mangouste", chars = { ["Autre-Royaume"] = true } })
	Check("[BUFF] raisons : « class » (paladin seul, Cri de guerre), « other » (élixir d'un autre personnage)", ok == false
		and why == "class" and ok2 == false and why2 == "other", tostring(why) .. " " .. tostring(why2))

	-- liste des réglages : chaque buff dit pourquoi
	B.class, B.group = "WARRIOR", { party1 = "PRIEST" }
	NS:DB().buffs = { [588] = { name = "Feu intérieur", self = true, enabled = true },
		[1243] = { name = "Mot de pouvoir : Robustesse", enabled = true },
		[6673] = { name = "Cri de guerre", enabled = true } }
	B.book["Cri de guerre"] = true
	local values = {}
	for _, item in ipairs(NS.OPTION_LISTS.buffs.items()) do values[item.text] = item.value end
	Check("[BUFF] réglages : Feu intérieur « buff personnel de prêtre », Robustesse et Cri de guerre « réclamé ici »",
		tostring(values["Feu intérieur"]):find("pas ici : buff personnel de prêtre", 1, true) ~= nil
		and tostring(values["Mot de pouvoir : Robustesse"]):find("OUI", 1, true) ~= nil
		and tostring(values["Mot de pouvoir : Robustesse"]):find("réclamé ici", 1, true) ~= nil
		and tostring(values["Cri de guerre"]):find("réclamé ici", 1, true) ~= nil, values["Feu intérieur"])
	B.group, B.class = {}, "PALADIN"
	values = {}
	for _, item in ipairs(NS.OPTION_LISTS.buffs.items()) do values[item.text] = item.value end
	Check("[BUFF] réglages : aucun guerrier dans le groupe", tostring(values["Cri de guerre"]):find("aucun guerrier dans le groupe", 1, true) ~= nil,
		values["Cri de guerre"])
	-- nom de classe : celui du client s'il existe, en minuscule en français
	_G.LOCALIZED_CLASS_NAMES_MALE = { PRIEST = "Prêtre" }
	Check("[BUFF] nom de classe du client", NS:ClassName("PRIEST") == "prêtre" and NS:ClassName("MAGE") == "mage")
	_G.LOCALIZED_CLASS_NAMES_MALE = nil
	-- couleur de la raison : contraste mesuré sur la carte la plus claire
	local function Lum(c)
		local t = {}
		for i = 1, 3 do local v = c[i]; t[i] = v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
		return 0.2126 * t[1] + 0.7152 * t[2] + 0.0722 * t[3]
	end
	local ratio = (Lum(NS.BUFF_WHY_COLOR) + 0.05) / (Lum(NS.Theme.ROW_ALT) + 0.05)
	Check("[BUFF] raison lisible (≥ 4,5:1 sur ROW_ALT)", ratio >= 4.5, ratio)
	NS:DB().buffs = {}
end

-- 4. Chaînes ------------------------------------------------------------------------------
do
	local missing = B.Missing({ "BUFF_WHY_OPTIN_CONSUMABLE", "BUFF_WHY_OPTIN_TOGGLE", "BUFF_WHY_OPTIN_OTHER",
		"BUFF_WHY_OPTIN_SITUATIONAL", "BUFF_WHY_ROLE", "BUFF_WHY_MANA", "OPT_BUFF_ROLE", "BUFF_ROLE_AUTO", "BUFF_ROLE_AUTO_IS",
		"BUFF_ROLE_TANK", "BUFF_ROLE_HEALER", "BUFF_ROLE_DAMAGER", "BUFF_WHY_HERE", "BUFF_WHY_SELF", "BUFF_WHY_CLASS",
		"BUFF_WHY_UNKNOWN", "BUFF_WHY_OTHER", "DIAG_TIP_MISSING", "CLASS_PRIEST", "CLASS_WARLOCK" })
	Check("[BUFF] chaînes des raisons et des rôles", #missing == 0, table.concat(missing, ","))
end

B.Restore()
