-- Thèmes du socle (3.2) : Sobre et Azeroth. Jetons changés sur place, police
-- des titres, accent de l'état actif, cadre en bois posé à l'affichage (et
-- ôté en Sobre), fenêtres déjà habillées laissées, atlas absent, contrastes
-- recalculés pour le thème, réglage de Ready2Quest, thème posé au chargement.
local Check, Say, NS, QNS, Mock, ResetWorld = T.Check, T.Say, T.NS, T.QNS, T.Mock, T.ResetWorld
local Theme = NS.Theme
local SKIN0 = { NS.Theme.skin, QNS.Theme.skin }
local savedTexture = rawget(_G, "C_Texture")
local function Same(a, b) return math.abs(a[1] - b[1]) < 1e-6 and math.abs(a[2] - b[2]) < 1e-6 and math.abs(a[3] - b[3]) < 1e-6 end
local function Atlases(missing)
	_G.C_Texture = { GetAtlasInfo = function(name) if name ~= missing then return { width = 64, height = 64 } end end }
	Theme.ResetAtlasCache()
end

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
	Say("-- thèmes : le cadre en bois")
	Atlases()
	Theme.ApplySkin("azeroth")
	local frame = Theme.CreateDialog(UIParent, 420, 300, { title = "Titre" })
	Check("[SKIN] fenêtre faite en Azeroth : plaque de titre, titre en or clair",
		frame.header.plate ~= nil and Same({ frame.title:GetTextColor() }, Theme.TITLE))
	Theme.DressWindow(frame)
	local wood = frame.skinWood
	local shown = wood ~= nil
	for _, key in ipairs(Theme.WOOD_KEYS) do shown = shown and wood[key] ~= nil and wood[key]:IsShown() end
	Check("[SKIN] à l'affichage : huit pièces de bois autour de la fenêtre, hors du contenu", shown and frame.skinDressed == true)
	Theme.ApplySkin("sobre")
	Theme.DressWindow(frame)
	local hidden = true
	for _, key in ipairs(Theme.WOOD_KEYS) do if wood[key]:IsShown() then hidden = false end end
	Check("[SKIN] passage en Sobre : le bois s'ôte à l'affichage suivant", hidden and frame.skinDressed == false)
	Theme.ApplySkin("azeroth")
	Theme.DressWindow(frame)
	Check("[SKIN] retour en Azeroth : les mêmes pièces reviennent (rien n'est recréé)", frame.skinWood == wood and wood.tl:IsShown())
	local small = Theme.CreateWindow(UIParent, 120, 90, {})
	Theme.DressWindow(small)
	local own = Theme.CreateWindow(UIParent, 400, 300, {})
	own.azeroth = true
	Theme.DressWindow(own)
	local off = Theme.CreateWindow(UIParent, 400, 300, { wood = false })
	Theme.DressWindow(off)
	Check("[SKIN] pas de bois : fenêtre trop petite, fenêtre déjà habillée par son module, fenêtre qui le refuse",
		small.skinWood == nil and own.skinDressed == false and not (own.skinWood and own.skinWood.tl:IsShown())
		and off.skinWood == nil)
	Atlases(Theme.WOOD.top)
	local bare = Theme.CreateWindow(UIParent, 400, 300, {})
	Theme.DressWindow(bare)
	Check("[SKIN] une pièce du bois absente du client : pas de bois, la fenêtre est construite quand même",
		bare ~= nil and bare.skinWood == nil and bare.bg ~= nil and Theme.SkinWoodOK() == false)
	for _, f in ipairs({ frame, small, own, off, bare }) do f:Hide() end
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

_G.C_Texture = savedTexture
Theme.ResetAtlasCache()
NS.Theme.ApplySkin(SKIN0[1]); QNS.Theme.ApplySkin(SKIN0[2])
