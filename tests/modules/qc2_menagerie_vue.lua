-- QC 2.4 : la Ménagerie façon bestiaire (MenagerieView.lua, JournalWindow.lua,
-- ns:MenagerieList dans Capture.lua). Trois paliers (verrouillée, croisée,
-- capturée), recherche qui ne dévoile jamais une inconnue, boutons de type
-- avec « Tous » et leurs comptes, recherche et type ensemble, tri par
-- abattues, brillante reconnue sans capture, modèle qui tourne.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local MV = {}

function MV.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "journalFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT = nil
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	local data = NS:CompanionData()
	data.tutoDone, data.capture = true, nil
	NS:TreatData().treatsInit = true
	NS:CompanionUpdateVisibility()
end

local function Lines(preview)
	local out = {}
	for _, line in ipairs(preview.lines) do out[#out + 1] = line.text or "" end
	return table.concat(out, " | ")
end

local function Row(pane, npc)
	for _, cell in ipairs(pane.items) do
		if cell:IsShown() and cell.entry and cell.entry.npc == npc then return cell end
	end
end

local function Shown(pane)
	local out = {}
	for _, cell in ipairs(pane.items) do
		if cell:IsShown() and cell.entry then out[#out + 1] = cell.entry.npc end
	end
	return out
end

do
	Say("-- QC 2.4 ménagerie : paliers, recherche, types")
	MV.Reset()
	local savedTable, savedFaction = rawget(NS, "ZONE_CREATURES"), NS.BestiaryFaction
	local savedShiny = NS.ShinyKnown
	NS.BestiaryFaction = function() return "H" end
	NS.ZONE_CREATURES = {
		[1413] = {
			[3201] = { lvl = { 10, 11 }, rank = 0, fr = "Kodo", en = "Kodo" },
			[3202] = { lvl = { 12, 13 }, rank = 1, fr = "Raptor", en = "Raptor" },
			[3203] = { lvl = { 14, 15 }, rank = 4, fr = "Esprit secret", en = "Secret spirit" },
			[3204] = { lvl = { 16, 17 }, rank = 0, fr = "Golem", en = "Golem" },
		},
	}
	NS.menagerieStatic = nil
	-- croisées : le kodo (capturé), le raptor (vu, jamais abattu), le golem
	-- (abattu deux fois) ; l'esprit, jamais croisé, reste verrouillé
	NS:BestiaryData()[1413] = {
		[3201] = { name = "Kodo des plaines", seen = true, killed = 4, type = "Bête", level = 11 },
		[3202] = { name = "Raptor tranchant", seen = true, killed = 0, type = "Bête", level = 12 },
		[3204] = { name = "Golem de fer", seen = true, killed = 2, type = "Mécanique", level = 16 },
	}
	local data = NS:CaptureData()
	data.creatures[3201] = { name = "Kodo des plaines", class = "normal", type = "Bête", zoneID = 1413, at = 1700000000 }
	data.count = 1
	-- la brillante du raptor a été repérée : reconnue sans capture
	NS.ShinyKnown = function(_, npc) if tonumber(npc) == 3202 then return 1700000500 end return savedShiny and savedShiny(NS, npc) end

	-- 1. Données : types, comptes, recherche, tri -------------------------------------------
	local all, stats = NS:MenagerieList({ zone = 1413 })
	local by = {}
	for _, e in ipairs(all) do by[e.npc] = e end
	Check("[MV] trois paliers : verrouillée, croisées, capturée", not by[3203].known and by[3202].known
		and not by[3202].captured and by[3201].captured)
	Check("[MV] type d'une inconnue : jamais dit", by[3203].typeKey == nil and by[3201].typeKey == "beast"
		and by[3204].typeKey == "mechanical")
	Check("[MV] comptes par type (croisées seulement)", stats.types.beast and stats.types.beast.known == 2
		and stats.types.beast.captured == 1 and stats.types.mechanical.known == 1 and stats.types.mechanical.captured == 0
		and stats.types.demon == nil)
	local beasts = NS:MenagerieList({ zone = 1413, ctype = "beast" })
	Check("[MV] filtre de type : les Bêtes", #beasts == 2 and beasts[1].typeKey == "beast" and beasts[2].typeKey == "beast")
	Check("[MV] filtre de type : Mécanique", #NS:MenagerieList({ zone = 1413, ctype = "mechanical" }) == 1)
	Check("[MV] filtre de type : rien de croisé, liste vide", #NS:MenagerieList({ zone = 1413, ctype = "demon" }) == 0)
	Check("[MV] « Tous » : sans filtre de type", #NS:MenagerieList({ zone = 1413, ctype = "all" }) == 4)
	local leaked = false
	for _, key in ipairs(NS.CREATURE_TYPES) do
		for _, e in ipairs(NS:MenagerieList({ zone = 1413, ctype = key })) do if e.npc == 3203 then leaked = true end end
	end
	Check("[MV] une inconnue ne tombe dans aucun type", not leaked)
	Check("[MV] recherche : le nom d'une inconnue ne la trouve pas", #NS:MenagerieList({ zone = 1413, search = "esprit" }) == 0
		and #NS:MenagerieList({ zone = "all", search = "secret" }) == 0)
	Check("[MV] recherche : une croisée se trouve", #NS:MenagerieList({ zone = 1413, search = "raptor" }) == 1)
	Check("[MV] recherche et type ensemble", #NS:MenagerieList({ zone = 1413, search = "raptor", ctype = "beast" }) == 1
		and #NS:MenagerieList({ zone = 1413, search = "kodo", ctype = "mechanical" }) == 0
		and #NS:MenagerieList({ zone = 1413, search = "golem", ctype = "mechanical" }) == 1)
	local byKills = NS:MenagerieList({ zone = 1413, sort = "kills" })
	Check("[MV] tri par abattues : le plus chassé d'abord", byKills[1].npc == 3201 and byKills[2].npc == 3204)

	-- 2. La page : rangées, fiches des trois paliers ------------------------------------------
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.menZone, f.menState, f.menRank, f.menSearch, f.menSort, f.menType = "here", "all", "all", "", "no", nil
	f.sections.menagerie:Click()
	local pane = f.men
	Check("[MV] tri « abattues » proposé", (function()
		for _, option in ipairs(pane.sort.options or {}) do if option.value == "kills" then return true end end
		return false
	end)())
	local locked, seen, golem, caught = Row(pane, 3203), Row(pane, 3202), Row(pane, 3204), Row(pane, 3201)
	Check("[MV] verrouillée : « ??? », point d'interrogation, case sombre", locked and locked.label.text == "???"
		and locked.icon.texture == "Interface\\Icons\\INV_Misc_QuestionMark"
		and locked.bg.vertex and locked.bg.vertex[1] == NS.Theme.FIELD[1] and locked.detail.text == "")
	local rare = NS.CAPTURE_RARITY.rare.color
	Check("[MV] verrouillée : « ??? » garde la couleur de sa rareté", locked and locked.label.textColor[1] == rare[1]
		and locked.label.textColor[2] == rare[2])
	Check("[MV] croisée : son nom et son type", seen and seen.label.text == "Raptor tranchant" and seen.detail.text == "Bête")
	Check("[MV] capturée : liseré vert, pas les autres", caught and caught.caught:IsShown() and not seen.caught:IsShown()
		and not locked.caught:IsShown())
	Check("[MV] brillante reconnue sans capture : losange au trait", seen.star:IsShown()
		and seen.star.texture == NS.Theme.DIAMOND_LINE)
	locked.hooks.OnEnter(locked)
	local p = pane.preview
	local text = Lines(p)
	Check("[MV] fiche verrouillée : ni nom, ni niveau, ni modèle", p.title.text == "???" and p.lines[1].text == NS.L.MENV_LOCKED
		and not text:find("Esprit", 1, true) and not text:find("14", 1, true) and p.model.creature == nil
		and not p.variant:IsShown(), text)
	Check("[MV] fiche verrouillée : la zone où la chercher", text:find("Les Tarides", 1, true) ~= nil
		and text:find(NS.L.JRN_MEN_NEVER, 1, true) ~= nil, text)
	golem.hooks.OnEnter(golem)
	text = Lines(p)
	Check("[MV] fiche croisée : nom, niveau, modèle, abattues", p.title.text == "Golem de fer" and text:find("16", 1, true)
		and text:find(NS:F("JRN_MEN_KILLED", 2), 1, true) and p.model.creature == 3204, text)
	Check("[MV] fiche croisée : effets de chasse cachés", not text:find("Chasse", 1, true), text)
	seen.hooks.OnEnter(seen)
	Check("[MV] brillante reconnue : bouton « Version brillante »", p.variant:IsShown()
		and Lines(p):find("Brillante repérée", 1, true) ~= nil, Lines(p))
	caught.hooks.OnEnter(caught)
	text = Lines(p)
	Check("[MV] fiche capturée : tout (capture, équiper)", p.title.text == "Kodo des plaines" and p.model.creature == 3201
		and (text:find("Capturée le", 1, true) or text:find("Qualité", 1, true))
		and text:find(NS.L.JRN_MEN_EQUIP, 1, true) ~= nil, text)
	if NS.CompanionEffectsLines then
		Check("[MV] fiche capturée : effets de chasse et de confort", text:find("Chasse", 1, true) ~= nil, text)
	end
	pane.zone:Choose("all")
	locked = Row(pane, 3203)
	Check("[MV] toutes zones : la verrouillée dit sa zone", locked and locked.detail.text == "Les Tarides", locked and locked.detail.text)
	pane.zone:Choose("here")

	-- 3. Boutons de type ------------------------------------------------------------------
	local types = pane.types
	Check("[MV] rangée de types : « Tous » et 8 boutons", types and types.all
		and #types.buttons == 8 and types.buttons.beast and types.buttons.mechanical)
	Check("[MV] « Tous » choisi au départ", types.all.selected and not types.buttons.beast.selected)
	local first = pane.items[1]
	local rowBottom = select(5, types:GetPoint()) - types:GetHeight()
	Check("[MV] la liste commence sous les boutons", select(5, first:GetPoint()) <= rowBottom - 4,
		select(5, first:GetPoint()) .. " / " .. rowBottom)
	Check("[MV] icônes du jeu désignées (rien de livré)", types.buttons.beast.icon.texture:find("^Interface\\Icons\\") ~= nil)
	types.buttons.beast.scripts.OnEnter(types.buttons.beast)
	local tip = table.concat(_G.GameTooltip.lines or {}, " | ")
	Check("[MV] infobulle : type et compte", tip:find("Bête", 1, true) and tip:find("1 capturées · 2 croisées", 1, true), tip)
	types.buttons.beast.scripts.OnLeave(types.buttons.beast)
	types.buttons.demon.scripts.OnEnter(types.buttons.demon)
	tip = table.concat(_G.GameTooltip.lines or {}, " | ")
	Check("[MV] infobulle : type jamais croisé", tip:find(NS.L.MENV_TYPE_NONE, 1, true) ~= nil and types.buttons.demon.empty, tip)
	types.buttons.demon.scripts.OnLeave(types.buttons.demon)
	types.buttons.beast:Click()
	local shown = Shown(pane)
	Check("[MV] clic sur Bête : seulement les Bêtes", f.menType == "beast" and #shown == 2
		and types.buttons.beast.selected and not types.all.selected, table.concat(shown, ","))
	Check("[MV] filtre actif écrit en clair", types.summary.text == "Bête : 1 capturées / 2 croisées", types.summary.text)
	pane.search:SetText("raptor")
	if pane.search.scripts and pane.search.scripts.OnTextChanged then pane.search.scripts.OnTextChanged(pane.search) end
	shown = Shown(pane)
	Check("[MV] recherche + type dans la page", #shown == 1 and shown[1] == 3202, table.concat(shown, ","))
	pane.search:SetText("esprit")
	if pane.search.scripts and pane.search.scripts.OnTextChanged then pane.search.scripts.OnTextChanged(pane.search) end
	Check("[MV] recherche d'une inconnue dans la page : rien", #Shown(pane) == 0)
	pane.search:SetText("")
	if pane.search.scripts and pane.search.scripts.OnTextChanged then pane.search.scripts.OnTextChanged(pane.search) end
	types.buttons.beast:Click()
	Check("[MV] second clic : le filtre s'enlève", f.menType == nil and types.all.selected and #Shown(pane) == 4)
	types.buttons.mechanical:Click()
	shown = Shown(pane)
	Check("[MV] Mécanique : le golem", f.menType == "mechanical" and #shown == 1 and shown[1] == 3204)
	types.all:Click()
	Check("[MV] « Tous » : tout revient", f.menType == nil and #Shown(pane) == 4 and types.summary.text == "")
	types.buttons.beast:Click()
	NS:OpenMenagerieZone(1413)
	Check("[MV] ouverte depuis une zone : filtre de type oublié", f.menType == nil and types.all.selected)

	-- 4. Le modèle tourne à la souris ------------------------------------------------------------
	local model = p.model
	Check("[MV] modèle : glisser branché", model.qcRotate == true and model.scripts.OnMouseDown ~= nil)
	Mock.world.cursorX = 500
	model.scripts.OnMouseDown(model, "LeftButton")
	Check("[MV] glisser : suivi pendant le geste seulement", model.scripts.OnUpdate ~= nil and model.dragX == 500)
	Mock.world.cursorX = 560
	model.scripts.OnUpdate(model)
	model.scripts.OnMouseUp(model, "LeftButton")
	Check("[MV] lâcher : plus rien à chaque image", model.scripts.OnUpdate == nil and model.dragX == nil)
	Mock.world.cursorX = nil

	f:Hide()
	NS.ZONE_CREATURES, NS.BestiaryFaction, NS.menagerieStatic, NS.ShinyKnown = savedTable, savedFaction, nil, savedShiny
	ResetWorld()
end

-- 5. Textes : français et anglais ----------------------------------------------------------------
do
	local strings = NS.MENAGERIE_VIEW_STRINGS
	local same = strings ~= nil
	for key in pairs(strings and strings.fr or {}) do if not strings.en[key] then same = false end end
	for key in pairs(strings and strings.en or {}) do if not strings.fr[key] then same = false end end
	Check("[MV] textes : mêmes clés en français et en anglais", same)
end
