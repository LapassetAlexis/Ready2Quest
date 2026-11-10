-- Ready2Quest 1.33.3 : l'effet du buff, le rôle et le mana décident s'il est
-- réclamé avant le départ (Respiration aquatique réclamée à tout le monde,
-- Fureur vertueuse à un paladin solo pas tank).
local Check, ResetWorld, NS = T.Check, T.ResetWorld, T.NS

local saved = { C_SpecializationInfo = rawget(_G, "C_SpecializationInfo"), UnitClass = rawget(_G, "UnitClass"), IsPlayerSpell = rawget(_G, "IsPlayerSpell"),
	IsSpellKnown = rawget(_G, "IsSpellKnown"), GetTalentTabInfo = rawget(_G, "GetTalentTabInfo"),
	UnitGroupRolesAssigned = rawget(_G, "UnitGroupRolesAssigned"), C_Spell = rawget(_G, "C_Spell"),
	GetSpellInfo = rawget(_G, "GetSpellInfo") }
local class, points, groupRole = "PALADIN", { 0, 0, 0 }, nil
_G.UnitClass = function(unit) if unit == "player" then return class, class, 2 end end
_G.C_SpecializationInfo = nil
_G.IsPlayerSpell = function() return true end
_G.IsSpellKnown = function() return true end
_G.C_Spell = nil
_G.GetSpellInfo = function() return nil end
-- format classique : nom, icône, points, fichier
_G.GetTalentTabInfo = function(tab) return "Onglet " .. tab, 1, points[tab], "Tab" .. tab end
_G.UnitGroupRolesAssigned = function() return groupRole or "NONE" end

do
	T.Say("-- R2Q 1.33.3 : buffs selon l'effet, le rôle et le mana")
	ResetWorld()
	local Kind, E = NS.BuffKind, NS.BuffEnabled
	Check("[1333B] de situation : respiration, marche sur l'eau, résistances, peur", Kind(1, { name = "Respiration aquatique" }) == "situational"
		and Kind(1, { name = "Unending Breath" }) == "situational" and Kind(1, { name = "Marche sur l'eau" }) == "situational"
		and Kind(1, { name = "Prière de protection contre l'ombre" }) == "situational" and Kind(1, { name = "Gardien de peur" }) == "situational")
	Check("[1333B] Robustesse reste un buff de classe", Kind(1, { name = "Mot de pouvoir : Robustesse" }) == "class")
	Check("[1333B] de situation : pas réclamé par défaut", not E({ name = "Respiration aquatique" }, 1))
	Check("[1333B] … sauf si le joueur l'active", E({ name = "Respiration aquatique", userSet = true, enabled = true }, 1))

	-- rôle : sans talents, dégâts ; Protection la plus remplie : tank
	NS:DB().buffRole = "auto"
	NS.buffRoleAt = nil
	Check("[1333B] rôle sans talents : dégâts", (NS:BuffRoleAuto()) == "DAMAGER")
	points = { 5, 0, 21 }
	Check("[1333B] paladin Vindicte : dégâts", (NS:BuffRoleAuto()) == "DAMAGER")
	Check("[1333B] Fureur vertueuse pas réclamée hors tank", not E({ name = "Fureur vertueuse" }, 2))
	points = { 0, 25, 5 }
	NS.buffRoleAt = nil
	Check("[1333B] paladin Protection : tank", (NS:BuffRoleAuto()) == "TANK")
	Check("[1333B] Fureur vertueuse réclamée au tank", E({ name = "Fureur vertueuse" }, 2))
	points = { 30, 0, 0 }
	NS.buffRoleAt = nil
	Check("[1333B] paladin Sacré : soigneur", (NS:BuffRoleAuto()) == "HEALER")
	groupRole = "TANK"
	Check("[1333B] le rôle de groupe passe avant les talents", (NS:BuffRoleAuto()) == "TANK")
	groupRole = nil
	-- format récent : id, nom, description, icône, points
	_G.GetTalentTabInfo = function(tab) return 100 + tab, "Onglet", "", 1, ({ 0, 31, 0 })[tab] end
	Check("[1333B] talents au format récent", (NS:BuffRoleAuto()) == "TANK")
	-- Forever : une seule spé par classe (« Paladin », DAMAGER) : ignorée
	_G.GetTalentTabInfo = nil
	_G.C_SpecializationInfo = { GetSpecialization = function() return 1 end,
		GetSpecializationInfo = function() return 1486, "Paladin", "", 626003, "DAMAGER", 4 end,
		GetNumSpecializationsForClassID = function() return 1 end }
	groupRole = nil
	NS:BuffSetRole("auto")
	Check("[1333B] Forever : spé unique ignorée, rôle de groupe absent : dégâts", (NS:BuffRoleAuto()) == "DAMAGER")
	-- client à plusieurs spés : le rôle de la spé active
	_G.C_SpecializationInfo.GetNumSpecializationsForClassID = function() return 3 end
	_G.C_SpecializationInfo.GetSpecializationInfo = function() return 66, "Protection", "", 1, "TANK", 2 end
	Check("[1333B] client à plusieurs spés : rôle de la spé", (NS:BuffRoleAuto()) == "TANK")
	_G.C_SpecializationInfo = nil
	_G.GetTalentTabInfo = function() error("pas de talents") end
	Check("[1333B] talents illisibles : dégâts, sans erreur", (NS:BuffRoleAuto()) == "DAMAGER")
	-- rôle forcé dans les réglages
	NS:BuffSetRole("TANK")
	Check("[1333B] rôle forcé : tank", NS:DB().buffRole == "TANK" and (NS:BuffRole()) == "TANK"
		and E({ name = "Fureur vertueuse" }, 2))
	NS:BuffSetRole("n'importe quoi")
	Check("[1333B] valeur inconnue : automatique", NS:DB().buffRole == "auto")
	local choices = NS:BuffRoleChoices()
	Check("[1333B] choix : automatique (déduit), tank, soigneur, dégâts", #choices == 4
		and choices[1].label == NS:F("BUFF_ROLE_AUTO_IS", NS.L.BUFF_ROLE_DAMAGER), choices[1] and choices[1].label)

	-- mana : Intelligence des arcanes pas réclamée à un guerrier
	local arcane = { name = "Intelligence des arcanes", self = false }
	class = "WARRIOR"
	local ok, why = NS:BuffAvailability(3, arcane, { MAGE = true, WARRIOR = true }, true, { MAGE = true })
	Check("[1333B] guerrier : pas d'Intelligence des arcanes", ok == false and why == "mana", why)
	class = "PALADIN"
	ok, why = NS:BuffAvailability(3, arcane, { MAGE = true, PALADIN = true }, true, { MAGE = true })
	Check("[1333B] paladin avec un mage : réclamée", ok == true, why)
	ok = NS:BuffAvailability(4, { name = "Mot de pouvoir : Robustesse" }, { PRIEST = true, WARRIOR = true }, true, { PRIEST = true })
	Check("[1333B] Robustesse reste réclamée au guerrier", ok == true)

	-- de bout en bout : un chaman solo avec Respiration aquatique apprise
	class = "SHAMAN"
	local db = NS:DB()
	db.buffsSchema, db.buffs = 2, { [131] = { name = "Respiration aquatique", learned = true, self = true } }
	local missing = NS:EvaluateBuffs()
	Check("[1333B] avant le départ : pas de Respiration aquatique", #missing == 0, table.concat(missing, ","))
	local items = NS.OPTION_LISTS.buffs.items()
	Check("[1333B] réglages : raison « de situation »", items[1] and items[1].value:find(NS.L.BUFF_WHY_OPTIN_SITUATIONAL, 1, true) ~= nil,
		items[1] and items[1].value)
	-- page des buffs : la ligne du rôle
	local found = false
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if page.id == "buffs" then
			for _, row in ipairs(page.rows or {}) do if row.key == "buffRole" then found = true end end
		end
	end
	Check("[1333B] page des buffs : réglage « Ton rôle »", found)
	-- chaînes FR / EN
	local absent = {}
	for _, key in ipairs({ "BUFF_WHY_OPTIN_SITUATIONAL", "BUFF_WHY_ROLE", "BUFF_WHY_MANA", "OPT_BUFF_ROLE", "BUFF_ROLE_AUTO",
		"BUFF_ROLE_AUTO_IS", "BUFF_ROLE_TANK", "BUFF_ROLE_HEALER", "BUFF_ROLE_DAMAGER" }) do
		if type(NS.L[key]) ~= "string" or NS.L[key] == key then absent[#absent + 1] = key end
	end
	Check("[1333B] chaînes", #absent == 0, table.concat(absent, ","))
	db.buffs, db.buffRole = {}, "auto"
	NS.buffRoleAt = nil
end

-- pairs saute les nil : une fonction absente au départ doit le redevenir
for _, k in ipairs({ "C_SpecializationInfo", "UnitClass", "IsPlayerSpell", "IsSpellKnown", "GetTalentTabInfo", "UnitGroupRolesAssigned",
	"C_Spell", "GetSpellInfo" }) do _G[k] = saved[k] end
