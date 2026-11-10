-- Bindings.lua -- raccourcis clavier (QuestCompanion 2.8.0)
--
-- Deux raccourcis dans le menu Raccourcis du jeu (Bindings.xml, section
-- « QuestCompanion ») : ouvrir les hauts faits (le carnet sur sa page Hauts
-- faits ; déjà ouvert sur cette page : fermé) et ouvrir le carnet.
-- Touche Y par défaut pour les hauts faits, comme dans le jeu : une seule
-- fois par personnage, hors combat (sinon à la fin du combat), et seulement
-- si Y ne sert à rien ; jamais par-dessus un raccourci existant. Le drapeau
-- est gardé : un joueur qui retire Y ne le voit jamais revenir.
-- Réglables aussi dans les options (page Carnet de voyage, section Hauts
-- faits) : « Changer » attend la touche suivante (Maj, Ctrl, Alt compris ;
-- Échap annule ; une touche déjà prise demande confirmation), « Retirer »
-- enlève la touche. Jamais en combat (le client refuse SetBinding).
-- 2.10.0 : deux raccourcis de plus, sans touche par défaut : afficher /
-- masquer le compagnon, lancer le filet (le meilleur candidat, jamais en
-- combat) ; leurs cartes sont sur la page Compagnon.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	BIND_HEADER       = "QuestCompanion",
	BIND_FEATS        = "Ouvrir les hauts faits",
	BIND_JOURNAL      = "Ouvrir le carnet",
	BIND_DEFAULT_MSG  = "Touche %s : hauts faits (modifiable dans Raccourcis)",
	BIND_NONE         = "aucune",
	BIND_PRESS        = "Appuie sur la touche voulue (Maj, Ctrl ou Alt en plus si tu veux). Échap : annuler.",
	BIND_CONFLICT     = "« %s » sert déjà à : %s. La remplacer ?",
	BIND_REPLACE      = "Remplacer",
	BIND_CANCEL       = "Annuler",
	BIND_DONE         = "Touche %s : %s.",
	BIND_CLEARED      = "%s : plus de touche.",
	BIND_COMBAT       = "Pas pendant un combat : les raccourcis se changent après.",
	OPT_BIND_FEATS    = "Raccourci des hauts faits",
	OPT_BIND_JOURNAL  = "Raccourci du carnet",
	OPT_BIND_CHANGE   = "Changer",
	OPT_BIND_CLEAR    = "Retirer",
	OPT_BIND_DESC     = "Aussi dans le menu Raccourcis du jeu, section QuestCompanion.",
	BIND_TOGGLE       = "Afficher / masquer le compagnon",
	BIND_NET          = "Lancer le filet",
	BIND_NET_COMBAT   = "Pas pendant un combat : le filet attend la fin du combat.",
	OPT_BIND_TOGGLE   = "Raccourci du compagnon",
	OPT_BIND_NET      = "Raccourci du filet",
	BIND_HUNT         = "Mode chasse (lancer / arrêter)",
	OPT_BIND_HUNT     = "Raccourci du mode chasse",
}
local EN = {
	BIND_HEADER       = "QuestCompanion",
	BIND_FEATS        = "Open achievements",
	BIND_JOURNAL      = "Open the journal",
	BIND_DEFAULT_MSG  = "%s key: achievements (change it in Key Bindings)",
	BIND_NONE         = "none",
	BIND_PRESS        = "Press the key you want (with Shift, Ctrl or Alt if you like). Escape: cancel.",
	BIND_CONFLICT     = "\"%s\" is already used for: %s. Replace it?",
	BIND_REPLACE      = "Replace",
	BIND_CANCEL       = "Cancel",
	BIND_DONE         = "%s key: %s.",
	BIND_CLEARED      = "%s: no key any more.",
	BIND_COMBAT       = "Not in combat: change key bindings afterwards.",
	OPT_BIND_FEATS    = "Achievements key",
	OPT_BIND_JOURNAL  = "Journal key",
	OPT_BIND_CHANGE   = "Change",
	OPT_BIND_CLEAR    = "Remove",
	OPT_BIND_DESC     = "Also in the game's Key Bindings menu, QuestCompanion section.",
	BIND_TOGGLE       = "Show / hide the companion",
	BIND_NET          = "Throw the net",
	BIND_NET_COMBAT   = "Not in combat: the net waits until the fight is over.",
	OPT_BIND_TOGGLE   = "Companion key",
	OPT_BIND_NET      = "Net key",
	BIND_HUNT         = "Hunt mode (start / stop)",
	OPT_BIND_HUNT     = "Hunt mode key",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.BINDINGS_STRINGS = { fr = FR, en = EN } end

ns.BINDINGS = { feats = "QUESTCOMPANION_FEATS", journal = "QUESTCOMPANION_JOURNAL",
	toggle = "QUESTCOMPANION_TOGGLE", net = "QUESTCOMPANION_NET", hunt = "QUESTCOMPANION_HUNT" }
ns.BINDING_DEFAULT_KEY = "Y"
-- Y déjà posé sur ces actions du jeu compte comme libre : sur Forever, Y ouvre
-- les hauts faits de Blizzard, vides (2.8.3)
ns.BINDING_REPLACEABLE = { TOGGLEACHIEVEMENT = true }
-- 2 : tentative faite avec la règle 2.8.3 (true = ancienne tentative, refaite une fois)
local TRIED = 2
local B = ns.BINDINGS
local LABEL = { feats = "BIND_FEATS", journal = "BIND_JOURNAL", toggle = "BIND_TOGGLE", net = "BIND_NET", hunt = "BIND_HUNT" }
-- touches seules qui ne font qu'ajouter un modificateur
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	LMETA = true, RMETA = true, UNKNOWN = true }

-- noms du menu Raccourcis et fonctions appelées par Bindings.xml
_G.BINDING_HEADER_QUESTCOMPANION = L.BIND_HEADER
_G.BINDING_NAME_QUESTCOMPANION_FEATS = L.BIND_FEATS
_G.BINDING_NAME_QUESTCOMPANION_JOURNAL = L.BIND_JOURNAL
_G.QuestCompanion_ToggleFeats = function() ns:ToggleJournalFeats() end
_G.QuestCompanion_ToggleJournal = function() if ns.ToggleJournal then ns:ToggleJournal() end end
_G.BINDING_NAME_QUESTCOMPANION_TOGGLE = L.BIND_TOGGLE
_G.BINDING_NAME_QUESTCOMPANION_NET = L.BIND_NET
_G.QuestCompanion_ToggleCompanion = function() if ns.CompanionToggleShown then return ns:CompanionToggleShown() end end
_G.QuestCompanion_ThrowNet = function() return ns:BindingThrowNet() end
-- 2.15.0 : mode chasse (CaptureSpecimens.lua) : lancé jusqu'à l'arrêt, ou arrêté
_G.BINDING_NAME_QUESTCOMPANION_HUNT = L.BIND_HUNT
_G.QuestCompanion_ToggleHunt = function() if ns.HuntToggle then return ns:HuntToggle() end end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end
local function InCombat()
	if Call(G("InCombatLockdown")) then return true end
	return false
end
local function Save()
	local set = Call(G("GetCurrentBindingSet")) or 2
	Call(G("SaveBindings"), set)
end
local function Action(key)
	local action = Call(G("GetBindingAction"), key)
	if type(action) ~= "string" then return "" end
	return action
end

-- 2.10.0 : le filet au clavier : le meilleur candidat, comme un clic sur le
-- filet, sans le panneau de choix (ancré au filet) ; refusé en combat, et
-- dit dans le chat quand il n'y a rien
function ns:BindingThrowNet()
	if not (self.CaptureThrow and self.CaptureQueuePrune) then return false end
	if InCombat() or Call(G("UnitAffectingCombat"), "player") then self:Print(L.BIND_NET_COMBAT); return false end
	-- 2.15.0 : la carte de préparation ouverte : son candidat, avec l'aide choisie
	if self.CapturePrepShown and self:CapturePrepShown() then return self:CapturePrepLaunch() and true or false end
	if #self:CaptureQueuePrune() == 0 then self:Print(L.CAPTURE_Q_NOTHING); return false end
	-- sinon tout de suite (pas de carte), avec l'aide déjà choisie
	return self:CaptureThrow() and true or false
end

-- Les hauts faits : le carnet sur cette page ; déjà ouvert dessus : fermé
function ns:ToggleJournalFeats()
	local frame = self.journalFrame
	if frame and frame:IsShown() and frame.kind == "feats" then
		frame:Hide()
		return nil
	end
	return self.OpenJournalFeats and self:OpenJournalFeats() or nil
end

-- La touche d'un raccourci (la première), ou nil
function ns:BindingKey(which)
	local key = Call(G("GetBindingKey"), B[which])
	return type(key) == "string" and key ~= "" and key or nil
end
function ns:BindingKeyText(which)
	local key = self:BindingKey(which)
	if not key then return L.BIND_NONE end
	local text = Call(G("GetBindingText"), key)
	return type(text) == "string" and text ~= "" and text or key
end

-- ---------------------------------------------------------------------------
-- Y par défaut : une fois par personnage, hors combat, seulement si Y est libre
-- ---------------------------------------------------------------------------
function ns:BindingDefaultTry()
	local char = self:CharData()
	if char.featsKeyTried == TRIED then return "done" end
	if InCombat() then
		self.bindingDeferred = true
		return "combat"
	end
	self.bindingDeferred = nil
	if type(G("GetBindingAction")) ~= "function" or type(G("SetBinding")) ~= "function" then return "noapi" end
	char.featsKeyTried = TRIED
	local key = ns.BINDING_DEFAULT_KEY
	local current = Action(key)
	if current == B.feats then return "bound" end
	if current ~= "" and not ns.BINDING_REPLACEABLE[current] then return "taken" end
	if Call(G("SetBinding"), key, B.feats) == false then return "refused" end
	Save()
	self:Print(self:F("BIND_DEFAULT_MSG", key))
	return "bound"
end

-- ---------------------------------------------------------------------------
-- Changer, retirer (options)
-- ---------------------------------------------------------------------------
-- Pose `key` sur le raccourci (ses anciennes touches retirées)
function ns:BindingApply(which, key)
	if not (B[which] and type(key) == "string" and key ~= "") then return false end
	if InCombat() then self:Print(L.BIND_COMBAT); return false end
	for _, old in ipairs({ Call(G("GetBindingKey"), B[which]) }) do
		if type(old) == "string" and old ~= key then Call(G("SetBinding"), old, nil) end
	end
	if Call(G("SetBinding"), key, B[which]) == false then return false end
	Save()
	self:Print(self:F("BIND_DONE", key, L[LABEL[which]]))
	self:BindingCaptureStop()
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return true
end

function ns:BindingClear(which)
	if not B[which] then return false end
	if InCombat() then self:Print(L.BIND_COMBAT); return false end
	local any = false
	for _, old in ipairs({ Call(G("GetBindingKey"), B[which]) }) do
		if type(old) == "string" then Call(G("SetBinding"), old, nil); any = true end
	end
	if any then Save() end
	self:Print(self:F("BIND_CLEARED", L[LABEL[which]]))
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return any
end

-- La fenêtre d'attente : un message, puis (touche déjà prise) Remplacer / Annuler
local function CaptureFrame(self)
	if self.bindingCapture then return self.bindingCapture end
	if not (Theme and Theme.CreateToast) then return nil end
	local frame = Theme.CreateToast(UIParent, 340, 96, { strata = "FULLSCREEN_DIALOG", name = "QuestCompanionBindingCapture" })
	if not frame then return nil end
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	frame:EnableMouse(true)
	local left = frame.contentLeft or 14
	frame.text = Theme.Text(frame, Theme.F_BODY, Theme.TEXT)
	frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -12)
	frame.text:SetWidth(340 - left - 14)
	frame.text:SetJustifyH("LEFT")
	if frame.text.SetWordWrap then frame.text:SetWordWrap(true) end
	frame.replace = Theme.CreateButton(frame, "auto", 24, L.BIND_REPLACE, function(b)
		local f = b:GetParent()
		if f.pending then ns:BindingApply(f.which, f.pending) end
	end, "primary")
	frame.replace:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
	frame.cancel = Theme.CreateButton(frame, "auto", 24, L.BIND_CANCEL, function() ns:BindingCaptureStop() end)
	frame.cancel:SetPoint("RIGHT", frame.replace, "LEFT", -8, 0)
	if frame.EnableKeyboard then pcall(frame.EnableKeyboard, frame, true) end
	frame:SetScript("OnKeyDown", function(f, key)
		local ok, err = pcall(ns.BindingCaptureKey, ns, key)
		if not ok and ns.RecordError then ns:RecordError("bindings:key", err) end
	end)
	frame:Hide()
	self.bindingCapture = frame
	return frame
end

function ns:BindingCaptureStart(which)
	if not B[which] then return false end
	if InCombat() then self:Print(L.BIND_COMBAT); return false end
	local frame = CaptureFrame(self)
	if not frame then return false end
	frame.which, frame.pending = which, nil
	frame.text:SetText(L.BIND_PRESS)
	frame.replace:Hide()
	frame.cancel:Show()
	if frame.SetPropagateKeyboardInput then pcall(frame.SetPropagateKeyboardInput, frame, false) end
	frame:Show()
	return true
end

function ns:BindingCaptureStop()
	local frame = self.bindingCapture
	if frame then frame.pending = nil; frame:Hide() end
end

-- La touche pressée pendant l'attente : rend "wait" (modificateur seul),
-- "cancel" (Échap), "conflict" (déjà prise : confirmation), true (posée)
function ns:BindingCaptureKey(key)
	local frame = self.bindingCapture
	if not (frame and frame:IsShown() and type(key) == "string") then return nil end
	if MODIFIERS[key] then return "wait" end
	if key == "ESCAPE" then self:BindingCaptureStop(); return "cancel" end
	if frame.pending then return "conflict" end
	local combo = (Call(G("IsAltKeyDown")) and "ALT-" or "") .. (Call(G("IsControlKeyDown")) and "CTRL-" or "")
		.. (Call(G("IsShiftKeyDown")) and "SHIFT-" or "") .. key
	local action = Action(combo)
	if action ~= "" and action ~= B[frame.which] then
		frame.pending = combo
		local name = G("BINDING_NAME_" .. action)
		frame.text:SetText(self:F("BIND_CONFLICT", combo, type(name) == "string" and name or action))
		frame.replace:Show()
		return "conflict"
	end
	return self:BindingApply(frame.which, combo)
end

-- ---------------------------------------------------------------------------
-- Options : page Carnet de voyage, section Hauts faits ; la carte montre la
-- touche, « Changer » (bouton de la carte) et « Retirer » (ajouté)
-- ---------------------------------------------------------------------------
local ROWS = { bindFeats = "feats", bindJournal = "journal", bindToggle = "toggle", bindNet = "net", bindHunt = "hunt" }
do
	for _, page in ipairs(ns.OPTION_PAGES or {}) do
		if page.id == "journal" and type(page.rows) == "table" then
			local at, present = nil, false
			for index, row in ipairs(page.rows) do
				if row.key == "featTitleForm" or (not at and row.key == "featStats") then at = index + 1 end
				if row.key == "bindFeats" then present = true end
			end
			if at and not present then
				table.insert(page.rows, at, { key = "bindJournal", label = "OPT_BIND_JOURNAL", kind = "action", button = "OPT_BIND_CHANGE",
					describe = function() return L.OPT_BIND_DESC end })
				table.insert(page.rows, at, { key = "bindFeats", label = "OPT_BIND_FEATS", kind = "action", button = "OPT_BIND_CHANGE",
					describe = function() return L.OPT_BIND_DESC end })
			end
		end
		-- 2.10.0 : page Compagnon, juste après « Afficher le compagnon »
		if page.id == "companionMain" and type(page.rows) == "table" then
			local at, present = nil, false
			for index, row in ipairs(page.rows) do
				if row.key == "companionShow" then at = index + 1 end
				if row.key == "bindToggle" then present = true end
			end
			if at and not present then
				table.insert(page.rows, at, { key = "bindHunt", label = "OPT_BIND_HUNT", kind = "action", button = "OPT_BIND_CHANGE",
					describe = function() return L.OPT_BIND_DESC end })
				table.insert(page.rows, at, { key = "bindNet", label = "OPT_BIND_NET", kind = "action", button = "OPT_BIND_CHANGE",
					describe = function() return L.OPT_BIND_DESC end })
				table.insert(page.rows, at, { key = "bindToggle", label = "OPT_BIND_TOGGLE", kind = "action", button = "OPT_BIND_CHANGE",
					describe = function() return L.OPT_BIND_DESC end })
			end
		end
	end
	local run = ns.RunOptionAction
	function ns:RunOptionAction(key, ...)
		if ROWS[key] then return self:BindingCaptureStart(ROWS[key]) end
		if run then return run(self, key, ...) end
	end
	local refresh = ns.RefreshOptions
	if refresh then
		function ns:RefreshOptions(...)
			local a, b = refresh(self, ...)
			local frame = self.optionsFrame
			for _, card in ipairs(frame and frame.rows or {}) do
				local which = card.def and ROWS[card.def.key]
				if which then
					if not card.clearButton and card.button then
						card.clearButton = Theme.CreateButton(card, "auto", 22, L.OPT_BIND_CLEAR, function() ns:BindingClear(which) end, "outline")
						card.clearButton:SetPoint("RIGHT", card.button, "LEFT", -8, 0)
						card.value:ClearAllPoints()
						card.value:SetPoint("RIGHT", card.clearButton, "LEFT", -10, 0)
					end
					card.value:SetText(self:BindingKeyText(which))
					card.value:Show()
					if card.clearButton then
						if self:BindingKey(which) then card.clearButton:Show() else card.clearButton:Hide() end
					end
				end
			end
			return a, b
		end
	end
end

-- ---------------------------------------------------------------------------
-- Événements : connexion (Y par défaut), fin de combat (essai reporté)
-- ---------------------------------------------------------------------------
local ok, frame = pcall(CreateFrame, "Frame")
if ok and frame then
	pcall(frame.RegisterEvent, frame, "PLAYER_LOGIN")
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	frame:SetScript("OnEvent", function(_, event)
		-- entrée en combat : la fenêtre de saisie lâche le clavier (sinon elle
		-- avalerait les touches du combat)
		if event == "PLAYER_REGEN_DISABLED" then
			local shown = ns.bindingCapture and ns.bindingCapture:IsShown()
			if shown then pcall(ns.BindingCaptureStop, ns) end
			return
		end
		if event == "PLAYER_REGEN_ENABLED" and not ns.bindingDeferred then return end
		local done, err = pcall(ns.BindingDefaultTry, ns)
		if not done and ns.RecordError then ns:RecordError("bindings:default", err) end
	end)
	ns.bindingEventFrame = frame
end

if ns.Mark then ns.Mark("Bindings") end
