-- QuestCompanion 2.3.0 : la page Guide du carnet (JournalGuide.lua) ; Échap
-- et le « × » ferment la scène de capture et la liste du filet
-- (CaptureStage.lua, CaptureQueue.lua).
-- 3.0.0 : le tutoriel de la ménagerie en bulles est retiré (les visites
-- guidées de GuidedTour.lua le remplacent : tests/modules/qc30_tutoriel.lua) ;
-- ses tests sont partis avec lui.
--   * la page Guide : sommaire, sections, table des types avec les vraies
--     valeurs, pagination, boutons des tutoriels, aucun chevauchement (FR et EN).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()

local G = { saved = {}, random = math.random, units = {}, sounds = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"UnitAffectingCombat", "InCombatLockdown", "PlaySound" }
for _, name in ipairs(GLOBALS) do G.saved[name] = rawget(_G, name) end
G.savedShiny = NS.SHINY_CHANCE
local PLAYER = "Player-1-00000001"
local POOLS = NS.COMPANION_POOLS
local RULES = NS.COMPANION_RULES

function G.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function G.Install()
	local w = G
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = w.units[unit]; return u and u.name end
	_G.UnitExists = function(unit) return unit == "player" or w.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function() return false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function(unit) local u = w.units[unit]; return u and u.class or "normal" end
	_G.UnitCreatureType = function() return "Bête" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function(unit)
		if unit == "player" or unit == nil then return 20 end
		local u = w.units[unit]; return u and u.level or 20
	end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.InCombatLockdown = function() return w.combat == true end
	_G.UnitAffectingCombat = function() return w.combat == true end
	_G.PlaySound = function(id) w.sounds[#w.sounds + 1] = id; return true end
end
-- Monde neuf : compagnon connu (tutoriel de base vu), capture allumée, scène
-- animée coupée (la petite fenêtre suffit)
function G.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt",
		"captureQueueList", "captureNetButton", "captureToast" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.captureAppCache = nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	G.units, G.combat, G.sounds = {}, false, {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	G.Install()
	NS.SHINY_CHANCE = 1 / 150
	G.Roll(0.99)                      -- jamais de brillante au hasard
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = false
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	NS:CompanionUpdateVisibility()
end
function G.Roll(value)
	math.random = function(a, b)
		if a and b then return G.random(a, b) end
		if a then return G.random(a) end
		return value
	end
end
function G.SeeKill(npcID, fields)
	fields = fields or {}
	local guid = G.Guid(npcID, fields.spawn)
	fields.guid = guid
	fields.name = fields.name or ("Bête " .. npcID)
	G.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
	return guid
end
-- La bulle affichée : son réservoir (nil si rien n'est affiché)
function G.Key()
	local bubble = NS.companionBubble
	if not (bubble and bubble:IsShown()) then return nil end
	return NS.companionBubbleKey
end
function G.Text() return NS.companionBubbleText or "" end
function G.Login()
	NS.companionSession = nil
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
end
-- Joue la capture lancée jusqu'au verdict, puis jusqu'à la fermeture
function G.PlayCapture()
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Mock:Advance(NS.CAPTURE_STAGE_HOLD + 0.5); NS:CaptureTick(NS.Now())
end
function G.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = G.saved[name] end
	math.random = G.random
	NS.SHINY_CHANCE = G.savedShiny
	ResetWorld()
end
local function Count(list, value)
	local n = 0
	for _, v in ipairs(list) do if v == value then n = n + 1 end end
	return n
end

-- 5. Parité FR/EN des textes du guide ----------------------------------------------------
do
	Say("-- qc2 guide : parité fr/en")
	local function Specs(text)
		local list = {}
		for spec in tostring(text or ""):gsub("%%%%", ""):gmatch("%%[sd]") do list[#list + 1] = spec end
		return table.concat(list, ",")
	end
	local bad
	local guide = NS.GUIDE_STRINGS
	bad = {}
	for key, fr in pairs(guide.fr) do
		local en = guide.en[key]
		if type(en) ~= "string" or en == "" or Specs(fr) ~= Specs(en) then bad[#bad + 1] = key end
	end
	for key in pairs(guide.en) do if guide.fr[key] == nil then bad[#bad + 1] = key .. " (en seul)" end end
	table.sort(bad)
	Check("[GUIDE] page Guide : mêmes clés et arguments en français et en anglais", #bad == 0, table.concat(bad, ", "))
	Check("[GUIDE] la scène : « Clic ou Échap pour fermer », en deux langues",
		NS.CAPTURE_STAGE_STRINGS.fr.CAPTURE_STAGE_CLOSE:find("Échap", 1, true) ~= nil
		and NS.CAPTURE_STAGE_STRINGS.en.CAPTURE_STAGE_CLOSE:find("Escape", 1, true) ~= nil)
end

-- 6. La page Guide du carnet -------------------------------------------------------------------------
do
	Say("-- qc2 guide : page Guide")
	G.Reset()
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	Check("[GUIDE] entrée « Guide » au menu, en dernier", f.sections.guide and f.sections.guide.text.text == NS.L.JRN_SEC_guide
		and f.sections.guide.points[1].y < f.sections.progress.points[1].y)
	NS:SelectJournalKind("guide")
	local pane = f.guide
	Check("[GUIDE] la page s'ouvre, titre et sous-titre", f.kind == "guide" and pane:IsShown()
		and f.header.title.text == NS.L.JRN_SEC_guide and f.header.subtitle.text == NS.L.JRN_SUB_guide)
	Check("[GUIDE] sommaire : neuf sections, dans l'ordre", #pane.rows == 9 and #NS.GUIDE_SECTIONS == 9
		and pane.rows[1].label.text == NS.L.GUIDE_SEC_net and pane.rows[4].label.text == NS.L.GUIDE_SEC_effects
		and pane.rows[9].label.text == NS.L.GUIDE_SEC_settings)
	Check("[GUIDE] la première section ouverte : Le filet", f.guideSection == "net" and pane.rows[1].selected
		and pane.title.text == NS.L.GUIDE_SEC_net and pane.shown >= 3)
	Check("[GUIDE] Le filet : les chiffres des constantes (12 monstres, 30 s, 30 %)",
		pane.paras[2].text:find(NS.CAPTURE_QUEUE_MAX .. " monstres", 1, true) and pane.paras[2].text:find(NS.CAPTURE_QUEUE_TIME .. " s", 1, true)
		and pane.paras[5].text:find("normal " .. math.floor(NS.CAPTURE_RATES.normal * 100 + 0.5) .. " %", 1, true), pane.paras[5].text)
	Check("[GUIDE] Le filet : bandeau (Ignorer, Sourdine 5, 15, 30 et 60 min), sons, Échap",
		pane.paras[4].text:find("Sourdine", 1, true) and pane.paras[4].text:find("5, 15, 30 et 60 min", 1, true)
		and pane.paras[4].text:find(NS.L.OPT_DAILY_CAPTURE_SOUND, 1, true) and pane.paras[3].text:find("Échap", 1, true), pane.paras[4].text)
	Check("[GUIDE] Le filet : les aides avec leur facteur", pane.paras[5].text:find(NS:CaptureAidLabel("appat") .. " ×1,5", 1, true)
		and pane.paras[5].text:find(NS:CaptureAidLabel("sifflet"), 1, true), pane.paras[5].text)
	pane.rows[2]:Click()
	Check("[GUIDE] Les étoiles : 60 / 30 / 10 %", f.guideSection == "stars" and pane.title.text == NS.L.GUIDE_SEC_stars
		and pane.paras[1].text:find(NS.CAPTURE_STAR_ODDS[1] .. " %", 1, true) and pane.paras[1].text:find(NS.CAPTURE_STAR_ODDS[3] .. " %", 1, true)
		and pane.paras[3].text:find("+0,25", 1, true), pane.paras[1].text)
	NS:JournalGuidePick("shiny")
	Check("[GUIDE] Les brillantes : 1 sur 150, ×3, 1 sur 40 après 50, ×1,5 en zone scellée",
		pane.paras[1].text:find("1 chance sur 150", 1, true) and pane.paras[1].text:find("×" .. NS.SHINY_RANK_MULT, 1, true)
		and pane.paras[2].text:find("1 sur 40", 1, true) and pane.paras[2].text:find(NS.SHINY_CHAIN_KILLS .. " abattus", 1, true)
		and pane.paras[2].text:find("×1,5", 1, true), pane.paras[2].text)
	-- la table des types
	NS:JournalGuidePick("effects")
	local rows = NS:JournalGuideTypeRows()
	Check("[GUIDE] table des types : les huit types et la mascotte", #rows == 9 and rows[1].key == "beast" and rows[9].key == "mascot"
		and rows[2].label == NS:CreatureTypeLabel("humanoid"))
	Check("[GUIDE] … les vraies valeurs (base et plafond) depuis CompanionEffects",
		rows[2].hunt == NS:F("GUIDE_CAP", NS:F("EFF_capture_humanoid", 10), 40)
		and rows[1].comfort == NS:F("GUIDE_CAP", NS:F("EFF_decay_hunger", 10), 40)
		and rows[9].hunt == NS:F("GUIDE_CAP", NS:F("EFF_capture_all", 2), 10), rows[2].hunt)
	Check("[GUIDE] … en-tête Type · Chasse · Confort et les rangées affichées", pane.theads[1]:IsShown()
		and pane.theads[1].cells[2].text == NS.Theme.Upper(NS.L.GUIDE_COL_HUNT) and pane.trows[1]:IsShown()
		and pane.trows[1].cells[1].text == NS:CreatureTypeLabel("beast") and pane.trows[1].cells[2].text == rows[1].hunt)
	Check("[GUIDE] … la page est paginée, la pagination le dit", pane.blocks > pane.shown and pane.pager.position.text ~= ""
		and pane.hint.text == NS.L.GUIDE_MORE, pane.pager.position.text)
	local first = pane.shown
	NS:ScrollJournal(-1)
	Check("[GUIDE] molette : un bloc de plus", f.guideOffset == 1)
	for _ = 1, 40 do NS:ScrollJournal(-1) end
	local last = f.guideOffset
	Check("[GUIDE] … bornée : la dernière page montre le dernier bloc", last < pane.blocks and f.guideOffset + pane.shown == pane.blocks
		and pane.paras[pane.shown - 3] ~= nil, f.guideOffset .. " / " .. pane.blocks)
	local blocks = NS:JournalGuideBlocks("effects", pane.cols)
	local strength
	for _, block in ipairs(blocks) do if block.kind == "p" and block.text:find("rang normal", 1, true) then strength = block.text end end
	Check("[GUIDE] la force : ×1, ×1,5, ×2, ×2,5, +0,5 brillante, +0,25 par étoile, +0,25 par palier", strength
		and strength:find("×1,5", 1, true) and strength:find("×2,5", 1, true) and strength:find("+0,5", 1, true)
		and strength:find("+0,25 par étoile", 1, true) and strength:find("+0,25 par palier", 1, true), strength)
	local delay
	for _, block in ipairs(blocks) do if block.kind == "p" and block.text:find("confirmation", 1, true) then delay = block.text end end
	Check("[GUIDE] le délai de 2 minutes et le seuil de 50 %", delay and delay:find("2 minutes", 1, true)
		and blocks[#blocks - 1].text:find(NS.EFFECT_NEED_OK .. " %", 1, true), delay)
	for _ = 1, 40 do NS:ScrollJournal(1) end
	Check("[GUIDE] … retour en haut", f.guideOffset == 0 and pane.shown == first)
	pane.pager.down:Click()
	Check("[GUIDE] chevron : une page entière", f.guideOffset == first)
	-- sceaux, titres, missions, fiche, réglages
	NS:JournalGuidePick("seals")
	Check("[GUIDE] Sceaux : brillantes ×1,5", pane.paras[2].text:find("×" .. NS.MenagerieDecimal(NS.SEAL_SHINY_MULT), 1, true) ~= nil)
	NS:JournalGuidePick("titles")
	local titleBlocks = NS:JournalGuideBlocks("titles", pane.cols)
	local ranks = {}
	for _, block in ipairs(titleBlocks) do if block.kind == "row" and not block.head then ranks[#ranks + 1] = block end end
	Check("[GUIDE] Titres : paliers par type (10, 20 et 40 ; 5, 10 et 20) et les types rares",
		titleBlocks[1].text:find("10, 20 et 40", 1, true) and titleBlocks[1].text:find("5, 10 et 20", 1, true)
		and titleBlocks[1].text:find(NS:CreatureTypeLabel("dragonkin"), 1, true), titleBlocks[1].text)
	Check("[GUIDE] Titres : cinq rangs, 10 à 250 espèces, leurs noms et leurs récompenses", #ranks == #NS.TRAINER_RANKS
		and ranks[1].cells[1] == "10" and ranks[5].cells[1] == "250" and ranks[1].cells[2] == NS.L.TRAINER_apprentice
		and ranks[5].cells[2] == NS.L.TRAINER_grandmaster and ranks[1].cells[3] == NS:TrainerRankGift(NS.TRAINER_RANKS[1])
		and ranks[1].cells[3]:find(NS:CaptureAidLabel("appat"), 1, true), ranks[1].cells[3])
	NS:JournalGuidePick("missions")
	Check("[GUIDE] Missions : récompenses depuis MISSION_REWARDS, sifflet toutes les 10 captures",
		pane.paras[1].text:find(NS:CaptureAidLabel("appat"), 1, true) and pane.paras[1].text:find(NS:TreatLabel("festin"), 1, true)
		and pane.paras[2].text:find(NS:CaptureAidLabel("sifflet"), 1, true)
		and pane.paras[3].text:find(NS.CAPTURE_GIFT_EVERY .. " captures", 1, true), pane.paras[1].text)
	NS:JournalGuidePick("card")
	Check("[GUIDE] Fiche : /qc fiche, l'entrée du menu et le réglage", pane.paras[2].text:find("/qc fiche", 1, true)
		and pane.paras[2].text:find(NS.L.TRAINER_MENU, 1, true) and pane.paras[3].text:find(NS.L.OPT_DAILY_TRAINER, 1, true))
	NS:JournalGuidePick("settings")
	Check("[GUIDE] Réglages : sons, cadrage (Portrait, Buste, En pied), commandes", pane.paras[1].text:find(NS.L.OPT_DAILY_CAPTURE_SOUND, 1, true)
		and pane.paras[2].text:find(NS.L.OPT_COMP_FRAMING, 1, true) and pane.paras[2].text:find(NS.L.COMP_FRAMING_pied, 1, true)
		and pane.paras[3].text:find("/qc tuto", 1, true) and pane.paras[3].text:find("sourdine", 1, true)
		and pane.paras[4].text:find(NS.L.GUIDE_REPLAY, 1, true) and pane.paras[4].text:find(NS.L.GUIDE_REPLAY_JOURNAL, 1, true)
		and pane.paras[4].text:find("Maj + clic droit", 1, true), pane.paras[2].text)
	Check("[GUIDE] anciens noms de page : inchangés", (function() NS:SelectJournalKind("collection"); return f.kind == "evolution" end)())
	NS:SelectJournalKind("guide")
	Check("[GUIDE] la page retenue pour la prochaine ouverture", NS:DB().journalTab == "guide")
	f:Hide()
	-- ouverture directe sur une section
	NS:OpenJournalGuide("titles")
	Check("[GUIDE] OpenJournalGuide : ouvert sur la section demandée", f:IsShown() and f.kind == "guide" and f.guideSection == "titles")
	f:Hide()
end

-- 7. Aperçu : aucun chevauchement, en français puis en anglais -------------------------------------
do
	Say("-- qc2 guide : aperçu, chaque section sans chevauchement")
	local savedW, savedH = UIParent.width, UIParent.height
	local savedColor = rawget(_G, "CreateColor")
	_G.CreateColor = savedColor or Mock.CreateColor
	local ok, frame = pcall(Snap.scenes["qc-journal-guide"], T)
	_G.CreateColor = savedColor
	Check("[GUIDE] scène qc-journal-guide construite", ok and frame ~= nil, frame)
	if ok and frame then
		local function Clean(lang)
			local bad = {}
			for _, key in ipairs(NS.GUIDE_SECTIONS) do
				NS:JournalGuidePick(key)
				local pane = frame.guide
				local pages = 0
				repeat
					local overlaps, outside, count = Snap.Layout(frame)
					for _, o in ipairs(overlaps) do bad[#bad + 1] = lang .. " " .. key .. " : " .. o end
					for _, o in ipairs(outside) do bad[#bad + 1] = lang .. " " .. key .. " hors cadre : " .. o end
					if count < 10 then bad[#bad + 1] = lang .. " " .. key .. " : trop peu de texte" end
					-- le dernier bloc au-dessus de la pagination
					local pager = Snap.Rect(pane.pager, { memo = {} })
					for _, list in ipairs({ pane.paras, pane.heads, pane.trows, pane.theads }) do
						for _, region in ipairs(list) do
							if Snap.Visible(region) then
								local r = Snap.Rect(region, { memo = {} })
								if r and pager and r.top + r.height > pager.top - 4 then bad[#bad + 1] = lang .. " " .. key .. " : sous la pagination" end
							end
						end
					end
					local before = frame.guideOffset
					NS:ScrollJournal(-pane.shown)
					pages = pages + 1
				until frame.guideOffset == before or pages > 8
			end
			return bad
		end
		local bad = Clean("fr")
		Check("[GUIDE] français : aucun chevauchement, rien ne sort, le dernier bloc au-dessus de la pagination", #bad == 0, table.concat(bad, " | "))
		-- en anglais : les textes du guide, des effets, des types et des titres
		local swapped = {}
		for _, pack in ipairs({ NS.GUIDE_STRINGS, NS.EFFECT_STRINGS, NS.CREATURE_TYPE_STRINGS, NS.MENAGERIE_COLLECTION_STRINGS }) do
			for key, text in pairs(pack.en) do NS.L[key] = text; swapped[#swapped + 1] = key end
		end
		bad = Clean("en")
		local leftover = {}
		for _, key in ipairs(NS.GUIDE_SECTIONS) do
			for _, block in ipairs(NS:JournalGuideBlocks(key, frame.guide.cols)) do
				local texts = block.kind == "row" and block.cells or { block.text }
				for _, text in ipairs(texts) do if text:find("%%[sd]") then leftover[#leftover + 1] = key end end
			end
		end
		for _, key in ipairs(swapped) do NS.L[key] = nil end
		Check("[GUIDE] anglais : aucun chevauchement, rien ne sort", #bad == 0, table.concat(bad, " | "))
		Check("[GUIDE] anglais : aucun argument laissé en plan", #leftover == 0, table.concat(leftover, ", "))
		Check("[GUIDE] retour au français", NS.L.GUIDE_SEC_net == NS.GUIDE_STRINGS.fr.GUIDE_SEC_net)
		frame:Hide()
	end
	UIParent.width, UIParent.height = savedW, savedH
	ResetWorld()
end

-- 8. Échap et « × » : la scène de capture et la liste du filet ----------------------------------------
do
	Say("-- qc2 guide : fermer la scène et la liste")
	G.Reset()
	NS:DB().companionCaptureAnim = true
	G.SeeKill(5501, { name = "Ours" })
	NS.captureNetButton:Click("RightButton")
	local list = NS.captureQueueList
	Check("[GUIDE] la liste a un nom et un « × »", list and list:GetName() == "QuestCompanionCaptureList" and list.close ~= nil)
	local function Registered(name)
		for _, entry in ipairs(UISpecialFrames) do if entry == name then return true end end
		return false
	end
	Check("[GUIDE] la liste est inscrite pour Échap", Registered("QuestCompanionCaptureList"))
	list.close:Click()
	Check("[GUIDE] « × » : la liste se ferme", not list:IsShown())
	NS.captureNetButton:Click("RightButton")
	Check("[GUIDE] rouverte", list:IsShown())
	G.Roll(0)
	list.rows[1]:Click()
	Check("[GUIDE] clic sur une ligne : le filet part, la liste se ferme", not list:IsShown() and NS:CaptureState().rolling ~= nil)
	local stage = NS.captureStage
	-- (dans le mock, GetName() rend le champ `name`, où la scène range la
	-- FontString du nom de la créature : on lit l'inscription elle-même)
	Check("[GUIDE] la scène est inscrite pour Échap sous son nom", stage and Registered("QuestCompanionCaptureStage") and stage:IsShown(),
		table.concat(UISpecialFrames, ","))
	-- Échap avant le verdict : la scène se cache, la capture se résout quand même
	Mock:Reset()
	stage:Hide()
	stage:GetScript("OnHide")(stage)
	Check("[GUIDE] Échap avant le verdict : scène cachée, le lancer continue", not stage:IsShown() and stage.rolling == nil
		and NS:CaptureState().rolling ~= nil)
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[GUIDE] … le verdict tombe et s'annonce dans le chat", NS:CaptureState().rolling.result == "ok"
		and Mock:Output():find("Ours", 1, true) ~= nil, Mock:Output())
	Mock:Advance(NS.CAPTURE_STAGE_HOLD + 0.5); NS:CaptureTick(NS.Now())
	Check("[GUIDE] … et le lancer se termine", NS:CaptureState().rolling == nil)
	-- Échap après le verdict : la scène se ferme et le lancer se termine au relevé suivant
	G.SeeKill(5502, { name = "Loup", spawn = "00000000AB" })
	G.Roll(0)
	NS:CaptureThrow()
	local rolling = NS:CaptureState().rolling
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[GUIDE] verdict tombé, scène affichée", rolling.result == "ok" and stage:IsShown() and rolling.closeAt > Mock.now)
	NS:CaptureStageUpdate(rolling.resultAt + 1.3)
	Check("[GUIDE] le pied dit « Clic ou Échap pour fermer »", stage.footer:GetText() == NS.L.CAPTURE_STAGE_CLOSE)
	stage:Hide()
	stage:GetScript("OnHide")(stage)
	NS:CaptureTick(NS.Now())
	Check("[GUIDE] Échap après le verdict : terminé", NS:CaptureState().rolling == nil and not stage:IsShown())
	-- un nouveau lancer pendant les 3,5 s du verdict : il part sans attendre
	G.SeeKill(5503, { name = "Cerf", spawn = "00000000AC" })
	NS:CaptureThrow()
	rolling = NS:CaptureState().rolling
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	G.SeeKill(5504, { name = "Hibou", spawn = "00000000AD" })
	Check("[GUIDE] verdict à l'écran, un autre monstre dans le filet", rolling.result == "ok" and #NS:CaptureQueue() == 1)
	Check("[GUIDE] clic sur le filet : le verdict se referme, le nouveau lancer part", NS:CaptureThrow() == true
		and NS:CaptureState().rolling ~= rolling and NS:CaptureState().rolling.target.name == "Hibou")
	Check("[GUIDE] un seul essai à la fois, toujours", NS:CaptureThrow() == false)
	G.PlayCapture()
end

G.Done()
