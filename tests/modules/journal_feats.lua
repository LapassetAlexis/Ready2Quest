-- QuestCompanion 3.7.0 : la page « Hauts faits » du carnet, refaite (chantier C1a).
-- En-tête (rang aux bornes, comptes, plaque du menu), onglets, Aperçu (à
-- portée de main, rattrapés, Communauté, derniers obtenus, récompenses
-- proches, par catégorie), listes (familles, filtres, séries, secrets, tours
-- de force, ligne dépliée, défilement, catégorie longue), recherche (accents,
-- casse, secrets, Échap), suivre (limite, Maj+clic, ligne du suivi à l'écran,
-- clic), coût (page fermée), contrastes sur le vrai fond, textes et code.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme
local L = NS.L
local FP = NS.FeatsPage

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local saved = {}
for _, name in ipairs({ "UnitName", "UnitLevel", "date", "IsShiftKeyDown", "GetStatistic" }) do saved[name] = rawget(_G, name) end
local added = {}
local function Add(row)
	local def = NS.FeatAdd(row)
	added[def.id] = true
	return def
end
local function Drop()
	for index = #NS.FEAT_DEFS, 1, -1 do if added[NS.FEAT_DEFS[index].id] then table.remove(NS.FEAT_DEFS, index) end end
	NS.featIndexDirty = true
	added = {}
end

local function Reset()
	ResetWorld()
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return nil end
	_G.UnitLevel = function() return 20 end
	_G.date = function(format) return format == "%d/%m" and "07/11" or "07/11/2026" end
	_G.IsShiftKeyDown = function() return false end
	_G.GetStatistic = function() return nil end
	NS.featsDormant = false
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.featLoginDone = nil
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	NS:CompanionData().tutoDone = true
	NS:DB().featsFilter = "all"
	Mock:Reset()
end

-- lignes de test : trois secrets (un indice connu), un tour de force, une liste longue
rawset(L, "FEAT_tjf_secret_a", "Nom secret Alpha"); rawset(L, "FEATD_flag_tjfA", "Condition cachée alpha")
rawset(L, "FEAT_tjf_secret_b", "Nom secret Bêta"); rawset(L, "FEATD_flag_tjfB", "Condition cachée bêta")
rawset(L, "FEATH_tjf_secret_b", "Un indice lâché")
rawset(L, "FEAT_tjf_fos", "Pionnier de test"); rawset(L, "FEATD_flag_tjfF", "Avant la date")
rawset(L, "FEAT_tjf_long", "Grande liste"); rawset(L, "FEATD_list_tjfLong", "Tout cocher (%d)")
local LONG = 40
NS.FEAT_LISTS.tjfLong = { topics = NS.FeatTopics("flag"), items = function()
	local out = {}
	for i = 1, LONG do out[i] = "zone:" .. (90000 + i) end
	return out
end, label = function(_, _, i) return "Élément " .. i end }
local function AddTestLines()
	Add({ "tjf_secret_a", 9101, "fun", 5, "account", crit = { "flag", "tjfA" }, hidden = true, reward = { title = 2 } })
	Add({ "tjf_secret_b", 9102, "fun", 5, "account", crit = { "flag", "tjfB" }, hidden = true })
	Add({ "tjf_fos", 9103, "fos", 0, "account", crit = { "flag", "tjfF" } })
	Add({ "tjf_long", 9104, "men", 10, "account", crit = { "list", "tjfLong" } })
end

local function Open(cat)
	if cat then return NS:OpenJournalFeats(cat) end
	NS:HandleCommand("hf")
	return NS.journalFrame
end
-- amène une ligne de la liste en tête (molette)
local function Bring(f, key)
	for index, item in ipairs(f.feats.list.items) do
		if FP.KeyOf(item) == key then f.featsOffset = index - 1 end
	end
	NS:RefreshJournal()
end
local function RowOf(f, pred)
	for _, row in ipairs(f.feats.list.rows) do if row:IsShown() and row.item and pred(row) then return row end end
end

-- 1. En-tête : rang aux bornes, comptes, plaque du menu, onglets ---------------------------------------
do
	Say("-- page Hauts faits : en-tête")
	Reset()
	local f = Open()
	local pane = f.feats
	local s = Steps()
	s.ok("à l'ouverture : Aperçu, six onglets dans l'ordre", f.featsTab == "overview" and #pane.tabs.chips == 6
		and pane.tabs.chips[1].text:GetText() == "Aperçu" and pane.tabs.chips[2].text:GetText() == "Dresseur"
		and pane.tabs.chips[3].text:GetText() == "Compagnon et voyage" and pane.tabs.chips[4].text:GetText() == "Aventure"
		and pane.tabs.chips[5].text:GetText() == "Titres" and pane.tabs.chips[6].text:GetText() == "Statistiques")
	s.ok("avant le premier rang", pane.rankName:GetText() == "Pas encore de rang"
		and pane.rankNext:GetText() == "prochain rang : Connu au village, à 100 points", pane.rankNext:GetText())
	s.ok("plaque du menu sans rang : « 0 points »", f.featPlate == nil or f.featPlate.text:GetText() == "0 points", f.featPlate and f.featPlate.text:GetText())
	local points = 0
	local saveP = NS.FeatPoints
	NS.FeatPoints = function() return points end
	points = 1240; NS:RefreshJournal()
	s.ok("1 240 : Réputé, prochain De grande renommée à 1 500, barre à 48 %", pane.rankName:GetText() == "Réputé"
		and pane.rankNext:GetText() == "prochain rang : De grande renommée, à 1 500 points" and pane.rankBar:IsShown()
		and math.abs((pane.rankBar.ratio or 0) - 0.48) < 0.01, tostring(pane.rankBar.ratio))
	s.ok("plaque du menu : « 1 240 points · Réputé » (ou sans « points » si elle ne tient pas)", f.featPlate == nil
		or f.featPlate.text:GetText() == "1 240 points · Réputé" or f.featPlate.text:GetText() == "1 240 · Réputé",
		f.featPlate and f.featPlate.text:GetText())
	s.ok("plaque du total : 1 240", not pane.pointsPlate or pane.pointsPlate.value:GetText() == "1 240")
	points = 99; NS:RefreshJournal()
	s.ok("99 : encore sans rang", pane.rankName:GetText() == "Pas encore de rang")
	points = 100; NS:RefreshJournal()
	s.ok("100 : Connu au village", pane.rankName:GetText() == "Connu au village"
		and pane.rankNext:GetText() == "prochain rang : Connu du comté, à 250 points")
	points = 4000; NS:RefreshJournal()
	s.ok("4 000 : dernier rang, « Le sommet : 5 000 points »", pane.rankName:GetText() == "Légende vivante"
		and pane.rankNext:GetText() == "Le sommet : 5 000 points" and pane.rankBar:IsShown())
	points = 5000; NS:RefreshJournal()
	s.ok("5 000 : plus rien", pane.rankNext:GetText() == "" and not pane.rankBar:IsShown())
	points = 1240; NS:RefreshJournal()
	s.ok("plaque longue : plus petite ou sans « points », jamais plus large que la plaque", (function()
		if not f.featPlate then return true end
		points = 3000; NS:RefreshJournal()
		local text = f.featPlate.text:GetText()
		return text == "3 000 · Célèbre dans tout Azeroth" or Theme.TextWidth(f.featPlate, text, Theme.F_SMALL) <= f.featPlate.text:GetWidth()
	end)(), f.featPlate and f.featPlate.text:GetText())
	NS.FeatPoints = saveP
	NS:FeatAward("char_level_10", { silent = true })
	NS:RefreshJournal()
	local _, total = NS:FeatCategoryStats("all")
	s.ok("« 1 sur N obtenus » (comptables), pas de secret découvert", pane.gotText:GetText() == "1 sur " .. FP.Num(total) .. " obtenus"
		and pane.secretText:GetText() == "", pane.gotText:GetText())
	AddTestLines()
	NS:FeatAward("tjf_secret_a", { silent = true })
	NS:RefreshJournal()
	s.ok("un secret découvert : la ligne dessous", pane.secretText:GetText() == "1 secret découvert")
	-- onglet gardé pour la session
	pane.tabChips.aventure:Click()
	NS:SelectJournalKind("evolution"); NS:SelectJournalKind("feats")
	s.ok("onglet gardé pour la session", f.featsTab == "aventure" and pane.list:IsShown())
	s.check("[JF] en-tête : rang aux bornes (sans rang, 100, dernier, sommet), barre, comptes, secrets, plaque du menu, onglets")
	f:Hide()
	Drop()
end

-- 2. Aperçu ------------------------------------------------------------------------------------------------
do
	Say("-- page Hauts faits : Aperçu")
	Reset()
	local data = NS:CaptureData()
	for i = 1, 8 do data.creatures[80000 + i] = { name = "C" .. i, normal = true, class = "normal", type = "Bête" } end
	data.count = 8
	NS:FeatAward("men_first", { silent = true, at = 1793000000 })
	NS:FeatAward("char_level_10", { silent = true, at = 1793100000 })
	local f = Open()
	local view = f.feats.views.overview
	local s = Steps()
	local near = NS:FeatNearest(4)
	s.ok("à portée de main : FeatNearest(4), nom, barre, compte, bouton Suivre", #near > 0 and view.near[1]:IsShown()
		and view.near[1].def == near[1].def and view.near[1].name:GetText() == NS:FeatName(near[1].def)
		and view.near[1].count:GetText() == NS:FeatCountText(near[1].cur, near[1].max) and view.near[1].follow:IsShown()
		and not view.near[1].unfollow:IsShown())
	s.ok("pas de rattrapage : pas de bloc", not view.catch:IsShown() and not view.catchSec:IsShown())
	-- (la page Communauté existe : sans elle, la ligne ne s'affiche pas)
	s.ok("page Communauté : la ligne est là", view.community:IsShown())
	do
		local real = NS.CommunityOpen
		NS.CommunityOpen = nil
		NS:RefreshJournal()
		s.ok("pas de page Communauté : pas de ligne", not view.community:IsShown())
		NS.CommunityOpen = real
		NS:RefreshJournal()
	end
	s.ok("derniers obtenus : le plus récent d'abord, date courte", view.recent[1].name:GetText() == NS:FeatName("char_level_10")
		and view.recent[1].date:GetText() == "07/11" and view.recent[2].name:GetText() == NS:FeatName("men_first")
		and view.recent[3].name:GetText() == "")
	local rewards = NS:FeatNearest(3, FP.HasReward)
	s.ok("récompenses proches : seulement avec titre, aide ou cosmétique ; récompense puis « nom : cur / max »", #rewards > 0
		and FP.HasReward(rewards[1].def) and view.rewards[1].reward:GetText() == FP.UpperFirst(NS:FeatRewardText(rewards[1].def))
		and view.rewards[1].line:GetText() == NS:FeatName(rewards[1].def) .. " : " .. NS:FeatCountText(rewards[1].cur, rewards[1].max))
	local cats = 0
	for _, line in ipairs(view.cats) do if line:IsShown() then cats = cats + 1 end end
	s.ok("par catégorie : six au plus, non terminées", cats > 0 and cats <= 6)
	view.cats[1]:Click()
	s.ok("clic sur une catégorie : sa famille, elle choisie", f.featsTab ~= "overview" and f.feats.list.cat == view.cats[1].cat)
	NS:JournalFeatsTab("overview")
	-- rattrapage : le relevé posé une fois, le bloc, « Voir la liste »
	NS:FeatStore("account").catchup = nil
	local note = NS:FeatCatchUpNote({ NS:FeatDef("men_first"), NS:FeatDef("char_level_10") }, 7)
	local again = NS:FeatCatchUpNote({ NS:FeatDef("men_first") }, 99)
	s.ok("relevé du rattrapage : une fois, points et paillettes", note and again == nil and #note.ids == 2 and note.pts == 10
		and note.glitter >= 7)
	NS:RefreshJournal()
	s.ok("bloc « Rattrapés » : texte de la maquette", view.catch:IsShown() and view.catch.name:GetText() == "2 hauts faits retrouvés dans ta progression"
		and view.catch.desc:GetText():find("^10 points et ") ~= nil and view.catch.desc:GetText():find("comptés une fois à la mise à jour", 1, true))
	view.catch.see:Click()
	local list = f.feats.list
	s.ok("« Voir la liste » : les rattrapés, comme une recherche, catégorie en étiquette", f.featsResults == "catchup" and list:IsShown()
		and #list.items == 2 and list.head:GetText() == "2 hauts faits retrouvés dans ta progression" and not list.filters:IsShown()
		and (function()
			local row = list.rows[1]
			for _, tag in ipairs(row.tags) do if tag:IsShown() and tag.label:GetText() == Theme.Upper(L["FEATC_" .. row.def.cat]) then return true end end
		end)())
	NS:JournalFeatsTab("overview")
	-- la ligne vers la page Communauté, si elle existe
	local opened
	local realOpen = NS.CommunityOpen
	NS.CommunityOpen = function(_, tab) opened = tab end
	NS:RefreshJournal()
	s.ok("page Communauté présente : la ligne, mots dorés, au-dessous du bloc", view.community:IsShown()
		and view.community.text:GetText():find("Une minute ? ", 1, true) and view.community.text:GetText():find(Theme.Hex(Theme.GOLD_LIGHT), 1, true))
	view.community:Click()
	s.ok("clic : la page Communauté, onglet Ton avis", opened == "avis")
	NS.CommunityOpen = realOpen
	-- suivre depuis l'Aperçu
	view.near[1].follow:Click()
	s.ok("Suivre : suivi, le bouton devient « Suivi »", FP.Followed(NS, near[1].def.id) and view.near[1].unfollow:IsShown()
		and not view.near[1].follow:IsShown())
	view.near[1].unfollow:Click()
	s.ok("« Suivi » retire", not FP.Followed(NS, near[1].def.id))
	s.check("[JF] Aperçu : à portée de main, rattrapés (relevé une fois, Voir la liste), Communauté si elle existe, derniers obtenus, récompenses proches, par catégorie")
	f:Hide()
end

-- 3. Listes : familles, filtres, séries, secrets, tours de force, ligne dépliée, défilement -------------------
do
	Say("-- page Hauts faits : listes")
	Reset()
	AddTestLines()
	local data = NS:CaptureData()
	for i = 1, 12 do data.creatures[80000 + i] = { name = "C" .. i, normal = true, class = "normal", type = "Bête" } end
	data.count = 12
	NS:FeatAward("men_first", { silent = true }); NS:FeatAward("men_species_10", { silent = true })
	NS:FeatAward("tjf_fos", { silent = true, at = 1793000000 })
	NS:FeatStore("account").hints = { tjf_secret_b = 1 }
	local f = Open("men")
	local list = f.feats.list
	local s = Steps()
	local cats = NS:FeatFamilyCategories("dresseur")
	local shown = 0
	for _, tile in ipairs(list.cats) do if tile:IsShown() then shown = shown + 1 end end
	s.ok("colonne : les catégories de la famille, la choisie en surbrillance", shown == #cats and f.featsTab == "dresseur"
		and list.cat == "men" and (function()
			for _, tile in ipairs(list.cats) do if tile.cat == "men" then return tile.selected end end
		end)())
	local st = FP.CatStats(NS).men
	s.ok("compte de droite : « n sur N · p points sur P »", list.count:GetText() == NS:F("FEAT_LIST_COUNT", FP.Num(st.got), FP.Num(st.total),
		FP.Num(st.pts), FP.Num(st.ptsMax)), list.count:GetText())
	Bring(f, "s:species")
	local species = RowOf(f, function(r) return r.item.key == "species" end)
	s.ok("série : une ligne, son nom, « SÉRIE · PALIER i SUR n », un losange par palier, prochain palier", species
		and species.name:GetText() == "Espèces capturées"
		and species.tags[1].label:GetText() == Theme.Upper(NS:F("FEAT_TAG_SERIES", species.item.index, #species.item.defs))
		and species.pipCount == #species.item.defs
		and species.desc:GetText():find("^Prochain : " .. NS:FeatName(species.item.def), 1) ~= nil
		and species.count:GetText() == NS:FeatCountText(species.item.cur, species.item.max) and species.bar:IsShown(),
		species and species.desc:GetText())
	s.ok("pas une ligne par palier", RowOf(f, function(r) return r.def.id == "men_species_25" and not r.item.defs end) == nil)
	-- au-delà de 14 paliers : une seule ligne de losanges
	local fake = { key = "species", defs = {}, index = 3, done = 2, cur = 1, max = 2, def = NS:FeatDef("men_first"), state = "open" }
	for i = 1, 30 do fake.defs[i] = NS:FeatDef("men_first") end
	FP.FillRow(NS, species, fake, 514, {})
	s.ok("30 paliers : losanges resserrés sur une ligne, avant la barre", species.pipStep * 29 + species.pipSize <= NS.JOURNAL_FEATS_ROW.pipRoom + 10
		and species.pipSize >= 4)
	NS:RefreshJournal()
	-- ligne dépliée : liste cochée, boutons, une seule à la fois
	Bring(f, "tjf_long")
	local long = RowOf(f, function(r) return r.def.id == "tjf_long" end)
	if long then long:Click("LeftButton") end
	long = RowOf(f, function(r) return r.def.id == "tjf_long" end)
	s.ok("clic : dépliée sous elle-même, étiquettes LISTE et COMPTE, cases (textures), Suivre, « Clic : replier »", long
		and long.selected and long.sep:IsShown() and long.checks and long.checks[1]:IsShown()
		and long.checks[1].box.done == false and long.follow:IsShown() and not long.share:IsShown() and not long.souvenir:IsShown()
		and long.fold:GetText() == "Clic : replier" and (function()
			local t = {}
			for _, tag in ipairs(long.tags) do if tag:IsShown() then t[#t + 1] = tag.label:GetText() end end
			t = table.concat(t, ",")
			return t:find("LISTE", 1, true) and t:find("COMPTE", 1, true)
		end)())
	s.ok("liste longue (40) : la ligne tient dans la zone, « et k autres »", long and long:GetHeight() <= NS.JOURNAL_FEATS_LAYOUT.listBottom - NS.JOURNAL_FEATS_LAYOUT.listY
		and long.more:IsShown() and long.more:GetText():find("^et %d+ autres$") ~= nil, long and long:GetHeight())
	if long then long:Click("LeftButton") end
	s.ok("second clic : repliée", f.featsOpen == nil)
	-- série dépliée : ses paliers
	Bring(f, "s:species")
	species = RowOf(f, function(r) return r.item.key == "species" end)
	species:Click("LeftButton")
	species = RowOf(f, function(r) return r.item.key == "species" end)
	s.ok("série dépliée : paliers (nom, seuil, points, date ou « à faire »)", species and species.checks[1]:IsShown()
		and species.checks[1].label:GetText() == NS:FeatName(species.item.defs[1]) and species.checks[1].detail:GetText() == "07/11"
		and species.checks[3].detail:GetText() == "à faire" and species.checks[3].pts:GetText():find("points$") ~= nil)
	-- filtres
	list.filterChips.got:Click()
	s.ok("Obtenus : séries finies et obtenus", (function()
		for _, item in ipairs(list.items) do if not item.got then return false end end
		return true
	end)())
	list.filterChips.open:Click()
	s.ok("En cours : non obtenus et commencés", #list.items > 0 and (function()
		for _, item in ipairs(list.items) do
			if item.got then return false end
			if not item.defs and (item.cur or 0) <= 0 then return false end
		end
		return true
	end)())
	list.filterChips.reward:Click()
	s.ok("Avec récompense : rien que des lignes à récompense", #list.items > 0 and (function()
		for _, item in ipairs(list.items) do
			if not item.defs and not FP.HasReward(item.def) then return false end
		end
		return true
	end)())
	-- catégorie vide après filtre : la phrase
	NS:JournalFeatsPick("fos")
	list.filterChips.open:Click()
	s.ok("vide après filtre : la phrase dit pourquoi", #list.items == 0 and list.empty:IsShown()
		and list.empty:GetText() == L.FEAT_EMPTY_open)
	list.filterChips.all:Click()
	local fos = RowOf(f, function(r) return r.def.id == "tjf_fos" end)
	s.ok("tour de force : sa catégorie, « TOUR DE FORCE · 0 POINT », losange au trait, date", fos
		and fos.tags[1].label:GetText() == "TOUR DE FORCE · 0 POINT" and fos.diaMode == "fos" and fos.pts:GetText() == ""
		and fos.date:GetText() == "Obtenu le 07/11/2026")
	s.ok("note sous les tours de force", list.note:IsShown() and list.note:GetText():find("le total reste atteignable", 1, true))
	-- secrets (Insolite)
	NS:JournalFeatsPick("fun")
	f.featsOffset = 99; NS:RefreshJournal()
	local a = RowOf(f, function(r) return r.def.id == "tjf_secret_a" end)
	local b = RowOf(f, function(r) return r.def.id == "tjf_secret_b" end)
	s.ok("secret sans indice : nom caché, « SECRET », phrase d'attente, losange « ? », ni compte ni récompense", a
		and a.name:GetText() == "Un secret du compagnon" and a.tags[1].label:GetText() == "SECRET" and a.desc:GetText() == L.FEAT_NO_HINT
		and a.pts:GetText() == "?" and a.line:GetText() == "" and a.count:GetText() == "")
	s.ok("secret à l'indice connu : « Indice : « … » »", b and b.desc:GetText() == "Indice : « Un indice lâché »")
	local s2 = FP.CatStats(NS).fun
	s.ok("compte d'une catégorie à secrets : « n sur N · k secrets sur K »", list.count:GetText()
		== NS:F("FEAT_LIST_SECRETS", FP.Num(s2.got), FP.Num(s2.total), FP.Num(s2.secretsGot), FP.Num(s2.secrets)))
	s.ok("note en bas d'Insolite", list.note:IsShown())
	if a then a:Click("LeftButton") end
	a = RowOf(f, function(r) return r.def.id == "tjf_secret_a" end)
	s.ok("secret déplié : ni Suivre, ni liste, ni étiquette de portée", a and a.selected and not a.follow:IsShown()
		and not a.unfollow:IsShown() and not (a.checks and a.checks[1] and a.checks[1]:IsShown()))
	NS:FeatAward("tjf_secret_a", { silent = true })
	NS:RefreshJournal()
	a = RowOf(f, function(r) return r.def.id == "tjf_secret_a" end)
	s.ok("secret obtenu : son vrai nom, « SECRET DÉCOUVERT »", a and a.name:GetText() == "Nom secret Alpha"
		and a.tags[1].label:GetText() == "SECRET DÉCOUVERT")
	-- défilement : ligne par ligne, « i à j sur n », toutes les lignes dépliables
	NS:JournalFeatsPick("men")
	local n = #list.items
	s.ok("position « 1 à j sur n »", list.position:GetText() == NS:F("FEAT_POSITION", 1, list.last, n))
	local seen, expandable = {}, true
	for _ = 1, n + 2 do
		for _, row in ipairs(list.rows) do
			if row:IsShown() and row.key then seen[row.key] = true end
		end
		NS:ScrollJournal(-1)
	end
	local count = 0
	for _ in pairs(seen) do count = count + 1 end
	for _, item in ipairs(list.items) do
		NS:JournalFeatsToggle(FP.KeyOf(item)); f.featsReveal = true; NS:RefreshJournal()
		local row = RowOf(f, function(r) return r.key == FP.KeyOf(item) end)
		if not (row and row.selected and row:GetHeight() <= NS.JOURNAL_FEATS_LAYOUT.listBottom - NS.JOURNAL_FEATS_LAYOUT.listY) then expandable = false end
		NS:JournalFeatsToggle(FP.KeyOf(item))
	end
	s.ok("catégorie longue : la molette passe par toutes les lignes", count == n, count .. "/" .. n)
	s.ok("catégorie longue : chaque ligne se déplie et tient", expandable)
	s.check("[JF] listes : colonne de la famille, compte, séries (losanges, prochain, paliers), ligne dépliée, filtres, vide expliqué, tours de force, secrets, défilement")
	f:Hide()
	Drop()
end

-- 4. Recherche ---------------------------------------------------------------------------------------------
do
	Say("-- page Hauts faits : recherche")
	Reset()
	AddTestLines()
	local f = Open()
	local pane = f.feats
	local list = pane.list
	local s = Steps()
	s.ok("le champ ne prend pas le clavier tout seul", pane.search.autoFocus == false and not pane.search:HasFocus())
	NS:JournalFeatsSearch("p")
	s.ok("un caractère : rien ne change", pane.views.overview:IsShown())
	local target = NS:FeatName("char_level_10")
	NS:JournalFeatsSearch((FP.Fold(target):upper():gsub("E", "É"))); NS:RefreshJournal()
	s.ok("dès deux caractères, sans accents ni casse : résultats à la place de l'onglet", list:IsShown() and #(list.items or {}) >= 1
		and (function() for _, it in ipairs(list.items or {}) do if it.def.id == "char_level_10" then return true end end end)(), #(list.items or {}) .. "/" .. tostring(list:IsShown()))
	NS:JournalFeatsSearch("cachée alpha"); NS:RefreshJournal()
	s.ok("un secret non obtenu ne se trouve pas par sa condition", #list.items == 0 and list.empty:GetText():find("Aucun haut fait", 1, true))
	NS:JournalFeatsSearch("secret alpha"); NS:RefreshJournal()
	s.ok("ni par son vrai nom", #list.items == 0)
	NS:JournalFeatsSearch("indice lache"); NS:RefreshJournal()
	s.ok("par son indice connu : non (indice pas encore lâché)", #list.items == 0)
	NS:FeatStore("account").hints = { tjf_secret_b = 1 }
	NS:JournalFeatsSearch("indice lache"); NS:RefreshJournal()
	NS:RefreshJournal()
	s.ok("son indice lâché : trouvé sous « Un secret du compagnon »", #list.items == 1 and list.rows[1].name:GetText() == "Un secret du compagnon")
	pane.search:SetFocus()
	pane.search:SetText("abc")
	pane.search:GetScript("OnEscapePressed")(pane.search)
	s.ok("Échap : champ vidé, clavier rendu, l'onglet revient", not pane.search:HasFocus() and (pane.search:GetText() or "") == ""
		and pane.views.overview:IsShown())
	s.check("[JF] recherche : dès deux caractères, accents et casse ignorés, secrets protégés, Échap vide et rend le clavier")
	f:Hide()
	Drop()
end

-- 5. Suivre et le suivi à l'écran -----------------------------------------------------------------------------
do
	Say("-- page Hauts faits : suivre")
	Reset()
	AddTestLines()
	NS:DB().journalTracker = true
	local f = Open("char")
	local list = f.feats.list
	local s = Steps()
	local ids = {}
	for _, item in ipairs(list.items) do
		if not item.got and not item.defs then ids[#ids + 1] = item.def.id end
	end
	for _, id in ipairs({ "char_level_30", "char_level_40" }) do table.insert(ids, 1, id) end
	s.ok("trois suivis", NS:FeatFollow("char_level_30", true) and NS:FeatFollow("men_species_50", true) and NS:FeatFollow("zone_visit_25", true))
	local row = list.rows[1]
	local def = row.def
	if FP.Followed(NS, def.id) then row = list.rows[2]; def = row.def end
	_G.IsShiftKeyDown = function() return true end
	row:Click("LeftButton")
	_G.IsShiftKeyDown = function() return false end
	s.ok("un quatrième (Maj+clic) : refusé d'une phrase, rien ne change", not FP.Followed(NS, def.id) and #NS:FeatFollowed() == 3
		and f.feats.notice:GetText() == "Trois hauts faits suivis au plus : retires-en un.", f.feats.notice:GetText())
	NS:FeatFollow("zone_visit_25", false)
	_G.IsShiftKeyDown = function() return true end
	row:Click("LeftButton")
	_G.IsShiftKeyDown = function() return false end
	s.ok("Maj+clic : suit, comme le bouton", FP.Followed(NS, def.id) and f.featsOpen == nil)
	-- le suivi à l'écran : la ligne, au rang 3, nom et « cur / max »
	NS:FeatFollow(def.id, false)
	NS:FeatFollow("zone_visit_25", false)
	NS:FeatFollow("men_species_50", false)
	local goals = NS:JournalTrackerObjectives()
	local goal
	for _, g in ipairs(goals) do if g.id == "feat:char_level_30" then goal = g end end
	local cur, max = NS:FeatProgress("char_level_30")
	s.ok("ligne du suivi : nom, « cur / max », rang 3", goal and goal.label == NS:FeatName("char_level_30") and goal.rank == 3
		and goal.progress == NS:FeatCountText(cur, max), goal and goal.progress)
	NS:RefreshJournalTracker()
	local line
	for _, l in ipairs((NS.journalTracker and NS.journalTracker.lines) or {}) do if l.goal and l.goal.id == "feat:char_level_30" then line = l end end
	s.ok("dans le cadre du suivi", line and line:IsShown())
	f:Hide()
	if line then line:Click("LeftButton") end
	f = NS.journalFrame
	s.ok("clic : le carnet sur ce haut fait, déplié", f and f:IsShown() and f.kind == "feats" and f.featsOpen == "s:level"
		and RowOf(f, function(r) return r.key == "s:level" and r.selected end) ~= nil, f and tostring(f.featsOpen))
	-- un secret ne se suit pas, n'apparaît pas dans le suivi
	s.ok("un secret ne se suit pas", select(2, NS:FeatFollow("tjf_secret_a", true)) == "unknown")
	-- obtenu : il sort tout seul
	NS:FeatAward("char_level_30", { silent = true })
	s.ok("obtenu : sorti des suivis et du suivi à l'écran", not FP.Followed(NS, "char_level_30") and (function()
		for _, g in ipairs(NS:JournalTrackerObjectives()) do if g.id == "feat:char_level_30" then return false end end
		return true
	end)())
	-- Partager : seulement obtenu ; Carte souvenir : seulement si elle existe
	NS:OpenJournalFeatsAt("char_level_30")
	local open = RowOf(f, function(r) return r.selected end)
	s.ok("série dépliée non finie : pas de Partager", open and not open.share:IsShown())
	NS:FeatAward("char_hearth_50", { silent = true })
	NS:OpenJournalFeatsAt("char_hearth_50")
	open = RowOf(f, function(r) return r.selected end)
	s.ok("obtenu : Partager, pas de Suivre, pas de Carte souvenir", open and open.share:IsShown() and not open.follow:IsShown()
		and not open.souvenir:IsShown())
	NS.SouvenirShow = function() end
	NS:RefreshJournal()
	open = RowOf(f, function(r) return r.selected end)
	s.ok("ns.SouvenirShow présente : Carte souvenir", open and open.souvenir:IsShown())
	NS.SouvenirShow = nil
	s.check("[JF] suivre : trois au plus (phrase), Maj+clic, ligne du suivi à l'écran (rang 3, nom, cur / max, clic : déplié), secrets, obtenu sort ; Partager, Carte souvenir")
	f:Hide()
	Drop()
end

-- 6. Coût : rien fermée, sur événement ouverte -------------------------------------------------------------------
do
	Say("-- page Hauts faits : coût")
	Reset()
	local f = Open()
	f:Hide()
	local calls = 0
	local base = NS.FeatSeriesList
	local baseN = NS.FeatNearest
	NS.FeatSeriesList = function(...) calls = calls + 1; return base(...) end
	NS.FeatNearest = function(...) calls = calls + 1; return baseN(...) end
	NS:FeatAward("char_level_10", { silent = true })
	NS:FeatTouch("level"); Mock:Advance(2)
	local closed = calls
	f = Open()
	local opened = calls
	Mock:Advance(5)
	local idle = calls
	NS.FeatSeriesList, NS.FeatNearest = base, baseN
	Check("[JF] coût : rien calculé page fermée, calculé à l'ouverture, rien par image ensuite", closed == 0 and opened > 0 and idle == opened,
		closed .. "/" .. opened .. "/" .. idle)
	f:Hide()
end

-- 7. Contrastes sur le vrai fond, textes, code -------------------------------------------------------------------
do
	Say("-- page Hauts faits : contrastes, textes, code")
	local s = Steps()
	local tile = { Theme.ROW, Theme.ROW_ALT, Theme.Over(Theme.ROW, Theme.WHITE, (Theme.FORGE_CARD or {}).light or 0.045),
		Theme.Over(Theme.ROW, Theme.WHITE, Theme.HOVER_ALPHA) }
	local window = { Theme.WINDOW, Theme.Over(Theme.WINDOW, Theme.WHITE, (Theme.FORGE_CARD or {}).light or 0.045) }
	local low = {}
	local function Min(ink, list) local m = 99; for _, bg in ipairs(list) do m = math.min(m, Theme.Contrast(ink, bg)) end return m end
	for _, item in ipairs({
		{ "nom d'une ligne", Theme.LABEL, tile, 4.5 }, { "nom obtenu", Theme.PARCHMENT, tile, 4.5 },
		{ "description, compte, date", Theme.MUTED_LIGHT, tile, 4.5 }, { "récompense", Theme.GOLD, tile, 4.5 },
		{ "phrase vide, note, « Clic : replier »", Theme.MUTED, tile, 4.5 }, { "liste cochée", Theme.TEXT, tile, 4.5 },
		{ "rang et derniers obtenus (fenêtre)", Theme.PARCHMENT, window, 4.5 }, { "prochain rang, comptes (fenêtre)", Theme.MUTED_LIGHT, window, 4.5 },
		{ "récompense proche (fenêtre)", Theme.GOLD, window, 4.5 }, { "note et vides (fenêtre)", Theme.MUTED, window, 4.5 },
		{ "phrase de la limite (fenêtre)", Theme.GOLD_LIGHT, window, 4.5 }, { "catégorie (fenêtre)", Theme.TEXT, window, 4.5 },
		{ "titre de section (identité)", Theme.IDENTITY_LIGHT, window, 3 },
		{ "chiffre du losange gris", Theme.PARCHMENT, { Theme.CONTROL }, 4.5 }, { "chiffre du losange or", Theme.INK, { Theme.GOLD }, 4.5 },
	}) do
		local c = Min(item[2], item[3])
		low[#low + 1] = string.format("%s %.2f", item[1], c)
		s.ok(item[1] .. " ≥ " .. item[4], c >= item[4], string.format("%.2f", c))
	end
	for _, tag in ipairs({ { "SÉRIE", Theme.ARCANE_LIGHT }, { "SECRET", FP.SecretInk() }, { "TOUR DE FORCE", Theme.GOLD_LIGHT },
		{ "LISTE", Theme.MUTED_LIGHT } }) do
		local bgs = {}
		for _, bg in ipairs(tile) do bgs[#bgs + 1] = Theme.Over(bg, tag[2], 0.16) end
		local c = Min(tag[2], bgs)
		low[#low + 1] = string.format("étiquette %s %.2f", tag[1], c)
		s.ok("étiquette " .. tag[1] .. " sur son fond ≥ 4,5", c >= 4.5, string.format("%.2f", c))
	end
	NS.journalFeatsContrasts = low
	s.check("[JF] contrastes mesurés sur le vrai fond (tuiles, fenêtre, losanges, étiquettes) : ≥ 4,5 texte, ≥ 3 titres")
	-- textes : FR/EN complets, aucune clé brute affichée, aucun glyphe
	local s2 = Steps()
	for _, pair in ipairs({ NS.JOURNAL_FEATS_STRINGS, NS.JOURNAL_FEATS_LIST_STRINGS }) do
		if pair then
			for key in pairs(pair.fr) do s2.ok("anglais de " .. key, pair.en[key] ~= nil) end
			for key, text in pairs(pair.en) do
				s2.ok("français de " .. key, pair.fr[key] ~= nil)
				for _, glyph in ipairs({ "★", "☆", "✓", "✗" }) do
					s2.ok("glyphe " .. glyph .. " dans " .. key, not tostring(text):find(glyph, 1, true) and not tostring(pair.fr[key] or ""):find(glyph, 1, true))
				end
			end
		end
	end
	for key in pairs(NS.FEAT_SERIES) do s2.ok("nom de série " .. key, L["FEAT_SERIES_" .. key] ~= "FEAT_SERIES_" .. key) end
	-- les textes affichés par la page, toutes vues
	Reset()
	AddTestLines()
	local f = Open()
	local raw = {}
	local function Scan()
		for _, region in ipairs(Mock.frames) do
			local text = region.kind == "FontString" and region.text
			if type(text) == "string" and (text:match("^FEAT[DHCF]?_") or text:match("^JRN_") or text:find("%%[sd]")) then raw[#raw + 1] = text end
		end
	end
	Scan()
	for _, tab in ipairs({ "dresseur", "voyage", "aventure", "titles", "stats" }) do NS:JournalFeatsTab(tab); Scan() end
	NS:JournalFeatsPick("fun"); f.featsOffset = 99; NS:RefreshJournal(); Scan()
	NS:JournalFeatsSearch("zz"); NS:RefreshJournal(); Scan()
	s2.ok("aucune clé brute ni code de format à l'écran", #raw == 0, table.concat(raw, " | "))
	s2.check("[JF] textes : français et anglais, noms des séries, aucune clé brute à l'écran, aucun glyphe ★ ☆ ✓ ✗")
	f:Hide()
	Drop()
	-- code : aucune couleur codée en dur dans les fichiers de la page
	local s3 = Steps()
	for _, file in ipairs({ "QuestCompanion/JournalFeats.lua", "QuestCompanion/JournalFeatsList.lua" }) do
		local handle = io.open((rawget(_G, "ADDON_ROOT") or ".") .. "/" .. file, "r")
		local text = handle and handle:read("*a") or ""
		if handle then handle:close() end
		s3.ok(file .. " lu", text ~= "")
		local n = 0
		for line in text:gmatch("[^\n]+") do
			local code = line:gsub("%-%-.*$", "")
			if code:find("|c%x%x%x%x%x%x%x%x") or code:find("{%s*0?%.%d+%s*,%s*0?%.%d+%s*,%s*0?%.%d+") or code:find("SetVertexColor%(%s*%d")
				or code:find("SetTextColor%(%s*%d") then n = n + 1 end
			for _, glyph in ipairs({ "★", "☆", "✓", "✗" }) do if code:find(glyph, 1, true) then n = n + 1 end end
		end
		s3.ok(file .. " : aucune couleur ni glyphe en dur", n == 0, n)
	end
	s3.check("[JF] code : couleurs par les jetons du thème seulement, aucun glyphe")
end

for name, fn in pairs(saved) do _G[name] = fn end
