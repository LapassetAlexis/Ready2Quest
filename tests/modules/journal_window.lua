-- Carnet 1.1.0 : Collection (clic = équiper, aperçu), garde-manger de l'en-tête,
-- Créature (caractère), objectif de zone qui ouvre sa zone. Carnet 1.5.0 : la
-- Collection passe dans « Son allure » (Compagnon), la zone dans la Complétion.
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

-- 1. Allure (ex-Collection) ------------------------------------------------------------------
-- Carnet 1.5.0 : la page Collection (grille de tous les objets, verrous, aperçu)
-- est retirée ; on porte ses apparences, cadres, fonds et ornements depuis la
-- page Compagnon (« Son allure »). Les données du catalogue restent.
do
	Say("-- carnet : Collection")
	W.Reset()
	local data = NS:CompanionData()
	data.unlocked["app:frog"], data.unlocked["frame:copper"], data.unlocked["orn:ribbon"] = true, true, true
	data.appearance = "whelp_green"
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	do
		local gear = f.settingsButton
		Check("[JRN] roue crantée dans l'en-tête, à gauche du ×", gear and gear:IsShown() ~= false
			and select(2, gear:GetPoint()) == f.close and select(1, gear:GetPoint()) == "RIGHT",
			tostring(gear and gear:IsShown()) .. " / " .. tostring(gear and select(1, gear:GetPoint())) .. " / " .. tostring(gear and select(2, gear:GetPoint()) == f.close))
		if NS.optionsFrame then NS.optionsFrame:Hide() end
		gear:Click()
		Check("[JRN] roue : ouvre les réglages de QuestCompanion", NS.optionsFrame ~= nil and NS.optionsFrame:IsShown())
		NS.optionsFrame:Hide()
		NS:ToggleJournal(true)
		f = NS.journalFrame
	end
	Check("[COLL] plus d'onglet Collection : l'ancien nom mène au Compagnon", f.sections.collection == nil and (function()
		NS:SelectJournalKind("collection"); return f.kind == "evolution" and f.evo:IsShown()
	end)())
	local evo = f.evo
	local apps = NS:JournalCollection("app")
	Check("[COLL] apparences : tout le catalogue", #apps == #NS.COMPANION_APPEARANCES)
	Check("[COLL] dragonnet vert : équipé", W.Find(apps, "whelp_green").equipped and not W.Find(apps, "owl").owned)
	local function Look(id)
		for _, cell in ipairs(evo.looks) do if cell:IsShown() and cell.def and cell.def.id == id then return cell end end
	end
	local green, frog = Look("whelp_green"), Look("frog")
	Check("[COLL] allure : les apparences possédées seulement, la portée en or", green and frog and Look("owl") == nil
		and green.selected and green.accent:IsShown() and green.accent.vertex[1] == NS.Theme.GOLD[1])
	Check("[COLL] clic sur un verrouillé : rien", NS:CompanionSetAppearance("owl") == nil and data.appearance == "whelp_green")
	frog:Click()
	Check("[COLL] clic sur la rainette : équipée", data.appearance == "frog" and W.Find(NS:JournalCollection("app"), "frog").equipped
		and Look("frog").selected)

	Check("[COLL] cadres : la liste les propose", evo.frameStyle.value ~= nil)
	evo.frameStyle:Choose("copper")
	Check("[COLL] cadre cuivre : équipé", NS:CompanionCurrentStyle("frame").id == "copper" and evo.frameStyle.value == "copper")
	Check("[COLL] cadre verrouillé : refusé", evo.frameStyle:Choose("oak") == false
		and NS:CompanionCurrentStyle("frame").id == "copper")

	local ribbon
	for _, button in ipairs(evo.orns) do if button:IsShown() and button.text.text == NS.L.COMP_ORN_RIBBON then ribbon = button end end
	Check("[COLL] ornement possédé : porté", ribbon and NS:DB().companionOrnRibbon ~= false
		and W.Find(NS:JournalCollection("orn"), "ribbon").equipped)
	if ribbon then ribbon:Click() end
	Check("[COLL] clic : l'ornement s'enlève", NS:DB().companionOrnRibbon == false
		and not W.Find(NS:JournalCollection("orn"), "ribbon").equipped)
	for _, button in ipairs(evo.orns) do if button:IsShown() and button.text.text == NS.L.COMP_ORN_RIBBON then ribbon = button end end
	if ribbon then ribbon:Click() end
	Check("[COLL] clic encore : remis", NS:DB().companionOrnRibbon == true)

	local base = W.Find(NS:JournalCollection("bg"), "night")
	Check("[COLL] fond de base : possédé d'office", base and base.owned and NS:JournalCosmeticSource(base) == "possédé d'office")
	f:Hide()
end

-- (1 bis, grille des zones : retirée avec la page Zones ; la molette de la liste
-- des zones de la Complétion est testée dans journal_progress.lua)

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
	-- pas encore de caractère : pas d'étiquette ; formé : son nom à côté du nom
	Check("[JRNW] Créature : pas de caractère formé, pas d'étiquette", NS:CompanionTrait() ~= nil or not f.evo.traitTag:IsShown())
	NS:PersonaData().formed = "curious"
	NS:RefreshJournal()
	local trait = NS:PersonaLabel(NS:CompanionTrait())
	Check("[JRNW] Créature : son caractère (étiquette à côté du nom)", trait and trait ~= "" and f.evo.traitTag:IsShown()
		and f.evo.traitTag.label.text == NS.Theme.Upper(trait), f.evo.traitTag.label.text)
	f:Hide()
	NS:OpenJournalFor({ id = "zone:1411", zoneID = 1411, source = "journal" })
	Check("[JRNW] objectif de zone : sa zone s'ouvre", f:IsShown() and f.kind == "progress" and f.zoneID == 1411)
	-- 2.10.0 : le clic ne referme que si la page cible est déjà là
	NS:OpenJournalFor({ id = "zone:1411", zoneID = 1411, source = "journal" })
	Check("[JRNW] … même page, même zone : le clic referme", not f:IsShown())
	NS:ToggleJournal(true)
	NS:SelectJournalKind("menagerie")
	NS:OpenJournalFor({ id = "zone:1411", zoneID = 1411, source = "journal" })
	Check("[JRNW] … ouvert sur une autre page : il y va, reste ouvert", f:IsShown() and f.kind == "progress"
		and f.zoneID == 1411, f.kind)
	NS:OpenJournalFor({ id = "zone:1413", zoneID = 1413, source = "journal" })
	Check("[JRNW] … même page, autre zone : il change de zone", f:IsShown() and f.zoneID == 1413, f.zoneID)
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
