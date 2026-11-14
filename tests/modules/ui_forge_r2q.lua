-- Thème forgé (Azeroth) des fenêtres et bandeaux de Ready2Quest : les blocs
-- faits à la main par les modules (bloc note et conseils d'« Avant le
-- départ », durée du bilan, options et verdict après la mort, titres et
-- niveau d'« Avant le donjon », cartes de « Place au butin » et des rangs de
-- sorts, bandeaux sac plein et camp, tuile d'annonce, résumé de stuff,
-- portrait, étiquette de la récompense). En Sobre, rien de tout cela n'est
-- créé : les aplats d'avant restent. Contrastes mesurés sur le vrai fond
-- (plaque teintée à son point le plus clair et le plus sombre, creux, halo).
local Check, Say, NS, Mock, ResetWorld = T.Check, T.Say, T.NS, T.Mock, T.ResetWorld
local Theme = NS.Theme
local SKIN0 = Theme.skin
local F = NS.FORGE

-- plusieurs étapes d'un même sujet : un contrôle, les étapes ratées nommées
local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end
local function Same(a, b)
	return a and b and math.abs(a[1] - b[1]) < 1e-6 and math.abs(a[2] - b[2]) < 1e-6 and math.abs(a[3] - b[3]) < 1e-6
end
local function Count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
-- visible : montrée, ou jamais cachée (la maquette part de « non montrée »)
local function Shown(region) return region ~= nil and not region.mockHidden end
local function SliceShown(slice) return slice ~= nil and slice.shown == true and not slice.parts.tl.mockHidden end
-- une découpe de la matière `art`, teinte `color`
local function IsSlice(slice, art, color)
	return slice ~= nil and Count(slice.parts) >= 8 and slice.parts.tl.texture == Theme.ART[art].file
		and (color == nil or Same(slice.color, color))
end
-- couleurs vues : plaque teintée (luminance de la texture), creux, voile
local function Plate(tint, level) return { tint[1] * level, tint[2] * level, tint[3] * level } end
local function PlateTop(tint) return Plate(tint, F.plate.top) end
local function PlateBottom(tint) return Plate(tint, F.plate.bottom) end
local function WellFill(rim) return Plate(rim, F.inset.fill) end
local BLACK = { 0, 0, 0 }
-- pire contraste d'une encre sur une liste de fonds
local function Worst(ink, backgrounds)
	local worst = math.huge
	for _, bg in ipairs(backgrounds) do worst = math.min(worst, Theme.Contrast(ink, bg)) end
	return worst
end

local function Fresh(skin)
	ResetWorld()
	Theme.ApplySkin(skin)
	NS:DB().popupScore = 100
	for _, field in ipairs({ "window", "expeditionFrame", "dungeonFrame", "deathFrame", "lootRoomFrame", "spellRanksFrame",
		"bagspaceFrame", "campFrame", "noticeFrame", "toastFrame", "portraitFrame" }) do
		if NS[field] and NS[field].Hide then NS[field]:Hide() end
		NS[field] = nil
	end
end
local function DiagWindow()
	Mock.world.durability = { [5] = { 18, 100 } }
	NS:RunChecklist("manual")
	NS:ShowWindow(NS.lastResults)
	return NS.window
end
local SHEET = {
	name = "Les Mortemines", verdict = "ok", min = 17, max = 26, level = 21,
	quests = { { title = "Edwin VanCleef", ready = false } }, blueprints = {},
	readiness = { { label = "Vivres", detail = "0", ok = false } },
}
local function LootRows()
	NS.LootRoomLoot = function() return { { link = "[Cuir]", count = 1, value = 1250 } } end
	NS.LootRoomRows = function() return { { itemID = 1, link = "[Os]", count = 1, vendor = 5 } } end
end

-- ---------------------------------------------------------------------------
do
	Say("-- forge R2Q : la cause du « Avant le départ » sans habillage")
	-- l'aperçu r2q-check construisait la fenêtre sans ADDON_LOADED : le thème
	-- n'était jamais posé (Theme.skin restait à « sobre », sa valeur au
	-- chargement du fichier). En jeu, le chargeur du socle le pose avant
	-- toute fenêtre ; construite après, la fenêtre est habillée.
	Fresh("sobre")
	NS.loaderFrame:GetScript("OnEvent")(NS.loaderFrame, "ADDON_LOADED", "Ready2Quest")
	local frame = DiagWindow()
	local chrome = frame.skinChrome
	Check("[FORGE-R2Q] Avant le départ, construite après le chargement : Azeroth, cadre, médaillon, plus de petit logo",
		Theme.skin == "azeroth" and frame.skinDressed == true and chrome ~= nil and chrome.emblem ~= nil
		and frame.header.logo == nil and frame.header.textLeft == Theme.EMBLEM.text)
end

-- ---------------------------------------------------------------------------
do
	Say("-- forge R2Q : Sobre ne change pas")
	Fresh("sobre")
	local s = Steps()
	s.ok("ForgeOn faux", NS.ForgeOn() == false)
	s.ok("aucune matière créée hors thème forgé", NS.ForgeCard(UIParent) == nil and NS.ForgeWell(UIParent) == nil
		and NS.ForgeLine(UIParent) == nil and NS.ForgeDot(UIParent) == nil and NS.ForgeSheen(CreateFrame("Frame")) == nil
		and NS.ForgeAccentBar(UIParent, UIParent:CreateTexture()) == nil)
	s.ok("style de bouton de Sobre", NS.ForgeStyle("primary", "danger") == "primary")
	local frame = DiagWindow()
	s.ok("bloc note : aplat et filet, pas de plaque", frame.scoreCard.plate == nil and Shown(frame.scoreCard.bg)
		and Shown(frame.scoreCard.border.top) and frame.forged == nil)
	s.ok("tampon : aplat et filet, pas de creux", frame.stamp.well == nil and Shown(frame.stamp.fill) and Shown(frame.stamp.border.top))
	s.ok("barre : fond plat, couleur ambre", frame.scoreBar.well == nil and Shown(frame.scoreBar.bg)
		and frame.scoreBar.fill.gradientSpec == nil and Same(frame.scoreBar.fill.vertex, Theme.GOLD))
	s.ok("chiffre en parchemin", Same({ frame.scoreValue:GetTextColor() }, Theme.PARCHMENT))
	s.ok("conseils : aplat, liseré de 2", frame.adviceBlock.plate == nil and Shown(frame.adviceBlock.bg)
		and frame.adviceBlock.bar:GetWidth() == 2 and frame.adviceBullets[1].glow == nil)
	NS:ShowExpeditionReport({ duration = 60, xp = 0, levels = 0, earned = 0, spent = 0, net = 0, loot = {}, deaths = 0,
		duraLost = 0, durability = 100, quests = 0, newQuests = 0, restock = {} })
	s.ok("bilan : durée sur aplat", NS.expeditionFrame.hero.plate == nil and Shown(NS.expeditionFrame.hero.bg))
	NS:ShowDeathPanel({ ghost = true, level = 22, distance = 175, runTime = 20, sickness = 600, points = 50, cost = 25000, verdict = "run" })
	s.ok("mort : lignes sans plaque ni creux", NS.deathFrame.lines[1].forgePlate == nil and NS.deathFrame.lines[3].forgeWell == nil
		and Shown(NS.deathFrame.lines[1].bg))
	NS:ShowDungeonWindow(SHEET)
	s.ok("donjon : titres sans point ni filet, niveau sur aplat", NS.dungeonFrame.lines[2].forgeDot == nil
		and NS.dungeonFrame.lines[1].forgeWell == nil and Shown(NS.dungeonFrame.lines[1].bg))
	local camp = NS:EnsureCampFrame()
	s.ok("camp : 28 de haut, pas d'habillage, pas de braise", camp:GetHeight() == 28 and camp.skinChrome == nil and camp.ember == nil)
	NS:ShowNotice(NS:NoticeDepart(92, "PRÊT"))
	s.ok("annonce : tuile plate et filet", NS.noticeFrame.plate == nil and Shown(NS.noticeFrame.tile)
		and Shown(NS.noticeFrame.border.top) and NS.noticeFrame.accentGlow == nil)
	NS:SimulateGearToast()
	s.ok("résumé : filet d'1 px, pas d'habillage maison", NS.toastFrame.forgeFrame == nil and Shown(NS.toastFrame.border.top)
		and Shown(NS.toastFrame.rule) and NS.toastFrame.skinNoChrome == nil)
	NS.bagspace = { index = 1, list = { { link = "[Os]", count = 1, value = 5, bag = 0, slot = 4, itemID = 1 } } }
	local bag = NS:ShowBagSpaceFrame()
	s.ok("sac plein : « Jeter » ambre, liseré sans halo", bag.destroyButton.style == "primary" and bag.keepButton.style == "outline"
		and bag.accentHalo == nil)
	s.check("[FORGE-R2Q] Sobre : mêmes aplats, filets, tailles et couleurs qu'avant, aucune texture du thème forgé")
end

-- ---------------------------------------------------------------------------
do
	Say("-- forge R2Q : Avant le départ")
	Fresh("azeroth")
	local frame = DiagWindow()
	local card = frame.scoreCard
	Check("[FORGE-R2Q] bloc note : plaque en relief teinte « carte », aplat et filet cachés",
		IsSlice(card.plate, "plate", F.card) and not Shown(card.bg) and not Shown(card.border.top))
	Check("[FORGE-R2Q] chiffre de la note en or clair, sur un halo d'or centré sur lui",
		Same({ frame.scoreValue:GetTextColor() }, Theme.TITLE) and frame.scoreGlow ~= nil
		and frame.scoreGlow.texture == Theme.ART.dot.file and select(2, frame.scoreGlow:GetPoint(1)) == frame.scoreValue)
	local _, _, _, fillAlpha = frame.stamp.fill:GetVertexColor()
	local c = Theme.ScoreColor((NS.score or 0) / 100)
	Check("[FORGE-R2Q] tampon du verdict : un creux dont le filet prend la couleur du verdict",
		IsSlice(frame.stamp.well, "inset", c) and not Shown(frame.stamp.fill) and not Shown(frame.stamp.border.top), fillAlpha)
	local bar = frame.scoreBar
	local spec = bar.fill.gradientSpec
	Check("[FORGE-R2Q] barre de la note : dans un creux qui la déborde, dégradé d'or (sombre en bas, clair en haut)",
		IsSlice(bar.well, "inset", Theme.EDGE) and bar.well.out == F.well.out and not Shown(bar.bg)
		and spec and spec[1] == "VERTICAL" and spec[2] == Theme.GOLD_SOFT and spec[4] == Theme.GOLD_LIGHT)
	local before = { bar.fill.vertex[1], bar.fill.vertex[2], bar.fill.vertex[3] }
	NS:ShowWindow(NS.lastResults)
	Check("[FORGE-R2Q] le dégradé reste à chaque affichage (plus de couleur unie par-dessus)",
		bar.fill.gradientSpec == spec and Same(bar.fill.vertex, before) and not Same(bar.fill.vertex, Theme.GOLD))
	bar:SetValue(0)
	local off = not Shown(bar.ember)
	bar:SetValue(0.5)
	Check("[FORGE-R2Q] une braise au bout de la barre, éteinte à zéro", off and Shown(bar.ember)
		and select(2, bar.ember:GetPoint(1)) == bar.fill)
	local block = frame.adviceBlock
	Check("[FORGE-R2Q] conseils : plaque, liseré lumineux élargi et son halo, aplat caché",
		IsSlice(block.plate, "plate", F.card) and not Shown(block.bg) and block.bar:GetWidth() == F.bar.width
		and block.bar.gradientSpec ~= nil and block.halo ~= nil and block.halo.gradientSpec[3] == F.bar.haloAlpha)
	local s = Steps()
	for index, bullet in ipairs(frame.adviceBullets) do
		s.ok("puce " .. index, bullet.glow ~= nil and Shown(bullet.glow) == Shown(bullet))
	end
	NS.lastAdvice = {}
	NS:ShowWindow(NS.lastResults)
	s.ok("sans conseil : une seule lueur", Shown(frame.adviceBullets[1].glow) and not Shown(frame.adviceBullets[2].glow))
	s.check("[FORGE-R2Q] chaque puce des conseils sur un point lumineux, qui suit sa puce")
end

-- ---------------------------------------------------------------------------
do
	Say("-- forge R2Q : bilan, mort, donjon")
	Fresh("azeroth")
	local report = NS:ShowExpeditionReport({ duration = 754, xp = 950, levels = 1, earned = 50000, spent = 20000, net = 30000,
		loot = {}, deaths = 0, duraLost = 0, durability = 100, quests = 0, newQuests = 0, restock = {} })
	Check("[FORGE-R2Q] bilan : la durée sur une plaque, en or clair sur un halo",
		IsSlice(report.hero.plate, "plate", F.card) and not Shown(report.hero.bg)
		and Same({ report.duration:GetTextColor() }, Theme.TITLE) and report.durationGlow ~= nil)

	NS:ShowDeathPanel({ ghost = true, level = 22, distance = 175, runTime = 20, sickness = 600, points = 50, cost = 25000, verdict = "run" })
	local lines = NS.deathFrame.lines
	local s = Steps()
	s.ok("options en plaques", SliceShown(lines[1].forgePlate) and SliceShown(lines[2].forgePlate) and not Shown(lines[1].bg))
	s.ok("verdict « cours » : creux à filet vert", SliceShown(lines[3].forgeWell) and Same(lines[3].forgeWell.color, Theme.GREEN)
		and lines[3].forgePlate == nil)
	s.ok("notes pâles à nu", lines[4].forgePlate == nil and lines[4].forgeWell == nil and lines[4].forgeKind == "note")
	NS:ShowDeathPanel({ ghost = true, level = 22, distance = 900, runTime = 200, sickness = 60, points = 50, cost = 25000, verdict = "healer" })
	s.ok("verdict « guérisseur » : filet or", Same(lines[3].forgeWell.color, Theme.GOLD))
	s.check("[FORGE-R2Q] après la mort : options en plaques, verdict dans un creux qui dit son sens, notes à nu")

	NS:ShowDungeonWindow(SHEET)
	local dl = NS.dungeonFrame.lines
	s = Steps()
	s.ok("niveau dans un creux vert (c'est ton niveau)", SliceShown(dl[1].forgeWell) and Same(dl[1].forgeWell.color, Theme.GREEN)
		and not Shown(dl[1].bg))
	s.ok("titre : point et filet lumineux, encre or clair", Shown(dl[2].forgeDot) and Shown(dl[2].forgeRule)
		and dl[2].forgeRule.texture == Theme.ART.line.file and Same({ dl[2].text:GetTextColor() }, Theme.TITLE))
	s.ok("le filet commence après le texte", (select(4, dl[2].forgeRule:GetPoint(1)) or 0)
		> NS.DGN_FORGE.textLeft + Theme.TextWidth(NS.dungeonFrame, dl[2].text:GetText(), Theme.F_CAPS))
	s.ok("une ligne ordinaire n'a ni point ni creux", dl[3].forgeDot == nil and dl[3].forgeWell == nil)
	local low = {}
	for k, v in pairs(SHEET) do low[k] = v end
	low.verdict, low.level = "low", 12
	NS:ShowDungeonWindow(low)
	s.ok("trop bas : filet rouge", Same(dl[1].forgeWell.color, Theme.RED))
	s.check("[FORGE-R2Q] avant le donjon : titres en or à point et filet lumineux, niveau dans un creux à la couleur du verdict")
end

-- ---------------------------------------------------------------------------
do
	Say("-- forge R2Q : listes en cartes, boutons qui portent le sens")
	Fresh("azeroth")
	LootRows()
	local loot = NS:LootRoomOpen(true)
	local row = loot.rows[1]
	Check("[FORGE-R2Q] place au butin : carte du butin en plaque à liseré lumineux",
		IsSlice(loot.targetCard.plate, "plate", F.card) and not Shown(loot.targetCard.bg) and loot.targetCard.halo ~= nil)
	local sheen = row.forgeSheen
	Check("[FORGE-R2Q] lignes en carte : un seul dégradé de la plaque et un reflet d'1 px (pas 9 pièces par ligne)",
		sheen ~= nil and sheen.gradientSpec ~= nil and sheen.gradientSpec[1] == "VERTICAL"
		and Same(sheen.gradientSpec[4], PlateTop(F.card)) and Same(sheen.gradientSpec[2], PlateBottom(F.card))
		and sheen.highlight:GetHeight() == 1 and not Shown(row.bg) and row.plate == nil)
	Check("[FORGE-R2Q] le survol de la ligne passe au-dessus de sa carte", row.hover.drawLayer == "BORDER")
	Check("[FORGE-R2Q] sans style « danger » au socle, « Jeter » garde son style d'avant", row.delete.style == "primary")
	NS.spellRanksFrame = nil
	local list = { { name = "Lumière sacrée", rank = 3, bestRank = 5, bar = 1, case = 4, bestID = 1 } }
	NS.SpellRankScan = function() return list end
	local ranks = NS:SpellRanksOpen()
	Check("[FORGE-R2Q] rangs de sorts : cartes en dégradé, rangs et nouveaux sorts", ranks.rows[1].forgeSheen ~= nil
		and ranks.newRows[1].forgeSheen ~= nil and not Shown(ranks.rows[1].bg))
	-- un socle qui connaît les styles de sens : chaque geste prend le sien
	local styles = Theme.BUTTON_STYLES
	local saved = { danger = styles.danger, add = styles.add, arcane = styles.arcane }
	styles.danger, styles.add, styles.arcane = styles.primary, styles.primary, styles.primary
	local s = Steps()
	s.ok("ForgeStyle : premier style connu", NS.ForgeStyle("primary", "remove", "danger") == "danger"
		and NS.ForgeStyle("outline", "inconnu") == "outline")
	NS.bagspace = { index = 1, list = { { link = "[Os]", count = 1, value = 5, bag = 0, slot = 4, itemID = 1 } } }
	NS.bagspaceFrame = nil
	local bag = NS:ShowBagSpaceFrame()
	s.ok("sac plein : Jeter rouge, Favori vert, Autre neutre", bag.destroyButton.style == "danger"
		and bag.keepButton.style == "add" and bag.nextButton.style == "outline")
	NS.lootRoomFrame = nil
	loot = NS:LootRoomOpen(true)
	s.ok("butin : Jeter rouge", loot.rows[1].delete.style == "danger")
	NS.spellRanksFrame = nil
	ranks = NS:SpellRanksOpen()
	s.ok("rangs : Mettre à jour en arcane, Placer en vert", ranks.rows[1].update.style == "arcane"
		and ranks.newRows[1].place.style == "add")
	styles.danger, styles.add, styles.arcane = saved.danger, saved.add, saved.arcane
	s.check("[FORGE-R2Q] la couleur dit le geste (rouge détruire, vert ajouter, arcane action neutre) quand le socle a ces styles")
	if NS.lootRoomFrame then NS.lootRoomFrame:Hide() end
	if NS.spellRanksFrame then NS.spellRanksFrame:Hide() end
end

-- ---------------------------------------------------------------------------
do
	Say("-- forge R2Q : bandeaux, tuile, résumé, portrait, récompense")
	Fresh("azeroth")
	NS.bagspace = { index = 1, list = { { link = "[Os]", count = 1, value = 5, bag = 0, slot = 4, itemID = 1 } } }
	local bag = NS:ShowBagSpaceFrame()
	Check("[FORGE-R2Q] sac plein : habillage de bandeau (ombre, cadre ; ni coins ni médaillon), liseré orange en lumière",
		bag.skinDressed == true and bag.skinChrome.corners == nil and bag.skinChrome.emblem == nil
		and bag.accentHalo ~= nil and bag.accent:GetWidth() == F.bar.width)

	local camp = NS:EnsureCampFrame()
	camp:Show()
	Check("[FORGE-R2Q] camp : le bandeau prend la hauteur de l'habillage et le reçoit, braise derrière le feu",
		camp:GetHeight() == Theme.CHROME.min and camp.skinDressed == true and camp.skinChrome.frame ~= nil
		and camp.skinChrome.emblem == nil and camp.ember ~= nil and select(2, camp.ember:GetPoint(1)) == camp.icon)
	camp:Hide()

	NS:ShowNotice(NS:NoticeReturn({ deaths = 1, durability = 40, restock = {} }))
	local tile = NS.noticeFrame
	local color = NS.notice.color
	Check("[FORGE-R2Q] annonce : tuile en plaque (bouton neutre), filet du bas en lumière de la couleur du rapport",
		IsSlice(tile.plate, "plate", F.neutral) and not Shown(tile.tile) and not Shown(tile.border.top)
		and tile.accentGlow ~= nil and Same(tile.accentGlow.vertex, color))
	NS:HideNotice()

	NS:SimulateGearToast()
	local toast = NS.toastFrame
	local around = select(2, toast.forgeFrame.parts.tl:GetPoint(1))
	Check("[FORGE-R2Q] résumé de stuff : ombre et cadre d'orfèvre autour de son fond (le cadre de 10 px ne les portait pas)",
		IsSlice(toast.forgeShadow, "shadow") and IsSlice(toast.forgeFrame, "frame") and around == toast.bg
		and toast.forgeFrame.parts.c == nil and toast.skinNoChrome == true and not Shown(toast.border.top))
	Theme.DressWindow(toast)
	Check("[FORGE-R2Q] résumé : le socle ne l'habille pas en double, son filet reste caché",
		toast.skinChrome == nil and not Shown(toast.border.top) and toast.ruleGlow ~= nil and not Shown(toast.rule))
	toast:Hide()

	NS.forceStats = true
	NS:ShowPortraitStats()
	NS.forceStats = nil
	Check("[FORGE-R2Q] portrait : bandeau habillé, filet sous la classe en lumière",
		NS.portraitFrame.skinDressed == true and NS.portraitFrame.ruleGlow ~= nil and not Shown(NS.portraitFrame.rule)
		and NS.portraitFrame.ruleGlow.texture == Theme.ART.line.file)
	NS.portraitFrame:Hide()
end

do
	Say("-- forge R2Q : étiquette de la récompense")
	Fresh("azeroth")
	local holder = CreateFrame("Frame", nil, UIParent)
	local button = CreateFrame("Button", "R2QForgeRewardButton", holder)
	button:SetSize(147, 41)
	NS.RewardMarkButton(button, "Pour toi")
	local mark = button.r2qRewardMark
	local labelWidth = tonumber(mark.label:GetStringWidth()) or 0
	local shown = SliceShown(mark.well)
	NS:RewardClearMarks()
	Check("[FORGE-R2Q] récompense : étiquette dans un creux à filet d'or, à la largeur du libellé, sous le texte, ôtée avec la marque",
		IsSlice(mark.well, "inset", Theme.GOLD) and shown and not SliceShown(mark.well)
		and mark.tag:GetWidth() == labelWidth + 2 * F.tag.padX and mark.glow.gradientSpec ~= nil
		and mark.well.parts.c.drawLayer == "OVERLAY" and (mark.well.parts.c.subLevel or 0) < (mark.label.subLevel or 0))
	holder:Hide()
end

-- ---------------------------------------------------------------------------
do
	Say("-- forge R2Q : contrastes sur les vrais fonds")
	Theme.ApplySkin("azeroth")
	local card = F.card
	local cardBgs = { PlateTop(card), PlateBottom(card) }
	local s = Steps()
	local function Pair(label, ink, backgrounds, min)
		local worst = Worst(ink, backgrounds)
		s.ok(label .. string.format(" %.2f", worst), worst >= min)
	end
	-- bloc note : le chiffre (grand, seuil des titres) sur la plaque et sur le cœur du halo
	Pair("note / plaque + halo", Theme.TITLE,
		{ PlateTop(card), PlateBottom(card), Theme.Over(PlateTop(card), Theme.GOLD, F.glow.alpha) }, 3)
	Pair("« / 100 » / plaque", Theme.MUTED, cardBgs, 4.5)
	-- le verdict, chacune de ses couleurs, dans un creux à filet de sa couleur
	for _, ratio in ipairs({ 0, 0.3, 0.6, 0.9 }) do
		local c = Theme.ScoreColor(ratio)
		Pair("verdict " .. ratio .. " / creux", c, { WellFill(c), BLACK }, 4.5)
	end
	-- conseils : texte et vert « rien à signaler », sur la plaque et près du halo du liseré
	local halo = Theme.Over(PlateTop(card), Theme.GOLD, F.bar.haloAlpha)
	Pair("conseil / plaque + halo", Theme.TEXT, { PlateTop(card), PlateBottom(card), halo }, 4.5)
	Pair("rien à signaler / plaque", Theme.GREEN, { PlateTop(card), PlateBottom(card), halo }, 4.5)
	-- bilan : durée (titre) et libellé
	Pair("durée / plaque + halo", Theme.TITLE, { PlateTop(card), Theme.Over(PlateTop(card), Theme.GOLD, F.glow.alpha) }, 3)
	Pair("« sur les routes » / plaque", Theme.MUTED, cardBgs, 4.5)
	-- après la mort : options (or, texte) sur plaque ; verdicts dans leur creux
	Pair("option : libellé or / plaque", Theme.GOLD, cardBgs, 4.5)
	Pair("option : texte / plaque", Theme.TEXT, cardBgs, 4.5)
	Pair("verdict cours / creux vert", Theme.GREEN, { WellFill(Theme.GREEN), BLACK }, 4.5)
	Pair("verdict guérisseur / creux or", Theme.GOLD, { WellFill(Theme.GOLD), BLACK }, 4.5)
	Pair("pas de verdict / creux", Theme.GREY, { WellFill(Theme.EDGE), BLACK }, 4.5)
	-- avant le donjon : titres en or clair sur la fenêtre (petites capitales : seuil du corps)
	Pair("titre de section / fenêtre", Theme.TITLE, { Theme.WINDOW, Theme.NAV }, 4.5)
	for verdict, c in pairs(NS.DGN_FORGE.tone) do
		Pair("niveau " .. verdict .. " / creux", c, { WellFill(c), BLACK }, 4.5)
	end
	-- cartes en dégradé : nom, prix, prix estompé (plus cher que le butin), « barre 1, case 4 »
	local sheen = { PlateTop(card), PlateBottom(card) }
	Pair("carte : nom", Theme.TEXT, sheen, 4.5)
	Pair("carte : prix", Theme.MUTED_LIGHT, sheen, 4.5)
	Pair("carte : prix estompé / emplacement", Theme.MUTED, sheen, 4.5)
	Pair("butin : libellé / plaque", Theme.LABEL, cardBgs, 4.5)
	-- récompense : « Pour toi » ambre dans son creux à filet d'or
	Pair("Pour toi / creux", Theme.GOLD, { WellFill(Theme.GOLD), BLACK }, 4.5)
	s.check("[FORGE-R2Q] chaque texte posé sur un fond forgé tient son seuil (4,5 corps, 3 grands chiffres) au plus clair et au plus sombre")
end

Theme.ApplySkin(SKIN0)
