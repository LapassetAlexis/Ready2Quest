-- QuestCompanion 3.1.0 : les bandeaux au thème forgé (ForgeBanners.lua).
-- L'ancien habillage coupé (état du produit), ce qu'il donnait aux bandeaux
-- est re-logé en matières du socle : médaillon (anneau d'or du logo,
-- portrait 2D, icône dans un creux, logo nu), plaque des points ou du
-- niveau (jamais sur le texte), apparition (éclosion, éclat, trait),
-- brillante (nom d'or, halo), sous-ligne « Nouveau titre », ligne de guilde
-- sur deux lignes et « et N autres exploits », grand effet forgé (ou ailes
-- du client s'il les a), bouton Partager en plaque forgée et écrit, menu
-- habillé, bulle des visites et liseré en couleur d'identité. En Sobre :
-- rien de tout ça (seule la sous-ligne « Nouveau titre », qui manquait).
-- Contrastes de chaque nouveau texte sur son vrai fond.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme

local FIELDS = { "captureToast", "journalToast", "guildFeatToast", "captureResult" }
local GLOBALS = { "InCombatLockdown", "UnitAffectingCombat", "SetPortraitTextureFromCreatureDisplayID", "IsInGuild" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end

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

local function Errors()
	local list = {}
	for _, e in ipairs(NS.errors or {}) do list[#list + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
	return table.concat(list, " | ")
end

-- le monde : thème forgé (choix azeroth) ou Sobre ; atlas du client ou non
local function Fresh(style, atlas)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache, NS.tourUI, NS.errors = {}, nil, {}
	NS.journalToasts, NS.journalToastHideAt = {}, nil
	NS.captureResultHideAt, NS.captureResultPending = nil, nil
	if NS.bannerLane then NS.bannerLane.showing, NS.bannerLane.frame, NS.bannerLane.waiting = nil, nil, {} end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.IsInGuild = function() return true end
	if atlas then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	NS:AzerothAtlasOK(true)
	NS:AzerothSceneAtlasOK(true)
	NS:DB().companionStyle = style or "azeroth"
	NS:DB().winterVeil = "off"
	NS:ApplyUIStyle()
end

local function Done()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	if NS.tourState then NS:TourStop() end
	NS.TOUR_DEFS.forgeTest = nil
	for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	ResetWorld()
	NS.uiStyleCache = {}
end

-- une région de l'habillage (pas du contenu) peinte avec un atlas du client ?
local function ClientChrome(root, content)
	if root.atlas and not content[root] then return true end
	for _, child in ipairs(root.mockChildren or {}) do
		if ClientChrome(child, content) then return true end
	end
	return false
end

local function Played(group) return group ~= nil and (group.plays or 0) > 0 end

-- 1. Contrastes de chaque nouveau texte sur son vrai fond ----------------------------------------
do
	Say("-- bandeaux forgés : contrastes")
	Fresh("azeroth")
	local s = Steps()
	-- fond d'un bandeau : WINDOW à 0,94 sur le monde (pire cas : un monde blanc)
	local bg = Theme.Over(Theme.WHITE, Theme.WINDOW, 0.94)
	local function Ratio(label, ink, back, min)
		local r = Theme.Contrast(ink, back)
		s.ok(label .. " ≥ " .. min .. ":1", r >= min, string.format("%.2f", r))
	end
	Ratio("petit titre (identité)", Theme.IDENTITY_LIGHT, bg, 4.5)
	Ratio("nom", Theme.PARCHMENT, bg, 4.5)
	Ratio("nom d'une brillante", Theme.SHINY, bg, 4.5)
	Ratio("étoiles et traits", Theme.GOLD, bg, 4.5)
	Ratio("sous-ligne « Nouveau titre »", Theme.GOLD_LIGHT, bg, 4.5)
	Ratio("ligne de la créature (guilde)", Theme.TEXT, bg, 4.5)
	Ratio("« et N autres exploits »", Theme.MUTED_LIGHT, bg, 4.5)
	-- plaque d'or des points ou du niveau : son point le plus clair et le plus sombre sous le chiffre
	local P, F = Theme.FORGE_PLATE, Theme.FORGE
	Ratio("chiffre sur la plaque d'or (clair)", Theme.FORGE_INK.gold, Theme.ForgeSurface(P.gold, F.label.light), 4.5)
	Ratio("chiffre sur la plaque d'or (sombre)", Theme.FORGE_INK.gold, Theme.ForgeSurface(P.gold, F.label.dark), 4.5)
	-- « Partager » sur la petite plaque : neutre au repos, bronze au survol
	local ink = NS.SHARE_FORGE_INK
	Ratio("« Partager » sur la plaque neutre (clair)", ink, Theme.ForgeSurface(P.neutral, F.label.light), 4.5)
	Ratio("« Partager » au survol (bronze, clair)", ink, Theme.ForgeSurface(Theme.ForgeHover(P.bronze), F.label.light), 4.5)
	Ratio("« Partager » au survol (bronze, sombre)", ink, Theme.ForgeSurface(Theme.ForgeHover(P.bronze), F.label.dark), 4.5)
	-- menu : titre en identité sur NAV survolé ; bulle des visites sur WINDOW à 0,97
	Ratio("titre du menu Partager", Theme.IDENTITY_LIGHT, Theme.Over(Theme.NAV, Theme.WHITE, Theme.HOVER_ALPHA), 4.5)
	local tour = Theme.Over(Theme.WHITE, Theme.WINDOW, NS.TOUR_FORGE.alpha)
	Ratio("titre de la bulle (identité)", NS.TOUR_FORGE.title, tour, 4.5)
	Ratio("compteur de la bulle", NS.TOUR_FORGE.step, tour, 4.5)
	Ratio("texte de la bulle", NS.TOUR_SOBRE.text, tour, 4.5)
	s.ok("identité arcane posée (QuestCompanion)", Theme.identity == "arcane" and Same(NS.TOUR_FORGE.title, Theme.TITLE))
	s.check("[FBAN] contrastes : titres, noms, sous-lignes, chiffres des plaques, « Partager », menu et bulle ≥ 4,5:1")
	Done()
end

-- 2. « Capturé ! » : portrait, niveau, étoiles et traits, Partager écrit -------------------------
do
	Say("-- bandeaux forgés : « Capturé ! »")
	Fresh("azeroth")
	local s = Steps()
	NS:CaptureAccount().display = NS:CaptureAccount().display or {}
	NS:CaptureAccount().display[3255] = 4321
	_G.SetPortraitTextureFromCreatureDisplayID = function(tex, id) tex.portraitID = id end
	local f = NS:CaptureResultShow({ name = "Raptor des Tarides", stars = 3, npcID = 3255, level = 18, type = "Beast",
		class = "elite", fresh = true, specimen = { size = "large", trait = "curious", stars = 3 } })
	s.ok("bandeau né forgé, clé forge, jamais frame.azeroth", f and f.forgeBanner and f.styleKey == "forge" and not f.azeroth
		and f.uiStyle == "sobre")
	s.ok("nom global par clé", f and f:GetName() == "QuestCompanionCaptureResultForge", f and f:GetName())
	local medal = f and f.medal
	s.ok("médaillon : anneau d'or creux (Theme.ART.ring), au-dessus du contenu, plus le logo plein", medal
		and medal.ring.texture == Theme.ART.ring.file and medal.ring.drawLayer == "OVERLAY" and medal.icon.drawLayer == "ARTWORK")
	-- le disque sombre : couvre tout le centre de l'anneau, sans sortir de la bande d'or
	local K, R = NS.FORGE_BANNER, Theme.ART.ring
	local hole, band = K.medal * R.inner / 2, K.medal * R.outer / 2
	local covered, inside = true, true
	for deg = 0, 89 do
		local a = math.rad(deg)
		local x, y = hole * math.cos(a), hole * math.sin(a)
		local hit = false
		for _, part in ipairs(medal and medal.disc or {}) do
			if x <= part.width / 2 and y <= part.height / 2 then hit = true end
		end
		if not hit then covered = false end
	end
	for _, part in ipairs(medal and medal.disc or {}) do
		if math.sqrt((part.width / 2) ^ 2 + (part.height / 2) ^ 2) > band then inside = false end
		if not Same(part.colorTexture or {}, Theme.NAV) then inside = false end
	end
	s.ok("disque sombre (NAV) : tout le centre couvert, rien hors de la bande d'or", medal and #medal.disc == 3 and covered and inside)
	s.ok("contenu rond sous le bord intérieur de la bande", K.content <= K.medal * R.inner + 2 and K.content >= K.medal * R.inner - 2)
	s.ok("sans masque : l'icône carrée tient dans le centre de l'anneau", K.icon * math.sqrt(2) / 2 <= hole + 1.5)
	s.ok("portrait 2D de la créature dans le médaillon, rond, glyphe caché", medal and medal.kind == "portrait"
		and medal.icon.portraitID == 4321 and medal.icon.width == NS.FORGE_BANNER.content and not medal.glyph.shown
		and not medal.logo.shown)
	s.ok("niveau sur la plaque d'or", medal and medal.badge:IsShown() and medal.badge.text.text == "18")
	local line = f and f.stars.text or ""
	s.ok("étoiles, taille et caractère du spécimen", line:find(NS:SpecimenTagsShort({ size = "large", trait = "curious" }), 1, true) ~= nil, line)
	s.ok("petit titre en couleur d'identité, nom en parchemin", f and Same(f.title.textColor, Theme.IDENTITY_LIGHT)
		and Same(f.text.textColor, Theme.PARCHMENT))
	s.ok("apparition : éclosion, éclat, trait (AnimationGroup)", f and Played(medal.bloomFlash) and Played(f.forgeShineAnim)
		and f.forgePlays == 1, f and (tostring(medal.bloomFlash and medal.bloomFlash.plays) .. "/" .. tostring(f.forgeShineAnim and f.forgeShineAnim.plays) .. "/" .. tostring(f.forgePlays)))
	local b = f and f.shareButton
	s.ok("Partager : plaque forgée, « Partager » écrit, en bas à droite", b and b:IsShown() and b.forge and b.labelled
		and b.label.text == NS.L.SHARE_LABEL and b.lastPoint.point == "BOTTOMRIGHT")
	-- le bouton a sa rangée sous les lignes : aucune ligne ne perd de largeur
	local function Bottom(fs)
		local h = math.ceil(Theme.TextHeight(fs, fs:GetWidth(), fs.forgeFont))
		if fs.forgeMaxLines then h = math.min(h, math.ceil(Theme.TextHeight(fs, 100000, fs.forgeFont)) * fs.forgeMaxLines) end
		return -fs.lastPoint.y + h
	end
	s.ok("Partager sur sa rangée : les lignes gardent toute leur largeur", f and f.stars:GetWidth() == f.shareWidths.stars
		and f.text:GetWidth() == f.shareWidths.text and f.title:GetWidth() == f.shareWidths.title)
	s.ok("Partager sous la dernière ligne (le bandeau grandit de la rangée)", f and b
		and Bottom(f.stars) + NS.FORGE_BANNER.buttonGap <= f:GetHeight() - NS.SHARE_BUTTON.forge.y - b:GetHeight() + 0.5
		and f:GetHeight() > NS.FORGE_RESULT.h, f and (Bottom(f.stars) .. " / " .. f:GetHeight()))
	s.ok("aucun habillage du client (atlas)", f and not ClientChrome(f, {}))
	-- texte à droite du médaillon : rien ne le chevauche
	local textLeft = f and f.title.lastPoint.x or 0
	s.ok("texte à droite du médaillon", textLeft >= -NS.FORGE_BANNER.out + NS.FORGE_BANNER.medal, textLeft)
	NS:CaptureResultHide()
	-- brillante, sans créature connue : glyphe du filet, nom d'or, halo
	local g = NS:CaptureResultShow({ name = "Gesharahan", shiny = true, stars = 2 })
	s.ok("même bandeau resservi", g == f)
	s.ok("brillante : nom d'or (Theme.SHINY), halo au repos", Same(g.text.textColor, Theme.SHINY)
		and (g.medal.bloom.alpha or 0) > 0)
	s.ok("sans créature : le glyphe du filet (sa propre texture), pas de niveau", g.medal.kind == "glyph" and g.medal.glyph.shown
		and not g.medal.icon.shown and not g.medal.badge:IsShown())
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FBAN] « Capturé ! » forgé : portrait 2D, niveau sur la plaque, étoiles et traits, Partager écrit, apparition, brillante")
	Done()
end

-- 3. Bandeau du carnet : icône, points, sous-ligne, rafale, grand effet -------------------------
do
	Say("-- bandeaux forgés : carnet")
	Fresh("azeroth")
	local s = Steps()
	NS:JournalToastPush({ kind = "feat", title = NS.L.FEAT_TOAST_TITLE, name = "Bourlingueur", icon = "Interface\\Icons\\INV_Misc_Map_01",
		points = 10 })
	local j = NS.journalToast
	s.ok("bandeau né forgé", j and j.forgeBanner and j.styleKey == "forge" and j:IsShown())
	local plainH = j and j:GetHeight()
	s.ok("icône de la catégorie dans le médaillon (carrée sans masque, inscrite)", j and j.medal.kind == "icon"
		and j.medal.icon.texture == "Interface\\Icons\\INV_Misc_Map_01" and j.medal.icon.shown
		and j.medal.icon.width == NS.FORGE_BANNER.icon and not j.medal.glyph.shown)
	s.ok("points sur la plaque, plus de chiffre sur le texte", j and j.medal.badge.text.text == "10" and j.featPoints == nil)
	j:Hide(); NS.journalToastHideAt = nil
	if NS.BannerDone then NS:BannerDone("journal") end
	NS:JournalToastPush({ kind = "feat", id = "day_rare_50", title = NS.L.FEAT_TOAST_TITLE, name = "Le traqueur", points = 25,
		icon = "Interface\\Icons\\Ability_Hunter_BeastTaming", sub = NS:F("FEAT_TOAST_NEW_TITLE", "Traqueuse") })
	-- chaque titre (deux formes) : la sous-ligne tient en deux lignes, sans « ... »
	local worst, worstText = 0, ""
	for code in pairs(NS.FEAT_TITLES) do
		for _, gender in ipairs({ "m", "f" }) do
			local sub = NS:F("FEAT_TOAST_NEW_TITLE", NS:FeatTitleText(code, nil, gender) or "")
			local lines = Theme.TextWidth(j, sub, j.stars.forgeFont) / j.stars:GetWidth()
			if lines > worst then worst, worstText = lines, sub end
		end
	end
	s.ok("le plus long « Nouveau titre : … » tient en deux lignes (jamais coupé)", j.stars.forgeMaxLines == 2
		and j.stars.wordWrap == true and worst <= 2, string.format("%.2f %s", worst, worstText))
	s.ok("sous-ligne « Nouveau titre », bandeau plus haut", j.stars:IsShown() and j.stars.text == NS:F("FEAT_TOAST_NEW_TITLE", "Traqueuse")
		and j:GetHeight() > plainH, tostring(j:GetHeight()) .. " / " .. tostring(plainH))
	-- grand effet forgé (sans atlas : éclat ART.dot et filets lumineux en miroir)
	local fx = j.azReward
	s.ok("gros haut fait : grand effet forgé lancé", fx and fx.forge and fx.at ~= nil and fx.glow and fx.wingUL and fx.wingLR
		and fx.glow.texture == Theme.ART.dot.file and fx.wingUL.texture == Theme.ART.line.file)
	NS.AzerothFxStep(fx.at + 0.9)
	s.ok("à mi-course : ailes ouvertes, éclat allumé", fx.wingUL:IsShown() and fx.wingUR:IsShown() and fx.glow:IsShown()
		and fx.wingUL.width > fx.wingLL.width and (fx.wingUL.alpha or 0) > 0)
	s.ok("filets de gauche en miroir (la lueur s'efface vers l'extérieur)", fx.wingUL.texCoord and fx.wingUL.texCoord[1] == 1
		and not (fx.wingUR.texCoord and fx.wingUR.texCoord[1] == 1))
	NS.AzerothFxStep(fx.at + NS.AZEROTH_FX.rewardTime + 0.1)
	s.ok("fin de l'effet : tout caché", not fx.wingUL:IsShown() and not fx.glow:IsShown() and fx.at == nil)
	s.ok("l'API de l'ancien habillage reste muette hors drapeau", NS:AzerothRewardFX(j) == false)
	j:Hide(); NS.journalToastHideAt = nil
	if NS.BannerDone then NS:BannerDone("journal") end
	-- rafale : le logo nu, sans points
	for index = 1, 6 do NS.journalToasts[#NS.journalToasts + 1] = { kind = "subzone", name = "Lieu " .. index } end
	NS:ShowNextJournalToast()
	s.ok("rafale : le glyphe du logo, sans plaque, sans sous-ligne", j.medal.kind == nil and not j.medal.icon:IsShown()
		and j.medal.logo.shown and j.medal.logo.texture == (Theme.LOGO_GLYPH or Theme.LOGO_SMALL)
		and not j.medal.badge:IsShown() and not j.stars:IsShown())
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FBAN] carnet forgé : icône et points au médaillon, « Nouveau titre », hauteur adaptée, grand effet forgé, rafale")
	Done()
end

-- 4. Le grand effet avec les ailes du client (un effet, pas un habillage) --------------------------
do
	Say("-- bandeaux forgés : ailes du client")
	Fresh("azeroth", true)
	local s = Steps()
	local j = NS:EnsureJournalToast()
	s.ok("avec les atlas : le bandeau reste forgé (ancien habillage coupé)", j and j.forgeBanner and not j.azeroth)
	j:Show()
	s.ok("grand effet : ailes et éclat du client", NS:BannerRewardFX(j) == true and j.azReward.left and j.azReward.left.atlas
		== NS.AZEROTH_FX_ATLAS.wings and j.azReward.burst and not j.azReward.wingUL)
	NS:AzerothFxStop()
	s.check("[FBAN] grand effet forgé : les ailes et l'éclat du client s'il les a, sinon les matières du socle")
	Done()
end

-- 5. Bandeau de guilde : deux lignes, médaillon, « et N autres exploits » -------------------------
do
	Say("-- bandeaux forgés : guilde")
	Fresh("azeroth")
	local s = Steps()
	NS:GuildFeatsShowToast({ key = "x", sender = "Xan-Royaume", feat = { kind = "h" }, score = 1000, at = Mock.now,
		info = { kind = "h", line = "Xan, Maîtresse des brillantes, a gagné le titre « Traqueuse » !", big = true,
			icon = "Interface\\Icons\\Ability_Hunter_BeastTaming", points = 25, more = 2, sub = "Nouveau titre : Traqueuse" } })
	local g = NS.guildFeatToast
	s.ok("bandeau né forgé, nom par clé", g and g.forgeBanner and g:GetName() == "QuestCompanionGuildFeatForge")
	s.ok("la ligne : deux lignes au plus, coupée aux mots", g and g.text.wordWrap == true and g.text.forgeMaxLines == 2)
	s.ok("« et 2 autres exploits » gardée", g and g.hint:IsShown() and g.hint.text == NS:GuildFeatMoreText(2))
	s.ok("points sur la plaque du médaillon (plus de chevauchement)", g and g.medal.badge.text.text == "25" and g.featPoints == nil)
	s.ok("« Nouveau titre : … » en or clair, comme sur le bandeau du carnet (une seule règle)", g
		and g.info.text == "Nouveau titre : Traqueuse" and Same(g.info.textColor, Theme.GOLD_LIGHT))
	local right = -NS.FORGE_BANNER.out + NS.FORGE_BANNER.medal
	local clear = true
	for _, key in ipairs({ "title", "text", "info", "hint" }) do
		local fs = g[key]
		if fs:IsShown() and (fs.lastPoint.x < right or fs.lastPoint.x + fs:GetWidth() > g:GetWidth()) then clear = false end
	end
	s.ok("chaque ligne entre le médaillon et le bord droit", clear)
	s.ok("lignes empilées sans se recouvrir", g.text.lastPoint.y < g.title.lastPoint.y and g.info.lastPoint.y < g.text.lastPoint.y
		and g.hint.lastPoint.y < g.info.lastPoint.y)
	s.ok("grand effet forgé sur un gros haut fait", g.azReward and g.azReward.forge and g.azReward.at ~= nil)
	NS:GuildFeatsHideToast()
	NS:GuildFeatsShowToast({ key = "y", sender = "Yan-Royaume", feat = { kind = "s" }, score = 700, at = Mock.now,
		info = { line = "Yan a capturé une brillante !", shiny = true, class = "normal", name = "Sanglier", stars = 2 } })
	s.ok("exploit ordinaire : glyphe du filet, pas de plaque, nom d'or", g.medal.kind == "glyph" and not g.medal.badge:IsShown()
		and Same(g.text.textColor, Theme.SHINY))
	s.ok("exploit ordinaire : la ligne de la créature reprend l'encre courante", Same(g.info.textColor, Theme.TEXT))
	NS:GuildFeatsHideToast()
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FBAN] guilde forgée : deux lignes, médaillon et points sans chevauchement, « et N autres exploits », grand effet")
	Done()
end

-- 6. « Capture possible » : chemin du socle, glyphe au médaillon ---------------------------------
do
	Say("-- bandeaux forgés : capture possible")
	Fresh("azeroth")
	local s = Steps()
	local c = NS:EnsureCaptureToast()
	s.ok("bandeau né forgé, médaillon au glyphe du filet", c and c.forgeBanner and c.medal.kind == "glyph" and c.icon == c.medal.glyph)
	s.ok("textes à droite du médaillon, boutons gardés", c and c.title.lastPoint.x >= -NS.FORGE_BANNER.out + NS.FORGE_BANNER.medal
		and c.mute and c.ignore and c.muteRow)
	s.ok("barre d'accent cachée (sous le médaillon), couleur retenue", c and not c.accent.shown)
	c:SetAccent(Theme.GOLD_LIGHT)
	s.ok("SetAccent : retenue, toujours cachée", c.accentColor == Theme.GOLD_LIGHT and not c.accent.shown)
	s.check("[FBAN] « Capture possible » forgé : chemin du socle, glyphe au médaillon, mêmes boutons")
	Done()
end

-- 7. Bulle des visites : bandeau du socle, liseré en couleur d'identité ---------------------------
do
	Say("-- bandeaux forgés : bulle des visites")
	Fresh("azeroth")
	local s = Steps()
	local a = CreateFrame("Frame", nil, UIParent)
	a:SetSize(40, 40); a:SetPoint("CENTER", UIParent, "CENTER", 0, 0); a:Show()
	NS.TOUR_DEFS.forgeTest = { steps = { { id = "a", anchor = a, title = "TOUR_A1_T", text = "TOUR_A1", placement = "top" } } }
	NS:TourStart("forgeTest")
	local ui = NS.tourUI and NS.tourUI.forge
	local c, ring = ui and ui.callout, ui and ui.ring
	s.ok("bulle : bandeau du socle (habillage forgé), sans barre d'accent", c and c.forgeTour and c.chrome == "toast"
		and c:IsShown() and not c.accent.shown)
	s.ok("titre en couleur d'identité", c and Same(c.title.textColor, Theme.TITLE))
	s.ok("liseré de la cible en couleur d'identité", ring and ring.forge and ring:IsShown()
		and Same(ring.outer.top.vertex, Theme.IDENTITY_LIGHT) and Same(ring.innerEdge.top.vertex, Theme.IDENTITY))
	s.ok("boutons du socle (forgés à la création)", c and c.nextButton and c.skipButton)
	NS:TourStop()
	s.check("[FBAN] bulle des visites forgée : habillée par le socle, titre et liseré en couleur d'identité")
	Done()
end

-- 8. Sobre : rien de forgé ; la sous-ligne « Nouveau titre » rendue --------------------------------
do
	Say("-- bandeaux forgés : Sobre")
	Fresh("sobre")
	local s = Steps()
	s.ok("thème Sobre", not Theme.Forged())
	NS:JournalToastPush({ kind = "feat", title = NS.L.FEAT_TOAST_TITLE, name = "Bourlingueur", points = 10 })
	local j = NS.journalToast
	s.ok("bandeau Sobre : ni médaillon ni effet forgé", j and not j.forgeBanner and not j.medal and not j.forgeShine
		and j.styleKey == "sobre" and j:GetHeight() == 50)
	s.ok("sans sous-ligne : pas de 3e ligne créée", j and j.stars == nil)
	j:Hide(); NS.journalToastHideAt = nil
	if NS.BannerDone then NS:BannerDone("journal") end
	NS:JournalToastPush({ kind = "feat", id = "day_rare_50", title = NS.L.FEAT_TOAST_TITLE, name = "Le traqueur", points = 25,
		sub = NS:F("FEAT_TOAST_NEW_TITLE", "Traqueuse") })
	s.ok("sous-ligne « Nouveau titre » écrite (elle manquait), bandeau plus haut", j.stars and j.stars:IsShown()
		and j.stars.text == NS:F("FEAT_TOAST_NEW_TITLE", "Traqueuse") and j:GetHeight() > 50)
	s.ok("Sobre : aucun grand effet", j.azReward == nil and NS:BannerRewardFX(j) == false)
	j:Hide(); NS.journalToastHideAt = nil
	if NS.BannerDone then NS:BannerDone("journal") end
	NS:JournalNotify({ kind = "subzone", name = "Camp Taurajo" })
	s.ok("bandeau suivant sans sous-ligne : ligne cachée, hauteur d'origine", not j.stars:IsShown() and j:GetHeight() == 50)
	local r = NS:EnsureCaptureResult()
	s.ok("« Capturé ! » Sobre : nom d'avant, pas de médaillon", r and not r.forgeBanner and r:GetName() == "QuestCompanionCaptureResult")
	local c = NS:EnsureCaptureToast()
	s.ok("« Capture possible » Sobre : glyphe à gauche, barre d'accent", c and not c.forgeBanner and not c.medal and c.accent.shown)
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FBAN] Sobre : aucun habillage forgé ; seule la sous-ligne « Nouveau titre » (information qui manquait)")
	Done()
end

-- 9. Masque rond du client ; le Voile d'hiver ne repeint que le glyphe ---------------------------
do
	Say("-- bandeaux forgés : masque rond, Voile d'hiver")
	Fresh("azeroth")
	local s = Steps()
	-- un client qui sait masquer : portrait et icône arrondis, à la taille du contenu
	local mockCreateFrame = _G.CreateFrame
	_G.CreateFrame = function(...)
		local made = mockCreateFrame(...)
		function made:CreateMaskTexture()
			local mask = self:CreateTexture(nil, "ARTWORK")
			function mask:SetTexture(file, h, v) self.texture, self.wrap = file, { h, v } end
			return mask
		end
		local base = made.CreateTexture
		function made:CreateTexture(...)
			local tex = base(self, ...)
			function tex:AddMaskTexture(mask) self.masks = self.masks or {}; self.masks[#self.masks + 1] = mask end
			return tex
		end
		return made
	end
	local j = NS:EnsureJournalToast()
	_G.CreateFrame = mockCreateFrame
	local medal = j and j.medal
	s.ok("masque rond posé sur l'icône (diamètre du contenu)", medal and medal.mask and medal.mask.texture == NS.FORGE_BANNER.mask
		and medal.mask.width == NS.FORGE_BANNER.content and medal.icon.masks and medal.icon.masks[1] == medal.mask)
	NS:ForgeMedalSet(j, "icon", "Interface\\Icons\\INV_Misc_Map_01")
	s.ok("avec le masque : l'icône remplit le centre de l'anneau", medal.icon.width == NS.FORGE_BANNER.content and medal.icon.shown)
	-- Voile d'hiver : « Capturé ! » affiché avec le portrait, puis le décor allumé
	NS:CaptureAccount().display = NS:CaptureAccount().display or {}
	NS:CaptureAccount().display[3255] = 4321
	_G.SetPortraitTextureFromCreatureDisplayID = function(tex, id) tex.portraitID = id; tex.texture = "portrait:" .. id end
	local f = NS:CaptureResultShow({ name = "Raptor des Tarides", stars = 3, npcID = 3255, level = 18, type = "Beast" })
	s.ok("portrait au médaillon", f and f.medal.kind == "portrait" and f.medal.icon.texture == "portrait:4321")
	NS:SetWinterVeil("on")
	s.ok("décor allumé (saison du faux client)", NS:WinterVeilActive())
	s.ok("le portrait reste (jamais la boule de neige)", f.medal.icon.texture == "portrait:4321" and not f.medal.icon.wvSnowball
		and f.medal.kind == "portrait", tostring(f.medal.icon.texture))
	s.ok("le glyphe du filet, lui, devient la boule de neige (caché)", f.medal.glyph.wvSnowball == true and not f.medal.glyph.shown)
	-- même chose pour l'icône d'un haut fait sur le bandeau de guilde
	NS:SetWinterVeil("off")
	NS:GuildFeatsShowToast({ key = "z", sender = "Zed-Royaume", feat = { kind = "h" }, score = 900, at = Mock.now,
		info = { kind = "h", line = "Zed a gagné un haut fait !", icon = "Interface\\Icons\\INV_Misc_Map_01", points = 10 } })
	local g = NS.guildFeatToast
	NS:SetWinterVeil("on")
	s.ok("guilde : l'icône du haut fait reste", g and g.medal.kind == "icon" and g.medal.icon.texture == "Interface\\Icons\\INV_Misc_Map_01")
	NS:SetWinterVeil("off")
	NS:GuildFeatsHideToast()
	NS:CaptureResultHide()
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FBAN] médaillon : masque rond du client ; le Voile d'hiver repeint le glyphe, jamais le portrait ni l'icône")
	Done()
end

-- 10. Bascule à chaud d'un bandeau affiché : « Capturé ! » remontré, carnet complet --------------
do
	Say("-- bandeaux forgés : bascule à chaud")
	Fresh("sobre")
	local s = Steps()
	NS:CaptureAccount().display = NS:CaptureAccount().display or {}
	NS:CaptureAccount().display[3255] = 4321
	_G.SetPortraitTextureFromCreatureDisplayID = function(tex, id) tex.portraitID = id end
	local plain = NS:CaptureResultShow({ name = "Raptor des Tarides", shiny = true, stars = 3, npcID = 3255, level = 18,
		type = "Beast", class = "rare" })
	local hideAt = NS.captureResultHideAt
	s.ok("Sobre : « Capturé ! » affiché", plain and plain:IsShown() and not plain.forgeBanner)
	NS:DB().companionStyle = "azeroth"; NS:ApplyUIStyle()
	local f = NS.captureResult
	s.ok("après la bascule : le bandeau forgé remontre la prise (portrait, niveau, Partager)", f and f ~= plain and f:IsShown()
		and f.forgeBanner and f.medal.kind == "portrait" and f.medal.badge.text.text == "18" and f.text.text == "Raptor des Tarides"
		and f.shareButton and f.shareButton:IsShown())
	s.ok("son temps n'est pas allongé", NS.captureResultHideAt == hideAt)
	NS:CaptureResultHide()
	-- carnet : forgé (sous-ligne, points, Partager) puis Sobre, puis retour
	NS:JournalToastPush({ kind = "feat", id = "day_rare_50", title = NS.L.FEAT_TOAST_TITLE, name = "Le traqueur", points = 25,
		icon = "Interface\\Icons\\Ability_Hunter_BeastTaming", sub = NS:F("FEAT_TOAST_NEW_TITLE", "Traqueuse") })
	local j = NS.journalToast
	local jHide = NS.journalToastHideAt
	s.ok("forgé : sous-ligne, points au médaillon, Partager", j and j.forgeBanner and j.stars:IsShown() and j.medal.badge:IsShown()
		and j.shareButton and j.shareButton:IsShown())
	NS:DB().companionStyle = "sobre"; NS:ApplyUIStyle()
	local sj = NS.journalToast
	s.ok("vers le Sobre : sous-ligne « Nouveau titre » gardée, bandeau plus haut", sj and sj ~= j and not sj.forgeBanner
		and sj.stars and sj.stars:IsShown() and sj.stars.text == NS:F("FEAT_TOAST_NEW_TITLE", "Traqueuse") and sj:GetHeight() > 50)
	s.ok("vers le Sobre : points et Partager gardés", sj and sj.featPoints and sj.featPoints:IsShown()
		and sj.featPoints.text == "25" and sj.shareButton and sj.shareButton:IsShown())
	s.ok("vers le Sobre : temps inchangé", NS.journalToastHideAt == jHide)
	NS:DB().companionStyle = "azeroth"; NS:ApplyUIStyle()
	local back = NS.journalToast
	s.ok("retour au forgé : médaillon, plaque et Partager", back == j and back:IsShown() and back.medal.badge.text.text == "25"
		and back.shareButton and back.shareButton:IsShown())
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FBAN] bascule à chaud : « Capturé ! » remontré dans le nouveau thème ; bandeau du carnet complet dans les deux sens")
	Done()
end

-- 11. Bascule à chaud pendant un exploit de guilde : le bandeau forgé n'est pas vide ---------------
do
	Say("-- bandeaux forgés : bascule à chaud d'un exploit de guilde")
	Fresh("sobre")
	local s = Steps()
	NS:GuildFeatsShowToast({ key = "x", sender = "Xan-Royaume", feat = { kind = "h" }, score = 1000, at = Mock.now,
		info = { kind = "h", line = "Xan, Maîtresse des brillantes, a gagné le titre « Traqueuse » !", big = true,
			icon = "Interface\\Icons\\Ability_Hunter_BeastTaming", points = 25, more = 2, sub = "Nouveau titre : Traqueuse" } })
	local plain = NS.guildFeatToast
	s.ok("Sobre : exploit affiché", plain and plain:IsShown() and not plain.forgeBanner)
	NS:DB().companionStyle = "azeroth"; NS:ApplyUIStyle()
	local g = NS.guildFeatToast
	s.ok("après la bascule : un bandeau forgé, affiché", g and g ~= plain and g.forgeBanner and g:IsShown())
	local anchored = g ~= nil
	for _, key in ipairs({ "title", "text", "info", "hint" }) do
		local fs = g and g[key]
		if not (fs and fs.lastPoint) then anchored = false end
	end
	s.ok("chaque ligne est ancrée (un texte sans ancre ne se dessine pas en jeu)", anchored)
	s.ok("l'exploit en cours est repris : ligne, sous-ligne, « et 2 autres exploits »", g
		and g.text.text == "Xan, Maîtresse des brillantes, a gagné le titre « Traqueuse » !"
		and g.info.text == "Nouveau titre : Traqueuse" and g.hint.text == NS:GuildFeatMoreText(2))
	s.ok("médaillon : icône du haut fait et plaque des points", g and g.medal and g.medal.kind ~= "glyph"
		and g.medal.badge:IsShown() and g.medal.badge.text.text == "25")
	NS:DB().companionStyle = "sobre"; NS:ApplyUIStyle()
	local back = NS.guildFeatToast
	s.ok("retour au Sobre : le même cadre, l'exploit et ses points", back == plain and back:IsShown()
		and back.text.text == "Xan, Maîtresse des brillantes, a gagné le titre « Traqueuse » !"
		and back.featPoints and back.featPoints:IsShown() and back.featPoints.text == "25")
	NS:GuildFeatsHideToast()
	s.ok("sans erreur", Errors() == "", Errors())
	s.check("[FBAN] bascule à chaud d'un exploit de guilde : le bandeau du nouveau thème reprend l'exploit, lignes ancrées")
	Done()
end
