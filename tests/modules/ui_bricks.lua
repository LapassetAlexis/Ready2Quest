-- Briques d'interface du socle (docs/UI.md) et du carnet : polices Inter et
-- leurs replis, jetons de la palette, dégradés, fenêtre, en-têtes, navigation,
-- onglets, recherche, cartes, interrupteurs, curseur, listes déroulantes,
-- nuancier, verrou, boutons (styles, largeur au libellé, tailles canoniques
-- « Composants 3.0 », désactivé lisible, inactif qui garde son clic, boutons
-- Azeroth), fenêtre de module et son pied, lignes de liste, statuts, bandeaux,
-- boutons-icônes, infobulles, puces, tuiles, étiquettes, pagination, bulle,
-- hauteur de texte, pastille de monnaie ; rendu hors-jeu (tests/snapshot.lua).
-- La mise en page des vraies fenêtres : ui_windows.lua.
local Check, Say, NS, QNS, Mock, ResetWorld = T.Check, T.Say, T.NS, T.QNS, T.Mock, T.ResetWorld
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()

local function Near(a, b) return math.abs((a or 0) - (b or 0)) < 0.01 end
-- socle 3.2 : ces contrôles décrivent le thème Sobre (jetons de docs/UI.md,
-- polices Inter) ; le thème Azeroth a les siens (ui_skin.lua). Rendu à la fin.
local SKIN0 = { NS.Theme.skin, QNS.Theme.skin }
NS.Theme.ApplySkin("sobre"); QNS.Theme.ApplySkin("sobre")
local function SameColor(c, token) return c and Near(c[1], token[1]) and Near(c[2], token[2]) and Near(c[3], token[3]) end
local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for i = 1, 3 do if math.abs((a[i] or -1) - (b[i] or -2)) > 0.001 then return false end end
	return true
end
-- plusieurs points d'un même sujet : une vérification, les points en échec nommés
local failed = {}
local function Want(label, ok, extra)
	if not ok then failed[#failed + 1] = extra ~= nil and (label .. " (" .. tostring(extra) .. ")") or label end
	return ok
end
local function Verdict(name) Check(name, #failed == 0, table.concat(failed, " | ")); failed = {} end

-- Ready2Quest : socle ----------------------------------------------------------
do
local Theme = NS.Theme
-- 1. Polices ---------------------------------------------------------------
do
	Say("-- thème v2 : polices")
	Want("objets de police préfixés par l'addon", Theme.F_BODY == "Ready2QuestFontBody"
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
	Want("sept rôles : graisse et taille de docs/UI.md", #wrong == 0, table.concat(wrong, ", "))
	Want("anciens noms branchés sur Inter", Theme.F_NORMAL == Theme.F_BODY and Theme.F_TITLE == "Ready2QuestFontTitle"
		and Theme.F_SMALL == "Ready2QuestFontSmall" and Theme.F_NUMBER == "Ready2QuestFontNumber"
		and tostring(_G.Ready2QuestFontNumber.font.path):find("Inter%-Bold") ~= nil)
	Want("chaque addon a son jeu (objets distincts)", rawget(_G, "Ready2QuestFontBody") ~= rawget(_G, "QuestCompanionFontBody")
		and tostring(QNS.Theme.FONT_REGULAR):find("QuestCompanion") ~= nil)
	Want("titre en Inter Bold", tostring(Theme.FONT_TITLE):find("Inter%-Bold") ~= nil)
	Want("capitales accentuées", Theme.Upper("préparation à l'œuvre") == "PRÉPARATION À L'ŒUVRE")
	Verdict("[UI] polices Inter : objets préfixés par l'addon, sept rôles (graisse, taille), anciens noms branchés, capitales accentuées")

	Mock.world.fontRefused = true
	local refused = Theme.CreateFonts("TestRefus")
	Mock.world.fontRefused = false
	Want("police refusée : repli sur la police du jeu", refused.BODY.inter == false
		and refused.BODY.name == "TestRefusFontBody" and _G.TestRefusFontBody.copiedFrom == _G.GameFontHighlightSmall,
		tostring(refused.BODY.name))
	Want("police refusée : titre copié de GameFontNormalLarge", _G.TestRefusFontTitle.copiedFrom == _G.GameFontNormalLarge)

	Mock.world.noCreateFont = true
	local bare = Theme.CreateFonts("TestSans")
	Mock.world.noCreateFont = nil
	Want("sans CreateFont : le rôle désigne la police du jeu", bare.BODY.name == "GameFontHighlightSmall"
		and bare.DISPLAY.name == "GameFontNormalHuge" and rawget(_G, "TestSansFontBody") == nil)

	-- copie impossible (pas de police du jeu de ce nom) : le nom du jeu, pas un objet vide
	Mock.world.fontRefused = true
	local saved = _G.GameFontNormalSmall
	_G.GameFontNormalSmall = nil
	local orphan = Theme.CreateFonts("TestOrphelin")
	_G.GameFontNormalSmall = saved
	Mock.world.fontRefused = false
	Want("ni Inter ni copie : jamais un objet sans police", orphan.CAPS.name == "GameFontNormalSmall", orphan.CAPS.name)
	-- client dont SetFont ne rend rien : on relit la police posée
	Mock.world.fontSilent = "refuse"
	local silentNo = Theme.CreateFonts("TestMuetRefus")
	Mock.world.fontSilent = "ok"
	local silentYes = Theme.CreateFonts("TestMuetOk")
	Mock.world.fontSilent = nil
	Want("SetFont muet, fichier refusé : repli sur la police du jeu", silentNo.BODY.inter == false
		and _G.TestMuetRefusFontBody.copiedFrom == _G.GameFontHighlightSmall)
	Want("SetFont muet, fichier posé : Inter gardée", silentYes.BODY.inter == true)
	Verdict("[UI] police refusée, SetFont muet ou sans CreateFont : repli sur la police du jeu, jamais un objet sans police")
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
	Check("[UI] jetons de la palette (docs/UI.md), anciens jetons gardés", #wrong == 0 and Theme.GOLD and Theme.BLUE and Theme.SURFACE
		and Theme.CONTROL and Theme.GOLD_DIM ~= nil, table.concat(wrong, ", "))
end

-- 3. Dégradés --------------------------------------------------------------
do
	local holder = CreateFrame("Frame", nil, UIParent)
	local tex = holder:CreateTexture(nil, "ARTWORK")
	local saved = rawget(_G, "CreateColor")
	_G.CreateColor = nil
	local mode = Theme.Gradient(tex, "HORIZONTAL", Theme.GOLD, 0, Theme.GOLD, 1)
	Want("sans CreateColor : aplat à mi-chemin", mode == nil and tex.gradient == nil and Near(tex.vertex[4], 0.5))
	_G.CreateColor = Mock.CreateColor
	mode = Theme.Gradient(tex, "VERTICAL", Theme.GOLD, 0.1, Theme.GOLD_LIGHT, 0.9)
	Want("dégradé, API récente", mode == "color" and tex.gradient[1] == "VERTICAL" and Near(tex.gradient[3].a, 0.9))
	tex.SetGradient = function() error("signature inconnue") end
	mode = Theme.Gradient(tex, "VERTICAL", Theme.GOLD, 0, Theme.GOLD, 1)
	Want("SetGradient qui échoue : aplat, sans erreur", mode == nil)
	_G.CreateColor = saved
	Verdict("[UI] dégradés : API récente ; sans CreateColor ou SetGradient en erreur, aplat sans erreur")
end

-- 4. Briques ---------------------------------------------------------------
do
	Say("-- thème v2 : briques")
	local win = Theme.CreateWindow(UIParent, 980, 680, { name = "TestTheme2Window", nav = 220, footer = 56 })
	Want("fenêtre : fond WINDOW, filet EDGE", SameColor(win.bg.vertex, Theme.WINDOW) and SameColor(win.border.top.vertex, Theme.EDGE))
	Want("fenêtre : navigation de 220 sur fond NAV", win.nav and win.nav.width == 220 and SameColor(win.nav.bg.vertex, Theme.NAV)
		and win.nav.separator ~= nil)
	Want("fenêtre : contenu à droite de la navigation", win.content and win.content.points[1].relTo == win.nav
		and win.content.points[1].relPoint == "TOPRIGHT")
	local escape = false
	for _, name in ipairs(UISpecialFrames) do if name == "TestTheme2Window" then escape = true end end
	Want("fenêtre : Échap la ferme", escape)
	Want("fenêtre : déplaçable", win.movable == true and win.scripts.OnDragStart ~= nil)
	win:Show()
	win.close:Click()
	Want("fenêtre : [×] la ferme", win.mockHidden == true and win.close.label.text == "\195\151")
	local plain = Theme.CreateWindow(UIParent, 400, 300, {})
	Want("fenêtre sans navigation", plain.nav == nil and plain.content.points[1].relTo == plain)
	Verdict("[UI] fenêtre : fond WINDOW, navigation (220) sur NAV, contenu à sa droite, Échap et [×], déplaçable")

	local header = Theme.CreatePageHeader(win.content, 758)
	header:SetTitle("Titre"); header:SetSubtitle("Sous-titre")
	Want("en-tête : titre F_DISPLAY, sous-titre F_BODY", header.title.text == "Titre" and header.title.fontObject == Theme.F_DISPLAY
		and header.subtitle.text == "Sous-titre" and header.subtitle.fontObject == Theme.F_BODY)
	Want("en-tête : filet en trois segments et halo", #header.rule.segments == 3 and #header.rule.glow == 2
		and header.rule.segments[1].gradientSpec[3] == 0 and header.rule.segments[2].gradientSpec[5] == 1)

	local brand = Theme.CreateNavBrand(win.nav, Theme.LOGO, "Ready2Quest")
	Want("marque : logo, nom F_TITLE, filet", brand.logo.texture == Theme.LOGO and brand.name.text == "Ready2Quest"
		and brand.name.fontObject == Theme.F_TITLE and brand.rule ~= nil)
	local group = Theme.CreateNavGroup(win.nav, "Préparation")
	Want("groupe : ambre, capitales", group.text == "PRÉPARATION" and SameColor(group.textColor, Theme.GOLD)
		and group.fontObject == Theme.F_CAPS)
	Verdict("[UI] en-tête (F_DISPLAY, filet en trois segments et halo), marque, groupe de navigation en capitales ambre")

	local item = Theme.CreateNavItem(win.nav, 219)
	item:SetText("Vivres")
	Want("entrée : sans interrupteur par défaut", item.power.mockHidden == true and not item.bar:IsShown())
	item:SetSelected(true)
	Want("entrée choisie : barre ambre, dégradé, libellé parchemin", item.bar.shown
		and item.tint.shown and SameColor(item.label.textColor, Theme.PARCHMENT))
	item:SetSelected(false)
	item:SetModuleState("off")
	Want("module coupé : rond gris, libellé grisé", item.power.shown and SameColor(item.power.icon.vertex, Theme.MUTED)
		and SameColor(item.label.textColor, Theme.MUTED) and not item.bar.shown)
	item:SetModuleState(true)
	Want("module actif : rond ambre", SameColor(item.power.icon.vertex, Theme.GOLD) and SameColor(item.label.textColor, Theme.TEXT))
	local powered
	item.onPower = function(_, on) powered = on end
	item.power:Click()
	Want("clic sur le rond : demande l'inverse", powered == false)
	item:SetBadge("2/3")
	Want("badge bleu, à gauche du rond", item.badge.shown and item.badge.text == "2/3" and SameColor(item.badge.textColor, Theme.BLUE)
		and item.badge.points[1].relTo == item.power)
	item:SetBadge(nil)
	Want("badge retiré", item.badge.mockHidden == true)
	item.scripts.OnEnter(item)
	Want("survol d'une entrée", item.hover.shown == true)
	item.scripts.OnLeave(item)
	Verdict("[UI] entrée de navigation : choisie, module coupé ou actif (rond), clic sur le rond, badge, survol")

	local picked
	local tabs = Theme.CreateTabs(win.content, function(id) picked = id end)
	tabs:SetTabs({ { id = "a", label = "Vérifications" }, { id = "b", label = "Alerte" }, { id = "c", label = "Fenêtre" } })
	Want("onglets : le premier choisi d'office", tabs.selected == "a" and tabs.tabs[1].underline.shown and not tabs.tabs[2].underline.shown)
	tabs.tabs[2]:Click()
	Want("onglets : clic -> rappel et soulignement", picked == "b" and tabs.tabs[2].underline.shown and not tabs.tabs[1].underline.shown
		and SameColor(tabs.tabs[2].label.textColor, Theme.PARCHMENT))
	picked = nil
	tabs:Select("c", true)
	Want("onglets : choix silencieux", picked == nil and tabs.selected == "c")
	Want("onglets : id inconnu refusé", tabs:Select("zz") == false and tabs.selected == "c")
	Want("onglets côte à côte", tabs.tabs[2].points[1].x > tabs.tabs[1].points[1].x)
	Verdict("[UI] onglets : premier choisi, clic -> rappel et soulignement, choix silencieux, id inconnu refusé")

	local searched
	local search = Theme.CreateSearchBox(win.nav, 188, "Rechercher", function(text) searched = text end)
	Want("recherche : EditBox FIELD, indicatif visible", search.kind == "EditBox" and SameColor(search.bg.vertex, Theme.FIELD)
		and search.placeholder.text == "Rechercher" and search.placeholder.mockHidden ~= true and search.autoFocus == false)
	search:SetText("viv")
	search.scripts.OnTextChanged(search, true)
	Want("recherche : rappel avec le texte, indicatif masqué", searched == "viv" and search.placeholder.mockHidden == true)
	searched = nil
	search.scripts.OnTextChanged(search, false)
	Want("recherche : pas de rappel si rien ne change", searched == nil)
	search:SetText("")
	search.scripts.OnTextChanged(search, true)
	Want("recherche vidée : indicatif revenu", searched == "" and search.placeholder.mockHidden == false)
	Verdict("[UI] recherche : indicatif, rappel avec le texte seulement s'il change")

	local section = Theme.CreateSection(win.content, "Déclenchement", "quand l'alerte apparaît")
	Want("section : capitales F_CAPS, détail entre parenthèses", section.label.text == "DÉCLENCHEMENT"
		and section.label.fontObject == Theme.F_CAPS and section.detail.text == "(quand l'alerte apparaît)")
	local bare = Theme.CreateSection(win.content, "Boutons")
	Want("section sans détail", bare.detail.mockHidden == true)

	local card = Theme.CreateSettingCard(win.content, 351)
	card:SetLabel("Son")
	Want("carte : fond ROW, libellé F_LABEL", SameColor(card.bg.vertex, Theme.ROW)
		and card.label.fontObject == Theme.F_LABEL and SameColor(card.label.textColor, Theme.LABEL) and card.control ~= nil)
	card:SetAlt(true)
	Want("carte paire : ROW_ALT", SameColor(card.bg.vertex, Theme.ROW_ALT))
	Verdict("[UI] section (capitales, détail entre parenthèses) et carte de réglage (ROW, paire en ROW_ALT)")

	local toggle = Theme.CreateToggle(card.control)
	Want("interrupteur : coupé au départ", toggle.checked == false)
	toggle:SetChecked(true)
	Want("interrupteur actif : piste ambre, curseur blanc à droite", SameColor(toggle.track.vertex, Theme.GOLD)
		and toggle.knob.vertex[1] == 1 and toggle.knob.vertex[3] == 1 and toggle.knob.points[1].point == "RIGHT")
	toggle:SetChecked(false)
	Want("interrupteur coupé : piste CONTROL, curseur MUTED à gauche", SameColor(toggle.track.vertex, Theme.CONTROL)
		and SameColor(toggle.knob.vertex, Theme.MUTED) and toggle.knob.points[1].point == "LEFT")
	toggle:SetPartial()
	Want("interrupteur partiel gardé", toggle.partial == true and toggle.checked == nil)
	Verdict("[UI] interrupteur dessiné : actif ambre à droite, coupé CONTROL à gauche, partiel")

	local changes = {}
	local slider = Theme.CreateSlider(card.control, 170, 0, 30, 5, function(v) changes[#changes + 1] = v end)
	Want("curseur : remplissage, poignée et case de valeur", SameColor(slider.fill.vertex, Theme.GOLD)
		and SameColor(slider.handle.vertex, Theme.GOLD) and slider.valueText.text == "0")
	Want("curseur : au cran près", slider:SetValue(12) == 10 and slider:SetValue(13) == 15 and slider.valueText.text == "15")
	Want("curseur : borné", slider:SetValue(99) == 30 and slider:SetValue(-4) == 0)
	Want("curseur : SetValue ne rappelle pas", #changes == 0)
	slider:SetValue(10)
	slider.scripts.OnMouseWheel(slider, 1)
	Want("molette : un cran de plus, rappel", slider.value == 15 and changes[1] == 15)
	Verdict("[UI] curseur : au cran près (décimal compris), borné, SetValue sans rappel, molette d'un cran avec rappel")
	Want("molette activée aussi sur la zone sensible de la piste", slider.hit.mouseWheel == true)
	Want("curseur au repos : pas d'OnUpdate", slider.hit.scripts.OnUpdate == nil)
	slider.hit.scripts.OnMouseDown(slider.hit)
	Want("glisser : suivi de la souris branché", slider.hit.scripts.OnUpdate ~= nil)
	slider.hit.scripts.OnMouseUp(slider.hit)
	Want("relâché : suivi débranché", slider.hit.scripts.OnUpdate == nil)
	slider:SetValue(15)
	slider.scripts.OnMouseWheel(slider, -1); slider.scripts.OnMouseWheel(slider, -1); slider.scripts.OnMouseWheel(slider, -1)
	slider.scripts.OnMouseWheel(slider, -1)
	Want("molette : bornée en bas, sans rappel inutile", slider.value == 0 and #changes == 4, #changes)
	Want("glisser : valeur sous la souris", slider:ValueAt(0) == 0 and slider:ValueAt(slider.trackWidth) == 30
		and slider:ValueAt(slider.trackWidth / 2) == 15 and slider:ValueAt(-50) == 0 and slider:ValueAt(9999) == 30)
	slider:SetValue(20)
	Want("remplissage proportionnel", Near(slider.fill.width, math.floor(slider.trackWidth * 2 / 3 + 0.5)))
	slider:SetValueText("20 s")
	Want("texte de valeur imposé", slider.valueText.text == "20 s")
	local fine = Theme.CreateSlider(card.control, 170, 0, 1, 0.1)
	Want("cran décimal sans erreur d'arrondi", fine:SetValue(0.3) == 0.3 and fine.valueText.text == "0.3")
	Verdict("[UI] curseur : glisser (suivi branché seulement pendant), molette bornée, valeur sous la souris, remplissage proportionnel")

	local chosen
	local dd = Theme.CreateDropdown(card.control, 150, function(value) chosen = value end)
	dd:SetOptions({ { value = "top", label = "En haut" }, { value = "mid", label = "Au centre" },
		{ value = "gold", label = "Cadre doré", disabled = true, hint = "30 brillantes" } })
	dd:SetValue("top")
	Want("liste : case FIELD, texte du choix, chevron", SameColor(dd.bg.vertex, Theme.FIELD) and dd.text.text == "En haut"
		and dd.chevron.texture == Theme.CHEVRON)
	Want("liste fermée au départ", not dd:IsOpen())
	dd:Click()
	Want("clic : la liste s'ouvre", dd:IsOpen() and #dd.list.rows == 3 and dd.list.height == 3 * Theme.DROPDOWN_ROW + 2)
	Want("choix désactivé : grisé avec son indice", SameColor(dd.list.rows[3].label.textColor, Theme.MUTED)
		and dd.list.rows[3].hint.text == "30 brillantes" and dd.list.rows[1].hint.text == "")
	Want("choix courant en ambre", SameColor(dd.list.rows[1].label.textColor, Theme.GOLD))
	dd.list.rows[3]:Click()
	Want("choix désactivé : refusé, liste ouverte", chosen == nil and dd.value == "top" and dd:IsOpen())
	dd.list.rows[2]:Click()
	Want("choix actif : rappel, texte, liste fermée", chosen == "mid" and dd.text.text == "Au centre" and not dd:IsOpen())
	Want("Choose refuse une valeur inconnue", dd:Choose("nope") == false)
	Verdict("[UI] liste déroulante : ouverte au clic, choix courant en ambre, désactivé grisé avec son indice et refusé, choix actif rappelé")
	-- deux listes voisines (cadre et fond) : en ouvrir une referme l'autre
	local dd2 = Theme.CreateDropdown(card.control, 150, nil)
	dd2:SetOptions({ { value = "a", label = "A" }, { value = "b", label = "B" } })
	dd:Click()
	dd2:Click()
	Want("une seule liste ouverte : la voisine se referme", dd2:IsOpen() and not dd:IsOpen())
	dd:Click()
	Want("et inversement", dd:IsOpen() and not dd2:IsOpen())
	dd:Click()
	Want("fermée : plus de liste ouverte retenue", not dd:IsOpen() and Theme.openDropdown == nil)
	Verdict("[UI] une seule liste ouverte à la fois")

	local swatch = Theme.CreateSwatch(card.control)
	swatch:SetColor(0.1, 0.2, 0.3)
	Want("nuancier bordé, couleur posée", swatch.border ~= nil and Near(swatch.color.vertex[3], 0.3))
	local lock = Theme.CreateLockTag(card.control, "30 brillantes")
	Want("verrou : texte pâle, pointillés", lock.label.text == "30 brillantes" and SameColor(lock.label.textColor, Theme.MUTED)
		and #lock.dashes > 8)
	local dashes = #lock.dashes
	lock:SetText("1")
	local visible = 0
	for _, dash in ipairs(lock.dashes) do if dash.mockHidden ~= true then visible = visible + 1 end end
	Want("verrou raccourci : tirets en trop masqués", #lock.dashes == dashes and visible < dashes)
	Verdict("[UI] nuancier et verrou (texte pâle, pointillés qui suivent sa longueur)")

	-- boutons
	local primary = Theme.CreateButton(win.content, 100, 28, "Fermer", nil, "primary")
	Want("principal : plein ambre, encre SANS ombre", SameColor(primary.bg.vertex, Theme.GOLD)
		and SameColor(primary.text.textColor, Theme.INK) and (primary.text.shadowOffset or {})[1] == 0
		and (primary.text.shadow or {})[4] == 0)
	local adv = Theme.CreateButton(win.content, 100, 28, "Partir", nil, "adventure")
	-- socle 2.11.0 : encre sombre sans ombre (le blanc tombait à 3,31:1)
	Want("aventure : bleu, encre INK sans ombre", SameColor(adv.bg.vertex, Theme.BLUE)
		and SameColor(adv.text.textColor, Theme.INK) and (adv.text.shadow or {})[4] == 0)
	local outline = Theme.CreateButton(win.content, 100, 28, "Réinitialiser", nil, "outline")
	Want("contour : filet EDGE, fond transparent, texte clair", SameColor(outline.border.top.vertex, Theme.EDGE)
		and outline.bg.vertex[4] == 0 and SameColor(outline.text.textColor, Theme.LABEL))
	outline.scripts.OnEnter(outline)
	Want("contour survolé : filet ambre", SameColor(outline.border.top.vertex, Theme.GOLD))
	outline.scripts.OnLeave(outline)
	Want("contour quitté : filet EDGE", SameColor(outline.border.top.vertex, Theme.EDGE))
	local default = Theme.CreateButton(win.content, 100, 28, "Défaut")
	Want("style par défaut = contour", default.style == "normal" and default.bg.vertex[4] == 0
		and SameColor(default.border.top.vertex, Theme.EDGE))
	local accent = Theme.CreateButton(win.content, 100, 28, "Terminé", nil, "accent")
	Want("accent : filet et texte ambre, fond ambre à 7 %", SameColor(accent.border.top.vertex, Theme.GOLD)
		and SameColor(accent.text.textColor, Theme.GOLD) and SameColor(accent.bg.vertex, Theme.GOLD) and Near(accent.bg.vertex[4], 0.07))
	Want("boutons en F_LABEL", primary.text.fontObject == Theme.F_LABEL)
	Verdict("[UI] boutons : principal ambre, aventure bleu (encre sans ombre), contour EDGE puis ambre au survol, accent ; défaut = contour")
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
	Want("ancre TOPLEFT sur l'écran (y du jeu vers le haut)", Is(R(box), 100, 50, 200, 100))
	local inner = CreateFrame("Frame", nil, box)
	inner:SetPoint("TOPLEFT", 10, -10)
	inner:SetPoint("BOTTOMRIGHT", -10, 10)
	Want("deux ancres opposées fixent la taille", Is(R(inner), 110, 60, 180, 80))
	local centered = CreateFrame("Frame", nil, box)
	centered:SetSize(20, 10)
	centered:SetPoint("CENTER")
	Want("CENTER sur le parent", Is(R(centered), 190, 95, 20, 10))
	local chained = CreateFrame("Frame", nil, box)
	chained:SetSize(30, 30)
	chained:SetPoint("LEFT", centered, "RIGHT", 5, 0)
	Want("ancre relative à une autre région", Is(R(chained), 215, 85, 30, 30))
	local corner = CreateFrame("Frame", nil, box)
	corner:SetSize(10, 10)
	corner:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 3)
	Want("BOTTOMRIGHT avec décalage", Is(R(corner), 288, 137, 10, 10))
	local stretch = box:CreateTexture(nil, "BACKGROUND")
	stretch:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	stretch:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	stretch:SetHeight(1)
	Want("filet : largeur par deux ancres, hauteur posée", Is(R(stretch), 100, 50, 200, 1))
	local all = box:CreateTexture(nil, "BACKGROUND")
	all:SetAllPoints()
	Want("SetAllPoints : le rectangle du parent", Is(R(all), 100, 50, 200, 100))
	local unsized = box:CreateTexture(nil, "ARTWORK")
	unsized:SetPoint("TOP")
	Want("texture sans taille : largeur nulle", Is(R(unsized), 200, 50, 0, 0))
	local a, b = CreateFrame("Frame", nil, box), CreateFrame("Frame", nil, box)
	a:SetPoint("LEFT", b, "RIGHT"); b:SetPoint("LEFT", a, "RIGHT")
	Want("ancres en boucle : pas de rectangle, pas d'erreur", R(a) == nil)
	Verdict("[SNAP] ancres résolues comme le jeu (TOPLEFT, deux ancres, CENTER, relative, décalages, SetAllPoints, sans taille, boucle)")
	local hiddenChild = box:CreateTexture(nil, "ARTWORK")
	inner:Hide()
	local underHidden = inner:CreateTexture(nil, "ARTWORK")
	Want("visibilité : un parent caché cache l'enfant", Snap.Visible(underHidden, box) == false
		and Snap.Visible(hiddenChild, box) == true)
	Want("codes couleur convertis", Snap.TextHtml("a |cffe8a54bB|r <c>") == 'a <span style="color:#e8a54b">B</span> &lt;c&gt;')
	Want("texte nu sans codes", Snap.PlainText("|cff6fcf7aOK|r|nfin") == "OK\nfin")
	Verdict("[SNAP] visibilité héritée du parent, codes couleur et texte nu")

	-- une scène complète se rend sans erreur, gradients et textes compris
	local savedColor = rawget(_G, "CreateColor")
	_G.CreateColor = Mock.CreateColor
	local ok, frame = pcall(Snap.scenes.bricks, T)
	_G.CreateColor = savedColor
	local html, count = "", 0
	if ok then html, count = Snap.Render(frame, { title = "test" }) end
	Check("[SNAP] scène « bricks » rendue : textes, dégradés et police Inter", ok and count > 150 and html:find("Check avant le d") ~= nil
		and html:find("linear%-gradient") ~= nil and html:find("Inter%-Bold%.ttf") ~= nil and html:find("font%-weight:600") ~= nil,
		ok and count or frame)
	frame:Hide()
end

-- 1. Fenêtre de module ------------------------------------------------------
do
	Say("-- fenêtres v2 : briques")
	local dialog = Theme.CreateDialog(UIParent, 420, 300, { name = "TestDialogV2", title = "Titre", subtitle = "Sous-titre" })
	Want("fenêtre de module : chrome, en-tête compact, pied", dialog.chrome == "dialog" and dialog.header.compact
		and dialog.footer ~= nil and dialog.footer.height == Theme.DIALOG_FOOTER)
	Want("en-tête : logo, titre F_TITLE, sous-titre F_BODY", dialog.logo ~= nil and dialog.title.text == "Titre"
		and dialog.title.fontObject == Theme.F_TITLE and dialog.subtitle.text == "Sous-titre"
		and dialog.subtitle.fontObject == Theme.F_BODY)
	Want("contenu sous l'en-tête", dialog.contentTop == -Theme.HEADER_COMPACT_HEIGHT - 1
		and dialog.innerWidth == 420 - 2 - 2 * Theme.DIALOG_PAD)
	Want("filet ambre lumineux dans l'en-tête", #dialog.header.rule.segments == 3)
	local escape = false
	for _, name in ipairs(UISpecialFrames) do if name == "TestDialogV2" then escape = true end end
	Want("Échap et [×]", escape and dialog.close ~= nil)
	local free = Theme.CreateDialog(UIParent, 300, 200, { footer = false, logo = false })
	Want("sans pied ni logo", free.footer == nil and free.logo == nil and free.header.textLeft == Theme.DIALOG_PAD)
	Verdict("[UI] fenêtre de module : chrome, en-tête compact titré (logo, F_TITLE, filet), contenu dessous, pied, Échap et [×]")

	-- pied : principal à droite, secondaires à gauche, au centre
	local done = dialog:AddFooterButton("Terminé", nil, "accent")
	local close = dialog:AddFooterButton("Fermer", nil, "outline")
	local reset = dialog:AddFooterButton("Réinitialiser", nil, "outline", "left")
	local more = dialog:AddFooterButton("Encore", nil, nil, "left")
	Want("pied : premier bouton à droite, collé au bord", select(1, done:GetPoint()) == "RIGHT"
		and select(2, done:GetPoint()) == dialog.footer and select(4, done:GetPoint()) == -Theme.DIALOG_PAD)
	Want("pied : le suivant à sa gauche", select(2, close:GetPoint()) == done and select(3, close:GetPoint()) == "LEFT")
	Want("pied : secondaires de gauche à droite", select(1, reset:GetPoint()) == "LEFT"
		and select(4, reset:GetPoint()) == Theme.DIALOG_PAD and select(2, more:GetPoint()) == reset)
	Want("pied : boutons dans le pied, hauteur commune", done:GetParent() == dialog.footer
		and done:GetHeight() == Theme.DIALOG_BUTTON_HEIGHT)
	Verdict("[UI] pied : principal à droite, les suivants à sa gauche, secondaires à gauche, hauteur commune")

	-- largeur au libellé
	local long = Theme.CreateButton(UIParent, nil, 24, "Terminer le déplacement des cadres", nil, "primary")
	Want("bouton « auto » : le libellé tient", long:GetWidth() >= long.text:GetStringWidth() + Theme.BUTTON_PAD)
	local short = Theme.CreateButton(UIParent, "auto", 24, "OK")
	Want("bouton « auto » : largeur minimale", short:GetWidth() == Theme.BUTTON_MIN)
	Want("largeur posée : respectée", Theme.CreateButton(UIParent, 90, 24, "Libellé très long à souhait"):GetWidth() == 90)

	-- en-tête compact et grand en-tête
	local big = Theme.CreatePageHeader(UIParent, 600)
	local small = Theme.CreatePageHeader(UIParent, 600, { compact = true })
	Want("grand en-tête inchangé (F_DISPLAY, 100, sans logo)", big.height == Theme.HEADER_HEIGHT
		and big.title.fontObject == Theme.F_DISPLAY and big.logo == nil and not big.compact)
	Want("en-tête compact : 64, titre F_TITLE à droite du logo", small.height == Theme.HEADER_COMPACT_HEIGHT
		and small.title.fontObject == Theme.F_TITLE and small.logo ~= nil and small.textLeft > 20 + 28)
	Verdict("[UI] bouton à la largeur du libellé (minimum, largeur posée respectée) ; grand en-tête et en-tête compact")
end

-- 2. Lignes, statuts, bandeaux, boutons-icônes, infobulles -------------------
do
	local row1 = Theme.CreateListRow(UIParent, 300, nil, { status = true, detail = true })
	local row2 = Theme.CreateListRow(UIParent, 300, 30, { icon = 24 })
	row1:SetIndex(1); row2:SetIndex(2)
	Want("ligne : carte ROW, rang pair en ROW_ALT", SameColor(row1.bg.vertex, Theme.ROW)
		and SameColor(row2.bg.vertex, Theme.ROW_ALT) and row1.height == Theme.LIST_ROW_HEIGHT and row2.height == 30)
	row2:SetIndex(3)
	Want("ligne : rang impair repasse en ROW", SameColor(row2.bg.vertex, Theme.ROW))
	Want("ligne : losange, texte après lui, détail aligné à droite", row1.status ~= nil
		and row1.textLeft > 12 + 9 and row1.detail.justifyH == "RIGHT" and select(1, row1.detail:GetPoint()) == "RIGHT")
	Want("ligne : icône, texte après elle", row2.icon ~= nil and row2.textLeft > 6 + 24 and row2.status == nil)
	local hover = Theme.CreateListRow(UIParent, 300, nil, { kind = "Button" })
	hover.scripts.OnEnter(hover)
	Want("ligne cliquable : éclairée au survol", hover.hover:IsShown())
	Verdict("[UI] ligne de liste : ROW / ROW_ALT selon le rang, losange ou icône avant le texte, détail à droite, survol")

	local d = row1.status
	local states = { ok = { Theme.GREEN, true }, info = { Theme.BLUE, true }, warn = { Theme.ORANGE, false },
		bad = { Theme.RED, false }, off = { Theme.MUTED, true }, item = { Theme.GOLD, true } }
	local wrong = {}
	for state, spec in pairs(states) do
		Theme.SetStatus(d, state)
		local role = spec[2] and "diamondLine" or "diamond"
		if not (d.state == state and d.clientRole == role and SameColor(d.vertex, spec[1]) and d:IsShown()) then
			wrong[#wrong + 1] = state
		end
	end
	Theme.SetStatus(d, "none")
	Check("[UI] statuts : forme et couleur (plein = à voir, trait = bon), « none » masqué", #wrong == 0 and not d:IsShown()
		and d.state == "none", table.concat(wrong, ","))

	local toast = Theme.CreateToast(UIParent, 200, 30)
	Want("bandeau : fond WINDOW, filet EDGE, liseré ambre", toast.chrome == "toast"
		and SameColor(toast.bg.vertex, Theme.WINDOW) and SameColor(toast.border.top.vertex, Theme.EDGE)
		and SameColor(toast.accent.vertex, Theme.GOLD))
	Want("bandeau : souris coupée hors édition, contenu après le liseré", toast.mouseEnabled == false
		and toast.contentLeft > Theme.TOAST_ACCENT)
	toast:SetAccent(Theme.RED)
	Want("bandeau : liseré de statut", SameColor(toast.accent.vertex, Theme.RED))
	toast:SetAccent(false)
	Want("bandeau : sans liseré", not toast.accent:IsShown())
	local plate = CreateFrame("Frame", nil, UIParent)
	plate:SetSize(100, 10)
	Theme.SkinToast(plate, { outset = { 10, 4, 6, 30 } })
	Want("habillage : le fond déborde du cadre", plate.bg.points[1].x == -10 and plate.bg.points[1].y == 4
		and plate.bg.points[2].x == 6 and plate.bg.points[2].y == -30 and plate.border.top.points[1].relTo == plate.bg)
	Verdict("[UI] bandeau : WINDOW, filet EDGE, liseré de statut ou aucun, souris coupée ; habillage qui déborde du cadre")

	local clicked = false
	local icon = Theme.CreateIconButton(UIParent, 22, Theme.REFRESH, function() clicked = true end, "Relancer")
	Want("bouton-icône : estompé au repos, filet EDGE", (icon.icon.alpha or 1) < 1 and SameColor(icon.border.top.vertex, Theme.EDGE))
	GameTooltip:ClearLines()
	icon.scripts.OnEnter(icon)
	Want("bouton-icône : plein et filet ambre au survol, infobulle", icon.icon.alpha == 1
		and SameColor(icon.border.top.vertex, Theme.GOLD) and GameTooltip.lines[1] == "Relancer")
	icon.scripts.OnLeave(icon)
	icon:Click()
	Want("bouton-icône : clic", clicked and (icon.icon.alpha or 1) < 1)
	Verdict("[UI] bouton-icône : estompé au repos, plein et ambre au survol avec infobulle, clic")

	GameTooltip:ClearLines()
	Theme.TooltipTitle(GameTooltip, "Titre")
	Theme.TooltipLine(GameTooltip, "Texte")
	Theme.TooltipHint(GameTooltip, "Aide", true)
	Theme.TooltipPair(GameTooltip, "Libellé", "Valeur")
	local s = GameTooltip.styled
	Check("[UI] infobulle : titre ambre, texte, aide pâle, paire", SameColor(s[1].color, Theme.GOLD)
		and SameColor(s[2].color, Theme.TEXT) and SameColor(s[3].color, Theme.MUTED_LIGHT) and s[3].wrap == true
		and s[4].right == "Valeur" and SameColor(s[4].rightColor, Theme.PARCHMENT))
end

end

-- QuestCompanion : briques du carnet et du compagnon ------------------------------
do
local Theme = QNS.Theme
-- 1. Briques ------------------------------------------------------------------
do
	Say("-- carnet et compagnon v2 : briques")
	local picked = {}
	local chips = Theme.CreateChips(UIParent, { { id = "a", label = "Toutes" }, { id = "b", label = "Kalimdor" } },
		function(id) picked[#picked + 1] = id end)
	Want("puces : une par choix, la première choisie, libellé tenu", chips.byId.a and chips.byId.b
		and chips.selected == "a" and chips.byId.a.selected and not chips.byId.b.selected
		and chips.byId.b:GetWidth() >= chips.byId.b.text:GetStringWidth() + 16 and chips.used > 0)
	Want("puce choisie : filet et texte ambre", SameColor(chips.byId.a.border.top.vertex, Theme.GOLD)
		and SameColor(chips.byId.a.text.textColor, Theme.GOLD) and SameColor(chips.byId.b.border.top.vertex, Theme.EDGE_SOFT))
	chips:Select("b", true)
	Want("puces : choix depuis le code, sans rappel", chips.selected == "b" and #picked == 0)
	chips.byId.a:Click()
	Want("puces : clic, rappel", chips.selected == "a" and picked[1] == "a")
	Want("puces : rangées sans chevauchement", select(4, chips.byId.b:GetPoint()) >= chips.byId.a:GetWidth())
	Verdict("[UI] puces : la première choisie (ambre), choix par code sans rappel, clic avec rappel, libellé tenu, sans chevauchement")

	local tile = Theme.CreateTile(UIParent, 120, 40)
	local entered = 0
	tile.onEnter = function() entered = entered + 1 end
	Want("tuile : fond ROW, filet EDGE_SOFT, sans liseré", SameColor(tile.bg.vertex, Theme.ROW)
		and SameColor(tile.border.top.vertex, Theme.EDGE_SOFT) and not tile.accent:IsShown())
	tile.scripts.OnEnter(tile)
	Want("tuile survolée : filet EDGE, rappel du module", SameColor(tile.border.top.vertex, Theme.EDGE) and entered == 1)
	tile.scripts.OnLeave(tile)
	tile:SetSelected(true)
	tile:SetAccent(Theme.BLUE)
	Want("tuile choisie : filet ambre, liseré de couleur", SameColor(tile.border.top.vertex, Theme.GOLD)
		and tile.accent:IsShown() and SameColor(tile.accent.vertex, Theme.BLUE))
	tile:SetAccent(nil)
	Want("tuile : liseré retiré", not tile.accent:IsShown())
	Verdict("[UI] tuile : ROW, filet EDGE_SOFT, EDGE au survol (rappel), ambre choisie, liseré de couleur posé et retiré")

	local tag = Theme.CreateTag(UIParent, "rare élite", Theme.BLUE)
	Want("étiquette : capitales, couleur, fond teinté, texte tenu", tag.label.text == "RARE ÉLITE"
		and SameColor(tag.label.textColor, Theme.BLUE) and Near(tag.bg.vertex[4], 0.16)
		and tag:GetWidth() >= tag.label:GetStringWidth() + 8 and tag:IsShown())
	tag:SetTag("")
	Want("étiquette vide : cachée", not tag:IsShown())
	Verdict("[UI] étiquette : capitales, couleur, fond teinté, texte tenu ; vide cachée")

	local steps = {}
	local pager = Theme.CreatePager(UIParent, function(delta) steps[#steps + 1] = delta end)
	pager:Update(0, 12, 40, 28)
	Want("pagination : position, chevron bas seul", pager.position.text == "1-12 / 40"
		and not pager.up:IsShown() and pager.down:IsShown())
	pager:Update(28, 12, 40, 28)
	Want("pagination : en bas, chevron haut seul", pager.position.text == "29-40 / 40"
		and pager.up:IsShown() and not pager.down:IsShown())
	pager:Update(0, 12, 5, 0)
	Want("pagination : une page, rien", pager.position.text == "" and not pager.up:IsShown() and not pager.down:IsShown())
	pager.down:Click(); pager.up:Click()
	Want("pagination : bas = -1, haut = 1 (comme la molette)", steps[1] == -1 and steps[2] == 1)
	-- 2.12.1 : le chevron du client seulement, tourné d'un demi-tour pour « haut »
	Want("pagination : sans atlas, pas d'image à nous", pager.up.icon.texture == nil and pager.up.icon.clientSource == nil)
	Mock.InstallAtlas(true)
	local turned = Theme.CreatePager(UIParent, function() end)
	Want("pagination : chevron du haut retourné", turned.up.icon.clientSource ~= nil
		and turned.up.icon.rotation == math.pi and turned.down.icon.rotation ~= math.pi)
	Mock.InstallAtlas(nil)
	Verdict("[UI] pagination : position, chevron utile seul, rien sur une page, bas -1 / haut 1, chevron du client retourné")

	local short = Theme.CreateBubble(UIParent, 200)
	short:SetText("Salut !")
	local bubble = Theme.CreateBubble(UIParent, 200)
	local text = string.rep("Une phrase assez longue pour passer à la ligne. ", 4)
	local height = bubble:SetText(text)
	Want("bulle : fond WINDOW, filet EDGE, filet ambre en haut, pointe", bubble.chrome == "bubble"
		and SameColor(bubble.bg.vertex, Theme.WINDOW) and SameColor(bubble.border.top.vertex, Theme.EDGE)
		and SameColor(bubble.rule.vertex, Theme.GOLD) and bubble.tail ~= nil and bubble.tailEdge ~= nil)
	Want("bulle : la hauteur suit le texte", height > short:GetHeight()
		and height >= Theme.TextHeight(bubble.text, 200 - 2 * Theme.BUBBLE_PAD, Theme.F_BODY) + 2 * Theme.BUBBLE_PAD, height)
	Want("bulle : place en plus pour des boutons", bubble:SetText(text, 30) == height + 30)
	Want("bulle : jamais plus petite que le minimum", short:SetText("") == Theme.BUBBLE_MIN)
	Verdict("[UI] bulle : thème (WINDOW, EDGE, filet ambre, pointe), hauteur qui suit le texte et les boutons, minimum")

	local fs = UIParent:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	fs:SetText("court")
	local one = Theme.TextHeight(fs, 300, Theme.F_BODY)
	fs:SetText(string.rep("mot ", 60))
	Want("hauteur de texte : une ligne, puis plusieurs", one > 0 and Theme.TextHeight(fs, 300, Theme.F_BODY) > 2 * one)
	fs:SetText("")
	Want("hauteur de texte : vide = 0", Theme.TextHeight(fs, 300) == 0)
	Verdict("[UI] hauteur de texte : une ligne, plusieurs, vide = 0")

	local bar = Theme.CreateTabs(UIParent, nil)
	bar:SetWidth(400)
	bar:SetTabs({ { id = "x", label = "Exploration" }, { id = "q", label = "Quêtes" } })
	bar:SetDim("q", true)
	Want("onglets : .text et .selected, onglet estompé en MUTED", bar.byId.x.text == bar.byId.x.label
		and bar.byId.x.selected and not bar.byId.q.selected and SameColor(bar.byId.q.text.textColor, Theme.MUTED))
	bar:Select("q", true)
	Want("onglet estompé choisi : clair quand même", SameColor(bar.byId.q.text.textColor, Theme.PARCHMENT))
	Verdict("[UI] onglet estompé en MUTED, clair quand il est choisi")

	local lock = Theme.CreateLockTag(UIParent, "")
	lock:SetText("10 jours aux trois missions", 80)
	Want("verrou trop long : coupé à la largeur donnée", lock:GetWidth() == 80 and lock.clipped
		and lock.label:GetWidth() < 80)
	lock:SetText("Palier 2", 80)
	Want("verrou court : à sa taille", lock:GetWidth() < 80 and not lock.clipped)

	local item = Theme.CreateNavItem(UIParent, 200)
	item:SetText("Jour")
	item:SetBadge("2")
	Want("entrée de navigation : .text et pastille", item.text.text == "Jour" and item.badge:IsShown())
	Verdict("[UI] verrou coupé à la largeur donnée (court : à sa taille), entrée de navigation et sa pastille")
end

end

-- QuestCompanion 3.0 : composants (docs/UI.md, « Composants 3.0 ») ------------------
do
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

-- 1. Tailles canoniques (socle) ---------------------------------------------------------------------------
do
	Say("-- qc30 composants : tailles canoniques")
	ResetWorld()
	local parent = CreateFrame("Frame", nil, UIParent)
	local S = Theme.BUTTON_SIZES
	Want("jetons : rangée d'outils 24, boutons xs 18 / sm 24 / md 28", Theme.CONTROL_HEIGHT == 24 and S.xs == 18
		and S.sm == 24 and S.md == 28 and Theme.CHIP_HEIGHT == Theme.CONTROL_HEIGHT)
	local sm = Theme.CreateButton(parent, 100, "sm", "Un")
	local md = Theme.CreateButton(parent, 100, nil, "Deux")
	local xs = Theme.CreateButton(parent, 100, "xs", "Trois")
	local n = Theme.CreateButton(parent, 100, 30, "Quatre")
	Want("bouton : taille nommée ou nombre (nil : md)", sm:GetHeight() == 24 and sm.size == "sm" and md:GetHeight() == 28
		and xs:GetHeight() == 18 and n:GetHeight() == 30 and n.size == nil)
	local chips = Theme.CreateChips(parent, { { id = "a", label = "Tous" }, { id = "b", label = "Brillants" } })
	local drop = Theme.CreateDropdown(parent, 120)
	local search = Theme.CreateSearchBox(parent, 120, "…")
	local badge = Theme.CreateCurrency(parent, { icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_02", label = "paillettes" })
	Want("puces, liste déroulante, recherche, pastille : une seule hauteur", chips:GetHeight() == 24
		and chips.byId.a:GetHeight() == 24 and drop:GetHeight() == 24 and search:GetHeight() == 24 and badge:GetHeight() == 24)
	Want("liste déroulante : hauteur à la demande", Theme.CreateDropdown(parent, 120, nil, { height = 30 }):GetHeight() == 30)
	Verdict("[UI30] tailles canoniques (docs/UI.md) : rangée d'outils 24, boutons xs/sm/md, puces, liste, recherche et pastille à une hauteur")
	badge:SetValue(40)
	local narrow = badge:GetWidth()
	badge:SetValue(12345)
	Want("pastille : chiffre, libellé, largeur au contenu", badge.value:GetText() == "12345" and badge.label:GetText() == "paillettes"
		and badge:GetWidth() > narrow and badge.amount == 12345)
	Want("pastille : icône du client", badge.icon.texture == "Interface\\Icons\\INV_Misc_Gem_Diamond_02"
		or badge.icon.file == "Interface\\Icons\\INV_Misc_Gem_Diamond_02" or badge.icon.tex == "Interface\\Icons\\INV_Misc_Gem_Diamond_02"
		or (badge.icon.GetTexture and badge.icon:GetTexture() == "Interface\\Icons\\INV_Misc_Gem_Diamond_02"))
	local plays = badge.shake and badge.shake.plays or 0
	Want("pastille secouée : secousse jouée, voile rouge", badge:Flash() == 1 and badge.shake ~= nil
		and badge.shake.plays == plays + 1 and #badge.shake.animations == #Theme.CURRENCY.shake
		and badge.shake.animations[1].kind == "Translation")
	Verdict("[UI30] pastille de monnaie : chiffre, libellé, largeur au contenu, icône du client, secousse")
	parent:Hide()
end

-- 2. État désactivé (Sobre) : lisible, opaque ; bouton inactif ----------------------------------------------
do
	Say("-- qc30 composants : désactivé et inactif (Sobre)")
	ResetWorld()
	local parent = CreateFrame("Frame", nil, UIParent)
	local D = Theme.DISABLED
	local bad = {}
	for _, style in ipairs({ "outline", "accent", "primary", "adventure" }) do
		local b = Theme.CreateButton(parent, 100, "sm", style, nil, style)
		b:SetEnabled(false)
		local filled = Theme.BUTTON_STYLES[style].filled
		local under = filled and D.bg or Theme.WINDOW
		local ratio = Theme.Contrast(D.text, under)
		if not (b.disabledLook and b.alpha == 1 and Same(b.text.textColor, D.text) and ratio >= 4.5) then
			bad[#bad + 1] = style .. string.format("=%.2f", ratio)
		end
		b:SetEnabled(true)
		if b.disabledLook or not Same(b.text.textColor, Theme.BUTTON_STYLES[style].text) then bad[#bad + 1] = style .. " (réactivé)" end
	end
	Check("[UI30] désactivé : opaque, libellé MUTED ≥ 4,5:1 (fond CONTROL ou fenêtre), quel que soit le style ; réactivé : son style",
		#bad == 0, table.concat(bad, ", "))
	local clicks = 0
	local b = Theme.CreateButton(parent, 100, "sm", "Acheter", function() clicks = clicks + 1 end, "primary")
	b:SetInactive(true, "Il te manque 5 paillettes.")
	b.scripts.OnEnter(b)
	Want("inactif : aspect désactivé, pas de survol, raison en infobulle", b.disabledLook and b.paintState == "disabled"
		and b.disabledTip == "Il te manque 5 paillettes.")
	b.scripts.OnMouseDown(b, "LeftButton")
	Want("inactif : pas d'appui", b.text.lastPoint.x == 0)
	b:GetScript("OnClick")(b)
	Want("inactif : le clic passe (le module explique)", clicks == 1)
	b:SetInactive(false)
	Want("actif de nouveau : style d'origine", not b.disabledLook and b.disabledTip == nil
		and Same(b.text.textColor, Theme.INK))
	Verdict("[UI30] bouton inactif : aspect désactivé, ni survol ni appui, raison en infobulle, le clic passe ; actif de nouveau")
	parent:Hide()
end

-- 3. Boutons Azeroth : un seul peintre d'états (carnet et capture) -------------------------------------------
do
	Say("-- qc30 composants : boutons Azeroth")
	C.Reset("azeroth")
	local AZB, INK = NS.AZEROTH_BUTTONS, NS.AZEROTH_INK
	local f = NS:OpenReserve()
	local rv = f.res.reserve
	NS:ReservePick(C.better)
	local toCodex, release = rv.toCodex, rv.release
	-- le défaut de la bêta 4 : après Enable(true), l'encre sombre du bouton plein retombait sur le rouge
	Want("« Mettre au Codex » : rouge, libellé doré (pas l'encre sombre)", toCodex.azSkin == "red"
		and toCodex.skinPaint == NS.AzerothButtonState and Same(toCodex.text.textColor, INK.goldText)
		and not Same(toCodex.text.textColor, Theme.INK) and toCodex.alpha == 1)
	Want("« Relâcher » refusé : bois délavé, libellé clair atténué", release.qcEnabled == false and release.disabledLook
		and release.azState == "disabled" and Same(release.text.textColor, AZB.offText) and release.alpha == 1)
	local off = NS.AzerothContrast(AZB.offText, NS.AzerothLuminance(AZB.off.top))
	local role = NS.AZEROTH_CONTRAST["button.off"]
	Want("libellé désactivé : ≥ 4,5:1 sur le haut du dégradé (le plus clair), rôle button.off", off >= 4.5 and role
		and role[1] == "buttonOff" and math.abs(role[2] - NS.AzerothLuminance(AZB.off.top)) < 0.001, string.format("%.2f", off))
	local onRed = NS.AzerothContrast(INK.goldText, NS.AzerothLuminance(AZB.red.top))
	local onBrown = NS.AzerothContrast(INK.goldText, NS.AzerothLuminance(AZB.brown.top))
	Want("libellé actif : ≥ 4,5:1 sur le rouge et le brun", onRed >= 4.5 and onBrown >= 4.5,
		string.format("%.2f / %.2f", onRed, onBrown))
	Verdict("[UI30] Azeroth : « Mettre au Codex » rouge libellé doré (défaut bêta 4), refusé en bois délavé, libellés ≥ 4,5:1")
	toCodex.scripts.OnEnter(toCodex)
	Want("survol : voile doré", toCodex.azState == "hover" and toCodex.azHover:IsShown())
	toCodex.scripts.OnMouseDown(toCodex, "LeftButton")
	Want("appui : voile sombre, libellé décalé", toCodex.azState == "pressed" and toCodex.azPress:IsShown()
		and toCodex.text.lastPoint.x == 1)
	toCodex.scripts.OnMouseUp(toCodex)
	toCodex.scripts.OnLeave(toCodex)
	Want("repos", toCodex.azState == "rest" and not toCodex.azHover:IsShown() and not toCodex.azPress:IsShown())
	Verdict("[UI30] Azeroth : survol (voile doré), appui (voile sombre, libellé décalé), repos")
	-- les boutons dessinés des fenêtres de capture : mêmes états
	local cap = NS:AzerothButton(UIParent, 120, 30, "Lancer", nil, "gold")
	cap:Disable()
	Want("bouton de capture désactivé : même bois délavé", cap.azState == "disabled" and Same(cap.text.textColor, AZB.offText))
	cap:Enable()
	Want("… réactivé : doré", cap.azState == "rest" and Same(cap.text.textColor, AZB.text))
	cap:Hide()
	Want("aucune erreur", next(NS.errors or {}) == nil, next(NS.errors or {}))
	Verdict("[UI30] boutons des fenêtres de capture : même bois délavé désactivé, dorés réactivés, sans erreur")
	C.Done()
end

end

-- QuestCompanion 3.1.0 : passe de cohérence (docs/UI.md, « Passe de cohérence 3.1.0 ») ------------------
do
local NS = QNS
local Theme = NS.Theme
local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for i = 1, 3 do if math.abs((a[i] or -1) - (b[i] or -2)) > 0.001 then return false end end
	return true
end

-- 1. Socle : appui des petits boutons dessinés, bouton-icône désactivé -----------------------------------
do
	Say("-- 3.1.0 : appui de [×], bouton-icône, roue crantée")
	ResetWorld()
	local parent = CreateFrame("Frame", nil, UIParent)
	local close = Theme.CreateCloseButton(parent, 22)
	local icon = Theme.CreateIconButton(parent, 24, Theme.REFRESH, nil, "Relancer")
	local gear = Theme.CreateGearButton(parent, 22, nil, "Réglages")
	for _, def in ipairs({ { "[×]", close, close.label }, { "icône", icon, icon.icon }, { "roue", gear, gear.icon } }) do
		local name, b, region = def[1], def[2], def[3]
		b.scripts.OnMouseDown(b, "LeftButton")
		Want(name .. " : contenu enfoncé d'un pixel", b.pressed and region.lastPoint.x == 1 and region.lastPoint.y == -1,
			tostring(region.lastPoint.x) .. "," .. tostring(region.lastPoint.y))
		if name ~= "roue" then
			Want(name .. " : filet ambre sombre à l'appui", Same(b.border.top.vertex, Theme.GOLD_SOFT))
		end
		b.scripts.OnMouseUp(b, "LeftButton")
		Want(name .. " : relâché, contenu à sa place", not b.pressed and region.lastPoint.x == 0 and region.lastPoint.y == 0
			and region.lastPoint.point == "CENTER")
		b.scripts.OnMouseDown(b, "RightButton")
		Want(name .. " : clic droit sans appui", not b.pressed)
	end
	Want("[×] relâché hors survol : filet EDGE", Same(close.border.top.vertex, Theme.EDGE))
	icon:SetEnabled(false)
	Want("bouton-icône désactivé : filet EDGE_SOFT, icône plus pâle", icon.disabledLook and Same(icon.border.top.vertex, Theme.DISABLED.edge)
		and (icon.icon.alpha or 1) < 0.6)
	GameTooltip:ClearLines()
	icon.scripts.OnEnter(icon)
	Want("bouton-icône désactivé : pas de survol, l'infobulle reste", Same(icon.border.top.vertex, Theme.DISABLED.edge)
		and GameTooltip.lines[1] == "Relancer")
	icon.scripts.OnMouseDown(icon, "LeftButton")
	Want("bouton-icône désactivé : pas d'appui", not icon.pressed and icon.icon.lastPoint.x == 0)
	icon.scripts.OnLeave(icon)
	icon:SetEnabled(true)
	Want("bouton-icône réactivé : repos", not icon.disabledLook and Same(icon.border.top.vertex, Theme.EDGE))
	parent:Hide()
	Verdict("[UI31] appui de [×], du bouton-icône et de la roue (contenu enfoncé, filet ambre sombre) ; bouton-icône désactivé sans survol")
end

-- 2. Infobulles par les briques du thème ; contrastes sur le fond d'infobulle ------------------------------
do
	Say("-- 3.1.0 : infobulles du suivi et de la fiche")
	ResetWorld()
	GameTooltip:ClearLines()
	NS:ShowJournalGoalTooltip(UIParent, { label = "Bestiaire", progress = "3/10", hint = { "Un loup" } })
	local st = GameTooltip.styled or {}
	local last = st[#st]
	Want("objectif : titre ambre", st[1] and Same(st[1].color, Theme.GOLD))
	Want("objectif : progression PARCHMENT (plus de blanc en dur)", st[2] and Same(st[2].color, Theme.PARCHMENT))
	Want("objectif : aide du clic en MUTED clair (TooltipHint)", last and Same(last.color, Theme.MUTED_LIGHT) and last.text == NS.L.JRN_HINT_CLICK)
	-- fond d'une infobulle du jeu (l'aperçu hors-jeu la peint ainsi, tests/snapshot.lua)
	local tipBg = { 0.03, 0.03, 0.06 }
	local bad = {}
	for name, c in pairs({ PARCHMENT = Theme.PARCHMENT, TEXT = Theme.TEXT, MUTED_LIGHT = Theme.MUTED_LIGHT, GOLD = Theme.GOLD }) do
		local r = Theme.Contrast(c, tipBg)
		if r < 4.5 then bad[#bad + 1] = name .. string.format("=%.2f", r) end
	end
	Want("encres d'infobulle ≥ 4,5:1 sur le fond du jeu", #bad == 0, table.concat(bad, ", "))
	-- aucun AddLine écrit à la main dans les fichiers passés au thème
	local root = rawget(_G, "ADDON_ROOT") or "."
	local raw = {}
	for _, file in ipairs({ "JournalTracker.lua", "TrainerCard.lua", "Tooltips.lua" }) do
		local h = io.open(root .. "/QuestCompanion/" .. file, "r")
		local src = h and h:read("*a") or ""
		if h then h:close() end
		if src:find(":AddLine%(") then raw[#raw + 1] = file end
	end
	Want("plus de AddLine à la main (JournalTracker, TrainerCard, Tooltips)", #raw == 0, table.concat(raw, ", "))
	GameTooltip:Hide()
	Verdict("[UI31] infobulles : titre, texte, aide par Theme.Tooltip* ; encres ≥ 4,5:1 sur le fond d'infobulle")
end

-- 3. Survol des commandes cliquables ; Échap et largeurs -----------------------------------------------------
do
	Say("-- 3.1.0 : survol, Échap, largeurs")
	ResetWorld()
	NS.uiStyleCache = {}
	local frame = NS:ToggleJournal(true)
	NS:SelectJournalKind("juke")
	local row = frame and frame.juke and frame.juke.rows[1]
	Want("juke-box : une rangée", row ~= nil)
	if row then
		for _, b in ipairs({ row.fav, row.add }) do
			b.scripts.OnEnter(b)
			Want("juke-box : étoile et « + » éclairés au survol", b.hover and b.hover:IsShown())
			b.scripts.OnLeave(b)
			Want("juke-box : éteints en partant", b.hover and not b.hover:IsShown())
		end
	end
	local box = frame and frame.navSummary
	Want("tableau de bord présent", box ~= nil)
	if box then
		box.pet.scripts.OnEnter(box.pet)
		Want("tableau de bord : bloc éclairé au survol", box.pet.hover and box.pet.hover:IsShown())
		box.pet.scripts.OnLeave(box.pet)
		Want("tableau de bord : éteint en partant", not box.pet.hover:IsShown())
	end
	if frame then frame:Hide() end
	NS.journalFrame, NS.uiStyleCache = nil, {}
	-- garde-manger : Échap, titre tenu ; fiche au survol : libellés dans leur colonne
	NS:CompanionUpdateVisibility()
	local pet = NS:EnsureCompanionFrame()
	local menu = pet and NS:EnsureTreatMenu()
	local registered = false
	for _, name in ipairs(UISpecialFrames or {}) do if name == "QuestCompanionTreatMenu" then registered = true end end
	Want("garde-manger : Échap le ferme", menu and registered)
	Want("garde-manger : titre à la largeur du menu", menu and menu.title.width and menu.title.width <= menu:GetWidth())
	local hover = pet and NS:EnsureCompanionHover()
	if hover then NS:CompanionRefreshHover() end
	local wide = {}
	for key, bar in pairs(hover and hover.bars or {}) do
		local room = (bar.lastPoint and bar.lastPoint.x or 0) - (bar.label.lastPoint and bar.label.lastPoint.x or 0)
		if not (bar.label.width and bar.label.width <= room and bar.label.wordWrap == false) then
			wide[#wide + 1] = key .. "=" .. tostring(bar.label.width) .. "/" .. room
		end
	end
	Want("fiche au survol : libellés d'envie bornés, sans retour à la ligne", hover and #wide == 0, table.concat(wide, ","))
	local m = pet and NS:EnsureCompanionMenu()
	Want("menu du compagnon : titre de chasse borné", m and m.huntTitle.width and m.huntTitle.width > 0)
	Verdict("[UI31] survol de l'étoile, du « + » et des blocs du tableau de bord ; garde-manger à Échap ; textes bornés")
end

-- 4. Combat : la fiche au survol et le garde-manger ne restent pas ouverts ----------------------------------
do
	Say("-- 3.1.0 : combat")
	ResetWorld()
	local saved = { rawget(_G, "InCombatLockdown"), rawget(_G, "UnitAffectingCombat") }
	local fighting = false
	_G.InCombatLockdown = function() return fighting end
	_G.UnitAffectingCombat = function() return fighting end
	NS.companionFighting = nil
	NS:CompanionUpdateVisibility()
	NS:EnsureCompanionFrame()
	NS:CompanionShowHover()
	local hover = NS.companionHover
	Want("hors combat : la fiche s'ouvre au survol", hover and hover:IsShown())
	local menu = NS:EnsureTreatMenu()
	if menu then menu:Show() end
	fighting = true
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Want("combat : fiche fermée", hover and not hover:IsShown())
	Want("combat : garde-manger fermé", menu and not menu:IsShown())
	NS:CompanionShowHover()
	Want("combat : la fiche ne s'ouvre pas au survol", hover and not hover:IsShown())
	fighting = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	NS.companionFighting = nil
	NS:CompanionShowHover()
	Want("après le combat : la fiche revient", hover and hover:IsShown())
	NS:CompanionHideHover()
	_G.InCombatLockdown, _G.UnitAffectingCombat = saved[1], saved[2]
	Verdict("[UI31] combat : fiche au survol et garde-manger fermés à l'entrée, la fiche ne s'ouvre plus avant la fin")
end
end

NS.Theme.ApplySkin(SKIN0[1]); QNS.Theme.ApplySkin(SKIN0[2])
