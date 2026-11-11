-- QuestCompanion 2.15.0 : le carnet de la refonte de la capture.
-- Relâcher refusé quand le spécimen bat le Codex ; page Créatures : « À
-- compléter », « Épinglées », épingle et « Localiser » sur chaque ligne
-- (repère, flèche, carte ouverte sur la zone) ; Exploration : « n à
-- compléter » / « complète » et le clic vers les Créatures ; Réserve :
-- grille, tri, filtres, fiche (origine, « meilleur que le Codex »), Mettre
-- au Codex, Relâcher avec confirmation dans la page, raisons des boutons
-- grisés, Réserve pleine ; Échoppe du dresseur : achats, besace pleine,
-- places, cosmétiques au compte, solde ; paillettes des missions et des
-- paliers ; les deux styles, encres mesurées, colonne de navigation.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local J = { saved = {} }
local GLOBALS = { "UnitLevel", "C_Map", "UiMapPoint", "C_SuperTrack", "InCombatLockdown", "UnitAffectingCombat",
	"OpenWorldMap", "C_Timer" }
for _, name in ipairs(GLOBALS) do J.saved[name] = rawget(_G, name) end
local FIELDS = { "journalFrame", "trainerFrame", "companionFrame", "companionBubble", "effectsConfirm" }
local INK = NS.AZEROTH_INK
local ZONE, OTHER = 1413, 1411
local savedPos = NS.ZONE_CREATURE_POS

-- Un petit catalogue : quatre espèces des Tarides, une de Durotar
local function Catalog()
	local function Item(npc, no, name, zones) return { npc = npc, no = no, staticName = name, class = "normal", lo = 10, hi = 12,
		zones = zones, zoneOrder = 1 } end
	local list = { Item(900, 1, "Raptor", { ZONE }), Item(901, 2, "Kodo", { ZONE }), Item(902, 3, "Hyène", { ZONE }),
		Item(903, 4, "Grue", { ZONE }), Item(904, 5, "Sanglier", { OTHER }) }
	local byNpc = {}
	for _, item in ipairs(list) do byNpc[item.npc] = item end
	NS.menagerieStatic = { faction = NS.BestiaryFaction and NS:BestiaryFaction() or nil, byNpc = byNpc, list = list,
		count = #list, zones = { OTHER, ZONE } }
end

function J.Reset(style)
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.effectsConfirmByStyle, NS.uiStyleCache, NS.errors, NS.carnetInkMisses = nil, {}, {}, nil
	NS.mapPin, NS.captureAppCache, NS.specimenCountCache, NS.codexReserveCache, NS.codexZoneCache = nil, nil, nil, nil, nil
	NS:DB().journalState, NS:DB().capture, NS:DB().journalTab = nil, nil, nil
	NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
	Mock.world.maps[ZONE] = { mapID = ZONE, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[OTHER] = { mapID = OTHER, name = "Durotar", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID, Mock.world.level = ZONE, 20
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.C_Timer = nil
	if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
	NS:CompanionData().tutoDone = true
	NS:CompanionData().appearance = nil
	Catalog()
	-- capturées : Raptor 3 étoiles, Kodo 1, Grue 3 (brillante 2) ; Hyène jamais vue ; Sanglier 3
	local data = NS:CaptureData()
	data.creatures[900] = { name = "Raptor", normal = true, stars = 3, zoneID = ZONE, type = "Bête", at = 1793000000 }
	data.creatures[901] = { name = "Kodo", normal = true, stars = 1, zoneID = ZONE, type = "Bête", at = 1793000100 }
	data.creatures[903] = { name = "Grue", normal = true, stars = 3, shiny = true, shinyStars = 2, zoneID = ZONE, type = "Bête" }
	data.creatures[904] = { name = "Sanglier", normal = true, stars = 3, zoneID = OTHER, type = "Bête" }
	data.count = 4
	local book = NS:BestiaryData()
	book[ZONE] = { [900] = { name = "Raptor", seen = true, type = "Bête" }, [901] = { name = "Kodo", seen = true, type = "Bête" },
		[903] = { name = "Grue", seen = true, type = "Bête" } }
	book[OTHER] = { [904] = { name = "Sanglier", seen = true, type = "Bête" } }
	NS:SpecimenMigrate()
	NS.ZONE_CREATURE_POS = { [ZONE] = "900\t300700\n901\t450550\n" }
end

function J.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = J.saved[name] end
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache, NS.mapPin, NS.menagerieStatic = {}, nil, nil
	NS.codexReserveCache, NS.codexZoneCache = nil, nil
	NS:DB().journalState, NS:DB().capture, NS:DB().journalTab = nil, nil, nil
	NS.ZONE_CREATURE_POS = savedPos
	ResetWorld()
end

-- l'API du repère, simulée ; `here` : la zone où tu es
local function PinApi(here)
	local pins = { set = 0, clear = 0, track = 0 }
	_G.UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
	-- le reste de C_Map (noms des zones) vient du monde simulé
	local map = {}
	for key, fn in pairs(J.saved.C_Map or {}) do map[key] = fn end
	map.SetUserWaypoint = function(point) pins.point = point; pins.set = pins.set + 1 end
	map.ClearUserWaypoint = function() pins.point = nil; pins.clear = pins.clear + 1 end
	map.HasUserWaypoint = function() return pins.point ~= nil end
	map.CanSetUserWaypointOnMap = function() return true end
	map.GetBestMapForUnit = function() return here end
	_G.C_Map = map
	_G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) if on then pins.track = pins.track + 1 end end }
	_G.OpenWorldMap = function(id) pins.opened = id end
	return pins
end

local function Open(kind)
	local frame = NS:ToggleJournal(true)
	if kind then NS:SelectJournalKind(kind) end
	return NS.journalFrame or frame
end
local function RowOf(pane, npc)
	for _, row in ipairs(pane.items) do if row.entry and row.entry.npc == npc and row:IsShown() then return row end end
	return nil
end
local function Has(list, pred) for _, v in ipairs(list) do if pred(v) then return true end end return false end
local function TileOf(rv, id)
	for _, tile in ipairs(rv.tiles) do if tile:IsShown() and tile.spec and tile.spec.id == id then return tile end end
	return nil
end

-- 1. Relâcher : jamais au-dessus du Codex ----------------------------------------------------------------
do
	Say("-- qc215 carnet : relâcher ne baisse jamais tes étoiles")
	J.Reset("sobre")
	local ref = NS:SpecimenReference(901, false)
	local three = NS:SpecimenAdd({ npc = 901, stars = 3, name = "Kodo", origin = "capture", by = "Dyokrion", zone = ZONE })
	Check("[J215] meilleur spécimen : au Codex, l'ancien en Réserve", NS:SpecimenIsReference(three) and not NS:SpecimenIsReference(ref.id))
	NS:SpecimenSetReference(ref.id)
	local ok, why = NS:SpecimenCanRelease(three)
	Check("[J215] 3 étoiles en Réserve, Codex à 1 : refusé (« better »)", ok == false and why == "better")
	Check("[J215] … le texte le dit", (NS.L.SPECIMEN_ERR_better or ""):find("Codex", 1, true) ~= nil
		and NS.L.RES_WHY_better == "Mets-le au Codex avant de le relâcher.")
	local equal = NS:SpecimenAdd({ npc = 901, stars = 1, name = "Kodo" })
	Check("[J215] même qualité que le Codex : permis", NS:SpecimenCanRelease(equal) == true)
	J.Done()
end

-- 2. Créatures : « À compléter », « Épinglées » ----------------------------------------------------------
do
	Say("-- qc215 carnet : À compléter, épingles")
	J.Reset("sobre")
	PinApi(ZONE)
	local list, stats = NS:MenagerieList({ zone = ZONE, state = "todo" })
	local ids = {}
	for _, item in ipairs(list) do ids[item.npc] = true end
	Check("[J215] À compléter : Kodo 1★, Hyène pas capturée, Grue brillante 2★ (pas le Raptor 3★)", #list == 3
		and ids[901] and ids[902] and ids[903] and not ids[900], #list)
	Check("[J215] comptes : à compléter et épinglées", stats.todo == 3 and stats.pinned == 0)
	Check("[J215] autres états inchangés", #NS:MenagerieList({ zone = ZONE, state = "captured" }) == 3)
	NS:HuntPin(900, true)
	list, stats = NS:MenagerieList({ zone = ZONE, state = "pinned" })
	Check("[J215] Épinglées : la liste de chasse", #list == 1 and list[1].npc == 900 and stats.pinned == 1)
	-- la page
	local f = Open("menagerie")
	local pane = f.men
	Check("[J215] puces : À compléter et Épinglées, la recherche monte en 1re rangée", pane.states.todo and pane.states.pinned
		and pane.search.lastPoint and pane.search.lastPoint.y == NS.JournalUI.TOP)
	f.menZone = ZONE
	pane.states.todo:GetScript("OnClick")(pane.states.todo)
	Check("[J215] filtre À compléter : trois lignes, compte dédié", f.menState == "todo" and RowOf(pane, 901) and RowOf(pane, 902)
		and not RowOf(pane, 900) and (pane.count:GetText() or ""):find("3 à compléter", 1, true) ~= nil, pane.count:GetText())
	local row = RowOf(pane, 901)
	Check("[J215] ligne connue : épingle et Localiser", row.pin:IsShown() and row.locate:IsShown() and not row.pin.on)
	Check("[J215] espèce jamais vue : pas d'épingle", not RowOf(pane, 902).pin:IsShown())
	Mock:Reset()
	row.pin:GetScript("OnClick")(row.pin)
	row = RowOf(pane, 901)
	Check("[J215] clic sur l'épingle : épinglée, ligne mise en évidence, chat", NS:HuntPinned(901) and row.pin.on
		and row.mark:IsShown() and Mock:Output():find("Kodo", 1, true) ~= nil)
	pane.states.pinned:GetScript("OnClick")(pane.states.pinned)
	Check("[J215] Épinglées : Raptor et Kodo", RowOf(pane, 900) and RowOf(pane, 901) and not RowOf(pane, 903))
	row = RowOf(pane, 901)
	row.pin:GetScript("OnClick")(row.pin)
	Check("[J215] 2e clic : retirée", not NS:HuntPinned(901) and not RowOf(pane, 901))
	-- fiche : Réserve et état
	NS:SpecimenAdd({ npc = 900, stars = 1, name = "Raptor" })
	NS:JournalPreviewMenagerie(RowOf(pane, 900).entry)
	local t = {}
	for _, l in ipairs(pane.preview.lines) do t[#t + 1] = tostring(l:GetText()) end
	local text = table.concat(t, "\n")
	Check("[J215] fiche : « En Réserve : 1 · Épinglée », sous la zone", text:find("En Réserve : 1 · Épinglée", 1, true) ~= nil, text)
	Check("[J215] ligne : « Réserve 1 » à la place du type", RowOf(pane, 900).detail:GetText() == "Réserve 1", RowOf(pane, 900).detail:GetText())
	f.menZone = "all"
	NS:RefreshJournal()
	Check("[J215] toutes zones : la zone, puis la Réserve", RowOf(pane, 900).detail:GetText() == "Les Tarides · Réserve 1",
		RowOf(pane, 900).detail:GetText())
	Check("[J215] aucune erreur du carnet", next(NS.errors or {}) == nil)
	J.Done()
end

-- 3. Localiser : repère, flèche, carte de la zone ---------------------------------------------------------
do
	Say("-- qc215 carnet : Localiser")
	J.Reset("sobre")
	local pins = PinApi(OTHER)
	local set, zone = NS:LocateSpecies(901, { OTHER, ZONE })
	Check("[J215] point de l'espèce : 1re zone qui en a un", set == true and zone == ZONE and pins.point.map == ZONE
		and math.abs(pins.point.x - 0.45) < 1e-9 and pins.track == 1)
	Check("[J215] tu es ailleurs : la carte s'ouvre sur sa zone", pins.opened == ZONE)
	Check("[J215] 2e clic : repère retiré", NS:LocateSpecies(901, ZONE) == false and pins.clear == 1)
	pins = PinApi(ZONE)
	NS:LocateSpecies(900, ZONE)
	Check("[J215] dans sa zone : flèche seulement, pas de carte", pins.set == 1 and pins.opened == nil)
	NS:LocateSpecies(900, ZONE)
	Check("[J215] espèce sans point : rien", NS:LocateSpecies(903, ZONE) == false and pins.set == 1)
	_G.InCombatLockdown = function() return true end
	pins = PinApi(OTHER)
	NS:LocateSpecies(901, ZONE)
	Check("[J215] en combat : repère posé, carte pas ouverte", pins.set == 1 and pins.opened == nil)
	_G.InCombatLockdown = function() return false end
	-- par la ligne de la page Créatures
	pins = PinApi(OTHER)
	NS.mapPin = nil
	local f = Open("menagerie")
	f.menZone, f.menState = ZONE, "todo"
	NS:RefreshJournal()
	local row = RowOf(f.men, 901)
	row.locate:GetScript("OnClick")(row.locate)
	Check("[J215] ligne : Localiser pose le repère et ouvre la carte", pins.set == 1 and pins.opened == ZONE
		and RowOf(f.men, 901).locate.on)
	Check("[J215] sans point connu : pas d'icône Localiser", not RowOf(f.men, 903).locate:IsShown())
	J.Done()
end

-- 4. Exploration : « n à compléter », clic vers les Créatures ----------------------------------------------
do
	Say("-- qc215 carnet : Exploration")
	J.Reset("sobre")
	local counts = NS:CodexZoneCounts(ZONE)
	Check("[J215] comptes de zone : 4 espèces, 3 à compléter, 1 à capturer", counts.total == 4 and counts.todo == 3
		and counts.missing == 1 and not counts.complete)
	Check("[J215] comptes gardés tant que rien ne bouge", NS:CodexZoneCounts(ZONE) == counts)
	local other = NS:CodexZoneCounts(OTHER)
	Check("[J215] zone toute en 3 étoiles : complète", other.total == 1 and other.todo == 0 and other.complete)
	NS:SpecimenAdd({ npc = 901, stars = 3, name = "Kodo" })
	Check("[J215] un spécimen de plus : recompté", NS:CodexZoneCounts(ZONE).todo == 2)
	local f = NS:ToggleJournal(true)
	NS:OpenJournalZone(ZONE)
	f = NS.journalFrame
	local tag = f.prog.todoTag
	Check("[J215] tag « 2 à compléter » sur la zone", tag:IsShown() and tag.label:GetText() == "2 à compléter" and not tag.complete,
		tag.label:GetText())
	local tip = false
	for _, row in ipairs(f.prog.zones) do if row.zoneID == ZONE then tip = row end end
	tag:GetScript("OnClick")(tag)
	Check("[J215] clic : Créatures de la zone, filtre À compléter", f.kind == "menagerie" and f.menZone == ZONE and f.menState == "todo"
		and RowOf(f.men, 902) and not RowOf(f.men, 901))
	NS:OpenJournalZone(OTHER)
	tag = NS.journalFrame.prog.todoTag
	Check("[J215] zone complète : « complète » en vert", tag:IsShown() and tag.complete
		and (tag.label:GetText() or ""):find("^complète") ~= nil and tag.label.textColor[2] == NS.Theme.GREEN[2])
	tag:GetScript("OnClick")(tag)
	Check("[J215] clic sur une zone complète : toute la zone", NS.journalFrame.kind == "menagerie" and NS.journalFrame.menState == "all"
		and NS.journalFrame.menZone == OTHER)
	J.Done()
end

-- 5. Réserve : grille, tri, filtres, fiche, actions --------------------------------------------------------
local function FillReserve()
	local a = NS:SpecimenAdd({ npc = 900, stars = 1, name = "Raptor", origin = "capture", by = "Dyokrion", zone = ZONE, at = 1793500000 })
	local b = NS:SpecimenAdd({ npc = 900, stars = 2, name = "Raptor", origin = "capture", by = "Dyokrion", zone = ZONE, at = 1793600000 })
	local ref = NS:SpecimenReference(901, false)
	local c = NS:SpecimenAdd({ npc = 901, stars = 3, name = "Kodo", origin = "capture", by = "Deklatis", zone = ZONE, at = 1793400000 })
	NS:SpecimenSetReference(ref.id)
	NS:SpecimenAdd({ npc = 903, stars = 1, shiny = true, name = "Grue" })
	local s = NS:SpecimenAdd({ npc = 903, stars = 1, shiny = true, name = "Grue", at = 1793700000 })
	return { low = a, mid = b, better = c, ref = ref.id, shiny = s }
end

for _, style in ipairs({ "sobre", "azeroth" }) do
	Say("-- qc215 carnet : Réserve (" .. style .. ")")
	J.Reset(style)
	local ids = FillReserve()
	local f = NS:OpenReserve()
	local pane = f and f.res
	local rv = pane and pane.reserve
	Check("[J215] " .. style .. " : la page Réserve, dans la navigation", f.kind == "reserve" and f.sections.reserve ~= nil
		and pane:IsShown() and rv:IsShown() and not f.shopPane:IsShown())
	Check("[J215] " .. style .. " : en-tête « Réserve · 5 / 20 »", f.header.title:GetText() == "Réserve · 5 / 20", f.header.title:GetText())
	NS:PaillettesAdd(126, "test")
	NS:RefreshJournal()
	-- 3.0.0 : le solde en pastille (chiffre, « paillettes »)
	Check("[J215] " .. style .. " : solde de paillettes", pane.balance.value:GetText() == "126"
		and pane.balance.label:GetText() == "paillettes")
	local shown = 0
	for _, tile in ipairs(rv.tiles) do if tile:IsShown() then shown = shown + 1 end end
	Check("[J215] " .. style .. " : une vignette par spécimen, la meilleure d'abord", shown == 5 and rv.tiles[1].spec.id == ids.better
		and rv.tiles[1].stars[3].full and rv.tiles[1].label:GetText() == "Kodo")
	Check("[J215] " .. style .. " : brillant : perle", TileOf(rv, ids.shiny).gem:IsShown() and not TileOf(rv, ids.low).gem:IsShown())
	local before = #Mock.frames
	NS:RefreshJournal(); NS:RefreshJournal()
	Check("[J215] " .. style .. " : rafraîchi sans rien créer (vignettes réutilisées)", #Mock.frames == before, #Mock.frames .. "/" .. before)
	rv.sort:Choose("date")
	Check("[J215] " .. style .. " : tri par date", rv.tiles[1].spec.id == ids.shiny and f.resSort == "date")
	rv.sort:Choose("name")
	Check("[J215] " .. style .. " : tri par nom", rv.tiles[1].spec.name == "Grue")
	rv.species:Choose(900)
	shown = 0
	for _, tile in ipairs(rv.tiles) do if tile:IsShown() then shown = shown + 1 end end
	Check("[J215] " .. style .. " : filtre d'espèce", shown == 2 and TileOf(rv, ids.low) and TileOf(rv, ids.mid))
	rv.species:Choose("all")
	rv.show:Select("shiny")
	Check("[J215] " .. style .. " : filtre Brillants", TileOf(rv, ids.shiny) and not TileOf(rv, ids.low))
	rv.show:Select("all")
	rv.sort:Choose("stars")
	-- fiche : origine, meilleur que le Codex, bouton grisé et pourquoi
	TileOf(rv, ids.better):GetScript("OnClick")(TileOf(rv, ids.better))
	local p = rv.preview
	local lines = {}
	for _, line in ipairs(p.lines) do lines[#lines + 1] = line:GetText() or "" end
	local text = table.concat(lines, "\n")
	Check("[J215] " .. style .. " : « Capturé par Deklatis · Les Tarides »", text:find("Capturé par Deklatis · Les Tarides", 1, true) ~= nil, text)
	Check("[J215] " .. style .. " : « Meilleur que ton spécimen du Codex »", text:find("Meilleur que ton spécimen du Codex", 1, true) ~= nil
		and rv.betterLine ~= nil)
	Check("[J215] " .. style .. " : Relâcher grisé, la raison dite (fiche et infobulle)", rv.release.qcEnabled == false
		and rv.release.disabledTip == "Mets-le au Codex avant de le relâcher." and text:find("Mets-le au Codex", 1, true) ~= nil)
	if style == "azeroth" then
		local tile = rv.tiles[1]
		Check("[J215] azeroth : vignettes claires, encres reserve.*", tile.azStyle == "light" and tile.label.azRole == "reserve.name"
			and pane.balance.value.azRole == "currency.value" and rv.preview.lines[2].azRole == "reserve.detail")
		Check("[J215] azeroth : « meilleur » en vert, la raison en rouge, mesurés", rv.betterLine and rv.reasonLine
			and rv.preview.lines[rv.betterLine].azRole == "reserve.better" and rv.preview.lines[rv.reasonLine].azRole == "reserve.reason")
		Check("[J215] azeroth : fiche habillée comme celle des Créatures", rv.preview.azStyle == "light" and rv.preview.azWoodBorder ~= nil)
		Check("[J215] azeroth : aucun rôle manquant", NS.carnetInkMisses == nil, table.concat(NS.carnetInkMisses or {}, ", "))
	end
	-- Mettre au Codex : échange
	rv.toCodex:GetScript("OnClick")(rv.toCodex)
	Check("[J215] " .. style .. " : Mettre au Codex : il y entre, l'ancien passe en Réserve et devient le choisi",
		NS:SpecimenIsReference(ids.better) and not NS:SpecimenIsReference(ids.ref) and f.resPick == ids.ref and TileOf(rv, ids.ref) ~= nil
		and not TileOf(rv, ids.better))
	lines = {}
	for _, line in ipairs(p.lines) do lines[#lines + 1] = line:GetText() or "" end
	Check("[J215] " .. style .. " : spécimen migré : « Avant la 3.0 »", table.concat(lines, "\n"):find("Avant la 3.0", 1, true) ~= nil)
	-- Relâcher : confirmation dans la page
	TileOf(rv, ids.low):GetScript("OnClick")(TileOf(rv, ids.low))
	Check("[J215] " .. style .. " : Relâcher (+1)", rv.release.qcEnabled == true and (rv.release:GetText() or ""):find("+1", 1, true) ~= nil)
	local balance = NS:Paillettes()
	rv.release:GetScript("OnClick")(rv.release)
	Check("[J215] " .. style .. " : 1er clic : la confirmation s'ouvre dans la fiche, rien n'est relâché", f.resConfirm == ids.low
		and rv.confirm:IsShown() and rv.confirmYes:IsShown() and not rv.release:IsShown() and NS:SpecimenGet(ids.low) ~= nil
		and NS:Paillettes() == balance)
	rv.confirmNo:GetScript("OnClick")(rv.confirmNo)
	Check("[J215] " .. style .. " : Annuler", f.resConfirm == nil and rv.release:IsShown() and not rv.confirm:IsShown())
	rv.release:GetScript("OnClick")(rv.release)
	rv.confirmYes:GetScript("OnClick")(rv.confirmYes)
	Check("[J215] " .. style .. " : confirmé : relâché, +1 paillette, le choix passe au suivant", NS:SpecimenGet(ids.low) == nil
		and NS:Paillettes() == balance + 1 and f.resPick ~= ids.low and f.resPick ~= nil and not rv.confirm:IsShown())
	-- Localiser l'espèce
	local pins = PinApi(OTHER)
	TileOf(rv, ids.mid):GetScript("OnClick")(TileOf(rv, ids.mid))
	rv.locate:GetScript("OnClick")(rv.locate)
	Check("[J215] " .. style .. " : Localiser l'espèce : repère et carte", pins.set == 1 and pins.point.map == ZONE and pins.opened == ZONE
		and rv.locate:GetText() == "Effacer le repère")
	TileOf(rv, ids.shiny):GetScript("OnClick")(TileOf(rv, ids.shiny))
	Check("[J215] " .. style .. " : espèce sans point : Localiser grisé", rv.locate.qcEnabled == false and rv.locate.disabledTip ~= nil)
	-- Réserve pleine
	Check("[J215] " .. style .. " : pas pleine : pas d'avertissement", (rv.warn:GetText() or "") == "")
	for _ = 1, 17 do NS:SpecimenAdd({ npc = 904, stars = 1, name = "Sanglier" }) end
	NS:RefreshJournal()
	Check("[J215] " .. style .. " : Réserve pleine : le dire", NS:ReserveFull() and (rv.warn:GetText() or ""):find("Réserve pleine", 1, true) ~= nil)
	-- vide
	NS:DB().capture.specimens, NS:DB().capture.codex = {}, {}
	NS:DB().capture.specDirty = true    -- le Codex se refait d'après les fiches : Réserve vide
	NS:RefreshJournal()
	Check("[J215] " .. style .. " : Réserve vide : expliquée, fiche vide", rv.empty:IsShown() and not rv.release:IsShown())
	Check("[J215] " .. style .. " : aucune erreur du carnet", next(NS.errors or {}) == nil, next(NS.errors or {}))
	J.Done()
end

-- 6. Échoppe du dresseur -----------------------------------------------------------------------------------
for _, style in ipairs({ "sobre", "azeroth" }) do
	Say("-- qc215 carnet : Échoppe (" .. style .. ")")
	J.Reset(style)
	-- 3.0.0 : l'Échoppe a son onglet (OpenReserve("shop") y mène encore)
	local f = NS:OpenReserve("shop")
	local pane = f.res
	local sv = f.shopPane
	Check("[J215] " .. style .. " : l'onglet Échoppe", f.kind == "shop" and sv:IsShown() and not pane:IsShown()
		and f.header.title:GetText() == "Échoppe du dresseur")
	local rows = {}
	for _, row in ipairs(sv.rows) do rows[row.item.id] = row end
	Check("[J215] " .. style .. " : six articles, prix de la table", #sv.rows == #NS.PAILLETTES_SHOP and rows.appat.item.price == 5
		and rows.lasso.item.price == 15 and rows.sifflet.item.price == 40 and rows.slots.item.price == 50)
	Check("[J215] " .. style .. " : solde à 0 : tout grisé, il manque n", rows.appat.buy.qcEnabled == false
		and rows.appat.buy.disabledTip == "Il te manque 5 paillettes." and rows.appat.state == "short"
		and rows.appat.buy.disabledLook == true)
	NS:PaillettesAdd(200, "test")
	NS:RefreshJournal()
	local items = NS:CaptureData().items
	local had = items.appat or 0
	rows.appat.buy:GetScript("OnClick")(rows.appat.buy)
	Check("[J215] " .. style .. " : Acheter : confirmation dans la ligne", f.shopConfirm == "appat" and rows.appat.yes:IsShown()
		and not rows.appat.buy:IsShown() and NS:Paillettes() == 200)
	rows.appat.no:GetScript("OnClick")(rows.appat.no)
	Check("[J215] " .. style .. " : Annuler", f.shopConfirm == nil and rows.appat.buy:IsShown() and NS:Paillettes() == 200)
	Mock:Reset()
	rows.appat.buy:GetScript("OnClick")(rows.appat.buy)
	rows.appat.yes:GetScript("OnClick")(rows.appat.yes)
	Check("[J215] " .. style .. " : achat : aide dans la besace, −5, ligne dans le chat", (items.appat or 0) == had + 1
		and NS:Paillettes() == 195 and Mock:Output():find("Échoppe du dresseur", 1, true) ~= nil)
	Check("[J215] " .. style .. " : solde affiché", sv.balance.value:GetText() == "195")
	items.sifflet = 3
	NS:RefreshJournal()
	Check("[J215] " .. style .. " : besace pleine : grisé, la limite dite", rows.sifflet.state == "full" and rows.sifflet.buy.qcEnabled == false
		and rows.sifflet.buy.disabledTip == "Besace pleine (3/3) : utilise-en d'abord." and select(2, NS:ShopBuy("sifflet")) == "full")
	Check("[J215] " .. style .. " : places de Réserve : +5", NS:ShopBuy("slots") == true and NS:ReserveCapacity() == 25
		and NS:Paillettes() == 145)
	-- cosmétique : au compte, condition « Échoppe du dresseur : n paillettes »
	local frameDef
	for _, def in ipairs(NS.COMPANION_FRAMES) do if def.id == "shop_glitter" then frameDef = def end end
	Check("[J215] " .. style .. " : cadre de l'échoppe : verrouillé, condition dite", frameDef and not NS:CompanionIsUnlocked("frame", frameDef)
		and NS:CompanionLockText(frameDef) == "Échoppe du dresseur : 80 paillettes", frameDef and NS:CompanionLockText(frameDef))
	Check("[J215] " .. style .. " : acheté : débloqué pour le compte", NS:ShopBuy("frame_glitter") == true
		and NS:CompanionIsUnlocked("frame", frameDef) and NS:DB().capture.shopOwned.shop_glitter == true and NS:Paillettes() == 65)
	NS:RefreshJournal()
	Check("[J215] " .. style .. " : déjà à toi : « Acquis », grisé", rows.frame_glitter.state == "owned"
		and rows.frame_glitter.buy:GetText() == "Acquis" and rows.frame_glitter.buy.qcEnabled == false
		and select(2, NS:ShopBuy("frame_glitter")) == "owned")
	Check("[J215] " .. style .. " : le fond (60) : acheté ; le lasso (15) : il manque", NS:ShopBuy("bg_starfall") == true
		and NS:Paillettes() == 5 and select(2, NS:ShopBuy("lasso")) == "short")
	NS:DB().companionCapture = false
	NS:RefreshJournal()
	Check("[J215] " .. style .. " : capture coupée : pas d'aides", rows.appat.state == "off" and rows.appat.buy.qcEnabled == false)
	NS:DB().companionCapture = true
	-- retour à la Réserve par l'onglet
	f.sections.reserve:GetScript("OnClick")(f.sections.reserve)
	Check("[J215] " .. style .. " : onglet Réserve", f.kind == "reserve" and f.resView == "reserve" and pane.reserve:IsShown()
		and not sv:IsShown())
	if style == "azeroth" then
		NS:OpenShop()
		Check("[J215] azeroth : lignes de l'échoppe : encres shop.*", rows.appat.name.azRole == "shop.name"
			and rows.appat.desc.azRole == "shop.desc" and rows.appat.price.azRole == "shop.price" and sv.note.azRole == "reserve.text")
		Check("[J215] azeroth : aucun rôle manquant", NS.carnetInkMisses == nil, table.concat(NS.carnetInkMisses or {}, ", "))
	end
	Check("[J215] " .. style .. " : aucune erreur", next(NS.errors or {}) == nil)
	J.Done()
end

-- 7. Paillettes des missions et des paliers -----------------------------------------------------------------
do
	Say("-- qc215 carnet : paillettes en récompense")
	J.Reset("sobre")
	NS:MissionGrant("zone")
	Check("[J215] mission du jour : +3 paillettes", NS:Paillettes() == 3)
	NS:MissionGrant("allWeekly")
	Check("[J215] les trois de la semaine : +10", NS:Paillettes() == 13)
	Check("[J215] texte de la récompense", NS:MissionRewardText("zone"):find("3 paillettes", 1, true) ~= nil)
	Check("[J215] paliers de zone : +2 chacun", NS:PaillettesOnMilestones({ { mark = 25 }, { mark = 50 } }, { quiet = true }) == 4
		and NS:Paillettes() == 17)
	NS:DB().companionCapture = false
	Check("[J215] capture coupée : rien", NS:PaillettesOnMilestones({ { mark = 75 } }) == 0 and NS:Paillettes() == 17)
	NS:MissionGrant("zone")
	Check("[J215] capture coupée : pas de paillettes de mission", NS:Paillettes() == 17)
	NS:DB().companionCapture = true
	J.Done()
end

-- 8. Colonne de navigation : la Réserve y tient --------------------------------------------------------------
do
	Say("-- qc215 carnet : colonne de navigation")
	for _, style in ipairs({ "sobre", "azeroth" }) do
		J.Reset(style)
		local f = Open("evolution")
		local nav, box = f.nav, f.navSummary
		local count = 0
		for _ in pairs(f.sections) do count = count + 1 end
		local lay = NS.CARNET_LAYOUT
		local navH = style == "azeroth" and (f:GetHeight() - lay.band - lay.wood) or (f:GetHeight() - 2)
		local top = -(box.lastPoint and box.lastPoint.y or 0)
		local bottom = top + box:GetHeight()
		-- en bas : le total (Sobre) ou le garde-manger (Azeroth, étiquette à 50 px du bas)
		local reserved = style == "azeroth" and 50 + 16 or 18 + 16
		Check("[J215] " .. style .. " : neuf entrées, la Réserve après les Créatures, l'Échoppe après la Réserve", count == 9
			and f.sections.reserve ~= nil and NS.JOURNAL_SECTIONS[3] == "reserve" and NS.JOURNAL_SECTIONS[4] == "shop"
			and f.sections.shop ~= nil)
		Check("[J215] " .. style .. " : le résumé tient au-dessus du bas de la colonne", bottom <= navH - reserved,
			bottom .. " / " .. navH)
		J.Done()
	end
end

-- 9. Encres et textes --------------------------------------------------------------------------------------
do
	Say("-- qc215 carnet : encres et textes")
	local bad = {}
	local roles = { "reserve.balance", "reserve.full", "reserve.text", "reserve.hint", "reserve.name", "reserve.shiny",
		"reserve.detail", "reserve.better", "reserve.reason", "reserve.confirm", "shop.name", "shop.desc", "shop.price",
		"shop.short", "codex.todo", "codex.done" }
	for _, role in ipairs(roles) do
		local r = NS.AZEROTH_CONTRAST[role]
		local ratio = r and NS.AzerothContrast(INK[r[1]], r[2]) or 0
		if not r or ratio < r[3] then bad[#bad + 1] = role .. string.format(" %.2f", ratio) end
	end
	Check("[J215] rôles reserve.* / shop.* / codex.* : seuil tenu sur le fond mesuré", #bad == 0, table.concat(bad, ", "))
	Check("[J215] fonds repris des surfaces déjà mesurées", NS.AZEROTH_CONTRAST["reserve.name"][2] == NS.AZEROTH_CONTRAST["tile.text"][2]
		and NS.AZEROTH_CONTRAST["reserve.text"][2] == NS.AZEROTH_CONTRAST["page.ink"][2])
	local fr, en = NS.RESERVE_STRINGS.fr, NS.RESERVE_STRINGS.en
	local missing = {}
	for key in pairs(fr) do if en[key] == nil then missing[#missing + 1] = key end end
	for key in pairs(en) do if fr[key] == nil then missing[#missing + 1] = key end end
	Check("[J215] textes FR/EN au complet", #missing == 0, table.concat(missing, ", "))
	Check("[J215] la paillette : icône du client, jamais livrée", NS.PAILLETTES_ICON:find("^Interface\\Icons\\") ~= nil
		and NS.PaillettesGlyph(12):find(NS.PAILLETTES_ICON, 1, true) ~= nil)
	Check("[J215] icônes des lignes : client", NS.MEN_ROW_ICONS.pin:find("^Interface\\Icons\\") ~= nil
		and NS.MEN_ROW_ICONS.locate:find("^Interface\\Icons\\") ~= nil)
end
