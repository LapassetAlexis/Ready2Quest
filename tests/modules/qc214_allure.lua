-- QC 2.14.0 : choisir l'allure du compagnon (CompanionAllure.lua). La page
-- Compagnon montre l'allure portée et « Choisir… » (plus de carrousel) ; le
-- panneau : recherche, puces, section « Voile d'hiver » en saison, grille à
-- la molette, clic = le chemin de l'ancien carrousel (confirmation des
-- effets, délai), Maj+clic = favori, mascottes pas gagnées grisées, version
-- brillante au choix, deux habits (Sobre, Azeroth), Échap, encres mesurées.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local A = { saved = {} }
local GLOBALS = { "IsShiftKeyDown", "C_Timer", "SetPortraitTextureFromCreatureDisplayID", "InCombatLockdown",
	"UnitAffectingCombat", "UnitLevel" }
for _, name in ipairs(GLOBALS) do A.saved[name] = rawget(_G, name) end
A.season, A.choice = NS.WinterVeilSeason, NS.WinterVeilChoice
local FIELDS = { "journalFrame", "effectsConfirm", "allurePanel" }
local INK = NS.AZEROTH_INK

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
	Say("-- 2.14.0 : choisir son allure, la page")
	A.Reset("sobre", false)
	NS:ToggleJournal(true)
	NS:SelectJournalKind("evolution")
	local evo = NS.journalFrame.evo
	Check("[ALLURE] plus de carrousel (ni vignettes ni chevrons)", evo.looks == nil and evo.lookPrev == nil
		and evo.lookNext == nil and NS.CompanionLooksScroll == nil)
	Check("[ALLURE] carte : nom de l'allure portée et bouton « Choisir… »", evo.lookCard and evo.lookChoose
		and evo.lookName.text == NS.L[NS.COMPANION_APPEARANCES[1].label] and evo.lookChoose.text.text == NS.L.ALLURE_CHOOSE,
		tostring(evo.lookName.text))
	Check("[ALLURE] carte : ce qu'elle est et combien à choisir", evo.lookDetail.text:find(NS.L.ALLURE_MASCOT, 1, true)
		and evo.lookDetail.text:find(NS:F("ALLURE_CARD_COUNT", #NS:CompanionUnlockedAppearances()), 1, true), evo.lookDetail.text)
	Check("[ALLURE] titre : « Son allure (N apparences) » gardé", evo.looksTitle.raw:find(NS.L.JRN_EVO_LOOKS, 1, true) == 1)
	evo.lookChoose:Click()
	local panel = NS.allurePanel
	Check("[ALLURE] le bouton ouvre le panneau, posé sur le carnet, au-dessus", panel and panel:IsShown()
		and panel.strata == NS.ALLURE_STRATA and panel.lastPoint.relTo == NS.journalFrame
		and panel.level == NS.journalFrame.level + NS.ALLURE_LEVEL_UP)
	Check("[ALLURE] Sobre : panneau du socle", panel.uiStyle == "sobre" and not panel.azBg)
	A.Done()
end

-- 2. Grille, ordre, saison --------------------------------------------------------------------------
do
	Say("-- 2.14.0 : choisir son allure, la grille")
	A.Reset("sobre", false)
	local panel = Open()
	local ids = Shown(panel)
	Check("[ALLURE] hors saison : pas de section Voile d'hiver", not panel.seasonTitle:IsShown()
		and not panel.seasonTiles[1]:IsShown() and not Index(ids, "winter:gfw"))
	Check("[ALLURE] la mascotte de départ en tête", ids[1] == NS.COMPANION_APPEARANCES[1].id, ids[1])
	local kodo, ours, oursS, gnoll, fire = Index(ids, "cap:7001"), Index(ids, "cap:7002"), Index(ids, "cap:7002:s"),
		Index(ids, "cap:7004"), Index(ids, "cap:7003")
	Check("[ALLURE] captures : par type (bête, humanoïde, élémentaire) puis par nom", kodo and ours and gnoll and fire
		and kodo < ours and ours < gnoll and gnoll < fire, table.concat(ids, ","))
	Check("[ALLURE] brillante : juste à côté de la normale", oursS == ours + 1)
	Check("[ALLURE] 8 vignettes par rangée", panel.tiles[9].lastPoint.y == panel.tiles[1].lastPoint.y - NS.ALLURE_TILE_H - NS.ALLURE_GAP
		and panel.tiles[8].lastPoint.y == panel.tiles[1].lastPoint.y)
	-- mascottes pas encore gagnées : en fin de liste, grisées
	local locked
	for _, def in ipairs(NS.COMPANION_APPEARANCES) do if not NS:CompanionIsUnlocked("app", def) then locked = def; break end end
	local all = select(2, NS:AllureList("all", ""))
	local lockedAt, lastCapture = nil, nil
	for i, def in ipairs(all) do
		if def == locked then lockedAt = i end
		if def.captured then lastCapture = i end
	end
	Check("[ALLURE] mascottes pas gagnées : après les captures", lockedAt and lastCapture and lockedAt > lastCapture)
	-- portraits 2D, pas de modèles 3D dans la grille
	local models = 0
	for _, tile in ipairs(panel.tiles) do if tile.model then models = models + 1 end end
	Check("[ALLURE] grille : portraits 2D (aucun modèle 3D)", models == 0 and #panel.tiles == NS.ALLURE_COLS * NS.ALLURE_ROWS_MAX)
	local tKodo = TileOf(panel, "cap:7001")
	Check("[ALLURE] portrait 2D : le displayID appris de l'espèce", tKodo.portrait.portraitID == 1001 and tKodo.portrait.portraitKind == "portrait")
	local before = #A.portraits
	NS:AllureRefresh()
	Check("[ALLURE] rafraîchir : portraits pas repeints", #A.portraits == before)
	-- molette : une rangée de plus, puis butée
	panel.offset = 0
	NS:AllureRefresh()
	local rows = panel.rows
	local total = #all
	Check("[ALLURE] assez d'apparences pour défiler", math.ceil(total / 8) > rows, total .. " / " .. rows)
	panel.grid.scripts.OnMouseWheel(panel.grid, -1)
	Check("[ALLURE] molette vers le bas : une rangée plus loin", panel.offset == 1 and panel.tiles[1].def == all[9])
	for _ = 1, 20 do panel.grid.scripts.OnMouseWheel(panel.grid, -1) end
	Check("[ALLURE] molette : butée au bout", panel.offset == panel.maxOffset)
	panel.grid.scripts.OnMouseWheel(panel.grid, 30)
	Check("[ALLURE] molette vers le haut : retour au début", panel.offset == 0)
	-- en saison : la section en tête
	NS:AllureClose()
	A.on = true
	NS:WinterCompanionsForget()
	NS:AllureOpen()
	Check("[ALLURE] en saison : « Voile d'hiver » en tête, les trois compagnons", panel.seasonTitle:IsShown()
		and panel.seasonTiles[1].def.id == "winter:gfw" and panel.seasonTiles[3].def.id == "winter:snowman"
		and select(2, panel.seasonTitle:GetPoint()) == panel and panel.seasonTitle.lastPoint.y > panel.mineTitle.lastPoint.y)
	Check("[ALLURE] en saison : pas dans la grille (seulement en tête)", not Index(Shown(panel), "winter:gfw"))
	Check("[ALLURE] saison : petits modèles 3D (trois seulement)", panel.seasonTiles[1].model ~= nil
		and panel.seasonTiles[1].model.modelKey ~= nil)
	A.Done()
end

-- 3. Recherche et puces -----------------------------------------------------------------------------
do
	Say("-- 2.14.0 : choisir son allure, recherche et puces")
	A.Reset("sobre", true)
	local panel = Open()
	Type(panel, "ELEM")
	Check("[ALLURE] recherche : attend la fin de la frappe", #A.timers == 1 and Index(Shown(panel), "cap:7001") ~= nil)
	A.Fire()
	local ids = Shown(panel)
	Check("[ALLURE] recherche : sans accents ni majuscules", #ids == 1 and ids[1] == "cap:7003", table.concat(ids, ","))
	Check("[ALLURE] recherche : la saison filtrée aussi", not panel.seasonTitle:IsShown())
	Type(panel, "")
	Check("[ALLURE] recherche vidée : tout de suite", #A.timers == 0 and #Shown(panel) > 5 and panel.seasonTitle:IsShown())
	Type(panel, "noel")
	A.Fire()
	Check("[ALLURE] rien ne correspond : un mot", #Shown(panel) == 0 and panel.empty:IsShown()
		and panel.empty.text == NS.L.ALLURE_EMPTY)
	Type(panel, "")
	-- puces : seulement les types présents
	local chips = panel.chips.byId
	Check("[ALLURE] puces : Toutes, les types présents, Brillantes, Favoris", chips.all:IsShown() and chips["t:beast"]:IsShown()
		and chips["t:humanoid"]:IsShown() and chips["t:elemental"]:IsShown() and not chips["t:undead"]:IsShown()
		and not chips["t:giant"]:IsShown() and chips.shiny:IsShown() and chips.fav:IsShown())
	Check("[ALLURE] puces : libellés traduits", chips["t:beast"].text.text == NS.L.CTYPE_beast and chips.all.text.text == NS.L.ALLURE_ALL)
	chips["t:humanoid"]:Click()
	local only = Shown(panel)
	Check("[ALLURE] puce Humanoïde : le gnoll seul, pas la saison", #only == 1 and only[1] == "cap:7004"
		and not panel.seasonTitle:IsShown(), table.concat(only, ","))
	chips.shiny:Click()
	only = Shown(panel)
	Check("[ALLURE] puce Brillantes : la version brillante seule", #only == 1 and only[1] == "cap:7002:s")
	chips.fav:Click()
	Check("[ALLURE] puce Favoris, aucun : l'aide (Maj+clic)", #Shown(panel) == 0 and panel.empty.text == NS.L.ALLURE_EMPTY_FAV)
	chips.all:Click()
	Check("[ALLURE] puce Toutes : tout revient", #Shown(panel) > 5 and panel.seasonTitle:IsShown())
	-- un type qui disparaît (capture relâchée) : retour à Toutes
	chips["t:humanoid"]:Click()
	NS:CaptureData().creatures[7004] = nil
	NS:CaptureData().serial = NS:CaptureData().serial + 1
	NS.captureAppCache = nil
	NS:AllureRefresh()
	Check("[ALLURE] type disparu : retour à Toutes", panel.filter == "all" and not chips["t:humanoid"]:IsShown())
	A.Done()
end

-- 4. Choisir : le chemin du carrousel, favoris, verrous, brillante -----------------------------------
do
	Say("-- 2.14.0 : choisir son allure, le choix")
	A.Reset("sobre", true)
	local panel = Open()
	local data = NS:CompanionData()
	local first = NS.COMPANION_APPEARANCES[1].id
	Check("[ALLURE] l'allure portée : entourée d'or", TileOf(panel, first).worn and TileOf(panel, first).selected
		and TileOf(panel, first).ring.top.vertex[4] == 1 and TileOf(panel, "cap:7001").ring.top.vertex[4] == 0)
	TileOf(panel, "cap:7001"):Click()
	Check("[ALLURE] clic : la confirmation qui compare les effets d'abord", NS.effectsConfirm and NS.effectsConfirm:IsShown()
		and data.appearance == first)
	Check("[ALLURE] confirmation au-dessus du panneau", NS.effectsConfirm.strata == NS.EFF_CONFIRM_STRATA
		and NS.EFF_CONFIRM_STRATA ~= NS.ALLURE_STRATA)
	NS:CompanionConfirmAnswer(true)
	local effects = NS:CompanionEffects()
	Check("[ALLURE] « Emmener » : l'apparence change, le délai des effets repart", data.appearance == "cap:7001"
		and effects.active == false and effects.remaining == NS.EFFECT_DELAY)
	Check("[ALLURE] panneau resté ouvert, liseré déplacé", panel:IsShown() and TileOf(panel, "cap:7001").worn
		and not TileOf(panel, first).worn)
	Check("[ALLURE] carte de la page à jour", NS.journalFrame.evo.lookName.text == "Kodo")
	-- brillante : la version choisie est gardée et rendue dorée
	TileOf(panel, "cap:7002:s"):Click()
	NS:CompanionConfirmAnswer(true)
	local cur = NS:CompanionCurrentAppearance()
	Check("[ALLURE] brillante choisie : « cap:<pnj>:s » gardé", data.appearance == "cap:7002:s" and cur.shiny == true)
	-- le cadre du compagnon (sans modèle dans les tests : un modèle de test)
	local frame = NS.companionFrame
	local keep = frame and frame.model
	if frame then frame.model = CreateFrame("PlayerModel", nil, frame) end
	NS:CompanionApplyModel()
	Check("[ALLURE] brillante : le compagnon prend la lumière dorée", frame and frame.model.lightShiny == true)
	if frame then frame.model = keep end
	Check("[ALLURE] brillante : carte « …, version brillante », modèle doré",
		NS.journalFrame.evo.lookName.text == NS:F("ALLURE_SHINY_OF", "Ourson")
		and NS.journalFrame.evo.lookCard.model.lightShiny == true)
	local tS, tN = TileOf(panel, "cap:7002:s"), TileOf(panel, "cap:7002")
	Check("[ALLURE] vignette brillante : perle, teinte dorée ; la normale sans", tS.gem:IsShown()
		and tS.portrait.vertex[2] == NS.Theme.SHINY[2] and not tN.gem:IsShown() and tN.portrait.vertex[2] == 1
		and tN.accentColor ~= NS.Theme.GOLD_LIGHT)
	TileOf(panel, "cap:7002"):Click()
	if NS.effectsConfirm:IsShown() then NS:CompanionConfirmAnswer(true) end
	Check("[ALLURE] retour à la version normale", data.appearance == "cap:7002" and not NS:CompanionCurrentAppearance().shiny)
	-- compagnon de saison : même chemin (choix à part, l'habituelle gardée)
	TileOf(panel, "winter:metzen"):Click()
	if NS.effectsConfirm:IsShown() then NS:CompanionConfirmAnswer(true) end
	Check("[ALLURE] compagnon de saison : choisi par le même chemin", NS:CompanionCurrentAppearance().id == "winter:metzen"
		and data.appearance == "cap:7002" and data.winter.pick == "metzen")
	Check("[ALLURE] saison : le liseré suit", TileOf(panel, "winter:metzen").worn and not TileOf(panel, "cap:7002").worn)
	-- favoris : Maj+clic, gardés
	A.shift = true
	TileOf(panel, "cap:7003"):Click()
	A.shift = false
	Check("[ALLURE] Maj+clic : favori, sans rien choisir", data.allureFav["cap:7003"] == true
		and NS:CompanionCurrentAppearance().id == "winter:metzen" and TileOf(panel, "cap:7003").fav:IsShown())
	NS:AllureClose()
	NS:AllureOpen()
	panel.chips.byId.fav:Click()
	local favs = Shown(panel)
	Check("[ALLURE] favoris gardés (données du compagnon) : la puce les montre", #favs == 1 and favs[1] == "cap:7003")
	A.shift = true
	TileOf(panel, "cap:7003"):Click()
	A.shift = false
	Check("[ALLURE] Maj+clic encore : retiré", data.allureFav["cap:7003"] == nil and #Shown(panel) == 0)
	panel.chips.byId.all:Click()
	-- mascotte pas encore gagnée : grisée, pas choisissable, sa condition en infobulle
	local lockedDef
	for _, def in ipairs(NS.COMPANION_APPEARANCES) do if not NS:CompanionIsUnlocked("app", def) then lockedDef = def; break end end
	for _ = 1, 10 do
		if TileOf(panel, lockedDef.id) then break end
		NS:AllureScroll(1)
	end
	local tile = TileOf(panel, lockedDef.id)
	Check("[ALLURE] mascotte pas gagnée : grisée", tile and tile.locked and tile.portrait.desaturated ~= false
		and tile.portrait.alpha == NS.Theme.DIM_ALPHA)
	A.shift = true
	tile:Click()
	A.shift = false
	tile:Click()
	Check("[ALLURE] mascotte pas gagnée : ni choisie ni favorite", NS:CompanionCurrentAppearance().id == "winter:metzen"
		and not NS.effectsConfirm:IsShown() and data.allureFav[lockedDef.id] == nil)
	tile.scripts.OnEnter(tile)
	local text = table.concat(GameTooltip.lines or {}, " | ")
	Check("[ALLURE] infobulle : sa condition", text:find(NS:F("ALLURE_TIP_LOCKED", NS:CompanionLockText(lockedDef)), 1, true) ~= nil, text)
	tile.scripts.OnLeave(tile)
	-- refusé si on force l'id
	Check("[ALLURE] choix verrouillé refusé", NS:AllureChoose(lockedDef.id) == nil)
	A.Done()
end

-- 5. Fermetures : Échap, croix, carnet fermé -------------------------------------------------------
do
	Say("-- 2.14.0 : choisir son allure, fermetures")
	A.Reset("sobre", false)
	local panel = Open()
	panel.scripts.OnKeyDown(panel, "A")
	Check("[ALLURE] une autre touche : rien", panel:IsShown())
	panel.scripts.OnKeyDown(panel, "ESCAPE")
	Check("[ALLURE] Échap : le panneau se ferme, le carnet reste", not panel:IsShown() and NS.journalFrame:IsShown())
	NS:AllureOpen()
	panel.close:Click()
	Check("[ALLURE] la croix ferme", not panel:IsShown())
	NS:AllureOpen()
	Check("[ALLURE] fermé avec le carnet (accroché à son OnHide)", NS.journalFrame.qcAllureHooked == true)
	NS:AllureOnJournalHide()
	Check("[ALLURE] carnet fermé : panneau fermé", not panel:IsShown())
	Check("[ALLURE] sans nom : hors d'UISpecialFrames (Échap ne ferme pas le carnet avec lui)", panel:GetName() == nil)
	A.Done()
end

-- 6. Azeroth, changement de style, encres ----------------------------------------------------------
do
	Say("-- 2.14.0 : choisir son allure, Azeroth")
	A.Reset("azeroth", true)
	local panel = Open()
	Check("[ALLURE] Azeroth : panneau au parchemin, bordé de bois", panel.uiStyle == "azeroth" and panel.azBg
		and panel.azDialog == true and #(NS.errors or {}) == 0, tostring(panel.uiStyle) .. " " .. tostring(panel.azBg) .. " "
		.. tostring(panel.azDialog) .. " " .. tostring(NS.errors and NS.errors[1] and (NS.errors[1].message)))
	local tile = TileOf(panel, "cap:7001")
	Check("[ALLURE] Azeroth : vignettes sur le fond clair des hauts faits", tile.azStyle == "light")
	Check("[ALLURE] Azeroth : puces et recherche habillées", panel.chips.chips[1].azBg ~= nil and panel.searchBox.azSurface == "dark")
	Check("[ALLURE] Azeroth : encres mesurées (nom, brillante, intertitre)", tile.label.azRole == "allure.name"
		and TileOf(panel, "cap:7002:s").label.azRole == "allure.shiny" and panel.mineTitle.label.azRole == "allure.section"
		and panel.pager.position.azRole == "allure.hint")
	local c = INK[NS.AZEROTH_CONTRAST["allure.name"][1]]
	Check("[ALLURE] Azeroth : la couleur posée est celle du rôle", math.abs(tile.label.textColor[1] - c[1]) < 1e-6)
	-- changement de style, panneau ouvert : rouvert dans l'autre habit
	NS:DB().companionStyle = "sobre"
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:ApplyUIStyle()
	local fresh = NS.allurePanel
	Check("[ALLURE] style changé panneau ouvert : rouvert en Sobre, l'ancien fermé", fresh ~= panel and fresh:IsShown()
		and fresh.uiStyle == "sobre" and not panel:IsShown() and fresh.lastPoint.relTo == NS.journalFrame,
		tostring(fresh and fresh.uiStyle))
	Check("[ALLURE] Sobre : couleurs du socle", TileOf(fresh, "cap:7001").label.textColor[1] == NS.Theme.LABEL[1])
	NS:AllureClose()
	NS:DB().companionStyle = "azeroth"
	Mock.InstallAtlas(true)
	NS:AzerothAtlasOK(true)
	NS:ApplyUIStyle()
	Check("[ALLURE] style changé panneau fermé : il reste fermé", not NS:AllureShown())
	NS:AllureOpen()
	Check("[ALLURE] chaque style garde son panneau (pas reconstruit)", NS.allurePanel == panel and panel:IsShown())
	A.Done()

	Say("-- 2.14.0 : choisir son allure, encres")
	local bad = {}
	for _, role in ipairs({ "allure.section", "allure.hint", "allure.text", "allure.name", "allure.locked", "allure.shiny" }) do
		local r = NS.AZEROTH_CONTRAST[role]
		local ratio = r and NS.AzerothContrast(INK[r[1]], r[2]) or 0
		if not r or ratio < r[3] then bad[#bad + 1] = role .. string.format(" %.2f", ratio) end
	end
	Check("[ALLURE] rôles allure.* : 4,5:1 au moins sur le pire fond mesuré", #bad == 0, table.concat(bad, ", "))
	Check("[ALLURE] fonds : parchemin des confirmations, tuiles claires", NS.AZEROTH_CONTRAST["allure.text"][2] == NS.AZEROTH_CONTRAST["dialog.text"][2]
		and NS.AZEROTH_CONTRAST["allure.name"][2] == NS.AZEROTH_CONTRAST["tile.text"][2])
	-- Sobre : jetons du socle sur la tuile (ROW) et la fenêtre (WINDOW)
	local Th = NS.Theme
	local sobre = {}
	for name, pair in pairs({ name = { Th.LABEL, Th.ROW }, locked = { Th.MUTED, Th.ROW }, shiny = { Th.GOLD_LIGHT, Th.ROW },
		section = { Th.MUTED_LIGHT, Th.WINDOW }, hint = { Th.MUTED, Th.WINDOW } }) do
		local ratio = Th.Contrast(pair[1], pair[2])
		if ratio < 4.5 then sobre[#sobre + 1] = name .. string.format(" %.2f", ratio) end
	end
	Check("[ALLURE] Sobre : 4,5:1 au moins (tuiles, fenêtre)", #sobre == 0, table.concat(sobre, ", "))
	local fr, en = NS.ALLURE_STRINGS.fr, NS.ALLURE_STRINGS.en
	local missing = {}
	for key in pairs(fr) do if en[key] == nil then missing[#missing + 1] = key end end
	for key in pairs(en) do if fr[key] == nil then missing[#missing + 1] = key end end
	Check("[ALLURE] textes FR/EN au complet", #missing == 0, table.concat(missing, ", "))
end
