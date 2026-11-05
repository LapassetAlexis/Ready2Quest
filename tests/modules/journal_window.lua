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
	Check("[COLL] dragonnet vert : équipé, liseré or", green and green.entry.equipped and green.edge.vertex[1] == NS.Theme.GOLD[1])
	Check("[COLL] chouette verrouillée : en silhouette", owl and not owl.entry.owned and owl.alpha < 1
		and owl.icon.texture == "Interface\\Icons\\INV_Misc_QuestionMark")
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
	Check("[ZONES] molette : une rangée plus bas", f.zoneOffset == 6 and f.zones.tiles[1].zoneID == list[7].id, f.zoneOffset)
	for _ = 1, 50 do NS:ScrollJournal(-1) end
	local last = f.zones.tiles[1].zone
	Check("[ZONES] butée en bas : la dernière zone visible", f.zoneOffset % 6 == 0 and f.zoneOffset + page >= #list
		and f.zoneOffset < #list and last ~= nil)
	f.scripts.OnMouseWheel(f, 1)
	Check("[ZONES] molette vers le haut", f.zones.tiles[1].zoneID == list[f.zoneOffset + 1].id)
	f:Hide()
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
	Check("[JRNW] dimensions : 820 × 560", NS.JOURNAL_LAYOUT.width == 820 and NS.JOURNAL_LAYOUT.height == 560)
	local missing = {}
	for key in pairs(NS.JOURNAL_WINDOW_STRINGS.fr) do
		if NS.JOURNAL_WINDOW_STRINGS.en[key] == nil then missing[#missing + 1] = key end
	end
	Check("[JRNW] textes du carnet : fr et en", #missing == 0, table.concat(missing, ", "))
end

ResetWorld()
