-- QuestCompanion 3.7.0 (chantier C1b) : onglets « Titres » et « Statistiques »
-- de la page Hauts faits (JournalFeatsTitles.lua, JournalFeatsStats.lua).
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
for _, name in ipairs({ "UnitName", "UnitSex", "date", "GetStatistic" }) do saved[name] = rawget(_G, name) end

local function Reset()
	ResetWorld()
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return nil end
	_G.UnitSex = function() return 2 end
	_G.date = function(format, at)
		if format == "%Y%m%d" then return os.date("!%Y%m%d", at or 0) end
		return format == "%d/%m" and os.date("!%d/%m", at or 0) or os.date("!%d/%m/%Y", at or 0)
	end
	_G.GetStatistic = function() return nil end
	NS.featsDormant = false
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	NS:CompanionData().tutoDone = true
	NS.errors = {}
	if NS.FeatStatsRecordsReset then NS:FeatStatsRecordsReset() end
	Mock:Reset()
end

local function Open(tab)
	NS:HandleCommand("hf")
	local f = NS.journalFrame
	NS:JournalFeatsTab(tab)
	return f
end

local function Errors()
	local out = {}
	for _, e in ipairs(NS.errors or {}) do out[#out + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
	return table.concat(out, " | ")
end

-- 0. les deux vues se branchent ----------------------------------------------------------------------
do
	Say("-- page Hauts faits : onglets Titres et Statistiques")
	Reset()
	local f = Open("titles")
	local s = Steps()
	s.ok("vues déclarées", NS.JOURNAL_FEATS_VIEWS.titles and NS.JOURNAL_FEATS_VIEWS.stats)
	s.ok("Titres : vue montrée, sans erreur", f.feats.views.titles:IsShown() and Errors() == "", Errors())
	NS:JournalFeatsTab("stats")
	s.ok("Statistiques : vue montrée, sans erreur", f.feats.views.stats:IsShown() and Errors() == "", Errors())
	s.check("[JFT] les onglets Titres et Statistiques se dessinent")
	f:Hide()
end

local function ValuesOf(list, field)
	local out = {}
	for _, item in ipairs(list) do out[#out + 1] = item[field] end
	return out
end
local function Has(list, field, value)
	for _, item in ipairs(list) do if item[field] == value then return item end end
	return nil
end
local function TitlesView(f) return f.feats.views.titles end
local function RadioOf(view, value)
	for _, row in ipairs(view.radios) do if row:IsShown() and row.value == value then return row end end
end

-- 1. Titres : compte neuf, choix unique, même source que la fiche ------------------------------------
do
	Say("-- onglet Titres : titre affiché, gagnés, choix")
	Reset()
	local f = Open("titles")
	local view = TitlesView(f)
	local s = Steps()
	local total = 0
	for _ in pairs(NS.FEAT_TITLES) do total = total + 1 end
	s.ok("compte neuf : « Gagnés · 0 sur N » (N : le registre)", view.earnedSec.label:GetText() == Theme.Upper("Gagnés · 0 sur " .. total),
		view.earnedSec.label:GetText())
	s.ok("compte neuf : Automatique et Aucun titre seulement", #view.picks == 2 and view.picks[1].label == "Automatique : le plus haut rang d'espèces"
		and view.picks[2].label == "Aucun titre")
	s.ok("compte neuf : mon nom seul, forme automatique", view.display.name:GetText() == "Testeur" and view.display.form:GetText() == "automatique"
		and view.display.formLabel:GetText() == "Forme :", view.display.name:GetText())
	s.ok("Automatique coché", RadioOf(view, "auto").radio.on and not RadioOf(view, "none").radio.on)
	s.ok("pas de « et k autres » ni de chevrons", view.more:GetText() == "" and not view.pager:IsShown())
	-- des titres gagnés, dont un tour de force
	for _, id in ipairs({ "men_rare_10", "shiny_cap_25", "fos_pioneer", "men_species_10" }) do NS:FeatAward(id, { silent = true }) end
	NS:RefreshJournal()
	s.ok("gagnés : rendus avec mon nom, ordre des codes", #view.picks == 6 and view.picks[3].label == "Apprenti dresseur Testeur"
		and view.picks[4].label == "Testeur le Collectionneur" and view.picks[5].label == "Testeur, Maître des brillantes"
		and view.picks[6].label == "Testeur le Pionnier", table.concat(ValuesOf(view.picks, "label"), " / "))
	s.ok("« Gagnés · 4 sur N »", view.earnedSec.label:GetText() == Theme.Upper("Gagnés · 4 sur " .. total))
	local fos = RadioOf(view, "68")
	s.ok("étiquette TOUR DE FORCE sur le titre du Pionnier seulement", fos and fos.tag:IsShown() and fos.tag.label:GetText() == Theme.Upper("Tour de force")
		and not RadioOf(view, "13").tag:IsShown())
	-- le choix : ns:FeatTitlePick, une seule source de vérité
	RadioOf(view, "13"):Click("LeftButton")
	s.ok("clic : le titre choisi (sauvegarde, sélecteur de la fiche)", NS:FeatTitleChoice() == 13 and NS:FeatTitleOptionValue() == "13"
		and NS:FeatTitleCode() == 13)
	s.ok("clic : coché, en tête, titre affiché", RadioOf(view, "13").radio.on and not RadioOf(view, "auto").radio.on
		and view.display.name:GetText() == "Testeur, Maître des brillantes", view.display.name:GetText())
	NS:FeatSetTitle(7)
	s.ok("choisi ailleurs (/qc titre) : la page suit", RadioOf(view, "7").radio.on and view.display.name:GetText() == "Testeur le Collectionneur")
	RadioOf(view, "none"):Click("LeftButton")
	s.ok("Aucun titre : mon nom seul", NS:FeatTitleChoice() == 0 and view.display.name:GetText() == "Testeur" and RadioOf(view, "none").radio.on)
	RadioOf(view, "auto"):Click("LeftButton")
	s.ok("Automatique : le titre du rang d'espèces", NS:FeatTitleChoice() == nil and RadioOf(view, "auto").radio.on
		and view.display.name:GetText() == NS:FeatTitleText(NS:FeatTitleCode() or 0, "Testeur") or view.display.name:GetText() == "Testeur",
		view.display.name:GetText())
	-- la forme du joueur pour lui-même
	NS:FeatSetTitleForm("f")
	s.ok("forme féminine choisie : titres à cette forme, « féminine, choisie »", view.display.form:GetText() == "féminine, choisie"
		and Has(view.picks, "value", "7").label == "Testeur la Collectionneuse"
		and Has(view.picks, "value", "1").label == "Apprentie dresseuse Testeur", view.display.form:GetText())
	NS:FeatSetTitleForm("auto")
	_G.UnitSex = function() return 3 end
	NS:RefreshJournal()
	s.ok("forme automatique d'un personnage féminin", view.display.form:GetText() == "automatique"
		and Has(view.picks, "value", "7").label == "Testeur la Collectionneuse")
	s.check("[JFT] Titres : compte neuf, gagnés rendus avec mon nom, tour de force, choix unique par FeatTitlePick, forme choisie ou automatique")
	f:Hide()
end

-- 2. Titres : à gagner (secrets, en attente, tours de force), tris, défilement -----------------------
do
	Say("-- onglet Titres : à gagner, tris, molette")
	Reset()
	local f = Open("titles")
	local view = TitlesView(f)
	local s = Steps()
	local togo = view.togoList
	s.ok("à gagner : des lignes, « À gagner · n »", #togo > 6 and view.togoSec.label:GetText() == Theme.Upper("À gagner · " .. #togo))
	s.ok("jamais un titre d'un haut fait en attente (T39, fun_unlucky)", NS:FeatDef("fun_unlucky").pending and not Has(togo, "code", 39))
	s.ok("jamais un tour de force (T68, Pionnier)", not Has(togo, "code", 68))
	local before = Has(togo, "code", 13) ~= nil
	NS:FeatAward("shiny_cap_25", { silent = true })
	NS:RefreshJournal()
	togo = view.togoList
	s.ok("gagné : il sort d'« À gagner »", before and not Has(togo, "code", 13) and Has(view.picks, "value", "13") ~= nil)
	local row = Has(togo, "code", 66)
	s.ok("ligne : titre avec mon nom, « <haut fait> : <condition> »", row and row.label == "Testeur le Marchand"
		and row.line == NS:FeatName("soc_trade_25") .. " : " .. FP.LowerFirst(NS:FeatDescription("soc_trade_25")), row and row.line)
	-- un secret pas découvert : absent ; découvert puis obtenu : gagné
	local def = NS:FeatDef("soc_trade_25")
	def.hidden = true
	s.ok("secret non découvert : absent d'« À gagner »", not Has(NS:FeatTitlesToGo("near"), "code", 66))
	def.hidden = nil
	def.pending = true
	s.ok("haut fait en attente : absent", not Has(NS:FeatTitlesToGo("near"), "code", 66))
	def.pending = nil
	-- tri : les plus proches (ratio décroissant), par catégorie (ordre du catalogue)
	NS:FeatStore("account").ctr.trades = 20
	NS:RefreshJournal()
	togo = view.togoList
	local sorted = true
	for i = 2, #togo do if togo[i].ratio > togo[i - 1].ratio then sorted = false end end
	s.ok("les plus proches d'abord", sorted and togo[1].code == 66 and view.togo[1].count:GetText() == "20 / 25", view.togo[1].count:GetText())
	view.sorts.byId.cat:Click("LeftButton")
	togo = view.togoList
	local bycat = f.featsTitleSort == "cat"
	for i = 2, #togo do if togo[i].pos < togo[i - 1].pos then bycat = false end end
	s.ok("par catégorie : l'ordre du catalogue", bycat and view.sorts.selected == "cat")
	view.sorts.byId.near:Click("LeftButton")
	-- molette : à droite par défaut
	s.ok("position « 1 à 6 sur n »", view.position:GetText() == "1 à 6 sur " .. #view.togoList, view.position:GetText())
	NS:ScrollJournal(-1)
	s.ok("molette (droite) : une ligne", f.featsTogoOffset == 1 and view.position:GetText() == "2 à 7 sur " .. #view.togoList
		and view.togo[1].code == view.togoList[2].code)
	NS:ScrollJournal(-999)
	s.ok("molette bornée en bas", f.featsTogoOffset == #view.togoList - 6)
	-- à gauche : plus de dix choix, molette sur la colonne, chevrons
	for _, id in ipairs({ "men_rare_10", "shiny_cap_25", "fos_pioneer", "men_species_10", "men_species_25", "men_species_50",
		"men_species_100", "men_species_250", "shiny_found_50", "zone_all_biomes", "char_level_60", "men_bad_luck" }) do
		NS:FeatAward(id, { silent = true })
	end
	NS:RefreshJournal()
	local hidden = #view.picks - 10
	s.ok("plus de dix : « et k autres : molette ou chevrons », chevrons", hidden > 1 and view.more:GetText() == "et " .. hidden .. " autres : molette ou chevrons"
		and view.pager:IsShown() and view.pager.down:IsShown() and not view.pager.up:IsShown(), view.more:GetText())
	view.left.IsMouseOver = function() return true end
	local right = f.featsTogoOffset
	NS:ScrollJournal(-1)
	s.ok("molette sur la colonne de gauche : la liste des gagnés", f.featsTitleOffset == 1 and f.featsTogoOffset == right
		and view.radios[1].value == view.picks[2].value)
	view.left.IsMouseOver = nil
	view.pager.up:Click("LeftButton")
	s.ok("chevron haut", f.featsTitleOffset == 0 and view.radios[1].value == "auto")
	view.pager.down:Click("LeftButton")
	s.ok("chevron bas", f.featsTitleOffset == 1)
	-- clic sur une ligne à gagner : le haut fait déplié
	f.featsTogoOffset = 0
	NS:RefreshJournal()
	local id = view.togo[1].def.id
	view.togo[1]:Click("LeftButton")
	s.ok("clic : le haut fait, déplié dans sa catégorie", f.featsTab == NS:FeatCategory(NS:FeatDef(id).cat).family and f.featsOpen ~= nil)
	s.check("[JFT] Titres : à gagner sans secret, en attente ni tour de force ; tris ; molette des deux listes, chevrons ; clic")
	f:Hide()
end

-- 3. Titres : rien de calculé onglet fermé, rien à la molette ------------------------------------------
do
	Say("-- onglet Titres : coût")
	Reset()
	local calls = 0
	local base = NS.FeatTitlesToGo
	NS.FeatTitlesToGo = function(...) calls = calls + 1; return base(...) end
	local f = Open("overview")
	NS:FeatAward("men_rare_10", { silent = true })
	NS:RefreshJournal()
	local closed = calls
	NS:JournalFeatsTab("titles")
	local opened = calls
	NS:ScrollJournal(-1); NS:ScrollJournal(-1)
	Mock:Advance(5)
	local after = calls
	NS.FeatTitlesToGo = base
	Check("[JFT] Titres : rien calculé onglet fermé, une passe à l'ouverture, rien à la molette ni par image",
		closed == 0 and opened == 1 and after == 1, closed .. "/" .. opened .. "/" .. after)
	f:Hide()
end

-- 4. Statistiques : ns:FeatStatsBlocks (forme figée), valeurs ------------------------------------------
local BLOCKS = {
	{ "captures", "Captures", { "caught", "throws", "success", "streak", "hunt" } },
	{ "collection", "Collection", { "species", "stars3", "mastered", "zones", "seals" } },
	{ "shinies", "Brillantes", { "shinySeen", "shinyFound", "shinyCap", "shinyChain", "shinyDay" } },
	{ "specimens", "Spécimens", { "biggest", "smallest", "mostCaught", "bond5", "nicks" } },
	{ "companion", "Compagnon", { "km", "days", "radiant", "wishes", "treats" } },
	{ "shop", "Réserve et Échoppe", { "glitter", "glitterSpent", "release", "orders", "trades" } },
}
local FRESH = { streak = true, hunt = true, shinyChain = true, radiant = true, wishes = true, treats = true,
	glitterSpent = true, release = true, orders = true }
local function Row(blocks, key)
	for _, block in ipairs(blocks) do for _, row in ipairs(block.rows) do if row.key == key then return row end end end
end

do
	Say("-- onglet Statistiques : blocs, valeurs")
	Reset()
	local s = Steps()
	local blocks = NS:FeatStatsBlocks()
	s.ok("six blocs dans l'ordre de l'écran", #blocks == 6)
	for i, spec in ipairs(BLOCKS) do
		local block = blocks[i] or {}
		s.ok("bloc " .. spec[1], block.key == spec[1] and block.title == spec[2] and type(block.rows) == "table" and #block.rows == 5, block.key)
		for r, key in ipairs(spec[3]) do
			local row = block.rows and block.rows[r] or {}
			s.ok("ligne " .. key, row.key == key and type(row.label) == "string" and row.label ~= "" and type(row.value) == "string"
				and row.value ~= "" and row.fresh == (FRESH[key] == true), row.key)
		end
	end
	s.ok("libellés de la maquette", Row(blocks, "throws").label == "Lancers de filet" and Row(blocks, "shinyDay").label == "Deux le même jour"
		and Row(blocks, "mostCaught").label == "Espèce la plus capturée" and Row(blocks, "radiant").label == "Temps Rayonnant")
	-- compte neuf : « — » pour l'inconnu, jamais un 0 trompeur
	for _, key in ipairs({ "success", "streak", "shinyChain", "shinyDay", "biggest", "smallest", "mostCaught" }) do
		s.ok("compte neuf : " .. key .. " « — »", Row(blocks, key).value == "—", Row(blocks, key).value)
	end
	s.ok("compte neuf : un compteur à zéro reste 0 (point bleu, légende)", Row(blocks, "release").value == "0" and Row(blocks, "caught").value == "0")
	s.check("[JFT] ns:FeatStatsBlocks : six blocs, cinq lignes { key, label, value, fresh }, ordre de l'écran ; compte neuf : « — » pour l'inconnu")

	-- une collection en cours
	local s2 = Steps()
	local data = NS:CaptureData()
	data.caught, data.tries, data.paillettesEarned = 1412, 2655, 6240
	data.studyV = NS.STUDY_SCHEMA
	data.study = { [90001] = { n = 37, z = 0, t = 0, paid = 0, lo = 88, hi = 124 }, [90002] = { n = 12, z = 0, t = 0, paid = 0, lo = 76, hi = 101 } }
	data.creatures[90001] = { name = "Raptor de Strangleronce", normal = true }
	data.creatures[90002] = { name = "Lapin", normal = true }
	data.specimens = data.specimens or {}
	data.specimens.t1 = { npc = 90001, shiny = true, at = 1794700000, origin = "capture" }
	data.specimens.t2 = { npc = 90002, shiny = true, at = 1794700000 + 60, origin = "capture" }
	data.specSerial = (tonumber(data.specSerial) or 0) + 1
	NS:CompanionData().travel = 412500
	NS:TallyAdd("captureHunt", 640); NS:TallyAdd("glitterSpent", 1180); NS:TallyAdd("release", 212); NS:TallyAdd("orderDone", 8)
	NS:TallyMax("captureStreak", 17); NS:TallyMax("shinyChain", 50)
	NS:TallyAdd("radiantMin", 560, "char"); NS:TallyAdd("wish", 23, "char"); NS:TallyAdd("treat", 61, "char")
	NS:FeatStore("account").ctr.trades = 3
	blocks = NS:FeatStatsBlocks()
	local V = function(key) return Row(blocks, key).value end
	s2.ok("prises, lancers (sauvegarde), réussite 53 %", V("throws") == "2 655" and V("success") == "53 %" and V("caught") == FP.Num(NS.FEAT_SOURCES.caught.get(NS)),
		V("caught") .. " " .. V("success"))
	s2.ok("séries (compteurs)", V("streak") == "17" and V("hunt") == "640" and V("shinyChain") == "50 sur 50")
	s2.ok("records de spécimens : nom (indice), espèce la plus capturée", V("biggest") == "Raptor de Strangleronce (124)"
		and V("smallest") == "Lapin (76)" and V("mostCaught") == "Raptor de Strangleronce (37)", V("biggest"))
	s2.ok("deux brillantes le même jour : la date du jour", V("shinyDay") == "le " .. os.date("!%d/%m", 1794700000), V("shinyDay"))
	s2.ok("compagnon : km, temps Rayonnant 9 h 20, envies, friandises", V("km") == "412" and V("radiant") == "9 h 20" and V("wishes") == "23"
		and V("treats") == "61", V("radiant"))
	s2.ok("réserve : paillettes, relâchers, commandes, échanges", V("glitter") == "6 240" and V("glitterSpent") == "1 180" and V("release") == "212"
		and V("orders") == "8" and V("trades") == "3")
	s2.ok("espèces : le nombre (sur le total de la faction s'il est connu)", V("species"):find("^" .. FP.Num(NS.FEAT_SOURCES.species.get(NS, "account"))) ~= nil, V("species"))
	-- sans Tally.lua : « — » pour tout ce qui en vient
	local saveGet, saveBest = NS.TallyGet, NS.TallyBest
	NS.TallyGet, NS.TallyBest = nil, nil
	blocks = NS:FeatStatsBlocks()
	local all = true
	for key in pairs(FRESH) do if Row(blocks, key).value ~= "—" then all = false end end
	NS.TallyGet, NS.TallyBest = saveGet, saveBest
	s2.ok("Tally.lua absent : « — » sur chaque ligne au point bleu", all)
	s2.check("[JFT] Statistiques : valeurs de la sauvegarde et des compteurs, réussite, records, date, durée ; sans compteurs : « — »")
end

-- 5. Statistiques : l'écran, le point bleu, la légende, Copier pour Discord, coût ----------------------
do
	Say("-- onglet Statistiques : écran, coût")
	Reset()
	local calls = 0
	local base = NS.FeatStatsBlocks
	NS.FeatStatsBlocks = function(...) calls = calls + 1; return base(...) end
	local f = Open("titles")
	NS:RefreshJournal()
	local closed = calls
	NS:JournalFeatsTab("stats")
	local opened = calls
	NS:ScrollJournal(-1)
	Mock:Advance(5)
	local after = calls
	local view = f.feats.views.stats
	local s = Steps()
	s.ok("coût : rien onglet fermé, une passe à l'ouverture, rien à la molette", closed == 0 and opened == 1 and after == 1,
		closed .. "/" .. opened .. "/" .. after)
	local blocks = view.blocks
	local same, dots = true, true
	for i, tile in ipairs(view.tiles) do
		if tile.section.label:GetText() ~= Theme.Upper(blocks[i].title) then same = false end
		for r, row in ipairs(tile.rows) do
			local item = blocks[i].rows[r]
			if row.label:GetText() ~= item.label or row.value:GetText() ~= item.value then same = false end
			if row.dot:IsShown() ~= item.fresh then dots = false end
		end
	end
	s.ok("l'écran est dessiné depuis ns:FeatStatsBlocks", same)
	s.ok("point bleu après le libellé, seulement sur ce qui vient de Tally.lua", dots)
	s.ok("légende", view.legend:GetText() == "compté depuis la 3.7 : rien n'était noté avant" and view.legendDot:IsShown(), tostring(view.legend:GetText()) .. "/" .. tostring(view.legendDot:IsShown()))
	-- sans la copie pour Discord (DiscordCopy.lua) : pas de bouton ; avec : le bouton, et le clic
	-- compose le texte des statistiques (ns:DiscordText("stats"), fait de ns:FeatStatsBlocks)
	local realShow = NS.DiscordCopyShow
	NS.DiscordCopyShow = nil
	NS:RefreshJournal()
	s.ok("pas de « Copier pour Discord » sans ns.DiscordCopyShow", not view.copy:IsShown())
	local got
	NS.DiscordCopyShow = function(text) got = text end
	NS:RefreshJournal()
	s.ok("ns.DiscordCopyShow présente : le bouton", view.copy:IsShown() and view.copy:GetText() == "Copier pour Discord")
	view.copy:Click("LeftButton")
	s.ok("clic : le texte des statistiques, prêt à copier", type(got) == "string" and got:find("curseforge.com", 1, true) ~= nil
		and got:find("**", 1, true) ~= nil, tostring(got))
	NS.DiscordCopyShow = realShow
	NS.FeatStatsBlocks = base
	s.check("[JFT] Statistiques : écran depuis FeatStatsBlocks, point bleu, légende, bouton Discord seulement s'il existe, coût")
	f:Hide()
end

-- 6. Contrastes sur le vrai fond, textes, code ---------------------------------------------------------
do
	Say("-- onglets Titres et Statistiques : contrastes, textes, code")
	local s = Steps()
	local tile = { Theme.ROW, Theme.ROW_ALT, Theme.Over(Theme.ROW, Theme.WHITE, (Theme.FORGE_CARD or {}).light or 0.045),
		Theme.Over(Theme.ROW, Theme.WHITE, Theme.HOVER_ALPHA) }
	local window = { Theme.WINDOW, Theme.Over(Theme.WINDOW, Theme.WHITE, (Theme.FORGE_CARD or {}).light or 0.045) }
	local low = {}
	local function Min(ink, list) local m = 99; for _, bg in ipairs(list) do m = math.min(m, Theme.Contrast(ink, bg)) end return m end
	local tagBg = {}
	for _, bg in ipairs(window) do tagBg[#tagBg + 1] = Theme.Over(bg, Theme.GOLD_LIGHT, 0.16) end
	for _, item in ipairs({
		{ "titre affiché (or clair, tuile)", Theme.GOLD_LIGHT, tile, 3 }, { "forme (tuile)", Theme.LABEL, tile, 4.5 },
		{ "« Forme : » (tuile)", Theme.MUTED_LIGHT, tile, 4.5 },
		{ "choix coché (fenêtre)", Theme.PARCHMENT, window, 4.5 }, { "choix (fenêtre)", Theme.TEXT, window, 4.5 },
		{ "« et k autres », position (fenêtre)", Theme.MUTED_LIGHT, window, 4.5 }, { "aucun titre à gagner (fenêtre)", Theme.MUTED, window, 4.5 },
		{ "titre à gagner (tuile)", FP.TogoInk(), tile, 4.5 }, { "haut fait et condition, compte (tuile)", Theme.MUTED_LIGHT, tile, 4.5 },
		{ "étiquette TOUR DE FORCE", Theme.GOLD_LIGHT, tagBg, 4.5 },
		{ "statistique : libellé (tuile)", Theme.MUTED_LIGHT, tile, 4.5 }, { "statistique : valeur (tuile)", Theme.LABEL, tile, 4.5 },
		{ "légende (fenêtre)", Theme.MUTED, window, 4.5 }, { "titre de bloc (arcane, tuile)", Theme.ARCANE_LIGHT, tile, 3 },
		{ "titre de section (identité, fenêtre)", Theme.IDENTITY_LIGHT, window, 3 },
	}) do
		local c = Min(item[2], item[3])
		low[#low + 1] = string.format("%s %.2f", item[1], c)
		s.ok(item[1] .. " ≥ " .. item[4], c >= item[4], string.format("%.2f", c))
	end
	NS.journalFeatsTabsContrasts = low
	s.check("[JFT] contrastes mesurés sur le vrai fond (tuiles, fenêtre, étiquette) : ≥ 4,5 texte, ≥ 3 titres : " .. table.concat(low, " ; "))
	-- textes : français et anglais, aucune clé brute, aucun glyphe
	local s2 = Steps()
	for _, pair in ipairs({ NS.JOURNAL_FEATS_TITLES_STRINGS, NS.JOURNAL_FEATS_STATS_STRINGS }) do
		s2.ok("textes gardés", pair ~= nil)
		for key in pairs(pair and pair.fr or {}) do s2.ok("anglais de " .. key, pair.en[key] ~= nil) end
		for key, text in pairs(pair and pair.en or {}) do
			s2.ok("français de " .. key, pair.fr[key] ~= nil)
			for _, glyph in ipairs({ "★", "☆", "✓", "✗" }) do
				s2.ok("glyphe " .. glyph .. " dans " .. key, not tostring(text):find(glyph, 1, true) and not tostring(pair.fr[key] or ""):find(glyph, 1, true))
			end
		end
	end
	Reset()
	local f = Open("titles")
	local raw = {}
	local function Scan()
		for _, region in ipairs(Mock.frames) do
			local text = region.kind == "FontString" and region:IsShown() ~= false and region.text
			if type(text) == "string" and (text:match("^FEAT[A-Z]*_") or text:find("%%[sd]")) then raw[#raw + 1] = text end
		end
	end
	Scan()
	NS:JournalFeatsTab("stats"); Scan()
	s2.ok("aucune clé brute ni code de format à l'écran", #raw == 0, table.concat(raw, " | "))
	s2.check("[JFT] textes : français et anglais, aucune clé brute à l'écran, aucun glyphe ★ ☆ ✓ ✗")
	f:Hide()
	-- code : aucune couleur codée en dur, aucun glyphe
	local s3 = Steps()
	for _, file in ipairs({ "QuestCompanion/JournalFeatsTitles.lua", "QuestCompanion/JournalFeatsStats.lua" }) do
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
	s3.check("[JFT] code : couleurs par les jetons du thème seulement, aucun glyphe")
end

for name, fn in pairs(saved) do _G[name] = fn end
