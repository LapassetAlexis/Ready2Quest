-- Ready2Quest 1.30.0 : les quêtes de voyage (« fil d'Ariane », sans objectif)
-- ne comptent plus comme « prêtes à rendre » dans le Check (idée de Lex).
local Check, ResetWorld, NS, Mock, Result = T.Check, T.ResetWorld, T.NS, T.Mock, T.Result

do
	T.Say("-- R2Q : quêtes de voyage")
	ResetWorld()
	local saved = C_QuestLog.GetQuestObjectives
	C_QuestLog.GetQuestObjectives = function(questID)
		if questID == 21 then return {} end
		return { { text = "Loups tués : 10/10", finished = true } }
	end
	Mock.world.quests = { { questID = 21, title = "Va voir Sven", ready = true } }
	NS:RunChecklist("manual")
	local r = Result("quests")
	Check("[TRAVEL] seule une quête de voyage : rien à reprocher, elle est citée", r and r.ok == true
		and r.detail == NS:FP("CHK_QUESTS_TRAVEL", 1), r and r.detail)
	Mock.world.quests = { { questID = 21, title = "Va voir Sven", ready = true }, { questID = 22, title = "Loups", ready = true } }
	NS:RunChecklist("manual")
	r = Result("quests")
	Check("[TRAVEL] une vraie quête prête : comptée seule", r and r.ok == false and r.detail == NS:FP("CHK_QUESTS_DETAIL", 1),
		r and r.detail)
	C_QuestLog.GetQuestObjectives = nil
	Check("[TRAVEL] objectifs illisibles : on ne présume rien", NS.QuestIsTravel(21) == false)
	C_QuestLog.GetQuestObjectives = saved
	Mock.world.quests = {}
end
