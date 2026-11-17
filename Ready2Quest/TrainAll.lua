-- TrainAll.lua -- « Tout apprendre » chez le maître (Ready2Quest 1.35.0)
--
-- Chez un maître (classe ou métier), un bouton à côté de « Apprendre » :
-- « Tout apprendre » avec le total à payer. Un clic apprend tout ce qui est
-- disponible. Pas assez d'or pour tout : le bouton est grisé et l'infobulle
-- dit combien il manque (rien n'est acheté à moitié sans que tu le saches).
--   * rien n'est jamais appris sans ton clic ;
--   * les achats partent un par un, chacun après la réponse du serveur
--     (TRAINER_UPDATE) : la liste du client reste juste, et un refus arrête tout ;
--   * les événements du maître ne sont écoutés que fenêtre ouverte.
-- API du maître : GetNumTrainerServices, GetTrainerServiceInfo (la sorte
-- « available » est cherchée parmi ses retours : son rang a changé selon les
-- clients), GetTrainerServiceCost, BuyTrainerService, GetMoney.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

ns.TRAINALL_TIMEOUT = 3      -- s sans réponse du serveur : la série s'arrête
ns.TRAINALL_MAX = 200        -- achats au plus par clic (garde-fou)

local FR = {
	OPT_TRAINALL        = "Bouton « Tout apprendre » chez les maîtres",
	OPT_TRAINALL_DESC   = "Chez un maître de classe ou de métier : un bouton qui apprend tout ce qui est disponible, avec le total à payer.",
	TRAINALL_BTN        = "Tout apprendre",
	TRAINALL_TIP_COUNT  = "%d à apprendre",
	TRAINALL_TIP_TOTAL  = "Total : %s",
	TRAINALL_TIP_SHORT  = "Il te manque %s.",
	TRAINALL_TIP_NONE   = "Rien de nouveau à apprendre ici.",
	TRAINALL_DONE       = "Maître : %d appris pour %s.",
	TRAINALL_STOPPED    = "Maître : %d appris sur %d (%s). Le reste n'a pas pu être appris.",
}
local EN = {
	OPT_TRAINALL        = "\"Learn all\" button at trainers",
	OPT_TRAINALL_DESC   = "At a class or profession trainer: a button that learns everything available, with the total cost.",
	TRAINALL_BTN        = "Learn all",
	TRAINALL_TIP_COUNT  = "%d to learn",
	TRAINALL_TIP_TOTAL  = "Total: %s",
	TRAINALL_TIP_SHORT  = "You are %s short.",
	TRAINALL_TIP_NONE   = "Nothing new to learn here.",
	TRAINALL_DONE       = "Trainer: %d learned for %s.",
	TRAINALL_STOPPED    = "Trainer: %d learned out of %d (%s). The rest could not be learned.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TRAINALL_STRINGS = { fr = FR, en = EN } end
ns.RegisterDefaults({ trainAllEnabled = true })

-- réglage : sur la page « Rangs de sorts » (les deux parlent du maître)
for _, page in ipairs(ns.OPTION_PAGES or {}) do
	if page.id == "spellranks" and type(page.rows) == "table" then
		local present = false
		for _, row in ipairs(page.rows) do if row.key == "trainAllEnabled" then present = true end end
		if not present then
			page.rows[#page.rows + 1] = { key = "trainAllEnabled", label = "OPT_TRAINALL", kind = "bool",
				describe = function() return L.OPT_TRAINALL_DESC end }
		end
	end
end

local function G(name) return rawget(_G, name) end
local function Plain(value) return ns.Plain and ns.Plain(value) or value end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Money(copper) return ns.FormatMoney and ns:FormatMoney(copper) or tostring(copper) end

function ns:TrainAllOn()
	local db = self:DB()
	return db.enabled ~= false and db.trainAllEnabled ~= false
end

-- Le service `index` est-il à apprendre ? (« available » parmi les retours)
local function Available(index)
	local info = G("GetTrainerServiceInfo")
	if type(info) ~= "function" then return false end
	local ok, a, b, c, d = pcall(info, index)
	if not ok then return false end
	return Plain(a) == "available" or Plain(b) == "available" or Plain(c) == "available" or Plain(d) == "available"
end

-- Ce qu'il y a à apprendre : nombre, total (cuivre), premier indice ; et l'or du joueur
function ns:TrainAllScan()
	local count, total, first = 0, 0, nil
	local num, cost = G("GetNumTrainerServices"), G("GetTrainerServiceCost")
	if type(num) ~= "function" or type(cost) ~= "function" then return 0, 0, nil, 0 end
	local okNum, services = pcall(num)
	services = okNum and tonumber(Plain(services)) or 0
	for index = 1, services do
		if Available(index) then
			local okCost, price = pcall(cost, index)
			count, total = count + 1, total + (okCost and tonumber(Plain(price)) or 0)
			first = first or index
		end
	end
	local getMoney = G("GetMoney")
	local okMoney, money = pcall(type(getMoney) == "function" and getMoney or function() return 0 end)
	return count, total, first, okMoney and tonumber(Plain(money)) or 0
end

-- ---------------------------------------------------------------------------
-- Le bouton, sur la fenêtre du maître du client
-- ---------------------------------------------------------------------------
local function ShowTip(button)
	local tooltip = G("GameTooltip")
	if type(tooltip) ~= "table" or not tooltip.SetOwner then return end
	tooltip:SetOwner(button, "ANCHOR_TOP")
	Theme.TooltipLine(tooltip, L.TRAINALL_BTN, Theme.PARCHMENT)
	if (button.count or 0) == 0 then
		Theme.TooltipLine(tooltip, L.TRAINALL_TIP_NONE, Theme.MUTED_LIGHT)
	else
		Theme.TooltipLine(tooltip, ns:F("TRAINALL_TIP_COUNT", button.count), Theme.TEXT)
		Theme.TooltipLine(tooltip, ns:F("TRAINALL_TIP_TOTAL", Money(button.total)), Theme.TEXT)
		if button.short and button.short > 0 then
			Theme.TooltipLine(tooltip, ns:F("TRAINALL_TIP_SHORT", Money(button.short)), Theme.RED)
		end
	end
	tooltip:Show()
end

function ns:EnsureTrainAllButton()
	if self.trainAllButton then return self.trainAllButton end
	local parent = G("ClassTrainerFrame")
	if type(parent) ~= "table" then return nil end
	-- le bouton du client (rouge, comme « Apprendre ») ; sans ce modèle, celui du thème
	local ok, button = pcall(CreateFrame, "Button", "Ready2QuestTrainAllButton", parent, "UIPanelButtonTemplate")
	if not (ok and button) then
		button = Theme.CreateButton and Theme.CreateButton(parent, 150, "sm", L.TRAINALL_BTN)
		if not button then return nil end
		button.themed = true
	end
	if button.SetSize then button:SetSize(150, 22) end
	-- la place est choisie à chaque rafraîchissement (TrainAllPlace) : jamais sur l'argent
	button:SetScript("OnClick", function() ns:TrainAllStart() end)
	button:SetScript("OnEnter", ShowTip)
	button:SetScript("OnLeave", function()
		local tooltip = G("GameTooltip")
		if type(tooltip) == "table" and tooltip.Hide then tooltip:Hide() end
	end)
	-- grisé, il garde son infobulle (elle dit ce qui manque)
	if button.SetMotionScriptsWhileDisabled then pcall(button.SetMotionScriptsWhileDisabled, button, true) end
	self.trainAllButton = button
	return button
end

-- ---------------------------------------------------------------------------
-- La place du bouton : entre l'argent du joueur et « S'entraîner », sans
-- jamais recouvrir l'argent (retour 1.35.0-beta5 : « Tout apprendre (5 pa 40 pc) »
-- couvrait « 1 po 80 pa 8 pc »). Libellé complet s'il tient, sinon le court
-- (le total reste dans l'infobulle), sinon au-dessus de « S'entraîner ».
-- ---------------------------------------------------------------------------
ns.TRAINALL_GAP_TRAIN = 4     -- px entre le bouton et « S'entraîner »
ns.TRAINALL_GAP_MONEY = 8     -- px laissés libres après l'argent
ns.TRAINALL_SAFE_LEFT = 220   -- px réservés à gauche quand l'argent est introuvable
ns.TRAINALL_MIN_WIDTH = 110   -- largeur d'agrément (abandonnée si elle ne tient pas)
ns.TRAINALL_PAD = 28          -- marge du libellé dans le bouton

local function Scale(frame)
	if type(frame) ~= "table" or type(frame.GetEffectiveScale) ~= "function" then return 1 end
	local ok, s = pcall(frame.GetEffectiveScale, frame)
	s = ok and tonumber(Plain(s)) or nil
	return (s and s > 0) and s or 1
end

-- Bord gauche ou droit d'un cadre, en pixels d'écran (nil si illisible)
local function Edge(frame, method)
	if type(frame) ~= "table" or type(frame[method]) ~= "function" then return nil end
	local ok, value = pcall(frame[method], frame)
	value = ok and tonumber(Plain(value)) or nil
	return value and value * Scale(frame) or nil
end

local function FrameName(frame)
	if type(frame) ~= "table" or type(frame.GetName) ~= "function" then return nil end
	local ok, name = pcall(frame.GetName, frame)
	name = ok and Plain(name) or nil
	return type(name) == "string" and name or nil
end

-- Un enfant (ou petit-enfant) du maître dont le nom parle d'argent
local function MoneyChild(frame, depth)
	if type(frame) ~= "table" or type(frame.GetChildren) ~= "function" or depth > 2 then return nil end
	local packed = { pcall(frame.GetChildren, frame) }
	if not packed[1] then return nil end
	for index = 2, #packed do
		local name = FrameName(packed[index])
		if name and name:find("Money") and not name:find("^Ready2Quest") then return packed[index] end
	end
	for index = 2, #packed do
		local found = MoneyChild(packed[index], depth + 1)
		if found then return found end
	end
	return nil
end

-- Le cadre d'argent du maître : plusieurs noms selon les clients
function ns:TrainAllMoneyFrame(parent)
	for _, name in ipairs({ "ClassTrainerMoneyFrame", "ClassTrainerFrameMoneyFrame" }) do
		local frame = G(name)
		if type(frame) == "table" then return frame end
	end
	if type(parent) ~= "table" then return nil end
	for _, key in ipairs({ "MoneyFrame", "moneyFrame", "Money" }) do
		local frame = rawget(parent, key)
		if type(frame) == "table" then return frame end
	end
	return MoneyChild(parent, 1)
end

-- Bord droit de l'argent affiché (le cadre, ou sa pièce la plus à droite)
local function MoneyRight(money)
	local right = Edge(money, "GetRight")
	local name = FrameName(money)
	if name then
		for _, coin in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do
			local edge = Edge(G(name .. coin), "GetRight")
			if edge and (not right or edge > right) then right = edge end
		end
	end
	return right
end

-- Largeur d'un libellé dans ce bouton (sa propre police si possible)
local function LabelWidth(button, label)
	local width
	if type(button.GetFontString) == "function" then
		local okFs, fs = pcall(button.GetFontString, button)
		if okFs and type(fs) == "table" and fs.SetText and fs.GetStringWidth then
			local old = fs.GetText and fs:GetText()
			pcall(fs.SetText, fs, label)
			local ok, w = pcall(fs.GetStringWidth, fs)
			width = ok and tonumber(Plain(w)) or nil
			pcall(fs.SetText, fs, old)
		end
	end
	if (not width or width <= 0) and Theme.TextWidth then width = tonumber(Theme.TextWidth(button, label, Theme.F_LABEL)) end
	return math.ceil(width or (#label * 7)) + ns.TRAINALL_PAD
end

-- Place libre (px du bouton) entre l'argent et « S'entraîner » ; nil : inconnue
function ns:TrainAllFreeSpace(button, parent, train)
	local trainLeft = Edge(train, "GetLeft")
	if not trainLeft then return nil end
	local money = self:TrainAllMoneyFrame(parent)
	local limit = money and MoneyRight(money)
	local moneyLeft = money and Edge(money, "GetLeft")
	if limit and moneyLeft and moneyLeft >= trainLeft then
		-- l'argent est à droite de « S'entraîner » : il n'est pas sur le chemin
		limit = Edge(parent, "GetLeft")
		if not limit then return nil end
	elseif not limit then
		-- argent introuvable : une marge sûre depuis le bord gauche du maître
		local parentLeft = Edge(parent, "GetLeft")
		if not parentLeft then return nil end
		limit = parentLeft + ns.TRAINALL_SAFE_LEFT * Scale(parent)
	end
	return (trainLeft - limit) / Scale(button) - ns.TRAINALL_GAP_TRAIN - ns.TRAINALL_GAP_MONEY
end

-- Libellé, largeur et ancre ; posés seulement s'ils changent. Rend le mode :
-- "full" (à côté, avec le total), "short" (à côté, sans le total), "above"
function ns:TrainAllPlace(button, count, total)
	local parent, train = G("ClassTrainerFrame"), G("ClassTrainerTrainButton")
	if type(train) ~= "table" then train = nil end
	local full = count > 0 and (L.TRAINALL_BTN .. " (" .. Money(total) .. ")") or L.TRAINALL_BTN
	local short = L.TRAINALL_BTN
	local fullWidth, shortWidth = LabelWidth(button, full), LabelWidth(button, short)
	local free = train and self:TrainAllFreeSpace(button, parent, train) or nil
	local mode, label, width
	if free then
		for _, try in ipairs({
			{ "full", full, math.max(ns.TRAINALL_MIN_WIDTH, fullWidth) }, { "full", full, fullWidth },
			{ "short", short, math.max(ns.TRAINALL_MIN_WIDTH, shortWidth) }, { "short", short, shortWidth },
		}) do
			if try[3] <= free then mode, label, width = try[1], try[2], try[3]; break end
		end
	end
	if not mode then
		-- pas de place mesurée à côté : au-dessus de « S'entraîner », rien n'est recouvert en bas
		mode, label, width = "above", full, math.max(ns.TRAINALL_MIN_WIDTH, fullWidth)
	end
	button.mode, button.free = mode, free
	if button.label ~= label then
		button.label = label
		button:SetText(label)
	end
	if button.width ~= width then
		button.width = width
		if button.SetWidth then button:SetWidth(width) end
	end
	local anchor = mode .. tostring(train)
	if button.anchor ~= anchor then
		button.anchor = anchor
		if button.ClearAllPoints then button:ClearAllPoints() end
		if not train then
			-- pas de « S'entraîner » connu : au-dessus du bas de la fenêtre, à droite
			button:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 40)
		elseif mode == "above" then
			button:SetPoint("BOTTOMRIGHT", train, "TOPRIGHT", 0, ns.TRAINALL_GAP_TRAIN)
		else
			button:SetPoint("RIGHT", train, "LEFT", -ns.TRAINALL_GAP_TRAIN, 0)
		end
	end
	return mode
end

-- Le libellé (« Tout apprendre (1 po 20 pa) »), la place et l'état ; posés seulement s'ils changent
function ns:TrainAllRefresh()
	local button = self:EnsureTrainAllButton()
	if not button then return nil end
	if not self:TrainAllOn() then button:Hide(); return nil end
	local count, total, _, money = self:TrainAllScan()
	button.count, button.total, button.short = count, total, math.max(0, total - money)
	self:TrainAllPlace(button, count, total)
	local on = count > 0 and button.short == 0 and not self.trainAllRun
	if button.on ~= on then
		button.on = on
		if on then
			if button.Enable then button:Enable() end
		elseif button.Disable then
			button:Disable()
		end
	end
	button:Show()
	return count, total
end

-- ---------------------------------------------------------------------------
-- La série d'achats : un par un, chacun après la réponse du serveur
-- ---------------------------------------------------------------------------
function ns:TrainAllStart()
	if self.trainAllRun or not self:TrainAllOn() then return false end
	local count, total, _, money = self:TrainAllScan()
	if count == 0 or total > money then self:TrainAllRefresh(); return false end
	self.trainAllRun = { want = count, total = total, done = 0, spent = 0 }
	ns.Every("trainAll", 0.5, ns.TrainAllWatch)
	self:TrainAllStep()
	return true
end

-- L'achat suivant ; plus rien à apprendre (ou plus assez d'or) : le bilan
function ns:TrainAllStep()
	local run = self.trainAllRun
	if not run then return false end
	local count, _, first, money = self:TrainAllScan()
	-- la réponse à l'achat d'avant : un service de moins = appris
	if run.pending and count < run.pending.count then
		run.done, run.spent = run.done + 1, run.spent + run.pending.price
	elseif run.pending then
		-- 1.37.1 : rien n'a encore bougé : on attend la liste à jour (le
		-- serveur répond en plusieurs fois) ; un vrai refus est arrêté par
		-- TrainAllWatch au bout de TRAINALL_TIMEOUT
		return true
	end
	run.pending = nil
	if count == 0 or not first or run.done >= ns.TRAINALL_MAX then return self:TrainAllFinish() end
	local cost, buy = G("GetTrainerServiceCost"), G("BuyTrainerService")
	local okCost, price = pcall(cost, first)
	price = okCost and tonumber(Plain(price)) or 0
	if price > money or type(buy) ~= "function" then return self:TrainAllFinish() end
	run.pending = { count = count, price = price }
	run.at = Clock()
	local ok, err = pcall(buy, first)
	if not ok then
		if self.RecordError then self:RecordError("trainall:buy", err) end
		run.pending = nil
		return self:TrainAllFinish()
	end
	return true
end

function ns:TrainAllFinish()
	local run = self.trainAllRun
	self.trainAllRun = nil
	if ns.Cancel then ns.Cancel("trainAll") end
	if run and run.done > 0 then
		if run.done >= run.want then
			self:Print(self:F("TRAINALL_DONE", run.done, Money(run.spent)))
		else
			self:Print(self:F("TRAINALL_STOPPED", run.done, run.want, Money(run.spent)))
		end
	end
	self:TrainAllRefresh()
	return false
end

-- Le serveur ne répond plus : la série s'arrête (jamais de boucle)
function ns.TrainAllWatch()
	local run = ns.trainAllRun
	if not run then return false end
	if run.at and Clock() - run.at > ns.TRAINALL_TIMEOUT then ns:TrainAllFinish(); return false end
end

-- ---------------------------------------------------------------------------
-- Événements : TRAINER_SHOW toujours (rare) ; le reste fenêtre ouverte seulement
-- ---------------------------------------------------------------------------
local OWNER = "trainAll"
local function OnUpdate()
	if ns.trainAllRun then ns:TrainAllStep() else ns:TrainAllRefresh() end
end
-- l'argent du client se redessine (sa largeur change) après notre passage :
-- la place est remesurée un instant plus tard, fenêtre toujours ouverte
local function Relayout()
	if not ns.Soon then return end
	ns.Soon("trainAll:layout", 0.1, function()
		if ns.Listening("TRAINER_UPDATE", OWNER) and not ns.trainAllRun then ns:TrainAllRefresh() end
	end)
end
-- 1.37.1 : pendant une série, l'argent bouge AVANT la liste du maître :
-- avancer là concluait « refusé » et arrêtait la série après 1 à 3 achats.
-- Seul TRAINER_UPDATE fait avancer la série.
local function OnMoney()
	if ns.trainAllRun then return end
	OnUpdate()
	Relayout()
end
local function OnClosed()
	ns.Off("TRAINER_UPDATE", OWNER)
	ns.Off("TRAINER_CLOSED", OWNER)
	ns.Off("PLAYER_MONEY", OWNER)
	if ns.trainAllRun then ns:TrainAllFinish() end
end
local function OnShow()
	if not ns:TrainAllOn() then
		if ns.trainAllButton then ns.trainAllButton:Hide() end
		return
	end
	ns.On("TRAINER_UPDATE", OWNER, OnUpdate, "trainall:TRAINER_UPDATE")
	ns.On("TRAINER_CLOSED", OWNER, OnClosed, "trainall:TRAINER_CLOSED")
	ns.On("PLAYER_MONEY", OWNER, OnMoney, "trainall:PLAYER_MONEY")
	-- la fenêtre du maître est chargée à la demande par le client, parfois
	-- juste après cet événement : un second passage la trouve
	if not ns:TrainAllRefresh() and not ns.trainAllButton and ns.Soon then
		ns.Soon("trainAll:late", 0.2, function() if ns.Listening("TRAINER_UPDATE", OWNER) then ns:TrainAllRefresh() end end)
	end
	-- la fenêtre vient de s'ouvrir : son argent et ses bords peuvent n'être posés qu'après
	Relayout()
end
ns.On("TRAINER_SHOW", OWNER, OnShow, "trainall:TRAINER_SHOW")

if ns.Mark then ns.Mark("TrainAll") end
