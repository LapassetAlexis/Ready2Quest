-- Thèmes du socle (3.2) : Sobre et Azeroth. Jetons changés sur place, police
-- des titres, accent de l'état actif, habillage forgé des fenêtres (découpe
-- en 9 tranches, ombre, cadre, coins, médaillon ; ôté en Sobre), contrastes
-- recalculés pour le thème, réglage de Ready2Quest, thème posé au chargement.
local Check, Say, NS, QNS, Mock, ResetWorld = T.Check, T.Say, T.NS, T.QNS, T.Mock, T.ResetWorld
local Theme = NS.Theme
local SKIN0 = { NS.Theme.skin, QNS.Theme.skin }
local function Same(a, b) return math.abs(a[1] - b[1]) < 1e-6 and math.abs(a[2] - b[2]) < 1e-6 and math.abs(a[3] - b[3]) < 1e-6 end

do
	Say("-- thèmes : jetons et polices")
	ResetWorld()
	Check("[SKIN] thème par défaut : Azeroth, pour les deux addons", Theme.SKIN_DEFAULT == "azeroth"
		and NS:UISkinChoice() == "azeroth" and QNS:UIStyleChoice() == "azeroth" and QNS:UISkinChoice() == QNS:UIStyle())
	Theme.ApplySkin("sobre")
	local edge, nav, title, active = Theme.EDGE, Theme.NAV, Theme.TITLE, Theme.ACTIVE
	local sobre = { { edge[1], edge[2], edge[3] }, { nav[1], nav[2], nav[3] } }
	Check("[SKIN] Sobre : titres en parchemin, état actif en ambre, police des titres : la nôtre",
		Same(Theme.TITLE, Theme.PARCHMENT) and Same(Theme.ACTIVE, Theme.GOLD) and Theme.FONT_TITLE == Theme.FONT_BOLD)
	Theme.ApplySkin("azeroth")
	Check("[SKIN] Azeroth : bord or patiné, bois sombre, titres or clair, état actif bleu arcane",
		Same(Theme.EDGE, Theme.SKIN_TOKENS.azeroth.EDGE) and Same(Theme.NAV, Theme.SKIN_TOKENS.azeroth.NAV)
		and Same(Theme.TITLE, Theme.GOLD_LIGHT) and Same(Theme.ACTIVE, Theme.BLUE))
	Check("[SKIN] les jetons changent sur place : mêmes tables, ce qui les lit suit",
		Theme.EDGE == edge and Theme.NAV == nav and Theme.TITLE == title and Theme.ACTIVE == active)
	local fonts = Theme.fonts
	Check("[SKIN] Azeroth : titres et sections en Friz Quadrata, le corps garde sa police",
		fonts.TITLE.skinFont == Theme.SKIN_FONT and fonts.DISPLAY.skinFont == Theme.SKIN_FONT
		and fonts.CAPS.skinFont == Theme.SKIN_FONT and fonts.BODY.skinFont == nil and Theme.FONT_TITLE == Theme.SKIN_FONT)
	Theme.ApplySkin("sobre")
	Check("[SKIN] retour à Sobre : les valeurs d'avant, au chiffre près ; thème inconnu : Sobre",
		Same(Theme.EDGE, sobre[1]) and Same(Theme.NAV, sobre[2]) and fonts.TITLE.skinFont == fonts.TITLE.file
		and Theme.ApplySkin("n'importe quoi") == "sobre")
end

do
	Say("-- thèmes : contrastes du thème Azeroth")
	Theme.ApplySkin("azeroth")
	-- textes posés sur le bois sombre (colonne, pied, plaque de titre) et sur l'ardoise
	local worst, where = math.huge, ""
	for _, pair in ipairs({
		{ "TEXT / NAV", Theme.TEXT, Theme.NAV, 4.5 }, { "MUTED / NAV", Theme.MUTED, Theme.NAV, 4.5 },
		{ "MUTED_LIGHT / NAV", Theme.MUTED_LIGHT, Theme.NAV, 4.5 }, { "LABEL / NAV", Theme.LABEL, Theme.NAV, 4.5 },
		{ "TITLE / NAV", Theme.TITLE, Theme.NAV, 3 }, { "TITLE / WINDOW", Theme.TITLE, Theme.WINDOW, 3 },
		{ "GOLD / NAV", Theme.GOLD, Theme.NAV, 4.5 }, { "PARCHMENT / NAV", Theme.PARCHMENT, Theme.NAV, 4.5 },
	}) do
		local ratio = Theme.Contrast(pair[2], pair[3])
		if ratio - pair[4] < worst then worst, where = ratio - pair[4], pair[1] .. " " .. string.format("%.2f", ratio) end
	end
	Check("[SKIN] Azeroth : chaque encre sur le bois sombre et l'ardoise tient son seuil (4,5 corps, 3 titres)", worst >= 0, where)
	-- le bord et l'accent se voient sur le fond (éléments graphiques : 3:1)
	Check("[SKIN] Azeroth : bord or patiné et accent arcane lisibles sur l'ardoise (≥ 3:1)",
		Theme.Contrast(Theme.EDGE, Theme.WINDOW) >= 3 and Theme.Contrast(Theme.ACTIVE, Theme.WINDOW) >= 3,
		Theme.Contrast(Theme.EDGE, Theme.WINDOW))
	local base = Theme.Luminance({ 0.051, 0.063, 0.075 })
	Check("[SKIN] Azeroth : le bois n'est pas plus clair que le fond qu'il remplace (contrastes d'avant tenus)",
		Theme.Luminance(Theme.NAV) <= base + 0.002, Theme.Luminance(Theme.NAV))
end

do
	Say("-- thèmes : l'habillage forgé des fenêtres")
	Theme.ApplySkin("azeroth")
	-- la découpe en 9 tranches
	local host = CreateFrame("Frame", nil, UIParent)
	host:SetSize(120, 40)
	local slice = Theme.Slice(host, "plate", { color = Theme.GOLD })
	local n = 0
	for _ in pairs(slice.parts) do n = n + 1 end
	local k = Theme.ART.plate.margin / Theme.ART.plate.size
	local tl = slice.parts.tl
	Check("[SKIN] découpe : neuf pièces de la même texture, coins à leur taille, teinte posée sur toutes",
		n == 9 and tl.texture == Theme.ART.plate.file and tl:GetWidth() == Theme.ART.plate.margin
		and Same({ tl:GetTexCoord() }, { 0, k, 0 }) and Same({ slice.parts.c:GetVertexColor() }, Theme.GOLD), n)
	local hollow = Theme.Slice(host, "frame", { fill = false })
	slice:SetShown(false)
	Check("[SKIN] découpe : sans centre à la demande ; cachée, toutes ses pièces le sont", hollow.parts.c == nil
		and not slice.parts.tl:IsShown() and not slice.parts.c:IsShown() and Theme.Slice(host, "line") == nil)

	local frame = Theme.CreateDialog(UIParent, 420, 300, { title = "Titre" })
	local chrome = frame.skinChrome
	Check("[SKIN] fenêtre de module en Azeroth : ombre, cadre, bords assombris, quatre coins, médaillon du logo",
		chrome ~= nil and chrome.shadow ~= nil and chrome.frame ~= nil and chrome.vignette ~= nil and #chrome.corners == 4
		and chrome.emblem ~= nil and chrome.emblem.texture == Theme.LOGO and frame.skinDressed == true)
	Check("[SKIN] le cadre, les coins et le médaillon vivent au-dessus des enfants de la fenêtre, sans souris",
		chrome.top ~= frame and chrome.top:GetFrameLevel() > frame.close:GetFrameLevel()
		and not (chrome.top.IsMouseEnabled and chrome.top:IsMouseEnabled()))
	Check("[SKIN] l'en-tête laisse la place au médaillon (pas de petit logo), titre en or clair, plaque de titre",
		frame.header.logo == nil and frame.header.textLeft == Theme.EMBLEM.text and frame.header.plate ~= nil
		and Same({ frame.title:GetTextColor() }, Theme.TITLE))
	local _, _, _, edgeAlpha = frame.border.top:GetVertexColor()
	Check("[SKIN] le filet d'un pixel s'efface sous le cadre forgé", edgeAlpha == 0, edgeAlpha)
	Theme.ApplySkin("sobre")
	Theme.DressWindow(frame)
	_, _, _, edgeAlpha = frame.border.top:GetVertexColor()
	Check("[SKIN] passage en Sobre : l'habillage se cache à l'affichage suivant, le filet revient",
		frame.skinDressed == false and not chrome.frame.parts.tl:IsShown() and not chrome.corners[1]:IsShown()
		and not chrome.emblem:IsShown() and not chrome.shadow.parts.c:IsShown() and edgeAlpha == 1)
	Theme.ApplySkin("azeroth")
	Theme.DressWindow(frame)
	Check("[SKIN] retour en Azeroth : le même habillage revient (rien n'est recréé)", frame.skinChrome == chrome
		and chrome.frame.parts.tl:IsShown() and chrome.emblem:IsShown())
	local plain = Theme.CreateWindow(UIParent, 400, 300, {})
	local own = Theme.CreateWindow(UIParent, 400, 300, {})
	own.azeroth = true
	Theme.DressWindow(own)
	local off = Theme.CreateWindow(UIParent, 400, 300, { chrome = false })
	local tiny = Theme.CreateWindow(UIParent, 30, 30, {})
	Check("[SKIN] fenêtre nue : habillée sans médaillon ; déjà habillée par son module, qui refuse, ou minuscule : rien",
		plain.skinDressed == true and plain.skinChrome.emblem == nil and own.skinDressed == false
		and not own.skinChrome.frame.parts.tl:IsShown() and off.skinChrome == nil and tiny.skinChrome == nil)
	local toast = Theme.CreateToast(UIParent, 300, 60, {})
	Check("[SKIN] bandeau : ombre et cadre, sans coins ni médaillon", toast.skinDressed == true
		and toast.skinChrome.frame ~= nil and toast.skinChrome.corners == nil and toast.skinChrome.emblem == nil)
	local sobre
	Theme.ApplySkin("sobre")
	sobre = Theme.CreateDialog(UIParent, 420, 300, { title = "Titre" })
	Check("[SKIN] fenêtre faite en Sobre : aucune texture d'habillage créée, petit logo dans l'en-tête",
		sobre.skinChrome == nil and sobre.header.logo ~= nil and sobre.skinDressed == false)
	Theme.ApplySkin("azeroth")
	for _, f in ipairs({ frame, plain, own, off, tiny, toast, sobre, host }) do f:Hide() end
end

do
	Say("-- thèmes : réglage de Ready2Quest, chargement")
	ResetWorld()
	local row
	for _, page in ipairs(NS.OPTION_PAGES) do
		if page.id == "general" then for _, r in ipairs(page.rows) do if r.key == "uiStyle" then row = r end end end
	end
	Check("[SKIN] Ready2Quest : réglage « Style de l'interface » page Général, deux choix", row ~= nil
		and #row.choices() == 2 and row.current() == "azeroth")
	row.choose("sobre")
	Check("[SKIN] choisir Sobre : gardé, thème posé", NS:DB().uiStyle == "sobre" and Theme.skin == "sobre"
		and NS:UISkinChoice() == "sobre")
	Check("[SKIN] choix inconnu refusé", NS:SetUISkin("rose") == nil and NS:DB().uiStyle == "sobre")
	Theme.ApplySkin("azeroth")
	-- (le chargeur du socle ne s'abonne qu'une fois : son gestionnaire, rejoué)
	NS.loaderFrame:GetScript("OnEvent")(NS.loaderFrame, "ADDON_LOADED", "Ready2Quest")
	Check("[SKIN] au chargement : le thème gardé est posé avant toute fenêtre", Theme.skin == "sobre")
	NS:DB().uiStyle = nil
end

NS.Theme.ApplySkin(SKIN0[1]); QNS.Theme.ApplySkin(SKIN0[2])
