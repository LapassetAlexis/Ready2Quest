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
-- R2Q 2.0.0 : navigation par familles. Les blocs qui éprouvent la
-- navigation par pages du socle (celle de QuestCompanion) la prennent sur
-- Ready2Quest le temps du bloc, sans ses familles.
local function Legacy(fn)
	local saved = NS.OPTION_FAMILIES
	NS.OPTION_FAMILIES = nil
	NS.optionsFrame = nil
	local ok, err = pcall(fn)
	NS.OPTION_FAMILIES = saved
	NS.optionsFrame = nil
	if not ok then error(err, 0) end
end

-- page de test le temps d'un bloc, retirée ensuite (navigation par pages)
local function WithPage(def, fn)
	NS.AddOptionPage(def)
	local ok, err = pcall(Legacy, fn)
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

-- 1. Navigation par familles (R2Q 2.0.0) ----------------------------------------
local function Head(ns, id)
	local sec = ns.optionsFrame.sectionIndex[id]
	return sec and sec.item and sec.item.region
end
do
	Say("-- réglages : navigation par familles")
	T.ResetWorld()
	local frame = Open(NS)
	Want("première ouverture : Accueil › Vue d'ensemble", frame.currentPage == "home:overview" and Nav(NS, "home").selected
		and frame.tabs:IsShown() and frame.tabs.selected == "home:overview", frame.currentPage)
	Want("six familles dans l'ordre", NavOrder(NS) == "home,check,sacs,voyage,quetes,combat", NavOrder(NS))
	local list = frame.navList
	Want("colonne sans défilement", list.contentHeight <= list.viewHeight, list.contentHeight)
	local check = Nav(NS, "check")
	Want("entrée : icône du client, libellé, sous-libellé, pas de voyant", check.icon.texture == NS.OPTION_ICONS.check
		and check.label.text == NS.L.OPT_FAM_CHECK and check.sub.text == NS.L.OPT_FAM_CHECK_SUB and not check.power:IsShown())
	Want("plus de titres de groupe", #frame.navHeaders == 0)
	check:Click()
	Want("famille : son premier onglet, sa phrase, interrupteur « Check actif »", frame.currentPage == "check:bags"
		and frame.header.title.text == NS.L.OPT_FAM_CHECK and frame.header.subtitle.text == NS.L.OPT_PAGE_BAGS_SUB
		and frame.headerPower:IsShown() and frame.headerPower.key == "departureEnabled"
		and frame.headerPower.label.text == NS.L.OPT_FAM_CHECK_POWER and frame.headerPower.checked == true)
	frame.tabs.byId["check:when"]:Click()
	Nav(NS, "combat"):Click()
	Nav(NS, "check"):Click()
	Want("famille : le dernier onglet retenu", frame.currentPage == "check:when", frame.currentPage)
	Nav(NS, "sacs"):Click()
	Want("famille sans interrupteur : en-tête sans interrupteur", not frame.headerPower:IsShown())
	Verdict("R2Q : six familles (icône, sous-libellé), colonne fixe, onglets, dernier onglet retenu, interrupteur d'en-tête")

	-- onglets de chaque famille, dans l'ordre de la maquette
	local tabs = {}
	for _, family in ipairs(frame.families) do
		local ids = {}
		for _, tab in ipairs(family.tabs) do ids[#ids + 1] = tab.id end
		tabs[#tabs + 1] = family.id .. "=" .. table.concat(ids, "/")
	end
	Check("[OPT] R2Q : onglets de la maquette", table.concat(tabs, " ") == "home=overview/general check=bags/gear/buffs/when "
		.. "sacs=marchand/plein voyage=retour/camp/donjon quetes=xp/sorts combat=portees/dots/cast/bars", table.concat(tabs, " "))

	-- une tête par fonction ; plus de ligne « Activer » en double
	local heads, problems = {}, {}
	for _, head in ipairs(frame.heads) do
		if head.powerKey then heads[#heads + 1] = head.def.id .. ":" .. head.powerKey end
	end
	Check("[OPT] R2Q : une tête avec interrupteur par fonction", table.concat(heads, ",") == "bagspace:bagspaceEnabled,"
		.. "lootroom:lootroomEnabled,quickloot:quickLootEnabled,expedition:expeditionEnabled,death:deathEnabled,camp:campEnabled,"
		.. "dungeon:dungeonEnabled,groupready:dungeonGroup,reward:rewardEnabled,pace:paceEnabled,spellranks:spellranksEnabled,"
		.. "trainall:trainAllEnabled,aggro:aggroEnabled,combatRange:combatRange,combatDots:combatDots,combatCast:combatCast,"
		.. "combatBars:combatBars", table.concat(heads, ","))
	local powers = { enabled = true, departureEnabled = true }
	for _, head in ipairs(frame.heads) do if head.powerKey then powers[head.powerKey] = true end end
	for _, row in ipairs(frame.rows) do
		if row.def and powers[row.def.key] then problems[#problems + 1] = row.def.key end
	end
	Check("[OPT] R2Q : aucun interrupteur de fonction en double dans les lignes", #problems == 0, table.concat(problems, ","))

	-- les déplacements de la maquette
	local function PageOf(key)
		for _, row in ipairs(frame.rows) do
			if (row.def and row.def.key == key) or row.moduleId == key then return row.pageId end
		end
	end
	local moved = {
		showWindow = "check:when", popupScore = "check:when", barranks = "check:gear", profcap = "check:buffs",
		favoriteClick = "sacs:marchand", favoriteAutoBuyback = "sacs:marchand", autoSellGray = "sacs:marchand",
		exitDelay = "check:when", showMinimap = "home:general", uiStyle = "home:general", reportIcon = "home:general",
		qcAction = "home:general", aggroLink = "combat:portees", campkit = "voyage:camp", deathPanel = "voyage:retour",
	}
	problems = {}
	for key, want in pairs(moved) do
		if PageOf(key) ~= want then problems[#problems + 1] = key .. "=" .. tostring(PageOf(key)) end
	end
	Check("[OPT] R2Q : réglages à leur nouvelle place (check, favoris, interface)", #problems == 0, table.concat(problems, ", "))
	Check("[OPT] R2Q : aucun contrôle du check sans place (rien ne tombe dans Général)", #frame.unplaced == 0,
		table.concat(frame.unplaced, ","))

	-- chaque onglet s'atteint, chaque réglage s'y affiche
	problems = {}
	local shown = 0
	for _, family in ipairs(frame.families) do
		for _, tab in ipairs(family.tabs) do
			local id = family.id .. ":" .. tab.id
			NS:SelectOptionsPage(id)
			if frame.currentPage ~= id then problems[#problems + 1] = id end
			for _, row in ipairs(frame.pages[id].rows) do
				if row:GetParent() == frame.pages[id] and frame.pages[id]:IsShown() then shown = shown + 1
				else problems[#problems + 1] = tostring(row.labelText) end
			end
		end
	end
	Check("[OPT] R2Q : chaque onglet s'ouvre, chaque réglage s'y affiche", #problems == 0 and shown == #frame.rows,
		table.concat(problems, ", ") .. " " .. shown .. "/" .. #frame.rows)
	frame:Hide()
end

-- 1 bis. Tête de fonction, vue d'ensemble, liens directs ----------------------------
do
	Say("-- réglages : fonctions, vue d'ensemble, liens directs")
	T.ResetWorld()
	local frame = Open(NS, "lootroom")
	Want("lien direct : « lootroom » ouvre Sacs & butin › Sac plein & butin, sa tête éclairée", frame.currentPage == "sacs:plein"
		and Head(NS, "lootroom").flash:IsShown())
	local head = Head(NS, "lootroom")
	head.toggle:Click()
	local dimmed, total = 0, 0
	for _, row in ipairs(frame.rows) do
		if row.sectionId == "lootroom" then total = total + 1; if row.dimmed then dimmed = dimmed + 1 end end
	end
	Want("tête : l'interrupteur coupe la fonction", NS:DB().lootroomEnabled == false and head.toggle.checked == false)
	Want("fonction coupée : ses réglages estompés, pas ceux des autres", total == 2 and dimmed == 2
		and not Row(NS, "bagspaceFrame").dimmed, dimmed .. "/" .. total)
	head.toggle:Click()
	Want("rallumée : réglages pleins", NS:DB().lootroomEnabled ~= false and not Row(NS, "lootroomConfirm").dimmed)
	local quick = Head(NS, "quickloot")
	Want("Butin rapide : fonction visible, sa phrase, son interrupteur (même clé)", quick and quick.phrase.text == NS.L.OPT_SEC_QUICKLOOT_SUB
		and quick.toggle.checked == (NS:DB().quickLootEnabled ~= false))
	NS:SelectOptionsPage("trainall")
	Want("lien direct : « trainall » ouvre Quêtes & sorts › Sorts", frame.currentPage == "quetes:sorts"
		and not Head(NS, "lootroom").flash:IsShown() and Head(NS, "trainall").flash:IsShown())
	for old, want in pairs({ departure = "check:bags", qol = "sacs:marchand", trigger = "check:when", safe = "check:when",
		merchant = "sacs:marchand", favorites = "sacs:marchand", general = "home:general", gear = "check:gear",
		aggro = "combat:portees", combatDots = "combat:dots", combatBars = "combat:bars", dungeon = "voyage:donjon",
		camp = "voyage:camp", pace = "quetes:xp", zzinconnu = "home:overview" }) do
		frame.tabChoice = {}
		NS:SelectOptionsPage(old)
		Want("ancien id « " .. old .. " »", frame.currentPage == want, frame.currentPage)
	end
	Verdict("tête de fonction (interrupteur, réglages estompés), fonctions visibles, liens directs et anciens ids")

	frame.tabChoice = {}
	NS:SelectOptionsPage("home")
	local lines = {}
	for _, line in ipairs(frame.dashLines) do lines[#lines + 1] = line.familyId .. ":" .. (line.spec.key or "-") end
	Want("vue d'ensemble : une ligne par fonction, famille par famille", table.concat(lines, ",") == "check:departureEnabled,"
		.. "sacs:autoSellGray,sacs:autoRepair,sacs:-,sacs:bagspaceEnabled,sacs:lootroomEnabled,sacs:quickLootEnabled,"
		.. "voyage:expeditionEnabled,voyage:deathEnabled,voyage:campEnabled,voyage:dungeonEnabled,voyage:dungeonGroup,"
		.. "quetes:rewardEnabled,quetes:paceEnabled,quetes:spellranksEnabled,quetes:trainAllEnabled,"
		.. "combat:aggroEnabled,combat:combatRange,combat:combatDots,combat:combatCast,combat:combatBars", table.concat(lines, ","))
	local dash = frame.pages["home:overview"].dashboard
	Want("vue d'ensemble : tient sans défilement", dash:IsShown() and dash:GetHeight() <= frame.pages["home:overview"].viewHeight
		and not frame.scrollThumb:IsShown(), dash:GetHeight())
	local pace
	for _, line in ipairs(frame.dashLines) do if line.spec.key == "paceEnabled" then pace = line end end
	pace.toggle:Click()
	Want("vue d'ensemble : l'interrupteur est le même réglage", NS:DB().paceEnabled == false and pace.toggle.checked == false)
	NS:SelectOptionsPage("pace")
	Want("… et la tête de la fonction le montre", Head(NS, "pace").toggle.checked == false)
	NS:ToggleModuleKey("paceEnabled")
	NS:SelectOptionsPage("home")
	NS:DB().favorites = { [1] = "Pierre", [2] = "Os" }
	NS.score = 64
	NS:RefreshOptions()
	local fav, score
	for _, line in ipairs(frame.dashLines) do
		if line.spec.go == "favorites" then fav = line end
		if line.spec.key == "departureEnabled" then score = line end
	end
	Want("vue d'ensemble : mentions (favoris, dernière note)", fav.detail.text == NS:F("OPT_DASH_FAVORITES", 2)
		and score.detail.text == NS:F("OPT_DASH_SCORE", 64), tostring(fav.detail.text) .. " / " .. tostring(score.detail.text))
	NS.score = nil
	pace:Click()
	Want("vue d'ensemble : un nom ouvre ses réglages", frame.currentPage == "quetes:xp" and Head(NS, "pace").flash:IsShown())
	NS:SelectOptionsPage("home")
	Want("Accueil : titre « Ready2Quest »", frame.header.title.text == "Ready2Quest")
	local checkCard
	for _, card in ipairs(frame.pages["home:overview"].dashboard.cards) do if card.familyId == "check" then checkCard = card end end
	local targets = {}
	for _, chip in ipairs(checkCard.tabButtons or {}) do targets[#targets + 1] = chip.target end
	Want("carte du check : un raccourci par onglet", table.concat(targets, ",") == "check:bags,check:gear,check:buffs,check:when",
		table.concat(targets, ","))
	checkCard.tabButtons[2]:Click()
	Want("raccourci : l'onglet en un clic", frame.currentPage == "check:gear", frame.currentPage)
	NS:SelectOptionsPage("home")
	checkCard:Click()
	Want("tête de carte : ouvre la famille", frame.currentPage:find("^check:") ~= nil and checkCard.open.text == NS.L.OPT_DASH_OPEN)
	Verdict("vue d'ensemble : une ligne par fonction, sans défilement, même interrupteur, mentions, le nom ouvre la fonction, raccourcis du check")

	-- l'interrupteur de l'en-tête de l'accueil : l'addon
	NS:SelectOptionsPage("general")
	Want("Accueil : « Addon actif » dans l'en-tête", frame.headerPower:IsShown() and frame.headerPower.key == "enabled"
		and frame.headerPower.label.text == NS.L.OPT_FAM_HOME_POWER)
	frame.headerPower:Click()
	Want("« Addon actif » coupé : réglage enabled", NS:DB().enabled == false and frame.headerPower.checked == false)
	frame.headerPower:Click()
	Want("rallumé", NS:DB().enabled ~= false)
	Verdict("Accueil : l'interrupteur « Addon actif » dans l'en-tête")

	-- /r2q options <mot>
	frame:Hide()
	NS:HandleCommand("options combat")
	Want("/r2q options combat : ouverte sur Combat", frame:IsShown() and frame.currentPage:find("^combat:") ~= nil, frame.currentPage)
	NS:HandleCommand("options butin rapide")
	Want("/r2q options butin rapide : la fonction (nom cherché)", frame.currentPage == "sacs:plein" and Head(NS, "quickloot").flash:IsShown(),
		frame.currentPage)
	NS:HandleCommand("options zones")
	Want("/r2q options zones : Quand & où", frame.currentPage == "check:when", frame.currentPage)
	NS:HandleCommand("options zzzz introuvable")
	Want("/r2q options <mot inconnu> : la recherche", frame.searching and frame.searchPage.total == 0)
	frame:Hide()
	frame.scripts.OnHide(frame)
	NS:HandleCommand("options")
	Want("/r2q options : rouvre là où on était (pas la vue d'ensemble)", frame:IsShown() and frame.currentPage == "check:when", frame.currentPage)
	frame:Hide()
	frame.scripts.OnHide(frame)
	Verdict("/r2q options <mot> : famille, fonction, recherche ; sans mot, là où on était")

	-- roue crantée de la fenêtre du check
	NS.optionsFrame = nil
	local opened = NS:OpenOptionsAt("check")
	Want("roue crantée du check : Check avant le départ", opened and opened:find("^check:") ~= nil, opened)
	NS.optionsFrame:Hide()
	-- une fenêtre de module : la roue à gauche du [×], ouvre sur sa fonction
	local dialog = Theme.CreateDialog(UIParent, 400, 200, { title = "Essai", headerIcon = true })
	local gear = NS:AddSettingsGear(dialog, "death")
	Want("roue d'une fenêtre : à gauche du [×]", gear and gear.lastPoint.relTo == dialog.close and NS:AddSettingsGear(dialog, "x") == gear)
	gear:Click()
	Want("roue d'une fenêtre : réglages ouverts sur sa fonction, éclairée", NS.optionsFrame:IsShown()
		and NS.optionsFrame.currentPage == "voyage:retour" and Head(NS, "death").flash:IsShown(), NS.optionsFrame.currentPage)
	NS.optionsFrame:Hide()
	dialog:Hide()
	-- chaque fenêtre de module porte sa roue, vers sa fonction
	local missing = {}
	for file, target in pairs({ Expedition = "expedition", Dungeon = "dungeon", Death = "death", SpellRanks = "spellranks",
		LootRoom = "lootroom", BagSpace = "bagspace" }) do
		local handle = io.open("Ready2Quest/" .. file .. ".lua", "r")
		local text = handle and handle:read("*a") or ""
		if handle then handle:close() end
		if not text:find('AddSettingsGear%(frame, "' .. target .. '"') then missing[#missing + 1] = file end
		if not NS.optionsFrame.sectionIndex[target] then missing[#missing + 1] = target .. ":cible" end
	end
	Want("roue sur les six fenêtres de module, cible existante", #missing == 0, table.concat(missing, ","))
	Verdict("roue crantée : check et fenêtres de module, ouvre sur leur fonction")
end

do
	local qframe = Open(QNS, "general")
	Want("QC : le Compagnon de route en groupe, une entrée par page", NavOrder(QNS) == "general,[COMPAGNON DE ROUTE],companionMain,companionQuiet,companionTalk,companionKeys,"
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
	Say("-- réglages : navigation qui défile (navigation par pages)")
	T.ResetWorld()
	Legacy(function()
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
	end)
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
	local ok, err = pcall(Legacy, function()
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
	local frame = Open(NS)
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
	local places = #NS:FindOptionPlaces("alerte")
	local results = frame.searchPage
	Want("recherche : toutes les cartes qui correspondent", results.total == expected + places and expected >= 4, results.total .. "/" .. expected)
	Want("recherche : vue des résultats, pages cachées", frame.searching and results:IsShown() and not frame.pages["home:overview"]:IsShown()
		and not frame.tabs:IsShown() and not frame.headerPower:IsShown())
	local delay = Row(NS, "exitDelay")
	Want("recherche : la carte est empruntée par les résultats", delay:GetParent() == results and delay:IsShown())
	local sections = 0
	for _, item in ipairs(results.items) do if item.kind == "section" then sections = sections + 1 end end
	Want("recherche : regroupée par onglet", sections >= 2 and results.items[1].kind == "section", sections)
	local badged = 0
	for _, nav in ipairs(frame.navButtons) do if nav.badge:IsShown() then badged = badged + tonumber(nav.badge.text) end end
	Want("recherche : chaque famille compte ses résultats", Nav(NS, "check").badge.text ~= nil and badged == expected
		and Nav(NS, "home").badge:IsShown() ~= true, badged)
	Want("recherche : titre et nombre", frame.header.title.text == NS.L.OPT_SEARCH_TITLE
		and frame.header.subtitle.text:find(tostring(expected + places), 1, true) ~= nil)
	local before = NS:DB().exitDelay
	delay:Step(1)
	Want("recherche : le réglage trouvé se règle", NS:DB().exitDelay == before + 1 and frame.searching)
	Verdict("recherche : toutes les cartes trouvées, empruntées et réglables, regroupées, comptées par famille")
	Type("ECART  alertes")
	Want("recherche : sans accents ni casse, tous les mots", results.total == 1 and results.items[2].region == Row(NS, "alertCooldown"),
		results.total)
	Type("zzzz introuvable")
	Want("recherche : aucun résultat, phrase", results.total == 0 and results.empty.text:find("introuvable", 1, true) ~= nil)
	Verdict("recherche : sans accents ni casse, tous les mots ; aucun résultat : une phrase")

	-- les lieux : fonctions, onglets, anciens noms de pages, avec leur chemin
	Type("butin rapide")
	local line = results.placeLines and results.placeLines[1]
	Want("lieu : une fonction trouvée par son nom, avec son chemin", results.places[1] and results.places[1].go == "quickloot"
		and results.items[1].region == results.placesSection and line:IsShown() and line.label.text == NS.L.OPT_SEC_QUICKLOOT
		and line.path.text == NS.L.OPT_FAM_BAGS .. " > " .. NS.L.OPT_TAB_FULL, line and line.path.text)
	Type("confort de jeu")
	Want("lieu : un ancien nom de page (Confort de jeu)", results.places[1] and results.places[1].go == "sacs")
	Type("declenchement")
	Want("lieu : Déclenchement, sans accents", results.places[1] and results.places[1].go == "trigger")
	Type("prediction")
	Want("lieu : un onglet", results.places[1] and results.places[1].go == "combat:cast" or (results.places[2] and results.places[2].go == "combat:cast"))
	results.placeLines[1]:Click()
	Want("clic sur un lieu : la recherche se ferme sur lui", not frame.searching and frame.currentPage == "combat:cast", frame.currentPage)
	Verdict("recherche des lieux : fonctions, anciens noms, onglets, avec leur chemin ; un clic y mène")

	Type("alerte")
	Type("")
	Want("recherche vidée : page d'avant rendue", not frame.searching and frame.currentPage == "combat:cast"
		and frame.pages["combat:cast"]:IsShown() and not results:IsShown())
	Want("recherche vidée : badges retirés", Nav(NS, "check").badge:IsShown() ~= true)
	NS:SelectOptionsPage("trigger")
	Want("la carte revient sur sa page", delay:GetParent() == frame.pages["check:when"] and delay:IsShown())
	Type("vivres")
	Nav(NS, "voyage"):Click()
	Want("clic dans la navigation : recherche refermée", not frame.searching and box:GetText() == "" and frame.currentPage == "voyage:retour")
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
		NS:SelectOptionsPage("merchant")
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
			if nav.sub and nav.sub:GetStringWidth() > nav.sub.width then problems[#problems + 1] = nav.sub.text end
		end
		for _, head in ipairs(frame.heads or {}) do
			if head.phrase and head.phrase:GetStringWidth() > head.phrase.width then problems[#problems + 1] = head.phrase.text end
		end
		for _, line in ipairs(frame.dashLines or {}) do
			if line.label:GetStringWidth() > line.label.width then problems[#problems + 1] = line.label.text end
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
	local frame = Open(NS, "bags")
	local departure = frame.previews.check
	Want("aperçu du départ : sous les onglets, la note d'exemple", departure and departure:IsShown() and frame.previewStrip:IsShown()
		and departure.score.text == "85" and departure.note.text == NS.L.OPT_PREVIEW_SAMPLE)
	local _, _, _, _, stripY = frame.previewStrip:GetPoint()
	local _, _, _, _, bodyY = frame.pages["check:bags"]:GetPoint()
	Want("aperçu : sous les onglets, au-dessus des réglages", stripY <= lay.tabsTop - Theme.TABS_HEIGHT
		and stripY > lay.tabsTop - Theme.TABS_HEIGHT - 20 and bodyY <= stripY - lay.previewHeight,
		stripY .. " / " .. bodyY)
	NS.score = 42
	NS:RefreshOptions()
	Want("aperçu du départ : suit la dernière note", departure.score.text == "42" and departure.note.text == NS.L.OPT_PREVIEW_LAST
		and math.abs(departure.bar.ratio - 0.42) < 0.001)
	NS.score = nil
	NS:SelectOptionsPage("gear")
	Want("aperçu : sur les onglets du check", frame.previews.check:IsShown())
	NS:SelectOptionsPage("trigger")
	Want("aperçu : pas sur Quand & où (l'onglet tient sans défiler)", not frame.previewStrip:IsShown() and not departure:IsShown())
	NS:SelectOptionsPage("general")
	Want("pas d'aperçu sur Général", not frame.previewStrip:IsShown() and not departure:IsShown())
	Verdict("aperçu du départ : sous l'en-tête, note d'exemple puis la dernière, sur tous les onglets de la page, pas sur Général")

	NS:SelectOptionsPage("spellranks")
	local ranks = frame.previews["quetes:sorts"]
	Want("aperçu des rangs : deux cases, liseré rouge sur la première", ranks and #ranks.slots == 2 and ranks.outline:IsShown()
		and ranks.outline.edges.top.vertex[1] == NS.SPELLRANKS_BORDER_COLOR[1] and ranks.outline.edges.top.vertex[2] < 0.3)
	Want("aperçu des rangs : sur l'onglet Sorts seulement", frame.previews.check:IsShown() ~= true)
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
	-- R2Q 2.0.0 : « Réinitialiser » quitte le pied pour Accueil › Général, avec confirmation
	Want("pied : plus de « Réinitialiser »", not frame.resetButton:IsShown())
	local savedDialogs, savedShow = _G.StaticPopupDialogs, _G.StaticPopup_Show
	local shown
	_G.StaticPopupDialogs = {}
	_G.StaticPopup_Show = function(which) shown = which; return { which = which } end
	NS:SelectOptionsPage("reset")
	Want("« reset » : Accueil › Général", frame.currentPage == "home:general")
	Row(NS, "resetAll").button:Click()
	Want("Tout réinitialiser : demande d'abord", shown == "READY2QUEST_RESET_ALL" and NS:DB().exitDelay == 12)
	StaticPopupDialogs.READY2QUEST_RESET_ALL.OnAccept()
	Want("confirmé : réglages par défaut", NS:DB().exitDelay ~= 12 and Row(NS, "exitDelay").value.text:find(tostring(NS:DB().exitDelay), 1, true))
	_G.StaticPopupDialogs, _G.StaticPopup_Show = savedDialogs, savedShow
	NS:DB().exitDelay = 12
	Want("sans fenêtre de confirmation : rien n'est effacé", NS:ConfirmResetAll() == nil and NS:DB().exitDelay == 12)
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
	Verdict("remise à zéro confirmée (Accueil › Général), action principale du pied, carte d'action (bouton, valeur à sa gauche)")
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
