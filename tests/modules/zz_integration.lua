-- Intégration : TOUS les modules chargés en même temps. Chaque module, testé
-- seul, tient dans le panneau ; c'est leur somme qui a fait déborder la
-- navigation sur le pied en v1.23.0 (« Marchand » sous les boutons). Aussi :
-- modules déclarés et uniques, alias sans conflit, premier relevé du
-- compagnon silencieux, ornements verrouillés, simulation du résumé de stuff,
-- compagnon et suivi du carnet ensemble, coffre avec le vrai catalogue, part
-- de complétion dans son onglet.
local Check, ResetWorld, NS, QNS = T.Check, T.ResetWorld, T.NS, T.QNS

ResetWorld()
NS.optionsFrame = nil
NS:ToggleOptions()
local frame, lay = NS.optionsFrame, NS.OPT_LAYOUT
-- la navigation (entrées de premier niveau) s'arrête au-dessus de la version,
-- en bas de la colonne (18 px du bas, une ligne)
local navFloor = -(lay.height - 2 - 40)
-- ordre : tous les modules avant le titre QOL, un seul titre par groupe
local seenQol, misplaced = false, {}
for _, def in ipairs(NS.OPTION_PAGES) do
	if def.group == "OPT_GROUP_QOL" then seenQol = true
	elseif seenQol then misplaced[#misplaced + 1] = def.id end
end
-- titres : le Check avant le départ, MODULES, le Confort de jeu ; chacun une fois
local titles, twice = {}, 0
for _, label in ipairs(frame.navGroups) do
	if titles[label.text] then twice = twice + 1 end
	titles[label.text] = true
end
Check("[INT] navigation au-dessus de la version, panneau à l'écran, trois titres de groupe uniques, aucun module sous le QoL",
	frame.navBottom >= navFloor and lay.height <= lay.maxHeight and #frame.navGroups == 3 and twice == 0 and #misplaced == 0,
	frame.navBottom .. " >= " .. navFloor .. " / " .. #frame.navGroups .. " / " .. table.concat(misplaced, ","))

local overflow = {}
for id in pairs(frame.pages) do
	for _, miss in ipairs(NS:OptionsUnreachable(id)) do overflow[#overflow + 1] = miss end
end
Check("[INT] chaque page de module se voit en entier (défilement)", #overflow == 0, table.concat(overflow, ", "))

-- QuestCompanion : son propre panneau (même socle), mêmes règles
do
	QNS.optionsFrame = nil
	QNS:ToggleOptions()
	local qframe = QNS.optionsFrame
	local qoverflow = {}
	for id in pairs(qframe.pages) do
		for _, miss in ipairs(QNS:OptionsUnreachable(id)) do qoverflow[#qoverflow + 1] = miss end
	end
	Check("[INT] QC : chaque page se voit en entier, navigation au-dessus de la version", #qoverflow == 0
		and qframe.navBottom >= navFloor, table.concat(qoverflow, ", ") .. " / " .. qframe.navBottom)
	qframe:Hide()
end

local seen, dup = {}, {}
for _, module in ipairs(NS.MODULES) do
	if seen[module.id] then dup[#dup + 1] = module.id end
	seen[module.id] = true
end
Check("[INT] identifiants de module uniques", #dup == 0, table.concat(dup, ","))
Check("[INT] les modules sont déclarés", seen.depart and seen.stuff and seen.portrait and seen.camp and seen.expedition and seen.dungeon
	and seen.reward and seen.pace and seen.bagspace and seen.death
	and not seen.companion and not seen.journal,     -- compagnon et carnet : QuestCompanion (v1.26.0)
	(function() local t = {} for id in pairs(seen) do t[#t + 1] = id end table.sort(t) return table.concat(t, ",") end)())

-- un alias de module ne doit jamais masquer l'identifiant d'un contrôle :
-- « /r2q module bags off » (forme d'avant la v1.22.0) vise le contrôle Sacs
do
	local clash = {}
	for _, def in ipairs(NS.checks or {}) do
		if NS:FindModule(def.id) then clash[#clash + 1] = def.id end
	end
	ResetWorld()
	NS:HandleCommand("module bags off")
	Check("[INT] aucun alias de module ne masque un contrôle : /r2q module bags off coupe le contrôle Sacs", #clash == 0
		and NS:IsModuleEnabled("bags") == false and NS:DB().bagspaceEnabled ~= false, table.concat(clash, ","))
	NS:SetModuleEnabled("bags", true)
end

-- un module ne doit jamais parler pendant qu'un autre agit : le premier relevé
-- du compagnon est silencieux, même s'il naît d'un tampon et pas d'une connexion
do
	ResetWorld()
	T.Mock.world.level = 45
	T.Mock:Reset()
	if QNS.FireCallback then QNS:FireCallback("STAMP", { id = "zone:1", kind = "zone", name = "Test", new = true }) end
	Check("[INT] compagnon : premier relevé silencieux (pas de rafale de déblocages)",
		not T.Mock:Output():find("débloqué", 1, true), T.Mock:Output())
end

-- réglages du compagnon : un ornement verrouillé n'affiche pas un interrupteur allumé
do
	ResetWorld()
	QNS.optionsFrame = nil
	QNS:ToggleOptions()
	QNS:SelectOptionsPage("companion")
	local wrong = {}
	for _, def in ipairs(QNS.COMPANION_ORNAMENTS or {}) do
		for _, row in ipairs(QNS.optionsFrame.rows) do
			if row.def and row.def.key == def.key and not QNS:CompanionIsUnlocked("orn", def)
				and (row.toggle:IsShown() or not (row.lock and row.lock:IsShown())) then
				wrong[#wrong + 1] = def.key
			end
		end
	end
	Check("[INT] ornements verrouillés : un verrou à la place de l'interrupteur", #wrong == 0, table.concat(wrong, ","))
end

-- Résumé de stuff : « Simuler un changement » montre un vrai cadre, au-dessus
-- du panneau de réglages, avec les stats de la classe et un gain + une perte
do
	ResetWorld()
	NS.optionsFrame = nil
	NS.toastFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("toast")
	local page = NS.optionsFrame.pages.toast
	NS:DB().showGearToast = false            -- même module coupé, l'aperçu s'affiche
	page.actionButtons.toastPreview:Click()
	local toast = NS.toastFrame
	Check("[INT] « Simuler un changement » : le cadre s'affiche au-dessus des réglages, le panneau reste ouvert",
		toast and toast:IsShown() == true and toast.strata == "FULLSCREEN_DIALOG" and NS.optionsFrame:IsShown() == true,
		toast and toast.strata)
	-- une seule ligne s'affiche : la stat principale de la classe, qui alterne
	-- gain (1er clic) et perte (2e clic) pour voir les deux flèches
	local first = NS:SimulateGearToast()
	local second = NS:SimulateGearToast()
	Check("[INT] simulation : stat principale de la classe (guerrier du harnais), un clic gain, le suivant perte",
		first[1].label == "STR" and second[1].label == "STR" and (first[1].delta > 0) ~= (second[1].delta > 0),
		first[1].label .. " " .. first[1].delta .. " / " .. second[1].delta)
	-- l'aperçu s'efface tout seul et rend sa couche normale au cadre
	T.Mock:Advance(30)
	local gone = toast:IsShown() == false and toast.strata == "HIGH"
	NS:DB().showGearToast = true
	NS:ShowGearToast({ { label = "STR", kind = "integer", polarity = true, delta = 2 } })
	Check("[INT] simulation : s'efface toute seule, couche normale rendue ; vrai changement en couche normale", gone
		and toast.strata == "HIGH", toast.strata)
end

-- Compagnon ↔ suivi du carnet : chaque agent a testé contre une doublure de
-- l'autre. Ici, les deux vraies fonctions ensemble.
do
	ResetWorld()
	T.Mock.world.level = 15
	local unlocks = QNS:CompanionNextUnlocks()
	local objectives = QNS:JournalObjectives()
	local fromCompanion, text = 0, {}
	for _, goal in ipairs(objectives) do
		-- un stade du compagnon : sa propre ligne, ou fusionné dans le palier de même niveau
		if goal.source == "companion" or table.concat(goal.rewards or {}, " "):find("devient", 1, true) then
			fromCompanion = fromCompanion + 1
		end
		text[#text + 1] = tostring(goal.label) .. " " .. tostring(goal.progress)
	end
	local joined = table.concat(text, " | ")
	Check("[INT] suivi : prochains déblocages du compagnon affichés avec leur progression", type(unlocks) == "table"
		and #unlocks > 0 and fromCompanion > 0 and joined:find("niveau 20 15/20", 1, true) ~= nil, joined)
	Check("[INT] suivi : aucune clé de traduction brute", not joined:find("JRN_", 1, true) and not joined:find("COMP_", 1, true), joined)
end

-- Coffre de zone avec le vrai catalogue (CompanionData.lua) : chaque palier
-- propose de quoi choisir, et un objet choisi s'applique au cadre
do
	ResetWorld()
	local counts = {}
	for tier = 1, 3 do counts[tier] = #QNS:ChestOptions(tier) end

	local labels, raw = {}, false
	for _, reward in ipairs(QNS:ChestOptions(2)) do
		local text = QNS:ChestRewardLabel(reward)
		labels[#labels + 1] = text
		if text:find("COMP_", 1, true) or text:find("OPT_", 1, true) then raw = true end
	end
	Check("[INT] coffre : au moins 7 objets par palier, libellés traduits", counts[1] >= 7 and counts[2] >= 7 and counts[3] >= 7
		and not raw and #labels > 0, counts[1] .. "/" .. counts[2] .. "/" .. counts[3] .. " " .. table.concat(labels, ", "))
	local data = QNS:CompanionData()
	QNS:ChestData()[4242] = { tier = 1, name = "Zone test", at = 0 }
	local frame
	for _, reward in ipairs(QNS:ChestOptions(1)) do
		if reward.kind == "frame" then frame = reward; break end
	end
	Check("[INT] coffre : un cadre au palier 1, choisi, débloqué, sélectionnable", frame ~= nil
		and QNS:ChestPick(4242, frame) == true and data.unlocked["frame:" .. frame.id] == true
		and QNS:CompanionIsUnlocked("frame", QNS:CompanionStyleDef("frame", frame.id)) == true)
	QNS:ChestData()[4242] = nil
end

-- Fenêtre du carnet : chaque part de complétion a son onglet d'activité
do
	local tabs, quests = {}, nil
	for _, def in ipairs(QNS.ZONE_PARTS) do
		if def.id == "quests" then quests = def end
	end
	-- une part factice de l'onglet Quêtes s'affiche dans la fenêtre
	local fake = { id = "fakeq", label = "JRN_PART_quests", tab = "quests",
		Compute = function() return { have = 1, need = 2 } end,
		Items = function() return { { name = "Quête A", done = false, detail = "niveau 12" }, { name = "Quête B", done = true } } end }
	QNS.RegisterZonePart(fake)
	local rows = QNS:JournalActivityRows(1413, "quests")
	local found = false
	for _, row in ipairs(rows) do if row.name == "Quête A" and row.detail == "niveau 12" then found = true end end
	Check("[INT] part Quêtes : son onglet ; une part de l'onglet Quêtes y est listée", quests and quests.tab == "quests"
		and type(quests.Items) == "function" and found and rows[1].header)
	for index = #QNS.ZONE_PARTS, 1, -1 do if QNS.ZONE_PARTS[index] == fake then table.remove(QNS.ZONE_PARTS, index) end end
end
