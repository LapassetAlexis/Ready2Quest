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
	local train = G("ClassTrainerTrainButton")
	if type(train) == "table" then
		button:SetPoint("RIGHT", train, "LEFT", -4, 0)
	else
		button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 16, 8)
	end
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

-- Le libellé (« Tout apprendre (1 po 20 pa) ») et l'état ; posés seulement s'ils changent
function ns:TrainAllRefresh()
	local button = self:EnsureTrainAllButton()
	if not button then return nil end
	if not self:TrainAllOn() then button:Hide(); return nil end
	local count, total, _, money = self:TrainAllScan()
	button.count, button.total, button.short = count, total, math.max(0, total - money)
	local label = count > 0 and (L.TRAINALL_BTN .. " (" .. Money(total) .. ")") or L.TRAINALL_BTN
	if button.label ~= label then
		button.label = label
		button:SetText(label)
		-- la largeur suit le libellé (le total change d'un maître à l'autre)
		local width = Theme.TextWidth and tonumber(Theme.TextWidth(button, label, Theme.F_LABEL))
		if width and button.SetWidth then button:SetWidth(math.max(110, math.ceil(width) + 28)) end
	end
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
		return self:TrainAllFinish()     -- rien n'a bougé : le serveur a refusé
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
	ns.On("PLAYER_MONEY", OWNER, OnUpdate, "trainall:PLAYER_MONEY")
	-- la fenêtre du maître est chargée à la demande par le client, parfois
	-- juste après cet événement : un second passage la trouve
	if not ns:TrainAllRefresh() and not ns.trainAllButton and ns.Soon then
		ns.Soon("trainAll:late", 0.2, function() if ns.Listening("TRAINER_UPDATE", OWNER) then ns:TrainAllRefresh() end end)
	end
end
ns.On("TRAINER_SHOW", OWNER, OnShow, "trainall:TRAINER_SHOW")

if ns.Mark then ns.Mark("TrainAll") end
