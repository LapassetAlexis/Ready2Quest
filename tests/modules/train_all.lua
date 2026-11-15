-- Ready2Quest : « Tout apprendre » chez le maître (TrainAll.lua, 1.35.0). Le
-- bouton et son total, grisé sans assez d'or (l'infobulle dit le manque), la
-- série d'achats un par un après chaque réponse du serveur, l'arrêt sur un
-- refus ou un silence, l'écoute seulement fenêtre ouverte, le réglage.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local GLOBALS = { "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "BuyTrainerService",
	"GetMoney", "ClassTrainerFrame", "ClassTrainerTrainButton", "ClassTrainerMoneyFrame", "ClassTrainerFrameMoneyFrame" }
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

do
	-- Retour 1.35.0-beta5 (en jeu) : « Tout apprendre (5 pa 40 pc) » recouvrait
	-- l'argent du joueur (« 1 po 80 pa 8 pc »). Géométrie du bas de la fenêtre,
	-- comme la capture : argent à partir de x = 145, « S'entraîner » à x = 365.
	Say("-- tout apprendre : le bouton ne recouvre jamais l'argent possédé")
	local parent, train = _G.ClassTrainerFrame, _G.ClassTrainerTrainButton
	local TRAIN_LEFT, MONEY_LEFT = 365, 145
	local G = { moneyWidth = 120, parentLeft = 0 }
	train.GetLeft = function() return TRAIN_LEFT end
	parent.GetLeft = function() return G.parentLeft end
	local money = CreateFrame("Frame", "ClassTrainerMoneyFrame", parent)
	money.GetLeft = function() return MONEY_LEFT end
	money.GetRight = function() return MONEY_LEFT + G.moneyWidth end
	_G.ClassTrainerMoneyFrame = money
	local function Price(gold, silver, copper) return gold * 10000 + silver * 100 + copper end
	-- le bouton tient-il sans rien recouvrir ? (libellé dans le bouton, bouton après l'argent)
	local function Clear(button, moneyRight)
		local point, rel, relPoint, x = button:GetPoint()
		local fits = #(button:GetText() or "") * 6.4 + NS.TRAINALL_PAD <= button:GetWidth() + 0.001
		if button.mode == "above" then
			return fits and point == "BOTTOMRIGHT" and rel == train and relPoint == "TOPRIGHT"
		end
		local left = TRAIN_LEFT + x - button:GetWidth()
		return fits and point == "RIGHT" and rel == train and relPoint == "LEFT" and left >= moneyRight
	end
	local function Open(cost, moneyWidth, playerMoney)
		Reset(playerMoney or 100000000)
		W.services[2].cost, W.services[4].cost = cost, 0
		G.moneyWidth = moneyWidth
		Mock:Fire("TRAINER_SHOW")
		return NS.trainAllButton
	end

	local button = Open(40, 20)
	Check("[TRN] place large : libellé complet à côté de « S'entraîner », l'argent libre",
		button.mode == "full" and button:GetText() == NS.L.TRAINALL_BTN .. " (" .. NS:FormatMoney(40) .. ")"
		and Clear(button, MONEY_LEFT + 20), button.mode)
	button = Open(Price(0, 5, 40), 80)
	Check("[TRN] place moyenne : libellé court « Tout apprendre », l'argent libre, le total dans l'infobulle",
		button.mode == "short" and button:GetText() == NS.L.TRAINALL_BTN and Clear(button, MONEY_LEFT + 80)
		and button.total == 540, button.mode)
	button = Open(Price(0, 5, 40), 120, 18008)
	Check("[TRN] la capture (1 po 80 pa 8 pc, 5 pa 40 pc) : rien ne tient à côté, le bouton passe au-dessus",
		button.mode == "above" and Clear(button, MONEY_LEFT + 120) and button.on == true, button.mode)

	-- tous les prix, toutes les largeurs d'argent, les deux langues : jamais de recouvrement
	local bad = {}
	for _, english in ipairs({ false, true }) do
		if english then rawset(NS.L, "TRAINALL_BTN", (NS.TRAINALL_STRINGS and NS.TRAINALL_STRINGS.en.TRAINALL_BTN) or "Learn all") end
		for _, cost in ipairs({ 0, 40, Price(0, 5, 40), Price(1, 20, 0), Price(123, 45, 67) }) do
			for moneyWidth = 20, 220, 10 do
				for _, playerMoney in ipairs({ 1, 100000000 }) do
					button = Open(cost, moneyWidth, playerMoney)
					if not Clear(button, MONEY_LEFT + moneyWidth) then
						bad[#bad + 1] = ("%s/%d/%d/%s"):format(english and "en" or "fr", cost, moneyWidth, tostring(button.mode))
					end
				end
			end
		end
		rawset(NS.L, "TRAINALL_BTN", nil)
	end
	Check("[TRN] tous prix (jusqu'à 123 po 45 pa 67 pc), toute fortune, FR et EN, grisé ou non : l'argent jamais recouvert",
		#bad == 0, table.concat(bad, " ", 1, math.min(#bad, 6)))

	button = Open(0, 60)
	for _, s in ipairs(W.services) do if s.kind == "available" then s.kind = "used" end end
	Mock:Fire("TRAINER_UPDATE")
	Check("[TRN] tout est déjà appris : « Tout apprendre » grisé, à côté, sans recouvrir",
		button.count == 0 and button.on == false and button:GetText() == NS.L.TRAINALL_BTN
		and button.mode ~= "above" and Clear(button, MONEY_LEFT + 60), button.mode)
	button = Open(Price(0, 5, 40), 40, 100)
	Check("[TRN] pas assez d'or : grisé, il manque l'argent dans l'infobulle, l'argent libre",
		button.on == false and button.short == 440 and Clear(button, MONEY_LEFT + 40))

	-- l'argent change : le client le redessine après nous, la place est remesurée
	button = Open(40, 20)
	local before = button.mode
	W.money = W.money * 100
	Mock:Fire("PLAYER_MONEY")
	G.moneyWidth = 120              -- le cadre d'argent du client s'élargit juste après
	Mock:Advance(0.2)
	Check("[TRN] l'argent s'allonge : la place est remesurée, le bouton s'écarte",
		before == "full" and button.mode == "above" and Clear(button, MONEY_LEFT + 120), button.mode)
	-- la liste change (TRAINER_UPDATE) : le total aussi, la place suit
	G.moneyWidth = 40
	W.services[2].cost = Price(123, 45, 67)
	Mock:Fire("TRAINER_UPDATE")
	Check("[TRN] la liste change : libellé et place recalculés", Clear(button, MONEY_LEFT + 40)
		and button.total == Price(123, 45, 67), button.mode)

	-- cadre d'argent d'un autre nom, enfant du maître
	_G.ClassTrainerMoneyFrame = nil
	local savedChildren = parent.GetChildren
	local bottom = CreateFrame("Frame", "ClassTrainerFrameBottom", parent)
	local child = CreateFrame("Frame", "ClassTrainerFrameBottomMoney", bottom)
	child.GetLeft = function() return MONEY_LEFT end
	child.GetRight = function() return MONEY_LEFT + 150 end
	bottom.GetChildren = function() return child end
	parent.GetChildren = function() return CreateFrame("Frame"), bottom end
	Check("[TRN] cadre d'argent trouvé parmi les enfants du maître", NS:TrainAllMoneyFrame(parent) == child)
	button = Open(Price(0, 5, 40), 0)
	Check("[TRN] argent enfant du maître : il n'est pas recouvert", Clear(button, MONEY_LEFT + 150), button.mode)
	-- introuvable : une marge sûre à gauche
	parent.GetChildren = function() error("pas d'enfants lisibles") end
	button = Open(Price(0, 5, 40), 0)
	Check("[TRN] argent introuvable : la marge sûre de gauche est réservée",
		NS:TrainAllMoneyFrame(parent) == nil and Clear(button, G.parentLeft + NS.TRAINALL_SAFE_LEFT), button.mode)
	-- bords illisibles (fenêtre pas encore posée) : au-dessus, jamais sur l'argent
	parent.GetChildren = savedChildren
	_G.ClassTrainerMoneyFrame = money
	train.GetLeft = function() return nil end
	button = Open(Price(0, 5, 40), 40)
	Check("[TRN] bords illisibles : le bouton passe au-dessus de « S'entraîner »", button.mode == "above"
		and Clear(button, 0), button.mode)
	train.GetLeft = function() error("secret") end
	button = Open(Price(0, 5, 40), 40)
	Check("[TRN] bord qui lève une erreur : pas d'erreur, au-dessus", button.mode == "above", button.mode)
	train.GetLeft, parent.GetLeft = nil, nil
end

Mock:Fire("TRAINER_CLOSED")
for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
NS.trainAllRun = nil
if NS.trainAllButton then NS.trainAllButton:Hide() end
