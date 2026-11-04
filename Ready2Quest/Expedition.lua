-- Expedition.lua -- module « Retour d'expédition » (v1.23.0)
--
-- Au retour en zone sûre après un départ confirmé, un court bilan du voyage :
-- durée, XP et niveaux, argent, butin notable, morts, usure, quêtes à rendre,
-- et ce qu'il faudrait racheter. Le module vit tout entier dans ce fichier et
-- ne s'appuie que sur l'API d'extension (callbacks DEPARTURE / RETURN de
-- Core.lua, RegisterStrings, RegisterDefaults, AddOptionPage, RegisterModule).
--
-- Mesures, et pourquoi celles-ci :
--   * argent : somme des écarts de PLAYER_MONEY pendant le voyage, séparés en
--     gains et dépenses. Un simple « argent au retour - argent au départ »
--     donnerait le net, mais cacherait 2 po gagnées puis 2 po de réparation.
--   * butin : lecture des messages CHAT_MSG_LOOT du joueur (« Tu reçois le
--     butin : ... »), reconnus à partir des chaînes du client (LOOT_ITEM_SELF
--     et consorts), donc dans la langue du client. Un diff des sacs se ferait
--     piéger par tout ce qui sort du sac pendant le voyage (objets vendus à un
--     marchand de campagne, consommés, détruits, empilés) et ne dirait pas ce
--     qui a été ramassé puis jeté ; le message, lui, n'arrive qu'une fois par
--     objet reçu, avec son lien (donc sa qualité) et sa quantité.
--   * XP : échantillons UnitXP à chaque PLAYER_XP_UPDATE ; une XP qui baisse
--     signale un passage de niveau (on ajoute la fin du niveau précédent).
--   * usure : rapport durabilité totale / maximale de l'équipement porté, au
--     départ et au retour (les morts coûtent 10 % chez l'ange, ça se voit).
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local WIDTH      = 360
local ROW_HEIGHT = 18
local MAX_ITEMS  = 3      -- objets notables listés sous la ligne « Butin »
local MIN_QUALITY = 2     -- inhabituel (vert) et au-dessus

-- ---------------------------------------------------------------------------
-- Chaînes, réglages, page d'options, module
-- ---------------------------------------------------------------------------
local FR = {
	OPT_PAGE_EXPEDITION      = "Retour d'expédition",
	OPT_PAGE_EXPEDITION_SUB  = "Un court bilan du voyage quand tu rentres en zone sûre.",
	OPT_EXP_WINDOW           = "Fenêtre de bilan",
	OPT_EXP_CHAT             = "Résumé d'une ligne dans le chat",
	OPT_EXP_MINTRIP          = "Voyage minimum",
	EXP_TITLE                = "Retour d'expédition",
	EXP_BACK_AT              = "Retour à %s",
	EXP_DURATION_LABEL       = "sur les routes",
	EXP_ROW_XP               = "Expérience",
	EXP_ROW_MONEY            = "Argent",
	EXP_ROW_LOOT             = "Butin",
	EXP_ROW_DEATHS           = "Morts",
	EXP_ROW_DURA             = "Usure",
	EXP_ROW_QUESTS           = "Quêtes",
	EXP_ROW_RESTOCK          = "À racheter",
	EXP_XP                   = "+%d XP",
	EXP_LEVELS               = "+%d niveau(x)",
	EXP_XP_NONE              = "aucune",
	EXP_MONEY_DETAIL         = "gagné %s, dépensé %s",
	EXP_MONEY_NONE           = "rien gagné, rien dépensé",
	EXP_LOOT_COUNT           = "%d objet(s) notable(s)",
	EXP_LOOT_NONE            = "rien de notable",
	EXP_LOOT_MORE            = "et %d autre(s)",
	EXP_DEATHS_NONE          = "aucune, bien joué",
	EXP_DURA_DETAIL          = "-%d pts, %d %% restant",
	EXP_DURA_NONE            = "rien de perdu",
	EXP_QUESTS_READY         = "%d à rendre",
	EXP_QUESTS_NEW           = "%d à rendre (+%d pendant le voyage)",
	EXP_QUESTS_NONE          = "rien à rendre",
	EXP_CHAT                 = "Retour d'expédition (%s) : %s.",
	EXP_CHAT_QUIET           = "rien à signaler",
	EXP_CHAT_DEATHS          = "%d mort(s)",
	EXP_CHAT_DURA            = "usure -%d pts",
	EXP_CHAT_QUESTS          = "%d quête(s) à rendre",
	EXP_CHAT_RESTOCK         = "à racheter : %s",
	EXP_DUR_SEC              = "%d s",
	EXP_DUR_MIN              = "%d min %02d",
	EXP_DUR_HOUR             = "%d h %02d",
}
local EN = {
	OPT_PAGE_EXPEDITION      = "Expedition report",
	OPT_PAGE_EXPEDITION_SUB  = "A short report of the trip when you get back to a safe zone.",
	OPT_EXP_WINDOW           = "Report window",
	OPT_EXP_CHAT             = "One-line chat summary",
	OPT_EXP_MINTRIP          = "Minimum trip",
	EXP_TITLE                = "Expedition report",
	EXP_BACK_AT              = "Back at %s",
	EXP_DURATION_LABEL       = "on the road",
	EXP_ROW_XP               = "Experience",
	EXP_ROW_MONEY            = "Money",
	EXP_ROW_LOOT             = "Loot",
	EXP_ROW_DEATHS           = "Deaths",
	EXP_ROW_DURA             = "Wear",
	EXP_ROW_QUESTS           = "Quests",
	EXP_ROW_RESTOCK          = "To restock",
	EXP_XP                   = "+%d XP",
	EXP_LEVELS               = "+%d level(s)",
	EXP_XP_NONE              = "none",
	EXP_MONEY_DETAIL         = "earned %s, spent %s",
	EXP_MONEY_NONE           = "nothing earned, nothing spent",
	EXP_LOOT_COUNT           = "%d notable item(s)",
	EXP_LOOT_NONE            = "nothing notable",
	EXP_LOOT_MORE            = "and %d more",
	EXP_DEATHS_NONE          = "none, well played",
	EXP_DURA_DETAIL          = "-%d pts, %d %% left",
	EXP_DURA_NONE            = "nothing lost",
	EXP_QUESTS_READY         = "%d to turn in",
	EXP_QUESTS_NEW           = "%d to turn in (+%d on this trip)",
	EXP_QUESTS_NONE          = "nothing to turn in",
	EXP_CHAT                 = "Expedition report (%s): %s.",
	EXP_CHAT_QUIET           = "nothing to report",
	EXP_CHAT_DEATHS          = "%d death(s)",
	EXP_CHAT_DURA            = "wear -%d pts",
	EXP_CHAT_QUESTS          = "%d quest(s) to turn in",
	EXP_CHAT_RESTOCK         = "restock: %s",
	EXP_DUR_SEC              = "%d s",
	EXP_DUR_MIN              = "%d min %02d",
	EXP_DUR_HOUR             = "%d h %02d",
}
ns.RegisterStrings(FR, EN)
-- exposées aux tests : chaque clé doit exister dans les deux langues
ns.EXPEDITION_STRINGS = { fr = FR, en = EN }

ns.RegisterDefaults({
	expeditionEnabled = true,
	expeditionWindow  = true,
	expeditionChat    = false,
	expeditionMinTrip = 60,     -- secondes ; en dessous, bilan seulement s'il s'est passé quelque chose
})

if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "expedition", title = "OPT_PAGE_EXPEDITION", group = "OPT_GROUP_MODULES", power = "expeditionEnabled",
		rows = {
			{ key = "expeditionWindow",  label = "OPT_EXP_WINDOW",  kind = "bool" },
			{ key = "expeditionChat",    label = "OPT_EXP_CHAT",    kind = "bool" },
			{ key = "expeditionMinTrip", label = "OPT_EXP_MINTRIP", kind = "number", min = 0, max = 600, step = 30, suffix = "OPT_SEC_UNIT" },
		},
	})
end

if ns.RegisterModule then
	ns.RegisterModule({ id = "expedition", key = "expeditionEnabled", label = "OPT_PAGE_EXPEDITION",
		aliases = { "expedition", "retour", "bilan", "report" } })
end

-- ---------------------------------------------------------------------------
-- Accès robustes au client : une API absente sur Era ne doit rien casser
-- ---------------------------------------------------------------------------
local function Call(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local function Money() return tonumber(Call("GetMoney")) end
local function Level() return tonumber(Call("UnitLevel", "player")) end
local function XP() return tonumber(Call("UnitXP", "player")) end
local function XPMax() return tonumber(Call("UnitXPMax", "player")) end

-- Durabilité totale de l'équipement porté, en % (nil si rien de mesurable)
local function DurabilityPercent()
	if type(rawget(_G, "GetInventoryItemDurability")) ~= "function" then return nil end
	local current, maximum = 0, 0
	for slot = 1, 19 do
		local cur, max = Call("GetInventoryItemDurability", slot)
		if type(cur) == "number" and type(max) == "number" and max > 0 then
			current, maximum = current + cur, maximum + max
		end
	end
	if maximum <= 0 then return nil end
	return current / maximum * 100
end

-- Même compte que le contrôle « quêtes » du Check avant le départ
local function ReadyQuests()
	local ready = 0
	local questLog = rawget(_G, "C_QuestLog")
	if type(questLog) == "table" and type(questLog.GetNumQuestLogEntries) == "function"
		and type(questLog.GetInfo) == "function" and type(questLog.ReadyForTurnIn) == "function" then
		local ok, total = pcall(questLog.GetNumQuestLogEntries)
		if not ok or type(total) ~= "number" then return nil end
		for i = 1, total do
			local okInfo, info = pcall(questLog.GetInfo, i)
			if okInfo and type(info) == "table" and info.questID then
				local okReady, isReady = pcall(questLog.ReadyForTurnIn, info.questID)
				if okReady and isReady == true then ready = ready + 1 end
			end
		end
		return ready
	end
	local total = tonumber(Call("GetNumQuestLogEntries"))
	if not total or not ns.QuestLogReady then return nil end
	for i = 1, total do
		if ns.QuestLogReady(i) then ready = ready + 1 end
	end
	return ready
end

-- ---------------------------------------------------------------------------
-- Butin : reconnaissance des messages de butin du joueur
-- ---------------------------------------------------------------------------
-- Les chaînes du client (traduites) d'abord : c'est la seule façon fiable de
-- distinguer « tu reçois » de « Machin reçoit » dans toutes les langues. Les
-- formes « multiple » passent avant : « %s. » avalerait aussi « [X]x5. ».

-- Couleur du lien -> qualité, si GetItemInfo n'a pas encore l'objet en cache
local LINK_COLORS = { ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6,
	["9d9d9d"] = 0, ["ffffff"] = 1 }

local function LinkQuality(link)
	local _, _, quality = Call("GetItemInfo", link)
	if type(quality) == "number" then return quality end
	-- clients récents : |cnIQ2:...  ; anciens : |cff1eff00...
	local iq = link:match("|cnIQ(%d+):")
	if iq then return tonumber(iq) end
	local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
	return hex and LINK_COLORS[hex:lower()] or nil
end

-- Butin du joueur (ns:ParseSelfLoot) : socle commun, Libs/Socle/World.lua.

-- ---------------------------------------------------------------------------
-- Suivi du voyage
-- ---------------------------------------------------------------------------
local function ModuleOn()
	local db = ns:DB()
	return db.enabled ~= false and db.expeditionEnabled ~= false
end

function ns:ExpeditionStart(from)
	if not ModuleOn() then self.expedition = nil; return end
	self.expedition = {
		from      = from,
		startedAt = ns.Now(),
		money     = Money(),
		lastMoney = Money(),
		earned    = 0,
		spent     = 0,
		level     = Level(),
		lastXP    = XP(),
		lastXPMax = XPMax(),
		xp        = 0,
		deaths    = 0,
		durability = DurabilityPercent(),
		quests    = ReadyQuests(),
		loot      = {},   -- { link, count, quality } dans l'ordre d'arrivée
	}
end

function ns:ExpeditionMoney()
	local trip = self.expedition
	local now = Money()
	if not trip or not now then return end
	if trip.lastMoney then
		local delta = now - trip.lastMoney
		if delta > 0 then trip.earned = trip.earned + delta
		elseif delta < 0 then trip.spent = trip.spent - delta end
	end
	trip.lastMoney = now
end

function ns:ExpeditionXP()
	local trip = self.expedition
	local now, max = XP(), XPMax()
	if not trip or not now then return end
	if trip.lastXP then
		if now >= trip.lastXP then
			trip.xp = trip.xp + (now - trip.lastXP)
		else
			-- l'XP repart de zéro : un niveau est passé entre deux échantillons
			trip.xp = trip.xp + math.max(0, (trip.lastXPMax or trip.lastXP) - trip.lastXP) + now
		end
	end
	trip.lastXP, trip.lastXPMax = now, max or trip.lastXPMax
end

function ns:ExpeditionLoot(message)
	local trip = self.expedition
	if not trip then return end
	local link, count = self:ParseSelfLoot(message)
	if not link then return end
	local quality = LinkQuality(link)
	if not quality or quality < MIN_QUALITY then return end
	for _, entry in ipairs(trip.loot) do
		if entry.link == link then entry.count = entry.count + count; return end
	end
	trip.loot[#trip.loot + 1] = { link = link, count = count, quality = quality }
end

-- Ce qu'il faut racheter : on rejoue les contrôles de réserves du Check avant
-- le départ (mêmes seuils, mêmes interrupteurs), sans recalculer la note.
local RESTOCK_CHECKS = { "vivres", "potions", "classreagents" }

function ns:ExpeditionRestock()
	local db = self:DB()
	if db.departureEnabled == false or not self.FindCheck then return {} end
	local list = {}
	for _, id in ipairs(RESTOCK_CHECKS) do
		local def = self:FindCheck(id)
		if def and (not self.IsModuleEnabled or self:IsModuleEnabled(id)) then
			local active = true
			if def.active then
				local okActive, res = pcall(def.active, db)
				active = okActive and res == true
			end
			if active then
				local okRun, okState = pcall(def.run, db)
				if okRun and okState == false then
					local label = def.label
					if type(label) == "function" then label = label() end
					list[#list + 1] = tostring(label or id)
				end
			end
		end
	end
	return list
end

function ns:ExpeditionReport(place)
	local trip = self.expedition
	if not trip then return nil end
	self:ExpeditionMoney()
	self:ExpeditionXP()

	local money = Money()
	local level = Level()
	local durability = DurabilityPercent()
	local quests = ReadyQuests()
	local report = {
		from     = trip.from,
		place    = place,
		duration = math.max(0, ns.Now() - (trip.startedAt or ns.Now())),
		xp       = trip.xp,
		levels   = (level and trip.level) and math.max(0, level - trip.level) or 0,
		earned   = trip.earned,
		spent    = trip.spent,
		net      = (money and trip.money) and (money - trip.money) or (trip.earned - trip.spent),
		deaths   = trip.deaths,
		loot     = trip.loot,
		durability = durability,
		duraLost = (durability and trip.durability) and math.max(0, math.floor(trip.durability - durability + 0.5)) or 0,
		quests   = quests,
		newQuests = (quests and trip.quests) and math.max(0, quests - trip.quests) or 0,
		restock  = self:ExpeditionRestock(),
	}
	return report
end

-- « Rien ne s'est passé » : ni XP, ni argent, ni butin notable, ni mort, ni usure
function ns:ExpeditionIsQuiet(report)
	return report.xp == 0 and report.levels == 0 and report.earned == 0 and report.spent == 0
		and #report.loot == 0 and report.deaths == 0 and report.duraLost == 0 and report.newQuests == 0
end

function ns:ExpeditionIsTrivial(report)
	local minimum = tonumber(self:DB().expeditionMinTrip) or 60
	return report.duration < minimum and self:ExpeditionIsQuiet(report)
end

function ns:ExpeditionFinish(place)
	-- module coupé pendant le voyage : on oublie le voyage, sans bilan
	local report = ModuleOn() and self:ExpeditionReport(place) or nil
	self.expedition = nil
	if not report or self:ExpeditionIsTrivial(report) then return nil end
	self.lastExpedition = report

	local db = self:DB()
	local shown = false
	if db.expeditionWindow ~= false and self.WantsNotice and self:WantsNotice() then
		-- une icône annonce le bilan (Notice.lua), la ligne du chat reste
		local notice = self:NoticeReturn(report)
		notice.onClick = function() ns:ShowExpeditionReport(report) end
		self:ShowNotice(notice)
		self:Print(self:ExpeditionChatLine(report))
		return report
	end
	if db.expeditionWindow ~= false then shown = self:ShowExpeditionReport(report) ~= nil end
	-- sans fenêtre possible (Theme absent), le chat prend le relais
	if db.expeditionChat == true or (db.expeditionWindow ~= false and not shown) then
		self:Print(self:ExpeditionChatLine(report))
	end
	return report
end

-- ---------------------------------------------------------------------------
-- Mise en forme
-- ---------------------------------------------------------------------------
function ns:FormatTripDuration(seconds)
	seconds = math.floor(tonumber(seconds) or 0)
	if seconds < 60 then return self:F("EXP_DUR_SEC", seconds) end
	if seconds < 3600 then return self:F("EXP_DUR_MIN", math.floor(seconds / 60), seconds % 60) end
	return self:F("EXP_DUR_HOUR", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
end

local function SignedMoney(copper)
	if copper < 0 then return "-" .. ns:FormatMoney(-copper) end
	return "+" .. ns:FormatMoney(copper)
end

function ns:ExpeditionXPText(report)
	local parts = {}
	if report.xp > 0 then parts[#parts + 1] = self:F("EXP_XP", report.xp) end
	if report.levels > 0 then parts[#parts + 1] = self:F("EXP_LEVELS", report.levels) end
	return table.concat(parts, ", ")
end

function ns:ExpeditionChatLine(report)
	local parts = {}
	local xp = self:ExpeditionXPText(report)
	if xp ~= "" then parts[#parts + 1] = xp end
	if report.earned > 0 or report.spent > 0 then parts[#parts + 1] = SignedMoney(report.net) end
	if #report.loot > 0 then
		local links = {}
		for index, entry in ipairs(report.loot) do
			if index > MAX_ITEMS then break end
			links[#links + 1] = entry.link .. (entry.count > 1 and ("x" .. entry.count) or "")
		end
		parts[#parts + 1] = table.concat(links, " ")
			.. (#report.loot > MAX_ITEMS and (" " .. self:F("EXP_LOOT_MORE", #report.loot - MAX_ITEMS)) or "")
	end
	if report.deaths > 0 then parts[#parts + 1] = self:F("EXP_CHAT_DEATHS", report.deaths) end
	if report.duraLost > 0 then parts[#parts + 1] = self:F("EXP_CHAT_DURA", report.duraLost) end
	if (report.quests or 0) > 0 then parts[#parts + 1] = self:F("EXP_CHAT_QUESTS", report.quests) end
	if #report.restock > 0 then parts[#parts + 1] = self:F("EXP_CHAT_RESTOCK", table.concat(report.restock, ", ")) end
	if #parts == 0 then parts[1] = L.EXP_CHAT_QUIET end
	return self:F("EXP_CHAT", self:FormatTripDuration(report.duration), table.concat(parts, ", "))
end

-- Lignes de la fenêtre : { label, valeur, détail gris, couleur du losange }
function ns:ExpeditionLines(report)
	local lines = {}
	local function Add(label, value, detail, color, filled)
		lines[#lines + 1] = { label = label, value = value, detail = detail, color = color, filled = filled }
	end

	local xp = self:ExpeditionXPText(report)
	Add(L.EXP_ROW_XP, xp ~= "" and xp or L.EXP_XP_NONE, nil, Theme.GOLD, xp ~= "")

	if report.earned > 0 or report.spent > 0 then
		Add(L.EXP_ROW_MONEY, SignedMoney(report.net),
			self:F("EXP_MONEY_DETAIL", self:FormatMoney(report.earned), self:FormatMoney(report.spent)), Theme.GOLD, true)
	else
		Add(L.EXP_ROW_MONEY, L.EXP_MONEY_NONE, nil, Theme.GOLD, false)
	end

	if #report.loot > 0 then
		Add(L.EXP_ROW_LOOT, self:F("EXP_LOOT_COUNT", #report.loot), nil, Theme.GOLD, true)
		for index, entry in ipairs(report.loot) do
			if index > MAX_ITEMS then
				lines[#lines + 1] = { item = true, value = Theme.T_GREY .. self:F("EXP_LOOT_MORE", #report.loot - MAX_ITEMS) .. "|r" }
				break
			end
			lines[#lines + 1] = { item = true, value = entry.link .. (entry.count > 1 and (" x" .. entry.count) or "") }
		end
	else
		Add(L.EXP_ROW_LOOT, L.EXP_LOOT_NONE, nil, Theme.GOLD, false)
	end

	if report.deaths > 0 then
		Add(L.EXP_ROW_DEATHS, tostring(report.deaths), nil, Theme.RED, true)
	else
		Add(L.EXP_ROW_DEATHS, L.EXP_DEATHS_NONE, nil, Theme.GREEN, false)
	end

	if report.duraLost > 0 then
		Add(L.EXP_ROW_DURA, self:F("EXP_DURA_DETAIL", report.duraLost, math.floor((report.durability or 0) + 0.5)), nil,
			report.durability and report.durability < 50 and Theme.RED or Theme.GOLD, true)
	elseif report.durability then
		Add(L.EXP_ROW_DURA, L.EXP_DURA_NONE, nil, Theme.GREEN, false)
	end

	-- bleu : une information, pas une alerte
	if report.quests then
		local text
		if report.quests == 0 then text = L.EXP_QUESTS_NONE
		elseif report.newQuests > 0 then text = self:F("EXP_QUESTS_NEW", report.quests, report.newQuests)
		else text = self:F("EXP_QUESTS_READY", report.quests) end
		Add(L.EXP_ROW_QUESTS, text, nil, Theme.BLUE, report.quests > 0)
	end

	if #report.restock > 0 then
		Add(L.EXP_ROW_RESTOCK, table.concat(report.restock, ", "), nil, Theme.ORANGE, true)
	end
	return lines
end

-- ---------------------------------------------------------------------------
-- Fenêtre (même habillage que « Avant le départ »)
-- ---------------------------------------------------------------------------
local MAX_LINES = 12

function ns:EnsureExpeditionWindow()
	if self.expeditionFrame then return self.expeditionFrame end
	if not Theme or not Theme.CreatePanel then return nil end

	local frame = Theme.CreatePanel(UIParent, WIDTH, 200, L.EXP_TITLE, { name = "Ready2QuestExpeditionFrame", titleSize = 14 })
	if not frame then return nil end
	if self.RestorePoint then self:RestorePoint(frame, "expeditionPoint", { point = "CENTER", x = 0, y = 160 }) end

	frame.subtitle:SetText("")
	frame.subtitle:SetWidth(WIDTH - 190)
	frame.subtitle:SetJustifyH("RIGHT")
	frame.subtitle:SetWordWrap(false)

	local top = frame.contentTop
	-- La durée en grand, dans la police maison : c'est ce qu'on lit en premier
	frame.duration = Theme.CreateTitle(frame, 26)
	frame.duration:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 6)
	frame.durationLabel = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.durationLabel:SetPoint("BOTTOMLEFT", frame.duration, "BOTTOMRIGHT", 6, 3)
	frame.durationLabel:SetText(Theme.T_GREY .. L.EXP_DURATION_LABEL .. "|r")
	frame.divider = Theme.CreateDivider(frame, WIDTH - 28, top - 42)

	frame.lines = {}
	for index = 1, MAX_LINES do
		local row = CreateFrame("Frame", nil, frame)
		row:SetSize(WIDTH - 28, ROW_HEIGHT - 2)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 50 - ((index - 1) * ROW_HEIGHT))
		row.status = Theme.CreateDiamond(row, 8, true)
		row.status:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.name = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.name:SetPoint("LEFT", row, "LEFT", 18, 0)
		row.name:SetWidth(84)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row.value = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.value:SetPoint("LEFT", row, "LEFT", 106, 0)
		row.value:SetWidth(WIDTH - 28 - 106 - 4)
		row.value:SetJustifyH("LEFT")
		row.value:SetWordWrap(false)
		row:Hide()
		frame.lines[index] = row
	end

	frame.closeButton = Theme.CreateButton(frame, 90, 20, L.OPT_CLOSE, function() frame:Hide() end, "primary")
	frame.closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 10)

	self.expeditionFrame = frame
	return frame
end

function ns:ShowExpeditionReport(report)
	report = report or self.lastExpedition
	if not report then return nil end
	local frame = self:EnsureExpeditionWindow()
	if not frame then return nil end

	frame.duration:SetText(self:FormatTripDuration(report.duration))
	local placeName = report.place and report.place.name
	frame.subtitle:SetText(placeName and self:F("EXP_BACK_AT", Theme.T_BLUE .. tostring(placeName) .. "|r") or "")

	local lines = self:ExpeditionLines(report)
	local count = math.min(#lines, MAX_LINES)
	for index, row in ipairs(frame.lines) do
		local line = lines[index]
		if line and index <= count then
			if line.item then
				-- objet notable : en retrait, sous la ligne « Butin », sans losange
				row.status:Hide()
				row.name:SetText("")
				row.value:SetText(line.value)
			else
				row.status:Show()
				row.status:SetTexture(line.filled and Theme.DIAMOND or Theme.DIAMOND_LINE)
				local c = line.color or Theme.GOLD
				row.status:SetVertexColor(c[1], c[2], c[3], 1)
				row.status.state = line.filled and "filled" or "line"
				row.name:SetText(line.label)
				row.name:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3])
				row.value:SetText(line.detail and (line.value .. "  " .. Theme.T_GREY .. line.detail .. "|r") or line.value)
			end
			row.line = line
			row:Show()
		else
			row.line = nil
			row:Hide()
		end
	end
	frame.visibleLines = count
	frame:SetHeight(36 + 50 + (count * ROW_HEIGHT) + 8 + 34)

	frame:Show()
	if Theme.FadeIn then Theme.FadeIn(frame, 0.2) end
	return frame
end

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
if ns.RegisterCallback then
	ns:RegisterCallback("DEPARTURE", function(self, from) self:ExpeditionStart(from) end)
	ns:RegisterCallback("RETURN", function(self, place) self:ExpeditionFinish(place) end)
end

local HANDLERS = {
	PLAYER_MONEY     = function() ns:ExpeditionMoney() end,
	PLAYER_XP_UPDATE = function() ns:ExpeditionXP() end,
	PLAYER_LEVEL_UP  = function() ns:ExpeditionXP() end,
	PLAYER_DEAD      = function() if ns.expedition then ns.expedition.deaths = ns.expedition.deaths + 1 end end,
	CHAT_MSG_LOOT    = function(message) ns:ExpeditionLoot(message) end,
}

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do
	-- un événement inconnu du client (Era, Forever) ne doit pas bloquer les autres
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if not ns.expedition then return end
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("expedition:" .. tostring(event), err) end
end)
ns.expeditionEventFrame = eventFrame

if ns.Mark then ns.Mark("Expedition") end
