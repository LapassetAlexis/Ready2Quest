-- Carnet 1.1.0 : Collection (clic = équiper, aperçu), garde-manger de l'en-tête,
-- Créature (caractère), objectif de zone qui ouvre sa zone.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local W = {}
function W.Reset()
	ResetWorld()
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.companionRT, NS.companionSession = nil, nil
	NS:CompanionData().tutoDone = true
	NS:DB().journalTracker = false
end
function W.Find(list, id)
	for _, entry in ipairs(list) do if entry.def.id == id then return entry end end
end
function W.Cell(frame, id)
	for _, cell in ipairs(frame.coll.items) do
		if cell.entry and cell.entry.def.id == id then return cell end
	end
end

-- 1. Collection ----------------------------------------------------------------------------
do
	Say("-- carnet : Collection")
	W.Reset()
	local data = NS:CompanionData()
	data.unlocked["app:frog"], data.unlocked["frame:copper"], data.unlocked["orn:ribbon"] = true, true, true
	data.appearance = "whelp_green"
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.sections.collection:Click()
	local coll = f.coll
	Check("[COLL] onglet Collection : affiché seul", f.kind == "collection" and coll:IsShown() and not f.comp:IsShown())
	Check("[COLL] quatre sortes", coll.kinds.app and coll.kinds.orn and coll.kinds.frame and coll.kinds.bg
		and coll.kinds.app.text.text == "Apparences")
	local apps = NS:JournalCollection("app")
	Check("[COLL] apparences : tout le catalogue", #apps == #NS.COMPANION_APPEARANCES)
	Check("[COLL] compteur « possédés »", coll.count.text:find("possédés", 1, true) ~= nil, coll.count.text)
	local green, frog, owl = W.Cell(f, "whelp_green"), W.Cell(f, "frog"), W.Cell(f, "owl")
	Check("[COLL] dragonnet vert : équipé, liseré or", green and green.entry.equipped and green.selected
		and green.accent:IsShown() and green.accent.vertex[1] == NS.Theme.GOLD[1])
	Check("[COLL] chouette verrouillée : un verrou qui dit son palier, pas d'icône", owl and not owl.entry.owned
		and owl.alpha < 1 and owl.lock:IsShown() and not owl.icon:IsShown() and owl.lock.label.text:find("2", 1, true),
		owl and owl.lock.label.text)
	Check("[COLL] aperçu : l'objet équipé, sur la créature", coll.preview.title.text == NS.L.COMP_APP_WHELP_GREEN
		and coll.preview.model.display == NS:CompanionAppearanceDef("whelp_green").display, coll.preview.title.text)
	owl.scripts.OnEnter(owl)
	Check("[COLL] survol d'un objet verrouillé : sa source", coll.preview.lines[1].text == "Verrouillé."
		and coll.preview.lines[2].text:find("palier 2", 1, true), coll.preview.lines[2].text)
	owl:Click()
	Check("[COLL] clic sur un verrouillé : rien", data.appearance == "whelp_green" and NS:JournalEquip(owl.entry) == false)
	frog:Click()
	Check("[COLL] clic sur la rainette : équipée", data.appearance == "frog" and W.Cell(f, "frog").entry.equipped)
	Check("[COLL] … l'aperçu suit", coll.preview.lines[1].text == "Équipé.", coll.preview.lines[1].text)

	coll.kinds.frame:Click()
	Check("[COLL] cadres", f.collKind == "frame" and W.Cell(f, "copper") ~= nil)
	W.Cell(f, "copper"):Click()
	Check("[COLL] cadre cuivre : équipé", NS:CompanionCurrentStyle("frame").id == "copper")
	W.Cell(f, "copper").scripts.OnEnter(W.Cell(f, "copper"))
	Check("[COLL] aperçu d'un cadre : sa couleur", coll.preview.swatch:IsShown())
	W.Cell(f, "oak"):Click()
	Check("[COLL] cadre verrouillé : refusé", NS:CompanionCurrentStyle("frame").id == "copper")

	coll.kinds.orn:Click()
	local ribbon = W.Cell(f, "ribbon")
	Check("[COLL] ornement possédé : porté", ribbon and ribbon.entry.equipped)
	ribbon:Click()
	Check("[COLL] clic : l'ornement s'enlève", NS:DB().companionOrnRibbon == false and not W.Cell(f, "ribbon").entry.equipped)
	Check("[COLL] … « Clic : le porter. »", coll.preview.lines[1].text == "Clic : le porter.", coll.preview.lines[1].text)
	W.Cell(f, "ribbon"):Click()
	Check("[COLL] clic encore : remis", NS:DB().companionOrnRibbon == true)

	coll.kinds.bg:Click()
	local base = W.Find(NS:JournalCollection("bg"), "night")
	Check("[COLL] fond de base : possédé d'office", base and base.owned and NS:JournalCosmeticSource(base) == "possédé d'office")
	f:Hide()
end

-- 1 bis. Grille des zones : la molette avance d'une rangée -------------------------------------
do
	Say("-- carnet : grille des zones")
	W.Reset()
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.sections.zones:Click()
	local list, page = f.zoneList, #f.zones.tiles
	Check("[ZONES] plus de zones qu'une page", #list > page, #list)
	f.scripts.OnMouseWheel(f, -1)
	local step = NS.JOURNAL_LAYOUT.zoneStep
	Check("[ZONES] molette : trois rangées plus bas", f.zoneOffset == step and f.zones.tiles[1].zoneID == list[step + 1].id, f.zoneOffset)
	for _ = 1, 50 do NS:ScrollJournal(-1) end
	local last = f.zones.tiles[1].zone
	Check("[ZONES] butée en bas : la dernière zone visible", f.zoneOffset % NS.JOURNAL_LAYOUT.tileCols == 0 and f.zoneOffset + page >= #list
		and f.zoneOffset < #list and last ~= nil)
	f.scripts.OnMouseWheel(f, 1)
	Check("[ZONES] molette vers le haut", f.zones.tiles[1].zoneID == list[f.zoneOffset + 1].id)
	f:Hide()
end

-- 1 ter. Zones sans tranche connue : niveaux calculés, et toutes dans la grille ----------------
do
	Say("-- carnet : zones préremplies")
	W.Reset()
	local creatures = NS.ZONE_CREATURES
	local saved = creatures and creatures[99001]
	if creatures then
		local zone = {}
		for index = 1, 10 do zone[5000 + index] = { lvl = { 20 + index, 21 + index }, rank = 0 } end
		zone[5100] = { lvl = { 60, 60 }, rank = 1 }        -- un élite : écarté
		zone[5101] = { lvl = { 1, 1 }, rank = 0 }          -- un extrême bas
		creatures[99001] = zone
		NS.ZoneLevelCache[99001] = nil
		local range = NS:ZoneLevelRange(99001)
		Check("[ZONES] tranche calculée : normales, sans les extrêmes ni les élites", range and range[1] == 21 and range[2] == 30,
			range and (range[1] .. "-" .. range[2]))
		Check("[ZONES] … et son palier de coffre", NS:ZoneTier(99001) == 2)
		creatures[99001] = saved
		NS.ZoneLevelCache[99001] = nil
	end
	Check("[ZONES] zone de la table : sa tranche", NS:ZoneLevelRange(1413)[1] == 10 and NS:ZoneLevelRange(1413)[2] == 25)
	Check("[ZONES] zone inconnue : pas de tranche", NS:ZoneLevelRange(424242) == nil)
	local forever = creatures and creatures[2482]
	if forever then
		local range = NS:ZoneLevelRange(2482)
		Check("[ZONES] zone propre à Forever : une tranche", range ~= nil and range[1] >= 1, range and range[1])
		local inGrid = false
		for _, zone in ipairs(NS:JournalAllZones("all", "lvl")) do if zone.id == 2482 then inGrid = true end end
		Check("[ZONES] … et dans la grille, même jamais visitée", inGrid)
	end
	local moonglade = creatures and creatures[1450]
	if moonglade then
		Check("[ZONES] Reflet-de-Lune (absente de la table) : une tranche", NS:ZoneLevelRange(1450) ~= nil)
	end
end

-- 2. Garde-manger dans l'en-tête -----------------------------------------------------------------
do
	Say("-- carnet : garde-manger")
	W.Reset()
	NS:TreatData().pantry.bonbon = 2
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	Check("[JPAN] cinq friandises dans l'en-tête", f.pantry and f.pantry.biscuit and f.pantry.festin)
	Check("[JPAN] compteurs", f.pantry.bonbon.count.text == "2" and f.pantry.biscuit.count.text == "0")
	Check("[JPAN] vide : grisé", f.pantry.biscuit.alpha < 1 and f.pantry.bonbon.alpha == 1)
	NS:CompanionData().needs.mood = 30
	f.pantry.bonbon:Click()
	Check("[JPAN] clic : donnée", NS:TreatCount("bonbon") == 1 and NS:CompanionData().needs.mood == 100
		and f.pantry.bonbon.count.text == "1")
	NS:TreatGrant("carte", { quiet = true })
	Check("[JPAN] friandise gagnée : l'en-tête suit", f.pantry.carte.count.text == "1")
	f.pantry.carte.scripts.OnEnter(f.pantry.carte)
	local tip = table.concat(_G.GameTooltip.lines or {}, " | ")
	Check("[JPAN] survol : nom, effet, nombre", tip:find("Carte au trésor", 1, true) and tip:find("1 / 3", 1, true), tip)
	f.pantry.carte.scripts.OnLeave(f.pantry.carte)
	f:Hide()
end

-- 3. Créature, objectif de zone --------------------------------------------------------------------
do
	Say("-- carnet : Créature, objectif de zone")
	W.Reset()
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.sections.evolution:Click()
	Check("[JRNW] Créature : son caractère", f.evo.trait.text:find("Caractère : ", 1, true) ~= nil, f.evo.trait.text)
	f:Hide()
	NS:OpenJournalFor({ id = "zone:1411", zoneID = 1411, source = "journal" })
	Check("[JRNW] objectif de zone : sa zone s'ouvre", f:IsShown() and f.kind == "completion" and f.zoneID == 1411)
	f:Hide()
	NS:OpenJournalFor({ id = "stage", kind = "stage", source = "companion" })
	Check("[JRNW] objectif du compagnon : Créature", f:IsShown() and f.kind == "evolution")
	f:Hide()
	Check("[JRNW] dimensions : 980 × 680, comme les réglages", NS.JOURNAL_LAYOUT.width == 980 and NS.JOURNAL_LAYOUT.height == 680)
	local missing = {}
	for key in pairs(NS.JOURNAL_WINDOW_STRINGS.fr) do
		if NS.JOURNAL_WINDOW_STRINGS.en[key] == nil then missing[#missing + 1] = key end
	end
	Check("[JRNW] textes du carnet : fr et en", #missing == 0, table.concat(missing, ", "))
end

ResetWorld()
