-- MenagerieView.lua -- la Ménagerie façon bestiaire : filtre par type, fiche qui tourne (QuestCompanion 2.4)
--
-- Inspiré du « Forever Bestiary » : une rangée de boutons carrés, un par type
-- de créature (CreatureTypes.lua), plus « Tous », sous la recherche de la
-- Ménagerie (JournalWindow.lua). Un clic filtre la liste sur ce type, un
-- second clic (ou « Tous ») enlève le filtre. L'infobulle donne le compte de
-- la zone choisie : espèces de ce type capturées et croisées. Une espèce
-- jamais croisée n'a pas de type connu (ns:MenagerieList ne le dit pas) :
-- elle ne tombe dans aucun filtre de type et la recherche ne la trouve pas,
-- rien ne fuit de ce qui reste à découvrir.
-- Le modèle 3D de la fiche tourne à la souris (glisser).
-- État : frame.menType (clé de type ou nil), oublié en changeant de zone par
-- la fiche de zone (ns:OpenMenagerieZone).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	MENV_ALL          = "Tous",
	MENV_ALL_TIP      = "Tous les types",
	MENV_TYPE_COUNT   = "%d capturées · %d croisées",
	MENV_TYPE_NONE    = "Aucune espèce de ce type croisée ici pour l'instant.",
	MENV_TYPE_CLICK   = "Clic : ne montrer que ce type.",
	MENV_TYPE_OFF     = "Clic : tous les types.",
	MENV_TYPE_ON      = "%s : %d capturées / %d croisées",
	MENV_LOCKED       = "Espèce pas encore découverte.",
}
local EN = {
	MENV_ALL          = "All",
	MENV_ALL_TIP      = "Every type",
	MENV_TYPE_COUNT   = "%d captured · %d met",
	MENV_TYPE_NONE    = "No creature of this type met here yet.",
	MENV_TYPE_CLICK   = "Click: show only this type.",
	MENV_TYPE_OFF     = "Click: every type.",
	MENV_TYPE_ON      = "%s: %d captured / %d met",
	MENV_LOCKED       = "Species not discovered yet.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.MENAGERIE_VIEW_STRINGS = { fr = FR, en = EN } end

-- Icônes des familles de mascottes du jeu (le Forever Bestiary s'en sert sur
-- ce client) ; repli sur les icônes de type de la liste si l'une manque.
-- Rien n'est livré avec l'addon : on désigne les fichiers du jeu.
ns.MENAGERIE_TYPE_BUTTON_ICONS = {
	beast      = "Interface\\Icons\\Icon_PetFamily_Beast",
	humanoid   = "Interface\\Icons\\Icon_PetFamily_Humanoid",
	undead     = "Interface\\Icons\\Icon_PetFamily_Undead",
	elemental  = "Interface\\Icons\\Icon_PetFamily_Elemental",
	dragonkin  = "Interface\\Icons\\Icon_PetFamily_Dragon",
	demon      = "Interface\\Icons\\Icon_PetFamily_Magical",
	giant      = "Interface\\Icons\\Icon_PetFamily_Water",
	mechanical = "Interface\\Icons\\Icon_PetFamily_Mechanical",
}
local BUTTON, GAP = 24, 4

local function SetIcon(tex, key)
	local path = ns.MENAGERIE_TYPE_BUTTON_ICONS[key]
	local ok, res = pcall(tex.SetTexture, tex, path)
	-- les clients récents rendent false pour un fichier absent
	if not ok or res == false then
		local fallback = ns.MENAGERIE_TYPE_ICONS and ns.MENAGERIE_TYPE_ICONS[ns:CreatureTypeLabel(key) or ""]
		pcall(tex.SetTexture, tex, fallback or "Interface\\Icons\\INV_Misc_QuestionMark")
	end
end

-- Un bouton carré au trait (comme les boutons-icônes du socle), qui reste
-- éclairé quand son filtre est actif
local function Paint(button)
	local on, hot = button.selected, button.hovered
	local edge = on and Theme.GOLD or (hot and Theme.EDGE or Theme.EDGE_SOFT)
	button.border:SetColor(edge[1], edge[2], edge[3], 1)
	button.bg:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], on and 0.14 or 0)
	if button.icon then
		if button.icon.SetDesaturated then button.icon:SetDesaturated(not (on or hot)) end
		button.icon:SetAlpha((on or hot) and 1 or (button.empty and 0.3 or 0.65))
	end
	if button.text then
		local c = on and Theme.GOLD or (hot and Theme.LABEL or Theme.MUTED_LIGHT)
		if button.text.SetTextColor then button.text:SetTextColor(c[1], c[2], c[3], 1) end
	end
end

local function NewButton(parent, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, BUTTON)
	button.bg = Theme.Solid(button, "BACKGROUND", Theme.GOLD, 0)
	button.bg:SetAllPoints()
	button.border = Theme.Border(button, Theme.EDGE_SOFT, 1)
	button:SetScript("OnLeave", function(self)
		self.hovered = false
		Paint(self)
		local UI = ns.JournalUI
		if UI and UI.HideTip then UI.HideTip() end
	end)
	return button
end

-- Choisir un type (nil = tous) ; re-choisir le même l'enlève
function ns:MenagerieSetType(key)
	local frame = self.journalFrame
	if not frame then return end
	if key == "all" or key == frame.menType then key = nil end
	frame.menType = key
	frame.menOffset = 0
	-- 2.11.0 : le type tient au /reload (journalState)
	if self.JournalRemember then self:JournalRemember("menType", key) end
	self:RefreshJournal()
end

-- Rangée de boutons sous la recherche ; rend sa hauteur
function ns:MenagerieViewBuild(pane, content, x, y, frame)
	local UI = ns.JournalUI
	if not (UI and UI.At) then return 0 end
	local row = CreateFrame("Frame", nil, pane)
	row:SetSize(UI.GRID_W or 400, BUTTON)
	UI.At(row, content, x, y)
	pane.types = row
	row.buttons = {}
	-- « Tous »
	local label = L.MENV_ALL
	local allW = math.ceil(Theme.TextWidth(row, label, Theme.F_BODY) + 20)
	local all = NewButton(row, allW)
	all:SetPoint("LEFT", row, "LEFT", 0, 0)
	all.text = Theme.Text(all, Theme.F_BODY, Theme.MUTED_LIGHT)
	all.text:SetPoint("CENTER", all, "CENTER", 0, 0)
	all.text:SetText(label)
	all.key = "all"
	all:SetScript("OnClick", function() ns:MenagerieSetType(nil) end)
	all:SetScript("OnEnter", function(self)
		self.hovered = true
		Paint(self)
		UI.Tip(self, L.MENV_ALL_TIP, self.tip)
	end)
	row.all = all
	local left = allW + GAP + 2
	for index, key in ipairs(ns.CREATURE_TYPES or {}) do
		local button = NewButton(row, BUTTON)
		button:SetPoint("LEFT", row, "LEFT", left + (index - 1) * (BUTTON + GAP), 0)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
		button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
		button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		SetIcon(button.icon, key)
		button.key = key
		button:SetScript("OnClick", function(self) ns:MenagerieSetType(self.key) end)
		button:SetScript("OnEnter", function(self)
			self.hovered = true
			Paint(self)
			UI.Tip(self, ns:CreatureTypeLabel(self.key), self.tip)
		end)
		row.buttons[index] = button
		row.buttons[key] = button
		Paint(button)
	end
	Paint(all)
	-- le filtre actif, en clair, à droite des boutons
	local after = left + #(ns.CREATURE_TYPES or {}) * (BUTTON + GAP) + 8
	row.summary = UI.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT, math.max(60, (UI.GRID_W or 400) - after))
	row.summary:SetPoint("LEFT", row, "LEFT", after, 0)
	if row.summary.SetWordWrap then row.summary:SetWordWrap(false) end
	return BUTTON
end

-- Comptes et sélection, à chaque rafraîchissement de la Ménagerie
function ns:MenagerieViewRefresh(pane, frame, stats)
	local row = pane.types
	if not row then return end
	-- le modèle de la fiche tourne à la souris (la fiche est construite après la rangée)
	self:MenagerieViewRotate(pane.preview and pane.preview.model)
	local types = type(stats) == "table" and stats.types or {}
	local active = frame.menType
	local totalKnown, totalCaught = 0, 0
	for _, key in ipairs(ns.CREATURE_TYPES or {}) do
		local button = row.buttons[key]
		local count = types[key] or { known = 0, captured = 0 }
		totalKnown, totalCaught = totalKnown + count.known, totalCaught + count.captured
		button.count = count
		button.empty = count.known == 0
		button.selected = active == key
		button.tip = {
			count.known > 0 and self:F("MENV_TYPE_COUNT", count.captured, count.known) or L.MENV_TYPE_NONE,
			button.selected and L.MENV_TYPE_OFF or L.MENV_TYPE_CLICK,
		}
		Paint(button)
	end
	row.all.selected = active == nil
	row.all.tip = { self:F("MENV_TYPE_COUNT", totalCaught, totalKnown) }
	Paint(row.all)
	if active and row.buttons[active] then
		local count = row.buttons[active].count
		row.summary:SetText(self:F("MENV_TYPE_ON", self:CreatureTypeLabel(active), count.captured, count.known))
	else
		row.summary:SetText("")
	end
end

-- Glisser sur le modèle : il tourne (comme dans le Forever Bestiary)
function ns:MenagerieViewRotate(model)
	if not model or model.qcRotate or not model.SetScript then return end
	model.qcRotate = true
	if model.EnableMouse then model:EnableMouse(true) end
	local function CursorX()
		local get = rawget(_G, "GetCursorPosition")
		if type(get) ~= "function" then return nil end
		local ok, cx = pcall(get)
		return ok and tonumber(cx) or nil
	end
	-- OnUpdate seulement pendant le glisser : rien à chaque image sinon
	local function Turn(self)
		local cx = CursorX()
		if cx and self.dragX and self.SetFacing then pcall(self.SetFacing, self, self.dragFacing + (cx - self.dragX) / 60) end
	end
	local function Stop(self)
		self.dragX = nil
		self:SetScript("OnUpdate", nil)
	end
	model:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local cx = CursorX()
		if not cx then return end
		local ok, facing = pcall(self.GetFacing, self)
		self.dragX, self.dragFacing = cx, ok and tonumber(facing) or 0
		self:SetScript("OnUpdate", Turn)
	end)
	model:SetScript("OnMouseUp", Stop)
	model:SetScript("OnHide", Stop)
end

-- ---------------------------------------------------------------------------
-- 2.15.0 : revenir compléter. « À compléter » (todo) : une espèce dont la
-- référence du Codex n'a pas 3 étoiles, version par version (la normale,
-- même pas encore capturée ; la brillante si tu l'as) ; « Épinglées »
-- (pinned) : la liste de chasse (ns:HuntPin). Deux états de plus pour
-- ns:MenagerieList ; les comptes d'une zone pour la page Exploration ; la
-- Réserve comptée par espèce. Rien n'est créé à l'affichage : les comptes
-- sont gardés tant que rien ne bouge (numéros de série de la capture).
-- ---------------------------------------------------------------------------
local CODEX_STATES = { todo = true, pinned = true }
ns.CODEX_STATES = CODEX_STATES
local STAR_MAX = 3

-- Une espèce de la liste (ns:MenagerieList) est-elle à compléter ?
function ns:CodexItemTodo(item)
	if type(item) ~= "table" then return false end
	local max = ns.CAPTURE_STAR_MAX or STAR_MAX
	local normal = (item.captured and item.normal ~= false) and (tonumber(item.stars) or 1) or 0
	if normal < max then return true end
	return item.shiny == true and (tonumber(item.shinyStars) or 1) < max
end

-- Spécimens en Réserve par espèce : { [npc] = n }, gardé tant que les
-- spécimens ne bougent pas (capture.specSerial)
function ns:CodexReserveCounts()
	local capture = ns.SpecimenStore and ns.SpecimenStore(self)
	if not capture then return {} end
	local cache = self.codexReserveCache
	if cache and cache.serial == capture.specSerial and cache.specimens == capture.specimens then return cache.counts end
	local counts = {}
	for _, spec in pairs(capture.specimens) do
		local codex = capture.codex[spec.npc]
		if not (codex and codex[spec.shiny and "bestShiny" or "best"] == spec.id) then
			counts[spec.npc] = (counts[spec.npc] or 0) + 1
		end
	end
	self.codexReserveCache = { serial = capture.specSerial, specimens = capture.specimens, counts = counts }
	return counts
end

do
	local base = ns.MenagerieList
	if base then
		function ns:MenagerieList(opts, ...)
			if type(opts) ~= "table" or not CODEX_STATES[opts.state or ""] then return base(self, opts, ...) end
			local want = opts.state
			local copy = {}
			for key, value in pairs(opts) do copy[key] = value end
			copy.state = "all"
			local list, stats = base(self, copy, ...)
			local kept = {}
			stats.todo, stats.pinned = 0, 0
			for _, item in ipairs(list or {}) do
				item.todo = self:CodexItemTodo(item)
				item.pinned = self.HuntPinned and self:HuntPinned(item.npc) or false
				if item.todo then stats.todo = stats.todo + 1 end
				if item.pinned then stats.pinned = stats.pinned + 1 end
				if (want == "todo" and item.todo) or (want == "pinned" and item.pinned) then kept[#kept + 1] = item end
			end
			return kept, stats
		end
	end
end

-- Comptes d'une zone (page Exploration) : { total, todo, missing } ;
-- complete = toutes ses espèces à 3 étoiles. Gardés par zone tant que la
-- capture ne bouge pas (capture.serial, capture.specSerial).
function ns:CodexZoneCounts(zoneID)
	zoneID = tonumber(zoneID)
	if not (zoneID and self.MenagerieList and self.CaptureData) then return nil end
	local capture = self:CaptureData()
	local cache = self.codexZoneCache
	if not cache or cache.serial ~= capture.serial or cache.specSerial ~= capture.specSerial or cache.creatures ~= capture.creatures then
		cache = { serial = capture.serial, specSerial = capture.specSerial, creatures = capture.creatures, zones = {} }
		self.codexZoneCache = cache
	end
	local counts = cache.zones[zoneID]
	if counts then return counts end
	local list, stats = self:MenagerieList({ zone = zoneID, state = "todo" })
	counts = { total = stats.total or 0, todo = #list, missing = (stats.total or 0) - (stats.captured or 0) }
	counts.complete = counts.total > 0 and counts.todo == 0
	cache.zones[zoneID] = counts
	return counts
end

-- Les Créatures d'une zone, filtre « À compléter » (tag de la page Exploration)
function ns:OpenMenagerieTodo(zoneID)
	local frame = self:EnsureJournalWindow()
	if not frame then return nil end
	frame.menZone = tonumber(zoneID) or "here"
	frame.menState, frame.menRank, frame.menSearch, frame.menOffset = "todo", "all", "", 0
	frame.menType = nil
	if frame.men and frame.men.search then frame.men.search:SetText("") end
	self:SelectJournalKind("menagerie")
	return frame
end

-- Épingler / désépingler depuis le carnet (la ligne d'une espèce)
function ns:CodexTogglePin(npc)
	if npc == nil or not self.HuntPin then return nil end
	local on = self:HuntPin(npc)
	local name = self.CreatureName and self:CreatureName(npc) or tostring(npc)
	self:Print(self:F(on and "HUNT_PINNED" or "HUNT_UNPINNED", name))
	return on
end

-- Le carnet suit les spécimens, les épingles et les paillettes
local function JournalFollow(self)
	local frame = self.journalFrame
	if not (frame and frame.IsShown and frame:IsShown()) then return end
	local kind = frame.kind
	-- 3.0.0 (bêta 6) : l'Échoppe aussi (ses « Acheter » suivent le solde)
	if kind == "menagerie" or kind == "reserve" or kind == "shop" or kind == "progress" or kind == "evolution" then
		if self.JournalSoon then self:JournalSoon("codex") else self:RefreshJournal() end
	end
end
if ns.RegisterCallback then
	ns:RegisterCallback("SPECIMENS", function(self) JournalFollow(self) end)
	ns:RegisterCallback("PAILLETTES", function(self) JournalFollow(self) end)
end

if ns.Mark then ns.Mark("MenagerieView") end
