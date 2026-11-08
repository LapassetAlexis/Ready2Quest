-- QuestCompanion 2.9.0, lot E : recaptures limitées par rareté (CaptureQueue.lua),
-- cadre du compagnon qui clignote en rouge sous plusieurs monstres (CompanionFx.lua).
local Check, Say, ResetWorld, NS = T.Check, T.Say, T.ResetWorld, T.QNS

do
	Say("-- qc29 : recaptures par rareté")
	ResetWorld()
	NS:DB().capture, NS.captureMergedChar = nil, nil
	local data = NS:CaptureData()
	data.creatures[7001] = { name = "Harpie", normal = true, stars = 1, class = "normal" }
	data.creatures[7002] = { name = "Ours élite", normal = true, stars = 1, class = "elite" }
	local common = { npcID = 7001, class = "normal" }
	local elite = { npcID = 7002, class = "elite" }
	Check("[RETRY] commune à 1 étoile : proposée (2 essais par défaut)", NS:CaptureQueueReason(common) == "stars"
		and NS:CaptureRetryLeft(common) == 2)
	local rnd = math.random
	math.random = function(a) if a then return a end return 0.999 end
	NS:CaptureRoll(common); NS:CaptureRoll(common)
	math.random = rnd
	Check("[RETRY] deux essais comptés : la commune n'est plus proposée", data.creatures[7001].retries == 2
		and NS:CaptureQueueReason(common) == nil)
	Check("[RETRY] élite : sans limite par défaut", NS:CaptureRetryLeft(elite) == nil and NS:CaptureQueueReason(elite) == "stars")
	NS:DB().companionRetryElite = 0
	Check("[RETRY] réglé à « jamais » : plus proposée", NS:CaptureQueueReason(elite) == nil)
	NS:DB().companionRetryElite = 5
	Check("[RETRY] une espèce nouvelle reste toujours proposée", NS:CaptureQueueReason({ npcID = 7999, class = "normal" }) == "new")
	local rows = 0
	for _, row in ipairs(NS.DAILY_OPTION_ROWS or {}) do if tostring(row.key):find("^companionRetry") then rows = rows + 1 end end
	Check("[RETRY] trois réglages (communes, élites, rares)", rows == 3)
	NS:DB().capture, NS.captureMergedChar = nil, nil
end

do
	Say("-- qc29 : plusieurs monstres sur toi")
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
