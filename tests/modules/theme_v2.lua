-- tests/modules/theme_v2.lua -- socle : thème v2 (polices Inter, jetons,
-- briques de la refonte) et rendu hors-jeu (tests/snapshot.lua)
local Check, Say, NS, QNS, Mock = T.Check, T.Say, T.NS, T.QNS, T.Mock
local Theme = NS.Theme
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()

local function Near(a, b) return math.abs((a or 0) - (b or 0)) < 0.01 end
local function SameColor(c, token) return c and Near(c[1], token[1]) and Near(c[2], token[2]) and Near(c[3], token[3]) end

-- 1. Polices ---------------------------------------------------------------
do
	Say("-- thème v2 : polices")
	Check("[TH2] objets de police préfixés par l'addon", Theme.F_BODY == "Ready2QuestFontBody"
		and QNS.Theme.F_BODY == "QuestCompanionFontBody", Theme.F_BODY .. " / " .. tostring(QNS.Theme.F_BODY))
	local roles = { DISPLAY = { "Bold", 26 }, TITLE = { "Bold", 16 }, HEADING = { "SemiBold", 13 }, LABEL = { "SemiBold", 12 },
		BODY = { "Regular", 12 }, SMALL = { "Regular", 11 }, CAPS = { "SemiBold", 10 } }
	local wrong = {}
	for role, spec in pairs(roles) do
		local name = Theme["F_" .. role]
		local font = rawget(_G, name)
		local path = font and font.font and font.font.path or ""
		if not (font and path:find("Inter%-" .. spec[1] .. "%.ttf") and font.font.size == spec[2]) then
			wrong[#wrong + 1] = role .. "=" .. tostring(path) .. "@" .. tostring(font and font.font and font.font.size)
		end
	end
	Check("[TH2] sept rôles : graisse et taille de docs/UI.md", #wrong == 0, table.concat(wrong, ", "))
	Check("[TH2] anciens noms branchés sur Inter", Theme.F_NORMAL == Theme.F_BODY and Theme.F_TITLE == "Ready2QuestFontTitle"
		and Theme.F_SMALL == "Ready2QuestFontSmall" and Theme.F_NUMBER == "Ready2QuestFontNumber"
		and tostring(_G.Ready2QuestFontNumber.font.path):find("Inter%-Bold") ~= nil)
	Check("[TH2] chaque addon a son jeu (objets distincts)", rawget(_G, "Ready2QuestFontBody") ~= rawget(_G, "QuestCompanionFontBody")
		and tostring(QNS.Theme.FONT_REGULAR):find("QuestCompanion") ~= nil)
	Check("[TH2] plus d'Alegreya", not tostring(Theme.FONT_TITLE):find("Alegreya") and tostring(Theme.FONT_TITLE):find("Inter%-Bold") ~= nil)

	Mock.world.fontRefused = true
	local refused = Theme.CreateFonts("TestRefus")
	Mock.world.fontRefused = false
	Check("[TH2] police refusée : repli sur la police du jeu", refused.BODY.inter == false
		and refused.BODY.name == "TestRefusFontBody" and _G.TestRefusFontBody.copiedFrom == _G.GameFontHighlightSmall,
		tostring(refused.BODY.name))
	Check("[TH2] police refusée : titre copié de GameFontNormalLarge", _G.TestRefusFontTitle.copiedFrom == _G.GameFontNormalLarge)

	Mock.world.noCreateFont = true
	local bare = Theme.CreateFonts("TestSans")
	Mock.world.noCreateFont = nil
	Check("[TH2] sans CreateFont : le rôle désigne la police du jeu", bare.BODY.name == "GameFontHighlightSmall"
		and bare.DISPLAY.name == "GameFontNormalHuge" and rawget(_G, "TestSansFontBody") == nil)

	-- copie impossible (pas de police du jeu de ce nom) : le nom du jeu, pas un objet vide
	Mock.world.fontRefused = true
	local saved = _G.GameFontNormalSmall
	_G.GameFontNormalSmall = nil
	local orphan = Theme.CreateFonts("TestOrphelin")
	_G.GameFontNormalSmall = saved
	Mock.world.fontRefused = false
	Check("[TH2] ni Inter ni copie : jamais un objet sans police", orphan.CAPS.name == "GameFontNormalSmall", orphan.CAPS.name)
	-- client dont SetFont ne rend rien : on relit la police posée
	Mock.world.fontSilent = "refuse"
	local silentNo = Theme.CreateFonts("TestMuetRefus")
	Mock.world.fontSilent = "ok"
	local silentYes = Theme.CreateFonts("TestMuetOk")
	Mock.world.fontSilent = nil
	Check("[TH2] SetFont muet, fichier refusé : repli sur la police du jeu", silentNo.BODY.inter == false
		and _G.TestMuetRefusFontBody.copiedFrom == _G.GameFontHighlightSmall)
	Check("[TH2] SetFont muet, fichier posé : Inter gardée", silentYes.BODY.inter == true)
	Check("[TH2] capitales accentuées", Theme.Upper("préparation à l'œuvre") == "PRÉPARATION À L'ŒUVRE", Theme.Upper("préparation à l'œuvre"))
end

-- 2. Jetons ----------------------------------------------------------------
do
	local hex = { WINDOW = "13171b", NAV = "0d1013", ROW = "171c21", ROW_ALT = "1b2127", FIELD = "101418",
		EDGE = "3a424a", EDGE_SOFT = "2a3138", LABEL = "e6e1d5" }
	local wrong = {}
	for token, value in pairs(hex) do
		local c = Theme[token]
		local got = c and string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
		if got ~= value then wrong[#wrong + 1] = token .. "=" .. tostring(got) end
	end
	Check("[TH2] jetons de la palette (docs/UI.md)", #wrong == 0, table.concat(wrong, ", "))
	Check("[TH2] anciens jetons gardés", Theme.GOLD and Theme.BLUE and Theme.SURFACE and Theme.CONTROL and Theme.GOLD_DIM ~= nil)
end

-- 3. Dégradés --------------------------------------------------------------
do
	local holder = CreateFrame("Frame", nil, UIParent)
	local tex = holder:CreateTexture(nil, "ARTWORK")
	local saved = rawget(_G, "CreateColor")
	_G.CreateColor = nil
	local mode = Theme.Gradient(tex, "HORIZONTAL", Theme.GOLD, 0, Theme.GOLD, 1)
	Check("[TH2] sans CreateColor : aplat à mi-chemin", mode == nil and tex.gradient == nil and Near(tex.vertex[4], 0.5))
	_G.CreateColor = Mock.CreateColor
	mode = Theme.Gradient(tex, "VERTICAL", Theme.GOLD, 0.1, Theme.GOLD_LIGHT, 0.9)
	Check("[TH2] dégradé, API récente", mode == "color" and tex.gradient[1] == "VERTICAL" and Near(tex.gradient[3].a, 0.9))
	tex.SetGradient = function() error("signature inconnue") end
	mode = Theme.Gradient(tex, "VERTICAL", Theme.GOLD, 0, Theme.GOLD, 1)
	Check("[TH2] SetGradient qui échoue : aplat, sans erreur", mode == nil)
	_G.CreateColor = saved
end

-- 4. Briques ---------------------------------------------------------------
do
	Say("-- thème v2 : briques")
	local win = Theme.CreateWindow(UIParent, 980, 680, { name = "TestTheme2Window", nav = 220, footer = 56 })
	Check("[TH2] fenêtre : fond WINDOW, filet EDGE", SameColor(win.bg.vertex, Theme.WINDOW) and SameColor(win.border.top.vertex, Theme.EDGE))
	Check("[TH2] fenêtre : navigation de 220 sur fond NAV", win.nav and win.nav.width == 220 and SameColor(win.nav.bg.vertex, Theme.NAV)
		and win.nav.separator ~= nil)
	Check("[TH2] fenêtre : contenu à droite de la navigation", win.content and win.content.points[1].relTo == win.nav
		and win.content.points[1].relPoint == "TOPRIGHT")
	local escape = false
	for _, name in ipairs(UISpecialFrames) do if name == "TestTheme2Window" then escape = true end end
	Check("[TH2] fenêtre : Échap la ferme", escape)
	Check("[TH2] fenêtre : déplaçable", win.movable == true and win.scripts.OnDragStart ~= nil)
	win:Show()
	win.close:Click()
	Check("[TH2] fenêtre : [×] la ferme", win.mockHidden == true and win.close.label.text == "\195\151")
	local plain = Theme.CreateWindow(UIParent, 400, 300, {})
	Check("[TH2] fenêtre sans navigation", plain.nav == nil and plain.content.points[1].relTo == plain)

	local header = Theme.CreatePageHeader(win.content, 758)
	header:SetTitle("Titre"); header:SetSubtitle("Sous-titre")
	Check("[TH2] en-tête : titre F_DISPLAY, sous-titre F_BODY", header.title.text == "Titre" and header.title.fontObject == Theme.F_DISPLAY
		and header.subtitle.text == "Sous-titre" and header.subtitle.fontObject == Theme.F_BODY)
	Check("[TH2] en-tête : filet en trois segments et halo", #header.rule.segments == 3 and #header.rule.glow == 2
		and header.rule.segments[1].gradientSpec[3] == 0 and header.rule.segments[2].gradientSpec[5] == 1)

	local brand = Theme.CreateNavBrand(win.nav, Theme.LOGO, "Ready2Quest")
	Check("[TH2] marque : logo, nom F_TITLE, filet", brand.logo.texture == Theme.LOGO and brand.name.text == "Ready2Quest"
		and brand.name.fontObject == Theme.F_TITLE and brand.rule ~= nil)
	local group = Theme.CreateNavGroup(win.nav, "Préparation")
	Check("[TH2] groupe : ambre, capitales", group.text == "PRÉPARATION" and SameColor(group.textColor, Theme.GOLD)
		and group.fontObject == Theme.F_CAPS)

	local item = Theme.CreateNavItem(win.nav, 219)
	item:SetText("Vivres")
	Check("[TH2] entrée : sans interrupteur par défaut", item.power.mockHidden == true and not item.bar:IsShown())
	item:SetSelected(true)
	Check("[TH2] entrée choisie : barre ambre 2 px, dégradé, libellé parchemin", item.bar.shown and item.bar.width == 2
		and item.tint.shown and SameColor(item.label.textColor, Theme.PARCHMENT))
	item:SetSelected(false)
	item:SetModuleState("off")
	Check("[TH2] module coupé : rond gris, libellé grisé", item.power.shown and SameColor(item.power.icon.vertex, Theme.MUTED)
		and SameColor(item.label.textColor, Theme.MUTED) and not item.bar.shown)
	item:SetModuleState(true)
	Check("[TH2] module actif : rond ambre", SameColor(item.power.icon.vertex, Theme.GOLD) and SameColor(item.label.textColor, Theme.TEXT))
	local powered
	item.onPower = function(_, on) powered = on end
	item.power:Click()
	Check("[TH2] clic sur le rond : demande l'inverse", powered == false)
	item:SetBadge("2/3")
	Check("[TH2] badge bleu, à gauche du rond", item.badge.shown and item.badge.text == "2/3" and SameColor(item.badge.textColor, Theme.BLUE)
		and item.badge.points[1].relTo == item.power)
	item:SetBadge(nil)
	Check("[TH2] badge retiré", item.badge.mockHidden == true)
	item.scripts.OnEnter(item)
	Check("[TH2] survol d'une entrée", item.hover.shown == true)
	item.scripts.OnLeave(item)

	local picked
	local tabs = Theme.CreateTabs(win.content, function(id) picked = id end)
	tabs:SetTabs({ { id = "a", label = "Vérifications" }, { id = "b", label = "Alerte" }, { id = "c", label = "Fenêtre" } })
	Check("[TH2] onglets : le premier choisi d'office", tabs.selected == "a" and tabs.tabs[1].underline.shown and not tabs.tabs[2].underline.shown)
	tabs.tabs[2]:Click()
	Check("[TH2] onglets : clic -> rappel et soulignement", picked == "b" and tabs.tabs[2].underline.shown and not tabs.tabs[1].underline.shown
		and tabs.tabs[2].underline.height == 2 and SameColor(tabs.tabs[2].label.textColor, Theme.PARCHMENT))
	picked = nil
	tabs:Select("c", true)
	Check("[TH2] onglets : choix silencieux", picked == nil and tabs.selected == "c")
	Check("[TH2] onglets : id inconnu refusé", tabs:Select("zz") == false and tabs.selected == "c")
	Check("[TH2] onglets côte à côte", tabs.tabs[2].points[1].x > tabs.tabs[1].points[1].x)

	local searched
	local search = Theme.CreateSearchBox(win.nav, 188, "Rechercher", function(text) searched = text end)
	Check("[TH2] recherche : EditBox FIELD, indicatif visible", search.kind == "EditBox" and SameColor(search.bg.vertex, Theme.FIELD)
		and search.placeholder.text == "Rechercher" and search.placeholder.mockHidden ~= true and search.autoFocus == false)
	search:SetText("viv")
	search.scripts.OnTextChanged(search, true)
	Check("[TH2] recherche : rappel avec le texte, indicatif masqué", searched == "viv" and search.placeholder.mockHidden == true)
	searched = nil
	search.scripts.OnTextChanged(search, false)
	Check("[TH2] recherche : pas de rappel si rien ne change", searched == nil)
	search:SetText("")
	search.scripts.OnTextChanged(search, true)
	Check("[TH2] recherche vidée : indicatif revenu", searched == "" and search.placeholder.mockHidden == false)

	local section = Theme.CreateSection(win.content, "Déclenchement", "quand l'alerte apparaît")
	Check("[TH2] section : capitales F_CAPS, détail entre parenthèses", section.label.text == "DÉCLENCHEMENT"
		and section.label.fontObject == Theme.F_CAPS and section.detail.text == "(quand l'alerte apparaît)")
	local bare = Theme.CreateSection(win.content, "Boutons")
	Check("[TH2] section sans détail", bare.detail.mockHidden == true)

	local card = Theme.CreateSettingCard(win.content, 351)
	card:SetLabel("Son")
	Check("[TH2] carte : 38 de haut, fond ROW, libellé F_LABEL", card.height == 38 and SameColor(card.bg.vertex, Theme.ROW)
		and card.label.fontObject == Theme.F_LABEL and SameColor(card.label.textColor, Theme.LABEL) and card.control ~= nil)
	card:SetAlt(true)
	Check("[TH2] carte paire : ROW_ALT", SameColor(card.bg.vertex, Theme.ROW_ALT))

	local toggle = Theme.CreateToggle(card.control)
	Check("[TH2] interrupteur : piste 32 x 15", toggle.width == 32 and toggle.height == 15 and toggle.checked == false)
	toggle:SetChecked(true)
	Check("[TH2] interrupteur actif : piste ambre, curseur blanc à droite", SameColor(toggle.track.vertex, Theme.GOLD)
		and toggle.knob.vertex[1] == 1 and toggle.knob.vertex[3] == 1 and toggle.knob.points[1].point == "RIGHT")
	toggle:SetChecked(false)
	Check("[TH2] interrupteur coupé : piste CONTROL, curseur MUTED à gauche", SameColor(toggle.track.vertex, Theme.CONTROL)
		and SameColor(toggle.knob.vertex, Theme.MUTED) and toggle.knob.points[1].point == "LEFT")
	toggle:SetPartial()
	Check("[TH2] interrupteur partiel gardé", toggle.partial == true and toggle.checked == nil)

	local changes = {}
	local slider = Theme.CreateSlider(card.control, 170, 0, 30, 5, function(v) changes[#changes + 1] = v end)
	Check("[TH2] curseur : piste 3 px, poignée et case de valeur", slider.track.height == 3 and SameColor(slider.fill.vertex, Theme.GOLD)
		and SameColor(slider.handle.vertex, Theme.GOLD) and slider.valueText.text == "0")
	Check("[TH2] curseur : au cran près", slider:SetValue(12) == 10 and slider:SetValue(13) == 15 and slider.valueText.text == "15")
	Check("[TH2] curseur : borné", slider:SetValue(99) == 30 and slider:SetValue(-4) == 0)
	Check("[TH2] curseur : SetValue ne rappelle pas", #changes == 0)
	slider:SetValue(10)
	slider.scripts.OnMouseWheel(slider, 1)
	Check("[TH2] molette : un cran de plus, rappel", slider.value == 15 and changes[1] == 15)
	Check("[TH2] molette activée aussi sur la zone sensible de la piste", slider.hit.mouseWheel == true)
	Check("[TH2] curseur au repos : pas d'OnUpdate", slider.hit.scripts.OnUpdate == nil)
	slider.hit.scripts.OnMouseDown(slider.hit)
	Check("[TH2] glisser : suivi de la souris branché", slider.hit.scripts.OnUpdate ~= nil)
	slider.hit.scripts.OnMouseUp(slider.hit)
	Check("[TH2] relâché : suivi débranché", slider.hit.scripts.OnUpdate == nil)
	slider:SetValue(15)
	slider.scripts.OnMouseWheel(slider, -1); slider.scripts.OnMouseWheel(slider, -1); slider.scripts.OnMouseWheel(slider, -1)
	slider.scripts.OnMouseWheel(slider, -1)
	Check("[TH2] molette : bornée en bas, sans rappel inutile", slider.value == 0 and #changes == 4, #changes)
	Check("[TH2] glisser : valeur sous la souris", slider:ValueAt(0) == 0 and slider:ValueAt(slider.trackWidth) == 30
		and slider:ValueAt(slider.trackWidth / 2) == 15 and slider:ValueAt(-50) == 0 and slider:ValueAt(9999) == 30)
	slider:SetValue(20)
	Check("[TH2] remplissage proportionnel", Near(slider.fill.width, math.floor(slider.trackWidth * 2 / 3 + 0.5)))
	slider:SetValueText("20 s")
	Check("[TH2] texte de valeur imposé", slider.valueText.text == "20 s")
	local fine = Theme.CreateSlider(card.control, 170, 0, 1, 0.1)
	Check("[TH2] cran décimal sans erreur d'arrondi", fine:SetValue(0.3) == 0.3 and fine.valueText.text == "0.3")

	local chosen
	local dd = Theme.CreateDropdown(card.control, 150, function(value) chosen = value end)
	dd:SetOptions({ { value = "top", label = "En haut" }, { value = "mid", label = "Au centre" },
		{ value = "gold", label = "Cadre doré", disabled = true, hint = "30 brillantes" } })
	dd:SetValue("top")
	Check("[TH2] liste : case FIELD, texte du choix, chevron", SameColor(dd.bg.vertex, Theme.FIELD) and dd.text.text == "En haut"
		and dd.chevron.texture == Theme.CHEVRON)
	Check("[TH2] liste fermée au départ", not dd:IsOpen())
	dd:Click()
	Check("[TH2] clic : la liste s'ouvre", dd:IsOpen() and #dd.list.rows == 3 and dd.list.height == 3 * Theme.DROPDOWN_ROW + 2)
	Check("[TH2] choix désactivé : grisé avec son indice", SameColor(dd.list.rows[3].label.textColor, Theme.MUTED)
		and dd.list.rows[3].hint.text == "30 brillantes" and dd.list.rows[1].hint.text == "")
	Check("[TH2] choix courant en ambre", SameColor(dd.list.rows[1].label.textColor, Theme.GOLD))
	dd.list.rows[3]:Click()
	Check("[TH2] choix désactivé : refusé, liste ouverte", chosen == nil and dd.value == "top" and dd:IsOpen())
	dd.list.rows[2]:Click()
	Check("[TH2] choix actif : rappel, texte, liste fermée", chosen == "mid" and dd.text.text == "Au centre" and not dd:IsOpen())
	Check("[TH2] Choose refuse une valeur inconnue", dd:Choose("nope") == false)
	-- deux listes voisines (cadre et fond) : en ouvrir une referme l'autre
	local dd2 = Theme.CreateDropdown(card.control, 150, nil)
	dd2:SetOptions({ { value = "a", label = "A" }, { value = "b", label = "B" } })
	dd:Click()
	dd2:Click()
	Check("[TH2] une seule liste ouverte : la voisine se referme", dd2:IsOpen() and not dd:IsOpen())
	dd:Click()
	Check("[TH2] et inversement", dd:IsOpen() and not dd2:IsOpen())
	dd:Click()
	Check("[TH2] fermée : plus de liste ouverte retenue", not dd:IsOpen() and Theme.openDropdown == nil)

	local swatch = Theme.CreateSwatch(card.control)
	swatch:SetColor(0.1, 0.2, 0.3)
	Check("[TH2] nuancier 15 bordé, couleur posée", swatch.width == 15 and swatch.border ~= nil and Near(swatch.color.vertex[3], 0.3))
	local lock = Theme.CreateLockTag(card.control, "30 brillantes")
	Check("[TH2] verrou : texte pâle, pointillés", lock.label.text == "30 brillantes" and SameColor(lock.label.textColor, Theme.MUTED)
		and #lock.dashes > 8)
	local dashes = #lock.dashes
	lock:SetText("1")
	local visible = 0
	for _, dash in ipairs(lock.dashes) do if dash.mockHidden ~= true then visible = visible + 1 end end
	Check("[TH2] verrou raccourci : tirets en trop masqués", #lock.dashes == dashes and visible < dashes)

	-- boutons
	local primary = Theme.CreateButton(win.content, 100, 28, "Fermer", nil, "primary")
	Check("[TH2] principal : plein ambre, encre SANS ombre", SameColor(primary.bg.vertex, Theme.GOLD)
		and SameColor(primary.text.textColor, Theme.INK) and (primary.text.shadowOffset or {})[1] == 0
		and (primary.text.shadow or {})[4] == 0)
	local adv = Theme.CreateButton(win.content, 100, 28, "Partir", nil, "adventure")
	Check("[TH2] aventure : bleu, texte blanc", SameColor(adv.bg.vertex, Theme.BLUE) and adv.text.textColor[1] == 1
		and adv.text.textColor[2] == 1 and adv.text.textColor[3] == 1)
	local outline = Theme.CreateButton(win.content, 100, 28, "Réinitialiser", nil, "outline")
	Check("[TH2] contour : filet EDGE, fond transparent, texte clair", SameColor(outline.border.top.vertex, Theme.EDGE)
		and outline.bg.vertex[4] == 0 and SameColor(outline.text.textColor, Theme.LABEL))
	outline.scripts.OnEnter(outline)
	Check("[TH2] contour survolé : filet ambre", SameColor(outline.border.top.vertex, Theme.GOLD))
	outline.scripts.OnLeave(outline)
	Check("[TH2] contour quitté : filet EDGE", SameColor(outline.border.top.vertex, Theme.EDGE))
	local default = Theme.CreateButton(win.content, 100, 28, "Défaut")
	Check("[TH2] style par défaut = contour", default.style == "normal" and default.bg.vertex[4] == 0
		and SameColor(default.border.top.vertex, Theme.EDGE))
	local accent = Theme.CreateButton(win.content, 100, 28, "Terminé", nil, "accent")
	Check("[TH2] accent : filet et texte ambre, fond ambre à 7 %", SameColor(accent.border.top.vertex, Theme.GOLD)
		and SameColor(accent.text.textColor, Theme.GOLD) and SameColor(accent.bg.vertex, Theme.GOLD) and Near(accent.bg.vertex[4], 0.07))
	Check("[TH2] boutons en F_LABEL", primary.text.fontObject == Theme.F_LABEL)
	-- l'ancien panneau (CreatePanel) et le filet CreateDivider sont retirés :
	-- plus rien ne s'en sert (lot 4, le carnet et le coffre passent à CreateWindow)
	Check("[TH2] ancien panneau retiré", Theme.CreatePanel == nil and Theme.CreateDivider == nil)
end

-- 5. Rendu hors-jeu : résolution des ancres ---------------------------------
do
	Say("-- thème v2 : rendu hors-jeu")
	local ctx = { screen = { width = 1000, height = 800 } }
	local function R(region) return Snap.Rect(region, ctx) end
	local function Is(rect, l, t, w, h)
		return rect ~= nil and Near(rect.left, l) and Near(rect.top, t) and Near(rect.width, w) and Near(rect.height, h)
	end
	local box = CreateFrame("Frame", nil, UIParent)
	box:SetSize(200, 100)
	box:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -50)
	Check("[SNAP] ancre TOPLEFT sur l'écran (y du jeu vers le haut)", Is(R(box), 100, 50, 200, 100))
	local inner = CreateFrame("Frame", nil, box)
	inner:SetPoint("TOPLEFT", 10, -10)
	inner:SetPoint("BOTTOMRIGHT", -10, 10)
	Check("[SNAP] deux ancres opposées fixent la taille", Is(R(inner), 110, 60, 180, 80))
	local centered = CreateFrame("Frame", nil, box)
	centered:SetSize(20, 10)
	centered:SetPoint("CENTER")
	Check("[SNAP] CENTER sur le parent", Is(R(centered), 190, 95, 20, 10))
	local chained = CreateFrame("Frame", nil, box)
	chained:SetSize(30, 30)
	chained:SetPoint("LEFT", centered, "RIGHT", 5, 0)
	Check("[SNAP] ancre relative à une autre région", Is(R(chained), 215, 85, 30, 30))
	local corner = CreateFrame("Frame", nil, box)
	corner:SetSize(10, 10)
	corner:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 3)
	Check("[SNAP] BOTTOMRIGHT avec décalage", Is(R(corner), 288, 137, 10, 10))
	local stretch = box:CreateTexture(nil, "BACKGROUND")
	stretch:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	stretch:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	stretch:SetHeight(1)
	Check("[SNAP] filet : largeur par deux ancres, hauteur posée", Is(R(stretch), 100, 50, 200, 1))
	local all = box:CreateTexture(nil, "BACKGROUND")
	all:SetAllPoints()
	Check("[SNAP] SetAllPoints : le rectangle du parent", Is(R(all), 100, 50, 200, 100))
	local unsized = box:CreateTexture(nil, "ARTWORK")
	unsized:SetPoint("TOP")
	Check("[SNAP] texture sans taille : largeur nulle", Is(R(unsized), 200, 50, 0, 0))
	local a, b = CreateFrame("Frame", nil, box), CreateFrame("Frame", nil, box)
	a:SetPoint("LEFT", b, "RIGHT"); b:SetPoint("LEFT", a, "RIGHT")
	Check("[SNAP] ancres en boucle : pas de rectangle, pas d'erreur", R(a) == nil)
	local hiddenChild = box:CreateTexture(nil, "ARTWORK")
	inner:Hide()
	local underHidden = inner:CreateTexture(nil, "ARTWORK")
	Check("[SNAP] visibilité : un parent caché cache l'enfant", Snap.Visible(underHidden, box) == false
		and Snap.Visible(hiddenChild, box) == true)
	Check("[SNAP] codes couleur convertis", Snap.TextHtml("a |cffe8a54bB|r <c>") == 'a <span style="color:#e8a54b">B</span> &lt;c&gt;')
	Check("[SNAP] texte nu sans codes", Snap.PlainText("|cff6fcf7aOK|r|nfin") == "OK\nfin")

	-- une scène complète se rend sans erreur, gradients et textes compris
	local savedColor = rawget(_G, "CreateColor")
	_G.CreateColor = Mock.CreateColor
	local ok, frame = pcall(Snap.scenes.bricks, T)
	_G.CreateColor = savedColor
	local html, count = "", 0
	if ok then html, count = Snap.Render(frame, { title = "test" }) end
	Check("[SNAP] scène « bricks » rendue", ok and count > 150, ok and count or frame)
	Check("[SNAP] le rendu contient textes, dégradés et police Inter", html:find("Check avant le d") ~= nil
		and html:find("linear%-gradient") ~= nil and html:find("Inter%-Bold%.ttf") ~= nil and html:find("font%-weight:600") ~= nil)
	frame:Hide()
end
