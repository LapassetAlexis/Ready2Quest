-- API récentes, exploitées seulement quand le client les expose (lot 3) :
--   * entrée dans Échap > Options > AddOns (Settings, socle Options.lua) :
--     une petite page avec un bouton qui ouvre nos réglages ;
--   * bouton des addons de la minicarte (AddonCompartmentFrame, socle
--     Minimap.lua) : même icône, même clic gauche, même infobulle ;
--   * boucles OnUpdate espacées (ns.Throttle, socle Base.lua).
-- Sans ces API : rien ne s'inscrit, rien ne casse.
local Check, Say, ResetWorld, NS, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.QNS, T.Mock

local L3 = { saved = {} }
for _, name in ipairs({ "Settings", "SettingsPanel", "AddonCompartmentFrame" }) do L3.saved[name] = rawget(_G, name) end

-- Remet les deux addons « avant connexion » : rien d'inscrit
function L3.Reset()
	for _, ns in ipairs({ NS, QNS }) do
		ns.settingsTried, ns.settingsCategory, ns.settingsCanvas, ns.compartmentEntry = nil, nil, nil, nil
	end
	_G.Settings, _G.SettingsPanel, _G.AddonCompartmentFrame = nil, nil, nil
end

function L3.InstallSettings(fail)
	local W = { categories = {}, added = {} }
	_G.Settings = {
		RegisterCanvasLayoutCategory = function(frame, name)
			if fail then error("settings refused") end
			local category = { frame = frame, name = name, id = 100 + #W.categories }
			function category:GetID() return self.id end
			W.categories[#W.categories + 1] = category
			return category
		end,
		RegisterAddOnCategory = function(category) W.added[#W.added + 1] = category end,
	}
	_G.SettingsPanel = { shown = true }
	function SettingsPanel:Hide() self.shown = false end
	return W
end

function L3.InstallCompartment(fail)
	local W = { entries = {} }
	_G.AddonCompartmentFrame = {
		RegisterAddon = function(self, info)
			if fail then error("compartment refused") end
			W.self = self
			W.entries[#W.entries + 1] = info
		end,
	}
	return W
end

-- ---------------------------------------------------------------------------
-- 1. Échap > Options > AddOns
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes (lot 3) : entrée dans les options du jeu")
	ResetWorld()
	L3.Reset()
	Check("[SET] chaînes en français et en anglais", NS.L.SETTINGS_OPEN == "Ouvrir les réglages"
		and type(NS.L.SETTINGS_HINT) == "string" and NS.L.SETTINGS_HINT ~= "SETTINGS_HINT"
		and NS.L.SETTINGS_VERSION:find("%s", 1, true) ~= nil)

	-- sans l'API : la connexion passe, rien d'inscrit
	local ok = pcall(Mock.Fire, Mock, "PLAYER_LOGIN")
	Check("[SET] sans Settings : connexion sans erreur, rien d'inscrit", ok and NS.settingsCategory == nil
		and QNS.settingsCategory == nil and NS:RegisterSettingsCategory() == nil)

	-- avec l'API : une catégorie par addon, à son nom, une seule fois
	local W = L3.InstallSettings()
	Mock:Fire("PLAYER_LOGIN")
	Check("[SET] connexion : une catégorie par addon", #W.categories == 2 and #W.added == 2, #W.categories)
	Check("[SET] au nom de chaque addon", NS.settingsCategory and NS.settingsCategory.name == "Ready2Quest"
		and QNS.settingsCategory and QNS.settingsCategory.name == "QuestCompanion")
	Check("[SET] la catégorie est inscrite parmi les addons", W.added[1] == W.categories[1] and W.added[2] == W.categories[2])
	Check("[SET] catégorie gardée (OpenToCategory possible)", NS.settingsCategory:GetID() == NS.settingsCategory.id)
	Mock:Fire("PLAYER_LOGIN")
	NS:RegisterSettingsCategory()
	QNS:RegisterSettingsCategory()
	Check("[SET] une seule inscription par addon", #W.categories == 2 and #W.added == 2, #W.categories)

	-- la page : titre, version, une ligne, le bouton
	local canvas = NS.settingsCanvas
	Check("[SET] page native : pas le grand panneau", canvas and canvas ~= NS.optionsFrame
		and W.categories[1].frame == canvas)
	Check("[SET] page native : titre et version", canvas.title.text == NS.APP.brand
		and canvas.version.text == string.format(NS.L.SETTINGS_VERSION, NS.APP.version), canvas.version.text)
	Check("[SET] page native : une ligne et le bouton", canvas.hint.text == NS.L.SETTINGS_HINT and canvas.open ~= nil)
	Check("[SET] QC : son propre titre", QNS.settingsCanvas.title.text == (QNS.APP.brand or "QuestCompanion"))

	-- le bouton ferme les options du jeu et ouvre les nôtres
	if NS.optionsFrame then NS.optionsFrame:Hide() end
	canvas.open:Click()
	Check("[SET] bouton : options du jeu fermées", SettingsPanel.shown == false)
	Check("[SET] bouton : nos réglages ouverts", NS.optionsFrame and NS.optionsFrame:IsShown() == true)
	SettingsPanel.shown = true
	canvas.open:Click()
	Check("[SET] second clic : nos réglages restent ouverts", NS.optionsFrame:IsShown() == true and SettingsPanel.shown == false)
	NS.optionsFrame:Hide()
	QNS.settingsCanvas.open:Click()
	Check("[SET] QC : ses propres réglages", QNS.optionsFrame and QNS.optionsFrame:IsShown() == true
		and not NS.optionsFrame:IsShown())
	QNS.optionsFrame:Hide()

	-- sans SettingsPanel : le bouton ouvre quand même
	_G.SettingsPanel = nil
	ok = pcall(canvas.open.Click, canvas.open)
	Check("[SET] sans SettingsPanel : ouvre sans erreur", ok and NS.optionsFrame:IsShown() == true)
	NS.optionsFrame:Hide()

	-- API en erreur : rien d'inscrit, pas d'erreur, pas de nouvel essai
	L3.Reset()
	local errors = #NS.errors
	W = L3.InstallSettings(true)
	ok = pcall(Mock.Fire, Mock, "PLAYER_LOGIN")
	Check("[SET] API en erreur : rien d'inscrit, sans erreur", ok and NS.settingsCategory == nil
		and #W.added == 0 and #NS.errors == errors)
	L3.Reset()
end

-- ---------------------------------------------------------------------------
-- 2. Bouton des addons de la minicarte
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes (lot 3) : bouton des addons de la minicarte")
	ResetWorld()
	L3.Reset()
	local ok = pcall(Mock.Fire, Mock, "PLAYER_LOGIN")
	Check("[CMP] sans AddonCompartmentFrame : rien, sans erreur", ok and NS.compartmentEntry == nil
		and QNS:RegisterAddonCompartment() == nil)

	local W = L3.InstallCompartment()
	Mock:Fire("PLAYER_LOGIN")
	Mock:Fire("PLAYER_LOGIN")
	NS:RegisterAddonCompartment()
	Check("[CMP] une entrée par addon, une seule fois", #W.entries == 2 and W.self == AddonCompartmentFrame, #W.entries)
	local r2q, qc = W.entries[1], W.entries[2]
	if r2q and r2q.text ~= "Ready2Quest" then r2q, qc = qc, r2q end
	Check("[CMP] nom de chaque addon", r2q.text == "Ready2Quest" and qc.text == "QuestCompanion")
	Check("[CMP] icône du bouton de minicarte, non cochable", r2q.icon == NS.Theme.LOGO_SMALL
		and r2q.icon == NS:EnsureMinimapButton().icon.texture and r2q.notCheckable == true and qc.notCheckable == true)

	-- clic : l'action du clic gauche du bouton de minicarte
	local calls = {}
	local defaults = { NS.DefaultCommand, QNS.DefaultCommand }
	NS.DefaultCommand = function() calls[#calls + 1] = "r2q" end
	QNS.DefaultCommand = function() calls[#calls + 1] = "qc" end
	r2q.func()
	qc.func()
	NS.minimapDragMoved = nil
	NS:EnsureMinimapButton():Click("LeftButton")
	Check("[CMP] clic : même action que le clic gauche de la minicarte", calls[1] == "r2q" and calls[2] == "qc"
		and calls[3] == "r2q", table.concat(calls, ","))
	NS.DefaultCommand, QNS.DefaultCommand = defaults[1], defaults[2]

	-- infobulle : nom, lignes de l'addon, clic gauche ; pas celles du bouton
	local setOwner, owner = GameTooltip.SetOwner, nil
	GameTooltip.SetOwner = function(_, o) owner = o end
	NS.score = 88
	GameTooltip.lines = {}
	local hover = CreateFrame("Button")
	r2q.funcOnEnter(hover)
	local text = table.concat(GameTooltip.lines, "\n")
	Check("[CMP] survol : infobulle au nom de l'addon", GameTooltip.shown == true and owner == hover
		and GameTooltip.lines[1] == NS.L.ADDON_NAME, text)
	Check("[CMP] survol : lignes de l'addon et clic gauche", text:find("88", 1, true) ~= nil
		and text:find(NS.L.MINIMAP_LEFT, 1, true) ~= nil, text)
	Check("[CMP] survol : sans glisser ni clic droit", text:find(NS.L.MINIMAP_DRAG, 1, true) == nil
		and text:find(NS.L.MINIMAP_RIGHT, 1, true) == nil, text)
	r2q.funcOnLeave(hover)
	Check("[CMP] sortie : infobulle masquée", GameTooltip.shown == false)
	GameTooltip.lines = {}
	qc.funcOnEnter()
	Check("[CMP] survol sans cadre : ancrée au bouton des addons", owner == AddonCompartmentFrame
		and GameTooltip.lines[1] == QNS.L.ADDON_NAME)
	-- le bouton de minicarte garde toutes ses lignes
	GameTooltip.lines = {}
	NS:EnsureMinimapButton().scripts.OnEnter(NS.minimapButton)
	text = table.concat(GameTooltip.lines, "\n")
	Check("[CMP] bouton de minicarte : infobulle inchangée", text:find(NS.L.MINIMAP_DRAG, 1, true) ~= nil
		and text:find(NS.L.MINIMAP_RIGHT, 1, true) ~= nil and owner == NS.minimapButton, text)
	GameTooltip.SetOwner = setOwner
	GameTooltip:Hide()

	-- API en erreur : pas d'erreur, pas de nouvel essai
	L3.Reset()
	W = L3.InstallCompartment(true)
	ok = pcall(Mock.Fire, Mock, "PLAYER_LOGIN")
	Check("[CMP] API en erreur : rien, sans erreur", ok and NS.compartmentEntry == false
		and NS:RegisterAddonCompartment() == nil)
	L3.Reset()
end

-- ---------------------------------------------------------------------------
-- 3. Boucles OnUpdate espacées
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes (lot 3) : boucles OnUpdate espacées")
	ResetWorld()
	Check("[THR] ns.Throttle dans les deux socles", type(NS.Throttle) == "function" and type(QNS.Throttle) == "function")

	local runs = {}
	local handler = NS.Throttle(0.2, function(frame, step, extra) runs[#runs + 1] = { frame = frame, step = step, extra = extra } end)
	local me = {}
	handler(me, 0.05)
	handler(me, 0.1)
	Check("[THR] rien avant l'intervalle", #runs == 0)
	handler(me, 0.05, "x")
	Check("[THR] l'intervalle atteint : un passage", #runs == 1 and runs[1].frame == me and runs[1].extra == "x")
	Check("[THR] reçoit le temps cumulé", runs[1] and math.abs(runs[1].step - 0.2) < 1e-9, runs[1] and runs[1].step)
	handler(me, 0.19)
	Check("[THR] cumul remis à zéro", #runs == 1)
	handler(me, 1.5)
	Check("[THR] grand écart : un seul passage", #runs == 2 and math.abs(runs[2].step - 1.69) < 1e-9)
	handler(me, nil)
	handler(me, "?")
	Check("[THR] écart illisible : compté zéro, sans erreur", #runs == 2)
	for _ = 1, 60 do handler(me, 1 / 60) end
	Check("[THR] une seconde à 60 images : au plus 5 passages", #runs - 2 <= 5 and #runs - 2 >= 4, #runs - 2)

	-- Boucles réelles : au plus un passage par intervalle, à 60 images/s
	-- (un premier grand écart vide le cumul laissé par les tests précédents)

	-- R2Q : sortie en attente dix fois par seconde, lieux à chaque image
	local exitCalls, placeCalls = 0, 0
	local update, place, pending = NS.UpdatePendingExit, NS.CheckPlaceMove, NS.pendingExit
	NS.UpdatePendingExit = function() exitCalls = exitCalls + 1 end
	NS.CheckPlaceMove = function() placeCalls = placeCalls + 1 end
	NS.pendingExit = { at = 0 }
	NS.eventFrame.scripts.OnUpdate(NS.eventFrame, 1)
	exitCalls, placeCalls = 0, 0
	for _ = 1, 60 do NS.eventFrame.scripts.OnUpdate(NS.eventFrame, 1 / 60) end
	Check("[THR] R2Q sortie en attente : au plus 10 par seconde", exitCalls >= 8 and exitCalls <= 10, exitCalls)
	Check("[THR] R2Q lieux : regardés à chaque image (espacés par eux-mêmes)", placeCalls == 60, placeCalls)
	Check("[THR] R2Q intervalle de la sortie", NS.EXIT_TICK == 0.1)
	NS.UpdatePendingExit, NS.CheckPlaceMove, NS.pendingExit = update, place, pending

	-- R2Q : camp (0,25 s)
	local campCalls, camp = 0, NS.UpdateCampFrame
	NS.UpdateCampFrame = function() campCalls = campCalls + 1 end
	NS.campEventFrame.scripts.OnUpdate(NS.campEventFrame, 1)
	campCalls = 0
	for _ = 1, 60 do NS.campEventFrame.scripts.OnUpdate(NS.campEventFrame, 1 / 60) end
	Check("[THR] R2Q camp : au plus 4 par seconde", campCalls >= 3 and campCalls <= 4, campCalls)
	NS.UpdateCampFrame = camp

	-- QC : brillants (0,1 s), annonces (0,2 s)
	local counts = { shiny = 0, aura = 0, flush = 0, glow = 0 }
	local saved = { QNS.ChestRevealStep, QNS.ShinyAuraTick, QNS.NotifyFlush, QNS.GlowUpdate }
	QNS.ChestRevealStep = function() counts.shiny = counts.shiny + 1 end
	QNS.ShinyAuraTick = function() counts.aura = counts.aura + 1 end
	QNS.NotifyFlush = function() counts.flush = counts.flush + 1 end
	QNS.GlowUpdate = function() counts.glow = counts.glow + 1 end
	for _, frame in ipairs({ QNS.shinyEventFrame, QNS.notifyEventFrame }) do
		frame.scripts.OnUpdate(frame, 1)
	end
	for key in pairs(counts) do counts[key] = 0 end
	for _ = 1, 60 do
		for _, frame in ipairs({ QNS.shinyEventFrame, QNS.notifyEventFrame }) do
			frame.scripts.OnUpdate(frame, 1 / 60)
		end
	end
	Check("[THR] QC coffre et aura : au plus 10 par seconde", counts.shiny >= 8 and counts.shiny <= 10
		and counts.aura == counts.shiny, counts.shiny)
	Check("[THR] QC annonces en attente : au plus 5 par seconde", counts.flush >= 4 and counts.flush <= 5, counts.flush)
	Check("[THR] QC éclat du liseré : à chaque image", counts.glow == 60, counts.glow)
	QNS.ChestRevealStep, QNS.ShinyAuraTick, QNS.NotifyFlush, QNS.GlowUpdate = saved[1], saved[2], saved[3], saved[4]

	-- éclat éteint et déjà caché : on ne touche plus aux bords
	local hides = 0
	local function Edge() return { Hide = function() hides = hides + 1 end, Show = function() end, SetAlpha = function() end } end
	local frame, until_ = QNS.companionFrame, QNS.companionBubbleUntil
	QNS.companionFrame = { glow = { Edge(), Edge(), Edge(), Edge() }, glowAlpha = 0.4 }
	QNS.companionBubbleUntil = nil
	QNS:GlowUpdate(Mock.now)
	Check("[THR] éclat qui s'éteint : bords cachés une fois", hides == 4 and QNS.companionFrame.glowAlpha == 0, hides)
	QNS:GlowUpdate(Mock.now)
	QNS:GlowUpdate(Mock.now)
	Check("[THR] éclat déjà éteint : plus rien à chaque image", hides == 4, hides)
	QNS.companionFrame, QNS.companionBubbleUntil = frame, until_
end

for name, value in pairs(L3.saved) do _G[name] = value end
