-- Fenêtre de réglages du socle (docs/UI.md), dans les deux addons :
-- navigation (groupes, interrupteurs de module, défilement), page parente et
-- onglets déclarés, recherche, défilement des pages, libellés longs (toutes
-- les pages tiennent, en français), aperçus, pied, carte d'action, infobulle
-- déclarée, phrase sous le libellé, liste déroulante longue.
local Check, Say, NS, QNS, Mock = T.Check, T.Say, T.NS, T.QNS, T.Mock
local Theme = NS.Theme
local lay = NS.OPT_LAYOUT

local failed = {}
local function Want(label, ok, extra)
	if not ok then failed[#failed + 1] = extra ~= nil and (label .. " (" .. tostring(extra) .. ")") or label end
	return ok
end
local function Verdict(name) Check("[OPT] " .. name, #failed == 0, table.concat(failed, " | ")); failed = {} end

local function Open(ns, page)
	ns.optionsFrame = nil
	ns:ToggleOptions()
	if page then ns:SelectOptionsPage(page) end
	return ns.optionsFrame
end
local function Row(ns, key)
	for _, row in ipairs(ns.optionsFrame.rows) do if row.def and row.def.key == key then return row end end
end
local function Nav(ns, id)
	for _, nav in ipairs(ns.optionsFrame.navButtons) do if nav.pageId == id then return nav end end
end
-- page de test le temps d'un bloc, retirée ensuite
local function WithPage(def, fn)
	NS.AddOptionPage(def)
	local ok, err = pcall(fn)
	for index, existing in ipairs(NS.OPTION_PAGES) do
		if existing == def then table.remove(NS.OPTION_PAGES, index); break end
	end
	NS.optionsFrame = nil
	if not ok then error(err, 0) end
end

local function Header(ns, id)
	for _, header in ipairs(ns.optionsFrame.navHeaders) do if header.pageId == id then return header end end
end
local function NavOrder(ns)
	local out = {}
	for _, item in ipairs(ns.optionsFrame.navList.items) do
		local r = item.region
		out[#out + 1] = item.kind == "section" and ("[" .. tostring(r.label.text) .. "]") or tostring(r.pageId)
	end
	return table.concat(out, ",")
end

-- 1. Navigation : une entrée par page --------------------------------------------
do
	Say("-- réglages : navigation")
	T.ResetWorld()
	local frame = Open(NS, "general")
	Want("R2Q : groupes et entrées dans l'ordre des pages", NavOrder(NS) == "general,[CHECK AVANT LE DÉPART],trigger,safe,bags,gear,buffs,"
		.. "[MODULES],toast,portrait,camp,expedition,dungeon,[CONFORT DE JEU],merchant,reward,pace,bagspace,lootroom,spellranks,death,aggro",
		NavOrder(NS))
	local qol = Header(NS, "qol")
	Want("page à sous-pages : titre de groupe en capitales ambre", qol and qol.label.text == "CONFORT DE JEU"
		and qol.label.fontObject == Theme.F_CAPS and qol.label.textColor[1] > 0.85)
	Want("sous-page liée à un module : son interrupteur", Nav(NS, "spellranks").powerKey == "spellranksEnabled"
		and Nav(NS, "reward").powerKey == "rewardEnabled" and Nav(NS, "merchant").powerKey == nil and Nav(NS, "spellranks").power:IsShown())
	Nav(NS, "spellranks").power:Click()
	Want("interrupteur d'une sous-page : coupe le module, reste sur la page", NS:DB().spellranksEnabled == false
		and frame.currentPage == "general" and Nav(NS, "spellranks").moduleOn == false and Row(NS, "spellranksEnabled").toggle.checked == false)
	Nav(NS, "spellranks").power:Click()
	Want("titre de groupe d'un module : son interrupteur", Header(NS, "departure").powerKey == "departureEnabled"
		and Header(NS, "departure").power:IsShown() and not qol.power:IsShown())
	Nav(NS, "spellranks"):Click()
	Want("en-tête : le titre de la sous-page choisie", frame.header.title.text == NS.L.OPT_PAGE_SPELLRANKS
		and frame.header.subtitle.text == NS.L.OPT_PAGE_SPELLRANKS_SUB and Nav(NS, "spellranks").selected and not frame.tabs:IsShown())
	local _, _, _, _, bodyY = frame.pages.spellranks:GetPoint()
	Want("sans onglets : le contenu remonte sous l'en-tête", bodyY > lay.tabsTop - Theme.TABS_HEIGHT - lay.previewHeight, bodyY)
	qol:Click()
	Want("clic sur un titre de groupe : sa première page", frame.currentPage == "merchant")
	Verdict("R2Q : navigation dans l'ordre des pages, groupes en capitales, interrupteurs de module, en-tête de la sous-page")
	-- chaque page a exactement une entrée, et chaque réglage s'atteint par elle
	local entries, problems = {}, {}
	for _, item in ipairs(frame.navButtons) do entries[item.pageId] = (entries[item.pageId] or 0) + 1 end
	for id in pairs(frame.pages) do
		if entries[id] ~= 1 then problems[#problems + 1] = id .. "x" .. tostring(entries[id]) end
	end
	for id, count in pairs(entries) do if not frame.pages[id] then problems[#problems + 1] = id .. ":sans page" end end
	local shown = 0
	for _, item in ipairs(frame.navButtons) do
		item:Click()
		for _, row in ipairs(frame.pages[item.pageId].rows) do
			if row:GetParent() == frame.pages[item.pageId] and frame.pages[item.pageId]:IsShown() then shown = shown + 1
			else problems[#problems + 1] = tostring(row.labelText) end
		end
	end
	Check("[OPT] R2Q : chaque page a une seule entrée, chaque réglage s'y affiche", #problems == 0 and shown == #frame.rows,
		table.concat(problems, ", ") .. " " .. shown .. "/" .. #frame.rows)
	frame:Hide()

	local qframe = Open(QNS, "general")
	Want("QC : le Compagnon de route en groupe, une entrée par page", NavOrder(QNS) == "general,[COMPAGNON DE ROUTE],companionMain,"
		.. "companionOrnaments,journal,companionCharacter,companionDaily", NavOrder(QNS))
	Want("QC : l'interrupteur du module sur le titre du groupe", Header(QNS, "companion").powerKey == "companionEnabled")
	local qcount = 0
	for _, item in ipairs(qframe.navButtons) do
		item:Click()
		for _, row in ipairs(qframe.pages[item.pageId].rows) do if row:GetParent() == qframe.pages[item.pageId] then qcount = qcount + 1 end end
	end
	Want("QC : chaque réglage s'affiche par une entrée", qcount == #qframe.rows, qcount .. "/" .. #qframe.rows)
	Nav(QNS, "journal"):Click()
	Want("QC : en-tête de la sous-page", qframe.header.title.text == QNS.L.OPT_PAGE_JOURNAL)
	Verdict("QC : le Compagnon de route en groupe avec son interrupteur, chaque réglage atteint par une entrée")
	qframe:Hide()
end

-- 1 bis. Navigation qui défile ----------------------------------------------------
do
	Say("-- réglages : navigation qui défile")
	T.ResetWorld()
	local frame = Open(NS, "general")
	local list = frame.navList
	Want("R2Q : la navigation dépasse la colonne", list.contentHeight > list.viewHeight, list.contentHeight .. " / " .. list.viewHeight)
	Want("navigation : en haut, la dernière entrée cachée, ascenseur", Nav(NS, "general"):IsShown() and not Nav(NS, "death"):IsShown()
		and list.scrollThumb:IsShown())
	for _ = 1, 30 do list.scripts.OnMouseWheel(list, -1) end
	Want("molette : la navigation descend jusqu'à la dernière entrée", Nav(NS, "death"):IsShown() and not Nav(NS, "general"):IsShown()
		and list.offset > 0)
	local cut = 0
	for _, item in ipairs(list.items) do
		if item.region:IsShown() and (item.y < list.offset or item.y + item.height > list.offset + list.viewHeight + 1) then cut = cut + 1 end
	end
	Want("navigation : aucune entrée coupée", cut == 0, cut)
	NS:SelectOptionsPage("trigger")
	Want("la page choisie remonte dans la navigation, avec son titre", Nav(NS, "trigger"):IsShown() and Header(NS, "departure"):IsShown())
	NS:SelectOptionsPage("death")
	Want("la page choisie descend dans la navigation", Nav(NS, "death"):IsShown())
	for _ = 1, 30 do NS:ScrollOptionsNav(1) end
	Want("molette : bornée en haut", list.offset == 0 and Nav(NS, "general"):IsShown())
	Want("navigation : au-dessus de la version", lay.navTop - lay.navView >= -(lay.height - 2 - 40))
	Verdict("navigation qui défile : molette bornée, rien de coupé, la page choisie ramenée en vue, au-dessus de la version")
	frame:Hide()
end

-- 1 ter. Page parente avec ses réglages, onglets déclarés -----------------------------
do
	Say("-- réglages : vue d'ensemble et onglets déclarés")
	T.ResetWorld()
	local parent = { id = "zzparent", title = "OPT_PAGE_GENERAL", rows = { { key = "optParent", label = "OPT_ENABLED", kind = "bool" } } }
	local child = { id = "zzchild", title = "OPT_PAGE_QOL", parent = "zzparent", rows = { { key = "optChild", label = "OPT_MINIMAP", kind = "bool" } } }
	local tabbed = { id = "zztabs", title = "OPT_PAGE_DEATH", tabs = {
		{ id = "a", label = "OPT_SETTINGS", rows = { { key = "optTabA", label = "OPT_ENABLED", kind = "bool" } } },
		{ id = "b", label = "OPT_MODULES", rows = { { key = "optTabB", label = "OPT_TEST_TAB_B", kind = "bool" } } },
	} }
	NS.L.OPT_TEST_TAB_B = "Réglage du second onglet"
	NS.AddOptionPage(parent); NS.AddOptionPage(child); NS.AddOptionPage(tabbed)
	local ok, err = pcall(function()
		local frame = Open(NS, "general")
		local overview, childNav = Nav(NS, "zzparent"), Nav(NS, "zzchild")
		Want("parent avec réglages : « Vue d'ensemble » en tête de son groupe", Header(NS, "zzparent") ~= nil and overview
			and overview.label.text == NS.L.OPT_NAV_OVERVIEW and childNav ~= nil)
		overview:Click()
		Want("vue d'ensemble : les réglages du parent", frame.currentPage == "zzparent" and Row(NS, "optParent"):IsShown())
		local tabsNav = Nav(NS, "zztabs")
		tabsNav:Click()
		Want("onglets déclarés : barre visible, premier onglet", frame.tabs:IsShown() and frame.tabs.selected == "zztabs:a"
			and frame.currentPage == "zztabs:a" and Row(NS, "optTabA"):IsShown() and tabsNav.selected)
		local _, _, _, _, bodyY = frame.pages["zztabs:a"]:GetPoint()
		Want("onglets déclarés : le contenu sous la barre", bodyY <= lay.tabsTop - Theme.TABS_HEIGHT, bodyY)
		frame.tabs.byId["zztabs:b"]:Click()
		Want("onglets déclarés : clic, l'autre onglet", frame.currentPage == "zztabs:b" and Row(NS, "optTabB"):IsShown()
			and not frame.pages["zztabs:a"]:IsShown() and frame.header.title.text == NS.L.OPT_PAGE_DEATH and tabsNav.selected)
		NS:SelectOptionsPage("general")
		NS:SelectOptionsPage("zztabs")
		Want("onglets déclarés : le dernier onglet retenu", frame.currentPage == "zztabs:b")
		NS:SetOptionsSearch("second onglet")
		Want("recherche dans un onglet : trouvée, l'onglet en détail", frame.searchPage.total == 1
			and frame.searchPage.sections[1].detail.text == "(" .. NS.L.OPT_MODULES .. ")" and tabsNav.badge.text == "1")
		frame:Hide()
	end)
	for _, def in ipairs({ parent, child, tabbed }) do
		for index, existing in ipairs(NS.OPTION_PAGES) do if existing == def then table.remove(NS.OPTION_PAGES, index); break end end
	end
	NS.L.OPT_TEST_TAB_B = nil
	NS.optionsFrame = nil
	if not ok then error(err, 0) end
	-- Theme : marge d'onglet resserrée quand la rangée déborde
	local holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(300, 40)
	local tabs = Theme.CreateTabs(holder, nil)
	tabs:SetWidth(300)
	tabs:SetTabs({ { id = "a", label = "Premier onglet" }, { id = "b", label = "Deuxième onglet" }, { id = "c", label = "Troisième" } })
	Want("onglets trop larges : marge resserrée", tabs.padding < 24 and tabs.padding >= 10, tabs.padding)
	Verdict("page parente (vue d'ensemble), onglets déclarés (barre, contenu dessous, dernier retenu, recherche), marge resserrée")
end

-- 2. Recherche ----------------------------------------------------------------
do
	Say("-- réglages : recherche")
	T.ResetWorld()
	local frame = Open(NS, "general")
	local box = frame.search
	local function Type(text)
		box:SetText(text)
		box.scripts.OnTextChanged(box, true)
	end
	Type("alerte")
	local expected = 0
	for _, row in ipairs(frame.rows) do
		if NS.OptionFold(row.labelText):find("alerte", 1, true) then expected = expected + 1 end
	end
	local results = frame.searchPage
	Want("recherche : toutes les cartes qui correspondent", results.total == expected and expected >= 4, results.total .. "/" .. expected)
	Want("recherche : vue des résultats, pages cachées", frame.searching and results:IsShown() and not frame.pages.general:IsShown()
		and not frame.tabs:IsShown())
	local delay = Row(NS, "exitDelay")
	Want("recherche : la carte est empruntée par les résultats", delay:GetParent() == results and delay:IsShown())
	local sections = 0
	for _, item in ipairs(results.items) do if item.kind == "section" then sections = sections + 1 end end
	Want("recherche : regroupée par page", sections >= 2 and results.items[1].kind == "section", sections)
	local badged = 0
	for _, nav in ipairs(frame.navButtons) do if nav.badge:IsShown() then badged = badged + tonumber(nav.badge.text) end end
	Want("recherche : chaque entrée compte ses résultats", Nav(NS, "trigger").badge.text == "2" and badged == expected
		and Nav(NS, "general").badge:IsShown() ~= true, badged)
	Want("recherche : titre et nombre", frame.header.title.text == NS.L.OPT_SEARCH_TITLE
		and frame.header.subtitle.text:find(tostring(expected), 1, true) ~= nil)
	-- une carte trouvée marche comme sur sa page
	local before = NS:DB().exitDelay
	delay:Step(1)
	Want("recherche : le réglage trouvé se règle", NS:DB().exitDelay == before + 1 and frame.searching)
	Verdict("recherche : toutes les cartes trouvées, empruntées et réglables, regroupées par page, comptées dans la navigation")
	-- sans accents, plusieurs mots
	Type("ECART  alertes")
	Want("recherche : sans accents ni casse, tous les mots", results.total == 1 and results.items[2].region == Row(NS, "alertCooldown"),
		results.total)
	Type("zzzz introuvable")
	Want("recherche : aucun résultat, phrase", results.total == 0 and results.empty.text:find("introuvable", 1, true) ~= nil)
	Verdict("recherche : sans accents ni casse, tous les mots ; aucun résultat : une phrase")
	Type("")
	Want("recherche vidée : page d'avant rendue", not frame.searching and frame.currentPage == "general"
		and frame.pages.general:IsShown() and not results:IsShown())
	Want("recherche vidée : badges retirés", Nav(NS, "trigger").badge:IsShown() ~= true)
	NS:SelectOptionsPage("trigger")
	Want("la carte revient sur sa page", delay:GetParent() == frame.pages.trigger and delay:IsShown())
	-- choisir une page pendant une recherche la referme
	Type("vivres")
	Nav(NS, "camp"):Click()
	Want("clic dans la navigation : recherche refermée", not frame.searching and box:GetText() == "" and frame.currentPage == "camp")
	-- fermer la fenêtre aussi
	Type("vivres")
	frame:Hide()
	frame.scripts.OnHide(frame)   -- le client l'appelle au Hide, pas le harnais
	Want("fermer : recherche refermée", not frame.searching and box:GetText() == "")
	Verdict("recherche vidée, clic dans la navigation ou fenêtre fermée : page rendue, cartes et badges remis")
end

-- 3. Défilement -----------------------------------------------------------------
do
	Say("-- réglages : défilement")
	T.ResetWorld()
	local rows = {}
	for index = 1, 30 do
		rows[#rows + 1] = { key = "optTest" .. index, label = "Réglage d'essai " .. index, kind = "bool" }
		if index % 10 == 0 then rows[#rows + 1] = { header = "OPT_SECTION_DISPLAY" } end
	end
	WithPage({ id = "zzscroll", title = "OPT_PAGE_GENERAL", rows = rows }, function()
		local frame = Open(NS, "zzscroll")
		local page = frame.pages.zzscroll
		Want("défilement : contenu plus haut que la zone", page.contentHeight > page.viewHeight, page.contentHeight .. " / " .. page.viewHeight)
		local function Alt(key) return Row(NS, key).alt == true end
		Want("ROW / ROW_ALT par rangée visuelle", not Alt("optTest1") and not Alt("optTest2") and Alt("optTest3") and Alt("optTest4")
			and not Alt("optTest5") and Row(NS, "optTest3").bg.vertex[1] == Theme.ROW_ALT[1] and Row(NS, "optTest1").bg.vertex[1] == Theme.ROW[1])
		Want("deux colonnes : même rangée, colonnes voisines", Row(NS, "optTest1").lastPoint.x == 0
			and Row(NS, "optTest2").lastPoint.x == lay.colWidth + lay.colGap and Row(NS, "optTest1").lastPoint.y == Row(NS, "optTest2").lastPoint.y)
		Want("une section repart sur ROW", not Alt("optTest11"))
		Verdict("cartes : deux colonnes, ROW / ROW_ALT par rangée visuelle, une section repart sur ROW")
		local function Shown(key) return Row(NS, key):IsShown() end
		Want("défilement : en haut, le premier visible, le dernier non", Shown("optTest1") and not Shown("optTest30"))
		Want("défilement : ascenseur affiché", frame.scrollThumb:IsShown() and frame.scrollTrack:IsShown())
		local thumbTop = select(5, frame.scrollThumb:GetPoint())
		frame.content.scripts.OnMouseWheel(frame.content, -1)
		Want("molette : la page descend", page.offset > 0 and select(5, frame.scrollThumb:GetPoint()) < thumbTop, page.offset)
		for _ = 1, 40 do frame.content.scripts.OnMouseWheel(frame.content, -1) end
		local lastItem = page.items[#page.items]
		Want("molette : bornée en bas, le dernier élément visible", Shown("optTest30") and lastItem.region:IsShown()
			and page.stopIndex == #page.stops and page.offset + page.viewHeight >= lastItem.y + lastItem.height)
		-- rien n'est montré à moitié : tout élément visible tient dans la zone
		local cut = 0
		for _, item in ipairs(page.items) do
			if item.region:IsShown() and (item.y - page.offset < 0 or item.y - page.offset + item.height > page.viewHeight + 1) then cut = cut + 1 end
		end
		Want("défilement : aucun élément coupé", cut == 0, cut)
		local row = Row(NS, "optTest30")
		row:Click()
		Want("défilement : la carte du bas se règle", NS:DB().optTest30 == false)
		for _ = 1, 40 do NS:ScrollOptions(1) end
		Want("molette : bornée en haut", page.offset == 0 and Shown("optTest1"))
		NS:SelectOptionsPage("general")
		Want("page courte : pas d'ascenseur", not frame.scrollThumb:IsShown())
		Verdict("défilement : ascenseur, molette bornée, rien de coupé, la carte du bas se règle, pas d'ascenseur sur page courte")
		frame:Hide()
	end)
end

-- 4. Libellés longs -------------------------------------------------------------
do
	Say("-- réglages : libellés longs")
	T.ResetWorld()
	local long = string.rep("Un libellé vraiment très long ", 8)
	NS.L.OPT_TEST_LONG = long
	WithPage({ id = "zzlong", title = "OPT_PAGE_GENERAL", rows = {
		{ key = "optShort", label = "OPT_ENABLED", kind = "bool" },
		{ key = "optMedium", label = "OPT_LOOTROOM_CONFIRM", kind = "bool" },
		{ key = "optLong", label = "OPT_TEST_LONG", kind = "bool" },
		{ key = "optNumber", label = "OPT_LOOTROOM_CONFIRM", kind = "number", min = 0, max = 10, step = 1 },
	} }, function()
		Open(NS, "zzlong")
		local short, medium, longRow, number = Row(NS, "optShort"), Row(NS, "optMedium"), Row(NS, "optLong"), Row(NS, "optNumber")
		Want("libellé court : demi-carte", short.span == "half" and short.width == lay.colWidth)
		Want("libellé trop long pour une colonne : pleine largeur, sans troncature", medium.span == "full"
			and medium.width == lay.inner and not medium.truncated and medium.labelWidth <= medium.labelRoom)
		Want("curseur au libellé long : pleine largeur", number.span == "full")
		Want("libellé démesuré : tronqué à sa place", longRow.truncated and longRow.label.width == longRow.labelRoom
			and longRow.labelRoom < longRow.labelWidth)
		_G.GameTooltip.lines = {}
		longRow.scripts.OnEnter(longRow)
		Want("libellé tronqué : entier dans l'infobulle", (_G.GameTooltip.lines or {})[1] == long)
		longRow.scripts.OnLeave(longRow)
		-- la demi-carte suivant une pleine largeur repart à gauche, sans chevauchement
		local page = NS.optionsFrame.pages.zzlong
		local spots = {}
		for _, item in ipairs(page.items) do
			if item.kind == "card" then spots[#spots + 1] = item.x .. ":" .. item.y end
		end
		Want("cartes : une place chacune", #spots == 4 and spots[1] ~= spots[2] and spots[2] ~= spots[3], table.concat(spots, " "))
		Verdict("libellés longs : demi-carte, pleine largeur sans troncature, tronqué à sa place (entier en infobulle)")
		NS.optionsFrame:Hide()
	end)
	NS.L.OPT_TEST_LONG = nil
	-- toutes les pages des deux addons, modules chargés, en français
	for _, pair in ipairs({ { "R2Q", NS }, { "QC", QNS } }) do
		local ns = pair[2]
		local frame = Open(ns)
		local problems = {}
		for _, row in ipairs(frame.rows) do
			if row.truncated or row.labelWidth > row.labelRoom then problems[#problems + 1] = tostring(row.labelText) end
			if row.slider then
				for value = row.slider.min, row.slider.max, math.max(1, row.slider.step) do
					row.slider.valueText:SetText(row.slider:FormatValue(value))
					if row.slider.valueText:GetStringWidth() + 8 > row.slider.valueWidth then
						problems[#problems + 1] = row.def.key .. "=" .. row.slider.valueText.text
					end
				end
			end
			if row.dropdown then
				for _, entry in ipairs(row.dropdown.options) do
					row.dropdown.text:SetText(entry.label)
					if row.dropdown.text:GetStringWidth() > row.dropdown.width - 30 then problems[#problems + 1] = entry.label end
				end
			end
		end
		for id, page in pairs(frame.pages) do
			ns:SelectOptionsPage(id)
			if frame.header.subtitle:GetStringWidth() > lay.inner then problems[#problems + 1] = id .. ":sous-titre" end
			if frame.tabs:IsShown() and frame.tabs.used > lay.inner then problems[#problems + 1] = id .. ":onglets" end
		end
		for _, nav in ipairs(frame.navButtons) do
			if nav.label:GetStringWidth() > nav.label.width then problems[#problems + 1] = nav.label.text end
		end
		ns:RefreshOptions()
		Check("[OPT] " .. pair[1] .. " : libellés, valeurs, sous-titres et onglets tiennent (toutes les pages)", #problems == 0, table.concat(problems, ", "))
		frame:Hide()
	end
end

-- 5. Aperçus ---------------------------------------------------------------------
do
	Say("-- réglages : aperçus")
	T.ResetWorld()
	local frame = Open(NS, "trigger")
	local departure = frame.previews.departure
	Want("aperçu du départ : sous les onglets, la note d'exemple", departure and departure:IsShown() and frame.previewStrip:IsShown()
		and departure.score.text == "85" and departure.note.text == NS.L.OPT_PREVIEW_SAMPLE)
	local _, _, _, _, stripY = frame.previewStrip:GetPoint()
	local _, _, _, _, bodyY = frame.pages.trigger:GetPoint()
	Want("aperçu : sous l'en-tête, au-dessus des réglages", stripY <= lay.tabsTop and stripY > lay.tabsTop - Theme.TABS_HEIGHT
		and bodyY <= stripY - lay.previewHeight,
		stripY .. " / " .. bodyY)
	NS.score = 42
	NS:RefreshOptions()
	Want("aperçu du départ : suit la dernière note", departure.score.text == "42" and departure.note.text == NS.L.OPT_PREVIEW_LAST
		and math.abs(departure.bar.ratio - 0.42) < 0.001)
	NS.score = nil
	NS:SelectOptionsPage("gear")
	Want("aperçu : sur tous les onglets de la page", frame.previews.departure:IsShown())
	NS:SelectOptionsPage("general")
	Want("pas d'aperçu sur Général", not frame.previewStrip:IsShown() and not departure:IsShown())
	Verdict("aperçu du départ : sous l'en-tête, note d'exemple puis la dernière, sur tous les onglets de la page, pas sur Général")

	NS:SelectOptionsPage("spellranks")
	local ranks = frame.previews.spellranks
	Want("aperçu des rangs : deux cases, liseré rouge sur la première", ranks and #ranks.slots == 2 and ranks.outline:IsShown()
		and ranks.outline.edges.top.vertex[1] == NS.SPELLRANKS_BORDER_COLOR[1] and ranks.outline.edges.top.vertex[2] < 0.3)
	Want("aperçu des rangs : seul le QoL ailleurs n'en a pas", frame.previews.departure:IsShown() ~= true)
	Row(NS, "spellranksBorder"):Click()
	Want("aperçu des rangs : liseré coupé avec le réglage", NS:DB().spellranksBorder == false and not ranks.outline:IsShown()
		and ranks.hint.text == NS.L.SR_PREVIEW_OFF)
	Row(NS, "spellranksBorder"):Click()
	Want("aperçu des rangs : liseré revenu", ranks.outline:IsShown())
	Verdict("aperçu des rangs : deux cases, liseré rouge qui suit le réglage")
	frame:Hide()

	-- un aperçu en erreur ne casse pas la fenêtre
	WithPage({ id = "zzpreview", title = "OPT_PAGE_GENERAL", preview = function() error("aperçu cassé") end,
		rows = { { key = "optPreview", label = "OPT_ENABLED", kind = "bool" } } }, function()
		local before = #NS.errors
		local broken = Open(NS, "zzpreview")
		Want("aperçu en erreur : page affichée, erreur notée", broken.currentPage == "zzpreview" and broken.pages.zzpreview:IsShown()
			and #NS.errors > before)
		broken:Hide()
	end)
	Verdict("aperçu en erreur : page affichée, erreur notée")

	-- QuestCompanion : le compagnon dans son cadre, sur tous les onglets du module
	T.ResetWorld()
	local qframe = Open(QNS, "companionMain")
	local comp = qframe.previews.companionMain
	Want("aperçu du compagnon : nom, apparence, cadre et fond", comp and comp:IsShown()
		and comp.name.text == QNS:CompanionName() and comp.line.text:find(QNS.L[QNS:CompanionCurrentAppearance().label], 1, true)
		and comp.style.text:find(QNS.L.COMP_FRAME_SLATE, 1, true) ~= nil, comp and comp.style.text)
	QNS:SelectOptionsPage("companionOrnaments")
	Want("aperçu du compagnon : sur sa page seulement", not comp:IsShown() and not qframe.previewStrip:IsShown())
	QNS:SelectOptionsPage("general")
	Want("aperçu du compagnon : pas sur Général", not comp:IsShown())
	Verdict("QC : aperçu du compagnon (nom, apparence, cadre) sur sa page seulement")
	qframe:Hide()
end

-- 6. Pied, carte d'action, infobulle, liste déroulante ---------------------------------
do
	Say("-- réglages : pied et contrôles")
	T.ResetWorld()
	local frame = Open(NS, "trigger")
	NS:DB().exitDelay = 12
	frame.resetButton:Click()
	Want("Réinitialiser : réglages par défaut", NS:DB().exitDelay ~= 12 and Row(NS, "exitDelay").value.text:find(tostring(NS:DB().exitDelay), 1, true))
	NS.lastResults = nil
	frame.runButton:Click()
	Want("action principale : le check est lancé", NS.lastResults ~= nil and frame.runButton:GetText() == NS.L.OPT_RUNCHECK)
	frame:Hide()
	frame = Open(NS, "general")
	local pos = Row(NS, "minimapPos")
	local angle = NS:DB().minimapAngle or 225
	pos.button:Click()
	Want("carte d'action : le bouton lance l'action", (NS:DB().minimapAngle or 225) ~= angle and pos.button:GetText() == NS.L.OPT_BTN_CHANGE)
	Want("carte d'action : la valeur à gauche du bouton", pos.value:IsShown() and pos.value.text:find("°", 1, true) ~= nil
		and pos.value.lastPoint.relTo == pos.button)
	Verdict("pied (Réinitialiser, action principale) et carte d'action (bouton, valeur à sa gauche)")
	frame:Hide()

	local qframe = Open(QNS, "companionMain")
	local chatter = Row(QNS, "companionChatter")
	_G.GameTooltip.lines = {}
	chatter.scripts.OnEnter(chatter)
	Want("infobulle déclarée (def.tooltip) au survol de la carte", #(_G.GameTooltip.lines or {}) >= 5 and chatter.hover:IsShown())
	chatter.scripts.OnLeave(chatter)
	Want("phrase sous le libellé : carte plus haute, pleine largeur", chatter.note and chatter.note.text ~= ""
		and chatter.height >= lay.noteCardHeight and chatter.span == "full")
	local source = Row(QNS, "companionTraitSource")
	Want("phrase longue : la carte grandit, la phrase passe à la ligne", source.height > lay.noteCardHeight
		and source.note:GetStringWidth() > source.labelRoom,
		source.height)
	local short = Row(QNS, "companionSize")
	Want("phrase courte : une ligne", short.height == lay.noteCardHeight)
	local app = Row(QNS, "companionAppearance")
	app:Click()
	Want("clic sur une carte à liste : la liste s'ouvre", app.dropdown:IsOpen())
	app:Click()
	Want("second clic : refermée", not app.dropdown:IsOpen())
	Verdict("QC : infobulle déclarée au survol, phrase sous le libellé (la carte grandit), carte à liste ouverte au clic")
	qframe:Hide()

	-- Theme : liste déroulante longue, dix lignes et la molette
	local holder = CreateFrame("Frame", nil, UIParent)
	local options = {}
	for index = 1, 25 do options[index] = { value = index, label = "Choix " .. index } end
	local dd = Theme.CreateDropdown(holder, 160, nil, { listWidth = 240 })
	dd:SetOptions(options)
	dd:SetValue(20)
	dd:Open()
	Want("liste longue : dix lignes, le choix courant en vue", #dd.list.rows == 10 and dd.list.height == 10 * Theme.DROPDOWN_ROW + 2
		and dd.offset > 0 and dd.offset < 20 and dd.offset + 10 >= 20 and dd.list.thumb:IsShown(), dd.offset)
	Want("liste plus large que la case", dd.list.width == 240)
	for _ = 1, 30 do dd:Scroll(-1) end
	Want("molette : bornée en bas", dd.offset == 15 and dd.list.rows[10].entry.value == 25)
	dd.list.rows[10]:Click()
	Want("choix dans la partie défilée", dd.value == 25 and not dd:IsOpen())
	Verdict("liste longue : dix lignes, le choix courant en vue, plus large que la case, molette bornée, choix défilé")
	dd:Open()
	dd.list.rows[1].scripts.OnMouseWheel(dd.list.rows[1], 1)
	Want("molette sur une ligne : la liste remonte", dd.offset == 14, dd.offset)
	Want("liste ouverte vers le bas par défaut", not dd.openedUp and dd.list.lastPoint.point == "TOPRIGHT")
	dd:Close()
	dd.GetBottom = function() return 100 end   -- près du bas de l'écran : pas la place
	dd:Open()
	Want("près du bas de l'écran : liste ouverte vers le haut", dd.openedUp and dd.list.lastPoint.point == "BOTTOMRIGHT"
		and dd.list.lastPoint.relPoint == "TOPRIGHT")
	Verdict("liste : molette sur une ligne, ouverte vers le bas, vers le haut près du bas de l'écran")
end
