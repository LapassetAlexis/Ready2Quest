-- Compagnon : le cadre clignote en rouge sous plusieurs monstres
-- (CompanionFx.lua, QuestCompanion 2.9.0) : un seul ne suffit pas, le réglage
-- coupe tout.
local Check, Say, ResetWorld, NS = T.Check, T.Say, T.ResetWorld, T.QNS

do
	Say("-- compagnon : plusieurs monstres sur toi")
	ResetWorld()
	local saved = { C_NamePlate = rawget(_G, "C_NamePlate"), UnitCanAttack = rawget(_G, "UnitCanAttack"),
		UnitIsUnit = rawget(_G, "UnitIsUnit"), UnitIsDead = rawget(_G, "UnitIsDead") }
	local onMe = {}
	_G.C_NamePlate = { GetNamePlates = function()
		return { { namePlateUnitToken = "nameplate1" }, { namePlateUnitToken = "nameplate2" }, { namePlateUnitToken = "nameplate3" } }
	end }
	_G.UnitCanAttack = function() return true end
	_G.UnitIsDead = function() return false end
	_G.UnitIsUnit = function(a, b) return b == "player" and onMe[a] == true end
	local savedFrame = NS.companionFrame
	NS.companionFrame = CreateFrame("Frame", nil, UIParent)
	NS.companionFrame:Show()
	onMe["nameplate1target"] = true
	Check("[AGGRO2] un seul monstre sur toi : pas de clignotement", NS:CompanionAggroCount() == 1
		and NS:CompanionAggroUpdate(1000) == false)
	onMe["nameplate2target"] = true
	local cnt, shown = NS:CompanionAggroCount(), NS.companionFrame:IsShown()
	Check("[AGGRO2] deux monstres : le cadre clignote en rouge", NS:CompanionAggroUpdate(1001) == true
		and NS.companionFrame.danger and NS.companionFrame.danger:IsShown(), tostring(cnt) .. "/" .. tostring(shown))
	NS:DB().companionAggroBlink = false
	Check("[AGGRO2] réglage coupé : rien", NS:CompanionAggroUpdate(1002) == false and not NS.companionFrame.danger:IsShown())
	NS:DB().companionAggroBlink = true
	NS.companionFrame:Hide()
	NS.companionFrame = savedFrame
	for k, v in pairs(saved) do _G[k] = v end
end
