-- Ready2Quest : « Tout apprendre » chez le maître (TrainAll.lua, 1.35.0). Le
-- bouton et son total, grisé sans assez d'or (l'infobulle dit le manque), la
-- série d'achats un par un après chaque réponse du serveur, l'arrêt sur un
-- refus ou un silence, l'écoute seulement fenêtre ouverte, le réglage.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local GLOBALS = { "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "BuyTrainerService",
	"GetMoney", "ClassTrainerFrame", "ClassTrainerTrainButton" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end
local W
_G.GetNumTrainerServices = function() return #W.services end
_G.GetTrainerServiceInfo = function(i) local s = W.services[i]; return s.name, "Rang 2", s.kind, false end
_G.GetTrainerServiceCost = function(i) return W.services[i].cost, 0, 0 end
_G.GetMoney = function() return W.money end
_G.BuyTrainerService = function(i)
	W.bought[#W.bought + 1] = i
	if W.refuse then return end
	local s = W.services[i]
	s.kind = "used"
	W.money = W.money - s.cost
	if not W.silent then Mock:Fire("TRAINER_UPDATE") end
end
_G.ClassTrainerFrame = CreateFrame("Frame")
_G.ClassTrainerTrainButton = CreateFrame("Button", nil, _G.ClassTrainerFrame)
local function Reset(money)
	ResetWorld()
	W = { money = money or 100000, bought = {}, services = {
		{ name = "Sorts", kind = "header", cost = 0 },
		{ name = "Éclair sacré", kind = "available", cost = 1200 },
		{ name = "Marteau", kind = "unavailable", cost = 5000 },
		{ name = "Sceau", kind = "available", cost = 800 },
		{ name = "Aura", kind = "used", cost = 300 },
	} }
	NS.trainAllRun = nil
	Mock:Fire("TRAINER_CLOSED")
end
local function Printed()
	local lines, old = {}, NS.Print
	NS.Print = function(_, msg) lines[#lines + 1] = tostring(msg) end
	return lines, function() NS.Print = old end
end

do
	Say("-- tout apprendre : le bouton et son total")
	Reset()
	Check("[TRN] fenêtre fermée : les événements du maître ne sont pas écoutés",
		not NS.Listening("TRAINER_UPDATE", "trainAll") and NS.Listening("TRAINER_SHOW", "trainAll"))
	Mock:Fire("TRAINER_SHOW")
	local button = NS.trainAllButton
	local count, total = NS:TrainAllScan()
	Check("[TRN] maître ouvert : deux sorts à apprendre, 20 pa au total, les autres sortes ignorées", count == 2 and total == 2000)
	Check("[TRN] bouton montré, actif, le total dans son libellé", button and button:IsShown() and button.on == true
		and button:GetText() == NS.L.TRAINALL_BTN .. " (" .. NS:FormatMoney(2000) .. ")", button and button:GetText())
	Check("[TRN] maître ouvert : mises à jour et fermeture écoutées", NS.Listening("TRAINER_UPDATE", "trainAll")
		and NS.Listening("TRAINER_CLOSED", "trainAll"))
	local printed, restore = Printed()
	button:GetScript("OnClick")(button)
	restore()
	Check("[TRN] clic : tout est appris, un par un, dans l'ordre ; l'or payé ; le bilan dans le chat",
		#W.bought == 2 and W.bought[1] == 2 and W.bought[2] == 4 and W.money == 98000 and NS.trainAllRun == nil
		and printed[1] == NS:F("TRAINALL_DONE", 2, NS:FormatMoney(2000)), printed[1])
	Check("[TRN] plus rien à apprendre : bouton grisé, libellé sans total", button.on == false
		and button:GetText() == NS.L.TRAINALL_BTN)
	Mock:Fire("TRAINER_CLOSED")
	Check("[TRN] maître fermé : l'écoute est rendue", not NS.Listening("TRAINER_UPDATE", "trainAll")
		and not NS.Listening("PLAYER_MONEY", "trainAll"))
end

do
	Say("-- tout apprendre : pas assez d'or, refus, silence, réglage")
	Reset(1500)
	Mock:Fire("TRAINER_SHOW")
	local button = NS.trainAllButton
	Check("[TRN] pas assez d'or pour tout : grisé, il manque 5 pa, rien n'est acheté au clic",
		button.on == false and button.short == 500 and NS:TrainAllStart() == false and #W.bought == 0)
	W.money = 2000
	Mock:Fire("PLAYER_MONEY")
	Check("[TRN] l'or arrive : le bouton se réveille", button.on == true)
	W.refuse = true
	local printed, restore = Printed()
	NS:TrainAllStart()
	Mock:Fire("TRAINER_UPDATE")
	Check("[TRN] le serveur refuse : un seul essai, la série s'arrête, rien d'annoncé", #W.bought == 1 and NS.trainAllRun == nil
		and #printed == 0)
	W.refuse, W.silent = false, true
	NS:TrainAllStart()
	Mock.now = Mock.now + NS.TRAINALL_TIMEOUT + 1
	NS.TrainAllWatch()
	restore()
	Check("[TRN] le serveur se tait : la série s'arrête seule", NS.trainAllRun == nil and #W.bought == 2)
	Mock:Fire("TRAINER_CLOSED")
	Reset()
	NS:DB().trainAllEnabled = false
	Mock:Fire("TRAINER_SHOW")
	Check("[TRN] réglage coupé : pas de bouton, pas d'écoute", not NS.trainAllButton:IsShown()
		and not NS.Listening("TRAINER_UPDATE", "trainAll") and NS:TrainAllStart() == false)
	local row
	for _, page in ipairs(NS.OPTION_PAGES) do
		if page.id == "spellranks" then for _, r in ipairs(page.rows) do if r.key == "trainAllEnabled" then row = r end end end
	end
	Check("[TRN] réglage sur la page Rangs de sorts, activé par défaut", row ~= nil and (ResetWorld() or true)
		and NS:DB().trainAllEnabled == true)
end

Mock:Fire("TRAINER_CLOSED")
for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
NS.trainAllRun = nil
if NS.trainAllButton then NS.trainAllButton:Hide() end
