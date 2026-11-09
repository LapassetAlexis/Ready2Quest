-- QuestCompanion 2.8.0 : le carnet et la fiche de dresseur en style Azeroth
-- (JournalAzeroth.lua), le Sobre inchangé, le changement de style à chaud, le
-- repli quand le client refuse une texture ; fiche : choix du titre sous le
-- nom (bouton de fermeture libre), nom sans royaume, bloc des hauts faits,
-- vitrine (sélecteur, protocole aller-retour, compatibilité, validation) ;
-- bulle (ordre de dessin, parchemin visible, aplat dessous) ; bandeau de
-- verdict (tête de la créature, niveau dans le bouclier).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local CZ = { saved = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitFullName", "UnitExists", "UnitIsPlayer", "UnitLevel", "InCombatLockdown",
	"UnitAffectingCombat", "C_Texture", "GetNormalizedRealmName", "GetRealmName", "time" }
for _, name in ipairs(GLOBALS) do CZ.saved[name] = rawget(_G, name) end
local TX = NS.CARNET_TEX
local LAY = NS.CARNET_LAYOUT

local FIELDS = { "journalFrame", "trainerFrame", "companionFrame", "companionBubble", "captureResult" }
function CZ.Reset(style, refused)
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
	NS:CompanionData().tutoDone = true
end
CZ.feat = { dormant = NS.featsDormant, login = NS.featLoginDone }
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
	NS.uiStyleCache = {}
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
local function Has(list, pred) for _, v in ipairs(list or {}) do if pred(v) then return true end end return false end

-- 1. Le carnet en Azeroth : cadre, plaque, colonne ---------------------------------------------------
do
	Say("-- carnet azeroth : cadre, plaque, colonne")
	CZ.Reset()
	local f = Open("evolution")
	local ok, errs = NoErrors()
	Check("[CZ] carnet construit en Azeroth, sans erreur", f and f.azeroth and f.uiStyle == "azeroth" and ok, errs)
	local W = LAY.wood + LAY.nav + LAY.gap + NS.JOURNAL_LAYOUT.width - 2 - NS.JOURNAL_LAYOUT.nav + LAY.wood
	Check("[CZ] la fenêtre grandit du bois et de la bande, la zone des pages garde sa taille",
		f:GetWidth() == W and f:GetHeight() == LAY.band + NS.JOURNAL_LAYOUT.height - 2 + LAY.wood
		and f.content:GetWidth() == NS.JOURNAL_LAYOUT.width - 2 - NS.JOURNAL_LAYOUT.nav, tostring(f:GetWidth()))
	Check("[CZ] cadre en bois : 8 pièces d'atlas", f.azWood and f.azWood.tl.atlas == NS.AZEROTH_WOOD.tl
		and f.azWood.right.atlas == NS.AZEROTH_WOOD.right and f.azOver.level > f.level + 20)
	local plate = f.azPlate
	Check("[CZ] plaque d'en-tête : ui-achievement-header (235402), déborde au-dessus",
		plate and plate.left.texture == TX.headA.file and plate.right.texture == TX.headB.file
		and select(5, plate:GetPoint()) == LAY.plateUp and plate.title:GetText() == NS.L.JRN_TITLE)
	Check("[CZ] case des points de la plaque", plate.box and plate.box.texture == 235402
		and plate.count:GetText() == NS:F("CARNET_AZ_POINTS", (NS:FeatPoints())) and plate.icon.texture == 235415)
	Check("[CZ] parchemins : colonne 130662, pages 130661", f.nav.azBg and f.nav.azBg.texture == 130662
		and f.content.azBg.texture == 130661 and f.nav.bg.mockHidden and f.content.azSurface == "light",
		tostring(f.nav.azSurface) .. " " .. tostring(f.nav.bg.mockHidden))
	Check("[CZ] séparateurs de métal 130658 / 130659", f.azMetalL and f.azMetalL.texture == 130658
		and f.azMetalT and f.azMetalT.texture == 130659)
	local item = f.sections.evolution
	Check("[CZ] catégorie : fond 130652, surbrillance 235400 teintée d'or", item.azBg and item.azBg.texture == 130652
		and item.tint.texture == 235400 and item.tint.blendMode == "ADD" and item.tint:IsShown()
		and item.hover.texture == 235400 and item.bar.alpha == 0)
	Check("[CZ] … la teinte est dorée (rouge > bleu)", item.tint.gradientSpec and item.tint.gradientSpec[2][1] > item.tint.gradientSpec[2][3])
	Check("[CZ] … seule l'entrée choisie s'éclaire", not f.sections.feats.tint:IsShown())
	Check("[CZ] les entrées : sous « CARNET », pas à pas", select(5, item:GetPoint()) == LAY.navTop
		and item:GetWidth() == LAY.nav and f.brand.mockHidden)
	Check("[CZ] garde-manger en bas de la colonne, cadres d'icône", f.azPantry and Has(NS.TREAT_KINDS, function(kind)
		local b = f.pantry[kind]; return b:GetParent() == f.nav and b.azRing and b.azRing.texture == 130656 end))
	Check("[CZ] bouton de fermeture du jeu", f.close.azIcon and f.close.azIcon.texture:find("MinimizeButton") ~= nil
		and f.close.label.mockHidden)
	-- 2.8.2 : titre à l'encre brun-rouge (l'or ombré tombait à 1,7:1 sur le parchemin)
	Check("[CZ] en-tête : titre à l'encre, filigrane", f.header.title.azKeep and f.header.title.textColor[1] == NS.AZEROTH_INK.title[1]
		and f.header.azFiligree and f.header.azFiligree.m.texture == TX.tsuH and f.header.rule.segments[1].mockHidden)
	Check("[CZ] bouton Fermer : rouge, texte doré", f.closeButton.azSkin == "red" and f.closeButton.bg.mockHidden
		and f.closeButton.text.textColor[1] == 1)
end

-- 2. Les pages --------------------------------------------------------------------------------------
do
	Say("-- carnet azeroth : les pages")
	CZ.Reset()
	local f = Open("evolution")
	local evo = f.evo
	Check("[CZ] Compagnon : carte du héros sur le fond des hauts faits (235397), encadré bois (130672)",
		evo.hero.azBg.texture == 235397 and evo.hero.azWoodBorder and evo.hero.azWoodBorder.pieces.t.texture == 130672
		and #evo.hero.azWoodBorder.pieces.t.texCoord == 8)
	Check("[CZ] Compagnon : portrait dans le cadre à volutes", evo.azVine and evo.azVine.atlas == NS.AZEROTH_ATLAS.frameRound)
	Check("[CZ] Compagnon : chiffres sur le fond des catégories, valeur dorée", Has({ "captures", "km" }, function(key)
		local tile = evo.stats[key]; return tile.azBg.texture == 130652 and tile.value.azKeep end))
	local need = evo.needs[1]
	Check("[CZ] Compagnon : envies en barres du jeu (14 px, bordure 235405)", need.bar:GetHeight() == 14
		and need.bar.azEdge and need.bar.fill.texture:find("UI%-StatusBar") ~= nil)
	need.bar.ratio = 0.15; need.bar:SetColor(1, 1, 1)
	Check("[CZ] … envie basse : orange", need.bar.azColor == NS.CARNET_COLORS.orange)
	need.bar.ratio = 0.9; need.bar:SetColor(1, 1, 1)
	Check("[CZ] … envie comblée : verte", need.bar.azColor == NS.CARNET_COLORS.green)
	Check("[CZ] Compagnon : texte brun sur le parchemin", evo.look.textColor[1] < 0.3 and evo.look.textColor[3] < 0.1)
	Check("[CZ] Compagnon : bulle sur le parchemin des hauts faits (2.8.2), voilée", evo.bubble.azBg.texture == 130661
		and evo.bubble.azVeil and evo.bubble.azVeil:IsShown())

	Open("menagerie")
	local men = f.men
	local row = men.items[1]
	Check("[CZ] Créatures : lignes sur le fond des hauts faits", row.azBg and (row.azBg.texture == 235397 or row.azBg.texture == 130660))
	Check("[CZ] Créatures : fiche (barre de nom grise 130667, fond du portrait, encadré bois)", men.preview.azTitle
		and men.preview.azTitle.texture == 130667 and men.preview.stage.texture == 1111217 and men.preview.azWoodBorder)
	Check("[CZ] Créatures : puces d'état sur le fond des catégories, surbrillance de l'état choisi",
		men.states.all.azBg and men.states.all.azBg.texture == 130652 and men.states.all.azHl:IsShown()
		and not men.states.captured.azHl:IsShown())
	men.stateRow:Select("captured")
	Check("[CZ] … autre choix : la surbrillance suit", men.states.captured.azHl:IsShown() and not men.states.all.azHl:IsShown())
	men.stateRow:Select("all")

	Open("feats")
	local hf = f.feats
	Check("[CZ] Hauts faits : catégories sombres, la choisie en or", hf.cats[1].azBg.texture == 130652
		and hf.cats[1].azHl:IsShown() and not hf.cats[2].azHl:IsShown())
	local frow = hf.rows[1]
	Check("[CZ] Hauts faits : barre de nom, cadre d'icône 130656, bouclier", frow.azTitle and frow.azTitle.texture == 130667
		and frow.azRing.texture == 130656 and frow.shield.atlas ~= nil)
	Check("[CZ] Hauts faits : grand bouclier des points (130665)", hf.azShield and hf.azShield.texture == 130665
		and hf.azShieldText:GetText() == tostring((NS:FeatPoints())))
	Check("[CZ] Hauts faits : non obtenu sur parchemin désaturé, barre grise", frow.entry and (frow.entry.got
		and frow.azBg.texture == 235397 or (frow.azBg.texture == 130660 and frow.azTitle.texCoord[3] > 0.3)))

	Open("day")
	local day = f.day
	Check("[CZ] Missions : bandeaux de section (235408), texte doré", day.innTitle.azStrip and day.innTitle.azStrip.texture == 235408
		and day.innTitle.label.azKeep and day.groups.zone.azStrip ~= nil)
	-- 2.9.1 : la carte des auberges en 7 tampons ronds (anneau des hauts faits)
	Check("[CZ] Missions : tampons ronds (anneau des hauts faits)", day.stamps[1].azRing
		and day.stamps[1].azRing.atlas == NS.AZEROTH_ATLAS.frameRound and #day.stamps == 7)
	Check("[CZ] Missions : missions sur le fond des hauts faits", day.missions[1].azBg.texture == 235397)

	Open("progress")
	local prog = f.prog
	Check("[CZ] Exploration : zones sur le fond des catégories", prog.zones[1].azBg.texture == 130652)
	Check("[CZ] Exploration : paliers en bandes or/grises (452109)", prog.marks[1].azBg.texture == 452109)
	Check("[CZ] Exploration : carte de zone encadrée", prog.card.azWoodBorder ~= nil and prog.card.azBg.texture == 235397)

	Open("guide")
	local guide = f.guide
	Check("[CZ] Guide : page sur le parchemin des statistiques (235412)", guide.azPage and guide.azPage.texture == 235412)
	Check("[CZ] Guide : titre doré sur sa bande, filigrane", guide.title.azKeep and guide.azBand and guide.azBand.texture == 235411
		and guide.azFiligree and guide.azFiligree.l.texture == 130670)
	Check("[CZ] Guide : intertitres dorés ombrés", #guide.heads == 0 or guide.heads[1].azKeep)
	Check("[CZ] Guide : sommaire sombre, section choisie en or", guide.rows[1].azHl:IsShown())
	local ok, errs = NoErrors()
	Check("[CZ] toutes les pages sans erreur", ok, errs)
	-- la pagination tient toujours
	NS:ScrollJournal(-1)
	Check("[CZ] molette et pages : toujours là", f.guide:IsShown() and NoErrors())
end

-- 3. Le Sobre inchangé, le changement de style à chaud, le repli --------------------------------------
do
	Say("-- carnet : sobre, à chaud, repli")
	CZ.Reset("sobre")
	local f = Open("feats")
	Check("[CZ] Sobre : aucun habit Azeroth", f and not f.azeroth and f.uiStyle == "sobre" and not f.azPlate
		and f:GetWidth() == NS.JOURNAL_LAYOUT.width and not f.sections.feats.azBg and not f.feats.rows[1].azTitle)
	-- à chaud : le carnet affiché devient Azeroth, la page est gardée
	Mock.InstallAtlas(true)
	NS:AzerothAtlasOK(true)
	NS:SetUIStyle("azeroth")
	local g = NS.journalFrame
	Check("[CZ] /qc style azeroth : le carnet affiché est remplacé, même page", g and g ~= f and g.azeroth and g:IsShown()
		and not f:IsShown() and g.kind == "feats")
	NS:SetUIStyle("sobre")
	Check("[CZ] retour en Sobre : l'ancien carnet revient (gardé, pas reconstruit)", NS.journalFrame == f and f:IsShown()
		and not g:IsShown())
	NS.journalFrame:Hide()
	NS:SetUIStyle("azeroth")
	Check("[CZ] carnet fermé : rien n'est construit avant l'ouverture", NS.journalFrame == nil)
	Check("[CZ] … à l'ouverture, celui du style (gardé)", Open() == g)

	-- repli : textures refusées par le client
	CZ.Reset("azeroth", { [130661] = true, [235402] = true, [130652] = true })
	local h = Open("feats")
	Check("[CZ] repli : page refusée -> fond Sobre, texte clair gardé", h.azeroth and not h.content.azBg
		and h.content.azSurface == nil and not h.content.bg)
	Check("[CZ] repli : plaque refusée -> pas de plaque, marque Sobre gardée", h.azPlate == nil and not h.brand.mockHidden)
	Check("[CZ] repli : catégories refusées -> entrée Sobre, colonne Sobre aussi", h.sections.feats.azBg == nil
		and h.sections.feats.tint.texture ~= 235400 and h.nav.azSurface == nil and not h.nav.bg.mockHidden)
	Check("[CZ] repli : le texte sur fond Sobre reste clair", h.feats.totals.textColor[1] > 0.8)
	Check("[CZ] repli : les fichiers refusés sont notés", NS.carnetMissing[130661] and NS.carnetMissing[235402])
	local ok, errs = NoErrors()
	Check("[CZ] repli : sans erreur", ok, errs)
end

-- 4. Fiche de dresseur ------------------------------------------------------------------------------
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
	for _, style in ipairs({ "sobre", "azeroth" }) do
		local men = CZ.Trainer(style)
		local f = NS:TrainerOpen(nil)
		local tag = "[CZ] fiche " .. style .. " : "
		Check(tag .. "nom sans « -Royaume » (royaume illisible : celui du joueur)", NS:TrainerShortName("Dyokrion-Aeternalis") == "Dyokrion"
			and f.header.title.text:find("Aeternalis", 1, true) == nil and f.header.title.text:find("Dyokrion", 1, true) ~= nil,
			tostring(f.header.title.text))
		Check(tag .. "un autre royaume garde son suffixe", NS:TrainerShortName("Bob-Hyjal") == "Bob-Hyjal")
		-- le choix du titre sous le nom, loin du bouton de fermeture
		local picker, close = f.titlePicker, f.close
		local p = picker.points[1]
		local L2 = NS.TRAINER_LAYOUT
		local right = (p.x or 0) + picker:GetWidth()
		Check(tag .. "« Titre affiché : » puis le choix, sous l'en-tête", f.titleLabel:IsShown() and picker:IsShown()
			and f.titleLabel:GetText() == NS.L.TRAINER_TITLE_SHOWN and p.relTo == f.content and p.point == "TOPLEFT"
			and p.y == L2.titleY and select(2, f.titleLabel:GetPoint()) == f.content)
		Check(tag .. "le bouton de fermeture reste libre", right < L2.width - 60 and p.y < -60
			and select(1, close:GetPoint()) == "TOPRIGHT", tostring(right) .. " " .. tostring(p.y))
		-- bloc des hauts faits
		local show = NS:TrainerFeatShowcase()
		Check(tag .. "vitrine par défaut : les 3 plus récents", #show == 3 and show[1].def == men[5] and show[3].def == men[3])
		Check(tag .. "cartes : nom, date, points", f.featCards[1].name:GetText() == NS:FeatName(men[5])
			and f.featCards[1].date:GetText() ~= "" and f.featCards[1].pts:GetText() == tostring(men[5].pts or 0))
		Check(tag .. "détail : obtenus et points", f.featsSection.detail:GetText():find("5", 1, true) ~= nil)
		Check(tag .. "quatre mini-barres de catégories", #f.featBars == 4 and f.featBars[1].count:GetText():find("^5/") ~= nil
			and f.featBars[1].bar:IsShown())
		Check(tag .. "sélecteur « Vitrine : les plus récents »", f.featsPicker:IsShown() and f.featsPicker:GetValue() == "auto")
		f.featsPicker:Choose(men[1].id)
		show = NS:TrainerFeatShowcase()
		Check(tag .. "épingler un haut fait : il passe en tête", show[1].def == men[1] and show[2].def == men[5]
			and f.featsPicker:GetValue() == "picked" and f.featCards[1].name:GetText() == NS:FeatName(men[1]))
		f.featsPicker:Choose(men[1].id)
		Check(tag .. "le reprendre : retiré", NS:TrainerFeatShowcase()[1].def == men[5] and #NS:TrainerFeatPins() == 0)
		f.featsPicker:Choose(men[2].id); f.featsPicker:Choose("auto")
		Check(tag .. "« les plus récents » : plus d'épingle", #NS:TrainerFeatPins() == 0)
		Check(tag .. "portrait de 206 px", f.stage:GetWidth() >= 200)
		if style == "azeroth" then
			Check(tag .. "cadre Azeroth, plaque « Fiche de dresseur », points", f.azeroth and f.azPlate
				and f.azPlate.title:GetText() == NS.L.TRAINER_TITLE and f.azPlate.count:GetText() ~= "")
			Check(tag .. "portrait dans le cadre à volutes, fond des Talking Heads", f.azVine.atlas == NS.AZEROTH_ATLAS.frameRound
				and f.stage.azBg.texture == 1111217)
			Check(tag .. "vitrine : cadres d'icône et petits boucliers", f.featCards[1].azRing.texture == 130656
				and f.featCards[1].mark.texture == 235415)
			Check(tag .. "chiffres sur les bandes des statistiques", f.azBands[1] and f.azBands[1].texture == 235411)
			Check(tag .. "mini-barres vertes du jeu", f.featBars[1].bar.azColor == NS.CARNET_COLORS.green)
			local ok, errs = NoErrors()
			Check(tag .. "sans erreur", ok, errs)
		else
			Check(tag .. "pas d'habit Azeroth", not f.azeroth and not f.azPlate and not f.featCards[1].azRing)
		end
		f:Hide()
	end

	Say("-- fiche de dresseur : vitrine dans le protocole")
	local men = CZ.Trainer("sobre")
	local text = NS:TrainerSerializeCard(NS:TrainerOwnCard())
	local fields = NS.TrainerDecode(text)
	Check("[CZ] protocole : champ hf (codes n, dates), champ hk", fields.hf ~= nil and fields.hk ~= nil
		and NS.TrainerUnescape(fields.hf):find(tostring(men[5].n) .. ":1700000500", 1, true) == 1, tostring(fields.hf))
	local card = NS:TrainerParseCard(text)
	Check("[CZ] protocole : aller-retour", #card.featShowcase == 3 and card.featShowcase[1].n == men[5].n
		and card.featShowcase[1].at == 1700000500 and card.featShowcase[1].def == men[5] and card.featCats.men == 5)
	Check("[CZ] protocole : version inchangée", fields.p == "1")
	local old = NS:TrainerParseCard("p=1;n=Bob-Hyjal;sp=3")
	Check("[CZ] protocole : fiche d'avant (sans hf) lue, vitrine vide", old.species == 3 and #old.featShowcase == 0
		and old.featCats == nil)
	local enc = NS.TrainerEncode({ p = 1, n = "Bob", hf = { "abc", "99999", "9998", tostring(men[1].n), tostring(men[1].n) .. ":12",
		tostring(men[2].n) .. ":12345678901", tostring(men[3].n), tostring(men[4].n), "-1" }, hk = { "men:999", "zz:3", "shiny:x" } })
	local bad = NS:TrainerParseCard(enc)
	local got = {}
	for _, item in ipairs(bad.featShowcase) do got[#got + 1] = tostring(item.n) .. ":" .. tostring(item.at) end
	Check("[CZ] protocole : codes mal formés, inconnus, en double écartés ; 3 au plus",
		#bad.featShowcase == 3 and bad.featShowcase[1].n == men[1].n and bad.featShowcase[2].n == men[3].n
		and bad.featShowcase[3].n == men[4].n and bad.featShowcase[2].at == nil, table.concat(got, ",") .. " / " .. tostring(men[1].n))
	local _, total = NS:FeatCategoryStats("men")
	Check("[CZ] protocole : catégories inconnues écartées, nombre borné au total", bad.featCats and bad.featCats.men == total
		and bad.featCats.zz == nil and bad.featCats.shiny == nil)
	-- la fiche d'un autre joueur affiche sa vitrine
	local f = NS:TrainerOpen(nil)
	NS.trainerState.cards[NS:TrainerKey("Bob-Hyjal")] = { card = card, at = NS.Now and NS.Now() or 0 }
	card.sender = "Bob-Hyjal"
	NS:TrainerOpen("Bob-Hyjal")
	Check("[CZ] fiche reçue : vitrine et mini-barres de l'autre, pas de sélecteur", f.featCards[1].name:GetText() == NS:FeatName(men[5])
		and not f.featsPicker:IsShown() and f.featBars[1].count:GetText():find("^5/") ~= nil)
	f:Hide()
end

-- 5. La bulle : parchemin visible, aplat dessous ------------------------------------------------------
do
	Say("-- bulle azeroth : ordre de dessin")
	CZ.Reset()
	NS:CompanionUpdateVisibility()
	NS:EnsureCompanionFrame()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	NS:CompanionSay("EAT", { force = true })
	local bubble = NS.companionBubble
	local skin = bubble and bubble.azTalk
	Check("[CZ] bulle : parchemin par son fichier (130661), recadré, opaque", skin and skin.bg.texture == 130661
		and skin.bg.texCoord[2] > 0.5 and skin.bg:IsShown() and skin.bg.vertex[4] == 1)
	Check("[CZ] bulle : aplat parchemin clair sous le parchemin", skin.backdrop:IsShown() and skin.backdrop.drawLayer == "BACKGROUND"
		and skin.bg.drawLayer == "BACKGROUND" and skin.backdrop.subLevel < skin.bg.subLevel and skin.backdrop.vertex[1] > 0.85)
	Check("[CZ] bulle : texte au-dessus, habit Sobre masqué", skin.text.drawLayer == "OVERLAY" and bubble.bg.mockHidden
		and bubble.rule.mockHidden)
	CZ.Reset(nil, { [130661] = true })
	NS:CompanionUpdateVisibility()
	NS:EnsureCompanionFrame()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	NS:CompanionSay("EAT", { force = true })
	skin = NS.companionBubble and NS.companionBubble.azTalk
	Check("[CZ] bulle : fichier refusé -> l'aplat clair seul, texte lisible", skin and skin.bg.azFailed and not skin.bg:IsShown()
		and skin.backdrop:IsShown() and skin.text.textColor[1] < 0.3)
end

-- 6. Le bandeau de verdict : tête de la créature, niveau --------------------------------------------
do
	Say("-- verdict azeroth : portrait et niveau")
	CZ.Reset()
	local banner = NS:AzerothVerdict(UIParent, 330, 107)
	-- 2.9.0 : portrait fixe (icône du type), plus de modèle 3D
	Check("[CZ] verdict : cadre d'icône à gauche (au-dessus du portrait)", banner.iconFrame and banner.iconFrame.atlas == NS.AZEROTH_ATLAS.frame
		and banner.portraitRing.level > (banner.GetFrameLevel and banner:GetFrameLevel() or 0))
	banner:SetShield("gold")
	banner:SetCreature({ npcID = 7001, type = "Bête", level = 12 })
	Check("[CZ] verdict : l'icône du type", not banner.portraitShown and banner.portraitIcon:IsShown()
		and banner.portraitIcon.texture == NS.MENAGERIE_TYPE_ICONS["Bête"])
	banner:SetCreature({ npcID = 7001, type = "Inconnu" })
	Check("[CZ] verdict : type inconnu -> icône de repli", banner.portraitIcon.texture == NS.AZEROTH_PORTRAIT_ICON)
	banner:SetCreature(nil)
	Check("[CZ] verdict : sans créature, cadre vide", not banner.portraitIcon:IsShown())
	banner:SetLevel(12)
	Check("[CZ] verdict : le niveau dans le bouclier", banner.levelText:GetText() == "12" and banner.levelText:IsShown()
		and select(2, banner.levelText:GetPoint()) == banner.shield)
	banner:SetShield(nil); banner:SetLevel(12)
	Check("[CZ] verdict : sans bouclier, pas de niveau", not banner.levelText:IsShown())
	-- le bandeau « Capturé ! »
	local toast = NS:CaptureResultShow({ name = "Kodo", stars = 2, npcID = 7002, level = 18, type = "Bête" })
	Check("[CZ] « Capturé ! » : tête de la créature dans le cadre, niveau 18 dans le bouclier", toast and toast.azeroth
		and toast.banner.portraitRing:IsShown() and toast.banner.levelText:GetText() == "18" and toast.iconFrame.mockHidden)
	NS:CaptureResultHide()
end

-- 7. Raccourcis : Y pour les hauts faits, options -----------------------------------------------------
CZ.bindSaved = {}
for _, name in ipairs({ "GetBindingAction", "SetBinding", "SaveBindings", "GetCurrentBindingSet", "GetBindingKey",
	"IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown" }) do CZ.bindSaved[name] = rawget(_G, name) end
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
	Check("[CZ] en combat : reporté", NS:BindingDefaultTry() == "combat" and CZ.keys.Y == nil and not NS:CharData().featsKeyTried)
	CZ.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Check("[CZ] … à la fin du combat : posé", CZ.keys.Y == "QUESTCOMPANION_FEATS" and NS:CharData().featsKeyTried)

	Say("-- raccourcis : bascule des hauts faits")
	local f = QuestCompanion_ToggleFeats()
	f = NS.journalFrame
	Check("[CZ] la touche ouvre le carnet sur les hauts faits", f and f:IsShown() and f.kind == "feats")
	QuestCompanion_ToggleFeats()
	Check("[CZ] … encore : fermé", not f:IsShown())
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
	Check("[CZ] Changer : attente de la touche", cap and cap:IsShown() and cap.which == "feats")
	Check("[CZ] … un modificateur seul : on attend", NS:BindingCaptureKey("LSHIFT") == "wait")
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
	for name, fn in pairs(CZ.bindSaved) do _G[name] = fn end
	NS:CharData().featsKeyTried = nil
end

CZ.Done()
