-- QuestCompanion 3.1.0 bêta 9 / socle : « QuestCompanion a été bloqué à cause
-- d'une action qui n'est utilisable que par l'IU de Blizzard » à chaque sortie
-- de donjon (retour d'un testeur, ADDON_ACTION_FORBIDDEN).
--   1. Journal de combat fermé (moteur 12.0) : aucun RegisterEvent ni
--      UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED") sur aucun cadre, ni par
--      le cadre commun (ns.On / ns.Off), ni par les hauts faits à l'entrée et
--      à la sortie d'une instance (cause de la 3.0.3 : FeatUnlisten).
--   2. Filtre CHAT_MSG_SYSTEM des échanges : posé seulement pendant la
--      fenêtre utile, retiré ensuite.
--   3. Menus du clic droit : rien d'écrit en instance.
--   4. Annonce automatique : rien pendant le verrou de la messagerie ni un
--      écran de chargement ; coupée après un refus du jeu.
--   5. Diagnostic : ADDON_ACTION_FORBIDDEN / BLOCKED notés (sauvegarde,
--      /qc diag), une ligne dans le chat par session, pour chaque addon.
local Check, Say, ResetWorld, QNS, RNS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.NS, T.Mock
local CLEU = "COMBAT_LOG_EVENT_UNFILTERED"

local saved = {}
local GLOBALS = { "C_CombatLog", "CombatLogGetCurrentEventInfo", "IsInInstance", "GetInstanceInfo", "ChatFrameUtil",
	"ChatFrame_AddMessageEventFilter", "ChatFrame_RemoveMessageEventFilter", "C_ChatInfo", "SendChatMessage",
	"IsInGroup", "IsInRaid", "InCombatLockdown", "UnitAffectingCombat", "UnitName", "GetNormalizedRealmName",
	"UnitIsFriend", "UnitFactionGroup", "GetRealZoneText", "date" }
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end
local function Restore() for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end end
-- un bloc qui plante est un échec (les suivants jouent quand même)
local function Block(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		Restore()
		Check("[BLOQ] " .. name .. " : sans erreur", false, tostring(err))
	end
end

-- Espion : chaque appel au client sur le journal de combat, tous cadres confondus
local function SpyCLEU()
	local spy = { calls = {} }
	local wrapped = {}
	for _, frame in ipairs(Mock.frames) do
		if type(frame.RegisterEvent) == "function" then
			local reg, unreg, unitReg = frame.RegisterEvent, frame.UnregisterEvent, frame.RegisterUnitEvent
			wrapped[#wrapped + 1] = { frame, reg, unreg, unitReg }
			frame.RegisterEvent = function(self, event, ...)
				if event == CLEU then spy.calls[#spy.calls + 1] = "register" end
				return reg(self, event, ...)
			end
			frame.UnregisterEvent = function(self, event, ...)
				if event == CLEU then spy.calls[#spy.calls + 1] = "unregister" end
				return unreg(self, event, ...)
			end
		end
	end
	function spy.Stop()
		for _, w in ipairs(wrapped) do w[1].RegisterEvent, w[1].UnregisterEvent = w[2], w[3] end
	end
	return spy
end

-- 1. Journal de combat fermé ------------------------------------------------
Block("journal de combat", function()
	Say("-- action bloquée : journal de combat fermé, jamais touché")
	ResetWorld()
	_G.C_CombatLog = { IsCombatLogRestricted = function() return true end }
	local spy = SpyCLEU()
	-- les abonnés du harnais (journal ouvert au chargement) mis en attente : le
	-- cadre commun n'a plus aucun abonné au journal, comme sur Forever
	local HOLDERS = { "bestiary", "companion", "journal" }
	for _, holder in ipairs(HOLDERS) do QNS.EventHold(holder, true) end
	local owner = {}
	local heard = QNS.On(CLEU, owner, function() end, "test:" .. CLEU)
	QNS.Off(CLEU, owner)
	local frame = CreateFrame("Frame")
	frame.RegisterEvent = function(self, event) if event == CLEU then spy.calls[#spy.calls + 1] = "register" end end
	frame.UnregisterEvent = function(self, event) if event == CLEU then spy.calls[#spy.calls + 1] = "unregister" end end
	local okDirect, direct = pcall(QNS.UnregisterGameEvent, frame, CLEU)
	local directReg = QNS.RegisterGameEvent(frame, CLEU)
	Check("[BLOQ] journal fermé : ns.On / ns.Off et Register/UnregisterGameEvent n'appellent jamais le client",
		heard == false and okDirect and direct == false and directReg == false and #spy.calls == 0,
		tostring(heard) .. " " .. tostring(direct) .. " " .. tostring(directReg) .. " " .. table.concat(spy.calls, ","))
	-- un événement jamais abonné (IsEventRegistered faux) : pas de désabonnement
	local unregs = 0
	frame.IsEventRegistered = function() return false end
	frame.UnregisterEvent = function() unregs = unregs + 1 end
	local skipped = QNS.UnregisterGameEvent(frame, "PLAYER_MONEY") == false
	frame.IsEventRegistered = function() return true end
	local done = QNS.UnregisterGameEvent(frame, "PLAYER_MONEY") == true
	Check("[BLOQ] UnregisterGameEvent : seulement un événement abonné", skipped and done and unregs == 1)
	-- les hauts faits : entrée puis sortie de donjon, trois fois (cause de la 3.0.3)
	_G.IsInInstance = function() return Mock.world.instance == true, Mock.world.instance and "party" or "none" end
	_G.GetInstanceInfo = function() return "Donjon", Mock.world.instance and "party" or "none" end
	local zoneErr
	for _ = 1, 3 do
		Mock.world.instance = true
		local ok1, e1 = pcall(Mock.Fire, Mock, "PLAYER_ENTERING_WORLD", false, false)
		Mock.world.instance = false
		local ok2, e2 = pcall(Mock.Fire, Mock, "PLAYER_ENTERING_WORLD", false, false)
		local ok3, e3 = pcall(QNS.FeatJeuZone, QNS)
		zoneErr = zoneErr or (not ok1 and e1) or (not ok2 and e2) or (not ok3 and e3)
	end
	-- même chose par l'appel direct (au cas où le compagnon dort dans le harnais)
	Mock.world.instance = true; QNS:FeatJeuZone()
	Mock.world.instance = false; QNS:FeatJeuZone()
	Check("[BLOQ] sorties de donjon (journal fermé) : aucun appel au client sur le journal de combat",
		not zoneErr and #spy.calls == 0, tostring(zoneErr) .. " " .. table.concat(spy.calls, ","))
	for _, holder in ipairs(HOLDERS) do QNS.EventHold(holder, false) end
	Check("[BLOQ] journal fermé : les abonnés du chargement reprennent sans appel au client", #spy.calls == 0,
		table.concat(spy.calls, ","))
	-- journal ouvert : abonné au premier abonné, désabonné au dernier (inchangé)
	_G.C_CombatLog = { IsCombatLogRestricted = function() return false end }
	for _, holder in ipairs(HOLDERS) do QNS.EventHold(holder, true) end
	spy.calls = {}
	local other = {}
	QNS.On(CLEU, other, function() end, "test2:" .. CLEU)
	QNS.Off(CLEU, other)
	local calls = table.concat(spy.calls, ",")
	for _, holder in ipairs(HOLDERS) do QNS.EventHold(holder, false) end
	Check("[BLOQ] journal ouvert : abonnement puis désabonnement normaux", calls == "register,unregister", calls)
	_G.C_CombatLog = saved.C_CombatLog
	spy.Stop()
	Mock.world.instance = nil
	Restore()
end)

-- 2. Filtre CHAT_MSG_SYSTEM des échanges -----------------------------------
Block("filtre du chat", function()
	Say("-- action bloquée : filtre du chat des échanges, le temps utile")
	ResetWorld()
	QNS:TradeResetSession()
	QNS:TradeFilterSync()
	local filters = {}
	local function Count()
		local n = 0
		for _, fn in pairs(filters) do if fn then n = n + 1 end end
		return n
	end
	_G.ChatFrameUtil = {
		AddMessageEventFilter = function(event, fn) if event == "CHAT_MSG_SYSTEM" then filters[fn] = fn end end,
		RemoveMessageEventFilter = function(event, fn) if event == "CHAT_MSG_SYSTEM" then filters[fn] = nil end end,
	}
	_G.C_ChatInfo = { RegisterAddonMessagePrefix = function() return 0 end,
		SendAddonMessage = function() return 0 end, InChatMessagingLockdown = function() return false end }
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end end
	_G.GetNormalizedRealmName = function() return "Royaume" end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	local ok, err = pcall(function()
		QNS:TradeFilterSync()
		local idle = Count()
		QNS:TradeInvite("Deklatis-Royaume")
		local during = Count()
		Mock:Advance(1)
		local still = Count()
		QNS:TradeCancel()
		Mock:Advance(11); Mock:Advance(1); Mock:Advance(1)
		local after = Count()
		Check("[BLOQ] filtre CHAT_MSG_SYSTEM : aucun hors échange, un pendant, retiré ensuite",
			idle == 0 and during == 1 and still == 1 and after == 0, idle .. "/" .. during .. "/" .. still .. "/" .. after)
	end)
	if not ok then Check("[BLOQ] filtre CHAT_MSG_SYSTEM : aucun hors échange, un pendant, retiré ensuite", false, tostring(err)) end
	-- sans fonction de retrait : jamais posé
	QNS:TradeResetSession(); QNS:TradeFilterSet(false)
	_G.ChatFrameUtil = { AddMessageEventFilter = function(_, fn) filters[fn] = fn end }
	local okSet, posed = pcall(QNS.TradeFilterSet, QNS, true)
	Check("[BLOQ] filtre : jamais posé sans fonction de retrait", okSet and posed == false and Count() == 0)
	QNS:TradeResetSession()
	Restore()
end)

-- 3. Menus du clic droit : rien en instance ---------------------------------
Block("menus", function()
	Say("-- action bloquée : menus du clic droit en instance")
	ResetWorld()
	local function Root()
		local root = { writes = 0 }
		function root:CreateDivider() self.writes = self.writes + 1 end
		function root:CreateButton() self.writes = self.writes + 1 end
		return root
	end
	_G.GetNormalizedRealmName = function() return "Royaume" end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end end
	QNS:TrainerMarkHolder("Deklatis-Royaume")
	_G.IsInInstance = function() return true, "party" end
	local inside = Root()
	local addedIn = QNS:TrainerMenuAdd(inside, { name = "Deklatis", server = "Royaume" })
	_G.IsInInstance = function() return false, "none" end
	local outside = Root()
	local addedOut = QNS:TrainerMenuAdd(outside, { name = "Deklatis", server = "Royaume" })
	Check("[BLOQ] menu d'un joueur : rien d'écrit en instance, la fiche dehors",
		addedIn == false and inside.writes == 0 and addedOut == true and outside.writes >= 2,
		tostring(addedIn) .. "/" .. inside.writes .. "/" .. tostring(addedOut) .. "/" .. outside.writes)
	Restore()
end)

-- 4. Annonce automatique : verrou de la messagerie, écran de chargement -----
Block("annonce", function()
	Say("-- action bloquée : annonce automatique retenue")
	ResetWorld()
	local sends, locked = {}, true
	_G.SendChatMessage = function(text, channel) sends[#sends + 1] = { text = text, channel = channel } end
	_G.C_ChatInfo = { InChatMessagingLockdown = function() return locked end }
	_G.IsInGroup = function(category) return category == 1 end
	_G.IsInRaid = function() return false end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	QNS.announceQueue, QNS.announceLog, QNS.announceCut, QNS.announceLoadingUntil = {}, {}, nil, nil
	QNS:DB().announceGroup = true
	local item = { kind = "capture", name = "Raptor", shiny = true, stars = 1, key = "cap:bloq1" }
	QNS:AnnounceCaptures({ item })
	local heldLock = #sends == 0 and #QNS.announceQueue == 1
	locked = false
	Mock:Advance(3.5)
	local afterLock = #sends == 1 and #QNS.announceQueue == 0
	Check("[BLOQ] annonce : rien pendant le verrou de la messagerie, envoyée ensuite (même file)",
		heldLock and afterLock, #sends .. "/" .. #QNS.announceQueue)
	-- écran de chargement : rien jusqu'à 2 s après l'entrée en jeu
	Mock:Advance(31)
	Mock:Fire("PLAYER_LEAVING_WORLD")
	QNS:AnnounceCaptures({ { kind = "capture", name = "Loup", stars = 3, key = "cap:bloq2" } })
	local heldLoad = #sends == 1
	Mock:Fire("PLAYER_ENTERING_WORLD", false, false)
	Mock:Advance(1)
	local early = #sends == 1
	Mock:Advance(3)
	Check("[BLOQ] annonce : rien pendant un écran de chargement ni dans les 2 s, puis envoyée",
		heldLoad and early and #sends == 2, #sends)
	-- refus du jeu sur SendChatMessage : coupée pour la session
	QNS.actionSeen, QNS.actionChatDone = nil, nil
	Mock:Advance(31)
	Mock:Fire("ADDON_ACTION_FORBIDDEN", "QuestCompanion", "SendChatMessage()")
	QNS:AnnounceCaptures({ { kind = "capture", name = "Kodo", shiny = true, key = "cap:bloq3" } })
	Mock:Advance(4)
	Check("[BLOQ] annonce : coupée pour la session après un refus du jeu", QNS.announceCut == true and #sends == 2
		and #QNS.announceQueue == 0)
	QNS.announceQueue, QNS.announceLog, QNS.announceCut, QNS.announceLoadingUntil = {}, {}, nil, nil
	QNS.actionSeen, QNS.actionChatDone = nil, nil
	QNS:DB().actionLog = nil
	Restore()
end)

-- 5. Diagnostic --------------------------------------------------------------
Block("diagnostic", function()
	Say("-- action bloquée : diagnostic (ADDON_ACTION_FORBIDDEN / BLOCKED)")
	for _, case in ipairs({ { ns = QNS, addon = "QuestCompanion", other = "Ready2Quest", slash = "/qc" },
		{ ns = RNS, addon = "Ready2Quest", other = "QuestCompanion", slash = "/r2q" } }) do
		local NS = case.ns
		ResetWorld()
		NS.actionSeen, NS.actionChatDone = nil, nil
		NS:DB().actionLog = nil
		_G.IsInInstance = function() return true, "party" end
		_G.GetRealZoneText = function() return "Mortemines" end
		_G.InCombatLockdown = function() return false end
		_G.C_ChatInfo = { InChatMessagingLockdown = function() return true end }
		_G.date = function() return "2026-11-15 13:37:00" end
		-- un gestionnaire du cadre commun vient de tourner
		NS.On("ZONE_CHANGED_NEW_AREA", "test:bloq", function() end, "bloq:ZONE_CHANGED_NEW_AREA")
		Mock:Fire("ZONE_CHANGED_NEW_AREA")
		Mock:Reset()
		Mock:Fire("ADDON_ACTION_FORBIDDEN", case.addon, "UnregisterEvent()")
		Mock:Fire("ADDON_ACTION_FORBIDDEN", case.addon, "UnregisterEvent()")
		Mock:Fire("ADDON_ACTION_BLOCKED", case.addon, "SetRaidTarget()")
		Mock:Fire("ADDON_ACTION_FORBIDDEN", case.other, "CastSpellByName()")
		local log = NS:DB().actionLog or {}
		local first = log[1] or {}
		local recent = table.concat(first.recent or {}, ", ")
		local chat = Mock:Output()
		-- (l'autre addon, nommé par le dernier événement, écrit sa propre ligne)
		local _, chatLines = chat:gsub("%(UnregisterEvent%(%)%)", "")
		local _, blockedLines = chat:gsub("%(SetRaidTarget%(%)%)", "")
		chatLines = chatLines + blockedLines
		Check("[BLOQ] diagnostic " .. case.addon .. " : une entrée par fonction, lieu, combat, verrou, dernier gestionnaire",
			#log == 2 and first.fn == "UnregisterEvent()" and first.kind == "forbidden" and first.instance == "party"
			and first.zone == "Mortemines" and first.combat == nil and first.locked == true
			and first.at == "2026-11-15 13:37:00" and first.version == tostring(NS.version)
			and recent:find("ZONE_CHANGED_NEW_AREA", 1, true) ~= nil and log[2].kind == "blocked",
			#log .. " " .. tostring(first.fn) .. " " .. recent)
		Check("[BLOQ] diagnostic " .. case.addon .. " : une seule ligne dans le chat (fonction, " .. case.slash .. " diag, Discord)",
			chatLines == 1 and chat:find("UnregisterEvent()", 1, true) ~= nil and chat:find(case.slash .. " diag", 1, true) ~= nil
			and chat:find("Discord", 1, true) ~= nil, chatLines .. " " .. chat)
		Mock:Reset()
		NS:HandleCommand("diag")
		local diag = Mock:Output()
		Check("[BLOQ] /diag " .. case.addon .. " : les actions refusées listées",
			diag:find("actions refusées par le jeu : 2", 1, true) ~= nil and diag:find("UnregisterEvent()", 1, true) ~= nil
			and diag:find("SetRaidTarget()", 1, true) ~= nil and diag:find("en instance (party)", 1, true) ~= nil
			and diag:find("juste après", 1, true) ~= nil, diag)
		-- au plus ACTION_LOG_MAX entrées, les plus récentes
		for i = 1, 12 do Mock:Fire("ADDON_ACTION_FORBIDDEN", case.addon, "Fn" .. i .. "()") end
		log = NS:DB().actionLog
		Check("[BLOQ] diagnostic " .. case.addon .. " : " .. NS.ACTION_LOG_MAX .. " entrées au plus, les plus récentes",
			#log == NS.ACTION_LOG_MAX and log[#log].fn == "Fn12()")
		NS.Off("ZONE_CHANGED_NEW_AREA", "test:bloq")
		NS.actionSeen, NS.actionChatDone = nil, nil
		NS:DB().actionLog = nil
	end
	Restore()
	Mock:Reset()
end)
