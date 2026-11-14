-- QuestCompanion 3.1.0 : le carnet et la fiche au thème forgé. Les fonctions
-- qui n'existaient que dans l'ancien habillage, re-logées en briques forgées
-- (décidées à la création du cadre) : médaillon du logo, points de hauts
-- faits sur une plaque sous la marque, roue du socle, envies en trois
-- paliers, chiffres du garde-manger sur pastille ; page Hauts faits (total
-- sur une plaque, losange sur les lignes) ; fiche de dresseur (médaillon,
-- portrait dans un cadre d'orfèvre, vitrine en creux) ; panneau d'allure et
-- confirmation (habillage qui suit le niveau, boutons à leur rang) ; décor du
-- Voile d'hiver sur le cadre forgé. En Sobre : rien de tout cela. Contrastes
-- des nouveaux textes mesurés sur leur vrai fond.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local Theme = NS.Theme

local FIELDS = { "journalFrame", "trainerFrame", "effectsConfirm", "allurePanel", "companionFrame", "companionBubble",
	"journalToast", "captureToast" }
local GLOBALS = { "UnitGUID", "UnitName", "UnitFullName", "UnitExists", "UnitIsPlayer", "UnitLevel",
	"InCombatLockdown", "UnitAffectingCombat" }
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

-- style : "azeroth" (thème forgé, l'état du produit) ou "sobre"
local function Fresh(style, winter)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle, NS.allureByStyle, NS.uiStyleCache = nil, nil, {}
	NS.errors = {}
	_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-00000001" end end
	_G.UnitName = function(unit) if unit == "player" then return "Dyokrion" end end
	_G.UnitFullName = function(unit) if unit == "player" then return "Dyokrion", "Aeternalis" end end
	_G.UnitExists = function(unit) return unit == "player" end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style
	NS:DB().winterVeil = winter or "off"
	NS:ApplyUIStyle()
	NS:CompanionData().tutoDone = true
	if NS.TreatData then NS:TreatData().treatsInit = true end
end

local function Done()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
	ResetWorld()
	NS.Theme.ApplySkin(NS:UISkinChoice())
end

local function Shown(region) return region ~= nil and region.IsShown and region:IsShown() and true or false end

-- contraste d'un texte sur une plaque forgée teinte (point le plus clair et le plus sombre sous un libellé)
local function OnPlate(ink, tint)
	local K = Theme.FORGE.label
	return math.min(Theme.Contrast(ink, Theme.ForgeSurface(tint, K.light)), Theme.Contrast(ink, Theme.ForgeSurface(tint, K.dark)))
end

-- 1. Carnet : médaillon, plaque des points, roue, envies, garde-manger ---------------------------
do
	Say("-- carnet forgé : médaillon, plaque des points sous la marque, roue du socle")
	Fresh("azeroth")
	NS:FeatAward("char_level_10", { silent = true })
	local f = NS:ToggleJournal(true)
	local s = Steps()
	s.ok("thème forgé posé, carnet né forgé", NS.QCForged() and f and f.journalForged == true and f.styleKey == "forge")
	s.ok("médaillon demandé et posé par le socle", f.wantsEmblem == true and f.skinChrome and Shown(f.skinChrome.emblem))
	s.ok("marque : le petit logo caché, le nom après le médaillon", f.brand.logo.mockHidden == true
		and select(4, f.brand.name:GetPoint(1)) == Theme.EMBLEM.text - 2)
	local plate = f.featPlate
	s.ok("plaque des points : découpe forgée (plaque), losange d'or", plate and plate.slice and plate.slice.art == Theme.ART.plate
		and plate.diamond and Same(plate.diamond.vertex, Theme.GOLD))
	s.ok("plaque des points : JRN_TOTAL_FEATS", plate and plate.text.text == NS:F("JRN_TOTAL_FEATS", NS:FeatPoints()),
		plate and plate.text.text)
	s.ok("bas de colonne : plus les points (module actif : vide)", f.subtitle.text == "", f.subtitle.text)
	-- la plaque sous la marque, la navigation descendue d'autant, rien ne se chevauche
	local K = NS.JOURNAL_FEAT_PLATE
	local _, _, _, gx, gy = f.navGroup:GetPoint(1)
	s.ok("navigation descendue sous la plaque", gy == -92 - K.shift and K.y - K.h > gy, tostring(gy))
	local medalBottom = Theme.EMBLEM.y - Theme.EMBLEM.size
	s.ok("plaque sous le médaillon et sous la marque (bas de la marque à -72)", K.y <= -72 - 4 and K.y < medalBottom)
	local gear = f.settingsButton
	s.ok("roue du socle sur sa petite plaque (pas la roue grise du client)", gear and gear.cogTexture == nil and gear.plate ~= nil)
	s.ok("sans erreur", #(NS.errors or {}) == 0, Errors())
	s.check("[JFG] carnet forgé : médaillon, points JRN_TOTAL_FEATS sur une plaque forgée sous la marque, colonne libre, roue du socle")

	s = Steps()
	local data = NS:CompanionData()
	data.needs = { hunger = 82, energy = 64, mood = 12, curiosity = 46 }
	NS:SelectJournalKind("evolution")
	local byKey = {}
	for _, row in ipairs(f.evo.needs) do byKey[row.key] = row end
	s.ok("comblée : barre et chiffre verts", Same(byKey.hunger.bar.fill.vertex, Theme.GREEN) and Same(byKey.hunger.value.textColor, Theme.GREEN))
	s.ok("entre les deux : barre d'or, chiffre clair", Same(byKey.energy.bar.fill.vertex, Theme.GOLD) and Same(byKey.energy.value.textColor, Theme.LABEL))
	s.ok("basse (sous 30 %) : barre et chiffre orange", Same(byKey.mood.bar.fill.vertex, Theme.ORANGE_DEEP)
		and Same(byKey.mood.value.textColor, Theme.ORANGE_DEEP))
	local nav = {}
	for _, row in ipairs(f.navSummary.pet.needs) do nav[row.key] = row end
	s.ok("colonne : les mêmes paliers", Same(nav.hunger.bar.fill.vertex, Theme.GREEN) and Same(nav.energy.bar.fill.vertex, Theme.GOLD)
		and Same(nav.mood.bar.fill.vertex, Theme.ORANGE_DEEP))
	local button = f.pantry and f.pantry.biscuit
	s.ok("garde-manger : chiffre sur sa pastille sombre, ombré", button and button.countPad and Same(button.countPad.vertex, Theme.INK)
		and button.count.shadowOffset ~= nil)
	button:GetScript("OnEnter")(button)
	s.ok("garde-manger : survol à la sélection", Same(button.border.top.vertex or {}, Theme.SELECT_LIGHT)
		or Same({ button.border.top:GetVertexColor() }, Theme.SELECT_LIGHT))
	button:GetScript("OnLeave")(button)
	s.check("[JFG] envies en trois paliers (verte comblée, or, orange sous 30 %), page et colonne ; garde-manger lisible")

	-- 2. Hauts faits : plaque du total, losanges
	s = Steps()
	NS:DB().featsFilter = "all"
	NS:SelectJournalKind("feats")
	local pane = f.feats
	s.ok("plaque du total, en tête de page : FeatPoints", pane.pointsPlate and pane.pointsPlate.value.text == tostring(NS:FeatPoints())
		and pane.pointsPlate.slice.art == Theme.ART.plate, pane.pointsPlate and pane.pointsPlate.value.text)
	local _, _, _, tx = pane.totals:GetPoint(1)
	local pk = NS.JOURNAL_FEATS_PLATE
	s.ok("totaux décalés à droite de la plaque", tx and tx >= pk.w, tostring(tx))
	local losanges, shields = 0, 0
	for _, row in ipairs(pane.rows) do
		if row:IsShown() then
			if Shown(row.diamond) then losanges = losanges + 1 end
			if Shown(row.shield) then shields = shields + 1 end
		end
	end
	s.ok("lignes : losange forgé, jamais le bouclier du client", losanges > 0 and shields == 0, losanges .. "/" .. shields)
	s.check("[JFG] Hauts faits forgés : total sur une plaque en tête, losanges sur les lignes")
	f:Hide()
	Done()
end

-- 3. Sobre : rien de forgé ajouté --------------------------------------------------------------------
do
	Say("-- carnet Sobre : aucune brique forgée ajoutée")
	Fresh("sobre")
	local f = NS:ToggleJournal(true)
	local s = Steps()
	s.ok("thème Sobre", not NS.QCForged() and f and not f.journalForged)
	s.ok("pas de médaillon, petit logo de la marque", not f.wantsEmblem and not f.brand.logo.mockHidden)
	s.ok("pas de plaque des points ; les points en bas de colonne", f.featPlate == nil and f.subtitle.text:find("points de hauts faits", 1, true))
	s.ok("roue grise du journal de quêtes", f.settingsButton and f.settingsButton.cogTexture ~= nil)
	local button = f.pantry and f.pantry.biscuit
	s.ok("garde-manger sans pastille", button and button.countPad == nil)
	NS:CompanionData().needs = { hunger = 82, energy = 64, mood = 12, curiosity = 46 }
	NS:SelectJournalKind("evolution")
	local low
	for _, row in ipairs(f.evo.needs) do if row.key == "mood" then low = row end end
	s.ok("envies : or ou gris (deux paliers)", low and Same(low.bar.fill.vertex, Theme.MUTED))
	NS:SelectJournalKind("feats")
	s.ok("Hauts faits : pas de plaque du total", f.feats.pointsPlate == nil)
	s.check("[JFG] Sobre : ni médaillon, ni plaque, ni pastille, ni troisième palier ; roue et points comme avant")
	f:Hide()
	local trainer = NS:TrainerOpen()
	s = Steps()
	s.ok("fiche Sobre : ni médaillon, ni cadre du portrait, ni creux", trainer and not trainer.wantsEmblem and not trainer.trainerForged
		and trainer.stage.forgeRing == nil and trainer.featCards[1].forgeInset == nil)
	s.check("[JFG] fiche Sobre inchangée")
	trainer:Hide()
	Done()
end

-- 4. Fiche de dresseur forgée --------------------------------------------------------------------------
do
	Say("-- fiche de dresseur forgée : médaillon, portrait encadré, vitrine en creux")
	Fresh("azeroth")
	NS:FeatAward("char_level_10", { silent = true })
	local f = NS:TrainerOpen()
	local s = Steps()
	s.ok("née forgée (clé forge)", f and f.trainerForged == true and f.styleKey == "forge")
	s.ok("médaillon ; l'en-tête lui laisse la place", f.wantsEmblem == true and f.skinChrome and Shown(f.skinChrome.emblem)
		and f.header.textLeft == Theme.EMBLEM.text and f.header.logo == nil)
	local ring = f.stage.forgeRing
	s.ok("portrait : cadre d'orfèvre, quatre coins, bords assombris, au-dessus du modèle, sans souris", ring and ring.slice
		and ring.slice.art == Theme.ART.frame and #ring.corners == 4 and ring.vignette
		and ring:GetFrameLevel() > f.stage:GetFrameLevel() and not ring.mouseEnabled)
	s.ok("le filet d'un pixel du portrait s'efface", f.stage.border.top.mockHidden == true)
	local insets = 0
	for _, card in ipairs(f.featCards) do if card.forgeInset and card.forgeInset.art == Theme.ART.inset then insets = insets + 1 end end
	s.ok("vitrine des hauts faits : chaque icône en creux", insets == #f.featCards, insets)
	local tiles = 0
	for _, tile in ipairs(f.tiles) do if not tile.model or (tile.forgeInset and tile.forgeInset.art == Theme.ART.inset) then tiles = tiles + 1 end end
	s.ok("vitrine : chaque modèle en creux", tiles == #f.tiles)
	-- le creux déborde du modèle de insetOut px : il garde de la marge jusqu'au
	-- liseré de la carte (haut, bas, gauche), et le texte part après lui
	local K, placed = NS.TRAINER_FORGE, 0
	for _, tile in ipairs(f.tiles) do
		local m = tile.model
		if m then
			local p, tp = m.lastPoint or {}, tile.name.lastPoint or {}
			local th, mh = tile:GetHeight() or 0, m:GetHeight() or 0
			local vMargin = (th - mh) / 2 - K.insetOut
			local hMargin = (p.x or 0) - K.insetOut
			local textGap = (tp.x or 0) - ((p.x or 0) + (m:GetWidth() or 0) + K.insetOut)
			if p.point == "LEFT" and vMargin >= 4 and hMargin >= 4 and textGap >= 6
				and (tile.detail.lastPoint or {}).x == tp.x and (tile.stars.lastPoint or {}).x == tp.x then
				placed = placed + 1
			end
		else
			placed = placed + 1
		end
	end
	s.ok("vitrine : creux à 4 px au moins du liseré, texte à 6 px au moins du creux", placed == #f.tiles, placed)
	-- l'en-tête des hauts faits (détail entre parenthèses) s'arrête avant la liste « Vitrine »
	local sec, picker = f.featsSection, f.featsPicker
	sec:SetText(NS.L.TRAINER_FEATS_HEAD, string.rep("détail très long ", 8))
	NS.TrainerFitFeatsDetail(f)
	local start = (sec.forged and Theme.FORGE_SECTION.text or 0) + sec.label:GetStringWidth() + 6
	local right = start + (sec.detail:GetWidth() or 1e9)
	local pickerLeft = (picker.lastPoint and picker.lastPoint.x or 0) - (f.featsSection.lastPoint.x or 0) - picker:GetWidth()
	s.ok("en-tête des hauts faits : un détail trop long est coupé sur une ligne avant la liste « Vitrine »",
		f.featsDetailFit ~= nil and sec.detail.wordWrap == false and right <= pickerLeft - NS.TRAINER_DETAIL_GAP + 0.5,
		string.format("%.1f / %.1f", right, pickerLeft))
	sec:SetText(NS.L.TRAINER_FEATS_HEAD, "court")
	NS.TrainerFitFeatsDetail(f)
	s.ok("en-tête des hauts faits : un détail court garde sa largeur naturelle", f.featsDetailFit == nil)
	-- aucune information perdue : les points de la fiche en sous-titre
	s.ok("points de la fiche en sous-titre", (f.header.subtitle.text or ""):find("points", 1, true), f.header.subtitle.text)
	s.ok("nom du compagnon au titre (identité)", Same(f.compName.textColor, Theme.TITLE))
	s.ok("sans erreur", #(NS.errors or {}) == 0, Errors())
	s.check("[JFG] fiche forgée : médaillon, portrait dans un cadre d'orfèvre, vitrine en creux, points en sous-titre")
	f:Hide()
	Done()
end

-- 5. Allure et confirmation -------------------------------------------------------------------------------
do
	Say("-- allure et confirmation au thème forgé")
	Fresh("azeroth")
	NS:ToggleJournal(true)
	local panel = NS:AllureOpen()
	local s = Steps()
	s.ok("allure : habillée par le socle (médaillon), née forgée", panel and panel.allureForged and panel.skinDressed == true
		and panel.wantsEmblem == true)
	local tone = panel.mineTitle.tone and Theme.ResolveTone(panel.mineTitle.tone) or Theme.ResolveTone()
	s.ok("titres de section à l'identité (pas repeints en gris)", Same(panel.mineTitle.label.textColor, tone.light),
		panel.mineTitle.label.textColor and panel.mineTitle.label.textColor[1])
	local worn
	for _, tile in ipairs(panel.tiles) do if tile.worn and tile:IsShown() then worn = tile end end
	if worn then s.ok("allure portée : la sélection", Same(worn.ring.top.vertex or { worn.ring.top:GetVertexColor() }, Theme.SELECT_LIGHT)) end
	s.ok("allure : l'habillage suit le niveau du panneau", panel.chromeFollows == true and panel.skinChrome
		and panel.skinChrome.top:GetFrameLevel() > panel:GetFrameLevel())
	-- le suivi de niveau sert au produit : il ne vit pas dans un fichier de
	-- l'ancien habillage, voué à disparaître (JournalAzeroth.lua, AzerothStyle.lua)
	local info = debug and debug.getinfo and debug.getinfo(NS.ForgeChromeFollows, "S")
	local src = info and info.source or ""
	s.ok("suivi de niveau de l'habillage (ns.ForgeChromeFollows) hors des fichiers de l'ancien habillage",
		type(NS.ForgeChromeFollows) == "function" and src ~= "" and not src:find("JournalAzeroth", 1, true)
		and not src:find("AzerothStyle", 1, true), src)
	NS:AllureClose()
	local dialog = NS:EnsureEffectsConfirm()
	NS:EffectsConfirmPlace(dialog)
	s.ok("confirmation : médaillon, habillage au-dessus d'elle une fois relevée", dialog.wantsEmblem == true and dialog.chromeFollows
		and dialog.skinChrome.top:GetFrameLevel() > dialog:GetFrameLevel())
	s.ok("confirmation : principal doré, Annuler en contour", dialog.ok and dialog.ok.style == "primary"
		and dialog.cancel and dialog.cancel.style == "outline", dialog.ok and tostring(dialog.ok.style))
	s.check("[JFG] allure et confirmation : habillées par le socle, médaillon au-dessus, boutons à leur rang, couleurs par rôle")
	Done()
end

-- 6. Voile d'hiver sur le carnet forgé ---------------------------------------------------------------------
do
	Say("-- Voile d'hiver : décor du carnet forgé")
	Fresh("azeroth", "on")
	local f = NS:ToggleJournal(true)
	local d = f.wvDecor
	local s = Steps()
	s.ok("en saison : décor posé sur le carnet forgé", NS:WinterVeilActive() and d and d.forged and d:IsShown())
	local K = NS.WINTER_VEIL_JOURNAL_FORGE
	local W = f:GetWidth()
	s.ok("guirlande : du médaillon jusqu'avant la roue et la croix", d.band.x0 >= Theme.EMBLEM.x + Theme.EMBLEM.size
		and d.band.x1 <= W - K.right and #d.lights > 0)
	s.ok("cadeau et renne autour du titre de la marque", d.present and d.reindeer and select(2, d.present:GetPoint(1)) == f.brand.name
		and select(2, d.reindeer:GetPoint(1)) == f.brand.name)
	s.ok("trois flocons", #d.flakes == #K.flakes)
	s.ok("sous le médaillon et les coins du socle, sans souris", d:GetFrameLevel() < f.skinChrome.top:GetFrameLevel() and not d.mouseEnabled)
	NS:SetWinterVeil("off")
	s.ok("réglage « jamais » : décor caché", not d:IsShown())
	NS:SetWinterVeil("on")
	s.ok("réglage « toujours » : revenu, le même (pas refait)", f.wvDecor == d and d:IsShown())
	s.check("[JFG] Voile d'hiver : guirlande sous le bord haut, cadeau et renne autour du titre, flocons, suit le réglage")
	f:Hide()
	Done()
	-- la bande du client refusée : le repli en matières forgées (fil et ampoules)
	Fresh("azeroth", "on")
	Mock.world.textureRefused = { [NS.WINTER_VEIL_ART.lights.file] = true }
	f = NS:ToggleJournal(true)
	d = f.wvDecor
	local bulbs = 0
	for _, tex in ipairs(d and d.lights or {}) do if tex.texture == Theme.ART.dot.file then bulbs = bulbs + 1 end end
	Check("[JFG] Voile d'hiver : bande du client refusée, fil lumineux et ampoules en matières forgées (jamais rien)",
		d and d.forgeLights and d.wire and d.wire.texture == Theme.ART.line.file and bulbs >= 10 and Errors() == "",
		tostring(bulbs) .. " " .. Errors())
	Mock.world.textureRefused = nil
	f:Hide()
	Done()
	Fresh("sobre", "on")
	f = NS:ToggleJournal(true)
	Check("[JFG] Voile d'hiver : jamais en Sobre", f.wvDecor == nil)
	f:Hide()
	Done()
end

-- 7. Contrastes des nouveaux textes, sur leur vrai fond -------------------------------------------------
do
	Say("-- carnet forgé : contrastes mesurés")
	Fresh("azeroth")
	local s = Steps()
	local plate = Theme.FORGE_PLATE[NS.JOURNAL_FEAT_PLATE.tint]
	local c1 = OnPlate(Theme.GOLD_LIGHT, plate)
	s.ok("points sous la marque (or clair sur la plaque ardoise) ≥ 4,5", c1 >= 4.5, string.format("%.2f", c1))
	local c2 = OnPlate(Theme.GOLD_LIGHT, Theme.FORGE_PLATE[NS.JOURNAL_FEATS_PLATE.tint])
	s.ok("total des Hauts faits (titre) ≥ 3", c2 >= 3, string.format("%.2f", c2))
	local K = NS.JOURNAL_PANTRY_FORGE
	local pad = Theme.Over(Theme.WHITE, Theme.INK, K.padAlpha)   -- la pastille sur l'icône la plus claire
	local c3 = Theme.Contrast(Theme.PARCHMENT, pad)
	s.ok("chiffre du garde-manger sur sa pastille, icône blanche dessous ≥ 4,5", c3 >= 4.5, string.format("%.2f", c3))
	for _, ink in ipairs({ { "verte", Theme.GREEN }, { "orange", Theme.ORANGE_DEEP }, { "claire", Theme.LABEL } }) do
		local c = math.min(Theme.Contrast(ink[2], Theme.ROW), Theme.Contrast(ink[2], Theme.ROW_ALT))
		s.ok("envie " .. ink[1] .. " sur sa rangée ≥ 4,5", c >= 4.5, string.format("%.2f", c))
	end
	for _, item in ipairs({ { "titre de plaque des Missions (identité claire) sur la tuile", Theme.IDENTITY_LIGHT, Theme.ROW },
		{ "titre de liste et intertitres (identité) sur la fenêtre", Theme.IDENTITY, Theme.WINDOW },
		{ "titre de colonne des Échanges (identité) sur la fenêtre", Theme.IDENTITY, Theme.WINDOW },
		{ "nom du compagnon de la fiche (titre) sur la fenêtre", Theme.TITLE, Theme.WINDOW },
		{ "étiquette du rang de la fiche (identité claire) sur la fenêtre", Theme.IDENTITY_LIGHT, Theme.WINDOW } }) do
		local c = Theme.Contrast(item[2], item[3])
		s.ok(item[1] .. " ≥ 4,5", c >= 4.5, string.format("%.2f", c))
	end
	s.check("[JFG] contrastes des nouveaux textes du carnet et de la fiche forgés (≥ 4,5 texte, ≥ 3 titre)")
	Done()
end
