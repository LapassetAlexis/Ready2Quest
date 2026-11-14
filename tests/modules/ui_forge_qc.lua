-- QuestCompanion au thème forgé (socle 3.2, Theme.Forged) : les blocs faits
-- main hors carnet Azeroth et scènes. Le filet (plaque d'or, creux de
-- l'icône, halo qui respire, compteur d'encre à chiffres d'or), les pastilles
-- de la capture express (cartes en relief, liseré qui brille, faites une
-- fois, jamais la souris), le garde-manger (cases en creux), la fiche au
-- survol et le carnet à l'écran (titres en or clair, filet lumineux), les
-- confirmations sur parchemin sans habillage forgé par-dessus. En Sobre : les
-- mêmes régions qu'avant. Contrastes mesurés sur le fond réel (le plus clair
-- et le plus sombre de la plaque).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme
local SKIN0, STYLE0 = Theme.skin, NS:DB().companionStyle
local FIELDS = { "captureNetButton", "captureExpressFeed", "treatMenu", "companionHover", "journalTracker",
	"effectsConfirm", "companionBubble", "companionFrame", "captureQueueList", "captureToast" }

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local function Same(a, b)
	return type(a) == "table" and type(b) == "table" and math.abs(a[1] - b[1]) < 1e-6
		and math.abs(a[2] - b[2]) < 1e-6 and math.abs(a[3] - b[3]) < 1e-6
end

-- le style de QuestCompanion (Azeroth = thème forgé du socle), blocs refaits
local function Fresh(forged)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle, NS.uiStyleCache = nil, {}
	if forged then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	NS:AzerothAtlasOK(true)
	NS:AzerothSceneAtlasOK(true)
	NS:DB().companionStyle = forged and "azeroth" or "sobre"
	NS:ApplyUIStyle()
	NS:CompanionData().tutoDone = true
	NS:CompanionUpdateVisibility()
end

local function Regions(root, list)
	list = list or {}
	for _, child in ipairs(root.mockChildren or {}) do
		list[#list + 1] = child
		Regions(child, list)
	end
	return list
end

local function SliceOf(slice, art)
	if type(slice) ~= "table" or type(slice.parts) ~= "table" then return false end
	local count = 0
	for _, tex in pairs(slice.parts) do
		count = count + 1
		if tex.texture ~= Theme.ART[art].file then return false end
	end
	return count >= 8
end

-- ---------------------------------------------------------------------------
-- 1. Sobre : les mêmes régions qu'avant
-- ---------------------------------------------------------------------------
do
	Say("-- thème forgé (QuestCompanion) : Sobre inchangé")
	Fresh(false)
	local s = Steps()
	s.ok("thème Sobre posé", Theme.skin == "sobre" and not NS.QCForged())
	local net = NS:EnsureCaptureNet()
	-- (relecture 3.1.0 : en Sobre, un clic ne touche pas la plaque d'encre)
	net:GetScript("OnMouseDown")(net, "LeftButton")
	net:GetScript("OnMouseUp")(net, "LeftButton")
	s.ok("filet : un clic laisse la plaque d'encre intacte, pas d'état forgé", net.forgeLook == nil and Same(net.plate.vertex, Theme.INK))
	s.ok("filet : plaque d'encre, liseré doré, ombre et halo à plat", not net.forged and net.plate and net.plate.texture == Theme.SOLID
		and Same(net.plate.vertex, Theme.INK) and net.ring and net.ring.top and net.shadow.texture == Theme.SOLID
		and net.glow.texture == Theme.SOLID and net.socket == nil and net.glowRest == nil)
	s.ok("filet : compteur doré, chiffre d'encre", Same(net.countBack.vertex, Theme.GOLD) and Same(net.count.textColor, Theme.INK))
	local feed = NS:EnsureCaptureExpressFeed()
	local row = feed.rows[1]
	s.ok("pastilles : plaque d'encre unie, nom à 9 px, sans lueur", not feed.forged and row.plate.texture == Theme.SOLID
		and row.glow == nil and row.text.points[1] and row.text.points[1].x == 9)
	NS:CaptureExpressPush("fail", "Loup", NS.L.CAPTURE_X_FLED)
	NS:CaptureExpressUpdate(NS.Now() + 0.5)
	s.ok("pastille d'échec : « échappée » en rouge", Same(row.right.textColor, Theme.RED))
	local menu = NS:EnsureTreatMenu()
	s.ok("garde-manger : cases au liseré d'un pixel, titre gris", menu and not menu.forged
		and menu.buttons.biscuit.border.top ~= nil and menu.buttons.biscuit.socket == nil and not Same(menu.title.textColor, NS.QC_FORGE.title))
	local hover = NS:EnsureCompanionHover()
	s.ok("fiche au survol : filet d'un pixel", hover and not hover.forged and hover.rule.texture == Theme.SOLID and hover.rule.height == 1)
	local tracker = NS:EnsureJournalTracker()
	s.ok("carnet à l'écran : titre sans filet lumineux", tracker and not tracker.title.forged and tracker.title.rule == nil)
	s.check("[FORGE-QC] Sobre : filet, pastilles, garde-manger, fiche et carnet à l'écran comme avant")
end

-- ---------------------------------------------------------------------------
-- 2. Le filet forgé
-- ---------------------------------------------------------------------------
do
	Say("-- thème forgé (QuestCompanion) : le filet")
	Fresh(true)
	local s = Steps()
	local F, K = NS.CAPTURE_NET_FORGE, NS.QC_FORGE
	s.ok("thème forgé posé avec le style Azeroth", Theme.skin == "azeroth" and NS.QCForged())
	local net = NS:EnsureCaptureNet()
	s.ok("plaque d'or en relief (9 tranches teintes)", net.forged and SliceOf(net.plate, "plate") and Same(net.plate.color, K.gold))
	-- relecture 3.1.0 : un clic teintait la plaque d'or en bronze pour de bon
	net:GetScript("OnMouseDown")(net, "LeftButton")
	local down = { net.plate.color[1], net.plate.color[2], net.plate.color[3] }
	net:GetScript("OnMouseUp")(net, "LeftButton")
	NS:CaptureStyleNet()
	s.ok("clic : la plaque s'assombrit à l'appui, puis reste d'or", down[1] < K.gold[1] and Same(net.plate.color, K.gold)
		and net.forgeState == "rest", net.forgeState)
	s.ok("l'icône dans un creux, plus petite que la plaque", SliceOf(net.socket, "inset")
		and net.icon.width == NS.CAPTURE_NET_SIZE - 2 * F.icon)
	local add = true
	for _, tex in pairs(net.glow.parts or {}) do if tex.blendMode ~= "ADD" then add = false end end
	s.ok("halo : l'ombre du socle en or, lumière ajoutée, allumé au repos", SliceOf(net.glow, "shadow") and add
		and net.glowRest == F.haloRest)
	s.ok("plus de liseré d'un pixel (la plaque en tient lieu)", net.ring == nil)
	s.ok("compteur : pastille d'encre, chiffres d'or clair", Same(net.countBack.vertex, Theme.INK)
		and Same(net.count.textColor, Theme.GOLD_LIGHT))
	net.scripts.OnEnter(net)
	local hot = net.glowRest == F.haloHover and Same(net.socket.color, K.rimOn)
	net.scripts.OnLeave(net)
	s.ok("survol : halo et creux plus vifs, puis retour au repos", hot and net.glowRest == F.haloRest and Same(net.socket.color, K.rim))
	net.pulseUntil = NS.Now() - 1
	net.scripts.OnUpdate(net)
	local parts = net.glow.parts
	s.ok("fin du battement : le halo revient à sa lueur de repos, pas à zéro", parts.tl.alpha == F.haloRest, parts.tl.alpha)
	net.shiny = true
	NS:CaptureStyleNet()
	s.ok("une brillante attend : filet de la pastille en or", net.countEdge.top.vertex and Same(net.countEdge.top.vertex, F.countShiny))
	net.shiny = nil
	s.ok("appui : le retour du socle reste (Theme.PressFeedback)", type(net.scripts.OnMouseDown) == "function"
		and type(net.scripts.OnMouseUp) == "function")
	s.check("[FORGE-QC] filet : plaque d'or, creux, halo qui respire, compteur d'encre ; survol, battement, brillante, appui")
end

-- ---------------------------------------------------------------------------
-- 3. Les pastilles de la capture express
-- ---------------------------------------------------------------------------
do
	Say("-- thème forgé (QuestCompanion) : les pastilles")
	Fresh(true)
	local s = Steps()
	local XF = NS.CAPTURE_EXPRESS_FORGE
	local feed = NS:EnsureCaptureExpressFeed()
	local all = true
	for _, row in ipairs(feed.rows) do
		if not (row.forged and SliceOf(row.plate, "plate") and Same(row.plate.color, XF.card)
			and row.glow and row.glow.texture == Theme.ART.dot.file and row.glow.blendMode == "ADD") then all = false end
	end
	s.ok("chaque fiche : carte en relief et lueur du liseré", feed.forged and all and #feed.rows == NS.CAPTURE_EXPRESS.rows)
	local before = #Regions(feed)
	NS:CaptureExpressPush("offer", "Raptor", "62 %")
	NS:CaptureExpressPush("ok", "Kodo", "**")
	NS:CaptureExpressPush("shiny", "Zhévra", "***")
	NS:CaptureExpressPush("fail", "Messager", NS.L.CAPTURE_X_FLED)
	NS:CaptureExpressPush("notable", "Crocilisque", NS.L.CAPTURE_X_NEW)
	NS:CaptureExpressUpdate(NS.Now() + 0.5)
	s.ok("cinq verdicts : aucune texture de plus (fiches reprises)", #Regions(feed) == before, #Regions(feed) - before)
	local mouse = feed.mouseEnabled == false
	for _, row in ipairs(feed.rows) do if row.mouseEnabled ~= false then mouse = false end end
	s.ok("jamais la souris (le fil se lit, il ne se clique pas)", mouse)
	local byKind = {}
	for index, row in ipairs(feed.rows) do byKind[feed.items[index].kind] = row end
	local fail, ok = byKind.fail, byKind.ok
	s.ok("échec : liseré et lueur rouges, « échappée » en rose pâle", fail and Same(fail.glow.vertex, Theme.RED)
		and Same(fail.right.textColor, XF.failRight))
	s.ok("prise : lueur verte, étoiles en or clair", ok and Same(ok.glow.vertex, Theme.GREEN) and Same(ok.right.textColor, XF.right))
	s.ok("le nom part après le liseré", ok and ok.text.points[1].x == XF.textLeft)
	s.check("[FORGE-QC] pastilles : cartes en relief faites une fois, liseré qui brille, couleurs du verdict, jamais la souris")
end

-- ---------------------------------------------------------------------------
-- 4. Contrastes : chaque encre sur le fond réel (le plus clair, le plus sombre)
-- ---------------------------------------------------------------------------
do
	Say("-- thème forgé (QuestCompanion) : contrastes")
	Fresh(true)
	local K, XF, F = NS.QC_FORGE, NS.CAPTURE_EXPRESS_FORGE, NS.CAPTURE_NET_FORGE
	local function Shade(tint, k) return { tint[1] * k, tint[2] * k, tint[3] * k } end
	local card = XF.card
	local pairs_ = {
		{ "nom / carte", Theme.PARCHMENT, card, 4.5 }, { "nom d'un échec / carte", Theme.MUTED_LIGHT, card, 4.5 },
		{ "brillante / carte", Theme.SHINY, card, 4.5 }, { "étoiles / carte", XF.right, card, 4.5 },
		{ "« échappée » / carte", XF.failRight, card, 4.5 },
		{ "compteur du filet / encre", F.countInk, { F.countBack[1], F.countBack[2], F.countBack[3] }, 4.5, true },
		{ "titre de la fiche / ardoise", K.title, Theme.WINDOW, 3, true },
		{ "titre du garde-manger / ardoise", K.title, Theme.WINDOW, 4.5, true },
	}
	local worst, where = math.huge, ""
	for _, p in ipairs(pairs_) do
		local backs = p[5] and { p[3] } or { Shade(p[3], 1), Shade(p[3], K.plateTop), Shade(p[3], K.plateBottom) }
		for _, back in ipairs(backs) do
			local ratio = Theme.Contrast(p[2], back)
			if ratio - p[4] < worst then worst, where = ratio - p[4], p[1] .. string.format(" %.2f", ratio) end
		end
	end
	Check("[FORGE-QC] contrastes : chaque texte tient son seuil sur son fond forgé (4,5 corps, 3 titres)", worst >= 0, where)
	-- la plaque d'or se détache de l'ardoise et du sol sombre (élément graphique : 3:1)
	Check("[FORGE-QC] la plaque d'or du filet se voit sur un fond sombre (≥ 3:1, partie la plus sombre)",
		Theme.Contrast(Shade(K.gold, K.plateBottom), Theme.WINDOW) >= 3, Theme.Contrast(Shade(K.gold, K.plateBottom), Theme.WINDOW))
end

-- ---------------------------------------------------------------------------
-- 5. Garde-manger, fiche au survol, carnet à l'écran
-- ---------------------------------------------------------------------------
do
	Say("-- thème forgé (QuestCompanion) : garde-manger, fiche, carnet à l'écran")
	Fresh(true)
	local s = Steps()
	local K = NS.QC_FORGE
	local menu = NS:EnsureTreatMenu()
	local button = menu and menu.buttons.biscuit
	s.ok("garde-manger : titre en or clair, cases en creux", menu and menu.forged and Same(menu.title.textColor, K.title)
		and SliceOf(button.socket, "inset") and Same(button.socket.color, K.rim))
	button.scripts.OnEnter(button)
	local hot = Same(button.socket.color, Theme.GOLD)
	button.scripts.OnLeave(button)
	s.ok("garde-manger : le creux s'allume au survol, puis revient", hot and Same(button.socket.color, Theme.EDGE))
	NS:TreatData().pantry.biscuit = 0
	NS:TreatMenuRefresh()
	s.ok("garde-manger : case vide grisée (désactivée), comme avant", button.alpha == 0.4)
	local hover = NS:EnsureCompanionHover()
	s.ok("fiche au survol : nom en or clair, filet lumineux", hover and hover.forged and Same(hover.title.textColor, K.title)
		and hover.rule.texture == Theme.ART.line.file and hover.rule.height == K.line.h)
	NS:CompanionShowHover()
	s.ok("fiche au survol : la mise en page place le filet", hover.rule.lastPoint ~= nil and hover:IsShown())
	local tracker = NS:EnsureJournalTracker()
	local rule = tracker and tracker.title.rule
	s.ok("carnet à l'écran : titre en or clair sur un filet lumineux qui part de la droite", rule
		and rule.texture == Theme.ART.line.file and rule.texCoord and rule.texCoord[1] == 1 and rule.texCoord[2] == 0
		and Same(tracker.title.text.textColor, K.title))
	s.check("[FORGE-QC] garde-manger en creux, fiche et carnet à l'écran : titres or clair et filets lumineux")
end

-- ---------------------------------------------------------------------------
-- 6. Les confirmations sur parchemin : leur bois, sans l'habillage forgé
-- ---------------------------------------------------------------------------
do
	Say("-- thème forgé (QuestCompanion) : confirmations sur parchemin")
	-- 3.1.0 : le parchemin est l'ancien habillage, derrière le drapeau
	T.Legacy(true)
	Fresh(true)
	local s = Steps()
	local frame = NS:EnsureEffectsConfirm()
	local chrome = frame and frame.skinChrome
	s.ok("confirmation au style Azeroth", frame and frame.azDialog and frame.uiStyle == "azeroth")
	s.ok("pas d'habillage forgé (cadre, ombre, coins, médaillon cachés)", frame.azeroth and frame.skinDressed == false
		and (not chrome or (chrome.frame.shown == false and chrome.shadow.shown == false
			and (not chrome.emblem or chrome.emblem.mockHidden))))
	local header = frame.header
	s.ok("pas de plaque de titre sombre sous l'encre du parchemin", not header.plate or header.plate.mockHidden)
	s.ok("le titre reprend la marge de la fenêtre (plus de place au médaillon)", header.textLeft == Theme.DIALOG_PAD
		and header.title.lastPoint.x == Theme.DIALOG_PAD and header.subtitle.lastPoint.x == Theme.DIALOG_PAD)
	frame:Show()
	if frame.hooks and frame.hooks.OnShow then frame.hooks.OnShow(frame) end
	s.ok("réaffichée : toujours sans habillage forgé", frame.skinDressed == false)
	s.check("[FORGE-QC] confirmations sur parchemin : le bois seul, titre lisible à sa marge")
	T.Legacy(false)
end

-- remise en état
Fresh(false)
Mock.InstallAtlas(nil)
NS:AzerothAtlasOK(true)
NS:AzerothSceneAtlasOK(true)
NS:DB().companionStyle = STYLE0
Theme.ApplySkin(SKIN0)
