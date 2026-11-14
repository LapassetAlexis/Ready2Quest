-- Le guide et les visites guidées du carnet (QuestCompanion 2.3 → 3.0).
--   1. La page Guide (JournalGuide.lua) : sommaire, chaque chiffre lu dans les
--      constantes du jeu, table des types, pagination, aucun chevauchement (FR
--      et EN) ; Échap et « × » ferment la scène de capture et la liste du filet.
--   2. Les visites guidées (GuidedTour.lua, 3.0.0) : le moteur (étapes, pause en
--      combat, Échap, /qc tuto), les deux styles et leurs contrastes, le
--      tutoriel de la ménagerie 2.3.0 retiré (une seule vérification) et la
--      remise à zéro, la visite des captures, celle du carnet, clic droit =
--      carnet, l'explication de la migration et le cadeau de la 3.0.
-- 3.1.0 : affirme l'ancien habillage (carnet en parchemin, scènes en bois, bandeaux
-- dorés, anneau) : le drapeau QNS.AZEROTH_LEGACY rallumé pour tout le module
-- (remis à la valeur du produit à sa fin, tests/run_tests.lua)
T.Legacy(true)
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- 1. La page Guide -------------------------------------------------------------------------------------
do
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

	local function Specs(text)
		local list = {}
		for spec in tostring(text or ""):gsub("%%%%", ""):gmatch("%%[sd]") do list[#list + 1] = spec end
		return table.concat(list, ",")
	end
	local function Registered(name)
		for _, entry in ipairs(UISpecialFrames) do if entry == name then return true end end
		return false
	end

	-- 1.1 Parité FR/EN des textes du guide
	do
		Say("-- guide : parité fr/en")
		local guide, bad = NS.GUIDE_STRINGS, {}
		for key, fr in pairs(guide.fr) do
			local en = guide.en[key]
			if type(en) ~= "string" or en == "" or Specs(fr) ~= Specs(en) then bad[#bad + 1] = key end
		end
		for key in pairs(guide.en) do if guide.fr[key] == nil then bad[#bad + 1] = key .. " (en seul)" end end
		table.sort(bad)
		Check("[GUIDE] page Guide : mêmes clés et arguments en français et en anglais ; « Clic ou Échap » des deux côtés", #bad == 0
			and NS.CAPTURE_STAGE_STRINGS.fr.CAPTURE_STAGE_CLOSE:find("Échap", 1, true) ~= nil
			and NS.CAPTURE_STAGE_STRINGS.en.CAPTURE_STAGE_CLOSE:find("Escape", 1, true) ~= nil, table.concat(bad, ", "))
	end

	-- 1.2 La page Guide : chaque chiffre vient des constantes du jeu
	do
		Say("-- guide : page Guide")
		G.Reset()
		NS:ToggleJournal(true)
		local f = NS.journalFrame
		local entry = f.sections.guide and f.sections.guide.text.text == NS.L.JRN_SEC_guide
			and f.sections.guide.points[1].y < f.sections.progress.points[1].y
		NS:SelectJournalKind("guide")
		local pane = f.guide
		Check("[GUIDE] entrée « Guide » en dernier ; la page : titre, sommaire de neuf sections, Le filet ouvert", entry
			and f.kind == "guide" and pane:IsShown() and f.header.title.text == NS.L.JRN_SEC_guide
			and f.header.subtitle.text == NS.L.JRN_SUB_guide and #pane.rows == 9 and #NS.GUIDE_SECTIONS == 9
			and pane.rows[1].label.text == NS.L.GUIDE_SEC_net and pane.rows[4].label.text == NS.L.GUIDE_SEC_effects
			and pane.rows[9].label.text == NS.L.GUIDE_SEC_settings and f.guideSection == "net" and pane.rows[1].selected
			and pane.title.text == NS.L.GUIDE_SEC_net and pane.shown >= 3)
		local bad = {}
		local function Want(label, ok) if not ok then bad[#bad + 1] = label end end
		Want("filet : 12 monstres, 30 s", pane.paras[2].text:find(NS.CAPTURE_QUEUE_MAX .. " monstres", 1, true)
			and pane.paras[2].text:find(NS.CAPTURE_QUEUE_TIME .. " s", 1, true))
		Want("filet : normal 30 %", pane.paras[5].text:find("normal " .. math.floor(NS.CAPTURE_RATES.normal * 100 + 0.5) .. " %", 1, true))
		Want("filet : sourdine, sons, Échap", pane.paras[4].text:find("5, 15, 30 et 60 min", 1, true)
			and pane.paras[4].text:find(NS.L.OPT_DAILY_CAPTURE_SOUND, 1, true) and pane.paras[3].text:find("Échap", 1, true))
		Want("filet : aides et facteurs", pane.paras[5].text:find(NS:CaptureAidLabel("appat") .. " ×1,5", 1, true)
			and pane.paras[5].text:find(NS:CaptureAidLabel("sifflet"), 1, true))
		pane.rows[2]:Click()
		Want("étoiles", f.guideSection == "stars" and pane.title.text == NS.L.GUIDE_SEC_stars
			and pane.paras[1].text:find(NS.CAPTURE_STAR_ODDS[1] .. " %", 1, true)
			and pane.paras[1].text:find(NS.CAPTURE_STAR_ODDS[3] .. " %", 1, true) and pane.paras[3].text:find("+0,25", 1, true))
		NS:JournalGuidePick("shiny")
		Want("brillantes", pane.paras[1].text:find("1 chance sur 150", 1, true) and pane.paras[1].text:find("×" .. NS.SHINY_RANK_MULT, 1, true)
			and pane.paras[2].text:find("1 sur 40", 1, true) and pane.paras[2].text:find(NS.SHINY_CHAIN_KILLS .. " abattus", 1, true)
			and pane.paras[2].text:find("×1,5", 1, true))
		NS:JournalGuidePick("seals")
		Want("sceaux", pane.paras[2].text:find("×" .. NS.MenagerieDecimal(NS.SEAL_SHINY_MULT), 1, true))
		NS:JournalGuidePick("titles")
		local titleBlocks = NS:JournalGuideBlocks("titles", pane.cols)
		local ranks = {}
		for _, block in ipairs(titleBlocks) do if block.kind == "row" and not block.head then ranks[#ranks + 1] = block end end
		Want("titres : paliers par type", titleBlocks[1].text:find("10, 20 et 40", 1, true) and titleBlocks[1].text:find("5, 10 et 20", 1, true)
			and titleBlocks[1].text:find(NS:CreatureTypeLabel("dragonkin"), 1, true))
		Want("titres : cinq rangs et leurs récompenses", #ranks == #NS.TRAINER_RANKS and ranks[1].cells[1] == "10"
			and ranks[5].cells[1] == "250" and ranks[1].cells[2] == NS.L.TRAINER_apprentice and ranks[5].cells[2] == NS.L.TRAINER_grandmaster
			and ranks[1].cells[3] == NS:TrainerRankGift(NS.TRAINER_RANKS[1]))
		NS:JournalGuidePick("missions")
		Want("missions", pane.paras[1].text:find(NS:CaptureAidLabel("appat"), 1, true) and pane.paras[1].text:find(NS:TreatLabel("festin"), 1, true)
			and pane.paras[2].text:find(NS:CaptureAidLabel("sifflet"), 1, true)
			and pane.paras[3].text:find(NS.CAPTURE_GIFT_EVERY .. " captures", 1, true))
		NS:JournalGuidePick("card")
		Want("fiche", pane.paras[2].text:find("/qc fiche", 1, true) and pane.paras[2].text:find(NS.L.TRAINER_MENU, 1, true)
			and pane.paras[3].text:find(NS.L.OPT_DAILY_TRAINER, 1, true))
		NS:JournalGuidePick("settings")
		Want("réglages", pane.paras[1].text:find(NS.L.OPT_DAILY_CAPTURE_SOUND, 1, true)
			and pane.paras[2].text:find(NS.L.OPT_COMP_FRAMING, 1, true) and pane.paras[2].text:find(NS.L.COMP_FRAMING_pied, 1, true)
			and pane.paras[3].text:find("/qc tuto", 1, true) and pane.paras[3].text:find("sourdine", 1, true)
			and pane.paras[4].text:find(NS.L.GUIDE_REPLAY, 1, true) and pane.paras[4].text:find(NS.L.GUIDE_REPLAY_JOURNAL, 1, true)
			and pane.paras[4].text:find("Maj + clic droit", 1, true))
		Check("[GUIDE] chaque section dit les chiffres des constantes (filet, étoiles, brillantes, sceaux, titres, missions, fiche, réglages)",
			#bad == 0, table.concat(bad, " | "))
		-- la table des types et la force
		NS:JournalGuidePick("effects")
		local rows = NS:JournalGuideTypeRows()
		Check("[GUIDE] table des types : huit types et la mascotte, vraies valeurs (base et plafond), en-tête et rangées affichées",
			#rows == 9 and rows[1].key == "beast" and rows[9].key == "mascot" and rows[2].label == NS:CreatureTypeLabel("humanoid")
			and rows[2].hunt == NS:F("GUIDE_CAP", NS:F("EFF_capture_humanoid", 10), 40)
			and rows[1].comfort == NS:F("GUIDE_CAP", NS:F("EFF_decay_hunger", 10), 40)
			and rows[9].hunt == NS:F("GUIDE_CAP", NS:F("EFF_capture_all", 2), 10) and pane.theads[1]:IsShown()
			and pane.theads[1].cells[2].text == NS.Theme.Upper(NS.L.GUIDE_COL_HUNT) and pane.trows[1]:IsShown()
			and pane.trows[1].cells[1].text == NS:CreatureTypeLabel("beast") and pane.trows[1].cells[2].text == rows[1].hunt, rows[2].hunt)
		local blocks = NS:JournalGuideBlocks("effects", pane.cols)
		local strength, delay
		for _, block in ipairs(blocks) do
			if block.kind == "p" and block.text:find("rang normal", 1, true) then strength = block.text end
			if block.kind == "p" and block.text:find("confirmation", 1, true) then delay = block.text end
		end
		Check("[GUIDE] la force (×1 → ×2,5, +0,5 brillante, +0,25 par étoile et par palier), le délai de 2 minutes, le seuil de 50 %",
			strength and strength:find("×1,5", 1, true) and strength:find("×2,5", 1, true) and strength:find("+0,5", 1, true)
			and strength:find("+0,25 par étoile", 1, true) and strength:find("+0,25 par palier", 1, true)
			and delay and delay:find("2 minutes", 1, true) and blocks[#blocks - 1].text:find(NS.EFFECT_NEED_OK .. " %", 1, true), strength)
		-- pagination
		local first = pane.shown
		local paged = pane.blocks > pane.shown and pane.pager.position.text ~= "" and pane.hint.text == NS.L.GUIDE_MORE
		NS:ScrollJournal(-1)
		local oneMore = f.guideOffset == 1
		for _ = 1, 40 do NS:ScrollJournal(-1) end
		local bounded = f.guideOffset < pane.blocks and f.guideOffset + pane.shown == pane.blocks and pane.paras[pane.shown - 3] ~= nil
		for _ = 1, 40 do NS:ScrollJournal(1) end
		local top = f.guideOffset == 0 and pane.shown == first
		pane.pager.down:Click()
		Check("[GUIDE] pagination : dite, molette d'un bloc, bornée au dernier, retour en haut, chevron d'une page", paged and oneMore
			and bounded and top and f.guideOffset == first, f.guideOffset .. " / " .. pane.blocks)
		NS:SelectJournalKind("collection")
		local oldName = f.kind == "evolution"
		NS:SelectJournalKind("guide")
		local remembered = NS:DB().journalTab == "guide"
		f:Hide()
		NS:OpenJournalGuide("titles")
		Check("[GUIDE] anciens noms de page inchangés ; page retenue ; OpenJournalGuide ouvre la section demandée", oldName and remembered
			and f:IsShown() and f.kind == "guide" and f.guideSection == "titles")
		f:Hide()
	end

	-- 1.3 Aperçu : aucun chevauchement, en français puis en anglais
	do
		Say("-- guide : aperçu, chaque section sans chevauchement")
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
			for _, key in ipairs(NS.GUIDE_SECTIONS) do
				for _, block in ipairs(NS:JournalGuideBlocks(key, frame.guide.cols)) do
					local texts = block.kind == "row" and block.cells or { block.text }
					for _, text in ipairs(texts) do if text:find("%%[sd]") then bad[#bad + 1] = "en " .. key .. " : argument en plan" end end
				end
			end
			for _, key in ipairs(swapped) do NS.L[key] = nil end
			Check("[GUIDE] anglais : aucun chevauchement, rien ne sort, aucun argument en plan ; retour au français", #bad == 0
				and NS.L.GUIDE_SEC_net == NS.GUIDE_STRINGS.fr.GUIDE_SEC_net, table.concat(bad, " | "))
			frame:Hide()
		end
		UIParent.width, UIParent.height = savedW, savedH
		ResetWorld()
	end

	-- 1.4 Échap et « × » : la scène de capture et la liste du filet
	do
		Say("-- guide : fermer la scène et la liste")
		G.Reset()
		NS:DB().companionCaptureAnim = true
		G.SeeKill(5501, { name = "Ours" })
		NS.captureNetButton:Click("RightButton")
		local list = NS.captureQueueList
		local named = list and list:GetName() == "QuestCompanionCaptureList" and list.close ~= nil and Registered("QuestCompanionCaptureList")
		list.close:Click()
		local closed = not list:IsShown()
		NS.captureNetButton:Click("RightButton")
		Check("[GUIDE] la liste du filet : un nom inscrit pour Échap, un « × » qui ferme, rouverte", named and closed and list:IsShown())
		G.Roll(0)
		list.rows[1]:Click()
		local stage = NS.captureStage
		-- (dans le mock, GetName() rend le champ `name`, où la scène range la
		-- FontString du nom de la créature : on lit l'inscription elle-même)
		Check("[GUIDE] clic sur une ligne : le filet part, la liste se ferme, la scène inscrite pour Échap", not list:IsShown()
			and NS:CaptureState().rolling ~= nil and stage and Registered("QuestCompanionCaptureStage") and stage:IsShown(),
			table.concat(UISpecialFrames, ","))
		-- Échap avant le verdict : la scène se cache, la capture se résout quand même
		Mock:Reset()
		stage:Hide()
		stage:GetScript("OnHide")(stage)
		local goesOn = not stage:IsShown() and stage.rolling == nil and NS:CaptureState().rolling ~= nil
		for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
		local said = NS:CaptureState().rolling.result == "ok" and Mock:Output():find("Ours", 1, true) ~= nil
		Mock:Advance(NS.CAPTURE_STAGE_HOLD + 0.5); NS:CaptureTick(NS.Now())
		Check("[GUIDE] Échap avant le verdict : scène cachée, le lancer continue, le verdict s'annonce dans le chat, puis fini",
			goesOn and said and NS:CaptureState().rolling == nil, Mock:Output())
		-- Échap après le verdict : la scène se ferme et le lancer se termine au relevé suivant
		G.SeeKill(5502, { name = "Loup", spawn = "00000000AB" })
		G.Roll(0)
		NS:CaptureThrow()
		local rolling = NS:CaptureState().rolling
		for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
		local shown = rolling.result == "ok" and stage:IsShown() and rolling.closeAt > Mock.now
		NS:CaptureStageUpdate(rolling.resultAt + 1.3)
		local foot = stage.footer:GetText() == NS.L.CAPTURE_STAGE_CLOSE
		stage:Hide()
		stage:GetScript("OnHide")(stage)
		NS:CaptureTick(NS.Now())
		Check("[GUIDE] verdict affiché, « Clic ou Échap pour fermer » ; Échap : terminé", shown and foot
			and NS:CaptureState().rolling == nil and not stage:IsShown())
		-- un nouveau lancer pendant les 3,5 s du verdict : il part sans attendre
		G.SeeKill(5503, { name = "Cerf", spawn = "00000000AC" })
		NS:CaptureThrow()
		rolling = NS:CaptureState().rolling
		for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
		G.SeeKill(5504, { name = "Hibou", spawn = "00000000AD" })
		local queued = rolling.result == "ok" and #NS:CaptureQueue() == 1
		Check("[GUIDE] verdict à l'écran, un autre monstre dans le filet : le clic referme le verdict et lance, un essai à la fois",
			queued and NS:CaptureThrow() == true and NS:CaptureState().rolling ~= rolling
			and NS:CaptureState().rolling.target.name == "Hibou" and NS:CaptureThrow() == false)
		G.PlayCapture()
	end

	G.Done()
end

-- 2. Les visites guidées ---------------------------------------------------------------------------------
do
	local P = { saved = {}, random = math.random, units = {} }
	P.rollQuality = NS.CaptureRollQuality
	local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
		"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
		"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
		"UnitAffectingCombat", "InCombatLockdown", "IsShiftKeyDown", "IsControlKeyDown", "UnitOnTaxi", "time" }
	for _, name in ipairs(GLOBALS) do P.saved[name] = rawget(_G, name) end
	P.savedShiny, P.savedAuto = NS.SHINY_CHANCE, NS.TOUR_AUTO
	local PLAYER = "Player-1-00000001"
	local FIELDS = { "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt", "captureQueueList",
		"captureNetButton", "captureToast", "captureResult", "companionMenu" }
	local SCENES = { "captureStage", "captureBatchFrame", "captureChooser" }
	local CACHES = { "captureStages", "captureBatchFrames", "captureChoosers" }

	function P.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
	function P.Install()
		local w = P
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
		_G.InCombatLockdown = function() return false end
		_G.UnitAffectingCombat = function() return w.combat == true end
		_G.IsShiftKeyDown = function() return w.shift == true end
		_G.IsControlKeyDown = function() return false end
		_G.UnitOnTaxi = function() return false end
		_G.time = function() return w.wall end
	end
	local function HideScenes()
		for _, field in ipairs(SCENES) do
			local frame = NS[field]
			if frame then frame.prep = nil; frame:Hide(); frame.rolling = nil end
		end
		for _, field in ipairs(CACHES) do
			for _, frame in pairs(NS[field] or {}) do frame.prep = nil; frame:Hide(); frame.rolling = nil end
		end
	end
	function P.Reset(style)
		if NS.tourState then NS:TourStop() end
		NS.tourPending, NS.tourMigrationAt, NS.tourHoldJournal = nil, nil, nil
		ResetWorld()
		P.quality = nil
		NS.CaptureRollQuality = function() return P.quality or 1 end
		HideScenes()
		for _, field in ipairs(FIELDS) do
			if NS[field] then NS[field]:Hide() end
			NS[field] = nil
		end
		for _, field in ipairs(SCENES) do NS[field] = nil end
		for _, field in ipairs(CACHES) do NS[field] = nil end
		NS.uiStyleCache = {}
		NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
		NS.captureToastHideAt, NS.captureAppCache, NS.captureBatch, NS.specimenCountCache = nil, nil, nil, nil
		NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
		NS:DB().capture, NS.captureMergedChar = nil, nil
		NS:DB().tour30 = nil
		P.units, P.combat, P.shift, P.wall = {}, false, false, 1800000000
		Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
		Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
		Mock.world.mapID, Mock.world.level = 1413, 20
		P.Install()
		if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
		NS:AzerothAtlasOK(true)
		NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
		NS:DB().winterVeil = "off"
		NS.SHINY_CHANCE = 0
		math.random = P.random
		NS:CompanionData().tutoDone = true
		NS:TreatData().treatsInit = true
		NS:DB().companionCaptureAnim = true
		NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
		NS:CompanionUpdateVisibility()
		NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
		if NS.notifyState then NS.notifyState.at = -math.huge end
		NS.TOUR_AUTO = true
	end
	function P.Roll(value)
		math.random = function(a, b)
			if a and b then return P.random(a, b) end
			if a then return P.random(a) end
			return value
		end
	end
	function P.SeeKill(npcID, fields)
		fields = fields or {}
		local guid = P.Guid(npcID, fields.spawn)
		fields.guid = guid
		fields.name = fields.name or ("Bête " .. npcID)
		P.units.target = fields
		NS:BestiarySeeUnit("target")
		NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
		NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
		return guid
	end
	-- la scène jouée jusqu'au verdict, puis jusqu'à sa fermeture
	function P.PlayCapture()
		for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
		Mock:Advance((NS.CAPTURE_STAGE_HOLD or 3) + 0.5); NS:CaptureTick(NS.Now())
		for _ = 1, 3 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	end
	function P.UI()
		-- 3.1.0 : le jeu de la clé courante (ancien habillage, forgé, Sobre)
		local style = NS.StyleKey and NS:StyleKey() or ((NS.AzerothOn and NS:AzerothOn()) and "azeroth" or "sobre")
		return NS.tourUI and NS.tourUI[style] or {}
	end
	function P.Callout() return P.UI().callout end
	function P.Ring() return P.UI().ring end
	function P.Shown() local c = P.Callout(); return c ~= nil and c:IsShown() end
	function P.Title() local c = P.Callout(); return c and c.title:GetText() or "" end
	function P.Text() local c = P.Callout(); return c and c.text:GetText() or "" end
	function P.Step() return NS.tourState and NS.tourState.def.steps[NS.tourState.index] or nil end
	function P.StepId() local s = P.Step(); return s and s.id end
	function P.Done()
		if NS.tourState then NS:TourStop() end
		NS.TOUR_DEFS.test = nil
		for _, name in ipairs(GLOBALS) do _G[name] = P.saved[name] end
		math.random = P.random
		NS.SHINY_CHANCE = P.savedShiny
		NS.TOUR_AUTO = P.savedAuto
		NS.CaptureRollQuality = P.rollQuality
		HideScenes()
		if NS.journalFrame then NS.journalFrame:Hide() end
		NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
		NS:DB().capture, NS.captureMergedChar = nil, nil
		NS:DB().tour30 = nil
		ResetWorld()
	end
	local function Has(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end
	local function Lum(c)
		local function lin(v) if v <= 0.03928 then return v / 12.92 end return ((v + 0.055) / 1.055) ^ 2.4 end
		return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
	end
	local function Anchor()
		local f = CreateFrame("Frame", nil, UIParent)
		f:SetSize(40, 40)
		f:Show()
		return f
	end

	-- 2.1 Le moteur
	do
		Say("-- visites : le moteur")
		P.Reset()
		local a, b, c = Anchor(), Anchor(), Anchor()
		local done = { ok = false }
		NS.TOUR_DEFS.test = { steps = {
			{ id = "a", anchor = a, title = "TOUR_A1_T", text = "TOUR_A1", placement = "top" },
			{ id = "b", anchor = function() return b end, title = "TOUR_A2_T", text = "TOUR_A2", placement = "right" },
			{ id = "c", anchor = c, title = "TOUR_A3_T", text = function() return "texte c" end, placement = "bottom", noNext = true,
				waitFor = function() return done.ok end },
		} }
		Check("[ENG] départ : bulle, titre, texte, compteur 1 / 3, liseré autour de l'ancre, « Suivant » et « Passer le tutoriel »",
			NS:TourStart("test") and P.Shown() and P.Title() == NS.L.TOUR_A1_T and P.Text() == NS.L.TOUR_A1
			and P.Callout().step:GetText() == "1 / 3" and P.Ring():IsShown() and P.Ring().anchor == a
			and P.Callout().nextButton:IsShown() and P.Callout().skipButton:IsShown()
			and P.Callout().skipButton.text:GetText() == NS.L.TOUR_SKIP, P.Callout() and P.Callout().step:GetText())
		local single = NS:TourStart("journal") == false and NS:TourActive() == "test"
		P.Callout().nextButton:Click()
		Check("[ENG] une seule visite à la fois ; Suivant : étape 2, ancre fonction, 2 / 3", single and P.StepId() == "b"
			and P.Ring().anchor == b and P.Callout().step:GetText() == "2 / 3")
		-- combat : pause, même étape à la reprise
		P.combat = true
		Mock:Fire("PLAYER_REGEN_DISABLED")
		local paused = not P.Shown() and not P.Ring():IsShown() and NS.tourState.paused and P.StepId() == "b"
		Mock:Advance(1)
		paused = paused and not P.Shown()
		P.combat = false
		Mock:Fire("PLAYER_REGEN_ENABLED")
		Mock:Advance(0.2)
		Check("[ENG] combat : bulle et liseré cachés tant qu'il dure ; après : la même étape revient", paused and P.Shown()
			and P.StepId() == "b" and not NS.tourState.paused)
		P.Callout().nextButton:Click()
		local waits = P.StepId() == "c" and not P.Callout().nextButton:IsShown() and P.Text() == "texte c"
		Mock:Advance(5)
		waits = waits and P.StepId() == "c" and P.Shown()
		done.ok = true
		Mock:Advance(0.2)
		Check("[ENG] étape qui attend un geste : pas de « Suivant », le temps ne la passe pas ; geste fait : fin, vue au compte",
			waits and NS:TourActive() == nil and NS:TourDone("test") and not P.Shown() and NS:DB().tour30.test == true)
		-- ancre absente : attend puis passe ; ancre qui disparaît après affichage : étape suivante
		NS:TourMark("test", false)
		a:Hide()
		NS:TourStart("test")
		local missing = not P.Shown() and P.StepId() == "a"
		Mock:Advance(NS.TOUR.missingWait + 0.5)
		missing = missing and P.StepId() == "b" and P.Shown() and P.Callout().step:GetText() == "2 / 3"
		done.ok = false
		b:Hide()
		Mock:Advance(0.2)
		Check("[ENG] ancre absente : l'étape attend puis passe ; ancre partie après l'affichage : suivante tout de suite", missing
			and P.StepId() == "c")
		a:Show(); b:Show()
		-- Échap : la bulle se ferme, la visite est passée ; Alt+Z (toute l'interface cachée) n'est pas un Échap
		local callout = P.Callout()
		local rootShown = UIParent.shown
		UIParent.shown = false
		callout:Hide()
		callout.scripts.OnHide(callout)
		local altZ = NS:TourActive() == "test" and NS.tourState.shownIndex == nil
		UIParent.shown = true
		Mock:Advance(0.2)
		Mock:Reset()
		callout:Hide()
		callout.scripts.OnHide(callout)
		UIParent.shown = rootShown
		local registered = false
		for _, name in ipairs(UISpecialFrames) do if name == callout:GetName() then registered = true end end
		Check("[ENG] Alt+Z : la visite continue ; Échap (bulle inscrite) : passée, vue, message du chat", altZ and registered
			and NS:TourActive() == nil and NS:TourDone("test") and Has(Mock:Output(), NS.L.TOUR_MSG_SKIPPED))
		NS:TourMark("test", false)
		done.ok = false
		NS:TourStart("test")
		P.Callout().skipButton:Click()
		Check("[ENG] « Passer le tutoriel » : fini, vu", NS:TourActive() == nil and NS:TourDone("test") and not P.Shown())
		-- démarrée en combat : après le combat
		NS:TourMark("test", false)
		P.combat = true
		local pending = NS:TourStart("test") == false and NS.tourPending == "test" and not P.Shown()
		P.combat = false
		Mock:Fire("PLAYER_REGEN_ENABLED")
		Mock:Advance(0.2)
		local started = NS:TourActive() == "test" and P.Shown()
		NS:TourStop()
		Check("[ENG] départ en combat : en attente, part à la fin du combat ; arrêt : rien de marqué", pending and started
			and not NS:TourDone("test") and not P.Shown())
		-- /qc tuto reset, aide, passer
		NS:TourMark("capture", true); NS:TourMark("journal", true)
		Mock:Reset()
		NS:HandleCommand("tuto reset")
		local reset = not NS:TourDone("capture") and not NS:TourDone("journal") and Has(Mock:Output(), NS.L.TOUR_MSG_RESET)
		Mock:Reset()
		NS:HandleCommand("tuto")
		local help = Has(Mock:Output(), "/qc tuto")
		NS:TourStart("test")
		NS:HandleCommand("tuto passer")
		Check("[ENG] /qc tuto reset (tout à revoir), /qc tuto (l'aide), /qc tuto passer (arrêtée, vue)", reset and help
			and NS:TourActive() == nil and NS:TourDone("test"))
		local S = NS.TOUR_STRINGS
		local bad = {}
		local function Specs(text)
			local list = {}
			for spec in tostring(text or ""):gsub("%%%%", ""):gmatch("%%[sd]") do list[#list + 1] = spec end
			return table.concat(list, ",")
		end
		for key, fr in pairs(S.fr) do
			local en = S.en[key]
			if type(en) ~= "string" or en == "" or Specs(fr) ~= Specs(en) then bad[#bad + 1] = key end
		end
		for key in pairs(S.en) do if S.fr[key] == nil then bad[#bad + 1] = key .. " (en seul)" end end
		Check("[ENG] textes : mêmes clés et arguments en français et en anglais", #bad == 0, table.concat(bad, ", "))
		NS.TOUR_DEFS.test = nil
	end

	-- 2.2 Les deux styles, et les contrastes
	do
		Say("-- visites : styles et contrastes")
		P.Reset()
		local a = Anchor()
		NS.TOUR_DEFS.test = { steps = { { id = "a", anchor = a, title = "TOUR_A1_T", text = "TOUR_A1" } } }
		NS:TourStart("test")
		local c = P.Callout()
		local INK, CONTRAST = NS.AZEROTH_INK, NS.AZEROTH_CONTRAST
		local bad = {}
		for role, entry in pairs(NS.TOUR_CONTRAST) do
			local ratio = NS.AzerothContrast(INK[entry[1]], entry[2])
			if CONTRAST[role] ~= entry or ratio < entry[3] or entry[3] < 4.5 then bad[#bad + 1] = role .. "=" .. string.format("%.2f", ratio) end
		end
		Check("[STYLE] Azeroth : bulle de parchemin, rôles versés au tableau, ≥ 4,5:1, même fond que la bulle du compagnon",
			c.uiStyle == "azeroth" and c.title.azRole == "tour.title" and c.text.azRole == "tour.text" and c.step.azRole == "tour.step"
			and c.nextButton.azeroth and #bad == 0 and NS.TOUR_CONTRAST["tour.text"][2] == CONTRAST["bubble.text"][2]
			and NS.TOUR_CONTRAST["tour.title"][2] == CONTRAST["bubble.name"][2], table.concat(bad, " "))
		NS:TourStop()
		P.Reset("sobre")
		a = Anchor()
		NS.TOUR_DEFS.test = { steps = { { id = "a", anchor = a, title = "TOUR_A1_T", text = "TOUR_A1" } } }
		NS:TourStart("test")
		c = P.Callout()
		local low, lowName = 99, ""
		local bg = Lum(NS.Theme.WINDOW)
		for _, key in ipairs({ "title", "text", "step" }) do
			local ratio = NS.AzerothContrast(NS.TOUR_SOBRE[key], bg)
			if ratio < low then low, lowName = ratio, key end
		end
		Check("[STYLE] Sobre : bulle sombre du socle, titre, texte, compteur ≥ 4,5:1 sur Theme.WINDOW", c.uiStyle == "sobre"
			and c:IsShown() and not c.nextButton.azeroth and low >= 4.5, lowName .. "=" .. string.format("%.2f", low))
		NS:TourStop()
		NS.TOUR_DEFS.test = nil
	end

	-- 2.3 Plus de tutoriel de la ménagerie ; remise à zéro 3.0
	do
		Say("-- visites : un seul tutoriel, remis à zéro en 3.0")
		P.Reset()
		Check("[OLD] le tutoriel de la ménagerie (2.3.0) est retiré", NS.CompanionMenagerieOpportunity == nil
			and NS.CompanionStartMenagerieTutorial == nil and NS.CompanionMenagerieTutorialSteps == nil
			and NS.CompanionSequenceAdvance == nil and NS.CompanionSequenceWaits == nil and NS.TUTO_MENAGERIE_AUTO == nil
			and NS.COMPANION_POOLS.TUTO_MENAGERIE == nil and NS.COMPANION_POOLS.TUTO_MENAGERIE_START == nil)
		-- anciens drapeaux vus (sauvegarde d'avant la 3.0) : la 3.0 rejoue quand même
		NS:CompanionData().tutoMenagerieDone = true
		NS:CompanionData().tutoDone = true
		P.SeeKill(7001, { name = "Sanglier" })
		Check("[OLD] anciens tutoriels vus : la visite des captures part quand même, sans bulle de tutoriel du compagnon",
			NS:TourActive() == "capture" and P.StepId() == "net" and P.Shown() and not NS:CompanionTutorialActive())
		NS:TourStop()
		-- tutoriel de base du compagnon en cours : la visite attend l'occasion suivante
		P.Reset()
		NS:CompanionData().tutoDone = nil
		NS.companionSession = nil
		Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
		local base = NS:CompanionTutorialActive()
		P.SeeKill(7002, { name = "Loup" })
		local held = base and NS:TourActive() == nil
		NS:CompanionSkipTutorial()
		P.SeeKill(7003, { name = "Kodo" })
		Check("[OLD] tutoriel de base en cours : pas de visite par-dessus ; fini : elle part à l'occasion suivante", held
			and NS:TourActive() == "capture")
		NS:TourStop()
		Mock:Reset()
		NS:HandleCommand("compagnon tuto collection")
		Check("[OLD] /qc compagnon tuto collection : la visite des captures", NS:TourActive() == "capture")
		NS:TourStop()
	end

	-- 2.4 Visite des premières captures
	do
		Say("-- visites : premières captures")
		P.Reset()
		P.quality = 2
		P.SeeKill(7101, { name = "Raptor" })
		local net = NS.captureNetButton
		Check("[CAP] première occasion : le filet montré (1 / 5), pas de « Suivant » (il faut cliquer), le filet bat",
			NS:TourActive() == "capture" and P.StepId() == "net" and P.Ring().anchor == net and P.Callout().step:GetText() == "1 / 5"
			and Has(P.Text(), "étoiles") and not P.Callout().nextButton:IsShown() and NS.tourNetPulse == true, P.Text())
		NS:CaptureNetClick("LeftButton")
		Mock:Advance(0.2)
		local stage = NS.captureStage
		Check("[CAP] clic sur le filet : la carte de préparation (pas de lancer direct), étape 2 sur la carte", stage
			and stage.prep ~= nil and NS.captureState.rolling == nil and P.StepId() == "card" and P.Ring().anchor == stage.details
			and P.Title() == NS.L.TOUR_A2_T and Has(P.Text(), "aide") and not NS.tourNetPulse, tostring(P.StepId()))
		P.Callout().nextButton:Click()
		local launch = P.StepId() == "launch" and P.Ring().anchor == stage.launch and Has(P.Text(), "Maj + clic")
			and not P.Callout().nextButton:IsShown()
		P.Roll(0)
		stage.launch:Click()
		Mock:Advance(0.2)
		Check("[CAP] étape 3 : Lancer / Passer, Maj+clic expliqué ; Lancer : la bulle se tait pendant la scène", launch
			and NS.captureState.rolling ~= nil and not P.Shown() and P.StepId() == "result")
		P.PlayCapture()
		Check("[CAP] verdict : capturé au Codex, ancré sur le compagnon, le clic droit expliqué", P.StepId() == "result" and P.Shown()
			and NS.tourState.ctx.result == "ok" and NS.tourState.ctx.place == "codex" and P.Text() == NS.L.TOUR_A4_codex
			and P.Ring().anchor == NS.companionFrame and Has(P.Text(), "Clic droit"), P.Text())
		P.shift = false
		NS.companionFrame.scripts.OnMouseUp(NS.companionFrame, "RightButton")
		Check("[CAP] clic droit sur le compagnon : le carnet s'ouvre, étape du mode chasse (sa visite attend)", NS.journalFrame
			and NS.journalFrame:IsShown() and P.StepId() == "hunt" and Has(P.Text(), "Maj + clic droit") and NS:TourActive() == "capture")
		P.Callout().nextButton:Click()
		local finished = NS:TourDone("capture") and NS:TourActive() == "journal"
		NS:TourStop()
		NS.journalFrame:Hide()
		P.SeeKill(7102, { name = "Kodo" })
		Check("[CAP] Terminer : vue au compte, le carnet ouvert a sa visite ; la capture suivante ne la relance pas", finished
			and NS:TourActive() == nil)
		-- Réserve : « Ton Codex avait déjà mieux »
		P.Reset()
		NS:SpecimenAdd({ npc = 7201, stars = 3, name = "Ours" })
		NS:HuntStart(5)
		P.quality = 1
		P.SeeKill(7201, { name = "Ours" })
		NS:CaptureNetClick("LeftButton")
		Mock:Advance(0.2)
		P.Callout().nextButton:Click()
		P.Roll(0)
		NS.captureStage.launch:Click()
		P.PlayCapture()
		Check("[CAP] moins bon que le Codex : « … rejoint ta Réserve »", NS.tourState and NS.tourState.ctx.place == "reserve"
			and P.Text() == NS.L.TOUR_A4_reserve, P.Text())
		NS:TourStop()
		NS:HuntStop()
		-- Maj+clic : le filet part tout de suite, les étapes de la carte sautent
		P.Reset()
		P.SeeKill(7301, { name = "Hyène" })
		P.shift = true
		P.Roll(0.999)
		NS:CaptureNetClick("LeftButton")
		P.shift = false
		Mock:Advance(0.2)
		local direct = NS.captureState.rolling ~= nil and P.StepId() == "result" and not P.Shown()
		P.PlayCapture()
		Check("[CAP] Maj+clic : lancer direct, carte sautée ; échappé : « Il s'est échappé… » (4 / 5)", direct and P.Shown()
			and NS.tourState.ctx.result == "fail" and P.Text() == NS.L.TOUR_A4_fail and P.Callout().step:GetText() == "4 / 5",
			P.Callout().step:GetText())
		NS:TourStop()
		-- monstre parti avant le clic : arrêt sans être vue, reprise à l'occasion suivante
		P.Reset()
		P.SeeKill(7401, { name = "Crocilisque" })
		Mock:Reset()
		Mock:Advance(NS.CAPTURE_QUEUE_TIME + 2); NS:CaptureTick(NS.Now())
		Mock:Advance(0.2)
		local gone = #NS:CaptureQueue() == 0 and NS:TourActive() == nil and not NS:TourDone("capture")
			and Has(Mock:Output(), NS.L.TOUR_MSG_LATER)
		P.SeeKill(7402, { name = "Zhévra" })
		Check("[CAP] candidat parti : visite arrêtée, pas vue, message ; occasion suivante : elle repart du filet", gone
			and NS:TourActive() == "capture" and P.StepId() == "net")
		NS:TourStop()
		-- en combat : pas de départ ; à la fin du combat, l'occasion compte
		P.Reset()
		P.combat = true
		P.SeeKill(7501, { name = "Lion" })
		local quiet = NS:TourActive() == nil
		P.combat = false
		Mock:Advance(0.2); NS:CaptureTick(NS.Now())
		Check("[CAP] monstre abattu en combat : pas de visite ; fin du combat : elle part", quiet and NS:TourActive() == "capture")
		NS:TourStop()
	end

	-- 2.5 Visite du carnet
	do
		Say("-- visites : le carnet")
		P.Reset()
		NS:ToggleJournal(true)
		local f = NS.journalFrame
		Mock:Advance(0.2)
		local first = NS:TourActive() == "journal" and P.StepId() == "evolution" and f.kind == "evolution"
			and P.Ring().anchor == f.sections.evolution and P.Title() == NS.L.JRN_SEC_evolution
		-- 3.0.0 : l'Échoppe du dresseur a son onglet, donc son étape
		-- 3.0.1 : Addons liés en dernier
		local order = { "evolution", "menagerie", "reserve", "shop", "feats", "day", "progress", "juke", "guide", "addons" }
		local bad, total = {}, NS.tourState.total
		for index, key in ipairs(order) do
			if f.sections[key] then
				if not (P.StepId() == key and f.kind == key and P.Ring().anchor == f.sections[key] and P.Text() == NS.L["TOUR_B_" .. key]) then
					bad[#bad + 1] = key .. "=" .. tostring(P.StepId()) .. "/" .. tostring(f.kind)
				end
				if index < #order then P.Callout().nextButton:Click() end
			end
		end
		local lastLabel = P.Callout().nextButton.text:GetText() == NS.L.TOUR_DONE
		P.Callout().nextButton:Click()
		Check("[JRN] première ouverture : chaque onglet surligné, ouvert, expliqué (10 étapes), « Terminer », vue au compte", first
			and #bad == 0 and total == 10 and lastLabel and NS:TourActive() == nil and NS:TourDone("journal"), table.concat(bad, ", "))
		f:Hide()
		NS:ToggleJournal(true)
		Mock:Advance(0.2)
		local once = NS:TourActive() == nil
		f:Hide()
		NS:TourMark("journal", false)
		NS:ToggleJournal(true)
		Mock:Advance(0.2)
		P.Callout().nextButton:Click()
		f:Hide()
		Mock:Advance(0.2)
		Check("[JRN] une fois ; carnet refermé en cours de visite : arrêtée, pas vue", once and NS:TourActive() == nil
			and not NS:TourDone("journal") and not P.Shown())
		-- les boutons de la page Guide
		NS:TourMark("journal", true)
		NS:OpenJournalGuide()
		Mock:Advance(0.2)
		local pane = f.guide
		local buttons = pane.replay and pane.replayJournal and pane.replay.text:GetText() == NS.L.GUIDE_REPLAY
			and pane.replayJournal.text:GetText() == NS.L.GUIDE_REPLAY_JOURNAL
		pane.replayJournal:Click()
		Mock:Advance(0.2)
		local replay = NS:TourActive() == "journal" and f.kind == "evolution"
		NS:TourStop()
		NS:SelectJournalKind("guide")
		Mock:Reset()
		pane.replay:Click()
		Check("[JRN] page Guide : « Tuto du carnet » relance la visite ; « Tuto des captures » (filet vide) : à la prochaine occasion",
			buttons and replay and not f:IsShown() and NS:TourActive() == nil and not NS:TourDone("capture")
			and Has(Mock:Output(), NS.L.TOUR_MSG_ARMED))
		NS:TourMark("capture", true)
		NS:HandleCommand("tuto capture")
		P.SeeKill(7601, { name = "Sanglier" })
		local cap = NS:TourActive() == "capture"
		NS:TourStop()
		NS:HandleCommand("tuto carnet")
		Mock:Advance(0.2)
		Check("[JRN] /qc tuto capture : à la capture suivante ; /qc tuto carnet : le carnet s'ouvre sur sa visite", cap
			and f:IsShown() and NS:TourActive() == "journal")
		NS:TourStop()
		f:Hide()
	end

	-- 2.6 Clic droit et Maj + clic droit
	do
		Say("-- visites : clic droit du compagnon")
		P.Reset()
		NS:TourMark("journal", true)
		local frame = NS.companionFrame
		frame.scripts.OnMouseDown(frame)
		frame.scripts.OnMouseUp(frame, "RightButton")
		local opened = NS.journalFrame and NS.journalFrame:IsShown() and not (NS.companionMenu and NS.companionMenu:IsShown())
		frame.scripts.OnMouseUp(frame, "RightButton")
		Check("[CLIC] clic droit : le carnet, d'un geste ; de nouveau : refermé", opened and not NS.journalFrame:IsShown())
		P.shift = true
		frame.scripts.OnMouseUp(frame, "RightButton")
		local menu = NS.companionMenu and NS.companionMenu:IsShown() and NS.companionMenu.journal and NS.companionMenu.durations
			and NS.companionMenu.untilStop and NS.companionMenu.stop and NS.companionMenu.cancel and not NS.journalFrame:IsShown()
		NS.companionMenu.cancel:Click()
		P.shift = false
		Check("[CLIC] Maj + clic droit : le menu de chasse ; le survol annonce les deux gestes (FR et EN)", menu
			and Has(NS.L.COMP_HOVER_HINT, "clic droit : carnet") and Has(NS.L.COMP_HOVER_HINT, "Maj + clic droit : chasse")
			and Has(NS.COMPANION_STRINGS and NS.COMPANION_STRINGS.en and NS.COMPANION_STRINGS.en.COMP_HOVER_HINT or "Shift + right-click: hunt",
				"Shift + right-click: hunt"))
	end

	-- 2.7 La migration expliquée
	local function Migrate(n, shinies)
		local data = NS:CaptureData()
		for index = 1, n do
			local shiny = index <= (shinies or 0)
			data.creatures[8000 + index] = { name = "Bête " .. index, normal = true, stars = (index % 3) + 1, at = 100 + index,
				zoneID = 1413, shiny = shiny or nil, shinyStars = shiny and 2 or nil, shinyAt = shiny and 200 or nil }
		end
		data.count = n
		NS:CaptureData().specV = nil
		return NS:SpecimenList({ sort = "id" })
	end
	do
		Say("-- visites : la migration expliquée")
		P.Reset()
		Migrate(5, 2)
		local species, total, shiny = NS:TourMigrationCounts()
		Check("[MIG] chiffres réels : 5 espèces, 7 spécimens, 2 brillants", species == 5 and total == 7 and shiny == 2,
			species .. "/" .. total .. "/" .. shiny)
		Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
		local delayed = NS:TourActive() == nil and NS.tourMigrationAt ~= nil
		Mock:Advance(NS.TOUR.migrationDelay + 0.5)
		Check("[MIG] connexion : quelques secondes après, l'explication avec les chiffres, le cadeau annoncé, « Suivant » et « Plus tard », vue",
			delayed and NS:TourActive() == "migration" and P.Title() == NS.L.TOUR_MIG_T and Has(P.Text(), "(5 ")
			and Has(P.Text(), " 7 ") and Has(P.Text(), " 2 ") and Has(P.Text(), NS.L.RES_BY_MIGRATION) and Has(P.Text(), "Recaptures")
			and Has(P.Text(), NS:F("TOUR_MIG_GIFT", 3)) and P.Callout().nextButton.text:GetText() == NS.L.TOUR_NEXT
			and P.Callout().skipButton.text:GetText() == NS.L.TOUR_MIG_LATER and NS:TourDone("migration"), P.Text())
		P.Callout().nextButton:Click()
		local gift = P.StepId() == "gift" and P.Callout().nextButton.text:GetText() == NS.L.TOUR_GIFT_GO
			and P.Callout().step:GetText() == "2 / 2"
		P.Callout().skipButton:Click()
		local later = NS:TourActive() == nil
		Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
		Mock:Advance(NS.TOUR.migrationDelay + 0.5)
		Check("[MIG] étape du cadeau « Choisir mes créatures » ; « Plus tard » : fini ; pas à la connexion suivante", gift and later
			and NS:TourActive() == nil)
		-- carnet ouvert avant la bulle de connexion : première étape de la visite du carnet
		P.Reset()
		Migrate(2, 0)
		NS:ToggleJournal(true)
		Mock:Advance(0.2)
		local inJournal = NS:TourActive() == "journal" and P.StepId() == "migration" and P.Callout().step:GetText() == "1 / 11"
			and Has(P.Text(), "(2 ") and not NS:Gift30Available() and not Has(P.Text(), NS:F("TOUR_MIG_GIFT", 3))
		P.Callout().nextButton:Click()
		local tabs = P.StepId() == "evolution" and NS:TourDone("migration")
		NS:TourStop()
		NS.journalFrame:Hide()
		Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
		Check("[MIG] carnet ouvert d'abord : l'explication en 1re étape (1 / 11, 2 espèces : pas de cadeau), puis les onglets ; rien à la connexion",
			inJournal and tabs and NS.tourMigrationAt == nil)
		-- sans créatures d'avant : jamais
		P.Reset()
		Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
		Mock:Advance(NS.TOUR.migrationDelay + 0.5)
		NS:ToggleJournal(true)
		Mock:Advance(0.2)
		Check("[MIG] nouveau joueur : pas d'explication, la visite commence aux onglets (10)", NS:TourActive() == "journal"
			and P.StepId() == "evolution" and NS.tourState.total == 10 and NS.tourMigrationAt == nil)
		NS:TourStop()
		NS.journalFrame:Hide()
	end

	-- 2.8 Le cadeau de la 3.0
	do
		Say("-- visites : le cadeau de la 3.0")
		P.Reset()
		Migrate(3, 1)
		Check("[GIFT] 3 espèces : pas de cadeau", not NS:Gift30Available() and NS:Gift30Grant({ 8001 }) == false)
		P.Reset()
		Migrate(5, 1)
		local data = NS:CaptureData()
		-- une espèce possédée seulement brillante
		data.creatures[8100] = { name = "Ours", normal = false, shiny = true, shinyStars = 3, shinyAt = 300 }
		data.specV = nil
		NS:SpecimenList()
		local offered = NS:Gift30Available()
		Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
		Mock:Advance(NS.TOUR.migrationDelay + 0.5)
		P.Callout().nextButton:Click()
		P.Callout().nextButton:Click()
		local f = NS.journalFrame
		local page = f and f:IsShown() and f.kind == "reserve" and f.resView == "gift" and f.res.gift:IsShown()
			and not f.res.reserve:IsShown()
		Mock:Advance(0.2)
		Check("[GIFT] plus de 3 espèces : offert ; « Choisir mes créatures » : la page Réserve, le choix, la visite du carnet attend",
			offered and page and NS:TourActive() == nil and not NS:TourDone("journal"))
		local gv = f.res.gift
		local tiles = 0
		for _, tile in ipairs(gv.tiles) do if tile:IsShown() then tiles = tiles + 1 end end
		local byNpc = {}
		for _, item in ipairs(NS:Gift30Candidates()) do byNpc[item.npc] = item end
		gv.search:SetText("Ours")
		if gv.search.scripts.OnTextChanged then gv.search.scripts.OnTextChanged(gv.search) end
		local found = 0
		for _, tile in ipairs(gv.tiles) do if tile:IsShown() then found = found + 1 end end
		local first = gv.tiles[1].gift.npc
		gv.search:SetText("")
		if gv.search.scripts.OnTextChanged then gv.search.scripts.OnTextChanged(gv.search) end
		Check("[GIFT] une vignette par espèce du Codex (6), la seule brillante copiée avec ses étoiles, recherche « Ours »",
			tiles == 6 and #NS:Gift30Candidates() == 6 and byNpc[8100] and byNpc[8100].stars == 3 and byNpc[8100].shinyOnly
			and found == 1 and first == 8100, tiles .. " / " .. found)
		local greyed = gv.confirm.qcEnabled == false
		NS:Gift30Toggle(8100); NS:Gift30Toggle(8001); NS:Gift30Toggle(8002)
		local capped = NS:Gift30Toggle(8003) == false and #f.giftPicks == 3 and gv.count:GetText() == NS:F("GIFT30_COUNT", 3, 3)
		NS:Gift30Toggle(8002)
		local unpicked = #f.giftPicks == 2
		NS:Gift30Toggle(8004)
		Check("[GIFT] rien de choisi : « Ajouter » grisé ; 3 au plus ; re-clic : reposée ; puis actif", greyed and capped and unpicked
			and gv.confirm.qcEnabled ~= false)
		local reserveBefore = NS:SpecimenReserveCount()
		local codexBefore = {}
		for _, npc in ipairs({ 8100, 8001, 8004 }) do codexBefore[npc] = NS:SpecimenReference(npc, false) end
		Mock:Reset()
		gv.confirm:Click()
		local gifts = NS:SpecimenList({ where = "reserve" })
		local okCopies = #gifts == 3
		for _, spec in ipairs(gifts) do
			local ref = NS:SpecimenReference(spec.npc, false) or NS:SpecimenReference(spec.npc, true)
			if spec.shiny or spec.origin ~= "gift3" or not ref or ref.stars ~= spec.stars or NS:SpecimenIsReference(spec.id) then okCopies = false end
		end
		Check("[GIFT] 3 copies en Réserve : jamais brillantes, mêmes étoiles, origine gift3", okCopies
			and NS:SpecimenReserveCount() == reserveBefore + 3)
		Check("[GIFT] … le Codex ne bouge pas ; « Cadeau de la 3.0 » sur la fiche et dans le chat",
			NS:SpecimenReference(8100, false) == codexBefore[8100] and NS:SpecimenReference(8001, false) == codexBefore[8001]
			and NS:SpecimenOriginText(gifts[1]):find(NS.L.RES_BY_GIFT3, 1, true) == 1 and Has(Mock:Output(), "Cadeau de la 3.0"))
		Check("[GIFT] une fois par compte ; puis la page Réserve et la visite du carnet", not NS:Gift30Available()
			and NS:Gift30Grant({ 8002 }) == false and f.resView == "reserve" and f.res.reserve:IsShown()
			and not f.res.reserve.giftButton:IsShown() and NS:TourActive() == "journal")
		NS:TourStop()
		f:Hide()
		-- « Plus tard » : le bouton reste dans la page Réserve
		P.Reset()
		Migrate(4, 0)
		NS:TourMark("journal", true)
		NS:OpenReserve("reserve")
		f = NS.journalFrame
		local rv = f.res.reserve
		local button = rv.giftButton:IsShown() and rv.giftButton.text:GetText() == NS:F("GIFT30_OPEN", 3)
		rv.giftButton:Click()
		local opens = f.resView == "gift" and f.res.gift:IsShown()
		f.res.gift.later:Click()
		Check("[GIFT] page Réserve : « Cadeau de la 3.0 : choisis 3 créatures » ouvre le choix ; « Plus tard » : cadeau gardé", button
			and opens and f.resView == "reserve" and NS:Gift30Available() and rv.giftButton:IsShown())
		-- la place de la Réserve compte
		for _ = 1, NS:ReserveCapacity() - 1 do
			NS:SpecimenAdd({ npc = 8001, stars = 1, name = "Bête 1" })
		end
		local count = NS:SpecimenReserveCount()
		local ok, why = NS:Gift30Grant({ 8001, 8002 })
		local refused = ok == false and why == "full" and NS:SpecimenReserveCount() == count and NS:Gift30Available()
		local ids = NS:Gift30Grant({ 8002 })
		Check("[GIFT] Réserve presque pleine : 2 copies refusées (« full »), une passe ; liste vide refusée", refused
			and type(ids) == "table" and #ids == 1 and NS:ReserveFull() and NS:Gift30Grant({}) == false, tostring(why) .. " " .. count)
		f:Hide()
	end

	P.Done()
end
