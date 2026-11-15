-- QuestCompanion 3.0.4 : « QuestCompanion a été bloqué » à chaque sortie de
-- donjon (ADDON_ACTION_FORBIDDEN). Journal de combat fermé (moteur 12.0) :
-- entrer puis sortir d'une instance ne doit jamais appeler RegisterEvent ni
-- UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED"), sur aucun cadre.
local Check, Say, ResetWorld, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local CLEU = "COMBAT_LOG_EVENT_UNFILTERED"

do
	Say("-- action bloquée : sorties de donjon, journal de combat fermé")
	ResetWorld()
	local saved = { C_CombatLog = rawget(_G, "C_CombatLog"), IsInInstance = rawget(_G, "IsInInstance"),
		GetInstanceInfo = rawget(_G, "GetInstanceInfo") }
	_G.C_CombatLog = { IsCombatLogRestricted = function() return true end }
	local inside = false
	_G.IsInInstance = function() return inside, inside and "party" or "none" end
	_G.GetInstanceInfo = function() return "Donjon", inside and "party" or "none" end
	local calls, wrapped = {}, {}
	for _, frame in ipairs(Mock.frames) do
		if type(frame.RegisterEvent) == "function" then
			local reg, unreg = frame.RegisterEvent, frame.UnregisterEvent
			wrapped[#wrapped + 1] = { frame, reg, unreg }
			frame.RegisterEvent = function(self, event, ...)
				if event == CLEU then calls[#calls + 1] = "register" end
				return reg(self, event, ...)
			end
			frame.UnregisterEvent = function(self, event, ...)
				if event == CLEU then calls[#calls + 1] = "unregister" end
				return unreg(self, event, ...)
			end
		end
	end
	local dormant, companionOn = QNS.featsDormant, QNS.CompanionOn
	QNS.featsDormant, QNS.CompanionOn = false, function() return true end
	local boss = 0
	local base = QNS.FeatBossKill
	QNS.FeatBossKill = function(self, ...) boss = boss + 1; return base(self, ...) end
	for _ = 1, 3 do
		inside = true; QNS:FeatJeuZone()
		Mock:Fire("UNIT_DIED", "Creature-0-4170-36-1234-639-0000ABCDEF")
		inside = false; QNS:FeatJeuZone()
	end
	QNS.FeatBossKill = base
	QNS.featsDormant, QNS.CompanionOn = dormant, companionOn
	for _, w in ipairs(wrapped) do w[1].RegisterEvent, w[1].UnregisterEvent = w[2], w[3] end
	for k, v in pairs(saved) do _G[k] = v end
	Check("[BLOQ] trois entrées et sorties de donjon : aucun appel au client sur le journal de combat",
		#calls == 0, table.concat(calls, ","))
	Check("[BLOQ] les morts de boss restent écoutées en instance (UNIT_DIED)", boss == 3, boss)
end
