-- Thème forgé (Azeroth) : navigation, sections, cartes et listes du socle.
-- Rien de forgé en Sobre (mêmes régions qu'avant) ; en Azeroth : filets et
-- points lumineux (nos textures ART.line / ART.dot), titres de groupe en
-- pilule de leur ton, entrée choisie en dégradé arcane et barre claire,
-- voyants de module, onglet choisi arcane, relief des cartes (pas de découpe
-- en 9 sur les cartes ni les lignes), losanges auréolés, pied et colonne de
-- la fenêtre de réglages ; rien de forgé sous l'habit du carnet ; contrastes
-- mesurés de chaque texte sur son nouveau fond (au point le plus clair).
local Check, Say, NS, QNS = T.Check, T.Say, T.NS, T.QNS
local Theme = NS.Theme
local SKIN0 = { NS.Theme.skin, QNS.Theme.skin }

local failed = {}
local function Want(label, ok, extra)
	if not ok then failed[#failed + 1] = extra ~= nil and (label .. " (" .. tostring(extra) .. ")") or label end
	return ok
end
local function Verdict(name) Check("[FORGE-NAV] " .. name, #failed == 0, table.concat(failed, " | ")); failed = {} end
local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for i = 1, 3 do if math.abs((a[i] or -1) - (b[i] or -2)) > 0.001 then return false end end
	return true
end
local function Alpha(tex) return tex and tex.vertex and (tex.vertex[4] or 1) end
local function Shown(region) return region ~= nil and region:IsShown() and not region.mockHidden end
local function Textures(frame)
	local n = 0
	for _, child in ipairs(frame.mockChildren or {}) do if child.kind == "Texture" then n = n + 1 end end
	return n
end
-- dégradé posé : { orientation, couleur de départ, alpha, couleur d'arrivée, alpha }
local function Spec(tex) return tex and tex.gradientSpec end
local function Host()
	local host = CreateFrame("Frame", nil, UIParent)
	host:SetSize(600, 400)
	return host
end

-- 1. Sobre : rien de forgé ----------------------------------------------------
do
	Say("-- thème forgé, navigation : Sobre inchangé")
	Theme.ApplySkin("sobre")
	local host = Host()
	Want("ForgeHere faux en Sobre", Theme.ForgeHere() == false and Theme.ForgeHere("CreateNavItem") == false)
	local rule = Theme.CreateGlowRule(host, 2)
	Want("filet : trois segments et deux halos", #rule.segments == 3 and #rule.glow == 2 and not rule.forged)
	local label = Theme.CreateNavGroup(host, "Groupe", "arcane")
	Want("titre de groupe : ambre, sans pilule", label.forgePill == nil and Same(label.textColor, Theme.GOLD))
	local item = Theme.CreateNavItem(host, 219)
	item:SetModuleState(true)
	Want("entrée : interrupteur du thème (pas de voyant), voile 3,5 %, sans reflet", not item.power.led
		and item.forgeSheen == nil and Alpha(item.hover) == 0.035 and Same(Spec(item.tint)[2], Theme.GOLD))
	local tabs = Theme.CreateTabs(host)
	tabs:SetTabs({ { id = "a", label = "A" }, { id = "b", label = "B" } })
	Want("onglets : sans lueur ni reflet, souligné ambre", tabs.tabs[1].forgeGlow == nil and tabs.forgeRuleLight == nil
		and Same(tabs.tabs[1].underline.vertex, Theme.GOLD))
	local section = Theme.CreateSection(host, "Titre", "détail", "arcane")
	Want("section : MUTED clair, sans point ni filet", section.forgeDot == nil and section.forgeLine == nil
		and Same(section.label.textColor, Theme.MUTED_LIGHT))
	local card = Theme.CreateSettingCard(host, 340, 38, "Button")
	Want("carte : fond ROW, sans relief, filet de survol plein", card.forgeRelief == nil and Same(card.bg.vertex, Theme.ROW)
		and Alpha(card.hover.edge.top) == 1)
	local row = Theme.CreateListRow(host, 340, 26, { status = 9 })
	row:SetSelected(true)
	Want("ligne : fond ROW, sans fondu ni choix dessiné", row.forgeFade == nil and row.forgeTint == nil and row.status.forgeGlow == nil)
	local chips = Theme.CreateChips(host, { { id = "a", label = "A" } })
	Want("puce choisie : ambre", Same(chips.byId.a.text.textColor, Theme.GOLD))
	local tag = Theme.CreateTag(host, "Rare", Theme.BLUE)
	local badge = Theme.CreateCurrency(host, {})
	local tile = Theme.CreateTile(host, 100, 60, {})
	local bubble = Theme.CreateBubble(host, 160, {})
	local discreet = Theme.CreateDiscreet(host, 100, 40)
	Want("étiquette, pastille, tuile, bulle, cadre discret : comme avant", tag.forgeEdge == nil and badge.forgeInset == nil
		and tile.forgeRelief == nil and bubble.rule.texture == Theme.SOLID and bubble.rule.height == 2
		and Same(discreet.top.vertex, Theme.GOLD_SOFT) and Alpha(discreet.top) == 0.45 and Spec(discreet.bg) == nil)
	local foot = CreateFrame("Frame", nil, host)
	Want("pied et colonne : rien posé", Theme.ForgeFooter(foot) == false and Theme.ForgeNavColumn(foot) == false and foot.forgeShade == nil)
	-- nombre de textures des briques en Sobre (celles d'avant le thème forgé)
	Want("textures : entrée 3 (+ interrupteur à part), carte 6, ligne à losange 7, section 0", Textures(item) == 3
		and Textures(card) == 6 and Textures(row) == 7 and Textures(section) == 0,
		Textures(item) .. "/" .. Textures(card) .. "/" .. Textures(row) .. "/" .. Textures(section))
	Verdict("Sobre : aucune brique forgée, mêmes régions et couleurs qu'avant")
	host:Hide()
end

Theme.ApplySkin("azeroth")

-- 2. Filets, en-tête, marque ----------------------------------------------------
do
	Say("-- thème forgé, navigation : filets et en-tête")
	local host = Host()
	local rule = Theme.CreateGlowRule(host, 2)
	rule:Place(20, -50, 300)
	local line = rule.segments[1]
	local p = line.points[1]
	Check("[FORGE-NAV] filet lumineux : une seule texture ART.line or clair, à la largeur posée, centrée sur l'ancien filet",
		#rule.segments == 1 and #rule.glow == 0 and line.texture == Theme.ART.line.file and Same(line.vertex, Theme.GOLD_LIGHT)
		and line.width == 300 and line.height == Theme.FORGE_RULE.height and p and p.y == -50 + Theme.FORGE_RULE.lift)
	local arcane = Theme.CreateGlowRule(host, 2, "arcane")
	Check("[FORGE-NAV] filet lumineux : ton arcane à la demande", Same(arcane.segments[1].vertex, Theme.ARCANE_LIGHT))

	local header = Theme.CreatePageHeader(host, 600)
	local spec = Spec(header.plate)
	local K = Theme.FORGE_HEADER
	Want("plaque de bois : bois en bas, chaud en haut", spec and spec[1] == "VERTICAL" and Same(spec[2], Theme.NAV)
		and spec[3] == K.bottom and Same(spec[4], K.warm) and spec[5] == K.top)
	Want("lueurs ambre au-dessus de la plaque", header.topGlow.subLevel == 2 and header.cornerGlow.subLevel == 2
		and header.plate.subLevel == 1)
	Want("filet sous le titre : ART.line", header.rule.forged and header.rule.segments[1].texture == Theme.ART.line.file)
	Verdict("en-tête : plaque de bois au haut chaud, lueurs dessus, filet lumineux sous le titre")

	local brand = Theme.CreateNavBrand(host, Theme.LOGO, "Ready2Quest")
	Check("[FORGE-NAV] marque : filet lumineux or clair (ART.line) sous le nom", brand.rule.texture == Theme.ART.line.file
		and Same(brand.rule.vertex, Theme.GOLD_LIGHT) and brand.rule.height == Theme.FORGE_RULE.height)
	host:Hide()
end

-- 3. Navigation : groupes, entrées, voyants -------------------------------------
do
	Say("-- thème forgé, navigation : colonne")
	local host = Host()
	local K = Theme.FORGE_NAV
	local gold = Theme.CreateNavGroup(host, "Check avant le départ")
	local arcane = Theme.CreateNavGroup(host, "Modules", "arcane")
	local gs, as = Spec(gold.forgePill), Spec(arcane.forgePill)
	Want("or par défaut : pilule ambre qui s'éteint à droite, titre or clair", gs and gs[1] == "HORIZONTAL"
		and Same(gs[2], Theme.GOLD) and gs[3] == K.pill.from and gs[5] == K.pill.to and Same(gold.textColor, Theme.GOLD_LIGHT)
		and gold.toneInk == Theme.IDENTITY_LIGHT and gold.tone == "identity")
	Want("arcane : pilule bleue, titre arcane clair", as and Same(as[2], Theme.BLUE) and Same(arcane.textColor, Theme.ARCANE_LIGHT)
		and arcane.tone == "second")
	Want("filet et reflet de la pilule", gold.forgePillEdge and Alpha(gold.forgePillEdge.top) == K.pill.edge
		and Alpha(gold.forgePillSheen) == K.pill.sheen)
	Want("ton inconnu : l'identité ; nouveaux noms : identity, second", Theme.CreateNavGroup(host, "x", "rose").tone == "identity"
		and Theme.CreateNavGroup(host, "x", "second").tone == "second" and Theme.CreateNavGroup(host, "x", "identity").tone == "identity")
	Verdict("titre de groupe : pilule de son ton (or ou arcane), filet et reflet")

	local item = Theme.CreateNavItem(host, 219)
	item:SetText("Sacs & vivres")
	local ts = Spec(item.tint)
	Want("choix : dégradé arcane qui s'éteint à droite", ts and Same(ts[2], Theme.BLUE) and ts[3] == K.select.from
		and ts[5] == K.select.to)
	Want("barre claire de 2 px", Same(item.bar.vertex, Theme.ARCANE_LIGHT) and item.bar.width == K.bar)
	Want("fond en retrait des bords", item.tint.points[1].x == K.inset and item.hover.points[1].x == K.inset)
	item.scripts.OnEnter(item)
	Want("survol : voile blanc 5 %, pas de choix", Shown(item.hover) and Alpha(item.hover) == K.hover and not Shown(item.tint))
	item:SetSelected(true)
	item:SetBadge("2")
	Want("choisie : dégradé, barre et reflet ; plus de voile", Shown(item.tint) and Shown(item.bar) and Shown(item.forgeSheen)
		and not Shown(item.hover))
	Want("compteur parchemin sur le choix, bleu sinon", Same(item.badge.textColor, Theme.PARCHMENT))
	item:SetSelected(false)
	item.scripts.OnLeave(item)
	Want("repos : rien d'allumé", not Shown(item.tint) and not Shown(item.forgeSheen) and not Shown(item.hover)
		and Same(item.badge.textColor, Theme.BLUE))
	Verdict("entrée : survol voilé, choix arcane avec barre claire et reflet, compteur lisible")

	local clicked
	item.onPower = function(_, on) clicked = on end
	item:SetModuleState(true)
	local led = item.power
	Want("voyant : bouton rond fait de nos points (pas de case du client)", led.led and led.glow.texture == Theme.ART.dot.file
		and led.core.texture == Theme.ART.dot.file and led.box == nil)
	Want("actif : halo vert et cœur vert", Shown(led.glow) and Same(led.glow.vertex, Theme.GREEN) and Same(led.core.vertex, Theme.GREEN))
	led.scripts.OnClick(led)
	Want("clic : l'interrupteur répond", clicked == false)
	item:SetModuleState(false)
	Want("coupé : point sombre, sans halo ; libellé MUTED", not Shown(led.glow) and Same(led.core.vertex, K.led.off)
		and led.core.width == K.led.offCore and Same(item.label.textColor, Theme.MUTED))
	Want("survol : halo clair de la couche HIGHLIGHT", led.highlight.drawLayer == "HIGHLIGHT" and Alpha(led.highlight) == K.led.hover)
	Verdict("voyant de module : point vert lumineux ou point sombre, clic et survol gardés")
	host:Hide()
end

-- 4. Onglets, sections ----------------------------------------------------------
do
	Say("-- thème forgé, navigation : onglets et sections")
	local host = Host()
	local K = Theme.FORGE_TABS
	local tabs = Theme.CreateTabs(host)
	tabs:SetTabs({ { id = "a", label = "Créatures" }, { id = "b", label = "Réserve" } })
	tabs:Select("b", true)
	local a, b = tabs.byId.a, tabs.byId.b
	local gs = Spec(b.forgeGlow)
	Want("choisi : dégradé arcane (vers le bas), souligné arcane clair, reflet", Shown(b.forgeGlow) and Shown(b.forgeSheen)
		and Shown(b.underline) and gs and gs[1] == "VERTICAL" and Same(gs[2], Theme.BLUE) and gs[5] == K.from and gs[3] == K.to
		and Same(b.underline.vertex, Theme.ARCANE_LIGHT) and Same(b.label.textColor, Theme.PARCHMENT))
	Want("les autres : éteints", not Shown(a.forgeGlow) and not Shown(a.forgeSheen) and not Shown(a.underline))
	a.scripts.OnEnter(a)
	Want("survol : texte courant", Same(a.label.textColor, Theme.TEXT) and not Shown(a.forgeGlow))
	Want("filet noir sous la rangée, reflet dessous", Same(tabs.rule.vertex, Theme.SHADOW) and Alpha(tabs.rule) == K.rule
		and Alpha(tabs.forgeRuleLight) == K.ruleLight)
	Verdict("onglets : le choisi en dégradé arcane souligné, survol éclairci, filet noir et reflet")

	local S = Theme.FORGE_SECTION
	local section = Theme.CreateSection(host, "Préparation", nil)
	Want("or : point lumineux, titre or clair, filet or", section.forgeDot.texture == Theme.ART.dot.file
		and Same(section.forgeDot.vertex, Theme.GOLD_LIGHT) and Same(section.label.textColor, Theme.GOLD_LIGHT)
		and section.forgeLine.texture == Theme.ART.line.file and section.tone == "identity")
	Want("titre après le point", section.label.points[1].x == S.text and section.forgeDot.width == S.dot)
	Want("filet : du titre au bord droit", section.forgeLine.points[1].relTo == section.label
		and section.forgeLine.points[2].point == "RIGHT")
	section:SetText("Quêtes", "2")
	Want("avec détail : le filet part après le détail", section.forgeLine.points[1].relTo == section.detail)
	local nav = Theme.CreateSection(host, "Résultats", nil, "arcane")
	Want("arcane : point, titre et filet arcane", Same(nav.label.textColor, Theme.ARCANE_LIGHT)
		and Same(nav.forgeLine.vertex, Theme.ARCANE_LIGHT) and nav.tone == "second")
	Verdict("section : point lumineux, titre de son ton, filet qui part après le titre")
	host:Hide()
end

-- 5. Cartes, lignes, losanges ---------------------------------------------------
do
	Say("-- thème forgé, navigation : cartes et listes")
	local host = Host()
	local K = Theme.FORGE_CARD
	local card = Theme.CreateSettingCard(host, 340, 38, "Button")
	local rs = Spec(card.forgeRelief)
	Want("relief : voile noir en bas, blanc en haut", rs and rs[1] == "VERTICAL" and Same(rs[2], Theme.SHADOW) and rs[3] == K.dark
		and Same(rs[4], Theme.WHITE) and rs[5] == K.light)
	Want("reflet en haut, ombre en bas", Alpha(card.forgeSheen) == K.sheen and Alpha(card.forgeShade) == K.shade
		and card.forgeSheen.points[1].point == "TOPLEFT" and card.forgeShade.points[1].point == "BOTTOMLEFT")
	card:SetAlt(true)
	Want("le fond garde ROW / ROW_ALT", Same(card.bg.vertex, Theme.ROW_ALT))
	Want("trois textures de relief, pas de découpe en 9", Textures(card) == 9, Textures(card))
	card.scripts.OnEnter(card)
	Want("survol : voile, filet or patiné discret", Shown(card.hover) and Alpha(card.hover.edge.top) == Theme.FORGE_NAV.hoverEdge)
	Verdict("carte de réglage : relief (voile, reflet, ombre) sur son fond, survol gardé")

	local R = Theme.FORGE_ROW
	local row = Theme.CreateListRow(host, 340, 26, { status = 9, detail = true, kind = "Button" })
	row:SetIndex(2)
	local fs, ss = Spec(row.forgeFade), Spec(row.forgeTint)
	Want("fond qui s'éteint vers la droite, couleur gardée", fs and fs[1] == "HORIZONTAL" and fs[3] == R.fade.from
		and fs[5] == R.fade.to and Same(row.bg.vertex, Theme.ROW_ALT))
	Want("au repos : pas de choix dessiné", not Shown(row.forgeTint) and not Shown(row.forgeBar))
	row:SetSelected(true)
	Want("choisie : dégradé arcane et barre claire", row.selected and Shown(row.forgeTint) and Shown(row.forgeBar)
		and ss and Same(ss[2], Theme.BLUE) and ss[3] == R.select.from and Same(row.forgeBar.vertex, Theme.ARCANE_LIGHT))
	row:SetSelected(false)
	Want("rendue : éteinte", not Shown(row.forgeTint) and not Shown(row.forgeBar))
	Want("pas de découpe en 9 sur une ligne : 4 textures de plus (choix, barre, fondu, halo)", Textures(row) == 11, Textures(row))
	Verdict("ligne de liste : fondu vers la droite, choix arcane et barre, sans découpe")

	local diamond = row.status
	local glow = diamond.forgeGlow
	local c = Theme.SetStatus(diamond, "bad")
	Want("halo : notre point, derrière le losange", glow and glow.texture == Theme.ART.dot.file and glow.drawLayer == "ARTWORK"
		and diamond.drawLayer == "OVERLAY" and glow.width == math.floor(9 * R.glow + 0.5))
	Want("halo de la couleur du statut", Same(glow.vertex, c) and math.abs(Alpha(glow) - R.glowAlpha) < 1e-6 and Shown(glow))
	Theme.SetStatus(diamond, "none")
	Want("losange caché : halo caché", not Shown(diamond) and not Shown(glow))
	diamond:Show()
	diamond:SetVertexColor(0.2, 0.4, 0.6, 1)
	Want("affiché ou recoloré par le module : le halo suit", Shown(glow) and Same(glow.vertex, { 0.2, 0.4, 0.6 }))
	Verdict("losange de statut : halo de sa couleur (ART.dot), qui suit couleur et affichage")
	host:Hide()
end

-- 6. Puces, tuiles, étiquettes, pastille, bulle, cadre discret ----------------
do
	Say("-- thème forgé, navigation : petites briques")
	local host = Host()
	local chips = Theme.CreateChips(host, { { id = "a", label = "Toutes" }, { id = "b", label = "Rares" } })
	local on, off = chips.byId.a, chips.byId.b
	local s = Spec(on.bg)
	Want("puce choisie : dégradé arcane, filet clair, texte parchemin", s and Same(s[2], Theme.BLUE) and s[5] == Theme.FORGE_CHIP.from
		and Same(on.border.top.vertex, Theme.ARCANE_LIGHT) and Same(on.text.textColor, Theme.PARCHMENT))
	Want("au repos : sans fond, filet or sombre", Spec(off.bg)[5] == 0 and Same(off.border.top.vertex, Theme.EDGE_SOFT))
	off.scripts.OnEnter(off)
	Want("survol : filet or patiné, libellé clair", Same(off.border.top.vertex, Theme.EDGE) and Same(off.text.textColor, Theme.LABEL))
	Verdict("puces (filtres) : la choisie en bleu arcane, survol gardé")

	local tile = Theme.CreateTile(host, 100, 60, {})
	tile:SetFill(Theme.GOLD, 0.2)
	tile:SetSelected(true)
	Check("[FORGE-NAV] tuile : relief par-dessus son fond (couleur du module gardée), choisie en filet arcane",
		tile.forgeRelief ~= nil and tile.forgeShade == nil and Same(tile.bg.vertex, Theme.GOLD) and Same(tile.border.top.vertex, Theme.ACTIVE))
	local tag = Theme.CreateTag(host, "Rare", Theme.BLUE)
	Check("[FORGE-NAV] étiquette : filet de sa couleur", tag.forgeEdge and Same(tag.forgeEdge.top.vertex, Theme.BLUE)
		and Alpha(tag.forgeEdge.top) == Theme.FORGE_TAG.edge)
	local badge = Theme.CreateCurrency(host, { value = 12 })
	Check("[FORGE-NAV] pastille de monnaie : creux (ART.inset, filet or patiné), fond et filet plats effacés",
		badge.forgeInset and badge.forgeInset.parts.c.texture == Theme.ART.inset.file and Same(badge.forgeInset.color, Theme.EDGE)
		and badge.bg.alpha == 0 and Alpha(badge.border.top) == 0)
	local bubble = Theme.CreateBubble(host, 160, {})
	Check("[FORGE-NAV] bulle : filet lumineux en haut", bubble.rule.texture == Theme.ART.line.file and bubble.forged)
	local discreet = Theme.CreateDiscreet(host, 100, 40)
	local ds = Spec(discreet.bg)
	Check("[FORGE-NAV] cadre discret : bois sombre vers le noir, filets or patiné", ds and Same(ds[2], Theme.SHADOW)
		and Same(ds[4], Theme.NAV) and Same(discreet.top.vertex, Theme.EDGE))
	host:Hide()
end

-- 7. Le carnet de QuestCompanion se rhabille lui-même : rien de forgé dessous --
do
	Say("-- thème forgé, navigation : sous l'habit du carnet")
	local host = Host()
	local own = Theme.CreateNavItem
	Theme.CreateNavItem = function(...) return own(...) end   -- comme ns.CarnetCaptureRun
	local item = Theme.CreateNavItem(host, 219)
	local group = Theme.CreateNavGroup(host, "Groupe")
	local diamond = Theme.CreateDiamond(host, 9)
	local section = Theme.CreateSection(host, "Section")
	local rule = Theme.CreateGlowRule(host, 2)
	local skipped = item.forged == nil and not item.power.led and group.forgePill == nil and diamond.forgeGlow == nil
		and section.forgeDot == nil and #rule.segments == 3
	Theme.CreateNavItem = own
	Check("[FORGE-NAV] carnet en Azeroth (fabriques enveloppées) : aucune brique forgée, même celles qu'il n'enveloppe pas",
		skipped and Theme.ForgeHere() == true)
	host:Hide()
end

-- 8. Fenêtre de réglages ----------------------------------------------------------
do
	Say("-- thème forgé, navigation : fenêtre de réglages")
	T.ResetWorld()
	NS.optionsFrame = nil
	NS:ToggleOptions()
	local frame = NS.optionsFrame
	local function Head(id) for _, h in ipairs(frame.navHeaders) do if h.pageId == id then return h end end end
	local function Plain()
		for _, label in ipairs(frame.navGroups) do
			local isPage = false
			for _, h in ipairs(frame.navHeaders) do if h.label == label then isPage = true end end
			if not isPage then return label end
		end
	end
	local departure, plain = Head("departure"), Plain()
	Want("page à sous-pages (une fonction) : pilule or", departure and departure.label.tone == "identity")
	Want("titre de rangement : pilule arcane", plain and plain.tone == "second")
	Want("voyants dans la colonne", departure.power.led and frame.navButtons[#frame.navButtons].power.led)
	local key = departure.powerKey
	Want("le groupe « départ » porte l'interrupteur de son module", key ~= nil)
	NS:DB()[key or "?"] = false
	NS:RefreshOptions()
	Want("module coupé : titre en MUTED clair (lisible sur sa pilule), point sombre",
		Same(departure.label.textColor, Theme.FORGE_NAV.offInk) and not Shown(departure.power.glow))
	NS:DB()[key or "?"] = nil
	NS:RefreshOptions()
	Want("module actif : titre de son ton, point vert",
		Same(departure.label.textColor, Theme.GOLD_LIGHT) and Shown(departure.power.glow))
	Verdict("colonne : groupes or (fonction) ou arcane (rangement), voyants, titre lisible module coupé")

	local nav, foot = frame.nav, frame.footer
	local ns_, fs_ = Spec(nav.forgeShade), Spec(foot.forgeShade)
	Check("[FORGE-NAV] colonne plus sombre au bord gauche, séparateur noir et reflet ; pied plus sombre, filet noir et reflet",
		ns_ and ns_[1] == "HORIZONTAL" and ns_[3] == Theme.FORGE_NAV.shade.from and Same(nav.separator.vertex, Theme.SHADOW)
		and Alpha(nav.forgeEdge) == Theme.FORGE_NAV.edgeLight and fs_ and fs_[1] == "VERTICAL" and fs_[5] == Theme.FORGE_FOOT.from
		and Same(foot.line.vertex, Theme.SHADOW) and Alpha(foot.forgeSheen) == Theme.FORGE_FOOT.sheen
		and Theme.ForgeFooter(foot) == false)

	frame.search:SetText("alerte")
	frame.search.scripts.OnTextChanged(frame.search, true)
	local first = frame.searchPage.sections[1]
	Check("[FORGE-NAV] recherche : sections de résultats en arcane (où vit le réglage)", first and first.tone == "second"
		and Same(first.label.textColor, Theme.ARCANE_LIGHT))
	frame.search:SetText("")
	frame.search.scripts.OnTextChanged(frame.search, true)

	-- budget : cartes de toutes les pages construites à l'ouverture
	local cards, slices = 0, 0
	for _, card in ipairs(frame.rows) do
		cards = cards + 1
		for _, child in ipairs(card.mockChildren) do
			if child.kind == "Texture" and child.texture == Theme.ART.plate.file then slices = slices + 1 end
		end
	end
	Check("[FORGE-NAV] cartes : relief de 3 textures (pas de découpe en 9 : " .. cards .. " cartes construites)",
		cards > 20 and slices == 0 and frame.rows[1].forgeRelief ~= nil, cards .. " cartes, " .. slices .. " pièces de plaque")
	frame:Hide()
	NS.optionsFrame = nil
end

-- 9. Contrastes : chaque texte sur son nouveau fond, au point le plus clair ---
do
	Say("-- thème forgé, navigation : contrastes")
	local C, Over = Theme.Contrast, Theme.Over
	local K, B = Theme.FORGE_NAV, Theme.FORGE_ROW
	local black, white = Theme.SHADOW, Theme.WHITE
	-- colonne : bois, plus sombre au bord gauche
	local navLeft, navRight = Over(Theme.NAV, black, K.shade.from), Over(Theme.NAV, black, K.shade.to)
	local function Lightest(...)
		local best
		for _, c in ipairs({ ... }) do if not best or Theme.Luminance(c) > Theme.Luminance(best) then best = c end end
		return best
	end
	local function Pair(name, ink, bg, need)
		Check(string.format("[FORGE-NAV] contraste %s >= %s", name, need), C(ink, bg) >= need, string.format("%.2f", C(ink, bg)))
	end
	local sel = Lightest(Over(navLeft, Theme.BLUE, K.select.from), Over(navRight, Theme.BLUE, K.select.to))
	Pair("entrée choisie : parchemin sur le dégradé arcane", Theme.PARCHMENT, sel, 4.5)
	Pair("entrée choisie : compteur parchemin sur le dégradé arcane", Theme.PARCHMENT, sel, 4.5)
	Pair("entrée survolée : texte sur le voile", Theme.TEXT, Over(navRight, white, K.hover), 4.5)
	local pillGold = Lightest(Over(navLeft, Theme.GOLD, K.pill.from), Over(navRight, Theme.GOLD, K.pill.from))
	local pillArc = Lightest(Over(navLeft, Theme.BLUE, K.pill.from), Over(navRight, Theme.BLUE, K.pill.from))
	Pair("titre de groupe or clair sur sa pilule", Theme.GOLD_LIGHT, pillGold, 4.5)
	Pair("titre de groupe arcane clair sur sa pilule", Theme.ARCANE_LIGHT, pillArc, 4.5)
	Pair("titre de groupe d'un module coupé sur la pilule or", K.offInk, pillGold, 4.5)
	Pair("titre de groupe d'un module coupé sur la pilule arcane", K.offInk, pillArc, 4.5)
	-- onglets, sections, puces : sur le fond de la fenêtre
	Pair("onglet choisi : parchemin sur le dégradé arcane", Theme.PARCHMENT, Over(Theme.WINDOW, Theme.BLUE, Theme.FORGE_TABS.from), 4.5)
	Pair("section : or clair sur la fenêtre", Theme.GOLD_LIGHT, Theme.WINDOW, 4.5)
	Pair("section : arcane clair sur la fenêtre", Theme.ARCANE_LIGHT, Theme.WINDOW, 4.5)
	Pair("puce choisie : parchemin sur le dégradé arcane", Theme.PARCHMENT, Over(Theme.WINDOW, Theme.BLUE, Theme.FORGE_CHIP.from), 4.5)
	-- cartes : le haut du relief est le plus clair (ROW_ALT + voile blanc + reflet)
	local cardTop = Over(Theme.ROW_ALT, white, Theme.FORGE_CARD.light)
	local cardBottom = Over(Theme.ROW, black, Theme.FORGE_CARD.dark)
	Pair("carte : libellé en haut du relief", Theme.LABEL, cardTop, 4.5)
	Pair("carte : libellé en bas du relief", Theme.LABEL, cardBottom, 4.5)
	Pair("carte : phrase (MUTED) en haut du relief", Theme.MUTED, cardTop, 4.5)
	Pair("carte : valeur ambre en haut du relief", Theme.GOLD, cardTop, 4.5)
	-- ligne choisie : le bord gauche du dégradé arcane est le plus clair
	local rowSel = Over(Theme.ROW_ALT, Theme.BLUE, B.select.from)
	Pair("ligne choisie : texte", Theme.TEXT, rowSel, 4.5)
	Pair("ligne choisie : détail MUTED clair", Theme.MUTED_LIGHT, rowSel, 4.5)
	-- en-tête : le haut de la plaque, lueurs ambre comprises
	local headerTop = Over(Over(Theme.WINDOW, Theme.FORGE_HEADER.warm, Theme.FORGE_HEADER.top), Theme.GOLD, 0.11)
	Pair("en-tête : titre or clair en haut de la plaque", Theme.TITLE, headerTop, 3)
	Pair("en-tête : sous-titre MUTED clair en haut de la plaque", Theme.MUTED_LIGHT, headerTop, 4.5)
	-- pastille de monnaie : sur le creux (fond presque noir : FIELD au plus clair)
	Pair("pastille : chiffre ambre sur le creux", Theme.GOLD, Theme.FIELD, 4.5)
end

NS.Theme.ApplySkin(SKIN0[1]); QNS.Theme.ApplySkin(SKIN0[2])
