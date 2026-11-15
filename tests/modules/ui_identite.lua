-- Identité et sélection du thème forgé (socle 3.3). Chaque addon déclare son
-- identité (ns.APP.identity, Config.lua) : Ready2Quest l'or (sélection bleu
-- arcane : ses valeurs d'avant, au chiffre près), QuestCompanion le bleu
-- arcane (sélection or). Rôles changés sur place par Theme.ApplySkin, aucune
-- table partagée, retour exact en Sobre, identité inconnue = or ; briques de
-- QuestCompanion aux tons inversés ; contrastes mesurés des nouvelles paires
-- (encre sur son vrai fond : plaque, dégradé, pilule).
local Check, Say, NS, QNS = T.Check, T.Say, T.NS, T.QNS
local R, Q = NS.Theme, QNS.Theme
local SKIN0 = { NS.Theme.skin, QNS.Theme.skin }

local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for i = 1, 3 do if math.abs((a[i] or -1) - (b[i] or -2)) > 1e-6 then return false end end
	return true
end
local function Copy(c) return { c[1], c[2], c[3] } end
local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
		return cond
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end
local function SliceColor(slice) return slice and slice.parts and slice.parts.c and slice.parts.c.vertex end
local function Spec(tex) return tex and tex.gradientSpec end

-- valeurs d'avant le socle 3.3 (thème forgé de Ready2Quest), en dur : la référence
local GOLD, GOLD_LIGHT = { 0.91, 0.65, 0.29 }, { 0.96, 0.78, 0.49 }
local BLUE, ARCANE_LIGHT = { 0.357, 0.561, 0.839 }, { 0.561, 0.722, 0.941 }
local PARCHMENT = { 0.95, 0.91, 0.83 }
local WARM, ARCANE_PLATE = { 0.235, 0.165, 0.086 }, { 0.210, 0.350, 0.560 }
local ROLES = { "IDENTITY", "IDENTITY_LIGHT", "SELECT", "SELECT_LIGHT", "TITLE", "ACTIVE" }

do
	Say("-- identité : déclarée par chaque addon, rôles selon l'identité")
	local s = Steps()
	s.ok("Ready2Quest : or ; QuestCompanion : arcane", NS.APP.identity == "gold" and QNS.APP.identity == "arcane"
		and R.IdentityChoice() == "gold" and Q.IdentityChoice() == "arcane")
	s.ok("chaque addon a sa table de thème", R ~= Q and R.IDENTITY ~= Q.IDENTITY)
	R.ApplySkin("azeroth"); Q.ApplySkin("azeroth")
	s.ok("Ready2Quest forgé : identité or, sélection bleu arcane, titres or clair, actif arcane",
		Same(R.IDENTITY, GOLD) and Same(R.IDENTITY_LIGHT, GOLD_LIGHT) and Same(R.SELECT, BLUE) and Same(R.SELECT_LIGHT, ARCANE_LIGHT)
		and Same(R.TITLE, GOLD_LIGHT) and Same(R.ACTIVE, BLUE) and R.identity == "gold")
	s.ok("Ready2Quest forgé : plaque d'en-tête chaude, liste ouverte arcane, curseur arcane, action arcane, voile entier",
		Same(R.FORGE_HEADER.warm, WARM) and Same(R.FORGE_PLATE.select, ARCANE_PLATE) and Same(R.FORGE_PLATE.thumbOn, BLUE)
		and R.FORGE_BUTTONS.arcane.plate == "arcane" and R.FORGE_BUTTONS.arcane.text == R.FORGE_INK.arcane and R.SELECT_ALPHA == 1)
	s.ok("Ready2Quest forgé : tons identity = or, second = arcane ; anciens noms gold / arcane",
		R.ResolveTone() == R.FORGE_TONES.identity and R.ResolveTone("gold") == R.FORGE_TONES.identity
		and R.ResolveTone("arcane") == R.FORGE_TONES.second and select(2, R.ResolveTone("rose")) == "identity"
		and Same(R.FORGE_TONES.identity.light, GOLD_LIGHT) and Same(R.FORGE_TONES.second.light, ARCANE_LIGHT))
	s.ok("QuestCompanion forgé : identité bleu arcane, sélection or, actif or, titres arcane très clair",
		Same(Q.IDENTITY, BLUE) and Same(Q.IDENTITY_LIGHT, ARCANE_LIGHT) and Same(Q.SELECT, GOLD) and Same(Q.SELECT_LIGHT, GOLD_LIGHT)
		and Same(Q.ACTIVE, GOLD) and Same(Q.TITLE, Q.IDENTITY_TOKENS.arcane.TITLE) and Q.identity == "arcane")
	s.ok("QuestCompanion forgé : plaque d'en-tête froide, liste ouverte bronze, curseur or, action en plaque neutre",
		Same(Q.FORGE_HEADER.warm, Q.IDENTITY_TOKENS.arcane["FORGE_HEADER.warm"]) and Q.FORGE_HEADER.warm[3] > Q.FORGE_HEADER.warm[1]
		and Same(Q.FORGE_PLATE.select, Q.FORGE_PLATE.bronze) and Same(Q.FORGE_PLATE.thumbOn, GOLD)
		and Q.FORGE_BUTTONS.arcane.plate == "neutral" and Q.FORGE_BUTTONS.arcane.text == Q.LABEL and Q.SELECT_ALPHA < 1)
	s.ok("QuestCompanion forgé : ton par défaut arcane, second ton or",
		Same(Q.ResolveTone().color, BLUE) and Same(Q.ResolveTone("second").color, GOLD) and Same(Q.ResolveTone("arcane").light, GOLD_LIGHT))
	s.ok("la famille commune ne bouge pas : or, bleu, arcane clair, bord, plaques d'action",
		Same(Q.GOLD, GOLD) and Same(Q.GOLD_LIGHT, GOLD_LIGHT) and Same(Q.BLUE, BLUE) and Same(Q.ARCANE_LIGHT, ARCANE_LIGHT)
		and Same(Q.EDGE, R.EDGE) and Same(Q.FORGE_PLATE.gold, R.FORGE_PLATE.gold) and Same(Q.FORGE_PLATE.arcane, ARCANE_PLATE)
		and Q.FORGE_BUTTONS.primary.plate == "gold")
	s.ok("Ready2Quest ne suit pas QuestCompanion (thèmes séparés)", Same(R.TITLE, GOLD_LIGHT) and Same(R.ACTIVE, BLUE))
	-- aucune table partagée : un rôle muté ne contamine ni un autre rôle ni la palette
	local tables, shared = {}, nil
	for _, key in ipairs(ROLES) do
		if tables[Q[key]] then shared = key end
		tables[Q[key]] = true
	end
	for _, key in ipairs({ "GOLD", "GOLD_LIGHT", "BLUE", "ARCANE_LIGHT", "PARCHMENT", "ORANGE" }) do
		if tables[Q[key]] then shared = key end
	end
	if Q.FORGE_PLATE.select == Q.FORGE_PLATE.bronze or Q.FORGE_PLATE.select == Q.FORGE_PLATE.arcane
		or Q.FORGE_PLATE.thumbOn == Q.GOLD then shared = "FORGE_PLATE" end
	s.ok("aucune table partagée entre rôles, palette et plaques", shared == nil, shared)
	s.check("[IDENT] rôles : Ready2Quest inchangé (or / arcane), QuestCompanion inversé (arcane / or)")
end

do
	Say("-- identité : inconnue = or, Sobre inchangé, aller-retour")
	local s = Steps()
	local keep = QNS.APP.identity
	for _, id in ipairs({ "rose", false, "gold" }) do
		QNS.APP.identity = id or nil
		Q.ApplySkin("azeroth")
		s.ok("identité " .. tostring(id) .. " : l'or", Q.IdentityChoice() == "gold" and Same(Q.IDENTITY, GOLD)
			and Same(Q.SELECT, BLUE) and Same(Q.TITLE, GOLD_LIGHT) and Q.FORGE_BUTTONS.arcane.plate == "arcane")
	end
	QNS.APP.identity = keep
	-- Sobre : les valeurs de départ, pour les deux addons
	for name, T in pairs({ r2q = R, qc = Q }) do
		local refs = {}
		for _, key in ipairs(ROLES) do refs[key] = T[key] end
		local warm, select = T.FORGE_HEADER.warm, T.FORGE_PLATE.select
		T.ApplySkin("sobre")
		s.ok(name .. " Sobre : titres parchemin, actif ambre, rôles à l'ambre", Same(T.TITLE, PARCHMENT) and Same(T.ACTIVE, GOLD)
			and Same(T.IDENTITY, GOLD) and Same(T.IDENTITY_LIGHT, GOLD_LIGHT) and Same(T.SELECT, GOLD) and Same(T.SELECT_LIGHT, GOLD_LIGHT)
			and T.identity == nil)
		s.ok(name .. " Sobre : plaques et style d'action d'origine, voile entier", Same(T.FORGE_HEADER.warm, WARM)
			and Same(T.FORGE_PLATE.select, ARCANE_PLATE) and Same(T.FORGE_PLATE.thumbOn, BLUE) and T.SELECT_ALPHA == 1
			and T.FORGE_BUTTONS.arcane.plate == "arcane" and T.FORGE_BUTTONS.arcane.text == T.FORGE_INK.arcane)
		local before = {}
		for _, key in ipairs(ROLES) do before[key] = Copy(T[key]) end
		T.ApplySkin("azeroth"); T.ApplySkin("sobre"); T.ApplySkin("azeroth"); T.ApplySkin("sobre")
		local same, kept = true, true
		for _, key in ipairs(ROLES) do
			if not Same(T[key], before[key]) then same = false end
			if T[key] ~= refs[key] then kept = false end
		end
		s.ok(name .. " aller-retour Sobre / Azeroth : mêmes valeurs, mêmes tables", same and kept
			and T.FORGE_HEADER.warm == warm and T.FORGE_PLATE.select == select)
		T.ApplySkin("azeroth")
	end
	s.ok("après les allers-retours : QuestCompanion inversé, Ready2Quest d'avant", Same(Q.TITLE, Q.IDENTITY_TOKENS.arcane.TITLE)
		and Same(Q.ACTIVE, GOLD) and Same(R.TITLE, GOLD_LIGHT) and Same(R.ACTIVE, BLUE) and Same(R.FORGE_HEADER.warm, WARM))
	s.check("[IDENT] identité inconnue = or ; Sobre d'origine dans les deux addons ; allers-retours exacts")
end

do
	Say("-- identité : briques de QuestCompanion aux tons inversés")
	Q.ApplySkin("azeroth")
	local s = Steps()
	local host = CreateFrame("Frame", nil, UIParent)
	host:SetSize(600, 400)
	local group = Q.CreateNavGroup(host, "Compagnon de route")
	local second = Q.CreateNavGroup(host, "Au jour le jour", "second")
	s.ok("pilule par défaut : bleu arcane, encre arcane clair", Same(Spec(group.forgePill)[2], BLUE)
		and Same(group.textColor, ARCANE_LIGHT) and group.tone == "identity")
	s.ok("pilule au second ton : or, encre or clair", Same(Spec(second.forgePill)[2], GOLD) and Same(second.textColor, GOLD_LIGHT))
	local section = Q.CreateSection(host, "Réglages")
	s.ok("section : point, titre et filet arcane clair", Same(section.forgeDot.vertex, ARCANE_LIGHT)
		and Same(section.label.textColor, ARCANE_LIGHT) and Same(section.forgeLine.vertex, ARCANE_LIGHT))
	local rule = Q.CreateGlowRule(host, 2)
	s.ok("filet lumineux : arcane clair", Same(rule.segments[1].vertex, ARCANE_LIGHT))
	local header = Q.CreatePageHeader(host, 600)
	s.ok("en-tête : plaque froide, lueurs arcane, titre arcane très clair",
		Same(Spec(header.plate)[4], Q.FORGE_HEADER.warm) and Same(Spec(header.topGlow)[2], BLUE)
		and Same(Spec(header.cornerGlow)[2], BLUE) and Same(header.title.textColor, Q.TITLE))
	local brand = Q.CreateNavBrand(host, Q.LOGO, "QuestCompanion")
	s.ok("marque : nom arcane très clair, filet arcane clair", Same(brand.name.textColor, Q.TITLE) and Same(brand.rule.vertex, ARCANE_LIGHT))
	local item = Q.CreateNavItem(host, 200)
	item:SetSelected(true)
	local K = Q.FORGE_NAV
	local ts = Spec(item.tint)
	s.ok("entrée choisie : dégradé or (voile allégé), barre or clair", Same(ts[2], GOLD)
		and math.abs(ts[3] - K.select.from * Q.SELECT_ALPHA) < 1e-9 and Same(item.bar.vertex, GOLD_LIGHT))
	local tabs = Q.CreateTabs(host)
	tabs:SetTabs({ { id = "a", label = "Créatures" }, { id = "b", label = "Réserve" } })
	s.ok("onglet choisi : dégradé or, souligné or clair", Same(Spec(tabs.tabs[1].forgeGlow)[2], GOLD)
		and Same(tabs.tabs[1].underline.vertex, GOLD_LIGHT))
	local row = Q.CreateListRow(host, 300, 26)
	row:SetSelected(true)
	s.ok("ligne choisie : dégradé or, barre or clair", Same(Spec(row.forgeTint)[2], GOLD) and Same(row.forgeBar.vertex, GOLD_LIGHT))
	local chips = Q.CreateChips(host, { { id = "a", label = "Toutes" }, { id = "b", label = "Brillantes" } })
	s.ok("puce choisie : dégradé or, filet or clair", Same(Spec(chips.byId.a.bg)[2], GOLD)
		and Same(chips.byId.a.border.top.vertex, GOLD_LIGHT))
	local toggle = Q.CreateToggle(host)
	toggle:SetChecked(true)
	s.ok("interrupteur actif : filet et curseur or", Same(SliceColor(toggle.inset), GOLD) and Same(SliceColor(toggle.thumb), GOLD))
	toggle:SetPartial()
	s.ok("interrupteur partiel : filet de l'identité (arcane), distinct de l'actif", Same(SliceColor(toggle.inset), BLUE))
	local action = Q.CreateButton(host, 90, 22, "Changer", nil, "arcane")
	local primary = Q.CreateButton(host, 90, 28, "Terminé", nil, "primary")
	local accent = Q.CreateButton(host, 90, 28, "Porter", nil, "accent")
	s.ok("bouton « arcane » : plaque neutre, libellé clair ; principal or ; accent bronze",
		Same(SliceColor(action.plate), Q.FORGE_PLATE.neutral) and Same(action.text.textColor, Q.LABEL)
		and Same(SliceColor(primary.plate), Q.FORGE_PLATE.gold) and Same(SliceColor(accent.plate), Q.FORGE_PLATE.bronze))
	local box = Q.CreateSearchBox(host, 180, "Rechercher")
	box.scripts.OnEditFocusGained(box)
	s.ok("recherche : filet or au focus", Same(SliceColor(box.inset), GOLD))
	local dd = Q.CreateDropdown(host, 160)
	dd:SetOptions({ { value = 1, label = "Un" }, { value = 2, label = "Deux" } })
	dd:Open()
	s.ok("liste ouverte : plaque bronze ; survol d'une ligne : or (voile allégé)", Same(SliceColor(dd.plate), Q.FORGE_PLATE.bronze)
		and Same(Spec(dd.list.rows[1].hover)[2], GOLD)
		and math.abs(Spec(dd.list.rows[1].hover)[3] - Q.FORGE.rowSelect * Q.SELECT_ALPHA) < 1e-9)
	dd:Close()
	s.ok("blocs de QuestCompanion : titre et filet de l'identité", QNS.QC_FORGE.title == Q.TITLE and QNS.QC_FORGE.glow == Q.IDENTITY
		and QNS.QC_FORGE.rimOn == Q.SELECT_LIGHT)
	local line = QNS.QCForgeLine(host)
	s.ok("filet d'un bloc (QCForgeLine) : bleu arcane", line and Same(line.vertex, BLUE))
	s.check("[IDENT] QuestCompanion : identité arcane (titres, pilules, sections, filets, en-tête), sélection or, action neutre")
	host:Hide()
end

do
	Say("-- identité : contrastes des nouvelles paires (QuestCompanion)")
	Q.ApplySkin("azeroth")
	local C, Over = Q.Contrast, Q.Over
	local black, white = Q.SHADOW, Q.WHITE
	local K, B = Q.FORGE_NAV, Q.FORGE_ROW
	local a = Q.SELECT_ALPHA
	local worst, where = math.huge, ""
	local function Pair(name, ink, backs, need)
		for _, bg in ipairs(backs) do
			local ratio = C(ink, bg)
			if ratio - need < worst then worst, where = ratio - need, string.format("%s %.2f", name, ratio) end
		end
	end
	local navLeft, navRight = Over(Q.NAV, black, K.shade.from), Over(Q.NAV, black, K.shade.to)
	-- titres de groupe sur leur pilule (bord gauche plus sombre, bord droit)
	local pillArc = { Over(navLeft, Q.IDENTITY, K.pill.from), Over(navRight, Q.IDENTITY, K.pill.from) }
	local pillGold = { Over(navLeft, Q.SELECT, K.pill.from), Over(navRight, Q.SELECT, K.pill.from) }
	Pair("titre de groupe arcane clair / pilule arcane", Q.IDENTITY_LIGHT, pillArc, 4.5)
	Pair("titre de groupe or clair / pilule or", Q.SELECT_LIGHT, pillGold, 4.5)
	Pair("groupe d'un module coupé / pilule arcane", K.offInk, pillArc, 4.5)
	Pair("groupe d'un module coupé / pilule or", K.offInk, pillGold, 4.5)
	-- en-tête : plaque froide, lueurs de l'identité (haut + coin)
	local headerTop = Over(Over(Q.WINDOW, Q.FORGE_HEADER.warm, Q.FORGE_HEADER.top), Q.IDENTITY, 0.11)
	local headerBottom = Over(Q.WINDOW, Q.NAV, 1 - Q.FORGE_HEADER.bottom)
	Pair("titre arcane très clair / plaque d'en-tête froide", Q.TITLE, { headerTop, headerBottom }, 3)
	Pair("sous-titre / plaque d'en-tête froide", Q.MUTED_LIGHT, { headerTop, headerBottom }, 4.5)
	Pair("marque / colonne", Q.TITLE, { Q.NAV, navLeft }, 3)
	Pair("section arcane clair / fenêtre", Q.IDENTITY_LIGHT, { Q.WINDOW, Q.NAV }, 4.5)
	-- sélection or : libellés sur les dégradés (le point le plus clair)
	Pair("entrée choisie : parchemin / dégradé or", Q.PARCHMENT,
		{ Over(navLeft, Q.SELECT, K.select.from * a), Over(navRight, Q.SELECT, K.select.to * a) }, 4.5)
	Pair("onglet choisi : parchemin / dégradé or", Q.PARCHMENT, { Over(Q.WINDOW, Q.SELECT, Q.FORGE_TABS.from * a) }, 4.5)
	Pair("puce choisie : parchemin / dégradé or", Q.PARCHMENT, { Over(Q.WINDOW, Q.SELECT, Q.FORGE_CHIP.from * a) }, 4.5)
	local rowSel = Over(Q.ROW_ALT, Q.SELECT, B.select.from * a)
	Pair("ligne choisie : texte / dégradé or", Q.TEXT, { rowSel }, 4.5)
	Pair("ligne choisie : détail MUTED clair / dégradé or", Q.MUTED_LIGHT, { rowSel }, 4.5)
	-- plaques : libellé du bouton neutre (repos, survol, appui), liste ouverte bronze
	local L, F = Q.FORGE.label, Q.FORGE
	local style = Q.FORGE_BUTTONS.arcane
	local plate = Q.FORGE_PLATE[style.plate]
	for _, level in ipairs({ L.light, L.dark }) do
		Pair("bouton neutre : libellé / plaque", style.text, { Q.ForgeSurface(plate, level), Q.ForgeSurface(Q.ForgeHover(plate), level),
			Q.ForgeSurface(Q.ForgeTint(plate, F.press), level) }, 4.5)
		Pair("liste ouverte : libellé / plaque bronze", Q.LABEL, { Q.ForgeSurface(Q.FORGE_PLATE.select, level) }, 4.5)
		local card = Q.ForgeSurface(Q.FORGE_PLATE.card, level)
		local hover = Over(card, Q.ACTIVE, F.rowSelect * a)
		Pair("liste : choix survolé / voile or", Q.LABEL, { hover }, 4.5)
		Pair("liste : choix courant (or clair) survolé / voile or", Q.GOLD_LIGHT, { hover }, 4.5)
	end
	Check("[IDENT] QuestCompanion : chaque nouvelle paire encre / fond tient son seuil (4,5 corps, 3 titres)", worst >= 0, where)
	-- éléments graphiques (3:1) : filet or de l'interrupteur actif et du focus sur le creux, curseur or sur la piste
	local fill = Q.FORGE.insetFill
	Check("[IDENT] filet or du focus et de l'interrupteur actif visibles sur le fond du creux (≥ 3:1)",
		C(Q.ACTIVE, Q.ForgeSurface(Q.ACTIVE, fill)) >= 3 and C(Q.FORGE_PLATE.thumbOn, Q.FORGE.track) >= 3,
		string.format("%.2f", C(Q.ACTIVE, Q.ForgeSurface(Q.ACTIVE, fill))))
end

NS.Theme.ApplySkin(SKIN0[1]); QNS.Theme.ApplySkin(SKIN0[2])
