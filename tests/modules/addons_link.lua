-- Addons liés (QuestCompanion 3.0.1, Ready2Quest 1.34.0) : l'onglet « Addons
-- liés » du carnet (deux styles, dernier de la colonne, qui tient), la carte
-- de Ready2Quest dans ses trois états (chargé, désactivé, absent), les liens
-- à copier ; dans les réglages de Ready2Quest, le bloc Quest Companion dans
-- les mêmes trois états ; ouvreurs, encres, textes FR/EN, visite du carnet.
local Check, Say, ResetWorld, NS, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.QNS, T.Mock

local A = { saved = {} }
for _, name in ipairs({ "C_AddOns", "Ready2Quest", "QuestCompanion", "InCombatLockdown", "UnitAffectingCombat",
	"StaticPopupDialogs", "StaticPopup_Show", "ReloadUI", "UnitLevel", "C_Timer" }) do
	A.saved[name] = { value = rawget(_G, name) }
end

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

-- C_AddOns de la maquette : `state` = "loaded" | "disabled" | "missing"
function A.AddOns(name, state, version)
	A.enabled = {}
	_G.C_AddOns = {
		IsAddOnLoaded = function(n) return n == name and state == "loaded" end,
		GetAddOnMetadata = function(n, field)
			if n ~= name or state == "missing" then return nil end
			if field == "Version" then return version end
			if field == "IconTexture" then return "Interface\\AddOns\\" .. name .. "\\Textures\\logo_petit" end
		end,
		DoesAddOnExist = function(n) return n == name and state ~= "missing" end,
		EnableAddOn = function(n, who) A.enabled[#A.enabled + 1] = tostring(n) .. "/" .. tostring(who) end,
	}
end

function A.Popups()
	_G.StaticPopupDialogs = {}
	A.popup = nil
	_G.StaticPopup_Show = function(which, text, _, data)
		local box = CreateFrame("EditBox", nil, UIParent)
		box.HighlightText = function(self) self.highlighted = true end
		local dialog = { which = which, text = text, data = data, editBox = box }
		box.GetParent = function() return dialog end
		A.popup = dialog
		local def = StaticPopupDialogs[which]
		if def and def.OnShow then def.OnShow(dialog) end
		return dialog
	end
	_G.ReloadUI = function() A.reloaded = true end
end

function A.Reset(style)
	ResetWorld()
	if QNS.journalFrame then QNS.journalFrame:Hide() end
	QNS.journalFrame, QNS.uiStyleCache = nil, {}
	QNS:DB().journalTab, QNS:DB().journalState = nil, nil
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return A.combat == true end
	_G.UnitAffectingCombat = function() return false end
	_G.C_Timer = nil
	if style == "azeroth" then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	QNS:AzerothAtlasOK(true)
	QNS:DB().companionStyle = style
	QNS:CompanionData().tutoDone = true
	A.combat = nil
	A.Popups()
end

function A.Restore()
	for name, entry in pairs(A.saved) do _G[name] = entry.value end
	if QNS.journalFrame then QNS.journalFrame:Hide() end
	QNS.journalFrame, QNS.uiStyleCache = nil, {}
	Mock.InstallAtlas(nil)
	ResetWorld()
end

function A.Open()
	QNS:ToggleJournal(true)
	QNS:SelectJournalKind("addons")
	return QNS.journalFrame
end

-- 1. L'onglet, dans les deux styles ---------------------------------------------------------
do
	local s = Steps()
	for _, style in ipairs({ "sobre", "azeroth" }) do
		A.Reset(style)
		local f = A.Open()
		local item, guide = f.sections.addons, f.sections.guide
		s.ok(style .. " : entrée « Addons liés »", item and item.text and item.text:GetText() == "Addons liés")
		s.ok(style .. " : sous le Guide, en dernier", item and guide and select(5, item:GetPoint()) < select(5, guide:GetPoint())
			and QNS.JOURNAL_SECTIONS[#QNS.JOURNAL_SECTIONS] == "addons")
		s.ok(style .. " : la page s'ouvre", f.kind == "addons" and f.addons:IsShown() and f.header.title:GetText() == "Addons liés")
		local pane = f.addons
		local lay = QNS.JOURNAL_ADDONS_LAYOUT
		local ui = QNS.JournalUI
		local last = ui.TOP - lay.togetherY - 26 - (lay.facts - 1) * lay.factStep - 2 * 15
		s.ok(style .. " : tout tient au-dessus de la pagination", last > ui.PAGER_Y, last)
		s.ok(style .. " : carte, cinq points, quatre faits", pane.card and #pane.card.points == 5 and #pane.facts == 4)
		if style == "azeroth" then
			s.ok("azeroth : encres mesurées", pane.card.name.azRole == "addons.name" and pane.card.points[1].azRole == "addons.text"
				and pane.facts[1].azRole == "addons.text" and pane.together.label.azRole == "addons.head" and pane.azPage ~= nil)
		end
	end
	A.Restore()
	s.check("[ADD] onglet « Addons liés » sous le Guide, deux styles, page qui tient, encres Azeroth")
end

-- 2. Carte de Ready2Quest : trois états --------------------------------------------------------
do
	local s = Steps()
	A.Reset("sobre")
	-- chargé (les deux addons tournent ensemble ici)
	A.AddOns("Ready2Quest", "loaded", "1.34.0")
	local f = A.Open()
	local card = f.addons.card
	s.ok("chargé : version", card.status:GetText() == "Installé et actif · version 1.34.0", card.status:GetText())
	s.ok("chargé : icône du .toc", card.icon.texture == "Interface\\AddOns\\Ready2Quest\\Textures\\logo_petit")
	s.ok("chargé : bouton « Ouvrir Ready2Quest », pas de liens", card.button:IsShown() and card.button.text:GetText() == "Ouvrir Ready2Quest"
		and not f.addons.links[1].box:IsShown())
	local savedToggle, opened = NS.ToggleOptions, nil
	NS.ToggleOptions = function(self) opened = self end
	card.button:Click()
	NS.ToggleOptions = savedToggle
	s.ok("chargé : ouvre les réglages de Ready2Quest", opened == NS)
	-- désactivé
	_G.Ready2Quest = nil
	A.AddOns("Ready2Quest", "disabled", "1.34.0")
	QNS:RefreshJournal()
	s.ok("désactivé : comment l'activer", card.status:GetText():find("Active-le", 1, true) ~= nil
		and card.button.text:GetText() == "Activer pour ce personnage")
	card.button:Click()
	s.ok("désactivé : activé pour ce personnage, rechargement proposé", A.enabled[1] == "Ready2Quest/Testeur"
		and A.popup and A.popup.which == "QUESTCOMPANION_RELOAD")
	StaticPopupDialogs[A.popup.which].OnAccept(A.popup)
	s.ok("rechargement", A.reloaded == true)
	A.enabled = {}
	A.combat = true
	Mock:Reset()
	card.button:Click()
	s.ok("en combat : rien, et pourquoi", #A.enabled == 0 and Mock:Output():find("Pas en combat", 1, true) ~= nil)
	A.combat = nil
	-- absent
	A.AddOns("Ready2Quest", "missing")
	QNS:RefreshJournal()
	local links = f.addons.links
	s.ok("absent : pas de bouton, icône du client", not card.button:IsShown() and card.icon.texture == "Interface\\Icons\\INV_Misc_Bag_08")
	s.ok("absent : liens CurseForge et Wago", links[1].box:IsShown() and links[1].box:GetText() == "https://www.curseforge.com/wow/addons/ready2quest"
		and links[2].box:GetText() == "https://addons.wago.io/addons/ready-2-quest" and f.addons.linkHint:GetText():find("Ctrl+C", 1, true))
	local box = links[1].box
	box.HighlightText = function(self) self.highlighted = true end
	box:SetText("abc")
	box.scripts.OnTextChanged(box)
	s.ok("lien en lecture seule", box:GetText() == "https://www.curseforge.com/wow/addons/ready2quest")
	box.highlighted = nil
	box.scripts.OnEditFocusGained(box)
	s.ok("clic : tout sélectionné", box.highlighted == true)
	-- sans C_AddOns ni globale : absent, sans erreur
	_G.C_AddOns = nil
	s.ok("sans API : absent", QNS:AddonsR2QStatus() == "missing")
	A.Restore()
	s.check("[ADD] carte Ready2Quest : chargé (version, ouvrir), désactivé (activer, recharger), absent (liens à copier)")
end

-- 3. Réglages de Ready2Quest : le bloc Quest Companion ------------------------------------------
do
	local s = Steps()
	A.Reset("sobre")
	A.AddOns("QuestCompanion", "loaded", "3.0.1")
	s.ok("chargé : version", NS:QCLinkText():find("version 3.0.1", 1, true) ~= nil and NS:QCButtonLabel() == "Ouvrir le carnet")
	local savedToggle, opened = QNS.ToggleJournal, nil
	QNS.ToggleJournal = function(self, force) opened = { self, force } end
	s.ok("chargé : ouvre le carnet", NS:QCAction() == "journal" and opened and opened[1] == QNS and opened[2] == true)
	QNS.ToggleJournal = savedToggle
	-- la page Général : la carte suit l'état
	NS.optionsFrame = nil
	NS:ToggleOptions()
	local card
	for _, c in ipairs(NS.optionsFrame.rows) do if c.def and c.def.key == "qcAction" then card = c end end
	s.ok("page Général : carte et note", card ~= nil and NS.optionsFrame.pages.general.notes.qcNote ~= nil
		and card.button.text:GetText() == "Ouvrir le carnet")
	_G.QuestCompanion = nil
	A.AddOns("QuestCompanion", "disabled")
	NS:RefreshOptions()
	s.ok("désactivé : « Activer », comment faire", card.button.text:GetText() == "Activer"
		and NS:QCLinkText():find("écran de sélection du personnage", 1, true) ~= nil)
	s.ok("désactivé : activé, rechargement proposé", NS:QCAction() == "enabled" and A.enabled[1] == "QuestCompanion/Testeur"
		and A.popup.which == "READY2QUEST_RELOAD")
	A.AddOns("QuestCompanion", "missing")
	NS:RefreshOptions()
	s.ok("absent : « Liens »", card.button.text:GetText() == "Liens" and NS:QCLinkText():find("capture les créatures", 1, true) ~= nil)
	s.ok("absent : fenêtre de liens", NS:QCAction() == "links" and A.popup.which == "READY2QUEST_COPY_LINK")
	local dialog, def = A.popup, StaticPopupDialogs.READY2QUEST_COPY_LINK
	s.ok("lien CurseForge sélectionné", dialog.editBox:GetText() == "https://www.curseforge.com/wow/addons/quest-companion"
		and dialog.editBox.highlighted == true)
	s.ok("bouton Wago : son lien, la fenêtre reste", def.button2 == "Wago" and def.OnCancel(dialog, dialog.data, "clicked") == true
		and dialog.editBox:GetText() == "https://addons.wago.io/addons/quest-companion")
	dialog.editBox:SetText("zzz")
	def.EditBoxOnTextChanged(dialog.editBox)
	s.ok("lecture seule", dialog.editBox:GetText() == "https://addons.wago.io/addons/quest-companion")
	NS.optionsFrame:Hide()
	NS.optionsFrame = nil
	A.Restore()
	s.check("[ADD] réglages de Ready2Quest : Quest Companion chargé (ouvrir le carnet), désactivé (activer), absent (liens)")
end

-- 4. Textes, visite ---------------------------------------------------------------------------------
do
	local s = Steps()
	local function Parity(pack, label)
		local missing = {}
		for key, value in pairs(pack.fr) do
			if type(pack.en[key]) ~= "string" or pack.en[key] == "" or value == "" then missing[#missing + 1] = key end
		end
		for key in pairs(pack.en) do if pack.fr[key] == nil then missing[#missing + 1] = key end end
		s.ok(label .. " FR/EN", #missing == 0, table.concat(missing, ","))
		for key, value in pairs(pack.fr) do
			if value:find("\226\152\133", 1, true) or value:find("\226\152\134", 1, true) then s.ok(label .. " sans étoile", false, key) end
		end
	end
	Parity(QNS.JOURNAL_ADDONS_STRINGS, "carnet")
	Parity(NS.QC_LINK_STRINGS, "réglages")
	s.ok("socle : textes de lien", NS.L.LINK_COPY_HINT == "Ctrl+C pour copier" and QNS.L.LINK_RELOAD == "Recharger")
	s.ok("visite : étape « Addons liés »", type(QNS.L.TOUR_B_addons) == "string" and QNS.L.TOUR_B_addons ~= "TOUR_B_addons")
	local roles = {}
	for _, role in ipairs({ "addons.name", "addons.text", "addons.muted", "addons.ok", "addons.head" }) do
		if not QNS.AZEROTH_CONTRAST[role] then roles[#roles + 1] = role end
	end
	s.ok("encres déclarées (mesurées par azeroth_style)", #roles == 0, table.concat(roles, ","))
	s.check("[ADD] textes FR/EN, sans étoile ; étape de visite ; encres déclarées")
end
