-- tests/modules/companion_v2.lua -- refonte 2026-11, lot 4 : les briques du
-- carnet et du compagnon (puces, tuiles, étiquettes, pagination, bulle,
-- hauteur de texte, onglets estompés, verrou coupé) et chaque fenêtre ou
-- cadre de QuestCompanion construit sans chevauchement (géométrie absolue de
-- tests/snapshot.lua, scènes de l'aperçu hors-jeu).
local Check, Say, NS, QNS, Mock = T.Check, T.Say, T.NS, T.QNS, T.Mock
local Theme = QNS.Theme
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()

local function Near(a, b) return math.abs((a or 0) - (b or 0)) < 0.01 end
local function SameColor(c, token) return c and Near(c[1], token[1]) and Near(c[2], token[2]) and Near(c[3], token[3]) end

-- 1. Briques ------------------------------------------------------------------
do
	Say("-- carnet et compagnon v2 : briques")
	local picked = {}
	local chips = Theme.CreateChips(UIParent, { { id = "a", label = "Toutes" }, { id = "b", label = "Kalimdor" } },
		function(id) picked[#picked + 1] = id end)
	Check("[CV2] puces : une par choix, la première choisie, libellé tenu", chips.byId.a and chips.byId.b
		and chips.selected == "a" and chips.byId.a.selected and not chips.byId.b.selected
		and chips.byId.b:GetWidth() >= chips.byId.b.text:GetStringWidth() + 16 and chips.used > 0)
	Check("[CV2] puce choisie : filet et texte ambre", SameColor(chips.byId.a.border.top.vertex, Theme.GOLD)
		and SameColor(chips.byId.a.text.textColor, Theme.GOLD) and SameColor(chips.byId.b.border.top.vertex, Theme.EDGE_SOFT))
	chips:Select("b", true)
	Check("[CV2] puces : choix depuis le code, sans rappel", chips.selected == "b" and #picked == 0)
	chips.byId.a:Click()
	Check("[CV2] puces : clic, rappel", chips.selected == "a" and picked[1] == "a")
	Check("[CV2] puces : rangées sans chevauchement", select(4, chips.byId.b:GetPoint()) >= chips.byId.a:GetWidth())

	local tile = Theme.CreateTile(UIParent, 120, 40)
	local entered = 0
	tile.onEnter = function() entered = entered + 1 end
	Check("[CV2] tuile : fond ROW, filet EDGE_SOFT, sans liseré", SameColor(tile.bg.vertex, Theme.ROW)
		and SameColor(tile.border.top.vertex, Theme.EDGE_SOFT) and not tile.accent:IsShown())
	tile.scripts.OnEnter(tile)
	Check("[CV2] tuile survolée : filet EDGE, rappel du module", SameColor(tile.border.top.vertex, Theme.EDGE) and entered == 1)
	tile.scripts.OnLeave(tile)
	tile:SetSelected(true)
	tile:SetAccent(Theme.BLUE)
	Check("[CV2] tuile choisie : filet ambre, liseré de couleur", SameColor(tile.border.top.vertex, Theme.GOLD)
		and tile.accent:IsShown() and SameColor(tile.accent.vertex, Theme.BLUE) and tile.accent.width == Theme.TILE_ACCENT)
	tile:SetAccent(nil)
	Check("[CV2] tuile : liseré retiré", not tile.accent:IsShown())
	local top = Theme.CreateTile(UIParent, 80, 80, { accent = "top" })
	Check("[CV2] tuile : liseré en haut", top.accent.height == Theme.TILE_ACCENT)

	local tag = Theme.CreateTag(UIParent, "rare élite", Theme.BLUE)
	Check("[CV2] étiquette : capitales, couleur, fond teinté, texte tenu", tag.label.text == "RARE ÉLITE"
		and SameColor(tag.label.textColor, Theme.BLUE) and Near(tag.bg.vertex[4], 0.16)
		and tag:GetWidth() >= tag.label:GetStringWidth() + 8 and tag:IsShown())
	tag:SetTag("")
	Check("[CV2] étiquette vide : cachée", not tag:IsShown())

	local steps = {}
	local pager = Theme.CreatePager(UIParent, function(delta) steps[#steps + 1] = delta end)
	pager:Update(0, 12, 40, 28)
	Check("[CV2] pagination : position, chevron bas seul", pager.position.text == "1-12 / 40"
		and not pager.up:IsShown() and pager.down:IsShown())
	pager:Update(28, 12, 40, 28)
	Check("[CV2] pagination : en bas, chevron haut seul", pager.position.text == "29-40 / 40"
		and pager.up:IsShown() and not pager.down:IsShown())
	pager:Update(0, 12, 5, 0)
	Check("[CV2] pagination : une page, rien", pager.position.text == "" and not pager.up:IsShown() and not pager.down:IsShown())
	pager.down:Click(); pager.up:Click()
	Check("[CV2] pagination : bas = -1, haut = 1 (comme la molette)", steps[1] == -1 and steps[2] == 1)
	Check("[CV2] pagination : chevron du haut retourné", pager.up.icon.texCoord and pager.up.icon.texCoord[3] == 1
		and pager.up.icon.texCoord[4] == 0)

	local short = Theme.CreateBubble(UIParent, 200)
	short:SetText("Salut !")
	local bubble = Theme.CreateBubble(UIParent, 200)
	local text = string.rep("Une phrase assez longue pour passer à la ligne. ", 4)
	local height = bubble:SetText(text)
	Check("[CV2] bulle : fond WINDOW, filet EDGE, filet ambre en haut, pointe", bubble.chrome == "bubble"
		and SameColor(bubble.bg.vertex, Theme.WINDOW) and SameColor(bubble.border.top.vertex, Theme.EDGE)
		and SameColor(bubble.rule.vertex, Theme.GOLD) and bubble.tail ~= nil and bubble.tailEdge ~= nil)
	Check("[CV2] bulle : la hauteur suit le texte", height > short:GetHeight()
		and height >= Theme.TextHeight(bubble.text, 200 - 2 * Theme.BUBBLE_PAD, Theme.F_BODY) + 2 * Theme.BUBBLE_PAD, height)
	Check("[CV2] bulle : place en plus pour des boutons", bubble:SetText(text, 30) == height + 30)
	Check("[CV2] bulle : jamais plus petite que le minimum", short:SetText("") == Theme.BUBBLE_MIN)

	local fs = UIParent:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	fs:SetText("court")
	local one = Theme.TextHeight(fs, 300, Theme.F_BODY)
	fs:SetText(string.rep("mot ", 60))
	Check("[CV2] hauteur de texte : une ligne, puis plusieurs", one > 0 and Theme.TextHeight(fs, 300, Theme.F_BODY) > 2 * one)
	fs:SetText("")
	Check("[CV2] hauteur de texte : vide = 0", Theme.TextHeight(fs, 300) == 0)

	local bar = Theme.CreateTabs(UIParent, nil)
	bar:SetWidth(400)
	bar:SetTabs({ { id = "x", label = "Exploration" }, { id = "q", label = "Quêtes" } })
	bar:SetDim("q", true)
	Check("[CV2] onglets : .text et .selected, onglet estompé en MUTED", bar.byId.x.text == bar.byId.x.label
		and bar.byId.x.selected and not bar.byId.q.selected and SameColor(bar.byId.q.text.textColor, Theme.MUTED))
	bar:Select("q", true)
	Check("[CV2] onglet estompé choisi : clair quand même", SameColor(bar.byId.q.text.textColor, Theme.PARCHMENT))

	local lock = Theme.CreateLockTag(UIParent, "")
	lock:SetText("10 jours aux trois missions", 80)
	Check("[CV2] verrou trop long : coupé à la largeur donnée", lock:GetWidth() == 80 and lock.clipped
		and lock.label:GetWidth() < 80)
	lock:SetText("Palier 2", 80)
	Check("[CV2] verrou court : à sa taille", lock:GetWidth() < 80 and not lock.clipped)

	local item = Theme.CreateNavItem(UIParent, 200)
	item:SetText("Jour")
	item:SetBadge("2")
	Check("[CV2] entrée de navigation : .text et pastille", item.text.text == "Jour" and item.badge:IsShown())
end

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
	Say("-- carnet et compagnon v2 : chaque fenêtre, sans chevauchement")
	local journal = {
		-- carnet 1.5.0 : Zones, Zone (et son onglet Combat) et Collection sont
		-- remplacées par la Complétion (et la Ménagerie / le Compagnon)
		{ "qc-journal-creature", "evolution" }, { "qc-journal-progress", "progress" }, { "qc-journal-day", "day" },
		{ "qc-journal-menagerie", "menagerie" },
	}
	for _, spec in ipairs(journal) do
		local name, kind = spec[1], spec[2]
		local frame, restore = Scene(name)
		if not frame then
			Check("[CV2] " .. name .. " : construite", false, restore)
		else
			local overlaps, outside, count = Snap.Layout(frame)
			Check("[CV2] " .. name .. " : la bonne page, du texte à lire", frame.kind == kind and count >= 10, count)
			Check("[CV2] " .. name .. " : aucun chevauchement", #overlaps == 0, table.concat(overlaps, " | "))
			Check("[CV2] " .. name .. " : rien ne sort de la fenêtre", #outside == 0, table.concat(outside, " | "))
			Check("[CV2] " .. name .. " : fenêtre v2 980 × 680, navigation et pied", frame.chrome == "journal"
				and frame.width == 980 and frame.height == 680 and frame.nav and frame.footer and frame.header)
			-- pied : le garde-manger à gauche s'arrête avant « Fermer »
			local close = Rect(frame.closeButton)
			local lastPantry = 0
			for _, button in pairs(frame.pantry or {}) do
				local r = Rect(button)
				lastPantry = math.max(lastPantry, r.left + r.width)
			end
			Check("[CV2] " .. name .. " : pied tenu (garde-manger, Fermer)", close and lastPantry > 0
				and lastPantry < close.left - 12 and frame.closeButton:GetWidth() >= frame.closeButton.text:GetStringWidth() + 16,
				tostring(lastPantry) .. " / " .. tostring(close and close.left))
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
						Check("[CV2] Créatures : « " .. row.label.text .. " » s'arrête avant son type", clear,
							tostring(label.left + label.width) .. " / " .. tostring(detail.left + detail.width - glyphs))
						if clear then ignore[Snap.Label(row.label) .. " / " .. Snap.Label(row.detail)] = true end
					end
				end
			end
			for _, list in ipairs(lists) do
				local b, n = CardsClean(list, ignore)
				cards = cards + n
				for _, o in ipairs(b) do bad[#bad + 1] = o end
			end
			Check("[CV2] " .. name .. " : chaque carte tient ses textes", cards > 0 and #bad == 0,
				cards .. " : " .. table.concat(bad, " | "))
			for _, list in ipairs(lists) do
				if list and list[1] and pane.pager then
					local ok, lowest, limit = AbovePager(list, Snap.Visible(pane.pager) and pane.pager or nil, frame.footer)
					if lowest > 0 then
						Check("[CV2] " .. name .. " : dernière rangée au-dessus de la pagination", ok,
							tostring(lowest) .. " / " .. tostring(limit))
					end
				end
			end
			restore()
		end
	end

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
		Check("[CV2] Créatures : cases à gauche de l'aperçu", right > 0 and right <= preview.left - 8,
			tostring(right) .. " / " .. tostring(preview.left))
		restore()
	end
	-- Complétion (ex-page Zone, Exploration) : la liste des villages, sans aperçu ;
	-- le suivi à l'écran est dans la carte de la zone, à droite du nom
	frame, restore = Scene("qc-journal-progress")
	if frame then
		local prog = frame.prog
		Check("[CV2] Complétion : Les Tarides, villages listés", frame.zoneID == 1413 and frame.progPart == nil
			and prog.items[1]:IsShown() and prog.head.text:find("Villages", 1, true) ~= nil, prog.head.text)
		local card, watch, name = Rect(prog.card), Rect(prog.watchLabel), Rect(prog.name)
		Check("[CV2] suivre à l'écran : dans la carte, à droite du nom", watch.top >= card.top
			and watch.left + watch.width <= card.left + card.width and watch.left > name.left + prog.name:GetWidth(),
			tostring(watch.left) .. " / " .. tostring(name.left + prog.name:GetWidth()))
		restore()
	end

	-- fenêtre de module : le coffre
	for _, name in ipairs({ "qc-chest" }) do
		local dialog, done = Scene(name)
		if not dialog then
			Check("[CV2] " .. name .. " : construite", false, done)
		else
			local overlaps, outside, count = Snap.Layout(dialog)
			Check("[CV2] " .. name .. " : fenêtre de module titrée", dialog.chrome == "dialog" and dialog.title.text ~= ""
				and dialog.footer ~= nil and count >= 3, count)
			Check("[CV2] " .. name .. " : aucun chevauchement", #overlaps == 0, table.concat(overlaps, " | "))
			Check("[CV2] " .. name .. " : rien ne sort", #outside == 0, table.concat(outside, " | "))
			local bad = {}
			for _, side in pairs(dialog.footerButtons) do
				for _, button in ipairs(side) do
					if button:GetWidth() < button.text:GetStringWidth() + 16 then bad[#bad + 1] = button:GetText() end
				end
			end
			Check("[CV2] " .. name .. " : libellés du pied tenus", #bad == 0, table.concat(bad, ","))
			done()
		end
	end
	local chest, done = Scene("qc-chest")
	if chest then
		local last = 0
		for _, option in ipairs(chest.options) do if option:IsShown() then last = math.max(last, Bottom(option)) end end
		local foot = Rect(chest.footer)
		local bad = CardsClean(chest.options)
		Check("[CV2] coffre : la hauteur suit les objets (dernière tuile au-dessus du pied)", last > 0 and last <= foot.top - 8
			and last >= foot.top - 30, tostring(last) .. " / " .. tostring(foot.top))
		Check("[CV2] coffre : chaque tuile tient sa sorte et son nom", #bad == 0, table.concat(bad, " | "))
		done()
	end

	-- cadres à l'écran : bulle, tutoriel, fiche au survol, garde-manger, bandeau, suivi
	local function Clean(root, label)
		local overlaps, outside, count = Snap.Layout(root)
		Check("[CV2] " .. label .. " : aucun chevauchement, rien ne sort", #overlaps == 0 and #outside == 0 and count >= 1,
			table.concat(overlaps, " | ") .. " / " .. table.concat(outside, " | "))
	end
	local _, back = Scene("qc-companion")
	if back then
		local bubble = QNS.companionBubble
		Check("[CV2] bulle : brique du thème, au-dessus du cadre", bubble and bubble.chrome == "bubble" and bubble:IsShown()
			and Bottom(bubble) <= Rect(QNS.companionFrame).top)
		Clean(bubble, "bulle")
		Check("[CV2] cadre du compagnon : le nom et l'humeur en plaque, sous le modèle", QNS.companionFrame.name.text == "Brindille"
			and QNS.companionFrame.mood.text ~= "" and not QNS.companionFrame.mood.text:find("|c", 1, true))
		back()
	end
	_, back = Scene("qc-tutorial")
	if back then
		local bubble = QNS.companionBubble
		Check("[CV2] tutoriel : Passer au trait, Suivant plein", bubble.nextButton:IsShown() and bubble.skipButton:IsShown()
			and bubble.nextButton.style == "primary" and bubble.skipButton.style == "outline")
		local text, nextB = Rect(bubble.text), Rect(bubble.nextButton)
		Check("[CV2] tutoriel : boutons sous le texte, dans la bulle", nextB.top >= text.top + bubble.textHeight - 1
			and Bottom(bubble.nextButton) <= Bottom(bubble), tostring(nextB.top) .. " / " .. tostring(text.top + bubble.textHeight))
		Clean(bubble, "tutoriel")
		back()
	end
	_, back = Scene("qc-companion-hover")
	if back then
		local hover = QNS.companionHover
		Check("[CV2] fiche au survol : bandeau du thème, valeurs des envies", hover.chrome == "toast"
			and hover.bars.mood.value.text == "91 %")
		Clean(hover, "fiche au survol")
		Check("[CV2] fiche au survol : l'aide finit dans le cadre", Bottom(hover.hint) <= Bottom(hover),
			tostring(Bottom(hover.hint)) .. " / " .. tostring(Bottom(hover)))
		back()
	end
	_, back = Scene("qc-pantry")
	if back then
		local menu = QNS.treatMenu
		Check("[CV2] garde-manger : bandeau du thème, une case par friandise", menu.chrome == "toast" and menu.buttons.festin)
		Clean(menu, "garde-manger")
		back()
	end
	local toast
	toast, back = Scene("qc-notify")
	if toast then
		Check("[CV2] bandeau du carnet : brique du thème, liseré ambre", toast.chrome == "toast"
			and SameColor(toast.accent.vertex, Theme.GOLD) and toast.text.text == "Camp Taurajo")
		Clean(toast, "bandeau du carnet")
		back()
	end
	local tracker
	tracker, back = Scene("qc-tracker")
	if tracker then
		local bad = CardsClean(tracker.lines)
		Check("[CV2] suivi à l'écran : chaque ligne tient ses textes", #bad == 0, table.concat(bad, " | "))
		back()
	end
end
