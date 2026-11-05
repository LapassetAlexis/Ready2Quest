-- tests/modules/options_v2.lua -- fenêtre de réglages refondue (docs/UI.md) :
-- onglets, recherche, défilement, aperçus, libellés qui tiennent, pied
local Check, Say, NS, QNS, Mock = T.Check, T.Say, T.NS, T.QNS, T.Mock
local Theme = NS.Theme
local lay = NS.OPT_LAYOUT

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
	Say("-- réglages v2 : navigation")
	T.ResetWorld()
	local frame = Open(NS, "general")
	Check("[OPT2] R2Q : groupes et entrées dans l'ordre des pages", NavOrder(NS) == "general,[CHECK AVANT LE DÉPART],trigger,safe,bags,gear,buffs,"
		.. "[MODULES],toast,portrait,camp,expedition,dungeon,[CONFORT DE JEU],merchant,reward,pace,bagspace,lootroom,spellranks,death",
		NavOrder(NS))
	local qol = Header(NS, "qol")
	Check("[OPT2] page à sous-pages : titre de groupe en capitales ambre", qol and qol.label.text == "CONFORT DE JEU"
		and qol.label.fontObject == Theme.F_CAPS and qol.label.textColor[1] > 0.85)
	Check("[OPT2] sous-page liée à un module : son interrupteur", Nav(NS, "spellranks").powerKey == "spellranksEnabled"
		and Nav(NS, "reward").powerKey == "rewardEnabled" and Nav(NS, "merchant").powerKey == nil and Nav(NS, "spellranks").power:IsShown())
	Nav(NS, "spellranks").power:Click()
	Check("[OPT2] interrupteur d'une sous-page : coupe le module, reste sur la page", NS:DB().spellranksEnabled == false
		and frame.currentPage == "general" and Nav(NS, "spellranks").moduleOn == false and Row(NS, "spellranksEnabled").toggle.checked == false)
	Nav(NS, "spellranks").power:Click()
	Check("[OPT2] titre de groupe d'un module : son interrupteur", Header(NS, "departure").powerKey == "departureEnabled"
		and Header(NS, "departure").power:IsShown() and not qol.power:IsShown())
	Nav(NS, "spellranks"):Click()
	Check("[OPT2] en-tête : le titre de la sous-page choisie", frame.header.title.text == NS.L.OPT_PAGE_SPELLRANKS
		and frame.header.subtitle.text == NS.L.OPT_PAGE_SPELLRANKS_SUB and Nav(NS, "spellranks").selected and not frame.tabs:IsShown())
	local _, _, _, _, bodyY = frame.pages.spellranks:GetPoint()
	Check("[OPT2] sans onglets : le contenu remonte sous l'en-tête", bodyY > lay.tabsTop - Theme.TABS_HEIGHT - lay.previewHeight, bodyY)
	qol:Click()
	Check("[OPT2] clic sur un titre de groupe : sa première page", frame.currentPage == "merchant")
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
	Check("[OPT2] R2Q : chaque page a une seule entrée, chaque réglage s'y affiche", #problems == 0 and shown == #frame.rows,
		table.concat(problems, ", ") .. " " .. shown .. "/" .. #frame.rows)
	frame:Hide()

	local qframe = Open(QNS, "general")
	Check("[OPT2] QC : le Compagnon de route en groupe, une entrée par page", NavOrder(QNS) == "general,[COMPAGNON DE ROUTE],companionMain,"
		.. "companionOrnaments,journal,companionMemories,companionCharacter,companionDaily", NavOrder(QNS))
	Check("[OPT2] QC : l'interrupteur du module sur le titre du groupe", Header(QNS, "companion").powerKey == "companionEnabled")
	local qcount = 0
	for _, item in ipairs(qframe.navButtons) do
		item:Click()
		for _, row in ipairs(qframe.pages[item.pageId].rows) do if row:GetParent() == qframe.pages[item.pageId] then qcount = qcount + 1 end end
	end
	Check("[OPT2] QC : chaque réglage s'affiche par une entrée", qcount == #qframe.rows, qcount .. "/" .. #qframe.rows)
	Nav(QNS, "journal"):Click()
	Check("[OPT2] QC : en-tête de la sous-page", qframe.header.title.text == QNS.L.OPT_PAGE_JOURNAL)
	qframe:Hide()
end

-- 1 bis. Navigation qui défile ----------------------------------------------------
do
	Say("-- réglages v2 : navigation qui défile")
	T.ResetWorld()
	local frame = Open(NS, "general")
	local list = frame.navList
	Check("[OPT2] R2Q : la navigation dépasse la colonne", list.contentHeight > list.viewHeight, list.contentHeight .. " / " .. list.viewHeight)
	Check("[OPT2] navigation : en haut, la dernière entrée cachée, ascenseur", Nav(NS, "general"):IsShown() and not Nav(NS, "death"):IsShown()
		and list.scrollThumb:IsShown())
	for _ = 1, 30 do list.scripts.OnMouseWheel(list, -1) end
	Check("[OPT2] molette : la navigation descend jusqu'à la dernière entrée", Nav(NS, "death"):IsShown() and not Nav(NS, "general"):IsShown()
		and list.offset > 0)
	local cut = 0
	for _, item in ipairs(list.items) do
		if item.region:IsShown() and (item.y < list.offset or item.y + item.height > list.offset + list.viewHeight + 1) then cut = cut + 1 end
	end
	Check("[OPT2] navigation : aucune entrée coupée", cut == 0, cut)
	NS:SelectOptionsPage("trigger")
	Check("[OPT2] la page choisie remonte dans la navigation, avec son titre", Nav(NS, "trigger"):IsShown() and Header(NS, "departure"):IsShown())
	NS:SelectOptionsPage("death")
	Check("[OPT2] la page choisie descend dans la navigation", Nav(NS, "death"):IsShown())
	for _ = 1, 30 do NS:ScrollOptionsNav(1) end
	Check("[OPT2] molette : bornée en haut", list.offset == 0 and Nav(NS, "general"):IsShown())
	Check("[OPT2] navigation : au-dessus de la version", lay.navTop - lay.navView >= -(lay.height - 2 - 40))
	frame:Hide()
end

-- 1 ter. Page parente avec ses réglages, onglets déclarés -----------------------------
do
	Say("-- réglages v2 : vue d'ensemble et onglets déclarés")
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
		Check("[OPT2] parent avec réglages : « Vue d'ensemble » en tête de son groupe", Header(NS, "zzparent") ~= nil and overview
			and overview.label.text == NS.L.OPT_NAV_OVERVIEW and childNav ~= nil)
		overview:Click()
		Check("[OPT2] vue d'ensemble : les réglages du parent", frame.currentPage == "zzparent" and Row(NS, "optParent"):IsShown())
		local tabsNav = Nav(NS, "zztabs")
		tabsNav:Click()
		Check("[OPT2] onglets déclarés : barre visible, premier onglet", frame.tabs:IsShown() and frame.tabs.selected == "zztabs:a"
			and frame.currentPage == "zztabs:a" and Row(NS, "optTabA"):IsShown() and tabsNav.selected)
		local _, _, _, _, bodyY = frame.pages["zztabs:a"]:GetPoint()
		Check("[OPT2] onglets déclarés : le contenu sous la barre", bodyY <= lay.tabsTop - Theme.TABS_HEIGHT, bodyY)
		frame.tabs.byId["zztabs:b"]:Click()
		Check("[OPT2] onglets déclarés : clic, l'autre onglet", frame.currentPage == "zztabs:b" and Row(NS, "optTabB"):IsShown()
			and not frame.pages["zztabs:a"]:IsShown() and frame.header.title.text == NS.L.OPT_PAGE_DEATH and tabsNav.selected)
		NS:SelectOptionsPage("general")
		NS:SelectOptionsPage("zztabs")
		Check("[OPT2] onglets déclarés : le dernier onglet retenu", frame.currentPage == "zztabs:b")
		NS:SetOptionsSearch("second onglet")
		Check("[OPT2] recherche dans un onglet : trouvée, l'onglet en détail", frame.searchPage.total == 1
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
	Check("[OPT2] onglets trop larges : marge resserrée", tabs.padding < 24 and tabs.padding >= 10, tabs.padding)
end

-- 2. Recherche ----------------------------------------------------------------
do
	Say("-- réglages v2 : recherche")
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
	Check("[OPT2] recherche : toutes les cartes qui correspondent", results.total == expected and expected >= 4, results.total .. "/" .. expected)
	Check("[OPT2] recherche : vue des résultats, pages cachées", frame.searching and results:IsShown() and not frame.pages.general:IsShown()
		and not frame.tabs:IsShown())
	local delay = Row(NS, "exitDelay")
	Check("[OPT2] recherche : la carte est empruntée par les résultats", delay:GetParent() == results and delay:IsShown())
	local sections = 0
	for _, item in ipairs(results.items) do if item.kind == "section" then sections = sections + 1 end end
	Check("[OPT2] recherche : regroupée par page", sections >= 2 and results.items[1].kind == "section", sections)
	local badged = 0
	for _, nav in ipairs(frame.navButtons) do if nav.badge:IsShown() then badged = badged + tonumber(nav.badge.text) end end
	Check("[OPT2] recherche : chaque entrée compte ses résultats", Nav(NS, "trigger").badge.text == "2" and badged == expected
		and Nav(NS, "general").badge:IsShown() ~= true, badged)
	Check("[OPT2] recherche : titre et nombre", frame.header.title.text == NS.L.OPT_SEARCH_TITLE
		and frame.header.subtitle.text:find(tostring(expected), 1, true) ~= nil)
	-- une carte trouvée marche comme sur sa page
	local before = NS:DB().exitDelay
	delay:Step(1)
	Check("[OPT2] recherche : le réglage trouvé se règle", NS:DB().exitDelay == before + 1 and frame.searching)
	-- sans accents, plusieurs mots
	Type("ECART  alertes")
	Check("[OPT2] recherche : sans accents ni casse, tous les mots", results.total == 1 and results.items[2].region == Row(NS, "alertCooldown"),
		results.total)
	Type("zzzz introuvable")
	Check("[OPT2] recherche : aucun résultat, phrase", results.total == 0 and results.empty.text:find("introuvable", 1, true) ~= nil)
	Type("")
	Check("[OPT2] recherche vidée : page d'avant rendue", not frame.searching and frame.currentPage == "general"
		and frame.pages.general:IsShown() and not results:IsShown())
	Check("[OPT2] recherche vidée : badges retirés", Nav(NS, "trigger").badge:IsShown() ~= true)
	NS:SelectOptionsPage("trigger")
	Check("[OPT2] la carte revient sur sa page", delay:GetParent() == frame.pages.trigger and delay:IsShown())
	-- choisir une page pendant une recherche la referme
	Type("vivres")
	Nav(NS, "camp"):Click()
	Check("[OPT2] clic dans la navigation : recherche refermée", not frame.searching and box:GetText() == "" and frame.currentPage == "camp")
	-- fermer la fenêtre aussi
	Type("vivres")
	frame:Hide()
	frame.scripts.OnHide(frame)   -- le client l'appelle au Hide, pas le harnais
	Check("[OPT2] fermer : recherche refermée", not frame.searching and box:GetText() == "")
end

-- 3. Défilement -----------------------------------------------------------------
do
	Say("-- réglages v2 : défilement")
	T.ResetWorld()
	local rows = {}
	for index = 1, 30 do
		rows[#rows + 1] = { key = "optTest" .. index, label = "Réglage d'essai " .. index, kind = "bool" }
		if index % 10 == 0 then rows[#rows + 1] = { header = "OPT_SECTION_DISPLAY" } end
	end
	WithPage({ id = "zzscroll", title = "OPT_PAGE_GENERAL", rows = rows }, function()
		local frame = Open(NS, "zzscroll")
		local page = frame.pages.zzscroll
		Check("[OPT2] défilement : contenu plus haut que la zone", page.contentHeight > page.viewHeight, page.contentHeight .. " / " .. page.viewHeight)
		local function Alt(key) return Row(NS, key).alt == true end
		Check("[OPT2] ROW / ROW_ALT par rangée visuelle", not Alt("optTest1") and not Alt("optTest2") and Alt("optTest3") and Alt("optTest4")
			and not Alt("optTest5") and Row(NS, "optTest3").bg.vertex[1] == Theme.ROW_ALT[1] and Row(NS, "optTest1").bg.vertex[1] == Theme.ROW[1])
		Check("[OPT2] deux colonnes : même rangée, colonnes voisines", Row(NS, "optTest1").lastPoint.x == 0
			and Row(NS, "optTest2").lastPoint.x == lay.colWidth + lay.colGap and Row(NS, "optTest1").lastPoint.y == Row(NS, "optTest2").lastPoint.y)
		Check("[OPT2] une section repart sur ROW", not Alt("optTest11"))
		local function Shown(key) return Row(NS, key):IsShown() end
		Check("[OPT2] défilement : en haut, le premier visible, le dernier non", Shown("optTest1") and not Shown("optTest30"))
		Check("[OPT2] défilement : ascenseur affiché", frame.scrollThumb:IsShown() and frame.scrollTrack:IsShown())
		local thumbTop = select(5, frame.scrollThumb:GetPoint())
		frame.content.scripts.OnMouseWheel(frame.content, -1)
		Check("[OPT2] molette : la page descend", page.offset > 0 and select(5, frame.scrollThumb:GetPoint()) < thumbTop, page.offset)
		for _ = 1, 40 do frame.content.scripts.OnMouseWheel(frame.content, -1) end
		local lastItem = page.items[#page.items]
		Check("[OPT2] molette : bornée en bas, le dernier élément visible", Shown("optTest30") and lastItem.region:IsShown()
			and page.stopIndex == #page.stops and page.offset + page.viewHeight >= lastItem.y + lastItem.height)
		-- rien n'est montré à moitié : tout élément visible tient dans la zone
		local cut = 0
		for _, item in ipairs(page.items) do
			if item.region:IsShown() and (item.y - page.offset < 0 or item.y - page.offset + item.height > page.viewHeight + 1) then cut = cut + 1 end
		end
		Check("[OPT2] défilement : aucun élément coupé", cut == 0, cut)
		local row = Row(NS, "optTest30")
		row:Click()
		Check("[OPT2] défilement : la carte du bas se règle", NS:DB().optTest30 == false)
		for _ = 1, 40 do NS:ScrollOptions(1) end
		Check("[OPT2] molette : bornée en haut", page.offset == 0 and Shown("optTest1"))
		NS:SelectOptionsPage("general")
		Check("[OPT2] page courte : pas d'ascenseur", not frame.scrollThumb:IsShown())
		frame:Hide()
	end)
end

-- 4. Libellés longs -------------------------------------------------------------
do
	Say("-- réglages v2 : libellés longs")
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
		Check("[OPT2] libellé court : demi-carte", short.span == "half" and short.width == lay.colWidth)
		Check("[OPT2] libellé trop long pour une colonne : pleine largeur, sans troncature", medium.span == "full"
			and medium.width == lay.inner and not medium.truncated and medium.labelWidth <= medium.labelRoom)
		Check("[OPT2] curseur au libellé long : pleine largeur", number.span == "full")
		Check("[OPT2] libellé démesuré : tronqué à sa place", longRow.truncated and longRow.label.width == longRow.labelRoom
			and longRow.labelRoom < longRow.labelWidth)
		_G.GameTooltip.lines = {}
		longRow.scripts.OnEnter(longRow)
		Check("[OPT2] libellé tronqué : entier dans l'infobulle", (_G.GameTooltip.lines or {})[1] == long)
		longRow.scripts.OnLeave(longRow)
		-- la demi-carte suivant une pleine largeur repart à gauche, sans chevauchement
		local page = NS.optionsFrame.pages.zzlong
		local spots = {}
		for _, item in ipairs(page.items) do
			if item.kind == "card" then spots[#spots + 1] = item.x .. ":" .. item.y end
		end
		Check("[OPT2] cartes : une place chacune", #spots == 4 and spots[1] ~= spots[2] and spots[2] ~= spots[3], table.concat(spots, " "))
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
		Check("[OPT2] " .. pair[1] .. " : libellés, valeurs, sous-titres et onglets tiennent", #problems == 0, table.concat(problems, ", "))
		frame:Hide()
	end
end

-- 5. Aperçus ---------------------------------------------------------------------
do
	Say("-- réglages v2 : aperçus")
	T.ResetWorld()
	local frame = Open(NS, "trigger")
	local departure = frame.previews.departure
	Check("[OPT2] aperçu du départ : sous les onglets, la note d'exemple", departure and departure:IsShown() and frame.previewStrip:IsShown()
		and departure.score.text == "85" and departure.note.text == NS.L.OPT_PREVIEW_SAMPLE)
	local _, _, _, _, stripY = frame.previewStrip:GetPoint()
	local _, _, _, _, bodyY = frame.pages.trigger:GetPoint()
	Check("[OPT2] aperçu : sous l'en-tête, au-dessus des réglages", stripY <= lay.tabsTop and stripY > lay.tabsTop - Theme.TABS_HEIGHT
		and bodyY <= stripY - lay.previewHeight,
		stripY .. " / " .. bodyY)
	NS.score = 42
	NS:RefreshOptions()
	Check("[OPT2] aperçu du départ : suit la dernière note", departure.score.text == "42" and departure.note.text == NS.L.OPT_PREVIEW_LAST
		and math.abs(departure.bar.ratio - 0.42) < 0.001)
	NS.score = nil
	NS:SelectOptionsPage("gear")
	Check("[OPT2] aperçu : sur tous les onglets de la page", frame.previews.departure:IsShown())
	NS:SelectOptionsPage("general")
	Check("[OPT2] pas d'aperçu sur Général", not frame.previewStrip:IsShown() and not departure:IsShown())

	NS:SelectOptionsPage("spellranks")
	local ranks = frame.previews.spellranks
	Check("[OPT2] aperçu des rangs : deux cases, liseré rouge sur la première", ranks and #ranks.slots == 2 and ranks.outline:IsShown()
		and ranks.outline.edges.top.vertex[1] == NS.SPELLRANKS_BORDER_COLOR[1] and ranks.outline.edges.top.vertex[2] < 0.3)
	Check("[OPT2] aperçu des rangs : seul le QoL ailleurs n'en a pas", frame.previews.departure:IsShown() ~= true)
	Row(NS, "spellranksBorder"):Click()
	Check("[OPT2] aperçu des rangs : liseré coupé avec le réglage", NS:DB().spellranksBorder == false and not ranks.outline:IsShown()
		and ranks.hint.text == NS.L.SR_PREVIEW_OFF)
	Row(NS, "spellranksBorder"):Click()
	Check("[OPT2] aperçu des rangs : liseré revenu", ranks.outline:IsShown())
	frame:Hide()

	-- un aperçu en erreur ne casse pas la fenêtre
	WithPage({ id = "zzpreview", title = "OPT_PAGE_GENERAL", preview = function() error("aperçu cassé") end,
		rows = { { key = "optPreview", label = "OPT_ENABLED", kind = "bool" } } }, function()
		local before = #NS.errors
		local broken = Open(NS, "zzpreview")
		Check("[OPT2] aperçu en erreur : page affichée, erreur notée", broken.currentPage == "zzpreview" and broken.pages.zzpreview:IsShown()
			and #NS.errors > before)
		broken:Hide()
	end)

	-- QuestCompanion : le compagnon dans son cadre, sur tous les onglets du module
	T.ResetWorld()
	local qframe = Open(QNS, "companionMain")
	local comp = qframe.previews.companionMain
	Check("[OPT2] aperçu du compagnon : nom, apparence, cadre et fond", comp and comp:IsShown()
		and comp.name.text == QNS:CompanionName() and comp.line.text:find(QNS.L[QNS:CompanionCurrentAppearance().label], 1, true)
		and comp.style.text:find(QNS.L.COMP_FRAME_SLATE, 1, true) ~= nil, comp and comp.style.text)
	QNS:SelectOptionsPage("companionOrnaments")
	Check("[OPT2] aperçu du compagnon : sur sa page seulement", not comp:IsShown() and not qframe.previewStrip:IsShown())
	QNS:SelectOptionsPage("general")
	Check("[OPT2] aperçu du compagnon : pas sur Général", not comp:IsShown())
	qframe:Hide()
end

-- 6. Pied, carte d'action, infobulle, liste déroulante ---------------------------------
do
	Say("-- réglages v2 : pied et contrôles")
	T.ResetWorld()
	local frame = Open(NS, "trigger")
	NS:DB().exitDelay = 12
	frame.resetButton:Click()
	Check("[OPT2] Réinitialiser : réglages par défaut", NS:DB().exitDelay ~= 12 and Row(NS, "exitDelay").value.text:find(tostring(NS:DB().exitDelay), 1, true))
	NS.lastResults = nil
	frame.runButton:Click()
	Check("[OPT2] action principale : le check est lancé", NS.lastResults ~= nil and frame.runButton:GetText() == NS.L.OPT_RUNCHECK)
	frame:Hide()
	frame = Open(NS, "general")
	local pos = Row(NS, "minimapPos")
	local angle = NS:DB().minimapAngle or 225
	pos.button:Click()
	Check("[OPT2] carte d'action : le bouton lance l'action", (NS:DB().minimapAngle or 225) ~= angle and pos.button:GetText() == NS.L.OPT_BTN_CHANGE)
	Check("[OPT2] carte d'action : la valeur à gauche du bouton", pos.value:IsShown() and pos.value.text:find("°", 1, true) ~= nil
		and pos.value.lastPoint.relTo == pos.button)
	frame:Hide()

	local qframe = Open(QNS, "companionMain")
	local chatter = Row(QNS, "companionChatter")
	_G.GameTooltip.lines = {}
	chatter.scripts.OnEnter(chatter)
	Check("[OPT2] infobulle déclarée (def.tooltip) au survol de la carte", #(_G.GameTooltip.lines or {}) >= 5 and chatter.hover:IsShown())
	chatter.scripts.OnLeave(chatter)
	Check("[OPT2] phrase sous le libellé : carte plus haute, pleine largeur", chatter.note and chatter.note.text ~= ""
		and chatter.height >= lay.noteCardHeight and chatter.span == "full")
	local source = Row(QNS, "companionTraitSource")
	Check("[OPT2] phrase longue : la carte grandit, la phrase passe à la ligne", source.height > lay.noteCardHeight
		and source.note.height == source.height - lay.noteCardHeight + 14 and source.note:GetStringWidth() > source.labelRoom,
		source.height)
	local short = Row(QNS, "companionSize")
	Check("[OPT2] phrase courte : une ligne", short.height == lay.noteCardHeight)
	local app = Row(QNS, "companionAppearance")
	app:Click()
	Check("[OPT2] clic sur une carte à liste : la liste s'ouvre", app.dropdown:IsOpen())
	app:Click()
	Check("[OPT2] second clic : refermée", not app.dropdown:IsOpen())
	qframe:Hide()

	-- Theme : liste déroulante longue, dix lignes et la molette
	local holder = CreateFrame("Frame", nil, UIParent)
	local options = {}
	for index = 1, 25 do options[index] = { value = index, label = "Choix " .. index } end
	local dd = Theme.CreateDropdown(holder, 160, nil, { listWidth = 240 })
	dd:SetOptions(options)
	dd:SetValue(20)
	dd:Open()
	Check("[OPT2] liste longue : dix lignes, le choix courant en vue", #dd.list.rows == 10 and dd.list.height == 10 * Theme.DROPDOWN_ROW + 2
		and dd.offset > 0 and dd.offset < 20 and dd.offset + 10 >= 20 and dd.list.thumb:IsShown(), dd.offset)
	Check("[OPT2] liste plus large que la case", dd.list.width == 240)
	for _ = 1, 30 do dd:Scroll(-1) end
	Check("[OPT2] molette : bornée en bas", dd.offset == 15 and dd.list.rows[10].entry.value == 25)
	dd.list.rows[10]:Click()
	Check("[OPT2] choix dans la partie défilée", dd.value == 25 and not dd:IsOpen())
	dd:Open()
	dd.list.rows[1].scripts.OnMouseWheel(dd.list.rows[1], 1)
	Check("[OPT2] molette sur une ligne : la liste remonte", dd.offset == 14, dd.offset)
	Check("[OPT2] liste ouverte vers le bas par défaut", not dd.openedUp and dd.list.lastPoint.point == "TOPRIGHT")
	dd:Close()
	dd.GetBottom = function() return 100 end   -- près du bas de l'écran : pas la place
	dd:Open()
	Check("[OPT2] près du bas de l'écran : liste ouverte vers le haut", dd.openedUp and dd.list.lastPoint.point == "BOTTOMRIGHT"
		and dd.list.lastPoint.relPoint == "TOPRIGHT")
end
