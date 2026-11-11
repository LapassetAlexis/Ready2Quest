-- QuestCompanion 2.14 : choisir l'allure du compagnon (CompanionAllure.lua).
-- La page Compagnon montre l'allure portée et « Choisir… » ; le panneau :
-- grille ordonnée (types, brillante à côté de la normale, mascottes pas
-- gagnées à la fin), molette, recherche, puces, section « Voile d'hiver » en
-- saison ; clic = le chemin de l'ancien carrousel (confirmation des effets,
-- délai), Maj+clic = favori, mascottes pas gagnées grisées, version brillante,
-- deux habits (Sobre, Azeroth), Échap ; vignettes : portrait 2D, modèle de la
-- créature, apprentissage des displayID en fond ; Metzen (modèle, portraits
-- 2D des compagnons de saison, /qc noel metzen) ; des noms, jamais des numéros.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local A = { saved = {} }
local GLOBALS = { "IsShiftKeyDown", "C_Timer", "SetPortraitTextureFromCreatureDisplayID", "InCombatLockdown",
	"UnitAffectingCombat", "UnitLevel" }
for _, name in ipairs(GLOBALS) do A.saved[name] = rawget(_G, name) end
A.season, A.choice = NS.WinterVeilSeason, NS.WinterVeilChoice
local FIELDS = { "journalFrame", "effectsConfirm", "allurePanel" }
local INK = NS.AZEROTH_INK

-- plusieurs étapes d'un même sujet : un contrôle, les étapes ratées nommées
local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local function Hide()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	for _, frame in pairs(NS.allureByStyle or {}) do frame:Hide() end
	NS.allureByStyle, NS.effectsConfirmByStyle = nil, nil
	NS.uiStyleCache = {}
end

-- quatre espèces : deux bêtes (l'une aussi en brillante), un humanoïde, un élémentaire
function A.Reset(style, season)
	ResetWorld()
	Hide()
	NS.errors = {}
	NS.carnetInkMisses = nil
	NS:DB().journalState = nil
	NS:DB().journalTracker = false
	A.shift, A.timers, A.portraits = false, {}, {}
	_G.IsShiftKeyDown = function() return A.shift end
	_G.C_Timer = { After = function(_, fn) A.timers[#A.timers + 1] = fn end }
	_G.SetPortraitTextureFromCreatureDisplayID = function(tex, id) A.portraits[#A.portraits + 1] = id; tex.portraitID = id end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.UnitLevel = function() return 20 end
	A.on = season and true or false
	NS.WinterVeilSeason = function() return A.on end
	NS.WinterVeilChoice = function() return nil end
	NS:WinterCompanionsForget()
	if style == "azeroth" then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "azeroth" and "azeroth" or "sobre"
	local data = NS:CompanionData()
	data.tutoDone, data.stage = true, 1
	data.appearance, data.winter, data.effects, data.allureFav = NS.COMPANION_APPEARANCES[1].id, nil, nil, nil
	local capture = NS:CaptureData()
	capture.creatures = {}
	capture.creatures[7001] = { name = "Kodo", class = "normal", type = "Bête", normal = true, at = 1 }
	capture.creatures[7002] = { name = "Ourson", class = "elite", type = "Bête", normal = true, at = 2, shiny = true, shinyAt = 3 }
	capture.creatures[7003] = { name = "Élémentaire de feu", class = "normal", type = "Élémentaire", normal = true, at = 4 }
	capture.creatures[7004] = { name = "Gnoll", class = "normal", type = "Humanoïde", normal = true, at = 5 }
	-- de quoi défiler : douze bêtes de plus, après l'ourson (Zèbre…)
	for n = 1, 12 do
		capture.creatures[7100 + n] = { name = "Zèbre " .. string.format("%02d", n), class = "normal", type = "Bête", normal = true, at = 10 + n }
	end
	capture.count = 16
	capture.serial = (capture.serial or 0) + 1
	NS.captureAppCache = nil
	local account = NS:CaptureAccount()
	account.display = { [7001] = 1001, [7002] = 1002 }
	NS:CompanionUpdateVisibility()
end
function A.Done()
	Hide()
	for _, name in ipairs(GLOBALS) do _G[name] = A.saved[name] end
	NS.WinterVeilSeason, NS.WinterVeilChoice = A.season, A.choice
	NS:WinterCompanionsForget()
	local data = NS:CompanionData()
	data.winter, data.effects, data.allureFav = nil, nil, nil
	data.appearance = NS.COMPANION_APPEARANCES[1].id
	local capture = NS:CaptureData()
	capture.creatures, capture.count = {}, 0
	NS.captureAppCache = nil
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = nil
	ResetWorld()
end
function A.Fire()
	local list = A.timers
	A.timers = {}
	for _, fn in ipairs(list) do fn() end
end
local function Open()
	NS:ToggleJournal(true)
	NS:SelectJournalKind("evolution")
	local evo = NS.journalFrame.evo
	evo.lookChoose:Click()
	return NS.allurePanel, evo
end
-- les ids des vignettes montrées, dans l'ordre
local function Shown(panel)
	local ids = {}
	for _, tile in ipairs(panel.tiles) do if tile.def and tile:IsShown() then ids[#ids + 1] = tile.def.id end end
	return ids
end
local function Index(list, id) for i, v in ipairs(list) do if v == id then return i end end return nil end
local function TileOf(panel, id)
	for _, tile in ipairs(panel.tiles) do if tile.def and tile.def.id == id and tile:IsShown() then return tile end end
	for _, tile in ipairs(panel.seasonTiles) do if tile.def and tile.def.id == id and tile:IsShown() then return tile end end
	return nil
end
local function Type(panel, text)
	panel.searchBox:SetText(text)
	panel.searchBox.scripts.OnTextChanged(panel.searchBox)
end

-- 1. La page Compagnon : l'allure portée et « Choisir… » ------------------------------------------
do
	Say("-- allure : la page")
	A.Reset("sobre", false)
	NS:ToggleJournal(true)
	NS:SelectJournalKind("evolution")
	local evo = NS.journalFrame.evo
	Check("[ALLURE] page : plus de carrousel ; carte de l'allure portée (nom, nature, nombre), « Choisir… », titre gardé",
		evo.looks == nil and evo.lookPrev == nil and evo.lookNext == nil and NS.CompanionLooksScroll == nil
		and evo.lookCard and evo.lookChoose and evo.lookName.text == NS.L[NS.COMPANION_APPEARANCES[1].label]
		and evo.lookChoose.text.text == NS.L.ALLURE_CHOOSE and evo.lookDetail.text:find(NS.L.ALLURE_MASCOT, 1, true)
		and evo.lookDetail.text:find(NS:F("ALLURE_CARD_COUNT", #NS:CompanionUnlockedAppearances()), 1, true)
		and evo.looksTitle.raw:find(NS.L.JRN_EVO_LOOKS, 1, true) == 1, tostring(evo.lookDetail and evo.lookDetail.text))
	evo.lookChoose:Click()
	local panel = NS.allurePanel
	Check("[ALLURE] « Choisir… » ouvre le panneau du socle, posé sur le carnet, au-dessus", panel and panel:IsShown()
		and panel.strata == NS.ALLURE_STRATA and panel.lastPoint.relTo == NS.journalFrame
		and panel.level == NS.journalFrame.level + NS.ALLURE_LEVEL_UP and panel.uiStyle == "sobre" and not panel.azBg)
	A.Done()
end

-- 2. Grille, ordre, saison --------------------------------------------------------------------------
do
	Say("-- allure : la grille")
	A.Reset("sobre", false)
	local panel = Open()
	local ids = Shown(panel)
	local all = select(2, NS:AllureList("all", ""))
	local locked
	for _, def in ipairs(NS.COMPANION_APPEARANCES) do if not NS:CompanionIsUnlocked("app", def) then locked = def; break end end
	local lockedAt, lastCapture = nil, nil
	for i, def in ipairs(all) do
		if def == locked then lockedAt = i end
		if def.captured then lastCapture = i end
	end
	local kodo, ours, oursS, gnoll, fire = Index(ids, "cap:7001"), Index(ids, "cap:7002"), Index(ids, "cap:7002:s"),
		Index(ids, "cap:7004"), Index(ids, "cap:7003")
	local s = Steps()
	s.ok("hors saison : pas de section Voile d'hiver", not panel.seasonTitle:IsShown() and not panel.seasonTiles[1]:IsShown()
		and not Index(ids, "winter:gfw"))
	s.ok("mascotte de départ en tête", ids[1] == NS.COMPANION_APPEARANCES[1].id, ids[1])
	s.ok("captures par type puis par nom", kodo and ours and gnoll and fire and kodo < ours and ours < gnoll and gnoll < fire,
		table.concat(ids, ","))
	s.ok("brillante à côté de la normale", oursS == ours + 1)
	s.ok("mascottes pas gagnées après les captures", lockedAt and lastCapture and lockedAt > lastCapture)
	s.ok("8 par rangée, tuiles construites une fois", #panel.tiles == NS.ALLURE_COLS * NS.ALLURE_ROWS_MAX
		and panel.tiles[8].lastPoint.y == panel.tiles[1].lastPoint.y and panel.tiles[9].lastPoint.y < panel.tiles[1].lastPoint.y)
	s.check("[ALLURE] grille : mascotte de départ, captures par type et par nom, brillante à côté, pas gagnées à la fin")
	local tKodo, tFire = TileOf(panel, "cap:7001"), TileOf(panel, "cap:7003")
	local before = #A.portraits
	NS:AllureRefresh()
	Check("[ALLURE] vignettes : portrait 2D du displayID appris, sinon l'icône du type ; pas repeintes au rafraîchissement",
		tKodo.portrait.portraitID == 1001 and tKodo.portrait.portraitKind == "portrait" and tKodo.model == nil
		and tFire.look == "icon" and tFire.portrait.texture == NS.MENAGERIE_TYPE_ICONS["Élémentaire"] and tFire.portrait:IsShown()
		and #A.portraits == before, tostring(tFire.look))
	s = Steps()
	panel.offset = 0
	NS:AllureRefresh()
	s.ok("assez pour défiler", math.ceil(#all / 8) > panel.rows)
	panel.grid.scripts.OnMouseWheel(panel.grid, -1)
	s.ok("une rangée plus loin", panel.offset == 1 and panel.tiles[1].def == all[9])
	for _ = 1, 20 do panel.grid.scripts.OnMouseWheel(panel.grid, -1) end
	s.ok("butée au bout", panel.offset == panel.maxOffset)
	panel.grid.scripts.OnMouseWheel(panel.grid, 30)
	s.ok("retour au début", panel.offset == 0)
	s.check("[ALLURE] molette : une rangée à la fois, butée au bout, retour au début")
	NS:AllureClose()
	A.on = true
	NS:WinterCompanionsForget()
	NS:AllureOpen()
	Check("[ALLURE] en saison : section « Voile d'hiver » en tête avec les trois compagnons, pas dans la grille",
		panel.seasonTitle:IsShown() and panel.seasonTiles[1].def.id == "winter:gfw" and panel.seasonTiles[1].seasonal
		and panel.seasonTiles[3].def.id == "winter:snowman" and panel.seasonTitle.lastPoint.y > panel.mineTitle.lastPoint.y
		and not Index(Shown(panel), "winter:gfw"))
	A.Done()
end

-- 3. Recherche et puces -----------------------------------------------------------------------------
do
	Say("-- allure : recherche et puces")
	A.Reset("sobre", true)
	local panel = Open()
	local s = Steps()
	Type(panel, "ELEM")
	s.ok("attend la fin de la frappe", #A.timers == 1 and Index(Shown(panel), "cap:7001") ~= nil)
	A.Fire()
	local ids = Shown(panel)
	s.ok("sans accents ni majuscules", #ids == 1 and ids[1] == "cap:7003", table.concat(ids, ","))
	s.ok("la saison filtrée aussi", not panel.seasonTitle:IsShown())
	Type(panel, "")
	s.ok("vidée : tout de suite", #A.timers == 0 and #Shown(panel) > 5 and panel.seasonTitle:IsShown())
	Type(panel, "noel")
	A.Fire()
	s.ok("rien : un mot", #Shown(panel) == 0 and panel.empty:IsShown() and panel.empty.text == NS.L.ALLURE_EMPTY)
	Type(panel, "")
	s.check("[ALLURE] recherche : après la frappe, sans accents ni majuscules, saison comprise, un mot si rien")
	local chips = panel.chips.byId
	s = Steps()
	s.ok("types présents seulement", chips.all:IsShown() and chips["t:beast"]:IsShown() and chips["t:humanoid"]:IsShown()
		and chips["t:elemental"]:IsShown() and not chips["t:undead"]:IsShown() and chips.shiny:IsShown() and chips.fav:IsShown())
	s.ok("libellés traduits", chips["t:beast"].text.text == NS.L.CTYPE_beast and chips.all.text.text == NS.L.ALLURE_ALL)
	chips["t:humanoid"]:Click()
	local only = Shown(panel)
	s.ok("Humanoïde : le gnoll seul", #only == 1 and only[1] == "cap:7004" and not panel.seasonTitle:IsShown(), table.concat(only, ","))
	chips.shiny:Click()
	only = Shown(panel)
	s.ok("Brillantes", #only == 1 and only[1] == "cap:7002:s")
	chips.fav:Click()
	s.ok("Favoris vides : l'aide", #Shown(panel) == 0 and panel.empty.text == NS.L.ALLURE_EMPTY_FAV)
	chips.all:Click()
	s.ok("Toutes", #Shown(panel) > 5 and panel.seasonTitle:IsShown())
	chips["t:humanoid"]:Click()
	NS:CaptureData().creatures[7004] = nil
	NS:CaptureData().serial = NS:CaptureData().serial + 1
	NS.captureAppCache = nil
	NS:AllureRefresh()
	s.ok("type disparu : retour à Toutes", panel.filter == "all" and not chips["t:humanoid"]:IsShown())
	s.check("[ALLURE] puces : Toutes, les types présents, Brillantes, Favoris ; type disparu : retour à Toutes")
	A.Done()
end

-- 4. Choisir : le chemin du carrousel, favoris, verrous, brillante -----------------------------------
do
	Say("-- allure : le choix")
	A.Reset("sobre", true)
	local panel = Open()
	local data = NS:CompanionData()
	local first = NS.COMPANION_APPEARANCES[1].id
	local s = Steps()
	s.ok("portée entourée d'or", TileOf(panel, first).worn and TileOf(panel, first).selected
		and TileOf(panel, first).ring.top.vertex[4] == 1 and TileOf(panel, "cap:7001").ring.top.vertex[4] == 0)
	TileOf(panel, "cap:7001"):Click()
	s.ok("clic : confirmation des effets d'abord", NS.effectsConfirm and NS.effectsConfirm:IsShown() and data.appearance == first)
	s.ok("confirmation au-dessus du panneau", NS.effectsConfirm.strata == NS.EFF_CONFIRM_STRATA
		and NS.EFF_CONFIRM_STRATA ~= NS.ALLURE_STRATA)
	NS:CompanionConfirmAnswer(true)
	local effects = NS:CompanionEffects()
	s.ok("« Emmener » : change, délai des effets reparti", data.appearance == "cap:7001" and effects.active == false
		and effects.remaining == NS.EFFECT_DELAY)
	s.ok("panneau ouvert, liseré déplacé, carte à jour", panel:IsShown() and TileOf(panel, "cap:7001").worn
		and not TileOf(panel, first).worn and NS.journalFrame.evo.lookName.text == "Kodo")
	s.check("[ALLURE] clic : confirmation des effets au-dessus du panneau, puis l'apparence change et le délai repart")
	-- brillante : la version choisie est gardée et rendue dorée
	s = Steps()
	TileOf(panel, "cap:7002:s"):Click()
	NS:CompanionConfirmAnswer(true)
	s.ok("« cap:<pnj>:s » gardé", data.appearance == "cap:7002:s" and NS:CompanionCurrentAppearance().shiny == true)
	local frame = NS.companionFrame
	local keep = frame and frame.model
	if frame then frame.model = CreateFrame("PlayerModel", nil, frame) end
	NS:CompanionApplyModel()
	s.ok("compagnon en lumière dorée", frame and frame.model.lightShiny == true)
	if frame then frame.model = keep end
	s.ok("carte « version brillante », modèle doré", NS.journalFrame.evo.lookName.text == NS:F("ALLURE_SHINY_OF", "Ourson")
		and NS.journalFrame.evo.lookCard.model.lightShiny == true)
	local tS, tN = TileOf(panel, "cap:7002:s"), TileOf(panel, "cap:7002")
	s.ok("vignette brillante : perle et teinte dorée, la normale sans", tS.gem:IsShown() and tS.portrait.vertex[2] == NS.Theme.SHINY[2]
		and not tN.gem:IsShown() and tN.portrait.vertex[2] == 1)
	TileOf(panel, "cap:7002"):Click()
	if NS.effectsConfirm:IsShown() then NS:CompanionConfirmAnswer(true) end
	s.ok("retour à la normale", data.appearance == "cap:7002" and not NS:CompanionCurrentAppearance().shiny)
	s.check("[ALLURE] version brillante : choisie et gardée, rendue dorée (compagnon, carte, vignette), retour possible")
	TileOf(panel, "winter:metzen"):Click()
	if NS.effectsConfirm:IsShown() then NS:CompanionConfirmAnswer(true) end
	Check("[ALLURE] compagnon de saison : même chemin, l'habituelle gardée, le liseré suit",
		NS:CompanionCurrentAppearance().id == "winter:metzen" and data.appearance == "cap:7002" and data.winter.pick == "metzen"
		and TileOf(panel, "winter:metzen").worn and not TileOf(panel, "cap:7002").worn)
	-- favoris : Maj+clic, gardés
	s = Steps()
	A.shift = true
	TileOf(panel, "cap:7003"):Click()
	A.shift = false
	s.ok("Maj+clic : favori sans choisir", data.allureFav["cap:7003"] == true
		and NS:CompanionCurrentAppearance().id == "winter:metzen" and TileOf(panel, "cap:7003").fav:IsShown())
	NS:AllureClose()
	NS:AllureOpen()
	panel.chips.byId.fav:Click()
	local favs = Shown(panel)
	s.ok("gardé, montré par la puce", #favs == 1 and favs[1] == "cap:7003")
	A.shift = true
	TileOf(panel, "cap:7003"):Click()
	A.shift = false
	s.ok("Maj+clic encore : retiré", data.allureFav["cap:7003"] == nil and #Shown(panel) == 0)
	panel.chips.byId.all:Click()
	s.check("[ALLURE] favoris : Maj+clic sans rien choisir, gardés d'une ouverture à l'autre, retirés de même")
	-- mascotte pas encore gagnée : grisée, pas choisissable, sa condition en infobulle
	local lockedDef
	for _, def in ipairs(NS.COMPANION_APPEARANCES) do if not NS:CompanionIsUnlocked("app", def) then lockedDef = def; break end end
	for _ = 1, 10 do
		if TileOf(panel, lockedDef.id) then break end
		NS:AllureScroll(1)
	end
	local tile = TileOf(panel, lockedDef.id)
	s = Steps()
	s.ok("grisée", tile and tile.locked and tile.portrait.desaturated ~= false and tile.portrait.alpha == NS.Theme.DIM_ALPHA)
	A.shift = true
	tile:Click()
	A.shift = false
	tile:Click()
	s.ok("ni choisie ni favorite", NS:CompanionCurrentAppearance().id == "winter:metzen" and not NS.effectsConfirm:IsShown()
		and data.allureFav[lockedDef.id] == nil)
	tile.scripts.OnEnter(tile)
	local text = table.concat(GameTooltip.lines or {}, " | ")
	s.ok("infobulle : sa condition", text:find(NS:F("ALLURE_TIP_LOCKED", NS:CompanionLockText(lockedDef)), 1, true) ~= nil, text)
	tile.scripts.OnLeave(tile)
	s.ok("id forcé refusé", NS:AllureChoose(lockedDef.id) == nil)
	s.check("[ALLURE] mascotte pas gagnée : grisée, ni choisie ni favorite, sa condition en infobulle")
	A.Done()
end

-- 5. Fermetures : Échap, croix, carnet fermé -------------------------------------------------------
do
	Say("-- allure : fermetures")
	A.Reset("sobre", false)
	local panel = Open()
	local s = Steps()
	panel.scripts.OnKeyDown(panel, "A")
	s.ok("autre touche : rien", panel:IsShown())
	panel.scripts.OnKeyDown(panel, "ESCAPE")
	s.ok("Échap : le panneau seul", not panel:IsShown() and NS.journalFrame:IsShown())
	NS:AllureOpen()
	panel.close:Click()
	s.ok("la croix", not panel:IsShown())
	NS:AllureOpen()
	s.ok("accroché à l'OnHide du carnet", NS.journalFrame.qcAllureHooked == true)
	NS:AllureOnJournalHide()
	s.ok("carnet fermé : panneau fermé", not panel:IsShown())
	s.ok("sans nom (hors d'UISpecialFrames)", panel:GetName() == nil)
	s.check("[ALLURE] fermetures : Échap ferme le panneau sans le carnet, la croix, le carnet qui se ferme")
	A.Done()
end

-- 6. Azeroth, changement de style, contrastes -------------------------------------------------------
do
	Say("-- allure : Azeroth")
	A.Reset("azeroth", true)
	local panel = Open()
	local tile = TileOf(panel, "cap:7001")
	local c = INK[NS.AZEROTH_CONTRAST["allure.name"][1]]
	Check("[ALLURE] Azeroth : parchemin bordé de bois, vignettes claires, puces et recherche habillées, encres des rôles allure.*",
		panel.uiStyle == "azeroth" and panel.azBg and panel.azDialog == true and #(NS.errors or {}) == 0
		and tile.azStyle == "light" and panel.chips.chips[1].azBg ~= nil and panel.searchBox.azSurface == "dark"
		and tile.label.azRole == "allure.name" and TileOf(panel, "cap:7002:s").label.azRole == "allure.shiny"
		and panel.mineTitle.label.azRole == "allure.section" and panel.pager.position.azRole == "allure.hint"
		and math.abs(tile.label.textColor[1] - c[1]) < 1e-6,
		tostring(panel.uiStyle) .. " " .. tostring(NS.errors and NS.errors[1] and NS.errors[1].message))
	local s = Steps()
	NS:DB().companionStyle = "sobre"
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:ApplyUIStyle()
	local fresh = NS.allurePanel
	s.ok("ouvert : rouvert en Sobre, l'ancien fermé", fresh ~= panel and fresh:IsShown() and fresh.uiStyle == "sobre"
		and not panel:IsShown() and fresh.lastPoint.relTo == NS.journalFrame)
	s.ok("Sobre : couleurs du socle", TileOf(fresh, "cap:7001").label.textColor[1] == NS.Theme.LABEL[1])
	NS:AllureClose()
	NS:DB().companionStyle = "azeroth"
	Mock.InstallAtlas(true)
	NS:AzerothAtlasOK(true)
	NS:ApplyUIStyle()
	s.ok("fermé : reste fermé", not NS:AllureShown())
	NS:AllureOpen()
	s.ok("chaque style garde son panneau", NS.allurePanel == panel and panel:IsShown())
	s.check("[ALLURE] changement de style : panneau ouvert rouvert dans l'autre habit, fermé reste fermé, pas reconstruit")
	A.Done()

	-- les rôles allure.* sont dans la table mesurée (seuils vérifiés par le garde des contrastes)
	local absent = {}
	for _, role in ipairs({ "allure.section", "allure.hint", "allure.text", "allure.name", "allure.locked", "allure.shiny" }) do
		if not NS.AZEROTH_CONTRAST[role] then absent[#absent + 1] = role end
	end
	-- Sobre : jetons du socle sur la tuile (ROW) et la fenêtre (WINDOW)
	local Th = NS.Theme
	for name, pair in pairs({ name = { Th.LABEL, Th.ROW }, locked = { Th.MUTED, Th.ROW }, shiny = { Th.GOLD_LIGHT, Th.ROW },
		section = { Th.MUTED_LIGHT, Th.WINDOW }, hint = { Th.MUTED, Th.WINDOW } }) do
		local ratio = Th.Contrast(pair[1], pair[2])
		if ratio < 4.5 then absent[#absent + 1] = "sobre " .. name .. string.format(" %.2f", ratio) end
	end
	Check("[ALLURE] contrastes : rôles allure.* dans la table mesurée ; Sobre 4,5:1 au moins (tuiles, fenêtre)", #absent == 0,
		table.concat(absent, ", "))
	local fr, en = NS.ALLURE_STRINGS.fr, NS.ALLURE_STRINGS.en
	local missing = {}
	for key in pairs(fr) do if en[key] == nil then missing[#missing + 1] = key end end
	for key in pairs(en) do if fr[key] == nil then missing[#missing + 1] = key end end
	Check("[ALLURE] textes FR/EN au complet", #missing == 0, table.concat(missing, ", "))
end

-- 7. Vignettes : la créature en 3D, l'apprentissage des displayID -------------------------------------
-- Un PlayerModel simulé qui sait charger une créature (SetCreature) et dire
-- son displayID (GetDisplayInfo) : tout de suite, ou après OnModelLoaded (A.lazy).
local DISPLAYS = { [7003] = 5003, [7004] = 5004 }
-- (bêta 6) ceux-là ne sont pas à apprendre : compagnons de saison, l'ourson
local MORE_DISPLAYS = { [7002] = 5002, [13444] = 13369, [15706] = 15904, [15710] = 15671 }
for n = 1, 12 do DISPLAYS[7100 + n] = 5100 + n end
local function InstallModels()
	A.models, A.lazy = {}, false
	A.createFrame = _G.CreateFrame
	_G.CreateFrame = function(kind, ...)
		local frame = A.createFrame(kind, ...)
		if kind == "PlayerModel" then
			A.models[#A.models + 1] = frame
			frame.loads = 0
			-- A.miss[id] : pas encore dans le cache du client (rien de chargé, une
			-- fois) ; A.never[id] : jamais
			function frame:SetCreature(id)
				local cold = (A.miss and A.miss[id]) or (A.never and A.never[id])
				if A.miss then A.miss[id] = nil end
				self.creature, self.display, self.loaded = id, nil, not A.lazy and not cold
				self.loads = self.loads + 1
			end
			function frame:SetDisplayInfo(id) self.display, self.creature, self.loaded = id, nil, true; self.loads = self.loads + 1 end
			function frame:GetDisplayInfo()
				if not self.loaded then return 0 end
				return self.display or DISPLAYS[self.creature or -1] or MORE_DISPLAYS[self.creature or -1] or 0
			end
			function frame:ClearModel() self.creature, self.display, self.loaded = nil, nil, false end
			function frame:SetCamDistanceScale(v) self.cam = v end
			function frame:SetPosition(_, _, z) self.posZ = z end
			function frame:SetPortraitZoom(v) self.zoom = v end
		end
		return frame
	end
	NS.modelLearnCreatureProbe, NS.modelLearnCreatureAt, NS.modelLearnPending = nil, nil, nil
end
local function UninstallModels()
	_G.CreateFrame = A.createFrame
	NS:ModelLearnStop()
	NS.modelLearnCreatureProbe, NS.modelLearnCreatureAt, NS.modelLearnPending = nil, nil, nil
end
local function GridModels(panel)
	local n = 0
	for _, tile in ipairs(panel.tiles) do if tile.model then n = n + 1 end end
	return n
end

do
	Say("-- allure : une vignette par créature")
	A.Reset("sobre", true)
	InstallModels()
	local panel = Open()
	local probe = NS.modelLearnCreatureProbe
	local tKodo = TileOf(panel, "cap:7001")
	-- la première espèce sans displayID a pu l'apprendre à l'ouverture : on regarde les suivantes
	local creatures, distinct, models, portraitsOnly = {}, 0, 0, true
	for _, tile in ipairs(panel.tiles) do
		local def = tile.def
		if def and def.captured and tile:IsShown() and tile.look == "model" then
			models = models + 1
			local npc = tile.model.creature
			if npc == def.npc and not creatures[npc] then creatures[npc] = true; distinct = distinct + 1 end
			if tile.portrait:IsShown() or not tile.model:IsShown() then portraitsOnly = false end
		end
	end
	local tFire = TileOf(panel, "cap:7003")
	Check("[ALLURE] vignettes : portrait 2D si displayID connu, sinon sa créature en 3D (une par tuile), cadrée comme le "
		.. "compagnon, sans souris", tKodo.look == "portrait" and tKodo.model == nil and tKodo.portrait:IsShown()
		and models >= 10 and distinct == models and portraitsOnly and tFire.look == "model"
		and math.abs(tFire.model.cam - NS.COMPANION_MODEL_TYPE_CAM["Élémentaire"]) < 1e-9 and tFire.model.zoom == 0
		and tFire.model.mouseEnabled == false, models .. " / " .. distinct)

	-- Metzen en 3D (/qc noel metzen 3d) : le modèle du Renne de l'Hiver (15706)
	local print0 = NS.Print
	local printed = {}
	NS.Print = function(_, text) printed[#printed + 1] = text end
	NS:WinterVeilCommand("metzen 3d")
	local s = Steps()
	local tMetzen = TileOf(panel, "winter:metzen")
	s.ok("vignette : Renne de l'Hiver", tMetzen.look == "model" and tMetzen.model.creature == NS.WINTER_METZEN_LOOK
		and NS.WINTER_METZEN_LOOK == 15706 and tMetzen.model:IsShown() and tMetzen.model.cam == NS.WINTER_METZEN_CAM)
	s.ok("même distance pour le cadre du compagnon", NS:CompanionModelCam({ npc = 15664 }, "pied") == NS.WINTER_METZEN_CAM
		and NS.COMPANION_MODEL_OVERRIDES[15664].cam == NS.WINTER_METZEN_CAM and NS.MODEL_NPC_LOOK[15664] == 15706)
	NS:WinterVeilCommand("metzen 2,5 15664")
	NS:AllureRefresh()
	local tuned = TileOf(panel, "winter:metzen")
	s.ok("/qc noel metzen 2,5 15664 : réglé, vignette rechargée", NS.WINTER_METZEN_CAM == 2.5 and tuned.model.creature == 15664
		and tuned.model.cam == 2.5 and NS:CompanionModelCam({ npc = 15664 }, "pied") == 2.5)
	NS:WinterVeilCommand("metzen 1 15706")
	NS:AllureRefresh()
	s.ok("/qc noel metzen 1 15706 : retour", TileOf(panel, "winter:metzen").model.creature == 15706 and NS.WINTER_METZEN_CAM == 1)
	s.check("[ALLURE] Metzen en 3D : le Renne de l'Hiver, même distance vignette et compagnon, réglable en jeu (/qc noel metzen)")
	-- bêta 5 : un displayID appris pour 15664 (le grand Metzen) ne passe pas devant
	do
		local account = NS:CaptureAccount()
		account.display = type(account.display) == "table" and account.display or {}
		account.display[15664] = 15902
		local tile = TileOf(panel, "winter:metzen")
		local model = tile.model
		local calls = {}
		local function Spy(name)
			local base = model[name]
			model[name] = function(m, ...)
				calls[#calls + 1] = { name = name, args = { ... } }
				return base(m, ...)
			end
		end
		for _, name in ipairs({ "SetCreature", "SetDisplayInfo", "SetCamDistanceScale" }) do Spy(name) end
		tile.lookKey, model.modelKey, model.modelShown = nil, nil, nil
		NS:AllureRefresh()
		local seen = {}
		for _, call in ipairs(calls) do seen[call.name] = seen[call.name] or call.args end
		model.cam = nil
		local loaded = model.hooks and model.hooks.OnModelLoaded
		if loaded then loaded(model) end
		Check("[ALLURE] Metzen : SetCreature(15706), jamais un displayID (ni 15902 appris), caméra reposée au chargement",
			seen.SetCreature and seen.SetCreature[1] == 15706 and seen.SetDisplayInfo == nil and model.display == nil
			and seen.SetCamDistanceScale and seen.SetCamDistanceScale[1] == NS.WINTER_METZEN_CAM and tile.look == "model"
			and not tile.portrait:IsShown() and loaded ~= nil and model.cam == NS.WINTER_METZEN_CAM,
			tostring(seen.SetCreature and seen.SetCreature[1]))
		printed = {}
		NS:WinterVeilCommand("metzen diag")
		local diagTile = #printed == 3 and printed[1]:find("15706", 1, true) ~= nil
			and printed[2]:find(NS.L.WINTER_METZEN_DIAG_TILE, 1, true) ~= nil and printed[2]:find("pnj 15706", 1, true) ~= nil
			and printed[3]:find(NS.L.WINTER_METZEN_DIAG_COMP, 1, true) ~= nil
		-- le cadre du compagnon qui porte Metzen : les mêmes appels
		if NS.companionFrame then NS.companionFrame:Hide() end
		NS.companionFrame = nil
		local frame = NS:EnsureCompanionFrame()
		local cm = frame and frame.model
		NS:CompanionSetAppearance("winter:metzen")
		printed = {}
		NS:WinterMetzenDiag()
		Check("[ALLURE] Metzen porté : cadre du compagnon par SetCreature(15706), sans display ni repli ; /qc noel metzen diag "
			.. "décrit vignette et cadre", diagTile and cm and cm.creature == 15706 and cm.display == nil and cm.cam
			and cm.cam <= 1 and not frame.usesFallback and printed[3] ~= nil and printed[3]:find("pnj 15706", 1, true) ~= nil,
			tostring(cm and cm.creature) .. " / " .. tostring(cm and cm.cam))
		account.display[15664] = nil
		if NS.companionFrame then NS.companionFrame:Hide() end
		NS.companionFrame = nil
	end
	NS:WinterVeilCommand("metzen 2d")
	NS.Print = print0
	-- la mise en réserve : un modèle par tuile au plus, réutilisé au défilement
	local before = #A.models
	local visible = panel.rows * NS.ALLURE_COLS
	local first = panel.tiles[1]
	local firstModel = first.model
	s = Steps()
	s.ok("seulement les tuiles visibles", GridModels(panel) <= visible)
	for _ = 1, 5 do NS:AllureScroll(1) end
	for _ = 1, 5 do NS:AllureScroll(-1) end
	NS:AllureScroll(1)
	s.ok("réutilisés au défilement", #A.models - before <= visible and (firstModel == nil or first.model == firstModel))
	local made = #A.models
	for _ = 1, 3 do NS:AllureScroll(1); NS:AllureScroll(-1) end
	s.ok("aller-retour : aucun de plus", #A.models == made)
	NS:AllureScroll(-10)
	s.check("[ALLURE] modèles des vignettes : seulement les visibles, réutilisés au défilement, jamais recréés")

	-- l'apprentissage des displayID : en fond, les visibles d'abord
	local account = NS:CaptureAccount()
	s = Steps()
	s.ok("sonde à part, invisible", probe ~= nil and probe ~= NS.modelLearnProbe and probe.alpha == 0)
	local learnedFirst = probe.creature
	s.ok("première lecture tout de suite", learnedFirst ~= nil and account.display[learnedFirst] == DISPLAYS[learnedFirst])
	local queued = #NS:ModelLearnQueue()
	local loads = probe.loads
	NS:ModelLearnPump()
	s.ok("une lecture par intervalle", probe.loads == loads and #NS:ModelLearnQueue() == queued)
	Mock.now = Mock.now + NS.MODEL_LEARN_CREATURE_GAP
	A.fight = true
	_G.InCombatLockdown = function() return A.fight end
	local timers = #A.timers
	NS:ModelLearnPump()
	s.ok("jamais en combat (reprise plus tard)", probe.loads == loads and NS.modelLearnPending == true and #A.timers == timers + 1)
	A.fight = false
	A.lazy = true
	local npc = NS:ModelLearnPump()
	s.ok("hors combat : la suivante", npc ~= nil and probe.loads == loads + 1 and #NS:ModelLearnQueue() == queued - 1)
	s.ok("pas encore chargée : rien gardé", account.display[npc] == nil)
	probe.loaded = true
	probe.scripts.OnModelLoaded(probe)
	s.ok("chargée : gardée au compte", account.display[npc] == DISPLAYS[npc])
	A.lazy = false
	for _ = 1, 40 do
		Mock.now = Mock.now + NS.MODEL_LEARN_CREATURE_GAP
		A.Fire()
	end
	local all = true
	for id in pairs(DISPLAYS) do if account.display[id] ~= DISPLAYS[id] then all = false end end
	s.ok("toutes apprises, file vide", all and #NS:ModelLearnQueue() == 0)
	NS:AllureClose()
	NS:AllureOpen()
	local tZebra = TileOf(panel, "cap:7101")
	s.ok("la fois suivante : portrait 2D", tZebra.look == "portrait" and tZebra.portrait.portraitID == 5101
		and (tZebra.model == nil or not tZebra.model:IsShown()))
	NS:CaptureAccount().display[7112] = nil
	NS:AllureRefresh()
	NS:AllureClose()
	s.ok("panneau fermé : file arrêtée", #NS:ModelLearnQueue() == 0)
	s.check("[ALLURE] apprentissage des displayID : sonde à part, une lecture par intervalle, jamais en combat, gardé "
		.. "une fois chargé, portrait 2D la fois suivante, arrêté à la fermeture")
	UninstallModels()
	A.Done()
end

-- 7 bis. Bêta 6 (4.png) : changer d'allure vers une créature pas encore en cache --------------------------
-- (Grand-père Hiver jamais croisé) : SetCreature ne dessine rien ; le cadre
-- restait vide jusqu'au /reload. Un nouvel essai, une fois.
do
	Say("-- allure : modèle resté vide au changement, un nouvel essai")
	A.Reset("azeroth", true)
	InstallModels()
	NS:CaptureAccount().display = {}
	if NS.companionFrame then NS.companionFrame:Hide() end
	NS.companionFrame = nil
	local frame = NS:EnsureCompanionFrame()
	local cm = frame and frame.model
	local s = Steps()
	local cases = { { "winter:gfw", 13444 }, { "winter:metzen", 15706 }, { "winter:snowman", 15710 }, { "cap:7003", 7003 },
		{ "cap:7002:s", 7002 } }
	for _, case in ipairs(cases) do
		local id, npc = case[1], case[2]
		A.miss = { [npc] = true }
		A.timers = {}
		local loads = cm.loads
		local done = NS:CompanionSetAppearance(id)
		local empty = done and cm.creature == npc and not cm.loaded and NS.ModelEmpty(cm) and #A.timers == 1
		A.Fire()
		s.ok(id .. " : vide au choix, rechargé à l'essai suivant", empty and cm.loaded and cm.creature == npc
			and cm.loads == loads + 2 and not frame.usesFallback and not NS.ModelEmpty(cm) and #A.timers == 0,
			tostring(empty) .. " " .. tostring(cm.loaded) .. " " .. (cm.loads - loads))
	end
	-- le rafraîchissement d'après la confirmation, avant l'essai : il recharge, une fois
	NS:CompanionSetAppearance("cap:7004")
	A.miss = { [13444] = true }
	A.timers = {}
	NS:CompanionSetAppearance("winter:gfw")
	local loads = cm.loads
	NS:CompanionApplyModel()
	A.Fire()
	s.ok("rafraîchi avant l'essai : rechargé, sans second essai", cm.loaded and cm.loads == loads + 1 and #A.timers == 0)
	-- chargé : rien de plus au rafraîchissement
	loads = cm.loads
	NS:CompanionApplyModel(); NS:CompanionApplyModel()
	s.ok("chargé : pas rechargé", cm.loads == loads)
	-- jamais chargé : un seul essai, pas de boucle
	NS:CompanionSetAppearance("cap:7004")
	A.never = { [15710] = true }
	A.timers = {}
	NS:CompanionSetAppearance("winter:snowman")
	loads = cm.loads
	A.Fire(); A.Fire()
	NS:CompanionApplyModel(); NS:CompanionApplyModel()
	s.ok("jamais chargé : un seul essai", cm.loads == loads + 1 and #A.timers == 0, cm.loads - loads)
	A.never = nil
	-- OnModelLoaded : chargé, même si GetDisplayInfo dit encore 0
	NS:CompanionSetAppearance("cap:7004")
	A.lazy, A.timers = true, {}
	NS:CompanionSetAppearance("winter:gfw")
	local hook = cm.hooks and cm.hooks.OnModelLoaded
	if hook then hook(cm) end
	s.ok("OnModelLoaded : prêt, pas d'essai", hook ~= nil and cm.modelReady and not NS.ModelEmpty(cm))
	A.Fire()
	A.lazy = false
	s.ok("aucune erreur", next(NS.errors or {}) == nil, next(NS.errors or {}))
	s.check("[ALLURE] changer d'allure (saison, ordinaire, brillante) vers une créature pas en cache : le modèle est "
		.. "rechargé une fois (essai différé ou rafraîchissement suivant), jamais en boucle ; OnModelLoaded = prêt")
	A.miss = nil
	if NS.companionFrame then NS.companionFrame:Hide() end
	NS.companionFrame = nil
	UninstallModels()
	A.Done()
end

-- 8. Des noms, pas des numéros (bêta 4, 23.png : « 3632 ») ---------------------------------------------
do
	Say("-- allure : le nom d'une créature capturée sans nom gardé")
	local savedZones = rawget(NS, "ZONE_CREATURES")
	NS.ZONE_CREATURES = NS.LazyZones({ [1413] = function()
		return { [3632] = { lvl = { 15, 16 }, rank = 1, fr = "Rampant déviant", en = "Deviate Creeper" } }
	end })
	NS.CreatureNameForget()
	A.Reset("azeroth")
	local capture = NS:CaptureData()
	capture.creatures[3632] = { name = "3632", class = "elite", type = "Bête", normal = true, at = 30 }
	capture.creatures[9999] = { class = "normal", type = "Bête", normal = true, at = 31 }
	capture.count, capture.serial = capture.count + 2, capture.serial + 1
	NS.captureAppCache = nil
	-- le carnet connaît 9999 sous son nom (une autre zone)
	NS:BestiaryData()[1411] = { [9999] = { name = "Sanglier du carnet", seen = true, killed = 1 } }
	local static = { ["Rampant déviant"] = true, ["Deviate Creeper"] = true }
	Check("[ALLURE] CreatureName : le carnet d'abord, puis la table livrée (toutes zones), un vrai nom reste, le numéro en dernier",
		static[NS:CreatureName(3632, { name = "3632" })] == true and NS:CreatureName(9999, {}) == "Sanglier du carnet"
		and NS:CreatureName(3632, { name = "Rampant" }) == "Rampant" and NS:CreatureName(123456, {}) == "123456")
	local panel = Open()
	local tile = TileOf(panel, "cap:3632")
	if not tile then
		Type(panel, "deviant")
		tile = TileOf(panel, "cap:3632")
	end
	if not tile then
		Type(panel, "creeper")
		tile = TileOf(panel, "cap:3632")
	end
	local label = tile and tile.label:GetText()
	local meta = tile and NS:AllureMeta(tile.def)
	NS:CompanionData().appearance = "cap:3632"
	NS.menagerieStatic = nil
	local found
	for _, item in ipairs(NS:MenagerieList({}) or {}) do if item.npc == 3632 then found = item.name end end
	local s = Steps()
	s.ok("vignette", label ~= nil and static[label] == true, label)
	s.ok("fiche de capture", static[capture.creatures[3632].name] == true and capture.creatures[9999].name == "Sanglier du carnet")
	s.ok("infobulle", meta ~= nil and static[meta.name] == true)
	s.ok("plaque du compagnon", static[NS:CompanionName()] == true, NS:CompanionName())
	s.ok("page Créatures", static[found] == true, found)
	s.check("[ALLURE] une capture sans nom gardé : son nom partout (vignette, fiche, infobulle, plaque, page Créatures), pas « 3632 »")
	NS:BestiaryData()[1411] = nil
	A.Done()
	NS.ZONE_CREATURES = savedZones
	NS.CreatureNameForget()
	NS.menagerieStatic = nil
end

-- 9. Portraits 2D des compagnons de saison (bêta 6, 30.png : Metzen minuscule, coupé) ---------------
do
	Say("-- allure : portraits 2D des compagnons de saison")
	A.Reset("azeroth", true)
	InstallModels()
	local print0 = NS.Print
	NS.Print = function() end
	local panel, evo = Open()
	local tM, tG, tS = TileOf(panel, "winter:metzen"), TileOf(panel, "winter:gfw"), TileOf(panel, "winter:snowman")
	tM:Click()
	if NS.effectsConfirm and NS.effectsConfirm:IsShown() then NS:CompanionConfirmAnswer(true) end
	NS:AllureRefreshCard(evo)
	local card = evo.lookCard
	Check("[ALLURE] compagnons de saison en portrait 2D (Metzen 15904, Grand-père Hiver 13369, bonhomme 15671), "
		.. "à la taille de la grille, modèle caché ; la carte « Son allure » aussi",
		tM and tM.look == "portrait" and tM.portrait.portraitID == 15904 and tM.portrait:IsShown()
		and not (tM.model and tM.model:IsShown()) and NS.WINTER_PORTRAIT_DISPLAY[15664] == 15904
		and tM.portrait:GetWidth() == NS.ALLURE_PORTRAIT and tG.look == "portrait" and tG.portrait.portraitID == 13369
		and tS.look == "portrait" and tS.portrait.portraitID == 15671
		and NS:CompanionCurrentAppearance().id == "winter:metzen" and card.look == "portrait" and card.portrait:IsShown()
		and card.portrait.portraitID == 15904 and not card.model:IsShown(),
		tostring(tM and tM.look) .. " / " .. tostring(tM and tM.portrait.portraitID))
	local s = Steps()
	NS:WinterVeilCommand("metzen 2d 15902")
	NS:AllureRefreshCard(evo)
	s.ok("/qc noel metzen 2d 15902 : vignette et carte rechargées", TileOf(panel, "winter:metzen").portrait.portraitID == 15902
		and card.portrait.portraitID == 15902)
	NS:WinterVeilCommand("metzen 2d 15904")
	_G.SetPortraitTextureFromCreatureDisplayID = function() error("portrait refusé") end
	for _, tile in ipairs(panel.seasonTiles) do tile.lookKey = nil end
	NS:AllureRefresh()
	tM = TileOf(panel, "winter:metzen")
	NS:AllureRefreshCard(evo)
	s.ok("portrait refusé : modèle 3D (vignette et carte)", tM.look == "model" and tM.model:IsShown() and tM.model.creature == 15706
		and not tM.portrait:IsShown() and card.look == "model" and not card.portrait:IsShown())
	_G.SetPortraitTextureFromCreatureDisplayID = nil
	NS:AllureRefresh()
	NS:AllureRefreshCard(evo)
	s.ok("client sans portrait 2D : modèle 3D", TileOf(panel, "winter:metzen").look == "model" and card.look == "model")
	_G.SetPortraitTextureFromCreatureDisplayID = function(tex, id) tex.portraitID = id end
	NS:WinterVeilCommand("metzen 3d")
	s.ok("/qc noel metzen 3d", TileOf(panel, "winter:metzen").look == "model" and NS:WinterPortraitDisplay(15664) == nil)
	NS:WinterVeilCommand("metzen 2d")
	s.ok("/qc noel metzen 2d", TileOf(panel, "winter:metzen").look == "portrait" and NS.WINTER_PORTRAITS_ON == true)
	local lines = NS:WinterMetzenDiag()
	s.ok("diag : ce que montrent les vignettes", lines[1]:find("15904", 1, true) ~= nil, lines[1])
	s.ok("textes du réglage", NS.L.WINTER_METZEN_LOOK ~= nil and NS.L.WINTER_METZEN_2D ~= nil and NS.L.WINTER_METZEN_3D ~= nil)
	s.check("[ALLURE] portraits de saison : réglables (/qc noel metzen 2d/3d), repli en 3D si le client refuse ou n'a pas le portrait")
	do local account = NS:CaptureAccount(); account.display[13444], account.display[15710] = nil, nil end
	NS.Print = print0
	UninstallModels()
	A.Done()
end
