-- QuestCompanion 2.8.2 : retours en jeu sur le style Azeroth. Contraste
-- mesuré (table ns.AZEROTH_CONTRAST recalculée ici, seuils WCAG), bulle sur
-- le parchemin des hauts faits (130661) sous le texte, habit Sobre masqué,
-- /qc debug bulle ; encres par rôle (hauts faits, Ménagerie, en-têtes,
-- guide, bandeaux) ; marge des catégories ; infobulles ancrées à la ligne
-- (ou sous le bouton) ; guide : titre, filigrane, texte sans chevauchement ;
-- modèle du compagnon dans l'ouverture du cadre (4 tailles, 3 cadrages) ;
-- verdict : tête dans le trou du cadre d'icône, niveau au centre de l'écu.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local RT = { saved = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitFullName", "UnitExists", "UnitIsPlayer", "UnitLevel", "InCombatLockdown",
	"UnitAffectingCombat", "C_Texture", "time" }
for _, name in ipairs(GLOBALS) do RT.saved[name] = rawget(_G, name) end
local INK = NS.AZEROTH_INK
local FIELDS = { "journalFrame", "trainerFrame", "companionFrame", "companionBubble", "captureResult" }

function RT.Reset(style)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	NS.errors = {}
	NS.carnetMissing = {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-00000001" end end
	_G.UnitName = function(unit) if unit == "player" then return "Dyokrion" end end
	_G.UnitFullName = function(unit) if unit == "player" then return "Dyokrion", "Aeternalis" end end
	_G.UnitExists = function(unit) return unit == "player" end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.time = function() return 1800000000 end
	if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
	NS:DB().companionSize = nil
	NS:DB().companionFraming = nil
	NS:CompanionData().tutoDone = true
end
function RT.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = RT.saved[name] end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	NS:DB().companionSize = nil
	NS:DB().companionFraming = nil
	ResetWorld()
end
local function NoErrors()
	local list = {}
	for _, e in ipairs(NS.errors or {}) do list[#list + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
	return #list == 0, table.concat(list, " | ")
end
local function Point(region, name)
	for _, p in ipairs(region.points or {}) do if p.point == name then return p end end
	return nil
end
local function Same(c, ref)
	if not (c and ref) then return false end
	for i = 1, 3 do if math.abs((c[i] or -1) - ref[i]) > 0.001 then return false end end
	return true
end
-- Luminance et contraste WCAG 2.x, recalculés ici (sans les fonctions de l'addon)
local function Lin(c) if c <= 0.03928 then return c / 12.92 end return ((c + 0.055) / 1.055) ^ 2.4 end
local function Lum(c) return 0.2126 * Lin(c[1]) + 0.7152 * Lin(c[2]) + 0.0722 * Lin(c[3]) end
local function Ratio(c, bg)
	local a, b = Lum(c), bg
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end
local function Speak()
	NS:CompanionUpdateVisibility()
	NS:EnsureCompanionFrame()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	return NS:CompanionSay("EAT", { force = true })
end

-- 1. La table des contrastes : chaque rôle tient son seuil -------------------------------------------
do
	Say("-- 2.8.2 : contraste mesuré, par rôle")
	Check("[RT] formule WCAG : noir sur blanc 21:1", math.abs(Ratio({ 0, 0, 0 }, 1) - 21) < 0.01
		and math.abs(NS.AzerothContrast({ 1, 1, 1 }, 0) - 21) < 0.01)
	local count, bad = 0, {}
	for key, role in pairs(NS.AZEROTH_CONTRAST) do
		count = count + 1
		local color = INK[role[1]]
		local ratio = color and Ratio(color, role[2]) or 0
		local min = role[4] >= 16 and math.min(role[3], 3) or role[3]
		if not color or ratio < min or role[3] < (role[4] >= 16 and 3 or 4.5) then
			bad[#bad + 1] = key .. "=" .. string.format("%.2f", ratio)
		end
		if color and math.abs(NS.AzerothContrast(color, role[2]) - ratio) > 0.001 then bad[#bad + 1] = key .. " (formule)" end
	end
	Check("[RT] au moins 55 rôles mesurés", count >= 55, tostring(count))
	Check("[RT] chaque rôle : 4,5:1 (texte courant) ou 3:1 (16 px et plus) sur le pire fond", #bad == 0, table.concat(bad, ", "))
	local roles = { "bubble.text", "bubble.name", "feat.desc", "feat.reward", "feat.date", "feat.scopeAccount", "featOpen.desc",
		"nav.label", "nav.badge", "men.no", "men.name", "men.detail", "seal.title", "seal.detail", "seal.trainer", "guide.text",
		"guide.head", "guide.title", "page.title", "banner.title", "banner.name", "verdict.title", "verdict.name", "cplate.mood",
		"trainer.band", "tile.text" }
	local missing = {}
	for _, key in ipairs(roles) do if not NS.AZEROTH_CONTRAST[key] then missing[#missing + 1] = key end end
	Check("[RT] tous les rôles signalés sont dans la table", #missing == 0, table.concat(missing, ", "))
	-- avant : les mêmes encres sans voile tombaient sous le seuil (mesures 2.8.1)
	Check("[RT] sans voile, même le noir ne tenait pas sur le parchemin (0,149)", Ratio({ 0, 0, 0 }, 0.149) < 4.5)
end

-- 2. La bulle : parchemin des hauts faits, sous le texte, habit Sobre masqué ---------------------------
do
	Say("-- 2.8.2 : bulle sur le parchemin des hauts faits")
	RT.Reset()
	Check("[RT] le compagnon parle", Speak() == true)
	local bubble = NS.companionBubble
	local skin = bubble and bubble.azTalk
	Check("[RT] bulle affichée, habillée Azeroth", bubble and bubble:IsShown() and bubble.azBubble and skin ~= nil)
	local bg = skin and skin.bg
	Check("[RT] parchemin 130661 (ou 130662), sur la bulle elle-même, affiché", bg and (bg.texture == 130661 or bg.texture == 130662)
		and bg:GetParent() == bubble and bg:IsShown() and bg.vertex[4] == 1 and not bg.atlas)
	Check("[RT] … couche BACKGROUND, sous le nom et le texte (OVERLAY)", bg.drawLayer == "BACKGROUND"
		and skin.text.drawLayer == "OVERLAY" and skin.name.drawLayer == "OVERLAY")
	Check("[RT] … aplat clair dessous, voile crème au-dessus", skin.backdrop.subLevel < bg.subLevel and skin.veil.subLevel > bg.subLevel
		and skin.veil:IsShown() and math.abs(skin.veil.vertex[4] - INK.alpha.bubble) < 0.001)
	local c = bg.texCoord
	local texRatio = (c[2] - c[1]) * 512 / ((c[4] - c[3]) * 256)
	Check("[RT] … recadré sans déformation (rapport de la bulle)", math.abs(texRatio - bubble:GetWidth() / bubble:GetHeight()) < 0.05,
		string.format("%.2f vs %.2f", texRatio, bubble:GetWidth() / bubble:GetHeight()))
	Check("[RT] habit Sobre masqué : fond sombre, filet, pointe, texte, bordure", bubble.bg.mockHidden and bubble.rule.mockHidden
		and bubble.tail.mockHidden and bubble.tailEdge.mockHidden and bubble.text.mockHidden and bubble.border.top.mockHidden)
	Check("[RT] encres de la bulle : texte et nom (table des contrastes)", Same(skin.text.textColor, INK[NS.AZEROTH_CONTRAST["bubble.text"][1]])
		and Same(skin.name.textColor, INK[NS.AZEROTH_CONTRAST["bubble.name"][1]]))
	Check("[RT] plus de Talking Heads (1111217) sur la bulle", bg.texture ~= 1111217 and NS.AZEROTH_TALK_FILE.file == 130661)
	-- /qc debug bulle
	local printed = {}
	local print0 = NS.Print
	NS.Print = function(_, text) printed[#printed + 1] = tostring(text) end
	local lines = NS:AzerothDebugCommand("bulle")
	NS.Print = print0
	local all = table.concat(lines or {}, "\n")
	Check("[RT] /qc debug bulle : état, couches, alpha, fichier", #printed >= 8 and all:find("az.parchment: shown", 1, true) ~= nil
		and all:find("tex=130661", 1, true) ~= nil and all:find("sobre.bg: hidden", 1, true) ~= nil
		and all:find("BACKGROUND/1", 1, true) ~= nil and all:find("azeroth", 1, true) ~= nil, all)
	Check("[RT] /qc debug (autre mot) : l'aide", NS:AzerothDebugCommand("") == nil)
	Check("[RT] la commande est enregistrée", type(NS.EXTRA_COMMANDS.debug) == "function")
	local ok, errs = NoErrors()
	Check("[RT] bulle sans erreur", ok, errs)
	-- retour au Sobre : l'habit Sobre revient
	NS:DB().companionStyle = "sobre"
	NS:ApplyUIStyle()
	Check("[RT] Sobre : la bulle reprend son habit", not bubble.azBubble and not bubble.bg.mockHidden and skin.bg.mockHidden)
end

-- 3. Le modèle du compagnon dans l'ouverture du cadre (tailles, cadrages) ------------------------------
do
	Say("-- 2.8.2 : modèle dans le cadre du compagnon")
	RT.Reset()
	-- un client qui sait afficher une créature : PlayerModel avec SetCreature
	local create = _G.CreateFrame
	_G.CreateFrame = function(kind, ...)
		local f = create(kind, ...)
		if kind == "PlayerModel" and f then f.SetCreature = function() return true end; f.SetDisplayInfo = function() return true end end
		return f
	end
	NS:CompanionUpdateVisibility()
	local frame = NS:EnsureCompanionFrame()
	_G.CreateFrame = create
	Check("[RT] le cadre a un modèle 3D", frame and frame.model ~= nil)
	local R = NS.AZEROTH_RING
	local hole = NS.AZEROTH_RING_HOLE
	local fw = frame:GetWidth()
	-- 2.13.1 : l'anneau décalé de R.x pour centrer son ouverture
	local left, top = fw / 2 - R.w / 2 + (R.x or 0), R.y + R.h / 2
	local hx0, hx1 = left + R.w * hole.l, left + R.w * hole.r
	local hy0, hy1 = top - R.h * hole.t, top - R.h * hole.b
	local function Inside()
		local model = frame.model
		local p = Point(model, "TOPLEFT")
		if not p or p.relTo ~= frame then return false, "ancre" end
		local x0, y0 = p.x, p.y
		local x1, y1 = x0 + model:GetWidth(), y0 - model:GetHeight()
		local ok = x0 >= hx0 and x1 <= hx1 and y0 <= hy0 and y1 >= hy1 and model:GetWidth() >= 40
		return ok, string.format("%s,%s %s×%s dans %.1f..%.1f / %.1f..%.1f", x0, y0, model:GetWidth(), model:GetHeight(), hx0, hx1, hy0, hy1)
	end
	local okAll, info = true, ""
	for size = 1, #NS.COMPANION_SIZES do
		NS:DB().companionSize = size
		NS:CompanionApplySize()
		for _, framing in ipairs(NS.COMPANION_FRAMINGS) do
			NS:CompanionSetFraming(framing)
			local ok, why = Inside()
			if not ok or frame.model.framingZoom ~= NS.COMPANION_FRAMING_ZOOM[framing] then okAll, info = false, size .. "/" .. framing .. " " .. why end
		end
	end
	Check("[RT] 4 tailles × 3 cadrages : le modèle dans l'ouverture du cadre", okAll, info)
	Check("[RT] le modèle sous l'anneau (niveaux)", frame.model.level < frame.azSkin.level)
	NS:CompanionPlaceModel(2, -1)
	local p = Point(frame.model, "TOPLEFT")
	Check("[RT] les effets (rebond) décalent depuis l'ouverture", p.x == frame.modelBase.x + 2 and p.y == frame.modelBase.y - 1)
	NS:CompanionPlaceModel(0, 0)
	Check("[RT] cadrage reposé à la fin du chargement (OnModelLoaded)", frame.model.hooks and type(frame.model.hooks.OnModelLoaded) == "function"
		and type(frame.model.framing) == "function")
	-- 2.13.1 : l'humeur est dans son rabat, à l'encre de sa teinte ; la bande claire n'a plus de voile
	local tabInk = NS.AZEROTH_MOOD_TAB[frame.azSkin.moodTab.mood or "happy"].ink
	Check("[RT] plaque : humeur à l'encre de son rabat", not frame.azSkin.moodBand:IsShown()
		and Same(frame.mood.textColor, tabInk))
	NS:DB().companionStyle = "sobre"
	NS:ApplyUIStyle()
	p = Point(frame.model, "TOPLEFT")
	Check("[RT] Sobre : le modèle reprend sa place d'avant", frame.modelBase == NS.COMPANION_MODEL_BASE and p.x == 4 and p.y == -4
		and frame.model:GetWidth() == NS.COMPANION_MODEL_BASE.w)
end

-- 4. Le bandeau de verdict : tête centrée dans le cadre, niveau dans l'écu ---------------------------
do
	Say("-- 2.8.2 : verdict, portrait et niveau centrés")
	RT.Reset()
	local banner = NS:AzerothVerdict(UIParent, 330, 107)
	local anchor = banner.portraitAnchor
	local size = anchor:GetWidth()
	-- 2.9.0 : plus de modèle 3D, le portrait fixe (icône du type) dans le trou
	local tl, br = Point(banner.portraitIcon, "TOPLEFT"), Point(banner.portraitIcon, "BOTTOMRIGHT")
	local cx, cy = (tl.x + br.x) / 2, (tl.y + br.y) / 2
	Check("[RT] tête : dans le trou du cadre d'icône, centrée", tl.relTo == anchor and br.relTo == anchor
		and math.abs(cx - size / 2) <= 1 and math.abs(cy + size / 2) <= 1
		and tl.x >= size * NS.AZEROTH_ICON_HOLE.l - 0.5 and br.x <= size * NS.AZEROTH_ICON_HOLE.r + 0.5,
		string.format("centre %.1f,%.1f taille %s", cx, cy, size))
	Check("[RT] portrait fixe : pas de modèle 3D", banner.portrait == nil)
	banner:SetCreature({ npcID = 7001, type = "Bête" })
	Check("[RT] portrait fixe : l'icône du type, montrée", banner.portraitIcon:IsShown()
		and banner.portraitIcon.texture == NS.MENAGERIE_TYPE_ICONS["Bête"])
	banner:SetShield("gold")
	banner:SetLevel(12)
	local lp = Point(banner.levelText, "CENTER")
	local face = NS.AZEROTH_SHIELD_FACE
	local ex = math.floor(banner.shield:GetWidth() * face.x + 0.5)
	local ey = math.floor(banner.shield:GetHeight() * face.y + 0.5) + face.digits
	Check("[RT] niveau : au centre visuel de l'écu (plus 3 px trop haut)", lp and lp.relTo == banner.shield and lp.x == ex and lp.y == ey
		and lp.y < 3 and lp.x >= 0, lp and (lp.x .. "," .. lp.y))
	Check("[RT] verdict : titre à l'encre sur sa bande éclaircie", banner.titleBand and banner.titleBand:IsShown()
		and Same(banner.title.textColor, INK[NS.AZEROTH_CONTRAST["verdict.title"][1]])
		and math.abs(banner.titleBand.vertex[4] - INK.alpha.strip) < 0.001)
	local toast = NS:AzerothCreateBanner({})
	Check("[RT] bandeau : bande du titre éclaircie, encre", toast.titleBand and Same(toast.title.textColor, INK.ink))
end

-- 5. Le carnet : encres, voiles, marge des catégories, infobulles, guide ------------------------------
do
	Say("-- 2.8.2 : carnet, lisibilité et placement")
	RT.Reset()
	local f = NS:ToggleJournal(true)
	Check("[RT] carnet Azeroth", f and f.azeroth)
	Check("[RT] voile des pages et de la colonne", f.content.azVeil and math.abs(f.content.azVeil.vertex[4] - INK.alpha.page) < 0.001
		and f.nav.azVeil and math.abs(f.nav.azVeil.vertex[4] - INK.alpha.nav) < 0.001)
	Check("[RT] en-tête : titre à l'encre (grand titre)", Same(f.header.title.textColor, INK[NS.AZEROTH_CONTRAST["page.title"][1]]))
	-- catégories de gauche : marge
	local item = f.sections.feats
	local lp = Point(item.label, "LEFT")
	Check("[RT] catégorie : texte à 12 px du bord de son fond", lp and lp.relTo == item.azBg and lp.x == NS.CARNET_LAYOUT.navPad
		and lp.x >= 10 and lp.x <= 14)
	item:SetBadge("2")
	local bp = Point(item.badge, "RIGHT")
	Check("[RT] catégorie : compteur dans le fond, 10 px du bord droit", bp and bp.relTo == item.azBg and bp.x == -NS.CARNET_LAYOUT.navBadgePad)
	-- hauts faits
	NS:SelectJournalKind("feats")
	local hf = f.feats
	local row = hf.rows[1]
	row.entry.got = { at = 1800000000 }
	NS.CARNET_PAGE_POSTS.feats(NS, f)
	Check("[RT] haut fait obtenu : fond voilé, encres par rôle", row.azVeil and row.azVeil:IsShown()
		and Same(row.desc.textColor, INK[NS.AZEROTH_CONTRAST["feat.desc"][1]])
		and Same(row.reward.textColor, INK[NS.AZEROTH_CONTRAST["feat.reward"][1]])
		and Same(row.date.textColor, INK[NS.AZEROTH_CONTRAST["feat.date"][1]]) and Same(row.name.textColor, INK.white))
	row.entry.got = nil
	NS.CARNET_PAGE_POSTS.feats(NS, f)
	Check("[RT] pas encore : parchemin sombre, texte clair", row.azBg.texture == 130660 and not row.azVeil:IsShown()
		and Same(row.desc.textColor, INK[NS.AZEROTH_CONTRAST["featOpen.desc"][1]])
		and Same(row.reward.textColor, INK[NS.AZEROTH_CONTRAST["featOpen.reward"][1]]))
	Check("[RT] étiquette Compte : fond brun opaque, bande assombrie", row.scope.bg and row.scope.bg:IsShown()
		and row.scope.bg.vertex[4] >= 0.9 and row.scope.azBg.vertex[1] == 0.5)
	-- infobulle d'une ligne
	NS:JournalFeatsTip(row)
	local tp = GameTooltip.lastPoint
	Check("[RT] infobulle d'un haut fait : à droite de la ligne survolée", tp and tp.relTo == row and tp.point == "TOPLEFT"
		and tp.relPoint == "TOPRIGHT" and tp.x == NS.JOURNAL_TIP_GAP)
	local getRight = UIParent.GetRight
	UIParent.GetRight = function() return 1920 end
	row.GetRight = function() return 1800 end
	NS:JournalFeatsTip(row)
	tp = GameTooltip.lastPoint
	Check("[RT] … pas la place à droite : sous la ligne", tp.relTo == row and tp.point == "TOPRIGHT" and tp.relPoint == "BOTTOMRIGHT")
	row.GetRight, UIParent.GetRight = nil, getRight
	-- ménagerie
	NS:SelectJournalKind("menagerie")
	local men = f.men
	local mrow = men.items[1]
	mrow.entry = { known = true, class = "elite", npc = 1 }
	NS.CARNET_PAGE_POSTS.menagerie(NS, f)
	Check("[RT] Créatures : ligne connue voilée, n° et type à l'encre, nom à sa rareté (sombre)", mrow.azVeil and mrow.azVeil:IsShown()
		and Same(mrow.no.textColor, INK[NS.AZEROTH_CONTRAST["men.no"][1]]) and Same(mrow.label.textColor, INK.rElite)
		and Same(mrow.detail.textColor, INK[NS.AZEROTH_CONTRAST["men.detail"][1]]))
	mrow.entry = { known = false, npc = 2 }
	NS.CARNET_PAGE_POSTS.menagerie(NS, f)
	Check("[RT] Créatures : jamais croisée, texte clair", Same(mrow.label.textColor, INK.light) and not mrow.azVeil:IsShown())
	local strip = men.collection
	Check("[RT] sceau : bloc voilé (titre, détail, dresseur lisibles)", strip and strip.azVeil and strip.azVeil:IsShown()
		and Same(strip.title.textColor, INK.ink) and Same(strip.trainer.textColor, INK.amber))
	local typeButton = men.types and men.types.buttons[1]
	local enter = typeButton and typeButton:GetScript("OnEnter")
	Check("[RT] boutons de type présents", enter ~= nil)
	if enter then
		enter(typeButton)
		tp = GameTooltip.lastPoint
		Check("[RT] infobulle d'un type : sous le bouton (la rangée de commandes reste visible)", tp.relTo == typeButton and tp.point == "TOP"
			and tp.relPoint == "BOTTOM")
	end
	-- guide : titre, filigrane, texte
	NS:SelectJournalKind("guide")
	local guide = f.guide
	local G = NS.CARNET_GUIDE_LAYOUT
	local TOP = NS.JOURNAL_LAYOUT.top
	local bandBottom = TOP + G.bandUp - G.bandH
	local filTop = select(5, guide.azFiligree.l:GetPoint())
	local filBottom = filTop - G.filigreeH
	Check("[RT] guide : bande du titre, puis filigrane, sans chevauchement", guide.azBand and bandBottom >= filTop and filTop == TOP - G.filigreeY,
		bandBottom .. " / " .. tostring(filTop))
	Check("[RT] guide : le texte commence sous le filigrane", guide.bodyTop == TOP - G.bodyY and guide.bodyTop < filBottom)
	local first = guide.paras[1] or guide.heads[1]
	Check("[RT] guide : premier bloc posé sous le filigrane", first == nil or select(5, first:GetPoint()) <= guide.bodyTop)
	Check("[RT] guide : titre centré sur sa bande, doré", Point(guide.title, "LEFT").relTo == guide.azBand
		and Same(guide.title.textColor, INK.goldHead))
	local head = guide.heads[1]
	Check("[RT] guide : intertitres à l'encre brun-rouge", head == nil or Same(head.textColor, INK.head))
	Check("[RT] guide : voile 50 %", guide.azVeil and math.abs(guide.azVeil.vertex[4] - INK.alpha.guide) < 0.001)
	local ok, errs = NoErrors()
	Check("[RT] carnet sans erreur", ok, errs)
	f:Hide()
end

RT.Done()
