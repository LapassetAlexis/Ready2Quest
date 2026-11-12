-- Mise en page des vraies fenêtres (géométrie absolue de tests/snapshot.lua,
-- scènes de l'aperçu hors-jeu) : chaque fenêtre de Ready2Quest et de
-- QuestCompanion construite sans chevauchement, rien ne sort, libellés du pied
-- tenus, hauteur qui suit la liste ; pages du carnet (cartes, pagination,
-- Créatures, Complétion), coffre, cadres à l'écran du compagnon. Puis la
-- Réserve et l'Échoppe du dresseur (3.0) dans les deux styles : rangée du haut
-- à une seule hauteur, pastille de monnaie, refus d'achat expliqué au clic,
-- aucun cadre créé au rafraîchissement ; visite guidée, colonne de navigation.
-- Les briques elles-mêmes : ui_bricks.lua.
local Check, Say, NS, QNS, Mock = T.Check, T.Say, T.NS, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()

local function Near(a, b) return math.abs((a or 0) - (b or 0)) < 0.01 end
local function SameColor(c, token) return c and Near(c[1], token[1]) and Near(c[2], token[2]) and Near(c[3], token[3]) end
local failed = {}
local function Want(label, ok, extra)
	if not ok then failed[#failed + 1] = extra ~= nil and (label .. " (" .. tostring(extra) .. ")") or label end
	return ok
end
local function Verdict(name) Check(name, #failed == 0, table.concat(failed, " | ")); failed = {} end

-- Ready2Quest -----------------------------------------------------------------
do
local Theme = NS.Theme
-- 3. Chaque fenêtre : construite sans chevauchement -------------------------
-- Les scènes de l'aperçu posent des données d'exemple ; elles remplacent des
-- méthodes de NS (scans) et la taille d'UIParent : tout est rendu ensuite.
local function SceneR2Q(name)
	local saved, savedW, savedH = {}, UIParent.width, UIParent.height
	for key, value in pairs(NS) do saved[key] = value end
	local savedColor = rawget(_G, "CreateColor")
	_G.CreateColor = savedColor or Mock.CreateColor
	local ok, frame = pcall(Snap.scenes[name], T)
	_G.CreateColor = savedColor
	local restore = function()
		for key in pairs(NS) do if saved[key] == nil then NS[key] = nil end end
		for key, value in pairs(saved) do NS[key] = value end
		UIParent.width, UIParent.height = savedW, savedH
		for index = 1, 3 do _G["QuestInfoRewardsFrameQuestInfoItem" .. index] = nil end
	end
	if not ok then restore(); return nil, frame end
	return frame, restore
end

-- blocs, chevauchements, sorties du cadre : tests/snapshot.lua
local function Layout(root) return Snap.Layout(root) end

do
	Say("-- Ready2Quest : chaque fenêtre, sans chevauchement")
	local scenes = { "r2q-check", "r2q-dungeon", "r2q-expedition", "r2q-death", "r2q-lootroom", "r2q-spellranks",
		"r2q-bagspace", "r2q-camp", "r2q-portrait", "r2q-gear-toast", "r2q-settings-canvas" }
	local built, overlapping, outsiders, labels = {}, {}, {}, {}
	for _, name in ipairs(scenes) do
		local frame, restore = SceneR2Q(name)
		if not frame then
			built[#built + 1] = name .. " : " .. tostring(restore)
		else
			local overlaps, outside, count = Layout(frame)
			if count < (name == "r2q-camp" and 1 or 2) then built[#built + 1] = name .. " : " .. count .. " textes" end
			for _, o in ipairs(overlaps) do overlapping[#overlapping + 1] = name .. " : " .. o end
			for _, o in ipairs(outside) do outsiders[#outsiders + 1] = name .. " : " .. o end
			-- boutons du pied : libellé tenu
			for _, side in pairs(frame.footer and frame.footerButtons or {}) do
				for _, button in ipairs(side) do
					if button:GetWidth() < button.text:GetStringWidth() + 16 then labels[#labels + 1] = name .. " : " .. button:GetText() end
				end
			end
			restore()
		end
	end
	Check("[WIN] chaque fenêtre de Ready2Quest construite, du texte à lire", #built == 0, table.concat(built, " | "))
	Check("[WIN] chaque fenêtre de Ready2Quest : aucun chevauchement", #overlapping == 0, table.concat(overlapping, " | "))
	Check("[WIN] chaque fenêtre de Ready2Quest : rien ne sort du cadre", #outsiders == 0, table.concat(outsiders, " | "))
	Check("[WIN] chaque fenêtre de Ready2Quest : libellés des boutons du pied tenus", #labels == 0, table.concat(labels, ", "))

	-- fenêtres de module : en-tête compact et pied partout
	local dialogs = {}
	for _, name in ipairs({ "r2q-check", "r2q-dungeon", "r2q-expedition", "r2q-death", "r2q-lootroom", "r2q-spellranks" }) do
		local frame, restore = SceneR2Q(name)
		if frame then
			if not (frame.chrome == "dialog" and frame.header.compact and frame.footer and frame.title.text ~= "") then
				dialogs[#dialogs + 1] = name
			end
			restore()
		end
	end
	Check("[WIN] six fenêtres de module : en-tête compact titré et pied", #dialogs == 0, table.concat(dialogs, ","))

	-- les listes suivent leur nombre de lignes : la dernière carte au-dessus du pied
	local rooms = {}
	for _, name in ipairs({ "r2q-lootroom", "r2q-spellranks" }) do
		local frame, restore = SceneR2Q(name)
		if frame then
			local last
			for _, row in ipairs(frame.rows) do if row:IsShown() then last = row end end
			local _, _, _, _, y = last:GetPoint()
			local room = frame:GetHeight() - Theme.DIALOG_FOOTER - (-y + last:GetHeight())
			if not (room >= 8 and room <= 20) then rooms[#rooms + 1] = name .. "=" .. room end
			restore()
		else
			rooms[#rooms + 1] = name .. " : pas construite"
		end
	end
	Check("[WIN] salle de butin, rangs de sorts : la hauteur suit la liste (pas de cartes vides)", #rooms == 0, table.concat(rooms, ", "))

	-- rangées alternées dans les listes
	local frame, restore = SceneR2Q("r2q-check")
	if frame then
		Check("[WIN] check : rangées alternées, le tampon tient son verdict", SameColor(frame.rows[1].bg.vertex, Theme.ROW)
			and SameColor(frame.rows[2].bg.vertex, Theme.ROW_ALT) and frame.stamp:GetWidth() >= frame.verdict:GetStringWidth() + 16)
		restore()
	end
end
end

-- QuestCompanion ---------------------------------------------------------------
do
local Theme = QNS.Theme
-- 2. Chaque fenêtre et cadre : construit sans chevauchement -----------------
local function Scene(name)
	local saved, savedQ, savedW, savedH = {}, {}, UIParent.width, UIParent.height
	for key, value in pairs(NS) do saved[key] = value end
	for key, value in pairs(QNS) do savedQ[key] = value end
	local savedColor = rawget(_G, "CreateColor")
	_G.CreateColor = savedColor or Mock.CreateColor
	local ok, frame = pcall(Snap.scenes[name], T)
	_G.CreateColor = savedColor
	local restore = function()
		for _, ns in ipairs({ { NS, saved }, { QNS, savedQ } }) do
			local target, copy = ns[1], ns[2]
			for _, field in ipairs({ "journalFrame", "companionFrame", "companionBubble", "companionHover", "chestFrame",
				"treatMenu", "journalToast", "journalTracker" }) do
				if rawget(target, field) and rawget(target, field) ~= copy[field] then target[field]:Hide() end
			end
			for key in pairs(target) do if copy[key] == nil then target[key] = nil end end
			for key, value in pairs(copy) do target[key] = value end
		end
		UIParent.width, UIParent.height = savedW, savedH
		T.ResetWorld()
	end
	if not ok then restore(); return nil, frame end
	return frame, restore
end

local function Rect(region) return Snap.Rect(region, { memo = {} }) end
local function Bottom(region) local r = Rect(region); return r and (r.top + r.height) end

-- les cartes visibles d'une liste : leurs textes tiennent dedans, sans se chevaucher
local function CardsClean(cards, ignore)
	local bad, count = {}, 0
	for _, card in ipairs(cards or {}) do
		if Snap.Visible(card) then
			count = count + 1
			local overlaps, outside = Snap.Layout(card, Snap.Texts(card), Rect(card))
			for _, o in ipairs(overlaps) do if not (ignore and ignore[o]) then bad[#bad + 1] = o end end
			for _, o in ipairs(outside) do bad[#bad + 1] = "hors carte : " .. o end
		end
	end
	return bad, count
end

-- la dernière carte visible reste au-dessus de la pagination (et du pied)
local function AbovePager(cards, pager, footer)
	local lowest = 0
	for _, card in ipairs(cards or {}) do
		if Snap.Visible(card) then lowest = math.max(lowest, Bottom(card) or 0) end
	end
	local limit = math.min(pager and (Rect(pager) or {}).top or math.huge, footer and (Rect(footer) or {}).top or math.huge)
	return lowest > 0 and lowest <= limit - 4, lowest, limit
end

do
	Say("-- QuestCompanion : chaque fenêtre, sans chevauchement")
	local journal = {
		-- carnet 1.5.0 : Zones, Zone (et son onglet Combat) et Collection sont
		-- remplacées par la Complétion (et la Ménagerie / le Compagnon)
		{ "qc-journal-creature", "evolution" }, { "qc-journal-progress", "progress" }, { "qc-journal-day", "day" },
		{ "qc-journal-menagerie", "menagerie" },
	}
	local G = { built = {}, overlapping = {}, outside = {}, foot = {}, cards = {}, pager = {}, names = {} }
	for _, spec in ipairs(journal) do
		local name, kind = spec[1], spec[2]
		local frame, restore = Scene(name)
		if not frame then
			G.built[#G.built + 1] = name .. " : " .. tostring(restore)
		else
			local overlaps, outside, count = Snap.Layout(frame)
			if not (frame.kind == kind and count >= 10) then G.built[#G.built + 1] = name .. " : page " .. tostring(frame.kind) .. ", " .. count end
			if not (frame.chrome == "journal" and frame.width == 980 and frame.height == 680 and frame.nav and frame.footer and frame.header) then
				G.built[#G.built + 1] = name .. " : pas la fenêtre 980 × 680 avec navigation et pied"
			end
			for _, o in ipairs(overlaps) do G.overlapping[#G.overlapping + 1] = name .. " : " .. o end
			for _, o in ipairs(outside) do G.outside[#G.outside + 1] = name .. " : " .. o end
			-- pied : le garde-manger à gauche s'arrête avant « Fermer »
			local close = Rect(frame.closeButton)
			local lastPantry = 0
			for _, button in pairs(frame.pantry or {}) do
				local r = Rect(button)
				lastPantry = math.max(lastPantry, r.left + r.width)
			end
			if not (close and lastPantry > 0 and lastPantry < close.left - 12
				and frame.closeButton:GetWidth() >= frame.closeButton.text:GetStringWidth() + 16) then
				G.foot[#G.foot + 1] = name .. " : " .. tostring(lastPantry) .. " / " .. tostring(close and close.left)
			end
			-- cartes de la page : textes tenus, la dernière au-dessus de la pagination
			local pane = ({ evolution = frame.evo, progress = frame.prog, day = frame.day,
				menagerie = frame.men })[kind]
			local lists = {}
			for _, field in ipairs({ "tiles", "cards", "items", "rows", "missions", "slots", "needs", "facts", "lines",
				"marks", "parts", "zones" }) do
				if pane[field] then lists[#lists + 1] = pane[field] end
			end
			local bad, cards = {}, 0
			-- Ménagerie : le nom (une ligne, coupé à sa largeur fixe) et le type
			-- (calé à droite dans 90 px) ont des cadres qui se recouvrent de
			-- quelques pixels ; on mesure ici les glyphes du type : le nom coupé
			-- doit s'arrêter avant eux
			local ignore = {}
			if kind == "menagerie" then
				for _, row in ipairs(pane.items) do
					if Snap.Visible(row) and row.detail.text ~= "" and row.detail.justifyH == "RIGHT" then
						local label, detail = Rect(row.label), Rect(row.detail)
						local glyphs = Snap.MeasureText(row.detail)
						local clear = label.left + label.width <= detail.left + detail.width - glyphs - 4
						if not clear then G.names[#G.names + 1] = row.label.text end
						if clear then ignore[Snap.Label(row.label) .. " / " .. Snap.Label(row.detail)] = true end
					end
				end
			end
			for _, list in ipairs(lists) do
				local b, n = CardsClean(list, ignore)
				cards = cards + n
				for _, o in ipairs(b) do bad[#bad + 1] = o end
			end
			if not (cards > 0 and #bad == 0) then G.cards[#G.cards + 1] = name .. " (" .. cards .. ") : " .. table.concat(bad, " | ") end
			for _, list in ipairs(lists) do
				if list and list[1] and pane.pager then
					local ok, lowest, limit = AbovePager(list, Snap.Visible(pane.pager) and pane.pager or nil, frame.footer)
					if lowest > 0 and not ok then G.pager[#G.pager + 1] = name .. " : " .. lowest .. " / " .. limit end
				end
			end
			restore()
		end
	end
	Check("[CV] chaque page du carnet : la bonne page, du texte, fenêtre 980 × 680 avec navigation et pied", #G.built == 0,
		table.concat(G.built, " | "))
	Check("[CV] chaque page du carnet : aucun chevauchement", #G.overlapping == 0, table.concat(G.overlapping, " | "))
	Check("[CV] chaque page du carnet : rien ne sort de la fenêtre", #G.outside == 0, table.concat(G.outside, " | "))
	Check("[CV] chaque page du carnet : pied tenu (garde-manger avant « Fermer », libellé tenu)", #G.foot == 0, table.concat(G.foot, " | "))
	Check("[CV] chaque page du carnet : chaque carte tient ses textes, la dernière rangée au-dessus de la pagination",
		#G.cards == 0 and #G.pager == 0, table.concat(G.cards, " | ") .. " " .. table.concat(G.pager, " | "))
	Check("[CV] Créatures : chaque nom coupé s'arrête avant son type", #G.names == 0, table.concat(G.names, ", "))

	-- (onglet Combat de la page Zone supprimé : le bestiaire d'une zone vit dans la
	-- Ménagerie, la Complétion n'en garde qu'une ligne et un bouton)
	-- Ménagerie : grille à gauche de l'aperçu
	frame, restore = Scene("qc-journal-menagerie")
	if frame then
		local men = frame.men
		local preview = Rect(men.preview)
		local right = 0
		for _, cell in ipairs(men.items) do
			if cell:IsShown() then local r = Rect(cell); right = math.max(right, r.left + r.width) end
		end
		Check("[CV] Créatures : cases à gauche de l'aperçu", right > 0 and right <= preview.left - 8,
			tostring(right) .. " / " .. tostring(preview.left))
		restore()
	end
	-- Complétion (ex-page Zone, Exploration) : la liste des villages, sans aperçu ;
	-- le suivi à l'écran est dans la carte de la zone, à droite du nom
	frame, restore = Scene("qc-journal-progress")
	if frame then
		local prog = frame.prog
		local card, watch, name = Rect(prog.card), Rect(prog.watchLabel), Rect(prog.name)
		Check("[CV] Complétion : Les Tarides, villages listés ; « suivre à l'écran » dans la carte, à droite du nom", frame.zoneID == 1413
			and frame.progPart == nil and prog.items[1]:IsShown() and prog.head.text:find("Villages", 1, true) ~= nil
			and watch.top >= card.top
			and watch.left + watch.width <= card.left + card.width and watch.left > name.left + prog.name:GetWidth(),
			prog.head.text .. " / " .. tostring(watch.left) .. " / " .. tostring(name.left + prog.name:GetWidth()))
		restore()
	end

	-- fenêtre de module : le coffre
	local chest, done = Scene("qc-chest")
	if not chest then
		Check("[CV] coffre : construit", false, done)
	else
		local overlaps, outside, count = Snap.Layout(chest)
		local bad = {}
		for _, side in pairs(chest.footerButtons) do
			for _, button in ipairs(side) do
				if button:GetWidth() < button.text:GetStringWidth() + 16 then bad[#bad + 1] = button:GetText() end
			end
		end
		Check("[CV] coffre : fenêtre de module titrée, sans chevauchement, rien ne sort, libellés du pied tenus",
			chest.chrome == "dialog" and chest.title.text ~= "" and chest.footer ~= nil and count >= 3 and #overlaps == 0
			and #outside == 0 and #bad == 0, table.concat(overlaps, " | ") .. " / " .. table.concat(outside, " | ") .. " / "
			.. table.concat(bad, ","))
		local last = 0
		for _, option in ipairs(chest.options) do if option:IsShown() then last = math.max(last, Bottom(option)) end end
		local foot = Rect(chest.footer)
		local tiles = CardsClean(chest.options)
		Check("[CV] coffre : la hauteur suit les objets, chaque tuile tient sa sorte et son nom", last > 0 and last <= foot.top - 8
			and last >= foot.top - 30 and #tiles == 0, tostring(last) .. " / " .. tostring(foot.top) .. " " .. table.concat(tiles, " | "))
		done()
	end

	-- cadres à l'écran : bulle, tutoriel, fiche au survol, garde-manger, bandeau, suivi
	local messy, content = {}, {}
	local function Clean(root, label)
		local overlaps, outside, count = Snap.Layout(root)
		if not (#overlaps == 0 and #outside == 0 and count >= 1) then
			messy[#messy + 1] = label .. " : " .. table.concat(overlaps, " | ") .. " / " .. table.concat(outside, " | ")
		end
	end
	local function Has(label, ok, extra) if not ok then content[#content + 1] = label .. (extra and (" " .. tostring(extra)) or "") end end
	local _, back = Scene("qc-companion")
	if back then
		local bubble = QNS.companionBubble
		Has("bulle : brique du thème, au-dessus du cadre", bubble and bubble.chrome == "bubble" and bubble:IsShown()
			and Bottom(bubble) <= Rect(QNS.companionFrame).top)
		Clean(bubble, "bulle")
		Has("cadre du compagnon : le nom et l'humeur en plaque, sous le modèle", QNS.companionFrame.name.text == "Brindille"
			and QNS.companionFrame.mood.text ~= "" and not QNS.companionFrame.mood.text:find("|c", 1, true))
		back()
	end
	_, back = Scene("qc-tutorial")
	if back then
		local bubble = QNS.companionBubble
		Has("tutoriel : Passer au trait, Suivant plein", bubble.nextButton:IsShown() and bubble.skipButton:IsShown()
			and bubble.nextButton.style == "primary" and bubble.skipButton.style == "outline")
		local text, nextB = Rect(bubble.text), Rect(bubble.nextButton)
		Has("tutoriel : boutons sous le texte, dans la bulle", nextB.top >= text.top + bubble.textHeight - 1
			and Bottom(bubble.nextButton) <= Bottom(bubble), tostring(nextB.top) .. " / " .. tostring(text.top + bubble.textHeight))
		Clean(bubble, "tutoriel")
		back()
	end
	_, back = Scene("qc-companion-hover")
	if back then
		local hover = QNS.companionHover
		Has("fiche au survol : bandeau du thème, valeurs des envies", hover.chrome == "toast"
			and hover.bars.mood.value.text == "91 %")
		Clean(hover, "fiche au survol")
		Has("fiche au survol : l'aide finit dans le cadre", Bottom(hover.hint) <= Bottom(hover),
			tostring(Bottom(hover.hint)) .. " / " .. tostring(Bottom(hover)))
		back()
	end
	_, back = Scene("qc-pantry")
	if back then
		local menu = QNS.treatMenu
		Has("garde-manger : bandeau du thème, une case par friandise", menu.chrome == "toast" and menu.buttons.festin)
		Clean(menu, "garde-manger")
		back()
	end
	local toast
	toast, back = Scene("qc-notify")
	if toast then
		Has("bandeau du carnet : brique du thème, liseré ambre", toast.chrome == "toast"
			and SameColor(toast.accent.vertex, Theme.GOLD) and toast.text.text == "Camp Taurajo")
		Clean(toast, "bandeau du carnet")
		back()
	end
	local tracker
	tracker, back = Scene("qc-tracker")
	if tracker then
		for _, o in ipairs(CardsClean(tracker.lines)) do messy[#messy + 1] = "suivi : " .. o end
		back()
	end
	Check("[CV] cadres à l'écran (bulle, tutoriel, fiche au survol, garde-manger, bandeau, suivi) : aucun chevauchement, rien ne sort",
		#messy == 0, table.concat(messy, " || "))
	Check("[CV] cadres à l'écran : briques du thème, bulle au-dessus du cadre, boutons du tutoriel dans la bulle, contenus",
		#content == 0, table.concat(content, " | "))
end
end

-- QuestCompanion 3.0 : Réserve, Échoppe, visite, navigation --------------------------------------------
do
local ResetWorld = T.ResetWorld
local NS = QNS
local Theme = NS.Theme
local C = { saved = {} }
local GLOBALS = { "UnitLevel", "InCombatLockdown", "UnitAffectingCombat", "C_Timer" }
for _, name in ipairs(GLOBALS) do C.saved[name] = rawget(_G, name) end
local FIELDS = { "journalFrame", "trainerFrame", "companionFrame", "companionBubble", "effectsConfirm" }
local ZONE = 1413

local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for i = 1, 3 do if math.abs((a[i] or -1) - (b[i] or -2)) > 0.001 then return false end end
	return true
end
local function Has(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end

function C.Reset(style)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle, NS.uiStyleCache, NS.errors, NS.carnetInkMisses = nil, {}, {}, nil
	NS.specimenCountCache, NS.codexReserveCache, NS.codexZoneCache = nil, nil, nil
	NS:DB().journalState, NS:DB().capture, NS:DB().journalTab = nil, nil, nil
	Mock.world.maps[ZONE] = { mapID = ZONE, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = ZONE, 20
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.C_Timer = nil
	if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
	NS:CompanionData().tutoDone = true
	NS:CompanionData().appearance = nil
	local data = NS:CaptureData()
	data.creatures[900] = { name = "Raptor", normal = true, stars = 3, zoneID = ZONE, type = "Bête", at = 1793000000 }
	data.creatures[901] = { name = "Kodo", normal = true, stars = 1, zoneID = ZONE, type = "Bête", at = 1793000100 }
	data.count = 2
	NS:SpecimenMigrate()
	-- en Réserve : un Raptor moins bon (relâchable), un Kodo meilleur que le Codex (pas relâchable)
	C.low = NS:SpecimenAdd({ npc = 900, stars = 1, name = "Raptor", origin = "capture", by = "Dyokrion", zone = ZONE })
	local ref = NS:SpecimenReference(901, false)
	C.better = NS:SpecimenAdd({ npc = 901, stars = 3, name = "Kodo", origin = "capture", by = "Dyokrion", zone = ZONE })
	NS:SpecimenSetReference(ref.id)
end

function C.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = C.saved[name] end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	NS.codexReserveCache, NS.codexZoneCache = nil, nil
	NS:DB().journalState, NS:DB().capture, NS:DB().journalTab = nil, nil, nil
	ResetWorld()
end

-- 4. Réserve : rangée du haut à une hauteur, pastille, deuxième rangée -------------------------------------
for _, style in ipairs({ "sobre", "azeroth" }) do
	Say("-- qc30 composants : Réserve (" .. style .. ")")
	C.Reset(style)
	NS:PaillettesAdd(40, "test")
	local f = NS:OpenReserve()
	local pane, rv = f.res, f.res.reserve
	local H = Theme.CONTROL_HEIGHT
	local chip = pane.views.chips[1]
	Want(style .. " : puces Réserve / Échanges (l'Échoppe n'y est plus)", #pane.views.chips == 2
		and pane.views.byId.reserve and pane.views.byId.trade and not pane.views.byId.shop)
	Want(style .. " : rangée du haut : puces et pastille à la même hauteur ; « Échanger avec ma cible » en sm",
		chip:GetHeight() == H and rv.tradeButton:GetHeight() == H and pane.balance:GetHeight() == H and rv.tradeButton.size == "sm",
		chip:GetHeight() .. "/" .. rv.tradeButton:GetHeight() .. "/" .. pane.balance:GetHeight())
	Verdict("[UI30] " .. style .. " : Réserve : puces Réserve / Échanges, rangée du haut à une seule hauteur")
	-- bêta 6 : « Échanger avec ma cible » en bas à gauche, sans rien chevaucher
	do
		local function R(region) return Snap.Rect(region, { memo = {} }) end
		local function Apart(a, b)
			return a.left + a.width <= b.left or b.left + b.width <= a.left or a.top + a.height <= b.top or b.top + b.height <= a.top
		end
		local button, grid, pager, preview, hint, views = R(rv.tradeButton), R(rv.grid), R(rv.pager), R(rv.preview),
			R(rv.hint), R(pane.views)
		local lowTile = 0
		for _, tile in ipairs(rv.tiles) do local r = R(tile); lowTile = math.max(lowTile, r.top + r.height) end
		Want(style .. " : « Échanger avec ma cible » plus dans la rangée du haut", button.top > views.top + views.height)
		Want(style .. " : en bas à gauche : aligné sur la grille, sous ses vignettes, centré sur la pagination",
			button.left == grid.left and button.top >= lowTile and math.abs((button.top + button.height / 2)
			- (pager.top + pager.height / 2)) <= 1, button.left .. "/" .. grid.left .. " " .. button.top .. "/" .. lowTile)
		Want(style .. " : ne chevauche ni la grille, ni la pagination, ni la fiche, ni l'aide", Apart(button, grid)
			and Apart(button, pager) and Apart(button, preview) and Apart(button, hint))
		Want(style .. " : l'aide à sa droite, avant la pagination, sous la grille", hint.left >= button.left + button.width
			and hint.left + hint.width <= pager.left and hint.left + hint.width <= grid.left + grid.width
			and Apart(hint, grid) and rv.hint:GetText() == NS.L.RES_HINT)
		Want(style .. " : au-dessus du pied du carnet", f.footer == nil or button.top + button.height <= R(f.footer).top)
	end
	Want(style .. " : 2e rangée : listes et puces Tous / Brillants à la même hauteur", rv.sort:GetHeight() == H
		and rv.species:GetHeight() == H and rv.show.chips[1]:GetHeight() == H and rv.show:GetHeight() == H)
	Want(style .. " : pastille de la Réserve : solde", not pane.balance.mockHidden and pane.balance.value:GetText() == "40"
		and pane.balance.flash ~= nil, tostring(pane.balance:IsShown()) .. " " .. tostring(pane.balance.value:GetText()))
	local before = #Mock.frames
	NS:RefreshJournal(); NS:RefreshJournal()
	Want(style .. " : rafraîchi sans créer de cadre", #Mock.frames == before, #Mock.frames .. "/" .. before)
	-- Échanges : la même pastille (celle de la page), toujours visible
	pane.views:Select("trade")
	Want(style .. " : vue Échanges : la pastille reste", f.resView == "trade" and pane.trade:IsShown()
		and not pane.balance.mockHidden and pane.balance.value:GetText() == "40")
	if style == "azeroth" then
		Want("azeroth : pastille sur aplat sombre, encres currency.*", pane.balance.azSurface == "dark"
			and pane.balance.value.azRole == "currency.value" and pane.balance.label.azRole == "currency.label")
		Want("azeroth : intertitre de l'historique canonique", pane.trade.histHead.label ~= nil)
	end
	Want(style .. " : aucune erreur", next(NS.errors or {}) == nil, next(NS.errors or {}))
	Verdict("[UI30] " .. style .. " : Réserve, pastille de solde (même en vue Échanges), rafraîchie sans créer de cadre, sans erreur")
	C.Done()
end

-- 5. L'Échoppe du dresseur : son onglet, sa pastille, le refus expliqué au clic ------------------------------
for _, style in ipairs({ "sobre", "azeroth" }) do
	Say("-- qc30 composants : Échoppe (" .. style .. ")")
	C.Reset(style)
	NS:PaillettesAdd(30, "test")
	local f = NS:ToggleJournal(true) and NS.journalFrame or NS.journalFrame
	Want(style .. " : onglet « Échoppe du dresseur » après la Réserve", f.sections.shop ~= nil
		and f.sections.shop:GetText() == "Échoppe du dresseur" and NS.JOURNAL_SECTIONS[4] == "shop")
	f.sections.shop:GetScript("OnClick")(f.sections.shop)
	local sv = f.shopPane
	Want(style .. " : clic sur l'onglet : la page, titre et sous-titre", f.kind == "shop" and sv:IsShown()
		and not f.res:IsShown() and f.header.title:GetText() == "Échoppe du dresseur" and f.sections.shop.selected ~= false)
	Want(style .. " : pastille de l'Échoppe : même composant, même solde", sv.balance ~= f.res.balance
		and sv.balance:GetHeight() == f.res.balance:GetHeight() and sv.balance.value:GetText() == "30" and sv.balance.Flash ~= nil)
	Verdict("[UI30] " .. style .. " : onglet « Échoppe du dresseur » après la Réserve, sa page, sa pastille (même composant, même solde)")
	local rows = {}
	for _, row in ipairs(sv.rows) do rows[row.item.id] = row end
	-- bêta 6 : un « Acheter » hors de portée est désactivé (état désactivé du
	-- socle), la raison en infobulle ; il suit le solde page ouverte
	local function TipOf(button)
		GameTooltip:ClearLines()
		button:GetScript("OnEnter")(button)
		local lines = GameTooltip.lines or {}
		button:GetScript("OnLeave")(button)
		return lines[1]
	end
	local buy = rows.sifflet.buy
	Want(style .. " : Sifflet (40) pour 30 : désactivé, grisé, « Il te manque 10 paillettes » au survol",
		rows.sifflet.state == "short" and not buy:IsEnabled() and buy.disabledLook and not buy.inactive
		and buy.qcEnabled == false and buy.size == "sm" and TipOf(buy) == "Il te manque 10 paillettes",
		tostring(buy:IsEnabled()) .. " / " .. tostring(TipOf(buy)))
	Want(style .. " : prix au-dessus du solde : tous désactivés (40, 50, 60, 80), à portée : actifs (5, 15)",
		not rows.slots.buy:IsEnabled() and not rows.frame_glitter.buy:IsEnabled() and not rows.bg_starfall.buy:IsEnabled()
		and rows.appat.buy:IsEnabled() and rows.lasso.buy:IsEnabled() and not rows.appat.buy.disabledLook)
	NS:CaptureData().items = NS:CaptureData().items or {}
	NS:CaptureData().items.appat = 99
	NS:RefreshJournal()
	Want(style .. " : besace pleine : désactivé, « Ta besace est pleine »", rows.appat.state == "full"
		and not rows.appat.buy:IsEnabled() and TipOf(rows.appat.buy) == "Ta besace est pleine")
	NS:CaptureData().items.appat = 0
	NS:CaptureData().shopOwned = { shop_starfall = true }
	NS:RefreshJournal()
	Want(style .. " : déjà obtenu : « Acquis », désactivé, « Déjà obtenu »", rows.bg_starfall.state == "owned"
		and not rows.bg_starfall.buy:IsEnabled() and rows.bg_starfall.buy:GetText() == "Acquis"
		and TipOf(rows.bg_starfall.buy) == "Déjà obtenu")
	NS:CaptureData().shopOwned = nil
	Mock:Reset()
	local flashes = sv.balance.flashes or 0
	buy:GetScript("OnClick")(buy)
	Want(style .. " : un clic qui passerait quand même : rien d'acheté, pas de confirmation", NS:Paillettes() == 30
		and f.shopConfirm == nil and buy:IsShown() and (sv.balance.flashes or 0) == flashes + 1)
	-- le solde bouge, page ouverte : les boutons suivent (gain, puis achat)
	NS:PaillettesAdd(20, "test")
	if Mock.RunTimers then Mock:RunTimers() end
	Want(style .. " : +20 paillettes, page ouverte : Sifflet et places (50) actifs, pastille à 50", buy:IsEnabled()
		and rows.slots.buy:IsEnabled() and not rows.frame_glitter.buy:IsEnabled() and sv.balance.value:GetText() == "50",
		tostring(buy:IsEnabled()) .. " / " .. tostring(sv.balance.value:GetText()))
	rows.slots.buy:GetScript("OnClick")(rows.slots.buy)
	rows.slots.yes:GetScript("OnClick")(rows.slots.yes)
	Want(style .. " : après l'achat des places (50) : solde 0, tout désactivé", NS:Paillettes() == 0
		and not buy:IsEnabled() and not rows.lasso.buy:IsEnabled() and TipOf(rows.lasso.buy) == "Il te manque 15 paillettes")
	NS:PaillettesAdd(30, "test")
	if Mock.RunTimers then Mock:RunTimers() end
	rows.lasso.buy:GetScript("OnClick")(rows.lasso.buy)
	Want(style .. " : à portée : la confirmation dans la ligne", f.shopConfirm == "lasso" and rows.lasso.yes:IsShown()
		and not rows.lasso.buy.disabledLook)
	Verdict("[UI30] " .. style .. " : Acheter hors de portée (prix, besace pleine, déjà obtenu) désactivé, raison au survol ; suit le solde (gain, achat) ; à portée : confirmation")
	NS:ReserveCancelConfirm()
	local before = #Mock.frames
	NS:RefreshJournal(); NS:RefreshJournal()
	Want(style .. " : rafraîchi sans créer de cadre", #Mock.frames == before)
	Want(style .. " : OpenReserve(\"shop\") mène à l'onglet", NS:OpenReserve("shop") and f.kind == "shop")
	if style == "azeroth" then
		Want("azeroth : boutons Acheter rouges ; refusé : bois délavé", rows.lasso.buy.azSkin == "red"
			and rows.frame_glitter.buy.azState == "disabled" and Same(rows.frame_glitter.buy.text.textColor, NS.AZEROTH_BUTTONS.offText))
		Want("azeroth : aucun rôle manquant", NS.carnetInkMisses == nil, table.concat(NS.carnetInkMisses or {}, ", "))
	end
	Want(style .. " : aucune erreur", next(NS.errors or {}) == nil, next(NS.errors or {}))
	Verdict("[UI30] " .. style .. " : Échoppe rafraîchie sans créer de cadre, OpenReserve(\"shop\"), Azeroth (boutons rouges, rôles), sans erreur")
	C.Done()
end

-- 6. Visite du carnet : l'étape de l'Échoppe ----------------------------------------------------------------
do
	Say("-- qc30 composants : visite guidée")
	local ids = {}
	for _, step in ipairs(NS.TOUR_DEFS.journal.steps) do ids[#ids + 1] = step.id end
	local list = table.concat(ids, ",")
	Check("[UI30] visite du carnet : l'Échoppe entre la Réserve et les hauts faits, textes de l'étape", Has(list, "reserve,shop,feats")
		and Has(NS.L.TOUR_B_shop, "paillettes") and Has(NS.L.TOUR_B_reserve, "onglet suivant"), list)
end

-- 7. Colonne de navigation : dix entrées (3.0.1 : Addons liés) qui tiennent, dans les deux styles --------------------------------
local navBad = {}
for _, style in ipairs({ "sobre", "azeroth" }) do
	Say("-- qc30 composants : navigation (" .. style .. ")")
	C.Reset(style)
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	local count = 0
	for _ in pairs(f.sections) do count = count + 1 end
	local box = f.navSummary
	local lay = NS.CARNET_LAYOUT
	local navH = style == "azeroth" and (f:GetHeight() - lay.band - lay.wood) or (f:GetHeight() - 2)
	local bottom = -(box.lastPoint and box.lastPoint.y or 0) + box:GetHeight()
	local reserved = style == "azeroth" and 50 + 16 or 18 + 16
	if not (count == 10 and bottom <= navH - reserved) then navBad[#navBad + 1] = style .. " : " .. count .. " / " .. bottom .. " / " .. navH end
	C.Done()
end
Check("[UI30] Sobre et Azeroth : dix onglets (Addons liés en dernier), le tableau de bord tient au-dessus du bas", #navBad == 0, table.concat(navBad, ", "))
end
