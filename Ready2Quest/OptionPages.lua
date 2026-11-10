-- OptionPages.lua -- pages de réglages de Ready2Quest
--
-- Le panneau lui-même (navigation, lignes, listes, pied) est dans le socle
-- commun (Libs/Socle/Options.lua). Ici : les pages du cœur, les listes
-- (zones sûres, buffs suivis), les actions et le bouton principal du pied.
-- Les modules ajoutent leurs pages ensuite (ns.AddOptionPage).
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local function OnOff(on)
	return on and (Theme.T_GREEN .. L.OPT_ON .. "|r") or (Theme.T_GREY .. L.OPT_OFF .. "|r")
end

-- ---------------------------------------------------------------------------
-- Pages. `modules` = interrupteurs de checks (ns.checks), `rows` = réglages,
-- `list` = liste défilante (zones sûres, buffs suivis), `buttons` = actions.
-- ---------------------------------------------------------------------------
-- v1.22.0 : l'addon a TROIS modules (Check avant le départ, Résumé de stuff,
-- Stats du portrait) et une section QoL. Les 13 « checks » ne sont pas des
-- modules : ce sont les contrôles du Check avant le départ, réglés dans ses
-- sous-pages. Un module a son interrupteur dans la navigation (`power` = clé
-- de réglage) ; une sous-page porte `parent`.
local R2Q_PAGES = {
	{
		id = "general", title = "OPT_PAGE_GENERAL",
		-- tout ce qui touche à l'affichage est réuni ici (section AFFICHAGE)
		rows = {
			{ key = "enabled",     label = "OPT_ENABLED",     kind = "bool" },
			{ header = "OPT_SECTION_DISPLAY" },
			{ key = "showMinimap", label = "OPT_MINIMAP",     kind = "bool" },
			{ key = "minimapPos",  label = "OPT_MINIMAP_POS", kind = "action", button = "OPT_BTN_CHANGE" },
			{ key = "showWindow",  label = "OPT_SHOWWINDOW",  kind = "bool" },
			{ key = "popupScore",  label = "OPT_POPUPSCORE",  kind = "number", min = 0, max = 100, step = 5 },
		},
		frameButtons = true,
	},
	-- MODULES ---------------------------------------------------------------
	-- aperçu sous les onglets : la note du dernier check, comme en tête de
	-- la fenêtre de diagnostic (DeparturePreview, plus bas)
	{ id = "departure", title = "OPT_PAGE_DEPARTURE", group = "OPT_GROUP_MODULES", power = "departureEnabled", target = "trigger",
		preview = function(self, container) return self:DeparturePreview(container) end },
	{
		id = "trigger", title = "OPT_PAGE_TRIGGER", parent = "departure", group = "OPT_GROUP_MODULES",
		rows = {
			{ key = "exitDelay",       label = "OPT_EXITDELAY",  kind = "number", min = 0, max = 15,  step = 1, suffix = "OPT_SEC_UNIT" },
			{ key = "quietAfterLogin", label = "OPT_QUIETLOGIN", kind = "number", min = 0, max = 60,  step = 5, suffix = "OPT_SEC_UNIT" },
			{ key = "alertCooldown",   label = "OPT_COOLDOWN",   kind = "number", min = 0, max = 120, step = 5, suffix = "OPT_SEC_UNIT" },
		},
	},
	{ id = "safe", title = "OPT_PAGE_SAFE", parent = "departure", group = "OPT_GROUP_MODULES", list = "safe" },
	{
		id = "bags", title = "OPT_PAGE_BAGS", parent = "departure", group = "OPT_GROUP_MODULES",
		modules = { "bags", "gray", "vivres", "potions" },
		rows = {
			{ key = "bagFreeThreshold",   label = "OPT_BAGTHRESHOLD",     kind = "number", min = 0, max = 40,  step = 1 },
			{ key = "continuousBagAlert", label = "OPT_BAGALERT",         kind = "bool" },
			{ key = "grayItemThreshold",  label = "OPT_GRAYTHRESHOLD",    kind = "number", min = 0, max = 50,  step = 1 },
			{ key = "vivresThreshold",    label = "OPT_VIVRESTHRESHOLD",  kind = "number", min = 0, max = 200, step = 5 },
			{ key = "potionsThreshold",   label = "OPT_POTIONSTHRESHOLD", kind = "number", min = 0, max = 50,  step = 1 },
		},
	},
	{
		id = "gear", title = "OPT_PAGE_GEAR", parent = "departure", group = "OPT_GROUP_MODULES",
		modules = { "durability", "repair", "classreagents", "spells", "hearth", "rest" },
		rows = {
			{ key = "durabilityMinPct", label = "OPT_DURAMIN", kind = "number", min = 0, max = 100, step = 5, suffix = "OPT_PCT_UNIT" },
			{ key = "restMinPercent",   label = "OPT_RESTMIN", kind = "number", min = 0, max = 150, step = 5, suffix = "OPT_REST_UNIT" },
		},
	},
	{
		id = "buffs", title = "OPT_PAGE_BUFFS", parent = "departure", group = "OPT_GROUP_MODULES",
		modules = { "buffs", "reagents", "quests" }, list = "buffs",
		rows = {
			{ key = "learnBuffs", label = "OPT_LEARNBUFFS", kind = "bool" },
			-- 1.33.3 : le rôle décide des buffs de tank (Fureur vertueuse)
			{ key = "buffRole", label = "OPT_BUFF_ROLE", kind = "action",
				choices = function() return ns:BuffRoleChoices() end,
				current = function() return ns:DB().buffRole or "auto" end,
				choose = function(value) ns:BuffSetRole(value) end },
		},
	},
	-- pas de page propre : leur réglage est l'interrupteur, et leur placement
	-- est dans Général > Affichage
	-- sans réglage propre, mais avec une vraie page : cliquer sur un module doit
	-- montrer ce qu'il fait (il renvoyait sur Général, c'était déroutant)
	{ id = "toast", title = "OPT_PAGE_TOAST", group = "OPT_GROUP_MODULES", power = "showGearToast",
		info = { "OPT_TOAST_INFO_1", "OPT_TOAST_INFO_2", "OPT_TOAST_INFO_3" }, actions = { "toastPreview", "editMode" } },
	{ id = "portrait", title = "OPT_PAGE_PORTRAIT", group = "OPT_GROUP_MODULES", power = "showPortraitStats",
		info = { "OPT_PORTRAIT_INFO_1", "OPT_PORTRAIT_INFO_2", "OPT_PORTRAIT_INFO_3" }, actions = { "portraitShow", "editMode" } },
	-- QOL -------------------------------------------------------------------
	-- QOL : une entrée parente, comme le Check avant le départ ; chaque confort
	-- est une sous-page (Marchand, puis ceux qu'ajoutent les modules QoL)
	{ id = "qol", title = "OPT_PAGE_QOL", group = "OPT_GROUP_QOL", target = "merchant" },
	{
		id = "merchant", title = "OPT_PAGE_MERCHANT", parent = "qol", group = "OPT_GROUP_QOL",
		rows = {
			{ key = "autoSellGray", label = "OPT_AUTOSELL",   kind = "bool" },
			{ key = "autoRepair",   label = "OPT_AUTOREPAIR", kind = "bool" },
		},
	},
}
for _, def in ipairs(R2Q_PAGES) do table.insert(ns.OPTION_PAGES, def) end

-- ---------------------------------------------------------------------------
-- Listes défilantes : zones sûres apprises, buffs suivis
-- ---------------------------------------------------------------------------
local function SafeItems()
	local db = ns:DB()
	local items = {}
	for key, entry in pairs(db.safe or {}) do
		local kind = entry.kind == "city" and L.SAFE_KIND_CITY or L.SAFE_KIND_VILLAGE
		items[#items + 1] = {
			key = key,
			text = tostring(entry.name or "?"),
			detail = kind .. ", " .. Theme.T_BLUE .. ns:SourceLabel(entry.source) .. "|r",
			action = L.OPT_REMOVE,
			onAction = function() ns:ForgetSafeZone(key) end,
		}
	end
	table.sort(items, function(a, b) return a.text < b.text end)
	return items
end

-- 1.31.0 : la raison en gris clair (MUTED_LIGHT #a3a8ad : 6,8:1 sur la
-- carte la plus claire #1b2127 ; le gris d'OFF n'y fait que 4,2:1)
-- 1.32.0 (fiche 28) : code couleur du socle (Theme.Hex)
local function Hex(c) return Theme.Hex(c) end
ns.BUFF_WHY_COLOR = Theme.MUTED_LIGHT

local function BuffItems()
	local items = {}
	local classes, grouped, others = ns:BuffGroupClasses()
	local why = Hex(ns.BUFF_WHY_COLOR)
	for _, entry in ipairs(ns:TrackedBuffs()) do
		local spellId = entry.spellId
		-- 1.31.0 : réclamé ici, ou pourquoi pas (buff personnel, classe absente…)
		local _, reason, cls = ns:BuffAvailability(spellId, entry.entry, classes, grouped, others)
		local because = ns:F("BUFF_WHY_" .. string.upper(reason or "other"), ns:ClassName(cls))
		-- 1.32.2 : pas réclamé par défaut (consommable, posture…) : à activer
		local kind = ns.BuffKind and ns.BuffKind(spellId, entry.entry)
		if not entry.entry.userSet and kind == "role" then
			-- 1.33.3 : buff de tank, selon ton rôle
			because = ns:F("BUFF_WHY_ROLE", L["BUFF_ROLE_" .. (ns:BuffRole())])
		elseif not entry.entry.userSet and kind and kind ~= "class" then
			because = L["BUFF_WHY_OPTIN_" .. string.upper(kind)] or because
		end
		items[#items + 1] = {
			key = spellId,
			text = tostring(entry.name or spellId),
			value = OnOff(entry.enabled) .. why .. " · " .. because .. "|r",
			onToggle = function()
				ns:BuffToggle(spellId)
			end,
			action = L.OPT_REMOVE,
			onAction = function() ns:DB().buffs[spellId] = nil end,
		}
	end
	return items
end

function ns:ForgetSafeZone(key)
	local db = self:DB()
	local entry = db.safe and db.safe[key]
	if not entry then return end
	db.safe[key] = nil
	if db.safeClues then db.safeClues[key] = nil end
	if entry.kind == "city" and entry.mapID and db.cityRest then db.cityRest[entry.mapID] = nil end
	self.inSafe, self.pendingExit = nil, nil
	self:Print(self:F("MSG_SAFE_REMOVED", tostring(entry.name or "?")))
end

ns.OPTION_LISTS.safe = {
	items = SafeItems, header = "OPT_SAFE_LIST", empty = "OPT_SAFE_EMPTY", lines = ns.OPT_LAYOUT.listLines,
	-- sous la liste : tout oublier, et une ligne d'aide
	clear = { label = "OPT_SAFE_CLEAR", run = function(self) self:HandleCommand("safe reset") end },
	hint = "OPT_SAFE_HINT",
}
-- quatre lignes : la page des buffs porte aussi l'aperçu et six cartes
ns.OPTION_LISTS.buffs = { items = BuffItems, header = "OPT_BUFFS_LIST", empty = "OPT_BUFFS_EMPTY",
	lines = ns.OPT_LAYOUT.listLines - 6 }

-- ---------------------------------------------------------------------------
-- Actions, bouton principal, fenêtres exclusives, interrupteurs
-- ---------------------------------------------------------------------------
ns.OPTION_ACTIONS.resetPos = function(self)
	self:HandleCommand("resetpos")
	self:RefreshOptions()
end
ns.OPTION_ACTIONS.toastPreview = function(self)
	if self.SimulateGearToast then self:SimulateGearToast() end
end
ns.OPTION_ACTIONS.portraitShow = function(self)
	if not self.ShowPortraitStats then return end
	-- aperçu immédiat, même si le module est coupé (forceStats)
	self.forceStats = true
	self:ShowPortraitStats()
	self.forceStats = nil
end

-- Aperçu de la page « Check avant le départ » : la note du dernier check (ou
-- une note d'exemple), sa barre et son verdict, aux couleurs de la fenêtre
function ns:DeparturePreview(container)
	local score = Theme.CreateTitle(container, 34)
	score:SetPoint("LEFT", container, "LEFT", 22, 4)
	local suffix = Theme.Text(container, Theme.F_BODY, Theme.MUTED)
	suffix:SetPoint("BOTTOMLEFT", score, "BOTTOMRIGHT", 6, 5)
	suffix:SetText("/ 100")
	local verdict = Theme.Text(container, Theme.F_HEADING, Theme.PARCHMENT)
	verdict:SetPoint("TOPLEFT", container, "TOPLEFT", 150, -24)
	local note = Theme.Text(container, Theme.F_SMALL, Theme.MUTED)
	note:SetPoint("TOPLEFT", verdict, "BOTTOMLEFT", 0, -6)
	local bar = Theme.CreateBar(container, 360, 5)
	bar:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -10)
	container.score, container.verdict, container.note, container.bar = score, verdict, note, bar
	function container:Refresh(addon)
		local value, sample = addon.score, false
		if not value then value, sample = 85, true end
		local label = addon:ScoreLabel(value)
		local c = Theme.ScoreColor(value / 100)
		self.score:SetText(tostring(value))
		self.score:SetTextColor(c[1], c[2], c[3], 1)
		self.verdict:SetText(label)
		self.note:SetText(sample and L.OPT_PREVIEW_SAMPLE or L.OPT_PREVIEW_LAST)
		self.bar:SetColor(c[1], c[2], c[3], 1)
		self.bar:SetValue(value / 100)
	end
	container:Refresh(self)
	return container
end

ns.OPTIONS_MAIN = { label = "OPT_RUNCHECK", run = function(self) self:RunChecklist("manual") end }

for _, field in ipairs({ "window", "expeditionFrame", "dungeonFrame" }) do
	table.insert(ns.EXCLUSIVE_WINDOWS, field)
end

-- Module coupé : on range ce qui est à l'écran ou en attente
function ns:OnModuleToggled(key, enabled)
	if key == "showPortraitStats" and enabled == false and self.HidePortraitStats then self:HidePortraitStats() end
	if key == "departureEnabled" and enabled == false then self.pendingExit = nil end
end

-- Infobulle du bouton de minicarte (socle commun) : la dernière note
function ns:MinimapTooltip(tooltip)
	if not self.score then return end
	Theme.TooltipLine(tooltip, string.format(L.MINIMAP_SCORE, self.score, self:ScoreLabel()), Theme.ScoreColor(self.score / 100))
end

if ns.Mark then ns.Mark("OptionPages") end
