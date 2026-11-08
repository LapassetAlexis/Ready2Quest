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
end

for k, v in pairs(saved) do _G[k] = v end
