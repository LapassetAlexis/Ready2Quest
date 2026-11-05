-- Dungeon.lua -- module « Avant le donjon » (v1.23.0)
--
-- À l'arrivée devant un donjon (sous-zone d'entrée) ou en y entrant, une fiche
-- courte pour CE donjon : ses quêtes dans le journal, le niveau du joueur face
-- à la fourchette du donjon, les plans avancés connus (Forever) et une
-- préparation tirée des contrôles existants (durabilité, réparation, vivres,
-- potions, foyer), sans ouvrir la fenêtre du Check avant le départ.
-- Une seule fiche par visite : les allers-retours de sous-zone à l'entrée ne
-- la rouvrent pas (voir EvaluateDungeon).
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

-- Délai sans être au donjon après lequel un retour compte comme une nouvelle
-- visite. Assez long pour couvrir une course de fantôme après un wipe ou un
-- passage au marchand de l'entrée, assez court pour la sortie du lendemain.
local REVISIT_GAP = 900
-- À l'entrée seulement : on ne montre la fiche qu'à un joueur qui a le
-- niveau, ou presque. Les Ruines de Lordaeron sont au-dessus de Fossoyeuse :
-- un Horde de niveau 5 ou 60 y passe sans viser le donjon.
local ENTRANCE_MARGIN = 3
local MAX_QUESTS = 8
-- Contrôles du Check avant le départ repris dans la fiche (même code, mêmes réglages)
local READY_CHECKS = { "durability", "repair", "vivres", "potions", "hearth" }

-- ---------------------------------------------------------------------------
-- Textes (tutoiement, courts)
-- ---------------------------------------------------------------------------
local FR = {
	OPT_PAGE_DUNGEON = "Avant le donjon",
	OPT_PAGE_DUNGEON_SUB = "Devant un donjon : ses quêtes dans ton journal, ton niveau face au sien et ta préparation.",
	OPT_DUNGEON_WINDOW = "Fiche en fenêtre (sinon dans le chat)",
	OPT_DUNGEON_ENTRANCE = "Aussi à l'entrée, pas seulement dedans",
	DGN_TITLE = "Avant le donjon",
	DGN_LEVEL_OK = "Niveaux %d-%d · toi %d : c'est ton niveau",
	DGN_LEVEL_LOW = "Niveaux %d-%d · toi %d : trop bas de %d niv.",
	DGN_LEVEL_GREY = "Niveaux %d-%d · toi %d : donjon gris pour toi",
	DGN_QUESTS = "QUÊTES DANS TON JOURNAL (%d)",
	DGN_QUESTS_NONE = "Aucune quête de ce donjon dans ton journal.",
	DGN_QUESTS_COLLAPSED = "Section repliée dans ton journal : déplie-la pour voir ses quêtes.",
	DGN_QUEST_READY = "à rendre",
	DGN_MORE = "+%d autres",
	DGN_BLUEPRINTS = "PLANS AVANCÉS POUR TES MÉTIERS",
	DGN_PREP = "PRÉPARATION",
	DGN_PREP_NONE = "Aucun contrôle actif.",
	DGN_CHAT_HEAD = "Avant le donjon : %s — %s",
	DGN_CHAT_QUESTS = "Quêtes : %s",
	DGN_CHAT_PREP_OK = "Préparation : tout est bon.",
	DGN_CHAT_PREP_BAD = "À voir : %s",
	DGN_CHAT_BLUEPRINTS = "Plans avancés : %s",
}
local EN = {
	OPT_PAGE_DUNGEON = "Before the dungeon",
	OPT_PAGE_DUNGEON_SUB = "At a dungeon: its quests in your log, your level against its range, and your readiness.",
	OPT_DUNGEON_WINDOW = "Sheet in a window (otherwise in chat)",
	OPT_DUNGEON_ENTRANCE = "Also at the entrance, not only inside",
	DGN_TITLE = "Before the dungeon",
	DGN_LEVEL_OK = "Levels %d-%d · you %d: right for you",
	DGN_LEVEL_LOW = "Levels %d-%d · you %d: %d level(s) too low",
	DGN_LEVEL_GREY = "Levels %d-%d · you %d: grey for you",
	DGN_QUESTS = "QUESTS IN YOUR LOG (%d)",
	DGN_QUESTS_NONE = "No quest for this dungeon in your log.",
	DGN_QUESTS_COLLAPSED = "Section collapsed in your log: expand it to see its quests.",
	DGN_QUEST_READY = "ready to turn in",
	DGN_MORE = "+%d more",
	DGN_BLUEPRINTS = "ADVANCED BLUEPRINTS FOR YOUR PROFESSIONS",
	DGN_PREP = "READINESS",
	DGN_PREP_NONE = "No active check.",
	DGN_CHAT_HEAD = "Before the dungeon: %s — %s",
	DGN_CHAT_QUESTS = "Quests: %s",
	DGN_CHAT_PREP_OK = "Readiness: all good.",
	DGN_CHAT_PREP_BAD = "Check: %s",
	DGN_CHAT_BLUEPRINTS = "Advanced Blueprints: %s",
}
ns.RegisterStrings(FR, EN)
ns.DUNGEON_STRINGS = { fr = FR, en = EN }   -- exposé aux tests (parité fr/en)

ns.RegisterDefaults({
	dungeonEnabled    = true,   -- module « Avant le donjon »
	dungeonShowWindow = true,   -- false = fiche dans le chat
	dungeonAtEntrance = true,   -- false = seulement en entrant dans l'instance
	dungeonPoint      = { point = "CENTER", x = 0, y = 60 },
})

ns.RegisterModule({ id = "dungeon", key = "dungeonEnabled", label = "OPT_PAGE_DUNGEON", aliases = { "donjon", "dungeon", "instance" } })
ns.AddOptionPage({
	id = "dungeon", title = "OPT_PAGE_DUNGEON", group = "OPT_GROUP_MODULES", power = "dungeonEnabled",
	rows = {
		{ key = "dungeonShowWindow", label = "OPT_DUNGEON_WINDOW",   kind = "bool" },
		{ key = "dungeonAtEntrance", label = "OPT_DUNGEON_ENTRANCE", kind = "bool" },
	},
})

-- ---------------------------------------------------------------------------
-- Index des donjons : par mapID d'instance, par nom, par sous-zone d'entrée.
-- Les noms sont ceux du jeu (C_Map.GetAreaInfo), donc valables dans toutes
-- les langues ; le nom anglais de DungeonData sert de repli.
-- ---------------------------------------------------------------------------
-- Index des donjons, détection (ns:DetectDungeon), nom, fourchette et
-- ns:IsForeverClient : socle commun, Libs/Socle/World.lua.
local Normalize = ns.DungeonNormalize
local AreaName = ns.AreaName

local function PlayerLevel()
	if type(UnitLevel) ~= "function" then return nil end
	local ok, level = pcall(UnitLevel, "player")
	return ok and tonumber(level) or nil
end

-- "low" (trop bas), "ok", "grey" (au-dessus de la fourchette), ou nil sans donnée
function ns:DungeonVerdict(entry, level)
	local minLevel, maxLevel = self:DungeonRange(entry)
	level = level or PlayerLevel()
	if not minLevel or not level then return nil end
	if level < minLevel then return "low", minLevel, maxLevel, level end
	if level > maxLevel then return "grey", minLevel, maxLevel, level end
	return "ok", minLevel, maxLevel, level
end


-- ---------------------------------------------------------------------------
-- Quêtes du journal rangées sous l'en-tête du donjon. Le journal Classic
-- groupe les quêtes de donjon sous un en-tête au nom du donjon : c'est la
-- seule source fiable (aucune table client ne relie une quête à un donjon).
-- ---------------------------------------------------------------------------
local function NamespacedRows()
	local rows, headers = {}, 0
	if not (C_QuestLog and type(C_QuestLog.GetNumQuestLogEntries) == "function" and type(C_QuestLog.GetInfo) == "function") then
		return rows, 0
	end
	local ok, total = pcall(C_QuestLog.GetNumQuestLogEntries)
	if not ok or type(total) ~= "number" then return rows, 0 end
	for i = 1, total do
		local okInfo, info = pcall(C_QuestLog.GetInfo, i)
		if okInfo and type(info) == "table" and type(info.title) == "string" then
			local row = { title = info.title, header = info.isHeader == true, collapsed = info.isCollapsed == true }
			if row.header then
				headers = headers + 1
			elseif info.questID and type(C_QuestLog.ReadyForTurnIn) == "function" then
				local okReady, isReady = pcall(C_QuestLog.ReadyForTurnIn, info.questID)
				row.ready = okReady and isReady == true
			else
				row.ready = info.isComplete == true or info.isComplete == 1
			end
			rows[#rows + 1] = row
		end
	end
	return rows, headers
end

function ns:QuestLogRows()
	return (NamespacedRows())
end

-- Renvoie { {title, ready}, … }, et true si l'en-tête du donjon est replié
function ns:DungeonQuests(entry, instanceName)
	local names = {}
	for _, name in ipairs({ AreaName(entry.area) or false, entry.name or false, instanceName or false }) do
		local n = name and Normalize(name)
		if n then names[n] = true end
	end
	local quests, collapsed, inside = {}, false, false
	for _, row in ipairs(self:QuestLogRows()) do
		if row.header then
			inside = names[Normalize(row.title) or ""] == true
			if inside and row.collapsed then collapsed = true end
		elseif inside then
			quests[#quests + 1] = { title = row.title, ready = row.ready == true }
		end
	end
	return quests, collapsed
end

-- ---------------------------------------------------------------------------
-- Plans avancés (Forever) : seulement ceux des métiers du joueur
-- ---------------------------------------------------------------------------
local PROFESSION_NAMES = {
	BS = { "blacksmithing", "forge" },
	LW = { "leatherworking", "travail du cuir" },
	TL = { "tailoring", "couture" },
	EN = { "engineering", "ingénierie" },
	AL = { "alchemy", "alchimie" },
	EC = { "enchanting", "enchantement" },
}

function ns:PlayerProfessions()
	local known = {}
	if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then return known end
	local ok, total = pcall(GetNumSkillLines)
	if not ok or type(total) ~= "number" then return known end
	for i = 1, total do
		local okLine, name = pcall(GetSkillLineInfo, i)
		local n = okLine and Normalize(name)
		if n then
			for code, names in pairs(PROFESSION_NAMES) do
				for _, candidate in ipairs(names) do
					if candidate == n then known[code] = true end
				end
			end
		end
	end
	return known
end

function ns:DungeonBlueprints(entry)
	local list = (self.DUNGEON_BLUEPRINTS or {})[entry.key]
	if not list or #list == 0 then return {} end
	local known, out = self:PlayerProfessions(), {}
	for _, item in ipairs(list) do
		if known[item.prof] then out[#out + 1] = item end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Préparation : les contrôles du Check avant le départ, lus un par un. Un
-- contrôle coupé par le joueur ou sans objet (réparation jamais mesurée) est
-- absent, comme dans le Check.
-- ---------------------------------------------------------------------------
function ns:DungeonReadiness()
	local db, lines = self:DB(), {}
	for _, id in ipairs(READY_CHECKS) do
		local def = self.FindCheck and self:FindCheck(id)
		if def and self:IsModuleEnabled(id) then
			local active = true
			if def.active then
				local okActive, res = pcall(def.active, db)
				active = okActive and res == true
			end
			if active then
				local okRun, okState, detail = pcall(def.run, db)
				if okRun then
					local label = def.label
					if type(label) == "function" then label = label() end
					lines[#lines + 1] = { id = id, label = tostring(label or id), ok = okState == true, detail = tostring(detail or "") }
				elseif self.RecordError then
					self:RecordError("dungeon:" .. id, okState)
				end
			end
		end
	end
	return lines
end

-- ---------------------------------------------------------------------------
-- Fiche
-- ---------------------------------------------------------------------------
function ns:LevelText(sheet)
	local v = sheet.verdict
	if v == "ok" then return Theme.T_GREEN .. self:F("DGN_LEVEL_OK", sheet.min, sheet.max, sheet.level) .. "|r" end
	if v == "low" then return Theme.T_RED .. self:F("DGN_LEVEL_LOW", sheet.min, sheet.max, sheet.level, sheet.min - sheet.level) .. "|r" end
	if v == "grey" then return Theme.T_GREY .. self:F("DGN_LEVEL_GREY", sheet.min, sheet.max, sheet.level) .. "|r" end
	return ""
end

function ns:BuildDungeonSheet(entry, how, instanceName)
	local verdict, minLevel, maxLevel, level = self:DungeonVerdict(entry)
	local quests, collapsed = self:DungeonQuests(entry, instanceName)
	return {
		key = entry.key, name = self:DungeonName(entry, instanceName), how = how,
		verdict = verdict, min = minLevel, max = maxLevel, level = level,
		quests = quests, collapsed = collapsed,
		blueprints = self:DungeonBlueprints(entry),
		readiness = self:DungeonReadiness(),
	}
end

-- À l'entrée, la fiche n'a de sens que pour un joueur qui a le niveau (ou presque)
local function WorthAtEntrance(sheet)
	if sheet.verdict == "ok" or sheet.verdict == nil then return true end
	if sheet.verdict == "low" then return sheet.level >= sheet.min - ENTRANCE_MARGIN end
	return false
end

-- Appelé à chaque changement de zone. Une visite = un donjon ; elle se
-- termine quand le joueur est resté loin du donjon plus de REVISIT_GAP s (ou
-- en arrive à un autre). Entrée -> instance -> entrée : une seule fiche.
function ns:EvaluateDungeon()
	local db = self:DB()
	if db.enabled == false or db.dungeonEnabled == false then return end
	-- fantôme qui court vers l'entrée : ni fiche, ni fin de visite
	if type(UnitIsDeadOrGhost) == "function" then
		local okDead, dead = pcall(UnitIsDeadOrGhost, "player")
		if okDead and dead then return end
	end
	local now = ns.Now()
	local entry, how, instanceName = self:DetectDungeon()
	if entry and how == "entrance" and db.dungeonAtEntrance == false then entry = nil end
	local visit = self.dungeonVisit
	if not entry then
		if visit and not visit.left then visit.left = now end
		return
	end
	if visit and visit.key == entry.key and (not visit.left or now - visit.left <= REVISIT_GAP) then
		visit.left = nil
		return
	end
	local sheet = self:BuildDungeonSheet(entry, how, instanceName)
	if how == "entrance" and not WorthAtEntrance(sheet) then return end
	self.dungeonVisit = { key = entry.key, at = now }
	self:ShowDungeonSheet(sheet)
end

function ns:ShowDungeonSheet(sheet)
	self.lastDungeonSheet = sheet
	if self:DB().dungeonShowWindow ~= false and self.ShowDungeonWindow and self.WantsNotice and self:WantsNotice() then
		-- une icône annonce la fiche (Notice.lua), une ligne dans le chat
		local notice = self:NoticeDungeon(sheet)
		notice.onClick = function() ns:ShowDungeonWindow(sheet) end
		self:ShowNotice(notice)
		self:Print(self:F("NOTICE_CHAT_DUNGEON", Theme.T_GOLD .. tostring(sheet.name) .. "|r"))
		return
	end
	if self:DB().dungeonShowWindow ~= false and self.ShowDungeonWindow and self:ShowDungeonWindow(sheet) then return end
	self:PrintDungeonSheet(sheet)
end

local function QuestText(quest)
	if quest.ready then return quest.title .. " (" .. L.DGN_QUEST_READY .. ")" end
	return quest.title
end

function ns:PrintDungeonSheet(sheet)
	self:Print(self:F("DGN_CHAT_HEAD", Theme.T_GOLD .. tostring(sheet.name) .. "|r", self:LevelText(sheet)))
	if #sheet.quests > 0 then
		local parts = {}
		for i = 1, math.min(#sheet.quests, MAX_QUESTS) do parts[#parts + 1] = QuestText(sheet.quests[i]) end
		if #sheet.quests > MAX_QUESTS then parts[#parts + 1] = self:F("DGN_MORE", #sheet.quests - MAX_QUESTS) end
		self:Print("  " .. self:F("DGN_CHAT_QUESTS", table.concat(parts, ", ")))
	elseif sheet.collapsed then
		self:Print("  " .. L.DGN_QUESTS_COLLAPSED)
	else
		self:Print("  " .. Theme.T_GREY .. L.DGN_QUESTS_NONE .. "|r")
	end
	if #sheet.blueprints > 0 then
		local parts = {}
		for _, item in ipairs(sheet.blueprints) do parts[#parts + 1] = item.name end
		self:Print("  " .. self:F("DGN_CHAT_BLUEPRINTS", table.concat(parts, ", ")))
	end
	local bad = {}
	for _, line in ipairs(sheet.readiness) do
		if not line.ok then bad[#bad + 1] = line.label .. " (" .. line.detail .. ")" end
	end
	if #bad > 0 then
		self:Print("  " .. Theme.T_ORANGE .. self:F("DGN_CHAT_PREP_BAD", table.concat(bad, ", ")) .. "|r")
	else
		self:Print("  " .. Theme.T_GREEN .. L.DGN_CHAT_PREP_OK .. "|r")
	end
end

-- ---------------------------------------------------------------------------
-- Fenêtre de module (Theme.CreateDialog) : le niveau en tête, puis des
-- sections (quêtes, plans, préparation) aux lignes en cartes, losange de
-- statut à gauche. Lignes recyclées. Renvoie false si l'interface n'a pas pu
-- être construite : la fiche part alors dans le chat plutôt que de se perdre.
-- ---------------------------------------------------------------------------
local WIDTH = 420
local ROW_CARD, ROW_STEP = 22, 24     -- carte, pas d'une ligne à l'autre
local HEAD_STEP = 28                  -- titre de section (avec son espace au-dessus)
local GAP = 14

local function Line(frame, index)
	frame.lines = frame.lines or {}
	local line = frame.lines[index]
	if line then return line end
	line = Theme.CreateListRow(frame, frame.innerWidth, ROW_CARD, { status = 8 })
	line.text:SetWidth(frame.innerWidth - line.textLeft - 12)
	frame.lines[index] = line
	return line
end

-- kind : "level" (le niveau, en tête), "head" (titre de section), "row"
-- (carte, avec ou sans losange), "note" (texte pâle, sans carte)
local function Style(line, kind, rank)
	line.kind = kind
	local x = (kind == "head" and 0) or ((kind == "row" and line.status.state ~= "none") and line.textLeft) or 12
	line.text:ClearAllPoints()
	line.text:SetPoint("LEFT", line, "LEFT", x, kind == "head" and -4 or 0)
	line.text:SetFontObject((kind == "head" and Theme.F_CAPS) or (kind == "level" and Theme.F_LABEL) or Theme.F_BODY)
	local color = (kind == "head" and Theme.MUTED_LIGHT) or (kind == "note" and Theme.MUTED) or Theme.TEXT
	line.text:SetTextColor(color[1], color[2], color[3])
	if kind == "head" or kind == "note" then line.bg:Hide() else line.bg:Show() end
	line:SetIndex(rank or 1)
end

function ns:EnsureDungeonWindow()
	if self.dungeonFrame then return self.dungeonFrame end
	if not (Theme and Theme.CreateDialog) then return nil end
	local frame = Theme.CreateDialog(UIParent, WIDTH, 200, { name = "Ready2QuestDungeonFrame", title = L.DGN_TITLE })
	if not frame then return nil end
	if self.RestorePoint then self:RestorePoint(frame, "dungeonPoint", { point = "CENTER", x = 0, y = 60 }) end
	frame.closeButton = frame:AddFooterButton(L.OPT_CLOSE, function() frame:Hide() end, "accent")
	self.dungeonFrame = frame
	return frame
end

function ns:ShowDungeonWindow(sheet)
	local ok, frame = pcall(self.EnsureDungeonWindow, self)
	if not ok or not frame then
		if not ok and self.RecordError then self:RecordError("dungeon:window", frame) end
		return false
	end
	local rows = {}
	local function Add(text, state, kind) rows[#rows + 1] = { text = text, state = state or "none", kind = kind or "row" } end
	Add(self:LevelText(sheet), nil, "level")
	Add(self:F("DGN_QUESTS", #sheet.quests), nil, "head")
	for i = 1, math.min(#sheet.quests, MAX_QUESTS) do
		local quest = sheet.quests[i]
		Add(quest.ready and (quest.title .. "  " .. Theme.T_GREEN .. L.DGN_QUEST_READY .. "|r") or quest.title, quest.ready and "ok" or "item")
	end
	if #sheet.quests > MAX_QUESTS then Add(self:F("DGN_MORE", #sheet.quests - MAX_QUESTS), nil, "note") end
	if #sheet.quests == 0 then
		Add(sheet.collapsed and L.DGN_QUESTS_COLLAPSED or L.DGN_QUESTS_NONE, nil, "note")
	end
	if #sheet.blueprints > 0 then
		Add(L.DGN_BLUEPRINTS, nil, "head")
		for _, item in ipairs(sheet.blueprints) do Add(tostring(item.name), "item") end
	end
	Add(L.DGN_PREP, nil, "head")
	for _, line in ipairs(sheet.readiness) do
		Add(line.label .. "  " .. Theme.T_GREY .. line.detail .. "|r", line.ok and "ok" or "bad")
	end
	if #sheet.readiness == 0 then Add(L.DGN_PREP_NONE, nil, "note") end

	frame.subtitle:SetText(tostring(sheet.name))
	local y = (frame.contentTop or -65) - GAP
	local rank = 0
	for index, row in ipairs(rows) do
		local line = Line(frame, index)
		if row.kind == "head" then
			y = y - (HEAD_STEP - ROW_STEP)
			rank = 0
		elseif row.kind == "row" then
			rank = rank + 1
		end
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", frame, "TOPLEFT", frame.pad + 1, y)
		line.text:SetText(row.kind == "head" and Theme.Upper(row.text) or row.text)
		Theme.SetStatus(line.status, row.state)
		Style(line, row.kind, rank)
		line:Show()
		y = y - ROW_STEP
	end
	for index = #rows + 1, #(frame.lines or {}) do
		frame.lines[index].text:SetText("")
		frame.lines[index]:Hide()
	end
	frame.visibleLines = #rows
	frame:SetHeight(-y + (ROW_STEP - ROW_CARD) + GAP + Theme.DIALOG_FOOTER)
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	return true
end

-- ---------------------------------------------------------------------------
-- Événements : cadre propre, enregistrement défensif (un événement inconnu
-- d'un client ne doit pas empêcher les autres)
-- ---------------------------------------------------------------------------
local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
	pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
	local ok, err = pcall(ns.EvaluateDungeon, ns)
	if not ok and ns.RecordError then ns:RecordError("dungeon:" .. tostring(event), err) end
	-- au chargement d'une instance, GetInstanceInfo peut répondre un peu tard :
	-- second passage (sans effet si la fiche est déjà sortie pour cette visite)
	if event == "PLAYER_ENTERING_WORLD" and C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(2, function() pcall(ns.EvaluateDungeon, ns) end)
	end
end)
ns.dungeonEvents = events

if ns.Mark then ns.Mark("Dungeon") end
