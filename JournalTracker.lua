-- JournalTracker.lua -- objectifs du « Carnet de voyage » et suivi à l'écran (v1.25.0)
--
-- Retour joueur : « je ne sais pas ce qui me reste à faire ». Le carnet
-- montre ce qui est GAGNÉ ; ce fichier calcule ce qui est PROCHE et l'affiche
-- dans un petit cadre « Carnet », dans l'esprit du suivi de quêtes.
--
-- Pourquoi un cadre à nous plutôt que des lignes dans le suivi de Blizzard :
-- QuestWatchFrame (Era) et ObjectiveTrackerFrame (Forever, client moderne) ne
-- se ressemblent pas, et Questie ou d'autres addons les remplacent souvent.
-- Écrire dedans casserait au premier changement ; se poser JUSTE EN DESSOUS
-- donne le même confort sans dépendre de leur fonctionnement interne.
--
-- Sources d'objectifs (3 à 5 affichés, le plus proche du but d'abord) :
--   * Compagnon de route : ns:CompanionNextUnlocks() (contrat avec
--     Companion.lua) -> liste de { label, kind = "app"|"orn"|"stage",
--     stat = "zone"|"subzone"|"dungeon"|"rare"|"level"|"total", have, need } ;
--     fonction absente : aucune ligne de cette source, rien d'inventé ;
--   * villages de la zone courante encore sans tampon (faction filtrée comme
--     au carnet) ;
--   * capitales (x / 6) ;
--   * donjons de ton niveau (plages de DungeonData.lua) ;
--   * prochain palier de niveau.
-- Chaque objectif se masque d'un clic droit (par personnage) ; la liste se
-- recalcule à chaque tampon, changement de zone et montée de niveau.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local TRACKER_MAX = 5
local TRACKER_WIDTH, TITLE_H, LINE_H = 240, 18, 15
-- Ordre d'essai : Era d'abord (QuestWatchFrame), puis le client moderne de
-- Forever (le cadre global, puis le seul bloc des quêtes)
local BLIZZARD_TRACKERS = { "QuestWatchFrame", "ObjectiveTrackerFrame", "QuestObjectiveTracker" }
-- Sans suivi de Blizzard : à droite, sous la minicarte, là où on cherche un suivi
local FALLBACK = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -90, y = -260 }

-- ---------------------------------------------------------------------------
-- Chaînes, réglages
-- ---------------------------------------------------------------------------
local FR = {
	OPT_JRN_TRACKER        = "Suivi à l'écran",
	OPT_JRN_TRACKER_COMBAT = "Masquer en combat",
	OPT_JRN_TRACKER_RESET  = "Réinitialiser la position du suivi",
	JRN_TRK_TITLE          = "Carnet",
	JRN_TRK_TITLE_COUNT    = "Carnet (%d)",
	JRN_TRK_RESET          = "Suivi du carnet remis à sa place.",
	JRN_GOAL_UNLOCK        = "%s — %s",
	JRN_GOAL_VILLAGES      = "Villages de %s",
	JRN_GOAL_CAPITALS      = "Capitales",
	JRN_GOAL_DUNGEONS      = "Donjons de ton niveau : %s",
	JRN_GOAL_LEVEL         = "Palier %d : niveau",
	JRN_STAT_zone          = "zones",
	JRN_STAT_subzone       = "villages",
	JRN_STAT_capital       = "capitales",
	JRN_STAT_dungeon       = "donjons",
	JRN_STAT_rare          = "rares",
	JRN_STAT_level         = "niveau",
	JRN_STAT_total         = "tampons",
}
local EN = {
	OPT_JRN_TRACKER        = "On-screen tracker",
	OPT_JRN_TRACKER_COMBAT = "Hide in combat",
	OPT_JRN_TRACKER_RESET  = "Reset the tracker position",
	JRN_TRK_TITLE          = "Journal",
	JRN_TRK_TITLE_COUNT    = "Journal (%d)",
	JRN_TRK_RESET          = "Journal tracker moved back to its place.",
	JRN_GOAL_UNLOCK        = "%s — %s",
	JRN_GOAL_VILLAGES      = "Villages of %s",
	JRN_GOAL_CAPITALS      = "Capitals",
	JRN_GOAL_DUNGEONS      = "Dungeons for your level: %s",
	JRN_GOAL_LEVEL         = "Milestone %d: level",
	JRN_STAT_zone          = "zones",
	JRN_STAT_subzone       = "villages",
	JRN_STAT_capital       = "capitals",
	JRN_STAT_dungeon       = "dungeons",
	JRN_STAT_rare          = "rares",
	JRN_STAT_level         = "level",
	JRN_STAT_total         = "stamps",
}
ns.RegisterStrings(FR, EN)
ns.JOURNAL_TRACKER_STRINGS = { fr = FR, en = EN }

ns.RegisterDefaults({
	journalTracker       = true,
	-- en combat, le regard est sur le combat : le suivi s'efface et revient après
	journalTrackerCombat = true,
})

-- ---------------------------------------------------------------------------
-- Village -> zone (uiMapID de type « Zone », mêmes numéros sur Era et Forever)
-- ---------------------------------------------------------------------------
-- Hubs.lua (généré) ne dit pas dans quelle zone est un village, et le client
-- n'a pas d'API areaID -> carte. Table posée à la main pour les villages et
-- hubs de la base ; les lieux propres à Forever (absents ici) s'apprennent en
-- passant (LearnHubZone), le premier passage suffit.
local HUB_ZONE = {
	-- Alliance
	[348] = 1425, [415] = 1440, [442] = 1439, [3197] = 1422, [42] = 1431, [16134] = 1431, [16161] = 1431,
	[186] = 1438, [1116] = 1444, [87] = 1429, [16524] = 1429, [131] = 1426, [69] = 1433, [150] = 1437,
	[2418] = 1428, [1438] = 1419, [608] = 1443, [320] = 1417, [702] = 1438, [108] = 1436, [271] = 1424,
	[2369] = 1424, [467] = 1442, [3137] = 1447, [16016] = 1447, [489] = 1444, [144] = 1432, [513] = 1445,
	-- Horde
	[222] = 1412, [496] = 1445, [159] = 1420, [1099] = 1444, [378] = 1413, [251] = 1428, [484] = 1441,
	[117] = 1434, [321] = 1417, [340] = 1418, [362] = 1411, [3317] = 1425, [2408] = 1443, [431] = 1440,
	[75] = 1435, [460] = 1442, [272] = 1424, [2368] = 1424, [380] = 1413, [228] = 1421, [1237] = 1447,
	[2897] = 1440,
	-- neutres
	[35] = 1434, [3425] = 1451, [2255] = 1452, [976] = 1446, [2268] = 1423, [541] = 1449, [2240] = 1441,
	[2361] = 1450, [392] = 1413, [977] = 1446, [1446] = 1427,
}
ns.JOURNAL_HUB_ZONE = HUB_ZONE

-- ---------------------------------------------------------------------------
-- Accès robustes
-- ---------------------------------------------------------------------------
local function Call(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e = pcall(fn, ...)
	if ok then return a, b, c, d, e end
	return nil
end

local function ModuleOn()
	local db = ns:DB()
	-- un seul interrupteur pour le Compagnon et son carnet (v1.25.0)
	return db.enabled ~= false and db.companionEnabled ~= false
end

-- PLAYER_LEVEL_UP arrive parfois avant que UnitLevel ne suive : le niveau
-- annoncé par l'événement vaut pendant son seul traitement (posé puis effacé)
local function Level()
	local level = tonumber(Call("UnitLevel", "player")) or 0
	local hint = tonumber(ns.journalLevelHint)
	if hint and hint > level then level = hint end
	return level
end

-- PLAYER_REGEN_DISABLED précède le verrouillage : le drapeau posé par
-- l'événement fait foi, InCombatLockdown en secours (/reload en combat)
local function InCombat()
	return ns.journalTrackerCombat == true or Call("InCombatLockdown") == true
end

function ns:JournalHubZone(areaID)
	if not areaID then return nil end
	local learned = self:DB().journalHubZones
	return HUB_ZONE[areaID] or (type(learned) == "table" and learned[areaID]) or nil
end

-- Un village visité dont la zone n'est pas dans la table : on la retient
-- (sauvegarde du compte : la géographie est la même pour tous tes personnages)
function ns:LearnHubZone()
	if self:InInstance() then return end
	local subzone = self:CurrentSubZone()
	local group = subzone and self:JournalHubGroups()[subzone]
	if not group or not group.areaID or HUB_ZONE[group.areaID] then return end
	if group.kind ~= "town" and group.kind ~= "hub" then return end
	local zoneID = self:JournalZone()
	if not zoneID then return end
	local db = self:DB()
	if type(db.journalHubZones) ~= "table" then db.journalHubZones = {} end
	db.journalHubZones[group.areaID] = zoneID
end

-- ---------------------------------------------------------------------------
-- Objectifs
-- ---------------------------------------------------------------------------
-- Un objectif atteint (have >= need) n'en est plus un : il disparaît.
-- `ratio` sert au tri et à la barre ; par défaut have / need.
local function Goal(id, label, have, need, ratio, source)
	have, need = tonumber(have), tonumber(need)
	if not have or not need or need <= 0 or have >= need then return nil end
	if have < 0 then have = 0 end
	return {
		id = id, label = label, have = have, need = need, source = source,
		ratio = ratio or (have / need), progress = string.format("%d/%d", have, need),
	}
end
ns.JournalGoal = Goal

-- Compagnon : le contrat seul, rien de recalculé ici (les seuils vivent dans
-- CompanionData.lua et peuvent changer sans que ce fichier le sache)
local function CompanionGoals(self, list)
	local fn = self.CompanionNextUnlocks
	if type(fn) ~= "function" then return end
	local ok, unlocks = pcall(fn, self)
	if not ok or type(unlocks) ~= "table" then return end
	for _, unlock in ipairs(unlocks) do
		if type(unlock) == "table" and type(unlock.label) == "string" and unlock.label ~= "" then
			local stat = L["JRN_STAT_" .. tostring(unlock.stat)] or tostring(unlock.stat or "")
			local goal = Goal("comp:" .. tostring(unlock.kind) .. ":" .. unlock.label,
				self:F("JRN_GOAL_UNLOCK", unlock.label, stat), unlock.have, unlock.need, nil, "companion")
			if goal then goal.kind = unlock.kind; list[#list + 1] = goal end
		end
	end
end

-- Villages de la zone où tu es, amis ou neutres, connus de ce client
local function VillageGoals(self, list)
	local zoneID, zoneName = self:JournalZone()
	if not zoneID then return end
	local faction, stamps = self:PlayerFaction(), self:JournalData().stamps
	local have, need = 0, 0
	for _, group in pairs(self:JournalHubGroups()) do
		if group.exists and self:JournalIsVillage(group, faction) and self:JournalHubZone(group.areaID) == zoneID then
			need = need + 1
			if stamps["subzone:" .. group.areaID] then have = have + 1 end
		end
	end
	local goal = Goal("villages:" .. zoneID, self:F("JRN_GOAL_VILLAGES", tostring(zoneName or "?")), have, need, nil, "journal")
	if goal then list[#list + 1] = goal end
end

local function CapitalGoals(self, list)
	local missing = self:JournalMissing("capital") or {}
	local have = self:JournalCounts().capital or 0
	local goal = Goal("capitals", L.JRN_GOAL_CAPITALS, have, have + #missing, nil, "journal")
	if goal then list[#list + 1] = goal end
end

-- Donjons dont la plage (Era ou Forever) contient ton niveau. L'identifiant
-- suit la plage, pas les tampons : un objectif masqué reste masqué quand tu
-- en finis un, et revient quand de nouveaux donjons entrent dans ta tranche.
local function DungeonGoals(self, list)
	local level = Level()
	if level <= 0 or not self.DungeonRange then return end
	local forever = self.IsForeverClient and self:IsForeverClient()
	local stamps, inRange, missing, have = self:JournalData().stamps, {}, {}, 0
	for key, entry in pairs(self.DUNGEONS or {}) do
		if not entry.forever or forever then
			local low, high = self:DungeonRange(entry)
			if low and high and level >= low and level <= high then
				inRange[#inRange + 1] = key
				if stamps["dungeon:" .. key] then
					have = have + 1
				else
					missing[#missing + 1] = { low = low, name = self.DungeonName and self:DungeonName(entry) or entry.name or key }
				end
			end
		end
	end
	if #inRange == 0 then return end
	table.sort(inRange)
	table.sort(missing, function(a, b)
		if a.low ~= b.low then return a.low < b.low end
		return a.name < b.name
	end)
	local names = {}
	for _, entry in ipairs(missing) do names[#names + 1] = entry.name end
	local goal = Goal("dungeons:" .. table.concat(inRange, ","),
		self:F("JRN_GOAL_DUNGEONS", table.concat(names, ", ")), have, #inRange, nil, "journal")
	if goal then list[#list + 1] = goal end
end

-- Prochain palier : affiché « niveau 27/30 », mais trié sur l'avancée dans la
-- tranche (27 sur 20 -> 30 = 70 %), sinon il serait toujours en tête
local function LevelGoals(self, list)
	local level = Level()
	if level <= 0 then return end
	local milestones = ns.JOURNAL_MILESTONES or { 10, 20, 30, 40, 50, 60 }
	for index, milestone in ipairs(milestones) do
		if level < milestone then
			local previous = milestones[index - 1] or 1
			local goal = Goal("level:" .. milestone, self:F("JRN_GOAL_LEVEL", milestone), level, milestone,
				(level - previous) / (milestone - previous), "journal")
			if goal then list[#list + 1] = goal end
			return
		end
	end
end

local SOURCES = { CompanionGoals, VillageGoals, CapitalGoals, DungeonGoals, LevelGoals }

-- Le plus proche du but d'abord ; à égalité, le moins de pas restants, puis
-- le nom (ordre stable d'un rafraîchissement à l'autre). Masqués à la fin.
local function Closer(a, b)
	if (a.dismissed == true) ~= (b.dismissed == true) then return not a.dismissed end
	if a.ratio ~= b.ratio then return a.ratio > b.ratio end
	local ra, rb = a.need - a.have, b.need - b.have
	if ra ~= rb then return ra < rb end
	return a.label < b.label
end

-- Tous les objectifs, masqués compris (marqués), triés
function ns:JournalObjectives()
	local list = {}
	for _, source in ipairs(SOURCES) do
		-- une source en panne ne prive pas des autres
		local ok, err = pcall(source, self, list)
		if not ok and self.RecordError then self:RecordError("journal:objectives", err) end
	end
	local dismissed = self:JournalData().dismissed or {}
	for _, goal in ipairs(list) do goal.dismissed = dismissed[goal.id] == true end
	table.sort(list, Closer)
	return list
end

-- Ceux du suivi : non masqués, les TRACKER_MAX premiers
function ns:JournalTrackerObjectives()
	local shown = {}
	for _, goal in ipairs(self:JournalObjectives()) do
		if not goal.dismissed and #shown < TRACKER_MAX then shown[#shown + 1] = goal end
	end
	return shown
end

-- Lignes de l'onglet « Objectifs » de la fenêtre (Journal.lua)
function ns:JournalGoalItems()
	local items = {}
	for _, goal in ipairs(self:JournalObjectives()) do
		items[#items + 1] = { name = goal.label, earned = false, goal = goal,
			detail = goal.progress .. (goal.dismissed and ("  " .. L.JRN_GOAL_HIDDEN) or "") }
	end
	return items
end

-- Masquer / remettre (state nil : bascule). Par personnage, comme le carnet.
function ns:JournalDismiss(id, state)
	if id == nil then return nil end
	local data = self:JournalData()
	if type(data.dismissed) ~= "table" then data.dismissed = {} end
	if state == nil then state = not data.dismissed[id] end
	data.dismissed[id] = state and true or nil
	self:RefreshJournalTracker()
	if self.journalFrame and self.journalFrame:IsShown() and self.RefreshJournal then self:RefreshJournal() end
	return state
end

-- ---------------------------------------------------------------------------
-- Cadre « Carnet »
-- ---------------------------------------------------------------------------
-- Le suivi de Blizzard présent (le premier visible, sinon le premier qui existe)
function ns:BlizzardQuestTracker()
	local fallback
	for _, name in ipairs(BLIZZARD_TRACKERS) do
		local frame = rawget(_G, name)
		if type(frame) == "table" and type(frame.IsShown) == "function" then
			local ok, shown = pcall(frame.IsShown, frame)
			if ok and shown then return frame, name end
			fallback = fallback or { frame, name }
		end
	end
	if fallback then return fallback[1], fallback[2] end
	return nil
end

-- Sous le suivi de Blizzard tant que tu ne l'as pas déplacé. Suivi caché
-- (aucune quête suivie) : on prend sa place, en haut, pour ne pas flotter
-- au milieu de l'écran sous un cadre invisible.
function ns:PlaceJournalTracker()
	local frame = self.journalTracker
	if not frame then return nil end
	frame:ClearAllPoints()
	local saved = self:DB().journalTrackerPoint
	if type(saved) == "table" and saved.point then
		frame:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, tonumber(saved.x) or 0, tonumber(saved.y) or 0)
		frame.anchoredTo = "saved"
		return frame.anchoredTo
	end
	local anchor, name = self:BlizzardQuestTracker()
	if anchor then
		local shown = false
		pcall(function() shown = anchor:IsShown() == true end)
		local ok
		if shown then
			ok = pcall(frame.SetPoint, frame, "TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -8)
		else
			ok = pcall(frame.SetPoint, frame, "TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
		end
		if ok then
			frame.anchoredTo = name
			-- le suivi de Blizzard apparaît / disparaît avec tes quêtes suivies
			if not frame.hooked or frame.hooked ~= anchor then
				if type(anchor.HookScript) == "function" then
					local function Replace() if not ns:DB().journalTrackerPoint then ns:PlaceJournalTracker() end end
					pcall(anchor.HookScript, anchor, "OnShow", Replace)
					pcall(anchor.HookScript, anchor, "OnHide", Replace)
				end
				frame.hooked = anchor
			end
			return frame.anchoredTo
		end
		frame:ClearAllPoints()
	end
	frame:SetPoint(FALLBACK.point, UIParent, FALLBACK.relPoint, FALLBACK.x, FALLBACK.y)
	frame.anchoredTo = "UIParent"
	return frame.anchoredTo
end

-- Fin de glisser : position retenue, relative à UIParent (StartMoving
-- réancre le cadre sur l'écran, GetPoint le dit tel quel)
function ns:SaveJournalTrackerPoint()
	local frame = self.journalTracker
	if not frame then return end
	local point, _, relPoint, x, y = frame:GetPoint(1)
	if not point then return end
	self:DB().journalTrackerPoint = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
	frame.anchoredTo = "saved"
end

function ns:ResetJournalTracker()
	self:DB().journalTrackerPoint = nil
	if self.journalTracker then self:PlaceJournalTracker() end
	self:Print(L.JRN_TRK_RESET)
	self:RefreshJournalTracker()
end

function ns:ToggleJournalTrackerCollapsed()
	local db = self:DB()
	db.journalTrackerCollapsed = not db.journalTrackerCollapsed
	self:RefreshJournalTracker()
	return db.journalTrackerCollapsed
end

local function StartDrag()
	local frame = ns.journalTracker
	if frame and frame.StartMoving then frame:StartMoving() end
end
local function StopDrag()
	local frame = ns.journalTracker
	if not frame then return end
	if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
	ns:SaveJournalTrackerPoint()
end

function ns:EnsureJournalTracker()
	if self.journalTracker then return self.journalTracker end
	if not Theme then return nil end
	local ok, frame = pcall(CreateFrame, "Frame", "Ready2QuestJournalTracker", UIParent)
	if not ok or not frame then return nil end
	frame:SetSize(TRACKER_WIDTH, TITLE_H)
	-- même couche que les suivis de quêtes : sous les fenêtres, au-dessus du monde
	frame:SetFrameStrata("LOW")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	-- le cadre lui-même laisse passer la souris : seuls le titre et les
	-- lignes la prennent, pas le vide entre elles
	frame:EnableMouse(false)

	-- titre : clic = replier / déplier, glisser = déplacer
	local title = CreateFrame("Button", nil, frame)
	title:SetSize(TRACKER_WIDTH, TITLE_H)
	title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	if title.RegisterForClicks then title:RegisterForClicks("LeftButtonUp") end
	if title.RegisterForDrag then title:RegisterForDrag("LeftButton") end
	title:SetScript("OnClick", function() ns:ToggleJournalTrackerCollapsed() end)
	title:SetScript("OnDragStart", StartDrag)
	title:SetScript("OnDragStop", StopDrag)
	title.text = Theme.CreateTitle(title, 13)
	title.text:SetPoint("RIGHT", title, "RIGHT", -16, 0)
	title.text:SetJustifyH("RIGHT")
	title.text:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	-- repère ASCII « - » / « + » (pas de glyphe absent des polices du jeu)
	title.state = title:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	title.state:SetPoint("RIGHT", title, "RIGHT", -2, 0)
	title.state:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	frame.title = title

	frame.lines = {}
	for index = 1, TRACKER_MAX do
		local line = CreateFrame("Button", nil, frame)
		line:SetSize(TRACKER_WIDTH, LINE_H)
		line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -TITLE_H - (index - 1) * LINE_H)
		if line.RegisterForClicks then line:RegisterForClicks("RightButtonUp") end
		if line.RegisterForDrag then line:RegisterForDrag("LeftButton") end
		line:SetScript("OnClick", function(self, button)
			if button == "RightButton" and self.goal then ns:JournalDismiss(self.goal.id, true) end
		end)
		line:SetScript("OnDragStart", StartDrag)
		line:SetScript("OnDragStop", StopDrag)
		line.diamond = Theme.CreateDiamond(line, 7, true)
		line.diamond:SetPoint("LEFT", line, "LEFT", 4, 0)
		line.diamond:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		line.text = line:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		line.text:SetPoint("LEFT", line, "LEFT", 16, 0)
		line.text:SetWidth(TRACKER_WIDTH - 70)
		line.text:SetJustifyH("LEFT")
		line.text:SetWordWrap(false)
		line.text:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3])
		line.progress = line:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		line.progress:SetPoint("RIGHT", line, "RIGHT", -2, 0)
		line.progress:SetWidth(50)
		line.progress:SetJustifyH("RIGHT")
		line.progress:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
		line:Hide()
		frame.lines[index] = line
	end
	frame:Hide()
	self.journalTracker = frame
	self:PlaceJournalTracker()
	return frame
end

-- Visible si : module allumé, suivi allumé, pas en combat (si réglé), et au
-- moins un objectif. Un titre seul, sans rien à suivre, ne serait que du bruit.
function ns:RefreshJournalTracker()
	local db = self:DB()
	local frame = self.journalTracker
	local wanted = ModuleOn() and db.journalTracker ~= false
		and not (db.journalTrackerCombat ~= false and InCombat())
	local goals = wanted and self:JournalTrackerObjectives() or {}
	if #goals == 0 then
		if frame then frame:Hide() end
		return frame
	end
	frame = frame or self:EnsureJournalTracker()
	if not frame then return nil end
	if frame.anchoredTo ~= "saved" then self:PlaceJournalTracker() end

	local collapsed = db.journalTrackerCollapsed == true
	frame.goals, frame.collapsed = goals, collapsed
	frame.title.text:SetText(collapsed and self:F("JRN_TRK_TITLE_COUNT", #goals) or L.JRN_TRK_TITLE)
	frame.title.state:SetText(collapsed and "+" or "-")
	local shown = 0
	for index, line in ipairs(frame.lines) do
		local goal = not collapsed and goals[index] or nil
		line.goal = goal
		if goal then
			line.text:SetText(goal.label)
			line.progress:SetText(goal.progress)
			line:Show()
			shown = shown + 1
		else
			line:Hide()
		end
	end
	frame:SetHeight(TITLE_H + shown * LINE_H)
	frame:Show()
	return frame
end

-- ---------------------------------------------------------------------------
-- Relais : réglages, interrupteur du module, action « réinitialiser »
-- ---------------------------------------------------------------------------
do
	local previous = ns.RunOptionAction
	function ns:RunOptionAction(key, ...)
		if key == "journalTrackerReset" then return self:ResetJournalTracker() end
		if previous then return previous(self, key, ...) end
	end
end

-- Un interrupteur basculé dans les réglages passe par ApplyDisplayOptions ;
-- « /r2q module carnet off » et l'interrupteur de la navigation par
-- RefreshOptions. Les deux relais suffisent à suivre l'état du module.
do
	local previousApply = ns.ApplyDisplayOptions
	function ns:ApplyDisplayOptions(...)
		local result
		if previousApply then result = previousApply(self, ...) end
		-- jamais bloquant : un réglage doit s'appliquer même si le suivi échoue
		pcall(self.RefreshJournalTracker, self)
		return result
	end
	local previousRefresh = ns.RefreshOptions
	if previousRefresh then
		function ns:RefreshOptions(...)
			local result = previousRefresh(self, ...)
			pcall(self.RefreshJournalTracker, self)
			return result
		end
	end
end

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
-- Un tampon gagné (contrat STAMP de Journal.lua) : la liste bouge
ns:RegisterCallback("STAMP", function(self) self:RefreshJournalTracker() end)

local function Moved()
	ns:LearnHubZone()
	ns:RefreshJournalTracker()
	if ns.journalFrame and ns.journalFrame:IsShown() and ns.journalFrame.kind == "goals" then ns:RefreshJournal() end
end

local HANDLERS = {
	PLAYER_ENTERING_WORLD = Moved,
	ZONE_CHANGED_NEW_AREA = Moved,
	ZONE_CHANGED          = Moved,
	ZONE_CHANGED_INDOORS  = Moved,
	PLAYER_LEVEL_UP       = function(level)
		ns.journalLevelHint = tonumber(level)
		local ok, err = pcall(Moved)
		ns.journalLevelHint = nil
		if not ok then error(err, 0) end
	end,
	PLAYER_REGEN_DISABLED = function() ns.journalTrackerCombat = true; ns:RefreshJournalTracker() end,
	PLAYER_REGEN_ENABLED  = function() ns.journalTrackerCombat = false; ns:RefreshJournalTracker() end,
}

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("journaltracker:" .. tostring(event), err) end
end)
ns.journalTrackerEventFrame = eventFrame

if ns.Mark then ns.Mark("JournalTracker") end
