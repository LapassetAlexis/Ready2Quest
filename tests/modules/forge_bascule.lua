-- QuestCompanion 3.1.0 : la bascule vers le thème forgé. L'état du produit
-- (ancien habillage coupé : QNS.AZEROTH_LEGACY faux, choix « azeroth »),
-- avec ET sans les atlas du client : le thème forgé est posé, et chaque
-- surface (carnet, fiche de dresseur, confirmation, panneau d'allure,
-- bandeaux, scène de capture, volée, choix au filet, compagnon, bulle des
-- visites) se construit sans erreur sur son chemin du socle : uiStyle
-- « sobre », clé de style « forge », jamais frame.azeroth, habillée par le
-- socle quand c'est une fenêtre. Bascule à chaud forgé -> Sobre -> forgé :
-- les bons cadres reviennent, aucun n'est refait deux fois (pas de fuite),
-- aucune brique forgée dans un cadre du Sobre. Décor du Voile d'hiver
-- posé sans erreur sur ces cadres.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme

local FIELDS = { "journalFrame", "trainerFrame", "effectsConfirm", "allurePanel", "companionFrame", "companionBubble",
	"captureToast", "journalToast", "guildFeatToast", "captureResult", "captureStage", "captureBatchFrame",
	"captureChooser", "captureNetButton" }
local GLOBALS = { "UnitGUID", "UnitName", "UnitFullName", "UnitExists", "UnitIsPlayer", "UnitLevel",
	"InCombatLockdown", "UnitAffectingCombat", "time" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local function Errors()
	local list = {}
	for _, e in ipairs(NS.errors or {}) do list[#list + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
	return table.concat(list, " | ")
end

-- le monde de départ ; atlas : les textures du client présentes ou non
local function Fresh(atlas, style)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle, NS.allureByStyle, NS.uiStyleCache, NS.tourUI = nil, nil, {}, nil
	NS.captureStages, NS.captureBatchFrames, NS.captureChoosers = nil, nil, nil
	NS.errors = {}
	_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-00000001" end end
	_G.UnitName = function(unit) if unit == "player" then return "Dyokrion" end end
	_G.UnitFullName = function(unit) if unit == "player" then return "Dyokrion", "Aeternalis" end end
	_G.UnitExists = function(unit) return unit == "player" end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	if atlas then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	NS:AzerothAtlasOK(true)
	NS:AzerothSceneAtlasOK(true)
	NS:DB().companionStyle = style or "azeroth"
	NS:DB().winterVeil = "off"
	NS:ApplyUIStyle()
	NS:CompanionData().tutoDone = true
	NS:CompanionUpdateVisibility()
end

local function Done()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	if NS.tourState then NS:TourStop() end
	NS.TOUR_DEFS.test = nil
	for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:AzerothSceneAtlasOK(true)
	ResetWorld()
end

-- une brique forgée (socle : frame.forged, nav.forged, header.forged…)
-- quelque part dans le cadre ou ses enfants ?
local function ForgedInside(root)
	if root.forged == true then return true end
	for _, child in ipairs(root.mockChildren or {}) do
		if ForgedInside(child) then return true end
	end
	return false
end

-- un cadre construit hors ancien habillage, sous le thème forgé
local function Plain(s, label, frame, window)
	s.ok(label .. " construit", frame ~= nil)
	if not frame then return end
	s.ok(label .. " : uiStyle sobre", frame.uiStyle == "sobre", frame.uiStyle)
	s.ok(label .. " : clé forge", frame.styleKey == "forge", frame.styleKey)
	s.ok(label .. " : jamais frame.azeroth", not frame.azeroth)
	if window then s.ok(label .. " : habillé par le socle", frame.skinDressed == true, tostring(frame.skinDressed)) end
end

local function Anchor()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(40, 40)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	f:Show()
	return f
end

-- 1. L'état du produit, avec et sans les atlas du client ------------------------------------------
for _, atlas in ipairs({ true, false }) do
	local tag = atlas and "avec les atlas du client" or "sans les atlas du client"
	do
		Say("-- bascule forgée : état du produit, " .. tag)
		Fresh(atlas)
		local s = Steps()
		s.ok("drapeau coupé", NS.AZEROTH_LEGACY == false)
		s.ok("choix azeroth, thème du socle azeroth", NS:UIStyleChoice() == "azeroth" and NS:UISkinChoice() == "azeroth")
		s.ok("thème forgé posé", Theme.Forged() and NS.QCForged())
		s.ok("ancien habillage coupé", NS:LegacyStyle() == "sobre" and NS:UIStyle() == "sobre" and not NS:AzerothOn()
			and not NS:AzerothScenesOn() and NS:JournalStyle() == "sobre")
		s.ok("clé de style forge", NS:StyleKey() == "forge" and NS:JournalStyleKey() == "forge")
		s.check("[BASC] " .. tag .. " : thème forgé posé, ancien habillage coupé, clé « forge »")
	end

	do
		Say("-- bascule forgée : fenêtres, " .. tag)
		Fresh(atlas)
		local s = Steps()
		local journal = NS:ToggleJournal(true)
		Plain(s, "carnet", journal, true)
		s.ok("carnet : nom global par clé", journal and journal:GetName() == "QuestCompanionJournalFrameForge",
			journal and journal:GetName())
		NS:SelectJournalKind("feats")
		NS:SelectJournalKind("menagerie")
		NS:SelectJournalKind("evolution")
		local confirm = NS:EnsureEffectsConfirm()
		if confirm then confirm:Show(); if confirm.hooks and confirm.hooks.OnShow then confirm.hooks.OnShow(confirm) end end
		Plain(s, "confirmation", confirm, true)
		if confirm then confirm:Hide() end
		local allure = NS:EnsureAllure()
		Plain(s, "allure", allure, false)
		NS:TrainerOpen(nil)
		local trainer = NS.trainerFrame
		Plain(s, "fiche", trainer, true)
		s.ok("fiche : nom global par clé", trainer and trainer:GetName() == "QuestCompanionTrainerFrameForge",
			trainer and trainer:GetName())
		s.ok("sans erreur", Errors() == "", Errors())
		s.check("[BASC] " .. tag .. " : carnet, confirmation, allure, fiche de dresseur au socle, habillés, clé forge")
	end

	do
		Say("-- bascule forgée : bandeaux, scènes, compagnon, " .. tag)
		Fresh(atlas)
		local s = Steps()
		Plain(s, "bandeau Capture possible", NS:EnsureCaptureToast(), false)
		Plain(s, "bandeau du carnet", NS:EnsureJournalToast(), false)
		Plain(s, "bandeau de guilde", NS:EnsureGuildFeatToast(), false)
		Plain(s, "bandeau Capturé !", NS:EnsureCaptureResult(), false)
		local stage = NS:EnsureCaptureStage()
		Plain(s, "scène de capture", stage, false)
		-- (la scène pose frame.name, son nom de créature : le faux client y
		-- range aussi le nom global ; on lit donc la liste d'Échap)
		local named = false
		for _, name in ipairs(UISpecialFrames) do if name == "QuestCompanionCaptureStageForge" then named = true end end
		s.ok("scène : nom global par clé, inscrit pour Échap", named)
		Plain(s, "volée", NS:EnsureCaptureBatchFrame(), false)
		Plain(s, "choix au filet", NS:EnsureCaptureChooser(), false)
		local companion = NS.companionFrame or (NS.EnsureCompanionFrame and NS:EnsureCompanionFrame())
		Plain(s, "compagnon", companion, false)
		s.ok("compagnon : pas d'anneau de l'ancien habillage", companion and not (companion.azSkin and companion.azSkin:IsShown()))
		local a = Anchor()
		NS.TOUR_DEFS.test = { steps = { { id = "a", anchor = a, title = "TOUR_A1_T", text = "TOUR_A1", placement = "top" } } }
		NS:TourStart("test")
		local ui = NS.tourUI and NS.tourUI.forge
		local callout = ui and ui.callout
		s.ok("bulle des visites montrée (jeu de la clé forge)", callout and callout:IsShown())
		if callout then
			s.ok("bulle : uiStyle sobre, clé forge, nom par clé", callout.uiStyle == "sobre" and callout.styleKey == "forge"
				and callout:GetName() == "QuestCompanionTourCalloutForge", callout:GetName())
		end
		NS:TourStop()
		NS.TOUR_DEFS.test = nil
		s.ok("sans erreur", Errors() == "", Errors())
		s.check("[BASC] " .. tag .. " : bandeaux, scène, volée, choix au filet, compagnon, bulle des visites : socle, clé forge")
	end
end

-- 2. Bascule à chaud : forgé -> Sobre -> forgé, sans fuite -------------------------------------------
do
	Say("-- bascule forgée : à chaud, sans fuite")
	Fresh(true)
	local s = Steps()
	local journal = NS:ToggleJournal(true)
	NS:SelectJournalKind("feats")
	local toast = NS:EnsureCaptureToast()
	local result = NS:EnsureCaptureResult()
	local stage = NS:EnsureCaptureStage()
	local chooser = NS:EnsureCaptureChooser()
	local before = #Mock.frames
	NS:ApplyUIStyle()
	NS:ApplyUIStyle()
	s.ok("deux ApplyUIStyle de suite : mêmes cadres, aucun cadre créé", NS.journalFrame == journal
		and NS.captureToast == toast and NS.captureResult == result and #Mock.frames == before, #Mock.frames - before)
	NS:SetUIStyle("sobre")
	local sjournal, stoast = NS.journalFrame, NS:EnsureCaptureToast()
	local sstage, schooser = NS:EnsureCaptureStage(), NS:EnsureCaptureChooser()
	s.ok("Sobre : thème Sobre, clé sobre", not Theme.Forged() and NS:StyleKey() == "sobre")
	s.ok("Sobre : le carnet affiché remplacé (même page), le forgé caché", sjournal and sjournal ~= journal
		and sjournal:IsShown() and not journal:IsShown() and sjournal.kind == "feats" and sjournal.styleKey == "sobre")
	s.ok("Sobre : bandeau, scène et choix au filet de la clé sobre", stoast ~= toast and stoast.styleKey == "sobre"
		and sstage ~= stage and sstage.styleKey == "sobre" and schooser ~= chooser and schooser.styleKey == "sobre")
	s.ok("Sobre : aucune brique forgée dans le carnet, le bandeau, la scène", not ForgedInside(sjournal)
		and not ForgedInside(stoast) and not ForgedInside(sstage))
	s.ok("Sobre : carnet au nom du Sobre", sjournal and sjournal:GetName() == "QuestCompanionJournalFrame", sjournal and sjournal:GetName())
	local mid = #Mock.frames
	NS:SetUIStyle("azeroth")
	s.ok("forgé de nouveau : les mêmes cadres reviennent (gardés, pas refaits)", NS.journalFrame == journal
		and journal:IsShown() and not sjournal:IsShown() and NS:EnsureCaptureToast() == toast
		and NS:EnsureCaptureStage() == stage and NS:EnsureCaptureChooser() == chooser and NS:EnsureCaptureResult() == result)
	NS:SetUIStyle("sobre")
	s.ok("Sobre de nouveau : les cadres du Sobre reviennent", NS.journalFrame == sjournal and NS:EnsureCaptureToast() == stoast
		and NS:EnsureCaptureStage() == sstage)
	NS:SetUIStyle("azeroth")
	s.ok("allers-retours : aucun cadre créé après le premier passage", #Mock.frames == mid, #Mock.frames - mid)
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[BASC] à chaud forgé → Sobre → forgé : bons cadres, gardés par clé, pas de fuite, pas de brique forgée en Sobre")
	Done()
end

-- 3. Le Sobre inchangé : le carnet du choix Sobre -------------------------------------------------
do
	Say("-- bascule forgée : le carnet du Sobre")
	Fresh(true, "sobre")
	local s = Steps()
	local journal = NS:ToggleJournal(true)
	s.ok("thème Sobre posé", not Theme.Forged() and NS:StyleKey() == "sobre")
	s.ok("carnet Sobre : clé sobre, nom d'avant, pas d'habillage forgé", journal and journal.styleKey == "sobre"
		and journal.uiStyle == "sobre" and journal:GetName() == "QuestCompanionJournalFrame" and not journal.skinDressed)
	s.ok("carnet Sobre : aucune brique forgée", journal and not ForgedInside(journal))
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[BASC] Sobre : carnet sans brique forgée, nom et clé d'avant")
	Done()
end

-- 4. Le Voile d'hiver suit le choix Azeroth ; ses poses tiennent sur les cadres du socle --------------
do
	Say("-- bascule forgée : Voile d'hiver")
	Fresh(false)
	local s = Steps()
	NS:DB().winterVeil = "on"
	s.ok("décor actif au choix Azeroth, sans ancien habillage ni atlas", NS:WinterVeilActive() == true)
	NS:ToggleJournal(true)
	NS:EnsureCaptureToast()
	NS:EnsureCaptureResult()
	local active = NS:WinterVeilApply()
	s.ok("posé partout sans erreur (carnet et compagnon sans hôte : rien)", active == true and Errors() == "", Errors())
	s.ok("carnet : pas de décor de l'ancien habillage", NS.journalFrame and NS.journalFrame.wvDecor == nil)
	s.ok("compagnon : pas de décor de l'ancien habillage", NS.companionFrame and NS.companionFrame.wvDecor == nil)
	-- les effets de l'ancien habillage : rien (à re-loger par le lot du
	-- compagnon et des bandeaux), sans erreur
	local fx = { NS:AzerothShinyFX(), NS:AzerothLevelFX("Niveau 12 !", "level"),
		NS:AzerothRewardFX(NS:EnsureJournalToast()), NS:CompanionPaintRing(), NS:CarnetPaintRing() }
	s.ok("effets de l'ancien habillage : aucun, sans erreur", not fx[1] and not fx[2] and not fx[3] and Errors() == "", Errors())
	NS:SetUIStyle("sobre")
	s.ok("choix Sobre : décor éteint", NS:WinterVeilActive() == false and Errors() == "", Errors())
	s.check("[BASC] Voile d'hiver : suit le choix Azeroth, posé sans erreur sur les cadres du socle")
	Done()
end

-- 5. L'ancien habillage (drapeau rallumé) : ses bandeaux gardés par clé, sans fuite ------------------
do
	Say("-- bascule forgée : ancien habillage, sans fuite")
	T.Legacy(true)
	Fresh(true)
	local s = Steps()
	local toast, result = NS:EnsureJournalToast(), NS:EnsureCaptureResult()
	s.ok("bandeaux de l'ancien habillage : clé azeroth", toast.styleKey == "azeroth" and toast.uiStyle == "azeroth"
		and result.styleKey == "azeroth" and NS:StyleKey() == "azeroth")
	local before = #Mock.frames
	NS:ApplyUIStyle()
	NS:ApplyUIStyle()
	s.ok("deux ApplyUIStyle de suite : mêmes bandeaux, aucun cadre créé", NS:EnsureJournalToast() == toast
		and NS:EnsureCaptureResult() == result and #Mock.frames == before, #Mock.frames - before)
	NS:SetUIStyle("sobre")
	local sobre = NS:EnsureJournalToast()
	NS:SetUIStyle("azeroth")
	s.ok("Sobre puis Azeroth : le bandeau doré revient (gardé)", sobre ~= toast and sobre.styleKey == "sobre"
		and NS:EnsureJournalToast() == toast)
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[BASC] ancien habillage (T.Legacy) : bandeaux gardés par clé, deux ApplyUIStyle sans fuite")
	T.Legacy(false)
	Done()
end
