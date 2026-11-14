-- Le carnet et la fiche de dresseur (QuestCompanion 2.8 → 2.11.1) : habits
-- Azeroth (textures du client par page), Sobre inchangé, changement de style à
-- chaud, repli quand le client refuse une texture, Échap (un nom global par
-- style) ; encres par rôle (aucun texte repeint par devinette), voiles,
-- infobulles ancrées à la ligne ; mise en page : chaque texte centré ou tenu
-- dans sa plaque, rien ne se chevauche (guide, Exploration, boucliers des
-- points, plaques de chiffres, bande résumé des Missions, colonne de
-- navigation) ; « Localiser », filtre et recherche des zones, état mémorisé ;
-- « Changer de compagnon ? » (style, au-dessus du carnet, Échap) ; fiche de
-- dresseur (titre, vitrine, protocole) ; raccourcis (Y, options).
-- 3.1.0 : affirme l'ancien habillage (carnet en parchemin, scènes en bois, bandeaux
-- dorés, anneau) : le drapeau QNS.AZEROTH_LEGACY rallumé pour tout le module
-- (remis à la valeur du produit à sa fin, tests/run_tests.lua)
T.Legacy(true)
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local CZ = { saved = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitFullName", "UnitExists", "UnitIsPlayer", "UnitLevel", "InCombatLockdown",
	"UnitAffectingCombat", "C_Texture", "GetNormalizedRealmName", "GetRealmName", "time", "C_ChatInfo", "UnitFactionGroup",
	"C_Map", "UiMapPoint", "C_SuperTrack", "GetBindingAction", "SetBinding", "SaveBindings", "GetCurrentBindingSet",
	"GetBindingKey", "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown" }
for _, name in ipairs(GLOBALS) do CZ.saved[name] = rawget(_G, name) end
CZ.feat = { dormant = NS.featsDormant, login = NS.featLoginDone }
local TX = NS.CARNET_TEX
local LAY = NS.CARNET_LAYOUT
local INK = NS.AZEROTH_INK
local CONTRAST = NS.AZEROTH_CONTRAST

local FIELDS = { "journalFrame", "trainerFrame", "companionFrame", "companionBubble", "captureResult", "effectsConfirm" }
function CZ.Reset(style, refused)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle = nil
	NS.uiStyleCache, NS.errors, NS.carnetMissing = {}, {}, {}
	NS.carnetInkMisses, NS.mapPin = nil, nil
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	Mock.world.textureRefused = refused
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
	-- 3.1.0 : le thème du socle suit le choix (il ne retombe plus en Sobre
	-- faute d'atlas au chargement) : posé ici, comme au chargement
	NS.Theme.ApplySkin(NS:UISkinChoice())
	NS:DB().journalState = nil
	NS:CompanionData().tutoDone = true
end
function CZ.Done()
	NS:DB().feats = nil
	NS:CharData().feats = nil
	NS:CompanionData().trainer = nil
	NS.featsDormant, NS.featLoginDone = CZ.feat.dormant, CZ.feat.login
	NS:TrainerResetSession()
	for _, name in ipairs(GLOBALS) do _G[name] = CZ.saved[name] end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle, NS.uiStyleCache, NS.mapPin = nil, {}, nil
	NS:DB().journalState = nil
	Mock.world.textureRefused = nil
	ResetWorld()
end
local function NoErrors()
	local list = {}
	for _, e in ipairs(NS.errors or {}) do list[#list + 1] = tostring(e.where) .. ": " .. tostring(e.message) end
	return #list == 0, table.concat(list, " | ")
end
local function Open(kind)
	local frame = NS:ToggleJournal(true)
	if kind then NS:SelectJournalKind(kind) end
	return frame
end
local function Point(region, name)
	for _, p in ipairs(region and region.points or {}) do if p.point == name then return p end end
	return nil
end
local function Same(c, ref)
	if not (c and ref) then return false end
	for i = 1, 3 do if math.abs((c[i] or -1) - ref[i]) > 0.001 then return false end end
	return true
end
local function Painted(fs, key) return fs and CONTRAST[key] and Same(fs.textColor, INK[CONTRAST[key][1]]) end
-- une liste d'exigences, une seule assertion : les noms en échec dans le détail
local function Expect(bad, label, fn)
	local ok, res = pcall(fn)
	if not (ok and res) then bad[#bad + 1] = label .. (ok and "" or " (erreur)") end
end

-- 1. Le carnet en Azeroth : cadre, plaque, colonne, pages ---------------------------------------------
do
	Say("-- carnet azeroth : habits du client, page par page")
	CZ.Reset()
	local f = Open("evolution")
	local ok, errs = NoErrors()
	local W = LAY.wood + LAY.nav + LAY.gap + NS.JOURNAL_LAYOUT.width - 2 - NS.JOURNAL_LAYOUT.nav + LAY.wood
	Check("[CZ] carnet Azeroth sans erreur ; la fenêtre grandit du bois et de la bande, la zone des pages garde sa taille",
		f and f.azeroth and f.uiStyle == "azeroth" and ok and f:GetWidth() == W
		and f:GetHeight() == LAY.band + NS.JOURNAL_LAYOUT.height - 2 + LAY.wood
		and f.content:GetWidth() == NS.JOURNAL_LAYOUT.width - 2 - NS.JOURNAL_LAYOUT.nav, errs)
	local bad = {}
	local plate, item = f.azPlate, f.sections.evolution
	Expect(bad, "bois", function() return f.azWood.tl.atlas == NS.AZEROTH_WOOD.tl and f.azWood.right.atlas == NS.AZEROTH_WOOD.right
		and f.azOver.level > f.level + 20 end)
	Expect(bad, "plaque", function() return plate.left.texture == TX.headA.file and plate.right.texture == TX.headB.file
		and select(5, plate:GetPoint()) == LAY.plateUp and plate.box.texture == 235402 and plate.icon.texture == 235415 end)
	Expect(bad, "parchemins", function() return f.nav.azBg.texture == 130662 and f.content.azBg.texture == 130661
		and f.nav.bg.mockHidden and f.content.azSurface == "light" end)
	Expect(bad, "métal", function() return f.azMetalL.texture == 130658 and f.azMetalT.texture == 130659 end)
	Expect(bad, "catégorie", function() return item.azBg.texture == 130652 and item.tint.texture == 235400
		and item.tint.blendMode == "ADD" and item.hover.texture == 235400 and item.bar.alpha == 0 end)
	Expect(bad, "entrées sous la marque", function() return select(5, item:GetPoint()) == LAY.navTop and item:GetWidth() == LAY.nav
		and f.brand.mockHidden end)
	Expect(bad, "garde-manger", function()
		for _, kind in ipairs(NS.TREAT_KINDS) do
			local b = f.pantry[kind]
			if b:GetParent() == f.nav and b.azRing and b.azRing.texture == 130656 then return true end
		end
	end)
	Expect(bad, "fermeture", function() return f.close.azIcon.texture:find("MinimizeButton") ~= nil and f.close.label.mockHidden
		and f.closeButton.azSkin == "red" and f.closeButton.bg.mockHidden and f.closeButton.text.textColor[1] == 1 end)
	Expect(bad, "filigrane", function() return f.header.azFiligree.m.texture == TX.tsuH and f.header.rule.segments[1].mockHidden end)
	-- les pages
	local evo = f.evo
	Expect(bad, "compagnon : carte", function() return evo.hero.azBg.texture == 235397 and evo.hero.azWoodBorder.pieces.t.texture == 130672
		and #evo.hero.azWoodBorder.pieces.t.texCoord == 8 and evo.azVine.atlas == NS.AZEROTH_ATLAS.frameRound end)
	Expect(bad, "compagnon : chiffres", function() local tile = evo.stats.captures; return tile.azBg.texture == 130652 and tile.value.azKeep end)
	Expect(bad, "compagnon : envies", function() local b = evo.needs[1].bar; return b:GetHeight() == 14 and b.azEdge
		and b.fill.texture:find("UI%-StatusBar") ~= nil end)
	Expect(bad, "compagnon : bulle", function() return evo.bubble.azBg.texture == 130661 and evo.bubble.azVeil:IsShown()
		and evo.look.textColor[1] < 0.3 and evo.look.textColor[3] < 0.1 end)
	Open("menagerie")
	local men = f.men
	Expect(bad, "créatures", function() local row = men.items[1]
		return (row.azBg.texture == 235397 or row.azBg.texture == 130660) and men.preview.azTitle.texture == 130667
		and men.preview.stage.texture == 1111217 and men.preview.azWoodBorder and men.states.all.azBg.texture == 130652 end)
	Open("feats")
	local hf = f.feats
	Expect(bad, "hauts faits", function() local frow = hf.rows[1]
		return hf.cats[1].azBg.texture == 130652 and frow.azTitle.texture == 130667 and frow.azRing.texture == 130656
		and frow.shield.atlas ~= nil and hf.azShield.texture == 130665
		and (frow.entry.got and frow.azBg.texture == 235397 or (frow.azBg.texture == 130660 and frow.azTitle.texCoord[3] > 0.3)) end)
	Open("day")
	local day = f.day
	-- 2.9.1 : la carte des auberges en 7 tampons ronds (anneau des hauts faits)
	Expect(bad, "missions", function() return day.stamps[1].azRing.atlas == NS.AZEROTH_ATLAS.frameRound and #day.stamps == 7
		and day.missions[1].azBg.texture == 235397 and day.groups.zone.azStrip ~= nil end)
	Open("progress")
	local prog = f.prog
	Expect(bad, "exploration", function() return prog.zones[1].azBg.texture == 130652 and prog.marks[1].azBg.texture == 452109
		and prog.card.azWoodBorder ~= nil and prog.card.azBg.texture == 235397 end)
	Open("guide")
	local guide = f.guide
	Expect(bad, "guide", function() return guide.azPage.texture == 235412 and guide.title.azKeep and guide.azBand.texture == 235411
		and guide.azFiligree.l.texture == 130670 and (#guide.heads == 0 or guide.heads[1].azKeep) and guide.rows[1].azHl:IsShown() end)
	Check("[CZ] habits Azeroth : les textures du client, page par page", #bad == 0, table.concat(bad, ", "))
	Check("[CZ] plaque : titre du carnet, points des hauts faits (plaque et grand bouclier)", plate.title:GetText() == NS.L.JRN_TITLE
		and plate.count:GetText() == NS:F("CARNET_AZ_POINTS", (NS:FeatPoints()))
		and hf.azShieldText:GetText() == tostring((NS:FeatPoints())))
	-- surbrillances : seule l'entrée choisie, dorée
	Open("evolution")
	Check("[CZ] seule l'entrée choisie s'éclaire, en or", item.tint:IsShown() and not f.sections.feats.tint:IsShown()
		and item.tint.gradientSpec and item.tint.gradientSpec[2][1] > item.tint.gradientSpec[2][3])
	local need = evo.needs[1]
	need.bar.ratio = 0.15; need.bar:SetColor(1, 1, 1)
	local low = need.bar.azColor == NS.CARNET_COLORS.orange
	need.bar.ratio = 0.9; need.bar:SetColor(1, 1, 1)
	Check("[CZ] envies : basse orange, comblée verte", low and need.bar.azColor == NS.CARNET_COLORS.green)
	Open("menagerie")
	local followed = men.states.all.azHl:IsShown() and not men.states.captured.azHl:IsShown()
	men.stateRow:Select("captured")
	Check("[CZ] puces d'état : la surbrillance suit le choix", followed and men.states.captured.azHl:IsShown()
		and not men.states.all.azHl:IsShown())
	men.stateRow:Select("all")
	Open("feats")
	Check("[CZ] catégories des hauts faits : la choisie en or", hf.cats[1].azHl:IsShown() and not hf.cats[2].azHl:IsShown())
	Open("guide")
	NS:ScrollJournal(-1)
	ok, errs = NoErrors()
	Check("[CZ] toutes les pages et la molette sans erreur", ok and f.guide:IsShown(), errs)
end

-- 2. Encres par rôle, voiles, marges, infobulles (2.8.2, 2.11.0 fiche 08) ----------------------------------
do
	Say("-- carnet azeroth : encres et placement")
	CZ.Reset()
	local f = Open()
	Check("[CZ] voiles des pages, de la colonne ; titre à l'encre du grand titre (l'or ombré tombait à 1,7:1)",
		math.abs(f.content.azVeil.vertex[4] - INK.alpha.page) < 0.001 and math.abs(f.nav.azVeil.vertex[4] - INK.alpha.nav) < 0.001
		and f.header.title.azKeep and Same(f.header.title.textColor, INK[CONTRAST["page.title"][1]]))
	local item = f.sections.feats
	item:SetBadge("2")
	local lp, bp = Point(item.label, "LEFT"), Point(item.badge, "RIGHT")
	Check("[CZ] catégorie : texte et compteur dans leur fond, avec marge", lp and lp.relTo == item.azBg and lp.x == LAY.navPad
		and lp.x >= 10 and lp.x <= 14 and bp and bp.relTo == item.azBg and bp.x == -LAY.navBadgePad and bp.x < 0)
	NS:SelectJournalKind("feats")
	local row = f.feats.rows[1]
	row.entry.got = { at = 1800000000 }
	NS.CARNET_PAGE_POSTS.feats(NS, f)
	Check("[CZ] haut fait obtenu : fond voilé, encres par rôle", row.azVeil:IsShown() and Painted(row.desc, "feat.desc")
		and Painted(row.reward, "feat.reward") and Painted(row.date, "feat.date") and Same(row.name.textColor, INK.white))
	row.entry.got = nil
	NS.CARNET_PAGE_POSTS.feats(NS, f)
	Check("[CZ] pas encore : parchemin sombre, texte clair ; étiquette Compte opaque", row.azBg.texture == 130660
		and not row.azVeil:IsShown() and Painted(row.desc, "featOpen.desc") and Painted(row.reward, "featOpen.reward")
		and row.scope.bg:IsShown() and row.scope.bg.vertex[4] >= 0.9 and row.scope.azBg.vertex[1] == 0.5)
	NS:JournalFeatsTip(row)
	local tp = GameTooltip.lastPoint
	local right = tp and tp.relTo == row and tp.point == "TOPLEFT" and tp.relPoint == "TOPRIGHT" and tp.x == NS.JOURNAL_TIP_GAP
	local getRight = UIParent.GetRight
	UIParent.GetRight = function() return 1920 end
	row.GetRight = function() return 1800 end
	NS:JournalFeatsTip(row)
	tp = GameTooltip.lastPoint
	Check("[CZ] infobulle d'un haut fait : à droite de la ligne, sinon dessous", right and tp.relTo == row
		and tp.point == "TOPRIGHT" and tp.relPoint == "BOTTOMRIGHT")
	row.GetRight, UIParent.GetRight = nil, getRight
	NS:SelectJournalKind("menagerie")
	local men = f.men
	local mrow = men.items[1]
	mrow.entry = { known = true, class = "elite", npc = 1 }
	NS.CARNET_PAGE_POSTS.menagerie(NS, f)
	local known = mrow.azVeil:IsShown() and Painted(mrow.no, "men.no") and Same(mrow.label.textColor, INK.rElite)
		and Painted(mrow.detail, "men.detail")
	mrow.entry = { known = false, npc = 2 }
	NS.CARNET_PAGE_POSTS.menagerie(NS, f)
	Check("[CZ] Créatures : connue voilée (n°, type à l'encre, nom à sa rareté) ; jamais croisée, texte clair", known
		and Same(mrow.label.textColor, INK.light) and not mrow.azVeil:IsShown())
	local strip = men.collection
	Check("[CZ] sceau : bloc voilé, titre et dresseur lisibles", strip.azVeil:IsShown() and Same(strip.title.textColor, INK.ink)
		and Same(strip.trainer.textColor, INK.amber))
	local typeButton = men.types and men.types.buttons[1]
	local enter = typeButton and typeButton:GetScript("OnEnter")
	if enter then enter(typeButton) end
	tp = GameTooltip.lastPoint
	Check("[CZ] infobulle d'un type : sous le bouton (la rangée de commandes reste visible)", enter ~= nil and tp.relTo == typeButton
		and tp.point == "TOP" and tp.relPoint == "BOTTOM")
	-- 2.11.0 fiche 08 : chaque texte repeint porte un rôle déclaré, aucun repli « assombri »
	for _, kind in ipairs({ "evolution", "menagerie", "feats", "day", "progress", "guide" }) do NS:SelectJournalKind(kind) end
	local misses, unknown, roled = NS.carnetInkMisses or {}, {}, 0
	for _, fs in ipairs(f.azReg.texts) do
		if fs.azRole then roled = roled + 1 end
		if fs.azRole and not CONTRAST[fs.azRole] then unknown[#unknown + 1] = fs.azRole end
	end
	Check("[CZ] aucun texte au repli « assombri », chaque rôle posé existe dans la table", #misses == 0 and #unknown == 0
		and roled > 0, table.concat(misses, " | ") .. " / " .. table.concat(unknown, ", "))
	local pantryOK = f.azPlate.count.azRole == "plate.count"
	for _, button in pairs(f.pantry or {}) do
		if button.count and (button.count.azRole ~= "pantry.count" or not (button.azShade and button.azShade:IsShown())) then pantryOK = false end
	end
	Check("[CZ] case des points et garde-manger : chiffre sur son ombre, à son rôle", pantryOK)
	local ok, errs = NoErrors()
	Check("[CZ] encres sans erreur", ok, errs)
	f:Hide()
end

-- 3. Mise en page : textes centrés dans leur plaque, rien ne se chevauche --------------------------------
do
	Say("-- carnet : mise en page")
	CZ.Reset()
	local f = Open("guide")
	-- guide : bande du titre, filigrane, puis le texte
	local guide, G, TOP = f.guide, NS.CARNET_GUIDE_LAYOUT, NS.JOURNAL_LAYOUT.top
	local bandBottom = TOP + G.bandUp - G.bandH
	local filTop = select(5, guide.azFiligree.l:GetPoint())
	local first = guide.paras[1] or guide.heads[1]
	Check("[CZ] guide : bande du titre, filigrane, texte, sans chevauchement", bandBottom >= filTop and filTop == TOP - G.filigreeY
		and guide.bodyTop == TOP - G.bodyY and guide.bodyTop < filTop - G.filigreeH
		and (first == nil or select(5, first:GetPoint()) <= guide.bodyTop), bandBottom .. " / " .. tostring(filTop))
	local head = guide.heads[1]
	Check("[CZ] guide : titre doré centré sur sa bande, intertitres brun-rouge, voile 50 %", Point(guide.title, "LEFT").relTo == guide.azBand
		and Same(guide.title.textColor, INK.goldHead) and (head == nil or Same(head.textColor, INK.head))
		and math.abs(guide.azVeil.vertex[4] - INK.alpha.guide) < 0.001)
	-- 2.9.0 : Exploration, textes centrés verticalement sur leur zone
	NS:SelectJournalKind("progress")
	local pane, PG = f.prog, NS.CARNET_PROGRESS_LAYOUT
	local row = pane.zones[1]
	row.bar:Show()
	NS.CarnetZoneRowText(row)
	local top, bottom = Point(row.name, "TOPLEFT"), Point(row.name, "BOTTOMLEFT")
	local barY = select(5, row.bar:GetPoint())
	local withBar = top and bottom and top.relTo == row and top.y == -PG.rowPad and bottom.relTo == row
		and bottom.relPoint == "TOPLEFT" and bottom.y == barY and row.name.justifyV == "MIDDLE"
		and Point(row.percent, "BOTTOMRIGHT").y == barY and row.percent.justifyV == "MIDDLE"
		and Point(row.here, "BOTTOMRIGHT") and row.here.justifyV == "MIDDLE"
	row.bar:Hide()
	NS.CarnetZoneRowText(row)
	bottom = Point(row.name, "BOTTOMLEFT")
	Check("[CZ] Exploration, zone : nom, % et « ici » centrés au-dessus de la barre, ou sur toute la rangée sans barre", withBar
		and bottom and bottom.relPoint == "BOTTOMLEFT" and bottom.y == PG.rowPad and #row.name.points == 2)
	local tile = pane.parts[1]
	local lt, lb = Point(tile.label, "TOPLEFT"), Point(tile.label, "BOTTOMLEFT")
	local tileBar = select(5, tile.bar:GetPoint())
	Check("[CZ] Exploration, part : libellé et compte centrés entre le haut et le liseré de la barre", lt and lb and lt.y == -PG.partTop
		and lb.relPoint == "TOPLEFT" and lb.y == tileBar + PG.barEdge and tile.label.justifyV == "MIDDLE"
		and Point(tile.count, "BOTTOMRIGHT").y == lb.y and tile.count.justifyV == "MIDDLE")
	local plate = f.azPlate
	local cp = Point(plate.count, "CENTER")
	Check("[CZ] plaque : nombre centré dans sa case, titre centré", cp and cp.relTo == plate.box and cp.x == NS.CARNET_PLATE_COUNT.x
		and cp.y == NS.CARNET_PLATE_COUNT.y and plate.count.justifyH == "CENTER" and plate.count.justifyV == "MIDDLE"
		and plate.title.justifyV == "MIDDLE" and plate.title.justifyH == "CENTER")
	-- 2.9.0 : boucliers des points (même gabarit doré/gris, nombre au centre de l'écu)
	NS:SelectJournalKind("feats")
	local hf = f.feats
	local frow = hf.rows[1]
	frow.entry.got = nil
	NS:RefreshJournal()
	local size, face = NS.AZEROTH_SHIELD_SIZE.row, NS.AZEROTH_SHIELD_FACE
	local pp = Point(frow.pts, "CENTER")
	Check("[CZ] ligne : bouclier au rapport de l'atlas, gris de même gabarit, nombre au centre de l'écu",
		frow.shield:GetWidth() == size[1] and frow.shield:GetHeight() == size[2] and math.abs(size[1] / size[2] - 63 / 56) < 0.02
		and frow.shield:IsShown() and frow.shield.atlas == "ui-achievement-shield-1-desaturated" and pp and pp.relTo == frow.shield
		and pp.x == math.floor(size[1] * face.x + 0.5) and pp.y == math.floor(size[2] * face.y + 0.5) + face.digits
		and frow.pts.justifyH == "CENTER" and frow.pts.justifyV == "MIDDLE", pp and (pp.x .. "," .. pp.y))
	local big, B = hf.azShield, NS.CARNET_SHIELD_BIG
	local tc = big.texCoord
	local sp = Point(hf.azShieldText, "CENTER")
	Check("[CZ] en-tête : grand bouclier recadré sur son dessin, sans déformer, nombre centré", tc and math.abs(tc[1] - 29 / 128) < 1e-6
		and math.abs(tc[2] - 99 / 128) < 1e-6 and math.abs(tc[3] - 39 / 128) < 1e-6 and math.abs(tc[4] - 90 / 128) < 1e-6
		and big:GetWidth() == B.w and big:GetHeight() == B.h and math.abs((B.w / B.h) / (70 / 51) - 1) < 0.05
		and sp and sp.relTo == big and sp.x == 0 and sp.y == B.y and hf.azShieldText.justifyH == "CENTER"
		and hf.azShieldText.justifyV == "MIDDLE")
	local feats = NS.FeatPoints
	NS.FeatPoints = function() return 1250 end
	NS.CARNET_PAGE_POSTS.feats(NS, f)
	local four = hf.azShieldText.font and hf.azShieldText.font.size == B.font[4] and hf.azShieldText.font.flags == "OUTLINE"
	NS.FeatPoints = function() return 95 end
	NS.CARNET_PAGE_POSTS.feats(NS, f)
	Check("[CZ] en-tête : 4 chiffres en police réduite, 2 chiffres pleine taille", four and hf.azShieldText.font.size == B.font[2]
		and hf.azShieldText:GetText() == "95")
	NS.FeatPoints = feats
	local icon = f.azPlate.icon
	tc = icon.texCoord
	Check("[CZ] petit bouclier de la plaque : recadré (20×18 sur 32), à sa taille", tc and math.abs(tc[2] - 20 / 32) < 1e-6
		and math.abs(tc[4] - 18 / 32) < 1e-6 and icon:GetWidth() == 20 and icon:GetHeight() == 18)
	-- 2.9.0 : bloc « Ses effets » de la page Compagnon à l'encre mesurée, même repeint par son horloge
	NS:SelectJournalKind("evolution")
	local evo = f.evo
	local pending = not (NS:CompanionEffects() or {}).active
	local line, state = pending and "effects.linePending" or "effects.line", pending and "effects.statePending" or "effects.state"
	NS:CompanionEffectsRefreshPane(evo)
	Check("[CZ] « Ses effets » : intertitre et lignes à l'encre mesurée, après l'horloge aussi", Painted(evo.effTitle.label, "section.label")
		and Painted(evo.effHunt, line) and Painted(evo.effComfort, line) and Painted(evo.effState, state))
	local real = NS.CompanionEffects
	NS.CompanionEffects = function(self)
		local copy = {}
		for k, v in pairs(real(self) or {}) do copy[k] = v end
		copy.active, copy.remaining = true, 0
		return copy
	end
	NS:CompanionEffectsRefreshPane(evo)
	Check("[CZ] effets actifs : l'encre pleine", Painted(evo.effHunt, "effects.line") and Painted(evo.effState, "effects.state"))
	NS.CompanionEffects = real
	local ok, errs = NoErrors()
	Check("[CZ] mise en page sans erreur", ok, errs)
	CZ.Done()
end

-- 4. Plaques de chiffres, étoiles, Missions, colonne de navigation (2.11.0, 2.11.1) ---------------------
do
	Say("-- carnet : plaques, étoiles, missions, colonne")
	local centred, fitted = {}, {}
	for _, style in ipairs({ "sobre", "azeroth" }) do
		CZ.Reset(style)
		local f = Open("evolution")
		-- C5 : le groupe (haut du chiffre, bas du libellé) centré à 1 px près
		local S = NS.JOURNAL_STAT_LAYOUT
		for key, tile in pairs(f.evo.stats) do
			local vp, lp = tile.value.lastPoint, tile.label.lastPoint
			local hv = (select(2, tile.value:GetFont()) or 16) * S.glyph
			local hl = (select(2, tile.label:GetFont()) or 11) * S.glyph
			local top, bottom = vp.y + hv / 2, lp.y - hl / 2
			if not (vp.point == "CENTER" and lp.point == "CENTER" and vp.relTo == tile and math.abs(top + bottom) <= 1
				and (vp.y - hv / 2) - (lp.y + hl / 2) <= S.gap + 1 and vp.y > 0 and lp.y < 0) then
				centred[#centred + 1] = style .. ":" .. key .. " " .. vp.y .. "/" .. lp.y
			end
		end
		-- C4 : résumé de la colonne borné à sa largeur intérieure (marges égales)
		local box = f.navSummary
		local navW = style == "azeroth" and LAY.nav or NS.JOURNAL_LAYOUT.nav
		local inner = navW - 2 * (box.lastPoint.x or 0)
		local ok = box.fitW and box.fitW <= inner and box:GetWidth() == box.fitW
		for _, block in ipairs({ box.pet, box.zone, box.missions }) do
			ok = ok and block:GetWidth() == box.fitW and block.rule:GetWidth() == box.fitW
		end
		for _, r in ipairs(box.pet.needs) do ok = ok and NS.JOURNAL_NAVSUM.labelW + r.bar:GetWidth() <= box.fitW end
		ok = ok and box.zone.bar:GetWidth() <= box.fitW
		for _, r in ipairs(box.missions.rows) do ok = ok and NS.JOURNAL_NAVSUM.labelW + 3 * 14 + r.left:GetWidth() <= box.fitW end
		if not ok then fitted[#fitted + 1] = style .. " " .. tostring(box.fitW) .. "/" .. tostring(inner) end
	end
	Check("[CZ] plaques de chiffres : chiffre et libellé groupés au centre (deux styles)", #centred == 0, table.concat(centred, ", "))
	Check("[CZ] colonne : barres, % et jours dans la largeur intérieure (deux styles)", #fitted == 0, table.concat(fitted, ", "))
	-- B1 : libellés courts ; en Azeroth, à leur rôle
	CZ.Reset("sobre")
	local f = Open("evolution")
	local short = f.evo.stats.missions.label.text == "missions" and f.evo.stats.km.label.text == "parcourus"
	-- fiche 14 : la colonne en tableau de bord, rafraîchie sans rien créer, cliquable
	local box = f.navSummary
	local before = #Mock.frames
	NS:RefreshJournal(); NS:RefreshJournal()
	Check("[CZ] colonne : trois blocs, rafraîchis sans rien créer, nom du compagnon", box and box.pet and box.zone and box.missions
		and #box.pet.needs == 4 and #Mock.frames == before and box.pet.name.text:find(NS:CompanionName(), 1, true) ~= nil,
		#Mock.frames .. " / " .. before)
	box.missions:GetScript("OnClick")(box.missions)
	local toDay = f.kind == "day"
	box.pet:GetScript("OnClick")(box.pet)
	Check("[CZ] colonne : clic sur les missions → Missions, sur le compagnon → sa page", toDay and f.kind == "evolution")
	CZ.Reset("azeroth")
	f = Open("evolution")
	local tile = f.evo.stats.days
	box = f.navSummary
	Check("[CZ] plaques : libellés courts ; Azeroth : chiffres, libellés et colonne à leur rôle", short
		and tile.value.azRole == "stat.value" and tile.label.azRole == "stat.label" and Same(tile.label.textColor, INK.statLabel)
		and box.pet.name.azRole == "navSum.name" and box.pet.needs[1].label.azRole == "navSum.label"
		and box.missions.rows[2].label.azRole == "navSum.label")
	-- B2 : étoiles des Créatures
	Open("menagerie")
	local row = f.men.items[1]
	local built = row.stars and #row.stars == 3 and row.stars[1].star.atlas == "auctionhouse-icon-favorite"
		and row.stars[1].edge.atlas == "auctionhouse-icon-favorite"
	NS.MenagerieRowStars(row, 2)
	local s1, s3 = row.stars[1], row.stars[3]
	Check("[CZ] étoiles : trois (atlas du jeu), 2 sur 3 pleines dorées, la 3e brun grisé, cerne sombre", built and s1.star.full
		and not s3.star.full and Same(s1.star.vertex, NS.MEN_STAR.full) and Same(s3.star.vertex, NS.MEN_STAR.empty)
		and Same(s1.edge.vertex, NS.MEN_STAR.edge) and s1.edge:IsShown() and s1.edge.width > s1.star.width)
	NS.MenagerieRowStars(row, nil)
	Check("[CZ] étoiles : sans capture, aucune", not s1.star:IsShown() and not s1.edge:IsShown())
	-- B3 / B4 : page Missions
	Open("day")
	local MIS = NS.JOURNAL_MISSIONS_LAYOUT
	local plaque = f.day.summary.week
	local pip = plaque.pips[1]
	Check("[CZ] bande résumé : détail sur deux lignes, pastilles en bas sous le détail, compte sur la ligne du titre",
		plaque.height == MIS.sumH and plaque.detail.wordWrap ~= false and plaque.detail.lastPoint.y == MIS.sumDetailY
		and pip.lastPoint.point == "BOTTOMLEFT" and pip.lastPoint.y == MIS.sumPipY
		and -MIS.sumDetailY + MIS.sumDetailH <= MIS.sumH - MIS.sumPipY - 5 and plaque.count.lastPoint.point == "TOPRIGHT"
		and plaque.count.lastPoint.y == plaque.label.lastPoint.y)
	local title = f.day.groups.trait
	Check("[CZ] Missions : intertitres à l'encre sur le parchemin, filet dessous ; étiquette du caractère foncée",
		title.azSurface == "light" and title.azRule:IsShown() and title.label.azRole == "mheader.label"
		and Same(title.label.textColor, INK.head) and f.day.innTitle.azStrip:IsShown()
		and Same(f.day.chips.trait.bg.vertex, NS.AZEROTH_MISSION.chipTrait) and f.day.chips.trait.text.azRole == "chip.trait")
	CZ.Done()
end

-- 5. Le Sobre inchangé, le changement de style à chaud, le repli, Échap ----------------------------------
do
	Say("-- carnet : sobre, à chaud, repli")
	CZ.Reset("sobre")
	local f = Open("feats")
	Check("[CZ] Sobre : aucun habit Azeroth", f and not f.azeroth and f.uiStyle == "sobre" and not f.azPlate
		and f:GetWidth() == NS.JOURNAL_LAYOUT.width and not f.sections.feats.azBg and not f.feats.rows[1].azTitle)
	Mock.InstallAtlas(true)
	NS:AzerothAtlasOK(true)
	NS:SetUIStyle("azeroth")
	local g = NS.journalFrame
	local swapped = g and g ~= f and g.azeroth and g:IsShown() and not f:IsShown() and g.kind == "feats"
	NS:SetUIStyle("sobre")
	Check("[CZ] à chaud : le carnet affiché remplacé (même page), puis l'ancien revient (gardé)", swapped
		and NS.journalFrame == f and f:IsShown() and not g:IsShown())
	NS.journalFrame:Hide()
	NS:SetUIStyle("azeroth")
	Check("[CZ] carnet fermé : rien n'est construit avant l'ouverture, puis celui du style (gardé)", NS.journalFrame == nil
		and Open() == g)
	-- repli : textures refusées par le client
	CZ.Reset("azeroth", { [130661] = true, [235402] = true, [130652] = true })
	local h = Open("feats")
	Check("[CZ] repli : page, plaque, catégories refusées → leurs parts Sobre, texte clair", h.azeroth and not h.content.azBg
		and h.content.azSurface == nil and not h.content.bg and h.azPlate == nil and not h.brand.mockHidden
		and h.sections.feats.azBg == nil and h.sections.feats.tint.texture ~= 235400 and h.nav.azSurface == nil
		and not h.nav.bg.mockHidden and h.feats.totals.textColor[1] > 0.8)
	local ok, errs = NoErrors()
	Check("[CZ] repli : les fichiers refusés sont notés, sans erreur", NS.carnetMissing[130661] and NS.carnetMissing[235402] and ok, errs)
end

-- 2.10.0 : Échap ferme le carnet et la fiche après des allers-retours de style.
-- Le client ferme à Échap le cadre _G[nom] : la DERNIÈRE frame créée sous ce nom.
local function EscapeClose()
	for _, name in ipairs(UISpecialFrames) do
		local last
		for _, region in ipairs(Mock.frames) do
			if region.GetName and region:GetName() == name then last = region end
		end
		if last and last:IsShown() then last:Hide() end
	end
end
local function Count(name)
	local n = 0
	for _, existing in ipairs(UISpecialFrames) do if existing == name then n = n + 1 end end
	return n
end
do
	Say("-- Échap : un nom global par style (carnet, fiche)")
	CZ.Reset("sobre")
	local first = #Mock.frames + 1
	-- open() : ouvre la fenêtre ; rend les étapes où Échap ne l'a pas fermée
	local function RoundTrip(open, sobreName, azName)
		local bad = {}
		local a = open()
		EscapeClose()
		if not (a and not a:IsShown() and a:GetName() == sobreName) then bad[#bad + 1] = "sobre" end
		NS:SetUIStyle("azeroth")
		local b = open()
		if not (b and b ~= a and b:GetName() == azName) then bad[#bad + 1] = "nom azeroth" end
		EscapeClose()
		if b and b:IsShown() then bad[#bad + 1] = "azeroth" end
		NS:SetUIStyle("sobre")
		local c = open()
		if not (c == a and c:IsShown()) then bad[#bad + 1] = "retour" end
		EscapeClose()
		if c and c:IsShown() then bad[#bad + 1] = "sobre après aller-retour" end
		return bad
	end
	Mock.InstallAtlas(true)
	NS:AzerothAtlasOK(true)
	local bad = RoundTrip(function() return Open("feats") end, "QuestCompanionJournalFrame", "QuestCompanionJournalFrameAzeroth")
	Check("[CZ] Échap : carnet fermé dans chaque style, après les allers-retours", #bad == 0, table.concat(bad, ", "))
	bad = RoundTrip(function() return NS:TrainerOpen(nil) end, "QuestCompanionTrainerFrame", "QuestCompanionTrainerFrameAzeroth")
	Check("[CZ] Échap : fiche de dresseur fermée dans chaque style, après les allers-retours", #bad == 0, table.concat(bad, ", "))
	Check("[CZ] les quatre noms sont dans UISpecialFrames, une fois chacun", Count("QuestCompanionJournalFrame") == 1
		and Count("QuestCompanionJournalFrameAzeroth") == 1 and Count("QuestCompanionTrainerFrame") == 1
		and Count("QuestCompanionTrainerFrameAzeroth") == 1)
	-- garde-fou : aucun nom d'Échap porté par deux fenêtres vivantes
	local owner, shared = {}, {}
	for _, name in ipairs(UISpecialFrames) do owner[name] = false end
	for index = first, #Mock.frames do
		local region = Mock.frames[index]
		local name = region.GetName and region:GetName()
		if name and owner[name] ~= nil then
			if owner[name] and owner[name] ~= region then shared[#shared + 1] = name end
			owner[name] = region
		end
	end
	local ok, errs = NoErrors()
	Check("[CZ] garde-fou : aucun nom d'Échap partagé par deux fenêtres, sans erreur", #shared == 0 and ok,
		table.concat(shared, ", ") .. " " .. errs)
end

-- 6. « Localiser », filtre et recherche des zones, état mémorisé (2.11.0 B6, fiches 13, 27) ---------------
local function PinApi(can)
	local pins = { set = 0, clear = 0, track = 0 }
	_G.UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
	_G.C_Map = {
		SetUserWaypoint = function(point) pins.point = point; pins.set = pins.set + 1 end,
		ClearUserWaypoint = function() pins.point = nil; pins.clear = pins.clear + 1 end,
		HasUserWaypoint = function() return pins.point ~= nil end,
		CanSetUserWaypointOnMap = function() return can ~= false end,
		GetBestMapForUnit = function() return 1413 end,
	}
	_G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) if on then pins.track = pins.track + 1 end end }
	return pins
end
do
	Say("-- carnet : « Localiser »")
	CZ.Reset("sobre")
	local savedQ, savedC = NS.ZONE_QUEST_POS, NS.ZONE_CREATURE_POS
	NS.ZONE_QUEST_POS = { [1413] = "100\t500250\n200\t010999\n" }
	NS.ZONE_CREATURE_POS = { [1413] = "3201\t300700\n" }
	local x, y = NS:ZonePoint("quest", 1413, 200)
	Check("[CZ] point d'une quête lu sans découper la chaîne", x == 0.01 and y == 0.999 and NS:ZonePoint("quest", 1413, 100) == 0.5
		and NS:ZonePoint("quest", 1413, 20) == nil and NS:ZonePoint("quest", 1411, 100) == nil)
	_G.C_Map, _G.UiMapPoint = nil, nil
	Check("[CZ] sans API : pas de repère", NS:MapPinAvailable(1413) == false and NS:MapPinToggle("quest:200", 1413, x, y) == false)
	local pins = PinApi()
	local items = NS.JournalProgressItems
	NS.JournalProgressItems = function() return { { id = 200, name = "Consumé par la haine", detail = "niveau 20" },
		{ id = 300, name = "Sans donneur", detail = "niveau 3" } }, {} end
	local f = Open("progress")
	f.progPart = "quests"
	NS:RefreshJournal()
	local pane = f.prog
	local hidden = not pane.locate:IsShown()
	pane.items[1]:GetScript("OnClick")(pane.items[1])
	Check("[CZ] « Localiser » : caché sans choix, sur la ligne de la quête choisie", hidden and f.progQuest == 200
		and pane.locate:IsShown() and pane.locate.lastPoint.relTo == pane.items[1] and pane.locate.text.text == "Localiser")
	pane.locate:GetScript("OnClick")(pane.locate)
	Check("[CZ] clic : repère posé (carte, coordonnées), suivi à l'écran", pins.set == 1 and pins.point.map == 1413
		and pins.point.x == 0.01 and pins.track == 1 and pane.locate.text.text == "Effacer")
	pane.locate:GetScript("OnClick")(pane.locate)
	Check("[CZ] 2e clic : repère retiré", pins.clear == 1 and pins.point == nil and pane.locate.text.text == "Localiser")
	pane.items[2]:GetScript("OnClick")(pane.items[2])
	Check("[CZ] quête sans point connu : pas de bouton", f.progQuest == 300 and not pane.locate:IsShown())
	NS.JournalProgressItems = items
	PinApi()
	local preview = f.men and f.men.preview
	if preview then
		preview.entry = nil
		NS:JournalPreviewMenagerie({ npc = 3201, known = true, name = "Kodo", zoneID = 1413, class = "normal" })
		local shown = preview.locate:IsShown()
		NS:JournalPreviewMenagerie({ npc = 9999, known = true, name = "Inconnu", zoneID = 1413, class = "normal" })
		Check("[CZ] fiche d'une créature : « Localiser » si son point est connu, caché sinon", shown and not preview.locate:IsShown())
	end
	NS.ZONE_QUEST_POS, NS.ZONE_CREATURE_POS = savedQ, savedC
	Check("[CZ] tables générées : points des quêtes et des créatures", type(savedQ) == "table" and type(savedC) == "table"
		and NS:ZonePoint("quest", 1411, 784) ~= nil)
	CZ.Done()
end
do
	Say("-- carnet : liste des zones, état mémorisé")
	CZ.Reset("sobre")
	_G.UnitLevel = function() return 8 end
	_G.UnitFactionGroup = function() return "Horde" end
	local all = {
		{ id = 1411, name = "Durotar", seen = true, here = true, lo = 1, hi = 10, percent = 40 },
		{ id = 1429, name = "Elwynn", seen = false, lo = 1, hi = 10 },
		{ id = 1412, name = "Mulgore", seen = false, lo = 1, hi = 10 },
		{ id = 1440, name = "Ashenvale", seen = true, lo = 18, hi = 30, percent = 20 },
		{ id = 1434, name = "Strangleorn", seen = false, lo = 30, hi = 45 },
		{ id = 1413, name = "Barrens", seen = true, lo = 10, hi = 25, percent = 100 },
	}
	local function Ids(list) local out = {} for _, z in ipairs(list) do out[#out + 1] = z.id end return table.concat(out, ",") end
	Check("[CZ] « Pour moi » : ici, commencées, de mon niveau, sans l'autre faction",
		Ids(NS:JournalFilterZones(all, "mine")) == "1411,1412,1440,1413", Ids(NS:JournalFilterZones(all, "mine")))
	Check("[CZ] « Commencées », « Toutes », recherche sur le nom sans casse", Ids(NS:JournalFilterZones(all, "seen")) == "1411,1440,1413"
		and #NS:JournalFilterZones(all, "all") == 6 and Ids(NS:JournalFilterZones(all, "all", "MUL")) == "1412")
	local f = Open("progress")
	local pane = f.prog
	local default = pane.zoneFilter:GetValue() == "mine" and pane.zoneSearch ~= nil and pane.zones[1].lastPoint.y < pane.zoneFilter.lastPoint.y
	pane.zoneFilter:Choose("all")
	Check("[CZ] filtre « Pour moi » par défaut, au-dessus des zones ; le choix est mémorisé", default and f.progFilter == "all"
		and NS:DB().journalState.progFilter == "all")
	local base = NS.JournalAllZones
	pane.zoneSearch:SetText("zz")
	pane.zoneSearch.scripts.OnTextChanged(pane.zoneSearch)
	Mock:RunTimers()
	Check("[CZ] recherche sans résultat : liste vide, message affiché", f.progSearch == "zz" and #pane.zoneList == 0 and pane.zoneEmpty:IsShown())
	local n = 0
	NS.JournalAllZones = function(...) n = n + 1; return base(...) end
	NS:ScrollJournal(-1)
	NS.JournalAllZones = base
	Check("[CZ] un cran de molette ne recalcule pas les zones", n == 0)
	-- fiche 27 : état mémorisé, recherche différée
	CZ.Reset("sobre")
	f = Open("menagerie")
	pane = f.men
	pane.rank:Choose("rare")
	pane.sort:Choose("name")
	pane.stateRow.chips[2]:GetScript("OnClick")(pane.stateRow.chips[2])
	NS:JournalProgressPart("quests")
	local state = NS:DB().journalState
	local noted = state.menRank == "rare" and state.menSort == "name" and state.progPart == "quests" and state.menState ~= nil
	state.menState = "obsolete"
	f:Hide()
	NS.journalFrame = nil
	NS.uiStyleCache = {}
	f = Open("menagerie")
	Check("[CZ] choix notés ; carnet reconstruit : retrouvés, valeur inconnue ignorée", noted and f.menRank == "rare"
		and f.menSort == "name" and f.progPart == "quests" and f.menState == "all" and f.men.rank:GetValue() == "rare")
	NS:OpenMenagerieZone(1413)
	Check("[CZ] ouvrir une zone depuis sa fiche ne touche pas aux choix", NS:DB().journalState.menRank == "rare")
	local refresh, count = NS.RefreshJournal, 0
	NS.RefreshJournal = function(...) count = count + 1; return refresh(...) end
	for _, text in ipairs({ "k", "ko", "kod", "kodo" }) do
		f.men.search:SetText(text)
		f.men.search.scripts.OnTextChanged(f.men.search)
	end
	local typed = count
	Mock:RunTimers()
	NS.RefreshJournal = refresh
	Check("[CZ] recherche : un seul rafraîchissement après la frappe", typed == 0 and count == 1 and f.menSearch == "kodo",
		typed .. " / " .. count)
	CZ.Done()
end

-- 7. « Changer de compagnon ? » : au style, au-dessus du carnet, Échap d'abord (2.11.0 B8, 2.11.1 C6) -----
do
	Say("-- carnet : « Changer de compagnon ? »")
	CZ.Reset("azeroth")
	local az = NS:EnsureEffectsConfirm()
	Check("[CZ] Azeroth : parchemin, encadré en bois, encres mesurées, bouton rouge, Annuler brun", az and az.azDialog
		and az.azBg.texture == 130661 and az.azWoodBorder ~= nil and not az.bg:IsShown() and az.title.azRole == "dialog.title"
		and az.text.azRole == "dialog.text" and Same(az.text.textColor, INK.ink) and az.ok.azSkin == "red" and az.cancel.azSkin == "brown")
	local once = NS:EnsureEffectsConfirm() == az
	NS:DB().companionStyle = "sobre"
	local sobre = NS:EnsureEffectsConfirm()
	local own = sobre and sobre ~= az and not sobre.azDialog and NS.effectsConfirm == sobre
	NS:DB().companionStyle = "azeroth"
	Check("[CZ] une fenêtre par style, construite une fois, reprise au retour", once and own and NS:EnsureEffectsConfirm() == az)
	local bad = { place = {}, keys = {}, escape = {}, closed = {}, combat = {} }
	for _, style in ipairs({ "azeroth", "sobre" }) do
		CZ.Reset(style)
		local journal = Open("menagerie")
		journal:SetFrameLevel(30)
		local d = NS:EnsureEffectsConfirm()
		function d:EnableKeyboard(on) self.keyboard = on end
		function d:SetPropagateKeyboardInput(on) self.propagate = on end
		function d:Raise() self.raised = true end
		local applied = false
		d.pending = { apply = function() applied = true end }
		if not (NS:EffectsConfirmPlace(d) == "journal" and d.lastPoint.point == "CENTER" and d.lastPoint.relTo == journal
			and d.strata == "FULLSCREEN_DIALOG" and d:GetFrameLevel() > journal:GetFrameLevel() and d.raised
			and journal.strata ~= "FULLSCREEN_DIALOG") then bad.place[#bad.place + 1] = style end
		d:Show()
		d:GetScript("OnKeyDown")(d, "W")
		if not (d.keyboard == true and d.propagate == true and d:IsShown()) then bad.keys[#bad.keys + 1] = style end
		d:GetScript("OnKeyDown")(d, "ESCAPE")
		if not (d.propagate == false and not d:IsShown() and not applied and journal:IsShown() and d.pending == nil) then
			bad.escape[#bad.escape + 1] = style
		end
		d.pending = { apply = function() applied = true end }
		NS:EffectsConfirmPlace(d)
		d:Show()
		journal:Hide()
		local onHide = journal.hooks and journal.hooks.OnHide
		if onHide and d:IsShown() then onHide(journal) end
		if d:IsShown() or applied then bad.closed[#bad.closed + 1] = style end
		-- en combat : pas de clavier (SetPropagateKeyboardInput réservé)
		_G.InCombatLockdown = function() return true end
		d.keyboard, d.propagate = nil, nil
		journal:Show()
		NS:EffectsConfirmPlace(d)
		if not (d.keyboard == false and d.propagate == nil) then bad.combat[#bad.combat + 1] = style end
	end
	Check("[CZ] question posée au centre du carnet, strate et niveau au-dessus", #bad.place == 0, table.concat(bad.place, ","))
	Check("[CZ] clavier pris, les autres touches passent au jeu", #bad.keys == 0, table.concat(bad.keys, ","))
	Check("[CZ] Échap ferme la question seule (non), le carnet reste", #bad.escape == 0, table.concat(bad.escape, ","))
	Check("[CZ] carnet fermé : question fermée sans réponse", #bad.closed == 0, table.concat(bad.closed, ","))
	Check("[CZ] en combat : ni clavier ni appel réservé", #bad.combat == 0, table.concat(bad.combat, ","))
	CZ.Done()
end

-- 8. Fiche de dresseur : titre, nom, vitrine des hauts faits, protocole ----------------------------------
function CZ.Trainer(style)
	CZ.Reset(style)
	NS:TrainerResetSession()
	_G.C_ChatInfo = { RegisterAddonMessagePrefix = function() return 0 end, SendAddonMessage = function() return 0 end,
		InChatMessagingLockdown = function() return false end }
	_G.GetNormalizedRealmName = nil
	_G.GetRealmName = nil
	NS.featsDormant = false
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.featLoginDone = true
	NS:DB().trainerShare = true
	local men = {}
	for _, def in ipairs(NS:FeatDefs()) do if def.cat == "men" and not def.pending and #men < 5 then men[#men + 1] = def end end
	for index, def in ipairs(men) do NS:FeatAward(def, { silent = true, at = 1700000000 + index * 100 }) end
	return men
end
do
	Say("-- fiche de dresseur : titre, nom, hauts faits (les deux styles)")
	local bad = { head = {}, picker = {}, showcase = {}, pin = {} }
	for _, style in ipairs({ "sobre", "azeroth" }) do
		local men = CZ.Trainer(style)
		local f = NS:TrainerOpen(nil)
		local L2 = NS.TRAINER_LAYOUT
		-- royaume illisible : celui du joueur
		if not (NS:TrainerShortName("Dyokrion-Aeternalis") == "Dyokrion" and NS:TrainerShortName("Bob-Hyjal") == "Bob-Hyjal"
			and f.header.title.text:find("Aeternalis", 1, true) == nil and f.header.title.text:find("Dyokrion", 1, true) ~= nil) then
			bad.head[#bad.head + 1] = style .. " " .. tostring(f.header.title.text)
		end
		-- le choix du titre sous le nom, loin du bouton de fermeture
		local picker = f.titlePicker
		local p = picker.points[1]
		if not (f.titleLabel:IsShown() and picker:IsShown() and f.titleLabel:GetText() == NS.L.TRAINER_TITLE_SHOWN
			and p.relTo == f.content and p.point == "TOPLEFT" and p.y == L2.titleY and select(2, f.titleLabel:GetPoint()) == f.content
			and (p.x or 0) + picker:GetWidth() < L2.width - 60 and p.y < -60 and select(1, f.close:GetPoint()) == "TOPRIGHT") then
			bad.picker[#bad.picker + 1] = style
		end
		local show = NS:TrainerFeatShowcase()
		if not (#show == 3 and show[1].def == men[5] and show[3].def == men[3] and f.featCards[1].name:GetText() == NS:FeatName(men[5])
			and f.featCards[1].date:GetText() ~= "" and f.featCards[1].pts:GetText() == tostring(men[5].pts or 0)
			and f.featsSection.detail:GetText():find("5", 1, true) ~= nil and #f.featBars == 4
			and f.featBars[1].count:GetText():find("^5/") ~= nil and f.featBars[1].bar:IsShown()
			and f.featsPicker:IsShown() and f.featsPicker:GetValue() == "auto" and f.stage:GetWidth() >= 200) then
			bad.showcase[#bad.showcase + 1] = style
		end
		f.featsPicker:Choose(men[1].id)
		show = NS:TrainerFeatShowcase()
		local pinned = show[1].def == men[1] and show[2].def == men[5] and f.featsPicker:GetValue() == "picked"
			and f.featCards[1].name:GetText() == NS:FeatName(men[1])
		f.featsPicker:Choose(men[1].id)
		local unpinned = NS:TrainerFeatShowcase()[1].def == men[5] and #NS:TrainerFeatPins() == 0
		f.featsPicker:Choose(men[2].id); f.featsPicker:Choose("auto")
		if not (pinned and unpinned and #NS:TrainerFeatPins() == 0) then bad.pin[#bad.pin + 1] = style end
		if style == "azeroth" then
			local ok, errs = NoErrors()
			Check("[CZ] fiche Azeroth : plaque, cadre à volutes, cadres d'icône, bandes, barres vertes, intertitres à l'encre",
				f.azeroth and f.azPlate and f.azPlate.title:GetText() == NS.L.TRAINER_TITLE and f.azPlate.count:GetText() ~= ""
				and f.azVine.atlas == NS.AZEROTH_ATLAS.frameRound and f.stage.azBg.texture == 1111217
				and f.featCards[1].azRing.texture == 130656 and f.featCards[1].mark.texture == 235415
				and f.azBands[1] and f.azBands[1].texture == 235411 and f.featBars[1].bar.azColor == NS.CARNET_COLORS.green
				and Painted(f.compSection.label, "section.label") and Painted(f.infoSection.label, "section.label")
				and Painted(f.badgeSection.label, "section.label") and Painted(f.featsSection.label, "section.label")
				and Painted(f.showSection.label, "section.label") and Painted(f.featsSection.detail, "section.detail") and ok, errs)
			local mark = f.featCards[1].mark
			Check("[CZ] vitrine : petit bouclier recadré (20×18 sur 32), à sa taille", mark.texCoord
				and math.abs(mark.texCoord[2] - 20 / 32) < 1e-6 and mark:GetWidth() == 20 and mark:GetHeight() == 18)
		else
			Check("[CZ] fiche Sobre : pas d'habit Azeroth", not f.azeroth and not f.azPlate and not f.featCards[1].azRing)
		end
		f:Hide()
	end
	Check("[CZ] fiche : son nom sans « -Royaume » (en-tête aussi), un autre royaume garde son suffixe", #bad.head == 0, table.concat(bad.head, ", "))
	Check("[CZ] fiche : « Titre affiché : » sous l'en-tête, le bouton de fermeture reste libre", #bad.picker == 0,
		table.concat(bad.picker, ","))
	Check("[CZ] fiche : vitrine des 3 plus récents (cartes, détail, quatre mini-barres, sélecteur)", #bad.showcase == 0,
		table.concat(bad.showcase, ","))
	Check("[CZ] fiche : épingler passe en tête, reprendre retire, « les plus récents » vide les épingles", #bad.pin == 0,
		table.concat(bad.pin, ","))

	Say("-- fiche de dresseur : vitrine dans le protocole")
	local men = CZ.Trainer("sobre")
	local text = NS:TrainerSerializeCard(NS:TrainerOwnCard())
	local fields = NS.TrainerDecode(text)
	Check("[CZ] protocole : champ hf (codes n, dates), champ hk, version inchangée", fields.hf ~= nil and fields.hk ~= nil
		and NS.TrainerUnescape(fields.hf):find(tostring(men[5].n) .. ":1700000500", 1, true) == 1 and fields.p == "1", tostring(fields.hf))
	local card = NS:TrainerParseCard(text)
	Check("[CZ] protocole : aller-retour", #card.featShowcase == 3 and card.featShowcase[1].n == men[5].n
		and card.featShowcase[1].at == 1700000500 and card.featShowcase[1].def == men[5] and card.featCats.men == 5)
	local old = NS:TrainerParseCard("p=1;n=Bob-Hyjal;sp=3")
	Check("[CZ] protocole : fiche d'avant (sans hf) lue, vitrine vide", old.species == 3 and #old.featShowcase == 0
		and old.featCats == nil)
	local enc = NS.TrainerEncode({ p = 1, n = "Bob", hf = { "abc", "99999", "9998", tostring(men[1].n), tostring(men[1].n) .. ":12",
		tostring(men[2].n) .. ":12345678901", tostring(men[3].n), tostring(men[4].n), "-1" }, hk = { "men:999", "zz:3", "shiny:x" } })
	local bad2 = NS:TrainerParseCard(enc)
	local got = {}
	for _, it in ipairs(bad2.featShowcase) do got[#got + 1] = tostring(it.n) .. ":" .. tostring(it.at) end
	Check("[CZ] protocole : codes mal formés, inconnus, en double écartés ; 3 au plus",
		#bad2.featShowcase == 3 and bad2.featShowcase[1].n == men[1].n and bad2.featShowcase[2].n == men[3].n
		and bad2.featShowcase[3].n == men[4].n and bad2.featShowcase[2].at == nil, table.concat(got, ",") .. " / " .. tostring(men[1].n))
	local _, total = NS:FeatCategoryStats("men")
	Check("[CZ] protocole : catégories inconnues écartées, nombre borné au total", bad2.featCats and bad2.featCats.men == total
		and bad2.featCats.zz == nil and bad2.featCats.shiny == nil)
	local f = NS:TrainerOpen(nil)
	NS.trainerState.cards[NS:TrainerKey("Bob-Hyjal")] = { card = card, at = NS.Now and NS.Now() or 0 }
	card.sender = "Bob-Hyjal"
	NS:TrainerOpen("Bob-Hyjal")
	Check("[CZ] fiche reçue : vitrine et mini-barres de l'autre, pas de sélecteur", f.featCards[1].name:GetText() == NS:FeatName(men[5])
		and not f.featsPicker:IsShown() and f.featBars[1].count:GetText():find("^5/") ~= nil)
	f:Hide()
end

-- 9. Raccourcis : Y pour les hauts faits, options -------------------------------------------------------
function CZ.Binds(map)
	CZ.keys, CZ.saves, CZ.combat = map or {}, 0, false
	_G.InCombatLockdown = function() return CZ.combat end
	_G.GetBindingAction = function(key) return CZ.keys[key] or "" end
	_G.SetBinding = function(key, action) CZ.keys[key] = action; return true end
	_G.SaveBindings = function(set) CZ.saves = CZ.saves + 1; CZ.set = set end
	_G.GetCurrentBindingSet = function() return 2 end
	_G.GetBindingKey = function(action)
		local list = {}
		for key, a in pairs(CZ.keys) do if a == action then list[#list + 1] = key end end
		table.sort(list)
		return unpack(list)
	end
	CZ.shift = false
	_G.IsShiftKeyDown = function() return CZ.shift end
	_G.IsControlKeyDown = function() return false end
	_G.IsAltKeyDown = function() return false end
	NS:CharData().featsKeyTried = nil
	NS.bindingDeferred = nil
	Mock:Reset()
end
do
	Say("-- raccourcis : déclarés, Y par défaut")
	CZ.Reset("sobre")
	local xml = io.open((ADDON_ROOT or ".") .. "/QuestCompanion/Bindings.xml"):read("*a")
	Check("[CZ] raccourcis déclarés (Bindings.xml, en-tête, noms, fonctions)", xml:find('name="QUESTCOMPANION_FEATS"', 1, true)
		and xml:find('header="QUESTCOMPANION"', 1, true) and xml:find("QuestCompanion_ToggleFeats()", 1, true)
		and xml:find('name="QUESTCOMPANION_JOURNAL"', 1, true) and BINDING_HEADER_QUESTCOMPANION == "QuestCompanion"
		and BINDING_NAME_QUESTCOMPANION_FEATS == "Ouvrir les hauts faits" and type(QuestCompanion_ToggleFeats) == "function")
	CZ.Binds()
	Check("[CZ] Y libre : posé, enregistré, une ligne dans le chat", NS:BindingDefaultTry() == "bound"
		and CZ.keys.Y == "QUESTCOMPANION_FEATS" and CZ.saves == 1 and CZ.set == 2
		and Mock:Output():find("Touche Y : hauts faits (modifiable dans Raccourcis)", 1, true) ~= nil)
	CZ.keys.Y = nil
	Check("[CZ] une seule tentative : retiré ensuite, jamais remis", NS:BindingDefaultTry() == "done" and CZ.keys.Y == nil)
	CZ.Binds({ Y = "TOGGLEACHIEVEMENT" })
	Check("[CZ] Y sur les hauts faits de Blizzard (vides sur Forever) : remplacé", NS:BindingDefaultTry() == "bound"
		and CZ.keys.Y == "QUESTCOMPANION_FEATS" and CZ.saves == 1)
	CZ.Binds({ Y = "TOGGLEACHIEVEMENT" })
	NS:CharData().featsKeyTried = true
	Check("[CZ] ancienne tentative (2.8.2, Y laissé) : refaite une fois", NS:BindingDefaultTry() == "bound"
		and CZ.keys.Y == "QUESTCOMPANION_FEATS" and NS:CharData().featsKeyTried == 2)
	CZ.Binds({ Y = "TOGGLEAUTORUN" })
	Check("[CZ] Y pris par une autre action : rien ne change, rien dans le chat", NS:BindingDefaultTry() == "taken"
		and CZ.keys.Y == "TOGGLEAUTORUN" and CZ.saves == 0 and Mock:Output() == "" and NS:CharData().featsKeyTried)
	CZ.Binds()
	CZ.combat = true
	local deferred = NS:BindingDefaultTry() == "combat" and CZ.keys.Y == nil and not NS:CharData().featsKeyTried
	CZ.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Check("[CZ] en combat : reporté, posé à la fin du combat", deferred and CZ.keys.Y == "QUESTCOMPANION_FEATS"
		and NS:CharData().featsKeyTried)

	Say("-- raccourcis : bascule des hauts faits")
	QuestCompanion_ToggleFeats()
	local f = NS.journalFrame
	local opened = f and f:IsShown() and f.kind == "feats"
	QuestCompanion_ToggleFeats()
	Check("[CZ] la touche ouvre le carnet sur les hauts faits, encore : fermé", opened and not f:IsShown())
	NS:ToggleJournal(true); NS:SelectJournalKind("menagerie")
	QuestCompanion_ToggleFeats()
	Check("[CZ] carnet ouvert ailleurs : passe aux hauts faits", f:IsShown() and f.kind == "feats")
	f:Hide()

	Say("-- raccourcis : options")
	CZ.Binds({ Y = "QUESTCOMPANION_FEATS", K = "TOGGLESPELLBOOK" })
	NS:ToggleOptions()
	NS:RefreshOptions()
	local card
	for _, c in ipairs(NS.optionsFrame and NS.optionsFrame.rows or {}) do if c.def and c.def.key == "bindFeats" then card = c end end
	Check("[CZ] options : la carte montre la touche, Changer et Retirer", card and card.value:GetText() == "Y"
		and card.button and card.clearButton and card.clearButton:IsShown())
	NS:RunOptionAction("bindFeats")
	local cap = NS.bindingCapture
	Check("[CZ] Changer : attente de la touche ; un modificateur seul : on attend", cap and cap:IsShown() and cap.which == "feats"
		and NS:BindingCaptureKey("LSHIFT") == "wait")
	CZ.shift = true
	Check("[CZ] … Maj+H : posé, Y retiré, enregistré", NS:BindingCaptureKey("H") == true and CZ.keys["SHIFT-H"] == "QUESTCOMPANION_FEATS"
		and CZ.keys.Y == nil and CZ.saves >= 1 and not cap:IsShown() and card.value:GetText() == "SHIFT-H")
	CZ.shift = false
	NS:RunOptionAction("bindFeats")
	Check("[CZ] touche déjà prise : confirmation demandée", NS:BindingCaptureKey("K") == "conflict" and cap.replace:IsShown()
		and cap.text:GetText():find("K", 1, true) ~= nil and CZ.keys.K == "TOGGLESPELLBOOK")
	cap.replace:Click()
	Check("[CZ] … Remplacer : posée, l'ancienne retirée", CZ.keys.K == "QUESTCOMPANION_FEATS" and CZ.keys["SHIFT-H"] == nil)
	NS:RunOptionAction("bindFeats")
	Check("[CZ] Échap : annulé", NS:BindingCaptureKey("ESCAPE") == "cancel" and not cap:IsShown() and CZ.keys.K == "QUESTCOMPANION_FEATS")
	card.clearButton:Click()
	Check("[CZ] Retirer : plus de touche, la carte le dit", CZ.keys.K == nil and card.value:GetText() == NS.L.BIND_NONE
		and not card.clearButton:IsShown())
	CZ.combat = true
	Check("[CZ] en combat : Changer refusé", NS:BindingCaptureStart("journal") == false and not cap:IsShown()
		and NS:BindingApply("journal", "J") == false and CZ.keys.J == nil)
	CZ.combat = false
	Check("[CZ] carnet : changer sa touche aussi", NS:BindingCaptureStart("journal") and NS:BindingCaptureKey("J") == true
		and CZ.keys.J == "QUESTCOMPANION_JOURNAL")
	if NS.optionsFrame then NS.optionsFrame:Hide() end
	NS:CharData().featsKeyTried = nil
end

CZ.Done()
