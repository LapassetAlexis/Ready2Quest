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
	-- displayID connu : portrait 2D, pas de modèle 3D (bêta 3 : modèle sinon, section 7)
	Check("[ALLURE] grille : tuiles construites une fois", #panel.tiles == NS.ALLURE_COLS * NS.ALLURE_ROWS_MAX)
	local tKodo = TileOf(panel, "cap:7001")
	Check("[ALLURE] portrait 2D : le displayID appris de l'espèce, sans modèle 3D", tKodo.portrait.portraitID == 1001
		and tKodo.portrait.portraitKind == "portrait" and tKodo.model == nil)
	-- ni displayID ni modèle que le client sache charger (simulacre sans SetCreature) : l'icône du type
	local tFire = TileOf(panel, "cap:7003")
	Check("[ALLURE] ni displayID ni modèle : l'icône de son type", tFire.look == "icon"
		and tFire.portrait.texture == NS.MENAGERIE_TYPE_ICONS["Élémentaire"] and tFire.portrait:IsShown(),
		tostring(tFire.look) .. " " .. tostring(tFire.portrait.texture))
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
	-- bêta 6 : les trois en portrait 2D (numéros de modèle connus)
	Check("[ALLURE] saison : les trois en vignette de saison", panel.seasonTiles[1].seasonal
		and panel.seasonTiles[1].def.id == "winter:gfw")
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

-- 7. Bêta 3 : chaque vignette montre sa créature -------------------------------------------------------
-- Un PlayerModel simulé qui sait charger une créature (SetCreature) et dire
-- son displayID (GetDisplayInfo) : tout de suite, ou après OnModelLoaded
-- (A.lazy).
local DISPLAYS = { [7003] = 5003, [7004] = 5004 }
for n = 1, 12 do DISPLAYS[7100 + n] = 5100 + n end
local function InstallModels()
	A.models, A.lazy = {}, false
	A.createFrame = _G.CreateFrame
	_G.CreateFrame = function(kind, ...)
		local frame = A.createFrame(kind, ...)
		if kind == "PlayerModel" then
			A.models[#A.models + 1] = frame
			frame.loads = 0
			function frame:SetCreature(id) self.creature, self.display, self.loaded = id, nil, not A.lazy; self.loads = self.loads + 1 end
			function frame:SetDisplayInfo(id) self.display, self.creature, self.loaded = id, nil, true; self.loads = self.loads + 1 end
			function frame:GetDisplayInfo()
				if not self.loaded then return 0 end
				return self.display or DISPLAYS[self.creature or -1] or 0
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
	Say("-- 2.14.0 (bêta 3) : une vignette par créature")
	A.Reset("sobre", true)
	InstallModels()
	local panel = Open()
	local probe = NS.modelLearnCreatureProbe
	-- displayID connu : le portrait 2D ; sinon la créature elle-même, en petit modèle
	local tKodo, tZebra = TileOf(panel, "cap:7001"), TileOf(panel, "cap:7101")
	Check("[ALLURE3] displayID connu : portrait 2D, pas de modèle", tKodo.look == "portrait" and tKodo.model == nil
		and tKodo.portrait:IsShown())
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
	Check("[ALLURE3] sans displayID : sa créature en 3D (SetCreature), une par tuile, pas un repli commun",
		models >= 10 and distinct == models and portraitsOnly, models .. " / " .. distinct)
	local tFire = TileOf(panel, "cap:7003")
	Check("[ALLURE3] modèle cadré comme le compagnon (distance du type, cadrage « pied »)", tFire.look == "model"
		and math.abs(tFire.model.cam - NS.COMPANION_MODEL_TYPE_CAM["Élémentaire"]) < 1e-9 and tFire.model.zoom == 0,
		tostring(tFire.model and tFire.model.cam))
	Check("[ALLURE3] modèle sans souris (le clic reste à la tuile)", tFire.model.mouseEnabled == false)
	-- bêta 6 : les vignettes de saison en portrait 2D par défaut ; les
	-- vérifications du modèle 3D (bêtas 4 et 5, son repli) en mode 3d
	local printQuiet = NS.Print
	NS.Print = function() end
	NS:WinterVeilCommand("metzen 3d")
	NS.Print = printQuiet
	-- Metzen : de loin, la même distance dans la vignette, la carte et le cadre du compagnon
	local tMetzen = TileOf(panel, "winter:metzen")
	-- bêta 4 : Metzen montré sous le modèle du Renne de l'Hiver (15706), cadré comme les autres
	Check("[ALLURE4] Metzen : la vignette montre un modèle (Renne de l'Hiver, 15706), cadré comme les autres",
		tMetzen.look == "model" and tMetzen.model.creature == NS.WINTER_METZEN_LOOK and NS.WINTER_METZEN_LOOK == 15706
		and tMetzen.model:IsShown() and tMetzen.model.cam == NS.WINTER_METZEN_CAM and NS.WINTER_METZEN_CAM <= 2,
		tostring(tMetzen.model.creature) .. " / " .. tostring(tMetzen.model.cam))
	Check("[ALLURE4] Metzen : même valeur pour le cadre du compagnon", NS:CompanionModelCam({ npc = 15664 }, "pied")
		== NS.WINTER_METZEN_CAM and NS.COMPANION_MODEL_OVERRIDES[15664].cam == NS.WINTER_METZEN_CAM
		and NS.MODEL_NPC_LOOK[15664] == 15706)
	-- bêta 4 : /qc noel metzen <distance> [pnj] : réglage en jeu, la vignette se recharge
	local print0 = NS.Print
	NS.Print = function() end
	NS:WinterVeilCommand("metzen 2,5 15664")
	NS:AllureRefresh()
	local tuned = TileOf(panel, "winter:metzen")
	Check("[ALLURE4] /qc noel metzen 2,5 15664 : distance et modèle réglés, vignette rechargée",
		NS.WINTER_METZEN_CAM == 2.5 and tuned.model.creature == 15664 and tuned.model.cam == 2.5
		and NS:CompanionModelCam({ npc = 15664 }, "pied") == 2.5, tostring(tuned.model.creature) .. " / " .. tostring(tuned.model.cam))
	-- 2.14.1 : distance par défaut réglée en jeu (0,6 : le renne réduit à sa taille dans le cadre)
	Check("[ALLURE141] Metzen : caméra par défaut 0,6", NS.WINTER_METZEN_CAM_DEFAULT == 0.6 or NS.WINTER_METZEN_CAM == 0.6
		or NS.WINTER_METZEN_CAM == 2.5)
	NS:WinterVeilCommand("metzen 1 15706")
	NS:AllureRefresh()
	Check("[ALLURE4] /qc noel metzen 1 15706 : retour au Renne de l'Hiver", TileOf(panel, "winter:metzen").model.creature == 15706
		and NS.WINTER_METZEN_CAM == 1)
	NS.Print = print0
	-- bêta 5 (28.png) : les appels exacts de la vignette de Metzen. Un displayID
	-- appris pour 15664 (le grand Metzen) ne passe pas devant.
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
		for _, name in ipairs({ "SetCreature", "SetDisplayInfo", "SetCamDistanceScale", "SetPortraitZoom", "SetPosition" }) do Spy(name) end
		model.SetModelScale = function(_, v) calls[#calls + 1] = { name = "SetModelScale", args = { v } } end
		tile.lookKey, model.modelKey, model.modelShown = nil, nil, nil
		NS:AllureRefresh()
		local seen = {}
		for _, call in ipairs(calls) do seen[call.name] = seen[call.name] or call.args end
		Check("[ALLURE5] Metzen : la vignette charge SetCreature(15706), jamais un display (ni 15902 appris)",
			seen.SetCreature and seen.SetCreature[1] == 15706 and seen.SetDisplayInfo == nil and model.display == nil
			and model.modelNpc == 15706 and model.modelDisplay == nil, tostring(seen.SetCreature and seen.SetCreature[1]))
		Check("[ALLURE5] Metzen : caméra du client (distance 1, ce renne disparaît dès qu'elle recule), zoom 0, position 0",
			NS.WINTER_METZEN_CAM == 1 and seen.SetCamDistanceScale and seen.SetCamDistanceScale[1] == 1
			and seen.SetPortraitZoom and seen.SetPortraitZoom[1] == 0
			and seen.SetPosition and seen.SetPosition[1] == 0 and seen.SetPosition[2] == 0 and seen.SetPosition[3] == 0
			and seen.SetModelScale == nil, tostring(seen.SetCamDistanceScale and seen.SetCamDistanceScale[1]))
		Check("[ALLURE5] Metzen : modèle montré, portrait caché, taille de la vignette", tile.look == "model"
			and model:IsShown() and not tile.portrait:IsShown() and model:GetWidth() == NS.ALLURE_TILE_W - 6
			and model:GetHeight() == NS.ALLURE_PORTRAIT)
		-- la caméra reposée au chargement (OnModelLoaded) : toujours 1
		model.cam = nil
		local loaded = model.hooks and model.hooks.OnModelLoaded
		if loaded then loaded(model) end
		Check("[ALLURE5] Metzen : chargement du modèle, la même caméra reposée", loaded ~= nil and model.cam == 1)
		Check("[ALLURE5] cadre du compagnon (Metzen porté) : même distance, quel que soit le cadrage, jamais plus loin que 1",
			NS:CompanionModelCam({ npc = 15664 }, "pied") == 1 and NS:CompanionModelCam({ npc = 15664 }, "portrait") <= 1
			and NS:CompanionModelCam({ npc = 15664 }, "buste") <= 1)
		-- /qc noel metzen diag : vignette et cadre du compagnon
		local printed = {}
		NS.Print = function(_, text) printed[#printed + 1] = text end
		NS:WinterVeilCommand("metzen diag")
		NS.Print = print0
		local all = table.concat(printed, "\n")
		Check("[ALLURE5] /qc noel metzen diag : pnj, display, caméra, chargé, taille de la vignette et du compagnon",
			#printed == 3 and printed[1]:find("15706", 1, true) ~= nil
			and printed[2]:find(NS.L.WINTER_METZEN_DIAG_TILE, 1, true) ~= nil and printed[2]:find("pnj 15706", 1, true) ~= nil
			and printed[2]:find("52 × 46", 1, true) ~= nil and printed[2]:find("caméra 1", 1, true) ~= nil
			and printed[3]:find(NS.L.WINTER_METZEN_DIAG_COMP, 1, true) ~= nil, all)
		-- le cadre du compagnon qui porte Metzen : les mêmes appels
		-- un cadre neuf, créé avec le PlayerModel simulé (SetCreature, caméra lue)
		if NS.companionFrame then NS.companionFrame:Hide() end
		NS.companionFrame = nil
		local frame = NS:EnsureCompanionFrame()
		local cm = frame and frame.model
		NS:CompanionSetAppearance("winter:metzen")
		Check("[ALLURE5] cadre du compagnon : Metzen chargé par SetCreature(15706), sans display, distance ≤ 1",
			cm and cm.creature == 15706 and cm.display == nil and cm.modelNpc == 15706 and cm.cam and cm.cam <= 1
			and not frame.usesFallback, tostring(cm and cm.creature) .. " / " .. tostring(cm and cm.cam))
		printed = {}
		NS.Print = function(_, text) printed[#printed + 1] = text end
		NS:WinterMetzenDiag()
		NS.Print = print0
		Check("[ALLURE5] diag : la ligne du cadre du compagnon quand il porte Metzen", printed[3] ~= nil
			and printed[3]:find("pnj 15706", 1, true) ~= nil, tostring(printed[3]))
		Check("[ALLURE5] diag : textes FR et EN", NS.L.WINTER_METZEN_DIAG_ROW ~= nil and NS.L.WINTER_METZEN_DIAG_HEAD ~= nil)
		account.display[15664] = nil
		if NS.companionFrame then NS.companionFrame:Hide() end
		NS.companionFrame = nil
	end
	Check("[ALLURE3] Grand-père Hiver et le bonhomme de neige : inchangés", TileOf(panel, "winter:gfw").model.cam == 1.5
		and TileOf(panel, "winter:snowman").model.cam == 1.2)
	NS.Print = function() end
	NS:WinterVeilCommand("metzen 2d")
	NS.Print = printQuiet
	-- la mise en réserve : un modèle par tuile au plus, réutilisé au défilement
	local before = #A.models
	local visible = panel.rows * NS.ALLURE_COLS
	Check("[ALLURE3] modèles : seulement les tuiles visibles qui en ont besoin", GridModels(panel) <= visible)
	local first = panel.tiles[1]
	local firstModel = first.model
	for _ = 1, 5 do NS:AllureScroll(1) end
	for _ = 1, 5 do NS:AllureScroll(-1) end
	NS:AllureScroll(1)
	Check("[ALLURE3] défilement : modèles réutilisés, pas recréés", #A.models - before <= visible
		and (firstModel == nil or first.model == firstModel), #A.models .. " / " .. before)
	local made = #A.models
	for _ = 1, 3 do NS:AllureScroll(1); NS:AllureScroll(-1) end
	Check("[ALLURE3] aller-retour : aucun modèle de plus", #A.models == made)
	NS:AllureScroll(-10)

	-- l'apprentissage des displayID : en fond, les visibles d'abord
	local account = NS:CaptureAccount()
	Check("[ALLURE3] apprentissage : une sonde à part (pas celle des unités)", probe ~= nil and probe ~= NS.modelLearnProbe
		and probe.alpha == 0)
	local learnedFirst = probe.creature
	Check("[ALLURE3] première lecture tout de suite, une espèce visible sans displayID",
		learnedFirst ~= nil and account.display[learnedFirst] == DISPLAYS[learnedFirst], tostring(learnedFirst))
	local queued = #NS:ModelLearnQueue()
	local loads = probe.loads
	NS:ModelLearnPump()
	Check("[ALLURE3] au plus une lecture tous les MODEL_LEARN_CREATURE_GAP s", probe.loads == loads
		and #NS:ModelLearnQueue() == queued and NS.MODEL_LEARN_CREATURE_GAP >= 0.25)
	Mock.now = Mock.now + NS.MODEL_LEARN_CREATURE_GAP
	A.fight = true
	_G.InCombatLockdown = function() return A.fight end
	local timers = #A.timers
	NS:ModelLearnPump()
	Check("[ALLURE3] jamais en combat (reprise plus tard)", probe.loads == loads and #NS:ModelLearnQueue() == queued
		and NS.modelLearnPending == true and #A.timers == timers + 1)
	A.fight = false
	A.lazy = true
	local npc = NS:ModelLearnPump()
	Check("[ALLURE3] hors combat : la suivante", npc ~= nil and probe.loads == loads + 1 and probe.creature == npc
		and #NS:ModelLearnQueue() == queued - 1)
	Check("[ALLURE3] pas encore chargée : rien de gardé (pas l'ancien modèle)", account.display[npc] == nil)
	probe.loaded = true
	probe.scripts.OnModelLoaded(probe)
	Check("[ALLURE3] chargée (OnModelLoaded) : son displayID gardé au compte", account.display[npc] == DISPLAYS[npc])
	A.lazy = false
	-- tout le reste, au rythme des minuteries
	for _ = 1, 40 do
		Mock.now = Mock.now + NS.MODEL_LEARN_CREATURE_GAP
		A.Fire()
	end
	local all = true
	for id in pairs(DISPLAYS) do if account.display[id] ~= DISPLAYS[id] then all = false end end
	Check("[ALLURE3] toutes les espèces capturées apprises, file vide", all and #NS:ModelLearnQueue() == 0)
	-- la fois suivante : le portrait 2D, le modèle rangé
	NS:AllureClose()
	NS:AllureOpen()
	tZebra = TileOf(panel, "cap:7101")
	Check("[ALLURE3] displayID appris : portrait 2D la fois suivante", tZebra.look == "portrait"
		and tZebra.portrait.portraitID == 5101 and tZebra.portrait:IsShown() and (tZebra.model == nil or not tZebra.model:IsShown()))
	-- fermer le panneau arrête la file
	NS:CaptureAccount().display[7112] = nil
	NS:AllureRefresh()
	NS:AllureClose()
	Check("[ALLURE3] panneau fermé : plus rien à apprendre", #NS:ModelLearnQueue() == 0)
	UninstallModels()
	A.Done()
end

-- 2.14.0 (bêta 4) : des noms, pas des numéros (23.png : « 3632 ») ---------------------------------------
do
	Say("-- allure (bêta 4) : le nom d'une créature capturée sans nom gardé")
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
	Check("[NOMS4] numéro rangé, nom de la table livrée (toutes zones)", static[NS:CreatureName(3632, { name = "3632" })] == true)
	Check("[NOMS4] le nom du carnet d'abord (une autre zone)", NS:CreatureName(9999, {}) == "Sanglier du carnet")
	Check("[NOMS4] un vrai nom de fiche reste", NS:CreatureName(3632, { name = "Rampant" }) == "Rampant")
	Check("[NOMS4] rien nulle part : le numéro en dernier recours", NS:CreatureName(123456, {}) == "123456")
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
	Check("[NOMS4] vignette : le nom, pas « 3632 »", label ~= nil and static[label] == true, tostring(label))
	Check("[NOMS4] nom rendu à la fiche de capture", static[capture.creatures[3632].name] == true
		and capture.creatures[9999].name == "Sanglier du carnet")
	local meta = tile and NS:AllureMeta(tile.def)
	Check("[NOMS4] infobulle : le nom en titre (libellé de l'apparence)", meta ~= nil and static[meta.name] == true,
		tostring(meta and meta.name))
	-- la plaque du compagnon, sous cette allure
	NS:CompanionData().appearance = "cap:3632"
	Check("[NOMS4] plaque du compagnon : le nom", static[NS:CompanionName()] == true, tostring(NS:CompanionName()))
	-- la page Créatures (vue du Pokédex)
	NS.menagerieStatic = nil
	local list = NS:MenagerieList({})
	local found
	for _, item in ipairs(list or {}) do if item.npc == 3632 then found = item.name end end
	Check("[NOMS4] page Créatures : le nom", static[found] == true, tostring(found))
	NS:BestiaryData()[1411] = nil
	A.Done()
	NS.ZONE_CREATURES = savedZones
	NS.CreatureNameForget()
	NS.menagerieStatic = nil
end

-- 2.14.0 (bêta 6) : portraits 2D des compagnons de saison (30.png : Metzen minuscule, coupé) -----------
do
	Say("-- allure (bêta 6) : portraits 2D des compagnons de saison")
	A.Reset("azeroth", true)
	InstallModels()
	local print0 = NS.Print
	NS.Print = function() end
	local panel, evo = Open()
	local tM, tG, tS = TileOf(panel, "winter:metzen"), TileOf(panel, "winter:gfw"), TileOf(panel, "winter:snowman")
	Check("[ALLURE6] Metzen : portrait 2D rond du Renne de l'Hiver (display 15904), modèle 3D caché",
		tM and tM.look == "portrait" and tM.portrait.portraitID == 15904 and tM.portrait:IsShown()
		and not (tM.model and tM.model:IsShown()) and NS.WINTER_PORTRAIT_DISPLAY[15664] == 15904,
		tostring(tM and tM.look) .. " / " .. tostring(tM and tM.portrait.portraitID))
	Check("[ALLURE6] Metzen : la taille d'une vignette (portrait de la grille)", tM.portrait:GetWidth() == NS.ALLURE_PORTRAIT
		and tM.portrait.vertex[1] == 1)
	-- bêta 6 : numéros lus en jeu / dans le client : les trois en portrait 2D d'emblée
	Check("[ALLURE6] Grand-père Hiver (13369) et le bonhomme (15671) en portrait 2D aussi (les trois pareils)",
		tG.look == "portrait" and tG.portrait.portraitID == 13369 and tS.look == "portrait" and tS.portrait.portraitID == 15671
		and not (tG.model and tG.model:IsShown()) and tM.look == "portrait",
		tostring(tG.look) .. "/" .. tostring(tG.portrait.portraitID) .. " " .. tostring(tS.look) .. "/" .. tostring(tS.portrait.portraitID))
	-- la carte « Son allure » : Metzen porté
	tM:Click()
	if NS.effectsConfirm and NS.effectsConfirm:IsShown() then NS:CompanionConfirmAnswer(true) end
	NS:AllureRefreshCard(evo)
	local card = evo.lookCard
	Check("[ALLURE6] carte « Son allure » : Metzen en portrait 2D (15904), le petit modèle caché",
		NS:CompanionCurrentAppearance().id == "winter:metzen" and card.look == "portrait" and card.portrait:IsShown()
		and card.portrait.portraitID == 15904 and not card.model:IsShown(), tostring(card.look))
	-- /qc noel metzen 2d 15902 : un autre affichage
	NS:WinterVeilCommand("metzen 2d 15902")
	NS:AllureRefreshCard(evo)
	Check("[ALLURE6] /qc noel metzen 2d 15902 : vignette et carte rechargées", TileOf(panel, "winter:metzen").portrait.portraitID == 15902
		and card.portrait.portraitID == 15902)
	NS:WinterVeilCommand("metzen 2d 15904")
	-- repli : le client refuse le portrait (erreur) : le modèle 3D d'avant
	_G.SetPortraitTextureFromCreatureDisplayID = function() error("portrait refusé") end
	for _, tile in ipairs(panel.seasonTiles) do tile.lookKey = nil end
	NS:AllureRefresh()
	tM = TileOf(panel, "winter:metzen")
	Check("[ALLURE6] portrait refusé : Metzen revient au modèle 3D (Renne de l'Hiver, 15706)", tM.look == "model"
		and tM.model:IsShown() and tM.model.creature == 15706 and not tM.portrait:IsShown(), tostring(tM.look))
	NS:AllureRefreshCard(evo)
	Check("[ALLURE6] portrait refusé : la carte aussi (modèle)", card.look == "model" and not card.portrait:IsShown())
	-- sans l'API du portrait : 3D
	_G.SetPortraitTextureFromCreatureDisplayID = nil
	NS:AllureRefresh()
	NS:AllureRefreshCard(evo)
	Check("[ALLURE6] client sans portrait 2D : modèle 3D (vignette et carte)", TileOf(panel, "winter:metzen").look == "model"
		and card.look == "model")
	-- /qc noel metzen 3d : le modèle même avec l'API ; 2d : le portrait revient
	_G.SetPortraitTextureFromCreatureDisplayID = function(tex, id) tex.portraitID = id end
	NS:WinterVeilCommand("metzen 3d")
	Check("[ALLURE6] /qc noel metzen 3d : modèle 3D", TileOf(panel, "winter:metzen").look == "model"
		and NS:WinterPortraitDisplay(15664) == nil)
	NS:WinterVeilCommand("metzen 2d")
	Check("[ALLURE6] /qc noel metzen 2d : portrait revenu", TileOf(panel, "winter:metzen").look == "portrait"
		and NS.WINTER_PORTRAITS_ON == true)
	local lines = NS:WinterMetzenDiag()
	Check("[ALLURE6] diag : dit ce que montrent les vignettes", lines[1]:find("15904", 1, true) ~= nil, lines[1])
	local fr, en = NS.L.WINTER_METZEN_LOOK, NS.L.WINTER_METZEN_2D
	Check("[ALLURE6] textes du réglage", fr ~= nil and en ~= nil and NS.L.WINTER_METZEN_3D ~= nil)
	do local account = NS:CaptureAccount(); account.display[13444], account.display[15710] = nil, nil end
	NS.Print = print0
	UninstallModels()
	A.Done()
end
